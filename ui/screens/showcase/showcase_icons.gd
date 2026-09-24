class_name ShowcaseIcons
extends RefCounted
## The icon contact sheet (§8.3): every icon, filled and outlined, at 24 px and at 16 px, with
## its name. Shared by the showcase's Icons page and tools/icon_sheet.gd.

## Display names for the sheet; the icon id is never shown.
const GROUP_KEYS: Array[Array] = [
	["res_", "ui.icons.group.resources"],
	["branch_", "ui.icons.group.branches"],
	["district_", "ui.icons.group.districts"],
	["planet_", "ui.icons.group.planets"],
	["trait_", "ui.icons.group.traits"],
	["emblem_", "ui.icons.group.emblems"],
	["stance_", "ui.icons.group.stances"],
	["alert_", "ui.icons.group.alerts"],
	["treaty_", "ui.icons.group.treaties"],
	["dmg_", "ui.icons.group.damage"],
	["stat_", "ui.icons.group.stats"],
	["ship_", "ui.icons.group.ships"],
	["map_", "ui.icons.group.map"],
	["ui_", "ui.icons.group.interface"],
]


static func build() -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "IconSheet"
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	var intro: Label = Label.new()
	intro.theme_type_variation = &"SecondaryLabel"
	intro.text = Strings.fmt("ui.icons.intro", {"count": IconCache.all_ids().size()})
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(intro)
	var ids: Array[String] = IconCache.all_ids()
	for g: Array in GROUP_KEYS:
		var members: Array[String] = []
		for id: String in ids:
			if id.begins_with(g[0]):
				members.append(id)
		if members.is_empty():
			continue
		var card: Card = Card.make(Strings.fmt(g[1]))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", Tokens.SPACE_S)
		flow.add_theme_constant_override("v_separation", Tokens.SPACE_S)
		for id: String in members:
			flow.add_child(_cell(id))
		card.add_body(flow)
		col.add_child(card)
	return col


static func _cell(id: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = &"InsetPanel"
	p.custom_minimum_size.x = 132.0 * maxf(1.0, Settings.text_scale * 0.85)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", Tokens.SPACE_XS)
	p.add_child(v)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	for spec: Array in [[24, "text.primary", false], [24, "accent.teal", true], [16, "text.primary", false], [16, "accent.teal", true]]:
		var ic: SfIcon = SfIcon.make(id, spec[0], spec[1], spec[2])
		ic.scales_with_text = false
		row.add_child(ic)
	v.add_child(row)
	var l: Label = Label.new()
	l.theme_type_variation = &"CaptionLabel"
	l.text = display_name(id)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return p


## The player-facing name of an icon, from the string table ("icon.<id>"). The validator checks
## that every icon file has one.
static func display_name(id: String) -> String:
	return Strings.fmt("icon." + id)
