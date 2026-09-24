class_name Tokens
extends RefCounted
## Design tokens (§8.2, §8.5, §8.4). Every colour, size, radius and duration in the UI comes from
## here, through the Theme that ThemeBuilder makes or through Tokens.color() for custom drawing.

const PALETTE: Dictionary[String, Color] = {
	"bg.deep": Color("#0B1622"),
	"bg.panel": Color("#13263A"),
	"bg.panel.alt": Color("#1B3350"),
	"line.subtle": Color("#2A4A6B"),
	"text.primary": Color("#EAF2F8"),
	"text.secondary": Color("#9FB3C8"),
	"accent.teal": Color("#2EC4B6"),
	"hearth.gold": Color("#FFD37A"),
	"alert.ember": Color("#FF6B4A"),
	"ally.blue": Color("#4EA8DE"),
	"other.magenta": Color("#C04CFD"),
	"ok.green": Color("#6BD68A"),
	"energy.yellow": Color("#F7C948"),
	"mineral.slate": Color("#A7B4C2"),
	"alloy.copper": Color("#E0925A"),
	"sci.cyan": Color("#56CFE1"),
	"influence.violet": Color("#9D8DF1"),
}

## High-contrast variant (§8.2): black panels, white text, 2 px outlines.
const HIGH_CONTRAST: Dictionary[String, Color] = {
	"bg.deep": Color("#000000"),
	"bg.panel": Color("#000000"),
	"bg.panel.alt": Color("#101010"),
	"line.subtle": Color("#FFFFFF"),
	"text.primary": Color("#FFFFFF"),
	"text.secondary": Color("#E6E6E6"),
}

## Semantic aliases used by components.
const POSITIVE: String = "hearth.gold"
const NEGATIVE: String = "alert.ember"

# Radii (§8.3)
const RADIUS_CHIP: int = 4
const RADIUS_PANEL: int = 8

# Spacing scale
const SPACE_XS: int = 4
const SPACE_S: int = 8
const SPACE_M: int = 12
const SPACE_L: int = 16
const SPACE_XL: int = 24
const SPACE_XXL: int = 32

# Type scale in px at 1080p (§8.5), and the compact (phone) scale in dp (14 sp body text).
const FONT_WIDE: Dictionary[String, int] = {"display": 32, "h1": 22, "h2": 18, "body": 16, "caption": 13}
const FONT_COMPACT: Dictionary[String, int] = {"display": 26, "h1": 20, "h2": 16, "body": 14, "caption": 12}
const LINE_HEIGHT: float = 1.35

# Interaction sizes
const TOUCH_TARGET_DP: int = 48
const POINTER_TARGET_PX: int = 32
const ICON_S: int = 16
const ICON_M: int = 20
const ICON_L: int = 24
const STROKE: int = 2

# Motion (§8.4), seconds
const TWEEN_FAST: float = 0.15
const TWEEN_NORMAL: float = 0.2
const TWEEN_SLOW: float = 0.25
const HOVER_DELAY: float = 0.3
const LONG_PRESS: float = 0.5

const FONT_SANS_REGULAR: String = "res://assets/fonts/plex_sans/IBMPlexSans-Regular.ttf"
const FONT_SANS_MEDIUM: String = "res://assets/fonts/plex_sans/IBMPlexSans-Medium.ttf"
const FONT_SANS_SEMIBOLD: String = "res://assets/fonts/plex_sans/IBMPlexSans-SemiBold.ttf"
const FONT_MONO_REGULAR: String = "res://assets/fonts/plex_mono/IBMPlexMono-Regular.ttf"
const FONT_MONO_MEDIUM: String = "res://assets/fonts/plex_mono/IBMPlexMono-Medium.ttf"

static var high_contrast: bool = false


static func has(token: String) -> bool:
	return PALETTE.has(token)


## The current colour of a token (respects the high-contrast variant).
static func color(token: String) -> Color:
	if high_contrast and HIGH_CONTRAST.has(token):
		return HIGH_CONTRAST[token]
	return PALETTE.get(token, Color.MAGENTA)


## WCAG 2.x relative luminance.
static func luminance(c: Color) -> float:
	var ch: Array[float] = [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v: float in ch:
		lin.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


## WCAG contrast ratio between two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
