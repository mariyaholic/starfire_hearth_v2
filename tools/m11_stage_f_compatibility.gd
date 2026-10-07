extends SceneTree
## Reproduction helper for the actual saved Stage E source and Stage F writer.
## Run with -- produce|older|verify /absolute/evidence/directory.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var mode: String=args[0]; var folder: String=args[1]
	var t: T=T.new()
	if mode=="produce":
		DirAccess.make_dir_recursive_absolute(folder)
		var state: GameState=ScenarioLoader.build(Content.db(),"s1_first_light",11)
		var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(state,"","",true)
		state.colonies_of(state.player_id)[0].districts.remove_at(0)
		var current: Dictionary=store.data.duplicate(true)
		for version: int in [1,2,3]:
			current["catalog"]=[AppearanceProfileStore.CATALOG,AppearanceProfileStore.STAGE_E_CATALOG,AppearanceProfileStore.CURRENT_CATALOG][version-1].duplicate(); current["architecture"]["kit_version"]=version; store.data=current.duplicate(true)
			FileAccess.open(folder.path_join("kit_"+str(version)+".json"),FileAccess.WRITE).store_string(SaveSerializer.to_text(state,"Stage F compatibility fixture",store.save_fields(state)["presentation"]))
	elif mode=="older":
		for version: int in [1,2,3]:
			var raw: String=FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+".json"))
			var loaded: SaveSerializer.LoadResult=SaveSerializer.from_text(raw)
			t.ok(loaded.ok)
			var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(loaded.state,loaded.presentation)
			t.not_ok(store.fallback,"Stage E understands the v1 compatibility view for catalog 3")
			if version==3:
				# Named old-writer fixture: complete then demolish a new parcel.
				# Its clearing exists only in presentation history, not final GameState.
				var colony: Colony=loaded.state.colonies_of(loaded.state.player_id)[0]
				var slot: int=ColonyRules.free_slots(colony,loaded.state.planets[colony.planet_id]).back()
				var district: Colony.PlacedDistrict=Colony.PlacedDistrict.new(); district.slot=slot; district.district_id="agriculture"
				colony.districts.append(district); store.sync_committed(loaded.state); colony.districts.pop_back()
				FileAccess.open(folder.path_join("old_writer_clearing.json"),FileAccess.WRITE).store_string(JSON.stringify({"colony":colony.id,"slot":slot}))
			var fields: Dictionary=store.save_fields(loaded.state)
			t.eq(fields["presentation"],loaded.presentation,"Stage E preserves understood extensions or opaque unsupported kit exactly")
			FileAccess.open(folder.path_join("kit_"+str(version)+"_resaved_by_e.json"),FileAccess.WRITE).store_string(SaveSerializer.to_text(loaded.state,"actual Stage E resave",fields["presentation"],fields["presentation_overlay"]))
	elif mode=="verify":
		for version: int in [1,2,3]:
			var before: SaveSerializer.LoadResult=SaveSerializer.from_text(FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+".json")))
			var after: SaveSerializer.LoadResult=SaveSerializer.from_text(FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+"_resaved_by_e.json")))
			t.ok(before.ok and after.ok); t.eq(after.state.state_hash(),before.state.state_hash())
			var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(after.state,after.presentation,after.presentation_overlay)
			t.not_ok(store.fallback,"Stage F understands both retained catalogs")
			var expected: Dictionary=PresentationEnvelope.inspect(before.presentation)["data"]
			if version==3:
				var clearing: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("old_writer_clearing.json")))
				expected["groundworks"]["sites"][clearing["colony"]].append(int(clearing["slot"]))
				expected["groundworks"]["sites"][clearing["colony"]].sort()
			t.eq(store.data,expected,"identities and newly demolished clearing survive actual older writer")
			t.eq(store.data["catalog"]["city_kit"],version)
			t.eq(store.architecture_for("ark"),"ark")
	else: t.fail("unknown compatibility mode")
	var result: Dictionary={"mode":mode,"checks":t.checks,"failures":t.failures,"qualification":"Stage E writer runs from checksum-verified archived review source; Stage F producer/restorer use current M1 checkout. No branch or worktree created."}
	FileAccess.open(folder.path_join(mode+"_verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result)); quit(0 if t.failures.is_empty() else 1)
