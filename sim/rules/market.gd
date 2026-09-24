class_name Market
extends RefCounted
## The market (§5.3), fixed rates in the POC. Energy is the currency: food and minerals buy at
## 1.50 and sell at 1.00 energy each, metals at 6.00 and 4.00. Influence and research cannot be
## traded. The market opens with a Market Exchange (DESIGN_LOG 78). Trades happen at once, in
## lots of 10.00, and every trade shows its exact rate.

const LOT: int = 1000
## Resource -> [buy, sell] price of 1.00, in centi-energy.
const RATES: Dictionary[String, Array] = {
	"food": [150, 100],
	"minerals": [150, 100],
	"alloys": [600, 400],
}
const MAX_LOTS: int = 20


static func is_open(state: GameState, empire_id: String) -> bool:
	for c: Colony in state.colonies_of(empire_id):
		if Construction.provides(c, "market"):
			return true
	return false


## Energy paid (buying) or received (selling) for `amount` centi-units of a resource.
static func price(resource_id: String, amount: int, buying: bool) -> int:
	var rate: int = int(RATES[resource_id][0 if buying else 1])
	return Fx.div_floor(amount * rate, Fx.ONE)


## The trade explained: the amount, the rate, and the energy that changes hands.
static func quote(resource_id: String, amount: int, buying: bool) -> Breakdown:
	var b: Breakdown = Breakdown.for_resource("breakdown.trade", "energy", false, {"resource_key": "res.%s.name" % resource_id})
	b.link_to("mechanic:market")
	var rate: int = int(RATES[resource_id][0 if buying else 1])
	var p: int = price(resource_id, amount, buying)
	b.base("source.trade_rate_buy" if buying else "source.trade_rate_sell", -p if buying else p, {"amount_c": amount, "rate_c": rate})
	return b.finish()


static func can_trade(state: GameState, empire_id: String, resource_id: String, lots: int, buying: bool) -> Result:
	if not state.empires.has(empire_id):
		return Result.fail("error.empire.not_found")
	if not is_open(state, empire_id):
		return Result.fail("error.market.closed")
	if not RATES.has(resource_id):
		return Result.fail("error.market.not_traded")
	if lots < 1 or lots > MAX_LOTS:
		return Result.fail("error.market.bad_amount", {"max": MAX_LOTS})
	var e: Empire = state.empires[empire_id]
	var amount: int = lots * LOT
	if buying:
		var cost: int = price(resource_id, amount, true)
		if e.stock_of("energy") < cost:
			return Result.fail("error.build.cannot_afford", {"resource_key": "res.energy.name", "need": Fx.div_ceil(cost, Fx.ONE), "have": Fx.div_floor(e.stock_of("energy"), Fx.ONE)})
	elif e.stock_of(resource_id) < amount:
		return Result.fail("error.build.cannot_afford", {"resource_key": "res.%s.name" % resource_id, "need": Fx.div_ceil(amount, Fx.ONE), "have": Fx.div_floor(e.stock_of(resource_id), Fx.ONE)})
	return Result.success()


## Applies a trade. Anything above a storage cap is lost at the next production phase, as usual.
static func trade(state: GameState, empire_id: String, resource_id: String, lots: int, buying: bool) -> void:
	var e: Empire = state.empires[empire_id]
	var amount: int = lots * LOT
	var energy: int = price(resource_id, amount, buying)
	if buying:
		e.stock["energy"] = e.stock_of("energy") - energy
		e.stock[resource_id] = e.stock_of(resource_id) + amount
	else:
		e.stock[resource_id] = e.stock_of(resource_id) - amount
		e.stock["energy"] = e.stock_of("energy") + energy
