class_name M1ColonyRenderer
extends Control

const GROUND_SHADER: Shader = preload("res://ui/city/shaders/terrain.gdshader")
const BUILDING_SHADER: Shader = preload("res://ui/city/shaders/building.gdshader")
const WATER_SHADER: Shader = preload("res://ui/city/shaders/water.gdshader")
const WINDOWS_SHADER: Shader = preload("res://ui/city/shaders/windows.gdshader")
const STEAM_SHADER: Shader = preload("res://ui/city/shaders/steam.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://ui/city/shaders/foliage.gdshader")

var appearance_seed: int = 11
var architecture: String = "ark"
var terrain_kind: String = "continental"
var development: int = 0
var planning: bool = false
var dusk: bool = false
var motion_paused: bool = false
var visual_time: float = 0.0
var busy: bool = true
var selected_slot: int = -1
var hovered_slot: int = -1
var recipe: Dictionary = {}
var generator: CityTerrainGenerator
var viewport: SubViewport
var camera: Camera3D
var slot_areas: Dictionary[int, Area3D] = {}
var _world: Node3D
var _landscape: Node3D
var _city: Node3D
var _planner: Node3D
var _meshes: Dictionary[String, Mesh] = {}
var _materials: Dictionary[String, Material] = {}
var _water: ShaderMaterial
var _windows: ShaderMaterial
var _steam: ShaderMaterial
var _leaves: ShaderMaterial
var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _vehicles: Array[MultiMesh] = []
var _top: PanelContainer
var _sidebar: PanelContainer
var _title: Label
var _description: Label
var _status: Label
var _hover: Label
var _pause_button: CheckButton
var _planning_button: CheckButton
var _dusk_button: CheckButton
var _stage_selector: OptionButton
var _style_selector: OptionButton
var _terrain_selector: OptionButton
var _target: Vector3 = Vector3(0,2,0)
var _look_at: Vector3 = Vector3(0,2,0)
var _distance: float = 44.0
var _current_distance: float = 44.0
var _yaw: float = 0.55
var _pitch: float = 0.61
var _dragging: bool = false
var _drag_pixels: float = 0.0
var _snapshot: Dictionary
var _blocked: Array = []
var _ticket: int = 0
var _queued: Dictionary = {}
var _job: int = -1
var _cancellation: SpaceSurfaceBaker.Cancellation
var _result: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _region_job: RegionBakeJob
var _region_recipe: Dictionary = {}
var _region_ticket: int = 0
var generation: GenerationScheduler
var session_epoch: int = 0
var resource_owner: String = ""
var _region_key: String = ""

func bind_generation(service: GenerationScheduler, epoch: int, owner: String) -> void:
	generation = service; session_epoch = epoch; resource_owner = owner
	generation.region_ready.connect(_region_ready)

func _region_ready(owner: String, epoch: int, key: String, result: Dictionary) -> void:
	if owner != resource_owner or epoch != session_epoch or key != _region_key: return
	if result.get("maps",{}).is_empty(): return
	generator = result["generator"]; recipe = result["recipe"]
	_apply_terrain(result["maps"]); busy = false

