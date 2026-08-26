extends Resource
class_name WorldEngine

const WORLD_CONTRACT_SCHEMA:= "eralife.world_engine_contract"
const WORLD_CONTRACT_VERSION:= 1
const DEFAULT_WORLD_CONTRACT_ID:= "eralife_default_world_engine"

var gs
var world_contract_registry: Dictionary = {}
var world_phase_registry: Dictionary = {}
var world_task_registry: Dictionary = {}
var last_world_contract_report: Dictionary = {}


var bounded_world_task_state: Dictionary = {}
var last_world_year_report: Dictionary = {}

func _init(_gs):
	gs = _gs
	configure_world_contracts({})

func configure_world_contracts(raw_bundle: Dictionary = {}) -> Dictionary:
	world_contract_registry.clear()
	world_phase_registry.clear()
	world_task_registry.clear()

	var report:= {
		"schema": "eralife.world_engine_contract_configure_report",
		"version": WORLD_CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"configured_at_ms": int(Time.get_ticks_msec())
	}

	var contracts: Array = []
	contracts.append(_build_default_world_contract())

	var registry_raw: Variant = raw_bundle.get("world_contract_registry", raw_bundle.get("contracts", {}))
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for key in (registry_raw as Dictionary).keys():
			var row_raw: Variant = (registry_raw as Dictionary).get(key, {})
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))
	elif typeof(registry_raw) == TYPE_ARRAY:
		for row_raw in registry_raw:
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	var direct_contracts_raw: Variant = raw_bundle.get("world_contracts", raw_bundle.get("runtime_phases", []))
	if typeof(direct_contracts_raw) == TYPE_ARRAY:
		for row_raw in direct_contracts_raw:
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	if raw_bundle.has("schema") or raw_bundle.has("phases") or raw_bundle.has("tasks"):
		contracts.append(raw_bundle.duplicate(true))

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = normalize_world_contract(raw_contract)
		var validation: Dictionary = normalized.get("validation", {})
		if not bool(validation.get("valid", false)):
			report ["failed"].append({
				"id": str(normalized.get("id", "")),
				"validation": validation.duplicate(true)
			})
			continue

		_ingest_world_contract(normalized)
		report ["loaded"].append({
			"id": str(normalized.get("id", "")),
			"phase_count": int(normalized.get("phases", []).size()),
			"task_count": int(normalized.get("tasks", []).size())
		})

	last_world_contract_report = report.duplicate(true)
	return report

func import_registry(raw_registry: Dictionary = {}) -> Dictionary:
	return configure_world_contracts(raw_registry)

func export_registry() -> Dictionary:
	return {
		"schema": "eralife.world_engine_contract_registry",
		"version": WORLD_CONTRACT_VERSION,
		"contracts": world_contract_registry.duplicate(true),
		"phases": world_phase_registry.duplicate(true),
		"tasks": world_task_registry.duplicate(true),
		"last_report": last_world_contract_report.duplicate(true)
	}

func export_state() -> Dictionary:
	return export_registry()

func import_state(raw_state: Dictionary = {}) -> Dictionary:
	return import_registry(raw_state)

