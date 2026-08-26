extends Resource
class_name TemporalSliceTransformationRuntime

const TEMPORAL_RUNTIME_VERSION:= 1
const FRAME_SCHEMA:= "eralife.live_slice_frame"
const REPORT_SCHEMA:= "eralife.temporal_slice_report"

var gs
var active_session: Dictionary = {}
var last_temporal_report: Dictionary = {}
var conflict_ledger: Dictionary = {}


func _init(_gs = null):
	gs = _gs


func begin_age_up_streaming_transaction(context: Dictionary = {}) -> Dictionary:
	active_session.clear()
	conflict_ledger.clear()

	if gs == null:
		return _fail_report("game_state_missing", "GameState unavailable.", context)

	_ensure_dependencies()

	var target_year: int = int(context.get("target_year", int(gs.year) + 1))
	var player_id: int = int(context.get("player_id", int(gs.player.id) if gs.player != null else -1))

	var frame_report: Dictionary = gs.game_state_serialization_runtime.serialize_live_slice_frame({
		"source": str(context.get("source", "temporal_age_up")),
		"profile": "live_slice_stream",
		"target_year": target_year,
		"player_id": player_id,
		"runtime_owner": str(context.get("runtime_owner", "age_up_runtime")),
		"entity_scope": str(context.get("entity_scope", "player_bubble")),
		"slice_filter": context.get("slice_filter", []),
		"skip_memory_compaction": true,
		"skip_world_feed_normalization": false,
		"skip_prune": true,
		"skip_archive": true
	})

	if not bool(frame_report.get("success", false)):
		return frame_report

	var frame_raw: Variant = frame_report.get("frame", {})
	if typeof(frame_raw) != TYPE_DICTIONARY:
		return _fail_report("frame_missing", "Live slice frame was not produced.", context)

	var frame: Dictionary = frame_raw
	var transform_contracts: Array = _resolve_age_up_contracts(context)

	active_session = {
		"schema": "eralife.temporal_slice_session",
		"version": TEMPORAL_RUNTIME_VERSION,
		"active": true,
		"stage": "transforming",
		"cursor": 0,
		"source_year": int(frame.get("source_year", gs.year)),
		"target_year": target_year,
		"player_id": player_id,
		"context": context.duplicate(true),
		"frame": frame.duplicate(true),
		"contracts": transform_contracts,
		"transformed": [],
		"skipped": [],
		"failed": [],
		"conflicts": [],
		"started_at_ms": int(Time.get_ticks_msec())
	}

	_store_loading_hint("temporal_slice_streaming", "Extracting live reality slices...")

	return {
		"success": true,
		"state": "running",
		"is_complete": false,
		"current_phase": "temporal_slice_streaming",
		"current_micro_lane": "frame_extracted",
		"frame_slice_count": _safe_dictionary(frame.get("slices", {})).size(),
		"contract_count": transform_contracts.size()
	}


func step_age_up_streaming_transaction(max_transforms: int = 1, max_budget_ms: int = 6) -> Dictionary:
	if gs == null:
		return _fail_report("game_state_missing", "GameState unavailable.", {})

	if active_session.is_empty() or not bool(active_session.get("active", false)):
		return begin_age_up_streaming_transaction({})

	var started_at: int = int(Time.get_ticks_msec())
	var budget_ms: int = max(1, int(max_budget_ms))
	var transform_limit: int = max(1, int(max_transforms))
	var transforms_this_step: int = 0

	var stage: String = str(active_session.get("stage", "transforming")).strip_edges()

	if stage == "hydrating":
		return _hydrate_active_session()

	if stage == "complete":
		return {
			"success": true,
			"state": "complete",
			"is_complete": true,
			"current_phase": "temporal_slice_streaming",
			"current_micro_lane": "complete",
			"result": last_temporal_report.duplicate(true)
		}

	var contracts: Array = active_session.get("contracts", [])
	var cursor: int = int(active_session.get("cursor", 0))

	while cursor < contracts.size() and transforms_this_step < transform_limit:
		if int(Time.get_ticks_msec()) - started_at >= budget_ms:
			break

		var raw_contract: Variant = contracts [cursor]
		cursor += 1

		if typeof(raw_contract) != TYPE_DICTIONARY:
			active_session ["skipped"].append({
				"reason": "contract_not_dictionary",
				"index": cursor - 1
			})
			continue

		var transform_report: Dictionary = _apply_transform_contract(raw_contract as Dictionary)
		if bool(transform_report.get("success", false)):
			active_session ["transformed"].append(transform_report)
		else:
			active_session ["failed"].append(transform_report)

		transforms_this_step += 1

	active_session ["cursor"] = cursor

	if cursor >= contracts.size():
		active_session ["stage"] = "hydrating"
		_store_loading_hint("temporal_slice_streaming", "Hydrating the next reality...")
		return _hydrate_active_session()

	var current_contract: Dictionary = {}
	if cursor < contracts.size() and typeof(contracts [cursor]) == TYPE_DICTIONARY:
		current_contract = contracts [cursor]

	_store_loading_hint(
		"temporal_slice_streaming",
		"Transforming %s..." % str(current_contract.get("slice", "time slice"))
	)

	return {
		"success": true,
		"state": "running",
		"is_complete": false,
		"current_phase": "temporal_slice_streaming",
		"current_micro_lane": "transforming",
		"cursor": cursor,
		"contract_count": contracts.size(),
		"progress": float(cursor) / float(max(1, contracts.size()))
	}


