class_name CodexIndex
extends RefCounted
## Every Codex entry (§6.5), built from the data files plus the prose in data/codex/*.md, so each
## entry shows the game's own numbers. This is the Scenario 1 subset: its mechanics, resources,
## districts, the buildings and technologies it can offer, its ordinances and civilian ships, the
## worlds and traits of Ember, its cast, and (with a game running) every event step already seen.
## Entry ids are "<kind>:<id>", the form breakdowns use for their Codex links.

const SCENARIO: String = "s1_first_light"
const PROSE_DIR: String = "res://data/codex"
const CATEGORIES: Array[String] = ["mechanics", "resources", "districts", "buildings", "techs", "ordinances", "ships", "worlds", "people", "events"]
## Category -> the string key of its name.
const CATEGORY_KEYS: Dictionary[String, String] = {
	"mechanics": "ui.codex.cat.mechanics", "resources": "ui.codex.cat.resources",
	"districts": "ui.codex.cat.districts", "buildings": "ui.codex.cat.buildings",
	"techs": "ui.codex.cat.techs", "ordinances": "ui.codex.cat.ordinances",
	"ships": "ui.codex.cat.ships", "worlds": "ui.codex.cat.worlds",
	"people": "ui.codex.cat.people", "events": "ui.codex.cat.events",
}
## The mechanics each resource leads to.
const RESOURCE_LINKS: Dictionary[String, Array] = {
	"food": ["mechanic:food", "mechanic:famine", "mechanic:growth"],
	"energy": ["mechanic:upkeep", "mechanic:shortage", "mechanic:market"],
	"minerals": ["mechanic:construction", "mechanic:industry", "mechanic:governors"],
	"alloys": ["mechanic:industry", "mechanic:market"],
	"influence": ["mechanic:influence", "mechanic:ordinances", "mechanic:outposts"],
	"research": ["mechanic:research"],
}
const ROLE_LINKS: Dictionary[String, String] = {"survey": "mechanic:outposts", "construction": "mechanic:outposts", "colony": "mechanic:colonies"}
## The campaign cast of Scenario 1 and the string key of each biography.
const HAB_KEYS: Dictionary[String, String] = {
	"open": "ui.codex.habitability.open", "domes": "ui.codex.habitability.domes",
	"orbital": "ui.codex.habitability.orbital", "outpost": "ui.codex.habitability.outpost",
}
const PEOPLE: Dictionary[String, String] = {"archivist_sola": "character.sola.bio", "steward_varga": "character.varga.bio", "captain_brandt": "character.brandt.bio"}


class Entry:
	extends RefCounted
	var id: String = ""
	var category: String = ""
	var title: String = ""
	var icon: String = ""
	var icon_token: String = "accent.teal"
	## The one-paragraph description.
	var summary: String = ""
	## Longer text with [url=<entry id>] links, for mechanics and events.
	var prose: String = ""
	## [label, value] pairs of plain facts from the data.
	var facts: Array[PackedStringArray] = []
	var cost: Dictionary = {}
	var effects: Array = []
	var links: Array[String] = []
	var portrait: String = ""
	var story: bool = false


var entries: Dictionary[String, Entry] = {}
var _order: Array[String] = []
var _facts: Dictionary[String, String] = {}


## The index for now: data entries, plus the events seen in `state` when a game is running.
static func build(state: GameState = null) -> CodexIndex:
	var ix: CodexIndex = CodexIndex.new()
	ix._facts = CodexFacts.values()
	ix._mechanics()
	ix._resources()
	ix._districts()
	ix._buildings()
	ix._techs()
	ix._ordinances()
	ix._ships()
	ix._worlds()
	ix._people()
	if state != null:
		ix._events(state)
	return ix


func has(id: String) -> bool:
	return entries.has(id)


func entry(id: String) -> Entry:
	return entries.get(id, null)


## Entries of a category, in data order (mechanics alphabetically by title).
func in_category(category: String) -> Array[Entry]:
	var out: Array[Entry] = []
	for id: String in _order:
		if entries[id].category == category:
			out.append(entries[id])
	return out


## Categories that have at least one entry.
func categories() -> Array[String]:
	var out: Array[String] = []
	for c: String in CATEGORIES:
		if not in_category(c).is_empty():
			out.append(c)
	return out


