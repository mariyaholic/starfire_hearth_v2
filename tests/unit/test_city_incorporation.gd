extends RefCounted

func _state() -> GameState:
	return ScenarioLoader.build(Content.db(),"s1_first_light",11)

func test_terrain_keys_ignore_selection_revision_tiers_and_queues(t: T) -> void:
	var state: GameState=_state()
	var colony: Colony=GameModel.capital(state)
	var description: Dictionary=VisualSnapshotBuilder.build(state,"colony",colony.id,1)
	var before: Dictionary=ColonyRenderer.ground_inputs(description)
	description["revision"]="changed"; description["stage"]="city"
	description["districts"][0]["tier"]=3
	description["queue"].append({"item_id":"q","slot":8,"id":"research","kind":"district","tier":1,"turns_left":1,"total_turns":2})
	t.eq(ColonyRenderer.ground_inputs(description),before,"hover/queue/upgrade/menu updates cannot regenerate terrain")
	description["districts"].remove_at(0)
	t.ne(ColonyRenderer.ground_inputs(description),before,"completed footprint changes have a distinct ground recipe")
	for count: int in [5,6,7,8,9,10,11,12,14,15,16,18,20,23,25,28,30]:
		description["slot_count"]=count
		for slot: int in count: t.ok(WorldViewController.permits(description,"slot:"+str(slot)))
		for invalid: String in ["slot:-1","slot:"+str(count),"slot:00","slot:1.0","slot:secret",colony.id]: t.not_ok(WorldViewController.permits(description,invalid))
	var foreign: GameState=state.clone(); foreign.colonies[colony.id].owner_id="foreign"
	t.ok(VisualSnapshotBuilder.build(foreign,"colony",colony.id,1).is_empty())

func test_prepared_ground_is_committed_saved_optional_and_forward_tolerant(t: T) -> void:
	var state: GameState=_state(); var colony: Colony=GameModel.capital(state)
	var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state)
	var count: int=ColonyRules.slot_count(state.planets[colony.planet_id])
	var before: Array[int]=store.prepared_for(colony.id,count)
	var hash: String=state.state_hash()
	var free: int=ColonyRules.free_slots(colony,state.planets[colony.planet_id])[0]
	var cmd: Command=PlaceDistrictCommand.create(state.player_id,colony.id,free,"agriculture")
	t.ok(cmd.validate(state).ok)
	var preview: GameState=state.clone(); cmd.apply(preview)
	t.eq(store.prepared_for(colony.id,count),before,"queued preview has no permanent groundworks")
	store.sync_committed(preview)
	t.eq(store.prepared_for(colony.id,count),before,"even committed queue is temporary")
	var cleared: GameState=state.clone(); cleared.colonies[colony.id].districts.clear()
	store.sync_committed(cleared)
	t.eq(store.prepared_for(colony.id,count),before,"demolition retains prepared sites")
	var raw: String=store.save_fields(cleared)["presentation"]
	var restored: AppearanceProfileStore=AppearanceProfileStore.new(); restored.bind(cleared,raw)
	t.eq(restored.prepared_for(colony.id,count),before); t.eq(state.state_hash(),hash)
	var old: Dictionary=store.data.duplicate(true); old.erase("groundworks")
	restored.bind(state,PresentationEnvelope.pack(old))
	t.eq(restored.prepared_for(colony.id,count),before,"Stage D saves reconstruct only completed footprints")
	old["groundworks"]={"version":99,"future_data":"preserve"}
	restored.bind(state,PresentationEnvelope.pack(old))
	t.ok(restored.prepared_for(colony.id,count).is_empty())
	t.eq(PresentationEnvelope.inspect(restored.save_fields(state)["presentation"])["data"]["groundworks"],old["groundworks"])
	var authoritative: Dictionary=store.data.duplicate(true)
	authoritative["groundworks"]={"version":1,"sites":{colony.id:[0,1]},"future_extension":"retain"}
	var overlay: Dictionary=authoritative.duplicate(true); overlay["groundworks"]["sites"][colony.id]=[2]
	var merged: Dictionary=AppearanceProfileStore.merge_additions(authoritative,overlay)
	t.eq(merged["groundworks"]["sites"][colony.id],[0,1,2]); t.eq(merged["groundworks"]["future_extension"],"retain")
	authoritative["groundworks"]["version"]=99
	t.eq(AppearanceProfileStore.merge_additions(authoritative,overlay)["groundworks"],authoritative["groundworks"],"future ground representation keeps authority")
	var current: AppearanceProfileStore=AppearanceProfileStore.new(); current.bind(state,"","",true)
	t.eq(current.data["catalog"]["city_kit"],3); t.eq(current.architecture_for("ark"),"ark")
	var newer: Dictionary=current.data.duplicate(true)
	var future: String=JSON.stringify({"format":PresentationEnvelope.FORMAT,"version":77,"payload":"{}","checksum":"{}".sha256_text(),"compatibility":PresentationEnvelope.pack(newer)})
	var older: Dictionary=store.data.duplicate(true); older["requires_future_renderer"]=true
	older["profiles"][colony.planet_id]["seed"]=999
	older["groundworks"]["sites"][colony.id].append(free)
	current.bind(state,future,PresentationEnvelope.pack(older))
	t.not_ok(current.fallback,"newer renderer recovers original supported compatibility view")
	t.eq(current.data["catalog"]["city_kit"],3)
	t.eq(current.profile_for(colony.planet_id)["seed"],newer["profiles"][colony.planet_id]["seed"],"old fallback never replaces authoritative planet")
	t.ok(current.prepared_for(colony.id,count).has(free),"understood groundworks additions survive old overlay")
	t.eq(current.save_fields(state)["presentation"],future,"original unknown wrapper stays byte-exact")

