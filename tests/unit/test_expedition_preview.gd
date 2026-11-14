extends RefCounted

func test_exploration_objectives_and_fog(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var e: Empire = s.player()
	var defs: Array[Dictionary] = Objectives.definitions(s)
	t.eq(Objectives.status(s, defs[0]).progress, 0, "home survey does not count")
	e.surveyed_planets.append("pl_vesper")
	t.eq(Objectives.status(s, defs[0]).progress, 1, "frontier survey counts")
	t.eq(Objectives.status(s, defs[2]).progress, 0, "Gate not yet visited")
	e.known_systems["sys_halden"] = Empire.FOG_SURVEYED
	t.eq(Objectives.status(s, defs[2]).progress, 1, "arrival completes visit")
	var galaxy: Dictionary = VisualSnapshotBuilder.galaxy(s)
	for marker: Dictionary in galaxy["systems"]:
		if marker["id"] == "sys_vesper":
			t.not_ok(marker.has("name_key"), "unknown system name is not disclosed")
			t.eq(marker.get("label_key"), "ui.travel.unknown", "unknown star carries a sanitized label")
			t.eq(marker.get("label_args", {}).get("number"), "4", "label matches the destination selector")
	for lane: Dictionary in galaxy["lanes"]:
		t.not_ok(lane["locked"], "preview deep lanes are open")
	var first_light: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 1)
	for lane: Dictionary in VisualSnapshotBuilder.galaxy(first_light)["lanes"]:
		t.ok(lane["locked"], "First Light lanes stay locked")


func test_in_transit_fleet_is_not_drawn_at_departure(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var fleet: Fleet = s.fleets["flt_0001"]
	fleet.path = ["sys_tessel"] as Array[String]
	var snapshot: Dictionary = M1VisualSnapshot.system_view(s, "sys_ember")
	for ship: Dictionary in snapshot["ships"]:
		t.not_ok(fleet.ship_ids.has(ship["id"]), "a departing fleet is not rendered in its origin")


func test_travelling_ships_are_not_reported_idle(t: T) -> void:
	var s: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var before: int = 0
	for item: ReportItem in GameModel.end_turn_checks(s, Economy.empire(s, s.player_id)):
		if item.text_key == "ui.endturn.ship_idle": before += 1
	t.eq(before, 3, "idle civilian ships still produce warnings")
	s.fleets["flt_0001"].path = ["sys_tessel"] as Array[String]
	var after: int = 0
	for item: ReportItem in GameModel.end_turn_checks(s, Economy.empire(s, s.player_id)):
		if item.text_key == "ui.endturn.ship_idle": after += 1
	t.eq(after, 2, "the travelling fleet is no longer marked idle")


func test_arrival_report_formats_the_localized_system_name(t: T) -> void:
	var state: GameState = ScenarioLoader.build(Content.db(), "m2a_expedition", 1)
	var first: TurnResult = TurnProcessor.run(state, [MoveFleetCommand.create(state.player_id, "flt_0001", "sys_tessel")] as Array[Command])
	var result: TurnResult = first
	for unused: int in range(8):
		if result.state.fleets["flt_0001"].path.is_empty(): break
		result = TurnProcessor.run(result.state, [] as Array[Command])
	var arrival: ReportItem = null
	for item: ReportItem in result.report_items:
		if item.text_key == "report.fleet_arrived": arrival = item
	t.ok(arrival != null, "arrival produces a report item")
	if arrival != null:
		t.eq(Strings.fmt(arrival.text_key, arrival.args), "Fleet arrived in Tessel.", "report renders the translated system name")
