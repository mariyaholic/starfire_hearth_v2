class_name ImmersiveWorldView
extends Control
## Map-first composition over the same persistent renderer and command inspectors.
## It contains no scene generation, simulation rules or independent command path.
var screen: GameScreen
var context: PanelContainer
var layout_data: Dictionary={}
var panels: Dictionary={}
var _bounds: Rect2
var queue_pill: SfButton
const TAB_KEYS: Dictionary={"overview":"ui.world.tab_overview","jobs":"ui.world.tab_jobs","governor":"ui.world.tab_governor","shipyard":"ui.world.tab_shipyard"}

static func build(owner: GameScreen) -> ImmersiveWorldView:
	var workspace: ImmersiveWorldView = ImmersiveWorldView.new()
	workspace.name = "ImmersiveWorld"
	workspace.screen = owner
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mount: Control = Control.new()
	mount.name = "PlannerGrid" if owner.view == GameScreen.COLONY else "GalaxyMap" if owner.view == GameScreen.GALAXY else "WorldMount"
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.add_child(mount)
	var entity: String = owner.colony_id if owner.view == GameScreen.COLONY else owner.system_id if owner.view == GameScreen.SYSTEM else "galaxy"
	var ghost: Dictionary = {}
	if owner.view == GameScreen.COLONY:
		ghost = ColonySpatialView.preview(owner,owner.state.colonies[entity])
	owner.world_controller.attach(mount,owner.view,entity,owner.state,ghost)
	if owner.view == GameScreen.COLONY: ColonySpatialView.sync_selection(owner)
	elif owner.view == GameScreen.SYSTEM and owner.world_controller.host.renderer != null and not owner.planet_id.is_empty() and owner.world_controller.selected_id != owner.planet_id:
		owner.world_controller.host.renderer.call("focus_body",owner.planet_id,false)
		owner.world_controller.selected_id = owner.planet_id
	workspace.layout_data=ImmersiveWorkspace.load_layout(owner.view,Layout.compact)
	var has_selection: bool=owner.slot>=0 if owner.view==GameScreen.COLONY else not owner.planet_id.is_empty()
	if has_selection and not workspace.layout_data.get("selection_seen",false):
		workspace.layout_data["selection_seen"]=true
		if not workspace.layout_data["open"].has("inspect"): workspace.layout_data["open"].append("inspect")
		workspace.layout_data["active"]="inspect"; workspace._save()
	workspace._build_windows()
	if owner.view==GameScreen.COLONY:
		queue_pill_add(workspace,owner)
	workspace.resized.connect(workspace._layout_panel)
	owner._scroll.resized.connect(workspace._layout_panel)
	workspace._layout_panel.call_deferred()
	return workspace

static func _button(parent: Container, key: String, icon: String, name_value: String, callback: Callable, compact: bool, primary: bool = false) -> SfButton:
	var style: String = SfButton.PRIMARY if primary else SfButton.ICON if compact else SfButton.GHOST
	var button: SfButton = SfButton.make_icon(icon,key,style) if compact else SfButton.make(key,icon,style)
	button.name = name_value
	button.pressed.connect(callback)
	if compact: button.add_theme_constant_override("icon_max_width",Tokens.ICON_M+2)
	parent.add_child(button)
	if compact:
		# Large text belongs in named panels and tooltips. Keep HUD icons and their
		# >=48-dp touch targets compact without shrinking any label or global theme.
		for state_name: String in ["normal","hover","pressed","disabled"]:
			var stylebox: StyleBox=button.get_theme_stylebox(state_name).duplicate()
			for side: int in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
				stylebox.set_content_margin(side,minf(stylebox.get_content_margin(side),Tokens.SPACE_S))
			button.add_theme_stylebox_override(state_name,stylebox)
	return button

