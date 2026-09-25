class_name Advisor
extends RefCounted
## Scores what a colony could build next from the empire's needs and a focus (§5.4 governors).
## Governors, the balanced bot and the hints share it, so the governor's reason line and the
## bot's choices come from the same reasoning. Scores are integer points; the reason names the
## need that weighed most.

const FOCUS_WEIGHTS: Dictionary[String, Dictionary] = {
	"balanced": {},
	"food": {"food": 20000},
	"industry": {"minerals": 20000, "alloys": 20000},
	"research": {"research": 20000},
	"growth": {"housing": 20000, "growth": 20000},
	"stability": {"stability": 20000},
}
## Techs the Scenario 1 objectives depend on, and their branches.
const OBJECTIVE_TECH_BRANCH: Dictionary[String, String] = {"habitat_domes": "society", "wake_theory": "physics"}
## How strongly each of those techs pulls new Research districts to its branch.
const OBJECTIVE_TECH_PULL: Dictionary[String, int] = {"habitat_domes": 3, "wake_theory": 1}
## Buildings with no use until later scenarios; the advisor never proposes them.
const NOT_YET_USEFUL: Array[String] = ["listening_post", "planetary_shield"]


## One thing a colony could build, with its score and the reason for it.
class Option:
	extends RefCounted
	var kind: String = ""
	var def_id: String = ""
	var slot: int = -1
	var branch: String = ""
	var tier: int = 1
	var cost: Dictionary[String, int] = {}
	var value: int = 0
	var score: int = 0
	var reason_key: String = ""
	var reason_args: Dictionary = {}

	func veto_key() -> String:
		return "%s:%s" % [kind, def_id]


## What the empire is short of, as weights per 1.00 of each resource per turn.
class Needs:
	extends RefCounted
	var weights: Dictionary[String, int] = {}
	var reasons: Dictionary[String, Array] = {}


static func needs(state: GameState, e: Empire, er: Economy.EmpireReport) -> Needs:
	var n: Needs = Needs.new()
	for res: String in ["food", "energy", "minerals", "alloys"]:
		var net: int = er.net_of(res)
		var cap: int = er.cap_of(res)
		var stock: int = e.stock_of(res)
		var full: bool = cap > 0 and stock * 10 >= cap * 6
		var w: int = 3
		var reason: Array = []
		match res:
			"food", "energy":
				if net < 0:
					w = 24
					reason = ["governor.reason.shortfall", {"resource_key": "res.%s.name" % res, "net_c": net}]
				elif net < (200 if res == "food" else 300):
					w = 12
					reason = ["governor.reason.low", {"resource_key": "res.%s.name" % res}]
				elif full or stock > _gross(er, res) * 7:
					# Plenty in store: more of it would only pile up.
					w = 1
			"minerals":
				if net < 0:
					w = 20
					reason = ["governor.reason.shortfall", {"resource_key": "res.minerals.name", "net_c": net}]
				elif stock >= 20000 or full:
					w = 2
				elif net < 1500 or stock < 5000:
					w = 14 if stock < 5000 else 10
					reason = ["governor.reason.low", {"resource_key": "res.minerals.name"}]
				else:
					w = 5
			"alloys":
				if needs_colony_ship(state, e) and stock < 5000 and net < 300:
					w = 30 if net <= 0 else 12
					reason = ["governor.reason.colony_ship", {}]
				elif full:
					w = 1
		n.weights[res] = w
		n.reasons[res] = reason
	n.weights["research"] = 12 if objective_research_pending(state, e) else 8
	n.reasons["research"] = []
	return n


## True while a tech the objectives depend on is still to be researched (Habitat Domes for dome
## worlds, Wake Theory for decoding).
static func objective_research_pending(_state: GameState, e: Empire) -> bool:
	for tid: String in OBJECTIVE_TECH_BRANCH.keys():
		if not e.has_tech(tid):
			return true
	return false


## True while the empire would still found colonies: a settleable, surveyed or surveyable planet
## is free and no colony ship is built or queued.
static func needs_colony_ship(state: GameState, e: Empire) -> bool:
	for sh: Ship in state.ships_of(e.id):
		if sh.hull == "colony_ship":
			return false
	for c: Colony in state.colonies_of(e.id):
		for item: BuildItem in c.queue:
			if item.kind == BuildItem.KIND_SHIP and item.def_id == "colony_ship":
				return false
	for pid: String in DictIO.sorted_keys(state.planets):
		var p: Planet = state.planets[pid]
		if p.colony_id.is_empty() and ColonyRules.habitability(p) in [ColonyRules.HAB_OPEN, ColonyRules.HAB_DOMES] and e.known_systems.has(p.system_id):
			return true
	return false


