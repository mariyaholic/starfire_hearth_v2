class_name BotRunner
extends RefCounted
## Plays one scenario with one bot policy and records per-turn telemetry (§13.7).
## Shared by tools/bot_run.gd and the integration tests.


class Run:
	extends RefCounted
	var scenario_id: String = ""
	var policy: String = ""
	var scenario_status: String = ""
	var game_seed: int = 0
	var turns: Array[Dictionary] = []
	var hashes: Array[String] = []
	var problems: Array[String] = []
	var rejected_orders: int = 0
	var final_state: GameState = null
	var outcome: String = ""
	var outcome_turn: int = 0
	var expected_turns: int = 0
	var difficulty: String = "normal"

	func summary() -> Dictionary:
		var times: Array[float] = []
		for row: Dictionary in turns:
			times.append(float(row["end_turn_ms"]))
		times.sort()
		var total: float = 0.0
		for x: float in times:
			total += x
		var p95: float = 0.0
		if not times.is_empty():
			p95 = times[mini(times.size() - 1, int(ceil(times.size() * 0.95)) - 1)]
		return {
			"turns": turns.size(),
			"outcome": outcome,
			"outcome_turn": outcome_turn,
			"expected_turns": expected_turns,
			"final_hash": hashes[hashes.size() - 1] if not hashes.is_empty() else "",
			"invariant_problems": problems.size(),
			"rejected_orders": rejected_orders,
			"end_turn_ms_mean": total / maxf(1.0, float(times.size())),
			"end_turn_ms_p95": p95,
			"end_turn_ms_max": times[times.size() - 1] if not times.is_empty() else 0.0,
		}

	func to_dict() -> Dictionary:
		return {
			"meta": {
				"scenario": scenario_id, "policy": policy, "seed": game_seed,
				"difficulty": difficulty, "schema_version": GameState.SCHEMA_VERSION,
				"scenario_status": scenario_status,
			},
			"summary": summary(),
			"turns": turns,
			"problems": problems.slice(0, 50),
		}


## Resolves "s1" to "s1_first_light" (unique prefix match on scenario ids).
static func resolve_scenario(db: ContentDb, name: String) -> String:
	if db.scenarios.has(name):
		return name
	var found: Array[String] = []
	for id: String in DictIO.sorted_keys(db.scenarios):
		if id.begins_with(name + "_"):
			found.append(id)
	return found[0] if found.size() == 1 else ""


static func run(db: ContentDb, scenario_id: String, policy: String, game_seed: int, turn_count: int, difficulty_id: String = "normal") -> Run:
	var r: Run = Run.new()
	r.scenario_id = scenario_id
	r.policy = policy
	r.game_seed = game_seed
	r.scenario_status = DictIO.str_of(db.scenarios.get(scenario_id, {}), "status")
	r.expected_turns = DictIO.int_of(db.scenarios.get(scenario_id, {}), "expected_turns")
	r.difficulty = difficulty_id
	var state: GameState = ScenarioLoader.build(db, scenario_id, game_seed, difficulty_id)
	for p: String in Invariants.check(state):
		r.problems.append("start: " + p)
	r.hashes.append(state.state_hash())
	for i in turn_count:
		var decision: BotPolicy.Decision = BotPolicy.decide(policy, state, state.player_id, game_seed)
		var queue: CommandQueue = CommandQueue.new(state)
		for cmd: Command in decision.commands:
			var v: Result = queue.submit(cmd)
			if not v.ok:
				r.problems.append("turn %d: bot order rejected at submit: %s" % [state.turn, v.reason_key])
		var t0: int = Time.get_ticks_usec()
		var tr: TurnResult = TurnProcessor.run(state, queue.commands())
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		r.rejected_orders += tr.rejected.size()
		for p: String in Invariants.check(tr.state):
			r.problems.append("turn %d: %s" % [tr.state.turn, p])
		if tr.state_hash.is_empty():
			r.problems.append("turn %d: state hash could not be computed" % tr.state.turn)
		r.turns.append(_row(tr, decision, ms))
		r.hashes.append(tr.state_hash)
		state = tr.state
		if state.is_over():
			break
	r.final_state = state
	r.outcome = state.outcome
	r.outcome_turn = state.outcome_turn
	return r