signal selected(index: int)
var snapshot: Dictionary = {}
var ghost: Dictionary = {}
var _container: SubViewportContainer
var _built_key: String = ""
var _vegetation_root: Node3D


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.stretch_shrink = 2 if OS.has_feature("web") else 1
	_container.gui_input.connect(_viewport_input)
	add_child(_container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("web") else Viewport.MSAA_2X
	_container.add_child(viewport)
	_world = Node3D.new(); viewport.add_child(_world)
	camera = Camera3D.new(); camera.fov = 48; camera.far = 450; _world.add_child(camera)
	_load_meshes(); _environment_setup()
	show_overview()
	if not snapshot.is_empty(): _configure_landscape()


func configure(description: Dictionary, preview: Dictionary = {}) -> void:
	var built: Dictionary = description.duplicate(true)
	built.erase("queue")
	var key: String = JSON.stringify(built)
	var changed: bool = key != _built_key
	_built_key = key
	snapshot = description.duplicate(true)
	ghost = preview.duplicate(true)
	if not is_node_ready(): return
	if changed: _configure_landscape()
	elif not recipe.is_empty(): _rebuild_city()


func _configure_landscape() -> void:
	if snapshot.is_empty(): return
	appearance_seed = snapshot["seed"]
	terrain_kind = snapshot["kind"] if snapshot["kind"] in CityTerrainGenerator.KINDS else "arid"
	architecture = snapshot["architecture"] if snapshot["architecture"] in CityBuildingKit.STYLES else "ark"
	_environment.background_mode = Environment.BG_COLOR if terrain_kind == "barren" else Environment.BG_SKY
	_environment.background_color = Color("03050a")
	_environment.fog_enabled = terrain_kind != "barren"
	_snapshot = {"districts": snapshot["districts"].duplicate(true), "count": snapshot["slot_count"]}
	for building: Dictionary in snapshot["buildings"]:
		if building["slot"] >= 0:
			_snapshot["districts"].append({"slot":building["slot"],"district":"building"})
	_blocked = snapshot["blocked"].duplicate()
	# Warm the canonical coordinates on the main thread before the worker reads them.
	HexGrid.coords(snapshot["slot_count"])
	request_generation()


func _bake_worker(request: Dictionary, cancellation: SpaceSurfaceBaker.Cancellation) -> void:
	var terrain: CityTerrainGenerator = CityTerrainGenerator.new(request["seed"],request["kind"])
	if not request.get("appearance",{}).is_empty() and not request.get("anchor",{}).is_empty():
		terrain = RegionTerrainGenerator.new(request["appearance"],request["anchor"])
	var layout: Dictionary = terrain.layout(request["sites"],request["blocked"],request["count"])
	var maps: Dictionary = terrain.bake(cancellation)
	_mutex.lock()
	_result = {"ticket":request["ticket"],"generator":terrain,"recipe":layout,"maps":maps}
	_mutex.unlock()


func _rebuild_city() -> void:
	if _city != null:
		for area: Area3D in slot_areas.values(): area.collision_layer = 0
		_city.queue_free()
	_city = Node3D.new(); _landscape.add_child(_city)
	slot_areas.clear(); _vehicles.clear(); _materials.clear()
	_windows = null; _steam = null
	_vegetation()
	_planner = Node3D.new(); _city.add_child(_planner)
	var parts: Array[Dictionary] = []
	var queued_parts: Array[Dictionary] = []
	var preview_parts: Array[Dictionary] = []
	var plan_lines: Array[Array] = []
	for site: Dictionary in recipe["slots"]:
		var at: Vector3 = site["at"]
		var assembly: Array[Dictionary] = []
		for district: Dictionary in snapshot["districts"]:
			if district["slot"] != site["slot"]: continue
			assembly = _district_parts(site,clampi(district["tier"]-1,0,2))
		for building: Dictionary in snapshot["buildings"]:
			if building["slot"] == site["slot"]: assembly = M1BuildingKit.build(building["id"],site["seed"])
		_translate(assembly,at,parts)
		for item: Dictionary in snapshot["queue"]:
			if item["slot"] != site["slot"]: continue
			var future: Array[Dictionary] = _future_parts(site,item)
			for part: Dictionary in future: part["role"] = "queued"
			_translate(future,at+Vector3(0,0.08,0),queued_parts)
		if ghost.get("slot",-1) == site["slot"] and site["kind"].is_empty() and not site["blocked"]:
			var future: Array[Dictionary] = _future_parts(site,ghost)
			for part: Dictionary in future: part["role"] = "preview" if ghost.get("valid",false) else "preview_invalid"
			_translate(future,at+Vector3(0,0.08,0),preview_parts)
		if site["blocked"]:
			for i: int in 7:
				var x: float = at.x+cos(i*2.3)*1.25; var z: float = at.z+sin(i*2.3)*1.25
				CityBuildingKit._part(parts,"rock","stone",Vector3(x,generator.height_at(x,z)+0.45,z),Vector3(1.6,1.25+i*0.12,1.3))
		var line: Array = []
		for corner: int in 7:
			var angle: float = corner*TAU/6.0+PI/6.0
			var x: float = at.x+cos(angle)*3.02; var z: float = at.z+sin(angle)*3.02
			line.append(Vector3(x,generator.height_at(x,z)+0.14,z))
		plan_lines.append(line)
		var area: Area3D = Area3D.new(); area.set_meta("slot",site["slot"]); area.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new(); var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(4.5,7 if site["blocked"] else (4 if not site["kind"].is_empty() else 0.35),4.5)
		shape.shape = box; area.position = at+Vector3(0,box.size.y*0.5-0.1,0)
		area.add_child(shape); _city.add_child(area); slot_areas[int(site["slot"])]=area
	var landmark_index: int = 0
	for building: Dictionary in snapshot["buildings"]:
		if building["slot"] >= 0: continue
		var at: Vector3 = _landmark_position(landmark_index)
		landmark_index += 1
		_translate(M1BuildingKit.build(building["id"],appearance_seed),at,parts)
	var roads: Array[Array] = []
	for edge: Vector2i in recipe["roads"]:
		var a: Vector3 = recipe["slots"][edge.x]["at"]; var b: Vector3 = recipe["slots"][edge.y]["at"]
		var line: Array = []
		for i: int in 17:
			var p: Vector3 = a.lerp(b,float(i)/16); p.y = generator.height_at(p.x,p.z)+0.075; line.append(p)
		roads.append(line)
	_lines(roads,0.31,_material("road"),_city)
	var plan_material: StandardMaterial3D = StandardMaterial3D.new()
	plan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; plan_material.albedo_color = Color("60c8ba")
	_lines(plan_lines,0.027,plan_material,_planner)
	_instances(parts,_city); _instances(queued_parts,_city); _instances(preview_parts,_city)
	_setup_vehicles(); _set_planning(planning)
	if selected_slot >= 0 and slot_areas.has(selected_slot): _highlight_selection()


func _future_parts(site: Dictionary, item: Dictionary) -> Array[Dictionary]:
	if item["kind"] == "building": return M1BuildingKit.build(item["id"],site["seed"])
	var future: Dictionary = site.duplicate(true); future["kind"] = item["id"]
	return _district_parts(future,clampi(int(item.get("tier",1))-1,0,2))


func _translate(assembly: Array[Dictionary], at: Vector3, into: Array[Dictionary]) -> void:
	for part: Dictionary in assembly:
		part["transform"] = Transform3D(Basis.IDENTITY,at)*part["transform"]
		into.append(part)


func _landmark_position(index: int) -> Vector3:
	var z: float = 10-index*19
	return Vector3(-16,generator.height_at(-16,z)+0.04,z)


func hover_text() -> String:
	if busy or not get_global_rect().has_point(get_global_mouse_position()): return ""
	var index: int = pick_slot(get_local_mouse_position())
	if index < 0: return ""
	var site: Dictionary = recipe["slots"][index]
	if site["blocked"]: return Strings.fmt("error.build.blocked_slot")
	for building: Dictionary in snapshot["buildings"]:
		if building["slot"] == index: return GameUI.name_of("buildings",building["id"])
	return GameUI.name_of("districts",site["kind"]) if site["kind"] != "" else Strings.fmt("ui.colony.slot_title")


func select_slot(index: int, emit_selection: bool = true) -> void:
	if busy or index < 0 or not slot_areas.has(index): return
	selected_slot = index
	_target = recipe["slots"][index]["at"]+Vector3(0,1,0)
	_distance = 22; _pitch = 0.65
	_highlight_selection()
	if emit_selection: selected.emit(index)


func _highlight_selection() -> void:
	var ring: Array = []
	var at: Vector3 = recipe["slots"][selected_slot]["at"]
	for corner: int in 7:
		var angle: float = corner*TAU/6.0+PI/6.0
		var x: float = at.x+cos(angle)*2.82; var z: float = at.z+sin(angle)*2.82
		ring.append(Vector3(x,generator.height_at(x,z)+0.20,z))
	for child: Node in _city.get_children():
		if child.name == "SelectionRing": child.queue_free()
	var root: Node3D = Node3D.new(); root.name = "SelectionRing"; _city.add_child(root)
	var mat: StandardMaterial3D = StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color("ffd37a")
	_lines([ring],0.05,mat,root)


func show_overview() -> void:
	selected_slot = -1; _target = Vector3(-1,2,2); _distance = 54; _pitch = 0.65; _yaw = 0.55
	if camera != null: _update_camera(1)


func _viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed: _dragging=true; _drag_pixels=0
			else:
				_dragging=false
				if _drag_pixels<8: select_slot(pick_slot(mouse.position))
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_distance=clampf(_distance*(0.9 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1),9,90)
	elif event is InputEventMouseMotion and _dragging:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_pixels+=mouse.relative.length(); _yaw-=mouse.relative.x*0.004; _pitch=clampf(_pitch+mouse.relative.y*0.003,0.28,1.15)
	_container.accept_event()


func _process(delta: float) -> void:
	_finish_job()
	if not motion_paused and not Settings.reduce_motion: visual_time+=minf(delta,0.1)
	if _water != null: _water.set_shader_parameter("visual_time",visual_time)
	if _leaves != null: _leaves.set_shader_parameter("visual_time",visual_time)
	for group_index: int in _vehicles.size():
		var multi: MultiMesh = _vehicles[group_index]
		for i: int in multi.instance_count:
			var edge: Vector2i = recipe["roads"][i]
			var a: Vector3 = recipe["slots"][edge.x]["at"]; var b: Vector3 = recipe["slots"][edge.y]["at"]
			var t: float = (sin(visual_time*0.19+i*1.7)+1)*0.5
			var at: Vector3 = a.lerp(b,t); at.y=generator.height_at(at.x,at.z)+0.20+(0.18 if group_index == 1 else 0)
			var basis: Basis = Basis.looking_at((b-a).normalized(),Vector3.UP)*Basis.from_scale(Vector3(0.36,0.18 if group_index == 0 else 0.09,0.62 if group_index == 0 else 0.34))
			multi.set_instance_transform(i,Transform3D(basis,at))
	_update_camera(1 if Settings.reduce_motion else 1-exp(-delta*5))


func _load_meshes() -> void:
	var kit: Node = (load("res://assets/3d/city_study/parts.glb") as PackedScene).instantiate()
	for child: Node in kit.find_children("*","MeshInstance3D",true,false):
		_meshes[str(child.name)] = (child as MeshInstance3D).mesh
	kit.free()
	_meshes["foliage"] = _foliage_mesh()
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 0.5; rock.height = 1.0; rock.radial_segments = 7; rock.rings = 4
	_meshes["rock"] = rock
	_meshes["steam"] = QuadMesh.new()



func _foliage_mesh() -> ArrayMesh:
	# Folded leaves give the canopy actual gaps and varied normals at close view.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = 8327
	var outline: Array[Vector2] = [Vector2(0,-0.55),Vector2(0.36,-0.22),Vector2(0.38,0.20),Vector2(0,0.55),Vector2(-0.38,0.20),Vector2(-0.36,-0.22)]
	for i: int in 70:
		var direction: Vector3 = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var at: Vector3 = direction * pow(rng.randf(),0.333) * 0.44
		var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf_range(-PI,PI),rng.randf_range(-PI,PI))) * Basis.from_scale(Vector3.ONE*rng.randf_range(0.16,0.24))
		for edge: int in outline.size():
			var a: Vector2 = outline[edge]; var b: Vector2 = outline[(edge+1)%outline.size()]
			var points: Array[Vector3] = [Vector3(0,0,0.07),Vector3(a.x,a.y,0),Vector3(b.x,b.y,0)]
			for point: Vector3 in points:
				surface.set_uv(Vector2(point.x+0.5,point.y+0.5))
				surface.add_vertex(at+basis*point)
	surface.generate_normals()
	return surface.commit()



