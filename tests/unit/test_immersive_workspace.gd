extends RefCounted

func test_workspace_defaults_sanitize_and_fit_to_reachable_bounds(t: T) -> void:
	var desktop: Dictionary=ImmersiveWorkspace.defaults("colony")
	t.eq(desktop["open"],["summary"],"default leaves the map open and detailed windows available on demand")
	var clean: Dictionary=ImmersiveWorkspace.sanitize({"version":1,"open":["inspect","future","inspect"],"active":"inspect","geometry":{"inspect":Rect2(-5,0,4,4)}},"system")
	t.eq(clean["open"],["inspect"],"unknown and duplicate window kinds are dropped")
	t.eq(clean["geometry"]["inspect"],Rect2(Vector2.ZERO,Vector2.ONE),"saved proportions clamp inside screen and upper bound")
	t.eq(ImmersiveWorkspace.sanitize({"version":999},"galaxy"),ImmersiveWorkspace.defaults("galaxy"),"unknown layout version returns usable defaults")
	var fit: Rect2=ImmersiveWorkspace.fit(Rect2(-20,-30,2000,900),Rect2(100,50,900,600),Vector2(240,120))
	t.eq(fit,Rect2(100,50,900,600),"a window remains fully reachable when the viewport shrinks")

func test_workspace_toggle_and_persistence_keep_future_fields(t: T) -> void:
	ImmersiveWorkspace.reset_memory()
	var path: String="user://test_immersive_workspace.cfg"
	var layout: Dictionary=ImmersiveWorkspace.defaults("system")
	ImmersiveWorkspace.toggle(layout,"tools")
	t.eq(layout["active"],"tools"); t.ok(layout["open"].has("tools"))
	ImmersiveWorkspace.toggle(layout,"tools")
	t.not_ok(layout["open"].has("tools"),"toggling the active open window closes it")
	var cfg: ConfigFile=ConfigFile.new()
	var key: String=ImmersiveWorkspace.key("system",false)
	cfg.set_value(key,"layout",{"version":1,"open":["manage"],"active":"manage","future_setting":"keep"})
	cfg.save(path)
	ImmersiveWorkspace._loaded=false; ImmersiveWorkspace._states.clear()
	var loaded: Dictionary=ImmersiveWorkspace.load_layout("system",false,path)
	ImmersiveWorkspace.save_layout("system",false,loaded,path)
	var readback: ConfigFile=ConfigFile.new(); readback.load(path)
	t.eq(readback.get_value(key,"layout",{}).get("future_setting"),"keep","newer workspace fields survive older UI saves")
	DirAccess.remove_absolute(path); ImmersiveWorkspace.reset_memory()

func test_old_default_windows_upgrade_but_player_geometry_is_retained(t: T) -> void:
	var old: Dictionary={"version":1,"open":["manage","queue","inspect"],"active":"inspect","geometry":{},"docked":{},"minimized":{}}
	t.eq(ImmersiveWorkspace.sanitize(old,"colony")["open"],["summary"])
	old["geometry"]={"manage":Rect2(0.1,0.1,0.3,0.4)}
	var migrated: Dictionary=ImmersiveWorkspace.sanitize(old,"colony")
	t.eq(migrated["open"],old["open"],"custom layouts keep their windows")
	t.eq(migrated["geometry"],old["geometry"],"custom geometry survives version upgrade")
	var bounds: Rect2=Rect2(0,0,1920,960)
	var summary: Rect2=ImmersiveWorkspace.initial_rect("summary",bounds)
	var inspector: Rect2=ImmersiveWorkspace.initial_rect("inspect",bounds)
	t.ok((summary.get_area()+inspector.get_area())/bounds.get_area()<0.20,"ordinary default edge cards occupy less than one fifth of the desktop scene")

func test_finish_preferences_roundtrip_and_retain_unknown_settings(t: T) -> void:
	var settings: Node=load("res://app/settings.gd").new(); settings.persist=false
	settings.set_interface_finish("glossy")
	t.eq(settings.interface_opacity,0.75); t.eq(settings.interface_gloss,0.25)
	settings.set_interface_opacity(0.1); settings.set_interface_blur(100); settings.set_interface_gloss(-1)
	t.eq(settings.interface_opacity,0.70); t.eq(settings.interface_blur,16.0); t.eq(settings.interface_gloss,0.0)
	var path: String="user://test_interface_preferences.cfg"
	var cfg: ConfigFile=ConfigFile.new(); cfg.set_value("interface","future_field","retained"); cfg.save(path)
	settings._save(path)
	var restored: Node=load("res://app/settings.gd").new(); restored.persist=false; restored._load(path)
	t.eq(restored.interface_finish,"glossy"); t.eq(restored.interface_opacity,0.70)
	cfg.load(path); t.eq(cfg.get_value("interface","future_field"),"retained")
	settings.set_interface_finish("frosted"); t.eq(settings.interface_blur,8.0)
	settings.set_interface_finish("invalid"); t.eq(settings.interface_finish,"frosted")
	settings.free(); restored.free(); DirAccess.remove_absolute(path)
