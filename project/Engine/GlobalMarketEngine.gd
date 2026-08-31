extends Resource
class_name GlobalMarketEngine

var gs

func _init(_gs):
	gs = _gs


var goods_market = {}

var GOODS_DEFS = {
	"Silk": {
		"base_value": 200,
		"rarity": 1.25,
		"era_mods": {
			"Ancient Era": 1.3,
			"Medieval Era": 1.45,
			"Industrial Era": 0.95,
			"Modern Era": 0.8,
			"Future Era": 0.7
		}
	},
	"Spices": {
		"base_value": 150,
		"rarity": 1.2,
		"era_mods": {
			"Ancient Era": 1.15,
			"Medieval Era": 1.35,
			"Industrial Era": 1.05,
			"Modern Era": 0.95,
			"Future Era": 0.9
		}
	},
	"Gold": {
		"base_value": 500,
		"rarity": 1.35,
		"era_mods": {
			"Ancient Era": 1.1,
			"Medieval Era": 1.15,
			"Industrial Era": 1.2,
			"Modern Era": 1.25,
			"Future Era": 1.3
		}
	},
	"Salt": {
		"base_value": 80,
		"rarity": 1.05,
		"era_mods": {
			"Ancient Era": 1.4,
			"Medieval Era": 1.3,
			"Industrial Era": 0.85,
			"Modern Era": 0.7,
			"Future Era": 0.55
		}
	},
	"Tea": {
		"base_value": 120,
		"rarity": 1.1,
		"era_mods": {
			"Ancient Era": 0.85,
			"Medieval Era": 1.05,
			"Industrial Era": 1.25,
			"Modern Era": 1.0,
			"Future Era": 0.95
		}
	},
	"Ivory": {
		"base_value": 300,
		"rarity": 1.3,
		"era_mods": {
			"Ancient Era": 1.2,
			"Medieval Era": 1.25,
			"Industrial Era": 1.1,
			"Modern Era": 0.9,
			"Future Era": 0.75
		}
	},
	"Jewels": {
		"base_value": 450,
		"rarity": 1.28,
		"era_mods": {
			"Ancient Era": 1.05,
			"Medieval Era": 1.2,
			"Industrial Era": 1.2,
			"Modern Era": 1.15,
			"Future Era": 1.1
		}
	}
}





func _ensure_bootstrapped():
	if goods_market.size() > 0:
		return

	for name in GOODS_DEFS.keys():
		var d = GOODS_DEFS [name]
		goods_market [name] = {
			"base_value": d ["base_value"],
			"rarity": d ["rarity"],
			"supply_pressure": 0.0,
			"war_pressure": 0.0,
			"trend": 1.0,
			"price": d ["base_value"]
		}

	_resolve_all_prices()





func get_price_for_good(good_name: String, realm_id:= -1) -> int:
	_ensure_bootstrapped()

	if not goods_market.has(good_name):
		return 0

	var data = goods_market [good_name]
	var price = float(data ["price"])

	if realm_id != -1:
		price *= _realm_local_modifier(realm_id)

	return max(1, int(price))


func get_market_snapshot() -> Dictionary:
	_ensure_bootstrapped()
	return goods_market.duplicate(true)





func yearly_market_tick(_payload:= {}):
	_ensure_bootstrapped()

	for good_name in goods_market.keys():
		var g = goods_market [good_name]


		g ["supply_pressure"] = lerp(float(g ["supply_pressure"]), 0.0, 0.18)


		g ["war_pressure"] = lerp(float(g ["war_pressure"]), 0.0, 0.22)


		g ["trend"] += randf_range(-0.08, 0.08)
		g ["trend"] = clamp(float(g ["trend"]), 0.65, 1.55)

		goods_market [good_name] = g

	_resolve_all_prices()
	_emit_market_news_if_needed()


func on_era_shift(_payload:= {}):
	_ensure_bootstrapped()

	for good_name in goods_market.keys():
		var g = goods_market [good_name]
		g ["trend"] = 1.0
		g ["war_pressure"] = 0.0
		goods_market [good_name] = g

	_resolve_all_prices()





func on_realm_war(payload: Dictionary):
	_ensure_bootstrapped()

	var attacker_realm_id = payload.get("attacker_realm_id", -1)
	var defender_realm_id = payload.get("defender_realm_id", -1)

	var affected_goods = ["Silk", "Spices", "Gold", "Salt"]

	for good_name in affected_goods:
		if not goods_market.has(good_name):
			continue

		var g = goods_market [good_name]
		g ["war_pressure"] = float(g ["war_pressure"]) + randf_range(0.1, 0.35)
		goods_market [good_name] = g

	_resolve_all_prices()

	var atk_name = _realm_name(attacker_realm_id)
	var def_name = _realm_name(defender_realm_id)

	if atk_name != "" and def_name != "":
		gs.push_world_feed(
			"⚔️ Trade routes tremble as war disrupts commerce between %s and %s." %
			[atk_name, def_name],
			{
				"category": "market",
				"event_name": ActionEventTypes.REALM_WAR,
				"source": "global_market_engine"
			}
		)





func on_trade_executed(payload: Dictionary):
	_ensure_bootstrapped()

	var good_name = payload.get("good_name", "")
	if good_name == "" or not goods_market.has(good_name):
		return

	var quantity = int(payload.get("quantity", 1))
	var g = goods_market [good_name]



	g ["supply_pressure"] = float(g ["supply_pressure"]) + (0.04 * quantity)
	g ["supply_pressure"] = clamp(float(g ["supply_pressure"]), -0.8, 1.8)

	goods_market [good_name] = g
	_resolve_all_prices()





func _resolve_all_prices():
	for good_name in goods_market.keys():
		var g = goods_market [good_name]
		var base_value = float(g ["base_value"])
		var rarity = float(g ["rarity"])
		var era_mod = _era_modifier(good_name)
		var supply_factor = 1.0 - (float(g ["supply_pressure"]) * 0.18)
		var war_factor = 1.0 + float(g ["war_pressure"])
		var trend = float(g ["trend"])

		var final_price = base_value * rarity * era_mod * supply_factor * war_factor * trend
		final_price = clamp(final_price, base_value * 0.35, base_value * 4.25)

		g ["price"] = int(final_price)
		goods_market [good_name] = g


func _era_modifier(good_name: String) -> float:
	if not GOODS_DEFS.has(good_name):
		return 1.0

	var mods = GOODS_DEFS [good_name].get("era_mods", {})

	# Same chassis-runtime hazard as _realm_local_modifier(): during a load gs.era can
	# still be null, and gs.era.name would throw.
	if gs == null or gs.era == null:
		return 1.0

	return float(mods.get(gs.era.name, 1.0))


func _realm_local_modifier(realm_id: int) -> float:
	if realm_id == -1:
		return 1.0

	# FIX: this checked realms.has(realm_id) but not that realm_engine exists. During a
	# load the silk road projection runs against a chassis runtime that has no
	# realm_engine yet, so gs.realm_engine.realms threw "Invalid access to property or
	# key 'realms' on a base object of type 'Nil'" and killed the load. Fall back to
	# the neutral modifier when the engine is not resident yet.
	if gs == null or gs.realm_engine == null:
		return 1.0

	if typeof(gs.realm_engine.realms) != TYPE_DICTIONARY:
		return 1.0

	if not gs.realm_engine.realms.has(realm_id):
		return 1.0

	var realm = gs.realm_engine.realms [realm_id]
	var pop = float(realm.get("population", 100000))
	var land = float(realm.get("land", 200))


	var density = pop / max(land, 1.0)

	if density > 1500:
		return 1.2
	elif density > 900:
		return 1.1
	elif density < 250:
		return 0.9

	return 1.0


func _realm_name(realm_id: int) -> String:
	if realm_id == -1:
		return ""

	if gs == null or gs.realm_engine == null:
		return ""

	if typeof(gs.realm_engine.realms) != TYPE_DICTIONARY:
		return ""

	if not gs.realm_engine.realms.has(realm_id):
		return ""
	return str(gs.realm_engine.realms [realm_id].get("name", ""))


func _emit_market_news_if_needed():
	if randi() % 5 != 0:
		return

	var keys = goods_market.keys()
	if keys.size() == 0:
		return

	var good_name = keys [randi() % keys.size()]
	var price = int(goods_market [good_name] ["price"])

	gs.push_world_feed(
		"📈 Market update: %s now trades for around %d." %
		[good_name, price],
		{
			"category": "market",
			"event_name": "market_update",
			"source": "global_market_engine"
		}
	)