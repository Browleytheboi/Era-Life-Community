

extends Resource
class_name RealityResidencyManager

const ENGINE_SCHEMA:= (
	"eralife.reality_residency_manager"
)
const STATE_SCHEMA:= (
	"eralife.reality_residency_manager.state"
)
const ENGINE_VERSION:= 1
const DEFAULT_CHASSIS_TARGET:= 1
const DEFAULT_MAX_RESIDENT_REALITIES:= 4
const MAX_LEDGER:= 128

var gs = null
var snapshot_engine: RealitySnapshotContractEngine = null
var projection_engine: RealityProjectionContractEngine = null



var resident_records: Dictionary = {}
var chassis_records: Dictionary = {}
var preview_signature_by_slot: Dictionary = {}
# Upper bound on step_resident_projection() passes for one projection before it is
# declared degraded. Boot publishes 5 surfaces in well under this.
const MAX_PROJECTION_TAIL_STEPS: int = 900
var active_service_keys: Array = []
# key -> first time it was seen orphaned, so a key is only pruned once it has been
# orphaned continuously for SERVICE_KEY_ORPHAN_GRACE_MS.
var service_key_first_seen_ms: Dictionary = {}
const SERVICE_KEY_ORPHAN_GRACE_MS: int = 3000
var attached_signature: String = ""
var next_chassis_sequence: int = 1
var service_cursor: int = 0
var service_pump_armed: bool = false
var service_pump_sequence: int = 0
var chassis_target: int = DEFAULT_CHASSIS_TARGET
var max_resident_realities: int = (
	DEFAULT_MAX_RESIDENT_REALITIES
)
var ledger: Array = []
var last_report: Dictionary = {}
var chassis_bootstrap_threads: Dictionary = {}
var checkpoint_hydration_threads: Dictionary = {}
var checkpoint_engine_graph_threads: Dictionary = {}

func _init(
	_gs = null,
	_snapshot_engine: RealitySnapshotContractEngine = null,
	_projection_engine: RealityProjectionContractEngine = null
) -> void:
	gs = _gs
	snapshot_engine = _snapshot_engine
	projection_engine = _projection_engine


func bind_authorities(
	_gs,
	_snapshot_engine: RealitySnapshotContractEngine,
	_projection_engine: RealityProjectionContractEngine
) -> void:
	gs = _gs
	snapshot_engine = _snapshot_engine
	projection_engine = _projection_engine


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"chassis_target": chassis_target,
		"max_resident_realities": (
			max_resident_realities
		),
		"ui_is_renderer_only": true
	}


func prime_chassis_pool(
	context: Dictionary = {}
) -> Dictionary:
	var requested_target: int = clampi(
		int(
			context.get(
				"target_chassis_count",
				chassis_target
			)
		),
		1,
		maxi(
			1,
			max_resident_realities
		)
	)
	chassis_target = requested_target

	var viable_chassis_count: int = 0
	var rearmed_chassis_count: int = 0
	var retired_chassis_count: int = 0
	var reconciled_legacy_state_count: int = 0
	var existing_chassis_ids: Array = (
		chassis_records.keys()
	)
	existing_chassis_ids.sort()






	for raw_chassis_id in existing_chassis_ids:
		var chassis_id: String = str(
			raw_chassis_id
		)
		var service_key: String = (
			"chassis:%s" % chassis_id
		)
		var chassis: Dictionary = _dict(
			chassis_records.get(
				chassis_id,
				{}
			)
		)
		var chassis_state: String = str(
			chassis.get(
				"state",
				""
			)
		)



		if chassis_state == "building_contract_graph":
			chassis_state = "building_hot_chassis"
			chassis ["state"] = chassis_state
			chassis [
				"legacy_chassis_state_reconciled"
			] = true
			chassis [
				"legacy_chassis_state_reconciled_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			chassis_records [chassis_id] = chassis
			reconciled_legacy_state_count += 1

		var runtime_raw: Variant = chassis.get(
			"runtime_ref",
			null
		)
		var hot_chassis: bool = (
			chassis_state == "hot_chassis"
			and bool(
				chassis.get(
					"hot",
					false
				)
			)
			and runtime_raw is GameState
		)
		var chassis_requires_service: bool = (
			chassis_state in [
				"allocation_pending",
				"building_hot_chassis"
			]
		)

		if hot_chassis:
			viable_chassis_count += 1


			_remove_service_key(
				service_key
			)
			continue

		if chassis_requires_service:
			viable_chassis_count += 1



			_append_service_key(
				service_key
			)
			rearmed_chassis_count += 1
			continue



		_record({
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mode": "resident_chassis_retired_during_pool_reconciliation",
			"chassis_id": chassis_id,
			"state": chassis_state,
			"failure_reason": str(
				chassis.get(
					"failure_reason",
					(
						"invalid_or_terminal_chassis_record"
					)
				)
			),
			"runtime_reference_was_game_state": (
				runtime_raw is GameState
			),
			"retired_at_ms": int(
				Time.get_ticks_msec()
			),
			"ui_is_renderer_only": true
		})

		chassis_records.erase(
			chassis_id
		)
		_remove_service_key(
			service_key
		)
		retired_chassis_count += 1

	while viable_chassis_count < chassis_target:
		var chassis_id: String = (
			"resident_chassis:%d"
			% next_chassis_sequence
		)
		next_chassis_sequence += 1



		chassis_records [chassis_id] = {
			"chassis_id": chassis_id,
			"runtime_ref": null,
			"state": "allocation_pending",
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"hot": false,
			"service_state_contract": (
				"allocation_pending_or_building_hot_chassis"
			)
		}

		_append_service_key(
			"chassis:%s" % chassis_id
		)
		viable_chassis_count += 1

	_ensure_service_pump()

	var report: Dictionary = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": (
			"resident_hot_chassis_pool_staging"
		),
		"target_chassis_count": chassis_target,
		"chassis_count": chassis_records.size(),
		"viable_chassis_count": viable_chassis_count,
		"rearmed_chassis_count": rearmed_chassis_count,
		"retired_chassis_count": retired_chassis_count,
		"reconciled_legacy_state_count": (
			reconciled_legacy_state_count
		),
		"resident_count": resident_records.size(),
		"ui_is_renderer_only": true
	}

	_record(report)

	return report

func reserve_reality(
	settings: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var signature: String = str(
		context.get(
			"signature",
			settings.get(
				"prewarm_signature",
				""
			)
		)
	).strip_edges()

	if signature == "":
		return _failure(
			"missing_residency_signature",
			context
		)

	var candidate_slot: String = str(
		context.get(
			"candidate_slot",
			""
		)
	).strip_edges().to_lower()
	var commit_residency: bool = bool(
		context.get(
			"commit_residency",
			false
		)
	)

	if bool(
		context.get(
			"replace_uncommitted_slot",
			false
		)
	) and candidate_slot != "":
		_replace_uncommitted_preview(
			candidate_slot,
			signature
		)

	if resident_records.has(signature):
		var existing: Dictionary = _record_for(
			signature
		)
		existing ["last_requested_at_ms"] = int(
			Time.get_ticks_msec()
		)

		if commit_residency:
			existing ["committed"] = true

		resident_records [signature] = existing

		if candidate_slot != "":
			preview_signature_by_slot [
				candidate_slot
			] = signature

		if str(
			existing.get(
				"state",
				""
			)
		) not in [
			"ready",
			"failed"
		]:
			_append_service_key(
				"resident:%s" % signature
			)
			_ensure_service_pump()

		return status_contract(
			signature,
			{
				"source": (
					"reserve_existing_resident"
				)
			}
		)

	if resident_records.size() >= max_resident_realities:
		_evict_oldest_uncommitted_preview()

	if resident_records.size() >= max_resident_realities:
		return _failure(
			"resident_capacity_reached",
			{
				"signature": signature,
				"resident_count": resident_records.size(),
				"max_resident_realities": (
					max_resident_realities
				),
			}
		)

	var runtime: GameState = _take_available_chassis()

	if runtime == null:

		resident_records [signature] = {
			"signature": signature,
			"runtime_ref": null,
			"state": "waiting_for_hot_chassis",
			"settings": settings.duplicate(true),
			"prewarm_contract": _dict(
				context.get(
					"prewarm_contract",
					{}
				)
			),
			"projection_contract": {},
			"snapshot": {},
			"reserved_at_ms": int(
				Time.get_ticks_msec()
			),
			"last_service_at_ms": 0,
			"last_attached_at_ms": 0,
			"lens_attached": false,
			"committed": commit_residency,
			"candidate_slot": candidate_slot,
			"runtime_never_unloads_for_lens_disconnect": true,
		}

		prime_chassis_pool({
			"target_chassis_count": chassis_target,
			"source": (
				"reserve_reality_waiting_for_hot_chassis"
			)
		})
		_append_service_key(
			"resident:%s" % signature
		)
		_ensure_service_pump()

		if candidate_slot != "":
			preview_signature_by_slot [
				candidate_slot
			] = signature

		return status_contract(
			signature,
			{
				"source": (
					"reality_reserved_waiting_for_hot_chassis"
				)
			}
		)

	_inject_shared_authorities(
		runtime
	)

	var constructor_context: Dictionary = (
		context.duplicate(true)
	)
	constructor_context ["signature"] = signature
	constructor_context ["settings"] = (
		settings.duplicate(true)
	)
	constructor_context ["source"] = str(
		context.get(
			"source",
			(
				"reality_residency_manager."
				+ "reserve_reality"
			)
		)
	)

	var begin_report: Dictionary = (
		runtime.begin_resident_runtime_chassis_bootstrap(
			constructor_context
		)
	)
	var bind_report: Dictionary = (
		runtime.bind_resident_reality(
			settings,
			constructor_context
		)
	)

	resident_records [signature] = {
		"signature": signature,
		"runtime_ref": runtime,
		"state": "building_contract_graph",
		"settings": settings.duplicate(true),
		"prewarm_contract": _dict(
			context.get(
				"prewarm_contract",
				{}
			)
		),
		"projection_contract": {},
		"snapshot": {},
		"begin_report": begin_report.duplicate(true),
		"build_report": bind_report.duplicate(true),
		"projection_started": false,
		"reserved_at_ms": int(
			Time.get_ticks_msec()
		),
		"last_service_at_ms": 0,
		"last_attached_at_ms": 0,
		"lens_attached": false,
		"committed": commit_residency,
		"candidate_slot": candidate_slot,
		"runtime_never_unloads_for_lens_disconnect": true
	}

	_append_service_key(
		"resident:%s" % signature
	)
	_ensure_service_pump()

	if candidate_slot != "":
		preview_signature_by_slot [
			candidate_slot
		] = signature

	return status_contract(
		signature,
		{
			"source": "reality_reserved"
		}
	)


func service_residency(
	context: Dictionary = {}
) -> Dictionary:
	var requested_signature: String = str(
		context.get(
			"signature",
			""
		)
	).strip_edges()
	var requested_max_steps: int = clampi(
		int(
			context.get(
				"max_steps",
				1
			)
		),
		1,
		32
	)
	var requested_frame_budget_ms: int = clampi(
		int(
			context.get(
				"frame_budget_ms",
				2
			)
		),
		1,
		16
	)
	var service_key: String = _next_service_key(
		requested_signature
	)

	if service_key == "":
		return status_contract(
			requested_signature,
			{
				"source": (
					"service_residency_no_pending_work"
				)
			}
		)

	var effective_max_steps: int = requested_max_steps
	var effective_frame_budget_ms: int = (
		requested_frame_budget_ms
	)
	var servicing_resident_reality: bool = (
		service_key.begins_with(
			"resident:"
		)
	)
	var resident_signature: String = ""

	if servicing_resident_reality:
		resident_signature = service_key.trim_prefix(
			"resident:"
		)
		effective_max_steps = 1
		effective_frame_budget_ms = mini(
			2,
			requested_frame_budget_ms
		)

		var resident_record: Dictionary = _record_for(
			resident_signature
		)
		var resident_runtime_raw: Variant = (
			resident_record.get(
				"runtime_ref",
				null
			)
		)

		if resident_runtime_raw is GameState:
			var resident_gs: GameState = (
				resident_runtime_raw as GameState
			)

			if typeof(
				resident_gs.scenario_state
			) != TYPE_DICTIONARY:
				resident_gs.scenario_state = {}

			var resident_state: String = str(
				resident_record.get(
					"state",
					""
				)
			)
			var runtime_guard: Dictionary = _dict(
				resident_gs.scenario_state.get(
					"runtime_guard",
					{}
				)
			)
			var renderer_present_fence_active: bool = (
				bool(
					resident_gs.scenario_state.get(
						"ready_door_projection_service_may_not_run",
						false
					)
				)
				or bool(
					resident_gs.scenario_state.get(
						"renderer_present_fence_active",
						false
					)
				)
				or bool(
					runtime_guard.get(
						"renderer_present_fence_active",
						false
					)
				)
				or bool(
					runtime_guard.get(
						"ready_door_projection_quantum_forbidden",
						false
					)
				)
			)

			var checkpoint_background_safe_lane: bool = (
				resident_state == "ready"
				and bool(
					resident_record.get(
						"checkpoint_resume_shell_ready_before_payload_tail",
						false
					)
				)
				and bool(
					resident_record.get(
						"constructor_work_after_lens_attach_forbidden",
						false
					)
				)
			)

			if (
				resident_state == "ready"
				and renderer_present_fence_active
				and not checkpoint_background_safe_lane
			):
				var paused_at_ms: int = int(
					Time.get_ticks_msec()
				)

				resident_record [
					"service_paused_for_renderer_present_fence"
				] = true
				resident_record [
					"service_paused_for_renderer_present_fence_at_ms"
				] = paused_at_ms
				resident_record [
					"service_pause_preserves_ready_state"
				] = true

				resident_records [
					resident_signature
				] = resident_record

				var fence_status: Dictionary = status_contract(
					resident_signature,
					{
						"source": (
							"service_residency_renderer_present_fence"
						),
						"service_paused": true,
						"pause_reason": (
							"renderer_present_fence"
						),
						"ready_state_preserved": true
					}
				)

				fence_status [
					"service_paused"
				] = true
				fence_status [
					"pause_reason"
				] = "renderer_present_fence"
				fence_status [
					"serviced_key"
				] = service_key
				fence_status [
					"ready_state_preserved"
				] = true

				return fence_status
			if (
				renderer_present_fence_active
				and checkpoint_background_safe_lane
			):
				resident_record [
					"checkpoint_background_continued_during_renderer_fence"
				] = true
				resident_record [
					"checkpoint_background_renderer_fence_did_not_veto_worker"
				] = true

				resident_records [
					resident_signature
				] = resident_record
			var playable_lens_visible: bool = (
				bool(
					resident_gs.scenario_state.get(
						"playable_life_shell_has_visible_sovereignty",
						false
					)
				)
				or bool(
					resident_gs.scenario_state.get(
						"playable_life_surface_has_visual_authority",
						false
					)
				)
				or bool(
					resident_gs.scenario_state.get(
						"god_mode_ready_revealed_staged_surface",
						false
					)
				)
				or bool(
					resident_gs.scenario_state.get(
						"checkpoint_progressive_core_shell_commit_complete",
						false
					)
				)
			)

			if (
				resident_state == "ready"
				and playable_lens_visible
			):
				var now_ms: int = int(
					Time.get_ticks_msec()
				)
				var next_service_at_ms: int = int(
					resident_record.get(
						"interactive_lens_service_next_at_ms",
						0
					)
				)
				var input_priority_until_ms: int = maxi(
					maxi(
						int(
							runtime_guard.get(
								"ui_interaction_grace_until_ms",
								0
							)
						),
						int(
							runtime_guard.get(
								"truth_resolution_yield_until_ms",
								0
							)
						)
					),
					int(
						resident_gs.scenario_state.get(
							"ready_door_zero_frame_input_fence_until_ms",
							0
						)
					)
				)

				effective_max_steps = 1
				effective_frame_budget_ms = 1



				var interactive_input_active: bool = (
					now_ms < input_priority_until_ms
				)

				resident_record [
					"interactive_input_active_during_residency_quantum"
				] = interactive_input_active
				resident_record [
					"interactive_input_pauses_residency_publication"
				] = false
				resident_record [
					"interactive_residency_quantum_budget_ms"
				] = 1
				resident_record [
					"interactive_residency_quantum_limit"
				] = 1



				if now_ms < next_service_at_ms:
					var frame_cadence_status: Dictionary = (
						status_contract(
							resident_signature,
							{
								"source": (
									"service_residency_renderer_frame_cadence"
								),
								"service_paused": true,
								"pause_reason": (
									"renderer_frame_quantum_interval"
								),
								"next_service_at_ms": next_service_at_ms
							}
						)
					)

					frame_cadence_status [
						"service_paused"
					] = true
					frame_cadence_status [
						"pause_reason"
					] = "renderer_frame_quantum_interval"
					frame_cadence_status [
						"next_service_at_ms"
					] = next_service_at_ms
					frame_cadence_status [
						"effective_frame_budget_ms"
					] = 1

					return frame_cadence_status

				resident_record [
					"interactive_lens_service_next_at_ms"
				] = now_ms + 1
				resident_record [
					"interactive_lens_service_quantum_budget_ms"
				] = 1
				resident_record [
					"interactive_lens_service_quantum_limit"
				] = 1
				resident_record [
					"interactive_lens_service_is_throttled"
				] = false
				resident_record [
					"interactive_lens_service_is_renderer_frame_cadenced"
				] = true
				resident_record [
					"interactive_input_has_absolute_priority"
				] = false
				resident_record [
					"interactive_input_has_scheduling_priority"
				] = true
				resident_record [
					"interactive_input_may_not_starve_residency"
				] = true

				resident_records [
					resident_signature
				] = resident_record

	if service_key.begins_with(
		"chassis:"
	):
		_service_chassis_record(
			service_key.trim_prefix(
				"chassis:"
			),
			effective_max_steps,
			effective_frame_budget_ms
		)
	elif servicing_resident_reality:
		_service_record(
			resident_signature,
			effective_max_steps,
			effective_frame_budget_ms
		)

	if requested_signature != "":
		var requested_status: Dictionary = (
			status_contract(
				requested_signature,
				{
					"source": (
						"service_residency_requested_signature"
					),
					"requested_max_steps": requested_max_steps,
					"requested_frame_budget_ms": (
						requested_frame_budget_ms
					),
					"effective_max_steps": effective_max_steps,
					"effective_frame_budget_ms": (
						effective_frame_budget_ms
					),
					"resident_binding_is_one_quantum": (
						servicing_resident_reality
					)
				}
			)
		)

		requested_status [
			"requested_max_steps"
		] = requested_max_steps
		requested_status [
			"requested_frame_budget_ms"
		] = requested_frame_budget_ms
		requested_status [
			"effective_max_steps"
		] = effective_max_steps
		requested_status [
			"effective_frame_budget_ms"
		] = effective_frame_budget_ms
		requested_status [
			"resident_binding_is_one_quantum"
		] = servicing_resident_reality

		return requested_status

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "residency_service_advanced",
		"serviced_key": service_key,
		"active_service_count": active_service_keys.size(),
		"requested_max_steps": requested_max_steps,
		"requested_frame_budget_ms": requested_frame_budget_ms,
		"effective_max_steps": effective_max_steps,
		"effective_frame_budget_ms": effective_frame_budget_ms,
		"resident_binding_is_one_quantum": (
			servicing_resident_reality
		),
		"interactive_lens_service_frame_cadenced": (
			servicing_resident_reality
			and effective_frame_budget_ms == 1
		),
		"interactive_input_has_absolute_priority": (
			servicing_resident_reality
		),
		"catalog": resident_catalog(),
		"ui_is_renderer_only": true
	}
