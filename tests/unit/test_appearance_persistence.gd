extends RefCounted

func _state() -> GameState:
 return ScenarioLoader.build(Content.db(),"s1_first_light",11)

func _bind(s: GameState, fresh: bool = true) -> AppearanceProfileStore:
 var store: AppearanceProfileStore = AppearanceProfileStore.new()
 store.bind(s,"","",fresh)
 return store

func test_graphics_integrity_is_independent_of_gameplay(t: T) -> void:
 var s: GameState = _state()
 var graphics: String = PresentationEnvelope.pack(_bind(s).data)
 var bare: Dictionary = CanonicalJson.parse(SaveSerializer.to_text(s,"test"))
 var env: Dictionary = CanonicalJson.parse(SaveSerializer.to_text(s,"test",graphics))
 t.eq(env["version"],2); t.eq(env["state"],bare["state"]); t.eq(env["checksum"],bare["checksum"])
 var wrapper: Dictionary = CanonicalJson.parse(graphics)
 wrapper["checksum"] = "tampered"
 env["presentation"] = CanonicalJson.stringify(wrapper)
 var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(CanonicalJson.stringify(env))
 t.ok(lr.ok); t.eq(lr.presentation_status,"invalid"); t.eq(lr.state.state_hash(),s.state_hash())
 var restored: AppearanceProfileStore = AppearanceProfileStore.new()
 restored.bind(lr.state,lr.presentation)
 t.eq(restored.notice,"ui.world.appearance_recovered"); t.not_ok(restored.fallback)
 t.eq(restored.save_fields(s)["presentation"],lr.presentation,"damaged original retained, never rehashed as valid")
 env["presentation"] = {"unrecognized":0.25}
 lr = SaveSerializer.from_text(JSON.stringify(env))
 t.ok(lr.ok,"optional fractional data cannot poison valid gameplay")
 env["state"]["turn"] = 1.25
 t.not_ok(SaveSerializer.from_text(JSON.stringify(env)).ok,"simulation still rejects fractional data")

func test_legacy_and_new_world_identity_and_snapshot_isolation(t: T) -> void:
 var s: GameState = _state()
 s.planets["pl_brume"].art_seed = 0; s.planets["pl_cinder"].art_seed = 0
 var legacy_store: AppearanceProfileStore = _bind(s,false)
 t.eq(legacy_store.profile_for("pl_brume")["seed"],0,"legacy seeded look retained")
 var current: AppearanceProfileStore = _bind(s)
 t.ne(current.profile_for("pl_brume")["seed"],current.profile_for("pl_cinder")["seed"],"same/zero source seed still has distinct new identities")
 var before: String = s.state_hash()
 Game.resume(s,PresentationEnvelope.pack(current.data))
 var copy: Dictionary = VisualSnapshotBuilder.build(Game.view(),"system","sys_ember",Worlds.session.epoch)
 copy["planets"][0]["appearance"]["seed"] = 0
 t.ne(Worlds.appearances.profile_for(copy["planets"][0]["id"])["seed"],0,"renderer copy detached")
 t.eq(s.state_hash(),before,"no game RNG or state mutation")
 var serialized: String = CanonicalJson.stringify(current.data)
 for id: String in s.planets:
  if not s.player().known_systems.has(s.planets[id].system_id): t.not_ok(serialized.contains('"'+id+'"'),"hidden planet excluded")

func test_future_graphics_survive_play_resave_and_reload(t: T) -> void:
 Settings.persist = false
 var s: GameState = _state()
 var future_payload: String = '{"future_float":0.123456789,"unknown_shader":"abc","arrays":[2.5,7.75]}'
 var future: String = JSON.stringify({"format":PresentationEnvelope.FORMAT,"version":77,"payload":future_payload,"checksum":future_payload.sha256_text(),"extra_future_wrapper":[0.25]})
 var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(s,"future",future))
 t.ok(lr.ok); t.eq(lr.presentation_status,"future")
 Game.resume(lr.state,lr.presentation)
 t.ok(Worlds.appearances.fallback)
 var reference: GameState = TurnProcessor.run(s,[] as Array[Command]).state
 Game.end_turn()
 t.eq(Game.state.state_hash(),reference.state_hash(),"unsupported graphics do not alter rules")
 var fields: Dictionary = Worlds.save_fields(Game.state)
 t.eq(fields["presentation"],future,"unknown wrapper and payload byte-for-byte")
 var again: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(Game.state,"test",fields["presentation"],fields["presentation_overlay"]))
 t.eq(again.presentation,future); t.ok(again.ok)
 Game.resume(again.state,again.presentation,again.presentation_overlay)
 t.ok(Worlds.appearances.fallback,"an empty compatibility overlay must not silently reroll future worlds")

