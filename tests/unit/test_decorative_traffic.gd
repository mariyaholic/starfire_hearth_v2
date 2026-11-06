extends RefCounted

func _network(routes: Array[Array]) -> Dictionary:
	var access: Array = []
	var connected: Array = []
	for route: Array in routes:
		for point: Vector2 in [route[0], route[-1]]:
			connected.append("entrance:" + str(connected.size()))
			access.append([point])
	return {"routes":routes, "access_paths":access, "connected":connected}

func test_fleet_uses_real_destinations_scales_with_development_and_caps(t: T) -> void:
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure({})
	t.eq(traffic.vehicles.size(), 0, "no development means no traffic")
	traffic.configure({"routes":[], "connected":["only"], "access_paths":[[Vector2.ZERO]]})
	t.eq(traffic.vehicles.size(), 0, "one site cannot invent a destination")
	for count: int in range(1, 7):
		var routes: Array[Array] = []
		for i: int in count: routes.append([Vector2(i * 4, 0), Vector2(i * 4, 8)])
		var network: Dictionary = _network(routes)
		var before: Dictionary = network.duplicate(true)
		traffic.configure(network)
		t.eq(traffic.vehicles.size(), mini(count, DecorativeTraffic.CAP))
		for vehicle: Dictionary in traffic.vehicles:
			t.ok(network["connected"].has(vehicle["origin"]))
			t.ok(network["connected"].has(vehicle["destination"]))
			t.ne(vehicle["origin"], vehicle["destination"])
		t.eq(network, before, "traffic never mutates the saved/drawn road recipe")

func test_shared_junction_round_trips_have_no_teleports_reverse_motion_or_overlap(t: T) -> void:
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure(_network([[Vector2(-5, 0), Vector2.ZERO, Vector2(5, 0)],
		[Vector2(0, -5), Vector2.ZERO, Vector2(0, 5)]]))
	t.eq(traffic.vehicles.size(), 2, "two terminal pairs can use the crossing")
	var minimum_gap: float = INF
	var max_step: float = 0.0
	var max_turn: float = 0.0
	var minimum_alignment: float = 1.0
	var road_error: float = 0.0
	var active_conflicts: int = 0
	for tick: int in 12000:
		var previous: Array[Dictionary] = traffic.vehicles.duplicate(true)
		traffic.advance(0.025)
		for i: int in traffic.vehicles.size():
			var vehicle: Dictionary = traffic.vehicles[i]
			var at: Vector2 = vehicle["at"]
			var movement: Vector2 = at - (previous[i]["at"] as Vector2)
			max_step = maxf(max_step, movement.length())
			max_turn = maxf(max_turn, absf(angle_difference(previous[i]["heading"], vehicle["heading"])))
			road_error = maxf(road_error, minf(absf(at.x), absf(at.y)))
			if movement.length() > 0.00001:
				var forward: Vector2 = Vector2(sin(vehicle["heading"]), cos(vehicle["heading"]))
				minimum_alignment = minf(minimum_alignment, forward.dot(movement.normalized()))
			for j: int in i:
				minimum_gap = minf(minimum_gap, at.distance_to(traffic.vehicles[j]["at"]))
				if vehicle["active"] and traffic.vehicles[j]["active"] and traffic.conflicts[i][j]: active_conflicts += 1
	t.ok(max_step < 0.04, "distance-based continuous motion, including trip endpoints")
	t.ok(max_turn < 0.2, "heading changes continuously, including the return turn")
	t.ok(minimum_alignment > 0.999, "cart nose always points along actual travel")
	t.ok(minimum_gap >= DecorativeTraffic.GAP, "parked and moving vehicles keep a physical gap")
	t.near(road_error, 0.0, 0.00001, "cart stays on the drawn centerline")
	t.eq(active_conflicts, 0, "shared single-lane trips hold exclusive reservations")
	for vehicle: Dictionary in traffic.vehicles:
		t.ok(vehicle["trips"] >= 4, "round-robin dispatch does not starve either cart")

