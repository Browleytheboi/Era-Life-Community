extends Resource
class_name SimulationDirector

var gs

const PHASE_CORE_STATE:= "core_state_resolution"
const PHASE_IDENTITY_DRIFT:= "internal_identity_drift"
const PHASE_CHOICE_SURFACING:= "choice_and_opportunity_surfacing"
const PHASE_NARRATIVE_PRESENTATION:= "narrative_and_presentation"

const LANE_A:= "lane_a"
const LANE_B:= "lane_b"
const LANE_C:= "lane_c"
const LANE_D:= "lane_d"

const DEFAULT_RUNTIME_RING_LIMIT:= 48
const DEFAULT_RUNTIME_FAR_LIMIT:= 180
const YEARLY_EXECUTION_INCREMENTAL:= "incremental"
const YEARLY_EXECUTION_CONSTANT_TIME:= "constant_time"
const YEARLY_EXECUTION_LEGACY:= "legacy_unclassified"
var runtime_phase_registry: Dictionary = {}
var runtime_cached_relevance: Dictionary = {}
var runtime_last_report: Dictionary = {}
var runtime_defaults_registered: bool = false
var runtime_bridge_step_sessions: Dictionary = {}
func _init(_gs):
	gs = _gs

	_ensure_phase_bucket(
		PHASE_CORE_STATE
	)
	_ensure_phase_bucket(
		PHASE_IDENTITY_DRIFT
	)
	_ensure_phase_bucket(
		PHASE_CHOICE_SURFACING
	)
	_ensure_phase_bucket(
		PHASE_NARRATIVE_PRESENTATION
	)




	if (
		gs != null
		and gs.career_runtime_engine != null
	):
		_register_yearly_phase_listener(
			"career_runtime_engine.yearly_quantum",
			PHASE_CORE_STATE,
			LANE_B,
			gs.career_runtime_engine,
			"service_yearly_quantum",
			{
				"priority": 15,

				"execution_model": (
					YEARLY_EXECUTION_INCREMENTAL
				),
				"max_quantum_ms": 2,
				"max_items_per_quantum": 1,
				"ui_concurrent": true,
				"idle_required": false,
				"can_defer": true,
				"can_compress": true
			}
		)

func _ensure_phase_bucket(phase_name: String) -> void:
	if not runtime_phase_registry.has(phase_name):
		runtime_phase_registry [phase_name] = []

func register_default_runtime_listeners() -> void:
	if gs == null or runtime_defaults_registered:
		return

	_register_yearly_phase_listener(
		"family_control.household_cluster_sync",
		PHASE_CORE_STATE,
		LANE_A,
		gs.family_control_engine,
		"yearly_household_cluster_sync",
		{
			"priority": 5,
		}
	)
	_register_yearly_phase_listener(
		"school_engine.yearly_school_tick",
		PHASE_CORE_STATE,
		LANE_A,
		gs.school_engine,
		"yearly_school_tick",
		{
			"priority": 10,
		}
	)
	_register_yearly_phase_listener(
		"reality_projection_contract_engine.yearly_school_surface_refresh",
		PHASE_CORE_STATE,
		LANE_A,
		gs.reality_projection_contract_engine,
		"yearly_school_surface_refresh",
		{
			"priority": 11,
			"depends_on": [
				"school_engine.yearly_school_tick"
			],
			"execution_model": YEARLY_EXECUTION_CONSTANT_TIME,
			"max_quantum_ms": 1,
			"max_items_per_quantum": 1,
			"ui_concurrent": true,
			"idle_required": false,
			"can_defer": false,
			"can_compress": true
		}
	)

	_register_yearly_phase_listener(
		"artifacts_engine.yearly_exchange_artifact_effects",
		PHASE_CORE_STATE,
		LANE_A,
		gs.artifacts_engine,
		"yearly_exchange_artifact_effects",
		{
			"priority": 12,
			"execution_model": YEARLY_EXECUTION_CONSTANT_TIME,
			"max_quantum_ms": 1,
			"max_items_per_quantum": 1,
			"ui_concurrent": true,
			"idle_required": false,
			"can_defer": false,
			"can_compress": true
		}
	)

	_register_yearly_phase_listener(
		"geo_engine.yearly_tick",
		PHASE_CORE_STATE,
		LANE_C,
		gs.geo_engine,
		"yearly_tick",
		{
			"priority": 20,
		}
	)
	_register_yearly_phase_listener(
		"migration_engine.yearly_tick",
		PHASE_CORE_STATE,
		LANE_C,
		gs.migration_engine,
		"yearly_tick",
		{
			"priority": 25,
			"depends_on": ["geo_engine.yearly_tick"]
		}
	)
	_register_yearly_phase_listener(
		"settlement_presence_engine.yearly_tick",
		PHASE_CORE_STATE,
		LANE_C,
		gs.settlement_presence_engine,
		"yearly_tick",
		{
			"priority": 30,
			"depends_on": ["migration_engine.yearly_tick"]
		}
	)
	_register_yearly_phase_listener(
		"universal_faction_engine.yearly_core_resolution",
		PHASE_CORE_STATE,
		LANE_C,
		gs.universal_faction_engine,
		"yearly_core_resolution",
		{
			"priority": 35,
			"depends_on": ["settlement_presence_engine.yearly_tick"]
		}
	)
	_register_yearly_phase_listener(
		"place_influence_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.place_influence_engine,
		"yearly_tick",
		{
			"priority": 10,
			"depends_on": ["settlement_presence_engine.yearly_tick"]
		}
	)
	_register_yearly_phase_listener(
		"vampire_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_engine,
		"yearly_tick",
		{
			"priority": 20,
		}
	)
	_register_yearly_phase_listener(
		"universal_faction_engine.yearly_identity_drift",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.universal_faction_engine,
		"yearly_identity_drift",
		{
			"priority": 50,
			"depends_on": [
				"place_influence_engine.yearly_tick",
				"vampire_society_engine.yearly_tick"
			]
		}
	)
	_register_yearly_phase_listener(
		"vampire_hunger_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_hunger_engine,
		"yearly_tick",
		{
			"priority": 25,
		}
	)
	_register_yearly_phase_listener(
		"vampire_society_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_society_engine,
		"yearly_tick",
		{
			"priority": 30,
		}
	)
	_register_yearly_phase_listener(
		"vampire_hunter_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_hunter_engine,
		"yearly_tick",
		{
			"priority": 35,
		}
	)
	_register_yearly_phase_listener(
		"vampire_legacy_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_legacy_engine,
		"yearly_tick",
		{
			"priority": 40,
		}
	)
	_register_yearly_phase_listener(
		"vampire_masquerade_engine.yearly_tick",
		PHASE_IDENTITY_DRIFT,
		LANE_B,
		gs.vampire_masquerade_engine,
		"yearly_tick",
		{
			"priority": 45,
		}
	)
	_register_yearly_phase_listener(
		"boxing_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_engine,
		"yearly_tick",
		{
			"priority": 10,
		}
	)
	_register_yearly_phase_listener(
		"boxing_amateur_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_amateur_engine,
		"yearly_tick",
		{
			"priority": 15,
		}
	)
	_register_yearly_phase_listener(
		"boxing_weight_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_weight_engine,
		"yearly_tick",
		{
			"priority": 20,
		}
	)
	_register_yearly_phase_listener(
		"boxing_mandatory_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_mandatory_engine,
		"yearly_tick",
		{
			"priority": 25,
		}
	)
	_register_yearly_phase_listener(
		"boxing_media_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_media_engine,
		"yearly_tick",
		{
			"priority": 30,
		}
	)
	_register_yearly_phase_listener(
		"boxing_legacy_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.boxing_legacy_engine,
		"yearly_tick",
		{
			"priority": 35,
		}
	)
	_register_yearly_phase_listener(
		"universal_faction_engine.yearly_choice_surface",
		PHASE_CHOICE_SURFACING,
		LANE_B,
		gs.universal_faction_engine,
		"yearly_choice_surface",
		{
			"priority": 40,
			"depends_on": [
				"boxing_engine.yearly_tick",
				"boxing_media_engine.yearly_tick"
			]
		}
	)
	_register_yearly_phase_listener(
		"many_realms_engine.yearly_tick",
		PHASE_CHOICE_SURFACING,
		LANE_C,
		gs.many_realms_engine,
		"yearly_tick",
		{
			"priority": 50,
		}
	)
	_register_yearly_phase_listener(
		"universal_faction_engine.yearly_narrative_surface",
		PHASE_NARRATIVE_PRESENTATION,
		LANE_B,
		gs.universal_faction_engine,
		"yearly_narrative_surface",
		{
			"priority": 10,
		}
	)
	runtime_defaults_registered = true
