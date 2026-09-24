class_name IdAudit
extends RefCounted
## The explanation and layout audit over a rendered UI tree (§6.8, §9.9, §12 explanation audit).
## Rules:
##   raw_id        text looks like an internal id (snake_case), an unresolved string key
##                 (dotted.key), or contains SYS-, COL-, null or a brace
##   overlap       two labels (or buttons with text) on the same layer overlap on screen
##   clipped       a label is cut off by the screen or a panel, or its text does not fit its box
##   broken_word   a wrapping label is narrower than one of its words, so the word is split
##   tap_target    at phone size, something you can press is smaller than 48 dp either way
##   numeric       a label showing a number is not inside an Explainable (or tooltip)
## A node (or an ancestor) with meta "audit_numeric_ok" is exempt from the numeric rule; the tour
## report lists every exemption so they stay visible.

const RAW_ID_PATTERN: String = "^[a-z0-9]+(_[a-z0-9]+)+$"
const KEY_PATTERN: String = "^[a-z_][a-z0-9_]*(\\.[a-z_][a-z0-9_]*)+$"
const FORBIDDEN: Array[String] = ["SYS-", "COL-", "null", "{", "}"]
const TAP_DP: float = 48.0
const EPS: float = 0.75


class AuditReport:
	extends RefCounted
	var issues: Array[Dictionary] = []
	var exemptions: Array[Dictionary] = []
	var checked_labels: int = 0
	var checked_targets: int = 0


static func run(tree_root: Node, overlay_root: Control, view: Rect2, phone: bool) -> AuditReport:
	var res: AuditReport = AuditReport.new()
	var raw_re: RegEx = RegEx.create_from_string(RAW_ID_PATTERN)
	var key_re: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var digit_re: RegEx = RegEx.create_from_string("[0-9]")
	var controls: Array[Control] = []
	_collect(tree_root, controls)
	var texts: Array[Dictionary] = []
	for c: Control in controls:
		if not c.is_visible_in_tree() or c.is_queued_for_deletion():
			continue
		var t: String = _text_of(c)
		var on_screen: Rect2 = _visible_rect(c, view, true)
		var shown: bool = on_screen.size.x > EPS and on_screen.size.y > EPS
		# raw ids: all text, shown or scrolled away, plus tooltips
		for candidate: String in [t, c.tooltip_text]:
			if candidate.is_empty():
				continue
			var stripped: String = candidate.strip_edges()
			if raw_re.search(stripped) != null:
				_issue(res, "raw_id", c, candidate, "looks like an internal id")
			elif key_re.search(stripped) != null:
				_issue(res, "raw_id", c, candidate, "unresolved string key")
			else:
				for f: String in FORBIDDEN:
					if candidate.contains(f):
						_issue(res, "raw_id", c, candidate, "contains \"%s\"" % f)
						break
		if not shown:
			continue
		if not t.is_empty() and (c is Label or c is RichTextLabel or (c is BaseButton and not (c as BaseButton).get("icon_only"))):
			res.checked_labels += 1
			texts.append({"node": c, "rect": on_screen, "layer": _layer_of(c, overlay_root)})
			_check_clip(res, c, t, view)
			if digit_re.search(t) != null:
				var ex: Node = _exempt_ancestor(c)
				if ex != null:
					res.exemptions.append({"path": _path(c), "text": t, "reason": str(ex.get_meta("audit_numeric_ok"))})
				elif not _in_group(c, "explainable") and not _in_group(c, "breakdown_tooltip"):
					_issue(res, "numeric", c, t, "number shown outside an Explainable")
		if c.is_in_group("hex_cell"):
			texts.append({"node": c, "rect": on_screen, "layer": _layer_of(c, overlay_root)})
		if phone and _pressable(c):
			res.checked_targets += 1
			var r: Rect2 = c.get_global_rect()
			if r.size.x + EPS < TAP_DP or r.size.y + EPS < TAP_DP:
				_issue(res, "tap_target", c, t, "%.0fx%.0f dp, needs %dx%d" % [r.size.x, r.size.y, int(TAP_DP), int(TAP_DP)])
	_check_overlaps(res, texts)
	return res


static func _collect(n: Node, out: Array[Control]) -> void:
	if n is Control:
		out.append(n)
	for ch: Node in n.get_children():
		_collect(ch, out)


static func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).text
	if c is Button:
		return (c as Button).text
	return ""