func test_future_compatible_view_and_unknown_extensions_are_preserved(t: T) -> void:
 var s: GameState = _state()
 var known: Dictionary = _bind(s).data
 known["unknown_extension"] = {"id":"preserve-me","version":501}
 var compatible: String = PresentationEnvelope.pack(known)
 var future_payload: String = '{"unimplemented":1.5}'
 var future: String = JSON.stringify({"format":PresentationEnvelope.FORMAT,"version":20,"payload":future_payload,"checksum":future_payload.sha256_text(),"compatibility":compatible})
 var store: AppearanceProfileStore = AppearanceProfileStore.new()
 store.bind(s,future)
 t.not_ok(store.fallback); t.eq(store.data,known)
 s.colonies_of(s.player_id)[0].pops += 10
 store.sync_committed(s)
 var fields: Dictionary = store.save_fields(s)
 t.eq(fields["presentation"],future)
 t.eq(PresentationEnvelope.inspect(fields["presentation_overlay"])["data"]["unknown_extension"],known["unknown_extension"])
 var roundtrip: AppearanceProfileStore = AppearanceProfileStore.new()
 roundtrip.bind(s,fields["presentation"],fields["presentation_overlay"])
 t.eq(roundtrip.data,store.data)

func test_graphics_migration_keeps_frozen_geography_and_versions(t: T) -> void:
 var fixture: Dictionary = CanonicalJson.parse(FileAccess.get_file_as_string("res://tests/fixtures/visual/appearance_v1.json"))
 var s: GameState = _state()
 var store: AppearanceProfileStore = AppearanceProfileStore.new()
 store.bind(s,fixture["v0"])
 var migrated: Dictionary = store.data.duplicate(true); migrated.erase("groundworks")
 t.eq(migrated,fixture["data"],"v0 rename migration preserves all profiles/anchors")
 var saved: Dictionary = PresentationEnvelope.inspect(store.save_fields(s)["presentation"])["data"].duplicate(true)
 t.eq(saved["groundworks"]["version"],1,"optional Stage E completed-ground history")
 saved.erase("groundworks")
 t.eq(PresentationEnvelope.pack(saved),fixture["v1"],"canonical v1 physical appearance is unchanged")
 var restored: AppearanceProfileStore = AppearanceProfileStore.new(); restored.bind(s,fixture["v1"])
 t.eq(_bind(s).data["catalog"]["city_kit"],3,"new catalog is explicitly versioned")
 t.eq(_bind(s).data["profiles"],fixture["data"]["profiles"],"new city kit cannot reroll physical world profiles")
 var physical: Dictionary = restored.data.duplicate(true); physical.erase("groundworks")
 t.eq(physical,fixture["data"],"new default changes require a new profile version, never fixture replacement")
 var p: Dictionary = restored.data["profiles"]["pl_aster"]
 p["generator_version"] = 100
 t.ok(restored.profile_for("pl_aster").is_empty(),"unsupported individual generator cannot masquerade as v1")
 var fields: Dictionary = restored.save_fields(s)
 t.eq(PresentationEnvelope.inspect(fields["presentation"])["data"]["profiles"]["pl_aster"]["generator_version"],100,"unknown per-profile version survives")

