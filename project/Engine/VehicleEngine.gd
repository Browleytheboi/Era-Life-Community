extends Resource
class_name VehicleEngine

const ENGINE_SCHEMA:= "eralife.vehicle_contract_engine"
const ASSET_CONTRACT_SCHEMA:= "eralife.vehicle_asset_contract"
const PORTFOLIO_CONTRACT_SCHEMA:= "eralife.vehicle_portfolio_contract"
const ACTION_CONTRACT_SCHEMA:= "eralife.vehicle_action_contract"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "vehicle_contract_engine_state"

var gs: GameState = null




var vehicles: Dictionary = {}

var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var _bound_event_bus_instance_id: int = -1


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_contract_state()
	_bind_contract_events()


func contract() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"engine_file": "VehicleEngine.gd",
		"internal_role": "VehicleContractEngine",
		"asset_contract_schema": ASSET_CONTRACT_SCHEMA,
		"portfolio_contract_schema": PORTFOLIO_CONTRACT_SCHEMA,
		"action_contract_schema": ACTION_CONTRACT_SCHEMA,
		"runtime_truth_authority": true,
		"catalog_authority": "EraLifeAssetCatalogExpansion",
		"market_authority": "DealershipContractEngine",
		"storage_authority": "VehicleEngine",
		"living_transport_authorities": [
			"AnimalContractEngine",
			"MythicalContractEngine"
		],
		"mutation_flow": [
			"intent",
			"vehicle_contract_resolution",
			"reality_mutation",
			"continuous_reality_rendering",
			"ui_lens"
		],
		"ui_is_renderer_only": true
	}


func get_contract() -> Dictionary:
	return contract()


func emit_vehicle_portfolio_contract(
	owner: Person,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null:
		return {
			"success": false,
			"schema": PORTFOLIO_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_owner",
			"vehicle_contracts": []
		}

	var vehicle_contracts: Array = []

	for raw_vehicle in _safe_array(
		vehicles.get(owner.id, [])
	):
		var vehicle: Dictionary = _safe_dictionary(raw_vehicle)

		if vehicle.is_empty():
			continue

		vehicle_contracts.append(
			_vehicle_asset_contract(
				owner,
				vehicle,
				context
			)
		)

	var report: Dictionary = {
		"success": true,
		"schema": PORTFOLIO_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"owner_id": int(owner.id),
		"vehicle_contracts": vehicle_contracts,
		"vehicle_count": vehicle_contracts.size(),
		"source_engine": ENGINE_SCHEMA,
		"runtime_truth_authority": true,
		"ui_is_renderer_only": true,
		"context": context.duplicate(true)
	}

	last_contract_report = report.duplicate(true)
	_publish_contract_state(
		"vehicle_portfolio_emitted"
	)

	return report


func resolve_vehicle_asset_contract(
	owner: Person,
	asset_id: int,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null or asset_id <= 0:
		return {}

	for raw_vehicle in _safe_array(
		vehicles.get(owner.id, [])
	):
		var vehicle: Dictionary = _safe_dictionary(raw_vehicle)

		if int(vehicle.get("id", -1)) != asset_id:
			continue

		return _vehicle_asset_contract(
			owner,
			vehicle,
			context
		)

	return {}


func commit_vehicle_contract_action(
	actor: Person,
	intent_contract: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_actor",
			"text": "No vehicle actor was provided."
		}

	var asset_id: int = int(
		intent_contract.get(
			"asset_id",
			intent_contract.get(
				"vehicle_id",
				-1
			)
		)
	)
	var action_id: String = str(
		intent_contract.get(
			"action_id",
			intent_contract.get(
				"vehicle_action",
				""
			)
		)
	).strip_edges()

	if asset_id <= 0:
		return {
			"success": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_asset_id",
			"text": "No vehicle asset was selected."
		}

	if action_id == "":
		return {
			"success": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_action_id",
			"text": "No vehicle action was selected."
		}

	var mutation_report: Dictionary = run_asset_action(
		actor,
		asset_id,
		action_id
	)

	mutation_report ["schema"] = ACTION_CONTRACT_SCHEMA
	mutation_report ["version"] = CONTRACT_VERSION
	mutation_report ["actor_id"] = int(actor.id)
	mutation_report ["asset_id"] = asset_id
	mutation_report ["action_id"] = action_id
	mutation_report ["source_engine"] = ENGINE_SCHEMA
	mutation_report ["reality_mutation_committed"] = bool(
		mutation_report.get("success", false)
	)
	mutation_report ["ui_is_renderer_only"] = true
	mutation_report ["intent_contract"] = intent_contract.duplicate(true)

	last_contract_report = mutation_report.duplicate(true)
	_publish_contract_state(
		"vehicle_action_committed"
	)

	return mutation_report


func _vehicle_asset_contract(
	owner: Person,
	vehicle: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var asset_id: int = int(
		vehicle.get(
			"id",
			-1
		)
	)
	var owner_id: int = (
		int(owner.id)
		if owner != null
		else -1
	)
	var living_transport: bool = bool(
		vehicle.get(
			"living_transport",
			false
		)
	)
	var condition_applicable: bool = bool(
		vehicle.get(
			"condition_applicable",
			not living_transport
		)
	)
	var color_name: String = str(
		vehicle.get(
			"color_name",
			"Factory Finish"
		)
	)
	var color_hex: String = str(
		vehicle.get(
			"color_hex",
			"7A8494"
		)
	).trim_prefix("#")
	var restricted_vehicle: bool = bool(
		vehicle.get(
			"restricted_vehicle",
			false
		)
	)
	var weapon_platform: bool = bool(
		vehicle.get(
			"weapon_platform",
			false
		)
	)
	var requires_underground_bunker: bool = bool(
		vehicle.get(
			"requires_underground_bunker",
			false
		)
	)

	return {
		"success": asset_id > 0,
		"schema": ASSET_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"asset_id": asset_id,
		"owner_id": owner_id,
		"template_id": str(
			vehicle.get(
				"template_id",
				""
			)
		),
		"name": _vehicle_display_name(
			vehicle
		),
		"brand": str(
			vehicle.get(
				"brand",
				""
			)
		),
		"model": str(
			vehicle.get(
				"model",
				vehicle.get(
					"display_name",
					"Vehicle"
				)
			)
		),
		"category": str(
			vehicle.get(
				"category",
				vehicle.get(
					"subtype",
					"mobility"
				)
			)
		),
		"movement_type": str(
			vehicle.get(
				"movement_type",
				"unknown"
			)
		),
		"seats": int(
			vehicle.get(
				"seats",
				1
			)
		),
		"terrain": _safe_array(
			vehicle.get(
				"terrain",
				[]
			)
		),
		"fuel": str(
			vehicle.get(
				"fuel",
				"none"
			)
		),
		"monthly_cost": int(
			vehicle.get(
				"monthly_cost",
				0
			)
		),
		"ownership_status": str(
			vehicle.get(
				"ownership_status",
				vehicle.get(
					"legal_status",
					"owned"
				)
			)
		),
		"availability": str(
			vehicle.get(
				"availability",
				"owned_not_for_sale"
			)
		),
		"condition": float(
			vehicle.get(
				"condition",
				100.0
			)
		),
		"condition_label": (
			str(
				vehicle.get(
					"condition_label",
					"Excellent"
				)
			)
			if condition_applicable
			else "Living"
		),
		"condition_applicable": condition_applicable,
		"living_transport": living_transport,
		"value": int(
			vehicle.get(
				"value",
				vehicle.get(
					"worth",
					0
				)
			)
		),
		"storage_status": str(
			vehicle.get(
				"storage_status",
				"unstored"
			)
		),
		"stored_at_property_id": int(
			vehicle.get(
				"stored_at_property_id",
				-1
			)
		),
		"stored_at_property_name": str(
			vehicle.get(
				"stored_at_property_name",
				""
			)
		),
		"physical_location_kind": str(
			vehicle.get(
				"physical_location_kind",
				(
					"property_storage"
					if int(
						vehicle.get(
							"stored_at_property_id",
							-1
						)
					) > 0
					else "with_owner"
				)
			)
		),
		"color_name": color_name,
		"color_hex": color_hex,
		"color_visual_contract": _safe_dictionary(
			vehicle.get(
				"color_visual_contract",
				{
					"name": color_name,
					"hex": color_hex,
					"swatch_visible": true,
					"ui_is_renderer_only": true
				}
			)
		),
		"restricted_vehicle": restricted_vehicle,
		"weapon_platform": weapon_platform,
		"requires_underground_bunker": (
			requires_underground_bunker
		),
		"storage_requirement": str(
			vehicle.get(
				"storage_requirement",
				(
					"underground_bunker"
					if requires_underground_bunker
					else "standard_vehicle_storage"
				)
			)
		),
		"feature_tags": _safe_array(
			vehicle.get(
				"feature_tags",
				[]
			)
		),
		"filter_tags": _safe_array(
			vehicle.get(
				"filter_tags",
				vehicle.get(
					"feature_tags",
					[]
				)
			)
		),
		"action_ids": _safe_array(
			vehicle.get(
				"action_ids",
				[]
			)
		),
		"source_engine": ENGINE_SCHEMA,
		"runtime_truth_authority": true,
		"ui_is_renderer_only": true,
		"context": context.duplicate(true)
	}


func _bind_contract_events() -> void:
	if gs == null or gs.event_bus == null:
		return

	var event_bus_instance_id: int = int(
		gs.event_bus.get_instance_id()
	)

	if (
		event_bus_instance_id
		== _bound_event_bus_instance_id
	):
		return

	gs.event_bus.subscribe(
		ActionEventTypes.YEAR_PASSED,
		self,
		"yearly_asset_ecology_tick"
	)
	gs.event_bus.subscribe(
		ActionEventTypes.NPC_DIED,
		self,
		"handle_inheritance"
	)

	_bound_event_bus_instance_id = event_bus_instance_id


func _ensure_contract_state() -> void:
	active_contract = contract()

	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			STATE_KEY,
			{}
		)
	)

	state ["schema"] = ENGINE_SCHEMA
	state ["version"] = CONTRACT_VERSION
	state ["engine_file"] = "VehicleEngine.gd"
	state ["internal_role"] = "VehicleContractEngine"
	state ["runtime_truth_authority"] = true
	state ["ui_is_renderer_only"] = true
	state ["vehicle_owner_bucket_count"] = vehicles.size()
	state ["contract"] = active_contract.duplicate(true)

	gs.scenario_state [STATE_KEY] = state


func _publish_contract_state(reason: String) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			STATE_KEY,
			{}
		)
	)

	state ["schema"] = ENGINE_SCHEMA
	state ["version"] = CONTRACT_VERSION
	state ["reason"] = reason
	state ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	state ["vehicle_owner_bucket_count"] = vehicles.size()
	state ["last_contract_report"] = last_contract_report.duplicate(true)
	state ["contract"] = contract()

	gs.scenario_state [STATE_KEY] = state

func buy_vehicle(
	buyer: Person,
	type_or_template,
	price_override:= -1,
	luxury_level:= 0,
	purchase_context:= {}
) -> Dictionary:
	if buyer == null:
		return {
			"success": false,
			"text": "No buyer provided."
		}

	var clean_context: Dictionary = (
		_safe_dictionary(
			purchase_context
		)
	)
	var template: Dictionary = _resolve_vehicle_template(
		type_or_template,
		luxury_level,
		clean_context
	)

	if template.is_empty():
		return {
			"success": false,
			"text": (
				"No valid transport template could be resolved."
			)
		}

	var storage_validation: Dictionary = (
		_validate_vehicle_storage_destination(
			buyer,
			template,
			str(
				clean_context.get(
					"storage_destination_id",
					""
				)
			)
		)
	)

	if not bool(
		storage_validation.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"reason": str(
				storage_validation.get(
					"reason",
					"storage_validation_failed"
				)
			),
			"text": str(
				storage_validation.get(
					"text",
					"Choose where this vehicle should be stored."
				)
			),
			"requires_storage_choice": bool(
				storage_validation.get(
					"requires_storage_choice",
					false
				)
			),
			"storage_choice_contract": (
				storage_validation.get(
					"storage_choice_contract",
					{}
				)
			)
		}

	var final_price: int = int(
		price_override
	)

	if final_price < 0:
		final_price = _calculate_vehicle_value(
			template,
			buyer,
			clean_context
		)

	if int(buyer.bank_balance) < final_price:
		return {
			"success": false,
			"text": "Not enough money."
		}

	var destination_id: String = str(
		storage_validation.get(
			"destination_id",
			"belongings"
		)
	)
	var vehicle: Dictionary = (
		_build_runtime_vehicle_from_template(
			template,
			buyer,
			clean_context
		)
	)

	vehicle ["value"] = final_price
	vehicle ["worth"] = final_price
	vehicle ["source_engine"] = "vehicle_engine"


	buyer.bank_balance -= final_price

	_register_vehicle_for_owner(
		buyer,
		vehicle,
		false
	)

	var storage_report: Dictionary = (
		_commit_initial_vehicle_storage(
			buyer,
			vehicle,
			destination_id
		)
	)

	if not bool(
		storage_report.get(
			"success",
			false
		)
	):

		buyer.bank_balance += final_price
		_remove_vehicle_refs(
			int(buyer.id),
			int(
				vehicle.get(
					"id",
					-1
				)
			)
		)

		if (
			gs != null
			and gs.belongings_engine != null
		):
			gs.belongings_engine.remove_item_by_id(
				buyer,
				"Vehicles",
				int(
					vehicle.get(
						"id",
						-1
					)
				)
			)

		return {
			"success": false,
			"text": str(
				storage_report.get(
					"text",
					"Vehicle storage failed; the purchase was rolled back."
				)
			)
		}

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.VEHICLE_PURCHASED,
			{
				"npc_id": int(buyer.id),
				"text": "%s %s purchased %s." % [
					buyer.first_name,
					buyer.last_name,
					_vehicle_display_name(
						vehicle
					)
				],
				"data": {
					"asset_id": int(
						vehicle.get(
							"id",
							-1
						)
					),
					"template_id": str(
						vehicle.get(
							"template_id",
							""
						)
					),
					"feature_tags": _safe_array(
						vehicle.get(
							"feature_tags",
							[]
						)
					),
					"prestige_signals": _safe_dictionary(
						vehicle.get(
							"prestige_signals",
							{}
						)
					),
					"storage_destination_id": destination_id
				}
			}
		)

	return {
		"success": true,
		"text": "Purchased %s. %s" % [
			_vehicle_display_name(
				vehicle
			),
			str(
				storage_report.get(
					"text",
					""
				)
			)
		],
		"asset_id": int(
			vehicle.get(
				"id",
				-1
			)
		),
		"vehicle_contract": vehicle.duplicate(true),
		"storage_report": storage_report,
		"storage_destination_id": destination_id
	}



func _vehicle_is_living_transport(
	vehicle: Dictionary
) -> bool:
	return (
		bool(
			vehicle.get(
				"living_transport",
				false
			)
		)
		or not bool(
			vehicle.get(
				"condition_applicable",
				true
			)
		)
	)


func _property_display_name(
	property_contract: Dictionary
) -> String:
	var nickname: String = str(
		property_contract.get("nickname", "")
	).strip_edges()

	if nickname != "":
		return nickname

	return str(
		property_contract.get(
			"display_name",
			property_contract.get(
				"type",
				"Property"
			)
		)
	)


