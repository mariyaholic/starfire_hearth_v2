class_name ColonyView
extends RefCounted
## The colony planner (§7 screen 6): the colony's numbers, its hex grid, the menu for the chosen
## slot with a preview of what a new district or building would change, the build queue, job
## priority, the governor and the shipyard. Every number explains itself; every refused order says why.

const KIND_KEYS: Dictionary[String, String] = {"district": "ui.colony.kind_district", "building": "ui.colony.kind_building"}
const FOCUS_KEYS: Dictionary[String, String] = {
	"balanced": "ui.governor.focus_balanced", "food": "ui.governor.focus_food", "industry": "ui.governor.focus_industry",
	"research": "ui.governor.focus_research", "growth": "ui.governor.focus_growth", "stability": "ui.governor.focus_stability",
}
const GROUP_ICONS: Dictionary[String, String] = {
	"food": "res_food", "energy": "res_energy", "minerals": "res_minerals", "alloys": "res_alloys",
	"research": "res_research", "clerks": "ui_advisor",
}


static func build(s: GameScreen) -> Control:
	var col: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	col.add_child(_tabs(s))
	var c: Colony = s.state.colonies.get(s.colony_id, null)
	if c == null:
		return col
	var cr: Economy.ColonyReport = s.report.colonies.get(c.id, null)
	if c.is_outpost():
		col.add_child(_outpost(s, c, cr))
		return col
	col.add_child(_stats(s, c, cr))
	var planner: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	planner.add_child(_planner(s, c, cr))
	var menu: Control = _slot_menu(s, c, cr)
	var side: VBoxContainer = GameUI.column(Tokens.SPACE_M)
	side.add_child(menu)
	side.add_child(_queue(s, c))
	col.add_child(GameUI.split(planner, side))
	col.add_child(GameUI.split(_jobs(s, c, cr), _governor(s, c)))
	if Construction.provides(c, "spaceport"):
		col.add_child(_shipyard(s, c))
	return col


static func _tabs(s: GameScreen) -> Control:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = "ColonyTabs"
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	for c: Colony in s.state.colonies_of(s.state.player_id):
		var b: SfButton = SfButton.make("", "map_outpost" if c.is_outpost() else "ui_colony", SfButton.TAB)
		b.text = GameUI.colony_name(s.state, c)
		b.name = "Colony_" + c.id
		b.button_group = group
		b.button_pressed = c.id == s.colony_id
		b.pressed.connect(s.select_colony.bind(c.id))
		flow.add_child(b)
	return flow


