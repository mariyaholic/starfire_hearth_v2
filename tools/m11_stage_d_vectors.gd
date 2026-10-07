extends SceneTree
func _initialize() -> void:
 var state: GameState = ScenarioLoader.build(Content.db(),"s1_first_light",11)
 var store: AppearanceProfileStore = AppearanceProfileStore.new(); store.bind(state,"","",true)
 var old: Dictionary = store.data.duplicate(true)
 old["worlds"] = old["profiles"]; old["regions"] = old["anchors"]; old.erase("profiles"); old.erase("anchors")
 var out: Dictionary = {"data":store.data,"v0":PresentationEnvelope.pack(old,0),"v1":PresentationEnvelope.pack(store.data)}
 FileAccess.open("res://tests/fixtures/visual/appearance_v1.json",FileAccess.WRITE).store_string(CanonicalJson.stringify(out))
 DirAccess.make_dir_recursive_absolute("res://build/stage_d")
 FileAccess.open("res://build/stage_d/legacy_loader_save.json",FileAccess.WRITE).store_string(SaveSerializer.to_text(state,"m11-stage-d",out["v1"]))
 print("Stage D fixtures: ",store.data["anchors"])
 quit()
