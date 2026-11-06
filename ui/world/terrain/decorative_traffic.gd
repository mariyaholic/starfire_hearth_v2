class_name DecorativeTraffic
extends RefCounted
## Presentation-only delivery carts. Trips join real entrances on the drawn
## street graph; disjoint terminal pairs share single-lane corridors by turns.
## No simulation state, RNG stream, persistent recipe or road geometry changes.
const CAP: int = 4
const GAP: float = 1.0
const SPEED: float = 0.9
const TURN_SECONDS: float = 0.8
const STOP_SECONDS: float = 1.0
## CityAccessNetwork drops edges shorter than sqrt(0.00001).
const ENTRANCE_TOLERANCE: float = 0.0032
var vehicles: Array[Dictionary] = []
var conflicts: Array[Array] = []
var _next: int = 0
var _wait_sequence: int = 0
var _network_identity: Dictionary = {}

func configure(network: Dictionary) -> void:
	var identity: Dictionary = {"routes":network.get("routes", []), "connected":network.get("connected", []), "access_paths":network.get("access_paths", [])}
	if identity == _network_identity: return
	_network_identity = identity.duplicate(true)
	vehicles.clear(); conflicts.clear(); _next = 0; _wait_sequence = 0
	var graph: AStar2D = AStar2D.new()
	var nodes: Dictionary = {}
	var entrances: Array[Dictionary] = []
	for i: int in network.get("connected", []).size():
		var path: Array = network["access_paths"][i]
		if not path.is_empty(): entrances.append({"id":network["connected"][i], "point":path[0]})
	# Smoothing/resampling can remove an entrance that lies within a rendered
	# segment. Insert it into that segment instead of requiring a matching vertex.
	var routes: Array = network.get("routes", [])
	var splits: Dictionary = {}
	for entrance: Dictionary in entrances:
		var best: float = ENTRANCE_TOLERANCE
		var best_key: String = ""
		var best_point: Vector2 = Vector2.ZERO
		for r: int in routes.size():
			var route: Array = routes[r]
			for i: int in route.size() - 1:
				var a: Vector2 = route[i]; var b: Vector2 = route[i + 1]
				var point: Vector2 = Geometry2D.get_closest_point_to_segment(entrance["point"], a, b)
				var distance: float = point.distance_to(entrance["point"])
				if distance > best: continue
				best = distance; best_key = str(r) + ":" + str(i); best_point = point
				if point.distance_to(a) < 0.00001: best_point = a
				elif point.distance_to(b) < 0.00001: best_point = b
		if best_key.is_empty(): continue
		entrance["point"] = best_point
		if not splits.has(best_key): splits[best_key] = []
		splits[best_key].append(best_point)
	for r: int in routes.size():
		var route: Array = routes[r]
		for i: int in route.size() - 1:
			var a: Vector2 = route[i]; var b: Vector2 = route[i + 1]
			var points: Array = [a, b]
			points.append_array(splits.get(str(r) + ":" + str(i), []))
			points.sort_custom(func(x: Vector2, y: Vector2) -> bool: return a.distance_squared_to(x) < a.distance_squared_to(y))
			for point: Vector2 in points:
				if not nodes.has(point):
					var id: int = nodes.size(); nodes[point] = id; graph.add_point(id, point)
			for j: int in points.size() - 1:
				if points[j] != points[j + 1]: graph.connect_points(nodes[points[j]], nodes[points[j + 1]])
	entrances = entrances.filter(func(entrance: Dictionary) -> bool: return nodes.has(entrance["point"]))
	# A single developed site has no destination, and therefore no traffic.
	var candidates: Array[Dictionary] = []
	for i: int in entrances.size():
		for j: int in range(i + 1, entrances.size()):
			var route: Array[Vector2] = []
			route.assign(graph.get_point_path(nodes[entrances[i]["point"]], nodes[entrances[j]["point"]]))
			route = _corners(route)
			if route.size() < 2 or route[0].distance_to(route[-1]) < GAP * 2: continue
			var length: float = 0.0
			for k: int in route.size() - 1: length += route[k].distance_to(route[k + 1])
			candidates.append({"origin":entrances[i]["id"], "destination":entrances[j]["id"], "route":route, "length":length})
	# Local deliveries first. A stable order gives the same fleet after a rebuild.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["length"] != b["length"]: return a["length"] < b["length"]
		return str(a["origin"]) + "/" + str(a["destination"]) < str(b["origin"]) + "/" + str(b["destination"]))
	for candidate: Dictionary in candidates:
		if vehicles.size() >= CAP: break
		var route: Array[Vector2] = candidate["route"]
		var safe: bool = true
		for other: Dictionary in vehicles:
			var path: Array[Vector2] = other["route"]
			# Waiting/turning carts occupy an entrance. No other trip may cross
			# either terminal, even while that trip owns the shared road.
			if _distance(route[0], path) < GAP or _distance(route[-1], path) < GAP or _distance(path[0], route) < GAP or _distance(path[-1], route) < GAP:
				safe = false; break
		if not safe: continue
		var heading: float = _heading(route[1] - route[0])
		candidate.merge({"at":route[0], "heading":heading, "index":0, "direction":1,
			"state":"waiting", "elapsed":0.0, "duration":0.0, "active":false,
			"trips":0, "start_heading":heading, "target_heading":heading,
			"wait_order":_wait_sequence})
		_wait_sequence += 1
		vehicles.append(candidate)
	for vehicle: Dictionary in vehicles:
		var row: Array = []
		for other: Dictionary in vehicles: row.append(_overlap(vehicle["route"], other["route"]))
		conflicts.append(row)

