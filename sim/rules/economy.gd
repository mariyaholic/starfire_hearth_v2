class_name Economy
extends RefCounted
## Jobs, output, upkeep and housing (§5.3, §5.4). Everything here is derived from the state and
## returned with its Breakdown; nothing is mutated. The production phase applies the empire
## totals, and the UI shows the same breakdowns.
##
## Where each bonus applies (DESIGN_LOG 67):
## - district level: tier, adjacency and district traits raise that district's job output only;
## - colony level: resource, output and research bonuses raise the colony's whole output of that
##   resource, including flat building output;
## - flat lines (upkeep, what settlers eat, industry's mineral input) come after both.
## Within a level, percentages add up.

const PRODUCED: Array[String] = ["food", "energy", "minerals", "alloys"]
const STOCKED: Array[String] = ["food", "energy", "minerals", "alloys", "influence"]
const DISTRICT_ORDER: Array[String] = ["habitation", "agriculture", "energy", "mining", "industry", "research"]
const HABITATION: String = "habitation"
const FOOD_PER_POP: int = 100
## Every capital's own research in each branch (DESIGN_LOG 55).
const CAPITAL_RESEARCH: int = 200
const INFLUENCE_BASE: int = 300
const INFLUENCE_PER_STABLE: int = 100
const INFLUENCE_STABLE_AT: int = 60
## Outposts (DESIGN_LOG 60).
const OUTPOST_YIELD: Dictionary[String, int] = {"minerals": 600, "energy": 600, "research": 300}
const OUTPOST_UPKEEP: int = 50


## One placed district's jobs and bonuses.
class DistrictWork:
	extends RefCounted
	var slot: int = 0
	var district_id: String = ""
	var tier: int = 1
	var branch: String = ""
	var job_id: String = ""
	var group: String = ""
	var jobs: int = 0
	var filled: int = 0
	var tier_bp: int = 0
	var adjacency_bp: int = 0
	## Summed district_output_bp effects, and the entries they came from.
	var trait_bp: int = 0

	func bonus_bp() -> int:
		return tier_bp + adjacency_bp + trait_bp


## Everything derived about one colony.
class ColonyReport:
	extends RefCounted
	var colony_id: String = ""
	var slots: int = 0
	var housing: Breakdown = null
	var jobs_total: int = 0
	## Job group -> jobs offered, and -> jobs filled.
	var jobs_by_group: Dictionary[String, int] = {}
	var filled_by_group: Dictionary[String, int] = {}
	var employed: int = 0
	var unemployed: int = 0
	var homeless: int = 0
	var free_housing: int = 0
	var work: Array[DistrictWork] = []
	## Resource -> this colony's net per turn (food, energy, minerals, alloys).
	var net: Dictionary[String, Breakdown] = {}
	## Branch -> this colony's research per turn.
	var research: Dictionary[String, Breakdown] = {}
	## Minerals industry wants this turn, and the metals it makes (both after bonuses).
	var mineral_input: int = 0
	var alloys_made: int = 0
	## Stability from jobs (clerks), and pollution sources: [{source_key, args, value}].
	var job_stability: int = 0
	var job_stability_jobs: int = 0
	var pollution: Array[Dictionary] = []
	var entries: Array[Modifiers.Entry] = []

	func net_of(resource_id: String) -> int:
		return net[resource_id].total if net.has(resource_id) else 0

	func research_total() -> int:
		var sum: int = 0
		for b: String in research.keys():
			sum += research[b].total
		return sum


## Everything derived about one empire's economy.
class EmpireReport:
	extends RefCounted
	var empire_id: String = ""
	var colonies: Dictionary[String, ColonyReport] = {}
	## Resource -> net per turn (food, energy, minerals, alloys, influence).
	var net: Dictionary[String, Breakdown] = {}
	## Branch -> research per turn.
	var research: Dictionary[String, Breakdown] = {}
	## Resource -> storage cap.
	var caps: Dictionary[String, Breakdown] = {}
	## Sealed Order decoding per turn (0 without the Archive of Sol).
	var decode: Breakdown = null
	## Share of industry that can run this turn, in basis points (below 10000 when minerals are
	## short; DESIGN_LOG 54).
	var industry_bp: int = 10000
	## Colony id -> minerals its governor sets aside this turn (DESIGN_LOG 71).
	var governor_savings: Dictionary[String, int] = {}

	func net_of(resource_id: String) -> int:
		return net[resource_id].total if net.has(resource_id) else 0

	func cap_of(resource_id: String) -> int:
		return caps[resource_id].total if caps.has(resource_id) else -1

	func research_total() -> int:
		var sum: int = 0
		for b: String in research.keys():
			sum += research[b].total
		return sum


static func colony(state: GameState, c: Colony) -> ColonyReport:
	var r: ColonyReport = ColonyReport.new()
	r.colony_id = c.id
	r.entries = Modifiers.for_colony(state, c)
	var planet: Planet = state.planets[c.planet_id]
	if c.is_outpost():
		_outpost(state, c, r)
		return r
	r.slots = ColonyRules.slot_count(planet)
	_work(state, c, r)
	_fill_jobs(c, r)
	_housing(state, c, planet, r)
	_output(state, c, r)
	_research(state, c, r)
	_stability_parts(state, c, r)
	return r


static func empire(state: GameState, empire_id: String) -> EmpireReport:
	var db: ContentDb = Content.db()
	var e: Empire = state.empires[empire_id]
	var er: EmpireReport = EmpireReport.new()
	er.empire_id = empire_id
	var owned: Array[Colony] = state.colonies_of(empire_id)
	for c: Colony in owned:
		er.colonies[c.id] = colony(state, c)

	for res: String in PRODUCED:
		var b: Breakdown = Breakdown.for_resource("breakdown.empire_net", res, true, {"resource_key": _res_name(res)})
		for c: Colony in owned:
			var cr: ColonyReport = er.colonies[c.id]
			if cr.net.has(res):
				b.add("source.colony", cr.net[res].total, ColonyRules.name_args(state, c, "name"), cr.net[res])
		er.net[res] = b
	_ship_upkeep(state, e, er.net)
	_ordinance_upkeep(e, er.net)

	var empire_fx: Array[Modifiers.Entry] = Modifiers.empire_wide(state, e)
	var building_fx: Array[Modifiers.Entry] = Modifiers.empire_buildings(state, e)
	var inf: Breakdown = Breakdown.for_resource("breakdown.empire_net", "influence", true, {"resource_key": _res_name("influence")})
	inf.base("source.influence_base", INFLUENCE_BASE)
	var stable: int = 0
	for c: Colony in owned:
		if not c.is_outpost() and c.stability >= INFLUENCE_STABLE_AT:
			stable += 1
	if stable > 0:
		inf.add("source.stable_colonies", stable * INFLUENCE_PER_STABLE, {"count": stable, "at": INFLUENCE_STABLE_AT}, null, "mechanic:influence")
	Modifiers.add_lines(inf, empire_fx, "influence_per_turn_add")
	Modifiers.add_lines(inf, building_fx, "influence_per_turn_add")
	er.net["influence"] = inf

	for branch: String in Empire.BRANCHES:
		var rb: Breakdown = Breakdown.make("breakdown.research_branch", Breakdown.UNIT_CENTI, true, {"branch_key": Names.branch(branch)})
		for c: Colony in owned:
			var cr: ColonyReport = er.colonies[c.id]
			if cr.research.has(branch):
				rb.add("source.colony", cr.research[branch].total, ColonyRules.name_args(state, c, "name"), cr.research[branch])
		er.research[branch] = rb.finish()

	for res: String in STOCKED:
		var cap: int = DictIO.int_of(db.record("resources", res), "cap", -1)
		var cb: Breakdown = Breakdown.for_resource("breakdown.cap", res, false, {"resource_key": _res_name(res)})
		cb.base("source.cap_base", maxi(0, cap))
		Modifiers.add_lines(cb, empire_fx, "cap_add:" + res)
		Modifiers.add_lines(cb, building_fx, "cap_add:" + res)
		er.caps[res] = cb.finish()

	_industry_shortage(e, er)
	_governor_savings(state, owned, er)
	for res: String in STOCKED:
		er.net[res].finish()

	var rate: int = Modifiers.total(building_fx, "decode_rate_bp") + Modifiers.total(empire_fx, "decode_rate_bp")
	er.decode = Breakdown.make("breakdown.decode", Breakdown.UNIT_CENTI, true)
	if rate > 0:
		er.decode.base("source.decode_research", er.research_total()).mult("source.decode_rate", rate - 10000, {"pct": Fx.div_floor(rate, 100)})
	er.decode.finish()
	return er


