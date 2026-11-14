extends RefCounted


func test_visit_condition_and_why_log(t: T) -> void:
	var s: GameState = S1.build()
	var sys: StarSystem = StarSystem.new()
	sys.id = "test_star"
	sys.name_key = "system.test.name"
	s.systems[sys.id] = sys
	var condition: Dictionary = {"visited_system": sys.id}
	t.not_ok(Events.check(s, s.player(), condition, "").ok)
	s.player().known_systems[sys.id] = Empire.FOG_SURVEYED
	var checked: Events.Check = Events.check(s, s.player(), condition, "")
	t.ok(checked.ok)
	t.eq(checked.reasons[0]["key"], "why.cond.visited_system")
	t.eq(checked.reasons[0]["args"]["system_key"], sys.name_key)
	var result: TurnResult = TurnResult.new()
	Events._fire(s, s.player(), "labor_strike", 1, "", "scripted", checked.reasons, result)
	t.eq(result.why_log.entries[0].causes[1].source_key, "why.cond.visited_system")
	t.not_ok(Events.check(s, s.player(), {"visited_system": 8}, "").ok)


func test_validator_checks_type_and_scenario_system_reference(t: T) -> void:
	var validator: DataValidator = DataValidator.new()
	validator.db = Content.db()
	validator._check_trigger({"visited_system": 7}, "test", ["s1_first_light"])
	t.eq(validator.errors().size(), 1)
	validator.issues.clear()
	validator._check_trigger({"visited_system": "not_here"}, "test", ["s1_first_light"])
	t.eq(validator.errors().size(), 1)
	validator.issues.clear()
	validator._check_trigger({"visited_system": "sys_ember"}, "test", ["s1_first_light"])
	t.eq(validator.errors().size(), 0)
