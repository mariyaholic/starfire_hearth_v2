class_name FinishMaterials
extends RefCounted
## Catalog-3 PBR assignments. Imported albedo is sRGB; data maps stay linear.
const SURFACE: Shader = preload("res://ui/art/shaders/surface.gdshader")
const GROUND: Shader = preload("res://ui/art/shaders/ground.gdshader")
const LEAF: Shader = preload("res://ui/art/shaders/leaf.gdshader")
const ROOT: String = "res://assets/textures/finish_v1/"

static func texture(family: String, channel: String) -> Texture2D:
	return load(ROOT+family+"_"+channel+".png") as Texture2D

static func surface(role: String, style: String = "ark") -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SURFACE
	var family: String = "metal" if role in ["metal","dark","solar","accent","foil"] else "rock" if role=="stone" else "soil" if role in ["soil","crop","road","trunk"] else "ceramic"
	if role=="shell" and style=="ark": family="concrete"
	var colors: Dictionary = {"shell":"f4ecda","hull":"f4ecda","metal":"b3bdc0","dark":"48525a","stone":"c8c0ac","soil":"a89572","crop":"598348","solar":"244e68","road":"a09480","trunk":"71614a","foil":"dab77b","accent":"629c97"}
	if style=="meridian": colors["shell"]="dbe5ec"; colors["accent"]="639bd0"
	elif style=="vael": colors["shell"]="d9d2df"; colors["accent"]="a991c6"
	for channel: String in ["albedo","normal","roughness"]: material.set_shader_parameter(channel+"_map",texture(family,channel))
	material.set_shader_parameter("trim_normal",texture("trim","normal"))
	material.set_shader_parameter("trim_ao",texture("trim","ao"))
	material.set_shader_parameter("tint",Color(colors.get(role,"f4ecda")))
	material.set_shader_parameter("metallic",0.78 if role in ["metal","solar","foil"] else 0.3 if role in ["dark","accent"] else 0.0)
	material.set_shader_parameter("panel_amount",1.0 if family in ["metal","ceramic","concrete"] else 0.0)
	material.set_shader_parameter("solar",role=="solar")
	return material

static func ground() -> ShaderMaterial:
	var material: ShaderMaterial=ShaderMaterial.new(); material.shader=GROUND
	for family: String in ["rock","soil"]:
		for channel: String in ["albedo","normal","roughness"]: material.set_shader_parameter(family+"_"+channel,texture(family,channel))
	return material

static func leaves() -> ShaderMaterial:
	var material: ShaderMaterial=ShaderMaterial.new(); material.shader=LEAF
	for channel: String in ["albedo","normal","roughness"]: material.set_shader_parameter(channel+"_map",texture("leaf",channel))
	return material

static func glass() -> StandardMaterial3D:
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.albedo_color=Color(0.21,0.38,0.43,0.42)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED; material.metallic=0.24; material.roughness=0.17
	return material
