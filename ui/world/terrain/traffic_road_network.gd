class_name TrafficRoadNetwork
extends RefCounted
## A transient graph cut from the road that is actually drawn. Legacy recipes
## remain untouched: unsafe sections are closed to carts, never replaced by a
## straight shortcut. Developed parcels allow their paved loading frontage;
## unbuilt parcels and elevated building footprints remain closed to traffic.
## Encloses every chassis vertex in 3D (furthest shell corner is 0.337).
## Using the full sphere also covers pitch, roll and turns on steep terrain.
const BODY_CLEARANCE: float = 0.35
const JOIN_EPSILON: float = 0.0001

static func derive(drawn: Array[Array], entries: Array[Dictionary], exclusions: Array[Dictionary], height: Callable = Callable(), wet: bool = false) -> Dictionary:
	var pieces: Array[PackedVector2Array] = []
	for route: Array in drawn:
		if route.size() > 1: pieces.append(PackedVector2Array(route))
	for exclusion: Dictionary in exclusions:
		var outside: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			outside.append_array(Geometry2D.clip_polyline_with_polygon(piece, exclusion["polygon"]))
		pieces = outside
	var segments: Array[Array] = []
	for piece: PackedVector2Array in pieces:
		for i: int in piece.size() - 1:
			var a: Vector2 = piece[i]; var b: Vector2 = piece[i + 1]
			if a.distance_to(b) < JOIN_EPSILON: continue
			if CityAccessNetwork.traversable(a, b, [], height, wet): segments.append([a, b])
	# Legacy paths share trunks and can cross without sharing a sampled vertex.
	# Split only at actual intersections; this never creates an undrawn edge.
	var cuts: Array[Array] = []
	for segment: Array in segments: cuts.append(segment.duplicate())
	for i: int in segments.size():
		for j: int in i:
			var a: Array = segments[i]; var b: Array = segments[j]
			var hit: Variant = Geometry2D.segment_intersects_segment(a[0], a[1], b[0], b[1])
			if hit != null:
				cuts[i].append(hit); cuts[j].append(hit)
			for point: Vector2 in a:
				if CityTerrainGenerator._segment_distance(point, b[0], b[1]) < JOIN_EPSILON: cuts[j].append(point)
			for point: Vector2 in b:
				if CityTerrainGenerator._segment_distance(point, a[0], a[1]) < JOIN_EPSILON: cuts[i].append(point)
	var result: Dictionary = {"routes":[], "connected":[], "access_paths":[]}
	var edges: Dictionary = {}
	var vertices: Dictionary = {}
	for i: int in cuts.size():
		var start: Vector2 = segments[i][0]
		cuts[i].sort_custom(func(a: Vector2, b: Vector2) -> bool: return start.distance_squared_to(a) < start.distance_squared_to(b))
		for j: int in cuts[i].size() - 1:
			var a: Vector2 = _vertex(cuts[i][j], vertices); var b: Vector2 = _vertex(cuts[i][j + 1], vertices)
			if a.distance_to(b) < JOIN_EPSILON: continue
			var key: String = CityAccessNetwork._edge_key(a, b)
			if edges.has(key): continue
			edges[key] = true; result["routes"].append([a, b])
	var terminals: Dictionary = {}
	for entry: Dictionary in entries:
		var point: Vector2 = entry["point"]
		var best: float = DecorativeTraffic.ENTRANCE_TOLERANCE
		var nearest: Variant = null
		for segment: Array in result["routes"]:
			var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])
			if point.distance_to(candidate) <= best:
				best = point.distance_to(candidate); nearest = candidate
		if nearest != null: _terminal(result, terminals, str(entry["id"]), nearest)
	for point: Vector2 in vertices.values():
		for exclusion: Dictionary in exclusions:
			if not exclusion.has("id"): continue
			var polygon: PackedVector2Array = exclusion["polygon"]
			for i: int in polygon.size():
				if CityTerrainGenerator._segment_distance(point, polygon[i], polygon[(i + 1) % polygon.size()]) < 0.001:
					_terminal(result, terminals, str(exclusion["id"]), point)
					break
	return result

static func _vertex(point: Vector2, vertices: Dictionary) -> Vector2:
	var key: Vector2i = Vector2i(roundi(point.x / JOIN_EPSILON), roundi(point.y / JOIN_EPSILON))
	if not vertices.has(key): vertices[key] = point
	return vertices[key]

static func _terminal(result: Dictionary, terminals: Dictionary, id: String, point: Vector2) -> void:
	var key: String = id + ":" + str(point)
	if terminals.has(key): return
	terminals[key] = true
	result["connected"].append(id); result["access_paths"].append([point])

static func rectangle(rect: Rect2) -> PackedVector2Array:
	var padded: Rect2 = rect.grow(BODY_CLEARANCE)
	return PackedVector2Array([padded.position, Vector2(padded.end.x, padded.position.y), padded.end, Vector2(padded.position.x, padded.end.y)])

static func parcel(at: Vector2, blocked: bool) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var count: int = 12 if blocked else 6
	# Expand the hex's apothem by the complete rotating chassis radius.
	var radius: float = 3.55 + BODY_CLEARANCE if blocked else 3.02 + BODY_CLEARANCE / cos(PI / 6.0)
	for i: int in count:
		var angle: float = float(i) * TAU / count + PI / 6.0
		polygon.append(at + Vector2(cos(angle), sin(angle)) * radius)
	return polygon