static func _outpost(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Control:
	var planet: Planet = s.state.planets[c.planet_id]
	var card: Card = Card.make(GameUI.colony_name(s.state, c), Strings.fmt(Names.stage("outpost")), "map_outpost", "accent.teal")
	card.name = "OutpostCard"
	card.add_text(Strings.fmt("ui.colony.outpost_note", {"planet_key": planet.name_key}))
	if cr != null:
		for res: String in cr.net.keys():
			var b: Breakdown = cr.net[res]
			card.add_body(GameUI.stat(GameUI.icon_of("resources", res), GameUI.token_of(res), GameUI.name_of("resources", res), Fmt.centi(b.total, true, 2), b))
		for branch: String in cr.research.keys():
			var rb: Breakdown = cr.research[branch]
			card.add_body(GameUI.stat("res_research", "sci.cyan", Strings.fmt("res.research.name"), Fmt.centi(rb.total, true, 2), rb))
	return card


# --- The colony's numbers ----------------------------------------------------------------------

static func _stats(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Control:
	var e: Empire = s.state.player()
	var planet: Planet = s.state.planets[c.planet_id]
	var card: Card = Card.make(GameUI.colony_name(s.state, c), Strings.fmt(Names.stage(ColonyRules.stage(c))), "ui_colony", "accent.teal")
	card.name = "ColonyStats"
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_XL)
	flow.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	var growth: Breakdown = Population.growth(s.state, c, cr, s.report.net_of("food"), e.stock_of("food"))
	var gpct: String = Strings.percent(Fx.div_floor(growth.total * 10000, Population.GROWTH_NEEDED))
	var stability: Breakdown = Stability.target(s.state, c, cr)
	var items: Array[Control] = [
		GameUI.stat("stat_pops", "text.secondary", Strings.fmt("ui.colony.settlers"), GameUI.pops(c.pops), null, "the colony's settlers, counted in thousands"),
		GameUI.stat("stat_housing", "text.secondary", Strings.fmt("ui.colony.housing"), Fmt.total(cr.housing), cr.housing),
		GameUI.stat("ui_governor", "text.secondary", Strings.fmt("ui.colony.jobs"), "%d / %d" % [cr.employed, cr.jobs_total], null, "settlers at work over jobs on offer"),
		GameUI.stat("stat_growth", "text.secondary", Strings.fmt("ui.colony.growth"), gpct, growth),
		GameUI.stat("stat_stability", "text.secondary", Strings.fmt("ui.colony.stability"), str(c.stability), stability),
	]
	items[4].name = "Stat_stability"
	for it: Control in items:
		it.custom_minimum_size.x = 210.0 * Settings.text_scale
		flow.add_child(it)
	card.add_body(flow)
	var m: Meter = Meter.make(float(c.growth), float(Population.GROWTH_NEEDED), "accent.teal")
	m.name = "GrowthMeter"
	card.add_body(m)
	if cr.unemployed > 0:
		card.add_body(_warn(Strings.fmt("ui.colony.unemployed", {"count": cr.unemployed})))
	if cr.homeless > 0:
		card.add_body(_warn(Strings.fmt("ui.colony.homeless", {"count": cr.homeless})))
	var why: SfButton = SfButton.make("ui.colony.why", "ui_why", SfButton.GHOST)
	why.name = "WhyStability"
	why.pressed.connect(s.open_why.bind("colony", c.id))
	card.add_action(why)
	return card


static func _warn(text: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	row.add_child(SfIcon.make("alert_warning", Tokens.ICON_S, Tokens.NEGATIVE))
	row.add_child(GameUI.grow(text, &"CaptionLabel"))
	return GameUI.exempt(row, "settlers without work or homes, counted from the colony")


# --- The hex planner ---------------------------------------------------------------------------

## Places hex cells at their axial coordinates (the same ones the rules use for adjacency).
class PlannerGrid:
	extends Control

	var radius: float = 30.0
	var _cells: Array[HexCell] = []
	var _slots: Array[int] = []
	var _centers: Array[Vector2] = []
	var _origin: Vector2 = Vector2.ZERO

	func setup(count: int, r: float, band: float) -> void:
		radius = r
		var coords: Array[Vector2i] = HexGrid.coords(count)
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		for q: Vector2i in coords:
			var p: Vector2 = Vector2(sqrt(3.0) * r * (q.x + q.y / 2.0), 1.5 * r * q.y)
			_centers.append(p)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var cell: Vector2 = HexCell.cell_size(r)
		_origin = Vector2(cell.x / 2.0 - lo.x, r + band - lo.y)
		custom_minimum_size = Vector2(hi.x - lo.x + cell.x, hi.y - lo.y + cell.y + band)

	func add_cell(i: int, h: HexCell) -> void:
		h.radius = radius
		add_child(h)
		_cells.append(h)
		_slots.append(i)

	func _ready() -> void:
		_layout()

	## A cell that shows adjacency chips is taller than the hex, so it is placed by its centre.
	func _layout() -> void:
		for n in _cells.size():
			var h: HexCell = _cells[n]
			h.size = h.get_combined_minimum_size()
			h.position = _origin + _centers[_slots[n]] - h.hex_center()


static func _planner(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Control:
	var planet: Planet = s.state.planets[c.planet_id]
	var card: Card = Card.make(Strings.fmt("ui.colony.planner"), Strings.fmt("ui.colony.planner_hint"), "district_habitation", "accent.teal")
	card.name = "Planner"
	var count: int = cr.slots
	var grid: PlannerGrid = PlannerGrid.new()
	grid.name = "PlannerGrid"
	var r: float = 26.0 if Layout.compact else 34.0
	grid.setup(count, r, 34.0 * Settings.text_scale)
	var ghost: Array[Dictionary] = []
	if s.slot >= 0 and not s.pick.is_empty():
		ghost = _preview(s, c, cr)
	for i in count:
		grid.add_cell(i, _cell(s, c, planet, i, ghost))
	var center: CenterContainer = CenterContainer.new()
	center.add_child(grid)
	card.add_body(center)
	return card


static func _cell(s: GameScreen, c: Colony, planet: Planet, i: int, ghost: Array[Dictionary]) -> HexCell:
	var h: HexCell
	var d: Colony.PlacedDistrict = c.district_at(i)
	var b: Colony.PlacedBuilding = c.building_at(i)
	var q: BuildItem = c.queued_at(i)
	if planet.blocked_slots.has(i):
		h = HexCell.new()
		h.state = HexCell.STATE_BLOCKED
	elif d != null:
		h = HexCell.for_district(d.district_id, GameUI.icon_of("districts", d.district_id), d.tier, HexCell.STATE_BUILT)
	elif b != null:
		h = HexCell.for_district("", GameUI.icon_of("buildings", b.building_id, "bld_storehouse"), 0, HexCell.STATE_BUILT)
	elif q != null:
		var table: String = "districts" if q.kind == BuildItem.KIND_DISTRICT else "buildings"
		h = HexCell.for_district(q.def_id if q.kind == BuildItem.KIND_DISTRICT else "", GameUI.icon_of(table, q.def_id), q.tier, HexCell.STATE_BUILDING)
		h.progress = 100 * (q.total_turns - q.turns_left) / maxi(1, q.total_turns)
	elif i == s.slot and not s.pick.is_empty():
		var table2: String = "districts" if s.pick_kind == "district" else "buildings"
		h = HexCell.for_district(s.pick if s.pick_kind == "district" else "", GameUI.icon_of(table2, s.pick), 1, HexCell.STATE_GHOST)
		var shown: Array[Dictionary] = []
		for g: Dictionary in ghost:
			if shown.size() < 2 and str(g.get("kind", "")) == "output":
				shown.append({"text": g["text"], "positive": g["positive"]})
		h.deltas = shown
	else:
		h = HexCell.new()
		h.state = HexCell.STATE_EMPTY
	h.name = "Slot_%d" % i
	h.selected = i == s.slot
	h.pressed.connect(s.select_slot.bind(i))
	return h


## What a district or building would change once built: net output, research, homes and jobs,
## found by adding it to a copy of the state and comparing the colony's report.
static func _preview(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Array[Dictionary]:
	var st2: GameState = s.state.clone()
	var c2: Colony = st2.colonies[c.id]
	if s.pick_kind == "district":
		var pd: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
		pd.slot = s.slot
		pd.district_id = s.pick
		pd.tier = 1
		pd.branch = s.branch_pick if s.pick == "research" else ""
		c2.districts.append(pd)
	else:
		var pb: Colony.PlacedBuilding = Colony.PlacedBuilding.new()
		pb.slot = s.slot
		pb.building_id = s.pick
		c2.buildings.append(pb)
	var after: Economy.ColonyReport = Economy.colony(st2, c2)
	var out: Array[Dictionary] = []
	for res: String in Economy.PRODUCED:
		var dv: int = after.net_of(res) - cr.net_of(res)
		if dv != 0:
			out.append({"kind": "output", "icon": GameUI.icon_of("resources", res), "token": GameUI.token_of(res), "text": Fmt.centi(dv, true, 1), "value": dv, "positive": dv > 0, "name": GameUI.name_of("resources", res)})
	var dr: int = after.research_total() - cr.research_total()
	if dr != 0:
		out.append({"kind": "output", "icon": "res_research", "token": "sci.cyan", "text": Fmt.centi(dr, true, 1), "value": dr, "positive": dr > 0, "name": Strings.fmt("res.research.name")})
	var dh: int = after.housing.total - cr.housing.total
	if dh != 0:
		out.append({"kind": "homes", "icon": "stat_housing", "token": "text.secondary", "text": Fmt.points(dh), "value": dh, "positive": dh > 0, "name": Strings.fmt("ui.colony.housing")})
	var dj: int = after.jobs_total - cr.jobs_total
	if dj != 0:
		out.append({"kind": "jobs", "icon": "ui_governor", "token": "text.secondary", "text": Fmt.points(dj), "value": dj, "positive": dj > 0, "name": Strings.fmt("ui.colony.jobs")})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absi(int(a["value"])) > absi(int(b["value"])))
	return out


# --- The chosen slot ---------------------------------------------------------------------------

static func _slot_menu(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Control:
	var planet: Planet = s.state.planets[c.planet_id]
	var card: Card = Card.make(Strings.fmt("ui.colony.slot_title"), "", "ui_plus", "accent.teal")
	card.name = "SlotMenu"
	if s.slot < 0:
		card.add_text(Strings.fmt("ui.colony.pick_slot"), &"CaptionLabel")
		return card
	var e: Empire = s.state.player()
	var d: Colony.PlacedDistrict = c.district_at(s.slot)
	var b: Colony.PlacedBuilding = c.building_at(s.slot)
	var q: BuildItem = c.queued_at(s.slot)
	if planet.blocked_slots.has(s.slot):
		card.add_text(Strings.fmt("error.build.blocked_slot"), &"CaptionLabel")
	elif d != null:
		_built_district(s, c, e, d, card)
	elif b != null:
		_built_building(s, c, e, b, card)
	elif q != null:
		card.add_text(Strings.fmt("error.build.busy_slot"), &"CaptionLabel")
	else:
		_options(s, c, e, cr, card)
	return card


static func _built_district(s: GameScreen, c: Colony, e: Empire, d: Colony.PlacedDistrict, card: Card) -> void:
	card.set_heading(GameUI.name_of("districts", d.district_id), Strings.fmt("ui.colony.tier", {"tier": ResearchView._roman(d.tier)}), GameUI.icon_of("districts", d.district_id), "accent.teal")
	card.add_text(GameUI.desc_of("districts", d.district_id), &"CaptionLabel")
	var up: UpgradeDistrictCommand = UpgradeDistrictCommand.create(e.id, c.id, d.slot)
	var res: Result = up.validate(s.state)
	var a: VBoxContainer = GameUI.action(Strings.fmt("ui.colony.upgrade"), "ui_upgrade", res, func() -> void:
		s.order(UpgradeDistrictCommand.create(e.id, c.id, d.slot)), SfButton.PRIMARY)
	a.name = "Upgrade"
	card.add_body(a)
	if res.ok or res.reason_key == "error.build.cannot_afford":
		card.add_body(GameUI.cost(Construction.upgrade_cost(d.district_id, d.tier), e))
	card.add_body(_demolish(s, c, e, d.slot))


static func _built_building(s: GameScreen, c: Colony, e: Empire, b: Colony.PlacedBuilding, card: Card) -> void:
	card.set_heading(GameUI.name_of("buildings", b.building_id), "", GameUI.icon_of("buildings", b.building_id, "bld_storehouse"), "accent.teal")
	card.add_text(GameUI.desc_of("buildings", b.building_id), &"CaptionLabel")
	var fx: Array = DictIO.arr_of(Content.db().record("buildings", b.building_id), "effects")
	if not fx.is_empty():
		card.add_body(EffectList.make(s.state, fx, c.id))
	card.add_body(_demolish(s, c, e, b.slot))


static func _demolish(s: GameScreen, c: Colony, e: Empire, slot: int) -> Control:
	var cmd: DemolishCommand = DemolishCommand.create(e.id, c.id, slot)
	var a: VBoxContainer = GameUI.action(Strings.fmt("ui.colony.demolish"), "ui_demolish", cmd.validate(s.state), func() -> void:
		s.order(DemolishCommand.create(e.id, c.id, slot)), SfButton.DANGER)
	a.name = "Demolish"
	return a


## The choices for an empty slot: districts or buildings, each with its cost and time, and for
## the one picked, what it would change and the button to queue it.
static func _options(s: GameScreen, c: Colony, e: Empire, cr: Economy.ColonyReport, card: Card) -> void:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	for kind: String in ["district", "building"]:
		var t: SfButton = SfButton.make(KIND_KEYS[kind], "district_habitation" if kind == "district" else "bld_storehouse", SfButton.TAB)
		t.name = "Kind_" + kind
		t.button_group = group
		t.button_pressed = s.pick_kind == kind
		t.pressed.connect(func() -> void:
			if s.pick_kind != kind:
				s.set_pick(kind, ""))
		tabs.add_child(t)
	card.add_body(tabs)
	var ids: Array[String] = []
	var table: String = "districts" if s.pick_kind == "district" else "buildings"
	for id: String in Content.db().ids(table):
		if s.pick_kind == "building" and DictIO.bool_of(Content.db().record("buildings", id), "landmark"):
			continue
		ids.append(id)
	var pick_group: ButtonGroup = ButtonGroup.new()
	for id: String in ids:
		var v: VBoxContainer = GameUI.column(2)
		var b: SfButton = SfButton.make("", GameUI.icon_of(table, id), SfButton.TAB)
		b.text = GameUI.name_of(table, id)
		b.name = "Option_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_group = pick_group
		b.button_pressed = s.pick == id
		b.pressed.connect(s.set_pick.bind(s.pick_kind, id))
		v.add_child(b)
		var cost: Dictionary[String, int] = Construction.district_cost(id) if s.pick_kind == "district" else Construction.building_cost(id)
		var line: HFlowContainer = HFlowContainer.new()
		line.add_theme_constant_override("h_separation", Tokens.SPACE_M)
		line.add_child(GameUI.cost(cost, e))
		var turns: int = Construction.build_turns(s.pick_kind, id)
		line.add_child(GameUI.exempt(GameUI.tag(Strings.fmt("ui.colony.takes_turns", {"turns": turns})), "build time from the data"))
		v.add_child(line)
		card.add_body(v)
	if s.pick.is_empty() or not ids.has(s.pick):
		return
	card.add_body(GameUI.heading(GameUI.name_of(table, s.pick)))
	card.add_text(GameUI.desc_of(table, s.pick), &"CaptionLabel")
	var fx: Array = DictIO.arr_of(Content.db().record(table, s.pick), "effects")
	if not fx.is_empty():
		card.add_body(EffectList.make(s.state, fx, c.id))
	if s.pick_kind == "district" and s.pick == "research":
		card.add_body(_branches(s))
	card.add_body(_preview_line(_preview(s, c, cr)))
	var res: Result
	var go: Callable
	if s.pick_kind == "district":
		var branch: String = s.branch_pick if s.pick == "research" else ""
		res = PlaceDistrictCommand.create(e.id, c.id, s.slot, s.pick, branch).validate(s.state)
		go = func() -> void:
			s.order(PlaceDistrictCommand.create(e.id, c.id, s.slot, s.pick, branch))
	else:
		res = BuildBuildingCommand.create(e.id, c.id, s.slot, s.pick).validate(s.state)
		go = func() -> void:
			s.order(BuildBuildingCommand.create(e.id, c.id, s.slot, s.pick))
	var build: VBoxContainer = GameUI.action(Strings.fmt("ui.colony.build"), "ui_plus", res, go, SfButton.PRIMARY)
	build.name = "Build"
	card.add_body(build)


static func _branches(s: GameScreen) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "BranchPick"
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	for branch: String in Empire.BRANCHES:
		var b: SfButton = SfButton.make(Names.branch(branch), "branch_" + branch, SfButton.TAB)
		b.name = "Branch_" + branch
		b.button_group = group
		b.button_pressed = s.branch_pick == branch
		b.pressed.connect(s.set_branch.bind(branch))
		row.add_child(b)
	return row


static func _preview_line(changes: Array[Dictionary]) -> Control:
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	v.name = "Preview"
	v.add_child(GameUI.caption(Strings.fmt("ui.colony.would_change")))
	if changes.is_empty():
		v.add_child(GameUI.caption(Strings.fmt("ui.colony.no_change")))
		return v
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	for ch: Dictionary in changes:
		var chip: PanelContainer = PanelContainer.new()
		chip.theme_type_variation = &"ChipPanel"
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_XS)
		row.add_child(SfIcon.make(str(ch["icon"]), Tokens.ICON_S, str(ch["token"])))
		var l: Label = Label.new()
		l.theme_type_variation = &"MonoLabel"
		l.text = str(ch["text"])
		l.add_theme_color_override("font_color", Tokens.color(Tokens.POSITIVE if bool(ch["positive"]) else Tokens.NEGATIVE))
		row.add_child(l)
		chip.add_child(row)
		chip.tooltip_text = str(ch["name"])
		flow.add_child(GameUI.exempt(chip, "the change this would make, computed on a copy of the colony"))
	v.add_child(flow)
	return v


# --- Queue, jobs, governor, shipyard -----------------------------------------------------------

static func _queue(s: GameScreen, c: Colony) -> Control:
	var e: Empire = s.state.player()
	var card: Card = Card.make(Strings.fmt("ui.colony.queue"), "", "ui_queue", "accent.teal")
	card.name = "Queue"
	if c.queue.is_empty():
		card.add_text(Strings.fmt("ui.colony.queue_empty"), &"CaptionLabel")
		return card
	for i in c.queue.size():
		var item: BuildItem = c.queue[i]
		var table: String = _table_of(item.kind)
		var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
		v.name = "Item_" + item.id
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", Tokens.SPACE_S)
		head.add_child(SfIcon.make(GameUI.icon_of(table, item.def_id), Tokens.ICON_M, "text.primary"))
		var name_l: Label = FlowScreen.label(_item_name(item), &"StrongLabel")
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var left: Label = GameUI.tag(Strings.fmt("ui.colony.turns_left", {"turns": item.turns_left}))
		head.add_child(GameUI.exempt(left, "turns left on the item"))
		v.add_child(head)
		v.add_child(Meter.make(float(item.total_turns - item.turns_left), float(maxi(1, item.total_turns)), "accent.teal"))
		var acts: HFlowContainer = HFlowContainer.new()
		acts.add_theme_constant_override("h_separation", Tokens.SPACE_S)
		var cancel: SfButton = SfButton.make("ui.colony.cancel", "ui_close", SfButton.GHOST)
		cancel.name = "Cancel_" + item.id
		var cancel_res: Result = CancelBuildCommand.create(e.id, c.id, item.id).validate(s.state)
		cancel.disabled = not cancel_res.ok
		cancel.pressed.connect(func() -> void:
			s.order(CancelBuildCommand.create(e.id, c.id, item.id)))
		acts.add_child(cancel)
		if i > 0:
			var up: SfButton = SfButton.make("ui.colony.move_up", "ui_upgrade", SfButton.GHOST)
			up.name = "MoveUp_" + item.id
			up.pressed.connect(func() -> void:
				s.order(MoveBuildUpCommand.create(e.id, c.id, item.id)))
			acts.add_child(up)
		else:
			var rush_res: Result = RushBuildCommand.create(e.id, c.id, item.id).validate(s.state)
			var rush: SfButton = SfButton.make("ui.colony.rush", "ui_end_turn", SfButton.GHOST)
			rush.name = "Rush_" + item.id
			rush.disabled = not rush_res.ok
			rush.pressed.connect(func() -> void:
				s.order(RushBuildCommand.create(e.id, c.id, item.id)))
			acts.add_child(rush)
			var rc: Breakdown = Construction.rush_cost(item)
			var chip: Explainable = CostChips.chip("energy", rc.total, e.stock_of("energy") < rc.total, e.stock_of("energy")) as Explainable
			chip.set_breakdown(rc)
			acts.add_child(chip)
		v.add_child(acts)
		card.add_body(GameUI.panel(v))
	return card


static func _table_of(kind: String) -> String:
	match kind:
		BuildItem.KIND_BUILDING:
			return "buildings"
		BuildItem.KIND_SHIP:
			return "hulls"
	return "districts"


static func _item_name(item: BuildItem) -> String:
	var n: String = GameUI.name_of(_table_of(item.kind), item.def_id)
	if item.kind == BuildItem.KIND_UPGRADE:
		return Strings.fmt("ui.colony.upgrade_of", {"name": n})
	return n


static func _jobs(s: GameScreen, c: Colony, cr: Economy.ColonyReport) -> Control:
	var e: Empire = s.state.player()
	var card: Card = Card.make(Strings.fmt("ui.colony.jobs_title"), Strings.fmt("ui.colony.jobs_hint"), "ui_governor", "accent.teal")
	card.name = "JobPriority"
	for i in c.job_priority.size():
		var group: String = c.job_priority[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_S)
		row.add_child(SfIcon.make(GROUP_ICONS.get(group, "ui_governor"), Tokens.ICON_M, GameUI.token_of(group) if group != "clerks" else "text.secondary"))
		var n: Label = FlowScreen.label(_group_name(group), &"SecondaryLabel")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
		var filled: Label = Label.new()
		filled.theme_type_variation = &"MonoLabel"
		filled.text = "%d / %d" % [cr.filled_by_group.get(group, 0), cr.jobs_by_group.get(group, 0)]
		row.add_child(GameUI.exempt(filled, "jobs filled over jobs offered in this group"))
		if i > 0:
			var up: SfButton = SfButton.make_icon("ui_upgrade", "ui.colony.raise")
			up.name = "Raise_" + group
			up.pressed.connect(func() -> void:
				var order: Array[String] = c.job_priority.duplicate()
				order.remove_at(i)
				order.insert(i - 1, group)
				s.order(SetJobPriorityCommand.create(e.id, c.id, order)))
			row.add_child(up)
		card.add_body(row)
	return card


static func _group_name(group: String) -> String:
	if group == "clerks":
		return Strings.fmt("job.clerk.name")
	return GameUI.name_of("resources", group)


static func _governor(s: GameScreen, c: Colony) -> Control:
	var e: Empire = s.state.player()
	var card: Card = Card.make(Strings.fmt("ui.governor.title"), Strings.fmt("ui.governor.subtitle"), "ui_governor", "hearth.gold")
	card.name = "GovernorCard"
	var on: SfButton = SfButton.make("ui.governor.on" if not c.governor_on else "ui.governor.off", "ui_check" if not c.governor_on else "ui_close", SfButton.PRIMARY if not c.governor_on else SfButton.SECONDARY)
	on.name = "GovernorToggle"
	on.pressed.connect(func() -> void:
		s.order(SetGovernorCommand.create(e.id, c.id, not c.governor_on, c.governor_focus, c.governor_budget_bp)))
	card.add_body(on)
	if not c.governor_on:
		card.add_text(Strings.fmt("ui.governor.off_note"), &"CaptionLabel")
		return card
	card.add_body(GameUI.heading(Strings.fmt("ui.governor.focus")))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	var group: ButtonGroup = ButtonGroup.new()
	for f: String in Colony.GOVERNOR_FOCUSES:
		var b: SfButton = SfButton.make(FOCUS_KEYS[f], "", SfButton.TAB)
		b.name = "Focus_" + f
		b.button_group = group
		b.button_pressed = c.governor_focus == f
		b.pressed.connect(func() -> void:
			s.order(SetGovernorCommand.create(e.id, c.id, true, f, c.governor_budget_bp)))
		flow.add_child(b)
	card.add_body(flow)
	var budget: Label = GameUI.caption(Strings.fmt("ui.governor.budget", {"pct": Fx.div_floor(c.governor_budget_bp, 100)}))
	card.add_body(GameUI.exempt(budget, "the share of minerals the governor may spend"))
	var slider: HSlider = HSlider.new()
	slider.name = "BudgetSlider"
	slider.min_value = SetGovernorCommand.MIN_BUDGET_BP / 100.0
	slider.max_value = SetGovernorCommand.MAX_BUDGET_BP / 100.0
	slider.step = 10.0
	slider.value = c.governor_budget_bp / 100.0
	slider.custom_minimum_size.y = Layout.target_size()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			s.order(SetGovernorCommand.create(e.id, c.id, true, c.governor_focus, int(slider.value * 100.0))))
	card.add_body(slider)
	var plan: Advisor.Option = Governor.plan(s.state, c, s.report)
	card.add_body(GameUI.heading(Strings.fmt("ui.governor.plan")))
	if plan == null:
		card.add_text(Strings.fmt("ui.governor.no_plan"), &"CaptionLabel")
	else:
		var table: String = _table_of(plan.kind)
		var what: Label = FlowScreen.label(Strings.fmt("ui.governor.plan_line", {"what": GameUI.name_of(table, plan.def_id), "reason": Strings.fmt(plan.reason_key, plan.reason_args)}))
		what.name = "PlanLine"
		card.add_body(GameUI.exempt(what, "the governor's reason, quoting the numbers it used"))
		var veto: SfButton = SfButton.make("ui.governor.veto", "ui_close", SfButton.GHOST)
		veto.name = "Veto"
		veto.pressed.connect(func() -> void:
			s.order(VetoPlanCommand.create(e.id, c.id, plan.veto_key())))
		card.add_body(veto)
	return card


static func _shipyard(s: GameScreen, c: Colony) -> Control:
	var e: Empire = s.state.player()
	var card: Card = Card.make(Strings.fmt("ui.colony.shipyard"), Strings.fmt("ui.colony.shipyard_hint"), "ship_fleet", "accent.teal")
	card.name = "Shipyard"
	for hull_id: String in Content.db().ids("hulls"):
		var hull: Dictionary = Content.db().record("hulls", hull_id)
		if DictIO.str_of(hull, "class") != "civilian":
			continue
		var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
		var res: Result = BuildShipCommand.create(e.id, c.id, hull_id).validate(s.state)
		var a: VBoxContainer = GameUI.action(GameUI.name_of("hulls", hull_id), DictIO.str_of(hull, "icon", "ship_fleet"), res, func() -> void:
			s.order(BuildShipCommand.create(e.id, c.id, hull_id)))
		a.name = "Build_" + hull_id
		v.add_child(a)
		var line: HFlowContainer = HFlowContainer.new()
		line.add_theme_constant_override("h_separation", Tokens.SPACE_M)
		line.add_child(GameUI.cost(Construction.ship_cost(s.state, c, hull_id), e))
		var turns: int = Construction.build_turns("ship", hull_id)
		line.add_child(GameUI.exempt(GameUI.tag(Strings.fmt("ui.colony.takes_turns", {"turns": turns})), "build time from the data"))
		v.add_child(line)
		card.add_body(GameUI.panel(v))
	return card
