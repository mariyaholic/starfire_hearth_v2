class_name Events
extends RefCounted
## The event engine (§5.10, §13.4). A chain is data (data/events/<chain>.json): steps with a
## trigger, a speaker and music cue, a title and body, and 2–4 choices with costs, effects,
## flags and an optional delayed next step.
##
## - Scripted chains (`kind` "scripted" or "main_arc") fire their first step as soon as its
##   trigger holds; later steps are scheduled by the choice that leads to them.
## - Status chains (famine, unrest, autonomy) fire like scripted ones, with a cooldown.
## - Emergent chains are picked by the director: at most one every 4–6 turns (seeded), never in a
##   turn when a scripted step fired, weighted toward chains not seen recently.
##
## Triggers use a closed set of conditions (CONDITIONS); each one met is written to the Why? log
## with a readable reason.

const KIND_SCRIPTED: String = "scripted"
const KIND_MAIN_ARC: String = "main_arc"
const KIND_STATUS: String = "status"
const KIND_EMERGENT: String = "emergent"

const CONDITIONS: Array[String] = [
	"min_turn", "max_turn", "flags_all", "flags_none", "colony_stability_max",
	"colony_stability_min", "colony_pops_min", "colonies_min", "has_building", "has_district",
	"techs_all", "stock_min", "net_max", "net_min", "decode_min", "outposts_min",
	"colony_planet_type", "colony_is_capital", "stock_max", "autonomous_colony",
]

const DIRECTOR_GAP_MIN: int = 4
const DIRECTOR_GAP_MAX: int = 6
## A chain seen within this many turns has its weight cut to a quarter.
const RECENT_TURNS: int = 20
## Negative numbers these keys carry are scaled by the difficulty's event severity.
const SEVERITY_KEYS: Array[String] = ["stability_add", "output_bp", "growth_bp", "influence_per_turn_add"]
const SEVERITY_PREFIXES: Array[String] = ["resource_output_bp:", "research_bp:", "add_stock:"]


# --- Lookups --------------------------------------------------------------------------------

static func chain(chain_id: String) -> Dictionary:
	return Content.db().events.get(chain_id, {})


static func step_of(chain_id: String, step: int) -> Dictionary:
	for sv: Variant in DictIO.arr_of(chain(chain_id), "steps"):
		var s: Dictionary = sv
		if DictIO.int_of(s, "step", 1) == step:
			return s
	return {}


static func pending_for(state: GameState, empire_id: String) -> Array[EventInstance]:
	var out: Array[EventInstance] = []
	for ev: EventInstance in state.events_pending:
		if ev.empire_id == empire_id:
			out.append(ev)
	return out


static func find_pending(state: GameState, event_id: String) -> EventInstance:
	for ev: EventInstance in state.events_pending:
		if ev.id == event_id:
			return ev
	return null


## The chains this scenario uses: its scripted list, plus every chain whose `scenarios` lists it.
static func chains_for(state: GameState) -> Array[String]:
	var db: ContentDb = Content.db()
	var sc: Dictionary = db.scenarios.get(state.scenario_id, {})
	var out: Array[String] = []
	for cid: String in DictIO.str_arr(sc, "scripted_events"):
		if db.events.has(cid) and not out.has(cid):
			out.append(cid)
	for cid: String in DictIO.sorted_keys(db.events):
		if DictIO.str_arr(db.events[cid], "scenarios").has(state.scenario_id) and not out.has(cid):
			out.append(cid)
	return out


# --- Choosing -------------------------------------------------------------------------------

