extends RefCounted

func test_hidden_parcel_lines_keep_blocked_outcrops_visible(t: T) -> void:
	var city: ColonyRenderer=ColonyRenderer.new()
	city._planner=Node3D.new(); city.add_child(city._planner)
	var lines: MeshInstance3D=MeshInstance3D.new(); city._planner.add_child(lines)
	var outcrop: MultiMeshInstance3D=MultiMeshInstance3D.new(); city._planner.add_child(outcrop)
	city.set_parcel_overlay(false)
	t.ok(city._planner.visible); t.not_ok(lines.visible); t.ok(outcrop.visible)
	city.set_parcel_overlay(true); t.ok(lines.visible); t.ok(outcrop.visible)
	city.free()

func test_finished_belt_retains_legacy_rock_positions(t: T) -> void:
	var renderer: M1SystemRenderer=M1SystemRenderer.new()
	var old: Node3D=Node3D.new(); var current: Node3D=Node3D.new()
	renderer.snapshot={"planet_material_version":1}; renderer._rocks(old,64133)
	renderer.snapshot={"planet_material_version":2}; renderer._rocks(current,64133)
	t.eq(old.get_child_count(),36); t.eq(current.get_child_count(),36)
	for i: int in 36:
		t.eq(old.get_child(i).position,current.get_child(i).position)
	t.ok(old.get_child(0).material_override is StandardMaterial3D)
	t.ok(current.get_child(0).material_override is ShaderMaterial)
	old.free(); current.free(); renderer.free()

func test_explicit_finish_upgrade_keeps_physical_and_unknown_saved_fields(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var hash: String=state.state_hash()
	for catalog: Dictionary in [AppearanceProfileStore.CATALOG,AppearanceProfileStore.STAGE_E_CATALOG]:
		var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state,"","",true)
		store.data["catalog"]=catalog.duplicate(); store.data["architecture"]["kit_version"]=catalog["city_kit"]
		store.data["future_extension"]={"retain":[1,2,3]}
		var old: Dictionary=store.data.duplicate(true)
		var raw: String=store.save_fields(state)["presentation"]
		store.bind(state,raw)
		t.eq(store.data,old,"opening an old supported save does not opt into new art")
		t.ok(store.can_upgrade_finish()); t.ok(store.upgrade_finish())
		t.eq(store.data["catalog"],AppearanceProfileStore.CURRENT_CATALOG)
		for key: String in ["profiles","anchors","groundworks","identity","legacy","future_extension"]: t.eq(store.data[key],old[key],"finish leaves "+key+" intact")
		var restored: AppearanceProfileStore=AppearanceProfileStore.new(); restored.bind(state,store.save_fields(state)["presentation"])
		t.eq(restored.data,store.data); t.not_ok(restored.can_upgrade_finish()); t.eq(state.state_hash(),hash)
		var unknown: Dictionary=old.duplicate(true); unknown["catalog"]["city_kit"]=99
		store.bind(state,PresentationEnvelope.pack(unknown))
		t.ok(store.opaque); t.not_ok(store.upgrade_finish()); t.eq(store.save_fields(state)["presentation"],PresentationEnvelope.pack(unknown))

func test_finish_coverage_function_tier_style_and_no_empty_ghosts(t: T) -> void:
	for style: String in CityBuildingKit.STYLES:
		for kind: String in CityTerrainGenerator.DISTRICTS:
			var fingerprints: Array[String]=[]
			for tier: int in 3:
				var site: Dictionary={"kind":kind,"blocked":false,"seed":77}
				var old: Array[Dictionary]=CityBuildingKitV2.build(site,style,tier,"continental")
				var parts: Array[Dictionary]=CityBuildingKitV3.build(site,style,tier,"continental")
				t.ok(parts.size()>old.size()); fingerprints.append(str(parts).sha256_text())
			t.ne(fingerprints[0],fingerprints[1]); t.ne(fingerprints[1],fingerprints[2])
		t.ok(CityBuildingKitV3.build({"kind":"","blocked":false,"seed":77},style,2,"continental").is_empty())
		t.ok(CityBuildingKitV3.build({"kind":"research","blocked":true,"seed":77},style,2,"continental").is_empty())
	var ids: Array[String]=Content.db().ids("buildings")
	t.eq(ids.size(),15)
	var prints: Dictionary={}
	for id: String in ids:
		var parts: Array[Dictionary]=FinishedBuildingKit.build(id,77)
		t.ok(parts.size()>M1BuildingKit.build(id,77).size(),id+" has its own finishing equipment")
		prints[id]=str(parts).sha256_text()
	t.ne(prints["civic_hall"],prints["market_exchange"]); t.ne(prints["archive_of_sol"],prints["civic_hall"])

