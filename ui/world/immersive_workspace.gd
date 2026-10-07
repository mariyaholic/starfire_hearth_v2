class_name ImmersiveWorkspace
extends RefCounted
## Device-local window layout, independent of campaign saves and appearance.
const PATH: String="user://immersive_workspace.cfg"
const VERSION: int=2
const KINDS: Array[String]=["summary","inspect","manage","queue","objects","tools","research","ordinances","market","objectives"]
static var _states: Dictionary={}
static var _loaded: bool=false

static func key(view: String,compact: bool) -> String:
	return view+(".compact" if compact else ".desktop")

static func defaults(view: String) -> Dictionary:
	return {"version":VERSION,"open":["summary"],"active":"summary","geometry":{},"docked":{},"minimized":{},"manage_tab":"overview","selection_seen":false}

static func load_layout(view: String,compact: bool,path: String=PATH) -> Dictionary:
	if not _loaded:
		_loaded=true
		var cfg: ConfigFile=ConfigFile.new()
		if Settings.persist and cfg.load(path)==OK:
			for section: String in cfg.get_sections():
				var value: Variant=cfg.get_value(section,"layout",{})
				if value is Dictionary: _states[section]=value.duplicate(true)
	var id: String=key(view,compact)
	if not _states.has(id): _states[id]=defaults(view)
	return sanitize(_states[id],view)

static func sanitize(value: Variant,view: String) -> Dictionary:
	if not value is Dictionary or value.get("version",VERSION) not in [1,VERSION]: return defaults(view)
	# Upgrade only uncustomized old defaults; retain player window arrangements.
	if value.get("version",VERSION)==1 and value.get("geometry",{}).is_empty() and value.get("docked",{}).is_empty() and value.get("minimized",{}).is_empty() and value.get("open",[]) in [["manage","queue","inspect"],["manage","inspect"]]: return defaults(view)
	var output: Dictionary=defaults(view)
	output["selection_seen"]=bool(value.get("selection_seen",false))
	if value.get("manage_tab") in ["overview","jobs","governor","shipyard"]: output["manage_tab"]=value["manage_tab"]
	if value.get("open") is Array:
		output["open"]=[]
		for kind: Variant in value["open"]:
			if kind is String and kind in KINDS and not output["open"].has(kind): output["open"].append(kind)
	if value.get("active") in output["open"]: output["active"]=value["active"]
	elif not output["open"].is_empty(): output["active"]=output["open"][-1]
	else: output["active"]=""
	for collection: String in ["geometry","docked","minimized"]:
		if value.get(collection) is Dictionary:
			for kind: String in KINDS:
				var item: Variant=value[collection].get(kind)
				if collection=="geometry":
					if item is Rect2 and item.position.is_finite() and item.size.is_finite() and item.size.x>0 and item.size.y>0:
						output[collection][kind]=Rect2(item.position.clamp(Vector2.ZERO,Vector2.ONE),item.size.clamp(Vector2(0.12,0.12),Vector2.ONE))
				elif item is bool: output[collection][kind]=item
	return output

static func save_layout(view: String,compact: bool,layout: Dictionary,path: String=PATH) -> void:
	var id: String=key(view,compact)
	var clean: Dictionary=sanitize(layout,view)
	# Keep fields from future writers even though this UI only consumes known ones.
	var stored: Dictionary=_states.get(id,{}).duplicate(true)
	for field: String in clean: stored[field]=clean[field]
	_states[id]=stored
	if not Settings.persist: return
	var cfg: ConfigFile=ConfigFile.new(); cfg.load(path)
	cfg.set_value(id,"layout",stored); cfg.save(path)
	if OS.has_feature("web"): _flush_web.call_deferred()

static func _flush_web() -> void:
	JavaScriptBridge.eval("if (typeof FS !== 'undefined' && FS.syncfs) FS.syncfs(false, function() {});",true)

static func default_rect(kind: String) -> Rect2:
	match kind:
		"summary": return Rect2(0.01,0.015,0.17,0.20)
		"manage": return Rect2(0.01,0.015,0.26,0.50)
		"queue": return Rect2(0.01,0.65,0.24,0.30)
		"inspect": return Rect2(0.78,0.63,0.21,0.34)
		"objects": return Rect2(0.70,0.20,0.29,0.66)
		"tools": return Rect2(0.30,0.18,0.38,0.64)
		_: return Rect2(0.02,0.06,0.38,0.68)

static func initial_rect(kind: String,bounds: Rect2,text_scale: float=1.0,expanded_inspector: bool=false) -> Rect2:
	var dimensions: Vector2={"summary":Vector2(290,178),"manage":Vector2(480,490),"queue":Vector2(380,260),"inspect":Vector2(370,520 if expanded_inspector else 290),"objects":Vector2(380,430),"tools":Vector2(440,560)}.get(kind,Vector2(540,580))
	dimensions*=sqrt(text_scale)
	var position: Vector2=bounds.position+Vector2(8,8)
	if kind=="inspect": position=bounds.end-dimensions-Vector2(8,8)
	elif kind=="queue": position=Vector2(bounds.position.x+8,bounds.end.y-dimensions.y-52)
	elif kind=="tools": position=Vector2(bounds.end.x-dimensions.x-8,bounds.position.y+8)
	return fit(Rect2(position,dimensions),bounds)

static func fit(rect: Rect2,bounds: Rect2,minimum: Vector2=Vector2(240,120)) -> Rect2:
	var size: Vector2=rect.size.clamp(minimum.min(bounds.size),bounds.size)
	var position: Vector2=rect.position.clamp(bounds.position,bounds.end-size)
	return Rect2(position,size)

static func toggle(layout: Dictionary,kind: String) -> void:
	if kind not in KINDS: return
	if layout["open"].has(kind) and layout.get("active")==kind and not layout["minimized"].get(kind,false):
		layout["open"].erase(kind)
		layout["active"]="" if layout["open"].is_empty() else layout["open"][-1]
	else:
		layout["open"].erase(kind); layout["open"].append(kind)
		layout["active"]=kind; layout["minimized"][kind]=false

static func reset_memory() -> void:
	_states.clear(); _loaded=false