static func toolbar(owner: GameScreen, parent: Container) -> void:
	var compact: bool = Layout.compact
	_button(parent,"ui.nav.more","ui_menu","Nav_more",owner.open_more,compact)
	_button(parent,"ui.world.enter_command","ui_display","ModeToggle",owner.toggle_view_mode,compact)
	_button(parent,"ui.world.build" if owner.view==GameScreen.COLONY else "ui.world.inspect","ui_plus" if owner.view==GameScreen.COLONY else "ui_why","ImmersiveInspect",owner.toggle_immersive_panel.bind("inspect"),compact)
	_button(parent,"ui.world.manage","ui_colony","ImmersiveManage",owner.toggle_immersive_panel.bind("manage"),compact)
	if not compact: _button(parent,"ui.world.objects","emblem_compass","ImmersiveObjects",owner.toggle_immersive_panel.bind("objects"),false)
	_button(parent,"ui.world.camera_tools","ui_settings","ImmersiveTools",owner.toggle_immersive_panel.bind("tools"),compact)
	if not compact:
		for item: Array in GameScreen.NAV:
			if item[0] in [GameScreen.GALAXY,GameScreen.SYSTEM,GameScreen.COLONY]: continue
			if item[0]==GameScreen.MARKET and not Market.is_open(owner.state,owner.state.player_id): continue
			_button(parent,item[1],item[2],"Nav_"+item[0],owner.show_view.bind(item[0]),false)
		_button(parent,"ui.world.workspace_reset","ui_reroll","ResetWorkspace",owner.reset_immersive_workspace,true)
	var undo: SfButton = _button(parent,"ui.game.undo","ui_undo","Undo",owner.undo_order,compact)
	undo.disabled = owner.order_count() == 0
	_button(parent,"ui.game.end_turn","ui_end_turn","EndTurn",owner.end_turn,compact,true)

func _build_windows() -> void:
	for kind: String in layout_data["open"]:
		if kind=="market" and not Market.is_open(screen.state,screen.state.player_id): continue
		var panel: ImmersivePanel=ImmersivePanel.make(kind,_title_for(kind))
		panel.add_to_group("modeless_window")
		panel.docked=bool(layout_data["docked"].get(kind,false))
		add_child(panel); panels[kind]=panel
		ImmersiveSurface.add_to(panel,screen)
		panel.activated.connect(_activate.bind(kind))
		panel.closed.connect(_close.bind(kind))
		panel.minimized.connect(_minimize.bind(kind))
		panel.dock_toggled.connect(_dock.bind(kind))
		panel.geometry_changed.connect(_geometry.bind(kind))
		var body: VBoxContainer=panel.body
		match kind:
			"summary": _summary(body)
			"inspect": _inspect(body)
			"manage": _manage(body)
			"queue":
				if screen.view==GameScreen.COLONY: body.add_child(ColonyView._queue(screen,screen.state.colonies[screen.colony_id]))
				else: _objects(body)
			"objects": _objects(body)
			"research": _research(body)
			"ordinances": body.add_child(OrdinancesView.build(screen))
			"market": body.add_child(MarketView.build(screen))
			"objectives": body.add_child(ObjectivesView.build(screen))
			"tools":
				var card: Card=Card.make(Strings.fmt("ui.world.camera_tools"))
				WorldViewTools.add_to(card,screen)
				card.add_text(Strings.fmt("ui.world.pan_hint"),&"CaptionLabel")
				var reset: SfButton=SfButton.make("ui.world.workspace_reset","ui_reroll",SfButton.GHOST)
				reset.name="ResetWorkspace"; reset.pressed.connect(screen.reset_immersive_workspace)
				card.add_body(reset); body.add_child(card)
		ImmersiveSurface.clear_cards(body)
	_activate(str(layout_data["active"]),false)
	_layout_panel()

func _title_for(kind: String) -> String:
	if kind=="summary":
		if screen.view==GameScreen.COLONY: return GameUI.colony_name(screen.state,screen.state.colonies[screen.colony_id])
		if screen.view==GameScreen.SYSTEM: return Strings.fmt(screen.state.systems[screen.system_id].name_key)
		return Strings.fmt("ui.nav.galaxy")
	if kind=="tools": return Strings.fmt("ui.world.camera_tools")
	if kind=="queue": return Strings.fmt("ui.colony.queue")
	if kind in ["research","ordinances","market","objectives"]: return Strings.fmt("ui.nav."+kind)
	return Strings.fmt("ui.world."+kind)

