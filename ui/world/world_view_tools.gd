class_name WorldViewTools
extends RefCounted
const INTERFACE_KEYS: Dictionary={"opacity":"ui.world.interface_opacity","blur":"ui.world.interface_blur","gloss":"ui.world.interface_gloss","edge":"ui.world.interface_edge"}

static func add_to(card: Card, screen: GameScreen) -> void:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	row.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	var strategic: SfButton = SfButton.make("ui.world.strategic", "emblem_compass", SfButton.GHOST)
	strategic.name = "AppearanceStrategic"
	strategic.pressed.connect(Settings.set_appearance.bind("strategic"))
	row.add_child(strategic)
	var reset: SfButton = SfButton.make("ui.world.reset", "ui_undo", SfButton.GHOST)
	reset.name = "CameraReset"
	reset.pressed.connect(screen.world_controller.overview)
	row.add_child(reset)
	var pause: CheckButton = CheckButton.new()
	pause.text = Strings.fmt("ui.3d.pause_short")
	pause.name = "WorldPause"
	pause.button_pressed = screen.world_controller.host.renderer != null and bool(screen.world_controller.host.renderer.get("motion_paused"))
	pause.custom_minimum_size.y = Layout.target_size()
	pause.toggled.connect(func(value: bool) -> void:
		if screen.world_controller.host.renderer != null: screen.world_controller.host.renderer.set("motion_paused", value))
	row.add_child(pause)
	if screen.view==GameScreen.SYSTEM:
		var orbit_toggle: CheckButton=CheckButton.new(); orbit_toggle.name="OrbitVisibility"
		orbit_toggle.text=Strings.fmt("ui.world.orbits_visible"); orbit_toggle.button_pressed=Settings.orbit_visible
		orbit_toggle.custom_minimum_size.y=Layout.target_size(); orbit_toggle.toggled.connect(Settings.set_orbit_visible)
		row.add_child(orbit_toggle)
		var opacity: HSlider=HSlider.new(); opacity.name="OrbitOpacity"
		opacity.min_value=0.0; opacity.max_value=1.0; opacity.step=0.05; opacity.value=Settings.orbit_opacity
		opacity.custom_minimum_size=Vector2(130,Layout.target_size()); opacity.tooltip_text=Strings.fmt("ui.world.orbit_opacity")
		opacity.value_changed.connect(Settings.set_orbit_opacity); row.add_child(opacity)
	if screen.world_controller.host.renderer is ColonyRenderer:
		var city: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
		var light: CheckButton=CheckButton.new(); light.name="WorldDusk"; light.text=Strings.fmt("ui.world.dusk")
		light.custom_minimum_size.y=Layout.target_size(); light.button_pressed=city.dusk
		light.toggled.connect(city.set_dusk); row.add_child(light)
		var parcels: CheckButton=CheckButton.new(); parcels.name="WorldParcels"; parcels.text=Strings.fmt("ui.world.parcels")
		parcels.custom_minimum_size.y=Layout.target_size(); parcels.button_pressed=city.parcel_overlay
		parcels.toggled.connect(city.set_parcel_overlay); row.add_child(parcels)
	if Worlds.appearances.can_upgrade_finish():
		var finish: SfButton=SfButton.make("ui.world.new_finish","ui_plus",SfButton.GHOST); finish.name="UpgradeVisualFinish"
		finish.tooltip_text=Strings.fmt("ui.world.new_finish_help")
		finish.pressed.connect(func() -> void:
			if Worlds.upgrade_finish(): screen.world_controller.deactivate(); screen._queue_refresh())
		row.add_child(finish)
	if screen.view==GameScreen.COLONY and CityRoadRecipes.can_upgrade(Worlds.appearances):
		var roads: SfButton=SfButton.make("ui.world.roads_update","ui_plus",SfButton.GHOST)
		roads.name="UpgradeCityRoads"; roads.tooltip_text=Strings.fmt("ui.world.roads_update_help")
		roads.pressed.connect(func() -> void:
			if Worlds.upgrade_roads(): screen.world_controller.deactivate(); screen._queue_refresh())
		row.add_child(roads)
	if screen.view==GameScreen.SYSTEM and Worlds.appearances.can_upgrade_orbits():
		var orbit: SfButton=SfButton.make("ui.world.orbits_update","ui_plus",SfButton.GHOST)
		orbit.name="UpgradeOrbits"; orbit.tooltip_text=Strings.fmt("ui.world.orbits_update_help")
		orbit.pressed.connect(func() -> void:
			if Worlds.upgrade_orbits(): screen.world_controller.deactivate(); screen._queue_refresh())
		row.add_child(orbit)
	card.add_body(row)
	if screen.world_controller.host.renderer is ColonyRenderer:
		var city: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
		if not city.road_network.get("unreachable",[]).is_empty(): card.add_text(Strings.fmt("ui.world.roads_gap"),&"CaptionLabel")
	var quality: Control=SettingsScreen.choice("ui.world.quality", ["auto","low","standard"], ["ui.world.auto","ui.world.low","ui.world.standard"], Settings.visual_quality, Settings.set_visual_quality)
	card.add_body(quality)
	add_interface_controls(card)
	# Scene controls precede the mount; they stay reachable on compact screens.
	var mount: Control=screen.world_controller.host.mount.get_ref() as Control if screen.world_controller.host.mount!=null else null
	if mount!=null and mount.get_parent()==card.body:
		var index: int=mount.get_index(); card.body.move_child(row,index); card.body.move_child(quality,index+1)

static func add_interface_controls(card: Card) -> void:
	card.add_body(SettingsScreen.choice("ui.world.interface_finish",["matte","frosted","glossy"],["ui.world.finish_matte","ui.world.finish_frosted","ui.world.finish_glossy"],Settings.interface_finish,Settings.set_interface_finish))
	for setting: String in ["opacity","blur","gloss","edge"]:
		var row: VBoxContainer=GameUI.column(4)
		var label: Label=GameUI.caption("")
		var value: float=Settings.get("interface_"+setting)
		label.text=Strings.fmt(INTERFACE_KEYS[setting])+" · "+(str(roundi(value))+" px" if setting=="blur" else str(roundi(value*100))+"%")
		row.add_child(GameUI.exempt(label,"interface appearance preference, independent of gameplay"))
		var slider: HSlider=HSlider.new(); slider.name="Interface_"+setting
		slider.min_value=0.70 if setting=="opacity" else 0.0
		slider.max_value=16.0 if setting=="blur" else 1.0 if setting=="opacity" else 0.30
		slider.step=1.0 if setting=="blur" else 0.01; slider.value=value
		slider.custom_minimum_size=Vector2(180,Layout.target_size())
		slider.value_changed.connect(func(v: float) -> void:
			Settings.call("set_interface_"+setting,v)
			label.text=Strings.fmt(INTERFACE_KEYS[setting])+" · "+(str(roundi(v))+" px" if setting=="blur" else str(roundi(v*100))+"%"))
		row.add_child(slider); card.add_body(row)
	var contrast: CheckButton=CheckButton.new(); contrast.name="InterfaceHighContrast"
	contrast.text=Strings.fmt("ui.settings.high_contrast"); contrast.button_pressed=Settings.high_contrast
	contrast.toggled.connect(Settings.set_high_contrast); card.add_body(contrast)