static func can_choose(state: GameState, empire_id: String, event_id: String, choice: int) -> Result:
	var ev: EventInstance = find_pending(state, event_id)
	if ev == null:
		return Result.fail("error.event.not_pending")
	if ev.empire_id != empire_id:
		return Result.fail("error.event.not_yours")
	var choices: Array = DictIO.arr_of(step_of(ev.chain, ev.step), "choices")
	if choice < 0 or choice >= choices.size():
		return Result.fail("error.event.bad_choice")
	var ch: Dictionary = choices[choice]
	var req: Dictionary = DictIO.dict_of(ch, "requires")
	if not req.is_empty() and not check(state, state.empires[empire_id], req, ev.colony_id).ok:
		return Result.fail("error.event.choice_locked", {"reason_key": DictIO.str_of(ch, "locked_key", "error.event.choice_locked_generic")})
	return Construction._check_cost(state.empires[empire_id], Construction._res_map(DictIO.dict_of(ch, "cost")))


## Pays the choice's cost, applies its effects and flags, rolls an "Uncertain" outcome, schedules
## the next step and logs it. `r` may be null (a command applied outside a turn).
static func choose(state: GameState, empire_id: String, event_id: String, choice: int, r: TurnResult) -> void:
	var ev: EventInstance = find_pending(state, event_id)
	if ev == null:
		return
	var e: Empire = state.empires[empire_id]
	var st: Dictionary = step_of(ev.chain, ev.step)
	var ch: Dictionary = DictIO.arr_of(st, "choices")[choice]
	var cost: Dictionary[String, int] = Construction._res_map(DictIO.dict_of(ch, "cost"))
	for res: String in DictIO.sorted_keys(cost):
		e.stock[res] = maxi(0, e.stock_of(res) - cost[res])
	var source_key: String = DictIO.str_of(st, "title_key")
	var outcome: int = -1
	var effects: Array = DictIO.arr_of(ch, "effects").duplicate(true)
	var flags: Array[String] = DictIO.str_arr(ch, "set_flags")
	var next: Dictionary = DictIO.dict_of(ch, "next")
	var outcomes: Array = DictIO.arr_of(ch, "outcomes")
	if not outcomes.is_empty():
		var rng: RngStream = Rng.stream(state.game_seed, state.turn, Rng.EVENTS, Rng.salt_of(ev.id))
		var weights: Array[int] = []
		for ov: Variant in outcomes:
			weights.append(DictIO.int_of(ov, "chance_bp"))
		outcome = rng.weighted(weights)
		if outcome >= 0:
			var oc: Dictionary = outcomes[outcome]
			effects.append_array(DictIO.arr_of(oc, "effects"))
			flags.append_array(DictIO.str_arr(oc, "set_flags"))
			if oc.has("next"):
				next = DictIO.dict_of(oc, "next")
	Effects.apply(state, empire_id, ev.colony_id, scaled(state, effects, ev.chain), source_key, r)
	for f: String in flags:
		state.flags[f] = state.turn
	for f: String in DictIO.str_arr(ch, "clear_flags"):
		state.flags.erase(f)
	if not next.is_empty():
		var nx: EventInstance = EventInstance.new()
		nx.id = state.next_id("evt")
		nx.chain = ev.chain
		nx.step = DictIO.int_of(next, "step", ev.step + 1)
		nx.empire_id = empire_id
		nx.colony_id = ev.colony_id
		nx.turn = state.turn + maxi(1, DictIO.int_of(next, "delay_turns", 1))
		nx.cause = "chain"
		state.events_scheduled.append(nx)
	for entry: EventLogEntry in state.event_log:
		if entry.chain == ev.chain and entry.step == ev.step and entry.choice < 0 and entry.turn == ev.turn:
			entry.choice = choice
			entry.outcome = outcome
	state.events_pending.erase(ev)


