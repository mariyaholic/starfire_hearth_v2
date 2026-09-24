extends RefCounted
## Build queues (DESIGN_LOG 57): placement checks with reasons, paying on queue, one build at a
## time, refunds, demolition, tiers, building limits and rushing.

const P: String = "emp_player"


func test_place_district_pays_and_completes_after_its_turns(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var cmd: PlaceDistrictCommand = PlaceDistrictCommand.create(P, cid, 8, "agriculture")
	t.ok(cmd.validate(s).ok)
	var r: TurnResult = S1.turn(s, [cmd])
	t.eq(r.state.player().stock_of("minerals"), 25000 - 6000 + 1100, "paid 60 when queued, then a turn of income")
	t.eq(S1.aster(r.state).queue.size(), 1)
	t.eq(S1.aster(r.state).queue[0].turns_left, 2, "3 build turns; the first passed at once")
	r = S1.advance(r.state, 2)
	t.eq(S1.aster(r.state).queue.size(), 0)
	t.ne(S1.aster(r.state).district_at(8), null, "the Farm district stands on slot 8")


func test_placement_refusals_say_why(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	t.eq(PlaceDistrictCommand.create(P, cid, 7, "mining").validate(s).reason_key, "error.build.blocked_slot")
	t.eq(PlaceDistrictCommand.create(P, cid, 0, "mining").validate(s).reason_key, "error.build.slot_taken")
	t.eq(PlaceDistrictCommand.create(P, cid, 99, "mining").validate(s).reason_key, "error.build.bad_slot")
	t.eq(PlaceDistrictCommand.create(P, cid, 8, "research").validate(s).reason_key, "error.build.branch_needed")
	t.eq(PlaceDistrictCommand.create(P, cid, 8, "mining", "physics").validate(s).reason_key, "error.build.no_branch")
	t.eq(PlaceDistrictCommand.create(P, cid, 8, "nonsense").validate(s).reason_key, "error.build.unknown")
	s.player().stock["minerals"] = 1000
	var poor: Result = PlaceDistrictCommand.create(P, cid, 8, "mining").validate(s)
	t.eq(poor.reason_key, "error.build.cannot_afford")
	t.eq(poor.args["need"], 60)
	t.eq(poor.args["have"], 10)


func test_queue_reserves_slots_and_cancel_refunds_in_full(t: T) -> void:
	var s: GameState = S1.build()
	var q: CommandQueue = CommandQueue.new(s)
	var cid: String = S1.aster(s).id
	t.ok(q.submit(PlaceDistrictCommand.create(P, cid, 8, "mining")).ok)
	t.eq(q.submit(PlaceDistrictCommand.create(P, cid, 8, "energy")).reason_key, "error.build.slot_queued")
	var item_id: String = q.preview().colonies[cid].queue[0].id
	t.ok(q.submit(CancelBuildCommand.create(P, cid, item_id)).ok)
	t.eq(q.preview().player().stock_of("minerals"), 25000, "a cancelled build refunds all of its cost")


func test_only_the_first_item_progresses(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var cmds: Array[Command] = [PlaceDistrictCommand.create(P, cid, 8, "mining"), PlaceDistrictCommand.create(P, cid, 9, "mining")]
	var r: TurnResult = S1.turn(s, cmds)
	var c: Colony = S1.aster(r.state)
	t.eq(c.queue[0].turns_left, 2)
	t.eq(c.queue[1].turns_left, 3, "the second item waits")
	var second: String = c.queue[1].id
	r = S1.turn(r.state, [MoveBuildUpCommand.create(P, cid, second)])
	t.eq(S1.aster(r.state).queue[0].id, second, "moved to the front")
	t.eq(S1.aster(r.state).queue[0].turns_left, 2)


func test_demolish_is_instant_and_story_buildings_stay(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var cmd: DemolishCommand = DemolishCommand.create(P, cid, 4)
	t.ok(cmd.validate(s).ok)
	cmd.apply(s)
	t.eq(S1.aster(s).district_at(4), null)
	t.eq(DemolishCommand.create(P, cid, 4).validate(s).reason_key, "error.build.nothing_there")
	t.eq(DemolishCommand.create(P, cid, -1).validate(s).reason_key, "error.build.nothing_there", "landmarks have no slot to demolish")


func test_upgrade_needs_tech_and_stage(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	t.eq(UpgradeDistrictCommand.create(P, cid, 2).validate(s).reason_key, "error.build.needs_tech")
	s.player().techs.append("advanced_districts")
	var ok: UpgradeDistrictCommand = UpgradeDistrictCommand.create(P, cid, 2)
	t.ok(ok.validate(s).ok, "Aster (10k settlers) is at the Colony stage")
	ok.apply(s)
	t.eq(S1.aster(s).queue[0].paid["minerals"], 12000, "tier II costs twice the base")
	s.player().techs.append("foundry_automation")
	S1.aster(s).queue.clear()
	S1.aster(s).district_at(2).tier = 2
	var r3: Result = UpgradeDistrictCommand.create(P, cid, 2).validate(s)
	t.eq(r3.reason_key, "error.build.needs_stage", "tier III needs a City (15k settlers)")


func test_tier_two_adds_a_job_and_a_quarter_more_output(t: T) -> void:
	var s: GameState = S1.build()
	var c: Colony = S1.aster(s)
	c.district_at(4).tier = 2
	c.pops = 11
	var cr: Economy.ColonyReport = Economy.colony(s, c)
	t.eq(cr.jobs_total, 11)
	var energy_group: Breakdown = null
	for l: Breakdown.Line in cr.net["energy"].lines:
		if l.child != null and str(l.source_args.get("district_key", "")) == "district.energy.name":
			energy_group = l.child
	t.ne(energy_group, null)
	if energy_group != null:
		t.eq(energy_group.total, 1500 + 375, "3 technicians x 5.00, +25% for tier II")


func test_building_limits(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	t.eq(BuildBuildingCommand.create(P, cid, 8, "hydroponics_bay").validate(s).reason_key, "error.build.needs_tech")
	t.eq(BuildBuildingCommand.create(P, cid, 8, "spaceport").validate(s).reason_key, "error.build.unique_colony")
	t.eq(BuildBuildingCommand.create(P, cid, 8, "ark_hull").validate(s).reason_key, "error.build.story_only")
	t.eq(BuildBuildingCommand.create(P, cid, 8, "habitat_dome").validate(s).reason_key, "error.build.needs_tech")
	s.player().techs.append("habitat_domes")
	t.eq(BuildBuildingCommand.create(P, cid, 8, "habitat_dome").validate(s).reason_key, "error.build.needs_dome_world")
	s.player().stock["minerals"] = 100000
	var q: CommandQueue = CommandQueue.new(s)
	for slot: int in [8, 9, 10]:
		t.ok(q.submit(BuildBuildingCommand.create(P, cid, slot, "park_commons")).ok)
	t.eq(q.submit(BuildBuildingCommand.create(P, cid, 11, "storehouse")).reason_key, "error.build.building_cap", "4 buildings; the Ark Hull, a landmark, does not count")


func test_rush_takes_a_turn_off_for_energy(t: T) -> void:
	var s: GameState = S1.build()
	var cid: String = S1.aster(s).id
	var q: CommandQueue = CommandQueue.new(s)
	q.submit(PlaceDistrictCommand.create(P, cid, 8, "industry"))
	var item: BuildItem = q.preview().colonies[cid].queue[0]
	var cost: int = Construction.rush_cost(item).total
	t.eq(cost, 3000, "80 minerals at the market's 1.50, over 4 turns")
	t.ok(q.submit(RushBuildCommand.create(P, cid, item.id)).ok)
	t.eq(q.preview().colonies[cid].queue[0].turns_left, 3)
	t.eq(q.submit(RushBuildCommand.create(P, cid, item.id)).reason_key, "error.build.rush_once")
	t.eq(q.preview().player().stock_of("energy"), 12000 - 3000)
