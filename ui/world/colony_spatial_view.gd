class_name ColonySpatialView
extends RefCounted
## The normal M1 planner supplies the same costs, previews, refusals and queue
## actions in both presentations. Only its left-hand parcel display changes.
static func planner(screen: GameScreen, colony: Colony, card: Card) -> Control:
	var mount: Control=Control.new()
	mount.name="PlannerGrid"
	mount.custom_minimum_size=Vector2(0,280 if Layout.compact else 480)
	mount.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mount.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_body(mount)
	var ghost: Dictionary=preview(screen,colony)
	screen.world_controller.attach(mount,"colony",colony.id,screen.state,ghost)
	WorldViewTools.add_to(card,screen)
	sync_selection(screen)
	add_selectors(card.body,screen,colony)
	card.add_body(GameUI.caption(Strings.fmt("ui.world.city_controls")))
	# Preserve landmark information and its exception to normal parcel occupancy.
	for building: Colony.PlacedBuilding in colony.buildings:
		if building.slot<0: card.add_text(GameUI.name_of("buildings",building.building_id),&"CaptionLabel")
	return card

static func preview(screen: GameScreen, colony: Colony) -> Dictionary:
	var ghost: Dictionary={}
	if screen.slot >= 0 and not screen.pick.is_empty() and colony.district_at(screen.slot)==null and colony.building_at(screen.slot)==null and colony.queued_at(screen.slot)==null:
		var command: Command=PlaceDistrictCommand.create(screen.state.player_id,colony.id,screen.slot,screen.pick,screen.branch_pick) if screen.pick_kind=="district" else BuildBuildingCommand.create(screen.state.player_id,colony.id,screen.slot,screen.pick)
		ghost={"slot":screen.slot,"kind":screen.pick_kind,"id":screen.pick,"tier":1,"valid":command.validate(screen.state).ok}
	return ghost

static func sync_selection(screen: GameScreen) -> void:
	var renderer: ColonyRenderer=screen.world_controller.host.renderer as ColonyRenderer
	if renderer!=null:
		if screen.slot>=0:
			if renderer.selected_slot!=screen.slot: renderer.select_slot(screen.slot,false)
			screen.world_controller.selected_id="slot:"+str(screen.slot)
		elif renderer.selected_slot>=0:
			renderer.selected_slot=-1
			if renderer.selection_root!=null: renderer._clear(renderer.selection_root)

static func add_selectors(parent: Control, screen: GameScreen, colony: Colony) -> void:
	var selectors: HFlowContainer=HFlowContainer.new()
	selectors.name="ParcelSelectors"
	selectors.add_theme_constant_override("h_separation",Tokens.SPACE_S)
	selectors.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	var planet: Planet=screen.state.planets[colony.planet_id]
	for index: int in ColonyRules.slot_count(planet):
		var icon: String="district_habitation"
		var title: String=Strings.fmt("ui.world.parcel",{"number":index+1})
		var district: Colony.PlacedDistrict=colony.district_at(index)
		var building: Colony.PlacedBuilding=colony.building_at(index)
		if planet.blocked_slots.has(index): icon="alert_warning"; title+=" · "+Strings.fmt("error.build.blocked_slot")
		elif district!=null: icon=GameUI.icon_of("districts",district.district_id); title+=" · "+GameUI.name_of("districts",district.district_id)
		elif building!=null: icon=GameUI.icon_of("buildings",building.building_id); title+=" · "+GameUI.name_of("buildings",building.building_id)
		var button: SfButton=SfButton.make("",icon,SfButton.TAB)
		button.name="Slot_%d" % index; button.text=str(index+1); button.tooltip_text=title
		button.button_pressed=index==screen.slot
		button.pressed.connect(screen.world_controller.focus.bind("slot:"+str(index)))
		selectors.add_child(GameUI.exempt(button,"canonical parcel number, shared with M1's construction rules"))
	parent.add_child(selectors)
