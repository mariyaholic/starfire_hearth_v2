class_name PickResearchCommand
extends Command
## Picks the card a branch researches (§5.5). Progress belongs to the branch, so switching cards
## loses nothing (DESIGN_LOG 70).

const TYPE: String = "pick_research"

var branch: String = ""
var tech_id: String = ""


static func create(p_empire_id: String, p_branch: String, p_tech_id: String) -> PickResearchCommand:
	var c: PickResearchCommand = PickResearchCommand.new()
	c.empire_id = p_empire_id
	c.branch = p_branch
	c.tech_id = p_tech_id
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not Empire.BRANCHES.has(branch):
		return Result.fail("error.research.bad_branch")
	var e: Empire = state.empires[empire_id]
	if not e.research.has(branch) or not e.research[branch].hand.has(tech_id):
		return Result.fail("error.research.not_offered")
	if e.research[branch].card == tech_id:
		return Result.fail("error.research.already_picked")
	return Result.success()


func apply(state: GameState) -> void:
	state.empires[empire_id].research[branch].card = tech_id


func _payload() -> Dictionary:
	return {"branch": branch, "tech_id": tech_id}


func _load_payload(d: Dictionary) -> void:
	branch = DictIO.str_of(d, "branch")
	tech_id = DictIO.str_of(d, "tech_id")
