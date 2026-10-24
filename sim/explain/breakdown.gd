class_name Breakdown
extends RefCounted
## The explanation of one derived number: the base value, every modifier with its source, and the
## total. Rules build these while computing a value; the UI's Explainable shows them and never
## recomputes game math.
##
## Arithmetic contract (checked by verify()):
##   subtotal = sum of base and add lines
##   each mult line's value = Fx.mul_bp(subtotal, line.bp)   (mults are additive with each other)
##   flat lines are fixed amounts applied after the mults (upkeep, consumption), so percentage
##   bonuses never scale a cost
##   cap lines clamp last; a cap line's value is the amount removed or added by the clamp
##   total = sum of every line's value

const KIND_BASE: String = "base"
const KIND_ADD: String = "add"
const KIND_MULT: String = "mult"
const KIND_FLAT: String = "flat"
const KIND_CAP: String = "cap"

## Units tell the UI how to format values.
const UNIT_RESOURCE: String = "resource"  # centi-units of the resource named in `resource`
const UNIT_POINTS: String = "points"      # plain integer points (stability, opinion, acceptance)
const UNIT_CENTI: String = "centi"        # centi-units without a resource (noise, growth progress)
const UNIT_PERCENT: String = "percent"    # basis points
const UNIT_TURNS: String = "turns"        # whole turns
const UNIT_COUNT: String = "count"        # whole things (pops, ships)


## One line of a breakdown.
class Line:
	extends RefCounted
	var kind: String = KIND_ADD
	var source_key: String = ""
	var source_args: Dictionary = {}
	## Contribution to the total, in the breakdown's unit.
	var value: int = 0
	## Mult lines: the percentage in basis points.
	var bp: int = 0
	## Cap lines: the limit that was applied, and whether it is a ceiling ("max") or floor ("min").
	var limit: int = 0
	var cap_dir: String = ""
	## Optional nested breakdown of this source (the UI opens it on hover or tap, 2 levels deep).
	var child: Breakdown = null
	## Optional Codex entry id for this source.
	var link: String = ""

	func to_dict() -> Dictionary:
		var d: Dictionary = {
			"kind": kind, "source_key": source_key, "source_args": source_args.duplicate(true),
			"value": value, "bp": bp, "limit": limit, "cap_dir": cap_dir, "link": link,
		}
		if child != null:
			d["child"] = child.to_dict()
		return d


var label_key: String = ""
var label_args: Dictionary = {}
var unit: String = UNIT_POINTS
## For UNIT_RESOURCE: which resource (formats "+4.0 food / turn").
var resource: String = ""
var per_turn: bool = false
var lines: Array[Line] = []
var total: int = 0
var note_key: String = ""
var note_args: Dictionary = {}
## Codex entry ids for the whole breakdown.
var links: Array[String] = []
var _finished: bool = false


static func make(p_label_key: String, p_unit: String, p_per_turn: bool = false, p_label_args: Dictionary = {}) -> Breakdown:
	var b: Breakdown = Breakdown.new()
	b.label_key = p_label_key
	b.unit = p_unit
	b.per_turn = p_per_turn
	b.label_args = p_label_args
	return b


## Shorthand for a per-turn resource flow such as "Food net".
static func for_resource(p_label_key: String, p_resource: String, p_per_turn: bool = true, p_label_args: Dictionary = {}) -> Breakdown:
	var b: Breakdown = make(p_label_key, UNIT_RESOURCE, p_per_turn, p_label_args)
	b.resource = p_resource
	return b


func base(source_key: String, value: int, args: Dictionary = {}, child: Breakdown = null, link: String = "") -> Breakdown:
	return _push(KIND_BASE, source_key, value, 0, args, child, link)


func add(source_key: String, value: int, args: Dictionary = {}, child: Breakdown = null, link: String = "") -> Breakdown:
	return _push(KIND_ADD, source_key, value, 0, args, child, link)


