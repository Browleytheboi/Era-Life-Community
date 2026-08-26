extends Resource
class_name AgeUpRuntimeEngine

const QUALITY_ULTRA:= "ultra_fidelity"
const QUALITY_BALANCED:= "balanced"
const QUALITY_MASSIVE:= "massive_world"

var gs
var active_year_context: Dictionary = {}
var active_groups: Dictionary = {}
var active_mailboxes: Dictionary = {}
var active_mailbox_keys: Dictionary = {}
var relevance_cache: Dictionary = {}
var last_execution_report: Dictionary = {}
var last_delta_packets: Array = []
var runtime_slice_active: bool = false
var runtime_slice_phase_cursor: int = 0
var runtime_slice_phase_timings: Dictionary = {}
var runtime_slice_started_at: int = 0
var runtime_slice_before_snapshot: Dictionary = {}
var runtime_slice_order: Array = []
var runtime_phase_walkers: Dictionary = {}

var runtime_contract_scheduler: Dictionary = {}
var runtime_phase_contracts: Dictionary = {}
var runtime_phase_overflow_log: Array = []
var runtime_slice_visible_watchdog_ms: int = 5200
var runtime_slice_force_complete_ms: int = 8200

func _init(_gs):
	gs = _gs
	_clear_runtime_state()

func _clear_runtime_state() -> void:
	active_year_context = {}
	active_groups = {}
	active_mailboxes = _build_empty_mailboxes()
	active_mailbox_keys = {}
	relevance_cache = {}
	last_execution_report = {}
	last_delta_packets = []
	runtime_slice_active = false
	runtime_slice_phase_cursor = 0
	runtime_slice_phase_timings = {}
	runtime_slice_started_at = 0
	runtime_slice_before_snapshot = {}
	runtime_slice_order = []
	runtime_phase_walkers = {}

	runtime_contract_scheduler = {}
	runtime_phase_contracts = {}
	runtime_phase_overflow_log = []
	runtime_slice_visible_watchdog_ms = 5200
	runtime_slice_force_complete_ms = 8200

func _build_empty_mailboxes() -> Dictionary:
	return {
		"mutation": [],
		"social": [],
		"scenario": [],
		"world_feed": [],
		"chronicle": [],
		"popups": [],
		"delta_packets": []
	}

func has_pending_commit() -> bool:
	if gs == null or gs.year_budget_engine == null:
		return false
	return gs.year_budget_engine.has_pending_year_pipeline()

func drain_pending_commit(max_stages: int = 1) -> void:
	if gs == null or gs.year_budget_engine == null:
		return
	gs.year_budget_engine.drain_pending_year_pipeline(max_stages)

func begin_year_transaction(
	context: Dictionary = {}
) -> Dictionary:



	var previous_groups: Dictionary = active_groups
	var previous_relevance_cache: Dictionary = relevance_cache

	_clear_runtime_state()

	var player_id: int = -1
	if (
		gs != null
		and gs.player != null
	):
		player_id = int(
			gs.player.id
		)

	var zero_frame_tail: bool = bool(
		context.get(
			"zero_frame_tail",
			false
		)
	)

	active_year_context = {
		"mode": str(
			context.get(
				"mode",
				"living"
			)
		),
		"year": int(
			context.get(
				"year",
				gs.year if gs != null else 0
			)
		),
		"player_id": int(
			context.get(
				"player_id",
				player_id
			)
		),
		"world_feed_cursor": (
			int(
				gs.world_feed.size()
			)
			if gs != null
			else 0
		),
		"death_cursor": (
			int(
				gs.pending_death_messages.size()
			)
			if gs != null
			else 0
		),
		"inheritance_cursor": (
			int(
				gs.pending_inheritance_messages.size()
			)
			if gs != null
			else 0
		),
		"popup_cursor": (
			int(
				gs.pending_year_resolution_popups.size()
			)
			if gs != null
			else 0
		),
		"quality_tier": QUALITY_BALANCED,
		"hot_dormant_ids": [],
		"phase_order": _fallback_age_up_phase_order(),
		"zero_frame_tail": zero_frame_tail,
		"runtime_owner": str(
			context.get(
				"runtime_owner",
				"age_up_runtime"
			)
		),
	}

	var planned_groups: Dictionary = {}
	var planned_cache: Dictionary = {}
	var runtime_plan: Dictionary = {}
	var defer_runtime_plan_build: bool = (
		zero_frame_tail
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		var warm_runtime_raw: Variant = (
			gs.scenario_state.get(
				"warm_runtime_plan",
				{}
			)
		)
		var warm_runtime: Dictionary = (
			warm_runtime_raw as Dictionary
			if typeof(warm_runtime_raw) == TYPE_DICTIONARY
			else {}
		)

		var warm_year: int = int(
			warm_runtime.get(
				"year",
				-999999
			)
		)
		var warm_mode: String = str(
			warm_runtime.get(
				"mode",
				""
			)
		)
		var warm_player_id: int = int(
			warm_runtime.get(
				"player_id",
				-999999
			)
		)
		var warm_plan_raw: Variant = (
			warm_runtime.get(
				"plan",
				{}
			)
		)

		defer_runtime_plan_build = (
			defer_runtime_plan_build
			or bool(
				gs.scenario_state.get(
					"defer_runtime_plan_build",
					false
				)
			)
		)

		if (
			warm_year == int(
				active_year_context.get(
					"year",
					gs.year
				)
			)
			and warm_mode == str(
				active_year_context.get(
					"mode",
					"living"
				)
			)
			and warm_player_id == int(
				active_year_context.get(
					"player_id",
					player_id
				)
			)
			and typeof(warm_plan_raw) == TYPE_DICTIONARY
		):

			runtime_plan = (
				warm_plan_raw as Dictionary
			)
			active_year_context [
				"used_warm_runtime_plan"
			] = true
			active_year_context [
				"warm_runtime_plan_source"
			] = str(
				warm_runtime.get(
					"source",
					"warm_runtime_plan"
				)
			)
			active_year_context [
				"warm_runtime_plan_signature"
			] = str(
				warm_runtime.get(
					"signature",
					""
				)
			)

			gs.scenario_state.erase(
				"warm_runtime_plan"
			)
			gs.scenario_state [
				"defer_runtime_plan_build"
			] = false

		var speculative_raw: Variant = (
			gs.scenario_state.get(
				"speculative_next_year_cache",
				{}
			)
		)
		var speculative: Dictionary = (
			speculative_raw as Dictionary
			if typeof(speculative_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			bool(
				speculative.get(
					"ready",
					false
				)
			)
			and int(
				speculative.get(
					"year",
					-999999
				)
			) == int(
				active_year_context.get(
					"year",
					gs.year
				)
			)
			and int(
				speculative.get(
					"player_id",
					-999999
				)
			) == int(
				active_year_context.get(
					"player_id",
					player_id
				)
			)
		):

			active_year_context [
				"speculative_precompute_cache"
			] = speculative
			active_year_context [
				"used_speculative_precompute"
			] = true

			var marked_speculative: Dictionary = (
				speculative.duplicate(
					false
				)
			)
			marked_speculative ["used"] = true
			marked_speculative ["used_at_ms"] = int(
				Time.get_ticks_msec()
			)
			gs.scenario_state [
				"speculative_next_year_cache"
			] = marked_speculative

	if (
		runtime_plan.is_empty()
		and not zero_frame_tail
		and not defer_runtime_plan_build
		and gs != null
		and gs.simulation_director != null
		and gs.simulation_director.has_method(
			"build_runtime_plan"
		)
	):
		runtime_plan = (
			gs.simulation_director.build_runtime_plan({
				"year": int(
					active_year_context.get(
						"year",
						gs.year
					)
				),
				"mode": str(
					active_year_context.get(
						"mode",
						"living"
					)
				),
				"player_id": int(
					active_year_context.get(
						"player_id",
						player_id
					)
				),
				"runtime_owner": "age_up_runtime"
			})
		)

	var runtime_groups_raw: Variant = (
		runtime_plan.get(
			"runtime_groups",
			{}
		)
	)
	if (
		typeof(runtime_groups_raw) == TYPE_DICTIONARY
		and not (
			runtime_groups_raw as Dictionary
		).is_empty()
	):
		var runtime_groups: Dictionary = (
			runtime_groups_raw as Dictionary
		)
		planned_groups = {
			"near": (
				runtime_groups.get(
					"near",
					[]
				)
			),
			"mid": (
				runtime_groups.get(
					"mid",
					[]
				)
			),
			"far": (
				runtime_groups.get(
					"far",
					[]
				)
			)
		}
	else:
		var lane_groups_raw: Variant = (
			runtime_plan.get(
				"groups",
				{}
			)
		)
		if typeof(lane_groups_raw) == TYPE_DICTIONARY:
			var lane_groups: Dictionary = (
				lane_groups_raw as Dictionary
			)
			planned_groups = {
				"near": lane_groups.get(
					"lane_a",
					[]
				),
				"mid": lane_groups.get(
					"lane_b",
					[]
				),
				"far": lane_groups.get(
					"lane_c",
					[]
				)
			}

	var plan_cache_raw: Variant = (
		runtime_plan.get(
			"relevance_cache",
			{}
		)
	)
	if typeof(plan_cache_raw) == TYPE_DICTIONARY:
		planned_cache = (
			plan_cache_raw as Dictionary
		)

	var plan_mailboxes_raw: Variant = (
		runtime_plan.get(
			"mailboxes",
			{}
		)
	)
	if (
		typeof(plan_mailboxes_raw) == TYPE_DICTIONARY
		and not (
			plan_mailboxes_raw as Dictionary
		).is_empty()
	):
		active_mailboxes = (
			plan_mailboxes_raw as Dictionary
		)

	if not runtime_plan.is_empty():
		active_year_context [
			"quality_tier"
		] = str(
			runtime_plan.get(
				"quality_tier",
				QUALITY_BALANCED
			)
		)
		active_year_context [
			"hot_dormant_ids"
		] = runtime_plan.get(
			"lane_ids",
			{}
		).get(
			"lane_d",
			[]
		)
		active_year_context [
			"phase_order"
		] = runtime_plan.get(
			"phase_order",
			active_year_context.get(
				"phase_order",
				[]
			)
		)

	if planned_groups.is_empty():
		if not previous_groups.is_empty():
			planned_groups = {
				"near": previous_groups.get(
					"near",
					[]
				),
				"mid": previous_groups.get(
					"mid",
					[]
				),
				"far": previous_groups.get(
					"far",
					[]
				)
			}
			planned_cache = previous_relevance_cache
			active_year_context [
				"resident_runtime_groups_reused"
			] = true
		elif zero_frame_tail:



			planned_groups = {
				"near": [],
				"mid": [],
				"far": []
			}
			active_year_context [
				"resident_runtime_groups_cold"
			] = true
			active_year_context [
				"runtime_group_projection_pending"
			] = true
		else:
			planned_groups = (
				_classify_runtime_groups()
			)

	active_groups = planned_groups
	relevance_cache = planned_cache

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"runtime_prepared_scenario_setup"
		] = {}

	last_execution_report = {
		"year": int(
			active_year_context.get(
				"year",
				0
			)
		),
		"mode": str(
			active_year_context.get(
				"mode",
				"living"
			)
		),
		"quality_tier": str(
			active_year_context.get(
				"quality_tier",
				QUALITY_BALANCED
			)
		),
		"player_bubble_count": _group_size(
			"near"
		),
		"social_ring_count": _group_size(
			"mid"
		),
		"settlement_lane_count": _group_size(
			"far"
		),
		"dormant_count": (
			int(
				gs.dormant_npcs.size()
			)
			if gs != null
			else 0
		),
		"phase_order": active_year_context.get(
			"phase_order",
			[]
		),
		"phase_timings_ms": {},
		"promotions": [],
		"deferred_jobs": [],
		"skipped_workloads": [],
		"generated_world_feed_entries": 0,
		"generated_popups": 0,
		"generated_scenarios": 0,
		"zero_frame_tail": zero_frame_tail,
	}

	return active_year_context.duplicate(
		false
	)

func advance_year_and_handle_era_shift(actor_for_narrative: Person = null) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var time_contract_raw: Variant = gs.scenario_state.get("age_up_time_contract", {})
	var time_contract: Dictionary = time_contract_raw if typeof(time_contract_raw) == TYPE_DICTIONARY else {}

	var source_year: int = int(time_contract.get("source_year", gs.scenario_state.get("age_up_started_from_year", gs.year)))
	var source_age: int = int(time_contract.get("source_age", gs.scenario_state.get("age_up_started_from_age", gs.player.age if gs.player != null else 0)))
	var target_year: int = int(time_contract.get("target_year", gs.scenario_state.get("age_up_requested_year", source_year + 1)))
	var target_age: int = int(time_contract.get("target_age", gs.scenario_state.get("age_up_truth_expected_target_age", source_age + 1)))

	if target_year <= source_year:
		target_year = source_year + 1

	if target_age <= source_age:
		target_age = source_age + 1

	if active_year_context.is_empty():
		begin_year_transaction({
			"mode": "living",
			"year": target_year,
			"player_id": int(gs.player.id) if gs.player != null else -1,
			"runtime_owner": "age_up_runtime_engine",
			"time_contract": time_contract.duplicate(true),
			"contract_source_year": source_year,
			"contract_target_year": target_year,
			"contract_source_age": source_age,
			"contract_target_age": target_age
		})
	else:
		active_year_context ["year"] = target_year
		active_year_context ["committed_year"] = target_year
		active_year_context ["contract_source_year"] = source_year
		active_year_context ["contract_target_year"] = target_year
		active_year_context ["contract_source_age"] = source_age
		active_year_context ["contract_target_age"] = target_age
		active_year_context ["time_contract"] = time_contract.duplicate(true)

	var safety_steps: int = 0
	var max_safety_steps: int = 24

	while safety_steps < max_safety_steps:
		var step_result: Dictionary = _step_year_and_era_mutation_walker(actor_for_narrative)
		if bool(step_result.get("is_complete", false)):
			if not gs.year_locked:
				gs.year = target_year

			if gs.player != null:
				gs.player.age = target_age

			active_year_context ["year"] = target_year
			active_year_context ["committed_year"] = target_year
			active_year_context ["completed_year"] = target_year
			active_year_context ["completed_player_age"] = target_age
			active_year_context ["time_contract_committed"] = true
			return

		safety_steps += 1

	if not gs.year_locked:
		gs.year = target_year

	if gs.player != null:
		gs.player.age = target_age

	gs.scenario_state ["runtime_guard"] = {
		"compressed_execution_current_year": true,
		"auto_stability_mode": true,
		"defer_noncritical_systems": true,
		"phase_budget_cap": 1,
		"commit_budget_cap": 4,
		"applies_to_year": target_year,
		"fault_source": "advance_year_and_handle_era_shift",
		"time_authority": "age_up_time_contract",
		"source_year": source_year,
		"target_year": target_year,
		"source_age": source_age,
		"target_age": target_age
	}
func _apply_runtime_active_npc_biological_year(
	target_year: int
) -> Dictionary:
	var report: Dictionary = {
		"year": target_year,
		"already_applied": false,
		"aged_active_npcs": 0,
		"corrected_overadvanced_npcs": 0,
		"world_feed_before": (
			int(
				gs.world_feed.size()
			)
			if (
				gs != null
				and "world_feed" in gs
			)
			else 0
		),
		"world_feed_after": (
			int(
				gs.world_feed.size()
			)
			if (
				gs != null
				and "world_feed" in gs
			)
			else 0
		),
		"event_count": 0,
		"death_checks": 0,
		"deferred_to_core_state_resolution": true,
		"reason": (
			"bounded_world_engine_age_npcs_priority_quantum"
		),
		"population_iteration_performed": false,
		"blocks_ui": false,
		"idle_required": false
	}

	if gs == null:
		return report

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if (
		gs.world_engine == null
		or not gs.world_engine.has_method(
			"run_world_contract_task"
		)
	):
		report [
			"reason"
		] = "world_engine_biological_authority_unavailable"

		report [
			"authority_available"
		] = false

		return report

	var time_contract_raw: Variant = (
		gs.scenario_state.get(
			"age_up_time_contract",
			{}
		)
	)

	var time_contract: Dictionary = (
		time_contract_raw as Dictionary
		if typeof(
			time_contract_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var source_year: int = int(
		time_contract.get(
			"source_year",
			target_year - 1
		)
	)

	var priority_relationship_count_hint: int = 0

	if gs.player != null:
		if gs.player.partner != null:
			priority_relationship_count_hint += 1

		priority_relationship_count_hint += (
			gs.player.parents.size()
			+ gs.player.children.size()
			+ gs.player.friends.size()
			+ gs.player.ex_partners.size()
			+ gs.player.schoolmates.size()
		)

	var zero_frame_tail: bool = bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	)
	var transaction_player_id: int = int(
		active_year_context.get(
			"player_id",
			time_contract.get(
				"player_id",
				(
					int(
						gs.player.id
					)
					if gs.player != null
					else -1
				)
			)
		)
	)
	var runtime_context: Dictionary = {
		"year": target_year,
		"contract_source_year": source_year,
		"player_id": transaction_player_id,
		"time_contract": time_contract.duplicate(false),
		"bounded_runtime": true,



		"runtime_item_budget": (
			12
			if zero_frame_tail
			else 96
		),
		"runtime_time_budget_ms": (
			1
			if zero_frame_tail
			else 2
		),
		"runtime_phase": "year_and_era_mutation",
		"runtime_owner": "age_up_runtime",
		"zero_frame_tail": zero_frame_tail,
		"ui_concurrent": true,
		"idle_required": false,
		"blocks_ui": false
	}

	var world_task_report: Dictionary = (
		gs.world_engine.run_world_contract_task(
			"age_npcs",
			runtime_context
		)
	)

	var bounded_result_raw: Variant = (
		world_task_report.get(
			"result",
			{}
		)
	)

	var bounded_result: Dictionary = (
		bounded_result_raw as Dictionary
		if typeof(
			bounded_result_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var processed_this_quantum: int = int(
		bounded_result.get(
			"processed_this_quantum",
			0
		)
	)

	var quantum_ran: bool = bool(
		world_task_report.get(
			"ran",
			false
		)
	)

	report [
		"authority_available"
	] = true

	report [
		"world_task_report"
	] = world_task_report.duplicate(false)

	report [
		"processed_this_quantum"
	] = processed_this_quantum

	report [
		"population_iteration_performed"
	] = (
		processed_this_quantum > 0
	)

	report [
		"relationship_priority_count_hint"
	] = priority_relationship_count_hint

	report [
		"relationship_priority_quantum_serviced"
	] = (
		quantum_ran
		and priority_relationship_count_hint > 0
	)

	report [
		"world_age_task_complete"
	] = bool(
		bounded_result.get(
			"is_complete",
			world_task_report.get(
				"is_complete",
				false
			)
		)
	)

	report [
		"world_age_task_progress"
	] = float(
		bounded_result.get(
			"progress",
			world_task_report.get(
				"progress",
				0.0
			)
		)
	)

	report [
		"deferred_to_core_state_resolution"
	] = not bool(
		report.get(
			"world_age_task_complete",
			false
		)
	)

	report [
		"world_feed_after"
	] = (
		int(
			gs.world_feed.size()
		)
		if "world_feed" in gs
		else 0
	)

	if bool(
		report.get(
			"relationship_priority_quantum_serviced",
			false
		)
	):
		gs.scenario_state [
			"age_up_relationship_priority_biology_quantum_year"
		] = target_year

		gs.scenario_state [
			"age_up_relationship_priority_biology_source_year"
		] = source_year

		gs.scenario_state [
			"age_up_relationship_priority_biology_quantum_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		gs.scenario_state [
			"age_up_relationship_priority_biology_quantum_report"
		] = report.duplicate(false)

	if typeof(
		active_year_context
	) == TYPE_DICTIONARY:
		active_year_context [
			"active_npc_biological_year_deferred_to_core"
		] = bool(
			report.get(
				"deferred_to_core_state_resolution",
				true
			)
		)

		active_year_context [
			"active_npc_biological_year_target"
		] = target_year

		active_year_context [
			"active_npc_biological_year_count"
		] = processed_this_quantum

		active_year_context [
			"active_npc_biological_year_priority_first"
		] = true

		active_year_context [
			"active_npc_biological_year_world_task_progress"
		] = float(
			report.get(
				"world_age_task_progress",
				0.0
			)
		)

	return report
func _install_visible_age_up_runtime_bus_guard(
	current_phase: String,
	reason: String
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var guard_raw: Variant = gs.scenario_state.get(
		"runtime_guard",
		{}
	)
	var guard: Dictionary = (
		guard_raw
		if typeof(guard_raw) == TYPE_DICTIONARY
		else {}
	)




	guard ["defer_noncritical_systems"] = false
	guard ["ui_tail_work_yield_to_input"] = false
	guard ["continuous_reality_service"] = true
	guard ["ui_activity_is_scheduler_input"] = false
	guard ["idle_required"] = false
	guard ["reduce_scenario_density"] = bool(
		guard.get(
			"reduce_scenario_density",
			false
		)
	)
	guard ["compressed_execution_current_year"] = bool(
		guard.get(
			"compressed_execution_current_year",
			false
		)
	)
	guard ["auto_stability_mode"] = bool(
		guard.get(
			"auto_stability_mode",
			false
		)
	)
	guard ["control_release_priority"] = "continuous_reality"
	guard ["phase_budget_cap"] = max(
		2,
		int(
			guard.get(
				"phase_budget_cap",
				2
			)
		)
	)
	guard ["commit_budget_cap"] = max(
		18,
		int(
			guard.get(
				"commit_budget_cap",
				18
			)
		)
	)
	guard ["stall_recovery_threshold"] = max(
		18,
		int(
			guard.get(
				"stall_recovery_threshold",
				18
			)
		)
	)
	guard ["applies_to_year"] = int(
		active_year_context.get(
			"year",
			gs.year
		)
	)
	guard ["current_phase"] = current_phase
	guard ["last_visible_runtime_guard_reason"] = reason
	guard ["last_visible_runtime_guard_ms"] = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state ["runtime_guard"] = guard
func _age_up_runtime_year_label(
	year_value: int
) -> String:
	if year_value < 0:
		return "%d BCE" % abs(
			year_value
		)

	if year_value <= 1000:
		return "%d AD" % year_value

	return str(
		year_value
	)
func _step_year_and_era_mutation_walker(
	actor_for_narrative: Person = null
) -> Dictionary:
	if gs == null:
		return _build_phase_step_result(
			"year_and_era_mutation",
			"idle",
			true,
			1.0
		)

	if bool(
		active_year_context.get(
			"year_and_era_mutation_complete",
			false
		)
	):
		return _build_phase_step_result(
			"year_and_era_mutation",
			"complete",
			true,
			1.0
		)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var time_contract_raw: Variant = (
		gs.scenario_state.get(
			"age_up_time_contract",
			{}
		)
	)

	var time_contract: Dictionary = (
		time_contract_raw
		if typeof(
			time_contract_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var contract_source_year: int = int(
		time_contract.get(
			"source_year",
			gs.scenario_state.get(
				"age_up_started_from_year",
				gs.year
			)
		)
	)

	var contract_target_year: int = int(
		time_contract.get(
			"target_year",
			gs.scenario_state.get(
				"age_up_requested_year",
				contract_source_year + 1
			)
		)
	)

	var contract_source_age: int = int(
		time_contract.get(
			"source_age",
			gs.scenario_state.get(
				"age_up_started_from_age",
				(
					gs.player.age
					if gs.player != null
					else 0
				)
			)
		)
	)

	var contract_target_age: int = int(
		time_contract.get(
			"target_age",
			gs.scenario_state.get(
				"age_up_truth_expected_target_age",
				contract_source_age + 1
			)
		)
	)

	if contract_target_year <= contract_source_year:
		contract_target_year = (
			contract_source_year + 1
		)

	if contract_target_age <= contract_source_age:
		contract_target_age = (
			contract_source_age + 1
		)

	var state: Dictionary = _get_phase_walker_state(
		"year_and_era_mutation",
		{
			"micro_lane_cursor": 0,
			"target_player_id": int(
				active_year_context.get(
					"player_id",
					(
						gs.player.id
						if gs.player != null
						else -1
					)
				)
			),
			"aged_player_id": int(
				active_year_context.get(
					"aged_player_id",
					-1
				)
			),
			"aged_player_year": int(
				active_year_context.get(
					"aged_player_year",
					-999999
				)
			),
			"previous_era_name": "",
			"current_era_name": "",
			"did_era_shift": false,
			"active_npc_biological_tick": {},
			"committed_year": int(
				active_year_context.get(
					"committed_year",
					gs.year
				)
			),
			"contract_source_year": contract_source_year,
			"contract_target_year": contract_target_year,
			"contract_source_age": contract_source_age,
			"contract_target_age": contract_target_age
		}
	)

	var lane_cursor: int = int(
		state.get(
			"micro_lane_cursor",
			0
		)
	)

	var lane_name: String = "complete"
	var total_lanes: float = 8.0

	match lane_cursor:
		0:
			lane_name = "phase_bootstrap"

			state ["target_player_id"] = int(
				active_year_context.get(
					"player_id",
					(
						gs.player.id
						if gs.player != null
						else -1
					)
				)
			)

			state ["aged_player_id"] = int(
				active_year_context.get(
					"aged_player_id",
					-1
				)
			)

			state ["aged_player_year"] = int(
				active_year_context.get(
					"aged_player_year",
					-999999
				)
			)

			state ["previous_era_name"] = (
				str(
					gs.era.name
				)
				if gs.era != null
				else ""
			)

			state ["current_era_name"] = ""
			state ["did_era_shift"] = false
			state ["active_npc_biological_tick"] = {}

			state ["committed_year"] = int(
				active_year_context.get(
					"committed_year",
					gs.year
				)
			)

			state ["contract_source_year"] = contract_source_year
			state ["contract_target_year"] = contract_target_year
			state ["contract_source_age"] = contract_source_age
			state ["contract_target_age"] = contract_target_age
			state ["micro_lane_cursor"] = 1

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				1.0 / total_lanes
			)

		1:
			lane_name = "year_increment"

			var requested_year: int = int(
				state.get(
					"contract_target_year",
					contract_target_year
				)
			)

			if not gs.year_locked:
				gs.year = requested_year
			else:
				requested_year = int(
					gs.year
				)

			active_year_context [
				"year"
			] = int(
				gs.year
			)

			active_year_context [
				"committed_year"
			] = int(
				gs.year
			)

			active_year_context [
				"contract_source_year"
			] = contract_source_year

			active_year_context [
				"contract_target_year"
			] = contract_target_year

			state ["committed_year"] = int(
				gs.year
			)

			state ["micro_lane_cursor"] = 2

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				2.0 / total_lanes
			)

		2:
			lane_name = "player_age_increment"

			var target_player_id: int = int(
				state.get(
					"target_player_id",
					-1
				)
			)

			var target_year: int = int(
				active_year_context.get(
					"year",
					gs.year
				)
			)

			var target_age: int = int(
				state.get(
					"contract_target_age",
					contract_target_age
				)
			)

			var aged_player_year: int = int(
				state.get(
					"aged_player_year",
					active_year_context.get(
						"aged_player_year",
						-999999
					)
				)
			)

			if (
				target_player_id > 0
				and aged_player_year != target_year
			):
				var turn_subject: Person = null

				if (
					gs.player != null
					and int(
						gs.player.id
					) == target_player_id
				):
					turn_subject = gs.player
				else:
					turn_subject = (
						gs.get_or_reactivate_npc_by_id(
							target_player_id
						)
					)

				if (
					turn_subject != null
					and turn_subject.alive
				):
					turn_subject.age = target_age

				active_year_context [
					"aged_player_id"
				] = target_player_id

				active_year_context [
					"aged_player_year"
				] = target_year

				active_year_context [
					"completed_player_age"
				] = target_age

				state [
					"aged_player_id"
				] = target_player_id

				state [
					"aged_player_year"
				] = target_year

			state ["micro_lane_cursor"] = 3

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				3.0 / total_lanes
			)

		3:
			lane_name = "active_npc_biological_year"

			var biological_report: Dictionary = (
				_apply_runtime_active_npc_biological_year(
					int(
						gs.year
					)
				)
			)

			state [
				"active_npc_biological_tick"
			] = biological_report

			active_year_context [
				"active_npc_biological_tick"
			] = biological_report.duplicate(
				true
			)

			_queue_mailbox(
				"mutation",
				{
					"type": "active_npc_biological_year",
					"year": int(
						gs.year
					),
					"report": biological_report.duplicate(
						true
					)
				}
			)

			state ["micro_lane_cursor"] = 4

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				4.0 / total_lanes
			)

		4:
			lane_name = "year_passed_emit"

			_install_visible_age_up_runtime_bus_guard(
				"year_and_era_mutation",
				"before_year_passed_emit"
			)

			_queue_mailbox(
				"mutation",
				{
					"type": "year_advanced",
					"year": int(
						gs.year
					),
					"active_npc_biological_tick": state.get(
						"active_npc_biological_tick",
						{}
					)
				}
			)







			gs.push_world_feed(
				"The world entered %s."
				% _age_up_runtime_year_label(
					int(
						gs.year
					)
				),
				{
					"category": "world",
					"event_name": "year_advanced",
					"source": "age_up_runtime.year_and_era_mutation",
					"year": int(
						gs.year
					),
					"runtime_managed": true,
					"runtime_owner": "age_up_runtime",
					"truth_owner": "age_up_time_contract",
					"ui_is_renderer_only": true,
					"blocks_ui": false
				}
			)

			if gs.event_bus != null:
				gs.event_bus.emit(
					ActionEventTypes.YEAR_PASSED,
					{
						"year": int(
							gs.year
						),
						"runtime_phase": "year_and_era_mutation",
						"runtime_managed": true,
						"runtime_owner": "age_up_runtime",
						"active_npc_biological_tick": state.get(
							"active_npc_biological_tick",
							{}
						),
						"qos_tier": "ambient",
						"fanout_priority": "low",
						"event_batch_key": (
							"runtime_year_passed|%d"
							% int(
								gs.year
							)
						),
						"fanout_hints": {
							"force_defer_bus": true,
							"event_batch_key": (
								"runtime_year_passed|%d"
								% int(
									gs.year
								)
							),
							"allow_partial_propagation": true,
							"skip_llm_bridge": true,
							"skip_npc_memory_web": true,
							"skip_agent_memory_propagation": true
						}
					}
				)

			state ["micro_lane_cursor"] = 5

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				5.0 / total_lanes
			)

		5:
			lane_name = "era_resolve"

			var previous_era_name: String = str(
				state.get(
					"previous_era_name",
					""
				)
			)

			var era_after = (
				gs.era_engine._era_from_year(
					gs.year
				)
			)

			state ["current_era_name"] = str(
				era_after.name
			)

			state ["did_era_shift"] = (
				str(
					era_after.name
				) != previous_era_name
			)

			if bool(
				state.get(
					"did_era_shift",
					false
				)
			):
				gs.era = era_after

			state ["micro_lane_cursor"] = 6

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				6.0 / total_lanes
			)

		6:
			lane_name = "era_shift_emit"

			if bool(
				state.get(
					"did_era_shift",
					false
				)
			):
				_install_visible_age_up_runtime_bus_guard(
					"year_and_era_mutation",
					"before_era_shift_emit"
				)

				var current_era_name: String = str(
					state.get(
						"current_era_name",
						""
					)
				)

				_queue_mailbox(
					"mutation",
					{
						"type": "era_shift",
						"year": int(
							gs.year
						),
						"era": current_era_name
					}
				)

				if gs.event_bus != null:
					gs.event_bus.emit(
						ActionEventTypes.ERA_SHIFT,
						{
							"era": current_era_name,
							"runtime_phase": "year_and_era_mutation",
							"runtime_managed": true,
							"runtime_owner": "age_up_runtime",
							"qos_tier": "ambient",
							"fanout_priority": "low",
							"event_batch_key": (
								"runtime_era_shift|%d|%s"
								% [
									int(
										gs.year
									),
									current_era_name
								]
							),
							"fanout_hints": {
								"force_defer_bus": true,
								"event_batch_key": (
									"runtime_era_shift|%d|%s"
									% [
										int(
											gs.year
										),
										current_era_name
									]
								),
								"allow_partial_propagation": true,
								"skip_llm_bridge": true,
								"skip_npc_memory_web": true,
								"skip_agent_memory_propagation": true
							}
						}
					)

			state ["micro_lane_cursor"] = 7

			_set_phase_walker_state(
				"year_and_era_mutation",
				state
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				false,
				7.0 / total_lanes
			)

		7:
			lane_name = "era_shift_narrative"

			if bool(
				state.get(
					"did_era_shift",
					false
				)
			):
				var current_era_name: String = str(
					state.get(
						"current_era_name",
						""
					)
				)

				if gs.world_chronicle_engine != null:
					gs.world_chronicle_engine.log(
						"The world entered the %s."
						% current_era_name
					)

				if actor_for_narrative != null:
					gs.narrative_engine.log_event(
						actor_for_narrative,
						{
							"type": "era_shift",
							"text": (
								"As I turned %d, the world entered the %s."
								% [
									actor_for_narrative.age,
									current_era_name
								]
							)
						}
					)

			active_year_context [
				"year_and_era_mutation_complete"
			] = true

			active_year_context [
				"completed_year"
			] = int(
				gs.year
			)

			active_year_context [
				"completed_player_age"
			] = (
				int(
					gs.player.age
				)
				if gs.player != null
				else -1
			)

			_clear_phase_walker_state(
				"year_and_era_mutation"
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				lane_name,
				true,
				1.0
			)

		_:
			active_year_context [
				"year_and_era_mutation_complete"
			] = true

			active_year_context [
				"completed_year"
			] = int(
				gs.year
			)

			active_year_context [
				"completed_player_age"
			] = (
				int(
					gs.player.age
				)
				if gs.player != null
				else -1
			)

			_clear_phase_walker_state(
				"year_and_era_mutation"
			)

			return _build_phase_step_result(
				"year_and_era_mutation",
				"complete",
				true,
				1.0
			)
func _queue_deferred_runtime_tail_phase(phase_name: String) -> void:
	if phase_name == "" or gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var tail_raw: Variant = gs.scenario_state.get("deferred_runtime_tail_phases", [])
	var tail: Array = tail_raw if typeof(tail_raw) == TYPE_ARRAY else []
	var active_year: int = int(active_year_context.get("year", gs.year))

	for raw_entry in tail:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("phase", "")) == phase_name and int(entry.get("year", -1)) == active_year:
			return

	tail.append({
		"phase": phase_name,
		"year": active_year,
		"deferred_by": "auto_stability_mode"
	})
	gs.scenario_state ["deferred_runtime_tail_phases"] = tail