func test_known_new_catalog_restores_older_writer_additions_after_demolition(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state,"","",true)
	var authority: Dictionary=store.data.duplicate(true)
	var older: AppearanceProfileStore=AppearanceProfileStore.new(); older.bind(state)
	var additions: Dictionary=older.data.duplicate(true)
	var colony: Colony=GameModel.capital(state)
	var free: int=ColonyRules.free_slots(colony,state.planets[colony.planet_id]).back()
	additions["groundworks"]["sites"][colony.id].append(free)
	additions["requires_future_renderer"]=true
	additions["profiles"]["new_world"]=PlanetFieldGenerator.profile("new_world",23,"arid")
	additions["anchors"]["new_region"]=RegionAnchor.choose(additions["profiles"]["new_world"],"new_region")
	store.bind(state,PresentationEnvelope.pack(authority),PresentationEnvelope.pack(additions))
	t.not_ok(store.opaque); t.not_ok(store.fallback); t.eq(store.data["catalog"],AppearanceProfileStore.CURRENT_CATALOG)
	for id: String in authority["profiles"]: t.eq(store.data["profiles"][id],authority["profiles"][id],"old rendering seeds never replace newer identities")
	t.eq(store.data["anchors"][colony.id],authority["anchors"][colony.id])
	t.ok(store.prepared_for(colony.id,30).has(free),"previously demolished site survives even though no building remains in GameState")
	t.eq(store.profile_for("new_world"),additions["profiles"]["new_world"])
	t.eq(store.data["anchors"]["new_region"],additions["anchors"]["new_region"])
	var saved: Dictionary=store.save_fields(state)
	t.eq(saved["presentation_overlay"],"")
	var again: AppearanceProfileStore=AppearanceProfileStore.new(); again.bind(state,saved["presentation"])
	t.eq(again.data,store.data)

func test_v2_transport_has_independently_checked_stage_e_view(t: T) -> void:
	var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
	var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state,"","",true)
	var fields: Dictionary=store.save_fields(state)
	var current: Dictionary=PresentationEnvelope.inspect(fields["presentation"])
	t.eq(current["version"],2); t.eq(current["data"],store.data)
	var wrapper: Dictionary=JSON.parse_string(fields["presentation"])
	var compatible: Dictionary=PresentationEnvelope.inspect(wrapper["compatibility"])
	t.eq(compatible["version"],1); t.eq(compatible["data"]["catalog"],AppearanceProfileStore.STAGE_E_CATALOG)
	for key: String in ["profiles","anchors","groundworks","identity"]: t.eq(compatible["data"][key],store.data[key])
	t.eq(compatible["data"]["architecture"]["kit_version"],2)
	var old: AppearanceProfileStore=AppearanceProfileStore.new(); old.bind(state)
	t.eq(PresentationEnvelope.inspect(old.save_fields(state)["presentation"])["version"],1,"original v1 writers and fixtures stay v1")

func test_hulls_have_three_real_decreasing_geometry_lods(t: T) -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/3d/finish_v1/manifest.json"))
	t.eq(int(manifest["lods"]),3); t.ok(manifest["external_assets"].is_empty())
	for hull: String in ["survey_probe","construction_ship","colony_ship"]:
		var counts: Array[int]=[]
		for lod: int in 3:
			var path: String="assets/3d/finish_v1/"+hull+"_lod"+str(lod)+".glb"
			t.ok(ResourceLoader.exists("res://"+path))
			for item: Dictionary in manifest["generated"]:
				if item["file"]==path: counts.append(int(item["triangles"]))
		t.eq(counts.size(),3); t.ok(counts[0]>counts[1] and counts[1]>counts[2])
	var kit: SpaceObjectKitV2=SpaceObjectKitV2.new(); var ship: Node3D=kit.ship("colony_ship")
	for level: int in 3:
		SpaceObjectKitV2.set_lod(ship,level)
		for i: int in 3: t.eq((ship.get_node("LOD"+str(i)) as Node3D).visible,i==level)
	ship.free()
