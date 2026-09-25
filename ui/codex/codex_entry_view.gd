class_name CodexEntryView
extends VBoxContainer
## One Codex entry: its picture and title, the description, the text (mechanics and events) with
## links, the cost (as explainable chips), the facts from the data, the effects, and "See also".
## Following a link calls `on_link` with the target's entry id.

var entry: CodexIndex.Entry
var _index: CodexIndex
var _on_link: Callable


static func make(e: CodexIndex.Entry, ix: CodexIndex, on_link: Callable) -> CodexEntryView:
	var v: CodexEntryView = CodexEntryView.new()
	v.name = "Entry"
	v.entry = e
	v._index = ix
	v._on_link = on_link
	v.add_theme_constant_override("separation", Tokens.SPACE_M)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v._build()
	return v


func _build() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", Tokens.SPACE_M)
	if not entry.portrait.is_empty():
		head.add_child(Portrait.make(entry.portrait, "neutral", 64.0))
	elif not entry.icon.is_empty():
		var i: SfIcon = SfIcon.make(entry.icon, Tokens.ICON_L * 2, entry.icon_token)
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(i)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(FlowScreen.label(Strings.fmt(CodexIndex.CATEGORY_KEYS.get(entry.category, "ui.codex.title")), &"CaptionLabel"))
	var t: Label = FlowScreen.label(entry.title, &"H1Label")
	t.name = "EntryTitle"
	titles.add_child(t)
	if entry.story:
		titles.add_child(FlowScreen.label(Strings.fmt("ui.codex.story_marker"), &"CaptionLabel"))
	head.add_child(titles)
	add_child(head)
	if not entry.summary.is_empty():
		var s: Label = FlowScreen.label(entry.summary)
		s.name = "Summary"
		s.set_meta("audit_numeric_ok", "the Codex quotes the data's own description")
		add_child(s)
	if not entry.prose.is_empty():
		var rt: RichTextLabel = RichTextLabel.new()
		rt.name = "Prose"
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.text = _with_titles(entry.prose)
		rt.meta_underlined = true
		rt.add_theme_color_override("default_color", Tokens.color("text.primary"))
		rt.meta_clicked.connect(func(meta: Variant) -> void: _on_link.call(str(meta)))
		# The mechanics pages quote the rules' own numbers (CodexFacts); event text is story prose.
		rt.set_meta("audit_numeric_ok", "numbers quoted from the rules and data by the Codex")
		add_child(rt)
	if not entry.cost.is_empty():
		add_child(FlowScreen.label(Strings.fmt("ui.codex.cost"), &"StrongLabel"))
		add_child(CostChips.make(entry.cost))
	if not entry.facts.is_empty():
		var grid: GridContainer = GridContainer.new()
		grid.name = "Facts"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", Tokens.SPACE_L)
		grid.add_theme_constant_override("v_separation", Tokens.SPACE_XS)
		grid.set_meta("audit_numeric_ok", "values quoted from the data files by the Codex")
		for f: PackedStringArray in entry.facts:
			var k: Label = Label.new()
			k.text = f[0]
			k.theme_type_variation = &"CaptionLabel"
			grid.add_child(k)
			var val: Label = FlowScreen.label(f[1])
			val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(val)
		add_child(grid)
	var lines: Array[EffectText.Line] = EffectText.describe_all(null, entry.effects)
	if not lines.is_empty():
		add_child(FlowScreen.label(Strings.fmt("ui.codex.effects"), &"StrongLabel"))
		add_child(EffectList.make(null, entry.effects))
	var targets: Array[String] = []
	for id: String in entry.links:
		var target: CodexIndex.Entry = _index.entry(id)
		if target != null and target != entry and not targets.has(id):
			targets.append(id)
	if targets.is_empty():
		return
	add_child(FlowScreen.label(Strings.fmt("ui.codex.see_also"), &"StrongLabel"))
	var related: HFlowContainer = HFlowContainer.new()
	related.name = "SeeAlso"
	related.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	add_child(related)
	for id2: String in targets:
		var b: SfButton = SfButton.make("", "ui_codex", SfButton.LINK)
		b.text = _index.entry(id2).title
		b.name = "Link_" + id2.replace(":", "_").replace(".", "_")
		b.pressed.connect(_on_link.bind(id2))
		related.add_child(b)


## A bare link ([url=x]x[/url]) shows its target's title.
func _with_titles(text: String) -> String:
	var re: RegEx = RegEx.create_from_string("\\[url=([a-z_]+:[a-z0-9_.]+)\\]\\1\\[/url\\]")
	var out: String = text
	for m: RegExMatch in re.search_all(text):
		var target: CodexIndex.Entry = _index.entry(m.get_string(1))
		if target != null:
			out = out.replace(m.get_string(0), "[url=%s]%s[/url]" % [m.get_string(1), target.title])
	return out
