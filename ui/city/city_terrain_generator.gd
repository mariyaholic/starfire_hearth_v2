class_name CityTerrainGenerator
extends RefCounted
## Regional appearance only: deterministic landscape, site grading and connected access.
## Workers produce arrays/images, never Nodes or GPU resources. All scales are art units.

const VERSION: int = 2
const EXTENT: float = 112.0
const KINDS: Array[String] = ["continental", "ocean", "arid", "ice", "barren", "toxic"]
const DISTRICTS: Array[String] = ["habitation", "agriculture", "energy", "mining", "industry", "research"]
const HEX_RADIUS: float = 3.2
var seed_value: int
var kind: String
var _land: FastNoiseLite
var _detail: FastNoiseLite
var _forest: FastNoiseLite
var slots: Array[Dictionary] = []


func _init(appearance_seed: int = 11, terrain_kind: String = "continental") -> void:
	seed_value = appearance_seed
	kind = terrain_kind
	assert(kind in KINDS)
	_land = _noise(seed_value, 0.025, 4)
	_detail = _noise(seed_value + 719, 0.14, 3)
	_forest = _noise(seed_value + 443, 0.06, 3)


func _noise(value: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = value
	n.frequency = frequency
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


func coast_z(x: float) -> float:
	return 23.0 + _land.get_noise_2d(x, 91.0) * 8.0 + sin(x * 0.10 + seed_value * 0.11) * 2.2


func river_x(z: float) -> float:
	return -27.0 + sin(z * 0.069 + seed_value * 0.13) * 4.0


func raw_height(x: float, z: float) -> float:
	var inland: float = coast_z(x) - z
	if inland < 0.0:
		return maxf(-5.0, inland * 0.38)
	var shore: float = 1.85 * (1.0 - exp(-inland * 0.30))
	var hill_weight: float = smoothstep(19.0, 47.0, Vector2(x, z).length())
	var hills: float = pow(1.0 - absf(_land.get_noise_2d(x, z)), 2.0) * 13.0 - 4.0
	var h: float = shore + hills * hill_weight * smoothstep(1.0, 7.0, inland)
	h += _detail.get_noise_2d(x, z) * lerpf(0.24, 0.8, hill_weight)
	var river: float = (1.0 - smoothstep(1.2, 3.0, absf(x - river_x(z)))) * smoothstep(0.0, 3.0, inland)
	return lerpf(h, -0.42, river)


func height_at(x: float, z: float) -> float:
	var h: float = raw_height(x, z)
	if absf(x) < 25.0 and absf(z) < 25.0:
		# Natural outcrops precede local grading, so their tails cannot lift a footing.
		for slot: Dictionary in slots:
			if not slot["blocked"]: continue
			var at: Vector3 = slot["at"]
			var distance: float = Vector2(x - at.x, z - at.z).length()
			h += exp(-distance * distance / 4.0) * 2.8
		for slot: Dictionary in slots:
			if slot["blocked"]: continue
			var at: Vector3 = slot["at"]
			var distance: float = Vector2(x - at.x, z - at.z).length()
			if distance < 3.0:
				h = lerpf(h, at.y, 1.0 - smoothstep(1.9, 3.0, distance))
				if slot["kind"] == "mining":
					h -= (1.0-smoothstep(0.75,1.5,distance))*0.64
	return h


func layout(districts: Array, blocked: Array, slot_count: int = 20) -> Dictionary:
	slots.clear()
	var coordinates: Array[Vector2i] = HexGrid.coords(slot_count)
	var actual: Dictionary = {}
	for district: Dictionary in districts:
		actual[int(district["slot"])] = str(district["district"])
	for i: int in coordinates.size():
		var qr: Vector2i = coordinates[i]
		var x: float = HEX_RADIUS * sqrt(3.0) * (qr.x + qr.y * 0.5)
		var z: float = HEX_RADIUS * 1.5 * qr.y
		var district_kind: String = actual.get(i, "")
		if blocked.has(i): district_kind = ""
		slots.append({"slot": i, "seed": seed_value+i*8191, "qr": qr, "at": Vector3(x, raw_height(x, z) + 0.04, z), "kind": district_kind, "blocked": blocked.has(i), "concept": false})
	var roads: Array[Vector2i] = _roads()
	var trees: Array[Vector4] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 7331
	# Fixed candidates remain in place when development clears a plot.
	for i: int in 650:
		var x: float = rng.randf_range(-62.0, 62.0)
		var z: float = rng.randf_range(-65.0, 31.0)
		var scale_value: float = rng.randf_range(0.7, 1.55)
		var h: float = height_at(x, z)
		if kind not in ["continental","ocean"] or h < 1.0 or h > 9.0 or _forest.get_noise_2d(x, z) < -0.11:
			continue
		var clear: bool = true
		for slot: Dictionary in slots:
			if (not slot["kind"].is_empty() or slot["blocked"]) and Vector2(x - slot["at"].x, z - slot["at"].z).length() < 3.5:
				clear = false
		for road: Vector2i in roads:
			var a: Vector3 = slots[road.x]["at"]
			var b: Vector3 = slots[road.y]["at"]
			if _segment_distance(Vector2(x, z), Vector2(a.x, a.z), Vector2(b.x, b.z)) < 1.1:
				clear = false
		if clear: trees.append(Vector4(x, h, z, scale_value))
	return {"version": VERSION, "seed": seed_value, "kind": kind, "slot_count": slot_count, "slots": slots.duplicate(true), "roads": roads, "trees": trees}


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var delta: Vector2 = b - a
	var t: float = clampf((p - a).dot(delta) / maxf(0.001, delta.length_squared()), 0.0, 1.0)
	return p.distance_to(a + delta * t)


func _roads() -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var frontier: Array[int] = [0]
	var previous: Dictionary = {0: -1}
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for next: int in slots.size():
			if slots[next]["blocked"] or previous.has(next): continue
			var a: Vector2i = slots[current]["qr"]
			var b: Vector2i = slots[next]["qr"]
			var delta: Vector2i = a - b
			if maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y))) != 1: continue
			previous[next] = current
			frontier.append(next)
	var used: Dictionary = {}
	for slot: Dictionary in slots:
		if slot["kind"].is_empty(): continue
		var at: int = slot["slot"]
		while previous.has(at) and int(previous[at]) >= 0:
			var next: int = previous[at]
			var edge: Vector2i = Vector2i(mini(at, next), maxi(at, next))
			if not used.has(edge):
				used[edge] = true
				edges.append(edge)
			at = next
	return edges


