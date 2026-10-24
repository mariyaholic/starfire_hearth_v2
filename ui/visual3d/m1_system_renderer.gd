class_name M1SystemRenderer
extends Control

const PLANET_SHADER: Shader = preload("res://ui/map/shaders/planet_surface.gdshader")
const CLOUD_SHADER: Shader = preload("res://ui/map/shaders/cloud_layer.gdshader")
const ATMOSPHERE_SHADER: Shader = preload("res://ui/map/shaders/atmosphere.gdshader")
const STAR_SHADER: Shader = preload("res://ui/map/shaders/stellar_surface.gdshader")
const SKY_SHADER: Shader = preload("res://ui/map/shaders/space_sky.gdshader")
const CORONA_SHADER: Shader = preload("res://ui/map/shaders/star_corona.gdshader")
const RING_SHADER: Shader = preload("res://ui/map/shaders/planet_ring.gdshader")
const OVERVIEW_WIDTH: int = 256
const FOCUS_WIDTH: int = 1024
const CACHE_LIMIT: int = 8
const MAX_BAKES: int = 2

## Stage A proves the non-threaded export with the same resumable pixel algorithm.
var cooperative_bakes: bool = OS.has_feature("web")
var overview_width: int = OVERVIEW_WIDTH
var focus_width: int = FOCUS_WIDTH
var generation_slice_us: int = 2000
var render_scale_divisor: int = 1
var generation_samples: PackedInt64Array = PackedInt64Array()
var upload_samples: PackedInt64Array = PackedInt64Array()
var _incremental_job: SpaceSurfaceBaker.BakeJob
var _incremental_key: String = ""

var bodies: Dictionary[String, Dictionary] = {}
var selected_id: String = ""
var hovered_id: String = ""
var visual_time: float = 0.0
var motion_paused: bool = false
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var _container: SubViewportContainer
var _title: Label
var _description: Label
var _hover: Label
var _quality: Label
var _pause: CheckButton
var _sidebar: PanelContainer
var _top: PanelContainer
var _dust: MultiMeshInstance3D
var _sky_material: ShaderMaterial
var _target: Vector3 = Vector3(1, 0, 0)
var _look_at: Vector3 = Vector3(1, 0, 0)
var _distance: float = 28.0
var _current_distance: float = 28.0
var _yaw: float = 0.0
var _pitch: float = 0.40
var _dragging: bool = false
var _drag_pixels: float = 0.0
var _jobs: Dictionary[String, int] = {}
var _queued: Dictionary[String, Dictionary] = {}
var _cancellations: Dictionary[String, SpaceSurfaceBaker.Cancellation] = {}
var _results: Dictionary[String, Dictionary] = {}
var _mutex: Mutex = Mutex.new()
var _cache: Dictionary[String, Dictionary] = {}
var _cache_order: Array[String] = []
var generation: GenerationScheduler
var resources: VisualResourceCache
var session_epoch: int = 0
var resource_owner: String = ""
var _requests: Dictionary[String, String] = {}
var _input_blocked: bool = false
var _panning: bool = false
var _space_kit: SpaceObjectKit
var _touches: Dictionary[int, Vector2] = {}
var _pinch_distance: float = 0.0
var _multi_touch: bool = false
var _sky_elapsed: float = 0.0
var _orbit_paths: Dictionary[String, MeshInstance3D]={}
var _orbit_motion_start: Dictionary[String, Vector3]={}
var _orbit_motion_elapsed: float=1.0
var _orbit_motion_duration: float=0.72
var _display_orbital: Dictionary={}
var _initial_overview: bool=true

func bind_services(scheduler: GenerationScheduler, cache: VisualResourceCache, epoch: int, owner: String) -> void:
	generation = scheduler; resources = cache; session_epoch = epoch; resource_owner = owner
	generation.surface_ready.connect(_surface_ready)

func camera_state() -> Dictionary:
	return {"selected": selected_id, "target": _target, "distance": _distance, "yaw": _yaw, "pitch": _pitch,"paused":motion_paused}

func restore_camera(saved: Dictionary) -> void:
	if saved.is_empty(): return
	_initial_overview=false
	selected_id = saved.get("selected", "")
	if not selected_id.is_empty() and not bodies.has(selected_id): selected_id = ""
	_target = saved.get("target", Vector3(3,0,0))
	_distance = saved.get("distance", 29.0)
	_yaw = saved.get("yaw", 0.0); _pitch = saved.get("pitch", 0.48)
	motion_paused=saved.get("paused",false)
	_body_visibility(selected_id)
	_update_camera(1)
	if bodies.has(selected_id): request_surface(selected_id, focus_width)

func set_active(active: bool, input_blocked: bool) -> void:
	set_process(active)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE if input_blocked else Control.MOUSE_FILTER_STOP
	if input_blocked or not active: _dragging=false; _touches.clear(); _multi_touch=false; _pinch_distance=0; _panning=false
	_input_blocked = input_blocked

signal selected(id: String)
var snapshot: Dictionary = {}
var _identity: String = ""


func _ready() -> void:
	clip_contents = true
	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.stretch_shrink = render_scale_divisor
	_container.focus_mode = Control.FOCUS_ALL
	_container.gui_input.connect(_viewport_input)
	add_child(_container)
	viewport = SubViewport.new(); viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_2X
	_container.add_child(viewport)
	world = Node3D.new(); viewport.add_child(world)
	camera = Camera3D.new(); camera.fov = 44; camera.far = 500; world.add_child(camera)
	_environment()
	_space_kit = SpaceObjectKitV2.new() if int(snapshot.get("civilian_kit_version",1))==2 else SpaceObjectKit.new()
	if not snapshot.is_empty(): _build_map()
	show_overview()
	_finish_initial_overview.call_deferred()

func _finish_initial_overview() -> void:
	# Container layout is queued after _ready; a deferred call still sees zero width.
	if not is_inside_tree() or is_queued_for_deletion(): return
	var tree: SceneTree=get_tree()
	await tree.process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	await tree.process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	if _initial_overview and selected_id.is_empty(): show_overview()
	_initial_overview=false


func configure(description: Dictionary) -> void:
	var key: String = JSON.stringify(description)
	if key == _identity: return
	var old_turn: int=int(snapshot.get("turn",description.get("turn",0)))
	var old_positions: Dictionary={}
	for id: String in bodies:
		old_positions[id]=(bodies[id]["node"] as Node3D).position
	var previous_id: String = snapshot.get("id", "")
	_identity = key
	snapshot = description.duplicate(true)
	if not is_node_ready(): return
	if generation != null:
		if previous_id != snapshot.get("id", ""):
			generation.cancel_owner(resource_owner)
			resources.release_owner(resource_owner)
			_requests.clear()
			for body: Dictionary in bodies.values(): (body["node"] as Node3D).queue_free()
			bodies.clear()
		var permitted: Dictionary = {snapshot["id"]: true}
		for collection: String in ["planets", "ships", "outposts", "colonies", "systems"]:
			for entity: Dictionary in snapshot.get(collection, []): permitted[entity["id"]] = true
		for id: String in bodies.keys():
			if permitted.has(id): continue
			(bodies[id]["area"] as Area3D).collision_layer = 0
			(bodies[id]["node"] as Node3D).queue_free()
			resources.unpin(bodies[id].get("map_key", ""), resource_owner)
			bodies.erase(id)
		_build_map()
		if not selected_id.is_empty() and not bodies.has(selected_id): show_overview()
		_body_visibility(selected_id)
		_begin_orbit_transition(old_positions,old_turn)
		return
	for cancellation: SpaceSurfaceBaker.Cancellation in _cancellations.values(): cancellation.cancel()
	for job: int in _jobs.values(): WorkerThreadPool.wait_for_task_completion(job)
	_jobs.clear(); _queued.clear(); _cancellations.clear(); _results.clear()
	_incremental_job = null; _incremental_key = ""
	for body: Dictionary in bodies.values():
		(body["area"] as Area3D).collision_layer = 0
		(body["node"] as Node3D).queue_free()
	bodies.clear()
	_build_map()
	if bodies.has(selected_id): focus_body(selected_id,false)
	else: show_overview()
	_begin_orbit_transition(old_positions,old_turn)