func _environment_setup() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = _sky
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("9facba")
	_environment.ambient_light_energy = 0.42
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("97aebc")
	_environment.fog_density = 0.0018
	var node: WorldEnvironment = WorldEnvironment.new()
	node.environment = _environment
	_world.add_child(node)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-43,-34,0)
	_sun.light_energy = 1.3
	_sun.light_color = Color("fff1d9")
	_sun.shadow_enabled = true
	_sun.shadow_blur = 2.0
	_sun.directional_shadow_max_distance = 120
	_world.add_child(_sun)
	_apply_lighting()



func request_generation() -> void:
	_ticket += 1
	busy = true
	_queued = {"ticket": _ticket, "seed": appearance_seed, "kind": terrain_kind,
		"sites":_snapshot["districts"].duplicate(true),"blocked":_blocked.duplicate(),"count":_snapshot["count"],
		"appearance":snapshot.get("appearance",{}).duplicate(true),"anchor":snapshot.get("anchor",{}).duplicate(true)}
	if _cancellation != null: _cancellation.cancel()
	if generation != null and not snapshot.get("appearance",{}).is_empty():
		generation.cancel_owner(resource_owner)
		_region_key = CanonicalJson.stringify({"appearance":snapshot["appearance"],"anchor":snapshot["anchor"],"sites":_queued["sites"],"blocked":_blocked,"count":_snapshot["count"]}).sha256_text()
		generation.request_region(resource_owner,session_epoch,_region_key,snapshot["appearance"],snapshot["anchor"],_queued["sites"],_blocked,_snapshot["count"],64 if OS.has_feature("web") else 128)
		_queued.clear()
		return
	_start_job()



