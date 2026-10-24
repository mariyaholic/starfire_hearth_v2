class_name SpaceObjectKitV2
extends SpaceObjectKit
## Full Blender hulls; each carries three independently exported geometry LODs.
func _material(role: String) -> StandardMaterial3D:
	if materials.has(role): return materials[role]
	if role=="glass": return FinishMaterials.glass()
	var material: StandardMaterial3D=StandardMaterial3D.new()
	var family: String="ceramic" if role=="shell" else "metal"
	material.albedo_color=Color({"shell":"f5edda","metal":"b4c1c7","solar":"305a86","foil":"dac184","light":"8cddea"}.get(role,"aab7be"))
	material.albedo_texture=FinishMaterials.texture(family,"albedo")
	material.normal_enabled=true; material.normal_scale=0.32; material.normal_texture=FinishMaterials.texture(family,"normal")
	material.roughness_texture=FinishMaterials.texture(family,"roughness"); material.roughness=0.75
	material.metallic=0.08 if role=="shell" else 0.75
	material.ao_enabled=true; material.ao_texture=FinishMaterials.texture("trim","ao"); material.ao_light_affect=0.2
	if role=="light": material.emission_enabled=true; material.emission=Color("83d9ec"); material.emission_energy_multiplier=1.5
	materials[role]=material
	return material

func ship(hull: String) -> Node3D:
	if hull not in ["survey_probe","construction_ship","colony_ship"]: return super(hull)
	var root: Node3D=Node3D.new(); root.name=hull; root.set_meta("finish_hull",true)
	for lod: int in 3:
		var level: Node3D=(load("res://assets/3d/finish_v1/"+hull+"_lod"+str(lod)+".glb") as PackedScene).instantiate()
		level.name="LOD"+str(lod); level.visible=lod==2
		_assign(level); root.add_child(level)
	return root

func _assign(node: Node) -> void:
	if node is MeshInstance3D: (node as MeshInstance3D).material_override=_material(str(node.name).split("_")[0])
	for child: Node in node.get_children(): _assign(child)

static func set_lod(root: Node3D, level: int) -> void:
	if not root.has_meta("finish_hull"): return
	for lod: int in 3: (root.get_node("LOD"+str(lod)) as Node3D).visible=lod==level
