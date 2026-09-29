class_name SystemView
extends RefCounted
## A star system (§7): the star, its planets, the ships in orbit, and for the chosen planet its
## survey state, traits, slots and the orders to give it: survey, colonise, build an outpost. Every
## order shows what it costs and, when it is refused, why.

const BEACON_KEYS: Dictionary[String, String] = {"dormant": "ui.system.beacon_dormant", "active": "ui.system.beacon_active"}
const TASK_KEYS: Dictionary[String, String] = {
	"survey": "ui.system.task_survey", "outpost": "ui.system.task_outpost", "colonise": "ui.system.task_colonise",
}
const STAR_KEYS: Dictionary[String, String] = {
	"M": "ui.worlds.star.m", "K": "ui.worlds.star.k", "G": "ui.worlds.star.g", "F": "ui.worlds.star.f",
	"A": "ui.worlds.star.a", "white_dwarf": "ui.worlds.star.white_dwarf", "binary": "ui.worlds.star.binary",
}


static func build(s: GameScreen) -> Control:
	var sys: StarSystem = s.state.systems[s.system_id]
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	var head: Card = Card.make(Strings.fmt(sys.name_key), Strings.fmt(STAR_KEYS.get(sys.spectral, "ui.worlds.star.g")), "emblem_hearth", "hearth.gold")
	head.name = "SystemHeader"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_L)
	var star: StarDisc = StarDisc.make(sys.spectral, sys.magnitude, 72.0)
	row.add_child(star)
	if sys.beacon != StarSystem.BEACON_NONE:
		var b: Label = FlowScreen.label(Strings.fmt(BEACON_KEYS.get(sys.beacon, "ui.system.beacon_dormant")), &"CaptionLabel")
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	head.add_body(row)
	col.add_child(head)
	var left: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	left.add_child(_planets(s, sys))
	left.add_child(_fleets(s, sys))
	var right: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	if s.planet_id.is_empty() or not s.state.planets.has(s.planet_id):
		var hint: Card = Card.make(Strings.fmt("ui.system.pick_title"), "", "map_outpost", "text.secondary")
		hint.add_text(Strings.fmt("ui.system.pick_hint"), &"CaptionLabel")
		right.add_child(hint)
	else:
		right.add_child(_panel(s, s.state.planets[s.planet_id]))
	col.add_child(GameUI.split(left, right))
	return col


static func _planets(s: GameScreen, sys: StarSystem) -> Control:
	var card: Card = Card.make(Strings.fmt("ui.system.planets"), "", "planet_continental", "accent.teal")
	card.name = "Planets"
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	flow.add_theme_constant_override("v_separation", Tokens.SPACE_M)
	var planets: Array[Planet] = []
	for pid: String in sys.planet_ids:
		planets.append(s.state.planets[pid])
	planets.sort_custom(func(a: Planet, b: Planet) -> bool: return a.orbit < b.orbit)
	for p: Planet in planets:
		flow.add_child(_tile(s, p))
	card.add_body(flow)
	return card


static func _tile(s: GameScreen, p: Planet) -> Control:
	var e: Empire = s.state.player()
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Planet_" + p.id
	panel.theme_type_variation = &"RaisedPanel" if p.id == s.planet_id else &"InsetPanel"
	panel.custom_minimum_size = Vector2(112.0 * Settings.text_scale, 0)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette: Array = DictIO.arr_of(Content.db().record("planet_types", p.type), "palette")
	var disc: PlanetDisc = PlanetDisc.make(p.type, palette, p.art_seed, 72.0)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap: CenterContainer = CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(disc)
	v.add_child(wrap)
	var n: Label = FlowScreen.label(Strings.fmt(p.name_key), &"StrongLabel")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var state_key: String = "ui.system.state_free"
	if not p.colony_id.is_empty():
		state_key = "ui.system.state_outpost" if s.state.colonies[p.colony_id].is_outpost() else "ui.system.state_colony"
	elif e.surveyed_planets.has(p.id):
		state_key = "ui.system.state_surveyed"
	var c: Label = FlowScreen.label(Strings.fmt(state_key), &"CaptionLabel")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(c)
	panel.add_child(v)
	var hit: Button = Button.new()
	hit.flat = true
	hit.name = "Pick_" + p.id
	hit.pressed.connect(s.select_planet.bind(p.id))
	panel.add_child(hit)
	return panel


