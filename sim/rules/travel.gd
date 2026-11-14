class_name Travel
extends RefCounted
## Deterministic slowboat travel. Beacon lanes remain closed until their Noise rules exist.


static func fleet_speed(state: GameState, fleet: Fleet) -> int:
	if fleet.ship_ids.is_empty() or not state.empires.has(fleet.owner_id):
		return 0
	var speed: int = 0
	var seen: Dictionary[String, bool] = {}
	for ship_id: String in fleet.ship_ids:
		if seen.has(ship_id) or not state.ships.has(ship_id):
			return 0
		seen[ship_id] = true
		var ship: Ship = state.ships[ship_id]
		if ship.id != ship_id or ship.owner_id != fleet.owner_id or ship.fleet_id != fleet.id or ship.is_busy() or not ship.design_id.is_empty():
			return 0
		var hull: Dictionary = Content.db().record("hulls", ship.hull)
		if DictIO.str_of(hull, "class") != "civilian":
			return 0
		var ship_speed: int = DictIO.int_of(hull, "speed_cp")
		if ship_speed <= 0:
			return 0
		speed = ship_speed if speed == 0 else mini(speed, ship_speed)
	# Reject an inconsistent reverse reference as well as invalid listed members.
	for ship_id: String in DictIO.sorted_keys(state.ships):
		if state.ships[ship_id].fleet_id == fleet.id and not seen.has(ship_id):
			return 0
	return speed


static func leg_turns(lane: Lane, speed: int) -> int:
	if lane == null or lane.length_cly <= 0 or speed <= 0:
		return 0
	return Fx.div_ceil(lane.length_cly * 2, speed)


static func _accessible(state: GameState, owner: String, system_id: String) -> bool:
	if not state.systems.has(system_id) or state.flags.get("fog_locked:" + system_id, 0) != 0:
		return false
	var system: StarSystem = state.systems[system_id]
	return system.owner_id.is_empty() or system.owner_id == owner


## Returns the shortest legal lane between two systems, with stable id tie-breaking.
static func lane_between(state: GameState, owner: String, a: String, b: String) -> Lane:
	if a == b or not state.systems.has(a) or not _accessible(state, owner, b):
		return null
	var best: Lane = null
	for id: String in DictIO.sorted_keys(state.lanes):
		var lane: Lane = state.lanes[id]
		if lane.kind != Lane.KIND_DEEP or lane.length_cly <= 0:
			continue
		if not ((lane.a == a and lane.b == b) or (lane.a == b and lane.b == a)):
			continue
		if best == null or lane.length_cly < best.length_cly:
			best = lane
	return best


## Dijkstra in turns; equal-cost routes use the lexicographically smallest system sequence.
## Unknown systems may be the destination, but cannot be used as intermediate waypoints.
static func route(state: GameState, fleet_id: String, destination: String) -> Array[String]:
	var none: Array[String] = []
	if not state.fleets.has(fleet_id):
		return none
	var fleet: Fleet = state.fleets[fleet_id]
	var speed: int = fleet_speed(state, fleet)
	if speed <= 0 or not state.systems.has(fleet.system_id) or not _accessible(state, fleet.owner_id, destination) or destination == fleet.system_id:
		return none
	var costs: Dictionary[String, int] = {fleet.system_id: 0}
	var paths: Dictionary = {fleet.system_id: []}
	var visited: Dictionary[String, bool] = {}
	while true:
		var current: String = ""
		for candidate: String in DictIO.sorted_keys(costs):
			if visited.has(candidate):
				continue
			if current.is_empty() or costs[candidate] < costs[current] or (costs[candidate] == costs[current] and _path_less(paths[candidate], paths[current])):
				current = candidate
		if current.is_empty():
			return none
		if current == destination:
			var result: Array[String] = []
			result.assign(paths[current])
			return result
		visited[current] = true
		for next: String in DictIO.sorted_keys(state.systems):
			if next != destination and not state.empires[fleet.owner_id].known_systems.has(next):
				continue
			if visited.has(next):
				continue
			var lane: Lane = lane_between(state, fleet.owner_id, current, next)
			if lane == null:
				continue
			var cost: int = costs[current] + leg_turns(lane, speed)
			var path: Array = paths[current].duplicate()
			path.append(next)
			if not costs.has(next) or cost < costs[next] or (cost == costs[next] and _path_less(path, paths[next])):
				costs[next] = cost
				paths[next] = path
	return none


static func _path_less(a: Array, b: Array) -> bool:
	for i: int in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return str(a[i]) < str(b[i])
	return a.size() < b.size()


static func can_move(state: GameState, empire_id: String, fleet_id: String, destination: String) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not state.fleets.has(fleet_id):
		return Result.fail("error.fleet.not_found")
	var fleet: Fleet = state.fleets[fleet_id]
	if fleet.owner_id != empire_id:
		return Result.fail("error.fleet.not_owned")
	if not fleet.path.is_empty() or fleet.move_progress != 0:
		return Result.fail("error.fleet.in_transit")
	if fleet.ship_ids.is_empty():
		return Result.fail("error.fleet.empty")
	if fleet_speed(state, fleet) <= 0:
		return Result.fail("error.fleet.unavailable")
	if destination == fleet.system_id:
		return Result.fail("error.fleet.already_here")
	if route(state, fleet_id, destination).is_empty():
		return Result.fail("error.fleet.no_route")
	return Result.success()


