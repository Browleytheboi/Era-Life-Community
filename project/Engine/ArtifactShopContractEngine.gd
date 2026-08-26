

extends RefCounted
class_name ArtifactShopContractEngine

const ENGINE_SCHEMA:= "eralife.artifact_shop_contract_engine"
const ENGINE_VERSION:= 1
const SHOP_SCHEMA:= "eralife.artifact_shop_contract"
const SHOP_VERSION:= 1
const CACHE_KEY:= "artifact_shop_contract_cache"

var gs
var projection_cache: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	_ensure_cache()
	_bind_resident_shop_observation_inputs()
	_arm_resident_shop_observation_monitor()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	_ensure_cache()
	_bind_resident_shop_observation_inputs()
	_arm_resident_shop_observation_monitor()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_cache()
	_bind_resident_shop_observation_inputs()
	_arm_resident_shop_observation_monitor()

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"truth_authority": "artifacts_engine",
		"catalog_authority": "artifacts_catalog_contract_engine",
		"global_catalog_authority": "global_object_catalog_system",
		"interaction_authority": "artifact_interaction_contract_engine",
		"requires_input_idle": false,
		"uses_call_deferred": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(false)


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor"
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			"refresh"
		)
	).strip_edges().to_lower()
	var action_result: Dictionary = {
		"success": true
	}

	match action_id:
		"open", "refresh":
			pass

		"purchase", "purchase_artifact", "artifact_shop_buy":
			action_result = _purchase(
				actor,
				payload
			)

		"purchase_exchange_artifact":
			action_result = _purchase_exchange_artifact(
				actor,
				payload
			)

		"request_extraordinary_acquisition":
			action_result = _request_extraordinary_acquisition(
				actor,
				payload
			)

		"accept_extraordinary_acquisition":
			action_result = _accept_extraordinary_acquisition(
				actor,
				payload
			)

		"perform_action", "perform_self_action":
			action_result = _perform_action(
				actor,
				actor,
				payload
			)

		"perform_target_action":
			var target: Person = _person_by_id(
				int(
					payload.get(
						"target_id",
						-1
					)
				)
			)

			action_result = _perform_action(
				actor,
				target,
				payload
			)

		_:
			return _fail(
				"unsupported_artifact_shop_intent"
			)

	var exchange_only_intent: bool = action_id in [
		"purchase_exchange_artifact",
		"request_extraordinary_acquisition",
		"accept_extraordinary_acquisition"
	]
	var queue_report: Dictionary = {
		"success": true,
		"mode": "artifact_shop_projection_not_required",
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"build_on_click_forbidden": true,
		"ready_gate_member": false
	}

	if not exchange_only_intent:
		queue_report = queue_resident_shop_projection(
			actor,
			{
				"source": str(
					payload.get(
						"source",
						"artifact_shop_contract_engine.resolve_intent"
					)
				),
				"reason": (
					"artifact_shop_intent_%s"
					% action_id
				),
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"build_on_click_forbidden": true,
				"ready_gate_member": false
			}
		)

	var cached_raw: Variant = projection_cache.get(
		str(
			int(
				actor.id
			)
		),
		{}
	)
	var shop_contract: Dictionary = (
		(cached_raw as Dictionary).duplicate(false)
		if typeof(
			cached_raw
		) == TYPE_DICTIONARY
		else {}
	)

	return {
		"success": bool(
			action_result.get(
				"success",
				true
			)
		),
		"mode": "artifact_shop_intent_resolved",
		"action_id": action_id,
		"result": action_result,
		"shop_contract": shop_contract,
		"projection_queue_report": queue_report,
		"ui_is_renderer_only": true
	}
