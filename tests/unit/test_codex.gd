extends RefCounted
## The Codex (§6.5): it covers what Scenario 1 shows the player, every link goes somewhere, every
## Codex link a breakdown makes has an entry, the mechanics pages quote live numbers with nothing
## left unfilled, and search and the events seen work.


func test_covers_scenario_1(t: T) -> void:
	var ix: CodexIndex = CodexIndex.build()
	var db: ContentDb = Content.db()
	var scope: Dictionary = DictIO.dict_of(db.scenarios["s1_first_light"], "balance_scope")
	for kind: String in ["districts", "buildings", "techs"]:
		var prefix: String = {"districts": "district:", "buildings": "building:", "techs": "tech:"}[kind]
		for id: Variant in DictIO.arr_of(scope, kind):
			t.ok(ix.has(prefix + str(id)), "%s%s has an entry" % [prefix, id])
	for id2: String in db.ids("resources"):
		t.ok(ix.has("resource:" + id2), "resource %s" % id2)
	for id3: String in ["ark_hull", "spaceport", "market_exchange", "habitat_dome"]:
		t.ok(ix.has("building:" + id3), "building %s" % id3)
	t.not_ok(ix.has("building:planetary_shield"), "military buildings are not in Scenario 1")
	t.not_ok(ix.has("tech:laser_weapons"), "military technologies are not in Scenario 1")
	t.not_ok(ix.has("ordinance:radio_silence"), "a locked ordinance is left out")
	for id4: String in ["survey_probe", "construction_ship", "colony_ship"]:
		t.ok(ix.has("hull:" + id4), "ship %s" % id4)
	for id5: String in ["planet_type:continental", "planet_type:gas_giant", "trait:fertile_soil", "character:archivist_sola"]:
		t.ok(ix.has(id5), id5)
	t.eq(ix.categories().has("events"), false, "no events without a game")


func test_every_link_goes_somewhere(t: T) -> void:
	var ix: CodexIndex = CodexIndex.build()
	var key_re: RegEx = RegEx.create_from_string("^[a-z_]+(\\.[a-z0-9_]+)+$")
	for id: String in ix.entries.keys():
		var e: CodexIndex.Entry = ix.entry(id)
		t.ok(not e.title.is_empty() and key_re.search(e.title) == null, "%s has a title (%s)" % [id, e.title])
		t.ok(not e.summary.is_empty() or not e.prose.is_empty(), "%s has something to say" % id)
		for l: String in ix.links_of(e):
			t.ok(ix.has(l), "%s links to %s" % [id, l])
		t.not_ok(e.prose.contains("{") or e.prose.contains("[["), "%s: no unfilled placeholder or raw link" % id)


func test_every_breakdown_link_has_an_entry(t: T) -> void:
	var ix: CodexIndex = CodexIndex.build()
	var re: RegEx = RegEx.create_from_string("\"(mechanic:[a-z_]+)\"")
	var found: int = 0
	for f: String in _scripts(["res://sim", "res://ui", "res://app"]):
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			found += 1
			t.ok(ix.has(m.get_string(1)), "%s (linked from %s) has an entry" % [m.get_string(1), f.get_file()])
	t.ok(found >= 20, "found the breakdowns' Codex links (%d)" % found)


func test_mechanics_quote_live_numbers(t: T) -> void:
	var ix: CodexIndex = CodexIndex.build()
	var stab: CodexIndex.Entry = ix.entry("mechanic:stability")
	t.ok(stab != null and stab.prose.contains(str(Stability.BASE)), "stability quotes its base from the rules")
	var growth: CodexIndex.Entry = ix.entry("mechanic:growth")
	t.ok(growth != null and growth.prose.contains("%dk" % ColonyRules.CITY_AT), "growth quotes the City threshold")
	var hydro: CodexIndex.Entry = ix.entry("building:hydroponics_bay")
	t.ok(hydro != null and not hydro.cost.is_empty(), "buildings carry their cost from the data")


func test_search_and_events_seen(t: T) -> void:
	var ix: CodexIndex = CodexIndex.build()
	t.eq(ix.search("").size(), 0, "an empty search finds nothing")
	var found: Array[CodexIndex.Entry] = ix.search("STABILITY")
	t.ok(found.size() >= 3, "search ignores case and looks in the text (%d found)" % found.size())
	t.eq(ix.search("zzzz nothing").size(), 0)
	var st: GameState = S1.build(4)
	var le: EventLogEntry = EventLogEntry.new()
	le.turn = 5
	le.chain = "labor_strike"
	le.step = 1
	le.colony_id = S1.aster(st).id
	le.choice = 0
	st.event_log.append(le)
	var ix2: CodexIndex = CodexIndex.build(st)
	var ev: CodexIndex.Entry = ix2.entry("event:labor_strike.1")
	t.ok(ev != null, "a seen event step has an entry")
	if ev != null:
		t.not_ok(ev.prose.is_empty() or ev.prose.contains("{"), "its text is filled in")
		t.eq(ev.portrait, "steward_varga", "with its speaker")


func _scripts(roots: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for r: String in roots:
		_collect(r, out)
	return out


func _collect(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
