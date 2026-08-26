extends Resource
class_name GodModePanelContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.god_mode_panel_contract_engine_state"
const PANEL_CAPTURE_SCHEMA:= "eralife.god_mode_panel.capture_contract"
const PANEL_PREWARM_SCHEMA:= "eralife.god_mode_panel.prewarm_emit_contract"
const PANEL_HANDOFF_SCHEMA:= "eralife.god_mode_panel.handoff_emit_contract"
const CONTRACT_VERSION:= 1
const MAX_PANEL_CONTRACTS:= 120

var gs
var sequence: int = 0
var panel_contracts: Dictionary = {}
var last_capture: Dictionary = {}
var last_prewarm_contract: Dictionary = {}
var last_handoff_contract: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	sequence = int(gs.scenario_state.get("god_mode_panel_contract_sequence", sequence))
	panel_contracts = _safe_dictionary(gs.scenario_state.get("god_mode_panel_contracts", panel_contracts))
	last_capture = _safe_dictionary(gs.scenario_state.get("god_mode_panel_last_capture", last_capture))
	last_prewarm_contract = _safe_dictionary(gs.scenario_state.get("god_mode_panel_last_prewarm_contract", last_prewarm_contract))
	last_handoff_contract = _safe_dictionary(gs.scenario_state.get("god_mode_panel_last_handoff_contract", last_handoff_contract))
	last_report = _safe_dictionary(gs.scenario_state.get("god_mode_panel_last_report", last_report))


func capture_panel_state(panel_state: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if typeof(panel_state) != TYPE_DICTIONARY or panel_state.is_empty():
		last_report = {
			"success": false,
			"reason": "invalid_panel_state",
			"schema": PANEL_CAPTURE_SCHEMA,
			"version": CONTRACT_VERSION
		}
		_commit_state()
		return last_report.duplicate(true)

	sequence += 1

	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_panel_capture_%d_%d" % [sequence, now_ms]

	var capture: Dictionary = {
		"schema": PANEL_CAPTURE_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "capture_god_mode_panel_state",
		"panel_state": panel_state.duplicate(true),
		"settings": panel_state.duplicate(true),
		"source": str(context.get("source", "god_mode_panel")),
		"ui_role": "capture_only",
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	last_capture = capture.duplicate(true)
	panel_contracts [contract_id] = capture.duplicate(true)
	_trim_contracts()

	last_report = {
		"success": true,
		"mode": "god_mode_panel_state_captured",
		"contract_id": contract_id,
		"capture": capture.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)


func emit_prewarm_contract(panel_state: Dictionary, context: Dictionary = {}) -> Dictionary:
	var capture_report: Dictionary = capture_panel_state(panel_state, context)
	if not bool(capture_report.get("success", false)):
		return capture_report

	sequence += 1

	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_panel_prewarm_%d_%d" % [sequence, now_ms]
	var capture: Dictionary = _safe_dictionary(capture_report.get("capture", {}))
	var settings: Dictionary = _safe_dictionary(capture.get("settings", panel_state))

	last_prewarm_contract = {
		"schema": PANEL_PREWARM_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "emit_prewarm_contract",
		"settings": settings.duplicate(true),
		"panel_capture_contract_id": str(capture.get("contract_id", "")),
		"target_consumer": "GodModeTrackerContractEngine",
		"secondary_consumer": "RealityOrchestrator",
		"panel_role_after_emit": "non_runtime",
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	panel_contracts [contract_id] = last_prewarm_contract.duplicate(true)
	_trim_contracts()

	last_report = {
		"success": true,
		"mode": "god_mode_panel_prewarm_contract_emitted",
		"contract_id": contract_id,
		"settings": settings.duplicate(true),
		"prewarm_contract": last_prewarm_contract.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)


func emit_handoff_contract(ready_settings: Dictionary, ready_signature: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if typeof(ready_settings) != TYPE_DICTIONARY or ready_settings.is_empty():
		last_report = {
			"success": false,
			"reason": "invalid_ready_settings",
			"schema": PANEL_HANDOFF_SCHEMA,
			"version": CONTRACT_VERSION
		}
		_commit_state()
		return last_report.duplicate(true)

	var signature: String = str(ready_signature).strip_edges()
	if signature == "":
		last_report = {
			"success": false,
			"reason": "missing_ready_signature",
			"schema": PANEL_HANDOFF_SCHEMA,
			"version": CONTRACT_VERSION
		}
		_commit_state()
		return last_report.duplicate(true)

	sequence += 1

	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_panel_handoff_%d_%d" % [sequence, now_ms]

	last_handoff_contract = {
		"schema": PANEL_HANDOFF_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "emit_handoff_contract",
		"signature": signature,
		"settings": ready_settings.duplicate(true),
		"target_consumer": "GodModeTrackerContractEngine",
		"secondary_consumer": "RealityOrchestrator",
		"final_consumer": "MainscenePlayableSurfaceRenderer",
		"panel_role_after_emit": "terminated_non_runtime",
		"handoff_policy": {
		},
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	panel_contracts [contract_id] = last_handoff_contract.duplicate(true)
	_trim_contracts()

	last_report = {
		"success": true,
		"mode": "god_mode_panel_handoff_contract_emitted",
		"contract_id": contract_id,
		"signature": signature,
		"settings": ready_settings.duplicate(true),
		"handoff_contract": last_handoff_contract.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"panel_contracts": panel_contracts.duplicate(true),
		"last_capture": last_capture.duplicate(true),
		"last_prewarm_contract": last_prewarm_contract.duplicate(true),
		"last_handoff_contract": last_handoff_contract.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func _trim_contracts() -> void:
	while panel_contracts.size() > MAX_PANEL_CONTRACTS:
		var oldest_key: String = str(panel_contracts.keys() [0])
		panel_contracts.erase(oldest_key)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["god_mode_panel_contract_sequence"] = sequence
	gs.scenario_state ["god_mode_panel_contracts"] = panel_contracts.duplicate(true)
	gs.scenario_state ["god_mode_panel_last_capture"] = last_capture.duplicate(true)
	gs.scenario_state ["god_mode_panel_last_prewarm_contract"] = last_prewarm_contract.duplicate(true)
	gs.scenario_state ["god_mode_panel_last_handoff_contract"] = last_handoff_contract.duplicate(true)
	gs.scenario_state ["god_mode_panel_last_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}