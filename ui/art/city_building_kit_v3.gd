class_name CityBuildingKitV3
extends RefCounted
## Versioned finishing layer; actual district function and tier are authoritative.
static func build(site: Dictionary, style: String, tier: int, kind: String) -> Array[Dictionary]:
	var parts: Array[Dictionary]=CityBuildingKitV2.build(site,style,tier,kind)
	if site["blocked"] or site["kind"].is_empty(): return parts
	var detail: Array[Dictionary]=[]
	# Entry apron, sheltered doorway and service junctions make the assembly usable.
	CityBuildingKit._box(detail,"stone",0,0.01,2.0,1.0,0.06,0.55)
	CityBuildingKit._box(detail,"dark",0,0.08,1.73,0.34,0.46,0.10)
	CityBuildingKit._box(detail,"metal",0,0.57,1.78,0.65,0.05,0.38)
	CityBuildingKit._box(detail,"light",0,0.46,1.80,0.20,0.025,0.03)
	match site["kind"]:
		"habitation":
			for x: float in [-1.1,1.1]:
				CityBuildingKit._box(detail,"metal",x,0.25,0.86,0.65,0.035,0.3)
				CityBuildingKit._box(detail,"metal",x,0.58,1.0,0.65,0.045,0.045)
				for end: float in [-0.28,0.28]: CityBuildingKit._box(detail,"metal",x+end,0.25,1.0,0.035,0.36,0.035)
		"agriculture":
			for x: float in [-1.45,1.45]:
				CityBuildingKit._part(detail,"cylinder","metal",Vector3(x,0.15,0),Vector3(0.045,2.7,0.045),Vector3(90,0,0))
				for z: float in [-1.2,-0.6,0,0.6,1.2]: CityBuildingKit._part(detail,"sphere","crop",Vector3(x*0.6,0.28,z),Vector3(0.16,0.25,0.16))
		"industry":
			for i: int in 3+tier:
				CityBuildingKit._part(detail,"cylinder","metal",Vector3(1.3,0.5,-0.65+i*0.24),Vector3(0.09,0.75,0.09),Vector3(0,0,90))
			CityBuildingKit._box(detail,"dark",0,0.18,1.0,0.65,0.75,0.07)
		"research":
			for side: int in [-1,1]:
				CityBuildingKit._part(detail,"cylinder","shell",Vector3(side*1.65,0.58,-0.8),Vector3(0.34,1.1,0.34))
				CityBuildingKit._part(detail,"sphere","light",Vector3(side*1.65,1.2,-0.8),Vector3.ONE*0.12)
		"mining":
			for i: int in 4: CityBuildingKit._box(detail,"metal",1.0+i*0.22,0.35,0.8,0.09,0.05,0.65)
			CityBuildingKit._box(detail,"foil",1.7,0.06,-1.4,0.55,0.4,0.65)
		"energy":
			for i: int in 3: CityBuildingKit._box(detail,"dark",-0.5+i*0.5,0.12,1.89,0.25,0.3,0.03)
	if style=="ark":
		# Repaired plating: geometric seams and an exterior utility cabinet.
		CityBuildingKit._box(detail,"foil",1.8,0.12,1.4,0.35,0.48,0.35)
	elif style=="meridian":
		for x: float in [-1.8,1.8]: CityBuildingKit._box(detail,"accent",x,0,1.85,0.15,0.92+tier*0.15,0.15)
	else:
		CityBuildingKit._part(detail,"arch","accent",Vector3(0,0,1.85),Vector3(0.9,1.6+tier*0.15,0.30))
		for x: float in [-0.6,0.6]: CityBuildingKit._part(detail,"dome","shell",Vector3(x,0.04,1.95),Vector3(0.32,0.55,0.32))
	parts.append_array(CityBuildingKit._varied(detail,site))
	return parts
