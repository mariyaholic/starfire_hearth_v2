extends RefCounted
## The showcase passes the explanation and layout audit (§12) without a GPU: layout and text
## metrics work headless, so this catches raw ids, overlaps, clipping, broken words, small touch
## targets and unexplained numbers in the normal test job. The screenshot tour repeats it with
## real rendering and keeps the pictures.

const CASES: Array[Array] = [
	# [window size, phone profile, text scale, demo state]
	[Vector2i(1920, 1080), false, 1.0, "components"],
	[Vector2i(1920, 1080), false, 2.0, "tooltip"],
	[Vector2i(2400, 1080), true, 1.0, "tooltip"],
	[Vector2i(2400, 1080), true, 2.0, "components"],
	[Vector2i(2400, 1080), true, 2.0, "modal"],
]


func test_showcase_passes_audit(t: T) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Window = tree.root
	var settings: Node = root.get_node("Settings")
	var layout: Node = root.get_node("Layout")
	var overlay: Node = root.get_node("Overlay")
	var old_size: Vector2i = root.size
	settings.set("persist", false)
	settings.call("set_reduce_motion", true)
	for case: Array in CASES:
		root.size = case[0]
		settings.call("set_text_scale", float(case[2]))
		layout.call("set_profile", 2 if case[1] else 1)
		var scene: Control = (load("res://ui/screens/showcase/showcase.tscn") as PackedScene).instantiate()
		root.add_child(scene)
		for i in 4:
			await tree.process_frame
		await scene.call("demo", case[3])
		for i in 4:
			await tree.process_frame
		var view: Rect2 = Rect2(Vector2.ZERO, layout.get("logical_size"))
		var rep: IdAudit.AuditReport = IdAudit.run(root, overlay.get("root"), view, case[1])
		var label: String = "%s %s text %d%% %s" % [case[0], "phone" if case[1] else "pc", int(float(case[2]) * 100), case[3]]
		t.ok(rep.checked_labels > 10, "%s: audited %d labels" % [label, rep.checked_labels])
		for issue: Dictionary in rep.issues.slice(0, 5):
			t.fail("%s: %s %s | %s" % [label, issue["rule"], issue["detail"], issue["text"]])
		overlay.call("close_all")
		scene.queue_free()
		await tree.process_frame
	root.size = old_size
	settings.call("set_text_scale", 1.0)
	layout.call("set_profile", 0)
