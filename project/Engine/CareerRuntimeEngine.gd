extends Resource
class_name CareerRuntimeEngine

const ENGINE_SCHEMA:= "eralife.career_runtime_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "career_ecosystem_state"
const CAREER_STAFFING_FILL_BUDGET_PER_QUANTUM:= 4
const CAREER_STAFFING_SCAN_BUDGET_PER_QUANTUM:= 16

var staffing_candidate_cursor_by_path: Dictionary = {}
const MAX_APPLICATION_HISTORY:= 160
const MAX_WORLD_EVENT_HISTORY:= 240
const MAX_ORGANIZATION_HISTORY:= 120

var gs
var last_runtime_report: Dictionary = {}

var path_ecosystem_reconciliation_queue: Array = []
var path_ecosystem_reconciliation_keys: Dictionary = {}
var path_ecosystem_reconciliation_service_active: bool = false
var legacy_job_reconciliation_queue: Array = []
var legacy_job_reconciliation_keys: Dictionary = {}
var legacy_job_reconciliation_service_active: bool = false

func _init(_gs):
	gs = _gs
	_ensure_state_shape()


func bootstrap_default_contracts() -> Dictionary:
	var report: Dictionary = ensure_world_ecosystem({
		"source": (
			"career_runtime_engine.bootstrap_default_contracts"
		)
	})

	var contract_engine = _contract_engine()

	if contract_engine != null:
		queue_path_ecosystem_reconciliation(
			contract_engine.career_paths.keys(),
			{
				"source": (
					"career_runtime_engine."
					+ "bootstrap_background_staffing"
				),
				"background_only": true,
				"blocks_ui": false,
				"ready_gate_member": false
			}
		)

	queue_legacy_job_reconciliation(
		_active_people(),
		{
			"source": (
				"career_runtime_engine."
				+ "bootstrap_legacy_job_reconciliation"
			),
			"background_only": true,
			"blocks_ui": false,
			"ready_gate_member": false
		}
	)

	report [
		"background_staffing_queued"
	] = true
	report [
		"legacy_job_reconciliation_queued"
	] = true
	report [
		"ready_waits_for_background_tail"
	] = false

	return report
func queue_legacy_job_reconciliation(
	actors: Array,
	_context: Dictionary = {}
) -> Dictionary:
	var queued_actor_ids: Array = []

	for raw_actor in actors:
		var actor: Person = (
			raw_actor as Person
		)

		if actor == null:
			continue

		var actor_id: int = int(
			actor.id
		)

		if (
			actor_id <= 0
			or legacy_job_reconciliation_keys.has(
				actor_id
			)
		):
			continue

		legacy_job_reconciliation_keys [
			actor_id
		] = true

		legacy_job_reconciliation_queue.append(
			actor_id
		)

		queued_actor_ids.append(
			actor_id
		)

	if (
		not legacy_job_reconciliation_queue.is_empty()
		and not legacy_job_reconciliation_service_active
	):
		legacy_job_reconciliation_service_active = true

		call_deferred(
			"_service_legacy_job_reconciliation_queue"
		)

	return {
		"success": true,
		"schema": (
			"eralife.career_legacy_job_reconciliation_queue"
		),
		"version": ENGINE_VERSION,
		"queued_actor_ids": queued_actor_ids,
		"queue_size": (
			legacy_job_reconciliation_queue.size()
		),
		"background_only": true,
		"blocks_ui": false,
		"ready_gate_member": false
	}


func _active_person_by_id_without_reactivation(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	for raw_actor in gs.npcs:
		var actor: Person = (
			raw_actor as Person
		)

		if (
			actor != null
			and int(
				actor.id
			) == actor_id
		):
			return actor

	return null


func _service_legacy_job_reconciliation_queue() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		legacy_job_reconciliation_service_active = false
		return

	while not legacy_job_reconciliation_queue.is_empty():
		await RenderingServer.frame_post_draw

		if legacy_job_reconciliation_queue.is_empty():
			break

		var actor_id: int = int(
			legacy_job_reconciliation_queue.pop_front()
		)

		legacy_job_reconciliation_keys.erase(
			actor_id
		)

		var actor: Person = (
			_active_person_by_id_without_reactivation(
				actor_id
			)
		)

		if actor != null:
			sync_actor_from_legacy_job(
				actor,
				{
					"source": (
						"career_runtime_engine."
						+ "background_legacy_job_reconciliation"
					),
					"world_ecosystem_already_resident": true,
					"background_only": true,
					"blocks_ui": false,
					"ready_gate_member": false
				}
			)

		await tree.process_frame

	legacy_job_reconciliation_service_active = false

	if not legacy_job_reconciliation_queue.is_empty():
		legacy_job_reconciliation_service_active = true

		call_deferred(
			"_service_legacy_job_reconciliation_queue"
		)

func ensure_world_ecosystem(
	context: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = _ensure_state_shape()
	var contract_engine = _contract_engine()

	if contract_engine == null:
		return _fail(
			"career_contract_engine_unavailable",
			context
		)

	var era_name: String = _current_era_name()
	var boot_key: String = "%s|catalog:%d" % [
		era_name,
		contract_engine.career_paths.size()
	]
	var boot_reports: Dictionary = _safe_dictionary(
		state.get(
			"era_boot_reports",
			{}
		)
	)
	var created_organizations: int = 0
	var created_departments: int = 0
	var created_positions: int = 0

	if not boot_reports.has(boot_key):
		for raw_path_id in contract_engine.career_paths.keys():
			var path: Dictionary = (
				contract_engine.get_path_definition(
					str(raw_path_id)
				)
			)

			if path.is_empty():
				continue

			if era_name not in _safe_array(
				path.get(
					"eras",
					[]
				)
			):
				continue

			var report: Dictionary = (
				_ensure_organization_for_path(
					path
				)
			)

			created_organizations += int(
				report.get(
					"created_organizations",
					0
				)
			)
			created_departments += int(
				report.get(
					"created_departments",
					0
				)
			)
			created_positions += int(
				report.get(
					"created_positions",
					0
				)
			)

		boot_reports [boot_key] = {
			"era_name": era_name,
			"year": int(gs.year),
			"created_organizations": (
				created_organizations
			),
			"created_departments": (
				created_departments
			),
			"created_positions": (
				created_positions
			),
			"booted_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		state [
			"era_boot_reports"
		] = boot_reports

	_reconcile_assignments()
	_reconcile_vacancies()
	_sync_state_back(state)

	last_runtime_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"era_name": era_name,
		"organization_count": _safe_dictionary(
			state.get(
				"organizations",
				{}
			)
		).size(),
		"department_count": _safe_dictionary(
			state.get(
				"departments",
				{}
			)
		).size(),
		"position_count": _safe_dictionary(
			state.get(
				"positions",
				{}
			)
		).size(),
		"assignment_count": _safe_dictionary(
			state.get(
				"assignments",
				{}
			)
		).size(),
		"created_organizations": (
			created_organizations
		),
		"created_departments": (
			created_departments
		),
		"created_positions": (
			created_positions
		),
		"vacancy_driven": true,
		"ui_is_renderer_only": true
	}

	return last_runtime_report.duplicate(true)

func queue_path_ecosystem_reconciliation(
	path_ids: Array,
	context: Dictionary = {}
) -> Dictionary:
	var contract_engine = _contract_engine()

	if contract_engine == null:
		return _fail(
			"career_contract_engine_unavailable",
			context
		)

	var era_name: String = _current_era_name()
	var queued_path_ids: Array = []

	for raw_path_id in path_ids:
		var path_id: String = str(
			raw_path_id
		).strip_edges()

		if path_id == "":
			continue

		var path: Dictionary = (
			contract_engine.get_path_definition(
				path_id
			)
		)

		if path.is_empty():
			continue



		if era_name not in _safe_array(
			path.get(
				"eras",
				[]
			)
		):
			continue

		if path_ecosystem_reconciliation_keys.has(
			path_id
		):
			continue

		path_ecosystem_reconciliation_keys [
			path_id
		] = true

		path_ecosystem_reconciliation_queue.append(
			path_id
		)

		queued_path_ids.append(
			path_id
		)

	if (
		not path_ecosystem_reconciliation_queue.is_empty()
		and not path_ecosystem_reconciliation_service_active
	):
		path_ecosystem_reconciliation_service_active = true

		call_deferred(
			"_service_path_ecosystem_reconciliation_queue"
		)

	return {
		"success": true,
		"schema": (
			"eralife.career_path_ecosystem_queue_report"
		),
		"version": ENGINE_VERSION,
		"era_name": era_name,
		"queued_path_ids": queued_path_ids,
		"queue_size": (
			path_ecosystem_reconciliation_queue.size()
		),
		"background_only": true,
		"blocks_ui": false,
		"build_on_click": false,
		"ready_gate_member": false
	}
func _service_path_ecosystem_reconciliation_queue() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		path_ecosystem_reconciliation_service_active = false
		return

	var contract_engine = _contract_engine()

	if contract_engine == null:
		path_ecosystem_reconciliation_queue.clear()
		path_ecosystem_reconciliation_keys.clear()
		path_ecosystem_reconciliation_service_active = false
		return

	while not path_ecosystem_reconciliation_queue.is_empty():

		await RenderingServer.frame_post_draw

		if path_ecosystem_reconciliation_queue.is_empty():
			break

		var path_id: String = str(
			path_ecosystem_reconciliation_queue.pop_front()
		)

		path_ecosystem_reconciliation_keys.erase(
			path_id
		)

		var path: Dictionary = (
			contract_engine.get_path_definition(
				path_id
			)
		)

		if (
			path.is_empty()
			or _current_era_name() not in _safe_array(
				path.get(
					"eras",
					[]
				)
			)
		):
			await tree.process_frame
			continue

		_ensure_organization_for_path(
			path
		)


		await tree.process_frame

		var filled_this_quantum: int = (
			_fill_open_positions_with_npcs(
				CAREER_STAFFING_FILL_BUDGET_PER_QUANTUM,
				path_id,
				CAREER_STAFFING_SCAN_BUDGET_PER_QUANTUM
			)
		)

		if filled_this_quantum > 0:
			last_runtime_report [
				"last_background_staffing_path_id"
			] = path_id
			last_runtime_report [
				"last_background_staffing_filled"
			] = filled_this_quantum
			last_runtime_report [
				"background_staffing_blocks_ui"
			] = false


		await tree.process_frame

	_reconcile_assignments()
	_reconcile_vacancies()

	_sync_state_back(
		_ensure_state_shape()
	)

	last_runtime_report [
		"background_staffing_complete"
	] = true
	last_runtime_report [
		"background_staffing_vacancies_preserved"
	] = true
	last_runtime_report [
		"background_staffing_ready_gate_member"
	] = false

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"career.ecosystem_background_reconciled",
			{
				"year": int(
					gs.year
				),
				"era_name": (
					_current_era_name()
				),
				"background_only": true,
				"blocks_ui": false
			}
		)

	path_ecosystem_reconciliation_service_active = false

	if not path_ecosystem_reconciliation_queue.is_empty():
		path_ecosystem_reconciliation_service_active = true

		call_deferred(
			"_service_path_ecosystem_reconciliation_queue"
		)