func test_bends_stop_and_turn_on_road_and_terrain_pose_follows_all_wheels(t: T) -> void:
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure(_network([[Vector2(0, 0), Vector2(0, 4), Vector2(4, 4)]]))
	t.eq(traffic.vehicles.size(), 1)
	var turning: bool = false
	var hill: Callable = func(x: float, z: float) -> float: return 0.2 * x + 0.3 * z
	for tick: int in 1000:
		var before: Vector2 = traffic.vehicles[0]["at"]
		var was_turning: bool = traffic.vehicles[0]["state"] == "turn"
		traffic.advance(0.05)
		var vehicle: Dictionary = traffic.vehicles[0]
		if was_turning and vehicle["state"] == "turn":
			turning = true
			t.near(before.distance_to(vehicle["at"]), 0.0, 0.0001, "turn in place after stopping")
		var pose: Transform3D = DecorativeTraffic.pose(vehicle, hill)
		var expected_up: Vector3 = Vector3(-0.2, 1, -0.3).normalized()
		t.ok(pose.basis.y.dot(expected_up) > 0.9999, "pitch and roll follow the supporting terrain")
	t.ok(turning)
	traffic.configure({})
	t.eq(traffic.vehicles.size(), 0, "demolition clears the previous fleet and reservations")
	traffic.advance(10.0)
	t.eq(traffic.vehicles.size(), 0)

func test_waiting_trip_is_not_starved_by_independent_conflicts(t: T) -> void:
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure(_network([[Vector2(-3, -5), Vector2(-3, 5)],
		[Vector2(-8, 0), Vector2(8, 0)], [Vector2(3, -3), Vector2(3, 3)]]))
	t.eq(traffic.vehicles.size(), 3)
	var simultaneous: bool = false
	var collision: bool = false
	for tick: int in 12000:
		traffic.advance(0.05)
		for i: int in traffic.vehicles.size():
			for j: int in i:
				var a: Dictionary = traffic.vehicles[i]
				var b: Dictionary = traffic.vehicles[j]
				if a["active"] and b["active"] and not traffic.conflicts[i][j]: simultaneous = true
				if (a["at"] as Vector2).distance_to(b["at"]) < DecorativeTraffic.GAP: collision = true
	t.ok(simultaneous, "independent trips still share the network")
	t.not_ok(collision, "priority preserves physical separation")
	for vehicle: Dictionary in traffic.vehicles:
		t.ok(vehicle["trips"] >= 4, "each waiting trip eventually receives a reservation")

func test_resampled_entrances_join_only_near_drawn_segments(t: T) -> void:
	var entries: Array[Dictionary] = [{"id":"a", "point":Vector2.ZERO},
		{"id":"b", "point":Vector2(-3.751, 0)}, {"id":"c", "point":Vector2(3.767, 0)}]
	var network: Dictionary = CityAccessNetwork.plan(entries, [])
	var original: Dictionary = network.duplicate(true)
	var traffic: DecorativeTraffic = DecorativeTraffic.new(); traffic.configure(network)
	t.eq(network["connected"].size(), 3)
	t.ok(not traffic.vehicles.is_empty(), "resampling and a discarded tiny apron do not disconnect all entrances")
	t.eq(network, original, "graph splitting never changes the road recipe")
	for vehicle: Dictionary in traffic.vehicles:
		for point: Vector2 in vehicle["route"]:
			t.near(point.y, 0.0, 0.00001, "routes stay on the actual road")
	var near: Dictionary = {"routes":[[Vector2.ZERO, Vector2(10,0)]],
		"connected":["left","near","right","far"], "access_paths":[[Vector2.ZERO], [Vector2(5,0.002)], [Vector2(10,0)], [Vector2(4,0.02)]]}
	traffic.configure(near)
	t.ok(not traffic.vehicles.is_empty())
	var uses_near: bool = false
	for vehicle: Dictionary in traffic.vehicles:
		uses_near = uses_near or vehicle["origin"] == "near" or vehicle["destination"] == "near"
		t.not_ok("far" in [vehicle["origin"], vehicle["destination"]], "off-road entrances beyond tolerance are rejected")
	t.ok(uses_near, "planner-sized missing stubs snap to the drawn segment")