func _start_job() -> void:
	if _job >= 0 or _region_job != null or _queued.is_empty(): return
	var request: Dictionary = _queued.duplicate()
	_queued.clear()
	_cancellation = SpaceSurfaceBaker.Cancellation.new()
	if OS.has_feature("web") and not request.get("appearance",{}).is_empty():
		var terrain: RegionTerrainGenerator = RegionTerrainGenerator.new(request["appearance"],request["anchor"])
		_region_recipe = terrain.layout(request["sites"],request["blocked"],request["count"])
		_region_job = RegionBakeJob.new(terrain,64,_cancellation)
		_region_ticket = request["ticket"]
		return
	_job = WorkerThreadPool.add_task(_bake_worker.bind(request,_cancellation))



func _finish_job() -> void:
	if _region_job != null:
		var started: int = Time.get_ticks_usec()
		while not _region_job.step(1):
			if Time.get_ticks_usec()-started >= 1000: return
		if not _region_job.cancelled and _region_ticket == _ticket:
			generator = _region_job.terrain; recipe = _region_recipe
			_apply_terrain(_region_job.maps()); busy = false
		_region_job = null; _region_recipe = {}; _start_job()
		return
	if _job < 0 or not WorkerThreadPool.is_task_completed(_job): return
	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	_mutex.lock()
	var result: Dictionary = _result
	_result = {}
	_mutex.unlock()
	if result["ticket"] == _ticket and not result["maps"].is_empty():
		generator = result["generator"]
		recipe = result["recipe"]
		_apply_terrain(result["maps"])
		busy = false
		if selected_slot >= 0: select_slot(selected_slot,false)
	_start_job()