## Every build the colony could queue now (placement rules met), scored. Affordability is not
## required: an option can be saved up for.
static func options(state: GameState, c: Colony, er: Economy.EmpireReport, focus: String = "balanced") -> Array[Option]:
	var out: Array[Option] = []
	if c.is_outpost() or c.owner_id.is_empty():
		return out
	var db: ContentDb = Content.db()
	var e: Empire = state.empires[c.owner_id]
	var planet: Planet = state.planets[c.planet_id]
	var cr: Economy.ColonyReport = er.colonies.get(c.id, null)
	if cr == null:
		cr = Economy.colony(state, c)
	var n: Needs = needs(state, e, er)
	var free: Array[int] = ColonyRules.free_slots(c, planet)
	var fw: Dictionary = FOCUS_WEIGHTS.get(focus, {})
	if not free.is_empty():
		for did: String in Economy.DISTRICT_ORDER:
			var branch: String = ""
			if DictIO.bool_of(db.record("districts", did), "branch_choice"):
				branch = research_branch(state, e)
			var slot: int = best_slot(c, planet, did, free, false)
			var o: Option = _district_option(state, c, cr, n, fw, did, slot, branch)
			if o != null:
				out.append(o)
		for bid: String in db.ids("buildings"):
			if NOT_YET_USEFUL.has(bid):
				continue
			var slot_b: int = best_slot(c, planet, bid, free, true)
			var check: Result = Construction.can_build_building(state, e.id, c.id, slot_b, bid)
			if not check.ok and check.reason_key != "error.build.cannot_afford":
				continue
			var ob: Option = _building_option(state, c, cr, er, n, fw, bid, slot_b)
			if ob != null:
				out.append(ob)
	for pd: Colony.PlacedDistrict in c.districts:
		var up: Result = Construction.can_upgrade(state, e.id, c.id, pd.slot)
		if not up.ok and up.reason_key != "error.build.cannot_afford":
			continue
		var ou: Option = _upgrade_option(state, c, cr, n, fw, pd)
		if ou != null:
			out.append(ou)
	for o: Option in out:
		var cost_units: int = Fx.div_floor(_cost_total(o.cost), Fx.ONE)
		o.score = Fx.div_floor(o.value * 1000, cost_units + 30)
	out.sort_custom(func(a: Option, b: Option) -> bool:
		if a.score != b.score:
			return a.score > b.score
		if a.kind != b.kind:
			return a.kind < b.kind
		if a.def_id != b.def_id:
			return a.def_id < b.def_id
		return a.slot < b.slot)
	return out


## The research branch that most needs another Research district: a branch leading to a tech the
## objectives need comes first, then the one with the fewest Research districts.
static func research_branch(state: GameState, e: Empire) -> String:
	var best: String = Empire.BRANCHES[0]
	var best_n: int = 1 << 30
	for b: String in Empire.BRANCHES:
		if Research.available(state, e, b).is_empty():
			continue
		var n: int = 0
		for goal: String in OBJECTIVE_TECH_BRANCH.keys():
			if OBJECTIVE_TECH_BRANCH[goal] == b and not e.has_tech(goal):
				n -= OBJECTIVE_TECH_PULL[goal]
		for c: Colony in state.colonies_of(e.id):
			for pd: Colony.PlacedDistrict in c.districts:
				if pd.district_id == "research" and pd.branch == b:
					n += 1
			for item: BuildItem in c.queue:
				if item.def_id == "research" and item.branch == b:
					n += 1
		if n < best_n:
			best_n = n
			best = b
	return best


