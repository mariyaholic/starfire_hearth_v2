class_name GenerationScheduler
extends Node
## One shared CPU generation service. Retirement never waits on an unfinished task.
## Only completed tasks are joined during navigation; shutdown cancels then drains.
signal surface_ready(owner: String, epoch: int, key: String, images: Dictionary)
signal region_ready(owner: String, epoch: int, key: String, result: Dictionary)
var epoch: int = 1
var cooperative: bool = OS.has_feature("web")
# Quality-first temporary allowance: the shared field costs more than the
# original inline baker. Keep bounded work while avoiding minutes of flat preview
# on a non-threaded browser. Stage G will tune from actual-device measurements.
var slice_us: int = 6000 if OS.has_feature("web") else 1000
var region_slice_us: int = 18000 if OS.has_feature("web") else 1000
var max_workers: int = 2
var samples: PackedInt64Array = PackedInt64Array()
var stale_results: int = 0
var cancelled_jobs: int = 0
var _tasks: Dictionary[String, Task] = {}
var _retired: Array[Task] = []
var _sequence: int = 0
var _inactive: Dictionary[String, bool] = {}
var process_calls: int = 0
var last_active: int = -1
var suspended: bool = false
var suspend_reason: String = ""

func set_owner_active(owner: String, active: bool) -> void:
	if active: _inactive.erase(owner)
	else: _inactive[owner] = true

func suspend(reason: String) -> void:
	if suspended: return
	suspended = true
	suspend_reason = reason
	_inactive.clear()
	for task: Task in _tasks.values().duplicate(): _retire(task)
	if _retired.is_empty(): set_process(false)

class Task:
	extends RefCounted
	var key: String
	var epoch: int
	var kind: String
	var seed_value: int
	var width: int
	var priority: int
	var sequence: int
	var owners: Dictionary[String, bool] = {}
	var token: SpaceSurfaceBaker.Cancellation = SpaceSurfaceBaker.Cancellation.new()
	var worker: int = -1
	var job: SpaceSurfaceBaker.BakeJob
	var images: Dictionary = {}
	var appearance: Dictionary = {}
	var region: Dictionary = {}
	var region_job: RegionBakeJob
	func begin_region() -> void:
		var terrain: RegionTerrainGenerator = RegionTerrainGenerator.new(appearance,region["anchor"])
		terrain.prepared_sites.assign(region.get("prepared",[]))
		images = {"generator":terrain,"recipe":terrain.layout(region["sites"],region["blocked"],region["count"])}
		region_job = RegionTilesJob.new(terrain,width,token) if region.get("chunked",false) else RegionBakeJob.new(terrain,width,token)
	func run() -> void:
		if region.is_empty(): images = SpaceSurfaceBaker.bake(kind, seed_value, width, token, appearance)
		else:
			begin_region()
			while not region_job.step(256): pass
			images["maps"] = region_job.maps()
	func step() -> bool:
		if region.is_empty():
			if job == null: job = SpaceSurfaceBaker.BakeJob.new(kind,seed_value,width,token,appearance)
			return job.step(16)
		if region_job == null: begin_region()
		return region_job.step(1)
	func result() -> Dictionary:
		if region.is_empty(): return job.maps()
		images["maps"] = region_job.maps()
		return images if not images["maps"].is_empty() else {}

func request(owner: String, request_epoch: int, key: String, kind: String, seed_value: int, width: int, priority: int = 10, appearance: Dictionary = {}, region: Dictionary = {}) -> void:
	if suspended or request_epoch != epoch or not (kind in SpaceSurfaceBaker.TYPES or kind == "star" or kind == "region" and not region.is_empty()): return
	if width < 16 or width > 2048: return
	if not appearance.is_empty() and (not PlanetFieldGenerator.supported(appearance) or appearance["seed"] != seed_value or kind != "region" and appearance["kind"] != kind): return
	if _tasks.has(key):
		_tasks[key].owners[owner] = true
		_tasks[key].priority = mini(_tasks[key].priority, priority)
		return
	# Keep speculative work bounded; visible/focused requests displace low-priority work.
	if _tasks.size() >= 32:
		var candidates: Array[Task] = []
		candidates.assign(_tasks.values())
		candidates.sort_custom(func(a: Task, b: Task) -> bool: return a.priority < b.priority)
		var worst: Task = candidates.back()
		if worst.priority <= priority: return
		_retire(worst)
	var task: Task = Task.new()
	task.key = key; task.epoch = epoch; task.kind = kind; task.seed_value = seed_value
	task.width = width; task.priority = priority; task.sequence = _sequence
	task.appearance = appearance.duplicate(true)
	task.region = region.duplicate(true)
	_sequence += 1
	task.owners[owner] = true
	_tasks[key] = task

