extends Resource
class_name ScenarioPopupContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.scenario_popup_contract_engine_state"
const CONTRACT_SCHEMA:= "eralife.scenario_popup_contract"
const VIEW_CONTRACT_SCHEMA:= "eralife.scenario_popup_view_contract"
const CONTRACT_VERSION:= 1

var gs
var popup_contract_templates: Dictionary = {}
var popup_contract_registry: Dictionary = {}
var popup_contract_observations: Dictionary = {}
var popup_contract_mutation_log: Array = []
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	popup_contract_templates = _safe_dictionary(gs.scenario_state.get("scenario_popup_contract_templates", popup_contract_templates))
	popup_contract_registry = _safe_dictionary(gs.scenario_state.get("scenario_popup_contract_registry", popup_contract_registry))
	popup_contract_observations = _safe_dictionary(gs.scenario_state.get("scenario_popup_contract_observations", popup_contract_observations))
	popup_contract_mutation_log = _safe_array(gs.scenario_state.get("scenario_popup_contract_mutation_log", popup_contract_mutation_log))

	_repair_popup_contract_engine_state()
	_commit_engine_state()


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"popup_contract_templates": popup_contract_templates.duplicate(true),
		"popup_contract_registry": popup_contract_registry.duplicate(true),
		"popup_contract_observations": popup_contract_observations.duplicate(true),
		"popup_contract_mutation_log": popup_contract_mutation_log.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	popup_contract_templates = _safe_dictionary(data.get("popup_contract_templates", data.get("templates", {})))
	popup_contract_registry = _safe_dictionary(data.get("popup_contract_registry", data.get("contracts", {})))
	popup_contract_observations = _safe_dictionary(data.get("popup_contract_observations", data.get("observations", {})))
	popup_contract_mutation_log = _safe_array(data.get("popup_contract_mutation_log", data.get("mutation_log", [])))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_repair_popup_contract_engine_state()
	_commit_engine_state()

	last_report = {
		"success": true,
		"mode": "scenario_popup_contract_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"template_count": popup_contract_templates.size(),
		"registry_count": popup_contract_registry.size(),
		"observation_count": popup_contract_observations.size(),
		"mutation_count": popup_contract_mutation_log.size(),
		"repaired": true
	}

	return last_report.duplicate(true)