## The free slot where a district or building does best: the most adjacency bonus, no
## pollution next to Habitation, then the lowest slot.
static func best_slot(c: Colony, planet: Planet, def_id: String, free: Array[int], is_building: bool) -> int:
	var db: ContentDb = Content.db()
	var slots: int = ColonyRules.slot_count(planet)
	var def: Dictionary = db.record("buildings" if is_building else "districts", def_id)
	var best: int = -1
	var best_score: int = -(1 << 30)
	for slot: int in free:
		var score: int = 0
		for av: Variant in DictIO.arr_of(def, "adjacency"):
			var rule: Dictionary = av
			var n: int = Economy._adjacent_districts(c, slots, slot, DictIO.str_of(rule, "with"))
			if DictIO.int_of(rule, "bonus_bp") != 0:
				score += mini(n * DictIO.int_of(rule, "bonus_bp"), DictIO.int_of(rule, "cap_bp", 10000))
			score += n * DictIO.int_of(rule, "stability_add") * 400
			score += n * DictIO.int_of(rule, "housing_add") * 600
		# Leave room next to Energy districts for Research, and keep Farm districts together.
		if not is_building:
			for s: int in HexGrid.neighbours(slot, slots):
				var other: Colony.PlacedDistrict = c.district_at(s)
				if other == null:
					continue
				for ov: Variant in DictIO.arr_of(db.record("districts", other.district_id), "adjacency"):
					var orule: Dictionary = ov
					if DictIO.str_of(orule, "with") == def_id:
						score += DictIO.int_of(orule, "bonus_bp") + DictIO.int_of(orule, "stability_add") * 400
		if score > best_score:
			best_score = score
			best = slot
	return best


static func _district_option(state: GameState, c: Colony, cr: Economy.ColonyReport, n: Needs, fw: Dictionary, did: String, slot: int, branch: String) -> Option:
	var db: ContentDb = Content.db()
	var check: Result = Construction.can_place_district(state, c.owner_id, c.id, slot, did, branch)
	if not check.ok and check.reason_key != "error.build.cannot_afford":
		return null
	var ddef: Dictionary = db.record("districts", did)
	var planet: Planet = state.planets[c.planet_id]
	var o: Option = _option(BuildItem.KIND_DISTRICT, did, slot, branch, 1, Construction.district_cost(did))
	var fill_bp: int = _fill_bp(cr, _district_jobs(ddef, 1))
	var adj_bp: int = _slot_adjacency_bp(c, planet, did, slot)
	var parts: Dictionary[String, int] = {}
	_job_value(ddef, 1, fill_bp, adj_bp, n, fw, parts)
	var housing: int = DictIO.int_of(ddef, "housing")
	if did == Economy.HABITATION:
		housing = Fx.mul_bp(housing, ColonyRules.habitability_bp(planet))
	parts["housing"] = housing * _housing_weight(cr, fw)
	parts["upkeep"] = -Fx.div_floor(int(DictIO.dict_of(ddef, "upkeep").get("energy", 0)) * n.weights["energy"], Fx.ONE)
	_finish(o, parts, cr, n, fw)
	return o


static func _upgrade_option(state: GameState, c: Colony, cr: Economy.ColonyReport, n: Needs, fw: Dictionary, pd: Colony.PlacedDistrict) -> Option:
	var ddef: Dictionary = Content.db().record("districts", pd.district_id)
	var next_tier: int = pd.tier + 1
	var tier: Dictionary = Economy._tier_record(ddef, next_tier)
	if tier.is_empty():
		return null
	var o: Option = _option(BuildItem.KIND_UPGRADE, pd.district_id, pd.slot, pd.branch, next_tier, Construction.upgrade_cost(pd.district_id, next_tier))
	var extra: int = DictIO.int_of(tier, "extra_jobs") - DictIO.int_of(Economy._tier_record(ddef, pd.tier), "extra_jobs")
	var parts: Dictionary[String, int] = {}
	var fill_bp: int = _fill_bp(cr, extra)
	var out_gain_bp: int = DictIO.int_of(tier, "output_bp") - DictIO.int_of(Economy._tier_record(ddef, pd.tier), "output_bp")
	# New jobs at the new tier's output, plus the output gain on the jobs already there.
	var base_jobs: int = _district_jobs(ddef, pd.tier)
	var tmp: Dictionary[String, int] = {}
	_job_value_count(ddef, extra, fill_bp, DictIO.int_of(tier, "output_bp"), n, fw, tmp, true)
	_job_value_count(ddef, base_jobs, 10000, out_gain_bp - 10000, n, fw, tmp, false)
	for k: String in tmp.keys():
		parts[k] = parts.get(k, 0) + tmp[k]
	if pd.district_id == Economy.HABITATION and DictIO.int_of(tier, "housing_mult_bp") > 10000:
		var planet: Planet = state.planets[c.planet_id]
		var gain: int = Fx.mul_bp(Fx.mul_bp(DictIO.int_of(ddef, "housing"), DictIO.int_of(tier, "housing_mult_bp") - 10000), ColonyRules.habitability_bp(planet))
		parts["housing"] = gain * _housing_weight(cr, fw)
	_finish(o, parts, cr, n, fw)
	return o