func normalize_world_contract(raw_contract: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", DEFAULT_WORLD_CONTRACT_ID))).strip_edges()
	if contract_id == "":
		contract_id = DEFAULT_WORLD_CONTRACT_ID
		warnings.append("WorldEngine contract id was empty. Defaulted to '%s'." % contract_id)

	var version: int = max(1, int(raw_contract.get("version", WORLD_CONTRACT_VERSION)))
	if version > WORLD_CONTRACT_VERSION:
		warnings.append("WorldEngine contract '%s' was authored for version %d. Runtime supports %d." % [contract_id, version, WORLD_CONTRACT_VERSION])

	var tasks: Array = []
	for raw_task in _safe_world_dictionary_array(raw_contract.get("tasks", [])):
		var task: Dictionary = normalize_world_task(raw_task, contract_id)
		if str(task.get("id", "")).strip_edges() == "":
			warnings.append("Skipped WorldEngine task without id.")
			continue
		tasks.append(task)

	var phases: Array = []
	for raw_phase in _safe_world_dictionary_array(raw_contract.get("phases", raw_contract.get("runtime_phases", []))):
		var phase: Dictionary = normalize_world_phase(raw_phase, contract_id)
		if str(phase.get("id", "")).strip_edges() == "":
			warnings.append("Skipped legacy WorldEngine phase without id.")
			continue
		phases.append(phase)

	if tasks.is_empty():
		errors.append("WorldEngine contract '%s' has no tasks." % contract_id)

	if phases.is_empty():
		warnings.append("WorldEngine contract '%s' has no local phases. GameStateContractEngine runtime phases will own scheduling." % contract_id)

	return {
		"schema": str(raw_contract.get("schema", WORLD_CONTRACT_SCHEMA)).strip_edges(),
		"version": version,
		"runtime_contract_version": WORLD_CONTRACT_VERSION,
		"id": contract_id,
		"enabled": bool(raw_contract.get("enabled", true)),
		"priority": int(raw_contract.get("priority", 0)),
		"tasks": tasks,
		"phases": phases,
		"phase_owner": "game_state_contract_engine",
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

func normalize_world_task(raw_task: Dictionary, contract_id: String = "") -> Dictionary:
	var task_id: String = str(raw_task.get("id", raw_task.get("task_id", ""))).strip_edges()
	var method_name: String = str(raw_task.get("method", raw_task.get("method_name", task_id))).strip_edges()

	return {
		"id": task_id,
		"contract_id": contract_id,
		"enabled": bool(raw_task.get("enabled", true)),
		"method": method_name,
		"phase": str(raw_task.get("phase", "legacy_world_year")).strip_edges(),
		"order": int(raw_task.get("order", 100)),
		"priority": int(raw_task.get("priority", 0)),
		"once_per_year": bool(raw_task.get("once_per_year", false)),
		"method_owns_year_guard": bool(raw_task.get("method_owns_year_guard", false)),
		"passes_context": bool(raw_task.get("passes_context", false)),
		"required": bool(raw_task.get("required", false)),
		"emits_world_feed": bool(raw_task.get("emits_world_feed", false)),
		"emits_diary": bool(raw_task.get("emits_diary", false)),
		"metadata": raw_task.get("metadata", {}).duplicate(true) if typeof(raw_task.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": task_id != "" and method_name != "",
			"errors": [] if task_id != "" and method_name != "" else ["WorldEngine task requires id and method."],
			"warnings": []
		}
	}

func normalize_world_phase(raw_phase: Dictionary, contract_id: String = "") -> Dictionary:
	var phase_id: String = str(raw_phase.get("id", raw_phase.get("phase", ""))).strip_edges()

	return {
		"id": phase_id,
		"contract_id": contract_id,
		"enabled": bool(raw_phase.get("enabled", true)),
		"order": int(raw_phase.get("order", 100)),
		"priority": int(raw_phase.get("priority", 0)),
		"tasks": raw_phase.get("tasks", []).duplicate(true) if typeof(raw_phase.get("tasks", [])) == TYPE_ARRAY else [],
		"metadata": raw_phase.get("metadata", {}).duplicate(true) if typeof(raw_phase.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": phase_id != "",
			"errors": [] if phase_id != "" else ["WorldEngine phase requires id."],
			"warnings": []
		}
	}

func run_world_contract_phase(phase_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_phase: String = str(phase_id).strip_edges()
	var phase_raw: Variant = world_phase_registry.get(clean_phase, {})
	var phase: Dictionary = phase_raw if typeof(phase_raw) == TYPE_DICTIONARY else {}

	var report:= {
		"schema": "eralife.world_engine_phase_report",
		"version": WORLD_CONTRACT_VERSION,
		"phase": clean_phase,
		"phase_owner": "game_state_contract_engine" if phase.is_empty() else "world_engine_legacy",
		"year": int(context.get("year", gs.year if gs != null else 0)),
		"ran": [],
		"skipped": [],
		"failed": [],
		"started_at_ms": int(Time.get_ticks_msec())
	}

	var task_ids: Array = []

	if not phase.is_empty():
		if not bool(phase.get("enabled", true)):
			report ["skipped"].append({
				"phase": clean_phase,
				"reason": "phase_disabled"
			})
			last_world_year_report = report.duplicate(true)
			return report

		task_ids = _world_phase_task_ids(phase)
		for task_id in task_ids:
			var task_report: Dictionary = run_world_contract_task(str(task_id), context)
			if bool(task_report.get("ran", false)):
				report ["ran"].append(task_report)
			elif bool(task_report.get("failed", false)):
				report ["failed"].append(task_report)
			else:
				report ["skipped"].append(task_report)
	else:
		var runtime_tasks: Array = []
		if gs != null and gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("get_runtime_phase_tasks"):
			runtime_tasks = gs.game_state_contract_engine.get_runtime_phase_tasks(clean_phase, "world_engine")

		if runtime_tasks.is_empty():
			report ["failed"].append({
				"phase": clean_phase,
				"reason": "missing_game_state_runtime_phase_or_world_tasks"
			})
			last_world_year_report = report.duplicate(true)
			return report

		for listener in runtime_tasks:
			if typeof(listener) != TYPE_DICTIONARY:
				continue

			var task_report: Dictionary = run_world_contract_listener(listener, context)
			if bool(task_report.get("ran", false)):
				report ["ran"].append(task_report)
			elif bool(task_report.get("failed", false)):
				report ["failed"].append(task_report)
			else:
				report ["skipped"].append(task_report)

	report ["finished_at_ms"] = int(Time.get_ticks_msec())
	report ["duration_ms"] = int(report ["finished_at_ms"]) - int(report ["started_at_ms"])
	last_world_year_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_world_engine_phase_report"] = report.duplicate(true)

	return report

func run_world_contract_task(
	task_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_task: String = str(
		task_id
	).strip_edges()

	var task_raw: Variant = world_task_registry.get(
		clean_task,
		{}
	)
	var task: Dictionary = (
		task_raw as Dictionary
		if typeof(task_raw) == TYPE_DICTIONARY
		else {}
	)

	var target_year: int = int(
		context.get(
			"year",
			gs.year if gs != null else 0
		)
	)

	var report: Dictionary = {
		"schema": "eralife.world_engine_task_report",
		"version": WORLD_CONTRACT_VERSION,
		"task": clean_task,
		"year": target_year,
		"ran": false,
		"skipped": false,
		"failed": false,
		"reason": "",
		"is_complete": true,
		"progress": 1.0,
		"bounded_runtime": false
	}

	if task.is_empty():
		report ["failed"] = true
		report ["reason"] = "missing_task_contract"
		return report

	if not bool(
		task.get(
			"enabled",
			true
		)
	):
		report ["skipped"] = true
		report ["reason"] = "task_disabled"
		return report

	var method_name: String = str(
		task.get(
			"method",
			clean_task
		)
	).strip_edges()

	if (
		method_name == ""
		or not has_method(
			method_name
		)
	):
		report ["failed"] = true
		report ["reason"] = (
			"missing_method:%s" % method_name
		)
		return report

	var runtime_context: Dictionary = (
		context.duplicate(
			false
		)
	)
	runtime_context ["world_task_id"] = clean_task
	runtime_context ["world_contract_id"] = str(
		task.get(
			"contract_id",
			DEFAULT_WORLD_CONTRACT_ID
		)
	)
	runtime_context ["year"] = target_year

	var bounded_runtime: bool = bool(
		runtime_context.get(
			"bounded_runtime",
			false
		)
	)

	if (
		bounded_runtime
		and clean_task in [
			"age_npcs",
			"process_pregnancies",
			"npc_have_children",
			"process_divorces",
			"process_remarriages",
			"process_movement"
		]
	):
		var bounded_result: Dictionary = (
			step_world_contract_task(
				clean_task,
				runtime_context
			)
		)

		report ["ran"] = true
		report ["method"] = method_name
		report ["bounded_runtime"] = true
		report ["is_complete"] = bool(
			bounded_result.get(
				"is_complete",
				false
			)
		)
		report ["progress"] = float(
			bounded_result.get(
				"progress",
				0.0
			)
		)
		report ["result"] = bounded_result.duplicate(
			false
		)
		return report

	if (
		bool(
			task.get(
				"once_per_year",
				false
			)
		)
		and not bool(
			task.get(
				"method_owns_year_guard",
				false
			)
		)
	):
		if not _claim_world_year_tick(
			clean_task,
			target_year
		):
			report ["skipped"] = true
			report ["reason"] = (
				"already_applied_for_year"
			)
			return report

	var result: Variant = null

	if bool(
		task.get(
			"passes_context",
			false
		)
	):
		result = callv(
			method_name,
			[
				runtime_context
			]
		)
	else:
		result = call(
			method_name
		)

	report ["ran"] = true
	report ["method"] = method_name

	if typeof(result) == TYPE_DICTIONARY:
		report ["result"] = (
			result as Dictionary
		).duplicate(
			false
		)
	else:
		report ["result"] = result

	return report
func step_world_contract_task(
	task_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_task: String = str(
		task_id
	).strip_edges()

	match clean_task:
		"age_npcs":
			return _step_world_age_npcs(
				context
			)

		"process_pregnancies":
			return _step_world_pregnancies(
				context
			)

		"npc_have_children":
			return _step_world_npc_births(
				context
			)

		"process_divorces":
			return _step_world_divorces(
				context
			)

		"process_remarriages":
			return _step_world_remarriages(
				context
			)

		"process_movement":
			return _step_world_movement(
				context
			)

		_:
			return {
				"success": false,
				"supported": false,
				"is_complete": true,
				"progress": 1.0,
				"reason": (
					"unsupported_bounded_world_task"
				),
				"task": clean_task
			}


func _bounded_world_task_budget(
	context: Dictionary
) -> Dictionary:
	return {
		"items": clampi(
			int(
				context.get(
					"runtime_item_budget",
					96
				)
			),
			1,
			256
		),
		"time_ms": clampi(
			int(
				context.get(
					"runtime_time_budget_ms",
					2
				)
			),
			1,
			4
		)
	}


func _bounded_world_task_key(
	task_id: String,
	target_year: int
) -> String:
	return "%s|%d" % [
		task_id,
		target_year
	]


func _bounded_world_task_progress(
	cursor: int,
	total: int
) -> float:
	if total <= 0:
		return 1.0

	return clampf(
		float(cursor) / float(total),
		0.0,
		1.0
	)
func _world_age_npcs_completion_receipt_is_valid(
	report: Dictionary,
	source_year: int,
	target_year: int
) -> bool:
	if report.is_empty():
		return false

	if str(
		report.get(
			"schema",
			""
		)
	).strip_edges() != "eralife.world_engine_age_npcs_report":
		return false

	if str(
		report.get(
			"authority",
			""
		)
	).strip_edges() != "world_engine":
		return false

	if str(
		report.get(
			"task",
			""
		)
	).strip_edges() != "age_npcs":
		return false

	if int(
		report.get(
			"source_year",
			-999999
		)
	) != source_year:
		return false

	if int(
		report.get(
			"year",
			-999999
		)
	) != target_year:
		return false

	if not bool(
		report.get(
			"is_complete",
			false
		)
	):
		return false

	if not bool(
		report.get(
			"completion_receipt",
			false
		)
	):
		return false

	return true

func _step_world_age_npcs(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"supported": false,
			"failed": true,
			"is_complete": false,
			"progress": 0.0,
			"reason": "missing_game_state",
			"task": "age_npcs",
			"blocks_ui": false
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)

	var source_year: int = int(
		context.get(
			"contract_source_year",
			target_year - 1
		)
	)

	var time_contract_raw: Variant = context.get(
		"time_contract",
		gs.scenario_state.get(
			"age_up_time_contract",
			{}
		)
	)
	var time_contract: Dictionary = (
		time_contract_raw as Dictionary
		if typeof(time_contract_raw) == TYPE_DICTIONARY
		else {}
	)

	source_year = int(
		time_contract.get(
			"source_year",
			source_year
		)
	)

	var existing_report_raw: Variant = gs.scenario_state.get(
		"last_world_engine_age_npcs_report",
		{}
	)
	var existing_report: Dictionary = (
		existing_report_raw as Dictionary
		if typeof(existing_report_raw) == TYPE_DICTIONARY
		else {}
	)

	var existing_receipt_valid: bool = (
		_world_age_npcs_completion_receipt_is_valid(
			existing_report,
			source_year,
			target_year
		)
	)

	var state_key: String = _bounded_world_task_key(
		"age_npcs",
		target_year
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {}
	)

	if state.is_empty():
		var claimed_now: bool = _claim_world_year_tick(
			"age_npcs",
			target_year
		)

		if (
			not claimed_now
			and existing_receipt_valid
		):
			gs.scenario_state [
				"age_up_zero_frame_npc_snapshot_complete"
			] = true
			gs.scenario_state [
				"age_up_zero_frame_npc_snapshot_pending"
			] = false

			return {
				"success": true,
				"supported": true,
				"is_complete": true,
				"progress": 1.0,
				"already_applied": true,
				"completion_receipt": true,
				"receipt_key": str(
					existing_report.get(
						"receipt_key",
						""
					)
				),
				"task": "age_npcs",
				"source_year": source_year,
				"year": target_year,
				"result": existing_report.duplicate(false),
				"blocks_ui": false
			}

		state = {
			"cursor": 0,
			"priority_source_index": 0,
			"priority_item_index": 0,
			"priority_partner_done": false,
			"priority_attempted_ids": {},
			"priority_resolved_ids": {},
			"priority_seen_ids": {},
			"priority_consumed": 0,
			"priority_lookup_attempts": 0,
			"priority_lookup_misses": 0,
			"priority_fallback_resolutions": 0,
			"prioritized_npcs": 0,
			"aged_npcs": 0,
			"corrected_overadvanced_npcs": 0,
			"skipped_dead": 0,
			"skipped_player": 0,
			"event_count": 0,
			"death_checks": 0,
			"recovered_same_year_npcs": 0,
			"recovered_claim_without_receipt": (
				not claimed_now
				and not existing_receipt_valid
			)
		}

	var budget: Dictionary = _bounded_world_task_budget(
		context
	)
	var item_budget: int = int(
		budget.get(
			"items",
			96
		)
	)
	var time_budget_ms: int = int(
		budget.get(
			"time_ms",
			2
		)
	)
	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var processed: int = 0
	var age_cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var priority_source_index: int = int(
		state.get(
			"priority_source_index",
			0
		)
	)
	var priority_item_index: int = int(
		state.get(
			"priority_item_index",
			0
		)
	)
	var priority_partner_done: bool = bool(
		state.get(
			"priority_partner_done",
			false
		)
	)
	var priority_consumed: int = int(
		state.get(
			"priority_consumed",
			0
		)
	)




	var legacy_priority_seen_raw: Variant = state.get(
		"priority_seen_ids",
		{}
	)
	var legacy_priority_seen_ids: Dictionary = (
		legacy_priority_seen_raw as Dictionary
		if typeof(legacy_priority_seen_raw) == TYPE_DICTIONARY
		else {}
	)
	var priority_attempted_raw: Variant = state.get(
		"priority_attempted_ids",
		legacy_priority_seen_ids
	)
	var priority_attempted_ids: Dictionary = (
		priority_attempted_raw as Dictionary
		if typeof(priority_attempted_raw) == TYPE_DICTIONARY
		else {}
	)
	var priority_resolved_raw: Variant = state.get(
		"priority_resolved_ids",
		{}
	)
	var priority_resolved_ids: Dictionary = (
		priority_resolved_raw as Dictionary
		if typeof(priority_resolved_raw) == TYPE_DICTIONARY
		else {}
	)

	var started_ages_raw: Variant = gs.scenario_state.get(
		"age_up_started_npc_ages",
		{}
	)
	var started_ages: Dictionary = (
		started_ages_raw as Dictionary
		if typeof(started_ages_raw) == TYPE_DICTIONARY
		else {}
	)
	var allow_multi_year_jump: bool = bool(
		gs.scenario_state.get(
			"age_up_allow_multi_year_npc_age_jump",
			false
		)
	)
	var controlled: Person = gs.player
	var priority_source_names: Array = [
		"parents",
		"children",
		"friends",
		"ex_partners",
		"schoolmates"
	]

	while processed < item_budget:
		if (
			processed > 0
			and int(
				Time.get_ticks_msec()
			) - started_ms >= time_budget_ms
		):
			break

		var npc = null
		var selected_from_priority: bool = false

		if (
			controlled != null
			and not priority_partner_done
		):
			priority_partner_done = true
			priority_consumed += 1
			processed += 1

			if controlled.partner != null:
				var partner_id: int = int(
					controlled.partner.id
				)
				var partner_key: String = str(
					partner_id
				)

				if (
					partner_id > 0
					and partner_id != int(
						controlled.id
					)
					and not priority_attempted_ids.has(
						partner_key
					)
				):
					priority_attempted_ids [
						partner_key
					] = true
					state ["priority_lookup_attempts"] = int(
						state.get(
							"priority_lookup_attempts",
							0
						)
					) + 1
					npc = gs.get_npc_by_id(
						partner_id,
						false
					)
					selected_from_priority = npc != null

					if selected_from_priority:
						priority_resolved_ids [
							partner_key
						] = true
					else:
						state ["priority_lookup_misses"] = int(
							state.get(
								"priority_lookup_misses",
								0
							)
						) + 1

		elif (
			controlled != null
			and priority_source_index < priority_source_names.size()
		):
			var source_name: String = str(
				priority_source_names [
					priority_source_index
				]
			)
			var source_ids: Array = []

			match source_name:
				"parents":
					source_ids = controlled.parents
				"children":
					source_ids = controlled.children
				"friends":
					source_ids = controlled.friends
				"ex_partners":
					source_ids = controlled.ex_partners
				"schoolmates":
					source_ids = controlled.schoolmates

			if priority_item_index >= source_ids.size():
				priority_source_index += 1
				priority_item_index = 0
				continue

			var priority_id: int = int(
				source_ids [
					priority_item_index
				]
			)
			priority_item_index += 1
			priority_consumed += 1
			processed += 1
			var priority_key: String = str(
				priority_id
			)

			if (
				priority_id > 0
				and priority_id != int(
					controlled.id
				)
				and not priority_attempted_ids.has(
					priority_key
				)
			):
				priority_attempted_ids [
					priority_key
				] = true
				state ["priority_lookup_attempts"] = int(
					state.get(
						"priority_lookup_attempts",
						0
					)
				) + 1
				npc = gs.get_npc_by_id(
					priority_id,
					false
				)
				selected_from_priority = npc != null

				if selected_from_priority:
					priority_resolved_ids [
						priority_key
					] = true
				else:
					state ["priority_lookup_misses"] = int(
						state.get(
							"priority_lookup_misses",
							0
						)
					) + 1

		else:
			if age_cursor >= gs.npcs.size():
				break

			npc = gs.npcs [
				age_cursor
			]
			age_cursor += 1
			processed += 1

			if npc != null:
				var cursor_npc_key: String = str(
					int(
						npc.id
					)
				)




				if priority_resolved_ids.has(
					cursor_npc_key
				):
					continue

				if priority_attempted_ids.has(
					cursor_npc_key
				):
					priority_resolved_ids [
						cursor_npc_key
					] = true
					state ["priority_fallback_resolutions"] = int(
						state.get(
							"priority_fallback_resolutions",
							0
						)
					) + 1

		if npc == null:
			continue

		if (
			gs.player != null
			and int(
				npc.id
			) == int(
				gs.player.id
			)
		):
			state ["skipped_player"] = int(
				state.get(
					"skipped_player",
					0
				)
			) + 1
			continue

		if not npc.alive:
			state ["skipped_dead"] = int(
				state.get(
					"skipped_dead",
					0
				)
			) + 1
			continue





		if (
			npc.has_method(
				"get_meta"
			)
			and int(
				npc.get_meta(
					"last_world_engine_biology_completed_year",
					-999999
				)
			) == target_year
		):
			state ["recovered_same_year_npcs"] = int(
				state.get(
					"recovered_same_year_npcs",
					0
				)
			) + 1
			continue

		var previous_age: int = int(
			npc.age
		)
		var npc_key: String = str(
			int(
				npc.id
			)
		)

		if not started_ages.has(
			npc_key
		):
			started_ages [
				npc_key
			] = previous_age

		var expected_age: int = int(
			started_ages.get(
				npc_key,
				previous_age
			)
		) + 1

		if int(npc.age) < expected_age:
			npc.age = expected_age
			state ["aged_npcs"] = int(
				state.get(
					"aged_npcs",
					0
				)
			) + 1
		elif (
			int(npc.age) > expected_age
			and not allow_multi_year_jump
		):
			npc.age = expected_age
			state [
				"corrected_overadvanced_npcs"
			] = int(
				state.get(
					"corrected_overadvanced_npcs",
					0
				)
			) + 1
		else:
			state ["aged_npcs"] = int(
				state.get(
					"aged_npcs",
					0
				)
			) + 1

		if selected_from_priority:
			state ["prioritized_npcs"] = int(
				state.get(
					"prioritized_npcs",
					0
				)
			) + 1

		if npc.has_method(
			"set_meta"
		):
			npc.set_meta(
				"last_temporal_biology_year",
				target_year
			)
			npc.set_meta(
				"last_world_engine_biology_year",
				target_year
			)

		if _should_emit_npc_age_event(
			npc,
			previous_age,
			int(npc.age)
		):
			_emit_npc_age_event(
				npc,
				previous_age,
				int(npc.age),
				target_year
			)
			state ["event_count"] = int(
				state.get(
					"event_count",
					0
				)
			) + 1

		if gs.health_engine != null:
			gs.health_engine.enforce_mortal_age_cap(
				npc
			)
			state ["death_checks"] = int(
				state.get(
					"death_checks",
					0
				)
			) + 1

		if npc.has_method(
			"set_meta"
		):
			npc.set_meta(
				"last_world_engine_biology_completed_year",
				target_year
			)

	state ["cursor"] = age_cursor
	state ["priority_source_index"] = priority_source_index
	state ["priority_item_index"] = priority_item_index
	state ["priority_partner_done"] = priority_partner_done
	state ["priority_consumed"] = priority_consumed
	state ["priority_attempted_ids"] = priority_attempted_ids
	state ["priority_resolved_ids"] = priority_resolved_ids



	state ["priority_seen_ids"] = priority_resolved_ids.duplicate(false)

	gs.scenario_state [
		"age_up_started_npc_ages"
	] = started_ages

	var priority_complete: bool = (
		priority_partner_done
		and priority_source_index >= priority_source_names.size()
	)
	var complete: bool = (
		priority_complete
		and age_cursor >= gs.npcs.size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
		gs.scenario_state [
			"age_up_zero_frame_npc_snapshot_cursor"
		] = gs.npcs.size()
		gs.scenario_state [
			"age_up_zero_frame_npc_snapshot_total"
		] = gs.npcs.size()
		gs.scenario_state [
			"age_up_zero_frame_npc_snapshot_complete"
		] = true
		gs.scenario_state [
			"age_up_zero_frame_npc_snapshot_pending"
		] = false

		var receipt_key: String = (
			"world.age_npcs|%d|%d"
			% [
				source_year,
				target_year
			]
		)

		var complete_report: Dictionary = {
			"schema": "eralife.world_engine_age_npcs_report",
			"version": WORLD_CONTRACT_VERSION,
			"authority": "world_engine",
			"task": "age_npcs",
			"source_year": source_year,
			"year": target_year,
			"is_complete": true,
			"complete": true,
			"completion_receipt": true,
			"receipt_key": receipt_key,
			"already_applied": false,
			"aged_npcs": int(
				state.get(
					"aged_npcs",
					0
				)
			),
			"prioritized_npcs": int(
				state.get(
					"prioritized_npcs",
					0
				)
			),
			"priority_lookup_attempts": int(
				state.get(
					"priority_lookup_attempts",
					0
				)
			),
			"priority_lookup_misses": int(
				state.get(
					"priority_lookup_misses",
					0
				)
			),
			"priority_fallback_resolutions": int(
				state.get(
					"priority_fallback_resolutions",
					0
				)
			),
			"corrected_overadvanced_npcs": int(
				state.get(
					"corrected_overadvanced_npcs",
					0
				)
			),
			"skipped_dead": int(
				state.get(
					"skipped_dead",
					0
				)
			),
			"skipped_player": int(
				state.get(
					"skipped_player",
					0
				)
			),
			"event_count": int(
				state.get(
					"event_count",
					0
				)
			),
			"death_checks": int(
				state.get(
					"death_checks",
					0
				)
			),
			"recovered_same_year_npcs": int(
				state.get(
					"recovered_same_year_npcs",
					0
				)
			),
			"recovered_claim_without_receipt": bool(
				state.get(
					"recovered_claim_without_receipt",
					false
				)
			),
			"aged_ids": [],
			"population_scan_used_for_priority_resolution": int(
				state.get(
					"priority_fallback_resolutions",
					0
				)
			) > 0,
			"bounded_runtime": true,
			"completed_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		gs.scenario_state [
			"last_world_engine_age_npcs_report"
		] = complete_report.duplicate(false)

		return {
			"success": true,
			"supported": true,
			"task": "age_npcs",
			"source_year": source_year,
			"year": target_year,
			"is_complete": true,
			"progress": 1.0,
			"completion_receipt": true,
			"receipt_key": receipt_key,
			"processed_this_quantum": processed,
			"result": complete_report,
			"blocks_ui": false
		}

	bounded_world_task_state [
		state_key
	] = state

	var priority_total_hint: int = 1
	if controlled != null:
		priority_total_hint += (
			controlled.parents.size()
			+ controlled.children.size()
			+ controlled.friends.size()
			+ controlled.ex_partners.size()
			+ controlled.schoolmates.size()
		)

	var priority_cursor_hint: int = priority_consumed
	var combined_total: int = maxi(
		1,
		priority_total_hint + gs.npcs.size()
	)
	var combined_cursor: int = mini(
		combined_total,
		priority_cursor_hint + age_cursor
	)

	return {
		"success": true,
		"supported": true,
		"task": "age_npcs",
		"source_year": source_year,
		"year": target_year,
		"is_complete": false,
		"progress": _bounded_world_task_progress(
			combined_cursor,
			combined_total
		),
		"processed_this_quantum": processed,
		"priority_lookup_attempts": int(
			state.get(
				"priority_lookup_attempts",
				0
			)
		),
		"priority_lookup_misses": int(
			state.get(
				"priority_lookup_misses",
				0
			)
		),
		"priority_fallback_resolutions": int(
			state.get(
				"priority_fallback_resolutions",
				0
			)
		),
		"recovered_claim_without_receipt": bool(
			state.get(
				"recovered_claim_without_receipt",
				false
			)
		),
		"blocks_ui": false
	}

func _step_world_pregnancies(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0
		}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)
	var state_key: String = (
		_bounded_world_task_key(
			"process_pregnancies",
			target_year
		)
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {
			"cursor": 0,
			"births": 0,
			"player_line_births_waiting_for_identity": 0
		}
	)

	var budget: Dictionary = (
		_bounded_world_task_budget(
			context
		)
	)
	var pregnancy_cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var pregnancy_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var pregnancy_processed: int = 0

	while (
		pregnancy_cursor < gs.npcs.size()
		and pregnancy_processed < int(
			budget.get(
				"items",
				96
			)
		)
	):
		var npc = gs.npcs [
			pregnancy_cursor
		]
		pregnancy_cursor += 1
		pregnancy_processed += 1

		if npc == null:
			continue

		if npc.pregnancy_progress < 0:
			continue

		npc.pregnancy_progress += 1

		if npc.pregnancy_progress < 1:
			continue

		var other_parent = gs.get_npc_by_id(
			npc.unborn_child_other_parent_id
		)

		if not gs.can_create_child(
			npc,
			other_parent,
			false
		):
			npc.pregnant_by_id = -1
			npc.unborn_child_other_parent_id = -1
			npc.pregnancy_progress = -1
			npc.pregnancy_known = false
			npc.pregnancy_context = ""
			continue

		var pending_raw: Variant = gs.pending_player_line_birth
		var pending: Dictionary = (
			pending_raw as Dictionary
			if typeof(pending_raw) == TYPE_DICTIONARY
			else {}
		)
		var pending_matches_birth: bool = (
			not pending.is_empty()
			and int(
				pending.get(
					"mother_id",
					-1
				)
			) == int(npc.id)
			and int(
				pending.get(
					"father_id",
					-1
				)
			) == int(other_parent.id)
		)

		if pending_matches_birth:
			pending ["ready_to_name"] = true
			pending ["birth_year"] = target_year
			pending ["truth_owner"] = "world_engine_due_birth"
			gs.pending_player_line_birth = pending
			state [
				"player_line_births_waiting_for_identity"
			] = int(
				state.get(
					"player_line_births_waiting_for_identity",
					0
				)
			) + 1
			continue

		var baby = gs.spawn_child(
			npc,
			other_parent,
			false
		)

		if baby == null:
			npc.pregnant_by_id = -1
			npc.unborn_child_other_parent_id = -1
			npc.pregnancy_progress = -1
			npc.pregnancy_known = false
			npc.pregnancy_context = ""
			continue

		baby.age = 0

		var birth_text: String = (
			"\n \n %s gave birth to %s's child, %s."
			% [
				npc.first_name,
				other_parent.first_name,
				baby.first_name
			]
		)

		gs.pending_death_messages.append(
			birth_text
		)
		gs.event_bus.emit(
			ActionEventTypes.CHILD_BORN_PLAYER_LINE,
			{
				"npc_id": npc.id,
				"target_id": other_parent.id,
				"child_id": baby.id,
				"text": birth_text
			}
		)

		state ["births"] = int(
			state.get(
				"births",
				0
			)
		) + 1

		npc.pregnant_by_id = -1
		npc.unborn_child_other_parent_id = -1
		npc.pregnancy_progress = -1
		npc.pregnancy_known = false
		npc.pregnancy_context = ""

		if (
			pregnancy_processed > 0
			and int(
				Time.get_ticks_msec()
			) - pregnancy_started_ms >= int(
				budget.get(
					"time_ms",
					2
				)
			)
		):
			break

	state ["cursor"] = pregnancy_cursor
	var complete: bool = (
		pregnancy_cursor >= gs.npcs.size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
	else:
		bounded_world_task_state [
			state_key
		] = state

	return {
		"success": true,
		"supported": true,
		"task": "process_pregnancies",
		"year": target_year,
		"is_complete": complete,
		"progress": (
			_bounded_world_task_progress(
				pregnancy_cursor,
				gs.npcs.size()
			)
		),
		"births": int(
			state.get(
				"births",
				0
			)
		),
		"player_line_births_waiting_for_identity": int(
			state.get(
				"player_line_births_waiting_for_identity",
				0
			)
		),
		"processed_this_quantum": pregnancy_processed,
		"blocks_ui": false
	}

func _step_world_npc_births(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0
		}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)
	var state_key: String = (
		_bounded_world_task_key(
			"npc_have_children",
			target_year
		)
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {
			"cursor": 0,
			"births": 0,
			"visible_events": 0
		}
	)

	var budget: Dictionary = (
		_bounded_world_task_budget(
			context
		)
	)
	var birth_cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var birth_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var birth_processed: int = 0

	while (
		birth_cursor < gs.npcs.size()
		and birth_processed < int(
			budget.get(
				"items",
				96
			)
		)
	):
		var npc = gs.npcs [
			birth_cursor
		]
		birth_cursor += 1
		birth_processed += 1

		if npc == null:
			continue

		var partner = gs.get_valid_partner(
			npc,
			true
		)

		if (
			partner != null
			and npc.age > 20
			and npc.age < 45
			and randi() % 500 == 1
		):
			var baby = gs.spawn_child(
				npc,
				partner,
				true
			)

			if baby != null:
				var parent_a_name: String = (
					_world_engine_full_name(
						npc
					)
				)
				var parent_b_name: String = (
					_world_engine_full_name(
						partner
					)
				)
				var baby_name: String = (
					_world_engine_full_name(
						baby
					)
				)
				var event_text: String = (
					"%s and %s had a child named %s."
					% [
						parent_a_name,
						parent_b_name,
						baby_name
					]
				)

				state ["births"] = int(
					state.get(
						"births",
						0
					)
				) + 1

				_world_engine_log_first_person_memory(
					npc,
					"I had a child named %s."
					% baby_name,
					{
						"event_name": "npc_born",
						"category": "life",
						"target_id": int(
							baby.id
						)
					}
				)
				_world_engine_log_first_person_memory(
					partner,
					"I had a child named %s."
					% baby_name,
					{
						"event_name": "npc_born",
						"category": "life",
						"target_id": int(
							baby.id
						)
					}
				)

				var personally_relevant: bool = (
					_world_engine_birth_relevant_to_player(
						npc,
						partner,
						baby
					)
				)
				var player_text: String = (
					_world_engine_birth_player_text(
						npc,
						partner,
						baby
					)
				)

				var entry: Dictionary = {
					"type": "world_feed_entry",
					"event_name": "npc_born",
					"source": "world_engine",
					"category": "life",
					"year": int(
						gs.year
					),
					"npc_id": int(
						npc.id
					),
					"target_id": int(
						baby.id
					),
					"text": event_text,
					"world_text": event_text,
					"player_text": player_text,
					"journal_text": player_text,
					"personally_relevant": (
						personally_relevant
					),
					"diary_scope": (
						"family"
						if personally_relevant
						else "world"
					),
					"suppress_diary": (
						not personally_relevant
					),
					"queue_world_feed": true
				}

				if gs.has_method(
					"push_world_feed"
				):
					gs.push_world_feed(
						event_text,
						entry
					)
					state [
						"visible_events"
					] = int(
						state.get(
							"visible_events",
							0
						)
					) + 1

				if (
					personally_relevant
					and player_text != ""
					and gs.narrative_engine != null
				):
					gs.narrative_engine.log_event(
						gs.player,
						{
							"type": "text",
							"text": player_text,
							"source": "world_engine",
							"category": "life",
							"event_name": "npc_born",
							"npc_id": int(
								npc.id
							),
							"target_id": int(
								baby.id
							),
							"personally_relevant": true,
							"diary_scope": "family",
							"suppress_world_feed": true
						}
					)

				_world_engine_queue_family_birth_popup(
					npc,
					partner,
					baby,
					player_text
				)

				if gs.event_bus != null:
					gs.event_bus.emit(
						ActionEventTypes.NPC_BORN,
						{
							"type": "npc_born",
							"npc_id": int(
								baby.id
							),
							"parent_a_id": int(
								npc.id
							),
							"parent_b_id": int(
								partner.id
							),
							"text": event_text,
							"world_feed_text": event_text,
							"player_text": player_text,
							"personally_relevant": (
								personally_relevant
							),
							"year": int(
								gs.year
							),
							"source": "world_engine",
							"category": "life",
							"event_name": "npc_born",
							"suppress_world_feed": true
						}
					)

		if (
			birth_processed > 0
			and int(
				Time.get_ticks_msec()
			) - birth_started_ms >= int(
				budget.get(
					"time_ms",
					2
				)
			)
		):
			break

	state ["cursor"] = birth_cursor
	var complete: bool = (
		birth_cursor >= gs.npcs.size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
	else:
		bounded_world_task_state [
			state_key
		] = state

	return {
		"success": true,
		"supported": true,
		"task": "npc_have_children",
		"year": target_year,
		"is_complete": complete,
		"progress": (
			_bounded_world_task_progress(
				birth_cursor,
				gs.npcs.size()
			)
		),
		"births": int(
			state.get(
				"births",
				0
			)
		),
		"visible_events": int(
			state.get(
				"visible_events",
				0
			)
		),
		"processed_this_quantum": birth_processed,
		"blocks_ui": false
	}


func _step_world_divorces(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0
		}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)
	var state_key: String = (
		_bounded_world_task_key(
			"process_divorces",
			target_year
		)
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {
			"cursor": 0,
			"divorces": 0
		}
	)

	var budget: Dictionary = (
		_bounded_world_task_budget(
			context
		)
	)
	var divorce_cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var divorce_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var divorce_processed: int = 0

	while (
		divorce_cursor < gs.npcs.size()
		and divorce_processed < int(
			budget.get(
				"items",
				96
			)
		)
	):
		var npc = gs.npcs [
			divorce_cursor
		]
		divorce_cursor += 1
		divorce_processed += 1

		if npc == null:
			continue

		var partner = gs.get_valid_partner(
			npc,
			true
		)

		if partner == null:
			continue

		if randi() % 2000 == 1:
			gs.narrative_engine.log_event(
				npc,
				{
					"type": "text",
					"text": (
						"%s and %s have divorced."
						% [
							npc.first_name,
							partner.first_name
						]
					)
				}
			)

			gs.end_partnership(
				npc,
				true
			)

			gs.event_bus.emit(
				ActionEventTypes.NPC_DIVORCED,
				{
					"npc_id": npc.id,
					"text": (
						"%s and %s divorced."
						% [
							npc.first_name,
							partner.first_name
						]
					)
				}
			)

			state ["divorces"] = int(
				state.get(
					"divorces",
					0
				)
			) + 1

		if (
			divorce_processed > 0
			and int(
				Time.get_ticks_msec()
			) - divorce_started_ms >= int(
				budget.get(
					"time_ms",
					2
				)
			)
		):
			break

	state ["cursor"] = divorce_cursor
	var complete: bool = (
		divorce_cursor >= gs.npcs.size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
	else:
		bounded_world_task_state [
			state_key
		] = state

	return {
		"success": true,
		"supported": true,
		"task": "process_divorces",
		"year": target_year,
		"is_complete": complete,
		"progress": (
			_bounded_world_task_progress(
				divorce_cursor,
				gs.npcs.size()
			)
		),
		"divorces": int(
			state.get(
				"divorces",
				0
			)
		),
		"processed_this_quantum": divorce_processed,
		"blocks_ui": false
	}


func _step_world_remarriages(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0
		}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)
	var state_key: String = (
		_bounded_world_task_key(
			"process_remarriages",
			target_year
		)
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {
			"phase": "gather",
			"gather_cursor": 0,
			"pair_cursor": 0,
			"singles": [],
			"marriages": 0
		}
	)

	var budget: Dictionary = (
		_bounded_world_task_budget(
			context
		)
	)
	var remarriage_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var remarriage_processed: int = 0
	var phase: String = str(
		state.get(
			"phase",
			"gather"
		)
	)

	if phase == "gather":
		var gather_cursor: int = int(
			state.get(
				"gather_cursor",
				0
			)
		)
		var singles_raw: Variant = state.get(
			"singles",
			[]
		)
		var singles: Array = (
			singles_raw as Array
			if typeof(singles_raw) == TYPE_ARRAY
			else []
		)

		while (
			gather_cursor < gs.npcs.size()
			and remarriage_processed < int(
				budget.get(
					"items",
					96
				)
			)
		):
			var npc = gs.npcs [
				gather_cursor
			]
			gather_cursor += 1
			remarriage_processed += 1

			if npc != null:
				var partner = gs.get_valid_partner(
					npc,
					true
				)

				if (
					partner == null
					and npc.alive
					and npc.age >= 18
					and _marital_status_available_for_remarriage(
						npc
					)
				):
					singles.append(
						npc
					)
			if (
				remarriage_processed > 0
				and int(
					Time.get_ticks_msec()
				) - remarriage_started_ms >= int(
					budget.get(
						"time_ms",
						2
					)
				)
			):
				break

		state ["gather_cursor"] = gather_cursor
		state ["singles"] = singles

		if gather_cursor >= gs.npcs.size():
			state ["phase"] = "pair"
			state ["pair_cursor"] = 0
			phase = "pair"

	if (
		phase == "pair"
		and int(
			Time.get_ticks_msec()
		) - remarriage_started_ms < int(
			budget.get(
				"time_ms",
				2
			)
		)
	):
		var pair_singles_raw: Variant = state.get(
			"singles",
			[]
		)
		var pair_singles: Array = (
			pair_singles_raw as Array
			if typeof(pair_singles_raw) == TYPE_ARRAY
			else []
		)
		var pair_cursor: int = int(
			state.get(
				"pair_cursor",
				0
			)
		)

		while (
			pair_cursor < pair_singles.size()
			and remarriage_processed < int(
				budget.get(
					"items",
					96
				)
			)
		):
			var npc = pair_singles [
				pair_cursor
			]
			pair_cursor += 1
			remarriage_processed += 1

			if (
				npc != null
				and npc.alive
				and randi() % 5000 == 1
				and pair_singles.size() > 1
			):
				var other = pair_singles [
					randi() % pair_singles.size()
				]

				if (
					other != null
					and other != npc
					and other.alive
					and _marital_status_available_for_remarriage(
						npc
					)
					and _marital_status_available_for_remarriage(
						other
					)
				):
					npc.partner = other
					other.partner = npc

					gs.social_graph_engine.connect_people(
						npc.id,
						other.id
					)

					npc.marital_status = "Married"
					other.marital_status = "Married"

					gs.event_bus.emit(
						ActionEventTypes.NPC_MARRIED,
						{
							"npc_id": npc.id,
							"text": (
								"%s married %s."
								% [
									npc.first_name,
									other.first_name
								]
							)
						}
					)

					gs.narrative_engine.log_event(
						npc,
						{
							"type": "text",
							"text": (
								"%s married %s."
								% [
									npc.first_name,
									other.first_name
								]
							)
						}
					)

					_process_step_parent_effects(
						npc,
						other
					)

					state ["marriages"] = int(
						state.get(
							"marriages",
							0
						)
					) + 1

			if (
				remarriage_processed > 0
				and int(
					Time.get_ticks_msec()
				) - remarriage_started_ms >= int(
					budget.get(
						"time_ms",
						2
					)
				)
			):
				break

		state ["pair_cursor"] = pair_cursor

	var complete: bool = (
		str(
			state.get(
				"phase",
				"gather"
			)
		) == "pair"
		and int(
			state.get(
				"pair_cursor",
				0
			)
		) >= (
			state.get(
				"singles",
				[]
			) as Array
		).size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
	else:
		bounded_world_task_state [
			state_key
		] = state

	var total_population: int = maxi(
		1,
		gs.npcs.size()
	)
	var progress: float = 0.0

	if str(
		state.get(
			"phase",
			"gather"
		)
	) == "gather":
		progress = (
			0.5
			* _bounded_world_task_progress(
				int(
					state.get(
						"gather_cursor",
						0
					)
				),
				total_population
			)
		)
	else:
		var progress_singles_raw: Variant = state.get(
			"singles",
			[]
		)
		var progress_singles: Array = (
			progress_singles_raw as Array
			if typeof(progress_singles_raw) == TYPE_ARRAY
			else []
		)
		progress = (
			0.5
			+ 0.5
			* _bounded_world_task_progress(
				int(
					state.get(
						"pair_cursor",
						0
					)
				),
				maxi(
					1,
					progress_singles.size()
				)
			)
		)

	return {
		"success": true,
		"supported": true,
		"task": "process_remarriages",
		"year": target_year,
		"is_complete": complete,
		"progress": (
			1.0
			if complete
			else progress
		),
		"marriages": int(
			state.get(
				"marriages",
				0
			)
		),
		"processed_this_quantum": remarriage_processed,
		"blocks_ui": false
	}


func _step_world_movement(
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0
		}

	var target_year: int = int(
		context.get(
			"year",
			gs.year
		)
	)
	var state_key: String = (
		_bounded_world_task_key(
			"process_movement",
			target_year
		)
	)
	var state_raw: Variant = bounded_world_task_state.get(
		state_key,
		{}
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {
			"cursor": 0,
			"moves": 0
		}
	)

	var budget: Dictionary = (
		_bounded_world_task_budget(
			context
		)
	)
	var movement_cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var movement_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var movement_processed: int = 0

	while (
		movement_cursor < gs.npcs.size()
		and movement_processed < int(
			budget.get(
				"items",
				96
			)
		)
	):
		var npc = gs.npcs [
			movement_cursor
		]
		movement_cursor += 1
		movement_processed += 1

		if (
			npc == null
			or not npc.alive
		):
			continue

		if gs.family_control_engine != null:
			if (
				gs.family_control_engine
				.is_in_player_household_cluster(
					npc
				)
			):
				continue

			if (
				gs.family_control_engine
				.is_minor_under_custodial_authority(
					npc
				)
			):
				continue

		if randi() % 3000 == 1:
			var locs = (
				gs.era_engine.get_birth_locations()
			)

			if not locs.is_empty():
				var new_place = locs [
					randi() % locs.size()
				]

				npc.home_city = str(
					new_place.get(
						"city",
						npc.home_city
					)
				)
				npc.home_country = str(
					new_place.get(
						"country",
						npc.home_country
					)
				)

				gs.event_bus.emit(
					ActionEventTypes.NPC_MOVED,
					{
						"npc_id": npc.id,
						"text": (
							"%s moved to %s, %s."
							% [
								npc.first_name,
								str(
									new_place.get(
										"city",
										npc.home_city
									)
								),
								str(
									new_place.get(
										"country",
										npc.home_country
									)
								)
							]
						)
					}
				)

				gs.chunk_simulation_engine.remove_npc(
					npc
				)
				gs.world_space_engine.move_npc(
					npc
				)
				gs.chunk_simulation_engine.assign_npc(
					npc
				)

				state ["moves"] = int(
					state.get(
						"moves",
						0
					)
				) + 1

		if (
			movement_processed > 0
			and int(
				Time.get_ticks_msec()
			) - movement_started_ms >= int(
				budget.get(
					"time_ms",
					2
				)
			)
		):
			break

	state ["cursor"] = movement_cursor
	var complete: bool = (
		movement_cursor >= gs.npcs.size()
	)

	if complete:
		bounded_world_task_state.erase(
			state_key
		)
	else:
		bounded_world_task_state [
			state_key
		] = state

	return {
		"success": true,
		"supported": true,
		"task": "process_movement",
		"year": target_year,
		"is_complete": complete,
		"progress": (
			_bounded_world_task_progress(
				movement_cursor,
				gs.npcs.size()
			)
		),
		"moves": int(
			state.get(
				"moves",
				0
			)
		),
		"processed_this_quantum": movement_processed,
		"blocks_ui": false
	}
func run_world_contract_listener(
	listener: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var task_id: String = str(
		listener.get(
			"task_id",
			listener.get(
				"id",
				""
			)
		)
	).strip_edges()

	if task_id == "":
		task_id = str(
			listener.get(
				"method",
				""
			)
		).strip_edges()

	var runtime_context: Dictionary = (
		context.duplicate(
			false
		)
	)
	runtime_context ["runtime_phase"] = str(
		listener.get(
			"phase",
			runtime_context.get(
				"runtime_phase",
				""
			)
		)
	)
	runtime_context ["runtime_owner"] = str(
		runtime_context.get(
			"runtime_owner",
			"game_state_contract_engine"
		)
	)
	runtime_context ["world_listener_id"] = str(
		listener.get(
			"id",
			task_id
		)
	)

	for key in listener.keys():
		if key in [
			"metadata",
			"validation"
		]:
			continue

		if not runtime_context.has(
			key
		):
			runtime_context [key] = listener.get(
				key
			)

	return run_world_contract_task(
		task_id,
		runtime_context
	)
func _build_default_world_contract() -> Dictionary:
	return {
		"schema": WORLD_CONTRACT_SCHEMA,
		"version": WORLD_CONTRACT_VERSION,
		"id": DEFAULT_WORLD_CONTRACT_ID,
		"enabled": true,
		"tasks": [
			{
				"id": "age_npcs",
				"method": "age_npcs",
				"phase": "population_lifecycle",
				"order": 10,
				"once_per_year": true,
				"method_owns_year_guard": true,
				"passes_context": true,
				"emits_world_feed": true,
				"emits_diary": true
			},
			{
				"id": "process_pregnancies",
				"method": "process_pregnancies",
				"phase": "population_lifecycle",
				"order": 20
			},
			{
				"id": "npc_have_children",
				"method": "npc_have_children",
				"phase": "population_lifecycle",
				"order": 30,
				"emits_world_feed": true,
				"emits_diary": true
			},
			{
				"id": "process_divorces",
				"method": "process_divorces",
				"phase": "relationship_lifecycle",
				"order": 40,
				"emits_world_feed": true
			},
			{
				"id": "process_remarriages",
				"method": "process_remarriages",
				"phase": "relationship_lifecycle",
				"order": 50,
				"emits_world_feed": true
			},
			{
				"id": "process_movement",
				"method": "process_movement",
				"phase": "migration_lifecycle",
				"order": 60,
				"emits_world_feed": true
			}
		],
		"phases": [
			{
				"id": "population_lifecycle",
				"order": 10,
				"tasks": ["age_npcs", "process_pregnancies", "npc_have_children"]
			},
			{
				"id": "relationship_lifecycle",
				"order": 20,
				"tasks": ["process_divorces", "process_remarriages"]
			},
			{
				"id": "migration_lifecycle",
				"order": 30,
				"tasks": ["process_movement"]
			},
			{
				"id": "legacy_world_year",
				"order": 100,
				"tasks": [
					"age_npcs",
					"process_pregnancies",
					"npc_have_children",
					"process_divorces",
					"process_remarriages",
					"process_movement"
				]
			}
		],
		"metadata": {
			"built_in": true,
			"backwards_compatible": true,
		}
	}

func _ingest_world_contract(contract: Dictionary) -> void:
	if not bool(contract.get("enabled", true)):
		return

	var contract_id: String = str(contract.get("id", DEFAULT_WORLD_CONTRACT_ID)).strip_edges()
	if contract_id == "":
		contract_id = DEFAULT_WORLD_CONTRACT_ID

	world_contract_registry [contract_id] = contract.duplicate(true)

	for raw_task in contract.get("tasks", []):
		if typeof(raw_task) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = raw_task
		var task_id: String = str(task.get("id", "")).strip_edges()
		if task_id == "":
			continue
		world_task_registry [task_id] = task.duplicate(true)

	for raw_phase in contract.get("phases", []):
		if typeof(raw_phase) != TYPE_DICTIONARY:
			continue
		var phase: Dictionary = raw_phase
		var phase_id: String = str(phase.get("id", "")).strip_edges()
		if phase_id == "":
			continue
		world_phase_registry [phase_id] = phase.duplicate(true)

func _world_phase_task_ids(phase: Dictionary) -> Array:
	var out: Array = []
	var tasks_raw: Variant = phase.get("tasks", [])

	if typeof(tasks_raw) != TYPE_ARRAY:
		return out

	for raw_task in tasks_raw:
		if typeof(raw_task) == TYPE_STRING:
			var task_id: String = str(raw_task).strip_edges()
			if task_id != "":
				out.append(task_id)
		elif typeof(raw_task) == TYPE_DICTIONARY:
			var task_row: Dictionary = raw_task
			var task_id_from_row: String = str(task_row.get("id", task_row.get("task_id", ""))).strip_edges()
			if task_id_from_row != "":
				out.append(task_id_from_row)

	return out

func _ensure_world_runtime_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state_raw: Variant = gs.scenario_state.get("world_engine_runtime_state", {})
	var state: Dictionary = state_raw if typeof(state_raw) == TYPE_DICTIONARY else {}

	if not state.has("year_ticks"):
		state ["year_ticks"] = {}
	if not state.has("reports"):
		state ["reports"] = []

	gs.scenario_state ["world_engine_runtime_state"] = state
	return state

func _claim_world_year_tick(domain: String, target_year: int) -> bool:
	var clean_domain: String = str(domain).strip_edges()
	if clean_domain == "":
		clean_domain = "world"

	var state: Dictionary = _ensure_world_runtime_state()
	if state.is_empty() and gs == null:
		return true

	var ticks_raw: Variant = state.get("year_ticks", {})
	var ticks: Dictionary = ticks_raw if typeof(ticks_raw) == TYPE_DICTIONARY else {}
	var tick_key: String = "%s|%d" % [clean_domain, target_year]

	if bool(ticks.get(tick_key, false)):
		return false

	ticks [tick_key] = true
	state ["year_ticks"] = ticks
	state ["last_tick_key"] = tick_key
	state ["last_tick_year"] = target_year

	_prune_world_year_ticks(state, target_year)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["world_engine_runtime_state"] = state

	return true

func _prune_world_year_ticks(state: Dictionary, target_year: int) -> void:
	var ticks_raw: Variant = state.get("year_ticks", {})
	if typeof(ticks_raw) != TYPE_DICTIONARY:
		return

	var ticks: Dictionary = ticks_raw
	var keep: Dictionary = {}

	for key in ticks.keys():
		var parts: PackedStringArray = str(key).split("|")
		if parts.size() < 2:
			continue
		var key_year: int = int(parts [parts.size() - 1])
		if abs(target_year - key_year) <= 3:
			keep [key] = ticks.get(key)

	state ["year_ticks"] = keep

func _safe_world_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))

	return out





func update_relationships(max_scan_per_step: int = -1) -> Dictionary:
	if (
		gs == null
		or gs.social_graph_engine == null
		or typeof(gs.npcs) != TYPE_ARRAY
	):
		remove_meta("yearly_relationship_update_state")
		return {
			"is_complete": true,
			"progress": 1.0,
			"processed": 0
		}

	var total: int = gs.npcs.size()
	if total <= 0:
		remove_meta("yearly_relationship_update_state")
		return {
			"is_complete": true,
			"progress": 1.0,
			"processed": 0
		}

	var current_year: int = int(gs.year)
	var state_raw: Variant = get_meta(
		"yearly_relationship_update_state",
		{}
	)
	var state: Dictionary = (
		state_raw
		if typeof(state_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		state.is_empty()
		or int(state.get("year", current_year)) != current_year
		or int(state.get("population_size", total)) != total
	):
		state = {
			"year": current_year,
			"population_size": total,
			"source_cursor": 0,
			"source_selected": false,
			"source_id": -1,
			"candidate_cursor": 0,
			"candidate_ids": [],
			"connected_count": 0
		}

	var source_cursor: int = int(
		state.get(
			"source_cursor",
			0
		)
	)
	var source_selected: bool = bool(
		state.get(
			"source_selected",
			false
		)
	)
	var source_id: int = int(
		state.get(
			"source_id",
			-1
		)
	)
	var candidate_cursor: int = int(
		state.get(
			"candidate_cursor",
			0
		)
	)
	var candidate_ids_raw: Variant = state.get(
		"candidate_ids",
		[]
	)
	var candidate_ids: Array = (
		candidate_ids_raw
		if typeof(candidate_ids_raw) == TYPE_ARRAY
		else []
	)
	var connected_count: int = int(
		state.get(
			"connected_count",
			0
		)
	)

	var scan_cap: int = 64
	if max_scan_per_step < 0:


		scan_cap = maxi(
			1,
			total * maxi(
				2,
				total + 1
			)
		)
	else:
		scan_cap = clampi(
			max_scan_per_step,
			1,
			64
		)

	var processed: int = 0

	while processed < scan_cap and source_cursor < total:
		var npc = gs.npcs [source_cursor]

		if not source_selected:
			processed += 1

			if npc == null:
				source_cursor += 1
				continue

			if randi() % 1500 != 0:
				source_cursor += 1
				continue

			source_selected = true
			source_id = int(npc.id)
			candidate_cursor = 0
			candidate_ids = []

		if candidate_cursor < total and processed < scan_cap:
			var other = gs.npcs [candidate_cursor]
			candidate_cursor += 1
			processed += 1

			if (
				other != null
				and int(other.id) != source_id
				and bool(other.alive)
			):
				candidate_ids.append(
					int(other.id)
				)
			continue

		if candidate_cursor >= total:
			if not candidate_ids.is_empty():
				var pick_id: int = int(
					candidate_ids [
						randi() % candidate_ids.size()
					]
				)
				gs.social_graph_engine.connect_people(
					source_id,
					pick_id
				)
				connected_count += 1

			source_cursor += 1
			source_selected = false
			source_id = -1
			candidate_cursor = 0
			candidate_ids = []

	var is_complete: bool = (
		source_cursor >= total
		and not source_selected
	)

	if is_complete:
		remove_meta(
			"yearly_relationship_update_state"
		)
	else:
		state ["source_cursor"] = source_cursor
		state ["source_selected"] = source_selected
		state ["source_id"] = source_id
		state ["candidate_cursor"] = candidate_cursor
		state ["candidate_ids"] = candidate_ids
		state ["connected_count"] = connected_count

		set_meta(
			"yearly_relationship_update_state",
			state
		)

	var source_fraction: float = 0.0
	if source_selected:
		source_fraction = (
			float(candidate_cursor)
			/ float(maxi(1, total))
		)

	return {
		"is_complete": is_complete,
		"progress": clampf(
			(
				float(source_cursor)
				+ source_fraction
			)
			/ float(maxi(1, total)),
			0.0,
			1.0
		),
		"processed": processed,
		"source_cursor": source_cursor,
		"population_size": total,
		"connected_count": connected_count,
		"max_scan_per_step": scan_cap
	}


func age_npcs(context: Dictionary = {}) -> Dictionary:
	var target_year: int = int(context.get("year", gs.year if gs != null else 0))
	var report:= {
		"schema": "eralife.world_engine_age_npcs_report",
		"version": WORLD_CONTRACT_VERSION,
		"year": target_year,
		"already_applied": false,
		"aged_npcs": 0,
		"corrected_overadvanced_npcs": 0,
		"skipped_dead": 0,
		"skipped_player": 0,
		"skipped_temporal_streamed": 0,
		"event_count": 0,
		"death_checks": 0,
		"aged_ids": []
	}

	if gs == null:
		return report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if not _claim_world_year_tick("age_npcs", target_year):
		report ["already_applied"] = true
		return report

	var started_npc_ages_raw: Variant = gs.scenario_state.get("age_up_started_npc_ages", {})
	var started_npc_ages: Dictionary = started_npc_ages_raw if typeof(started_npc_ages_raw) == TYPE_DICTIONARY else {}
	var allow_multi_year_jump: bool = bool(gs.scenario_state.get("age_up_allow_multi_year_npc_age_jump", false))

	for npc in gs.npcs:
		if npc == null:
			continue

		if gs.player != null and int(npc.id) == int(gs.player.id):
			report ["skipped_player"] = int(report.get("skipped_player", 0)) + 1
			continue

		if not npc.alive:
			report ["skipped_dead"] = int(report.get("skipped_dead", 0)) + 1
			continue

		var previous_age: int = int(npc.age)
		var npc_key: String = str(int(npc.id))
		var expected_age: int = previous_age + 1

		if started_npc_ages.has(npc_key):
			expected_age = int(started_npc_ages.get(npc_key, previous_age)) + 1

		if int(npc.age) < expected_age:
			npc.age = expected_age
			report ["aged_npcs"] = int(report.get("aged_npcs", 0)) + 1
		elif int(npc.age) > expected_age and not allow_multi_year_jump:
			npc.age = expected_age
			report ["corrected_overadvanced_npcs"] = int(report.get("corrected_overadvanced_npcs", 0)) + 1
		else:
			report ["aged_npcs"] = int(report.get("aged_npcs", 0)) + 1

		report ["aged_ids"].append(int(npc.id))

		if npc.has_method("set_meta"):
			npc.set_meta("last_temporal_biology_year", target_year)
			npc.set_meta("last_world_engine_biology_year", target_year)

		if _should_emit_npc_age_event(npc, previous_age, int(npc.age)):
			_emit_npc_age_event(npc, previous_age, int(npc.age), target_year)
			report ["event_count"] = int(report.get("event_count", 0)) + 1

		if gs.health_engine != null:
			gs.health_engine.enforce_mortal_age_cap(npc)
			report ["death_checks"] = int(report.get("death_checks", 0)) + 1

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_world_engine_age_npcs_report"] = report.duplicate(true)

	return report

func _should_emit_npc_age_event(npc: Person, previous_age: int, new_age: int) -> bool:
	if npc == null:
		return false

	if new_age <= previous_age:
		return false

	if _world_engine_personally_relevant(npc):
		return true

	if bool(npc.is_royal) or bool(npc.is_ruler):
		return _is_world_age_milestone(new_age)

	if int(npc.fame) >= 70:
		return _is_world_age_milestone(new_age)

	return false

func _is_world_age_milestone(age_value: int) -> bool:
	if age_value in [1, 5, 10, 13, 16, 18, 21, 25]:
		return true
	if age_value >= 30 and age_value % 10 == 0:
		return true
	return false

func _world_engine_personally_relevant(npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false

	if int(npc.id) == int(gs.player.id):
		return true
	if int(npc.id) in gs.player.parents:
		return true
	if int(npc.id) in gs.player.children:
		return true
	if int(gs.player.id) in npc.parents:
		return true
	if int(gs.player.id) in npc.children:
		return true
	if npc.parents == gs.player.parents and int(npc.id) != int(gs.player.id):
		return true
	if int(npc.id) in gs.player.friends:
		return true
	if gs.player.partner == npc:
		return true
	if int(npc.id) in gs.player.ex_partners:
		return true

	return false

func _world_engine_relation_label(npc: Person) -> String:
	if gs == null or gs.player == null or npc == null:
		return ""

	if gs.has_method("get_relationship_label_between"):
		var label: String = str(gs.get_relationship_label_between(gs.player, npc)).strip_edges()
		if label != "" and label != "Stranger":
			return label

	if int(npc.id) in gs.player.parents:
		return "father" if str(npc.gender) == "Male" else "mother"
	if int(npc.id) in gs.player.children:
		return "son" if str(npc.gender) == "Male" else "daughter"
	if int(gs.player.id) in npc.parents:
		return "son" if str(npc.gender) == "Male" else "daughter"
	if npc.parents == gs.player.parents and int(npc.id) != int(gs.player.id):
		return "brother" if str(npc.gender) == "Male" else "sister"
	if int(npc.id) in gs.player.friends:
		return "friend"
	if gs.player.partner == npc:
		return "partner"
	if int(npc.id) in gs.player.ex_partners:
		return "ex"

	return ""

func _world_engine_full_name(npc: Person) -> String:
	if npc == null:
		return "Someone"

	var full_name: String = ("%s %s" % [npc.first_name, npc.last_name]).strip_edges()
	if full_name == "":
		return "Someone"

	return full_name
func _world_vitality_year_label(year_value: int) -> String:
	if year_value < 0:
		return "%d BCE" % abs(year_value)
	if year_value <= 1000:
		return "%d AD" % year_value
	return str(year_value)


func _world_vitality_format_integer_with_commas(amount: int) -> String:
	var negative: bool = amount < 0
	var digits: String = str(abs(amount))
	var grouped: String = ""

	while digits.length() > 3:
		grouped = (
			"," + digits.substr(
				digits.length() - 3,
				3
			) + grouped
		)
		digits = digits.substr(
			0,
			digits.length() - 3
		)

	grouped = digits + grouped

	if negative:
		grouped = "-" + grouped

	return grouped
func emit_yearly_world_vitality_feed(
	context: Dictionary = {}
) -> Dictionary:
	var target_year: int = int(
		context.get(
			"target_year",
			context.get(
				"year",
				gs.year if gs != null else 0
			)
		)
	)
	var started_from_year: int = int(
		context.get(
			"started_from_year",
			target_year - 1
		)
	)
	var reality_mode: String = str(
		context.get(
			"reality_mode",
			gs.reality_mode
			if gs != null and "reality_mode" in gs
			else "realistic"
		)
	).strip_edges().to_lower()
	var era_name: String = str(
		context.get(
			"era_name",
			""
		)
	).strip_edges()
	var max_npc_events: int = maxi(
		0,
		int(
			context.get(
				"max_npc_events",
				18
			)
		)
	)
	var realm_event_scope: String = str(
		context.get(
			"realm_event_scope",
			"all_resident_realms"
		)
	).strip_edges().to_lower()

	if realm_event_scope == "":
		realm_event_scope = "all_resident_realms"

	var requested_max_realm_events: int = int(
		context.get(
			"max_realm_events",
			-1
		)
	)
	var max_realm_events: int = requested_max_realm_events

	if (
		realm_event_scope == "all_resident_realms"
		or requested_max_realm_events < 0
	):



		max_realm_events = 2147483647
	else:
		max_realm_events = maxi(
			0,
			requested_max_realm_events
		)

	var report: Dictionary = {
		"schema": "eralife.yearly_world_vitality_feed_report",
		"version": WORLD_CONTRACT_VERSION,
		"source": str(
			context.get(
				"source",
				"world_engine"
			)
		),
		"started_from_year": started_from_year,
		"target_year": target_year,
		"reality_mode": reality_mode,
		"era_name": era_name,
		"realm_event_scope": realm_event_scope,
		"already_applied": false,
		"queued": false,
		"is_complete": false,
		"npc_candidates": 0,
		"npc_events_emitted": 0,
		"realm_events_emitted": 0,
		"cosmic_events_emitted": 0,
		"death_events_emitted": 0,
		"crime_events_emitted": 0,
		"event_names": [],
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"uses_call_deferred": false,
		"npc_checks_max_per_process_frame": 1,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	if gs == null:
		return report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var registry_raw: Variant = gs.scenario_state.get(
		"yearly_world_vitality_feed_registry",
		{}
	)
	var registry: Dictionary = (
		registry_raw as Dictionary
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var feed_key: String = "world_vitality|%d|%s|%s" % [
		target_year,
		reality_mode,
		era_name
	]

	if bool(
		registry.get(
			feed_key,
			false
		)
	):
		report ["already_applied"] = true
		report ["is_complete"] = true
		return report

	var jobs_raw: Variant = get_meta(
		"yearly_world_vitality_feed_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)

	if jobs.has(feed_key):
		var existing_raw: Variant = jobs.get(
			feed_key,
			{}
		)
		if typeof(existing_raw) == TYPE_DICTIONARY:
			var existing_job: Dictionary = existing_raw as Dictionary
			var existing_report_raw: Variant = existing_job.get(
				"report",
				{}
			)
			if typeof(existing_report_raw) == TYPE_DICTIONARY:
				report = (
					(existing_report_raw as Dictionary).duplicate(false)
				)

		report ["queued"] = true
		report ["already_queued"] = true
		_arm_yearly_world_vitality_feed_service()
		return report

	var order_raw: Variant = get_meta(
		"yearly_world_vitality_feed_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	var runtime_context: Dictionary = context.duplicate(false)
	runtime_context ["started_from_year"] = started_from_year
	runtime_context ["target_year"] = target_year
	runtime_context ["reality_mode"] = reality_mode
	runtime_context ["era_name"] = era_name
	runtime_context ["max_npc_events"] = max_npc_events
	runtime_context ["realm_event_scope"] = realm_event_scope
	runtime_context ["max_realm_events"] = max_realm_events
	runtime_context ["background_only"] = true
	runtime_context ["blocks_ui"] = false
	runtime_context ["requires_input_idle"] = false
	runtime_context ["uses_call_deferred"] = false
	runtime_context ["ready_gate_member"] = false

	var npc_count: int = gs.npcs.size()
	var npc_scan_origin: int = 0

	if npc_count > 0:
		npc_scan_origin = (
			abs(
				hash(
					"world_vitality_origin|%d|%s|%s|%d"
					% [
						target_year,
						reality_mode,
						era_name,
						npc_count
					]
				)
			)
			% npc_count
		)

	report ["npc_candidates"] = npc_count
	report ["queued"] = true

	jobs [feed_key] = {
		"feed_key": feed_key,
		"context": runtime_context,
		"phase": (
			"realms"
			if bool(
				context.get(
					"emit_realm_stats",
					true
				)
			) and max_realm_events > 0
			else "npcs"
		),
		"realm_cursor": 0,
		"npc_cursor": 0,
		"npc_scan_origin": npc_scan_origin,
		"npc_scan_total": npc_count,
		"report": report,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if not order.has(feed_key):
		order.append(feed_key)

	set_meta(
		"yearly_world_vitality_feed_jobs",
		jobs
	)
	set_meta(
		"yearly_world_vitality_feed_order",
		order
	)
	set_meta(
		"yearly_world_vitality_feed_requires_input_idle",
		false
	)
	set_meta(
		"yearly_world_vitality_feed_uses_call_deferred",
		false
	)
	set_meta(
		"yearly_world_vitality_feed_blocks_ui",
		false
	)

	_arm_yearly_world_vitality_feed_service()

	return report
func _arm_yearly_world_vitality_feed_service() -> void:
	var order_raw: Variant = get_meta(
		"yearly_world_vitality_feed_order",
		[]
	)
	var order: Array = (
		order_raw as Array
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"yearly_world_vitality_feed_service_active",
			false
		)
		return

	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		set_meta(
			"yearly_world_vitality_feed_service_active",
			false
		)
		return

	var callback:= Callable(
		self,
		"_drive_yearly_world_vitality_feed_process_frame"
	)

	if tree.process_frame.is_connected(callback):
		set_meta(
			"yearly_world_vitality_feed_service_active",
			true
		)
		return

	tree.process_frame.connect(callback)
	set_meta(
		"yearly_world_vitality_feed_service_active",
		true
	)


func _drive_yearly_world_vitality_feed_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_yearly_world_vitality_feed_process_frame"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(callback)
	):
		tree.process_frame.disconnect(callback)

	set_meta(
		"yearly_world_vitality_feed_service_active",
		false
	)

	_service_yearly_world_vitality_feed_quantum()
	_arm_yearly_world_vitality_feed_service()


func _world_vitality_realm_event_for_resident_id(
	realm_id: int,
	context: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.realm_engine == null
		or not ("realms" in gs.realm_engine)
		or realm_id < 0
	):
		return {}

	var realms_raw: Variant = gs.realm_engine.realms
	if typeof(realms_raw) != TYPE_DICTIONARY:
		return {}

	var realms: Dictionary = realms_raw as Dictionary
	var realm_raw: Variant = realms.get(
		realm_id,
		realms.get(
			str(realm_id),
			{}
		)
	)
	if typeof(realm_raw) != TYPE_DICTIONARY:
		return {}

	var realm: Dictionary = realm_raw as Dictionary
	var realm_name: String = str(
		realm.get(
			"name",
			"Unknown Realm"
		)
	).strip_edges()

	if realm_name == "":
		realm_name = "Unknown Realm"

	var target_year: int = int(
		context.get(
			"target_year",
			gs.year
		)
	)
	var reality_mode: String = str(
		context.get(
			"reality_mode",
			gs.reality_mode
			if "reality_mode" in gs
			else "realistic"
		)
	).strip_edges()
	var era_name: String = str(
		context.get(
			"era_name",
			""
		)
	).strip_edges()
	var population: int = int(
		realm.get(
			"population",
			realm.get(
				"population_estimate",
				realm.get(
					"resident_count",
					0
				)
			)
		)
	)
	var stability: int = clampi(
		int(
			realm.get(
				"stability",
				realm.get(
					"public_order",
					realm.get(
						"cohesion",
						50
					)
				)
			)
		),
		0,
		100
	)
	var treasury: int = int(
		realm.get(
			"treasury",
			realm.get(
				"wealth",
				realm.get(
					"economy",
					0
				)
			)
		)
	)
	var war_heat: int = int(
		realm.get(
			"war_heat",
			realm.get(
				"military_pressure",
				realm.get(
					"conflict_pressure",
					0
				)
			)
		)
	)
	var year_text: String = _world_vitality_year_label(target_year)
	var population_text: String = _world_vitality_format_integer_with_commas(
		population
	)
	var treasury_text: String = _world_vitality_format_integer_with_commas(
		treasury
	)
	var world_text: String = (
		"REALM WATCH: %s has entered %s with a population of %s, "
		+ "a stability of %d%%, and a Treasury of %s."
	) % [
		realm_name,
		year_text,
		population_text,
		stability,
		treasury_text
	]

	return {
		"type": "world_feed_entry",
		"event_name": "realm_yearly_stats",
		"source": "world_engine.yearly_realm_stats",
		"category": "realm",
		"year": target_year,
		"realm_id": realm_id,
		"text": world_text,
		"world_text": world_text,
		"personally_relevant": false,
		"suppress_diary": true,
		"realm_stats": {
			"population": population,
			"stability": stability,
			"treasury": treasury,
			"wealth": treasury,
			"war_heat": war_heat,
			"reality_mode": reality_mode,
			"era_name": era_name
		}
	}


func _service_yearly_world_vitality_feed_quantum() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var order_raw: Variant = get_meta(
		"yearly_world_vitality_feed_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)
	if order.is_empty():
		return

	var jobs_raw: Variant = get_meta(
		"yearly_world_vitality_feed_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)

	var feed_key: String = str(
		order.pop_front()
	)
	var job_raw: Variant = jobs.get(
		feed_key,
		{}
	)
	if typeof(job_raw) != TYPE_DICTIONARY:
		jobs.erase(feed_key)
		set_meta(
			"yearly_world_vitality_feed_order",
			order
		)
		set_meta(
			"yearly_world_vitality_feed_jobs",
			jobs
		)
		return

	var job: Dictionary = job_raw as Dictionary
	var context_raw: Variant = job.get(
		"context",
		{}
	)
	var context: Dictionary = (
		context_raw as Dictionary
		if typeof(context_raw) == TYPE_DICTIONARY
		else {}
	)
	var report_raw: Variant = job.get(
		"report",
		{}
	)
	var report: Dictionary = (
		report_raw as Dictionary
		if typeof(report_raw) == TYPE_DICTIONARY
		else {}
	)
	var target_year: int = int(
		context.get(
			"target_year",
			gs.year
		)
	)
	var source_year: int = int(
		context.get(
			"started_from_year",
			target_year - 1
		)
	)
	var phase: String = str(
		job.get(
			"phase",
			"realms"
		)
	).strip_edges().to_lower()
	var complete: bool = false

	if phase == "realms":
		var max_realm_events: int = maxi(
			0,
			int(
				context.get(
					"max_realm_events",
					5
				)
			)
		)
		var realm_emitted: int = int(
			report.get(
				"realm_events_emitted",
				0
			)
		)
		var realm_cursor: int = int(
			job.get(
				"realm_cursor",
				0
			)
		)
		var realm_count: int = 0

		if (
			gs.realm_engine != null
			and gs.realm_engine.has_method(
				"resident_realm_identity_count"
			)
		):
			realm_count = int(
				gs.realm_engine.resident_realm_identity_count()
			)

		if (
			max_realm_events <= 0
			or realm_emitted >= max_realm_events
			or realm_cursor >= realm_count
		):
			job ["phase"] = "npcs"
		else:
			var realm_id: int = int(
				gs.realm_engine.resident_realm_id_at(
					realm_cursor
				)
			)
			job ["realm_cursor"] = realm_cursor + 1

			var event: Dictionary = (
				_world_vitality_realm_event_for_resident_id(
					realm_id,
					context
				)
			)

			if (
				not event.is_empty()
				and _world_vitality_push_event(
					event,
					report
				)
			):
				report ["realm_events_emitted"] = (
					realm_emitted + 1
				)

			if (
				int(job.get("realm_cursor", 0)) >= realm_count
				or int(
					report.get(
						"realm_events_emitted",
						0
					)
				) >= max_realm_events
			):
				job ["phase"] = "npcs"

	elif phase == "npcs":
		var max_npc_events: int = maxi(
			0,
			int(
				context.get(
					"max_npc_events",
					18
				)
			)
		)
		var age_report_raw: Variant = gs.scenario_state.get(
			"last_world_engine_age_npcs_report",
			{}
		)
		var age_report: Dictionary = (
			age_report_raw as Dictionary
			if typeof(age_report_raw) == TYPE_DICTIONARY
			else {}
		)
		var age_truth_complete: bool = (
			_world_age_npcs_completion_receipt_is_valid(
				age_report,
				source_year,
				target_year
			)
		)

		if not age_truth_complete:
			report ["waiting_for_age_truth"] = true
			report ["waiting_for_age_truth_year"] = target_year
		else:
			report ["waiting_for_age_truth"] = false

			var npc_total: int = int(
				job.get(
					"npc_scan_total",
					gs.npcs.size()
				)
			)
			npc_total = mini(
				npc_total,
				gs.npcs.size()
			)
			var npc_cursor: int = int(
				job.get(
					"npc_cursor",
					0
				)
			)
			var npc_origin: int = int(
				job.get(
					"npc_scan_origin",
					0
				)
			)
			var emitted_npc_events: int = int(
				report.get(
					"npc_events_emitted",
					0
				)
			)

			if (
				max_npc_events <= 0
				or emitted_npc_events >= max_npc_events
				or npc_cursor >= npc_total
			):
				complete = true
			else:
				var checks: int = 0
				var emitted_this_quantum: bool = false

				while (
					checks < 1
					and npc_cursor < npc_total
					and not emitted_this_quantum
				):
					var npc_index: int = (
						(npc_origin + npc_cursor)
						% maxi(
							1,
							npc_total
						)
					)
					npc_cursor += 1
					checks += 1

					var npc: Person = gs.npcs [npc_index]
					if npc == null:
						continue
					if (
						gs.player != null
						and int(npc.id) == int(gs.player.id)
					):
						continue

					if (
						not bool(npc.alive)
						and "death_year" in npc
					):
						var canonical_death_year: int = int(
							npc.death_year
						)
						if (
							canonical_death_year > -999000
							and canonical_death_year != target_year
						):
							continue

					var event: Dictionary = (
						_world_vitality_event_for_npc(
							npc,
							target_year,
							str(
								context.get(
									"reality_mode",
									"realistic"
								)
							),
							str(
								context.get(
									"era_name",
									""
								)
							)
						)
					)
					if event.is_empty():
						continue

					if _world_vitality_push_event(
						event,
						report
					):
						emitted_this_quantum = true
						emitted_npc_events += 1
						report ["npc_events_emitted"] = emitted_npc_events

						var event_category: String = str(
							event.get(
								"category",
								""
							)
						).strip_edges().to_lower()
						var event_name: String = str(
							event.get(
								"event_name",
								""
							)
						).strip_edges().to_lower()

						if event_category == "cosmic":
							report ["cosmic_events_emitted"] = int(
								report.get(
									"cosmic_events_emitted",
									0
								)
							) + 1
						if event_category == "crime":
							report ["crime_events_emitted"] = int(
								report.get(
									"crime_events_emitted",
									0
								)
							) + 1
						if event_name == "npc_died":
							report ["death_events_emitted"] = int(
								report.get(
									"death_events_emitted",
									0
								)
							) + 1
							if (
								"death_year" in npc
								and int(npc.death_year) <= -999000
							):
								npc.death_year = target_year

				job ["npc_cursor"] = npc_cursor
				report ["npc_checks_this_quantum"] = checks

				complete = (
					npc_cursor >= npc_total
					or emitted_npc_events >= max_npc_events
				)

	else:
		complete = true

	job ["report"] = report
	job ["last_serviced_at_ms"] = int(
		Time.get_ticks_msec()
	)

	if complete:
		report ["is_complete"] = true
		report ["completed_at_ms"] = int(
			Time.get_ticks_msec()
		)

		var registry_raw: Variant = gs.scenario_state.get(
			"yearly_world_vitality_feed_registry",
			{}
		)
		var registry: Dictionary = (
			(registry_raw as Dictionary).duplicate(false)
			if typeof(registry_raw) == TYPE_DICTIONARY
			else {}
		)
		registry [feed_key] = true
		gs.scenario_state [
			"yearly_world_vitality_feed_registry"
		] = registry
		gs.scenario_state [
			"last_yearly_world_vitality_feed_report"
		] = report.duplicate(false)
		jobs.erase(feed_key)
	else:
		jobs [feed_key] = job
		order.append(feed_key)

	set_meta(
		"yearly_world_vitality_feed_order",
		order
	)
	set_meta(
		"yearly_world_vitality_feed_jobs",
		jobs
	)
	set_meta(
		"yearly_world_vitality_feed_last_key",
		feed_key
	)
	set_meta(
		"yearly_world_vitality_feed_last_phase",
		str(
			job.get(
				"phase",
				phase
			)
		)
	)
	set_meta(
		"yearly_world_vitality_feed_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"yearly_world_vitality_feed_last_blocks_ui",
		false
	)
	set_meta(
		"yearly_world_vitality_feed_last_requires_input_idle",
		false
	)
	set_meta(
		"yearly_world_vitality_feed_last_used_call_deferred",
		false
	)


func _world_vitality_candidate_npcs(target_year: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs == null:
		return out

	if gs.spatial_culling_engine != null and gs.spatial_culling_engine.has_method("classify"):
		var groups: Variant = gs.spatial_culling_engine.classify()
		if typeof(groups) == TYPE_DICTIONARY:
			var group_dict: Dictionary = groups
			for npc in _world_vitality_safe_array(group_dict.get("near", [])):
				_world_vitality_append_candidate(out, seen, npc)
			for npc in _world_vitality_safe_array(group_dict.get("mid", [])):
				_world_vitality_append_candidate(out, seen, npc)

	if gs.player != null:
		for npc in gs.npcs:
			if npc == null:
				continue
			if _world_engine_personally_relevant(npc):
				_world_vitality_append_candidate(out, seen, npc)

	for npc in gs.npcs:
		if npc == null:
			continue
		if bool(npc.is_ruler) or bool(npc.is_royal) or int(npc.fame) >= 60:
			_world_vitality_append_candidate(out, seen, npc)

	var npc_count: int = gs.npcs.size()
	if npc_count <= 0:
		return out

	var scan_limit: int = min(npc_count, 80)
	for i in range(scan_limit):
		var idx: int = abs(hash("world_vitality_candidate|%d|%d|%d" % [target_year, i, npc_count])) % npc_count
		var sampled = gs.npcs [idx]
		_world_vitality_append_candidate(out, seen, sampled)

	return out


func _world_vitality_append_candidate(out: Array, seen: Dictionary, npc) -> void:
	if npc == null:
		return
	if not ("id" in npc):
		return
	var npc_id: int = int(npc.id)
	if npc_id <= 0:
		return
	if seen.has(npc_id):
		return
	if gs != null and gs.player != null and npc_id == int(gs.player.id):
		return
	seen [npc_id] = true
	out.append(npc)


func _world_vitality_event_for_npc(npc: Person, target_year: int, reality_mode: String, era_name: String) -> Dictionary:
	if gs == null or npc == null:
		return {}

	var npc_name: String = _world_engine_full_name(npc)
	var relation_label: String = _world_engine_relation_label(npc)
	var personally_relevant: bool = _world_engine_personally_relevant(npc)
	var realm_name: String = _world_vitality_realm_name_for_npc(npc)
	var age_value: int = int(npc.age)

	if not bool(npc.alive):
		var cause: String = str(npc.cause_of_death).strip_edges()
		if cause == "":
			return {}
		return _world_vitality_make_event(
			"npc_died",
			"death",
			"%s died at age %d. Cause: %s." % [npc_name, age_value, cause],
			"My %s died at age %d. Cause: %s." % [relation_label.to_lower(), age_value, cause] if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	var roll_seed: String = "%d|%d|%s|%s|world_vitality" % [
		int(npc.id),
		target_year,
		reality_mode,
		era_name
	]
	var roll: int = abs(hash(roll_seed)) % 1000

	if personally_relevant:
		roll = max(0, roll - 90)
	if bool(npc.is_ruler) or bool(npc.is_royal):
		roll = max(0, roll - 55)
	if int(npc.fame) >= 70:
		roll = max(0, roll - 35)

	if age_value >= 78 and roll < 45:
		var cause_text: String = "old age"
		if int(npc.health) < 35:
			cause_text = "declining health"
		npc.alive = false
		npc.health = 0
		npc.cause_of_death = cause_text
		return _world_vitality_make_event(
			"npc_died",
			"death",
			"%s died at age %d. Cause: %s." % [npc_name, age_value, cause_text],
			"My %s died at age %d. Cause: %s." % [relation_label.to_lower(), age_value, cause_text] if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if age_value < 13:
		if roll < 220:
			return _world_vitality_make_event(
				"npc_childhood_milestone",
				"life",
				"%s spent the year growing up in %s." % [npc_name, realm_name],
				"My %s spent the year growing up." % relation_label.to_lower() if relation_label != "" else "",
				npc,
				target_year,
				personally_relevant
			)
		return {}

	if roll < 145:
		var career_text: String = "took on new work"
		if str(npc.job).strip_edges() != "":
			career_text = "made progress as a %s" % str(npc.job)
		elif age_value < 22:
			career_text = "kept building their future"
		return _world_vitality_make_event(
			"npc_life_progress",
			"life",
			"%s %s in %s." % [npc_name, career_text, realm_name],
			"My %s %s." % [relation_label.to_lower(), career_text] if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if roll < 250:
		return _world_vitality_make_event(
			"npc_relationship_shift",
			"relationship",
			"%s's relationships shifted quietly this year in %s." % [npc_name, realm_name],
			"My %s's relationships shifted this year." % relation_label.to_lower() if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if roll < 350 and age_value >= 16:
		return _world_vitality_make_event(
			"npc_crime_pressure",
			"crime",
			"%s was linked to a crime rumor in %s." % [npc_name, realm_name],
			"My %s was linked to a crime rumor." % relation_label.to_lower() if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if roll < 475 and _world_vitality_mode_allows_cosmic(reality_mode):
		var artifact_line: String = "%s crossed paths with a cosmic artifact in %s." % [npc_name, realm_name]
		if roll % 3 == 0:
			artifact_line = "%s found a cosmic artifact in %s, and nobody agrees on what it did." % [npc_name, realm_name]
		elif roll % 3 == 1:
			artifact_line = "%s tried to use a strange artifact in %s." % [npc_name, realm_name]
		return _world_vitality_make_event(
			"npc_cosmic_artifact_event",
			"cosmic",
			artifact_line,
			"My %s crossed paths with a cosmic artifact." % relation_label.to_lower() if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if roll < 610 and realm_name != "the world":
		return _world_vitality_make_event(
			"npc_realm_pressure",
			"realm",
			"%s was pulled into the yearly pressure of %s." % [npc_name, realm_name],
			"My %s was pulled into local realm pressure." % relation_label.to_lower() if relation_label != "" else "",
			npc,
			target_year,
			personally_relevant
		)

	if personally_relevant and roll < 760:
		return _world_vitality_make_event(
			"npc_quiet_year",
			"life",
			"%s had a quiet but meaningful year." % npc_name,
			"My %s had a quiet but meaningful year." % relation_label.to_lower() if relation_label != "" else "",
			npc,
			target_year,
			true
		)

	return {}


func _world_vitality_make_event(event_name: String, category: String, world_text: String, player_text: String, npc: Person, target_year: int, personally_relevant: bool) -> Dictionary:
	return {
		"type": "world_feed_entry",
		"event_name": event_name,
		"source": "world_engine.yearly_world_vitality",
		"category": category,
		"year": target_year,
		"npc_id": int(npc.id) if npc != null else -1,
		"text": world_text,
		"world_text": world_text,
		"player_text": player_text,
		"journal_text": player_text,
		"personally_relevant": personally_relevant,
		"diary_scope": "family" if personally_relevant else "world",
		"suppress_diary": not personally_relevant
	}


func _world_vitality_push_event(event: Dictionary, report: Dictionary) -> bool:
	if gs == null:
		return false

	var text: String = str(event.get("world_text", event.get("text", ""))).strip_edges()
	if text == "":
		return false

	var meta: Dictionary = event.duplicate(true)
	if not meta.has("type"):
		meta ["type"] = "world_feed_entry"
	if not meta.has("source"):
		meta ["source"] = "world_engine.yearly_world_vitality"

	var event_category: String = str(meta.get("category", "")).strip_edges().to_lower()
	var event_name: String = str(meta.get("event_name", "")).strip_edges().to_lower()
	var npc_id: int = int(meta.get("npc_id", -1))

	if event_category == "death" or event_name == "npc_died":
		var dead_npc: Person = gs.get_or_reactivate_npc_by_id(npc_id) if gs.has_method("get_or_reactivate_npc_by_id") else null
		if dead_npc != null:
			var full_name: String = ("%s %s" % [str(dead_npc.first_name), str(dead_npc.last_name)]).strip_edges()
			var cause: String = str(dead_npc.cause_of_death).strip_edges()
			if cause == "":
				cause = str(meta.get("cause", "unknown causes")).strip_edges()
			if cause == "":
				cause = "unknown causes"

			if gs.has_method("build_death_world_feed_text"):
				text = gs.build_death_world_feed_text(
					full_name,
					int(dead_npc.age),
					cause,
					int(dead_npc.id)
				)
				meta ["text"] = text
				meta ["world_text"] = text

			if gs.has_method("queue_known_person_death_message"):
				gs.queue_known_person_death_message(dead_npc)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(text, meta)

	report ["event_names"].append(str(meta.get("event_name", "world_vitality")))
	return true


func _emit_yearly_realm_stat_feed(
	context: Dictionary,
	report: Dictionary,
	max_realm_events: int
) -> void:
	if gs == null or max_realm_events == 0:
		return
	if gs.realm_engine == null:
		return
	if not ("realms" in gs.realm_engine):
		return

	var realms_raw: Variant = gs.realm_engine.realms
	if typeof(realms_raw) != TYPE_DICTIONARY:
		return

	var realms: Dictionary = realms_raw
	var keys: Array = realms.keys()
	keys.sort()

	var emitted: int = 0
	var target_year: int = int(context.get("target_year", gs.year))
	var reality_mode: String = str(
		context.get(
			"reality_mode",
			gs.reality_mode if "reality_mode" in gs else "realistic"
		)
	).strip_edges()
	var era_name: String = str(context.get("era_name", "")).strip_edges()

	for raw_key in keys:
		if max_realm_events > 0 and emitted >= max_realm_events:
			break

		var realm_raw: Variant = realms.get(raw_key, {})
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		var realm_name: String = str(
			realm.get(
				"name",
				"Unknown Realm"
			)
		).strip_edges()

		if realm_name == "":
			realm_name = "Unknown Realm"

		var population: int = int(
			realm.get(
				"population",
				realm.get(
					"population_estimate",
					realm.get(
						"resident_count",
						0
					)
				)
			)
		)
		var stability: int = clampi(
			int(
				realm.get(
					"stability",
					realm.get(
						"public_order",
						realm.get(
							"cohesion",
							50
						)
					)
				)
			),
			0,
			100
		)
		var treasury: int = int(
			realm.get(
				"treasury",
				realm.get(
					"wealth",
					realm.get(
						"economy",
						0
					)
				)
			)
		)
		var war_heat: int = int(
			realm.get(
				"war_heat",
				realm.get(
					"military_pressure",
					realm.get(
						"conflict_pressure",
						0
					)
				)
			)
		)
		var year_text: String = _world_vitality_year_label(target_year)
		var population_text: String = _world_vitality_format_integer_with_commas(
			population
		)
		var treasury_text: String = _world_vitality_format_integer_with_commas(
			treasury
		)
		var world_text: String = (
			"REALM WATCH: %s has entered %s with a population of %s, "
			+ "a stability of %d%%, and a Treasury of %s."
		) % [
			realm_name,
			year_text,
			population_text,
			stability,
			treasury_text
		]

		var event: Dictionary = {
			"type": "world_feed_entry",
			"event_name": "realm_yearly_stats",
			"source": "world_engine.yearly_realm_stats",
			"category": "realm",
			"year": target_year,
			"realm_id": raw_key,
			"text": world_text,
			"world_text": world_text,
			"personally_relevant": false,
			"suppress_diary": true,
			"realm_stats": {
				"population": population,
				"stability": stability,
				"treasury": treasury,
				"wealth": treasury,
				"war_heat": war_heat,
				"reality_mode": reality_mode,
				"era_name": era_name
			}
		}

		if _world_vitality_push_event(event, report):
			emitted += 1
			report ["realm_events_emitted"] = emitted

func _world_vitality_realm_name_for_npc(npc: Person) -> String:
	if gs == null or npc == null:
		return "the world"

	var realm_id: int = -1
	if "realm_id" in npc:
		realm_id = int(npc.realm_id)

	if realm_id > 0 and gs.realm_engine != null and "realms" in gs.realm_engine:
		var realms_raw: Variant = gs.realm_engine.realms
		if typeof(realms_raw) == TYPE_DICTIONARY:
			var realms: Dictionary = realms_raw
			var realm_raw: Variant = realms.get(realm_id, realms.get(str(realm_id), {}))
			if typeof(realm_raw) == TYPE_DICTIONARY:
				var realm: Dictionary = realm_raw
				var realm_name: String = str(realm.get("name", "")).strip_edges()
				if realm_name != "":
					return realm_name

	if "home_country" in npc and str(npc.home_country).strip_edges() != "":
		return str(npc.home_country).strip_edges()
	if "birth_country" in npc and str(npc.birth_country).strip_edges() != "":
		return str(npc.birth_country).strip_edges()

	return "the world"


func _world_vitality_mode_allows_cosmic(reality_mode: String) -> bool:
	var clean_mode: String = str(reality_mode).strip_edges().to_lower()
	if clean_mode in ["fantasy", "custom", "chaos", "enhanced", "supernatural"]:
		return true
	if gs != null and "custom_mode" in gs and bool(gs.custom_mode):
		return true
	return false


func _world_vitality_safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []
func _emit_npc_age_event(
	npc: Person,
	previous_age: int,
	new_age: int,
	target_year: int
) -> void:
	if gs == null or npc == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var full_name: String = _world_engine_full_name(
		npc
	)
	var personally_relevant: bool = (
		_world_engine_personally_relevant(
			npc
		)
	)
	var relation_label: String = (
		_world_engine_relation_label(
			npc
		)
	)
	var world_text: String = "%s turned %d." % [
		full_name,
		new_age
	]

	var player_text: String = ""

	if personally_relevant:
		if relation_label != "":
			player_text = "My %s turned %d." % [
				relation_label.to_lower(),
				new_age
			]
		else:
			player_text = "%s turned %d." % [
				full_name,
				new_age
			]

	var entry:= {
		"type": "world_feed_entry",
		"event_name": "npc_aged",
		"source": "world_engine",
		"category": "life",
		"year": target_year,
		"npc_id": int(npc.id),
		"text": world_text,
		"world_text": world_text,
		"player_text": player_text,
		"journal_text": player_text,
		"relation_label": relation_label,
		"personally_relevant": personally_relevant,
		"diary_scope": "family" if personally_relevant else "world",
		"suppress_diary": not personally_relevant,
		"previous_age": previous_age,
		"age": new_age
	}

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			world_text,
			entry
		)







	if (
		personally_relevant
		and gs.player != null
		and gs.reality_projection_contract_engine != null
		and gs.reality_projection_contract_engine.has_method(
			"queue_resident_relationship_section_refresh"
		)
	):
		gs.reality_projection_contract_engine.queue_resident_relationship_section_refresh(
			int(
				gs.player.id
			),
			[
				"family",
				"partner",
				"household",
				"ancestors",
				"descendants",
				"dead",
				"social",
				"exes",
				"pets"
			],
			{
				"source": (
					"world_engine."
					+ "npc_temporal_truth_relationship_projection"
				),
				"reason": "personally_relevant_npc_age_committed",
				"temporal_actor_id": int(
					npc.id
				),
				"previous_age": previous_age,
				"age": new_age,
				"source_year": target_year - 1,
				"target_year": target_year,
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"ui_interaction_grace_ignored": true,
				"build_on_click_forbidden": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)




	var packet_cache_raw: Variant = gs.scenario_state.get(
		"profile_pointer_packet_by_actor",
		{}
	)
	var actor_has_resident_switch_pointer: bool = (
		typeof(packet_cache_raw) == TYPE_DICTIONARY
		and (packet_cache_raw as Dictionary).has(
			str(
				int(
					npc.id
				)
			)
		)
	)

	if (
		actor_has_resident_switch_pointer
		and gs.universal_switch_contract_engine != null
		and gs.universal_switch_contract_engine.has_method(
			"queue_resident_profile_pointer_successor_refresh_for_actor"
		)
	):
		gs.universal_switch_contract_engine.queue_resident_profile_pointer_successor_refresh_for_actor(
			int(
				npc.id
			),
			target_year - 1,
			target_year,
			{
				"source": (
					"world_engine."
					+ "npc_temporal_truth_switch_successor"
				),
				"reason": "npc_age_truth_committed",
				"previous_age": previous_age,
				"age": new_age,
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"build_on_click_forbidden": true,
				"switch_press_build_forbidden": true,
				"ready_gate_member": false,
				"preserve_existing_switch_readiness": true,
				"ui_is_renderer_only": true
			}
		)

	if (
		personally_relevant
		and player_text != ""
		and gs.narrative_engine != null
	):
		gs.narrative_engine.log_event(
			gs.player,
			{
				"type": "text",
				"text": player_text,
				"source": "world_engine",
				"category": "life",
				"event_name": "npc_aged",
				"npc_id": int(npc.id),
				"personally_relevant": true,
				"diary_scope": "family",
				"suppress_world_feed": true
			}
		)

	_world_engine_maybe_log_family_school_transition(
		npc,
		previous_age,
		new_age,
		target_year
	)




func npc_have_children() -> Dictionary:
	var report:= {
		"schema": "eralife.world_engine_birth_report",
		"version": WORLD_CONTRACT_VERSION,
		"year": int(gs.year) if gs != null else 0,
		"births": 0,
		"birth_ids": [],
		"visible_events": 0
	}

	if gs == null:
		return report

	for npc in gs.npcs:
		if npc == null:
			continue

		var partner = gs.get_valid_partner(npc, true)

		if partner != null and npc.age > 20 and npc.age < 45:
			if randi() % 500 == 1:
				var baby = gs.spawn_child(npc, partner, true)
				if baby == null:
					continue

				var parent_a_name: String = _world_engine_full_name(npc)
				var parent_b_name: String = _world_engine_full_name(partner)
				var baby_name: String = _world_engine_full_name(baby)
				var event_text: String = "%s and %s had a child named %s." % [
					parent_a_name,
					parent_b_name,
					baby_name
				]

				report ["births"] = int(report.get("births", 0)) + 1
				report ["birth_ids"].append(int(baby.id))

				_world_engine_log_first_person_memory(npc, "I had a child named %s." % baby_name, {
					"event_name": "npc_born",
					"category": "life",
					"target_id": int(baby.id)
				})

				_world_engine_log_first_person_memory(partner, "I had a child named %s." % baby_name, {
					"event_name": "npc_born",
					"category": "life",
					"target_id": int(baby.id)
				})

				var personally_relevant: bool = _world_engine_birth_relevant_to_player(npc, partner, baby)
				var player_text: String = _world_engine_birth_player_text(npc, partner, baby)

				var entry:= {
					"type": "world_feed_entry",
					"event_name": "npc_born",
					"source": "world_engine",
					"category": "life",
					"year": int(gs.year),
					"npc_id": int(npc.id),
					"target_id": int(baby.id),
					"text": event_text,
					"world_text": event_text,
					"player_text": player_text,
					"journal_text": player_text,
					"personally_relevant": personally_relevant,
					"diary_scope": "family" if personally_relevant else "world",
					"suppress_diary": not personally_relevant,
					"queue_world_feed": true
				}

				if gs.has_method("push_world_feed"):
					gs.push_world_feed(event_text, entry)
					report ["visible_events"] = int(report.get("visible_events", 0)) + 1

				if personally_relevant and player_text != "" and gs.narrative_engine != null:
					gs.narrative_engine.log_event(gs.player, {
						"type": "text",
						"text": player_text,
						"source": "world_engine",
						"category": "life",
						"event_name": "npc_born",
						"npc_id": int(npc.id),
						"target_id": int(baby.id),
						"personally_relevant": true,
						"diary_scope": "family",
						"suppress_world_feed": true
					})
					_world_engine_queue_family_birth_popup(npc, partner, baby, player_text)

				if gs.event_bus != null:
					gs.event_bus.emit(ActionEventTypes.NPC_BORN, {
						"type": "npc_born",
						"npc_id": int(baby.id),
						"parent_a_id": int(npc.id),
						"parent_b_id": int(partner.id),
						"text": event_text,
						"world_feed_text": event_text,
						"player_text": player_text,
						"personally_relevant": personally_relevant,
						"year": int(gs.year),
						"source": "world_engine",
						"category": "life",
						"event_name": "npc_born",
						"suppress_world_feed": true
					})

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_world_engine_birth_report"] = report.duplicate(true)

	return report

func _world_engine_birth_relevant_to_player(parent_a: Person, parent_b: Person, baby: Person) -> bool:
	if gs == null or gs.player == null:
		return false
	if parent_a == null or parent_b == null or baby == null:
		return false

	if int(parent_a.id) == int(gs.player.id):
		return true
	if int(parent_b.id) == int(gs.player.id):
		return true
	if _world_engine_personally_relevant(parent_a):
		return true
	if _world_engine_personally_relevant(parent_b):
		return true
	if int(baby.id) in gs.player.children:
		return true
	if int(gs.player.id) in baby.parents:
		return true

	return false

func _world_engine_birth_player_text(parent_a: Person, parent_b: Person, baby: Person) -> String:
	if gs == null or gs.player == null or baby == null:
		return ""

	var baby_name: String = _world_engine_full_name(baby)
	var baby_relation: String = _world_engine_newborn_relationship_to_player(parent_a, parent_b, baby)

	if parent_a != null and int(parent_a.id) == int(gs.player.id):
		return "I had a child named %s." % baby_name
	if parent_b != null and int(parent_b.id) == int(gs.player.id):
		return "I had a child named %s." % baby_name

	var parent_a_label: String = _world_engine_relation_label(parent_a)
	if parent_a_label != "":
		return "My %s had a child named %s. %s is my %s." % [
			parent_a_label.to_lower(),
			baby_name,
			baby_name,
			baby_relation
		]

	var parent_b_label: String = _world_engine_relation_label(parent_b)
	if parent_b_label != "":
		return "My %s had a child named %s. %s is my %s." % [
			parent_b_label.to_lower(),
			baby_name,
			baby_name,
			baby_relation
		]

	return ""
func _world_engine_log_first_person_memory(person: Person, text: String, context: Dictionary = {}) -> void:
	if gs == null or person == null:
		return

	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return

	if gs.narrative_engine != null:
		var payload: Dictionary = {
			"type": "text",
			"text": clean_text,
			"life_diary_text": clean_text,
			"force_first_person_memory": true,
			"source": str(context.get("source", "world_engine")),
			"category": str(context.get("category", "life")),
			"event_name": str(context.get("event_name", "npc_life_event")),
			"npc_id": int(person.id),
			"suppress_world_feed": true
		}

		for key in context.keys():
			payload [key] = context [key]

		gs.narrative_engine.log_event(person, payload)
		return

	if gs.memory_engine != null:
		gs.memory_engine.remember(int(person.id), clean_text)


func _world_engine_maybe_log_family_school_transition(npc: Person, previous_age: int, new_age: int, target_year: int) -> void:
	if gs == null or gs.player == null or npc == null:
		return
	if not _world_engine_personally_relevant(npc):
		return

	var previous_stage: String = _world_engine_education_stage_for_age(previous_age)
	var new_stage: String = _world_engine_education_stage_for_age(new_age)

	if new_stage == "" or new_stage == previous_stage:
		return

	var relation_label: String = _world_engine_relation_label(npc)
	if relation_label == "":
		return

	var school_label: String = _world_engine_school_label_for_stage(new_stage)
	var full_name: String = _world_engine_full_name(npc)

	var player_text: String = "My %s started %s." % [
		relation_label.to_lower(),
		school_label
	]
	var npc_text: String = "I started %s." % school_label
	var world_text: String = "%s started %s." % [full_name, school_label]

	_world_engine_log_first_person_memory(npc, npc_text, {
		"source": "world_engine.school_transition",
		"category": "school",
		"event_name": "school_level_started",
		"year": target_year
	})

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(gs.player, {
			"type": "text",
			"text": player_text,
			"source": "world_engine.school_transition",
			"category": "school",
			"event_name": "family_school_level_started",
			"npc_id": int(npc.id),
			"personally_relevant": true,
			"diary_scope": "family",
			"suppress_world_feed": true
		})

	if int(npc.fame) >= 60 or bool(npc.is_royal) or bool(npc.is_ruler):
		if gs.has_method("push_world_feed"):
			gs.push_world_feed(world_text, {
				"type": "world_feed_entry",
				"event_name": "npc_school_level_started",
				"source": "world_engine.school_transition",
				"category": "school",
				"year": target_year,
				"npc_id": int(npc.id),
				"text": world_text,
				"world_text": world_text,
				"player_text": player_text,
				"personally_relevant": true,
				"diary_scope": "family",
				"suppress_diary": true
			})


func _world_engine_education_stage_for_age(age_value: int) -> String:
	if age_value == 5 or age_value == 6:
		return "lower"
	if age_value == 11 or age_value == 12:
		return "middle"
	if age_value == 14 or age_value == 15:
		return "upper"
	return ""


func _world_engine_school_label_for_stage(stage: String) -> String:
	var clean_stage: String = str(stage).strip_edges().to_lower()
	var era_name: String = ""
	if gs != null and gs.era != null:
		era_name = str(gs.era.get("name", "")).strip_edges()

	match era_name:
		"Ancient Era":
			match clean_stage:
				"lower":
					return "early lessons"
				"middle":
					return "scribe training"
				"upper":
					return "advanced academy"
		"Medieval Era":
			match clean_stage:
				"lower":
					return "parish lessons"
				"middle":
					return "guild schooling"
				"upper":
					return "upper academy"
		"Industrial Era":
			match clean_stage:
				"lower":
					return "primary school"
				"middle":
					return "secondary school"
				"upper":
					return "upper school"
		"Future Era":
			match clean_stage:
				"lower":
					return "foundation academy"
				"middle":
					return "mid-level academy"
				"upper":
					return "upper-level academy"
		_:
			match clean_stage:
				"lower":
					return "elementary school"
				"middle":
					return "middle school"
				"upper":
					return "high school"

	return "school"


func _world_engine_newborn_relationship_to_player(parent_a: Person, parent_b: Person, baby: Person) -> String:
	if gs == null or gs.player == null or baby == null:
		return "relative"

	var baby_gender: String = str(baby.gender).strip_edges().to_lower()
	var son_or_daughter: String = "son" if baby_gender == "male" else "daughter" if baby_gender == "female" else "child"
	var brother_or_sister: String = "brother" if baby_gender == "male" else "sister" if baby_gender == "female" else "sibling"
	var nephew_or_niece: String = "nephew" if baby_gender == "male" else "niece" if baby_gender == "female" else "nibling"
	var grandson_or_granddaughter: String = "grandson" if baby_gender == "male" else "granddaughter" if baby_gender == "female" else "grandchild"

	if int(gs.player.id) in baby.parents:
		return son_or_daughter

	if parent_a != null and int(parent_a.id) in gs.player.parents:
		return brother_or_sister
	if parent_b != null and int(parent_b.id) in gs.player.parents:
		return brother_or_sister

	if parent_a != null and parent_a.parents == gs.player.parents and int(parent_a.id) != int(gs.player.id):
		return nephew_or_niece
	if parent_b != null and parent_b.parents == gs.player.parents and int(parent_b.id) != int(gs.player.id):
		return nephew_or_niece

	if parent_a != null and int(parent_a.id) in gs.player.children:
		return grandson_or_granddaughter
	if parent_b != null and int(parent_b.id) in gs.player.children:
		return grandson_or_granddaughter

	return "relative"


func _world_engine_queue_family_birth_popup(parent_a: Person, parent_b: Person, baby: Person, player_text: String) -> void:
	if gs == null or baby == null:
		return
	if not gs.has_method("queue_year_resolution_popup"):
		return

	var clean_text: String = str(player_text).strip_edges()
	if clean_text == "":
		return

	var baby_name: String = _world_engine_full_name(baby)
	var baby_relation: String = _world_engine_newborn_relationship_to_player(parent_a, parent_b, baby)

	gs.queue_year_resolution_popup({
		"type": "year_resolution_popup",
		"popup_title": "New Family Member",
		"popup_text": "A new child was born in your family.\n\n%s\n\n%s is your %s." % [
			clean_text,
			baby_name,
			baby_relation
		],
		"popup_footer": "Tap anywhere to continue.",
		"text": clean_text,
		"newborn_id": int(baby.id),
		"relationship_label": baby_relation,
		"suppress_world_feed": true
	})




func process_divorces():
	for npc in gs.npcs:
		var partner = gs.get_valid_partner(npc, true)
		if partner == null:
			continue

		if randi() % 2000 == 1:
			gs.narrative_engine.log_event(npc, {
				"type": "text",
				"text": "%s and %s have divorced." % [
					npc.first_name, partner.first_name
				]
			})

			gs.end_partnership(npc, true)

			gs.event_bus.emit(ActionEventTypes.NPC_DIVORCED, {
				"npc_id": npc.id,
				"text": "%s and %s divorced." % [npc.first_name, partner.first_name]
			})




func process_remarriages():


	var singles: Array = []
	for npc in gs.npcs:
		var partner = gs.get_valid_partner(npc, true)
		if partner == null and npc.alive and npc.age >= 18:
			if npc.marital_status == "Single":
				singles.append(npc)


	for npc in singles:
		if randi() % 5000 == 1 and singles.size() > 1:

			var other = singles [randi() % singles.size()]
			if other == npc:
				continue


			npc.partner = other
			other.partner = npc
			gs.social_graph_engine.connect_people(npc.id, other.id)
			npc.marital_status = "Married"
			other.marital_status = "Married"
			gs.event_bus.emit(ActionEventTypes.NPC_MARRIED, {
				"npc_id": npc.id,
				"text": "%s married %s." % [npc.first_name, other.first_name]
			})

			gs.narrative_engine.log_event(npc, {
				"type": "text",
				"text": "%s married %s." % [
					npc.first_name, other.first_name
				]
			})


			_process_step_parent_effects(npc, other)



func _marital_status_available_for_remarriage(
	person: Person
) -> bool:
	if person == null:
		return false

	return (
		str(
			person.marital_status
		).strip_edges().to_lower()
		in [
			"single",
			"divorced",
			"widow",
			"widower",
			"widowed"
		]
	)
func _process_step_parent_effects(a, b):


	for cid in a.children:
		var c = gs.get_npc_by_id(cid)
		if c != null:
			c.memories.append(
				"My %s married %s." % [
					"father" if a.gender == "Male" else "mother",
					b.first_name
				]
			)


	for cid in b.children:
		var c = gs.get_npc_by_id(cid)
		if c != null:
			c.memories.append(
				"My %s married %s." % [
					"father" if b.gender == "Male" else "mother",
					a.first_name
				]
			)





func process_movement():
	for npc in gs.npcs:
		if not npc.alive:
			continue
		if gs.family_control_engine != null:
			if gs.family_control_engine.is_in_player_household_cluster(npc):
				continue
			if gs.family_control_engine.is_minor_under_custodial_authority(npc):
				continue

		if randi() % 3000 == 1:
			var locs = gs.era_engine.get_birth_locations()
			if locs.is_empty():
				continue
			var new_place = locs [randi() % locs.size()]
			npc.home_city = str(new_place.get("city", npc.home_city))
			npc.home_country = str(new_place.get("country", npc.home_country))
			gs.event_bus.emit(ActionEventTypes.NPC_MOVED, {
				"npc_id": npc.id,
				"text": "%s moved to %s, %s." % [
					npc.first_name,
					str(new_place.get("city", npc.home_city)),
					str(new_place.get("country", npc.home_country))
				]
			})
			gs.chunk_simulation_engine.remove_npc(npc)
			gs.world_space_engine.move_npc(npc)
			gs.chunk_simulation_engine.assign_npc(npc)





func run_world_year(context: Dictionary = {}) -> Dictionary:
	var runtime_context: Dictionary = context.duplicate(true)
	if not runtime_context.has("year"):
		runtime_context ["year"] = int(gs.year) if gs != null else 0
	runtime_context ["runtime_owner"] = str(runtime_context.get("runtime_owner", "legacy_life_engine"))
	runtime_context ["runtime_phase"] = str(runtime_context.get("runtime_phase", "legacy_world_year"))

	return run_world_contract_phase("legacy_world_year", runtime_context)
func try_start_player_line_pregnancy(initiator: Person, target: Person, context:= "hookup") -> bool:
	var details:= try_start_player_line_pregnancy_details(initiator, target, context)
	return bool(details.get("pregnancy_started", false))

func try_start_player_line_pregnancy_details(
	initiator: Person,
	target: Person,
	context:= "hookup"
) -> Dictionary:
	if initiator == null or target == null:
		return {
			"pregnancy_started": false
		}

	if not initiator.alive or not target.alive:
		return {
			"pregnancy_started": false
		}

	if initiator.age < 16 or target.age < 16:
		return {
			"pregnancy_started": false
		}

	var carrier: Person = null
	var other_parent: Person = null

	if (
		initiator.gender == "Male"
		and target.gender == "Female"
	):
		carrier = target
		other_parent = initiator
	elif (
		initiator.gender == "Female"
		and target.gender == "Male"
	):
		carrier = initiator
		other_parent = target
	else:
		return {
			"pregnancy_started": false
		}

	if carrier.pregnancy_progress >= 0:
		return {
			"pregnancy_started": false
		}

	var chance:= 8

	if context == "make_love":
		chance = 14
	elif context == "try_for_baby":


		chance = 35

	var initiator_fertility: float = clamp(
		float(initiator.fertility),
		0.0,
		100.0
	)
	var target_fertility: float = clamp(
		float(target.fertility),
		0.0,
		100.0
	)

	chance += int(
		round(
			(initiator_fertility - 50.0) * 0.1
		)
	)
	chance += int(
		round(
			(target_fertility - 50.0) * 0.14
		)
	)

	if "Impulsive" in initiator.traits:
		chance += 6

	if (
		"Loyal" in initiator.traits
		and initiator.partner == target
	):
		chance += 4

	chance = int(
		clamp(
			chance,
			0,
			95
		)
	)

	if randi() % 100 >= chance:
		return {
			"pregnancy_started": false
		}

	carrier.pregnant_by_id = other_parent.id
	carrier.unborn_child_other_parent_id = other_parent.id
	carrier.pregnancy_progress = 0
	carrier.pregnancy_known = true
	carrier.pregnancy_context = context

	var event_text:= (
		"%s became pregnant by %s."
		% [
			carrier.first_name,
			other_parent.first_name
		]
	)

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.PREGNANCY_STARTED,
			{
				"npc_id": carrier.id,
				"target_id": other_parent.id,
				"text": event_text,
				"context": context
			}
		)

	var diary_text:= ""
	var player_involved: bool = false

	if gs.player != null:
		if int(carrier.id) == int(gs.player.id):
			player_involved = true
			diary_text = "I became pregnant with my baby."
		elif int(other_parent.id) == int(gs.player.id):
			player_involved = true
			var carrier_label: String = str(
				gs.get_relationship_label_between(
					gs.player,
					carrier
				)
			).strip_edges()

			if (
				carrier_label == ""
				or carrier_label == "Stranger"
			):
				carrier_label = "Partner"

			diary_text = (
				"My %s became pregnant with my baby."
				% carrier_label.to_lower()
			)



	if player_involved:
		var pending_raw: Variant = gs.pending_player_line_birth
		var pending: Dictionary = (
			pending_raw as Dictionary
			if typeof(pending_raw) == TYPE_DICTIONARY
			else {}
		)

		if pending.is_empty():
			var default_last_name: String = str(
				carrier.last_name
			).strip_edges()
			if default_last_name == "":
				default_last_name = str(
					other_parent.last_name
				).strip_edges()

			var child_gender: String = [
				"Male",
				"Female"
			] [randi() % 2]
			var child_sex_label: String = (
				"boy"
				if child_gender == "Male"
				else "girl"
			)
			var prompt_text: String = ""

			if int(carrier.id) == int(gs.player.id):
				prompt_text = (
					"You gave birth.\n\nIt's a %s.\n\nChoose your baby's first name and last name."
					% child_sex_label
				)
			else:
				var relationship_label: String = str(
					gs.get_relationship_label_between(
						gs.player,
						carrier
					)
				).strip_edges()
				if (
					relationship_label == ""
					or relationship_label == "Stranger"
				):
					relationship_label = "Partner"
				prompt_text = (
					"Your %s gave birth.\n\nIt's a %s.\n\nChoose the baby's first name and last name."
					% [
						relationship_label.to_lower(),
						child_sex_label
					]
				)

			gs.pending_player_line_birth = {
				"schema": "eralife.player_line_birth_identity_contract",
				"version": 2,
				"mother_id": int(carrier.id),
				"father_id": int(other_parent.id),
				"default_last_name": default_last_name,
				"child_gender": child_gender,
				"prompt_text": prompt_text,
				"conception_year": int(gs.year),
				"target_birth_year": int(gs.year) + 1,
				"ready_to_name": false,
				"truth_owner": "world_engine_conception"
			}

	return {
		"pregnancy_started": true,
		"carrier_id": int(carrier.id),
		"other_parent_id": int(other_parent.id),
		"carrier_is_player": (
			gs.player != null
			and int(carrier.id) == int(gs.player.id)
		),
		"pregnancy_context": context,
		"conception_chance": chance,
		"diary_text": diary_text,
		"event_text": event_text,
		"player_line_birth_contract_prearmed": player_involved
	}
func terminate_player_line_pregnancy(
	carrier: Person,
	other_parent: Person,
	context: Dictionary = {}
) -> Dictionary:
	if carrier == null:
		return {
			"success": false,
			"reason": "pregnancy_carrier_missing"
		}

	if int(
		carrier.pregnancy_progress
	) < 0:
		return {
			"success": false,
			"reason": "pregnancy_not_active",
			"carrier_id": int(
				carrier.id
			)
		}

	var expected_other_parent_id: int = int(
		carrier.unborn_child_other_parent_id
	)

	if (
		other_parent != null
		and expected_other_parent_id > 0
		and expected_other_parent_id != int(
			other_parent.id
		)
	):
		return {
			"success": false,
			"reason": "pregnancy_other_parent_mismatch",
			"carrier_id": int(
				carrier.id
			),
			"expected_other_parent_id": (
				expected_other_parent_id
			),
			"received_other_parent_id": int(
				other_parent.id
			)
		}

	var previous_context: String = str(
		carrier.pregnancy_context
	).strip_edges()

	carrier.pregnant_by_id = -1
	carrier.unborn_child_other_parent_id = -1
	carrier.pregnancy_progress = -1
	carrier.pregnancy_known = false
	carrier.pregnancy_context = ""




	if (
		gs != null
		and typeof(
			gs.pending_player_line_birth
		) == TYPE_DICTIONARY
		and int(
			gs.pending_player_line_birth.get(
				"mother_id",
				-1
			)
		) == int(
			carrier.id
		)
	):
		gs.pending_player_line_birth = {}

	return {
		"success": true,
		"schema": "eralife.player_line_pregnancy_termination",
		"version": 1,
		"carrier_id": int(
			carrier.id
		),
		"other_parent_id": expected_other_parent_id,
		"previous_pregnancy_context": previous_context,
		"termination_context": context.duplicate(false),
		"authority": "WorldEngine"
	}


func process_pregnancies():
	for npc in gs.npcs:
		if npc.pregnancy_progress < 0:
			continue
		npc.pregnancy_progress += 1
		if npc.pregnancy_progress < 1:
			continue

		var other_parent = gs.get_npc_by_id(npc.unborn_child_other_parent_id)
		if not gs.can_create_child(npc, other_parent, false):
			npc.pregnant_by_id = -1
			npc.unborn_child_other_parent_id = -1
			npc.pregnancy_progress = -1
			npc.pregnancy_known = false
			npc.pregnancy_context = ""
			continue

		var baby = gs.spawn_child(npc, other_parent, false)
		if baby == null:
			npc.pregnant_by_id = -1
			npc.unborn_child_other_parent_id = -1
			npc.pregnancy_progress = -1
			npc.pregnancy_known = false
			npc.pregnancy_context = ""
			continue

		baby.age = 0

		var birth_text = "\n👶\n %s gave birth to %s's child, %s." % [
			npc.first_name,
			other_parent.first_name,
			baby.first_name
		]
		gs.pending_death_messages.append(birth_text)
		gs.event_bus.emit(ActionEventTypes.CHILD_BORN_PLAYER_LINE, {
			"npc_id": npc.id,
			"target_id": other_parent.id,
			"child_id": baby.id,
			"text": birth_text
		})

		npc.pregnant_by_id = -1
		npc.unborn_child_other_parent_id = -1
		npc.pregnancy_progress = -1
		npc.pregnancy_known = false
		npc.pregnancy_context = ""