func _build_map() -> void:
	if snapshot.is_empty(): return
	for old: Node in world.get_children():
		if old.name=="OrbitPaths": old.queue_free()
	_orbit_paths.clear()
	var star_radius: float = 0.62 if snapshot["spectral"] == "white_dwarf" else (1.95 if snapshot["spectral"] == "binary" else 1.65)
	_display_orbital=OrbitalLayout.display_recipe(snapshot.get("orbital_recipe",{}),snapshot["planets"],star_radius)
	var orbital: Dictionary=_display_orbital
	var moving: bool=not orbital.is_empty()
	var star_at: Vector3=Vector3.ZERO if moving else Vector3(-6,0,0)
	_add_body(snapshot["id"],snapshot["name_key"],"star",snapshot["seed"],star_at,star_radius,snapshot.get("appearance",{}))
	var positions: Dictionary = {}
	var orbit_root: Node3D=Node3D.new(); orbit_root.name="OrbitPaths"; world.add_child(orbit_root)
	var outer_orbit: float=0.0
	for i: int in snapshot["planets"].size():
		var planet: Dictionary = snapshot["planets"][i]
		var at: Vector3 = OrbitalLayout.position(orbital,planet["id"],int(snapshot.get("turn",0))) if moving else Vector3(-2.3+i*3.8,0,2.7 if i%2 == 0 else -2.4)
		if moving: _add_orbit_path(orbit_root,planet["id"],float(orbital.get("bodies",{}).get(planet["id"],{}).get("display_milli",2100))/1000.0)
		if moving: outer_orbit=maxf(outer_orbit,at.length())
		var radius: float = 1.55 if planet["kind"] == "gas_giant" else (0.65 if planet["kind"] == "barren" else 0.97)
		_add_body(planet["id"],planet["name_key"],planet["kind"],planet["seed"],at,radius,planet.get("appearance",{}))
		positions[planet["id"]] = at
	for i: int in snapshot["ships"].size():
		var ship: Dictionary = snapshot["ships"][i]
		var idle_at: Vector3 = Vector3(-3.5,0,4.6)
		var at: Vector3 = positions.get(ship["target"], idle_at)
		at += Vector3(1.5+i*0.85,0.3,1.2)
		var radius: float = 0.65 if ship["hull"] == "survey_probe" else (0.75 if ship["hull"] == "construction_ship" else 0.95)
		_add_body(ship["id"],ship["name_key"],"probe",0,at,radius)
		bodies[ship["id"]]["home"] = at
		if positions.has(ship["target"]):
			bodies[ship["id"]]["parent_planet"]=ship["target"]
			bodies[ship["id"]]["parent_offset"]=at-positions[ship["target"]]
	if generation != null:
		for outpost: Dictionary in snapshot.get("outposts", []):
			var at: Vector3 = positions.get(outpost["planet"], Vector3.ZERO) + Vector3(-1.3,0.5,1.0)
			_add_body(outpost["id"],outpost["name_key"],"outpost",0,at,0.55)
			bodies[outpost["id"]]["home"] = at
			bodies[outpost["id"]]["parent_planet"]=outpost["planet"]
			bodies[outpost["id"]]["parent_offset"]=at-positions.get(outpost["planet"],Vector3.ZERO)
		for colony: Dictionary in snapshot.get("colonies", []):
			var direction: Vector3 = RegionAnchor.mesh_direction(colony["anchor"]) if not colony.get("anchor",{}).is_empty() else Vector3(0,0.65,0.85).normalized()
			var radius: float = bodies[colony["planet"]]["radius"]
			var at: Vector3 = positions.get(colony["planet"], Vector3.ZERO) + direction.rotated(Vector3.UP,visual_time*0.035)*(radius+0.10)
			_add_body(colony["id"],colony["name_key"],"colony_marker",0,at,0.14)
			bodies[colony["id"]]["parent_planet"] = colony["planet"]
			bodies[colony["id"]]["anchor_direction"] = direction
	var star: ShaderMaterial = bodies[snapshot["id"]]["material"]
	var tints: Dictionary = {"M":"f5996c","K":"ffe1ad","G":"fff0cb","F":"f0f2ff","A":"cddcff","white_dwarf":"d8e6ff","binary":"ffe1ad"}
	star.set_shader_parameter("star_color",Color(tints.get(snapshot["spectral"],"fff0cb")))
	if moving and selected_id.is_empty() and outer_orbit>0: _distance=maxf(_distance,outer_orbit*1.55+8.0)
	_apply_orbit_visibility()

func _add_orbit_path(parent: Node3D,id: String,radius: float) -> void:
	var line: ImmediateMesh=ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point: Vector3 in OrbitalLayout.path_mesh(radius): line.surface_add_vertex(point+Vector3.UP*0.025)
	line.surface_end()
	var node: MeshInstance3D=MeshInstance3D.new(); node.name="Orbit_"+id; node.mesh=line
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color("87aebc",0.38)
	node.material_override=material; parent.add_child(node); _orbit_paths[id]=node

func _apply_orbit_visibility() -> void:
	for id: String in _orbit_paths:
		var node: MeshInstance3D=_orbit_paths[id]
		node.visible=Settings.orbit_visible and selected_id.is_empty()
		var material: StandardMaterial3D=node.material_override as StandardMaterial3D
		var selected: bool=id==selected_id
		material.albedo_color=Color("f5ce86" if selected else "87aebc",clampf(Settings.orbit_opacity*(0.78 if selected else 0.42),0.0,0.85))

func _begin_orbit_transition(previous: Dictionary,previous_turn: int) -> void:
	_orbit_motion_start.clear(); _orbit_motion_elapsed=1.0
	if Settings.reduce_motion or int(snapshot.get("turn",previous_turn))<=previous_turn: return
	for id: String in previous:
		if not bodies.has(id): continue
		if not _display_orbital.get("bodies",{}).has(id): continue
		_orbit_motion_start[id]=previous[id]
		(bodies[id]["node"] as Node3D).position=previous[id]
	if not _orbit_motion_start.is_empty(): _orbit_motion_elapsed=0.0


func focus_body(id: String, emit_selection: bool = true) -> void:
	if not bodies.has(id): return
	if bodies[id]["kind"] == "colony_marker" and emit_selection:
		selected.emit(id)
		return
	selected_id = id
	var body: Dictionary = bodies[id]
	_body_visibility(id)
	_target = (body["node"] as Node3D).position
	_distance = maxf(1.1,float(body["radius"])*3.8); _pitch = 0.2; _yaw = 0
	request_surface(id,focus_width)
	if Settings.reduce_motion: _update_camera(1)
	if emit_selection: selected.emit(id)


