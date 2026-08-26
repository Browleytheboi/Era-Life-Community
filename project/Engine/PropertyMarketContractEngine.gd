extends Resource
class_name PropertyMarketContractEngine

const ENGINE_SCHEMA:= "eralife.market.property_market_contract_engine"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "property_market_contract_state"
var resident_listing_contract_by_id: Dictionary = {}
var market_observation_jobs: Dictionary = {}
var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()

func service_market_surface_observation_quantum(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or gs == null
		or gs.property_engine == null
	):
		return {
			"success": false,
			"complete": true,
			"reason": (
				"property_market_authority_unavailable"
			)
		}

	var actor_id: int = int(
		actor.id
	)

	var job_key: String = (
		"%d|%s|%d|property_market_progressive"
		% [
			actor_id,
			_current_era_name(),
			_current_year()
		]
	)

	var job_raw: Variant = market_observation_jobs.get(
		job_key,
		{}
	)

	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		var initial_templates: Array = (
			gs.property_engine
			.property_market_templates_for_buyer(
				actor,
				context
			)
		)

		var initial_filters: Array = []

		if gs.era_life_asset_catalog_expansion == null:
			gs.era_life_asset_catalog_expansion = (
				EraLifeAssetCatalogExpansion.new(
					gs
				)
			)

		if gs.era_life_asset_catalog_expansion != null:
			initial_filters = (
				gs.era_life_asset_catalog_expansion
				.property_filter_contracts()
			)

		job = {
			"actor_id": actor_id,
			"templates": initial_templates,
			"filter_contracts": initial_filters,
			"filters_published": false,
			"cursor": 0,
			"cards": [],
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"ui_is_renderer_only": true
		}

		market_observation_jobs [
			job_key
		] = job

	if not bool(
		job.get(
			"filters_published",
			false
		)
	):
		job [
			"filters_published"
		] = true

		market_observation_jobs [
			job_key
		] = job

		return {
			"success": true,
			"complete": false,
			"actor_id": actor_id,
			"cursor": 0,
			"surface_patch": {
				"patch_kind": "filters",
				"actor_id": actor_id,
				"filter_contracts": job.get(
					"filter_contracts",
					[]
				),
			},
			"ui_is_renderer_only": true
		}

	var templates_raw: Variant = job.get(
		"templates",
		[]
	)

	var templates: Array = (
		templates_raw as Array
		if typeof(templates_raw) == TYPE_ARRAY
		else []
	)

	var cursor: int = int(
		job.get(
			"cursor",
			0
		)
	)

	if cursor < templates.size():
		job [
			"cursor"
		] = cursor + 1

		var template_raw: Variant = templates [
			cursor
		]

		if typeof(template_raw) == TYPE_DICTIONARY:
			var row: Dictionary = (
				gs.property_engine
				.build_property_market_row_contract(
					actor,
					template_raw as Dictionary,
					context
				)
			)

			if (
				not row.is_empty()
				and _property_market_row_is_publicly_purchasable(
					row
				)
			):
				var card: Dictionary = (
					_property_card_contract(
						actor,
						row,
						context
					)
				)

				card [
					"resident_property_template_contract"
				] = (
					(
						row.get(
							"property_template_contract",
							{}
						) as Dictionary
					).duplicate(false)
					if typeof(
						row.get(
							"property_template_contract",
							{}
						)
					) == TYPE_DICTIONARY
					else {}
				)

				var listing_id: String = str(
					card.get(
						"listing_id",
						""
					)
				)

				if listing_id != "":
					resident_listing_contract_by_id [
						listing_id
					] = card.duplicate(false)

				var current_cards_raw: Variant = job.get(
					"cards",
					[]
				)

				var current_cards: Array = (
					current_cards_raw as Array
					if typeof(current_cards_raw) == TYPE_ARRAY
					else []
				)

				current_cards.append(
					card
				)

				job [
					"cards"
				] = current_cards

				market_observation_jobs [
					job_key
				] = job

				return {
					"success": true,
					"complete": false,
					"actor_id": actor_id,
					"cursor": cursor + 1,
					"template_count": templates.size(),
					"surface_patch": {
						"patch_kind": "listing",
						"actor_id": actor_id,
						"listing_card_contract": card
					},
					"ui_is_renderer_only": true
				}

		market_observation_jobs [
			job_key
		] = job

		return {
			"success": true,
			"complete": false,
			"actor_id": actor_id,
			"cursor": cursor + 1,
			"template_count": templates.size(),
			"surface_patch": {},
			"ui_is_renderer_only": true
		}

	var cards_raw: Variant = job.get(
		"cards",
		[]
	)

	var cards: Array = (
		cards_raw as Array
		if typeof(cards_raw) == TYPE_ARRAY
		else []
	)

	var filter_contracts_raw: Variant = job.get(
		"filter_contracts",
		[]
	)

	var filter_contracts: Array = (
		filter_contracts_raw as Array
		if typeof(filter_contracts_raw) == TYPE_ARRAY
		else []
	)

	var final_contract: Dictionary = {
		"success": true,
		"schema": (
			"eralife.market.property_market.surface_contract"
		),
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"title": (
			"PROPERTY MARKET • %s"
			% _current_era_name()
		),
		"subtitle": (
			"Era-valid property contracts synthesized from world rules, "
			+ "place, price, construction, lifestyle, and technology."
		),
		"era": _current_era_name(),
		"market_year": _current_year(),
		"truth_state": "hot",
		"status_text": "",
		"currency": _market_currency_contract(),
		"filter_contracts": filter_contracts,
		"listing_card_contracts": cards,
		"listing_count": cards.size(),
		"commit_authority": ENGINE_SCHEMA,
		"amenity_authority": (
			"PropertyAmenitySynthesisContractEngine"
		),
		"ui_is_pure_renderer": true,
		"ui_is_renderer_only": true,
	}

	market_observation_jobs.erase(
		job_key
	)

	return {
		"success": true,
		"complete": true,
		"actor_id": actor_id,
		"surface_patch": {
			"patch_kind": "complete",
			"actor_id": actor_id,
			"surface_contract": final_contract,
			"listing_count": cards.size()
		},
		"surface_contract": final_contract,
		"ui_is_renderer_only": true
	}
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

	var rows: Array = _property_rows_for_actor(
		actor,
		context
	)
	var cards: Array = []

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if row.is_empty():
			continue

		cards.append(
			_property_card_contract(
				actor,
				row,
				context
			)
		)

	var filter_contracts: Array = []

	if gs != null:
		if gs.era_life_asset_catalog_expansion == null:
			gs.era_life_asset_catalog_expansion = EraLifeAssetCatalogExpansion.new(
				gs
			)

		if gs.era_life_asset_catalog_expansion != null:
			filter_contracts = (
				gs.era_life_asset_catalog_expansion
				.property_filter_contracts()
			)

	var status_text: String = str(
		context.get("status_text", "")
	).strip_edges()
	var surface_contract: Dictionary = {
		"success": true,
		"schema": "eralife.market.property_market.surface_contract",
		"version": CONTRACT_VERSION,
		"title": "PROPERTY MARKET • %s" % _current_era_name(),
		"subtitle": "Era-valid property contracts synthesized from world rules, place, price, construction, lifestyle, and technology.",
		"era": _current_era_name(),
		"market_year": _current_year(),
		"truth_state": (
			"hot"
			if not cards.is_empty()
			else "observable_partial"
		),
		"status_text": status_text,
		"layout_contract": {
			"surface": "near_full_screen",
			"panel": "PropertyMarketPanel",
			"cards": "aaa_property_cards",
			"filters": "contract_driven",
		},
		"currency": _market_currency_contract(),
		"filter_contracts": filter_contracts,
		"listing_card_contracts": cards,
		"listing_count": cards.size(),
		"selected_template_id": str(
			context.get(
				"selected_template_id",
				""
			)
		),
		"commit_authority": ENGINE_SCHEMA,
		"amenity_authority": "PropertyAmenitySynthesisContractEngine",
		"ui_is_pure_renderer": true,
		"ui_is_renderer_only": true,
	}

	if gs != null:
		if gs.card_contract_engine == null:
			gs.card_contract_engine = CardContractEngine.new(
				gs
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
			return gs.card_contract_engine.project_market_surface(
				"property",
				actor,
				surface_contract,
				context
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
		payload.get(
			"listing_id",
			""
		)
	).strip_edges()
	var action_id: String = str(
		payload.get(
			"market_action",
			payload.get(
				"action_id",
				""
			)
		)
	).strip_edges()
	var listing: Dictionary = _listing_by_id(
		actor,
		listing_id,
		payload
	)

	if listing.is_empty():
		return _result_with_surface(
			actor,
			false,
			"That property listing is no longer visible.",
			payload
		)



	listing = _property_listing_with_selected_variation(
		listing,
		payload
	)

	var template_id: String = str(
		listing.get(
			"template_id",
			""
		)
	).strip_edges()
	var template_ref: String = (
		"template:%s" % template_id
	)
	var price: int = int(
		listing.get(
			"price",
			0
		)
	)

	var bank_balance_before: int = maxi(
		0,
		int(
			round(
				float(
					actor.bank_balance
				)
			)
		)
	)
	var result: Dictionary = {}

	match action_id:
		"buy_outright":
			result = _buy_outright(
				actor,
				template_ref,
				price,
				listing,
				payload
			)
		"rent_monthly":
			result = _rent_monthly(
				actor,
				template_ref,
				listing,
				payload
			)
		"apply_mortgage":
			result = _apply_mortgage(
				actor,
				template_ref,
				price,
				listing,
				payload
			)
		"inspect":
			return _result_with_surface(
				actor,
				true,
				_property_inspection_text(
					listing
				),
				payload
			)
		_:
			return _result_with_surface(
				actor,
				false,
				"That property action is not available.",
				payload
			)

	if (
		bool(
			result.get(
				"success",
				false
			)
		)
		and action_id in [
			"buy_outright",
			"rent_monthly",
			"apply_mortgage"
		]
	):
		var bank_balance_after: int = maxi(
			0,
			int(
				round(
					float(
						actor.bank_balance
					)
				)
			)
		)

		result ["bank_report"] = {
			"schema": "eralife.bank_delta_contract",
			"version": 1,
			"actor_id": int(
				actor.id
			),
			"previous_balance": bank_balance_before,
			"new_balance": bank_balance_after,
			"balance": bank_balance_after,
			"bank_delta": (
				bank_balance_after
				- bank_balance_before
			),
			"transaction_kind": action_id,
			"transaction_committed": true,
			"source": (
				"PropertyMarketContractEngine.commit_listing_action"
			),
			"truth_state": "hot",
			"ui_is_renderer_only": true
		}

	return result
func _buy_outright(
	actor: Person,
	template_ref: String,
	price: int,
	listing: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if bool(
		listing.get(
			"buy_disabled",
			false
		)
	):
		return _result_with_surface(
			actor,
			false,
			str(
				listing.get(
					"buy_disabled_reason",
					"This property cannot be bought outright."
				)
			),
			context
		)

	if (
		gs == null
		or gs.property_engine == null
	):
		return _result_with_surface(
			actor,
			false,
			"PropertyEngine is unavailable.",
			context
		)

	var result: Dictionary = gs.property_engine.buy_property(
		actor,
		template_ref,
		price,
		_purchase_context_from_listing(
			listing,
			"buy_outright",
			context
		)
	)
	var text: String = str(
		result.get(
			"text",
			"Property purchase resolved."
		)
	)

	return _result_with_surface(
		actor,
		bool(
			result.get(
				"success",
				false
			)
		),
		text,
		context
	)


func _rent_monthly(
	actor: Person,
	template_ref: String,
	listing: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var monthly_rent: int = int(
		listing.get(
			"monthly_rent",
			max(
				1,
				int(
					round(
						float(
							listing.get(
								"price",
								0
							)
						) * 0.008
					)
				)
			)
		)
	)
	var move_in_cost: int = monthly_rent * 2

	if int(actor.bank_balance) < move_in_cost:
		return _result_with_surface(
			actor,
			false,
			"You need %s to move in."
			% _format_money(
				move_in_cost
			),
			context
		)

	if (
		gs == null
		or gs.property_engine == null
	):
		return _result_with_surface(
			actor,
			false,
			"PropertyEngine is unavailable.",
			context
		)

	actor.bank_balance -= move_in_cost

	var template: Dictionary = (
		gs.property_engine._resolve_property_template(
			template_ref,
			_purchase_context_from_listing(
				listing,
				"rent_monthly",
				context
			)
		)
	)

	if template.is_empty():
		return _result_with_surface(
			actor,
			false,
			"That rental could not be resolved.",
			context
		)

	var prop: Dictionary = (
		gs.property_engine._build_runtime_property_from_template(
			template,
			actor,
			_purchase_context_from_listing(
				listing,
				"rent_monthly",
				context
			)
		)
	)
	prop ["legal_status"] = "rented"
	prop ["rent_contract"] = {
		"monthly_rent": monthly_rent,
		"deposit_paid": monthly_rent,
		"first_month_paid": monthly_rent,
		"started_year": _current_year(),
		"tenant_id": int(actor.id)
	}
	prop ["owners"] = []
	prop ["price"] = 0
	prop ["value"] = int(
		listing.get(
			"price",
			0
		)
	)
	prop ["worth"] = int(
		listing.get(
			"price",
			0
		)
	)
	prop ["source_engine"] = ENGINE_SCHEMA

	gs.property_engine._register_property_for_owner(
		actor,
		prop,
		false
	)

	var text: String = (
		"You rented %s for %s per month."
		% [
			str(
				listing.get(
					"display_name",
					"the property"
				)
			),
			_format_money(
				monthly_rent
			)
		]
	)

	return _result_with_surface(
		actor,
		true,
		text,
		context
	)

func _apply_mortgage(
	actor: Person,
	template_ref: String,
	price: int,
	listing: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if bool(
		listing.get(
			"mortgage_disabled",
			false
		)
	):
		return _result_with_surface(
			actor,
			false,
			str(
				listing.get(
					"mortgage_disabled_reason",
					"A mortgage is not available for this property."
				)
			),
			context
		)

	var down_payment: int = int(
		listing.get(
			"mortgage_down_payment",
			max(
				1,
				int(
					round(
						float(
							price
						) * 0.2
					)
				)
			)
		)
	)
	var monthly_payment: int = int(
		listing.get(
			"mortgage_monthly_payment",
			max(
				1,
				int(
					round(
						float(
							price
						) * 0.0065
					)
				)
			)
		)
	)

	if int(actor.bank_balance) < down_payment:
		return _result_with_surface(
			actor,
			false,
			"You need %s for the down payment."
			% _format_money(
				down_payment
			),
			context
		)

	if (
		gs == null
		or gs.property_engine == null
	):
		return _result_with_surface(
			actor,
			false,
			"PropertyEngine is unavailable.",
			context
		)

	actor.bank_balance -= down_payment

	var template: Dictionary = (
		gs.property_engine._resolve_property_template(
			template_ref,
			_purchase_context_from_listing(
				listing,
				"apply_mortgage",
				context
			)
		)
	)

	if template.is_empty():
		return _result_with_surface(
			actor,
			false,
			"That mortgage listing could not be resolved.",
			context
		)

	var prop: Dictionary = (
		gs.property_engine._build_runtime_property_from_template(
			template,
			actor,
			_purchase_context_from_listing(
				listing,
				"apply_mortgage",
				context
			)
		)
	)
	prop ["legal_status"] = "mortgaged"
	prop ["price"] = price
	prop ["value"] = price
	prop ["worth"] = price
	prop ["mortgage_contract"] = {
		"principal": max(
			0,
			price - down_payment
		),
		"down_payment": down_payment,
		"monthly_payment": monthly_payment,
		"started_year": _current_year(),
		"borrower_id": int(actor.id)
	}
	prop ["source_engine"] = ENGINE_SCHEMA

	gs.property_engine._register_property_for_owner(
		actor,
		prop,
		true
	)

	var text: String = (
		"Your mortgage was approved for %s. Down payment: %s. Monthly payment: %s."
		% [
			str(
				listing.get(
					"display_name",
					"the property"
				)
			),
			_format_money(
				down_payment
			),
			_format_money(
				monthly_payment
			)
		]
	)

	return _result_with_surface(
		actor,
		true,
		text,
		context
	)

func _property_rows_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Array:
	var source_rows: Array = []

	if (
		gs != null
		and gs.property_engine != null
		and gs.property_engine.has_method(
			"get_property_market_rows_for_buyer"
		)
	):
		source_rows = (
			gs.property_engine
			.get_property_market_rows_for_buyer(
				actor,
				context
			)
		)

	if source_rows.is_empty():
		source_rows = _fallback_property_rows(
			actor
		)

	var rows: Array = []

	for raw_row in source_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary

		if not _property_market_row_is_publicly_purchasable(
			row
		):
			continue

		rows.append(
			row
		)

	return _yearly_rotated_rows(
		rows
	)
func _property_market_row_is_publicly_purchasable(
	row: Dictionary
) -> bool:
	if row.is_empty():
		return false

	if bool(
		row.get(
			"government_owned",
			false
		)
	):
		return false

	if bool(
		row.get(
			"temporary_controlled_by_office_holder",
			false
		)
	):
		return false

	var asset_kind: String = str(
		row.get(
			"asset_kind",
			"property"
		)
	).strip_edges().to_lower()

	if asset_kind in [
		"official_residence",
		"government_residence"
	]:
		return false

	var availability: String = str(
		row.get(
			"availability",
			"available"
		)
	).strip_edges().to_lower()

	if availability in [
		"owned_not_for_sale",
		"government_controlled",
		"official_use",
		"unavailable",
		"not_for_sale"
	]:
		return false

	var ownership_status: String = str(
		row.get(
			"ownership_status",
			"available"
		)
	).strip_edges().to_lower()

	if ownership_status in [
		"owned",
		"rented",
		"mortgaged",
		"government_owned",
		"official_residence"
	]:
		return false

	return true
func _owned_property_rows(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		actor == null
		or gs == null
		or gs.property_engine == null
		or not gs.property_engine.properties.has(
			actor.id
		)
	):
		return out

	var seen: Dictionary = {}

	for raw_property in gs.property_engine.properties.get(
		actor.id,
		[]
	):
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var property_contract: Dictionary = (
			raw_property as Dictionary
		)
		var property_id: int = int(
			property_contract.get("id", -1)
		)

		if (
			property_id <= 0
			or seen.has(property_id)
		):
			continue

		seen [property_id] = true

		var legal_status: String = str(
			property_contract.get(
				"legal_status",
				"owned"
			)
		).strip_edges().to_lower()
		var filter_tags: Array = _safe_array(
			property_contract.get(
				"filter_tags",
				property_contract.get(
					"feature_tags",
					[]
				)
			)
		)

		if not filter_tags.has(legal_status):
			filter_tags.append(legal_status)

		if (
			legal_status == "rented"
			and not filter_tags.has("rental")
		):
			filter_tags.append("rental")

		out.append({
			"template_id": "owned_property:%d" % property_id,
			"source_property_id": property_id,
			"display_name": str(
				property_contract.get(
					"nickname",
					property_contract.get(
						"display_name",
						"Property"
					)
				)
			),
			"category": str(
				property_contract.get(
					"category",
					property_contract.get(
						"archetype",
						"residential"
					)
				)
			),
			"archetype": str(
				property_contract.get(
					"archetype",
					"residence"
				)
			),
			"subtype": str(
				property_contract.get(
					"subtype",
					""
				)
			),
			"size": str(
				property_contract.get(
					"size",
					""
				)
			),
			"social_tier": str(
				property_contract.get(
					"social_tier",
					"common"
				)
			),
			"value_band": str(
				property_contract.get(
					"value_band",
					"entry"
				)
			),
			"filter_tags": filter_tags,
			"ownership_modes": _safe_array(
				property_contract.get(
					"ownership_modes",
					[]
				)
			),
			"ownership_status": legal_status,
			"availability": "owned_not_for_sale",
			"feature_tags": _safe_array(
				property_contract.get(
					"feature_tags",
					[]
				)
			),
			"requirement_tags": _safe_array(
				property_contract.get(
					"requirement_tags",
					[]
				)
			),
			"portfolio_tags": _safe_array(
				property_contract.get(
					"portfolio_tags",
					[]
				)
			),
			"status_summary": [
				legal_status.capitalize()
			],
			"operational_summary": [],
			"amenity_synthesis_contract": _safe_dictionary(
				property_contract.get(
					"amenity_synthesis_contract",
					{}
				)
			),
			"amenity_contracts": _safe_array(
				property_contract.get(
					"amenity_contracts",
					[]
				)
			),
			"amenities": _safe_array(
				property_contract.get(
					"amenities",
					[]
				)
			),
			"amenity_ids": _safe_array(
				property_contract.get(
					"amenity_ids",
					[]
				)
			),
			"amenity_summary": str(
				property_contract.get(
					"amenity_summary",
					"No resolved amenities"
				)
			),
			"vehicle_storage_capacity": int(
				property_contract.get(
					"vehicle_storage_capacity",
					0
				)
			),
			"price": int(
				property_contract.get(
					"value",
					property_contract.get(
						"worth",
						0
					)
				)
			)
		})

	return out


func _property_card_contract(
	_actor: Person,
	row: Dictionary,
	_context: Dictionary = {}
) -> Dictionary:
	var template_id: String = str(
		row.get(
			"template_id",
			""
		)
	).strip_edges()
	var price: int = int(
		row.get(
			"price",
			0
		)
	)
	var feature_tags: Array = _safe_array(
		row.get(
			"feature_tags",
			[]
		)
	)
	var filter_tags: Array = _safe_array(
		row.get(
			"filter_tags",
			feature_tags
		)
	)
	var display_name: String = str(
		row.get(
			"display_name",
			"Property"
		)
	)
	var category: String = str(
		row.get(
			"category",
			row.get(
				"archetype",
				"residential"
			)
		)
	).strip_edges().to_lower()
	var ownership_modes: Array = _safe_array(
		row.get(
			"ownership_modes",
			[
				"buy",
				"rent",
				"mortgage"
			]
		)
	)
	var ownership_status: String = str(
		row.get(
			"ownership_status",
			"available"
		)
	).strip_edges().to_lower()
	var availability: String = str(
		row.get(
			"availability",
			"available"
		)
	).strip_edges().to_lower()
	var available_listing: bool = (
		ownership_status == "available"
		and availability == "available"
	)
	var can_buy_outright: bool = (
		available_listing
		and ownership_modes.has("buy")
	)
	var can_rent: bool = (
		available_listing
		and ownership_modes.has("rent")
	)
	var can_mortgage: bool = (
		available_listing
		and ownership_modes.has("mortgage")
	)
	var monthly_rent: int = maxi(
		1,
		int(
			round(
				float(price) * 0.008
			)
		)
	)
	var down_payment: int = maxi(
		1,
		int(
			round(
				float(price) * 0.2
			)
		)
	)
	var monthly_mortgage: int = maxi(
		1,
		int(
			round(
				float(price) * 0.0065
			)
		)
	)

	if not filter_tags.has(category):
		filter_tags.append(category)

	if not filter_tags.has(ownership_status):
		filter_tags.append(ownership_status)

	if (
		availability == "available"
		and not filter_tags.has("available")
	):
		filter_tags.append("available")

	var actions: Array = [
		{
			"action_id": "inspect",
			"label": "Inspect",
			"disabled": false
		}
	]

	if available_listing:
		actions.append({
			"action_id": "buy_outright",
			"label": "Buy Outright",
			"disabled": not can_buy_outright,
			"disabled_reason": "This property contract is not available for outright purchase."
		})
		actions.append({
			"action_id": "rent_monthly",
			"label": "Pay Monthly Rent",
			"disabled": not can_rent,
			"disabled_reason": "This property contract is not offered as a rental."
		})
		actions.append({
			"action_id": "apply_mortgage",
			"label": "Apply For Mortgage",
			"disabled": not can_mortgage,
			"disabled_reason": "This property contract is not mortgage-eligible."
		})

	var variation_contracts: Array = (
		_property_listing_variation_contracts(
			row,
			price
		)
	)
	var default_variation_index: int = 0

	if variation_contracts.size() > 1:
		default_variation_index = 1

	var default_variation: Dictionary = {}

	if not variation_contracts.is_empty():
		default_variation = _safe_dictionary(
			variation_contracts [
				default_variation_index
			]
		)

	var resolved_price: int = int(
		default_variation.get(
			"price",
			price
		)
	)
	var resolved_monthly_rent: int = int(
		default_variation.get(
			"monthly_rent",
			monthly_rent
		)
	)
	var resolved_down_payment: int = int(
		default_variation.get(
			"mortgage_down_payment",
			down_payment
		)
	)
	var resolved_monthly_mortgage: int = int(
		default_variation.get(
			"mortgage_monthly_payment",
			monthly_mortgage
		)
	)

	var resident_template_raw: Variant = row.get(
		"property_template_contract",
		row.get(
			"resident_property_template_contract",
			{}
		)
	)

	var resident_template: Dictionary = (
		resident_template_raw as Dictionary
		if typeof(resident_template_raw) == TYPE_DICTIONARY
		else {}
	)

	return {
		"schema": "eralife.market.property_market.card_contract",
		"version": CONTRACT_VERSION,
		"listing_id": _listing_id(
			"property",
			template_id
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
				"Maintained"
			)
		),
		"condition": float(
			default_variation.get(
				"condition",
				100.0
			)
		),
		"condition_text": str(
			default_variation.get(
				"condition_text",
				"Maintained"
			)
		),
		"condition_applicable": bool(
			default_variation.get(
				"condition_applicable",
				true
			)
		),
		"template_id": template_id,
		"resident_property_template_contract": (
			resident_template.duplicate(false)
		),
		"title": display_name,
		"display_name": display_name,
		"category": category,
		"subtype": str(
			row.get(
				"subtype",
				""
			)
		),
		"filter_tags": filter_tags,
		"ownership_modes": ownership_modes,
		"ownership_status": ownership_status,
		"availability": availability,
		"price": resolved_price,
		"price_text": str(
			default_variation.get(
				"price_text",
				_format_money(
					resolved_price
				)
			)
		),
		"monthly_rent": resolved_monthly_rent,
		"monthly_rent_text": str(
			default_variation.get(
				"monthly_rent_text",
				_format_money(
					resolved_monthly_rent
				)
			)
		),
		"mortgage_down_payment": resolved_down_payment,
		"mortgage_down_payment_text": str(
			default_variation.get(
				"mortgage_down_payment_text",
				_format_money(
					resolved_down_payment
				)
			)
		),
		"mortgage_monthly_payment": resolved_monthly_mortgage,
		"mortgage_monthly_payment_text": str(
			default_variation.get(
				"mortgage_monthly_payment_text",
				_format_money(
					resolved_monthly_mortgage
				)
			)
		),
		"social_tier": str(
			row.get(
				"social_tier",
				"common"
			)
		),
		"value_band": str(
			row.get(
				"value_band",
				"entry"
			)
		),
		"feature_tags": feature_tags,
		"requirement_tags": _safe_array(
			row.get(
				"requirement_tags",
				[]
			)
		),
		"portfolio_tags": _safe_array(
			row.get(
				"portfolio_tags",
				[]
			)
		),
		"status_summary": _safe_array(
			row.get(
				"status_summary",
				[]
			)
		),
		"operational_summary": _safe_array(
			row.get(
				"operational_summary",
				[]
			)
		),
		"amenity_synthesis_contract": _safe_dictionary(
			row.get(
				"amenity_synthesis_contract",
				{}
			)
		),
		"amenity_contracts": _safe_array(
			row.get(
				"amenity_contracts",
				[]
			)
		),
		"amenities": _safe_array(
			row.get(
				"amenities",
				[]
			)
		),
		"amenity_ids": _safe_array(
			row.get(
				"amenity_ids",
				[]
			)
		),
		"amenity_summary": str(
			row.get(
				"amenity_summary",
				"No resolved amenities"
			)
		),
		"vehicle_storage_capacity": int(
			row.get(
				"vehicle_storage_capacity",
				0
			)
		),
		"actions": actions,
		"buy_disabled": not can_buy_outright,
		"buy_disabled_reason": "This property contract is not available for outright purchase.",
		"meta_line": "%s • %s • %s" % [
			category.capitalize(),
			str(
				row.get(
					"value_band",
					"entry"
				)
			).replace("_", " ").capitalize(),
			str(
				row.get(
					"amenity_summary",
					"No amenities"
				)
			)
		],
		"render_kind": "property_contract_card",
		"truth_source": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _resident_property_listing_contract_by_id(
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
					"property_market_contract_engine."
					+ "resident_listing_lookup"
				)
			}
		)
	)
	var surface: Dictionary = _safe_dictionary(
		pack.get(
			"property_market_surface_contract",
			{}
		)
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
		return {}

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
	var prefix: String = (
		"property:%d:" % _current_year()
	)

	if not clean_listing_id.begins_with(
		prefix
	):
		return {}

	var template_id: String = (
		clean_listing_id.trim_prefix(
			prefix
		)
	)

	var registry_raw: Variant = (
		resident_listing_contract_by_id.get(
			clean_listing_id,
			{}
		)
	)

	if typeof(registry_raw) == TYPE_DICTIONARY:
		var registered_listing: Dictionary = (
			registry_raw as Dictionary
		)

		if (
			not registered_listing.is_empty()
			and str(
				registered_listing.get(
					"template_id",
					""
				)
			) == template_id
		):
			var resolved: Dictionary = (
				registered_listing.duplicate(false)
			)
			resolved [
				"resolved_from_resident_listing_registry"
			] = true
			resolved [
				"listing_regeneration_performed_on_click"
			] = false
			return resolved

	var resident_listing: Dictionary = (
		_resident_property_listing_contract_by_id(
			actor,
			clean_listing_id
		)
	)

	if (
		not resident_listing.is_empty()
		and str(
			resident_listing.get(
				"template_id",
				""
			)
		) == template_id
	):
		resident_listing [
			"resolved_from_resident_surface_cache"
		] = true
		resident_listing [
			"listing_regeneration_performed_on_click"
		] = false
		return resident_listing

	var observed_raw: Variant = context.get(
		"resident_listing_contract",
		{}
	)

	if typeof(observed_raw) == TYPE_DICTIONARY:
		var observed: Dictionary = (
			observed_raw as Dictionary
		)

		if (
			str(
				observed.get(
					"listing_id",
					""
				)
			) == clean_listing_id
			and str(
				observed.get(
					"template_id",
					""
				)
			) == template_id
		):
			var resolved_observed: Dictionary = (
				observed.duplicate(false)
			)
			resolved_observed [
				"resolved_from_observed_immutable_card"
			] = true
			resolved_observed [
				"listing_regeneration_performed_on_click"
			] = false
			return resolved_observed


	return {}


func _result_with_surface(
	_actor: Person,
	success: bool,
	text: String,
	_context: Dictionary = {}
) -> Dictionary:
	return {
		"success": success,
		"committed": success,
		"text": text,
		"popup_title": "Property Market",
		"popup_text": text,
		"popup_footer": (
			"The resident market remains observable. "
			+ "Portfolio truth will reconcile behind it."
		),
		"surface_contract": {},
		"affected_asset_domain": "property",
		"background_portfolio_reconcile_requested": success,
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}


func _purchase_context_from_listing(
	listing: Dictionary,
	action_id: String,
	action_context: Dictionary = {}
) -> Dictionary:
	var resident_template_raw: Variant = listing.get(
		"resident_property_template_contract",
		listing.get(
			"property_template_contract",
			{}
		)
	)

	var resident_template: Dictionary = (
		resident_template_raw as Dictionary
		if typeof(resident_template_raw) == TYPE_DICTIONARY
		else {}
	)

	var resident_amenity_raw: Variant = listing.get(
		"amenity_synthesis_contract",
		{}
	)

	var resident_amenity: Dictionary = (
		resident_amenity_raw as Dictionary
		if typeof(resident_amenity_raw) == TYPE_DICTIONARY
		else {}
	)

	var amenity_contracts_raw: Variant = listing.get(
		"amenity_contracts",
		[]
	)
	var amenity_contracts: Array = (
		amenity_contracts_raw as Array
		if typeof(amenity_contracts_raw) == TYPE_ARRAY
		else []
	)

	var amenities_raw: Variant = listing.get(
		"amenities",
		[]
	)
	var amenities: Array = (
		amenities_raw as Array
		if typeof(amenities_raw) == TYPE_ARRAY
		else []
	)

	var amenity_ids_raw: Variant = listing.get(
		"amenity_ids",
		[]
	)
	var amenity_ids: Array = (
		amenity_ids_raw as Array
		if typeof(amenity_ids_raw) == TYPE_ARRAY
		else []
	)

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

		"resident_listing_contract": (
			listing.duplicate(false)
		),

		"resident_property_template_contract": (
			resident_template.duplicate(false)
		),

		"resident_amenity_synthesis_contract": (
			resident_amenity.duplicate(false)
		),

		"amenity_contracts": (
			amenity_contracts.duplicate(false)
		),
		"amenities": (
			amenities.duplicate(false)
		),
		"amenity_ids": (
			amenity_ids.duplicate(false)
		),

		"amenity_summary": str(
			listing.get(
				"amenity_summary",
				""
			)
		),

		"listing_regeneration_forbidden": true,
		"amenity_resynthesis_forbidden": true,


		"action_context": (
			action_context.duplicate(false)
		)
	}
func _property_inspection_text(listing: Dictionary) -> String:
	return "%s • %s • %s • Rent %s/mo • Mortgage down %s." % [
		str(listing.get("display_name", "Property")),
		str(listing.get("social_tier", "common")).replace("_", " ").capitalize(),
		str(listing.get("value_band", "entry")).replace("_", " ").capitalize(),
		str(listing.get("monthly_rent_text", "")),
		str(listing.get("mortgage_down_payment_text", ""))
	]


func _property_meta_line(row: Dictionary) -> String:
	var parts: Array = []
	parts.append(str(row.get("social_tier", "common")).replace("_", " ").capitalize())
	parts.append(str(row.get("value_band", "entry")).replace("_", " ").capitalize())
	for raw_tag in _safe_array(row.get("feature_tags", [])):
		if parts.size() >= 5:
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


func _fallback_property_rows(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		gs == null
		or gs.property_engine == null
	):
		return out

	for size_name in [
		"Small",
		"Medium",
		"Large",
		"Mansion"
	]:
		var template: Dictionary = (
			gs.property_engine
			._legacy_property_from_size(
				size_name
			)
		)

		if template.is_empty():
			continue

		var price: int = (
			gs.property_engine
			._calculate_property_value(
				template,
				actor,
				{}
			)
		)

		out.append({
			"template_id": str(
				template.get(
					"template_id",
					""
				)
			),



			"property_template_contract": (
				template.duplicate(false)
			),

			"display_name": str(
				template.get(
					"display_name",
					"Property"
				)
			),
			"subtype": str(
				template.get(
					"subtype",
					""
				)
			),
			"social_tier": str(
				template.get(
					"social_tier",
					"common"
				)
			),
			"value_band": str(
				template.get(
					"value_band",
					"entry"
				)
			),
			"feature_tags": _safe_array(
				template.get(
					"feature_tags",
					[]
				)
			),
			"requirement_tags": _safe_array(
				template.get(
					"requirement_tags",
					[]
				)
			),
			"portfolio_tags": _safe_array(
				template.get(
					"portfolio_tags",
					[]
				)
			),
			"status_summary": [],
			"operational_summary": [],
			"price": price
		})

	return out
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

	var current_era: String = (
		_current_era_name()
		.to_lower()
	)
	var candidates: Array = []
	var inspected: int = 0

	for raw_key in resident_listing_contract_by_id.keys():
		if inspected >= 96:
			break

		inspected += 1

		var card: Dictionary = _safe_dictionary(
			resident_listing_contract_by_id.get(
				raw_key,
				{}
			)
		)

		if card.is_empty():
			continue

		var availability: String = str(
			card.get(
				"availability",
				"available"
			)
		).strip_edges().to_lower()

		if availability != "available":
			continue

		var resident_template: Dictionary = (
			_safe_dictionary(
				card.get(
					"resident_property_template_contract",
					{}
				)
			)
		)
		var template_era: String = str(
			resident_template.get(
				"era",
				resident_template.get(
					"era_name",
					""
				)
			)
		).strip_edges().to_lower()

		if (
			template_era != ""
			and current_era != ""
			and template_era != current_era
		):
			continue

		var price: int = int(
			card.get(
				"price",
				0
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
		var tags: Array = _safe_array(
			card.get(
				"feature_tags",
				[]
			)
		)

		var luxury_candidate: bool = (
			price >= 750000
			or category.find("penthouse") >= 0
			or category.find("estate") >= 0
			or category.find("palace") >= 0
			or title.find("penthouse") >= 0
			or title.find("estate") >= 0
			or title.find("palace") >= 0
			or title.find("orbital") >= 0
			or title.find("lunar") >= 0
			or tags.has("luxury")
			or tags.has("penthouse")
			or tags.has("estate")
			or tags.has("orbital")
		)

		if not luxury_candidate:
			continue

		card = card.duplicate(false)
		card [
			"luxury_exchange_source_authority"
		] = ENGINE_SCHEMA
		card [
			"luxury_exchange_actor_id"
		] = int(actor.id)
		card [
			"luxury_exchange_commit_revalidates_actor"
		] = true

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
func _listing_id(kind: String, template_id: String) -> String:
	return "%s:%s:%s" % [kind, str(_current_year()), template_id]


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
func _property_listing_variation_contracts(
	row: Dictionary,
	base_price: int
) -> Array:
	var template_id: String = str(
		row.get(
			"template_id",
			"property"
		)
	)
	var current_year: int = (
		int(gs.year)
		if gs != null
		else 0
	)
	var seed_source: String = (
		"%s|%d|%d|property_variations" % [
			template_id,
			base_price,
			current_year
		]
	)
	var variation_seed: int = abs(
		seed_source.hash()
	)
	var conditions: Array = [
		52 + (variation_seed % 12),
		76 + (variation_seed % 13),
		93 + (variation_seed % 8)
	]
	var labels: Array = [
		"As-Is",
		"Maintained",
		"Restored"
	]
	var multipliers: Array = [
		0.86,
		1.0,
		1.12
	]
	var out: Array = []

	for index in range(3):
		var price: int = maxi(
			1,
			int(
				round(
					float(base_price)
					* float(
						multipliers [index]
					)
				)
			)
		)
		var monthly_rent: int = maxi(
			1,
			int(
				round(
					float(price) * 0.008
				)
			)
		)
		var down_payment: int = maxi(
			1,
			int(
				round(
					float(price) * 0.2
				)
			)
		)
		var monthly_mortgage: int = maxi(
			1,
			int(
				round(
					float(price) * 0.0065
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
			"price_text": _format_money(
				price
			),
			"monthly_rent": monthly_rent,
			"monthly_rent_text": _format_money(
				monthly_rent
			),
			"mortgage_down_payment": down_payment,
			"mortgage_down_payment_text": _format_money(
				down_payment
			),
			"mortgage_monthly_payment": monthly_mortgage,
			"mortgage_monthly_payment_text": _format_money(
				monthly_mortgage
			),
			"contract_authority": ENGINE_SCHEMA
		})

	return out

func _property_listing_with_selected_variation(
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

	var variations_raw: Variant = listing.get(
		"variation_contracts",
		[]
	)

	var variations: Array = (
		variations_raw as Array
		if typeof(variations_raw) == TYPE_ARRAY
		else []
	)

	for raw_variation in variations:
		if typeof(raw_variation) != TYPE_DICTIONARY:
			continue

		var variation: Dictionary = (
			raw_variation as Dictionary
		)

		if str(
			variation.get(
				"variation_id",
				""
			)
		) != requested_id:
			continue



		var resolved: Dictionary = (
			listing.duplicate(false)
		)

		for key in variation.keys():
			if key == "contract_authority":
				continue

			resolved [key] = variation [key]

		resolved [
			"selected_variation_id"
		] = requested_id

		resolved [
			"selected_variation_contract"
		] = variation.duplicate(false)

		resolved [
			"purchase_variation_deep_copy_performed"
		] = false

		return resolved

	return listing

func _format_money(amount: int) -> String:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("format_money"):
		return str(gs.economy_engine.format_money(amount))
	return "$%d" % amount


func _market_currency_contract() -> Dictionary:
	return {
		"name": "USD",
		"symbol": "$",
		"base_unit": 1
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []