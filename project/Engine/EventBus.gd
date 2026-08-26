extends Resource
class_name EventBus

var gs
var subscribers:= {}
var contract_layer
var _deferred_delivery_service_armed: bool = false
var _event_seq: int = 0
var _deferred_batch_receipts: Dictionary = {}

const _DEFERRED_BATCH_RECEIPT_HARD_LIMIT:= 128
const _DEFERRED_BATCH_RECEIPT_RETAIN_LIMIT:= 96


var _deferred_deliveries: Dictionary = {}


var _deferred_delivery_index: Dictionary = {}

var _deferred_delivery_head: int = 0
var _deferred_delivery_tail: int = 0

const _DEFERRED_BATCH_PREVIEW_LIMIT:= 6
const _MAX_DEFERRED_HANDLERS_PER_FLUSH:= 64
const _DEFERRED_QUEUE_SOFT_LIMIT:= 96

func _init(_gs):
	gs = _gs
	contract_layer = EventBusContractLayer.new(gs, self)


func configure_from_contract(contract: Dictionary = {}) -> Dictionary:
	if contract_layer == null:
		contract_layer = EventBusContractLayer.new(gs, self)
	if contract_layer.has_method("configure"):
		return contract_layer.configure(contract)
	return {
		"schema": "eralife.event_bus_configure_report",
		"reason": "EventBusContractLayer missing configure()."
	}




func subscribe(event_type: String, target: Object, method_name: String, options:= {}):
	var normalized_event_type: String = str(event_type).strip_edges()
	var normalized_method_name: String = str(method_name).strip_edges()

	if normalized_event_type == "" or target == null or normalized_method_name == "":
		return

	if contract_layer != null and contract_layer.has_method("resolve_event_type"):
		normalized_event_type = str(contract_layer.resolve_event_type(normalized_event_type)).strip_edges()

	if not subscribers.has(normalized_event_type):
		subscribers [normalized_event_type] = []

	var normalized_options: Dictionary = options if typeof(options) == TYPE_DICTIONARY else {}
	if contract_layer != null and contract_layer.has_method("normalize_subscription_options"):
		normalized_options = contract_layer.normalize_subscription_options(normalized_event_type, normalized_options)

	var subscriber_key: String = _build_subscriber_key(target, normalized_method_name)

	for i in range(subscribers [normalized_event_type].size()):
		var existing_raw: Variant = subscribers [normalized_event_type] [i]
		var existing: Dictionary = existing_raw if typeof(existing_raw) == TYPE_DICTIONARY else {}
		if str(existing.get("subscriber_key", "")) == subscriber_key:
			var merged: Dictionary = existing.duplicate(true)
			for key in normalized_options.keys():
				merged [key] = normalized_options.get(key)
			merged ["target"] = target
			merged ["method"] = normalized_method_name
			merged ["allow_defer"] = bool(merged.get("allow_defer", true))
			merged ["force_immediate"] = bool(merged.get("force_immediate", false))
			merged ["subscriber_key"] = subscriber_key
			merged ["duplicate_suppressed_at_ms"] = int(Time.get_ticks_msec())
			subscribers [normalized_event_type] [i] = merged
			return

	var sub:= {
		"target": target,
		"method": normalized_method_name,
		"allow_defer": bool(normalized_options.get("allow_defer", true)),
		"force_immediate": bool(normalized_options.get("force_immediate", false)),
		"subscriber_key": subscriber_key,
		"lane": str(normalized_options.get("lane", normalized_options.get("dispatch_lane", ""))).strip_edges(),
		"subscription_id": str(normalized_options.get("subscription_id", subscriber_key)).strip_edges(),
		"subscription_priority": int(normalized_options.get("subscription_priority", normalized_options.get("priority", 100))),
		"replay_on_subscribe": bool(normalized_options.get("replay_on_subscribe", false))
	}

	subscribers [normalized_event_type].append(sub)
	subscribers [normalized_event_type].sort_custom(func (a, b): return int(a.get("subscription_priority", 100)) < int(b.get("subscription_priority", 100)))

	if bool(sub.get("replay_on_subscribe", false)):
		_replay_to_subscriber(normalized_event_type, sub)




