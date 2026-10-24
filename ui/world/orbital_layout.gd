class_name OrbitalLayout
extends RefCounted
## Stable, quantized presentation-only orbital mechanics. One campaign turn is one month.
const VERSION: int=1
const TURNS_PER_YEAR: int=12
const FULL_TURN_MDEG: int=360000

static func stellar_mass_milli(spectral: String) -> int:
	return {"M":400,"K":750,"G":1000,"F":1400,"A":2200,"white_dwarf":650,"binary":1600}.get(spectral,1000)

static func build_recipe(state: GameState) -> Dictionary:
	var systems: Dictionary={}
	for system_id: String in DictIO.sorted_keys(state.systems):
		var system: StarSystem=state.systems[system_id]
		var bodies: Dictionary={}
		for body_id: String in system.planet_ids:
			if not state.planets.has(body_id): continue
			var planet: Planet=state.planets[body_id]
			var rank: int=maxi(0,planet.orbit)
			var distance_milli: int=550+rank*rank*850+rank*125
			var seed: int=Rng.salt_of("m12_orbit:%s:%s:%d" % [system_id,body_id,planet.art_seed])
			var period: int=maxi(1,roundi(float(TURNS_PER_YEAR)*sqrt(pow(float(distance_milli)/1000.0,3.0)/(float(stellar_mass_milli(system.spectral))/1000.0))))
			bodies[body_id]={"distance_milli":distance_milli,"display_milli":2100+rank*1700,"phase_mdeg":posmod(seed,FULL_TURN_MDEG),"epoch_turn":0,"period_turns":period}
		systems[system_id]={"version":VERSION,"mass_milli":stellar_mass_milli(system.spectral),"bodies":bodies}
	return {"identity":AppearanceProfileStore.identity(state),"version":VERSION,"systems":systems}

static func position(recipe: Dictionary,body_id: String,turn: int) -> Vector3:
	var body: Variant=recipe.get("bodies",{}).get(body_id,{})
	if not body is Dictionary: return Vector3.ZERO
	var period: int=maxi(1,int(body.get("period_turns",1)))
	var elapsed: int=turn-int(body.get("epoch_turn",0))
	var angle_mdeg: int=posmod(int(body.get("phase_mdeg",0))+posmod(elapsed,period)*FULL_TURN_MDEG/period,FULL_TURN_MDEG)
	var angle: float=deg_to_rad(float(angle_mdeg)/1000.0)
	var radius: float=float(int(body.get("display_milli",2100)))/1000.0
	return Vector3(cos(angle)*radius,0.0,sin(angle)*radius)

static func path_mesh(radius: float,segments: int=96) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for i: int in segments+1:
		var angle: float=TAU*float(i)/float(segments)
		points.append(Vector3(cos(angle)*radius,0.0,sin(angle)*radius))
	return points

static func body_extent(kind: String) -> float:
	# Rings occupy more space than the gas giant's sphere; belts use their full rock spread.
	return 1.55*2.1 if kind=="gas_giant" else 1.55 if kind=="asteroid_belt" else 0.65 if kind=="barren" else 1.0

static func display_recipe(saved: Dictionary,disclosed: Array,star_radius: float) -> Dictionary:
	var output: Dictionary=saved.duplicate(true)
	var records: Dictionary=output.get("bodies",{})
	var ordered: Array=disclosed.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["orbit"]<b["orbit"] if a["orbit"]!=b["orbit"] else str(a["id"])<str(b["id"]))
	var previous_radius: float=0.0
	var previous_extent: float=star_radius*1.25
	for planet: Dictionary in ordered:
		if not records.has(planet["id"]): continue
		var extent: float=body_extent(planet["kind"])
		var original: float=float(records[planet["id"]].get("display_milli",2100))/1000.0
		var radius: float=maxf(original*1.4+1.0,previous_radius+previous_extent+extent+1.4)
		records[planet["id"]]["display_milli"]=roundi(radius*1000.0)
		previous_radius=radius; previous_extent=extent
	return output

static func normalize_for_system(recipe: Dictionary,system_id: String,body_ids: Array[String]=[]) -> Dictionary:
	if recipe.is_empty(): return {}
	var systems: Variant=recipe.get("systems",{})
	if systems is Dictionary and systems.has(system_id) and systems[system_id] is Dictionary:
		var system: Dictionary=systems[system_id].duplicate(true)
		var bodies: Variant=system.get("bodies",{})
		if bodies is Dictionary and not body_ids.is_empty():
			var filtered: Dictionary={}
			for id: String in body_ids:
				if bodies.has(id): filtered[id]=bodies[id].duplicate(true)
			system["bodies"]=filtered
		return {"identity":recipe.get("identity",{}),"version":VERSION,"system_id":system_id,"mass_milli":system.get("mass_milli",1000),"bodies":system.get("bodies",{})}
	# M1.2 development and archived drafts briefly used one-system components.
	if str(recipe.get("system_id",""))!=system_id: return {}
	var legacy: Dictionary=recipe.duplicate(true)
	legacy["version"]=int(legacy.get("version",legacy.get("recipe_version",0)))
	if not body_ids.is_empty() and legacy.get("bodies") is Dictionary:
		var filtered: Dictionary={}
		for id: String in body_ids:
			if legacy["bodies"].has(id): filtered[id]=legacy["bodies"][id].duplicate(true)
		legacy["bodies"]=filtered
	return legacy
