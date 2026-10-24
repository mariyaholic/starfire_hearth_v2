class_name M11StageDProbe
extends Node
## Explicit review/test route only; save directory is isolated from player saves.
var app: AppRoot
var phase: String = "starting"
var action: String = ""
var study: M1VisualStudy
var expected_hash: String = ""
var error: String = ""
var _elapsed: float = 0.0

func start(owner: AppRoot) -> void:
 app = owner
 Settings.persist=false; Settings.set_hints_enabled(false); Settings.set_reduce_motion(true)
 Settings.set_appearance("3d"); Settings.set_visual_quality("low" if OS.has_feature("web") else "standard")
 SaveService.dir="user://stage_d_review"
 for i: int in 2: await get_tree().process_frame
 if FileAccess.file_exists(SaveService.dir.path_join("manual_1.json")):
  restore("manual_1")
 else: app.go(AppRoot.BEGIN,{"scenario":"s1_first_light","seed":11})
 for i: int in 6: await get_tree().process_frame
 Overlay.close_all(); show_system()
 phase="ready"; _publish()

func show_system() -> void:
 var screen: GameScreen = app.screen as GameScreen
 if screen != null:
  screen.show_view(GameScreen.SYSTEM)
  screen.world_controller.focus("pl_aster")

func restore(slot: String) -> void:
 var lr: SaveSerializer.LoadResult = SaveService.load_slot(slot)
 if not lr.ok: error=lr.error_key; return
 app.go(AppRoot.CONTINUE,{"state":lr.state,"presentation":lr.presentation,"presentation_overlay":lr.presentation_overlay})
 show_system()

func perform(request: String) -> void:
 action=""
 match request:
  "save":
   error=str(SaveService.save("manual_1",Game.state))
   phase="saved"
  "next_turn":
   expected_hash=TurnProcessor.run(GameState.from_dict(Game.state.to_dict()),[] as Array[Command]).state_hash
   Game.end_turn(); SaveService.autosave(Game.state); phase="turn_saved"
  "restore_manual":
   if is_instance_valid(study): study.close(); study=null
   restore("manual_1"); phase="restored"
  "region":
   Overlay.close_all()
   study=M1VisualStudy.make(app.screen as GameScreen,"colony"); Overlay.push(study)
   phase="region_requested"
  "close_region":
   if is_instance_valid(study): study.close()
   study=null; phase="closed_region"
  "future_compatible","future_unsupported":
   var wrapper: Dictionary = {"format":PresentationEnvelope.FORMAT,"version":77,"payload":"{\"future_float\":0.375,\"future_shader\":\"retain-exactly\"}","checksum":""}
   wrapper["checksum"]=str(wrapper["payload"]).sha256_text()
   if request == "future_compatible": wrapper["compatibility"]=PresentationEnvelope.pack(Worlds.appearances.data)
   var raw: String = JSON.stringify(wrapper)
   app.go(AppRoot.CONTINUE,{"state":Game.state,"presentation":raw})
   show_system()
   error=str(SaveService.save("future_review",Game.state))
   phase=request
  "restore_future":
   restore("future_review"); phase="future_restored"
 _publish()

func evidence() -> Dictionary:
 var store: AppearanceProfileStore = Worlds.appearances
 var colony: Colony = Game.state.colonies_of(Game.state.player_id)[0]
 var p: Dictionary = store.profile_for(colony.planet_id)
 var a: Dictionary = store.anchor_for(colony.id,colony.planet_id)
 var samples: Array[Dictionary] = []
 if not p.is_empty() and not a.is_empty():
  var terrain: RegionTerrainGenerator = RegionTerrainGenerator.new(p,a)
  for at: Vector2 in [Vector2.ZERO,Vector2(-112,112),Vector2(40,-60),Vector2(80,80),Vector2(-17,13)]:
   var global: Dictionary = terrain.global_sample(at.x,at.y)
   samples.append({"x":int(at.x),"z":int(at.y),"height_milli":roundi(terrain.raw_height(at.x,at.y)*1000),"elevation_ppm":roundi(global["elevation"]*1000000),"color":(global["color"] as Color).to_html(false)})
 var rendered_width: int = 0
 var screen: GameScreen = app.screen as GameScreen
 if screen != null and screen.world_controller.host.renderer != null:
  var renderer: M1SystemRenderer = screen.world_controller.host.renderer as M1SystemRenderer
  if renderer != null and renderer.bodies.has("pl_aster"): rendered_width=renderer.bodies["pl_aster"]["width"]
 var original: String = store.original
 return {"phase":phase,"error":error,"web":OS.has_feature("web"),"persistent_filesystem":OS.is_userfs_persistent(),
  "state_hash":Game.state.state_hash(),"expected_hash":expected_hash,"turn":Game.state.turn,
  "appearance_fingerprint":CanonicalJson.stringify(store.data).sha256_text(),"profile":p,"anchor":a,"samples":samples,
  "fallback":store.fallback,"notice":store.notice,"appearance_setting":Settings.appearance,"rendered_width":rendered_width,
  "future_original_sha256":original.sha256_text(),"future_saved_sha256":SaveService.load_slot("future_review").presentation.sha256_text() if FileAccess.file_exists(SaveService.dir.path_join("future_review.json")) else "",
  "region_ready":is_instance_valid(study) and is_instance_valid(study.renderer) and not study.renderer.get("busy"),
  "scheduler":Worlds.scheduler.metrics()}

func _publish() -> void:
 if OS.has_feature("web"): JavaScriptBridge.eval("window.__m11StageD = "+JSON.stringify(evidence()),true)

func _process(delta: float) -> void:
 if phase == "starting": return
 _elapsed+=delta
 if _elapsed<0.20: return
 _elapsed=0.0
 if OS.has_feature("web"):
  action=str(JavaScriptBridge.eval("window.__m11StageDAction || ''",true))
  if not action.is_empty(): JavaScriptBridge.eval("window.__m11StageDAction = ''",true)
 if not action.is_empty(): perform(action)
 if phase == "region_requested" and is_instance_valid(study) and not study.renderer.get("busy"): phase="region_ready"
 _publish()