func attach_reality(
	signature: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var record: Dictionary = _record_for(
		clean_signature
	)

	if record.is_empty():
		return _failure(
			"resident_reality_not_found",
			{
				"signature": clean_signature
			}
		)

	if str(
		record.get(
			"state",
			""
		)
	) != "ready":
		return status_contract(
			clean_signature,
			{
				"source": "attach_requested_before_ready"
			}
		)

	var runtime = record.get(
		"runtime_ref",
		null
	)

	if not (runtime is GameState):
		return _failure(
			"resident_runtime_reference_missing",
			{
				"signature": clean_signature
			}
		)

	var resident_gs: GameState = (
		runtime as GameState
	)

	if (
		resident_gs == null
		or resident_gs.player == null
	):
		return _failure(
			"resident_runtime_not_playable",
			{
				"signature": clean_signature
			}
		)

	if (
		attached_signature != ""
		and attached_signature != clean_signature
		and resident_records.has(
			attached_signature
		)
	):
		var previous: Dictionary = _record_for(
			attached_signature
		)

		previous [
			"lens_attached"
		] = false
		previous [
			"last_detached_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		resident_records [
			attached_signature
		] = previous

	var checkpoint_candidate: Dictionary = _dict(
		record.get(
			"checkpoint_candidate",
			{}
		)
	)
	var checkpoint_resume_contract: Dictionary = _dict(
		record.get(
			"checkpoint_resume_contract",
			{}
		)
	)

	if checkpoint_resume_contract.is_empty():
		checkpoint_resume_contract = (
			_checkpoint_resume_contract_for_candidate(
				checkpoint_candidate
			)
		)

	if checkpoint_resume_contract.is_empty():
		var context_resume_raw: Variant = context.get(
			"checkpoint_resume_contract",
			{}
		)

		if typeof(context_resume_raw) == TYPE_DICTIONARY:
			checkpoint_resume_contract = (
				context_resume_raw as Dictionary
			).duplicate(false)

	var checkpoint_first_frame_raw: Variant = (
		checkpoint_resume_contract.get(
			"first_frame_ui_snapshot",
			{}
		)
	)
	var checkpoint_first_frame_ui_snapshot: Dictionary = (
		checkpoint_first_frame_raw as Dictionary
		if typeof(
			checkpoint_first_frame_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var checkpoint_attach: bool = (
		bool(
			context.get(
				"checkpoint_attach",
				false
			)
		)
		or not checkpoint_resume_contract.is_empty()
		or not checkpoint_candidate.is_empty()
	)
	var progressive_checkpoint_payload_tail: bool = (
		checkpoint_attach
		and bool(
			record.get(
				"checkpoint_payload_apply_pending",
				false
			)
		)
	)
	var pause_checkpoint_tail: bool = (
		checkpoint_attach
		and bool(
			context.get(
				"pause_checkpoint_tail_while_lens_attached",
				true
			)
		)
		and bool(
			record.get(
				"residency_tail_pending",
				false
			)
		)
		and not progressive_checkpoint_payload_tail
	)

	attached_signature = clean_signature

	record [
		"lens_attached"
	] = true
	record [
		"committed"
	] = true
	record [
		"last_attached_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	record [
		"attach_count"
	] = int(
		record.get(
			"attach_count",
			0
		)
	) + 1
	record [
		"checkpoint_attach"
	] = checkpoint_attach
	record [
		"checkpoint_progressive_payload_tail_while_attached"
	] = progressive_checkpoint_payload_tail
	record [
		"residency_tail_paused_for_interactive_lens"
	] = pause_checkpoint_tail
	record [
		"residency_tail_pause_reason"
	] = (
		"checkpoint_interactive_lens_attached"
		if pause_checkpoint_tail
		else ""
	)
	record [
		"interactive_input_has_absolute_priority"
	] = checkpoint_attach

	resident_records [
		clean_signature
	] = record

	if pause_checkpoint_tail:
		_remove_service_key(
			"resident:%s" % clean_signature
		)
	elif progressive_checkpoint_payload_tail:


		_append_service_key(
			"resident:%s" % clean_signature
		)
		_ensure_service_pump()

	if typeof(
		resident_gs.scenario_state
	) != TYPE_DICTIONARY:
		resident_gs.scenario_state = {}

	var attached_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var resident_engine_graph_ready: bool = (
		bool(
			resident_gs.scenario_state.get(
				"resident_runtime_engine_graph_ready",
				false
			)
		)
		or bool(
			resident_gs.resident_runtime_bootstrap_complete
		)
	)
	var resident_engine_graph_background_tail: bool = (
		bool(
			record.get(
				"residency_tail_pending",
				false
			)
		)
		and not resident_engine_graph_ready
	)

	resident_gs.scenario_state [
		"resident_runtime_lens_attached"
	] = true
	resident_gs.scenario_state [
		"resident_runtime_attached_signature"
	] = clean_signature
	resident_gs.scenario_state [
		"resident_runtime_attached_at_ms"
	] = attached_at_ms
	resident_gs.scenario_state [
		"resident_checkpoint_interactive_lens_attached"
	] = checkpoint_attach
	resident_gs.scenario_state [
		"resident_checkpoint_tail_paused_while_attached"
	] = pause_checkpoint_tail
	resident_gs.scenario_state [
		"resident_checkpoint_progressive_payload_tail_while_attached"
	] = progressive_checkpoint_payload_tail
	resident_gs.scenario_state [
		"resident_interactive_input_has_absolute_priority"
	] = checkpoint_attach

	var report: Dictionary = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "resident_runtime_attached",
		"signature": clean_signature,
		"game_state": resident_gs,
		"runtime_ref": resident_gs,
		"contract": _dict(
			record.get(
				"prewarm_contract",
				{}
			)
		),
		"projection_contract": _dict(
			record.get(
				"projection_contract",
				{}
			)
		),
		"snapshot": _dict(
			record.get(
				"snapshot",
				{}
			)
		),
		"rehydration_report": _dict(
			record.get(
				"rehydration_report",
				{}
			)
		),
		"checkpoint_candidate": (
			checkpoint_candidate.duplicate(false)
		),
		"checkpoint_resume_contract": (
			checkpoint_resume_contract.duplicate(false)
		),
		"checkpoint_first_frame_ui_snapshot": (
			checkpoint_first_frame_ui_snapshot.duplicate(false)
		),
		"checkpoint_attach": checkpoint_attach,
		"checkpoint_tail_paused_while_lens_attached": (
			pause_checkpoint_tail
		),
		"checkpoint_progressive_payload_tail_while_attached": (
			progressive_checkpoint_payload_tail
		),
		"interactive_input_has_absolute_priority": (
			checkpoint_attach
		),
		"resident_engine_graph_ready": (
			resident_engine_graph_ready
		),
		"resident_engine_graph_background_tail": (
			resident_engine_graph_background_tail
		),
		"background_active": (
			bool(
				_dict(
					record.get(
						"rehydration_report",
						{}
					)
				).get(
					"background_active",
					false
				)
			)
			or resident_engine_graph_background_tail
			or progressive_checkpoint_payload_tail
		),
		"player_created": true,
		"created_at_ms": attached_at_ms,
		"context": context.duplicate(false),
		"ui_is_renderer_only": true
	}

	_record(
		report
	)

	return report
func request_attached_actor_projection_rebind(
	actor_id: int,
	context: Dictionary = {}
) -> Dictionary:
	if actor_id <= 0:
		return _failure(
			"invalid_projection_rebind_actor_id",
			context
		)

	var signature: String = str(
		attached_signature
	).strip_edges()

	if signature == "":
		return _failure(
			"no_attached_resident_reality",
			context
		)

	var record: Dictionary = _record_for(
		signature
	)

	if record.is_empty():
		return _failure(
			"attached_resident_record_missing",
			{
				"signature": signature,
				"actor_id": actor_id,
				"context": context.duplicate(true)
			}
		)

	var runtime_raw: Variant = record.get(
		"runtime_ref",
		null
	)

	if not (runtime_raw is GameState):
		return _failure(
			"attached_resident_runtime_missing",
			{
				"signature": signature,
				"actor_id": actor_id,
				"context": context.duplicate(true)
			}
		)

	var resident_gs: GameState = runtime_raw as GameState

	if (
		resident_gs == null
		or resident_gs.player == null
		or int(resident_gs.player.id) != actor_id
	):
		return _failure(
			"projection_rebind_actor_mismatch",
			{
				"signature": signature,
				"actor_id": actor_id,
				"runtime_actor_id": (
					int(resident_gs.player.id)
					if (
						resident_gs != null
						and resident_gs.player != null
					)
					else -1
				),
				"context": context.duplicate(true)
			}
		)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var generation: int = int(
		record.get(
			"projection_actor_rebind_generation",
			0
		)
	) + 1



	record ["projection_actor_rebind_generation"] = generation
	record ["projection_actor_rebind_pending"] = true
	record ["projection_actor_rebind_actor_id"] = actor_id
	record ["projection_actor_rebind_reason"] = str(
		context.get(
			"source",
			"controlled_actor_switch"
		)
	)
	record ["projection_actor_rebind_requested_at_ms"] = now_ms
	record ["projection_started"] = false
	record ["projection_tail_pending"] = true
	record ["projection_tail_complete"] = false
	record ["projection_tail_failed"] = false
	record ["projection_tail_skipped"] = false
	record ["projection_tail_report"] = {}
	record ["projection_surface_packets_complete"] = false
	record ["residency_tail_pending"] = true
	record ["resident_chassis_tail_complete"] = true
	record ["ready_state_preserved"] = true

	resident_records [
		signature
	] = record

	if typeof(resident_gs.scenario_state) != TYPE_DICTIONARY:
		resident_gs.scenario_state = {}

	resident_gs.scenario_state [
		"resident_projection_actor_rebind_pending"
	] = true
	resident_gs.scenario_state [
		"resident_projection_actor_rebind_actor_id"
	] = actor_id
	resident_gs.scenario_state [
		"resident_projection_actor_rebind_generation"
	] = generation
	resident_gs.scenario_state [
		"resident_projection_actor_rebind_requested_at_ms"
	] = now_ms
	resident_gs.scenario_state [
		"resident_projection_surface_packets_complete"
	] = false
	resident_gs.scenario_state [
		"resident_projection_rebind_ready_gate_member"
	] = false
	resident_gs.scenario_state [
		"resident_projection_rebind_build_on_click"
	] = false
	resident_gs.scenario_state [
		"resident_ready_state_preserved_during_actor_rebind"
	] = true

	_append_service_key(
		"resident:%s"
		% signature
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "attached_actor_projection_rebind_queued",
		"signature": signature,
		"actor_id": actor_id,
		"generation": generation,
		"ready_gate_member": false,
		"ready_state_preserved": true,
		"ui_is_renderer_only": true,
		"context": context.duplicate(true)
	}

func detach_lens(
	signature: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var record: Dictionary = _record_for(
		clean_signature
	)

	if record.is_empty():
		return _failure(
			"resident_reality_not_found",
			{
				"signature": clean_signature
			}
		)

	record ["lens_attached"] = false
	record ["last_detached_at_ms"] = int(
		Time.get_ticks_msec()
	)
	record ["execution_mode"] = (
		"dormant_chunked"
	)
	record [
		"residency_tail_paused_for_interactive_lens"
	] = false
	record [
		"residency_tail_pause_reason"
	] = ""
	record [
		"interactive_input_has_absolute_priority"
	] = false
	resident_records [clean_signature] = record

	if attached_signature == clean_signature:
		attached_signature = ""

	var runtime = record.get(
		"runtime_ref",
		null
	)

	if runtime is GameState:
		var resident_gs: GameState = (
			runtime as GameState
		)

		if resident_gs != null:
			if typeof(
				resident_gs.scenario_state
			) != TYPE_DICTIONARY:
				resident_gs.scenario_state = {}

			resident_gs.scenario_state [
				"resident_runtime_lens_attached"
			] = false
			resident_gs.scenario_state [
				"resident_runtime_execution_mode"
			] = "dormant_chunked"
			resident_gs.scenario_state [
				"resident_runtime_last_detached_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = false
			resident_gs.scenario_state [
				"resident_snapshot_tail_paused"
			] = false
			resident_gs.scenario_state [
				"resident_interactive_input_has_absolute_priority"
			] = false
			resident_gs.realtime_enabled = false

	if bool(
		record.get(
			"residency_tail_pending",
			false
		)
	):
		_append_service_key(
			"resident:%s" % clean_signature
		)
		_ensure_service_pump()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "resident_lens_detached",
		"signature": clean_signature,
		"execution_mode": "dormant_chunked",
		"detached_tail_rearmed": bool(
			record.get(
				"residency_tail_pending",
				false
			)
		),
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}

func status_contract(
		signature: String,
		context: Dictionary = {}
) -> Dictionary:
	var status_started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var clean_signature: String = str(
		signature
	).strip_edges()
	var record_raw: Variant = resident_records.get(
		clean_signature,
		{}
	)
	var record: Dictionary = (
		(record_raw as Dictionary).duplicate(false)
		if typeof(
			record_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if record.is_empty():
		return {
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mode": "resident_reality_absent",
			"signature": clean_signature,
			"state": "absent",
			"ready": false,
			"constitutional_ready": false,
			"progress": 0.0,
			"stage_id": "not_reserved",
			"resident": false,
			"first_false_gate": "resident_record_exists",
			"readiness_gates": {
			},
			"context": context.duplicate(false),
			"ui_is_renderer_only": true
		}

	var runtime_raw: Variant = record.get(
		"runtime_ref",
		null
	)
	var resident_gs: GameState = null
	var bootstrap: Dictionary = {}
	var scenario: Dictionary = {}
	var resident_settings: Dictionary = {}
	var actor_id: int = -1

	if runtime_raw is GameState:
		resident_gs = runtime_raw as GameState

		if resident_gs != null:
			bootstrap = (
				resident_gs.resident_runtime_bootstrap_snapshot()
			)




			if typeof(
				resident_gs.scenario_state
			) == TYPE_DICTIONARY:
				scenario = resident_gs.scenario_state

			if typeof(
				resident_gs.custom_settings
			) == TYPE_DICTIONARY:
				resident_settings = (
					resident_gs.custom_settings
				)

			if resident_gs.player != null:
				actor_id = int(
					resident_gs.player.id
				)

	var state: String = str(
		record.get(
			"state",
			"reserved"
		)
	)
	var bootstrap_failed: bool = bool(
		bootstrap.get(
			"failed",
			false
		)
	)
	var bootstrap_complete: bool = bool(
		bootstrap.get(
			"complete",
			false
		)
	)
	var completed_steps: int = int(
		bootstrap.get(
			"completed_steps",
			0
		)
	)
	var total_steps: int = int(
		bootstrap.get(
			"total_steps",
			0
		)
	)
	var stage_id: String = str(
		bootstrap.get(
			"stage_id",
			state
		)
	)
	var world_seed: int = int(
		scenario.get(
			"world_seed",
			resident_settings.get(
				"world_seed",
				-1
			)
		)
	)
	var runtime_exists: bool = (
		resident_gs != null
	)
	var world_seed_exists: bool = (
		world_seed > 0
	)
	var player_identity_exists: bool = (
		resident_gs != null
		and resident_gs.player != null
		and actor_id > 0
	)
	var household_birth_truth_exists: bool = (
		bool(
			scenario.get(
				"resident_runtime_household_birth_truth_ready",
				false
			)
		)
		or scenario.has(
			"resident_birth_contract_first_frame_target_count"
		)
		or bool(
			scenario.get(
				"birth_shell_player_created",
				false
			)
		)
	)
	var life_shell_can_bind: bool = (
		runtime_exists
		and player_identity_exists
	)
	var minimum_playable_truth_ready: bool = (
		bool(
			record.get(
				"minimum_playable_truth_ready",
				false
			)
		)
		or bool(
			scenario.get(
				"resident_runtime_minimum_playable_truth_ready",
				false
			)
		)
		or bool(
			scenario.get(
				"god_mode_life_prewarm_ready",
				false
			)
		)
	)
	var checkpoint_resume_contract: Dictionary = _dict(
		record.get(
			"checkpoint_resume_contract",
			{}
		)
	)
	var checkpoint_resume: bool = (
		not checkpoint_resume_contract.is_empty()
		or bool(
			scenario.get(
				"checkpoint_resume_not_birth",
				false
			)
		)
	)
	var checkpoint_era_truth_exists: bool = (
		resident_gs != null
		and resident_gs.era != null
	)
	var checkpoint_first_frame_truth_exists: bool = (
		not _dict(
			checkpoint_resume_contract.get(
				"first_frame_ui_snapshot",
				{}
			)
		).is_empty()
		or not _dict(
			scenario.get(
				"first_frame_ui_snapshot",
				{}
			)
		).is_empty()
		or not _dict(
			scenario.get(
				"prebuilt_first_frame_ui_snapshot",
				{}
			)
		).is_empty()
	)

	var checkpoint_constitutional_ready: bool = (
		runtime_exists
		and world_seed_exists
		and player_identity_exists
		and checkpoint_era_truth_exists
		and checkpoint_first_frame_truth_exists
		and life_shell_can_bind
	)
	var constitutional_ready: bool = (
		checkpoint_constitutional_ready
		if checkpoint_resume
		else (
			runtime_exists
			and not bootstrap_failed
			and bootstrap_complete
			and world_seed_exists
			and player_identity_exists
			and household_birth_truth_exists
			and life_shell_can_bind
		)
	)
	var record_state_reconciled: bool = false

	if (
		constitutional_ready
		and state != "ready"
		and not checkpoint_resume
	):
		state = "ready"
		record_state_reconciled = true

		record ["state"] = "ready"
		record ["ready_at_ms"] = int(
			record.get(
				"ready_at_ms",
				Time.get_ticks_msec()
			)
		)
		record ["minimum_playable_truth_ready"] = true
		record ["minimum_playable_truth_contract"] = (
			"seed_era_player_family_birth"
		)
		record [
			"ready_state_reconciled_from_runtime_truth"
		] = true
		record [
			"ready_state_reconciled_from_runtime_truth_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"ready_state_reconciled_bootstrap_snapshot"
		] = bootstrap.duplicate(false)

		if resident_gs != null:
			if typeof(
				resident_gs.scenario_state
			) != TYPE_DICTIONARY:
				resident_gs.scenario_state = {}

			resident_gs.scenario_state [
				"resident_runtime_minimum_playable_truth_ready"
			] = true
			resident_gs.scenario_state [
				"resident_runtime_ready_state_reconciled"
			] = true
			resident_gs.scenario_state [
				"resident_runtime_ready_state_reconciled_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		resident_records [
			clean_signature
		] = record

	var ready: bool = (
		state == "ready"
		and constitutional_ready
	)
	var progress: float = float(
		bootstrap.get(
			"overall_progress",
			1.0 if ready else 0.0
		)
	)

	if (
		state == "projecting_contracts"
		and projection_engine != null
	):
		var projection_status: Dictionary = (
			projection_engine.projection_status(
				clean_signature
			)
		)

		progress = (
			0.9
			+ float(
				projection_status.get(
					"progress",
					0.0
				)
			) * 0.09
		)
		stage_id = "projection:%s" % str(
			projection_status.get(
				"stage_id",
				"contracts"
			)
		)

	if ready:
		progress = 1.0
		stage_id = "complete"

	var service_key: String = (
		"resident:%s" % clean_signature
	)
	var service_key_present: bool = (
		service_key in active_service_keys
	)
	var service_attempt_count: int = int(
		record.get(
			"service_attempt_count",
			0
		)
	)
	var last_service_entered_at_ms: int = int(
		record.get(
			"last_service_entered_at_ms",
			0
		)
	)
	var last_service_completed_at_ms: int = int(
		record.get(
			"last_service_at_ms",
			0
		)
	)
	var readiness_gates: Dictionary = {
		"resident_runtime_exists": runtime_exists,
		"bootstrap_not_failed": not bootstrap_failed,
		"bootstrap_complete": bootstrap_complete,
		"world_seed_exists": world_seed_exists,
		"player_identity_exists": player_identity_exists,
		"household_birth_truth_exists": (
			household_birth_truth_exists
		),
		"checkpoint_era_truth_exists": (
			checkpoint_era_truth_exists
		),
		"checkpoint_first_frame_truth_exists": (
			checkpoint_first_frame_truth_exists
		),
		"life_shell_can_bind": life_shell_can_bind,
		"minimum_playable_truth_ready": (
			minimum_playable_truth_ready
			or constitutional_ready
		),
		"record_state_ready": (
			state == "ready"
		),
		"service_key_present": service_key_present,
		"service_pump_armed": service_pump_armed
	}

	var constitutional_gate_order: Array = (
		[
			"resident_runtime_exists",
			"world_seed_exists",
			"player_identity_exists",
			"checkpoint_era_truth_exists",
			"checkpoint_first_frame_truth_exists",
			"life_shell_can_bind",
			"record_state_ready"
		]
		if checkpoint_resume
		else [
			"resident_runtime_exists",
			"bootstrap_not_failed",
			"bootstrap_complete",
			"world_seed_exists",
			"player_identity_exists",
			"household_birth_truth_exists",
			"life_shell_can_bind",
			"record_state_ready"
		]
	)
	var first_false_gate: String = ""

	for raw_gate_id in constitutional_gate_order:
		var gate_id: String = str(
			raw_gate_id
		)

		if not bool(
			readiness_gates.get(
				gate_id,
				false
			)
		):
			first_false_gate = gate_id
			break

	var truth_signature: String = (
		"%s|%s|%s|%d|%d|%s|%s|%s"
		% [
			state,
			stage_id,
			first_false_gate,
			completed_steps,
			total_steps,
			str(service_key_present),
			str(service_pump_armed),
			str(ready)
		]
	)
	var previous_truth_signature: String = str(
		record.get(
			"readiness_truth_print_signature",
			""
		)
	)
	var periodic_heartbeat: bool = (
		service_attempt_count > 0
		and service_attempt_count % 60 == 0
	)

	if (
		truth_signature != previous_truth_signature
		or periodic_heartbeat
	):
		EraLog.truth(
			(
				"ERALIFE_RESIDENCY_TRUTH"
				+ "|signature=%s"
				+ "|state=%s"
				+ "|ready=%s"
				+ "|constitutional_ready=%s"
				+ "|first_false_gate=%s"
				+ "|stage=%s"
				+ "|cursor=%d/%d"
				+ "|progress=%s"
				+ "|world_seed=%d"
				+ "|actor_id=%d"
				+ "|service_key_present=%s"
				+ "|service_pump_armed=%s"
				+ "|service_attempts=%d"
				+ "|last_service_entered_at_ms=%d"
				+ "|last_service_completed_at_ms=%d"
				+ "|record_state_reconciled=%s"
			)
			% [
				clean_signature,
				state,
				str(ready),
				str(constitutional_ready),
				first_false_gate,
				stage_id,
				completed_steps,
				total_steps,
				str(
					clampf(
						progress,
						0.0,
						1.0
					)
				),
				world_seed,
				actor_id,
				str(service_key_present),
				str(service_pump_armed),
				service_attempt_count,
				last_service_entered_at_ms,
				last_service_completed_at_ms,
				str(record_state_reconciled)
			]
		)

		record ["readiness_truth_print_signature"] = (
			truth_signature
		)
		record ["readiness_truth_printed_at_ms"] = int(
			Time.get_ticks_msec()
		)
		resident_records [
			clean_signature
		] = record

	var snapshot_raw: Variant = record.get(
		"snapshot",
		{}
	)
	var projection_raw: Variant = record.get(
		"projection_contract",
		{}
	)
	var snapshot_ready: bool = (
		typeof(
			snapshot_raw
		) == TYPE_DICTIONARY
		and not (
			snapshot_raw as Dictionary
		).is_empty()
	)
	var projection_ready: bool = (
		typeof(
			projection_raw
		) == TYPE_DICTIONARY
		and not (
			projection_raw as Dictionary
		).is_empty()
	)
	var status_completed_at_ms: int = int(
		Time.get_ticks_msec()
	)

	return {
		"success": (
			checkpoint_constitutional_ready
			if checkpoint_resume
			else not bootstrap_failed
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "resident_reality_status",
		"signature": clean_signature,
		"state": state,
		"ready": ready,
		"constitutional_ready": constitutional_ready,
		"record_state_reconciled": (
			record_state_reconciled
		),
		"resident": true,
		"actor_id": actor_id,
		"world_seed": world_seed,
		"progress": clampf(
			progress,
			0.0,
			1.0
		),
		"stage_id": stage_id,
		"completed_steps": completed_steps,
		"total_steps": total_steps,
		"first_false_gate": first_false_gate,
		"readiness_gates": readiness_gates,
		"service_key": service_key,
		"service_key_present": service_key_present,
		"service_pump_armed": service_pump_armed,
		"service_attempt_count": service_attempt_count,
		"last_service_entered_at_ms": (
			last_service_entered_at_ms
		),
		"last_service_completed_at_ms": (
			last_service_completed_at_ms
		),
		"bootstrap": bootstrap.duplicate(false),
		"snapshot_ready": snapshot_ready,
		"projection_ready": projection_ready,
		"lens_attached": bool(
			record.get(
				"lens_attached",
				false
			)
		),
		"committed": bool(
			record.get(
				"committed",
				false
			)
		),
		"status_started_at_ms": status_started_at_ms,
		"status_completed_at_ms": status_completed_at_ms,
		"status_elapsed_ms": maxi(
			0,
			status_completed_at_ms
			- status_started_at_ms
		),
		"worker_thread_used": false,
		"context": context.duplicate(false),
		"ui_is_renderer_only": true
	}
func resident_catalog() -> Array:
	var rows: Array = []
	var signatures: Array = resident_records.keys()
	signatures.sort()

	for raw_signature in signatures:
		var row: Dictionary = status_contract(
			str(
				raw_signature
			),
			{
				"source": "resident_catalog"
			}
		)
		row.erase("bootstrap")
		rows.append(row)

	return rows


func get_resident_runtime(
	signature: String
) -> GameState:
	var record: Dictionary = _record_for(
		str(
			signature
		).strip_edges()
	)
	var runtime = record.get(
		"runtime_ref",
		null
	)

	if runtime is GameState:
		return runtime as GameState

	return null

func bind_checkpoint_to_resident_record(
	signature: String,
	checkpoint: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var record: Dictionary = _record_for(
		clean_signature
	)

	if record.is_empty():
		return _failure(
			"resident_record_not_found",
			{
				"signature": clean_signature
			}
		)

	var path: String = str(
		checkpoint.get(
			"checkpoint_path",
			checkpoint.get(
				"path",
				""
			)
		)
	).strip_edges()
	var candidate: Dictionary = checkpoint.duplicate(true)

	candidate ["schema"] = "eralife.reality.checkpoint_candidate"
	candidate ["version"] = ENGINE_VERSION
	candidate ["success"] = (
		path != ""
		and FileAccess.file_exists(path)
	)
	candidate ["authority"] = str(
		candidate.get(
			"authority",
			"local"
		)
	)
	candidate ["source"] = str(
		candidate.get(
			"source",
			"reality_residency_checkpoint_binding"
		)
	)
	candidate ["checkpoint_path"] = path
	candidate ["path"] = path
	candidate ["residency_signature"] = clean_signature
	candidate ["updated_at_ms"] = int(
		candidate.get(
			"updated_at_ms",
			Time.get_ticks_msec()
		)
	)

	var snapshot: Dictionary = _dict(
		record.get(
			"snapshot",
			{}
		)
	)

	snapshot ["checkpoint_candidate"] = candidate.duplicate(true)
	snapshot ["restart_hydration_ready"] = bool(
		candidate.get(
			"success",
			false
		)
	)

	record ["snapshot"] = snapshot
	record ["checkpoint_candidate"] = candidate.duplicate(true)
	record ["restart_hydration_ready"] = bool(
		candidate.get(
			"success",
			false
		)
	)
	record ["checkpoint_bound_at_ms"] = int(
		Time.get_ticks_msec()
	)
	resident_records [clean_signature] = record

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "checkpoint_bound_to_resident_record",
		"signature": clean_signature,
		"checkpoint_candidate": candidate.duplicate(true),
		"restart_hydration_ready": bool(
			candidate.get(
				"success",
				false
			)
		),
		"ui_is_renderer_only": true
	}

func _bootstrap_chassis_runtime_on_worker(
	resident_runtime: GameState,
	chassis_id: String
) -> Dictionary:
	if resident_runtime == null:
		return {
			"success": false,
			"reason": "hot_chassis_runtime_missing",
			"chassis_id": chassis_id,
			"worker_thread_used": true
		}

	var begin_report: Dictionary = (
		resident_runtime
		.begin_resident_runtime_chassis_bootstrap({
			"signature": chassis_id,
			"source": (
				"reality_residency_manager."
				+ "hot_chassis_worker"
			),
			"settings": {},
			"allocation_mode": (
				"game_state_resident_chassis_factory"
			),
			"runtime_scene_tree_access_allowed": false,
			"worker_thread_used": true,
			"ui_is_renderer_only": true
		})
	)

	if bool(
		begin_report.get(
			"failed",
			false
		)
	):
		return {
			"success": false,
			"reason": "hot_chassis_bootstrap_begin_failed",
			"chassis_id": chassis_id,
			"begin_report": begin_report,
			"worker_thread_used": true
		}

	var build_report: Dictionary = begin_report
	var safety_cursor: int = 0
	var safety_limit: int = 4096

	while safety_cursor < safety_limit:
		if resident_runtime.resident_runtime_bootstrap_failed:
			return {
				"success": false,
				"reason": "hot_chassis_bootstrap_failed",
				"chassis_id": chassis_id,
				"begin_report": begin_report,
				"build_report": (
					resident_runtime
					.resident_runtime_bootstrap_snapshot()
				),
				"worker_thread_used": true
			}

		if resident_runtime.resident_runtime_bootstrap_complete:
			build_report = (
				resident_runtime
				.resident_runtime_bootstrap_snapshot()
			)

			return {
				"success": true,
				"mode": "hot_chassis_worker_complete",
				"chassis_id": chassis_id,
				"runtime_ref": resident_runtime,
				"begin_report": begin_report,
				"build_report": build_report,
				"worker_thread_used": true,
				"completed_at_ms": int(
					Time.get_ticks_msec()
				)
			}

		build_report = (
			resident_runtime
			.step_resident_runtime_bootstrap(
				1,
				2
			)
		)

		if (
			bool(
				build_report.get(
					"failed",
					false
				)
			)
			or not bool(
				build_report.get(
					"success",
					true
				)
			)
		):
			return {
				"success": false,
				"reason": "hot_chassis_bootstrap_failed",
				"chassis_id": chassis_id,
				"begin_report": begin_report,
				"build_report": build_report,
				"worker_thread_used": true
			}

		safety_cursor += 1


		OS.delay_msec(
			1
		)

	return {
		"success": false,
		"reason": "hot_chassis_worker_safety_limit_reached",
		"chassis_id": chassis_id,
		"begin_report": begin_report,
		"build_report": build_report,
		"worker_thread_used": true,
		"safety_cursor": safety_cursor
	}
func _hydrate_checkpoint_engine_graph_on_worker(
	resident_runtime: GameState,
	signature: String,
	checkpoint_path: String
) -> Dictionary:
	if resident_runtime == null:
		return {
			"success": false,
			"complete": false,
			"reason": "checkpoint_engine_graph_runtime_missing",
			"signature": signature,
			"worker_thread_used": true,
		}

	var context: Dictionary = {
		"signature": signature,
		"checkpoint_path": checkpoint_path,
		"source": (
			"reality_residency_manager."
			+ "checkpoint_engine_graph_worker"
		),
		"max_steps": 1,
		"frame_budget_ms": 1,
		"worker_thread_used": true,
		"runtime_scene_tree_access_allowed": false,
		"constructor_work_on_renderer_thread": false,
		"ui_is_renderer_only": true
	}

	var build_report: Dictionary = {}
	var safety_cursor: int = 0
	var safety_limit: int = 4096

	while safety_cursor < safety_limit:
		build_report = (
			resident_runtime
			.prepare_resident_runtime_for_checkpoint_hydration(
				context
			)
		)

		if (
			resident_runtime.resident_runtime_bootstrap_failed
			or bool(
				build_report.get(
					"failed",
					false
				)
			)
			or not bool(
				build_report.get(
					"success",
					true
				)
			)
		):
			return {
				"success": false,
				"complete": false,
				"reason": (
					"checkpoint_engine_graph_bootstrap_failed"
				),
				"signature": signature,
				"build_report": build_report,
				"worker_thread_used": true,
			}

		if bool(
			build_report.get(
				"ready",
				build_report.get(
					"complete",
					false
				)
			)
		):
			return {
				"success": true,
				"complete": true,
				"signature": signature,
				"build_report": build_report,
				"worker_thread_used": true,
				"ready_gate_member": false,
				"completed_at_ms": int(
					Time.get_ticks_msec()
				)
			}

		safety_cursor += 1



		OS.delay_msec(
			4
		)

	return {
		"success": false,
		"complete": false,
		"reason": (
			"checkpoint_engine_graph_worker_safety_limit_reached"
		),
		"signature": signature,
		"build_report": build_report,
		"worker_thread_used": true,
		"safety_cursor": safety_cursor
	}
func _service_chassis_record(
	chassis_id: String,
	_max_steps: int,
	_frame_budget_ms: int
) -> void:
	var chassis: Dictionary = _dict(
		chassis_records.get(
			chassis_id,
			{}
		)
	)

	if chassis.is_empty():
		var orphan_worker_raw: Variant = (
			chassis_bootstrap_threads.get(
				chassis_id,
				null
			)
		)

		if orphan_worker_raw is Thread:
			var orphan_worker: Thread = (
				orphan_worker_raw as Thread
			)

			if not orphan_worker.is_alive():
				orphan_worker.wait_to_finish()

		chassis_bootstrap_threads.erase(
			chassis_id
		)

		_remove_service_key(
			"chassis:%s" % chassis_id
		)
		return

	var state: String = str(
		chassis.get(
			"state",
			"allocation_pending"
		)
	)
	var resident_runtime: GameState = null

	if state == "allocation_pending":



		resident_runtime = (
			GameState.create_resident_chassis_shell()
		)

		if resident_runtime == null:
			chassis ["state"] = "failed"
			chassis ["failure_reason"] = (
				"hot_chassis_allocation_failed"
			)
			chassis ["allocation_mode"] = (
				"game_state_resident_chassis_factory"
			)
			chassis_records [chassis_id] = chassis

			_remove_service_key(
				"chassis:%s" % chassis_id
			)
			return

		if (
			resident_runtime.reality_residency_manager != null
			or resident_runtime.reality_snapshot_contract_engine != null
			or resident_runtime.reality_projection_contract_engine != null
			or resident_runtime.reality_residency_contract_engine != null
		):
			chassis ["state"] = "failed"
			chassis ["failure_reason"] = (
				"resident_chassis_factory_bootstrapped_nested_residency"
			)
			chassis ["allocation_mode"] = (
				"game_state_resident_chassis_factory"
			)
			chassis_records [chassis_id] = chassis

			_remove_service_key(
				"chassis:%s" % chassis_id
			)
			return

		_inject_shared_authorities(
			resident_runtime
		)

		var worker:= Thread.new()
		var worker_error: int = worker.start(
			Callable(
				self,
				"_bootstrap_chassis_runtime_on_worker"
			).bind(
				resident_runtime,
				chassis_id
			),
			Thread.PRIORITY_LOW
		)

		if worker_error != OK:
			chassis ["state"] = "failed"
			chassis ["failure_reason"] = (
				"hot_chassis_worker_start_failed"
			)
			chassis ["worker_error"] = worker_error
			chassis ["runtime_ref"] = resident_runtime
			chassis_records [chassis_id] = chassis

			_remove_service_key(
				"chassis:%s" % chassis_id
			)
			return

		chassis_bootstrap_threads [
			chassis_id
		] = worker

		chassis ["runtime_ref"] = resident_runtime
		chassis ["state"] = "building_hot_chassis"
		chassis ["allocation_mode"] = (
			"game_state_resident_chassis_factory"
		)
		chassis [
			"nested_residency_dependencies_skipped"
		] = true
		chassis ["construction_started_at_ms"] = int(
			Time.get_ticks_msec()
		)
		chassis ["worker_thread_used"] = true
		chassis ["worker_thread_active"] = true
		chassis [
			"constructor_work_on_renderer_thread"
		] = false
		chassis [
			"constructor_work_competes_with_main_menu"
		] = false
		chassis_records [chassis_id] = chassis
		return

	var runtime_raw: Variant = chassis.get(
		"runtime_ref",
		null
	)

	if not (
		runtime_raw is GameState
	):
		chassis ["state"] = "failed"
		chassis ["failure_reason"] = (
			"hot_chassis_runtime_missing"
		)
		chassis_records [chassis_id] = chassis

		_remove_service_key(
			"chassis:%s" % chassis_id
		)
		return

	resident_runtime = (
		runtime_raw as GameState
	)

	var worker_raw: Variant = (
		chassis_bootstrap_threads.get(
			chassis_id,
			null
		)
	)

	if worker_raw is Thread:
		var worker: Thread = (
			worker_raw as Thread
		)

		if worker.is_alive():
			chassis ["last_service_at_ms"] = int(
				Time.get_ticks_msec()
			)
			chassis ["worker_thread_active"] = true
			chassis [
				"renderer_thread_poll_only"
			] = true
			chassis [
				"renderer_thread_constructor_work_performed"
			] = false
			chassis_records [chassis_id] = chassis
			return

		var worker_result_raw: Variant = (
			worker.wait_to_finish()
		)

		chassis_bootstrap_threads.erase(
			chassis_id
		)

		var worker_result: Dictionary = (
			worker_result_raw as Dictionary
			if typeof(
				worker_result_raw
			) == TYPE_DICTIONARY
			else {}
		)

		chassis ["worker_thread_active"] = false
		chassis ["worker_thread_complete"] = true
		chassis ["worker_report"] = (
			worker_result.duplicate(false)
		)
		chassis ["last_service_at_ms"] = int(
			Time.get_ticks_msec()
		)

		if not bool(
			worker_result.get(
				"success",
				false
			)
		):
			chassis ["state"] = "failed"
			chassis ["failure_reason"] = str(
				worker_result.get(
					"reason",
					"hot_chassis_bootstrap_failed"
				)
			)
			chassis_records [chassis_id] = chassis

			_remove_service_key(
				"chassis:%s" % chassis_id
			)
			return

		var build_report_raw: Variant = (
			worker_result.get(
				"build_report",
				{}
			)
		)
		var build_report: Dictionary = (
			build_report_raw as Dictionary
			if typeof(
				build_report_raw
			) == TYPE_DICTIONARY
			else {}
		)

		chassis ["build_report"] = (
			build_report.duplicate(false)
		)
		chassis ["state"] = "hot_chassis"
		chassis ["hot"] = true
		chassis ["hot_at_ms"] = int(
			Time.get_ticks_msec()
		)
		chassis ["constructor_work_complete"] = true
		chassis ["runtime_identity_preserved"] = true
		chassis [
			"constructor_work_on_renderer_thread"
		] = false
		chassis [
			"main_menu_input_remained_sovereign"
		] = true
		chassis_records [chassis_id] = chassis

		_remove_service_key(
			"chassis:%s" % chassis_id
		)
		return




	var recovery_worker:= Thread.new()
	var recovery_error: int = recovery_worker.start(
		Callable(
			self,
			"_bootstrap_chassis_runtime_on_worker"
		).bind(
			resident_runtime,
			chassis_id
		)
	)

	if recovery_error != OK:
		chassis ["state"] = "failed"
		chassis ["failure_reason"] = (
			"hot_chassis_recovery_worker_start_failed"
		)
		chassis ["worker_error"] = recovery_error
		chassis_records [chassis_id] = chassis

		_remove_service_key(
			"chassis:%s" % chassis_id
		)
		return

	chassis_bootstrap_threads [
		chassis_id
	] = recovery_worker

	chassis ["state"] = "building_hot_chassis"
	chassis ["worker_thread_used"] = true
	chassis ["worker_thread_active"] = true
	chassis [
		"legacy_main_thread_chassis_service_recovered"
	] = true
	chassis_records [chassis_id] = chassis
func _service_record(
	signature: String,
	max_steps: int,
	frame_budget_ms: int
) -> void:
	var record: Dictionary = _record_for(
		signature
	)

	if record.is_empty():
		_remove_service_key(
			"resident:%s" % signature
		)
		return

	var service_entered_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var state: String = str(
		record.get(
			"state",
			""
		)
	)




	record ["service_attempt_count"] = (
		int(
			record.get(
				"service_attempt_count",
				0
			)
		) + 1
	)
	record ["last_service_entered_at_ms"] = (
		service_entered_at_ms
	)
	record ["last_service_entered_state"] = state
	record ["last_service_pump_sequence"] = (
		service_pump_sequence
	)
	resident_records [signature] = record

	# DIAGNOSTIC: the checkpoint key is registered (keys=2|records=2 in the logs) but
	# CHECKPOINT_RESOLVE never fires, so _service_record() is evidently never reached
	# for that signature. Report every record this actually services.
	EraLog.truth(
		"ERALIFE_SERVICE_RECORD|signature=%s|state=%s"
		% [signature, state]
	)

	if state in [
		"checkpoint_resolution_pending",
		"rehydration_pending"
	]:
		_append_service_key(
			"resident:%s" % signature
		)
		_service_rehydration_record(
			signature,
			record
		)
		return

	if (
		state == "ready"
		and bool(
			record.get(
				"residency_tail_pending",
				false
			)
		)
	):
		_service_ready_checkpoint_tail(
			signature,
			record,
			max_steps,
			frame_budget_ms
		)
		return

	if state in [
		"ready",
		"failed"
	]:
		_remove_service_key(
			"resident:%s" % signature
		)
		return

	if state == "waiting_for_hot_chassis":
		var hot_runtime: GameState = (
			_take_available_chassis()
		)

		if hot_runtime == null:
			prime_chassis_pool({
				"target_chassis_count": chassis_target,
				"source": (
					"resident_record_waiting_for_hot_chassis"
				)
			})

			record ["last_service_at_ms"] = int(
				Time.get_ticks_msec()
			)
			record ["last_service_completed_state"] = (
				"waiting_for_hot_chassis"
			)
			resident_records [signature] = record

			_append_service_key(
				"resident:%s" % signature
			)
			return

		_inject_shared_authorities(
			hot_runtime
		)

		var settings: Dictionary = _dict(
			record.get(
				"settings",
				{}
			)
		)
		var constructor_context: Dictionary = {
			"signature": signature,
			"settings": settings.duplicate(true),
			"source": (
				"reality_residency_manager."
				+ "service_waiting_resident"
			),
			"ui_is_renderer_only": true
		}
		var begin_report: Dictionary = (
			hot_runtime.begin_resident_runtime_chassis_bootstrap(
				constructor_context
			)
		)
		var bind_report: Dictionary = (
			hot_runtime.bind_resident_reality(
				settings,
				constructor_context
			)
		)

		record ["runtime_ref"] = hot_runtime
		record ["begin_report"] = (
			begin_report.duplicate(true)
		)
		record ["build_report"] = (
			bind_report.duplicate(true)
		)
		record ["state"] = "binding_reality"
		record ["hot_chassis_claimed_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record ["last_service_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record ["last_service_completed_state"] = (
			"binding_reality"
		)
		resident_records [signature] = record

		_append_service_key(
			"resident:%s" % signature
		)
		return

	var runtime = record.get(
		"runtime_ref",
		null
	)

	if not (
		runtime is GameState
	):
		_fail_record(
			record,
			signature,
			"resident_runtime_reference_missing"
		)
		return

	var resident_gs: GameState = (
		runtime as GameState
	)

	if state in [
		"building_contract_graph",
		"binding_reality"
	]:
		var boot_report: Dictionary = (
			resident_gs.step_resident_runtime_bootstrap(
				max_steps,
				frame_budget_ms
			)
		)

		record ["build_report"] = (
			boot_report.duplicate(true)
		)
		record ["last_service_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record ["last_service_completed_state"] = state
		record ["last_service_stage_id"] = str(
			boot_report.get(
				"stage_id",
				state
			)
		)
		record ["last_service_progress"] = float(
			boot_report.get(
				"overall_progress",
				boot_report.get(
					"progress",
					0.0
				)
			)
		)
		resident_records [signature] = record

		if bool(
			boot_report.get(
				"failed",
				false
			)
		):
			_fail_record(
				record,
				signature,
				"resident_runtime_bootstrap_failed",
				boot_report
			)
			return

		if bool(
			boot_report.get(
				"complete",
				false
			)
		):
			if resident_gs.player == null:
				record ["state"] = "binding_reality"
				record [
					"minimum_playable_truth_missing_actor"
				] = true
				resident_records [signature] = record

				_append_service_key(
					"resident:%s" % signature
				)
				return

			if typeof(
				resident_gs.scenario_state
			) != TYPE_DICTIONARY:
				resident_gs.scenario_state = {}

			var ready_at_ms: int = int(
				Time.get_ticks_msec()
			)







			record ["state"] = "ready"
			record ["ready_at_ms"] = ready_at_ms
			record ["minimum_playable_truth_ready"] = true
			record ["minimum_playable_truth_contract"] = (
				"seed_era_player_family_birth"
			)
			record ["playable_before_spatial_enrichment"] = true
			record ["playable_before_relationship_enrichment"] = true
			record ["playable_before_full_projection"] = true
			record ["resident_chassis_tail_complete"] = true

			record ["post_ready_truth_tail_pending"] = true
			record ["post_ready_truth_tail_complete"] = false
			record ["post_ready_truth_tail_degraded"] = false

			record ["projection_started"] = false
			record ["projection_tail_pending"] = false
			record ["residency_tail_pending"] = true

			record [
				"ready_door_waits_for_post_ready_truth_tail"
			] = false

			record [
				"ready_door_waits_for_projection"
			] = false

			record [
				"ready_door_waits_for_snapshot"
			] = false

			record [
				"service_scheduler_reached_constitutional_ready"
			] = true

			record [
				"service_scheduler_reached_constitutional_ready_at_ms"
			] = ready_at_ms

			resident_gs.scenario_state [
				"resident_runtime_minimum_playable_truth_ready"
			] = true

			resident_gs.scenario_state [
				"resident_runtime_minimum_playable_truth_contract"
			] = "seed_era_player_family_birth"

			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_pending"
			] = true

			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_complete"
			] = false

			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_does_not_block_ready"
			] = true

			resident_gs.scenario_state [
				"resident_runtime_deep_projection_tail_pending"
			] = projection_engine != null

			resident_gs.scenario_state [
				"resident_runtime_snapshot_tail_pending"
			] = projection_engine != null

			resident_gs.scenario_state [
				"resident_runtime_ready_door_waits_for_post_ready_truth_tail"
			] = false

			resident_gs.scenario_state [
				"resident_runtime_ready_door_waits_for_projection"
			] = false

			resident_gs.scenario_state [
				"resident_runtime_ready_door_waits_for_snapshot"
			] = false

			resident_records [signature] = record



			_append_service_key(
				"resident:%s" % signature
			)
			return



		resident_records [signature] = record

		_append_service_key(
			"resident:%s" % signature
		)
		return



	if state == "projecting_contracts":
		if projection_engine == null:
			_fail_record(
				record,
				signature,
				"missing_projection_engine"
			)
			return

		var projection_status: Dictionary = (
			projection_engine.step_resident_projection(
				signature,
				max_steps,
				frame_budget_ms
			)
		)

		record ["last_service_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record ["last_service_completed_state"] = (
			"projecting_contracts"
		)
		record ["last_service_stage_id"] = str(
			projection_status.get(
				"stage_id",
				"projecting_contracts"
			)
		)
		record ["last_service_progress"] = float(
			projection_status.get(
				"progress",
				0.0
			)
		)
		resident_records [signature] = record

		if bool(
			projection_status.get(
				"failed",
				false
			)
		):
			_fail_record(
				record,
				signature,
				"resident_projection_failed",
				projection_status
			)
			return

		if bool(
			projection_status.get(
				"complete",
				false
			)
		):
			var projection: Dictionary = _dict(
				projection_status.get(
					"projection_contract",
					{}
				)
			)

			record ["projection_contract"] = (
				projection.duplicate(true)
			)

			if snapshot_engine == null:
				_fail_record(
					record,
					signature,
					"missing_snapshot_engine"
				)
				return

			var snapshot_report: Dictionary = (
				snapshot_engine.capture_resident_snapshot(
					signature,
					resident_gs,
					projection,
					{
						"source": (
							"reality_residency_manager"
						)
					}
				)
			)

			if not bool(
				snapshot_report.get(
					"success",
					false
				)
			):
				_fail_record(
					record,
					signature,
					"resident_snapshot_invalid",
					snapshot_report
				)
				return

			record ["snapshot"] = _dict(
				snapshot_report.get(
					"snapshot",
					{}
				)
			)
			record ["state"] = "ready"
			record ["ready_at_ms"] = int(
				Time.get_ticks_msec()
			)
			resident_records [signature] = record

			_remove_service_key(
				"resident:%s" % signature
			)
			return

		resident_records [signature] = record

		_append_service_key(
			"resident:%s" % signature
		)
		return



	_fail_record(
		record,
		signature,
		"resident_service_state_unhandled",
		{
			"state": state,
			"signature": signature,
			"service_pump_sequence": service_pump_sequence,
			"service_entered_at_ms": service_entered_at_ms
		}
	)
func reserve_checkpoint_reality(
	signature: String,
	checkpoint: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var checkpoint_path: String = str(
		checkpoint.get(
			"checkpoint_path",
			checkpoint.get(
				"path",
				""
			)
		)
	).strip_edges()

	if clean_signature == "":
		return _failure(
			"missing_residency_signature",
			checkpoint
		)

	if (
		checkpoint_path == ""
		or not FileAccess.file_exists(
			checkpoint_path
		)
	):
		return _failure(
			"resident_checkpoint_unavailable",
			{
				"signature": clean_signature,
				"checkpoint_path": checkpoint_path
			}
		)

	var checkpoint_candidate: Dictionary = (
		checkpoint.duplicate(true)
	)

	checkpoint_candidate ["schema"] = (
		"eralife.reality.checkpoint_candidate"
	)
	checkpoint_candidate ["version"] = ENGINE_VERSION
	checkpoint_candidate ["success"] = true
	checkpoint_candidate ["authority"] = str(
		checkpoint_candidate.get(
			"authority",
			"local"
		)
	)
	checkpoint_candidate ["checkpoint_path"] = (
		checkpoint_path
	)
	checkpoint_candidate ["path"] = checkpoint_path
	checkpoint_candidate ["residency_signature"] = (
		clean_signature
	)
	checkpoint_candidate ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	checkpoint_candidate [
		"checkpoint_requires_worker_hot_chassis"
	] = false
	checkpoint_candidate [
		"checkpoint_first_frame_shell_may_precede_engine_graph"
	] = true
	checkpoint_candidate [
		"checkpoint_engine_graph_worker_tail_required"
	] = true
	checkpoint_candidate [
		"constructor_work_on_renderer_thread_forbidden"
	] = true

	if resident_records.has(
		clean_signature
	):
		var existing: Dictionary = _record_for(
			clean_signature
		)

		existing ["checkpoint_candidate"] = (
			checkpoint_candidate.duplicate(true)
		)
		existing ["committed"] = true
		existing ["last_requested_at_ms"] = int(
			Time.get_ticks_msec()
		)
		existing [
			"checkpoint_lightweight_chassis_allowed"
		] = true
		existing [
			"checkpoint_waits_for_hot_chassis"
		] = false
		existing [
			"checkpoint_engine_graph_must_be_hot_before_attach"
		] = false
		existing [
			"checkpoint_engine_graph_worker_tail_required"
		] = true
		existing [
			"constructor_work_after_lens_attach_forbidden"
		] = false
		existing [
			"constructor_work_after_lens_attach_worker_only"
		] = true
		existing [
			"constructor_work_on_renderer_thread_after_lens_attach_forbidden"
		] = true

		resident_records [
			clean_signature
		] = existing

		if str(
			existing.get(
				"state",
				""
			)
		) not in [
			"ready",
			"failed"
		]:
			_append_service_key(
				"resident:%s"
				% clean_signature
			)
			_ensure_service_pump()

		return status_contract(
			clean_signature,
			{
				"source": (
					"reserve_existing_checkpoint_reality"
				)
			}
		)

	resident_records [clean_signature] = {
		"signature": clean_signature,
		"runtime_ref": null,
		"state": "checkpoint_resolution_pending",
		"settings": {},
		"prewarm_contract": {},
		"projection_contract": {},
		"snapshot": {
			"checkpoint_candidate": (
				checkpoint_candidate.duplicate(true)
			),
			"restart_hydration_ready": true
		},
		"checkpoint_candidate": (
			checkpoint_candidate.duplicate(true)
		),
		"restart_hydration_ready": true,
		"committed": true,
		"lens_attached": false,
		"reserved_at_ms": int(
			Time.get_ticks_msec()
		),
		"runtime_never_unloads_for_lens_disconnect": true,
		"checkpoint_lightweight_chassis_allowed": true,
		"checkpoint_waits_for_hot_chassis": false,
		"checkpoint_engine_graph_must_be_hot_before_attach": false,
		"checkpoint_engine_graph_worker_tail_required": true,
		"constructor_work_after_lens_attach_forbidden": false,
		"constructor_work_after_lens_attach_worker_only": true,
		"constructor_work_on_renderer_thread_after_lens_attach_forbidden": true,
		"residency_tail_pending": false
	}

	_append_service_key(
		"resident:%s" % clean_signature
	)
	_ensure_service_pump()

	return status_contract(
		clean_signature,
		{
			"source": "checkpoint_reality_reserved"
		}
	)
func _hydrate_checkpoint_runtime_on_worker(
	checkpoint_candidate: Dictionary,
	signature: String
) -> Dictionary:
	var checkpoint_path: String = str(
		checkpoint_candidate.get(
			"checkpoint_path",
			checkpoint_candidate.get(
				"path",
				""
			)
		)
	).strip_edges()

	if (
		checkpoint_path == ""
		or not FileAccess.file_exists(
			checkpoint_path
		)
	):
		return {
			"success": false,
			"reason": "resident_checkpoint_file_missing",
			"signature": signature,
			"worker_thread_used": true,
		}

	var payload: Dictionary = {}
	var format: String = "binary"

	if checkpoint_path.to_lower().ends_with(".json"):
		format = "json"

		var json_file:= FileAccess.open(
			checkpoint_path,
			FileAccess.READ
		)

		if json_file != null:
			var parsed_raw: Variant = JSON.parse_string(
				json_file.get_as_text()
			)

			json_file.close()

			if typeof(parsed_raw) == TYPE_DICTIONARY:
				payload = parsed_raw as Dictionary
	else:
		var binary_file:= FileAccess.open(
			checkpoint_path,
			FileAccess.READ
		)

		if binary_file != null:
			var bytes: PackedByteArray = (
				binary_file.get_buffer(
					binary_file.get_length()
				)
			)

			binary_file.close()

			payload = BinarySaveEngine.decode(
				bytes
			)

	var spatial_hydration_plan: Dictionary = {
		"actor_id": -1,
		"actor": [],
		"household": [],
		"city": [],
		"realm": [],
		"world": [],
		"household_count": 0,
		"relationship_local_count": 0,
		"relationship_local_graph_depth": 3,
		"city_count": 0,
		"realm_count": 0,
		"world_count": 0,
		"locality_order": [
			"actor",
			"life",
			"household",
			"city",
			"realm",
			"world"
		]
	}

	if not payload.is_empty():
		# The decoded checkpoint payload passes through here. Report what it carries so
		# we can tell whether the engine registry survived the save/decode round trip
		# regardless of which hydration function ends up applying it.
		EraLog.truth(
			"ERALIFE_PAYLOAD_DECODED|keys=%d|has_engine_registry=%s|has_graph=%s"
			% [
				payload.size(),
				str(payload.has("engine_registry")),
				str(payload.has("canonical_relationship_graph"))
			]
		)

		var npc_rows_raw: Variant = payload.get(
			"npcs",
			[]
		)
		var npc_rows: Array = (
			npc_rows_raw as Array
			if typeof(npc_rows_raw) == TYPE_ARRAY
			else []
		)
		var actor_id: int = int(
			payload.get(
				"player_id",
				-1
			)
		)
		var actor_row: Dictionary = {}
		var npc_row_by_id: Dictionary = {}

		for raw_row in npc_rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			)
			var row_id: int = int(
				row.get(
					"id",
					-1
				)
			)

			if row_id <= 0:
				continue

			npc_row_by_id [
				str(row_id)
			] = row

			if row_id == actor_id:
				actor_row = row













		var household_ids: Dictionary = {}
		var relationship_local_depth_by_id: Dictionary = {}
		var relationship_local_frontier: Array = []
		var relationship_local_graph_depth: int = 3

		if not actor_row.is_empty():
			relationship_local_depth_by_id [
				str(actor_id)
			] = 0
			relationship_local_frontier.append(
				actor_id
			)




			var explicit_household_raw: Variant = actor_row.get(
				"household_member_ids",
				[]
			)

			if typeof(explicit_household_raw) == TYPE_ARRAY:
				for raw_household_id in explicit_household_raw as Array:
					var household_member_id: int = int(
						raw_household_id
					)

					if (
						household_member_id > 0
						and household_member_id != actor_id
					):
						household_ids [
							str(household_member_id)
						] = true

			while not relationship_local_frontier.is_empty():
				var current_id: int = int(
					relationship_local_frontier.pop_front()
				)
				var current_key: String = str(
					current_id
				)
				var current_depth: int = int(
					relationship_local_depth_by_id.get(
						current_key,
						0
					)
				)

				if current_depth >= relationship_local_graph_depth:
					continue

				var current_row_raw: Variant = npc_row_by_id.get(
					current_key,
					{}
				)

				if typeof(current_row_raw) != TYPE_DICTIONARY:
					continue

				var current_row: Dictionary = (
					current_row_raw as Dictionary
				)
				var relationship_neighbor_ids: Array = []

				for relationship_array_key in [
					"parents",
					"children"
				]:
					var neighbor_array_raw: Variant = current_row.get(
						str(relationship_array_key),
						[]
					)

					if typeof(neighbor_array_raw) != TYPE_ARRAY:
						continue

					for raw_neighbor_id in neighbor_array_raw as Array:
						relationship_neighbor_ids.append(
							int(raw_neighbor_id)
						)

				var current_partner_id: int = int(
					current_row.get(
						"partner_id",
						-1
					)
				)

				if current_partner_id > 0:
					relationship_neighbor_ids.append(
						current_partner_id
					)

				var next_depth: int = current_depth + 1

				for raw_neighbor_id in relationship_neighbor_ids:
					var neighbor_id: int = int(
						raw_neighbor_id
					)

					if (
						neighbor_id <= 0
						or neighbor_id == actor_id
					):
						continue

					var neighbor_key: String = str(
						neighbor_id
					)

					household_ids [
						neighbor_key
					] = true

					var existing_depth: int = int(
						relationship_local_depth_by_id.get(
							neighbor_key,
							relationship_local_graph_depth + 1
						)
					)

					if next_depth < existing_depth:
						relationship_local_depth_by_id [
							neighbor_key
						] = next_depth

						if (
							next_depth
							< relationship_local_graph_depth
						):
							relationship_local_frontier.append(
								neighbor_id
							)

		var actor_city: String = str(
			actor_row.get(
				"home_city",
				""
			)
		).strip_edges().to_lower()
		var actor_country: String = str(
			actor_row.get(
				"home_country",
				""
			)
		).strip_edges().to_lower()
		var actor_realm_id: int = int(
			actor_row.get(
				"realm_id",
				-1
			)
		)

		for raw_row in npc_rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			)
			var npc_id: int = int(
				row.get(
					"id",
					-1
				)
			)

			if npc_id <= 0:
				continue

			if npc_id == actor_id:
				spatial_hydration_plan [
					"actor"
				] = [
					row
				]
				continue

			var id_key: String = str(
				npc_id
			)
			var npc_city: String = str(
				row.get(
					"home_city",
					""
				)
			).strip_edges().to_lower()
			var npc_country: String = str(
				row.get(
					"home_country",
					""
				)
			).strip_edges().to_lower()
			var npc_realm_id: int = int(
				row.get(
					"realm_id",
					-1
				)
			)

			if household_ids.has(
				id_key
			):
				(
					spatial_hydration_plan [
						"household"
					] as Array
				).append(
					row
				)
			elif (
				actor_city != ""
				and npc_city == actor_city
			):
				(
					spatial_hydration_plan [
						"city"
					] as Array
				).append(
					row
				)
			elif (
				(
					actor_realm_id > 0
					and npc_realm_id == actor_realm_id
				)
				or (
					actor_country != ""
					and npc_country == actor_country
				)
			):
				(
					spatial_hydration_plan [
						"realm"
					] as Array
				).append(
					row
				)
			else:
				(
					spatial_hydration_plan [
						"world"
					] as Array
				).append(
					row
				)

		spatial_hydration_plan [
			"actor_id"
		] = actor_id
		spatial_hydration_plan [
			"household_count"
		] = (
			spatial_hydration_plan [
				"household"
			] as Array
		).size()
		spatial_hydration_plan [
			"relationship_local_count"
		] = (
			spatial_hydration_plan [
				"household"
			] as Array
		).size()
		spatial_hydration_plan [
			"city_count"
		] = (
			spatial_hydration_plan [
				"city"
			] as Array
		).size()
		spatial_hydration_plan [
			"realm_count"
		] = (
			spatial_hydration_plan [
				"realm"
			] as Array
		).size()
		spatial_hydration_plan [
			"world_count"
		] = (
			spatial_hydration_plan [
				"world"
			] as Array
		).size()

	return {
		"success": not payload.is_empty(),
		"reason": (
			""
			if not payload.is_empty()
			else "resident_checkpoint_decode_failed"
		),
		"signature": signature,
		"checkpoint_path": checkpoint_path,
		"format": format,
		"payload": payload,
		"spatial_hydration_plan": spatial_hydration_plan,
		"worker_thread_used": true,
		"decoded_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _checkpoint_resume_contract_for_candidate(
	checkpoint_candidate: Dictionary
) -> Dictionary:
	if checkpoint_candidate.is_empty():
		return {}

	var resume_raw: Variant = checkpoint_candidate.get(
		"checkpoint_resume_contract",
		{}
	)
	var resume_contract: Dictionary = (
		(resume_raw as Dictionary).duplicate(false)
		if typeof(resume_raw) == TYPE_DICTIONARY
		else {}
	)

	if resume_contract.is_empty():
		var continue_raw: Variant = checkpoint_candidate.get(
			"continue_contract",
			{}
		)
		var continue_contract: Dictionary = (
			continue_raw as Dictionary
			if typeof(continue_raw) == TYPE_DICTIONARY
			else {}
		)
		var continue_resume_raw: Variant = continue_contract.get(
			"checkpoint_resume_contract",
			{}
		)
		resume_contract = (
			(continue_resume_raw as Dictionary).duplicate(false)
			if typeof(continue_resume_raw) == TYPE_DICTIONARY
			else {}
		)

	if resume_contract.is_empty():
		var load_options_raw: Variant = checkpoint_candidate.get(
			"load_options",
			{}
		)
		var load_options: Dictionary = (
			load_options_raw as Dictionary
			if typeof(load_options_raw) == TYPE_DICTIONARY
			else {}
		)
		var load_resume_raw: Variant = load_options.get(
			"checkpoint_resume_contract",
			{}
		)
		resume_contract = (
			(load_resume_raw as Dictionary).duplicate(false)
			if typeof(load_resume_raw) == TYPE_DICTIONARY
			else {}
		)

		if resume_contract.is_empty():
			var load_continue_raw: Variant = load_options.get(
				"continue_contract",
				{}
			)
			var load_continue_contract: Dictionary = (
				load_continue_raw as Dictionary
				if typeof(load_continue_raw) == TYPE_DICTIONARY
				else {}
			)
			var load_continue_resume_raw: Variant = (
				load_continue_contract.get(
					"checkpoint_resume_contract",
					{}
				)
			)
			resume_contract = (
				(load_continue_resume_raw as Dictionary).duplicate(false)
				if typeof(load_continue_resume_raw) == TYPE_DICTIONARY
				else {}
			)

	# FIX: the candidate carries checkpoint_path, path, load_options and metadata, but
	# never checkpoint_resume_contract -- RealitySnapshotContractEngine builds it from
	# the record and never opens the save file. The contract IS on disk: the save path
	# writes it into the saved-life summary. Without it this function returned {},
	# _materialize_checkpoint_resume_shell() was skipped entirely, resume_shell_ready
	# stayed false, and the record never reached "ready" -- the load polled forever.
	# Read the summary before giving up.
	if resume_contract.is_empty():
		var summary_path: String = str(
			checkpoint_candidate.get(
				"checkpoint_path",
				checkpoint_candidate.get("path", "")
			)
		).strip_edges()

		# Log unconditionally -- the previous version only logged inside the guard, so
		# when the guard failed there was no evidence at all of why.
		EraLog.truth(
			"ERALIFE_RESUME_FROM_SUMMARY|path='%s'|gs_null=%s|has_reader=%s"
			% [
				summary_path,
				str(gs == null),
				str(gs != null and gs.has_method("_read_saved_life_summary"))
			]
		)

		if (
			summary_path != ""
			and gs != null
			and gs.has_method("_read_saved_life_summary")
		):
			var saved_summary: Dictionary = _dict(
				gs._read_saved_life_summary(summary_path)
			)
			var summary_resume_raw: Variant = saved_summary.get(
				"checkpoint_resume_contract",
				{}
			)

			if typeof(summary_resume_raw) == TYPE_DICTIONARY:
				resume_contract = (summary_resume_raw as Dictionary).duplicate(false)

			EraLog.truth(
				"ERALIFE_RESUME_FROM_SUMMARY|path=%s|summary_keys=%d|resume_found=%s"
				% [
					summary_path,
					saved_summary.size(),
					str(not resume_contract.is_empty())
				]
			)

	if resume_contract.is_empty():
		set_meta(
			"checkpoint_cold_resume_capsule_available",
			false
		)
		set_meta(
			"checkpoint_cold_resume_requires_background_payload_restore",
			true
		)
		return {}

	var actor_snapshot_raw: Variant = resume_contract.get(
		"actor_snapshot",
		{}
	)
	var actor_snapshot: Dictionary = (
		(actor_snapshot_raw as Dictionary).duplicate(false)
		if typeof(actor_snapshot_raw) == TYPE_DICTIONARY
		else {}
	)
	var first_frame_raw: Variant = resume_contract.get(
		"first_frame_ui_snapshot",
		{}
	)
	var first_frame: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(first_frame_raw) == TYPE_DICTIONARY
		else {}
	)

	var actor_id: int = int(
		resume_contract.get(
			"controlled_actor_id",
			resume_contract.get(
				"actor_id",
				actor_snapshot.get(
					"id",
					-1
				)
			)
		)
	)

	if (
		actor_snapshot.is_empty()
		or first_frame.is_empty()
		or actor_id <= 0
	):
		set_meta(
			"checkpoint_cold_resume_capsule_available",
			false
		)
		set_meta(
			"checkpoint_cold_resume_capsule_invalid",
			true
		)
		set_meta(
			"checkpoint_cold_resume_capsule_actor_id",
			actor_id
		)
		return {}

	var first_frame_stats_raw: Variant = first_frame.get(
		"stats",
		{}
	)
	var first_frame_stats: Dictionary = (
		(first_frame_stats_raw as Dictionary).duplicate(false)
		if typeof(first_frame_stats_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_hunger_raw: Variant = actor_snapshot.get(
		"hunger",
		-1
	)
	var persisted_hunger_raw: Variant = first_frame.get(
		"hunger",
		first_frame_stats.get(
			"hunger",
			-1
		)
	)
	var resolved_hunger: float = -1.0
	var hunger_backfilled: bool = false
	var hunger_normalized_from_actor_snapshot: bool = false
	var hunger_legacy_zero_conflict_repaired: bool = false

	var actor_hunger_numeric: bool = (
		typeof(actor_hunger_raw) in [
			TYPE_INT,
			TYPE_FLOAT
		]
	)
	var persisted_hunger_numeric: bool = (
		typeof(persisted_hunger_raw) in [
			TYPE_INT,
			TYPE_FLOAT
		]
	)

	var actor_hunger_value: float = (
		clampf(
			float(actor_hunger_raw),
			0.0,
			100.0
		)
		if actor_hunger_numeric
		else -1.0
	)
	var persisted_hunger_value: float = (
		clampf(
			float(persisted_hunger_raw),
			0.0,
			100.0
		)
		if persisted_hunger_numeric
		else -1.0
	)











	if (
		actor_hunger_numeric
		and persisted_hunger_numeric
		and actor_hunger_value == persisted_hunger_value
	):
		resolved_hunger = actor_hunger_value
		hunger_normalized_from_actor_snapshot = true
	elif (
		actor_hunger_numeric
		and actor_hunger_value > 0.0
	):
		resolved_hunger = actor_hunger_value
		hunger_normalized_from_actor_snapshot = true
	elif (
		persisted_hunger_numeric
		and persisted_hunger_value > 0.0
		and (
			not actor_hunger_numeric
			or actor_hunger_value == 0.0
		)
	):
		resolved_hunger = persisted_hunger_value
		hunger_backfilled = true
		hunger_legacy_zero_conflict_repaired = (
			actor_hunger_numeric
			and actor_hunger_value == 0.0
		)
	elif actor_hunger_numeric:
		resolved_hunger = actor_hunger_value
		hunger_normalized_from_actor_snapshot = true
	elif persisted_hunger_numeric:
		resolved_hunger = persisted_hunger_value
		hunger_backfilled = true

	if resolved_hunger >= 0.0:
		actor_snapshot [
			"hunger"
		] = resolved_hunger
		first_frame [
			"hunger"
		] = resolved_hunger
		first_frame_stats [
			"hunger"
		] = resolved_hunger
		first_frame [
			"stats"
		] = first_frame_stats





	var diary_promoted_from_first_frame: bool = false
	var diary_entries_raw: Variant = resume_contract.get(
		"life_diary_entries",
		[]
	)
	var latest_diary_raw: Variant = resume_contract.get(
		"latest_life_diary_lines",
		[]
	)
	var diary_entries_present: bool = (
		typeof(diary_entries_raw) == TYPE_ARRAY
		and not (diary_entries_raw as Array).is_empty()
	)
	var latest_diary_present: bool = (
		typeof(latest_diary_raw) == TYPE_ARRAY
		and not (latest_diary_raw as Array).is_empty()
	)

	if not latest_diary_present:
		var first_frame_diary_raw: Variant = first_frame.get(
			"life_diary_lines",
			[]
		)
		if (
			typeof(first_frame_diary_raw) == TYPE_ARRAY
			and not (first_frame_diary_raw as Array).is_empty()
		):
			var first_frame_diary_lines: Array = (
				(first_frame_diary_raw as Array).duplicate(false)
			)
			resume_contract [
				"latest_life_diary_lines"
			] = first_frame_diary_lines.duplicate(false)
			latest_diary_raw = first_frame_diary_lines
			latest_diary_present = true
			diary_promoted_from_first_frame = true

	if (
		not diary_entries_present
		and latest_diary_present
	):
		var latest_diary_lines: Array = (
			(latest_diary_raw as Array).duplicate(false)
		)
		resume_contract [
			"life_diary_entries"
		] = [
			latest_diary_lines.duplicate(false)
		]
		diary_promoted_from_first_frame = true

	var normalized: Dictionary = (
		resume_contract.duplicate(false)
	)
	var candidate_signature: String = str(
		checkpoint_candidate.get(
			"residency_signature",
			normalized.get(
				"residency_signature",
				""
			)
		)
	).strip_edges()

	normalized [
		"actor_snapshot"
	] = actor_snapshot.duplicate(false)
	normalized [
		"first_frame_ui_snapshot"
	] = first_frame.duplicate(false)
	normalized [
		"actor_id"
	] = actor_id
	normalized [
		"player_id"
	] = actor_id
	normalized [
		"controlled_actor_id"
	] = actor_id
	normalized [
		"checkpoint_resume_hunger_backfilled_from_first_frame"
	] = hunger_backfilled
	normalized [
		"checkpoint_resume_hunger_normalized_from_actor_snapshot"
	] = hunger_normalized_from_actor_snapshot
	normalized [
		"checkpoint_resume_hunger_legacy_zero_conflict_repaired"
	] = hunger_legacy_zero_conflict_repaired
	normalized [
		"checkpoint_resume_legacy_diary_promoted_from_first_frame"
	] = diary_promoted_from_first_frame

	if candidate_signature != "":
		normalized [
			"residency_signature"
		] = candidate_signature



	normalized [
		"checkpoint_resume_capsule_is_observable_authority"
	] = true
	normalized [
		"checkpoint_resume_capsule_is_full_runtime_authority"
	] = false
	normalized [
		"binary_payload_required_before_visible_lens"
	] = false
	normalized [
		"full_payload_hydration_may_continue_after_lens_attach"
	] = true
	normalized [
		"progressive_observability"
	] = true

	set_meta(
		"checkpoint_cold_resume_capsule_available",
		true
	)
	set_meta(
		"checkpoint_cold_resume_capsule_is_observable_authority",
		true
	)
	set_meta(
		"checkpoint_cold_resume_capsule_is_full_runtime_authority",
		false
	)
	set_meta(
		"checkpoint_cold_resume_requires_background_payload_restore",
		true
	)
	set_meta(
		"checkpoint_cold_resume_decode_on_continue_forbidden",
		true
	)

	return normalized

func _checkpoint_resume_contract_from_payload(
	payload: Dictionary,
	checkpoint_candidate: Dictionary,
	signature: String
) -> Dictionary:
	var player_id: int = int(
		payload.get(
			"player_id",
			-1
		)
	)
	var actor_snapshot: Dictionary = {}
	var npc_rows_raw: Variant = payload.get(
		"npcs",
		[]
	)

	if typeof(npc_rows_raw) == TYPE_ARRAY:
		for raw_row in npc_rows_raw as Array:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = raw_row as Dictionary

			if int(
				row.get(
					"id",
					-1
				)
			) != player_id:
				continue

			actor_snapshot = row.duplicate(false)
			break

	if actor_snapshot.is_empty():
		return {}

	var saved_resume_contract: Dictionary = {}
	var direct_resume_raw: Variant = checkpoint_candidate.get(
		"checkpoint_resume_contract",
		{}
	)

	if typeof(direct_resume_raw) == TYPE_DICTIONARY:
		saved_resume_contract = (
			direct_resume_raw as Dictionary
		).duplicate(false)

	var load_options: Dictionary = _dict(
		checkpoint_candidate.get(
			"load_options",
			{}
		)
	)

	if saved_resume_contract.is_empty():
		var load_resume_raw: Variant = load_options.get(
			"checkpoint_resume_contract",
			{}
		)

		if typeof(load_resume_raw) == TYPE_DICTIONARY:
			saved_resume_contract = (
				load_resume_raw as Dictionary
			).duplicate(false)

	if saved_resume_contract.is_empty():
		var continue_contract: Dictionary = _dict(
			load_options.get(
				"continue_contract",
				checkpoint_candidate.get(
					"continue_contract",
					{}
				)
			)
		)
		var continue_resume_raw: Variant = (
			continue_contract.get(
				"checkpoint_resume_contract",
				{}
			)
		)

		if typeof(continue_resume_raw) == TYPE_DICTIONARY:
			saved_resume_contract = (
				continue_resume_raw as Dictionary
			).duplicate(false)

	var payload_scenario: Dictionary = _dict(
		payload.get(
			"scenario_state",
			{}
		)
	)
	var first_frame_raw: Variant = payload_scenario.get(
		"prebuilt_first_frame_ui_snapshot",
		payload_scenario.get(
			"zero_frame_consciousness_switch_surface",
			saved_resume_contract.get(
				"first_frame_ui_snapshot",
				{}
			)
		)
	)
	var first_frame_snapshot: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(first_frame_raw) == TYPE_DICTIONARY
		else {}
	)
	var hud_raw: Variant = payload_scenario.get(
		"runtime_hud_visibility_snapshot",
		saved_resume_contract.get(
			"runtime_hud_visibility_snapshot",
			{}
		)
	)
	var hud_snapshot: Dictionary = (
		(hud_raw as Dictionary).duplicate(false)
		if typeof(hud_raw) == TYPE_DICTIONARY
		else {}
	)
	var surface_deck: Dictionary = {}
	var deck_by_actor_raw: Variant = payload_scenario.get(
		"resident_main_tab_surface_contracts_by_actor",
		{}
	)

	if typeof(deck_by_actor_raw) == TYPE_DICTIONARY:
		var deck_by_actor: Dictionary = (
			deck_by_actor_raw as Dictionary
		)
		var actor_deck_raw: Variant = deck_by_actor.get(
			str(player_id),
			{}
		)

		if typeof(actor_deck_raw) == TYPE_DICTIONARY:
			surface_deck = (
				actor_deck_raw as Dictionary
			).duplicate(false)

	if surface_deck.is_empty():
		var direct_deck_raw: Variant = payload_scenario.get(
			"resident_main_tab_surface_contracts",
			saved_resume_contract.get(
				"main_tab_surface_contracts",
				{}
			)
		)

		if typeof(direct_deck_raw) == TYPE_DICTIONARY:
			surface_deck = (
				direct_deck_raw as Dictionary
			).duplicate(false)

	var diary_entries: Array = []
	var diary_store: Dictionary = _dict(
		payload_scenario.get(
			"life_diary_state_by_npc",
			{}
		)
	)
	var diary_row: Dictionary = _dict(
		diary_store.get(
			str(player_id),
			{}
		)
	)
	var diary_entries_raw: Variant = diary_row.get(
		"entries",
		saved_resume_contract.get(
			"life_diary_entries",
			[]
		)
	)

	if typeof(diary_entries_raw) == TYPE_ARRAY:
		diary_entries = (
			diary_entries_raw as Array
		).duplicate(true)

	var latest_diary_raw: Variant = (
		saved_resume_contract.get(
			"latest_life_diary_lines",
			first_frame_snapshot.get(
				"life_diary_lines",
				[]
			)
		)
	)
	var latest_diary_lines: Array = (
		(latest_diary_raw as Array).duplicate(true)
		if typeof(latest_diary_raw) == TYPE_ARRAY
		else []
	)
	var world_seed: int = int(
		payload_scenario.get(
			"world_seed",
			payload.get(
				"world_seed",
				saved_resume_contract.get(
					"world_seed",
					-1
				)
			)
		)
	)
	var seed_contract: Dictionary = _dict(
		payload_scenario.get(
			"seed_contract",
			payload.get(
				"seed_contract",
				saved_resume_contract.get(
					"seed_contract",
					{}
				)
			)
		)
	)
	var era_name: String = str(
		payload_scenario.get(
			"effective_era_name",
			payload_scenario.get(
				"era_name",
				saved_resume_contract.get(
					"era_name",
					first_frame_snapshot.get(
						"era_name",
						""
					)
				)
			)
		)
	).strip_edges()
	var era_key: String = str(
		saved_resume_contract.get(
			"era_key",
			era_name
		)
	).strip_edges().to_lower()

	if era_key == "":
		era_key = "modern"

	var audio_raw: Variant = payload_scenario.get(
		"checkpoint_resume_era_audio_context",
		saved_resume_contract.get(
			"era_audio_context",
			{}
		)
	)
	var audio_context: Dictionary = (
		(audio_raw as Dictionary).duplicate(false)
		if typeof(audio_raw) == TYPE_DICTIONARY
		else {}
	)

	if audio_context.is_empty():
		audio_context = {
			"era_key": era_key,
			"era_name": era_name,
			"year": int(
				payload.get(
					"year",
					0
				)
			),
			"player_id": player_id,
			"current_panel": "life",
			"source": "checkpoint_payload_resume_contract",
			"checkpoint_resume": true,
			"birth_intro_audio_forbidden": true
		}

	return {
		"schema": "eralife.reality_checkpoint.resume_contract",
		"version": 4,
		"checkpoint_path": str(
			checkpoint_candidate.get(
				"checkpoint_path",
				checkpoint_candidate.get(
					"path",
					""
				)
			)
		),
		"residency_signature": signature,
		"actor_id": player_id,
		"player_id": player_id,
		"controlled_actor_id": player_id,
		"actor_snapshot": actor_snapshot,
		"year": int(
			payload.get(
				"year",
				0
			)
		),
		"next_id": int(
			payload.get(
				"next_id",
				player_id + 1
			)
		),
		"world_seed": world_seed,
		"seed_contract": seed_contract,
		"era_name": era_name,
		"era_key": era_key,
		"current_panel": "life",
		"entry_kind": "checkpoint_resume",
		"resume_not_birth": true,
		"birth_intro_allowed": false,
		"first_frame_ui_snapshot": first_frame_snapshot,
		"runtime_hud_visibility_snapshot": hud_snapshot,
		"main_tab_surface_contracts": surface_deck,
		"life_diary_entries": diary_entries,
		"latest_life_diary_lines": latest_diary_lines,
		"era_audio_context": audio_context,
		"relationship_cards_packet_present": (
			surface_deck.has(
				"relationships"
			)
		),
		"main_tab_surface_packet_count": surface_deck.size(),
		"presentation_contract_complete": false,
		"binary_payload_required_before_visible_lens": false,
		"blank_life_shell_forbidden": true
	}


func _materialize_checkpoint_resume_shell(
	resident_gs: GameState,
	resume_contract: Dictionary,
	signature: String,
	checkpoint_candidate: Dictionary
) -> Dictionary:
	if resident_gs == null:
		return {
			"success": false,
			"reason": "resident_runtime_missing"
		}

	# FIX: this is the only hydration a checkpoint resume performs -- the resume truth
	# reports full_payload_hydrated=false, so the save payload is never applied. Three
	# earlier attempts put this restore on payload-hydration paths that never run.
	# Apply the engine registry carried by the resume contract here.
	var resume_registry: Dictionary = _dict(
		resume_contract.get("engine_registry", {})
	)
	var resume_restored: Array = []

	if not resume_registry.is_empty():
		# The stores arrived but were dropped: the chassis runtime has no vehicle,
		# belongings, property or heirloom engine yet, so every guard below failed and
		# only the graph and entity registry survived. Create whichever engines are
		# missing before applying -- an engine with no data is useless anyway, and the
		# data is right here.
		if resident_gs.vehicle_engine == null and resume_registry.has("vehicles"):
			resident_gs.vehicle_engine = VehicleEngine.new(resident_gs)

		if resident_gs.belongings_engine == null and resume_registry.has("belongings"):
			resident_gs.belongings_engine = BelongingsEngine.new(resident_gs)

		if resident_gs.property_engine == null and resume_registry.has("properties"):
			resident_gs.property_engine = PropertyEngine.new(resident_gs)

		if resident_gs.heirloom_engine == null and resume_registry.has("heirlooms"):
			resident_gs.heirloom_engine = HeirloomEngine.new(resident_gs)

		if resident_gs.vehicle_engine != null and resume_registry.has("vehicles"):
			resident_gs.vehicle_engine.vehicles = resume_registry.get("vehicles", {})
			resume_restored.append("vehicles")

		if resident_gs.belongings_engine != null and resume_registry.has("belongings"):
			resident_gs.belongings_engine.belongings = resume_registry.get("belongings", {})
			resume_restored.append("belongings")

		if resident_gs.property_engine != null and resume_registry.has("properties"):
			resident_gs.property_engine.properties = resume_registry.get("properties", {})
			resume_restored.append("properties")

			if resume_registry.has("used_addresses"):
				resident_gs.property_engine.used_addresses = resume_registry.get("used_addresses", {})

		if resident_gs.heirloom_engine != null and resume_registry.has("heirlooms"):
			resident_gs.heirloom_engine.heirlooms = resume_registry.get("heirlooms", {})
			resume_restored.append("heirlooms")

	# FIX: pets stayed broken after a load -- existing ones did not come back and new
	# purchases silently did nothing -- because the resumed runtime has no
	# relationship-graph or pets engines. The graph data alone is useless without the
	# engines that read and write it, so create them here the same way the asset
	# engines are created above.
	if resident_gs.relationship_graph_contract_engine == null:
		resident_gs.relationship_graph_contract_engine = (
			RelationshipGraphContractEngine.new(resident_gs)
		)

	if resident_gs.pets_contract_engine == null:
		resident_gs.pets_contract_engine = PetsContractEngine.new(resident_gs)

	# The graph and registry must be well-formed dictionaries before either engine
	# touches them, or a restored-but-malformed graph breaks every later write.
	if typeof(resident_gs.entity_registry) != TYPE_DICTIONARY:
		resident_gs.entity_registry = {}

	if typeof(resident_gs.canonical_relationship_graph) != TYPE_DICTIONARY:
		resident_gs.canonical_relationship_graph = {}

	var resume_graph: Dictionary = _dict(
		resume_contract.get("canonical_relationship_graph", {})
	)

	if not resume_graph.is_empty():
		resident_gs.canonical_relationship_graph = resume_graph
		resume_restored.append("relationship_graph")

	# Restore the entity registry whenever the contract carries the key at all, even
	# if empty. Skipping an empty one leaves the resumed runtime holding entities from
	# a different life while the graph edges come from this one -- pets then reference
	# animals that do not exist in the registry.
	if resume_contract.has("entity_registry"):
		resident_gs.entity_registry = _dict(
			resume_contract.get("entity_registry", {})
		)
		resume_restored.append("entity_registry")

	EraLog.truth(
		"ERALIFE_RESUME_REGISTRY_RESTORED|available=%d|restored=%s"
		% [resume_registry.size(), str(resume_restored)]
	)

	# Report the actual state of the resumed runtime rather than assuming which
	# engines exist. Four attempts at the pet problem have guessed at this; measure it.
	EraLog.truth(
		"ERALIFE_RESUME_RUNTIME|graph_engine=%s|pets_engine=%s|entity_count=%d|edge_count=%d|is_player_runtime=%s"
		% [
			str(resident_gs.relationship_graph_contract_engine != null),
			str(resident_gs.pets_contract_engine != null),
			resident_gs.entity_registry.size() if typeof(resident_gs.entity_registry) == TYPE_DICTIONARY else -1,
			_dict(resident_gs.canonical_relationship_graph.get("edges", {})).size(),
			str(gs != null and resident_gs == gs)
		]
	)

	var bootstrap: Dictionary = (
		resident_gs
		.resident_runtime_bootstrap_snapshot()
	)
	var engine_graph_hot: bool = (
		resident_gs.resident_runtime_bootstrap_complete
		and not resident_gs.resident_runtime_bootstrap_failed
		and bool(
			bootstrap.get(
				"complete",
				false
			)
		)
	)





	var actor_snapshot: Dictionary = _dict(
		resume_contract.get(
			"actor_snapshot",
			{}
		)
	)
	var actor_id: int = int(
		resume_contract.get(
			"controlled_actor_id",
			resume_contract.get(
				"actor_id",
				actor_snapshot.get(
					"id",
					-1
				)
			)
		)
	)

	if actor_snapshot.is_empty() or actor_id <= 0:
		return {
			"success": false,
			"reason": (
				"checkpoint_resume_actor_snapshot_missing"
			),
			"actor_id": actor_id
		}

	var actor:= Person.new()
	var skipped_properties: Array = [
		"partner",
		"person_contract_slice"
	]

	for property_row in actor.get_property_list():
		var property_name: String = str(
			property_row.get(
				"name",
				""
			)
		)

		if (
			property_name == ""
			or property_name in skipped_properties
			or not actor_snapshot.has(property_name)
		):
			continue

		actor.set(
			property_name,
			actor_snapshot [property_name]
		)

	actor.id = actor_id
	resident_gs.player = actor
	resident_gs.player_id = actor_id
	resident_gs.npcs = [actor]
	resident_gs.year = int(
		resume_contract.get(
			"year",
			resident_gs.year
		)
	)
	resident_gs.next_id = maxi(
		actor_id + 1,
		int(
			resume_contract.get(
				"next_id",
				actor_id + 1
			)
		)
	)
	resident_gs._rebuild_npc_index()

	if typeof(resident_gs.scenario_state) != TYPE_DICTIONARY:
		resident_gs.scenario_state = {}

	var first_frame_raw: Variant = resume_contract.get(
		"first_frame_ui_snapshot",
		{}
	)
	var first_frame_snapshot: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(first_frame_raw) == TYPE_DICTIONARY
		else {}
	)

	var hud_raw: Variant = resume_contract.get(
		"runtime_hud_visibility_snapshot",
		{}
	)
	var hud_snapshot: Dictionary = (
		(hud_raw as Dictionary).duplicate(false)
		if typeof(hud_raw) == TYPE_DICTIONARY
		else {}
	)
	hud_snapshot = (
		resident_gs
		._checkpoint_resume_hud_visibility_snapshot_for_current_actor(
			hud_snapshot
		)
	)

	resume_contract [
		"runtime_hud_visibility_snapshot"
	] = hud_snapshot
	var surface_deck_raw: Variant = resume_contract.get(
		"main_tab_surface_contracts",
		{}
	)
	var surface_deck: Dictionary = (
		(surface_deck_raw as Dictionary).duplicate(false)
		if typeof(surface_deck_raw) == TYPE_DICTIONARY
		else {}
	)
	var diary_entries_raw: Variant = resume_contract.get(
		"life_diary_entries",
		[]
	)
	var diary_entries: Array = (
		(diary_entries_raw as Array).duplicate(false)
		if typeof(diary_entries_raw) == TYPE_ARRAY
		else []
	)
	var audio_context_raw: Variant = resume_contract.get(
		"era_audio_context",
		{}
	)
	var audio_context: Dictionary = (
		(audio_context_raw as Dictionary).duplicate(false)
		if typeof(audio_context_raw) == TYPE_DICTIONARY
		else {}
	)
	var world_seed: int = int(
		resume_contract.get(
			"world_seed",
			-1
		)
	)
	var seed_contract_raw: Variant = resume_contract.get(
		"seed_contract",
		{}
	)
	var seed_contract: Dictionary = (
		(seed_contract_raw as Dictionary).duplicate(false)
		if typeof(seed_contract_raw) == TYPE_DICTIONARY
		else {}
	)
	var era_name: String = str(
		resume_contract.get(
			"era_name",
			audio_context.get(
				"era_name",
				""
			)
		)
	).strip_edges()

	var era_key: String = str(
		resume_contract.get(
			"era_key",
			audio_context.get(
				"era_key",
				""
			)
		)
	).strip_edges().to_lower()



	resident_gs.era = (
		resident_gs._resolve_loaded_era_from_save_data(
			{
				"era_name": era_name
			},
			resident_gs.year
		)
	)

	if resident_gs.era == null:
		return {
			"success": false,
			"reason": (
				"checkpoint_resume_era_truth_unavailable"
			),
			"actor_id": actor_id,
			"year": resident_gs.year,
			"requested_era_name": era_name
		}

	var resolved_era_name: String = ""
	var resolved_era_key: String = ""

	if typeof(
		resident_gs.era
	) == TYPE_DICTIONARY:
		var resolved_era_dict: Dictionary = (
			resident_gs.era as Dictionary
		)

		resolved_era_name = str(
			resolved_era_dict.get(
				"name",
				resolved_era_dict.get(
					"era_name",
					era_name
				)
			)
		).strip_edges()

		resolved_era_key = str(
			resolved_era_dict.get(
				"key",
				resolved_era_dict.get(
					"era_key",
					""
				)
			)
		).strip_edges().to_lower()

	else:
		resolved_era_name = str(
			resident_gs.era.get(
				"name"
			)
		).strip_edges()

		resolved_era_key = str(
			resident_gs.era.get(
				"key"
			)
		).strip_edges().to_lower()

	if resolved_era_name == "":
		resolved_era_name = era_name

	if resolved_era_name == "":
		return {
			"success": false,
			"reason": (
				"checkpoint_resume_era_name_unavailable"
			),
			"actor_id": actor_id,
			"year": resident_gs.year
		}

	if resolved_era_key == "":
		resolved_era_key = (
			resolved_era_name.to_lower()
		)

	era_name = resolved_era_name
	era_key = resolved_era_key



	var first_frame_diary_lines: Array = []

	var first_frame_diary_raw: Variant = (
		resume_contract.get(
			"latest_life_diary_lines",
			first_frame_snapshot.get(
				"life_diary_lines",
				[]
			)
		)
	)

	if typeof(
		first_frame_diary_raw
	) == TYPE_ARRAY:
		first_frame_diary_lines = (
			(first_frame_diary_raw as Array)
			.duplicate(false)
		)

	first_frame_snapshot = (
		resident_gs
		._checkpoint_resume_first_frame_snapshot_for_current_actor(
			first_frame_snapshot,
			first_frame_diary_lines,
			str(
				resume_contract.get(
					"current_panel",
					"life"
				)
			)
		)
	)

	resume_contract [
		"era_name"
	] = era_name
	resume_contract [
		"era_key"
	] = era_key
	resume_contract [
		"first_frame_ui_snapshot"
	] = first_frame_snapshot

	audio_context [
		"era_name"
	] = era_name
	audio_context [
		"era_key"
	] = era_key
	audio_context [
		"year"
	] = resident_gs.year

	resume_contract [
		"era_audio_context"
	] = audio_context

	resident_gs.scenario_state [
		"resident_runtime_signature"
	] = signature
	resident_gs.scenario_state [
		"resident_runtime_attached_signature"
	] = signature
	resident_gs.scenario_state [
		"resident_runtime_restored_from_checkpoint"
	] = true
	resident_gs.scenario_state [
		"resident_runtime_checkpoint_path"
	] = str(
		checkpoint_candidate.get(
			"checkpoint_path",
			checkpoint_candidate.get(
				"path",
				""
			)
		)
	)
	resident_gs.scenario_state [
		"resident_runtime_execution_mode"
	] = "resident_playable_checkpoint"
	resident_gs.scenario_state [
		"resident_runtime_engine_graph_ready"
	] = engine_graph_hot
	resident_gs.scenario_state [
		"resident_runtime_engine_graph_background_tail"
	] = not engine_graph_hot
	resident_gs.scenario_state [
		"checkpoint_engine_construction_after_lens_attach_forbidden"
	] = false
	resident_gs.scenario_state [
		"checkpoint_engine_construction_after_lens_attach_worker_only"
	] = not engine_graph_hot
	resident_gs.scenario_state [
		"checkpoint_engine_construction_on_renderer_thread_forbidden"
	] = true
	resident_gs.scenario_state [
		"checkpoint_first_frame_truth_does_not_wait_for_engine_graph"
	] = true
	resident_gs.scenario_state [
		"resident_runtime_tabs_require_no_click_build"
	] = true
	resident_gs.scenario_state [
		"legacy_playable_life_shell_layout_forbidden"
	] = true
	resident_gs.scenario_state [
		"checkpoint_resume_contract"
	] = resume_contract.duplicate(false)
	resident_gs.scenario_state [
		"checkpoint_resume_controlled_actor_id"
	] = actor_id
	resident_gs.scenario_state [
		"checkpoint_resume_current_panel"
	] = str(
		resume_contract.get(
			"current_panel",
			"life"
		)
	)
	resident_gs.scenario_state [
		"checkpoint_resume_blank_shell_forbidden"
	] = true
	resident_gs.scenario_state [
		"checkpoint_resume_first_frame_truth_hot"
	] = not first_frame_snapshot.is_empty()
	resident_gs.scenario_state [
		"checkpoint_resume_presentation_contract_complete"
	] = bool(
		resume_contract.get(
			"presentation_contract_complete",
			false
		)
	)
	resident_gs.scenario_state [
		"checkpoint_resume_not_birth"
	] = true
	resident_gs.scenario_state [
		"birth_intro_cry_allowed"
	] = false
	resident_gs.scenario_state [
		"birth_intro_cry_armed_for_first_playable_ui"
	] = false
	resident_gs.scenario_state [
		"newborn_birth_intro_required_for_next_birth_start"
	] = false
	resident_gs.scenario_state [
		"checkpoint_payload_hydration_tail_pending"
	] = true
	resident_gs.scenario_state [
		"checkpoint_payload_decode_deferred_until_lens_detached"
	] = false
	resident_gs.scenario_state [
		"checkpoint_payload_worker_may_run_ahead_of_observation"
	] = true
	resident_gs.scenario_state [
		"checkpoint_resume_actor_contract_tail_pending"
	] = true

	if world_seed >= 0:
		resident_gs.scenario_state ["world_seed"] = world_seed

	if not seed_contract.is_empty():
		resident_gs.scenario_state [
			"seed_contract"
		] = seed_contract

	if era_name != "":
		resident_gs.scenario_state [
			"effective_era_name"
		] = era_name
		resident_gs.scenario_state [
			"active_era_name"
		] = era_name
		resident_gs.scenario_state [
			"current_era_name"
		] = era_name
		resident_gs.scenario_state [
			"era_name"
		] = era_name

	if era_key != "":
		resident_gs.scenario_state [
			"checkpoint_resume_era_key"
		] = era_key

	if not first_frame_snapshot.is_empty():
		resident_gs.scenario_state [
			"prebuilt_first_frame_ui_snapshot"
		] = first_frame_snapshot
		resident_gs.scenario_state [
			"zero_frame_consciousness_switch_surface"
		] = first_frame_snapshot
		resident_gs.scenario_state [
			"first_frame_ui_snapshot"
		] = first_frame_snapshot

	if not hud_snapshot.is_empty():
		resident_gs.scenario_state [
			"runtime_hud_visibility_snapshot"
		] = hud_snapshot
		resident_gs.scenario_state [
			"runtime_hud_visibility_snapshot_reason"
		] = "checkpoint_resume_contract"

	if not surface_deck.is_empty():
		resident_gs.scenario_state [
			"resident_main_tab_surface_contracts"
		] = surface_deck
		resident_gs.scenario_state [
			"resident_main_tab_surface_contracts_by_actor"
		] = {
			str(actor_id): surface_deck
		}

	if not diary_entries.is_empty():
		var diary_store: Dictionary = {
			str(actor_id): {
				"entries": diary_entries,
				"world_feed_cursor": 0,
				"global_memory_cursor": 0,
				"player_memory_cursor": 0,
				"owner_year": resident_gs.year,
				"owner_age": actor.age,
			}
		}
		resident_gs.scenario_state [
			"life_diary_state_by_npc"
		] = diary_store
		resident_gs.scenario_state [
			"checkpoint_resume_life_diary_entries"
		] = diary_entries

	if not audio_context.is_empty():
		resident_gs.scenario_state [
			"checkpoint_resume_era_audio_context"
		] = audio_context

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.checkpoint_resume_shell_report",
		"version": 3,
		"signature": signature,
		"actor_id": actor_id,
		"year": resident_gs.year,
		"era_name": era_name,
		"era_key": era_key,
		"era_truth_hot": (
			resident_gs.era != null
		),
		"first_frame_actor_scalar_truth_current": bool(
			first_frame_snapshot.get(
				"checkpoint_actor_scalar_truth_current",
				false
			)
		),
		"world_seed": world_seed,
		"first_frame_snapshot_hot": (
			not first_frame_snapshot.is_empty()
		),
		"hud_snapshot_hot": not hud_snapshot.is_empty(),
		"main_tab_surface_packet_count": surface_deck.size(),
		"relationship_cards_packet_present": surface_deck.has(
			"relationships"
		),
		"life_diary_entry_count": diary_entries.size(),
		"era_audio_context_hot": not audio_context.is_empty(),
		"resume_not_birth": true,
		"playable_before_full_residency": true,
		"engine_graph_hot": engine_graph_hot,
		"engine_graph_worker_tail_required": not engine_graph_hot,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	EraLog.truth(
		"ERALIFE_CHECKPOINT_RESUME_TRUTH"
		+ "|signature=" + signature
		+ "|actor_id=" + str(actor_id)
		+ "|year=" + str(resident_gs.year)
		+ "|first_frame_hot=" + str(
			not first_frame_snapshot.is_empty()
		).to_lower()
		+ "|hud_hot=" + str(
			not hud_snapshot.is_empty()
		).to_lower()
		+ "|tab_packets=" + str(surface_deck.size())
		+ "|relationship_cards_packet=" + str(
			surface_deck.has("relationships")
		).to_lower()
		+ "|diary_entries=" + str(diary_entries.size())
		+ "|era_audio_context=" + str(
			not audio_context.is_empty()
		).to_lower()
		+ "|resume_not_birth=true"
		+ "|person_contract_rebuilt=false"
		+ "|full_payload_hydrated=false"
		+ "|at_ms=" + str(int(Time.get_ticks_msec()))
	)

	return report

func _service_rehydration_record(
	signature: String,
	record: Dictionary
) -> void:
	var state: String = str(
		record.get(
			"state",
			"checkpoint_resolution_pending"
		)
	)

	if state == "checkpoint_resolution_pending":
		# DIAGNOSTIC: the load reserves a checkpoint and then polls forever with
		# success=true|ready=false, which means this resolution never completes. Report
		# entry and the candidate result so we can see whether the pump reaches here at
		# all, and if so what it rejects.
		var resolved_candidate: Dictionary = (
			_checkpoint_candidate_for_record(
				signature,
				record
			)
		)

		EraLog.truth(
			"ERALIFE_CHECKPOINT_RESOLVE|signature=%s|candidate_success=%s|reason=%s"
			% [
				signature,
				str(resolved_candidate.get("success", false)),
				str(resolved_candidate.get("reason", "-"))
			]
		)

		if not bool(
			resolved_candidate.get(
				"success",
				false
			)
		):
			_fail_record(
				record,
				signature,
				"resident_checkpoint_unavailable",
				resolved_candidate
			)
			return

		var runtime: GameState = _take_available_chassis()
		var used_hot_chassis: bool = (
			runtime != null
		)




		if runtime == null:
			runtime = (
				GameState.create_resident_chassis_shell()
			)

		if runtime == null:
			_fail_record(
				record,
				signature,
				"resident_checkpoint_shell_allocation_failed"
			)
			return

		record [
			"checkpoint_waiting_for_hot_chassis"
		] = false
		record [
			"checkpoint_claimed_worker_hot_chassis"
		] = used_hot_chassis
		record [
			"checkpoint_lightweight_chassis_fallback_used"
		] = not used_hot_chassis
		record [
			"checkpoint_engine_graph_must_be_hot_before_attach"
		] = false
		record [
			"constructor_work_after_lens_attach_forbidden"
		] = false
		record [
			"constructor_work_after_lens_attach_worker_only"
		] = not used_hot_chassis
		record [
			"constructor_work_on_renderer_thread_after_lens_attach_forbidden"
		] = true

		if used_hot_chassis:
			record [
				"checkpoint_claimed_worker_hot_chassis_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		EraLog.truth(
			"ERALIFE_CKPT_STAGE|signature=%s|stage=chassis_allocated|hot=%s"
			% [signature, str(used_hot_chassis)]
		)

		_inject_shared_authorities(
			runtime
		)

		EraLog.truth("ERALIFE_CKPT_STAGE|signature=%s|stage=authorities_injected" % signature)

		if runtime.reality_checkpoint_contract_engine == null:
			runtime.reality_checkpoint_contract_engine = (
				RealityCheckpointContractEngine.new(
					runtime
				)
			)

		if runtime.world_contract_hydrator == null:
			runtime.world_contract_hydrator = (
				WorldContractHydrator.new(
					runtime
				)
			)

		EraLog.truth("ERALIFE_CKPT_STAGE|signature=%s|stage=engines_built" % signature)

		var candidate_resume_contract: Dictionary = (
			_checkpoint_resume_contract_for_candidate(
				resolved_candidate
			)
		)
		var candidate_resume_report: Dictionary = {}

		EraLog.truth(
			"ERALIFE_CKPT_STAGE|signature=%s|stage=resume_contract_built|empty=%s|candidate_keys=%s"
			% [
				signature,
				str(candidate_resume_contract.is_empty()),
				str(resolved_candidate.keys()).substr(0, 300)
			]
		)

		if not candidate_resume_contract.is_empty():
			candidate_resume_report = (
				_materialize_checkpoint_resume_shell(
					runtime,
					candidate_resume_contract,
					signature,
					resolved_candidate
				)
			)

		var now_ms: int = int(
			Time.get_ticks_msec()
		)
		var resume_shell_ready: bool = bool(
			candidate_resume_report.get(
				"success",
				false
			)
		)

		# The transition to "ready" happens only inside `if resume_shell_ready:`. When
		# the resume shell fails to materialise nothing is reported at all -- the
		# record just stays checkpoint_resolution_pending forever, which is the load
		# polling 4,500 times with ready=false. Report the outcome and its reason.
		EraLog.truth(
			"ERALIFE_CKPT_STAGE|signature=%s|stage=resume_shell|ready=%s|reason=%s|contract_empty=%s"
			% [
				signature,
				str(resume_shell_ready),
				str(candidate_resume_report.get("reason", "-")),
				str(candidate_resume_contract.is_empty())
			]
		)

		record ["runtime_ref"] = runtime
		record ["checkpoint_candidate"] = (
			resolved_candidate.duplicate(false)
		)
		record ["checkpoint_resume_contract"] = (
			candidate_resume_contract.duplicate(false)
		)
		record ["checkpoint_resume_report"] = (
			candidate_resume_report.duplicate(false)
		)
		record ["rehydration_attempted"] = true
		record ["rehydration_started_at_ms"] = now_ms
		record ["checkpoint_resolved_at_ms"] = now_ms
		record ["used_hot_chassis"] = used_hot_chassis
		record [
			"used_lightweight_checkpoint_chassis"
		] = not used_hot_chassis
		record [
			"renderer_thread_hydration_performed"
		] = false
		record [
			"checkpoint_hydration_blocks_title_card"
		] = false
		record [
			"checkpoint_hydration_blocks_main_menu"
		] = false
		record [
			"worker_thread_mutates_visible_controls"
		] = false

		if resume_shell_ready:
			var engine_graph_worker_started: bool = false
			var engine_graph_worker_error: int = OK

			if not used_hot_chassis:
				var checkpoint_path: String = str(
					resolved_candidate.get(
						"checkpoint_path",
						resolved_candidate.get(
							"path",
							""
						)
					)
				).strip_edges()

				var engine_graph_worker:= Thread.new()

				engine_graph_worker_error = (
					engine_graph_worker.start(
						Callable(
							self,
							"_hydrate_checkpoint_engine_graph_on_worker"
						).bind(
							runtime,
							signature,
							checkpoint_path
						),
						Thread.PRIORITY_LOW
					)
				)

				if engine_graph_worker_error == OK:
					checkpoint_engine_graph_threads [
						signature
					] = engine_graph_worker
					engine_graph_worker_started = true

			EraLog.truth(
				"ERALIFE_CKPT_STAGE|signature=%s|stage=marked_ready" % signature
			)

			record ["state"] = "ready"
			record ["ready_at_ms"] = now_ms
			record ["rehydration_completed"] = false
			record ["residency_tail_pending"] = true
			record ["residency_tail_started"] = false

			record [
				"resident_chassis_tail_complete"
			] = used_hot_chassis
			record [
				"resident_chassis_tail_completed_at_ms"
			] = (
				now_ms
				if used_hot_chassis
				else 0
			)
			record [
				"checkpoint_engine_graph_hot_before_ready"
			] = used_hot_chassis
			record [
				"checkpoint_engine_graph_worker_active"
			] = engine_graph_worker_started
			record [
				"checkpoint_engine_graph_worker_started_at_ms"
			] = (
				now_ms
				if engine_graph_worker_started
				else 0
			)
			record [
				"checkpoint_engine_graph_worker_start_failed"
			] = (
				not used_hot_chassis
				and not engine_graph_worker_started
			)
			record [
				"checkpoint_engine_graph_worker_error"
			] = engine_graph_worker_error
			record [
				"constructor_work_on_renderer_thread_after_lens_attach_forbidden"
			] = true
			record [
				"constructor_work_after_lens_attach_worker_only"
			] = not used_hot_chassis

			record ["projection_tail_pending"] = false
			record ["playable_before_full_residency"] = true
			record [
				"checkpoint_resume_shell_ready_before_payload_tail"
			] = true

			record ["worker_thread_used"] = (
				used_hot_chassis
				or engine_graph_worker_started
			)
			record ["worker_thread_active"] = (
				engine_graph_worker_started
			)

			record [
				"checkpoint_payload_decode_pending"
			] = true
			record [
				"checkpoint_payload_apply_pending"
			] = true
			record [
				"checkpoint_payload_decode_deferred_until_lens_detached"
			] = false
			record [
				"checkpoint_payload_worker_start_on_continue_forbidden"
			] = false
			record [
				"checkpoint_resume_contract_is_visible_truth_authority"
			] = true
			record [
				"checkpoint_binary_payload_is_not_first_frame_authority"
			] = true

			resident_records [
				signature
			] = record

			_append_service_key(
				"resident:%s" % signature
			)
			_ensure_service_pump()

			EraLog.truth(
				"ERALIFE_CHECKPOINT_REHYDRATION_START_TRUTH"
				+ "|signature=" + signature
				+ "|state=ready"
				+ "|resume_shell_ready=true"
				+ "|used_hot_chassis="
				+ str(
					used_hot_chassis
				).to_lower()
				+ "|engine_graph_hot_before_ready="
				+ str(
					used_hot_chassis
				).to_lower()
				+ "|engine_graph_worker_active="
				+ str(
					engine_graph_worker_started
				).to_lower()
				+ "|renderer_thread_constructors_after_attach=false"
				+ "|constructors_after_attach_worker_only="
				+ str(
					not used_hot_chassis
				).to_lower()
				+ "|binary_decode_deferred_until_detach=false"
				+ "|visible_lens_blocked=false"
				+ "|at_ms=" + str(now_ms)
			)
			return



		var new_checkpoint_hydration_worker: Thread = Thread.new()
		var worker_error: int = (
			new_checkpoint_hydration_worker.start(
				Callable(
					self,
					"_hydrate_checkpoint_runtime_on_worker"
				).bind(
					resolved_candidate.duplicate(false),
					signature
				),
				Thread.PRIORITY_LOW
			)
		)

		if worker_error != OK:
			_fail_record(
				record,
				signature,
				"resident_checkpoint_worker_start_failed",
				{
					"worker_error": worker_error,
					"checkpoint_candidate": (
						resolved_candidate.duplicate(false)
					)
				}
			)
			return

		checkpoint_hydration_threads [
			signature
		] = new_checkpoint_hydration_worker
		record ["state"] = "rehydration_pending"
		record ["worker_thread_used"] = true
		record ["worker_thread_active"] = true
		record [
			"checkpoint_worker_decodes_immutable_payload_only"
		] = true
		record ["checkpoint_payload_decode_pending"] = true
		record ["checkpoint_payload_apply_pending"] = true
		record [
			"checkpoint_resume_shell_ready_before_payload_tail"
		] = false
		resident_records [signature] = record

		EraLog.truth(
			"ERALIFE_CHECKPOINT_REHYDRATION_START_TRUTH"
			+ "|signature=" + signature
			+ "|state=rehydration_pending"
			+ "|resume_shell_ready=false"
			+ "|used_hot_chassis=" + str(
				used_hot_chassis
			).to_lower()
			+ "|worker_started=true"
			+ "|legacy_checkpoint=true"
			+ "|at_ms=" + str(now_ms)
		)

		_append_service_key(
			"resident:%s" % signature
		)
		_ensure_service_pump()
		return

	if state != "rehydration_pending":
		return

	var runtime_raw: Variant = record.get(
		"runtime_ref",
		null
	)

	if not (runtime_raw is GameState):
		_fail_record(
			record,
			signature,
			"resident_rehydration_runtime_missing"
		)
		return

	var resident_gs: GameState = runtime_raw as GameState
	var checkpoint_candidate: Dictionary = _dict(
		record.get(
			"checkpoint_candidate",
			{}
		)
	)

	if checkpoint_candidate.is_empty():
		_fail_record(
			record,
			signature,
			"resident_checkpoint_candidate_missing"
		)
		return

	var worker_raw: Variant = checkpoint_hydration_threads.get(
		signature,
		null
	)

	if not (worker_raw is Thread):
		_fail_record(
			record,
			signature,
			"resident_checkpoint_worker_missing",
			{
				"checkpoint_candidate": (
					checkpoint_candidate.duplicate(false)
				)
			}
		)
		return

	var active_checkpoint_hydration_worker: Thread = (
		worker_raw as Thread
	)

	if active_checkpoint_hydration_worker.is_alive():
		record ["worker_thread_active"] = true
		record ["worker_thread_last_poll_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record [
			"renderer_thread_poll_only"
		] = true
		record [
			"renderer_thread_hydration_performed"
		] = false
		record [
			"worker_thread_mutates_game_state"
		] = false
		resident_records [signature] = record
		return

	var decode_raw: Variant = (
		active_checkpoint_hydration_worker.wait_to_finish()
	)

	checkpoint_hydration_threads.erase(signature)

	var decode_report: Dictionary = (
		decode_raw as Dictionary
		if typeof(decode_raw) == TYPE_DICTIONARY
		else {}
	)

	record ["worker_thread_active"] = false
	record ["worker_thread_complete"] = true
	record ["worker_thread_completed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	record [
		"worker_thread_mutates_game_state"
	] = false
	record [
		"checkpoint_payload_decode_pending"
	] = false

	if not bool(
		decode_report.get(
			"success",
			false
		)
	):
		_fail_record(
			record,
			signature,
			"resident_checkpoint_decode_failed",
			decode_report
		)
		return

	var payload: Dictionary = _dict(
		decode_report.get(
			"payload",
			{}
		)
	)

	if payload.is_empty():
		_fail_record(
			record,
			signature,
			"resident_checkpoint_decoded_payload_empty",
			decode_report
		)
		return

	var decoded_resume_contract: Dictionary = _dict(
		record.get(
			"checkpoint_resume_contract",
			{}
		)
	)

	if decoded_resume_contract.is_empty():
		decoded_resume_contract = (
			_checkpoint_resume_contract_from_payload(
				payload,
				checkpoint_candidate,
				signature
			)
		)

	if decoded_resume_contract.is_empty():
		_fail_record(
			record,
			signature,
			"resident_checkpoint_resume_contract_missing",
			{
				"decode_report": decode_report.duplicate(false),
				"checkpoint_candidate": (
					checkpoint_candidate.duplicate(false)
				)
			}
		)
		return

	var current_first_frame_raw: Variant = (
		decoded_resume_contract.get(
			"first_frame_ui_snapshot",
			{}
		)
	)
	var current_first_frame: Dictionary = (
		current_first_frame_raw as Dictionary
		if typeof(current_first_frame_raw) == TYPE_DICTIONARY
		else {}
	)

	if current_first_frame.is_empty():
		var payload_scenario_state: Dictionary = _dict(
			payload.get(
				"scenario_state",
				{}
			)
		)
		var payload_first_frame_raw: Variant = (
			payload_scenario_state.get(
				"zero_frame_consciousness_switch_surface",
				payload_scenario_state.get(
					"prebuilt_first_frame_ui_snapshot",
					{}
				)
			)
		)

		if typeof(payload_first_frame_raw) == TYPE_DICTIONARY:
			decoded_resume_contract [
				"first_frame_ui_snapshot"
			] = (
				payload_first_frame_raw as Dictionary
			).duplicate(false)

	var decoded_resume_report: Dictionary = (
		_materialize_checkpoint_resume_shell(
			resident_gs,
			decoded_resume_contract,
			signature,
			checkpoint_candidate
		)
	)

	if not bool(
		decoded_resume_report.get(
			"success",
			false
		)
	):
		_fail_record(
			record,
			signature,
			"resident_checkpoint_resume_shell_failed",
			decoded_resume_report
		)
		return

	var ready_at_ms: int = int(Time.get_ticks_msec())

	record ["runtime_ref"] = resident_gs
	record ["checkpoint_resume_contract"] = (
		decoded_resume_contract.duplicate(false)
	)
	record ["checkpoint_resume_report"] = (
		decoded_resume_report.duplicate(false)
	)
	record ["checkpoint_decode_report"] = (
		decode_report.duplicate(false)
	)
	record ["checkpoint_decoded_payload"] = payload
	record ["checkpoint_payload_apply_pending"] = true
	record ["rehydration_completed"] = false
	record ["state"] = "ready"
	record ["ready_at_ms"] = ready_at_ms
	record ["residency_tail_pending"] = true
	record ["residency_tail_started"] = false
	record ["projection_tail_pending"] = false
	record ["playable_before_full_residency"] = true
	record [
		"renderer_thread_hydration_performed"
	] = false
	record [
		"worker_thread_mutated_game_state"
	] = false
	record [
		"checkpoint_resume_shell_ready_before_payload_tail"
	] = true
	resident_records [signature] = record

	EraLog.truth(
		"ERALIFE_CHECKPOINT_REHYDRATION_READY_TRUTH"
		+ "|signature=" + signature
		+ "|actor_id=" + str(resident_gs.player_id)
		+ "|state=ready"
		+ "|payload_tail_pending=true"
		+ "|worker_mutated_game_state=false"
		+ "|recursive_payload_copy=false"
		+ "|at_ms=" + str(ready_at_ms)
	)

	_append_service_key(
		"resident:%s" % signature
	)
	_ensure_service_pump()
func _service_ready_checkpoint_payload_tail(
	signature: String,
	record: Dictionary,
	resident_gs: GameState
) -> bool:
	if not bool(
		record.get(
			"checkpoint_payload_apply_pending",
			false
		)
	):
		return true

	var lens_attached: bool = bool(
		record.get(
			"lens_attached",
			false
		)
	)
	var playable_surface_visible: bool = false

	if typeof(
		resident_gs.scenario_state
	) == TYPE_DICTIONARY:
		playable_surface_visible = (
			bool(
				resident_gs.scenario_state.get(
					"playable_life_shell_has_visible_sovereignty",
					false
				)
			)
			or bool(
				resident_gs.scenario_state.get(
					"playable_life_surface_has_visual_authority",
					false
				)
			)
			or bool(
				resident_gs.scenario_state.get(
					"checkpoint_progressive_core_shell_commit_complete",
					false
				)
			)
		)




	if (
		lens_attached
		and not playable_surface_visible
	):
		record [
			"checkpoint_payload_waiting_for_visible_life_lens"
		] = false
		record [
			"checkpoint_payload_allowed_ahead_of_visible_life_lens"
		] = true
		record [
			"checkpoint_payload_main_thread_hydration_started"
		] = false
		record [
			"checkpoint_payload_decode_started"
		] = bool(
			record.get(
				"checkpoint_payload_decode_started",
				false
			)
		)

		resident_records [
			signature
		] = record




	var payload_raw: Variant = record.get(
		"checkpoint_decoded_payload",
		{}
	)
	var payload: Dictionary = (
		payload_raw as Dictionary
		if typeof(payload_raw) == TYPE_DICTIONARY
		else {}
	)

	var spatial_hydration_plan_raw: Variant = record.get(
		"checkpoint_spatial_hydration_plan",
		{}
	)
	var spatial_hydration_plan: Dictionary = (
		spatial_hydration_plan_raw as Dictionary
		if typeof(
			spatial_hydration_plan_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if payload.is_empty():
		var worker_raw: Variant = (
			checkpoint_hydration_threads.get(
				signature,
				null
			)
		)

		if not (worker_raw is Thread):
			var decode_candidate: Dictionary = _dict(
				record.get(
					"checkpoint_candidate",
					{}
				)
			)

			if decode_candidate.is_empty():
				record [
					"checkpoint_payload_apply_pending"
				] = false
				record [
					"checkpoint_payload_tail_failed"
				] = true
				record [
					"checkpoint_payload_tail_failure_reason"
				] = "checkpoint_candidate_missing"

				resident_records [
					signature
				] = record

				return true

			var new_decode_worker: Thread = (
				Thread.new()
			)
			var worker_error: int = (
				new_decode_worker.start(
					Callable(
						self,
						"_hydrate_checkpoint_runtime_on_worker"
					).bind(
						decode_candidate.duplicate(false),
						signature
					),
					Thread.PRIORITY_LOW
				)
			)

			if worker_error != OK:
				record [
					"checkpoint_payload_apply_pending"
				] = false
				record [
					"checkpoint_payload_tail_failed"
				] = true
				record [
					"checkpoint_payload_tail_failure_reason"
				] = "checkpoint_decode_worker_start_failed"
				record [
					"checkpoint_payload_tail_worker_error"
				] = worker_error
				record [
					"ready_state_preserved"
				] = true

				resident_records [
					signature
				] = record

				return true

			checkpoint_hydration_threads [
				signature
			] = new_decode_worker

			record [
				"worker_thread_used"
			] = true
			record [
				"worker_thread_active"
			] = true
			record [
				"worker_thread_mutates_game_state"
			] = false
			record [
				"checkpoint_payload_decode_pending"
			] = true
			record [
				"checkpoint_payload_decode_started_after_lens_detach"
			] = false
			record [
				"checkpoint_payload_decode_started_outside_interactive_frame"
			] = true
			record [
				"checkpoint_payload_decode_started_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			resident_records [
				signature
			] = record

			return false

		var active_decode_worker: Thread = (
			worker_raw as Thread
		)

		if active_decode_worker.is_alive():
			record [
				"checkpoint_payload_decode_pending"
			] = true
			record [
				"checkpoint_payload_tail_poll_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			resident_records [
				signature
			] = record

			return false

		var decode_raw: Variant = (
			active_decode_worker.wait_to_finish()
		)

		checkpoint_hydration_threads.erase(
			signature
		)

		var decode_report: Dictionary = (
			decode_raw as Dictionary
			if typeof(decode_raw) == TYPE_DICTIONARY
			else {}
		)

		if not bool(
			decode_report.get(
				"success",
				false
			)
		):
			record [
				"checkpoint_payload_apply_pending"
			] = false
			record [
				"checkpoint_payload_tail_failed"
			] = true
			record [
				"checkpoint_payload_tail_failure"
			] = decode_report.duplicate(false)
			record [
				"ready_state_preserved"
			] = true

			resident_records [
				signature
			] = record

			return true



		var decoded_payload_raw: Variant = (
			decode_report.get(
				"payload",
				{}
			)
		)
		payload = (
			decoded_payload_raw as Dictionary
			if typeof(
				decoded_payload_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var decoded_spatial_plan_raw: Variant = (
			decode_report.get(
				"spatial_hydration_plan",
				{}
			)
		)
		spatial_hydration_plan = (
			decoded_spatial_plan_raw as Dictionary
			if typeof(
				decoded_spatial_plan_raw
			) == TYPE_DICTIONARY
			else {}
		)





		var compact_decode_report: Dictionary = (
			decode_report.duplicate(false)
		)
		compact_decode_report.erase(
			"payload"
		)
		compact_decode_report.erase(
			"spatial_hydration_plan"
		)
		compact_decode_report [
			"immutable_payload_reference_consumed"
		] = true
		compact_decode_report [
			"recursive_payload_copy_performed"
		] = false

		record [
			"checkpoint_decode_report"
		] = compact_decode_report
		record [
			"checkpoint_decoded_payload"
		] = payload
		record [
			"checkpoint_spatial_hydration_plan"
		] = spatial_hydration_plan
		record [
			"checkpoint_payload_decode_pending"
		] = false
		record [
			"worker_thread_active"
		] = false
		record [
			"worker_thread_complete"
		] = true
		record [
			"worker_thread_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"checkpoint_locality_plan_built_on_worker"
		] = true
		record [
			"checkpoint_payload_recursive_copy_performed"
		] = false

		resident_records [
			signature
		] = record

	if payload.is_empty():
		record [
			"checkpoint_payload_apply_pending"
		] = false
		record [
			"checkpoint_payload_tail_failed"
		] = true
		record [
			"checkpoint_payload_tail_failure_reason"
		] = "decoded_checkpoint_payload_empty"
		record [
			"ready_state_preserved"
		] = true

		resident_records [
			signature
		] = record

		return true

	if (
		resident_gs.game_state_hydration_runtime
		== null
	):
		resident_gs.game_state_hydration_runtime = (
			GameStateHydrationRuntime.new(
				resident_gs
			)
		)

	if not bool(
		record.get(
			"checkpoint_progressive_hydration_started",
			false
		)
	):
		if not (
			resident_gs
			.game_state_hydration_runtime
			.has_method(
				"begin_resident_checkpoint_spatial_hydration"
			)
		):
			record [
				"checkpoint_payload_apply_pending"
			] = false
			record [
				"checkpoint_payload_tail_failed"
			] = true
			record [
				"checkpoint_payload_tail_failure_reason"
			] = (
				"progressive_checkpoint_hydration_authority_missing"
			)

			resident_records [
				signature
			] = record

			return true

		var hydration_candidate: Dictionary = _dict(
			record.get(
				"checkpoint_candidate",
				{}
			)
		)

		var begin_report: Dictionary = (
			resident_gs
			.game_state_hydration_runtime
			.begin_resident_checkpoint_spatial_hydration(
				payload,
				spatial_hydration_plan,
				{
					"source": (
						"reality_residency_manager."
						+ "checkpoint_payload_live_spatial_tail"
					),
					"profile": (
						"resident_checkpoint_spatial_bloom"
					),
					"path": str(
						hydration_candidate.get(
							"checkpoint_path",
							hydration_candidate.get(
								"path",
								""
							)
						)
					),
					"background_enabled": true,
					"defer_consciousness_repair": true,
					"strict_one_item_per_slice": true,
					"strict_interactive_chunk_caps": true,
					"npc_chunk_cap": 1,
					"partner_chunk_cap": 1,
					"consciousness_chunk_cap": 1,
					"resident_restore": true,
					"resident_engine_graph_ready": true,
					"runtime_scene_tree_access_allowed": false,
					"worker_thread_used": false,
					"ui_is_renderer_only": true
				}
			)
		)

		if not bool(
			begin_report.get(
				"success",
				false
			)
		):
			record [
				"checkpoint_payload_apply_pending"
			] = false
			record [
				"checkpoint_payload_tail_failed"
			] = true
			record [
				"checkpoint_payload_tail_failure"
			] = begin_report.duplicate(false)
			record [
				"ready_state_preserved"
			] = true

			resident_records [
				signature
			] = record

			return true

		record [
			"checkpoint_progressive_hydration_started"
		] = true
		record [
			"checkpoint_progressive_hydration_started_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"checkpoint_payload_waiting_for_visible_life_lens"
		] = false
		record [
			"checkpoint_payload_main_thread_hydration_started"
		] = false
		record [
			"checkpoint_progressive_hydration_begin_report"
		] = begin_report.duplicate(false)
		record [
			"checkpoint_progressive_hydration_payload_by_reference"
		] = true
		record [
			"checkpoint_progressive_hydration_deep_copy_performed"
		] = false

		resident_records [
			signature
		] = record

		return false

	var slice_report: Dictionary = (
		resident_gs
		.game_state_hydration_runtime
		.run_background_hydration_slice(
			1
		)
	)

	record [
		"checkpoint_progressive_hydration_last_slice_report"
	] = slice_report.duplicate(false)
	record [
		"checkpoint_progressive_hydration_last_slice_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	if typeof(
		resident_gs.scenario_state
	) == TYPE_DICTIONARY:
		record [
			"checkpoint_progressive_hydration_current_tier"
		] = str(
			resident_gs.scenario_state.get(
				"checkpoint_spatial_hydration_tier",
				"world"
			)
		)

	if bool(
		slice_report.get(
			"active",
			false
		)
	):
		resident_records [
			signature
		] = record

		return false

	if not bool(
		slice_report.get(
			"complete",
			false
		)
	):
		resident_records [
			signature
		] = record

		return false

	var hydration_report: Dictionary = _dict(
		resident_gs.game_state_hydration_report
	)
	var resume_contract: Dictionary = _dict(
		record.get(
			"checkpoint_resume_contract",
			{}
		)
	)
	var controlled_actor_id: int = int(
		resume_contract.get(
			"controlled_actor_id",
			resume_contract.get(
				"actor_id",
				-1
			)
		)
	)
	var controlled_actor: Person = null

	if controlled_actor_id > 0:
		controlled_actor = (
			resident_gs.get_npc_by_id(
				controlled_actor_id
			)
		)

	if controlled_actor != null:
		resident_gs.player = controlled_actor
		resident_gs.player_id = (
			controlled_actor_id
		)

	if typeof(
		resident_gs.scenario_state
	) != TYPE_DICTIONARY:
		resident_gs.scenario_state = {}

	var first_frame_raw: Variant = (
		resume_contract.get(
			"first_frame_ui_snapshot",
			{}
		)
	)

	if typeof(
		first_frame_raw
	) == TYPE_DICTIONARY:
		var first_frame_snapshot: Dictionary = (
			first_frame_raw as Dictionary
		)

		resident_gs.scenario_state [
			"prebuilt_first_frame_ui_snapshot"
		] = first_frame_snapshot
		resident_gs.scenario_state [
			"zero_frame_consciousness_switch_surface"
		] = first_frame_snapshot

	resident_gs.scenario_state [
		"checkpoint_payload_hydration_tail_pending"
	] = false
	resident_gs.scenario_state [
		"checkpoint_payload_hydration_tail_complete"
	] = true
	resident_gs.scenario_state [
		"checkpoint_resume_actor_contract_tail_pending"
	] = false
	resident_gs.scenario_state [
		"checkpoint_hydration_worker_mutated_game_state"
	] = false
	resident_gs.scenario_state [
		"checkpoint_spatial_hydration_active"
	] = false
	resident_gs.scenario_state [
		"checkpoint_spatial_hydration_tier"
	] = "complete"



	record.erase(
		"checkpoint_decoded_payload"
	)
	record.erase(
		"checkpoint_spatial_hydration_plan"
	)

	record [
		"checkpoint_payload_apply_pending"
	] = false
	record [
		"checkpoint_payload_tail_complete"
	] = true
	record [
		"checkpoint_payload_tail_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	record [
		"rehydration_report"
	] = hydration_report.duplicate(false)
	record [
		"rehydration_completed"
	] = true
	record [
		"rehydrated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	record [
		"renderer_thread_hydration_performed"
	] = false
	record [
		"worker_thread_mutated_game_state"
	] = false
	record [
		"checkpoint_progressive_hydration_complete"
	] = true
	record [
		"checkpoint_payload_recursive_copy_performed"
	] = false







	var life_observation_report: Dictionary = {}

	if (
		projection_engine != null
		and projection_engine.has_method(
			"queue_checkpoint_resume_life_observation"
		)
	):
		life_observation_report = (
			projection_engine
			.queue_checkpoint_resume_life_observation(
				resident_gs,
				signature,
				resume_contract,
				{
					"source": (
						"reality_residency_manager."
						+ "checkpoint_payload_hydrated"
					),
					"authority_phase": "hydrated_runtime",
					"background_only": true,
					"blocks_ui": false,
					"requires_ui_idle": false,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	record [
		"checkpoint_resume_life_observation_refresh_report"
	] = life_observation_report.duplicate(false)
	record [
		"checkpoint_resume_life_observation_refresh_queued"
	] = bool(
		life_observation_report.get(
			"queued",
			false
		)
	)
	record [
		"checkpoint_resume_life_observation_refresh_waits_for_ui_idle"
	] = false
	record [
		"checkpoint_resume_life_observation_refresh_requires_observation"
	] = false

	resident_records [
		signature
	] = record

	EraLog.truth(
		"ERALIFE_CHECKPOINT_HYDRATION_TRUTH"
		+ "|signature=" + signature
		+ "|actor_id=" + str(
			resident_gs.player_id
		)
		+ "|playable=true"
		+ "|background_active=false"
		+ "|worker_mutated_game_state=false"
		+ "|live_spatial_tail=true"
		+ "|one_item_per_slice=true"
		+ "|one_entity_per_quantum=true"
		+ "|locality_order=me>life>household>city>realm>world"
		+ "|decode_started_after_detach=false"
		+ "|recursive_payload_copy=false"
		+ "|life_observation_refresh_queued="
		+ str(
			bool(
				life_observation_report.get(
					"queued",
					false
				)
			)
		)
		+ "|at_ms="
		+ str(
			int(
				Time.get_ticks_msec()
			)
		)
	)

	return true
func _checkpoint_relationship_projection_locality_status(
	resident_gs: GameState,
	checkpoint_payload_pending: bool
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"local_relationship_truth_hot": false,
		"checkpoint_payload_pending": checkpoint_payload_pending,
		"checkpoint_spatial_hydration_active": false,
		"checkpoint_spatial_hydration_tier": "",
		"checkpoint_spatial_hydration_tier_cursor": 0,
		"checkpoint_spatial_hydration_tier_count": -1,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	if resident_gs == null:
		report ["success"] = false
		report ["reason"] = "resident_runtime_missing"
		return report

	if not checkpoint_payload_pending:
		report ["local_relationship_truth_hot"] = true
		report ["reason"] = "checkpoint_payload_already_complete"
		return report

	if typeof(
		resident_gs.scenario_state
	) != TYPE_DICTIONARY:
		report ["reason"] = (
			"checkpoint_spatial_hydration_state_not_published"
		)
		return report

	var spatial_active: bool = bool(
		resident_gs.scenario_state.get(
			"checkpoint_spatial_hydration_active",
			false
		)
	)
	var spatial_tier: String = str(
		resident_gs.scenario_state.get(
			"checkpoint_spatial_hydration_tier",
			""
		)
	).strip_edges().to_lower()
	var tier_cursor: int = int(
		resident_gs.scenario_state.get(
			"checkpoint_spatial_hydration_tier_cursor",
			0
		)
	)
	var tier_count: int = int(
		resident_gs.scenario_state.get(
			"checkpoint_spatial_hydration_tier_count",
			-1
		)
	)

	report [
		"checkpoint_spatial_hydration_active"
	] = spatial_active
	report [
		"checkpoint_spatial_hydration_tier"
	] = spatial_tier
	report [
		"checkpoint_spatial_hydration_tier_cursor"
	] = tier_cursor
	report [
		"checkpoint_spatial_hydration_tier_count"
	] = tier_count








	var household_tier_complete: bool = (
		spatial_tier == "household"
		and tier_count >= 0
		and tier_cursor >= tier_count
	)
	var hydration_has_advanced_beyond_household: bool = (
		spatial_tier in [
			"city",
			"my_city",
			"realm",
			"my_realm",
			"world",
			"the_world",
			"complete"
		]
	)

	var local_relationship_truth_hot: bool = (
		not spatial_active
		or household_tier_complete
		or hydration_has_advanced_beyond_household
	)

	report [
		"local_relationship_truth_hot"
	] = local_relationship_truth_hot

	if local_relationship_truth_hot:
		report ["reason"] = (
			"controlled_actor_household_locality_hot"
		)
	else:
		report ["reason"] = (
			"controlled_actor_household_locality_still_hydrating"
		)

	return report
func _service_checkpoint_interactive_projection_lane(
	signature: String,
	record: Dictionary,
	resident_gs: GameState,
	allow_step: bool,
	frame_budget_ms: int
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"serviced": false,
		"started": false,
		"stepped": false,
		"yielded_to_checkpoint_payload": false,
		"yielded_to_relationship_local_truth": false,
		"yielded_to_checkpoint_life_observation": false,
		"yielded_to_surface_authority": false,
		"projection_terminal": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
	if resident_gs == null:
		report ["success"] = false
		report ["reason"] = "resident_runtime_missing"
		return report

	var projection_terminal: bool = (
		bool(
			record.get(
				"projection_tail_complete",
				false
			)
		)
		or bool(
			record.get(
				"projection_tail_failed",
				false
			)
		)
		or bool(
			record.get(
				"projection_tail_skipped",
				false
			)
		)
	)

	report ["projection_terminal"] = projection_terminal

	if projection_terminal:
		return report

	if projection_engine == null:
		record ["projection_tail_pending"] = false
		record ["projection_tail_skipped"] = true
		record ["projection_tail_skip_reason"] = (
			"missing_projection_engine"
		)
		record ["ready_state_preserved"] = true

		resident_records [
			signature
		] = record

		report ["success"] = false
		report ["serviced"] = true
		report ["projection_terminal"] = true
		report ["reason"] = "missing_projection_engine"

		return report

	if not bool(
		record.get(
			"projection_started",
			false
		)
	):
		var begin_report: Dictionary = (
			projection_engine.begin_resident_projection(
				resident_gs,
				{
					"signature": signature,
					"source": (
						"reality_residency_manager."
						+ "visible_shell_interactive_surface_lane"
					),
					"interactive_surfaces_only": true,
					"ready_gate_member": false,
					"ready_door_waits_for_projection": false,
					"build_on_click_forbidden": true,
					"ui_is_renderer_only": true,
					# FIX: this lane runs BEFORE the checkpoint tail's own begin call
					# and returns early when it services the record, so it -- not the
					# tail -- is the path a mid-life rebind actually takes. Without
					# force_rebuild here, begin_resident_projection() hit its reuse
					# branch (same actor) and handed back the world-start projection,
					# so the surfaces never rebuilt no matter what the tail did.
					"force_rebuild": int(
						record.get(
							"projection_actor_rebind_requested_at_ms",
							0
						)
					) > 0
				}
			)
		)

		if not bool(
			begin_report.get(
				"success",
				false
			)
		):
			record ["projection_tail_pending"] = false
			EraLog.watch_end("projection:%s" % signature)
			record ["projection_tail_failed"] = true
			record ["projection_tail_failure"] = (
				begin_report.duplicate(false)
			)
			record ["ready_state_preserved"] = true

			resident_records [
				signature
			] = record

			report ["success"] = false
			report ["serviced"] = true
			report ["projection_terminal"] = true
			report ["reason"] = (
				"interactive_projection_begin_failed"
			)
			report ["begin_report"] = (
				begin_report.duplicate(false)
			)

			return report

		record ["projection_started"] = true
		record ["projection_tail_pending"] = true
		EraLog.watch_begin(
			"projection:%s" % signature,
			"resident_projection"
		)
		# FIX: consume the rebind marker here too. If it stayed set, every later pass
		# through this lane would force another rebuild and the projection could
		# never reach completion.
		record ["projection_actor_rebind_requested_at_ms"] = 0
		record ["projection_tail_step_count"] = 0
		record ["projection_tail_started_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record [
			"projection_surface_packets_complete"
		] = false
		record [
			"projection_publication_ready_gate_member"
		] = false
		record [
			"projection_interactive_surfaces_only"
		] = true
		record [
			"projection_started_from_visible_shell"
		] = true
		record [
			"projection_full_engine_graph_gate_removed"
		] = true
		record [
			"relationship_projection_complete_payload_gate_removed"
		] = true









		var initial_life_observation_report: Dictionary = {}
		var resume_contract_raw: Variant = record.get(
			"checkpoint_resume_contract",
			{}
		)
		var resume_contract: Dictionary = (
			(resume_contract_raw as Dictionary).duplicate(false)
			if typeof(resume_contract_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			not resume_contract.is_empty()
			and projection_engine.has_method(
				"queue_checkpoint_resume_life_observation"
			)
		):
			initial_life_observation_report = (
				projection_engine
				.queue_checkpoint_resume_life_observation(
					resident_gs,
					signature,
					resume_contract,
					{
						"source": (
							"reality_residency_manager."
							+ "visible_checkpoint_life_shell"
						),
						"authority_phase": "resident_checkpoint_shell",
						"background_only": true,
						"blocks_ui": false,
						"requires_ui_idle": false,
						"ready_gate_member": false,
						"ui_is_renderer_only": true
					}
				)
			)

		record [
			"checkpoint_resume_initial_life_observation_report"
		] = initial_life_observation_report.duplicate(false)
		record [
			"checkpoint_resume_initial_life_observation_queued"
		] = bool(
			initial_life_observation_report.get(
				"queued",
				false
			)
		)
		record [
			"checkpoint_resume_initial_life_observation_requires_ui_idle"
		] = false
		record [
			"checkpoint_resume_initial_life_observation_requires_observation"
		] = false

		resident_records [
			signature
		] = record

		if typeof(
			resident_gs.scenario_state
		) == TYPE_DICTIONARY:
			resident_gs.scenario_state [
				"resident_projection_publication_lane_active"
			] = true
			resident_gs.scenario_state [
				"resident_projection_publication_ready_gate_member"
			] = false
			resident_gs.scenario_state [
				"resident_projection_started_from_visible_shell"
			] = true
			resident_gs.scenario_state [
				"resident_projection_full_engine_graph_gate_removed"
			] = true
			resident_gs.scenario_state [
				"resident_relationship_projection_complete_payload_gate_removed"
			] = true
			resident_gs.scenario_state [
				"checkpoint_resume_life_observation_intrinsically_bound"
			] = bool(
				initial_life_observation_report.get(
					"queued",
					false
				)
			)

		report ["serviced"] = true
		report ["started"] = true
		report ["begin_report"] = (
			begin_report.duplicate(false)
		)
		report [
			"initial_life_observation_report"
		] = initial_life_observation_report.duplicate(false)

		return report




	var stage_promotion_report: Dictionary = (
		projection_engine.promote_next_hot_interactive_stage(
			signature
		)
	)

	var status_before: Dictionary = (
		projection_engine.projection_status(
			signature
		)
	)
	var stage_id: String = str(
		status_before.get(
			"stage_id",
			""
		)
	).strip_edges().to_lower()

	var authority_status: Dictionary = (
		projection_engine
		.interactive_projection_stage_authority_status(
			signature
		)
	)
	var stage_authority_hot: bool = bool(
		authority_status.get(
			"authority_hot",
			false
		)
	)

	report [
		"stage_promotion_report"
	] = stage_promotion_report.duplicate(false)
	report [
		"surface_authority_order_is_dynamic"
	] = true
	report [
		"surface_authority_promotion_waits_for_ui_idle"
	] = false




	var step_is_allowed: bool = (
		allow_step
		or stage_authority_hot
	)

	if not step_is_allowed:
		report [
			"yielded_to_surface_authority"
		] = true
		report [
			"stage_id"
		] = stage_id
		report [
			"stage_authority_status"
		] = authority_status.duplicate(false)

		return report

	var checkpoint_payload_pending: bool = bool(
		record.get(
			"checkpoint_payload_apply_pending",
			false
		)
	)







	var checkpoint_life_observation_pending: bool = (
		projection_engine.has_method(
			"checkpoint_resume_life_observation_pending"
		)
		and bool(
			projection_engine
				.checkpoint_resume_life_observation_pending(
					signature
				)
		)
	)

	if checkpoint_life_observation_pending:
		report [
			"yielded_to_checkpoint_life_observation"
		] = true
		report [
			"checkpoint_life_observation_has_background_qos"
		] = true
		report [
			"checkpoint_life_observation_requires_ui_idle"
		] = false
		report [
			"checkpoint_life_observation_requires_observation"
		] = false
		report [
			"stage_id"
		] = stage_id
		report [
			"stage_authority_status"
		] = authority_status.duplicate(false)

		return report







	if (
		checkpoint_payload_pending
		and stage_id == "relationships"
	):
		var relationship_locality_status: Dictionary = (
			_checkpoint_relationship_projection_locality_status(
				resident_gs,
				checkpoint_payload_pending
			)
		)

		report [
			"relationship_locality_status"
		] = relationship_locality_status.duplicate(false)
		report [
			"relationship_projection_waits_for_complete_checkpoint_payload"
		] = false

		if not bool(
			relationship_locality_status.get(
				"local_relationship_truth_hot",
				false
			)
		):
			report [
				"yielded_to_relationship_local_truth"
			] = true
			report [
				"yielded_to_checkpoint_payload"
			] = false
			report [
				"stage_id"
			] = stage_id
			report [
				"stage_authority_status"
			] = authority_status.duplicate(false)

			return report











		var relationship_payload_turn: String = str(
			record.get(
				"checkpoint_relationship_payload_lane_turn",
				"projection"
			)
		).strip_edges().to_lower()

		if relationship_payload_turn not in [
			"projection",
			"payload"
		]:
			relationship_payload_turn = "projection"

		if relationship_payload_turn == "payload":
			record [
				"checkpoint_relationship_payload_lane_turn"
			] = "projection"
			record [
				"checkpoint_relationship_payload_lane_last_payload_turn_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			record [
				"checkpoint_relationship_payload_lane_requires_ui_idle"
			] = false
			record [
				"checkpoint_relationship_payload_lane_requires_observation"
			] = false

			resident_records [
				signature
			] = record

			report [
				"yielded_to_checkpoint_payload"
			] = true
			report [
				"relationship_payload_fairness_turn"
			] = "payload"
			report [
				"relationship_projection_can_starve_payload"
			] = false
			report [
				"checkpoint_payload_can_starve_relationship_projection"
			] = false
			report [
				"stage_id"
			] = stage_id
			report [
				"stage_authority_status"
			] = authority_status.duplicate(false)

			return report

		record [
			"checkpoint_relationship_payload_lane_turn"
		] = "payload"
		record [
			"checkpoint_relationship_payload_lane_last_projection_turn_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"checkpoint_relationship_payload_lane_requires_ui_idle"
		] = false
		record [
			"checkpoint_relationship_payload_lane_requires_observation"
		] = false

		resident_records [
			signature
		] = record

		report [
			"relationship_payload_fairness_turn"
		] = "projection"
		report [
			"relationship_projection_can_starve_payload"
		] = false
		report [
			"checkpoint_payload_can_starve_relationship_projection"
		] = false
	else:
		if record.has(
			"checkpoint_relationship_payload_lane_turn"
		):
			record.erase(
				"checkpoint_relationship_payload_lane_turn"
			)

			resident_records [
				signature
			] = record

	var projection_status: Dictionary = (
		projection_engine.step_resident_projection(
			signature,
			1,
			maxi(
				1,
				frame_budget_ms
			)
		)
	)

	record = _record_for(
		signature
	)

	record [
		"projection_tail_report"
	] = projection_status.duplicate(false)
	record [
		"projection_tail_last_service_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	record [
		"projection_publication_waits_for_ui_idle"
	] = false
	record [
		"projection_publication_started_from_visible_shell"
	] = true
	record [
		"projection_publication_waits_for_full_engine_graph"
	] = false
	record [
		"projection_last_surface_authority_status"
	] = authority_status.duplicate(false)
	record [
		"relationship_projection_waits_for_complete_checkpoint_payload"
	] = false

	if bool(
		projection_status.get(
			"failed",
			false
		)
	):
		record ["projection_tail_pending"] = false
		record ["projection_tail_failed"] = true
		record [
			"projection_tail_failure"
		] = projection_status.duplicate(false)
		record ["ready_state_preserved"] = true

		resident_records [
			signature
		] = record

		report ["success"] = false
		report ["serviced"] = true
		report ["stepped"] = true
		report ["projection_terminal"] = true
		report ["projection_status"] = (
			projection_status.duplicate(false)
		)

		return report

	var interactive_surface_packets_complete: bool = (
		projection_engine.interactive_surface_packets_ready(
			signature
		)
	)

	if interactive_surface_packets_complete:
		record [
			"projection_surface_packets_complete"
		] = true
		record [
			"projection_surface_packets_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		if typeof(
			resident_gs.scenario_state
		) == TYPE_DICTIONARY:
			resident_gs.scenario_state [
				"resident_projection_surface_packets_complete"
			] = true
			resident_gs.scenario_state [
				"resident_projection_surface_packets_completed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

	if bool(
		projection_status.get(
			"complete",
			false
		)
	):
		var completed_projection_contract_raw: Variant = (
			projection_status.get(
				"projection_contract",
				{}
			)
		)
		var completed_projection_contract: Dictionary = (
			(
				completed_projection_contract_raw
				as Dictionary
			).duplicate(false)
			if typeof(
				completed_projection_contract_raw
			) == TYPE_DICTIONARY
			else {}
		)

		record [
			"projection_contract"
		] = completed_projection_contract.duplicate(false)
		record [
			"projection_tail_pending"
		] = false
		record [
			"projection_tail_complete"
		] = true
		record [
			"projection_tail_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"projection_surface_packets_complete"
		] = true

		report [
			"projection_terminal"
		] = true

	resident_records [
		signature
	] = record

	report ["serviced"] = true
	report ["stepped"] = true
	report ["stage_id"] = str(
		projection_status.get(
			"stage_id",
			stage_id
		)
	)
	report [
		"stage_authority_status"
	] = authority_status.duplicate(false)
	report ["projection_status"] = (
		projection_status.duplicate(false)
	)

	return report
func _service_ready_checkpoint_tail(
	signature: String,
	record: Dictionary,
	max_steps: int,
	frame_budget_ms: int
) -> void:
	# DIAGNOSTIC: request_attached_actor_projection_rebind() now succeeds and its
	# flags persist, but no re-projection follows. This reports whether the ready
	# checkpoint tail is reached at all, and with what state.
	EraLog.truth(
		"ERALIFE_RESIDENCY_TAIL_SERVICE|signature=%s|tail_pending=%s|projection_started=%s|projection_tail_pending=%s|runtime_is_gamestate=%s|max_steps=%d"
		% [
			signature,
			str(record.get("residency_tail_pending", false)),
			str(record.get("projection_started", false)),
			str(record.get("projection_tail_pending", false)),
			str(record.get("runtime_ref", null) is GameState),
			max_steps
		]
	)

	var runtime_raw: Variant = record.get(
		"runtime_ref",
		null
	)

	if not (
		runtime_raw is GameState
	):
		record ["residency_tail_pending"] = false
		record ["residency_tail_failed"] = true
		record ["residency_tail_failure_reason"] = (
			"resident_runtime_reference_missing"
		)
		record ["ready_state_preserved"] = true
		resident_records [signature] = record
		_remove_service_key(
			"resident:%s" % signature
		)
		return

	var resident_gs: GameState = (
		runtime_raw as GameState
	)

	if typeof(
		resident_gs.scenario_state
	) != TYPE_DICTIONARY:
		resident_gs.scenario_state = {}





	if bool(
		record.get(
			"lens_attached",
			false
		)
	):
		_service_checkpoint_interactive_projection_lane(
			signature,
			record,
			resident_gs,
			false,
			frame_budget_ms
		)

		record = _record_for(
			signature
		)

	if not bool(
		record.get(
			"resident_chassis_tail_complete",
			false
		)
	):
		var worker_raw: Variant = (
			checkpoint_engine_graph_threads.get(
				signature,
				null
			)
		)

		if not (worker_raw is Thread):
			record [
				"checkpoint_engine_graph_worker_active"
			] = false
			record [
				"checkpoint_engine_graph_tail_degraded"
			] = true
			record [
				"checkpoint_engine_graph_tail_failure_reason"
			] = (
				"checkpoint_engine_graph_worker_missing"
			)
			record [
				"ready_state_preserved"
			] = true
			record [
				"renderer_thread_engine_constructor_fallback_attempted"
			] = false
			record [
				"renderer_thread_engine_constructor_fallback_forbidden"
			] = true
			record [
				"residency_tail_pending"
			] = false

			resident_gs.scenario_state [
				"checkpoint_engine_graph_tail_degraded"
			] = true
			resident_gs.scenario_state [
				"checkpoint_engine_graph_tail_failure_reason"
			] = (
				"checkpoint_engine_graph_worker_missing"
			)
			resident_gs.scenario_state [
				"checkpoint_first_frame_truth_remains_authoritative"
			] = true

			resident_records [
				signature
			] = record

			_remove_service_key(
				"resident:%s" % signature
			)
			return

		var engine_graph_worker: Thread = (
			worker_raw as Thread
		)

		if engine_graph_worker.is_alive():
			record [
				"checkpoint_engine_graph_worker_active"
			] = true
			record [
				"checkpoint_engine_graph_worker_last_poll_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			record [
				"checkpoint_engine_graph_worker_poll_only"
			] = true
			record [
				"renderer_thread_engine_constructor_work"
			] = false
			record [
				"ready_state_preserved"
			] = true

			resident_records [
				signature
			] = record
			return

		var worker_result_raw: Variant = (
			engine_graph_worker.wait_to_finish()
		)

		checkpoint_engine_graph_threads.erase(
			signature
		)

		var worker_result: Dictionary = (
			worker_result_raw as Dictionary
			if typeof(
				worker_result_raw
			) == TYPE_DICTIONARY
			else {}
		)

		record [
			"checkpoint_engine_graph_worker_active"
		] = false
		record [
			"checkpoint_engine_graph_worker_complete"
		] = true
		record [
			"checkpoint_engine_graph_worker_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"checkpoint_engine_graph_worker_report"
		] = worker_result.duplicate(false)

		if not bool(
			worker_result.get(
				"success",
				false
			)
		):
			record [
				"checkpoint_engine_graph_tail_degraded"
			] = true
			record [
				"checkpoint_engine_graph_tail_failure_reason"
			] = str(
				worker_result.get(
					"reason",
					"checkpoint_engine_graph_worker_failed"
				)
			)
			record [
				"ready_state_preserved"
			] = true
			record [
				"residency_tail_pending"
			] = false

			resident_gs.scenario_state [
				"checkpoint_engine_graph_tail_degraded"
			] = true
			resident_gs.scenario_state [
				"checkpoint_first_frame_truth_remains_authoritative"
			] = true

			resident_records [
				signature
			] = record

			_remove_service_key(
				"resident:%s" % signature
			)
			return

		record [
			"resident_chassis_tail_complete"
		] = true
		record [
			"resident_chassis_tail_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		record [
			"checkpoint_engine_graph_hot"
		] = true
		record [
			"checkpoint_engine_graph_ready_gate_member"
		] = false
		record [
			"ready_state_preserved"
		] = true

		resident_gs.scenario_state [
			"resident_runtime_engine_graph_ready"
		] = true
		resident_gs.scenario_state [
			"resident_runtime_engine_graph_background_tail"
		] = false
		resident_gs.scenario_state [
			"checkpoint_hydration_chassis_active"
		] = false
		resident_gs.scenario_state [
			"checkpoint_hydration_chassis_complete"
		] = true
		resident_gs.scenario_state [
			"checkpoint_engine_graph_ready_gate_member"
		] = false

		resident_records [
			signature
		] = record

		EraLog.truth(
			"ERALIFE_CHECKPOINT_ENGINE_GRAPH_WORKER_TRUTH"
			+ "|signature=" + signature
			+ "|complete=true"
			+ "|ready_gate_member=false"
			+ "|renderer_thread_constructors=false"
			+ "|life_shell_remained_observable=true"
			+ "|at_ms="
			+ str(
				Time.get_ticks_msec()
			)
		)



		return
	var early_projection_lane: Dictionary = (
		_service_checkpoint_interactive_projection_lane(
			signature,
			record,
			resident_gs,
			true,
			frame_budget_ms
		)
	)



	if bool(
		early_projection_lane.get(
			"serviced",
			false
		)
	):
		return

	record = _record_for(
		signature
	)




	if bool(
		record.get(
			"checkpoint_payload_apply_pending",
			false
		)
	):
		if not _service_ready_checkpoint_payload_tail(
			signature,
			record,
			resident_gs
		):
			return

		record = _record_for(
			signature
		)

	var projection_terminal: bool = (
		bool(
			record.get(
				"projection_tail_complete",
				false
			)
		)
		or bool(
			record.get(
				"projection_tail_failed",
				false
			)
		)
		or bool(
			record.get(
				"projection_tail_skipped",
				false
			)
		)
	)
	var surface_packets_complete: bool = (
		bool(
			record.get(
				"projection_surface_packets_complete",
				false
			)
		)
		or projection_terminal
	)
	var lens_attached: bool = bool(
		record.get(
			"lens_attached",
			false
		)
	)




	if not projection_terminal:
		if projection_engine == null:
			record ["projection_tail_pending"] = false
			record ["projection_tail_skipped"] = true
			record ["projection_tail_skip_reason"] = (
				"missing_projection_engine"
			)
			record [
				"projection_surface_packets_complete"
			] = true
			record ["ready_state_preserved"] = true

			resident_gs.scenario_state [
				"resident_runtime_deep_projection_tail_pending"
			] = false
			resident_gs.scenario_state [
				"resident_projection_surface_packets_complete"
			] = false
			resident_gs.scenario_state [
				"resident_projection_surface_packets_skipped"
			] = true

			resident_records [signature] = record
			return

		if not bool(
			record.get(
				"projection_started",
				false
			)
		):
			var begin_report: Dictionary = (
				projection_engine.begin_resident_projection(
					resident_gs,
					{
						"signature": signature,
						"source": (
							"reality_residency_manager."
							+ "attached_surface_publication_lane"
						),
						"ready_gate_member": false,
						"ready_door_waits_for_projection": false,
						"interactive_surfaces_only": true,
						"build_on_click_forbidden": true,
						"ui_is_renderer_only": true,
						# FIX: only true when request_attached_actor_projection_rebind()
						# armed this pass. Without it begin_resident_projection() reuses
						# the world-start projection (same actor => reuse branch) and the
						# surfaces never rebuild. Boot and character switch do not set
						# this marker, so their behaviour is unchanged.
						"force_rebuild": int(
							record.get(
								"projection_actor_rebind_requested_at_ms",
								0
							)
						) > 0
					}
				)
			)

			if not bool(
				begin_report.get(
					"success",
					false
				)
			):
				# DIAGNOSTIC: a failed begin marks the tail degraded and returns with
				# nothing rescheduled, which looks identical to the projection simply
				# stopping. Say why.
				EraLog.truth(
					"ERALIFE_RESIDENCY_TAIL_BEGIN_FAILED|signature=%s|reason=%s|mode=%s"
					% [
						signature,
						str(begin_report.get("reason", begin_report.get("reason_id", "-"))),
						str(begin_report.get("mode", "-"))
					]
				)

				record ["projection_tail_pending"] = false
				EraLog.watch_end("projection:%s" % signature)
				record ["projection_tail_failed"] = true
				record ["projection_tail_failure"] = (
					begin_report.duplicate(true)
				)
				record [
					"projection_surface_packets_complete"
				] = true
				record ["ready_state_preserved"] = true

				resident_gs.scenario_state [
					"resident_runtime_projection_tail_degraded"
				] = true
				resident_gs.scenario_state [
					"resident_runtime_projection_tail_failure"
				] = begin_report.duplicate(true)

				resident_records [signature] = record
				return

			record ["projection_started"] = true
			record ["projection_tail_pending"] = true
			EraLog.watch_begin(
				"projection:%s" % signature,
				"resident_projection"
			)
			# FIX: consume the rebind marker now that the forced rebuild has actually
			# started. Leaving it set would make every later service force another
			# rebuild, so the projection could never reach completion.
			record ["projection_actor_rebind_requested_at_ms"] = 0
			record ["projection_tail_step_count"] = 0
			record ["projection_tail_started_at_ms"] = int(
				Time.get_ticks_msec()
			)
			record [
				"projection_surface_packets_complete"
			] = false
			record [
				"projection_publication_ready_gate_member"
			] = false

			resident_gs.scenario_state [
				"resident_projection_publication_lane_active"
			] = true
			resident_gs.scenario_state [
				"resident_projection_publication_ready_gate_member"
			] = false
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = true

			# FIX: the begin path had the same gap as the incomplete-step path -- it
			# started the projection, wrote the record, and returned without
			# rescheduling. So the projection began and was never stepped, which is
			# exactly what the logs showed: a single TAIL_SERVICE line with
			# projection_started=false and nothing after it.
			resident_records [signature] = record

			_append_service_key(
				"resident:%s" % signature
			)
			return

		if (
			lens_attached
			and surface_packets_complete
		):
			record [
				"projection_publication_lane_active"
			] = false
			record [
				"post_ready_truth_tail_paused_for_interactive_lens"
			] = true
			record [
				"snapshot_tail_paused_for_interactive_lens"
			] = true

			resident_records [signature] = record
			return

		var projection_status: Dictionary = (
			projection_engine.step_resident_projection(
				signature,
				1,
				maxi(
					1,
					frame_budget_ms
				)
			)
		)

		EraLog.watch_progress(
			"projection:%s" % signature
		)
		record ["projection_tail_report"] = (
			projection_status.duplicate(true)
		)
		record ["projection_tail_last_service_at_ms"] = int(
			Time.get_ticks_msec()
		)

		if bool(
			projection_status.get(
				"failed",
				false
			)
		):
			record ["projection_tail_pending"] = false
			record ["projection_tail_failed"] = true
			record ["projection_tail_failure"] = (
				projection_status.duplicate(true)
			)
			record [
				"projection_surface_packets_complete"
			] = true
			record ["ready_state_preserved"] = true

			resident_gs.scenario_state [
				"resident_runtime_deep_projection_tail_pending"
			] = false
			resident_gs.scenario_state [
				"resident_runtime_projection_tail_degraded"
			] = true

			resident_records [signature] = record
			return

		surface_packets_complete = (
			bool(
				projection_status.get(
					"complete",
					false
				)
			)
			or projection_engine
			.interactive_surface_packets_ready(
				signature
			)
		)

		if surface_packets_complete:
			record [
				"projection_surface_packets_complete"
			] = true
			record [
				"projection_surface_packets_completed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			resident_gs.scenario_state [
				"resident_projection_surface_packets_complete"
			] = true
			resident_gs.scenario_state [
				"resident_projection_surface_packets_completed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = lens_attached
			resident_gs.scenario_state [
				"resident_interactive_input_has_absolute_priority"
			] = lens_attached

		if not bool(
			projection_status.get(
				"complete",
				false
			)
		):
			# FIX: an incomplete projection used to write the record and return
			# without re-registering anything. Whether a second step ever happened
			# depended on some other caller keeping the service pump alive, which
			# made mid-life refreshes a race -- the same purchase would refresh the
			# surfaces on one run and silently stall halfway on the next.
			# step_resident_projection() advances one step per pass by design (to
			# stay inside the frame budget), so the record must stay scheduled until
			# it reports complete. _append_service_key() re-arms the pump.
			record ["projection_tail_pending"] = true

			# Safety cap: if a projection can never complete, rescheduling it every
			# frame would spin the service pump indefinitely. Give up after a
			# generous number of steps and mark it degraded rather than hanging.
			var projection_step_count: int = int(
				record.get(
					"projection_tail_step_count",
					0
				)
			) + 1
			record ["projection_tail_step_count"] = projection_step_count

			if projection_step_count > MAX_PROJECTION_TAIL_STEPS:
				record ["projection_tail_pending"] = false
				record ["projection_tail_failed"] = true
				record ["projection_tail_failure_reason"] = (
					"projection_tail_step_budget_exhausted"
				)
				record ["projection_surface_packets_complete"] = true
				record ["ready_state_preserved"] = true
				resident_records [signature] = record

				EraLog.truth(
					"ERALIFE_RESIDENCY_TAIL_GAVE_UP|signature=%s|steps=%d"
					% [
						signature,
						projection_step_count
					]
				)
				return

			resident_records [signature] = record

			_append_service_key(
				"resident:%s" % signature
			)
			return

		var completed_projection_contract: Dictionary = _dict(
			projection_status.get(
				"projection_contract",
				{}
			)
		)

		record ["projection_contract"] = (
			completed_projection_contract.duplicate(true)
		)
		record ["projection_tail_pending"] = false
		EraLog.watch_end(
			"projection:%s" % signature
		)
		record ["projection_tail_complete"] = true
		record ["projection_tail_completed_at_ms"] = int(
			Time.get_ticks_msec()
		)
		record [
			"projection_surface_packets_complete"
		] = true

		resident_gs.scenario_state [
			"resident_runtime_deep_projection_tail_pending"
		] = false
		resident_gs.scenario_state [
			"resident_projection_surface_packets_complete"
		] = true

		resident_records [signature] = record
		return




	if lens_attached:
		record [
			"residency_tail_paused_for_interactive_lens"
		] = true
		record [
			"residency_tail_pause_reason"
		] = "interactive_lens_has_absolute_priority"
		record [
			"post_ready_truth_tail_paused_for_interactive_lens"
		] = true
		record [
			"snapshot_tail_paused_for_interactive_lens"
		] = true
		record [
			"interactive_input_has_absolute_priority"
		] = true

		resident_gs.scenario_state [
			"resident_post_ready_truth_tail_paused"
		] = true
		resident_gs.scenario_state [
			"resident_post_ready_truth_tail_pause_reason"
		] = "interactive_lens_has_absolute_priority"
		resident_gs.scenario_state [
			"resident_snapshot_tail_paused"
		] = true
		resident_gs.scenario_state [
			"resident_interactive_input_has_absolute_priority"
		] = true

		resident_records [signature] = record
		return



	if int(
		record.get(
			"attach_count",
			0
		)
	) <= 0:
		record [
			"residency_tail_waiting_for_first_lens"
		] = true
		resident_records [signature] = record
		return



	if bool(
		record.get(
			"post_ready_truth_tail_pending",
			false
		)
	):
		var post_ready_report: Dictionary = (
			resident_gs.step_resident_post_ready_truth_tail(
				maxi(
					1,
					max_steps
				),
				maxi(
					1,
					frame_budget_ms
				)
			)
		)

		record ["post_ready_truth_tail_report"] = (
			post_ready_report.duplicate(true)
		)
		record [
			"post_ready_truth_tail_last_service_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		if not bool(
			post_ready_report.get(
				"success",
				true
			)
		):
			record ["post_ready_truth_tail_pending"] = false
			record ["post_ready_truth_tail_complete"] = false
			record ["post_ready_truth_tail_degraded"] = true
			record ["post_ready_truth_tail_failure"] = (
				post_ready_report.duplicate(true)
			)
			record [
				"post_ready_truth_tail_failed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			record ["ready_state_preserved"] = true

			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_pending"
			] = false
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_complete"
			] = false
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_degraded"
			] = true
			resident_gs.scenario_state [
				"resident_post_ready_truth_tail_failure"
			] = post_ready_report.duplicate(true)
			resident_gs.scenario_state [
				"resident_ready_state_preserved_after_tail_failure"
			] = true

			resident_records [signature] = record
			return

		if not bool(
			post_ready_report.get(
				"complete",
				false
			)
		):
			resident_records [signature] = record
			return

		record ["post_ready_truth_tail_pending"] = false
		record ["post_ready_truth_tail_complete"] = true
		record ["post_ready_truth_tail_degraded"] = false
		record [
			"post_ready_truth_tail_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		resident_gs.scenario_state [
			"resident_post_ready_truth_tail_pending"
		] = false
		resident_gs.scenario_state [
			"resident_post_ready_truth_tail_complete"
		] = true
		resident_gs.scenario_state [
			"resident_post_ready_truth_tail_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		resident_records [signature] = record
		return

	var resident_projection_contract: Dictionary = _dict(
		record.get(
			"projection_contract",
			{}
		)
	)

	if (
		snapshot_engine != null
		and not resident_projection_contract.is_empty()
		and not bool(
			record.get(
				"snapshot_tail_complete",
				false
			)
		)
	):
		var snapshot_report: Dictionary = (
			snapshot_engine.capture_resident_snapshot(
				signature,
				resident_gs,
				resident_projection_contract,
				{
					"source": (
						"reality_residency_manager."
						+ "detached_snapshot_tail"
					),
					"ready_gate_member": false
				}
			)
		)

		record ["snapshot_tail_report"] = (
			snapshot_report.duplicate(true)
		)
		record ["snapshot_tail_complete"] = bool(
			snapshot_report.get(
				"success",
				false
			)
		)

		if bool(
			snapshot_report.get(
				"success",
				false
			)
		):
			record ["snapshot"] = _dict(
				snapshot_report.get(
					"snapshot",
					{}
				)
			)
		else:
			record ["snapshot_tail_degraded"] = true

		resident_records [signature] = record
		return

	record ["residency_tail_pending"] = false
	record ["residency_tail_complete"] = true
	record ["residency_tail_completed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	record ["ready_state_preserved"] = true

	resident_gs.scenario_state [
		"resident_runtime_background_tail_complete"
	] = true
	resident_gs.scenario_state [
		"resident_runtime_background_tail_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	resident_records [signature] = record

	_remove_service_key(
		"resident:%s" % signature
	)
func _checkpoint_candidate_for_record(
	signature: String,
	record: Dictionary
) -> Dictionary:
	var candidates: Array = []
	var direct_candidate: Dictionary = _dict(
		record.get(
			"checkpoint_candidate",
			{}
		)
	)

	if not direct_candidate.is_empty():
		candidates.append(
			direct_candidate
		)

	var record_snapshot: Dictionary = _dict(
		record.get(
			"snapshot",
			{}
		)
	)
	var snapshot_candidate: Dictionary = _dict(
		record_snapshot.get(
			"checkpoint_candidate",
			{}
		)
	)

	if not snapshot_candidate.is_empty():
		candidates.append(
			snapshot_candidate
		)

	if snapshot_engine != null:
		var engine_snapshot: Dictionary = (
			snapshot_engine.snapshot_for_signature(
				signature
			)
		)
		var engine_candidate: Dictionary = _dict(
			engine_snapshot.get(
				"checkpoint_candidate",
				{}
			)
		)

		if not engine_candidate.is_empty():
			candidates.append(
				engine_candidate
			)

	for raw_candidate in candidates:
		var candidate: Dictionary = _dict(
			raw_candidate
		)
		var path: String = str(
			candidate.get(
				"checkpoint_path",
				candidate.get(
					"path",
					""
				)
			)
		).strip_edges()
		var candidate_signature: String = str(
			candidate.get(
				"residency_signature",
				""
			)
		).strip_edges()

		if (
			path != ""
			and FileAccess.file_exists(path)
			and (
				candidate_signature == ""
				or candidate_signature == signature
			)
		):
			candidate ["success"] = true
			candidate ["checkpoint_path"] = path
			candidate ["path"] = path
			candidate ["residency_signature"] = signature
			return candidate

	if gs != null:
		if gs.reality_checkpoint_contract_engine == null:
			gs.reality_checkpoint_contract_engine = (
				RealityCheckpointContractEngine.new(
					gs
				)
			)

		var fetched: Dictionary = (
			gs.reality_checkpoint_contract_engine.fetch_local_checkpoint(
				{},
				{},
				{
					"residency_signature": signature,
					"source": "reality_residency_manager.restart_resolution"
				}
			)
		)
		var fetched_signature: String = str(
			fetched.get(
				"residency_signature",
				""
			)
		).strip_edges()

		if (
			bool(
				fetched.get(
					"success",
					false
				)
			)
			and (
				fetched_signature == signature
				or (
					fetched_signature == ""
					and resident_records.size() == 1
				)
			)
		):
			fetched ["residency_signature"] = signature
			return fetched

	return {
		"success": false,
		"schema": "eralife.reality.checkpoint_candidate",
		"version": ENGINE_VERSION,
		"reason": "matching_checkpoint_not_found",
		"residency_signature": signature
	}

func _resident_record_requires_foreground_service(
		record: Dictionary
) -> bool:
	var state: String = str(
		record.get(
			"state",
			""
		)
	)

	return state in [
		"reserved",
		"waiting_for_hot_chassis",
		"building_contract_graph",
		"binding_reality",
		"checkpoint_resolution_pending",
		"rehydration_pending",
		"projecting_contracts"
	]

func _priority_resident_signature_for_service() -> String:
	var clean_attached_signature: String = str(
		attached_signature
	).strip_edges()

	# FIX: the attached branch below returns as soon as the attached record wants
	# foreground service -- and a "ready" record with residency_tail_pending qualifies.
	# With the projection tail now rescheduling itself the attached record is
	# permanently hungry, so a checkpoint registered by a load NEVER got a turn: the
	# logs show only godmode_... serviced, thousands of times, while the checkpoint
	# stayed at service_attempts=0. A checkpoint waiting to resolve is blocking a
	# player action, so it is checked FIRST.
	for raw_pending_signature in resident_records.keys():
		var pending_signature: String = str(raw_pending_signature).strip_edges()

		if pending_signature == "":
			continue

		var pending_record: Dictionary = _record_for(pending_signature)

		if pending_record.is_empty():
			continue

		if str(pending_record.get("state", "")) in [
			"checkpoint_resolution_pending",
			"rehydration_pending"
		]:
			EraLog.truth(
				"ERALIFE_PRIORITY|chose_pending=%s|over_attached=%s"
				% [pending_signature, clean_attached_signature]
			)
			return pending_signature

	if clean_attached_signature != "":
		var attached_record: Dictionary = _record_for(
			clean_attached_signature
		)
		var attached_projection_packets_terminal: bool = (
			bool(
				attached_record.get(
					"projection_surface_packets_complete",
					false
				)
			)
			or bool(
				attached_record.get(
					"projection_tail_failed",
					false
				)
			)
			or bool(
				attached_record.get(
					"projection_tail_skipped",
					false
				)
			)
		)

		if (
			not attached_record.is_empty()
			and (
				_resident_record_requires_foreground_service(
					attached_record
				)
				or (
					str(
						attached_record.get(
							"state",
							""
						)
					) == "ready"
					and bool(
						attached_record.get(
							"residency_tail_pending",
							false
						)
					)
					and not attached_projection_packets_terminal
				)
			)
		):
			return clean_attached_signature

	var ordered_signatures: Array = resident_records.keys()
	ordered_signatures.sort()

	var detached_tail_signature: String = ""

	for raw_signature in ordered_signatures:
		var signature: String = str(
			raw_signature
		).strip_edges()

		if signature == "":
			continue

		var record: Dictionary = _record_for(
			signature
		)

		if record.is_empty():
			continue

		if bool(
			record.get(
				"lens_attached",
				false
			)
		):
			continue

		if _resident_record_requires_foreground_service(
			record
		):
			return signature

		if (
			detached_tail_signature == ""
			and str(
				record.get(
					"state",
					""
				)
			) == "ready"
			and bool(
				record.get(
					"residency_tail_pending",
					false
				)
			)
			and int(
				record.get(
					"attach_count",
					0
				)
			) > 0
		):
			detached_tail_signature = signature

	return detached_tail_signature

func _ready_resident_waiting_for_first_lens_signature() -> String:
	var ordered_signatures: Array = resident_records.keys()
	ordered_signatures.sort()

	for raw_signature in ordered_signatures:
		var signature: String = str(
			raw_signature
		).strip_edges()

		if signature == "":
			continue

		var service_key: String = (
			"resident:%s" % signature
		)

		if not active_service_keys.has(
			service_key
		):
			continue

		var record: Dictionary = _record_for(
			signature
		)

		if record.is_empty():
			continue

		if (
			str(
				record.get(
					"state",
					""
				)
			) == "ready"
			and not bool(
				record.get(
					"lens_attached",
					false
				)
			)
			and int(
				record.get(
					"attach_count",
					0
				)
			) <= 0
		):
			return signature

	return ""

func _has_pending_non_attached_record() -> bool:
	# True when some record other than the attached one still needs servicing --
	# a checkpoint being resolved during a load, for example.
	for raw_signature in resident_records.keys():
		if str(raw_signature) == attached_signature:
			continue

		var other_record: Dictionary = _record_for(str(raw_signature))
		if other_record.is_empty():
			continue

		var other_state: String = str(other_record.get("state", ""))
		if other_state != "ready" and other_state != "":
			return true

	return false


func _prune_orphaned_service_keys() -> void:
	# A "resident:<signature>" key whose record has been erased keeps the pump alive
	# forever: it arms every frame, finds nothing to service, and re-arms. The logs
	# showed 369 consecutive "result=armed|keys=1|records=0" lines -- one orphaned key
	# and no records at all. Drop keys that no longer refer to a record.
	if active_service_keys.is_empty():
		return

	# Keys are pruned only after a grace period. Two earlier attempts both failed:
	# pruning immediately wiped VALID keys during the transient moment when
	# resident_records is empty (the checkpoint's own key vanished right after
	# registration), and skipping entirely while records was empty let an orphaned
	# chassis key spam the pump hundreds of times at boot. A grace period handles
	# both: a key that is still orphaned seconds later is genuinely dead.
	var now_ms: int = int(Time.get_ticks_msec())
	var surviving_keys: Array = []
	var orphan_samples: Array = []

	for raw_key in active_service_keys:
		var clean_key: String = str(raw_key).strip_edges()
		var signature: String = ""

		for prefix in ["resident:", "chassis:", "projection:"]:
			if clean_key.begins_with(prefix):
				signature = clean_key.substr(prefix.length())
				break

		if signature == "" or resident_records.has(signature):
			surviving_keys.append(clean_key)
			service_key_first_seen_ms.erase(clean_key)
			continue

		# Orphaned right now -- but give it time to have its record registered.
		if not service_key_first_seen_ms.has(clean_key):
			service_key_first_seen_ms [clean_key] = now_ms
			surviving_keys.append(clean_key)
			continue

		if now_ms - int(service_key_first_seen_ms.get(clean_key, now_ms)) < SERVICE_KEY_ORPHAN_GRACE_MS:
			surviving_keys.append(clean_key)
			continue

		service_key_first_seen_ms.erase(clean_key)

		if orphan_samples.size() < 3:
			orphan_samples.append(clean_key)

	if surviving_keys.size() != active_service_keys.size():
		EraLog.truth(
			"ERALIFE_PUMP_PRUNE|removed=%d|remaining=%d|records=%d|samples=%s"
			% [
				active_service_keys.size() - surviving_keys.size(),
				surviving_keys.size(),
				resident_records.size(),
				str(orphan_samples)
			]
		)

	active_service_keys = surviving_keys


func _ensure_service_pump() -> void:
	_prune_orphaned_service_keys()

	if active_service_keys.is_empty():
		EraLog.truth(
			"ERALIFE_PUMP_ARM|result=declined|reason=no_active_service_keys|records=%d"
			% resident_records.size()
		)
		service_pump_armed = false
		return

	if service_pump_armed:
		return

	if attached_signature != "":
		var attached_record: Dictionary = _record_for(
			attached_signature
		)
		var projection_surface_packets_terminal: bool = (
			bool(
				attached_record.get(
					"projection_surface_packets_complete",
					false
				)
			)
			or bool(
				attached_record.get(
					"projection_tail_failed",
					false
				)
			)
			or bool(
				attached_record.get(
					"projection_tail_skipped",
					false
				)
			)
		)
		var checkpoint_payload_pending: bool = bool(
			attached_record.get(
				"checkpoint_payload_apply_pending",
				false
			)
		)
		var checkpoint_progressive_hydration_active: bool = bool(
			attached_record.get(
				"checkpoint_progressive_hydration_started",
				false
			)
		)




		var all_attached_publication_terminal: bool = (
			projection_surface_packets_terminal
			and not checkpoint_payload_pending
			and not checkpoint_progressive_hydration_active
		)

		# FIX: this dormancy check only considered the ATTACHED record. Loading a save
		# registers a new checkpoint record that needs servicing while the attached
		# record is still the old, finished one -- so the pump refused to arm, the
		# checkpoint was never serviced, and the load stalled at
		# first_false_gate=resident_runtime_exists with service_attempts=0 and no
		# message. Only go dormant when nothing else is waiting for work.
		var other_records_pending: bool = false

		for raw_signature in resident_records.keys():
			if str(raw_signature) == attached_signature:
				continue

			var other_record: Dictionary = _record_for(
				str(raw_signature)
			)

			if other_record.is_empty():
				continue

			var other_state: String = str(
				other_record.get(
					"state",
					""
				)
			)

			if other_state != "ready" and other_state != "":
				other_records_pending = true
				break

		if (
			not attached_record.is_empty()
			and not other_records_pending
			and bool(
				attached_record.get(
					"lens_attached",
					false
				)
			)
			and str(
				attached_record.get(
					"state",
					""
				)
			) == "ready"
			and all_attached_publication_terminal
		):
			EraLog.truth(
				"ERALIFE_PUMP_ARM|result=declined|reason=attached_ready_dormant|attached=%s|other_pending=%s|keys=%d"
				% [attached_signature, str(other_records_pending), active_service_keys.size()]
			)
			service_pump_armed = false

			set_meta(
				"attached_ready_lens_service_pump_dormant",
				true
			)
			set_meta(
				"attached_ready_lens_service_pump_dormant_signature",
				attached_signature
			)
			set_meta(
				"attached_ready_lens_service_pump_dormant_at_ms",
				int(
					Time.get_ticks_msec()
				)
			)
			set_meta(
				"attached_ready_lens_surface_packets_complete",
				bool(
					attached_record.get(
						"projection_surface_packets_complete",
						false
					)
				)
			)
			set_meta(
				"attached_ready_lens_checkpoint_payload_pending",
				false
			)
			set_meta(
				"attached_ready_lens_post_ready_simulation_paused",
				true
			)

			return

	set_meta(
		"attached_ready_lens_service_pump_dormant",
		false
	)
	set_meta(
		"attached_ready_lens_checkpoint_payload_pending",
		(
			bool(
				_record_for(
					attached_signature
				).get(
					"checkpoint_payload_apply_pending",
					false
				)
			)
			if attached_signature != ""
			else false
		)
	)




	EraLog.truth(
		"ERALIFE_PUMP_ARM|mgr=%d|result=armed|attached=%s|keys=%d|records=%d|key_list=%s"
		% [int(get_instance_id()), attached_signature, active_service_keys.size(), resident_records.size(),
			str(active_service_keys).substr(0, 120)]
	)

	service_pump_armed = true

	call_deferred(
		"_arm_service_pump_for_next_renderer_frame"
	)
func _arm_service_pump_for_next_renderer_frame() -> void:
	if not service_pump_armed:
		return

	if active_service_keys.is_empty():
		service_pump_armed = false
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		service_pump_armed = false
		call_deferred(
			"_ensure_service_pump"
		)
		return



	await RenderingServer.frame_post_draw

	if not service_pump_armed:
		return

	if active_service_keys.is_empty():
		service_pump_armed = false
		return

	var timer:= tree.create_timer(
		0.001,
		true,
		false,
		true
	)

	var connection_error: int = (
		timer.timeout.connect(
			Callable(
				self,
				"_service_pump_frame"
			),
			CONNECT_ONE_SHOT
		)
	)

	if connection_error != OK:
		service_pump_armed = false
		call_deferred(
			"_ensure_service_pump"
		)
		return

	set_meta(
		"service_pump_armed_for_renderer_frame",
		true
	)
	set_meta(
		"service_pump_armed_for_renderer_frame_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"service_pump_runs_after_present",
		true
	)
	set_meta(
		"service_pump_waits_for_ui_idle",
		false
	)
	set_meta(
		"service_pump_input_can_starve_publication",
		false
	)
	set_meta(
		"service_pump_fixed_timer_latency_ms",
		1
	)
func _service_pump_frame() -> void:
	if active_service_keys.is_empty():
		service_pump_armed = false
		return

	# FIX: a load registers a checkpoint record and then waits for it to resolve, but
	# the rest of this function has many paths that yield or go dormant -- the truth
	# line showed service_pump_armed flipping to false while the checkpoint still sat
	# at service_attempts=0, and only the attached record was ever serviced. Guarding
	# each disarm individually kept missing one, so a pending checkpoint is serviced
	# here directly, ahead of all of it. This is a blocking player action; it should
	# not be competing with background work for a turn.
	for raw_pending_signature in resident_records.keys():
		var pending_signature: String = str(raw_pending_signature).strip_edges()

		if pending_signature == "":
			continue

		var pending_record: Dictionary = _record_for(pending_signature)

		if pending_record.is_empty():
			continue

		if str(pending_record.get("state", "")) in [
			"checkpoint_resolution_pending",
			"rehydration_pending"
		]:
			service_pump_armed = true
			_service_record(
				pending_signature,
				1,
				4
			)
			_ensure_service_pump()
			return

	var attached_projection_publication_only: bool = false
	var attached_surface_visible: bool = false
	var attached_surface_packets_terminal: bool = false
	var attached_checkpoint_payload_pending: bool = false
	var attached_ui_priority_until_ms: int = 0

	if attached_signature != "":
		var attached_record: Dictionary = _record_for(
			attached_signature
		)
		var attached_lens_is_playable: bool = (
			not attached_record.is_empty()
			and bool(
				attached_record.get(
					"lens_attached",
					false
				)
			)
			and str(
				attached_record.get(
					"state",
					""
				)
			) == "ready"
		)

		if attached_lens_is_playable:
			var now_ms: int = int(
				Time.get_ticks_msec()
			)

			attached_surface_packets_terminal = (
				bool(
					attached_record.get(
						"projection_surface_packets_complete",
						false
					)
				)
				or bool(
					attached_record.get(
						"projection_tail_failed",
						false
					)
				)
				or bool(
					attached_record.get(
						"projection_tail_skipped",
						false
					)
				)
			)
			attached_checkpoint_payload_pending = bool(
				attached_record.get(
					"checkpoint_payload_apply_pending",
					false
				)
			)

			var runtime_raw: Variant = (
				attached_record.get(
					"runtime_ref",
					null
				)
			)
			var resident_gs: GameState = (
				runtime_raw as GameState
				if runtime_raw is GameState
				else null
			)

			if resident_gs != null:
				if typeof(
					resident_gs.scenario_state
				) != TYPE_DICTIONARY:
					resident_gs.scenario_state = {}

				var runtime_guard: Dictionary = _dict(
					resident_gs.scenario_state.get(
						"runtime_guard",
						{}
					)
				)

				attached_ui_priority_until_ms = maxi(
					maxi(
						int(
							runtime_guard.get(
								"ui_interaction_grace_until_ms",
								0
							)
						),
						int(
							runtime_guard.get(
								"truth_resolution_yield_until_ms",
								0
							)
						)
					),
					int(
						resident_gs.scenario_state.get(
							"ready_door_zero_frame_input_fence_until_ms",
							0
						)
					)
				)

				attached_surface_visible = (
					bool(
						resident_gs.scenario_state.get(
							"playable_life_shell_has_visible_sovereignty",
							false
						)
					)
					or bool(
						resident_gs.scenario_state.get(
							"playable_life_surface_has_visual_authority",
							false
						)
					)
					or bool(
						resident_gs.scenario_state.get(
							"god_mode_ready_revealed_staged_surface",
							false
						)
					)
					or bool(
						resident_gs.scenario_state.get(
							"checkpoint_progressive_core_shell_commit_complete",
							false
						)
					)
				)




			if (
				attached_surface_packets_terminal
				and not attached_checkpoint_payload_pending
			):
				attached_record [
					"residency_tail_paused_for_interactive_lens"
				] = true
				attached_record [
					"residency_tail_pause_reason"
				] = "attached_playable_lens_surface_packets_terminal"
				attached_record [
					"projection_publication_lane_active"
				] = false
				attached_record [
					"projection_publication_lane_only"
				] = false
				attached_record [
					"checkpoint_payload_publication_lane_active"
				] = false
				attached_record [
					"post_ready_simulation_allowed_while_attached"
				] = false
				attached_record [
					"snapshot_allowed_while_attached"
				] = false
				attached_record [
					"bulk_projection_allowed_while_attached"
				] = false
				attached_record [
					"interactive_input_has_absolute_priority"
				] = true
				attached_record [
					"residency_tail_paused_at_ms"
				] = now_ms

				resident_records [
					attached_signature
				] = attached_record

				if resident_gs != null:
					resident_gs.scenario_state [
						"resident_projection_publication_lane_active"
					] = false
					resident_gs.scenario_state [
						"resident_projection_surface_packets_complete"
					] = bool(
						attached_record.get(
							"projection_surface_packets_complete",
							false
						)
					)
					resident_gs.scenario_state [
						"resident_checkpoint_payload_publication_lane_active"
					] = false
					resident_gs.scenario_state [
						"resident_post_ready_truth_tail_paused"
					] = true
					resident_gs.scenario_state [
						"resident_post_ready_truth_tail_pause_reason"
					] = "attached_playable_lens_surface_packets_terminal"
					resident_gs.scenario_state [
						"resident_snapshot_tail_paused"
					] = true
					resident_gs.scenario_state [
						"resident_bulk_projection_allowed_while_attached"
					] = false
					resident_gs.scenario_state [
						"resident_interactive_input_has_absolute_priority"
					] = true
					resident_gs.scenario_state [
						"resident_attached_truth_uses_incremental_deltas"
					] = true

				set_meta(
					"attached_lens_projection_publication_allowed",
					false
				)
				set_meta(
					"attached_lens_surface_packets_terminal",
					true
				)
				set_meta(
					"attached_lens_checkpoint_payload_publication_allowed",
					false
				)
				set_meta(
					"attached_lens_post_ready_simulation_allowed",
					false
				)
				set_meta(
					"attached_lens_snapshot_allowed",
					false
				)
				set_meta(
					"attached_lens_bulk_projection_allowed",
					false
				)
				set_meta(
					"attached_lens_interactive_input_has_absolute_priority",
					true
				)
				set_meta(
					"attached_lens_service_pump_suspended_at_ms",
					now_ms
				)

				service_pump_armed = false
				return



			attached_projection_publication_only = true

			attached_record [
				"residency_tail_paused_for_interactive_lens"
			] = false
			attached_record [
				"residency_tail_pause_reason"
			] = ""
			attached_record [
				"projection_publication_lane_active"
			] = not attached_surface_packets_terminal
			attached_record [
				"projection_publication_lane_only"
			] = true
			attached_record [
				"checkpoint_payload_publication_lane_active"
			] = attached_checkpoint_payload_pending
			attached_record [
				"checkpoint_payload_publication_lane_only"
			] = attached_checkpoint_payload_pending
			attached_record [
				"post_ready_simulation_allowed_while_attached"
			] = false
			attached_record [
				"snapshot_allowed_while_attached"
			] = false
			attached_record [
				"bulk_projection_allowed_while_attached"
			] = false
			attached_record [
				"interactive_input_has_absolute_priority"
			] = true
			attached_record [
				"projection_publication_last_armed_at_ms"
			] = now_ms

			resident_records [
				attached_signature
			] = attached_record

			if resident_gs != null:
				resident_gs.scenario_state [
					"resident_projection_publication_lane_active"
				] = not attached_surface_packets_terminal
				resident_gs.scenario_state [
					"resident_projection_publication_lane_only"
				] = true
				resident_gs.scenario_state [
					"resident_projection_surface_packets_complete"
				] = attached_surface_packets_terminal
				resident_gs.scenario_state [
					"resident_checkpoint_payload_publication_lane_active"
				] = attached_checkpoint_payload_pending
				resident_gs.scenario_state [
					"resident_checkpoint_payload_publication_lane_only"
				] = attached_checkpoint_payload_pending
				resident_gs.scenario_state [
					"resident_post_ready_truth_tail_paused"
				] = true
				resident_gs.scenario_state [
					"resident_post_ready_truth_tail_pause_reason"
				] = (
					"checkpoint_payload_publication_only"
					if attached_checkpoint_payload_pending
					else "surface_packet_publication_only"
				)
				resident_gs.scenario_state [
					"resident_snapshot_tail_paused"
				] = true
				resident_gs.scenario_state [
					"resident_bulk_projection_allowed_while_attached"
				] = false
				resident_gs.scenario_state [
					"resident_interactive_input_has_absolute_priority"
				] = true
				resident_gs.scenario_state [
					"resident_surface_packets_publish_behind_ready_cover"
				] = (
					not attached_surface_visible
					and not attached_surface_packets_terminal
				)
				resident_gs.scenario_state [
					"resident_surface_packets_do_not_block_ready"
				] = true

			set_meta(
				"attached_lens_projection_publication_allowed",
				not attached_surface_packets_terminal
			)
			set_meta(
				"attached_lens_projection_publication_lane_only",
				true
			)
			set_meta(
				"attached_lens_surface_packets_terminal",
				attached_surface_packets_terminal
			)
			set_meta(
				"attached_lens_checkpoint_payload_publication_allowed",
				attached_checkpoint_payload_pending
			)
			set_meta(
				"attached_lens_post_ready_simulation_allowed",
				false
			)
			set_meta(
				"attached_lens_snapshot_allowed",
				false
			)
			set_meta(
				"attached_lens_bulk_projection_allowed",
				false
			)
			set_meta(
				"attached_lens_interactive_input_has_absolute_priority",
				true
			)
			set_meta(
				"attached_lens_surface_packets_publish_behind_cover",
				(
					not attached_surface_visible
					and not attached_surface_packets_terminal
				)
			)



	if (
		attached_projection_publication_only
		and attached_surface_visible
		and int(
			Time.get_ticks_msec()
		) < attached_ui_priority_until_ms
	):
		set_meta(
			"attached_lens_checkpoint_publication_observed_input",
			true
		)
		set_meta(
			"attached_lens_checkpoint_publication_ui_priority_until_ms",
			attached_ui_priority_until_ms
		)
		set_meta(
			"attached_lens_checkpoint_publication_yielded_to_input",
			false
		)
		set_meta(
			"attached_lens_checkpoint_publication_continues_with_one_ms_budget",
			true
		)

	# FIX: these yield paths disarmed the pump, immediately re-armed it, and returned
	# without servicing anything. With a checkpoint waiting that is an infinite loop:
	# the log showed "result=armed" every frame while service_attempts stayed at 0,
	# so a loaded save never resolved. Yielding to the interactive lens is correct for
	# background work, but not when another record is actually waiting on the pump.
	if (
		not attached_projection_publication_only
		and _service_pump_should_yield_to_interactive_lens()
		and not _has_pending_non_attached_record()
	):
		service_pump_armed = false
		_ensure_service_pump()
		return

	var waiting_signature: String = (
		_ready_resident_waiting_for_first_lens_signature()
	)

	if (
		not attached_projection_publication_only
		and waiting_signature != ""
		and not _has_pending_non_attached_record()
	):
		set_meta(
			"ready_resident_service_paused_for_first_lens",
			true
		)
		set_meta(
			"ready_resident_service_paused_signature",
			waiting_signature
		)
		set_meta(
			"ready_resident_service_paused_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		service_pump_armed = false
		_ensure_service_pump()
		return

	service_pump_sequence += 1

	var preferred_signature: String = (
		attached_signature
		if attached_projection_publication_only
		else _priority_resident_signature_for_service()
	)
	var publication_budget_ms: int = (
		2
		if (
			attached_projection_publication_only
			and not attached_surface_visible
		)
		else 1
	)

	service_residency({
		"signature": preferred_signature,
		"max_steps": 1,
		"frame_budget_ms": publication_budget_ms,
		"service_request_id": (
			"resident_pump:%d:%d"
			% [
				service_pump_sequence,
				int(
					Time.get_ticks_msec()
				)
			]
		),
		"source": "reality_residency_manager.service_pump",
		"renderer_breathing_interval_ms": (
			50
			if not attached_surface_visible
			else 96
		),
		"preferred_resident_has_absolute_priority": (
			preferred_signature != ""
		),
		"projection_publication_lane_only": (
			attached_projection_publication_only
		),
		"checkpoint_payload_publication_lane": (
			attached_checkpoint_payload_pending
		),
		"projection_surface_packets_publish_behind_cover": (
			attached_projection_publication_only
			and not attached_surface_visible
		),
		"post_ready_simulation_forbidden": (
			attached_projection_publication_only
		),
		"snapshot_capture_forbidden": (
			attached_projection_publication_only
		),
		"ready_resident_waits_for_lens_before_tail": (
			not attached_projection_publication_only
		),
		"service_quantum_limit": 1,
		"service_frame_budget_ms": publication_budget_ms,
	})

	service_pump_armed = false
	_ensure_service_pump()
func _service_pump_should_yield_to_interactive_lens() -> bool:
	if attached_signature == "":
		return false

	var attached_record: Dictionary = _record_for(
		attached_signature
	)

	if attached_record.is_empty():
		return false

	if not bool(
		attached_record.get(
			"lens_attached",
			false
		)
	):
		return false

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var attached_state: String = str(
		attached_record.get(
			"state",
			""
		)
	)
	var residency_tail_pending: bool = bool(
		attached_record.get(
			"residency_tail_pending",
			false
		)
	)
	var attached_service_key: String = (
		"resident:%s" % attached_signature
	)
	var projection_surface_packets_terminal: bool = (
		bool(
			attached_record.get(
				"projection_surface_packets_complete",
				false
			)
		)
		or bool(
			attached_record.get(
				"projection_tail_failed",
				false
			)
		)
		or bool(
			attached_record.get(
				"projection_tail_skipped",
				false
			)
		)
	)
	var runtime_raw: Variant = attached_record.get(
		"runtime_ref",
		null
	)
	var resident_gs: GameState = null
	var resident_scenario_state: Dictionary = {}
	var runtime_guard: Dictionary = {}

	if runtime_raw is GameState:
		resident_gs = (
			runtime_raw as GameState
		)

	if resident_gs != null:
		if typeof(
			resident_gs.scenario_state
		) != TYPE_DICTIONARY:
			resident_gs.scenario_state = {}

		resident_scenario_state = (
			resident_gs.scenario_state
		)

		var runtime_guard_raw: Variant = (
			resident_scenario_state.get(
				"runtime_guard",
				{}
			)
		)

		if typeof(
			runtime_guard_raw
		) == TYPE_DICTIONARY:
			runtime_guard = (
				runtime_guard_raw as Dictionary
			)

	var ready_door_contract_active: bool = (
		bool(
			resident_scenario_state.get(
				"ready_door_latch_hot",
				false
			)
		)
		or bool(
			resident_scenario_state.get(
				"god_mode_ready_aaa_life_shell_hot",
				false
			)
		)
		or bool(
			resident_scenario_state.get(
				"god_mode_zero_frame_entry_surface_staged",
				false
			)
		)
		or bool(
			resident_scenario_state.get(
				"god_mode_zero_frame_entry_surface_prebuilt",
				false
			)
		)
	)
	var player_control_released: bool = bool(
		resident_scenario_state.get(
			"playable_life_surface_player_control_released",
			false
		)
	)
	var first_paint_complete: bool = bool(
		resident_scenario_state.get(
			"ready_door_first_paint_complete",
			false
		)
	)
	var interaction_grace_until_ms: int = int(
		runtime_guard.get(
			"ui_interaction_grace_until_ms",
			0
		)
	)
	var truth_resolution_yield_until_ms: int = int(
		runtime_guard.get(
			"truth_resolution_yield_until_ms",
			0
		)
	)
	var ready_door_input_fence_until_ms: int = int(
		resident_scenario_state.get(
			"ready_door_zero_frame_input_fence_until_ms",
			0
		)
	)
	var ui_priority_until_ms: int = maxi(
		maxi(
			interaction_grace_until_ms,
			truth_resolution_yield_until_ms
		),
		ready_door_input_fence_until_ms
	)
	var ready_door_owns_renderer: bool = (
		attached_state == "ready"
		and residency_tail_pending
		and not projection_surface_packets_terminal
		and ready_door_contract_active
		and (
			not player_control_released
			or not first_paint_complete
			or now_ms < ui_priority_until_ms
		)
	)




	if ready_door_owns_renderer:
		var pause_reason: String = (
			"ready_door_waiting_for_player_press"
		)

		if player_control_released:
			pause_reason = (
				"ready_door_waiting_for_first_paint"
			)

		if (
			first_paint_complete
			and now_ms < ui_priority_until_ms
		):
			pause_reason = (
				"zero_frame_entry_input_fence_active"
			)

		attached_record [
			"residency_tail_paused_for_interactive_lens"
		] = true
		attached_record [
			"residency_tail_pause_reason"
		] = pause_reason
		attached_record [
			"projection_publication_lane_active"
		] = false
		attached_record [
			"projection_publication_waiting_for_ready_door"
		] = true
		attached_record [
			"projection_publication_waiting_for_first_paint"
		] = not first_paint_complete
		attached_record [
			"projection_publication_waiting_for_ui_fence"
		] = (
			now_ms < ui_priority_until_ms
		)
		attached_record [
			"post_ready_simulation_allowed_while_attached"
		] = false
		attached_record [
			"snapshot_allowed_while_attached"
		] = false

		resident_records [
			attached_signature
		] = attached_record

		if not active_service_keys.has(
			attached_service_key
		):
			_append_service_key(
				attached_service_key
			)

		if resident_gs != null:
			resident_scenario_state [
				"resident_projection_publication_lane_active"
			] = false
			resident_scenario_state [
				"resident_projection_publication_waiting_for_ready_door"
			] = true
			resident_scenario_state [
				"resident_projection_publication_pause_reason"
			] = pause_reason
			resident_scenario_state [
				"resident_projection_publication_ui_priority_until_ms"
			] = ui_priority_until_ms
			resident_scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = true
			resident_scenario_state [
				"resident_post_ready_truth_tail_pause_reason"
			] = pause_reason
			resident_scenario_state [
				"resident_snapshot_tail_paused"
			] = true
			resident_scenario_state [
				"resident_interactive_input_has_absolute_priority"
			] = true

		set_meta(
			"attached_lens_projection_publication_allowed",
			false
		)
		set_meta(
			"attached_lens_projection_waiting_for_ready_door",
			true
		)
		set_meta(
			"attached_lens_projection_pause_reason",
			pause_reason
		)
		set_meta(
			"attached_lens_projection_ui_priority_until_ms",
			ui_priority_until_ms
		)
		set_meta(
			"attached_lens_post_ready_simulation_allowed",
			false
		)
		set_meta(
			"attached_lens_snapshot_allowed",
			false
		)
		set_meta(
			"attached_lens_interactive_input_has_absolute_priority",
			true
		)

		return true




	if (
		attached_state == "ready"
		and residency_tail_pending
		and not projection_surface_packets_terminal
	):
		attached_record [
			"residency_tail_paused_for_interactive_lens"
		] = false
		attached_record [
			"residency_tail_pause_reason"
		] = ""
		attached_record [
			"projection_publication_lane_active"
		] = true
		attached_record [
			"projection_publication_lane_only"
		] = true
		attached_record [
			"projection_publication_waiting_for_ready_door"
		] = false
		attached_record [
			"projection_publication_waiting_for_first_paint"
		] = false
		attached_record [
			"projection_publication_waiting_for_ui_fence"
		] = false
		attached_record [
			"post_ready_simulation_allowed_while_attached"
		] = false
		attached_record [
			"snapshot_allowed_while_attached"
		] = false

		resident_records [
			attached_signature
		] = attached_record

		if not active_service_keys.has(
			attached_service_key
		):
			_append_service_key(
				attached_service_key
			)

		if resident_gs != null:
			resident_scenario_state [
				"resident_projection_publication_lane_active"
			] = true
			resident_scenario_state [
				"resident_projection_publication_lane_only"
			] = true
			resident_scenario_state [
				"resident_projection_publication_waiting_for_ready_door"
			] = false
			resident_scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = true
			resident_scenario_state [
				"resident_post_ready_truth_tail_pause_reason"
			] = (
				"interactive_surface_packets_publish_first"
			)
			resident_scenario_state [
				"resident_snapshot_tail_paused"
			] = true

		set_meta(
			"attached_lens_projection_publication_allowed",
			true
		)
		set_meta(
			"attached_lens_projection_waiting_for_ready_door",
			false
		)
		set_meta(
			"attached_lens_post_ready_simulation_allowed",
			false
		)
		set_meta(
			"attached_lens_snapshot_allowed",
			false
		)
		set_meta(
			"attached_lens_projection_publication_signature",
			attached_signature
		)
		set_meta(
			"attached_lens_projection_publication_at_ms",
			now_ms
		)

		return false

	if attached_state == "ready":
		attached_record [
			"residency_tail_paused_for_interactive_lens"
		] = true
		attached_record [
			"residency_tail_pause_reason"
		] = "interactive_lens_has_absolute_priority"
		attached_record [
			"projection_publication_lane_active"
		] = false
		attached_record [
			"post_ready_simulation_allowed_while_attached"
		] = false
		attached_record [
			"snapshot_allowed_while_attached"
		] = false

		resident_records [
			attached_signature
		] = attached_record

		if resident_gs != null:
			resident_scenario_state [
				"resident_projection_publication_lane_active"
			] = false
			resident_scenario_state [
				"resident_post_ready_truth_tail_paused"
			] = true
			resident_scenario_state [
				"resident_post_ready_truth_tail_pause_reason"
			] = "interactive_lens_has_absolute_priority"
			resident_scenario_state [
				"resident_snapshot_tail_paused"
			] = true
			resident_scenario_state [
				"resident_interactive_input_has_absolute_priority"
			] = true

		set_meta(
			"attached_lens_projection_publication_allowed",
			false
		)
		set_meta(
			"attached_lens_post_ready_simulation_allowed",
			false
		)
		set_meta(
			"attached_lens_snapshot_allowed",
			false
		)
		set_meta(
			"attached_lens_unrelated_residency_work_paused",
			true
		)
		set_meta(
			"attached_lens_interactive_input_has_absolute_priority",
			true
		)

		return true

	if not _resident_record_requires_foreground_service(
		attached_record
	):
		return true

	var attached_at_ms: int = int(
		attached_record.get(
			"last_attached_at_ms",
			0
		)
	)

	if (
		attached_at_ms > 0
		and now_ms - attached_at_ms < 750
	):
		return true

	if not active_service_keys.has(
		attached_service_key
	):
		_append_service_key(
			attached_service_key
		)

	var quantum_interval_ms: int = 125
	var next_quantum_at_ms: int = int(
		get_meta(
			"attached_lens_next_residency_quantum_at_ms",
			0
		)
	)

	if next_quantum_at_ms <= 0:
		set_meta(
			"attached_lens_next_residency_quantum_at_ms",
			now_ms + quantum_interval_ms
		)
		set_meta(
			"attached_lens_residency_quantum_interval_ms",
			quantum_interval_ms
		)

		return true

	if now_ms < next_quantum_at_ms:
		return true

	set_meta(
		"attached_lens_next_residency_quantum_at_ms",
		now_ms + quantum_interval_ms
	)
	set_meta(
		"attached_lens_residency_quantum_interval_ms",
		quantum_interval_ms
	)
	set_meta(
		"attached_lens_last_residency_quantum_released_at_ms",
		now_ms
	)

	return false
func _take_available_chassis() -> GameState:
	var ids: Array = chassis_records.keys()
	ids.sort()

	for raw_id in ids:
		var chassis_id: String = str(
			raw_id
		)
		var chassis: Dictionary = _dict(
			chassis_records.get(
				chassis_id,
				{}
			)
		)

		if str(
			chassis.get(
				"state",
				""
			)
		) != "hot_chassis":
			continue

		if not bool(
			chassis.get(
				"hot",
				false
			)
		):
			continue

		var runtime = chassis.get(
			"runtime_ref",
			null
		)

		if not (
			runtime is GameState
		):
			continue

		chassis_records.erase(
			chassis_id
		)

		return runtime as GameState

	return null

func _replace_uncommitted_preview(
	slot: String,
	new_signature: String
) -> void:
	var old_signature: String = str(
		preview_signature_by_slot.get(
			slot,
			""
		)
	)

	if (
		old_signature == ""
		or old_signature == new_signature
		or not resident_records.has(
			old_signature
		)
	):
		return

	var record: Dictionary = _record_for(
		old_signature
	)

	if (
		bool(
			record.get(
				"committed",
				false
			)
		)
		or bool(
			record.get(
				"lens_attached",
				false
			)
		)
	):
		return

	resident_records.erase(
		old_signature
	)
	_remove_service_key(
		"resident:%s" % old_signature
	)
	preview_signature_by_slot.erase(
		slot
	)

	if projection_engine != null:
		projection_engine.projection_work_by_signature.erase(
			old_signature
		)


func _evict_oldest_uncommitted_preview() -> bool:
	var oldest_signature: String = ""
	var oldest_ms: int = 9223372036854775807

	for raw_signature in resident_records.keys():
		var signature: String = str(
			raw_signature
		)
		var record: Dictionary = _record_for(
			signature
		)

		if (
			bool(
				record.get(
					"committed",
					false
				)
			)
			or bool(
				record.get(
					"lens_attached",
					false
				)
			)
		):
			continue

		var reserved_at_ms: int = int(
			record.get(
				"reserved_at_ms",
				0
			)
		)

		if reserved_at_ms < oldest_ms:
			oldest_ms = reserved_at_ms
			oldest_signature = signature

	if oldest_signature == "":
		return false

	resident_records.erase(
		oldest_signature
	)
	_remove_service_key(
		"resident:%s" % oldest_signature
	)

	return true


func _inject_shared_authorities(
	runtime: GameState
) -> void:
	if runtime == null:
		return

	runtime.reality_snapshot_contract_engine = (
		snapshot_engine
	)
	runtime.reality_projection_contract_engine = (
		projection_engine
	)
	runtime.reality_residency_manager = self
	runtime.reality_residency_contract_engine = (
		RealityResidencyContractEngine.new(
			runtime,
			self,
			snapshot_engine,
			projection_engine
		)
	)


func _next_service_key(
	preferred_signature: String
) -> String:
	var clean_preferred_signature: String = str(
		preferred_signature
	).strip_edges()
	var preferred_key: String = (
		"resident:%s" % clean_preferred_signature
		if clean_preferred_signature != ""
		else ""
	)

	if preferred_key != "":
		var preferred_record: Dictionary = _record_for(
			clean_preferred_signature
		)

		if not preferred_record.is_empty():
			var preferred_state: String = str(
				preferred_record.get(
					"state",
					""
				)
			)
			EraLog.truth(
				"ERALIFE_NEXT_KEY|preferred_sig=%s|state=%s|key=%s|in_active=%s"
				% [
					clean_preferred_signature,
					preferred_state,
					preferred_key,
					str(preferred_key in active_service_keys)
				]
			)

			var preferred_requires_service: bool = (
				preferred_state in [
					"reserved",
					"waiting_for_hot_chassis",
					"building_contract_graph",
					"binding_reality",
					"checkpoint_resolution_pending",
					"rehydration_pending",
					"projecting_contracts"
				]
				or (
					preferred_state == "ready"
					and bool(
						preferred_record.get(
							"residency_tail_pending",
							false
						)
					)
				)
			)
			var preferred_waits_for_hot_chassis: bool = (
				preferred_state == "waiting_for_hot_chassis"
				or bool(
					preferred_record.get(
						"checkpoint_waits_for_hot_chassis",
						false
					)
				)
				or bool(
					preferred_record.get(
						"checkpoint_waiting_for_hot_chassis",
						false
					)
				)
			)

			if preferred_requires_service:


				_append_service_key(
					preferred_key
				)





				if preferred_waits_for_hot_chassis:
					var ordered_chassis_ids: Array = (
						chassis_records.keys()
					)
					ordered_chassis_ids.sort()

					var hot_chassis_available: bool = false
					var dependency_service_key: String = ""




					for raw_chassis_id in ordered_chassis_ids:
						var chassis_id: String = str(
							raw_chassis_id
						)
						var chassis: Dictionary = _dict(
							chassis_records.get(
								chassis_id,
								{}
							)
						)
						var chassis_state: String = str(
							chassis.get(
								"state",
								""
							)
						)

						if chassis_state == "building_contract_graph":
							chassis_state = "building_hot_chassis"
							chassis ["state"] = chassis_state
							chassis [
								"legacy_chassis_state_reconciled"
							] = true
							chassis [
								"legacy_chassis_state_reconciled_at_ms"
							] = int(
								Time.get_ticks_msec()
							)
							chassis_records [chassis_id] = chassis

						if (
							chassis_state == "hot_chassis"
							and bool(
								chassis.get(
									"hot",
									false
								)
							)
							and chassis.get(
								"runtime_ref",
								null
							) is GameState
						):
							hot_chassis_available = true
							break

						if (
							dependency_service_key == ""
							and chassis_state in [
								"allocation_pending",
								"building_hot_chassis"
							]
						):
							dependency_service_key = (
								"chassis:%s" % chassis_id
							)

					if hot_chassis_available:
						return preferred_key

					if dependency_service_key != "":
						_append_service_key(
							dependency_service_key
						)
						return dependency_service_key

					prime_chassis_pool({
						"target_chassis_count": chassis_target,
						"source": (
							"next_service_key_repair_missing_chassis"
						)
					})

					ordered_chassis_ids = (
						chassis_records.keys()
					)
					ordered_chassis_ids.sort()
					hot_chassis_available = false
					dependency_service_key = ""

					for raw_chassis_id in ordered_chassis_ids:
						var chassis_id: String = str(
							raw_chassis_id
						)
						var chassis: Dictionary = _dict(
							chassis_records.get(
								chassis_id,
								{}
							)
						)
						var chassis_state: String = str(
							chassis.get(
								"state",
								""
							)
						)

						if (
							chassis_state == "hot_chassis"
							and bool(
								chassis.get(
									"hot",
									false
								)
							)
							and chassis.get(
								"runtime_ref",
								null
							) is GameState
						):
							hot_chassis_available = true
							break

						if (
							dependency_service_key == ""
							and chassis_state in [
								"allocation_pending",
								"building_hot_chassis"
							]
						):
							dependency_service_key = (
								"chassis:%s" % chassis_id
							)

					if hot_chassis_available:
						return preferred_key

					if dependency_service_key != "":
						_append_service_key(
							dependency_service_key
						)
						return dependency_service_key

				return preferred_key

		_remove_service_key(
			preferred_key
		)

	if active_service_keys.is_empty():
		return ""

	var queue_snapshot: Array = (
		active_service_keys.duplicate()
	)
	var snapshot_size: int = queue_snapshot.size()
	var snapshot_start: int = wrapi(
		service_cursor,
		0,
		snapshot_size
	)

	for offset in range(
		snapshot_size
	):
		var snapshot_index: int = wrapi(
			snapshot_start + offset,
			0,
			snapshot_size
		)
		var candidate_key: String = str(
			queue_snapshot [
				snapshot_index
			]
		).strip_edges()

		if candidate_key.begins_with(
			"chassis:"
		):
			var chassis_id: String = candidate_key.trim_prefix(
				"chassis:"
			)
			var chassis_record: Dictionary = _dict(
				chassis_records.get(
					chassis_id,
					{}
				)
			)
			var chassis_state: String = str(
				chassis_record.get(
					"state",
					""
				)
			)

			if chassis_state == "building_contract_graph":
				chassis_state = "building_hot_chassis"
				chassis_record ["state"] = chassis_state
				chassis_record [
					"legacy_chassis_state_reconciled"
				] = true
				chassis_record [
					"legacy_chassis_state_reconciled_at_ms"
				] = int(
					Time.get_ticks_msec()
				)
				chassis_records [chassis_id] = chassis_record

			if chassis_state in [
				"allocation_pending",
				"building_hot_chassis"
			]:
				var live_chassis_index: int = (
					active_service_keys.find(
						candidate_key
					)
				)

				if live_chassis_index >= 0:
					service_cursor = wrapi(
						live_chassis_index + 1,
						0,
						active_service_keys.size()
					)

				return candidate_key

			_remove_service_key(
				candidate_key
			)
			continue

		if candidate_key.begins_with(
			"resident:"
		):
			var candidate_signature: String = (
				candidate_key.trim_prefix(
					"resident:"
				)
			)
			var candidate_record: Dictionary = _record_for(
				candidate_signature
			)

			if candidate_record.is_empty():
				_remove_service_key(
					candidate_key
				)
				continue

			var candidate_state: String = str(
				candidate_record.get(
					"state",
					""
				)
			)
			var candidate_requires_service: bool = (
				candidate_state in [
					"reserved",
					"waiting_for_hot_chassis",
					"building_contract_graph",
					"binding_reality",
					"checkpoint_resolution_pending",
					"rehydration_pending",
					"projecting_contracts"
				]
				or (
					candidate_state == "ready"
					and bool(
						candidate_record.get(
							"residency_tail_pending",
							false
						)
					)
				)
			)

			if candidate_requires_service:
				var live_resident_index: int = (
					active_service_keys.find(
						candidate_key
					)
				)

				if live_resident_index >= 0:
					service_cursor = wrapi(
						live_resident_index + 1,
						0,
						active_service_keys.size()
					)

				return candidate_key

			_remove_service_key(
				candidate_key
			)
			continue

		_remove_service_key(
			candidate_key
		)

	return ""
func _append_service_key(
	key: String
) -> void:
	var clean_key: String = str(
		key
	).strip_edges()

	if clean_key == "":
		return

	# The checkpoint record's key never appeared in active_service_keys during a load,
	# so report every registration to see whether it is added and then lost, or never
	# added at all.
	if clean_key.find("checkpoint") >= 0:
		EraLog.truth(
			"ERALIFE_KEY_APPEND|mgr=%d|key=%s|already_present=%s|keys_before=%d"
			% [
				int(get_instance_id()),
				clean_key,
				str(clean_key in active_service_keys),
				active_service_keys.size()
			]
		)

	if clean_key not in active_service_keys:
		active_service_keys.append(
			clean_key
		)



	_ensure_service_pump()

func _remove_service_key(
	key: String
) -> void:
	var clean_key: String = str(
		key
	).strip_edges()

	if clean_key == "":
		return

	if clean_key.begins_with(
		"resident:"
	):
		var signature: String = clean_key.trim_prefix(
			"resident:"
		)
		var record: Dictionary = _record_for(
			signature
		)

		if not record.is_empty():
			var state: String = str(
				record.get(
					"state",
					""
				)
			)
			var interactive_checkpoint_tail_paused: bool = (
				state == "ready"
				and bool(
					record.get(
						"lens_attached",
						false
					)
				)
				and bool(
					record.get(
						"residency_tail_paused_for_interactive_lens",
						false
					)
				)
				and bool(
					record.get(
						"interactive_input_has_absolute_priority",
						false
					)
				)
			)
			var requires_service: bool = (
				not interactive_checkpoint_tail_paused
				and (
					state in [
						"reserved",
						"waiting_for_hot_chassis",
						"building_contract_graph",
						"binding_reality",
						"checkpoint_resolution_pending",
						"rehydration_pending",
						"projecting_contracts"
					]
					or (
						state == "ready"
						and bool(
							record.get(
								"residency_tail_pending",
								false
							)
						)
					)
				)
			)

			if requires_service:
				if clean_key not in active_service_keys:
					active_service_keys.append(
						clean_key
					)

				_ensure_service_pump()
				return

			if interactive_checkpoint_tail_paused:
				record [
					"service_key_removed_for_interactive_checkpoint_lens"
				] = true
				record [
					"service_key_removed_for_interactive_checkpoint_lens_at_ms"
				] = int(
					Time.get_ticks_msec()
				)
				record [
					"detached_tail_rearms_on_lens_detach"
				] = bool(
					record.get(
						"residency_tail_pending",
						false
					)
				)
				resident_records [signature] = record

	active_service_keys.erase(
		clean_key
	)

	if active_service_keys.is_empty():
		service_cursor = 0
		service_pump_armed = false
	else:
		service_cursor = clampi(
			service_cursor,
			0,
			active_service_keys.size() - 1
		)


func _fail_record(
	record: Dictionary,
	signature: String,
	reason: String,
	details: Dictionary = {}
) -> void:
	record ["state"] = "failed"
	record ["failure"] = {
		"reason": reason,
		"details": details.duplicate(true),
		"failed_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	resident_records [signature] = record
	_remove_service_key(
		"resident:%s" % signature
	)


func _record_for(
	signature: String
) -> Dictionary:
	var record_raw: Variant = resident_records.get(
		signature,
		{}
	)

	return (
		(record_raw as Dictionary).duplicate(false)
		if typeof(record_raw) == TYPE_DICTIONARY
		else {}
	)

func export_state() -> Dictionary:
	var residents: Dictionary = {}

	for raw_signature in resident_records.keys():
		var signature: String = str(
			raw_signature
		)
		var serializable: Dictionary = _record_for(
			signature
		)
		serializable.erase(
			"runtime_ref"
		)
		residents [signature] = serializable

	return {
		"schema": STATE_SCHEMA,
		"version": ENGINE_VERSION,
		"state": {
			"resident_records": residents,
			"preview_signature_by_slot": (
				preview_signature_by_slot.duplicate(true)
			),
			"attached_signature": attached_signature,
			"next_chassis_sequence": (
				next_chassis_sequence
			),
			"chassis_target": chassis_target,
			"max_resident_realities": (
				max_resident_realities
			),
			"ledger": ledger.duplicate(true)
		},
		"ui_is_renderer_only": true
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	var imported: Dictionary = _dict(
		data.get(
			"state",
			data
		)
	)
	var imported_records: Dictionary = _dict(
		imported.get(
			"resident_records",
			{}
		)
	)

	# FIX: this hardcoded attached_signature = "", discarding the value that
	# export_state() deliberately saves. After loading, the restored record existed
	# and its service key existed, but no reality was attached -- which is the
	# first_false_gate=resident_runtime_exists stall, and why the pump armed 331 times
	# without ever servicing anything. Restore what was saved, but only if the record
	# it names actually came back with the import.
	var imported_attached_signature: String = str(
		imported.get(
			"attached_signature",
			""
		)
	).strip_edges()

	if (
		imported_attached_signature != ""
		and imported_records.has(imported_attached_signature)
	):
		attached_signature = imported_attached_signature
	else:
		attached_signature = ""

	EraLog.truth(
		"ERALIFE_RESIDENCY_IMPORT|attached_restored=%s|signature=%s|records=%d"
		% [
			str(attached_signature != ""),
			imported_attached_signature,
			imported_records.size()
		]
	)

	next_chassis_sequence = maxi(
		1,
		int(
			imported.get(
				"next_chassis_sequence",
				1
			)
		)
	)
	chassis_target = clampi(
		int(
			imported.get(
				"chassis_target",
				DEFAULT_CHASSIS_TARGET
			)
		),
		1,
		DEFAULT_MAX_RESIDENT_REALITIES
	)
	max_resident_realities = maxi(
		1,
		int(
			imported.get(
				"max_resident_realities",
				DEFAULT_MAX_RESIDENT_REALITIES
			)
		)
	)
	ledger = _array(
		imported.get(
			"ledger",
			[]
		)
	)
	preview_signature_by_slot = {}
	resident_records = {}
	chassis_records = {}
	active_service_keys = []
	service_cursor = 0
	service_pump_armed = false

	var restored_record_count: int = 0
	var skipped_preview_count: int = 0

	for raw_signature in imported_records.keys():
		var signature: String = str(
			raw_signature
		).strip_edges()
		var record: Dictionary = _dict(
			imported_records.get(
				raw_signature,
				{}
			)
		)
		var snapshot: Dictionary = _dict(
			record.get(
				"snapshot",
				{}
			)
		)
		var committed: bool = bool(
			record.get(
				"committed",
				false
			)
		)
		var verified_snapshot: bool = (
			bool(
				snapshot.get(
					"verified",
					false
				)
			)
			and bool(
				snapshot.get(
					"legal",
					false
				)
			)
		)

		if (
			signature == ""
			or (
				not committed
				and not verified_snapshot
			)
		):
			skipped_preview_count += 1
			continue

		record.erase(
			"runtime_ref"
		)
		record ["signature"] = signature
		record ["state"] = "checkpoint_resolution_pending"
		record ["lens_attached"] = false
		record ["committed"] = true
		record ["imported_from_persistent_state"] = true
		record ["runtime_reference_restored"] = false
		record ["rehydration_attempted"] = false
		record ["rehydration_completed"] = false
		record ["imported_at_ms"] = int(
			Time.get_ticks_msec()
		)

		resident_records [signature] = record
		_append_service_key(
			"resident:%s" % signature
		)
		restored_record_count += 1

	if not active_service_keys.is_empty():
		call_deferred(
			"_ensure_service_pump"
		)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "residency_metadata_imported",
		"snapshot_rehydration_available": (
			snapshot_engine != null
		),
		"checkpoint_hydration_queued": (
			restored_record_count > 0
		),
		"restored_record_count": restored_record_count,
		"skipped_preview_count": skipped_preview_count,
		"ui_is_renderer_only": true
	}


func _record(
	report: Dictionary
) -> void:
	last_report = report.duplicate(true)
	ledger.append(
		last_report.duplicate(true)
	)

	while ledger.size() > MAX_LEDGER:
		ledger.pop_front()


func _failure(
	reason: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report: Dictionary = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}

	_record(report)

	return report


func _dict(
	value: Variant
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value: Variant
) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)