static func _building_option(state: GameState, c: Colony, cr: Economy.ColonyReport, er: Economy.EmpireReport, n: Needs, fw: Dictionary, bid: String, slot: int) -> Option:
	var db: ContentDb = Content.db()
	var bdef: Dictionary = db.record("buildings", bid)
	var o: Option = _option(BuildItem.KIND_BUILDING, bid, slot, "", 1, Construction.building_cost(bid))
	var parts: Dictionary[String, int] = {}
	var planet: Planet = state.planets[c.planet_id]
	var slots: int = ColonyRules.slot_count(planet)
	var e: Empire = state.empires[c.owner_id]
	for fx: Variant in DictIO.arr_of(bdef, "effects"):
		var d: Dictionary = fx
		var key: String = DictIO.str_of(d, "key")
		var v: int = DictIO.int_of(d, "value")
		if key.begins_with("output_add:"):
			var res: String = key.trim_prefix("output_add:")
			var flat: int = Fx.div_floor(v * n.weights.get(res, 4) * _focus(fw, res), Fx.ONE * 10000)
			# Output that needs no workers is worth more while every settler already has a job.
			if cr.unemployed == 0:
				flat = Fx.div_floor(flat * 3, 2)
			parts[res] = parts.get(res, 0) + flat
		elif key.begins_with("resource_output_bp:"):
			var res2: String = key.trim_prefix("resource_output_bp:")
			var gross: int = cr.research_total() if res2 == "research" else cr.alloys_made if res2 == "alloys" else maxi(0, cr.net_of(res2))
			parts[res2] = parts.get(res2, 0) + Fx.div_floor(Fx.mul_bp(gross, v) * n.weights.get(res2, 4) * _focus(fw, res2), Fx.ONE * 10000)
		elif key == "stability_add":
			parts["stability"] = parts.get("stability", 0) + v * _stability_weight(c, fw)
		elif key == "influence_per_turn_add":
			parts["influence"] = parts.get("influence", 0) + Fx.div_floor(v * 8, Fx.ONE)
		elif key == "housing_add":
			parts["housing"] = parts.get("housing", 0) + v * _housing_weight(cr, fw)
		elif key == "growth_bp":
			if cr.free_housing > 1:
				var small: int = 5 if c.pops < ColonyRules.DEVELOPED_POPS else 2
				parts["growth"] = parts.get("growth", 0) + Fx.div_floor(v * small * _focus(fw, "growth"), 100 * 10000)
		elif key.begins_with("cap_add:"):
			var res3: String = key.trim_prefix("cap_add:")
			var cap: int = er.cap_of(res3)
			if cap > 0 and e.stock_of(res3) * 10 >= cap * 7 and er.net_of(res3) > 0:
				parts["storage"] = parts.get("storage", 0) + (20 if e.stock_of(res3) * 10 >= cap * 9 else 8)
	for av: Variant in DictIO.arr_of(bdef, "adjacency"):
		var rule: Dictionary = av
		var adj: int = Economy._adjacent_districts(c, slots, slot, DictIO.str_of(rule, "with"))
		parts["stability"] = parts.get("stability", 0) + adj * DictIO.int_of(rule, "stability_add") * _stability_weight(c, fw)
		parts["housing"] = parts.get("housing", 0) + adj * DictIO.int_of(rule, "housing_add") * _housing_weight(cr, fw)
	if bid == "spaceport":
		parts["ships"] = 0 if _empire_has_service(state, e, "spaceport") else 12
	if bid == "market_exchange":
		# Worth it when stocks pile up with nothing to spend them on.
		var surplus: int = 0
		for res4: String in ["energy", "food", "alloys", "minerals"]:
			if e.stock_of(res4) > 6000 and er.net_of(res4) > 0:
				surplus += 1
		parts["storage"] = parts.get("storage", 0) + surplus * 30
	if bid == "habitat_dome" and not ColonyRules.is_dome_world(planet):
		return null
	var upkeep: int = int(DictIO.dict_of(bdef, "upkeep").get("energy", 0))
	parts["upkeep"] = -Fx.div_floor(upkeep * n.weights["energy"], Fx.ONE)
	# A second copy of the same building helps less, and a third hardly at all.
	var copies: int = 0
	for pb: Colony.PlacedBuilding in c.buildings:
		if pb.building_id == bid:
			copies += 1
	for item: BuildItem in c.queue:
		if item.kind == BuildItem.KIND_BUILDING and item.def_id == bid:
			copies += 1
	if copies > 0:
		for k: String in parts.keys():
			if parts[k] > 0:
				parts[k] = Fx.div_floor(parts[k], 1 + copies * 2)
	# Keep enough slots for the districts a developed colony needs.
	if not _room_for_districts(c, planet):
		return null
	_finish(o, parts, cr, n, fw)
	return o


