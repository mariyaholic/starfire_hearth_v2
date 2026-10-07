class_name SpaceObjectKit
extends RefCounted
## Civilian hull/facility assemblies made from the current Blender part library.
var meshes: Dictionary[String, Mesh] = {}
var materials: Dictionary[String, StandardMaterial3D] = {}

func _init() -> void:
	var kit: Node = (load("res://assets/3d/city_study/parts.glb") as PackedScene).instantiate()
	for child: Node in kit.get_children():
		if child is MeshInstance3D: meshes[str(child.name)] = child.mesh
	kit.free()

func _material(role: String) -> StandardMaterial3D:
	if materials.has(role): return materials[role]
	var colors: Dictionary = {"shell": "c9c8b7", "metal": "728895", "solar": "23445f", "foil": "b7a170", "light": "82d8ed"}
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(colors.get(role, "728895"))
	material.roughness = 0.4
	material.metallic = 0.15 if role == "shell" else 0.65
	var family: String = "concrete" if role == "shell" else "metal"
	material.albedo_texture = load("res://assets/textures/city_study/" + family + "_albedo.png")
	material.normal_enabled = true; material.normal_scale = 0.35
	material.normal_texture = load("res://assets/textures/city_study/" + family + "_normal.png")
	material.roughness_texture = load("res://assets/textures/city_study/" + family + "_roughness.png")
	if role == "light":
		material.emission_enabled = true; material.emission = Color("82d8ed"); material.emission_energy_multiplier = 1.8
	materials[role] = material
	return material

func _part(parent: Node3D, mesh: String, role: String, at: Vector3, dimensions: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = meshes[mesh]; part.material_override = _material(role)
	part.position = at; part.rotation_degrees = rotation; part.scale = dimensions
	parent.add_child(part)

func ship(hull: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = hull
	if hull == "survey_probe":
		_part(root, "box", "foil", Vector3.ZERO, Vector3(0.24,0.25,0.52))
		for side: int in [-1,1]:
			_part(root,"box","metal",Vector3(side*0.31,0,0),Vector3(0.50,0.025,0.03))
			_part(root,"box","solar",Vector3(side*0.56,0,0),Vector3(0.50,0.035,0.44))
		_part(root,"cone","shell",Vector3(0,0,-0.33),Vector3(0.30,0.12,0.30),Vector3(90,0,0))
		_part(root,"cylinder","metal",Vector3(0,0.30,0),Vector3(0.018,0.36,0.018))
		_part(root,"sphere","light",Vector3(0,0,-0.40),Vector3.ONE*0.10)
	elif hull == "construction_ship":
		_part(root,"box","shell",Vector3.ZERO,Vector3(0.44,0.30,0.78))
		for side: int in [-1,1]:
			_part(root,"box","foil",Vector3(side*0.34,0,0.06),Vector3(0.20,0.28,0.62))
			_part(root,"box","metal",Vector3(side*0.36,0,-0.51),Vector3(0.08,0.08,0.50))
			_part(root,"box","metal",Vector3(side*0.27,0,-0.72),Vector3(0.20,0.08,0.06))
			_part(root,"cylinder","metal",Vector3(side*0.34,0,0.44),Vector3(0.16,0.22,0.16),Vector3(90,0,0))
			_part(root,"sphere","light",Vector3(side*0.34,0,0.57),Vector3.ONE*0.09)
		_part(root,"dome","metal",Vector3(0,0.15,-0.23),Vector3(0.34,0.16,0.26))
	else:
		_part(root,"box","metal",Vector3.ZERO,Vector3(0.15,0.16,1.48))
		for i: int in 6:
			var angle: float = i*TAU/6
			var at: Vector3 = Vector3(cos(angle)*0.30,sin(angle)*0.30,0)
			_part(root,"cylinder","shell",at,Vector3(0.23,1.05,0.23),Vector3(90,0,0))
		_part(root,"sphere","shell",Vector3(0,0,-0.67),Vector3(0.45,0.45,0.30))
		for side: int in [-1,1]:
			_part(root,"box","solar",Vector3(side*0.65,0,0.30),Vector3(0.56,0.03,0.55))
			_part(root,"cylinder","metal",Vector3(side*0.25,0,0.72),Vector3(0.19,0.28,0.19),Vector3(90,0,0))
			_part(root,"sphere","light",Vector3(side*0.25,0,0.88),Vector3.ONE*0.10)
	return root

func outpost(resource: String) -> Node3D:
	var root: Node3D = Node3D.new(); root.name = "Outpost_" + resource
	_part(root,"cylinder","shell",Vector3.ZERO,Vector3(0.35,0.8,0.35))
	for side: int in [-1,1]:
		_part(root,"box","metal",Vector3(side*0.40,0,0),Vector3(0.7,0.06,0.08))
		_part(root,"box","solar",Vector3(side*0.65,0,0),Vector3(0.45,0.035,0.70))
		_part(root,"sphere","foil",Vector3(side*0.20,-0.20,0.30),Vector3(0.24,0.32,0.24))
	_part(root,"dome","metal",Vector3(0,0.41,0),Vector3(0.42,0.20,0.42))
	_part(root,"sphere","light",Vector3(0,0.65,0),Vector3.ONE*0.08)
	return root
