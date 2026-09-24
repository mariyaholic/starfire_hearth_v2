class_name Invariants
extends RefCounted
## State invariants checked by the integration tests and the bot after every turn (§9.8):
## no negative stocks, sane pops and stability, integer-only state, every id reference resolves.


## Returns a list of human-readable problems; empty means the state is sound.
static func check(state: GameState) -> Array[String]:
	var problems: Array[String] = []
	if state.turn < 1:
		problems.append("turn is %d, expected >= 1" % state.turn)
	if state.game_seed < 0 or state.game_seed > GameState.MAX_SEED:
		problems.append("game_seed out of 32-bit range")
	if state.player_id != "" and not state.empires.has(state.player_id):
		problems.append("player_id %s does not resolve" % state.player_id)

	var errors: Array[String] = []
	CanonicalJson.stringify(state.to_dict(), errors)
	for e: String in errors:
		problems.append("non-integer or unsupported value: " + e)

	for eid: String in DictIO.sorted_keys(state.empires):
		var e: Empire = state.empires[eid]
		if e.id != eid:
			problems.append("empire key %s holds id %s" % [eid, e.id])
		for res: String in DictIO.sorted_keys(e.stock):
			if e.stock[res] < 0:
				problems.append("empire %s has negative %s stock (%d)" % [eid, res, e.stock[res]])
		if e.noise < 0 or e.noise > 10000:
			problems.append("empire %s noise %d outside 0..10000" % [eid, e.noise])
		for sid: String in DictIO.sorted_keys(e.known_systems):
			if not state.systems.has(sid):
				problems.append("empire %s knows missing system %s" % [eid, sid])
		if e.capital_id != "":
			if not state.colonies.has(e.capital_id):
				problems.append("empire %s has missing capital %s" % [eid, e.capital_id])
			elif state.colonies[e.capital_id].owner_id != eid and state.colonies[e.capital_id].autonomous_from != eid:
				problems.append("empire %s does not own its capital %s" % [eid, e.capital_id])
		for b: String in DictIO.sorted_keys(e.research):
			var rb: ResearchBranch = e.research[b]
			if not Empire.BRANCHES.has(b) or rb.branch != b:
				problems.append("empire %s has research branch %s holding %s" % [eid, b, rb.branch])
			if rb.progress < 0:
				problems.append("empire %s has negative %s progress" % [eid, b])
			if rb.card != "" and not rb.hand.has(rb.card):
				problems.append("empire %s researches %s, which is not in its %s hand" % [eid, rb.card, b])
			if rb.hand.size() > 3:
				problems.append("empire %s holds %d %s cards" % [eid, rb.hand.size(), b])
		for o: String in DictIO.sorted_keys(e.ordinances):
			if e.ordinances[o] == 0 or e.ordinances[o] < -1:
				problems.append("empire %s ordinance %s has %d turns left" % [eid, o, e.ordinances[o]])
		for pid: String in e.surveyed_planets:
			if not state.planets.has(pid):
				problems.append("empire %s surveyed missing planet %s" % [eid, pid])
		if e.decode_progress < 0:
			problems.append("empire %s has negative decode progress" % eid)

	for sid: String in DictIO.sorted_keys(state.systems):
		var s: StarSystem = state.systems[sid]
		if s.id != sid:
			problems.append("system key %s holds id %s" % [sid, s.id])
		for pid: String in s.planet_ids:
			if not state.planets.has(pid):
				problems.append("system %s lists missing planet %s" % [sid, pid])
		_check_owner(state, "system " + sid, s.owner_id, problems)

	for lid: String in DictIO.sorted_keys(state.lanes):
		var l: Lane = state.lanes[lid]
		if not state.systems.has(l.a) or not state.systems.has(l.b):
			problems.append("lane %s has a missing endpoint" % lid)
		if l.length_cly <= 0:
			problems.append("lane %s has non-positive length" % lid)

	for pid: String in DictIO.sorted_keys(state.planets):
		var p: Planet = state.planets[pid]
		if not state.systems.has(p.system_id):
			problems.append("planet %s is in missing system %s" % [pid, p.system_id])
		if p.colony_id != "" and not state.colonies.has(p.colony_id):
			problems.append("planet %s points at missing colony %s" % [pid, p.colony_id])

	for cid: String in DictIO.sorted_keys(state.colonies):
		var c: Colony = state.colonies[cid]
		if not state.planets.has(c.planet_id):
			problems.append("colony %s is on missing planet %s" % [cid, c.planet_id])
		elif state.planets[c.planet_id].colony_id != cid:
			problems.append("colony %s and planet %s disagree" % [cid, c.planet_id])
		_check_owner(state, "colony " + cid, c.owner_id, problems)
		if c.pops < 0:
			problems.append("colony %s has negative pops" % cid)
		if c.stability < 0 or c.stability > 100:
			problems.append("colony %s stability %d outside 0..100" % [cid, c.stability])
		if c.pops > 0 and c.is_outpost():
			problems.append("outpost %s has pops" % cid)
		if not Colony.GOVERNOR_FOCUSES.has(c.governor_focus):
			problems.append("colony %s has governor focus %s" % [cid, c.governor_focus])
		if c.governor_funds < 0:
			problems.append("colony %s has negative governor funds" % cid)
		var seen: Dictionary[int, bool] = {}
		for pd: Colony.PlacedDistrict in c.districts:
			if pd.slot < 0 or seen.has(pd.slot):
				problems.append("colony %s has a district on slot %d, which is taken or invalid" % [cid, pd.slot])
			seen[pd.slot] = true
			if pd.tier < 1 or pd.tier > 3:
				problems.append("colony %s district on slot %d has tier %d" % [cid, pd.slot, pd.tier])
		for pb: Colony.PlacedBuilding in c.buildings:
			if pb.slot == Colony.LANDMARK_SLOT:
				continue
			if pb.slot < 0 or seen.has(pb.slot):
				problems.append("colony %s has a building on slot %d, which is taken or invalid" % [cid, pb.slot])
			seen[pb.slot] = true
		for item: BuildItem in c.queue:
			if item.turns_left < 0 or item.turns_left > item.total_turns:
				problems.append("colony %s build %s has %d of %d turns left" % [cid, item.id, item.turns_left, item.total_turns])
			for r: String in DictIO.sorted_keys(item.paid):
				if item.paid[r] < 0:
					problems.append("colony %s build %s paid a negative %s" % [cid, item.id, r])
			if item.kind == BuildItem.KIND_DISTRICT or item.kind == BuildItem.KIND_BUILDING:
				if seen.has(item.slot):
					problems.append("colony %s queues %s on slot %d, which is taken" % [cid, item.def_id, item.slot])
				seen[item.slot] = true
			elif item.kind == BuildItem.KIND_UPGRADE and c.district_at(item.slot) == null:
				problems.append("colony %s upgrades an empty slot %d" % [cid, item.slot])

	for fid: String in DictIO.sorted_keys(state.fleets):
		var f: Fleet = state.fleets[fid]
		if not state.systems.has(f.system_id):
			problems.append("fleet %s is in missing system %s" % [fid, f.system_id])
		_check_owner(state, "fleet " + fid, f.owner_id, problems)
		for shid: String in f.ship_ids:
			if not state.ships.has(shid):
				problems.append("fleet %s lists missing ship %s" % [fid, shid])
			elif state.ships[shid].fleet_id != fid:
				problems.append("ship %s and fleet %s disagree" % [shid, fid])
		for step: String in f.path:
			if not state.systems.has(step):
				problems.append("fleet %s routes through missing system %s" % [fid, step])

	for shid: String in DictIO.sorted_keys(state.ships):
		var sh: Ship = state.ships[shid]
		if sh.design_id != "" and not state.designs.has(sh.design_id):
			problems.append("ship %s has missing design %s" % [shid, sh.design_id])
		if sh.design_id == "" and sh.hull == "":
			problems.append("ship %s has neither a design nor a hull" % shid)
		if sh.task != "" and sh.task_turns < 0:
			problems.append("ship %s has %d task turns" % [shid, sh.task_turns])
		if sh.fleet_id != "" and not state.fleets.has(sh.fleet_id):
			problems.append("ship %s is in missing fleet %s" % [shid, sh.fleet_id])
		_check_owner(state, "ship " + shid, sh.owner_id, problems)
		if sh.structure < 0:
			problems.append("ship %s has negative structure" % shid)

	for did: String in DictIO.sorted_keys(state.designs):
		_check_owner(state, "design " + did, state.designs[did].owner_id, problems)

	for mid: String in DictIO.sorted_keys(state.modifiers):
		var m: Modifier = state.modifiers[mid]
		if not state.empires.has(m.empire_id):
			problems.append("modifier %s belongs to missing empire %s" % [mid, m.empire_id])
		if m.colony_id != "" and not state.colonies.has(m.colony_id):
			problems.append("modifier %s is on missing colony %s" % [mid, m.colony_id])
		if m.turns_left == 0 or m.turns_left < -1:
			problems.append("modifier %s has %d turns left" % [mid, m.turns_left])
	for list: Array in [state.events_pending, state.events_scheduled]:
		for ev: EventInstance in list:
			if not state.empires.has(ev.empire_id):
				problems.append("event %s belongs to missing empire %s" % [ev.id, ev.empire_id])
			if ev.colony_id != "" and not state.colonies.has(ev.colony_id):
				problems.append("event %s is about missing colony %s" % [ev.id, ev.colony_id])
	for se: ScheduledEffect in state.scheduled_effects:
		if se.elapsed < 0 or se.elapsed > se.over_turns:
			problems.append("scheduled effect %s has elapsed %d of %d" % [se.id, se.elapsed, se.over_turns])
	if not [GameState.OUTCOME_NONE, GameState.OUTCOME_WON, GameState.OUTCOME_LOST].has(state.outcome):
		problems.append("outcome is %s" % state.outcome)
	return problems


static func _check_owner(state: GameState, what: String, owner_id: String, problems: Array[String]) -> void:
	if owner_id != "" and not state.empires.has(owner_id):
		problems.append("%s has missing owner %s" % [what, owner_id])
