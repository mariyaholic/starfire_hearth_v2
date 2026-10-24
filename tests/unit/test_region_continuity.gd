extends RefCounted

func test_globe_region_samples_agree_at_seams_and_poles(t: T) -> void:
 for kind: String in CityTerrainGenerator.KINDS:
  var p: Dictionary = PlanetFieldGenerator.profile("fixture_"+kind,91,kind)
  var field: PlanetFieldGenerator = PlanetFieldGenerator.new(kind,p["seed"],p)
  for pair: Vector2i in [Vector2i(0,0),Vector2i(999999,1000000),Vector2i(0,500000),Vector2i(999999,500000)]:
   var a: Dictionary = {"version":1,"planet":p["id"],"u_ppm":pair.x,"v_ppm":pair.y,"heading_mdeg":90700,"mode":"land"}
   var region: RegionTerrainGenerator = RegionTerrainGenerator.new(p,a)
   for at: Vector2 in [Vector2.ZERO,Vector2(-112,112),Vector2(45,-67)]:
    var d: Vector3 = region.direction_at(at.x,at.y)
    var globe: Dictionary = field.sample(d)
    var local: Dictionary = region.global_sample(at.x,at.y)
    t.eq(globe,local,"same field at arbitrary regional point")
    t.ne(d,Vector3.ZERO); t.ne(region.east,Vector3.ZERO)
    var value: float = globe["elevation"] if kind in ["continental","ocean"] else globe["relief"]
    t.near(region.raw_height(at.x,at.y),(value-region.datum)*p["relief_units"],0.000001)
   t.near(field.sample(SpaceSurfaceBaker.direction(0,0.5))["relief"],field.sample(SpaceSurfaceBaker.direction(1,0.5))["relief"],0.000001,"longitude seam wraps")

func test_globe_marker_matches_godot_sphere_uv_orientation(t: T) -> void:
 var mesh: SphereMesh = SphereMesh.new(); mesh.radial_segments=8; mesh.rings=4
 var arrays: Array = mesh.get_mesh_arrays()
 for i: int in arrays[Mesh.ARRAY_VERTEX].size():
  var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
  var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
  var a: Dictionary = {"u_ppm":roundi(uv.x*1000000),"v_ppm":roundi(uv.y*1000000)}
  t.near(RegionAnchor.mesh_direction(a).distance_to(vertex.normalized()),0.0,0.00001)

func test_all_actual_m1_parcel_sizes_and_modifiers_have_feasible_footings(t: T) -> void:
 var tested_counts: Dictionary = {}
 for kind: String in CityTerrainGenerator.KINDS:
  var p: Dictionary = PlanetFieldGenerator.profile("fixture_"+kind,17,kind)
  var anchor: Dictionary = RegionAnchor.choose(p,"fixture_colony")
  var region: RegionTerrainGenerator = RegionTerrainGenerator.new(p,anchor)
  for size: String in ["tiny","small","medium","large","huge"]:
   for traits: Array[String] in [[] as Array[String],["tidally_locked"] as Array[String],["toxic_atmosphere"] as Array[String],["tidally_locked","toxic_atmosphere"] as Array[String]]:
    var planet: Planet = Planet.new(); planet.type=kind; planet.size=size; planet.traits=traits
    var count: int = ColonyRules.slot_count(planet); tested_counts[count]=true
    var sites: Array = []
    for slot: int in count: sites.append({"slot":slot,"district":"habitation"})
    var recipe: Dictionary = region.layout(sites,[count-1],count)
    t.eq(recipe["slots"].size(),count)
    var coords: Array[Vector2i] = HexGrid.coords(count)
    for slot: Dictionary in recipe["slots"]:
     t.eq(slot["qr"],coords[slot["slot"]]); t.eq(slot["blocked"],slot["slot"]==count-1)
     var at: Vector3 = slot["at"]
     if slot["blocked"]: continue
     t.near(region.height_at(at.x,at.z),at.y,0.00001,"completed footing graded")
     if kind in ["continental","ocean"]: t.ok(at.y >= 1.0,"legal settlement above water")
 for count: int in [12,16,20,25,30]: t.ok(tested_counts.has(count),"all five base sizes exercised")
 t.ok(tested_counts.size()>10,"traits and dome counts are real rules, not synthetic sizes")

func test_local_development_preserves_macro_geography_and_empty_ground(t: T) -> void:
 var p: Dictionary = PlanetFieldGenerator.profile("fixture",42,"continental")
 var a: Dictionary = RegionAnchor.choose(p,"colony")
 var region: RegionTerrainGenerator = RegionTerrainGenerator.new(p,a)
 region.layout([],[],30)
 var original: float = region.height_at(0,0)
 var horizon: float = region.height_at(80,80)
 region.layout([{ "slot":0,"district":"industry"}],[],30)
 t.near(region.height_at(80,80),horizon,0.0)
 region.layout([],[],30)
 t.near(region.height_at(0,0),original,0.0,"Undo/demolition restores empty natural field")
 t.eq(region.anchor,a); t.eq(region.appearance,p)

func test_region_jobs_lod_shared_edges_cancellation_and_backend_parity(t: T) -> void:
 var p: Dictionary = PlanetFieldGenerator.profile("fixture",67,"arid")
 var a: Dictionary = RegionAnchor.choose(p,"colony")
 var terrain: RegionTerrainGenerator = RegionTerrainGenerator.new(p,a)
 terrain.layout([],[],20)
 var low: RegionBakeJob = RegionBakeJob.new(terrain,4,SpaceSurfaceBaker.Cancellation.new(),Vector2(-112,-112),112)
 var high: RegionBakeJob = RegionBakeJob.new(terrain,8,SpaceSurfaceBaker.Cancellation.new(),Vector2(0,-112),112)
 t.ok(low.maps().is_empty(),"partial mesh never published")
 while not low.step(3): pass
 while not high.step(11): pass
 for row: int in 5:
  t.eq(low.vertices[row*5+4],high.vertices[(row*2)*9],"adjacent LODs share global edge coordinates/heights")
  t.eq(low.normals[row*5+4],high.normals[(row*2)*9],"normal samples independent of LOD")
 var token: SpaceSurfaceBaker.Cancellation = SpaceSurfaceBaker.Cancellation.new()
 var cancelled: RegionBakeJob = RegionBakeJob.new(terrain,16,token)
 cancelled.step(4); token.cancel(); cancelled.step(4)
 t.ok(cancelled.cancelled); t.ok(cancelled.maps().is_empty())
 var outputs: Dictionary = {}
 for cooperative: bool in [false,true]:
  var service: GenerationScheduler = GenerationScheduler.new(); service.cooperative=cooperative
  service.region_ready.connect(func(_owner: String,_epoch: int,_key: String,result: Dictionary) -> void: outputs[cooperative]=result["maps"])
  (Engine.get_main_loop() as SceneTree).root.add_child(service)
  service.request_region("region",1,"proof",p,a,[],[],20,16)
  for frame: int in 10000:
   if outputs.has(cooperative): break
   await Engine.get_main_loop().process_frame
  t.ok(outputs.has(cooperative),"bounded regional scheduler completes")
  service.queue_free(); await Engine.get_main_loop().process_frame
 t.eq(outputs[false]["arrays"],outputs[true]["arrays"],"worker/cooperative arrays identical")
 t.eq(outputs[false]["heightmap"].get_data(),outputs[true]["heightmap"].get_data())
