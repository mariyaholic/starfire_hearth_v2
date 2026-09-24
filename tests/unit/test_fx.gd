extends RefCounted
## Fixed-point helpers and the calendar.


func test_div_floor_rounds_toward_negative_infinity(t: T) -> void:
	t.eq(Fx.div_floor(7, 2), 3)
	t.eq(Fx.div_floor(-7, 2), -4)
	t.eq(Fx.div_floor(7, -2), -4)
	t.eq(Fx.div_floor(-7, -2), 3)
	t.eq(Fx.div_floor(-8, 2), -4)
	t.eq(Fx.div_floor(0, 5), 0)


func test_div_ceil(t: T) -> void:
	t.eq(Fx.div_ceil(7, 2), 4)
	t.eq(Fx.div_ceil(-7, 2), -3)
	t.eq(Fx.div_ceil(8, 2), 4)


func test_mul_bp(t: T) -> void:
	t.eq(Fx.mul_bp(400, 1000), 40, "+10% of 4.00 is 0.40")
	t.eq(Fx.mul_bp(500, 2500), 125, "+25% of 5.00 is 1.25")
	t.eq(Fx.mul_bp(-600, 2500), -150, "+25% of -6.00 is -1.50")
	t.eq(Fx.mul_bp(333, 1000), 33, "floored")
	t.eq(Fx.mul_bp(-333, 1000), -34, "floored toward negative infinity")


func test_parse_centi(t: T) -> void:
	t.eq(Fx.parse_centi("4.00"), [true, 400])
	t.eq(Fx.parse_centi("-6"), [true, -600])
	t.eq(Fx.parse_centi("0.5"), [true, 50])
	t.eq(Fx.parse_centi(" 12.34 "), [true, 1234])
	t.eq(Fx.parse_centi("1.234")[0], false, "three decimals rejected")
	t.eq(Fx.parse_centi("abc")[0], false)
	t.eq(Fx.parse_centi("")[0], false)


func test_calendar(t: T) -> void:
	t.eq(Calendar.month_of(1), 1)
	t.eq(Calendar.year_of(1), 100, "the game starts in Year 100 S.")
	t.eq(Calendar.month_of(12), 12)
	t.eq(Calendar.year_of(12), 100)
	t.eq(Calendar.month_of(13), 1)
	t.eq(Calendar.year_of(13), 101)
	t.eq(Calendar.month_of(16), 4, "turn 16 is Month 4, Year 101 S.")
	t.eq(Calendar.year_of(16), 101)