func force_complete_age_up_streaming_transaction(reason: String = "force_complete") -> Dictionary:
	var guard: int = 0
	var result: Dictionary = {}
	while guard < 64:
		result = step_age_up_streaming_transaction(8, 24)
		if bool(result.get("is_complete", false)):
			return result
		guard += 1

	if not active_session.is_empty():
		active_session ["failed"].append({
			"reason": "force_complete_guard_exhausted",
			"force_reason": reason
		})
		active_session ["stage"] = "hydrating"
		return _hydrate_active_session()

	return result


func is_streaming_transaction_active() -> bool:
	return not active_session.is_empty() and bool(active_session.get("active", false))


func _hydrate_active_session() -> Dictionary:
	var frame_raw: Variant = active_session.get("frame", {})
	if typeof(frame_raw) != TYPE_DICTIONARY:
		return _fail_report("frame_missing", "Temporal session has no frame.", active_session)

	var frame: Dictionary = frame_raw
	var hydrate_report: Dictionary = {}

	if gs.game_state_hydration_runtime != null and gs.game_state_hydration_runtime.has_method("hydrate_live_slice_frame"):
		hydrate_report = gs.game_state_hydration_runtime.hydrate_live_slice_frame(frame, {
			"source": "temporal_slice_transformation_runtime",
			"profile": "partial_live_hydration",
			"target_year": int(active_session.get("target_year", gs.year)),
			"player_id": int(active_session.get("player_id", -1))
		})
	else:
		return _fail_report("hydration_runtime_missing", "Live slice hydration is unavailable.", active_session)

	var report: Dictionary = {
		"schema": REPORT_SCHEMA,
		"version": TEMPORAL_RUNTIME_VERSION,
		"success": bool(hydrate_report.get("success", false)),
		"state": "complete",
		"is_complete": true,
		"source_year": int(active_session.get("source_year", 0)),
		"target_year": int(active_session.get("target_year", 0)),
		"player_id": int(active_session.get("player_id", -1)),
		"transformed": active_session.get("transformed", []).duplicate(true),
		"skipped": active_session.get("skipped", []).duplicate(true),
		"failed": active_session.get("failed", []).duplicate(true),
		"conflicts": active_session.get("conflicts", []).duplicate(true),
		"hydrate_report": hydrate_report.duplicate(true),
		"started_at_ms": int(active_session.get("started_at_ms", Time.get_ticks_msec())),
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - int(report ["started_at_ms"])

	active_session ["active"] = false
	active_session ["stage"] = "complete"
	last_temporal_report = _make_binary_safe(report)

	if gs != null:
		gs.game_state_temporal_slice_report = last_temporal_report.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["last_temporal_slice_report"] = last_temporal_report.duplicate(true)
			gs.scenario_state ["temporal_slice_streaming_active"] = false

	_store_loading_hint("complete", "")

	return {
		"success": bool(report.get("success", false)),
		"state": "complete",
		"is_complete": true,
		"current_phase": "temporal_slice_streaming",
		"current_micro_lane": "hydrated",
		"result": report.duplicate(true)
	}


func _apply_transform_contract(contract: Dictionary) -> Dictionary:
	var slice_id: String = str(contract.get("slice", contract.get("save_key", ""))).strip_edges()
	var transform_id: String = str(contract.get("transform", "")).strip_edges()
	var rules: Dictionary = _safe_dictionary(contract.get("rules", {}))

	if transform_id == "":
		return {
			"success": false,
			"slice": slice_id,
			"reason": "missing_transform"
		}

	match transform_id:
		"advance_core_identity":
			return _transform_core_identity(slice_id, rules)
		"increment_age":
			return _transform_npc_biology(slice_id, rules)
		"apply_market_shift":
			return _transform_market_slice(slice_id, rules)
		"decay_or_strengthen":
			return _transform_relationship_slice(slice_id, rules)
		_:
			return {
				"success": false,
				"slice": slice_id,
				"transform": transform_id,
				"reason": "unsupported_transform"
			}


func _transform_core_identity(slice_id: String, rules: Dictionary) -> Dictionary:
	var frame: Dictionary = active_session.get("frame", {})
	var _context: Dictionary = active_session.get("context", {})
	var source_year: int = int(active_session.get("source_year", gs.year if gs != null else 0))
	var target_year: int = int(active_session.get("target_year", source_year + 1))
	var player_id: int = int(active_session.get("player_id", -1))

	var state_contract_raw: Variant = {}
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state_contract_raw = gs.scenario_state.get("age_up_time_contract", {})

	var time_contract: Dictionary = state_contract_raw if typeof(state_contract_raw) == TYPE_DICTIONARY else {}
	var temporal_policy: Dictionary = _safe_dictionary(time_contract.get("temporal_slice_policy", {}))

	var may_advance_year: bool = bool(rules.get("advance_year", temporal_policy.get("may_advance_core_year", true)))
	var may_advance_player_age: bool = bool(rules.get("advance_player_age", temporal_policy.get("may_advance_player_age", true)))

	var player_age_before: int = int(time_contract.get("source_age", -1))
	if player_age_before < 0 and gs != null and gs.player != null:
		player_age_before = int(gs.player.age)

	var player_age_after: int = int(time_contract.get("target_age", player_age_before + 1 if player_age_before >= 0 else -1))
	if not may_advance_player_age:
		player_age_after = player_age_before

	var delta: Dictionary = {
		"year_before": int(time_contract.get("source_year", source_year)),
		"year_after": int(time_contract.get("target_year", target_year)),
		"player_id": player_id,
		"player_age_before": player_age_before,
		"player_age_after": player_age_after,
		"advance_year": may_advance_year,
		"advance_player_age": may_advance_player_age,
		"time_authority": str(rules.get("time_authority", time_contract.get("time_authority", "temporal_slice_runtime"))),
		"deferred_to_time_contract": not may_advance_year or not may_advance_player_age
	}

	frame ["core_identity_delta"] = delta
	active_session ["frame"] = frame

	if may_advance_year:
		_write_conflict_path("core.year", "core_identity", delta.get("year_after", target_year), str(rules.get("conflict_policy", "last_writer_wins")))

	if may_advance_player_age:
		_write_conflict_path("player.age", "core_identity", delta.get("player_age_after", -1), str(rules.get("conflict_policy", "last_writer_wins")))

	return {
		"success": true,
		"slice": slice_id,
		"transform": "advance_core_identity",
		"year_after": delta.get("year_after", target_year),
		"player_age_after": delta.get("player_age_after", -1),
		"advance_year": may_advance_year,
		"advance_player_age": may_advance_player_age,
		"time_authority": str(delta.get("time_authority", ""))
	}


func _transform_npc_biology(slice_id: String, rules: Dictionary) -> Dictionary:
	var frame: Dictionary = active_session.get("frame", {})
	var subset: Array = _safe_array(frame.get("entity_graph_subset", []))
	var target_year: int = int(active_session.get("target_year", gs.year + 1 if gs != null else 0))
	var player_id: int = int(active_session.get("player_id", -1))
	var transformed: Array = []
	var elder_decline_start: int = int(rules.get("elder_decline_start", 60))

	for raw_row in subset:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (raw_row as Dictionary).duplicate(true)
		var npc_id: int = int(row.get("id", -1))
		if npc_id <= 0:
			continue

		if not bool(row.get("alive", true)):
			continue

		var before_age: int = int(row.get("age", 0))
		var after_age: int = before_age + 1

		row ["age_before_temporal"] = before_age
		row ["age"] = after_age
		row ["temporal_biology_year"] = target_year
		row ["temporal_transform_source"] = "live_slice_stream"

		if after_age >= elder_decline_start:
			row ["elder_decline_pending"] = true

		transformed.append(row)
		_write_conflict_path("npc.%d.age" % npc_id, "npc_biology", after_age, str(rules.get("conflict_policy", "last_writer_wins")))

	frame ["entity_graph_subset"] = transformed
	frame ["entity_graph_delta"] = {
		"target_year": target_year,
		"player_id": player_id,
		"rows": transformed,
		"scope": str(frame.get("entity_scope", "player_bubble")),
		"partial": true
	}

	active_session ["frame"] = frame

	return {
		"success": true,
		"slice": slice_id,
		"transform": "increment_age",
		"target_year": target_year,
		"aged_count": transformed.size()
	}


func _transform_market_slice(slice_id: String, rules: Dictionary) -> Dictionary:
	var frame: Dictionary = active_session.get("frame", {})
	var slices: Dictionary = _safe_dictionary(frame.get("slices", {}))
	var inflation_rate: float = float(rules.get("inflation_rate", 0.03))
	var volatility: float = float(rules.get("volatility", 0.2))
	var changed_slice_count: int = 0

	for save_key in slices.keys():
		var key: String = str(save_key)
		if not _slice_key_matches(key, slice_id, ["economy", "market", "global_market", "bank"]):
			continue

		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw
		var data_raw: Variant = row.get("data", {})
		if typeof(data_raw) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = (data_raw as Dictionary).duplicate(true)
		_apply_numeric_market_shift(data, inflation_rate, volatility, str(save_key))
		row ["data"] = data
		row ["temporal_transform"] = "apply_market_shift"
		row ["dirty"] = true
		slices [save_key] = row
		changed_slice_count += 1

	frame ["slices"] = slices
	active_session ["frame"] = frame

	return {
		"success": true,
		"slice": slice_id,
		"transform": "apply_market_shift",
		"changed_slices": changed_slice_count
	}


func _transform_relationship_slice(slice_id: String, rules: Dictionary) -> Dictionary:
	var frame: Dictionary = active_session.get("frame", {})
	var slices: Dictionary = _safe_dictionary(frame.get("slices", {}))
	var changed_slice_count: int = 0

	for save_key in slices.keys():
		var key: String = str(save_key)
		if not _slice_key_matches(key, slice_id, ["relationship", "relationships", "social_graph"]):
			continue

		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw
		var data_raw: Variant = row.get("data", {})
		if typeof(data_raw) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = (data_raw as Dictionary).duplicate(true)
		_apply_relationship_decay(data, rules)
		row ["data"] = data
		row ["temporal_transform"] = "decay_or_strengthen"
		row ["dirty"] = true
		slices [save_key] = row
		changed_slice_count += 1

	frame ["slices"] = slices
	active_session ["frame"] = frame

	return {
		"success": true,
		"slice": slice_id,
		"transform": "decay_or_strengthen",
		"changed_slices": changed_slice_count
	}

func _resolve_age_up_contracts(context: Dictionary) -> Array:
	var explicit_raw: Variant = context.get("age_up_contracts", [])
	if typeof(explicit_raw) == TYPE_ARRAY and not (explicit_raw as Array).is_empty():
		return (explicit_raw as Array).duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var state_contracts_raw: Variant = gs.scenario_state.get("age_up_contracts", [])
		if typeof(state_contracts_raw) == TYPE_ARRAY and not (state_contracts_raw as Array).is_empty():
			return (state_contracts_raw as Array).duplicate(true)

	return [
		{
			"slice": "core_identity",
			"transform": "advance_core_identity",
			"rules": {
				"conflict_policy": "last_writer_wins"
			}
		},
		{
			"slice": "npc_biology",
			"transform": "increment_age",
			"rules": {
				"death_curve": "sigmoid",
				"elder_decline_start": 60,
				"conflict_policy": "last_writer_wins"
			}
		},
		{
			"slice": "economy",
			"transform": "apply_market_shift",
			"rules": {
				"inflation_rate": 0.03,
				"volatility": 0.2,
				"conflict_policy": "merge_numeric"
			}
		},
		{
			"slice": "relationships",
			"transform": "decay_or_strengthen",
			"rules": {
				"distance_decay": true,
				"shared_events_boost": true,
				"conflict_policy": "merge_relationship_edges"
			}
		}
	]


func _apply_numeric_market_shift(data: Dictionary, inflation_rate: float, volatility: float, path_prefix: String) -> void:
	for key in data.keys():
		var value: Variant = data.get(key)

		if typeof(value) == TYPE_DICTIONARY:
			_apply_numeric_market_shift(value as Dictionary, inflation_rate, volatility, "%s.%s" % [path_prefix, str(key)])
			continue

		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue

		var key_text: String = str(key).to_lower()
		var economic_key: bool = key_text.find("price") >= 0 \
or key_text.find("value") >= 0 \
or key_text.find("cost") >= 0 \
or key_text.find("wage") >= 0 \
or key_text.find("market") >= 0

		if not economic_key:
			continue

		var base_value: float = float(value)
		var deterministic_noise: float = _seeded_unit_noise("%s.%s" % [path_prefix, str(key)])
		var shift: float = inflation_rate + ((deterministic_noise - 0.5) * volatility * inflation_rate)
		var next_value: float = max(0.0, base_value * (1.0 + shift))

		if typeof(value) == TYPE_INT:
			data [key] = int(round(next_value))
		else:
			data [key] = next_value


func _apply_relationship_decay(data: Dictionary, rules: Dictionary) -> void:
	for key in data.keys():
		var value: Variant = data.get(key)

		if typeof(value) == TYPE_DICTIONARY:
			_apply_relationship_decay(value as Dictionary, rules)
			continue

		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue

		var key_text: String = str(key).to_lower()
		var relationship_key: bool = key_text.find("relationship") >= 0 \
or key_text.find("bond") >= 0 \
or key_text.find("closeness") >= 0 \
or key_text.find("opinion") >= 0

		if not relationship_key:
			continue

		var current: float = float(value)
		var decay: float = 1.0 if bool(rules.get("distance_decay", true)) else 0.0
		var boosted: float = 1.0 if bool(rules.get("shared_events_boost", true)) else 0.0
		var next_value: float = clamp(current - decay + boosted, 0.0, 100.0)

		if typeof(value) == TYPE_INT:
			data [key] = int(round(next_value))
		else:
			data [key] = next_value


func _write_conflict_path(path: String, writer: String, value: Variant, policy: String = "last_writer_wins") -> void:
	if path == "":
		return

	if conflict_ledger.has(path):
		var existing: Dictionary = conflict_ledger.get(path, {})
		active_session ["conflicts"].append({
			"path": path,
			"first_writer": str(existing.get("writer", "")),
			"second_writer": writer,
			"policy": policy
		})

	conflict_ledger [path] = {
		"writer": writer,
		"value": _make_binary_safe(value),
		"policy": policy
	}


func _seeded_unit_noise(seed_text: String) -> float:
	var source_year: int = int(active_session.get("source_year", 0))
	var target_year: int = int(active_session.get("target_year", 0))
	var player_id: int = int(active_session.get("player_id", -1))
	var seed_value: int = abs(hash("%s|%d|%d|%d" % [seed_text, source_year, target_year, player_id]))
	return float(seed_value % 10000) / 10000.0


func _slice_key_matches(save_key: String, requested_slice: String, aliases: Array) -> bool:
	var clean_key: String = save_key.to_lower()
	var clean_requested: String = requested_slice.to_lower()

	if clean_requested != "" and clean_key.find(clean_requested) >= 0:
		return true

	for alias in aliases:
		var alias_text: String = str(alias).to_lower()
		if alias_text != "" and clean_key.find(alias_text) >= 0:
			return true

	return false


func _ensure_dependencies() -> void:
	if gs == null:
		return

	if gs.has_method("_ensure_load_game_runtime_dependencies"):
		gs._ensure_load_game_runtime_dependencies()

	if gs.game_state_serialization_runtime == null:
		gs.game_state_serialization_runtime = GameStateSerializationRuntime.new(gs)

	if gs.game_state_hydration_runtime == null:
		gs.game_state_hydration_runtime = GameStateHydrationRuntime.new(gs)


func _store_loading_hint(phase: String, subline: String) -> void:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var loading_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	var loading: Dictionary = loading_raw if typeof(loading_raw) == TYPE_DICTIONARY else {}

	loading ["current_phase"] = phase
	loading ["current_micro_lane"] = "live_slice_stream"
	loading ["temporal_slice_streaming_active"] = phase != "complete"
	if subline != "":
		loading ["subline"] = subline

	gs.scenario_state ["loading_runtime"] = loading
	gs.scenario_state ["temporal_slice_streaming_active"] = phase != "complete"


func _fail_report(reason_id: String, reason: String, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": REPORT_SCHEMA,
		"version": TEMPORAL_RUNTIME_VERSION,
		"success": false,
		"state": "failed",
		"is_complete": true,
		"reason_id": reason_id,
		"reason": reason,
		"extra": extra.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_temporal_report = report.duplicate(true)
	if gs != null:
		gs.game_state_temporal_slice_report = last_temporal_report.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["last_temporal_slice_report"] = last_temporal_report.duplicate(true)

	return report


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)