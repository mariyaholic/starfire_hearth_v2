class_name Card
extends PanelContainer
## A panel with an optional icon, a title, a subtitle, a body and a footer of actions.

var body: VBoxContainer
var footer: HFlowContainer
var _header: HBoxContainer
var _title: Label
var _subtitle: Label


static func make(title_text: String, subtitle_text: String = "", icon_id: String = "", icon_token: String = "accent.teal") -> Card:
	var c: Card = Card.new()
	c.set_heading(title_text, subtitle_text, icon_id, icon_token)
	return c


func _init() -> void:
	theme_type_variation = &"Card"
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_M)
	add_child(col)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", Tokens.SPACE_M)
	_header.visible = false
	col.add_child(_header)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_S)
	col.add_child(body)
	footer = HFlowContainer.new()
	footer.visible = false
	col.add_child(footer)


func set_heading(title_text: String, subtitle_text: String = "", icon_id: String = "", icon_token: String = "accent.teal") -> void:
	for c: Node in _header.get_children():
		c.queue_free()
	_header.visible = not title_text.is_empty()
	if not icon_id.is_empty():
		_header.add_child(SfIcon.make(icon_id, Tokens.ICON_L, icon_token))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(texts)
	_title = Label.new()
	_title.theme_type_variation = &"H2Label"
	_title.text = title_text
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_title)
	if not subtitle_text.is_empty():
		_subtitle = Label.new()
		_subtitle.theme_type_variation = &"CaptionLabel"
		_subtitle.text = subtitle_text
		_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(_subtitle)


func add_body(c: Control) -> Control:
	body.add_child(c)
	return c


func add_action(b: Control) -> Control:
	footer.visible = true
	footer.add_child(b)
	return b


## A wrapping paragraph in the card body.
func add_text(text: String, variation: StringName = &"") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)
	return l
