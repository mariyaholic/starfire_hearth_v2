class_name PendingScreen
extends FlowScreen
## Stands in for the game screen until it is built (the next M1 screen task), so the flow from the
## title to the debrief can be walked and tested now. It says what is missing, names the game that
## was started, and leads back to the title.


static func make() -> PendingScreen:
	var s: PendingScreen = PendingScreen.new()
	s.name = "PendingScreen"
	s.back_route = AppRoot.TITLE
	return s


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.pending.title")))
	var c: Card = Card.make("")
	c.add_text(Strings.fmt("ui.pending.game"), &"SecondaryLabel")
	if Game.has_game():
		var st: GameState = Game.state
		var rec: Dictionary = Content.db().scenarios.get(st.scenario_id, {})
		var l: Label = c.add_text(Strings.fmt("ui.pending.current", {"scenario_key": DictIO.str_of(rec, "name_key", "ui.title.unknown_scenario"), "date": Fmt.date(st.turn), "difficulty_key": DictIO.str_of(Content.db().record("difficulty", st.difficulty_id), "name_key", "difficulty.normal.name")}), &"CaptionLabel")
		l.name = "CurrentGame"
		l.set_meta("audit_numeric_ok", "the running game's date")
	col.add_child(FlowScreen.scroll_of(c))
