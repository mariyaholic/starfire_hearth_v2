class_name CityRoadAccess
extends RefCounted
## Entry sockets match the front aprons in the current authored kits. Older
## assemblies use the same stable external frontage convention.
static func describe(id: String, at: Vector3, parts: Array[Dictionary], meshes: Dictionary, building_id: String = "") -> Dictionary:
	var bounds: AABB=AABB()
	var first: bool=true
	for part: Dictionary in parts:
		if part["role"] in ["steam","leaf","foliage","light","crop"]: continue
		var mesh: Mesh=meshes.get(part["mesh"])
		if mesh==null: continue
		var box: AABB=(part["transform"] as Transform3D)*mesh.get_aabb()
		# Ground aprons/paving are traversable; elevated equipment is not.
		if box.end.y<0.18: continue
		bounds=box if first else bounds.merge(box); first=false
	if first: bounds=AABB(Vector3(-1.8,0,-1.8),Vector3(3.6,1,3.6))
	var rect: Rect2=Rect2(Vector2(at.x+bounds.position.x,at.z+bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
	var entrance: Vector2=Vector2(at.x,rect.end.y+0.4)
	if building_id=="ark_hull":
		# The reclaimed hull has a side airlock and boarding ramp at local z=-2.
		entrance=Vector2(rect.end.x+0.4,at.z-2.0)
	return {"entry":{"id":id,"point":entrance},"obstacle":{"id":id,"rect":rect}}