## Effect records with difficulty applied: negative values of the listed keys are scaled by
## event severity (story events keep their numbers).
static func scaled(state: GameState, effects: Array, chain_id: String) -> Array:
	var kind: String = DictIO.str_of(chain(chain_id), "kind", KIND_EMERGENT)
	var bp: int = DictIO.int_of(Content.db().record("difficulty", state.difficulty_id), "event_severity_bp", 10000)
	if bp == 10000 or kind == KIND_MAIN_ARC or kind == KIND_SCRIPTED:
		return effects
	var out: Array = []
	for fx: Variant in effects:
		var d: Dictionary = (fx as Dictionary).duplicate()
		var key: String = DictIO.str_of(d, "key")
		var v: int = DictIO.int_of(d, "value")
		if v < 0 and _severity_applies(key):
			d["value"] = -Fx.mul_bp(-v, bp)
		elif key == "remove_pops" and v > 0:
			d["value"] = maxi(1, Fx.mul_bp(v, bp))
		out.append(d)
	return out


static func _severity_applies(key: String) -> bool:
	if SEVERITY_KEYS.has(key):
		return true
	for p: String in SEVERITY_PREFIXES:
		if key.begins_with(p):
			return true
	return false


# --- Phase 12 -------------------------------------------------------------------------------

static func run(state: GameState, r: TurnResult) -> void:
	_deliver_scheduled(state, r)
	if state.is_over():
		return
	for eid: String in DictIO.sorted_keys(state.empires):
		var e: Empire = state.empires[eid]
		if not e.is_player:
			continue
		var scripted_fired: bool = _fire_due(state, e, r)
		scripted_fired = _fire_triggered(state, e, r) or scripted_fired
		if not scripted_fired:
			_director(state, e, r)


## Scheduled chain steps that are due.
static func _fire_due(state: GameState, e: Empire, r: TurnResult) -> bool:
	var fired: bool = false
	var keep: Array[EventInstance] = []
	for ev: EventInstance in state.events_scheduled:
		if ev.empire_id != e.id or ev.turn > state.turn:
			keep.append(ev)
			continue
		var st: Dictionary = step_of(ev.chain, ev.step)
		if st.is_empty():
			continue
		var req: Dictionary = DictIO.dict_of(st, "trigger")
		if not req.is_empty() and not check(state, e, req, ev.colony_id).ok:
			# Not yet: try again next turn.
			keep.append(ev)
			continue
		if ev.colony_id != "" and not state.colonies.has(ev.colony_id):
			continue
		_fire(state, e, ev.chain, ev.step, ev.colony_id, "chain", [], r)
		fired = true
	state.events_scheduled = keep
	return fired


## First steps of scripted, main-arc and status chains whose triggers hold.
static func _fire_triggered(state: GameState, e: Empire, r: TurnResult) -> bool:
	var fired: bool = false
	for cid: String in chains_for(state):
		var ch: Dictionary = chain(cid)
		var kind: String = DictIO.str_of(ch, "kind", KIND_EMERGENT)
		if kind == KIND_EMERGENT:
			continue
		if not _may_fire_again(state, cid, ch):
			continue
		if _in_flight(state, e, cid):
			continue
		var st: Dictionary = step_of(cid, 1)
		var res: Check = check(state, e, DictIO.dict_of(st, "trigger"), "")
		if not res.ok:
			continue
		_fire(state, e, cid, 1, res.colony_id, kind, res.reasons, r)
		if kind != KIND_STATUS:
			fired = true
	return fired