func _vehicle_property_operational_profile(
	property_contract: Dictionary
) -> Dictionary:
	var profile_raw: Variant = property_contract.get(
		"operational_profile",
		{}
	)

	return (
		profile_raw as Dictionary
		if typeof(profile_raw) == TYPE_DICTIONARY
		else {}
	)


func _vehicle_property_storage_capacity(
	property_contract: Dictionary
) -> int:
	var profile: Dictionary = _vehicle_property_operational_profile(
		property_contract
	)

	return maxi(
		0,
		int(
			property_contract.get(
				"vehicle_storage_capacity",
				profile.get(
					"vehicle_storage_capacity",
					0
				)
			)
		)
	)


func _vehicle_property_storage_protection_multiplier(
	property_contract: Dictionary
) -> float:
	var amenity_ids: Array = _safe_array(
		property_contract.get("amenity_ids", [])
	)
	var feature_tags: Array = _safe_array(
		property_contract.get("feature_tags", [])
	)
	var searchable: String = "%s %s %s %s" % [
		str(
			property_contract.get(
				"display_name",
				""
			)
		),
		str(
			property_contract.get("type", "")
		),
		" ".join(amenity_ids),
		" ".join(feature_tags)
	]
	searchable = searchable.to_lower()

	for protected_key in [
		"autonomous_garage",
		"underground_parking",
		"airport_hangar",
		"hangar",
		"bunker",
		"secured_garage",
		"climate_controlled_garage",
		"nanite_repair_system"
	]:
		if searchable.find(
			str(protected_key)
		) >= 0:
			return 0.3

	for covered_key in [
		"garage",
		"stable",
		"carriage_house",
		"covered_parking",
		"boat_house",
		"sky_dock",
		"private_harbor"
	]:
		if searchable.find(
			str(covered_key)
		) >= 0:
			return 0.48

	return 0.68


func _owned_property_storage_options(
	owner: Person,
	vehicle_contract: Dictionary = {}
) -> Array:
	var out: Array = []

	if (
		owner == null
		or gs == null
		or gs.property_engine == null
		or not gs.property_engine.properties.has(
			owner.id
		)
	):
		return out

	var seen: Dictionary = {}
	var requires_bunker: bool = (
		_vehicle_requires_underground_bunker(
			vehicle_contract
		)
	)

	for raw_property in gs.property_engine.properties.get(
		owner.id,
		[]
	):
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var property_contract: Dictionary = (
			raw_property as Dictionary
		)
		var property_id: int = int(
			property_contract.get(
				"id",
				-1
			)
		)

		if (
			property_id <= 0
			or seen.has(property_id)
		):
			continue

		seen [property_id] = true

		var capacity: int = (
			_vehicle_property_storage_capacity(
				property_contract
			)
		)
		var used: int = 0

		for raw_item in _safe_array(
			property_contract.get(
				"storage_contents",
				[]
			)
		):
			if (
				typeof(raw_item) == TYPE_DICTIONARY
				and str(
					raw_item.get(
						"asset_kind",
						""
					)
				) == "transport"
			):
				used += 1

		var bunker_compatible: bool = (
			_property_has_underground_bunker(
				property_contract
			)
		)
		var requirement_satisfied: bool = (
			not requires_bunker
			or bunker_compatible
		)

		out.append({
			"destination_id": (
				"property:%d" % property_id
			),
			"destination_kind": "property",
			"property_id": property_id,
			"display_name": _property_display_name(
				property_contract
			),
			"capacity": capacity,
			"used": used,
			"available_slots": maxi(
				0,
				capacity - used
			),
			"requires_underground_bunker": (
				requires_bunker
			),
			"property_has_underground_bunker": (
				bunker_compatible
			),
			"storage_requirement_satisfied": (
				requirement_satisfied
			),
			"can_store_vehicle": (
				used < capacity
				and requirement_satisfied
			),
			"disabled_reason": (
				""
				if (
					used < capacity
					and requirement_satisfied
				)
				else (
					"This vehicle requires an underground bunker."
					if not requirement_satisfied
					else (
						"%s has no open vehicle storage slots."
						% _property_display_name(
							property_contract
						)
					)
				)
			)
		})

	return out
func _vehicle_requires_underground_bunker(
	vehicle_contract: Dictionary
) -> bool:
	if vehicle_contract.is_empty():
		return false

	if bool(
		vehicle_contract.get(
			"requires_underground_bunker",
			false
		)
	):
		return true

	var tags: Array = _safe_array(
		vehicle_contract.get(
			"feature_tags",
			vehicle_contract.get(
				"filter_tags",
				[]
			)
		)
	)

	return (
		tags.has("tank")
		or tags.has("bunker_storage_required")
		or str(
			vehicle_contract.get(
				"storage_requirement",
				""
			)
		) == "underground_bunker"
	)


func _property_has_underground_bunker(
	property_contract: Dictionary
) -> bool:
	if property_contract.is_empty():
		return false

	var searchable_parts:= PackedStringArray([
		str(
			property_contract.get(
				"subtype",
				""
			)
		),
		str(
			property_contract.get(
				"display_name",
				""
			)
		)
	])

	for raw_tag in _safe_array(
		property_contract.get(
			"feature_tags",
			[]
		)
	):
		searchable_parts.append(
			str(raw_tag)
		)

	for raw_amenity in _safe_array(
		property_contract.get(
			"amenity_ids",
			property_contract.get(
				"amenities",
				[]
			)
		)
	):
		searchable_parts.append(
			str(raw_amenity)
		)

	var searchable: String = " ".join(
		searchable_parts
	).to_lower()

	return (
		searchable.find("underground_bunker") >= 0
		or searchable.find("underground bunker") >= 0
		or searchable.find("vehicle_bunker") >= 0
		or searchable.find("military_storage") >= 0
	)


func _actor_restricted_vehicle_clearance_contract(
	actor: Person,
	vehicle_contract: Dictionary
) -> Dictionary:
	var tags: Array = _safe_array(
		vehicle_contract.get(
			"feature_tags",
			vehicle_contract.get(
				"filter_tags",
				[]
			)
		)
	)
	var restricted: bool = (
		bool(
			vehicle_contract.get(
				"restricted_vehicle",
				false
			)
		)
		or tags.has("restricted")
		or tags.has("military_clearance")
		or tags.has("tank")
	)

	if not restricted:
		return {
			"restricted": false,
			"granted": true,
			"clearance_level": "civilian",
			"reason": ""
		}

	if actor == null:
		return {
			"restricted": true,
			"granted": false,
			"clearance_level": "none",
			"reason": "No actor was available for clearance review."
		}

	var authority_parts:= PackedStringArray()

	for field_name in [
		"job",
		"career",
		"occupation",
		"government_role",
		"military_rank",
		"royal_rank",
		"title",
		"social_class"
	]:
		if field_name in actor:
			authority_parts.append(
				str(
					actor.get(
						field_name
					)
				)
			)

	for raw_trait in actor.traits:
		authority_parts.append(
			str(raw_trait)
		)

	var authority_text: String = " ".join(
		authority_parts
	).to_lower()
	var high_authority_terms: Array = [
		"president",
		"prime minister",
		"head of state",
		"emperor",
		"empress",
		"king",
		"queen",
		"monarch",
		"ruler",
		"dictator",
		"supreme leader",
		"secretary of defense",
		"defense minister",
		"minister of defence",
		"general",
		"field marshal",
		"admiral",
		"chief of staff",
		"commander",
		"military high command"
	]
	var matched_term: String = ""

	for raw_term in high_authority_terms:
		var term: String = str(raw_term)

		if authority_text.find(term) >= 0:
			matched_term = term
			break

	var granted: bool = matched_term != ""

	return {
		"restricted": true,
		"granted": granted,
		"clearance_level": (
			"strategic_military_vehicle"
			if granted
			else "insufficient"
		),
		"matched_authority": matched_term,
		"reason": (
			""
			if granted
			else (
				"This vehicle requires high military, government, or ruling-level clearance."
			)
		),
		"actor_id": int(actor.id),
		"contract_authority": ENGINE_SCHEMA
	}