func ensure_actor_profile(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var profile: Dictionary = _safe_dictionary(
		actor.career_profile
	)

	profile ["schema"] = (
		"eralife.person_career_profile"
	)
	profile ["version"] = 1
	profile ["actor_id"] = int(actor.id)
	profile ["current_assignment_id"] = str(
		profile.get(
			"current_assignment_id",
			""
		)
	)
	profile ["application_ids"] = _safe_array(
		profile.get(
			"application_ids",
			profile.get(
				"active_application_ids",
				[]
			)
		)
	)
	profile ["career_history"] = _safe_array(
		profile.get(
			"career_history",
			[]
		)
	)
	profile ["professional_reputation"] = (
		_normalized_reputation(
			_safe_dictionary(
				profile.get(
					"professional_reputation",
					{}
				)
			)
		)
	)
	profile [
		"professional_reputation_score"
	] = _reputation_score(
		_safe_dictionary(
			profile.get(
				"professional_reputation",
				{}
			)
		)
	)
	profile ["legacy"] = _normalized_legacy(
		_safe_dictionary(
			profile.get(
				"legacy",
				{}
			)
		)
	)

	actor.career_profile = profile.duplicate(
		true
	)

	return profile.duplicate(true)


func sync_actor_from_legacy_job(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	if not bool(
		context.get(
			"world_ecosystem_already_resident",
			false
		)
	):
		ensure_world_ecosystem({
			"source": (
				"career_runtime_engine.sync_actor_from_legacy_job"
			)
		})

	var existing: Dictionary = assignment_for_actor(
		actor
	)

	if not existing.is_empty():
		_sync_legacy_fields(
			actor,
			existing
		)

		return {
			"success": true,
			"assignment": existing,
		}

	var clean_job: String = str(
		actor.job
	).strip_edges()

	if clean_job == "" or clean_job == "Retired":
		return {
			"success": true,
			"assignment": {},
		}

	var path_id: String = (
		_contract_engine()
		.path_id_for_legacy_job(
			clean_job
		)
	)

	if path_id == "":
		return _register_legacy_fallback(
			actor,
			clean_job,
			context
		)

	var path: Dictionary = (
		_contract_engine()
		.get_path_definition(
			path_id
		)
	)
	var rank_index: int = 0

	for index in range(
		_safe_array(
			path.get(
				"ranks",
				[]
			)
		).size()
	):
		var rank: Dictionary = (
			_contract_engine()
			.get_rank_definition(
				path_id,
				index
			)
		)

		if str(
			rank.get(
				"title",
				""
			)
		).to_lower() == clean_job.to_lower():
			rank_index = index
			break

	var position: Dictionary = (
		_find_or_create_vacant_position(
			path_id,
			rank_index,
			true
		)
	)

	if position.is_empty():
		return _fail(
			"legacy_position_unavailable",
			context
		)

	return commit_hire(
		actor,
		position,
		{
			"source": "legacy_job_hydration",
			"preserve_existing_income": true,
			"preserve_existing_performance": true,
			"preserve_existing_experience": true,
			"silent": true
		}
	)


func assignment_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _resident_state()

	if state.is_empty():
		return {}

	var index: Dictionary = _read_dictionary(
		state.get(
			"actor_assignment_index",
			{}
		)
	)

	var assignment_id: String = str(
		index.get(
			int(actor.id),
			index.get(
				str(
					int(actor.id)
				),
				""
			)
		)
	)

	if assignment_id == "":
		var profile: Dictionary = (
			resident_actor_profile(
				actor
			)
		)
		assignment_id = str(
			profile.get(
				"current_assignment_id",
				""
			)
		)

	if assignment_id == "":
		return {}

	var assignments: Dictionary = _read_dictionary(
		state.get(
			"assignments",
			{}
		)
	)

	var assignment_raw: Variant = assignments.get(
		assignment_id,
		{}
	)

	return (
		assignment_raw as Dictionary
		if typeof(assignment_raw) == TYPE_DICTIONARY
		else {}
	)


func position_for_actor(
	actor: Person
) -> Dictionary:
	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return {}

	return position_by_id(
		str(
			assignment.get(
				"position_id",
				""
			)
		)
	)


func organization_for_actor(
	actor: Person
) -> Dictionary:
	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return {}

	return organization_by_id(
		str(
			assignment.get(
				"organization_id",
				""
			)
		)
	)


func position_by_id(
	position_id: String
) -> Dictionary:
	var state: Dictionary = _resident_state()
	var positions: Dictionary = _read_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var raw_position: Variant = positions.get(
		position_id,
		{}
	)

	return (
		raw_position as Dictionary
		if typeof(raw_position) == TYPE_DICTIONARY
		else {}
	)


func organization_by_id(
	organization_id: String
) -> Dictionary:
	var state: Dictionary = _resident_state()
	var organizations: Dictionary = _read_dictionary(
		state.get(
			"organizations",
			{}
		)
	)
	var raw_organization: Variant = organizations.get(
		organization_id,
		{}
	)

	return (
		raw_organization as Dictionary
		if typeof(raw_organization) == TYPE_DICTIONARY
		else {}
	)


func department_by_id(
	department_id: String
) -> Dictionary:
	var state: Dictionary = _resident_state()
	var departments: Dictionary = _read_dictionary(
		state.get(
			"departments",
			{}
		)
	)
	var raw_department: Variant = departments.get(
		department_id,
		{}
	)

	return (
		raw_department as Dictionary
		if typeof(raw_department) == TYPE_DICTIONARY
		else {}
	)

func open_positions_for_actor(
	actor: Person,
	lane: String = "all"
) -> Array:
	var out: Array = []

	if (
		actor == null
		or not actor.alive
	):
		return out

	var clean_lane: String = str(
		lane
	).strip_edges().to_lower()

	var state: Dictionary = _resident_state()
	var positions: Dictionary = _read_dictionary(
		state.get(
			"positions",
			{}
		)
	)

	for raw_position in positions.values():
		if typeof(raw_position) != TYPE_DICTIONARY:
			continue

		var position: Dictionary = (
			raw_position as Dictionary
		)

		if position.is_empty():
			continue

		if str(
			position.get(
				"status",
				""
			)
		) != "vacant":
			continue

		if not bool(
			position.get(
				"accepting_applications",
				true
			)
		):
			continue

		var organization: Dictionary = (
			organization_by_id(
				str(
					position.get(
						"organization_id",
						""
					)
				)
			)
		)

		if not bool(
			organization.get(
				"active",
				true
			)
		):
			continue

		var contract_engine = _contract_engine()

		if contract_engine == null:
			continue

		var path: Dictionary = (
			contract_engine.get_path_definition(
				str(
					position.get(
						"path_id",
						""
					)
				)
			)
		)

		if path.is_empty():
			continue

		if _current_era_name() not in _read_array(
			path.get(
				"eras",
				[]
			)
		):
			continue

		if (
			clean_lane not in [
				"",
				"all"
			]
			and str(
				path.get(
					"lane",
					"full_time"
				)
			) != clean_lane
		):
			continue

		out.append(
			position
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

			if int(
				left.get(
					"rank_index",
					0
				)
			) == int(
				right.get(
					"rank_index",
					0
				)
			):
				return str(
					left.get(
						"position_id",
						""
					)
				) < str(
					right.get(
						"position_id",
						""
					)
				)

			return int(
				left.get(
					"rank_index",
					0
				)
			) < int(
				right.get(
					"rank_index",
					0
				)
			)
	)

	return out
func commit_weekly_hours(
	actor: Person,
	weekly_hours: int,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	var assignment: Dictionary = (
		assignment_for_actor(
			actor
		)
	)

	if assignment.is_empty():
		return _fail(
			"career_assignment_missing",
			context
		)

	var requested_hours: int = clampi(
		weekly_hours,
		10,
		50
	)

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _read_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)

	var current_raw: Variant = assignments.get(
		assignment_id,
		assignment
	)
	var current: Dictionary = (
		(current_raw as Dictionary).duplicate(false)
		if typeof(current_raw) == TYPE_DICTIONARY
		else assignment.duplicate(false)
	)

	current ["weekly_hours"] = requested_hours
	current ["weekly_hours_set_year"] = int(
		gs.year
	)
	current ["weekly_hours_source"] = str(
		context.get(
			"source",
			"career_runtime_engine"
		)
	)

	assignments [
		assignment_id
	] = current
	state ["assignments"] = assignments

	_sync_state_back(
		state
	)
	_sync_legacy_fields(
		actor,
		current
	)

	return {
		"success": true,
		"type": "career_weekly_hours_updated",
		"actor_id": int(
			actor.id
		),
		"assignment_id": assignment_id,
		"weekly_hours": requested_hours,
		"player_selectable_max_hours": 50,
		"overwork_threshold_hours": 50,
		"text": (
			"I set my work schedule to %d hours per week."
			% requested_hours
		),
		"career_runtime_authority": ENGINE_SCHEMA
	}


func commit_work_harder(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	var assignment: Dictionary = (
		assignment_for_actor(
			actor
		)
	)

	if assignment.is_empty():
		return _fail(
			"career_assignment_missing",
			context
		)

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _read_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)

	var current_raw: Variant = assignments.get(
		assignment_id,
		assignment
	)
	var current: Dictionary = (
		(current_raw as Dictionary).duplicate(false)
		if typeof(current_raw) == TYPE_DICTIONARY
		else assignment.duplicate(false)
	)

	current ["next_year_effort_mode"] = "hard"
	current ["next_year_effort_year"] = int(
		gs.year
	) + 1
	current ["next_year_effort_committed_at_ms"] = int(
		Time.get_ticks_msec()
	)

	assignments [
		assignment_id
	] = current
	state ["assignments"] = assignments

	_sync_state_back(
		state
	)

	return {
		"success": true,
		"type": "career_work_harder_committed",
		"actor_id": int(
			actor.id
		),
		"assignment_id": assignment_id,
		"applies_year": int(
			gs.year
		) + 1,
		"text": (
			"I committed to working harder this year."
		),
		"career_runtime_authority": ENGINE_SCHEMA
	}


func salary_quote_for_path(
	path: Dictionary,
	rank_index: int = 0
) -> int:
	if path.is_empty():
		return 0

	var rank: Dictionary = {}

	if _contract_engine() != null:
		rank = (
			_contract_engine()
			.get_rank_definition(
				str(
					path.get(
						"path_id",
						""
					)
				),
				rank_index
			)
		)

	return _salary_for_position(
		path,
		rank
	)


func find_promotion_vacancy(
	actor: Person
) -> Dictionary:
	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return {}

	var next_rank: int = int(
		assignment.get(
			"rank_index",
			0
		)
	) + 1
	var positions: Dictionary = _safe_dictionary(
		_ensure_state_shape().get(
			"positions",
			{}
		)
	)

	for raw_position in positions.values():
		var position: Dictionary = _safe_dictionary(
			raw_position
		)

		if str(
			position.get(
				"path_id",
				""
			)
		) != str(
			assignment.get(
				"path_id",
				""
			)
		):
			continue

		if str(
			position.get(
				"organization_id",
				""
			)
		) != str(
			assignment.get(
				"organization_id",
				""
			)
		):
			continue

		if (
			int(
				position.get(
					"rank_index",
					-1
				)
			) == next_rank
			and str(
				position.get(
					"status",
					""
				)
			) == "vacant"
		):
			return position

	return {}


func coworker_ids_for_actor(
	actor: Person
) -> Array:
	var out: Array = []

	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return out

	var organization_id: String = str(
		assignment.get(
			"organization_id",
			""
		)
	)

	var path_id: String = str(
		assignment.get(
			"path_id",
			""
		)
	)

	var assignments: Dictionary = _safe_dictionary(
		_ensure_state_shape().get(
			"assignments",
			{}
		)
	)

	for raw_assignment in assignments.values():
		var row: Dictionary = _safe_dictionary(
			raw_assignment
		)

		if not bool(
			row.get(
				"active",
				false
			)
		):
			continue

		if str(
			row.get(
				"organization_id",
				""
			)
		) != organization_id:
			continue




		if str(
			row.get(
				"path_id",
				""
			)
		) != path_id:
			continue

		var coworker_id: int = int(
			row.get(
				"actor_id",
				-1
			)
		)

		if (
			coworker_id > 0
			and coworker_id != int(
				actor.id
			)
			and coworker_id not in out
		):
			out.append(
				coworker_id
			)

	return out

func record_application(
	actor: Person,
	position: Dictionary,
	contract: Dictionary
) -> Dictionary:
	if actor == null or position.is_empty():
		return _fail(
			"invalid_application_record",
			contract
		)

	var state: Dictionary = _ensure_state_shape()
	var applications: Dictionary = _safe_dictionary(
		state.get(
			"applications",
			{}
		)
	)
	var sequence: int = int(
		state.get(
			"next_application_sequence",
			1
		)
	)
	var application_id: String = (
		"application_%d_%d"
		% [
			int(actor.id),
			sequence
		]
	)

	state [
		"next_application_sequence"
	] = sequence + 1

	var row: Dictionary = contract.duplicate(true)
	row ["application_id"] = application_id
	row ["actor_id"] = int(actor.id)
	row ["position_id"] = str(
		position.get(
			"position_id",
			""
		)
	)
	row ["created_at_ms"] = int(
		Time.get_ticks_msec()
	)

	applications [
		application_id
	] = row
	state ["applications"] = applications

	var order: Array = _safe_array(
		state.get(
			"application_order",
			[]
		)
	)
	order.append(
		application_id
	)

	while order.size() > MAX_APPLICATION_HISTORY:
		applications.erase(
			str(
				order.pop_front()
			)
		)

	state ["application_order"] = order
	state ["applications"] = applications

	var profile: Dictionary = ensure_actor_profile(
		actor
	)
	var actor_applications: Array = _safe_array(
		profile.get(
			"application_ids",
			[]
		)
	)
	actor_applications.append(
		application_id
	)

	while actor_applications.size() > 20:
		actor_applications.pop_front()

	profile [
		"application_ids"
	] = actor_applications
	actor.career_profile = profile

	_sync_state_back(state)

	return row


func commit_hire(
	actor: Person,
	position: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	if position.is_empty():
		return _fail(
			"missing_position",
			context
		)

	if not assignment_for_actor(actor).is_empty():
		return _fail(
			"actor_already_employed",
			context
		)

	var state: Dictionary = _ensure_state_shape()
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var position_id: String = str(
		position.get(
			"position_id",
			""
		)
	)
	var canonical_position: Dictionary = _safe_dictionary(
		positions.get(
			position_id,
			position
		)
	)

	if str(
		canonical_position.get(
			"status",
			""
		)
	) != "vacant":
		return _fail(
			"position_no_longer_vacant",
			context
		)

	var path_id: String = str(
		canonical_position.get(
			"path_id",
			""
		)
	)
	var rank_index: int = int(
		canonical_position.get(
			"rank_index",
			0
		)
	)
	var path: Dictionary = (
		_contract_engine()
		.get_path_definition(
			path_id
		)
	)
	var rank: Dictionary = (
		_contract_engine()
		.get_rank_definition(
			path_id,
			rank_index
		)
	)
	var organization: Dictionary = organization_by_id(
		str(
			canonical_position.get(
				"organization_id",
				""
			)
		)
	)
	var salary: int = int(
		canonical_position.get(
			"salary",
			0
		)
	)

	if (
		bool(
			context.get(
				"preserve_existing_income",
				false
			)
		)
		and int(actor.income) > 0
	):
		salary = int(actor.income)

	var sequence: int = int(
		state.get(
			"next_assignment_sequence",
			1
		)
	)
	state [
		"next_assignment_sequence"
	] = sequence + 1

	var assignment_id: String = (
		"career_assignment_%d_%d"
		% [
			int(actor.id),
			sequence
		]
	)
	var assignment: Dictionary = {
		"assignment_id": assignment_id,
		"actor_id": int(actor.id),
		"position_id": position_id,
		"organization_id": str(
			canonical_position.get(
				"organization_id",
				""
			)
		),
		"department_id": str(
			canonical_position.get(
				"department_id",
				""
			)
		),
		"department_name": str(
			canonical_position.get(
				"department_name",
				path.get(
					"department",
					"General"
				)
			)
		),
		"path_id": path_id,
		"rank_index": rank_index,
		"rank_title": str(
			rank.get(
				"title",
				path.get(
					"display_name",
					"Career"
				)
			)
		),
		"salary": salary,
		"performance": (
			int(actor.job_performance)
			if bool(
				context.get(
					"preserve_existing_performance",
					false
				)
			)
			else 50
		),
		"experience": (
			int(actor.job_experience)
			if bool(
				context.get(
					"preserve_existing_experience",
					false
				)
			)
			else 0
		),
		"satisfaction": int(actor.satisfaction),
		"work_stress": float(actor.work_stress),
		"active": true,
		"started_year": int(gs.year),
		"last_review_year": int(gs.year),
		"performance_history": [],
		"activity_history": [],
		"promotion_history": [],
		"source": str(
			context.get(
				"source",
				"career_hire"
			)
		)
	}

	var civic_contract_raw: Variant = (
		actor.get(
			"civic_office_contract"
		)
	)
	var civic_contract: Dictionary = (
		(civic_contract_raw as Dictionary).duplicate(true)
		if typeof(
			civic_contract_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var government_model: String = str(
		civic_contract.get(
			"government_model",
			""
		)
	).strip_edges().to_lower()
	var civic_office: String = str(
		civic_contract.get(
			"office",
			""
		)
	).strip_edges().to_lower()
	var assignment_title: String = str(
		assignment.get(
			"rank_title",
			""
		)
	).strip_edges().to_lower()
	var actor_job: String = str(
		actor.job
	).strip_edges().to_lower()
	var presidential_election: bool = (
		government_model in [
			"federal_presidential_republic",
			"federal_republic",
			"presidential_republic",
			"constitutional_republic"
		]
		and (
			civic_office == "president"
			or assignment_title in [
				"president",
				"president of the united states"
			]
			or actor_job in [
				"president",
				"president of the united states"
			]
		)
	)
	var transition_event: String = (
		"elected"
		if presidential_election
		else "hired"
	)
	var transition_event_name: String = (
		"civic_office_elected"
		if presidential_election
		else "career_hired"
	)

	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	assignments [
		assignment_id
	] = assignment
	state ["assignments"] = assignments

	canonical_position ["status"] = "filled"
	canonical_position [
		"occupant_actor_id"
	] = int(actor.id)
	canonical_position [
		"assignment_id"
	] = assignment_id
	canonical_position [
		"vacant_since_year"
	] = -1
	canonical_position [
		"last_filled_year"
	] = int(gs.year)

	positions [
		position_id
	] = canonical_position
	state ["positions"] = positions

	var index: Dictionary = _safe_dictionary(
		state.get(
			"actor_assignment_index",
			{}
		)
	)
	index [
		int(actor.id)
	] = assignment_id
	state [
		"actor_assignment_index"
	] = index

	var profile: Dictionary = ensure_actor_profile(
		actor
	)
	profile [
		"current_assignment_id"
	] = assignment_id
	var history: Array = _safe_array(
		profile.get(
			"career_history",
			[]
		)
	)
	history.append({
		"event": transition_event,
		"year": int(gs.year),
		"organization_id": str(
			assignment.get(
				"organization_id",
				""
			)
		),
		"organization_name": str(
			organization.get(
				"name",
				"Institution"
			)
		),
		"path_id": path_id,
		"rank_index": rank_index,
		"rank_title": str(
			assignment.get(
				"rank_title",
				"Career"
			)
		),
		"position_id": position_id,
		"constitutional_office_transition": (
			presidential_election
		),
		"selection_method": (
			"popular_election"
			if presidential_election
			else "employment"
		)
	})
	profile ["career_history"] = history
	actor.career_profile = profile

	_sync_legacy_fields(
		actor,
		assignment
	)
	_register_with_workplace(
		actor,
		assignment,
		organization
	)
	_sync_state_back(state)

	var event_context: Dictionary = (
		context.duplicate(true)
	)

	if presidential_election:
		event_context [
			"constitutional_office_transition"
		] = true
		event_context [
			"selection_method"
		] = "popular_election"
		event_context [
			"country"
		] = "United States"
		event_context [
			"office"
		] = "President of the United States"

	_record_world_event(
		transition_event_name,
		actor,
		assignment,
		event_context
	)




	_emit_event(
		ActionEventTypes.JOB_HIRED,
		actor,
		assignment,
		event_context
	)

	var text: String = ""

	if presidential_election:
		text = (
			"I was elected as President of the United States "
			+ "by the American people."
		)
	else:
		text = (
			"I was hired as %s at %s."
			% [
				str(
					assignment.get(
						"rank_title",
						"Career"
					)
				),
				str(
					organization.get(
						"name",
						"an institution"
					)
				)
			]
		)

	_log_narrative(
		actor,
		text,
		transition_event_name
	)

	return {
		"success": true,
		"type": transition_event_name,
		"text": text,
		"assignment": assignment,
		"position": canonical_position,
		"organization": organization,
		"constitutional_office_transition": (
			presidential_election
		),
		"selection_method": (
			"popular_election"
			if presidential_election
			else "employment"
		),
		"reality_mutated": true
	}

func commit_activity(
	actor: Person,
	activity: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	if activity.is_empty():
		return _fail(
			"activity_not_found",
			context
		)

	var state: Dictionary = _ensure_state_shape()

	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)

	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)

	var current: Dictionary = _safe_dictionary(
		assignments.get(
			assignment_id,
			assignment
		)
	)

	var activity_id: String = str(
		activity.get(
			"id",
			"professional_activity"
		)
	).strip_edges().to_lower()

	var productive_limit: int = maxi(
		1,
		int(
			activity.get(
				"productive_uses_per_year",
				3
			)
		)
	)

	var usage_by_year: Dictionary = _safe_dictionary(
		current.get(
			"activity_usage_by_year",
			{}
		)
	)

	var year_key: String = str(
		int(
			gs.year
		)
	)

	var year_usage: Dictionary = _safe_dictionary(
		usage_by_year.get(
			year_key,
			usage_by_year.get(
				int(
					gs.year
				),
				{}
			)
		)
	)

	var uses_before: int = maxi(
		0,
		int(
			year_usage.get(
				activity_id,
				0
			)
		)
	)

	var productive_effects_applied: bool = (
		uses_before < productive_limit
	)

	var use_number: int = uses_before + 1

	year_usage [
		activity_id
	] = use_number

	usage_by_year [
		year_key
	] = year_usage

	current [
		"activity_usage_by_year"
	] = usage_by_year

	var performance_delta: int = int(
		activity.get(
			"performance_delta",
			0
		)
	)

	var stress_delta: float = float(
		activity.get(
			"stress_delta",
			0.0
		)
	)

	var satisfaction_delta: int = int(
		activity.get(
			"satisfaction_delta",
			0
		)
	)

	if productive_effects_applied:
		match str(
			context.get(
				"intensity",
				"normal"
			)
		).to_lower():
			"hard":
				performance_delta += 4
				stress_delta += 6.0
				satisfaction_delta -= 2

			"slack":
				performance_delta -= 10
				stress_delta -= 2.0
				satisfaction_delta += 2

			_:
				pass

	else:
		performance_delta = 0
		stress_delta = 0.0
		satisfaction_delta = 0

	var quality: int = 0

	if productive_effects_applied:
		quality = clampi(
			int(
				float(
					actor.smarts
				) / 10.0
			)
			+ int(
				float(
					actor.health
				) / 20.0
			)
			+ int(
				float(
					current.get(
						"performance",
						50
					)
				) / 10.0
			)
			+ randi_range(
				-5,
				5
			),
			-10,
			20
		)

		performance_delta += int(
			round(
				float(
					quality
				) * 0.25
			)
		)

	current ["performance"] = clampi(
		int(
			current.get(
				"performance",
				50
			)
		) + performance_delta,
		0,
		100
	)

	current ["work_stress"] = clampf(
		float(
			current.get(
				"work_stress",
				0.0
			)
		) + stress_delta,
		0.0,
		100.0
	)

	current ["satisfaction"] = clampi(
		int(
			current.get(
				"satisfaction",
				50
			)
		) + satisfaction_delta,
		0,
		100
	)

	if productive_effects_applied:
		current ["experience"] = int(
			current.get(
				"experience",
				0
			)
		) + 1

	current ["last_activity_id"] = activity_id
	current ["last_activity_year"] = int(
		gs.year
	)
	current [
		"last_activity_productive_effects_applied"
	] = productive_effects_applied

	var activity_history: Array = _safe_array(
		current.get(
			"activity_history",
			[]
		)
	)

	activity_history.append({
		"activity_id": activity_id,
		"label": str(
			activity.get(
				"label",
				"Professional Activity"
			)
		),
		"year": int(
			gs.year
		),
		"use_number": use_number,
		"productive_limit": productive_limit,
		"productive_effects_applied": (
			productive_effects_applied
		),
		"performance_delta": performance_delta,
		"stress_delta": stress_delta,
		"satisfaction_delta": satisfaction_delta,
		"quality": quality
	})

	while activity_history.size() > 80:
		activity_history.pop_front()

	current ["activity_history"] = activity_history

	assignments [
		assignment_id
	] = current

	state ["assignments"] = assignments

	var profile: Dictionary = ensure_actor_profile(
		actor
	)

	var reputation: Dictionary = (
		_normalized_reputation(
			_safe_dictionary(
				profile.get(
					"professional_reputation",
					{}
				)
			)
		)
	)

	var reputation_delta: Dictionary = {}

	if productive_effects_applied:
		reputation_delta = _safe_dictionary(
			activity.get(
				"reputation_delta",
				{}
			)
		)

	for axis in reputation_delta.keys():
		reputation [
			str(
				axis
			)
		] = clampi(
			int(
				reputation.get(
					str(
						axis
					),
					50
				)
			)
			+ int(
				reputation_delta.get(
					axis,
					0
				)
			),
			0,
			100
		)

	profile [
		"professional_reputation"
	] = reputation

	profile [
		"professional_reputation_score"
	] = _reputation_score(
		reputation
	)

	var legacy: Dictionary = _normalized_legacy(
		_safe_dictionary(
			profile.get(
				"legacy",
				{}
			)
		)
	)

	var legacy_metric: String = str(
		activity.get(
			"legacy_metric",
			""
		)
	)

	if (
		productive_effects_applied
		and legacy_metric != ""
	):
		legacy [
			legacy_metric
		] = maxi(
			0,
			int(
				legacy.get(
					legacy_metric,
					0
				)
			)
			+ int(
				activity.get(
					"legacy_delta",
					0
				)
			)
		)

	profile ["legacy"] = legacy
	actor.career_profile = profile

	_sync_legacy_fields(
		actor,
		current
	)

	_sync_state_back(
		state
	)

	_record_world_event(
		"career_activity",
		actor,
		current,
		{
			"activity": activity,
			"use_number": use_number,
			"productive_limit": productive_limit,
			"productive_effects_applied": (
				productive_effects_applied
			),
			"source": str(
				context.get(
					"source",
					"career_activity"
				)
			)
		}
	)

	_emit_event(
		ActionEventTypes.JOB_WORKED,
		actor,
		current,
		context
	)

	var text: String = ""

	if productive_effects_applied:
		text = (
			"I completed %s. Performance is now %d."
			% [
				str(
					activity.get(
						"label",
						"professional work"
					)
				),
				int(
					current.get(
						"performance",
						50
					)
				)
			]
		)

	else:
		text = (
			"I completed %s again, but it no longer changed "
			+ "my professional stats this year."
		) % str(
			activity.get(
				"label",
				"professional work"
			)
		)

	_log_narrative(
		actor,
		text,
		"career_activity"
	)

	return {
		"success": true,
		"type": "career_activity_completed",
		"text": text,
		"assignment": current,
		"professional_reputation": reputation,
		"legacy": legacy,
		"activity_id": activity_id,
		"use_number": use_number,
		"productive_limit": productive_limit,
		"productive_uses_remaining": maxi(
			0,
			productive_limit - use_number
		),
		"productive_effects_applied": (
			productive_effects_applied
		),
		"reality_mutated": true
	}
func commit_professional_interaction(
	actor: Person,
	interaction: Dictionary
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			interaction
		)

	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			interaction
		)

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)
	var current: Dictionary = _safe_dictionary(
		assignments.get(
			assignment_id,
			assignment
		)
	)
	var performance_delta: int = int(
		interaction.get(
			"performance_delta",
			0
		)
	)
	var satisfaction_delta: int = int(
		interaction.get(
			"satisfaction_delta",
			0
		)
	)
	var stress_delta: float = float(
		interaction.get(
			"stress_delta",
			0.0
		)
	)

	current ["performance"] = clampi(
		int(
			current.get(
				"performance",
				actor.job_performance
			)
		)
		+ performance_delta,
		0,
		100
	)
	current ["satisfaction"] = clampi(
		int(
			current.get(
				"satisfaction",
				actor.satisfaction
			)
		)
		+ satisfaction_delta,
		0,
		100
	)
	current ["work_stress"] = clampf(
		float(
			current.get(
				"work_stress",
				actor.work_stress
			)
		)
		+ stress_delta,
		0.0,
		100.0
	)
	current ["last_professional_interaction_id"] = str(
		interaction.get(
			"interaction_id",
			"career_interaction"
		)
	)
	current ["last_professional_interaction_year"] = int(
		gs.year
	)

	var interaction_history: Array = _safe_array(
		current.get(
			"interaction_history",
			[]
		)
	)
	interaction_history.append({
		"interaction_id": str(
			interaction.get(
				"interaction_id",
				"career_interaction"
			)
		),
		"scenario_kind": str(
			interaction.get(
				"scenario_kind",
				"career"
			)
		),
		"target_id": int(
			interaction.get(
				"target_id",
				-1
			)
		),
		"performance_delta": performance_delta,
		"satisfaction_delta": satisfaction_delta,
		"stress_delta": stress_delta,
		"reputation_delta": _safe_dictionary(
			interaction.get(
				"reputation_delta",
				{}
			)
		),
		"relationship_delta": int(
			interaction.get(
				"relationship_delta",
				0
			)
		),
		"year": int(
			gs.year
		),
		"source": str(
			interaction.get(
				"source",
				"career_professional_interaction"
			)
		)
	})

	while interaction_history.size() > 80:
		interaction_history.pop_front()

	current ["interaction_history"] = interaction_history
	assignments [assignment_id] = current
	state ["assignments"] = assignments

	var profile: Dictionary = ensure_actor_profile(
		actor
	)
	var reputation: Dictionary = _normalized_reputation(
		_safe_dictionary(
			profile.get(
				"professional_reputation",
				{}
			)
		)
	)
	var reputation_delta: Dictionary = _safe_dictionary(
		interaction.get(
			"reputation_delta",
			{}
		)
	)

	for raw_axis in reputation_delta.keys():
		var axis: String = str(
			raw_axis
		)
		reputation [axis] = clampi(
			int(
				reputation.get(
					axis,
					0
				)
			)
			+ int(
				reputation_delta.get(
					raw_axis,
					0
				)
			),
			0,
			100
		)

	profile ["professional_reputation"] = reputation
	profile ["professional_reputation_score"] = _reputation_score(
		reputation
	)
	actor.career_profile = profile

	var target_id: int = int(
		interaction.get(
			"target_id",
			-1
		)
	)
	var relationship_delta: int = int(
		interaction.get(
			"relationship_delta",
			0
		)
	)
	var target: Person = _actor_by_id(
		target_id
	)

	if (
		target != null
		and relationship_delta != 0
		and gs != null
		and gs.relationship_engine != null
	):
		if gs.relationship_engine.has_method(
			"ensure_pair_relationship_baseline"
		):
			gs.relationship_engine.ensure_pair_relationship_baseline(
				actor,
				target
			)

		if gs.relationship_engine.has_method(
			"adjust_relationship"
		):
			gs.relationship_engine.adjust_relationship(
				actor,
				target,
				relationship_delta
			)

	_sync_legacy_fields(
		actor,
		current
	)
	_sync_state_back(
		state
	)
	_record_world_event(
		"career_professional_interaction",
		actor,
		current,
		interaction
	)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(
			"career.professional_interaction",
			{
				"actor_id": int(
					actor.id
				),
				"target_id": target_id,
				"assignment_id": assignment_id,
				"organization_id": str(
					current.get(
						"organization_id",
						""
					)
				),
				"interaction": interaction.duplicate(true),
			}
		)

	var target_name: String = (
		_actor_display_name(
			target
		)
		if target != null
		else "the workplace"
	)
	var requested_narrative_text: String = str(
		interaction.get(
			"narrative_text",
			""
		)
	).strip_edges()

	var text: String = requested_narrative_text

	if text == "":
		text = (
			"My response affected my standing with %s. "
			+ "Performance is now %d and professional reputation is %d."
		) % [
			target_name,
			int(
				current.get(
					"performance",
					actor.job_performance
				)
			),
			int(
				profile.get(
					"professional_reputation_score",
					50
				)
			)
		]

	_log_narrative(
		actor,
		text,
		"career_professional_interaction"
	)

	return {
		"success": true,
		"type": "career_professional_interaction_committed",
		"text": text,
		"assignment": current,
		"professional_reputation": reputation,
		"professional_reputation_score": int(
			profile.get(
				"professional_reputation_score",
				50
			)
		),
		"target_id": target_id,
		"relationship_delta": relationship_delta,
		"reality_mutated": true
	}
func commit_promotion(
	actor: Person,
	vacancy: Dictionary,
	contract: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			contract
		)

	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			contract
		)

	if (
		vacancy.is_empty()
		or str(
			vacancy.get(
				"status",
				""
			)
		) != "vacant"
	):
		return _fail(
			"promotion_vacancy_unavailable",
			contract
		)

	var state: Dictionary = _ensure_state_shape()
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)
	var old_position_id: String = str(
		assignment.get(
			"position_id",
			""
		)
	)
	var new_position_id: String = str(
		vacancy.get(
			"position_id",
			""
		)
	)
	var current: Dictionary = _safe_dictionary(
		assignments.get(
			assignment_id,
			assignment
		)
	)
	var old_position: Dictionary = _safe_dictionary(
		positions.get(
			old_position_id,
			{}
		)
	)
	var new_position: Dictionary = _safe_dictionary(
		positions.get(
			new_position_id,
			vacancy
		)
	)

	if str(
		new_position.get(
			"status",
			""
		)
	) != "vacant":
		return _fail(
			"promotion_vacancy_unavailable",
			contract
		)

	old_position ["status"] = "vacant"
	old_position ["occupant_actor_id"] = -1
	old_position ["assignment_id"] = ""
	old_position ["vacant_since_year"] = int(gs.year)
	positions [
		old_position_id
	] = old_position

	current ["position_id"] = new_position_id
	current ["department_id"] = str(
		new_position.get(
			"department_id",
			""
		)
	)
	current ["department_name"] = str(
		new_position.get(
			"department_name",
			current.get(
				"department_name",
				"General"
			)
		)
	)
	current ["rank_index"] = int(
		new_position.get(
			"rank_index",
			0
		)
	)
	current ["rank_title"] = str(
		new_position.get(
			"rank_title",
			"Career"
		)
	)
	current ["salary"] = maxi(
		int(
			current.get(
				"salary",
				0
			)
		) + 1,
		int(
			new_position.get(
				"salary",
				0
			)
		)
	)
	current ["last_review_year"] = int(gs.year)

	var promotion_history: Array = _safe_array(
		current.get(
			"promotion_history",
			[]
		)
	)
	promotion_history.append({
		"year": int(gs.year),
		"from_position_id": old_position_id,
		"to_position_id": new_position_id,
		"to_rank_index": int(
			current.get(
				"rank_index",
				0
			)
		),
		"to_rank_title": str(
			current.get(
				"rank_title",
				"Career"
			)
		),
		"promotion_score": int(
			contract.get(
				"review_score",
				0
			)
		)
	})
	current [
		"promotion_history"
	] = promotion_history

	assignments [
		assignment_id
	] = current
	state ["assignments"] = assignments

	new_position ["status"] = "filled"
	new_position [
		"occupant_actor_id"
	] = int(actor.id)
	new_position [
		"assignment_id"
	] = assignment_id
	new_position [
		"vacant_since_year"
	] = -1
	new_position [
		"last_filled_year"
	] = int(gs.year)

	positions [
		new_position_id
	] = new_position
	state ["positions"] = positions

	var profile: Dictionary = ensure_actor_profile(
		actor
	)
	var history: Array = _safe_array(
		profile.get(
			"career_history",
			[]
		)
	)
	history.append({
		"event": "promoted",
		"year": int(gs.year),
		"path_id": str(
			current.get(
				"path_id",
				""
			)
		),
		"rank_index": int(
			current.get(
				"rank_index",
				0
			)
		),
		"rank_title": str(
			current.get(
				"rank_title",
				"Career"
			)
		),
		"organization_id": str(
			current.get(
				"organization_id",
				""
			)
		)
	})
	profile ["career_history"] = history

	var reputation: Dictionary = _normalized_reputation(
		_safe_dictionary(
			profile.get(
				"professional_reputation",
				{}
			)
		)
	)
	reputation ["leadership"] = clampi(
		int(
			reputation.get(
				"leadership",
				50
			)
		) + 4,
		0,
		100
	)
	reputation ["reliability"] = clampi(
		int(
			reputation.get(
				"reliability",
				50
			)
		) + 2,
		0,
		100
	)

	profile [
		"professional_reputation"
	] = reputation
	profile [
		"professional_reputation_score"
	] = _reputation_score(
		reputation
	)
	actor.career_profile = profile

	_sync_legacy_fields(
		actor,
		current
	)
	_sync_state_back(state)

	_record_world_event(
		"career_promoted",
		actor,
		current,
		contract
	)
	_emit_event(
		ActionEventTypes.JOB_PROMOTED,
		actor,
		current,
		contract
	)

	var text: String = (
		"I was promoted to %s."
		% str(
			current.get(
				"rank_title",
				"a higher rank"
			)
		)
	)

	_log_narrative(
		actor,
		text,
		"career_promoted"
	)

	return {
		"success": true,
		"type": "career_promotion_committed",
		"text": text,
		"assignment": current,
		"old_position": old_position,
		"new_position": new_position,
		"reality_mutated": true
	}


func commit_raise(
	actor: Person,
	new_salary: int,
	context: Dictionary = {}
) -> Dictionary:
	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)
	var current: Dictionary = _safe_dictionary(
		assignments.get(
			assignment_id,
			assignment
		)
	)
	var previous_salary: int = int(
		current.get(
			"salary",
			actor.income
		)
	)

	current ["salary"] = maxi(
		previous_salary,
		new_salary
	)
	current ["last_raise_year"] = int(gs.year)
	assignments [
		assignment_id
	] = current
	state ["assignments"] = assignments

	_sync_legacy_fields(
		actor,
		current
	)
	_sync_state_back(state)

	_record_world_event(
		"career_raise",
		actor,
		current,
		context
	)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.JOB_RAISE_GRANTED,
			{
				"npc": actor,
				"npc_id": int(actor.id),
				"job": str(
					current.get(
						"rank_title",
						actor.job
					)
				),
				"previous_salary": previous_salary,
				"new_salary": int(
					current.get(
						"salary",
						previous_salary
					)
				),
			}
		)

	var text: String = (
		"My salary increased from %d to %d."
		% [
			previous_salary,
			int(
				current.get(
					"salary",
					previous_salary
				)
			)
		]
	)

	_log_narrative(
		actor,
		text,
		"career_raise"
	)

	return {
		"success": true,
		"type": "career_raise_committed",
		"text": text,
		"previous_salary": previous_salary,
		"new_salary": int(
			current.get(
				"salary",
				previous_salary
			)
		),
		"assignment": current,
		"reality_mutated": true
	}


