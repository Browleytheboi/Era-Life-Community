extends Resource
class_name GodModeTrackerContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.god_mode_tracker_contract_engine_state"
const TRACKER_CONTRACT_SCHEMA:= "eralife.god_mode_tracker.contract"
const PREWARM_CONTRACT_SCHEMA:= "eralife.god_mode_tracker.prewarm_contract"
const HANDOFF_CONTRACT_SCHEMA:= "eralife.god_mode_tracker.handoff_contract"
const CONTRACT_VERSION:= 1
const MAX_TRACKER_CONTRACTS:= 120

var gs
var tracker_sequence: int = 0
var tracked_settings: Dictionary = {}
var tracked_signature: String = ""
var prewarm_contract: Dictionary = {}
var handoff_contract: Dictionary = {}
var tracker_contracts: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	tracker_sequence = int(gs.scenario_state.get("god_mode_tracker_sequence", tracker_sequence))
	tracked_settings = _safe_dictionary(gs.scenario_state.get("god_mode_tracker_tracked_settings", tracked_settings))
	tracked_signature = str(gs.scenario_state.get("god_mode_tracker_tracked_signature", tracked_signature)).strip_edges()
	prewarm_contract = _safe_dictionary(gs.scenario_state.get("god_mode_tracker_prewarm_contract", prewarm_contract))
	handoff_contract = _safe_dictionary(gs.scenario_state.get("god_mode_tracker_handoff_contract", handoff_contract))
	tracker_contracts = _safe_dictionary(gs.scenario_state.get("god_mode_tracker_contracts", tracker_contracts))
	last_report = _safe_dictionary(gs.scenario_state.get("god_mode_tracker_last_report", last_report))


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"tracker_sequence": tracker_sequence,
		"tracked_settings": tracked_settings.duplicate(true),
		"tracked_signature": tracked_signature,
		"prewarm_contract": prewarm_contract.duplicate(true),
		"handoff_contract": handoff_contract.duplicate(true),
		"tracker_contracts": tracker_contracts.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		last_report = {
			"success": false,
			"reason": "invalid_data",
			"schema": ENGINE_STATE_SCHEMA,
			"version": CONTRACT_VERSION
		}
		return last_report.duplicate(true)

	tracker_sequence = int(data.get("tracker_sequence", data.get("god_mode_tracker_sequence", 0)))
	tracked_settings = _safe_dictionary(data.get("tracked_settings", data.get("god_mode_tracker_tracked_settings", {})))
	tracked_signature = str(data.get("tracked_signature", data.get("god_mode_tracker_tracked_signature", ""))).strip_edges()
	prewarm_contract = _safe_dictionary(data.get("prewarm_contract", data.get("god_mode_tracker_prewarm_contract", {})))
	handoff_contract = _safe_dictionary(data.get("handoff_contract", data.get("god_mode_tracker_handoff_contract", {})))
	tracker_contracts = _safe_dictionary(data.get("tracker_contracts", data.get("god_mode_tracker_contracts", {})))
	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_tracker_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"tracked_signature": tracked_signature,
		"prewarm_ready": bool(prewarm_contract.get("prewarm_ready", false)),
		"handoff_stage": str(handoff_contract.get("handoff_stage", "")),
		"imported_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)