func emit_popup_contract(raw_contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var contract: Dictionary = normalize_popup_contract(raw_contract, context)
	if contract.is_empty():
		return {
			"success": false,
			"reason": "empty_contract"
		}

	var contract_id: String = str(contract.get("id", "")).strip_edges()
	if contract_id == "":
		return {
			"success": false,
			"reason": "normalized_contract_missing_id"
		}

	popup_contract_registry [contract_id] = contract.duplicate(true)
	_record_popup_contract_mutation(contract_id, "emitted", {
		"source": str(context.get("source", "emit_popup_contract")),
		"category": str(contract.get("category", "general")),
		"target_id": int(contract.get("target_id", contract.get("target", -1)))
	})

	if gs == null or gs.scenario_runtime_contract_engine == null:
		_commit_engine_state()
		return {
			"success": false,
			"reason": "missing_scenario_runtime_contract_engine",
			"contract": contract
		}

	var report: Dictionary = gs.scenario_runtime_contract_engine.activate_popup_contract(contract)
	last_report = report.duplicate(true)
	last_report ["popup_contract_engine_registry_count"] = popup_contract_registry.size()

	_commit_engine_state()
	return last_report.duplicate(true)

func emit_from_action_result(result: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_result"
		}

	var raw_options: Array = _options_from_action_result(result)
	if raw_options.is_empty():
		return {
			"success": false,
			"reason": "result_has_no_choices"
		}

	var actor_id: int = int(context.get("target", context.get("target_id", -1)))
	if actor_id <= 0 and gs != null and gs.player != null:
		actor_id = int(gs.player.id)

	var issuer_id: int = int(context.get("issuer", context.get("issuer_id", -1)))

	var raw_contract: Dictionary = {
		"id": str(result.get("contract_id", "")).strip_edges(),
		"issuer": issuer_id,
		"target": actor_id,
		"category": str(result.get("category", result.get("scenario_category", "general"))),
		"request": str(result.get("request", result.get("type", "choice"))),
		"title": str(result.get("popup_title", result.get("title", "Pending Situation"))),
		"overview": str(result.get("popup_text", result.get("text", ""))),
		"details": str(result.get("popup_text", result.get("text", ""))),
		"response_options": raw_options,
		"expires_age": float(result.get("expires_age", -1.0)),
		"urgency": float(result.get("urgency", 25.0)),
		"decay": float(result.get("decay", 0.0)),
		"escalation_triggers": result.get("escalation_triggers", []),
		"source_result": result.duplicate(true),
		"created_from": "action_result_popup"
	}

	return emit_popup_contract(raw_contract, context)


func normalize_popup_contract(raw_contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(raw_contract) != TYPE_DICTIONARY:
		return {}

	var now_ms: int = int(Time.get_ticks_msec())
	var now_year: int = int(gs.year) if gs != null else 0

	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", ""))).strip_edges()
	if contract_id == "":
		contract_id = "popup_%d_%d" % [now_ms, abs(int(hash(str(raw_contract)))) % 99999]

	var target_id: int = int(raw_contract.get("target", raw_contract.get("target_id", context.get("target_id", -1))))
	if target_id <= 0 and gs != null and gs.player != null:
		target_id = int(gs.player.id)

	var issuer_id: int = int(raw_contract.get("issuer", raw_contract.get("issuer_id", context.get("issuer_id", -1))))

	var participant_ids: Array = _unique_positive_int_array(raw_contract.get("participant_ids", raw_contract.get("participants", [])))
	if target_id > 0 and target_id not in participant_ids:
		participant_ids.append(target_id)

	var audience_ids: Array = _unique_positive_int_array(raw_contract.get("audience_ids", []))
	var decision_actor_ids: Array = _unique_positive_int_array(raw_contract.get("decision_actor_ids", participant_ids))
	var parent_ids: Array = _unique_positive_int_array(raw_contract.get("parent_ids", []))

	var response_options: Array = _normalize_response_options(raw_contract.get("response_options", raw_contract.get("opps", [])))
	if response_options.is_empty():
		response_options = [
			{
				"id": "acknowledge",
				"label": "Acknowledge",
				"resolution": "acknowledge"
			}
		]

	var urgency: float = clamp(float(raw_contract.get("urgency", 25.0)), 0.0, 100.0)
	var decay: float = clamp(float(raw_contract.get("decay", 0.0)), -100.0, 100.0)
	var category: String = str(raw_contract.get("category", "general")).strip_edges().to_lower()
	if category == "":
		category = "general"

	var request: String = str(raw_contract.get("request", "choice")).strip_edges().to_lower()
	if request == "":
		request = "choice"

	var title: String = str(raw_contract.get("title", raw_contract.get("popup_title", "Pending Situation"))).strip_edges()
	if title == "":
		title = "Pending Situation"

	var overview: String = str(raw_contract.get("overview", raw_contract.get("popup_text", raw_contract.get("text", "")))).strip_edges()
	if overview == "":
		overview = title

	var details: String = str(raw_contract.get("details", overview)).strip_edges()
	if details == "":
		details = overview

	var raw_mesh: Dictionary = _safe_dictionary(raw_contract.get("contract_mesh", {}))
	var contract_mesh: Dictionary = raw_mesh.duplicate(true)
	contract_mesh ["source_of_truth"] = "ScenarioPopupContractEngine"
	contract_mesh ["runtime_owner"] = "ScenarioRuntimeContractEngine"
	contract_mesh ["pending_index_owner"] = "PendingSituationsEngine"
	contract_mesh ["ui_observer"] = "PopupViewer"
	contract_mesh ["persistent"] = true
	contract_mesh ["save_key"] = "scenario_runtime_contract_engine_state"
	contract_mesh ["ui_mutation_allowed"] = false
	contract_mesh ["popup_is_reality_contract"] = true
	contract_mesh ["one_contract_multiple_views"] = bool(raw_contract.get("one_contract_multiple_views", raw_mesh.get("one_contract_multiple_views", true)))

	var contract: Dictionary = {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"issuer": issuer_id,
		"issuer_id": issuer_id,
		"target": target_id,
		"target_id": target_id,
		"participant_ids": participant_ids,
		"audience_ids": audience_ids,
		"decision_actor_ids": decision_actor_ids,
		"parent_ids": parent_ids,
		"custodial_parent_id": int(raw_contract.get("custodial_parent_id", -1)),
		"other_parent_id": int(raw_contract.get("other_parent_id", -1)),
		"perspective_actor_roles": _safe_dictionary(raw_contract.get("perspective_actor_roles", {})),
		"perspective_views": _safe_dictionary(raw_contract.get("perspective_views", {})),
		"follow_up_views": _safe_dictionary(raw_contract.get("follow_up_views", raw_contract.get("reply_views", {}))),
		"shared_decision_model": _safe_dictionary(raw_contract.get("shared_decision_model", {})),
		"category": category,
		"request": request,
		"title": title,
		"overview": overview,
		"details": details,
		"amount": int(raw_contract.get("amount", 0)),
		"currency": str(raw_contract.get("currency", "USD")),
		"state": str(raw_contract.get("state", "pending")).strip_edges().to_lower(),
		"visibility": str(raw_contract.get("visibility", "player_visible")),
		"requires_attention": bool(raw_contract.get("requires_attention", true)),
		"response_options": response_options,
		"selected_response": str(raw_contract.get("selected_response", "")),
		"resolution": _safe_dictionary(raw_contract.get("resolution", {})),
		"urgency": urgency,
		"decay": decay,
		"escalation_stage": max(0, int(raw_contract.get("escalation_stage", 0))),
		"escalation_triggers": _safe_array(raw_contract.get("escalation_triggers", [])),
		"next_escalation_ms": int(raw_contract.get("next_escalation_ms", now_ms + int(raw_contract.get("escalates_after_ms", 15000)))),
		"expires_age": float(raw_contract.get("expires_age", -1.0)),
		"visible_age_min": float(raw_contract.get("visible_age_min", -1.0)),
		"visible_age_max": float(raw_contract.get("visible_age_max", -1.0)),
		"created_year": int(raw_contract.get("created_year", now_year)),
		"created_age": float(raw_contract.get("created_age", float(gs.player.age) if gs != null and gs.player != null else -1.0)),
		"created_at_ms": int(raw_contract.get("created_at_ms", now_ms)),
		"updated_at_ms": now_ms,
		"source": str(raw_contract.get("source", context.get("source", "scenario_popup_contract_engine"))),
		"source_result": _safe_dictionary(raw_contract.get("source_result", {})),
		"contract_mesh": contract_mesh
	}

	if str(contract.get("state", "")) == "":
		contract ["state"] = "pending"

	return contract

func resolve_contract_response(contract_id: String, option_id: String, payload: Dictionary = {}) -> Dictionary:
	if gs == null or gs.scenario_runtime_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_scenario_runtime_contract_engine"
		}

	return gs.scenario_runtime_contract_engine.resolve_popup_contract(contract_id, option_id, payload)


func build_view_contract(contract: Dictionary) -> Dictionary:
	var safe_contract: Dictionary = normalize_popup_contract(contract, {
		"source": "build_view_contract"
	})
	var response_options: Array = _safe_array(safe_contract.get("response_options", []))
	var contract_id: String = str(safe_contract.get("id", "")).strip_edges()

	if contract_id != "":
		_observe_popup_contract(contract_id, "popup_viewer")

	return {
		"schema": VIEW_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"title": str(safe_contract.get("title", "Pending Situation")),
		"overview": str(safe_contract.get("overview", "")),
		"details": str(safe_contract.get("details", safe_contract.get("overview", ""))),
		"category": str(safe_contract.get("category", "general")),
		"urgency": float(safe_contract.get("urgency", 0.0)),
		"state": str(safe_contract.get("state", "pending")),
		"response_options": response_options,
		"contract": safe_contract.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "ScenarioPopupContractEngine",
			"runtime_owner": "ScenarioRuntimeContractEngine",
			"pending_index_owner": "PendingSituationsEngine",
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false
		}
	}
