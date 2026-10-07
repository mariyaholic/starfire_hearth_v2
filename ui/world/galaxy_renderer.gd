class_name GalaxyRenderer
extends M1SystemRenderer
## Actual public topology in shallow 3D; unknown systems have a neutral marker.
var _center: Vector3 = Vector3.ZERO
var _overview_distance: float = 35
var _lanes: Node3D

func _build_map() -> void:
	var lo: Vector3 = Vector3(INF,0,INF)
	var hi: Vector3 = Vector3(-INF,0,-INF)
	var positions: Dictionary[String, Vector3] = {}
	for system: Dictionary in snapshot.get("systems", []):
		var at: Vector3 = Vector3(system["x"]*0.025,0,system["y"]*0.025)
		positions[system["id"]] = at
		lo.x = minf(lo.x, at.x); lo.z = minf(lo.z, at.z)
		hi.x = maxf(hi.x, at.x); hi.z = maxf(hi.z, at.z)
		var known: bool = system["known"]
		_add_body(system["id"], system.get("name_key", "ui.galaxy.unknown"), "star" if known else "unknown", int(system.get("seed",Rng.salt_of("system_surface:"+system["id"]))) if known else 0, at, 0.55,system.get("appearance",{}))
		if known:
			var colors: Dictionary = {"K":"ffe1ad","M":"ed996f","G":"fff0cb","F":"f0f2ff","A":"cddcff","white_dwarf":"d8e6ff","binary":"ffe1ad"}
			(bodies[system["id"]]["material"] as ShaderMaterial).set_shader_parameter("star_color",Color(colors.get(system["spectral"],"fff0cb")))
		if not bodies[system["id"]].has("label"):
			var label: Label3D = Label3D.new()
			label.text = Strings.fmt(system.get("name_key", "ui.galaxy.unknown"))
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.pixel_size = 0.012; label.font_size = 30; label.outline_size = 6
			label.position = Vector3(0,0.85,0)
			(bodies[system["id"]]["node"] as Node3D).add_child(label)
			bodies[system["id"]]["label"] = label
	if not positions.is_empty():
		_center = (lo+hi)*0.5
		_overview_distance = maxf(16, (hi-lo).length()*2.2)
	if _lanes != null:
		world.remove_child(_lanes); _lanes.queue_free()
	_lanes = Node3D.new(); world.add_child(_lanes)
	if positions.is_empty() or snapshot.get("lanes", []).is_empty(): return
	var lines: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("647383")
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for lane: Dictionary in snapshot.get("lanes", []):
		if not positions.has(lane["a"]) or not positions.has(lane["b"]): continue
		var a: Vector3 = positions[lane["a"]]; var b: Vector3 = positions[lane["b"]]
		for i: int in 20:
			if i%2 == 0:
				lines.surface_add_vertex(a.lerp(b,i/20.0))
				lines.surface_add_vertex(a.lerp(b,(i+1)/20.0))
	lines.surface_end()
	var mesh: MeshInstance3D = MeshInstance3D.new(); mesh.mesh = lines
	_lanes.add_child(mesh)

func show_overview() -> void:
	selected_id = ""; _target = _center
	_distance = _overview_distance; _yaw = 0; _pitch = 0.94
	if camera != null: _update_camera(1)

func focus_body(id: String, emit_selection: bool = true) -> void:
	if bodies.has(id) and emit_selection: selected.emit(id)

func configure(description: Dictionary) -> void:
	# Public marker appearance can change only after permitted disclosure changes.
	var prior: String = _identity
	super.configure(description)
	if prior != _identity and is_node_ready():
		var desired: Dictionary = {}
		for marker: Dictionary in snapshot.get("systems", []): desired[marker["id"]] = true
		for id: String in bodies.keys():
			if not desired.has(id):
				(bodies[id]["node"] as Node3D).queue_free(); bodies.erase(id)
