extends SceneTree
const OUT: String = "res://screens/m11_stage_d"
var checks: T = T.new()
var captures: Array[String] = []
var probe: Variant
var app: Variant
var game: Node
var worlds: Node
var settings: Node

func _initialize() -> void:
 _run.call_deferred()

func _frames(count: int) -> void:
 for i: int in count: await process_frame

func _until(predicate: Callable, timeout: int = 120) -> void:
 var start: int = Time.get_ticks_msec()
 while not predicate.call() and Time.get_ticks_msec()-start < timeout*1000: await process_frame
 checks.ok(predicate.call(),"requested visual completes")

func _capture(name: String) -> void:
 await _frames(3); await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT.path_join(name+".png"))
 captures.append(name+".png")

func _run() -> void:
 var catcher: Logger = (load("res://tools/m11_stage_c_smoke.gd") as GDScript).ErrorCatcher.new()
 OS.add_logger(catcher)
 game=root.get_node("Game"); worlds=root.get_node("Worlds"); settings=root.get_node("Settings")
 root.size=Vector2i(1920,1080); root.get_node("Layout").call("set_profile",1)
 DirAccess.make_dir_recursive_absolute(OUT); FileAccess.open(OUT.path_join(".gdignore"),FileAccess.WRITE).close()
 app=(load("res://ui/screens/app_root.tscn") as PackedScene).instantiate(); root.add_child(app)
 probe=(load("res://ui/world/stage_d_probe.gd") as GDScript).new(); app.add_child(probe)
 # Isolated review directory; delete only this tool's earlier captures/save slots.
 var review_dir: String = "user://stage_d_review"
 if DirAccess.dir_exists_absolute(review_dir):
  for file: String in DirAccess.open(review_dir).get_files(): DirAccess.remove_absolute(review_dir.path_join(file))
 await probe.start(app)
 await _until(func() -> bool: return probe.evidence()["rendered_width"] >= 1024)
 var initial: Dictionary = probe.evidence()
 await _capture("01_globe_before_save")
 probe.perform("save"); checks.eq(probe.error,"0")
 probe.perform("region"); await _until(func() -> bool: return probe.evidence()["region_ready"])
 checks.eq(probe.study.renderer.recipe["anchor"],initial["anchor"])
 checks.eq(probe.evidence()["samples"],initial["samples"])
 await _capture("02_saved_region_before_reload")
 probe.perform("restore_manual"); await _frames(8); root.get_node("Overlay").call("close_all")
 await _until(func() -> bool: return probe.evidence()["rendered_width"] >= 1024)
 checks.eq(probe.evidence()["appearance_fingerprint"],initial["appearance_fingerprint"])
 checks.eq(probe.evidence()["state_hash"],initial["state_hash"])
 checks.eq(probe.evidence()["samples"],initial["samples"])
 await _capture("03_globe_after_reload")
 probe.perform("region"); await _until(func() -> bool: return probe.evidence()["region_ready"])
 await _capture("04_same_region_after_reload")
 probe.perform("restore_manual"); await _frames(6); root.get_node("Overlay").call("close_all")
 probe.perform("next_turn"); checks.eq(game.call("view").state_hash(),probe.expected_hash)
 checks.eq(probe.evidence()["anchor"],initial["anchor"])
 checks.eq(probe.evidence()["samples"],initial["samples"])
 probe.perform("future_compatible"); await _frames(8); root.get_node("Overlay").call("close_all")
 await _until(func() -> bool: return probe.evidence()["rendered_width"]>=1024)
 checks.not_ok(worlds.get("appearances").get("fallback"))
 checks.eq(probe.evidence()["future_original_sha256"],probe.evidence()["future_saved_sha256"])
 await _capture("05_future_save_compatible_view")
 probe.perform("future_unsupported"); await _frames(8)
 checks.ok(worlds.get("appearances").get("fallback")); checks.eq(settings.get("appearance"),"strategic")
 checks.eq(probe.evidence()["future_original_sha256"],probe.evidence()["future_saved_sha256"])
 await _capture("06_future_save_strategic_fallback")
 probe.perform("restore_future"); await _frames(6)
 checks.ok(worlds.get("appearances").get("fallback"))
 var future: Dictionary = probe.evidence()
 probe.perform("restore_manual"); await _frames(6); root.get_node("Overlay").call("close_all")
 var final: Dictionary = probe.evidence()
 app.queue_free(); await _frames(5)
 root.get_node("Worlds").call("restart"); await _frames(4)
 root.get_node("Audio").queue_free(); await create_timer(0.15).timeout
 for error: String in catcher.call("take"): checks.fail(error)
 OS.remove_logger(catcher)
 var result: Dictionary = {"checks":checks.checks,"failures":checks.failures,"initial":initial,"final":final,"future":future,"captures":captures}
 FileAccess.open(OUT.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print(JSON.stringify(result))
 quit(0 if checks.failures.is_empty() else 1)