func run_year_runtime() -> Dictionary:
	if gs == null:
		return {}

	if active_year_context.is_empty():
		begin_year_transaction({
			"mode": "living",
			"year": int(gs.year),
			"player_id": int(gs.player.id) if gs.player != null else -1
		})

	if active_groups.is_empty():
		active_groups = _classify_runtime_groups()

	var started_at: int = Time.get_ticks_msec()
	var phase_timings: Dictionary = {}
	var before_snapshot: Dictionary = _capture_snapshot(active_groups)

	var phase_started: int = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "core_state_resolution"
	_run_core_state_resolution()
	_execute_registered_phase_bridge("core_state_resolution")
	phase_timings ["core_state_resolution"] = int(Time.get_ticks_msec() - phase_started)

	phase_started = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "internal_identity_drift"
	_run_internal_identity_drift()
	_execute_registered_phase_bridge("internal_identity_drift")
	phase_timings ["internal_identity_drift"] = int(Time.get_ticks_msec() - phase_started)

	phase_started = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "data_defined_simulation_laws"
	_run_data_defined_simulation_laws()
	_execute_registered_phase_bridge("data_defined_simulation_laws")
	phase_timings ["data_defined_simulation_laws"] = int(Time.get_ticks_msec() - phase_started)

	phase_started = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "player_phase_contract"
	_run_player_phase_contract()
	_execute_registered_phase_bridge("player_phase_contract")
	phase_timings ["player_phase_contract"] = int(Time.get_ticks_msec() - phase_started)

	phase_started = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "choice_and_opportunity_surfacing"
	_run_choice_and_opportunity_surfacing()
	_execute_registered_phase_bridge("choice_and_opportunity_surfacing")
	phase_timings ["choice_and_opportunity_surfacing"] = int(Time.get_ticks_msec() - phase_started)

	phase_started = Time.get_ticks_msec()
	active_year_context ["current_phase"] = "narrative_and_presentation"
	_run_narrative_and_presentation()
	_execute_registered_phase_bridge("narrative_and_presentation")
	phase_timings ["narrative_and_presentation"] = int(Time.get_ticks_msec() - phase_started)

	var after_snapshot: Dictionary = _capture_snapshot(active_groups)
	var direct_packets: Array = _collect_direct_delta_packets()
	last_delta_packets = _build_delta_packets(before_snapshot, after_snapshot, direct_packets)
	active_mailboxes ["delta_packets"] = last_delta_packets.duplicate(true)

	last_execution_report ["phase_order"] = [
		"core_state_resolution",
		"internal_identity_drift",
		"data_defined_simulation_laws",
		"player_phase_contract",
		"choice_and_opportunity_surfacing",
		"narrative_and_presentation"
	]
	last_execution_report ["phase_timings_ms"] = phase_timings.duplicate(true)
	last_execution_report ["total_runtime_ms"] = int(Time.get_ticks_msec() - started_at)
	last_execution_report ["generated_world_feed_entries"] = int(active_mailboxes.get("world_feed", []).size())
	last_execution_report ["generated_popups"] = int(active_mailboxes.get("popups", []).size())
	last_execution_report ["generated_scenarios"] = int(active_mailboxes.get("scenario", []).size())
	last_execution_report ["phase_mailboxes"] = active_mailboxes.duplicate(true)
	last_execution_report ["delta_packet_count"] = int(last_delta_packets.size())

	if gs.scenario_state != null:
		gs.scenario_state ["last_runtime_report"] = last_execution_report.duplicate(true)
		gs.scenario_state ["last_runtime_delta_packets"] = last_delta_packets.duplicate(true)

		var stored_result_raw: Variant = gs.scenario_state.get("post_runtime_result", {})
		if typeof(stored_result_raw) == TYPE_DICTIONARY and not stored_result_raw.is_empty():
			var stored_result: Dictionary = stored_result_raw.duplicate(true)
			stored_result ["runtime_report"] = last_execution_report.duplicate(true)
			gs.scenario_state ["post_runtime_result"] = stored_result

	return last_execution_report.duplicate(true)

func get_last_execution_report() -> Dictionary:
	return last_execution_report.duplicate(true)
func _runtime_phase_domain_tasks(
	phase_id: String,
	fallback_tasks: Array = []
) -> Array:
	var contract: Dictionary = _phase_contract_for(
		phase_id
	)
	var tasks_raw: Variant = contract.get(
		"runtime_tasks",
		contract.get(
			"domain_tasks",
			[]
		)
	)
	var tasks: Array = (
		tasks_raw as Array
		if typeof(tasks_raw) == TYPE_ARRAY
		else []
	)

	if tasks.is_empty():
		tasks = fallback_tasks

	var out: Array = []

	for raw_task in tasks:
		if typeof(raw_task) != TYPE_DICTIONARY:
			continue

		var task: Dictionary = (
			raw_task as Dictionary
		)

		if not bool(
			task.get(
				"enabled",
				true
			)
		):
			continue

		out.append(
			task.duplicate(
				false
			)
		)

	out.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			if (
				typeof(left_raw) != TYPE_DICTIONARY
				or typeof(right_raw) != TYPE_DICTIONARY
			):
				return false

			var left: Dictionary = (
				left_raw as Dictionary
			)
			var right: Dictionary = (
				right_raw as Dictionary
			)

			return int(
				left.get(
					"order",
					left.get(
						"priority",
						100
					)
				)
			) < int(
				right.get(
					"order",
					right.get(
						"priority",
						100
					)
				)
			)
	)

	return out
func _runtime_phase_task_context(
	phase_id: String,
	extra: Dictionary = {}
) -> Dictionary:


	var context: Dictionary = (
		active_year_context.duplicate(
			false
		)
	)

	context ["runtime_phase"] = phase_id
	context ["current_phase"] = phase_id
	context ["runtime_owner"] = str(
		context.get(
			"runtime_owner",
			"age_up_runtime"
		)
	)
	context ["year"] = int(
		context.get(
			"year",
			gs.year if gs != null else 0
		)
	)
	context ["player_id"] = int(
		context.get(
			"player_id",
			(
				gs.player.id
				if (
					gs != null
					and gs.player != null
				)
				else -1
			)
		)
	)
	context ["bounded_runtime"] = true
	context ["runtime_item_budget"] = 96
	context ["runtime_time_budget_ms"] = 2
	context ["ui_may_preempt_between_quanta"] = false
	context ["ui_activity_is_scheduler_input"] = false
	context ["continuous_reality_service"] = true
	context ["blocks_ui"] = false

	for key in extra.keys():
		context [key] = extra [key]

	var zero_frame_tail: bool = bool(
		context.get(
			"zero_frame_tail",
			false
		)
	)





	if zero_frame_tail:
		context ["runtime_item_budget"] = mini(
			12,
			maxi(
				1,
				int(
					context.get(
						"runtime_item_budget",
						12
					)
				)
			)
		)
		context ["runtime_time_budget_ms"] = 1
		context [
			"intrinsic_zero_frame_quantum_cap"
		] = true
		context [
			"zero_frame_quantum_item_cap"
		] = 12
		context [
			"zero_frame_quantum_time_cap_ms"
		] = 1

	return context
func _engine_instance_for_runtime_task(engine_id: String):
	if gs == null:
		return null

	var clean_id: String = str(engine_id).strip_edges()
	if clean_id == "":
		return null

	if gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("get_engine_instance"):
		var from_contract = gs.game_state_contract_engine.get_engine_instance(clean_id)
		if from_contract != null:
			return from_contract

	var from_property = gs.get(clean_id)
	if from_property != null:
		return from_property

	return null