## An order to finish the current leg and discard only later destinations.
static func can_stop(state: GameState, empire_id: String, fleet_id: String) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not state.fleets.has(fleet_id):
		return Result.fail("error.fleet.not_found")
	var fleet: Fleet = state.fleets[fleet_id]
	if fleet.owner_id != empire_id:
		return Result.fail("error.fleet.not_owned")
	if fleet.id != fleet_id or (fleet.path.is_empty() and fleet.move_progress != 0):
		return Result.fail("error.fleet.invalid_route")
	if fleet.path.is_empty():
		return Result.fail("error.fleet.not_moving")
	if not route_valid(state, fleet):
		return Result.fail("error.fleet.invalid_route")
	if fleet.path.size() == 1 and not AutoExplore.enabled(state, fleet_id):
		return Result.fail("error.fleet.already_stopping")
	return Result.success()


## Called only after can_stop succeeds. Never resets the current lane or its progress.
static func stop_next(state: GameState, fleet_id: String) -> void:
	var fleet: Fleet = state.fleets[fleet_id]
	var next: String = fleet.path[0]
	fleet.path.clear()
	fleet.path.append(next)
	AutoExplore.set_enabled(state, fleet.owner_id, fleet_id, false)


## A preview of a new route, in turns. The generic lane label does not reveal unknown names.
static func eta(state: GameState, fleet_id: String, destination: String) -> Breakdown:
	var result: Breakdown = Breakdown.make("breakdown.travel_turns", Breakdown.UNIT_TURNS)
	result.link_to("mechanic:travel")
	if not state.fleets.has(fleet_id):
		return result.finish()
	var fleet: Fleet = state.fleets[fleet_id]
	var current: String = fleet.system_id
	var speed: int = fleet_speed(state, fleet)
	for step: String in route(state, fleet_id, destination):
		result.add("source.travel_lane", leg_turns(lane_between(state, fleet.owner_id, current, step), speed))
		current = step
	return result.finish()


## Remaining turns along the saved route; the first lane accounts for turns already spent.
static func remaining_eta(state: GameState, fleet_id: String) -> Breakdown:
	var result: Breakdown = Breakdown.make("breakdown.travel_turns", Breakdown.UNIT_TURNS)
	result.link_to("mechanic:travel")
	if not state.fleets.has(fleet_id):
		return result.finish()
	var fleet: Fleet = state.fleets[fleet_id]
	if not route_valid(state, fleet):
		return result.finish()
	var speed: int = fleet_speed(state, fleet)
	var current: String = fleet.system_id
	var first: bool = true
	for step: String in fleet.path:
		var turns: int = leg_turns(lane_between(state, fleet.owner_id, current, step), speed)
		if first:
			turns -= fleet.move_progress
			first = false
		result.add("source.travel_lane", turns)
		current = step
	return result.finish()


## Validate the entire stored route before progressing, including routes loaded from saves.
static func route_valid(state: GameState, fleet: Fleet) -> bool:
	if fleet.path.is_empty():
		return fleet.move_progress == 0
	var speed: int = fleet_speed(state, fleet)
	if speed <= 0 or fleet.move_progress < 0:
		return false
	var current: String = fleet.system_id
	var seen: Dictionary[String, bool] = {current: true}
	for step: String in fleet.path:
		var lane: Lane = lane_between(state, fleet.owner_id, current, step)
		if lane == null or seen.has(step):
			return false
		if current == fleet.system_id and fleet.move_progress >= leg_turns(lane, speed):
			return false
		seen[step] = true
		current = step
	return true


static func advance(state: GameState, result: TurnResult) -> void:
	for fleet_id: String in DictIO.sorted_keys(state.fleets):
		var fleet: Fleet = state.fleets[fleet_id]
		if fleet.path.is_empty() and fleet.move_progress == 0:
			continue
		if not route_valid(state, fleet):
			# Freeze rather than teleport or permit tasks while the fleet is in an invalid route.
			if state.empires.has(fleet.owner_id) and state.empires[fleet.owner_id].is_player:
				result.report_items.append(ReportItem.make(ReportItem.CATEGORY_FLEETS, 60, "report.fleet_route_blocked")
					.with_severity(ReportItem.SEVERITY_WARNING).focus("fleet", fleet_id))
			continue
		var next: String = fleet.path[0]
		var turns: int = leg_turns(lane_between(state, fleet.owner_id, fleet.system_id, next), fleet_speed(state, fleet))
		fleet.move_progress += 1
		if fleet.move_progress < turns:
			continue
		fleet.system_id = next
		fleet.path.remove_at(0)
		fleet.move_progress = 0
		state.empires[fleet.owner_id].known_systems[next] = Empire.FOG_SURVEYED
		if state.empires[fleet.owner_id].is_player:
			var explanation: Breakdown = Breakdown.make("breakdown.travel_turns", Breakdown.UNIT_TURNS)
			explanation.link_to("mechanic:travel")
			explanation.base("source.travel_lane", turns)
			result.report_items.append(ReportItem.make(ReportItem.CATEGORY_FLEETS, 40, "report.fleet_arrived", {"system_key": state.systems[next].name_key})
				.with_severity(ReportItem.SEVERITY_GOOD).with_breakdown(explanation.finish()).focus("system", next))
