class_name RerollResearchCommand
extends Command
## Pays 25 influence for a new hand in one branch (§5.5). The picked card and story cards stay.

const TYPE: String = "reroll_research"

var branch: String = ""


static func create(p_empire_id: String, p_branch: String) -> RerollResearchCommand:
	var c: RerollResearchCommand = RerollResearchCommand.new()
	c.empire_id = p_empire_id
	c.branch = p_branch
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not Empire.BRANCHES.has(branch):
		return Result.fail("error.research.bad_branch")
	var e: Empire = state.empires[empire_id]
	var cost: Dictionary[String, int] = {"influence": Research.REROLL_COST}
	var r: Result = Construction._check_cost(e, cost)
	if not r.ok:
		return r
	var others: int = 0
	for tid: String in Research.available(state, e, branch):
		if not e.branch(branch).hand.has(tid):
			others += 1
	if others == 0:
		return Result.fail("error.research.nothing_new")
	return Result.success()


func apply(state: GameState) -> void:
	var e: Empire = state.empires[empire_id]
	e.stock["influence"] = e.stock_of("influence") - Research.REROLL_COST
	Research.reroll(state, e, branch)


func _payload() -> Dictionary:
	return {"branch": branch}


func _load_payload(d: Dictionary) -> void:
	branch = DictIO.str_of(d, "branch")
