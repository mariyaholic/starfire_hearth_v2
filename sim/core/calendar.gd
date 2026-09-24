class_name Calendar
extends RefCounted
## The Silence calendar. One turn is one month; turn 1 is Month 1 of Year 100 S.
## Presentation formats it through the string table ("Month 4, Year 101 S.").

const START_YEAR: int = 100
const MONTHS_PER_YEAR: int = 12


static func month_of(turn: int) -> int:
	return posmod(turn - 1, MONTHS_PER_YEAR) + 1


static func year_of(turn: int) -> int:
	return START_YEAR + Fx.div_floor(turn - 1, MONTHS_PER_YEAR)
