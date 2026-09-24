class_name TurnProcessor
extends RefCounted
## Resolves one turn. The phase order below is a contract (§9.4); changing it needs a DESIGN_LOG
## entry and a golden re-baseline.
##
## run() never mutates the state it is given: it works on a clone and returns the next turn's
## state in a TurnResult. The same state and the same commands always produce the same hash.

const PHASES: Array[String] = [
	"commands",          # 1. queued player commands, then AI commands in fixed empire order
	"construction",      # 2. districts, buildings, ships, starbases, beacons
	"production",        # 3. job output -> upkeep -> market trades -> caps and overflow
	"food_growth",       # 4. food, growth and famine
	"research",          # 5. research progress, completions, new cards
	"movement",          # 6. every fleet advances; arrivals
	"combat",            # 7. combat in every contested system (seeded per system)
	"occupation",        # 8. occupation, outposts, colonisation completions
	"stability_edicts",  # 9. stability recalculation and edict ticks
	"diplomacy",         # 10. opinion decay, treaty upkeep, war exhaustion, AI diplomacy
	"noise",             # 11. Noise update
	"events",            # 12. story triggers first, then the emergent event director
	"victory",           # 13. victory and defeat checks, scenario objectives
	"report",            # 14. report, why-log and state hash (the app auto-saves the result)
]


static func run(state: GameState, player_commands: Array[Command]) -> TurnResult:
	var r: TurnResult = TurnResult.new()
	r.state = state.clone()
	var ai_commands: Array[Command] = []
	for eid: String in DictIO.sorted_keys(state.empires):
		var e: Empire = state.empires[eid]
		if not e.is_player:
			ai_commands.append_array(AiPlayer.decide(state, eid))
	for phase: String in PHASES:
		match phase:
			"commands":
				_phase_commands(r, player_commands, ai_commands)
			"construction":
				pass
			"production":
				pass
			"food_growth":
				pass
			"research":
				pass
			"movement":
				pass
			"combat":
				pass
			"occupation":
				pass
			"stability_edicts":
				pass
			"diplomacy":
				pass
			"noise":
				pass
			"events":
				pass
			"victory":
				pass
			"report":
				_phase_report(r)
		r.phase_log.append(phase)
	return r


static func _phase_commands(r: TurnResult, player_commands: Array[Command], ai_commands: Array[Command]) -> void:
	var all: Array[Command] = player_commands.duplicate()
	all.append_array(ai_commands)
	for cmd: Command in all:
		var v: Result = cmd.validate(r.state)
		if v.ok:
			cmd.apply(r.state)
			continue
		r.rejected.append({"command": cmd.to_dict(), "reason_key": v.reason_key, "args": v.args})
		if r.state.empires.has(cmd.empire_id) and r.state.empires[cmd.empire_id].is_player:
			var args: Dictionary = v.args.duplicate()
			args["reason_key"] = v.reason_key
			r.report_items.append(
				ReportItem.make(ReportItem.CATEGORY_COLONIES, 60, "report.order_rejected", args)
					.with_severity(ReportItem.SEVERITY_WARNING)
			)


static func _phase_report(r: TurnResult) -> void:
	r.state.turn += 1
	r.state_hash = r.state.state_hash()