func bake(cancellation: SpaceSurfaceBaker.Cancellation, subdivisions: int = 224) -> Dictionary:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for z_index: int in subdivisions + 1:
		if cancellation.is_cancelled(): return {}
		var z: float = lerpf(-EXTENT, EXTENT, float(z_index) / subdivisions)
		for x_index: int in subdivisions + 1:
			var x: float = lerpf(-EXTENT, EXTENT, float(x_index) / subdivisions)
			var y: float = height_at(x, z)
			var normal: Vector3 = Vector3(height_at(x-0.3,z)-height_at(x+0.3,z), 0.6, height_at(x,z-0.3)-height_at(x,z+0.3)).normalized()
			vertices.append(Vector3(x,y,z)); normals.append(normal); uv.append(Vector2(x,z) / 3.0)
			var tints: Dictionary = {"continental":"637854","ocean":"5e785f","arid":"b3956b","ice":"c4d5d8","barren":"777573","toxic":"777d57"}
			var grass: Color = Color(tints[kind])
			var sand: Color = Color("baac89") if kind not in ["ice","barren","toxic"] else grass.darkened(0.13)
			var stone: Color = Color("7d827b") if kind != "arid" else Color("8c7664")
			var color: Color = sand.lerp(grass, smoothstep(0.35,2.2,y))
			color = color.lerp(stone, smoothstep(0.18,0.50,1.0-normal.y) * 0.85)
			if kind in ["continental","ocean","ice"]: color = color.lerp(Color("dde3e0"), smoothstep(10.5,13.0,y))
			colors.append(color)
			if x_index < subdivisions and z_index < subdivisions:
				var at: int = z_index * (subdivisions + 1) + x_index
				indices.append_array(PackedInt32Array([at,at+1,at+subdivisions+1,at+1,at+subdivisions+2,at+subdivisions+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	var heightmap: Image = Image.create(256,256,false,Image.FORMAT_RF)
	for row: int in 256:
		if cancellation.is_cancelled(): return {}
		for col: int in 256:
			var x: float = lerpf(-EXTENT,EXTENT,float(col)/255.0)
			var z: float = lerpf(-EXTENT,EXTENT,float(row)/255.0)
			heightmap.set_pixel(col,row,Color(height_at(x,z),0,0))
	return {"arrays": arrays, "heightmap": heightmap}
