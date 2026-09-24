extends RefCounted
## Design tokens (§8.2): text contrast meets WCAG AA, the high-contrast variant is stronger, and
## the colour-vision helper matches its reference behaviour.


func test_body_text_contrast_is_wcag_aa(t: T) -> void:
	for bg: String in ["bg.deep", "bg.panel", "bg.panel.alt"]:
		for fg: String in ["text.primary", "text.secondary"]:
			var ratio: float = Tokens.contrast(Tokens.PALETTE[fg], Tokens.PALETTE[bg])
			t.ok(ratio >= 4.5, "%s on %s is %.2f:1, needs 4.5:1" % [fg, bg, ratio])


func test_signal_colours_are_readable_on_panels(t: T) -> void:
	for fg: String in ["hearth.gold", "alert.ember", "accent.teal", "ok.green", "sci.cyan", "energy.yellow"]:
		var ratio: float = Tokens.contrast(Tokens.PALETTE[fg], Tokens.PALETTE["bg.panel"])
		t.ok(ratio >= 4.5, "%s on panel is %.2f:1" % [fg, ratio])


func test_primary_button_label_contrast(t: T) -> void:
	var ratio: float = Tokens.contrast(Tokens.PALETTE["bg.deep"], Tokens.PALETTE["accent.teal"])
	t.ok(ratio >= 4.5, "dark text on teal is %.2f:1" % ratio)


func test_high_contrast_variant(t: T) -> void:
	var before: bool = Tokens.high_contrast
	Tokens.high_contrast = true
	t.eq(Tokens.color("bg.panel"), Color("#000000"))
	t.eq(Tokens.color("text.primary"), Color("#FFFFFF"))
	t.ok(Tokens.contrast(Tokens.color("text.primary"), Tokens.color("bg.panel")) >= 20.0)
	Tokens.high_contrast = before


func test_deuteranopia_keeps_greys_and_shifts_reds(t: T) -> void:
	var grey: Color = ColourVision.simulate(Color(0.5, 0.5, 0.5))
	t.near(grey.r, 0.5, 0.01, "neutral greys are unchanged")
	t.near(grey.g, 0.5, 0.01)
	var red: Color = ColourVision.simulate(Color(1, 0, 0))
	t.ok(red.g > 0.3, "pure red loses its redness under deuteranopia (g=%.2f)" % red.g)
