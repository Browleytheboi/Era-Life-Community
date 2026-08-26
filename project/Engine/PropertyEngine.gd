extends Resource
class_name PropertyEngine

const ENGINE_SCHEMA:= "eralife.property_contract_engine"
const ASSET_CONTRACT_SCHEMA:= "eralife.property_asset_contract"
const PORTFOLIO_CONTRACT_SCHEMA:= "eralife.property_portfolio_contract"
const ACTION_CONTRACT_SCHEMA:= "eralife.property_action_contract"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "property_contract_engine_state"

var gs: GameState = null




var properties: Dictionary = {}
var used_addresses: Dictionary = {}

var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var _bound_event_bus_instance_id: int = -1
var spousal_property_settlement_queue: Array = []
var spousal_property_settlement_service_armed: bool = false

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
		"engine_file": "PropertyEngine.gd",
		"internal_role": "PropertyContractEngine",
		"asset_contract_schema": ASSET_CONTRACT_SCHEMA,
		"portfolio_contract_schema": PORTFOLIO_CONTRACT_SCHEMA,
		"action_contract_schema": ACTION_CONTRACT_SCHEMA,
		"spatial_topology_schema": "eralife.property.spatial_topology_contract",
		"spatial_node_schema": "eralife.property.spatial_node_contract",
		"spatial_edge_schema": "eralife.property.spatial_edge_contract",
		"runtime_truth_authority": true,
		"catalog_authority": "EraLifeAssetCatalogExpansion",
		"amenity_authority": "PropertyAmenitySynthesisContractEngine",
		"market_authority": "PropertyMarketContractEngine",
		"spatial_authorities": [
			"PropertyEngine",
			"RoomGraphContractEngine",
			"SpatialTraversalContractEngine",
			"PresenceEngine"
		],
		"spatial_resolution_flow": [
			"property_asset_contract",
			"persistent_spatial_topology",
			"current_node",
			"adjacent_edge_contracts",
			"movement_affordance_contracts",
			"ui_lens"
		],
		"supported_topology_mutations": [
			"add_node",
			"remove_node",
			"convert_node_type",
			"add_edge",
			"remove_edge",
			"damage_node",
			"repair_node",
			"lock_edge",
			"unlock_edge",
			"add_fixture",
			"remove_fixture"
		],
		"mutation_flow": [
			"intent",
			"property_contract_resolution",
			"reality_mutation",
			"continuous_reality_rendering",
			"ui_lens"
		],
		"ui_is_renderer_only": true
	}

func get_contract() -> Dictionary:
	return contract()
func resolve_property_spatial_topology_contract(
	actor: Person,
	property_asset: Dictionary,
	reality_node: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if property_asset.is_empty():
		return {
			"success": false,
			"reason": "missing_property_asset",
			"schema": "eralife.property.spatial_topology_resolution",
			"version": CONTRACT_VERSION,
			"spatial_topology": {},
			"floors": [],
			"navigation_actions": [],
			"truth_state": "missing_property_but_observable",
			"property_contract_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	if gs == null or gs.room_graph_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_room_graph_contract_engine",
			"schema": "eralife.property.spatial_topology_resolution",
			"version": CONTRACT_VERSION,
			"property_id": int(
				property_asset.get(
					"id",
					-1
				)
			),
			"spatial_topology": {},
			"floors": [],
			"navigation_actions": [],
			"truth_state": "observable_partial",
			"property_contract_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true,
		}



	var graph: Dictionary = (
		gs.room_graph_contract_engine
		.emit_room_graph_contract(
			actor,
			property_asset,
			reality_node
		)
	)
	graph = apply_native_property_spatial_profile_contract(
		property_asset,
		graph
	)

	if (
		gs.spatial_traversal_contract_engine != null
		and gs.spatial_traversal_contract_engine.has_method(
			"project_resident_property_graph_cursor"
		)
	):
		graph = (
			gs.spatial_traversal_contract_engine
			.project_resident_property_graph_cursor(
				actor,
				property_asset,
				reality_node,
				graph
			)
		)

	graph ["success"] = true
	graph ["schema"] = (
		"eralife.property.spatial_topology_resolution"
	)
	graph ["version"] = CONTRACT_VERSION
	graph ["property_id"] = int(
		property_asset.get(
			"id",
			-1
		)
	)
	graph ["property_contract_authority"] = ENGINE_SCHEMA
	graph ["structure_authority"] = (
		"eralife.room_graph_contract_engine"
	)
	graph ["movement_authority"] = (
		"eralife.spatial_traversal_contract_engine"
	)
	graph ["context"] = context.duplicate(false)
	graph ["ui_is_renderer_only"] = true



	last_contract_report = {
		"schema": (
			"eralife.property.spatial_topology_resolution_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"property_id": int(
			property_asset.get(
				"id",
				-1
			)
		),
		"active_floor": int(
			graph.get(
				"active_floor",
				0
			)
		),
		"active_room": str(
			graph.get(
				"active_room",
				""
			)
		),
		"truth_state": str(
			graph.get(
				"truth_state",
				"observable"
			)
		),
	}

	_publish_contract_state(
		"property_spatial_topology_resolved"
	)
	return graph

func apply_property_spatial_topology_mutation(
	actor: Person,
	property_asset: Dictionary,
	reality_node: Dictionary,
	mutation_contract: Dictionary
) -> Dictionary:
	if mutation_contract.is_empty():
		return {
			"success": false,
			"reason": "missing_topology_mutation",
			"property_contract_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	if gs == null or gs.room_graph_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_room_graph_contract_engine",
			"property_contract_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var report: Dictionary = (
		gs.room_graph_contract_engine
		.apply_topology_mutation(
			actor,
			property_asset,
			reality_node,
			mutation_contract
		)
	)

	var property_id: int = int(
		property_asset.get(
			"id",
			reality_node.get(
				"property_id",
				-1
			)
		)
	)
	report ["schema"] = (
		"eralife.property.spatial_topology_mutation_report"
	)
	report ["version"] = CONTRACT_VERSION
	report ["property_id"] = property_id
	report ["property_contract_authority"] = ENGINE_SCHEMA
	report ["structure_authority"] = (
		"eralife.room_graph_contract_engine"
	)
	report ["ui_is_renderer_only"] = true



	last_contract_report = {
		"schema": (
			"eralife.property.spatial_topology_mutation_receipt"
		),
		"version": CONTRACT_VERSION,
		"success": bool(
			report.get(
				"success",
				false
			)
		),
		"property_id": property_id,
		"mutation_kind": str(
			mutation_contract.get(
				"kind",
				""
			)
		),
		"edge_id": str(
			mutation_contract.get(
				"edge_id",
				""
			)
		),
		"security_mode": str(
			mutation_contract.get(
				"security_mode",
				""
			)
		),
		"actor_id": int(
			actor.id
			if actor != null
			else -1
		),
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_publish_contract_state(
		"property_spatial_topology_mutated"
	)
	return report

func emit_property_portfolio_contract(
	owner: Person,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null:
		return {
			"success": false,
			"schema": PORTFOLIO_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_owner",
			"property_contracts": []
		}

	var property_contracts: Array = []
	var controlled_properties: Array = (
		_controlled_properties_for_actor(
			owner,
			true
		)
	)

	for raw_property in controlled_properties:
		var property_asset: Dictionary = (
			_safe_dictionary(
				raw_property
			)
		)

		if property_asset.is_empty():
			continue

		property_contracts.append(
			_property_asset_contract(
				owner,
				property_asset,
				context
			)
		)

	var report: Dictionary = {
		"success": true,
		"schema": PORTFOLIO_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"owner_id": int(owner.id),
		"property_contracts": property_contracts,
		"property_count": property_contracts.size(),
		"source_engine": ENGINE_SCHEMA,
		"runtime_truth_authority": true,
		"ui_is_renderer_only": true,
		"context": context.duplicate(true)
	}

	last_contract_report = report.duplicate(true)

	_publish_contract_state(
		"property_portfolio_emitted"
	)

	return report


func resolve_property_asset_contract(
	owner: Person,
	asset_id: int,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null or asset_id <= 0:
		return {}

	for raw_property in _safe_array(
		properties.get(owner.id, [])
	):
		var property_asset: Dictionary = _safe_dictionary(
			raw_property
		)

		if int(
			property_asset.get("id", -1)
		) != asset_id:
			continue

		return _property_asset_contract(
			owner,
			property_asset,
			context
		)

	return {}
func _property_party_place_label(
	prop: Dictionary
) -> String:
	var property_name: String = str(
		prop.get(
			"nickname",
			""
		)
	).strip_edges()

	if property_name == "":
		property_name = str(
			prop.get(
				"display_name",
				prop.get(
					"type",
					"Property"
				)
			)
		).strip_edges()

	if property_name == "":
		property_name = "Property"

	var address: String = str(
		prop.get(
			"address",
			"Unknown Address"
		)
	).strip_edges()

	if address == "":
		address = "Unknown Address"

	return "%s at %s" % [
		property_name,
		address
	]
func _property_party_choice(
	choice_id: String,
	label: String,
	size: String,
	privacy: String,
	property_id: int,
	property_contract: Dictionary
) -> Dictionary:
	return {
		"id": choice_id,
		"label": label,
		"text": label,
		"detail_action": "engine_call",
		"engine_property": "property_engine",
		"method": "commit_property_contract_action",
		"commits_reality_truth": true,
		"authority_prevalidated": false,
		"payload": {
			"action_id": "throw_party",
			"property_id": property_id,
			"asset_id": property_id,
			"party_size": size,
			"privacy": privacy,
			"property_contract": (
				property_contract.duplicate(false)
			),
			"source": (
				"property_party_choice"
			)
		},
		"preview_lines": [
			"Size: %s" % size.capitalize(),
			(
				"Privacy: %s"
				% privacy.replace(
					"_",
					" "
				).capitalize()
			),
			"Attendance resolves after commitment."
		]
	}
func _property_party_choice_result(
	actor: Person,
	property_id: int,
	property_contract: Dictionary
) -> Dictionary:
	var place_label: String = (
		_property_party_place_label(
			property_contract
		)
	)

	return {
		"success": true,
		"committed": false,
		"reality_mutation_committed": false,
		"popup_title": "Throw Party",
		"popup_text": (
			"Choose the scale and privacy level for your party at %s."
			% place_label
		),
		"popup_footer": (
			"Intent is not action. Choosing a party option commits the party."
		),
		"force_immediate_popup": true,
		"choices": [
			_property_party_choice(
				"small_private",
				"Small Private Party",
				"small",
				"private",
				property_id,
				property_contract
			),
			_property_party_choice(
				"medium_invite",
				"Invite-Only Reception",
				"medium",
				"invite_only",
				property_id,
				property_contract
			),
			_property_party_choice(
				"large_public",
				"Large Public Celebration",
				"large",
				"public",
				property_id,
				property_contract
			),
			_property_party_choice(
				"national_public",
				"Major Public Event",
				"national",
				"public",
				property_id,
				property_contract
			)
		],
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"property_id": property_id
	}
func _property_party_attendance(
	actor: Person,
	prop: Dictionary,
	party_size: String,
	privacy: String
) -> int:
	var base: int = 40

	match party_size:
		"small":
			base = 12
		"medium":
			base = 40
		"large":
			base = 140
		"national":
			base = 420

	var privacy_factor: float = 1.0

	match privacy:
		"private":
			privacy_factor = 0.45
		"invite_only":
			privacy_factor = 0.82
		"public":
			privacy_factor = 1.35

	var fame_value: int = (
		int(actor.fame)
		if actor != null
		else 0
	)
	var prestige: Dictionary = _safe_dictionary(
		prop.get(
			"prestige_signals",
			{}
		)
	)
	var prestige_bonus: float = 0.0

	for raw_value in prestige.values():
		if typeof(raw_value) in [
			TYPE_INT,
			TYPE_FLOAT
		]:
			prestige_bonus += float(
				raw_value
			)

	var draw: float = (
		float(base)
		+ float(fame_value) * 2.5
		+ prestige_bonus * 2.0
	)

	return maxi(
		4,
		int(
			round(
				draw * privacy_factor
			)
		)
	)
func _commit_property_party(
	actor: Person,
	property_id: int,
	party_size: String,
	privacy: String
) -> Dictionary:
	if (
		actor == null
		or not properties.has(
			actor.id
		)
	):
		return {
			"success": false,
			"committed": false,
			"text": (
				"That property could not be found."
			)
		}

	var items: Array = properties.get(
		actor.id,
		[]
	)

	for index in range(
		items.size()
	):
		var raw_prop: Variant = items [
			index
		]

		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue

		var prop: Dictionary = (
			raw_prop as Dictionary
		)

		if int(
			prop.get(
				"id",
				-1
			)
		) != property_id:
			continue

		var place_label: String = (
			_property_party_place_label(
				prop
			)
		)
		var clean_size: String = str(
			party_size
		).strip_edges().to_lower()
		var clean_privacy: String = str(
			privacy
		).strip_edges().to_lower()
		var attendance: int = (
			_property_party_attendance(
				actor,
				prop,
				clean_size,
				clean_privacy
			)
		)
		var party_label: String = (
			clean_size.capitalize()
		)
		var privacy_label: String = (
			clean_privacy.replace(
				"_",
				" "
			).capitalize()
		)
		var history: Array = _safe_array(
			prop.get(
				"history",
				[]
			)
		)

		history.append(
			"%s %s hosted a %s, %s party at %s in %s."
			% [
				actor.first_name,
				actor.last_name,
				privacy_label,
				party_label,
				place_label,
				_format_year_for_history()
			]
		)

		prop [
			"history"
		] = history
		items [
			index
		] = prop
		properties [
			actor.id
		] = items

		if (
			gs != null
			and gs.belongings_engine != null
		):
			gs.belongings_engine.add_item(
				actor,
				prop,
				"Real Estate",
				true
			)

		return {
			"success": true,
			"committed": true,
			"popup_title": (
				"%s Party"
				% str(
					prop.get(
						"display_name",
						prop.get(
							"type",
							"Property"
						)
					)
				)
			),
			"popup_text": (
				"%d people attended your %s, %s party at %s."
				% [
					attendance,
					privacy_label,
					party_label,
					place_label
				]
			),
			"popup_footer": (
				"Attendance resolved from party size, privacy, fame, and property prestige."
			),
			"text": (
				"I threw a %s, %s party at %s. %d people attended."
				% [
					privacy_label,
					party_label,
					place_label,
					attendance
				]
			),
			"party_attendance": attendance,
			"party_size": clean_size,
			"privacy": clean_privacy,
			"property_id": property_id,
			"property_label": place_label,
			"log_to_diary": true
		}

	return {
		"success": false,
		"committed": false,
		"text": (
			"That property could not be found."
		)
	}

func commit_property_contract_action(
	actor: Person,
	intent_contract: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"committed": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_actor",
			"text": "No property actor was provided."
		}

	var asset_id: int = int(
		intent_contract.get(
			"asset_id",
			intent_contract.get(
				"property_id",
				-1
			)
		)
	)
	var action_id: String = str(
		intent_contract.get(
			"action_id",
			intent_contract.get(
				"property_action",
				""
			)
		)
	).strip_edges().to_lower()

	if asset_id <= 0:
		return {
			"success": false,
			"committed": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_asset_id",
			"text": "No property asset was selected."
		}

	if action_id == "":
		return {
			"success": false,
			"committed": false,
			"schema": ACTION_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "missing_action_id",
			"text": "No property action was selected."
		}

	var mutation_report: Dictionary = {}

	if action_id == "throw_party":
		var party_size: String = str(
			intent_contract.get(
				"party_size",
				""
			)
		).strip_edges().to_lower()
		var privacy: String = str(
			intent_contract.get(
				"privacy",
				""
			)
		).strip_edges().to_lower()

		if (
			party_size == ""
			or privacy == ""
		):
			var property_contract: Dictionary = {}

			var observed_raw: Variant = (
				intent_contract.get(
					"property_contract",
					{}
				)
			)

			if typeof(observed_raw) == TYPE_DICTIONARY:
				property_contract = (
					observed_raw as Dictionary
				).duplicate(false)

			if property_contract.is_empty():
				for raw_property in properties.get(
					actor.id,
					[]
				):
					if typeof(raw_property) != TYPE_DICTIONARY:
						continue

					var candidate: Dictionary = (
						raw_property as Dictionary
					)

					if int(
						candidate.get(
							"id",
							-1
						)
					) == asset_id:
						property_contract = (
							candidate.duplicate(false)
						)
						break

			mutation_report = (
				_property_party_choice_result(
					actor,
					asset_id,
					property_contract
				)
			)
		else:
			mutation_report = (
				_commit_property_party(
					actor,
					asset_id,
					party_size,
					privacy
				)
			)
	else:
		mutation_report = run_asset_action(
			actor,
			asset_id,
			action_id
		)

	var committed: bool = bool(
		mutation_report.get(
			"committed",
			mutation_report.get(
				"success",
				false
			)
		)
	)

	mutation_report [
		"schema"
	] = ACTION_CONTRACT_SCHEMA
	mutation_report [
		"version"
	] = CONTRACT_VERSION
	mutation_report [
		"actor_id"
	] = int(
		actor.id
	)
	mutation_report [
		"asset_id"
	] = asset_id
	mutation_report [
		"action_id"
	] = action_id
	mutation_report [
		"source_engine"
	] = ENGINE_SCHEMA
	mutation_report [
		"committed"
	] = committed
	mutation_report [
		"reality_mutation_committed"
	] = committed
	mutation_report [
		"ui_is_renderer_only"
	] = true
	mutation_report [
		"intent_contract"
	] = intent_contract.duplicate(false)

	last_contract_report = (
		mutation_report.duplicate(false)
	)

	if committed:
		_publish_contract_state(
			"property_action_committed"
		)

	return mutation_report


func _property_asset_contract(
	owner: Person,
	property_asset: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var operational_profile: Dictionary = _safe_dictionary(
		property_asset.get(
			"operational_profile",
			{}
		)
	)

	return {
		"success": int(
			property_asset.get("id", -1)
		) > 0,
		"schema": ASSET_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"asset_id": int(
			property_asset.get("id", -1)
		),
		"owner_id": (
			int(owner.id)
			if owner != null
			else -1
		),
		"template_id": str(
			property_asset.get(
				"template_id",
				""
			)
		),
		"name": str(
			property_asset.get(
				"nickname",
				property_asset.get(
					"display_name",
					property_asset.get(
						"type",
						"Property"
					)
				)
			)
		),
		"category": str(
			property_asset.get(
				"category",
				property_asset.get(
					"archetype",
					"residential"
				)
			)
		),
		"subtype": str(
			property_asset.get(
				"subtype",
				""
			)
		),
		"address": str(
			property_asset.get(
				"address",
				"Unknown Address"
			)
		),
		"value": int(
			property_asset.get(
				"value",
				property_asset.get(
					"worth",
					0
				)
			)
		),
		"ownership_status": str(
			property_asset.get(
				"ownership_status",
				property_asset.get(
					"legal_status",
					"owned"
				)
			)
		),
		"availability": str(
			property_asset.get(
				"availability",
				"owned_not_for_sale"
			)
		),
		"condition": float(
			property_asset.get(
				"condition",
				100.0
			)
		),
		"condition_label": str(
			property_asset.get(
				"condition_label",
				"Excellent"
			)
		),
		"amenities": _safe_array(
			property_asset.get(
				"amenities",
				[]
			)
		),
		"amenity_ids": _safe_array(
			property_asset.get(
				"amenity_ids",
				[]
			)
		),
		"amenity_contracts": _safe_array(
			property_asset.get(
				"amenity_contracts",
				[]
			)
		),
		"amenity_summary": str(
			property_asset.get(
				"amenity_summary",
				"No resolved amenities"
			)
		),
		"vehicle_storage_capacity": int(
			property_asset.get(
				"vehicle_storage_capacity",
				operational_profile.get(
					"vehicle_storage_capacity",
					0
				)
			)
		),
		"storage_contents": _safe_array(
			property_asset.get(
				"storage_contents",
				[]
			)
		),
		"operational_profile": operational_profile,
		"feature_tags": _safe_array(
			property_asset.get(
				"feature_tags",
				[]
			)
		),
		"filter_tags": _safe_array(
			property_asset.get(
				"filter_tags",
				property_asset.get(
					"feature_tags",
					[]
				)
			)
		),
		"action_ids": _safe_array(
			property_asset.get(
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
		"yearly_asset_ecology_tick",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 150,
			"subscription_id": (
				"property_yearly_asset_ecology"
			)
		}
	)

	gs.event_bus.subscribe(
		ActionEventTypes.NPC_MARRIED,
		self,
		"on_spousal_property_ownership_changed",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 151,
			"subscription_id": (
				"property_marriage_settlement"
			)
		}
	)

	gs.event_bus.subscribe(
		ActionEventTypes.NPC_DIVORCED,
		self,
		"on_spousal_property_divorce_settlement_requested",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 152,
			"subscription_id": (
				"property_divorce_settlement"
			)
		}
	)

	_bound_event_bus_instance_id = event_bus_instance_id
func on_spousal_property_ownership_changed(
	payload:= {}
) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var event_payload: Dictionary = (
		payload as Dictionary
	)

	var actor_id: int = int(
		event_payload.get(
			"actor_id",
			event_payload.get(
				"npc_id",
				-1
			)
		)
	)
	var spouse_id: int = int(
		event_payload.get(
			"spouse_id",
			event_payload.get(
				"target_id",
				-1
			)
		)
	)

	_queue_spousal_property_settlement_by_ids(
		actor_id,
		spouse_id,
		"marriage",
		event_payload
	)


func on_spousal_property_divorce_settlement_requested(
	payload:= {}
) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var event_payload: Dictionary = (
		payload as Dictionary
	)

	_queue_spousal_property_settlement_by_ids(
		int(
			event_payload.get(
				"actor_id",
				event_payload.get(
					"npc_id",
					-1
				)
			)
		),
		int(
			event_payload.get(
				"spouse_id",
				event_payload.get(
					"target_id",
					-1
				)
			)
		),
		"divorce",
		event_payload
	)

func reconcile_spousal_property_ownership_for_actor(
	owner: Person,
	reason: String = "property_portfolio_projection"
) -> Dictionary:
	if (
		gs == null
		or owner == null
	):
		return {
			"success": false,
			"reason": "missing_game_state_or_owner",
			"changed_property_count": 0
		}

	var spouse: Person = (
		gs.get_valid_partner(
			owner,
			true,
			true
		)
	)

	if spouse == null:
		return {
			"success": true,
			"reason": "no_valid_spouse",
			"owner_id": int(
				owner.id
			),
			"changed_property_count": 0
		}

	if (
		str(
			owner.marital_status
		).strip_edges().to_lower()
		!= "married"
		or str(
			spouse.marital_status
		).strip_edges().to_lower()
		!= "married"
	):
		return {
			"success": true,
			"reason": "partnership_is_not_legal_marriage",
			"owner_id": int(
				owner.id
			),
			"spouse_id": int(
				spouse.id
			),
			"changed_property_count": 0
		}

	return _queue_spousal_property_settlement_by_ids(
		int(
			owner.id
		),
		int(
			spouse.id
		),
		"marriage",
		{
			"reason": reason,
			"prenup_signed": false,
		}
	)
func _queue_spousal_property_settlement_by_ids(
	actor_id: int,
	spouse_id: int,
	mode: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor_id <= 0
		or spouse_id <= 0
		or actor_id == spouse_id
	):
		return {
			"success": false,
			"reason": "invalid_spousal_property_pair"
		}

	spousal_property_settlement_queue.append({
		"actor_id": actor_id,
		"spouse_id": spouse_id,
		"mode": mode,
		"context": context.duplicate(false),
		"phase": "index_actor",
		"cursor": 0,
		"membership_actor": {},
		"membership_spouse": {},
		"settled": {},
		"changed_property_count": 0,
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	_arm_spousal_property_settlement_service()

	return {
		"success": true,
		"queued": true,
		"owner_id": actor_id,
		"spouse_id": spouse_id,
		"mode": mode,
		"changed_property_count": 0,
		"blocks_ui": false
	}


func _arm_spousal_property_settlement_service() -> void:
	if spousal_property_settlement_service_armed:
		return

	if spousal_property_settlement_queue.is_empty():
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (main_loop is SceneTree):
		return

	spousal_property_settlement_service_armed = true

	var timer:= (
		main_loop as SceneTree
	).create_timer(
		0.02
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_spousal_property_settlement_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _property_resident_person_by_id(
	person_id: int
) -> Person:
	if (
		gs == null
		or person_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == person_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			person_id,
			false
		)

	return null


func _service_spousal_property_settlement_quantum() -> void:
	spousal_property_settlement_service_armed = false

	if spousal_property_settlement_queue.is_empty():
		return

	var job_raw: Variant = (
		spousal_property_settlement_queue [
			0
		]
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		spousal_property_settlement_queue.pop_front()
		_arm_spousal_property_settlement_service()
		return

	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var spouse_id: int = int(
		job.get(
			"spouse_id",
			-1
		)
	)
	var mode: String = str(
		job.get(
			"mode",
			"marriage"
		)
	)
	var context: Dictionary = _safe_dictionary(
		job.get(
			"context",
			{}
		)
	)
	var phase: String = str(
		job.get(
			"phase",
			"index_actor"
		)
	)
	var cursor: int = int(
		job.get(
			"cursor",
			0
		)
	)

	var actor_properties: Array = _safe_array(
		properties.get(
			actor_id,
			[]
		)
	)
	var spouse_properties: Array = _safe_array(
		properties.get(
			spouse_id,
			[]
		)
	)

	if phase == "index_actor":
		if cursor < actor_properties.size():
			var property_asset: Dictionary = _safe_dictionary(
				actor_properties [
					cursor
				]
			)

			job ["cursor"] = cursor + 1

			if not property_asset.is_empty():
				var key: String = _property_identity_key(
					property_asset
				)

				var membership: Dictionary = _safe_dictionary(
					job.get(
						"membership_actor",
						{}
					)
				)

				membership [key] = true

				job ["membership_actor"] = membership

			spousal_property_settlement_queue [
				0
			] = job

			_arm_spousal_property_settlement_service()
			return

		job ["phase"] = "index_spouse"
		job ["cursor"] = 0
		phase = "index_spouse"
		cursor = 0

	if phase == "index_spouse":
		if cursor < spouse_properties.size():
			var property_asset: Dictionary = _safe_dictionary(
				spouse_properties [
					cursor
				]
			)

			job ["cursor"] = cursor + 1

			if not property_asset.is_empty():
				var key: String = _property_identity_key(
					property_asset
				)

				var membership: Dictionary = _safe_dictionary(
					job.get(
						"membership_spouse",
						{}
					)
				)

				membership [key] = true

				job ["membership_spouse"] = membership

			spousal_property_settlement_queue [
				0
			] = job

			_arm_spousal_property_settlement_service()
			return

		job ["phase"] = "settle_actor"
		job ["cursor"] = 0
		phase = "settle_actor"
		cursor = 0

	var source_properties: Array = (
		actor_properties
		if phase == "settle_actor"
		else spouse_properties
	)

	if phase in [
		"settle_actor",
		"settle_spouse"
	]:
		if cursor < source_properties.size():
			var property_asset: Dictionary = _safe_dictionary(
				source_properties [
					cursor
				]
			)

			job ["cursor"] = cursor + 1

			if not property_asset.is_empty():
				var property_key: String = (
					_property_identity_key(
						property_asset
					)
				)
				var settled: Dictionary = _safe_dictionary(
					job.get(
						"settled",
						{}
					)
				)

				if not settled.has(
					property_key
				):
					settled [
						property_key
					] = true
					job ["settled"] = settled

					var prenup_signed: bool = bool(
						context.get(
							"prenup_signed",
							false
						)
					)
					var actor_premarital: Dictionary = (
						_safe_dictionary(
							context.get(
								"premarital_property_keys_actor",
								{}
							)
						)
					)
					var spouse_premarital: Dictionary = (
						_safe_dictionary(
							context.get(
								"premarital_property_keys_target",
								{}
							)
						)
					)

					var protected_actor_property: bool = (
						prenup_signed
						and actor_premarital.has(
							property_key
						)
					)
					var protected_spouse_property: bool = (
						prenup_signed
						and spouse_premarital.has(
							property_key
						)
					)

					if protected_actor_property:
						property_asset ["owners"] = [
							actor_id
						]
						property_asset [
							"marital_equity_shares"
						] = {
							str(actor_id): 1.0
						}

					elif protected_spouse_property:
						property_asset ["owners"] = [
							spouse_id
						]
						property_asset [
							"marital_equity_shares"
						] = {
							str(spouse_id): 1.0
						}

					else:
						property_asset ["owners"] = [
							actor_id,
							spouse_id
						]
						property_asset [
							"marital_equity_shares"
						] = {
							str(actor_id): 0.5,
							str(spouse_id): 0.5
						}

					property_asset [
						"marital_property_status"
					] = (
						"divorce_equal_equity"
						if mode == "divorce"
						else "married_equal_ownership"
					)

					property_asset [
						"prenup_protected"
					] = (
						protected_actor_property
						or protected_spouse_property
					)

					job [
						"changed_property_count"
					] = int(
						job.get(
							"changed_property_count",
							0
						)
					) + 1

			spousal_property_settlement_queue [
				0
			] = job

			_arm_spousal_property_settlement_service()
			return

		if phase == "settle_actor":
			job ["phase"] = "settle_spouse"
			job ["cursor"] = 0

			spousal_property_settlement_queue [
				0
			] = job

			_arm_spousal_property_settlement_service()
			return


	if (
		gs.assets_contract_engine != null
		and gs.assets_contract_engine.has_method(
			"invalidate_actor"
		)
	):
		gs.assets_contract_engine.invalidate_actor(
			actor_id,
			"%s_spousal_property_settlement"
			% mode
		)
		gs.assets_contract_engine.invalidate_actor(
			spouse_id,
			"%s_spousal_property_settlement"
			% mode
		)

	_publish_contract_state(
		"spousal_property_settlement_complete"
	)

	last_contract_report = {
		"success": true,
		"schema": (
			"eralife.property.spousal_settlement"
		),
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"spouse_id": spouse_id,
		"mode": mode,
		"changed_property_count": int(
			job.get(
				"changed_property_count",
				0
			)
		),
		"prenup_signed": bool(
			context.get(
				"prenup_signed",
				false
			)
		),
		"blocks_ui": false,
		"completed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	spousal_property_settlement_queue.pop_front()

	_arm_spousal_property_settlement_service()

func _controlled_properties_for_actor(
	owner: Person,
	reconcile_marriage_truth: bool = true
) -> Array:
	var out: Array = []

	if owner == null:
		return out

	if reconcile_marriage_truth:
		reconcile_spousal_property_ownership_for_actor(
			owner,
			"controlled_property_projection"
		)

	var seen: Dictionary = {}

	for raw_property in _safe_array(
		properties.get(
			owner.id,
			[]
		)
	):
		var indexed_property: Dictionary = (
			_safe_dictionary(
				raw_property
			)
		)

		if indexed_property.is_empty():
			continue

		var indexed_key: String = (
			_property_identity_key(
				indexed_property
			)
		)

		if seen.has(indexed_key):
			continue

		seen [indexed_key] = true
		out.append(
			indexed_property
		)



	for raw_bucket_id in properties.keys().duplicate():
		for raw_property in _safe_array(
			properties.get(
				raw_bucket_id,
				[]
			)
		):
			var discovered_property: Dictionary = (
				_safe_dictionary(
					raw_property
				)
			)

			if discovered_property.is_empty():
				continue

			var legal_owner_ids: Array = _safe_array(
				discovered_property.get(
					"owners",
					[]
				)
			)
			var control_roles: Dictionary = (
				_safe_dictionary(
					discovered_property.get(
						"control_roles",
						{}
					)
				)
			)
			var control_owner_ids: Array = _safe_array(
				control_roles.get(
					"owner_ids",
					[]
				)
			)

			if (
				int(owner.id) not in legal_owner_ids
				and int(owner.id) not in control_owner_ids
			):
				continue

			var discovered_key: String = (
				_property_identity_key(
					discovered_property
				)
			)

			if seen.has(discovered_key):
				continue

			seen [discovered_key] = true
			out.append(
				discovered_property
			)

			if not properties.has(owner.id):
				properties [owner.id] = []

			if discovered_property not in properties [owner.id]:
				properties [owner.id].append(
					discovered_property
				)

	return out


func _property_identity_key(
	property_asset: Dictionary
) -> String:
	var asset_id: int = int(
		property_asset.get(
			"id",
			-1
		)
	)

	if asset_id > 0:
		return "property:%d" % asset_id

	return "property_hash:%d" % property_asset.hash()


func _property_actor_from_event_payload(
	payload
) -> Person:
	if payload is Person:
		return payload

	if typeof(payload) != TYPE_DICTIONARY:
		return null

	var row: Dictionary = payload

	for person_key in [
		"npc",
		"person",
		"actor",
		"owner"
	]:
		var person_raw: Variant = row.get(
			person_key,
			null
		)

		if person_raw is Person:
			return person_raw

	var actor_id: int = int(
		row.get(
			"npc_id",
			row.get(
				"person_id",
				row.get(
					"actor_id",
					row.get(
						"owner_id",
						-1
					)
				)
			)
		)
	)

	if actor_id <= 0:
		return null

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		return gs.get_or_reactivate_npc_by_id(
			actor_id
		)

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(
			actor_id
		)

	return null

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
	state ["engine_file"] = "PropertyEngine.gd"
	state ["internal_role"] = "PropertyContractEngine"
	state ["runtime_truth_authority"] = true
	state ["ui_is_renderer_only"] = true
	state ["property_owner_bucket_count"] = properties.size()
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
	state ["property_owner_bucket_count"] = properties.size()
	state ["last_contract_report"] = last_contract_report.duplicate(true)
	state ["contract"] = contract()

	gs.scenario_state [STATE_KEY] = state




func buy_property(
	buyer: Person,
	size_or_template,
	price_override:= -1,
	purchase_context:= {}
) -> Dictionary:
	if buyer == null:
		return {
			"success": false,
			"text": "No buyer provided."
		}

	var template:= _resolve_property_template(
		size_or_template,
		purchase_context
	)

	if template.is_empty():
		return {
			"success": false,
			"text": (
				"No valid property template could be resolved."
			)
		}

	var final_price: int = int(
		price_override
	)

	if final_price < 0:
		final_price = _calculate_property_value(
			template,
			buyer,
			purchase_context
		)

	if buyer.bank_balance < final_price:
		return {
			"success": false,
			"text": " I can't afford this property."
		}

	buyer.bank_balance -= final_price

	var resolved_purchase_context: Dictionary = (
		purchase_context.duplicate(false)
	)

	resolved_purchase_context [
		"resolved_price"
	] = final_price

	var prop:= _build_runtime_property_from_template(
		template,
		buyer,
		resolved_purchase_context
	)

	prop [
		"price"
	] = final_price
	prop [
		"value"
	] = (
		final_price
		+ int(
			prop.get(
				"synthesized_property_value_delta",
				0
			)
		)
	)
	prop [
		"worth"
	] = int(
		prop [
			"value"
		]
	)
	prop [
		"source_engine"
	] = "property_engine"

	_register_property_for_owner(
		buyer,
		prop,
		true
	)

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			ActionEventTypes.PROPERTY_PURCHASED,
			{
				"npc_id": int(
					buyer.id
				),
				"text": (
					"%s %s purchased %s."
					% [
						buyer.first_name,
						buyer.last_name,
						str(
							prop.get(
								"display_name",
								prop.get(
									"type",
									"Property"
								)
							)
						)
					]
				),
				"data": {
					"asset_id": int(
						prop.get(
							"id",
							-1
						)
					),
					"template_id": str(
						prop.get(
							"template_id",
							""
						)
					),
					"feature_tags": prop.get(
						"feature_tags",
						[]
					),
					"prestige_signals": prop.get(
						"prestige_signals",
						{}
					)
				},
				"fanout_hints": {
					"force_defer_bus": true,
					"ui_blocking_forbidden": true
				}
			}
		)

	return {
		"success": true,
		"text": (
			" Purchased %s at %s."
			% [
				str(
					prop.get(
						"display_name",
						prop.get(
							"type",
							"Property"
						)
					)
				),
				str(
					prop.get(
						"address",
						"Unknown Address"
					)
				)
			]
		),
		"property_id": int(
			prop.get(
				"id",
				-1
			)
		),
	}

func _resolve_property_template(
	size_or_template,
	purchase_context:= {}
) -> Dictionary:
	if typeof(size_or_template) == TYPE_DICTIONARY:
		return (
			size_or_template as Dictionary
		).duplicate(false)

	var raw: String = str(
		size_or_template
	)
	var resolved_raw: String = raw.trim_prefix(
		"template:"
	)

	var resident_template_raw: Variant = (
		purchase_context.get(
			"resident_property_template_contract",
			{}
		)
	)

	if typeof(resident_template_raw) == TYPE_DICTIONARY:
		var resident_template: Dictionary = (
			resident_template_raw as Dictionary
		)
		var resident_template_id: String = str(
			resident_template.get(
				"template_id",
				""
			)
		).strip_edges()

		if (
			resident_template_id != ""
			and resident_template_id == resolved_raw
		):
			return resident_template.duplicate(
				false
			)

	if bool(
		purchase_context.get(
			"listing_regeneration_forbidden",
			false
		)
	):
		return {}

	if gs != null:
		if gs.era_life_asset_catalog_expansion == null:
			gs.era_life_asset_catalog_expansion = (
				EraLifeAssetCatalogExpansion.new(
					gs
				)
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
				.property_template_by_id(
					resolved_raw
				)
			)

			if not expansion_template.is_empty():
				return expansion_template

	if (
		gs != null
		and gs.era_data_loader != null
	):
		var by_id: Dictionary = (
			gs.era_data_loader.get_property_template(
				resolved_raw
			)
		)

		if not by_id.is_empty():
			return by_id

		var selector: Dictionary = (
			purchase_context.duplicate(false)
		)

		if str(
			selector.get(
				"query_text",
				""
			)
		) == "":
			selector [
				"query_text"
			] = resolved_raw

		if gs.era != null:
			var from_catalog: Dictionary = (
				gs.era_data_loader
				.get_best_property_template_for_context(
					gs.era.name,
					selector
				)
			)

			if not from_catalog.is_empty():
				return from_catalog

	if (
		resolved_raw.begins_with(
			"legacy_property_"
		)
		and gs != null
		and gs.era != null
	):
		var era_prefix: String = (
			"legacy_property_%s_"
			% str(
				gs.era.name
			).to_lower().replace(
				" ",
				"_"
			)
		)

		if resolved_raw.begins_with(
			era_prefix
		):
			var legacy_size_key: String = (
				resolved_raw.trim_prefix(
					era_prefix
				)
			)

			if legacy_size_key != "":
				return _legacy_property_from_size(
					legacy_size_key.capitalize()
				)

	return _legacy_property_from_size(
		resolved_raw
	)
func _property_amenity_synthesis_engine() -> PropertyAmenitySynthesisContractEngine:
	if gs == null:
		return null

	if gs.property_amenity_synthesis_contract_engine == null:
		gs.property_amenity_synthesis_contract_engine = PropertyAmenitySynthesisContractEngine.new(
			gs
		)
	elif gs.property_amenity_synthesis_contract_engine.has_method(
		"bind_game_state"
	):
		gs.property_amenity_synthesis_contract_engine.bind_game_state(
			gs
		)

	return gs.property_amenity_synthesis_contract_engine
func _legacy_property_from_size(size: String) -> Dictionary:
	if str(size) == "Royal":
		var royal_property_type:= _property_type_for_size("Royal")
		var royal_base_value:= 350000
		match gs.era.name:
			"Ancient Era":
				royal_base_value = 240000
			"Medieval Era":
				royal_base_value = 420000
			"Industrial Era":
				royal_base_value = 950000
			"Modern Era":
				royal_base_value = 3000000
			"Future Era":
				royal_base_value = 8500000
		var royal_feature_tags: Array = [
			"land",
			"residential",
			"luxury",
			"family_seat",
			"noble",
			"ceremonial",
			"dynasty_seat"
		]
		if gs != null and gs.era != null and gs.era.name in ["Ancient Era", "Medieval Era"]:
			royal_feature_tags.append("fortified")
		return {
			"template_id": "legacy_property_%s_royal" % [
				str(gs.era.name).to_lower().replace(" ", "_")
			],
			"asset_kind": "property",
			"archetype": "residence",
			"subtype": "royal",
			"display_name": royal_property_type,
			"legacy_type": royal_property_type,
			"size": "Royal",
			"era_tags": [gs.era.name],
			"social_tier": "royal",
			"feature_tags": royal_feature_tags,
			"rarity": 1.65,
			"upkeep_profile": {
				"maintenance_intensity": 1.55
			},
			"requirement_tags": [],
			"operational_profile": {
				"storage_pressure": 5,
				"comfort": 5,
				"bedrooms": 14,
				"bathrooms": 10
			},
			"passive_modifiers": {},
			"event_hooks": [],
			"action_ids": ["inspect", "rename", "sell", "gift", "maintain", "repair", "rest"],
			"prestige_signals": {
				"class_respect": 5.2
			},
			"pricing_rules": {},
			"base_value": royal_base_value,
			"default_condition": 100.0
		}

	var property_type:= _property_type_for_size(size)
	var social_tier:= "common"
	var feature_tags: Array = ["land", "residential"]
	var base_value: int = 10000
	var class_respect: float = 1.0
	var comfort: int = 1
	var storage_pressure: int = 1
	var maintenance_intensity: float = 1.0
	var rarity: float = 1.0


	match gs.era.name:
		"Ancient Era":
			match property_type:
				"Insula":
					social_tier = "working_class"
					feature_tags.append("dense")
					base_value = 4200
					class_respect = 0.55
					comfort = 1
					storage_pressure = 1
				"Domus":
					social_tier = "respectable"
					feature_tags.append("family_seat")
					base_value = 18000
					class_respect = 1.25
					comfort = 2
					storage_pressure = 2
				"Villa":
					social_tier = "wealthy"
					feature_tags.append_array(["luxury", "family_seat"])
					base_value = 54000
					class_respect = 2.2
					comfort = 4
					storage_pressure = 3
					maintenance_intensity = 1.15
					rarity = 1.15
				"Temple Residence":
					social_tier = "noble"
					feature_tags.append_array(["noble", "ceremonial"])
					base_value = 86000
					class_respect = 3.0
					comfort = 4
					storage_pressure = 3
					maintenance_intensity = 1.2
					rarity = 1.22
		"Medieval Era":
			match property_type:
				"Cottage":
					social_tier = "working_class"
					feature_tags.append("rural")
					base_value = 6500
					class_respect = 0.6
				"Longhouse":
					social_tier = "respectable"
					feature_tags.append("family_seat")
					base_value = 15000
					class_respect = 1.1
					comfort = 2
					storage_pressure = 2
				"Manor":
					social_tier = "wealthy"
					feature_tags.append_array(["luxury", "family_seat"])
					base_value = 62000
					class_respect = 2.3
					comfort = 4
					storage_pressure = 3
					maintenance_intensity = 1.15
					rarity = 1.18
				"Castle Keep":
					social_tier = "noble"
					feature_tags.append_array(["fortified", "noble"])
					base_value = 165000
					class_respect = 3.4
					comfort = 3
					storage_pressure = 4
					maintenance_intensity = 1.35
					rarity = 1.28
		"Industrial Era":
			match property_type:
				"Tenement":
					social_tier = "working_class"
					feature_tags.append("dense")
					base_value = 14000
					class_respect = 0.5
				"Townhouse":
					social_tier = "respectable"
					base_value = 32000
					class_respect = 1.15
					comfort = 2
					storage_pressure = 2
				"Estate":
					social_tier = "wealthy"
					feature_tags.append_array(["luxury", "family_seat"])
					base_value = 98000
					class_respect = 2.4
					comfort = 4
					storage_pressure = 3
					maintenance_intensity = 1.15
					rarity = 1.2
				"Factory House":
					social_tier = "wealthy"
					feature_tags.append("industrial")
					base_value = 58000
					class_respect = 1.8
					comfort = 2
					storage_pressure = 4
					maintenance_intensity = 1.25
		"Modern Era":
			match property_type:
				"Apartment":
					social_tier = "respectable"
					feature_tags.append("dense")
					base_value = 45000
					class_respect = 1.0
					comfort = 2
				"Suburban Home":
					social_tier = "respectable"
					feature_tags.append("family_seat")
					base_value = 92000
					class_respect = 1.4
					comfort = 3
					storage_pressure = 2
				"Condo":
					social_tier = "wealthy"
					feature_tags.append("luxury")
					base_value = 180000
					class_respect = 2.0
					comfort = 3
					storage_pressure = 2
					maintenance_intensity = 1.1
				"Mansion":
					social_tier = "celebrity"
					feature_tags.append_array(["luxury", "family_seat"])
					base_value = 780000
					class_respect = 3.2
					comfort = 5
					storage_pressure = 4
					maintenance_intensity = 1.2
					rarity = 1.3
				"Penthouse":
					social_tier = "ultra_luxury"
					feature_tags.append_array(["luxury", "celebrity"])
					base_value = 1450000
					class_respect = 3.8
					comfort = 5
					storage_pressure = 3
					maintenance_intensity = 1.25
					rarity = 1.38
		"Future Era":
			match property_type:
				"Sky Pod":
					social_tier = "respectable"
					base_value = 240000
					class_respect = 1.5
					comfort = 3
					storage_pressure = 2
				"Smart Habitat":
					social_tier = "wealthy"
					feature_tags.append("luxury")
					base_value = 520000
					class_respect = 2.4
					comfort = 4
					storage_pressure = 3
					maintenance_intensity = 1.12
				"Floating Estate":
					social_tier = "ultra_luxury"
					feature_tags.append_array(["luxury", "noble"])
					base_value = 2400000
					class_respect = 4.0
					comfort = 5
					storage_pressure = 4
					maintenance_intensity = 1.3
					rarity = 1.45
				"Colony Unit":
					social_tier = "wealthy"
					feature_tags.append_array(["frontier", "family_seat"])
					base_value = 980000
					class_respect = 2.8
					comfort = 4
					storage_pressure = 4
					maintenance_intensity = 1.22
					rarity = 1.24

	return {
		"template_id": "legacy_property_%s_%s" % [
			str(gs.era.name).to_lower().replace(" ", "_"),
			str(size).to_lower().replace(" ", "_")
		],
		"asset_kind": "property",
		"archetype": "residence",
		"subtype": str(size).to_lower(),
		"display_name": property_type,
		"legacy_type": property_type,
		"size": size,
		"era_tags": [gs.era.name],
		"social_tier": social_tier,
		"feature_tags": feature_tags,
		"rarity": rarity,
		"upkeep_profile": {
			"maintenance_intensity": maintenance_intensity
		},
		"requirement_tags": [],
		"operational_profile": {
			"storage_pressure": storage_pressure,
			"comfort": comfort
		},
		"passive_modifiers": {},
		"event_hooks": [],
		"action_ids": ["inspect", "rename", "sell", "gift", "maintain", "repair", "rest"],
		"prestige_signals": {
			"class_respect": class_respect
		},
		"pricing_rules": {},
		"base_value": base_value,
		"default_condition": 100.0
	}
func _build_runtime_property_from_template(
	template: Dictionary,
	buyer: Person,
	context:= {}
) -> Dictionary:
	var display_name: String = str(
		template.get(
			"display_name",
			template.get(
				"legacy_type",
				"Property"
			)
		)
	)
	var requirement_tags: Array = _safe_array(
		template.get("requirement_tags", [])
	)
	var infrastructure_tags: Array = []

	for raw_tag in context.get(
		"infrastructure_tags",
		[]
	):
		infrastructure_tags.append(
			str(raw_tag)
		)

	var satisfied_requirements: Array = []
	var missing_requirements: Array = []

	for raw_requirement in requirement_tags:
		var requirement: String = str(
			raw_requirement
		)

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

	var amenity_contract: Dictionary = {}

	var resident_amenity_raw: Variant = context.get(
		"resident_amenity_synthesis_contract",
		{}
	)

	if typeof(resident_amenity_raw) == TYPE_DICTIONARY:
		amenity_contract = (
			resident_amenity_raw as Dictionary
		).duplicate(false)

	if amenity_contract.is_empty():
		if bool(
			context.get(
				"amenity_resynthesis_forbidden",
				false
			)
		):
			return {}

		var synthesis_engine:= (
			_property_amenity_synthesis_engine()
		)

		if synthesis_engine != null:
			amenity_contract = (
				synthesis_engine.resolve_property_contract(
					buyer,
					template,
					context
				)
			)

	var operational_profile: Dictionary = _safe_dictionary(
		template.get(
			"operational_profile",
			{}
		)
	)
	var synthesized_vehicle_capacity: int = int(
		amenity_contract.get(
			"vehicle_storage_capacity",
			template.get(
				"vehicle_storage_capacity",
				operational_profile.get(
					"vehicle_storage_capacity",
					0
				)
			)
		)
	)
	operational_profile ["vehicle_storage_capacity"] = synthesized_vehicle_capacity
	operational_profile ["storage_pressure"] = maxi(
		int(
			operational_profile.get(
				"storage_pressure",
				0
			)
		),
		synthesized_vehicle_capacity
	)

	var passive_modifiers: Dictionary = _safe_dictionary(
		template.get("passive_modifiers", {})
	)
	passive_modifiers ["comfort"] = (
		float(
			passive_modifiers.get(
				"comfort",
				0.0
			)
		)
		+ float(
			amenity_contract.get(
				"comfort_delta",
				0.0
			)
		)
	)

	return {
		"id": _gen_id(),
		"template_id": str(
			template.get("template_id", "")
		),
		"asset_kind": "property",
		"category": str(
			template.get(
				"category",
				template.get(
					"archetype",
					"residential"
				)
			)
		),
		"archetype": str(
			template.get(
				"archetype",
				"residence"
			)
		),
		"subtype": str(
			template.get("subtype", "")
		),
		"size": str(
			template.get("size", "")
		),
		"type": str(
			template.get(
				"legacy_type",
				display_name
			)
		),
		"display_name": display_name,
		"era_name": str(gs.era.name),
		"era_tags": _safe_array(
			template.get("era_tags", [])
		),
		"filter_tags": _safe_array(
			template.get(
				"filter_tags",
				template.get("feature_tags", [])
			)
		),
		"ownership_modes": _safe_array(
			template.get(
				"ownership_modes",
				["buy", "mortgage"]
			)
		),
		"ownership_status": "owned",
		"availability": "owned_not_for_sale",
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
			template.get("feature_tags", [])
		),
		"portfolio_tags": _safe_array(
			template.get("portfolio_tags", [])
		),
		"rarity": float(
			template.get("rarity", 1.0)
		),
		"upkeep_profile": _safe_dictionary(
			template.get("upkeep_profile", {})
		),
		"requirement_tags": requirement_tags,
		"operational_profile": operational_profile,
		"passive_modifiers": passive_modifiers,
		"event_hooks": _safe_array(
			template.get("event_hooks", [])
		),
		"action_ids": _safe_array(
			template.get("action_ids", [])
		),
		"prestige_signals": _safe_dictionary(
			template.get("prestige_signals", {})
		),
		"pricing_rules": _safe_dictionary(
			template.get("pricing_rules", {})
		),
		"condition": float(
			template.get(
				"default_condition",
				100.0
			)
		),
		"condition_label": _property_condition_label(
			float(
				template.get(
					"default_condition",
					100.0
				)
			)
		),
		"amenity_synthesis_contract": amenity_contract.duplicate(true),
		"amenity_contracts": _safe_array(
			amenity_contract.get(
				"amenity_contracts",
				[]
			)
		),
		"amenities": _safe_array(
			amenity_contract.get(
				"amenities",
				[]
			)
		),
		"amenity_ids": _safe_array(
			amenity_contract.get(
				"amenity_ids",
				[]
			)
		),
		"amenity_summary": str(
			amenity_contract.get(
				"amenity_summary",
				"No resolved amenities"
			)
		),
		"vehicle_storage_capacity": synthesized_vehicle_capacity,
		"synthesized_property_value_delta": int(
			amenity_contract.get(
				"property_value_delta",
				0
			)
		),
		"synthesized_monthly_cost_delta": int(
			amenity_contract.get(
				"monthly_cost_delta",
				0
			)
		),
		"damage_flags": [],
		"nickname": "",
		"decor_style": str(
			context.get("decor_style", "")
		),
		"upgrades": [],
		"active_assignment": "",
		"dependency_state": {
			"requirements_satisfied": satisfied_requirements,
			"requirements_missing": missing_requirements,
			"last_checked_year": int(gs.year)
		},
		"control_roles": {
			"owner_ids": [int(buyer.id)],
			"co_owner_ids": [],
			"heir_ids": [],
			"tenant_ids": [],
			"household_user_ids": [int(buyer.id)],
			"caretaker_ids": [],
			"manager_ids": [],
			"staff_ids": []
		},
		"household_access": {
			"owner_ids": [int(buyer.id)],
			"user_ids": [int(buyer.id)],
			"staff_ids": []
		},
		"legal_status": "owned",
		"market_region": str(
			context.get("market_region", "")
		),
		"market_climate": str(
			context.get("market_climate", "")
		),
		"last_maintenance_year": int(gs.year),
		"storage_contents": [],
		"assigned_staff": [],
		"known_history": [],
		"previous_owners": [],
		"provenance": {
			"acquired_year": int(gs.year),
			"acquired_era": str(gs.era.name),
			"acquired_by": int(buyer.id)
		},
		"address": _gen_address(display_name),
		"autofix_enabled": true,
		"owners": [int(buyer.id)],
		"history": [
			"%s %s purchased %s in %s." % [
				buyer.first_name,
				buyer.last_name,
				display_name,
				_format_year_for_history()
			]
		]
	}
func _calculate_property_value(template: Dictionary, buyer: Person, context:= {}) -> int:
	var base_value: float = float(template.get("base_value", 0))
	if base_value <= 0.0:
		base_value = float(context.get("fallback_price", 0))

	var multiplier: float = 1.0
	multiplier *= _market_adjustment_for_property(template, buyer, context)

	var condition: float = float(template.get("default_condition", 100.0))
	multiplier *= lerp(0.45, 1.15, clamp(condition / 100.0, 0.0, 1.0))

	var prestige_signals: Dictionary = template.get("prestige_signals", {})
	multiplier *= 1.0 + (float(prestige_signals.get("class_respect", 0.0)) * 0.04)
	multiplier *= 1.0 + (float(prestige_signals.get("fame_visibility", 0.0)) * 0.03)

	var local_variation: float = randf_range(0.9, 1.12)
	multiplier *= local_variation

	return max(1, int(round(base_value * multiplier)))
func _market_adjustment_for_property(template: Dictionary, buyer: Person, context:= {}) -> float:
	var out: float = 1.0
	var rarity: float = float(template.get("rarity", 1.0))
	out *= clamp(rarity, 0.65, 2.25)

	var feature_tags: Array = template.get("feature_tags", [])
	if "luxury" in feature_tags:
		out *= 1.35
	if "fortified" in feature_tags:
		out *= 1.2
	if "noble" in feature_tags:
		out *= 1.3
	if "hidden" in feature_tags:
		out *= 1.12
	if "frontier" in feature_tags:
		out *= 0.92

	var social_tier: String = str(template.get("social_tier", "common"))
	match social_tier:
		"working_class":
			out *= 0.82
		"respectable":
			out *= 1.0
		"wealthy":
			out *= 1.28
		"noble":
			out *= 1.55
		"celebrity":
			out *= 1.75
		"black_market":
			out *= 1.18
		"ultra_luxury":
			out *= 2.2

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
		out *= lerp(0.76, 1.12, requirement_score)

	var region_type:= str(context.get("region_type", ""))
	if region_type == "urban" and "urban" in feature_tags:
		out *= 1.1
	if region_type == "rural" and "rural" in feature_tags:
		out *= 1.08
	if region_type == "frontier" and "frontier" in feature_tags:
		out *= 1.14

	var upkeep_profile: Dictionary = template.get("upkeep_profile", {})
	var maintenance_intensity: float = max(0.25, float(upkeep_profile.get("maintenance_intensity", 1.0)))
	out *= lerp(1.08, 0.88, clamp((maintenance_intensity - 0.5) / 2.5, 0.0, 1.0))

	if buyer != null:
		var fame_factor: float = clamp(float(buyer.fame) / 100.0, 0.0, 1.0)
		out *= lerp(1.0, 1.18, fame_factor)

	return out
func get_property_asset_actions(owner: Person) -> Array:
	var out: Array = []
	if owner == null:
		return out
	if not properties.has(owner.id):
		return out

	for raw_prop in properties.get(owner.id, []):
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue

		var prop: Dictionary = raw_prop
		var asset_id:= int(prop.get("id", -1))
		if asset_id <= 0:
			continue

		var display_name:= str(prop.get("nickname", ""))
		if display_name == "":
			display_name = str(prop.get("display_name", prop.get("type", "Property")))

		for raw_action_id in prop.get("action_ids", []):
			var action_id:= str(raw_action_id)
			if action_id == "":
				continue
			out.append({
				"id": "property_asset_%d_%s" % [asset_id, action_id],
				"text": "%s • %s" % [_label_for_property_action(action_id), display_name],
				"engine": "property_engine",
				"method": "run_asset_action",
				"args": [owner, asset_id, action_id]
			})
	return out
func run_asset_action(owner: Person, asset_id: int, action_id: String) -> Dictionary:
	if owner == null:
		return { "success": false, "text": "No owner provided."}
	if not properties.has(owner.id):
		return { "success": false, "text": "No properties found."}
	var items: Array = properties.get(owner.id, [])
	for i in range(items.size()):
		var raw_prop: Variant = items [i]
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = raw_prop
		if int(prop.get("id", -1)) != asset_id:
			continue
		match action_id:
			"inspect":
				return {
					"success": true,
					"text": "%s • %s • Condition %s%% • %s" % [
						str(prop.get("display_name", prop.get("type", "Property"))),
						str(prop.get("address", "Unknown Address")),
						int(round(float(prop.get("condition", 100.0)))),
						str(prop.get("condition_label", "Excellent"))
					]
				}
			"rename":
				var new_name:= str(prop.get("nickname", ""))
				if new_name == "":
					new_name = str(prop.get("display_name", prop.get("type", "Property")))
				prop ["nickname"] = new_name
				items [i] = prop
				properties [owner.id] = items
				return { "success": true, "text": "I renamed the property to %s." % new_name}
			"maintain", "repair", "rest":
				prop ["condition"] = min(100.0, float(prop.get("condition", 100.0)) + 8.0)
				prop ["condition_label"] = _property_condition_label(float(prop.get("condition", 100.0)))
				prop ["last_maintenance_year"] = int(gs.year)
				items [i] = prop
				properties [owner.id] = items
				gs.belongings_engine.add_item(owner, prop, "Real Estate", true)
				return { "success": true, "text": "I maintained %s." % str(prop.get("display_name", prop.get("type", "Property")))}
			"throw_party":
				var display_name: String = str(
					prop.get(
						"nickname",
						prop.get(
							"display_name",
							prop.get(
								"type",
								"Property"
							)
						)
					)
				)

				var history: Array = (
					prop.get(
						"history",
						[]
					) as Array
					if typeof(
						prop.get(
							"history",
							[]
						)
					) == TYPE_ARRAY
					else []
				).duplicate(true)

				history.append(
					"%s %s hosted a party at %s in %s."
					% [
						owner.first_name,
						owner.last_name,
						display_name,
						_format_year_for_history()
					]
				)

				prop ["history"] = history
				items [i] = prop
				properties [owner.id] = items

				if (
					gs != null
					and gs.belongings_engine != null
				):
					gs.belongings_engine.add_item(
						owner,
						prop,
						"Real Estate",
						true
					)

				return {
					"success": true,
					"text": "I threw a party at %s." % display_name,
					"property_id": asset_id,
					"action_id": "throw_party",
				}
			"sell":
				var sale_value:= int(round(float(prop.get("value", prop.get("price", 0))) * randf_range(0.8, 1.08)))
				owner.bank_balance += sale_value
				var history: Array = prop.get("history", [])
				history.append("%s %s sold %s in %s." % [
					owner.first_name,
					owner.last_name,
					str(prop.get("display_name", prop.get("type", "Property"))),
					_format_year_for_history()
				])
				prop ["history"] = history
				_remove_property_from_all_owners(prop)
				return { "success": true, "text": "I sold %s for %s." % [
					str(prop.get("display_name", prop.get("type", "Property"))),
					gs.economy_engine.format_money(sale_value) if gs != null and gs.economy_engine != null else "$%d" % sale_value
				]}
			_:
				return { "success": true, "text": "I used %s through %s." % [
					str(prop.get("display_name", prop.get("type", "Property"))),
					action_id
				]}
	return { "success": false, "text": "That property could not be found."}
func yearly_asset_ecology_tick(_payload:= {}) -> void:
	if gs == null:
		return
	_yearly_property_maintenance()
	simulate_npc_property_market()


func _yearly_property_maintenance() -> void:
	var seen_asset_ids: Dictionary = {}
	for npc_id in properties.keys():
		var owner_items: Array = properties [npc_id]
		for i in range(owner_items.size()):
			var raw_prop: Variant = owner_items [i]
			if typeof(raw_prop) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = raw_prop
			var asset_id: int = int(prop.get("id", -1))
			if asset_id <= 0 or seen_asset_ids.has(asset_id):
				continue
			seen_asset_ids [asset_id] = true

			var upkeep: Dictionary = prop.get("upkeep_profile", {})
			var intensity: float = max(0.25, float(upkeep.get("maintenance_intensity", 1.0)))
			var decay_roll: float = randf_range(0.8, 3.8) * intensity

			if bool(prop.get("autofix_enabled", false)):
				prop ["condition"] = min(100.0, float(prop.get("condition", 100.0)) + 3.0)
			else:
				prop ["condition"] = clamp(float(prop.get("condition", 100.0)) - decay_roll, 0.0, 100.0)

			prop ["condition_label"] = _property_condition_label(float(prop.get("condition", 100.0)))
			prop ["last_maintenance_year"] = int(gs.year)

			var dependency_state: Dictionary = prop.get("dependency_state", {})
			dependency_state ["last_checked_year"] = int(gs.year)
			prop ["dependency_state"] = dependency_state

			prop ["value"] = max(1, int(round(
				float(prop.get("value", prop.get("price", 1))) *
				lerp(0.96, 1.02, clamp(float(prop.get("condition", 100.0)) / 100.0, 0.0, 1.0))
			)))

			for owner_id in prop.get("owners", []):
				var oid: int = int(owner_id)
				if not properties.has(oid):
					continue
				var owner_arr: Array = properties [oid]
				for idx in range(owner_arr.size()):
					var candidate: Variant = owner_arr [idx]
					if typeof(candidate) != TYPE_DICTIONARY:
						continue
					if int(candidate.get("id", -1)) != asset_id:
						continue
					owner_arr [idx] = prop
				properties [oid] = owner_arr

				var owner_npc: Person = gs.get_npc_by_id(oid)
				if owner_npc != null and gs.belongings_engine != null:
					gs.belongings_engine.add_item(owner_npc, prop, "Real Estate", true)


func simulate_npc_property_market() -> void:
	if gs == null or gs.era_data_loader == null:
		return

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if npc == gs.player:
			continue
		if int(npc.age) < 18:
			continue

		var owned_count: int = properties.get(npc.id, []).size()

		if owned_count <= 0:
			if float(npc.bank_balance) < 5000.0:
				continue
			if randf() >= 0.02:
				continue
			var context: Dictionary = _build_npc_property_market_context(npc)
			var template: Dictionary = gs.era_data_loader.get_best_property_template_for_context(gs.era.name, context)
			if template.is_empty():
				continue
			var price: int = _calculate_property_value(template, npc, context)
			if float(npc.bank_balance) < float(price):
				continue
			buy_property(npc, template, price, context)
		else:
			if float(npc.bank_balance) < 0.0 or randf() < min(0.06, 0.015 * float(owned_count)):
				var owner_items: Array = properties.get(npc.id, [])
				if owner_items.is_empty():
					continue
				var chosen_idx: int = randi() % owner_items.size()
				var raw_prop: Variant = owner_items [chosen_idx]
				if typeof(raw_prop) != TYPE_DICTIONARY:
					continue
				run_asset_action(npc, int(raw_prop.get("id", -1)), "sell")


func get_asset_signal_rollup_for_owner(
	owner: Person
) -> Dictionary:
	if owner == null:
		return {}

	var controlled_properties: Array = (
		_controlled_properties_for_actor(
			owner,
			true
		)
	)

	if controlled_properties.is_empty():
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

	for raw_prop in controlled_properties:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue

		var prop: Dictionary = raw_prop
		var asset_id: int = int(
			prop.get(
				"id",
				-1
			)
		)

		if asset_id <= 0 or seen.has(asset_id):
			continue

		seen [asset_id] = true

		_absorb_property_into_rollup(
			rollup,
			prop
		)

	if int(
		rollup.get(
			"asset_count",
			0
		)
	) <= 0:
		return {}

	_finalize_property_rollup(
		rollup
	)

	rollup ["owner_id"] = int(owner.id)
	rollup ["controlled_property_truth"] = true
	rollup ["spousal_ownership_reconciled"] = true

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

	for npc_id in properties.keys():
		for raw_prop in properties [npc_id]:
			if typeof(raw_prop) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = raw_prop
			var asset_id: int = int(prop.get("id", -1))
			if asset_id <= 0 or seen.has(asset_id):
				continue
			seen [asset_id] = true
			_absorb_property_into_rollup(rollup, prop)

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

	var upkeep_pressure: float = float(pressure_profile.get("upkeep", 0.0))
	var community_belonging: float = float(pressure_profile.get("community_belonging", 0.0))
	var spectacle: float = float(pressure_profile.get("spectacle", 0.0))
	var authority_suspicion: float = float(pressure_profile.get("authority_suspicion", 0.0))
	var fame_visibility: float = float(status_signals.get("fame_visibility", 0.0))
	var dynastic_legitimacy: float = float(status_signals.get("dynastic_legitimacy", 0.0))

	var eviction_hook_count: int = int(event_hooks.get("eviction_risk", 0)) + int(event_hooks.get("housing_instability", 0))
	var inheritance_hook_count: int = int(event_hooks.get("inheritance_drama", 0)) + int(event_hooks.get("succession_drama", 0))
	var siege_hook_count: int = int(event_hooks.get("siege_attempt", 0)) + int(event_hooks.get("siege_attempts", 0))
	var noble_visit_count: int = int(event_hooks.get("noble_visit", 0)) + int(event_hooks.get("elite_visits", 0))
	var party_hook_count: int = int(event_hooks.get("party_hosting", 0)) + int(event_hooks.get("estate_party", 0))
	var celebrity_hook_count: int = int(event_hooks.get("celebrity_sightings", 0)) + int(event_hooks.get("celebrity_dropins", 0))

	if dependency_pressure >= 1.0 or upkeep_pressure >= 1.5:
		out.append({
			"type": "text",
			"text": "Housing costs and upkeep pressed against your year.",
			"world_text": "%s's housing costs and upkeep pressed against the year."
		})

	if eviction_hook_count >= 1 or (upkeep_pressure >= 2.5 and float(status_signals.get("class_respect", 0.0)) <= 1.0):
		out.append({
			"type": "text",
			"text": "Your housing situation made the year feel more fragile, with money and security staying close to the surface.",
			"world_text": "%s's housing situation made the year feel more fragile, with money and security staying close to the surface."
		})

	if float(passive_modifiers.get("comfort", 0.0)) > 0.0 or float(passive_modifiers.get("happiness", 0.0)) > 0.0 or community_belonging >= 1.0:
		out.append({
			"type": "text",
			"text": "What you owned shaped the comfort and tone of your home life.",
			"world_text": "%s's holdings clearly shaped the comfort and tone of home life this year."
		})

	if inheritance_hook_count >= 1 or int(portfolio_tags.get("dynastic_properties", 0)) >= 1 or dynastic_legitimacy >= 1.0:
		out.append({
			"type": "text",
			"text": "Your holdings pulled legacy questions, family expectation, and inheritance energy into the year.",
			"world_text": "%s's holdings pulled legacy questions, family expectation, and inheritance energy into the year."
		})

	if siege_hook_count >= 1 or noble_visit_count >= 1 or authority_suspicion >= 1.5:
		out.append({
			"type": "text",
			"text": "Powerful property attracted authority, conflict, and status attention around you.",
			"world_text": "%s's most powerful properties attracted authority, conflict, and status attention this year."
		})

	if party_hook_count >= 1 or celebrity_hook_count >= 1 or fame_visibility >= 1.5 or spectacle >= 1.5:
		out.append({
			"type": "text",
			"text": "The right address turned parts of your year into a spectacle, drawing invitations, gossip, and attention.",
			"world_text": "%s's address turned parts of the year into a spectacle, drawing invitations, gossip, and attention."
		})

	return out
func get_property_portfolio_asset_payload(owner: Person, asset_id: int) -> Dictionary:
	var out: Dictionary = {}

	if owner == null:
		return out

	var controlled_properties: Array = (
		_controlled_properties_for_actor(
			owner,
			true
		)
	)

	for raw_prop in controlled_properties:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = raw_prop
		if int(prop.get("id", -1)) != asset_id:
			continue

		var display_name: String = str(prop.get("nickname", ""))
		if display_name == "":
			display_name = str(prop.get("display_name", prop.get("type", "Property")))

		var action_rows: Array = []
		for raw_action_id in prop.get("action_ids", []):
			var action_key: String = str(raw_action_id)
			if action_key == "":
				continue
			action_rows.append({
				"action_id": action_key,
				"label": _label_for_property_action(action_key)
			})

		var portfolio_tag_labels: Array = []
		for raw_tag in prop.get("portfolio_tags", []):
			portfolio_tag_labels.append(str(raw_tag))

		var feature_tag_labels: Array = []
		for raw_tag in prop.get("feature_tags", []):
			feature_tag_labels.append(str(raw_tag))

		var requirement_tag_labels: Array = []
		for raw_tag in prop.get("requirement_tags", []):
			requirement_tag_labels.append(str(raw_tag))

		var dependency_state: Dictionary = prop.get("dependency_state", {})
		var missing_requirement_labels: Array = []
		for raw_req in dependency_state.get("requirements_missing", []):
			missing_requirement_labels.append(str(raw_req))

		var satisfied_requirement_labels: Array = []
		for raw_req in dependency_state.get("requirements_satisfied", []):
			satisfied_requirement_labels.append(str(raw_req))

		var status_lines: Array = []
		var status_signals: Dictionary = prop.get("status_signals", prop.get("prestige_signals", {}))
		for key in status_signals.keys():
			status_lines.append("%s: %s" % [
				str(key).replace("_", " ").capitalize(),
				str(int(round(float(status_signals.get(key, 0.0)))))
			])

		var operational_lines: Array = []
		var operational_profile: Dictionary = prop.get("operational_profile", {})
		for key in operational_profile.keys():
			var value: Variant = operational_profile.get(key, null)
			operational_lines.append("%s: %s" % [
				str(key).replace("_", " ").capitalize(),
				str(value)
			])

		var pressure_lines: Array = []
		var pressure_profile: Dictionary = prop.get("pressure_profile", {})
		for key in pressure_profile.keys():
			pressure_lines.append("%s: %s" % [
				str(key).replace("_", " ").capitalize(),
				str(snappedf(float(pressure_profile.get(key, 0.0)), 0.01))
			])

		var provenance_lines: Array = []
		var provenance: Dictionary = prop.get("provenance", {})
		if not provenance.is_empty():
			provenance_lines.append("Acquired Year: %s" % str(provenance.get("acquired_year", "")))
			provenance_lines.append("Acquired Era: %s" % str(provenance.get("acquired_era", "")))
			provenance_lines.append("Acquired By NPC ID: %s" % str(provenance.get("acquired_by", "")))

		var previous_owner_lines: Array = []
		for raw_owner_id in prop.get("previous_owners", []):
			previous_owner_lines.append(str(raw_owner_id))

		return {
			"asset_id": asset_id,
			"display_name": display_name,
			"archetype": str(prop.get("archetype", "residence")),
			"subtype": str(prop.get("subtype", "")),
			"size": str(prop.get("size", "")),
			"social_tier": str(prop.get("social_tier", "common")),
			"value_band": str(prop.get("value_band", "entry")),
			"address": str(prop.get("address", "Unknown Address")),
			"condition": int(round(float(prop.get("condition", 100.0)))),
			"condition_label": str(prop.get("condition_label", "Excellent")),
			"estimated_value": int(prop.get("value", prop.get("price", 0))),
			"portfolio_tag_labels": portfolio_tag_labels,
			"feature_tag_labels": feature_tag_labels,
			"requirement_tag_labels": requirement_tag_labels,
			"missing_requirement_labels": missing_requirement_labels,
			"satisfied_requirement_labels": satisfied_requirement_labels,
			"status_lines": status_lines,
			"operational_lines": operational_lines,
			"pressure_lines": pressure_lines,
			"provenance_lines": provenance_lines,
			"previous_owner_lines": previous_owner_lines,
			"legal_status": str(prop.get("legal_status", "owned")),
			"market_region": str(prop.get("market_region", "")),
			"market_climate": str(prop.get("market_climate", "")),
			"action_rows": action_rows
		}
	return out
func property_market_templates_for_buyer(
	buyer: Person,
	context: Dictionary = {}
) -> Array:
	var templates: Array = []
	var seen_template_ids: Dictionary = {}

	if (
		buyer == null
		or gs == null
	):
		return templates

	var era_name: String = (
		_property_current_era_name(
			context
		)
	)

	if era_name == "":
		return templates

	var candidates: Array = []



	if gs.era_life_asset_catalog_expansion != null:
		candidates.append_array(
			gs.era_life_asset_catalog_expansion
			.property_templates_for_actor(
				buyer,
				context
			)
		)

	if gs.era_data_loader != null:
		candidates.append_array(
			gs.era_data_loader
			.get_property_templates_for_era(
				era_name
			)
		)

	for raw_template in candidates:
		if typeof(
			raw_template
		) != TYPE_DICTIONARY:
			continue

		var template: Dictionary = (
			raw_template as Dictionary
		)
		var template_id: String = str(
			template.get(
				"template_id",
				""
			)
		).strip_edges()

		if (
			template_id == ""
			or seen_template_ids.has(
				template_id
			)
		):
			continue

		seen_template_ids [
			template_id
		] = true

		templates.append(
			template
		)

	return templates
func build_property_market_row_contract(
	buyer: Person,
	template: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if (
		buyer == null
		or template.is_empty()
	):
		return {}

	var template_id: String = str(
		template.get(
			"template_id",
			""
		)
	).strip_edges()

	if template_id == "":
		return {}

	var price: int = int(
		_calculate_property_value(
			template,
			buyer,
			context
		)
	)
	var synthesis_context: Dictionary = (
		context.duplicate(false)
	)
	synthesis_context [
		"resolved_price"
	] = price

	var amenity_contract: Dictionary = {}
	var synthesis_engine:= (
		_property_amenity_synthesis_engine()
	)

	if synthesis_engine != null:
		amenity_contract = (
			synthesis_engine.resolve_property_contract(
				buyer,
				template,
				synthesis_context
			)
		)

	var operational_profile: Dictionary = _safe_dictionary(
		template.get(
			"operational_profile",
			{}
		)
	)
	var feature_tags: Array = _safe_array(
		template.get(
			"feature_tags",
			[]
		)
	)
	var filter_tags: Array = _safe_array(
		template.get(
			"filter_tags",
			feature_tags
		)
	)

	if not filter_tags.has(
		"available"
	):
		filter_tags.append(
			"available"
		)

	var operational_summary: Array = []

	if int(
		operational_profile.get(
			"bedrooms",
			0
		)
	) > 0:
		operational_summary.append(
			"Bedrooms %d"
			% int(
				operational_profile.get(
					"bedrooms",
					0
				)
			)
		)

	if int(
		operational_profile.get(
			"bathrooms",
			0
		)
	) > 0:
		operational_summary.append(
			"Bathrooms %d"
			% int(
				operational_profile.get(
					"bathrooms",
					0
				)
			)
		)

	var storage_capacity: int = int(
		amenity_contract.get(
			"vehicle_storage_capacity",
			template.get(
				"vehicle_storage_capacity",
				operational_profile.get(
					"vehicle_storage_capacity",
					0
				)
			)
		)
	)

	operational_summary.append(
		"Vehicle storage %d"
		% storage_capacity
	)

	return {
		"template_id": template_id,
		"property_template_contract": (
			template.duplicate(false)
		),
		"display_name": str(
			template.get(
				"display_name",
				template.get(
					"type",
					"Property"
				)
			)
		),
		"category": str(
			template.get(
				"category",
				template.get(
					"archetype",
					"residential"
				)
			)
		),
		"archetype": str(
			template.get(
				"archetype",
				"residence"
			)
		),
		"subtype": str(
			template.get(
				"subtype",
				""
			)
		),
		"size": str(
			template.get(
				"size",
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
		"ownership_modes": _safe_array(
			template.get(
				"ownership_modes",
				[
					"buy",
					"mortgage"
				]
			)
		),
		"ownership_status": "available",
		"availability": "available",
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
		"status_summary": [],
		"operational_summary": operational_summary,
		"amenity_synthesis_contract": (
			amenity_contract.duplicate(false)
		),
		"amenity_contracts": _safe_array(
			amenity_contract.get(
				"amenity_contracts",
				[]
			)
		),
		"amenities": _safe_array(
			amenity_contract.get(
				"amenities",
				[]
			)
		),
		"amenity_ids": _safe_array(
			amenity_contract.get(
				"amenity_ids",
				[]
			)
		),
		"amenity_summary": str(
			amenity_contract.get(
				"amenity_summary",
				"No resolved amenities"
			)
		),
		"vehicle_storage_capacity": storage_capacity,
		"price": price
	}
func _property_contract_is_arcade(
	property_asset: Dictionary
) -> bool:
	if property_asset.is_empty():
		return false

	var property_blob: String = (
		(
			"%s %s %s %s %s"
			% [
				str(
					property_asset.get(
						"display_name",
						property_asset.get(
							"name",
							""
						)
					)
				),
				str(
					property_asset.get(
						"type",
						""
					)
				),
				str(
					property_asset.get(
						"subtype",
						""
					)
				),
				str(
					property_asset.get(
						"archetype",
						""
					)
				),
				str(
					property_asset.get(
						"category",
						""
					)
				)
			]
		)
		.to_lower()
	)

	return property_blob.contains(
		"arcade"
	)
func apply_native_property_spatial_profile_contract(
	property_asset: Dictionary,
	graph: Dictionary
) -> Dictionary:
	if (
		property_asset.is_empty()
		or graph.is_empty()
		or not _property_contract_is_arcade(
			property_asset
		)
	):
		return graph

	var out: Dictionary = graph.duplicate(false)
	var layout_key: String = str(
		out.get(
			"layout_key",
			""
		)
	).strip_edges().to_lower()




	out [
		"native_property_profile"
	] = "arcade"
	out [
		"native_property_profile_authority"
	] = ENGINE_SCHEMA
	out [
		"native_property_profile_ready"
	] = (
		layout_key == "arcade"
	)
	out [
		"native_property_profile_requires_cold_topology_migration"
	] = (
		layout_key != "arcade"
	)
	out [
		"generic_residential_semantics_rejected"
	] = true
	out [
		"room_identity_relabeling_performed"
	] = false
	out [
		"fixture_injection_performed"
	] = false

	return out
func get_property_market_rows_for_buyer(
	buyer: Person,
	context: Dictionary = {}
) -> Array:
	var rows: Array = []

	for raw_template in property_market_templates_for_buyer(
		buyer,
		context
	):
		if typeof(raw_template) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			build_property_market_row_contract(
				buyer,
				raw_template as Dictionary,
				context
			)
		)

		if not row.is_empty():
			rows.append(
				row
			)

	rows.sort_custom(
		func (
			left_raw,
			right_raw
		) -> bool:
			return int(
				(left_raw as Dictionary).get(
					"price",
					0
				)
			) < int(
				(right_raw as Dictionary).get(
					"price",
					0
				)
			)
	)

	return rows
func get_property_portfolio_panel_payload(
	owner: Person
) -> Dictionary:
	var out: Dictionary = {
		"rollup": {},
		"asset_rows": [],
		"owner_id": (
			int(owner.id)
			if owner != null
			else -1
		),
		"truth_state": "observable_partial"
	}

	if owner == null:
		return out

	var controlled_properties: Array = (
		_controlled_properties_for_actor(
			owner,
			true
		)
	)

	out ["rollup"] = (
		get_asset_signal_rollup_for_owner(
			owner
		)
	)

	var rows: Array = []
	var seen: Dictionary = {}

	for raw_prop in controlled_properties:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue

		var prop: Dictionary = raw_prop
		var asset_id: int = int(
			prop.get(
				"id",
				-1
			)
		)

		if asset_id <= 0 or seen.has(asset_id):
			continue

		seen [asset_id] = true

		var display_name: String = str(
			prop.get(
				"nickname",
				""
			)
		)

		if display_name == "":
			display_name = str(
				prop.get(
					"display_name",
					prop.get(
						"type",
						"Property"
					)
				)
			)

		rows.append({
			"asset_id": asset_id,
			"display_name": display_name,
			"address": str(
				prop.get(
					"address",
					"Unknown Address"
				)
			),
			"condition": int(
				round(
					float(
						prop.get(
							"condition",
							100.0
						)
					)
				)
			),
			"condition_label": str(
				prop.get(
					"condition_label",
					"Excellent"
				)
			),
			"legal_owner_ids": _safe_array(
				prop.get(
					"owners",
					[]
				)
			).duplicate(true),
		})

	out ["asset_rows"] = rows
	out ["asset_count"] = rows.size()
	out ["truth_state"] = "hot"
	out ["spousal_ownership_reconciled"] = true
	out ["ui_is_renderer_only"] = true

	return out
func _absorb_property_into_rollup(rollup: Dictionary, prop: Dictionary) -> void:
	rollup ["asset_count"] = int(rollup.get("asset_count", 0)) + 1
	var dependency_state: Dictionary = prop.get("dependency_state", {})
	var missing_requirements: Array = dependency_state.get("requirements_missing", [])
	rollup ["dependency_pressure"] = float(rollup.get("dependency_pressure", 0.0)) + float(missing_requirements.size())

	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	for raw_tag in prop.get("portfolio_tags", []):
		var tag:= str(raw_tag)
		portfolio_tags [tag] = int(portfolio_tags.get(tag, 0)) + 1
	rollup ["portfolio_tags"] = portfolio_tags

	var event_hooks: Dictionary = rollup.get("event_hooks", {})
	for raw_hook in prop.get("event_hooks", []):
		var hook_name:= str(raw_hook)
		event_hooks [hook_name] = int(event_hooks.get(hook_name, 0)) + 1
	rollup ["event_hooks"] = event_hooks

	var passive_modifiers: Dictionary = rollup.get("passive_modifiers", {})
	for key in prop.get("passive_modifiers", {}).keys():
		var k:= str(key)
		var value:= float(prop.get("passive_modifiers", {}).get(key, 0.0))
		passive_modifiers [k] = float(passive_modifiers.get(k, 0.0)) + value
		rollup ["modifier_weight"] = float(rollup.get("modifier_weight", 0.0)) + abs(value)
	rollup ["passive_modifiers"] = passive_modifiers

	var prestige_signals: Dictionary = rollup.get("prestige_signals", {})
	for key in prop.get("prestige_signals", {}).keys():
		var k:= str(key)
		var value:= float(prop.get("prestige_signals", {}).get(key, 0.0))
		prestige_signals [k] = float(prestige_signals.get(k, 0.0)) + value
		rollup ["prestige_total"] = float(rollup.get("prestige_total", 0.0)) + max(0.0, value)
	rollup ["prestige_signals"] = prestige_signals

	var status_signals_source: Dictionary = prop.get("status_signals", prop.get("prestige_signals", {}))
	var status_signals: Dictionary = rollup.get("status_signals", {})
	for key in status_signals_source.keys():
		var k:= str(key)
		var value:= float(status_signals_source.get(key, 0.0))
		status_signals [k] = float(status_signals.get(k, 0.0)) + value
	rollup ["status_signals"] = status_signals

	var pressure_profile_source: Dictionary = prop.get("pressure_profile", {})
	var pressure_profile: Dictionary = rollup.get("pressure_profile", {})
	for key in pressure_profile_source.keys():
		var k:= str(key)
		var value:= float(pressure_profile_source.get(key, 0.0))
		pressure_profile [k] = float(pressure_profile.get(k, 0.0)) + value
	rollup ["pressure_profile"] = pressure_profile

	var asset_namespaces: Dictionary = rollup.get("asset_namespaces", {})
	var namespace_key: String = _property_asset_namespace(prop)
	if namespace_key != "":
		_increment_counter_map(asset_namespaces, namespace_key)
	rollup ["asset_namespaces"] = asset_namespaces

	var asset_class_filters: Dictionary = rollup.get("asset_class_filters", {})
	for raw_key in _property_asset_class_keys(prop):
		var class_key: String = str(raw_key)
		if class_key != "":
			_increment_counter_map(asset_class_filters, class_key)
	rollup ["asset_class_filters"] = asset_class_filters

	var asset_identity_modes: Dictionary = rollup.get("asset_identity_modes", {})
	for raw_mode in _property_asset_identity_modes(prop, namespace_key):
		var mode_key: String = str(raw_mode)
		if mode_key != "":
			_increment_counter_map(asset_identity_modes, mode_key)
	rollup ["asset_identity_modes"] = asset_identity_modes

	var asset_tier_profile: Dictionary = rollup.get("asset_tier_profile", {})
	var tier_key: String = _asset_tier_key_from_labels(
		str(prop.get("social_tier", "common")),
		str(prop.get("value_band", "entry"))
	)
	if tier_key != "":
		_increment_float_map(asset_tier_profile, tier_key, 1.0)
	rollup ["asset_tier_profile"] = asset_tier_profile

	var asset_condition_profile: Dictionary = rollup.get("asset_condition_profile", {})
	var condition_key: String = _asset_condition_key(prop)
	if condition_key != "":
		_increment_float_map(asset_condition_profile, condition_key, 1.0)
	rollup ["asset_condition_profile"] = asset_condition_profile

	var asset_provenance_signals: Dictionary = rollup.get("asset_provenance_signals", {})
	for raw_key in _property_asset_provenance_keys(prop):
		var provenance_key: String = str(raw_key)
		if provenance_key != "":
			_increment_float_map(asset_provenance_signals, provenance_key, 1.0)
	rollup ["asset_provenance_signals"] = asset_provenance_signals
func _finalize_property_rollup(rollup: Dictionary) -> void:
	var asset_namespaces: Dictionary = rollup.get("asset_namespaces", {})
	var asset_identity_modes: Dictionary = rollup.get("asset_identity_modes", {})
	var asset_tier_profile: Dictionary = rollup.get("asset_tier_profile", {})
	var uniqueness_score: float = 0.0
	uniqueness_score += float(asset_namespaces.size()) * 1.15
	uniqueness_score += float(asset_identity_modes.size()) * 0.9
	if float(asset_tier_profile.get("noble", 0.0)) > 0.0:
		uniqueness_score += 1.25
	if int(rollup.get("asset_count", 0)) == 1 and asset_namespaces.size() == 1:
		uniqueness_score += 0.75
	rollup ["asset_uniqueness_score"] = uniqueness_score


func _property_asset_namespace(prop: Dictionary) -> String:
	var display_name: String = str(prop.get("display_name", prop.get("type", "Property"))).to_lower()
	var archetype: String = str(prop.get("archetype", "residence")).to_lower()

	if display_name.findn("castle") != -1 or display_name.findn("keep") != -1 or display_name.findn("palace") != -1:
		return "property.castle"
	if display_name.findn("shack") != -1:
		return "property.shack"
	if display_name.findn("manor") != -1 or display_name.findn("estate") != -1:
		return "property.estate"
	if display_name.findn("villa") != -1:
		return "property.villa"
	if display_name.findn("farm") != -1 or display_name.findn("homestead") != -1:
		return "property.farmland"
	if display_name.findn("temple") != -1:
		return "property.ceremonial_residence"
	if display_name.findn("apartment") != -1 or display_name.findn("tenement") != -1:
		return "property.dense_housing"
	if archetype != "":
		return "property.%s" % archetype
	return "property.residence"


func _property_asset_class_keys(prop: Dictionary) -> Array:
	var out: Array = []
	var archetype: String = str(prop.get("archetype", "residence")).to_lower()
	var social_tier: String = str(prop.get("social_tier", "common")).to_lower()

	if archetype != "":
		out.append("property.archetype.%s" % archetype)
	if social_tier != "":
		out.append("property.tier.%s" % social_tier)

	for raw_tag in prop.get("feature_tags", []):
		var tag: String = str(raw_tag).to_lower()
		if tag != "":
			out.append("property.feature.%s" % tag)

	return out


func _property_asset_identity_modes(prop: Dictionary, namespace_key: String = "") -> Array:
	var out: Array = []
	var archetype: String = str(prop.get("archetype", "residence")).to_lower()
	var social_tier: String = str(prop.get("social_tier", "common")).to_lower()
	var status_signals: Dictionary = prop.get("status_signals", prop.get("prestige_signals", {}))
	var event_hooks: Array = prop.get("event_hooks", [])
	var feature_tags: Array = prop.get("feature_tags", [])
	var condition: float = float(prop.get("condition", 100.0))

	if archetype == "residence":
		out.append("residence")
	if namespace_key == "property.castle":
		out.append("fortress")
	if _string_array_contains(feature_tags, "family_seat") or float(status_signals.get("dynastic_legitimacy", 0.0)) > 0.0:
		out.append("dynasty_seat")
	if _string_array_contains(feature_tags, "ceremonial") or social_tier in ["noble", "royal", "elite"]:
		out.append("ceremonial_symbol")
	if _string_array_contains(event_hooks, "inheritance_drama") or _string_array_contains(event_hooks, "succession_drama") or _property_was_inherited(prop):
		out.append("inheritance_anchor")
	if float(status_signals.get("fame_visibility", 0.0)) > 1.0 or _string_array_contains(event_hooks, "party_hosting") or _string_array_contains(event_hooks, "celebrity_dropins"):
		out.append("scandal_magnet")
	if condition <= 45.0:
		out.append("decaying_anchor")

	_dedupe_string_array_in_place(out)
	return out


func _property_asset_provenance_keys(prop: Dictionary) -> Array:
	var out: Array = []
	var provenance: Dictionary = prop.get("provenance", {})
	var acquisition_mode: String = str(
		provenance.get(
			"acquisition_mode",
			prop.get("acquisition_mode", provenance.get("acquired_via", ""))
		)
	).to_lower()
	var event_hooks: Array = prop.get("event_hooks", [])
	var status_signals: Dictionary = prop.get("status_signals", prop.get("prestige_signals", {}))

	if provenance.has("last_inherited_year") or acquisition_mode.findn("inherit") != -1:
		out.append("inherited")
	elif acquisition_mode.findn("conquer") != -1 or acquisition_mode.findn("seize") != -1:
		out.append("conquered")
	elif acquisition_mode.findn("gift") != -1:
		out.append("gifted")
	elif acquisition_mode.findn("buy") != -1 or acquisition_mode.findn("purch") != -1:
		out.append("bought")
	elif int(prop.get("value", prop.get("price", 0))) > 0:
		out.append("bought")

	if _string_array_contains(event_hooks, "inheritance_drama") or _string_array_contains(event_hooks, "succession_drama") or _string_array_contains(event_hooks, "land_dispute"):
		out.append("contested")
	if float(status_signals.get("fame_visibility", 0.0)) > 1.0:
		out.append("famous")
	if _string_array_contains(event_hooks, "tax_abuse") or _string_array_contains(event_hooks, "servant_gossip") or _string_array_contains(event_hooks, "secret_prisoner"):
		out.append("old_scandal")

	_dedupe_string_array_in_place(out)
	return out


func _property_was_inherited(prop: Dictionary) -> bool:
	var provenance: Dictionary = prop.get("provenance", {})
	if provenance.has("last_inherited_year"):
		return true
	var acquisition_mode: String = str(
		provenance.get(
			"acquisition_mode",
			prop.get("acquisition_mode", provenance.get("acquired_via", ""))
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


func _sync_property_control_roles(prop: Dictionary, owner_id: int) -> void:
	var control_roles: Dictionary = prop.get("control_roles", {})
	var owner_ids: Array = control_roles.get("owner_ids", [])
	if owner_id not in owner_ids:
		owner_ids.append(owner_id)
	control_roles ["owner_ids"] = owner_ids

	var household_user_ids: Array = control_roles.get("household_user_ids", [])
	if owner_id not in household_user_ids:
		household_user_ids.append(owner_id)
	control_roles ["household_user_ids"] = household_user_ids
	prop ["control_roles"] = control_roles

	var household_access: Dictionary = prop.get("household_access", {})
	var access_owner_ids: Array = household_access.get("owner_ids", [])
	if owner_id not in access_owner_ids:
		access_owner_ids.append(owner_id)
	household_access ["owner_ids"] = access_owner_ids

	var user_ids: Array = household_access.get("user_ids", [])
	if owner_id not in user_ids:
		user_ids.append(owner_id)
	household_access ["user_ids"] = user_ids
	prop ["household_access"] = household_access


func _remove_property_from_all_owners(prop: Dictionary) -> void:
	var owner_ids: Array = prop.get("owners", []).duplicate()
	for raw_owner_id in owner_ids:
		_remove_property_refs(int(raw_owner_id), int(prop.get("id", -1)))
	prop ["owners"] = []

	var control_roles: Dictionary = prop.get("control_roles", {})
	control_roles ["owner_ids"] = []
	control_roles ["household_user_ids"] = []
	prop ["control_roles"] = control_roles

	var household_access: Dictionary = prop.get("household_access", {})
	household_access ["owner_ids"] = []
	household_access ["user_ids"] = []
	prop ["household_access"] = household_access


func _build_npc_property_market_context(npc: Person) -> Dictionary:
	var desired_tags: Array = []
	var social_tier:= "respectable"
	var social_class:= str(npc.social_class).to_lower()

	match social_class:
		"slave", "peasant":
			social_tier = "working_class"
		"commoner":
			social_tier = "respectable"
		"merchant":
			social_tier = "wealthy"
			if "family_seat" not in desired_tags:
				desired_tags.append("family_seat")
		"noble":
			social_tier = "aristocrat"
			for tag in ["luxury", "family_seat", "noble"]:
				if tag not in desired_tags:
					desired_tags.append(tag)
		"royal":
			social_tier = "royal"
			for tag in ["luxury", "family_seat", "noble", "ceremonial"]:
				if tag not in desired_tags:
					desired_tags.append(tag)

	if float(npc.fame) >= 60.0 and "luxury" not in desired_tags:
		desired_tags.append("luxury")
	if npc.partner != null or npc.children.size() > 0:
		if "family_seat" not in desired_tags:
			desired_tags.append("family_seat")
	if float(npc.bank_balance) >= 1000000.0 and social_tier not in ["royal", "aristocrat"]:
		social_tier = "wealthy"
	if float(npc.fame) >= 80.0 and social_tier not in ["royal"]:
		social_tier = "celebrity"

	if npc.is_royal or npc.is_ruler:
		social_tier = "royal"
		for tag in ["luxury", "family_seat", "noble", "ceremonial", "dynasty_seat"]:
			if tag not in desired_tags:
				desired_tags.append(tag)
		if gs != null and gs.era != null and gs.era.name in ["Ancient Era", "Medieval Era"]:
			if "fortified" not in desired_tags:
				desired_tags.append("fortified")

	return {
		"desired_tags": desired_tags,
		"social_tier": social_tier,
		"market_climate": "stable"
	}
func _property_condition_label(score: float) -> String:
	if score >= 90.0:
		return "Excellent"
	if score >= 75.0:
		return "Good"
	if score >= 55.0:
		return "Worn"
	if score >= 30.0:
		return "Strained"
	return "Critical"
func _format_year_for_history() -> String:
	if gs == null:
		return "Unknown Year"
	if int(gs.year) < 0:
		return "%d BCE" % abs(int(gs.year))
	return "%d AD" % int(gs.year)


func _property_type_for_size(size: String) -> String:
	var s:= str(
		size
	)
	var era_name: String = (
		_property_current_era_name()
	)

	if s == "Royal":
		match era_name:
			"Ancient Era":
				return "Royal Castle"
			"Medieval Era":
				return "Royal Castle"
			"Industrial Era":
				return "Royal Palace"
			"Modern Era":
				return "Royal Palace"
			"Future Era":
				return "Royal Palace"
			_:
				return "Royal Palace"

	match era_name:
		"Ancient Era":
			match s:
				"Small":
					return "Insula"
				"Medium":
					return "Domus"
				"Large":
					return "Villa"
				"Mansion":
					return "Temple Residence"
				_:
					return "Domus"

		"Medieval Era":
			match s:
				"Small":
					return "Cottage"
				"Medium":
					return "Longhouse"
				"Large":
					return "Manor"
				"Mansion":
					return "Castle Keep"
				_:
					return "Manor"

		"Industrial Era":
			match s:
				"Small":
					return "Tenement"
				"Medium":
					return "Townhouse"
				"Large":
					return "Estate"
				"Mansion":
					return "Factory House"
				_:
					return "Townhouse"

		"Modern Era":
			match s:
				"Small":
					return "Apartment"
				"Medium":
					return "Suburban Home"
				"Large":
					return "Condo"
				"Mansion":
					return "Mansion"
				_:
					return "Suburban Home"

		"Future Era":
			match s:
				"Small":
					return "Sky Pod"
				"Medium":
					return "Smart Habitat"
				"Large":
					return "Colony Unit"
				"Mansion":
					return "Floating Estate"
				_:
					return "Smart Habitat"

		_:
			return "Residence"


func _register_property_for_owner(
	owner: Person,
	prop: Dictionary,
	share_with_partner:= true
) -> void:
	if (
		owner == null
		or prop.is_empty()
	):
		return

	var owner_id: int = int(
		owner.id
	)
	var affected_actor_ids: Array = []
	var registration_changed: bool = false

	if not properties.has(
		owner_id
	):
		properties [
			owner_id
		] = []
		registration_changed = true

	if prop not in properties [
		owner_id
	]:
		properties [
			owner_id
		].append(
			prop
		)
		registration_changed = true

	if (
		gs != null
		and gs.belongings_engine != null
	):
		gs.belongings_engine.add_item(
			owner,
			prop,
			"Real Estate",
			true,
			{
				"source": (
					"property_engine_contract_mirror"
				),
				"property_truth_authority": (
					"PropertyEngine"
				),
				"spawn_existing_asset": true,
				"defer_reality_routing": true,
				"suppress_object_perception": true,
				"suppress_upce_perception": true,
				"suppress_player_ui_interpretation": true,
				"suppress_duplicate_discovery_text": true,
				"transaction_enrichment_deferred": true,
				"ui_blocking_forbidden": true
			}
		)

	var owner_ids: Array = _safe_array(
		prop.get(
			"owners",
			prop.get(
				"legal_owner_ids",
				[]
			)
		)
	)

	if owner_id not in owner_ids:
		owner_ids.append(
			owner_id
		)
		registration_changed = true

	prop [
		"owners"
	] = owner_ids
	prop [
		"legal_owner_ids"
	] = owner_ids.duplicate(false)

	_sync_property_control_roles(
		prop,
		owner_id
	)

	affected_actor_ids.append(
		owner_id
	)

	if (
		share_with_partner
		and gs != null
	):
		var spouse: Person = (
			gs.get_valid_partner(
				owner,
				true
			)
		)

		if (
			spouse != null
			and spouse.alive
		):
			var spouse_id: int = int(
				spouse.id
			)
			var spouse_became_owner: bool = (
				spouse_id not in owner_ids
			)

			if spouse_became_owner:
				owner_ids.append(
					spouse_id
				)
				registration_changed = true

			prop [
				"owners"
			] = owner_ids
			prop [
				"legal_owner_ids"
			] = owner_ids.duplicate(false)

			_sync_property_control_roles(
				prop,
				spouse_id
			)

			if not properties.has(
				spouse_id
			):
				properties [
					spouse_id
				] = []
				registration_changed = true

			if prop not in properties [
				spouse_id
			]:
				properties [
					spouse_id
				].append(
					prop
				)
				registration_changed = true

			if gs.belongings_engine != null:
				gs.belongings_engine.add_item(
					spouse,
					prop,
					"Real Estate",
					true,
					{
						"source": (
							"property_engine_contract_mirror"
						),
						"property_truth_authority": (
							"PropertyEngine"
						),
						"spawn_existing_asset": true,
						"defer_reality_routing": true,
						"suppress_object_perception": true,
						"suppress_upce_perception": true,
						"suppress_player_ui_interpretation": true,
						"suppress_duplicate_discovery_text": true,
						"transaction_enrichment_deferred": true,
						"ui_blocking_forbidden": true
					}
				)

			if spouse_became_owner:
				var history: Array = _safe_array(
					prop.get(
						"history",
						[]
					)
				)
				var history_entry: String = (
					"%s %s became a shared owner in %s."
					% [
						spouse.first_name,
						spouse.last_name,
						_format_year_for_history()
					]
				)

				if history_entry not in history:
					history.append(
						history_entry
					)

				prop [
					"history"
				] = history

			if spouse_id not in affected_actor_ids:
				affected_actor_ids.append(
					spouse_id
				)

	if not registration_changed:
		return

	last_contract_report = {
		"success": true,
		"schema": (
			"eralife.property."
			+ "owner_registration_report"
		),
		"version": CONTRACT_VERSION,
		"property_id": int(
			prop.get(
				"id",
				-1
			)
		),
		"property_name": str(
			prop.get(
				"name",
				prop.get(
					"display_name",
					"Property"
				)
			)
		),
		"primary_owner_id": owner_id,
		"affected_actor_ids": (
			affected_actor_ids.duplicate(false)
		),
		"shared_with_partner": (
			affected_actor_ids.size() > 1
		),
		"registered_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if (
		gs != null
		and gs.assets_contract_engine != null
		and gs.assets_contract_engine.has_method(
			"invalidate_actor"
		)
	):
		for raw_actor_id in affected_actor_ids:
			var affected_actor_id: int = int(
				raw_actor_id
			)

			if affected_actor_id <= 0:
				continue

			gs.assets_contract_engine.invalidate_actor(
				affected_actor_id,
				"property_registered_for_owner"
			)

	_publish_contract_state(
		"property_registered_for_owner"
	)


func _remove_property_refs(owner_id: int, prop_id: int) -> void:
	if not properties.has(owner_id):
		return

	var kept: Array = []
	for prop in properties [owner_id]:
		if int(prop.get("id", -1)) != prop_id:
			kept.append(prop)
	properties [owner_id] = kept


func _is_player_emotionally_affected_by(npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false

	var p: Person = gs.player

	if npc.id in p.parents:
		return true
	if npc.id in p.children:
		return true
	if p.partner != null and p.partner.id == npc.id:
		return true
	if npc.id in p.friends:
		return true
	if npc.id in p.ex_partners:
		return true

	if p.parents.size() > 0 and npc.parents == p.parents and npc.id != p.id:
		return true

	for gid in gs._collect_player_ancestor_ids(4):
		if int(gid) == npc.id:
			return true

	return false


func _player_can_skip_generation(dead_npc: Person) -> bool:
	if gs == null or gs.player == null or dead_npc == null:
		return false
	if not gs.player.alive:
		return false
	if gs.relationship_engine == null:
		return false

	var score:= int(gs.relationship_engine.update_relationship(gs.player, dead_npc))
	if score < 75:
		return false

	return randf() < 0.18


func _resolve_dead_npc_from_payload(payload) -> Person:
	if payload is Person:
		return payload

	if typeof(payload) == TYPE_DICTIONARY:
		var npc_id: int = int(payload.get("npc_id", -1))
		if npc_id > 0:
			var resolved: Person = gs.get_or_reactivate_npc_by_id(npc_id)
			if resolved != null:
				return resolved

		var embedded_npc = payload.get("npc", null)
		if embedded_npc is Person:
			return embedded_npc

		var embedded_value = payload.get("value", null)
		if embedded_value is Person:
			return embedded_value

	return null

func _resolve_explicit_heir_from_payload(payload) -> Person:
	if typeof(payload) != TYPE_DICTIONARY:
		return null
	var explicit_heir_id: int = int(payload.get("explicit_heir_id", payload.get("heir_id", -1)))
	if explicit_heir_id <= 0 and typeof(payload.get("data", null)) == TYPE_DICTIONARY:
		var data: Dictionary = payload.get("data", {})
		explicit_heir_id = int(data.get("explicit_heir_id", data.get("heir_id", -1)))
	if explicit_heir_id <= 0:
		return null
	return gs.get_or_reactivate_npc_by_id(explicit_heir_id)
func handle_inheritance(payload) -> void:
	var dead_npc: Person = _resolve_dead_npc_from_payload(payload)
	if dead_npc == null:
		return
	if gs.should_skip_manual_player_inheritance(int(dead_npc.id)):
		return
	if _is_player_emotionally_affected_by(dead_npc):
		gs.player.satisfaction = clamp(int(gs.player.satisfaction) - 10, 0, 100)
		gs.pending_death_messages.append("\n%s %s died." % [
			dead_npc.first_name, dead_npc.last_name
		])
	if not properties.has(dead_npc.id):
		return
	var estate: Array = properties.get(dead_npc.id, []).duplicate()
	if estate.is_empty():
		return
	var heirs: Array = []
	var explicit_heir: Person = _resolve_explicit_heir_from_payload(payload)
	var spouse: Person = gs.get_valid_partner(dead_npc, true)
	if explicit_heir != null and explicit_heir.alive:
		heirs.append(explicit_heir)
	elif spouse != null and spouse.alive:
		heirs.append(spouse)
	for cid in dead_npc.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(cid))
		if child != null and child.alive and child not in heirs:
			heirs.append(child)
	if _player_can_skip_generation(dead_npc) and gs.player not in heirs:
		heirs.append(gs.player)
	if heirs.is_empty():
		return
	var chosen_heir: Person = heirs [0]
	if chosen_heir == null:
		return
	if not properties.has(chosen_heir.id):
		properties [chosen_heir.id] = []
	for prop in estate:
		if prop not in properties [chosen_heir.id]:
			properties [chosen_heir.id].append(prop)
		var owners: Array = prop.get("owners", []).duplicate()
		var kept_owners: Array = []
		for owner_id in owners:
			if int(owner_id) != int(dead_npc.id):
				kept_owners.append(owner_id)
		if int(chosen_heir.id) not in kept_owners:
			kept_owners.append(chosen_heir.id)
		prop ["owners"] = kept_owners
		var history: Array = prop.get("history", [])
		history.append("%s %s inherited this %s in %s." % [
			chosen_heir.first_name,
			chosen_heir.last_name,
			str(prop.get("type", "property")),
			_format_year_for_history()
		])
		prop ["history"] = history
	properties.erase(dead_npc.id)



func _gen_address(property_type: String = "") -> String:
	var base:= ""
	var era_name: String = (
		_property_current_era_name()
	)

	match era_name:
		"Ancient Era":
			match property_type:
				"Domus":
					base = (
						"Domus %d, Patrician Hill"
						% randi_range(
							1,
							50000
						)
					)
				"Insula":
					base = (
						"Insula %d, Lower District"
						% randi_range(
							1,
							50000
						)
					)
				"Villa":
					base = (
						"Villa Plot %d, Olive Road"
						% randi_range(
							1,
							50000
						)
					)
				"Temple Residence":
					base = (
						"Temple Quarter %d"
						% randi_range(
							1,
							50000
						)
					)
				_:
					base = (
						"Block %d of the Lower District"
						% randi_range(
							1,
							50000
						)
					)

		"Medieval Era":
			match property_type:
				"Cottage":
					base = (
						"%d Miller's Lane"
						% randi_range(
							1,
							50000
						)
					)
				"Longhouse":
					base = (
						"%d Timber Row"
						% randi_range(
							1,
							50000
						)
					)
				"Manor":
					base = (
						"%d Manor Way"
						% randi_range(
							1,
							50000
						)
					)
				"Castle Keep":
					base = (
						"%d Keep Hill"
						% randi_range(
							1,
							50000
						)
					)
				_:
					base = (
						"%d Guild Row"
						% randi_range(
							1,
							50000
						)
					)

		"Industrial Era":
			match property_type:
				"Tenement":
					base = (
						"%d Soot Alley"
						% randi_range(
							1,
							50000
						)
					)
				"Townhouse":
					base = (
						"%d Iron Street"
						% randi_range(
							1,
							50000
						)
					)
				"Estate":
					base = (
						"%d Foundry Heights"
						% randi_range(
							1,
							50000
						)
					)
				"Factory House":
					base = (
						"%d Smoke Street"
						% randi_range(
							1,
							50000
						)
					)
				_:
					base = (
						"%d Smoke Street"
						% randi_range(
							1,
							50000
						)
					)

		"Modern Era":
			match property_type:
				"Apartment":
					base = (
						"%d Evergreen Ave"
						% randi_range(
							1,
							50000
						)
					)
				"Suburban Home":
					base = (
						"%d Maple Drive"
						% randi_range(
							1,
							50000
						)
					)
				"Condo":
					base = (
						"%d Skyline Blvd"
						% randi_range(
							1,
							50000
						)
					)
				"Mansion":
					base = (
						"%d Grand Oaks Estate"
						% randi_range(
							1,
							50000
						)
					)
				"Penthouse":
					base = (
						"Penthouse %d, Skyline Tower"
						% randi_range(
							1,
							50000
						)
					)
				_:
					base = (
						"%d Evergreen Ave"
						% randi_range(
							1,
							50000
						)
					)

		"Future Era":
			match property_type:
				"Sky Pod":
					base = (
						"Pod-%d Aurora Ring"
						% randi_range(
							1,
							50000
						)
					)
				"Smart Habitat":
					base = (
						"Habitat-%d Hyperlane"
						% randi_range(
							1,
							50000
						)
					)
				"Floating Estate":
					base = (
						"Estate-%d Cloud Belt"
						% randi_range(
							1,
							50000
						)
					)
				"Colony Unit":
					base = (
						"Colony Sector %d"
						% randi_range(
							1,
							50000
						)
					)
				_:
					base = (
						"Module-%d Hyperlane"
						% randi_range(
							1,
							50000
						)
					)

		_:
			base = (
				"%d Unknown Road"
				% randi_range(
					1,
					50000
				)
			)

	if used_addresses.has(
		base
	):
		return _gen_address(
			property_type
		)

	used_addresses [
		base
	] = true

	return base
func _gen_id():
	gs.next_id += 1
	return gs.next_id
func get_buyable_property_templates_for_person(
	person: Person,
	desired_tags:= [],
	extra_context:= {}
) -> Array:
	var out: Array = []

	if (
		gs == null
		or gs.era_data_loader == null
	):
		return out

	var context: Dictionary = (
		extra_context.duplicate(true)
	)

	var era_name: String = (
		_property_current_era_name(
			context
		)
	)

	if era_name == "":
		return out

	if not context.has(
		"desired_tags"
	):
		context [
			"desired_tags"
		] = desired_tags.duplicate()

	for raw_template in (
		gs.era_data_loader
		.get_property_templates_for_era(
			era_name
		)
	):
		if typeof(
			raw_template
		) != TYPE_DICTIONARY:
			continue

		var template: Dictionary = (
			raw_template
		)

		if _property_template_matches_person(
			template,
			person,
			context
		):
			out.append(
				template.duplicate(true)
			)

	return out


func _property_template_matches_person(template: Dictionary, _person: Person, context:= {}) -> bool:
	if gs == null or gs.era_data_loader == null:
		return false
	return gs.era_data_loader.template_matches_context(template, context)
func _property_current_era_name(
	context: Dictionary = {}
) -> String:
	var candidates: Array = []

	for key in [
		"era_name",
		"era"
	]:
		var direct_value: String = str(
			context.get(
				key,
				""
			)
		).strip_edges()

		if direct_value != "":
			candidates.append(
				direct_value
			)

	if gs != null:
		var resident_era: Variant = gs.era

		if typeof(
			resident_era
		) == TYPE_DICTIONARY:
			var resident_era_dict: Dictionary = (
				resident_era as Dictionary
			)

			for key in [
				"name",
				"era_name",
				"key"
			]:
				var resident_value: String = str(
					resident_era_dict.get(
						key,
						""
					)
				).strip_edges()

				if resident_value != "":
					candidates.append(
						resident_value
					)

		elif (
			typeof(
				resident_era
			) == TYPE_OBJECT
			and resident_era != null
		):
			var resident_object:= (
				resident_era as Object
			)

			var resident_name: String = str(
				resident_object.get(
					"name"
				)
			).strip_edges()

			if (
				resident_name != ""
				and resident_name != "<null>"
			):
				candidates.append(
					resident_name
				)

		if typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY:
			for key in [
				"era_name",
				"era"
			]:
				var scenario_value: String = str(
					gs.scenario_state.get(
						key,
						""
					)
				).strip_edges()

				if scenario_value != "":
					candidates.append(
						scenario_value
					)

		if typeof(
			gs.custom_settings
		) == TYPE_DICTIONARY:
			for key in [
				"era_name",
				"era"
			]:
				var settings_value: String = str(
					gs.custom_settings.get(
						key,
						""
					)
				).strip_edges()

				if settings_value != "":
					candidates.append(
						settings_value
					)

	for raw_candidate in candidates:
		var candidate: String = str(
			raw_candidate
		).strip_edges().to_lower()

		match candidate:
			"ancient", "ancient era":
				return "Ancient Era"

			"medieval", "medieval era":
				return "Medieval Era"

			"industrial", "industrial era":
				return "Industrial Era"

			"modern", "modern era":
				return "Modern Era"

			"future", "future era":
				return "Future Era"





	if gs != null:
		var year_value: int = int(
			gs.year
		)

		if year_value <= 476:
			return "Ancient Era"

		if year_value <= 1492:
			return "Medieval Era"

		if year_value <= 1945:
			return "Industrial Era"

		if year_value <= 2039:
			return "Modern Era"

		return "Future Era"

	return ""
func _label_for_property_action(action_id: String) -> String:
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
		"rest":
			return "Rest"
		"use":
			return "Use"
		"host_feast":
			return "Host Feast"
		"fortify":
			return "Fortify"
		"renovate":
			return "Renovate"
		"throw_party":
			return "Throw Party"
		"store_contraband":
			return "Store Contraband"
		"open_to_tenants":
			return "Open To Tenants"
		"hold_ceremony":
			return "Hold Ceremony"
		_:
			return action_id.capitalize()


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)

	return {}