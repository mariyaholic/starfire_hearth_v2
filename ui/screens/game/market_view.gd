class_name MarketView
extends RefCounted
## The market (§5.3, §7): energy buys and sells food, minerals and metals at fixed rates, in lots.
## Every trade shows its exact rate, and happens at once.


static func build(s: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var card: Card = Card.make(Strings.fmt("ui.market.title"), Strings.fmt("ui.market.subtitle"), "bld_market_exchange", "energy.yellow")
	card.name = "Market"
	var e: Empire = s.state.player()
	var db: ContentDb = Content.db()
	for res: String in Market.RATES.keys():
		var block: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
		block.name = "Trade_" + res
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", Tokens.SPACE_S)
		head.add_child(SfIcon.make(GameUI.icon_of("resources", res), Tokens.ICON_M, GameUI.token_of(res)))
		var t: Label = FlowScreen.label(GameUI.name_of("resources", res), &"StrongLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var have: Label = Label.new()
		have.theme_type_variation = &"MonoLabel"
		have.text = Fmt.stock(e.stock_of(res))
		head.add_child(Explainable.wrap(have, s.report.net[res]))
		block.add_child(head)
		var buy_q: Breakdown = Market.quote(res, Market.LOT, true)
		var sell_q: Breakdown = Market.quote(res, Market.LOT, false)
		var row: HFlowContainer = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", Tokens.SPACE_L)
		row.add_theme_constant_override("v_separation", Tokens.SPACE_S)
		row.add_child(_trade(s, res, true, buy_q))
		row.add_child(_trade(s, res, false, sell_q))
		block.add_child(row)
		card.add_body(GameUI.panel(block))
	var note: Label = card.add_text(Strings.fmt("ui.market.note", {"lot_c": Market.LOT, "max": Market.MAX_LOTS}), &"CaptionLabel")
	GameUI.exempt(note, "the market's lot size and limit, quoted from the rules")
	col.add_child(card)
	return col


static func _trade(s: GameScreen, res: String, buying: bool, quote: Breakdown) -> Control:
	var v: VBoxContainer = GameUI.column(2)
	var r: Result = Market.can_trade(s.state, s.state.player_id, res, 1, buying)
	var key: String = "ui.market.buy" if buying else "ui.market.sell"
	var act: VBoxContainer = GameUI.action(Strings.fmt(key), "ui_plus" if buying else "ui_minus", r, func() -> void:
		s.order(TradeCommand.create(s.state.player_id, res, 1, buying)))
	act.name = ("Buy_" if buying else "Sell_") + res
	v.add_child(act)
	var price: Label = Label.new()
	price.theme_type_variation = &"MonoCaptionLabel"
	var energy: int = absi(quote.total)
	price.text = Strings.fmt("ui.market.price", {"price_c": energy})
	v.add_child(Explainable.wrap(price, quote))
	return v