func _normalize_payload(
	event_type: String,
	payload,
	contract_gate: Dictionary = {}
) -> Dictionary:
	var raw: Dictionary = {}

	if typeof(payload) == TYPE_DICTIONARY:


		raw = payload.duplicate(false)
	else:
		raw = { "value": payload}

	_event_seq += 1

	var normalized:= {
		"event_name": event_type,
		"event_id": _event_seq,
		"event_uid": str(
			contract_gate.get(
				"event_uid",
				raw.get(
					"event_uid",
					""
				)
			)
		),
		"lineage_id": str(
			contract_gate.get(
				"lineage_id",
				raw.get(
					"lineage_id",
					""
				)
			)
		),
		"parent_event_uid": str(
			contract_gate.get(
				"parent_event_uid",
				raw.get(
					"parent_event_uid",
					""
				)
			)
		),
		"lineage_depth": int(
			contract_gate.get(
				"lineage_depth",
				raw.get(
					"lineage_depth",
					0
				)
			)
		),
		"dispatch_lane": str(
			contract_gate.get(
				"dispatch_lane",
				raw.get(
					"dispatch_lane",
					raw.get(
						"lane",
						""
					)
				)
			)
		),
		"schema_valid": (
			bool(
				contract_gate.get(
					"schema_report",
					{}
				).get(
					"valid",
					true
				)
			)
			if typeof(
				contract_gate.get(
					"schema_report",
					{}
				)
			) == TYPE_DICTIONARY
			else true
		),
		"schema_report": (
			contract_gate.get(
				"schema_report",
				{}
			).duplicate(false)
			if typeof(
				contract_gate.get(
					"schema_report",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"contract_id": (
			str(
				contract_gate.get(
					"event_contract",
					{}
				).get(
					"contract_id",
					""
				)
			)
			if typeof(
				contract_gate.get(
					"event_contract",
					{}
				)
			) == TYPE_DICTIONARY
			else ""
		),
		"year": gs.year if gs != null else 0,
		"era": (
			gs.era.name
			if gs != null and gs.era != null
			else ""
		),
		"source": raw.get(
			"source",
			"event_bus"
		),
		"text": raw.get(
			"text",
			""
		),
		"npc_id": raw.get(
			"npc_id",
			-1
		),
		"data": raw.duplicate(false)
	}

	for key in raw.keys():
		normalized [key] = raw [key]

	return _apply_qos_defaults(
		normalized
	)





func get_event_name(payload: Dictionary) -> String:
	return payload.get("event_name", "")


func get_event_data(payload: Dictionary) -> Dictionary:
	return payload.get("data", {})


func get_npc(payload: Dictionary):
	var npc_id = payload.get("npc_id", -1)
	if gs == null or npc_id == -1:
		return null
	return gs.get_npc_by_id(npc_id)


func get_contract_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}

	if (
		contract_layer != null
		and contract_layer.has_method(
			"export_debug_snapshot"
		)
	):
		snapshot = (
			contract_layer.export_debug_snapshot()
		)

	snapshot [
		"pending_deferred_count"
	] = get_pending_deferred_delivery_count()
	snapshot [
		"deferred_index_count"
	] = _deferred_delivery_index.size()
	snapshot [
		"deferred_queue_soft_limit"
	] = _DEFERRED_QUEUE_SOFT_LIMIT
	snapshot [
		"deferred_max_handlers_per_flush"
	] = _MAX_DEFERRED_HANDLERS_PER_FLUSH
	snapshot [
		"deferred_mailbox_head"
	] = _deferred_delivery_head
	snapshot [
		"deferred_mailbox_tail"
	] = _deferred_delivery_tail
	snapshot [
		"deferred_mailbox_o1_consumption"
	] = true

	return snapshot

func _build_subscriber_key(target: Object, method_name: String) -> String:
	if target == null:
		return "null|%s" % method_name
	return "%s|%s|%s" % [
		str(target.get_class()),
		str(target.get_instance_id()),
		method_name
	]

func _deferred_batch_key_from_payload(
	payload: Dictionary
) -> String:
	var fanout_hints_raw: Variant = payload.get(
		"fanout_hints",
		{}
	)
	var fanout_hints: Dictionary = (
		fanout_hints_raw as Dictionary
		if typeof(fanout_hints_raw) == TYPE_DICTIONARY
		else {}
	)

	return str(
		fanout_hints.get(
			"event_batch_key",
			payload.get(
				"event_batch_key",
				""
			)
		)
	).strip_edges()


func _begin_deferred_batch_tracking(
	event_type: String,
	payload: Dictionary
) -> void:
	var batch_key: String = _deferred_batch_key_from_payload(
		payload
	)

	if batch_key == "":
		return

	var existing_raw: Variant = _deferred_batch_receipts.get(
		batch_key,
		{}
	)
	var existing: Dictionary = (
		existing_raw as Dictionary
		if typeof(existing_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		not existing.is_empty()
		and not bool(
			existing.get(
				"is_complete",
				false
			)
		)
	):
		existing ["emit_count"] = int(
			existing.get(
				"emit_count",
				1
			)
		) + 1
		existing ["duplicate_emit_detected"] = true

		_deferred_batch_receipts [
			batch_key
		] = existing
		return

	_deferred_batch_receipts [
		batch_key
	] = {
		"schema": "eralife.event_bus_deferred_batch_receipt",
		"version": 1,
		"batch_key": batch_key,
		"event_type": event_type,
		"event_id": int(
			payload.get(
				"event_id",
				-1
			)
		),
		"event_uid": str(
			payload.get(
				"event_uid",
				""
			)
		),
		"year": int(
			payload.get(
				"year",
				gs.year
				if gs != null
				else 0
			)
		),
		"emit_count": 1,
		"duplicate_emit_detected": false,
		"fanout_scheduling_complete": false,
		"queued_handlers": 0,
		"settled_handlers": 0,
		"delivered_handlers": 0,
		"dropped_handlers": 0,
		"pending_handlers": 0,
		"is_complete": false,
		"started_at_ms": int(
			Time.get_ticks_msec()
		),
		"completed_at_ms": 0
	}


func _note_deferred_batch_delivery_queued(
	payload: Dictionary
) -> void:
	var batch_key: String = _deferred_batch_key_from_payload(
		payload
	)

	if batch_key == "":
		return

	var receipt_raw: Variant = _deferred_batch_receipts.get(
		batch_key,
		{}
	)
	if typeof(receipt_raw) != TYPE_DICTIONARY:
		return

	var receipt: Dictionary = (
		receipt_raw as Dictionary
	)

	receipt ["queued_handlers"] = int(
		receipt.get(
			"queued_handlers",
			0
		)
	) + 1
	receipt ["pending_handlers"] = int(
		receipt.get(
			"pending_handlers",
			0
		)
	) + 1
	receipt ["is_complete"] = false

	_deferred_batch_receipts [
		batch_key
	] = receipt


func _finalize_deferred_batch_tracking(
	payload: Dictionary
) -> void:
	var batch_key: String = _deferred_batch_key_from_payload(
		payload
	)

	if batch_key == "":
		return

	var receipt_raw: Variant = _deferred_batch_receipts.get(
		batch_key,
		{}
	)
	if typeof(receipt_raw) != TYPE_DICTIONARY:
		return

	var receipt: Dictionary = (
		receipt_raw as Dictionary
	)

	receipt ["fanout_scheduling_complete"] = true

	if int(
		receipt.get(
			"pending_handlers",
			0
		)
	) <= 0:
		receipt ["pending_handlers"] = 0
		receipt ["is_complete"] = true
		receipt ["completed_at_ms"] = int(
			Time.get_ticks_msec()
		)

	_deferred_batch_receipts [
		batch_key
	] = receipt

	_prune_deferred_batch_receipts()


func _settle_deferred_batch_delivery(
	payload: Dictionary,
	delivered_ok: bool
) -> void:
	var batch_key: String = _deferred_batch_key_from_payload(
		payload
	)

	if batch_key == "":
		return

	var receipt_raw: Variant = _deferred_batch_receipts.get(
		batch_key,
		{}
	)
	if typeof(receipt_raw) != TYPE_DICTIONARY:
		return

	var receipt: Dictionary = (
		receipt_raw as Dictionary
	)

	receipt ["settled_handlers"] = int(
		receipt.get(
			"settled_handlers",
			0
		)
	) + 1
	receipt ["pending_handlers"] = maxi(
		0,
		int(
			receipt.get(
				"pending_handlers",
				0
			)
		) - 1
	)

	if delivered_ok:
		receipt ["delivered_handlers"] = int(
			receipt.get(
				"delivered_handlers",
				0
			)
		) + 1
	else:
		receipt ["dropped_handlers"] = int(
			receipt.get(
				"dropped_handlers",
				0
			)
		) + 1

	if (
		bool(
			receipt.get(
				"fanout_scheduling_complete",
				false
			)
		)
		and int(
			receipt.get(
				"pending_handlers",
				0
			)
		) <= 0
	):
		receipt ["pending_handlers"] = 0
		receipt ["is_complete"] = true
		receipt ["completed_at_ms"] = int(
			Time.get_ticks_msec()
		)

	_deferred_batch_receipts [
		batch_key
	] = receipt

	_prune_deferred_batch_receipts()


func _prune_deferred_batch_receipts() -> void:
	if (
		_deferred_batch_receipts.size()
		<= _DEFERRED_BATCH_RECEIPT_HARD_LIMIT
	):
		return

	for raw_key in _deferred_batch_receipts.keys():
		if (
			_deferred_batch_receipts.size()
			<= _DEFERRED_BATCH_RECEIPT_RETAIN_LIMIT
		):
			break

		var receipt_raw: Variant = _deferred_batch_receipts.get(
			raw_key,
			{}
		)
		var receipt: Dictionary = (
			receipt_raw as Dictionary
			if typeof(receipt_raw) == TYPE_DICTIONARY
			else {}
		)

		if bool(
			receipt.get(
				"is_complete",
				false
			)
		):
			_deferred_batch_receipts.erase(
				raw_key
			)


func get_deferred_batch_receipt(
	batch_key: String
) -> Dictionary:
	var clean_key: String = str(
		batch_key
	).strip_edges()

	if clean_key == "":
		return {}

	var receipt_raw: Variant = _deferred_batch_receipts.get(
		clean_key,
		{}
	)

	return (
		(receipt_raw as Dictionary).duplicate(false)
		if typeof(receipt_raw) == TYPE_DICTIONARY
		else {}
	)
func _resolve_payload_qos_tier(payload: Dictionary) -> String:
	var explicit_qos: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
	if explicit_qos in ["critical", "important", "ambient"]:
		return explicit_qos

	var dispatch_lane: String = str(payload.get("dispatch_lane", payload.get("lane", ""))).strip_edges().to_lower()
	if dispatch_lane in ["critical", "important", "ambient"]:
		return dispatch_lane

	var fanout_priority: String = str(payload.get("fanout_priority", "")).strip_edges().to_lower()
	if fanout_priority in ["critical", "high"]:
		return "critical"
	if fanout_priority in ["ambient", "low"]:
		return "ambient"

	if bool(payload.get("player_relevant", false)):
		return "critical"

	return "important"


func _apply_qos_defaults(
	payload: Dictionary
) -> Dictionary:
	var normalized: Dictionary = payload.duplicate(false)

	var qos_tier: String = _resolve_payload_qos_tier(
		normalized
	)
	normalized [
		"qos_tier"
	] = qos_tier

	match qos_tier:
		"critical":
			normalized ["fanout_priority"] = "high"
		"important":
			normalized ["fanout_priority"] = "normal"
		"ambient":
			normalized ["fanout_priority"] = "low"
		_:
			normalized ["fanout_priority"] = "normal"

	var fanout_hints_raw: Variant = normalized.get(
		"fanout_hints",
		{}
	)
	var fanout_hints: Dictionary = (
		(fanout_hints_raw as Dictionary).duplicate(false)
		if typeof(fanout_hints_raw) == TYPE_DICTIONARY
		else {}
	)

	match qos_tier:
		"critical":
			fanout_hints ["skip_agent_memory_propagation"] = bool(
				fanout_hints.get(
					"skip_agent_memory_propagation",
					false
				)
			)
			fanout_hints ["skip_npc_memory_web"] = bool(
				fanout_hints.get(
					"skip_npc_memory_web",
					false
				)
			)
			fanout_hints ["skip_llm_bridge"] = bool(
				fanout_hints.get(
					"skip_llm_bridge",
					false
				)
			)
			fanout_hints ["skip_reputation"] = bool(
				fanout_hints.get(
					"skip_reputation",
					false
				)
			)
			fanout_hints ["allow_partial_propagation"] = false

		"important":
			fanout_hints ["skip_agent_memory_propagation"] = bool(
				fanout_hints.get(
					"skip_agent_memory_propagation",
					false
				)
			)
			fanout_hints ["skip_npc_memory_web"] = bool(
				fanout_hints.get(
					"skip_npc_memory_web",
					false
				)
			)
			fanout_hints ["skip_llm_bridge"] = bool(
				fanout_hints.get(
					"skip_llm_bridge",
					false
				)
			)
			fanout_hints ["skip_reputation"] = bool(
				fanout_hints.get(
					"skip_reputation",
					false
				)
			)
			fanout_hints ["allow_partial_propagation"] = true

		"ambient":
			fanout_hints ["skip_agent_memory_propagation"] = bool(
				fanout_hints.get(
					"skip_agent_memory_propagation",
					true
				)
			)
			fanout_hints ["skip_npc_memory_web"] = bool(
				fanout_hints.get(
					"skip_npc_memory_web",
					true
				)
			)
			fanout_hints ["skip_llm_bridge"] = bool(
				fanout_hints.get(
					"skip_llm_bridge",
					true
				)
			)
			fanout_hints ["skip_reputation"] = bool(
				fanout_hints.get(
					"skip_reputation",
					true
				)
			)
			fanout_hints ["allow_partial_propagation"] = false

		_:
			fanout_hints [
				"allow_partial_propagation"
			] = false

	normalized [
		"fanout_hints"
	] = fanout_hints

	return normalized


func _get_runtime_guard() -> Dictionary:
	var out: Dictionary = {}

	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return out

	var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
	if typeof(guard_raw) == TYPE_DICTIONARY:
		out.merge(guard_raw as Dictionary, true)

	var contract_guard_raw: Variant = gs.scenario_state.get("game_state_contract_runtime_guard", {})
	if typeof(contract_guard_raw) == TYPE_DICTIONARY:
		out.merge(contract_guard_raw as Dictionary, true)

	return out


func _runtime_prefers_deferred_delivery() -> bool:
	var guard: Dictionary = _get_runtime_guard()
	var now_ms: int = int(Time.get_ticks_msec())

	var ui_grace_until_ms: int = int(guard.get("ui_interaction_grace_until_ms", 0))
	var post_tail_until_ms: int = int(guard.get("post_age_up_tail_settle_until_ms", 0))

	return (
		bool(guard.get("defer_noncritical_systems", false))
		or bool(guard.get("reduce_scenario_density", false))
		or bool(guard.get("compressed_execution_current_year", false))
		or bool(guard.get("auto_stability_mode", false))
		or bool(guard.get("ui_tail_work_yield_to_input", false))
		or now_ms < ui_grace_until_ms
		or now_ms < post_tail_until_ms
	)


func _should_defer_delivery(
	payload: Dictionary,
	sub: Dictionary
) -> bool:
	if (
		contract_layer != null
		and contract_layer.has_method(
			"should_defer_delivery"
		)
	):
		var lane_decision: Dictionary = (
			contract_layer.should_defer_delivery(
				payload,
				sub
			)
		)

		if bool(
			lane_decision.get(
				"decided",
				false
			)
		):
			return bool(
				lane_decision.get(
					"defer",
					false
				)
			)

	if bool(
		sub.get(
			"force_immediate",
			false
		)
	):
		return false

	if not bool(
		sub.get(
			"allow_defer",
			true
		)
	):
		return false

	var qos_tier: String = (
		_resolve_payload_qos_tier(
			payload
		)
	)


	if qos_tier == "critical":
		return false

	var fanout_hints_raw: Variant = payload.get(
		"fanout_hints",
		{}
	)
	var fanout_hints: Dictionary = (
		fanout_hints_raw
		if typeof(fanout_hints_raw) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		fanout_hints.get(
			"force_immediate_bus",
			false
		)
	):
		return false

	if bool(
		fanout_hints.get(
			"force_defer_bus",
			false
		)
	):
		return true

	var guard: Dictionary = _get_runtime_guard()

	var compressed_execution: bool = (
		bool(
			guard.get(
				"compressed_execution_current_year",
				false
			)
		)
		or bool(
			guard.get(
				"auto_stability_mode",
				false
			)
		)
	)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var interaction_grace_until_ms: int = int(
		guard.get(
			"ui_interaction_grace_until_ms",
			0
		)
	)

	var ui_concurrency_yield_active: bool = (
		bool(
			guard.get(
				"ui_tail_work_yield_to_input",
				false
			)
		)
		or (
			interaction_grace_until_ms > 0
			and now_ms < interaction_grace_until_ms
		)
	)

	if qos_tier == "important":
		return (
			bool(
				guard.get(
					"defer_noncritical_systems",
					false
				)
			)
			or compressed_execution
			or ui_concurrency_yield_active
		)

	return (
		bool(
			guard.get(
				"defer_noncritical_systems",
				false
			)
		)
		or bool(
			guard.get(
				"reduce_scenario_density",
				false
			)
		)
		or compressed_execution
		or ui_concurrency_yield_active
	)

func _deliver_to_subscriber(
	sub: Dictionary,
	payload: Dictionary
) -> bool:
	var target: Object = sub.get(
		"target",
		null
	)

	var method_name: String = str(
		sub.get(
			"method",
			""
		)
	).strip_edges()

	if (
		target == null
		or method_name == ""
	):
		return false

	if not is_instance_valid(
		target
	):
		return false

	if not target.has_method(
		method_name
	):
		return false

	var delivery_started_us: int = int(
		Time.get_ticks_usec()
	)

	target.call(
		method_name,
		payload
	)

	var delivery_finished_us: int = int(
		Time.get_ticks_usec()
	)

	var elapsed_us: int = maxi(
		0,
		delivery_finished_us - delivery_started_us
	)

	if elapsed_us >= 2000:
		var event_name: String = str(
			payload.get(
				"event_name",
				""
			)
		)

		var target_class: String = str(
			target.get_class()
		)

		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"event_bus_last_slow_subscriber"
			] = {
				"event_name": event_name,
				"target_class": target_class,
				"method": method_name,
				"elapsed_us": elapsed_us,
				"year": int(
					payload.get(
						"year",
						gs.year
					)
				),
				"runtime_managed": bool(
					payload.get(
						"runtime_managed",
						false
					)
				),
				"at_ms": int(
					Time.get_ticks_msec()
				)
			}

		EraLog.truth(
			(
				"ERALIFE_EVENT_BUS_SLOW_SUBSCRIBER"
				+ "|event=%s"
				+ "|target=%s"
				+ "|method=%s"
				+ "|elapsed_us=%d"
				+ "|runtime_managed=%s"
				+ "|at_ms=%d"
			)
			% [
				event_name,
				target_class,
				method_name,
				elapsed_us,
				str(
					bool(
						payload.get(
							"runtime_managed",
							false
						)
					)
				).to_lower(),
				int(
					Time.get_ticks_msec()
				)
			]
		)

	return true


func _build_deferred_delivery_key(event_type: String, payload: Dictionary, sub: Dictionary) -> String:
	var fanout_hints_raw: Variant = payload.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}

	var explicit_batch_key: String = str(fanout_hints.get("event_batch_key", payload.get("event_batch_key", ""))).strip_edges()
	if explicit_batch_key != "":
		return "%s|%s" % [
			str(sub.get("subscriber_key", "")),
			explicit_batch_key
		]

	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(sub.get("subscriber_key", "")),
		event_type,
		str(payload.get("dispatch_lane", "")),
		str(payload.get("npc_id", -1)),
		str(payload.get("target_id", -1)),
		str(payload.get("year", gs.year if gs != null else 0)),
		str(payload.get("source", "event_bus")),
		str(payload.get("text", "")).strip_edges()
	]


