class_name GalaxySpatialView
extends RefCounted

static func build(screen: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var card: Card = Card.make(Strings.fmt("ui.galaxy.title"), Strings.fmt("ui.galaxy.subtitle"), "emblem_compass", "accent.teal")
	card.name = "Galaxy"
	var mount: Control = Control.new(); mount.name = "GalaxyMap"
	mount.custom_minimum_size = Vector2(0, 300 if Layout.compact else 480)
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_body(mount)
	screen.world_controller.attach(mount, "galaxy", "galaxy", screen.state)
	var choices: HFlowContainer = HFlowContainer.new()
	choices.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	choices.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	for marker: Dictionary in screen.world_controller.description.get("systems", []):
		var button: SfButton = SfButton.make(marker.get("name_key", "ui.galaxy.unknown"), "emblem_hearth", SfButton.GHOST)
		button.name = "System_" + marker["id"]
		button.pressed.connect(screen.world_controller.select.bind(marker["id"]))
		choices.add_child(button)
	card.add_body(choices)
	WorldViewTools.add_to(card, screen)
	card.add_text(Strings.fmt("ui.galaxy.locked"), &"CaptionLabel").name = "LockedNote"
	col.add_child(card)
	return col
