extends RefCounted
## Save envelope, checksum, round trip and fixtures (§9.6).

const FIXTURES_DIR: String = "res://tests/fixtures/saves"


func test_round_trip_is_byte_identical(t: T) -> void:
	var s: GameState = TinyState.build()
	var text: String = SaveSerializer.to_text(s, "test")
	t.ne(text, "")
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(text)
	t.ok(lr.ok, lr.error_detail)
	t.eq(SaveSerializer.to_text(lr.state, "test"), text)


func test_envelope_fields(t: T) -> void:
	var s: GameState = TinyState.build(99)
	s.turn = 7
	var env: Dictionary = CanonicalJson.parse(SaveSerializer.to_text(s, "0.1.0"))
	t.eq(env["format"], "starfire-hearth-save")
	t.eq(env["version"], GameState.SCHEMA_VERSION)
	t.eq(env["game_version"], "0.1.0")
	t.eq(env["seed"], 99)
	t.eq(env["turn"], 7)
	t.eq(env["scenario_id"], "test")
	t.eq(env["checksum"], CanonicalJson.sha256_hex(CanonicalJson.stringify(env["state"])))


func test_tampered_state_fails_checksum(t: T) -> void:
	var text: String = SaveSerializer.to_text(TinyState.build(), "test")
	var tampered: String = text.replace("\"pops\":10", "\"pops\":11")
	t.ne(tampered, text, "tamper applied")
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(tampered)
	t.not_ok(lr.ok)
	t.eq(lr.error_key, "save.error.checksum")


func test_rejects_other_files(t: T) -> void:
	t.eq(SaveSerializer.from_text("not json").error_key, "save.error.corrupt")
	t.eq(SaveSerializer.from_text("{\"format\":\"something-else\"}").error_key, "save.error.not_a_save")
	var env: Dictionary = CanonicalJson.parse(SaveSerializer.to_text(TinyState.build(), "test"))
	env["version"] = GameState.SCHEMA_VERSION + 1
	t.eq(SaveSerializer.from_text(CanonicalJson.stringify(env)).error_key, "save.error.too_new")


func test_every_fixture_save_loads(t: T) -> void:
	var dir: DirAccess = DirAccess.open(FIXTURES_DIR)
	t.ne(dir, null, "fixture folder exists")
	if dir == null:
		return
	var count: int = 0
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		count += 1
		var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(FileAccess.get_file_as_string(FIXTURES_DIR.path_join(f)))
		t.ok(lr.ok, "%s: %s %s" % [f, lr.error_key, lr.error_detail])
		if lr.ok:
			t.empty(Invariants.check(lr.state), f)
	t.ok(count >= 1, "at least one fixture save")