func _save() -> void:
	ImmersiveWorkspace.save_layout(screen.view,Layout.compact,layout_data)

func _activate(kind: String,save: bool=true) -> void:
	if not panels.has(kind):
		context=null; screen.immersive_panel_open=false; return
	layout_data["active"]=kind
	if save:
		layout_data["open"].erase(kind); layout_data["open"].append(kind); _save()
	for id: String in panels: (panels[id] as Control).name="ImmersiveWindow_"+id
	context=panels[kind]; context.name="ImmersiveContext"
	move_child(context,get_child_count()-1)
	screen.immersive_panel=kind; screen.immersive_panel_open=true
	_layout_panel()

func _close(kind: String) -> void:
	layout_data["open"].erase(kind)
	layout_data["active"]="" if layout_data["open"].is_empty() else layout_data["open"][-1]
	_save(); screen._refresh_view()

func _minimize(kind: String) -> void:
	layout_data["minimized"][kind]=true
	_save(); _layout_panel()

func _dock(kind: String) -> void:
	layout_data["docked"][kind]=not layout_data["docked"].get(kind,false)
	(panels[kind] as ImmersivePanel).docked=layout_data["docked"][kind]
	_save(); _layout_panel()

func _geometry(rect: Rect2,kind: String) -> void:
	if _bounds.size.x<=0 or _bounds.size.y<=0: return
	layout_data["geometry"][kind]=Rect2((rect.position-_bounds.position)/_bounds.size,rect.size/_bounds.size)
	_save()

func _process(_delta: float) -> void:
	# Container minima settle after their first sort. Refitting also follows the
	# clipped map during HUD reflow without resizing the renderer or resetting scroll.
	_layout_panel()

func _layout_panel() -> void:
	if panels.is_empty() or not is_instance_valid(screen._scroll): return
	var m: Vector4 = Layout.safe_margins
	var pad: float = Tokens.SPACE_S
	# The scroll content may be taller than its clipped viewport. Fit contexts to
	# the visible map, so a dock never hides its own controls beneath the toolbar.
	var bounds: Rect2 = screen._scroll.get_global_rect()
	var origin: Vector2 = bounds.position-global_position
	var available: Vector2 = bounds.size
	_bounds=Rect2(origin+Vector2(m.x+pad,pad),Vector2(maxf(1,available.x-m.x-m.z-2*pad),maxf(1,available.y-2*pad)))
	if queue_pill!=null:
		queue_pill.visible=not Layout.compact or layout_data["active"] in ["summary",""]
		queue_pill.position=Vector2(_bounds.position.x,_bounds.end.y-queue_pill.size.y-4)
	for kind: String in panels:
		var panel: ImmersivePanel=panels[kind]
		var minimized: bool=layout_data["minimized"].get(kind,false)
		panel.visible=not minimized and (not Layout.compact or kind==layout_data["active"])
		if not panel.visible or panel.dragging or panel.resizing: continue
		var expanded: bool=screen.view==GameScreen.COLONY and (screen.slot<0 or (screen.state.colonies[screen.colony_id].district_at(screen.slot)==null and screen.state.colonies[screen.colony_id].building_at(screen.slot)==null))
		var rect: Rect2=ImmersiveWorkspace.initial_rect(kind,_bounds,Settings.text_scale,expanded)
		if layout_data["geometry"].has(kind) and not panel.docked:
			var normalized: Rect2=layout_data["geometry"][kind]
			rect=Rect2(_bounds.position+normalized.position*_bounds.size,normalized.size*_bounds.size)
		if Layout.compact:
			if kind=="summary": rect=Rect2(_bounds.position,Vector2(minf(_bounds.size.x,290),minf(_bounds.size.y,178*sqrt(Settings.text_scale))))
			elif available.x<available.y: rect=Rect2(_bounds.position+Vector2(0,_bounds.size.y*0.54),Vector2(_bounds.size.x,_bounds.size.y*0.46))
			else: rect=Rect2(_bounds.position+Vector2(_bounds.size.x*0.52,0),Vector2(_bounds.size.x*0.48,_bounds.size.y))
		panel.fit_window(rect,_bounds)

