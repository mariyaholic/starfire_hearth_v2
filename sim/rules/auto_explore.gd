class_name AutoExplore
extends RefCounted
## Optional survey-probe automation. Intent lives in existing empire flags and creates no new
## default state. Assignments happen once per idle fleet after the command phase.

const PREFIX: String = "auto_explore:"


static func enabled(state: GameState, fleet_id: String) -> bool:
	if not state.fleets.has(fleet_id):
		return false
	var fleet: Fleet = state.fleets[fleet_id]
	return state.empires.has(fleet.owner_id) and state.empires[fleet.owner_id].flags.get(PREFIX + fleet_id, 0) == 1


static func can_set(state: GameState, empire_id: String, fleet_id: String, enable: bool) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not state.fleets.has(fleet_id):
		return Result.fail("error.fleet.not_found")
	var fleet: Fleet = state.fleets[fleet_id]
	if fleet.owner_id != empire_id:
		return Result.fail("error.fleet.not_owned")
	if enable and not _eligible(state, fleet):
		return Result.fail("error.auto_explore.unavailable")
	return Result.success()


static func set_enabled(state: GameState, empire_id: String, fleet_id: String, enable: bool) -> void:
	if enable:
		state.empires[empire_id].flags[PREFIX + fleet_id] = 1
	else:
		state.empires[empire_id].flags.erase(PREFIX + fleet_id)


## Read-only state for the interface; a pending decision delays only new assignments.
static func status(state: GameState, fleet_id: String) -> String:
	if not enabled(state, fleet_id):
		return "disabled"
	var fleet: Fleet = state.fleets[fleet_id]
	if not fleet.path.is_empty() or fleet.move_progress != 0:
		return "travelling"
	if fleet.ship_ids.size() == 1 and state.ships.has(fleet.ship_ids[0]) and state.ships[fleet.ship_ids[0]].is_busy():
		return "surveying"
	return "waiting"


static func _eligible(state: GameState, fleet: Fleet) -> bool:
	if not state.empires.has(fleet.owner_id) or not state.systems.has(fleet.system_id) or fleet.ship_ids.size() != 1 or state.fleets.get(fleet.id) != fleet:
		return false
	var ship_id: String = fleet.ship_ids[0]
	if not state.ships.has(ship_id):
		return false
	var ship: Ship = state.ships[ship_id]
	if ship.id != ship_id or ship.owner_id != fleet.owner_id or ship.fleet_id != fleet.id or ship.hull != "survey_probe" or not ship.design_id.is_empty():
		return false
	for other_id: String in DictIO.sorted_keys(state.ships):
		if other_id != ship_id and state.ships[other_id].fleet_id == fleet.id:
			return false
	return true


## Clear stale or malformed flags even when a decision is pending. Never transfer an intent to a
## new owner if a fleet disappeared or changed hands.
static func _clean_flags(state: GameState) -> void:
	for empire_id: String in DictIO.sorted_keys(state.empires):
		var empire: Empire = state.empires[empire_id]
		for key: String in DictIO.sorted_keys(empire.flags):
			if not key.begins_with(PREFIX):
				continue
			var fleet_id: String = key.trim_prefix(PREFIX)
			if empire.flags[key] != 1 or not state.fleets.has(fleet_id):
				empire.flags.erase(key)
				continue
			var fleet: Fleet = state.fleets[fleet_id]
			if fleet.owner_id != empire_id or not _eligible(state, fleet):
				empire.flags.erase(key)


## Only inspect planet lists in systems already known to the empire. Local systems are occupied by
## the probe and therefore visible. Return unsurveyed, unreserved targets in stable id order.
static func _unreserved_planets(state: GameState, empire: Empire, system_id: String, reserved_planets: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not state.systems.has(system_id):
		return out
	var ids: Array[String] = state.systems[system_id].planet_ids.duplicate()
	ids.sort()
	for planet_id: String in ids:
		if state.planets.has(planet_id) and state.planets[planet_id].system_id == system_id and not empire.surveyed_planets.has(planet_id) and not reserved_planets.has(planet_id):
			out.append(planet_id)
	return out


static func advance(state: GameState, result: TurnResult) -> void:
	_clean_flags(state)
	# Existing orders reserve destinations/targets before assigning any new ones. Reservations
	# are per empire so another empire's undisclosed activities never affect these decisions.
	var reserved_systems: Dictionary = {}
	var reserved_planets: Dictionary = {}
	for fleet_id: String in DictIO.sorted_keys(state.fleets):
		var fleet: Fleet = state.fleets[fleet_id]
		if not fleet.path.is_empty() and _eligible(state, fleet) and Travel.route_valid(state, fleet):
			reserved_systems[fleet.owner_id + ":" + fleet.path.back()] = true
	for ship_id: String in DictIO.sorted_keys(state.ships):
		var ship: Ship = state.ships[ship_id]
		if ship.task == Ship.TASK_SURVEY:
			reserved_planets[ship.owner_id + ":" + ship.task_target] = true
	for fleet_id: String in DictIO.sorted_keys(state.fleets):
		var fleet: Fleet = state.fleets[fleet_id]
		if not enabled(state, fleet_id) or not _eligible(state, fleet):
			continue
		var empire: Empire = state.empires[fleet.owner_id]
		if empire.is_player and not Events.pending_for(state, empire.id).is_empty():
			continue
		var ship: Ship = state.ships[fleet.ship_ids[0]]
		if ship.is_busy() or not fleet.path.is_empty() or fleet.move_progress != 0:
			continue
		var local_reservations: Dictionary = {}
		for pid: String in state.systems[fleet.system_id].planet_ids:
			if reserved_planets.has(empire.id + ":" + pid):
				local_reservations[pid] = true
		for pid: String in _unreserved_planets(state, empire, fleet.system_id, local_reservations):
			if Ships.can_survey(state, empire.id, ship.id, pid).ok:
				Ships.start_survey(state, ship.id, pid)
				reserved_planets[empire.id + ":" + pid] = true
				break
		if ship.is_busy():
			continue
		var best: String = ""
		var best_turns: int = 0
		var waiting_for_reserved: bool = not local_reservations.is_empty()
		for system_id: String in DictIO.sorted_keys(state.systems):
			if system_id == fleet.system_id:
				continue
			var is_known: bool = empire.known_systems.has(system_id)
			if is_known and _unreserved_planets(state, empire, system_id, {}).is_empty():
				continue
			if not Travel.can_move(state, empire.id, fleet_id, system_id).ok:
				continue
			if reserved_systems.has(empire.id + ":" + system_id):
				waiting_for_reserved = true
				continue
			if is_known:
				var all_reserved: bool = true
				for pid: String in _unreserved_planets(state, empire, system_id, {}):
					if not reserved_planets.has(empire.id + ":" + pid):
						all_reserved = false
						break
				if all_reserved:
					waiting_for_reserved = true
					continue
			var turns: int = Travel.eta(state, fleet_id, system_id).total
			if best.is_empty() or turns < best_turns:
				best = system_id
				best_turns = turns
		if not best.is_empty():
			fleet.path = Travel.route(state, fleet_id, best)
			reserved_systems[empire.id + ":" + best] = true
		elif not waiting_for_reserved:
			set_enabled(state, empire.id, fleet_id, false)
			if empire.is_player:
				result.report_items.append(ReportItem.make(ReportItem.CATEGORY_FLEETS, 40, "report.auto_explore_complete")
					.with_severity(ReportItem.SEVERITY_GOOD).focus("system", fleet.system_id))