func _legacy_yearly_listener_ids() -> Dictionary:
	return {
		"family_control.household_cluster_sync": true,
		"school_engine.yearly_school_tick": true,
		"geo_engine.yearly_tick": true,
		"migration_engine.yearly_tick": true,
		"settlement_presence_engine.yearly_tick": true,
		"universal_faction_engine.yearly_core_resolution": true,

		"place_influence_engine.yearly_tick": true,
		"vampire_engine.yearly_tick": true,
		"vampire_hunger_engine.yearly_tick": true,
		"vampire_society_engine.yearly_tick": true,
		"vampire_hunter_engine.yearly_tick": true,
		"vampire_legacy_engine.yearly_tick": true,
		"vampire_masquerade_engine.yearly_tick": true,
		"universal_faction_engine.yearly_identity_drift": true,

		"boxing_engine.yearly_tick": true,
		"boxing_amateur_engine.yearly_tick": true,
		"boxing_weight_engine.yearly_tick": true,
		"boxing_mandatory_engine.yearly_tick": true,
		"boxing_media_engine.yearly_tick": true,
		"boxing_legacy_engine.yearly_tick": true,
		"universal_faction_engine.yearly_choice_surface": true,
		"many_realms_engine.yearly_tick": true,

		"universal_faction_engine.yearly_narrative_surface": true
	}
func _register_yearly_phase_listener(
	listener_id: String,
	phase_name: String,
	lane_name: String,
	target,
	method_name: String,
	meta: Dictionary = {}
) -> void:
	if (
		target == null
		or method_name == ""
	):
		return

	_ensure_phase_bucket(
		phase_name
	)

	var contract_meta: Dictionary = (
		meta.duplicate(false)
	)

	var execution_model_explicit: bool = (
		contract_meta.has(
			"execution_model"
		)
		or contract_meta.has(
			"yearly_execution_model"
		)
	)

	var execution_model: String = str(
		contract_meta.get(
			"execution_model",
			contract_meta.get(
				"yearly_execution_model",
				""
			)
		)
	).strip_edges().to_lower()

	var grandfathered: bool = false

	if execution_model == "":
		if _legacy_yearly_listener_ids().has(
			listener_id
		):
			execution_model = (
				YEARLY_EXECUTION_LEGACY
			)
			grandfathered = true
		else:
			EraLog.truth(
				(
					"ERALIFE_YEARLY_CONTRACT_REJECTED"
					+ "|listener_id=%s"
					+ "|phase=%s"
					+ "|reason=missing_execution_model"
					+ "|required=incremental_or_constant_time"
					+ "|registered=false"
					+ "|at_ms=%d"
				) % [
					listener_id,
					phase_name,
					int(
						Time.get_ticks_msec()
					)
				]
			)
			return

	if execution_model not in [
		YEARLY_EXECUTION_INCREMENTAL,
		YEARLY_EXECUTION_CONSTANT_TIME,
		YEARLY_EXECUTION_LEGACY
	]:
		EraLog.truth(
			(
				"ERALIFE_YEARLY_CONTRACT_REJECTED"
				+ "|listener_id=%s"
				+ "|phase=%s"
				+ "|reason=invalid_execution_model"
				+ "|execution_model=%s"
				+ "|registered=false"
				+ "|at_ms=%d"
			) % [
				listener_id,
				phase_name,
				execution_model,
				int(
					Time.get_ticks_msec()
				)
			]
		)
		return

	contract_meta ["engine_id"] = str(
		contract_meta.get(
			"engine_id",
			listener_id
		)
	)
	contract_meta ["phase_affinity"] = str(
		contract_meta.get(
			"phase_affinity",
			phase_name
		)
	)
	contract_meta ["lane_affinity"] = str(
		contract_meta.get(
			"lane_affinity",
			lane_name
		)
	)

	contract_meta ["required_inputs"] = (
		contract_meta.get(
			"required_inputs",
			[]
		)
	)
	contract_meta ["forbidden_states"] = (
		contract_meta.get(
			"forbidden_states",
			[]
		)
	)
	contract_meta ["mailboxes_read"] = (
		contract_meta.get(
			"mailboxes_read",
			[]
		)
	)
	contract_meta ["mailboxes_write"] = (
		contract_meta.get(
			"mailboxes_write",
			[]
		)
	)
	contract_meta ["ui_surfaces_touched"] = (
		contract_meta.get(
			"ui_surfaces_touched",
			[]
		)
	)

	contract_meta ["can_defer"] = bool(
		contract_meta.get(
			"can_defer",
			lane_name != LANE_A
		)
	)
	contract_meta ["can_compress"] = bool(
		contract_meta.get(
			"can_compress",
			lane_name in [
				LANE_B,
				LANE_C,
				LANE_D
			]
		)
	)
	contract_meta ["can_quarantine"] = true
	contract_meta ["health_checks"] = (
		contract_meta.get(
			"health_checks",
			[]
		)
	)

	contract_meta ["execution_model"] = (
		execution_model
	)
	contract_meta [
		"execution_model_explicit"
	] = execution_model_explicit
	contract_meta [
		"legacy_execution_model_grandfathered"
	] = grandfathered
	contract_meta [
		"requires_progress_contract"
	] = (
		execution_model
		== YEARLY_EXECUTION_INCREMENTAL
	)
	contract_meta ["max_quantum_ms"] = clampi(
		int(
			contract_meta.get(
				"max_quantum_ms",
				2
			)
		),
		1,
		6
	)
	contract_meta [
		"max_items_per_quantum"
	] = clampi(
		int(
			contract_meta.get(
				"max_items_per_quantum",
				64
			)
		),
		1,
		512
	)


	contract_meta ["ui_concurrent"] = true
	contract_meta ["idle_required"] = false
	contract_meta [
		"ui_may_preempt_between_quanta"
	] = true
	contract_meta ["blocks_ui"] = false

	var entry: Dictionary = {
		"id": listener_id,
		"phase": phase_name,
		"lane": lane_name,
		"target": target,
		"method": method_name,
		"priority": int(
			contract_meta.get(
				"priority",
				100
			)
		),
		"execution_model": execution_model,
		"max_quantum_ms": int(
			contract_meta.get(
				"max_quantum_ms",
				2
			)
		),
		"max_items_per_quantum": int(
			contract_meta.get(
				"max_items_per_quantum",
				64
			)
		),
		"ui_concurrent": true,
		"idle_required": false,
		"meta": contract_meta
	}

	if (
		gs != null
		and gs.runtime_health_registry != null
	):
		gs.runtime_health_registry.register_contract(
			listener_id,
			{
				"engine_id": listener_id,
				"phase_affinity": phase_name,
				"lane_affinity": lane_name,
				"method_name": method_name,
				"target_class": str(
					target.get_class()
				),
				"execution_model": (
					execution_model
				),
				"max_quantum_ms": int(
					contract_meta.get(
						"max_quantum_ms",
						2
					)
				),
				"max_items_per_quantum": int(
					contract_meta.get(
						"max_items_per_quantum",
						64
					)
				),
				"ui_concurrent": true,
				"idle_required": false,
				"legacy_execution_model_grandfathered": (
					grandfathered
				),
				"required_inputs": (
					contract_meta.get(
						"required_inputs",
						[]
					)
				),
				"forbidden_states": (
					contract_meta.get(
						"forbidden_states",
						[]
					)
				),
				"mailboxes_read": (
					contract_meta.get(
						"mailboxes_read",
						[]
					)
				),
				"mailboxes_write": (
					contract_meta.get(
						"mailboxes_write",
						[]
					)
				),
				"ui_surfaces_touched": (
					contract_meta.get(
						"ui_surfaces_touched",
						[]
					)
				),
				"can_defer": bool(
					contract_meta.get(
						"can_defer",
						false
					)
				),
				"can_compress": bool(
					contract_meta.get(
						"can_compress",
						false
					)
				),
				"can_quarantine": true,
				"health_checks": (
					contract_meta.get(
						"health_checks",
						[]
					)
				)
			}
		)

	var bucket: Array = runtime_phase_registry.get(
		phase_name,
		[]
	)

	for i in range(
		bucket.size()
	):
		var existing: Dictionary = (
			bucket [i] as Dictionary
			if typeof(bucket [i]) == TYPE_DICTIONARY
			else {}
		)

		if str(
			existing.get(
				"id",
				""
			)
		) != listener_id:
			continue

		bucket [i] = entry
		runtime_phase_registry [
			phase_name
		] = bucket
		runtime_phase_registry [
			phase_name
		].sort_custom(
			Callable(
				self,
				"_sort_runtime_entries"
			)
		)
		return

	bucket.append(
		entry
	)
	runtime_phase_registry [
		phase_name
	] = bucket
	runtime_phase_registry [
		phase_name
	].sort_custom(
		Callable(
			self,
			"_sort_runtime_entries"
		)
	)