func commit_quit(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	return _vacate_actor_position(
		actor,
		"quit",
		context
	)


func commit_retirement(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _vacate_actor_position(
		actor,
		"retired",
		context
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		actor.job = "Retired"
		actor.income = 0

	return result


func yearly_tick(
	payload:= {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0,
			"reason": "missing_game_state"
		}

	var state: Dictionary = _ensure_state_shape()
	var target_year: int = int(
		(
			payload as Dictionary
			if typeof(payload) == TYPE_DICTIONARY
			else {}
		).get(
			"year",
			gs.year
		)
	)

	var job_raw: Variant = state.get(
		"yearly_runtime_job",
		{}
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		not job.is_empty()
		and int(
			job.get(
				"year",
				-1
			)
		) == target_year
		and not bool(
			job.get(
				"is_complete",
				false
			)
		)
	):
		return {
			"success": true,
			"schema": (
				"eralife.career_yearly_job_declaration"
			),
			"year": target_year,
			"is_complete": false,
			"progress": float(
				job.get(
					"progress",
					0.0
				)
			),
			"execution_model": "incremental",
			"blocks_ui": false
		}

	var population_snapshot_size: int = (
		gs.npcs.size()
		if typeof(gs.npcs) == TYPE_ARRAY
		else 0
	)

	job = {
		"schema": (
			"eralife.career_runtime_yearly_job"
		),
		"version": 1,
		"year": target_year,
		"stage": "player",
		"player_processed": false,
		"npc_cursor": 0,
		"npc_population_snapshot_size": (
			population_snapshot_size
		),
		"processed_people": 0,
		"promoted": 0,
		"retired": 0,
		"fired": 0,
		"quit": 0,
		"hired": 0,
		"is_complete": false,
		"progress": 0.0,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"execution_model": "incremental",
		"ui_concurrent": true,
		"idle_required": false,
		"blocks_ui": false
	}

	state [
		"yearly_runtime_job"
	] = job
	_sync_state_back(
		state
	)

	return {
		"success": true,
		"schema": (
			"eralife.career_yearly_job_declaration"
		),
		"year": target_year,
		"is_complete": false,
		"progress": 0.0,
		"execution_model": "incremental",
		"blocks_ui": false
	}
func service_yearly_quantum(
	payload:= {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0,
			"reason": "missing_game_state"
		}

	var runtime_payload: Dictionary = (
		payload as Dictionary
		if typeof(payload) == TYPE_DICTIONARY
		else {}
	)
	var target_year: int = int(
		runtime_payload.get(
			"year",
			gs.year
		)
	)

	var state: Dictionary = _ensure_state_shape()
	var job_raw: Variant = state.get(
		"yearly_runtime_job",
		{}
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		job.is_empty()
		or int(
			job.get(
				"year",
				-1
			)
		) != target_year
	):
		yearly_tick({
			"year": target_year,
			"source": (
				"career_runtime_engine.service_yearly_quantum"
			)
		})

		state = _ensure_state_shape()
		job_raw = state.get(
			"yearly_runtime_job",
			{}
		)
		job = (
			job_raw as Dictionary
			if typeof(job_raw) == TYPE_DICTIONARY
			else {}
		)

	if job.is_empty():
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0,
			"reason": "yearly_job_could_not_be_declared"
		}

	if bool(
		job.get(
			"is_complete",
			false
		)
	):
		return {
			"success": true,
			"is_complete": true,
			"progress": 1.0,
			"year": target_year,
			"execution_model": "incremental",
			"blocks_ui": false
		}

	var stage: String = str(
		job.get(
			"stage",
			"player"
		)
	)

	if stage == "player":
		if (
			not bool(
				job.get(
					"player_processed",
					false
				)
			)
			and gs.player != null
			and gs.player.alive
		):
			var player_report: Dictionary = (
				simulate_actor_year(
					gs.player,
					{
						"source": (
							"career_runtime_engine.yearly_quantum"
						),
						"bounded_runtime": true
					}
				)
			)

			job ["processed_people"] = int(
				job.get(
					"processed_people",
					0
				)
			) + 1
			job ["promoted"] = int(
				job.get(
					"promoted",
					0
				)
			) + int(
				player_report.get(
					"promoted",
					0
				)
			)
			job ["retired"] = int(
				job.get(
					"retired",
					0
				)
			) + int(
				player_report.get(
					"retired",
					0
				)
			)
			job ["fired"] = int(
				job.get(
					"fired",
					0
				)
			) + int(
				player_report.get(
					"fired",
					0
				)
			)
			job ["quit"] = int(
				job.get(
					"quit",
					0
				)
			) + int(
				player_report.get(
					"quit",
					0
				)
			)

		job ["player_processed"] = true
		job ["stage"] = "npcs"

	elif stage == "npcs":
		var snapshot_size: int = mini(
			int(
				job.get(
					"npc_population_snapshot_size",
					0
				)
			),
			gs.npcs.size()
		)
		var cursor: int = int(
			job.get(
				"npc_cursor",
				0
			)
		)

		if cursor < snapshot_size:
			var actor = gs.npcs [
				cursor
			]
			job ["npc_cursor"] = cursor + 1

			if (
				actor != null
				and actor.alive
				and (
					gs.player == null
					or int(actor.id)
					!= int(gs.player.id)
				)
			):
				var npc_report: Dictionary = (
					simulate_actor_year(
						actor,
						{
							"source": (
								"career_runtime_engine.yearly_quantum"
							),
							"bounded_runtime": true
						}
					)
				)

				job ["processed_people"] = int(
					job.get(
						"processed_people",
						0
					)
				) + 1
				job ["retired"] = int(
					job.get(
						"retired",
						0
					)
				) + int(
					npc_report.get(
						"retired",
						0
					)
				)
				job ["fired"] = int(
					job.get(
						"fired",
						0
					)
				) + int(
					npc_report.get(
						"fired",
						0
					)
				)
				job ["quit"] = int(
					job.get(
						"quit",
						0
					)
				) + int(
					npc_report.get(
						"quit",
						0
					)
				)

		else:
			job ["stage"] = "complete"

	if str(
		job.get(
			"stage",
			""
		)
	) == "complete":
		job ["is_complete"] = true
		job ["progress"] = 1.0
		job ["completed_at_ms"] = int(
			Time.get_ticks_msec()
		)

		last_runtime_report = {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"processed_people": int(
				job.get(
					"processed_people",
					0
				)
			),
			"promoted": int(
				job.get(
					"promoted",
					0
				)
			),
			"retired": int(
				job.get(
					"retired",
					0
				)
			),
			"fired": int(
				job.get(
					"fired",
					0
				)
			),
			"quit": int(
				job.get(
					"quit",
					0
				)
			),
			"year": target_year,
			"execution_model": "incremental",
			"ui_concurrent": true,
			"blocks_ui": false
		}

	else:
		var snapshot_total: int = maxi(
			1,
			int(
				job.get(
					"npc_population_snapshot_size",
					0
				)
			) + 1
		)
		var completed_people: int = (
			int(
				job.get(
					"npc_cursor",
					0
				)
			)
			+ (
				1
				if bool(
					job.get(
						"player_processed",
						false
					)
				)
				else 0
			)
		)

		job ["progress"] = clampf(
			float(completed_people)
			/ float(snapshot_total),
			0.0,
			0.999
		)

	state [
		"yearly_runtime_job"
	] = job
	_sync_state_back(
		state
	)

	return {
		"success": true,
		"schema": (
			"eralife.career_runtime_yearly_quantum"
		),
		"year": target_year,
		"stage": str(
			job.get(
				"stage",
				""
			)
		),
		"is_complete": bool(
			job.get(
				"is_complete",
				false
			)
		),
		"progress": float(
			job.get(
				"progress",
				0.0
			)
		),
		"processed_people": int(
			job.get(
				"processed_people",
				0
			)
		),
		"execution_model": "incremental",
		"ui_concurrent": true,
		"idle_required": false,
		"blocks_ui": false
	}
func _resident_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(
		gs.career_ecosystem_state
	) == TYPE_DICTIONARY:
		var state: Dictionary = (
			gs.career_ecosystem_state as Dictionary
		)

		if not state.is_empty():
			return state

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		var state_raw: Variant = (
			gs.scenario_state.get(
				STATE_KEY,
				{}
			)
		)

		if typeof(state_raw) == TYPE_DICTIONARY:
			return state_raw as Dictionary

	return {}


func _read_dictionary(
	value: Variant
) -> Dictionary:
	return (
		value as Dictionary
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _read_array(
	value: Variant
) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)


func resident_actor_profile(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var profile_raw: Variant = (
		actor.career_profile
	)

	if typeof(profile_raw) != TYPE_DICTIONARY:
		return {}

	return profile_raw as Dictionary
func on_npc_died(
	payload:= {}
) -> void:
	var actor: Person = _actor_from_payload(
		payload
	)

	if actor != null:
		_vacate_actor_position(
			actor,
			"died",
			{
				"source": (
					"career_runtime_engine.on_npc_died"
				),
				"silent": true
			}
		)


func on_era_shift(
	_payload:= {}
) -> void:
	ensure_world_ecosystem({
		"source": (
			"career_runtime_engine.on_era_shift"
		)
	})

	var contract_engine = _contract_engine()

	if contract_engine != null:
		queue_path_ecosystem_reconciliation(
			contract_engine.career_paths.keys(),
			{
				"source": (
					"career_runtime_engine."
					+ "era_shift_background_staffing"
				),
				"background_only": true,
				"blocks_ui": false,
				"ready_gate_member": false
			}
		)

	queue_legacy_job_reconciliation(
		_active_people(),
		{
			"source": (
				"career_runtime_engine."
				+ "era_shift_legacy_job_reconciliation"
			),
			"background_only": true,
			"blocks_ui": false,
			"ready_gate_member": false
		}
	)
func ensure_vacant_position_for_path(
	path_id: String,
	rank_index: int = 0,
	allow_overflow: bool = false
) -> Dictionary:
	return _find_or_create_vacant_position(
		path_id,
		rank_index,
		allow_overflow
	)


func _ensure_organization_for_path(
	path: Dictionary
) -> Dictionary:
	var path_id: String = str(
		path.get(
			"path_id",
			""
		)
	).strip_edges()

	if path_id == "":
		return {
			"created_organizations": 0,
			"created_departments": 0,
			"created_positions": 0
		}

	var state: Dictionary = _ensure_state_shape()
	var organizations: Dictionary = _safe_dictionary(
		state.get(
			"organizations",
			{}
		)
	)
	var departments: Dictionary = _safe_dictionary(
		state.get(
			"departments",
			{}
		)
	)
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var era_name: String = _current_era_name()
	var organization_key: String = str(
		path.get(
			"organization_key",
			path.get(
				"institution",
				path_id
			)
		)
	).strip_edges()
	var organization_id: String = (
		"career_org::%s::%s"
		% [
			_slug(
				era_name
			),
			_slug(
				organization_key
			)
		]
	)
	var department_name: String = str(
		path.get(
			"department",
			"General"
		)
	).strip_edges()
	var department_id: String = (
		"%s::department::%s"
		% [
			organization_id,
			_slug(
				department_name
			)
		]
	)
	var created_organizations: int = 0
	var created_departments: int = 0
	var created_positions: int = 0
	var organization: Dictionary = _safe_dictionary(
		organizations.get(
			organization_id,
			{}
		)
	)

	if organization.is_empty():
		organization = {
			"organization_id": organization_id,
			"name": organization_key,
			"organization_type": str(
				path.get(
					"organization_type",
					"institution"
				)
			),
			"era_name": era_name,
			"active": true,
			"created_year": int(
				gs.year
			),
			"path_ids": [],
			"department_ids": [],
			"stability": 72,
			"prestige": 50,
			"vacancy_rate": 0.0,
			"history": []
		}
		created_organizations = 1

	var organization_path_ids: Array = _safe_array(
		organization.get(
			"path_ids",
			[]
		)
	)

	if path_id not in organization_path_ids:
		organization_path_ids.append(
			path_id
		)

	organization [
		"path_ids"
	] = organization_path_ids

	var organization_department_ids: Array = _safe_array(
		organization.get(
			"department_ids",
			[]
		)
	)

	if department_id not in organization_department_ids:
		organization_department_ids.append(
			department_id
		)

	organization [
		"department_ids"
	] = organization_department_ids
	organizations [
		organization_id
	] = organization

	var department: Dictionary = _safe_dictionary(
		departments.get(
			department_id,
			{}
		)
	)

	if department.is_empty():
		department = {
			"department_id": department_id,
			"organization_id": organization_id,
			"name": department_name,
			"active": true,
			"created_year": int(
				gs.year
			),
			"path_ids": [],
			"position_ids": []
		}
		created_departments = 1

	var department_path_ids: Array = _safe_array(
		department.get(
			"path_ids",
			[]
		)
	)

	if path_id not in department_path_ids:
		department_path_ids.append(
			path_id
		)

	department [
		"path_ids"
	] = department_path_ids

	var department_position_ids: Array = _safe_array(
		department.get(
			"position_ids",
			[]
		)
	)
	var ranks: Array = _safe_array(
		path.get(
			"ranks",
			[]
		)
	)

	for rank_index in range(
		ranks.size()
	):
		var rank: Dictionary = _safe_dictionary(
			ranks [
				rank_index
			]
		)
		var capacity: int = maxi(
			1,
			int(
				rank.get(
					"capacity",
					1
				)
			)
		)

		for slot_index in range(
			capacity
		):
			var position_id: String = (
				"%s::path::%s::rank::%d::slot::%d"
				% [
					department_id,
					_slug(
						path_id
					),
					rank_index,
					slot_index
				]
			)

			if not positions.has(
				position_id
			):
				positions [
					position_id
				] = {
					"position_id": position_id,
					"organization_id": organization_id,
					"department_id": department_id,
					"department_name": department_name,
					"path_id": path_id,
					"rank_index": rank_index,
					"rank_title": str(
						rank.get(
							"title",
							path.get(
								"display_name",
								"Career"
							)
						)
					),
					"capacity_slot": slot_index,
					"status": "vacant",
					"occupant_actor_id": -1,
					"assignment_id": "",
					"salary": _salary_for_position(
						path,
						rank
					),
					"competition": clampi(
						48
						+ rank_index * 8
						+ (
							8
							if bool(
								path.get(
									"special_path",
									false
								)
							)
							else 0
						),
						35,
						92
					),
					"accepting_applications": true,
					"created_year": int(
						gs.year
					),
					"vacant_since_year": int(
						gs.year
					),
					"last_filled_year": -1,
					"special_path": bool(
						path.get(
							"special_path",
							false
						)
					),
				}
				created_positions += 1

			if position_id not in department_position_ids:
				department_position_ids.append(
					position_id
				)

	department [
		"position_ids"
	] = department_position_ids
	departments [
		department_id
	] = department
	state ["organizations"] = organizations
	state ["departments"] = departments
	state ["positions"] = positions

	_sync_state_back(
		state
	)

	return {
		"created_organizations": created_organizations,
		"created_departments": created_departments,
		"created_positions": created_positions,
		"organization_id": organization_id,
		"department_id": department_id
	}


func _find_or_create_vacant_position(
	path_id: String,
	rank_index: int,
	allow_overflow: bool
) -> Dictionary:
	var state: Dictionary = _ensure_state_shape()
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)

	for raw_position in positions.values():
		var position: Dictionary = _safe_dictionary(
			raw_position
		)

		if str(
			position.get(
				"path_id",
				""
			)
		) != path_id:
			continue

		if int(
			position.get(
				"rank_index",
				-1
			)
		) != rank_index:
			continue

		if str(
			position.get(
				"status",
				""
			)
		) == "vacant":
			return position

	var path: Dictionary = {}

	if _contract_engine() != null:
		path = (
			_contract_engine()
			.get_path_definition(
				path_id
			)
		)

	if path.is_empty():
		return {}

	_ensure_organization_for_path(
		path
	)

	state = _ensure_state_shape()
	positions = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)

	for raw_position in positions.values():
		var position: Dictionary = _safe_dictionary(
			raw_position
		)

		if (
			str(
				position.get(
					"path_id",
					""
				)
			) == path_id
			and int(
				position.get(
					"rank_index",
					-1
				)
			) == rank_index
			and str(
				position.get(
					"status",
					""
				)
			) == "vacant"
		):
			return position

	if not allow_overflow:
		return {}

	var ranks: Array = _safe_array(
		path.get(
			"ranks",
			[]
		)
	)

	if (
		rank_index < 0
		or rank_index >= ranks.size()
	):
		return {}

	var rank: Dictionary = _safe_dictionary(
		ranks [
			rank_index
		]
	)
	var organization_report: Dictionary = (
		_ensure_organization_for_path(
			path
		)
	)
	var organization_id: String = str(
		organization_report.get(
			"organization_id",
			""
		)
	)
	var department_id: String = str(
		organization_report.get(
			"department_id",
			""
		)
	)
	var department: Dictionary = department_by_id(
		department_id
	)
	var overflow_index: int = 0
	var position_id: String = ""

	while true:
		position_id = (
			"%s::path::%s::rank::%d::overflow::%d"
			% [
				department_id,
				_slug(
					path_id
				),
				rank_index,
				overflow_index
			]
		)

		if not positions.has(
			position_id
		):
			break

		overflow_index += 1

	var overflow_position: Dictionary = {
		"position_id": position_id,
		"organization_id": organization_id,
		"department_id": department_id,
		"department_name": str(
			path.get(
				"department",
				"General"
			)
		),
		"path_id": path_id,
		"rank_index": rank_index,
		"rank_title": str(
			rank.get(
				"title",
				path.get(
					"display_name",
					"Career"
				)
			)
		),
		"capacity_slot": overflow_index,
		"status": "vacant",
		"occupant_actor_id": -1,
		"assignment_id": "",
		"salary": _salary_for_position(
			path,
			rank
		),
		"competition": clampi(
			48 + rank_index * 8,
			35,
			92
		),
		"accepting_applications": true,
		"created_year": int(
			gs.year
		),
		"vacant_since_year": int(
			gs.year
		),
		"last_filled_year": -1,
	}

	positions [
		position_id
	] = overflow_position
	state ["positions"] = positions

	var departments: Dictionary = _safe_dictionary(
		state.get(
			"departments",
			{}
		)
	)
	var canonical_department: Dictionary = _safe_dictionary(
		departments.get(
			department_id,
			department
		)
	)
	var position_ids: Array = _safe_array(
		canonical_department.get(
			"position_ids",
			[]
		)
	)

	position_ids.append(
		position_id
	)
	canonical_department [
		"position_ids"
	] = position_ids
	departments [
		department_id
	] = canonical_department
	state ["departments"] = departments

	_sync_state_back(
		state
	)

	return overflow_position


func _register_legacy_fallback(
	actor: Person,
	job_name: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or _contract_engine() == null
	):
		return _fail(
			"legacy_fallback_unavailable",
			context
		)

	var lane: String = (
		"part_time"
		if int(actor.age) < 18
		else "full_time"
	)
	var path_id: String = (
		_contract_engine()
		.ensure_legacy_fallback_path(
			job_name,
			lane
		)
	)

	if path_id == "":
		return _fail(
			"legacy_fallback_path_unavailable",
			context
		)

	var position: Dictionary = (
		_find_or_create_vacant_position(
			path_id,
			0,
			true
		)
	)

	if position.is_empty():
		return _fail(
			"legacy_fallback_position_unavailable",
			context
		)

	return commit_hire(
		actor,
		position,
		{
			"source": str(
				context.get(
					"source",
					"legacy_fallback_hydration"
				)
			),
			"preserve_existing_income": true,
			"preserve_existing_performance": true,
			"preserve_existing_experience": true,
			"silent": true
		}
	)


func _reconcile_assignments() -> Dictionary:
	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var index: Dictionary = _safe_dictionary(
		state.get(
			"actor_assignment_index",
			{}
		)
	)
	var active_count: int = 0
	var repaired_count: int = 0

	for assignment_id_raw in assignments.keys():
		var assignment_id: String = str(
			assignment_id_raw
		)
		var assignment: Dictionary = _safe_dictionary(
			assignments.get(
				assignment_id,
				{}
			)
		)

		if not bool(
			assignment.get(
				"active",
				false
			)
		):
			continue

		var actor_id: int = int(
			assignment.get(
				"actor_id",
				-1
			)
		)
		var actor: Person = _actor_by_id(
			actor_id
		)
		var position_id: String = str(
			assignment.get(
				"position_id",
				""
			)
		)
		var position: Dictionary = _safe_dictionary(
			positions.get(
				position_id,
				{}
			)
		)

		if (
			actor == null
			or not actor.alive
			or position.is_empty()
		):
			assignment ["active"] = false
			assignment ["ended_year"] = int(
				gs.year
			)
			assignment [
				"end_reason"
			] = "reconciliation"
			assignments [
				assignment_id
			] = assignment

			index.erase(
				actor_id
			)
			index.erase(
				str(actor_id)
			)

			if not position.is_empty():
				position ["status"] = "vacant"
				position ["occupant_actor_id"] = -1
				position ["assignment_id"] = ""
				position [
					"vacant_since_year"
				] = int(
					gs.year
				)
				positions [
					position_id
				] = position

			repaired_count += 1
			continue

		index [
			actor_id
		] = assignment_id
		position ["status"] = "filled"
		position [
			"occupant_actor_id"
		] = actor_id
		position [
			"assignment_id"
		] = assignment_id
		position [
			"vacant_since_year"
		] = -1
		positions [
			position_id
		] = position

		_sync_legacy_fields(
			actor,
			assignment
		)
		_register_with_workplace(
			actor,
			assignment,
			organization_by_id(
				str(
					assignment.get(
						"organization_id",
						""
					)
				)
			)
		)

		active_count += 1

	state ["assignments"] = assignments
	state ["positions"] = positions
	state [
		"actor_assignment_index"
	] = index

	_sync_state_back(
		state
	)

	return {
		"active_assignments": active_count,
		"repaired_assignments": repaired_count
	}


func _reconcile_vacancies() -> Dictionary:
	var state: Dictionary = _ensure_state_shape()
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var repaired_count: int = 0
	var vacant_count: int = 0

	for position_id_raw in positions.keys():
		var position_id: String = str(
			position_id_raw
		)
		var position: Dictionary = _safe_dictionary(
			positions.get(
				position_id,
				{}
			)
		)
		var assignment_id: String = str(
			position.get(
				"assignment_id",
				""
			)
		)
		var assignment: Dictionary = _safe_dictionary(
			assignments.get(
				assignment_id,
				{}
			)
		)
		var actor_id: int = int(
			position.get(
				"occupant_actor_id",
				-1
			)
		)
		var actor: Person = _actor_by_id(
			actor_id
		)
		var should_be_filled: bool = (
			assignment_id != ""
			and not assignment.is_empty()
			and bool(
				assignment.get(
					"active",
					false
				)
			)
			and actor != null
			and actor.alive
		)

		if should_be_filled:
			if str(
				position.get(
					"status",
					""
				)
			) != "filled":
				repaired_count += 1

			position ["status"] = "filled"
			position [
				"vacant_since_year"
			] = -1
		else:
			if str(
				position.get(
					"status",
					""
				)
			) != "vacant":
				repaired_count += 1

			position ["status"] = "vacant"
			position ["occupant_actor_id"] = -1
			position ["assignment_id"] = ""

			if int(
				position.get(
					"vacant_since_year",
					-1
				)
			) < 0:
				position [
					"vacant_since_year"
				] = int(
					gs.year
				)

			vacant_count += 1

		positions [
			position_id
		] = position

	state ["positions"] = positions

	_sync_state_back(
		state
	)

	return {
		"vacant_positions": vacant_count,
		"repaired_positions": repaired_count
	}


func simulate_actor_year(
	actor: Person,
	_context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"promoted": 0,
		"retired": 0,
		"fired": 0,
		"quit": 0,
		"hired": 0,
		"employment_search_pending": false,
		"promotion_review_pending": false,
		"blocks_ui": false
	}

	if (
		actor == null
		or not actor.alive
	):
		return report

	var assignment: Dictionary = (
		assignment_for_actor(
			actor
		)
	)




	if (
		assignment.is_empty()
		and str(
			actor.job
		).strip_edges() != ""
		and str(
			actor.job
		) != "Retired"
	):
		report [
			"legacy_hydration_pending"
		] = true
		return report



	if assignment.is_empty():
		if (
			actor != gs.player
			and int(actor.age) >= 14
		):
			report [
				"employment_search_pending"
			] = true

		return report

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _read_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)

	var current_raw: Variant = assignments.get(
		assignment_id,
		assignment
	)
	var current: Dictionary = (
		(current_raw as Dictionary).duplicate(false)
		if typeof(current_raw) == TYPE_DICTIONARY
		else assignment.duplicate(false)
	)

	var weekly_hours: int = clampi(
		int(
			current.get(
				"weekly_hours",
				40
			)
		),
		1,
		84
	)

	var performance_drift: int = (
		_stable_runtime_roll(
			"performance|%d|%d|%s"
			% [
				int(actor.id),
				int(gs.year),
				assignment_id
			],
			-4,
			5
		)
	)

	performance_drift += int(
		round(
			(
				float(actor.smarts)
				- 50.0
			)
			/ 25.0
		)
	)

	performance_drift -= int(
		round(
			float(
				current.get(
					"work_stress",
					0.0
				)
			)
			/ 35.0
		)
	)



	var hours_performance_delta: int = clampi(
		int(
			round(
				(
					float(weekly_hours)
					- 30.0
				)
				/ 5.0
			)
		),
		-4,
		6
	)

	performance_drift += (
		hours_performance_delta
	)

	var effort_mode: String = str(
		current.get(
			"next_year_effort_mode",
			""
		)
	).strip_edges().to_lower()
	var effort_year: int = int(
		current.get(
			"next_year_effort_year",
			-1
		)
	)
	var work_harder_applied: bool = (
		effort_mode == "hard"
		and effort_year <= int(
			gs.year
		)
	)

	if work_harder_applied:
		performance_drift += 6

	current ["experience"] = int(
		current.get(
			"experience",
			0
		)
	) + 1

	current ["performance"] = clampi(
		int(
			current.get(
				"performance",
				50
			)
		) + performance_drift,
		0,
		100
	)

	var baseline_stress_delta: float = float(
		_stable_runtime_roll(
			"stress|%d|%d"
			% [
				int(actor.id),
				int(gs.year)
			],
			-2,
			4
		)
	)

	var hours_stress_delta: float = (
		maxf(
			0.0,
			float(
				weekly_hours - 40
			)
		) * 0.55
	)

	var effort_stress_delta: float = (
		7.0
		if work_harder_applied
		else 0.0
	)

	current ["work_stress"] = clampf(
		float(
			current.get(
				"work_stress",
				0.0
			)
		)
		+ baseline_stress_delta
		+ hours_stress_delta
		+ effort_stress_delta,
		0.0,
		100.0
	)

	current ["satisfaction"] = clampi(
		int(
			current.get(
				"satisfaction",
				50
			)
		)
		+ _stable_runtime_roll(
			"satisfaction|%d|%d"
			% [
				int(actor.id),
				int(gs.year)
			],
			-3,
			3
		)
		- (
			1
			if work_harder_applied
			else 0
		),
		0,
		100
	)

	current [
		"last_review_year"
	] = int(
		gs.year
	)
	current [
		"last_hours_performance_delta"
	] = hours_performance_delta
	current [
		"last_effort_performance_delta"
	] = (
		6
		if work_harder_applied
		else 0
	)
	current [
		"last_hours_stress_delta"
	] = hours_stress_delta

	if work_harder_applied:
		current.erase(
			"next_year_effort_mode"
		)
		current.erase(
			"next_year_effort_year"
		)



	current [
		"promotion_review_pending"
	] = (
		int(
			current.get(
				"experience",
				0
			)
		) > 0
	)
	report [
		"promotion_review_pending"
	] = bool(
		current.get(
			"promotion_review_pending",
			false
		)
	)

	assignments [
		assignment_id
	] = current
	state ["assignments"] = assignments

	_sync_state_back(
		state
	)
	_sync_legacy_fields(
		actor,
		current
	)



	if (
		weekly_hours > 50
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"career_overwork_pressure",
			{
				"actor_id": int(
					actor.id
				),
				"assignment_id": assignment_id,
				"weekly_hours": weekly_hours,
				"overwork_hours": (
					weekly_hours - 50
				),
				"work_stress": float(
					current.get(
						"work_stress",
						0.0
					)
				),
				"year": int(
					gs.year
				),
				"source": (
					"career_runtime_engine"
				),
				"execution_model": (
					"constant_time"
				)
			}
		)

	var retirement_age: int = (
		_retirement_age_for_era()
	)

	if int(actor.age) >= retirement_age:
		var retirement_chance: int = clampi(
			15
			+ (
				int(actor.age)
				- retirement_age
			) * 5,
			15,
			85
		)

		if _stable_runtime_roll(
			"retire|%d|%d"
			% [
				int(actor.id),
				int(gs.year)
			],
			0,
			99
		) < retirement_chance:
			var retirement: Dictionary = (
				commit_retirement(
					actor,
					{
						"source": (
							"career_runtime_engine.simulate_actor_year"
						)
					}
				)
			)

			if bool(
				retirement.get(
					"success",
					false
				)
			):
				report ["retired"] = 1

			return report

	if int(
		current.get(
			"performance",
			50
		)
	) <= 15:
		if _stable_runtime_roll(
			"fire|%d|%d"
			% [
				int(actor.id),
				int(gs.year)
			],
			0,
			99
		) < 35:
			var firing: Dictionary = (
				_vacate_actor_position(
					actor,
					"fired",
					{
						"source": (
							"career_runtime_engine.simulate_actor_year"
						)
					}
				)
			)

			if bool(
				firing.get(
					"success",
					false
				)
			):
				report ["fired"] = 1

			return report

	if int(
		current.get(
			"satisfaction",
			50
		)
	) <= 12:
		if _stable_runtime_roll(
			"quit|%d|%d"
			% [
				int(actor.id),
				int(gs.year)
			],
			0,
			99
		) < 28:
			var quit_result: Dictionary = (
				commit_quit(
					actor,
					{
						"source": (
							"career_runtime_engine.simulate_actor_year"
						)
					}
				)
			)

			if bool(
				quit_result.get(
					"success",
					false
				)
			):
				report ["quit"] = 1

	return report

func _fill_open_positions_with_npcs(
	limit: int,
	path_id: String = "",
	scan_budget: int = (
		CAREER_STAFFING_SCAN_BUDGET_PER_QUANTUM
	)
) -> int:
	var contract_engine = _contract_engine()

	if (
		limit <= 0
		or scan_budget <= 0
		or contract_engine == null
	):
		return 0

	var clean_path_id: String = str(
		path_id
	).strip_edges()

	var state: Dictionary = _ensure_state_shape()
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)

	var available_positions: Array = []

	for raw_position in positions.values():
		var position: Dictionary = _safe_dictionary(
			raw_position
		)

		if position.is_empty():
			continue

		if str(
			position.get(
				"status",
				""
			)
		) != "vacant":
			continue

		if not bool(
			position.get(
				"accepting_applications",
				true
			)
		):
			continue

		if (
			clean_path_id != ""
			and str(
				position.get(
					"path_id",
					""
				)
			) != clean_path_id
		):
			continue

		available_positions.append(
			position
		)

	if available_positions.is_empty():
		return 0




	available_positions.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			return int(
				_safe_dictionary(
					left_raw
				).get(
					"rank_index",
					0
				)
			) > int(
				_safe_dictionary(
					right_raw
				).get(
					"rank_index",
					0
				)
			)
	)

	var candidates: Array = _active_people()

	if candidates.is_empty():
		return 0

	var cursor_key: String = (
		clean_path_id
		if clean_path_id != ""
		else "__all__"
	)

	var start_cursor: int = int(
		staffing_candidate_cursor_by_path.get(
			cursor_key,
			0
		)
	)

	start_cursor = (
		start_cursor
		% candidates.size()
	)

	var maximum_scan: int = mini(
		scan_budget,
		candidates.size()
	)

	var scanned: int = 0
	var filled: int = 0

	while (
		scanned < maximum_scan
		and filled < limit
		and not available_positions.is_empty()
	):
		var candidate_index: int = (
			(
				start_cursor
				+ scanned
			)
			% candidates.size()
		)

		scanned += 1

		var actor: Person = (
			candidates [
				candidate_index
			] as Person
		)

		if (
			actor == null
			or actor == gs.player
			or not actor.alive
		):
			continue

		if not assignment_for_actor(
			actor
		).is_empty():
			continue

		for position_index in range(
			available_positions.size()
		):
			var position: Dictionary = _safe_dictionary(
				available_positions [
					position_index
				]
			)

			var candidate_path_id: String = str(
				position.get(
					"path_id",
					""
				)
			)

			var path: Dictionary = (
				contract_engine.get_path_definition(
					candidate_path_id
				)
			)

			var rank: Dictionary = (
				contract_engine.get_rank_definition(
					candidate_path_id,
					int(
						position.get(
							"rank_index",
							0
						)
					)
				)
			)

			var eligibility: Dictionary = (
				contract_engine
				.evaluate_entry_requirements(
					actor,
					path,
					rank
				)
			)

			if not bool(
				eligibility.get(
					"eligible",
					false
				)
			):
				continue

			var result: Dictionary = (
				contract_engine.evaluate_application(
					actor,
					str(
						position.get(
							"position_id",
							""
						)
					),
					{
						"source": (
							"career_runtime_engine."
							+ "fill_open_positions_quantum"
						),
						"background_only": true,
						"blocks_ui": false,
						"ready_gate_member": false
					}
				)
			)

			if not bool(
				result.get(
					"success",
					false
				)
			):
				continue

			filled += 1

			available_positions.remove_at(
				position_index
			)

			break

	staffing_candidate_cursor_by_path [
		cursor_key
	] = (
		(
			start_cursor
			+ scanned
		)
		% candidates.size()
	)

	return filled


