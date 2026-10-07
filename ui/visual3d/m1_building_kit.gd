class_name M1BuildingKit
extends RefCounted
## Compact functional silhouettes for the actual M1 building catalog. Appearance only.

static func build(id: String, seed_value: int) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	match id:
		"spaceport":
			CityBuildingKit._box(parts,"dark",0,0,0,3.7,0.10,3.7)
			for side: int in [-1,1]:
				CityBuildingKit._box(parts,"light",side*0.48,0.105,0,0.09,0.015,1.15)
				CityBuildingKit._box(parts,"metal",side*1.65,0,1.35,0.18,1.65,0.18)
			CityBuildingKit._box(parts,"light",0,0.105,0,0.98,0.015,0.09)
			CityBuildingKit._box(parts,"shell",0,0,1.75,1.65,0.62,0.55)
			CityBuildingKit._box(parts,"metal",0,1.55,1.35,3.48,0.13,0.20)
		"storehouse":
			for x: int in 2:
				for z: int in 2:
					CityBuildingKit._box(parts,"shell",x*1.30-0.65,0,z*1.24-0.62,1.15,0.77,1.05)
					CityBuildingKit._box(parts,"dark",x*1.30-0.65,0.45,z*1.24-0.08,0.77,0.22,0.02)
		"fusion_plant", "planetary_shield":
			for i: int in 3:
				CityBuildingKit._part(parts,"cylinder","metal",Vector3(i*0.85-0.85,0.7,0),Vector3(0.70,1.4,0.70))
			CityBuildingKit._part(parts,"sphere","accent",Vector3(0,1.75,0),Vector3.ONE*0.6)
			CityBuildingKit._box(parts,"shell",0,0,1.15,2.5,0.55,0.65)
			if id == "planetary_shield":
				CityBuildingKit._part(parts,"arch","metal",Vector3(0,0,0),Vector3(3.1,5,0.9))
		"research_institute", "habitat_dome":
			parts = CityBuildingKit.build({"kind":"research" if id == "research_institute" else "habitation", "blocked":false,"seed":seed_value},"ark",1,"continental")
			if id == "habitat_dome": CityBuildingKit._part(parts,"dome","glass",Vector3(0,0.05,0),Vector3(3.5,2.6,3.5))
		"hydroponics_bay":
			parts = CityBuildingKit.build({"kind":"agriculture","blocked":false,"seed":seed_value},"ark",1,"continental")
			CityBuildingKit._box(parts,"shell",0,0.3,1.8,1.25,0.85,0.6)
		"park_commons":
			CityBuildingKit._box(parts,"road",0,0.01,0,0.3,0.02,3.4)
			for x: int in [-1,1]:
				for z: int in [-1,1]:
					CityBuildingKit._part(parts,"cone","dark",Vector3(x,0.4,z),Vector3(0.12,0.8,0.12))
					CityBuildingKit._part(parts,"foliage","foliage",Vector3(x,1.05,z),Vector3.ONE*1.4)
			CityBuildingKit._box(parts,"shell",0.7,0.15,0,0.5,0.18,1.3)
		"foundry", "industrial_megaplex":
			parts = CityBuildingKit.build({"kind":"industry","blocked":false,"seed":seed_value},"ark",2 if id == "industrial_megaplex" else 0,"continental")
		"clinic":
			CityBuildingKit._box(parts,"shell",0,0,0,2.8,0.95,1.15)
			CityBuildingKit._box(parts,"shell",0,0,0,1.1,0.95,2.65)
			CityBuildingKit._box(parts,"light",0,0.951,0,0.72,0.02,0.14)
			CityBuildingKit._box(parts,"light",0,0.951,0,0.14,0.02,0.72)
		"listening_post":
			CityBuildingKit._box(parts,"shell",0,0,0,1.5,0.65,1.6)
			CityBuildingKit._part(parts,"cylinder","metal",Vector3(0,1.35,0),Vector3(0.17,1.7,0.17))
			CityBuildingKit._part(parts,"dome","metal",Vector3(0,2.1,0),Vector3(2.1,0.3,2.1),Vector3(25,0,0))
		"civic_hall", "market_exchange", "archive_of_sol":
			CityBuildingKit._box(parts,"shell",0,0,0,2.55,1.25,1.8)
			for side: int in [-1,1]: CityBuildingKit._box(parts,"metal",side*1.3,0,1.0,0.16,1.8,0.16)
			CityBuildingKit._part(parts,"dome","glass",Vector3(0,1.25,0),Vector3(2.6,0.65,1.9))
			CityBuildingKit._box(parts,"light",0,0.45,0.92,1.7,0.25,0.02)
		"ark_hull":
			CityBuildingKit._box(parts,"shell",0,0.15,0,3.25,1.1,12.0)
			CityBuildingKit._part(parts,"cone","shell",Vector3(0,0.75,-7),Vector3(3.25,3.0,1.7),Vector3(-90,0,0))
			for side: int in [-1,1]:
				CityBuildingKit._box(parts,"metal",side*2.1,0.2,2.5,1.05,0.95,6.2)
				CityBuildingKit._part(parts,"cylinder","dark",Vector3(side*2.1,0.68,5.9),Vector3(0.75,0.9,0.75),Vector3(90,0,0))
				for brace: int in 4: CityBuildingKit._box(parts,"dark",side*1.1,1.24,-3.6+brace*2.2,0.06,0.04,1.25)
	return parts
