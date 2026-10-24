class_name CityAccessNetwork
extends RefCounted
## Presentation-only streets. One shared network joins external entry aprons.
## Search and tie order are stable; missing access is returned as a diagnostic.
const VERSION: int = 2
const STEP: float = 0.75
const CLEARANCE: float = 0.24
const MAX_GRADE: float = 0.85
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]

class StreetGraph:
	extends AStar2D
	var sink: int = -1
	var source: int = -1
	var heights: Dictionary = {}
	var gate_costs: Dictionary = {}
	func _compute_cost(from_id: int, to_id: int) -> float:
		if from_id == sink or to_id == sink: return 0.0
		if from_id == source: return float(gate_costs.get(to_id,0.0))
		if to_id == source: return float(gate_costs.get(from_id,0.0))
		var distance: float = get_point_position(from_id).distance_to(get_point_position(to_id))
		var grade: float = absf(float(heights[from_id])-float(heights[to_id]))/maxf(distance,0.01)
		return distance*(1.0+grade*grade*4.0)
	func _estimate_cost(_from_id: int, _end_id: int) -> float:
		# The destination is any existing street node, via a zero-cost sink.
		return 0.0

static func plan(entries: Array[Dictionary], obstacles: Array[Dictionary], height: Callable = Callable(), wet: bool = false) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = {"version":VERSION,"routes":[],"access_paths":[],"connected":[],"unreachable":[],"junctions":[],"length":0.0,"cost":0.0,"search_us":0}
	if entries.is_empty(): return result
	var ordered: Array[Dictionary] = entries.duplicate(true)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a["id"])<str(b["id"]))
	var bounds: Rect2 = Rect2(ordered[0]["point"],Vector2.ZERO)
	for entry: Dictionary in ordered: bounds=bounds.expand(entry["point"])
	for obstacle: Dictionary in obstacles:
		if obstacle.has("rect"): bounds=bounds.merge(obstacle["rect"])
		else:
			var radius: float=float(obstacle["radius"])
			bounds=bounds.merge(Rect2(obstacle["center"]-Vector2.ONE*radius,Vector2.ONE*radius*2))
	bounds=bounds.grow(7.5)
	var origin: Vector2i=Vector2i(floori(bounds.position.x/STEP),floori(bounds.position.y/STEP))
	var end: Vector2i=Vector2i(ceili(bounds.end.x/STEP),ceili(bounds.end.y/STEP))
	var dimensions: Vector2i=end-origin+Vector2i.ONE
	if dimensions.x*dimensions.y>24000:
		for entry: Dictionary in ordered: result["unreachable"].append({"id":entry["id"],"reason":"search_bounds"})
		return result
	var graph: StreetGraph=StreetGraph.new()
	var cells: Dictionary={}
	for y: int in dimensions.y:
		for x: int in dimensions.x:
			var cell: Vector2i=origin+Vector2i(x,y)
			var point: Vector2=Vector2(cell)*STEP
			if not clear(point,point,obstacles): continue
			var elevation: float=_height(point,height)
			if wet and elevation<0.15: continue
			var id: int=y*dimensions.x+x
			cells[cell]=id; graph.add_point(id,point); graph.heights[id]=elevation
	for cell: Vector2i in cells:
		var id: int=int(cells[cell])
		for direction: Vector2i in DIRECTIONS:
			var other: Vector2i=cell+direction
			if not cells.has(other): continue
			var next_id: int=int(cells[other])
			if traversable(Vector2(cell)*STEP,Vector2(other)*STEP,obstacles,height,wet): graph.connect_points(id,next_id)
	var gates: Array[Dictionary]=[]
	for entry: Dictionary in ordered:
		var point: Vector2=entry["point"]
		var nearest: int=-1
		var best: float=INF
		var around: Vector2i=Vector2i(roundi(point.x/STEP),roundi(point.y/STEP))
		for y: int in range(-2,3):
			for x: int in range(-2,3):
				var cell: Vector2i=around+Vector2i(x,y)
				if not cells.has(cell): continue
				var candidate: Vector2=Vector2(cell)*STEP
				var distance: float=point.distance_squared_to(candidate)
				if distance>=best or not traversable(point,candidate,obstacles,height,wet): continue
				nearest=int(cells[cell]); best=distance
		if nearest<0:
			result["unreachable"].append({"id":entry["id"],"reason":"entrance_blocked"})
		else: gates.append({"id":entry["id"],"point":point,"node":nearest})
	if gates.is_empty(): return result
	graph.sink=dimensions.x*dimensions.y
	graph.add_point(graph.sink,Vector2.ZERO)
	graph.source=graph.sink+1
	graph.add_point(graph.source,Vector2.ZERO)
	var root_gate: Dictionary=gates.pop_front()
	var network: Dictionary={int(root_gate["node"]):true}
	graph.connect_points(int(root_gate["node"]),graph.sink)
	result["connected"].append(root_gate["id"])
	var access: Array=[root_gate["point"],graph.get_point_position(int(root_gate["node"]))]
	result["access_paths"].append(access)
	var edges: Dictionary={}
	_add_segment(edges,access[0],access[1])
	for gate: Dictionary in gates:
		var node: int=int(gate["node"])
		graph.gate_costs[node]=(gate["point"] as Vector2).distance_to(graph.get_point_position(node))
		if not graph.are_points_connected(graph.source,node): graph.connect_points(graph.source,node)
	# Nearest feasible connection first, measured through the terrain, not air.
	while not gates.is_empty():
		var best_path: PackedInt64Array=graph.get_id_path(graph.source,graph.sink)
		if best_path.is_empty():
			for gate: Dictionary in gates: result["unreachable"].append({"id":gate["id"],"reason":"no_supported_corridor"})
			break
		var best_index: int=0
		while int(gates[best_index]["node"])!=best_path[1]: best_index+=1
		var gate: Dictionary=gates.pop_at(best_index)
		if not gates.any(func(other: Dictionary) -> bool: return other["node"]==gate["node"]):
			graph.disconnect_points(graph.source,int(gate["node"]))
		var best_cost: float=0.0
		for n: int in best_path.size()-2: best_cost+=graph._compute_cost(best_path[n],best_path[n+1])
		var path: Array=[gate["point"]]
		for n: int in range(1,best_path.size()-1):
			var node: int=best_path[n]
			path.append(graph.get_point_position(node))
			if not network.has(node):
				network[node]=true; graph.connect_points(node,graph.sink)
		for i: int in path.size()-1: _add_segment(edges,path[i],path[i+1])
		result["access_paths"].append(path)
		result["connected"].append(gate["id"]); result["cost"]+=best_cost
	var adjacency: Dictionary={}
	for edge: Array in edges.values():
		for i: int in 2:
			var point: Vector2=edge[i]
			if not adjacency.has(point): adjacency[point]=[]
			adjacency[point].append(edge[1-i])
	for point: Vector2 in adjacency:
		if adjacency[point].size()>2: result["junctions"].append(point)
	result["routes"]=_chains(adjacency,obstacles,height,wet)
	for route: Array in result["routes"]:
		for i: int in route.size()-1: result["length"]+=(route[i] as Vector2).distance_to(route[i+1])
	result["search_us"]=Time.get_ticks_usec()-started
	return result

