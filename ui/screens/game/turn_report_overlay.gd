class_name TurnReportOverlay
extends RefCounted
## The turn report (§6.6) and the End Turn checklist: the three things that matter most, then
## everything else by topic, each line with an arrow that jumps to what it is about, and a
## breakdown where the line has one. The checklist is the same list of what still wants an order.

const CATEGORY_KEYS: Dictionary[String, String] = {
	"colonies": "ui.report.category.colonies", "research": "ui.report.category.research",
	"fleets": "ui.report.category.fleets", "diplomacy": "ui.report.category.diplomacy",
	"story": "ui.report.category.story",
}


## Opens the report; `on_close` runs when the player closes it (events come next). `turn` (when
## above zero) puts the date first, as a number that explains itself.
static func open_report(s: GameScreen, items: Array[ReportItem], title: String, on_close: Callable, turn: int = 0) -> Modal:
	var m: Modal = Modal.make(title)
	m.name = "TurnReport"
	if turn > 0:
		var date: Label = GameUI.tag(Fmt.date(turn), &"StrongLabel")
		date.name = "ReportDate"
		m.body.add_child(Explainable.wrap(date, GameModel.turn_breakdown(turn)))
	if items.is_empty():
		m.body.add_child(FlowScreen.label(Strings.fmt("ui.report.nothing"), &"SecondaryLabel"))
	var top: Array[ReportItem] = ReportBuilder.top(items)
	for it: ReportItem in top:
		m.body.add_child(_row(s, it, true))
	var groups: Dictionary[String, Array] = ReportBuilder.grouped(items)
	for cat: String in ReportItem.CATEGORIES:
		if not groups.has(cat):
			continue
		var rest: Array[ReportItem] = []
		for v: Variant in groups[cat]:
			if not top.has(v):
				rest.append(v)
		if rest.is_empty():
			continue
		var h: Label = GameUI.caption(Strings.fmt(CATEGORY_KEYS[cat]).to_upper())
		m.body.add_child(h)
		for it: ReportItem in rest:
			m.body.add_child(_row(s, it, false))
	var ok: SfButton = SfButton.make("ui.report.continue", "ui_check", SfButton.PRIMARY)
	ok.name = "Continue"
	ok.pressed.connect(m.close)
	m.add_action(ok)
	m.dismissed.connect(func() -> void:
		s.ui_event("report_closed")
		if on_close.is_valid():
			on_close.call_deferred())
	m.open()
	return m


## What still wants an order. Ending the turn anyway is the player's call.
static func open_checklist(s: GameScreen, items: Array[ReportItem], on_confirm: Callable) -> Modal:
	var m: Modal = Modal.make(Strings.fmt("ui.endturn.title"))
	m.name = "EndTurnChecklist"
	for it: ReportItem in items:
		m.body.add_child(_row(s, it, false))
	var back: SfButton = SfButton.make("ui.endturn.back", "ui_back", SfButton.GHOST)
	back.name = "GoBack"
	back.sound = "ui_cancel"
	back.pressed.connect(m.close)
	m.add_action(back)
	var go: SfButton = SfButton.make("ui.endturn.anyway", "ui_end_turn", SfButton.PRIMARY)
	go.name = "EndAnyway"
	go.pressed.connect(func() -> void:
		m.close()
		if on_confirm.is_valid():
			on_confirm.call_deferred())
	m.add_action(go)
	m.open()
	return m


static func _row(s: GameScreen, it: ReportItem, strong: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	var icon: SfIcon = SfIcon.make(Toast.ICONS.get(it.severity, "alert_info"), Tokens.ICON_M, Toast.COLORS.get(it.severity, "accent.teal"))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l: Label = FlowScreen.label(Strings.fmt(it.text_key, it.args), &"StrongLabel" if strong else &"")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var content: Control = l
	if it.breakdown != null:
		content = Explainable.wrap(l, it.breakdown, false)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# The report says what happened, with the numbers that changed.
		l.set_meta("audit_numeric_ok", "a report line states what happened")
	row.add_child(content)
	if not it.focus_kind.is_empty():
		var kind: String = it.focus_kind
		var id: String = it.focus_id
		var jump: SfButton = SfButton.make_icon("ui_chevron_right", "ui.report.jump")
		jump.pressed.connect(func() -> void:
			s.ui_event("report_closed")
			s.jump(kind, id))
		row.add_child(jump)
	return row