func _build_batched_event_preview(payload: Dictionary) -> Dictionary:
	return {
		"event_id": int(payload.get("event_id", -1)),
		"event_uid": str(payload.get("event_uid", "")),
		"lineage_id": str(payload.get("lineage_id", "")),
		"event_name": str(payload.get("event_name", "")),
		"dispatch_lane": str(payload.get("dispatch_lane", "")),
		"year": int(payload.get("year", gs.year if gs != null else 0)),
		"npc_id": int(payload.get("npc_id", -1)),
		"target_id": int(payload.get("target_id", -1)),
		"source": str(payload.get("source", "event_bus")),
		"text": str(payload.get("text", ""))
	}


func _merge_deferred_entry_payload(
	existing_payload: Dictionary,
	new_payload: Dictionary
) -> Dictionary:
	var batched_events_raw: Variant = existing_payload.get(
		"batched_events",
		[]
	)
	var batched_events: Array = (
		(batched_events_raw as Array).duplicate(false)
		if typeof(batched_events_raw) == TYPE_ARRAY
		else []
	)

	batched_events.append(
		_build_batched_event_preview(
			new_payload
		)
	)


	while batched_events.size() > _DEFERRED_BATCH_PREVIEW_LIMIT:
		batched_events.pop_front()

	var merged: Dictionary = new_payload.duplicate(false)
	var prior_count: int = int(
		existing_payload.get(
			"batched_event_count",
			1
		)
	)

	merged [
		"batched_event_count"
	] = prior_count + 1
	merged [
		"batched_events"
	] = batched_events
	merged [
		"batched"
	] = true

	return merged
