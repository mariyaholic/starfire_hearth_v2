extends RefCounted

const RETIREMENT: GDScript = preload("res://ui/visual3d/sky_retirement.gd")
const AUDIO: GDScript = preload("res://app/audio.gd")


func test_sky_created_during_post_draw_survives_until_its_own_draw(t: T) -> void:
	# Headless has no render boundary; its explicit bypass is checked below.
	if DisplayServer.get_name() == "headless": return
	while RETIREMENT.has_pending(): await RenderingServer.frame_post_draw
	var late: Array[WeakRef] = []
	var create_late: Callable = func() -> void:
		var sky: Sky = Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		RETIREMENT.retain(sky)
		late.append(weakref(sky))
	# This listener runs before the retirement callback for the earlier sky.
	RenderingServer.frame_post_draw.connect(create_late, CONNECT_ONE_SHOT)
	var earlier: Sky = Sky.new()
	earlier.sky_material = ProceduralSkyMaterial.new()
	RETIREMENT.retain(earlier)
	earlier = null
	await RenderingServer.frame_post_draw
	t.eq(late.size(), 1)
	t.ok(late[0].get_ref() != null, "a sky created after this draw must survive it")
	t.ok(RETIREMENT.has_pending(), "new sky still needs a rendering boundary")
	await RenderingServer.frame_post_draw
	t.eq(late[0].get_ref(), null, "new sky releases after a subsequent draw")
	t.not_ok(RETIREMENT.has_pending())


func test_sky_lifetime_reaches_draw_boundary(t: T) -> void:
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var reference: WeakRef = weakref(sky)
	RETIREMENT.retain(sky)
	RETIREMENT.retain(sky)
	sky = null
	if DisplayServer.get_name() == "headless":
		t.eq(reference.get_ref(), null, "headless has no renderer to wait for")
		t.not_ok(RETIREMENT.has_pending())
	else:
		t.ok(reference.get_ref() != null, "sky remains alive until the renderer draws")
		t.eq(RETIREMENT._pending.size(), 1, "repeated retirement is deduplicated")
		await RenderingServer.frame_post_draw
		# The draw counter advances after this signal on the compatibility renderer.
		if reference.get_ref() != null: await RenderingServer.frame_post_draw
		t.eq(reference.get_ref(), null, "sky is released within two draw boundaries")
		t.not_ok(RETIREMENT.has_pending())


func test_audio_shutdown_is_idempotent_and_blocks_new_sounds(t: T) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = AUDIO.new()
	tree.root.add_child(audio)
	audio.play_music("mus_title")
	audio.play_voice("test", AudioStreamWAV.new())
	if DisplayServer.get_name() != "headless":
		t.ok(audio._playbacks_pending(), "active playback is tracked before shutdown")
	audio._begin_shutdown()
	audio._begin_shutdown()
	t.eq(audio.current_track(), null)
	t.eq(audio.voice_utterance, "")
	if DisplayServer.get_name() == "headless":
		t.not_ok(audio._playbacks_pending(), "headless audio did not start a playback")
	else:
		var deadline: int = Time.get_ticks_msec() + audio.SHUTDOWN_TIMEOUT_MS
		while audio._playbacks_pending() and Time.get_ticks_msec() < deadline:
			await tree.process_frame
		t.not_ok(audio._playbacks_pending(), "stopped playbacks are released by the mixer")
	var played: int = audio.sounds_played
	audio.play("ui_confirm")
	audio.play_music("mus_title")
	t.not_ok(audio.play_voice("new", AudioStreamWAV.new()))
	t.eq(audio.sounds_played, played)
	t.eq(audio.current_music, "")
	audio.free()


func test_desktop_quit_controls_use_graceful_path(t: T) -> void:
	# A live AppRoot starts the singleton's music; exercise the wiring without
	# starting audio in the test runner, which itself exits through direct quit.
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.get_name() != "headless":
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node("Audio")
	var saved_persist: bool = Settings.persist
	Settings.persist = false
	var app: Control = (load("res://ui/screens/app_root.tscn") as PackedScene).instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame
	var quit_button: Button = app.find_child("Quit", true, false) as Button
	t.ok(quit_button != null, "desktop title offers Quit")
	if quit_button != null:
		t.ok(quit_button.pressed.is_connected(audio.quit_gracefully), "Quit uses graceful shutdown")
	t.ok(tree.root.close_requested.is_connected(audio.quit_gracefully), "main window uses graceful shutdown")
	app.free()
	Settings.persist = saved_persist
