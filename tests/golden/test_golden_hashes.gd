extends RefCounted
## Golden per-turn state hashes (§9.8). A mismatch means the simulation's output changed: either a
## bug, or an intended change that needs tools/regen_golden.gd and a CHANGELOG entry.


func test_tiny_fixture_hashes_match_golden(t: T) -> void:
	var text: String = FileAccess.get_file_as_string(GoldenScript.TINY_PATH)
	t.ne(text, "", "golden file exists; create it with tools/regen_golden.gd")
	if text.is_empty():
		return
	var golden: Dictionary = CanonicalJson.parse(text)
	var expected: Array = golden["hashes"]
	var got: Array[String] = GoldenScript.tiny_hashes()
	t.eq(got.size(), expected.size(), "turn count")
	for i in mini(got.size(), expected.size()):
		if got[i] != expected[i]:
			t.fail("hash differs first at turn %d" % i)
			return


func test_s1_hashes_match_golden(t: T) -> void:
	var text: String = FileAccess.get_file_as_string(GoldenScript.S1_PATH)
	t.ne(text, "", "golden file exists; create it with tools/regen_golden.gd")
	if text.is_empty():
		return
	var expected: Array = CanonicalJson.parse(text)["hashes"]
	var got: Array[String] = GoldenScript.s1_hashes()
	t.eq(got.size(), expected.size(), "turn count")
	for i in mini(got.size(), expected.size()):
		if got[i] != expected[i]:
			t.fail("Scenario 1 hash differs first at turn %d" % i)
			return


func test_s1_survives_save_and_load_every_turn(t: T) -> void:
	var live: Array[String] = GoldenScript.s1_hashes()
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", GoldenScript.S1_SEED)
	var reloaded: Array[String] = [state.state_hash()]
	for turn in GoldenScript.S1_TURNS:
		var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(state, "test"))
		state = lr.state
		var r: TurnResult = TurnProcessor.run(state, GoldenScript.s1_commands(turn, state))
		state = r.state
		reloaded.append(r.state_hash)
	t.eq(reloaded, live, "Scenario 1 saved and loaded every turn stays on the same hashes")


func test_hashes_survive_save_and_load_every_turn(t: T) -> void:
	var live: Array[String] = GoldenScript.tiny_hashes()
	var state: GameState = TinyState.build(GoldenScript.TINY_SEED)
	var reloaded: Array[String] = [state.state_hash()]
	for turn in GoldenScript.TINY_TURNS:
		var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(state, "test"))
		state = lr.state
		var r: TurnResult = TurnProcessor.run(state, GoldenScript.commands_for(turn))
		state = r.state
		reloaded.append(r.state_hash)
	t.eq(reloaded, live, "a game saved and loaded every turn stays on the same hashes")
