class_name GalaxyView
extends RefCounted
## The galaxy (§7): the home system and its neighbours, most of them fogged, joined by lanes. In
## Scenario 1 every lane is locked, and the screen says why; the home system opens its own view.


static func build(s: GameScreen) -> Control:
	if Settings.appearance == "3d": return GalaxySpatialView.build(s)
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var card: Card = Card.make(Strings.fmt("ui.galaxy.title"), Strings.fmt("ui.galaxy.subtitle"), "emblem_compass", "accent.teal")
	card.name = "Galaxy"
	var spatial: SfButton = SfButton.make("ui.world.spatial", "emblem_compass", SfButton.GHOST)
	spatial.name = "Appearance3D"
	spatial.pressed.connect(Settings.set_appearance.bind("3d"))
	card.add_action(GameUI.exempt(spatial,"3D names the appearance mode"))
	var map: Map = Map.new()
	map.name = "GalaxyMap"
	map.setup(s)
	card.add_body(map)
	var note: Label = card.add_text(Strings.fmt("ui.galaxy.locked"), &"CaptionLabel")
	note.name = "LockedNote"
	col.add_child(card)
	return col


## The map: lanes drawn between the systems, each system a button with its star.
class Map:
	extends Control

	var _screen: GameScreen
	var _pos: Dictionary[String, Vector2] = {}
	var _nodes: Dictionary[String, Button] = {}

	func setup(s: GameScreen) -> void:
		_screen = s
		custom_minimum_size = Vector2(0, 260.0 if Layout.compact else 440.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var known: Dictionary[String, String] = s.state.player().known_systems
		for id: String in DictIO.sorted_keys(s.state.systems):
			var sys: StarSystem = s.state.systems[id]
			var here: bool = known.has(id)
			var b: Button = Button.new()
			b.name = "System_" + id
			b.flat = true
			b.focus_mode = Control.FOCUS_ALL
			b.custom_minimum_size = Vector2(104, 96)
			b.size = b.custom_minimum_size
			var v: VBoxContainer = VBoxContainer.new()
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var disc: StarDisc = StarDisc.make(sys.spectral if here else "G", sys.magnitude if here else 3, 44.0)
			disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var wrap: CenterContainer = CenterContainer.new()
			wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(disc)
			v.add_child(wrap)
			var l: Label = Label.new()
			l.theme_type_variation = &"CaptionLabel"
			l.text = Strings.fmt(sys.name_key) if here else Strings.fmt("ui.galaxy.unknown")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
			b.add_child(v)
			if not here:
				b.modulate = Color(1, 1, 1, 0.5)
			b.pressed.connect(_chosen.bind(id))
			add_child(b)
			_nodes[id] = b
		resized.connect(_place)
		_place.call_deferred()

	func _place() -> void:
		if _screen == null or _nodes.is_empty() or size.x <= 0.0:
			return
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		for id: String in _nodes.keys():
			var sys: StarSystem = _screen.state.systems[id]
			lo = Vector2(minf(lo.x, sys.x), minf(lo.y, sys.y))
			hi = Vector2(maxf(hi.x, sys.x), maxf(hi.y, sys.y))
		var margin: Vector2 = Vector2(64.0, 56.0)
		var span: Vector2 = Vector2(maxf(1.0, hi.x - lo.x), maxf(1.0, hi.y - lo.y))
		var k: float = minf((size.x - 2.0 * margin.x) / span.x, (size.y - 2.0 * margin.y) / span.y)
		var origin: Vector2 = (size - span * k) / 2.0
		for id: String in _nodes.keys():
			var sys: StarSystem = _screen.state.systems[id]
			_pos[id] = origin + (Vector2(sys.x, sys.y) - lo) * k
			var b: Button = _nodes[id]
			b.position = _pos[id] - b.size / 2.0
		queue_redraw()

	func _draw() -> void:
		var line: Color = Color(Tokens.color("line.subtle"), 0.9)
		var lock: Texture2D = IconCache.texture("ui_lock", 20)
		for lane_id: String in DictIO.sorted_keys(_screen.state.lanes):
			var lane: Lane = _screen.state.lanes[lane_id]
			if not _pos.has(lane.a) or not _pos.has(lane.b):
				continue
			draw_dashed_line(_pos[lane.a], _pos[lane.b], line, 2.0, 8.0)
			var mid: Vector2 = (_pos[lane.a] + _pos[lane.b]) / 2.0
			if lock != null:
				draw_texture(lock, mid - lock.get_size() / 2.0, Tokens.color("text.secondary"))

	func _chosen(id: String) -> void:
		var sys: StarSystem = _screen.state.systems[id]
		if _screen.state.player().known_systems.has(id) and not sys.planet_ids.is_empty():
			_screen.system_id = id
			_screen.planet_id = ""
			_screen.show_view(GameScreen.SYSTEM)
		else:
			Overlay.toast(Strings.fmt("ui.galaxy.locked_toast"), ReportItem.SEVERITY_INFO)
