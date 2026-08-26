extends Resource
class_name PatchSuggestionEngine

var gs

func _init(_gs):
	gs = _gs

func build_patch_card(fault: Dictionary, snapshot: Dictionary = {}) -> Dictionary:
	var engine_id: String = str(fault.get("engine_id", ""))
	var contract: Dictionary = {}
	if gs != null and gs.runtime_health_registry != null:
		contract = gs.runtime_health_registry.get_contract(engine_id)

	var code: String = str(fault.get("code", "unknown_fault"))
	var domain: String = str(fault.get("domain", "runtime"))
	var source_resolution: Dictionary = _resolve_fault_source(fault, contract, snapshot)
	var source_function: String = str(source_resolution.get("function_name", "unknown")).strip_edges()
	var source_engine: String = str(source_resolution.get("engine_name", engine_id)).strip_edges()
	if source_function == "":
		source_function = "unknown"

	var invariant_text: String = "A runtime invariant appears to have been broken."
	var permanent_patch: String = "Add a narrower guard and keep the failing state localized."
	var confidence: float = 0.42

	match code:
		"stuck_transition":
			invariant_text = "A transition flag stayed active after its surface stopped being valid."
			permanent_patch = "Guard transition teardown with a surface-validity check and force-cancel stale panel transitions before the next UI rebuild."
			confidence = 0.88
		"duplicate_popup_loop":
			invariant_text = "Too many overlapping popup surfaces were active in the same interaction lane."
			permanent_patch = "Deduplicate popup entry points and quarantine the popup lane when multiple surfaces try to own the same handoff."
			confidence = 0.82
		"frame_spike":
			invariant_text = "The visible frame budget was exceeded while UI/runtime work was still in flight."
			permanent_patch = "Throttle diagnostics repaint, require sustained over-budget frames before routing a fault, and attribute the spike to the active phase owner instead of the observer shell."
			confidence = 0.9 if bool(fault.get("observer_only", false)) or bool(contract.get("observer_only", false)) else 0.76
		"year_pipeline_backpressure":
			invariant_text = "The year-budget pipeline stayed pending long enough to threaten a visible stall."
			permanent_patch = "Downgrade the current year to compressed execution and surface pipeline stage metadata so the stall is explainable."
			confidence = 0.86
		"mailbox_payload_invalid":
			invariant_text = "A mailbox payload shape did not match the runtime contract for the phase that consumed it."
			permanent_patch = "Validate mailbox payload shape at the boundary and suppress duplicate/invalid packets before downstream UI reads them."
			confidence = 0.84
		_:
			if not contract.is_empty():
				confidence = 0.61

	var mitigation_text: String = str(fault.get("temporary_mitigation", "monitor_only"))
	var patch_card: Dictionary = {
		"signature": str(fault.get("signature", "")),
		"domain": domain,
		"severity": str(fault.get("severity", "warning")),
		"engine_id": engine_id,
		"likely_source_engine": source_engine,
		"likely_source_function": source_function,
		"failing_state_snapshot": snapshot.duplicate(true),
		"probable_invariant": invariant_text,
		"temporary_mitigation_applied": mitigation_text,
		"recommended_permanent_patch": permanent_patch,
		"auto_patch_family": str(contract.get("auto_patch_family", "")),
		"confidence": clamp(confidence, 0.0, 0.99),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return patch_card
func _resolve_fault_source(fault: Dictionary, contract: Dictionary = {}, snapshot: Dictionary = {}) -> Dictionary:
	var hinted_function: String = str(fault.get("fault_source_hint", "")).strip_edges()
	var hinted_engine: String = str(fault.get("fault_source_engine_hint", "")).strip_edges()
	if hinted_function != "":
		return {
			"function_name": hinted_function,
			"engine_name": hinted_engine if hinted_engine != "" else str(contract.get("fault_source_engine", "unknown"))
		}

	var engine_id: String = str(fault.get("engine_id", "unknown"))
	var current_phase: String = str(fault.get("current_phase", snapshot.get("current_phase", "")))

	if bool(fault.get("observer_only", false)) or bool(contract.get("observer_only", false)):
		var phase_owner_hints_raw: Variant = contract.get("phase_owner_hints", {})
		var phase_owner_hints: Dictionary = phase_owner_hints_raw if typeof(phase_owner_hints_raw) == TYPE_DICTIONARY else {}
		var phase_owner_hint: String = str(phase_owner_hints.get(current_phase, "")).strip_edges()
		if phase_owner_hint != "":
			var parts: PackedStringArray = phase_owner_hint.split("::")
			if parts.size() >= 2:
				return {
					"engine_name": parts [0],
					"function_name": parts [1]
				}
		return {
			"engine_name": str(contract.get("fault_source_engine", "MainScene.gd")),
			"function_name": str(contract.get("fault_source_function", "_process"))
		}

	var contract_method: String = str(contract.get("method_name", "")).strip_edges()
	if contract_method != "":
		return {
			"engine_name": str(contract.get("fault_source_engine", engine_id)),
			"function_name": contract_method
		}

	match str(fault.get("code", "")):
		"stuck_transition":
			return { "engine_name": "MainScene.gd", "function_name": "_force_post_age_up_ui_refresh"}
		"duplicate_popup_loop":
			return { "engine_name": "MainScene.gd", "function_name": "_refresh_live_diagnostics_panel"}
		"frame_spike":
			return { "engine_name": "MainScene.gd", "function_name": "_process"}
		"year_pipeline_backpressure":
			return { "engine_name": "AgeUpRuntimeEngine.gd", "function_name": "run_year_runtime_slice"}
		"mailbox_payload_invalid":
			return { "engine_name": "AgeUpRuntimeEngine.gd", "function_name": "_update_loading_runtime_bucket"}
		_:
			return { "engine_name": engine_id, "function_name": "unknown"}