func _inspect(body: VBoxContainer) -> void:
	if screen.view == GameScreen.COLONY:
		var colony: Colony = screen.state.colonies[screen.colony_id]
		var report: Economy.ColonyReport = screen.report.colonies.get(colony.id,null)
		body.add_child(ColonyView._slot_menu(screen,colony,report))
	elif screen.view == GameScreen.SYSTEM:
		SystemSpatialView.populate_inspector(screen,screen.state.systems[screen.system_id],body)
	else:
		body.add_child(GameUI.caption(Strings.fmt("ui.world.context_hint")))
		_objects(body)

static func queue_pill_add(workspace: ImmersiveWorldView,owner: GameScreen) -> void:
	workspace.queue_pill=SfButton.make("ui.colony.queue","ui_queue",SfButton.GHOST)
	workspace.queue_pill.name="ImmersiveQueue"
	var count: int=owner.state.colonies[owner.colony_id].queue.size()
	workspace.queue_pill.text=Strings.fmt("ui.world.queue_status",{"count":str(count)}) if count>0 else Strings.fmt("ui.world.queue_idle")
	workspace.queue_pill.pressed.connect(owner.toggle_immersive_panel.bind("queue"))
	workspace.add_child(workspace.queue_pill)
	ImmersiveSurface.add_to(workspace.queue_pill,owner)

func _summary(body: VBoxContainer) -> void:
	if screen.view==GameScreen.COLONY:
		var colony: Colony=screen.state.colonies[screen.colony_id]
		body.add_child(GameUI.exempt(FlowScreen.label(Strings.fmt("ui.world.summary_population",{"value":GameUI.pops(colony.pops)})),"colony population in thousands"))
		var stability: Label=FlowScreen.label(Strings.fmt("ui.world.summary_stability",{"value":str(colony.stability)}))
		body.add_child(Explainable.wrap(stability,Stability.target(screen.state,colony,screen.report.colonies.get(colony.id))))
		var manage: SfButton=SfButton.make("ui.world.manage","ui_settings",SfButton.GHOST)
		manage.name="SummaryManage"; manage.pressed.connect(screen.toggle_immersive_panel.bind("manage")); body.add_child(manage)
	else:
		var navigation: HFlowContainer=HFlowContainer.new(); body.add_child(navigation)
		for item: Array in GameScreen.NAV:
			if item[0] not in [GameScreen.GALAXY,GameScreen.SYSTEM,GameScreen.COLONY]: continue
			_button(navigation,item[1],item[2],"Summary_"+item[0],screen.show_view.bind(item[0]),true)
		var objects: SfButton=SfButton.make("ui.world.objects","emblem_compass",SfButton.GHOST)
		objects.name="SummaryObjects"; objects.pressed.connect(screen.toggle_immersive_panel.bind("objects")); body.add_child(objects)

func _research(body: VBoxContainer) -> void:
	var tabs: HFlowContainer=HFlowContainer.new(); body.add_child(tabs)
	for branch: String in Empire.BRANCHES:
		var button: SfButton=SfButton.make(Names.branch(branch),"branch_"+branch,SfButton.TAB)
		button.name="ResearchTab_"+branch; button.button_pressed=screen.branch_pick==branch
		button.pressed.connect(func() -> void: screen.branch_pick=branch; screen._refresh_view())
		tabs.add_child(button)
	body.add_child(ResearchView._branch(screen,screen.state.player(),screen.branch_pick))
	body.add_child(ResearchView._known(screen.state.player()))