func emit_vehicle_purchase_storage_contract(
	owner: Person,
	vehicle_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null:
		return {
			"success": false,
			"reason": "missing_owner",
			"destination_contracts": []
		}

	var clearance: Dictionary = (
		_actor_restricted_vehicle_clearance_contract(
			owner,
			vehicle_contract
		)
	)
	var requires_bunker: bool = (
		_vehicle_requires_underground_bunker(
			vehicle_contract
		)
	)
	var destinations: Array = []

	if not requires_bunker:
		destinations.append({
			"destination_id": "belongings",
			"destination_kind": "belongings",
			"label": "Keep With My Belongings",
			"description": (
				"The vehicle remains unstored and follows the owner's belongings contract."
			),
			"disabled": false,
			"can_store_vehicle": true
		})

	for raw_option in _owned_property_storage_options(
		owner,
		vehicle_contract
	):
		var option: Dictionary = _safe_dictionary(
			raw_option
		)

		destinations.append({
			"destination_id": str(
				option.get(
					"destination_id",
					""
				)
			),
			"destination_kind": "property",
			"property_id": int(
				option.get(
					"property_id",
					-1
				)
			),
			"label": "Store At %s" % str(
				option.get(
					"display_name",
					"Property"
				)
			),
			"description": "%d of %d vehicle slots available." % [
				int(
					option.get(
						"available_slots",
						0
					)
				),
				int(
					option.get(
						"capacity",
						0
					)
				)
			],
			"disabled": not bool(
				option.get(
					"can_store_vehicle",
					false
				)
			),
			"disabled_reason": str(
				option.get(
					"disabled_reason",
					""
				)
			),
			"can_store_vehicle": bool(
				option.get(
					"can_store_vehicle",
					false
				)
			)
		})

	var enabled_destinations: Array = []

	for raw_destination in destinations:
		var destination: Dictionary = (
			_safe_dictionary(
				raw_destination
			)
		)

		if not bool(
			destination.get(
				"disabled",
				false
			)
		):
			enabled_destinations.append(
				destination
			)

	var default_destination_id: String = ""

	if enabled_destinations.size() == 1:
		default_destination_id = str(
			(
				enabled_destinations [0]
				as Dictionary
			).get(
				"destination_id",
				""
			)
		)
	elif enabled_destinations.is_empty() and not requires_bunker:
		default_destination_id = "belongings"

	return {
		"success": true,
		"schema": (
			"eralife.vehicle.purchase_storage_choice_contract"
		),
		"version": 1,
		"actor_id": int(owner.id),
		"template_id": str(
			vehicle_contract.get(
				"template_id",
				""
			)
		),
		"requires_underground_bunker": requires_bunker,
		"clearance_contract": clearance,
		"clearance_granted": bool(
			clearance.get(
				"granted",
				false
			)
		),
		"destination_contracts": destinations,
		"enabled_destination_count": (
			enabled_destinations.size()
		),
		"has_valid_destination": (
			not enabled_destinations.is_empty()
		),
		"default_destination_id": default_destination_id,
		"requires_choice": (
			enabled_destinations.size() > 1
		),
		"source": str(
			context.get(
				"source",
				ENGINE_SCHEMA
			)
		),
		"ui_is_renderer_only": true
	}


func _validate_vehicle_storage_destination(
	owner: Person,
	vehicle_contract: Dictionary,
	destination_id: String
) -> Dictionary:
	var storage_contract: Dictionary = (
		emit_vehicle_purchase_storage_contract(
			owner,
			vehicle_contract,
			{
				"source": (
					"vehicle_storage_destination_validation"
				)
			}
		)
	)

	if not bool(
		storage_contract.get(
			"clearance_granted",
			false
		)
	):
		return {
			"success": false,
			"reason": "clearance_denied",
			"text": str(
				(
					storage_contract.get(
						"clearance_contract",
						{}
					) as Dictionary
				).get(
					"reason",
					"Clearance denied."
				)
			),
			"storage_choice_contract": storage_contract
		}

	var clean_destination_id: String = (
		destination_id.strip_edges()
	)

	if clean_destination_id == "":
		clean_destination_id = str(
			storage_contract.get(
				"default_destination_id",
				""
			)
		)

	if clean_destination_id == "":
		return {
			"success": false,
			"reason": "storage_choice_required",
			"text": "Choose where this vehicle should be stored.",
			"requires_storage_choice": true,
			"storage_choice_contract": storage_contract
		}

	for raw_destination in _safe_array(
		storage_contract.get(
			"destination_contracts",
			[]
		)
	):
		var destination: Dictionary = _safe_dictionary(
			raw_destination
		)

		if str(
			destination.get(
				"destination_id",
				""
			)
		) != clean_destination_id:
			continue

		if bool(
			destination.get(
				"disabled",
				false
			)
		):
			return {
				"success": false,
				"reason": (
					"storage_destination_disabled"
				),
				"text": str(
					destination.get(
						"disabled_reason",
						"That storage destination is unavailable."
					)
				),
				"storage_choice_contract": storage_contract
			}

		return {
			"success": true,
			"destination_id": clean_destination_id,
			"destination_contract": destination,
			"storage_choice_contract": storage_contract
		}

	return {
		"success": false,
		"reason": "unknown_storage_destination",
		"text": "That storage destination no longer exists.",
		"storage_choice_contract": storage_contract
	}


func _commit_initial_vehicle_storage(
	owner: Person,
	vehicle: Dictionary,
	destination_id: String
) -> Dictionary:
	if destination_id == "belongings":
		vehicle ["storage_status"] = "unstored"
		vehicle ["stored_at_property_id"] = -1
		vehicle ["stored_at_property_name"] = ""
		vehicle ["physical_location_kind"] = "with_owner"

		_replace_vehicle_instance_for_all_owners(
			vehicle
		)
		_sync_vehicle_belongings_projection(
			owner,
			vehicle
		)

		return {
			"success": true,
			"destination_id": "belongings",
			"text": "%s was placed with your belongings." % (
				_vehicle_display_name(
					vehicle
				)
			)
		}

	if destination_id.begins_with("property:"):
		var property_id: int = int(
			destination_id.trim_prefix(
				"property:"
			)
		)

		return _store_vehicle_at_property(
			owner,
			vehicle,
			property_id
		)

	return {
		"success": false,
		"text": "The initial vehicle storage destination was invalid."
	}

func _find_owned_property(
	owner: Person,
	property_id: int
) -> Dictionary:
	if (
		owner == null
		or gs == null
		or gs.property_engine == null
	):
		return {}

	for raw_property in gs.property_engine.properties.get(
		owner.id,
		[]
	):
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var property_contract: Dictionary = (
			raw_property as Dictionary
		)

		if int(
			property_contract.get("id", -1)
		) == property_id:
			return property_contract

	return {}


func _remove_vehicle_from_property_storage(
	owner: Person,
	vehicle: Dictionary
) -> void:
	var property_id: int = int(
		vehicle.get(
			"stored_at_property_id",
			-1
		)
	)

	if property_id <= 0:
		return

	var property_contract: Dictionary = _find_owned_property(
		owner,
		property_id
	)

	if property_contract.is_empty():
		return

	var kept: Array = []

	for raw_item in _safe_array(
		property_contract.get(
			"storage_contents",
			[]
		)
	):
		if typeof(raw_item) != TYPE_DICTIONARY:
			kept.append(raw_item)
			continue

		var storage_item: Dictionary = (
			raw_item as Dictionary
		)

		if (
			str(
				storage_item.get(
					"asset_kind",
					""
				)
			) == "transport"
			and int(
				storage_item.get(
					"asset_id",
					-1
				)
			) == int(
				vehicle.get("id", -1)
			)
		):
			continue

		kept.append(storage_item)

	property_contract ["storage_contents"] = kept

	if gs.property_engine.has_method(
		"_replace_property_for_all_owners"
	):
		gs.property_engine._replace_property_for_all_owners(
			property_contract
		)


func _store_vehicle_at_property(
	owner: Person,
	vehicle: Dictionary,
	property_id: int
) -> Dictionary:
	var property_contract: Dictionary = _find_owned_property(
		owner,
		property_id
	)

	if property_contract.is_empty():
		return {
			"success": false,
			"text": "That property could not be resolved."
		}

	var capacity: int = _vehicle_property_storage_capacity(
		property_contract
	)
	var storage_contents: Array = _safe_array(
		property_contract.get(
			"storage_contents",
			[]
		)
	)
	var used: int = 0

	for raw_item in storage_contents:
		if (
			typeof(raw_item) == TYPE_DICTIONARY
			and str(
				raw_item.get(
					"asset_kind",
					""
				)
			) == "transport"
		):
			used += 1

	if used >= capacity:
		return {
			"success": false,
			"text": "%s has no open vehicle storage slots." % _property_display_name(
				property_contract
			)
		}

	_remove_vehicle_from_property_storage(
		owner,
		vehicle
	)

	storage_contents = _safe_array(
		property_contract.get(
			"storage_contents",
			[]
		)
	)
	storage_contents.append({
		"asset_kind": "transport",
		"asset_id": int(
			vehicle.get("id", -1)
		),
		"display_name": _vehicle_display_name(
			vehicle
		),
		"owner_id": int(owner.id),
		"stored_year": int(gs.year),
	})

	property_contract ["storage_contents"] = storage_contents
	vehicle ["storage_status"] = "stored"
	vehicle ["stored_at_property_id"] = property_id
	vehicle ["stored_at_property_name"] = _property_display_name(
		property_contract
	)
	vehicle ["storage_decay_multiplier"] = (
		_vehicle_property_storage_protection_multiplier(
			property_contract
		)
	)

	_replace_vehicle_instance_for_all_owners(
		vehicle
	)

	if gs.property_engine.has_method(
		"_replace_property_for_all_owners"
	):
		gs.property_engine._replace_property_for_all_owners(
			property_contract
		)

	_sync_vehicle_belongings_projection(
		owner,
		vehicle
	)

	return {
		"success": true,
		"text": "%s is now stored at %s." % [
			_vehicle_display_name(vehicle),
			_property_display_name(
				property_contract
			)
		]
	}


func _unstore_vehicle(
	owner: Person,
	vehicle: Dictionary
) -> Dictionary:
	_remove_vehicle_from_property_storage(
		owner,
		vehicle
	)

	vehicle ["storage_status"] = "unstored"
	vehicle ["stored_at_property_id"] = -1
	vehicle ["stored_at_property_name"] = ""
	vehicle ["storage_decay_multiplier"] = 1.0

	_replace_vehicle_instance_for_all_owners(
		vehicle
	)
	_sync_vehicle_belongings_projection(
		owner,
		vehicle
	)

	return {
		"success": true,
		"text": "%s is no longer stored and is visible in Belongings." % _vehicle_display_name(
			vehicle
		)
	}


func _sync_vehicle_belongings_projection(
	owner: Person,
	vehicle: Dictionary
) -> void:
	if (
		owner == null
		or gs == null
		or gs.belongings_engine == null
	):
		return

	var asset_id: int = int(
		vehicle.get(
			"id",
			-1
		)
	)

	if asset_id <= 0:
		return

	var is_stored: bool = (
		str(
			vehicle.get(
				"storage_status",
				"unstored"
			)
		) == "stored"
		or int(
			vehicle.get(
				"stored_at_property_id",
				-1
			)
		) > 0
	)
	var projection: Dictionary = (
		vehicle.duplicate(true)
	)

	projection ["category"] = "Vehicles"
	projection ["belongings_projection_only"] = is_stored
	projection ["physically_with_owner"] = not is_stored
	projection ["physical_location_kind"] = (
		"property_storage"
		if is_stored
		else "with_owner"
	)
	projection ["physical_location_text"] = (
		"Stored at %s"
		% str(
			vehicle.get(
				"stored_at_property_name",
				"Property"
			)
		)
		if is_stored
		else "With owner"
	)
	projection ["source_engine"] = ENGINE_SCHEMA
	projection ["runtime_truth_authority"] = true
	projection ["ui_is_renderer_only"] = true



	gs.belongings_engine.remove_item_by_id(
		owner,
		"Vehicles",
		asset_id
	)
	gs.belongings_engine.add_item(
		owner,
		projection,
		"Vehicles",
		true
	)

	# DIAGNOSTIC: remove-then-add should keep exactly one entry per asset_id. If the
	# Vehicles category keeps growing, either remove_item_by_id is not matching the
	# id, or something is adding entries outside this function.
	EraLog.truth(
		"ERALIFE_VEHICLE_BELONGINGS_SYNC|owner=%d|asset_id=%d|name=%s"
		% [
			int(owner.id),
			asset_id,
			str(vehicle.get("display_name", vehicle.get("model", "?")))
		]
	)


func _vehicle_storage_decay_multiplier(
	vehicle: Dictionary
) -> float:
	if str(
		vehicle.get(
			"storage_status",
			"unstored"
		)
	) != "stored":
		return 1.0

	return clampf(
		float(
			vehicle.get(
				"storage_decay_multiplier",
				0.68
			)
		),
		0.2,
		1.0
	)
func yearly_maintenance() -> void:
	if gs == null:
		return

	for npc_id in vehicles.keys():
		var owner_items: Array = vehicles [npc_id]

		for index in range(owner_items.size()):
			var raw_vehicle: Variant = owner_items [index]

			if typeof(raw_vehicle) != TYPE_DICTIONARY:
				continue

			var vehicle: Dictionary = raw_vehicle as Dictionary

			if _vehicle_is_living_transport(vehicle):
				vehicle ["condition"] = 100.0
				vehicle ["condition_label"] = "Living"
				vehicle ["condition_applicable"] = false
				vehicle ["maintenance_due"] = false
				owner_items [index] = vehicle
				continue

			var upkeep: Dictionary = _safe_dictionary(
				vehicle.get("upkeep_profile", {})
			)
			var intensity: float = maxf(
				0.25,
				float(
					upkeep.get(
						"maintenance_intensity",
						1.0
					)
				)
			)
			var maintained_this_year: bool = (
				int(
					vehicle.get(
						"last_maintenance_year",
						-999999
					)
				) >= int(gs.year) - 1
			)
			var storage_multiplier: float = _vehicle_storage_decay_multiplier(
				vehicle
			)
			var provenance: Dictionary = _safe_dictionary(
				vehicle.get("provenance", {})
			)
			var age_years: int = maxi(
				0,
				int(gs.year)
				- int(
					provenance.get(
						"acquired_year",
						gs.year
					)
				)
			)
			var age_multiplier: float = (
				1.0
				+ minf(
					1.2,
					float(age_years) * 0.025
				)
			)
			var decay_roll: float = (
				randf_range(1.5, 6.5)
				* intensity
				* storage_multiplier
				* age_multiplier
			)

			if maintained_this_year:
				decay_roll *= 0.22

			vehicle ["durability"] = clampf(
				float(
					vehicle.get(
						"durability",
						100.0
					)
				) - decay_roll,
				0.0,
				100.0
			)
			vehicle ["condition"] = clampf(
				float(
					vehicle.get(
						"condition",
						100.0
					)
				) - decay_roll * 0.72,
				0.0,
				100.0
			)
			vehicle ["condition_label"] = _vehicle_condition_label(
				float(
					vehicle.get(
						"condition",
						100.0
					)
				)
			)
			vehicle ["maintenance_due"] = (
				int(
					vehicle.get(
						"last_maintenance_year",
						-999999
					)
				) < int(gs.year) - 1
			)
			vehicle ["last_condition_decay_year"] = int(
				gs.year
			)

			var acquisition_value: int = maxi(
				1,
				int(
					vehicle.get(
						"acquisition_value",
						vehicle.get("value", 1)
					)
				)
			)
			var condition_ratio: float = clampf(
				float(
					vehicle.get(
						"condition",
						100.0
					)
				) / 100.0,
				0.0,
				1.0
			)
			var age_depreciation: float = clampf(
				1.0 - float(age_years) * 0.035,
				0.28,
				1.0
			)
			var condition_multiplier: float = lerpf(
				0.18,
				1.0,
				condition_ratio
			)

			vehicle ["value"] = maxi(
				1,
				int(
					round(
						float(acquisition_value)
						* age_depreciation
						* condition_multiplier
					)
				)
			)
			vehicle ["worth"] = int(
				vehicle ["value"]
			)
			owner_items [index] = vehicle

			var owner: Person = gs.get_npc_by_id(
				int(npc_id)
			)

			if owner != null:
				_sync_vehicle_belongings_projection(
					owner,
					vehicle
				)

		vehicles [npc_id] = owner_items
func _resolve_vehicle_template(
	type_or_template,
	luxury_level:= 0,
	purchase_context:= {}
) -> Dictionary:
	if typeof(type_or_template) == TYPE_DICTIONARY:
		return (
			type_or_template as Dictionary
		).duplicate(true)

	var raw: String = str(type_or_template)
	var resolved_raw: String = raw.trim_prefix(
		"template:"
	)

	if gs != null:
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

		if gs.era_life_asset_catalog_expansion != null:
			var expansion_template: Dictionary = (
				gs.era_life_asset_catalog_expansion
				.vehicle_template_by_id(resolved_raw)
			)

			if not expansion_template.is_empty():
				return expansion_template

	if gs != null and gs.era_data_loader != null:
		var by_id: Dictionary = (
			gs.era_data_loader
			.get_transport_template(resolved_raw)
		)

		if not by_id.is_empty():
			return by_id

		var selector: Dictionary = purchase_context.duplicate(true)

		if str(selector.get("query_text", "")) == "":
			selector ["query_text"] = resolved_raw

		if not selector.has("luxury_level"):
			selector ["luxury_level"] = luxury_level

		if gs.era != null:
			var from_catalog: Dictionary = (
				gs.era_data_loader
				.get_best_transport_template_for_context(
					gs.era.name,
					selector
				)
			)

			if not from_catalog.is_empty():
				return from_catalog

	if (
		resolved_raw.begins_with("legacy_transport_")
		and gs != null
		and gs.era != null
	):
		var era_prefix: String = "legacy_transport_%s_" % str(
			gs.era.name
		).to_lower().replace(" ", "_")

		if resolved_raw.begins_with(era_prefix):
			var legacy_type_key: String = resolved_raw.trim_prefix(
				era_prefix
			)

			if legacy_type_key != "":
				var pretty_words: Array = []

				for raw_word in legacy_type_key.split("_"):
					var word: String = str(
						raw_word
					).strip_edges()

					if word != "":
						pretty_words.append(
							word.capitalize()
						)

				var legacy_type_name: String = " ".join(
					pretty_words
				)

				if legacy_type_name != "":
					return _legacy_vehicle_template(
						legacy_type_name,
						luxury_level
					)

	return _legacy_vehicle_template(
		resolved_raw,
		luxury_level
	)
func _legacy_vehicle_template(type_name: String, luxury_level:= 0) -> Dictionary:
	var feature_tags: Array = ["transport"]
	if type_name in ["Boat", "Ship", "Fishing Boat", "Smuggling Skiff"]:
		feature_tags.append("water")
	elif type_name in ["Horse", "Warhorse", "Carriage", "Cart", "Chariot"]:
		feature_tags.append("animal")
		feature_tags.append("land")
	elif type_name in ["Plane", "Private Shuttle", "Hover Pod", "Hovercar"]:
		feature_tags.append("air")
	else:
		feature_tags.append("land")
	if luxury_level >= 3:
		feature_tags.append("luxury")

	var social_tier:= "common"
	var base_value: int = 1000

	match gs.era.name:
		"Ancient Era":
			match type_name:
				"Horse":
					social_tier = "working_class"
					base_value = 450
				"Chariot":
					social_tier = "respectable"
					base_value = 1800
				"Boat":
					social_tier = "wealthy"
					base_value = 4200
				_:
					base_value = 1200
		"Medieval Era":
			match type_name:
				"Cart":
					social_tier = "working_class"
					base_value = 700
				"Horse":
					social_tier = "respectable"
					base_value = 950
				"Carriage":
					social_tier = "wealthy"
					base_value = 2800
				_:
					base_value = 1400
		"Industrial Era":
			match type_name:
				"Car":
					social_tier = "respectable"
					base_value = 9000
				"Boat":
					social_tier = "wealthy"
					base_value = 18000
				"Plane":
					social_tier = "noble"
					base_value = 110000
				_:
					base_value = 6000
		"Modern Era":
			match type_name:
				"Car":
					social_tier = "respectable"
					base_value = 26000
				"Boat":
					social_tier = "wealthy"
					base_value = 72000
				"Plane":
					social_tier = "celebrity"
					base_value = 340000
				_:
					base_value = 18000
		"Future Era":
			match type_name:
				"Hover Pod":
					social_tier = "wealthy"
					base_value = 120000
				"Hovercar":
					social_tier = "wealthy"
					base_value = 190000
				"Private Shuttle":
					social_tier = "ultra_luxury"
					base_value = 920000
				_:
					base_value = 95000

	if luxury_level >= 3:
		base_value = int(round(float(base_value) * 1.35))
		if social_tier in ["common", "working_class", "respectable"]:
			social_tier = "wealthy"

	return {
		"template_id": "legacy_transport_%s_%s" % [
			str(gs.era.name).to_lower().replace(" ", "_"),
			type_name.to_lower().replace(" ", "_")
		],
		"asset_kind": "transport",
		"archetype": "personal_transport",
		"subtype": type_name.to_lower().replace(" ", "_"),
		"display_name": type_name,
		"legacy_type": type_name,
		"era_tags": [gs.era.name],
		"social_tier": social_tier,
		"feature_tags": feature_tags,
		"rarity": 1.0 + (float(luxury_level) * 0.08),
		"upkeep_profile": {
			"maintenance_intensity": 1.0 + (float(luxury_level) * 0.12)
		},
		"requirement_tags": [],
		"operational_profile": {
			"fuel": 0,
			"feed": 0,
			"energy_use": 0,
			"cargo_capacity": 1,
			"passenger_capacity": 2,
			"concealment": 0,
			"comfort": 1 + int(luxury_level),
			"travel_range": 1,
			"speed_class": 1 + int(luxury_level),
			"crew_burden": 0,
			"maintenance_intensity": 1.0
		},
		"passive_modifiers": {},
		"event_hooks": [],
		"action_ids": ["inspect", "rename", "sell", "gift", "maintain", "repair", "use", "ride", "drive"],
		"prestige_signals": {
			"fame_visibility": float(luxury_level),
			"class_respect": float(luxury_level) * 0.75
		},
		"pricing_rules": {},
		"base_value": base_value,
		"default_condition": 100.0
	}
func _build_runtime_vehicle_from_template(
	template: Dictionary,
	buyer: Person,
	context:= {}
) -> Dictionary:
	var display_name: String = str(
		template.get(
			"display_name",
			template.get(
				"legacy_type",
				"Vehicle"
			)
		)
	)
	var requirement_tags: Array = _safe_array(
		template.get(
			"requirement_tags",
			[]
		)
	)
	var infrastructure_tags: Array = []

	for raw_tag in context.get(
		"infrastructure_tags",
		[]
	):
		var infrastructure_tag: String = str(
			raw_tag
		).strip_edges()

		if (
			infrastructure_tag != ""
			and not infrastructure_tags.has(
				infrastructure_tag
			)
		):
			infrastructure_tags.append(
				infrastructure_tag
			)

	var satisfied_requirements: Array = []
	var missing_requirements: Array = []

	for raw_requirement in requirement_tags:
		var requirement: String = str(
			raw_requirement
		).strip_edges()

		if requirement == "":
			continue

		if requirement in infrastructure_tags:
			satisfied_requirements.append(
				requirement
			)
		else:
			missing_requirements.append(
				requirement
			)

	var operational_profile: Dictionary = _safe_dictionary(
		template.get(
			"operational_profile",
			{}
		)
	)
	var living_transport: bool = bool(
		context.get(
			"living_transport",
			template.get(
				"living_transport",
				false
			)
		)
	)
	var condition_applicable: bool = bool(
		template.get(
			"condition_applicable",
			not living_transport
		)
	)
	var brand: String = str(
		context.get(
			"brand",
			template.get(
				"brand",
				""
			)
		)
	)
	var model: String = str(
		context.get(
			"model",
			template.get(
				"model",
				display_name
			)
		)
	)

	var color_name: String = str(
		context.get(
			"color_name",
			template.get(
				"color_name",
				"Factory Finish"
			)
		)
	).strip_edges()

	if color_name == "":
		color_name = "Factory Finish"

	var color_hex: String = str(
		context.get(
			"color_hex",
			template.get(
				"color_hex",
				"7A8494"
			)
		)
	).strip_edges().trim_prefix("#")

	if color_hex == "":
		color_hex = "7A8494"

	var color_visual_contract: Dictionary = _safe_dictionary(
		context.get(
			"color_visual_contract",
			template.get(
				"color_visual_contract",
				{}
			)
		)
	).duplicate(true)

	color_visual_contract ["name"] = color_name
	color_visual_contract ["hex"] = color_hex
	color_visual_contract ["swatch_visible"] = bool(
		color_visual_contract.get(
			"swatch_visible",
			true
		)
	)
	color_visual_contract ["ui_is_renderer_only"] = true

	var restricted_vehicle: bool = bool(
		template.get(
			"restricted_vehicle",
			false
		)
	)
	var weapon_platform: bool = bool(
		template.get(
			"weapon_platform",
			false
		)
	)
	var requires_underground_bunker: bool = bool(
		template.get(
			"requires_underground_bunker",
			false
		)
	)
	var storage_requirement: String = str(
		template.get(
			"storage_requirement",
			""
		)
	).strip_edges()

	if storage_requirement == "":
		storage_requirement = (
			"underground_bunker"
			if requires_underground_bunker
			else "standard_vehicle_storage"
		)

	var initial_condition: float = float(
		template.get(
			"default_condition",
			100.0
		)
	)
	var base_value: int = int(
		context.get(
			"acquisition_value",
			template.get(
				"base_value",
				1
			)
		)
	)

	return {
		"id": _gen_id(),
		"template_id": str(
			template.get(
				"template_id",
				""
			)
		),
		"type": str(
			template.get(
				"legacy_type",
				display_name
			)
		),
		"display_name": display_name,
		"name": display_name,
		"brand": brand,
		"model": model,
		"color_name": color_name,
		"color_hex": color_hex,
		"color_visual_contract": (
			color_visual_contract
		),
		"restricted_vehicle": restricted_vehicle,
		"weapon_platform": weapon_platform,
		"requires_underground_bunker": (
			requires_underground_bunker
		),
		"storage_requirement": storage_requirement,
		"asset_kind": "transport",
		"category": str(
			template.get(
				"category",
				template.get(
					"subtype",
					"mobility"
				)
			)
		),
		"archetype": str(
			template.get(
				"archetype",
				"personal_transport"
			)
		),
		"subtype": str(
			template.get(
				"subtype",
				""
			)
		),
		"movement_type": str(
			context.get(
				"movement_type",
				template.get(
					"movement_type",
					operational_profile.get(
						"movement_type",
						"unknown"
					)
				)
			)
		),
		"seats": int(
			context.get(
				"seats",
				template.get(
					"seats",
					operational_profile.get(
						"passenger_capacity",
						1
					)
				)
			)
		),
		"terrain": _safe_array(
			context.get(
				"terrain",
				template.get(
					"terrain",
					operational_profile.get(
						"terrain",
						[]
					)
				)
			)
		),
		"fuel": str(
			context.get(
				"fuel",
				template.get(
					"fuel",
					operational_profile.get(
						"fuel",
						"none"
					)
				)
			)
		),
		"monthly_cost": int(
			context.get(
				"monthly_cost",
				template.get(
					"monthly_cost",
					operational_profile.get(
						"monthly_cost",
						0
					)
				)
			)
		),
		"era_name": str(
			gs.era.name
		),
		"era_tags": _safe_array(
			template.get(
				"era_tags",
				[]
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
		"filter_tags": _safe_array(
			template.get(
				"filter_tags",
				template.get(
					"feature_tags",
					[]
				)
			)
		),
		"feature_tags": _safe_array(
			template.get(
				"feature_tags",
				[]
			)
		),
		"portfolio_tags": _safe_array(
			template.get(
				"portfolio_tags",
				[]
			)
		),
		"rarity": float(
			template.get(
				"rarity",
				1.0
			)
		),
		"upkeep_profile": _safe_dictionary(
			template.get(
				"upkeep_profile",
				{}
			)
		),
		"requirement_tags": requirement_tags,
		"operational_profile": operational_profile,
		"passive_modifiers": _safe_dictionary(
			template.get(
				"passive_modifiers",
				{}
			)
		),
		"event_hooks": _safe_array(
			template.get(
				"event_hooks",
				[]
			)
		),
		"action_ids": _safe_array(
			template.get(
				"action_ids",
				[]
			)
		),
		"prestige_signals": _safe_dictionary(
			template.get(
				"prestige_signals",
				{}
			)
		),
		"pricing_rules": _safe_dictionary(
			template.get(
				"pricing_rules",
				{}
			)
		),
		"luxury": int(
			context.get(
				"luxury_level",
				template.get(
					"luxury",
					0
				)
			)
		),
		"durability": 100.0,
		"condition": initial_condition,
		"condition_applicable": condition_applicable,
		"condition_label": (
			_vehicle_condition_label(
				initial_condition
			)
			if condition_applicable
			else "Living"
		),
		"living_transport": living_transport,
		"linked_entity_id": str(
			context.get(
				"linked_entity_id",
				""
			)
		),
		"linked_entity_kind": str(
			context.get(
				"linked_entity_kind",
				""
			)
		),
		"animal_species_id": str(
			context.get(
				"animal_species_id",
				template.get(
					"animal_species_id",
					""
				)
			)
		),
		"mythical_species_id": str(
			context.get(
				"mythical_species_id",
				template.get(
					"mythical_species_id",
					""
				)
			)
		),
		"autofix": false,
		"maintenance_due": false,
		"damage_flags": [],
		"upgrades": [],
		"nickname": "",
		"custom_paint": str(
			context.get(
				"custom_paint",
				""
			)
		),
		"active_assignment": "",
		"dependency_state": {
			"requirements_satisfied": (
				satisfied_requirements
			),
			"requirements_missing": (
				missing_requirements
			),
			"last_checked_year": int(
				gs.year
			)
		},
		"access_roles": {
			"owner_ids": [
				int(buyer.id)
			],
			"co_owner_ids": [],
			"heir_ids": [],
			"household_user_ids": [
				int(buyer.id)
			],
			"assigned_driver_ids": [],
			"captain_ids": [],
			"caretaker_ids": [],
			"staff_ids": []
		},
		"assigned_operator_id": -1,
		"crew_manifest": [],
		"legal_status": "owned",
		"ownership_status": "owned",
		"availability": "owned_not_for_sale",
		"market_region": str(
			context.get(
				"market_region",
				""
			)
		),
		"market_climate": str(
			context.get(
				"market_climate",
				""
			)
		),
		"dealer": str(
			context.get(
				"dealer",
				""
			)
		),
		"last_maintenance_year": int(
			gs.year
		),
		"last_condition_decay_year": int(
			gs.year
		),
		"storage_status": "unstored",
		"stored_at_property_id": -1,
		"stored_at_property_name": "",
		"physical_location_kind": "with_owner",
		"storage_decay_multiplier": 1.0,
		"cargo_contents": [],
		"storage_contents": [],
		"previous_owners": [],
		"value": maxi(
			1,
			base_value
		),
		"worth": maxi(
			1,
			base_value
		),
		"acquisition_value": maxi(
			1,
			base_value
		),
		"provenance": {
			"acquired_year": int(
				gs.year
			),
			"acquired_era": str(
				gs.era.name
			),
			"acquired_by": int(
				buyer.id
			)
		}
	}
func _calculate_vehicle_value(template: Dictionary, buyer: Person, context:= {}) -> int:
	var base_value: float = float(template.get("base_value", 0))
	if base_value <= 0.0:
		base_value = float(context.get("fallback_price", 0))

	var multiplier: float = 1.0
	multiplier *= _market_adjustment_for_vehicle(template, buyer, context)

	var condition: float = float(template.get("default_condition", 100.0))
	multiplier *= lerp(0.42, 1.18, clamp(condition / 100.0, 0.0, 1.0))

	var local_variation: float = randf_range(0.88, 1.15)
	multiplier *= local_variation

	return max(1, int(round(base_value * multiplier)))
func _market_adjustment_for_vehicle(template: Dictionary, buyer: Person, context:= {}) -> float:
	var out: float = 1.0
	out *= clamp(float(template.get("rarity", 1.0)), 0.65, 2.5)

	var tags: Array = template.get("feature_tags", [])
	if "luxury" in tags:
		out *= 1.4
	if "cargo" in tags:
		out *= 1.12
	if "air" in tags:
		out *= 1.35
	if "water" in tags:
		out *= 1.18
	if "animal" in tags:
		out *= 0.94
	if "ceremonial" in tags:
		out *= 1.22
	if "criminal" in tags or "hidden" in tags:
		out *= 1.16

	var pricing_rules: Dictionary = template.get("pricing_rules", {})
	out *= max(0.25, float(pricing_rules.get("era_multiplier", context.get("era_multiplier", 1.0))))
	out *= max(0.25, float(pricing_rules.get("region_multiplier", context.get("region_multiplier", 1.0))))
	out *= max(0.25, float(pricing_rules.get("market_climate_multiplier", context.get("market_climate_multiplier", 1.0))))
	out *= max(0.25, float(pricing_rules.get("class_desirability_multiplier", context.get("class_desirability_multiplier", 1.0))))
	out *= max(0.25, float(pricing_rules.get("scarcity_multiplier", pricing_rules.get("scarcity", context.get("scarcity_multiplier", 1.0)))))

	var infrastructure_tags: Array = []
	for raw_tag in context.get("infrastructure_tags", []):
		infrastructure_tags.append(str(raw_tag))

	var requirement_tags: Array = template.get("requirement_tags", [])
	if not requirement_tags.is_empty():
		var satisfied_count: int = 0
		for raw_req in requirement_tags:
			var req:= str(raw_req)
			if req in infrastructure_tags:
				satisfied_count += 1
		var requirement_score: float = float(satisfied_count) / float(max(1, requirement_tags.size()))
		out *= lerp(0.74, 1.14, requirement_score)

	var network_type:= str(context.get("network_type", ""))
	if network_type == "road" and "land" in tags:
		out *= 1.08
	if network_type == "dock" and "water" in tags:
		out *= 1.1
	if network_type == "air" and "air" in tags:
		out *= 1.12
	if network_type == "stable" and "animal" in tags:
		out *= 1.08

	var operational_profile: Dictionary = template.get("operational_profile", {})
	out *= lerp(0.95, 1.2, clamp(float(operational_profile.get("speed_class", 1)) / 10.0, 0.0, 1.0))
	out *= lerp(0.96, 1.16, clamp(float(operational_profile.get("travel_range", 1)) / 10.0, 0.0, 1.0))
	out *= lerp(0.98, 1.1, clamp(float(operational_profile.get("cargo_capacity", 0)) / 10.0, 0.0, 1.0))

	if buyer != null:
		var fame_factor: float = clamp(float(buyer.fame) / 100.0, 0.0, 1.0)
		out *= lerp(1.0, 1.16, fame_factor)

	return out
func get_vehicle_portfolio_panel_payload(owner: Person) -> Dictionary:
	var out: Dictionary = {
		"rollup": {},
		"asset_rows": []
	}
	if owner == null:
		return out
	if not vehicles.has(owner.id):
		return out

	out ["rollup"] = get_asset_signal_rollup_for_owner(owner)

	var rows: Array = []
	var seen: Dictionary = {}
	for raw_vehicle in vehicles.get(owner.id, []):
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = raw_vehicle
		var asset_id: int = int(v.get("id", -1))
		if asset_id <= 0 or seen.has(asset_id):
			continue
		seen [asset_id] = true

		rows.append({
			"asset_id": asset_id,
			"display_name": _vehicle_display_name(v),
			"condition": int(round(float(v.get("condition", 100.0)))),
			"condition_label": str(v.get("condition_label", "Excellent")),
			"operator_label": _vehicle_operator_label(v),
			"route_label": str(v.get("assigned_route", "Local Use")),
			"trade_role_label": str(v.get("trade_role", "Personal Travel"))
		})
	out ["asset_rows"] = rows
	return out


func get_vehicle_portfolio_asset_payload(owner: Person, asset_id: int) -> Dictionary:
	var vehicle: Dictionary = _find_vehicle_for_owner(owner, asset_id)
	if vehicle.is_empty():
		return {}

	var candidate_labels: Array = []
	for raw_candidate in get_vehicle_portfolio_operator_candidates(owner, asset_id):
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate
		candidate_labels.append(str(candidate.get("name", "Unknown")))

	var feature_tag_labels: Array = []
	for raw_tag in vehicle.get("feature_tags", []):
		feature_tag_labels.append(str(raw_tag))

	var requirement_tag_labels: Array = []
	for raw_tag in vehicle.get("requirement_tags", []):
		requirement_tag_labels.append(str(raw_tag))

	var portfolio_tag_labels: Array = []
	for raw_tag in vehicle.get("portfolio_tags", []):
		portfolio_tag_labels.append(str(raw_tag))

	var dependency_state: Dictionary = vehicle.get("dependency_state", {})
	var missing_requirement_labels: Array = []
	for raw_req in dependency_state.get("requirements_missing", []):
		missing_requirement_labels.append(str(raw_req))

	var satisfied_requirement_labels: Array = []
	for raw_req in dependency_state.get("requirements_satisfied", []):
		satisfied_requirement_labels.append(str(raw_req))

	var status_lines: Array = []
	var status_signals: Dictionary = vehicle.get("status_signals", vehicle.get("prestige_signals", {}))
	for key in status_signals.keys():
		status_lines.append("%s: %s" % [
			str(key).replace("_", " ").capitalize(),
			str(int(round(float(status_signals.get(key, 0.0)))))
		])

	var operational_lines: Array = []
	var operational_profile: Dictionary = vehicle.get("operational_profile", {})
	for key in operational_profile.keys():
		operational_lines.append("%s: %s" % [
			str(key).replace("_", " ").capitalize(),
			str(operational_profile.get(key, 0))
		])

	var pressure_lines: Array = []
	var pressure_profile: Dictionary = vehicle.get("pressure_profile", {})
	for key in pressure_profile.keys():
		pressure_lines.append("%s: %s" % [
			str(key).replace("_", " ").capitalize(),
			str(snappedf(float(pressure_profile.get(key, 0.0)), 0.01))
		])

	var provenance_lines: Array = []
	var provenance: Dictionary = vehicle.get("provenance", {})
	if not provenance.is_empty():
		provenance_lines.append("Acquired Year: %s" % str(provenance.get("acquired_year", "")))
		provenance_lines.append("Acquired Era: %s" % str(provenance.get("acquired_era", "")))
		provenance_lines.append("Acquired By NPC ID: %s" % str(provenance.get("acquired_by", "")))

	return {
		"asset_id": asset_id,
		"display_name": _vehicle_display_name(vehicle),
		"archetype": str(vehicle.get("archetype", "personal_transport")),
		"subtype": str(vehicle.get("subtype", "")),
		"social_tier": str(vehicle.get("social_tier", "common")),
		"value_band": str(vehicle.get("value_band", "entry")),
		"condition": int(round(float(vehicle.get("condition", 100.0)))),
		"condition_label": str(vehicle.get("condition_label", "Excellent")),
		"operator_label": _vehicle_operator_label(vehicle),
		"route_label": str(vehicle.get("assigned_route", "Local Use")),
		"trade_role_label": str(vehicle.get("trade_role", "Personal Travel")),
		"feature_tag_labels": feature_tag_labels,
		"requirement_tag_labels": requirement_tag_labels,
		"portfolio_tag_labels": portfolio_tag_labels,
		"missing_requirement_labels": missing_requirement_labels,
		"satisfied_requirement_labels": satisfied_requirement_labels,
		"status_lines": status_lines,
		"operational_lines": operational_lines,
		"pressure_lines": pressure_lines,
		"provenance_lines": provenance_lines,
		"candidate_labels": candidate_labels,
		"legal_status": str(vehicle.get("legal_status", "owned")),
		"market_region": str(vehicle.get("market_region", "")),
		"market_climate": str(vehicle.get("market_climate", "")),
		"custom_paint": str(vehicle.get("custom_paint", "")),
		"active_assignment": str(vehicle.get("active_assignment", ""))
	}


func get_vehicle_portfolio_operator_candidates(owner: Person, _asset_id: int = -1) -> Array:
	var out: Array = []
	var seen_ids: Dictionary = {}

	out.append({
		"id": -1,
		"name": "Owner / Self"
	})
	seen_ids [-1] = true

	if owner == null:
		return out

	var partner: Person = gs.get_valid_partner(owner, true)
	if partner != null and partner.alive and int(partner.age) >= 18 and not seen_ids.has(int(partner.id)):
		seen_ids [int(partner.id)] = true
		out.append({
			"id": int(partner.id),
			"name": "%s %s" % [partner.first_name, partner.last_name]
		})

	for raw_parent_id in owner.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_parent_id))
		if parent == null or not parent.alive or int(parent.age) < 18:
			continue
		if seen_ids.has(int(parent.id)):
			continue
		seen_ids [int(parent.id)] = true
		out.append({
			"id": int(parent.id),
			"name": "%s %s" % [parent.first_name, parent.last_name]
		})

	for raw_child_id in owner.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(raw_child_id))
		if child == null or not child.alive or int(child.age) < 18:
			continue
		if seen_ids.has(int(child.id)):
			continue
		seen_ids [int(child.id)] = true
		out.append({
			"id": int(child.id),
			"name": "%s %s" % [child.first_name, child.last_name]
		})

	if gs != null and gs.workplace_engine != null:
		var coworkers: Array = gs.workplace_engine.get_coworkers(owner)
		for coworker_value in coworkers:
			if coworker_value == null:
				continue
			var coworker: Person = coworker_value
			if not coworker.alive or int(coworker.age) < 18:
				continue
			if seen_ids.has(int(coworker.id)):
				continue
			seen_ids [int(coworker.id)] = true
			out.append({
				"id": int(coworker.id),
				"name": "%s %s" % [coworker.first_name, coworker.last_name]
			})

	return out


