extends RefCounted
## Breakdowns sum exactly to their totals (§6.1, §9.8).


func test_base_add_mult_sum_to_total(t: T) -> void:
	var b: Breakdown = Breakdown.for_resource("breakdown.food_net", "food")
	b.base("source.jobs.farmers", 800).add("source.upkeep.pops", -1000).mult("source.trait.fertile", 2000)
	b.finish()
	t.eq(b.lines[2].value, -40, "+20% of -2.00 is -0.40")
	t.eq(b.total, -240)
	t.ok(b.verify())


func test_mults_are_additive_and_rounded_per_line(t: T) -> void:
	var b: Breakdown = Breakdown.for_resource("breakdown.energy", "energy")
	b.base("source.jobs.technicians", 333).mult("source.tech", 1000).mult("source.edict", 1000)
	b.finish()
	t.eq(b.lines[1].value, 33)
	t.eq(b.lines[2].value, 33)
	t.eq(b.total, 399, "per-line rounding: 333 + 33 + 33")
	t.ok(b.verify())


func test_caps_clamp_last_and_record_the_loss(t: T) -> void:
	var b: Breakdown = Breakdown.make("breakdown.stability", Breakdown.UNIT_POINTS)
	b.base("source.base", 50).add("source.civic_hall", 10).add("source.park", 8).add("source.festival", 10)
	b.add("source.origin", 10).add("source.clerks", 20).mult("source.none", 0)
	b.cap_max(100, "source.cap.max").cap_min(0, "source.cap.min")
	b.finish()
	t.eq(b.total, 100)
	var cap_line: Breakdown.Line = b.lines[b.lines.size() - 2]
	t.eq(cap_line.value, -8, "108 clamped to 100 removes 8")
	t.ok(b.verify())
	t.eq(b.visible_lines().size(), b.lines.size() - 1, "the floor cap did not bite and is hidden")


func test_nested_children_verify(t: T) -> void:
	var child: Breakdown = Breakdown.for_resource("breakdown.farmers", "food").base("source.job.farmer", 400).add("source.job.farmer", 400).finish()
	var parent: Breakdown = Breakdown.for_resource("breakdown.food", "food").base("source.jobs.farmers", child.total, {}, child).finish()
	t.ok(parent.verify())
	t.eq(parent.lines[0].child.total, 800)


func test_unfinished_breakdown_does_not_verify(t: T) -> void:
	var b: Breakdown = Breakdown.make("x", Breakdown.UNIT_POINTS).base("y", 1)
	t.not_ok(b.verify())


func test_to_dict_is_canonical_json_safe(t: T) -> void:
	var b: Breakdown = Breakdown.for_resource("a", "food").base("b", 100, {"n": 2}).finish()
	var errors: Array[String] = []
	CanonicalJson.stringify(b.to_dict(), errors)
	t.empty(errors)
