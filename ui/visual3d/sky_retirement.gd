extends RefCounted
## Godot 4.7 GLES3 can leave a freed Sky on its dirty list if it is released before
## the next draw. Hold only the Sky resources until the renderer has processed them.

static var _pending: Array[Sky] = []


static func retain(sky: Sky) -> void:
	if sky == null or DisplayServer.get_name() == "headless":
		return
	if not _pending.has(sky):
		_pending.append(sky)
	if not RenderingServer.frame_post_draw.is_connected(_release_after_draw):
		RenderingServer.frame_post_draw.connect(_release_after_draw, CONNECT_ONE_SHOT)


static func has_pending() -> bool:
	return not _pending.is_empty()


static func _release_after_draw() -> void:
	_pending.clear()