func test_actual_development_and_landmarks_fit_every_real_size(t: T) -> void:
	var state: GameState=_state(); var colony: Colony=GameModel.capital(state)
	for population: int in [4,5,15]:
		colony.pops=population
		t.eq(M1VisualSnapshot.colony_view(state,colony.id)["stage"],{4:"settlement",5:"colony",15:"city"}[population])
	for style: String in CityBuildingKit.STYLES:
		for kind: String in CityTerrainGenerator.DISTRICTS:
			var fingerprints: Array[String]=[]
			for tier: int in [1,2,3]:
				var parts: Array[Dictionary]=CityBuildingKitV2.build({"kind":kind,"blocked":false,"seed":77},style,tier-1,"continental")
				t.ok(not parts.is_empty()); fingerprints.append(str(parts).sha256_text())
			t.ne(fingerprints[0],fingerprints[1]); t.ne(fingerprints[1],fingerprints[2],"each district's actual tier supplies its development")
	var p: Dictionary=PlanetFieldGenerator.profile("fixture",23,"arid")
	var terrain: RegionTerrainGenerator=RegionTerrainGenerator.new(p,RegionAnchor.choose(p,"fixture"))
	var renderer: ColonyRenderer=ColonyRenderer.new(); renderer.generator=terrain
	for count: int in [12,16,20,25,30]:
		renderer.recipe=terrain.layout([],[],count)
		var landmarks: Array[Dictionary]=[]
		for index: int in 2:
			var position: Vector3=renderer._landmark_position(index)
			var reach: Vector2=Vector2(6,12) if index==0 else Vector2(3.5,3.5)
			for site: Dictionary in renderer.recipe["slots"]: t.ok(absf(position.x-site["at"].x)>reach.x+3.2,"landmark stays outside canonical parcel footprints")
			landmarks.append({"center":Vector2(position.x,position.z),"reach":reach})
		t.eq(RegionalAccessRoutes.build(renderer.recipe["slots"],[0,count-1],landmarks).size(),4,"districts and both landmarks receive decorative access")
	renderer.free()

