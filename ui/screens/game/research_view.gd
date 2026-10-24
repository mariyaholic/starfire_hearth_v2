class_name ResearchView
extends RefCounted
## Research (§5.7, §7): three branches, each studying one card at a time and offering a hand of up
## to three. Every cost is a breakdown; a branch with no card picked earns nothing yet.

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]


static func build(s: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var e: Empire = s.state.player()
	var box: BoxContainer
	if Layout.compact:
		box = VBoxContainer.new()
	else:
		box = HBoxContainer.new()
	box.name = "Branches"
	box.add_theme_constant_override("separation", Tokens.SPACE_L)
	for branch: String in Empire.BRANCHES:
		var c: Card = _branch(s, e, branch)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(c)
	col.add_child(box)
	col.add_child(_known(e))
	return col


static func _branch(s: GameScreen, e: Empire, branch: String) -> Card:
	var rb: ResearchBranch = e.research.get(branch, null)
	var card: Card = Card.make(Strings.fmt(Names.branch(branch)), "", "branch_" + branch, "sci.cyan")
	card.name = "Branch_" + branch
	var rate: Breakdown = s.report.research[branch]
	var rate_l: Label = Label.new()
	rate_l.theme_type_variation = &"MonoStrongLabel"
	rate_l.text = Strings.fmt("ui.fmt.rate", {"value": Fmt.centi(rate.total), "resource": Strings.fmt("res.research.name")})
	card.add_body(Explainable.wrap(rate_l, rate))
	if rb == null:
		return card
	if not rb.card.is_empty():
		card.add_body(_current(s, e, branch, rb, rate.total))
	if not rb.hand.is_empty():
		card.add_body(GameUI.heading(Strings.fmt("ui.research.cards")))
		for tech_id: String in rb.hand:
			card.add_body(_offer(s, e, branch, rb, tech_id))
		var reroll: RerollResearchCommand = RerollResearchCommand.create(e.id, branch)
		var rr: VBoxContainer = GameUI.action(Strings.fmt("ui.research.reroll"), "ui_reroll", reroll.validate(s.state), func() -> void:
			s.order(RerollResearchCommand.create(e.id, branch)), SfButton.GHOST)
		rr.name = "Reroll_" + branch
		card.add_body(rr)
		var cost: Label = Label.new()
		cost.theme_type_variation = &"MonoCaptionLabel"
		var rb_cost: Breakdown = Breakdown.for_resource("breakdown.reroll_cost", "influence", false)
		rb_cost.base("source.reroll_price", Research.REROLL_COST)
		rb_cost.finish()
		cost.text = Strings.fmt("ui.research.reroll_cost", {"cost_c": Research.REROLL_COST})
		card.add_body(Explainable.wrap(cost, rb_cost))
	elif rb.card.is_empty():
		card.add_text(Strings.fmt("ui.research.nothing_new"), &"CaptionLabel")
	return card


## The card being studied: its progress against its cost, and what it will do.
static func _current(s: GameScreen, e: Empire, branch: String, rb: ResearchBranch, rate: int) -> Control:
	var tech: Dictionary = Content.db().record("techs", rb.card)
	var cost: Breakdown = Research.cost(s.state, e, rb.card)
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_S)
	v.name = "Current_" + branch
	v.add_child(GameUI.heading(Strings.fmt("ui.research.studying")))
	v.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(tech, "name_key")), &"H2Label"))
	var m: Meter = Meter.make(float(mini(rb.progress, cost.total)), float(maxi(1, cost.total)), "sci.cyan")
	v.add_child(m)
	var prog: Label = Label.new()
	prog.theme_type_variation = &"MonoLabel"
	prog.text = Strings.fmt("ui.research.progress", {"have_c": mini(rb.progress, cost.total), "need_c": cost.total})
	v.add_child(Explainable.wrap(prog, cost))
	if rate > 0:
		var turns: int = Fx.div_ceil(maxi(0, cost.total - rb.progress), rate)
		v.add_child(GameUI.exempt(GameUI.caption(Strings.fmt("ui.research.eta", {"turns": turns})), "an estimate from the cost and the branch's rate"))
	v.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(tech, "desc_key")), &"CaptionLabel"))
	var fx: Array = DictIO.arr_of(tech, "effects")
	if not fx.is_empty():
		v.add_child(EffectList.make(s.state, fx))
	return GameUI.panel(v, &"RaisedPanel")


static func _offer(s: GameScreen, e: Empire, branch: String, rb: ResearchBranch, tech_id: String) -> Control:
	var tech: Dictionary = Content.db().record("techs", tech_id)
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	v.name = "Offer_" + tech_id
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", Tokens.SPACE_S)
	var n: Label = FlowScreen.label(Strings.fmt(DictIO.str_of(tech, "name_key")), &"StrongLabel")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(GameUI.tag(Strings.fmt("ui.research.tier", {"tier": _roman(DictIO.int_of(tech, "tier", 1))})))
	v.add_child(head)
	v.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(tech, "desc_key")), &"CaptionLabel"))
	var fx: Array = DictIO.arr_of(tech, "effects")
	if not fx.is_empty():
		v.add_child(EffectList.make(s.state, fx))
	var cost: Breakdown = Research.cost(s.state, e, tech_id)
	var cl: Label = Label.new()
	cl.theme_type_variation = &"MonoLabel"
	cl.text = Strings.fmt("ui.research.cost", {"cost_c": cost.total})
	v.add_child(Explainable.wrap(cl, cost))
	if rb.card == tech_id:
		v.add_child(GameUI.caption(Strings.fmt("error.research.already_picked")))
	else:
		var pick: PickResearchCommand = PickResearchCommand.create(e.id, branch, tech_id)
		var act: VBoxContainer = GameUI.action(Strings.fmt("ui.research.pick"), "ui_check", pick.validate(s.state), func() -> void:
			s.order(PickResearchCommand.create(e.id, branch, tech_id)), SfButton.PRIMARY if rb.card.is_empty() else SfButton.SECONDARY)
		act.name = "Pick_" + tech_id
		v.add_child(act)
	return GameUI.panel(v)


## Everything researched so far, by branch.
static func _known(e: Empire) -> Control:
	var card: Card = Card.make(Strings.fmt("ui.research.known"), "", "ui_tree", "sci.cyan")
	card.name = "Known"
	if e.techs.is_empty():
		card.add_text(Strings.fmt("ui.research.none_yet"), &"CaptionLabel")
		return card
	for branch: String in Empire.BRANCHES:
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", Tokens.SPACE_S)
		flow.add_theme_constant_override("v_separation", Tokens.SPACE_S)
		for tech_id: String in e.techs:
			var tech: Dictionary = Content.db().record("techs", tech_id)
			if DictIO.str_of(tech, "branch") != branch:
				continue
			var chip: PanelContainer = PanelContainer.new()
			chip.theme_type_variation = &"ChipPanel"
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", Tokens.SPACE_XS)
			row.add_child(SfIcon.make("branch_" + branch, Tokens.ICON_S, "sci.cyan"))
			row.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(tech, "name_key")), &"CaptionLabel"))
			chip.add_child(row)
			flow.add_child(chip)
		if flow.get_child_count() > 0:
			card.add_body(GameUI.caption(Strings.fmt(Names.branch(branch))))
			card.add_body(flow)
	return card


static func _roman(tier: int) -> String:
	return ROMAN[clampi(tier, 1, ROMAN.size()) - 1]