func _execute_runtime_domain_task(
	task: Dictionary,
	phase_id: String,
	extra_context: Dictionary = {}
) -> Dictionary:
	var engine_id: String = str(
		task.get(
			"engine_id",
			task.get(
				"target_engine_id",
				""
			)
		)
	).strip_edges()

	var dispatch: String = str(
		task.get(
			"dispatch",
			"engine_method"
		)
	).strip_edges().to_lower()

	var required_for_completion: bool = bool(
		task.get(
			"required",
			false
		)
	)

	var context: Dictionary = _runtime_phase_task_context(
		phase_id,
		extra_context
	)
	context ["runtime_task_id"] = str(
		task.get(
			"id",
			""
		)
	)
	context ["runtime_task_dispatch"] = dispatch

	var report: Dictionary = {
		"schema": "eralife.age_up_runtime_domain_task_report",
		"phase": phase_id,
		"task_id": str(
			task.get(
				"id",
				""
			)
		),
		"engine_id": engine_id,
		"dispatch": dispatch,
		"ran": false,
		"skipped": false,
		"failed": false,
		"reason": "",
		"is_complete": true,
		"progress": 1.0,
		"required_for_completion": required_for_completion,
		"completion_blocked": false,
		"blocks_ui": false
	}

	if engine_id == "":
		report ["failed"] = true
		report ["reason"] = "missing_engine_id"

		if required_for_completion:
			report ["is_complete"] = false
			report ["progress"] = 0.0
			report ["completion_blocked"] = true

		return report

	var engine = _engine_instance_for_runtime_task(
		engine_id
	)

	if engine == null:
		report ["failed"] = true
		report ["reason"] = "missing_engine:%s" % engine_id

		if required_for_completion:
			report ["is_complete"] = false
			report ["progress"] = 0.0
			report ["completion_blocked"] = true

		return report

	var result: Variant = null

	match dispatch:
		"world_contract_task":
			if engine.has_method(
				"run_world_contract_listener"
			):
				result = engine.run_world_contract_listener(
					task,
					context
				)
			else:
				var world_task_id: String = str(
					task.get(
						"task_id",
						task.get(
							"id",
							""
						)
					)
				).strip_edges()

				if engine.has_method(
					"run_world_contract_task"
				):
					result = engine.run_world_contract_task(
						world_task_id,
						context
					)
				else:
					report ["failed"] = true
					report ["reason"] = (
						"world_engine_missing_contract_task_runner"
					)

					if required_for_completion:
						report ["is_complete"] = false
						report ["progress"] = 0.0
						report ["completion_blocked"] = true

					return report

		"life_contract_task":
			if engine.has_method(
				"run_life_contract_listener"
			):
				result = engine.run_life_contract_listener(
					task,
					context
				)
			else:
				var life_task_id: String = str(
					task.get(
						"task_id",
						task.get(
							"id",
							""
						)
					)
				).strip_edges()

				if engine.has_method(
					"run_life_contract_task"
				):
					result = engine.run_life_contract_task(
						life_task_id,
						context
					)
				else:
					report ["failed"] = true
					report ["reason"] = (
						"life_engine_missing_contract_task_runner"
					)

					if required_for_completion:
						report ["is_complete"] = false
						report ["progress"] = 0.0
						report ["completion_blocked"] = true

					return report

		_:
			var method_name: String = str(
				task.get(
					"method",
					task.get(
						"callback",
						""
					)
				)
			).strip_edges()

			if method_name == "":
				method_name = str(
					task.get(
						"task_id",
						""
					)
				).strip_edges()

			if (
				method_name == ""
				or not engine.has_method(
					method_name
				)
			):
				report ["failed"] = true
				report ["reason"] = (
					"missing_method:%s"
					% method_name
				)

				if required_for_completion:
					report ["is_complete"] = false
					report ["progress"] = 0.0
					report ["completion_blocked"] = true

				return report

			if bool(
				task.get(
					"passes_context",
					false
				)
			):
				result = engine.callv(
					method_name,
					[
						context
					]
				)
			else:
				result = engine.call(
					method_name
				)

	report ["ran"] = true

	var execution_model: String = str(
		task.get(
			"execution_model",
			""
		)
	).strip_edges().to_lower()

	if execution_model == "":
		execution_model = str(
			task.get(
				"yearly_execution_model",
				"legacy_unclassified"
			)
		).strip_edges().to_lower()

	report ["execution_model"] = execution_model

	if execution_model == "incremental":
		if typeof(result) != TYPE_DICTIONARY:
			report ["failed"] = true
			report ["reason"] = (
				"incremental_yearly_task_missing_dictionary_result"
			)
			report ["contract_violation"] = true
			report ["quarantined"] = true
			report ["is_complete"] = not required_for_completion
			report ["progress"] = (
				1.0
				if not required_for_completion
				else 0.0
			)
			report ["completion_blocked"] = required_for_completion
			return report

		var incremental_result: Dictionary = (
			result as Dictionary
		)

		if (
			not incremental_result.has(
				"is_complete"
			)
			or not incremental_result.has(
				"progress"
			)
		):
			report ["failed"] = true
			report ["reason"] = (
				"incremental_yearly_task_missing_is_complete_or_progress"
			)
			report ["contract_violation"] = true
			report ["quarantined"] = true
			report ["result"] = (
				incremental_result.duplicate(false)
			)
			report ["is_complete"] = not required_for_completion
			report ["progress"] = (
				1.0
				if not required_for_completion
				else 0.0
			)
			report ["completion_blocked"] = required_for_completion

			EraLog.truth(
				(
					"ERALIFE_YEARLY_TASK_CONTRACT_VIOLATION"
					+ "|task_id=%s"
					+ "|phase=%s"
					+ "|execution_model=incremental"
					+ "|reason=missing_progress_contract"
					+ "|quarantined=true"
					+ "|required=%s"
					+ "|at_ms=%d"
				) % [
					str(
						task.get(
							"id",
							""
						)
					),
					phase_id,
					str(
						required_for_completion
					),
					int(
						Time.get_ticks_msec()
					)
				]
			)
			return report

		report ["result"] = (
			incremental_result.duplicate(false)
		)
		report ["is_complete"] = bool(
			incremental_result.get(
				"is_complete",
				false
			)
		)
		report ["progress"] = clampf(
			float(
				incremental_result.get(
					"progress",
					0.0
				)
			),
			0.0,
			1.0
		)

		var task_failed: bool = bool(
			incremental_result.get(
				"failed",
				false
			)
		)

		var task_skipped: bool = bool(
			incremental_result.get(
				"skipped",
				false
			)
		)

		var nested_raw: Variant = incremental_result.get(
			"result",
			{}
		)
		var nested: Dictionary = (
			nested_raw as Dictionary
			if typeof(nested_raw) == TYPE_DICTIONARY
			else {}
		)

		if not nested.is_empty():
			if bool(
				nested.get(
					"failed",
					false
				)
			):
				task_failed = true

			if (
				nested.has(
					"success"
				)
				and not bool(
					nested.get(
						"success",
						false
					)
				)
			):
				task_failed = true

			if (
				nested.has(
					"supported"
				)
				and not bool(
					nested.get(
						"supported",
						true
					)
				)
			):
				task_failed = true

		if (
			task_failed
			or (
				required_for_completion
				and task_skipped
			)
		):
			report ["failed"] = true

			if str(
				report.get(
					"reason",
					""
				)
			).strip_edges() == "":
				var nested_reason: String = str(
					nested.get(
						"reason",
						incremental_result.get(
							"reason",
							""
						)
					)
				).strip_edges()

				report ["reason"] = (
					nested_reason
					if nested_reason != ""
					else "required_incremental_task_failed"
				)

			if required_for_completion:
				report ["is_complete"] = false
				report ["progress"] = minf(
					float(
						report.get(
							"progress",
							0.0
						)
					),
					0.99
				)
				report ["completion_blocked"] = true

	elif execution_model == "constant_time":
		report ["result"] = (
			(result as Dictionary).duplicate(false)
			if typeof(result) == TYPE_DICTIONARY
			else result
		)

		var constant_failed: bool = false
		var constant_skipped: bool = false

		if typeof(result) == TYPE_DICTIONARY:
			var constant_result: Dictionary = result as Dictionary

			constant_failed = bool(
				constant_result.get(
					"failed",
					false
				)
			)
			constant_skipped = bool(
				constant_result.get(
					"skipped",
					false
				)
			)

			if (
				constant_result.has(
					"success"
				)
				and not bool(
					constant_result.get(
						"success",
						false
					)
				)
			):
				constant_failed = true

		if (
			constant_failed
			or (
				required_for_completion
				and constant_skipped
			)
		):
			report ["failed"] = true

			if required_for_completion:
				report ["is_complete"] = false
				report ["progress"] = 0.0
				report ["completion_blocked"] = true
			else:
				report ["is_complete"] = true
				report ["progress"] = 1.0
		else:
			report ["is_complete"] = true
			report ["progress"] = 1.0

	else:


		report ["result"] = (
			(result as Dictionary).duplicate(false)
			if typeof(result) == TYPE_DICTIONARY
			else result
		)
		report ["is_complete"] = true
		report ["progress"] = 1.0
		report ["legacy_unclassified"] = true

	return report
func _execute_runtime_phase_domain_tasks(phase_id: String, fallback_tasks: Array = []) -> Dictionary:
	var tasks: Array = _runtime_phase_domain_tasks(phase_id, fallback_tasks)
	var report:= {
		"schema": "eralife.age_up_runtime_phase_domain_task_report",
		"phase": phase_id,
		"task_count": tasks.size(),
		"ran": [],
		"skipped": [],
		"failed": [],
		"started_at_ms": int(Time.get_ticks_msec())
	}

	for task in tasks:
		if typeof(task) != TYPE_DICTIONARY:
			continue

		var task_report: Dictionary = _execute_runtime_domain_task(task, phase_id)
		if bool(task_report.get("ran", false)):
			report ["ran"].append(task_report)
		elif bool(task_report.get("failed", false)):
			report ["failed"].append(task_report)
		else:
			report ["skipped"].append(task_report)

	report ["finished_at_ms"] = int(Time.get_ticks_msec())
	report ["duration_ms"] = int(report ["finished_at_ms"]) - int(report ["started_at_ms"])

	var domain_reports_raw: Variant = active_mailboxes.get("domain_task_reports", [])
	var domain_reports: Array = domain_reports_raw if typeof(domain_reports_raw) == TYPE_ARRAY else []
	domain_reports.append(report.duplicate(true))
	active_mailboxes ["domain_task_reports"] = domain_reports

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_age_up_runtime_domain_task_report"] = report.duplicate(true)

	return report

func _execute_registered_phase_domain_tasks(
	phase_id: String
) -> Dictionary:


	if phase_id == "core_state_resolution":
		return {
			"schema": (
				"eralife.age_up_runtime_phase_domain_task_step"
			),
			"phase": phase_id,
			"is_complete": true,
			"progress": 1.0
		}

	return _step_registered_phase_domain_tasks(
		phase_id
	)

func _legacy_core_state_domain_tasks() -> Array:
	return [
		{
			"id": "world.age_npcs",
			"engine_id": "world_engine",
			"task_id": "age_npcs",
			"dispatch": "world_contract_task",
			"order": 10,
			"passes_context": true
		},
		{
			"id": "world.process_pregnancies",
			"engine_id": "world_engine",
			"task_id": "process_pregnancies",
			"dispatch": "world_contract_task",
			"order": 20,
			"passes_context": true
		},
		{
			"id": "world.npc_have_children",
			"engine_id": "world_engine",
			"task_id": "npc_have_children",
			"dispatch": "world_contract_task",
			"order": 30,
			"passes_context": true
		},
		{
			"id": "world.process_divorces",
			"engine_id": "world_engine",
			"task_id": "process_divorces",
			"dispatch": "world_contract_task",
			"order": 40,
			"passes_context": true
		},
		{
			"id": "world.process_remarriages",
			"engine_id": "world_engine",
			"task_id": "process_remarriages",
			"dispatch": "world_contract_task",
			"order": 50,
			"passes_context": true
		},
		{
			"id": "world.process_movement",
			"engine_id": "world_engine",
			"task_id": "process_movement",
			"dispatch": "world_contract_task",
			"order": 60,
			"passes_context": true
		},
		{
			"id": "dynamic_world.era_events",
			"engine_id": "dynamic_world_event_engine",
			"method": "_era_events",
			"dispatch": "engine_method",
			"order": 70,
			"passes_context": false
		},
		{
			"id": "dynamic_world.artifact_events",
			"engine_id": "dynamic_world_event_engine",
			"method": "_artifact_events",
			"dispatch": "engine_method",
			"order": 80,
			"passes_context": false
		},
		{
			"id": "dynamic_world.bending_events",
			"engine_id": "dynamic_world_event_engine",
			"method": "_bending_events",
			"dispatch": "engine_method",
			"order": 90,
			"passes_context": false
		},
		{
			"id": "dynamic_world.bonnet_events",
			"engine_id": "dynamic_world_event_engine",
			"method": "_bonnet_events",
			"dispatch": "engine_method",
			"order": 100,
			"passes_context": false
		},
		{
			"id": "dynamic_world.asset_ecology_events",
			"engine_id": "dynamic_world_event_engine",
			"method": "_asset_ecology_events",
			"dispatch": "engine_method",
			"order": 110,
			"passes_context": false
		}
	]
func _get_phase_walker_state(phase_name: String, defaults: Dictionary = {}) -> Dictionary:
	if phase_name == "":
		return {}
	var state_raw: Variant = runtime_phase_walkers.get(phase_name, {})
	var state: Dictionary = state_raw if typeof(state_raw) == TYPE_DICTIONARY else {}
	if state.is_empty():
		state = defaults.duplicate(true)
		state ["phase_name"] = phase_name
	return state

func _set_phase_walker_state(phase_name: String, state: Dictionary) -> void:
	if phase_name == "":
		return
	runtime_phase_walkers [phase_name] = state

func _clear_phase_walker_state(phase_name: String) -> void:
	if phase_name == "":
		return
	runtime_phase_walkers.erase(phase_name)

func _build_phase_step_result(phase_name: String, lane_name: String, is_complete: bool, progress: float) -> Dictionary:
	return {
		"state": "complete" if is_complete else "running",
		"is_complete": is_complete,
		"current_phase": phase_name,
		"current_micro_lane": lane_name,
		"progress": clamp(progress, 0.0, 1.0)
	}

func _phase_state_array(state: Dictionary, key: String) -> Array:
	var raw: Variant = state.get(key, [])
	return raw if typeof(raw) == TYPE_ARRAY else []

func _step_core_state_resolution_walker() -> Dictionary:
	if gs == null:
		return _build_phase_step_result(
			"core_state_resolution",
			"idle",
			true,
			1.0
		)

	var state: Dictionary = _get_phase_walker_state(
		"core_state_resolution",
		{
			"micro_lane_cursor": 0
		}
	)

	var tasks: Array = _runtime_phase_domain_tasks(
		"core_state_resolution",
		_legacy_core_state_domain_tasks()
	)

	var lane_cursor: int = int(
		state.get(
			"micro_lane_cursor",
			0
		)
	)

	var lane_name: String = "complete"

	var total_lanes: int = maxi(
		1,
		tasks.size() + 2
	)

	if lane_cursor < tasks.size():
		var task: Dictionary = (
			tasks [
				lane_cursor
			] as Dictionary
		)

		lane_name = str(
			task.get(
				"id",
				task.get(
					"task_id",
					"domain_task"
				)
			)
		).strip_edges()

		var task_report: Dictionary = (
			_execute_runtime_domain_task(
				task,
				"core_state_resolution"
			)
		)

		var task_complete: bool = bool(
			task_report.get(
				"is_complete",
				true
			)
		)

		var task_progress: float = clampf(
			float(
				task_report.get(
					"progress",
					(
						1.0
						if task_complete
						else 0.0
					)
				)
			),
			0.0,
			1.0
		)

		if not task_complete:
			state [
				"micro_lane_cursor"
			] = lane_cursor

			state [
				"active_domain_task_id"
			] = lane_name

			_set_phase_walker_state(
				"core_state_resolution",
				state
			)

			return _build_phase_step_result(
				"core_state_resolution",
				lane_name,
				false,
				clampf(
					(
						float(
							lane_cursor
						)
						+ task_progress
					) / float(
						total_lanes
					),
					0.0,
					0.98
				)
			)

		_queue_mailbox(
			"mutation",
			{
				"type": "core_state_domain_task",
				"year": int(
					active_year_context.get(
						"year",
						gs.year
					)
				),
				"lane": lane_name,
				"report": task_report.duplicate(
					false
				)
			}
		)

		lane_cursor += 1

	elif lane_cursor == tasks.size():
		lane_name = "group_refresh_request"







		active_year_context [
			"runtime_group_projection_requested"
		] = true

		active_year_context [
			"runtime_group_projection_requested_year"
		] = int(
			active_year_context.get(
				"year",
				gs.year
			)
		)

		active_year_context [
			"runtime_group_projection_requested_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		active_year_context [
			"runtime_group_projection_reused_resident_groups"
		] = true

		active_year_context [
			"runtime_group_projection_classification_on_age_up"
		] = false

		active_year_context [
			"runtime_group_projection_blocks_ui"
		] = false

		lane_cursor += 1

	elif lane_cursor == tasks.size() + 1:
		lane_name = "mailbox_finalize"

		_queue_mailbox(
			"mutation",
			{
				"type": "core_state_resolution_complete",
				"year": int(
					active_year_context.get(
						"year",
						gs.year
					)
				),
				"runtime_group_projection_requested": bool(
					active_year_context.get(
						"runtime_group_projection_requested",
						false
					)
				)
			}
		)

		lane_cursor += 1

	else:
		_clear_phase_walker_state(
			"core_state_resolution"
		)

		return _build_phase_step_result(
			"core_state_resolution",
			"complete",
			true,
			1.0
		)

	state [
		"micro_lane_cursor"
	] = lane_cursor

	state.erase(
		"active_domain_task_id"
	)

	if lane_cursor > total_lanes - 1:
		_clear_phase_walker_state(
			"core_state_resolution"
		)

		return _build_phase_step_result(
			"core_state_resolution",
			lane_name,
			true,
			1.0
		)

	_set_phase_walker_state(
		"core_state_resolution",
		state
	)

	return _build_phase_step_result(
		"core_state_resolution",
		lane_name,
		false,
		float(
			lane_cursor
		) / float(
			total_lanes
		)
	)
func _step_registered_phase_domain_tasks(
	phase_id: String
) -> Dictionary:
	var tasks: Array = _runtime_phase_domain_tasks(
		phase_id
	)

	if tasks.is_empty():
		return {
			"schema": (
				"eralife.age_up_runtime_phase_domain_task_step"
			),
			"phase": phase_id,
			"is_complete": true,
			"task_count": 0,
			"cursor": 0,
			"progress": 1.0
		}

	var root_raw: Variant = active_year_context.get(
		"registered_phase_domain_task_state",
		{}
	)
	var root: Dictionary = (
		root_raw as Dictionary
		if typeof(root_raw) == TYPE_DICTIONARY
		else {}
	)

	var phase_state_raw: Variant = root.get(
		phase_id,
		{}
	)
	var phase_state: Dictionary = (
		phase_state_raw as Dictionary
		if typeof(phase_state_raw) == TYPE_DICTIONARY
		else {}
	)

	var cursor: int = int(
		phase_state.get(
			"cursor",
			0
		)
	)

	if cursor >= tasks.size():
		root.erase(
			phase_id
		)
		active_year_context [
			"registered_phase_domain_task_state"
		] = root

		return {
			"schema": (
				"eralife.age_up_runtime_phase_domain_task_step"
			),
			"phase": phase_id,
			"is_complete": true,
			"task_count": tasks.size(),
			"cursor": tasks.size(),
			"progress": 1.0
		}

	var task: Dictionary = (
		tasks [cursor] as Dictionary
	)
	var task_report: Dictionary = (
		_execute_runtime_domain_task(
			task,
			phase_id
		)
	)

	var task_complete: bool = bool(
		task_report.get(
			"is_complete",
			true
		)
	)
	var task_progress: float = clampf(
		float(
			task_report.get(
				"progress",
				1.0 if task_complete else 0.0
			)
		),
		0.0,
		1.0
	)

	if task_complete:
		cursor += 1

	phase_state ["cursor"] = cursor
	root [phase_id] = phase_state

	if cursor >= tasks.size():
		root.erase(
			phase_id
		)

	active_year_context [
		"registered_phase_domain_task_state"
	] = root

	return {
		"schema": (
			"eralife.age_up_runtime_phase_domain_task_step"
		),
		"phase": phase_id,
		"is_complete": (
			cursor >= tasks.size()
		),
		"task_count": tasks.size(),
		"cursor": cursor,
		"task_id": str(
			task.get(
				"id",
				""
			)
		),
		"task_report": task_report.duplicate(
			false
		),
		"progress": clampf(
			(
				float(
					cursor
					- (
						0
						if task_complete
						else 1
					)
				)
				+ (
					0.0
					if task_complete
					else task_progress
				)
			) / float(
				maxi(
					1,
					tasks.size()
				)
			),
			0.0,
			1.0
		)
	}