## The chosen planet: what is known of it and what can be ordered.
static func _panel(s: GameScreen, p: Planet) -> Control:
	var st: GameState = s.state
	var e: Empire = st.player()
	var kind: String = GameUI.name_of("planet_types", p.type)
	if not p.size.is_empty():
		kind = Strings.fmt("ui.system.kind_size", {"size_key": DictIO.str_of(Content.db().record("planet_sizes", p.size), "name_key"), "type_key": DictIO.str_of(Content.db().record("planet_types", p.type), "name_key")})
	var card: Card = Card.make(Strings.fmt(p.name_key), kind, GameUI.icon_of("planet_types", p.type, "map_outpost"), "accent.teal")
	card.name = "PlanetPanel"
	card.add_text(GameUI.desc_of("planet_types", p.type), &"CaptionLabel")
	var surveyed: bool = e.surveyed_planets.has(p.id)
	if surveyed:
		for trait_id: String in p.traits:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", Tokens.SPACE_S)
			row.add_child(SfIcon.make(GameUI.icon_of("traits", trait_id, "trait_locked"), Tokens.ICON_M, "text.secondary"))
			row.add_child(GameUI.grow(GameUI.name_of("traits", trait_id), &"StrongLabel"))
			card.add_body(row)
			card.add_text(GameUI.desc_of("traits", trait_id), &"CaptionLabel")
		var slots: int = ColonyRules.slot_count(p)
		if slots > 0:
			var sl: Label = GameUI.caption(Strings.fmt("ui.system.slots", {"count": slots, "blocked": p.blocked_slots.size()}))
			card.add_body(GameUI.exempt(sl, "the planet's slot count"))
	else:
		card.add_text(Strings.fmt("ui.system.unsurveyed"))
	if not p.colony_id.is_empty():
		var c: Colony = st.colonies[p.colony_id]
		if c.owner_id == e.id and not c.is_outpost():
			var open: SfButton = SfButton.make("ui.system.open_colony", "ui_colony", SfButton.PRIMARY)
			open.name = "OpenColony"
			open.pressed.connect(s.open_colony.bind(c.id))
			card.add_action(open)
		return card
	card.add_body(GameUI.heading(Strings.fmt("ui.system.orders")))
	var any: bool = false
	for sh: Ship in st.ships_of(e.id):
		if Ships.system_of(st, sh) != p.system_id:
			continue
		var hull_key: String = DictIO.str_of(Content.db().record("hulls", sh.hull), "name_key")
		match Ships.role(sh):
			Ships.ROLE_SURVEY:
				if not surveyed:
					any = true
					var cmd: SurveyCommand = SurveyCommand.create(e.id, sh.id, p.id)
					var a: VBoxContainer = GameUI.action(Strings.fmt("ui.system.survey_with", {"ship_key": hull_key}), "ship_survey", cmd.validate(st), func() -> void:
						s.order(SurveyCommand.create(e.id, sh.id, p.id)), SfButton.PRIMARY)
					a.name = "Survey_" + sh.id
					card.add_body(a)
			Ships.ROLE_COLONY:
				if surveyed and ColonyRules.outpost_kinds(p).is_empty():
					any = true
					var cmd2: ColoniseCommand = ColoniseCommand.create(e.id, sh.id, p.id)
					var a2: VBoxContainer = GameUI.action(Strings.fmt("ui.system.colonise_with", {"ship_key": hull_key}), "ship_colony", cmd2.validate(st), func() -> void:
						s.order(ColoniseCommand.create(e.id, sh.id, p.id)), SfButton.PRIMARY)
					a2.name = "Colonise_" + sh.id
					card.add_body(a2)
			Ships.ROLE_CONSTRUCTION:
				if surveyed:
					for kind_id: String in ColonyRules.outpost_kinds(p):
						any = true
						card.add_body(_outpost(s, e, sh, p, kind_id, hull_key))
	if not any:
		card.add_body(GameUI.caption(Strings.fmt(_no_orders_key(s, p, surveyed))))
	return card


