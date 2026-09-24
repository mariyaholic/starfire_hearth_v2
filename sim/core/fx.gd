class_name Fx
extends RefCounted
## Fixed-point helpers. Simulation state holds integers only:
## - resources, rates and combat stats in centi-units (1.00 food = 100),
## - percentages in basis points (+10% = 1000),
## - counts (pops, turns, stability points, opinion points) as plain integers.
## Rounding is always toward negative infinity so results never depend on the sign convention
## of the platform's integer division.

const ONE: int = 100
const BP_ONE: int = 10000


static func div_floor(a: int, b: int) -> int:
	assert(b != 0, "Fx.div_floor: division by zero")
	var q: int = a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


static func div_ceil(a: int, b: int) -> int:
	return -div_floor(-a, b)


## x * bp / 10000, floored.
static func mul_bp(x: int, bp: int) -> int:
	return div_floor(x * bp, BP_ONE)


## Whole units to centi-units.
static func units(n: int) -> int:
	return n * ONE


## Parses an authoring string such as "4.00", "-6", "0.5" into centi-units.
## Returns [ok: bool, value: int]. At most two decimals are accepted.
static func parse_centi(text: String) -> Array:
	var s: String = text.strip_edges()
	var re: RegEx = RegEx.create_from_string("^(-?)(\\d+)(?:\\.(\\d{1,2}))?$")
	var m: RegExMatch = re.search(s)
	if m == null:
		return [false, 0]
	var whole: int = m.get_string(2).to_int()
	var frac_text: String = m.get_string(3)
	var frac: int = 0
	if frac_text.length() == 1:
		frac = frac_text.to_int() * 10
	elif frac_text.length() == 2:
		frac = frac_text.to_int()
	var value: int = whole * ONE + frac
	if m.get_string(1) == "-":
		value = -value
	return [true, value]