## Turns until a stock empties (net < 0) or fills (net > 0); -1 when it never will.
static func turns_until(stock: int, net: int, cap: int) -> int:
	if net < 0:
		return Fx.div_floor(stock, -net)
	if net > 0 and cap >= 0:
		if stock >= cap:
			return 0
		return Fx.div_ceil(cap - stock, net)
	return -1


# --- Jobs -----------------------------------------------------------------------------------

static func _work(_state: GameState, c: Colony, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	for pd: Colony.PlacedDistrict in c.districts:
		var ddef: Dictionary = db.record("districts", pd.district_id)
		var tier: Dictionary = _tier_record(ddef, pd.tier)
		var extra: int = DictIO.int_of(tier, "extra_jobs")
		var first: bool = true
		for jv: Variant in DictIO.arr_of(ddef, "jobs"):
			var js: Dictionary = jv
			var w: DistrictWork = DistrictWork.new()
			w.slot = pd.slot
			w.district_id = pd.district_id
			w.tier = pd.tier
			w.branch = pd.branch
			w.job_id = DictIO.str_of(js, "job")
			w.group = DictIO.str_of(db.record("jobs", w.job_id), "group")
			w.jobs = DictIO.int_of(js, "count") + (extra if first else 0)
			first = false
			w.tier_bp = DictIO.int_of(tier, "output_bp")
			w.adjacency_bp = _adjacency_bp(c, r.slots, pd, ddef)
			w.trait_bp = Modifiers.total(r.entries, "district_output_bp:" + pd.district_id)
			r.work.append(w)
			r.jobs_total += w.jobs
			r.jobs_by_group[w.group] = r.jobs_by_group.get(w.group, 0) + w.jobs


## Settlers take jobs group by group in the colony's priority order; inside a group the most
## productive district fills first, then the lowest slot (DESIGN_LOG 68).
static func _fill_jobs(c: Colony, r: ColonyReport) -> void:
	var left: int = c.pops
	for group: String in c.job_priority:
		var candidates: Array[DistrictWork] = []
		for w: DistrictWork in r.work:
			if w.group == group:
				candidates.append(w)
		candidates.sort_custom(func(a: DistrictWork, b: DistrictWork) -> bool:
			if a.bonus_bp() != b.bonus_bp():
				return a.bonus_bp() > b.bonus_bp()
			return a.slot < b.slot)
		for w: DistrictWork in candidates:
			w.filled = mini(w.jobs, left)
			left -= w.filled
			r.filled_by_group[group] = r.filled_by_group.get(group, 0) + w.filled
	r.employed = c.pops - left
	r.unemployed = left


static func _adjacency_bp(c: Colony, slots: int, pd: Colony.PlacedDistrict, ddef: Dictionary) -> int:
	var total: int = 0
	for av: Variant in DictIO.arr_of(ddef, "adjacency"):
		var rule: Dictionary = av
		var bonus: int = DictIO.int_of(rule, "bonus_bp")
		if bonus == 0:
			continue
		var n: int = _adjacent_districts(c, slots, pd.slot, DictIO.str_of(rule, "with"))
		var cap: int = DictIO.int_of(rule, "cap_bp", bonus * 6)
		total += mini(n * bonus, cap)
	return total


static func _adjacent_districts(c: Colony, slots: int, slot: int, district_id: String) -> int:
	var n: int = 0
	for s: int in HexGrid.neighbours(slot, slots):
		var other: Colony.PlacedDistrict = c.district_at(s)
		if other != null and other.district_id == district_id:
			n += 1
	return n


static func _tier_record(ddef: Dictionary, tier: int) -> Dictionary:
	for tv: Variant in DictIO.arr_of(ddef, "tiers"):
		var t: Dictionary = tv
		if DictIO.int_of(t, "tier") == tier:
			return t
	return {}


# --- Housing --------------------------------------------------------------------------------

static func _housing(state: GameState, c: Colony, planet: Planet, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	var b: Breakdown = Breakdown.make("breakdown.housing", Breakdown.UNIT_COUNT, false, ColonyRules.name_args(state, c))
	var hab_raw: int = 0
	var hab_count: int = 0
	var other: int = 0
	var other_count: int = 0
	for pd: Colony.PlacedDistrict in c.districts:
		var ddef: Dictionary = db.record("districts", pd.district_id)
		var h: int = DictIO.int_of(ddef, "housing")
		var mult: int = DictIO.int_of(_tier_record(ddef, pd.tier), "housing_mult_bp", 10000)
		if pd.district_id == HABITATION:
			hab_raw += Fx.mul_bp(h, mult)
			hab_count += 1
		else:
			other += Fx.mul_bp(h, mult)
			other_count += 1
	var hab_bp: int = ColonyRules.habitability_bp(planet)
	if hab_count > 0:
		b.add("source.housing_habitation", Fx.mul_bp(hab_raw, hab_bp), {"count": hab_count, "pct": Fx.div_floor(hab_bp, 100)}, null, "district:habitation")
	if other_count > 0:
		b.add("source.housing_districts", other, {"count": other_count})
	Modifiers.add_lines(b, r.entries, "housing_add")
	for pb: Colony.PlacedBuilding in c.buildings:
		if pb.slot == Colony.LANDMARK_SLOT:
			continue
		var bdef: Dictionary = db.record("buildings", pb.building_id)
		for av: Variant in DictIO.arr_of(bdef, "adjacency"):
			var rule: Dictionary = av
			var per: int = DictIO.int_of(rule, "housing_add")
			if per == 0:
				continue
			var n: int = _adjacent_districts(c, r.slots, pb.slot, DictIO.str_of(rule, "with"))
			if n > 0:
				var with_def: Dictionary = db.record("districts", DictIO.str_of(rule, "with"))
				b.add("source.adjacency_housing", per * n, {"name_key": DictIO.str_of(bdef, "name_key"), "count": n, "with_key": DictIO.str_of(with_def, "name_key")}, null, "building:" + pb.building_id)
	b.cap_min(0, "source.never_negative")
	r.housing = b.finish()
	r.free_housing = r.housing.total - c.pops
	r.homeless = maxi(0, -r.free_housing)


# --- Output ---------------------------------------------------------------------------------

static func _output(state: GameState, c: Colony, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	var name: Dictionary = ColonyRules.name_args(state, c)
	for res: String in PRODUCED:
		var label_args: Dictionary = name.duplicate()
		label_args["resource_key"] = _res_name(res)
		r.net[res] = Breakdown.for_resource("breakdown.colony_net", res, true, label_args)
	# District groups, in a fixed order.
	for did: String in DISTRICT_ORDER:
		for res: String in PRODUCED:
			var child: Breakdown = _district_group(state, c, r, did, res, "")
			if child != null:
				var ddef: Dictionary = db.record("districts", did)
				r.net[res].add("source.district_group", child.total, {"district_key": DictIO.str_of(ddef, "name_key"), "count": _count_districts(c, did)}, child, "district:" + did)
	for res: String in PRODUCED:
		var b: Breakdown = r.net[res]
		Modifiers.add_lines(b, r.entries, "output_add:" + res)
		Modifiers.mult_lines(b, r.entries, "resource_output_bp:" + res)
		Modifiers.mult_lines(b, r.entries, "output_bp")
	# Flat lines.
	var pops_eat: int = c.pops * FOOD_PER_POP
	if pops_eat > 0:
		r.net["food"].flat("source.pop_upkeep", -pops_eat, {"count": c.pops}, null, "mechanic:food")
	_upkeep_lines(state, c, r)
	var inputs: Dictionary[String, int] = {}
	var input_jobs: Dictionary[String, int] = {}
	for w: DistrictWork in r.work:
		if w.filled == 0:
			continue
		var job: Dictionary = db.record("jobs", w.job_id)
		var input: Dictionary = DictIO.dict_of(job, "input")
		for res: Variant in input.keys():
			var key: String = "%s|%s" % [str(res), w.job_id]
			inputs[key] = inputs.get(key, 0) + w.filled * int(input[res])
			input_jobs[key] = input_jobs.get(key, 0) + w.filled
	for key: String in DictIO.sorted_keys(inputs):
		var parts: PackedStringArray = key.split("|")
		var res_id: String = parts[0]
		var job_def: Dictionary = db.record("jobs", parts[1])
		if r.net.has(res_id):
			r.net[res_id].flat("source.job_input", -inputs[key], {"job_key": DictIO.str_of(job_def, "name_key"), "count": input_jobs[key]})
		if res_id == "minerals":
			r.mineral_input += inputs[key]
	for res: String in PRODUCED:
		r.net[res].finish()
	# Metals made, after colony bonuses: the gross (positive) part of the alloys breakdown.
	r.alloys_made = 0
	for l: Breakdown.Line in r.net["alloys"].lines:
		if l.kind != Breakdown.KIND_FLAT and l.kind != Breakdown.KIND_CAP:
			r.alloys_made += l.value


static func _count_districts(c: Colony, district_id: String) -> int:
	var n: int = 0
	for pd: Colony.PlacedDistrict in c.districts:
		if pd.district_id == district_id:
			n += 1
	return n


## The output of every district of one type for one resource (and one research branch), with
## tier, adjacency and trait bonuses as lines. Null when those districts make none of it.
static func _district_group(state: GameState, c: Colony, r: ColonyReport, district_id: String, res: String, branch: String) -> Breakdown:
	var db: ContentDb = Content.db()
	var group_work: Array[DistrictWork] = []
	var each: int = 0
	var job_id: String = ""
	for w: DistrictWork in r.work:
		if w.district_id != district_id:
			continue
		if not branch.is_empty() and w.branch != branch:
			continue
		var out: Dictionary = DictIO.dict_of(db.record("jobs", w.job_id), "output")
		if not out.has(res):
			continue
		each = int(out[res])
		job_id = w.job_id
		group_work.append(w)
	if group_work.is_empty():
		return null
	var ddef: Dictionary = db.record("districts", district_id)
	var job_def: Dictionary = db.record("jobs", job_id)
	var label_args: Dictionary = ColonyRules.name_args(state, c)
	label_args["district_key"] = DictIO.str_of(ddef, "name_key")
	var b: Breakdown = Breakdown.for_resource("breakdown.district_output", res, true, label_args)
	var filled: int = 0
	var jobs: int = 0
	for w: DistrictWork in group_work:
		filled += w.filled
		jobs += w.jobs
	b.base("source.jobs_filled", filled * each, {"filled": filled, "jobs": jobs, "job_key": DictIO.str_of(job_def, "name_key"), "each_c": each}, null, "job:" + job_id)
	# Tier bonuses, one line per tier present.
	for tier: int in [2, 3]:
		var v: int = 0
		var pct: int = 0
		for w: DistrictWork in group_work:
			if w.tier == tier and w.tier_bp != 0:
				v += Fx.mul_bp(w.filled * each, w.tier_bp)
				pct = w.tier_bp
		if v != 0:
			b.add("source.tier_bonus", v, {"tier": tier, "bp": pct}, null, "mechanic:tiers")
	var adj: int = 0
	for w: DistrictWork in group_work:
		adj += Fx.mul_bp(w.filled * each, w.adjacency_bp)
	if adj != 0:
		b.add("source.adjacency_output", adj, _adjacency_args(ddef), null, "mechanic:adjacency")
	for e: Modifiers.Entry in Modifiers.with_key(r.entries, "district_output_bp:" + district_id):
		var v: int = 0
		for w: DistrictWork in group_work:
			v += Fx.mul_bp(w.filled * each, e.value)
		if v != 0:
			var args: Dictionary = e.source_args.duplicate()
			args["bp"] = e.value
			b.add(e.source_key, v, args, null, e.link)
	return b.finish()


static func _adjacency_args(ddef: Dictionary) -> Dictionary:
	var db: ContentDb = Content.db()
	for av: Variant in DictIO.arr_of(ddef, "adjacency"):
		var rule: Dictionary = av
		if DictIO.int_of(rule, "bonus_bp") != 0:
			var with_def: Dictionary = db.record("districts", DictIO.str_of(rule, "with"))
			return {"with_key": DictIO.str_of(with_def, "name_key"), "each_pct": Fx.div_floor(DictIO.int_of(rule, "bonus_bp"), 100), "cap_pct": Fx.div_floor(DictIO.int_of(rule, "cap_bp"), 100)}
	return {}


static func _upkeep_lines(state: GameState, c: Colony, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	var name: Dictionary = ColonyRules.name_args(state, c)
	for res: String in PRODUCED:
		var dchild: Breakdown = Breakdown.for_resource("breakdown.district_upkeep", res, true, name)
		for did: String in DISTRICT_ORDER:
			var n: int = _count_districts(c, did)
			if n == 0:
				continue
			var ddef: Dictionary = db.record("districts", did)
			var per: int = int(DictIO.dict_of(ddef, "upkeep").get(res, 0))
			if per != 0:
				dchild.add("source.district_upkeep_each", -n * per, {"count": n, "district_key": DictIO.str_of(ddef, "name_key"), "each_c": per}, null, "district:" + did)
		dchild.finish()
		if dchild.total != 0:
			r.net[res].flat("source.district_upkeep", dchild.total, {"count": c.districts.size()}, dchild, "mechanic:upkeep")
		var bchild: Breakdown = Breakdown.for_resource("breakdown.building_upkeep", res, true, name)
		for pb: Colony.PlacedBuilding in c.buildings:
			var bdef: Dictionary = db.record("buildings", pb.building_id)
			var per_b: int = int(DictIO.dict_of(bdef, "upkeep").get(res, 0))
			if per_b != 0:
				bchild.add("source.effect.building", -per_b, {"name_key": DictIO.str_of(bdef, "name_key")}, null, "building:" + pb.building_id)
		bchild.finish()
		if bchild.total != 0:
			r.net[res].flat("source.building_upkeep", bchild.total, {"count": c.buildings.size()}, bchild, "mechanic:upkeep")


# --- Research -------------------------------------------------------------------------------

static func _research(state: GameState, c: Colony, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	var e: Empire = state.empires.get(c.owner_id, null)
	var is_capital: bool = e != null and e.capital_id == c.id
	for branch: String in Empire.BRANCHES:
		var args: Dictionary = ColonyRules.name_args(state, c)
		args["branch_key"] = Names.branch(branch)
		var b: Breakdown = Breakdown.make("breakdown.colony_research", Breakdown.UNIT_CENTI, true, args)
		var any: bool = false
		var child: Breakdown = _district_group(state, c, r, "research", "research", branch)
		if child != null:
			var ddef: Dictionary = db.record("districts", "research")
			b.add("source.district_group", child.total, {"district_key": DictIO.str_of(ddef, "name_key"), "count": _count_branch_districts(c, branch)}, child, "district:research")
			any = true
		if is_capital:
			b.add("source.capital_research", CAPITAL_RESEARCH, {}, null, "mechanic:research")
			any = true
		if not any:
			continue
		_research_mults(b, r.entries, branch)
		r.research[branch] = b.finish()


static func _research_mults(b: Breakdown, entries: Array[Modifiers.Entry], branch: String) -> void:
	Modifiers.mult_lines(b, entries, "resource_output_bp:research")
	Modifiers.mult_lines(b, entries, "research_bp:all")
	Modifiers.mult_lines(b, entries, "research_bp:" + branch)
	Modifiers.mult_lines(b, entries, "output_bp")


static func _count_branch_districts(c: Colony, branch: String) -> int:
	var n: int = 0
	for pd: Colony.PlacedDistrict in c.districts:
		if pd.district_id == "research" and pd.branch == branch:
			n += 1
	return n


# --- Stability parts computed with the jobs ---------------------------------------------------

static func _stability_parts(_state: GameState, c: Colony, r: ColonyReport) -> void:
	var db: ContentDb = Content.db()
	for w: DistrictWork in r.work:
		var per: int = DictIO.int_of(db.record("jobs", w.job_id), "stability_add")
		if per != 0 and w.filled > 0:
			r.job_stability += per * w.filled
			r.job_stability_jobs += w.filled
	# Pollution and other stability adjacency: districts and buildings next to a district type.
	var tallies: Dictionary[String, Dictionary] = {}
	for pd: Colony.PlacedDistrict in c.districts:
		var ddef: Dictionary = db.record("districts", pd.district_id)
		_tally_stability_adjacency(c, r.slots, pd.slot, ddef, "district:" + pd.district_id, tallies)
	for pb: Colony.PlacedBuilding in c.buildings:
		if pb.slot == Colony.LANDMARK_SLOT:
			continue
		var bdef: Dictionary = db.record("buildings", pb.building_id)
		_tally_stability_adjacency(c, r.slots, pb.slot, bdef, "building:" + pb.building_id, tallies)
	for key: String in DictIO.sorted_keys(tallies):
		r.pollution.append(tallies[key])


static func _tally_stability_adjacency(c: Colony, slots: int, slot: int, def: Dictionary, link: String, tallies: Dictionary[String, Dictionary]) -> void:
	var db: ContentDb = Content.db()
	for av: Variant in DictIO.arr_of(def, "adjacency"):
		var rule: Dictionary = av
		var per: int = DictIO.int_of(rule, "stability_add")
		if per == 0:
			continue
		var with_id: String = DictIO.str_of(rule, "with")
		var n: int = _adjacent_districts(c, slots, slot, with_id)
		if n == 0:
			continue
		var key: String = "%s|%s" % [link, with_id]
		if not tallies.has(key):
			var with_def: Dictionary = db.record("districts", with_id)
			tallies[key] = {"source_key": "source.adjacency_stability", "args": {"name_key": DictIO.str_of(def, "name_key"), "with_key": DictIO.str_of(with_def, "name_key"), "count": 0}, "value": 0, "link": link}
		var t: Dictionary = tallies[key]
		t["value"] = int(t["value"]) + per * n
		var args: Dictionary = t["args"]
		args["count"] = int(args["count"]) + n


# --- Outposts -------------------------------------------------------------------------------

static func _outpost(state: GameState, c: Colony, r: ColonyReport) -> void:
	var name: Dictionary = ColonyRules.name_args(state, c)
	for res: String in PRODUCED:
		var label_args: Dictionary = name.duplicate()
		label_args["resource_key"] = _res_name(res)
		r.net[res] = Breakdown.for_resource("breakdown.colony_net", res, true, label_args)
	if c.outpost_kind == "research":
		for branch: String in Empire.BRANCHES:
			var args: Dictionary = name.duplicate()
			args["branch_key"] = Names.branch(branch)
			var b: Breakdown = Breakdown.make("breakdown.colony_research", Breakdown.UNIT_CENTI, true, args)
			b.base("source.outpost_yield", OUTPOST_YIELD["research"], {}, null, "mechanic:outposts")
			_research_mults(b, r.entries, branch)
			r.research[branch] = b.finish()
	elif r.net.has(c.outpost_kind):
		var b2: Breakdown = r.net[c.outpost_kind]
		b2.base("source.outpost_yield", OUTPOST_YIELD.get(c.outpost_kind, 0), {}, null, "mechanic:outposts")
		Modifiers.mult_lines(b2, r.entries, "resource_output_bp:" + c.outpost_kind)
		Modifiers.mult_lines(b2, r.entries, "output_bp")
	r.net["energy"].flat("source.outpost_upkeep", -OUTPOST_UPKEEP, {}, null, "mechanic:outposts")
	for res: String in PRODUCED:
		r.net[res].finish()


# --- Empire-level lines ---------------------------------------------------------------------

static func _ship_upkeep(state: GameState, e: Empire, nets: Dictionary[String, Breakdown]) -> void:
	var db: ContentDb = Content.db()
	var per_hull: Dictionary[String, int] = {}
	for sh: Ship in state.ships_of(e.id):
		var hull_id: String = sh.hull
		if hull_id.is_empty() and state.designs.has(sh.design_id):
			hull_id = state.designs[sh.design_id].hull
		per_hull[hull_id] = per_hull.get(hull_id, 0) + 1
	for res: String in PRODUCED:
		var child: Breakdown = Breakdown.for_resource("breakdown.ship_upkeep", res, true)
		for hull_id: String in DictIO.sorted_keys(per_hull):
			var hdef: Dictionary = db.record("hulls", hull_id)
			var per: int = int(DictIO.dict_of(hdef, "upkeep").get(res, 0))
			if per != 0:
				child.add("source.ship_upkeep_each", -per * per_hull[hull_id], {"count": per_hull[hull_id], "hull_key": DictIO.str_of(hdef, "name_key"), "each_c": per}, null, "hull:" + hull_id)
		child.finish()
		if child.total != 0:
			nets[res].flat("source.ship_upkeep", child.total, {"count": state.ships_of(e.id).size()}, child, "mechanic:upkeep")


static func _ordinance_upkeep(e: Empire, nets: Dictionary[String, Breakdown]) -> void:
	var db: ContentDb = Content.db()
	for res: String in PRODUCED:
		var child: Breakdown = Breakdown.for_resource("breakdown.ordinance_upkeep", res, true)
		for oid: String in DictIO.sorted_keys(e.ordinances):
			var odef: Dictionary = db.record("edicts", oid)
			var per: int = int(DictIO.dict_of(odef, "upkeep").get(res, 0))
			if per != 0:
				child.add("source.effect.ordinance", -per, {"name_key": DictIO.str_of(odef, "name_key")}, null, "edict:" + oid)
		child.finish()
		if child.total != 0:
			nets[res].flat("source.ordinance_upkeep", child.total, {"count": e.ordinances.size()}, child, "mechanic:ordinances")


## When the minerals in stock plus this turn's net cannot cover industry, industry runs only as
## far as the minerals go and makes proportionally fewer metals (DESIGN_LOG 54).
static func _industry_shortage(e: Empire, er: EmpireReport) -> void:
	var input: int = 0
	var made: int = 0
	for cid: String in er.colonies.keys():
		input += er.colonies[cid].mineral_input
		made += er.colonies[cid].alloys_made
	if input <= 0:
		return
	var minerals_net: int = 0
	for l: Breakdown.Line in er.net["minerals"].lines:
		minerals_net += l.value
	var after: int = e.stock_of("minerals") + minerals_net
	if after >= 0:
		return
	var cut: int = mini(-after, input)
	er.industry_bp = Fx.div_floor((input - cut) * 10000, input)
	var pct: int = Fx.div_floor(er.industry_bp, 100)
	er.net["minerals"].flat("source.industry_short_minerals", cut, {"pct": pct}, null, "mechanic:industry")
	var lost: int = made - Fx.div_floor(made * (input - cut), input)
	if lost > 0:
		er.net["alloys"].flat("source.industry_short_alloys", -lost, {"pct": pct}, null, "mechanic:industry")


## Each governor sets aside its share of the minerals income, in colony order, never more than
## the income itself and never past its purse limit. The set-aside is a flat line of the net, so
## the net still says exactly how the stock will change.
static func _governor_savings(state: GameState, owned: Array[Colony], er: EmpireReport) -> void:
	var income: int = 0
	for l: Breakdown.Line in er.net["minerals"].lines:
		income += l.value
	var left: int = maxi(0, income)
	for c: Colony in owned:
		if not c.governor_on or c.is_outpost() or left <= 0:
			continue
		var share: int = mini(Fx.mul_bp(maxi(0, income), c.governor_budget_bp), left)
		share = mini(share, maxi(0, Governor.FUNDS_CAP - c.governor_funds))
		if share <= 0:
			continue
		left -= share
		er.governor_savings[c.id] = share
		var args: Dictionary = ColonyRules.name_args(state, c)
		args["pct"] = Fx.div_floor(c.governor_budget_bp, 100)
		er.net["minerals"].flat("source.governor_savings", -share, args, null, "mechanic:governors")


static func _res_name(res: String) -> String:
	return DictIO.str_of(Content.db().record("resources", res), "name_key", "res.%s.name" % res)