## True when a building here still leaves room for DEVELOPED_DISTRICTS districts.
static func _room_for_districts(c: Colony, planet: Planet) -> bool:
	var districts: int = c.districts.size()
	for item: BuildItem in c.queue:
		if item.kind == BuildItem.KIND_DISTRICT:
			districts += 1
	var needed: int = maxi(0, ColonyRules.DEVELOPED_DISTRICTS - districts)
	return ColonyRules.free_slots(c, planet).size() - 1 >= needed


static func _empire_has_service(state: GameState, e: Empire, service: String) -> bool:
	for c: Colony in state.colonies_of(e.id):
		if Construction.provides(c, service):
			return true
	return false


static func _option(kind: String, def_id: String, slot: int, branch: String, tier: int, cost: Dictionary[String, int]) -> Option:
	var o: Option = Option.new()
	o.kind = kind
	o.def_id = def_id
	o.slot = slot
	o.branch = branch
	o.tier = tier
	o.cost = cost
	return o


## Expected share of new jobs that will be filled: settlers without work now, plus the few that
## free homes will soon bring, minus jobs already standing empty.
static func _fill_bp(cr: Economy.ColonyReport, jobs: int) -> int:
	if jobs <= 0:
		return 0
	var open_jobs: int = cr.jobs_total - cr.employed
	var available: int = cr.unemployed + mini(maxi(0, cr.free_housing), 3) - open_jobs
	return clampi(Fx.div_floor(available * 10000, jobs), 0, 10000)


static func _district_jobs(ddef: Dictionary, tier: int) -> int:
	var n: int = DictIO.int_of(Economy._tier_record(ddef, tier), "extra_jobs")
	for jv: Variant in DictIO.arr_of(ddef, "jobs"):
		n += DictIO.int_of(jv, "count")
	return n


static func _slot_adjacency_bp(c: Colony, planet: Planet, did: String, slot: int) -> int:
	var ddef: Dictionary = Content.db().record("districts", did)
	var slots: int = ColonyRules.slot_count(planet)
	var bp: int = 0
	for av: Variant in DictIO.arr_of(ddef, "adjacency"):
		var rule: Dictionary = av
		var b: int = DictIO.int_of(rule, "bonus_bp")
		if b != 0:
			bp += mini(Economy._adjacent_districts(c, slots, slot, DictIO.str_of(rule, "with")) * b, DictIO.int_of(rule, "cap_bp", 10000))
	return bp


static func _job_value(ddef: Dictionary, tier: int, fill_bp: int, bonus_bp: int, n: Needs, fw: Dictionary, parts: Dictionary[String, int]) -> void:
	_job_value_count(ddef, _district_jobs(ddef, tier), fill_bp, bonus_bp, n, fw, parts, true)


