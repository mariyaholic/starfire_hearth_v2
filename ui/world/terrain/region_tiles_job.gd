class_name RegionTilesJob
extends RegionBakeJob
## Sixteen bounded tiles, a detailed central square and a coarse surrounding
## ring. Every common sample uses the same field and normal offsets. Vertical
## skirts cover the intermediate vertices at unequal-resolution boundaries.
var tile_index: int = 0
var current: RegionBakeJob
var chunks: Array[Dictionary] = []
var water_map: Image

func _init(region: RegionTerrainGenerator, resolution: int, cancellation: SpaceSurfaceBaker.Cancellation) -> void:
	super(region,resolution,cancellation)
	heightmap = null
	_next_tile()

func _next_tile() -> void:
	var x: int = tile_index % 4
	var z: int = tile_index / 4
	var core: bool = x in [1,2] and z in [1,2]
	current = RegionBakeJob.new(terrain,maxi(4,subdivisions / (2 if core else 8)),token,Vector2(-112+x*56,-112+z*56),56,tile_index == 0)

func step(budget: int = 8) -> bool:
	if done or cancelled: return true
	if token != null and token.is_cancelled(): cancelled = true; return true
	var before: int = current.cursor
	var finished: bool = current.step(budget)
	cursor += current.cursor-before
	if current.cancelled: cancelled = true; return true
	if not finished: return false
	var output: Dictionary = current.maps()
	var arrays: Array = output["arrays"]
	_add_skirts(arrays,current.subdivisions)
	chunks.append({"arrays":arrays,"origin":current.origin,"span":56.0,"resolution":current.subdivisions,"skirt_depth":3.0})
	if tile_index == 0: water_map = current.heightmap
	tile_index += 1
	done = tile_index == 16
	if not done: _next_tile()
	return done

static func _add_skirts(arrays: Array, resolution: int) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var cs: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var boundary: Array[int] = []
	for i: int in resolution: boundary.append(i)
	for i: int in resolution: boundary.append(i*(resolution+1)+resolution)
	for i: int in resolution: boundary.append(resolution*(resolution+1)+resolution-i)
	for i: int in resolution: boundary.append((resolution-i)*(resolution+1))
	var start: int = points.size()
	for index: int in boundary:
		points.append(points[index]-Vector3(0,3,0)); ns.append(ns[index]); cs.append(cs[index]); uvs.append(uvs[index])
	for i: int in boundary.size():
		var next: int = (i+1)%boundary.size()
		faces.append_array(PackedInt32Array([boundary[i],start+i,boundary[next],boundary[next],start+i,start+next]))
	arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_NORMAL]=ns
	arrays[Mesh.ARRAY_COLOR]=cs; arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_INDEX]=faces

func maps() -> Dictionary:
	if not done or cancelled: return {}
	return {"arrays":chunks[0]["arrays"],"chunks":chunks,"heightmap":water_map,"appearance_key":PlanetFieldGenerator.key(terrain.appearance),"anchor":terrain.anchor.duplicate(true)}
