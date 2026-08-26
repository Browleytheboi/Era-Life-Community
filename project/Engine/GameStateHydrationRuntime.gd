extends Resource
class_name GameStateHydrationRuntime

const HYDRATION_RUNTIME_VERSION:= 1

const PHASE_CORE_IDENTITY:= "core_identity"
const PHASE_STRUCTURAL_SYSTEMS:= "structural_systems"
const PHASE_ENTITY_GRAPH:= "entity_graph"
const PHASE_SYSTEM_STATE:= "system_state"
const PHASE_DERIVED_SYSTEMS:= "derived_systems"
const PHASE_FINALIZATION:= "finalization"

const PHASE_ORDER:= [
	PHASE_CORE_IDENTITY,
	PHASE_STRUCTURAL_SYSTEMS,
	PHASE_ENTITY_GRAPH,
	PHASE_SYSTEM_STATE,
	PHASE_DERIVED_SYSTEMS,
	PHASE_FINALIZATION
]

var gs
var last_hydration_report: Dictionary = {}
var last_merge_report: Dictionary = {}
var preserved_unknown_slices: Dictionary = {}
var background_hydration_active: bool = false
var background_hydration_queue: Array = []
var active_hydration_session: Dictionary = {}
var last_background_hydration_report: Dictionary = {}



var background_authority_thread: Thread = null
var background_authority_context: Dictionary = {}



var background_hydration_service_thread: Thread = null
var background_hydration_service_mutex: Mutex = Mutex.new()
var background_hydration_service_state: Dictionary = {}
func _init(_gs = null):
	gs = _gs

