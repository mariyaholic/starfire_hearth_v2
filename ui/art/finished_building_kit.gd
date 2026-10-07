class_name FinishedBuildingKit
extends RefCounted
## Specific authored service equipment for all fifteen playable M1 buildings.
static func build(id: String, seed_value: int) -> Array[Dictionary]:
	var parts: Array[Dictionary]=M1BuildingKit.build(id,seed_value)
	for part: Dictionary in parts:
		if part["role"]=="foliage": part["role"]="leaf"
	if parts.is_empty(): return parts
	if id=="ark_hull":
		for part: Dictionary in parts:
			if part["role"]=="shell": part["role"]="hull"
		for side: int in [-1,1]:
			for i: int in 8:
				CityBuildingKit._box(parts,"dark",side*1.64,0.50,-4+i*1.12,0.025,0.34,0.55)
				CityBuildingKit._box(parts,"light",side*1.66,0.56,-4+i*1.12,0.015,0.17,0.38)
				CityBuildingKit._box(parts,"metal",side*1.65,1.30,-4+i*1.12,0.12,0.04,0.85)
		CityBuildingKit._box(parts,"metal",2.2,0.08,-2,1.3,0.18,1.5)
		CityBuildingKit._box(parts,"shell",1.6,0.4,-2,0.8,0.62,1.0)
		CityBuildingKit._box(parts,"foil",0.8,1.26,-0.5,0.65,0.025,0.85)
		return parts
	CityBuildingKit._box(parts,"dark",0,0.1,1.3,0.4,0.55,0.08)
	CityBuildingKit._box(parts,"metal",0,0.68,1.38,0.75,0.045,0.4)
	CityBuildingKit._box(parts,"light",0,0.55,1.36,0.25,0.04,0.025)
	match id:
		"civic_hall":
			for x: float in [-0.9,0.9]: CityBuildingKit._box(parts,"stone",x,0,1.5,0.25,1.8,0.25)
			CityBuildingKit._box(parts,"accent",0,1.65,1.4,1.5,0.15,0.15)
		"market_exchange":
			for x: float in [-1.6,1.6]:
				CityBuildingKit._box(parts,"accent",x,0.75,0.5,0.85,0.05,1.45)
				CityBuildingKit._box(parts,"foil",x,0.1,0.5,0.55,0.55,1.1)
		"archive_of_sol":
			for i: int in 5: CityBuildingKit._box(parts,"metal",-1+i*0.5,0.15,-1.0,0.15,1.6,0.28)
			CityBuildingKit._part(parts,"sphere","accent",Vector3(0,2.15,0),Vector3.ONE*0.35)
		"spaceport":
			CityBuildingKit._box(parts,"shell",-1.65,0,1.3,0.60,2.1,0.55)
			CityBuildingKit._box(parts,"glass",-1.65,1.55,1.3,0.64,0.45,0.60)
		"storehouse":
			for x: float in [-0.65,0.65]:
				for i: int in 5: CityBuildingKit._box(parts,"metal",x,0.15+i*0.10,1.16,0.9,0.035,0.05)
		"fusion_plant","planetary_shield":
			for x: float in [-1.3,1.3]: CityBuildingKit._part(parts,"cylinder","metal",Vector3(x,0.36,0),Vector3(0.18,1.8,0.18),Vector3(90,0,0))
		"clinic":
			CityBuildingKit._box(parts,"shell",0,0.05,1.6,0.9,0.65,0.70)
			CityBuildingKit._box(parts,"accent",0,0.69,1.6,0.50,0.05,0.12)
		"listening_post":
			for x: float in [-0.6,0.6]: CityBuildingKit._part(parts,"cylinder","metal",Vector3(x,1.4,-0.5),Vector3(0.025,2.4,0.025))
		"research_institute","habitat_dome","hydroponics_bay","park_commons","foundry":
			CityBuildingKit._box(parts,"metal",1.8,0.05,0.3,0.4,0.9,0.5)
			for i: int in 5: CityBuildingKit._box(parts,"dark",1.81,0.19+i*0.12,0.56,0.27,0.045,0.025)
	return parts
