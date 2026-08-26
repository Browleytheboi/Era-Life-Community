extends Resource
class_name EventBusContractLayer

const CONTRACT_SCHEMA:= "eralife.event_bus_contract_layer"
const CONTRACT_VERSION:= 1

const DEFAULT_MAX_DEPTH:= 12
const DEFAULT_DUPLICATE_TTL_MS:= 120
const DEFAULT_DUPLICATE_HISTORY_LIMIT:= 512
const DEFAULT_REPLAY_BUFFER_LIMIT:= 24

const ALLOWED_SCHEMA_POLICIES:= [
	"warn",
	"drop",
	"quarantine",
	"strict"
]

const ALLOWED_LANE_POLICIES:= [
	"immediate",
	"deferred",
	"qos",
	"drop_when_over_budget"
]

var gs
var bus

var contract_registry: Dictionary = {}
var event_contracts: Dictionary = {}
var lane_contracts: Dictionary = {}
var runtime_guard: Dictionary = {}
var replay_buffers: Dictionary = {}
var duplicate_window: Dictionary = {}



var duplicate_order: Array = []
var duplicate_order_cursor: int = 0
var duplicate_order_limit: int = 0
var lineage_stack: Array = []

var last_validation_report: Dictionary = {}
var last_dispatch_report: Dictionary = {}
var last_configure_report: Dictionary = {}

var _lineage_seq: int = 0

func _init(_gs = null, _bus = null):
	gs = _gs
	bus = _bus
	reset_to_defaults()


func reset_to_defaults() -> void:
	contract_registry.clear()
	event_contracts.clear()
	lane_contracts.clear()
	runtime_guard.clear()
	last_validation_report.clear()
	last_dispatch_report.clear()
	_ingest_contract(_normalize_contract(_build_legacy_default_contract(), "builtin://event_bus_legacy_default"))