func _manage(body: VBoxContainer) -> void:
	if screen.view == GameScreen.COLONY:
		var colony: Colony = screen.state.colonies[screen.colony_id]
		var report: Economy.ColonyReport = screen.report.colonies.get(colony.id,null)
		body.add_child(ColonyView._tabs(screen))
		var tabs: HFlowContainer=HFlowContainer.new(); body.add_child(tabs)
		for id: String in ["overview","jobs","governor","shipyard"]:
			if id=="shipyard" and not Construction.provides(colony,"spaceport"): continue
			var button: SfButton=SfButton.make(TAB_KEYS[id],"",SfButton.TAB)
			button.name="ManageTab_"+id; button.button_pressed=layout_data.get("manage_tab")==id
			button.pressed.connect(func() -> void: layout_data["manage_tab"]=id; _save(); screen._refresh_view())
			tabs.add_child(button)
		match layout_data.get("manage_tab","overview"):
			"jobs": body.add_child(ColonyView._jobs(screen,colony,report))
			"governor": body.add_child(ColonyView._governor(screen,colony))
			"shipyard":
				if Construction.provides(colony,"spaceport"): body.add_child(ColonyView._shipyard(screen,colony))
			_: body.add_child(ColonyView._stats(screen,colony,report))
	else:
		_objects(body)
	# All empire screens remain reachable without changing the selected layout setting.
	var navigation: HFlowContainer = HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation",Tokens.SPACE_S)
	navigation.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	for item: Array in GameScreen.NAV:
		if item[0] == GameScreen.MARKET and not Market.is_open(screen.state,screen.state.player_id): continue
		_button(navigation,item[1],item[2],"Manage_"+item[0],screen.show_view.bind(item[0]),false)
	body.add_child(navigation)
	var advisor: SfButton = SfButton.make("ui.world.advisor","ui_advisor",SfButton.GHOST)
	advisor.name = "ImmersiveAdvisor"
	advisor.pressed.connect(func() -> void:
		var drawer: Drawer = Drawer.make(Strings.fmt("ui.world.advisor"),Drawer.SIDE_RIGHT)
		screen._refresh_advisor()
		for child: Node in screen._advisor_box.get_children():
			screen._advisor_box.remove_child(child); drawer.body.add_child(child)
		drawer.open())
	body.add_child(advisor)
	if Layout.compact: _objects(body)

func _objects(body: VBoxContainer) -> void:
	body.add_child(GameUI.caption(Strings.fmt("ui.world.overview_hint")))
	var overview: SfButton = SfButton.make("ui.3d.overview","emblem_compass",SfButton.GHOST)
	overview.name = "SystemOverview"
	overview.pressed.connect(screen.world_controller.overview)
	body.add_child(overview)
	if screen.view == GameScreen.COLONY:
		ColonySpatialView.add_selectors(body,screen,screen.state.colonies[screen.colony_id])
		return
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation",Tokens.SPACE_S)
	flow.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	body.add_child(flow)
	var description: Dictionary = screen.world_controller.description
	if screen.view == GameScreen.GALAXY:
		for item: Dictionary in description.get("systems",[]):
			_button(flow,item.get("name_key","ui.galaxy.unknown"),"emblem_hearth","System_"+item["id"],screen.world_controller.select.bind(item["id"]),false)
		body.add_child(GameUI.caption(Strings.fmt("ui.galaxy.locked")))
	else:
		_button(flow,screen.state.systems[screen.system_id].name_key,"emblem_hearth","Focus_"+screen.system_id,screen.world_controller.focus.bind(screen.system_id),false)
		for collection: String in ["planets","ships","outposts","colonies"]:
			for item: Dictionary in description.get(collection,[]):
				var button: SfButton = _button(flow,item["name_key"],"emblem_compass","Focus_"+item["id"],screen.world_controller.focus.bind(item["id"]),false)
				if collection in ["colonies","outposts"]:
					button.text = Strings.fmt("ui.world.colony_link" if collection == "colonies" else "ui.world.outpost_link",{"planet_key":item["name_key"]})