## Gross income: what the colonies produce before upkeep, consumption and inputs (the flat
## lines), plus influence's positive sources.
static func gross_income(er: Economy.EmpireReport, res: String) -> int:
	var g: int = 0
	if res == "influence":
		for l: Breakdown.Line in er.net["influence"].lines:
			g += maxi(0, l.value)
		return g
	for cid: String in er.colonies.keys():
		var cr: Economy.ColonyReport = er.colonies[cid]
		if not cr.net.has(res):
			continue
		for l: Breakdown.Line in cr.net[res].lines:
			if l.kind != Breakdown.KIND_FLAT and l.kind != Breakdown.KIND_CAP:
				g += l.value
	return maxi(0, g)


static func _row(tr: TurnResult, decision: BotPolicy.Decision, ms: float) -> Dictionary:
	var s: GameState = tr.state
	var p: Empire = s.player()
	var income: Dictionary = {}
	var caps: Dictionary = {}
	var gross: Dictionary = {}
	if p != null and tr.reports.has(p.id):
		var er: Economy.EmpireReport = tr.reports[p.id]
		for res: String in Economy.STOCKED:
			income[res] = er.net_of(res)
			caps[res] = er.cap_of(res)
			gross[res] = gross_income(er, res)
		income["research"] = er.research_total()
		for b: String in Empire.BRANCHES:
			income["research:" + b] = er.research[b].total if er.research.has(b) else 0
		var cards: Dictionary = {}
		for b2: String in Empire.BRANCHES:
			cards[b2] = p.branch(b2).card
		income["cards"] = cards
	var overflow: Dictionary = {}
	var events: Array = []
	for it: ReportItem in tr.report_items:
		if it.text_key == "report.overflow":
			overflow[str(it.args.get("resource_key", ""))] = int(it.args.get("lost_c", 0))
	for entry: EventLogEntry in s.event_log:
		if entry.turn == s.turn - 1:
			events.append("%s:%d" % [entry.chain, entry.step])
	var stability_min: int = 100
	var stability_sum: int = 0
	var colonies: int = 0
	var pops: int = 0
	var built: Dictionary = {}
	var outposts: int = 0
	for cid: String in DictIO.sorted_keys(s.colonies):
		var c: Colony = s.colonies[cid]
		if p == null or c.owner_id != p.id:
			continue
		if c.is_outpost():
			outposts += 1
			continue
		colonies += 1
		pops += c.pops
		stability_min = mini(stability_min, c.stability)
		stability_sum += c.stability
		for pd: Colony.PlacedDistrict in c.districts:
			built[pd.district_id] = int(built.get(pd.district_id, 0)) + 1
		for pb: Colony.PlacedBuilding in c.buildings:
			built[pb.building_id] = int(built.get(pb.building_id, 0)) + 1
	return {
		"turn": s.turn - 1,
		"stocks": DictIO.plain(p.stock) if p != null else {},
		"income": income,
		"gross": gross,
		"caps": caps,
		"overflow": overflow,
		"built": built,
		"techs": p.techs.duplicate() if p != null else [],
		"colonies": colonies,
		"outposts": outposts,
		"pops": pops,
		"stability_min": stability_min if colonies > 0 else 0,
		"stability_mean": stability_sum / maxi(1, colonies),
		"decisions_available": decision.legal,
		"decisions_meaningful": decision.meaningful,
		"decisions_taken": decision.commands.size(),
		"events_fired": events,
		"battles": tr.battles.size(),
		"objectives": DictIO.plain(s.objectives_done),
		"outcome": s.outcome,
		"end_turn_ms": snappedf(ms, 0.01),
		"hash": tr.state_hash,
	}