static func _outpost(s: GameScreen, e: Empire, sh: Ship, p: Planet, kind_id: String, hull_key: String) -> Control:
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	var cmd: BuildOutpostCommand = BuildOutpostCommand.create(e.id, sh.id, p.id, kind_id)
	var res_key: String = DictIO.str_of(Content.db().record("resources", kind_id), "name_key")
	var a: VBoxContainer = GameUI.action(Strings.fmt("ui.system.outpost_with", {"resource_key": res_key, "ship_key": hull_key}), "map_outpost", cmd.validate(s.state), func() -> void:
		s.order(BuildOutpostCommand.create(e.id, sh.id, p.id, kind_id)), SfButton.PRIMARY)
	a.name = "Outpost_" + kind_id
	v.add_child(a)
	var cost: Breakdown = Ships.outpost_cost(s.state, e)
	var chip: Explainable = CostChips.chip("influence", cost.total, e.stock_of("influence") < cost.total, e.stock_of("influence")) as Explainable
	chip.set_breakdown(cost)
	var turns: Breakdown = Ships.outpost_turns(s.state, e)
	var tl: Label = GameUI.tag(Strings.fmt("ui.system.takes_turns", {"turns": turns.total}))
	var line: HFlowContainer = HFlowContainer.new()
	line.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	line.add_child(chip)
	line.add_child(Explainable.wrap(tl, turns))
	v.add_child(line)
	return v


## Why a planet has no orders: the ship it needs is elsewhere, busy, or not built yet.
static func _no_orders_key(s: GameScreen, p: Planet, surveyed: bool) -> String:
	if not surveyed:
		return "ui.system.need_survey_ship"
	if not ColonyRules.outpost_kinds(p).is_empty():
		return "ui.system.need_construction_ship"
	return "ui.system.need_colony_ship"


static func _fleets(s: GameScreen, sys: StarSystem) -> Control:
	var card: Card = Card.make(Strings.fmt("ui.system.ships"), "", "ship_fleet", "accent.teal")
	card.name = "Ships"
	var here: int = 0
	for sh: Ship in s.state.ships_of(s.state.player_id):
		if Ships.system_of(s.state, sh) != sys.id:
			continue
		here += 1
		var hull: Dictionary = Content.db().record("hulls", sh.hull)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Ship_" + sh.id
		row.add_theme_constant_override("separation", Tokens.SPACE_S)
		row.add_child(SfIcon.make(DictIO.str_of(hull, "icon", "ship_fleet"), Tokens.ICON_L, "text.primary"))
		var texts: VBoxContainer = GameUI.column(0)
		texts.add_child(FlowScreen.label(Strings.fmt(DictIO.str_of(hull, "name_key")), &"StrongLabel"))
		texts.add_child(GameUI.exempt(GameUI.caption(_task_text(s.state, sh)), "turns left on the ship's task"))
		row.add_child(texts)
		card.add_body(row)
	if here == 0:
		card.add_text(Strings.fmt("ui.system.no_ships"), &"CaptionLabel")
	return card


static func _task_text(state: GameState, sh: Ship) -> String:
	if not sh.is_busy():
		return Strings.fmt("ui.system.ship_idle")
	var planet_key: String = state.planets[sh.task_target].name_key if state.planets.has(sh.task_target) else ""
	return Strings.fmt(TASK_KEYS.get(sh.task, "ui.system.ship_idle"), {"planet_key": planet_key, "turns": sh.task_turns})