func _apply_terrain(maps: Dictionary) -> void:
	if _landscape != null:
		for area: Area3D in slot_areas.values(): area.collision_layer = 0
		_landscape.queue_free()
	_landscape = Node3D.new()
	_world.add_child(_landscape)
	_city = null
	_materials.clear()
	var material: ShaderMaterial = _ground_material()
	var chunks: Array = maps.get("chunks",[{"arrays":maps["arrays"]}])
	for chunk: Dictionary in chunks:
		var ground: MeshInstance3D = MeshInstance3D.new()
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,chunk["arrays"])
		ground.mesh = mesh; ground.material_override = material
		_landscape.add_child(ground)
	var sea: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(512,512)
	sea.mesh = plane
	_water = ShaderMaterial.new()
	_water.shader = WATER_SHADER
	_water.set_shader_parameter("height_map",ImageTexture.create_from_image(maps["heightmap"]))
	_water.set_shader_parameter("frozen",terrain_kind == "ice")
	_water.set_shader_parameter("toxic",terrain_kind == "toxic")
	sea.material_override = _water
	sea.visible = terrain_kind != "barren"
	_landscape.add_child(sea)
	_vegetation()
	_rebuild_city()



func _ground_material() -> ShaderMaterial:
	var material: ShaderMaterial=ShaderMaterial.new(); material.shader=GROUND_SHADER
	material.set_shader_parameter("rock_albedo",load("res://assets/textures/city_study/rock_albedo.png"))
	material.set_shader_parameter("rock_roughness",load("res://assets/textures/city_study/rock_roughness.png"))
	return material

