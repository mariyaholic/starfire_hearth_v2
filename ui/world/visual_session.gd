class_name VisualSession
extends RefCounted
## Presentation metadata only; never written to the authoritative game state.
var epoch: int = 1
var cameras: Dictionary[String, Dictionary] = {}
var _order: Array[String] = []
const CAMERA_LIMIT: int = 32

func restart() -> void:
	epoch += 1
	cameras.clear()
	_order.clear()

func remember(key: String, camera_state: Dictionary) -> void:
	cameras[key] = camera_state.duplicate(true)
	_order.erase(key)
	_order.append(key)
	while _order.size() > CAMERA_LIMIT: cameras.erase(_order.pop_front())

func recall(key: String) -> Dictionary:
	return cameras.get(key, {}).duplicate(true)