func test_isolated_outer_sites_have_obstacle_avoiding_decorative_access(t: T) -> void:
	var p: Dictionary=PlanetFieldGenerator.profile("fixture",23,"arid")
	var terrain: RegionTerrainGenerator=RegionTerrainGenerator.new(p,RegionAnchor.choose(p,"fixture"))
	for count: int in [12,16,20,25,30]:
		var coords: Array[Vector2i]=HexGrid.coords(count)
		var target: int=count-1
		var blocked: Array[int]=[]
		for i: int in count:
			var delta: Vector2i=coords[i]-coords[target]
			if maxi(absi(delta.x),maxi(absi(delta.y),absi(delta.x+delta.y)))==1: blocked.append(i)
		var recipe: Dictionary=terrain.layout([{"slot":target,"district":"industry"}],blocked,count)
		var routes: Array[Array]=RegionalAccessRoutes.build(recipe["slots"],[target])
		t.eq(routes.size(),1,"outer site remains reachable around blocked interior neighbours")
		if routes.is_empty(): continue
		for i: int in routes[0].size()-1:
			for index: int in blocked:
				var at: Vector3=recipe["slots"][index]["at"]
				t.ok(CityTerrainGenerator._segment_distance(Vector2(at.x,at.z),routes[0][i],routes[0][i+1])>=3.55,"route avoids blocked outcrop")
		t.eq(HexGrid.coords(count),coords,"presentation never changes adjacency")

func test_chunked_region_core_ring_skirts_and_scheduler_parity(t: T) -> void:
	var p: Dictionary=PlanetFieldGenerator.profile("fixture",67,"arid")
	var a: Dictionary=RegionAnchor.choose(p,"fixture")
	var terrain: RegionTerrainGenerator=RegionTerrainGenerator.new(p,a); terrain.layout([],[],20)
	var job: RegionTilesJob=RegionTilesJob.new(terrain,16,SpaceSurfaceBaker.Cancellation.new())
	t.ok(job.maps().is_empty())
	while not job.step(23): pass
	var maps: Dictionary=job.maps(); t.eq(maps["chunks"].size(),16)
	var core: int=0
	for tile: Dictionary in maps["chunks"]:
		var resolution: int=tile["resolution"]
		if resolution==8: core+=1
		var points: PackedVector3Array=tile["arrays"][Mesh.ARRAY_VERTEX]
		t.eq(points.size(),(resolution+1)*(resolution+1)+resolution*4)
		t.eq(tile["skirt_depth"],3.0)
		for point: Vector3 in points.slice(0,(resolution+1)*(resolution+1)):
			t.near(point.y,terrain.height_at(point.x,point.z),0.000001)
	t.eq(core,4)
	var low: Dictionary=maps["chunks"][1]; var high: Dictionary=maps["chunks"][5]
	for col: int in 5:
		t.eq(low["arrays"][Mesh.ARRAY_VERTEX][20+col],high["arrays"][Mesh.ARRAY_VERTEX][col*2],"different LODs share boundary samples")
		t.eq(low["arrays"][Mesh.ARRAY_NORMAL][20+col],high["arrays"][Mesh.ARRAY_NORMAL][col*2])
	var outputs: Dictionary={}
	for cooperative: bool in [false,true]:
		var service: GenerationScheduler=GenerationScheduler.new(); service.cooperative=cooperative
		service.region_ready.connect(func(_owner: String,_epoch: int,_key: String,result: Dictionary) -> void: outputs[cooperative]=result["maps"])
		Engine.get_main_loop().root.add_child(service)
		service.request_region("tiles",1,"tiles",p,a,[],[],20,16,true)
		for frame: int in 10000:
			if outputs.has(cooperative): break
			await Engine.get_main_loop().process_frame
		t.ok(outputs.has(cooperative)); service.queue_free(); await Engine.get_main_loop().process_frame
	t.eq(outputs[false]["chunks"],outputs[true]["chunks"])
	t.eq(outputs[false]["heightmap"].get_data(),outputs[true]["heightmap"].get_data())
	var token: SpaceSurfaceBaker.Cancellation=SpaceSurfaceBaker.Cancellation.new()
	job=RegionTilesJob.new(terrain,16,token); job.step(5); token.cancel(); job.step(5)
	t.ok(job.cancelled); t.ok(job.maps().is_empty())
