class_name WorldViewController
extends Node
## Owns the permitted selection contract; renderer intent is revalidated on fresh state.
signal selection_requested(id: String)
var host: WorldViewportHost
var description: Dictionary = {}
var selected_id: String = ""
var _screen: WeakRef

func setup(screen: Control) -> void:
	_screen = weakref(screen)
	host = WorldViewportHost.new()
	host.setup(screen, Worlds.session, Worlds.scheduler, Worlds.cache)
	host.selected.connect(select)
	host.presentation_failed.connect(_fallback)
	screen.add_child(host)

func attach(placeholder: Control, kind: String, entity_id: String, state: GameState, preview: Dictionary = {}) -> void:
	var changed_view: bool = description.get("view_kind", "") != kind or description.get("id", "") != entity_id or int(description.get("session_epoch", -1)) != Worlds.session.epoch
	if changed_view: selected_id = ""
	description = VisualSnapshotBuilder.build(state, kind, entity_id, Worlds.session.epoch)
	host.attach(placeholder, description, preview)
	if host.renderer != null and kind == "system":
		var remembered: String = str(host.renderer.get("selected_id"))
		if remembered != selected_id and selected_id.is_empty(): selected_id = remembered
		var screen: Control = _screen.get_ref() as Control
		if changed_view and is_instance_valid(screen) and str(screen.get("planet_id")).is_empty() and state.planets.has(remembered):
			screen.set("planet_id", remembered)

func select(id: String) -> void:
	var screen: Control = _screen.get_ref() as Control
	if not is_instance_valid(screen) or description.is_empty(): return
	var fresh: Dictionary = VisualSnapshotBuilder.build(Game.view(), description["view_kind"], description["id"], Worlds.session.epoch)
	var clear_colony: bool=id.is_empty() and not fresh.is_empty() and fresh["view_kind"]=="colony"
	if int(description["session_epoch"]) != Worlds.session.epoch or not (clear_colony or permits(fresh, id)): return
	selected_id = id
	selection_requested.emit(id)

static func permits(snapshot: Dictionary, id: String) -> bool:
	if snapshot.is_empty(): return false
	if snapshot["view_kind"] == "galaxy":
		for marker: Dictionary in snapshot["systems"]:
			if marker["id"] == id: return true
	elif snapshot["view_kind"] == "colony":
		if not id.begins_with("slot:"): return false
		var value: String = id.trim_prefix("slot:")
		if not value.is_valid_int() or str(int(value)) != value: return false
		return int(value) >= 0 and int(value) < int(snapshot["slot_count"])
	else:
		if snapshot["id"] == id: return true
		for collection: String in ["planets", "ships", "outposts", "colonies"]:
			for item: Dictionary in snapshot.get(collection, []):
				if item["id"] == id: return true
	return false

func focus(id: String) -> void:
	if host.renderer != null and permits(description, id):
		host.renderer.call("focus_body", id)
		_reveal_scene()

func overview() -> void:
	selected_id = ""
	if host.renderer != null: host.renderer.call("show_overview")
	selection_requested.emit("")
	_reveal_scene()

func _reveal_scene() -> void:
	# Selection rebuilds the inspector. Wait for its mount and container layout before
	# scrolling, so compact screens reveal the selected world and resume refinement.
	for i: int in 2: await get_tree().process_frame
	var screen: Control = _screen.get_ref() as Control
	var placeholder: Control = host.mount.get_ref() as Control if host.mount != null else null
	if is_instance_valid(screen) and is_instance_valid(placeholder):
		var scroll: ScrollContainer=screen.get("_scroll") as ScrollContainer
		if scroll.is_ancestor_of(placeholder): scroll.ensure_control_visible(placeholder)

func deactivate() -> void:
	host.deactivate()
	description.clear()
	selected_id = ""

func _fallback() -> void:
	Settings.set_appearance("strategic")
	Overlay.toast(Strings.fmt("ui.world.fallback"), ReportItem.SEVERITY_INFO)
