class_name SystemSpatialView
extends RefCounted
## Disposable inspectors and accessible selectors around the persistent scene.
static func build(screen: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var sys: StarSystem = screen.state.systems[screen.system_id]
	var head: Card = Card.make(Strings.fmt(sys.name_key), Strings.fmt(SystemView.STAR_KEYS.get(sys.spectral, "ui.worlds.star.g")), "emblem_hearth", "hearth.gold")
	head.name = "SystemHeader"
	col.add_child(head)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	buttons.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	head.add_body(buttons)
	var overview: SfButton = SfButton.make("ui.3d.overview", "emblem_compass", SfButton.GHOST)
	overview.name = "SystemOverview"
	overview.pressed.connect(screen.world_controller.overview)
	buttons.add_child(overview)
	var split: BoxContainer = BoxContainer.new()
	split.vertical = Layout.compact
	split.add_theme_constant_override("separation", Tokens.SPACE_M)
	col.add_child(split)
	var mount: Control = Control.new()
	mount.name = "WorldMount"
	mount.custom_minimum_size = Vector2(0, 280 if Layout.compact else 480)
	mount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(mount)
	screen.world_controller.attach(mount, "system", screen.system_id, screen.state)
	var snapshot: Dictionary = screen.world_controller.description
	if snapshot.is_empty(): return col
	WorldViewTools.add_to(head, screen)
	var focus_star: SfButton = SfButton.make(sys.name_key, "emblem_hearth", SfButton.GHOST)
	focus_star.name = "Focus_" + sys.id
	focus_star.pressed.connect(screen.world_controller.focus.bind(sys.id))
	buttons.add_child(focus_star)
	for collection: String in ["planets", "ships", "outposts", "colonies"]:
		for object: Dictionary in snapshot.get(collection, []):
			var icon: String = "planet_" + object["kind"] if collection == "planets" else "map_outpost"
			if collection == "ships": icon = GameUI.icon_of("hulls", object["hull"], "ship_fleet")
			if collection == "colonies": icon = "ui_colony"
			var button: SfButton = SfButton.make(object["name_key"], icon, SfButton.GHOST)
			if collection == "colonies": button.text = Strings.fmt("ui.world.colony_link", {"planet_key":object["name_key"]})
			elif collection == "outposts": button.text = Strings.fmt("ui.world.outpost_link", {"planet_key":object["name_key"]})
			button.name = "Focus_" + object["id"]
			button.pressed.connect(screen.world_controller.focus.bind(object["id"]))
			buttons.add_child(button)
	var inspector: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	inspector.name = "SystemInspector"
	inspector.custom_minimum_size.x = 0 if Layout.compact else 320 * Settings.text_scale
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(inspector)
	populate_inspector(screen,sys,inspector)
	col.add_child(GameUI.caption(Strings.fmt("ui.world.controls")))
	return col

static func populate_inspector(screen: GameScreen, sys: StarSystem, inspector: VBoxContainer) -> void:
	var selection: String = screen.world_controller.selected_id
	if screen.state.planets.has(screen.planet_id):
		if selection != screen.planet_id:
			screen.world_controller.host.renderer.call("focus_body", screen.planet_id, false)
			screen.world_controller.selected_id = screen.planet_id
		inspector.add_child(SystemView._panel(screen, screen.state.planets[screen.planet_id]))
	elif selection == sys.id:
		var star_card: Card = Card.make(Strings.fmt(sys.name_key), Strings.fmt(SystemView.STAR_KEYS.get(sys.spectral, "ui.worlds.star.g")), "emblem_hearth", "hearth.gold")
		star_card.name = "StarInspector"
		inspector.add_child(star_card)
	else:
		if screen.state.ships.has(selection) and screen.state.ships[selection].owner_id == screen.state.player_id:
			var ship: Ship = screen.state.ships[selection]
			var ship_card: Card = Card.make(GameUI.name_of("hulls", ship.hull), "", "ship_fleet", "accent.teal")
			ship_card.name = "ShipInspector"
			GameUI.exempt(ship_card.add_text(SystemView._task_text(screen.state, ship)), "actual turns left on the owned ship's task")
			inspector.add_child(ship_card)
		elif screen.state.colonies.has(selection) and screen.state.colonies[selection].owner_id == screen.state.player_id:
			inspector.add_child(SystemView._panel(screen, screen.state.planets[screen.state.colonies[selection].planet_id]))
		else:
			var hint: Card = Card.make(Strings.fmt("ui.system.pick_title"), "", "map_outpost", "text.secondary")
			hint.add_text(Strings.fmt("ui.system.pick_hint"))
			inspector.add_child(hint)
	inspector.add_child(SystemView._fleets(screen, sys))
