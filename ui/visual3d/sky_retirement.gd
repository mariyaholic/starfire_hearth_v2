extends RefCounted
## Godot 4.7 GLES3 can leave a freed Sky on its dirty list if it is released before
## the next draw. Hold only the Sky resources until the renderer has processed them.

static var _pending: Dictionary[Sky, int] = {}


static func retain(sky: Sky) -> void:
	if sky == null or DisplayServer.get_name() == "headless":
		return
	# A preceding frame_post_draw listener may create or dirty a sky during
	# that same emission. Its own draw must happen before we release it.
	_pending[sky] = Engine.get_frames_drawn()
	if not RenderingServer.frame_post_draw.is_connected(_release_after_draw):
		RenderingServer.frame_post_draw.connect(_release_after_draw)


static func has_pending() -> bool:
	return not _pending.is_empty()


static func _release_after_draw() -> void:
	# Godot increments this counter after draw() returns, so a sky retained
	# before the draw may conservatively survive one additional boundary.
	var drawn: int = Engine.get_frames_drawn()
	for sky: Sky in _pending.keys():
		if _pending[sky] < drawn: _pending.erase(sky)
	if _pending.is_empty(): RenderingServer.frame_post_draw.disconnect(_release_after_draw)