static func _height(point: Vector2, height: Callable) -> float:
	return float(height.call(point.x,point.y)) if height.is_valid() else 0.0

static func traversable(a: Vector2,b: Vector2,obstacles: Array[Dictionary],height: Callable,wet: bool) -> bool:
	if not clear(a,b,obstacles): return false
	var distance: float=a.distance_to(b)
	var count: int=maxi(1,ceili(distance/0.3))
	var previous: float=_height(a,height)
	if wet and previous<0.15: return false
	for i: int in range(1,count+1):
		var elevation: float=_height(a.lerp(b,float(i)/count),height)
		if wet and elevation<0.15: return false
		if absf(elevation-previous)>MAX_GRADE*distance/count+0.001: return false
		previous=elevation
	return true

static func clear(a: Vector2,b: Vector2,obstacles: Array[Dictionary]) -> bool:
	for obstacle: Dictionary in obstacles:
		if obstacle.has("rect"):
			var rect: Rect2=(obstacle["rect"] as Rect2).grow(CLEARANCE)
			if rect.has_point(a) or rect.has_point(b): return false
			var corners: Array[Vector2]=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
			for i: int in 4:
				if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return false
		elif CityTerrainGenerator._segment_distance(obstacle["center"],a,b)<float(obstacle["radius"])+CLEARANCE: return false
	return true

