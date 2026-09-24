class_name ResearchBranch
extends RefCounted
## One research branch of one empire (§5.5): the offered hand, the card being researched, and the
## progress stored in the branch. Progress belongs to the branch, not to a card, so switching
## cards loses nothing and what is left after a tech completes carries over (DESIGN_LOG 70).

var branch: String = ""
## The tech being researched, or "" when no card is picked.
var card: String = ""
## Research points stored in this branch, in centi-units.
var progress: int = 0
## Tech ids currently offered (up to 3).
var hand: Array[String] = []
## Hands drawn so far; salts the next seeded draw.
var draws: int = 0


func to_dict() -> Dictionary:
	return {"branch": branch, "card": card, "progress": progress, "hand": hand.duplicate(), "draws": draws}


static func from_dict(d: Dictionary) -> ResearchBranch:
	var r: ResearchBranch = ResearchBranch.new()
	r.branch = DictIO.str_of(d, "branch")
	r.card = DictIO.str_of(d, "card")
	r.progress = DictIO.int_of(d, "progress")
	r.hand = DictIO.str_arr(d, "hand")
	r.draws = DictIO.int_of(d, "draws")
	return r