func show_overview() -> void:
	selected_id = ""; _body_visibility("")
	var lo: Vector3 = Vector3(INF,INF,INF); var hi: Vector3 = Vector3(-INF,-INF,-INF)
	for body: Dictionary in bodies.values():
		var extent: Vector3 = Vector3.ONE * float(body["radius"]) * (2.1 if body["kind"] == "gas_giant" else 1.15)
		var at: Vector3 = (body["node"] as Node3D).position
		lo = lo.min(at-extent); hi = hi.max(at+extent)
	_target = (lo+hi)*0.5 if not bodies.is_empty() else Vector3(3,0,0)
	_distance = maxf(20,(hi-lo).length()*1.1) if not bodies.is_empty() else 29
	_pitch = 0.95; _yaw = 0
	if not _display_orbital.get("bodies",{}).is_empty():
		var outer: float=0.0
		for id: String in _display_orbital["bodies"]:
			outer=maxf(outer,float(_display_orbital["bodies"][id].get("display_milli",0))/1000.0)
		var aspect: float=maxf(0.25,size.x/maxf(1.0,size.y))
		var tangent: float=tan(deg_to_rad(camera.fov*0.5))
		_target=Vector3.ZERO
		# Include the near-side perspective expansion, rings and associated markers.
		var bound: float=outer+3.5
		var vertical: float=bound*(sin(_pitch)/tangent+cos(_pitch))
		var horizontal: float=bound*sqrt(pow(1.0/(aspect*tangent),2.0)+pow(cos(_pitch),2.0))
		_distance=maxf(20.0,maxf(vertical,horizontal)*1.04)
	if camera != null: _update_camera(1)


func hover_text() -> String:
	if not get_global_rect().has_point(get_global_mouse_position()): return ""
	var id: String = pick_body(get_local_mouse_position())
	return Strings.fmt(bodies[id]["name_key"]) if bodies.has(id) else ""


func _viewport_input(event: InputEvent) -> void:
	if _input_blocked: return
	if event.device==-1 and (event is InputEventMouseButton or event is InputEventMouseMotion): return
	if event is InputEventKey:
		var key: InputEventKey=event as InputEventKey
		if not key.pressed or key.echo or key.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_HOME,KEY_PLUS,KEY_EQUAL,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT]: return
		if key.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var ids: Array=bodies.keys(); ids.sort()
			if not ids.is_empty():
				var index: int=ids.find(selected_id)
				var step: int=-1 if key.keycode in [KEY_LEFT,KEY_UP] else 1
				focus_body(ids[posmod(index+step,ids.size())])
		elif key.keycode==KEY_HOME: show_overview(); selected.emit("")
		elif key.keycode in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD]: _zoom(0.9)
		elif key.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]: _zoom(1.1)
		_container.accept_event(); return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning=mouse.pressed; _dragging=false; _drag_pixels=8
			_container.accept_event(); return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed: _dragging=true; _drag_pixels=0; _panning=mouse.shift_pressed
			else:
				_dragging=false
				if _drag_pixels<8 and not _panning:
					var id: String = pick_body(mouse.position)
					if not id.is_empty(): focus_body(id)
				_panning=false
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom(0.9 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
	elif event is InputEventMouseMotion and _panning:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_pixels+=mouse.relative.length()
		var right: Vector3 = Vector3(cos(_yaw),0,-sin(_yaw))
		var forward: Vector3 = Vector3(sin(_yaw),0,cos(_yaw))
		_target+=(-right*mouse.relative.x-forward*mouse.relative.y)*_distance/maxf(1,_container.size.y)
		_target.x=clampf(_target.x,-150,150); _target.z=clampf(_target.z,-150,150)
	elif event is InputEventMouseMotion and _dragging:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_pixels+=mouse.relative.length(); _yaw-=mouse.relative.x*0.004; _pitch=clampf(_pitch+mouse.relative.y*0.003,-0.7,1.2)
	elif event is InputEventMouseMotion:
		var id: String = pick_body((event as InputEventMouseMotion).position)
		_container.tooltip_text = Strings.fmt(bodies[id]["name_key"]) if bodies.has(id) else ""
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _touches.is_empty(): _multi_touch=false; _drag_pixels=0
			_touches[touch.index]=touch.position
			if _touches.size()>1: _multi_touch=true
		else:
			if not _multi_touch and _touches.size() == 1 and _drag_pixels < 8:
				var id: String = pick_body(touch.position)
				if not id.is_empty(): focus_body(id)
			_touches.erase(touch.index)
		_pinch_distance = _touch_span()
	elif event is InputEventScreenDrag:
		var touch: InputEventScreenDrag = event as InputEventScreenDrag
		_touches[touch.index] = touch.position; _drag_pixels += touch.relative.length()
		if _touches.size() >= 2:
			var distance: float = _touch_span()
			if distance > 1 and _pinch_distance > 1: _zoom(_pinch_distance / distance)
			_pinch_distance = distance
		else:
			_yaw -= touch.relative.x*0.004
			_pitch = clampf(_pitch+touch.relative.y*0.003,-0.7,1.2)
	_container.accept_event()

func _touch_span() -> float:
	if _touches.size() < 2: return 0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])

func _zoom(factor: float) -> void:
	var minimum: float = float(bodies[selected_id]["radius"])*2.4 if bodies.has(selected_id) else 5.0
	_distance = clampf(_distance*factor, minimum, 100)