## Entries whose title, summary or text contain every word of the query (any case).
func search(query: String) -> Array[Entry]:
	var out: Array[Entry] = []
	var words: PackedStringArray = query.to_lower().split(" ", false)
	if words.is_empty():
		return out
	for id: String in _order:
		var e: Entry = entries[id]
		var hay: String = (e.title + " " + e.summary + " " + e.prose).to_lower()
		var all: bool = true
		for w: String in words:
			if not hay.contains(w):
				all = false
				break
		if all:
			out.append(e)
	return out


## Every link an entry makes (its related list and the links in its prose).
func links_of(e: Entry) -> Array[String]:
	var out: Array[String] = e.links.duplicate()
	var re: RegEx = RegEx.create_from_string("\\[url=([a-z_]+:[a-z0-9_.]+)\\]")
	for m: RegExMatch in re.search_all(e.prose):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


# --- builders -----------------------------------------------------------------------------------

func _add(e: Entry) -> Entry:
	entries[e.id] = e
	_order.append(e.id)
	return e


func _make(id: String, category: String, name_key: String, desc_key: String, icon: String) -> Entry:
	var e: Entry = Entry.new()
	e.id = id
	e.category = category
	e.title = Strings.fmt(name_key)
	e.summary = Strings.fmt(desc_key) if not desc_key.is_empty() else ""
	e.icon = icon
	return e


func _mechanics() -> void:
	var files: Array[String] = []
	for f: String in DirAccess.get_files_at(PROSE_DIR):
		if f.ends_with(".md"):
			files.append(f)
	var made: Array[Entry] = []
	for f2: String in files:
		var text: String = FileAccess.get_file_as_string(PROSE_DIR.path_join(f2))
		var e: Entry = Entry.new()
		e.id = "mechanic:" + f2.get_basename()
		e.category = "mechanics"
		e.icon = "ui_codex"
		var paragraphs: PackedStringArray = PackedStringArray()
		for block: String in text.strip_edges().split("\n\n", false):
			var b: String = block.strip_edges()
			if b.begins_with("# "):
				e.title = b.trim_prefix("# ").strip_edges()
			else:
				paragraphs.append(b.replace("\n", " "))
		e.prose = _links_to_bbcode(CodexFacts.fill("\n\n".join(paragraphs), _facts))
		e.summary = ""
		made.append(e)
	made.sort_custom(func(a: Entry, b: Entry) -> bool: return a.title < b.title)
	for e2: Entry in made:
		_add(e2)


## [[kind:id|label]] and [[kind:id]] become [url=kind:id]label[/url]; the bare form shows the
## target's title, resolved when the text is shown.
static func _links_to_bbcode(text: String) -> String:
	var re: RegEx = RegEx.create_from_string("\\[\\[([a-z_]+:[a-z0-9_.]+)(?:\\|([^\\]]+))?\\]\\]")
	var out: String = text
	for m: RegExMatch in re.search_all(text):
		var label: String = m.get_string(2) if not m.get_string(2).is_empty() else m.get_string(1)
		out = out.replace(m.get_string(0), "[url=%s]%s[/url]" % [m.get_string(1), label])
	return out


func _resources() -> void:
	var db: ContentDb = Content.db()
	for id: String in db.ids("resources"):
		var r: Dictionary = db.record("resources", id)
		var e: Entry = _make("resource:" + id, "resources", DictIO.str_of(r, "name_key"), DictIO.str_of(r, "desc_key"), DictIO.str_of(r, "icon"))
		e.icon_token = DictIO.str_of(r, "color", "accent.teal")
		var unit_key: String = DictIO.str_of(r, "unit_key")
		if not unit_key.is_empty():
			e.facts.append(_fact("ui.codex.fact.unit", Strings.fmt(unit_key)))
		if DictIO.int_of(r, "cap") > 0:
			e.facts.append(_fact("ui.codex.fact.storage", _amount(DictIO.int_of(r, "cap"), id)))
		e.facts.append(_fact("ui.codex.fact.tradable", Strings.fmt("ui.codex.yes" if DictIO.bool_of(r, "tradable") else "ui.codex.no")))
		for l: Variant in RESOURCE_LINKS.get(id, []):
			e.links.append(str(l))
		_add(e)


