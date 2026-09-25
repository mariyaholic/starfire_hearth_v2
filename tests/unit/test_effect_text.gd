extends RefCounted
## Effect descriptions (EffectText + the string layer) and the M1 display components built on
## them: effect lists, cost chips, and the story scene and portrait placeholders.


func test_effects_read_as_plain_english(t: T) -> void:
	var s: GameState = S1.build()
	var fx: Array = [
		{"key": "stability_add", "value": 5, "turns": 10, "target": "colony"},
		{"key": "add_pops", "value": 6, "over_turns": 10},
		{"key": "research_bp:all", "value": 1000},
		{"key": "add_stock:food", "value": -2500},
		{"key": "set_flag", "value": 1, "target": "hidden"},
	]
	var lines: Array[EffectText.Line] = EffectText.describe_all(s, fx, S1.aster(s).id)
	t.eq(lines.size(), 4, "flags have nothing to say")
	t.eq(EffectList.text_of(lines[0]), "+5 stability on Aster for 10 turns")
	t.eq(EffectList.text_of(lines[1]), "+6k settlers over 10 turns")
	t.eq(EffectList.text_of(lines[2]), "+10% research for good")
	t.eq(EffectList.text_of(lines[3]), "−25 Food")
	t.not_ok(lines[3].good)


func test_every_event_choice_effect_can_be_described(t: T) -> void:
	var s: GameState = S1.build()
	var silent: Array[String] = ["set_flag", "clear_flag", "spawn_event"]
	for cid: String in DictIO.sorted_keys(Content.db().events):
		for step: Variant in DictIO.arr_of(Content.db().events[cid], "steps"):
			for ch: Variant in DictIO.arr_of(step, "choices"):
				var all: Array = DictIO.arr_of(ch, "effects").duplicate()
				for oc: Variant in DictIO.arr_of(ch, "outcomes"):
					all.append_array(DictIO.arr_of(oc, "effects"))
				for fx: Variant in all:
					var key: String = DictIO.str_of(fx, "key")
					if silent.has(key):
						continue
					var line: EffectText.Line = EffectText.describe(s, fx)
					t.ne(line, null, "%s: %s has a description" % [cid, key])
					if line != null:
						var text: String = EffectList.text_of(line)
						t.not_ok(text.contains("{") or text.contains("}"), "%s: %s" % [cid, text])


func test_components_build_from_data(t: T) -> void:
	var s: GameState = S1.build()
	var chips: CostChips = CostChips.make({"influence": 2000, "energy": 6000}, s.player().stock, true)
	t.eq(chips.get_child_count(), 2)
	chips.free()
	var scene: StoryScene = StoryScene.make("labor_strike")
	t.eq(scene.vignette_id, "labor_strike")
	scene.free()
	var p: Portrait = Portrait.make("steward_varga", "worried")
	t.eq(p.expression, "worried")
	p.free()
	var odd: Portrait = Portrait.make("archivist_sola", "furious")
	t.eq(odd.expression, "neutral", "an unknown expression falls back to neutral")
	odd.free()
	t.ok(AssetIds.texture("labor_strike") != null, "a delivered scene has its painting")
	t.eq(AssetIds.texture("quiet_lane"), null, "a scene not delivered yet draws its placeholder")
