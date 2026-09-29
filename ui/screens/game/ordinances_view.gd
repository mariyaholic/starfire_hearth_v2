class_name OrdinancesView
extends RefCounted
## Ordinances (§5.11, §7): laws with a price, influence to pass and energy every turn. The empire
## has a few slots; a law can be repealed at any time.


static func build(s: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var e: Empire = s.state.player()
	var slots: Breakdown = Ordinances.slots(s.state, e)
	var head: Card = Card.make(Strings.fmt("ui.ordinances.title"), Strings.fmt("ui.ordinances.subtitle"), "ui_edict", "influence.violet")
	head.name = "Ordinances"
	var used: Label = Label.new()
	used.theme_type_variation = &"MonoStrongLabel"
	used.text = "%d / %d" % [e.ordinances.size(), slots.total]
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	var t: Label = FlowScreen.label(Strings.fmt("ui.ordinances.slots"), &"SecondaryLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Explainable.wrap(used, slots))
	head.add_body(row)
	col.add_child(head)
	var locked: Array[String] = Ordinances.locked(s.state)
	for id: String in Content.db().ids("edicts"):
		col.add_child(_card(s, e, id, locked.has(id)))
	return col


static func _card(s: GameScreen, e: Empire, id: String, is_locked: bool) -> Control:
	var rec: Dictionary = Content.db().record("edicts", id)
	var active: bool = e.ordinances.has(id)
	var card: Card = Card.make(GameUI.name_of("edicts", id), "", GameUI.icon_of("edicts", id, "ui_edict"), "hearth.gold" if active else "influence.violet")
	card.name = "Ordinance_" + id
	card.add_text(GameUI.desc_of("edicts", id))
	var effects: Array = DictIO.arr_of(rec, "effects")
	if not effects.is_empty():
		card.add_body(EffectList.make(s.state, effects))
	var upkeep: Dictionary = DictIO.dict_of(rec, "upkeep")
	var duration: int = DictIO.int_of(rec, "duration")
	var facts: HFlowContainer = HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	facts.add_child(GameUI.tag(Strings.fmt("ui.ordinances.price")))
	facts.add_child(GameUI.cost(Ordinances.activation_cost(id), e))
	if not upkeep.is_empty():
		facts.add_child(GameUI.tag(Strings.fmt("ui.ordinances.upkeep")))
		facts.add_child(CostChips.make(Construction._res_map(upkeep)))
	card.add_body(facts)
	var when: Label = GameUI.caption(Strings.fmt("ui.ordinances.lasts", {"turns": duration}) if duration > 0 else Strings.fmt("ui.ordinances.lasts_until_repealed"))
	card.add_body(GameUI.exempt(when, "how long the law lasts"))
	if active:
		var left: int = int(e.ordinances[id])
		if left > 0:
			card.add_body(GameUI.exempt(GameUI.caption(Strings.fmt("ui.ordinances.turns_left", {"turns": left})), "turns left on the law"))
		card.add_action(GameUI.action(Strings.fmt("ui.ordinances.repeal"), "ui_close", Ordinances.can_cancel(s.state, e.id, id), func() -> void:
			s.order(CancelOrdinanceCommand.create(e.id, id)), SfButton.SECONDARY))
	elif is_locked:
		card.add_body(GameUI.caption(Strings.fmt("error.ordinance.locked")))
	else:
		card.add_action(GameUI.action(Strings.fmt("ui.ordinances.pass"), "ui_check", Ordinances.can_activate(s.state, e.id, id), func() -> void:
			s.order(ActivateOrdinanceCommand.create(e.id, id)), SfButton.PRIMARY))
	return card
