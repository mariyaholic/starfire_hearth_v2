extends RefCounted

func test_incremental_surface_matches_the_recorded_pre_refactor_pixels(t: T) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/visual/surface_v1.json"))
	for vector: Dictionary in fixture["vectors"]:
		var job: SpaceSurfaceBaker.BakeJob = SpaceSurfaceBaker.BakeJob.new(vector["kind"],vector["seed"],vector["width"])
		while not job.step(29): pass
		var maps: Dictionary = job.maps()
		for channel: String in ["albedo","surface","clouds","normal"]:
			t.eq(_hash(maps[channel]),vector["sha256"][channel],"pre-refactor %s/%d/%s" % [vector["kind"],vector["seed"],channel])

func test_job_yields_after_its_requested_batch_and_does_not_publish_partial_maps(t: T) -> void:
	var job: SpaceSurfaceBaker.BakeJob = SpaceSurfaceBaker.BakeJob.new("continental",11,64)
	t.not_ok(job.step(8))
	t.eq(job.cursor,8)
	t.ok(job.maps().is_empty(),"partial images cannot be uploaded")
	while not job.step(31): pass
	t.eq(job.cursor,64*32*2)
	t.ok(job.done)
	t.eq(job.maps()["width"],64)

func test_cancelled_surface_stops_without_publishing_a_result(t: T) -> void:
	var token: SpaceSurfaceBaker.Cancellation = SpaceSurfaceBaker.Cancellation.new()
	var job: SpaceSurfaceBaker.BakeJob = SpaceSurfaceBaker.BakeJob.new("barren",117,64,token)
	job.step(16)
	token.cancel()
	t.ok(job.step(4096))
	t.ok(job.cancelled)
	t.not_ok(job.done)
	t.eq(job.cursor,16)
	t.ok(job.maps().is_empty())

func test_synchronous_worker_and_cooperative_batches_produce_identical_maps(t: T) -> void:
	var expected: Dictionary = SpaceSurfaceBaker.bake("ice",29,64)
	var job: SpaceSurfaceBaker.BakeJob = SpaceSurfaceBaker.BakeJob.new("ice",29,64)
	while not job.step(3): pass
	for channel: String in ["albedo","surface","clouds","normal"]:
		t.eq((job.maps()[channel] as Image).get_data(),(expected[channel] as Image).get_data(),channel)

func _hash(image: Image) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()
