extends SceneTree
## Palette report (§6.9, §8.2): WCAG contrast of text on panels, and how far apart the colours
## that carry meaning stay under a deuteranopia simulation (CIE76 ΔE in Lab; below about 20 two
## colours are easy to confuse). Colour is never the only signal in the UI, so a low ΔE is a
## finding for the Owner, not a failure.
##   godot --headless --path . -s tools/palette_report.gd

const PAIRS: Array[Array] = [
	["hearth.gold", "alert.ember", "positive vs negative numbers"],
	["ok.green", "energy.yellow", "farm vs energy districts"],
	["energy.yellow", "alloy.copper", "energy vs industry districts"],
	["ok.green", "alloy.copper", "farm vs industry districts"],
	["accent.teal", "ally.blue", "you vs the Meridian Directorate"],
	["accent.teal", "other.magenta", "you vs the Vael"],
	["ally.blue", "other.magenta", "Meridian vs the Vael"],
	["alert.ember", "other.magenta", "the Unlit vs the Vael"],
	["accent.teal", "sci.cyan", "teal vs science cyan"],
	["mineral.slate", "text.secondary", "minerals vs secondary text"],
]
## Candidate colours for negative numbers, for the Owner to choose from (M0 report question).
const NEGATIVE_CANDIDATES: Array[Array] = [
	["#FF6B4A", "ember (current)"],
	["#FF5C8A", "rose"],
	["#FF6F91", "coral pink"],
	["#F25CB4", "pink magenta"],
	["#E86BE0", "red violet"],
]


func _initialize() -> void:
	print("Text contrast (WCAG 2, AA needs 4.5:1 for body text)")
	for bg: String in ["bg.deep", "bg.panel", "bg.panel.alt"]:
		for fg: String in ["text.primary", "text.secondary", "hearth.gold", "alert.ember", "accent.teal"]:
			print("  %-16s on %-13s %5.2f:1" % [fg, bg, Tokens.contrast(Tokens.PALETTE[fg], Tokens.PALETTE[bg])])
	print("")
	print("Separation of meaningful pairs (ΔE76; normal vision -> deuteranopia)")
	for p: Array in PAIRS:
		var a: Color = Tokens.PALETTE[p[0]]
		var b: Color = Tokens.PALETTE[p[1]]
		var normal: float = _delta_e(a, b)
		var cvd: float = _delta_e(ColourVision.simulate(a), ColourVision.simulate(b))
		var flag: String = "  LOW" if cvd < 20.0 else ""
		print("  %-30s %6.1f -> %6.1f%s" % [p[2], normal, cvd, flag])
	print("")
	print("Negative-number candidates (ΔE76 to hearth.gold under deuteranopia; contrast on bg.panel)")
	var gold: Color = Tokens.PALETTE["hearth.gold"]
	for c: Array in NEGATIVE_CANDIDATES:
		var col: Color = Color(c[0])
		var cvd_gold: float = _delta_e(ColourVision.simulate(col), ColourVision.simulate(gold))
		print("  %-9s %-16s %6.1f   %5.2f:1" % [c[0], c[1], cvd_gold, Tokens.contrast(col, Tokens.PALETTE["bg.panel"])])
	quit(0)


func _delta_e(a: Color, b: Color) -> float:
	var la: Vector3 = _lab(a)
	var lb: Vector3 = _lab(b)
	return la.distance_to(lb)


## sRGB -> CIE L*a*b* (D65).
func _lab(c: Color) -> Vector3:
	var r: float = ColourVision.to_linear(c.r)
	var g: float = ColourVision.to_linear(c.g)
	var b: float = ColourVision.to_linear(c.b)
	var x: float = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y: float = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.0
	var z: float = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var fx: float = _f(x)
	var fy: float = _f(y)
	var fz: float = _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
