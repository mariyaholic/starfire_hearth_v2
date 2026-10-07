class_name ImmersivePanel
extends PanelContainer
## In-canvas modeless window. Its shell stops input and isolates content minima.
signal activated
signal closed
signal minimized
signal dock_toggled
signal geometry_changed(rect: Rect2)
var kind: String=""
var body: VBoxContainer
var grip: Control
var title_handle: Label
var docked: bool=false
var dragging: bool=false
var resizing: bool=false
var _start_pointer: Vector2
var _start_rect: Rect2
var allowed_bounds: Rect2

static func make(id: String,title: String) -> ImmersivePanel:
	var panel: ImmersivePanel=ImmersivePanel.new()
	panel.kind=id; panel.name="ImmersiveWindow_"+id
	panel.theme_type_variation=&"CardPanel"; panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var clear: StyleBoxFlat=StyleBoxFlat.new(); clear.bg_color=Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel",clear)
	panel.clip_contents=true; panel.focus_mode=Control.FOCUS_ALL
	var shell: Control=Control.new(); shell.mouse_filter=Control.MOUSE_FILTER_PASS
	panel.add_child(shell)
	var col: VBoxContainer=GameUI.column(Tokens.SPACE_S)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shell.add_child(col)
	col.offset_left=12; col.offset_right=-12; col.offset_top=10; col.offset_bottom=-10
	var header: HBoxContainer=HBoxContainer.new(); col.add_child(header)
	panel.title_handle=Label.new(); panel.title_handle.text=title; panel.title_handle.theme_type_variation=&"StrongLabel"
	panel.title_handle.clip_text=true; panel.title_handle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.title_handle.mouse_filter=Control.MOUSE_FILTER_STOP; panel.title_handle.mouse_default_cursor_shape=Control.CURSOR_MOVE
	panel.title_handle.tooltip_text=Strings.fmt("ui.world.workspace_drag")
	panel.title_handle.gui_input.connect(panel._move_input); header.add_child(panel.title_handle)
	for item: Array in [["minimize","ui_minus","ui.world.workspace_minimize"],["dock","ui_display","ui.world.workspace_dock"],["close","ui_close","ui.world.close_panel"]]:
		if id=="summary": continue
		var button: SfButton=SfButton.make_icon(item[1],item[2],SfButton.GHOST)
		button.name="Workspace_"+item[0]+"_"+id
		match item[0]:
			"close": button.pressed.connect(func() -> void: panel.closed.emit())
			"minimize": button.pressed.connect(func() -> void: panel.minimized.emit())
			"dock": button.pressed.connect(func() -> void: panel.dock_toggled.emit())
		header.add_child(button)
	panel.body=GameUI.column(Tokens.SPACE_M)
	var scroll: ScrollContainer=FlowScreen.scroll_of(panel.body)
	scroll.name="ImmersiveContextScroll"; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	col.add_child(scroll)
	panel.grip=Control.new(); panel.grip.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.grip.mouse_default_cursor_shape=Control.CURSOR_FDIAGSIZE
	panel.grip.tooltip_text=Strings.fmt("ui.world.workspace_resize")
	panel.grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grip.offset_left=-24; panel.grip.offset_top=-24
	panel.grip.gui_input.connect(panel._resize_input); shell.add_child(panel.grip)
	panel.grip.draw.connect(func() -> void:
		for n: int in [6,11,16]: panel.grip.draw_line(Vector2(24-n,24),Vector2(24,24-n),Color("829ca8"),1.5))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: panel.activated.emit())
	return panel

func fit_window(rect: Rect2,bounds: Rect2) -> void:
	allowed_bounds=bounds
	var fitted: Rect2=ImmersiveWorkspace.fit(rect,bounds,Vector2(240,120))
	position=fitted.position; size=fitted.size
	grip.visible=not docked and not Layout.compact
	title_handle.mouse_default_cursor_shape=Control.CURSOR_ARROW if docked or Layout.compact else Control.CURSOR_MOVE

func _move_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		activated.emit()
		if is_inside_tree(): grab_focus()
		if not docked and not Layout.compact:
			dragging=event.pressed
			if dragging: _start_pointer=event.global_position; _start_rect=Rect2(position,size)
			else: geometry_changed.emit(Rect2(position,size))
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		fit_window(Rect2(_start_rect.position+event.global_position-_start_pointer,size),allowed_bounds)
		accept_event()

func _resize_input(event: InputEvent) -> void:
	if docked or Layout.compact: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		activated.emit()
		if is_inside_tree(): grab_focus()
		resizing=event.pressed
		if resizing: _start_pointer=event.global_position; _start_rect=Rect2(position,size)
		else: geometry_changed.emit(Rect2(position,size))
		accept_event()
	elif event is InputEventMouseMotion and resizing:
		fit_window(Rect2(position,_start_rect.size+event.global_position-_start_pointer),allowed_bounds)
		accept_event()