func _step_internal_identity_drift_walker() -> Dictionary:
	if gs == null:
		return _build_phase_step_result(
			"internal_identity_drift",
			"idle",
			true,
			1.0
		)

	var state: Dictionary = _get_phase_walker_state(
		"internal_identity_drift",
		{
			"micro_lane_cursor": 0,
			"near_group": [],
			"mid_group": [],
			"far_group": [],
			"runtime_near_group": [],
			"fallback_near_cursor": 0,
			"fallback_mid_cursor": 0,
			"fallback_far_cursor": 0,
			"fallback_path_committed": false
		}
	)
	var lane_cursor: int = int(
		state.get(
			"micro_lane_cursor",
			0
		)
	)
	var lane_name: String = "complete"
	var fallback_path_committed: bool = bool(
		state.get(
			"fallback_path_committed",
			false
		)
	)

	match lane_cursor:
		0:
			lane_name = "group_bootstrap"
			var near_group: Array = _get_group_array(
				active_groups,
				"near"
			)
			var mid_group: Array = _get_group_array(
				active_groups,
				"mid"
			)
			var far_group: Array = _get_group_array(
				active_groups,
				"far"
			)

			if gs.afterlife_active:
				var anchor_id: int = int(
					gs.afterlife_state.get(
						"anchored_descendant_id",
						-1
					)
				)

				if anchor_id > 0:
					var anchor_npc: Person = (
						gs.get_or_reactivate_npc_by_id(
							anchor_id
						)
					)

					if (
						anchor_npc != null
						and anchor_npc.alive
						and anchor_npc not in near_group
					):
						near_group.append(
							anchor_npc
						)

			state ["near_group"] = near_group
			state ["mid_group"] = mid_group
			state ["far_group"] = far_group
			state ["micro_lane_cursor"] = 1
			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				0.125
			)

		1:
			lane_name = "near_runtime_filter"
			var near_group: Array = _phase_state_array(
				state,
				"near_group"
			)
			var runtime_near_group: Array = []
			var player_id: int = int(
				active_year_context.get(
					"player_id",
					-1
				)
			)

			for npc in near_group:
				if npc == null:
					continue

				if (
					not gs.afterlife_active
					and player_id > 0
					and int(
						npc.id
					) == player_id
				):
					continue

				runtime_near_group.append(
					npc
				)

			state ["runtime_near_group"] = (
				runtime_near_group
			)
			state ["micro_lane_cursor"] = 2
			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				0.25
			)

		2:
			lane_name = "group_commit"
			active_groups ["near"] = _phase_state_array(
				state,
				"near_group"
			)
			active_groups ["mid"] = _phase_state_array(
				state,
				"mid_group"
			)
			active_groups ["far"] = _phase_state_array(
				state,
				"far_group"
			)
			state ["micro_lane_cursor"] = 3
			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				0.375
			)

		3:
			var runtime_near_group: Array = (
				_phase_state_array(
					state,
					"runtime_near_group"
				)
			)

			if (
				gs.year_budget_engine != null
				and not fallback_path_committed
			):
				lane_name = "near_budget_lane"
				var near_result: Dictionary = (
					gs.year_budget_engine.process_near_npcs(
						runtime_near_group
					)
				)

				if bool(
					near_result.get(
						"is_complete",
						false
					)
				):
					state ["micro_lane_cursor"] = 4
			else:
				lane_name = "near_fallback"
				state [
					"fallback_path_committed"
				] = true
				var near_cursor: int = int(
					state.get(
						"fallback_near_cursor",
						0
					)
				)

				if near_cursor < runtime_near_group.size():
					var near_npc = (
						runtime_near_group [
							near_cursor
						]
					)

					if near_npc != null:
						_simulate_near_fallback(
							near_npc
						)

					near_cursor += 1

				state ["fallback_near_cursor"] = (
					near_cursor
				)

				if near_cursor >= runtime_near_group.size():
					state ["micro_lane_cursor"] = 4

			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				float(
					int(
						state.get(
							"micro_lane_cursor",
							3
						)
					)
				) / 8.0
			)

		4:
			fallback_path_committed = bool(
				state.get(
					"fallback_path_committed",
					false
				)
			)

			if (
				gs.year_budget_engine != null
				and not fallback_path_committed
			):
				lane_name = "pipeline_start"
				gs.year_budget_engine.start_year_pipeline(
					{
						"mid": _phase_state_array(
							state,
							"mid_group"
						),
						"far": _phase_state_array(
							state,
							"far_group"
						),
						"dormant_hot_ids": (
							active_year_context.get(
								"hot_dormant_ids",
								[]
							).duplicate()
						),
						"quality_tier": str(
							active_year_context.get(
								"quality_tier",
								QUALITY_BALANCED
							)
						),
						"mailboxes": active_mailboxes,
						"runtime_context": {
							"year": int(
								active_year_context.get(
									"year",
									gs.year
								)
							),
							"runtime_managed": true,
							"runtime_owner": "age_up_runtime",
							"phase": "internal_identity_drift"
						}
					},
					true
				)
				state ["micro_lane_cursor"] = 5
			else:
				lane_name = "mid_fallback"
				state [
					"fallback_path_committed"
				] = true
				var mid_group: Array = _phase_state_array(
					state,
					"mid_group"
				)
				var mid_cursor: int = int(
					state.get(
						"fallback_mid_cursor",
						0
					)
				)

				if mid_cursor < mid_group.size():
					var mid_npc = mid_group [
						mid_cursor
					]

					if mid_npc != null:
						_simulate_mid_fallback(
							mid_npc
						)

					mid_cursor += 1

				state ["fallback_mid_cursor"] = (
					mid_cursor
				)

				if mid_cursor >= mid_group.size():
					state ["micro_lane_cursor"] = 5

			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				float(
					int(
						state.get(
							"micro_lane_cursor",
							4
						)
					)
				) / 8.0
			)

		5:
			fallback_path_committed = bool(
				state.get(
					"fallback_path_committed",
					false
				)
			)

			if (
				gs.year_budget_engine != null
				and not fallback_path_committed
			):
				lane_name = "pipeline_register"
				var deferred_jobs_raw: Variant = (
					last_execution_report.get(
						"deferred_jobs",
						[]
					)
				)
				var deferred_jobs: Array = (
					deferred_jobs_raw
					if typeof(
						deferred_jobs_raw
					) == TYPE_ARRAY
					else []
				)
				deferred_jobs.append(
					{
						"job": "year_budget_pipeline",
						"phase": "internal_identity_drift",
						"pending": (
							gs.year_budget_engine.has_pending_year_pipeline()
						)
					}
				)
				last_execution_report [
					"deferred_jobs"
				] = deferred_jobs
				state ["micro_lane_cursor"] = 7
			else:
				lane_name = "far_fallback"
				state [
					"fallback_path_committed"
				] = true
				var far_group: Array = _phase_state_array(
					state,
					"far_group"
				)
				var far_cursor: int = int(
					state.get(
						"fallback_far_cursor",
						0
					)
				)

				if far_cursor < far_group.size():
					var far_npc = far_group [
						far_cursor
					]

					if far_npc != null:
						_simulate_far_fallback(
							far_npc
						)

					far_cursor += 1

				state ["fallback_far_cursor"] = (
					far_cursor
				)

				if far_cursor >= far_group.size():
					state ["micro_lane_cursor"] = 6

			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				float(
					int(
						state.get(
							"micro_lane_cursor",
							5
						)
					)
				) / 8.0
			)

		6:
			if gs.year_budget_engine == null:
				lane_name = "year_budget_residency_wait"
				_set_phase_walker_state(
					"internal_identity_drift",
					state
				)
				return _build_phase_step_result(
					"internal_identity_drift",
					lane_name,
					false,
					0.75
				)





			lane_name = "world_tail_pipeline_start"
			gs.year_budget_engine.start_year_pipeline(
				{
					"mid": [],
					"far": [],
					"dormant_hot_ids": (
						active_year_context.get(
							"hot_dormant_ids",
							[]
						).duplicate()
					),
					"quality_tier": str(
						active_year_context.get(
							"quality_tier",
							QUALITY_BALANCED
						)
					),
					"mailboxes": active_mailboxes,
					"runtime_context": {
						"year": int(
							active_year_context.get(
								"year",
								gs.year
							)
						),
						"runtime_managed": true,
						"runtime_owner": "age_up_runtime",
						"phase": "internal_identity_drift",
					}
				},
				true
			)

			var deferred_jobs_raw: Variant = (
				last_execution_report.get(
					"deferred_jobs",
					[]
				)
			)
			var deferred_jobs: Array = (
				deferred_jobs_raw
				if typeof(
					deferred_jobs_raw
				) == TYPE_ARRAY
				else []
			)
			deferred_jobs.append(
				{
					"job": "year_budget_pipeline",
					"phase": "internal_identity_drift",
					"pending": (
						gs.year_budget_engine.has_pending_year_pipeline()
					),
					"tail_only": true
				}
			)
			last_execution_report [
				"deferred_jobs"
			] = deferred_jobs
			state ["micro_lane_cursor"] = 7
			_set_phase_walker_state(
				"internal_identity_drift",
				state
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				false,
				0.875
			)

		7:
			lane_name = "mailbox_finalize"
			var runtime_near_group: Array = (
				_phase_state_array(
					state,
					"runtime_near_group"
				)
			)
			var mid_group: Array = _phase_state_array(
				state,
				"mid_group"
			)
			var far_group: Array = _phase_state_array(
				state,
				"far_group"
			)
			_queue_mailbox(
				"social",
				{
					"type": "identity_drift_complete",
					"near_count": int(
						runtime_near_group.size()
					),
					"mid_count": int(
						mid_group.size()
					),
					"far_count": int(
						far_group.size()
					),
					"dormant_hot_count": int(
						active_year_context.get(
							"hot_dormant_ids",
							[]
						).size()
					),
					"dormant_count": int(
						gs.dormant_npcs.size()
					)
				}
			)
			_clear_phase_walker_state(
				"internal_identity_drift"
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				lane_name,
				true,
				1.0
			)

		_:
			_clear_phase_walker_state(
				"internal_identity_drift"
			)
			return _build_phase_step_result(
				"internal_identity_drift",
				"complete",
				true,
				1.0
			)
func _run_core_state_resolution(max_steps: int = -1) -> void:
	var steps_remaining: int = max_steps
	while true:
		var step_result: Dictionary = _step_core_state_resolution_walker()
		if bool(step_result.get("is_complete", false)):
			return
		if max_steps >= 0:
			steps_remaining -= 1
			if steps_remaining <= 0:
				return

func _run_internal_identity_drift(max_steps: int = -1) -> void:
	var steps_remaining: int = max_steps
	while true:
		var step_result: Dictionary = _step_internal_identity_drift_walker()
		if bool(step_result.get("is_complete", false)):
			return
		if max_steps >= 0:
			steps_remaining -= 1
			if steps_remaining <= 0:
				return
func _run_choice_and_opportunity_surfacing() -> void:
	var player_id: int = int(active_year_context.get("player_id", -1))
	if player_id <= 0 or gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var scenario_setup_raw: Variant = gs.scenario_state.get("runtime_prepared_scenario_setup", {})
	var scenario_setup: Dictionary = {}
	if typeof(scenario_setup_raw) == TYPE_DICTIONARY:
		scenario_setup = scenario_setup_raw

	if scenario_setup.is_empty():
		return

	var target_year: int = int(active_year_context.get("year", gs.year))

	_queue_mailbox("scenario", {
		"type": "scenario_setup_ready",
		"player_id": player_id,
		"year": target_year,
		"mailbox_key": "scenario_setup_ready|%d|%d" % [player_id, target_year],
		"entry": scenario_setup.duplicate(true)
	})
	_queue_mailbox("scenario", {
		"type": "player_choice_window_ready",
		"player_id": player_id,
		"year": target_year,
		"mailbox_key": "player_choice_window_ready|%d|%d" % [player_id, target_year]
	})

	gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
func has_active_runtime_slice() -> bool:
	return runtime_slice_active


func complete_visible_slice_ui_first(
	result: Dictionary = {},
	reason: String = "ui_first_release"
) -> void:
	var display_result: Dictionary = (
		result.duplicate(false)
	)

	if (
		display_result.is_empty()
		and gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		var stored_raw: Variant = (
			gs.scenario_state.get(
				"post_runtime_result",
				{}
			)
		)

		if (
			typeof(
				stored_raw
			) == TYPE_DICTIONARY
			and not (
				stored_raw as Dictionary
			).is_empty()
		):
			display_result = (
				stored_raw as Dictionary
			).duplicate(false)

	if display_result.is_empty():
		return

	if not display_result.has(
		"type"
	):
		display_result [
			"type"
		] = "year_passed"

	if (
		not display_result.has(
			"year"
		)
		and gs != null
	):
		display_result [
			"year"
		] = int(
			gs.year
		)

	if (
		not display_result.has(
			"age"
		)
		and gs != null
		and gs.player != null
	):
		display_result [
			"age"
		] = int(
			gs.player.age
		)

	var tail_pending: bool = (
		runtime_slice_active
		or (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
			and bool(
				gs.scenario_state.get(
					"age_up_tail_runtime_pending",
					false
				)
			)
		)
	)





	active_year_context [
		"ui_first_release"
	] = true

	active_year_context [
		"ui_first_release_reason"
	] = reason

	active_year_context [
		"visible_overlay_released"
	] = true

	active_year_context [
		"tail_runtime_pending"
	] = tail_pending

	active_year_context [
		"ui_release_completed_simulation"
	] = false

	last_execution_report [
		"ui_first_release"
	] = true

	last_execution_report [
		"ui_first_release_reason"
	] = reason

	last_execution_report [
		"visible_overlay_released"
	] = true

	last_execution_report [
		"tail_runtime_pending"
	] = tail_pending

	last_execution_report [
		"ui_release_completed_simulation"
	] = false

	last_execution_report [
		"phase_order"
	] = runtime_slice_order.duplicate(false)

	last_execution_report [
		"phase_timings_ms"
	] = runtime_slice_phase_timings.duplicate(false)

	last_execution_report [
		"released_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"post_runtime_result"
		] = display_result.duplicate(false)

		gs.scenario_state [
			"last_runtime_report"
		] = last_execution_report.duplicate(false)

		gs.scenario_state [
			"age_up_ui_first_release_completed_simulation"
		] = false

		gs.scenario_state [
			"age_up_ui_first_release_preserved_tail"
		] = tail_pending

		_update_loading_runtime_bucket({
			"completion_state": (
				"presentation_released"
				if tail_pending
				else "complete"
			),
			"is_complete": not tail_pending,
			"current_phase": str(
				active_year_context.get(
					"current_phase",
					"preflight"
				)
			),
			"session_stage": (
				"tail_running"
				if tail_pending
				else "complete"
			),
			"subline": "",
			"final_result": display_result.duplicate(false),
			"resolved_result": display_result.duplicate(false),
			"ui_first_release": true,
			"ui_first_release_reason": reason,
			"tail_runtime_pending": tail_pending,
			"ui_release_completed_simulation": false
		})
func _runtime_event_should_enter_life_diary(raw_event: Variant) -> bool:
	if gs == null or gs.player == null:
		return false
	if typeof(raw_event) != TYPE_DICTIONARY:
		return false

	var event: Dictionary = raw_event
	if bool(event.get("suppress_diary", false)):
		return false

	var diary_scope: String = str(event.get("diary_scope", "")).strip_edges()
	if diary_scope in ["player", "personal", "family", "family_relevant"]:
		return true
	if diary_scope in ["world", "era", "ambient", "flavor", "none"]:
		return false

	var line_probe: String = _runtime_diary_line_from_event(event).strip_edges().to_lower()
	if line_probe == "":
		return false

	if line_probe.begins_with("you made it to age"):
		return false
	if line_probe.begins_with("i turned "):
		return false
	if line_probe.find("found a cool rock") != -1:
		return false
	if line_probe.find("practiced my avatar bending") != -1 and not bool(event.get("player_initiated", false)):
		return false
	if line_probe.find("neighboring tribe raided") != -1 and not bool(event.get("personally_relevant", false)):
		return false
	if line_probe.find("local ruler demanded new taxes") != -1 and not bool(event.get("personally_relevant", false)):
		return false

	var source: String = str(event.get("source", "")).strip_edges()
	var category: String = str(event.get("category", "")).strip_edges()
	var event_name: String = str(event.get("event_name", event.get("type", ""))).strip_edges()

	if source in ["era_engine", "world_engine", "ai_event_engine"] and not bool(event.get("personally_relevant", false)):
		return false
	if category in ["world", "era", "ambient", "flavor"] and not bool(event.get("personally_relevant", false)):
		return false
	if event_name in ["year_passed", "age_flavor", "ambient_flavor"]:
		return false

	var npc_id: int = int(event.get("npc_id", -1))
	var target_id: int = int(event.get("target_id", -1))

	if _runtime_person_is_player_family(npc_id):
		return true
	if _runtime_person_is_player_family(target_id):
		return true

	if npc_id == int(gs.player.id) or target_id == int(gs.player.id):
		return bool(event.get("personally_relevant", false)) or source not in ["", "ai_event_engine", "era_engine", "world_engine"]

	return bool(event.get("personally_relevant", false))


func _runtime_person_is_player_family(person_id: int) -> bool:
	if gs == null or gs.player == null:
		return false
	if person_id <= 0:
		return false
	if person_id == int(gs.player.id):
		return true
	if person_id in gs.player.parents or person_id in gs.player.children:
		return true

	var person: Person = gs.get_npc_by_id(person_id)
	if person == null:
		return false

	if int(gs.player.id) in person.parents or int(gs.player.id) in person.children:
		return true

	for parent_id in gs.player.parents:
		if parent_id in person.parents:
			return true

	return false


func _runtime_diary_line_from_event(raw_event: Variant) -> String:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return ""

	var event: Dictionary = raw_event
	var line: String = str(event.get("player_text", "")).strip_edges()
	if line == "":
		line = str(event.get("journal_text", "")).strip_edges()
	if line == "":
		line = str(event.get("text", "")).strip_edges()

	return line
func _visible_age_up_runtime_is_hot() -> bool:
	if gs == null:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var loading_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	var loading: Dictionary = loading_raw if typeof(loading_raw) == TYPE_DICTIONARY else {}

	if loading.is_empty():
		return false

	var completion_state: String = str(loading.get("completion_state", "")).strip_edges()
	if completion_state == "complete":
		return false

	var session_stage: String = str(loading.get("session_stage", "")).strip_edges()
	var current_phase: String = str(loading.get("current_phase", "")).strip_edges()

	if session_stage in ["boot", "running", "settling_previous_year", "settling_current_year"]:
		return true

	if current_phase in ["overlay_entry", "year_and_era_mutation", "core_state_resolution", "internal_identity_drift", "player_phase_contract", "commit_settling"]:
		return true

	return bool(loading.get("active", false))
func _step_player_phase_contract_walker() -> Dictionary:
	if gs == null or gs.player == null:
		return _build_phase_step_result("player_phase_contract", "idle", true, 1.0)

	var state: Dictionary = _get_phase_walker_state("player_phase_contract", {
		"micro_lane_cursor": 0,
		"events": [],
		"relationship_targets": [],
		"relationship_cursor": 0,
		"event_log_cursor": 0,
		"opps": [],
		"auto_stability_mode": false,
		"reduce_scenario_density": false,
		"defer_noncritical_systems": false,
		"defer_player_facing_surfaces": false
	})

	var lane_cursor: int = int(state.get("micro_lane_cursor", 0))
	var lane_name: String = "complete"
	var total_lanes: float = 13.0
	var player: Person = gs.player

	match lane_cursor:
		0:
			lane_name = "phase_bootstrap"
			var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
			var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
			var visible_runtime_hot: bool = _visible_age_up_runtime_is_hot()

			state ["visible_runtime_hot"] = visible_runtime_hot
			state ["auto_stability_mode"] = bool(guard.get("auto_stability_mode", false)) \
or bool(guard.get("compressed_execution_current_year", false)) \
or visible_runtime_hot
			state ["reduce_scenario_density"] = bool(guard.get("reduce_scenario_density", false)) \
or visible_runtime_hot
			state ["defer_noncritical_systems"] = bool(guard.get("defer_noncritical_systems", false)) \
or visible_runtime_hot




			state ["defer_player_facing_surfaces"] = bool(guard.get("defer_player_facing_surfaces", false))
			state ["events"] = []
			state ["relationship_targets"] = []
			state ["relationship_cursor"] = 0
			state ["event_log_cursor"] = 0
			state ["opps"] = []
			if gs.scenario_engine != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
			state ["micro_lane_cursor"] = 1
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 1.0 / total_lanes)

		1:
			lane_name = "bias_commit"
			if gs.scenario_engine != null:
				gs.scenario_engine.apply_committed_biases_for_year()
			if gs.crime_engine != null:
				gs.crime_engine.reduce_prison_time()
			state ["micro_lane_cursor"] = 2
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 2.0 / total_lanes)

		2:
			lane_name = "player_health_and_survival"

			if gs.heirloom_contract_engine != null:
				var heirloom_year_report: Dictionary = (
					gs.heirloom_contract_engine.yearly_tick(
						player,
						{
							"action_id": "yearly_tick",
							"year": int(gs.year),
							"source": (
								"age_up_runtime"
								+ ".player_health_and_survival"
							)
						}
					)
				)

				state ["heirloom_year_report"] = (
					heirloom_year_report.duplicate(true)
				)

			if gs.personality_engine != null:
				gs.personality_engine.generate_traits(player)
			if gs.health_engine != null:
				gs.health_engine.update_health(player)
			if not player.alive:
				var death_result: Dictionary = {}
				if gs.life_engine != null and gs.life_engine.has_method("_handle_player_death"):
					death_result = gs.life_engine._handle_player_death()
				if typeof(gs.scenario_state) == TYPE_DICTIONARY:
					gs.scenario_state ["post_runtime_result"] = death_result.duplicate(true)
				_clear_phase_walker_state("player_phase_contract")
				return _build_phase_step_result("player_phase_contract", lane_name, true, 1.0)
			state ["micro_lane_cursor"] = 3
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 3.0 / total_lanes)

		3:
			lane_name = "career_and_school"
			if gs.career_engine != null:
				gs.career_engine.update_career(player)
			if gs.school_engine != null:
				gs.school_engine.attend_school_year(player)
			state ["micro_lane_cursor"] = 4
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 4.0 / total_lanes)

		4:
			lane_name = "world_event_generation"
			var events: Array = []
			if gs.event_engine != null:
				events = gs.event_engine.generate_year_events(player)
			if bool(state.get("auto_stability_mode", false)) and bool(state.get("reduce_scenario_density", false)) and events.size() > 6:
				events = events.slice(0, 6)
			state ["events"] = events
			state ["micro_lane_cursor"] = 5
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 5.0 / total_lanes)

		5:
			lane_name = "ai_event_generation"
			var events: Array = _phase_state_array(state, "events")
			var ai_events: Array = []

			if not bool(state.get("defer_noncritical_systems", false)):
				if gs.ai_event_engine != null:
					ai_events = gs.ai_event_engine.generate_events(player)
				if bool(state.get("auto_stability_mode", false)) and bool(state.get("reduce_scenario_density", false)) and ai_events.size() > 2:
					ai_events = ai_events.slice(0, 2)
				for e in ai_events:
					events.append(e)

			state ["events"] = events
			state ["micro_lane_cursor"] = 6
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 6.0 / total_lanes)

		6:
			lane_name = "era_event_generation"
			var events: Array = _phase_state_array(state, "events")

			if not bool(state.get("defer_noncritical_systems", false)):
				if gs.era_engine != null:
					var era_events: Array = gs.era_engine.get_world_events()
					if bool(state.get("auto_stability_mode", false)) and bool(state.get("reduce_scenario_density", false)) and era_events.size() > 2:
						era_events = era_events.slice(0, 2)
					for e in era_events:
						events.append({
							"text": e,
							"source": "era_engine",
							"category": "era",
							"diary_scope": "era",
							"suppress_diary": true
						})

			if bool(state.get("auto_stability_mode", false)) and bool(state.get("reduce_scenario_density", false)) and events.size() > 10:
				events = events.slice(0, 10)

			state ["events"] = events
			state ["micro_lane_cursor"] = 7
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 7.0 / total_lanes)

		7:
			lane_name = "relationship_target_bootstrap"
			var relationship_targets: Array = _collect_player_phase_relationship_targets()
			if bool(state.get("auto_stability_mode", false)) and relationship_targets.size() > 4:
				relationship_targets = relationship_targets.slice(0, 4)
			state ["relationship_targets"] = relationship_targets
			state ["relationship_cursor"] = 0
			state ["micro_lane_cursor"] = 8
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 8.0 / total_lanes)

		8:
			lane_name = "relationship_updates"
			var relationship_targets: Array = _phase_state_array(state, "relationship_targets")
			var relationship_cursor: int = int(state.get("relationship_cursor", 0))
			if relationship_cursor < relationship_targets.size():
				var target = relationship_targets [relationship_cursor]
				if gs.relationship_engine != null and target != null:
					gs.relationship_engine.update_relationship(player, target)
				relationship_cursor += 1
				state ["relationship_cursor"] = relationship_cursor
				if relationship_cursor >= relationship_targets.size():
					state ["micro_lane_cursor"] = 9
				_set_phase_walker_state("player_phase_contract", state)
				var relationship_total: float = max(1.0, float(relationship_targets.size()))
				var relationship_progress: float = float(relationship_cursor) / relationship_total
				return _build_phase_step_result("player_phase_contract", lane_name, false, (8.0 + relationship_progress) / total_lanes)
			state ["micro_lane_cursor"] = 9
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 9.0 / total_lanes)

		9:
			lane_name = "event_logging"
			var events: Array = _phase_state_array(state, "events")
			var event_log_cursor: int = int(state.get("event_log_cursor", 0))

			if event_log_cursor < events.size():
				var event_to_log: Variant = events [event_log_cursor]

				if gs.narrative_engine != null and _runtime_event_should_enter_life_diary(event_to_log):
					gs.narrative_engine.log_event(player, event_to_log)

				event_log_cursor += 1
				state ["event_log_cursor"] = event_log_cursor

				if event_log_cursor >= events.size():
					state ["micro_lane_cursor"] = 10

				_set_phase_walker_state("player_phase_contract", state)

				var event_total: float = max(1.0, float(events.size()))
				var event_progress: float = float(event_log_cursor) / event_total
				return _build_phase_step_result("player_phase_contract", lane_name, false, (9.0 + event_progress) / total_lanes)

			state ["micro_lane_cursor"] = 10
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 10.0 / total_lanes)

		10:
			lane_name = "opportunity_generation"
			var opps: Array = []

			if bool(state.get("defer_noncritical_systems", false)) and bool(state.get("defer_player_facing_surfaces", false)):
				_queue_deferred_runtime_tail_phase("choice_and_opportunity_surfacing")
			else:
				if gs.opportunity_engine != null:
					opps = gs.opportunity_engine.generate_opportunities(player)
				if bool(state.get("auto_stability_mode", false)) and bool(state.get("reduce_scenario_density", false)) and opps.size() > 4:
					opps = opps.slice(0, 4)

			state ["opps"] = opps
			state ["micro_lane_cursor"] = 11
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 11.0 / total_lanes)

		11:
			lane_name = "result_commit"
			var final_events: Array = _phase_state_array(state, "events")
			var final_opps: Array = _phase_state_array(state, "opps")
			var diary_lines: Array = []
			var seen_diary_lines: Dictionary = {}

			for raw_event in final_events:
				if not _runtime_event_should_enter_life_diary(raw_event):
					continue

				var line: String = _runtime_diary_line_from_event(raw_event)
				if line == "":
					continue
				if seen_diary_lines.has(line):
					continue

				seen_diary_lines [line] = true
				diary_lines.append("• %s" % line)

			var final_text:= ""
			if not diary_lines.is_empty():
				final_text = "\n".join(PackedStringArray(diary_lines))

			var final_result: Dictionary = {
				"type": "year_passed",
				"text": final_text,
				"events": final_events,
				"opps": final_opps,
				"year": int(gs.year),
				"age": int(player.age)
			}

			if gs != null and gs.has_method("push_world_feed"):
				gs.push_world_feed("%s %s turned %d in %s." % [
					player.first_name,
					player.last_name,
					int(player.age),
					str(gs.era.name) if gs.era != null else "the current era"
				], {
					"npc_id": int(player.id),
					"personally_relevant": true,
					"category": "world",
					"event_name": "year_passed",
					"source": "age_up_runtime",
					"year": int(gs.year),
					"suppress_diary": true
				})

			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["post_runtime_result"] = final_result.duplicate(true)

			state ["micro_lane_cursor"] = 12
			_set_phase_walker_state("player_phase_contract", state)
			return _build_phase_step_result("player_phase_contract", lane_name, false, 12.0 / total_lanes)

		12:
			lane_name = "scenario_setup"

			if bool(state.get("defer_noncritical_systems", false)) and bool(state.get("defer_player_facing_surfaces", false)):
				_queue_deferred_runtime_tail_phase("choice_and_opportunity_surfacing")
			elif gs.scenario_engine != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
				var scenario_setup: Dictionary = gs.scenario_engine.prepare_pre_year_player_scenarios()
				if typeof(scenario_setup) == TYPE_DICTIONARY and not scenario_setup.is_empty():
					gs.scenario_state ["runtime_prepared_scenario_setup"] = scenario_setup.duplicate(true)

			_clear_phase_walker_state("player_phase_contract")
			return _build_phase_step_result("player_phase_contract", lane_name, true, 1.0)

		_:
			_clear_phase_walker_state("player_phase_contract")
			return _build_phase_step_result("player_phase_contract", "complete", true, 1.0)
