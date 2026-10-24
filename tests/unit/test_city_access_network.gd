extends RefCounted

func test_shared_streets_have_no_duplicate_edges_and_stop_at_entrances(t: T) -> void:
	var entries: Array[Dictionary]=[
		{"id":"hall","point":Vector2(-9,0)},
		{"id":"industry","point":Vector2(9,0)},
		{"id":"homes","point":Vector2(6,6)},
		{"id":"lab","point":Vector2(6,-6)}]
	var network: Dictionary=CityAccessNetwork.plan(entries,[])
	t.eq(network["connected"].size(),4); t.ok(network["unreachable"].is_empty())
	t.ok(not network["junctions"].is_empty(),"shared access has actual branch junctions")
	# Four independent routes from (-9,0) cost 60 units in this fixture.
	t.ok(float(network["length"])<60,"network reuses a common street")
	var seen: Dictionary={}
	for route: Array in network["routes"]:
		for i: int in route.size()-1:
			var key: String=CityAccessNetwork._edge_key(route[i],route[i+1])
			t.not_ok(seen.has(key),"only one rendered edge per street")
			seen[key]=true
	for i: int in network["access_paths"].size():
		var path: Array=network["access_paths"][i]
		t.ok(entries.any(func(entry: Dictionary) -> bool: return entry["point"]==path[0]),"starts at an external entrance")
	var reversed: Array[Dictionary]=entries.duplicate(true); reversed.reverse()
	var again: Dictionary=CityAccessNetwork.plan(reversed,[])
	for key: String in ["routes","access_paths","connected","unreachable","junctions","length","cost"]:
		t.eq(again[key],network[key],"caller ordering cannot alter "+key)

func test_network_avoids_footprints_and_reports_impossible_entrances(t: T) -> void:
	var obstacles: Array[Dictionary]=[{"rect":Rect2(-3,-3,6,6)}]
	var entries: Array[Dictionary]=[{"id":"left","point":Vector2(-6,0)},{"id":"right","point":Vector2(6,0)},{"id":"invalid","point":Vector2.ZERO}]
	var network: Dictionary=CityAccessNetwork.plan(entries,obstacles)
	t.eq(network["connected"].size(),2)
	t.eq(network["unreachable"],[{"id":"invalid","reason":"entrance_blocked"}])
	for route: Array in network["routes"]:
		for i: int in route.size()-1:
			t.ok(CityAccessNetwork.clear(route[i],route[i+1],obstacles),"street clearance excludes the footprint")

func test_terrain_rejects_cliffs_and_water_but_accepts_supported_platforms(t: T) -> void:
	var entries: Array[Dictionary]=[{"id":"a","point":Vector2(-3,0)},{"id":"b","point":Vector2(3,0)}]
	var cliff: Callable=func(x: float,_z: float) -> float: return 10.0 if x>0 else 1.0
	var network: Dictionary=CityAccessNetwork.plan(entries,[],cliff)
	t.eq(network["connected"].size(),1); t.eq(network["unreachable"].size(),1,"no silent road across a cliff")
	var ocean: Callable=func(x: float,_z: float) -> float: return -1.0 if absf(x)<1 else 1.0
	network=CityAccessNetwork.plan(entries,[],ocean,true)
	t.eq(network["connected"].size(),1); t.eq(network["unreachable"].size(),1,"water requires a supported crossing")
	var platform: Callable=func(_x: float,_z: float) -> float: return 1.0
	network=CityAccessNetwork.plan(entries,[],platform,true)
	t.eq(network["connected"].size(),2); t.ok(network["unreachable"].is_empty(),"supported ocean platforms remain accessible")

func test_sloped_detour_is_valid_and_demolition_rebuilds_network(t: T) -> void:
	var entries: Array[Dictionary]=[{"id":"a","point":Vector2(-6,0)},{"id":"b","point":Vector2(6,0)}]
	var hill: Callable=func(x: float,z: float) -> float: return 3.0*exp(-(x*x+z*z)/6.0)
	var obstacles: Array[Dictionary]=[{"rect":Rect2(-1,-2,2,4)}]
	var network: Dictionary=CityAccessNetwork.plan(entries,obstacles,hill)
	t.eq(network["connected"].size(),2)
	for route: Array in network["routes"]:
		for i: int in route.size()-1:
			t.ok(CityAccessNetwork.traversable(route[i],route[i+1],obstacles,hill,false),"smoothing retains terrain constraints")
	var flat: Dictionary=CityAccessNetwork.plan(entries,[])
	t.ok(float(flat["length"])<float(network["length"]),"removed obstacle permits a shorter street")
