extends Resource
class_name LivePatchGuard

var gs

func _init(_gs):
	gs = _gs

func suggest_mitigation(fault: Dictionary, contract: Dictionary = {}) -> Dictionary:
	var code: String = str(fault.get("code", ""))
	var action: Dictionary = {
		"action": "monitor_only",
		"description": "Observed only. No automatic mitigation was safe enough to apply.",
		"safe": false
	}

	match code:
		"stuck_transition":
			action = {
				"action": "clear_stale_transition_flag",
				"description": "Clear the stale transition flag and cancel the dead panel transition before the next rebuild.",
				"safe": true
			}
		"duplicate_popup_loop":
			action = {
				"action": "quarantine_popup_lane",
				"description": "Quarantine the active popup lane for the current handoff and close duplicate popup surfaces.",
				"safe": true
			}
		"frame_spike", "year_pipeline_backpressure":
			action = {
				"action": "compress_execution_current_year",
				"description": "Force the current year into compressed execution budgets until the visible runtime stabilizes.",
				"safe": true
			}
		"mailbox_payload_invalid":
			action = {
				"action": "suppress_duplicate_event_once",
				"description": "Suppress one invalid/duplicate runtime packet before it propagates further.",
				"safe": true
			}
		"ui_surface_refresh_fault":
			action = {
				"action": "fallback_cached_ui",
				"description": "Use cached visible UI for one handoff instead of forcing a broken refresh.",
				"safe": true
			}

	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		action ["engine_id"] = str(contract.get("engine_id", ""))
		action ["phase_affinity"] = str(contract.get("phase_affinity", ""))
		action ["lane_affinity"] = str(contract.get("lane_affinity", ""))

	return action

func apply_runtime_guard(action: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if bool(gs.scenario_state.get("age_up_truth_probe_disable_live_patch_guard", false)):
		if not bool(gs.scenario_state.get("age_up_truth_probe_live_patch_guard_suppressed_logged", false)):
			EraLog.truth("AGEUP_TRUTH|", {
				"stage": "live_patch_guard_suppressed",
				"action": str(action.get("action", "")) if typeof(action) == TYPE_DICTIONARY else "",
				"at_ms": int(Time.get_ticks_msec())
			})
			gs.scenario_state ["age_up_truth_probe_live_patch_guard_suppressed_logged"] = true
		return
	var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
	var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
	var action_name: String = str(action.get("action", ""))
	var current_year: int = int(gs.year) if gs != null else 0

	match action_name:
		"compress_execution_current_year":
			guard ["compressed_execution_current_year"] = true
			guard ["auto_stability_mode"] = true
			guard ["reduce_scenario_density"] = true
			guard ["defer_noncritical_systems"] = true
			guard ["defer_refresh_once"] = true
			guard ["fallback_cached_ui"] = true
			guard ["control_release_priority"] = "ui_first"
			guard ["phase_budget_cap"] = 1
			guard ["commit_budget_cap"] = 4
			guard ["stall_recovery_threshold"] = 48.0
			guard ["applies_to_year"] = current_year
		"quarantine_popup_lane":
			guard ["quarantine_popup_lane"] = true
		"suppress_duplicate_event_once":
			guard ["suppress_duplicate_event_once"] = true
		"fallback_cached_ui":
			guard ["fallback_cached_ui"] = true
		"defer_refresh":
			guard ["defer_refresh_once"] = true

	guard ["last_action"] = action_name
	guard ["last_action_ms"] = int(Time.get_ticks_msec())
	gs.scenario_state ["runtime_guard"] = guard

func review_ui_snapshot(snapshot: Dictionary) -> Array:
	var actions: Array = []
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		return actions

	var transition_active: bool = bool(snapshot.get("transition_active", false))
	var transition_surface_valid: bool = bool(snapshot.get("transition_surface_valid", true))
	if transition_active and not transition_surface_valid:
		actions.append({
			"action": "clear_stale_transition_flag",
			"description": "Transition was still active even though its surface was gone.",
			"safe": true
		})

	var popup_count: int = int(snapshot.get("popup_count", 0))
	var loading_active: bool = bool(snapshot.get("loading_active", false))
	if popup_count >= 3 and loading_active:
		actions.append({
			"action": "quarantine_popup_lane",
			"description": "Too many popup surfaces were stacked during an active loading/runtime handoff.",
			"safe": true
		})

	return actions