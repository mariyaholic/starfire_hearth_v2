class_name BriefingScreen
extends FlowScreen
## The scenario briefing (§7 screen 15): the advisor's portrait and the briefing, the objectives
## (required, then optional), the difficulty, and Begin, which starts a new game. Archivist Sola is
## the advisor voice of the campaign (§4.6).

const ADVISOR: String = "archivist_sola"

var progress: CampaignProgress
var scenario_id: String = ""


static func make(p_progress: CampaignProgress, p_scenario_id: String) -> BriefingScreen:
	var s: BriefingScreen = BriefingScreen.new()
	s.name = "BriefingScreen"
	s.progress = p_progress
	s.scenario_id = p_scenario_id
	s.back_route = AppRoot.CAMPAIGN
	return s


func scenario() -> Dictionary:
	return Content.db().scenarios.get(scenario_id, {})


func build_screen() -> void:
	var rec: Dictionary = scenario()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	var begin: SfButton = SfButton.make("ui.briefing.begin", "ui_play", SfButton.PRIMARY)
	begin.name = "Begin"
	begin.pressed.connect(go.bind(AppRoot.BEGIN, {"scenario": scenario_id}))
	if not Layout.touch_ui:
		begin.grab_focus.call_deferred()
	# Phones put Begin in the heading row, leaving the rest of the short screen to the briefing.
	var actions: Array[Control] = []
	if Layout.compact:
		actions.append(begin)
	col.add_child(header(Strings.fmt(DictIO.str_of(rec, "name_key", "ui.title.unknown_scenario")), Strings.fmt("ui.briefing.kicker"), actions))
	var story: Card = _story_card(rec)
	var goals: Card = _objectives_card(rec)
	if Layout.compact:
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", Tokens.SPACE_L)
		v.add_child(story)
		v.add_child(goals)
		col.add_child(FlowScreen.scroll_of(v))
	else:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_XL)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		story.size_flags_stretch_ratio = 1.4
		story.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goals.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(story)
		row.add_child(goals)
		col.add_child(FlowScreen.scroll_of(row))
		var footer: HBoxContainer = HBoxContainer.new()
		footer.name = "Footer"
		footer.alignment = BoxContainer.ALIGNMENT_END
		footer.add_child(begin)
		col.add_child(footer)


func _story_card(rec: Dictionary) -> Card:
	var c: Card = Card.make("")
	c.name = "Story"
	var who: HBoxContainer = HBoxContainer.new()
	who.add_theme_constant_override("separation", Tokens.SPACE_M)
	var p: Portrait = Portrait.make(ADVISOR, "neutral", 64.0 if Layout.compact else 96.0)
	p.name = "Advisor"
	who.add_child(p)
	var name_col: VBoxContainer = VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(Content.db().record("portraits", ADVISOR), "name_key")), &"StrongLabel"))
	name_col.add_child(FlowScreen.label(Strings.fmt("ui.briefing.advisor_role"), &"CaptionLabel"))
	who.add_child(name_col)
	c.add_body(who)
	var text: Label = c.add_text(Strings.fmt(DictIO.str_of(rec, "briefing_key", "ui.briefing.none")))
	text.name = "Briefing"
	text.set_meta("audit_numeric_ok", "story prose (the in-world date)")
	return c


func _objectives_card(rec: Dictionary) -> Card:
	var c: Card = Card.make(Strings.fmt("ui.briefing.objectives"), Strings.fmt("ui.briefing.objectives_hint"), "ui_objective", "hearth.gold")
	c.name = "Objectives"
	var objs: Dictionary = DictIO.dict_of(rec, "objectives")
	for v: Variant in DictIO.arr_of(objs, "required"):
		c.add_body(objective_row(Strings.fmt(DictIO.str_of(v as Dictionary, "text_key")), "ui_objective", "hearth.gold"))
	var optional: Array = DictIO.arr_of(objs, "optional")
	if not optional.is_empty():
		c.add_body(FlowScreen.label(Strings.fmt("ui.briefing.optional"), &"StrongLabel"))
		for v2: Variant in optional:
			c.add_body(objective_row(Strings.fmt(DictIO.str_of(v2 as Dictionary, "text_key")), "ui_star", "text.secondary"))
	var diff: Dictionary = Content.db().record("difficulty", progress.difficulty_id)
	c.add_body(HSeparator.new())
	var d: Label = FlowScreen.label(Strings.fmt("ui.briefing.difficulty", {"name_key": DictIO.str_of(diff, "name_key", "difficulty.normal.name"), "desc_key": DictIO.str_of(diff, "desc_key", "difficulty.normal.desc")}), &"CaptionLabel")
	d.name = "DifficultyLine"
	c.add_body(d)
	return c


## One objective: an icon (shape says required or optional) and the objective's words.
static func objective_row(text: String, icon: String, token: String) -> HBoxContainer:
	var r: HBoxContainer = HBoxContainer.new()
	r.add_theme_constant_override("separation", Tokens.SPACE_S)
	var i: SfIcon = SfIcon.make(icon, Tokens.ICON_M, token)
	i.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.add_child(i)
	var l: Label = FlowScreen.label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# An objective states its target in words ("Develop 3 colonies"); its live progress is
	# explained in the game's Objectives view.
	l.set_meta("audit_numeric_ok", "an objective's target, stated in words")
	r.add_child(l)
	return r
