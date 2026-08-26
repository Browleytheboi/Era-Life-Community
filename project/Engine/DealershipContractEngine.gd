extends Resource
class_name DealershipContractEngine

const ENGINE_SCHEMA:= "eralife.market.dealership_contract_engine"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "dealership_contract_state"
var surface_deck_cache: Dictionary = {}
var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()
func reset_runtime() -> void:
	if (
		gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return

	gs.scenario_state.erase(STATE_KEY)


func _asset_catalog_expansion() -> EraLifeAssetCatalogExpansion:
	if gs == null:
		return null

	if gs.era_life_asset_catalog_expansion == null:
		gs.era_life_asset_catalog_expansion = EraLifeAssetCatalogExpansion.new(
			gs
		)
	elif gs.era_life_asset_catalog_expansion.has_method(
		"bind_game_state"
	):
		gs.era_life_asset_catalog_expansion.bind_game_state(
			gs
		)

	return gs.era_life_asset_catalog_expansion


func _dealership_state() -> Dictionary:
	_ensure_state()

	if gs == null:
		return {}

	var state_raw: Variant = gs.scenario_state.get(
		STATE_KEY,
		{}
	)

	if typeof(state_raw) != TYPE_DICTIONARY:
		return {}

	return state_raw as Dictionary


func _selected_dealership_id_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return ""

	var state: Dictionary = _dealership_state()
	var selected_raw: Variant = state.get(
		"selected_dealership_by_actor",
		{}
	)
	var selected: Dictionary = (
		selected_raw as Dictionary
		if typeof(selected_raw) == TYPE_DICTIONARY
		else {}
	)

	return str(
		selected.get(int(actor.id), "")
	).strip_edges()


func _set_selected_dealership_id_for_actor(
	actor: Person,
	dealership_id: String
) -> void:
	if actor == null or gs == null:
		return

	var state: Dictionary = _dealership_state()
	var selected_raw: Variant = state.get(
		"selected_dealership_by_actor",
		{}
	)
	var selected: Dictionary = (
		selected_raw as Dictionary
		if typeof(selected_raw) == TYPE_DICTIONARY
		else {}
	)
	var clean_id: String = str(
		dealership_id
	).strip_edges()

	if clean_id == "":
		selected.erase(int(actor.id))
	else:
		selected [int(actor.id)] = clean_id

	state ["selected_dealership_by_actor"] = selected
	state ["last_selected_actor_id"] = int(actor.id)
	state ["last_selected_dealership_id"] = clean_id
	state ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [STATE_KEY] = state

func emit_market_surface_deck(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var policy: Dictionary = (
		_dealership_selector_policy()
	)
	var selector_available: bool = bool(
		policy.get(
			"selector_available",
			false
		)
	)
	var deck_key: String = (
		"%d|%s|%s|%d|bank:%d"
		% [
			int(
				actor.id
			),
			_current_era_name().to_lower(),
			_current_reality_mode_key(),
			_current_year(),
			int(
				actor.bank_balance
			)
		]
	)
	var force_rebuild: bool = bool(
		context.get(
			"force_rebuild",
			false
		)
	)

	if (
		not force_rebuild
		and surface_deck_cache.has(
			deck_key
		)
	):
		var cached: Dictionary = _safe_dictionary(
			surface_deck_cache.get(
				deck_key,
				{}
			)
		)

		cached [
			"cache_hit"
		] = true
		cached [
			"requested_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		return cached

	var surfaces: Dictionary = {}
	var ordered_surface_keys: Array = []
	var default_surface_key: String = ""

	if not selector_available:
		var inventory_context: Dictionary = (
			context.duplicate(true)
		)

		inventory_context [
			"selected_dealership_id"
		] = ""
		inventory_context [
			"building_surface_deck"
		] = true
		inventory_context [
			"dealership_selector_available"
		] = false

		var inventory_contract: Dictionary = (
			emit_market_surface_contract(
				actor,
				inventory_context
			)
		)

		surfaces [
			"inventory"
		] = inventory_contract.duplicate(
			true
		)
		ordered_surface_keys.append(
			"inventory"
		)
		default_surface_key = "inventory"
	else:
		var selector_context: Dictionary = (
			context.duplicate(true)
		)

		selector_context [
			"selected_dealership_id"
		] = ""
		selector_context [
			"building_surface_deck"
		] = true
		selector_context [
			"dealership_selector_available"
		] = true

		var selector_contract: Dictionary = (
			emit_market_surface_contract(
				actor,
				selector_context
			)
		)

		surfaces [
			"selector"
		] = selector_contract.duplicate(
			true
		)
		ordered_surface_keys.append(
			"selector"
		)
		default_surface_key = "selector"

		var dealership_contracts: Array = _safe_array(
			selector_contract.get(
				"dealership_contracts",
				[]
			)
		)

		for raw_dealership in dealership_contracts:
			if typeof(
				raw_dealership
			) != TYPE_DICTIONARY:
				continue

			var dealership: Dictionary = (
				raw_dealership as Dictionary
			)
			var dealership_id: String = str(
				dealership.get(
					"dealership_id",
					dealership.get(
						"id",
						""
					)
				)
			).strip_edges()

			if dealership_id == "":
				continue

			var inventory_context: Dictionary = (
				context.duplicate(true)
			)

			inventory_context [
				"selected_dealership_id"
			] = dealership_id
			inventory_context [
				"selected_dealership_contract"
			] = dealership.duplicate(
				true
			)
			inventory_context [
				"building_surface_deck"
			] = true
			inventory_context [
				"dealership_selector_available"
			] = true

			var inventory_contract: Dictionary = (
				emit_market_surface_contract(
					actor,
					inventory_context
				)
			)
			var surface_key: String = (
				"dealership:%s"
				% dealership_id
			)

			surfaces [
				surface_key
			] = inventory_contract.duplicate(
				true
			)
			ordered_surface_keys.append(
				surface_key
			)

	var deck: Dictionary = {
		"success": true,
		"schema": (
			"eralife.market.vehicle_market.surface_deck"
		),
		"version": CONTRACT_VERSION,
		"actor_id": int(
			actor.id
		),
		"era": _current_era_name(),
		"reality_mode": (
			_current_reality_mode_key()
		),
		"market_year": _current_year(),
		"surface_deck_key": deck_key,
		"default_surface_key": (
			default_surface_key
		),
		"ordered_surface_keys": (
			ordered_surface_keys
		),
		"surfaces": surfaces,
		"surface_count": surfaces.size(),
		"dealership_selector_available": (
			selector_available
		),
		"dealership_selector_policy": str(
			policy.get(
				"policy",
				""
			)
		),
		"truth_state": (
			"hot"
			if not surfaces.is_empty()
			else "observable_partial"
		),
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"cache_hit": false
	}

	surface_deck_cache [
		deck_key
	] = deck.duplicate(
		true
	)

	return deck
func _dealership_selector_policy() -> Dictionary:
	var era_key: String = str(
		_current_era_name()
	).strip_edges().to_lower()

	if era_key.contains(
		"ancient"
	):
		return {
			"selector_available": false,
			"visible_dealership_limit": 0,
			"policy": "ancient_direct_market"
		}

	if era_key.contains(
		"medieval"
	):
		return {
			"selector_available": false,
			"visible_dealership_limit": 0,
			"policy": "medieval_direct_market"
		}

	if era_key.contains(
		"industrial"
	):
		return {
			"selector_available": true,
			"visible_dealership_limit": 4,
			"policy": "industrial_limited_dealerships"
		}

	return {
		"selector_available": true,
		"visible_dealership_limit": 0,
		"policy": "full_dealership_market"
	}


func _current_reality_mode_key() -> String:
	if gs == null:
		return "chaos"

	return str(
		gs.reality_mode
	).strip_edges().to_lower()
func _dealership_contracts_for_actor(
	actor: Person
) -> Array:
	var catalog:= _asset_catalog_expansion()

	if catalog == null:
		return []

	var policy: Dictionary = (
		_dealership_selector_policy()
	)

	if not bool(
		policy.get(
			"selector_available",
			false
		)
	):
		return []

	var contracts: Array = (
		catalog.dealership_contracts_for_actor(
			actor,
			{
				"source": ENGINE_SCHEMA
			}
		)
	)
	var visible_limit: int = maxi(
		0,
		int(
			policy.get(
				"visible_dealership_limit",
				0
			)
		)
	)

	if (
		visible_limit > 0
		and contracts.size() > visible_limit
	):
		contracts = contracts.slice(
			0,
			visible_limit
		)

	return contracts


func _dealership_contract_by_id(
	actor: Person,
	dealership_id: String
) -> Dictionary:
	var clean_id: String = str(
		dealership_id
	).strip_edges()

	if clean_id == "":
		return {}

	for raw_contract in _dealership_contracts_for_actor(
		actor
	):
		var contract: Dictionary = _safe_dictionary(
			raw_contract
		)

		if str(
			contract.get("dealership_id", "")
		) == clean_id:
			return contract

	return {}

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

	var catalog:= _asset_catalog_expansion()
	var selector_policy: Dictionary = (
		_dealership_selector_policy()
	)
	var selector_available: bool = bool(
		selector_policy.get(
			"selector_available",
			false
		)
	)
	var dealership_contracts: Array = (
		_dealership_contracts_for_actor(
			actor
		)
	)
	var selected_dealership_id: String = str(
		context.get(
			"selected_dealership_id",
			_selected_dealership_id_for_actor(
				actor
			)
		)
	).strip_edges()
	var selected_dealership: Dictionary = {}

	if selected_dealership_id != "":
		selected_dealership = (
			_dealership_contract_by_id(
				actor,
				selected_dealership_id
			)
		)

	if (
		selected_dealership_id != ""
		and selected_dealership.is_empty()
	):
		_set_selected_dealership_id_for_actor(
			actor,
			""
		)
		selected_dealership_id = ""

	var era_name: String = (
		_current_era_name()
	)
	var filter_contracts: Array = (
		catalog.vehicle_filter_contracts()
		if catalog != null
		else []
	)

	if (
		selected_dealership_id == ""
		and selector_available
	):
		return {
			"success": true,
			"schema": (
				"eralife.market.vehicle_market.surface_contract"
			),
			"version": CONTRACT_VERSION,
			"surface_mode": "dealership_selector",
			"title": (
				"CHOOSE A DEALERSHIP • %s"
				% era_name
			),
			"subtitle": (
				"Select an era-valid mobility house "
				+ "before viewing inventory."
			),
			"era": era_name,
			"reality_mode": (
				_current_reality_mode_key()
			),
			"market_year": _current_year(),
			"truth_state": "hot",
			"status_text": (
				"Dealership categories are contract-driven "
				+ "and visible at one glance."
			),
			"layout_contract": {
				"surface": "near_full_screen",
				"panel": "VehicleMarketPanel",
				"selector": "compact_aaa_multigrid",
				"cards": "mobility_contract_cards",
			},
			"currency": _market_currency_contract(),
			"dealership_contracts": dealership_contracts,
			"selected_dealership_id": "",
			"selected_dealership_contract": {},
			"filter_contracts": filter_contracts,
			"listing_card_contracts": [],
			"listing_count": 0,
			"commit_authority": ENGINE_SCHEMA,
			"ui_is_pure_renderer": true,
			"ui_is_renderer_only": true,
			"dealership_selector_available": true,
			"dealership_selector_policy": str(
				selector_policy.get(
					"policy",
					""
				)
			),
		}

	var listing_context: Dictionary = (
		context.duplicate(true)
	)

	listing_context [
		"selected_dealership_id"
	] = selected_dealership_id
	listing_context [
		"selected_dealership_contract"
	] = selected_dealership.duplicate(
		true
	)
	listing_context [
		"include_owned_portfolio_rows"
	] = true

	var rows: Array = (
		_vehicle_rows_for_actor(
			actor,
			listing_context
		)
	)
	var cards: Array = []

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if row.is_empty():
			continue

		cards.append(
			_vehicle_card_contract(
				actor,
				row,
				listing_context
			)
		)

	var title_text: String = (
		"VEHICLE MARKET • %s"
		% era_name
	)

	if not selected_dealership.is_empty():
		title_text = str(
			selected_dealership.get(
				"name",
				title_text
			)
		).to_upper()

	var surface_contract: Dictionary = {
		"success": true,
		"schema": (
			"eralife.market.vehicle_market.surface_contract"
		),
		"version": CONTRACT_VERSION,
		"surface_mode": "inventory",
		"title": title_text,
		"subtitle": (
			"Mobility contracts expose facts; "
			+ "the panel never defines brands, "
			+ "vehicles, or availability."
		),
		"era": era_name,
		"reality_mode": (
			_current_reality_mode_key()
		),
		"market_year": _current_year(),
		"truth_state": (
			"hot"
			if not cards.is_empty()
			else "observable_partial"
		),
		"status_text": str(
			context.get(
				"status_text",
				""
			)
		),
		"layout_contract": {
			"surface": "near_full_screen",
			"panel": "VehicleMarketPanel",
			"cards": "mobility_contract_cards",
			"filters": "contract_driven",
		},
		"currency": _market_currency_contract(),
		"dealership_mode": (
			selected_dealership_id != ""
		),
		"dealership_selector_available": (
			selector_available
		),
		"dealership_selector_policy": str(
			selector_policy.get(
				"policy",
				""
			)
		),
		"dealership_contracts": (
			dealership_contracts
		),
		"selected_dealership_id": (
			selected_dealership_id
		),
		"selected_dealership_contract": (
			selected_dealership.duplicate(
				true
			)
		),
		"filter_contracts": filter_contracts,
		"mobility_field_contract": [
			"name",
			"price",
			"movement_type",
			"seats",
			"era",
			"terrain",
			"fuel",
			"monthly_cost",
			"ownership_status",
			"availability",
			"dealer",
			"condition"
		],
		"listing_card_contracts": cards,
		"listing_count": cards.size(),
		"selected_template_id": str(
			context.get(
				"selected_template_id",
				""
			)
		),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_pure_renderer": true,
		"ui_is_renderer_only": true,
	}

	if gs != null:
		if gs.card_contract_engine == null:
			gs.card_contract_engine = (
				CardContractEngine.new(
					gs
				)
			)
		elif gs.card_contract_engine.has_method(
			"bind_game_state"
		):
			gs.card_contract_engine.bind_game_state(
				gs
			)

		if (
			gs.card_contract_engine != null
			and gs.card_contract_engine.has_method(
				"project_market_surface"
			)
		):
			return (
				gs.card_contract_engine.project_market_surface(
					"vehicle",
					actor,
					surface_contract,
					listing_context
				)
			)

	return surface_contract

func commit_listing_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var listing_id: String = str(
		payload.get("listing_id", "")
	).strip_edges()
	var action_id: String = str(
		payload.get(
			"market_action",
			payload.get("action_id", "")
		)
	).strip_edges()

	if action_id == "select_dealership":
		var dealership_id: String = listing_id.trim_prefix(
			"dealership:"
		)
		var dealership: Dictionary = _dealership_contract_by_id(
			actor,
			dealership_id
		)

		if dealership.is_empty():
			return _result_with_surface(
				actor,
				false,
				"That dealership is not available in this era or reality mode.",
				payload
			)

		_set_selected_dealership_id_for_actor(
			actor,
			dealership_id
		)

		var refreshed_context: Dictionary = payload.duplicate(true)
		refreshed_context ["selected_dealership_id"] = dealership_id

		return _result_with_surface(
			actor,
			true,
			"You entered %s." % str(
				dealership.get(
					"name",
					"the dealership"
				)
			),
			refreshed_context
		)

	if action_id == "clear_dealership":
		_set_selected_dealership_id_for_actor(
			actor,
			""
		)

		var selector_context: Dictionary = payload.duplicate(true)
		selector_context ["selected_dealership_id"] = ""

		return _result_with_surface(
			actor,
			true,
			"You returned to the dealership directory.",
			selector_context
		)

	var listing_context: Dictionary = payload.duplicate(true)
	var active_dealership_id: String = _selected_dealership_id_for_actor(
		actor
	)

	if active_dealership_id != "":
		listing_context ["selected_dealership_id"] = active_dealership_id
		listing_context ["selected_dealership_contract"] = (
			_dealership_contract_by_id(
				actor,
				active_dealership_id
			)
		)

	var listing: Dictionary = _listing_by_id(
		actor,
		listing_id,
		listing_context
	)
	if listing.is_empty():
		return _result_with_surface(
			actor,
			false,
			"That vehicle listing is no longer visible.",
			listing_context
		)

	listing = _vehicle_listing_with_selected_variation(
		listing,
		payload
	)

	match action_id:
		"inspect":
			return _result_with_surface(
				actor,
				true,
				_vehicle_inspection_text(listing),
				listing_context
			)

		"buy_vehicle":
			return _buy_vehicle(
				actor,
				listing,
				listing_context
			)

		"finance_vehicle":
			return _finance_vehicle(
				actor,
				listing,
				listing_context
			)

		"lease_vehicle":
			return _lease_vehicle(
				actor,
				listing,
				listing_context
			)

		_:
			return _result_with_surface(
				actor,
				false,
				"That vehicle action is not available.",
				listing_context
			)


func _buy_vehicle(
	actor: Person,
	listing: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if bool(listing.get("living_transport", false)):
		return _buy_living_transport(
			actor,
			listing,
			context
		)

	if gs == null or gs.vehicle_engine == null:
		return _result_with_surface(
			actor,
			false,
			"VehicleEngine is unavailable.",
			context
		)

	var template_id: String = str(
		listing.get("template_id", "")
	).strip_edges()
	var price: int = int(
		listing.get("price", 0)
	)
	var result: Dictionary = gs.vehicle_engine.buy_vehicle(
		actor,
		"template:%s" % template_id,
		price,
		int(listing.get("luxury_level", 0)),
		_purchase_context_from_listing(
			listing,
			"buy_vehicle",
			context
		)
	)

	return _result_with_surface(
		actor,
		bool(result.get("success", false)),
		str(
			result.get(
				"text",
				"Vehicle purchase resolved."
			)
		),
		context
	)
func _buy_living_transport(
	actor: Person,
	listing: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if gs == null or gs.vehicle_engine == null:
		return _result_with_surface(
			actor,
			false,
			"VehicleEngine is unavailable.",
			context
		)

	var price: int = int(
		listing.get("price", 0)
	)

	if int(actor.bank_balance) < price:
		return _result_with_surface(
			actor,
			false,
			"You need %s to acquire this living mount." % _format_money(
				price
			),
			context
		)

	var entity: Dictionary = {}
	var animal_species_id: String = str(
		listing.get("animal_species_id", "")
	).strip_edges()
	var mythical_species_id: String = str(
		listing.get("mythical_species_id", "")
	).strip_edges()
	var entity_context: Dictionary = {
		"source": ENGINE_SCHEMA,
		"name": str(
			listing.get(
				"model",
				listing.get("display_name", "")
			)
		),
		"mobility_template_id": str(
			listing.get("template_id", "")
		)
	}

	if (
		mythical_species_id != ""
		and gs.mythical_contract_engine != null
	):
		entity = gs.mythical_contract_engine.create_mythical_entity(
			mythical_species_id,
			int(actor.id),
			entity_context
		)
	elif (
		animal_species_id != ""
		and gs.animal_contract_engine != null
	):
		entity = gs.animal_contract_engine.create_animal_entity(
			animal_species_id,
			int(actor.id),
			entity_context
		)

	if entity.is_empty():
		return _result_with_surface(
			actor,
			false,
			"The living mobility entity could not be resolved by its animal authority.",
			context
		)

	var purchase_context: Dictionary = _purchase_context_from_listing(
		listing,
		"buy_vehicle"
	)
	var template: Dictionary = gs.vehicle_engine._resolve_vehicle_template(
		"template:%s" % str(
			listing.get("template_id", "")
		),
		int(listing.get("luxury_level", 0)),
		purchase_context
	)

	if template.is_empty():
		return _result_with_surface(
			actor,
			false,
			"The mobility wrapper could not be resolved.",
			context
		)

	actor.bank_balance -= price

	var vehicle: Dictionary = gs.vehicle_engine._build_runtime_vehicle_from_template(
		template,
		actor,
		purchase_context
	)
	vehicle ["linked_entity_id"] = str(
		entity.get("entity_id", "")
	)
	vehicle ["linked_entity_kind"] = str(
		entity.get("entity_kind", "animal")
	)
	vehicle ["condition_applicable"] = false
	vehicle ["condition_label"] = "Living"
	vehicle ["condition"] = 100.0
	vehicle ["value"] = price
	vehicle ["worth"] = price
	vehicle ["acquisition_value"] = price
	vehicle ["source_engine"] = ENGINE_SCHEMA

	gs.vehicle_engine._register_vehicle_for_owner(
		actor,
		vehicle,
		false
	)

	return _result_with_surface(
		actor,
		true,
		"You acquired %s as a living mobility companion." % str(
			listing.get(
				"display_name",
				"the mount"
			)
		),
		context
	)


func _finance_vehicle(actor: Person, listing: Dictionary, context: Dictionary = {}) -> Dictionary:
	var price: int = int(listing.get("price", 0))
	var down_payment: int = int(listing.get("finance_down_payment", max(1, int(round(float(price) * 0.12)))))
	var monthly_payment: int = int(listing.get("finance_monthly_payment", max(1, int(round(float(price) * 0.018)))))

	if int(actor.bank_balance) < down_payment:
		return _result_with_surface(actor, false, "You need %s down to finance this vehicle." % _format_money(down_payment), context)

	if gs == null or gs.vehicle_engine == null:
		return _result_with_surface(actor, false, "VehicleEngine is unavailable.", context)

	actor.bank_balance -= down_payment

	var template_id: String = str(listing.get("template_id", "")).strip_edges()
	var template: Dictionary = gs.vehicle_engine._resolve_vehicle_template("template:%s" % template_id, int(listing.get("luxury_level", 0)), _purchase_context_from_listing(listing, "finance_vehicle"))
	if template.is_empty():
		return _result_with_surface(actor, false, "That financing offer could not be resolved.", context)

	var vehicle: Dictionary = gs.vehicle_engine._build_runtime_vehicle_from_template(template, actor, _purchase_context_from_listing(listing, "finance_vehicle", context))
	vehicle ["legal_status"] = "financed"
	vehicle ["value"] = price
	vehicle ["worth"] = price
	vehicle ["finance_contract"] = {
		"principal": max(0, price - down_payment),
		"down_payment": down_payment,
		"monthly_payment": monthly_payment,
		"started_year": _current_year(),
		"borrower_id": int(actor.id),
		"dealership_tier": str(listing.get("dealership_tier", "standard"))
	}
	vehicle ["brand"] = str(listing.get("brand", "Era Motors"))
	vehicle ["model"] = str(listing.get("model", listing.get("display_name", "Vehicle")))
	vehicle ["source_engine"] = ENGINE_SCHEMA
	gs.vehicle_engine._register_vehicle_for_owner(actor, vehicle, false)

	var text: String = "You financed %s. Down payment: %s. Monthly payment: %s." % [
		str(listing.get("display_name", "the vehicle")),
		_format_money(down_payment),
		_format_money(monthly_payment)
	]
	return _result_with_surface(actor, true, text, context)


func _lease_vehicle(actor: Person, listing: Dictionary, context: Dictionary = {}) -> Dictionary:
	var price: int = int(listing.get("price", 0))
	var lease_due: int = int(listing.get("lease_due_today", max(1, int(round(float(price) * 0.045)))))
	var monthly_payment: int = int(listing.get("lease_monthly_payment", max(1, int(round(float(price) * 0.011)))))

	if int(actor.bank_balance) < lease_due:
		return _result_with_surface(actor, false, "You need %s due today to lease this vehicle." % _format_money(lease_due), context)

	if gs == null or gs.vehicle_engine == null:
		return _result_with_surface(actor, false, "VehicleEngine is unavailable.", context)

	actor.bank_balance -= lease_due

	var template_id: String = str(listing.get("template_id", "")).strip_edges()
	var template: Dictionary = gs.vehicle_engine._resolve_vehicle_template("template:%s" % template_id, int(listing.get("luxury_level", 0)), _purchase_context_from_listing(listing, "lease_vehicle"))
	if template.is_empty():
		return _result_with_surface(actor, false, "That lease offer could not be resolved.", context)

	var vehicle: Dictionary = gs.vehicle_engine._build_runtime_vehicle_from_template(template, actor, _purchase_context_from_listing(listing, "lease_vehicle", context))
	vehicle ["legal_status"] = "leased"
	vehicle ["value"] = price
	vehicle ["worth"] = price
	vehicle ["lease_contract"] = {
		"due_today": lease_due,
		"monthly_payment": monthly_payment,
		"started_year": _current_year(),
		"driver_id": int(actor.id),
		"dealership_tier": str(listing.get("dealership_tier", "standard"))
	}
	vehicle ["brand"] = str(listing.get("brand", "Era Motors"))
	vehicle ["model"] = str(listing.get("model", listing.get("display_name", "Vehicle")))
	vehicle ["source_engine"] = ENGINE_SCHEMA
	gs.vehicle_engine._register_vehicle_for_owner(actor, vehicle, false)

	var text: String = "You leased %s. Due today: %s. Monthly payment: %s." % [
		str(listing.get("display_name", "the vehicle")),
		_format_money(lease_due),
		_format_money(monthly_payment)
	]
	return _result_with_surface(actor, true, text, context)
func _vehicle_color_from_contract(
	card_contract: Dictionary
) -> Color:
	var color_hex: String = str(
		card_contract.get(
			"color_hex",
			"7A8494"
		)
	).strip_edges()

	if not color_hex.begins_with("#"):
		color_hex = "#%s" % color_hex

	return Color.from_string(
		color_hex,
		Color(0.48, 0.52, 0.58, 1.0)
	)


func _add_vehicle_color_visual(
	parent: VBoxContainer,
	card_contract: Dictionary
) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var color_name: String = str(
		card_contract.get(
			"color_name",
			"Factory Finish"
		)
	)
	var vehicle_color: Color = (
		_vehicle_color_from_contract(
			card_contract
		)
	)
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_theme_constant_override(
		"separation",
		8
	)

	var swatch:= ColorRect.new()
	swatch.color = vehicle_color
	swatch.custom_minimum_size = Vector2(
		36,
		20
	)
	swatch.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	row.add_child(swatch)

	var label:= Label.new()
	label.text = "Color • %s" % color_name
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.9,
			0.94,
			1.0,
			0.92
		)
	)
	row.add_child(label)

	parent.add_child(row)

func _vehicle_rows_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Array:
	var rows: Array = []

	if (
		gs != null
		and gs.vehicle_engine != null
		and gs.vehicle_engine.has_method(
			"get_vehicle_market_rows_for_buyer"
		)
	):
		rows = gs.vehicle_engine.get_vehicle_market_rows_for_buyer(
			actor,
			context
		)

	if rows.is_empty():
		rows = _fallback_vehicle_rows(actor)

	return _yearly_rotated_rows(rows)

func _vehicle_card_contract(
	actor: Person,
	row: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var template_id: String = str(
		row.get("template_id", "")
	).strip_edges()
	var price: int = int(
		row.get("price", 0)
	)
	var tier: Dictionary = _tier_for_row(row)
	var brand: String = str(
		row.get(
			"brand",
			_brand_for_row(row, tier)
		)
	)
	var model: String = str(
		row.get(
			"model",
			row.get("display_name", "Vehicle")
		)
	)
	var selected_dealership: Dictionary = _safe_dictionary(
		context.get(
			"selected_dealership_contract",
			{}
		)
	)
	var dealer_name: String = str(
		row.get(
			"dealer",
			selected_dealership.get(
				"name",
				tier.get("label", "Dealer")
			)
		)
	)
	var ownership_status: String = str(
		row.get("ownership_status", "available")
	).strip_edges().to_lower()
	var availability: String = str(
		row.get("availability", "available")
	).strip_edges().to_lower()
	var living_transport: bool = bool(
		row.get("living_transport", false)
	)
	var available_for_purchase: bool = (
		ownership_status == "available"
		and availability == "available"
	)
	var finance_down: int = maxi(
		1,
		int(
			round(
				float(price)
				* float(
					tier.get(
						"finance_down_rate",
						0.12
					)
				)
			)
		)
	)
	var finance_monthly: int = maxi(
		1,
		int(
			round(
				float(price)
				* float(
					tier.get(
						"finance_monthly_rate",
						0.018
					)
				)
			)
		)
	)
	var lease_due: int = maxi(
		1,
		int(
			round(
				float(price)
				* float(
					tier.get(
						"lease_due_rate",
						0.045
					)
				)
			)
		)
	)
	var lease_monthly: int = maxi(
		1,
		int(
			round(
				float(price)
				* float(
					tier.get(
						"lease_monthly_rate",
						0.011
					)
				)
			)
		)
	)
	var filter_tags: Array = _safe_array(
		row.get(
			"filter_tags",
			row.get("feature_tags", [])
		)
	)

	if not filter_tags.has(ownership_status):
		filter_tags.append(ownership_status)
	var storage_choice_contract: Dictionary = {}

	if (
		gs != null
		and gs.vehicle_engine != null
		and gs.vehicle_engine.has_method(
			"emit_vehicle_purchase_storage_contract"
		)
	):
		storage_choice_contract = (
			gs.vehicle_engine
			.emit_vehicle_purchase_storage_contract(
				actor,
				row,
				{
					"source": ENGINE_SCHEMA,
					"listing_id": _listing_id(
						"vehicle",
						template_id,
						brand,
						model
					)
				}
			)
		)

	var clearance_granted: bool = bool(
		storage_choice_contract.get(
			"clearance_granted",
			true
		)
	)
	var has_valid_destination: bool = bool(
		storage_choice_contract.get(
			"has_valid_destination",
			true
		)
	)
	var acquisition_disabled: bool = (
		not clearance_granted
		or not has_valid_destination
	)
	var acquisition_disabled_reason: String = ""

	if not clearance_granted:
		acquisition_disabled_reason = str(
			(
				storage_choice_contract.get(
					"clearance_contract",
					{}
				) as Dictionary
			).get(
				"reason",
				"Required clearance was not granted."
			)
		)
	elif not has_valid_destination:
		acquisition_disabled_reason = (
			"No valid storage destination is available."
		)
	var actions: Array = [
		{
			"action_id": "inspect",
			"label": "Inspect",
			"disabled": false
		}
	]

	if available_for_purchase:
		actions.append({
			"action_id": "buy_vehicle",
			"label": "Buy Vehicle",
			"disabled": acquisition_disabled,
			"disabled_reason": acquisition_disabled_reason
		})
		actions.append({
			"action_id": "finance_vehicle",
			"label": "Finance",
			"disabled": living_transport,
			"disabled_reason": "Living mounts are acquired outright through their animal contract."
		})
		actions.append({
			"action_id": "lease_vehicle",
			"label": "Lease",
			"disabled": living_transport,
			"disabled_reason": "Living mounts cannot be leased as machinery."
		})

	var monthly_cost: int = int(
		row.get("monthly_cost", 0)
	)

	if ownership_status == "financed":
		monthly_cost = int(
			row.get(
				"finance_monthly_payment",
				finance_monthly
			)
		)
	elif ownership_status == "leased":
		monthly_cost = int(
			row.get(
				"lease_monthly_payment",
				lease_monthly
			)
		)
	var variation_contracts: Array = _vehicle_listing_variation_contracts(
		row,
		price,
		living_transport,
		tier
	)
	var default_variation_index: int = (
		0
		if living_transport
		else 1
	)
	var default_variation: Dictionary = _safe_dictionary(
		variation_contracts [default_variation_index]
	)
	return {
		"schema": "eralife.market.vehicle_market.card_contract",
		"version": CONTRACT_VERSION,
		"listing_id": _listing_id(
			"vehicle",
			template_id,
			brand,
			model
		),
		"color_name": str(
			row.get(
				"color_name",
				"Factory Finish"
			)
		),
		"color_hex": str(
			row.get(
				"color_hex",
				"7A8494"
			)
		),
		"color_visual_contract": _safe_dictionary(
			row.get(
				"color_visual_contract",
				{}
			)
		),
		"storage_choice_contract": (
			storage_choice_contract
		),
		"storage_destination_contracts": _safe_array(
			storage_choice_contract.get(
				"destination_contracts",
				[]
			)
		),
		"default_storage_destination_id": str(
			storage_choice_contract.get(
				"default_destination_id",
				""
			)
		),
		"storage_choice_required": bool(
			storage_choice_contract.get(
				"requires_choice",
				false
			)
		),
		"clearance_contract": _safe_dictionary(
			storage_choice_contract.get(
				"clearance_contract",
				{}
			)
		),
		"restricted_vehicle": bool(
			row.get(
				"restricted_vehicle",
				false
			)
		),
		"requires_underground_bunker": bool(
			row.get(
				"requires_underground_bunker",
				false
			)
		),
		"variation_contracts": variation_contracts,
		"active_variation_index": default_variation_index,
		"variation_id": str(
			default_variation.get(
				"variation_id",
				""
			)
		),
		"variation_label": str(
			default_variation.get(
				"variation_label",
				"Dealer Maintained"
			)
		),
		"template_id": template_id,
		"title": "%s %s" % [brand, model],
		"display_name": "%s %s" % [brand, model],
		"name": "%s %s" % [brand, model],
		"brand": brand,
		"model": model,
		"category": str(
			row.get(
				"category",
				row.get("subtype", "mobility")
			)
		),
		"filter_tags": filter_tags,
		"movement_type": str(
			row.get("movement_type", "unknown")
		),
		"seats": int(row.get("seats", 1)),
		"era": str(
			row.get("era", _current_era_name())
		),
		"terrain": _safe_array(
			row.get("terrain", [])
		),
		"fuel": str(row.get("fuel", "none")),
		"monthly_cost": monthly_cost,
		"monthly_cost_text": _format_money(
			monthly_cost
		),
		"ownership_status": ownership_status,
		"availability": availability,
		"dealer": dealer_name,
		"condition": float(
			row.get("condition", 100.0)
		),
		"condition_text": str(
			row.get(
				"condition_text",
				row.get("condition_label", "New")
			)
		),
		"condition_applicable": bool(
			row.get(
				"condition_applicable",
				not living_transport
			)
		),
		"living_transport": living_transport,
		"animal_species_id": str(
			row.get("animal_species_id", "")
		),
		"mythical_species_id": str(
			row.get("mythical_species_id", "")
		),
		"dealership_tier": str(
			tier.get("id", "standard")
		),
		"dealership_label": dealer_name,
		"luxury_level": int(
			tier.get("luxury_level", 0)
		),
		"price": price,
		"price_text": _format_money(price),
		"finance_down_payment": finance_down,
		"finance_down_payment_text": _format_money(
			finance_down
		),
		"finance_monthly_payment": finance_monthly,
		"finance_monthly_payment_text": _format_money(
			finance_monthly
		),
		"lease_due_today": lease_due,
		"lease_due_today_text": _format_money(
			lease_due
		),
		"lease_monthly_payment": lease_monthly,
		"lease_monthly_payment_text": _format_money(
			lease_monthly
		),
		"feature_tags": _safe_array(
			row.get("feature_tags", [])
		),
		"requirement_tags": _safe_array(
			row.get("requirement_tags", [])
		),
		"portfolio_tags": _safe_array(
			row.get("portfolio_tags", [])
		),
		"status_summary": _safe_array(
			row.get("status_summary", [])
		),
		"operational_summary": _safe_array(
			row.get("operational_summary", [])
		),
		"actions": actions,
		"meta_line": _vehicle_meta_line(
			row,
			brand,
			tier
		),
		"render_kind": "mobility_contract_card",
		"truth_source": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}

func _elemental_vehicle_rows(_actor: Person) -> Array:
	var era_name: String = _current_era_name()
	var rows: Array = []
	if era_name not in ["Ancient Era", "Medieval Era", "Industrial Era", "Modern Era", "Future Era"]:
		return rows

	var elemental_rows: Array = [
		{ "template_id": "elemental_earth_iron_boar", "display_name": "Iron Boar Crawler", "brand": "Earth Kingdom Works", "model": "Iron Boar", "subtype": "crawler", "archetype": "utility_truck", "social_tier": "wealthy", "value_band": "specialty", "feature_tags": ["land", "earth", "utility", "armored"], "price": 54000},
		{ "template_id": "elemental_fire_sun_limo", "display_name": "Sunline Royal Limo", "brand": "Fire Nation Sunline", "model": "Royal Limo", "subtype": "limo", "archetype": "luxury_transport", "social_tier": "celebrity", "value_band": "luxury", "feature_tags": ["land", "fire", "luxury", "limo"], "price": 132000},
		{ "template_id": "elemental_water_tide_suv", "display_name": "Tidewalker SUV", "brand": "Northern Watercraft", "model": "Tidewalker SUV", "subtype": "suv", "archetype": "suv", "social_tier": "wealthy", "value_band": "premium", "feature_tags": ["land", "water", "suv", "all_terrain"], "price": 76000},
		{ "template_id": "elemental_air_cloud_pod", "display_name": "Cloud Runner Pod", "brand": "Air Nomad Motion", "model": "Cloud Runner", "subtype": "hover_pod", "archetype": "personal_transport", "social_tier": "respectable", "value_band": "premium", "feature_tags": ["air", "air_nomad", "quiet", "energy"], "price": 98000}
	]

	for raw_row in elemental_rows:
		var row: Dictionary = _safe_dictionary(raw_row)
		row ["requirement_tags"] = []
		row ["portfolio_tags"] = ["elemental_vehicle"]
		row ["status_summary"] = []
		row ["operational_summary"] = ["Era blend"]
		rows.append(row)

	return rows


func _modern_dealership_rows(_actor: Person) -> Array:
	var era_name: String = _current_era_name()
	if era_name not in ["Modern Era", "Future Era"]:
		return []

	var rows: Array = []
	var base_rows: Array = [
		{ "template_id": "dealer_modern_falcon_sedan", "brand": "Ford", "model": "Falcon Sedan", "display_name": "Falcon Sedan", "subtype": "sedan", "archetype": "personal_transport", "social_tier": "respectable", "value_band": "entry", "feature_tags": ["land", "car"], "price": 29000},
		{ "template_id": "dealer_modern_q7_suv", "brand": "Audi", "model": "Q7 SUV", "display_name": "Q7 SUV", "subtype": "suv", "archetype": "suv", "social_tier": "wealthy", "value_band": "premium", "feature_tags": ["land", "suv", "luxury"], "price": 74000},
		{ "template_id": "dealer_modern_town_limo", "brand": "Lincoln", "model": "Town Limo", "display_name": "Town Limo", "subtype": "limo", "archetype": "luxury_transport", "social_tier": "celebrity", "value_band": "luxury", "feature_tags": ["land", "limo", "luxury"], "price": 118000},
		{ "template_id": "dealer_future_aether_limo", "brand": "Aetheris", "model": "Halo Limo", "display_name": "Halo Limo", "subtype": "limo", "archetype": "luxury_transport", "social_tier": "ultra_luxury", "value_band": "premium_luxury", "feature_tags": ["energy", "limo", "luxury", "future"], "price": 420000}
	]

	for raw_row in base_rows:
		var row: Dictionary = _safe_dictionary(raw_row)
		if era_name == "Modern Era" and str(row.get("template_id", "")).find("future") >= 0:
			continue
		row ["requirement_tags"] = []
		row ["portfolio_tags"] = ["dealership_vehicle"]
		row ["status_summary"] = []
		row ["operational_summary"] = []
		rows.append(row)

	return rows

func _resident_vehicle_listing_contract_by_id(
	actor: Person,
	listing_id: String
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.assets_contract_engine == null
		or not gs.assets_contract_engine.has_method(
			"cached_surface_pack_for_actor"
		)
	):
		return {}

	var pack: Dictionary = (
		gs.assets_contract_engine
		.cached_surface_pack_for_actor(
			actor,
			{
				"source": (
					"dealership_contract_engine."
					+ "resident_listing_lookup"
				)
			}
		)
	)
	var vehicle_deck: Dictionary = _safe_dictionary(
		pack.get(
			"vehicle_market_surface_deck",
			{}
		)
	)
	var surfaces: Dictionary = _safe_dictionary(
		vehicle_deck.get(
			"surfaces",
			{}
		)
	)

	for raw_surface in surfaces.values():
		var surface: Dictionary = _safe_dictionary(
			raw_surface
		)

		if (
			surface.is_empty()
			or int(
				surface.get(
					"market_year",
					_current_year()
				)
			) != _current_year()
		):
			continue

		for raw_card in _safe_array(
			surface.get(
				"listing_card_contracts",
				[]
			)
		):
			var card: Dictionary = _safe_dictionary(
				raw_card
			)

			if str(
				card.get(
					"listing_id",
					""
				)
			).strip_edges() == listing_id:
				return card.duplicate(true)

	return {}
func _listing_by_id(
	actor: Person,
	listing_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_listing_id: String = str(
		listing_id
	).strip_edges()
	var parts: PackedStringArray = (
		clean_listing_id.split(
			":"
		)
	)

	if parts.size() < 5:
		return {}

	# FIX: this used to `return {}` outright when the id's embedded year did not match
	# the current year, which made EVERY vehicle card unclickable the moment the year
	# advanced -- the surface still shows listings generated last year, and their ids
	# carry that year. "That vehicle listing is no longer visible." for all of them.
	#
	# The regeneration fallback further down already handles exactly this: it rescans
	# the current catalogue by template/brand/model and rebuilds the card at current
	# prices. The early return simply made it unreachable. The year is now used only
	# to decide whether the cached resident listing can be trusted.
	var listing_year_matches_current: bool = (
		int(parts [1]) == _current_year()
	)

	var template_id: String = str(
		parts [2]
	)
	var brand: String = str(
		parts [3]
	)
	var model: String = str(
		parts [4]
	)
	var resident_listing: Dictionary = (
		_resident_vehicle_listing_contract_by_id(
			actor,
			clean_listing_id
		)
	)

	if (
		listing_year_matches_current
		and not resident_listing.is_empty()
		and str(
			resident_listing.get(
				"template_id",
				""
			)
		) == template_id
		and str(
			resident_listing.get(
				"brand",
				""
			)
		) == brand
		and str(
			resident_listing.get(
				"model",
				""
			)
		) == model
	):
		resident_listing [
			"resolved_from_resident_surface_cache"
		] = true
		resident_listing [
			"listing_regeneration_performed_on_click"
		] = false
		return resident_listing



	for raw_row in _vehicle_rows_for_actor(
		actor,
		context
	):
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if str(
			row.get(
				"template_id",
				""
			)
		) != template_id:
			continue

		if str(
			row.get(
				"brand",
				""
			)
		) != brand:
			continue

		if str(
			row.get(
				"model",
				""
			)
		) != model:
			continue

		var fallback_listing: Dictionary = (
			_vehicle_card_contract(
				actor,
				row,
				context
			)
		)
		fallback_listing [
			"resolved_from_resident_surface_cache"
		] = false
		fallback_listing [
			"listing_regeneration_performed_on_click"
		] = true
		return fallback_listing

	return {}

func _result_with_surface(
	actor: Person,
	success: bool,
	text: String,
	context: Dictionary = {}
) -> Dictionary:
	var surface_refresh_required: bool = bool(
		context.get(
			"surface_refresh_required",
			false
		)
	)
	var refreshed_surface: Dictionary = {}

	if (
		actor != null
		and surface_refresh_required
	):
		refreshed_surface = emit_market_surface_contract(
			actor,
			context
		)

	return {
		"success": success,
		"committed": success,
		"text": text,
		"popup_title": "Vehicle Market",
		"popup_text": text,
		"popup_footer": (
			"The resident dealership remains observable. "
			+ "Fleet truth will reconcile behind it."
		),
		"surface_refresh_required": surface_refresh_required,
		"surface_contract": refreshed_surface.duplicate(false),
		"affected_asset_domain": "vehicle",
		"background_portfolio_reconcile_requested": success,
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}

func _vehicle_inspection_text(listing: Dictionary) -> String:
	return "%s • %s • %s • Finance down %s • Lease due %s." % [
		str(listing.get("display_name", "Vehicle")),
		str(listing.get("dealership_label", "Market")),
		str(listing.get("value_band", "entry")).replace("_", " ").capitalize(),
		str(listing.get("finance_down_payment_text", "")),
		str(listing.get("lease_due_today_text", ""))
	]


func _purchase_context_from_listing(
	listing: Dictionary,
	action_id: String,
	action_context: Dictionary = {}
) -> Dictionary:
	return {
		"source": ENGINE_SCHEMA,
		"market_action": action_id,
		"market_region": str(
			listing.get(
				"market_region",
				""
			)
		),
		"market_climate": str(
			listing.get(
				"market_climate",
				""
			)
		),
		"listing_id": str(
			listing.get(
				"listing_id",
				""
			)
		),
		"template_id": str(
			listing.get(
				"template_id",
				""
			)
		),
		"brand": str(
			listing.get(
				"brand",
				""
			)
		),
		"model": str(
			listing.get(
				"model",
				""
			)
		),
		"category": str(
			listing.get(
				"category",
				""
			)
		),
		"movement_type": str(
			listing.get(
				"movement_type",
				""
			)
		),
		"seats": int(
			listing.get(
				"seats",
				1
			)
		),
		"terrain": _safe_array(
			listing.get(
				"terrain",
				[]
			)
		),
		"fuel": str(
			listing.get(
				"fuel",
				"none"
			)
		),
		"monthly_cost": int(
			listing.get(
				"monthly_cost",
				0
			)
		),
		"living_transport": bool(
			listing.get(
				"living_transport",
				false
			)
		),
		"animal_species_id": str(
			listing.get(
				"animal_species_id",
				""
			)
		),
		"mythical_species_id": str(
			listing.get(
				"mythical_species_id",
				""
			)
		),
		"luxury_level": int(
			listing.get(
				"luxury_level",
				0
			)
		),
		"dealership_tier": str(
			listing.get(
				"dealership_tier",
				"standard"
			)
		),
		"dealer": str(
			listing.get(
				"dealer",
				listing.get(
					"dealership_label",
					""
				)
			)
		),
		"color_name": str(
			listing.get(
				"color_name",
				"Factory Finish"
			)
		),
		"color_hex": str(
			listing.get(
				"color_hex",
				"7A8494"
			)
		),
		"storage_destination_id": str(
			action_context.get(
				"storage_destination_id",
				listing.get(
					"default_storage_destination_id",
					""
				)
			)
		)
	}

func _tier_for_row(row: Dictionary) -> Dictionary:
	var social_tier: String = str(row.get("social_tier", "common")).to_lower()
	var value_band: String = str(row.get("value_band", "entry")).to_lower()

	for tier in _dealership_tiers():
		var tier_id: String = str(tier.get("id", ""))
		if value_band == tier_id:
			return tier
		if social_tier == tier_id:
			return tier

	if social_tier in ["celebrity", "ultra_luxury"] or value_band.find("luxury") >= 0:
		return _dealership_tiers() [4]
	if social_tier in ["wealthy", "noble"] or value_band.find("premium") >= 0:
		return _dealership_tiers() [3]
	if social_tier == "respectable":
		return _dealership_tiers() [1]
	return _dealership_tiers() [0]


func _dealership_tiers() -> Array:
	return [
		{ "id": "budget", "label": "Budget Lot", "luxury_level": 0, "finance_down_rate": 0.1, "finance_monthly_rate": 0.02, "lease_due_rate": 0.04, "lease_monthly_rate": 0.013},
		{ "id": "standard", "label": "Standard Dealership", "luxury_level": 1, "finance_down_rate": 0.12, "finance_monthly_rate": 0.018, "lease_due_rate": 0.045, "lease_monthly_rate": 0.011},
		{ "id": "premium", "label": "Premium Dealer", "luxury_level": 2, "finance_down_rate": 0.15, "finance_monthly_rate": 0.016, "lease_due_rate": 0.05, "lease_monthly_rate": 0.01},
		{ "id": "luxury", "label": "Luxury Showroom", "luxury_level": 3, "finance_down_rate": 0.18, "finance_monthly_rate": 0.014, "lease_due_rate": 0.06, "lease_monthly_rate": 0.009},
		{ "id": "premium_luxury", "label": "Premium Luxury", "luxury_level": 4, "finance_down_rate": 0.22, "finance_monthly_rate": 0.012, "lease_due_rate": 0.075, "lease_monthly_rate": 0.008}
	]


func _brand_for_row(row: Dictionary, tier: Dictionary) -> String:
	if str(row.get("brand", "")).strip_edges() != "":
		return str(row.get("brand", "")).strip_edges()

	var tags: Array = _safe_array(row.get("feature_tags", []))
	if tags.has("earth"):
		return "Earth Kingdom Works"
	if tags.has("fire"):
		return "Fire Nation Sunline"
	if tags.has("water"):
		return "Northern Watercraft"
	if tags.has("air_nomad"):
		return "Air Nomad Motion"

	match str(tier.get("id", "standard")):
		"budget":
			return "Ford"
		"standard":
			return "Toyota"
		"premium":
			return "Audi"
		"luxury":
			return "Mercedes"
		"premium_luxury":
			return "Aetheris"
		_:
			return "Era Motors"


func _vehicle_meta_line(row: Dictionary, brand: String, tier: Dictionary) -> String:
	var parts: Array = []
	parts.append(brand)
	parts.append(str(tier.get("label", "Dealership")))
	parts.append(str(row.get("value_band", "entry")).replace("_", " ").capitalize())
	for raw_tag in _safe_array(row.get("feature_tags", [])):
		if parts.size() >= 6:
			break
		parts.append(str(raw_tag).replace("_", " ").capitalize())
	return " • ".join(parts)


func _yearly_rotated_rows(rows: Array) -> Array:
	var year_key: int = abs(_current_year())
	var out: Array = rows.duplicate(true)
	out.sort_custom(func (a, b):
		var a_row: Dictionary = _safe_dictionary(a)
		var b_row: Dictionary = _safe_dictionary(b)
		var a_score: int = int(a_row.get("price", 0)) + abs(str(a_row.get("template_id", "")).hash() + year_key) % 10000
		var b_score: int = int(b_row.get("price", 0)) + abs(str(b_row.get("template_id", "")).hash() + year_key) % 10000
		return a_score < b_score
	)
	return out


func _fallback_vehicle_rows(actor: Person) -> Array:
	var out: Array = []
	if gs == null or gs.vehicle_engine == null:
		return out
	for vehicle_type in ["Car", "Boat", "Plane"]:
		var template: Dictionary = gs.vehicle_engine._legacy_vehicle_template(vehicle_type, 0)
		if template.is_empty():
			continue
		var price: int = gs.vehicle_engine._calculate_vehicle_value(template, actor, {})
		out.append({
			"template_id": str(template.get("template_id", "")),
			"display_name": str(template.get("display_name", "Vehicle")),
			"archetype": str(template.get("archetype", "personal_transport")),
			"subtype": str(template.get("subtype", "")),
			"social_tier": str(template.get("social_tier", "common")),
			"value_band": str(template.get("value_band", "entry")),
			"feature_tags": _safe_array(template.get("feature_tags", [])),
			"requirement_tags": _safe_array(template.get("requirement_tags", [])),
			"portfolio_tags": _safe_array(template.get("portfolio_tags", [])),
			"status_summary": [],
			"operational_summary": [],
			"price": price
		})
	return out


func _listing_id(kind: String, template_id: String, brand: String, model: String) -> String:
	return "%s:%s:%s:%s:%s" % [kind, str(_current_year()), template_id, brand, model]


func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if typeof(gs.scenario_state.get(STATE_KEY, {})) != TYPE_DICTIONARY:
		gs.scenario_state [STATE_KEY] = {}


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "Unknown Era"


func _current_year() -> int:
	if gs != null:
		return int(gs.year)
	return 0


func _format_money(amount: int) -> String:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("format_money"):
		return str(gs.economy_engine.format_money(amount))
	return "$%d" % amount

func resident_luxury_listing_card_contracts(
	actor: Person,
	max_cards: int = 4
) -> Array:
	var out: Array = []

	if (
		actor == null
		or max_cards <= 0
	):
		return out

	var prefix: String = (
		"%d|%s|%s|%d|"
		% [
			int(actor.id),
			_current_era_name().to_lower(),
			_current_reality_mode_key(),
			_current_year()
		]
	)

	var newest_deck: Dictionary = {}
	var newest_created_at_ms: int = -1
	var inspected_decks: int = 0

	for raw_key in surface_deck_cache.keys():
		if inspected_decks >= 32:
			break

		inspected_decks += 1

		var deck_key: String = str(
			raw_key
		)

		if not deck_key.begins_with(
			prefix
		):
			continue

		var deck: Dictionary = _safe_dictionary(
			surface_deck_cache.get(
				raw_key,
				{}
			)
		)

		var created_at_ms: int = int(
			deck.get(
				"created_at_ms",
				0
			)
		)

		if created_at_ms <= newest_created_at_ms:
			continue

		newest_created_at_ms = (
			created_at_ms
		)
		newest_deck = deck

	if newest_deck.is_empty():
		return out

	var surfaces: Dictionary = _safe_dictionary(
		newest_deck.get(
			"surfaces",
			{}
		)
	)
	var candidates: Array = []
	var inspected_surfaces: int = 0
	var inspected_cards: int = 0

	for raw_surface in surfaces.values():
		if inspected_surfaces >= 12:
			break

		inspected_surfaces += 1

		var surface: Dictionary = _safe_dictionary(
			raw_surface
		)

		for raw_card in _safe_array(
			surface.get(
				"listing_card_contracts",
				[]
			)
		):
			if inspected_cards >= 64:
				break

			inspected_cards += 1

			if typeof(raw_card) != TYPE_DICTIONARY:
				continue

			var card: Dictionary = (
				(raw_card as Dictionary)
				.duplicate(false)
			)
			var availability: String = str(
				card.get(
					"availability",
					"available"
				)
			).strip_edges().to_lower()

			if availability != "available":
				continue

			var price: int = int(
				card.get(
					"price",
					0
				)
			)
			var luxury_level: int = int(
				card.get(
					"luxury_level",
					0
				)
			)
			var tags: Array = _safe_array(
				card.get(
					"feature_tags",
					[]
				)
			)
			var category: String = str(
				card.get(
					"category",
					""
				)
			).to_lower()
			var title: String = str(
				card.get(
					"title",
					""
				)
			).to_lower()

			var luxury_candidate: bool = (
				luxury_level >= 2
				or price >= 250000
				or tags.has("luxury")
				or tags.has("supercar")
				or tags.has("yacht")
				or tags.has("private_aircraft")
				or tags.has("private_jet")
				or category.find("yacht") >= 0
				or category.find("aircraft") >= 0
				or title.find("yacht") >= 0
				or title.find("jet") >= 0
			)

			if not luxury_candidate:
				continue

			card [
				"luxury_exchange_source_authority"
			] = ENGINE_SCHEMA
			card [
				"luxury_exchange_actor_id"
			] = int(actor.id)

			candidates.append(
				card
			)

	candidates.sort_custom(
		func (a, b):
			return int(
				(a as Dictionary).get(
					"price",
					0
				)
			) > int(
				(b as Dictionary).get(
					"price",
					0
				)
			)
	)

	for index in range(
		mini(
			max_cards,
			candidates.size()
		)
	):
		out.append(
			(
				candidates [index]
				as Dictionary
			).duplicate(false)
		)

	return out
func _market_currency_contract() -> Dictionary:
	return {
		"name": "USD",
		"symbol": "$",
		"base_unit": 1
	}

func _vehicle_listing_variation_contracts(
	row: Dictionary,
	base_price: int,
	living_transport: bool,
	tier: Dictionary
) -> Array:
	var template_id: String = str(
		row.get(
			"template_id",
			"vehicle"
		)
	)
	var current_year: int = (
		int(gs.year)
		if gs != null
		else 0
	)
	var seed_source: String = (
		"%s|%d|%d|vehicle_variations" % [
			template_id,
			base_price,
			current_year
		]
	)
	var variation_seed: int = abs(
		seed_source.hash()
	)

	if living_transport:
		return [{
			"variation_id": "%s:living" % template_id,
			"variation_label": "Living Contract",
			"condition": 100.0,
			"condition_text": "Living",
			"condition_applicable": false,
			"price": base_price,
			"price_text": _format_money(base_price),
			"contract_authority": ENGINE_SCHEMA
		}]

	var conditions: Array = [
		55 + (variation_seed % 11),
		78 + (variation_seed % 12),
		95 + (variation_seed % 6)
	]
	var labels: Array = [
		"Used",
		"Dealer Maintained",
		"Showroom"
	]
	var multipliers: Array = [
		0.8,
		1.0,
		1.14
	]
	var out: Array = []

	for index in range(3):
		var price: int = maxi(
			1,
			int(
				round(
					float(base_price)
					* float(multipliers [index])
				)
			)
		)
		var finance_down: int = maxi(
			1,
			int(
				round(
					float(price)
					* float(
						tier.get(
							"finance_down_rate",
							0.12
						)
					)
				)
			)
		)
		var finance_monthly: int = maxi(
			1,
			int(
				round(
					float(price)
					* float(
						tier.get(
							"finance_monthly_rate",
							0.018
						)
					)
				)
			)
		)
		var lease_due: int = maxi(
			1,
			int(
				round(
					float(price)
					* float(
						tier.get(
							"lease_due_rate",
							0.045
						)
					)
				)
			)
		)
		var lease_monthly: int = maxi(
			1,
			int(
				round(
					float(price)
					* float(
						tier.get(
							"lease_monthly_rate",
							0.011
						)
					)
				)
			)
		)

		out.append({
			"variation_id": "%s:%d" % [
				template_id,
				index
			],
			"variation_label": str(
				labels [index]
			),
			"condition": float(
				conditions [index]
			),
			"condition_text": str(
				labels [index]
			),
			"condition_applicable": true,
			"price": price,
			"price_text": _format_money(price),
			"finance_down_payment": finance_down,
			"finance_down_payment_text": _format_money(
				finance_down
			),
			"finance_monthly_payment": finance_monthly,
			"finance_monthly_payment_text": _format_money(
				finance_monthly
			),
			"lease_due_today": lease_due,
			"lease_due_today_text": _format_money(
				lease_due
			),
			"lease_monthly_payment": lease_monthly,
			"lease_monthly_payment_text": _format_money(
				lease_monthly
			),
			"contract_authority": ENGINE_SCHEMA
		})

	return out


func _vehicle_listing_with_selected_variation(
	listing: Dictionary,
	payload: Dictionary
) -> Dictionary:
	var requested_id: String = str(
		payload.get(
			"variation_id",
			""
		)
	).strip_edges()

	if requested_id == "":
		return listing

	for raw_variation in _safe_array(
		listing.get(
			"variation_contracts",
			[]
		)
	):
		var variation: Dictionary = _safe_dictionary(
			raw_variation
		)

		if str(
			variation.get(
				"variation_id",
				""
			)
		) != requested_id:
			continue

		var resolved: Dictionary = listing.duplicate(true)

		for key in variation.keys():
			if key == "contract_authority":
				continue

			resolved [key] = variation [key]

		resolved ["selected_variation_id"] = requested_id
		resolved ["selected_variation_contract"] = variation.duplicate(true)
		return resolved

	return listing
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []