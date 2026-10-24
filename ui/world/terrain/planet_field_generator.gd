class_name PlanetFieldGenerator
extends RefCounted
## Frozen sphere_fbm/1 field. Every globe pixel and regional sample shares this
## function. Retain this implementation when adding a new dispatcher version.
const GENERATOR: String = "sphere_fbm"
const VERSION: int = 1
const MATERIAL_VERSION: int = 1
var seed_value: int
var kind: String
var broad: FastNoiseLite
var detail: FastNoiseLite
var fine: FastNoiseLite
var wet: FastNoiseLite
var cloud_noise: FastNoiseLite
var crater_rng: RandomNumberGenerator
var craters: Array[Vector4]
var sea_level: float = 0.49

static func profile(id: String, source_seed: int, surface_kind: String, legacy: bool = false) -> Dictionary:
	return {"schema":1, "id":id, "source_seed":source_seed,
		"seed":source_seed if legacy else Rng.salt_of("appearance:sphere_fbm:1:"+id+":"+str(source_seed)) & 0x7fffffff,
		"kind":surface_kind, "generator":GENERATOR, "generator_version":VERSION,
		"material_version":MATERIAL_VERSION, "sea_ppm":490000 if surface_kind == "continental" else 620000,
		"projection_radius":3200, "relief_units":180, "legacy":legacy}

static func supported(p: Dictionary) -> bool:
	return p.get("schema") == 1 and p.get("generator") == GENERATOR and p.get("generator_version") == VERSION and p.get("material_version") == MATERIAL_VERSION and p.get("seed") is int and p.get("sea_ppm") is int and int(p["sea_ppm"]) >= 0 and int(p["sea_ppm"]) <= 1000000 and p.get("projection_radius") is int and int(p["projection_radius"]) >= 1000 and p.get("relief_units") is int and int(p["relief_units"]) > 0 and p.get("kind") in SpaceSurfaceBaker.TYPES + ["star", "asteroid_belt"]

static func key(p: Dictionary) -> String:
	return CanonicalJson.stringify(p).sha256_text()

func _init(surface_kind: String, surface_seed: int, appearance: Dictionary = {}) -> void:
	kind = surface_kind
	seed_value = surface_seed
	sea_level = float(appearance.get("sea_ppm",490000 if kind == "continental" else 620000)) / 1000000.0
	broad = SpaceSurfaceBaker._noise(seed_value, 2.8, 5)
	detail = SpaceSurfaceBaker._noise(seed_value + 197, 20.0, 4)
	fine = SpaceSurfaceBaker._noise(seed_value + 811, 140.0, 2)
	wet = SpaceSurfaceBaker._noise(seed_value + 313, 7.0, 4)
	cloud_noise = SpaceSurfaceBaker._noise(seed_value + 991, 5.0, 5)
	crater_rng = RandomNumberGenerator.new()
	crater_rng.seed = seed_value
	craters = []
	if kind == "barren":
		for i: int in 22:
			var at: Vector3 = SpaceSurfaceBaker.direction(crater_rng.randf(), acos(crater_rng.randf_range(-1.0, 1.0)) / PI)
			craters.append(Vector4(at.x, at.y, at.z, crater_rng.randf_range(0.04, 0.20)))

