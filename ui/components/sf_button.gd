class_name SfButton
extends Button
## Button variants of the UI kit. Always at least one touch target tall (48 dp on touch, 32 px with
## a pointer); icons are rasterised for the current scale.

const PRIMARY: String = "primary"
const SECONDARY: String = "secondary"
const GHOST: String = "ghost"
const DANGER: String = "danger"
const ICON: String = "icon"
const TAB: String = "tab"
const LINK: String = "link"

const VARIATIONS: Dictionary[String, StringName] = {
	PRIMARY: &"PrimaryButton", SECONDARY: &"", GHOST: &"GhostButton", DANGER: &"DangerButton",
	ICON: &"IconButton", TAB: &"TabButton", LINK: &"LinkButtonFlat",
}

var variant: String = SECONDARY
var icon_id: String = ""
## Key of the visible label, or of the accessible name for icon-only buttons.
var text_key: String = ""
var icon_only: bool = false


static func make(p_text_key: String, p_icon: String = "", p_variant: String = SECONDARY) -> SfButton:
	var b: SfButton = SfButton.new()
	b.text_key = p_text_key
	b.icon_id = p_icon
	b.variant = p_variant
	b.text = Strings.fmt(p_text_key) if not p_text_key.is_empty() else ""
	# Tabs toggle from the start, so a caller can mark one pressed before it enters the tree.
	b.toggle_mode = p_variant == TAB
	return b


## A square button with only an icon. The name still comes from the string table: it is the
## hover tooltip and the accessibility label.
static func make_icon(p_icon: String, p_name_key: String, p_variant: String = ICON) -> SfButton:
	var b: SfButton = SfButton.new()
	b.icon_id = p_icon
	b.text_key = p_name_key
	b.variant = p_variant
	b.icon_only = true
	b.tooltip_text = Strings.fmt(p_name_key)
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	add_to_group("sf_button")


func _ready() -> void:
	theme_type_variation = VARIATIONS.get(variant, &"")
	if variant == TAB:
		toggle_mode = true
	if icon_only:
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Layout.changed.connect(_refresh)
	_refresh()


func set_icon_id(id: String) -> void:
	icon_id = id
	_refresh()


func _refresh() -> void:
	var target: float = Layout.target_size()
	if variant == LINK and not Layout.touch_ui:
		target = 0.0
	custom_minimum_size = Vector2(target if icon_only else 0.0, target)
	if icon_id.is_empty():
		icon = null
		return
	var logical: float = (Tokens.ICON_L if not Layout.compact else Tokens.ICON_M + 2) * Settings.text_scale
	icon = IconCache.texture(icon_id, ceili(logical * Layout.scale))
