extends Resource
class_name MeatMarketContractEngine

const ENGINE_SCHEMA:= "eralife.market.meat_market_contract_engine"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "meat_market_contract_state"

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()

func market_label_for_actor(actor: Person) -> String:
	if actor == null:
		return "THE MARKET"

	var city_text: String = str(
		actor.home_city
	).strip_edges()

	if city_text == "":
		city_text = "The City"

	var era_name: String = (
		_current_era_name()
		.to_lower()
	)

	if era_name.find("ancient") >= 0:
		return "%s Butchers & Game Market" % city_text

	if era_name.find("medieval") >= 0:
		return "%s Butcher Row" % city_text

	if era_name.find("industrial") >= 0:
		return "%s Meat Exchange" % city_text

	if era_name.find("modern") >= 0:
		return "%s Meat Market" % city_text

	if era_name.find("future") >= 0:
		return "%s Protein Market" % city_text

	return "%s Market" % city_text


func available_in_current_era() -> bool:
	var era_name: String = (
		_current_era_name()
		.to_lower()
	)

	return (
		era_name.find("ancient") >= 0
		or era_name.find("medieval") >= 0
		or era_name.find("industrial") >= 0
		or era_name.find("modern") >= 0
		or era_name.find("future") >= 0
	)
func _market_subtitle_for_current_era() -> String:
	var era_name: String = (
		_current_era_name()
		.to_lower()
	)

	if era_name.find("ancient") >= 0:
		return (
			"Open-air butchers, hunters, fishmongers, game tables, "
			+ "spice smoke, marrow, and animal-feed scraps."
		)

	if era_name.find("medieval") >= 0:
		return (
			"Butcher stalls, game sellers, poulterers, fishmongers, "
			+ "smoked cuts, pies, and working-market scraps."
		)

	if era_name.find("industrial") >= 0:
		return (
			"Fresh cuts, smokehouses, cured meats, fish counters, "
			+ "poultry sellers, tins, and butcher-floor bargains."
		)

	if era_name.find("future") >= 0:
		return (
			"Cultured cuts, printed proteins, heritage clone meats, "
			+ "synthetic seafood, predator feed, and gastrolab stalls."
		)

	return (
		"Fresh butchers, fish counters, specialty cuts, game, "
		+ "prepared meats, and animal-feed stock."
	)
func emit_market_surface_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var listings: Array = _market_listings(
		actor,
		context
	)
	var basket: Array = _basket_for_actor(actor)
	var food_cards: Array = (
		_food_card_contracts_for_listings(
			actor,
			listings,
			basket,
			context
		)
	)
	var basket_total: int = _basket_total(
		basket
	)
	var basket_item_count: int = (
		_basket_item_count(basket)
	)

	return {
		"success": true,
		"schema": "eralife.market.meat_market.surface_contract",
		"version": CONTRACT_VERSION,
		"title": market_label_for_actor(actor),
		"subtitle": _market_subtitle_for_current_era(),
		"era": _current_era_name(),
		"market_year": (
			int(gs.year)
			if gs != null
			else 0
		),
		"truth_state": "hot",
		"layout_contract": {
			"surface": "near_full_screen",
			"panel": "MeatMarketPanel",
			"cards": "aaa_food_mosaic",
			"formation": "scrollable_compact_market_mosaic",
		},
		"currency": _market_currency_contract(),
		"basket_name": "Basket",
		"basket": basket.duplicate(true),
		"basket_total": basket_total,
		"basket_total_text": _format_market_money(
			basket_total
		),
		"basket_count": basket.size(),
		"basket_item_count": basket_item_count,
		"listings": listings.duplicate(true),
		"food_card_contracts": food_cards.duplicate(true),
		"listing_count": listings.size(),
		"resident_publication_policy": (
			"one_already_authored_card_per_quantum"
		),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_pure_renderer": true,
		"ui_is_renderer_only": true
	}
