class_name SetGovernorCommand
extends Command
## Turns a colony's governor on or off and sets its focus and budget (§5.4).

const TYPE: String = "set_governor"
const MIN_BUDGET_BP: int = 1000
const MAX_BUDGET_BP: int = 10000

var colony_id: String = ""
var enabled: bool = true
var focus: String = "balanced"
var budget_bp: int = Colony.DEFAULT_GOVERNOR_BUDGET_BP


static func create(p_empire_id: String, p_colony_id: String, p_enabled: bool, p_focus: String = "balanced", p_budget_bp: int = Colony.DEFAULT_GOVERNOR_BUDGET_BP) -> SetGovernorCommand:
	var c: SetGovernorCommand = SetGovernorCommand.new()
	c.empire_id = p_empire_id
	c.colony_id = p_colony_id
	c.enabled = p_enabled
	c.focus = p_focus
	c.budget_bp = p_budget_bp
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	var failures: Array[Result] = []
	var c: Colony = Command.owned_colony(state, empire_id, colony_id, failures)
	if c == null:
		return failures[0]
	if c.is_outpost():
		return Result.fail("error.build.outpost")
	if not Colony.GOVERNOR_FOCUSES.has(focus):
		return Result.fail("error.governor.bad_focus")
	if budget_bp < MIN_BUDGET_BP or budget_bp > MAX_BUDGET_BP:
		return Result.fail("error.governor.bad_budget", {"min": Fx.div_floor(MIN_BUDGET_BP, 100), "max": Fx.div_floor(MAX_BUDGET_BP, 100)})
	return Result.success()


func apply(state: GameState) -> void:
	var c: Colony = state.colonies[colony_id]
	if not enabled and c.governor_funds > 0:
		# The purse goes back to the Compact.
		var e: Empire = state.empires[empire_id]
		e.stock["minerals"] = e.stock_of("minerals") + c.governor_funds
		c.governor_funds = 0
	c.governor_on = enabled
	c.governor_focus = focus
	c.governor_budget_bp = budget_bp


func _payload() -> Dictionary:
	return {"colony_id": colony_id, "enabled": enabled, "focus": focus, "budget_bp": budget_bp}


func _load_payload(d: Dictionary) -> void:
	colony_id = DictIO.str_of(d, "colony_id")
	enabled = DictIO.bool_of(d, "enabled", true)
	focus = DictIO.str_of(d, "focus", "balanced")
	budget_bp = DictIO.int_of(d, "budget_bp", Colony.DEFAULT_GOVERNOR_BUDGET_BP)
