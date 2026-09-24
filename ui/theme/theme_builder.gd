class_name ThemeBuilder
extends RefCounted
## Builds the one Theme every screen uses, from Tokens. Rebuilt whenever the text scale, the layout
## class (wide or compact), touch mode or the high-contrast setting changes.
##
## Type variations (set Control.theme_type_variation):
##   Labels   DisplayLabel H1Label H2Label StrongLabel CaptionLabel SecondaryLabel MonoLabel
##            MonoStrongLabel MonoCaptionLabel
##   Buttons  PrimaryButton (default Button is secondary) GhostButton DangerButton IconButton
##            TabButton LinkButtonFlat
##   Panels   Card RaisedPanel InsetPanel BreakdownPanel ChipPanel BarPanel SheetPanel DrawerPanel
##            ToastPanel ModalPanel

static var _fonts: Dictionary[String, Font] = {}


static func font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


## Font sizes in logical pixels for the current layout class and text scale.
static func font_sizes(compact: bool, text_scale: float) -> Dictionary[String, int]:
	var base: Dictionary[String, int] = Tokens.FONT_COMPACT if compact else Tokens.FONT_WIDE
	var out: Dictionary[String, int] = {}
	for k: String in base.keys():
		out[k] = roundi(base[k] * text_scale)
	return out