func _districts() -> void:
	var db: ContentDb = Content.db()
	for id: String in db.ids("districts"):
		var d: Dictionary = db.record("districts", id)
		var e: Entry = _make("district:" + id, "districts", DictIO.str_of(d, "name_key"), DictIO.str_of(d, "desc_key"), DictIO.str_of(d, "icon"))
		e.cost = DictIO.dict_of(d, "cost")
		e.facts.append(_fact("ui.codex.fact.build_time", Strings.fmt("ui.codex.turns", {"turns": DictIO.int_of(d, "build_turns")})))
		_upkeep_fact(e, DictIO.dict_of(d, "upkeep"))
		e.facts.append(_fact("ui.codex.fact.housing", Strings.fmt("ui.codex.homes", {"count": DictIO.int_of(d, "housing")})))
		for j: Variant in DictIO.arr_of(d, "jobs"):
			var jd: Dictionary = j
			var job: Dictionary = db.record("jobs", DictIO.str_of(jd, "job"))
			e.facts.append(_fact("ui.codex.fact.jobs", Strings.fmt("ui.codex.job_line", {"count": DictIO.int_of(jd, "count"), "job_key": DictIO.str_of(job, "name_key"), "output": _outputs(DictIO.dict_of(job, "output"))})))
		for t: Variant in DictIO.arr_of(d, "tiers"):
			var tech: String = DictIO.str_of(t as Dictionary, "requires_tech")
			if _s1_tech(tech):
				e.links.append("tech:" + tech)
		e.links.append("mechanic:jobs")
		if not DictIO.arr_of(d, "adjacency").is_empty():
			e.links.append("mechanic:adjacency")
		e.links.append("mechanic:tiers")
		_add(e)


func _buildings() -> void:
	var db: ContentDb = Content.db()
	var start: Array[String] = _start_buildings()
	for id: String in db.ids("buildings"):
		var b: Dictionary = db.record("buildings", id)
		var tech: String = DictIO.str_of(b, "unlock_tech")
		var in_s1: bool = start.has(id) or (tech.is_empty() and not DictIO.bool_of(b, "landmark")) or _s1_tech(tech)
		if not in_s1:
			continue
		var e: Entry = _make("building:" + id, "buildings", DictIO.str_of(b, "name_key"), DictIO.str_of(b, "desc_key"), DictIO.str_of(b, "icon"))
		e.icon_token = "hearth.gold"
		e.cost = DictIO.dict_of(b, "cost")
		e.effects = DictIO.arr_of(b, "effects")
		e.story = DictIO.bool_of(b, "story")
		if DictIO.int_of(b, "build_turns") > 0:
			e.facts.append(_fact("ui.codex.fact.build_time", Strings.fmt("ui.codex.turns", {"turns": DictIO.int_of(b, "build_turns")})))
		_upkeep_fact(e, DictIO.dict_of(b, "upkeep"))
		match DictIO.str_of(b, "unique"):
			"colony":
				e.facts.append(_fact("ui.codex.fact.limit", Strings.fmt("ui.codex.one_per_colony")))
			"empire":
				e.facts.append(_fact("ui.codex.fact.limit", Strings.fmt("ui.codex.one_in_empire")))
		if DictIO.bool_of(b, "landmark"):
			e.facts.append(_fact("ui.codex.fact.landmark", Strings.fmt("ui.codex.landmark")))
		if not tech.is_empty():
			e.facts.append(_fact("ui.codex.fact.unlocked_by", Strings.fmt(DictIO.str_of(db.record("techs", tech), "name_key"))))
			e.links.append("tech:" + tech)
		if id == "market_exchange":
			e.links.append("mechanic:market")
		if id == "habitat_dome":
			e.links.append("mechanic:habitability")
		e.links.append("mechanic:construction")
		_add(e)


func _techs() -> void:
	var db: ContentDb = Content.db()
	for id: String in db.ids("techs"):
		if not _s1_tech(id):
			continue
		var t: Dictionary = db.record("techs", id)
		var branch: String = DictIO.str_of(t, "branch")
		var e: Entry = _make("tech:" + id, "techs", DictIO.str_of(t, "name_key"), DictIO.str_of(t, "desc_key"), "branch_" + branch)
		e.icon_token = "sci.cyan"
		e.effects = DictIO.arr_of(t, "effects")
		e.story = DictIO.bool_of(t, "story")
		var tier: int = DictIO.int_of(t, "tier", 1)
		e.facts.append(_fact("ui.codex.fact.branch", Strings.fmt(Names.branch(branch))))
		e.facts.append(_fact("ui.codex.fact.tier", str(tier)))
		e.facts.append(_fact("ui.codex.fact.research_cost", Strings.fmt("ui.codex.research_cost", {"cost": Strings.centi(int(Research.TIER_COST.get(tier, 0)))})))
		if e.story:
			e.facts.append(_fact("ui.codex.fact.story", Strings.fmt("ui.codex.story_tech")))
		for p: Variant in DictIO.arr_of(t, "prereqs"):
			e.facts.append(_fact("ui.codex.fact.needs", Strings.fmt(DictIO.str_of(db.record("techs", str(p)), "name_key"))))
			e.links.append("tech:" + str(p))
		for bid: String in db.ids("buildings"):
			if DictIO.str_of(db.record("buildings", bid), "unlock_tech") == id:
				e.facts.append(_fact("ui.codex.fact.unlocks", Strings.fmt(DictIO.str_of(db.record("buildings", bid), "name_key"))))
				e.links.append("building:" + bid)
		for d: Variant in DictIO.arr_of(db.record("districts", "habitation"), "tiers"):
			if DictIO.str_of(d as Dictionary, "requires_tech") == id:
				e.facts.append(_fact("ui.codex.fact.unlocks", Strings.fmt("ui.codex.tier_unlock", {"tier": DictIO.int_of(d as Dictionary, "tier")})))
				e.links.append("mechanic:tiers")
		e.links.append("mechanic:research")
		_add(e)