## A percentage modifier. Its value is computed in finish() from the base and add lines.
func mult(source_key: String, bp: int, args: Dictionary = {}, child: Breakdown = null, link: String = "") -> Breakdown:
	return _push(KIND_MULT, source_key, 0, bp, args, child, link)


## A fixed amount applied after the mults, such as upkeep or what settlers eat.
func flat(source_key: String, value: int, args: Dictionary = {}, child: Breakdown = null, link: String = "") -> Breakdown:
	return _push(KIND_FLAT, source_key, value, 0, args, child, link)


## Clamp the total to at most `limit` (applied in finish(), after mults).
func cap_max(limit: int, source_key: String, args: Dictionary = {}, link: String = "") -> Breakdown:
	var l: Line = _make_line(KIND_CAP, source_key, 0, 0, args, null, link)
	l.limit = limit
	l.cap_dir = "max"
	lines.append(l)
	return self


## Clamp the total to at least `limit` (applied in finish(), after mults).
func cap_min(limit: int, source_key: String, args: Dictionary = {}, link: String = "") -> Breakdown:
	var l: Line = _make_line(KIND_CAP, source_key, 0, 0, args, null, link)
	l.limit = limit
	l.cap_dir = "min"
	lines.append(l)
	return self


func note(key: String, args: Dictionary = {}) -> Breakdown:
	note_key = key
	note_args = args
	return self


func link_to(codex_id: String) -> Breakdown:
	links.append(codex_id)
	return self


## Computes mult and cap line values and the total. Call once, after the last line.
func finish() -> Breakdown:
	var subtotal: int = 0
	for l: Line in lines:
		if l.kind == KIND_BASE or l.kind == KIND_ADD:
			subtotal += l.value
	var running: int = subtotal
	for l: Line in lines:
		if l.kind == KIND_MULT:
			l.value = Fx.mul_bp(subtotal, l.bp)
			running += l.value
	for l: Line in lines:
		if l.kind == KIND_FLAT:
			running += l.value
	for l: Line in lines:
		if l.kind == KIND_CAP:
			var clamped: int = mini(running, l.limit) if l.cap_dir == "max" else maxi(running, l.limit)
			l.value = clamped - running
			running = clamped
	total = running
	_finished = true
	return self


## True when the lines sum to the total and every mult line follows the contract.
func verify() -> bool:
	if not _finished:
		return false
	var subtotal: int = 0
	var sum: int = 0
	for l: Line in lines:
		sum += l.value
		if l.kind == KIND_BASE or l.kind == KIND_ADD:
			subtotal += l.value
	for l: Line in lines:
		if l.kind == KIND_MULT and l.value != Fx.mul_bp(subtotal, l.bp):
			return false
		if l.child != null and not l.child.verify():
			return false
	return sum == total


## Lines that are not zero-valued caps (a cap that did not bite is not worth showing).
func visible_lines() -> Array[Line]:
	var out: Array[Line] = []
	for l: Line in lines:
		if l.kind == KIND_CAP and l.value == 0:
			continue
		out.append(l)
	return out


func to_dict() -> Dictionary:
	var ls: Array = []
	for l: Line in lines:
		ls.append(l.to_dict())
	return {
		"label_key": label_key, "label_args": label_args.duplicate(true), "unit": unit,
		"resource": resource, "per_turn": per_turn, "lines": ls, "total": total,
		"note_key": note_key, "note_args": note_args.duplicate(true), "links": links.duplicate(),
	}


func _push(kind: String, source_key: String, value: int, bp: int, args: Dictionary, child: Breakdown, link: String) -> Breakdown:
	lines.append(_make_line(kind, source_key, value, bp, args, child, link))
	return self


func _make_line(kind: String, source_key: String, value: int, bp: int, args: Dictionary, child: Breakdown, link: String) -> Line:
	var l: Line = Line.new()
	l.kind = kind
	l.source_key = source_key
	l.source_args = args.duplicate(true)
	l.value = value
	l.bp = bp
	l.child = child
	l.link = link
	return l
