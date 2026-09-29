class_name GameUI
extends RefCounted
## Builders the game screen, its views and its overlays share.


static func heading(text: String) -> Label:
	return FlowScreen.label(text, &"StrongLabel")


static func caption(text: String) -> Label:
	return FlowScreen.label(text, &"CaptionLabel")


## A short label that never wraps, for rows and flows (a wrapping label there gets no width).
static func tag(text: String, variation: StringName = &"CaptionLabel") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## A wrapping label that takes the rest of its row.
static func grow(text: String, variation: StringName = &"") -> Label:
	var l: Label = FlowScreen.label(text, variation)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Marks a control as showing a number that needs no breakdown (a count, a date), and says why.
static func exempt(c: Control, reason: String) -> Control:
	c.set_meta("audit_numeric_ok", reason)
	return c


## The words for a refused order: its reason key with its arguments.
static func why(r: Result) -> String:
	return Strings.fmt(r.reason_key, r.args)


static func refusal(r: Result) -> Label:
	var l: Label = FlowScreen.label(why(r), &"CaptionLabel")
	l.add_theme_color_override("font_color", Tokens.color(Tokens.NEGATIVE))
	# A refusal quotes the numbers that refused the order ("needs 60 minerals; you have 40").
	l.set_meta("audit_numeric_ok", "a refusal quotes what refused the order")
	return l


## A button that runs `on_press`. A refused order is disabled with its reason underneath, so an
## order is never dropped silently (§6.7).
static func action(text: String, icon: String, r: Result, on_press: Callable, variant: String = SfButton.SECONDARY) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var b: SfButton = SfButton.make("", icon, variant)
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not r.ok
	b.pressed.connect(on_press)
	v.add_child(b)
	if not r.ok:
		v.add_child(refusal(r))
	return v


## A labelled value: icon, title and value. With a breakdown the value explains itself; without,
## `plain_reason` says why it needs none.
static func stat(icon_id: String, icon_token: String, title: String, value: String, b: Breakdown, plain_reason: String = "a count") -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_S)
	row.add_child(SfIcon.make(icon_id, Tokens.ICON_M, icon_token))
	var t: Label = FlowScreen.label(title, &"SecondaryLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var v: Label = Label.new()
	v.theme_type_variation = &"MonoStrongLabel"
	v.text = value
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	if b == null:
		return exempt(row, plain_reason)
	var e: Explainable = Explainable.wrap(row, b)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e


## A panel that groups a few controls inside a view.
static func panel(inner: Control, variation: StringName = &"InsetPanel") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	p.add_child(inner)
	return p


static func column(separation: int = Tokens.SPACE_S) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


## Two blocks side by side on PC, one above the other on phones.
static func split(first: Control, second: Control, first_share: float = 1.0, second_share: float = 1.0) -> Container:
	var box: BoxContainer
	if Layout.compact:
		box = VBoxContainer.new()
	else:
		box = HBoxContainer.new()
	box.add_theme_constant_override("separation", Tokens.SPACE_L)
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first.size_flags_stretch_ratio = first_share
	second.size_flags_stretch_ratio = second_share
	first.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	second.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(first)
	box.add_child(second)
	return box


## A record's display name from the string table ("" when the record has none).
static func name_of(table: String, id: String) -> String:
	var key: String = DictIO.str_of(Content.db().record(table, id), "name_key")
	return Strings.fmt(key) if not key.is_empty() else ""


static func desc_of(table: String, id: String) -> String:
	var key: String = DictIO.str_of(Content.db().record(table, id), "desc_key")
	return Strings.fmt(key) if not key.is_empty() else ""


static func icon_of(table: String, id: String, fallback: String = "ui_star") -> String:
	return DictIO.str_of(Content.db().record(table, id), "icon", fallback)


## A resource's icon token (data/resources.json).
static func token_of(resource_id: String) -> String:
	return DictIO.str_of(Content.db().record("resources", resource_id), "color", "text.secondary")


## A cost as chips that flag what the empire cannot pay.
static func cost(c: Dictionary, e: Empire) -> CostChips:
	return CostChips.make(c, e.stock, true)


## A colony's name: the one the player gave it, or else its planet's.
static func colony_name(state: GameState, c: Colony) -> String:
	if not c.name.is_empty():
		return c.name
	var planet: Planet = state.planets.get(c.planet_id, null)
	return Strings.fmt(planet.name_key) if planet != null else ""


## The kilo-settlers of a colony as text ("12k").
static func pops(n: int) -> String:
	return "%dk" % n