func _ordinances() -> void:
	var db: ContentDb = Content.db()
	var locked: Array = DictIO.arr_of(_scenario(), "locked_ordinances")
	for id: String in db.ids("edicts"):
		if locked.has(id):
			continue
		var o: Dictionary = db.record("edicts", id)
		var e: Entry = _make("ordinance:" + id, "ordinances", DictIO.str_of(o, "name_key"), DictIO.str_of(o, "desc_key"), DictIO.str_of(o, "icon", "ui_edict"))
		e.icon_token = "influence.violet"
		e.cost = DictIO.dict_of(o, "activation")
		e.effects = DictIO.arr_of(o, "effects")
		_upkeep_fact(e, DictIO.dict_of(o, "upkeep"))
		e.facts.append(_fact("ui.codex.fact.duration", Strings.fmt("ui.codex.turns", {"turns": DictIO.int_of(o, "duration")})))
		e.links.append("mechanic:ordinances")
		_add(e)


func _ships() -> void:
	var db: ContentDb = Content.db()
	for id: String in db.ids("hulls"):
		var h: Dictionary = db.record("hulls", id)
		if DictIO.str_of(h, "class") != "civilian":
			continue
		var e: Entry = _make("hull:" + id, "ships", DictIO.str_of(h, "name_key"), DictIO.str_of(h, "desc_key"), DictIO.str_of(h, "icon"))
		e.cost = DictIO.dict_of(h, "cost")
		e.facts.append(_fact("ui.codex.fact.build_time", Strings.fmt("ui.codex.turns", {"turns": DictIO.int_of(h, "build_turns")})))
		_upkeep_fact(e, DictIO.dict_of(h, "upkeep"))
		var role: String = DictIO.str_of(h, "role")
		e.facts.append(_fact("ui.codex.fact.role", Strings.fmt(Names.ship_role(role))))
		if ROLE_LINKS.has(role):
			e.links.append(ROLE_LINKS[role])
		_add(e)


func _worlds() -> void:
	var db: ContentDb = Content.db()
	var types: Array[String] = []
	var traits: Array[String] = []
	for sys: Variant in DictIO.arr_of(DictIO.dict_of(_scenario(), "map"), "systems"):
		for p: Variant in DictIO.arr_of(sys as Dictionary, "planets"):
			var pd: Dictionary = p
			if not types.has(DictIO.str_of(pd, "type")):
				types.append(DictIO.str_of(pd, "type"))
			for tr: Variant in DictIO.arr_of(pd, "traits"):
				if not traits.has(str(tr)):
					traits.append(str(tr))
	for id: String in db.ids("planet_types"):
		if not types.has(id):
			continue
		var t: Dictionary = db.record("planet_types", id)
		var e: Entry = _make("planet_type:" + id, "worlds", DictIO.str_of(t, "name_key"), DictIO.str_of(t, "desc_key"), DictIO.str_of(t, "icon"))
		e.effects = DictIO.arr_of(t, "effects")
		e.facts.append(_fact("ui.codex.fact.habitability", Strings.fmt(HAB_KEYS.get(DictIO.str_of(t, "habitability"), HAB_KEYS["open"]), {"pct": _facts.get("hab_" + id, "")})))
		e.links.append("mechanic:habitability")
		if DictIO.str_of(t, "habitability") in ["orbital", "outpost"]:
			e.links.append("mechanic:outposts")
		_add(e)
	for id2: String in db.ids("traits"):
		if not traits.has(id2):
			continue
		var tr2: Dictionary = db.record("traits", id2)
		var e2: Entry = _make("trait:" + id2, "worlds", DictIO.str_of(tr2, "name_key"), DictIO.str_of(tr2, "desc_key"), DictIO.str_of(tr2, "icon"))
		e2.icon_token = "hearth.gold"
		e2.effects = DictIO.arr_of(tr2, "effects")
		_add(e2)