## The event director (§5.10): at most one emergent event every 4–6 turns, seeded.
static func _director(state: GameState, e: Empire, r: TurnResult) -> void:
	var sc: Dictionary = Content.db().scenarios.get(state.scenario_id, {})
	var start: int = DictIO.int_of(sc, "director_start", 6)
	if state.turn < maxi(start, state.director_next):
		return
	if not pending_for(state, e.id).is_empty():
		return
	var ids: Array[String] = []
	var weights: Array[int] = []
	var checks: Array[Check] = []
	for cid: String in chains_for(state):
		var ch: Dictionary = chain(cid)
		if DictIO.str_of(ch, "kind", KIND_EMERGENT) != KIND_EMERGENT:
			continue
		if not _may_fire_again(state, cid, ch) or _in_flight(state, e, cid):
			continue
		var res: Check = check(state, e, DictIO.dict_of(step_of(cid, 1), "trigger"), "")
		if not res.ok:
			continue
		var w: int = DictIO.int_of(ch, "weight", 100)
		if state.event_memory.has(cid) and state.turn - state.event_memory[cid] < RECENT_TURNS:
			w = maxi(1, Fx.div_floor(w, 4))
		ids.append(cid)
		weights.append(w)
		checks.append(res)
	var rng: RngStream = Rng.stream(state.game_seed, state.turn, Rng.EVENTS, Rng.salt_of("director:" + e.id))
	state.director_next = state.turn + rng.range(DIRECTOR_GAP_MIN, DIRECTOR_GAP_MAX)
	if ids.is_empty():
		return
	var pick: int = rng.weighted(weights)
	if pick < 0:
		return
	_fire(state, e, ids[pick], 1, checks[pick].colony_id, "director", checks[pick].reasons, r)


static func _may_fire_again(state: GameState, cid: String, ch: Dictionary) -> bool:
	if not state.event_memory.has(cid):
		return true
	var cooldown: int = DictIO.int_of(ch, "cooldown", 0)
	if cooldown <= 0:
		return false
	return state.turn - state.event_memory[cid] >= cooldown


static func _in_flight(state: GameState, e: Empire, cid: String) -> bool:
	for list: Array in [state.events_pending, state.events_scheduled]:
		for ev: EventInstance in list:
			if ev.chain == cid and ev.empire_id == e.id:
				return true
	return false


static func _fire(state: GameState, e: Empire, cid: String, step: int, colony_id: String, cause: String, reasons: Array[Dictionary], r: TurnResult) -> void:
	var st: Dictionary = step_of(cid, step)
	var ev: EventInstance = EventInstance.new()
	ev.id = state.next_id("evt")
	ev.chain = cid
	ev.step = step
	ev.empire_id = e.id
	ev.colony_id = colony_id if not colony_id.is_empty() else e.capital_id
	ev.turn = state.turn
	ev.cause = cause
	if step == 1:
		state.event_memory[cid] = state.turn
	var on_fire: Dictionary = DictIO.dict_of(st, "on_fire")
	Effects.apply(state, e.id, ev.colony_id, scaled(state, DictIO.arr_of(on_fire, "effects"), cid), DictIO.str_of(st, "title_key"), r)
	for f: String in DictIO.str_arr(on_fire, "set_flags"):
		state.flags[f] = state.turn
	var log: EventLogEntry = EventLogEntry.new()
	log.turn = state.turn
	log.chain = cid
	log.step = step
	log.colony_id = ev.colony_id
	state.event_log.append(log)
	if DictIO.arr_of(st, "choices").is_empty():
		# A closing step with nothing to decide: it is read in the report and the log.
		log.choice = 0
	else:
		state.events_pending.append(ev)
	if r != null:
		var why: WhyLog.Entry = r.why_log.record(WhyLog.KIND_EVENT_TRIGGER, state.turn, "event", ev.id, DictIO.str_of(st, "title_key"))
		WhyLog.cause(why, Names.event_cause(cause), 0)
		for reason: Dictionary in reasons:
			WhyLog.cause(why, str(reason["key"]), 0, reason.get("args", {}))
		var args: Dictionary = {"title_key": DictIO.str_of(st, "title_key")}
		r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 70, "report.event", args)
			.with_severity(ReportItem.SEVERITY_INFO).focus("event", ev.id))


# --- Conditions -----------------------------------------------------------------------------

## The outcome of a trigger check: whether it holds, the colony it is about (if any), and the
## readable reasons of every condition that was met.
class Check:
	extends RefCounted
	var ok: bool = true
	var colony_id: String = ""
	var reasons: Array[Dictionary] = []