func _material(role: String) -> Material:
	if _materials.has(role): return _materials[role]
	if role in ["queued","preview","preview_invalid"]:
		var ghost_material: StandardMaterial3D = StandardMaterial3D.new()
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_material.albedo_color = Color(0.20,0.60,0.95,0.28) if role == "queued" else Color(0.25,0.85,0.60,0.30) if role == "preview" else Color(0.95,0.23,0.15,0.30)
		_materials[role] = ghost_material
		return ghost_material
	var accents: Dictionary = {"ark": "397d7d", "meridian": "477fa6", "vael": "967ea5"}
	var colors: Dictionary = {"shell": "c3c5b8", "metal": "7c8a8b", "dark": "33424a", "stone": "9ca495", "soil": "6d573d", "crop": "4e7c43", "solar": "244457", "road": "736e60", "accent": accents[architecture]}
	var result: Material
	if role == "light":
		_windows = ShaderMaterial.new()
		_windows.shader = WINDOWS_SHADER
		_windows.set_shader_parameter("tint",Color("cdaee6") if architecture == "vael" else Color("f4c783"))
		_windows.set_shader_parameter("night_amount",1.0 if dusk else 0.0)
		result = _windows
	elif role == "steam":
		_steam = ShaderMaterial.new(); _steam.shader = STEAM_SHADER
		result = _steam
	elif role == "leaf":
		_leaves = ShaderMaterial.new(); _leaves.shader = FOLIAGE_SHADER
		_leaves.set_shader_parameter("tint",Color("435f3b"))
		result = _leaves
	elif role in ["glass", "trunk"]:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color("375b61") if role == "glass" else Color("617854") if role == "leaf" else Color("574a3b")
		mat.roughness = 0.22 if role == "glass" else 0.92
		if role == "glass":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.34
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.metallic = 0.1
		mat.vertex_color_use_as_albedo = role == "leaf"
		result = mat
	else:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BUILDING_SHADER
		var family: String = "metal" if role in ["metal","dark","solar","accent"] else "rock" if role in ["soil","stone","crop"] else "concrete"
		mat.set_shader_parameter("albedo_map",load("res://assets/textures/city_study/%s_albedo.png" % family))
		mat.set_shader_parameter("normal_map",load("res://assets/textures/city_study/%s_normal.png" % family))
		mat.set_shader_parameter("roughness_map",load("res://assets/textures/city_study/%s_roughness.png" % family))
		mat.set_shader_parameter("tint",Color(colors.get(role,"aab1a6")))
		mat.set_shader_parameter("metallic",0.65 if role in ["metal","solar"] else 0.0)
		mat.set_shader_parameter("roughness_scale",0.58 if role == "solar" else 1.0)
		result = mat
	_materials[role] = result
	return result



