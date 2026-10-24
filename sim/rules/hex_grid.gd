class_name HexGrid
extends RefCounted
## Where a planet's slots sit (DESIGN_LOG 69). Slot 0 is the centre hex; the rings around it are
## filled in order. A ring that is only partly used spreads its slots evenly around the ring, so
## every planet reads as a disc. Coordinates are axial (q, r); adjacency is the six axial
## neighbours. The planner draws from the same coordinates, so what it shows as adjacent is
## what the rules count.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

static var _cache: Dictionary[int, Array] = {}


## Axial coordinates of slots 0..count-1.
static func coords(count: int) -> Array[Vector2i]:
	if _cache.has(count):
		var cached: Array[Vector2i] = []
		cached.assign(_cache[count])
		return cached
	var out: Array[Vector2i] = []
	if count <= 0:
		return out
	out.append(Vector2i.ZERO)
	var radius: int = 1
	while out.size() < count:
		var ring: Array[Vector2i] = _ring(radius)
		var want: int = mini(ring.size(), count - out.size())
		if want == ring.size():
			out.append_array(ring)
		else:
			# Spread `want` cells evenly around the ring, starting from its first cell.
			for i in want:
				out.append(ring[Fx.div_floor(i * ring.size(), want)])
		radius += 1
	_cache[count] = out.duplicate()
	return out


## Slots next to `slot` on a planet with `count` slots, in slot order.
static func neighbours(slot: int, count: int) -> Array[int]:
	var cs: Array[Vector2i] = coords(count)
	var out: Array[int] = []
	if slot < 0 or slot >= cs.size():
		return out
	var here: Vector2i = cs[slot]
	for i in cs.size():
		if i == slot:
			continue
		if is_adjacent(here, cs[i]):
			out.append(i)
	return out


static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	for d: Vector2i in DIRECTIONS:
		if a + d == b:
			return true
	return false


## Cells of the ring at `radius`, walking from the south-west corner.
static func _ring(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hex: Vector2i = DIRECTIONS[4] * radius
	for side in 6:
		for _step in radius:
			out.append(hex)
			hex += DIRECTIONS[side]
	return out