func _commit_engine_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}




	gs.scenario_state [
		"scenario_popup_contract_templates"
	] = popup_contract_templates

	gs.scenario_state [
		"scenario_popup_contract_registry"
	] = popup_contract_registry

	gs.scenario_state [
		"scenario_popup_contract_observations"
	] = popup_contract_observations

	gs.scenario_state [
		"scenario_popup_contract_mutation_log"
	] = popup_contract_mutation_log


func _repair_popup_contract_engine_state() -> void:
	var repaired_templates: Dictionary = {}
	for raw_template_id in popup_contract_templates.keys():
		var template_id: String = str(raw_template_id).strip_edges()
		if template_id == "":
			continue
		var template: Dictionary = _safe_dictionary(popup_contract_templates.get(raw_template_id, {}))
		if template.is_empty():
			continue
		template ["id"] = str(template.get("id", template_id)).strip_edges()
		template ["schema"] = str(template.get("schema", "eralife.scenario_popup_contract_template"))
		template ["version"] = int(template.get("version", CONTRACT_VERSION))
		repaired_templates [template_id] = template

	var repaired_registry: Dictionary = {}
	for raw_contract_id in popup_contract_registry.keys():
		var contract: Dictionary = _safe_dictionary(popup_contract_registry.get(raw_contract_id, {}))
		if contract.is_empty():
			continue
		var normalized: Dictionary = normalize_popup_contract(contract, {
			"source": "repair_popup_contract_registry"
		})
		var contract_id: String = str(normalized.get("id", "")).strip_edges()
		if contract_id == "":
			continue
		repaired_registry [contract_id] = normalized

	popup_contract_templates = repaired_templates
	popup_contract_registry = repaired_registry

	var repaired_observations: Dictionary = {}
	for raw_contract_id in popup_contract_observations.keys():
		var contract_id_text: String = str(raw_contract_id).strip_edges()
		if contract_id_text == "":
			continue
		repaired_observations [contract_id_text] = _safe_dictionary(popup_contract_observations.get(raw_contract_id, {}))
	popup_contract_observations = repaired_observations

	if popup_contract_mutation_log.size() > 200:
		popup_contract_mutation_log = popup_contract_mutation_log.slice(popup_contract_mutation_log.size() - 200, popup_contract_mutation_log.size())