## Evaluates a trigger. Colony conditions pick the first colony (in id order) that meets all of
## them, or check `colony_id` when it is given.
static func check(state: GameState, e: Empire, trig: Dictionary, colony_id: String) -> Check:
	var out: Check = Check.new()
	for key: Variant in trig.keys():
		if not CONDITIONS.has(str(key)) and not ["weight", "scripted", "chance_bp"].has(str(key)):
			out.ok = false
			return out
	if trig.has("min_turn"):
		if state.turn < DictIO.int_of(trig, "min_turn"):
			out.ok = false
			return out
		out.reasons.append({"key": "why.cond.min_turn", "args": {"turn": DictIO.int_of(trig, "min_turn")}})
	if trig.has("max_turn") and state.turn > DictIO.int_of(trig, "max_turn"):
		out.ok = false
		return out
	for f: String in DictIO.str_arr(trig, "flags_all"):
		if not state.flags.has(f):
			out.ok = false
			return out
	for f: String in DictIO.str_arr(trig, "flags_none"):
		if state.flags.has(f):
			out.ok = false
			return out
	if trig.has("colonies_min"):
		var n: int = ColonyRules.settled(state, e.id).size()
		if n < DictIO.int_of(trig, "colonies_min"):
			out.ok = false
			return out
		out.reasons.append({"key": "why.cond.colonies_min", "args": {"count": n}})
	if trig.has("outposts_min") and ColonyRules.outposts(state, e.id).size() < DictIO.int_of(trig, "outposts_min"):
		out.ok = false
		return out
	for t: String in DictIO.str_arr(trig, "techs_all"):
		if not e.has_tech(t):
			out.ok = false
			return out
	if trig.has("decode_min"):
		if e.decode_progress < DictIO.int_of(trig, "decode_min"):
			out.ok = false
			return out
		out.reasons.append({"key": "why.cond.decode", "args": {}})
	var smin: Dictionary = DictIO.dict_of(trig, "stock_min")
	for res: Variant in smin.keys():
		if e.stock_of(str(res)) < int(smin[res]):
			out.ok = false
			return out
	var smax: Dictionary = DictIO.dict_of(trig, "stock_max")
	for res4: Variant in smax.keys():
		if e.stock_of(str(res4)) > int(smax[res4]):
			out.ok = false
			return out
		out.reasons.append({"key": "why.cond.stock_low", "args": {"resource_key": "res.%s.name" % str(res4)}})
	if trig.has("autonomous_colony"):
		for cid: String in DictIO.sorted_keys(state.colonies):
			if state.colonies[cid].autonomous_from == e.id:
				out.colony_id = cid
				out.reasons.append({"key": "why.cond.autonomous", "args": ColonyRules.name_args(state, state.colonies[cid])})
				return out
		out.ok = false
		return out
	var needs_net: bool = trig.has("net_max") or trig.has("net_min")
	if needs_net:
		var er: Economy.EmpireReport = Economy.empire(state, e.id)
		var nmax: Dictionary = DictIO.dict_of(trig, "net_max")
		for res2: Variant in nmax.keys():
			if er.net_of(str(res2)) > int(nmax[res2]):
				out.ok = false
				return out
			out.reasons.append({"key": "why.cond.net_max", "args": {"resource_key": "res.%s.name" % str(res2)}})
		var nmin: Dictionary = DictIO.dict_of(trig, "net_min")
		for res3: Variant in nmin.keys():
			if er.net_of(str(res3)) < int(nmin[res3]):
				out.ok = false
				return out
	if trig.has("has_building"):
		var bid: String = DictIO.str_of(trig, "has_building")
		var any: bool = false
		for c: Colony in state.colonies_of(e.id):
			if c.has_building(bid):
				any = true
		if not any:
			out.ok = false
			return out
	var colony_keys: Array[String] = ["colony_stability_max", "colony_stability_min", "colony_pops_min", "has_district", "colony_planet_type", "colony_is_capital"]
	var wants_colony: bool = false
	for k: String in colony_keys:
		if trig.has(k):
			wants_colony = true
	if not wants_colony:
		out.colony_id = colony_id
		return out
	var candidates: Array[Colony] = []
	if not colony_id.is_empty() and state.colonies.has(colony_id):
		candidates.append(state.colonies[colony_id])
	else:
		candidates = ColonyRules.settled(state, e.id)
	for c: Colony in candidates:
		var reasons: Array[Dictionary] = _colony_matches(state, e, c, trig)
		if reasons.size() > 0 and str(reasons[0].get("key", "")) != "":
			out.colony_id = c.id
			out.reasons.append_array(reasons)
			return out
	out.ok = false
	return out


