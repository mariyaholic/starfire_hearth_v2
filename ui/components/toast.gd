class_name Toast
extends PanelContainer
## A short, non-blocking notice (§6.6). The icon and colour both carry the severity, so colour is
## never the only signal. Critical alerts are not toasts: they block End Turn in the report.

const ICONS: Dictionary[String, String] = {
	ReportItem.SEVERITY_INFO: "alert_info",
	ReportItem.SEVERITY_GOOD: "alert_success",
	ReportItem.SEVERITY_WARNING: "alert_warning",
	ReportItem.SEVERITY_CRITICAL: "alert_critical",
}
const COLORS: Dictionary[String, String] = {
	ReportItem.SEVERITY_INFO: "accent.teal",
	ReportItem.SEVERITY_GOOD: "ok.green",
	ReportItem.SEVERITY_WARNING: "hearth.gold",
	ReportItem.SEVERITY_CRITICAL: "alert.ember",
}

var severity: String = ReportItem.SEVERITY_INFO
var _label: Label


func setup(text: String, p_severity: String) -> void:
	severity = p_severity
	theme_type_variation = &"ToastPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_M)
	add_child(row)
	var stripe: ColorRect = ColorRect.new()
	stripe.color = Tokens.color(COLORS.get(severity, "accent.teal"))
	stripe.custom_minimum_size = Vector2(4, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	row.add_child(SfIcon.make(ICONS.get(severity, "alert_info"), Tokens.ICON_L, COLORS.get(severity, "accent.teal")))
	_label = Label.new()
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	var close: SfButton = SfButton.make_icon("ui_close", "ui.toast.dismiss")
	close.pressed.connect(dismiss)
	row.add_child(close)


func text() -> String:
	return _label.text


func dismiss() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if Settings.reduce_motion:
		queue_free()
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, Tokens.TWEEN_FAST)
	tw.tween_callback(queue_free)
