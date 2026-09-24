extends RefCounted
## Data validation (§9.8): the real data passes, and the validator really catches problems.

const BAD_DATA: String = "res://tests/fixtures/bad_data"


func test_real_data_is_valid(t: T) -> void:
	var rep: DataChecks.Report = DataChecks.run()
	t.empty(rep.errors, "validate_data errors")
	t.ok(rep.records >= 40, "records loaded: %d" % rep.records)


func test_every_resource_has_two_sinks(t: T) -> void:
	var db: ContentDb = ContentDb.load_from()
	for id: String in db.ids("resources"):
		t.ok(DictIO.arr_of(db.record("resources", id), "sinks").size() >= 2, id)


func test_numbers_load_as_ints(t: T) -> void:
	var db: ContentDb = ContentDb.load_from()
	var cost: Dictionary = db.record("districts", "agriculture")["cost"]
	t.eq(typeof(cost["minerals"]), TYPE_INT)
	t.eq(cost["minerals"], 6000, "60.00 minerals")


func test_validator_catches_broken_data(t: T) -> void:
	var db: ContentDb = ContentDb.load_from(BAD_DATA)
	var v: DataValidator = DataValidator.run(db, StringTable.load_csv())
	var text: String = ""
	for i: Dictionary in v.errors():
		text += "%s: %s\n" % [i["where"], i["message"]]
	t.ok(text.contains("at least 2 competing sinks"), "one-sink resource is caught")
	t.ok(text.contains("unknown field \"colour\""), "typo field is caught")
	t.ok(text.contains("is not a known jobs id"), "broken reference is caught")
	t.ok(text.contains("missing from strings/en.csv"), "missing string key is caught")
	t.ok(text.contains("closed set of effect keys"), "unknown effect key is caught")
	t.ok(text.contains("\"4.001\" is not an amount"), "bad authoring amount is caught")
	t.ok(text.contains("missing file"), "missing data file is caught")


func test_authoring_amounts_convert(t: T) -> void:
	var db: ContentDb = ContentDb.load_from(BAD_DATA)
	t.eq(db.record("districts", "quarry")["cost"]["minerals"], 5050, "\"50.50\" -> 5050")


func test_effect_keys(t: T) -> void:
	t.ok(EffectKeys.is_valid("stability_add"))
	t.ok(EffectKeys.is_valid("resource_output_bp:food"))
	t.ok(EffectKeys.is_valid("research_bp:all"))
	t.not_ok(EffectKeys.is_valid("resource_output_bp:"), "parameter required")
	t.not_ok(EffectKeys.is_valid("make_everything_free"))