func test_matching_rebuild_preserves_trip_but_removed_frontage_replaces_trip(t: T) -> void:
	var network: Dictionary = _network([[Vector2.ZERO, Vector2(0, 8)]])
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure(network); traffic.advance(3.0)
	var before: Array[Dictionary] = traffic.vehicles.duplicate(true)
	traffic.configure(network.duplicate(true))
	t.eq(traffic.vehicles, before, "an identical rebuilt network retains motion and reservation")
	var changed: Dictionary = _network([[Vector2.ZERO, Vector2(0, 9)]])
	traffic.configure(changed)
	t.eq(traffic.vehicles[0]["state"], "waiting", "changed topology safely starts a new fleet")
	t.eq(traffic.vehicles[0]["at"], Vector2.ZERO)

func test_road_addition_reordering_and_resampling_keep_running_trip_and_reservation(t: T) -> void:
	var network: Dictionary = {"routes":[[Vector2.ZERO,Vector2(0,8)]],"connected":["depot","farm"],"access_paths":[[Vector2.ZERO],[Vector2(0,8)]]}
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	traffic.configure(network); traffic.advance(2.3)
	var before: Dictionary = traffic.vehicles[0].duplicate(true)
	var changed: Dictionary = {"routes":[[Vector2(8,0),Vector2(8,8)],[Vector2(0,8),Vector2(0,5),Vector2(0,2),Vector2.ZERO]],
		"connected":["lab","farm","mine","depot"],"access_paths":[[Vector2(8,8)],[Vector2(0,8)],[Vector2(8,0)],[Vector2.ZERO]]}
	traffic.configure(changed)
	t.eq(traffic.vehicles[0],before,"changed network keeps the exact running journey and reservation")
	t.eq(traffic.replaced_trips,0)
	t.eq(traffic.vehicles.size(),2,"new independent development gets a second delivery")
	traffic.advance(0.025)
	t.ok((traffic.vehicles[0]["at"] as Vector2).distance_to(before["at"])<0.04,"first post-change step remains bounded")
	t.ok(traffic.vehicles[0]["active"],"running trip retains its reservation")

func test_removed_pavement_is_not_retained_or_bridged(t: T) -> void:
	var traffic: DecorativeTraffic = DecorativeTraffic.new()
	var network: Dictionary = {"routes":[[Vector2.ZERO,Vector2(0,8)]],"connected":["depot","farm"],"access_paths":[[Vector2.ZERO],[Vector2(0,8)]]}
	traffic.configure(network); traffic.advance(2.0)
	network["routes"]=[[Vector2.ZERO,Vector2(0,3)],[Vector2(0,4),Vector2(0,8)]]
	traffic.configure(network)
	t.eq(traffic.replaced_trips,1,"renderer must conceal an unsupported trip during construction replacement")
	t.empty(traffic.vehicles,"no invisible shortcut across removed pavement")

func test_derived_graph_joins_drawn_crossings_but_excludes_closed_parcels(t: T) -> void:
	var drawn: Array[Array] = [[Vector2(-6,0),Vector2(6,0)],[Vector2(0,-6),Vector2(0,6)]]
	var entries: Array[Dictionary] = [{"id":"a","point":Vector2(-6,0)},{"id":"b","point":Vector2(0,6)}]
	var before: Array[Array] = drawn.duplicate(true)
	var graph: Dictionary = TrafficRoadNetwork.derive(drawn,entries,[])
	var traffic: DecorativeTraffic = DecorativeTraffic.new(); traffic.configure(graph)
	t.eq(traffic.vehicles.size(),1,"a real unsampled road crossing connects actual destinations")
	t.ok(traffic.vehicles[0]["route"].has(Vector2.ZERO))
	var polygon: PackedVector2Array = TrafficRoadNetwork.rectangle(Rect2(-1,-1,2,2))
	graph=TrafficRoadNetwork.derive(drawn,entries,[{"polygon":polygon}])
	traffic.configure(graph)
	t.empty(traffic.vehicles,"closed parcel blocks the crossing without a made-up detour")
	for route: Array in graph["routes"]:
		for point: Vector2 in route:
			t.ok(absf(point.x)<0.0001 or absf(point.y)<0.0001,"retained geometry lies on drawn roads")
			t.not_ok(Rect2(-1,-1,2,2).has_point(point),"closed parcel interior remains empty")
	t.eq(drawn,before,"derived routing never edits its input geometry or recipe")