func test_only_completed_settlements_commit_anchors_and_growth_keeps_them(t: T) -> void:
 Settings.persist = false
 var s: GameState = _state()
 s.player().surveyed_planets.append("pl_brume")
 var ship: Ship = Ships.launch(s,s.colonies_of(s.player_id)[0],"colony_ship")
 Game.resume(s,"","",true)
 var initial: Dictionary = Worlds.appearances.data["anchors"].duplicate(true)
 var cmd: Command = ColoniseCommand.create(s.player_id,ship.id,"pl_brume")
 t.ok(Game.submit(cmd).ok)
 VisualSnapshotBuilder.build(Game.view(),"system","sys_ember",Worlds.session.epoch)
 t.eq(Worlds.appearances.data["anchors"],initial,"order/hover preview creates no saved anchors")
 Game.undo(); t.eq(Worlds.appearances.data["anchors"],initial)
 Game.submit(cmd); Game.end_turn()
 var id: String = Game.state.planets["pl_brume"].colony_id
 t.ne(id,""); t.ok(Worlds.appearances.data["anchors"].has(id),"commit bus runs before autosave")
 var anchor: Dictionary = Worlds.appearances.anchor_for(id,"pl_brume")
 var grown: GameState = GameState.from_dict(Game.state.to_dict())
 grown.colonies[id].pops = 19; grown.colonies[id].districts.append(Colony.PlacedDistrict.new())
 Worlds.appearances.sync_committed(grown)
 t.eq(Worlds.appearances.anchor_for(id,"pl_brume"),anchor,"population and buildings never reseat the region")

func test_manual_auto_checkpoint_and_session_restore_preserve_graphics(t: T) -> void:
 Settings.persist = false
 var old_dir: String = SaveService.dir
 var scratch: String = "user://stage_d_%d" % Time.get_ticks_usec()
 SaveService.dir = scratch
 var s: GameState = _state(); s.turn = 5
 Game.resume(s,"","",true)
 var expected: Dictionary = Worlds.appearances.data.duplicate(true)
 t.ne(SaveService.save_manual(s),"")
 t.eq(SaveService.autosave(s),OK)
 var count: int = 0
 for item: Dictionary in SaveService.list_slots():
  var lr: SaveSerializer.LoadResult = SaveService.load_slot(item["slot"])
  t.ok(lr.ok); t.eq(lr.presentation_status,"supported")
  Game.resume(lr.state,lr.presentation,lr.presentation_overlay)
  t.eq(Worlds.appearances.data,expected)
  count += 1
 t.eq(count,3)
 var pending: FileAccess = FileAccess.open(scratch.path_join("interrupted.json.pending"),FileAccess.WRITE)
 pending.store_string("partial"); pending.close()
 t.eq(SaveService.list_slots().size(),3,"interrupted replacement never offered by Continue")
 for file: String in DirAccess.open(scratch).get_files(): DirAccess.remove_absolute(scratch.path_join(file))
 DirAccess.remove_absolute(scratch); SaveService.dir = old_dir

func test_newer_writer_merges_only_new_identities_from_older_overlay(t: T) -> void:
 var s: GameState = _state()
 var view: Dictionary = _bind(s).data
 var future: Dictionary = view.duplicate(true)
 future["profiles"]["pl_aster"]["generator_version"]=99
 future["anchors"]["col_0001"]["heading_mdeg"]=999
 view["profiles"]["added_world"]=PlanetFieldGenerator.profile("added_world",25,"arid")
 view["anchors"]["added_colony"]=RegionAnchor.choose(view["profiles"]["added_world"],"added_colony")
 var merged: Dictionary = AppearanceProfileStore.merge_additions(future,view)
 t.eq(merged["profiles"]["pl_aster"]["generator_version"],99)
 t.eq(merged["anchors"]["col_0001"]["heading_mdeg"],999)
 t.eq(merged["profiles"]["added_world"],view["profiles"]["added_world"])
 t.eq(merged["anchors"]["added_colony"],view["anchors"]["added_colony"])
 t.not_ok(future["profiles"].has("added_world"),"merge returns detached data")
 view["identity"]["seed"]=123
 t.eq(AppearanceProfileStore.merge_additions(future,view),future,"other sessions cannot contaminate appearance")