func _run_data_defined_simulation_laws() -> void:
	if gs == null:
		return

	if gs.simulation_contract_engine == null:
		return

	if not gs.simulation_contract_engine.has_method("run_yearly_simulation_laws"):
		return

	var report: Dictionary = gs.simulation_contract_engine.run_yearly_simulation_laws(active_year_context)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["last_data_defined_simulation_report"] = report.duplicate(true)

	var mailbox: Array = active_mailboxes.get("delta_packets", [])
	mailbox.append({
		"type": "data_defined_simulation_laws",
		"phase": "data_defined_simulation_laws",
		"year": int(active_year_context.get("year", gs.year)),
		"realm_update_count": int(report.get("realm_updates", []).size()),
		"layer_update_count": int(report.get("layer_updates", []).size())
	})
	active_mailboxes ["delta_packets"] = mailbox
func _run_player_phase_contract() -> void:
	while true:
		var step_result: Dictionary = _step_player_phase_contract_walker()
		if bool(step_result.get("is_complete", false)):
			return

func _collect_player_phase_relationship_targets() -> Array:
	if gs == null or gs.life_engine == null:
		return []
	if gs.life_engine.has_method("_collect_player_relationship_targets"):
		return gs.life_engine._collect_player_relationship_targets()
	return []

func _run_narrative_and_presentation() -> void:
	if gs == null:
		return

	var direct_packets: Array = _collect_direct_delta_packets()
	var narrative_step_budget: int = 24
	var budget_override: int = int(
		active_year_context.get(
			"narrative_phase_budget",
			0
		)
	)

	if budget_override > 0:
		narrative_step_budget = budget_override

	if bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	):
		narrative_step_budget = mini(
			narrative_step_budget,
			4
		)

	var narrative_progress_raw: Variant = (
		active_year_context.get(
			"narrative_progress",
			{}
		)
	)
	var narrative_progress: Dictionary = narrative_progress_raw if typeof(narrative_progress_raw) == TYPE_DICTIONARY else {
		"typed_world_feed_done": false,
		"typed_popups_done": false,
		"typed_chronicle_done": false,
		"year_commit_complete_queued": false
	}

	var rows_remaining: int = narrative_step_budget

	if rows_remaining > 0 and not bool(narrative_progress.get("typed_world_feed_done", false)):
		if gs.world_feed_engine != null and gs.world_feed_engine.has_method("build_runtime_mailbox_entries_from_typed_packets"):
			var typed_world_feed_rows: Array = gs.world_feed_engine.build_runtime_mailbox_entries_from_typed_packets(direct_packets)
			var typed_world_feed_cursor: int = int(narrative_progress.get("typed_world_feed_cursor", 0))
			typed_world_feed_cursor = clamp(typed_world_feed_cursor, 0, typed_world_feed_rows.size())
			while rows_remaining > 0 and typed_world_feed_cursor < typed_world_feed_rows.size():
				var raw_row = typed_world_feed_rows [typed_world_feed_cursor]
				typed_world_feed_cursor += 1
				if typeof(raw_row) != TYPE_DICTIONARY:
					continue
				_queue_mailbox("world_feed", raw_row)
				rows_remaining -= 1
			narrative_progress ["typed_world_feed_cursor"] = typed_world_feed_cursor
			narrative_progress ["typed_world_feed_done"] = typed_world_feed_cursor >= typed_world_feed_rows.size()
		else:
			narrative_progress ["typed_world_feed_done"] = true

	if rows_remaining > 0:
		var wf_start: int = int(active_year_context.get("world_feed_cursor", 0))
		wf_start = clamp(wf_start, 0, gs.world_feed.size())
		while rows_remaining > 0 and wf_start < gs.world_feed.size():
			var entry = gs.normalize_world_feed_entry(gs.world_feed [wf_start])
			_queue_mailbox("world_feed", {
				"type": "world_feed_entry",
				"entry": entry
			})
			wf_start += 1
			rows_remaining -= 1
		active_year_context ["world_feed_cursor"] = wf_start

	if rows_remaining > 0 and not bool(narrative_progress.get("typed_popups_done", false)):
		if gs.has_method("build_runtime_popup_mailbox_entries_from_typed_packets"):
			var typed_popup_rows: Array = gs.build_runtime_popup_mailbox_entries_from_typed_packets(direct_packets)
			var typed_popup_cursor: int = int(narrative_progress.get("typed_popup_cursor", 0))
			typed_popup_cursor = clamp(typed_popup_cursor, 0, typed_popup_rows.size())
			while rows_remaining > 0 and typed_popup_cursor < typed_popup_rows.size():
				var raw_popup_row = typed_popup_rows [typed_popup_cursor]
				typed_popup_cursor += 1
				if typeof(raw_popup_row) != TYPE_DICTIONARY:
					continue
				_queue_mailbox("popups", raw_popup_row)
				rows_remaining -= 1
			narrative_progress ["typed_popup_cursor"] = typed_popup_cursor
			narrative_progress ["typed_popups_done"] = typed_popup_cursor >= typed_popup_rows.size()
		else:
			narrative_progress ["typed_popups_done"] = true

	if rows_remaining > 0:
		var death_start: int = int(active_year_context.get("death_cursor", 0))
		death_start = clamp(death_start, 0, gs.pending_death_messages.size())
		while rows_remaining > 0 and death_start < gs.pending_death_messages.size():
			_queue_mailbox("popups", {
				"type": "death_notice",
				"text": str(gs.pending_death_messages [death_start])
			})
			death_start += 1
			rows_remaining -= 1
		active_year_context ["death_cursor"] = death_start

	if rows_remaining > 0:
		var inheritance_start: int = int(active_year_context.get("inheritance_cursor", 0))
		inheritance_start = clamp(inheritance_start, 0, gs.pending_inheritance_messages.size())
		while rows_remaining > 0 and inheritance_start < gs.pending_inheritance_messages.size():
			_queue_mailbox("popups", {
				"type": "inheritance_notice",
				"text": str(gs.pending_inheritance_messages [inheritance_start])
			})
			inheritance_start += 1
			rows_remaining -= 1
		active_year_context ["inheritance_cursor"] = inheritance_start

	if rows_remaining > 0:
		var popup_start: int = int(active_year_context.get("popup_cursor", 0))
		popup_start = clamp(popup_start, 0, gs.pending_year_resolution_popups.size())
		while rows_remaining > 0 and popup_start < gs.pending_year_resolution_popups.size():
			var popup_entry = gs.pending_year_resolution_popups [popup_start]
			popup_start += 1
			if typeof(popup_entry) != TYPE_DICTIONARY:
				continue
			_queue_mailbox("popups", {
				"type": "year_resolution_popup",
				"entry": popup_entry.duplicate(true)
			})
			rows_remaining -= 1
		active_year_context ["popup_cursor"] = popup_start

	if rows_remaining > 0 and not bool(narrative_progress.get("typed_chronicle_done", false)):
		if gs.world_chronicle_engine != null and gs.world_chronicle_engine.has_method("build_runtime_mailbox_entries_from_typed_packets"):
			var typed_chronicle_rows: Array = gs.world_chronicle_engine.build_runtime_mailbox_entries_from_typed_packets(direct_packets)
			var typed_chronicle_cursor: int = int(narrative_progress.get("typed_chronicle_cursor", 0))
			typed_chronicle_cursor = clamp(typed_chronicle_cursor, 0, typed_chronicle_rows.size())
			while rows_remaining > 0 and typed_chronicle_cursor < typed_chronicle_rows.size():
				var raw_chronicle_row = typed_chronicle_rows [typed_chronicle_cursor]
				typed_chronicle_cursor += 1
				if typeof(raw_chronicle_row) != TYPE_DICTIONARY:
					continue
				_queue_mailbox("chronicle", raw_chronicle_row)
				rows_remaining -= 1
			narrative_progress ["typed_chronicle_cursor"] = typed_chronicle_cursor
			narrative_progress ["typed_chronicle_done"] = typed_chronicle_cursor >= typed_chronicle_rows.size()
		else:
			narrative_progress ["typed_chronicle_done"] = true

	if rows_remaining > 0 and not bool(narrative_progress.get("year_commit_complete_queued", false)):
		_queue_mailbox("chronicle", {
			"type": "year_commit_complete",
			"year": int(active_year_context.get("year", gs.year)),
			"quality_tier": str(active_year_context.get("quality_tier", QUALITY_BALANCED)),
			"mailbox_key": "year_commit_complete|%d" % int(active_year_context.get("year", gs.year))
		})
		narrative_progress ["year_commit_complete_queued"] = true

	active_year_context ["narrative_progress"] = narrative_progress
func _narrative_and_presentation_complete() -> bool:
	if gs == null:
		return true

	var narrative_progress_raw: Variant = active_year_context.get("narrative_progress", {})
	var narrative_progress: Dictionary = narrative_progress_raw if typeof(narrative_progress_raw) == TYPE_DICTIONARY else {}

	if not bool(narrative_progress.get("typed_world_feed_done", false)):
		return false

	if int(active_year_context.get("world_feed_cursor", 0)) < int(gs.world_feed.size()):
		return false

	if not bool(narrative_progress.get("typed_popups_done", false)):
		return false

	if int(active_year_context.get("death_cursor", 0)) < int(gs.pending_death_messages.size()):
		return false

	if int(active_year_context.get("inheritance_cursor", 0)) < int(gs.pending_inheritance_messages.size()):
		return false

	if int(active_year_context.get("popup_cursor", 0)) < int(gs.pending_year_resolution_popups.size()):
		return false

	if not bool(narrative_progress.get("typed_chronicle_done", false)):
		return false

	if not bool(narrative_progress.get("year_commit_complete_queued", false)):
		return false

	return true
func _queue_mailbox_rows(channel: String, rows: Array) -> void:
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		_queue_mailbox(channel, raw_row)

func _mailbox_payload_key(channel: String, payload: Dictionary) -> String:
	if typeof(payload) != TYPE_DICTIONARY or payload.is_empty():
		return ""

	var explicit_key: String = str(payload.get("mailbox_key", "")).strip_edges()
	if explicit_key != "":
		return "%s|%s" % [channel, explicit_key]

	match channel:
		"delta_packets":
			return _delta_packet_key(payload)
		"world_feed":
			var entry = payload.get("entry", {})
			if typeof(entry) == TYPE_DICTIONARY:
				var normalized_entry: Dictionary = gs.normalize_world_feed_entry(entry) if gs != null else entry.duplicate(true)
				return "%s|%s|%s|%s" % [
					channel,
					str(normalized_entry.get("event_name", "")),
					str(normalized_entry.get("npc_id", -1)),
					str(normalized_entry.get("text", ""))
				]
		"chronicle":
			return "%s|%s|%s|%s" % [
				channel,
				str(payload.get("type", "")),
				str(payload.get("year", "")),
				str(payload.get("text", ""))
			]
		"popups":
			var popup_type: String = str(payload.get("type", "")).strip_edges()
			if popup_type == "year_resolution_popup":
				var popup_entry = payload.get("entry", {})
				if typeof(popup_entry) == TYPE_DICTIONARY:
					return "%s|%s|%s" % [
						channel,
						popup_type,
						str(popup_entry.get("popup_text", ""))
					]
			return "%s|%s|%s" % [
				channel,
				popup_type,
				str(payload.get("text", ""))
			]

	return ""
func _build_delta_packets(before_snapshot: Dictionary, after_snapshot: Dictionary, direct_packets: Array = []) -> Array:
	var snapshot_packets: Array = []
	var all_ids: Dictionary = {}

	for npc_id in before_snapshot.keys():
		all_ids [int(npc_id)] = true
	for npc_id in after_snapshot.keys():
		all_ids [int(npc_id)] = true

	for npc_id in all_ids.keys():
		var before_state: Dictionary = before_snapshot.get(int(npc_id), {})
		var after_state: Dictionary = after_snapshot.get(int(npc_id), {})

		if before_state.is_empty() and not after_state.is_empty():
			snapshot_packets.append({
				"type": "appeared",
				"npc_id": int(npc_id),
				"name": str(after_state.get("name", "Unknown"))
			})
			continue

		if not before_state.is_empty() and after_state.is_empty():
			snapshot_packets.append({
				"type": "removed",
				"npc_id": int(npc_id),
				"name": str(before_state.get("name", "Unknown"))
			})
			continue

		if before_state.is_empty() or after_state.is_empty():
			continue

		var before_alive: bool = bool(before_state.get("alive", false))
		var after_alive: bool = bool(after_state.get("alive", false))
		if before_alive and not after_alive:
			snapshot_packets.append({
				"type": "death",
				"npc_id": int(npc_id),
				"name": str(after_state.get("name", before_state.get("name", "Unknown")))
			})

		var before_settlement: String = str(before_state.get("settlement_id", ""))
		var after_settlement: String = str(after_state.get("settlement_id", ""))
		if before_settlement != after_settlement:
			snapshot_packets.append({
				"type": "moved",
				"npc_id": int(npc_id),
				"from": before_settlement,
				"to": after_settlement
			})

		var before_city: String = str(before_state.get("home_city", ""))
		var after_city: String = str(after_state.get("home_city", ""))
		var before_country: String = str(before_state.get("home_country", ""))
		var after_country: String = str(after_state.get("home_country", ""))
		if before_city != after_city or before_country != after_country:
			snapshot_packets.append({
				"type": "place_shift",
				"npc_id": int(npc_id),
				"from_city": before_city,
				"to_city": after_city,
				"from_country": before_country,
				"to_country": after_country
			})

		var before_class: String = str(before_state.get("social_class", ""))
		var after_class: String = str(after_state.get("social_class", ""))
		if before_class != after_class:
			snapshot_packets.append({
				"type": "class_changed",
				"npc_id": int(npc_id),
				"from": before_class,
				"to": after_class
			})

		var before_job: String = str(before_state.get("job", ""))
		var after_job: String = str(after_state.get("job", ""))
		if before_job != after_job:
			snapshot_packets.append({
				"type": "job_changed",
				"npc_id": int(npc_id),
				"from": before_job,
				"to": after_job
			})

		var before_fame: int = int(before_state.get("fame", 0))
		var after_fame: int = int(after_state.get("fame", 0))
		if abs(after_fame - before_fame) >= 10:
			snapshot_packets.append({
				"type": "fame_shift",
				"npc_id": int(npc_id),
				"from": before_fame,
				"to": after_fame
			})

		var before_health: float = float(before_state.get("health", 0.0))
		var after_health: float = float(after_state.get("health", 0.0))
		if abs(after_health - before_health) >= 20.0:
			snapshot_packets.append({
				"type": "health_swing",
				"npc_id": int(npc_id),
				"from": before_health,
				"to": after_health
			})

		var before_mental: float = float(before_state.get("mental_health", 0.0))
		var after_mental: float = float(after_state.get("mental_health", 0.0))
		if abs(after_mental - before_mental) >= 15.0:
			snapshot_packets.append({
				"type": "mental_swing",
				"npc_id": int(npc_id),
				"from": before_mental,
				"to": after_mental
			})

	return _merge_delta_packets(direct_packets, snapshot_packets)

