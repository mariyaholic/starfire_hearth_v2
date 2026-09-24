class_name CostChips
extends HFlowContainer
## A cost as chips: resource icon and amount. A cost the empire cannot pay gets a warning icon
## and the negative colour, and its breakdown says what is missing.


static func make(cost: Dictionary, stock: Dictionary = {}, check: bool = false) -> CostChips:
	var c: CostChips = CostChips.new()
	c.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	c.add_theme_constant_override("v_separation", Tokens.SPACE_XS)
	var keys: Array = cost.keys()
	keys.sort()
	for res: Variant in keys:
		var amount: int = int(cost[res])
		if amount == 0:
			continue
		var have: int = int(stock.get(res, 0))
		c.add_child(chip(str(res), amount, check and have < amount, have))
	return c


static func chip(res: String, amount: int, short: bool, have: int = 0) -> Control:
	var db: ContentDb = Content.db()
	var rec: Dictionary = db.record("resources", res)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ChipPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_XS)
	panel.add_child(row)
	row.add_child(SfIcon.make(DictIO.str_of(rec, "icon", "res_minerals"), Tokens.ICON_S, DictIO.str_of(rec, "color", "text.secondary")))
	var l: Label = Label.new()
	l.theme_type_variation = &"MonoLabel"
	l.text = Fmt.centi(amount, false, 2, 0)
	row.add_child(l)
	if short:
		l.add_theme_color_override("font_color", Tokens.color(Tokens.NEGATIVE))
		row.add_child(SfIcon.make("alert_warning", Tokens.ICON_S, Tokens.NEGATIVE))
	var b: Breakdown = Breakdown.for_resource("ui.cost.label", res, false, {"resource_key": DictIO.str_of(rec, "name_key")})
	b.base("ui.cost.price", amount)
	if short:
		b.note("ui.cost.short", {"have_c": have})
	b.finish()
	var e: Explainable = Explainable.wrap(panel, b)
	e.name = "Cost_" + res
	return e
