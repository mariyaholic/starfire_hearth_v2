extends SceneTree
## Actual production assembly bounds and terrain, independent of UI containers.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var renderer: Variant=load("res://ui/world/colony_renderer.gd").new()
	renderer.snapshot={"city_kit_version":3}; renderer._load_meshes()
	var failures: int=0
	for style: String in CityBuildingKit.STYLES:
		for count: int in [12,30]:
			var profile: Dictionary=PlanetFieldGenerator.profile("roads",23,"arid")
			var terrain: RegionTerrainGenerator=RegionTerrainGenerator.new(profile,RegionAnchor.choose(profile,"roads"))
			var districts: Array=[]
			for slot: int in count: districts.append({"slot":slot,"district":CityTerrainGenerator.DISTRICTS[slot%6]})
			var layout: Dictionary=terrain.layout(districts,[],count)
			var entries: Array[Dictionary]=[]; var obstacles: Array[Dictionary]=[]
			for site: Dictionary in layout["slots"]:
				var parts: Array[Dictionary]=CityBuildingKitV3.build(site,style,2,"arid")
				var access: Dictionary=CityRoadAccess.describe("slot:"+str(site["slot"]),site["at"],parts,renderer._meshes)
				entries.append(access["entry"]); obstacles.append(access["obstacle"])
			var result: Dictionary=CityAccessNetwork.plan(entries,obstacles,terrain.height_at)
			print(JSON.stringify({"style":style,"count":count,"length":result["length"],"connected":result["connected"].size(),"unreachable":result["unreachable"],"search_us":result["search_us"]}))
			if not result["unreachable"].is_empty(): failures+=1
	renderer.free(); quit(failures)