## The part of `c` that can be seen: clipped by clipping ancestors (all of them, or all but
## ScrollContainers) and by the screen.
static func _visible_rect(c: Control, view: Rect2, include_scroll: bool) -> Rect2:
	var r: Rect2 = c.get_global_rect()
	var p: Node = c.get_parent()
	while p != null:
		if p is Control:
			var pc: Control = p
			if pc.clip_contents and (include_scroll or not (pc is ScrollContainer)):
				r = r.intersection(pc.get_global_rect())
		p = p.get_parent()
	return r.intersection(view)


static func _check_clip(res: AuditReport, c: Control, t: String, view: Rect2) -> void:
	var full: Rect2 = c.get_global_rect()
	if full.size.x <= EPS or full.size.y <= EPS:
		return
	# Clipping along a scroll container's scroll axis is scrolling, not a defect.
	var r: Rect2 = full
	var scroll_h: bool = false
	var scroll_v: bool = false
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			var sc: ScrollContainer = p
			scroll_h = scroll_h or sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			scroll_v = scroll_v or sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			r = r.intersection(sc.get_global_rect())
		elif p is Control and (p as Control).clip_contents:
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	r = r.intersection(view)
	var cut_x: bool = r.size.x < full.size.x - 1.0
	var cut_y: bool = r.size.y < full.size.y - 1.0
	if (cut_x and not scroll_h) or (cut_y and not scroll_v):
		_issue(res, "clipped", c, t, "cut off %s" % ("sideways" if cut_x and not scroll_h else "at the top or bottom"))
		return
	if c is Label:
		var l: Label = c
		var min_size: Vector2 = l.get_minimum_size()
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.size.x + EPS < min_size.x:
			_issue(res, "clipped", c, t, "text is wider than its box")
		elif l.size.y + EPS < min_size.y:
			_issue(res, "clipped", c, t, "text is taller than its box")
		elif l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var font: Font = l.get_theme_font("font")
			var fs: int = l.get_theme_font_size("font_size")
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x + EPS:
				_issue(res, "clipped", c, t, "text is truncated")
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		var wl: Label = c
		var wfont: Font = wl.get_theme_font("font")
		var wsize: int = wl.get_theme_font_size("font_size")
		for word: String in t.split(" ", false):
			var ww: float = wfont.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wsize).x
			if ww > wl.size.x + EPS:
				_issue(res, "broken_word", c, t, "\"%s\" is wider than its %d px box" % [word, int(wl.size.x)])
				break
	var panel: Control = _nearest_panel(c)
	if panel != null:
		var pr: Rect2 = panel.get_global_rect().grow(1.0)
		if not pr.encloses(full):
			_issue(res, "clipped", c, t, "spills out of its panel")


static func _check_overlaps(res: AuditReport, texts: Array[Dictionary]) -> void:
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a: Dictionary = texts[i]
			var b: Dictionary = texts[j]
			if a["layer"] != b["layer"]:
				continue
			var na: Control = a["node"]
			var nb: Control = b["node"]
			if na.is_ancestor_of(nb) or nb.is_ancestor_of(na):
				continue
			var inter: Rect2 = (a["rect"] as Rect2).intersection(b["rect"])
			if inter.size.x > 1.5 and inter.size.y > 1.5:
				_issue(res, "overlap", na, _text_of(na), "overlaps \"%s\" (%s)" % [_text_of(nb).left(40), _path(nb)])


static func _pressable(c: Control) -> bool:
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	return c is BaseButton or c is Range or c is LineEdit or c.is_in_group("explainable") or c.is_in_group("hex_cell")


static func _layer_of(c: Control, overlay_root: Control) -> int:
	var n: Node = c
	while n != null:
		if n.get_parent() == overlay_root:
			return n.get_instance_id()
		n = n.get_parent()
	return 0


static func _nearest_panel(c: Control) -> Control:
	var p: Node = c.get_parent()
	while p != null:
		if p is PanelContainer:
			return p
		if p is ScrollContainer:
			return null
		p = p.get_parent()
	return null


static func _in_group(c: Node, group: String) -> bool:
	var p: Node = c
	while p != null:
		if p.is_in_group(group):
			return true
		p = p.get_parent()
	return false


static func _exempt_ancestor(c: Node) -> Node:
	var p: Node = c
	while p != null:
		if p.has_meta("audit_numeric_ok"):
			return p
		p = p.get_parent()
	return null


static func _issue(res: AuditReport, rule: String, c: Node, text: String, detail: String) -> void:
	res.issues.append({"rule": rule, "path": _path(c), "text": text.left(80), "detail": detail})


static func _path(c: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var n: Node = c
	var depth: int = 0
	while n != null and depth < 7:
		parts.insert(0, str(n.name))
		n = n.get_parent()
		depth += 1
	return "/".join(parts)