func _people() -> void:
	var db: ContentDb = Content.db()
	for id: String in PEOPLE.keys():
		var p: Dictionary = db.record("portraits", id)
		var e: Entry = _make("character:" + id, "people", DictIO.str_of(p, "name_key"), PEOPLE[id], "")
		e.portrait = id
		_add(e)


## Each event step seen in this game, newest last: its title and text, who spoke, and the choice.
func _events(state: GameState) -> void:
	var db: ContentDb = Content.db()
	var seen: Dictionary[String, bool] = {}
	for le: EventLogEntry in state.event_log:
		var ev: Dictionary = db.events.get(le.chain, {})
		var step: Dictionary = {}
		for s: Variant in DictIO.arr_of(ev, "steps"):
			if DictIO.int_of(s as Dictionary, "step") == le.step:
				step = s
		var id: String = "event:%s.%d" % [le.chain, le.step]
		if step.is_empty() or seen.has(id):
			continue
		seen[id] = true
		var e: Entry = _make(id, "events", DictIO.str_of(step, "title_key"), "", "ui_event")
		var args: Dictionary = {}
		if state.colonies.has(le.colony_id):
			args = ColonyRules.name_args(state, state.colonies[le.colony_id])
		e.prose = Strings.fmt(DictIO.str_of(step, "body_key"), args)
		e.portrait = DictIO.str_of(step, "speaker")
		var choices: Array = DictIO.arr_of(step, "choices")
		if le.choice >= 0 and le.choice < choices.size():
			e.facts.append(_fact("ui.codex.fact.your_choice", Strings.fmt(DictIO.str_of(choices[le.choice] as Dictionary, "label_key"))))
		e.facts.append(_fact("ui.codex.fact.when", Fmt.date(le.turn)))
		_add(e)


# --- helpers ------------------------------------------------------------------------------------

static func _fact(label_key: String, value: String) -> PackedStringArray:
	return PackedStringArray([Strings.fmt(label_key), value])


func _upkeep_fact(e: Entry, upkeep: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for res: Variant in upkeep.keys():
		if int(upkeep[res]) > 0:
			parts.append(_amount(int(upkeep[res]), str(res)))
	if not parts.is_empty():
		e.facts.append(_fact("ui.codex.fact.upkeep", Strings.fmt("ui.codex.per_turn", {"amount": ", ".join(parts)})))


static func _amount(centi: int, res: String) -> String:
	var r: Dictionary = Content.db().record("resources", res)
	var unit_key: String = DictIO.str_of(r, "unit_key")
	if unit_key.is_empty():
		return Strings.fmt("ui.codex.amount_plain", {"value_c": centi, "resource_key": DictIO.str_of(r, "name_key")})
	return Strings.fmt("ui.codex.amount", {"value_c": centi, "unit_key": unit_key, "resource_key": DictIO.str_of(r, "name_key")})


static func _outputs(output: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for res: Variant in output.keys():
		parts.append(_amount(int(output[res]), str(res)))
	return ", ".join(parts)


func _scenario() -> Dictionary:
	return Content.db().scenarios.get(SCENARIO, {})


## A technology Scenario 1 can offer: its pool leaves out military technologies.
func _s1_tech(id: String) -> bool:
	if id.is_empty() or not Content.db().has("techs", id):
		return false
	var pool: Dictionary = DictIO.dict_of(_scenario(), "tech_pool")
	return not (DictIO.bool_of(pool, "exclude_military") and DictIO.bool_of(Content.db().record("techs", id), "military"))


func _start_buildings() -> Array[String]:
	var out: Array[String] = []
	for emp: Variant in DictIO.arr_of(DictIO.dict_of(_scenario(), "start"), "empires"):
		for c: Variant in DictIO.arr_of(emp as Dictionary, "colonies"):
			for b: Variant in DictIO.arr_of(c as Dictionary, "buildings"):
				var bid: String = DictIO.str_of(b as Dictionary, "building")
				if not out.has(bid):
					out.append(bid)
	return out