func _capture_snapshot(groups: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	var seen: Dictionary = {}
	for lane_key in ["near", "mid", "far"]:
		for npc in _get_group_array(groups, lane_key):
			if npc == null:
				continue
			var npc_id: int = int(npc.id)
			if npc_id <= 0 or seen.has(npc_id):
				continue
			seen [npc_id] = true
			snapshot [npc_id] = _build_snapshot_row_for_npc(npc)
	return snapshot
func _build_snapshot_row_for_npc(npc) -> Dictionary:
	if npc == null:
		return {}
	return {
		"id": int(npc.id),
		"name": ("%s %s" % [str(npc.first_name), str(npc.last_name)]).strip_edges(),
		"alive": bool(npc.alive),
		"age": int(npc.age),
		"settlement_id": str(npc.settlement_id),
		"home_city": str(npc.home_city),
		"home_country": str(npc.home_country),
		"social_class": str(npc.social_class),
		"job": str(npc.job),
		"fame": int(npc.fame),
		"health": float(npc.health),
		"mental_health": float(npc.mental_health),
		"bank_balance": float(npc.bank_balance)
	}


func _start_runtime_snapshot_capture_session(
	capture_key: String
) -> void:
	if capture_key == "":
		return

	var zero_frame_tail: bool = bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	)

	var snapshot_required: bool = bool(
		active_year_context.get(
			"runtime_delta_snapshot_required",
			not zero_frame_tail
		)
	)






	if (
		zero_frame_tail
		or not snapshot_required
	):
		active_year_context [
			"runtime_snapshot_capture"
		] = {
			"active": false,
			"capture_key": capture_key,
			"snapshot": {},
			"skipped": true,
			"skip_reason": (
				"zero_frame_age_up_uses_authoritative_direct_delta_packets"
			),
			"blocks_ui": false,
			"requires_input_idle": false
		}

		active_year_context [
			"runtime_snapshot_capture_skipped"
		] = true

		active_year_context [
			"runtime_snapshot_capture_skipped_key"
		] = capture_key

		return

	var existing_raw: Variant = (
		active_year_context.get(
			"runtime_snapshot_capture",
			{}
		)
	)

	var existing: Dictionary = (
		existing_raw as Dictionary
		if typeof(
			existing_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if (
		bool(
			existing.get(
				"active",
				false
			)
		)
		and str(
			existing.get(
				"capture_key",
				""
			)
		) == capture_key
	):
		return

	var loading_raw: Variant = (
		gs.scenario_state.get(
			"loading_runtime",
			{}
		)
		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		)
		else {}
	)

	var loading: Dictionary = (
		loading_raw as Dictionary
		if typeof(
			loading_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var guard_raw: Variant = (
		gs.scenario_state.get(
			"runtime_guard",
			{}
		)
		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		)
		else {}
	)

	var guard: Dictionary = (
		guard_raw as Dictionary
		if typeof(
			guard_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var session_stage: String = str(
		loading.get(
			"session_stage",
			""
		)
	).strip_edges()

	var completion_state: String = str(
		loading.get(
			"completion_state",
			"running"
		)
	).strip_edges()

	var hot_visible_runtime: bool = (
		session_stage in [
			"boot",
			"running",
			"settling_previous_year",
			"settling_current_year"
		]
		and completion_state != "complete"
	)

	var compressed_visible_runtime: bool = (
		hot_visible_runtime
		and (
			bool(
				guard.get(
					"compressed_execution_current_year",
					false
				)
			)
			or bool(
				guard.get(
					"auto_stability_mode",
					false
				)
			)
			or bool(
				guard.get(
					"post_loading_auto_stability",
					false
				)
			)
		)
	)

	var max_items_per_step: int = 96
	var time_budget_ms: int = 3

	if hot_visible_runtime:
		max_items_per_step = 384
		time_budget_ms = 8

	if compressed_visible_runtime:
		max_items_per_step = 640
		time_budget_ms = 10

	active_year_context [
		"runtime_snapshot_capture"
	] = {
		"active": true,
		"capture_key": capture_key,
		"lane_keys": [
			"near",
			"mid",
			"far"
		],
		"lane_index": 0,
		"row_index": 0,
		"snapshot": {},
		"seen": {},
		"max_items_per_step": max_items_per_step,
		"time_budget_ms": time_budget_ms,
	}

func _step_runtime_snapshot_capture(
		max_items: int = 12
) -> Dictionary:
	var state_raw: Variant = active_year_context.get(
		"runtime_snapshot_capture",
		{}
	)
	var state: Dictionary = (
		state_raw
		if typeof(state_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		state.is_empty()
		or not bool(
			state.get(
				"active",
				false
			)
		)
	):
		return {
			"state": "complete",
			"is_complete": true,
			"capture_key": "",
			"snapshot": {},
			"current_micro_lane": "snapshot_capture_idle",
			"phase_progress": 1.0,
			"scanned": 0,
			"captured": 0
		}

	var lane_keys_raw: Variant = state.get(
		"lane_keys",
		[
			"near",
			"mid",
			"far"
		]
	)
	var lane_keys: Array = (
		lane_keys_raw
		if typeof(lane_keys_raw) == TYPE_ARRAY
		else [
			"near",
			"mid",
			"far"
		]
	)

	if lane_keys.is_empty():
		lane_keys = [
			"near",
			"mid",
			"far"
		]

	var lane_index: int = maxi(
		0,
		int(
			state.get(
				"lane_index",
				0
			)
		)
	)
	var row_index: int = maxi(
		0,
		int(
			state.get(
				"row_index",
				0
			)
		)
	)

	var snapshot_raw: Variant = state.get(
		"snapshot",
		{}
	)
	var snapshot: Dictionary = (
		snapshot_raw
		if typeof(snapshot_raw) == TYPE_DICTIONARY
		else {}
	)

	var seen_raw: Variant = state.get(
		"seen",
		{}
	)
	var seen: Dictionary = (
		seen_raw
		if typeof(seen_raw) == TYPE_DICTIONARY
		else {}
	)

	var requested_item_cap: int = maxi(
		1,
		max_items
	)
	var configured_item_cap: int = maxi(
		1,
		int(
			state.get(
				"max_items_per_step",
				requested_item_cap
			)
		)
	)




	var item_cap: int = mini(
		mini(
			requested_item_cap,
			configured_item_cap
		),
		16
	)

	var configured_time_budget_ms: int = maxi(
		1,
		int(
			state.get(
				"time_budget_ms",
				2
			)
		)
	)



	var time_budget_ms: int = mini(
		configured_time_budget_ms,
		2
	)

	var capture_key: String = str(
		state.get(
			"capture_key",
			""
		)
	).strip_edges()
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var scanned_count: int = 0
	var captured_count: int = 0
	var should_yield: bool = false

	while (
		scanned_count < item_cap
		and lane_index < lane_keys.size()
		and not should_yield
	):
		var lane_key: String = str(
			lane_keys [lane_index]
		)
		var people: Array = _get_group_array(
			active_groups,
			lane_key
		)

		while (
			row_index < people.size()
			and scanned_count < item_cap
		):
			var npc = people [row_index]
			row_index += 1
			scanned_count += 1

			if npc != null:
				var npc_id: int = int(npc.id)

				if (
					npc_id > 0
					and not seen.has(npc_id)
				):
					seen [npc_id] = true
					snapshot [npc_id] = (
						_build_snapshot_row_for_npc(
							npc
						)
					)
					captured_count += 1

			if (
				int(Time.get_ticks_msec())
				- started_at_ms
				>= time_budget_ms
			):
				should_yield = true
				break

		if row_index >= people.size():
			lane_index += 1
			row_index = 0

	state ["lane_keys"] = lane_keys
	state ["lane_index"] = lane_index
	state ["row_index"] = row_index
	state ["snapshot"] = snapshot
	state ["seen"] = seen
	state ["active"] = lane_index < lane_keys.size()
	state ["last_quantum_scanned"] = scanned_count
	state ["last_quantum_captured"] = captured_count
	state ["last_quantum_item_cap"] = item_cap
	state ["last_quantum_time_budget_ms"] = time_budget_ms
	state ["last_quantum_at_ms"] = int(
		Time.get_ticks_msec()
	)

	active_year_context [
		"runtime_snapshot_capture"
	] = state

	var prefix: String = "before_snapshot_capture"
	if capture_key == "runtime_slice_after_snapshot":
		prefix = "after_snapshot_capture"

	if lane_index >= lane_keys.size():
		return {
			"state": "complete",
			"is_complete": true,
			"capture_key": capture_key,
			"snapshot": snapshot.duplicate(false),
			"current_micro_lane": "%s_complete" % prefix,
			"phase_progress": 1.0,
			"scanned": scanned_count,
			"captured": captured_count,
			"max_items_per_step": item_cap,
			"time_budget_ms": time_budget_ms,
		}

	var current_lane: String = str(
		lane_keys [lane_index]
	)
	var current_people: Array = _get_group_array(
		active_groups,
		current_lane
	)
	var lane_progress: float = (
		0.0
		if current_people.is_empty()
		else clampf(
			float(row_index)
			/ float(
				maxi(
					1,
					current_people.size()
				)
			),
			0.0,
			1.0
		)
	)
	var phase_progress: float = clampf(
		(
			float(lane_index)
			+ lane_progress
		)
		/ float(
			maxi(
				1,
				lane_keys.size()
			)
		),
		0.0,
		0.98
	)

	return {
		"state": "running",
		"is_complete": false,
		"capture_key": capture_key,
		"snapshot": {},
		"current_micro_lane": "%s_%s" % [
			prefix,
			current_lane
		],
		"phase_progress": phase_progress,
		"scanned": scanned_count,
		"captured": captured_count,
		"max_items_per_step": item_cap,
		"time_budget_ms": time_budget_ms,
	}
func _execute_registered_phase_bridge(
	phase_name: String,
	max_listeners: int = 999
) -> Dictionary:
	var domain_task_report: Dictionary = (
		_execute_registered_phase_domain_tasks(
			phase_name
		)
	)

	if not bool(
		domain_task_report.get(
			"is_complete",
			true
		)
	):
		return {
			"state": "running",
			"is_complete": false,
			"current_phase": phase_name,
			"current_micro_lane": str(
				domain_task_report.get(
					"task_id",
					"domain_task"
				)
			),
			"phase_progress": float(
				domain_task_report.get(
					"progress",
					0.0
				)
			),
			"domain_task_report": (
				domain_task_report.duplicate(
					false
				)
			)
		}

	if gs == null:
		return {
			"state": "complete",
			"is_complete": true,
			"current_phase": phase_name,
			"current_micro_lane": "bridge_idle",
			"domain_task_report": (
				domain_task_report.duplicate(
					false
				)
			)
		}

	var visible_runtime_hot: bool = (
		_visible_age_up_runtime_is_hot()
	)
	var zero_frame_tail: bool = bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	)

	if visible_runtime_hot:
		_install_visible_age_up_runtime_bus_guard(
			phase_name,
			"before_registered_phase_bridge"
		)

	var bridge_result: Dictionary = {
		"state": "complete",
		"is_complete": true,
		"current_phase": phase_name,
		"current_micro_lane": "bridge_complete",
		"domain_task_report": (
			domain_task_report.duplicate(
				false
			)
		)
	}

	if gs.simulation_director != null:
		var cached_bridge_payload: Dictionary = (
			_get_cached_phase_bridge_payload()
		)
		var bridge_context: Dictionary = {
			"year": int(
				active_year_context.get(
					"year",
					gs.year
				)
			),
			"quality_tier": str(
				active_year_context.get(
					"quality_tier",
					QUALITY_BALANCED
				)
			),
			"lane_ids": cached_bridge_payload.get(
				"lane_ids",
				{}
			),
			"groups": cached_bridge_payload.get(
				"groups",
				{}
			),
			"mailboxes": active_mailboxes,
			"delta_sink": self,
			"emit_typed_delta_method": (
				"_emit_typed_delta_packet"
			),
			"runtime_owner": "age_up_runtime",
			"domain_task_report": (
				domain_task_report.duplicate(
					false
				)
			),
			"_runtime_metrics_cache_key": str(
				cached_bridge_payload.get(
					"metrics_cache_key",
					""
				)
			)
		}

		if (
			visible_runtime_hot
			and gs.simulation_director.has_method(
				"step_runtime_phase_bridge"
			)
		):
			bridge_result = (
				gs.simulation_director
				.step_runtime_phase_bridge(
					phase_name,
					bridge_context,
					maxi(
						1,
						max_listeners
					),
					6
				)
			)
		elif (
			not zero_frame_tail
			and gs.simulation_director.has_method(
				"execute_runtime_phase_bridge"
			)
		):
			gs.simulation_director.execute_runtime_phase_bridge(
				phase_name,
				bridge_context
			)

	if typeof(
		bridge_result
	) != TYPE_DICTIONARY:
		bridge_result = {
			"state": "complete",
			"is_complete": true,
			"current_phase": phase_name,
			"current_micro_lane": "bridge_complete"
		}

	bridge_result [
		"domain_task_report"
	] = domain_task_report.duplicate(
		false
	)




	if (
		not zero_frame_tail
		and not visible_runtime_hot
		and gs.event_bus != null
		and gs.event_bus.has_method(
			"flush_deferred"
		)
	):
		var phase_flush_budget: int = 2

		match phase_name:
			"core_state_resolution", \
"internal_identity_drift":
				phase_flush_budget = 6

			"data_defined_simulation_laws":
				phase_flush_budget = 6

			"year_budget_pipeline_commit":
				phase_flush_budget = 10

			"player_phase_contract":
				phase_flush_budget = 4

			"choice_and_opportunity_surfacing", \
"narrative_and_presentation":
				phase_flush_budget = 3

			_:
				phase_flush_budget = 2

		gs.event_bus.flush_deferred(
			phase_flush_budget,
			false
		)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"last_registered_phase_bridge_report"
		] = bridge_result.duplicate(
			false
		)

	return bridge_result

func _get_cached_phase_bridge_payload() -> Dictionary:
	var signature: String = "%d|%d|%d|%d|%s" % [
		int(active_year_context.get("year", gs.year)),
		_group_size("near"),
		_group_size("mid"),
		_group_size("far"),
		str(active_year_context.get("quality_tier", QUALITY_BALANCED))
	]

	var cache_raw: Variant = active_year_context.get("_phase_bridge_payload_cache", {})
	var cache: Dictionary = cache_raw if typeof(cache_raw) == TYPE_DICTIONARY else {}

	if str(cache.get("signature", "")) == signature:
		var cached_payload_raw: Variant = cache.get("payload", {})
		var cached_payload: Dictionary = cached_payload_raw if typeof(cached_payload_raw) == TYPE_DICTIONARY else {}
		if not cached_payload.is_empty():
			return cached_payload.duplicate(true)

	var payload: Dictionary = {
		"lane_ids": _build_phase_bridge_lane_ids(),
		"groups": _build_phase_bridge_groups(),
		"metrics_cache_key": signature
	}

	active_year_context ["_phase_bridge_payload_cache"] = {
		"signature": signature,
		"payload": payload.duplicate(true)
	}
	return payload

func _build_phase_bridge_lane_ids() -> Dictionary:
	return {
		"lane_a": _group_ids_from_people(_get_group_array(active_groups, "near")),
		"lane_b": _group_ids_from_people(_get_group_array(active_groups, "mid")),
		"lane_c": _group_ids_from_people(_get_group_array(active_groups, "far")),
		"lane_d": active_year_context.get("hot_dormant_ids", []).duplicate()
	}

func _build_phase_bridge_groups() -> Dictionary:
	return {
		"lane_a": _get_group_array(active_groups, "near"),
		"lane_b": _get_group_array(active_groups, "mid"),
		"lane_c": _get_group_array(active_groups, "far"),
		"lane_d": []
	}

func _group_ids_from_people(people: Array) -> Array:
	var out: Array = []
	for person in people:
		if person == null:
			continue
		var pid: int = int(person.id)
		if pid <= 0:
			continue
		if pid in out:
			continue
		out.append(pid)
	return out

func _emit_typed_delta_packet(packet: Dictionary) -> void:
	var normalized: Dictionary = _normalize_delta_packet(packet)
	if normalized.is_empty():
		return
	_queue_mailbox("delta_packets", normalized)

func _collect_direct_delta_packets() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var bucket = active_mailboxes.get("delta_packets", [])
	if typeof(bucket) != TYPE_ARRAY:
		return out

	for raw_packet in bucket:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = _normalize_delta_packet(raw_packet)
		if packet.is_empty():
			continue
		var packet_key: String = _delta_packet_key(packet)
		if packet_key == "" or seen.has(packet_key):
			continue
		seen [packet_key] = true
		out.append(packet)

	return out

func _merge_delta_packets(primary_packets: Array, fallback_packets: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_packet in primary_packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = _normalize_delta_packet(raw_packet)
		if packet.is_empty():
			continue
		var packet_key: String = _delta_packet_key(packet)
		if packet_key == "" or seen.has(packet_key):
			continue
		seen [packet_key] = true
		out.append(packet)

	for raw_packet in fallback_packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = _normalize_delta_packet(raw_packet)
		if packet.is_empty():
			continue
		var packet_key: String = _delta_packet_key(packet)
		if packet_key == "" or seen.has(packet_key):
			continue
		seen [packet_key] = true
		out.append(packet)

	return out

func _normalize_delta_packet(packet: Dictionary) -> Dictionary:
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return {}

	var out: Dictionary = packet.duplicate(true)
	var packet_type: String = str(out.get("type", "")).strip_edges()
	if packet_type == "":
		return {}

	out ["type"] = packet_type

	if not out.has("year"):
		out ["year"] = int(active_year_context.get("year", gs.year if gs != null else 0))
	if not out.has("phase"):
		out ["phase"] = str(active_year_context.get("current_phase", ""))
	if not out.has("source"):
		out ["source"] = "typed_phase_packet"

	return out

func _delta_packet_key(packet: Dictionary) -> String:
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return ""

	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(packet.get("type", "")),
		str(packet.get("npc_id", -1)),
		str(packet.get("from", "")),
		str(packet.get("to", "")),
		str(packet.get("from_city", "")),
		str(packet.get("to_city", "")),
		str(packet.get("from_country", "")),
		str(packet.get("to_country", "")),
		str(packet.get("year", "")),
		str(packet.get("phase", ""))
	]
func _queue_mailbox(channel: String, payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY or payload.is_empty():
		return

	var stored_payload: Dictionary = payload.duplicate(true)
	if channel == "delta_packets":
		stored_payload = _normalize_delta_packet(stored_payload)
	if stored_payload.is_empty():
		return

	if not active_mailboxes.has(channel):
		active_mailboxes [channel] = []

	if not active_mailbox_keys.has(channel):
		active_mailbox_keys [channel] = {}

	var mailbox_key: String = _mailbox_payload_key(channel, stored_payload)
	if mailbox_key != "":
		var channel_keys_raw: Variant = active_mailbox_keys.get(channel, {})
		var channel_keys: Dictionary = channel_keys_raw if typeof(channel_keys_raw) == TYPE_DICTIONARY else {}
		if channel_keys.has(mailbox_key):
			return
		channel_keys [mailbox_key] = true
		active_mailbox_keys [channel] = channel_keys

	active_mailboxes [channel].append(stored_payload)

func _group_size(group_key: String) -> int:
	return int(_get_group_array(active_groups, group_key).size())

func _get_group_array(groups, key: String) -> Array:
	if typeof(groups) == TYPE_DICTIONARY:
		var arr = groups.get(key, [])
		if typeof(arr) == TYPE_ARRAY:
			return arr.duplicate()
		return []

	if groups == null:
		return []

	match key:
		"near":
			if "near" in groups:
				return groups.near.duplicate()
		"mid":
			if "mid" in groups:
				return groups.mid.duplicate()
		"far":
			if "far" in groups:
				return groups.far.duplicate()

	return []

func _classify_runtime_groups() -> Dictionary:
	var raw_groups = {}
	if gs != null and gs.spatial_culling_engine != null:
		raw_groups = gs.spatial_culling_engine.classify()

	var bubble: Array = _build_player_bubble(_get_group_array(raw_groups, "near"))
	var social_ring: Array = _build_social_ring(raw_groups, bubble)
	var settlement_lane: Array = _get_group_array(raw_groups, "far")

	return {
		"near": bubble,
		"mid": social_ring,
		"far": settlement_lane
	}

func _build_player_bubble(seed_people: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	_append_unique_person(out, seen, gs.player)

	for npc in seed_people:
		_append_unique_person(out, seen, npc)

	if gs == null or gs.player == null:
		return out

	var p: Person = gs.player

	for pid in p.parents:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(pid)))

	for cid in p.children:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(cid)))

	for fid in p.friends:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(fid)))

	for exid in p.ex_partners:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(exid)))

	for sid in p.schoolmates:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(sid)))

	var partner: Person = gs.get_valid_partner(p, true)
	if partner != null:
		_append_unique_person(out, seen, partner)

	return out