func _purchase_exchange_artifact(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"purchase_exchange_artifact"
		)
	):
		return _fail(
			"exchange_artifact_authority_unavailable"
		)

	var result: Dictionary = _safe_dictionary(
		gs.artifacts_engine.purchase_exchange_artifact(
			actor,
			str(
				payload.get(
					"item_id",
					""
				)
			),
			str(
				payload.get(
					"canonical_instance_id",
					""
				)
			)
		)
	)

	if (
		bool(
			result.get(
				"success",
				false
			)
		)
		and gs.narrative_engine != null
	):
		var diary_text: String = str(
			result.get(
				"diary_text",
				result.get(
					"text",
					""
				)
			)
		).strip_edges()

		if diary_text != "":
			gs.narrative_engine.log_event(
				actor,
				{
					"type": "text",
					"text": diary_text,
					"source": "artifact_shop_contract_engine",
					"category": "artifact",
					"event_name": "luxury_exchange_artifact_acquisition",
					"personally_relevant": (
						actor == gs.player
					),
					"suppress_world_feed": true
				}
			)

	return result


func _request_extraordinary_acquisition(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"request_extraordinary_exchange_artifact_acquisition"
		)
	):
		return _fail(
			"extraordinary_artifact_authority_unavailable"
		)

	var result: Dictionary = _safe_dictionary(
		gs.artifacts_engine.request_extraordinary_exchange_artifact_acquisition(
			actor,
			str(
				payload.get(
					"item_id",
					""
				)
			),
			str(
				payload.get(
					"canonical_instance_id",
					""
				)
			)
		)
	)

	if not bool(
		result.get(
			"success",
			false
		)
	):
		return result

	var price: int = int(
		result.get(
			"price",
			0
		)
	)
	var terms_id: String = str(
		result.get(
			"terms_id",
			""
		)
	)
	var artifact_name: String = str(
		result.get(
			"artifact_name",
			"Acrello’s MacBook"
		)
	)

	result [
		"extraordinary_presentation_card"
	] = {
		"card_id": (
			"extraordinary_terms:%s"
			% terms_id
		),
		"classification": "ONE OF ONE",
		"classification_display": "EXTRAORDINARY ACQUISITION",
		"title": "EXTRAORDINARY ACQUISITION",
		"house_text_override": (
			"The current custodian will accept your offer."
		),
		"ask_text_override": _format_money(
			price
		),
		"market_text_override": (
			"In addition, Artifact Authority requires the extinguishment "
			+ "of three randomly selected living members of your family lineage."
		),
		"rarity_text": (
			"The identities of those selected will not be disclosed "
			+ "until the acquisition becomes canonical."
		),
		"history_note": (
			"This transfer cannot be reversed."
		),
		"provenance_text_override": "",
		"lore": "",
		"acquisition_label": "ACCEPT TERMS",
		"acquisition_disabled": false,
		"acquisition_intent": {
			"action_id": "accept_extraordinary_acquisition",
			"payload": {
				"action_id": "accept_extraordinary_acquisition",
				"terms_id": terms_id,
				"source": "luxury_exchange.extraordinary_artifact_terms"
			},
			"target": {
				"route_kind": "engine_method",
				"engine_property": "artifact_shop_contract_engine",
				"method": "resolve_intent",
				"pass_actor_payload": true
			}
		},
		"leave_label": str(
			result.get(
				"leave_label",
				"LEAVE THE MACBOOK."
			)
		),
		"leave_intent": {},
		"lock_hover_projection": true,
		"artifact_name": artifact_name,
		"ui_is_renderer_only": true
	}

	result [
		"affects_market_projection"
	] = false

	return result


func _accept_extraordinary_acquisition(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"accept_extraordinary_exchange_artifact_acquisition"
		)
	):
		return _fail(
			"extraordinary_artifact_authority_unavailable"
		)

	var result: Dictionary = _safe_dictionary(
		gs.artifacts_engine.accept_extraordinary_exchange_artifact_acquisition(
			actor,
			str(
				payload.get(
					"terms_id",
					""
				)
			)
		)
	)

	if not bool(
		result.get(
			"success",
			false
		)
	):
		return result

	var presentation_raw: Variant = result.get(
		"presentation_lines",
		[]
	)
	var presentation_lines: Array = (
		presentation_raw as Array
		if typeof(
			presentation_raw
		) == TYPE_ARRAY
		else []
	)
	var receipt_text: String = ""

	for raw_line in presentation_lines:
		var line: String = str(
			raw_line
		).strip_edges()

		if line == "":
			continue

		if receipt_text != "":
			receipt_text += "\n\n"

		receipt_text += line

	result [
		"extraordinary_presentation_card"
	] = {
		"card_id": (
			"extraordinary_receipt:%s"
			% str(
				result.get(
					"terms_id",
					""
				)
			)
		),
		"classification": "ONE OF ONE",
		"classification_display": "◆ ONE OF ONE ◆",
		"title": str(
			result.get(
				"artifact_name",
				"Acrello’s MacBook"
			)
		),
		"house_text_override": (
			"The Sanctorum has accepted consideration."
		),
		"ask_text_override": "",
		"market_text_override": receipt_text,
		"rarity_text": "",
		"history_note": "",
		"provenance_text_override": "",
		"lore": "",
		"acquisition_intent": {},
		"leave_label": "RETURN TO EXCHANGE",
		"leave_intent": {
			"action_id": "refresh_exchange",
			"payload": {
				"action_id": "refresh_exchange",
				"source": "luxury_exchange.extraordinary_receipt_dismissed"
			},
			"target": {
				"route_kind": "engine_method",
				"engine_property": "luxury_shop_engine",
				"method": "resolve_intent",
				"pass_actor_payload": true
			}
		},
		"lock_hover_projection": true,
		"ui_is_renderer_only": true
	}

	result [
		"affects_market_projection"
	] = false

	var diary_text: String = str(
		result.get(
			"diary_text",
			""
		)
	).strip_edges()

	if (
		diary_text != ""
		and gs.narrative_engine != null
	):
		gs.narrative_engine.log_event(
			actor,
			{
				"type": "text",
				"text": diary_text,
				"source": "artifact_shop_contract_engine",
				"category": "artifact",
				"event_name": "extraordinary_artifact_acquisition",
				"personally_relevant": (
					actor == gs.player
				),
				"suppress_world_feed": true
			}
		)

	return result
func resident_shop_contract_for_actor(
	actor_id: int
) -> Dictionary:
	_ensure_cache()

	if actor_id <= 0:
		return {}

	var raw_contract: Variant = (
		projection_cache.get(
			str(actor_id),
			{}
		)
	)

	if typeof(raw_contract) != TYPE_DICTIONARY:
		return {}

	var contract: Dictionary = (
		raw_contract as Dictionary
	)

	if contract.is_empty():
		return {}

	return contract.duplicate(false)