func test_unknown_supported_envelope_extensions_survive_resaving(t: T) -> void:
 var s: GameState = _state()
 var wrapper: Dictionary = JSON.parse_string(PresentationEnvelope.pack(_bind(s).data))
 wrapper["future_extension"]={"floating":0.875,"unicode":"世界"}
 var raw: String = JSON.stringify(wrapper)
 var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(s,raw)
 var fields: Dictionary = store.save_fields(s)
 t.eq(JSON.parse_string(fields["presentation"])["future_extension"],wrapper["future_extension"])
 t.eq(PresentationEnvelope.inspect(fields["presentation"])["status"],"supported")

func test_unsupported_generator_never_runs_current_algorithm(t: T) -> void:
 var p: Dictionary = PlanetFieldGenerator.profile("future",11,"continental")
 p["generator_version"]=99
 t.ok(SpaceSurfaceBaker.bake("continental",p["seed"],16,null,p).is_empty(),"future version rejects rendering, never rerolls with current algorithm")
 var service: GenerationScheduler = GenerationScheduler.new()
 (Engine.get_main_loop() as SceneTree).root.add_child(service)
 service.request("future",1,"future","continental",p["seed"],16,0,p)
 t.eq(service.metrics()["pending"],0)
 service.queue_free()
 await Engine.get_main_loop().process_frame

func test_unknown_extensions_stay_on_disk_outside_render_disclosure(t: T) -> void:
 var s: GameState = _state()
 var store: AppearanceProfileStore = _bind(s)
 store.data["profiles"]["pl_aster"]["future_secret_extension"]={"SECRET":"not permitted"}
 store.data["anchors"]["col_0001"]["future_secret_extension"]={"SECRET":"not permitted"}
 Game.resume(s,PresentationEnvelope.pack(store.data))
 var snapshot: Dictionary = VisualSnapshotBuilder.build(Game.view(),"system","sys_ember",Worlds.session.epoch)
 t.not_ok(CanonicalJson.stringify(snapshot).contains("SECRET"))
 t.ok(Worlds.save_fields(s)["presentation"].contains("SECRET"),"opaque extensions preserved only at save boundary")
 store.data["anchors"]["col_0001"]["version"]=99
 Game.resume(s,PresentationEnvelope.pack(store.data))
 snapshot=VisualSnapshotBuilder.build(Game.view(),"system","sys_ember",Worlds.session.epoch)
 t.not_ok(snapshot["appearance_supported"],"unsupported anchor cannot move the marker to an invented location")
 t.eq(PresentationEnvelope.inspect(Worlds.save_fields(s)["presentation"])["data"]["anchors"]["col_0001"]["version"],99)

func test_future_catalog_or_other_game_identity_uses_preserving_fallback(t: T) -> void:
 var s: GameState = _state()
 for reason: String in ["catalog","identity"]:
  var data: Dictionary = _bind(s).data
  if reason == "catalog": data["catalog"]["city_kit"]=99
  else: data["identity"]["seed"]=212
  var raw: String = PresentationEnvelope.pack(data)
  var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(s,raw)
  t.ok(store.fallback,reason+" does not silently apply wrong appearance")
  t.eq(store.save_fields(s)["presentation"],raw,"unsupported original preserved exactly")
  var restored: AppearanceProfileStore = AppearanceProfileStore.new()
  restored.bind(s,raw,store.save_fields(s)["presentation_overlay"])
  t.ok(restored.fallback,"fallback persists through overlay reload")

func test_unknown_future_architecture_is_preserved_without_impersonating_ark(t: T) -> void:
 var s: GameState = _state()
 var store: AppearanceProfileStore = _bind(s)
 store.data["architecture"]["id"]="future_civilization"
 Game.resume(s,PresentationEnvelope.pack(store.data))
 var snapshot: Dictionary = VisualSnapshotBuilder.build(Game.view(),"colony","col_0001",Worlds.session.epoch)
 t.not_ok(snapshot["appearance_supported"])
 t.eq(PresentationEnvelope.inspect(Worlds.save_fields(s)["presentation"])["data"]["architecture"]["id"],"future_civilization")
