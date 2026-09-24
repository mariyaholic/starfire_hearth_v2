extends RefCounted
## Presentation formatting of fixed-point values (§6.8: numbers show a unit and a sign).


func test_centi(t: T) -> void:
	t.eq(Fmt.centi(1234), "12.34")
	t.eq(Fmt.centi(1200), "12.0", "at least one decimal")
	t.eq(Fmt.centi(1250, true, 1), "+12.5")
	t.eq(Fmt.centi(1234, true, 1), "+12.3")
	t.eq(Fmt.centi(-1000, true, 1), Fmt.MINUS + "10.0")
	t.eq(Fmt.centi(0, true, 1), "0.0", "zero carries no sign")
	t.eq(Fmt.centi(-4, true, 1), "0.0", "rounds to zero without a sign")
	t.eq(Fmt.centi(123456, false, 0), "1,235")
	t.eq(Fmt.centi(-3000, true, 0), Fmt.MINUS + "30")


func test_stock_and_group(t: T) -> void:
	t.eq(Fmt.stock(15000), "150")
	t.eq(Fmt.stock(123456789), "1,234,567")
	t.eq(Fmt.group(1000), "1,000")
	t.eq(Fmt.group(999), "999")
	t.eq(Fmt.group(0), "0")


func test_points_and_bp(t: T) -> void:
	t.eq(Fmt.points(3), "+3")
	t.eq(Fmt.points(-8), Fmt.MINUS + "8")
	t.eq(Fmt.points(0), "0")
	t.eq(Fmt.points(64, false), "64")
	t.eq(Fmt.bp(1000), "+10%")
	t.eq(Fmt.bp(-250), Fmt.MINUS + "2.5%")
	t.eq(Fmt.bp(1550, false), "15.5%")


func test_breakdown_values_follow_units(t: T) -> void:
	var food: Breakdown = Breakdown.for_resource("breakdown.resource_net", "food", true).base("source.building", 1220).finish()
	t.eq(Fmt.total(food), "+12.2", "per-turn flows are signed")
	var stab: Breakdown = Breakdown.make("breakdown.stability", Breakdown.UNIT_POINTS).base("source.stability_base", 64).finish()
	t.eq(Fmt.total(stab), "64", "levels are not signed")
	t.eq(Fmt.line_value(stab, -3), Fmt.MINUS + "3", "lines are always signed")


func test_date_and_rate_use_the_string_table(t: T) -> void:
	t.eq(Fmt.date(16), "Month 4, Year 101 S.")
	t.eq(Fmt.rate(400, "Food"), "+4.0 food / turn")
