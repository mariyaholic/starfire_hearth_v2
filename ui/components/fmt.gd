class_name Fmt
extends RefCounted
## Turns simulation integers into text. Presentation divides for display (§5 fixed-point rule);
## it never computes game rules. Signs use a true minus sign, and every rate carries its unit.

const MINUS: String = "−"


## Centi-units to text. `decimals` is the maximum; trailing zeros are trimmed down to `min_decimals`.
## Zero never carries a sign.
static func centi(v: int, signed: bool = false, decimals: int = 2, min_decimals: int = 1) -> String:
	var neg: bool = v < 0
	var a: int = absi(v)
	var whole: int = 0
	var frac_text: String = ""
	if decimals <= 0:
		whole = (a + 50) / 100
	elif decimals == 1:
		var tenths: int = (a + 5) / 10
		whole = tenths / 10
		frac_text = str(tenths % 10)
	else:
		whole = a / 100
		frac_text = "%02d" % (a % 100)
	while frac_text.length() > min_decimals and frac_text.ends_with("0"):
		frac_text = frac_text.left(-1)
	var body: String = group(whole)
	if not frac_text.is_empty():
		body += "." + frac_text
	var is_zero: bool = whole == 0 and frac_text.to_int() == 0
	if neg and not is_zero:
		return MINUS + body
	if signed and not is_zero:
		return "+" + body
	return body


## Whole-number stock display: 15000 centi -> "150".
static func stock(v: int) -> String:
	var neg: bool = v < 0
	var s: String = group(absi(v) / 100)
	return (MINUS + s) if neg else s


## Signed plain integer: 3 -> "+3", -8 -> "−8", 0 -> "0".
static func points(v: int, signed: bool = true) -> String:
	if v < 0:
		return MINUS + group(-v)
	if signed and v > 0:
		return "+" + group(v)
	return group(v)


## Basis points: 1000 -> "+10%", -250 -> "−2.5%".
static func bp(v: int, signed: bool = true) -> String:
	var neg: bool = v < 0
	var a: int = absi(v)
	var whole: int = a / 100
	var frac: int = a % 100
	var s: String = str(whole)
	if frac != 0:
		s += (".%02d" % frac).rstrip("0")
	s += "%"
	if neg:
		return MINUS + s
	if signed and v > 0:
		return "+" + s
	return s


## Thousands separators: 1250 -> "1,250".
static func group(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if n < 0 else out


## "+4.0 food / turn" style rate for a resource (name from the string table).
static func rate(v: int, resource_name: String) -> String:
	return Strings.fmt("ui.fmt.rate", {"value": centi(v, true, 2, 1), "resource": resource_name.to_lower()})


## A resource's display unit ("kt", "GW", from its `unit_key` in data), or "" if it has none.
static func unit(resource_id: String) -> String:
	if Game.db == null:
		return ""
	var key: String = str(Game.db.record("resources", resource_id).get("unit_key", ""))
	return "" if key.is_empty() else Strings.fmt(key)


## What follows a breakdown total: " kt / turn" for a resource flow, " kt" for a stock.
static func suffix(b: Breakdown, with_per_turn: bool = true) -> String:
	if b.unit != Breakdown.UNIT_RESOURCE:
		return ""
	var out: String = ""
	var u: String = unit(b.resource)
	if not u.is_empty():
		out += " " + u
	if with_per_turn and b.per_turn:
		out += " " + Strings.fmt("ui.fmt.per_turn")
	return out


## The date for a turn: "Month 4, Year 101 S.".
static func date(turn: int) -> String:
	return Strings.fmt("ui.calendar.date", {"month": Calendar.month_of(turn), "year": Calendar.year_of(turn)})


## One breakdown line's value in the breakdown's unit.
static func line_value(b: Breakdown, value: int) -> String:
	match b.unit:
		Breakdown.UNIT_RESOURCE, Breakdown.UNIT_CENTI:
			return centi(value, true)
		Breakdown.UNIT_PERCENT:
			return bp(value)
		_:
			return points(value)


## A breakdown total in its unit (unsigned unless it is a per-turn flow).
static func total(b: Breakdown) -> String:
	match b.unit:
		Breakdown.UNIT_RESOURCE, Breakdown.UNIT_CENTI:
			return centi(b.total, b.per_turn)
		Breakdown.UNIT_PERCENT:
			return bp(b.total, false)
		_:
			return points(b.total, b.per_turn)