## Adds the weighted value of `jobs` jobs of the district's job, filled at fill_bp, with output
## raised by bonus_bp. With count_extras false only the output counts (an upgrade's gain on jobs
## that already exist uses no more input and adds no more clerks).
static func _job_value_count(ddef: Dictionary, jobs: int, fill_bp: int, bonus_bp: int, n: Needs, fw: Dictionary, parts: Dictionary[String, int], count_extras: bool) -> void:
	var db: ContentDb = Content.db()
	for jv: Variant in DictIO.arr_of(ddef, "jobs"):
		var job: Dictionary = db.record("jobs", DictIO.str_of(jv, "job"))
		var workers: int = Fx.mul_bp(jobs * 100, fill_bp)
		var out: Dictionary = DictIO.dict_of(job, "output")
		for res: Variant in out.keys():
			var amount: int = Fx.div_floor(workers * int(out[res]), 100)
			amount += Fx.mul_bp(amount, bonus_bp)
			var w: int = n.weights.get(str(res), 4) * _focus(fw, str(res))
			parts[str(res)] = parts.get(str(res), 0) + Fx.div_floor(amount * w, Fx.ONE * 10000)
		if not count_extras:
			continue
		var input: Dictionary = DictIO.dict_of(job, "input")
		for res2: Variant in input.keys():
			var used: int = Fx.div_floor(workers * int(input[res2]), 100)
			parts[str(res2)] = parts.get(str(res2), 0) - Fx.div_floor(used * n.weights.get(str(res2), 4), Fx.ONE)
		var stab: int = DictIO.int_of(job, "stability_add")
		if stab != 0:
			parts["stability"] = parts.get("stability", 0) + Fx.div_floor(workers * stab, 100) * 3


static func _focus(fw: Dictionary, what: String) -> int:
	return int(fw.get(what, 10000))


static func _housing_weight(cr: Economy.ColonyReport, fw: Dictionary) -> int:
	var w: int = 1
	if cr.free_housing <= 0:
		w = 18
	elif cr.free_housing <= 2:
		w = 10
	elif cr.free_housing <= 4:
		w = 4
	return Fx.div_floor(w * _focus(fw, "housing"), 10000)


static func _stability_weight(c: Colony, fw: Dictionary) -> int:
	var w: int = 1
	if c.stability < 45:
		w = 12
	elif c.stability < 60:
		w = 5
	elif c.stability < 70:
		w = 2
	return Fx.div_floor(w * _focus(fw, "stability"), 10000)


## Sums the parts into the option's value and names the biggest positive part as the reason.
static func _finish(o: Option, parts: Dictionary[String, int], cr: Economy.ColonyReport, n: Needs, fw: Dictionary) -> void:
	var total: int = 0
	var top: String = ""
	var top_v: int = 0
	for k: String in DictIO.sorted_keys(parts):
		total += parts[k]
		if parts[k] > top_v:
			top_v = parts[k]
			top = k
	o.value = maxi(0, total)
	o.reason_key = "governor.reason.best_value"
	o.reason_args = {}
	match top:
		"housing":
			o.reason_key = "governor.reason.housing"
			o.reason_args = {"free": maxi(0, cr.free_housing)}
		"stability":
			o.reason_key = "governor.reason.stability"
		"growth":
			o.reason_key = "governor.reason.growth"
		"storage":
			o.reason_key = "governor.reason.storage"
		"ships":
			o.reason_key = "governor.reason.spaceport"
		"food", "energy", "minerals", "alloys", "research":
			var r: Array = n.reasons.get(top, [])
			if not r.is_empty():
				o.reason_key = str(r[0])
				o.reason_args = (r[1] as Dictionary).duplicate()
			elif cr.unemployed > 0:
				o.reason_key = "governor.reason.jobs"
				o.reason_args = {"count": cr.unemployed}
			else:
				o.reason_key = "governor.reason.output"
				o.reason_args = {"resource_key": "res.%s.name" % top}
	if not fw.is_empty() and int(fw.get(top, 10000)) > 10000:
		o.reason_args["focus"] = 1


static func _cost_total(cost: Dictionary[String, int]) -> int:
	var sum: int = 0
	for k: String in cost.keys():
		sum += cost[k]
	return sum


# --- Event choices --------------------------------------------------------------------------