func request_region(owner: String, request_epoch: int, key: String, appearance: Dictionary, anchor: Dictionary, sites: Array, blocked: Array, count: int, resolution: int = 64, chunked: bool = false, prepared: Array = []) -> void:
	if not PlanetFieldGenerator.supported(appearance) or not RegionAnchor.valid(anchor,appearance["id"]): return
	if appearance["kind"] not in CityTerrainGenerator.KINDS or resolution < 16 or resolution > 256 or count < 1 or count > 128: return
	request(owner,request_epoch,key,"region",appearance["seed"],resolution,0,appearance,
		{"anchor":anchor,"sites":sites,"blocked":blocked,"count":count,"chunked":chunked,"prepared":prepared})

func cancel_owner(owner: String) -> void:
	_inactive.erase(owner)
	for task: Task in _tasks.values():
		task.owners.erase(owner)
		if task.owners.is_empty(): _retire(task)

func restart(new_epoch: int) -> void:
	for task: Task in _tasks.values(): _retire(task)
	epoch = new_epoch
	_inactive.clear()

func _retire(task: Task) -> void:
	task.token.cancel()
	_tasks.erase(task.key)
	cancelled_jobs += 1
	if task.worker >= 0: _retired.append(task)

func _ordered() -> Array[Task]:
	var tasks: Array[Task] = []
	for task: Task in _tasks.values():
		for owner: String in task.owners:
			if not _inactive.has(owner):
				tasks.append(task)
				break
	tasks.sort_custom(func(a: Task, b: Task) -> bool:
		return a.priority < b.priority or (a.priority == b.priority and a.sequence < b.sequence))
	return tasks

func _process(_delta: float) -> void:
	process_calls += 1
	for task: Task in _retired.duplicate():
		if WorkerThreadPool.is_task_completed(task.worker):
			WorkerThreadPool.wait_for_task_completion(task.worker)
			_retired.erase(task)
	if suspended:
		if _retired.is_empty(): set_process(false)
		return
	if cooperative:
		var tasks: Array[Task] = _ordered()
		last_active = tasks.size()
		if tasks.is_empty(): return
		var task: Task = tasks[0]
		# At most one cooperative image buffer exists, including after priority changes.
		for other: Task in tasks:
			if other != task:
				other.job = null; other.region_job = null; other.images = {}
		var started: int = Time.get_ticks_usec()
		var finished: bool = task.step()
		while not finished:
			if Time.get_ticks_usec() - started >= (region_slice_us if not task.region.is_empty() else slice_us): break
			finished = task.step()
		samples.append(Time.get_ticks_usec() - started)
		if samples.size() > 1024: samples.remove_at(0)
		if finished: _deliver(task, task.result())
	else:
		var running: int = _retired.size()
		var delivered: bool = false
		for task: Task in _tasks.values():
			if task.worker < 0: continue
			if not delivered and WorkerThreadPool.is_task_completed(task.worker):
				WorkerThreadPool.wait_for_task_completion(task.worker)
				_deliver(task, task.images)
				delivered = true
			else: running += 1
		for task: Task in _ordered():
			if running >= max_workers: break
			if task.worker >= 0: continue
			task.worker = WorkerThreadPool.add_task(task.run)
			running += 1

func _deliver(task: Task, images: Dictionary) -> void:
	_tasks.erase(task.key)
	if task.epoch != epoch or task.token.is_cancelled() or images.is_empty():
		stale_results += 1
		return
	for owner: String in task.owners:
		if task.region.is_empty(): surface_ready.emit(owner,task.epoch,task.key,images)
		else: region_ready.emit(owner,task.epoch,task.key,images)

func metrics() -> Dictionary:
	var progress: Array[Dictionary] = []
	for task: Task in _tasks.values():
		progress.append({"kind":task.kind,"cursor":task.job.cursor if task.job != null else -1,"region_cursor":task.region_job.cursor if task.region_job != null else -1})
	return {"backend": "cooperative" if cooperative else "workers", "pending": _tasks.size(),
		"active_tasks":_ordered().size(),"inactive_owners":_inactive.keys(),"processing":is_processing(),
		"suspended":suspended,"suspend_reason":suspend_reason,
		"process_calls":process_calls,"can_process":can_process(),"tree_paused":get_tree().paused,
		"last_active":last_active,"progress":progress,"sample_count":samples.size(),
		"retiring": _retired.size(), "stale_results": stale_results, "cancelled_jobs": cancelled_jobs,
		"generation_us": Array(samples)}

func _exit_tree() -> void:
	restart(epoch + 1)
	for task: Task in _retired: WorkerThreadPool.wait_for_task_completion(task.worker)
	_retired.clear()
