class_name RegionalAccessRoutes
extends RefCounted
## Decorative access uses a separate bounded lattice. It never changes gameplay
## adjacency or bonuses. Line-of-sight simplification removes grid-shaped zigzags.
const STEP: float = 1.5
const LIMIT: int = 24
const HUB: Vector2i = Vector2i(-16,-16)

static func build(slots: Array, occupied: Array[int], landmarks: Array[Dictionary]=[]) -> Array[Array]:
	var goals: Array[Dictionary]=[]
	for target: int in occupied:
		if target<0 or target>=slots.size() or slots[target]["blocked"]: continue
		var at: Vector3=slots[target]["at"]
		goals.append({"point":Vector2(at.x,at.z),"slot":target})
	for landmark: Dictionary in landmarks:
		goals.append({"point":landmark["center"]-Vector2(landmark["reach"].x+1.5,0),"slot":-1})
	var routes: Array[Array]=[]
	for goal: Dictionary in goals:
		var point: Vector2=goal["point"]
		var target: Vector2i=Vector2i(roundi(point.x/STEP),roundi(point.y/STEP))
		var frontier: Array[Vector2i]=[HUB]
		var previous: Dictionary={HUB:HUB}
		var cursor: int=0
		while cursor<frontier.size() and not previous.has(target):
			var current: Vector2i=frontier[cursor]; cursor+=1
			for offset: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var next: Vector2i=current+offset
				if absi(next.x)>LIMIT or absi(next.y)>LIMIT or previous.has(next): continue
				if not clear_segment(Vector2(current)*STEP,Vector2(next)*STEP,slots,occupied,int(goal["slot"]),landmarks): continue
				previous[next]=current; frontier.append(next)
		if not previous.has(target): continue
		var path: Array=[point]
		var cell: Vector2i=target
		while cell!=HUB:
			path.append(Vector2(cell)*STEP); cell=previous[cell]
		path.append(Vector2(HUB)*STEP)
		var simplified: Array=[path[0]]
		var start: int=0
		while start<path.size()-1:
			var end: int=path.size()-1
			while end>start+1 and not clear_segment(path[start],path[end],slots,occupied,int(goal["slot"]),landmarks): end-=1
			simplified.append(path[end]); start=end
		var sampled: Array=[]
		for i: int in simplified.size()-1:
			var a: Vector2=simplified[i]; var b: Vector2=simplified[i+1]
			var count: int=maxi(1,ceili(a.distance_to(b)))
			for n: int in count: sampled.append(a.lerp(b,float(n)/count))
		sampled.append(simplified[-1]); routes.append(sampled)
	return routes

static func clear_segment(a: Vector2, b: Vector2, slots: Array, occupied: Array[int], exempt: int, landmarks: Array[Dictionary]=[]) -> bool:
	for site: Dictionary in slots:
		if int(site["slot"])==exempt: continue
		if not site["blocked"] and not occupied.has(int(site["slot"])): continue
		var pos: Vector3=site["at"]
		if CityTerrainGenerator._segment_distance(Vector2(pos.x,pos.z),a,b)<(3.55 if site["blocked"] else 3.25): return false
	for landmark: Dictionary in landmarks:
		var rect: Rect2=Rect2(landmark["center"]-landmark["reach"],landmark["reach"]*2).grow(0.3)
		if rect.has_point(a) or rect.has_point(b): return false
		var corners: Array[Vector2]=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for i: int in 4:
			if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return false
	return true
