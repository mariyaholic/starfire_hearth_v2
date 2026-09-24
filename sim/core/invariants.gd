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
		var seen: Dictionary[int, bool] = {}
		for pd: Colony.PlacedDistrict in c.districts:
			if seen.has(pd.slot):
				problems.append("colony %s has two things on slot %d" % [cid, pd.slot])
			seen[pd.slot] = true
		for pb: Colony.PlacedBuilding in c.buildings:
			if seen.has(pb.slot):
				problems.append("colony %s has two things on slot %d" % [cid, pb.slot])
			seen[pb.slot] = true

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
		if not state.designs.has(sh.design_id):
			problems.append("ship %s has missing design %s" % [shid, sh.design_id])
		if sh.fleet_id != "" and not state.fleets.has(sh.fleet_id):
			problems.append("ship %s is in missing fleet %s" % [shid, sh.fleet_id])
		_check_owner(state, "ship " + shid, sh.owner_id, problems)
		if sh.structure < 0:
			problems.append("ship %s has negative structure" % shid)

	for did: String in DictIO.sorted_keys(state.designs):
		_check_owner(state, "design " + did, state.designs[did].owner_id, problems)
	return problems


static func _check_owner(state: GameState, what: String, owner_id: String, problems: Array[String]) -> void:
	if owner_id != "" and not state.empires.has(owner_id):
		problems.append("%s has missing owner %s" % [what, owner_id])