func _build_social_ring(raw_groups, bubble: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for npc in _get_group_array(raw_groups, "mid"):
		_append_unique_person(out, seen, npc)

	if gs != null and gs.social_graph_engine != null:
		for npc in bubble:
			if npc == null:
				continue
			for other_id in gs.social_graph_engine.get_connections(int(npc.id)):
				var other: Person = gs.get_or_reactivate_npc_by_id(int(other_id))
				_append_unique_person(out, seen, other)

	for npc in bubble:
		if npc != null and seen.has(int(npc.id)):
			out.erase(npc)

	return out

func _append_unique_person(out: Array, seen: Dictionary, npc: Person) -> void:
	if npc == null:
		return
	var npc_id: int = int(npc.id)
	if npc_id <= 0:
		return
	if seen.has(npc_id):
		return
	seen [npc_id] = true
	out.append(npc)

func _resolve_quality_tier() -> String:
	if gs == null:
		return QUALITY_BALANCED

	var represented: int = int(gs.npcs.size()) + int(gs.dormant_npcs.size())
	if gs.population_shard_engine != null:
		represented += int(gs.population_shard_engine.get_total_sharded_population())

	if represented > 35000:
		return QUALITY_MASSIVE
	if represented > 7000:
		return QUALITY_BALANCED
	return QUALITY_ULTRA

func _simulate_near_fallback(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.health_engine.update_health(npc)
	gs.career_engine.update_career(npc)
	gs.personality_engine.generate_traits(npc)
	gs.fate_engine.assign_arc(npc)
	gs.desire_engine.yearly_tick(npc)
	gs.goal_planning_engine.yearly_update(npc)
	gs.desire_behavior_bridge.process_npc(npc)
	gs.capability_graph_engine.yearly_growth(npc)

func _simulate_mid_fallback(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.health_engine.update_health(npc)
	gs.career_engine.update_career(npc)
	if randi() % 3 == 0:
		gs.personality_engine.generate_traits(npc)
	if randi() % 4 == 0:
		gs.desire_engine.yearly_tick(npc)

func _simulate_far_fallback(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.spatial_culling_engine.simulate_far_npc(npc)

func _run_world_tail_fallback() -> void:
	gs.simulate_dormant_population()
	gs.world_engine.update_relationships()
	gs.red_bonnet_engine.yearly_spawn_check()
	gs.artifacts_engine.yearly_discovery_chance()
	gs.artifacts_engine.cosmic_consequence()
	gs.dragonballs_engine.yearly_chance()
	gs.many_realms_engine.yearly_discovery_chance()
	gs.fame_engine.random_npc_becomes_famous()
	gs.vehicle_engine.yearly_maintenance()
	gs.emergent_story_engine.yearly_tick()

	if gs.population_lifecycle_manager != null:
		gs.population_lifecycle_manager.yearly_evaluate()
	else:
		gs._soft_unload_npcs()
func _compute_loading_stall_score() -> float:
	var total_runtime_ms: float = 0.0
	if runtime_slice_started_at > 0:
		total_runtime_ms = float(Time.get_ticks_msec() - runtime_slice_started_at)
	else:
		total_runtime_ms = float(last_execution_report.get("total_runtime_ms", 0))

	var pipeline_pressure: float = 0.0
	if gs != null and gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
		pipeline_pressure = 28.0

	var phase_weight: float = 0.0
	var current_phase: String = str(active_year_context.get("current_phase", ""))
	if current_phase == "year_budget_pipeline_commit":
		phase_weight = 18.0
	elif current_phase == "internal_identity_drift":
		phase_weight = 8.0

	return clamp((total_runtime_ms / 22.0) + pipeline_pressure + phase_weight, 0.0, 100.0)


func _update_loading_runtime_bucket(extra: Dictionary = {}) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var bucket_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
	if bucket.is_empty():
		return

	var total_runtime_ms: int = 0
	if runtime_slice_started_at > 0:
		total_runtime_ms = int(Time.get_ticks_msec() - runtime_slice_started_at)
	else:
		total_runtime_ms = int(last_execution_report.get("total_runtime_ms", 0))

	var current_phase: String = str(active_year_context.get("current_phase", bucket.get("current_phase", "preflight")))
	var current_lane: String = "boot"
	match current_phase:
		"core_state_resolution":
			current_lane = "lane_a"
		"internal_identity_drift":
			current_lane = "lane_b"
		"year_budget_pipeline_commit":
			current_lane = "lane_c"
		"player_phase_contract":
			current_lane = "player_contract"
		"choice_and_opportunity_surfacing":
			current_lane = "lane_b"
		"narrative_and_presentation":
			current_lane = "presentation"
		"commit_settling":
			current_lane = "lane_c_tail"

	var player_micro_lane: String = str(extra.get("current_micro_lane", bucket.get("current_micro_lane", ""))).strip_edges()
	if player_micro_lane != "":
		current_lane = "player_contract:%s" % player_micro_lane

	var deferred_jobs: Array = []
	var report_deferred_raw: Variant = last_execution_report.get("deferred_jobs", [])
	if typeof(report_deferred_raw) == TYPE_ARRAY:
		deferred_jobs = report_deferred_raw.duplicate(true)

	var year_pipeline_pending: bool = false
	var year_pipeline_stage: int = 0
	if gs.year_budget_engine != null:
		year_pipeline_pending = bool(gs.year_budget_engine.has_pending_year_pipeline())
		year_pipeline_stage = int(gs.year_budget_engine.pipeline_stage)

	if year_pipeline_pending:
		deferred_jobs.append({
			"job": "year_budget_pipeline",
			"stage": year_pipeline_stage,
			"pending": true
		})

	var report_signature: String = "%s|%s|%d|%d|%d|%d|%d|%d" % [
		current_phase,
		current_lane,
		int(runtime_slice_phase_cursor),
		int(runtime_slice_order.size()),
		int(floor(float(total_runtime_ms) / 24.0)),
		year_pipeline_stage,
		deferred_jobs.size(),
		1 if year_pipeline_pending else 0
	]
	var last_report_signature: String = str(active_year_context.get("_loading_bucket_report_signature", ""))
	var refresh_report: bool = report_signature != last_report_signature or bool(extra.get("force_report_refresh", false)) or bool(extra.get("is_complete", false))
	active_year_context ["_loading_bucket_report_signature"] = report_signature

	var phase_progress_bucket: int = int(round(float(extra.get("phase_progress", bucket.get("phase_progress", 0.0))) * 100.0))
	var write_signature: String = "%s|%s|%d|%d|%d|%d|%d|%s|%s" % [
		current_phase,
		current_lane,
		int(runtime_slice_phase_cursor),
		int(runtime_slice_order.size()),
		int(floor(float(total_runtime_ms) / 24.0)),
		year_pipeline_stage,
		phase_progress_bucket,
		str(extra.get("completion_state", bucket.get("completion_state", "running"))),
		str(extra.get("current_micro_lane", bucket.get("current_micro_lane", "")))
	]
	var last_write_signature: String = str(active_year_context.get("_loading_bucket_write_signature", ""))
	var force_bucket_write: bool = bool(extra.get("force_bucket_write", false)) or bool(extra.get("is_complete", false))
	if not force_bucket_write and write_signature == last_write_signature:
		return
	active_year_context ["_loading_bucket_write_signature"] = write_signature

	var phase_timings: Dictionary = {}
	if refresh_report or not bucket.has("phase_durations_ms"):
		phase_timings = runtime_slice_phase_timings.duplicate(true)
		if phase_timings.is_empty():
			phase_timings = last_execution_report.get("phase_timings_ms", {}).duplicate(true)
	else:
		var cached_phase_timings_raw: Variant = bucket.get("phase_durations_ms", {})
		phase_timings = cached_phase_timings_raw if typeof(cached_phase_timings_raw) == TYPE_DICTIONARY else {}

	var budget_consumption: Dictionary = {
		"phase_steps_consumed": int(runtime_slice_phase_cursor),
		"phase_steps_total": int(runtime_slice_order.size()),
		"year_pipeline_pending": year_pipeline_pending,
		"year_pipeline_stage": year_pipeline_stage,
		"runtime_ms": total_runtime_ms
	}

	bucket ["current_phase"] = current_phase
	bucket ["current_lane"] = current_lane
	if not bucket.has("phase_order") or bool(extra.get("force_phase_order_refresh", false)):
		bucket ["phase_order"] = runtime_slice_order.duplicate(true) if not runtime_slice_order.is_empty() else active_year_context.get("phase_order", []).duplicate(true)
	bucket ["phase_index"] = int(runtime_slice_phase_cursor)
	bucket ["phase_durations_ms"] = phase_timings
	bucket ["total_runtime_ms"] = total_runtime_ms
	bucket ["stall_score"] = _compute_loading_stall_score()
	bucket ["runtime_weight"] = clamp(float(total_runtime_ms) / 380.0, 0.0, 1.0)
	bucket ["deferred_jobs"] = deferred_jobs
	bucket ["budget_consumption"] = budget_consumption
	bucket ["year_pipeline_pending"] = year_pipeline_pending
	bucket ["year_pipeline_stage"] = year_pipeline_stage
	bucket ["quality_tier"] = str(active_year_context.get("quality_tier", "balanced"))

	if refresh_report:
		bucket ["last_runtime_report"] = last_execution_report.duplicate(true)

	for key in extra.keys():
		bucket [key] = extra [key]

	gs.scenario_state ["loading_runtime"] = bucket
	if gs.live_diagnostics_engine != null:
		gs.live_diagnostics_engine.observe_loading_bucket(bucket)
func _live_slice_streaming_enabled() -> bool:
	if gs == null:
		return false







	var runtime_owner: String = str(
		active_year_context.get(
			"runtime_owner",
			"age_up_runtime"
		)
	).strip_edges().to_lower()

	var zero_frame_tail: bool = bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	)

	if zero_frame_tail:
		return false

	if runtime_owner in [
		"age_up_runtime",
		"age_up_runtime_engine",
		"zero_frame_tail_runtime",
		"life_engine"
	]:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false




	return bool(
		gs.scenario_state.get(
			"age_up_live_slice_streaming_enabled",
			false
		)
	)


func _ensure_temporal_slice_runtime() -> bool:
	if gs == null:
		return false

	if not "temporal_slice_transformation_runtime" in gs:
		return false







	return (
		gs.temporal_slice_transformation_runtime != null
	)

func _step_temporal_slice_streaming_walker(max_transforms: int = 1, max_budget_ms: int = 6) -> Dictionary:
	if not _live_slice_streaming_enabled():
		return {
			"state": "complete",
			"is_complete": true,
			"current_phase": "year_and_era_mutation",
			"current_micro_lane": "live_slice_streaming_disabled",
			"progress": 1.0
		}

	if not _ensure_temporal_slice_runtime():
		return {
			"state": "complete",
			"is_complete": true,
			"current_phase": "year_and_era_mutation",
			"current_micro_lane": "temporal_runtime_unavailable",
			"progress": 1.0
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var time_contract_raw: Variant = gs.scenario_state.get("age_up_time_contract", {})
	var time_contract: Dictionary = time_contract_raw if typeof(time_contract_raw) == TYPE_DICTIONARY else {}

	var source_year: int = int(time_contract.get("source_year", gs.scenario_state.get("age_up_started_from_year", gs.year)))
	var source_age: int = int(time_contract.get("source_age", gs.scenario_state.get("age_up_started_from_age", gs.player.age if gs.player != null else 0)))
	var target_year: int = int(time_contract.get("target_year", gs.scenario_state.get("age_up_requested_year", source_year + 1)))
	var target_age: int = int(time_contract.get("target_age", gs.scenario_state.get("age_up_truth_expected_target_age", source_age + 1)))

	if target_year <= source_year:
		target_year = source_year + 1

	if target_age <= source_age:
		target_age = source_age + 1

	active_year_context ["year"] = target_year
	active_year_context ["committed_year"] = target_year
	active_year_context ["contract_source_year"] = source_year
	active_year_context ["contract_target_year"] = target_year
	active_year_context ["contract_source_age"] = source_age
	active_year_context ["contract_target_age"] = target_age

	if not gs.temporal_slice_transformation_runtime.is_streaming_transaction_active():
		gs.temporal_slice_transformation_runtime.begin_age_up_streaming_transaction({
			"source": "age_up_runtime.year_and_era_mutation",
			"runtime_owner": "age_up_runtime",
			"target_year": target_year,
			"player_id": int(active_year_context.get("player_id", int(gs.player.id) if gs.player != null else -1)),
			"entity_scope": "player_bubble",
			"age_up_contracts": active_year_context.get("age_up_contracts", []),
			"time_contract": time_contract.duplicate(true),
			"contract_source_year": source_year,
			"contract_target_year": target_year,
			"contract_source_age": source_age,
			"contract_target_age": target_age
		})

	var step_report: Dictionary = gs.temporal_slice_transformation_runtime.step_age_up_streaming_transaction(max_transforms, max_budget_ms)
	var complete: bool = bool(step_report.get("is_complete", false))

	if complete:
		if not gs.year_locked:
			gs.year = target_year

		if gs.player != null:
			gs.player.age = target_age

		active_year_context ["year_and_era_mutation_complete"] = true
		active_year_context ["completed_year"] = target_year
		active_year_context ["completed_player_age"] = target_age
		active_year_context ["temporal_slice_streaming_applied"] = true
		active_year_context ["temporal_slice_report"] = step_report.get("result", {})

		gs.scenario_state ["temporal_slice_streaming_applied"] = true
		gs.scenario_state ["temporal_slice_streaming_year"] = target_year

	return {
		"state": "complete" if complete else "running",
		"is_complete": complete,
		"current_phase": "year_and_era_mutation",
		"current_micro_lane": str(step_report.get("current_micro_lane", "temporal_slice_streaming")),
		"progress": float(step_report.get("progress", 1.0 if complete else 0.5)),
		"temporal_report": step_report.duplicate(true),
		"time_authority": "age_up_time_contract",
		"source_year": source_year,
		"target_year": target_year,
		"source_age": source_age,
		"target_age": target_age
	}
func _fallback_age_up_phase_order() -> Array:
	return [
		"year_and_era_mutation",
		"core_state_resolution",
		"internal_identity_drift",
		"data_defined_simulation_laws",
		"year_budget_pipeline_commit",
		"player_phase_contract",
		"choice_and_opportunity_surfacing",
		"narrative_and_presentation"
	]


func _refresh_contract_runtime_scheduler(overlay_context: Dictionary = {}) -> Dictionary:
	var scheduler: Dictionary = {}

	if gs != null and gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("get_runtime_phase_scheduler_context"):
		scheduler = gs.game_state_contract_engine.get_runtime_phase_scheduler_context({
			"runtime_kind": "age_up",
			"year": int(gs.year if gs != null else 0),
			"player_age": int(gs.player.age) if gs != null and gs.player != null else -1,
			"frame_budget_ms": int(overlay_context.get("frame_budget_ms", 6)),
			"visible_watchdog_ms": int(overlay_context.get("visible_watchdog_ms", 5200)),
			"force_complete_ms": int(overlay_context.get("force_complete_ms", 8200))
		})

	if scheduler.is_empty():
		scheduler = {
			"runtime_kind": "age_up",
			"phase_order": _fallback_age_up_phase_order(),
			"phase_contracts": {},
			"frame_budget_ms": 6,
			"visible_watchdog_ms": 5200,
			"force_complete_ms": 8200
		}

	runtime_contract_scheduler = scheduler.duplicate(true)

	var contracts_raw: Variant = scheduler.get("phase_contracts", {})
	runtime_phase_contracts = contracts_raw if typeof(contracts_raw) == TYPE_DICTIONARY else {}

	var order_raw: Variant = scheduler.get("phase_order", [])
	var order: Array = order_raw if typeof(order_raw) == TYPE_ARRAY else []
	if order.is_empty():
		order = _fallback_age_up_phase_order()

	runtime_slice_order = order.duplicate(true)
	active_year_context ["phase_order"] = runtime_slice_order.duplicate(true)

	runtime_slice_visible_watchdog_ms = max(1200, int(scheduler.get("visible_watchdog_ms", 5200)))
	runtime_slice_force_complete_ms = max(runtime_slice_visible_watchdog_ms + 1200, int(scheduler.get("force_complete_ms", 8200)))

	return scheduler


func _phase_contract_for(phase_id: String) -> Dictionary:
	var clean_phase: String = str(phase_id).strip_edges()
	var raw: Variant = runtime_phase_contracts.get(clean_phase, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _hard_budget_for_phase(phase_id: String) -> int:
	var contract: Dictionary = _phase_contract_for(phase_id)
	return max(1, int(contract.get("hard_budget_ms", contract.get("budget_ms", 12))))


func _soft_budget_for_phase(phase_id: String) -> int:
	var contract: Dictionary = _phase_contract_for(phase_id)
	return max(1, int(contract.get("soft_budget_ms", contract.get("budget_ms", 4))))


func _record_phase_overflow_if_needed(phase_id: String, elapsed_ms: int) -> Dictionary:
	var hard_budget_ms: int = _hard_budget_for_phase(phase_id)
	var soft_budget_ms: int = _soft_budget_for_phase(phase_id)

	if elapsed_ms < soft_budget_ms:
		return {}

	var report:= {
		"phase_id": str(phase_id),
		"elapsed_ms": elapsed_ms,
		"soft_budget_ms": soft_budget_ms,
		"hard_budget_ms": hard_budget_ms,
		"overflow_level": "hard" if elapsed_ms >= hard_budget_ms else "soft",
		"degradation_applied": false,
		"recorded_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("record_runtime_phase_overflow"):
		var contract_report: Dictionary = gs.game_state_contract_engine.record_runtime_phase_overflow(str(phase_id), elapsed_ms, {
			"source": "AgeUpRuntimeEngine.run_year_runtime_slice",
			"phase_cursor": int(runtime_slice_phase_cursor),
			"phase_count": int(runtime_slice_order.size()),
			"commit_budget_cap": 2,
			"phase_budget_cap": 1
		})
		report ["contract_report"] = contract_report.duplicate(true)
		report ["degradation_applied"] = true

	runtime_phase_overflow_log.append(report)
	if runtime_phase_overflow_log.size() > 80:
		runtime_phase_overflow_log = runtime_phase_overflow_log.slice(runtime_phase_overflow_log.size() - 80, runtime_phase_overflow_log.size())

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["age_up_runtime_phase_overflow_log"] = runtime_phase_overflow_log.duplicate(true)

	return report


func _visible_runtime_elapsed_ms() -> int:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)



	if bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	):
		if runtime_slice_started_at <= 0:
			return 0

		return maxi(
			0,
			now_ms - runtime_slice_started_at
		)

	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return 0

	var loading_raw: Variant = gs.scenario_state.get(
		"loading_runtime",
		{}
	)
	var loading: Dictionary = (
		loading_raw
		if typeof(loading_raw) == TYPE_DICTIONARY
		else {}
	)

	var started_ms: int = int(
		loading.get(
			"visible_started_at_ms",
			loading.get(
				"started_at_ms",
				runtime_slice_started_at
			)
		)
	)

	if started_ms <= 0:
		started_ms = runtime_slice_started_at

	if started_ms <= 0:
		return 0

	return maxi(
		0,
		now_ms - started_ms
	)


func _age_up_runtime_watchdog_result(
	reason: String
) -> Dictionary:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var current_phase: String = str(
		active_year_context.get(
			"current_phase",
			"preflight"
		)
	).strip_edges()

	var report: Dictionary = {
		"state": "running",
		"is_complete": false,
		"current_phase": current_phase,
		"current_micro_lane": "WATCHDOG_PRESSURE",
		"watchdog_pressure": true,
		"watchdog_resolved": false,
		"watchdog_reason": reason,
		"runtime_report": last_execution_report.duplicate(false),
		"at_ms": now_ms
	}






	active_year_context [
		"watchdog_pressure"
	] = true

	active_year_context [
		"watchdog_reason"
	] = reason

	active_year_context [
		"watchdog_pressure_at_ms"
	] = now_ms

	active_year_context [
		"watchdog_force_completion_forbidden"
	] = true

	active_year_context [
		"transaction_complete"
	] = false

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"last_age_up_runtime_watchdog_pressure"
		] = report.duplicate(false)

		gs.scenario_state [
			"age_up_runtime_watchdog_force_completion_forbidden"
		] = true

		gs.scenario_state [
			"age_up_runtime_required_receipts_still_authoritative"
		] = true

		var loading_raw: Variant = (
			gs.scenario_state.get(
				"loading_runtime",
				{}
			)
		)

		var loading: Dictionary = (
			(loading_raw as Dictionary).duplicate(false)
			if typeof(
				loading_raw
			) == TYPE_DICTIONARY
			else {}
		)

		if not loading.is_empty():
			loading [
				"watchdog_pressure"
			] = true

			loading [
				"watchdog_resolved"
			] = false

			loading [
				"watchdog_reason"
			] = reason

			loading [
				"watchdog_force_completion_forbidden"
			] = true

			loading [
				"tail_runtime_pending"
			] = true

			loading [
				"completion_state"
			] = "running"

			loading [
				"is_complete"
			] = false

			loading [
				"current_phase"
			] = current_phase

			gs.scenario_state [
				"loading_runtime"
			] = loading

	return report
func _check_visible_runtime_watchdog() -> Dictionary:
	var elapsed_ms: int = _visible_runtime_elapsed_ms()
	if elapsed_ms <= 0:
		return {}

	var current_phase: String = str(active_year_context.get("current_phase", "preflight"))
	var force_limit: int = max(runtime_slice_force_complete_ms, runtime_slice_visible_watchdog_ms + 1200)

	if elapsed_ms >= force_limit:
		var _overflow_report: Dictionary = _record_phase_overflow_if_needed(current_phase, elapsed_ms)
		return _age_up_runtime_watchdog_result("visible_runtime_force_complete_%dms" % elapsed_ms)

	if elapsed_ms >= runtime_slice_visible_watchdog_ms:
		var overflow: Dictionary = _record_phase_overflow_if_needed(current_phase, elapsed_ms)
		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": current_phase,
			"current_micro_lane": "PHASE_OVERFLOW",
			"phase_overflow_report": overflow,
			"subline": "Reality spiked. Compressing noncritical systems..."
		})

	return {}
func begin_runtime_slice_session() -> Dictionary:
	if gs == null:
		return {}

	if runtime_slice_active:
		if runtime_slice_order.is_empty():
			_refresh_contract_runtime_scheduler(
				{}
			)

		if runtime_slice_order.is_empty():
			runtime_slice_order = (
				_fallback_age_up_phase_order()
			)

		if str(
			active_year_context.get(
				"current_phase",
				""
			)
		).strip_edges() == "":
			active_year_context [
				"current_phase"
			] = "preflight"

		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": str(
				active_year_context.get(
					"current_phase",
					"preflight"
				)
			),
			"phase_order": runtime_slice_order.duplicate(false),
			"phase_index": int(
				runtime_slice_phase_cursor
			)
		})

		return active_year_context.duplicate(false)

	if (
		not runtime_slice_active
		and bool(
			active_year_context.get(
				"transaction_complete",
				false
			)
		)
	):
		active_year_context = {}

	if active_year_context.is_empty():
		begin_year_transaction({
			"mode": "living",
			"year": int(
				gs.year + 1
			),
			"player_id": (
				int(
					gs.player.id
				)
				if gs.player != null
				else -1
			),
			"runtime_owner": "age_up_runtime"
		})

	var zero_frame_tail: bool = bool(
		active_year_context.get(
			"zero_frame_tail",
			false
		)
	)





	if active_groups.is_empty():
		if zero_frame_tail:
			active_groups = {
				"near": [],
				"mid": [],
				"far": []
			}

			active_year_context [
				"runtime_group_projection_pending"
			] = true

			active_year_context [
				"runtime_group_classification_on_age_up"
			] = false
		else:
			active_groups = (
				_classify_runtime_groups()
			)

	runtime_phase_walkers = {}
	runtime_slice_active = true
	runtime_slice_phase_cursor = 0
	runtime_slice_phase_timings = {}
	runtime_slice_started_at = int(
		Time.get_ticks_msec()
	)

	var loading: Dictionary = {}



	if (
		not zero_frame_tail
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		var loading_raw: Variant = (
			gs.scenario_state.get(
				"loading_runtime",
				{}
			)
		)

		if typeof(
			loading_raw
		) == TYPE_DICTIONARY:
			loading = (
				loading_raw as Dictionary
			).duplicate(false)

	var overlay_context_raw: Variant = (
		loading.get(
			"overlay_context",
			{}
		)
	)

	var overlay_context: Dictionary = (
		overlay_context_raw as Dictionary
		if typeof(
			overlay_context_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var startup_soft_enabled: bool = (
		not zero_frame_tail
		and not loading.is_empty()
	)

	var first_visible_runtime_boot: bool = bool(
		overlay_context.get(
			"first_visible_runtime_boot",
			false
		)
	)

	var startup_soft_slice_frames_default: int = (
		5
		if first_visible_runtime_boot
		else 3
	)

	var startup_soft_slice_ms_default: int = (
		80
		if first_visible_runtime_boot
		else 48
	)

	var startup_soft_defer_snapshot_frames_default: int = (
		1
		if first_visible_runtime_boot
		else 0
	)

	var startup_soft_defer_snapshot_ms_default: int = (
		20
		if first_visible_runtime_boot
		else 0
	)

	var snapshot_items_per_step_default: int = (
		96
		if first_visible_runtime_boot
		else 128
	)

	var startup_soft_defer_snapshot: bool = (
		not zero_frame_tail
		and startup_soft_enabled
		and bool(
			overlay_context.get(
				"startup_soft_defer_before_snapshot",
				false
			)
		)
	)

	runtime_slice_before_snapshot = {}

	active_year_context [
		"runtime_snapshot_capture"
	] = {}

	active_year_context [
		"runtime_delta_snapshot_required"
	] = not zero_frame_tail

	active_year_context [
		"runtime_delta_snapshot_skipped_for_zero_frame_age_up"
	] = zero_frame_tail

	active_year_context [
		"snapshot_bookkeeping_is_completion_gate"
	] = false

	_refresh_contract_runtime_scheduler(
		overlay_context
	)

	if runtime_slice_order.is_empty():
		runtime_slice_order = (
			_fallback_age_up_phase_order()
		)

	active_year_context [
		"current_phase"
	] = "preflight"

	active_year_context [
		"runtime_contract_scheduler"
	] = runtime_contract_scheduler.duplicate(false)

	active_year_context [
		"phase_order"
	] = runtime_slice_order.duplicate(false)

	active_year_context [
		"startup_soft_loading_mode"
	] = startup_soft_enabled

	active_year_context [
		"startup_soft_slice_frames_remaining"
	] = (
		maxi(
			0,
			int(
				overlay_context.get(
					"startup_soft_slice_frames",
					startup_soft_slice_frames_default
				)
			)
		)
		if startup_soft_enabled
		else 0
	)

	active_year_context [
		"startup_soft_slice_until_ms"
	] = (
		int(
			Time.get_ticks_msec()
		) + maxi(
			0,
			int(
				overlay_context.get(
					"startup_soft_slice_ms",
					startup_soft_slice_ms_default
				)
			)
		)
		if startup_soft_enabled
		else 0
	)

	active_year_context [
		"startup_soft_phase_budget_cap"
	] = (
		maxi(
			2,
			int(
				overlay_context.get(
					"startup_soft_phase_budget_cap",
					2
				)
			)
		)
		if startup_soft_enabled
		else maxi(
			2,
			int(
				active_year_context.get(
					"startup_soft_phase_budget_cap",
					2
				)
			)
		)
	)

	active_year_context [
		"startup_soft_commit_budget_cap"
	] = (
		maxi(
			12,
			int(
				overlay_context.get(
					"startup_soft_commit_budget_cap",
					16
				)
			)
		)
		if startup_soft_enabled
		else maxi(
			12,
			int(
				active_year_context.get(
					"startup_soft_commit_budget_cap",
					16
				)
			)
		)
	)

	active_year_context [
		"runtime_snapshot_items_per_step"
	] = (
		maxi(
			48,
			int(
				overlay_context.get(
					"runtime_snapshot_items_per_step",
					snapshot_items_per_step_default
				)
			)
		)
		if startup_soft_enabled
		else maxi(
			48,
			int(
				active_year_context.get(
					"runtime_snapshot_items_per_step",
					snapshot_items_per_step_default
				)
			)
		)
	)

	active_year_context [
		"deferred_before_snapshot_capture"
	] = startup_soft_defer_snapshot

	active_year_context [
		"deferred_before_snapshot_frames_remaining"
	] = (
		maxi(
			0,
			int(
				overlay_context.get(
					"startup_soft_defer_before_snapshot_frames",
					startup_soft_defer_snapshot_frames_default
				)
			)
		)
		if startup_soft_defer_snapshot
		else 0
	)

	active_year_context [
		"deferred_before_snapshot_until_ms"
	] = (
		int(
			Time.get_ticks_msec()
		) + maxi(
			0,
			int(
				overlay_context.get(
					"startup_soft_defer_before_snapshot_ms",
					startup_soft_defer_snapshot_ms_default
				)
			)
		)
		if startup_soft_defer_snapshot
		else 0
	)

	if (
		not startup_soft_defer_snapshot
		and not zero_frame_tail
	):
		_start_runtime_snapshot_capture_session(
			"runtime_slice_before_snapshot"
		)

	_update_loading_runtime_bucket({
		"completion_state": "running",
		"is_complete": false,
		"phase_order": runtime_slice_order.duplicate(false),
		"phase_index": 0,
		"zero_frame_tail": zero_frame_tail,
	})

	return active_year_context.duplicate(false)

func _finalize_runtime_slice_session() -> Dictionary:
	var capture_state_raw: Variant = active_year_context.get(
		"runtime_snapshot_capture",
		{}
	)
	var capture_state: Dictionary = (
		capture_state_raw
		if typeof(capture_state_raw) == TYPE_DICTIONARY
		else {}
	)

	if not bool(capture_state.get("active", false)):
		_start_runtime_snapshot_capture_session(
			"runtime_slice_after_snapshot"
		)
		capture_state_raw = active_year_context.get(
			"runtime_snapshot_capture",
			{}
		)
		capture_state = (
			capture_state_raw
			if typeof(capture_state_raw) == TYPE_DICTIONARY
			else {}
		)

	var configured_items_per_step: int = maxi(
		1,
		int(
			active_year_context.get(
				"runtime_snapshot_items_per_step",
				12
			)
		)
	)
	var capture_items_per_step: int = mini(
		configured_items_per_step,
		16
	)

	var capture_step: Dictionary = _step_runtime_snapshot_capture(
		capture_items_per_step
	)
	if not bool(
		capture_step.get(
			"is_complete",
			false
		)
	):
		return {
			"state": "running",
			"is_complete": false,
			"current_phase": "finalize",
			"current_micro_lane": str(
				capture_step.get(
					"current_micro_lane",
					"after_snapshot_capture"
				)
			),
			"phase_progress": float(
				capture_step.get(
					"phase_progress",
					0.0
				)
			)
		}

	var after_snapshot_raw: Variant = capture_step.get(
		"snapshot",
		{}
	)
	var after_snapshot: Dictionary = (
		after_snapshot_raw
		if typeof(after_snapshot_raw) == TYPE_DICTIONARY
		else {}
	)
	active_year_context ["runtime_snapshot_capture"] = {}

	var direct_packets: Array = _collect_direct_delta_packets()
	last_delta_packets = _build_delta_packets(
		runtime_slice_before_snapshot,
		after_snapshot,
		direct_packets
	)
	active_mailboxes [
		"delta_packets"
	] = last_delta_packets.duplicate(false)

	last_execution_report [
		"phase_order"
	] = runtime_slice_order.duplicate(false)
	last_execution_report [
		"phase_timings_ms"
	] = runtime_slice_phase_timings.duplicate(false)
	last_execution_report [
		"total_runtime_ms"
	] = int(
		Time.get_ticks_msec() - runtime_slice_started_at
	)
	last_execution_report [
		"generated_world_feed_entries"
	] = int(
		active_mailboxes.get(
			"world_feed",
			[]
		).size()
	)
	last_execution_report [
		"generated_popups"
	] = int(
		active_mailboxes.get(
			"popups",
			[]
		).size()
	)
	last_execution_report [
		"generated_scenarios"
	] = int(
		active_mailboxes.get(
			"scenario",
			[]
		).size()
	)
	last_execution_report [
		"phase_mailboxes"
	] = active_mailboxes.duplicate(false)
	last_execution_report [
		"delta_packet_count"
	] = int(last_delta_packets.size())

	if gs.scenario_state != null:
		gs.scenario_state [
			"last_runtime_report"
		] = last_execution_report.duplicate(false)
		gs.scenario_state [
			"last_runtime_delta_packets"
		] = last_delta_packets.duplicate(false)

	var stored_result_raw: Variant = gs.scenario_state.get(
		"post_runtime_result",
		{}
	)
	if (
		typeof(stored_result_raw) == TYPE_DICTIONARY
		and not stored_result_raw.is_empty()
	):
		var stored_result: Dictionary = (
			stored_result_raw as Dictionary
		).duplicate(false)
		stored_result [
			"runtime_report"
		] = last_execution_report.duplicate(false)
		gs.scenario_state [
			"post_runtime_result"
		] = stored_result

	runtime_slice_active = false
	active_year_context [
		"current_phase"
	] = "complete"
	active_year_context [
		"transaction_complete"
	] = true
	active_year_context [
		"transaction_completed_at_ms"
	] = int(Time.get_ticks_msec())
	active_year_context [
		"completed_year"
	] = (
		int(gs.year)
		if gs != null
		else int(
			active_year_context.get(
				"year",
				0
			)
		)
	)
	active_year_context [
		"completed_player_age"
	] = (
		int(gs.player.age)
		if gs != null and gs.player != null
		else -1
	)

	var completion_result_raw: Variant = (
		gs.scenario_state.get(
			"post_runtime_result",
			{}
		)
		if gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
		else {}
	)
	var completion_result: Dictionary = (
		completion_result_raw
		if typeof(completion_result_raw) == TYPE_DICTIONARY
		else {}
	)

	if completion_result.is_empty():
		completion_result = {
			"type": "year_passed",
			"text": "Another year passed.",
			"opps": []
		}

	if not completion_result.has("year") and gs != null:
		completion_result ["year"] = int(gs.year)

	if (
		not completion_result.has("age")
		and gs != null
		and gs.player != null
	):
		completion_result ["age"] = int(gs.player.age)




	if (
		gs != null
		and gs.player != null
		and gs.life_diary_contract_engine != null
		and gs.life_diary_contract_engine.has_method(
			"emit_diary_intent"
		)
	):
		var annual_diary_lines: Array = []
		var annual_diary_seen: Dictionary = {}

		var completion_text: String = str(
			completion_result.get(
				"text",
				""
			)
		).strip_edges()

		if completion_text != "":
			for raw_line in completion_text.split("\n"):
				var line_text: String = str(
					raw_line
				).strip_edges()
				if (
					line_text == ""
					or annual_diary_seen.has(line_text)
				):
					continue
				annual_diary_seen [line_text] = true
				annual_diary_lines.append(line_text)

		var popup_rows_raw: Variant = active_mailboxes.get(
			"popups",
			[]
		)
		var popup_rows: Array = (
			popup_rows_raw
			if typeof(popup_rows_raw) == TYPE_ARRAY
			else []
		)

		for popup_raw in popup_rows:
			if typeof(popup_raw) != TYPE_DICTIONARY:
				continue

			var popup_row: Dictionary = popup_raw as Dictionary
			if str(
				popup_row.get(
					"type",
					""
				)
			) != "death_notice":
				continue

			var death_text: String = str(
				popup_row.get(
					"text",
					""
				)
			).strip_edges()

			if (
				death_text == ""
				or annual_diary_seen.has(death_text)
			):
				continue

			annual_diary_seen [death_text] = true
			annual_diary_lines.append(death_text)

		var diary_year: int = int(
			completion_result.get(
				"year",
				gs.year
			)
		)
		var diary_age: int = int(
			completion_result.get(
				"age",
				gs.player.age
			)
		)

		for raw_line in annual_diary_lines:
			var line_text: String = str(
				raw_line
			).strip_edges()
			if line_text == "":
				continue

			gs.life_diary_contract_engine.emit_diary_intent(
				{
					"type": "legacy_text",
					"actor_id": int(gs.player.id),
					"year": diary_year,
					"age": diary_age,
					"text": line_text,
					"source": "age_up_runtime",
					"append_to_current_year_block": true,
					"dedupe_key": "age_up_runtime|%d|%d|%d|%d" % [
						int(gs.player.id),
						diary_year,
						diary_age,
						line_text.hash()
					],
					"meta": {
					}
				},
				{
					"source": (
						"age_up_runtime."
						+ "finalize_runtime_slice_session"
					)
				}
			)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"post_runtime_result"
		] = completion_result.duplicate(false)

	_update_loading_runtime_bucket({
		"completion_state": "complete",
		"is_complete": true,
		"current_phase": "complete",
		"session_stage": "complete",
		"subline": "",
		"final_result": completion_result.duplicate(false),
		"resolved_result": completion_result.duplicate(false)
	})

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"age_up_deferred_flush_pending"
		] = true
		gs.scenario_state [
			"age_up_deferred_flush_next_ms"
		] = 0



	return {
		"state": "complete",
		"is_complete": true,
		"runtime_report": last_execution_report.duplicate(false)
	}
func run_year_runtime_slice(max_phase_steps: int = 1, max_commit_stages: int = 12) -> Dictionary:
	if gs == null:
		return {}

	if not runtime_slice_active:
		begin_runtime_slice_session()

	if runtime_contract_scheduler.is_empty():
		_refresh_contract_runtime_scheduler({})

	var watchdog_result: Dictionary = _check_visible_runtime_watchdog()
	if bool(watchdog_result.get("is_complete", false)):
		return watchdog_result

	var effective_phase_steps: int = clamp(int(max_phase_steps), 1, 1)
	var effective_commit_stages: int = clamp(int(max_commit_stages), 1, 3)

	var loading_raw: Variant = gs.scenario_state.get("loading_runtime", {}) if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	var loading: Dictionary = loading_raw if typeof(loading_raw) == TYPE_DICTIONARY else {}
	var overlay_context_raw: Variant = loading.get("overlay_context", {})
	var overlay_context: Dictionary = overlay_context_raw if typeof(overlay_context_raw) == TYPE_DICTIONARY else {}

	var visible_session_stage: String = str(loading.get("session_stage", "")).strip_edges()
	var _visible_phase_hint: String = str(loading.get("current_phase", "")).strip_edges()
	var hot_visible_runtime: bool = visible_session_stage in [
		"boot",
		"running",
		"settling_previous_year",
		"settling_current_year"
	] and str(loading.get("completion_state", "running")).strip_edges() != "complete"

	var visible_started_at_ms: int = int(loading.get("visible_started_at_ms", 0))
	var visible_elapsed_ms: int = 0
	if visible_started_at_ms > 0:
		visible_elapsed_ms = max(0, int(Time.get_ticks_msec()) - visible_started_at_ms)

	active_year_context ["visible_runtime_elapsed_ms"] = visible_elapsed_ms

	var hard_frame_budget_ms: int = 4
	if not hot_visible_runtime:
		hard_frame_budget_ms = 8

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}

		var guard_phase_cap: int = int(guard.get("phase_budget_cap", overlay_context.get("runtime_phase_budget_cap", 1)))
		var guard_commit_cap: int = int(guard.get("visible_runtime_commit_budget_cap", guard.get("commit_budget_cap", overlay_context.get("runtime_frame_commit_budget_cap", 3))))

		effective_phase_steps = clamp(effective_phase_steps, 1, max(1, guard_phase_cap))
		effective_commit_stages = clamp(effective_commit_stages, 1, max(1, guard_commit_cap))

	if hot_visible_runtime or bool(overlay_context.get("age_up_loading_pure_renderer", false)):
		effective_phase_steps = 1
		effective_commit_stages = clamp(effective_commit_stages, 1, 3)
		hard_frame_budget_ms = min(hard_frame_budget_ms, int(overlay_context.get("runtime_frame_budget_ms", 4)))

	var slice_started_ms: int = int(Time.get_ticks_msec())
	var deferred_before_snapshot_capture: bool = bool(active_year_context.get("deferred_before_snapshot_capture", false))
	var deferred_before_snapshot_frames_remaining: int = int(active_year_context.get("deferred_before_snapshot_frames_remaining", 0))
	var deferred_before_snapshot_until_ms: int = int(active_year_context.get("deferred_before_snapshot_until_ms", 0))
	var deferred_before_snapshot_active: bool = deferred_before_snapshot_capture and deferred_before_snapshot_frames_remaining > 0
	if deferred_before_snapshot_capture and deferred_before_snapshot_until_ms > 0 and int(Time.get_ticks_msec()) < deferred_before_snapshot_until_ms:
		deferred_before_snapshot_active = true
	if deferred_before_snapshot_capture and deferred_before_snapshot_active:
		active_year_context ["deferred_before_snapshot_frames_remaining"] = max(0, deferred_before_snapshot_frames_remaining - 1)
		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": "snapshot_quarantine",
			"phase_progress": 0.0
		})
		return {
			"state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": "snapshot_quarantine",
			"phase_progress": 0.0
		}
	if deferred_before_snapshot_capture:
		_start_runtime_snapshot_capture_session("runtime_slice_before_snapshot")
		active_year_context ["deferred_before_snapshot_capture"] = false
		active_year_context ["deferred_before_snapshot_frames_remaining"] = 0
		active_year_context ["deferred_before_snapshot_until_ms"] = 0
		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": "before_snapshot_capture_prepare",
			"phase_progress": 0.0
		})
		return {
			"state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": "before_snapshot_capture_prepare",
			"phase_progress": 0.0
		}
	var snapshot_state_raw: Variant = active_year_context.get("runtime_snapshot_capture", {})
	var snapshot_state: Dictionary = snapshot_state_raw if typeof(snapshot_state_raw) == TYPE_DICTIONARY else {}
	if bool(snapshot_state.get("active", false)) and str(snapshot_state.get("capture_key", "")) == "runtime_slice_before_snapshot":
		var capture_items_per_step: int = max(1, int(active_year_context.get("runtime_snapshot_items_per_step", 2)))
		if hot_visible_runtime:
			capture_items_per_step = min(capture_items_per_step, int(overlay_context.get("visible_runtime_snapshot_items_per_step", 2)))
		var capture_step: Dictionary = _step_runtime_snapshot_capture(max(1, capture_items_per_step))
		var capture_complete: bool = bool(capture_step.get("is_complete", false))
		var capture_lane: String = str(capture_step.get("current_micro_lane", "before_snapshot_capture"))
		var capture_progress: float = float(capture_step.get("phase_progress", 0.0))
		if capture_complete:
			var before_snapshot_raw: Variant = capture_step.get("snapshot", {})
			runtime_slice_before_snapshot = before_snapshot_raw if typeof(before_snapshot_raw) == TYPE_DICTIONARY else {}
			active_year_context ["runtime_snapshot_capture"] = {}
			capture_lane = "before_snapshot_capture_complete"
			capture_progress = 0.08
		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": capture_lane,
			"phase_progress": capture_progress
		})
		return {
			"state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"current_micro_lane": capture_lane,
			"phase_progress": capture_progress
		}
	var startup_soft_loading_mode: bool = bool(active_year_context.get("startup_soft_loading_mode", false))
	var startup_soft_frames_remaining: int = int(active_year_context.get("startup_soft_slice_frames_remaining", 0))
	var startup_soft_until_ms: int = int(active_year_context.get("startup_soft_slice_until_ms", 0))
	var startup_soft_active: bool = startup_soft_loading_mode and startup_soft_frames_remaining > 0
	if startup_soft_loading_mode and startup_soft_until_ms > 0 and int(Time.get_ticks_msec()) < startup_soft_until_ms:
		startup_soft_active = true
	if startup_soft_active:
		effective_phase_steps = min(
			effective_phase_steps,
			max(1, int(active_year_context.get("startup_soft_phase_budget_cap", 1)))
		)
		effective_commit_stages = min(
			effective_commit_stages,
			max(1, int(active_year_context.get("startup_soft_commit_budget_cap", 4)))
		)
		active_year_context ["startup_soft_slice_frames_remaining"] = max(0, startup_soft_frames_remaining - 1)
	else:
		active_year_context ["startup_soft_loading_mode"] = false
		active_year_context ["startup_soft_slice_frames_remaining"] = 0
		active_year_context ["startup_soft_slice_until_ms"] = 0
	var steps_remaining: int = effective_phase_steps
	var last_report: Dictionary = {
		"state": "running",
		"is_complete": false,
		"current_phase": str(active_year_context.get("current_phase", "preflight"))
	}
	while steps_remaining > 0 and runtime_slice_phase_cursor < runtime_slice_order.size():
		var phase_name: String = str(runtime_slice_order [runtime_slice_phase_cursor])
		active_year_context ["current_phase"] = phase_name
		var phase_started: int = int(Time.get_ticks_msec())
		var should_yield: bool = false
		match phase_name:
			"year_and_era_mutation":
				var year_step: Dictionary = {}
				if _live_slice_streaming_enabled():
					year_step = _step_temporal_slice_streaming_walker(
						1 if hot_visible_runtime else 8,
						2 if hot_visible_runtime else 18
					)
				else:
					year_step = _step_year_and_era_mutation_walker(gs.player)

				var year_accumulated_ms: int = int(runtime_slice_phase_timings.get("year_and_era_mutation", 0))
				year_accumulated_ms += int(Time.get_ticks_msec() - phase_started)
				runtime_slice_phase_timings ["year_and_era_mutation"] = year_accumulated_ms

				if bool(year_step.get("is_complete", false)):
					runtime_slice_phase_cursor += 1
				else:
					should_yield = true

				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "year_and_era_mutation",
					"current_micro_lane": str(year_step.get("current_micro_lane", "")),
					"phase_progress": float(year_step.get("progress", 0.0)),
					"temporal_slice_streaming": bool(_live_slice_streaming_enabled())
				}
			"core_state_resolution":
				var core_step: Dictionary = _step_core_state_resolution_walker()
				var core_accumulated_ms: int = int(runtime_slice_phase_timings.get("core_state_resolution", 0))
				core_accumulated_ms += int(Time.get_ticks_msec() - phase_started)
				runtime_slice_phase_timings ["core_state_resolution"] = core_accumulated_ms
				if bool(core_step.get("is_complete", false)):
					var core_bridge_step: Dictionary = _execute_registered_phase_bridge(
						"core_state_resolution",
						1 if hot_visible_runtime else 999
					)
					if bool(core_bridge_step.get("is_complete", true)):
						runtime_slice_phase_cursor += 1
					else:
						should_yield = true
				else:
					should_yield = true
					should_yield = true
				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "core_state_resolution",
					"current_micro_lane": str(core_step.get("current_micro_lane", "")),
					"phase_progress": float(core_step.get("progress", 0.0))
				}
			"internal_identity_drift":
				var drift_step: Dictionary = _step_internal_identity_drift_walker()
				var drift_accumulated_ms: int = int(runtime_slice_phase_timings.get("internal_identity_drift", 0))
				drift_accumulated_ms += int(Time.get_ticks_msec() - phase_started)
				runtime_slice_phase_timings ["internal_identity_drift"] = drift_accumulated_ms
				if bool(drift_step.get("is_complete", false)):
					var drift_bridge_step: Dictionary = _execute_registered_phase_bridge(
						"internal_identity_drift",
						1 if hot_visible_runtime else 999
					)
					if bool(drift_bridge_step.get("is_complete", true)):
						runtime_slice_phase_cursor += 1
					else:
						should_yield = true
				else:
					should_yield = true
				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "internal_identity_drift",
					"current_micro_lane": str(drift_step.get("current_micro_lane", "")),
					"phase_progress": float(drift_step.get("progress", 0.0))
				}
			"year_budget_pipeline_commit":
				var accumulated_ms: int = int(runtime_slice_phase_timings.get("year_budget_pipeline_commit", 0))
				if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
					var commit_drain_budget: int = max(1, effective_commit_stages)
					var pending_pipeline_stage: int = int(gs.year_budget_engine.pipeline_stage)
					if hot_visible_runtime:
						commit_drain_budget = clamp(commit_drain_budget, 1, 3)
					gs.year_budget_engine.drain_pending_year_pipeline(commit_drain_budget)
					accumulated_ms += int(Time.get_ticks_msec() - phase_started)
					runtime_slice_phase_timings ["year_budget_pipeline_commit"] = accumulated_ms
					if gs.year_budget_engine.has_pending_year_pipeline():
						should_yield = true
					else:
						runtime_slice_phase_cursor += 1
					steps_remaining -= 1
					last_report = {
						"state": "running",
						"is_complete": false,
						"current_phase": phase_name,
						"current_micro_lane": "pipeline_stage_%d" % pending_pipeline_stage
					}
				else:
					runtime_slice_phase_cursor += 1
					steps_remaining -= 1
					last_report = {
						"state": "running",
						"is_complete": false,
						"current_phase": phase_name
					}
			"player_phase_contract":
				var player_step: Dictionary = _step_player_phase_contract_walker()
				var player_accumulated_ms: int = int(runtime_slice_phase_timings.get("player_phase_contract", 0))
				player_accumulated_ms += int(Time.get_ticks_msec() - phase_started)
				runtime_slice_phase_timings ["player_phase_contract"] = player_accumulated_ms
				if bool(player_step.get("is_complete", false)):
					runtime_slice_phase_cursor += 1
				else:
					should_yield = true
				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "player_phase_contract",
					"current_micro_lane": str(player_step.get("current_micro_lane", "")),
					"phase_progress": float(player_step.get("progress", 0.0))
				}
			"choice_and_opportunity_surfacing":
				_run_choice_and_opportunity_surfacing()
				var choice_bridge_step: Dictionary = _execute_registered_phase_bridge(
					"choice_and_opportunity_surfacing",
					1 if hot_visible_runtime else 999
				)

				runtime_slice_phase_timings ["choice_and_opportunity_surfacing"] = int(Time.get_ticks_msec() - phase_started)

				if bool(choice_bridge_step.get("is_complete", true)):
					runtime_slice_phase_cursor += 1
				else:
					should_yield = true

				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "choice_and_opportunity_surfacing",
					"current_micro_lane": "scenario_surface_ready",
					"phase_progress": 1.0
				}
			"narrative_and_presentation":
				active_year_context ["narrative_phase_budget"] = 3 if hot_visible_runtime else 32
				_run_narrative_and_presentation()

				var narrative_done: bool = _narrative_and_presentation_complete()
				var narrative_bridge_done: bool = true

				if narrative_done:
					var narrative_bridge_step: Dictionary = _execute_registered_phase_bridge(
						"narrative_and_presentation",
						1 if hot_visible_runtime else 999
					)
					narrative_bridge_done = bool(narrative_bridge_step.get("is_complete", true))

				runtime_slice_phase_timings ["narrative_and_presentation"] = int(Time.get_ticks_msec() - phase_started)

				if narrative_done and narrative_bridge_done:
					runtime_slice_phase_cursor += 1
				else:
					should_yield = true

				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": "narrative_and_presentation",
					"current_micro_lane": "mailbox_drain",
					"phase_progress": 1.0 if narrative_done else 0.72
				}
			_:
				runtime_slice_phase_cursor += 1
				steps_remaining -= 1
				last_report = {
					"state": "running",
					"is_complete": false,
					"current_phase": phase_name
				}
		var measured_phase_name: String = str(last_report.get("current_phase", phase_name))
		var measured_elapsed_ms: int = int(runtime_slice_phase_timings.get(measured_phase_name, 0))
		var overflow_report: Dictionary = _record_phase_overflow_if_needed(measured_phase_name, measured_elapsed_ms)

		_update_loading_runtime_bucket({
			"completion_state": "running",
			"is_complete": false,
			"current_phase": measured_phase_name,
			"current_micro_lane": str(last_report.get("current_micro_lane", "")),
			"phase_progress": float(last_report.get("phase_progress", 0.0)),
			"phase_overflow": not overflow_report.is_empty(),
			"phase_overflow_report": overflow_report,
			"runtime_contract_scheduler": runtime_contract_scheduler.duplicate(true),
			"force_bucket_write": not overflow_report.is_empty()
		})

		watchdog_result = _check_visible_runtime_watchdog()
		if bool(watchdog_result.get("is_complete", false)):
			return watchdog_result

		if should_yield:
			return last_report

		if hot_visible_runtime:
			return last_report

		if int(Time.get_ticks_msec()) - slice_started_ms >= hard_frame_budget_ms:
			return last_report

		if runtime_slice_phase_cursor >= runtime_slice_order.size():
			return _finalize_runtime_slice_session()

	return last_report