func _observe_popup_contract(contract_id: String, observer_id: String = "unknown") -> void:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return

	var observer: String = str(observer_id).strip_edges()
	if observer == "":
		observer = "unknown"

	var row: Dictionary = _safe_dictionary(popup_contract_observations.get(clean_id, {}))
	row ["contract_id"] = clean_id
	row ["last_observer"] = observer
	row ["observation_count"] = int(row.get("observation_count", 0)) + 1
	row ["last_observed_at_ms"] = int(Time.get_ticks_msec())
	popup_contract_observations [clean_id] = row

	_record_popup_contract_mutation(clean_id, "observed", {
		"observer": observer
	})
	_commit_engine_state()


func _record_popup_contract_mutation(contract_id: String, mutation_type: String, payload: Dictionary = {}) -> void:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return

	popup_contract_mutation_log.append({
		"contract_id": clean_id,
		"mutation_type": str(mutation_type).strip_edges(),
		"payload": payload.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	if popup_contract_mutation_log.size() > 200:
		popup_contract_mutation_log = popup_contract_mutation_log.slice(popup_contract_mutation_log.size() - 200, popup_contract_mutation_log.size())
func _options_from_action_result(result: Dictionary) -> Array:
	var raw_options: Variant = result.get("response_options", result.get("opps", []))
	if typeof(raw_options) == TYPE_ARRAY:
		return raw_options as Array
	return []


func _normalize_response_options(raw_options: Variant) -> Array:
	var out: Array = []
	if typeof(raw_options) != TYPE_ARRAY:
		return out

	for i in range((raw_options as Array).size()):
		var raw_option: Variant = (raw_options as Array) [i]

		if typeof(raw_option) == TYPE_DICTIONARY:
			var row: Dictionary = (raw_option as Dictionary).duplicate(true)
			var option_id: String = str(row.get("id", row.get("choice_id", row.get("resolution", "")))).strip_edges()
			if option_id == "":
				option_id = "option_%d" % i
			row ["id"] = option_id
			row ["label"] = str(row.get("label", row.get("text", option_id.capitalize()))).strip_edges()
			row ["resolution"] = str(row.get("resolution", option_id)).strip_edges()
			out.append(row)
		else:
			var label: String = str(raw_option).strip_edges()
			if label == "":
				continue
			var option_id_from_label: String = label.to_lower().replace(" ", "_")
			out.append({
				"id": option_id_from_label,
				"label": label,
				"resolution": option_id_from_label
			})

	return out


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _unique_positive_int_array(value: Variant) -> Array:
	var out: Array = []
	var raw_array: Array = _safe_array(value)

	for raw_id in raw_array:
		var clean_id: int = int(raw_id)
		if clean_id > 0 and clean_id not in out:
			out.append(clean_id)

	return out
func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []