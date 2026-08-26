extends Resource
class_name AutoPatchEngine

var gs

func _init(_gs):
	gs = _gs

func maybe_generate_auto_patch(
	fault: Dictionary,
	contract: Dictionary = {},
	snapshot: Dictionary = {},
	patch_card: Dictionary = {}
) -> Dictionary:
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY and bool(gs.scenario_state.get("age_up_truth_probe_disable_auto_patcher", false)):
		if not bool(gs.scenario_state.get("age_up_truth_probe_auto_patcher_suppressed_logged", false)):
			EraLog.truth("AGEUP_TRUTH|", {
				"stage": "auto_patcher_suppressed",
				"fault_code": str(fault.get("code", "")) if typeof(fault) == TYPE_DICTIONARY else "",
				"engine_id": str(fault.get("engine_id", "")) if typeof(fault) == TYPE_DICTIONARY else "",
				"at_ms": int(Time.get_ticks_msec())
			})
			gs.scenario_state ["age_up_truth_probe_auto_patcher_suppressed_logged"] = true
		return {}

	if typeof(fault) != TYPE_DICTIONARY or fault.is_empty():
		return {}
	if int(fault.get("occurrences", 0)) < 2:
		return {}

	var code: String = str(fault.get("code", ""))
	var engine_id: String = str(fault.get("engine_id", ""))
	var current_phase: String = str(fault.get("current_phase", snapshot.get("current_phase", "")))

	if code == "frame_spike" and engine_id == "ui.main_scene.surface_runtime":
		return {
			"patch_key": "ui_frame_spike_live_diagnostics_throttle",
			"signature": str(fault.get("signature", "")),
			"target_engine": "MainScene.gd",
			"target_function": "_refresh_live_diagnostics_panel",
			"companion_patches": [
				{ "engine": "LiveDiagnosticsEngine.gd", "function": "observe_ui_snapshot"},
				{ "engine": "PatchSuggestionEngine.gd", "function": "build_patch_card"}
			],
			"reason": "Repeated frame-spike signatures are coming from the live diagnostics shell while runtime work is still in flight. Throttle diagnostics repaint, require sustained over-budget frames before routing a fault, and attribute the patch card to the phase owner instead of the observer shell.",
			"recommended_phase": current_phase,
			"confidence": 0.93,
			"contract_engine_id": str(contract.get("engine_id", "")),
			"latest_patch_card_source": str(patch_card.get("likely_source_function", "")),
			"exact_before_after_available": true
		}

	if code == "year_pipeline_backpressure":
		return {
			"patch_key": "runtime_pipeline_backpressure_guard",
			"signature": str(fault.get("signature", "")),
			"target_engine": "AgeUpRuntimeEngine.gd",
			"target_function": "_drive_age_up_loading_runtime",
			"companion_patches": [
				{ "engine": "AgeUpRuntimeEngine.gd", "function": "_update_loading_runtime_bucket"}
			],
			"reason": "The visible runtime is repeatedly stalling because the year pipeline remains pending too long while the UI is still interactive.",
			"recommended_phase": current_phase,
			"confidence": 0.89,
			"contract_engine_id": str(contract.get("engine_id", "")),
			"latest_patch_card_source": str(patch_card.get("likely_source_function", "")),
			"exact_before_after_available": true
		}

	return {}