func hydrate_from_path(path: String = "user://savegame.bin", options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		normalized_path = "user://savegame.bin"

	if not FileAccess.file_exists(normalized_path):
		return _fail_report("missing_save_file", "No save file found.", {
			"path": normalized_path
		})

	var decoded: Dictionary = _decode_payload_from_path(normalized_path)
	if not bool(decoded.get("success", false)):
		return decoded

	var payload: Dictionary = decoded.get("data", {})
	var hydration_options: Dictionary = options.duplicate(true)
	hydration_options ["path"] = normalized_path
	hydration_options ["format"] = decoded.get("format", "unknown")

	return hydrate_from_payload(payload, hydration_options)
func _run_background_authority_call_on_worker(
	target: Variant,
	method_name: String,
	arguments: Array,
	validate_after: bool = false
) -> Dictionary:
	if (
		target == null
		or typeof(target) != TYPE_OBJECT
		or not is_instance_valid(target)
	):
		return {
			"success": false,
			"reason": "background_authority_target_invalid",
			"worker_thread_used": true,
		}

	if (
		method_name == ""
		or not target.has_method(
			method_name
		)
	):
		return {
			"success": false,
			"reason": "background_authority_method_unavailable",
			"method_name": method_name,
			"worker_thread_used": true,
		}

	var call_result: Variant = (
		target.callv(
			method_name,
			arguments
		)
	)

	var validation_performed: bool = (
		validate_after
		and target.has_method(
			"validate_state"
		)
	)
	var validation: Variant = null

	if validation_performed:
		validation = target.call(
			"validate_state"
		)

	return {
		"success": true,
		"method_name": method_name,
		"call_result": call_result,
		"validation_performed": validation_performed,
		"validation": validation,
		"worker_thread_used": true,
		"completed_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _service_background_authority_call(
	task_id: String,
	target: Variant,
	method_name: String,
	arguments: Array,
	validate_after: bool = false
) -> Dictionary:
	var clean_task_id: String = str(
		task_id
	).strip_edges()

	if clean_task_id == "":
		return {
			"success": false,
			"complete": true,
			"reason": "background_authority_task_id_missing"
		}

	if background_authority_thread != null:
		var active_thread: Thread = (
			background_authority_thread
		)
		var active_task_id: String = str(
			background_authority_context.get(
				"task_id",
				""
			)
		)

		if active_thread.is_alive():
			return {
				"success": true,
				"complete": false,
				"state": "running",
				"task_id": active_task_id,
				"requested_task_id": clean_task_id,
				"worker_thread_used": true,
				"renderer_thread_poll_only": true
			}

		var worker_result_raw: Variant = (
			active_thread.wait_to_finish()
		)

		background_authority_thread = null
		background_authority_context = {}



		if active_task_id != clean_task_id:
			return {
				"success": true,
				"complete": false,
				"state": "stale_worker_discarded",
				"task_id": clean_task_id,
				"discarded_task_id": active_task_id,
				"worker_thread_used": true
			}

		var worker_result: Dictionary = (
			worker_result_raw as Dictionary
			if typeof(
				worker_result_raw
			) == TYPE_DICTIONARY
			else {
				"success": false,
				"reason": (
					"background_authority_worker_return_invalid"
				)
			}
		)

		worker_result ["complete"] = true
		worker_result ["task_id"] = clean_task_id
		worker_result ["worker_thread_used"] = true
		worker_result [
			"renderer_thread_poll_only"
		] = true

		return worker_result

	if (
		target == null
		or typeof(target) != TYPE_OBJECT
		or not is_instance_valid(target)
	):
		return {
			"success": false,
			"complete": true,
			"task_id": clean_task_id,
			"reason": "background_authority_target_invalid"
		}

	if (
		method_name == ""
		or not target.has_method(
			method_name
		)
	):
		return {
			"success": false,
			"complete": true,
			"task_id": clean_task_id,
			"reason": "background_authority_method_unavailable",
			"method_name": method_name
		}

	var worker:= Thread.new()
	var worker_error: int = worker.start(
		Callable(
			self,
			"_run_background_authority_call_on_worker"
		).bind(
			target,
			method_name,
			arguments,
			validate_after
		),
		Thread.PRIORITY_LOW
	)

	if worker_error != OK:
		return {
			"success": false,
			"complete": true,
			"task_id": clean_task_id,
			"reason": "background_authority_worker_start_failed",
			"worker_error": worker_error,
			"method_name": method_name
		}

	background_authority_thread = worker
	background_authority_context = {
		"task_id": clean_task_id,
		"method_name": method_name,
		"started_at_ms": int(
			Time.get_ticks_msec()
		),
		"worker_thread_used": true,
	}

	return {
		"success": true,
		"complete": false,
		"state": "running",
		"task_id": clean_task_id,
		"method_name": method_name,
		"worker_thread_used": true,
		"renderer_thread_poll_only": true
	}
func hydrate_playable_from_path(path: String = "user://savegame.bin", options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		normalized_path = "user://savegame.bin"

	if not FileAccess.file_exists(normalized_path):
		return _fail_report("missing_save_file", "No save file found.", {
			"path": normalized_path
		})

	var decoded: Dictionary = _decode_payload_from_path(normalized_path)
	if not bool(decoded.get("success", false)):
		return decoded

	var payload: Dictionary = decoded.get("data", {})
	var hydration_options: Dictionary = options.duplicate(true)
	hydration_options ["path"] = normalized_path
	hydration_options ["format"] = decoded.get("format", "unknown")
	hydration_options ["playable_first"] = true
	hydration_options ["background_enabled"] = bool(hydration_options.get("background_enabled", true))
	hydration_options ["playable_npc_limit"] = int(hydration_options.get("playable_npc_limit", 24))
	hydration_options ["defer_consciousness_repair"] = bool(hydration_options.get("defer_consciousness_repair", true))
	hydration_options ["npc_chunk_cap"] = int(hydration_options.get("npc_chunk_cap", 16))
	hydration_options ["partner_chunk_cap"] = int(hydration_options.get("partner_chunk_cap", 48))
	hydration_options ["consciousness_chunk_cap"] = int(hydration_options.get("consciousness_chunk_cap", 12))

	return hydrate_playable_from_payload(payload, hydration_options)

func hydrate_playable_from_payload(
	raw_data: Variant,
	options: Dictionary = {}
) -> Dictionary:
	var started_at: int = int(
		Time.get_ticks_msec()
	)

	if typeof(raw_data) != TYPE_DICTIONARY:
		return _fail_report(
			"corrupted_save",
			" Save corrupted.",
			{
				"typeof": typeof(raw_data)
			}
		)




	var data: Dictionary = (
		raw_data as Dictionary
	)

	if data.is_empty():
		return _fail_report(
			"empty_save",
			" Save corrupted.",
			{}
		)

	_ensure_runtime_dependencies()

	data = _apply_pre_hydration_migrations(
		data,
		options
	)

	if not _passes_minimum_payload_shape(
		data,
		options
	):
		return _fail_report(
			"missing_required_fields",
			"Save missing required fields.",
			{
				"required": [
					"year",
					"next_id",
					"npcs"
				],
				"has_year": data.has(
					"year"
				),
				"has_next_id": data.has(
					"next_id"
				),
				"has_npcs": data.has(
					"npcs"
				)
			}
		)

	var report: Dictionary = {
		"schema": "eralife.game_state_hydration_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"playable": false,
		"background_active": false,
		"source": str(
			options.get(
				"source",
				"hydrate_playable_from_payload"
			)
		),
		"profile": str(
			options.get(
				"profile",
				"playable_first"
			)
		),
		"path": str(
			options.get(
				"path",
				""
			)
		),
		"format": str(
			options.get(
				"format",
				"dictionary"
			)
		),
		"phases": {},
		"hydrated_slices": [],
		"deferred_slices": [],
		"unknown_slices": [],
		"failed_slices": [],
		"repairs": [],
		"warnings": [],
		"started_at_ms": started_at,
		"finished_at_ms": 0,
		"duration_ms": 0,
		"complete_payload_deep_copy_performed": false,
	}

	background_hydration_active = false
	background_hydration_queue.clear()
	active_hydration_session.clear()

	preserved_unknown_slices = _collect_unknown_slices(
		data
	)
	_store_preserved_unknown_slices(
		preserved_unknown_slices,
		report
	)

	var session: Dictionary = {
		"schema": "eralife.live_hydration_session",
		"version": HYDRATION_RUNTIME_VERSION,

		"payload": data,
		"options": options.duplicate(false),
		"report": report.duplicate(false),
		"started_at_ms": started_at,
		"pending_npc_dicts": [],
		"pending_npc_cursor": 0,
		"partner_source_dicts": [],
		"partner_cursor": 0,
		"imported_ids": {},
		"phase_reports": {},
		"state": "boot",
		"complete_payload_deep_copy_performed": false
	}

	var core_report: Dictionary = (
		_begin_phase_report(
			PHASE_CORE_IDENTITY
		)
	)

	_hydrate_core_identity(
		data,
		core_report,
		options
	)
	_commit_phase_report(
		report,
		core_report
	)
	session [
		"phase_reports"
	] [
		PHASE_CORE_IDENTITY
	] = core_report.duplicate(false)

	var structural_report: Dictionary = (
		_begin_phase_report(
			PHASE_STRUCTURAL_SYSTEMS
		)
	)

	_hydrate_structural_systems(
		data,
		structural_report,
		options
	)
	_hydrate_contract_slices_for_phase(
		PHASE_STRUCTURAL_SYSTEMS,
		data,
		structural_report,
		options
	)
	_commit_phase_report(
		report,
		structural_report
	)
	session [
		"phase_reports"
	] [
		PHASE_STRUCTURAL_SYSTEMS
	] = structural_report.duplicate(false)

	var entity_report: Dictionary = (
		_begin_phase_report(
			PHASE_ENTITY_GRAPH
		)
	)

	_hydrate_entity_graph_playable(
		data,
		entity_report,
		options,
		session
	)
	_commit_phase_report(
		report,
		entity_report
	)
	session [
		"phase_reports"
	] [
		PHASE_ENTITY_GRAPH
	] = entity_report.duplicate(false)

	report ["playable"] = (
		gs != null
		and gs.player != null
	)
	report ["success"] = (
		report ["failed_slices"].is_empty()
		and bool(
			report.get(
				"playable",
				false
			)
		)
	)

	if not bool(
		report.get(
			"success",
			false
		)
	):
		report ["finished_at_ms"] = int(
			Time.get_ticks_msec()
		)
		report ["duration_ms"] = (
			int(
				report ["finished_at_ms"]
			) - started_at
		)

		last_hydration_report = (
			_make_binary_safe(
				report
			)
		)

		if gs != null:
			gs.game_state_hydration_report = (
				last_hydration_report.duplicate(false)
			)

			if typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY:
				gs.scenario_state [
					"last_game_state_hydration_report"
				] = (
					last_hydration_report.duplicate(false)
				)

		return last_hydration_report.duplicate(false)

	if bool(
		options.get(
			"background_enabled",
			true
		)
	):
		_schedule_background_hydration_after_playable(
			session
		)

	report ["background_active"] = (
		background_hydration_active
	)
	report ["background_queue_size"] = (
		background_hydration_queue.size()
	)
	report ["finished_at_ms"] = int(
		Time.get_ticks_msec()
	)
	report ["duration_ms"] = (
		int(
			report ["finished_at_ms"]
		) - started_at
	)
	report [
		"complete_payload_deep_copy_performed"
	] = false

	active_hydration_session [
		"report"
	] = report.duplicate(false)

	last_hydration_report = (
		_make_binary_safe(
			report
		)
	)

	if gs != null:
		gs.game_state_hydration_report = (
			last_hydration_report.duplicate(false)
		)

		if typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY:
			gs.scenario_state [
				"game_state_hydration_report"
			] = (
				last_hydration_report.duplicate(false)
			)
			gs.scenario_state [
				"last_game_state_hydration_report"
			] = (
				last_hydration_report.duplicate(false)
			)
			gs.scenario_state [
				"background_hydration_active"
			] = background_hydration_active
			gs.scenario_state [
				"background_hydration_queue_size"
			] = background_hydration_queue.size()
			gs.scenario_state [
				"checkpoint_playable_payload_deep_copy_performed"
			] = false

	return last_hydration_report.duplicate(false)
func begin_resident_checkpoint_spatial_hydration(
	raw_data: Variant,
	spatial_plan: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)

	if typeof(raw_data) != TYPE_DICTIONARY:
		return _fail_report(
			"corrupted_save",
			" Save corrupted.",
			{
				"typeof": typeof(raw_data)
			}
		)

	if gs == null or gs.player == null:
		return _fail_report(
			"resident_checkpoint_actor_missing",
			"Resident checkpoint actor is unavailable.",
			{}
		)

	var data: Dictionary = (
		raw_data as Dictionary
	)

	if data.is_empty():
		return _fail_report(
			"empty_save",
			" Save corrupted.",
			{}
		)

	_ensure_runtime_dependencies()

	background_hydration_active = false
	background_hydration_queue.clear()
	active_hydration_session.clear()

	var actor_id: int = int(
		gs.player.id
	)
	var imported_ids: Dictionary = {
		str(actor_id): true
	}



	var household_rows_raw: Variant = spatial_plan.get(
		"household",
		[]
	)
	var city_rows_raw: Variant = spatial_plan.get(
		"city",
		[]
	)
	var realm_rows_raw: Variant = spatial_plan.get(
		"realm",
		[]
	)
	var world_rows_raw: Variant = spatial_plan.get(
		"world",
		[]
	)

	var tiers: Dictionary = {
		"household": (
			household_rows_raw as Array
			if typeof(household_rows_raw) == TYPE_ARRAY
			else []
		),
		"city": (
			city_rows_raw as Array
			if typeof(city_rows_raw) == TYPE_ARRAY
			else []
		),
		"realm": (
			realm_rows_raw as Array
			if typeof(realm_rows_raw) == TYPE_ARRAY
			else []
		),
		"world": (
			world_rows_raw as Array
			if typeof(world_rows_raw) == TYPE_ARRAY
			else []
		)
	}
	var tier_cursors: Dictionary = {
		"household": 0,
		"city": 0,
		"realm": 0,
		"world": 0
	}
	var report: Dictionary = {
		"schema": "eralife.game_state_hydration_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"playable": true,
		"background_active": true,
		"source": str(
			options.get(
				"source",
				"resident_checkpoint_spatial_hydration"
			)
		),
		"profile": str(
			options.get(
				"profile",
				"resident_checkpoint_spatial_bloom"
			)
		),
		"path": str(
			options.get(
				"path",
				""
			)
		),
		"format": str(
			options.get(
				"format",
				"dictionary"
			)
		),
		"phases": {},
		"hydrated_slices": [],
		"deferred_slices": [],
		"unknown_slices": [],
		"failed_slices": [],
		"repairs": [],
		"warnings": [],
		"started_at_ms": started_at_ms,
		"finished_at_ms": 0,
		"duration_ms": 0,
		"complete_payload_deep_copy_performed": false,
		"spatial_locality_order": [
			"me",
			"my_life",
			"my_household",
			"my_city",
			"my_realm",
			"the_world"
		],
		"actor_id": actor_id,
		"household_pending": (
			tiers [
				"household"
			] as Array
		).size(),
		"city_pending": (
			tiers [
				"city"
			] as Array
		).size(),
		"realm_pending": (
			tiers [
				"realm"
			] as Array
		).size(),
		"world_pending": (
			tiers [
				"world"
			] as Array
		).size(),
		"strict_one_item_per_slice": true,
		"strict_interactive_chunk_caps": true
	}

	var npc_rows_raw: Variant = data.get(
		"npcs",
		[]
	)
	var npc_rows: Array = (
		npc_rows_raw as Array
		if typeof(npc_rows_raw) == TYPE_ARRAY
		else []
	)

	active_hydration_session = {
		"schema": "eralife.live_hydration_session",
		"version": HYDRATION_RUNTIME_VERSION,
		"payload": data,
		"options": options.duplicate(false),
		"report": report.duplicate(false),
		"started_at_ms": started_at_ms,
		"spatial_npc_tiers": tiers,
		"spatial_npc_cursors": tier_cursors,
		"partner_source_dicts": npc_rows,
		"partner_cursor": 0,
		"pending_consciousness_cursor": 0,
		"imported_ids": imported_ids,
		"phase_reports": {},
		"state": "checkpoint_spatial_hydrating",
		"npc_chunk_cap": 1,
		"partner_chunk_cap": 1,
		"consciousness_chunk_cap": 1,
		"strict_one_item_per_slice": true,
		"strict_interactive_chunk_caps": true,
		"complete_payload_deep_copy_performed": false
	}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"defer_deserialize_consciousness_repair"
	] = true
	gs.scenario_state [
		"background_hydration_active"
	] = true
	gs.scenario_state [
		"checkpoint_spatial_hydration_active"
	] = true
	gs.scenario_state [
		"checkpoint_spatial_hydration_tier"
	] = "my_life"
	gs.scenario_state [
		"checkpoint_spatial_hydration_locality_order"
	] = [
		"me",
		"my_life",
		"my_household",
		"my_city",
		"my_realm",
		"the_world"
	]
	gs.scenario_state [
		"checkpoint_spatial_hydration_one_entity_per_quantum"
	] = true

	background_hydration_queue = [
		{
			"kind": "phase",
			"phase": PHASE_CORE_IDENTITY,
			"spatial_tier": "my_life"
		},
		{
			"kind": "spatial_npc_chunk",
			"tier": "household",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "spatial_npc_chunk",
			"tier": "city",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "phase",
			"phase": PHASE_STRUCTURAL_SYSTEMS,
			"spatial_tier": "realm"
		},
		{
			"kind": "spatial_npc_chunk",
			"tier": "realm",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "spatial_npc_chunk",
			"tier": "world",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "checkpoint_entity_state",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "partner_chunk",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "consciousness_chunk",
			"phase": PHASE_ENTITY_GRAPH
		},
		{
			"kind": "phase",
			"phase": PHASE_SYSTEM_STATE
		},
		{
			"kind": "phase",
			"phase": PHASE_DERIVED_SYSTEMS
		},
		{
			"kind": "phase",
			"phase": PHASE_FINALIZATION
		}
	]

	background_hydration_active = true

	gs.scenario_state [
		"background_hydration_queue_size"
	] = background_hydration_queue.size()

	last_hydration_report = _make_binary_safe(
		report
	)
	gs.game_state_hydration_report = (
		last_hydration_report.duplicate(false)
	)

	return {
		"success": true,
		"playable": true,
		"background_active": true,
		"background_queue_size": (
			background_hydration_queue.size()
		),
		"actor_id": actor_id,
		"current_spatial_tier": "my_life",
		"strict_one_item_per_slice": true,
		"strict_interactive_chunk_caps": true,
		"complete_payload_deep_copy_performed": false,
		"started_at_ms": started_at_ms
	}
func _hydrate_pending_spatial_npc_chunk(
	tier: String,
	budget_ms: int,
	started_at_ms: int
) -> bool:
	if gs == null:
		return true

	var clean_tier: String = str(
		tier
	).strip_edges().to_lower()

	var tiers_raw: Variant = active_hydration_session.get(
		"spatial_npc_tiers",
		{}
	)
	var tiers: Dictionary = (
		tiers_raw as Dictionary
		if typeof(tiers_raw) == TYPE_DICTIONARY
		else {}
	)
	var cursors_raw: Variant = active_hydration_session.get(
		"spatial_npc_cursors",
		{}
	)
	var cursors: Dictionary = (
		cursors_raw as Dictionary
		if typeof(cursors_raw) == TYPE_DICTIONARY
		else {}
	)
	var rows_raw: Variant = tiers.get(
		clean_tier,
		[]
	)
	var rows: Array = (
		rows_raw as Array
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)
	var cursor: int = int(
		cursors.get(
			clean_tier,
			0
		)
	)
	var imported_ids_raw: Variant = (
		active_hydration_session.get(
			"imported_ids",
			{}
		)
	)
	var imported_ids: Dictionary = (
		imported_ids_raw as Dictionary
		if typeof(imported_ids_raw) == TYPE_DICTIONARY
		else {}
	)
	var imported_this_slice: int = 0

	while cursor < rows.size():
		if (
			int(Time.get_ticks_msec())
			- started_at_ms
			>= budget_ms
		):
			break

		if imported_this_slice >= 1:
			break

		var raw: Variant = rows [
			cursor
		]
		cursor += 1

		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw as Dictionary
		)
		var npc_id: int = int(
			row.get(
				"id",
				-1
			)
		)

		if npc_id <= 0:
			continue

		var id_key: String = str(
			npc_id
		)

		if imported_ids.has(
			id_key
		):
			continue

		var npc = gs._deserialize_npc(
			row
		)

		if npc == null:
			continue

		gs.npcs.append(
			npc
		)
		gs._remember_npc_in_index(
			npc
		)

		imported_ids [
			id_key
		] = true
		imported_this_slice += 1

	cursors [
		clean_tier
	] = cursor

	active_hydration_session [
		"spatial_npc_cursors"
	] = cursors
	active_hydration_session [
		"imported_ids"
	] = imported_ids

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"checkpoint_spatial_hydration_tier"
		] = clean_tier
		gs.scenario_state [
			"checkpoint_spatial_hydration_tier_cursor"
		] = cursor
		gs.scenario_state [
			"checkpoint_spatial_hydration_tier_count"
		] = rows.size()
		gs.scenario_state [
			"checkpoint_spatial_hydration_last_entity_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return cursor >= rows.size()
func _hydrate_checkpoint_non_npc_entity_state(
	budget_ms: int,
	started_at_ms: int
) -> bool:
	if gs == null:
		return true

	if (
		int(Time.get_ticks_msec())
		- started_at_ms
		>= budget_ms
	):
		return false

	var data_raw: Variant = (
		active_hydration_session.get(
			"payload",
			{}
		)
	)
	var data: Dictionary = (
		data_raw as Dictionary
		if typeof(data_raw) == TYPE_DICTIONARY
		else {}
	)

	if data.is_empty():
		return true

	var stage: int = int(
		active_hydration_session.get(
			"checkpoint_entity_state_stage",
			0
		)
	)

	match stage:
		0:
			if gs.dynasty_engine != null:
				gs.dynasty_engine.dynasties = data.get(
					"dynasties",
					{}
				)

		1:
			if gs.historical_timeline_engine != null:
				gs.historical_timeline_engine.timeline = data.get(
					"historical_timeline",
					{}
				)

		2:
			if gs.world_chronicle_engine != null:
				gs.world_chronicle_engine.timeline = data.get(
					"world_chronicle",
					[]
				)

		3:
			var world_feed_raw: Variant = data.get(
				"world_feed",
				[]
			)

			gs.world_feed = (
				world_feed_raw as Array
				if typeof(world_feed_raw) == TYPE_ARRAY
				else []
			)

			active_hydration_session [
				"checkpoint_world_feed_cursor"
			] = 0

		4:
			var world_feed_cursor: int = int(
				active_hydration_session.get(
					"checkpoint_world_feed_cursor",
					0
				)
			)

			if world_feed_cursor < gs.world_feed.size():
				gs.world_feed [
					world_feed_cursor
				] = gs.normalize_world_feed_entry(
					gs.world_feed [
						world_feed_cursor
					]
				)

				active_hydration_session [
					"checkpoint_world_feed_cursor"
				] = world_feed_cursor + 1

				return false

		5:
			gs.memories = data.get(
				"memories",
				{}
			)

		6:
			if gs.agent_memory_propagation_engine != null:
				gs.agent_memory_propagation_engine.observer_memories = (
					data.get(
						"agent_observer_memories",
						{}
					)
				)

		7:
			gs.compressed_memories = data.get(
				"compressed_memories",
				{}
			)

		8:
			gs.npc_graveyard = data.get(
				"npc_graveyard",
				{}
			)

		9:
			gs.archive_generations = data.get(
				"archive_generations",
				[]
			)

		10:
			gs.dormant_npcs = data.get(
				"dormant_npcs",
				{}
			)

		11:
			if gs.population_shard_engine != null:
				gs.population_shard_engine.population_shards = data.get(
					"population_shards",
					{}
				)

		12:
			if gs.population_shard_engine != null:
				gs.population_shard_engine.lineage_ledger = data.get(
					"lineage_ledger",
					{}
				)

		13:
			if typeof(gs.scenario_state) != TYPE_DICTIONARY:
				gs.scenario_state = {}

			var saved_scenario_raw: Variant = data.get(
				"scenario_state",
				{}
			)
			var saved_scenario: Dictionary = (
				saved_scenario_raw as Dictionary
				if typeof(saved_scenario_raw) == TYPE_DICTIONARY
				else {}
			)

			active_hydration_session [
				"checkpoint_saved_scenario_state"
			] = saved_scenario
			active_hydration_session [
				"checkpoint_saved_scenario_keys"
			] = saved_scenario.keys()
			active_hydration_session [
				"checkpoint_saved_scenario_cursor"
			] = 0

		14:
			var saved_scenario_raw: Variant = (
				active_hydration_session.get(
					"checkpoint_saved_scenario_state",
					{}
				)
			)
			var saved_scenario: Dictionary = (
				saved_scenario_raw as Dictionary
				if typeof(saved_scenario_raw) == TYPE_DICTIONARY
				else {}
			)
			var keys_raw: Variant = (
				active_hydration_session.get(
					"checkpoint_saved_scenario_keys",
					[]
				)
			)
			var keys: Array = (
				keys_raw as Array
				if typeof(keys_raw) == TYPE_ARRAY
				else []
			)
			var scenario_cursor: int = int(
				active_hydration_session.get(
					"checkpoint_saved_scenario_cursor",
					0
				)
			)

			if scenario_cursor < keys.size():
				var raw_key: Variant = keys [
					scenario_cursor
				]
				var key: String = str(
					raw_key
				)

				active_hydration_session [
					"checkpoint_saved_scenario_cursor"
				] = scenario_cursor + 1




				var immutable_checkpoint_observation_key: bool = (
					key in [
						"resident_main_tab_surface_contracts",
						"resident_main_tab_surface_contracts_by_actor",
						"resident_control_switch_support_surface_packet_by_actor",
						"checkpoint_resume_era_audio_context"
					]
				)

				if (
					immutable_checkpoint_observation_key
					or not (
						key.begins_with(
							"resident_"
						)
						or key.begins_with(
							"checkpoint_"
						)
						or key.begins_with(
							"playable_life_"
						)
						or key == "runtime_guard"
						or key == "loading_runtime"
					)
				):
					gs.scenario_state [
						raw_key
					] = saved_scenario [
						raw_key
					]

				return false

		15:
			gs.scenario_history = data.get(
				"scenario_history",
				[]
			)

		16:
			gs.transient_scenario_biases = data.get(
				"transient_scenario_biases",
				{}
			)

		17:
			gs.universal_faction_state = data.get(
				"universal_faction_state",
				{}
			)

		18:
			if typeof(gs.scenario_state) != TYPE_DICTIONARY:
				gs.scenario_state = {}

			gs.scenario_state [
				"checkpoint_spatial_hydration_entity_state_restored"
			] = true
			gs.scenario_state [
				"checkpoint_spatial_hydration_entity_state_restored_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			active_hydration_session.erase(
				"checkpoint_saved_scenario_state"
			)
			active_hydration_session.erase(
				"checkpoint_saved_scenario_keys"
			)
			active_hydration_session.erase(
				"checkpoint_saved_scenario_cursor"
			)
			active_hydration_session.erase(
				"checkpoint_world_feed_cursor"
			)

		_:
			return true

	active_hydration_session [
		"checkpoint_entity_state_stage"
	] = stage + 1

	return stage >= 18
func _run_background_hydration_worker_quantum(
	max_budget_ms: int = 6
) -> Dictionary:
	if not background_hydration_active:
		return {
			"success": true,
			"active": false,
			"complete": true,
			"queue_remaining": 0,
			"worker_thread_used": true,
			"renderer_thread_hydration_performed": false
		}

	var started_at: int = int(
		Time.get_ticks_msec()
	)
	var budget_ms: int = max(
		1,
		int(
			max_budget_ms
		)
	)
	var completed_items: Array = []

	var session_options_raw: Variant = (
		active_hydration_session.get(
			"options",
			{}
		)
	)
	var session_options: Dictionary = (
		session_options_raw as Dictionary
		if typeof(
			session_options_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var strict_one_item_per_slice: bool = bool(
		active_hydration_session.get(
			"strict_one_item_per_slice",
			session_options.get(
				"strict_one_item_per_slice",
				false
			)
		)
	)
	var serviced_items: int = 0

	while (
		background_hydration_queue.size() > 0
		and (
			int(
				Time.get_ticks_msec()
			) - started_at
		) < budget_ms
	):
		if (
			strict_one_item_per_slice
			and serviced_items >= 1
		):
			break

		var item: Dictionary = (
			background_hydration_queue [0]
			if typeof(
				background_hydration_queue [0]
			) == TYPE_DICTIONARY
			else {}
		)

		if item.is_empty():
			background_hydration_queue.pop_front()
			serviced_items += 1
			continue

		var item_complete: bool = (
			_run_background_hydration_item(
				item,
				budget_ms,
				started_at
			)
		)
		serviced_items += 1

		if item_complete:
			completed_items.append(
				item.duplicate(false)
			)
			background_hydration_queue.pop_front()
		else:
			break

	if background_hydration_queue.is_empty():
		_complete_background_hydration()

	var report: Dictionary = {
		"schema": "eralife.background_hydration_slice_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"active": background_hydration_active,
		"complete": not background_hydration_active,
		"completed_items": completed_items,
		"queue_remaining": background_hydration_queue.size(),
		"duration_ms": (
			int(
				Time.get_ticks_msec()
			) - started_at
		),
		"strict_one_item_per_slice": (
			strict_one_item_per_slice
		),
		"serviced_items": serviced_items,
		"worker_thread_used": true,
		"renderer_thread_hydration_performed": false,
		"ui_interaction_pauses_simulation": false,
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}

	last_background_hydration_report = (
		_make_binary_safe(
			report
		)
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"background_hydration_active"
		] = background_hydration_active
		gs.scenario_state [
			"background_hydration_queue_size"
		] = background_hydration_queue.size()
		gs.scenario_state [
			"last_background_hydration_report"
		] = (
			last_background_hydration_report
			.duplicate(false)
		)
		gs.scenario_state [
			"background_hydration_worker_thread_used"
		] = true
		gs.scenario_state [
			"background_hydration_renderer_thread_work"
		] = false
		gs.scenario_state [
			"background_hydration_ui_interaction_pauses_simulation"
		] = false

	return (
		last_background_hydration_report
		.duplicate(false)
	)
func run_background_hydration_slice(
	max_budget_ms: int = 6
) -> Dictionary:



	if background_hydration_service_thread != null:
		var existing_worker: Thread = (
			background_hydration_service_thread
		)

		if existing_worker.is_alive():
			return (
				_background_hydration_service_state_snapshot()
			)

		var finished_raw: Variant = (
			existing_worker.wait_to_finish()
		)

		background_hydration_service_thread = null

		if typeof(
			finished_raw
		) == TYPE_DICTIONARY:
			background_hydration_service_mutex.lock()
			background_hydration_service_state = (
				(
					finished_raw as Dictionary
				).duplicate(false)
			)
			background_hydration_service_mutex.unlock()

	if not background_hydration_active:
		var completed_state: Dictionary = (
			_background_hydration_service_state_snapshot()
		)

		if not completed_state.is_empty():
			completed_state ["active"] = false
			completed_state ["complete"] = true
			completed_state [
				"renderer_thread_hydration_performed"
			] = false
			return completed_state

		return {
			"success": true,
			"active": false,
			"complete": true,
			"queue_remaining": 0,
			"worker_thread_used": true,
			"renderer_thread_hydration_performed": false
		}

	return _start_background_hydration_service_worker(
		maxi(
			1,
			max_budget_ms
		)
	)
func _background_hydration_service_state_snapshot() -> Dictionary:
	background_hydration_service_mutex.lock()

	var snapshot: Dictionary = (
		background_hydration_service_state
		.duplicate(false)
	)

	background_hydration_service_mutex.unlock()

	return snapshot
func _start_background_hydration_service_worker(
	max_budget_ms: int
) -> Dictionary:
	if not background_hydration_active:
		return {
			"success": true,
			"active": false,
			"complete": true,
			"queue_remaining": 0,
			"worker_thread_used": true,
			"renderer_thread_hydration_performed": false
		}

	if background_hydration_service_thread != null:
		var existing_worker: Thread = (
			background_hydration_service_thread
		)

		if existing_worker.is_alive():
			return (
				_background_hydration_service_state_snapshot()
			)

		var finished_raw: Variant = (
			existing_worker.wait_to_finish()
		)

		background_hydration_service_thread = null

		if typeof(
			finished_raw
		) == TYPE_DICTIONARY:
			background_hydration_service_mutex.lock()
			background_hydration_service_state = (
				(
					finished_raw as Dictionary
				).duplicate(false)
			)
			background_hydration_service_mutex.unlock()

	var safe_budget_ms: int = maxi(
		1,
		max_budget_ms
	)
	var initial_state: Dictionary = {
		"schema": "eralife.background_hydration_service_state",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"active": true,
		"complete": false,
		"queue_remaining": (
			background_hydration_queue.size()
		),
		"worker_thread_used": true,
		"worker_thread_active": true,
		"worker_priority": "low",
		"renderer_thread_hydration_performed": false,
		"ui_interaction_pauses_simulation": false,
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	background_hydration_service_mutex.lock()
	background_hydration_service_state = (
		initial_state.duplicate(false)
	)
	background_hydration_service_mutex.unlock()

	var worker:= Thread.new()
	var worker_error: int = worker.start(
		Callable(
			self,
			"_run_background_hydration_service_worker"
		).bind(
			safe_budget_ms
		),
		Thread.PRIORITY_LOW
	)

	if worker_error != OK:
		var failure: Dictionary = {
			"schema": "eralife.background_hydration_service_state",
			"version": HYDRATION_RUNTIME_VERSION,
			"success": false,
			"active": false,
			"complete": false,
			"reason": "background_hydration_service_worker_start_failed",
			"worker_error": worker_error,
			"worker_thread_used": false,
			"renderer_thread_hydration_performed": false,
			"failed_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		background_hydration_service_mutex.lock()
		background_hydration_service_state = (
			failure.duplicate(false)
		)
		background_hydration_service_mutex.unlock()

		return failure

	background_hydration_service_thread = worker

	return initial_state
func _run_background_hydration_service_worker(
	max_budget_ms: int
) -> Dictionary:
	var safe_budget_ms: int = maxi(
		1,
		max_budget_ms
	)
	var final_report: Dictionary = {
		"success": true,
		"active": background_hydration_active,
		"complete": not background_hydration_active,
		"queue_remaining": 0
	}

	if background_hydration_active:
		var quantum_report: Dictionary = (
			_run_background_hydration_worker_quantum(
				safe_budget_ms
			)
		)

		final_report = (
			quantum_report.duplicate(false)
		)

	final_report [
		"worker_thread_used"
	] = true
	final_report [
		"worker_thread_active"
	] = false
	final_report [
		"renderer_thread_hydration_performed"
	] = false
	final_report [
		"ui_interaction_pauses_simulation"
	] = false
	final_report [
		"one_worker_quantum_per_service_invocation"
	] = true
	final_report [
		"continuous_worker_loop_forbidden"
	] = true
	final_report [
		"worker_thread_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	background_hydration_service_mutex.lock()
	background_hydration_service_state = (
		final_report.duplicate(false)
	)
	background_hydration_service_mutex.unlock()

	return final_report

func is_background_hydration_active() -> bool:
	return background_hydration_active

func _schedule_background_hydration_after_playable(
	session: Dictionary
) -> void:


	active_hydration_session = session.duplicate(false)

	if session.has(
		"payload"
	):
		active_hydration_session [
			"payload"
		] = session.get(
			"payload"
		)

	background_hydration_queue.clear()

	var pending_npcs: Array = _safe_array(
		active_hydration_session.get(
			"pending_npc_dicts",
			[]
		)
	)

	if not pending_npcs.is_empty():
		background_hydration_queue.append({
			"kind": "npc_chunk",
			"phase": PHASE_ENTITY_GRAPH
		})

	var partner_sources: Array = _safe_array(
		active_hydration_session.get(
			"partner_source_dicts",
			[]
		)
	)

	if not partner_sources.is_empty():
		background_hydration_queue.append({
			"kind": "partner_chunk",
			"phase": PHASE_ENTITY_GRAPH
		})

	var session_options: Dictionary = (
		active_hydration_session.get(
			"options",
			{}
		)
		if typeof(
			active_hydration_session.get(
				"options",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		session_options.get(
			"defer_consciousness_repair",
			true
		)
	):
		background_hydration_queue.append({
			"kind": "consciousness_chunk",
			"phase": PHASE_ENTITY_GRAPH
		})

	background_hydration_queue.append({
		"kind": "phase",
		"phase": PHASE_SYSTEM_STATE
	})
	background_hydration_queue.append({
		"kind": "phase",
		"phase": PHASE_DERIVED_SYSTEMS
	})
	background_hydration_queue.append({
		"kind": "phase",
		"phase": PHASE_FINALIZATION
	})

	active_hydration_session [
		"state"
	] = "background_hydrating"
	active_hydration_session [
		"complete_payload_deep_copy_performed"
	] = false

	background_hydration_active = true

func _run_background_hydration_item(
	item: Dictionary,
	budget_ms: int,
	started_at_ms: int
) -> bool:
	var kind: String = str(
		item.get(
			"kind",
			""
		)
	).strip_edges()

	match kind:
		"spatial_npc_chunk":
			return _hydrate_pending_spatial_npc_chunk(
				str(
					item.get(
						"tier",
						"world"
					)
				),
				budget_ms,
				started_at_ms
			)

		"checkpoint_entity_state":
			return _hydrate_checkpoint_non_npc_entity_state(
				budget_ms,
				started_at_ms
			)

		"npc_chunk":
			return _hydrate_pending_npc_chunk(
				budget_ms,
				started_at_ms
			)

		"partner_chunk":
			return _hydrate_pending_partner_chunk(
				budget_ms,
				started_at_ms
			)

		"consciousness_chunk":
			return _hydrate_pending_consciousness_chunk(
				budget_ms,
				started_at_ms
			)

		"phase":
			var phase_id: String = str(
				item.get(
					"phase",
					""
				)
			).strip_edges()
			var spatial_tier: String = str(
				item.get(
					"spatial_tier",
					""
				)
			).strip_edges()

			if (
				spatial_tier != ""
				and gs != null
				and typeof(gs.scenario_state)
				== TYPE_DICTIONARY
			):
				gs.scenario_state [
					"checkpoint_spatial_hydration_tier"
				] = spatial_tier

			if (
				int(Time.get_ticks_msec())
				- started_at_ms
				>= budget_ms
			):
				return false

			return _hydrate_background_phase(
				phase_id
			)

		_:
			return true

func _hydrate_pending_npc_chunk(
	budget_ms: int,
	started_at_ms: int
) -> bool:
	if gs == null:
		return true



	var pending_raw: Variant = (
		active_hydration_session.get(
			"pending_npc_dicts",
			[]
		)
	)
	var pending: Array = (
		pending_raw as Array
		if typeof(pending_raw) == TYPE_ARRAY
		else []
	)
	var cursor: int = int(
		active_hydration_session.get(
			"pending_npc_cursor",
			0
		)
	)
	var imported_ids: Dictionary = (
		active_hydration_session.get(
			"imported_ids",
			{}
		)
		if typeof(
			active_hydration_session.get(
				"imported_ids",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var imported_this_slice: int = 0
	var hard_chunk_cap: int = int(
		active_hydration_session.get(
			"npc_chunk_cap",
			64
		)
	)
	var strict_interactive_chunk_caps: bool = bool(
		active_hydration_session.get(
			"strict_interactive_chunk_caps",
			false
		)
	)

	if strict_interactive_chunk_caps:
		hard_chunk_cap = 1
	else:
		hard_chunk_cap = max(
			8,
			hard_chunk_cap
		)

	while cursor < pending.size():
		if (
			int(Time.get_ticks_msec())
			- started_at_ms
			>= budget_ms
		):
			break

		if imported_this_slice >= hard_chunk_cap:
			break

		var raw: Variant = pending [
			cursor
		]
		cursor += 1

		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = raw
		var npc_id: int = int(
			d.get(
				"id",
				-1
			)
		)

		if npc_id <= 0:
			continue

		var id_key: String = str(
			npc_id
		)

		if imported_ids.has(
			id_key
		):
			continue

		var npc = gs._deserialize_npc(
			d
		)

		if npc == null:
			continue

		gs.npcs.append(
			npc
		)
		gs._remember_npc_in_index(
			npc
		)

		imported_ids [
			id_key
		] = true
		imported_this_slice += 1

	active_hydration_session [
		"pending_npc_cursor"
	] = cursor
	active_hydration_session [
		"imported_ids"
	] = imported_ids

	return cursor >= pending.size()

func _hydrate_pending_partner_chunk(
	budget_ms: int,
	started_at_ms: int
) -> bool:
	if gs == null:
		return true



	var sources_raw: Variant = (
		active_hydration_session.get(
			"partner_source_dicts",
			[]
		)
	)
	var sources: Array = (
		sources_raw as Array
		if typeof(sources_raw) == TYPE_ARRAY
		else []
	)
	var cursor: int = int(
		active_hydration_session.get(
			"partner_cursor",
			0
		)
	)
	var processed_this_slice: int = 0
	var hard_chunk_cap: int = int(
		active_hydration_session.get(
			"partner_chunk_cap",
			96
		)
	)
	var strict_interactive_chunk_caps: bool = bool(
		active_hydration_session.get(
			"strict_interactive_chunk_caps",
			false
		)
	)

	hard_chunk_cap = max(
		1 if strict_interactive_chunk_caps else 16,
		hard_chunk_cap
	)

	while cursor < sources.size():
		if (
			int(Time.get_ticks_msec())
			- started_at_ms
			>= budget_ms
		):
			break

		if processed_this_slice >= hard_chunk_cap:
			break

		var raw: Variant = sources [
			cursor
		]
		cursor += 1

		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = (
			raw as Dictionary
		)
		var npc_id: int = int(
			d.get(
				"id",
				-1
			)
		)

		if npc_id <= 0:
			continue

		var npc = gs.get_npc_by_id(
			npc_id
		)

		if npc == null:
			continue

		var partner_id: int = int(
			d.get(
				"partner_id",
				-1
			)
		)

		if partner_id != -1:
			npc.partner = gs.get_npc_by_id(
				partner_id
			)
		else:
			npc.partner = null

		gs.get_valid_partner(
			npc,
			true
		)

		processed_this_slice += 1

	active_hydration_session [
		"partner_cursor"
	] = cursor

	return cursor >= sources.size()
func _hydrate_pending_consciousness_chunk(
	budget_ms: int,
	started_at_ms: int
) -> bool:
	if gs == null:
		return true

	var options: Dictionary = (
		active_hydration_session.get(
			"options",
			{}
		)
		if typeof(
			active_hydration_session.get(
				"options",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var cursor: int = int(
		active_hydration_session.get(
			"pending_consciousness_cursor",
			0
		)
	)
	var repaired_this_slice: int = 0
	var hard_chunk_cap: int = int(
		options.get(
			"consciousness_chunk_cap",
			active_hydration_session.get(
				"consciousness_chunk_cap",
				12
			)
		)
	)
	var strict_interactive_chunk_caps: bool = bool(
		active_hydration_session.get(
			"strict_interactive_chunk_caps",
			options.get(
				"strict_interactive_chunk_caps",
				false
			)
		)
	)

	hard_chunk_cap = max(
		1 if strict_interactive_chunk_caps else 4,
		hard_chunk_cap
	)

	while cursor < gs.npcs.size():
		if (
			int(Time.get_ticks_msec())
			- started_at_ms
			>= budget_ms
		):
			break

		if repaired_this_slice >= hard_chunk_cap:
			break

		var npc = gs.npcs [
			cursor
		]
		cursor += 1

		if npc == null:
			continue

		if gs.consciousness_engine != null:
			gs.consciousness_engine.ensure_consciousness(
				npc,
				{
					"source": (
						"background_hydration_consciousness_chunk"
					)
				}
			)

		if (
			"willpower_engine" in gs
			and gs.willpower_engine != null
			and gs.willpower_engine.has_method(
				"ensure_willpower"
			)
		):
			gs.willpower_engine.ensure_willpower(
				npc,
				{
					"source": (
						"background_hydration_consciousness_chunk"
					)
				}
			)

		repaired_this_slice += 1

	active_hydration_session [
		"pending_consciousness_cursor"
	] = cursor

	return cursor >= gs.npcs.size()
func _hydrate_background_phase(
	phase_id: String
) -> bool:
	if gs == null:
		return true

	var data_raw: Variant = (
		active_hydration_session.get(
			"payload",
			{}
		)
	)
	var data: Dictionary = (
		data_raw as Dictionary
		if typeof(data_raw) == TYPE_DICTIONARY
		else {}
	)

	var options_raw: Variant = (
		active_hydration_session.get(
			"options",
			{}
		)
	)
	var options: Dictionary = (
		options_raw as Dictionary
		if typeof(options_raw) == TYPE_DICTIONARY
		else {}
	)

	var phase_reports_raw: Variant = (
		active_hydration_session.get(
			"phase_reports",
			{}
		)
	)
	var phase_reports: Dictionary = (
		phase_reports_raw as Dictionary
		if typeof(phase_reports_raw) == TYPE_DICTIONARY
		else {}
	)

	var phase_report_raw: Variant = (
		phase_reports.get(
			phase_id,
			{}
		)
	)
	var phase_report: Dictionary = (
		phase_report_raw as Dictionary
		if typeof(phase_report_raw) == TYPE_DICTIONARY
		else {}
	)

	if phase_report.is_empty():
		phase_report = (
			_begin_phase_report(
				phase_id
			)
		)

	var phase_complete: bool = false

	match phase_id:
		PHASE_CORE_IDENTITY:
			if not bool(
				active_hydration_session.get(
					"background_core_identity_complete",
					false
				)
			):
				_hydrate_core_identity(
					data,
					phase_report,
					options
				)

				active_hydration_session [
					"background_core_identity_complete"
				] = true

			phase_complete = true

		PHASE_STRUCTURAL_SYSTEMS:
			phase_complete = (
				_hydrate_structural_systems_background_quantum(
					data,
					phase_report,
					options
				)
			)

			if phase_complete:
				phase_complete = (
					_hydrate_contract_slices_for_phase_background_quantum(
						PHASE_STRUCTURAL_SYSTEMS,
						data,
						phase_report,
						options
					)
				)

		PHASE_SYSTEM_STATE:
			phase_complete = (
				_hydrate_contract_slices_for_phase_background_quantum(
					PHASE_SYSTEM_STATE,
					data,
					phase_report,
					options
				)
			)

		PHASE_DERIVED_SYSTEMS:
			var slices_complete: bool = (
				_hydrate_contract_slices_for_phase_background_quantum(
					PHASE_DERIVED_SYSTEMS,
					data,
					phase_report,
					options
				)
			)

			if slices_complete:
				if not bool(
					active_hydration_session.get(
						"background_derived_systems_complete",
						false
					)
				):
					_hydrate_derived_systems(
						data,
						phase_report,
						options
					)

					active_hydration_session [
						"background_derived_systems_complete"
					] = true

				phase_complete = true

		PHASE_FINALIZATION:
			phase_complete = (
				_finalize_hydration_background_quantum(
					data,
					phase_report,
					options
				)
			)

		_:
			return true

	phase_reports [
		phase_id
	] = phase_report
	active_hydration_session [
		"phase_reports"
	] = phase_reports

	if not phase_complete:
		active_hydration_session [
			"background_last_phase_id"
		] = phase_id
		active_hydration_session [
			"background_last_phase_complete"
		] = false

		return false

	phase_report [
		"finished_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	phase_report [
		"duration_ms"
	] = int(
		phase_report [
			"finished_at_ms"
		]
	) - int(
		phase_report [
			"started_at_ms"
		]
	)

	var report_raw: Variant = (
		active_hydration_session.get(
			"report",
			{}
		)
	)
	var report: Dictionary = (
		report_raw as Dictionary
		if typeof(report_raw) == TYPE_DICTIONARY
		else {}
	)

	_commit_phase_report(
		report,
		phase_report
	)

	active_hydration_session [
		"report"
	] = report
	active_hydration_session [
		"phase_reports"
	] = phase_reports
	active_hydration_session [
		"background_last_phase_id"
	] = phase_id
	active_hydration_session [
		"background_last_phase_complete"
	] = true



	last_hydration_report = (
		report.duplicate(false)
	)

	gs.game_state_hydration_report = (
		last_hydration_report.duplicate(false)
	)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"game_state_hydration_report"
		] = last_hydration_report.duplicate(false)
		gs.scenario_state [
			"last_game_state_hydration_report"
		] = last_hydration_report.duplicate(false)
		gs.scenario_state [
			"background_hydration_phase_is_cooperative"
		] = true
		gs.scenario_state [
			"background_hydration_phase_id"
		] = phase_id

	return true
func _hydrate_structural_systems_background_quantum(
	data: Dictionary,
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	if gs == null:
		return true

	var resident_hot_graph_restore: bool = (
		bool(
			options.get(
				"resident_restore",
				false
			)
		)
		and bool(
			options.get(
				"resident_engine_graph_ready",
				false
			)
		)
	)
	var detached_resident_restore: bool = (
		resident_hot_graph_restore
		and not bool(
			options.get(
				"runtime_scene_tree_access_allowed",
				true
			)
		)
	)
	var cursor: int = int(
		active_hydration_session.get(
			"background_structural_systems_cursor",
			0
		)
	)
	var quantum_complete: bool = true

	match cursor:
		0:
			var loaded_realm_map: Dictionary = (
				gs._normalize_loaded_realm_map(
					data.get(
						"realm_realms",
						{}
					)
				)
			)

			if (
				not loaded_realm_map.is_empty()
				and gs.realm_engine != null
			):
				gs.realm_engine.realms = loaded_realm_map
				phase_report ["hydrated"].append({
					"id": "realm_realms",
					"count": loaded_realm_map.size(),
				})
			elif not resident_hot_graph_restore:
				if (
					gs.realm_engine != null
					and gs.realm_engine.has_method(
						"bootstrap_realms_for_era"
					)
				):
					gs.realm_engine.bootstrap_realms_for_era()
					phase_report ["hydrated"].append({
						"id": "realm_bootstrap"
					})
			else:
				phase_report ["deferred"].append({
					"id": "realm_bootstrap",
					"reason": (
						"resident_hot_engine_graph_may_not_rebootstrap"
					)
				})

		1:
			quantum_complete = (
				_import_registry_background_quantum(
					"game_state_contract_engine",
					"game_state_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		2:
			quantum_complete = (
				_import_registry_background_quantum(
					"realm_contract_engine",
					"realm_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		3:
			quantum_complete = (
				_import_registry_background_quantum(
					"simulation_contract_engine",
					"simulation_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		4:
			quantum_complete = (
				_import_registry_background_quantum(
					"ui_contract_engine",
					"ui_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		5:
			quantum_complete = (
				_import_registry_background_quantum(
					"world_engine",
					"world_engine_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		6:
			quantum_complete = (
				_import_registry_background_quantum(
					"life_engine",
					"life_engine_contract_registry",
					"import_registry",
					data,
					phase_report,
					options
				)
			)

		7:
			if resident_hot_graph_restore:
				phase_report ["hydrated"].append({
					"id": "realm_runtime_maps",
					"source": "persisted_hot_resident_graph",
				})
			elif (
				gs.realm_contract_engine != null
				and gs.realm_contract_engine.has_method(
					"repair_runtime_realm_maps"
				)
			):
				gs.realm_contract_engine.repair_runtime_realm_maps()
				phase_report ["repairs"].append(
					"realm_contract_engine.repair_runtime_realm_maps"
				)

		8:
			if resident_hot_graph_restore:
				phase_report ["hydrated"].append({
					"id": "simulation_external_packs",
					"source": "already_hot_engine_graph",
				})
			elif (
				gs.simulation_contract_engine != null
				and gs.simulation_contract_engine.has_method(
					"load_external_packs"
				)
			):
				gs.simulation_contract_engine.load_external_packs()
				phase_report ["hydrated"].append({
					"id": "simulation_external_packs"
				})

		9:
			if (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"import_save_slices"
				)
			):
				if detached_resident_restore:
					var worker_report: Dictionary = (
						_service_background_authority_call(
							"structural:game_state_contract_slices",
							gs.game_state_contract_engine,
							"import_save_slices",
							[
								data.get(
									"game_state_contract_slices",
									{}
								)
							],
							false
						)
					)

					if not bool(
						worker_report.get(
							"complete",
							false
						)
					):
						quantum_complete = false
					elif bool(
						worker_report.get(
							"success",
							false
						)
					):
						phase_report ["hydrated"].append({
							"id": "game_state_contract_slices",
							"worker_thread_used": true,
						})
					else:
						phase_report ["failed"].append({
							"id": "game_state_contract_slices",
							"reason": str(
								worker_report.get(
									"reason",
									"game_state_contract_slices_import_failed"
								)
							),
							"worker_thread_used": true
						})
				else:
					gs.game_state_contract_engine.import_save_slices(
						data.get(
							"game_state_contract_slices",
							{}
						)
					)
					phase_report ["hydrated"].append({
						"id": "game_state_contract_slices"
					})

		10:
			if resident_hot_graph_restore:
				phase_report ["hydrated"].append({
					"id": "registered_existing_engines",
					"source": "already_hot_engine_graph",
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"register_existing_engines_from_game_state"
				)
			):
				gs.game_state_contract_engine.register_existing_engines_from_game_state()
				phase_report ["hydrated"].append({
					"id": "registered_existing_engines"
				})

		_:
			return true

	if not quantum_complete:
		active_hydration_session [
			"background_structural_system_waiting_cursor"
		] = cursor
		return false

	active_hydration_session.erase(
		"background_structural_system_waiting_cursor"
	)

	cursor += 1
	active_hydration_session [
		"background_structural_systems_cursor"
	] = cursor

	return cursor >= 11
func _hydrate_contract_slices_for_phase_background_quantum(
	phase_id: String,
	data: Dictionary,
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	var contracts_raw: Variant = (
		active_hydration_session.get(
			"background_save_slice_contracts",
			null
		)
	)
	var contracts: Array = []

	if typeof(contracts_raw) == TYPE_ARRAY:
		contracts = contracts_raw as Array
	else:
		contracts = _resolve_save_slice_contracts()
		active_hydration_session [
			"background_save_slice_contracts"
		] = contracts

	var cursor_by_phase_raw: Variant = (
		active_hydration_session.get(
			"background_contract_slice_cursor_by_phase",
			{}
		)
	)
	var cursor_by_phase: Dictionary = (
		cursor_by_phase_raw as Dictionary
		if typeof(
			cursor_by_phase_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var cursor: int = int(
		cursor_by_phase.get(
			phase_id,
			0
		)
	)

	if cursor >= contracts.size():
		return true

	var raw_contract: Variant = contracts [
		cursor
	]




	if typeof(raw_contract) != TYPE_DICTIONARY:
		cursor += 1
		cursor_by_phase [
			phase_id
		] = cursor
		active_hydration_session [
			"background_contract_slice_cursor_by_phase"
		] = cursor_by_phase
		return cursor >= contracts.size()

	var slice_contract: Dictionary = (
		raw_contract as Dictionary
	)
	var save_key: String = str(
		slice_contract.get(
			"save_key",
			slice_contract.get(
				"id",
				""
			)
		)
	).strip_edges()

	if (
		save_key == ""
		or _phase_for_slice(
			slice_contract
		) != phase_id
		or not data.has(
			save_key
		)
	):
		cursor += 1
		cursor_by_phase [
			phase_id
		] = cursor
		active_hydration_session [
			"background_contract_slice_cursor_by_phase"
		] = cursor_by_phase
		return cursor >= contracts.size()

	var import_complete: bool = (
		_hydrate_engine_slice(
			slice_contract,
			data.get(
				save_key
			),
			phase_report,
			options
		)
	)

	if not import_complete:
		active_hydration_session [
			"background_contract_slice_waiting_save_key"
		] = save_key
		active_hydration_session [
			"background_contract_slice_waiting_phase"
		] = phase_id
		return false

	active_hydration_session.erase(
		"background_contract_slice_waiting_save_key"
	)
	active_hydration_session.erase(
		"background_contract_slice_waiting_phase"
	)

	cursor += 1
	cursor_by_phase [
		phase_id
	] = cursor
	active_hydration_session [
		"background_contract_slice_cursor_by_phase"
	] = cursor_by_phase

	return cursor >= contracts.size()
func _reconcile_runtime_state_background_quantum(
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	if gs == null:
		phase_report [
			"failed"
		].append({
			"reason": (
				"GameState unavailable during reconciliation."
			)
		})
		return true

	if not bool(
		active_hydration_session.get(
			"background_reconcile_initialized",
			false
		)
	):
		var resident_restore: bool = bool(
			options.get(
				"resident_restore",
				false
			)
		)



		if (
			not resident_restore
			and gs.has_method(
				"_rebuild_npc_index"
			)
		):
			gs._rebuild_npc_index()
			phase_report [
				"repairs"
			].append(
				"_rebuild_npc_index"
			)

		if (
			gs.player == null
			and gs.npcs.size() > 0
		):
			gs.player = gs.npcs [
				0
			]
			phase_report [
				"repairs"
			].append(
				"player_fallback_from_npcs"
			)

		gs.player_id = (
			gs.player.id
			if gs.player != null
			else -1
		)

		active_hydration_session [
			"background_reconcile_initialized"
		] = true
		active_hydration_session [
			"background_reconcile_npc_cursor"
		] = 0

		return false

	var npc_cursor: int = int(
		active_hydration_session.get(
			"background_reconcile_npc_cursor",
			0
		)
	)

	if npc_cursor < gs.npcs.size():
		var npc = gs.npcs [
			npc_cursor
		]

		active_hydration_session [
			"background_reconcile_npc_cursor"
		] = npc_cursor + 1

		if npc != null:
			if (
				"parents" in npc
				and typeof(npc.parents) != TYPE_ARRAY
			):
				npc.parents = []

			if (
				"children" in npc
				and typeof(npc.children) != TYPE_ARRAY
			):
				npc.children = []

			if (
				"friends" in npc
				and typeof(npc.friends) != TYPE_ARRAY
			):
				npc.friends = []

			if (
				"partner" in npc
				and npc.partner != null
				and gs.get_npc_by_id(
					int(
						npc.partner.id
					)
				) == null
			):
				npc.partner = null

		return false

	if not bool(
		active_hydration_session.get(
			"background_reconcile_realm_complete",
			false
		)
	):
		if (
			gs.realm_contract_engine != null
			and gs.realm_contract_engine.has_method(
				"repair_runtime_realm_maps"
			)
		):
			gs.realm_contract_engine.repair_runtime_realm_maps()
			phase_report [
				"repairs"
			].append(
				"realm_contract_engine.repair_runtime_realm_maps"
			)

		active_hydration_session [
			"background_reconcile_realm_complete"
		] = true

		return false

	return true


func _finalize_hydration_background_quantum(
	data: Dictionary,
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	if gs == null:
		phase_report [
			"failed"
		].append({
			"reason": "GameState unavailable."
		})
		return true

	var resident_hot_graph_restore: bool = (
		bool(
			options.get(
				"resident_restore",
				false
			)
		)
		and bool(
			options.get(
				"resident_engine_graph_ready",
				false
			)
		)
	)
	var detached_resident_restore: bool = (
		resident_hot_graph_restore
		and not bool(
			options.get(
				"runtime_scene_tree_access_allowed",
				true
			)
		)
	)
	var cursor: int = int(
		active_hydration_session.get(
			"background_finalization_cursor",
			0
		)
	)

	match cursor:
		0:
			gs.custom_mode = bool(
				data.get(
					"custom_mode",
					false
				)
			)
			gs.custom_settings = data.get(
				"custom_settings",
				{}
			)
			gs.reality_mode = str(
				data.get(
					"reality_mode",
					gs.custom_settings.get(
						"reality_mode",
						gs.REALITY_CHAOS
					)
				)
			).to_lower()
			gs.reality_feature_overrides = (
				data.get(
					"feature_overrides",
					gs.custom_settings.get(
						"feature_overrides",
						{}
					)
				)
				.duplicate()
			)

		1:
			gs._hydrate_reality_settings()

		2:
			if detached_resident_restore:
				var worker_report: Dictionary = (
					_service_background_authority_call(
						"finalization:apply_reality_mode_runtime",
						gs,
						"_apply_reality_mode_runtime",
						[],
						false
					)
				)

				if not bool(
					worker_report.get(
						"complete",
						false
					)
				):
					return false

				if not bool(
					worker_report.get(
						"success",
						false
					)
				):
					phase_report ["failed"].append({
						"id": "apply_reality_mode_runtime",
						"reason": str(
							worker_report.get(
								"reason",
								"detached_reality_mode_runtime_failed"
							)
						),
						"worker_thread_used": true
					})
				else:
					phase_report ["hydrated"].append({
						"id": "apply_reality_mode_runtime",
						"worker_thread_used": true,
					})
			else:
				gs._apply_reality_mode_runtime()

		3:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "runtime_reconciliation",
					"source": "persisted_hot_checkpoint_truth",
				})
			elif not _reconcile_runtime_state_background_quantum(
				phase_report,
				options
			):
				return false

		4:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "registered_existing_engines",
					"source": "already_hot_engine_graph",
					"rerun": false
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"register_existing_engines_from_game_state"
				)
			):
				gs.game_state_contract_engine.register_existing_engines_from_game_state()

		5:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "active_contract_validation",
					"source": "already_hot_engine_graph",
					"rerun": false
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"validate_active_contracts"
				)
			):
				gs.game_state_contract_engine.validate_active_contracts({
					"phase": "post_contract_hydration",
					"save_version": int(
						data.get(
							"save_version",
							0
						)
					),
					"include_runtime": true
				})

		6:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "missing_engine_recovery",
					"source": "already_hot_engine_graph",
					"rerun": false
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"recover_missing_engines"
				)
			):
				gs.game_state_contract_engine.recover_missing_engines({
					"phase": "post_contract_hydration",
					"save_version": int(
						data.get(
							"save_version",
							0
						)
					)
				})

		7:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "runtime_state_hydration",
					"source": "incremental_checkpoint_state_import",
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"hydrate_runtime_state"
				)
			):
				gs.game_state_contract_engine.hydrate_runtime_state({
					"phase": "post_contract_hydration",
					"save_version": int(
						data.get(
							"save_version",
							0
						)
					)
				})

		8:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "runtime_phase_budget_report",
					"rerun": false
				})
			elif (
				gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"build_runtime_phase_budget_report"
				)
			):
				gs.game_state_contract_engine.build_runtime_phase_budget_report({
					"phase": "post_contract_hydration",
					"save_version": int(
						data.get(
							"save_version",
							0
						)
					)
				})

		9:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "runtime_guards",
					"source": "already_hot_engine_graph",
					"rerun": false
				})
			elif (
				bool(
					options.get(
						"apply_runtime_guards",
						true
					)
				)
				and gs.game_state_contract_engine != null
				and gs.game_state_contract_engine.has_method(
					"apply_runtime_guards"
				)
			):
				gs.game_state_contract_engine.apply_runtime_guards({
					"phase": "post_contract_hydration",
					"save_version": int(
						data.get(
							"save_version",
							0
						)
					)
				})

		10:
			if (
				gs.bank_engine != null
				and gs.bank_engine.has_method(
					"repair_legacy_player_money_mirror"
				)
			):
				gs.bank_engine.repair_legacy_player_money_mirror()
				phase_report [
					"repairs"
				].append(
					"bank_engine.repair_legacy_player_money_mirror"
				)

		11:
			if resident_hot_graph_restore:
				phase_report [
					"hydrated"
				].append({
					"id": "player_lineage",
					"source": "persisted_checkpoint_truth",
				})
			elif gs.has_method(
				"_ensure_loaded_player_lineage"
			):
				gs._ensure_loaded_player_lineage()
				phase_report [
					"repairs"
				].append(
					"_ensure_loaded_player_lineage"
				)

		12:
			if bool(
				options.get(
					"resident_restore",
					false
				)
			):
				phase_report [
					"deferred"
				].append({
					"id": "_soft_unload_npcs",
					"reason": (
						"attached_checkpoint_bulk_maintenance_deferred"
					)
				})

				if typeof(gs.scenario_state) == TYPE_DICTIONARY:
					gs.scenario_state [
						"checkpoint_soft_unload_deferred"
					] = true
			elif gs.has_method(
				"_soft_unload_npcs"
			):
				gs._soft_unload_npcs()
				phase_report [
					"repairs"
				].append(
					"_soft_unload_npcs"
				)

		13:
			phase_report [
				"hydrated"
			].append({
				"id": "runtime_finalization",
				"checkpoint_resume_is_not_birth": resident_hot_graph_restore
			})

		_:
			return true

	cursor += 1
	active_hydration_session [
		"background_finalization_cursor"
	] = cursor

	return cursor >= 14
func _complete_background_hydration() -> void:
	background_hydration_active = false

	var report_raw: Variant = (
		active_hydration_session.get(
			"report",
			{}
		)
	)
	var report: Dictionary = (
		report_raw as Dictionary
		if typeof(
			report_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var failed_raw: Variant = report.get(
		"failed_slices",
		[]
	)
	var failed_slices: Array = (
		failed_raw as Array
		if typeof(
			failed_raw
		) == TYPE_ARRAY
		else []
	)

	report [
		"background_active"
	] = false
	report [
		"background_complete"
	] = true
	report [
		"finished_background_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	report [
		"success"
	] = failed_slices.is_empty()
	report [
		"live_completion_recursive_copy_performed"
	] = false
	report [
		"worker_thread_used"
	] = true
	report [
		"renderer_thread_hydration_performed"
	] = false
	report [
		"ui_interaction_pauses_simulation"
	] = false

	active_hydration_session [
		"state"
	] = "complete"
	active_hydration_session [
		"report"
	] = report.duplicate(false)




	last_hydration_report = (
		report.duplicate(false)
	)

	if gs != null:
		gs.game_state_hydration_report = (
			last_hydration_report.duplicate(false)
		)

		if typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY:
			gs.scenario_state [
				"defer_deserialize_consciousness_repair"
			] = false
			gs.scenario_state [
				"background_hydration_active"
			] = false
			gs.scenario_state [
				"background_hydration_queue_size"
			] = 0
			gs.scenario_state [
				"game_state_hydration_report"
			] = last_hydration_report.duplicate(false)
			gs.scenario_state [
				"last_game_state_hydration_report"
			] = last_hydration_report.duplicate(false)
			gs.scenario_state [
				"checkpoint_hydration_live_completion_recursive_copy_performed"
			] = false
			gs.scenario_state [
				"checkpoint_hydration_completed_off_renderer_thread"
			] = true

		if gs.has_method(
			"complete_save_load_runtime_scheduler"
		):
			var scheduler_report: Dictionary = (
				gs.complete_save_load_runtime_scheduler(
					last_hydration_report
				)
			)

			active_hydration_session [
				"save_load_runtime_scheduler_completion_report"
			] = scheduler_report.duplicate(false)
func _hydrate_entity_graph_playable(data: Dictionary, phase_report: Dictionary, options: Dictionary, session: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	if gs.dynasty_engine != null:
		gs.dynasty_engine.dynasties = data.get("dynasties", {})

	if gs.historical_timeline_engine != null:
		gs.historical_timeline_engine.timeline = data.get("historical_timeline", {})
	if gs.world_chronicle_engine != null:
		gs.world_chronicle_engine.timeline = data.get("world_chronicle", [])

	gs.world_feed = data.get("world_feed", [])
	for i in range(gs.world_feed.size()):
		gs.world_feed [i] = gs.normalize_world_feed_entry(gs.world_feed [i])

	var npc_dicts: Array = _safe_array(data.get("npcs", []))
	var saved_player_id: int = int(data.get("player_id", -1))
	var playable_npc_limit: int = max(1, int(options.get("playable_npc_limit", 24)))
	var defer_consciousness_repair: bool = bool(options.get("defer_consciousness_repair", true))

	var playable_ids: Dictionary = {}
	var player_dict: Dictionary = _merge_find_foreign_dict(npc_dicts, saved_player_id)
	if not player_dict.is_empty():
		_mark_playable_identity_ids(player_dict, playable_ids)

	var imported_count: int = 0
	var pending_npc_dicts: Array = []
	var imported_ids: Dictionary = {}

	gs.npcs.clear()

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["defer_deserialize_consciousness_repair"] = defer_consciousness_repair

	for raw in npc_dicts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = raw
		var npc_id: int = int(d.get("id", -1))
		if npc_id <= 0:
			continue

		var id_key: String = str(npc_id)
		var should_import_now: bool = playable_ids.has(id_key) or imported_count < playable_npc_limit

		if should_import_now:
			var npc = gs._deserialize_npc(d)
			if npc == null:
				continue

			gs.npcs.append(npc)
			imported_ids [id_key] = true
			imported_count += 1
		else:
			pending_npc_dicts.append(d.duplicate(true))

	gs._rebuild_npc_index()

	for raw in npc_dicts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = raw
		var npc_id: int = int(d.get("id", -1))
		if npc_id <= 0:
			continue

		var npc = gs.get_npc_by_id(npc_id)
		if npc == null:
			continue

		var partner_id: int = int(d.get("partner_id", -1))
		if partner_id != -1:
			npc.partner = gs.get_npc_by_id(partner_id)
		else:
			npc.partner = null

		gs.get_valid_partner(npc, true)

	gs.memories = data.get("memories", {})
	if gs.agent_memory_propagation_engine != null:
		gs.agent_memory_propagation_engine.observer_memories = data.get("agent_observer_memories", {})
	gs.compressed_memories = data.get("compressed_memories", {})
	gs.npc_graveyard = data.get("npc_graveyard", {})
	gs.archive_generations = data.get("archive_generations", [])
	gs.dormant_npcs = data.get("dormant_npcs", {})

	if gs.population_shard_engine != null:
		gs.population_shard_engine.population_shards = data.get("population_shards", {})
		gs.population_shard_engine.lineage_ledger = data.get("lineage_ledger", {})

	gs.scenario_state = data.get("scenario_state", {})
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["defer_deserialize_consciousness_repair"] = defer_consciousness_repair

	gs.scenario_history = data.get("scenario_history", [])
	gs.transient_scenario_biases = data.get("transient_scenario_biases", {})
	gs.universal_faction_state = data.get("universal_faction_state", {})

	gs.player = gs.get_npc_by_id(int(data.get("player_id", -1)))
	if gs.player == null and gs.npcs.size() > 0:
		gs.player = gs.npcs [0]
	gs.player_id = gs.player.id if gs.player != null else -1

	var consciousness_repaired_now: int = 0
	if gs.player != null:
		if gs.consciousness_engine != null:
			gs.consciousness_engine.ensure_consciousness(gs.player, {
				"source": "hydrate_entity_graph_playable_player_first"
			})
			consciousness_repaired_now += 1

		if "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("ensure_willpower"):
			gs.willpower_engine.ensure_willpower(gs.player, {
				"source": "hydrate_entity_graph_playable_player_first"
			})

	if not defer_consciousness_repair and gs.consciousness_engine != null:
		for npc in gs.npcs:
			if npc == null or npc == gs.player:
				continue
			gs.consciousness_engine.ensure_consciousness(npc, {
				"source": "hydrate_entity_graph"
			})
			consciousness_repaired_now += 1

	phase_report ["hydrated"].append({
		"id": "entity_graph",
		"npc_count": gs.npcs.size(),
		"player_id": gs.player_id,
		"consciousness_repaired": consciousness_repaired_now,
		"consciousness_repair_deferred": defer_consciousness_repair
	})

	session ["pending_npc_dicts"] = pending_npc_dicts
	session ["pending_npc_cursor"] = 0
	session ["partner_source_dicts"] = npc_dicts
	session ["partner_cursor"] = 0
	session ["pending_consciousness_cursor"] = 0
	session ["imported_ids"] = imported_ids
	session ["defer_consciousness_repair"] = defer_consciousness_repair

	phase_report ["hydrated"].append({
		"id": "entity_graph_playable",
		"npc_count_loaded_now": gs.npcs.size(),
		"npc_count_deferred": pending_npc_dicts.size(),
		"player_id": gs.player_id,
		"playable_npc_limit": playable_npc_limit
	})

func _mark_playable_identity_ids(src: Dictionary, playable_ids: Dictionary) -> void:
	var npc_id: int = int(src.get("id", -1))
	if npc_id > 0:
		playable_ids [str(npc_id)] = true

	for pid in _safe_array(src.get("parents", [])):
		var clean_parent_id: int = int(pid)
		if clean_parent_id > 0:
			playable_ids [str(clean_parent_id)] = true

	for cid in _safe_array(src.get("children", [])):
		var clean_child_id: int = int(cid)
		if clean_child_id > 0:
			playable_ids [str(clean_child_id)] = true

	var partner_id: int = int(src.get("partner_id", -1))
	if partner_id > 0:
		playable_ids [str(partner_id)] = true

func _commit_phase_report(
	report: Dictionary,
	phase_report: Dictionary
) -> void:
	var phase_id: String = str(
		phase_report.get(
			"id",
			""
		)
	).strip_edges()

	if (
		not report.has(
			"phases"
		)
		or typeof(
			report.get(
				"phases",
				{}
			)
		) != TYPE_DICTIONARY
	):
		report [
			"phases"
		] = {}

	if phase_id != "":
		report [
			"phases"
		] [phase_id] = phase_report.duplicate(false)

	var failed_raw: Variant = phase_report.get(
		"failed",
		[]
	)
	if typeof(failed_raw) == TYPE_ARRAY:
		for failed in failed_raw as Array:
			report [
				"failed_slices"
			].append(
				failed
			)

	var warnings_raw: Variant = phase_report.get(
		"warnings",
		[]
	)
	if typeof(warnings_raw) == TYPE_ARRAY:
		for warning in warnings_raw as Array:
			report [
				"warnings"
			].append(
				warning
			)

	var hydrated_raw: Variant = phase_report.get(
		"hydrated",
		[]
	)
	if typeof(hydrated_raw) == TYPE_ARRAY:
		for hydrated in hydrated_raw as Array:
			report [
				"hydrated_slices"
			].append(
				hydrated
			)

	var deferred_raw: Variant = phase_report.get(
		"deferred",
		[]
	)
	if typeof(deferred_raw) == TYPE_ARRAY:
		for deferred in deferred_raw as Array:
			report [
				"deferred_slices"
			].append(
				deferred
			)

	var repairs_raw: Variant = phase_report.get(
		"repairs",
		[]
	)
	if typeof(repairs_raw) == TYPE_ARRAY:
		for repair in repairs_raw as Array:
			report [
				"repairs"
			].append(
				repair
			)
func hydrate_from_payload(raw_data: Variant, options: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())

	if typeof(raw_data) != TYPE_DICTIONARY:
		return _fail_report("corrupted_save", "❌ Save corrupted.", {
			"typeof": typeof(raw_data)
		})

	var data: Dictionary = (raw_data as Dictionary).duplicate(true)
	if data.is_empty():
		return _fail_report("empty_save", "❌ Save corrupted.", {})

	_ensure_runtime_dependencies()

	data = _apply_pre_hydration_migrations(data, options)
	if not _passes_minimum_payload_shape(data, options):
		return _fail_report("missing_required_fields", "Save missing required fields.", {
			"required": ["year", "next_id", "npcs"],
			"has_year": data.has("year"),
			"has_next_id": data.has("next_id"),
			"has_npcs": data.has("npcs")
		})

	var report: Dictionary = {
		"schema": "eralife.game_state_hydration_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"source": str(options.get("source", "hydrate_from_payload")),
		"profile": str(options.get("profile", "full_simulation")),
		"path": str(options.get("path", "")),
		"format": str(options.get("format", "dictionary")),
		"phases": {},
		"hydrated_slices": [],
		"deferred_slices": [],
		"unknown_slices": [],
		"failed_slices": [],
		"repairs": [],
		"warnings": [],
		"started_at_ms": started_at,
		"finished_at_ms": 0,
		"duration_ms": 0
	}

	preserved_unknown_slices = _collect_unknown_slices(data)
	_store_preserved_unknown_slices(preserved_unknown_slices, report)

	for phase_id in PHASE_ORDER:
		var phase_report: Dictionary = _begin_phase_report(phase_id)
		match phase_id:
			PHASE_CORE_IDENTITY:
				_hydrate_core_identity(data, phase_report, options)
			PHASE_STRUCTURAL_SYSTEMS:
				_hydrate_structural_systems(data, phase_report, options)
				_hydrate_contract_slices_for_phase(phase_id, data, phase_report, options)
			PHASE_ENTITY_GRAPH:
				_hydrate_entity_graph(data, phase_report, options)
			PHASE_SYSTEM_STATE:
				_hydrate_contract_slices_for_phase(phase_id, data, phase_report, options)
			PHASE_DERIVED_SYSTEMS:
				_hydrate_contract_slices_for_phase(phase_id, data, phase_report, options)
				_hydrate_derived_systems(data, phase_report, options)
			PHASE_FINALIZATION:
				_finalize_hydration(data, phase_report, options)
		phase_report ["finished_at_ms"] = int(Time.get_ticks_msec())
		phase_report ["duration_ms"] = int(phase_report ["finished_at_ms"]) - int(phase_report ["started_at_ms"])
		report ["phases"] [phase_id] = phase_report

		for failed in phase_report.get("failed", []):
			report ["failed_slices"].append(failed)
		for warning in phase_report.get("warnings", []):
			report ["warnings"].append(warning)
		for hydrated in phase_report.get("hydrated", []):
			report ["hydrated_slices"].append(hydrated)
		for deferred in phase_report.get("deferred", []):
			report ["deferred_slices"].append(deferred)
		for repair in phase_report.get("repairs", []):
			report ["repairs"].append(repair)

	report ["success"] = report ["failed_slices"].is_empty()
	report ["finished_at_ms"] = int(Time.get_ticks_msec())
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at

	last_hydration_report = _make_binary_safe(report)
	if gs != null:
		gs.game_state_hydration_report = last_hydration_report.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["game_state_hydration_report"] = last_hydration_report.duplicate(true)

	return last_hydration_report.duplicate(true)
func hydrate_live_slice_frame(raw_frame: Variant, options: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())

	if typeof(raw_frame) != TYPE_DICTIONARY:
		return _fail_report("corrupted_live_slice_frame", "Live slice frame corrupted.", {
			"typeof": typeof(raw_frame)
		})

	var frame: Dictionary = (raw_frame as Dictionary).duplicate(true)
	if frame.is_empty():
		return _fail_report("empty_live_slice_frame", "Live slice frame was empty.", {})

	_ensure_runtime_dependencies()

	var report: Dictionary = {
		"schema": "eralife.live_slice_hydration_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"source": str(options.get("source", "hydrate_live_slice_frame")),
		"profile": str(options.get("profile", "partial_live_hydration")),
		"source_year": int(frame.get("source_year", 0)),
		"target_year": int(frame.get("target_year", options.get("target_year", 0))),
		"player_id": int(frame.get("player_id", options.get("player_id", -1))),
		"hydrated": [],
		"deferred": [],
		"warnings": [],
		"failed": [],
		"started_at_ms": started_at,
		"finished_at_ms": 0,
		"duration_ms": 0
	}

	_apply_live_core_identity(frame, report, options)
	_apply_live_entity_graph_delta(frame, report, options)
	_apply_live_dirty_contract_slices(frame, report, options)
	_finalize_live_partial_hydration(frame, report, options)

	report ["success"] = report ["failed"].is_empty()
	report ["finished_at_ms"] = int(Time.get_ticks_msec())
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at

	last_hydration_report = _make_binary_safe(report)

	if gs != null:
		gs.game_state_hydration_report = last_hydration_report.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["last_live_slice_hydration_report"] = last_hydration_report.duplicate(true)
			gs.scenario_state ["game_state_hydration_report"] = last_hydration_report.duplicate(true)

	return last_hydration_report.duplicate(true)


func _apply_live_core_identity(frame: Dictionary, report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		report ["failed"].append({ "reason": "GameState unavailable."})
		return

	var delta_raw: Variant = frame.get("core_identity_delta", {})
	var delta: Dictionary = delta_raw if typeof(delta_raw) == TYPE_DICTIONARY else {}

	if delta.is_empty():
		report ["deferred"].append({
			"id": "core_identity_delta",
			"reason": "missing_delta"
		})
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var time_contract_raw: Variant = gs.scenario_state.get("age_up_time_contract", {})
	var time_contract: Dictionary = time_contract_raw if typeof(time_contract_raw) == TYPE_DICTIONARY else {}

	var target_year: int = int(delta.get("year_after", frame.get("target_year", int(gs.year) + 1)))
	var player_id: int = int(delta.get("player_id", frame.get("player_id", int(gs.player_id))))
	var may_advance_year: bool = bool(delta.get("advance_year", true))
	var may_advance_player_age: bool = bool(delta.get("advance_player_age", true))

	if not time_contract.is_empty():
		var temporal_policy: Dictionary = _safe_dictionary(time_contract.get("temporal_slice_policy", {}))
		if not bool(temporal_policy.get("may_advance_core_year", true)):
			may_advance_year = false
		if not bool(temporal_policy.get("may_advance_player_age", true)):
			may_advance_player_age = false

	if may_advance_year and not gs.year_locked:
		gs.year = target_year

	if gs.era_engine != null and gs.era_engine.has_method("_era_from_year"):
		gs.era = gs.era_engine._era_from_year(gs.year)

	var player = gs.get_npc_by_id(player_id) if gs.has_method("get_npc_by_id") else gs.player
	if player != null and may_advance_player_age:
		var desired_age: int = int(delta.get("player_age_after", int(player.age) + 1))
		player.age = desired_age
		if player.has_method("set_meta"):
			player.set_meta("last_temporal_biology_year", target_year)

		gs.player = player
		gs.player_id = int(player.id)

	report ["hydrated"].append({
		"id": "core_identity_delta",
		"year": int(gs.year),
		"player_id": int(gs.player_id),
		"player_age": int(gs.player.age) if gs.player != null else -1,
		"advance_year": may_advance_year,
		"advance_player_age": may_advance_player_age,
		"time_authority": str(delta.get("time_authority", time_contract.get("time_authority", "")))
	})

func _apply_live_entity_graph_delta(frame: Dictionary, report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		report ["failed"].append({ "reason": "GameState unavailable."})
		return

	var delta_raw: Variant = frame.get("entity_graph_delta", {})
	var delta: Dictionary = delta_raw if typeof(delta_raw) == TYPE_DICTIONARY else {}

	if delta.is_empty():
		report ["deferred"].append({
			"id": "entity_graph_delta",
			"reason": "missing_delta"
		})
		return

	var rows: Array = _safe_array(delta.get("rows", []))
	var target_year: int = int(delta.get("target_year", frame.get("target_year", gs.year)))
	var applied: int = 0
	var missing: int = 0

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var npc_id: int = int(row.get("id", -1))
		if npc_id <= 0:
			continue

		var npc = gs.get_or_reactivate_npc_by_id(npc_id) if gs.has_method("get_or_reactivate_npc_by_id") else gs.get_npc_by_id(npc_id)
		if npc == null:
			missing += 1
			continue

		_apply_live_person_row(npc, row, target_year)
		applied += 1

	if applied > 0 and gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()

	report ["hydrated"].append({
		"id": "entity_graph_delta",
		"applied": applied,
		"missing": missing,
		"target_year": target_year,
		"partial": bool(delta.get("partial", true))
	})


func _apply_live_person_row(npc, row: Dictionary, target_year: int) -> void:
	var scalar_keys: Array = [
		"age",
		"alive",
		"health",
		"happiness",
		"smarts",
		"looks",
		"fame",
		"money",
		"job",
		"career",
		"social_class",
		"locality_id",
		"district_id"
	]

	for key in scalar_keys:
		if row.has(key) and key in npc:
			npc.set(key, row.get(key))

	var array_keys: Array = [
		"parents",
		"children",
		"friends",
		"ex_partners",
		"schoolmates"
	]

	for key in array_keys:
		if row.has(key) and key in npc and typeof(row.get(key)) == TYPE_ARRAY:
			npc.set(key, row.get(key).duplicate(true))

	if npc.has_method("set_meta"):
		npc.set_meta("last_temporal_biology_year", target_year)
		npc.set_meta("last_temporal_slice_streamed_at_ms", int(Time.get_ticks_msec()))


func _apply_live_dirty_contract_slices(frame: Dictionary, report: Dictionary, options: Dictionary) -> void:
	var slices: Dictionary = _safe_dictionary(frame.get("slices", {}))
	if slices.is_empty():
		return

	var contracts: Array = _resolve_save_slice_contracts()
	var hydrated_count: int = 0

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var slice_contract: Dictionary = raw_contract
		var save_key: String = str(slice_contract.get("save_key", slice_contract.get("id", ""))).strip_edges()
		if save_key == "":
			continue

		if not slices.has(save_key):
			continue

		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw
		if not bool(row.get("dirty", false)) and not bool(options.get("hydrate_clean_slices", false)):
			continue

		var data: Variant = row.get("data", {})
		var phase_report: Dictionary = _begin_phase_report(_phase_for_slice(slice_contract))
		_hydrate_engine_slice(slice_contract, data, phase_report, options)

		if not phase_report.get("failed", []).is_empty():
			report ["failed"].append({
				"save_key": save_key,
				"phase_report": phase_report.duplicate(true)
			})
		else:
			hydrated_count += 1

	report ["hydrated"].append({
		"id": "dirty_contract_slices",
		"count": hydrated_count
	})


func _finalize_live_partial_hydration(frame: Dictionary, report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var target_year: int = int(frame.get("target_year", gs.year))

	gs.scenario_state ["last_live_slice_target_year"] = target_year
	gs.scenario_state ["temporal_slice_streaming_active"] = false

	if gs.world_engine != null and gs.world_engine.has_method("_claim_world_year_tick"):
		var entity_delta_raw: Variant = frame.get("entity_graph_delta", {})
		if typeof(entity_delta_raw) == TYPE_DICTIONARY:
			var entity_delta: Dictionary = entity_delta_raw
			if bool(entity_delta.get("partial", true)):
				gs.scenario_state ["temporal_partial_biology_year"] = target_year

	if gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()

	report ["hydrated"].append({
		"id": "live_partial_finalization",
		"year": int(gs.year),
		"player_id": int(gs.player_id),
		"player_age": int(gs.player.age) if gs.player != null else -1
	})
func merge_character_from_path(path: String, merge_contract: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())
	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		return _merge_fail("missing_path", "❌ Merge file missing.", started_at, {})
	if not FileAccess.file_exists(normalized_path):
		return _merge_fail("missing_file", "❌ Merge file missing.", started_at, {
			"path": normalized_path
		})
	var decoded: Dictionary = _decode_payload_from_path(normalized_path)
	if not bool(decoded.get("success", false)):
		return _merge_fail("decode_failed", str(decoded.get("reason", "❌ Merge file corrupted.")), started_at, {
			"path": normalized_path
		})
	var data: Dictionary = decoded.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return _merge_fail("corrupted_payload", "❌ Merge file corrupted.", started_at, {
			"path": normalized_path
		})

	var policy: Dictionary = _resolve_merge_policy(merge_contract)
	var foreign_npcs: Array = _safe_array(data.get("npcs", []))
	var foreign_player_id: int = int(data.get("player_id", -1))
	var root_person_id: int = int(policy.get("root_person_id", foreign_player_id))
	if root_person_id <= 0:
		root_person_id = foreign_player_id

	var foreign_player_dict: Dictionary = _merge_find_foreign_dict(foreign_npcs, foreign_player_id)
	if foreign_player_dict.is_empty():
		return _merge_fail("foreign_player_missing", "❌ No foreign player.", started_at, {
			"path": normalized_path,
			"foreign_player_id": foreign_player_id
		})

	var root_person_dict: Dictionary = _merge_find_foreign_dict(foreign_npcs, root_person_id)
	if root_person_dict.is_empty():
		return _merge_fail("foreign_root_person_missing", "❌ Selected person was not found in that universe.", started_at, {
			"path": normalized_path,
			"foreign_player_id": foreign_player_id,
			"root_person_id": root_person_id
		})

	if gs == null:
		return _merge_fail("game_state_missing", "❌ GameState unavailable for merge.", started_at, {})

	var id_map: Dictionary = {}
	var imported_cache: Dictionary = {}
	var queue: Array = [root_person_id]
	var visited: Dictionary = {}
	while queue.size() > 0:
		var old_id: int = int(queue.pop_front())
		if visited.has(old_id):
			continue
		visited [old_id] = true
		_import_foreign_person(old_id, foreign_npcs, id_map, imported_cache)
		var src: Dictionary = _merge_find_foreign_dict(foreign_npcs, old_id)
		if src.is_empty():
			continue
		for linked_id in _merge_linked_ids_from_policy(src, policy, foreign_npcs):
			var clean_linked_id: int = int(linked_id)
			if clean_linked_id > 0 and not visited.has(clean_linked_id):
				queue.append(clean_linked_id)

	_reconcile_imported_family_links(imported_cache, id_map, policy)
	_integrate_imported_people(imported_cache, policy)
	var imported_player = imported_cache.get(root_person_id, null)
	_apply_merge_friend_policy(imported_player, policy)

	var report: Dictionary = {
		"schema": "eralife.reality_merge_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": true,
		"path": normalized_path,
		"format": decoded.get("format", "unknown"),
		"merge_policy": policy.duplicate(true),
		"foreign_player_id": foreign_player_id,
		"foreign_root_person_id": root_person_id,
		"foreign_root_person_name": _merge_person_name_from_dict(root_person_dict),
		"imported_player": imported_player,
		"imported_count": imported_cache.size(),
		"id_map": id_map.duplicate(true),
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at
	last_merge_report = report.duplicate(true)
	return report

func _decode_payload_from_path(path: String) -> Dictionary:
	var lower_path: String = str(path).to_lower()
	if lower_path.ends_with(".bin"):
		var f_bin = FileAccess.open(path, FileAccess.READ)
		if f_bin == null:
			return _fail_report("open_failed", "❌ Failed to open save file.", {
				"path": path
			})
		var bytes: PackedByteArray = f_bin.get_buffer(f_bin.get_length())
		f_bin.close()
		var decoded: Variant = BinarySaveEngine.decode(bytes)
		if typeof(decoded) != TYPE_DICTIONARY:
			return _fail_report("binary_decode_failed", "❌ Save corrupted.", {
				"path": path
			})
		return {
			"success": true,
			"format": "binary",
			"data": decoded
		}

	var f_json = FileAccess.open(path, FileAccess.READ)
	if f_json == null:
		return _fail_report("open_failed", "❌ Failed to open save file.", {
			"path": path
		})
	var parsed: Variant = JSON.parse_string(f_json.get_as_text())
	f_json.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail_report("json_decode_failed", "❌ Save corrupted.", {
			"path": path
		})
	return {
		"success": true,
		"format": "json",
		"data": parsed
	}

func _ensure_runtime_dependencies() -> void:
	if gs == null:
		return





	var resident_engine_graph_hot: bool = (
		bool(
			gs.resident_runtime_bootstrap_complete
		)
		and not bool(
			gs.resident_runtime_bootstrap_failed
		)
	)

	if (
		not resident_engine_graph_hot
		and gs.has_method(
			"_ensure_load_game_runtime_dependencies"
		)
	):
		gs._ensure_load_game_runtime_dependencies()

	if gs.game_state_contract_engine == null:
		gs.game_state_contract_engine = (
			GameStateContractEngine.new(
				gs
			)
		)

	if gs.game_state_hydration_runtime == null:
		gs.game_state_hydration_runtime = (
			GameStateHydrationRuntime.new(
				gs
			)
		)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"hydration_runtime_resident_engine_graph_hot"
		] = resident_engine_graph_hot
		gs.scenario_state [
			"hydration_runtime_full_dependency_reconciliation_performed"
		] = not resident_engine_graph_hot
		gs.scenario_state [
			"hydration_runtime_redundant_resident_bootstrap_forbidden"
		] = true

func _apply_pre_hydration_migrations(data: Dictionary, options: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out = _normalize_eralife_save_payload(out)

	if gs == null:
		return out
	if gs.mod_loader == null:
		gs.mod_loader = ModLoader.new(gs)
	if gs.mod_loader != null and gs.mod_loader.has_method("import_registry"):
		gs.mod_loader.import_registry(out.get("mod_contract_registry", {}))
	if gs.mod_loader != null and gs.mod_loader.has_method("apply_save_migrations"):
		var migrated: Variant = gs.mod_loader.apply_save_migrations(out)
		if typeof(migrated) == TYPE_DICTIONARY:
			out = _normalize_eralife_save_payload(migrated as Dictionary)
	if gs.mod_loader != null:
		if gs.mod_loader.has_method("import_registry"):
			gs.mod_loader.import_registry(out.get("mod_contract_registry", {}))
		if gs.mod_loader.has_method("hot_apply_mod_contracts"):
			var mod_apply_report: Dictionary = gs.mod_loader.hot_apply_mod_contracts({
				"source": "game_state_hydration_runtime",
				"force": true,
				"profile": str(options.get("profile", "full_simulation"))
			})
			gs.mod_contract_runtime_report = mod_apply_report.duplicate(true)
			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["mod_contract_hydration_apply_report"] = mod_apply_report.duplicate(true)
		if gs.mod_loader.has_method("export_registry"):
			gs.mod_contract_registry = gs.mod_loader.export_registry()
	return out
func _normalize_eralife_save_payload(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var schema: String = str(out.get("schema", "")).strip_edges()

	if schema != "eralife.save":
		return out

	var slices_raw: Variant = out.get("slices", {})
	if typeof(slices_raw) == TYPE_DICTIONARY:
		var slices: Dictionary = slices_raw
		for save_key in slices.keys():
			var row_raw: Variant = slices.get(save_key, {})
			if typeof(row_raw) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = row_raw
			var clean_save_key: String = str(row.get("save_key", save_key)).strip_edges()
			if clean_save_key == "":
				continue

			if not out.has(clean_save_key):
				out [clean_save_key] = _make_binary_safe(row.get("data", {}))

		if not out.has("game_state_contract_slices"):
			out ["game_state_contract_slices"] = {
				"schema": "eralife.game_state_contract_save_slices",
				"version": int(out.get("serialization_runtime_version", 1)),
				"state_id": str(out.get("state_id", "")),
				"save_contract": out.get("save_contract", {}),
				"slices": slices.duplicate(true),
				"orphaned_slices": out.get("preserved_unknown_save_slices", {}),
				"imported_from_schema": schema
			}

	return out

func _passes_minimum_payload_shape(data: Dictionary, options: Dictionary) -> bool:
	if bool(options.get("allow_partial_payload", false)):
		return data.has("year") or data.has("npcs") or data.has("game_state_contract_slices")
	return data.has("year") and data.has("next_id") and data.has("npcs")

func _hydrate_core_identity(data: Dictionary, phase_report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	gs.year = int(data.get("year", 2000))
	gs.next_id = int(data.get("next_id", 1))
	gs.era = gs._resolve_loaded_era_from_save_data(data, gs.year)
	gs.save_version = int(data.get("save_version", gs.save_version))
	gs.game_state_contract_registry = data.get("game_state_contract_registry", {})
	gs.game_state_contract_slices = data.get("game_state_contract_slices", {})
	gs.game_state_runtime_guard = data.get("game_state_runtime_guard", {})

	var seed_contract: Dictionary = _safe_dictionary(data.get("seed_contract", data.get("seed_engine_state", {})))
	var loaded_world_seed: int = int(data.get("world_seed", seed_contract.get("seed", -1)))

	if gs.seed_engine == null:
		gs.seed_engine = SeedEngine.new(gs)

	if not seed_contract.is_empty():
		if gs.seed_engine.has_method("import_state"):
			gs.seed_engine.import_state(seed_contract)
		else:
			gs.seed_engine.initialize(int(seed_contract.get("seed", loaded_world_seed)))
	elif loaded_world_seed != -1:
		gs.seed_engine.initialize(loaded_world_seed)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs.seed_engine != null:
		if gs.seed_engine.has_method("export_state"):
			gs.scenario_state ["seed_contract"] = gs.seed_engine.export_state()
		if "seed_value" in gs.seed_engine:
			gs.scenario_state ["world_seed"] = int(gs.seed_engine.seed_value)

	phase_report ["hydrated"].append({
		"id": "core_identity",
		"year": gs.year,
		"next_id": gs.next_id,
		"save_version": gs.save_version,
		"world_seed": loaded_world_seed,
		"seed_contract_loaded": not seed_contract.is_empty()
	})
func _hydrate_structural_systems(data: Dictionary, phase_report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	if gs.realm_engine != null and gs.realm_engine.has_method("bootstrap_realms_for_era"):
		gs.realm_engine.bootstrap_realms_for_era()
		phase_report ["hydrated"].append({ "id": "realm_bootstrap"})

	var loaded_realm_map: Dictionary = gs._normalize_loaded_realm_map(data.get("realm_realms", {}))
	if not loaded_realm_map.is_empty() and gs.realm_engine != null:
		gs.realm_engine.realms = loaded_realm_map
		phase_report ["hydrated"].append({
			"id": "realm_realms",
			"count": loaded_realm_map.size()
		})

	_import_registry_if_available("game_state_contract_engine", "game_state_contract_registry", "import_registry", data, phase_report)
	_import_registry_if_available("realm_contract_engine", "realm_contract_registry", "import_registry", data, phase_report)
	_import_registry_if_available("simulation_contract_engine", "simulation_contract_registry", "import_registry", data, phase_report)
	_import_registry_if_available("ui_contract_engine", "ui_contract_registry", "import_registry", data, phase_report)
	_import_registry_if_available("world_engine", "world_engine_contract_registry", "import_registry", data, phase_report)
	_import_registry_if_available("life_engine", "life_engine_contract_registry", "import_registry", data, phase_report)

	if gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("repair_runtime_realm_maps"):
		gs.realm_contract_engine.repair_runtime_realm_maps()
		phase_report ["repairs"].append("realm_contract_engine.repair_runtime_realm_maps")

	if gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("load_external_packs"):
		gs.simulation_contract_engine.load_external_packs()
		phase_report ["hydrated"].append({ "id": "simulation_external_packs"})

	if gs.game_state_contract_engine != null:
		if gs.game_state_contract_engine.has_method("import_save_slices"):
			gs.game_state_contract_engine.import_save_slices(data.get("game_state_contract_slices", {}))
			phase_report ["hydrated"].append({ "id": "game_state_contract_slices"})
		if gs.game_state_contract_engine.has_method("register_existing_engines_from_game_state"):
			gs.game_state_contract_engine.register_existing_engines_from_game_state()
			phase_report ["hydrated"].append({ "id": "registered_existing_engines"})

func _hydrate_entity_graph(data: Dictionary, phase_report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	if gs.dynasty_engine != null:
		gs.dynasty_engine.dynasties = data.get("dynasties", {})
	if gs.historical_timeline_engine != null:
		gs.historical_timeline_engine.timeline = data.get("historical_timeline", {})
	if gs.world_chronicle_engine != null:
		gs.world_chronicle_engine.timeline = data.get("world_chronicle", [])

	gs.world_feed = data.get("world_feed", [])
	for i in range(gs.world_feed.size()):
		gs.world_feed [i] = gs.normalize_world_feed_entry(gs.world_feed [i])

	gs.npcs.clear()
	var npc_dicts: Array = _safe_array(data.get("npcs", []))
	for d in npc_dicts:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		gs.npcs.append(gs._deserialize_npc(d))

	gs._rebuild_npc_index()

	for i in range(npc_dicts.size()):
		var d = npc_dicts [i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if i >= gs.npcs.size():
			continue
		var npc = gs.npcs [i]
		var partner_id:= int(d.get("partner_id", -1))
		if partner_id != -1:
			npc.partner = gs.get_npc_by_id(partner_id)
		else:
			npc.partner = null

	for npc in gs.npcs:
		gs.get_valid_partner(npc, true)

	gs.memories = data.get("memories", {})
	if gs.agent_memory_propagation_engine != null:
		gs.agent_memory_propagation_engine.observer_memories = data.get("agent_observer_memories", {})
	gs.compressed_memories = data.get("compressed_memories", {})
	gs.npc_graveyard = data.get("npc_graveyard", {})
	gs.archive_generations = data.get("archive_generations", [])
	gs.dormant_npcs = data.get("dormant_npcs", {})

	if gs.population_shard_engine != null:
		gs.population_shard_engine.population_shards = data.get("population_shards", {})
		gs.population_shard_engine.lineage_ledger = data.get("lineage_ledger", {})

	gs.scenario_state = data.get("scenario_state", {})
	gs.scenario_history = data.get("scenario_history", [])
	gs.transient_scenario_biases = data.get("transient_scenario_biases", {})
	gs.universal_faction_state = data.get("universal_faction_state", {})

	gs.player = gs.get_npc_by_id(int(data.get("player_id", -1)))
	if gs.player == null and gs.npcs.size() > 0:
		gs.player = gs.npcs [0]
	gs.player_id = gs.player.id if gs.player != null else -1

	if gs.consciousness_engine != null:
		for npc in gs.npcs:
			if npc == null:
				continue
			gs.consciousness_engine.ensure_consciousness(npc, {
				"source": "hydrate_entity_graph"
			})

	phase_report ["hydrated"].append({
		"id": "entity_graph",
		"npc_count": gs.npcs.size(),
		"player_id": gs.player_id,
		"consciousness_repaired": gs.consciousness_engine != null
	})

func _hydrate_contract_slices_for_phase(phase_id: String, data: Dictionary, phase_report: Dictionary, options: Dictionary) -> void:
	var contracts: Array = _resolve_save_slice_contracts()
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue
		var slice_contract: Dictionary = raw_contract
		var save_key: String = str(slice_contract.get("save_key", slice_contract.get("id", ""))).strip_edges()
		if save_key == "":
			continue
		if _phase_for_slice(slice_contract) != phase_id:
			continue
		if not data.has(save_key):
			continue
		_hydrate_engine_slice(slice_contract, data.get(save_key), phase_report, options)

func _hydrate_engine_slice(
	slice_contract: Dictionary,
	payload: Variant,
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	var save_key: String = str(
		slice_contract.get(
			"save_key",
			slice_contract.get(
				"id",
				""
			)
		)
	).strip_edges()
	var engine_id: String = str(
		slice_contract.get(
			"engine_id",
			""
		)
	).strip_edges()
	var import_method: String = str(
		slice_contract.get(
			"import_method",
			"import_state"
		)
	).strip_edges()
	var required: bool = bool(
		slice_contract.get(
			"required",
			false
		)
	)

	if save_key == "":
		return true

	if not _slice_allowed_for_profile(
		slice_contract,
		options
	):
		phase_report ["deferred"].append({
			"save_key": save_key,
			"engine_id": engine_id,
			"reason": "deferred_by_loading_profile"
		})
		preserved_unknown_slices [save_key] = {
			"save_key": save_key,
			"engine_id": engine_id,
			"data": _make_binary_safe(
				payload
			),
			"deferred": true
		}
		return true

	var target = _resolve_engine(
		engine_id
	)

	if target == null:
		var missing_engine_report: Dictionary = {
			"save_key": save_key,
			"engine_id": engine_id,
			"reason": "engine_unavailable",
			"required": required
		}
		preserved_unknown_slices [save_key] = {
			"save_key": save_key,
			"engine_id": engine_id,
			"data": _make_binary_safe(
				payload
			),
			"orphaned": true,
			"required": required
		}

		if required:
			phase_report ["failed"].append(
				missing_engine_report
			)
		else:
			phase_report ["warnings"].append(
				missing_engine_report
			)

		return true

	if (
		import_method == ""
		or not target.has_method(
			import_method
		)
	):
		var missing_method_report: Dictionary = {
			"save_key": save_key,
			"engine_id": engine_id,
			"import_method": import_method,
			"reason": "import_method_unavailable",
			"required": required
		}
		preserved_unknown_slices [save_key] = {
			"save_key": save_key,
			"engine_id": engine_id,
			"data": _make_binary_safe(
				payload
			),
			"orphaned": true,
			"required": required
		}

		if required:
			phase_report ["failed"].append(
				missing_method_report
			)
		else:
			phase_report ["warnings"].append(
				missing_method_report
			)

		return true

	var detached_resident_import: bool = (
		background_hydration_active
		and bool(
			options.get(
				"resident_restore",
				false
			)
		)
		and bool(
			options.get(
				"resident_engine_graph_ready",
				false
			)
		)
		and not bool(
			options.get(
				"runtime_scene_tree_access_allowed",
				true
			)
		)
	)

	if detached_resident_import:
		var task_id: String = (
			"hydrate_engine_slice:%s:%s"
			% [
				engine_id,
				save_key
			]
		)
		var worker_report: Dictionary = (
			_service_background_authority_call(
				task_id,
				target,
				import_method,
				[
					payload
				],
				true
			)
		)

		if not bool(
			worker_report.get(
				"complete",
				false
			)
		):
			active_hydration_session [
				"background_engine_import_worker_active"
			] = true
			active_hydration_session [
				"background_engine_import_worker_save_key"
			] = save_key
			active_hydration_session [
				"background_engine_import_worker_engine_id"
			] = engine_id
			return false

		active_hydration_session [
			"background_engine_import_worker_active"
		] = false
		active_hydration_session.erase(
			"background_engine_import_worker_save_key"
		)
		active_hydration_session.erase(
			"background_engine_import_worker_engine_id"
		)
		active_hydration_session [
			"background_engine_import_worker_used"
		] = true

		if not bool(
			worker_report.get(
				"success",
				false
			)
		):
			var worker_failure: Dictionary = {
				"save_key": save_key,
				"engine_id": engine_id,
				"import_method": import_method,
				"reason": str(
					worker_report.get(
						"reason",
						"background_engine_import_failed"
					)
				),
				"required": required,
				"worker_thread_used": true
			}

			preserved_unknown_slices [save_key] = {
				"save_key": save_key,
				"engine_id": engine_id,
				"data": _make_binary_safe(
					payload
				),
				"orphaned": true,
				"required": required,
			}

			if required:
				phase_report ["failed"].append(
					worker_failure
				)
			else:
				phase_report ["warnings"].append(
					worker_failure
				)

			return true

		if bool(
			worker_report.get(
				"validation_performed",
				false
			)
		):
			phase_report ["validations"].append({
				"save_key": save_key,
				"engine_id": engine_id,
				"validation": _make_binary_safe(
					worker_report.get(
						"validation",
						null
					)
				),
				"worker_thread_used": true
			})

		phase_report ["hydrated"].append({
			"save_key": save_key,
			"engine_id": engine_id,
			"import_method": import_method,
			"worker_thread_used": true,
		})

		return true


	target.callv(
		import_method,
		[
			payload
		]
	)

	if target.has_method(
		"validate_state"
	):
		var validation: Variant = target.call(
			"validate_state"
		)
		phase_report ["validations"].append({
			"save_key": save_key,
			"engine_id": engine_id,
			"validation": _make_binary_safe(
				validation
			)
		})

	phase_report ["hydrated"].append({
		"save_key": save_key,
		"engine_id": engine_id,
		"import_method": import_method
	})

	return true
func _import_registry_background_quantum(
	engine_property: String,
	data_key: String,
	import_method: String,
	data: Dictionary,
	phase_report: Dictionary,
	options: Dictionary
) -> bool:
	if not data.has(
		data_key
	):
		return true

	var target = _resolve_engine(
		engine_property
	)

	if target == null:
		phase_report ["warnings"].append({
			"data_key": data_key,
			"engine_property": engine_property,
			"reason": "registry_engine_unavailable"
		})
		return true

	if not target.has_method(
		import_method
	):
		phase_report ["warnings"].append({
			"data_key": data_key,
			"engine_property": engine_property,
			"import_method": import_method,
			"reason": "registry_import_method_unavailable"
		})
		return true

	var detached_resident_import: bool = (
		bool(
			options.get(
				"resident_restore",
				false
			)
		)
		and bool(
			options.get(
				"resident_engine_graph_ready",
				false
			)
		)
		and not bool(
			options.get(
				"runtime_scene_tree_access_allowed",
				true
			)
		)
	)

	if not detached_resident_import:
		_import_registry_if_available(
			engine_property,
			data_key,
			import_method,
			data,
			phase_report
		)
		return true

	var worker_report: Dictionary = (
		_service_background_authority_call(
			"registry:%s:%s"
			% [
				engine_property,
				data_key
			],
			target,
			import_method,
			[
				data.get(
					data_key,
					{}
				)
			],
			false
		)
	)

	if not bool(
		worker_report.get(
			"complete",
			false
		)
	):
		return false

	if not bool(
		worker_report.get(
			"success",
			false
		)
	):
		phase_report ["warnings"].append({
			"data_key": data_key,
			"engine_property": engine_property,
			"import_method": import_method,
			"reason": str(
				worker_report.get(
					"reason",
					"registry_background_import_failed"
				)
			),
			"worker_thread_used": true
		})
		return true

	phase_report ["hydrated"].append({
		"id": data_key,
		"engine_property": engine_property,
		"import_method": import_method,
		"worker_thread_used": true,
	})

	return true

func _hydrate_derived_systems(data: Dictionary, phase_report: Dictionary, _options: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	var loaded_warm_snapshot_raw: Variant = data.get(
		"warm_world_runtime_snapshot",
		gs.scenario_state.get("warm_world_runtime_snapshot", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	)
	var loaded_warm_snapshot: Dictionary = loaded_warm_snapshot_raw if typeof(loaded_warm_snapshot_raw) == TYPE_DICTIONARY else {}
	if not loaded_warm_snapshot.is_empty():
		gs._restore_warm_runtime_snapshot(loaded_warm_snapshot)
		phase_report ["hydrated"].append({ "id": "warm_world_runtime_snapshot"})

func _finalize_hydration(data: Dictionary, phase_report: Dictionary, options: Dictionary) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable."})
		return

	gs.custom_mode = bool(data.get("custom_mode", false))
	gs.custom_settings = data.get("custom_settings", {})
	gs.reality_mode = str(data.get("reality_mode", gs.custom_settings.get("reality_mode", gs.REALITY_CHAOS))).to_lower()
	gs.reality_feature_overrides = data.get("feature_overrides", gs.custom_settings.get("feature_overrides", {})).duplicate()

	gs._hydrate_reality_settings()
	gs._apply_reality_mode_runtime()

	_reconcile_runtime_state(phase_report, options)

	if gs.game_state_contract_engine != null:
		if gs.game_state_contract_engine.has_method("register_existing_engines_from_game_state"):
			gs.game_state_contract_engine.register_existing_engines_from_game_state()

		if gs.game_state_contract_engine.has_method("validate_active_contracts"):
			gs.game_state_contract_engine.validate_active_contracts({
				"phase": "post_contract_hydration",
				"save_version": int(data.get("save_version", 0)),
				"include_runtime": true
			})

		if gs.game_state_contract_engine.has_method("recover_missing_engines"):
			gs.game_state_contract_engine.recover_missing_engines({
				"phase": "post_contract_hydration",
				"save_version": int(data.get("save_version", 0))
			})

		if gs.game_state_contract_engine.has_method("hydrate_runtime_state"):
			gs.game_state_contract_engine.hydrate_runtime_state({
				"phase": "post_contract_hydration",
				"save_version": int(data.get("save_version", 0))
			})

		if gs.game_state_contract_engine.has_method("build_runtime_phase_budget_report"):
			gs.game_state_contract_engine.build_runtime_phase_budget_report({
				"phase": "post_contract_hydration",
				"save_version": int(data.get("save_version", 0))
			})

		if bool(options.get("apply_runtime_guards", true)) and gs.game_state_contract_engine.has_method("apply_runtime_guards"):
			gs.game_state_contract_engine.apply_runtime_guards({
				"phase": "post_contract_hydration",
				"save_version": int(data.get("save_version", 0))
			})

	if gs.bank_engine != null and gs.bank_engine.has_method("repair_legacy_player_money_mirror"):
		gs.bank_engine.repair_legacy_player_money_mirror()
		phase_report ["repairs"].append("bank_engine.repair_legacy_player_money_mirror")

	if gs.has_method("_ensure_loaded_player_lineage"):
		gs._ensure_loaded_player_lineage()
		phase_report ["repairs"].append("_ensure_loaded_player_lineage")

	if gs.has_method("_soft_unload_npcs"):
		gs._soft_unload_npcs()
		phase_report ["repairs"].append("_soft_unload_npcs")

	phase_report ["hydrated"].append({ "id": "runtime_finalization"})

func _reconcile_runtime_state(phase_report: Dictionary, _options: Dictionary = {}) -> void:
	if gs == null:
		phase_report ["failed"].append({ "reason": "GameState unavailable during reconciliation."})
		return

	if gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()
		phase_report ["repairs"].append("_rebuild_npc_index")

	if gs.player == null and gs.npcs.size() > 0:
		gs.player = gs.npcs [0]
		phase_report ["repairs"].append("player_fallback_from_npcs")

	gs.player_id = gs.player.id if gs.player != null else -1

	for npc in gs.npcs:
		if npc == null:
			continue
		if "parents" in npc and typeof(npc.parents) != TYPE_ARRAY:
			npc.parents = []
		if "children" in npc and typeof(npc.children) != TYPE_ARRAY:
			npc.children = []
		if "friends" in npc and typeof(npc.friends) != TYPE_ARRAY:
			npc.friends = []
		if "partner" in npc and npc.partner != null:
			if gs.get_npc_by_id(int(npc.partner.id)) == null:
				npc.partner = null

	if gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("repair_runtime_realm_maps"):
		gs.realm_contract_engine.repair_runtime_realm_maps()
		phase_report ["repairs"].append("realm_contract_engine.repair_runtime_realm_maps")

func _import_registry_if_available(engine_property: String, data_key: String, import_method: String, data: Dictionary, phase_report: Dictionary) -> void:
	if not data.has(data_key):
		return

	var target = _resolve_engine(engine_property)
	if target == null:
		phase_report ["warnings"].append({
			"data_key": data_key,
			"engine_property": engine_property,
			"reason": "registry_engine_unavailable"
		})
		return

	if not target.has_method(import_method):
		phase_report ["warnings"].append({
			"data_key": data_key,
			"engine_property": engine_property,
			"import_method": import_method,
			"reason": "registry_import_method_unavailable"
		})
		return

	target.callv(import_method, [data.get(data_key, {})])
	phase_report ["hydrated"].append({
		"id": data_key,
		"engine_property": engine_property,
		"import_method": import_method
	})

func _resolve_save_slice_contracts() -> Array:
	var out: Array = []

	if gs != null and gs.game_state_contract_engine != null:
		var registry_raw: Variant = gs.game_state_contract_engine.get("save_slice_registry")
		if typeof(registry_raw) == TYPE_DICTIONARY:
			for key in (registry_raw as Dictionary).keys():
				var raw_contract: Variant = (registry_raw as Dictionary).get(key, {})
				if typeof(raw_contract) == TYPE_DICTIONARY:
					out.append((raw_contract as Dictionary).duplicate(true))
		elif typeof(registry_raw) == TYPE_ARRAY:
			for raw in registry_raw:
				if typeof(raw) == TYPE_DICTIONARY:
					out.append((raw as Dictionary).duplicate(true))

		if out.is_empty() and gs.game_state_contract_engine.has_method("export_registry"):
			var exported: Variant = gs.game_state_contract_engine.export_registry()
			if typeof(exported) == TYPE_DICTIONARY:
				out = _extract_save_slices_from_registry(exported as Dictionary)

	if out.is_empty():
		out = _fallback_legacy_save_slice_contracts()

	return out

func _extract_save_slices_from_registry(registry: Dictionary) -> Array:
	var out: Array = []
	for key in ["save_slice_registry", "save_slices"]:
		var raw: Variant = registry.get(key, null)
		if typeof(raw) == TYPE_DICTIONARY:
			for slice_key in (raw as Dictionary).keys():
				var slice_contract: Variant = (raw as Dictionary).get(slice_key, {})
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))
		elif typeof(raw) == TYPE_ARRAY:
			for slice_contract in raw:
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))

	var active_contract_raw: Variant = registry.get("active_save_contract", registry.get("kernel_contract", {}))
	if typeof(active_contract_raw) == TYPE_DICTIONARY:
		var active_contract: Dictionary = active_contract_raw
		var active_slices: Variant = active_contract.get("save_slices", [])
		if typeof(active_slices) == TYPE_ARRAY:
			for slice_contract in active_slices:
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))

	return out

func _fallback_legacy_save_slice_contracts() -> Array:
	return [
		{ "id": "realm_contract_registry", "save_key": "realm_contract_registry", "engine_id": "realm_contract_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "simulation_contract_registry", "save_key": "simulation_contract_registry", "engine_id": "simulation_contract_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "ui_contract_registry", "save_key": "ui_contract_registry", "engine_id": "ui_contract_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "world_engine_contract_registry", "save_key": "world_engine_contract_registry", "engine_id": "world_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "life_engine_contract_registry", "save_key": "life_engine_contract_registry", "engine_id": "life_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "universal_faction_state", "save_key": "universal_faction_state", "engine_id": "universal_faction_engine", "import_method": "import_state", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "food_engine_state", "save_key": "food_engine_state", "engine_id": "food_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "food_restaurant_engine_state", "save_key": "food_restaurant_engine_state", "engine_id": "food_restaurant_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "grocery_store_engine_state", "save_key": "grocery_store_engine_state", "engine_id": "grocery_store_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "runtime_contract_engine_state", "save_key": "runtime_contract_engine_state", "engine_id": "runtime_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "romance_contract_engine_state", "save_key": "romance_contract_engine_state", "engine_id": "romance_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "romance_contract_engine_state", "save_key": "romance_contract_engine_state", "engine_id": "romance_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "shared_public_space_engine_state", "save_key": "shared_public_space_engine_state", "engine_id": "shared_public_space_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "genetics_inheritance_engine_state", "save_key": "genetics_inheritance_engine_state", "engine_id": "genetics_inheritance_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "body_type_contract_engine_state", "save_key": "body_type_contract_engine_state", "engine_id": "body_type_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "growth_curve_engine_state", "save_key": "growth_curve_engine_state", "engine_id": "growth_curve_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "height_contract_engine_state", "save_key": "height_contract_engine_state", "engine_id": "height_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "weight_contract_engine_state", "save_key": "weight_contract_engine_state", "engine_id": "weight_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "movie_theater_engine_state", "save_key": "movie_theater_engine_state", "engine_id": "movie_theater_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "luxury_shop_engine_state", "save_key": "luxury_shop_engine_state", "engine_id": "luxury_shop_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "bank_engine_state", "save_key": "bank_engine_state", "engine_id": "bank_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "crime_contract_engine_state", "save_key": "crime_contract_engine_state", "engine_id": "crime_contract_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "investigation_layer_state", "save_key": "investigation_layer_state", "engine_id": "investigation_layer", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "justice_system_engine_state", "save_key": "justice_system_engine_state", "engine_id": "justice_system_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "jail_engine_state", "save_key": "jail_engine_state", "engine_id": "jail_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "prison_engine_state", "save_key": "prison_engine_state", "engine_id": "prison_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "case_orchestrator_state", "save_key": "case_orchestrator_state", "engine_id": "case_orchestrator", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "belongings_engine_state", "save_key": "belongings_engine_state", "engine_id": "belongings_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_opponent_pool_engine_state", "save_key": "boxing_opponent_pool_engine_state", "engine_id": "boxing_opponent_pool_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_combat_resolution_engine_state", "save_key": "boxing_combat_resolution_engine_state", "engine_id": "boxing_combat_resolution_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_fight_economy_engine_state", "save_key": "boxing_fight_economy_engine_state", "engine_id": "boxing_fight_economy_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_title_engine_state", "save_key": "boxing_title_engine_state", "engine_id": "boxing_title_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_amateur_engine_state", "save_key": "boxing_amateur_engine_state", "engine_id": "boxing_amateur_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_media_engine_state", "save_key": "boxing_media_engine_state", "engine_id": "boxing_media_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE}
	]

func _phase_for_slice(slice_contract: Dictionary) -> String:
	var explicit_phase: String = str(slice_contract.get("hydration_phase", "")).strip_edges()
	if explicit_phase in PHASE_ORDER:
		return explicit_phase

	var metadata: Dictionary = slice_contract.get("metadata", {}) if typeof(slice_contract.get("metadata", {})) == TYPE_DICTIONARY else {}
	var metadata_phase: String = str(metadata.get("hydration_phase", metadata.get("phase", ""))).strip_edges()
	if metadata_phase in PHASE_ORDER:
		return metadata_phase

	var save_key: String = str(slice_contract.get("save_key", slice_contract.get("id", ""))).strip_edges()
	var mapped: String = _phase_for_save_key(save_key)
	if mapped != "":
		return mapped

	var lane: String = str(metadata.get("hydration_lane", slice_contract.get("hydration_lane", ""))).strip_edges().to_lower()
	match lane:
		"identity", "core_identity":
			return PHASE_CORE_IDENTITY
		"structural", "structure", "realm", "world", "faction":
			return PHASE_STRUCTURAL_SYSTEMS
		"entity", "entities", "npc", "relationship":
			return PHASE_ENTITY_GRAPH
		"system", "runtime", "core":
			return PHASE_SYSTEM_STATE
		"derived", "cache":
			return PHASE_DERIVED_SYSTEMS
		"final", "finalization":
			return PHASE_FINALIZATION
		_:
			return PHASE_SYSTEM_STATE

func _phase_for_save_key(save_key: String) -> String:
	match str(save_key).strip_edges():
		"realm_contract_registry", "simulation_contract_registry", "ui_contract_registry", "world_engine_contract_registry", "life_engine_contract_registry", "game_state_contract_registry", "game_state_contract_slices", "realm_realms", "universal_faction_state":
			return PHASE_STRUCTURAL_SYSTEMS
		"npcs", "player_id", "memories", "agent_observer_memories", "compressed_memories", "npc_graveyard", "archive_generations", "dormant_npcs", "population_shards", "lineage_ledger", "scenario_state", "scenario_history", "transient_scenario_biases":
			return PHASE_ENTITY_GRAPH
		"warm_world_runtime_snapshot":
			return PHASE_DERIVED_SYSTEMS
		"year", "next_id", "era_name", "save_version":
			return PHASE_CORE_IDENTITY
		_:
			return PHASE_SYSTEM_STATE

func _slice_allowed_for_profile(slice_contract: Dictionary, options: Dictionary) -> bool:
	var profile: String = str(options.get("profile", "full_simulation")).strip_edges().to_lower()
	if profile in ["", "full", "full_simulation", "desktop"]:
		return true

	var metadata: Dictionary = slice_contract.get("metadata", {}) if typeof(slice_contract.get("metadata", {})) == TYPE_DICTIONARY else {}
	if bool(slice_contract.get("stream_on_demand", metadata.get("stream_on_demand", false))):
		return false

	if profile in ["mobile", "phone", "smart_tv", "low_power"]:
		var save_key: String = str(slice_contract.get("save_key", "")).strip_edges()
		if save_key in ["world_chronicle", "historical_timeline", "npc_memory_web_state", "large_cache_state"]:
			return false

	return true

func _resolve_engine(engine_id: String) -> Variant:
	if gs == null:
		return null

	var clean: String = str(engine_id).strip_edges()
	if clean == "":
		return null

	if gs.has_method("get"):
		var value: Variant = gs.get(clean)
		if value != null:
			return value

	if typeof(gs.contract_runtime_engines) == TYPE_DICTIONARY and gs.contract_runtime_engines.has(clean):
		return gs.contract_runtime_engines.get(clean)

	return null

func _collect_unknown_slices(data: Dictionary) -> Dictionary:
	var known: Dictionary = {}
	for key in [
		"year", "next_id", "era_name", "save_version", "player_id", "npcs",
		"dynasties", "historical_timeline", "world_chronicle", "world_feed",
		"memories", "agent_observer_memories", "compressed_memories",
		"npc_graveyard", "archive_generations", "dormant_npcs",
		"population_shards", "lineage_ledger", "scenario_state",
		"scenario_history", "transient_scenario_biases", "custom_mode",
		"custom_settings", "reality_mode", "feature_overrides",
		"mod_contract_registry", "game_state_contract_registry",
		"game_state_contract_slices", "game_state_runtime_guard",
		"realm_realms", "warm_world_runtime_snapshot",
		"schema", "version", "serialization_runtime_version", "saved_at_ms",
		"slices", "meta", "migration_hints", "save_contract",
		"binary_save_envelope", "contract_governor_report",
		"preserved_unknown_save_slices", "orphaned_slices",
		"realm_realms", "warm_world_runtime_snapshot"
	]:
		known [key] = true

	for contract in _resolve_save_slice_contracts():
		if typeof(contract) != TYPE_DICTIONARY:
			continue
		var save_key: String = str((contract as Dictionary).get("save_key", (contract as Dictionary).get("id", ""))).strip_edges()
		if save_key != "":
			known [save_key] = true

	var unknown: Dictionary = {}
	for key in data.keys():
		var clean_key: String = str(key)
		if known.has(clean_key):
			continue
		unknown [clean_key] = {
			"save_key": clean_key,
			"data": _make_binary_safe(data.get(key)),
			"unknown": true,
			"preserved_at_ms": int(Time.get_ticks_msec())
		}
	return unknown

func _store_preserved_unknown_slices(unknown: Dictionary, report: Dictionary) -> void:
	if gs == null:
		return
	gs.preserved_unknown_save_slices = unknown.duplicate(true)
	report ["unknown_slices"] = unknown.keys()
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["preserved_unknown_save_slices"] = unknown.duplicate(true)

func _begin_phase_report(phase_id: String) -> Dictionary:
	return {
		"id": phase_id,
		"started_at_ms": int(Time.get_ticks_msec()),
		"finished_at_ms": 0,
		"duration_ms": 0,
		"hydrated": [],
		"deferred": [],
		"failed": [],
		"warnings": [],
		"validations": [],
		"repairs": []
	}

func _resolve_merge_policy(merge_contract: Dictionary) -> Dictionary:
	var raw_policy: Variant = merge_contract.get("merge_policy", merge_contract)
	var policy: Dictionary = raw_policy if typeof(raw_policy) == TYPE_DICTIONARY else {}
	var out: Dictionary = {
		"relationship_scope": ["parents", "children", "spouse"],
		"friend_link": "bidirectional",
		"root_person_id": -1,
		"lineage_strategy": "preserve",
		"id_strategy": "remap_safe",
		"conflict_resolution": "parallel_identity",
		"world_integration": {
			"register_npcs": true,
			"rebuild_index": true,
			"ensure_lineage": true
		}
	}
	return _merge_dict(out, policy)

func _merge_find_foreign_dict(list: Array, old_id: int) -> Dictionary:
	for raw in list:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		if int(d.get("id", -1)) == old_id:
			return d
	return {}
func _merge_person_name_from_dict(data: Dictionary) -> String:
	var full_name: String = str(data.get("name", "")).strip_edges()
	if full_name != "":
		return full_name
	return ("%s %s" % [
		str(data.get("first_name", "")),
		str(data.get("last_name", ""))
	]).strip_edges()
func _merge_linked_ids_from_policy(src: Dictionary, policy: Dictionary, foreign_npcs: Array = []) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var scope: Array = _safe_array(policy.get("relationship_scope", []))

	if "parents" in scope:
		for pid in _safe_array(src.get("parents", [])):
			_merge_append_linked_id(out, seen, int(pid))

	if "children" in scope:
		for cid in _safe_array(src.get("children", [])):
			_merge_append_linked_id(out, seen, int(cid))

	if "spouse" in scope or "partner" in scope:
		var partner_id: int = int(src.get("partner_id", -1))
		_merge_append_linked_id(out, seen, partner_id)

	if "ex_partners" in scope:
		for ex_id in _safe_array(src.get("ex_partners", [])):
			_merge_append_linked_id(out, seen, int(ex_id))

	if "siblings" in scope or "family_web" in scope or "extended_family" in scope:
		var source_parent_ids: Array = _safe_array(src.get("parents", []))
		for raw_npc in foreign_npcs:
			if typeof(raw_npc) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = raw_npc
			var candidate_id: int = int(candidate.get("id", -1))
			if candidate_id <= 0 or candidate_id == int(src.get("id", -1)):
				continue
			for pid in source_parent_ids:
				if int(pid) > 0 and int(pid) in _safe_array(candidate.get("parents", [])):
					_merge_append_linked_id(out, seen, candidate_id)

	if "grandparents" in scope or "family_web" in scope or "extended_family" in scope:
		for pid in _safe_array(src.get("parents", [])):
			var parent_dict: Dictionary = _merge_find_foreign_dict(foreign_npcs, int(pid))
			for gpid in _safe_array(parent_dict.get("parents", [])):
				_merge_append_linked_id(out, seen, int(gpid))

	if "grandchildren" in scope or "family_web" in scope or "extended_family" in scope:
		for cid in _safe_array(src.get("children", [])):
			var child_dict: Dictionary = _merge_find_foreign_dict(foreign_npcs, int(cid))
			for gcid in _safe_array(child_dict.get("children", [])):
				_merge_append_linked_id(out, seen, int(gcid))

	return out


func _merge_append_linked_id(out: Array, seen: Dictionary, linked_id: int) -> void:
	if linked_id <= 0:
		return
	if seen.has(linked_id):
		return
	seen [linked_id] = true
	out.append(linked_id)

func _import_foreign_person(old_id: int, foreign_npcs: Array, id_map: Dictionary, imported_cache: Dictionary) -> Variant:
	if gs == null:
		return null

	if gs.has_method("_merge_import_single"):
		return gs._merge_import_single(gs, foreign_npcs, old_id, id_map, imported_cache)

	var src: Dictionary = _merge_find_foreign_dict(foreign_npcs, old_id)
	if src.is_empty():
		return null

	var new_p = gs._deserialize_npc(src)
	new_p.id = _remap_foreign_id(old_id, id_map)
	if "parents" in new_p:
		new_p.parents = new_p.parents.duplicate()
	if "children" in new_p:
		new_p.children = new_p.children.duplicate()
	imported_cache [old_id] = new_p
	return new_p

func _remap_foreign_id(old_id: int, id_map: Dictionary) -> int:
	if gs != null and gs.has_method("_merge_remap_id"):
		return gs._merge_remap_id(gs, id_map, old_id)

	if old_id <= 0:
		return 0
	if not id_map.has(old_id):
		id_map [old_id] = gs.next_id
		gs.next_id += 1
	return int(id_map [old_id])

func _reconcile_imported_family_links(imported_cache: Dictionary, id_map: Dictionary, policy: Dictionary) -> void:
	var scope: Array = _safe_array(policy.get("relationship_scope", []))
	var lineage_strategy: String = str(policy.get("lineage_strategy", "preserve")).strip_edges().to_lower()

	if lineage_strategy == "none":
		return

	for old_id in imported_cache.keys():
		var p = imported_cache [old_id]
		if p == null:
			continue

		if "parents" in scope and "parents" in p:
			var new_parents: Array = []
			for pid in p.parents:
				if imported_cache.has(int(pid)):
					new_parents.append(_remap_foreign_id(int(pid), id_map))
			p.parents = new_parents

		if "children" in scope and "children" in p:
			var new_children: Array = []
			for cid in p.children:
				if imported_cache.has(int(cid)):
					new_children.append(_remap_foreign_id(int(cid), id_map))
			p.children = new_children

		if ("spouse" in scope or "partner" in scope) and "partner" in p:
			p.partner = null

func _integrate_imported_people(imported_cache: Dictionary, policy: Dictionary) -> void:
	if gs == null:
		return

	var integration: Dictionary = policy.get("world_integration", {}) if typeof(policy.get("world_integration", {})) == TYPE_DICTIONARY else {}
	var should_register: bool = bool(integration.get("register_npcs", true))
	var should_rebuild: bool = bool(integration.get("rebuild_index", true))
	var should_lineage: bool = bool(integration.get("ensure_lineage", true))

	for p in imported_cache.values():
		if p == null:
			continue
		if should_register and gs.has_method("register_npc"):
			gs.register_npc(p)
		if should_lineage and gs.npc_factory != null and gs.npc_factory.has_method("ensure_family_lineage"):
			gs.npc_factory.ensure_family_lineage(p)

	if should_rebuild and gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()

func _apply_merge_friend_policy(imported_player: Variant, policy: Dictionary) -> void:
	if gs == null or imported_player == null or gs.player == null:
		return

	var friend_link: String = str(policy.get("friend_link", "bidirectional")).strip_edges().to_lower()
	match friend_link:
		"none", "false", "disabled":
			return
		"player_to_imported":
			if imported_player.id not in gs.player.friends:
				gs.player.friends.append(imported_player.id)
		"imported_to_player":
			if gs.player.id not in imported_player.friends:
				imported_player.friends.append(gs.player.id)
		_:
			if imported_player.id not in gs.player.friends:
				gs.player.friends.append(imported_player.id)
			if gs.player.id not in imported_player.friends:
				imported_player.friends.append(gs.player.id)

func _merge_fail(reason: String, message: String, started_at: int, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.reality_merge_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": false,
		"reason": message,
		"reason_id": reason,
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at
	for key in extra.keys():
		report [key] = extra [key]
	last_merge_report = report.duplicate(true)
	return report

func _fail_report(reason_id: String, reason: String, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.game_state_hydration_report",
		"version": HYDRATION_RUNTIME_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": reason,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	for key in extra.keys():
		report [key] = extra [key]
	last_hydration_report = report.duplicate(true)
	return report

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch [key]
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value
	return out

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)