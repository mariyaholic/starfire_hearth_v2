class_name TradeCommand
extends Command
## Buys or sells a resource for energy at the market's fixed rates (§5.3), in lots of 10.00.

const TYPE: String = "trade"

var resource_id: String = ""
var lots: int = 1
var buying: bool = true


static func create(p_empire_id: String, p_resource_id: String, p_lots: int, p_buying: bool) -> TradeCommand:
	var c: TradeCommand = TradeCommand.new()
	c.empire_id = p_empire_id
	c.resource_id = p_resource_id
	c.lots = p_lots
	c.buying = p_buying
	return c


func type_id() -> String:
	return TYPE


func validate(state: GameState) -> Result:
	return Market.can_trade(state, empire_id, resource_id, lots, buying)


func apply(state: GameState) -> void:
	Market.trade(state, empire_id, resource_id, lots, buying)


func _payload() -> Dictionary:
	return {"resource_id": resource_id, "lots": lots, "buying": buying}


func _load_payload(d: Dictionary) -> void:
	resource_id = DictIO.str_of(d, "resource_id")
	lots = DictIO.int_of(d, "lots", 1)
	buying = DictIO.bool_of(d, "buying", true)