func _simulate_organization_ecology() -> void:
	var state: Dictionary = _ensure_state_shape()
	var organizations: Dictionary = _safe_dictionary(
		state.get(
			"organizations",
			{}
		)
	)
	var departments: Dictionary = _safe_dictionary(
		state.get(
			"departments",
			{}
		)
	)
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)

	for organization_id_raw in organizations.keys():
		var organization_id: String = str(
			organization_id_raw
		)
		var organization: Dictionary = _safe_dictionary(
			organizations.get(
				organization_id,
				{}
			)
		)
		var total_positions: int = 0
		var vacant_positions: int = 0

		for department_id_raw in _safe_array(
			organization.get(
				"department_ids",
				[]
			)
		):
			var department: Dictionary = _safe_dictionary(
				departments.get(
					str(
						department_id_raw
					),
					{}
				)
			)

			for position_id_raw in _safe_array(
				department.get(
					"position_ids",
					[]
				)
			):
				var position: Dictionary = _safe_dictionary(
					positions.get(
						str(
							position_id_raw
						),
						{}
					)
				)

				if position.is_empty():
					continue

				total_positions += 1

				if str(
					position.get(
						"status",
						"vacant"
					)
				) == "vacant":
					vacant_positions += 1

		var vacancy_rate: float = 0.0

		if total_positions > 0:
			vacancy_rate = (
				float(
					vacant_positions
				)
				/ float(
					total_positions
				)
			)

		organization [
			"vacancy_rate"
		] = vacancy_rate

		var stability_delta: int = 0

		if vacancy_rate < 0.25:
			stability_delta = 1
		elif vacancy_rate > 0.65:
			stability_delta = -2

		organization ["stability"] = clampi(
			int(
				organization.get(
					"stability",
					72
				)
			)
			+ stability_delta,
			0,
			100
		)
		organization ["prestige"] = clampi(
			int(
				organization.get(
					"prestige",
					50
				)
			)
			+ (
				1
				if int(
					organization.get(
						"stability",
						72
					)
				) >= 80
				else 0
			),
			0,
			100
		)
		organization ["active"] = (
			int(
				organization.get(
					"stability",
					72
				)
			) > 5
		)

		var history: Array = _safe_array(
			organization.get(
				"history",
				[]
			)
		)
		history.append({
			"year": int(
				gs.year
			),
			"vacancy_rate": vacancy_rate,
			"stability": int(
				organization.get(
					"stability",
					72
				)
			),
			"prestige": int(
				organization.get(
					"prestige",
					50
				)
			),
			"active": bool(
				organization.get(
					"active",
					true
				)
			)
		})

		while (
			history.size()
			> MAX_ORGANIZATION_HISTORY
		):
			history.pop_front()

		organization ["history"] = history
		organizations [
			organization_id
		] = organization

	state ["organizations"] = organizations

	_sync_state_back(
		state
	)