func _instances(parts: Array[Dictionary], parent: Node3D) -> void:
	var groups: Dictionary = {}
	for part: Dictionary in parts:
		var key: String = part["mesh"]+":"+part["role"]
		if not groups.has(key): groups[key] = []
		groups[key].append(part)
	for key: String in groups:
		var group: Array = groups[key]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = _meshes[group[0]["mesh"]]
		multi.instance_count = group.size()
		for i: int in group.size():
			multi.set_instance_transform(i,group[i]["transform"])
			multi.set_instance_color(i,group[i].get("color",Color.WHITE))
			multi.set_instance_custom_data(i,Color(float(i%8)/8.0,0,0,1))
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.set_meta("part_mesh",group[0]["mesh"])
		node.multimesh = multi
		node.material_override = _material(group[0]["role"])
		if group[0]["role"] in ["glass","steam","queued","preview","preview_invalid"]: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)



func _vegetation() -> void:
	if is_instance_valid(_vegetation_root): _vegetation_root.queue_free()
	_vegetation_root = Node3D.new(); _landscape.add_child(_vegetation_root)
	var parts: Array[Dictionary] = []
	for tree: Vector4 in recipe["trees"]:
		var obstructed: bool = false
		var temporary_sites: Array = snapshot["queue"].duplicate()
		if not ghost.is_empty(): temporary_sites.append(ghost)
		for site: Dictionary in temporary_sites:
			var index: int = int(site.get("slot",-1))
			if index < 0 or index >= recipe["slots"].size(): continue
			var at: Vector3 = recipe["slots"][index]["at"]
			if Vector2(tree.x-at.x,tree.z-at.z).length()<3.5: obstructed = true
		var landmark_index: int = 0
		for building: Dictionary in snapshot["buildings"]:
			if building["slot"] >= 0: continue
			var at: Vector3 = _landmark_position(landmark_index); landmark_index += 1
			var reach: Vector2 = Vector2(6,12) if building["id"] == "ark_hull" else Vector2(3.5,3.5)
			if absf(tree.x-at.x)<reach.x and absf(tree.z-at.z)<reach.y: obstructed = true
		if obstructed: continue
		var at: Vector3 = Vector3(tree.x,tree.y,tree.z)
		var scale_value: float = tree.w
		CityBuildingKit._part(parts,"cone","trunk",at+Vector3(0,scale_value,0),Vector3(0.13,scale_value*2,0.13))
		for i: int in 4:
			var angle: float = i*TAU/4.0
			CityBuildingKit._part(parts,"cylinder","trunk",at+Vector3(cos(angle)*0.22,1.5,sin(angle)*0.22)*scale_value,Vector3(0.044,0.90,0.044)*scale_value,Vector3(sin(angle)*-24,0,cos(angle)*24))
			CityBuildingKit._part(parts,"foliage","leaf",at+Vector3(cos(angle)*0.35,1.70+i*0.09,sin(angle)*0.35)*scale_value,Vector3(1.18,1.02,1.18)*scale_value)
			parts[-1]["color"] = Color(0.80+tree.w*0.13,0.82+tree.w*0.10,0.72+tree.w*0.10)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = appearance_seed+307
	for i: int in 95:
		var x: float = rng.randf_range(-60,60)
		var z: float = rng.randf_range(-55,28)
		if Vector2(x,z).length() < 21.0 or generator.height_at(x,z)<3.0: continue
		var size_value: float = rng.randf_range(0.35,1.0)
		CityBuildingKit._part(parts,"rock","stone",Vector3(x,generator.height_at(x,z)+size_value*0.3,z),Vector3(1.3,1.0,1.1)*size_value,Vector3(0,rng.randf_range(0,180),0))
	_instances(parts,_vegetation_root)



