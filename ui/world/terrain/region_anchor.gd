class_name RegionAnchor
extends RefCounted
## Quantized geographic identity, selected once from bounded appearance-only
## candidates. No population, queues, technology, or camera inputs enter selection.
const VERSION: int = 1

static func valid(a: Dictionary, planet_id: String) -> bool:
	return a.get("version") == VERSION and a.get("planet") == planet_id and a.get("u_ppm") is int and a.get("v_ppm") is int and int(a["u_ppm"]) >= 0 and int(a["u_ppm"]) < 1000000 and int(a["v_ppm"]) >= 0 and int(a["v_ppm"]) <= 1000000 and a.get("heading_mdeg") is int and a.get("mode") in ["land", "island", "platform", "dome"]

static func direction(a: Dictionary) -> Vector3:
	return SpaceSurfaceBaker.direction(float(a["u_ppm"])/1000000.0,float(a["v_ppm"])/1000000.0)

static func mesh_direction(a: Dictionary) -> Vector3:
	# Godot SphereMesh UV: u=0 lies on +Z and u=.25 on +X. The
	# baker's unit sphere uses +X then +Z; swap axes before placing a marker.
	var d: Vector3 = direction(a)
	return Vector3(d.z,d.y,d.x)

static func choose(p: Dictionary, colony_id: String) -> Dictionary:
	var field: PlanetFieldGenerator = PlanetFieldGenerator.new(p["kind"],p["seed"],p)
	var salt: int = Rng.salt_of("appearance:anchor:1:"+p["id"]+":"+colony_id)
	var best: Dictionary = {}
	var best_score: float = INF
	for i: int in 128:
		var u: int = (Rng.salt_of(str(salt)+":u:"+str(i)) & 0x7fffffff) % 1000000
		var v: int = 170000 + (Rng.salt_of(str(salt)+":v:"+str(i)) & 0x7fffffff) % 660001
		var candidate: Dictionary = {"version":VERSION,"planet":p["id"],"u_ppm":u,"v_ppm":v,
			"heading_mdeg":salt % 360000,"mode":"land"}
		var d: Vector3 = direction(candidate)
		var s: Dictionary = field.sample(d)
		var water: bool = p["kind"] in ["continental","ocean"]
		var score: float = absf(s["elevation"] - s["sea"] - 0.024) if water else absf(s["relief"] - 0.5)
		# Prefer naturally dry planner footprints, with a coastal horizon nearby.
		var axis: Vector3 = Vector3.UP.cross(d).normalized()
		for offset: Vector2 in [Vector2(-32,-32),Vector2(-32,32),Vector2(32,-32),Vector2(32,32)]:
			var at: Vector3 = (d + (axis*offset.x+d.cross(axis)*offset.y)/float(p["projection_radius"])).normalized()
			var edge: Dictionary = field.sample(at)
			if water and float(edge["elevation"]) < float(s["sea"])+0.006: score += 2.0
		if score < best_score:
			best_score = score
			best = candidate
	if p["kind"] in ["ice","toxic","barren"]: best["mode"] = "dome"
	elif best_score >= 2.0: best["mode"] = "platform" if p["kind"] == "ocean" else "island"
	return best