func _vacate_actor_position(
	actor: Person,
	reason: String,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	var assignment: Dictionary = assignment_for_actor(
		actor
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	var state: Dictionary = _ensure_state_shape()
	var assignments: Dictionary = _safe_dictionary(
		state.get(
			"assignments",
			{}
		)
	)
	var positions: Dictionary = _safe_dictionary(
		state.get(
			"positions",
			{}
		)
	)
	var index: Dictionary = _safe_dictionary(
		state.get(
			"actor_assignment_index",
			{}
		)
	)
	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			""
		)
	)
	var position_id: String = str(
		assignment.get(
			"position_id",
			""
		)
	)
	var current: Dictionary = _safe_dictionary(
		assignments.get(
			assignment_id,
			assignment
		)
	)
	var position: Dictionary = _safe_dictionary(
		positions.get(
			position_id,
			{}
		)
	)

	current ["active"] = false
	current ["ended_year"] = int(
		gs.year
	)
	current ["end_reason"] = reason
	assignments [
		assignment_id
	] = current

	if not position.is_empty():
		position ["status"] = "vacant"
		position ["occupant_actor_id"] = -1
		position ["assignment_id"] = ""
		position [
			"vacant_since_year"
		] = int(
			gs.year
		)
		positions [
			position_id
		] = position

	index.erase(
		int(actor.id)
	)
	index.erase(
		str(
			int(actor.id)
		)
	)

	state ["assignments"] = assignments
	state ["positions"] = positions
	state [
		"actor_assignment_index"
	] = index

	var profile: Dictionary = ensure_actor_profile(
		actor
	)
	profile [
		"current_assignment_id"
	] = ""

	var history: Array = _safe_array(
		profile.get(
			"career_history",
			[]
		)
	)
	history.append({
		"event": reason,
		"year": int(
			gs.year
		),
		"organization_id": str(
			current.get(
				"organization_id",
				""
			)
		),
		"path_id": str(
			current.get(
				"path_id",
				""
			)
		),
		"rank_title": str(
			current.get(
				"rank_title",
				actor.job
			)
		),
		"position_id": position_id
	})
	profile ["career_history"] = history
	actor.career_profile = profile

	_unregister_from_workplace(
		actor
	)

	actor.current_workplace_id = ""
	actor.coworkers.clear()
	actor.income = 0
	actor.work_stress = 0.0
	actor.job = (
		"Retired"
		if reason == "retired"
		else ""
	)

	if reason in [
		"quit",
		"fired"
	]:
		actor.job_performance = 50

	_sync_state_back(
		state
	)
	_record_world_event(
		"career_%s"
		% reason,
		actor,
		current,
		context
	)

	var should_emit_quit: bool = reason in [
		"quit",
		"retired"
	]

	if should_emit_quit:
		_emit_event(
			ActionEventTypes.JOB_QUIT,
			actor,
			current,
			{
				"reason": reason,
				"source": str(
					context.get(
						"source",
						""
					)
				)
			}
		)
	elif reason == "fired":
		_emit_event(
			ActionEventTypes.JOB_FIRED,
			actor,
			current,
			{
				"reason": reason,
				"source": str(
					context.get(
						"source",
						""
					)
				)
			}
		)

	var text: String = (
		"I left my position as %s."
		% str(
			current.get(
				"rank_title",
				"professional"
			)
		)
	)

	if reason == "retired":
		text = (
			"I retired from my career as %s."
			% str(
				current.get(
					"rank_title",
					"professional"
				)
			)
		)
	elif reason == "fired":
		text = (
			"I was fired from my position as %s."
			% str(
				current.get(
					"rank_title",
					"professional"
				)
			)
		)
	elif reason == "died":
		text = (
			"%s's professional position became vacant after their death."
			% _actor_display_name(
				actor
			)
		)

	if not bool(
		context.get(
			"silent",
			false
		)
	):
		_log_narrative(
			actor,
			text,
			"career_%s"
			% reason
		)

	return {
		"success": true,
		"type": "career_position_vacated",
		"reason": reason,
		"text": text,
		"assignment": current,
		"position": position,
		"reality_mutated": true
	}


func _record_world_event(
	event_name: String,
	actor: Person,
	assignment: Dictionary,
	context: Dictionary = {}
) -> void:
	var state: Dictionary = _ensure_state_shape()

	var event_context: Dictionary = (
		context.duplicate(true)
	)

	if event_name == "career_activity":
		var output_report: Dictionary = (
			_materialize_declared_career_output(
				actor,
				assignment,
				event_context
			)
		)

		if not output_report.is_empty():
			event_context [
				"career_output_report"
			] = output_report

	var history: Array = _safe_array(
		state.get(
			"world_event_history",
			[]
		)
	)

	history.append({
		"event_name": event_name,
		"year": (
			int(
				gs.year
			)
			if gs != null
			else 0
		),
		"actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"actor_name": _actor_display_name(
			actor
		),
		"assignment_id": str(
			assignment.get(
				"assignment_id",
				""
			)
		),
		"organization_id": str(
			assignment.get(
				"organization_id",
				""
			)
		),
		"department_id": str(
			assignment.get(
				"department_id",
				""
			)
		),
		"path_id": str(
			assignment.get(
				"path_id",
				""
			)
		),
		"rank_title": str(
			assignment.get(
				"rank_title",
				""
			)
		),
		"context": event_context,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	while (
		history.size()
		> MAX_WORLD_EVENT_HISTORY
	):
		history.pop_front()

	state [
		"world_event_history"
	] = history

	_sync_state_back(
		state
	)
func _materialize_declared_career_output(
	actor: Person,
	assignment: Dictionary,
	context: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.belongings_engine == null
		or not bool(
			context.get(
				"productive_effects_applied",
				false
			)
		)
	):
		return {}

	var activity: Dictionary = _safe_dictionary(
		context.get(
			"activity",
			{}
		)
	)

	var output_contract: Dictionary = _safe_dictionary(
		activity.get(
			"career_output_contract",
			{}
		)
	)

	if output_contract.is_empty():
		return {}

	var output_kind: String = str(
		output_contract.get(
			"output_kind",
			"career_creation"
		)
	).strip_edges().to_lower()

	var category: String = str(
		output_contract.get(
			"category",
			"Created Works"
		)
	).strip_edges()

	if category == "":
		category = "Created Works"

	var actor_profile: Dictionary = _safe_dictionary(
		actor.career_profile
	)

	var performance: int = clampi(
		int(
			assignment.get(
				"performance",
				actor.job_performance
			)
		),
		0,
		100
	)

	var reputation: int = clampi(
		int(
			actor_profile.get(
				"professional_reputation_score",
				0
			)
		),
		0,
		100
	)

	var base_value: int = maxi(
		1,
		int(
			output_contract.get(
				"base_value",
				100
			)
		)
	)

	var value_variance: int = maxi(
		0,
		int(
			output_contract.get(
				"value_variance",
				0
			)
		)
	)

	var variance: int = _stable_runtime_roll(
		"career_output|%d|%d|%s|%d" % [
			int(
				actor.id
			),
			int(
				gs.year
			),
			str(
				activity.get(
					"id",
					"career_output"
				)
			),
			int(
				context.get(
					"use_number",
					1
				)
			)
		],
		- value_variance,
		value_variance
	)

	var appraised_value: int = maxi(
		1,
		base_value
		+ int(
			round(
				float(
					performance
				) * float(
					output_contract.get(
						"value_per_performance",
						2.0
					)
				)
			)
		)
		+ int(
			round(
				float(
					actor.smarts
				) * float(
					output_contract.get(
						"value_per_smarts",
						1.0
					)
				)
			)
		)
		+ int(
			round(
				float(
					reputation
				) * float(
					output_contract.get(
						"value_per_reputation",
						1.0
					)
				)
			)
		)
		+ variance
	)

	var appraisal_ratio: float = (
		float(
			appraised_value
		) / float(
			maxi(
				1,
				base_value
			)
		)
	)

	var appraisal_label: String = "Workshop Piece"

	if appraisal_ratio >= 3.0:
		appraisal_label = "Exceptional Masterwork"

	elif appraisal_ratio >= 2.0:
		appraisal_label = "Acclaimed Work"

	elif appraisal_ratio >= 1.35:
		appraisal_label = "Strong Commission"

	var name_prefix: String = str(
		output_contract.get(
			"name_prefix",
			"Created Work"
		)
	).strip_edges()

	var item_name: String = (
		"%s • %s • %d"
		% [
			name_prefix,
			appraisal_label,
			int(
				gs.year
			)
		]
	)

	var item_contract: Dictionary = (
		_career_output_item_contract(
			output_kind,
			category
		)
	)

	var contract_id: String = str(
		item_contract.get(
			"id",
			"career_output.%s"
			% output_kind
		)
	)

	if (
		gs.belongings_engine.has_method(
			"get_item_contract"
		)
		and gs.belongings_engine.has_method(
			"register_item_contract"
		)
		and gs.belongings_engine.get_item_contract(
			contract_id
		).is_empty()
	):
		gs.belongings_engine.register_item_contract(
			item_contract
		)

	var item: Dictionary = {
		"name": item_name,
		"display_name": item_name,
		"type": str(
			item_contract.get(
				"type",
				output_kind.replace(
					"_",
					" "
				).capitalize()
			)
		),
		"contract_id": contract_id,
		"item_contract": item_contract,
		"value": appraised_value,
		"category": category,
		"source": (
			"career_runtime_engine."
			+ "declared_career_output"
		),
		"creator_id": int(
			actor.id
		),
		"creator_name": _actor_display_name(
			actor
		),
		"career_path_id": str(
			assignment.get(
				"path_id",
				""
			)
		),
		"career_assignment_id": str(
			assignment.get(
				"assignment_id",
				""
			)
		),
		"career_activity_id": str(
			activity.get(
				"id",
				""
			)
		),
		"created_year": int(
			gs.year
		),
		"appraised_value": appraised_value,
		"appraisal_label": appraisal_label,
		"career_output_kind": output_kind
	}

	gs.belongings_engine.add_item(
		actor,
		item,
		category,
		false,
		{
			"source": (
				"career_runtime_engine."
				+ "declared_career_output"
			),
			"career_output_kind": output_kind,
			"appraised_value": appraised_value,
			"ui_blocking_forbidden": true
		}
	)

	var narrative_text: String = (
		"I created %s, and it was valued at $%d."
		% [
			item_name,
			appraised_value
		]
	)

	if output_kind == "painting":
		narrative_text = (
			"I painted %s, and it was valued at $%d."
			% [
				item_name,
				appraised_value
			]
		)

	_log_narrative(
		actor,
		narrative_text,
		"career_output_created"
	)

	return {
		"success": true,
		"schema": (
			"eralife.career_activity_output_report"
		),
		"version": ENGINE_VERSION,
		"actor_id": int(
			actor.id
		),
		"output_kind": output_kind,
		"category": category,
		"item_name": item_name,
		"appraised_value": appraised_value,
		"appraisal_label": appraisal_label,
		"contract_id": contract_id,
		"belongings_authority": "belongings_engine",
		"career_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _career_output_item_contract(
	output_kind: String,
	category: String
) -> Dictionary:
	var display_name: String = (
		output_kind.replace(
			"_",
			" "
		).capitalize()
	)

	if output_kind == "painting":
		display_name = "Painting"

	return {
		"id": (
			"career_output.%s"
			% output_kind
		),
		"display_name": display_name,
		"item_name": display_name,
		"type": display_name,
		"category": category,
		"value": 0,
		"identity": {
			"type": display_name,
			"category": category,
		},
		"affordances": [
			"display",
			"gift",
			"sell",
			"inherit"
		],
		"relationships": {
			"bondable": true,
			"giftable": true
		},
		"persistence": {
			"inheritable": true
		}
	}
func _emit_event(
	event_type,
	actor: Person,
	assignment: Dictionary,
	context: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.event_bus == null
	):
		return

	gs.event_bus.emit(
		event_type,
		{
			"npc": actor,
			"npc_id": (
				int(actor.id)
				if actor != null
				else -1
			),
			"text": str(
				context.get(
					"text",
					""
				)
			),
			"job_name": str(
				assignment.get(
					"rank_title",
					(
						actor.job
						if actor != null
						else ""
					)
				)
			),
			"assignment_id": str(
				assignment.get(
					"assignment_id",
					""
				)
			),
			"position_id": str(
				assignment.get(
					"position_id",
					""
				)
			),
			"organization_id": str(
				assignment.get(
					"organization_id",
					""
				)
			),
			"department_id": str(
				assignment.get(
					"department_id",
					""
				)
			),
			"path_id": str(
				assignment.get(
					"path_id",
					""
				)
			),
			"context": context.duplicate(true)
		}
	)


func _log_narrative(
	actor: Person,
	text: String,
	event_name: String
) -> void:
	if (
		actor == null
		or str(
			text
		).strip_edges() == ""
	):
		return

	if (
		gs == null
		or gs.narrative_engine == null
	):
		return

	gs.narrative_engine.log_event(
		actor,
		{
			"type": "text",
			"text": text,
			"life_diary_text": text,
			"force_first_person_memory": true,
			"source": "career_runtime_engine",
			"category": "career",
			"event_name": event_name,
			"suppress_world_feed": false
		}
	)


func _active_people() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs == null:
		return out

	if gs.player != null:
		seen [
			int(gs.player.id)
		] = true
		out.append(
			gs.player
		)

	for raw_actor in gs.npcs:
		var actor: Person = raw_actor as Person

		if actor == null:
			continue

		if seen.has(
			int(actor.id)
		):
			continue

		seen [
			int(actor.id)
		] = true
		out.append(
			actor
		)

	return out


func _actor_from_payload(
	payload
) -> Person:
	if payload is Person:
		return payload as Person

	if typeof(payload) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = payload as Dictionary

	for key in [
		"npc",
		"actor",
		"person"
	]:
		var candidate = data.get(
			key,
			null
		)

		if candidate is Person:
			return candidate as Person

	for key in [
		"npc_id",
		"actor_id",
		"person_id",
		"id"
	]:
		var actor_id: int = int(
			data.get(
				key,
				-1
			)
		)

		if actor_id > 0:
			return _actor_by_id(
				actor_id
			)

	return null


func _actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		return gs.get_or_reactivate_npc_by_id(
			actor_id
		)

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			actor_id
		)

	return null