func _process(delta: float) -> void:
	_finish_bakes()
	if _orbit_motion_elapsed<1.0:
		_orbit_motion_elapsed=minf(1.0,_orbit_motion_elapsed+delta/_orbit_motion_duration)
		var progress: float=1.0-pow(1.0-_orbit_motion_elapsed,3.0)
		for id: String in _orbit_motion_start:
			if not bodies.has(id): continue
			var target: Vector3=OrbitalLayout.position(_display_orbital,id,int(snapshot.get("turn",0)))
			var start: Vector3=_orbit_motion_start[id]
			var angle: float=lerp_angle(atan2(start.z,start.x),atan2(target.z,target.x),progress)
			var radius: float=lerpf(start.length(),target.length(),progress)
			(bodies[id]["node"] as Node3D).position=Vector3(cos(angle)*radius,0,sin(angle)*radius)
	if not motion_paused and not _input_blocked and not Settings.reduce_motion:
		visual_time+=minf(delta,0.1)
		for body: Dictionary in bodies.values():
			if body["mesh"] != null and body["kind"] != "probe": (body["mesh"] as MeshInstance3D).rotation.y=visual_time*0.035
			if body["cloud"] != null: (body["cloud"] as MeshInstance3D).rotation.y=visual_time*0.045
			if body["corona_material"] != null: (body["corona_material"] as ShaderMaterial).set_shader_parameter("visual_time",visual_time)
			if body.has("home"):
				(body["node"] as Node3D).position=body["home"]+Vector3(cos(visual_time*0.14)*0.15,0,sin(visual_time*0.14)*0.15)
		_sky_elapsed += delta
		if _sky_elapsed > 0.25:
			_sky_material.set_shader_parameter("visual_time",visual_time)
			_sky_elapsed = 0
	# Turn-driven parent motion continues when ambient effects are paused.
	for body: Dictionary in bodies.values():
		if body.has("anchor_direction") and bodies.has(body["parent_planet"]):
			var parent: Dictionary = bodies[body["parent_planet"]]
			(body["node"] as Node3D).position = (parent["node"] as Node3D).position + (body["anchor_direction"] as Vector3).rotated(Vector3.UP,visual_time*0.035)*(float(parent["radius"])+0.10)
		elif body.has("parent_planet") and bodies.has(body["parent_planet"]):
			body["node"].position=(bodies[body["parent_planet"]]["node"] as Node3D).position+body.get("parent_offset",Vector3.ZERO)
	if bodies.has(selected_id) and (bodies[selected_id]["kind"] == "probe" or _display_orbital.get("bodies",{}).has(selected_id)): _target=(bodies[selected_id]["node"] as Node3D).position
	_apply_orbit_visibility()
	_update_camera(1 if Settings.reduce_motion else 1-exp(-delta*5))
	if _space_kit is SpaceObjectKitV2:
		for id: String in bodies:
			if bodies[id]["kind"]!="probe": continue
			var level: int=0 if selected_id==id and _current_distance<4 else 1 if selected_id==id else 2
			for child: Node in (bodies[id]["node"] as Node3D).get_children():
				if child is Node3D: SpaceObjectKitV2.set_lod(child,level)


func _environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	if render_scale_divisor>1:
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	sky.sky_material = _sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("51627c")
	environment.ambient_light_energy = 0.08
	var node: WorldEnvironment = WorldEnvironment.new()
	node.environment = environment
	world.add_child(node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color("fff2dd")
	sun.light_energy = 1.65
	sun.rotation_degrees = Vector3(-22, -58, 0)
	sun.shadow_enabled = render_scale_divisor == 1
	world.add_child(sun)



func _add_body(id: String, name_key: String, kind: String, seed_value: int, at: Vector3, radius: float, appearance: Dictionary = {}) -> void:
	if bodies.has(id):
		var existing: Dictionary = bodies[id]
		if existing["kind"] == kind and existing["seed"] == seed_value and existing.get("appearance",{}) == appearance:
			(existing["node"] as Node3D).position = at
			return
		(existing["area"] as Area3D).collision_layer = 0
		(existing["node"] as Node3D).queue_free()
		if resources != null: resources.unpin(existing.get("map_key", ""), resource_owner)
		bodies.erase(id)
	var pivot: Node3D = Node3D.new()
	pivot.name = id
	pivot.position = at
	world.add_child(pivot)
	var mesh: MeshInstance3D = null
	var material: ShaderMaterial = ShaderMaterial.new()
	var cloud: MeshInstance3D = null
	var cloud_material: ShaderMaterial = null
	var corona_material: ShaderMaterial = null
	if kind == "asteroid_belt":
		_rocks(pivot, seed_value)
	elif kind == "probe":
		var hull: String = "survey_probe"
		for ship: Dictionary in snapshot.get("ships", []):
			if ship["id"] == id: hull = ship["hull"]
		pivot.add_child(_space_kit.ship(hull))
	elif kind == "outpost":
		var resource: String = ""
		for outpost: Dictionary in snapshot.get("outposts", []):
			if outpost["id"] == id: resource = outpost["resource"]
		pivot.add_child(_space_kit.outpost(resource))
	elif kind == "colony_marker":
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = _sphere(radius)
		var beacon: StandardMaterial3D = StandardMaterial3D.new()
		beacon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beacon.albedo_color = Color("a2dcc9")
		marker.material_override = beacon
		pivot.add_child(marker)
	else:
		mesh = MeshInstance3D.new()
		mesh.mesh = _sphere(radius)
		material.shader = STAR_SHADER if kind in ["star", "unknown"] else PLANET_SHADER
		if kind=="star" and int(snapshot.get("stellar_material_version",1))==2: material.shader=load("res://ui/art/shaders/star.gdshader")
		elif kind in SpaceSurfaceBaker.TYPES and int(snapshot.get("planet_material_version",1))==2: material.shader=load("res://ui/art/shaders/planet.gdshader")
		if kind == "gas_giant": material.set_shader_parameter("normal_depth",0.08)
		if kind == "star":
			material.set_shader_parameter("star_color", Color("ffe1ad"))
		mesh.material_override = material
		pivot.add_child(mesh)
		if kind == "star" and snapshot.get("spectral", "") == "binary":
			mesh.mesh = _sphere(radius*0.48); mesh.position.x = -radius*0.50
			var companion: MeshInstance3D = MeshInstance3D.new()
			companion.mesh = _sphere(radius*0.36); companion.position.x = radius*0.50
			companion.material_override = material
			pivot.add_child(companion)
		if kind == "unknown":
			material.set_shader_parameter("star_color",Color("9aa9b8"))
			var image: Image = Image.create(16,8,false,Image.FORMAT_RGB8); image.fill(Color(0.5,0.5,0.5))
			material.set_shader_parameter("photosphere",ImageTexture.create_from_image(image))
		if kind in ["continental", "ocean", "ice", "toxic", "arid"]:
			cloud = MeshInstance3D.new()
			cloud.mesh = _sphere(radius * 1.009)
			cloud_material = ShaderMaterial.new()
			cloud_material.shader = CLOUD_SHADER
			if kind == "toxic":
				cloud_material.set_shader_parameter("cloud_color", Color("b8b194"))
			cloud.material_override = cloud_material
			pivot.add_child(cloud)
		var atmosphere: MeshInstance3D = MeshInstance3D.new()
		atmosphere.mesh = _sphere(radius * 1.025)
		var atmosphere_material: ShaderMaterial = ShaderMaterial.new()
		atmosphere_material.shader = ATMOSPHERE_SHADER
		var tints: Dictionary = {"arid": "caaa8c", "gas_giant": "d1b79d", "toxic": "9e976c", "ice": "8dadc3"}
		atmosphere_material.set_shader_parameter("tint", Color(tints.get(kind, "418ac1")))
		atmosphere_material.set_shader_parameter("strength", 0.65)
		atmosphere.material_override = atmosphere_material
		if kind in SpaceSurfaceBaker.TYPES and kind != "barren":
			pivot.add_child(atmosphere)
		else:
			atmosphere.queue_free()
		if kind == "star":
			var corona: MeshInstance3D = MeshInstance3D.new()
			var plane: QuadMesh = QuadMesh.new()
			plane.size = Vector2.ONE * radius * 3.0
			corona.mesh = plane
			corona_material = ShaderMaterial.new()
			corona_material.shader = CORONA_SHADER
			corona.material_override = corona_material
			corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(corona)
		if kind == "gas_giant":
			var ring: MeshInstance3D = _planet_rings(radius)
			ring.rotation_degrees.z = 14
			ring.rotation_degrees.x = 12
			pivot.add_child(ring)
	var area: Area3D = Area3D.new()
	area.collision_layer = 1
	area.collision_mask = 0
	area.set_meta("body_id", id)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = maxf(radius * (2.1 if kind == "gas_giant" else 1.12), 0.32)
	shape.shape = sphere
	area.add_child(shape)
	pivot.add_child(area)
	bodies[id] = {"node": pivot, "area": area, "mesh": mesh, "material": material, "cloud": cloud, "cloud_material": cloud_material, "corona_material": corona_material, "seed": seed_value, "kind": kind, "radius": radius, "name_key": name_key, "width": 0}
	bodies[id]["appearance"] = appearance.duplicate(true)
	if kind in SpaceSurfaceBaker.TYPES or kind == "star":
		_apply_maps(id, _upload(_cheap_preview(kind,seed_value) if cooperative_bakes or generation != null else SpaceSurfaceBaker.bake(kind, seed_value, 32)))
		request_surface(id, overview_width)


func _cheap_preview(kind: String, seed_value: int) -> Dictionary:
	var images: Dictionary = {"width":16,"seed":seed_value,"kind":kind}
	var colors: Dictionary = {"albedo":Color("657b6f"),"surface":Color(0.5,1.0,0.8),"normal":Color(0.5,0.5,1.0),"clouds":Color.BLACK}
	var palette: Dictionary = {"continental":"657b6f","ocean":"214b69","arid":"b99369","ice":"bccfda","barren":"8a8378","toxic":"7c8660","gas_giant":"b69a7d","star":"8f7f6b"}
	colors["albedo"] = Color(palette.get(kind, "657b6f"))
	for channel: String in colors:
		var image: Image = Image.create(16,8,false,Image.FORMAT_RGB8)
		image.fill(colors[channel]); images[channel] = image
	return images



func _sphere(radius: float) -> SphereMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48 if render_scale_divisor>1 else 96
	sphere.rings = 24 if render_scale_divisor>1 else 48
	return sphere



func _planet_rings(radius: float) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in 129:
		var angle: float = float(i) / 128.0 * TAU
		for edge: int in 2:
			var distance: float = radius * (1.23 if edge == 0 else 2.1)
			vertices.append(Vector3(cos(angle), 0, sin(angle)) * distance)
			normals.append(Vector3.UP)
			uv.append(Vector2(edge, float(i) / 128.0))
		if i < 128:
			var at: int = i * 2
			indices.append_array(PackedInt32Array([at, at+1, at+2, at+1, at+3, at+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = RING_SHADER
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node



func _rocks(parent: Node3D, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var finished: bool=int(snapshot.get("planet_material_version",1))==2
	var material: Material
	if finished:
		material=FinishMaterials.surface("stone")
	else:
		var legacy: StandardMaterial3D=StandardMaterial3D.new()
		legacy.albedo_color=Color("8a8278"); legacy.roughness=0.95
		material=legacy
	for i: int in 36:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = rng.randf_range(0.045, 0.13)
		mesh.height = mesh.radius * 1.6
		mesh.radial_segments = 10 if finished else 5
		mesh.rings = 5 if finished else 3
		rock.mesh = mesh
		rock.material_override = material
		var a: float = TAU * i / 36
		rock.position = Vector3(cos(a), rng.randf_range(-0.15, 0.15), sin(a)) * rng.randf_range(0.6, 1.1)
		parent.add_child(rock)



func _probe_mesh(parent: Node3D) -> void:
	for i: int in 3:
		var node: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.15, 0.15, 0.4) if i == 0 else Vector3(0.4, 0.025, 0.24)
		node.mesh = box
		node.position.x = 0.0 if i == 0 else (-0.30 if i == 1 else 0.30)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color("ceb898") if i == 0 else Color("315979")
		mat.metallic = 0.3
		mat.roughness = 0.38
		node.material_override = mat
		parent.add_child(node)



func request_surface(id: String, width: int) -> void:
	if not bodies.has(id): return
	var body: Dictionary = bodies[id]
	if not (body["kind"] in SpaceSurfaceBaker.TYPES or body["kind"] == "star"):
		return
	_queued.erase(id)
	if int(body["width"]) >= width:
		return
	if generation != null:
		var shared_key: String = id + ":" + SpaceSurfaceBaker.cache_key(body["kind"], body["seed"], width, body.get("appearance",{}))
		resources.pin(shared_key, resource_owner)
		var cached: Dictionary = resources.get_maps(shared_key, session_epoch)
		if not cached.is_empty():
			_apply_shared(id, shared_key, cached)
			return
		_requests[shared_key] = id
		generation.request(resource_owner, session_epoch, shared_key, body["kind"], body["seed"], width, 0 if id == selected_id else 10, body.get("appearance",{}))
		return
	var key: String = SpaceSurfaceBaker.cache_key(body["kind"], body["seed"], width)
	if key == _incremental_key: return
	if _cache.has(key):
		_cache_order.erase(key)
		_cache_order.append(key)
		_apply_maps(id, _cache[key])
		return
	if _jobs.has(key):
		return
	_queued[id] = {"key": key, "kind": body["kind"], "seed": body["seed"], "width": width}
	_start_bakes()



func _start_bakes() -> void:
	if cooperative_bakes and _incremental_job != null: return
	var ids: Array = _queued.keys()
	# A focused world gets the next free worker ahead of overview refinements.
	if ids.has(selected_id):
		ids.erase(selected_id)
		ids.push_front(selected_id)
	for id: String in ids:
		if _jobs.size() >= MAX_BAKES:
			break
		var request: Dictionary = _queued[id]
		_queued.erase(id)
		var key: String = request["key"]
		if _jobs.has(key):
			continue
		var cancellation: SpaceSurfaceBaker.Cancellation = SpaceSurfaceBaker.Cancellation.new()
		_cancellations[key] = cancellation
		if cooperative_bakes:
			_incremental_key = key
			_incremental_job = SpaceSurfaceBaker.BakeJob.new(request["kind"],request["seed"],request["width"],cancellation)
			return
		else:
			_jobs[key] = WorkerThreadPool.add_task(_bake_worker.bind(key, request["kind"], request["seed"], request["width"], cancellation))



func _bake_worker(key: String, kind: String, seed_value: int, width: int, cancellation: SpaceSurfaceBaker.Cancellation) -> void:
	var result: Dictionary = SpaceSurfaceBaker.bake(kind, seed_value, width, cancellation)
	_mutex.lock()
	_results[key] = result
	_mutex.unlock()



func _upload(images: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = {"width": images["width"], "seed": images["seed"], "kind": images["kind"], "appearance_key":images.get("appearance_key","")}
	for channel: String in ["albedo", "surface", "normal", "clouds"]:
		var image: Image = images[channel]
		image.generate_mipmaps()
		result[channel] = ImageTexture.create_from_image(image)
	upload_samples.append(Time.get_ticks_usec()-started)
	if upload_samples.size()>1024: upload_samples.remove_at(0)
	return result



func _finish_bakes() -> void:
	if generation != null: return
	if cooperative_bakes:
		_advance_incremental()
		return
	for key: String in _jobs.keys():
		if not WorkerThreadPool.is_task_completed(_jobs[key]):
			continue
		WorkerThreadPool.wait_for_task_completion(_jobs[key])
		_jobs.erase(key)
		_cancellations.erase(key)
		_mutex.lock()
		var images: Dictionary = _results[key]
		_results.erase(key)
		_mutex.unlock()
		var maps: Dictionary = _upload(images)
		_cache[key] = maps
		_cache_order.append(key)
		while _cache_order.size() > CACHE_LIMIT:
			_cache.erase(_cache_order.pop_front())
		for id: String in bodies:
			var body: Dictionary = bodies[id]
			if body["seed"] == maps["seed"] and body["kind"] == maps["kind"] and body["width"] <= maps["width"]:
				_apply_maps(id, maps)
		break # One upload per frame, even when several worker tasks finish together.
	_start_bakes()


func _advance_incremental() -> void:
	if _incremental_job == null:
		_start_bakes()
		return
	var started: int = Time.get_ticks_usec()
	while not _incremental_job.step(1):
		if Time.get_ticks_usec()-started>=generation_slice_us: break
	generation_samples.append(Time.get_ticks_usec()-started)
	if generation_samples.size()>1024: generation_samples.remove_at(0)
	if not _incremental_job.done and not _incremental_job.cancelled: return
	var key: String = _incremental_key
	var images: Dictionary = _incremental_job.maps()
	_incremental_job = null; _incremental_key = ""
	_cancellations.erase(key)
	if not images.is_empty():
		var maps: Dictionary = _upload(images)
		_cache[key] = maps; _cache_order.append(key)
		while _cache_order.size()>CACHE_LIMIT: _cache.erase(_cache_order.pop_front())
		for id: String in bodies:
			var body: Dictionary = bodies[id]
			if body["seed"]==maps["seed"] and body["kind"]==maps["kind"] and body["width"]<=maps["width"]:
				_apply_maps(id,maps)
	_start_bakes()


func cache_texture_bytes_estimate() -> int:
	if resources != null: return resources.bytes
	var total: int = 0
	for maps: Dictionary in _cache.values():
		var image: Texture2D = maps["albedo"]
		# Four GPU channels, conservatively RGBA8, with full mip chains.
		total += image.get_width()*image.get_height()*16*4/3
	return total

func _surface_ready(owner: String, epoch: int, key: String, images: Dictionary) -> void:
	if owner != resource_owner or epoch != session_epoch or not _requests.has(key): return
	var id: String = _requests[key]
	_requests.erase(key)
	if not bodies.has(id) or bodies[id]["seed"] != images["seed"] or bodies[id]["kind"] != images["kind"]:
		resources.unpin(key, resource_owner)
		return
	if images.get("appearance_key","") != PlanetFieldGenerator.key(bodies[id].get("appearance",{})):
		resources.unpin(key,resource_owner)
		return
	if int(bodies[id]["width"]) > int(images["width"]):
		resources.unpin(key, resource_owner)
		return
	var maps: Dictionary = _upload(images)
	resources.put(key, maps, int(images["width"])*int(images["width"])/2*16*4/3, epoch)
	_apply_shared(id, key, maps)

func _apply_shared(id: String, key: String, maps: Dictionary) -> void:
	var previous_key: String = bodies[id].get("map_key", "")
	_apply_maps(id, maps)
	bodies[id]["map_key"] = key
	if previous_key != key: resources.unpin(previous_key, resource_owner)



func _apply_maps(id: String, maps: Dictionary) -> void:
	var body: Dictionary = bodies[id]
	var material: ShaderMaterial = body["material"]
	if body["kind"] == "star":
		material.set_shader_parameter("photosphere", maps["albedo"])
	else:
		material.set_shader_parameter("albedo_map", maps["albedo"])
		material.set_shader_parameter("surface_map", maps["surface"])
		material.set_shader_parameter("normal_map", maps["normal"])
		if body["cloud_material"] != null:
			(body["cloud_material"] as ShaderMaterial).set_shader_parameter("cloud_map", maps["clouds"])
	body["width"] = maps["width"]



func _update_camera(weight: float) -> void:
	_look_at = _look_at.lerp(_target, weight)
	_current_distance = lerpf(_current_distance, _distance, weight)
	var offset: Vector3 = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _current_distance
	camera.position = _look_at + offset
	camera.look_at(_look_at)



func _body_visibility(focused: String) -> void:
	for id: String in bodies:
		var visible_body: bool = focused.is_empty() or focused == id or bodies[id].get("parent_planet", "") == focused
		(bodies[id]["node"] as Node3D).visible = visible_body
		(bodies[id]["area"] as Area3D).collision_layer = 1 if visible_body else 0



func pick_body(screen_position: Vector2) -> String:
	screen_position *= Vector2(viewport.size)/size
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * 200.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(hit["collider"].get_meta("body_id", "")) if not hit.is_empty() else ""



func _exit_tree() -> void:
	if generation != null:
		generation.surface_ready.disconnect(_surface_ready)
		generation.cancel_owner(resource_owner)
		resources.release_owner(resource_owner)
		return
	for cancellation: SpaceSurfaceBaker.Cancellation in _cancellations.values():
		cancellation.cancel()
	for task: int in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(task)