func configure(raw_contract: Dictionary = {}) -> Dictionary:
	reset_to_defaults()

	var report:= {
		"schema": "eralife.event_bus_contract_layer_configure_report",
		"version": CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"warnings": [],
		"configured_at_ms": int(Time.get_ticks_msec())
	}

	var contracts: Array = []

	var registry_raw: Variant = raw_contract.get("event_bus_contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for key in (registry_raw as Dictionary).keys():
			var row_raw: Variant = (registry_raw as Dictionary).get(key, {})
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	var contracts_raw: Variant = raw_contract.get("contracts", [])
	if typeof(contracts_raw) == TYPE_ARRAY:
		for row_raw in contracts_raw:
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	if contracts.is_empty() and not raw_contract.is_empty():
		contracts.append(raw_contract.duplicate(true))

	for raw in contracts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = _normalize_contract(raw, str(raw.get("source_path", "runtime_event_bus_contract")))
		var validation: Dictionary = normalized.get("validation", {})
		if not bool(validation.get("valid", true)):
			report ["failed"].append({
				"id": str(normalized.get("id", "")),
				"validation": validation.duplicate(true)
			})
			continue

		_ingest_contract(normalized)
		report ["loaded"].append({
			"id": str(normalized.get("id", "")),
			"event_count": int(normalized.get("events", []).size()),
			"lane_count": int(normalized.get("dispatch_lanes", []).size())
		})

	last_configure_report = report.duplicate(true)
	return report

func register_contract(raw_contract: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.event_bus_contract_layer_register_report",
		"version": CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"warnings": [],
		"registered_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(raw_contract) != TYPE_DICTIONARY or raw_contract.is_empty():
		report ["failed"].append({
			"reason": "No event bus contract supplied."
		})
		return report

	var normalized: Dictionary = _normalize_contract(
		raw_contract,
		str(raw_contract.get("source_path", "runtime_event_bus_contract"))
	)

	var validation: Dictionary = normalized.get("validation", {})
	if not bool(validation.get("valid", true)):
		report ["failed"].append({
			"id": str(normalized.get("id", "")),
			"validation": validation.duplicate(true)
		})
		return report

	_ingest_contract(normalized)

	report ["loaded"].append({
		"id": str(normalized.get("id", "")),
		"event_count": int(normalized.get("events", []).size()),
		"lane_count": int(normalized.get("dispatch_lanes", []).size())
	})

	last_configure_report = report.duplicate(true)
	return report
func _build_legacy_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "legacy_event_bus",
		"runtime_guards": {
			"max_depth": DEFAULT_MAX_DEPTH,
			"duplicate_ttl_ms": DEFAULT_DUPLICATE_TTL_MS,
			"duplicate_history_limit": DEFAULT_DUPLICATE_HISTORY_LIMIT,
			"default_replay_buffer_limit": DEFAULT_REPLAY_BUFFER_LIMIT
		},
		"dispatch_lanes": [
			{
				"id": "immediate",
				"policy": "immediate",
				"priority": 0,
				"force_immediate": true,
				"defer_by_default": false
			},
			{
				"id": "critical",
				"policy": "immediate",
				"priority": 10,
				"force_immediate": true,
				"defer_by_default": false
			},
			{
				"id": "important",
				"policy": "qos",
				"priority": 50,
				"force_immediate": false,
				"defer_by_default": false
			},
			{
				"id": "ambient",
				"policy": "deferred",
				"priority": 100,
				"force_immediate": false,
				"defer_by_default": true
			},
			{
				"id": "deferred",
				"policy": "deferred",
				"priority": 120,
				"force_immediate": false,
				"defer_by_default": true
			}
		],
		"events": [
			{
				"id": "legacy_default_event",
				"event": "*",
				"lane": "important",
				"schema_policy": "warn",
				"allow_unknown_keys": true,
				"suppress_duplicates": true,
				"duplicate_ttl_ms": DEFAULT_DUPLICATE_TTL_MS,
				"max_depth": DEFAULT_MAX_DEPTH,
				"replay_enabled": false,
				"replay_buffer_limit": DEFAULT_REPLAY_BUFFER_LIMIT
			}
		]
	}


func _normalize_contract(raw_contract: Dictionary, source_path: String = "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", "event_bus_contract"))).strip_edges()
	if contract_id == "":
		contract_id = "event_bus_contract"

	var version: int = max(1, int(raw_contract.get("version", CONTRACT_VERSION)))
	if version > CONTRACT_VERSION:
		warnings.append("EventBus contract '%s' was authored for version %d. Runtime supports %d." % [contract_id, version, CONTRACT_VERSION])

	var normalized_lanes: Array = []
	var lanes_raw: Array = _safe_dictionary_array(raw_contract.get("dispatch_lanes", raw_contract.get("lanes", [])))
	for raw_lane in lanes_raw:
		var lane: Dictionary = _normalize_lane_contract(raw_lane, contract_id)
		if str(lane.get("id", "")).strip_edges() == "":
			warnings.append("Skipped EventBus lane without id.")
			continue
		normalized_lanes.append(lane)

	var normalized_events: Array = []
	var events_raw: Array = _safe_dictionary_array(raw_contract.get("events", raw_contract.get("event_contracts", [])))
	for raw_event in events_raw:
		var event_contract: Dictionary = _normalize_event_contract(raw_event, contract_id)
		if str(event_contract.get("event", "")).strip_edges() == "":
			warnings.append("Skipped EventBus event contract without event.")
			continue
		normalized_events.append(event_contract)

	var runtime_guard_raw: Variant = raw_contract.get("runtime_guards", raw_contract.get("runtime_guard", {}))
	var normalized_runtime_guard: Dictionary = runtime_guard_raw.duplicate(true) if typeof(runtime_guard_raw) == TYPE_DICTIONARY else {}

	if normalized_events.is_empty() and normalized_lanes.is_empty() and normalized_runtime_guard.is_empty():
		errors.append("EventBus contract has no events, dispatch_lanes, or runtime_guards.")

	return {
		"schema": str(raw_contract.get("schema", CONTRACT_SCHEMA)).strip_edges(),
		"version": version,
		"runtime_contract_version": CONTRACT_VERSION,
		"id": contract_id,
		"source_path": source_path,
		"priority": int(raw_contract.get("priority", 0)),
		"conflict_policy": str(raw_contract.get("conflict_policy", "merge")).strip_edges().to_lower(),
		"runtime_guards": normalized_runtime_guard,
		"dispatch_lanes": normalized_lanes,
		"events": normalized_events,
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}


func _normalize_lane_contract(raw_lane: Dictionary, contract_id: String = "") -> Dictionary:
	var lane_id: String = str(raw_lane.get("id", raw_lane.get("lane", ""))).strip_edges()
	var policy: String = str(raw_lane.get("policy", "qos")).strip_edges().to_lower()
	if policy not in ALLOWED_LANE_POLICIES:
		policy = "qos"

	return {
		"id": lane_id,
		"lane": lane_id,
		"contract_id": contract_id,
		"enabled": bool(raw_lane.get("enabled", true)),
		"priority": int(raw_lane.get("priority", 100)),
		"policy": policy,
		"force_immediate": bool(raw_lane.get("force_immediate", policy == "immediate")),
		"defer_by_default": bool(raw_lane.get("defer_by_default", policy == "deferred")),
		"queue_limit": max(0, int(raw_lane.get("queue_limit", 128))),
		"max_handlers_per_flush": max(1, int(raw_lane.get("max_handlers_per_flush", 64))),
		"metadata": raw_lane.get("metadata", {}).duplicate(true) if typeof(raw_lane.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func _normalize_event_contract(raw_event: Dictionary, contract_id: String = "") -> Dictionary:
	var event_name: String = str(raw_event.get("event", raw_event.get("event_name", raw_event.get("id", "")))).strip_edges()
	var event_id: String = str(raw_event.get("id", event_name)).strip_edges()
	var schema_policy: String = str(raw_event.get("schema_policy", "warn")).strip_edges().to_lower()
	if schema_policy not in ALLOWED_SCHEMA_POLICIES:
		schema_policy = "warn"

	return {
		"id": event_id,
		"contract_id": contract_id,
		"event": event_name,
		"event_name": event_name,
		"enabled": bool(raw_event.get("enabled", true)),
		"lane": str(raw_event.get("lane", raw_event.get("dispatch_lane", "important"))).strip_edges(),
		"priority": int(raw_event.get("priority", 100)),
		"schema_policy": schema_policy,
		"allow_unknown_keys": bool(raw_event.get("allow_unknown_keys", true)),
		"required_keys": _safe_string_array(raw_event.get("required_keys", [])),
		"optional_keys": _safe_string_array(raw_event.get("optional_keys", [])),
		"key_types": raw_event.get("key_types", {}).duplicate(true) if typeof(raw_event.get("key_types", {})) == TYPE_DICTIONARY else {},
		"defaults": raw_event.get("defaults", {}).duplicate(true) if typeof(raw_event.get("defaults", {})) == TYPE_DICTIONARY else {},
		"aliases": _safe_string_array(raw_event.get("aliases", raw_event.get("compatibility_aliases", []))),
		"canonical_event": str(raw_event.get("canonical_event", event_name)).strip_edges(),
		"max_depth": max(1, int(raw_event.get("max_depth", DEFAULT_MAX_DEPTH))),
		"suppress_duplicates": bool(raw_event.get("suppress_duplicates", true)),
		"duplicate_ttl_ms": max(0, int(raw_event.get("duplicate_ttl_ms", DEFAULT_DUPLICATE_TTL_MS))),
		"duplicate_keys": _safe_string_array(raw_event.get("duplicate_keys", [])),
		"replay_enabled": bool(raw_event.get("replay_enabled", false)),
		"replay_buffer_limit": max(0, int(raw_event.get("replay_buffer_limit", DEFAULT_REPLAY_BUFFER_LIMIT))),
		"metadata": raw_event.get("metadata", {}).duplicate(true) if typeof(raw_event.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func _ingest_contract(contract: Dictionary) -> void:
	var contract_id: String = str(contract.get("id", "event_bus_contract")).strip_edges()
	if contract_id == "":
		contract_id = "event_bus_contract"

	contract_registry [contract_id] = contract.duplicate(true)

	var guard_raw: Variant = contract.get("runtime_guards", {})
	if typeof(guard_raw) == TYPE_DICTIONARY:
		for key in (guard_raw as Dictionary).keys():
			runtime_guard [str(key)] = (guard_raw as Dictionary).get(key)

	for lane_raw in contract.get("dispatch_lanes", []):
		if typeof(lane_raw) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_raw
		var lane_id: String = str(lane.get("id", "")).strip_edges()
		if lane_id == "":
			continue
		lane_contracts [lane_id] = lane.duplicate(true)

	for event_raw in contract.get("events", []):
		if typeof(event_raw) != TYPE_DICTIONARY:
			continue
		var event_contract: Dictionary = event_raw
		var event_name: String = str(event_contract.get("event", "")).strip_edges()
		if event_name == "":
			continue

		event_contracts [event_name] = event_contract.duplicate(true)

		for alias in event_contract.get("aliases", []):
			var clean_alias: String = str(alias).strip_edges()
			if clean_alias == "":
				continue
			var alias_contract: Dictionary = event_contract.duplicate(true)
			alias_contract ["event"] = clean_alias
			alias_contract ["event_name"] = clean_alias
			alias_contract ["canonical_event"] = str(event_contract.get("canonical_event", event_name))
			event_contracts [clean_alias] = alias_contract


func begin_emit(
	event_type: String,
	payload: Variant
) -> Dictionary:
	var original_event_type: String = str(
		event_type
	).strip_edges()

	var raw: Dictionary = (
		payload.duplicate(false)
		if typeof(payload) == TYPE_DICTIONARY
		else { "value": payload}
	)

	var canonical_event: String = resolve_event_type(
		original_event_type
	)
	var event_contract: Dictionary = get_event_contract(
		canonical_event
	)

	if not bool(
		event_contract.get(
			"enabled",
			true
		)
	):
		return _blocked_dispatch(
			original_event_type,
			canonical_event,
			"event_contract_disabled",
			raw
		)

	var prepared_payload: Dictionary = (
		_apply_payload_defaults(
			raw,
			event_contract
		)
	)

	var schema_report: Dictionary = validate_payload(
		canonical_event,
		prepared_payload,
		event_contract
	)
	var schema_policy: String = str(
		event_contract.get(
			"schema_policy",
			"warn"
		)
	)

	if (
		not bool(
			schema_report.get(
				"valid",
				true
			)
		)
		and schema_policy in [
			"drop",
			"strict",
			"quarantine"
		]
	):
		return _blocked_dispatch(
			original_event_type,
			canonical_event,
			"schema_validation_failed",
			prepared_payload,
			schema_report
		)

	var max_depth: int = max(
		1,
		int(
			event_contract.get(
				"max_depth",
				runtime_guard.get(
					"max_depth",
					DEFAULT_MAX_DEPTH
				)
			)
		)
	)
	var current_depth: int = (
		lineage_stack.size()
	)

	if current_depth >= max_depth:
		return _blocked_dispatch(
			original_event_type,
			canonical_event,
			"max_depth_exceeded",
			prepared_payload,
			{
				"depth": current_depth,
				"max_depth": max_depth
			}
		)

	var duplicate_report: Dictionary = (
		_check_duplicate(
			canonical_event,
			prepared_payload,
			event_contract
		)
	)

	if bool(
		duplicate_report.get(
			"duplicate",
			false
		)
	):
		return _blocked_dispatch(
			original_event_type,
			canonical_event,
			"duplicate_suppressed",
			prepared_payload,
			duplicate_report
		)

	_lineage_seq += 1

	var parent_event_uid: String = ""
	var lineage_id: String = ""

	if not lineage_stack.is_empty():
		var parent_raw: Variant = (
			lineage_stack.back()
		)
		var parent: Dictionary = (
			parent_raw
			if typeof(parent_raw) == TYPE_DICTIONARY
			else {}
		)

		parent_event_uid = str(
			parent.get(
				"event_uid",
				""
			)
		)
		lineage_id = str(
			parent.get(
				"lineage_id",
				""
			)
		)

	var event_uid: String = str(
		prepared_payload.get(
			"event_uid",
			""
		)
	).strip_edges()

	if event_uid == "":
		event_uid = (
			"ev_%d_%d"
			% [
				int(
					Time.get_ticks_msec()
				),
				_lineage_seq
			]
		)

	if lineage_id == "":
		lineage_id = event_uid

	var dispatch_lane: String = resolve_lane(
		canonical_event,
		prepared_payload,
		event_contract
	)
	var lane_contract: Dictionary = get_lane_contract(
		dispatch_lane
	)

	var gate:= {
		"allowed": true,
		"event_type": canonical_event,
		"original_event_type": original_event_type,
		"payload": prepared_payload,
		"event_uid": event_uid,
		"lineage_id": lineage_id,
		"parent_event_uid": parent_event_uid,
		"lineage_depth": current_depth,
		"dispatch_lane": dispatch_lane,
		"lane_contract": lane_contract.duplicate(false),
		"event_contract": event_contract.duplicate(false),
		"schema_report": schema_report.duplicate(false),
		"began_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	lineage_stack.append(
		gate
	)



	last_dispatch_report = {
		"allowed": true,
		"event_type": canonical_event,
		"original_event_type": original_event_type,
		"event_uid": event_uid,
		"lineage_id": lineage_id,
		"parent_event_uid": parent_event_uid,
		"lineage_depth": current_depth,
		"dispatch_lane": dispatch_lane,
		"schema_valid": bool(
			schema_report.get(
				"valid",
				true
			)
		),
		"began_at_ms": int(
			gate.get(
				"began_at_ms",
				0
			)
		)
	}

	return gate

func end_emit(gate: Dictionary, payload: Dictionary = {}) -> void:
	var event_uid: String = str(gate.get("event_uid", "")).strip_edges()

	if not lineage_stack.is_empty():
		var top_raw: Variant = lineage_stack.back()
		var top: Dictionary = top_raw if typeof(top_raw) == TYPE_DICTIONARY else {}
		if str(top.get("event_uid", "")) == event_uid:
			lineage_stack.pop_back()
		else:
			for i in range(lineage_stack.size() - 1, -1, -1):
				var row_raw: Variant = lineage_stack [i]
				var row: Dictionary = row_raw if typeof(row_raw) == TYPE_DICTIONARY else {}
				if str(row.get("event_uid", "")) == event_uid:
					lineage_stack.remove_at(i)
					break

	var event_type: String = str(gate.get("event_type", "")).strip_edges()
	if event_type != "" and typeof(payload) == TYPE_DICTIONARY:
		record_replay(event_type, payload)


func resolve_event_type(event_type: String) -> String:
	var clean_event: String = str(event_type).strip_edges()
	if clean_event == "":
		return ""

	if event_contracts.has(clean_event):
		var contract: Dictionary = event_contracts.get(clean_event, {})
		var canonical: String = str(contract.get("canonical_event", clean_event)).strip_edges()
		return canonical if canonical != "" else clean_event

	return clean_event


func resolve_lane(_event_type: String, payload: Dictionary, event_contract: Dictionary = {}) -> String:
	var explicit_lane: String = str(payload.get("dispatch_lane", payload.get("lane", ""))).strip_edges()
	if explicit_lane != "":
		return explicit_lane

	var contract_lane: String = str(event_contract.get("lane", "")).strip_edges()
	if contract_lane != "":
		return contract_lane

	var qos_tier: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
	if qos_tier in ["critical", "important", "ambient"]:
		return qos_tier

	return "important"


func get_event_contract(event_type: String) -> Dictionary:
	var clean_event: String = str(event_type).strip_edges()
	if event_contracts.has(clean_event):
		return event_contracts.get(clean_event, {}).duplicate(true)
	if event_contracts.has("*"):
		var fallback: Dictionary = event_contracts.get("*", {}).duplicate(true)
		fallback ["event"] = clean_event
		fallback ["event_name"] = clean_event
		return fallback
	return {
		"id": clean_event,
		"event": clean_event,
		"event_name": clean_event,
		"lane": "important",
		"schema_policy": "warn",
		"allow_unknown_keys": true,
		"required_keys": [],
		"key_types": {},
		"defaults": {},
		"max_depth": int(runtime_guard.get("max_depth", DEFAULT_MAX_DEPTH)),
		"suppress_duplicates": true,
		"duplicate_ttl_ms": int(runtime_guard.get("duplicate_ttl_ms", DEFAULT_DUPLICATE_TTL_MS)),
		"replay_enabled": false,
		"replay_buffer_limit": int(runtime_guard.get("default_replay_buffer_limit", DEFAULT_REPLAY_BUFFER_LIMIT))
	}


func get_lane_contract(lane_id: String) -> Dictionary:
	var clean_lane: String = str(lane_id).strip_edges()
	if lane_contracts.has(clean_lane):
		return lane_contracts.get(clean_lane, {}).duplicate(true)
	if lane_contracts.has("important"):
		return lane_contracts.get("important", {}).duplicate(true)
	return {
		"id": clean_lane,
		"lane": clean_lane,
		"policy": "qos",
		"force_immediate": false,
		"defer_by_default": false,
		"priority": 100
	}


func normalize_subscription_options(event_type: String, options: Dictionary = {}) -> Dictionary:
	var clean_event: String = resolve_event_type(event_type)
	var event_contract: Dictionary = get_event_contract(clean_event)

	var normalized: Dictionary = options.duplicate(true)
	var lane: String = str(normalized.get("lane", normalized.get("dispatch_lane", ""))).strip_edges()
	if lane == "":
		lane = str(event_contract.get("lane", "important")).strip_edges()

	var lane_contract: Dictionary = get_lane_contract(lane)

	normalized ["lane"] = lane
	normalized ["dispatch_lane"] = lane
	normalized ["allow_defer"] = bool(normalized.get("allow_defer", not bool(lane_contract.get("force_immediate", false))))
	normalized ["force_immediate"] = bool(normalized.get("force_immediate", bool(lane_contract.get("force_immediate", false))))
	normalized ["replay_on_subscribe"] = bool(normalized.get("replay_on_subscribe", false))
	normalized ["subscription_priority"] = int(normalized.get("priority", normalized.get("subscription_priority", event_contract.get("priority", 100))))

	return normalized


func should_defer_delivery(payload: Dictionary, sub: Dictionary) -> Dictionary:
	var lane: String = str(sub.get("lane", payload.get("dispatch_lane", payload.get("lane", "")))).strip_edges()
	if lane == "":
		lane = resolve_lane(str(payload.get("event_name", "")), payload)

	var lane_contract: Dictionary = get_lane_contract(lane)

	if bool(lane_contract.get("force_immediate", false)):
		return {
			"decided": true,
			"defer": false,
			"reason": "lane_force_immediate",
			"lane": lane
		}

	if bool(lane_contract.get("defer_by_default", false)):
		var qos_tier: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
		if qos_tier != "critical":
			return {
				"decided": true,
				"defer": true,
				"reason": "lane_defer_by_default",
				"lane": lane
			}

	return {
		"decided": false,
		"defer": false,
		"reason": "lane_no_override",
		"lane": lane
	}


func validate_payload(event_type: String, payload: Dictionary, event_contract: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var required_keys: Array = event_contract.get("required_keys", [])
	for raw_key in required_keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		if not payload.has(key):
			errors.append("Event '%s' missing required key '%s'." % [event_type, key])

	var key_types_raw: Variant = event_contract.get("key_types", {})
	var key_types: Dictionary = key_types_raw if typeof(key_types_raw) == TYPE_DICTIONARY else {}

	for key in key_types.keys():
		var clean_key: String = str(key).strip_edges()
		if clean_key == "" or not payload.has(clean_key):
			continue
		var expected_type: String = str(key_types.get(key, "any")).strip_edges().to_lower()
		if not _value_matches_type(payload.get(clean_key), expected_type):
			errors.append("Event '%s' key '%s' expected type '%s'." % [event_type, clean_key, expected_type])

	if not bool(event_contract.get("allow_unknown_keys", true)):
		var allowed: Dictionary = {}
		for raw_key in required_keys:
			allowed [str(raw_key)] = true
		for raw_key in event_contract.get("optional_keys", []):
			allowed [str(raw_key)] = true
		for key in key_types.keys():
			allowed [str(key)] = true

		for key in payload.keys():
			if not allowed.has(str(key)):
				warnings.append("Event '%s' has unknown key '%s'." % [event_type, str(key)])

	var report:= {
		"schema": "eralife.event_bus_payload_validation",
		"event": event_type,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"validated_at_ms": int(Time.get_ticks_msec())
	}

	last_validation_report = report.duplicate(true)
	return report


func record_replay(event_type: String, payload: Dictionary) -> void:
	var event_contract: Dictionary = get_event_contract(event_type)
	if not bool(event_contract.get("replay_enabled", false)):
		return

	var limit: int = max(0, int(event_contract.get("replay_buffer_limit", runtime_guard.get("default_replay_buffer_limit", DEFAULT_REPLAY_BUFFER_LIMIT))))
	if limit <= 0:
		return

	var clean_event: String = str(event_type).strip_edges()
	if not replay_buffers.has(clean_event):
		replay_buffers [clean_event] = []

	var buffer: Array = replay_buffers.get(clean_event, [])
	buffer.append(payload.duplicate(true))

	while buffer.size() > limit:
		buffer.pop_front()

	replay_buffers [clean_event] = buffer


func get_replay_events(event_type: String, limit: int = -1) -> Array:
	var clean_event: String = resolve_event_type(event_type)
	var buffer_raw: Variant = replay_buffers.get(clean_event, [])
	var buffer: Array = buffer_raw if typeof(buffer_raw) == TYPE_ARRAY else []
	var out: Array = []

	var start_index: int = 0
	if limit > 0:
		start_index = max(0, buffer.size() - limit)

	for i in range(start_index, buffer.size()):
		var row_raw: Variant = buffer [i]
		if typeof(row_raw) == TYPE_DICTIONARY:
			out.append((row_raw as Dictionary).duplicate(true))

	return out


func export_debug_snapshot() -> Dictionary:
	return {
		"schema": "eralife.event_bus_contract_layer_debug",
		"version": CONTRACT_VERSION,
		"contract_count": contract_registry.size(),
		"event_contract_count": event_contracts.size(),
		"lane_contract_count": lane_contracts.size(),
		"lineage_depth": lineage_stack.size(),
		"duplicate_window_size": duplicate_window.size(),
		"replay_buffer_count": replay_buffers.size(),
		"runtime_guard": runtime_guard.duplicate(true),
		"last_validation_report": last_validation_report.duplicate(true),
		"last_dispatch_report": last_dispatch_report.duplicate(true),
		"last_configure_report": last_configure_report.duplicate(true)
	}


func _apply_payload_defaults(
	payload: Dictionary,
	event_contract: Dictionary
) -> Dictionary:


	var out: Dictionary = payload.duplicate(false)

	var defaults_raw: Variant = event_contract.get(
		"defaults",
		{}
	)

	if typeof(defaults_raw) != TYPE_DICTIONARY:
		return out

	for key in (
		defaults_raw as Dictionary
	).keys():
		if not out.has(
			key
		):
			out [
				key
			] = (
				defaults_raw as Dictionary
			).get(
				key
			)

	return out
func _check_duplicate(
	event_type: String,
	payload: Dictionary,
	event_contract: Dictionary
) -> Dictionary:
	if not bool(
		event_contract.get(
			"suppress_duplicates",
			true
		)
	):
		return {
			"duplicate": false
		}

	var ttl_ms: int = max(
		0,
		int(
			event_contract.get(
				"duplicate_ttl_ms",
				runtime_guard.get(
					"duplicate_ttl_ms",
					DEFAULT_DUPLICATE_TTL_MS
				)
			)
		)
	)

	if ttl_ms <= 0:
		return {
			"duplicate": false
		}

	var history_limit: int = max(
		8,
		int(
			runtime_guard.get(
				"duplicate_history_limit",
				DEFAULT_DUPLICATE_HISTORY_LIMIT
			)
		)
	)



	if duplicate_order_limit != history_limit:
		duplicate_window.clear()
		duplicate_order.clear()
		duplicate_order_cursor = 0
		duplicate_order_limit = history_limit

	var signature: String = (
		_build_duplicate_signature(
			event_type,
			payload,
			event_contract
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var last_seen_ms: int = int(
		duplicate_window.get(
			signature,
			-999999999
		)
	)

	if (
		last_seen_ms > 0
		and now_ms - last_seen_ms <= ttl_ms
	):
		return {
			"duplicate": true,
			"signature": signature,
			"last_seen_ms": last_seen_ms,
			"now_ms": now_ms,
			"ttl_ms": ttl_ms
		}

	duplicate_window [
		signature
	] = now_ms

	var ring_row: Dictionary = {
		"signature": signature,
		"seen_ms": now_ms
	}

	if duplicate_order.size() < history_limit:
		duplicate_order.append(
			ring_row
		)
	else:
		var slot_index: int = (
			duplicate_order_cursor
			% history_limit
		)

		var old_row_raw: Variant = (
			duplicate_order [
				slot_index
			]
		)
		var old_row: Dictionary = (
			old_row_raw
			if typeof(old_row_raw) == TYPE_DICTIONARY
			else {}
		)

		var old_signature: String = str(
			old_row.get(
				"signature",
				""
			)
		)
		var old_seen_ms: int = int(
			old_row.get(
				"seen_ms",
				-1
			)
		)




		if (
			old_signature != ""
			and int(
				duplicate_window.get(
					old_signature,
					-2
				)
			) == old_seen_ms
		):
			duplicate_window.erase(
				old_signature
			)

		duplicate_order [
			slot_index
		] = ring_row

	duplicate_order_cursor += 1

	return {
		"duplicate": false,
		"signature": signature,
		"now_ms": now_ms,
		"ttl_ms": ttl_ms
	}

func _build_duplicate_signature(event_type: String, payload: Dictionary, event_contract: Dictionary) -> String:
	var explicit_key: String = str(payload.get("duplicate_key", payload.get("event_batch_key", ""))).strip_edges()
	if explicit_key != "":
		return "%s|explicit|%s" % [event_type, explicit_key]

	var duplicate_keys: Array = event_contract.get("duplicate_keys", [])
	if not duplicate_keys.is_empty():
		var parts: Array = [event_type]
		for raw_key in duplicate_keys:
			var key: String = str(raw_key).strip_edges()
			parts.append("%s=%s" % [key, str(payload.get(key, ""))])
		return "|".join(parts)

	return "%s|%s|%s|%s|%s|%s|%s" % [
		event_type,
		str(payload.get("source", "event_bus")),
		str(payload.get("npc_id", -1)),
		str(payload.get("target_id", -1)),
		str(payload.get("year", gs.year if gs != null else 0)),
		str(payload.get("text", "")).strip_edges(),
		str(payload.get("parent_event_uid", ""))
	]


func _prune_duplicate_window() -> void:





	return

func _blocked_dispatch(original_event: String, canonical_event: String, reason: String, payload: Dictionary = {}, detail: Dictionary = {}) -> Dictionary:
	var report:= {
		"allowed": false,
		"original_event_type": original_event,
		"event_type": canonical_event,
		"reason": reason,
		"payload_preview": _payload_preview(payload),
		"detail": detail.duplicate(true),
		"blocked_at_ms": int(Time.get_ticks_msec()),
		"lineage_depth": lineage_stack.size()
	}
	last_dispatch_report = report.duplicate(true)
	return report


func _payload_preview(payload: Dictionary) -> Dictionary:
	return {
		"source": str(payload.get("source", "")),
		"npc_id": int(payload.get("npc_id", -1)),
		"target_id": int(payload.get("target_id", -1)),
		"year": int(payload.get("year", gs.year if gs != null else 0)),
		"text": str(payload.get("text", "")).left(160)
	}


func _value_matches_type(value: Variant, expected_type: String) -> bool:
	match expected_type:
		"any":
			return true
		"dictionary", "dict":
			return typeof(value) == TYPE_DICTIONARY
		"array":
			return typeof(value) == TYPE_ARRAY
		"string":
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		"int", "integer":
			return typeof(value) == TYPE_INT
		"float", "number":
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		"bool", "boolean":
			return typeof(value) == TYPE_BOOL
		_:
			return true


func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))
	return out


func _safe_string_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var clean_direct: String = str(value).strip_edges()
		if clean_direct != "":
			out.append(clean_direct)
		return out

	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out

	for raw in value:
		var clean: String = str(raw).strip_edges()
		if clean != "":
			out.append(clean)

	return out