func _lines(lines: Array[Array], half_width: float, material: Material, parent: Node3D) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: Array in lines:
		for i: int in line.size()-1:
			var a: Vector3 = line[i]; var b: Vector3 = line[i+1]
			var side: Vector3 = Vector3(b.z-a.z,0,a.x-b.x).normalized()*half_width
			var corners: Array[Vector3] = [a-side,a+side,b-side,b+side]
			for corner: int in [0,1,2,1,3,2]:
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(corners[corner].x,corners[corner].z)*0.5)
				surface.add_vertex(corners[corner])
	if lines.is_empty(): return
	surface.generate_tangents()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit(); node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)



func _setup_vehicles() -> void:
	if recipe["roads"].is_empty(): return
	for role: String in ["shell","dark"]:
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes["box"]; multi.instance_count = mini(4,recipe["roads"].size())
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.multimesh = multi; node.material_override = _material(role)
		_city.add_child(node); _vehicles.append(multi)



func _set_planning(value: bool) -> void:
	planning = value
	if _planning_button != null: _planning_button.set_pressed_no_signal(value)
	if _planner == null: return
	_planner.visible = value
	for slot: Dictionary in recipe["slots"]:
		slot_areas[int(slot["slot"])].collision_layer = 1 if value or not slot["kind"].is_empty() or slot["blocked"] else 0



func _apply_lighting() -> void:
	if _dusk_button != null: _dusk_button.set_pressed_no_signal(dusk)
	_sun.light_energy = 0.19 if dusk else 1.3
	_sun.light_color = Color("c99575") if dusk else Color("fff1d9")
	_environment.ambient_light_energy = 0.27 if dusk else 0.42
	_sky.sky_top_color = Color("202a42") if dusk else Color("537e9d")
	_sky.sky_horizon_color = Color("6a6578") if dusk else Color("adbbc0")
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("373c44")
	_environment.fog_light_color = _sky.sky_horizon_color
	if _windows != null: _windows.set_shader_parameter("night_amount",1.0 if dusk else 0.0)



func _update_camera(weight: float) -> void:
	_look_at=_look_at.lerp(_target,weight); _current_distance=lerpf(_current_distance,_distance,weight)
	camera.position=_look_at+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_current_distance
	if generator != null: camera.position.y=maxf(camera.position.y,generator.height_at(camera.position.x,camera.position.z)+1.2)
	camera.look_at(_look_at)



func _exit_tree() -> void:
	if generation != null:
		generation.cancel_owner(resource_owner)
		generation.region_ready.disconnect(_region_ready)
	if _cancellation != null: _cancellation.cancel()
	if _job >= 0: WorkerThreadPool.wait_for_task_completion(_job)

func pick_slot(pointer: Vector2) -> int:
	var origin: Vector3=camera.project_ray_origin(pointer)
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(pointer)*300,1)
	query.collide_with_areas=true; query.collide_with_bodies=false
	var hit: Dictionary=_world.get_world_3d().direct_space_state.intersect_ray(query)
	return int(hit["collider"].get_meta("slot",-1)) if not hit.is_empty() else -1

func _district_parts(site: Dictionary, tier_index: int) -> Array[Dictionary]:
	return CityBuildingKitV2.build(site,architecture,tier_index,terrain_kind) if int(snapshot.get("city_kit_version",1))==2 else CityBuildingKit.build(site,architecture,tier_index,terrain_kind)
