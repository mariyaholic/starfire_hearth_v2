extends RefCounted

func _state() -> GameState:
	return ScenarioLoader.build(Content.db(), "s1_first_light", 11)


func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/m12_stage_a_components_v1.json"))


func test_frozen_m11_writer_keeps_new_components_out_of_catalog_and_rules(t: T) -> void:
	var state: GameState = _state()
	var before_hash: String = state.state_hash()
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/appearance_v1.json"))
	var fixture: Dictionary = _fixture()
	var raw: String = PresentationEnvelope.with_components(str(appearance["v1"]), fixture["components"])
	var checked: Dictionary = PresentationEnvelope.inspect(raw)
	t.eq(checked["status"], "supported")
	t.eq(PresentationEnvelope.inspect_component(fixture["components"]["road"], "road")["status"], "supported")
	t.eq(PresentationEnvelope.inspect_component(fixture["components"]["orbit"], "orbit")["status"], "supported")
	t.not_ok(checked["data"].has("road"), "road is not an appearance catalog key")
	t.not_ok(checked["data"].has("orbit"), "orbit is not an appearance catalog key")

	var store: AppearanceProfileStore = AppearanceProfileStore.new()
	store.bind(state, raw)
	t.ok(store.component_supported("road")); t.ok(store.component_supported("orbit"))
	t.eq(store.component_view("road")["recipe_version"], 1)
	t.eq(store.component_view("orbit")["system_id"], "sys_ember")
	t.eq(store.road_recipe_for("col_0001")["version"], 1)
	t.eq(store.road_recipe_for("hidden_colony"), {}, "road access is scoped to the requested colony")
	t.eq(store.orbital_recipe_for("sys_ember", ["pl_aster"])["bodies"].size(), 1)
	t.eq(store.orbital_recipe_for("undisclosed"), {}, "orbit access is scoped to the requested system")
	t.eq(store.data["catalog"], AppearanceProfileStore.CATALOG)

	var saved: Dictionary = store.save_fields(state)
	t.eq(state.state_hash(), before_hash, "component save does not enter the gameplay checksum")
	t.eq(PresentationEnvelope.component_raws(saved["presentation"]), fixture["components"], "known M1.1 writer data carries opaque components")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(state, "M1.2 Stage A", saved["presentation"]))
	t.ok(loaded.ok); t.eq(loaded.state.state_hash(), before_hash)


func test_archived_writer_fixture_roundtrip_has_no_gameplay_schema_change(t: T) -> void:
	var state: GameState = _state()
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/appearance_v1.json"))
	var fixture: Dictionary = _fixture()
	var raw: String = PresentationEnvelope.with_components(str(appearance["v1"]), fixture["components"])
	var known: Dictionary = PresentationEnvelope.inspect(raw)["data"]
	# This is the pinned M1.1 writer operation: reserialize only the known
	# appearance payload and retain unknown wrapper extensions verbatim.
	var archived_resave: String = PresentationEnvelope.repack(known, raw, 1)
	t.eq(PresentationEnvelope.component_raws(archived_resave), fixture["components"], "archived writer preserves wrapper components")
	var restored: AppearanceProfileStore = AppearanceProfileStore.new()
	restored.bind(state, archived_resave)
	t.eq(restored.component_view("road"), PresentationEnvelope.inspect_component(fixture["components"]["road"], "road")["data"])
	t.eq(restored.component_view("orbit"), PresentationEnvelope.inspect_component(fixture["components"]["orbit"], "orbit")["data"])
	# The original executable's documented boundary remains explicit: a writer
	# that emits a fresh v1 payload without the extension has no component data.
	var dropped: String = PresentationEnvelope.pack(known, 1)
	t.eq(PresentationEnvelope.component_raws(dropped), {})


func test_future_component_is_opaque_and_identity_mismatch_is_not_disclosed(t: T) -> void:
	var state: GameState = _state()
	var fixture: Dictionary = _fixture()
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/appearance_v1.json"))
	var future_payload: String = "{\"future_float\":0.25,\"identity\":{\"scenario\":\"s1_first_light\",\"seed\":11,\"viewer\":\"emp_player\"}}"
	var future: String = JSON.stringify({"checksum":future_payload.sha256_text(),"component":"road","format":PresentationEnvelope.COMPONENT_FORMAT,"payload":future_payload,"version":77})
	var outer: String = PresentationEnvelope.with_components(str(appearance["v1"]), {"road":future,"orbit":fixture["components"]["orbit"]})
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(state, outer)
	t.eq(store.component_status("road"), "future")
	t.eq(store.component_view("road"), {})
	t.eq(store.component_raw("road"), future)
	var saved: Dictionary = store.save_fields(state)
	t.eq(PresentationEnvelope.component_raws(saved["presentation"])["road"], future, "unsupported component survives resave")

	var compatible_future: String = PresentationEnvelope.pack_component("road", {"identity":{"scenario":"s1_first_light","seed":11,"viewer":"emp_player"},"future_version":1}, 77, fixture["components"]["road"])
	store.bind(state, PresentationEnvelope.with_components(str(appearance["v1"]), {"road":compatible_future}))
	t.eq(store.component_status("road"), "compatible")
	t.eq(store.component_view("road"), PresentationEnvelope.inspect_component(fixture["components"]["road"], "road")["data"])
	t.eq(store.component_raw("road"), compatible_future)

	var wrong: Dictionary = {"identity":{"scenario":"s1_first_light","seed":999,"viewer":"emp_player"},"recipe_version":1,"colonies":{}}
	var wrong_raw: String = PresentationEnvelope.pack_component("road", wrong)
	store.bind(state, PresentationEnvelope.with_components(str(appearance["v1"]), {"road":wrong_raw}))
	t.eq(store.component_status("road"), "incompatible")
	t.not_ok(store.component_supported("road")); t.eq(store.component_view("road"), {})
	t.eq(store.component_raw("road"), wrong_raw)


func test_component_overlay_additions_are_written_back_without_replacing_authority(t: T) -> void:
	var state: GameState = _state()
	var base: AppearanceProfileStore = AppearanceProfileStore.new(); base.bind(state, "", "", true)
	var identity: Dictionary = AppearanceProfileStore.identity(state)
	var authority: Dictionary = {"colonies":{"col_0001":{"edges":[[0,1]],"entrances":["slot:0"],"unreachable":[]}},"identity":identity,"recipe_version":1}
	var additions: Dictionary = {"colonies":{"col_added":{"edges":[[4,5]],"entrances":["slot:4"],"unreachable":[]}},"identity":identity,"recipe_version":1}
	var appearance_raw: String = PresentationEnvelope.pack(base.data)
	var original: String = PresentationEnvelope.with_components(appearance_raw, {"road":PresentationEnvelope.pack_component("road", authority)})
	var overlay: String = PresentationEnvelope.with_components(appearance_raw, {"road":PresentationEnvelope.pack_component("road", additions)})
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(state, original, overlay)
	t.ok(store.component_view("road")["colonies"].has("col_added"))
	var saved: Dictionary = store.save_fields(state)
	var restored: AppearanceProfileStore = AppearanceProfileStore.new(); restored.bind(state, saved["presentation"])
	t.ok(restored.component_view("road")["colonies"].has("col_0001"))
	t.ok(restored.component_view("road")["colonies"].has("col_added"), "merged overlay addition survives the next save")
	t.eq(restored.component_view("road")["colonies"]["col_0001"], authority["colonies"]["col_0001"], "authoritative collision wins")


func test_set_component_requires_session_identity_and_cannot_replace_future_authority(t: T) -> void:
	var state: GameState = _state()
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(state, "", "", true)
	var value: Dictionary = {"identity":AppearanceProfileStore.identity(state),"recipe_version":1,"colonies":{}}
	t.ok(store.set_component("road", value))
	var wrong: Dictionary = value.duplicate(true); wrong["identity"]["seed"] = 999
	t.not_ok(store.set_component("road", wrong), "component cannot cross campaign identity")
	var future: String = PresentationEnvelope.pack_component("road", value, 77)
	var raw: String = PresentationEnvelope.with_components(PresentationEnvelope.pack(store.data), {"road":future})
	store.bind(state, raw)
	t.not_ok(store.set_component("road", value), "future component authority requires explicit migration")
	t.eq(store.component_raw("road"), future)


func test_set_component_preserves_unknown_component_wrapper_extensions(t: T) -> void:
	var state: GameState = _state()
	var identity: Dictionary = AppearanceProfileStore.identity(state)
	var original_value: Dictionary = {"identity":identity,"recipe_version":1,"colonies":{}}
	var component: Dictionary = JSON.parse_string(PresentationEnvelope.pack_component("road", original_value))
	component["future_component_extension"] = {"fraction":0.125,"opaque":[0.5,"keep"]}
	var appearance: AppearanceProfileStore = AppearanceProfileStore.new()
	var outer: String = PresentationEnvelope.with_components(PresentationEnvelope.pack(appearance.data), {})
	# Bind requires a valid appearance identity; use the store's fresh data after
	# construction rather than manufacturing a second session wrapper.
	appearance.bind(state, "", "", true)
	outer = PresentationEnvelope.with_components(PresentationEnvelope.pack(appearance.data), {"road":JSON.stringify(component)})
	appearance.bind(state, outer)
	var changed: Dictionary = original_value.duplicate(true)
	changed["colonies"] = {"col_0001":{"edges":[],"entrances":[],"unreachable":[]}}
	t.ok(appearance.set_component("road", changed))
	var saved_component: Dictionary = JSON.parse_string(appearance.component_raw("road"))
	t.eq(saved_component["future_component_extension"], component["future_component_extension"], "known edits retain opaque component wrapper fields")
	t.eq(PresentationEnvelope.inspect_component(appearance.component_raw("road"), "road")["data"], changed)


func test_missing_roads_allow_explicit_recipe_upgrade(t: T) -> void:
	var state: GameState = _state()
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(state, "", "", true)
	t.ok(store.can_upgrade_roads(), "missing roads can be upgraded explicitly")
	var recipe: Dictionary = {"identity":AppearanceProfileStore.identity(state),"version":2,"colonies":{}}
	t.ok(store.upgrade_roads(recipe)); t.eq(store.road_recipe_for()["version"], 2)


func test_actual_archived_m11_writer_roundtrip_after_turn_build_demolish_and_addition(t: T) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/m12_stage_a_archived_m11/archived_manifest.json"))
	var saved_text: String = FileAccess.get_file_as_string("res://tests/fixtures/visual/m12_stage_a_archived_m11/archived_supported.json")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(saved_text)
	t.ok(loaded.ok, "archived M1.1 writer save loads")
	t.eq(loaded.state.state_hash(), manifest["after_hash"], "end-turn state from archived writer is unchanged")
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(loaded.state, loaded.presentation, loaded.presentation_overlay)
	t.not_ok(store.fallback)
	t.eq(store.component_status("road"), "supported"); t.eq(store.component_status("orbit"), "supported")
	t.ok(store.component_view("road")["colonies"].has("col_0001"), "road component survives actual older writer")
	t.eq(store.component_view("orbit")["bodies"]["pl_aster"]["period_turns"], 12)
	t.ok(store.data["profiles"].has(manifest["added_profile"]), "new body profile addition survives")
	t.ok(store.data["anchors"].has(manifest["added_anchor"]), "new body anchor addition survives")
	t.ok(store.prepared_for(manifest["demolished_colony"], 128).has(int(manifest["demolished_slot"])), "demolished clearing survives")
	var wrapper: Dictionary = JSON.parse_string(loaded.presentation)
	t.eq(wrapper["m11_opaque_extension"]["fraction"], 0.125, "unknown wrapper extension survives")
	t.eq(PresentationEnvelope.component_raws(loaded.presentation), PresentationEnvelope.component_raws(str(manifest["presentation"])), "component wrappers match the frozen older-writer output")


func test_actual_archived_m11_future_wrapper_is_byte_exact_on_current_resave(t: T) -> void:
	var saved_text: String = FileAccess.get_file_as_string("res://tests/fixtures/visual/m12_stage_a_archived_m11/archived_future.json")
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_text(saved_text)
	var original: String = FileAccess.get_file_as_string("res://tests/fixtures/visual/m12_stage_a_archived_m11/archived_future_raw.txt")
	t.ok(loaded.ok); t.eq(loaded.presentation, original, "archived writer future wrapper is fixture-exact")
	var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(loaded.state, loaded.presentation, loaded.presentation_overlay)
	var fields: Dictionary = store.save_fields(loaded.state)
	t.eq(fields["presentation"], original, "current resave retains opaque wrapper bytes")
	var wrapper: Dictionary = JSON.parse_string(fields["presentation"])
	t.eq(wrapper["future_extension"], [0.25, "opaque"])