func cycle_vehicle_portfolio_operator(owner: Person, asset_id: int) -> Dictionary:
	var vehicle: Dictionary = _find_vehicle_for_owner(owner, asset_id)
	if vehicle.is_empty():
		return { "success": false, "text": "That mobility asset could not be found."}

	var candidates: Array = get_vehicle_portfolio_operator_candidates(owner, asset_id)
	if candidates.is_empty():
		return { "success": false, "text": "No eligible operators are available right now."}

	var current_operator_id: int = int(vehicle.get("assigned_operator_id", -1))
	var current_index: int = -1
	for idx in range(candidates.size()):
		var raw_candidate: Variant = candidates [idx]
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("id", -99999)) == current_operator_id:
			current_index = idx
			break

	var next_index: int = (current_index + 1) % candidates.size()
	var next_candidate: Dictionary = candidates [next_index]
	var next_operator_id: int = int(next_candidate.get("id", -1))

	vehicle ["assigned_operator_id"] = next_operator_id

	var access_roles: Dictionary = vehicle.get("access_roles", {})
	var assigned_driver_ids: Array = []
	if next_operator_id > 0:
		assigned_driver_ids.append(next_operator_id)
	access_roles ["assigned_driver_ids"] = assigned_driver_ids
	vehicle ["access_roles"] = access_roles
	vehicle ["active_assignment"] = "%s • %s • %s" % [
		_vehicle_operator_label(vehicle),
		str(vehicle.get("assigned_route", "Local Use")),
		str(vehicle.get("trade_role", "Personal Travel"))
	]

	_replace_vehicle_instance_for_all_owners(vehicle)

	return {
		"success": true,
		"text": "%s is now assigned to %s." % [
			_vehicle_display_name(vehicle),
			_vehicle_operator_label(vehicle)
		]
	}


func cycle_vehicle_portfolio_route(owner: Person, asset_id: int) -> Dictionary:
	var vehicle: Dictionary = _find_vehicle_for_owner(owner, asset_id)
	if vehicle.is_empty():
		return { "success": false, "text": "That mobility asset could not be found."}

	var routes: Array = _vehicle_route_cycle(vehicle)
	if routes.is_empty():
		return { "success": false, "text": "No route options are available for this asset."}

	var current_route: String = str(vehicle.get("assigned_route", ""))
	var current_index: int = routes.find(current_route)
	var next_index: int = 0
	if current_index >= 0:
		next_index = (current_index + 1) % routes.size()

	var next_route: String = str(routes [next_index])
	vehicle ["assigned_route"] = next_route
	vehicle ["active_assignment"] = "%s • %s • %s" % [
		_vehicle_operator_label(vehicle),
		next_route,
		str(vehicle.get("trade_role", "Personal Travel"))
	]

	_replace_vehicle_instance_for_all_owners(vehicle)

	return {
		"success": true,
		"text": "%s is now set to the %s route." % [
			_vehicle_display_name(vehicle),
			next_route
		]
	}


func cycle_vehicle_trade_role(owner: Person, asset_id: int) -> Dictionary:
	var vehicle: Dictionary = _find_vehicle_for_owner(owner, asset_id)
	if vehicle.is_empty():
		return { "success": false, "text": "That mobility asset could not be found."}

	var roles: Array = _vehicle_trade_role_cycle(vehicle)
	if roles.is_empty():
		return { "success": false, "text": "No trade roles are available for this asset."}

	var current_role: String = str(vehicle.get("trade_role", ""))
	var current_index: int = roles.find(current_role)
	var next_index: int = 0
	if current_index >= 0:
		next_index = (current_index + 1) % roles.size()

	var next_role: String = str(roles [next_index])
	vehicle ["trade_role"] = next_role
	vehicle ["active_assignment"] = "%s • %s • %s" % [
		_vehicle_operator_label(vehicle),
		str(vehicle.get("assigned_route", "Local Use")),
		next_role
	]

	_replace_vehicle_instance_for_all_owners(vehicle)

	return {
		"success": true,
		"text": "%s now operates as %s." % [
			_vehicle_display_name(vehicle),
			next_role
		]
	}


func _find_vehicle_for_owner(owner: Person, asset_id: int) -> Dictionary:
	if owner == null:
		return {}
	if not vehicles.has(owner.id):
		return {}
	for raw_vehicle in vehicles.get(owner.id, []):
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = raw_vehicle
		if int(vehicle.get("id", -1)) == asset_id:
			return vehicle
	return {}


func _replace_vehicle_instance_for_all_owners(vehicle: Dictionary) -> void:
	var asset_id: int = int(vehicle.get("id", -1))
	if asset_id <= 0:
		return
	for owner_id_value in vehicles.keys():
		var owner_id: int = int(owner_id_value)
		var owner_items: Array = vehicles.get(owner_id, [])
		for idx in range(owner_items.size()):
			var raw_vehicle: Variant = owner_items [idx]
			if typeof(raw_vehicle) != TYPE_DICTIONARY:
				continue
			if int(raw_vehicle.get("id", -1)) != asset_id:
				continue
			owner_items [idx] = vehicle
		vehicles [owner_id] = owner_items


func _vehicle_display_name(vehicle: Dictionary) -> String:
	var display_name: String = str(vehicle.get("nickname", ""))
	if display_name == "":
		display_name = str(vehicle.get("display_name", vehicle.get("type", "Vehicle")))
	return display_name


func _vehicle_operator_label(vehicle: Dictionary) -> String:
	var operator_id: int = int(vehicle.get("assigned_operator_id", -1))
	if operator_id <= 0:
		return "Owner / Self"
	var operator: Person = gs.get_or_reactivate_npc_by_id(operator_id)
	if operator == null:
		return "Unknown Operator"
	return "%s %s" % [operator.first_name, operator.last_name]


func _vehicle_route_cycle(vehicle: Dictionary) -> Array:
	var tags: Array = vehicle.get("feature_tags", [])
	if "air" in tags:
		return ["Local Air Corridor", "Regional Freight Arc", "Long-Range Charter"]
	if "water" in tags:
		return ["Harbor Shuttle", "Coastal Trade Run", "Deepwater Cargo Route"]
	if "animal" in tags:
		return ["Town Circuit", "Courier Trail", "Frontier Supply Route"]
	return ["City Circuit", "Regional Trade Road", "Cross-Country Haul"]
func get_vehicle_market_rows_for_buyer(
	buyer: Person,
	context: Dictionary = {}
) -> Array:
	var rows: Array = []

	if (
		buyer == null
		or gs == null
		or gs.era == null
	):
		return rows

	var templates: Array = []
	var seen_template_ids: Dictionary = {}

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

	if gs.era_life_asset_catalog_expansion != null:
		templates.append_array(
			gs.era_life_asset_catalog_expansion.vehicle_templates_for_actor(
				buyer,
				context
			)
		)

	if gs.era_data_loader != null:
		templates.append_array(
			gs.era_data_loader.get_transport_templates_for_era(
				gs.era.name
			)
		)

	var selected_dealership_raw: Variant = context.get(
		"selected_dealership_contract",
		{}
	)
	var selected_dealership: Dictionary = (
		selected_dealership_raw as Dictionary
		if typeof(selected_dealership_raw) == TYPE_DICTIONARY
		else {}
	)

	for raw_template in templates:
		if typeof(raw_template) != TYPE_DICTIONARY:
			continue

		var template: Dictionary = (
			raw_template as Dictionary
		).duplicate(true)
		var template_id: String = str(
			template.get("template_id", "")
		).strip_edges()

		if (
			template_id == ""
			or seen_template_ids.has(template_id)
		):
			continue

		seen_template_ids [template_id] = true

		var price: int = int(
			_calculate_vehicle_value(
				template,
				buyer,
				context
			)
		)
		var operational_profile: Dictionary = _safe_dictionary(
			template.get("operational_profile", {})
		)
		var feature_tags: Array = _safe_array(
			template.get("feature_tags", [])
		)
		var filter_tags: Array = _safe_array(
			template.get(
				"filter_tags",
				feature_tags
			)
		)
		var status_summary_bits: Array = []
		var status_signals: Dictionary = _safe_dictionary(
			template.get(
				"status_signals",
				template.get(
					"prestige_signals",
					{}
				)
			)
		)

		for signal_key in status_signals.keys():
			var signal_value: float = float(
				status_signals.get(signal_key, 0.0)
			)

			if signal_value <= 0.0:
				continue

			status_summary_bits.append(
				"%s %d" % [
					str(signal_key)
						.replace("_", " ")
						.capitalize(),
					int(round(signal_value))
				]
			)

			if status_summary_bits.size() >= 3:
				break

		var movement_type: String = str(
			template.get(
				"movement_type",
				operational_profile.get(
					"movement_type",
					"unknown"
				)
			)
		)
		var seats: int = int(
			template.get(
				"seats",
				operational_profile.get(
					"passenger_capacity",
					1
				)
			)
		)
		var operational_summary_bits: Array = [
			"Movement %s" % movement_type
				.replace("_", " ")
				.capitalize(),
			"Seats %d" % seats
		]

		rows.append({
			"template_id": template_id,
			"display_name": str(
				template.get(
					"display_name",
					template.get("type", "Vehicle")
				)
			),
			"brand": str(
				template.get("brand", "")
			),
			"model": str(
				template.get(
					"model",
					template.get(
						"display_name",
						"Vehicle"
					)
				)
			),
			"category": str(
				template.get(
					"category",
					template.get(
						"subtype",
						"mobility"
					)
				)
			),
			"archetype": str(
				template.get(
					"archetype",
					"personal_transport"
				)
			),
			"subtype": str(
				template.get("subtype", "")
			),
			"movement_type": movement_type,
			"seats": seats,
			"era": str(gs.era.name),
			"terrain": _safe_array(
				template.get(
					"terrain",
					operational_profile.get(
						"terrain",
						[]
					)
				)
			),
			"fuel": str(
				template.get(
					"fuel",
					operational_profile.get(
						"fuel",
						"none"
					)
				)
			),
			"monthly_cost": int(
				template.get(
					"monthly_cost",
					operational_profile.get(
						"monthly_cost",
						0
					)
				)
			),
			"ownership_status": "available",
			"availability": "available",
			"condition": float(
				template.get(
					"default_condition",
					100.0
				)
			),
			"condition_label": (
				"Living"
				if bool(
					template.get(
						"living_transport",
						false
					)
				)
				else "New"
			),
			"condition_applicable": bool(
				template.get(
					"condition_applicable",
					not bool(
						template.get(
							"living_transport",
							false
						)
					)
				)
			),
			"living_transport": bool(
				template.get(
					"living_transport",
					false
				)
			),
			"animal_species_id": str(
				template.get(
					"animal_species_id",
					""
				)
			),
			"mythical_species_id": str(
				template.get(
					"mythical_species_id",
					""
				)
			),
			"dealer": str(
				selected_dealership.get(
					"name",
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
			"filter_tags": filter_tags,
			"feature_tags": feature_tags,
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
			"status_summary": status_summary_bits,
			"operational_summary": operational_summary_bits,
			"price": price
		})

	if bool(
		context.get(
			"include_owned_portfolio_rows",
			true
		)
	):
		rows.append_array(
			_owned_vehicle_market_rows_for_buyer(
				buyer
			)
		)

	rows.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("price", 0)
		) < int(
			(right_raw as Dictionary).get("price", 0)
		)
	)

	return rows