func emit_shop_contract(
	actor: Person,
	_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	var stock: Array = []
	var object_rows: Array = []

	if gs != null and gs.artifacts_engine != null and gs.artifacts_engine.has_method("get_shop_inventory"):
		stock = _safe_array(gs.artifacts_engine.get_shop_inventory(actor))

	if gs != null and gs.artifacts_catalog_contract_engine != null:
		object_rows = gs.artifacts_catalog_contract_engine.get_available_objects({
			"actor_id": int(actor.id),
			"include_catalog_definitions": true,
			"include_owned_instances": false,
			"include_modded": true
		})

	var object_index: Dictionary = {}
	for raw_object in object_rows:
		if typeof(raw_object) != TYPE_DICTIONARY:
			continue
		var object_contract: Dictionary = raw_object as Dictionary
		var source: Dictionary = _safe_dictionary(object_contract.get("source_payload", {}))
		var source_id: String = str(source.get("id", source.get("shop_item_id", ""))).strip_edges().to_lower()
		if source_id != "":
			object_index [source_id] = object_contract.duplicate(true)

	var rows: Array = []
	for raw_entry in stock:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		var item_id: String = str(entry.get("id", "")).strip_edges().to_lower()
		entry ["object_contract"] = _safe_dictionary(object_index.get(item_id, {}))
		entry ["action_id"] = "purchase_artifact"
		entry ["action_payload"] = {
			"action_id": "purchase_artifact",
			"item_id": item_id
		}
		rows.append(entry)

	var contract: Dictionary = {
		"success": true,
		"schema": SHOP_SCHEMA,
		"version": SHOP_VERSION,
		"actor_id": int(actor.id),
		"funds": float(actor.bank_balance),
		"funds_display": _format_money(int(actor.bank_balance)),
		"rows": rows,
		"stock": rows,
		"stock_count": rows.size(),
		"owned_stone_count": owned_stone_count(actor),
		"owns_all_stones": actor_has_all_stones(actor),
		"artifact_signature": artifact_signature_for_actor(actor),
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(Time.get_ticks_msec())
	}
	projection_cache [str(int(actor.id))] = contract.duplicate(true)
	_sync_cache()
	return contract


func action_specs_for_item(
	_actor: Person,
	item: Dictionary
) -> Array:
	if (
		gs != null
		and gs.artifact_interaction_contract_engine != null
		and gs.artifact_interaction_contract_engine.has_method(
			"artifact_action_specs"
		)
	):
		return _safe_array(
			gs.artifact_interaction_contract_engine.artifact_action_specs(
				item
			)
		)
	return []

func owned_stone_count(
	actor: Person
) -> int:
	if actor == null:
		return 0
	if (
		gs != null
		and gs.artifact_interaction_contract_engine != null
		and gs.artifact_interaction_contract_engine.has_method(
			"emit_observability_contract"
		)
	):
		var contract: Dictionary = _safe_dictionary(
			gs.artifact_interaction_contract_engine.emit_observability_contract(
				actor
			)
		)
		return clampi(
			int(contract.get("owned_stone_count", 0)),
			0,
			6
		)
	return 0

func actor_has_all_stones(
	actor: Person
) -> bool:
	return owned_stone_count(actor) >= 6

func artifact_signature_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return "artifacts_none"
	if (
		gs != null
		and gs.artifact_interaction_contract_engine != null
		and gs.artifact_interaction_contract_engine.has_method(
			"emit_observability_contract"
		)
	):
		var contract: Dictionary = _safe_dictionary(
			gs.artifact_interaction_contract_engine.emit_observability_contract(
				actor
			)
		)
		return str(
			contract.get("artifact_signature", "artifacts_none")
		)
	return "artifacts_unavailable"

func market_profile_for_item(
	actor: Person,
	item: Dictionary
) -> Dictionary:
	if (
		gs != null
		and gs.artifact_interaction_contract_engine != null
		and gs.artifact_interaction_contract_engine.has_method(
			"artifact_market_profile"
		)
	):
		return _safe_dictionary(
			gs.artifact_interaction_contract_engine.artifact_market_profile(
				actor,
				item
			)
		)
	return {}

func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"projection_cache": projection_cache.duplicate(true),
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	projection_cache = _safe_dictionary(data.get("projection_cache", {}))
	_sync_cache()
	return {
		"success": true,
		"mode": "artifact_shop_projection_cache_imported",
		"cache_count": projection_cache.size()
	}


func _purchase(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.artifacts_engine == null
	):
		return _fail(
			"artifacts_engine_unavailable"
		)

	if not gs.artifacts_engine.has_method(
		"purchase_shop_item"
	):
		return _fail(
			"artifact_purchase_method_unavailable"
		)

	var result_raw: Variant = (
		gs.artifacts_engine.purchase_shop_item(
			actor,
			str(
				payload.get(
					"item_id",
					""
				)
			)
		)
	)
	var result: Dictionary = _safe_dictionary(
		result_raw
	)



	if (
		bool(
			result.get(
				"success",
				false
			)
		)
		and gs.narrative_engine != null
	):
		var diary_text: String = str(
			result.get(
				"text",
				""
			)
		).strip_edges()

		if diary_text != "":
			gs.narrative_engine.log_event(
				actor,
				{
					"type": "text",
					"text": diary_text,
					"source": "artifact_shop_contract_engine",
					"category": "artifact",
					"event_name": "artifact_shop_purchase",
					"personally_relevant": (
						actor == gs.player
					),
					"suppress_world_feed": true
				}
			)

	return result

func _perform_action(
	actor: Person,
	target: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.artifact_interaction_contract_engine == null
	):
		return _fail("artifact_interaction_contract_engine_unavailable")

	var routed_payload: Dictionary = payload.duplicate(true)
	routed_payload ["action_id"] = (
		"perform_self_action"
		if target == actor
		else "perform_target_action"
	)
	routed_payload ["target_id"] = int(target.id) if target != null else -1

	return _safe_dictionary(
		gs.artifact_interaction_contract_engine.resolve_intent(
			actor,
			routed_payload
		)
	)

func _format_money(
	amount: int
) -> String:
	if (
		gs != null
		and gs.economy_engine != null
		and gs.economy_engine.has_method("format_money")
	):
		return str(
			gs.economy_engine.format_money(
				amount
			)
		)
	return str(amount)


func _person_has_stone(
	actor: Person,
	stone_name: String
) -> bool:
	if actor == null:
		return false
	if gs != null and gs.artifacts_engine != null and gs.artifacts_engine.has_method("person_has_stone"):
		return bool(gs.artifacts_engine.person_has_stone(actor, stone_name))
	if gs != null and gs.belongings_engine != null:
		return gs.belongings_engine.has_item_named(
			actor,
			"Artifacts",
			"%s Infinity Stone" % stone_name
		)
	return false


func _person_by_id(
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
		var found: Variant = gs.get_npc_by_id(
			person_id,
			false
		)

		if found is Person:
			return found as Person

	return null


func _ensure_cache() -> void:
	if projection_cache.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		projection_cache = _safe_dictionary(gs.scenario_state.get(CACHE_KEY, {}))
	_sync_cache()


func _sync_cache() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}




	gs.scenario_state [
		CACHE_KEY
	] = projection_cache.duplicate(false)
func _bind_resident_shop_observation_inputs() -> void:
	if (
		gs == null
		or gs.event_bus == null
		or not gs.event_bus.has_method(
			"subscribe"
		)
	):
		return

	var event_bus_instance_id: int = int(
		gs.event_bus.get_instance_id()
	)

	if int(
		get_meta(
			"artifact_shop_bound_event_bus_instance_id",
			-1
		)
	) == event_bus_instance_id:
		return

	gs.event_bus.subscribe(
		"belongings.event",
		self,
		"_on_artifact_shop_belongings_event"
	)

	set_meta(
		"artifact_shop_bound_event_bus_instance_id",
		event_bus_instance_id
	)


func _on_artifact_shop_belongings_event(
	packet: Dictionary
) -> void:
	if (
		gs == null
		or gs.player == null
	):
		return

	if int(
		packet.get(
			"owner_id",
			-1
		)
	) != int(
		gs.player.id
	):
		return

	queue_resident_shop_projection(
		gs.player,
		{
			"source": (
				"artifact_shop_contract_engine."
				+ "belongings_event"
			),
			"reason": "controlled_actor_belongings_changed",
			"background_only": true,
			"blocks_ui": false,
			"requires_input_idle": false,
			"ready_gate_member": false
		}
	)


func _arm_resident_shop_observation_monitor() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()

	if not (
		main_loop is SceneTree
	):
		return

	var tree: SceneTree = (
		main_loop as SceneTree
	)
	var callback:= Callable(
		self,
		"_drive_resident_shop_observation_monitor"
	)

	if tree.process_frame.is_connected(
		callback
	):
		return



	tree.process_frame.connect(
		callback
	)

	set_meta(
		"artifact_shop_observation_monitor_active",
		true
	)
	set_meta(
		"artifact_shop_observation_monitor_requires_input_idle",
		false
	)
	set_meta(
		"artifact_shop_observation_monitor_uses_call_deferred",
		false
	)


func _drive_resident_shop_observation_monitor() -> void:



	if posmod(
		int(
			Engine.get_process_frames()
		),
		4
	) != 0:
		return

	_bind_resident_shop_observation_inputs()

	if (
		gs == null
		or gs.player == null
	):
		return

	var actor: Person = gs.player
	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return

	var observation_frontier: String = (
		"%d:%d:%d"
		% [
			actor_id,
			int(
				gs.year
			),
			int(
				round(
					float(
						actor.bank_balance
					)
				)
			)
		]
	)

	if observation_frontier == str(
		get_meta(
			"artifact_shop_last_observation_frontier",
			""
		)
	):
		return

	set_meta(
		"artifact_shop_last_observation_frontier",
		observation_frontier
	)

	queue_resident_shop_projection(
		actor,
		{
			"source": (
				"artifact_shop_contract_engine."
				+ "continuous_resident_observation"
			),
			"reason": "controlled_actor_frontier_changed",
			"background_only": true,
			"blocks_ui": false,
			"requires_input_idle": false,
			"ready_gate_member": false
		}
	)


func queue_resident_shop_projection(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": "missing_actor_or_game_state"
		}

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	var generation: int = int(
		get_meta(
			"artifact_shop_projection_generation",
			0
		)
	) + 1

	set_meta(
		"artifact_shop_projection_generation",
		generation
	)

	var jobs_raw: Variant = get_meta(
		"artifact_shop_resident_projection_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(
			jobs_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var order_raw: Variant = get_meta(
		"artifact_shop_resident_projection_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)

	var actor_key: String = str(
		actor_id
	)

	jobs [
		actor_key
	] = {
		"actor_id": actor_id,
		"generation": generation,
		"phase": "header",
		"cursor": 0,
		"rows": [],
		"context": context.duplicate(false),
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if not order.has(
		actor_key
	):
		order.append(
			actor_key
		)

	set_meta(
		"artifact_shop_resident_projection_jobs",
		jobs
	)
	set_meta(
		"artifact_shop_resident_projection_order",
		order
	)

	_arm_resident_shop_projection_service()

	return {
		"success": true,
		"queued": true,
		"actor_id": actor_id,
		"generation": generation,
		"queue_size": order.size(),
		"blocks_ui": false,
		"requires_input_idle": false,
		"uses_call_deferred": false,
		"ready_gate_member": false
	}


func _arm_resident_shop_projection_service() -> void:
	var order_raw: Variant = get_meta(
		"artifact_shop_resident_projection_order",
		[]
	)
	var order: Array = (
		order_raw as Array
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"artifact_shop_resident_projection_service_active",
			false
		)
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (
		main_loop is SceneTree
	):
		return

	var tree: SceneTree = (
		main_loop as SceneTree
	)
	var callback:= Callable(
		self,
		"_drive_resident_shop_projection_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		set_meta(
			"artifact_shop_resident_projection_service_active",
			true
		)
		return

	tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT
	)

	set_meta(
		"artifact_shop_resident_projection_service_active",
		true
	)


func _drive_resident_shop_projection_process_frame() -> void:
	set_meta(
		"artifact_shop_resident_projection_service_active",
		false
	)

	_service_resident_shop_projection_quantum()
	_arm_resident_shop_projection_service()


func _publish_resident_shop_observation(
	actor_id: int,
	packet: Dictionary
) -> bool:
	if (
		gs == null
		or actor_id <= 0
		or packet.is_empty()
		or gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"publish_resident_continuous_observation"
		)
	):
		return false

	gs.reality_projection_contract_engine.publish_resident_continuous_observation(
		"artifact_shop:%d" % actor_id,
		packet
	)

	return true


func _service_resident_shop_projection_quantum() -> void:
	var order_raw: Variant = get_meta(
		"artifact_shop_resident_projection_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		return

	var jobs_raw: Variant = get_meta(
		"artifact_shop_resident_projection_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(
			jobs_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var actor_key: String = str(
		order.pop_front()
	)
	var job_raw: Variant = jobs.get(
		actor_key,
		{}
	)
	var job: Dictionary = (
		(job_raw as Dictionary).duplicate(false)
		if typeof(
			job_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		jobs.erase(
			actor_key
		)
		set_meta(
			"artifact_shop_resident_projection_order",
			order
		)
		set_meta(
			"artifact_shop_resident_projection_jobs",
			jobs
		)
		return

	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var actor: Person = _person_by_id(
		actor_id
	)

	if actor == null:
		jobs.erase(
			actor_key
		)
		set_meta(
			"artifact_shop_resident_projection_order",
			order
		)
		set_meta(
			"artifact_shop_resident_projection_jobs",
			jobs
		)
		return



	if (
		gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"publish_resident_continuous_observation"
		)
	):
		jobs [
			actor_key
		] = job
		order.append(
			actor_key
		)
		set_meta(
			"artifact_shop_resident_projection_order",
			order
		)
		set_meta(
			"artifact_shop_resident_projection_jobs",
			jobs
		)
		return

	var generation: int = int(
		job.get(
			"generation",
			0
		)
	)
	var phase: String = str(
		job.get(
			"phase",
			"header"
		)
	).strip_edges().to_lower()
	var complete: bool = false

	match phase:
		"header":
			var slot_count: int = 0

			if (
				gs.artifacts_engine != null
				and gs.artifacts_engine.has_method(
					"shop_inventory_slot_count"
				)
			):
				slot_count = int(
					gs.artifacts_engine.shop_inventory_slot_count()
				)

			_publish_resident_shop_observation(
				actor_id,
				{
					"schema": "eralife.artifact_shop_observation",
					"version": 1,
					"observation_channel": "artifact_shop",
					"phase": "header",
					"actor_id": actor_id,
					"generation": generation,
					"funds": float(
						actor.bank_balance
					),
					"funds_display": (
						_format_money(
							int(
								actor.bank_balance
							)
						)
					),
					"catalog_slot_count": slot_count,
					"projection_complete": false,
					"background_only": true,
					"blocks_ui": false,
					"requires_input_idle": false,
					"ui_is_renderer_only": true
				}
			)

			job [
				"phase"
			] = "rows"

		"rows":
			var slot_count: int = 0

			if (
				gs.artifacts_engine != null
				and gs.artifacts_engine.has_method(
					"shop_inventory_slot_count"
				)
			):
				slot_count = int(
					gs.artifacts_engine.shop_inventory_slot_count()
				)

			var cursor: int = int(
				job.get(
					"cursor",
					0
				)
			)

			if cursor >= slot_count:
				job [
					"phase"
				] = "complete"
			else:
				var entry: Dictionary = {}

				if (
					gs.artifacts_engine != null
					and gs.artifacts_engine.has_method(
						"shop_inventory_entry_at"
					)
				):
					entry = (
						gs.artifacts_engine.shop_inventory_entry_at(
							actor,
							cursor
						)
					)

				job [
					"cursor"
				] = cursor + 1

				if not entry.is_empty():
					if (
						gs.artifacts_catalog_contract_engine != null
						and gs.artifacts_catalog_contract_engine.has_method(
							"object_contract_for_shop_entry"
						)
					):
						entry [
							"object_contract"
						] = (
							gs.artifacts_catalog_contract_engine
							.object_contract_for_shop_entry(
								entry,
								{
									"actor_id": actor_id,
									"source": (
										"artifact_shop_contract_engine."
										+ "resident_catalog_projection"
									),
									"projection_read_only": true,
									"ui_is_renderer_only": true
								}
							)
						)

					var item_id: String = str(
						entry.get(
							"id",
							""
						)
					).strip_edges().to_lower()

					entry [
						"action_id"
					] = "purchase_artifact"
					entry [
						"action_payload"
					] = {
						"action_id": "purchase_artifact",
						"item_id": item_id
					}

					var rows_raw: Variant = job.get(
						"rows",
						[]
					)
					var rows: Array = (
						(rows_raw as Array).duplicate(false)
						if typeof(
							rows_raw
						) == TYPE_ARRAY
						else []
					)

					rows.append(
						entry
					)
					job [
						"rows"
					] = rows

					_publish_resident_shop_observation(
						actor_id,
						{
							"schema": "eralife.artifact_shop_observation",
							"version": 1,
							"observation_channel": "artifact_shop",
							"phase": "row",
							"actor_id": actor_id,
							"generation": generation,
							"slot_index": cursor,
							"row_index": rows.size() - 1,
							"row": entry,
							"projection_complete": false,
							"background_only": true,
							"blocks_ui": false,
							"requires_input_idle": false,
							"ui_is_renderer_only": true
						}
					)

				if cursor + 1 >= slot_count:
					job [
						"phase"
					] = "complete"

		"complete":
			var rows_raw: Variant = job.get(
				"rows",
				[]
			)
			var rows: Array = (
				(rows_raw as Array).duplicate(false)
				if typeof(
					rows_raw
				) == TYPE_ARRAY
				else []
			)
			var stone_count: int = owned_stone_count(
				actor
			)
			var contract: Dictionary = {
				"success": true,
				"schema": SHOP_SCHEMA,
				"version": SHOP_VERSION,
				"actor_id": actor_id,
				"generation": generation,
				"funds": float(
					actor.bank_balance
				),
				"funds_display": _format_money(
					int(
						actor.bank_balance
					)
				),
				"rows": rows,
				"stock": rows,
				"stock_count": rows.size(),
				"owned_stone_count": stone_count,
				"owns_all_stones": (
					stone_count >= 6
				),
				"artifact_signature": (
					artifact_signature_for_actor(
						actor
					)
				),
				"truth_state": "hot",
				"projection_composed": true,
				"hydrated": true,
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"ui_is_renderer_only": true,
				"generated_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			projection_cache [
				actor_key
			] = contract.duplicate(false)

			_sync_cache()

			_publish_resident_shop_observation(
				actor_id,
				{
					"schema": "eralife.artifact_shop_observation",
					"version": 1,
					"observation_channel": "artifact_shop",
					"phase": "complete",
					"actor_id": actor_id,
					"generation": generation,
					"shop_contract": contract,
					"stock_count": rows.size(),
					"projection_complete": true,
					"background_only": true,
					"blocks_ui": false,
					"requires_input_idle": false,
					"ui_is_renderer_only": true
				}
			)

			complete = true

		_:
			complete = true

	if complete:
		jobs.erase(
			actor_key
		)
	else:
		jobs [
			actor_key
		] = job
		order.append(
			actor_key
		)

	set_meta(
		"artifact_shop_resident_projection_order",
		order
	)
	set_meta(
		"artifact_shop_resident_projection_jobs",
		jobs
	)
	set_meta(
		"artifact_shop_resident_projection_last_actor_id",
		actor_id
	)
	set_meta(
		"artifact_shop_resident_projection_last_phase",
		phase
	)
	set_meta(
		"artifact_shop_resident_projection_one_slot_per_frame",
		true
	)
	set_meta(
		"artifact_shop_resident_projection_requires_input_idle",
		false
	)
	set_meta(
		"artifact_shop_resident_projection_uses_call_deferred",
		false
	)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"mode": "artifact_shop_contract_rejected",
		"ui_is_renderer_only": true
	}