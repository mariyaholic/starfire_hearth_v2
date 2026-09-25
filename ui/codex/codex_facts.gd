class_name CodexFacts
extends RefCounted
## The numbers the Codex's mechanics pages quote (§6.5), read from the rules' constants and the
## data files at run time, so the prose can never disagree with the game. A page writes {name}
## and gets the value here, formatted with its unit.


static func values() -> Dictionary[String, String]:
	var db: ContentDb = Content.db()
	var f: Dictionary[String, String] = {}
	# Settlers and growth.
	f["growth_base"] = _pct(Fx.div_floor(Population.GROWTH_BASE * 10000, Population.GROWTH_NEEDED))
	f["growth_per_free"] = _pct(Fx.div_floor(Population.GROWTH_PER_FREE * 10000, Population.GROWTH_NEEDED))
	f["growth_max"] = _pct(Fx.div_floor(Population.GROWTH_MAX * 10000, Population.GROWTH_NEEDED))
	f["homeless_growth"] = _pct(Population.HOMELESS_BP)
	f["famine_period"] = str(Population.FAMINE_PERIOD)
	f["colony_at"] = "%dk" % ColonyRules.COLONY_AT
	f["city_at"] = "%dk" % ColonyRules.CITY_AT
	f["developed_pops"] = "%dk" % ColonyRules.DEVELOPED_POPS
	f["developed_districts"] = str(ColonyRules.DEVELOPED_DISTRICTS)
	f["building_cap"] = str(ColonyRules.BUILDING_CAP)
	f["city_extra_buildings"] = str(ColonyRules.CITY_EXTRA_BUILDINGS)
	# Stability.
	f["stability_base"] = str(Stability.BASE)
	f["unemployed"] = _signed(Stability.UNEMPLOYED)
	f["homeless"] = _signed(Stability.HOMELESS)
	f["energy_short"] = _signed(Stability.ENERGY_SHORT)
	f["famine"] = _signed(Stability.FAMINE)
	f["unrest_at"] = str(Stability.UNREST_AT)
	f["autonomy_at"] = str(Stability.AUTONOMY_AT)
	f["autonomy_warning"] = str(Stability.AUTONOMY_WARNING)
	f["stable_at"] = str(Modifiers.STABLE_AT)
	f["stable_bonus"] = _pct(Modifiers.STABLE_BP)
	f["unstable_at"] = str(Modifiers.UNSTABLE_AT)
	f["unstable_loss"] = _pct(-Modifiers.UNSTABLE_BP)
	# Economy.
	f["food_per_pop"] = _amount(Economy.FOOD_PER_POP, "food")
	f["capital_research"] = Strings.centi(Economy.CAPITAL_RESEARCH)
	f["influence_base"] = Strings.centi(Economy.INFLUENCE_BASE)
	f["influence_per_stable"] = Strings.centi(Economy.INFLUENCE_PER_STABLE)
	f["influence_stable_at"] = str(Economy.INFLUENCE_STABLE_AT)
	f["outpost_minerals"] = _amount(Economy.OUTPOST_YIELD["minerals"], "minerals")
	f["outpost_energy"] = _amount(Economy.OUTPOST_YIELD["energy"], "energy")
	f["outpost_research"] = Strings.centi(Economy.OUTPOST_YIELD["research"])
	f["outpost_upkeep"] = _amount(Economy.OUTPOST_UPKEEP, "energy")
	var smith: Dictionary = db.record("jobs", "metallurgist")
	f["industry_input"] = _amount(DictIO.int_of(DictIO.dict_of(smith, "input"), "minerals"), "minerals")
	f["industry_output"] = _amount(DictIO.int_of(DictIO.dict_of(smith, "output"), "alloys"), "alloys")
	# Research.
	f["hand_size"] = str(Research.HAND_SIZE)
	for tier: int in Research.TIER_COST.keys():
		f["tier_%d_cost" % tier] = Strings.centi(Research.TIER_COST[tier])
	f["cost_per_colony"] = _pct(Research.COST_PER_COLONY_BP)
	f["reroll_cost"] = Strings.centi(Research.REROLL_COST)
	# Construction, governors, ordinances.
	f["max_queue"] = str(Construction.MAX_QUEUE)
	f["veto_turns"] = str(Governor.VETO_TURNS)
	f["funds_cap"] = _amount(Governor.FUNDS_CAP, "minerals")
	f["governor_budget"] = _pct(Colony.DEFAULT_GOVERNOR_BUDGET_BP)
	f["ordinance_slots"] = str(Ordinances.BASE_SLOTS)
	# Ships.
	f["survey_turns"] = str(Ships.SURVEY_TURNS)
	f["outpost_turns"] = str(Ships.OUTPOST_TURNS)
	f["colonise_turns"] = str(Ships.COLONISE_TURNS)
	f["outpost_influence"] = Strings.centi(Ships.OUTPOST_INFLUENCE)
	f["outpost_floor"] = _pct(-Ships.OUTPOST_COST_FLOOR_BP)
	f["colony_pops"] = "%dk" % Ships.COLONY_POPS
	# Market.
	f["market_lot"] = Strings.centi(Market.LOT)
	f["market_max_lots"] = str(Market.MAX_LOTS)
	for res: String in Market.RATES.keys():
		f["%s_buy" % res] = _amount(int(Market.RATES[res][0]), "energy")
		f["%s_sell" % res] = _amount(int(Market.RATES[res][1]), "energy")
	# District tiers and adjacency, from the data.
	var hab: Dictionary = db.record("districts", "habitation")
	for t: Variant in DictIO.arr_of(hab, "tiers"):
		var td: Dictionary = t
		var n: int = DictIO.int_of(td, "tier")
		f["tier%d_tech" % n] = Strings.fmt(DictIO.str_of(db.record("techs", DictIO.str_of(td, "requires_tech")), "name_key"))
		f["tier%d_cost" % n] = "%s×" % Strings.centi(Fx.div_floor(DictIO.int_of(td, "cost_mult_bp"), 100))
		f["tier%d_jobs" % n] = str(DictIO.int_of(td, "extra_jobs"))
		f["tier%d_output" % n] = Strings.percent(DictIO.int_of(td, "output_bp"))
	for did: String in db.ids("districts"):
		for a: Variant in DictIO.arr_of(db.record("districts", did), "adjacency"):
			var ad: Dictionary = a
			var key: String = "adj_%s_%s" % [did, DictIO.str_of(ad, "with")]
			if ad.has("bonus_bp"):
				f[key] = Strings.percent(DictIO.int_of(ad, "bonus_bp"))
				f[key + "_cap"] = _pct(DictIO.int_of(ad, "cap_bp"))
			if ad.has("stability_add"):
				f[key + "_stability"] = _signed(DictIO.int_of(ad, "stability_add"))
	# Habitability by planet type, and the difficulty presets.
	for pid: String in db.ids("planet_types"):
		f["hab_%s" % pid] = _pct(DictIO.int_of(db.record("planet_types", pid), "habitability_bp"))
	for did2: String in db.ids("difficulty"):
		var dd: Dictionary = db.record("difficulty", did2)
		f["%s_output" % did2] = Strings.percent(DictIO.int_of(dd, "player_output_bp", 10000) - 10000)
		f["%s_severity" % did2] = _pct(DictIO.int_of(dd, "event_severity_bp", 10000))
	return f


## Fills {name} placeholders; unknown names stay as they are, which the Codex tests catch.
static func fill(text: String, facts: Dictionary[String, String]) -> String:
	var values: Dictionary = {}
	for k: String in facts.keys():
		values[k] = facts[k]
	return text.format(values)


## An unsigned percentage: 1000 -> "10%".
static func _pct(bp: int) -> String:
	return Strings.percent(absi(bp)).trim_prefix("+")


static func _signed(points: int) -> String:
	return ("+%d" % points) if points > 0 else ("−%d" % -points if points < 0 else "0")


static func _amount(centi: int, res: String) -> String:
	var unit_key: String = DictIO.str_of(Content.db().record("resources", res), "unit_key")
	return Strings.centi(centi) + (" " + Strings.fmt(unit_key) if not unit_key.is_empty() else "")