func advance(delta: float) -> void:
	# Bounded substeps keep dispatch and stops independent of the display rate.
	var remaining: float = maxf(0.0, delta)
	while remaining > 0.000001:
		var step: float = minf(remaining, 0.05)
		_dispatch()
		for vehicle: Dictionary in vehicles: _advance_vehicle(vehicle, step)
		remaining -= step

func _dispatch() -> void:
	if vehicles.is_empty(): return
	for offset: int in vehicles.size():
		var index: int = (_next + offset) % vehicles.size()
		var vehicle: Dictionary = vehicles[index]
		if vehicle["state"] != "waiting": continue
		var available: bool = true
		for j: int in vehicles.size():
			if j == index or not conflicts[index][j]: continue
			# An older blocked waiter must eventually see all its conflicts drain.
			# Unrelated trips may still run concurrently.
			if vehicles[j]["active"] or (vehicles[j]["state"] == "waiting" and vehicles[j]["wait_order"] < vehicle["wait_order"]):
				available = false; break
		if not available: continue
		vehicle["active"] = true
		_begin_drive(vehicle)
		_next = (index + 1) % vehicles.size()
		# Start at most one trip per substep, preserving the round-robin order.
		break

func _begin_drive(vehicle: Dictionary) -> void:
	var route: Array[Vector2] = vehicle["route"]
	var index: int = vehicle["index"]
	var next: int = index + int(vehicle["direction"])
	vehicle["state"] = "drive"; vehicle["elapsed"] = 0.0
	vehicle["duration"] = route[index].distance_to(route[next]) / SPEED

func _begin_turn(vehicle: Dictionary, heading: float) -> void:
	vehicle["state"] = "turn"; vehicle["elapsed"] = 0.0
	vehicle["duration"] = maxf(0.15, absf(angle_difference(vehicle["heading"], heading)) / PI * TURN_SECONDS)
	vehicle["start_heading"] = vehicle["heading"]; vehicle["target_heading"] = heading

func _advance_vehicle(vehicle: Dictionary, delta: float) -> void:
	if vehicle["state"] == "waiting": return
	var route: Array[Vector2] = vehicle["route"]
	vehicle["elapsed"] += delta
	var t: float = clampf(vehicle["elapsed"] / maxf(0.00001, vehicle["duration"]), 0.0, 1.0)
	var ease: float = t * t * (3.0 - 2.0 * t)
	match vehicle["state"]:
		"drive":
			var index: int = vehicle["index"]
			var next: int = index + int(vehicle["direction"])
			vehicle["at"] = route[index].lerp(route[next], ease)
			if t < 1.0: return
			vehicle["index"] = next
			if next == 0 or next == route.size() - 1:
				vehicle["state"] = "stop"; vehicle["elapsed"] = 0.0; vehicle["duration"] = STOP_SECONDS
				vehicle["trips"] += 1
			else: _begin_turn(vehicle, _heading(route[next + int(vehicle["direction"])] - route[next]))
		"stop":
			if t < 1.0: return
			vehicle["direction"] = -int(vehicle["direction"])
			var index: int = vehicle["index"]
			_begin_turn(vehicle, _heading(route[index + int(vehicle["direction"])] - route[index]))
		"turn":
			vehicle["heading"] = wrapf(lerp_angle(vehicle["start_heading"], vehicle["target_heading"], ease), -PI, PI)
			if t < 1.0: return
			if vehicle["index"] == 0 and vehicle["direction"] == 1:
				vehicle["state"] = "waiting"; vehicle["active"] = false
				vehicle["wait_order"] = _wait_sequence; _wait_sequence += 1
			else: _begin_drive(vehicle)

## +Z is the cart's nose. Front/rear and left/right wheel samples keep its
## entire chassis on the road on a grade instead of moving a level box up/down.
static func pose(vehicle: Dictionary, height: Callable) -> Transform3D:
	var at: Vector2 = vehicle["at"]
	var heading: float = vehicle["heading"]
	var forward: Vector2 = Vector2(sin(heading), cos(heading))
	var right: Vector2 = Vector2(forward.y, -forward.x)
	var front: float = _height(at + forward * 0.16, height)
	var rear: float = _height(at - forward * 0.16, height)
	var rh: float = _height(at + right * 0.12, height)
	var lh: float = _height(at - right * 0.12, height)
	var z: Vector3 = Vector3(forward.x, (front - rear) / 0.32, forward.y).normalized()
	var x: Vector3 = Vector3(right.x, (rh - lh) / 0.24, right.y).normalized()
	var y: Vector3 = z.cross(x).normalized()
	x = y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), Vector3(at.x, (front + rear + rh + lh) * 0.25 + 0.105, at.y))

static func _height(at: Vector2, height: Callable) -> float:
	return float(height.call(at.x, at.y)) if height.is_valid() else 0.0

static func _heading(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)

static func _corners(path: Array[Vector2]) -> Array[Vector2]:
	var output: Array[Vector2] = []
	for at: Vector2 in path:
		if not output.is_empty() and output[-1].distance_to(at) < 0.0001: continue
		while output.size() >= 2:
			var a: Vector2 = (output[-1] - output[-2]).normalized()
			var b: Vector2 = (at - output[-1]).normalized()
			if a.dot(b) < 0.99999: break
			output.pop_back()
		output.append(at)
	return output

static func _distance(at: Vector2, path: Array[Vector2]) -> float:
	var distance: float = INF
	for i: int in path.size() - 1:
		distance = minf(distance, CityTerrainGenerator._segment_distance(at, path[i], path[i + 1]))
	return distance

static func _overlap(a: Array[Vector2], b: Array[Vector2]) -> bool:
	for point: Vector2 in a:
		if _distance(point, b) < GAP: return true
	for point: Vector2 in b:
		if _distance(point, a) < GAP: return true
	for i: int in a.size() - 1:
		for j: int in b.size() - 1:
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1]) != null: return true
	return false
