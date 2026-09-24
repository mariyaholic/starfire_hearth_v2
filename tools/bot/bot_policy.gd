class_name BotPolicy
extends RefCounted
## Bot players for headless playthroughs (§13.7). A policy reads the start-of-turn state and gives
## orders through the same commands and validation a human uses.
##
## M0 has no economy yet: the only orders that exist are renaming a colony and reordering its job
## priorities, and neither changes an outcome. So every policy except random-legal passes, and no
## order counts as a meaningful decision. The policies grow with the rules from M1 on.

const POLICIES: Array[String] = ["balanced", "economy", "military", "turtle", "random-legal"]
## Stream id for the bot's own choices; outside the game's stream ids (Rng.GEN .. Rng.FORECAST).
const BOT_STREAM: int = 99


class Decision:
	extends RefCounted
	var commands: Array[Command] = []
	## Legal orders the bot could have given this turn.
	var legal: int = 0
	## Legal orders that would change an outcome (the "no dead turns" gate counts these).
	var meaningful: int = 0


static func is_known(policy: String) -> bool:
	return POLICIES.has(policy)


## Every order the empire could legally give this turn (a representative sample per colony).
static func legal_commands(state: GameState, empire_id: String) -> Array[Command]:
	var out: Array[Command] = []
	for cid: String in DictIO.sorted_keys(state.colonies):
		var c: Colony = state.colonies[cid]
		if c.owner_id != empire_id:
			continue
		var rotated: Array[String] = c.job_priority.duplicate()
		rotated.push_back(rotated.pop_front())
		out.append(SetJobPriorityCommand.create(empire_id, cid, rotated))
		out.append(RenameColonyCommand.create(empire_id, cid, "Hearth %s" % cid.trim_prefix("col_")))
	var valid: Array[Command] = []
	for cmd: Command in out:
		if cmd.validate(state).ok:
			valid.append(cmd)
	return valid


static func decide(policy: String, state: GameState, empire_id: String, bot_seed: int) -> Decision:
	var d: Decision = Decision.new()
	var legal: Array[Command] = legal_commands(state, empire_id)
	d.legal = legal.size()
	d.meaningful = 0
	if policy == "random-legal" and not legal.is_empty():
		var rng: RngStream = Rng.stream(bot_seed, state.turn, BOT_STREAM, Rng.salt_of(policy))
		var pick: int = rng.range(0, legal.size())
		if pick < legal.size():
			d.commands.append(legal[pick])
	return d