func _sort_runtime_entries(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 100)) < int(b.get("priority", 100))
func _resolve_phase_entries(entries: Array) -> Array:
	var remaining: Array = entries.duplicate()
	var ordered: Array = []
	var resolved: Dictionary = {}

	while not remaining.is_empty():
		var progressed: bool = false
		remaining.sort_custom(Callable(self, "_sort_runtime_entries"))

		for i in range(remaining.size() - 1, -1, -1):
			var entry: Dictionary = remaining [i]
			var meta: Dictionary = entry.get("meta", {})
			var deps: Array = meta.get("depends_on", [])
			var ready: bool = true

			for dep in deps:
				if not resolved.has(str(dep)):
					ready = false
					break

			if not ready:
				continue

			ordered.append(entry)
			resolved [str(entry.get("id", ""))] = true
			remaining.remove_at(i)
			progressed = true

		if progressed:
			continue

		remaining.sort_custom(Callable(self, "_sort_runtime_entries"))
		for entry in remaining:
			ordered.append(entry)
		break

	return ordered
func yearly_evaluation(_payload:= {}):
	if gs == null:
		return
	if not runtime_defaults_registered:
		register_default_runtime_listeners()

	if typeof(_payload) == TYPE_DICTIONARY and bool(_payload.get("runtime_managed", false)):
		var bridged_plan: Dictionary = build_runtime_plan(_payload)
		runtime_last_report = {
			"year": int(bridged_plan.get("year", gs.year)),
			"quality_tier": str(bridged_plan.get("quality_tier", "balanced")),
			"phase_hits": {},
			"promotions": 0,
		}
		return

	var metrics: Dictionary = _gather_metrics()
	var plan: Dictionary = _build_runtime_year_plan(metrics, _payload)

	_run_global_pressure_observers(metrics)
	_apply_promotion_rules(plan)
	_execute_registered_phase(PHASE_CORE_STATE, plan, metrics)
	_execute_registered_phase(PHASE_IDENTITY_DRIFT, plan, metrics)
	_execute_lane_surfaces(plan)
	_execute_registered_phase(PHASE_CHOICE_SURFACING, plan, metrics)
	_execute_registered_phase(PHASE_NARRATIVE_PRESENTATION, plan, metrics)
	_finalize_runtime_report(plan, metrics)

func get_last_runtime_report() -> Dictionary:
	return runtime_last_report.duplicate(true)

func build_runtime_plan(context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}

	if not runtime_defaults_registered:
		register_default_runtime_listeners()

	var metrics: Dictionary = _gather_metrics()
	var plan: Dictionary = _build_runtime_year_plan(
		metrics,
		context
	)

	var runtime_actor_id: int = int(
		context.get(
			"player_id",
			int(gs.player.id)
			if gs.player != null
			else -1
		)
	)




	if typeof(runtime_cached_relevance) == TYPE_DICTIONARY:
		runtime_cached_relevance [
			"actor_id"
		] = runtime_actor_id

	plan [
		"runtime_actor_id"
	] = runtime_actor_id

	return plan

