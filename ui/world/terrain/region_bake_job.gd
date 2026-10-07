class_name RegionBakeJob
extends RefCounted
## CPU arrays only, same bounded job on worker or non-threaded browser.
var terrain: RegionTerrainGenerator
var subdivisions: int
var token: SpaceSurfaceBaker.Cancellation
var origin: Vector2
var span: float
var cursor: int = 0
var done: bool = false
var cancelled: bool = false
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var uv: PackedVector2Array = PackedVector2Array()
var indices: PackedInt32Array = PackedInt32Array()
var include_water: bool = true
var heightmap: Image
const WATER_SIZE: int = 64

func _init(region: RegionTerrainGenerator, resolution: int, cancellation: SpaceSurfaceBaker.Cancellation, chunk_origin: Vector2 = Vector2(-112,-112), chunk_span: float = 224.0, water: bool = true) -> void:
	assert(resolution >= 4 and resolution <= 256)
	terrain = region; subdivisions = resolution; token = cancellation
	origin = chunk_origin; span = chunk_span; include_water = water
	heightmap = Image.create(WATER_SIZE,WATER_SIZE,false,Image.FORMAT_RF)

func step(budget: int = 8) -> bool:
	if done or cancelled: return true
	var count: int = (subdivisions+1)*(subdivisions+1)
	var end: int = mini(cursor+budget,count+(WATER_SIZE*WATER_SIZE if include_water else 0))
	while cursor < end:
		if token != null and token.is_cancelled(): cancelled = true; return true
		if cursor < count:
			var row: int = cursor / (subdivisions+1)
			var col: int = cursor % (subdivisions+1)
			var x: float = origin.x+span*float(col)/subdivisions
			var z: float = origin.y+span*float(row)/subdivisions
			var y: float = terrain.height_at(x,z)
			var normal: Vector3 = Vector3(terrain.height_at(x-0.3,z)-terrain.height_at(x+0.3,z),0.6,terrain.height_at(x,z-0.3)-terrain.height_at(x,z+0.3)).normalized()
			vertices.append(Vector3(x,y,z)); normals.append(normal); uv.append(Vector2(x,z)/3.0)
			var color: Color = terrain.global_sample(x,z)["color"]
			for site: Dictionary in terrain.slots:
				if site["blocked"] or not terrain.prepared_sites.has(int(site["slot"])): continue
				var at: Vector3 = site["at"]
				var distance: float = Vector2(x-at.x,z-at.z).length()
				if distance < 3.0: color=color.lerp(Color("827e6a"),0.6*(1-smoothstep(2.3,3.0,distance)))
			colors.append(color)
			if col < subdivisions and row < subdivisions:
				indices.append_array(PackedInt32Array([cursor,cursor+1,cursor+subdivisions+1,cursor+1,cursor+subdivisions+2,cursor+subdivisions+1]))
		else:
			var at: int = cursor-count
			var row: int = at / WATER_SIZE
			var col: int = at % WATER_SIZE
			heightmap.set_pixel(col,row,Color(terrain.height_at(lerpf(-112,112,float(col)/(WATER_SIZE-1)),lerpf(-112,112,float(row)/(WATER_SIZE-1))),0,0))
		cursor += 1
	done = cursor == count+(WATER_SIZE*WATER_SIZE if include_water else 0)
	return done

func maps() -> Dictionary:
	if not done or cancelled: return {}
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	return {"arrays":arrays,"heightmap":heightmap,"appearance_key":PlanetFieldGenerator.key(terrain.appearance),"anchor":terrain.anchor.duplicate(true)}