static func _edge_key(a: Vector2,b: Vector2) -> String:
	var first: String=str(a); var second: String=str(b)
	return first+"/"+second if first<second else second+"/"+first

static func _add_segment(edges: Dictionary,a: Vector2,b: Vector2) -> void:
	if a.distance_squared_to(b)<0.00001: return
	edges[_edge_key(a,b)]=[a,b]

static func _chains(adjacency: Dictionary,obstacles: Array[Dictionary],height: Callable,wet: bool) -> Array[Array]:
	var routes: Array[Array]=[]
	var visited: Dictionary={}
	for point: Vector2 in adjacency:
		if adjacency[point].size()==2: continue
		for next: Vector2 in adjacency[point]:
			if visited.has(_edge_key(point,next)): continue
			var chain: Array=[point]
			var previous: Vector2=point
			var current: Vector2=next
			while true:
				visited[_edge_key(previous,current)]=true
				chain.append(current)
				if adjacency[current].size()!=2: break
				var neighbors: Array=adjacency[current]
				var following: Vector2=neighbors[1] if neighbors[0]==previous else neighbors[0]
				if visited.has(_edge_key(current,following)): break
				previous=current; current=following
			routes.append(chain)
	# An isolated loop is possible when multiple aprons meet the same street cell.
	for point: Vector2 in adjacency:
		for next: Vector2 in adjacency[point]:
			if not visited.has(_edge_key(point,next)):
				visited[_edge_key(point,next)]=true; routes.append([point,next])
	var protected: Dictionary={}
	for chain: Array in routes:
		for i: int in chain.size()-1: _add_segment(protected,chain[i],chain[i+1])
	var finished: Array[Array]=[]
	for chain: Array in routes:
		var smooth: Array=_smooth_chain(chain,protected,obstacles,height,wet)
		for i: int in chain.size()-1: protected.erase(_edge_key(chain[i],chain[i+1]))
		for i: int in smooth.size()-1: _add_segment(protected,smooth[i],smooth[i+1])
		finished.append(_collinear(smooth))
	return finished

static func _smooth_chain(chain: Array,protected: Dictionary,obstacles: Array[Dictionary],height: Callable,wet: bool) -> Array:
	var own: Dictionary={}
	for i: int in chain.size()-1: own[_edge_key(chain[i],chain[i+1])]=true
	var output: Array=[chain[0]]
	var start: int=0
	while start<chain.size()-1:
		var end: int=chain.size()-1
		while end>start+1:
			if traversable(chain[start],chain[end],obstacles,height,wet) and _no_crossing(chain[start],chain[end],protected,own): break
			end-=1
		output.append(chain[end]); start=end
	return output

static func _no_crossing(a: Vector2,b: Vector2,protected: Dictionary,own: Dictionary) -> bool:
	for key: String in protected:
		if own.has(key): continue
		var edge: Array=protected[key]
		var hit: Variant=Geometry2D.segment_intersects_segment(a,b,edge[0],edge[1])
		if hit!=null and (hit as Vector2).distance_to(a)>0.001 and (hit as Vector2).distance_to(b)>0.001: return false
	return true

static func _collinear(path: Array) -> Array:
	var output: Array=[]
	for point: Vector2 in path:
		if output.size()>1:
			var a: Vector2=output[-2]; var b: Vector2=output[-1]
			if absf((b-a).cross(point-b))<0.00001 and (b-a).dot(point-b)>0: output.pop_back()
		output.append(point)
	# Terrain-following meshes need short spans even on a straight street.
	var sampled: Array=[]
	for i: int in output.size()-1:
		var a: Vector2=output[i]; var b: Vector2=output[i+1]
		var count: int=maxi(1,ceili(a.distance_to(b)/STEP))
		for n: int in count: sampled.append(a.lerp(b,float(n)/count))
	if not output.is_empty(): sampled.append(output[-1])
	return sampled