func get_resident_realtime_relevance_snapshot() -> Dictionary:
	var current_actor_id: int = (
		int(gs.player.id)
		if gs != null and gs.player != null
		else -1
	)

	if current_actor_id <= 0:
		return {
			"success": false,
			"schema": "eralife.simulation_realtime_relevance_snapshot",
			"version": 1,
			"reason": "missing_current_actor",
			"actor_id": current_actor_id,
			"near_ids": [],
		}

	var lane_ids_raw: Variant = runtime_cached_relevance.get(
		"lane_ids",
		{}
	)
	var lane_ids: Dictionary = (
		lane_ids_raw as Dictionary
		if typeof(lane_ids_raw) == TYPE_DICTIONARY
		else {}
	)
	var cached_actor_id: int = int(
		runtime_cached_relevance.get(
			"actor_id",
			-1
		)
	)

	if (
		cached_actor_id == current_actor_id
		and lane_ids.has(LANE_A)
	):
		var near_ids_raw: Variant = lane_ids.get(
			LANE_A,
			[]
		)
		var near_ids: Array = (
			near_ids_raw as Array
			if typeof(near_ids_raw) == TYPE_ARRAY
			else []
		)

		return {
			"success": true,
			"schema": "eralife.simulation_realtime_relevance_snapshot",
			"version": 1,
			"actor_id": current_actor_id,
			"year": int(
				runtime_cached_relevance.get(
					"year",
					gs.year
				)
			),
			"lane": LANE_A,
			"near_ids": near_ids,
			"source": "simulation_director.runtime_cached_relevance",
		}

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		var warm_raw: Variant = gs.scenario_state.get(
			"warm_runtime_plan",
			{}
		)
		var warm: Dictionary = (
			warm_raw as Dictionary
			if typeof(warm_raw) == TYPE_DICTIONARY
			else {}
		)
		var warm_actor_id: int = int(
			warm.get(
				"player_id",
				-1
			)
		)
		var warm_plan_raw: Variant = warm.get(
			"plan",
			{}
		)
		var warm_plan: Dictionary = (
			warm_plan_raw as Dictionary
			if typeof(warm_plan_raw) == TYPE_DICTIONARY
			else {}
		)
		var warm_lane_ids_raw: Variant = warm_plan.get(
			"lane_ids",
			{}
		)
		var warm_lane_ids: Dictionary = (
			warm_lane_ids_raw as Dictionary
			if typeof(warm_lane_ids_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			warm_actor_id == current_actor_id
			and warm_lane_ids.has(LANE_A)
		):
			var warm_near_ids_raw: Variant = warm_lane_ids.get(
				LANE_A,
				[]
			)
			var warm_near_ids: Array = (
				warm_near_ids_raw as Array
				if typeof(warm_near_ids_raw) == TYPE_ARRAY
				else []
			)

			return {
				"success": true,
				"schema": "eralife.simulation_realtime_relevance_snapshot",
				"version": 1,
				"actor_id": current_actor_id,
				"year": int(
					warm.get(
						"year",
						gs.year
					)
				),
				"lane": LANE_A,
				"near_ids": warm_near_ids,
				"source": "game_state.warm_runtime_plan",
			}

	return {
		"success": false,
		"schema": "eralife.simulation_realtime_relevance_snapshot",
		"version": 1,
		"reason": "resident_relevance_snapshot_not_authored",
		"actor_id": current_actor_id,
		"near_ids": [],
	}
func _build_runtime_year_plan(metrics: Dictionary, context: Dictionary = {}) -> Dictionary:
	var runtime_year: int = int(context.get("year", gs.year))
	var quality_tier: String = _resolve_quality_tier(metrics)

	var lane_ids: Dictionary = {
		LANE_A: _collect_lane_a_ids(),
		LANE_B: [],
		LANE_C: [],
		LANE_D: []
	}
	lane_ids [LANE_B] = _collect_lane_b_ids(lane_ids [LANE_A])
	lane_ids [LANE_C] = _collect_lane_c_ids(lane_ids [LANE_A], lane_ids [LANE_B])
	lane_ids [LANE_D] = _collect_dormant_hot_ids(lane_ids [LANE_A], lane_ids [LANE_B], lane_ids [LANE_C])

	var groups: Dictionary = {
		LANE_A: _active_people_from_ids(lane_ids [LANE_A]),
		LANE_B: _active_people_from_ids(lane_ids [LANE_B]),
		LANE_C: _active_people_from_ids(lane_ids [LANE_C]),
		LANE_D: []
	}

	var execution_manifest: Dictionary = {}
	for phase_name in [
		PHASE_CORE_STATE,
		PHASE_IDENTITY_DRIFT,
		PHASE_CHOICE_SURFACING,
		PHASE_NARRATIVE_PRESENTATION
	]:
		var rows: Array = []
		for entry in runtime_phase_registry.get(phase_name, []):
			var meta: Dictionary = entry.get("meta", {})
			rows.append({
				"id": str(entry.get("id", "")),
				"lane": str(entry.get("lane", "")),
				"priority": int(entry.get("priority", 100)),
				"depends_on": meta.get("depends_on", []).duplicate(true)
			})
		execution_manifest [phase_name] = rows

	var plan_mailboxes: Dictionary = {
		"mutation": [],
		"social": [],
		"social_consequences": [],
		"scenario": [],
		"scenarios": [],
		"world_feed": [],
		"chronicle": [],
		"popups": [],
		"delta_packets": []
	}

	var plan: Dictionary = {
		"year": runtime_year,
		"mode": str(context.get("mode", "living")),
		"metrics": metrics,
		"quality_tier": quality_tier,
		"phase_order": [
			PHASE_CORE_STATE,
			PHASE_IDENTITY_DRIFT,
			PHASE_CHOICE_SURFACING,
			PHASE_NARRATIVE_PRESENTATION
		],
		"lane_ids": lane_ids,
		"groups": groups,
		"runtime_groups": {
			"near": groups.get(LANE_A, []).duplicate(),
			"mid": groups.get(LANE_B, []).duplicate(),
			"far": groups.get(LANE_C, []).duplicate()
		},
		"mailboxes": plan_mailboxes,
		"execution_manifest": execution_manifest,
		"promotion_candidates": _build_promotion_candidates(lane_ids),
		"promoted_ids": [],
		"world_feed_before": int(gs.world_feed.size()),
		"pending_popups_before": int(gs.pending_year_resolution_popups.size()) +
			int(gs.pending_death_messages.size()) +
			int(gs.pending_inheritance_messages.size()),
		"scenario_history_before": int(gs.scenario_history.size()),
		"relevance_cache": {
			"year": runtime_year,
			"lane_ids": lane_ids.duplicate(true),
			"quality_tier": quality_tier,
			"hot_dormant_ids": lane_ids.get(LANE_D, []).duplicate(true),
			"phase_order": [
				PHASE_CORE_STATE,
				PHASE_IDENTITY_DRIFT,
				PHASE_CHOICE_SURFACING,
				PHASE_NARRATIVE_PRESENTATION
			]
		}
	}

	runtime_cached_relevance = plan.get("relevance_cache", {}).duplicate(true)

	runtime_last_report = {
		"year": runtime_year,
		"quality_tier": quality_tier,
		"phase_hits": {},
		"promotions": 0
	}

	return plan
func execute_runtime_phase_bridge(phase_name: String, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}

	if not runtime_defaults_registered:
		register_default_runtime_listeners()

	var metrics: Dictionary = _get_cached_runtime_bridge_metrics(context)

	var lane_ids: Dictionary = context.get("lane_ids", {})
	if typeof(lane_ids) != TYPE_DICTIONARY:
		lane_ids = {}

	var groups: Dictionary = context.get("groups", {})
	if typeof(groups) != TYPE_DICTIONARY:
		groups = {}

	var mailboxes = context.get("mailboxes", {})
	if typeof(mailboxes) != TYPE_DICTIONARY:
		mailboxes = {}

	var execution_manifest: Dictionary = context.get("execution_manifest", {})
	if typeof(execution_manifest) != TYPE_DICTIONARY:
		execution_manifest = {}

	var plan: Dictionary = {
		"year": int(context.get("year", gs.year)),
		"metrics": metrics,
		"quality_tier": str(context.get("quality_tier", _resolve_quality_tier(metrics))),
		"lane_ids": lane_ids.duplicate(true),
		"groups": groups.duplicate(true),
		"mailboxes": mailboxes,
		"promoted_ids": context.get("promoted_ids", []).duplicate(),
		"execution_manifest": execution_manifest,
		"delta_sink": context.get("delta_sink", null),
		"emit_typed_delta_method": str(context.get("emit_typed_delta_method", "")),
		"phase_delta_defaults": {
			"year": int(context.get("year", gs.year)),
			"phase": phase_name,
			"source": str(context.get("runtime_owner", "age_up_runtime"))
		},
		"runtime_owner": str(context.get("runtime_owner", "age_up_runtime"))
	}

	_execute_registered_phase(phase_name, plan, metrics)
	return plan

func _get_cached_runtime_bridge_metrics(context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return _gather_metrics()

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var cache_key: String = "%d|%s|%s" % [
		int(context.get("year", gs.year)),
		str(context.get("runtime_owner", "age_up_runtime")),
		str(context.get("_runtime_metrics_cache_key", "default"))
	]

	var cache_raw: Variant = gs.scenario_state.get("_runtime_bridge_metrics_cache", {})
	var cache: Dictionary = cache_raw if typeof(cache_raw) == TYPE_DICTIONARY else {}

	if str(cache.get("key", "")) == cache_key:
		var cached_metrics_raw: Variant = cache.get("metrics", {})
		var cached_metrics: Dictionary = cached_metrics_raw if typeof(cached_metrics_raw) == TYPE_DICTIONARY else {}
		if not cached_metrics.is_empty():
			return cached_metrics.duplicate(true)

	var metrics: Dictionary = _gather_metrics()
	gs.scenario_state ["_runtime_bridge_metrics_cache"] = {
		"key": cache_key,
		"metrics": metrics.duplicate(true)
	}
	return metrics
func _resolve_quality_tier(metrics: Dictionary) -> String:
	var population: int = int(metrics.get("population", 0))
	if population > 35000:
		return "massive_world"
	if population > 7000:
		return "balanced"
	return "ultra_fidelity"

func _collect_lane_a_ids() -> Array:
	var ids: Array = []
	if gs == null or gs.player == null:
		return ids

	for cached_id in _get_cached_lane_ids(LANE_A):
		_push_unique_id(ids, int(cached_id))

	_push_unique_id(ids, int(gs.player.id))
	_append_id_list(ids, gs.player.parents)
	_append_id_list(ids, gs.player.children)

	var partner_id: int = _extract_partner_id(gs.player)
	if partner_id > 0:
		_push_unique_id(ids, partner_id)

	for parent_id in gs.player.parents:
		var parent = gs.get_npc_by_id(int(parent_id))
		if parent == null:
			continue
		_append_id_list(ids, parent.children)
		_append_id_list(ids, parent.parents)

	if gs.social_graph_engine != null:
		for linked_id in gs.social_graph_engine.get_connections(int(gs.player.id)):
			_push_unique_id(ids, int(linked_id))
			if ids.size() >= 24:
				break

	return ids

func _collect_lane_b_ids(lane_a_ids: Array) -> Array:
	var ids: Array = []
	var blocked: Dictionary = {}

	for npc_id in lane_a_ids:
		blocked [int(npc_id)] = true

	for cached_id in _get_cached_lane_ids(LANE_B):
		_push_unique_id_if_missing(ids, int(cached_id), blocked)

	for seed_id in lane_a_ids:
		var person = gs.get_npc_by_id(int(seed_id))
		if person != null:
			_append_id_list_if_missing(ids, person.parents, blocked)
			_append_id_list_if_missing(ids, person.children, blocked)
			var partner_id: int = _extract_partner_id(person)
			_push_unique_id_if_missing(ids, partner_id, blocked)

		if gs.social_graph_engine != null:
			for linked_id in gs.social_graph_engine.get_connections(int(seed_id)):
				_push_unique_id_if_missing(ids, int(linked_id), blocked)
				if ids.size() >= DEFAULT_RUNTIME_RING_LIMIT:
					return ids

	return ids

func _collect_lane_c_ids(lane_a_ids: Array, lane_b_ids: Array) -> Array:
	var ids: Array = []
	var blocked: Dictionary = {}

	for npc_id in lane_a_ids:
		blocked [int(npc_id)] = true
	for npc_id in lane_b_ids:
		blocked [int(npc_id)] = true

	for cached_id in _get_cached_lane_ids(LANE_C):
		_push_unique_id_if_missing(ids, int(cached_id), blocked)

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		_push_unique_id_if_missing(ids, int(npc.id), blocked)
		if ids.size() >= DEFAULT_RUNTIME_FAR_LIMIT:
			break

	return ids

func _collect_dormant_hot_ids(lane_a_ids: Array, lane_b_ids: Array, lane_c_ids: Array) -> Array:
	var ids: Array = []

	for npc_id in lane_a_ids:
		if gs.dormant_npcs.has(int(npc_id)):
			_push_unique_id(ids, int(npc_id))
	for npc_id in lane_b_ids:
		if gs.dormant_npcs.has(int(npc_id)):
			_push_unique_id(ids, int(npc_id))
	for npc_id in lane_c_ids:
		if gs.dormant_npcs.has(int(npc_id)):
			_push_unique_id(ids, int(npc_id))

	return ids

func _build_promotion_candidates(lane_ids: Dictionary) -> Array:
	var out: Array = []

	for npc_id in lane_ids.get(LANE_A, []):
		var pid: int = int(npc_id)
		if gs.dormant_npcs.has(pid):
			out.append({
				"npc_id": pid,
				"preferred_lane": LANE_A,
				"reason": "player_bubble"
			})

	for npc_id in lane_ids.get(LANE_B, []):
		var pid: int = int(npc_id)
		if gs.dormant_npcs.has(pid):
			out.append({
				"npc_id": pid,
				"preferred_lane": LANE_B,
				"reason": "social_ring"
			})

	return out

func _apply_promotion_rules(plan: Dictionary) -> void:
	var promoted_ids: Array = []
	var groups: Dictionary = plan.get("groups", {})
	var lane_ids: Dictionary = plan.get("lane_ids", {})

	for entry in plan.get("promotion_candidates", []):
		var npc_id: int = int(entry.get("npc_id", -1))
		if npc_id <= 0 or not gs.dormant_npcs.has(npc_id):
			continue

		var npc = gs.reactivate_npc(npc_id)
		if npc == null:
			continue

		promoted_ids.append(npc_id)
		var preferred_lane: String = str(entry.get("preferred_lane", LANE_B))

		if preferred_lane == LANE_A:
			_append_unique_person(groups [LANE_A], npc)
			_push_unique_id(lane_ids [LANE_A], npc_id)
		elif preferred_lane == LANE_B:
			_append_unique_person(groups [LANE_B], npc)
			_push_unique_id(lane_ids [LANE_B], npc_id)
		else:
			_append_unique_person(groups [LANE_C], npc)
			_push_unique_id(lane_ids [LANE_C], npc_id)

	plan ["promoted_ids"] = promoted_ids
	runtime_last_report ["promotions"] = promoted_ids.size()

func _execute_registered_phase(phase_name: String, plan: Dictionary, metrics: Dictionary) -> void:
	var entries: Array = runtime_phase_registry.get(phase_name, [])
	var ordered_entries: Array = _resolve_phase_entries(entries)
	var phase_hits: Dictionary = runtime_last_report.get("phase_hits", {})
	phase_hits [phase_name] = 0
	runtime_last_report ["phase_hits"] = phase_hits

	for entry in ordered_entries:
		_execute_runtime_phase_entry(entry, phase_name, plan, metrics)


func _execute_runtime_phase_entry(
	entry: Dictionary,
	phase_name: String,
	plan: Dictionary,
	metrics: Dictionary
) -> Dictionary:
	var listener_id: String = str(
		entry.get(
			"id",
			""
		)
	).strip_edges()

	var target = entry.get(
		"target",
		null
	)
	var method_name: String = str(
		entry.get(
			"method",
			""
		)
	).strip_edges()

	var report: Dictionary = {
		"success": false,
		"listener_id": listener_id,
		"phase": phase_name,
		"is_complete": true,
		"progress": 1.0,
		"contract_violation": false,
		"budget_violation": false,
		"blocks_ui": false
	}

	if (
		target == null
		or method_name == ""
		or not target.has_method(
			method_name
		)
	):
		report ["reason"] = (
			"missing_runtime_target_or_method"
		)
		return report

	var meta_raw: Variant = entry.get(
		"meta",
		{}
	)
	var contract_meta: Dictionary = (
		meta_raw as Dictionary
		if typeof(meta_raw) == TYPE_DICTIONARY
		else {}
	)

	var execution_model: String = str(
		entry.get(
			"execution_model",
			contract_meta.get(
				"execution_model",
				""
			)
		)
	).strip_edges().to_lower()

	if execution_model not in [
		YEARLY_EXECUTION_INCREMENTAL,
		YEARLY_EXECUTION_CONSTANT_TIME,
		YEARLY_EXECUTION_LEGACY
	]:
		report ["reason"] = (
			"missing_yearly_execution_contract"
		)
		report ["contract_violation"] = true
		report ["quarantined"] = true

		EraLog.truth(
			(
				"ERALIFE_YEARLY_RUNTIME_CONTRACT_VIOLATION"
				+ "|listener_id=%s"
				+ "|phase=%s"
				+ "|reason=missing_execution_model"
				+ "|executed=false"
				+ "|at_ms=%d"
			) % [
				listener_id,
				phase_name,
				int(
					Time.get_ticks_msec()
				)
			]
		)

		return report

	var max_quantum_ms: int = clampi(
		int(
			entry.get(
				"max_quantum_ms",
				contract_meta.get(
					"max_quantum_ms",
					2
				)
			)
		),
		1,
		6
	)

	var max_items_per_quantum: int = clampi(
		int(
			entry.get(
				"max_items_per_quantum",
				contract_meta.get(
					"max_items_per_quantum",
					64
				)
			)
		),
		1,
		512
	)

	var lane_name: String = str(
		entry.get(
			"lane",
			""
		)
	)

	var payload: Dictionary = {
		"year": int(
			plan.get(
				"year",
				gs.year
			)
		),
		"phase": phase_name,
		"lane": lane_name,
		"lane_ids": (
			plan.get(
				"lane_ids",
				{}
			).get(
				lane_name,
				[]
			)
		),
		"lane_people": (
			plan.get(
				"groups",
				{}
			).get(
				lane_name,
				[]
			)
		),
		"plan": plan,
		"metrics": metrics,
		"mailboxes": plan.get(
			"mailboxes",
			{}
		),
		"runtime_quality_tier": str(
			plan.get(
				"quality_tier",
				"balanced"
			)
		),
		"promoted_ids": plan.get(
			"promoted_ids",
			[]
		),
		"execution_manifest": plan.get(
			"execution_manifest",
			{}
		),
		"delta_sink": plan.get(
			"delta_sink",
			null
		),
		"emit_typed_delta_method": str(
			plan.get(
				"emit_typed_delta_method",
				""
			)
		),
		"phase_delta_defaults": plan.get(
			"phase_delta_defaults",
			{}
		),
		"runtime_owner": str(
			plan.get(
				"runtime_owner",
				"simulation_director"
			)
		),

		"runtime_quantum_contract": {
			"execution_model": execution_model,
			"max_quantum_ms": max_quantum_ms,
			"max_items_per_quantum": (
				max_items_per_quantum
			),
			"ui_concurrent": true,
			"idle_required": false,
			"ui_may_preempt_between_quanta": true,
			"blocks_ui": false
		}
	}

	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var raw_result: Variant = target.call(
		method_name,
		payload
	)
	var elapsed_ms: int = maxi(
		0,
		int(
			Time.get_ticks_msec()
		) - started_ms
	)

	report ["success"] = true
	report ["execution_model"] = execution_model
	report ["elapsed_ms"] = elapsed_ms
	report ["max_quantum_ms"] = max_quantum_ms

	if (
		execution_model
		== YEARLY_EXECUTION_INCREMENTAL
	):
		if typeof(raw_result) != TYPE_DICTIONARY:
			report ["success"] = false
			report ["contract_violation"] = true
			report ["quarantined"] = true
			report ["reason"] = (
				"incremental_task_missing_dictionary_result"
			)
			report ["is_complete"] = true
			report ["progress"] = 1.0

		else:
			var result: Dictionary = (
				raw_result as Dictionary
			)

			if (
				not result.has(
					"is_complete"
				)
				or not result.has(
					"progress"
				)
			):
				report ["success"] = false
				report ["contract_violation"] = true
				report ["quarantined"] = true
				report ["reason"] = (
					"incremental_task_missing_progress_contract"
				)
				report ["is_complete"] = true
				report ["progress"] = 1.0

			else:
				report ["result"] = (
					result.duplicate(false)
				)
				report ["is_complete"] = bool(
					result.get(
						"is_complete",
						false
					)
				)
				report ["progress"] = clampf(
					float(
						result.get(
							"progress",
							0.0
						)
					),
					0.0,
					1.0
				)

	elif (
		execution_model
		== YEARLY_EXECUTION_CONSTANT_TIME
	):
		report ["result"] = raw_result
		report ["is_complete"] = true
		report ["progress"] = 1.0

	else:

		report ["result"] = raw_result
		report ["is_complete"] = true
		report ["progress"] = 1.0
		report ["legacy_unclassified"] = true

	if elapsed_ms > max_quantum_ms:
		report ["budget_violation"] = true

		EraLog.truth(
			(
				"ERALIFE_YEARLY_RUNTIME_BUDGET_VIOLATION"
				+ "|listener_id=%s"
				+ "|phase=%s"
				+ "|execution_model=%s"
				+ "|elapsed_ms=%d"
				+ "|budget_ms=%d"
				+ "|at_ms=%d"
			) % [
				listener_id,
				phase_name,
				execution_model,
				elapsed_ms,
				max_quantum_ms,
				int(
					Time.get_ticks_msec()
				)
			]
		)

	var phase_hits_raw: Variant = (
		runtime_last_report.get(
			"phase_hits",
			{}
		)
	)
	var phase_hits: Dictionary = (
		phase_hits_raw as Dictionary
		if typeof(phase_hits_raw) == TYPE_DICTIONARY
		else {}
	)

	phase_hits [
		phase_name
	] = int(
		phase_hits.get(
			phase_name,
			0
		)
	) + 1

	runtime_last_report [
		"phase_hits"
	] = phase_hits
	runtime_last_report [
		"last_yearly_quantum_report"
	] = report.duplicate(false)

	return report

func _runtime_bridge_session_key(phase_name: String, context: Dictionary) -> String:
	return "%s|%d|%s|%s" % [
		phase_name,
		int(context.get("year", gs.year if gs != null else 0)),
		str(context.get("runtime_owner", "age_up_runtime")),
		str(context.get("_runtime_metrics_cache_key", "default"))
	]


func step_runtime_phase_bridge(
	phase_name: String,
	context: Dictionary = {},
	max_listeners: int = 1,
	max_ms: int = 6
) -> Dictionary:
	if gs == null:
		return {
			"state": "complete",
			"is_complete": true,
			"current_phase": phase_name,
			"current_micro_lane": "bridge_idle",
			"phase_progress": 1.0
		}

	if not runtime_defaults_registered:
		register_default_runtime_listeners()

	var session_key: String = (
		_runtime_bridge_session_key(
			phase_name,
			context
		)
	)
	var session_raw: Variant = (
		runtime_bridge_step_sessions.get(
			session_key,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	if session.is_empty():
		var bridge_metrics: Dictionary = (
			_get_cached_runtime_bridge_metrics(
				context
			)
		)

		var lane_ids_raw: Variant = context.get(
			"lane_ids",
			{}
		)
		var lane_ids: Dictionary = (
			lane_ids_raw as Dictionary
			if typeof(lane_ids_raw) == TYPE_DICTIONARY
			else {}
		)

		var groups_raw: Variant = context.get(
			"groups",
			{}
		)
		var groups: Dictionary = (
			groups_raw as Dictionary
			if typeof(groups_raw) == TYPE_DICTIONARY
			else {}
		)

		var mailboxes_raw: Variant = context.get(
			"mailboxes",
			{}
		)
		var mailboxes: Dictionary = (
			mailboxes_raw as Dictionary
			if typeof(mailboxes_raw) == TYPE_DICTIONARY
			else {}
		)

		var execution_manifest_raw: Variant = (
			context.get(
				"execution_manifest",
				{}
			)
		)
		var execution_manifest: Dictionary = (
			execution_manifest_raw as Dictionary
			if typeof(
				execution_manifest_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var bridge_plan: Dictionary = {
			"year": int(
				context.get(
					"year",
					gs.year
				)
			),
			"metrics": bridge_metrics,
			"quality_tier": str(
				context.get(
					"quality_tier",
					_resolve_quality_tier(
						bridge_metrics
					)
				)
			),



			"lane_ids": lane_ids,
			"groups": groups,
			"mailboxes": mailboxes,
			"promoted_ids": context.get(
				"promoted_ids",
				[]
			),
			"execution_manifest": execution_manifest,
			"delta_sink": context.get(
				"delta_sink",
				null
			),
			"emit_typed_delta_method": str(
				context.get(
					"emit_typed_delta_method",
					""
				)
			),
			"phase_delta_defaults": {
				"year": int(
					context.get(
						"year",
						gs.year
					)
				),
				"phase": phase_name,
				"source": str(
					context.get(
						"runtime_owner",
						"age_up_runtime"
					)
				)
			},
			"runtime_owner": str(
				context.get(
					"runtime_owner",
					"age_up_runtime"
				)
			)
		}

		var registered_entries: Array = (
			runtime_phase_registry.get(
				phase_name,
				[]
			)
		)
		var ordered_entries: Array = (
			_resolve_phase_entries(
				registered_entries
			)
		)

		var phase_hits_raw: Variant = (
			runtime_last_report.get(
				"phase_hits",
				{}
			)
		)
		var phase_hits: Dictionary = (
			phase_hits_raw as Dictionary
			if typeof(phase_hits_raw) == TYPE_DICTIONARY
			else {}
		)

		if not phase_hits.has(
			phase_name
		):
			phase_hits [
				phase_name
			] = 0

		runtime_last_report [
			"phase_hits"
		] = phase_hits

		session = {
			"phase_name": phase_name,
			"cursor": 0,
			"entries": ordered_entries,
			"plan": bridge_plan,
			"metrics": bridge_metrics,
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"active_listener_progress": 0.0
		}

	var entries_raw: Variant = session.get(
		"entries",
		[]
	)
	var entries: Array = (
		entries_raw as Array
		if typeof(entries_raw) == TYPE_ARRAY
		else []
	)

	var cursor: int = clampi(
		int(
			session.get(
				"cursor",
				0
			)
		),
		0,
		entries.size()
	)

	var plan_raw: Variant = session.get(
		"plan",
		{}
	)
	var plan: Dictionary = (
		plan_raw as Dictionary
		if typeof(plan_raw) == TYPE_DICTIONARY
		else {}
	)

	var metrics_raw: Variant = session.get(
		"metrics",
		{}
	)
	var metrics: Dictionary = (
		metrics_raw as Dictionary
		if typeof(metrics_raw) == TYPE_DICTIONARY
		else {}
	)

	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var processed: int = 0
	var listener_cap: int = maxi(
		1,
		max_listeners
	)
	var time_cap: int = maxi(
		1,
		max_ms
	)

	var current_listener_id: String = ""
	var current_listener_progress: float = 0.0

	while (
		cursor < entries.size()
		and processed < listener_cap
	):
		var entry_raw: Variant = entries [
			cursor
		]

		if typeof(entry_raw) != TYPE_DICTIONARY:
			cursor += 1
			continue

		var entry: Dictionary = (
			entry_raw as Dictionary
		)
		current_listener_id = str(
			entry.get(
				"id",
				""
			)
		)

		var entry_report: Dictionary = (
			_execute_runtime_phase_entry(
				entry,
				phase_name,
				plan,
				metrics
			)
		)

		processed += 1

		var entry_complete: bool = bool(
			entry_report.get(
				"is_complete",
				true
			)
		)
		current_listener_progress = clampf(
			float(
				entry_report.get(
					"progress",
					1.0
				)
			),
			0.0,
			1.0
		)



		if entry_complete:
			cursor += 1
			current_listener_progress = 0.0

		session [
			"last_listener_report"
		] = entry_report.duplicate(false)

		if not entry_complete:
			break

		if (
			int(
				Time.get_ticks_msec()
			) - started_ms >= time_cap
		):
			break

	session ["cursor"] = cursor
	session [
		"active_listener_progress"
	] = current_listener_progress

	if cursor >= entries.size():
		runtime_bridge_step_sessions.erase(
			session_key
		)

		return {
			"state": "complete",
			"is_complete": true,
			"current_phase": phase_name,
			"current_micro_lane": "bridge_complete",
			"phase_progress": 1.0,
			"processed": processed,
			"ui_concurrent": true,
			"idle_required": false
		}

	runtime_bridge_step_sessions [
		session_key
	] = session

	var phase_progress: float = (
		(
			float(cursor)
			+ current_listener_progress
		)
		/ float(
			maxi(
				1,
				entries.size()
			)
		)
	)

	return {
		"state": "running",
		"is_complete": false,
		"current_phase": phase_name,
		"current_micro_lane": (
			current_listener_id
			if current_listener_id != ""
			else (
				"bridge_listener_%d_of_%d"
				% [
					cursor + 1,
					entries.size()
				]
			)
		),
		"current_listener_id": current_listener_id,
		"listener_progress": (
			current_listener_progress
		),
		"phase_progress": clampf(
			phase_progress,
			0.0,
			0.999
		),
		"processed": processed,
		"ui_concurrent": true,
		"idle_required": false
	}
func _execute_lane_surfaces(plan: Dictionary) -> void:
	if gs == null or gs.year_budget_engine == null:
		return

	var groups: Dictionary = plan.get("groups", {})
	var near_group: Array = []
	var current_player_id: int = int(gs.player.id) if gs.player != null else -1

	for npc in groups.get(LANE_A, []):
		if npc == null:
			continue
		if not gs.afterlife_active and current_player_id > 0 and int(npc.id) == current_player_id:
			continue
		near_group.append(npc)

	gs.year_budget_engine.process_near_npcs(near_group)
	gs.year_budget_engine.run_year_pipeline_immediate({
		"mid": groups.get(LANE_B, []),
		"far": groups.get(LANE_C, []),
		"dormant_hot_ids": plan.get("lane_ids", {}).get(LANE_D, []).duplicate(),
		"quality_tier": str(plan.get("quality_tier", "balanced")),
		"mailboxes": plan.get("mailboxes", {}),
		"runtime_context": {
			"year": int(plan.get("year", gs.year)),
			"runtime_managed": false,
			"phase": PHASE_IDENTITY_DRIFT
		}
	})

func _run_global_pressure_observers(metrics: Dictionary) -> void:
	_check_avatar_presence()
	_check_population(metrics)
	_check_dynasty_dominance(metrics)
	_check_artifact_distribution(metrics)
	_check_class_inequality(metrics)
	_check_fame_clusters(metrics)

func _active_people_from_ids(ids: Array) -> Array:
	var out: Array = []
	for npc_id in ids:
		var npc = gs.get_npc_by_id(int(npc_id))
		if npc != null and npc.alive:
			out.append(npc)
	return out

func _extract_partner_id(person) -> int:
	if person == null or person.partner == null:
		return -1
	if typeof(person.partner) == TYPE_INT:
		return int(person.partner)
	return int(person.partner.id)

func _push_unique_id(ids: Array, candidate_id: int) -> void:
	if candidate_id <= 0:
		return
	if candidate_id not in ids:
		ids.append(candidate_id)

func _push_unique_id_if_missing(ids: Array, candidate_id: int, blocked: Dictionary) -> void:
	if candidate_id <= 0:
		return
	if blocked.has(candidate_id):
		return
	if candidate_id not in ids:
		ids.append(candidate_id)

func _append_id_list(ids: Array, source_ids: Array) -> void:
	for source_id in source_ids:
		_push_unique_id(ids, int(source_id))

func _append_id_list_if_missing(ids: Array, source_ids: Array, blocked: Dictionary) -> void:
	for source_id in source_ids:
		_push_unique_id_if_missing(ids, int(source_id), blocked)

func _get_cached_lane_ids(lane_name: String) -> Array:
	if typeof(runtime_cached_relevance.get("lane_ids", {})) != TYPE_DICTIONARY:
		return []
	return runtime_cached_relevance.get("lane_ids", {}).get(lane_name, [])

func _append_unique_person(arr: Array, npc) -> void:
	if npc == null:
		return
	for existing in arr:
		if existing != null and int(existing.id) == int(npc.id):
			return
	arr.append(npc)

func _finalize_runtime_report(plan: Dictionary, metrics: Dictionary) -> void:
	runtime_last_report ["population"] = int(metrics.get("population", 0))
	runtime_last_report ["active_population"] = int(metrics.get("active_population", 0))
	runtime_last_report ["dormant_population"] = int(gs.dormant_npcs.size())
	runtime_last_report ["player_bubble_count"] = int(plan.get("groups", {}).get(LANE_A, []).size())
	runtime_last_report ["social_ring_count"] = int(plan.get("groups", {}).get(LANE_B, []).size())
	runtime_last_report ["far_ring_count"] = int(plan.get("groups", {}).get(LANE_C, []).size())
	runtime_last_report ["dormant_hot_count"] = int(plan.get("lane_ids", {}).get(LANE_D, []).size())
	runtime_last_report ["total_npcs_touched"] = runtime_last_report ["player_bubble_count"] + runtime_last_report ["social_ring_count"] + runtime_last_report ["far_ring_count"] + runtime_last_report ["promotions"]
	runtime_last_report ["generated_world_feed_entries"] = max(0, int(gs.world_feed.size()) - int(plan.get("world_feed_before", 0)))
	var pending_popups_after: int = int(gs.pending_year_resolution_popups.size()) + int(gs.pending_death_messages.size()) + int(gs.pending_inheritance_messages.size())
	runtime_last_report ["generated_popups"] = max(0, pending_popups_after - int(plan.get("pending_popups_before", 0)))
	runtime_last_report ["generated_scenarios"] = max(0, int(gs.scenario_history.size()) - int(plan.get("scenario_history_before", 0)))
	runtime_last_report ["deferred_jobs"] = 1 if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline() else 0
	runtime_last_report ["skipped_workloads"] = max(0, int(gs.dormant_npcs.size()) - int(plan.get("lane_ids", {}).get(LANE_D, []).size()))

func _gather_metrics() -> Dictionary:
	var pop:= 0
	var shard_pop:= 0
	if gs.population_shard_engine != null:
		shard_pop = gs.population_shard_engine.get_total_sharded_population()
	var dynasty_counts:= {}
	var artifact_total:= 0
	var class_counts:= {}
	var fame_total:= 0
	var fame_elite:= 0
	for npc in gs.npcs:
		if npc.alive:
			pop += 1
			if not dynasty_counts.has(npc.last_name):
				dynasty_counts [npc.last_name] = 0
			dynasty_counts [npc.last_name] += 1
			if gs.artifacts_engine.ownership.has(npc.id):
				artifact_total += gs.artifacts_engine.ownership [npc.id].size()
			if not class_counts.has(npc.social_class):
				class_counts [npc.social_class] = 0
			class_counts [npc.social_class] += 1
			fame_total += npc.fame
			if npc.fame >= 70:
				fame_elite += 1
	return {
		"population": pop + shard_pop,
		"active_population": pop,
		"sharded_population": shard_pop,
		"dynasties": dynasty_counts,
		"artifact_total": artifact_total,
		"class_counts": class_counts,
		"fame_total": fame_total,
		"fame_elite": fame_elite
	}

func _check_population(m):
	var pop = m.population
	if pop < 20:
		gs.push_world_feed(
			"\n📈 Birth rates mysteriously rise worldwide.",
			{
				"category": "world",
				"event_name": "population_pressure",
				"source": "simulation_director"
			}
		)
		_boost_birth_pressure()
	elif pop > 500:
		if randi() % 5 == 0:
			_trigger_global_event("A sudden global pandemic spreads.")

func _boost_birth_pressure():
	for npc in gs.npcs:
		if npc.age >= 20 and npc.age <= 40:
			var partner = gs.get_valid_partner(npc, true)
			if partner != null and randi() % 200 == 0:
				gs.spawn_child(npc, partner, true)

func _check_dynasty_dominance(m):
	var dyn = m.dynasties
	var largest:= 0
	var dominant:= ""
	for name in dyn.keys():
		if dyn [name] > largest:
			largest = dyn [name]
			dominant = name
	if largest > m.population * 0.4:
		if randi() % 4 == 0:
			_trigger_global_event("\n⚖ Political tension rises against the %s dynasty." % dominant)

func _check_artifact_distribution(m):
	if m.artifact_total > 8:
		if randi() % 3 == 0:
			_trigger_global_event("\n🌌 Strange cosmic tremors ripple through reality.")

func _check_class_inequality(m):
	var classes = m.class_counts
	if classes.has("Royal") and classes ["Royal"] > m.population * 0.3:
		_trigger_global_event("\n👑 Too many royals weaken the meaning of royalty.")
	if classes.has("Slave") and classes ["Slave"] > m.population * 0.5:
		_trigger_global_event("\n🔥 A massive slave uprising begins.")

func _check_fame_clusters(m):
	if m.fame_elite > 10:
		if randi() % 3 == 0:
			_trigger_global_event("\n📉 Public interest fragments. Fame begins to dilute.")

func _trigger_global_event(text: String):
	gs.push_world_feed(text, {
		"category": "world",
		"event_name": "simulation_director_event",
		"source": "simulation_director"
	})
	for npc in gs.npcs:
		if randi() % 20 == 0:
			npc.mental_health -= randi_range(1, 5)

func _check_avatar_presence():
	for npc in gs.npcs:
		if npc.bending_type == "avatar":
			if randi() % 100 == 0:
				_trigger_avatar_war(npc)

func _trigger_avatar_war(_avatar):
	gs.push_world_feed(
		"The nations move toward war as the Avatar walks the world.",
		{
			"category": "world",
			"event_name": "avatar_war_pressure",
			"source": "simulation_director"
		}
	)
	for npc in gs.npcs:
		if npc.bending_type == "fire":
			npc.ambition += 10