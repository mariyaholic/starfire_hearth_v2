class_name ImmersiveSurface
extends ColorRect
## Samples only the scene SubViewport; text and other UI never enter the glass.
const SHADER: Shader = preload("res://ui/world/shaders/immersive_glass.gdshader")
var owner_screen: WeakRef

static func add_to(panel: Control, screen: GameScreen) -> ImmersiveSurface:
	var surface: ImmersiveSurface = ImmersiveSurface.new()
	surface.owner_screen=weakref(screen)
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.show_behind_parent=true
	var shader_material: ShaderMaterial=ShaderMaterial.new(); shader_material.shader=SHADER
	surface.material=shader_material
	panel.add_child(surface); panel.move_child(surface,0)
	return surface

func _process(_delta: float) -> void:
	var screen: Variant=owner_screen.get_ref()
	if screen==null: return
	var renderer: Variant=screen.world_controller.host.renderer
	var shader_material: ShaderMaterial=material
	var has_scene: bool=renderer!=null and renderer.get("viewport") is SubViewport
	shader_material.set_shader_parameter("has_scene",has_scene)
	if has_scene:
		shader_material.set_shader_parameter("scene_texture",renderer.viewport.get_texture())
		var rect: Rect2=renderer.get_global_rect()
		shader_material.set_shader_parameter("scene_rect",Vector4(rect.position.x/Layout.logical_size.x,rect.position.y/Layout.logical_size.y,rect.size.x/Layout.logical_size.x,rect.size.y/Layout.logical_size.y))
		shader_material.set_shader_parameter("scene_pixel",Vector2.ONE/rect.size.max(Vector2.ONE))
	var matte: bool=Settings.interface_finish=="matte" or Settings.high_contrast
	shader_material.set_shader_parameter("panel_size",size)
	shader_material.set_shader_parameter("tint",Tokens.color("bg.panel"))
	shader_material.set_shader_parameter("opacity",1.0 if matte else Settings.interface_opacity)
	shader_material.set_shader_parameter("blur",0.0 if matte else Settings.interface_blur)
	shader_material.set_shader_parameter("gloss",0.0 if matte else Settings.interface_gloss)
	shader_material.set_shader_parameter("edge_light",0.0 if matte else Settings.interface_edge)

static func clear_cards(root: Node) -> void:
	for node: Node in root.find_children("*","PanelContainer",true,false):
		if not node is Card: continue
		var style: StyleBoxFlat=StyleBoxFlat.new()
		style.bg_color=Color.TRANSPARENT
		style.content_margin_left=8; style.content_margin_right=8
		style.content_margin_top=4; style.content_margin_bottom=4
		node.add_theme_stylebox_override("panel",style)