func _owned_vehicle_market_rows_for_buyer(
	buyer: Person
) -> Array:
	var out: Array = []

	if (
		buyer == null
		or not vehicles.has(buyer.id)
	):
		return out

	var seen: Dictionary = {}

	for raw_vehicle in vehicles.get(
		buyer.id,
		[]
	):
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue

		var vehicle: Dictionary = raw_vehicle as Dictionary
		var asset_id: int = int(
			vehicle.get("id", -1)
		)

		if (
			asset_id <= 0
			or seen.has(asset_id)
		):
			continue

		seen [asset_id] = true

		var legal_status: String = str(
			vehicle.get(
				"legal_status",
				"owned"
			)
		).strip_edges().to_lower()
		var filter_tags: Array = _safe_array(
			vehicle.get(
				"filter_tags",
				vehicle.get("feature_tags", [])
			)
		)

		if not filter_tags.has(legal_status):
			filter_tags.append(legal_status)

		out.append({
			"template_id": "owned_asset:%d" % asset_id,
			"source_asset_id": asset_id,
			"display_name": _vehicle_display_name(
				vehicle
			),
			"brand": str(
				vehicle.get("brand", "")
			),
			"model": str(
				vehicle.get(
					"model",
					vehicle.get(
						"display_name",
						"Vehicle"
					)
				)
			),
			"category": str(
				vehicle.get(
					"category",
					vehicle.get(
						"subtype",
						"mobility"
					)
				)
			),
			"movement_type": str(
				vehicle.get(
					"movement_type",
					"unknown"
				)
			),
			"seats": int(
				vehicle.get("seats", 1)
			),
			"era": str(
				vehicle.get(
					"era_name",
					gs.era.name
				)
			),
			"terrain": _safe_array(
				vehicle.get("terrain", [])
			),
			"fuel": str(
				vehicle.get("fuel", "none")
			),
			"monthly_cost": int(
				vehicle.get(
					"monthly_cost",
					0
				)
			),
			"ownership_status": legal_status,
			"availability": "owned_not_for_sale",
			"condition": float(
				vehicle.get(
					"condition",
					100.0
				)
			),
			"condition_label": str(
				vehicle.get(
					"condition_label",
					"Excellent"
				)
			),
			"condition_applicable": bool(
				vehicle.get(
					"condition_applicable",
					true
				)
			),
			"living_transport": bool(
				vehicle.get(
					"living_transport",
					false
				)
			),
			"dealer": str(
				vehicle.get(
					"dealer",
					"Owned Portfolio"
				)
			),
			"social_tier": str(
				vehicle.get(
					"social_tier",
					"common"
				)
			),
			"value_band": str(
				vehicle.get(
					"value_band",
					"entry"
				)
			),
			"filter_tags": filter_tags,
			"feature_tags": _safe_array(
				vehicle.get("feature_tags", [])
			),
			"requirement_tags": _safe_array(
				vehicle.get(
					"requirement_tags",
					[]
				)
			),
			"portfolio_tags": _safe_array(
				vehicle.get(
					"portfolio_tags",
					[]
				)
			),
			"status_summary": [
				str(
					vehicle.get(
						"storage_status",
						"unstored"
					)
				).capitalize()
			],
			"operational_summary": [],
			"price": int(
				vehicle.get(
					"value",
					vehicle.get("worth", 0)
				)
			)
		})

	return out
func _vehicle_trade_role_cycle(vehicle: Dictionary) -> Array:
	var roles: Array = ["Personal Travel", "Passenger Service", "Cargo Haul", "Trade Escort"]
	var tags: Array = vehicle.get("feature_tags", [])
	if "luxury" in tags:
		roles.append("VIP Charter")
	return roles
func get_vehicle_asset_actions(
	owner: Person
) -> Array:
	var out: Array = []

	if (
		owner == null
		or not vehicles.has(owner.id)
	):
		return out

	for raw_vehicle in vehicles.get(
		owner.id,
		[]
	):
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue

		var vehicle: Dictionary = raw_vehicle as Dictionary
		var asset_id: int = int(
			vehicle.get("id", -1)
		)

		if asset_id <= 0:
			continue

		var display_name: String = _vehicle_display_name(
			vehicle
		)

		for raw_action_id in _safe_array(
			vehicle.get("action_ids", [])
		):
			var action_id: String = str(
				raw_action_id
			)

			if action_id == "":
				continue

			if (
				_vehicle_is_living_transport(vehicle)
				and action_id in ["maintain", "repair"]
			):
				continue

			out.append({
				"id": "vehicle_asset_%d_%s" % [
					asset_id,
					action_id
				],
				"text": "%s • %s" % [
					_label_for_vehicle_action(
						action_id
					),
					display_name
				],
				"engine": "vehicle_engine",
				"method": "run_asset_action",
				"args": [
					owner,
					asset_id,
					action_id
				]
			})

		if str(
			vehicle.get(
				"storage_status",
				"unstored"
			)
		) == "stored":
			out.append({
				"id": "vehicle_asset_%d_unstore" % asset_id,
				"text": "Unstore • %s" % display_name,
				"engine": "vehicle_engine",
				"method": "run_asset_action",
				"args": [
					owner,
					asset_id,
					"unstore_vehicle"
				]
			})
		else:
			for raw_option in _owned_property_storage_options(
				owner
			):
				var option: Dictionary = (
					raw_option as Dictionary
				)

				if not bool(
					option.get(
						"can_store_vehicle",
						false
					)
				):
					continue

				var property_id: int = int(
					option.get(
						"property_id",
						-1
					)
				)

				out.append({
					"id": "vehicle_asset_%d_store_%d" % [
						asset_id,
						property_id
					],
					"text": "Store at %s • %s" % [
						str(
							option.get(
								"display_name",
								"Property"
							)
						),
						display_name
					],
					"engine": "vehicle_engine",
					"method": "run_asset_action",
					"args": [
						owner,
						asset_id,
						"store_at_property:%d" % property_id
					]
				})

	return out
func run_asset_action(
	owner: Person,
	asset_id: int,
	action_id: String
) -> Dictionary:
	if owner == null:
		return {
			"success": false,
			"text": "No owner provided."
		}

	if not vehicles.has(owner.id):
		return {
			"success": false,
			"text": "No vehicles found."
		}

	var items: Array = vehicles.get(
		owner.id,
		[]
	)

	for index in range(items.size()):
		var raw_vehicle: Variant = items [index]

		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue

		if int(
			raw_vehicle.get("id", -1)
		) != asset_id:
			continue

		var vehicle: Dictionary = raw_vehicle as Dictionary

		if action_id.begins_with(
			"store_at_property:"
		):
			var property_id: int = int(
				action_id.trim_prefix(
					"store_at_property:"
				)
			)

			return _store_vehicle_at_property(
				owner,
				vehicle,
				property_id
			)

		if action_id == "unstore_vehicle":
			return _unstore_vehicle(
				owner,
				vehicle
			)

		match action_id:
			"inspect":
				var condition_text: String = (
					"Living"
					if _vehicle_is_living_transport(
						vehicle
					)
					else "%d%% • %s" % [
						int(
							round(
								float(
									vehicle.get(
										"condition",
										100.0
									)
								)
							)
						),
						str(
							vehicle.get(
								"condition_label",
								"Excellent"
							)
						)
					]
				)
				var storage_text: String = "Unstored"

				if str(
					vehicle.get(
						"storage_status",
						"unstored"
					)
				) == "stored":
					storage_text = "Stored at %s" % str(
						vehicle.get(
							"stored_at_property_name",
							"Property"
						)
					)

				return {
					"success": true,
					"text": "%s • Condition %s • %s" % [
						_vehicle_display_name(
							vehicle
						),
						condition_text,
						storage_text
					]
				}

			"maintain", "repair":
				if _vehicle_is_living_transport(
					vehicle
				):
					return {
						"success": false,
						"text": "Living mounts are maintained by their animal-care contract."
					}

				vehicle ["durability"] = minf(
					100.0,
					float(
						vehicle.get(
							"durability",
							100.0
						)
					) + 12.0
				)
				vehicle ["condition"] = minf(
					100.0,
					float(
						vehicle.get(
							"condition",
							100.0
						)
					) + 12.0
				)
				vehicle ["condition_label"] = _vehicle_condition_label(
					float(
						vehicle.get(
							"condition",
							100.0
						)
					)
				)
				vehicle ["last_maintenance_year"] = int(
					gs.year
				)
				vehicle ["maintenance_due"] = false

				items [index] = vehicle
				vehicles [owner.id] = items

				_replace_vehicle_instance_for_all_owners(
					vehicle
				)
				_sync_vehicle_belongings_projection(
					owner,
					vehicle
				)

				return {
					"success": true,
					"text": "I maintained %s." % _vehicle_display_name(
						vehicle
					)
				}

			"sell":
				_remove_vehicle_from_property_storage(
					owner,
					vehicle
				)

				var sale_value: int = int(
					round(
						float(
							vehicle.get(
								"value",
								0
							)
						) * randf_range(
							0.78,
							1.05
						)
					)
				)

				owner.bank_balance += sale_value

				if (
					gs != null
					and gs.belongings_engine != null
				):
					gs.belongings_engine.remove_item_by_id(
						owner,
						"Vehicles",
						asset_id
					)

				_remove_vehicle_refs(
					owner.id,
					asset_id
				)

				return {
					"success": true,
					"text": "I sold %s for %s." % [
						_vehicle_display_name(
							vehicle
						),
						(
							gs.economy_engine.format_money(
								sale_value
							)
							if (
								gs != null
								and gs.economy_engine != null
							)
							else "$%d" % sale_value
						)
					]
				}
			"cruise":
				var cruise_text: String = (
					"I took %s out for a cruise."
					% _vehicle_display_name(vehicle)
				)

				return _commit_vehicle_lifestyle_event(
					owner,
					vehicle,
					action_id,
					cruise_text
				)

			"go_fishing":
				var fishing_text: String = (
					"I went fishing from %s."
					% _vehicle_display_name(vehicle)
				)

				return _commit_vehicle_lifestyle_event(
					owner,
					vehicle,
					action_id,
					fishing_text
				)

			"host_boat_gathering":
				var gathering_text: String = (
					"I hosted a gathering aboard %s."
					% _vehicle_display_name(vehicle)
				)

				return _commit_vehicle_lifestyle_event(
					owner,
					vehicle,
					action_id,
					gathering_text
				)

			"host_yacht_party":
				var party_text: String = (
					"I hosted a luxury yacht party aboard %s."
					% _vehicle_display_name(vehicle)
				)

				return _commit_vehicle_lifestyle_event(
					owner,
					vehicle,
					action_id,
					party_text
				)

			"operate_casino_night":
				var casino_text: String = (
					"I operated a casino night aboard %s."
					% _vehicle_display_name(vehicle)
				)

				return _commit_vehicle_lifestyle_event(
					owner,
					vehicle,
					action_id,
					casino_text
				)

			"launch_missiles":
				return _commit_tank_missile_crime(
					owner,
					vehicle
				)
			_:
				return {
					"success": true,
					"text": "I used %s through %s." % [
						_vehicle_display_name(
							vehicle
						),
						action_id
					]
				}

	return {
		"success": false,
		"text": "That vehicle could not be found."
	}
func yearly_asset_ecology_tick(_payload:= {}) -> void:
	var payload: Dictionary = (
		_payload as Dictionary
		if typeof(_payload) == TYPE_DICTIONARY
		else {}
	)

	if (
		bool(
			payload.get(
				"runtime_managed",
				false
			)
		)
		and str(
			payload.get(
				"runtime_owner",
				""
			)
		).strip_edges() == "age_up_runtime"
	):
		simulate_npc_vehicle_market()
		return

	yearly_maintenance()
	simulate_npc_vehicle_market()


func _register_vehicle_for_owner(
	owner: Person,
	vehicle: Dictionary,
	share_with_partner:= false
) -> void:
	if owner == null:
		return

	if not vehicles.has(owner.id):
		vehicles [owner.id] = []

	# FIX: this was `vehicle in vehicles[owner.id]`, and `in` compares Dictionaries by
	# REFERENCE, not by contents. Any caller handing over a copy of the vehicle dict
	# (a rehydrate, a projection pass, a re-registration on view) therefore failed the
	# check and appended another entry, so the Assets panel -- which reads
	# vehicle_engine.vehicles directly -- grew one extra copy per visit. Two entries
	# with the same vehicle id are the same vehicle, so match on that instead.
	var vehicle_id: int = int(
		vehicle.get(
			"id",
			-1
		)
	)
	var owned: Array = vehicles [owner.id]
	var already_registered: bool = false

	if vehicle_id > 0:
		# Repair pass: collapse any duplicates a previous run already stored.
		var deduped: Array = []
		var seen_ids: Dictionary = {}

		for raw_existing in owned:
			if typeof(raw_existing) != TYPE_DICTIONARY:
				deduped.append(raw_existing)
				continue

			var existing_id: int = int(
				(raw_existing as Dictionary).get(
					"id",
					-1
				)
			)

			if existing_id > 0:
				if seen_ids.has(existing_id):
					continue
				seen_ids [existing_id] = true

			deduped.append(raw_existing)

		if deduped.size() != owned.size():
			EraLog.truth(
				"ERALIFE_VEHICLE_DUPLICATES_COLLAPSED|owner=%d|before=%d|after=%d"
				% [
					int(owner.id),
					owned.size(),
					deduped.size()
				]
			)

		owned = deduped
		vehicles [owner.id] = owned
		already_registered = seen_ids.has(vehicle_id)
	else:
		already_registered = vehicle in owned

	if not already_registered:
		vehicles [owner.id].append(vehicle)

	# DIAGNOSTIC: a vehicle appearing again on every visit to Assets means something
	# is registering it repeatedly. Report who, and whether the dedup check matched.
	EraLog.truth(
		"ERALIFE_VEHICLE_REGISTER|owner=%d|vehicle_id=%s|name=%s|already_registered=%s|owned_now=%d"
		% [
			int(owner.id),
			str(vehicle.get("id", -1)),
			str(vehicle.get("display_name", vehicle.get("model", "?"))),
			str(already_registered),
			vehicles [owner.id].size()
		]
	)

	_sync_vehicle_belongings_projection(
		owner,
		vehicle
	)
	_sync_vehicle_access_roles(
		vehicle,
		owner.id
	)

	if not share_with_partner:
		return

	var spouse: Person = gs.get_valid_partner(
		owner,
		true
	)

	if spouse == null or not spouse.alive:
		return

	if not vehicles.has(spouse.id):
		vehicles [spouse.id] = []

	if vehicle not in vehicles [spouse.id]:
		vehicles [spouse.id].append(vehicle)

	_sync_vehicle_belongings_projection(
		spouse,
		vehicle
	)
	_sync_vehicle_access_roles(
		vehicle,
		spouse.id
	)


func _sync_vehicle_access_roles(v: Dictionary, owner_id: int) -> void:
	var access_roles: Dictionary = v.get("access_roles", {})
	var owner_ids: Array = access_roles.get("owner_ids", [])
	if owner_id not in owner_ids:
		owner_ids.append(owner_id)
	access_roles ["owner_ids"] = owner_ids

	var household_user_ids: Array = access_roles.get("household_user_ids", [])
	if owner_id not in household_user_ids:
		household_user_ids.append(owner_id)
	access_roles ["household_user_ids"] = household_user_ids
	v ["access_roles"] = access_roles


func _remove_vehicle_refs(owner_id: int, asset_id: int) -> void:
	if not vehicles.has(owner_id):
		return
	var kept: Array = []
	for raw_vehicle in vehicles [owner_id]:
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		if int(raw_vehicle.get("id", -1)) != asset_id:
			kept.append(raw_vehicle)
	vehicles [owner_id] = kept


func handle_inheritance(payload) -> void:
	if gs == null:
		return
	var dead_id: int = -1
	if typeof(payload) == TYPE_DICTIONARY:
		dead_id = int(payload.get("npc_id", -1))
	elif payload is Person:
		dead_id = int(payload.id)

	if dead_id <= 0:
		return
	if gs.should_skip_manual_player_inheritance(dead_id):
		return
	if not vehicles.has(dead_id):
		return

	var dead_npc: Person = gs.get_or_reactivate_npc_by_id(dead_id)
	if dead_npc == null:
		return

	var heir: Person = gs.get_valid_partner(dead_npc, true)
	if heir == null or not heir.alive:
		for child_id in dead_npc.children:
			var child: Person = gs.get_or_reactivate_npc_by_id(int(child_id))
			if child != null and child.alive:
				heir = child
				break

	if heir == null:
		return

	var inherited: Array = vehicles.get(dead_id, []).duplicate(true)
	vehicles.erase(dead_id)

	for raw_vehicle in inherited:
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = raw_vehicle
		var provenance: Dictionary = v.get("provenance", {})
		provenance ["last_inherited_year"] = int(gs.year)
		provenance ["last_inherited_by"] = int(heir.id)
		v ["provenance"] = provenance
		_register_vehicle_for_owner(heir, v, false)


func simulate_npc_vehicle_market() -> void:
	if gs == null or gs.era_data_loader == null:
		return

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if npc == gs.player:
			continue
		if int(npc.age) < 16:
			continue

		var owned_count: int = vehicles.get(npc.id, []).size()

		if owned_count <= 0:
			if float(npc.bank_balance) < 1000.0:
				continue
			if randf() >= 0.05:
				continue

			var context: Dictionary = _build_npc_vehicle_market_context(npc)
			var luxury_level: int = int(context.get("luxury_level", 0))
			var template: Dictionary = gs.era_data_loader.get_best_transport_template_for_context(gs.era.name, context)
			if template.is_empty():
				continue
			var price: int = _calculate_vehicle_value(template, npc, context)
			if float(npc.bank_balance) < float(price):
				continue
			buy_vehicle(npc, template, price, luxury_level, context)
		else:
			if float(npc.bank_balance) < 0.0 or randf() < min(0.08, 0.02 * float(owned_count)):
				var owner_items: Array = vehicles.get(npc.id, [])
				if owner_items.is_empty():
					continue
				var chosen_idx: int = randi() % owner_items.size()
				var raw_vehicle: Variant = owner_items [chosen_idx]
				if typeof(raw_vehicle) != TYPE_DICTIONARY:
					continue
				run_asset_action(npc, int(raw_vehicle.get("id", -1)), "sell")
				continue

			if randf() < 0.015 and gs.social_graph_engine != null:
				var ties: Array = gs.social_graph_engine.strongest_connections(int(npc.id), 3)
				if ties.is_empty():
					continue
				var target_id: int = int(ties [randi() % ties.size()])
				var target: Person = gs.get_npc_by_id(target_id)
				if target == null or not target.alive or target == gs.player:
					continue
				if float(target.bank_balance) < 750.0:
					continue
				var owner_items: Array = vehicles.get(npc.id, [])
				if owner_items.is_empty():
					continue
				var raw_vehicle: Variant = owner_items [randi() % owner_items.size()]
				if typeof(raw_vehicle) != TYPE_DICTIONARY:
					continue
				trade_vehicle_between_npcs(npc, target, int(raw_vehicle.get("id", -1)))


func trade_vehicle_between_npcs(from_owner: Person, to_owner: Person, asset_id: int) -> Dictionary:
	if from_owner == null or to_owner == null:
		return { "success": false, "text": "Trade participants missing."}
	if not vehicles.has(from_owner.id):
		return { "success": false, "text": "No source vehicle inventory found."}

	var owner_items: Array = vehicles.get(from_owner.id, [])
	for i in range(owner_items.size()):
		var raw_vehicle: Variant = owner_items [i]
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = raw_vehicle
		if int(v.get("id", -1)) != asset_id:
			continue

		var transfer_value: int = int(round(float(v.get("value", 0)) * randf_range(0.85, 1.1)))
		if float(to_owner.bank_balance) < float(transfer_value):
			return { "success": false, "text": "Target owner cannot afford this trade."}

		to_owner.bank_balance -= transfer_value
		from_owner.bank_balance += transfer_value
		_remove_vehicle_refs(from_owner.id, asset_id)

		var access_roles: Dictionary = v.get("access_roles", {})
		access_roles ["owner_ids"] = []
		access_roles ["household_user_ids"] = []
		v ["access_roles"] = access_roles

		_register_vehicle_for_owner(to_owner, v, false)

		if gs != null and gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.TRADE_EXECUTED, {
				"npc_id": int(from_owner.id),
				"target_id": int(to_owner.id),
				"text": "%s %s traded %s to %s %s." % [
					from_owner.first_name,
					from_owner.last_name,
					str(v.get("display_name", v.get("type", "Vehicle"))),
					to_owner.first_name,
					to_owner.last_name
				],
				"source": "vehicle_engine"
			})

		return { "success": true, "text": "Trade completed."}

	return { "success": false, "text": "Vehicle not found for trade."}


func get_asset_signal_rollup_for_owner(owner: Person) -> Dictionary:
	if owner == null:
		return {}
	if not vehicles.has(owner.id):
		return {}
	var rollup: Dictionary = {
		"asset_count": 0,
		"dependency_pressure": 0.0,
		"prestige_total": 0.0,
		"modifier_weight": 0.0,
		"portfolio_tags": {},
		"event_hooks": {},
		"passive_modifiers": {},
		"prestige_signals": {},
		"status_signals": {},
		"pressure_profile": {},
		"asset_namespaces": {},
		"asset_class_filters": {},
		"asset_identity_modes": {},
		"asset_tier_profile": {},
		"asset_provenance_signals": {},
		"asset_condition_profile": {},
		"asset_uniqueness_score": 0.0
	}
	var seen: Dictionary = {}
	for raw_vehicle in vehicles.get(owner.id, []):
		if typeof(raw_vehicle) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = raw_vehicle
		var asset_id: int = int(v.get("id", -1))
		if asset_id <= 0 or seen.has(asset_id):
			continue
		seen [asset_id] = true
		_absorb_vehicle_into_rollup(rollup, v)
	if int(rollup.get("asset_count", 0)) <= 0:
		return {}
	_finalize_vehicle_rollup(rollup)
	return rollup


func get_global_asset_signal_rollup() -> Dictionary:
	var rollup: Dictionary = {
		"asset_count": 0,
		"dependency_pressure": 0.0,
		"prestige_total": 0.0,
		"modifier_weight": 0.0,
		"portfolio_tags": {},
		"event_hooks": {},
		"passive_modifiers": {},
		"prestige_signals": {}
	}
	var seen: Dictionary = {}

	for npc_id in vehicles.keys():
		for raw_vehicle in vehicles [npc_id]:
			if typeof(raw_vehicle) != TYPE_DICTIONARY:
				continue
			var v: Dictionary = raw_vehicle
			var asset_id: int = int(v.get("id", -1))
			if asset_id <= 0 or seen.has(asset_id):
				continue
			seen [asset_id] = true
			_absorb_vehicle_into_rollup(rollup, v)

	if int(rollup.get("asset_count", 0)) <= 0:
		return {}
	return rollup


func get_yearly_event_fragments_for_owner(owner: Person) -> Array:
	var out: Array = []
	var rollup: Dictionary = get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return out
	var passive_modifiers: Dictionary = rollup.get("passive_modifiers", {})
	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	var event_hooks: Dictionary = rollup.get("event_hooks", {})
	var status_signals: Dictionary = rollup.get("status_signals", rollup.get("prestige_signals", {}))
	var pressure_profile: Dictionary = rollup.get("pressure_profile", {})
	var dependency_pressure: float = float(rollup.get("dependency_pressure", 0.0))
	var criminal_usefulness: float = float(pressure_profile.get("criminal_usefulness", 0.0))
	var romance_signal: float = float(pressure_profile.get("romance_signal", 0.0))
	var _spectacle: float = float(pressure_profile.get("spectacle", 0.0))
	var _fame_visibility: float = float(status_signals.get("fame_visibility", 0.0))
	var storm_hook_count: int = int(event_hooks.get("storm_exposure", 0)) + int(event_hooks.get("storm_risk", 0))
	var smuggling_hook_count: int = int(event_hooks.get("smuggling", 0)) + int(event_hooks.get("store_contraband", 0))
	if dependency_pressure >= 1.0 or float(pressure_profile.get("upkeep", 0.0)) >= 1.5:
		out.append({
			"type": "text",
			"text": "Your transportation needs created logistical pressure this year.",
			"world_text": "%s's transportation needs created logistical pressure this year."
		})
	if float(passive_modifiers.get("travel_access", 0.0)) > 0.0 or float(passive_modifiers.get("region_mobility", 0.0)) > 0.0:
		out.append({
			"type": "text",
			"text": "What you owned changed how far, fast, and freely you could move.",
			"world_text": "%s's mobility assets changed how far, fast, and freely life could move this year."
		})
	if int(portfolio_tags.get("fleets", 0)) >= 1 or int(portfolio_tags.get("stables", 0)) >= 1:
		out.append({
			"type": "text",
			"text": "Your mobility assets started to feel like a real network instead of a single ride.",
			"world_text": "%s's mobility assets started to feel like a real network instead of a single ride."
		})
	if storm_hook_count >= 1:
		out.append({
			"type": "text",
			"text": "Your more exposed routes pulled weather risk and travel uncertainty into the year.",
			"world_text": "%s's more exposed routes pulled weather risk and travel uncertainty into the year."
		})
	if smuggling_hook_count >= 1 or criminal_usefulness >= 1.5:
		out.append({
			"type": "text",
			"text": "The wrong kind of movement kept brushing against your year, opening shady opportunities and extra risk.",
			"world_text": "The way %s moved through the world invited shady opportunities and extra risk this year."
		})
	if romance_signal >= 1.5 and float(passive_modifiers.get("comfort", 0.0)) > 0.0:
		out.append({
			"type": "text",
			"text": "Travel and comfort reshaped parts of your social and romantic atmosphere this year.",
			"world_text": "Travel and comfort reshaped parts of %s's social and romantic atmosphere this year."
		})
	return out


func _absorb_vehicle_into_rollup(rollup: Dictionary, v: Dictionary) -> void:
	rollup ["asset_count"] = int(rollup.get("asset_count", 0)) + 1
	var dependency_state: Dictionary = v.get("dependency_state", {})
	var missing_requirements: Array = dependency_state.get("requirements_missing", [])
	rollup ["dependency_pressure"] = float(rollup.get("dependency_pressure", 0.0)) + float(missing_requirements.size())

	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	for raw_tag in v.get("portfolio_tags", []):
		var tag:= str(raw_tag)
		portfolio_tags [tag] = int(portfolio_tags.get(tag, 0)) + 1
	rollup ["portfolio_tags"] = portfolio_tags

	var event_hooks: Dictionary = rollup.get("event_hooks", {})
	for raw_hook in v.get("event_hooks", []):
		var hook_name:= str(raw_hook)
		event_hooks [hook_name] = int(event_hooks.get(hook_name, 0)) + 1
	rollup ["event_hooks"] = event_hooks

	var passive_modifiers: Dictionary = rollup.get("passive_modifiers", {})
	for key in v.get("passive_modifiers", {}).keys():
		var k:= str(key)
		var value:= float(v.get("passive_modifiers", {}).get(key, 0.0))
		passive_modifiers [k] = float(passive_modifiers.get(k, 0.0)) + value
		rollup ["modifier_weight"] = float(rollup.get("modifier_weight", 0.0)) + abs(value)
	rollup ["passive_modifiers"] = passive_modifiers

	var prestige_signals: Dictionary = rollup.get("prestige_signals", {})
	for key in v.get("prestige_signals", {}).keys():
		var k:= str(key)
		var value:= float(v.get("prestige_signals", {}).get(key, 0.0))
		prestige_signals [k] = float(prestige_signals.get(k, 0.0)) + value
		rollup ["prestige_total"] = float(rollup.get("prestige_total", 0.0)) + max(0.0, value)
	rollup ["prestige_signals"] = prestige_signals

	var status_signals_source: Dictionary = v.get("status_signals", v.get("prestige_signals", {}))
	var status_signals: Dictionary = rollup.get("status_signals", {})
	for key in status_signals_source.keys():
		var k:= str(key)
		var value:= float(status_signals_source.get(key, 0.0))
		status_signals [k] = float(status_signals.get(k, 0.0)) + value
	rollup ["status_signals"] = status_signals

	var pressure_profile_source: Dictionary = v.get("pressure_profile", {})
	var pressure_profile: Dictionary = rollup.get("pressure_profile", {})
	for key in pressure_profile_source.keys():
		var k:= str(key)
		var value:= float(pressure_profile_source.get(key, 0.0))
		pressure_profile [k] = float(pressure_profile.get(k, 0.0)) + value
	rollup ["pressure_profile"] = pressure_profile

	var asset_namespaces: Dictionary = rollup.get("asset_namespaces", {})
	var namespace_key: String = _vehicle_asset_namespace(v)
	if namespace_key != "":
		_increment_counter_map(asset_namespaces, namespace_key)
	rollup ["asset_namespaces"] = asset_namespaces

	var asset_class_filters: Dictionary = rollup.get("asset_class_filters", {})
	for raw_key in _vehicle_asset_class_keys(v):
		var class_key: String = str(raw_key)
		if class_key != "":
			_increment_counter_map(asset_class_filters, class_key)
	rollup ["asset_class_filters"] = asset_class_filters

	var asset_identity_modes: Dictionary = rollup.get("asset_identity_modes", {})
	for raw_mode in _vehicle_asset_identity_modes(v, namespace_key):
		var mode_key: String = str(raw_mode)
		if mode_key != "":
			_increment_counter_map(asset_identity_modes, mode_key)
	rollup ["asset_identity_modes"] = asset_identity_modes

	var asset_tier_profile: Dictionary = rollup.get("asset_tier_profile", {})
	var tier_key: String = _asset_tier_key_from_labels(
		str(v.get("social_tier", "common")),
		str(v.get("value_band", "entry"))
	)
	if tier_key != "":
		_increment_float_map(asset_tier_profile, tier_key, 1.0)
	rollup ["asset_tier_profile"] = asset_tier_profile

	var asset_condition_profile: Dictionary = rollup.get("asset_condition_profile", {})
	var condition_key: String = _asset_condition_key(v)
	if condition_key != "":
		_increment_float_map(asset_condition_profile, condition_key, 1.0)
	rollup ["asset_condition_profile"] = asset_condition_profile

	var asset_provenance_signals: Dictionary = rollup.get("asset_provenance_signals", {})
	for raw_key in _vehicle_asset_provenance_keys(v):
		var provenance_key: String = str(raw_key)
		if provenance_key != "":
			_increment_float_map(asset_provenance_signals, provenance_key, 1.0)
	rollup ["asset_provenance_signals"] = asset_provenance_signals
func _finalize_vehicle_rollup(rollup: Dictionary) -> void:
	var asset_namespaces: Dictionary = rollup.get("asset_namespaces", {})
	var asset_identity_modes: Dictionary = rollup.get("asset_identity_modes", {})
	var asset_tier_profile: Dictionary = rollup.get("asset_tier_profile", {})
	var uniqueness_score: float = 0.0
	uniqueness_score += float(asset_namespaces.size()) * 1.1
	uniqueness_score += float(asset_identity_modes.size()) * 0.85
	if float(asset_tier_profile.get("wealthy", 0.0)) > 0.0 or float(asset_tier_profile.get("noble", 0.0)) > 0.0:
		uniqueness_score += 1.1
	if int(rollup.get("asset_count", 0)) == 1 and asset_namespaces.size() == 1:
		uniqueness_score += 0.6
	rollup ["asset_uniqueness_score"] = uniqueness_score


func _vehicle_asset_namespace(v: Dictionary) -> String:
	var display_name: String = str(v.get("display_name", v.get("type", "Vehicle"))).to_lower()
	var subtype: String = str(v.get("subtype", "")).to_lower()
	var archetype: String = str(v.get("archetype", "personal_transport")).to_lower()

	if display_name.findn("yacht") != -1:
		return "vehicle.yacht"
	if display_name.findn("boat") != -1 or display_name.findn("ship") != -1 or display_name.findn("ferry") != -1 or display_name.findn("submarine") != -1:
		return "vehicle.maritime"
	if display_name.findn("truck") != -1 or display_name.findn("van") != -1 or display_name.findn("hauler") != -1:
		return "vehicle.utility_truck"
	if display_name.findn("armored") != -1:
		return "vehicle.armored_transport"
	if display_name.findn("jet") != -1 or display_name.findn("helicopter") != -1 or display_name.findn("plane") != -1:
		return "vehicle.private_aviation"
	if subtype != "":
		return "vehicle.%s" % subtype
	if archetype != "":
		return "vehicle.%s" % archetype
	return "vehicle.personal_transport"


func _vehicle_asset_class_keys(v: Dictionary) -> Array:
	var out: Array = []
	var archetype: String = str(v.get("archetype", "personal_transport")).to_lower()
	var social_tier: String = str(v.get("social_tier", "common")).to_lower()

	if archetype != "":
		out.append("vehicle.archetype.%s" % archetype)
	if social_tier != "":
		out.append("vehicle.tier.%s" % social_tier)

	for raw_tag in v.get("feature_tags", []):
		var tag: String = str(raw_tag).to_lower()
		if tag != "":
			out.append("vehicle.feature.%s" % tag)

	return out


func _vehicle_asset_identity_modes(v: Dictionary, namespace_key: String = "") -> Array:
	var out: Array = []
	var pressure_profile: Dictionary = v.get("pressure_profile", {})
	var event_hooks: Array = v.get("event_hooks", [])
	var condition: float = float(v.get("condition", 100.0))

	out.append("mobility_base")

	if namespace_key == "vehicle.yacht":
		out.append("spectacle_carrier")
	if float(pressure_profile.get("spectacle", 0.0)) > 1.0 or _string_array_contains(event_hooks, "luxury_arrivals") or _string_array_contains(event_hooks, "party_hosting") or _string_array_contains(event_hooks, "celebrity_sightings"):
		out.append("spectacle_carrier")
	if float(pressure_profile.get("criminal_usefulness", 0.0)) > 0.0 or _string_array_contains(event_hooks, "smuggling") or _string_array_contains(event_hooks, "store_contraband"):
		out.append("smuggling_channel")
	if _string_array_contains(event_hooks, "storm_exposure") or _string_array_contains(event_hooks, "storm_risk"):
		out.append("weather_exposed")
	if _vehicle_was_inherited(v):
		out.append("inheritance_anchor")
	if condition <= 45.0:
		out.append("fragile_transport")

	_dedupe_string_array_in_place(out)
	return out


func _vehicle_asset_provenance_keys(v: Dictionary) -> Array:
	var out: Array = []
	var provenance: Dictionary = v.get("provenance", {})
	var acquisition_mode: String = str(
		provenance.get(
			"acquisition_mode",
			v.get("acquisition_mode", provenance.get("acquired_via", ""))
		)
	).to_lower()
	var event_hooks: Array = v.get("event_hooks", [])
	var pressure_profile: Dictionary = v.get("pressure_profile", {})

	if provenance.has("last_inherited_year") or acquisition_mode.findn("inherit") != -1:
		out.append("inherited")
	elif acquisition_mode.findn("gift") != -1:
		out.append("gifted")
	elif acquisition_mode.findn("buy") != -1 or acquisition_mode.findn("purch") != -1:
		out.append("bought")
	elif int(v.get("value", v.get("price", 0))) > 0:
		out.append("bought")

	if _string_array_contains(event_hooks, "smuggling") or _string_array_contains(event_hooks, "store_contraband"):
		out.append("suspicious")
	if float(pressure_profile.get("spectacle", 0.0)) > 1.0:
		out.append("famous")

	_dedupe_string_array_in_place(out)
	return out


func _vehicle_was_inherited(v: Dictionary) -> bool:
	var provenance: Dictionary = v.get("provenance", {})
	if provenance.has("last_inherited_year"):
		return true
	var acquisition_mode: String = str(
		provenance.get(
			"acquisition_mode",
			v.get("acquisition_mode", provenance.get("acquired_via", ""))
		)
	).to_lower()
	return acquisition_mode.findn("inherit") != -1


func _asset_tier_key_from_labels(social_tier: String, value_band: String) -> String:
	var tier_text: String = social_tier.to_lower()
	match tier_text:
		"working_class", "common", "entry":
			return "entry"
		"respectable", "mid", "midtier":
			return "respectable"
		"wealthy", "luxury":
			return "wealthy"
		"noble", "royal", "elite":
			return "noble"
		_:
			match value_band.to_lower():
				"entry":
					return "entry"
				"mid", "standard":
					return "respectable"
				"luxury", "premium":
					return "wealthy"
				"rare", "legendary", "noble":
					return "noble"
	return "entry"


func _asset_condition_key(asset: Dictionary) -> String:
	var condition: float = float(asset.get("condition", 100.0))
	if condition >= 90.0:
		return "pristine"
	if condition >= 70.0:
		return "stable"
	if condition >= 45.0:
		return "neglected"
	return "decaying"


func _increment_counter_map(dest: Dictionary, key: String, amount: int = 1) -> void:
	if key == "":
		return
	dest [key] = int(dest.get(key, 0)) + amount


func _increment_float_map(dest: Dictionary, key: String, amount: float = 1.0) -> void:
	if key == "":
		return
	dest [key] = float(dest.get(key, 0.0)) + amount


func _string_array_contains(arr: Array, needle: String) -> bool:
	for raw_value in arr:
		if str(raw_value).to_lower() == needle.to_lower():
			return true
	return false


func _dedupe_string_array_in_place(arr: Array) -> void:
	var seen: Dictionary = {}
	var deduped: Array = []
	for raw_value in arr:
		var value: String = str(raw_value)
		if value == "" or seen.has(value):
			continue
		seen [value] = true
		deduped.append(value)
	arr.clear()
	arr.append_array(deduped)


func _build_npc_vehicle_market_context(npc: Person) -> Dictionary:
	var desired_tags: Array = ["land"]
	var luxury_level: int = 0
	var social_tier:= "respectable"
	var social_class:= str(npc.social_class).to_lower()

	match social_class:
		"merchant":
			social_tier = "wealthy"
			luxury_level = max(luxury_level, 1)
		"noble":
			social_tier = "aristocrat"
			luxury_level = max(luxury_level, 2)
			if "luxury" not in desired_tags:
				desired_tags.append("luxury")
		"royal":
			social_tier = "royal"
			luxury_level = max(luxury_level, 4)
			for tag in ["luxury", "family_seat"]:
				if tag not in desired_tags:
					desired_tags.append(tag)

	if float(npc.fame) >= 60.0:
		if "luxury" not in desired_tags:
			desired_tags.append("luxury")
		luxury_level = max(luxury_level, 2)
	if float(npc.fame) >= 80.0:
		luxury_level = max(luxury_level, 3)
	if npc.children.size() > 0 and "family_seat" not in desired_tags:
		desired_tags.append("family_seat")
	if float(npc.bank_balance) >= 250000.0 and social_tier not in ["royal", "aristocrat"]:
		social_tier = "wealthy"
	if float(npc.fame) >= 80.0 and social_tier not in ["royal"]:
		social_tier = "celebrity"
	if npc.is_royal or npc.is_ruler:
		social_tier = "royal"
		luxury_level = max(luxury_level, 4)
		for tag in ["luxury", "family_seat"]:
			if tag not in desired_tags:
				desired_tags.append(tag)

	return {
		"desired_tags": desired_tags,
		"luxury_level": luxury_level,
		"social_tier": social_tier,
		"network_type": "road",
		"market_climate": "stable"
	}
func _vehicle_condition_label(score: float) -> String:
	if score >= 90.0:
		return "Excellent"
	if score >= 75.0:
		return "Good"
	if score >= 55.0:
		return "Worn"
	if score >= 30.0:
		return "Strained"
	return "Critical"
func get_buyable_transport_templates_for_person(person: Person, desired_tags:= [], extra_context:= {}) -> Array:
	var out: Array = []
	if gs == null or gs.era_data_loader == null:
		return out

	var context: Dictionary = extra_context.duplicate(true)
	if not context.has("desired_tags"):
		context ["desired_tags"] = desired_tags.duplicate()

	for raw_template in gs.era_data_loader.get_transport_templates_for_era(gs.era.name):
		if typeof(raw_template) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = raw_template
		if _transport_template_matches_person(template, person, context):
			out.append(template.duplicate(true))

	return out


func _transport_template_matches_person(template: Dictionary, _person: Person, context:= {}) -> bool:
	if gs == null or gs.era_data_loader == null:
		return false
	return gs.era_data_loader.template_matches_context(template, context)

func _label_for_vehicle_action(
	action_id: String
) -> String:
	match action_id:
		"inspect":
			return "Inspect"
		"rename":
			return "Rename"
		"sell":
			return "Sell"
		"gift":
			return "Gift"
		"maintain":
			return "Maintain"
		"repair":
			return "Repair"
		"use":
			return "Use"
		"ride":
			return "Ride"
		"drive":
			return "Drive"
		"sail":
			return "Sail"
		"road_trip":
			return "Road Trip"
		"transport_goods":
			return "Transport Goods"
		"assign_driver":
			return "Assign Driver"
		"assign_captain":
			return "Assign Captain"
		"activate_defense_grid":
			return "Activate Defense Grid"
		"go_fishing":
			return "Go Fishing"
		"cruise":
			return "Go Cruising"
		"host_boat_gathering":
			return "Host Boat Gathering"
		"host_yacht_party":
			return "Host Yacht Party"
		"operate_casino_night":
			return "Operate Casino Night"
		"launch_missiles":
			return "Launch Missiles"
		_:
			return action_id.replace(
				"_",
				" "
			).capitalize()
func _commit_vehicle_lifestyle_event(
	owner: Person,
	vehicle: Dictionary,
	action_id: String,
	text: String
) -> Dictionary:
	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"vehicle.lifestyle_action",
			{
				"actor_id": int(owner.id),
				"vehicle_id": int(
					vehicle.get(
						"id",
						-1
					)
				),
				"template_id": str(
					vehicle.get(
						"template_id",
						""
					)
				),
				"action_id": action_id,
				"text": text,
				"source": ENGINE_SCHEMA
			}
		)

	return {
		"success": true,
		"text": text,
		"vehicle_id": int(
			vehicle.get(
				"id",
				-1
			)
		),
		"action_id": action_id
	}


func _commit_tank_missile_crime(
	owner: Person,
	vehicle: Dictionary
) -> Dictionary:
	var tags: Array = _safe_array(
		vehicle.get(
			"feature_tags",
			[]
		)
	)

	if (
		not tags.has("missile_platform")
		and not bool(
			vehicle.get(
				"weapon_platform",
				false
			)
		)
	):
		return {
			"success": false,
			"text": (
				"This vehicle does not contain a missile-platform contract."
			)
		}

	var clearance: Dictionary = (
		_actor_restricted_vehicle_clearance_contract(
			owner,
			vehicle
		)
	)

	if not bool(
		clearance.get(
			"granted",
			false
		)
	):
		return {
			"success": false,
			"text": str(
				clearance.get(
					"reason",
					"Strategic clearance denied."
				)
			)
		}

	if str(
		vehicle.get(
			"storage_status",
			"unstored"
		)
	) != "stored":
		return {
			"success": false,
			"text": (
				"This restricted vehicle must be secured inside an underground bunker before its weapons contract can be accessed."
			)
		}

	var property_contract: Dictionary = (
		_find_owned_property(
			owner,
			int(
				vehicle.get(
					"stored_at_property_id",
					-1
				)
			)
		)
	)

	if not _property_has_underground_bunker(
		property_contract
	):
		return {
			"success": false,
			"text": (
				"The tank is not secured at a valid underground bunker."
			)
		}

	if (
		gs == null
		or gs.player == null
		or int(gs.player.id) != int(owner.id)
	):
		return {
			"success": false,
			"text": (
				"Only the currently controlled actor can commit this action."
			)
		}

	var crime_name: String = (
		"Strategic Missile Attack Against Civilians"
	)
	var crime_payload: Dictionary = {
		"crime_name": crime_name,
		"severity": 100.0,
		"intent": "mass_violence",
		"weapon_name": _vehicle_display_name(
			vehicle
		),
		"crime": {
			"name": crime_name,
			"charge_success": (
				"Mass Casualty Attack"
			),
			"severity": 100.0,
			"sentence_success": 45,
			"base_sentence_years": 45,
			"violent": true,
			"charges": [
				"Mass Casualty Attack",
				"Unlawful Use of Strategic Weapons",
				"Crimes Against Civilians",
				"Destruction of Property",
				"Abuse of Military Authority"
			]
		},
		"vehicle_id": int(
			vehicle.get(
				"id",
				-1
			)
		),
		"source": ENGINE_SCHEMA
	}

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.NPC_COMMITTED_CRIME,
			{
				"npc_id": int(owner.id),
				"actor_id": int(owner.id),
				"crime_name": crime_name,
				"vehicle_id": int(
					vehicle.get(
						"id",
						-1
					)
				),
				"text": "%s launched a strategic missile attack against civilians." % [
					owner.first_name
				],
				"data": crime_payload.duplicate(
					true
				)
			}
		)

	if (
		gs.case_orchestrator != null
		and gs.case_orchestrator.has_method(
			"start_player_crime_case"
		)
	):
		return (
			gs.case_orchestrator
			.start_player_crime_case(
				crime_payload
			)
		)

	return {
		"success": true,
		"text": (
			"The missile attack was committed and entered the crime-and-justice pipeline."
		),
		"crime_name": crime_name
	}
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _gen_id() -> int:
	if gs == null:
		return -1

	gs.next_id += 1
	return int(gs.next_id)