func _arm_deferred_delivery_service() -> void:
	if (
		_deferred_delivery_service_armed
		or not has_pending_deferred_deliveries()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		_deferred_delivery_service_armed = false

		return

	var callback:= Callable(
		self,
		"_service_deferred_delivery_quantum"
	)

	if tree.process_frame.is_connected(
		callback
	):
		_deferred_delivery_service_armed = true

		return

	var connection_error: int = (
		tree.process_frame.connect(
			callback,
			CONNECT_ONE_SHOT
		)
	)

	if connection_error != OK:
		_deferred_delivery_service_armed = false

		return

	_deferred_delivery_service_armed = true
func _service_deferred_delivery_quantum() -> void:
	_deferred_delivery_service_armed = false

	if not has_pending_deferred_deliveries():
		return







	_drain_deferred_deliveries(
		1,
		false
	)

	if has_pending_deferred_deliveries():
		_arm_deferred_delivery_service()
func _queue_deferred_delivery(
	event_type: String,
	payload: Dictionary,
	sub: Dictionary
) -> void:
	var delivery_key: String = _build_deferred_delivery_key(
		event_type,
		payload,
		sub
	)
	var qos_tier: String = _resolve_payload_qos_tier(
		payload
	)

	if (
		qos_tier == "ambient"
		and _deferred_delivery_index.has(
			delivery_key
		)
	):
		var existing_delivery_id: int = int(
			_deferred_delivery_index.get(
				delivery_key,
				-1
			)
		)

		if (
			existing_delivery_id >= _deferred_delivery_head
			and _deferred_deliveries.has(
				existing_delivery_id
			)
		):
			var existing_entry_raw: Variant = _deferred_deliveries.get(
				existing_delivery_id,
				{}
			)
			var existing_entry: Dictionary = (
				existing_entry_raw
				if typeof(existing_entry_raw) == TYPE_DICTIONARY
				else {}
			)
			var existing_payload_raw: Variant = existing_entry.get(
				"payload",
				{}
			)
			var existing_payload: Dictionary = (
				existing_payload_raw
				if typeof(existing_payload_raw) == TYPE_DICTIONARY
				else {}
			)

			existing_entry [
				"payload"
			] = _merge_deferred_entry_payload(
				existing_payload,
				payload
			)
			existing_entry [
				"last_event_id"
			] = int(
				payload.get(
					"event_id",
					-1
				)
			)
			existing_entry [
				"last_event_uid"
			] = str(
				payload.get(
					"event_uid",
					""
				)
			)
			existing_entry [
				"last_year"
			] = int(
				payload.get(
					"year",
					gs.year
					if gs != null
					else 0
				)
			)

			_deferred_deliveries [
				existing_delivery_id
			] = existing_entry

			_arm_deferred_delivery_service()
			return

		_deferred_delivery_index.erase(
			delivery_key
		)

	var queued_payload: Dictionary = payload.duplicate(
		false
	)
	queued_payload [
		"batched_event_count"
	] = int(
		queued_payload.get(
			"batched_event_count",
			1
		)
	)
	queued_payload [
		"batched_events"
	] = [
		_build_batched_event_preview(
			queued_payload
		)
	]

	var entry:= {
		"delivery_key": delivery_key,
		"event_type": event_type,
		"subscriber": sub.duplicate(false),
		"payload": queued_payload,
		"qos_tier": qos_tier,
		"dispatch_lane": str(
			payload.get(
				"dispatch_lane",
				sub.get(
					"lane",
					""
				)
			)
		),
		"queued_event_id": int(
			payload.get(
				"event_id",
				-1
			)
		),
		"queued_event_uid": str(
			payload.get(
				"event_uid",
				""
			)
		),
		"last_event_id": int(
			payload.get(
				"event_id",
				-1
			)
		),
		"last_event_uid": str(
			payload.get(
				"event_uid",
				""
			)
		),
		"last_year": int(
			payload.get(
				"year",
				gs.year
				if gs != null
				else 0
			)
		)
	}

	var delivery_id: int = _deferred_delivery_tail
	_deferred_delivery_tail += 1

	_deferred_deliveries [
		delivery_id
	] = entry
	_deferred_delivery_index [
		delivery_key
	] = delivery_id

	_note_deferred_batch_delivery_queued(
		queued_payload
	)

	_arm_deferred_delivery_service()
func _rebuild_deferred_delivery_index() -> void:
	_deferred_delivery_index.clear()



	for raw_delivery_id in _deferred_deliveries:
		var delivery_id: int = int(
			raw_delivery_id
		)

		if delivery_id < _deferred_delivery_head:
			continue

		var entry_raw: Variant = (
			_deferred_deliveries.get(
				delivery_id,
				{}
			)
		)
		var entry: Dictionary = (
			entry_raw
			if typeof(entry_raw) == TYPE_DICTIONARY
			else {}
		)
		var delivery_key: String = str(
			entry.get(
				"delivery_key",
				""
			)
		).strip_edges()

		if delivery_key == "":
			continue

		_deferred_delivery_index [
			delivery_key
		] = delivery_id

func _drain_deferred_deliveries(
	max_handlers: int = -1,
	force_all: bool = false
) -> void:
	if _deferred_deliveries.is_empty():
		_deferred_delivery_head = 0
		_deferred_delivery_tail = 0
		_deferred_delivery_index.clear()
		return

	var pending_count: int = _deferred_deliveries.size()
	var budget: int = max_handlers

	if budget < 0:
		budget = (
			pending_count
			if force_all
			else 4
		)

	budget = min(
		max(
			0,
			budget
		),
		pending_count
	)

	if budget <= 0:
		return




	var work_budget_usec: int = (
		500
		if force_all
		else 250
	)

	var started_usec: int = int(
		Time.get_ticks_usec()
	)
	var delivered_count: int = 0

	while (
		delivered_count < budget
		and _deferred_delivery_head < _deferred_delivery_tail
	):
		if (
			delivered_count > 0
			and int(
				Time.get_ticks_usec()
			) - started_usec >= work_budget_usec
		):
			break

		var delivery_id: int = _deferred_delivery_head
		_deferred_delivery_head += 1

		if not _deferred_deliveries.has(
			delivery_id
		):
			continue

		var entry_raw: Variant = _deferred_deliveries.get(
			delivery_id,
			{}
		)
		var entry: Dictionary = (
			entry_raw
			if typeof(entry_raw) == TYPE_DICTIONARY
			else {}
		)




		_deferred_deliveries.erase(
			delivery_id
		)

		var delivery_key: String = str(
			entry.get(
				"delivery_key",
				""
			)
		).strip_edges()

		if (
			delivery_key != ""
			and int(
				_deferred_delivery_index.get(
					delivery_key,
					-1
				)
			) == delivery_id
		):
			_deferred_delivery_index.erase(
				delivery_key
			)

		var payload_raw: Variant = entry.get(
			"payload",
			{}
		)
		var payload: Dictionary = (
			payload_raw
			if typeof(payload_raw) == TYPE_DICTIONARY
			else {}
		)

		var sub_raw: Variant = entry.get(
			"subscriber",
			{}
		)
		var sub: Dictionary = (
			sub_raw
			if typeof(sub_raw) == TYPE_DICTIONARY
			else {}
		)

		delivered_count += 1

		var delivered_ok: bool = _deliver_to_subscriber(
			sub,
			payload
		)

		_settle_deferred_batch_delivery(
			payload,
			delivered_ok
		)

	if _deferred_deliveries.is_empty():
		_deferred_delivery_head = 0
		_deferred_delivery_tail = 0
		_deferred_delivery_index.clear()


func flush_deferred(
	max_handlers: int = -1,
	force_all: bool = false
) -> void:


	if (
		_deferred_delivery_service_armed
		and not force_all
	):
		return

	_drain_deferred_deliveries(
		max_handlers,
		force_all
	)

	if has_pending_deferred_deliveries():
		_arm_deferred_delivery_service()

func has_pending_deferred_deliveries() -> bool:
	return not _deferred_deliveries.is_empty()

func get_pending_deferred_delivery_count() -> int:
	return _deferred_deliveries.size()

func _replay_to_subscriber(event_type: String, sub: Dictionary) -> void:
	if contract_layer == null or not contract_layer.has_method("get_replay_events"):
		return

	var replay_events: Array = contract_layer.get_replay_events(event_type)
	for payload_raw in replay_events:
		if typeof(payload_raw) != TYPE_DICTIONARY:
			continue
		_deliver_to_subscriber(sub, payload_raw as Dictionary)





func emit(
	event_type: String,
	payload:= {}
):
	var normalized_event_type: String = str(
		event_type
	).strip_edges()

	if normalized_event_type == "":
		return

	var gate: Dictionary = {
		"allowed": true,
		"event_type": normalized_event_type,
		"payload": (
			payload
			if typeof(payload) == TYPE_DICTIONARY
			else { "value": payload}
		)
	}

	if (
		contract_layer != null
		and contract_layer.has_method(
			"begin_emit"
		)
	):
		gate = contract_layer.begin_emit(
			normalized_event_type,
			payload
		)

	if not bool(
		gate.get(
			"allowed",
			true
		)
	):
		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"last_event_bus_blocked_dispatch"
			] = gate.duplicate(false)

		return

	normalized_event_type = str(
		gate.get(
			"event_type",
			normalized_event_type
		)
	).strip_edges()




	var prepared_payload: Variant = gate.get(
		"payload",
		payload
	)
	var normalized: Dictionary = _normalize_payload(
		normalized_event_type,
		prepared_payload,
		gate
	)

	_begin_deferred_batch_tracking(
		normalized_event_type,
		normalized
	)

	if not subscribers.has(
		normalized_event_type
	):
		_finalize_deferred_batch_tracking(
			normalized
		)

		if (
			contract_layer != null
			and contract_layer.has_method(
				"end_emit"
			)
		):
			contract_layer.end_emit(
				gate,
				normalized
			)

		return

	for raw_sub in subscribers [
		normalized_event_type
	]:
		var sub: Dictionary = (
			raw_sub
			if typeof(raw_sub) == TYPE_DICTIONARY
			else {}
		)

		if _should_defer_delivery(
			normalized,
			sub
		):
			_queue_deferred_delivery(
				normalized_event_type,
				normalized,
				sub
			)
			continue



		_deliver_to_subscriber(
			sub,
			normalized
		)

	_finalize_deferred_batch_tracking(
		normalized
	)

	if has_pending_deferred_deliveries():
		_arm_deferred_delivery_service()

	if (
		contract_layer != null
		and contract_layer.has_method(
			"end_emit"
		)
	):
		contract_layer.end_emit(
			gate,
			normalized
		)
func publish(event:= {}) -> void:
	if typeof(event) == TYPE_STRING or typeof(event) == TYPE_STRING_NAME:
		emit(str(event), {})
		return

	if typeof(event) != TYPE_DICTIONARY:
		return

	var envelope: Dictionary = event.duplicate(true)
	var event_type: String = str(
		envelope.get("type", envelope.get("event", envelope.get("event_name", "")))
	).strip_edges()

	if event_type == "":
		return

	envelope.erase("type")
	envelope.erase("event")
	envelope.erase("event_name")

	emit(event_type, envelope)