static func build(text_scale: float, compact: bool, touch: bool, high_contrast: bool) -> Theme:
	Tokens.high_contrast = high_contrast
	var t: Theme = Theme.new()
	var fs: Dictionary[String, int] = font_sizes(compact, text_scale)
	var target: int = Tokens.TOUCH_TARGET_DP if touch else Tokens.POINTER_TARGET_PX
	var border: int = 2 if high_contrast else 1
	t.default_font = font(Tokens.FONT_SANS_REGULAR)
	t.default_font_size = fs["body"]

	# --- labels ----------------------------------------------------------------------------
	t.set_color("font_color", "Label", Tokens.color("text.primary"))
	t.set_constant("line_spacing", "Label", _line_spacing(fs["body"]))
	_label(t, "DisplayLabel", Tokens.FONT_SANS_SEMIBOLD, fs["display"], "text.primary")
	_label(t, "H1Label", Tokens.FONT_SANS_SEMIBOLD, fs["h1"], "text.primary")
	_label(t, "H2Label", Tokens.FONT_SANS_SEMIBOLD, fs["h2"], "text.primary")
	_label(t, "StrongLabel", Tokens.FONT_SANS_MEDIUM, fs["body"], "text.primary")
	_label(t, "CaptionLabel", Tokens.FONT_SANS_REGULAR, fs["caption"], "text.secondary")
	_label(t, "SecondaryLabel", Tokens.FONT_SANS_REGULAR, fs["body"], "text.secondary")
	_label(t, "MonoLabel", Tokens.FONT_MONO_REGULAR, fs["body"], "text.primary")
	_label(t, "MonoStrongLabel", Tokens.FONT_MONO_MEDIUM, fs["body"], "text.primary")
	_label(t, "MonoCaptionLabel", Tokens.FONT_MONO_REGULAR, fs["caption"], "text.secondary")
	t.set_color("default_color", "RichTextLabel", Tokens.color("text.primary"))
	t.set_font("normal_font", "RichTextLabel", font(Tokens.FONT_SANS_REGULAR))
	t.set_font("bold_font", "RichTextLabel", font(Tokens.FONT_SANS_SEMIBOLD))
	t.set_font("mono_font", "RichTextLabel", font(Tokens.FONT_MONO_REGULAR))
	t.set_font_size("normal_font_size", "RichTextLabel", fs["body"])
	t.set_font_size("bold_font_size", "RichTextLabel", fs["body"])
	t.set_font_size("mono_font_size", "RichTextLabel", fs["body"])
	t.set_constant("line_separation", "RichTextLabel", _line_spacing(fs["body"]))

	# --- buttons ---------------------------------------------------------------------------
	var pad_v: int = maxi(Tokens.SPACE_S, int(ceil((target - fs["body"] * 1.3) / 2.0)))
	var pad_h: int = Tokens.SPACE_L
	_button(t, "Button", "bg.panel.alt", "text.primary", "line.subtle", border, pad_h, pad_v, fs["body"])
	_button(t, "PrimaryButton", "accent.teal", "bg.deep", "accent.teal", border, pad_h, pad_v, fs["body"])
	_button(t, "DangerButton", "alert.ember", "bg.deep", "alert.ember", border, pad_h, pad_v, fs["body"])
	_button(t, "GhostButton", "", "text.primary", "", border if high_contrast else 0, pad_h, pad_v, fs["body"])
	_button(t, "IconButton", "", "text.primary", "", border if high_contrast else 0, pad_v, pad_v, fs["body"])
	_button(t, "TabButton", "", "text.secondary", "", border if high_contrast else 0, pad_h, pad_v, fs["body"])
	_button(t, "LinkButtonFlat", "", "accent.teal", "", 0, 0, 2, fs["body"])
	# Pressed tabs look selected.
	t.set_stylebox("pressed", "TabButton", _box("bg.panel.alt", "accent.teal", 0, Tokens.RADIUS_CHIP, pad_h, pad_v, 2, true))
	t.set_color("font_pressed_color", "TabButton", Tokens.color("text.primary"))
	for v: String in ["Button", "PrimaryButton", "DangerButton", "GhostButton", "IconButton", "TabButton", "LinkButtonFlat"]:
		t.set_font("font", v, font(Tokens.FONT_SANS_MEDIUM))
		t.set_constant("icon_max_width", v, roundi((Tokens.ICON_L if not compact else Tokens.ICON_M + 2) * text_scale))
		t.set_constant("h_separation", v, Tokens.SPACE_S)
	t.set_font("font", "LinkButtonFlat", font(Tokens.FONT_SANS_MEDIUM))

	# --- panels ----------------------------------------------------------------------------
	var pad: int = Tokens.SPACE_M if compact else Tokens.SPACE_L
	t.set_stylebox("panel", "PanelContainer", _box("bg.panel", "line.subtle", border if high_contrast else 0, Tokens.RADIUS_PANEL, pad, pad))
	_panel(t, "Card", _box("bg.panel", "line.subtle", border if high_contrast else 0, Tokens.RADIUS_PANEL, pad, pad))
	_panel(t, "RaisedPanel", _box("bg.panel.alt", "line.subtle", border if high_contrast else 0, Tokens.RADIUS_PANEL, pad, pad))
	_panel(t, "InsetPanel", _box("bg.deep", "line.subtle", border, Tokens.RADIUS_PANEL, Tokens.SPACE_M, Tokens.SPACE_S))
	var tip: StyleBoxFlat = _box("bg.panel.alt", "line.subtle", border, Tokens.RADIUS_PANEL, Tokens.SPACE_M, Tokens.SPACE_M)
	tip.shadow_color = Color(0, 0, 0, 0.45)
	tip.shadow_size = 12
	tip.shadow_offset = Vector2(0, 4)
	_panel(t, "BreakdownPanel", tip)
	_panel(t, "ChipPanel", _box("bg.panel.alt", "line.subtle", border if high_contrast else 0, Tokens.RADIUS_CHIP, Tokens.SPACE_S, Tokens.SPACE_XS))
	var bar: StyleBoxFlat = _box("bg.panel", "line.subtle", 0, 0, Tokens.SPACE_M, Tokens.SPACE_XS)
	bar.border_width_bottom = border
	bar.border_color = Tokens.color("line.subtle")
	_panel(t, "BarPanel", bar)
	var sheet: StyleBoxFlat = _box("bg.panel", "line.subtle", 0, 0, pad, Tokens.SPACE_S)
	sheet.corner_radius_top_left = 12
	sheet.corner_radius_top_right = 12
	sheet.border_width_top = border
	sheet.border_color = Tokens.color("line.subtle")
	sheet.shadow_color = Color(0, 0, 0, 0.5)
	sheet.shadow_size = 16
	_panel(t, "SheetPanel", sheet)
	var drawer: StyleBoxFlat = _box("bg.panel", "line.subtle", 0, 0, pad, pad)
	drawer.border_width_right = border
	drawer.border_color = Tokens.color("line.subtle")
	drawer.shadow_color = Color(0, 0, 0, 0.5)
	drawer.shadow_size = 16
	_panel(t, "DrawerPanel", drawer)
	var toast: StyleBoxFlat = _box("bg.panel.alt", "line.subtle", border, Tokens.RADIUS_PANEL, Tokens.SPACE_M, Tokens.SPACE_S)
	toast.shadow_color = Color(0, 0, 0, 0.4)
	toast.shadow_size = 10
	_panel(t, "ToastPanel", toast)
	var modal: StyleBoxFlat = _box("bg.panel", "line.subtle", border, 0 if compact else Tokens.RADIUS_PANEL, pad + Tokens.SPACE_S, pad)
	modal.shadow_color = Color(0, 0, 0, 0.55)
	modal.shadow_size = 24
	_panel(t, "ModalPanel", modal)

	# --- inputs and bars -------------------------------------------------------------------
	t.set_stylebox("normal", "LineEdit", _box("bg.deep", "line.subtle", border, Tokens.RADIUS_CHIP, Tokens.SPACE_M, pad_v))
	t.set_stylebox("focus", "LineEdit", _focus())
	t.set_color("font_color", "LineEdit", Tokens.color("text.primary"))
	t.set_color("font_placeholder_color", "LineEdit", Tokens.color("text.secondary"))
	t.set_color("caret_color", "LineEdit", Tokens.color("accent.teal"))
	t.set_stylebox("background", "ProgressBar", _box("bg.deep", "line.subtle", border if high_contrast else 0, Tokens.RADIUS_CHIP, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box("accent.teal", "", 0, Tokens.RADIUS_CHIP, 0, 0))
	t.set_font_size("font_size", "ProgressBar", fs["caption"])
	var grabber_px: int = 20 if touch else 14
	t.set_icon("grabber", "HSlider", _dot_texture(grabber_px, Tokens.color("text.primary")))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(grabber_px, Tokens.color("accent.teal")))
	t.set_stylebox("slider", "HSlider", _box("bg.deep", "line.subtle", border, 3, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", _box("accent.teal", "", 0, 3, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box("accent.teal", "", 0, 3, 0, 3))
	var sb: StyleBoxFlat = _box("line.subtle", "", 0, 4, 0, 0)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box("text.secondary", "", 0, 4, 3, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box("accent.teal", "", 0, 4, 3, 3))
	t.set_stylebox("scroll", "VScrollBar", _box("", "", 0, 4, 3, 3))
	t.set_stylebox("grabber", "HScrollBar", sb)
	t.set_stylebox("grabber_highlight", "HScrollBar", _box("text.secondary", "", 0, 4, 3, 3))
	t.set_stylebox("grabber_pressed", "HScrollBar", _box("accent.teal", "", 0, 4, 3, 3))
	t.set_stylebox("scroll", "HScrollBar", _box("", "", 0, 4, 3, 3))
	t.set_stylebox("separator", "HSeparator", _line_box())
	t.set_constant("separation", "HSeparator", Tokens.SPACE_S)
	t.set_color("font_color", "CheckBox", Tokens.color("text.primary"))
	t.set_color("font_color", "CheckButton", Tokens.color("text.primary"))
	t.set_stylebox("focus", "CheckButton", _focus())
	t.set_stylebox("focus", "CheckBox", _focus())
	t.set_constant("separation", "HBoxContainer", Tokens.SPACE_S)
	t.set_constant("separation", "VBoxContainer", Tokens.SPACE_S)
	t.set_constant("h_separation", "HFlowContainer", Tokens.SPACE_S)
	t.set_constant("v_separation", "HFlowContainer", Tokens.SPACE_S)
	t.set_constant("h_separation", "GridContainer", Tokens.SPACE_M)
	t.set_constant("v_separation", "GridContainer", Tokens.SPACE_XS)
	return t


static func _line_spacing(size: int) -> int:
	return roundi(size * (Tokens.LINE_HEIGHT - 1.3))


static func _label(t: Theme, variation: String, font_path: String, size: int, color_token: String) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font("font", variation, font(font_path))
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, Tokens.color(color_token))
	t.set_constant("line_spacing", variation, _line_spacing(size))


static func _panel(t: Theme, variation: String, box: StyleBox) -> void:
	t.set_type_variation(variation, "PanelContainer")
	t.set_stylebox("panel", variation, box)


static func _button(t: Theme, variation: String, bg: String, fg: String, border_token: String, border: int, pad_h: int, pad_v: int, size: int) -> void:
	if variation != "Button":
		t.set_type_variation(variation, "Button")
	var radius: int = Tokens.RADIUS_PANEL if variation != "TabButton" else Tokens.RADIUS_CHIP
	var normal: StyleBoxFlat = _box(bg, border_token, border, radius, pad_h, pad_v)
	var hover: StyleBoxFlat = _box(bg, border_token, border, radius, pad_h, pad_v)
	var pressed: StyleBoxFlat = _box(bg, border_token, border, radius, pad_h, pad_v)
	var disabled: StyleBoxFlat = _box(bg, border_token, border, radius, pad_h, pad_v)
	if bg.is_empty():
		hover.draw_center = true
		hover.bg_color = Tokens.color("bg.panel.alt")
		pressed.draw_center = true
		pressed.bg_color = Tokens.color("line.subtle")
	else:
		hover.bg_color = Tokens.color(bg).lightened(0.12)
		pressed.bg_color = Tokens.color(bg).darkened(0.18)
		disabled.bg_color = Tokens.color(bg).lerp(Tokens.color("bg.panel"), 0.65)
	t.set_stylebox("normal", variation, normal)
	t.set_stylebox("hover", variation, hover)
	t.set_stylebox("pressed", variation, pressed)
	t.set_stylebox("hover_pressed", variation, pressed)
	t.set_stylebox("disabled", variation, disabled)
	t.set_stylebox("focus", variation, _focus())
	var c: Color = Tokens.color(fg)
	t.set_color("font_color", variation, c)
	t.set_color("font_hover_color", variation, c)
	t.set_color("font_pressed_color", variation, c)
	t.set_color("font_hover_pressed_color", variation, c)
	t.set_color("font_focus_color", variation, c)
	t.set_color("font_disabled_color", variation, Tokens.color("text.secondary").darkened(0.25) if bg.is_empty() else c.lerp(Tokens.color("bg.panel"), 0.45))
	t.set_color("icon_normal_color", variation, c)
	t.set_color("icon_hover_color", variation, c)
	t.set_color("icon_pressed_color", variation, c)
	t.set_color("icon_hover_pressed_color", variation, c)
	t.set_color("icon_focus_color", variation, c)
	t.set_color("icon_disabled_color", variation, c.lerp(Tokens.color("bg.panel"), 0.5))
	t.set_font_size("font_size", variation, size)


static func _box(bg: String, border_token: String, border: int, radius: int, pad_h: int, pad_v: int, border_bottom_only: int = 0, _tab: bool = false) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.draw_center = not bg.is_empty()
	if not bg.is_empty():
		b.bg_color = Tokens.color(bg)
	b.set_corner_radius_all(radius)
	b.corner_detail = 6
	b.anti_aliasing = true
	b.content_margin_left = pad_h
	b.content_margin_right = pad_h
	b.content_margin_top = pad_v
	b.content_margin_bottom = pad_v
	if border_bottom_only > 0:
		b.border_width_bottom = border_bottom_only
		b.border_color = Tokens.color(border_token)
	elif border > 0 and not border_token.is_empty():
		b.set_border_width_all(border)
		b.border_color = Tokens.color(border_token)
	return b


static func _focus() -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.draw_center = false
	b.set_border_width_all(2)
	b.border_color = Tokens.color("hearth.gold")
	b.set_corner_radius_all(Tokens.RADIUS_PANEL)
	b.set_expand_margin_all(2)
	return b


static func _line_box() -> StyleBoxLine:
	var l: StyleBoxLine = StyleBoxLine.new()
	l.color = Tokens.color("line.subtle")
	l.thickness = 1
	return l


static func _dot_texture(px: int, c: Color) -> ImageTexture:
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r: float = px / 2.0
	for y in px:
		for x in px:
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a: float = clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)