## The reasons a colony meets every colony condition, or an empty list when it does not.
static func _colony_matches(state: GameState, e: Empire, c: Colony, trig: Dictionary) -> Array[Dictionary]:
	var reasons: Array[Dictionary] = []
	var name: Dictionary = ColonyRules.name_args(state, c)
	if c.is_outpost():
		return []
	if trig.has("colony_is_capital") and DictIO.bool_of(trig, "colony_is_capital") != (c.id == e.capital_id):
		return []
	if trig.has("colony_stability_max"):
		if c.stability > DictIO.int_of(trig, "colony_stability_max"):
			return []
		var a: Dictionary = name.duplicate()
		a["stability"] = c.stability
		reasons.append({"key": "why.cond.stability_low", "args": a})
	if trig.has("colony_stability_min"):
		if c.stability < DictIO.int_of(trig, "colony_stability_min"):
			return []
	if trig.has("colony_pops_min"):
		if c.pops < DictIO.int_of(trig, "colony_pops_min"):
			return []
		var b: Dictionary = name.duplicate()
		b["count"] = c.pops
		reasons.append({"key": "why.cond.pops", "args": b})
	if trig.has("has_district"):
		var did: String = DictIO.str_of(trig, "has_district")
		var found: bool = false
		for pd: Colony.PlacedDistrict in c.districts:
			if pd.district_id == did:
				found = true
		if not found:
			return []
		var d: Dictionary = name.duplicate()
		d["district_key"] = DictIO.str_of(Content.db().record("districts", did), "name_key")
		reasons.append({"key": "why.cond.has_district", "args": d})
	if trig.has("colony_planet_type"):
		if state.planets[c.planet_id].type != DictIO.str_of(trig, "colony_planet_type"):
			return []
	if reasons.is_empty():
		reasons.append({"key": "why.cond.colony", "args": name})
	return reasons


# --- Lasting parts --------------------------------------------------------------------------

## Phase 9, after stability: timed modifiers count down and expire.
static func tick_modifiers(state: GameState, r: TurnResult) -> void:
	for mid: String in DictIO.sorted_keys(state.modifiers):
		var m: Modifier = state.modifiers[mid]
		if m.is_permanent():
			continue
		m.turns_left -= 1
		if m.turns_left > 0:
			continue
		state.modifiers.erase(mid)
		var e: Empire = state.empires.get(m.empire_id, null)
		if e != null and e.is_player:
			r.report_items.append(ReportItem.make(ReportItem.CATEGORY_STORY, 30, "report.modifier_ended", {"name_key": m.source_key})
				.with_severity(ReportItem.SEVERITY_INFO))


static func _deliver_scheduled(state: GameState, r: TurnResult) -> void:
	var keep: Array[ScheduledEffect] = []
	for se: ScheduledEffect in state.scheduled_effects:
		var amount: int = se.due_now()
		se.elapsed += 1
		se.delivered += amount
		if amount != 0:
			Effects.apply_one(state, se.empire_id, se.colony_id, se.key, amount, se.target, se.source_key, r)
		if se.elapsed < se.over_turns:
			keep.append(se)
	state.scheduled_effects = keep
