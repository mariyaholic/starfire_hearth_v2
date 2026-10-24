class_name SpaceSurfaceBaker
extends RefCounted
## Appearance only. Spherical noise avoids a longitude seam; the seed and generator
## version identify a surface across overview/focus LODs. Images can bake on workers.
## No global RNG, simulation mutation, Node access or GPU work in this baker.

const VERSION: int = 1
const TYPES: Array[String] = ["continental", "ocean", "arid", "ice", "barren", "toxic", "gas_giant"]

class Cancellation:
	extends RefCounted
	var _mutex: Mutex = Mutex.new()
	var _cancelled: bool = false
	func cancel() -> void:
		_mutex.lock()
		_cancelled = true
		_mutex.unlock()
	func is_cancelled() -> bool:
		_mutex.lock()
		var value: bool = _cancelled
		_mutex.unlock()
		return value


static func _noise(seed_value: int, frequency: float, octaves: int = 4) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_gain = 0.5
	return n


static func direction(u: float, v: float) -> Vector3:
	var longitude: float = u * TAU
	var latitude: float = v * PI
	return Vector3(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude))


## The exact same pixel algorithm can be advanced in bounded batches on non-threaded web.
class BakeJob:
	extends RefCounted
	var kind: String
	var seed_value: int
	var width: int
	var cancellation: Cancellation
	var cursor: int = 0
	var done: bool = false
	var cancelled: bool = false
	var height_px: int
	var albedo: Image
	var surface: Image
	var clouds: Image
	var normal: Image
	var heights: PackedFloat32Array
	var field: PlanetFieldGenerator
	var appearance: Dictionary

	func _init(surface_kind: String, surface_seed: int, map_width: int, token: Cancellation = null, profile: Dictionary = {}) -> void:
		if not profile.is_empty() and (not PlanetFieldGenerator.supported(profile) or profile["seed"] != surface_seed or profile["kind"] != surface_kind):
			cancelled = true
			return
		assert(surface_kind in SpaceSurfaceBaker.TYPES or surface_kind == "star")
		assert(map_width >= 16 and map_width <= 2048)
		kind = surface_kind
		seed_value = surface_seed
		width = map_width
		cancellation = token
		height_px = width / 2
		albedo = Image.create(width, height_px, false, Image.FORMAT_RGB8)
		surface = Image.create(width, height_px, false, Image.FORMAT_RGB8)
		clouds = Image.create(width, height_px, false, Image.FORMAT_RGB8)
		normal = Image.create(width, height_px, false, Image.FORMAT_RGB8)
		appearance = profile.duplicate(true)
		field = PlanetFieldGenerator.new(kind,seed_value,appearance)
		heights = PackedFloat32Array()
		heights.resize(width * height_px)

	func step(pixel_budget: int = 32) -> bool:
		assert(pixel_budget > 0)
		if done or cancelled: return true
		var pixels: int = width * height_px
		var stop: int = mini(cursor + pixel_budget, pixels * 2)
		while cursor < stop:
			if cancellation != null and cursor % 16 == 0 and cancellation.is_cancelled():
				cancelled = true
				return true
			var index: int = cursor % pixels
			var x: int = index % width
			var y: int = index / width
			if cursor < pixels: _paint_pixel(x,y)
			else: _normal_pixel(x,y)
			cursor += 1
		done = cursor == pixels * 2
		if done: heights.resize(0)
		return done

	func maps() -> Dictionary:
		if not done or cancelled: return {}
		return {"albedo":albedo,"surface":surface,"clouds":clouds,"normal":normal,
			"seed":seed_value,"kind":kind,"width":width,"version":SpaceSurfaceBaker.VERSION, "appearance_key":PlanetFieldGenerator.key(appearance)}

	func _paint_pixel(x: int, y: int) -> void:
		var d: Vector3 = SpaceSurfaceBaker.direction(float(x) / width, float(y) / (height_px - 1))
		var sample: Dictionary = field.sample(d)
		albedo.set_pixel(x,y,sample["color"])
		surface.set_pixel(x,y,sample["surface"])
		clouds.set_pixel(x,y,Color(sample["cloud"],sample["cloud"],sample["cloud"]))
		heights[y * width + x] = sample["relief"]

	func _normal_pixel(x: int, y: int) -> void:
		var latitude_scale: float = maxf(0.18, sin(float(y) / (height_px - 1) * PI))
		var dx: float = heights[y * width + (x + 1) % width] - heights[y * width + (x + width - 1) % width]
		var dy: float = heights[mini(y + 1, height_px - 1) * width + x] - heights[maxi(y - 1, 0) * width + x]
		var strength: float = float(width) * (0.045 if kind == "barren" else 0.010)
		var n: Vector3 = Vector3(-dx * strength / latitude_scale, -dy * strength, 1.0).normalized()
		normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))



static func bake(kind: String, seed_value: int, width: int = 256, cancellation: Cancellation = null, appearance: Dictionary = {}) -> Dictionary:
	var job: BakeJob = BakeJob.new(kind,seed_value,width,cancellation,appearance)
	while not job.step(4096): pass
	return job.maps()


static func cache_key(kind: String, seed_value: int, width: int, appearance: Dictionary = {}) -> String:
	return "%d:%s:%d:%d" % [VERSION, kind, seed_value, width] + (":"+PlanetFieldGenerator.key(appearance) if not appearance.is_empty() else "")
