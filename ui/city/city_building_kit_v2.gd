class_name CityBuildingKitV2
extends RefCounted
## Catalog 2 completes tier silhouettes without editing the saved catalog-1 kit.
## Actual tier alone supplies these details; they do not invent production assets.
static func build(site: Dictionary, style: String, development: int, terrain_kind: String) -> Array[Dictionary]:
	var parts: Array[Dictionary]=CityBuildingKit.build(site,style,development,terrain_kind)
	if site["blocked"] or site["kind"].is_empty(): return parts
	var additions: Array[Dictionary]=[]
	if site["kind"]=="agriculture" and development>=1:
		# Irrigation manifolds for tier II; enclosed nutrient equipment at tier III.
		CityBuildingKit._part(additions,"box","metal",Vector3(0,0.3,-1.72),Vector3(2.7,0.22,0.25))
		for x: float in [-1.6,1.6]:
			CityBuildingKit._part(additions,"cylinder","accent",Vector3(x,0.48,-1.55),Vector3(0.18,0.8,0.18))
		if development>=2:
			for x: float in [-1.75,1.75]:
				CityBuildingKit._part(additions,"cylinder","shell",Vector3(x,0.75,1.38),Vector3(0.42,1.4,0.42))
				CityBuildingKit._part(additions,"dome","metal",Vector3(x,1.47,1.38),Vector3(0.45,0.25,0.45))
			CityBuildingKit._part(additions,"box","solar",Vector3(0,0.96,1.8),Vector3(1.15,0.045,0.65),Vector3(-15,0,0))
	elif site["kind"]=="energy" and style!="vael" and development>=2:
		for x: float in [-1.7,1.7]:
			CityBuildingKit._part(additions,"box","shell",Vector3(x,0.65,1.3),Vector3(0.62,1.25,0.65))
			CityBuildingKit._part(additions,"box","accent",Vector3(x,0.65,1.64),Vector3(0.22,0.85,0.025))
	elif site["kind"]=="mining" and style=="vael" and development>=1:
		CityBuildingKit._part(additions,"dome","shell",Vector3(1.5,0.04,1.2),Vector3(0.7,1.25,0.7))
		if development>=2:
			CityBuildingKit._part(additions,"arch","accent",Vector3(-1.45,0.05,1.1),Vector3(0.8,3.2,0.65),Vector3(0,90,0))
			CityBuildingKit._part(additions,"sphere","light",Vector3(-1.45,1.55,1.1),Vector3.ONE*0.18)
	parts.append_array(CityBuildingKit._varied(additions,site))
	return parts
