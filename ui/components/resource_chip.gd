class_name ResourceChip
extends Explainable
## One resource in the top bar: icon, stock, and net per turn, with the breakdown one hover or tap
## away. A warning (for example overflow in two turns) adds an alert icon and a caption, so the
## state never depends on colour alone.

var resource_id: String = ""
var _icon: SfIcon
var _stock: Label
var _net: Label
var _warn_icon: SfIcon


## `icon_id` and `color_token` come from data/resources.json. `net` is centi-units per turn.
static func make_chip(p_resource: String, icon_id: String, color_token: String, stock: int, net: int, b: Breakdown) -> ResourceChip:
	var c: ResourceChip = ResourceChip.new()
	c.resource_id = p_resource
	c.breakdown = b
	c._build(icon_id, color_token)
	c.set_values(stock, net)
	return c


func _build(icon_id: String, color_token: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_XS + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = SfIcon.make(icon_id, Tokens.ICON_L if not Layout.compact else Tokens.ICON_M, color_token)
	row.add_child(_icon)
	_stock = Label.new()
	_stock.theme_type_variation = &"MonoStrongLabel"
	_stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stock)
	_net = Label.new()
	_net.theme_type_variation = &"MonoCaptionLabel"
	_net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_net)
	_warn_icon = SfIcon.make("alert_warning", Tokens.ICON_S, "hearth.gold")
	_warn_icon.visible = false
	row.add_child(_warn_icon)
	custom_minimum_size.y = Layout.target_size()


func set_values(stock: int, net: int) -> void:
	_stock.text = Fmt.stock(stock)
	_net.text = Fmt.centi(net, true, 1)
	var token: String = "text.secondary"
	if net > 0:
		token = Tokens.POSITIVE
	elif net < 0:
		token = Tokens.NEGATIVE
	_net.add_theme_color_override("font_color", Tokens.color(token))


## Research has no stockpile (it flows into the current cards): show only the rate.
func hide_stock() -> void:
	_stock.visible = false
	_net.theme_type_variation = &"MonoStrongLabel"


func set_warning(on: bool) -> void:
	_warn_icon.visible = on