func _salary_for_position(
	path: Dictionary,
	rank: Dictionary
) -> int:
	var era_name: String = _current_era_name()

	var lane: String = str(
		path.get(
			"lane",
			"full_time"
		)
	)

	var base_salary: int = 24000

	match era_name:
		"Ancient Era":
			base_salary = 1200

		"Medieval Era":
			base_salary = 1800

		"Industrial Era":
			base_salary = 18000

		"Modern Era":
			base_salary = 36000

		"Future Era":
			base_salary = 78000

		_:
			base_salary = 24000

	var path_base_salary_by_era: Dictionary = (
		_safe_dictionary(
			path.get(
				"base_salary_by_era",
				{}
			)
		)
	)

	var path_base_salary: int = maxi(
		0,
		int(
			path_base_salary_by_era.get(
				era_name,
				path.get(
					"base_salary",
					0
				)
			)
		)
	)

	if path_base_salary > 0:
		base_salary = path_base_salary

	if lane == "part_time":
		base_salary = maxi(
			400,
			int(
				round(
					float(
						base_salary
					) * 0.34
				)
			)
		)

	var quoted_salary: int = maxi(
		1,
		int(
			round(
				float(
					base_salary
				)
				* float(
					rank.get(
						"salary_multiplier",
						1.0
					)
				)
			)
		)
	)

	var salary_floor_by_era: Dictionary = _safe_dictionary(
		path.get(
			"minimum_base_salary_by_era",
			{}
		)
	)

	var path_salary_floor: int = maxi(
		0,
		int(
			salary_floor_by_era.get(
				era_name,
				path.get(
					"minimum_base_salary",
					0
				)
			)
		)
	)




	return maxi(
		quoted_salary,
		path_salary_floor
	)
func _retirement_age_for_era() -> int:
	match _current_era_name():
		"Ancient Era", "Medieval Era":
			return 52

		"Industrial Era":
			return 58

		"Future Era":
			return 68

		_:
			return 62


func _stable_runtime_roll(
	seed_text: String,
	minimum: int,
	maximum: int
) -> int:
	var low: int = mini(
		minimum,
		maximum
	)
	var high: int = maxi(
		minimum,
		maximum
	)
	var span: int = (
		high
		- low
		+ 1
	)

	if span <= 1:
		return low

	return (
		low
		+ posmod(
			int(
				str(
					seed_text
				).hash()
			),
			span
		)
	)


func _slug(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"\\",
		":",
		".",
		",",
		"'",
		"\""
	]:
		out = out.replace(
			token,
			"_"
		)

	while "__" in out:
		out = out.replace(
			"__",
			"_"
		)

	return out.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)


func _actor_display_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Person"

	var full_name: String = (
		"%s %s"
		% [
			str(
				actor.first_name
			),
			str(
				actor.last_name
			)
		]
	).strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d"
		% int(actor.id)
	)
func _sync_legacy_fields(
	actor: Person,
	assignment: Dictionary
) -> void:
	actor.job = str(
		assignment.get(
			"rank_title",
			actor.job
		)
	)
	actor.income = int(
		assignment.get(
			"salary",
			actor.income
		)
	)
	actor.job_performance = clampi(
		int(
			assignment.get(
				"performance",
				actor.job_performance
			)
		),
		0,
		100
	)
	actor.job_experience = maxi(
		0,
		int(
			assignment.get(
				"experience",
				actor.job_experience
			)
		)
	)
	actor.satisfaction = clampf(
		float(
			assignment.get(
				"satisfaction",
				actor.satisfaction
			)
		),
		0.0,
		100.0
	)
	actor.work_stress = clampf(
		float(
			assignment.get(
				"work_stress",
				actor.work_stress
			)
		),
		0.0,
		100.0
	)
	actor.current_workplace_id = str(
		assignment.get(
			"organization_id",
			actor.current_workplace_id
		)
	)
	actor.coworkers = coworker_ids_for_actor(
		actor
	)


func _register_with_workplace(
	actor: Person,
	assignment: Dictionary,
	organization: Dictionary
) -> void:
	if gs == null or gs.workplace_engine == null:
		return

	if gs.workplace_engine.has_method(
		"register_worker_at_organization"
	):
		gs.workplace_engine.register_worker_at_organization(
			actor,
			str(
				assignment.get(
					"rank_title",
					actor.job
				)
			),
			str(
				assignment.get(
					"organization_id",
					""
				)
			),
			str(
				assignment.get(
					"department_id",
					""
				)
			),
			str(
				assignment.get(
					"position_id",
					""
				)
			),
			{
				"organization_name": str(
					organization.get(
						"name",
						"Institution"
					)
				),
			}
		)
	else:
		gs.workplace_engine.register_worker(
			actor,
			str(
				assignment.get(
					"rank_title",
					actor.job
				)
			)
		)


func _unregister_from_workplace(
	actor: Person
) -> void:
	if (
		gs != null
		and gs.workplace_engine != null
	):
		gs.workplace_engine.unregister_worker(
			actor
		)


func _ensure_state_shape() -> Dictionary:
	if gs == null:
		return _default_state()

	var state: Dictionary = _safe_dictionary(
		gs.career_ecosystem_state
	)

	if (
		state.is_empty()
		and typeof(gs.scenario_state)
		== TYPE_DICTIONARY
	):
		state = _safe_dictionary(
			gs.scenario_state.get(
				STATE_KEY,
				{}
			)
		)

	if state.is_empty():
		state = _default_state()

	for key in [
		"organizations",
		"departments",
		"positions",
		"assignments",
		"actor_assignment_index",
		"applications",
		"era_boot_reports"
	]:
		if typeof(
			state.get(
				key,
				{}
			)
		) != TYPE_DICTIONARY:
			state [key] = {}

	for key in [
		"application_order",
		"world_event_history"
	]:
		if typeof(
			state.get(
				key,
				[]
			)
		) != TYPE_ARRAY:
			state [key] = []

	if not state.has(
		"next_assignment_sequence"
	):
		state [
			"next_assignment_sequence"
		] = 1

	if not state.has(
		"next_application_sequence"
	):
		state [
			"next_application_sequence"
		] = 1

	state ["schema"] = (
		"eralife.career_ecosystem_state"
	)
	state ["version"] = 1

	_sync_state_back(state)

	return state


func _sync_state_back(
	state: Dictionary
) -> void:
	if gs == null:
		return

	gs.career_ecosystem_state = state

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			STATE_KEY
		] = state.duplicate(true)


func _default_state() -> Dictionary:
	return {
		"schema": "eralife.career_ecosystem_state",
		"version": 1,
		"organizations": {},
		"departments": {},
		"positions": {},
		"assignments": {},
		"actor_assignment_index": {},
		"applications": {},
		"application_order": [],
		"world_event_history": [],
		"era_boot_reports": {},
		"next_assignment_sequence": 1,
		"next_application_sequence": 1
	}


func _normalized_reputation(
	raw: Dictionary
) -> Dictionary:
	var out: Dictionary = {
		"reliability": 50,
		"leadership": 50,
		"kindness": 50,
		"innovation": 50,
		"efficiency": 50,
		"corruption": 0,
		"bravery": 50,
		"carelessness": 0
	}

	for key in out.keys():
		if raw.has(key):
			out [key] = clampi(
				int(
					raw.get(
						key,
						out [key]
					)
				),
				0,
				100
			)

	return out


func _normalized_legacy(
	raw: Dictionary
) -> Dictionary:
	var out: Dictionary = {
		"achievements": 0,
		"students_mentored": 0,
		"patents_created": 0,
		"books_written": 0,
		"buildings_created": 0,
		"battles_won": 0,
		"patients_saved": 0,
		"cases_won": 0,
		"discoveries": 0,
		"world_traces": 0
	}

	for key in out.keys():
		if raw.has(key):
			out [key] = maxi(
				0,
				int(
					raw.get(
						key,
						0
					)
				)
			)

	return out


func _reputation_score(
	reputation: Dictionary
) -> int:
	return clampi(
		int(
			round(
				float(
					reputation.get(
						"reliability",
						50
					)
				) * 0.18
				+ float(
					reputation.get(
						"leadership",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"kindness",
						50
					)
				) * 0.1
				+ float(
					reputation.get(
						"innovation",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"efficiency",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"bravery",
						50
					)
				) * 0.1
				- float(
					reputation.get(
						"corruption",
						0
					)
				) * 0.08
				- float(
					reputation.get(
						"carelessness",
						0
					)
				) * 0.08
				+ 18.0
			)
		),
		0,
		100
	)


func _contract_engine():
	if gs == null:
		return null

	return gs.career_contract_engine


func _current_era_name() -> String:
	if gs == null or gs.era == null:
		return "Unknown Era"

	return str(
		gs.era.get(
			"name",
			"Unknown Era"
		)
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": (
			"Career runtime could not resolve: %s."
			% reason
		),
		"context": context.duplicate(true)
	}