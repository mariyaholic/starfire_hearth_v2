class_name RegionTerrainGenerator
extends CityTerrainGenerator
## A bounded tangent region of the SAME pinned globe field. Coordinates are art
## units, not a gameplay claim about planetary radius or available building land.
var appearance: Dictionary
var anchor: Dictionary
var field: PlanetFieldGenerator
var center: Vector3
var east: Vector3
var north: Vector3
var datum: float
var prepared_sites: Array[int] = []
var platform_height: float

func _init(p: Dictionary, a: Dictionary) -> void:
	assert(PlanetFieldGenerator.supported(p) and RegionAnchor.valid(a,p["id"]))
	super(p["seed"],p["kind"])
	appearance = p.duplicate(true); anchor = a.duplicate(true)
	field = PlanetFieldGenerator.new(kind,seed_value,appearance)
	center = RegionAnchor.direction(anchor)
	# Longitude supplies a stable basis even at either pole.
	var longitude: float = float(anchor["u_ppm"])/1000000.0*TAU
	east = Vector3(-sin(longitude),0,cos(longitude))
	north = center.cross(east).normalized()
	var heading: float = deg_to_rad(float(anchor["heading_mdeg"])/1000.0)
	var old_east: Vector3 = east
	east = old_east*cos(heading)+north*sin(heading)
	north = north*cos(heading)-old_east*sin(heading)
	var at: Dictionary = field.sample(center)
	datum = at["sea"] if kind in ["continental","ocean"] else float(at["relief"])-0.025
	platform_height = maxf(1.2,(float(at["elevation"])-datum)*float(appearance["relief_units"]))

func direction_at(x: float, z: float) -> Vector3:
	return (center+(east*x+north*z)/float(appearance["projection_radius"])).normalized()

func global_sample(x: float, z: float) -> Dictionary:
	return field.sample(direction_at(x,z))

func raw_height(x: float, z: float) -> float:
	var sample: Dictionary = global_sample(x,z)
	var value: float = sample["elevation"] if kind in ["continental","ocean"] else sample["relief"]
	return (value-datum)*float(appearance["relief_units"])

func footing_height(x: float, z: float) -> float:
	# Local support guarantees every otherwise-legal canonical parcel. A water
	# world receives a platform/island; it never changes simulation slot legality.
	return maxf(1.0,raw_height(x,z)) if kind in ["continental","ocean"] else raw_height(x,z)

func height_at(x: float, z: float) -> float:
	var h: float = raw_height(x,z)
	if anchor["mode"] in ["island","platform"]:
		h = lerpf(h,maxf(h,platform_height),1.0-smoothstep(28.0,40.0,Vector2(x,z).length()))
	for slot: Dictionary in slots:
		var at: Vector3 = slot["at"]
		var distance: float = Vector2(x-at.x,z-at.z).length()
		if slot["blocked"]:
			h += exp(-distance*distance/4.0)*2.8
	# Grade after ALL outcrops, so neighboring blocked-plot tails cannot lift
	# an otherwise valid completed footing.
	for slot: Dictionary in slots:
		if slot["blocked"] or (slot["kind"].is_empty() and not prepared_sites.has(int(slot["slot"]))): continue
		var at: Vector3 = slot["at"]
		var distance: float = Vector2(x-at.x,z-at.z).length()
		if distance < 3.0:
			h = lerpf(h,at.y,1.0-smoothstep(1.9,3.0,distance))
	return h

func layout(districts: Array, blocked: Array, slot_count: int = 20) -> Dictionary:
	var result: Dictionary = super.layout(districts,blocked,slot_count)
	for slot: Dictionary in slots:
		var at: Vector3 = slot["at"]
		at.y = footing_height(at.x,at.z)+0.04
		slot["at"] = at
	result["slots"] = slots.duplicate(true)
	result["anchor"] = anchor.duplicate(true)
	result["appearance_key"] = PlanetFieldGenerator.key(appearance)
	result["region_version"] = RegionAnchor.VERSION
	return result

func bake(cancellation: SpaceSurfaceBaker.Cancellation, subdivisions: int = 128) -> Dictionary:
	var job: RegionBakeJob = RegionBakeJob.new(self,subdivisions,cancellation)
	while not job.step(256): pass
	return job.maps()
