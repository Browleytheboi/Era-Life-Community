

extends RefCounted
class_name HeirloomHubContractEngine

const ENGINE_SCHEMA:= "eralife.heirloom_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.heirloom_hub_contract"
const HUB_VERSION:= 1
const LENS_KEY:= "heirloom_hub_lenses"

var gs
var lens_state: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	_ensure_lens_state()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	_ensure_lens_state()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_lens_state()
	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"sections": ["overview", "owned", "lineage", "disputes", "market", "history"],
		"truth_authority": "heirloom_runtime_engine",
		"constitutional_authority": "heirloom_contract_engine",
		"catalog_authority": "heirloom_catalog_contract_engine",
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")

	var action_id: String = str(payload.get("action_id", "refresh")).strip_edges().to_lower()
	var section_id: String = _section(str(payload.get("section_id", "overview")))
	var action_result: Dictionary = {}

	if action_id in ["open", "refresh", "change_section", "observe_partial"]:
		_commit_lens(actor, section_id, payload)
	else:
		if gs == null or gs.heirloom_contract_engine == null:
			return _fail("heirloom_contract_engine_unavailable")
		action_result = gs.heirloom_contract_engine.resolve_intent(
			actor,
			payload
		)
		_commit_lens(actor, section_id, payload)

	var hub_contract: Dictionary = emit_heirloom_hub_contract(
		actor,
		{
			"section_id": section_id
		}.merged(payload, true)
	)

	return {
		"success": bool(action_result.get("success", true)),
		"mode": "heirloom_hub_intent_resolved",
		"action_id": action_id,
		"result": action_result,
		"hub_contract": hub_contract,
		"ui_is_renderer_only": true
	}


func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	return emit_heirloom_hub_contract(actor, context)


func emit_heirloom_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	var actor_id: int = int(actor.id)
	var lens: Dictionary = _lens_for(actor_id)
	var active_section: String = _section(
		str(context.get("section_id", lens.get("active_section", "overview")))
	)
	var runtime_records: Array = []
	var disputes: Array = []
	var catalog_objects: Array = []
	var market_objects: Array = []

	if gs != null and gs.heirloom_runtime_engine != null:
		runtime_records = gs.heirloom_runtime_engine.records_for_actor(actor_id)
		disputes = gs.heirloom_runtime_engine.disputes_for_actor(actor_id)

	if gs != null and gs.heirloom_catalog_contract_engine != null:
		catalog_objects = gs.heirloom_catalog_contract_engine.get_available_objects({
			"actor_id": actor_id,
			"include_unowned": false,
			"include_modded": true
		})

	if gs != null and gs.global_object_catalog_system != null:
		market_objects = gs.global_object_catalog_system.get_available_objects({
			"actor_id": actor_id,
			"domain": "heirloom",
			"ownership_scope": "available",
			"include_owned_instances": false,
			"include_catalog_definitions": true,
			"include_modded": true
		})

	var history: Array = []
	for raw_record in runtime_records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue
		for row in _safe_array((raw_record as Dictionary).get("history", [])):
			history.append(row)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": actor_id,
		"active_section": active_section,
		"tabs": _tabs(),
		"summary": {
			"owned_count": runtime_records.size(),
			"catalog_count": catalog_objects.size(),
			"market_count": market_objects.size(),
			"open_dispute_count": _open_dispute_count(disputes),
			"total_prestige": _total_prestige(runtime_records),
			"total_historical_value": _total_historical_value(runtime_records)
		},
		"sections": {
			"overview": _overview_rows(runtime_records, disputes),
			"owned": runtime_records,
			"lineage": _lineage_rows(runtime_records),
			"disputes": disputes,
			"market": market_objects,
			"history": history
		},
		"active_rows": _active_rows(
			active_section,
			runtime_records,
			disputes,
			market_objects,
			history
		),
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(Time.get_ticks_msec())
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"lenses": lens_state.duplicate(true)
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	lens_state = _safe_dictionary(data.get("lenses", {}))
	_ensure_lens_state()
	return {
		"success": true,
		"mode": "heirloom_hub_lenses_imported",
		"lens_count": lens_state.size()
	}


func _overview_rows(
	records: Array,
	disputes: Array
) -> Array:
	return [
		{
			"kind": "metric",
			"label": "Owned Heirlooms",
			"value": records.size()
		},
		{
			"kind": "metric",
			"label": "Open Claims",
			"value": _open_dispute_count(disputes)
		},
		{
			"kind": "metric",
			"label": "Lineage Prestige",
			"value": _total_prestige(records)
		}
	]


func _lineage_rows(
	records: Array
) -> Array:
	var out: Array = []
	for raw_record in records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = raw_record as Dictionary
		out.append({
			"object_id": str(record.get("object_id", "")),
			"display_name": str(record.get("display_name", "Heirloom")),
			"lineage_id": str(record.get("lineage_id", "")),
			"inheritance_count": int(record.get("inheritance_count", 0)),
			"ownership_chain": _safe_array(record.get("ownership_chain", [])),
			"prestige": float(record.get("prestige", 0.0))
		})
	return out


func _active_rows(
	section_id: String,
	records: Array,
	disputes: Array,
	market: Array,
	history: Array
) -> Array:
	match section_id:
		"owned":
			return records
		"lineage":
			return _lineage_rows(records)
		"disputes":
			return disputes
		"market":
			return market
		"history":
			return history
		_:
			return _overview_rows(records, disputes)


func _tabs() -> Array:
	return [
		{ "id": "overview", "label": "Overview"},
		{ "id": "owned", "label": "Owned"},
		{ "id": "lineage", "label": "Lineage"},
		{ "id": "disputes", "label": "Claims"},
		{ "id": "market", "label": "Available"},
		{ "id": "history", "label": "History"}
	]


func _section(
	value: String
) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	if clean not in ["overview", "owned", "lineage", "disputes", "market", "history"]:
		return "overview"
	return clean


func _commit_lens(
	actor: Person,
	section_id: String,
	payload: Dictionary = {}
) -> void:
	var key: String = str(int(actor.id))
	lens_state [key] = {
		"active_section": _section(section_id),
		"selected_object_id": str(payload.get("object_id", "")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_sync_lens_state()


func _lens_for(
	actor_id: int
) -> Dictionary:
	return _safe_dictionary(
		lens_state.get(
			str(actor_id),
			{
				"active_section": "overview",
				"selected_object_id": ""
			}
		)
	)


func _ensure_lens_state() -> void:
	if lens_state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		lens_state = _safe_dictionary(gs.scenario_state.get(LENS_KEY, {}))
	_sync_lens_state()


func _sync_lens_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [LENS_KEY] = lens_state.duplicate(true)


func _open_dispute_count(
	disputes: Array
) -> int:
	var count: int = 0
	for raw_dispute in disputes:
		if typeof(raw_dispute) == TYPE_DICTIONARY and str((raw_dispute as Dictionary).get("state", "open")) == "open":
			count += 1
	return count


func _total_prestige(
	records: Array
) -> float:
	var total: float = 0.0
	for raw_record in records:
		if typeof(raw_record) == TYPE_DICTIONARY:
			total += float((raw_record as Dictionary).get("prestige", 0.0))
	return total


func _total_historical_value(
	records: Array
) -> float:
	var total: float = 0.0
	for raw_record in records:
		if typeof(raw_record) == TYPE_DICTIONARY:
			total += float((raw_record as Dictionary).get("historical_value", 0.0))
	return total


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
		"mode": "heirloom_hub_contract_rejected",
		"ui_is_renderer_only": true
	}