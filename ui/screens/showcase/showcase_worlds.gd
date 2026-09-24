class_name ShowcaseWorlds
extends RefCounted
## Stars and planets page of the showcase: every spectral class, and every planet type with three
## seeds each, so the generators' range and consistency can be judged at a glance.

const MAGNITUDE_KEYS: Array[String] = [
	"ui.worlds.magnitude_1", "ui.worlds.magnitude_2", "ui.worlds.magnitude_3",
	"ui.worlds.magnitude_4", "ui.worlds.magnitude_5",
]
const SPECTRAL_KEYS: Array[Array] = [
	["M", "ui.worlds.star.m"], ["K", "ui.worlds.star.k"], ["G", "ui.worlds.star.g"],
	["F", "ui.worlds.star.f"], ["A", "ui.worlds.star.a"], ["white_dwarf", "ui.worlds.star.white_dwarf"],
	["binary", "ui.worlds.star.binary"],
]


static func build(db: ContentDb) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Worlds"
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	var stars: Card = Card.make(Strings.fmt("ui.worlds.stars.title"), Strings.fmt("ui.worlds.stars.subtitle"))
	var sflow: HFlowContainer = HFlowContainer.new()
	sflow.add_theme_constant_override("h_separation", Tokens.SPACE_L)
	for pair: Array in SPECTRAL_KEYS:
		var v: VBoxContainer = _item(StarDisc.make(pair[0], 3 if pair[0] != "M" else 2, 88), Strings.fmt(pair[1]))
		sflow.add_child(v)
	stars.add_body(sflow)
	var mags: HFlowContainer = HFlowContainer.new()
	mags.add_theme_constant_override("h_separation", Tokens.SPACE_L)
	for m in range(1, 6):
		mags.add_child(_item(StarDisc.make("G", m, 64), Strings.fmt(MAGNITUDE_KEYS[m - 1])))
	stars.add_body(mags)
	col.add_child(stars)
	var planets: Card = Card.make(Strings.fmt("ui.worlds.planets.title"), Strings.fmt("ui.worlds.planets.subtitle"))
	planets.name = "CardPlanets"
	var grid: HFlowContainer = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", Tokens.SPACE_M)
	grid.add_theme_constant_override("v_separation", Tokens.SPACE_M)
	for tid: String in db.ids("planet_types"):
		var rec: Dictionary = db.record("planet_types", tid)
		var block: PanelContainer = PanelContainer.new()
		block.theme_type_variation = &"InsetPanel"
		var v: VBoxContainer = VBoxContainer.new()
		block.add_child(v)
		var head: HBoxContainer = HBoxContainer.new()
		head.add_child(SfIcon.make(rec["icon"], Tokens.ICON_M, "text.secondary"))
		var name_l: Label = Label.new()
		name_l.theme_type_variation = &"StrongLabel"
		name_l.text = Strings.fmt(rec["name_key"])
		head.add_child(name_l)
		v.add_child(head)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_S)
		for seed_i: int in [3, 17, 42]:
			row.add_child(PlanetDisc.make(tid, rec["palette"], seed_i * 7919 + tid.length(), 88))
		v.add_child(row)
		grid.add_child(block)
	planets.add_body(grid)
	col.add_child(planets)
	return col


static func _item(art: Control, caption: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	var c: CenterContainer = CenterContainer.new()
	c.add_child(art)
	v.add_child(c)
	if not caption.is_empty():
		var l: Label = Label.new()
		l.theme_type_variation = &"CaptionLabel"
		l.text = caption
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = (art.custom_minimum_size.x + 8.0) * Settings.text_scale
		v.add_child(l)
	return v
