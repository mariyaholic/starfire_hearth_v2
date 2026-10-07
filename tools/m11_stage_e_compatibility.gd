extends SceneTree
## Reproduction helper for the actual saved Stage D source and Stage E writer.
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
		for version: int in [1,2]:
			current["catalog"]["city_kit"]=version; current["architecture"]["kit_version"]=version
			FileAccess.open(folder.path_join("kit_"+str(version)+".json"),FileAccess.WRITE).store_string(SaveSerializer.to_text(state,"Stage E compatibility fixture",PresentationEnvelope.pack(current)))
	elif mode=="older":
		for version: int in [1,2]:
			var raw: String=FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+".json"))
			var loaded: SaveSerializer.LoadResult=SaveSerializer.from_text(raw)
			t.ok(loaded.ok)
			var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(loaded.state,loaded.presentation)
			t.eq(store.fallback,version==2,"Stage D dispatches only its implemented catalog")
			var fields: Dictionary=store.save_fields(loaded.state)
			t.eq(fields["presentation"],loaded.presentation,"Stage D preserves understood extensions or opaque unsupported kit exactly")
			FileAccess.open(folder.path_join("kit_"+str(version)+"_resaved_by_d.json"),FileAccess.WRITE).store_string(SaveSerializer.to_text(loaded.state,"actual Stage D resave",fields["presentation"],fields["presentation_overlay"]))
	elif mode=="verify":
		for version: int in [1,2]:
			var before: SaveSerializer.LoadResult=SaveSerializer.from_text(FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+".json")))
			var after: SaveSerializer.LoadResult=SaveSerializer.from_text(FileAccess.get_file_as_string(folder.path_join("kit_"+str(version)+"_resaved_by_d.json")))
			t.ok(before.ok and after.ok); t.eq(after.state.state_hash(),before.state.state_hash())
			var store: AppearanceProfileStore=AppearanceProfileStore.new(); store.bind(after.state,after.presentation,after.presentation_overlay)
			t.not_ok(store.fallback,"Stage E understands both retained catalogs")
			t.eq(store.data,PresentationEnvelope.inspect(before.presentation)["data"],"profiles, anchors and clearing history survive actual older writer")
			t.eq(store.data["catalog"]["city_kit"],version)
			t.eq(store.architecture_for("ark"),"ark")
	else: t.fail("unknown compatibility mode")
	var result: Dictionary={"mode":mode,"checks":t.checks,"failures":t.failures,"qualification":"Stage D writer runs from its separately archived and checksum-verified source patch; no branch or worktree created."}
	FileAccess.open(folder.path_join(mode+"_verification.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result)); quit(0 if t.failures.is_empty() else 1)