## How much a choice of a pending event is worth to the empire, in the same points as build
## options. `stability_w` scales how much stability matters (the turtle values it more).
static func choice_value(state: GameState, e: Empire, ev: EventInstance, index: int, stability_w: int = 10000) -> int:
	var st: Dictionary = Events.step_of(ev.chain, ev.step)
	var choices: Array = DictIO.arr_of(st, "choices")
	if index < 0 or index >= choices.size():
		return -(1 << 30)
	var ch: Dictionary = choices[index]
	var er: Economy.EmpireReport = Economy.empire(state, e.id)
	var n: Needs = needs(state, e, er)
	var v: int = 0
	var cost: Dictionary = DictIO.dict_of(ch, "cost")
	for res: Variant in cost.keys():
		v -= Fx.div_floor(int(cost[res]) * _stock_weight(str(res), n), Fx.ONE)
	v += effects_value(state, e, er, n, Events.scaled(state, DictIO.arr_of(ch, "effects"), ev.chain), ev.colony_id, stability_w)
	var outcomes: Array = DictIO.arr_of(ch, "outcomes")
	for ov: Variant in outcomes:
		var od: Dictionary = ov
		var ev_v: int = effects_value(state, e, er, n, Events.scaled(state, DictIO.arr_of(od, "effects"), ev.chain), ev.colony_id, stability_w)
		v += Fx.mul_bp(ev_v, DictIO.int_of(od, "chance_bp"))
	if not DictIO.dict_of(ch, "next").is_empty():
		v += 5
	return v


## The value of a list of effect records over a 30-turn horizon.
static func effects_value(state: GameState, e: Empire, er: Economy.EmpireReport, n: Needs, effects: Array, colony_id: String, stability_w: int = 10000) -> int:
	const HORIZON: int = 30
	var v: int = 0
	var colonies: int = maxi(1, ColonyRules.settled(state, e.id).size())
	for fx: Variant in effects:
		var d: Dictionary = fx
		var key: String = DictIO.str_of(d, "key")
		var val: int = DictIO.int_of(d, "value")
		var turns: int = mini(HORIZON, DictIO.int_of(d, "turns", HORIZON))
		var scope: int = 1 if DictIO.str_of(d, "target") == "colony" else colonies
		if key == "stability_add":
			var low: int = 3 if _lowest_stability(state, e) < 50 else 1
			v += Fx.mul_bp(val * turns * scope * low, stability_w)
		elif key.begins_with("resource_output_bp:"):
			var res: String = key.trim_prefix("resource_output_bp:")
			var gross: int = er.research_total() if res == "research" else maxi(0, er.net_of(res)) + 500
			v += Fx.div_floor(Fx.mul_bp(gross, val) * turns * n.weights.get(res, 4), Fx.ONE)
		elif key == "output_bp":
			var all: int = 0
			for res2: String in Economy.PRODUCED:
				all += maxi(0, er.net_of(res2)) + 300
			v += Fx.div_floor(Fx.mul_bp(all, val) * turns * 5, Fx.ONE)
		elif key.begins_with("research_bp:"):
			v += Fx.div_floor(Fx.mul_bp(er.research_total(), val) * turns * n.weights["research"], Fx.ONE)
		elif key == "growth_bp":
			v += Fx.div_floor(val * turns * scope, 1000)
		elif key.begins_with("add_stock:"):
			v += Fx.div_floor(val * _stock_weight(key.trim_prefix("add_stock:"), n), Fx.ONE)
		elif key == "add_pops":
			v += val * 40
		elif key == "remove_pops":
			v -= val * 60
		elif key == "influence_per_turn_add":
			v += Fx.div_floor(val * turns * 8, Fx.ONE)
		elif key == "housing_add":
			v += val * 12 * Fx.div_floor(turns, 10)
		elif key == "decode_progress_add":
			v += Fx.div_floor(val * 20, Fx.ONE)
		elif key.begins_with("cap_add:"):
			v += Fx.div_floor(val, 1000)
		elif key == "rejoin_colony":
			v += 600
	return v


## What the colonies make of a resource before upkeep, consumption and inputs (the flat lines).
static func _gross(er: Economy.EmpireReport, res: String) -> int:
	var g: int = 0
	for cid: String in er.colonies.keys():
		var cr: Economy.ColonyReport = er.colonies[cid]
		if not cr.net.has(res):
			continue
		for l: Breakdown.Line in cr.net[res].lines:
			if l.kind != Breakdown.KIND_FLAT and l.kind != Breakdown.KIND_CAP:
				g += l.value
	return maxi(0, g)


static func _stock_weight(res: String, n: Needs) -> int:
	if res == "influence":
		return 6
	return n.weights.get(res, 4)


static func _lowest_stability(state: GameState, e: Empire) -> int:
	var low: int = 100
	for c: Colony in ColonyRules.settled(state, e.id):
		low = mini(low, c.stability)
	return low