func sample(d: Vector3) -> Dictionary:
	var large: float = broad.get_noise_3dv(d)
	var small: float = detail.get_noise_3dv(d)
	var grain: float = fine.get_noise_3dv(d)
	var moisture: float = wet.get_noise_3dv(d) * 0.5 + 0.5
	var elevation: float = clampf(0.5 + large * 0.72 + small * 0.055, 0.0, 1.0)
	var sea: float = sea_level
	var land: float = smoothstep(sea - 0.005, sea + 0.005, elevation)
	var color: Color = Color("71817e")
	var roughness: float = 0.85
	var relief: float = elevation
	var weather_direction: Vector3 = (d + Vector3(moisture - 0.5, small, large) * 0.22).normalized()
	var cloud_amount: float = smoothstep(-0.15, 0.36, cloud_noise.get_noise_3dv(weather_direction))
	cloud_amount *= clampf(0.85 + grain * 0.35 + small * 0.5, 0.35, 1.0)
	if kind == "continental" or kind == "ocean":
		var depth: float = clampf((elevation - sea + 0.22) / 0.22, 0.0, 1.0)
		var ocean: Color = Color("07182d").lerp(Color("247c91"), pow(depth, 3.0))
		var ground: Color = Color("a08c58").lerp(Color("285a42"), moisture)
		ground = ground.lerp(Color("817d70"), smoothstep(sea + 0.11, sea + 0.27, elevation))
		var snow: float = smoothstep(0.76, 0.94, absf(d.y) + maxf(elevation - sea - 0.1, 0.0) * 0.6)
		ground = ground.lerp(Color("d8e4e8"), snow)
		ground = ground.lerp(Color("c9ba91"), 1.0 - smoothstep(sea, sea + 0.013, elevation))
		color = ocean.lerp(ground, land)
		roughness = lerpf(0.16, 0.87, land)
		relief = maxf(elevation, sea) if land > 0.5 else sea
		cloud_amount *= 0.83
	elif kind == "barren":
		land = 1.0
		relief = 0.5 + large * 0.05 + small * 0.02
		for crater: Vector4 in craters:
			var dot_value: float = d.dot(Vector3(crater.x, crater.y, crater.z))
			if dot_value > 1.0 - crater.w * crater.w * 0.72:
				var radius: float = sqrt(maxf(0.0, 2.0 - 2.0 * dot_value)) / crater.w
				relief += 0.085 * exp(-pow((radius - 0.90) / 0.13, 2.0)) - 0.08 * (1.0 - smoothstep(0.45, 0.90, radius))
		color = Color("363a3d").lerp(Color("a59d8e"), clampf(elevation * 0.55 + relief * 0.45, 0.0, 1.0))
		cloud_amount = 0.0
	elif kind == "arid":
		land = 1.0
		color = Color("6e4530").lerp(Color("d0aa74"), elevation)
		color = color.lerp(Color("776957"), smoothstep(0.60, 0.78, elevation))
		cloud_amount *= 0.13
	elif kind == "ice":
		land = 1.0
		var fissure: float = 1.0 - smoothstep(0.0, 0.04, absf(small))
		color = Color("68929f").lerp(Color("e1e9e8"), elevation * 0.6 + 0.35)
		color = color.lerp(Color("356273"), fissure * 0.38)
		roughness = 0.58
		cloud_amount *= 0.22
	elif kind == "toxic":
		land = 1.0
		color = Color("454538").lerp(Color("a39b64"), elevation)
		cloud_amount = clampf(cloud_amount * 0.65 + 0.25, 0.0, 1.0)
	elif kind == "gas_giant":
		land = 1.0
		var band: float = sin(d.y * 48.0 + small * 3.2 + float(seed_value % 71)) * 0.5 + 0.5
		color = Color("825a44").lerp(Color("dbc1a1"), band)
		var storm: float = pow(maxf(0.0, d.dot(SpaceSurfaceBaker.direction(0.33 + float(seed_value % 9) * 0.035, 0.57))), 100.0)
		color = color.lerp(Color("b16b4e"), storm * 0.75)
		relief = 0.5 + small * 0.006
		roughness = 0.95
		cloud_amount = 0.0
	elif kind == "star":
		land = 1.0
		var granule: float = clampf(0.5 + grain * 1.0 + small * 0.35, 0.0, 1.0)
		var spots: float = 1.0 - smoothstep(-0.42, -0.19, large)
		color = Color(granule, granule, granule) * (1.0 - spots * 0.73)
		relief = granule
		cloud_amount = 0.0
	color *= 0.96 + grain * 0.11 if kind != "star" else 1.0
	return {"color":color, "surface":Color(clampf(relief,0.0,1.0),land,roughness),
		"cloud":cloud_amount, "relief":relief, "elevation":elevation, "sea":sea,
		"land":land, "moisture":moisture, "grain":grain}
