class_name ShowcaseData
extends RefCounted
## Sample content for the UI kit showcase. The numbers follow Aster's start in scenario 1 (§10.2)
## so they read plausibly, but they are built here, not computed by the rules (which arrive in M1).
## They are real Breakdown and ReportItem objects, the same types the simulation will emit.


static func food() -> Breakdown:
	var farms: Breakdown = Breakdown.for_resource("breakdown.farm_output", "food", true, {"colony": "Aster"})
	farms.base("source.jobs", 1600, {"count": 4, "job_key": "job.farmer.name", "each": "4.0"})
	farms.mult("source.trait", 2000, {"trait_key": "trait.fertile_soil.name"})
	farms.finish()
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "food", true, {"resource_key": "res.food.name"})
	b.base("source.districts", farms.total, {"district_key": "district.agriculture.name", "count": 2}, farms)
	b.add("source.building", 300, {"building_key": "sample.building.ark_hull"})
	b.add("source.pop_upkeep", -1000, {"count": 10})
	b.note("note.food_growth").link_to("mechanic:food")
	return b.finish()


static func energy() -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "energy", true, {"resource_key": "res.energy.name"})
	b.base("source.jobs", 1000, {"count": 2, "job_key": "job.technician.name", "each": "5.0"})
	b.add("source.jobs", 400, {"count": 2, "job_key": "job.clerk.name", "each": "2.0"})
	b.add("source.building", 300, {"building_key": "sample.building.ark_hull"})
	b.add("source.district_upkeep", -350, {"count": 6})
	return b.finish()


static func minerals() -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "minerals", true, {"resource_key": "res.minerals.name"})
	b.base("source.jobs", 800, {"count": 2, "job_key": "job.miner.name", "each": "4.0"})
	b.add("source.building", 300, {"building_key": "sample.building.ark_hull"})
	return b.finish()


static func alloys() -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "alloys", true, {"resource_key": "res.alloys.name"})
	b.base("source.none_yet", 0, {"job_key": "job.metallurgist.name"})
	b.note("note.alloys_start")
	return b.finish()


static func research() -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "research", true, {"resource_key": "res.research.name"})
	b.base("source.building", 300, {"building_key": "sample.building.ark_archive"})
	b.mult("source.origin", -1000, {"origin_key": "origin.generation_ark.name"})
	return b.finish()


static func influence() -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.resource_net", "influence", true, {"resource_key": "res.influence.name"})
	b.base("source.influence_base", 300)
	b.add("source.stable_colonies", 100, {"count": 1})
	return b.finish()


static func stability() -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.stability", Breakdown.UNIT_POINTS, false, {"colony": "Aster"})
	b.base("source.stability_base", 50)
	b.add("source.jobs_stability", 2, {"count": 2, "job_key": "job.clerk.name"})
	b.add("source.building", 5, {"building_key": "sample.building.ark_hull"})
	b.add("source.origin", 10, {"origin_key": "origin.generation_ark.name"})
	b.add("source.unemployed", -3, {"count": 1})
	b.cap_max(100, "source.stability_range")
	b.cap_min(0, "source.stability_range")
	b.note("note.stability_bands")
	return b.finish()


static func research_cost() -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.research_cost", Breakdown.UNIT_CENTI, false, {"tech_key": "sample.tech.hydroponics"})
	b.base("source.tech_tier", 8000, {"tier": "I"})
	b.mult("source.colony_count", 1000, {"count": 3})
	b.mult("source.catch_up", -1500)
	return b.finish()


static func noise() -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.noise", Breakdown.UNIT_CENTI)
	b.base("source.noise_last", 1250)
	b.add("source.noise_beacon", 25, {"system_key": "system.halden.name"})
	b.add("source.noise_transits", 200, {"count": 2})
	b.add("source.noise_decay", -50)
	b.cap_max(10000, "source.noise_range")
	b.note("note.noise_thresholds")
	return b.finish()


static func turn(t: int) -> Breakdown:
	var b: Breakdown = Breakdown.make("breakdown.turn", Breakdown.UNIT_COUNT)
	b.base("source.turns_played", t)
	b.note("note.calendar")
	return b.finish()


## The top bar model with Aster's starting stocks.
static func top_bar(db: ContentDb) -> TopBar.Model:
	var m: TopBar.Model = TopBar.Model.new()
	var stocks: Dictionary[String, int] = {"food": 15000, "energy": 12000, "minerals": 25000, "alloys": 0, "research": -1, "influence": 6000}
	var breakdowns: Dictionary[String, Breakdown] = {
		"food": food(), "energy": energy(), "minerals": minerals(), "alloys": alloys(),
		"research": research(), "influence": influence(),
	}
	for rid: String in db.ids("resources"):
		var rec: Dictionary = db.record("resources", rid)
		var bd: Breakdown = breakdowns.get(rid)
		m.resources[rid] = {
			"icon": rec["icon"], "color": rec["color"], "name_key": rec["name_key"],
			"stock": stocks.get(rid, 0), "net": bd.total if bd != null else 0, "breakdown": bd,
		}
		m.resource_order.append(rid)
	m.noise = noise().total
	m.noise_breakdown = noise()
	m.turn = 16
	m.turn_breakdown = turn(16)
	return m


static func report_items() -> Array[ReportItem]:
	var items: Array[ReportItem] = [
		ReportItem.make(ReportItem.CATEGORY_COLONIES, 80, "sample.report.overflow", {"resource_key": "res.food.name", "turns": 2}).with_severity(ReportItem.SEVERITY_WARNING).with_breakdown(food()),
		ReportItem.make(ReportItem.CATEGORY_RESEARCH, 70, "sample.report.tech_done", {"tech_key": "sample.tech.hydroponics"}).with_severity(ReportItem.SEVERITY_GOOD),
		ReportItem.make(ReportItem.CATEGORY_STORY, 90, "sample.report.sealed_order").with_severity(ReportItem.SEVERITY_INFO),
		ReportItem.make(ReportItem.CATEGORY_COLONIES, 40, "sample.report.pop_grew", {"colony": "Aster"}),
		ReportItem.make(ReportItem.CATEGORY_FLEETS, 30, "sample.report.probe_idle"),
	]
	return items