func add_listing_to_basket(
	actor: Person,
	listing_contract: Variant = "",
	quantity_or_context: Variant = 1,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return { "success": false, "reason": "missing_actor"}

	var normalized: Dictionary = _normalize_add_listing_payload(
		listing_contract,
		quantity_or_context,
		context
	)

	var listing_id: String = str(normalized.get("listing_id", "")).strip_edges()
	var listing: Dictionary = _listing_by_id(actor, listing_id, normalized)
	if listing.is_empty():
		return {
			"success": false,
			"reason": "missing_listing",
			"text": "That market item is gone.",
			"popup_title": market_label_for_actor(actor),
			"popup_text": "That market item is gone.",
			"popup_footer": "The market surface can refresh without crashing.",
			"surface_contract": emit_market_surface_contract(actor, { "source": "meat_market.add_missing_listing"})
		}

	var basket: Array = _basket_for_actor(actor)
	var max_affordable: int = _max_affordable_quantity_for_listing(actor, listing, basket)
	if max_affordable <= 0:
		return {
			"success": false,
			"reason": "not_enough_money",
			"text": "You cannot afford %s." % str(listing.get("display_name", "that item")),
			"popup_title": market_label_for_actor(actor),
			"popup_text": "You cannot afford %s." % str(listing.get("display_name", "that item")),
			"popup_footer": "Available balance: %s" % _format_market_money(int(actor.bank_balance)),
			"surface_contract": emit_market_surface_contract(actor, { "source": "meat_market.add_not_enough_money"})
		}

	var requested_count: int = max(1, int(normalized.get("quantity", 1)))
	var count: int = clamp(requested_count, 1, max_affordable)

	var added: Dictionary = listing.duplicate(true)
	added ["quantity"] = count
	added ["line_total"] = int(listing.get("price", 0)) * count
	added ["line_total_text"] = _format_market_money(int(added.get("line_total", 0)))
	added ["added_at_ms"] = int(Time.get_ticks_msec())
	added ["source"] = str(normalized.get("source", "meat_market_contract_engine"))
	basket.append(added)
	_set_basket_for_actor(actor, basket)

	var basket_total: int = _basket_total(basket)
	var basket_item_count: int = _basket_item_count(basket)
	var text: String = "%s x%d was added to your basket." % [
		str(listing.get("display_name", "The item")),
		count
	]
	var surface_contract: Dictionary = emit_market_surface_contract(actor, { "source": "meat_market.add_listing_to_basket"})

	return {
		"success": true,
		"committed": true,
		"text": text,
		"popup_title": market_label_for_actor(actor),
		"popup_text": text,
		"popup_footer": "Basket: %d item(s) - %s" % [basket_item_count, _format_market_money(basket_total)],
		"basket": basket.duplicate(true),
		"basket_total": basket_total,
		"basket_total_text": _format_market_money(basket_total),
		"basket_item_count": basket_item_count,
		"surface_contract": surface_contract.duplicate(true),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}


func checkout_basket(actor: Person, _context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return { "success": false, "reason": "missing_actor"}

	var basket: Array = _basket_for_actor(actor)
	if basket.is_empty():
		return {
			"success": false,
			"text": "Your basket is empty.",
			"reason": "empty_basket",
			"surface_contract": emit_market_surface_contract(actor, { "source": "meat_market.checkout_empty"})
		}

	var total: int = _basket_total(basket)

	if int(actor.bank_balance) < total:
		return {
			"success": false,
			"text": "You need %s to buy everything in your basket." % _format_market_money(total),
			"popup_title": market_label_for_actor(actor),
			"popup_text": "You do not have enough money for the basket.",
			"popup_footer": "Basket total: %s" % _format_market_money(total),
			"reason": "not_enough_money",
			"surface_contract": emit_market_surface_contract(actor, { "source": "meat_market.checkout_not_enough_money"})
		}

	actor.bank_balance -= total

	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		_add_market_item_to_belongings(actor, item)

	_set_basket_for_actor(actor, [])

	var text: String = "You bought meat and market goods for %s." % _format_market_money(total)
	_emit_diary_text(actor, text, { "type": "meat_market_checkout", "total": total})

	return {
		"success": true,
		"committed": true,
		"text": text,
		"diary_text": text,
		"popup_title": market_label_for_actor(actor),
		"popup_text": text,
		"popup_footer": "The food is now in your belongings.",
		"surface_contract": emit_market_surface_contract(actor, { "source": "meat_market.checkout_committed"}),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_pure_renderer": true,
		"ui_is_renderer_only": true
	}

func _normalize_add_listing_payload(
	listing_contract: Variant = "",
	quantity_or_context: Variant = 1,
	context: Dictionary = {}
) -> Dictionary:
	var out: Dictionary = context.duplicate(true)

	if typeof(listing_contract) == TYPE_DICTIONARY:
		var payload: Dictionary = (listing_contract as Dictionary).duplicate(true)
		for key in payload.keys():
			out [key] = payload.get(key)
	elif typeof(listing_contract) == TYPE_STRING or typeof(listing_contract) == TYPE_STRING_NAME:
		out ["listing_id"] = str(listing_contract).strip_edges()
	elif listing_contract != null:
		out ["listing_id"] = str(listing_contract).strip_edges()

	if typeof(quantity_or_context) == TYPE_DICTIONARY:
		var quantity_context: Dictionary = (quantity_or_context as Dictionary).duplicate(true)
		for key in quantity_context.keys():
			out [key] = quantity_context.get(key)
	elif typeof(quantity_or_context) == TYPE_INT or typeof(quantity_or_context) == TYPE_FLOAT:
		out ["quantity"] = int(quantity_or_context)
	elif str(quantity_or_context).strip_edges().is_valid_int():
		out ["quantity"] = int(str(quantity_or_context).strip_edges())

	if not out.has("quantity"):
		out ["quantity"] = 1

	return out


func _food_card_contracts_for_listings(
	actor: Person,
	listings: Array,
	basket: Array,
	context: Dictionary = {}
) -> Array:
	var out: Array = []
	for raw_listing in listings:
		var listing: Dictionary = _safe_dictionary(raw_listing)
		if listing.is_empty():
			continue
		out.append(_food_card_contract_for_listing(actor, listing, basket, context))
	return out


func _food_card_contract_for_listing(
	actor: Person,
	listing: Dictionary,
	basket: Array,
	_context: Dictionary = {}
) -> Dictionary:
	var listing_id: String = str(
		listing.get(
			"listing_id",
			""
		)
	).strip_edges()
	var tags: Array = _safe_array(
		listing.get(
			"tags",
			[]
		)
	).duplicate(true)
	var basket_quantity: int = (
		_listing_in_basket_quantity(
			basket,
			listing_id
		)
	)
	var category: String = str(
		listing.get(
			"category",
			"Food"
		)
	).strip_edges()
	var price: int = int(
		listing.get(
			"price",
			0
		)
	)
	var max_affordable: int = (
		_max_affordable_quantity_for_listing(
			actor,
			listing,
			basket
		)
	)

	return {
		"schema": "eralife.market.meat_market.food_card_contract",
		"version": CONTRACT_VERSION,
		"listing_id": listing_id,
		"title": str(
			listing.get(
				"display_name",
				"Market Food"
			)
		),
		"display_name": str(
			listing.get(
				"display_name",
				"Market Food"
			)
		),
		"description": str(
			listing.get(
				"description",
				""
			)
		),
		"price": price,
		"price_text": _format_market_money(
			price
		),
		"quantity": int(
			listing.get(
				"quantity",
				1
			)
		),
		"category": category,
		"tags": tags,
		"stall": str(
			listing.get(
				"stall",
				"Market Stall"
			)
		),
		"quality": str(
			listing.get(
				"quality",
				"Market Grade"
			)
		),
		"origin": str(
			listing.get(
				"origin",
				"Local Market"
			)
		),
		"mosaic_span": str(
			listing.get(
				"mosaic_span",
				"standard_1x1"
			)
		),
		"bloodthirst_delta": int(
			listing.get(
				"bloodthirst_delta",
				0
			)
		),
		"basket_quantity": basket_quantity,
		"max_affordable_quantity": max_affordable,
		"max_affordable_label": "%s x%d" % [
			str(
				listing.get(
					"display_name",
					"Market Food"
				)
			),
			max_affordable
		],
		"meta_line": (
			_food_card_meta_line(
				listing,
				basket_quantity
			)
		),
		"action_label": (
			"Add To Basket"
			if basket_quantity <= 0
			else "Add Another"
		),
		"disabled": (
			listing_id == ""
			or max_affordable <= 0
		),
		"render_kind": "aaa_food_mosaic_card",
		"currency": (
			_market_currency_contract()
		),
		"truth_source": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _food_card_meta_line(listing: Dictionary, basket_quantity: int = 0) -> String:
	var parts: Array = []
	var quantity: int = int(listing.get("quantity", 1))
	if quantity > 1:
		parts.append("Bundle x%d" % quantity)
	else:
		parts.append("Single portion")

	var tags: Array = _safe_array(listing.get("tags", []))
	if tags.has("pet_food") and tags.has("human_food"):
		parts.append("People + pets")
	elif tags.has("pet_food"):
		parts.append("Pet food")
	elif tags.has("human_food"):
		parts.append("Human food")

	if int(listing.get("bloodthirst_delta", 0)) > 0:
		parts.append("Bloodthirst +%d" % int(listing.get("bloodthirst_delta", 0)))

	if basket_quantity > 0:
		parts.append("In basket x%d" % basket_quantity)

	return " - ".join(parts)


func _listing_in_basket_quantity(basket: Array, listing_id: String) -> int:
	var total: int = 0
	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		if str(item.get("listing_id", "")).strip_edges() == listing_id:
			total += int(item.get("quantity", 1))
	return total


func _basket_total(basket: Array) -> int:
	var total: int = 0
	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		total += int(item.get("line_total", int(item.get("price", 0)) * int(item.get("quantity", 1))))
	return total

func quick_buy_pet_food(actor: Person, food_id: String, context: Dictionary = {}) -> Dictionary:
	var listing: Dictionary = _listing_by_id(actor, food_id, context)
	if listing.is_empty():
		return { "success": false, "reason": "missing_food_listing"}

	var price: int = int(listing.get("price", 0))
	if int(actor.bank_balance) < price:
		return { "success": false, "reason": "not_enough_money", "text": "You cannot afford %s." % str(listing.get("display_name", "that food"))}

	actor.bank_balance -= price
	listing ["quantity"] = int(listing.get("quantity", 1))
	_add_market_item_to_belongings(actor, listing)

	return {
		"success": true,
		"committed": true,
		"text": "You quickly bought %s." % str(listing.get("display_name", "pet food")),
		"item": listing.duplicate(true),
		"commit_authority": ENGINE_SCHEMA
	}
func _basket_item_count(basket: Array) -> int:
	var total: int = 0
	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		total += max(1, int(item.get("quantity", 1)))
	return total


func _max_affordable_quantity_for_listing(actor: Person, listing: Dictionary, basket: Array = []) -> int:
	if actor == null:
		return 0

	var price: int = max(1, int(listing.get("price", 0)))
	var already_reserved: int = _basket_total(basket)
	var available: int = max(0, int(actor.bank_balance) - already_reserved)
	return int(floor(float(available) / float(price)))


func _market_currency_contract() -> Dictionary:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("get_currency"):
		var currency_raw: Variant = gs.economy_engine.get_currency()
		if typeof(currency_raw) == TYPE_DICTIONARY:
			var currency: Dictionary = (currency_raw as Dictionary).duplicate(true)
			return {
				"name": str(currency.get("name", "USD")),
				"symbol": str(currency.get("symbol", "$")),
				"base_unit": int(currency.get("base_unit", 1))
			}

	return {
		"name": "USD",
		"symbol": "$",
		"base_unit": 1
	}


func _format_market_money(amount: int) -> String:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("format_money"):
		return str(gs.economy_engine.format_money(int(amount)))

	var currency: Dictionary = _market_currency_contract()
	return "%s%d %s" % [
		str(currency.get("symbol", "$")),
		int(amount),
		str(currency.get("name", "USD"))
	]
func _market_listings(
	_actor: Person,
	_context: Dictionary = {}
) -> Array:
	var era_name: String = (
		_current_era_name()
		.to_lower()
	)

	if era_name.find("ancient") >= 0:
		return [
			{
				"listing_id": "ancient_goat_cut",
				"display_name": "Fresh Goat Cut",
				"price": 18,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "raw_meat", "human_food", "pet_food"],
				"bloodthirst_delta": 3,
				"stall": "Goat Butcher",
				"quality": "Fresh Cut",
				"origin": "Local Herd",
				"mosaic_span": "wide_2x1",
				"description": "Fresh goat cut from the morning slaughter."
			},
			{
				"listing_id": "ancient_wild_boar",
				"display_name": "Wild Boar Haunch",
				"price": 32,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "game", "raw_meat", "human_food", "pet_food"],
				"bloodthirst_delta": 4,
				"stall": "Hunter's Table",
				"quality": "Prime Game",
				"origin": "Outer Woodlands",
				"mosaic_span": "tall_1x2",
				"description": "Dense wild game brought in from beyond the city."
			},
			{
				"listing_id": "ancient_river_fish",
				"display_name": "River Fish Bundle",
				"price": 12,
				"quantity": 3,
				"category": "Food",
				"tags": ["fish", "meat", "raw_meat", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Fishmonger",
				"quality": "Morning Catch",
				"origin": "River Landing",
				"mosaic_span": "standard_1x1",
				"description": "A bundled morning catch packed over wet reeds."
			},
			{
				"listing_id": "ancient_dried_venison",
				"display_name": "Salted Venison Strips",
				"price": 21,
				"quantity": 4,
				"category": "Food",
				"tags": ["meat", "preserved_food", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Game Preserver",
				"quality": "Travel Grade",
				"origin": "Hill Country",
				"mosaic_span": "standard_1x1",
				"description": "Salted venison prepared to survive a long road."
			},
			{
				"listing_id": "ancient_marrow_bones",
				"display_name": "Marrow Bone Bundle",
				"price": 8,
				"quantity": 4,
				"category": "Food",
				"tags": ["meat", "bones", "pet_food", "scraps"],
				"bloodthirst_delta": 2,
				"stall": "Butcher's End",
				"quality": "Working Cut",
				"origin": "Local Slaughter",
				"mosaic_span": "standard_1x1",
				"description": "Heavy marrow bones for broth or carnivorous companions."
			},
			{
				"listing_id": "ancient_small_prey",
				"display_name": "Hunter's Small Prey",
				"price": 20,
				"quantity": 2,
				"category": "Food",
				"tags": ["prey", "meat", "pet_food"],
				"bloodthirst_delta": 5,
				"stall": "Hunter's Table",
				"quality": "Whole Prey",
				"origin": "Nearby Scrubland",
				"mosaic_span": "wide_2x1",
				"description": "Whole small prey intended for hunting animals and dangerous companions."
			}
		]

	if era_name.find("medieval") >= 0:
		return [
			{
				"listing_id": "medieval_mutton",
				"display_name": "Butchered Mutton",
				"price": 22,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Butcher Row",
				"quality": "Fresh Cut",
				"origin": "Town Pasture",
				"mosaic_span": "wide_2x1",
				"description": "A fresh mutton cut from the town butcher."
			},
			{
				"listing_id": "medieval_venison",
				"display_name": "Noble Venison",
				"price": 44,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "game", "human_food", "pet_food"],
				"bloodthirst_delta": 4,
				"stall": "Licensed Game Seller",
				"quality": "Choice Game",
				"origin": "Estate Woodlands",
				"mosaic_span": "tall_1x2",
				"description": "Choice venison sold through a licensed game stall."
			},
			{
				"listing_id": "medieval_smoked_eel",
				"display_name": "Smoked Eel",
				"price": 16,
				"quantity": 2,
				"category": "Food",
				"tags": ["fish", "prepared_food", "human_food", "pet_food"],
				"bloodthirst_delta": 1,
				"stall": "Fishmonger",
				"quality": "Oak Smoked",
				"origin": "River Quarter",
				"mosaic_span": "standard_1x1",
				"description": "River eel slowly smoked above an oak fire."
			},
			{
				"listing_id": "medieval_salted_pork",
				"display_name": "Salted Pork Slab",
				"price": 28,
				"quantity": 2,
				"category": "Food",
				"tags": ["meat", "preserved_food", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Pork Butcher",
				"quality": "Cellar Cured",
				"origin": "Town Smokehouse",
				"mosaic_span": "standard_1x1",
				"description": "A dense slab of pork cured for cellar storage."
			},
			{
				"listing_id": "medieval_capon",
				"display_name": "Market Capon",
				"price": 26,
				"quantity": 1,
				"category": "Food",
				"tags": ["poultry", "meat", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Poulterer",
				"quality": "Feast Grade",
				"origin": "Village Yard",
				"mosaic_span": "standard_1x1",
				"description": "A dressed capon prepared for a wealthy table."
			},
			{
				"listing_id": "medieval_meat_pie",
				"display_name": "Hot Meat Pie",
				"price": 12,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "prepared_food", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Cooked Stall",
				"quality": "Hot",
				"origin": "Market Oven",
				"mosaic_span": "standard_1x1",
				"description": "A hot market pie filled with seasoned minced meat."
			}
		]

	if era_name.find("industrial") >= 0:
		return [
			{
				"listing_id": "industrial_beef_cut",
				"display_name": "Butcher's Beef Cut",
				"price": 30,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "raw_meat", "human_food", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Prime Butcher",
				"quality": "Prime",
				"origin": "Regional Stockyard",
				"mosaic_span": "wide_2x1",
				"description": "A marbled beef cut arriving through the regional stockyard."
			},
			{
				"listing_id": "industrial_cured_ham",
				"display_name": "Smokehouse Ham",
				"price": 38,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "prepared_food", "human_food"],
				"bloodthirst_delta": 1,
				"stall": "Smokehouse",
				"quality": "Long Cured",
				"origin": "Warehouse District",
				"mosaic_span": "tall_1x2",
				"description": "A long-cured ham from a commercial city smokehouse."
			},
			{
				"listing_id": "industrial_sausage_bundle",
				"display_name": "Butcher Sausage Bundle",
				"price": 18,
				"quantity": 6,
				"category": "Food",
				"tags": ["meat", "prepared_food", "human_food", "pet_food"],
				"bloodthirst_delta": 1,
				"stall": "Sausage Counter",
				"quality": "Daily Batch",
				"origin": "Local Butcher",
				"mosaic_span": "standard_1x1",
				"description": "A tied bundle of the butcher's daily sausage batch."
			},
			{
				"listing_id": "industrial_smoked_fish",
				"display_name": "Smoked Fish Parcel",
				"price": 20,
				"quantity": 3,
				"category": "Food",
				"tags": ["fish", "prepared_food", "human_food", "pet_food"],
				"bloodthirst_delta": 1,
				"stall": "Fish Counter",
				"quality": "Rail Fresh",
				"origin": "Coastal Freight",
				"mosaic_span": "standard_1x1",
				"description": "Smoked fish brought inland through the rail network."
			},
			{
				"listing_id": "industrial_tinned_beef",
				"display_name": "Tinned Corned Beef",
				"price": 11,
				"quantity": 2,
				"category": "Food",
				"tags": ["meat", "preserved_food", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Provisioner",
				"quality": "Shelf Stable",
				"origin": "Packing Works",
				"mosaic_span": "standard_1x1",
				"description": "Factory-packed corned beef intended for long storage."
			},
			{
				"listing_id": "industrial_butcher_scraps",
				"display_name": "Butcher Floor Scraps",
				"price": 7,
				"quantity": 5,
				"category": "Food",
				"tags": ["meat", "scraps", "pet_food"],
				"bloodthirst_delta": 2,
				"stall": "Back Counter",
				"quality": "Animal Feed",
				"origin": "Local Butcher",
				"mosaic_span": "wide_2x1",
				"description": "Cheap trimmings sold for working dogs and other carnivores."
			}
		]

	if era_name.find("future") >= 0:
		return [
			{
				"listing_id": "future_cultured_wagyu",
				"display_name": "Cultured Wagyu Reserve",
				"price": 92,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "cultured_meat", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Culture Atelier",
				"quality": "Reserve Grade",
				"origin": "Myocyte Cellar 7",
				"mosaic_span": "wide_2x1",
				"description": "A precisely marbled cultured cut matured without a slaughtered animal."
			},
			{
				"listing_id": "future_printed_salmon",
				"display_name": "Printed Wild-Salmon Matrix",
				"price": 58,
				"quantity": 2,
				"category": "Food",
				"tags": ["fish", "printed_protein", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Oceanless Fishmonger",
				"quality": "Wild Profile",
				"origin": "Pelagic Genome Bank",
				"mosaic_span": "tall_1x2",
				"description": "Printed salmon tissue reconstructed from a protected wild genome."
			},
			{
				"listing_id": "future_clone_venison",
				"display_name": "Heritage Clone Venison",
				"price": 74,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "cultured_meat", "game", "human_food"],
				"bloodthirst_delta": 1,
				"stall": "Heritage Protein House",
				"quality": "Archive Lineage",
				"origin": "Cervid Genome Archive",
				"mosaic_span": "wide_2x1",
				"description": "Venison grown from a preserved heritage cervid lineage."
			},
			{
				"listing_id": "future_synth_fowl",
				"display_name": "Synth-Fowl Breast",
				"price": 34,
				"quantity": 2,
				"category": "Food",
				"tags": ["meat", "synthetic_protein", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Everyday Protein",
				"quality": "Domestic Premium",
				"origin": "Municipal Protein Works",
				"mosaic_span": "standard_1x1",
				"description": "An everyday engineered poultry analogue with controlled texture."
			},
			{
				"listing_id": "future_predator_feed",
				"display_name": "Predator Feeding Pack",
				"price": 46,
				"quantity": 4,
				"category": "Food",
				"tags": ["meat", "pet_food", "predator_feed"],
				"bloodthirst_delta": 5,
				"stall": "Companion Nutrition",
				"quality": "High Iron",
				"origin": "Fauna Nutrition Lab",
				"mosaic_span": "standard_1x1",
				"description": "A high-iron feeding pack for large carnivorous companions."
			},
			{
				"listing_id": "future_gastrolab_roast",
				"display_name": "Gastrolab Sunday Roast",
				"price": 66,
				"quantity": 1,
				"category": "Food",
				"tags": ["meat", "prepared_food", "human_food"],
				"bloodthirst_delta": 0,
				"stall": "Gastrolab",
				"quality": "Chef Finished",
				"origin": "On-Site Culture Kitchen",
				"mosaic_span": "standard_1x1",
				"description": "A chef-finished cultured roast engineered to reproduce an old family meal."
			}
		]


	return [
		{
			"listing_id": "modern_prime_ribeye",
			"display_name": "Prime Ribeye",
			"price": 48,
			"quantity": 1,
			"category": "Food",
			"tags": ["meat", "raw_meat", "human_food"],
			"bloodthirst_delta": 1,
			"stall": "Prime Beef Counter",
			"quality": "Prime",
			"origin": "Regional Ranch",
			"mosaic_span": "wide_2x1",
			"description": "A heavily marbled prime ribeye cut to order."
		},
		{
			"listing_id": "modern_salmon",
			"display_name": "Atlantic Salmon Fillets",
			"price": 32,
			"quantity": 2,
			"category": "Food",
			"tags": ["fish", "raw_meat", "human_food", "pet_food"],
			"bloodthirst_delta": 1,
			"stall": "Seafood Counter",
			"quality": "Fresh",
			"origin": "Cold Chain",
			"mosaic_span": "tall_1x2",
			"description": "Fresh salmon portions held behind the market's chilled seafood glass."
		},
		{
			"listing_id": "modern_lamb_chops",
			"display_name": "French-Cut Lamb Chops",
			"price": 42,
			"quantity": 4,
			"category": "Food",
			"tags": ["meat", "raw_meat", "human_food"],
			"bloodthirst_delta": 1,
			"stall": "Specialty Butcher",
			"quality": "Premium",
			"origin": "Domestic Farm",
			"mosaic_span": "standard_1x1",
			"description": "French-cut lamb chops prepared behind the specialty counter."
		},
		{
			"listing_id": "modern_ground_beef",
			"display_name": "Fresh Ground Beef",
			"price": 18,
			"quantity": 2,
			"category": "Food",
			"tags": ["meat", "raw_meat", "human_food", "pet_food"],
			"bloodthirst_delta": 1,
			"stall": "Daily Butcher",
			"quality": "Ground Today",
			"origin": "Local Processor",
			"mosaic_span": "standard_1x1",
			"description": "Ground beef prepared in-house during today's market service."
		},
		{
			"listing_id": "modern_charcuterie",
			"display_name": "House Charcuterie Board",
			"price": 52,
			"quantity": 1,
			"category": "Food",
			"tags": ["meat", "prepared_food", "human_food"],
			"bloodthirst_delta": 0,
			"stall": "Cured Counter",
			"quality": "House Selection",
			"origin": "Domestic + Imported",
			"mosaic_span": "wide_2x1",
			"description": "A rotating selection of cured meats assembled from the market's premium counter."
		},
		{
			"listing_id": "modern_raw_pet_blend",
			"display_name": "Raw Carnivore Blend",
			"price": 24,
			"quantity": 4,
			"category": "Food",
			"tags": ["meat", "raw_meat", "pet_food"],
			"bloodthirst_delta": 4,
			"stall": "Companion Freezer",
			"quality": "Pet Nutrition",
			"origin": "Market Butcher",
			"mosaic_span": "standard_1x1",
			"description": "A frozen raw-meat blend prepared for carnivorous companion diets."
		}
	]

func _listing_by_id(actor: Person, listing_id: String, context: Dictionary = {}) -> Dictionary:
	for raw_listing in _market_listings(actor, context):
		var listing: Dictionary = _safe_dictionary(raw_listing)
		if str(listing.get("listing_id", "")) == listing_id:
			return listing.duplicate(true)
	return {}

func _add_market_item_to_belongings(actor: Person, item: Dictionary) -> void:
	if gs == null or actor == null or gs.belongings_engine == null:
		return

	var item_id: int = int(Time.get_ticks_usec())
	if "next_id" in gs:
		item_id = int(gs.next_id)
		gs.next_id += 1

	gs.belongings_engine.add_item(actor, {
		"id": item_id,
		"name": str(item.get("display_name", item.get("name", "Market Food"))),
		"display_name": str(item.get("display_name", item.get("name", "Market Food"))),
		"type": "Food",
		"quantity": int(item.get("quantity", 1)),
		"stackable": true,
		"tags": _safe_array(item.get("tags", [])).duplicate(true),
		"bloodthirst_delta": int(item.get("bloodthirst_delta", 0)),
		"description": str(item.get("description", "")),
		"lore": "Bought from %s in %s." % [market_label_for_actor(actor), _format_year_value(int(gs.year if gs != null else 0))]
	}, "Food")

func _basket_for_actor(actor: Person) -> Array:
	var state: Dictionary = _state()
	var baskets: Dictionary = _safe_dictionary(state.get("baskets", {}))
	return _safe_array(baskets.get(str(int(actor.id)), [])).duplicate(true)

func _set_basket_for_actor(actor: Person, basket: Array) -> void:
	var state: Dictionary = _state()
	var baskets: Dictionary = _safe_dictionary(state.get("baskets", {}))
	baskets [str(int(actor.id))] = basket.duplicate(true)
	state ["baskets"] = baskets
	_set_state(state)

func _emit_diary_text(actor: Person, text: String, meta: Dictionary = {}) -> void:
	if gs == null or actor == null or gs.life_diary_contract_engine == null:
		return
	if not gs.life_diary_contract_engine.has_method("emit_diary_intent"):
		return

	gs.life_diary_contract_engine.emit_diary_intent({
		"type": "meat_market",
		"actor_id": int(actor.id),
		"lines": str(text).split("\n"),
		"source": ENGINE_SCHEMA,
		"preserve_lines_exactly": true,
		"meta": meta.duplicate(true)
	}, { "source": ENGINE_SCHEMA})

func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if typeof(gs.scenario_state.get(STATE_KEY, {})) != TYPE_DICTIONARY:
		gs.scenario_state [STATE_KEY] = {
			"schema": "eralife.meat_market_state",
			"version": CONTRACT_VERSION,
			"baskets": {}
		}

func _state() -> Dictionary:
	_ensure_state()
	return _safe_dictionary(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)

func _set_state(state: Dictionary) -> void:
	if gs == null:
		return
	gs.scenario_state [STATE_KEY] = state.duplicate(true)

func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.get("name", gs.era.get("id", ""))) if typeof(gs.era) == TYPE_DICTIONARY else str(gs.era.name)
	return "modern"

func _format_year_value(year_value: int) -> String:
	if year_value < 0:
		return "%d BCE" % abs(year_value)
	return "%d CE" % year_value

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []