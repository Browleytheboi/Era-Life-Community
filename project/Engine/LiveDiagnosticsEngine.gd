extends Resource
class_name LiveDiagnosticsEngine

var gs
var latest_ui_snapshot: Dictionary = {}
var latest_loading_snapshot: Dictionary = {}
var latest_router_result: Dictionary = {}
var last_fault_signature: String = ""
var last_fault_ms: int = 0
var frame_spike_threshold_ms: float = 28.0
var last_ui_snapshot_signature: String = ""
var last_ui_snapshot_recorded_ms: int = 0
var consecutive_frame_spike_count: int = 0
func _init(_gs):
	gs = _gs

func bootstrap_runtime_watchers() -> void:
	if gs == null or gs.runtime_health_registry == null:
		return

	gs.runtime_health_registry.register_contract(
		"age_up_runtime.loading_runtime",
		{
			"engine_id": "age_up_runtime.loading_runtime",
			"phase_affinity": "runtime_slice",
			"lane_affinity": "runtime",
			"method_name": "_update_loading_runtime_bucket",
			"required_inputs": ["scenario_state.loading_runtime", "phase_timings_ms", "year_budget_engine"],
			"forbidden_states": ["missing_loading_bucket", "stuck_complete_flag", "phase_without_lane"],
			"mailboxes_read": ["mutation", "scenario", "delta_packets"],
			"mailboxes_write": ["loading_runtime"],
			"ui_surfaces_touched": ["age_up_loading_overlay", "live_diagnostics_panel"],
			"can_defer": true,
			"can_compress": true,
			"can_quarantine": false,
			"health_checks": ["frame_spike", "year_pipeline_backpressure", "mailbox_payload_invalid"]
		}
	)

	gs.runtime_health_registry.register_contract(
		"year_budget_engine.pipeline",
		{
			"engine_id": "year_budget_engine.pipeline",
			"phase_affinity": "year_budget_pipeline_commit",
			"lane_affinity": "lane_c",
			"method_name": "drain_pending_year_pipeline",
			"required_inputs": ["pipeline_stage", "pipeline_groups"],
			"forbidden_states": ["pipeline_running_without_stage", "pipeline_stage_overflow"],
			"mailboxes_read": ["delta_packets"],
			"mailboxes_write": ["mutation"],
			"ui_surfaces_touched": [],
			"can_defer": true,
			"can_compress": true,
			"can_quarantine": false,
			"health_checks": ["year_pipeline_backpressure"]
		}
	)

func observe_loading_bucket(bucket: Dictionary) -> void:
	if typeof(bucket) != TYPE_DICTIONARY or bucket.is_empty():
		return
	latest_loading_snapshot = bucket.duplicate(true)
	if gs != null and gs.runtime_health_registry != null:
		gs.runtime_health_registry.record_snapshot({
			"source": "loading_runtime",
			"current_phase": str(bucket.get("current_phase", "")),
			"current_lane": str(bucket.get("current_lane", "")),
			"stall_score": float(bucket.get("stall_score", 0.0)),
			"year_pipeline_stage": int(bucket.get("year_pipeline_stage", 0)),
			"time_ms": int(Time.get_ticks_msec())
		})

	var stall_score: float = float(bucket.get("stall_score", 0.0))
	var total_runtime_ms: int = int(bucket.get("total_runtime_ms", 0))
	if stall_score >= 92.0 or (bool(bucket.get("year_pipeline_pending", false)) and total_runtime_ms >= 480):
		_route_fault_once(
			"runtime",
			"year_pipeline_backpressure",
			{
				"engine_id": "age_up_runtime.loading_runtime",
				"severity": "warning",
				"stall_score": stall_score,
				"current_phase": str(bucket.get("current_phase", "")),
				"current_lane": str(bucket.get("current_lane", ""))
			},
			latest_ui_snapshot
		)

func observe_ui_snapshot(snapshot: Dictionary, delta: float) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		return
	latest_ui_snapshot = snapshot.duplicate(true)
	latest_ui_snapshot ["frame_ms"] = float(delta) * 1000.0

	var now_ms: int = int(Time.get_ticks_msec())
	var observation_signature: String = "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(latest_ui_snapshot.get("current_panel", "")),
		str(latest_ui_snapshot.get("current_phase", "")),
		str(latest_ui_snapshot.get("current_lane", "")),
		str(latest_ui_snapshot.get("popup_count", 0)),
		str(latest_ui_snapshot.get("loading_active", false)),
		str(latest_ui_snapshot.get("year_pipeline_stage", 0)),
		str(latest_ui_snapshot.get("observer_suppressed", false)),
		str(latest_ui_snapshot.get("restore_gate_active", false))
	]

	var signature_changed: bool = observation_signature != last_ui_snapshot_signature
	var loading_active: bool = bool(latest_ui_snapshot.get("loading_active", false))
	var observer_suppressed: bool = bool(latest_ui_snapshot.get("observer_suppressed", false))
	var should_record_snapshot: bool = signature_changed or (loading_active and not observer_suppressed) or (now_ms - last_ui_snapshot_recorded_ms) >= 180
	if should_record_snapshot and gs != null and gs.runtime_health_registry != null:
		gs.runtime_health_registry.record_snapshot({
			"source": "main_scene_ui",
			"frame_ms": float(latest_ui_snapshot.get("frame_ms", 0.0)),
			"current_panel": str(latest_ui_snapshot.get("current_panel", "")),
			"popup_count": int(latest_ui_snapshot.get("popup_count", 0)),
			"loading_active": loading_active,
			"time_ms": now_ms
		})

	last_ui_snapshot_recorded_ms = now_ms
	last_ui_snapshot_signature = observation_signature

	var current_phase: String = str(latest_ui_snapshot.get("current_phase", ""))
	var current_lane: String = str(latest_ui_snapshot.get("current_lane", ""))
	var frame_ms: float = float(latest_ui_snapshot.get("frame_ms", 0.0))
	var runtime_in_flight: bool = loading_active \
or bool(latest_ui_snapshot.get("year_pipeline_pending", false)) \
or int(latest_ui_snapshot.get("year_pipeline_stage", 0)) > 0 \
or current_phase not in ["", "preflight", "boot"]

	if observer_suppressed:
		consecutive_frame_spike_count = max(0, consecutive_frame_spike_count - 1)
	elif frame_ms >= frame_spike_threshold_ms * 0.92 and runtime_in_flight:
		consecutive_frame_spike_count += 1
	else:
		consecutive_frame_spike_count = max(0, consecutive_frame_spike_count - 1)

	if not observer_suppressed and runtime_in_flight and (
		frame_ms >= frame_spike_threshold_ms * 1.9
		or consecutive_frame_spike_count >= 3
	):
		var source_hint: Dictionary = _resolve_frame_spike_source(latest_ui_snapshot)
		_route_fault_once(
			"performance",
			"frame_spike",
			{
				"engine_id": "ui.main_scene.surface_runtime",
				"severity": "warning",
				"frame_ms": frame_ms,
				"current_phase": current_phase,
				"current_lane": current_lane,
				"fault_source_hint": str(source_hint.get("function_name", "")),
				"fault_source_engine_hint": str(source_hint.get("engine_name", "")),
				"observer_only": true
			},
			latest_ui_snapshot
		)

	if bool(latest_ui_snapshot.get("transition_active", false)) and not bool(latest_ui_snapshot.get("transition_surface_valid", true)):
		_route_fault_once(
			"ui",
			"stuck_transition",
			{
				"engine_id": "ui.main_scene.surface_runtime",
				"severity": "warning",
				"current_panel": str(latest_ui_snapshot.get("current_panel", "")),
				"current_phase": current_phase,
				"current_lane": current_lane
			},
			latest_ui_snapshot
		)

	if int(latest_ui_snapshot.get("popup_count", 0)) >= 3 and bool(latest_ui_snapshot.get("loading_active", false)):
		_route_fault_once(
			"ui",
			"duplicate_popup_loop",
			{
				"engine_id": "ui.main_scene.surface_runtime",
				"severity": "warning",
				"popup_count": int(latest_ui_snapshot.get("popup_count", 0)),
				"current_phase": current_phase,
				"current_lane": current_lane
			},
			latest_ui_snapshot
		)
func _resolve_frame_spike_source(snapshot: Dictionary) -> Dictionary:
	var current_phase: String = str(snapshot.get("current_phase", ""))
	match current_phase:
		"core_state_resolution":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_execute_registered_phase_bridge"
			}
		"internal_identity_drift":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_execute_registered_phase_bridge"
			}
		"year_budget_pipeline_commit":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_drive_age_up_loading_runtime"
			}
		"player_phase_contract":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_run_player_phase_contract"
			}
		"choice_and_opportunity_surfacing":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_execute_registered_phase_bridge"
			}
		"narrative_and_presentation":
			return {
				"engine_name": "AgeUpRuntimeEngine.gd",
				"function_name": "_execute_registered_phase_bridge"
			}
		_:
			return {
				"engine_name": "MainScene.gd",
				"function_name": "_process"
			}

func record_fault(domain: String, code: String, payload: Dictionary = {}, severity: String = "warning", snapshot: Dictionary = {}) -> Dictionary:
	var fault: Dictionary = payload.duplicate(true)
	fault ["domain"] = domain
	fault ["code"] = code
	fault ["severity"] = severity
	fault ["time_ms"] = int(Time.get_ticks_msec())
	if not fault.has("engine_id"):
		fault ["engine_id"] = "ui.main_scene.surface_runtime"
	if gs != null and gs.runtime_fault_router != null:
		latest_router_result = gs.runtime_fault_router.route_fault(
			fault,
			snapshot if not snapshot.is_empty() else latest_ui_snapshot
		)
	return latest_router_result

func record_recovery(code: String, payload: Dictionary = {}) -> void:
	if gs == null or gs.runtime_health_registry == null:
		return
	var recovery: Dictionary = payload.duplicate(true)
	recovery ["code"] = code
	recovery ["time_ms"] = int(Time.get_ticks_msec())
	gs.runtime_health_registry.record_recovery(recovery)

func get_debug_snapshot() -> Dictionary:
	var out: Dictionary = {}
	_copy_into(out, latest_ui_snapshot)
	_copy_into(out, latest_loading_snapshot)
	if gs != null and gs.runtime_health_registry != null:
		var digest: Dictionary = gs.runtime_health_registry.get_live_digest()
		out ["contract_count"] = int(digest.get("contract_count", 0))
		out ["signature_count"] = int(digest.get("signature_count", 0))
		out ["latest_fault"] = digest.get("latest_fault", {})
		out ["latest_patch_card"] = digest.get("latest_patch_card", {})
		out ["latest_recovery"] = digest.get("latest_recovery", {})
		out ["latest_auto_patch"] = digest.get("latest_auto_patch", {})
		out ["active_mitigations"] = digest.get("active_mitigations", [])
	if not out.has("state_label"):
		if bool(out.get("loading_active", false)):
			out ["state_label"] = "RUNTIME"
		elif int(out.get("popup_count", 0)) > 0:
			out ["state_label"] = "INTERACTIVE"
		else:
			out ["state_label"] = "IDLE"
	return out

func _route_fault_once(domain: String, code: String, payload: Dictionary, snapshot: Dictionary) -> Dictionary:
	var preview_engine: String = str(payload.get("engine_id", ""))
	var preview_phase: String = str(payload.get("current_phase", ""))
	var signature: String = "%s|%s|%s|%s" % [domain, code, preview_engine, preview_phase]
	var now_ms: int = int(Time.get_ticks_msec())
	if signature == last_fault_signature and (now_ms - last_fault_ms) < 900:
		return latest_router_result
	last_fault_signature = signature
	last_fault_ms = now_ms
	return record_fault(domain, code, payload, str(payload.get("severity", "warning")), snapshot)

func _copy_into(target: Dictionary, source: Dictionary) -> void:
	if typeof(source) != TYPE_DICTIONARY:
		return
	for key in source.keys():
		target [key] = source [key]