func track_panel_settings(settings: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if typeof(settings) != TYPE_DICTIONARY or settings.is_empty():
		last_report = {
			"success": false,
			"reason": "invalid_settings",
			"schema": TRACKER_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION
		}
		return last_report.duplicate(true)

	tracker_sequence += 1

	var signature: String = str(context.get("signature", tracked_signature)).strip_edges()
	var contract_id: String = "god_mode_tracker_panel_%d_%d" % [
		tracker_sequence,
		int(Time.get_ticks_msec())
	]

	tracked_settings = settings.duplicate(true)
	tracked_signature = signature

	var contract: Dictionary = {
		"schema": TRACKER_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "track_god_mode_panel_settings",
		"source": str(context.get("source", "god_mode_panel")),
		"signature": signature,
		"settings": tracked_settings.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	tracker_contracts [contract_id] = contract.duplicate(true)
	_trim_contracts()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_panel_settings_tracked",
		"contract_id": contract_id,
		"signature": signature,
		"settings": tracked_settings.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func mark_prewarm_queued(settings: Dictionary, signature: String, context: Dictionary = {}) -> Dictionary:
	track_panel_settings(settings, {
		"source": str(context.get("source", "god_mode_prewarm_queued")),
		"signature": signature,
	})

	prewarm_contract = {
		"schema": PREWARM_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "god_mode_prewarm_queued",
		"signature": signature,
		"settings": settings.duplicate(true),
		"prewarm_ready": false,
		"prewarm_pending": true,
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_tracker_prewarm_queued",
		"signature": signature,
		"prewarm_contract": prewarm_contract.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func mark_prewarm_ready(settings: Dictionary, signature: String, capsule_contract: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	track_panel_settings(settings, {
		"source": str(context.get("source", "god_mode_prewarm_ready")),
		"signature": signature,
		"prewarm_ready": true
	})

	prewarm_contract = {
		"schema": PREWARM_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "god_mode_prewarm_ready",
		"signature": signature,
		"settings": settings.duplicate(true),
		"capsule_contract": capsule_contract.duplicate(true),
		"prewarm_ready": true,
		"prewarm_pending": false,
		"panel_role_after_ready": "handoff_only",
		"blank_shell_forbidden": true,
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_tracker_prewarm_ready",
		"signature": signature,
		"prewarm_contract": prewarm_contract.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func claim_handoff(settings: Dictionary, signature: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if signature.strip_edges() == "":
		last_report = {
			"success": false,
			"reason": "missing_signature"
		}
		return last_report.duplicate(true)

	tracker_sequence += 1

	var contract_id: String = "god_mode_tracker_handoff_%d_%d" % [
		tracker_sequence,
		int(Time.get_ticks_msec())
	]

	handoff_contract = {
		"schema": HANDOFF_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "god_mode_to_playable_life_handoff",
		"handoff_stage": "entry_claimed",
		"signature": signature,
		"settings": settings.duplicate(true),
		"panel_role": "handoff_surface_only",
		"consume_mode": "hot_prewarmed_capsule",
		"visual_policy": {
			"blank_shell_forbidden": true,
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_handoff_claimed",
		"contract_id": contract_id,
		"signature": signature,
		"handoff_contract": handoff_contract.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func claim_playable_surface(snapshot: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if handoff_contract.is_empty():
		handoff_contract = {
			"schema": HANDOFF_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"mode": "god_mode_to_playable_life_handoff",
			"handoff_stage": "surface_claimed",
			"created_at_ms": int(Time.get_ticks_msec())
		}

	handoff_contract ["handoff_stage"] = "surface_claimed"
	handoff_contract ["playable_surface_claimed"] = true
	handoff_contract ["playable_surface_claimed_at_ms"] = int(Time.get_ticks_msec())
	handoff_contract ["playable_surface_snapshot"] = snapshot.duplicate(true)
	handoff_contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	handoff_contract ["context"] = context.duplicate(true)

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_playable_surface_claimed",
		"handoff_contract": handoff_contract.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func mark_entry_complete(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if handoff_contract.is_empty():
		handoff_contract = {
			"schema": HANDOFF_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"mode": "god_mode_to_playable_life_handoff",
			"created_at_ms": int(Time.get_ticks_msec())
		}

	handoff_contract ["handoff_stage"] = "entry_complete"
	handoff_contract ["entry_complete"] = true
	handoff_contract ["entry_complete_at_ms"] = int(Time.get_ticks_msec())
	handoff_contract ["panel_released_after_playable_ui"] = true
	handoff_contract ["blank_shell_seen"] = false
	handoff_contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	handoff_contract ["context"] = context.duplicate(true)

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_entry_complete",
		"handoff_contract": handoff_contract.duplicate(true)
	}
	_commit_state()
	return last_report.duplicate(true)


func abort_handoff(reason: String = "aborted") -> Dictionary:
	_ensure_state()

	handoff_contract ["handoff_stage"] = "aborted"
	handoff_contract ["entry_complete"] = false
	handoff_contract ["aborted"] = true
	handoff_contract ["abort_reason"] = reason
	handoff_contract ["aborted_at_ms"] = int(Time.get_ticks_msec())
	handoff_contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	_commit_state()

	last_report = {
		"success": true,
		"mode": "god_mode_handoff_aborted",
		"reason": reason
	}
	_commit_state()
	return last_report.duplicate(true)


func ready_settings() -> Dictionary:
	_ensure_state()
	if not bool(prewarm_contract.get("prewarm_ready", false)):
		return {}
	return _safe_dictionary(prewarm_contract.get("settings", tracked_settings))


func ready_signature() -> String:
	_ensure_state()
	if bool(prewarm_contract.get("prewarm_ready", false)):
		return str(prewarm_contract.get("signature", tracked_signature)).strip_edges()
	return tracked_signature


func current_handoff_stage() -> String:
	_ensure_state()
	return str(handoff_contract.get("handoff_stage", "")).strip_edges()


func current_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"tracked_signature": tracked_signature,
		"tracked_settings": tracked_settings.duplicate(true),
		"prewarm_contract": prewarm_contract.duplicate(true),
		"handoff_contract": handoff_contract.duplicate(true),
		"handoff_stage": str(handoff_contract.get("handoff_stage", "")),
		"prewarm_ready": bool(prewarm_contract.get("prewarm_ready", false))
	}


func _trim_contracts() -> void:
	while tracker_contracts.size() > MAX_TRACKER_CONTRACTS:
		var oldest_key: String = str(tracker_contracts.keys() [0])
		tracker_contracts.erase(oldest_key)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["god_mode_tracker_sequence"] = tracker_sequence
	gs.scenario_state ["god_mode_tracker_tracked_settings"] = tracked_settings.duplicate(true)
	gs.scenario_state ["god_mode_tracker_tracked_signature"] = tracked_signature
	gs.scenario_state ["god_mode_tracker_prewarm_contract"] = prewarm_contract.duplicate(true)
	gs.scenario_state ["god_mode_tracker_handoff_contract"] = handoff_contract.duplicate(true)
	gs.scenario_state ["god_mode_tracker_contracts"] = tracker_contracts.duplicate(true)
	gs.scenario_state ["god_mode_tracker_last_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}