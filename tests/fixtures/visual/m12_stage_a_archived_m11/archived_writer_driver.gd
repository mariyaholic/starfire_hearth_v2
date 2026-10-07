extends SceneTree
## Runs against the archived M1.1 Stage F source patch, never the M1.2 tree.
## The output saves are consumed by the current Stage A compatibility test.

const BASELINE: String = "a160d9d334c59a2796b8c88e8eaca7f49b42c029"

func _initialize() -> void:
	_run.call_deferred()


func _pack_component(kind: String, data: Dictionary) -> String:
	var payload: String = CanonicalJson.stringify(data)
	return CanonicalJson.stringify({"checksum":CanonicalJson.sha256_hex(payload),"component":kind,
		"format":"starfire-hearth-presentation-component","payload":payload,"version":1})


func _with_components(raw: String, components: Dictionary) -> String:
	var wrapper: Dictionary = JSON.parse_string(raw)
	wrapper["components"] = components
	# This unknown wrapper extension deliberately contains a fractional value.
	wrapper["m11_opaque_extension"] = {"fraction":0.125,"tag":"archived-stage-f"}
	return JSON.stringify(wrapper)


func _save(path: String, state: GameState, fields: Dictionary, label: String) -> void:
	var text: String = SaveSerializer.to_text(state, label, fields["presentation"], fields["presentation_overlay"])
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty(): quit(2); return
	var folder: String = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var state: GameState = ScenarioLoader.build(Content.db(), "s1_first_light", 11)
	var store: AppearanceProfileStore = AppearanceProfileStore.new()
	store.bind(state, "", "", true)
	var road: Dictionary = {"colonies":{"col_0001":{"edges":[[0,1]],"entrances":["slot:0"],"unreachable":[]}},"identity":AppearanceProfileStore.identity(state),"recipe_version":1}
	var orbit: Dictionary = {"bodies":{"pl_aster":{"epoch_turn":1,"phase_mdeg":0,"period_turns":12,"semi_major_mau":1000}},"identity":AppearanceProfileStore.identity(state),"recipe_version":1,"system_id":"sys_ember"}
	var initial_raw: String = _with_components(PresentationEnvelope.pack(store.data), {"road":_pack_component("road",road),"orbit":_pack_component("orbit",orbit)})
	store.bind(state, initial_raw)
	var before_turn_hash: String = state.state_hash()

	# The old writer resolves a turn and records a completed build followed by
	# demolition. Groundworks intentionally retain the demolished site.
	state = TurnProcessor.run(state, [] as Array[Command]).state
	store.sync_committed(state)
	var colony: Colony = state.colonies_of(state.player_id)[0]
	var slot: int = ColonyRules.free_slots(colony, state.planets[colony.planet_id]).back()
	var district: Colony.PlacedDistrict = Colony.PlacedDistrict.new()
	district.slot = slot; district.district_id = "agriculture"
	colony.districts.append(district); store.sync_committed(state); colony.districts.pop_back(); store.sync_committed(state)
	var added: Dictionary = PlanetFieldGenerator.profile("pl_old_writer_addition", 777, "arid")
	store.data["profiles"]["pl_old_writer_addition"] = added
	store.data["anchors"]["col_old_writer_addition"] = RegionAnchor.choose(added, "col_old_writer_addition")
	var fields: Dictionary = store.save_fields(state)
	_save(folder.path_join("archived_supported.json"), state, fields, "archived M1.1 writer supported")
	FileAccess.open(folder.path_join("archived_manifest.json"), FileAccess.WRITE).store_string(JSON.stringify({"baseline":BASELINE,"before_turn_hash":before_turn_hash,"after_hash":state.state_hash(),"demolished_colony":colony.id,"demolished_slot":slot,"added_profile":"pl_old_writer_addition","added_anchor":"col_old_writer_addition","presentation":fields["presentation"]},"\t"))

	# Exercise the actual archived opaque path. Its writer returns the original
	# future wrapper byte-for-byte and puts only fallback data in the overlay.
	var future_payload: String = "{\"future_float\":0.375,\"future_shader\":\"retain-exactly\"}"
	var compatible: String = PresentationEnvelope.pack(store.data)
	var future_wrapper: Dictionary = {"format":PresentationEnvelope.FORMAT,"version":77,"payload":future_payload,"checksum":CanonicalJson.sha256_hex(future_payload),"compatibility":compatible,"future_extension":[0.25,"opaque"]}
	var future_raw: String = JSON.stringify(future_wrapper)
	var future_store: AppearanceProfileStore = AppearanceProfileStore.new(); future_store.bind(state, future_raw)
	var future_fields: Dictionary = future_store.save_fields(state)
	_save(folder.path_join("archived_future.json"), state, future_fields, "archived M1.1 writer opaque")
	FileAccess.open(folder.path_join("archived_future_raw.txt"), FileAccess.WRITE).store_string(future_raw)
	print(JSON.stringify({"baseline":BASELINE,"supported_hash":state.state_hash(),"supported_presentation":fields["presentation"],"future_exact":future_fields["presentation"]}))
	quit(0)
