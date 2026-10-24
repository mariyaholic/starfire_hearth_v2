extends SceneTree
## Capture the existing appearance algorithm before its scheduling refactor.
func _initialize() -> void:
	var vectors: Array[Dictionary] = []
	for kind: String in SpaceSurfaceBaker.TYPES + ["star"]:
		for seed_value: int in [11,117]:
			var maps: Dictionary = SpaceSurfaceBaker.bake(kind,seed_value,32)
			var hashes: Dictionary = {}
			for channel: String in ["albedo","surface","clouds","normal"]:
				var hash: HashingContext = HashingContext.new()
				hash.start(HashingContext.HASH_SHA256)
				hash.update((maps[channel] as Image).get_data())
				hashes[channel] = hash.finish().hex_encode()
			vectors.append({"kind":kind,"seed":seed_value,"width":32,"sha256":hashes})
	DirAccess.make_dir_recursive_absolute("res://tests/fixtures/visual")
	FileAccess.open("res://tests/fixtures/visual/surface_v1.json",FileAccess.WRITE).store_string(JSON.stringify({"version":SpaceSurfaceBaker.VERSION,"vectors":vectors},"\t")+"\n")
	print("Recorded sixteen existing surface profiles before scheduling changes")
	quit(0)
