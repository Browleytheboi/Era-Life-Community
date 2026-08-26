extends Resource
class_name LifeEngine

const LIFE_CONTRACT_SCHEMA:= "eralife.life_engine_contract"
const LIFE_CONTRACT_VERSION:= 1
const DEFAULT_LIFE_CONTRACT_ID:= "eralife_default_life_engine"

var gs
var runtime_engine: AgeUpRuntimeEngine
var life_contract_registry: Dictionary = {}
var life_task_registry: Dictionary = {}
var last_life_contract_report: Dictionary = {}
var last_life_task_report: Dictionary = {}

func _init(_gs):
	gs = _gs
	runtime_engine = AgeUpRuntimeEngine.new(gs)
	configure_life_contracts({})
func configure_life_contracts(raw_bundle: Dictionary = {}) -> Dictionary:
	life_contract_registry.clear()
	life_task_registry.clear()

	var report:= {
		"schema": "eralife.life_engine_contract_configure_report",
		"version": LIFE_CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"configured_at_ms": int(Time.get_ticks_msec())
	}

	var contracts: Array = []
	contracts.append(_build_default_life_contract())

	var registry_raw: Variant = raw_bundle.get("life_contract_registry", raw_bundle.get("contracts", {}))
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for key in (registry_raw as Dictionary).keys():
			var row_raw: Variant = (registry_raw as Dictionary).get(key, {})
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))
	elif typeof(registry_raw) == TYPE_ARRAY:
		for row_raw in registry_raw:
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	if raw_bundle.has("schema") or raw_bundle.has("tasks"):
		contracts.append(raw_bundle.duplicate(true))

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = normalize_life_contract(raw_contract)
		var validation: Dictionary = normalized.get("validation", {})
		if not bool(validation.get("valid", false)):
			report ["failed"].append({
				"id": str(normalized.get("id", "")),
				"validation": validation.duplicate(true)
			})
			continue

		_ingest_life_contract(normalized)
		report ["loaded"].append({
			"id": str(normalized.get("id", "")),
			"task_count": int(normalized.get("tasks", []).size())
		})

	last_life_contract_report = report.duplicate(true)
	return report

func import_registry(raw_registry: Dictionary = {}) -> Dictionary:
	return configure_life_contracts(raw_registry)

func export_registry() -> Dictionary:
	return {
		"schema": "eralife.life_engine_contract_registry",
		"version": LIFE_CONTRACT_VERSION,
		"contracts": life_contract_registry.duplicate(true),
		"tasks": life_task_registry.duplicate(true),
		"last_report": last_life_contract_report.duplicate(true)
	}

func export_state() -> Dictionary:
	return export_registry()

func import_state(raw_state: Dictionary = {}) -> Dictionary:
	return import_registry(raw_state)

func normalize_life_contract(raw_contract: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", DEFAULT_LIFE_CONTRACT_ID))).strip_edges()
	if contract_id == "":
		contract_id = DEFAULT_LIFE_CONTRACT_ID
		warnings.append("LifeEngine contract id was empty. Defaulted to '%s'." % contract_id)

	var version: int = max(1, int(raw_contract.get("version", LIFE_CONTRACT_VERSION)))
	if version > LIFE_CONTRACT_VERSION:
		warnings.append("LifeEngine contract '%s' was authored for version %d. Runtime supports %d." % [contract_id, version, LIFE_CONTRACT_VERSION])

	var tasks: Array = []
	for raw_task in _safe_life_dictionary_array(raw_contract.get("tasks", [])):
		var task: Dictionary = normalize_life_task(raw_task, contract_id)
		if str(task.get("id", "")).strip_edges() == "":
			warnings.append("Skipped LifeEngine task without id.")
			continue
		tasks.append(task)

	if tasks.is_empty():
		errors.append("LifeEngine contract '%s' has no tasks." % contract_id)

	return {
		"schema": str(raw_contract.get("schema", LIFE_CONTRACT_SCHEMA)).strip_edges(),
		"version": version,
		"runtime_contract_version": LIFE_CONTRACT_VERSION,
		"id": contract_id,
		"enabled": bool(raw_contract.get("enabled", true)),
		"priority": int(raw_contract.get("priority", 0)),
		"tasks": tasks,
		"phase_owner": "game_state_contract_engine",
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

func normalize_life_task(raw_task: Dictionary, contract_id: String = "") -> Dictionary:
	var task_id: String = str(raw_task.get("id", raw_task.get("task_id", ""))).strip_edges()
	var method_name: String = str(raw_task.get("method", raw_task.get("method_name", task_id))).strip_edges()

	return {
		"id": task_id,
		"contract_id": contract_id,
		"enabled": bool(raw_task.get("enabled", true)),
		"method": method_name,
		"phase": str(raw_task.get("phase", "life_year")).strip_edges(),
		"order": int(raw_task.get("order", 100)),
		"priority": int(raw_task.get("priority", 0)),
		"passes_context": bool(raw_task.get("passes_context", true)),
		"required": bool(raw_task.get("required", false)),
		"metadata": raw_task.get("metadata", {}).duplicate(true) if typeof(raw_task.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": task_id != "" and method_name != "",
			"errors": [] if task_id != "" and method_name != "" else ["LifeEngine task requires id and method."],
			"warnings": []
		}
	}

func run_life_contract_listener(listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var task_id: String = str(listener.get("task_id", listener.get("id", ""))).strip_edges()
	if task_id == "":
		task_id = str(listener.get("method", "")).strip_edges()

	var runtime_context: Dictionary = context.duplicate(true)
	runtime_context ["runtime_phase"] = str(listener.get("phase", runtime_context.get("runtime_phase", "")))
	runtime_context ["runtime_owner"] = str(runtime_context.get("runtime_owner", "game_state_contract_engine"))
	runtime_context ["life_listener_id"] = str(listener.get("id", task_id))

	for key in listener.keys():
		if key in ["metadata", "validation"]:
			continue
		if not runtime_context.has(key):
			runtime_context [key] = listener.get(key)

	return run_life_contract_task(task_id, runtime_context)

func run_life_contract_task(task_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_task: String = str(task_id).strip_edges()
	var task_raw: Variant = life_task_registry.get(clean_task, {})
	var task: Dictionary = task_raw if typeof(task_raw) == TYPE_DICTIONARY else {}
	var target_year: int = int(context.get("year", gs.year if gs != null else 0))

	var report:= {
		"schema": "eralife.life_engine_task_report",
		"version": LIFE_CONTRACT_VERSION,
		"task": clean_task,
		"year": target_year,
		"ran": false,
		"skipped": false,
		"failed": false,
		"reason": ""
	}

	if task.is_empty():
		report ["failed"] = true
		report ["reason"] = "missing_task_contract"
		last_life_task_report = report.duplicate(true)
		return report

	if not bool(task.get("enabled", true)):
		report ["skipped"] = true
		report ["reason"] = "task_disabled"
		last_life_task_report = report.duplicate(true)
		return report

	var method_name: String = str(task.get("method", clean_task)).strip_edges()
	if method_name == "" or not has_method(method_name):
		report ["failed"] = true
		report ["reason"] = "missing_method:%s" % method_name
		last_life_task_report = report.duplicate(true)
		return report

	var runtime_context: Dictionary = context.duplicate(true)
	runtime_context ["life_task_id"] = clean_task
	runtime_context ["life_contract_id"] = str(task.get("contract_id", DEFAULT_LIFE_CONTRACT_ID))
	runtime_context ["year"] = target_year

	var result: Variant = null
	if bool(task.get("passes_context", true)):
		result = callv(method_name, [runtime_context])
	else:
		result = call(method_name)

	report ["ran"] = true
	report ["method"] = method_name

	if typeof(result) == TYPE_DICTIONARY:
		report ["result"] = (result as Dictionary).duplicate(true)
	else:
		report ["result"] = result

	last_life_task_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_life_engine_task_report"] = report.duplicate(true)

	return report

func _build_default_life_contract() -> Dictionary:
	return {
		"schema": LIFE_CONTRACT_SCHEMA,
		"version": LIFE_CONTRACT_VERSION,
		"id": DEFAULT_LIFE_CONTRACT_ID,
		"enabled": true,
		"tasks": [
			{
				"id": "begin_living_year",
				"method": "_life_task_begin_living_year",
				"phase": "year_and_era_mutation",
				"order": 10,
				"passes_context": true,
				"required": true
			},
			{
				"id": "refresh_relationship_targets",
				"method": "_life_task_refresh_relationship_targets",
				"phase": "internal_identity_drift",
				"order": 20,
				"passes_context": true
			},
			{
				"id": "finalize_life_year_contract",
				"method": "_life_task_finalize_life_year_contract",
				"phase": "narrative_and_presentation",
				"order": 90,
				"passes_context": true
			}
		],
		"metadata": {
			"built_in": true,
			"backwards_compatible": true,
		}
	}

func _ingest_life_contract(contract: Dictionary) -> void:
	if not bool(contract.get("enabled", true)):
		return

	var contract_id: String = str(contract.get("id", DEFAULT_LIFE_CONTRACT_ID)).strip_edges()
	if contract_id == "":
		contract_id = DEFAULT_LIFE_CONTRACT_ID

	life_contract_registry [contract_id] = contract.duplicate(true)

	for raw_task in contract.get("tasks", []):
		if typeof(raw_task) != TYPE_DICTIONARY:
			continue

		var task: Dictionary = raw_task
		var task_id: String = str(task.get("id", "")).strip_edges()
		if task_id == "":
			continue

		life_task_registry [task_id] = task.duplicate(true)

func _safe_life_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))

	return out

func _life_task_begin_living_year(context: Dictionary = {}) -> Dictionary:
	var target_year: int = int(context.get("year", gs.year + 1 if gs != null else 0))
	var should_advance_immediately: bool = bool(context.get("advance_immediately", true))

	var report:= {
		"schema": "eralife.life_engine_begin_year_report",
		"version": LIFE_CONTRACT_VERSION,
		"year": target_year,
		"runtime_engine_used": runtime_engine != null,
		"advanced": false,
		"transaction_opened": false,
		"advance_immediately": should_advance_immediately,
		"runtime_owner": str(context.get("runtime_owner", "life_engine"))
	}

	if gs == null or gs.player == null:
		return report

	if runtime_engine != null:
		runtime_engine.begin_year_transaction({
			"mode": str(context.get("mode", "living")),
			"year": target_year,
			"player_id": int(context.get("player_id", gs.player.id)),
			"runtime_owner": str(context.get("runtime_owner", "life_engine")),
			"life_task_id": str(context.get("life_task_id", "begin_living_year"))
		})

		report ["transaction_opened"] = true
		report ["transaction_year"] = target_year
		report ["current_year"] = int(gs.year)
		report ["player_age"] = int(gs.player.age)

		if not should_advance_immediately:
			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["life_engine_year_transaction_open"] = report.duplicate(true)
			return report

		runtime_engine.advance_year_and_handle_era_shift(gs.player)
	else:
		_advance_year_and_handle_era_shift(gs.player)

	report ["advanced"] = true
	report ["current_year"] = int(gs.year)
	report ["player_age"] = int(gs.player.age)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["life_engine_year_transaction_open"] = report.duplicate(true)

	return report

func _life_task_refresh_relationship_targets(context: Dictionary = {}) -> Dictionary:
	var targets: Array = _collect_player_relationship_targets()
	var ids: Array = []

	for npc in targets:
		if npc == null:
			continue
		ids.append(int(npc.id))

	var report:= {
		"schema": "eralife.life_engine_relationship_targets_report",
		"version": LIFE_CONTRACT_VERSION,
		"year": int(context.get("year", gs.year if gs != null else 0)),
		"target_count": ids.size(),
		"target_ids": ids
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["life_engine_relationship_targets"] = report.duplicate(true)

	return report

func _life_task_finalize_life_year_contract(
	context: Dictionary = {}
) -> Dictionary:
	var report:= {
		"schema": "eralife.life_engine_finalize_year_report",
		"version": LIFE_CONTRACT_VERSION,
		"year": int(
			context.get(
				"year",
				gs.year
				if gs != null
				else 0
			)
		),
		"player_id": (
			int(gs.player.id)
			if gs != null and gs.player != null
			else -1
		),
		"stat_drift_applied": false,
		"stat_drift_already_applied": false,
		"finalized_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if gs == null:
		return report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs.player != null:
		var time_contract_raw: Variant = gs.scenario_state.get(
			"age_up_time_contract",
			{}
		)
		var time_contract: Dictionary = (
			time_contract_raw as Dictionary
			if typeof(time_contract_raw) == TYPE_DICTIONARY
			else {}
		)

		var target_year: int = int(
			time_contract.get(
				"target_year",
				report.get(
					"year",
					gs.year
				)
			)
		)
		var target_age: int = int(
			time_contract.get(
				"target_age",
				gs.player.age
			)
		)

		var drift_key: String = (
			"age_up_truth_stat_drift|%d|%d|%d"
			% [
				int(
					gs.player.id
				),
				target_year,
				target_age
			]
		)

		var drift_registry_raw: Variant = gs.scenario_state.get(
			"age_up_truth_stat_drift_registry",
			{}
		)
		var drift_registry: Dictionary = (
			drift_registry_raw as Dictionary
			if typeof(drift_registry_raw) == TYPE_DICTIONARY
			else {}
		)

		if bool(
			drift_registry.get(
				drift_key,
				false
			)
		):
			report ["stat_drift_already_applied"] = true
		else:
			var age_pressure: float = 0.0

			if target_age >= 35:
				age_pressure += randf_range(
					0.05,
					0.35
				)

			if target_age >= 45:
				age_pressure += randf_range(
					0.15,
					0.85
				)

			if target_age >= 70:
				age_pressure += randf_range(
					0.35,
					1.25
				)

			var health_drift: float = (
				randf_range(
					0.05,
					0.85
				) + age_pressure
			)
			var mental_drift: float = randf_range(
				0.05,
				0.75
			)
			var happiness_drift: float = randf_range(
				0.05,
				0.75
			)
			var smarts_drift: float = randf_range(
				0.0,
				0.3
			)
			var looks_drift: float = randf_range(
				0.0,
				0.35
			)
			var fame_drift: float = randf_range(
				0.0,
				0.45
			)

			if target_age >= 55:
				smarts_drift += randf_range(
					0.0,
					0.25
				)
				looks_drift += randf_range(
					0.15,
					0.65
				)

			gs.player.health = clamp(
				float(
					gs.player.health
				) - health_drift,
				0.0,
				200.0
			)
			gs.player.mental_health = clamp(
				float(
					gs.player.mental_health
				) - mental_drift,
				0.0,
				100.0
			)
			gs.player.satisfaction = clamp(
				float(
					gs.player.satisfaction
				) - happiness_drift,
				0.0,
				100.0
			)
			gs.player.smarts = clamp(
				int(
					round(
						float(
							gs.player.smarts
						) - smarts_drift
					)
				),
				0,
				100
			)
			gs.player.looks = clamp(
				int(
					round(
						float(
							gs.player.looks
						) - looks_drift
					)
				),
				0,
				100
			)
			gs.player.fame = clamp(
				int(
					round(
						float(
							gs.player.fame
						) - fame_drift
					)
				),
				0,
				100
			)

			if "approval" in gs.player:
				var approval_drift: float = randf_range(
					-0.35,
					0.85
				)
				gs.player.approval = clamp(
					int(
						round(
							float(
								gs.player.approval
							) - approval_drift
						)
					),
					0,
					100
				)


			drift_registry [
				drift_key
			] = true
			gs.scenario_state [
				"age_up_truth_stat_drift_registry"
			] = drift_registry

			report ["stat_drift_applied"] = true

	gs.scenario_state [
		"life_engine_last_finalize_year_report"
	] = report.duplicate(true)

	return report
func _append_relationship_target(out: Array, seen: Dictionary, npc: Person) -> void:
	if npc == null:
		return
	if gs.player == null:
		return
	if npc == gs.player:
		return
	if not npc.alive:
		return
	if seen.has(npc.id):
		return

	out.append(npc)
	seen [npc.id] = true


func _collect_player_relationship_targets() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var p: Person = gs.player

	if p == null:
		return out


	if gs.world_space_engine != null:
		for npc in gs.world_space_engine.get_nearby_npcs(p):
			_append_relationship_target(out, seen, npc)


	if gs.social_graph_engine != null:
		for other_id in gs.social_graph_engine.get_connections(p.id):
			_append_relationship_target(out, seen, gs.get_npc_by_id(int(other_id)))


	for pid in p.parents:
		_append_relationship_target(out, seen, gs.get_npc_by_id(int(pid)))

	for cid in p.children:
		_append_relationship_target(out, seen, gs.get_npc_by_id(int(cid)))


	for pid in p.parents:
		var par: Person = gs.get_npc_by_id(int(pid))
		if par != null:
			for sid in par.children:
				var sib: Person = gs.get_npc_by_id(int(sid))
				if sib != null and sib.id != p.id:
					_append_relationship_target(out, seen, sib)


	for fid in p.friends:
		_append_relationship_target(out, seen, gs.get_npc_by_id(int(fid)))

	for exid in p.ex_partners:
		_append_relationship_target(out, seen, gs.get_npc_by_id(int(exid)))

	var partner: Person = gs.get_valid_partner(p, true)
	if partner != null:
		_append_relationship_target(out, seen, partner)


	for sid in p.schoolmates:
		_append_relationship_target(out, seen, gs.get_or_reactivate_npc_by_id(int(sid)))

	return out
func _capture_age_up_npc_age_truth_snapshot() -> Dictionary:
	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"age_up_npc_snapshot_strategy"
		] = "world_engine_lazy_bounded"

		gs.scenario_state [
			"age_up_npc_snapshot_eager_scan_performed"
		] = false

		gs.scenario_state [
			"age_up_npc_snapshot_authority"
		] = "world_engine.age_npcs"

		gs.scenario_state [
			"age_up_npc_snapshot_blocks_ui"
		] = false




	return {}


func _format_life_engine_year_label(year_value: int) -> String:
	if year_value < 0:
		return "%d BCE" % abs(year_value)
	if year_value <= 1000:
		return "%d AD" % year_value
	return str(year_value)


func _canonicalize_age_up_result(
	result: Dictionary,
	started_from_year: int,
	target_year: int,
	started_from_age: int,
	target_age: int,
	reason: String
) -> Dictionary:
	var out: Dictionary = result.duplicate(true)

	if not out.has("type") or str(out.get("type", "")).strip_edges() == "":
		out ["type"] = "year_passed"

	if not out.has("opps"):
		out ["opps"] = []

	out ["year"] = target_year if gs == null or not bool(gs.year_locked) else int(gs.year)
	out ["age"] = target_age
	out ["started_from_year"] = started_from_year
	out ["started_from_age"] = started_from_age
	out ["target_year"] = target_year
	out ["target_age"] = target_age
	out ["runtime_truth_committed"] = true
	out ["runtime_truth_commit_reason"] = reason

	var clean_text: String = str(out.get("text", "")).strip_edges()
	if clean_text == "" or clean_text.begins_with("Another year passed"):
		out ["text"] = "Another year passed. I am now %d." % target_age

	return out


func _push_age_up_world_feed_once(
	started_from_year: int,
	target_year: int,
	target_age: int,
	reason: String
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var feed_registry_raw: Variant = gs.scenario_state.get(
		"age_up_world_feed_registry",
		{}
	)
	var feed_registry: Dictionary = (
		feed_registry_raw
		if typeof(feed_registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var feed_key: String = "year_passed_feed|%d|%d|%d" % [
		started_from_year,
		target_year,
		target_age
	]

	if bool(feed_registry.get(feed_key, false)):
		return

	var from_year_text: String = _format_life_engine_year_label(started_from_year)
	var to_year_text: String = _format_life_engine_year_label(target_year)
	var feed_text: String = (
		"The world moved from %s to %s. Life kept happening beyond you."
		% [
			from_year_text,
			to_year_text
		]
	)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(feed_text, {
			"source": reason,
			"category": "time",
			"event_name": "year_passed",
			"year": target_year,
			"personally_relevant": false,
		})

	var vitality_report: Dictionary = {}
	if (
		gs.world_engine != null
		and gs.world_engine.has_method("emit_yearly_world_vitality_feed")
	):
		vitality_report = gs.world_engine.emit_yearly_world_vitality_feed({
			"source": reason,
			"started_from_year": started_from_year,
			"target_year": target_year,
			"target_age": target_age,
			"reality_mode": (
				str(gs.reality_mode)
				if "reality_mode" in gs
				else "realistic"
			),
			"era_name": (
				str(gs.era.get("name", ""))
				if gs.era != null
				else ""
			),
			"player_id": int(gs.player.id) if gs.player != null else -1,
			"emit_realm_stats": true,
			"max_npc_events": 18,
			"realm_event_scope": "all_resident_realms",
			"max_realm_events": -1
		})

	gs.scenario_state ["last_age_up_world_vitality_report"] = (
		vitality_report.duplicate(true)
	)

	feed_registry [feed_key] = true
	gs.scenario_state ["age_up_world_feed_registry"] = feed_registry
func _commit_npc_time_truth_for_age_up(
	started_from_year: int,
	target_year: int,
	reason: String
) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.age_up_npc_time_truth_report",
		"version": 3,
		"reason": reason,
		"started_from_year": started_from_year,
		"target_year": target_year,
		"already_applied": false,
		"complete": false,
		"streaming_pending": true,
		"runtime_contract_owned": true,
		"authority": "world_engine",
		"receipt_key": "",
		"aged_npcs": 0,
		"corrected_overadvanced_npcs": 0,
		"skipped_player": 0,
		"skipped_dead": 0,
		"event_count": 0,
		"death_checks": 0
	}

	if gs == null:
		report ["reason"] = "missing_game_state"
		return report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var world_report_raw: Variant = gs.scenario_state.get(
		"last_world_engine_age_npcs_report",
		{}
	)
	var world_report: Dictionary = (
		world_report_raw as Dictionary
		if typeof(world_report_raw) == TYPE_DICTIONARY
		else {}
	)

	var receipt_valid: bool = (
		not world_report.is_empty()
		and str(
			world_report.get(
				"schema",
				""
			)
		).strip_edges() == "eralife.world_engine_age_npcs_report"
		and str(
			world_report.get(
				"authority",
				""
			)
		).strip_edges() == "world_engine"
		and str(
			world_report.get(
				"task",
				""
			)
		).strip_edges() == "age_npcs"
		and int(
			world_report.get(
				"source_year",
				-999999
			)
		) == started_from_year
		and int(
			world_report.get(
				"year",
				-999999
			)
		) == target_year
		and bool(
			world_report.get(
				"is_complete",
				false
			)
		)
		and bool(
			world_report.get(
				"completion_receipt",
				false
			)
		)
	)

	if not receipt_valid:
		report ["reason"] = (
			"awaiting_world_engine_age_npcs_completion_receipt"
		)
		report ["deferred_to_zero_frame_tail"] = true

		gs.scenario_state [
			"last_age_up_npc_time_truth_report"
		] = report.duplicate(false)

		return report

	var commit_key: String = (
		"npc_time_truth|%d|%d"
		% [
			started_from_year,
			target_year
		]
	)

	var commit_registry_raw: Variant = gs.scenario_state.get(
		"age_up_npc_time_truth_registry",
		{}
	)
	var commit_registry: Dictionary = (
		commit_registry_raw as Dictionary
		if typeof(commit_registry_raw) == TYPE_DICTIONARY
		else {}
	)

	var already_applied: bool = bool(
		commit_registry.get(
			commit_key,
			false
		)
	)

	report ["reason"] = reason
	report ["already_applied"] = already_applied
	report ["complete"] = true
	report ["streaming_pending"] = false
	report ["runtime_contract_owned"] = true
	report ["authority_receipt"] = world_report.duplicate(false)
	report ["receipt_key"] = str(
		world_report.get(
			"receipt_key",
			""
		)
	)
	report ["aged_npcs"] = int(
		world_report.get(
			"aged_npcs",
			0
		)
	)
	report ["corrected_overadvanced_npcs"] = int(
		world_report.get(
			"corrected_overadvanced_npcs",
			0
		)
	)
	report ["skipped_player"] = int(
		world_report.get(
			"skipped_player",
			0
		)
	)
	report ["skipped_dead"] = int(
		world_report.get(
			"skipped_dead",
			0
		)
	)
	report ["event_count"] = int(
		world_report.get(
			"event_count",
			0
		)
	)
	report ["death_checks"] = int(
		world_report.get(
			"death_checks",
			0
		)
	)

	commit_registry [
		commit_key
	] = true

	gs.scenario_state [
		"age_up_npc_time_truth_registry"
	] = commit_registry
	gs.scenario_state [
		"last_age_up_npc_time_truth_report"
	] = report.duplicate(false)
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_complete"
	] = true
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_pending"
	] = false
	gs.scenario_state [
		"age_up_npc_time_truth_committed_with_visible_time"
	] = false
	gs.scenario_state [
		"age_up_npc_time_truth_committed_in_background"
	] = true
	gs.scenario_state [
		"age_up_npc_time_truth_committed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	return report
func _queue_age_up_relationship_projection_refresh(
	source_year: int,
	target_year: int,
	transaction_actor_id: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.age_up_relationship_projection_refresh_report",
		"version": 4,
		"success": false,
		"queued": false,
		"source_year": source_year,
		"target_year": target_year,
		"actor_id": -1,
		"refresh_actor_ids": [],
		"reason": "",
		"blocks_ui": false,
		"requires_input_idle": false,
		"switch_readiness_invalidated": false,
		"bounded_refresh_actor_limit": 2
	}

	if (
		gs == null
		or gs.player == null
	):
		report ["reason"] = "missing_game_state_or_player"
		return report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if transaction_actor_id <= 0:
		var time_contract_raw: Variant = (
			gs.scenario_state.get(
				"age_up_time_contract",
				{}
			)
		)
		var time_contract: Dictionary = (
			(time_contract_raw as Dictionary).duplicate(false)
			if typeof(time_contract_raw) == TYPE_DICTIONARY
			else {}
		)

		transaction_actor_id = int(
			time_contract.get(
				"player_id",
				gs.player.id
			)
		)

	var live_actor_id: int = int(
		gs.player.id
	)
	var refresh_actor_ids: Array = []

	if transaction_actor_id > 0:
		refresh_actor_ids.append(
			transaction_actor_id
		)

	if (
		live_actor_id > 0
		and not refresh_actor_ids.has(
			live_actor_id
		)
	):
		refresh_actor_ids.append(
			live_actor_id
		)





	if refresh_actor_ids.size() > 2:
		refresh_actor_ids.resize(
			2
		)

	report ["actor_id"] = transaction_actor_id
	report ["refresh_actor_ids"] = (
		refresh_actor_ids.duplicate(false)
	)

	var refresh_required: bool = bool(
		gs.scenario_state.get(
			"age_up_relationship_lenses_must_refresh",
			false
		)
	)
	var refresh_year: int = int(
		gs.scenario_state.get(
			"age_up_relationship_lenses_refresh_year",
			-999999
		)
	)
	var temporal_surface_refresh_required: bool = (
		int(
			gs.scenario_state.get(
				"age_up_temporal_surface_successors_last_queued_year",
				-999999
			)
		) != target_year
	)

	if (
		(
			not refresh_required
			or refresh_year != target_year
		)
		and not temporal_surface_refresh_required
	):
		report ["success"] = true
		report ["reason"] = "already_satisfied"
		return report

	if gs.reality_projection_contract_engine == null:
		report ["reason"] = (
			"reality_projection_authority_unavailable"
		)
		return report

	if (
		refresh_required
		and refresh_year == target_year
		and not gs.reality_projection_contract_engine.has_method(
			"queue_resident_relationship_section_refresh"
		)
	):
		report ["reason"] = (
			"relationship_projection_authority_unavailable"
		)
		return report

	if (
		temporal_surface_refresh_required
		and not gs.reality_projection_contract_engine.has_method(
			"queue_resident_temporal_surface_refresh"
		)
	):
		report ["reason"] = (
			"temporal_surface_projection_authority_unavailable"
		)
		return report

	if (
		refresh_required
		and refresh_year == target_year
		and (
			gs.universal_switch_contract_engine == null
			or not gs.universal_switch_contract_engine.has_method(
				"queue_resident_profile_pointer_successor_refresh_for_actor"
			)
		)
	):
		report ["reason"] = (
			"universal_switch_targeted_successor_authority_unavailable"
		)
		return report

	var switch_reports: Array = []
	var switch_any_queued: bool = false

	if (
		refresh_required
		and refresh_year == target_year
	):
		for refresh_actor_id_raw in refresh_actor_ids:
			var refresh_actor_id: int = int(
				refresh_actor_id_raw
			)
			var switch_report: Dictionary = (
				gs.universal_switch_contract_engine
				.queue_resident_profile_pointer_successor_refresh_for_actor(
					refresh_actor_id,
					source_year,
					target_year,
					{
						"source": (
							"life_engine."
							+ "age_up_targeted_switch_pointer_successor_refresh"
						),
						"reason": "age_up_world_truth_completed",
						"source_year": source_year,
						"target_year": target_year,
						"background_only": true,
						"blocks_ui": false,
						"requires_input_idle": false,
						"ui_interaction_grace_ignored": true,
						"build_on_click_forbidden": true,
						"switch_press_build_forbidden": true,
						"render_boundary_required": false,
						"ready_gate_member": false,
						"preserve_existing_switch_readiness": true
					}
				)
			)

			switch_reports.append(
				switch_report.duplicate(false)
			)

			if not bool(
				switch_report.get(
					"success",
					false
				)
			):
				report [
					"switch_successor_queue_report"
				] = {
					"success": false,
					"actor_reports": switch_reports
				}
				report ["reason"] = (
					"resident_switch_successor_queue_rejected"
				)
				return report

			switch_any_queued = (
				switch_any_queued
				or bool(
					switch_report.get(
						"queued",
						false
					)
				)
			)

	var relationship_reports: Array = []
	var relationship_any_queued: bool = false
	var relationship_all_success: bool = true
	var section_ids: Array = [
		"family",
		"partner",
		"household",
		"ancestors",
		"descendants",
		"dead",
		"social",
		"exes",
		"pets"
	]

	if (
		refresh_required
		and refresh_year == target_year
	):
		for refresh_actor_id_raw in refresh_actor_ids:
			var refresh_actor_id: int = int(
				refresh_actor_id_raw
			)
			var relationship_report: Dictionary = (
				gs.reality_projection_contract_engine
				.queue_resident_relationship_section_refresh(
					refresh_actor_id,
					section_ids,
					{
						"source": (
							"life_engine."
							+ "age_up_relationship_projection_refresh"
						),
						"reason": "age_up_world_truth_completed",
						"source_year": source_year,
						"target_year": target_year,
						"background_only": true,
						"blocks_ui": false,
						"ui_interaction_grace_ignored": true,
						"build_on_click_forbidden": true,
						"ready_gate_member": false
					}
				)
			)

			relationship_reports.append(
				relationship_report.duplicate(false)
			)

			relationship_all_success = (
				relationship_all_success
				and bool(
					relationship_report.get(
						"success",
						false
					)
				)
			)
			relationship_any_queued = (
				relationship_any_queued
				or bool(
					relationship_report.get(
						"queued",
						false
					)
				)
			)

	var temporal_surface_ids: Array = [
		"activities"
	]
	var temporal_surface_reports: Array = []
	var temporal_surface_any_queued: bool = false
	var temporal_surface_all_success: bool = true

	if temporal_surface_refresh_required:
		for refresh_actor_id_raw in refresh_actor_ids:
			var refresh_actor_id: int = int(
				refresh_actor_id_raw
			)
			var temporal_surface_report: Dictionary = (
				gs.reality_projection_contract_engine
				.queue_resident_temporal_surface_refresh(
					refresh_actor_id,
					temporal_surface_ids,
					{
						"source": (
							"life_engine."
							+ "age_up_temporal_surface_successor_refresh"
						),
						"reason": "age_up_world_truth_completed",
						"source_year": source_year,
						"target_year": target_year,
						"background_only": true,
						"blocks_ui": false,
						"requires_input_idle": false,
						"ui_interaction_grace_ignored": true,
						"build_on_click_forbidden": true,
						"render_boundary_required": false,
						"ready_gate_member": false,
						"projection_read_only": true,
					}
				)
			)

			temporal_surface_reports.append(
				temporal_surface_report.duplicate(false)
			)
			temporal_surface_all_success = (
				temporal_surface_all_success
				and bool(
					temporal_surface_report.get(
						"success",
						false
					)
				)
			)
			temporal_surface_any_queued = (
				temporal_surface_any_queued
				or bool(
					temporal_surface_report.get(
						"queued",
						false
					)
				)
			)

	var switch_successor_queue_report: Dictionary = {
		"success": true,
		"queued": switch_any_queued,
		"actor_reports": switch_reports,
		"actor_count": refresh_actor_ids.size(),
		"bounded": true
	}
	var relationship_queue_report: Dictionary = {
		"success": relationship_all_success,
		"queued": relationship_any_queued,
		"actor_reports": relationship_reports,
		"actor_count": refresh_actor_ids.size(),
		"section_count_per_actor": section_ids.size(),
		"bounded": true
	}
	var temporal_surface_queue_report: Dictionary = {
		"success": temporal_surface_all_success,
		"queued": temporal_surface_any_queued,
		"actor_reports": temporal_surface_reports,
		"actor_count": refresh_actor_ids.size(),
		"surface_ids": temporal_surface_ids.duplicate(false),
		"renderer_thread_poll_only": true,
		"requires_input_idle": false,
		"ready_gate_member": false,
	}

	report [
		"switch_successor_queue_report"
	] = switch_successor_queue_report
	report [
		"relationship_queue_report"
	] = relationship_queue_report
	report [
		"temporal_surface_queue_report"
	] = temporal_surface_queue_report


	report [
		"queue_report"
	] = relationship_queue_report.duplicate(false)

	report ["success"] = (
		relationship_all_success
		and temporal_surface_all_success
	)
	report ["queued"] = (
		switch_any_queued
		or relationship_any_queued
		or temporal_surface_any_queued
	)
	report [
		"switch_readiness_invalidated"
	] = false

	if relationship_all_success:
		gs.scenario_state [
			"age_up_relationship_lenses_must_refresh"
		] = false
		gs.scenario_state [
			"age_up_relationship_lenses_last_consumed_year"
		] = target_year
		gs.scenario_state [
			"age_up_switch_pointer_successors_last_queued_year"
		] = target_year
		gs.scenario_state [
			"age_up_switch_readiness_preserved"
		] = true
		gs.scenario_state [
			"age_up_switch_global_successor_scan_forbidden"
		] = true

	if temporal_surface_all_success:
		gs.scenario_state [
			"age_up_temporal_surface_successors_last_queued_year"
		] = target_year
		gs.scenario_state [
			"age_up_temporal_surface_successors_last_queue_report"
		] = temporal_surface_queue_report.duplicate(false)

	if bool(
		report.get(
			"success",
			false
		)
	):
		gs.scenario_state [
			"age_up_relationship_lenses_last_refresh_report"
		] = report.duplicate(false)

	return report
func _build_age_up_time_contract(
	source_year: int,
	source_age: int,
	target_year: int,
	target_age: int
) -> Dictionary:
	return {
		"schema": "eralife.age_up_time_contract",
		"version": 2,
		"player_id": (
			int(
				gs.player.id
			)
			if (
				gs != null
				and gs.player != null
			)
			else -1
		),
		"source_year": source_year,
		"target_year": target_year,
		"source_age": source_age,
		"target_age": target_age,
		"year_delta": target_year - source_year,
		"age_delta": target_age - source_age,
		"time_authority": "age_up_runtime_engine",
		"core_identity_policy": {
			"advance_year": true,
			"advance_player_age": true,
		},
		"temporal_slice_policy": {
			"may_advance_core_year": false,
			"may_advance_player_age": false,
			"reason": (
				"AgeUpRuntimeEngine and constitutional world contract "
				+ "tasks own annual mutation. "
				+ "TemporalSliceTransformationRuntime may not serialize, "
				+ "mutate, hydrate, or replay annual truth."
			)
		},
		"world_policy": {
			"npc_age_mode": "source_snapshot_plus_one",
			"npc_age_authority": "world_engine.age_npcs",
			"continuous_runtime": true,
			"idle_required": false,
			"ui_activity_is_scheduler_input": false
		}
	}
func _ensure_age_up_time_contract_open(reason: String = "age_up_time_contract_open", loading_context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.player == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var existing_contract_raw: Variant = gs.scenario_state.get("age_up_time_contract", {})
	var existing_contract: Dictionary = existing_contract_raw if typeof(existing_contract_raw) == TYPE_DICTIONARY else {}

	if not existing_contract.is_empty() and bool(gs.scenario_state.get("age_up_contract_open", false)):
		var existing_source_year: int = int(existing_contract.get("source_year", gs.year))
		var existing_target_year: int = int(existing_contract.get("target_year", existing_source_year + 1))
		var existing_source_age: int = int(existing_contract.get("source_age", gs.player.age))
		var existing_target_age: int = int(existing_contract.get("target_age", existing_source_age + 1))

		var existing_contract_still_safe: bool = int(gs.year) <= existing_target_year and int(gs.player.age) <= existing_target_age
		if existing_contract_still_safe:
			return existing_contract.duplicate(true)

		gs.scenario_state ["age_up_contract_open"] = false
		gs.scenario_state ["age_up_contract_stale_closed"] = {
			"reason": reason,
			"source_year": existing_source_year,
			"target_year": existing_target_year,
			"source_age": existing_source_age,
			"target_age": existing_target_age,
			"live_year": int(gs.year),
			"live_age": int(gs.player.age),
			"closed_at_ms": int(Time.get_ticks_msec())
		}

	var started_from_year: int = int(loading_context.get("source_year", loading_context.get("started_from_year", gs.year)))
	var started_from_age: int = int(loading_context.get("source_age", loading_context.get("started_from_age", gs.player.age)))
	var target_year: int = int(loading_context.get("target_year", started_from_year + 1))
	var target_age: int = int(loading_context.get("target_age", started_from_age + 1))

	if target_year != started_from_year + 1:
		target_year = started_from_year + 1

	if target_age != started_from_age + 1:
		target_age = started_from_age + 1

	var time_contract: Dictionary = _build_age_up_time_contract(
		started_from_year,
		started_from_age,
		target_year,
		target_age
	)

	gs.scenario_state ["defer_runtime_plan_build"] = true
	gs.scenario_state ["age_up_time_contract"] = time_contract.duplicate(true)
	gs.scenario_state ["age_up_contract_open"] = true
	gs.scenario_state ["age_up_contract_transaction_id"] = "%d:%d:%d:%d" % [
		started_from_year,
		target_year,
		started_from_age,
		target_age
	]
	gs.scenario_state ["age_up_requested_year"] = target_year
	gs.scenario_state ["age_up_started_from_year"] = started_from_year
	gs.scenario_state ["age_up_started_from_age"] = started_from_age
	gs.scenario_state ["age_up_started_npc_ages"] = _capture_age_up_npc_age_truth_snapshot()
	gs.scenario_state ["age_up_truth_expected_target_age"] = target_age
	gs.scenario_state ["age_up_truth_owner"] = "age_up_runtime_engine"
	gs.scenario_state ["age_up_live_slice_streaming_enabled"] = true
	gs.scenario_state ["temporal_slice_streaming_applied"] = false
	gs.scenario_state ["temporal_slice_streaming_year"] = target_year
	gs.scenario_state ["age_up_time_contract_open_reason"] = reason



	gs.scenario_state ["age_up_contracts"] = [
		{
			"slice": "core_identity",
			"transform": "advance_core_identity",
			"rules": {
				"advance_year": false,
				"advance_player_age": false,
				"time_authority": "age_up_runtime_engine",
				"conflict_policy": "defer_to_age_up_time_contract"
			}
		},
		{
			"slice": "npc_biology",
			"transform": "increment_age",
			"rules": {
				"death_curve": "sigmoid",
				"elder_decline_start": 60,
				"conflict_policy": "source_snapshot_plus_one"
			}
		},
		{
			"slice": "economy",
			"transform": "apply_market_shift",
			"rules": {
				"inflation_rate": 0.03,
				"volatility": 0.2,
				"conflict_policy": "merge_numeric"
			}
		},
		{
			"slice": "relationships",
			"transform": "decay_or_strengthen",
			"rules": {
				"distance_decay": true,
				"shared_events_boost": true,
				"conflict_policy": "merge_relationship_edges"
			}
		}
	]

	var loading_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	var loading: Dictionary = loading_raw if typeof(loading_raw) == TYPE_DICTIONARY else {}
	if not loading.is_empty():
		var overlay_raw: Variant = loading.get("overlay_context", {})
		var overlay_context: Dictionary = overlay_raw if typeof(overlay_raw) == TYPE_DICTIONARY else {}

		overlay_context ["source_year"] = started_from_year
		overlay_context ["source_age"] = started_from_age
		overlay_context ["target_year"] = target_year
		overlay_context ["target_age"] = target_age
		overlay_context ["time_contract"] = time_contract.duplicate(true)

		loading ["overlay_context"] = overlay_context
		loading ["source_year"] = started_from_year
		loading ["source_age"] = started_from_age
		loading ["target_year"] = target_year
		loading ["target_age"] = target_age
		loading ["time_contract"] = time_contract.duplicate(true)
		gs.scenario_state ["loading_runtime"] = loading

	if runtime_engine != null and "active_year_context" in runtime_engine and not runtime_engine.active_year_context.is_empty():
		runtime_engine.active_year_context ["year"] = target_year
		runtime_engine.active_year_context ["committed_year"] = target_year
		runtime_engine.active_year_context ["time_contract"] = time_contract.duplicate(true)
		runtime_engine.active_year_context ["contract_source_year"] = started_from_year
		runtime_engine.active_year_context ["contract_target_year"] = target_year
		runtime_engine.active_year_context ["contract_source_age"] = started_from_age
		runtime_engine.active_year_context ["contract_target_age"] = target_age
		runtime_engine.active_year_context ["age_up_contracts"] = gs.scenario_state ["age_up_contracts"].duplicate(true)

	return time_contract.duplicate(true)
func _age_up_runtime_dependencies_hot() -> bool:
	if gs == null:
		return false

	return (
		runtime_engine != null
		and gs.life_engine != null
		and gs.game_state_contract_engine != null
		and gs.scenario_engine != null
		and gs.year_budget_engine != null
		and gs.health_engine != null
		and gs.world_engine != null
		and gs.life_diary_contract_engine != null
	)
func age_up():
	if gs == null:
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs.player == null:
		return {}

	if not gs.player.alive:
		return _age_up_afterlife_year()



	if bool(gs.year_locked):
		return {
			"success": false,
			"type": "age_up_year_locked",
			"reason": "year_progression_explicitly_locked",
			"text": "Year progression is locked.",
			"opps": [],
			"year": int(gs.year),
			"age": int(gs.player.age),
			"year_locked": true,
			"runtime_tail_pending": false,
			"zero_frame_age_up": true
		}




	var pending_birth_prompt: Dictionary = (
		_build_player_line_birth_prompt()
	)
	var pending_scenario_surface: Dictionary = {}

	if (
		gs.scenario_engine != null
		and gs.scenario_engine.has_pending_choice()
	):
		var pending_surface_timing: String = str(
			gs.scenario_state.get(
				"pending_surface_timing",
				""
			)
		).strip_edges().to_lower()
		var pending_allows_pre_year: bool = bool(
			gs.scenario_state.get(
				"pending_allows_pre_year_age_up_surface",
				false
			)
		)

		if (
			pending_surface_timing in [
				"pre_year",
				"before_year",
				"before_time_resolves"
			]
			or pending_allows_pre_year
		):
			var pending_raw: Variant = (
				gs.scenario_engine.get_pending_choice_result()
			)
			if typeof(pending_raw) == TYPE_DICTIONARY:
				pending_scenario_surface = (
					pending_raw as Dictionary
				).duplicate(false)

	var dependencies_hot: bool = (
		_age_up_runtime_dependencies_hot()
	)





	gs.scenario_state [
		"age_up_runtime_dependencies_hot_on_press"
	] = dependencies_hot
	gs.scenario_state [
		"age_up_load_dependency_repair_used_on_press"
	] = false
	gs.scenario_state [
		"age_up_predictive_queue_flushed_on_press"
	] = false
	gs.scenario_state [
		"age_up_resident_runtime_chassis_reused"
	] = dependencies_hot
	gs.scenario_state [
		"age_up_runtime_dependency_residency_pending"
	] = not dependencies_hot
	gs.scenario_state [
		"age_up_visible_commit_may_not_wait_for_tail_dependencies"
	] = true
	gs.scenario_state [
		"age_up_synchronous_repair_forbidden"
	] = true

	var existing_contract_raw: Variant = (
		gs.scenario_state.get(
			"age_up_time_contract",
			{}
		)
	)
	var existing_contract: Dictionary = (
		existing_contract_raw
		if typeof(
			existing_contract_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var started_from_year: int = int(
		gs.year
	)
	var started_from_age: int = int(
		gs.player.age
	)

	if (
		not existing_contract.is_empty()
		and bool(
			gs.scenario_state.get(
				"age_up_contract_open",
				false
			)
		)
	):
		started_from_year = int(
			existing_contract.get(
				"source_year",
				started_from_year
			)
		)
		started_from_age = int(
			existing_contract.get(
				"source_age",
				started_from_age
			)
		)

	var target_year: int = (
		started_from_year + 1
	)
	var target_age: int = (
		started_from_age + 1
	)
	var time_contract: Dictionary = (
		_build_age_up_time_contract(
			started_from_year,
			started_from_age,
			target_year,
			target_age
		)
	)
	var precompute_cache: Dictionary = (
		_zero_frame_age_up_cache_for_target(
			target_year
		)
	)
	var zero_frame_result: Dictionary = (
		_build_zero_frame_age_up_result(
			time_contract,
			precompute_cache,
			"life_engine_age_up"
		)
	)

	var post_commit_surface: Dictionary = {}

	if not pending_birth_prompt.is_empty():
		post_commit_surface = pending_birth_prompt.duplicate(false)

	if not pending_scenario_surface.is_empty():
		if post_commit_surface.is_empty():
			post_commit_surface = pending_scenario_surface.duplicate(false)
		else:
			post_commit_surface [
				"followup_result"
			] = pending_scenario_surface.duplicate(false)

	if not post_commit_surface.is_empty():
		zero_frame_result [
			"post_commit_surface"
		] = post_commit_surface.duplicate(false)
		zero_frame_result [
			"pre_year_surface_blocked_time"
		] = false

	var visible_commit_report: Dictionary = (
		_commit_zero_frame_age_up_visible_time(
			time_contract,
			zero_frame_result,
			"life_engine_age_up"
		)
	)
	var visible_truth_committed: bool = (
		bool(
			visible_commit_report.get(
				"success",
				false
			)
		)
		and int(gs.year) == target_year
		and int(gs.player.age) == target_age
	)

	zero_frame_result [
		"visible_commit_report"
	] = visible_commit_report.duplicate(false)
	zero_frame_result [
		"visible_truth_committed_before_tail"
	] = visible_truth_committed

	if not visible_truth_committed:
		zero_frame_result [
			"success"
		] = false
		zero_frame_result [
			"runtime_tail_pending"
		] = false
		zero_frame_result [
			"reason"
		] = str(
			visible_commit_report.get(
				"reason",
				"visible_time_commit_failed"
			)
		)
		return zero_frame_result.duplicate(false)

	var tail_queue_report: Dictionary = (
		_queue_zero_frame_age_up_tail_runtime(
			time_contract,
			precompute_cache,
			"life_engine_age_up"
		)
	)

	zero_frame_result [
		"tail_queue_report"
	] = tail_queue_report.duplicate(false)
	zero_frame_result [
		"success"
	] = true
	zero_frame_result [
		"synchronous_dependency_repair_performed"
	] = false
	zero_frame_result [
		"synchronous_predictive_flush_performed"
	] = false
	zero_frame_result [
		"synchronous_world_iteration_performed"
	] = false

	return zero_frame_result.duplicate(false)
func _life_safe_dictionary(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(
			false
		)

	return {}


func _life_safe_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(
			false
		)

	return []
func resolve_age_up_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"reason": "missing_age_up_actor_or_game_state",
			"type": "age_up_intent_rejected"
		}

	if (
		gs.player == null
		or int(
			actor.id
		) != int(
			gs.player.id
		)
	):
		return {
			"success": false,
			"reason": (
				"age_up_actor_is_not_controlled_identity"
			),
			"type": "age_up_intent_rejected",
			"actor_id": int(
				actor.id
			),
			"controlled_actor_id": (
				int(gs.player.id)
				if gs.player != null
				else -1
			)
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var source_year: int = int(
		gs.year
	)
	var source_age: int = int(
		actor.age
	)
	var source_frame: int = int(
		payload.get(
			"input_frame_id",
			Engine.get_process_frames()
		)
	)
	var intent_token: String = str(
		payload.get(
			"intent_token",
			""
		)
	).strip_edges()

	if intent_token == "":
		intent_token = "%d:%d:%d:%d" % [
			int(actor.id),
			source_year,
			source_age,
			source_frame
		]

	var guard: Dictionary = _life_safe_dictionary(
		gs.scenario_state.get(
			"age_up_temporal_intent_guard",
			{}
		)
	)

	if (
		not guard.is_empty()
		and str(
			guard.get(
				"intent_token",
				""
			)
		) == intent_token
		and bool(
			guard.get(
				"committed",
				false
			)
		)
	):
		var cached_report: Dictionary = (
			_life_safe_dictionary(
				guard.get(
					"route_report",
					{}
				)
			)
		)
		if not cached_report.is_empty():
			cached_report [
				"duplicate_temporal_intent_returned_cached_truth"
			] = true
			cached_report [
				"world_advanced_again"
			] = false
			cached_report [
				"compile_safe_life_dictionary_used"
			] = true
			return cached_report

	if (
		not guard.is_empty()
		and bool(
			guard.get(
				"active",
				false
			)
		)
		and int(
			guard.get(
				"source_frame",
				-1
			)
		) == source_frame
	):
		return {
			"success": true,
			"type": "age_up_intent_duplicate_ignored",
			"reason": (
				"same_input_frame_temporal_intent_already_active"
			),
			"actor_id": int(actor.id),
			"source_year": int(
				guard.get(
					"source_year",
					source_year
				)
			),
			"committed_year": int(gs.year),
			"source_age": int(
				guard.get(
					"source_age",
					source_age
				)
			),
			"committed_age": int(actor.age),
			"zero_frame_age_up": true,
			"world_advanced_again": false,
			"ui_called_engine_directly": false,
			"global_intent_routed": true,
			"compile_safe_life_dictionary_used": true
		}

	var intent_started_at_ms: int = int(
		Time.get_ticks_msec()
	)

	guard = {
		"schema": "eralife.age_up_temporal_intent_guard",
		"version": 4,
		"active": true,
		"committed": false,
		"intent_token": intent_token,
		"source_frame": source_frame,
		"actor_id": int(actor.id),
		"source_year": source_year,
		"source_age": source_age,
		"target_year": source_year + 1,
		"target_age": source_age + 1,
		"created_at_ms": intent_started_at_ms,
		"compile_safe_life_dictionary_used": true
	}

	gs.scenario_state [
		"age_up_temporal_intent_guard"
	] = guard.duplicate(false)

	var result: Dictionary = age_up()

	var committed_year: int = int(gs.year)
	var committed_age: int = int(actor.age)
	var expected_year: int = source_year + 1
	var expected_age: int = source_age + 1
	var corrected_double_advance: bool = false

	if committed_year > expected_year:
		gs.year = expected_year
		committed_year = expected_year
		corrected_double_advance = true

	if committed_age > expected_age:
		actor.age = expected_age
		committed_age = expected_age
		corrected_double_advance = true

	var visible_truth_committed: bool = (
		committed_year == expected_year
		and committed_age == expected_age
	)
	var result_declared_success: bool = bool(
		result.get(
			"success",
			not result.is_empty()
		)
	)
	var success: bool = (
		result_declared_success
		and visible_truth_committed
	)
	var rejection_reason: String = str(
		result.get(
			"reason",
			""
		)
	).strip_edges()

	if (
		not success
		and rejection_reason == ""
	):
		rejection_reason = (
			"age_up_visible_time_not_committed"
		)

	var route_report: Dictionary = {
		"success": success,
		"type": (
			"age_up_intent_resolved"
			if success
			else "age_up_intent_rejected"
		),
		"reason": rejection_reason,
		"actor_id": int(actor.id),
		"source_year": source_year,
		"committed_year": committed_year,
		"target_year": expected_year,
		"source_age": source_age,
		"committed_age": committed_age,
		"target_age": expected_age,
		"result": result.duplicate(false),
		"zero_frame_age_up": bool(
			result.get(
				"zero_frame_age_up",
				true
			)
		),
		"visible_truth_committed": visible_truth_committed,
		"world_tail_pending": (
			success
			and bool(
				result.get(
					"runtime_tail_pending",
					false
				)
			)
		),
		"double_advance_corrected": corrected_double_advance,
		"synchronous_world_iteration_performed": false,
		"synchronous_dependency_repair_performed": false,
		"synchronous_predictive_flush_performed": false,
		"ui_called_engine_directly": false,
		"global_intent_routed": true,
		"compile_safe_life_dictionary_used": true
	}

	guard ["active"] = false
	guard ["committed"] = visible_truth_committed
	guard ["committed_at_ms"] = (
		int(Time.get_ticks_msec())
		if visible_truth_committed
		else 0
	)
	guard ["committed_year"] = committed_year
	guard ["committed_age"] = committed_age
	guard ["route_report"] = route_report.duplicate(false)

	gs.scenario_state [
		"age_up_temporal_intent_guard"
	] = guard.duplicate(false)
	gs.scenario_state [
		"last_age_up_intent_actor_id"
	] = int(actor.id)
	gs.scenario_state [
		"last_age_up_intent_source_year"
	] = source_year
	gs.scenario_state [
		"last_age_up_intent_committed_year"
	] = committed_year
	gs.scenario_state [
		"last_age_up_intent_source_age"
	] = source_age
	gs.scenario_state [
		"last_age_up_intent_committed_age"
	] = committed_age
	gs.scenario_state [
		"last_age_up_intent_duration_ms"
	] = maxi(
		0,
		int(Time.get_ticks_msec()) - intent_started_at_ms
	)
	gs.scenario_state [
		"last_age_up_intent_global_route"
	] = bool(
		payload.get(
			"global_intent_routed",
			true
		)
	)
	gs.scenario_state [
		"last_age_up_intent_ui_called_engine_directly"
	] = false
	gs.scenario_state [
		"last_age_up_intent_one_year_only"
	] = true
	gs.scenario_state [
		"last_age_up_intent_compile_safe_dictionary_used"
	] = true
	gs.scenario_state [
		"last_age_up_intent_visible_truth_committed"
	] = visible_truth_committed

	return route_report
func _zero_frame_visible_result_for_current_year() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {}

	var candidates: Array = [
		gs.scenario_state.get("zero_frame_age_up_last_result", {}),
		gs.scenario_state.get("post_runtime_result", {}),
		gs.scenario_state.get("last_resolved_age_up_result", {})
	]

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = (raw_candidate as Dictionary).duplicate(true)
		if result.is_empty():
			continue
		if not bool(result.get("zero_frame_age_up", false)):
			continue

		var target_year: int = int(result.get("target_year", result.get("year", gs.year)))
		if target_year != int(gs.year):
			continue

		if gs.player != null:
			var target_age: int = int(result.get("target_age", result.get("age", gs.player.age)))
			if target_age != int(gs.player.age):
				continue

		return result.duplicate(true)

	return {}
func _zero_frame_age_up_cache_for_target(
	target_year: int
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
	):
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var cache_raw: Variant = (
		gs.scenario_state.get(
			"speculative_next_year_cache",
			{}
		)
	)

	if typeof(
		cache_raw
	) != TYPE_DICTIONARY:
		return {}

	var cache: Dictionary = (
		cache_raw as Dictionary
	)

	if cache.is_empty():
		return {}

	if not bool(
		cache.get(
			"ready",
			false
		)
	):
		return {}

	if int(
		cache.get(
			"year",
			-999999
		)
	) != target_year:
		return {}

	if int(
		cache.get(
			"player_id",
			-999999
		)
	) != int(
		gs.player.id
	):
		return {}




	return cache.duplicate(
		false
	)

func _build_zero_frame_age_up_result(
	time_contract: Dictionary,
	precompute_cache: Dictionary,
	reason: String = "zero_frame_age_up"
) -> Dictionary:
	var source_year: int = int(
		time_contract.get(
			"source_year",
			gs.year if gs != null else 0
		)
	)
	var target_year: int = int(
		time_contract.get(
			"target_year",
			source_year + 1
		)
	)
	var source_age: int = int(
		time_contract.get(
			"source_age",
			gs.player.age
			if gs != null and gs.player != null
			else 0
		)
	)
	var target_age: int = int(
		time_contract.get(
			"target_age",
			source_age + 1
		)
	)
	var precompute_ready: bool = (
		not precompute_cache.is_empty()
		and bool(
			precompute_cache.get(
				"ready",
				false
			)
		)
	)

	var text: String = "Another year passed."
	if precompute_ready:
		text = "Another year unfolded."




	return {
		"type": "year_passed",
		"text": text,
		"opps": [],
		"zero_frame_age_up": true,
		"zero_frame_age_up_schema": (
			"eralife.zero_frame_age_up_result"
		),
		"zero_frame_age_up_version": 3,
		"source_year": source_year,
		"target_year": target_year,
		"source_age": source_age,
		"target_age": target_age,
		"year": target_year,
		"age": target_age,
		"precompute_ready": precompute_ready,
		"precompute_signature": str(
			precompute_cache.get(
				"signature",
				""
			)
		),
		"runtime_tail_pending": true,
		"runtime_tail_policy": {
			"ui_activity_is_scheduler_input": false,
			"idle_required": false,
			"ui_is_pure_renderer": true,
		},
		"popup_title": "Year %d" % target_year,
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue.",
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"reason": reason
	}
func _commit_zero_frame_age_up_visible_time(
	time_contract: Dictionary,
	result: Dictionary,
	reason: String = "zero_frame_age_up"
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
	):
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var source_year: int = int(
		time_contract.get(
			"source_year",
			gs.year
		)
	)
	var target_year: int = int(
		time_contract.get(
			"target_year",
			source_year + 1
		)
	)
	var source_age: int = int(
		time_contract.get(
			"source_age",
			gs.player.age
		)
	)
	var target_age: int = int(
		time_contract.get(
			"target_age",
			source_age + 1
		)
	)

	if target_year <= source_year:
		target_year = source_year + 1

	if target_age <= source_age:
		target_age = source_age + 1

	var core_identity_policy_raw: Variant = (
		time_contract.get(
			"core_identity_policy",
			{}
		)
	)
	var core_identity_policy: Dictionary = (
		core_identity_policy_raw as Dictionary
		if typeof(
			core_identity_policy_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var contract_advances_year: bool = bool(
		core_identity_policy.get(
			"advance_year",
			true
		)
	)
	var year_lock_was_active: bool = bool(
		gs.year_locked
	)







	if contract_advances_year:
		gs.year = target_year

	gs.player.age = target_age

	if (
		gs.health_engine != null
		and gs.health_engine.has_method(
			"enforce_mortal_age_cap"
		)
	):
		gs.health_engine.enforce_mortal_age_cap(
			gs.player
		)

	if gs.player.has_method(
		"set_meta"
	):
		gs.player.set_meta(
			"last_temporal_biology_year",
			target_year
		)
		gs.player.set_meta(
			"last_age_up_time_truth_year",
			target_year
		)
		gs.player.set_meta(
			"last_age_up_time_truth_reason",
			reason
		)

	var pending_npc_report: Dictionary = {
		"schema": (
			"eralife.age_up_npc_time_truth_report"
		),
		"version": 2,
		"reason": "%s_background_stream" % reason,
		"started_from_year": source_year,
		"target_year": target_year,
		"streaming_pending": true,
		"deferred_to_zero_frame_tail": true,
		"aged_npcs": 0
	}

	result [
		"npc_time_truth_committed"
	] = false
	result [
		"npc_time_truth_pending"
	] = true
	result [
		"npc_time_truth_report"
	] = pending_npc_report.duplicate(
		false
	)
	result [
		"visible_time_commit_is_constant_time"
	] = true
	result [
		"npc_iteration_on_press"
	] = false
	result [
		"recursive_copy_on_visible_commit"
	] = false
	result [
		"year_lock_was_active"
	] = year_lock_was_active
	result [
		"explicit_age_up_contract_owns_year_commit"
	] = contract_advances_year
	result [
		"year_lock_vetoed_explicit_age_up_contract"
	] = false

	gs.scenario_state [
		"age_up_started_npc_ages"
	] = {}
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_cursor"
	] = 0
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_complete"
	] = false
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_pending"
	] = true
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_cursor"
	] = 0
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_complete"
	] = false
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_pending"
	] = true
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_source_year"
	] = source_year
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_target_year"
	] = target_year
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_report"
	] = pending_npc_report.duplicate(
		false
	)

	gs.scenario_state [
		"zero_frame_age_up_active"
	] = true
	gs.scenario_state [
		"zero_frame_age_up_last_commit_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"zero_frame_age_up_last_reason"
	] = reason




	gs.scenario_state [
		"zero_frame_age_up_last_result"
	] = result.duplicate(
		false
	)
	gs.scenario_state [
		"age_up_time_contract"
	] = time_contract.duplicate(
		false
	)

	gs.scenario_state [
		"age_up_contract_open"
	] = false
	gs.scenario_state [
		"age_up_contract_transaction_id"
	] = "%d:%d:%d:%d" % [
		source_year,
		target_year,
		source_age,
		target_age
	]
	gs.scenario_state [
		"age_up_requested_year"
	] = target_year
	gs.scenario_state [
		"age_up_started_from_year"
	] = source_year
	gs.scenario_state [
		"age_up_started_from_age"
	] = source_age
	gs.scenario_state [
		"age_up_truth_expected_target_age"
	] = target_age
	gs.scenario_state [
		"age_up_truth_owner"
	] = "zero_frame_age_up_visible_commit"
	gs.scenario_state [
		"age_up_npc_time_truth_committed_with_visible_time"
	] = false
	gs.scenario_state [
		"age_up_npc_time_truth_deferred_from_visible_time"
	] = true
	gs.scenario_state [
		"age_up_visible_time_commit_iterated_npcs"
	] = false
	gs.scenario_state [
		"age_up_relationship_lenses_must_refresh"
	] = true
	gs.scenario_state [
		"age_up_relationship_lenses_refresh_year"
	] = target_year
	gs.scenario_state [
		"age_up_explicit_contract_overrode_year_lock"
	] = (
		year_lock_was_active
		and contract_advances_year
	)
	gs.scenario_state [
		"year_in_progress"
	] = false
	gs.scenario_state [
		"bundle_built"
	] = false
	gs.scenario_state [
		"runtime_prepared_scenario_setup"
	] = {}

	gs.scenario_state [
		"post_runtime_result"
	] = result.duplicate(
		false
	)
	gs.scenario_state [
		"last_resolved_age_up_result"
	] = result.duplicate(
		false
	)

	return {
		"success": true,
		"mode": "zero_frame_visible_time_committed",
		"source_year": source_year,
		"target_year": target_year,
		"source_age": source_age,
		"target_age": target_age,
		"npc_time_truth_committed": false,
		"npc_time_truth_pending": true,
		"npc_time_truth_report": (
			pending_npc_report.duplicate(
				false
			)
		),
		"visible_time_commit_is_constant_time": true,
		"npc_iteration_on_press": false,
		"year_lock_was_active": year_lock_was_active,
		"explicit_age_up_contract_owns_year_commit": (
			contract_advances_year
		)
	}
func _queue_zero_frame_age_up_tail_runtime(
	time_contract: Dictionary,
	precompute_cache: Dictionary,
	reason: String = "zero_frame_age_up"
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
	):
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var target_year: int = int(
		time_contract.get(
			"target_year",
			gs.year
		)
	)
	var source_year: int = int(
		time_contract.get(
			"source_year",
			target_year - 1
		)
	)
	var target_age: int = int(
		time_contract.get(
			"target_age",
			gs.player.age
		)
	)
	var player_id: int = int(
		gs.player.id
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var precompute_ready: bool = (
		not precompute_cache.is_empty()
		and bool(
			precompute_cache.get(
				"ready",
				false
			)
		)
	)

	if precompute_ready:
		gs.scenario_state [
			"warm_runtime_plan"
		] = {
			"year": target_year,
			"mode": "living",
			"player_id": player_id,
			"plan": precompute_cache.get(
				"plan",
				{}
			),
			"source": "zero_frame_age_up_precompute_cache",
			"signature": str(
				precompute_cache.get(
					"signature",
					""
				)
			),
			"created_at_ms": int(
				precompute_cache.get(
					"created_at_ms",
					now_ms
				)
			),
		}

	var marked_cache: Dictionary = (
		precompute_cache.duplicate(
			false
		)
	)

	marked_cache ["used"] = true
	marked_cache ["used_at_ms"] = now_ms
	marked_cache ["used_by"] = reason

	gs.scenario_state [
		"speculative_next_year_cache"
	] = marked_cache
	gs.scenario_state [
		"defer_runtime_plan_build"
	] = not precompute_ready
	gs.scenario_state [
		"age_up_tail_runtime_pending"
	] = true
	gs.scenario_state [
		"age_up_tail_runtime_next_ms"
	] = 0
	gs.scenario_state [
		"age_up_tail_runtime_started_ms"
	] = 0
	gs.scenario_state [
		"age_up_tail_runtime_reason"
	] = reason
	gs.scenario_state [
		"age_up_tail_runtime_time_contract"
	] = time_contract.duplicate(false)
	gs.scenario_state [
		"age_up_tail_last_phase"
	] = "queued"
	gs.scenario_state [
		"age_up_tail_runtime_service_owner"
	] = "life_engine_autonomous"
	gs.scenario_state [
		"age_up_tail_runtime_autonomous_service_owned"
	] = true
	gs.scenario_state [
		"age_up_tail_runtime_main_scene_service_required"
	] = false
	gs.scenario_state [
		"age_up_tail_runtime_process_frame_service"
	] = true
	gs.scenario_state [
		"age_up_tail_runtime_service_requires_idle"
	] = false
	gs.scenario_state [
		"age_up_tail_runtime_service_waits_for_render"
	] = false
	gs.scenario_state [
		"age_up_tail_runtime_service_uses_call_deferred"
	] = false


	gs.scenario_state [
		"age_up_deferred_flush_pending"
	] = false
	gs.scenario_state.erase(
		"age_up_deferred_flush_next_ms"
	)
	gs.scenario_state [
		"age_up_tail_was_queued_without_deep_copy"
	] = true
	gs.scenario_state [
		"age_up_tail_blocks_visible_time"
	] = false
	gs.scenario_state [
		"age_up_tail_ui_concurrent"
	] = true
	gs.scenario_state [
		"age_up_tail_idle_required"
	] = false
	gs.scenario_state [
		"age_up_tail_ui_activity_is_scheduler_input"
	] = false

	var guard_raw: Variant = (
		gs.scenario_state.get(
			"runtime_guard",
			{}
		)
	)
	var guard: Dictionary = (
		guard_raw
		if typeof(
			guard_raw
		) == TYPE_DICTIONARY
		else {}
	)

	guard ["zero_frame_age_up"] = true
	guard ["ui_tail_work_yield_to_input"] = false
	guard ["defer_noncritical_systems"] = false
	guard ["tail_runtime_after_visible_commit"] = true
	guard ["visible_time_already_committed"] = true
	guard ["visible_ui_waits_for_tail"] = false
	guard ["continuous_reality_service"] = true
	guard ["ui_activity_is_scheduler_input"] = false
	guard ["commit_budget_cap"] = 1
	guard ["phase_budget_cap"] = 1
	guard ["post_age_up_tail_flush_budget"] = 1
	guard [
		"post_age_up_tail_flush_interval_ms"
	] = 1

	gs.scenario_state [
		"runtime_guard"
	] = guard






	gs.scenario_state [
		"age_up_world_feed_publication_pending"
	] = true
	gs.scenario_state [
		"age_up_world_feed_publication_source_year"
	] = source_year
	gs.scenario_state [
		"age_up_world_feed_publication_target_year"
	] = target_year
	gs.scenario_state [
		"age_up_world_feed_publication_target_age"
	] = target_age
	gs.scenario_state [
		"age_up_world_feed_publication_reason"
	] = (
		"%s_world_feed_publication"
		% reason
	)
	gs.scenario_state [
		"age_up_world_feed_publication_queued_before_tail_service"
	] = false
	gs.scenario_state [
		"age_up_world_feed_publication_blocks_visible_time"
	] = false






	var visible_commit_process_frame: int = int(
		Engine.get_process_frames()
	)

	gs.scenario_state [
		"age_up_visible_commit_process_frame"
	] = visible_commit_process_frame
	gs.scenario_state [
		"age_up_tail_runtime_not_before_process_frame"
	] = visible_commit_process_frame + 1
	gs.scenario_state [
		"age_up_tail_runtime_first_visible_paint_guard"
	] = true
	gs.scenario_state [
		"age_up_tail_runtime_first_visible_paint_guard_requires_idle"
	] = false
	gs.scenario_state [
		"age_up_tail_runtime_first_visible_paint_guard_requires_renderer_ack"
	] = false

	_arm_zero_frame_age_up_tail_runtime_service()

	return {
		"success": true,
		"mode": "zero_frame_tail_runtime_queued",
		"target_year": target_year,
		"player_id": player_id,
		"precompute_ready": precompute_ready,
		"visible_ui_waits_for_tail": false,
		"ui_concurrent": true,
		"idle_required": false,
		"ui_activity_is_scheduler_input": false,
		"service_owner": "life_engine_autonomous",
	}
func _arm_zero_frame_age_up_tail_runtime_service() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if not bool(
		gs.scenario_state.get(
			"age_up_tail_runtime_pending",
			false
		)
	):
		set_meta(
			"zero_frame_age_up_tail_runtime_service_armed",
			false
		)
		return

	if bool(
		get_meta(
			"zero_frame_age_up_tail_runtime_service_armed",
			false
		)
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		gs.scenario_state [
			"age_up_tail_runtime_service_tree_missing"
		] = true

		gs.scenario_state [
			"age_up_tail_runtime_service_tree_missing_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		return

	set_meta(
		"zero_frame_age_up_tail_runtime_service_armed",
		true
	)

	var connection_error: int = (
		tree.process_frame.connect(
			Callable(
				self,
				"_service_zero_frame_age_up_tail_runtime_quantum"
			),
			CONNECT_ONE_SHOT
		)
	)

	if connection_error != OK:
		set_meta(
			"zero_frame_age_up_tail_runtime_service_armed",
			false
		)

		gs.scenario_state [
			"age_up_tail_runtime_service_connect_error"
		] = connection_error

		gs.scenario_state [
			"age_up_tail_runtime_service_connect_error_at_ms"
		] = int(
			Time.get_ticks_msec()
		)


func _service_zero_frame_age_up_tail_runtime_quantum() -> void:
	set_meta(
		"zero_frame_age_up_tail_runtime_service_armed",
		false
	)

	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if not bool(
		gs.scenario_state.get(
			"age_up_tail_runtime_pending",
			false
		)
	):
		gs.scenario_state [
			"age_up_tail_runtime_autonomous_service_active"
		] = false

		return

	var current_process_frame: int = int(
		Engine.get_process_frames()
	)
	var not_before_process_frame: int = int(
		gs.scenario_state.get(
			"age_up_tail_runtime_not_before_process_frame",
			-1
		)
	)






	if (
		not_before_process_frame >= 0
		and current_process_frame <= not_before_process_frame
	):
		gs.scenario_state [
			"age_up_tail_runtime_autonomous_service_active"
		] = true
		gs.scenario_state [
			"age_up_tail_last_phase"
		] = "first_visible_paint_guard"
		gs.scenario_state [
			"age_up_tail_runtime_first_visible_paint_guard_serviced"
		] = true
		gs.scenario_state [
			"age_up_tail_runtime_first_visible_paint_guard_frame"
		] = current_process_frame
		gs.scenario_state [
			"age_up_tail_runtime_first_visible_paint_guard_requires_idle"
		] = false
		gs.scenario_state [
			"age_up_tail_runtime_first_visible_paint_guard_requires_renderer_ack"
		] = false

		_arm_zero_frame_age_up_tail_runtime_service()

		return

	gs.scenario_state.erase(
		"age_up_tail_runtime_not_before_process_frame"
	)

	var quantum_started_ms: int = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [
		"age_up_tail_runtime_autonomous_service_active"
	] = true
	gs.scenario_state [
		"age_up_tail_runtime_last_autonomous_quantum_frame"
	] = current_process_frame

	var report: Dictionary = (
		continue_zero_frame_age_up_tail_runtime(
			1,
			1
		)
	)

	var quantum_finished_ms: int = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [
		"age_up_tail_runtime_last_autonomous_report"
	] = report.duplicate(
		false
	)
	gs.scenario_state [
		"age_up_tail_runtime_last_autonomous_quantum_ms"
	] = maxi(
		0,
		quantum_finished_ms - quantum_started_ms
	)
	gs.scenario_state [
		"age_up_tail_runtime_last_autonomous_quantum_at_ms"
	] = quantum_finished_ms

	var relationship_priority_year: int = int(
		gs.scenario_state.get(
			"age_up_relationship_priority_biology_quantum_year",
			-999999
		)
	)
	var world_feed_pending: bool = bool(
		gs.scenario_state.get(
			"age_up_world_feed_publication_pending",
			false
		)
	)




	if (
		world_feed_pending
		and relationship_priority_year == int(
			gs.scenario_state.get(
				"age_up_world_feed_publication_target_year",
				gs.year
			)
		)
	):
		_push_age_up_world_feed_once(
			int(
				gs.scenario_state.get(
					"age_up_world_feed_publication_source_year",
					gs.year - 1
				)
			),
			int(
				gs.scenario_state.get(
					"age_up_world_feed_publication_target_year",
					gs.year
				)
			),
			int(
				gs.scenario_state.get(
					"age_up_world_feed_publication_target_age",
					(
						gs.player.age
						if gs.player != null
						else 0
					)
				)
			),
			str(
				gs.scenario_state.get(
					"age_up_world_feed_publication_reason",
					"zero_frame_age_up_world_feed_publication"
				)
			)
		)

		gs.scenario_state [
			"age_up_world_feed_publication_pending"
		] = false
		gs.scenario_state [
			"age_up_world_feed_publication_published_after_relationship_priority"
		] = true
		gs.scenario_state [
			"age_up_world_feed_publication_published_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	var is_complete: bool = bool(
		report.get(
			"is_complete",
			false
		)
	)

	if is_complete:
		gs.scenario_state [
			"age_up_tail_runtime_autonomous_service_active"
		] = false
		gs.scenario_state [
			"age_up_tail_runtime_autonomous_service_completed_at_ms"
		] = quantum_finished_ms




		if bool(
			gs.scenario_state.get(
				"age_up_world_feed_publication_pending",
				false
			)
		):
			_push_age_up_world_feed_once(
				int(
					gs.scenario_state.get(
						"age_up_world_feed_publication_source_year",
						gs.year - 1
					)
				),
				int(
					gs.scenario_state.get(
						"age_up_world_feed_publication_target_year",
						gs.year
					)
				),
				int(
					gs.scenario_state.get(
						"age_up_world_feed_publication_target_age",
						(
							gs.player.age
							if gs.player != null
							else 0
						)
					)
				),
				str(
					gs.scenario_state.get(
						"age_up_world_feed_publication_reason",
						"zero_frame_age_up_world_feed_publication"
					)
				)
			)

			gs.scenario_state [
				"age_up_world_feed_publication_pending"
			] = false

		return




	_arm_zero_frame_age_up_tail_runtime_service()
func continue_zero_frame_age_up_tail_runtime(
	max_phase_steps: int = 1,
	max_commit_stages: int = 1
) -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if not bool(
		gs.scenario_state.get(
			"age_up_tail_runtime_pending",
			false
		)
	):
		return {
			"success": true,
			"mode": "zero_frame_tail_not_pending",
			"is_complete": true
		}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var time_contract_raw: Variant = (
		gs.scenario_state.get(
			"age_up_tail_runtime_time_contract",
			gs.scenario_state.get(
				"age_up_time_contract",
				{}
			)
		)
	)

	var time_contract: Dictionary = (
		time_contract_raw as Dictionary
		if typeof(time_contract_raw) == TYPE_DICTIONARY
		else {}
	)

	var source_year: int = int(
		time_contract.get(
			"source_year",
			gs.year - 1
		)
	)

	var target_year: int = int(
		time_contract.get(
			"target_year",
			gs.year
		)
	)

	var target_age: int = int(
		time_contract.get(
			"target_age",
			(
				gs.player.age
				if gs.player != null
				else 0
			)
		)
	)

	gs.scenario_state [
		"age_up_time_contract"
	] = time_contract.duplicate(
		false
	)

	gs.scenario_state [
		"age_up_contract_open"
	] = false

	gs.scenario_state [
		"age_up_tail_runtime_started_ms"
	] = int(
		gs.scenario_state.get(
			"age_up_tail_runtime_started_ms",
			now_ms
		)
	)

	gs.scenario_state [
		"age_up_tail_runtime_next_ms"
	] = 0

	var step_report: Dictionary = {}
	var runtime_engine_missing: bool = (
		runtime_engine == null
	)
	var pipeline_pending: bool = false

	if runtime_engine_missing:
		if not bool(
			gs.scenario_state.get(
				"age_up_zero_frame_npc_snapshot_complete",
				false
			)
		):
			var snapshot_report: Dictionary = (
				_step_zero_frame_age_up_npc_snapshot(
					12,
					1
				)
			)

			gs.scenario_state [
				"age_up_tail_last_phase"
			] = "npc_source_age_snapshot_recovery"

			if not bool(
				snapshot_report.get(
					"complete",
					false
				)
			):
				return {
					"success": true,
					"mode": "zero_frame_tail_snapshot_streaming_recovery",
					"is_complete": false,
					"snapshot_report": snapshot_report.duplicate(false),
					"idle_required": false,
					"ui_activity_is_scheduler_input": false
				}
	else:
		if (
			runtime_engine.has_method(
				"has_active_runtime_slice"
			)
			and not bool(
				runtime_engine.has_active_runtime_slice()
			)
		):
			if not runtime_engine.has_pending_commit():
				runtime_engine.begin_year_transaction(
					{
						"mode": "living",
						"year": target_year,
						"player_id": int(
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
						),
						"runtime_owner": "zero_frame_tail_runtime",
						"zero_frame_tail": true,
						"time_contract": time_contract.duplicate(false),
						"contract_target_year": target_year,
						"contract_target_age": target_age,
						"continuous_reality_service": true,
						"ui_activity_is_scheduler_input": false
					}
				)

		if runtime_engine.has_method(
			"begin_runtime_slice_session"
		):
			runtime_engine.begin_runtime_slice_session()

	var phase_quantum: int = 1
	var commit_quantum: int = 1

	set_meta(
		"zero_frame_age_up_tail_requested_phase_steps",
		maxi(
			1,
			max_phase_steps
		)
	)

	set_meta(
		"zero_frame_age_up_tail_requested_commit_stages",
		maxi(
			1,
			max_commit_stages
		)
	)

	if (
		not runtime_engine_missing
		and runtime_engine.has_method(
			"run_year_runtime_slice"
		)
	):
		step_report = (
			runtime_engine.run_year_runtime_slice(
				phase_quantum,
				commit_quantum
			)
		)

	elif (
		not runtime_engine_missing
		and runtime_engine.has_pending_commit()
	):
		runtime_engine.drain_pending_commit(
			commit_quantum
		)

		step_report = {
			"state": "running",
			"is_complete": (
				not runtime_engine.has_pending_commit()
			)
		}

	if not runtime_engine_missing:
		var runtime_still_active: bool = false

		if runtime_engine.has_method(
			"has_active_runtime_slice"
		):
			runtime_still_active = bool(
				runtime_engine.has_active_runtime_slice()
			)

		pipeline_pending = (
			runtime_still_active
			or runtime_engine.has_pending_commit()
		)

	if (
		gs.year_budget_engine != null
		and gs.year_budget_engine.has_pending_year_pipeline()
	):
		pipeline_pending = true







	var observed_npc_truth_report: Dictionary = {}
	var observed_relationship_refresh_report: Dictionary = {}

	if not runtime_engine_missing:
		observed_npc_truth_report = (
			_commit_npc_time_truth_for_age_up(
				source_year,
				target_year,
				"zero_frame_tail_runtime_receipt_observation"
			)
		)

		if bool(
			observed_npc_truth_report.get(
				"complete",
				false
			)
		):
			observed_relationship_refresh_report = (
				_queue_age_up_relationship_projection_refresh(
					source_year,
					target_year,
					int(
						time_contract.get(
							"player_id",
							-1
						)
					)
				)
			)

	if pipeline_pending:
		gs.scenario_state [
			"age_up_tail_runtime_next_ms"
		] = 0

		gs.scenario_state [
			"age_up_tail_last_phase"
		] = str(
			step_report.get(
				"current_phase",
				"runtime_pipeline"
			)
		)

		return {
			"success": true,
			"mode": "zero_frame_tail_runtime_running",
			"is_complete": false,
			"step_report": step_report.duplicate(false),
			"npc_time_truth_report": (
				observed_npc_truth_report.duplicate(false)
			),
			"relationship_refresh_report": (
				observed_relationship_refresh_report.duplicate(false)
			),
			"phase_quantum": 1,
			"commit_quantum": 1,
			"idle_required": false,
			"ui_activity_is_scheduler_input": false
		}

	var npc_truth_report: Dictionary = (
		observed_npc_truth_report.duplicate(
			false
		)
	)

	if runtime_engine_missing:
		npc_truth_report = (
			_step_zero_frame_age_up_npc_time_truth(
				source_year,
				target_year,
				"zero_frame_tail_runtime_recovery",
				96,
				2
			)
		)

		if not bool(
			npc_truth_report.get(
				"complete",
				false
			)
		):
			gs.scenario_state [
				"age_up_tail_runtime_next_ms"
			] = 0

			gs.scenario_state [
				"age_up_tail_last_phase"
			] = "npc_time_truth_stream_recovery"

			return {
				"success": true,
				"mode": "zero_frame_tail_npc_truth_streaming_recovery",
				"is_complete": false,
				"step_report": step_report.duplicate(false),
				"npc_time_truth_report": npc_truth_report.duplicate(false),
				"idle_required": false,
				"ui_activity_is_scheduler_input": false
			}

		gs.scenario_state [
			"age_up_tail_runtime_next_ms"
		] = 0

		gs.scenario_state [
			"age_up_tail_last_phase"
		] = "runtime_authority_recovery_required"

		return {
			"success": false,
			"mode": "zero_frame_tail_runtime_authority_missing",
			"is_complete": false,
			"npc_time_truth_report": npc_truth_report.duplicate(false),
			"reason": "runtime_authority_recovery_required",
			"idle_required": false,
			"ui_activity_is_scheduler_input": false
		}

	if not bool(
		npc_truth_report.get(
			"complete",
			false
		)
	):
		npc_truth_report = (
			_commit_npc_time_truth_for_age_up(
				source_year,
				target_year,
				"zero_frame_tail_runtime_receipt"
			)
		)

	if not bool(
		npc_truth_report.get(
			"complete",
			false
		)
	):
		gs.scenario_state [
			"age_up_tail_runtime_next_ms"
		] = 0

		gs.scenario_state [
			"age_up_tail_last_phase"
		] = "npc_time_truth_receipt"

		return {
			"success": true,
			"mode": "zero_frame_tail_waiting_for_npc_receipt",
			"is_complete": false,
			"step_report": step_report.duplicate(false),
			"npc_time_truth_report": npc_truth_report.duplicate(false),
			"idle_required": false,
			"ui_activity_is_scheduler_input": false
		}

	var relationship_refresh_report: Dictionary = (
		observed_relationship_refresh_report.duplicate(
			false
		)
	)

	if relationship_refresh_report.is_empty():
		relationship_refresh_report = (
			_queue_age_up_relationship_projection_refresh(
				source_year,
				target_year,
				int(
					time_contract.get(
						"player_id",
						-1
					)
				)
			)
		)

	var annual_batch_key: String = (
		"runtime_year_passed|%d"
		% target_year
	)

	var annual_fanout_report: Dictionary = {}

	if (
		gs.event_bus != null
		and gs.event_bus.has_method(
			"get_deferred_batch_receipt"
		)
	):
		annual_fanout_report = (
			gs.event_bus.get_deferred_batch_receipt(
				annual_batch_key
			)
		)

	var annual_fanout_delivery_pending: bool = (
		not annual_fanout_report.is_empty()
		and (
			not bool(
				annual_fanout_report.get(
					"is_complete",
					false
				)
			)
			or int(
				annual_fanout_report.get(
					"pending_handlers",
					0
				)
			) > 0
		)
	)

	gs.scenario_state [
		"age_up_annual_event_fanout_observation_only"
	] = true
	gs.scenario_state [
		"age_up_annual_event_fanout_delivery_pending"
	] = annual_fanout_delivery_pending
	gs.scenario_state [
		"age_up_annual_event_fanout_completion_gate"
	] = false
	gs.scenario_state [
		"age_up_annual_event_fanout_batch_key"
	] = annual_batch_key
	gs.scenario_state [
		"age_up_annual_event_fanout_last_receipt"
	] = annual_fanout_report.duplicate(
		false
	)

	gs.scenario_state [
		"age_up_contract_last_completed"
	] = {
		"source_year": source_year,
		"target_year": target_year,
		"target_age": target_age,
		"npc_receipt_key": str(
			npc_truth_report.get(
				"receipt_key",
				""
			)
		),
		"annual_batch_key": annual_batch_key,
		"annual_fanout_report": annual_fanout_report.duplicate(false),
		"relationship_refresh_report": (
			relationship_refresh_report.duplicate(false)
		),
		"completed_at_ms": now_ms,
		"reason": "zero_frame_tail_runtime_complete"
	}

	gs.scenario_state [
		"age_up_tail_runtime_pending"
	] = false

	gs.scenario_state.erase(
		"age_up_tail_runtime_next_ms"
	)

	gs.scenario_state.erase(
		"age_up_tail_runtime_started_ms"
	)

	gs.scenario_state [
		"age_up_tail_last_phase"
	] = "complete"

	gs.scenario_state [
		"age_up_deferred_flush_pending"
	] = false

	gs.scenario_state.erase(
		"age_up_deferred_flush_next_ms"
	)

	return {
		"success": true,
		"mode": "zero_frame_tail_runtime_complete",
		"is_complete": true,
		"step_report": step_report.duplicate(false),
		"npc_time_truth_report": npc_truth_report.duplicate(false),
		"annual_batch_key": annual_batch_key,
		"annual_fanout_report": annual_fanout_report.duplicate(false),
		"relationship_refresh_report": (
			relationship_refresh_report.duplicate(false)
		),
		"phase_quantum": 1,
		"commit_quantum": 1,
		"idle_required": false,
		"ui_activity_is_scheduler_input": false
	}
func _step_zero_frame_age_up_npc_snapshot(
		max_items: int = 48,
		frame_budget_ms: int = 2
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"complete": false,
			"reason": "missing_game_state"
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var snapshot_raw: Variant = (
		gs.scenario_state.get(
			"age_up_started_npc_ages",
			{}
		)
	)
	var snapshot: Dictionary = (
		snapshot_raw
		if typeof(
			snapshot_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var cursor: int = maxi(
		0,
		int(
			gs.scenario_state.get(
				"age_up_zero_frame_npc_snapshot_cursor",
				0
			)
		)
	)
	var total: int = gs.npcs.size()
	var processed: int = 0
	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var item_limit: int = maxi(
		1,
		max_items
	)
	var budget_ms: int = maxi(
		1,
		frame_budget_ms
	)

	while (
		cursor < total
		and processed < item_limit
	):
		if (
			processed > 0
			and int(
				Time.get_ticks_msec()
			) - started_ms >= budget_ms
		):
			break

		var npc_raw: Variant = gs.npcs [
			cursor
		]

		cursor += 1
		processed += 1

		if not (
			npc_raw is Person
		):
			continue

		var npc: Person = npc_raw as Person
		var npc_id: int = int(
			npc.id
		)

		if npc_id <= 0:
			continue

		snapshot [
			str(
				npc_id
			)
		] = int(
			npc.age
		)

	var complete: bool = (
		cursor >= total
	)

	gs.scenario_state [
		"age_up_started_npc_ages"
	] = snapshot
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_cursor"
	] = cursor
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_total"
	] = total
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_complete"
	] = complete
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_pending"
	] = not complete
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_last_batch"
	] = processed
	gs.scenario_state [
		"age_up_zero_frame_npc_snapshot_last_batch_ms"
	] = maxi(
		0,
		int(
			Time.get_ticks_msec()
		) - started_ms
	)

	return {
		"success": true,
		"complete": complete,
		"cursor": cursor,
		"total": total,
		"processed": processed,
		"snapshot_size": snapshot.size(),
		"frame_budget_ms": budget_ms,
		"all_population_iteration_on_one_frame": false
	}
func _step_zero_frame_age_up_npc_time_truth(
		started_from_year: int,
		target_year: int,
		reason: String,
		max_items: int = 48,
		frame_budget_ms: int = 2
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"complete": false,
			"reason": "missing_game_state"
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var commit_key: String = (
		"npc_time_truth|%d|%d"
		% [
			started_from_year,
			target_year
		]
	)
	var commit_registry_raw: Variant = (
		gs.scenario_state.get(
			"age_up_npc_time_truth_registry",
			{}
		)
	)
	var commit_registry: Dictionary = (
		commit_registry_raw
		if typeof(
			commit_registry_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		commit_registry.get(
			commit_key,
			false
		)
	):
		var cached_raw: Variant = (
			gs.scenario_state.get(
				"last_age_up_npc_time_truth_report",
				{}
			)
		)
		var cached: Dictionary = (
			(
				cached_raw as Dictionary
			).duplicate(false)
			if typeof(
				cached_raw
			) == TYPE_DICTIONARY
			else {}
		)

		cached [
			"success"
		] = true
		cached [
			"complete"
		] = true
		cached [
			"already_applied"
		] = true

		return cached

	var snapshot_raw: Variant = (
		gs.scenario_state.get(
			"age_up_started_npc_ages",
			{}
		)
	)
	var snapshot: Dictionary = (
		snapshot_raw
		if typeof(
			snapshot_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if not bool(
		gs.scenario_state.get(
			"age_up_zero_frame_npc_snapshot_complete",
			false
		)
	):
		return {
			"success": true,
			"complete": false,
			"reason": "npc_source_age_snapshot_pending",
			"streaming_pending": true
		}

	var report_raw: Variant = (
		gs.scenario_state.get(
			"age_up_zero_frame_npc_truth_stream_report",
			{}
		)
	)
	var report: Dictionary = (
		report_raw
		if typeof(
			report_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if report.is_empty():
		report = {
			"schema": (
				"eralife.age_up_npc_time_truth_report"
			),
			"version": 2,
			"reason": reason,
			"started_from_year": started_from_year,
			"target_year": target_year,
			"already_applied": false,
			"aged_npcs": 0,
			"corrected_overadvanced_npcs": 0,
			"corrected_underadvanced_npcs": 0,
			"skipped_player": 0,
			"skipped_dead": 0,
			"skipped_missing_snapshot": 0,
			"event_count": 0,
			"death_checks": 0,
			"aged_ids": [],
			"streaming_pending": true
		}

	var aged_ids_raw: Variant = report.get(
		"aged_ids",
		[]
	)
	var aged_ids: Array = (
		aged_ids_raw
		if typeof(
			aged_ids_raw
		) == TYPE_ARRAY
		else []
	)
	var cursor: int = maxi(
		0,
		int(
			gs.scenario_state.get(
				"age_up_zero_frame_npc_truth_cursor",
				0
			)
		)
	)
	var total: int = gs.npcs.size()
	var processed: int = 0
	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var item_limit: int = maxi(
		1,
		max_items
	)
	var budget_ms: int = maxi(
		1,
		frame_budget_ms
	)

	while (
		cursor < total
		and processed < item_limit
	):
		if (
			processed > 0
			and int(
				Time.get_ticks_msec()
			) - started_ms >= budget_ms
		):
			break

		var npc_raw: Variant = gs.npcs [
			cursor
		]

		cursor += 1
		processed += 1

		if not (
			npc_raw is Person
		):
			continue

		var npc: Person = npc_raw as Person

		if (
			gs.player != null
			and int(
				npc.id
			) == int(
				gs.player.id
			)
		):
			report [
				"skipped_player"
			] = int(
				report.get(
					"skipped_player",
					0
				)
			) + 1
			continue

		if not bool(
			npc.alive
		):
			report [
				"skipped_dead"
			] = int(
				report.get(
					"skipped_dead",
					0
				)
			) + 1
			continue

		var npc_key: String = str(
			int(
				npc.id
			)
		)

		if not snapshot.has(
			npc_key
		):
			report [
				"skipped_missing_snapshot"
			] = int(
				report.get(
					"skipped_missing_snapshot",
					0
				)
			) + 1
			continue

		var previous_age: int = int(
			snapshot.get(
				npc_key,
				npc.age
			)
		)
		var expected_age: int = (
			previous_age + 1
		)
		var current_age: int = int(
			npc.age
		)

		if current_age < expected_age:
			npc.age = expected_age
			report [
				"corrected_underadvanced_npcs"
			] = int(
				report.get(
					"corrected_underadvanced_npcs",
					0
				)
			) + 1
		elif current_age > expected_age:
			npc.age = expected_age
			report [
				"corrected_overadvanced_npcs"
			] = int(
				report.get(
					"corrected_overadvanced_npcs",
					0
				)
			) + 1

		if int(
			npc.age
		) == expected_age:
			report [
				"aged_npcs"
			] = int(
				report.get(
					"aged_npcs",
					0
				)
			) + 1

			if not aged_ids.has(
				int(
					npc.id
				)
			):
				aged_ids.append(
					int(
						npc.id
					)
				)

		if npc.has_method(
			"set_meta"
		):
			npc.set_meta(
				"last_temporal_biology_year",
				target_year
			)
			npc.set_meta(
				"last_age_up_time_truth_year",
				target_year
			)
			npc.set_meta(
				"last_age_up_time_truth_reason",
				reason
			)

		if (
			gs.world_engine != null
			and gs.world_engine.has_method(
				"_should_emit_npc_age_event"
			)
			and gs.world_engine.has_method(
				"_emit_npc_age_event"
			)
		):
			var should_emit: bool = bool(
				gs.world_engine.call(
					"_should_emit_npc_age_event",
					npc,
					previous_age,
					int(
						npc.age
					)
				)
			)

			if should_emit:
				gs.world_engine.call(
					"_emit_npc_age_event",
					npc,
					previous_age,
					int(
						npc.age
					),
					target_year
				)
				report [
					"event_count"
				] = int(
					report.get(
						"event_count",
						0
					)
				) + 1

		if (
			gs.health_engine != null
			and gs.health_engine.has_method(
				"enforce_mortal_age_cap"
			)
		):
			gs.health_engine.enforce_mortal_age_cap(
				npc
			)
			report [
				"death_checks"
			] = int(
				report.get(
					"death_checks",
					0
				)
			) + 1

	var complete: bool = (
		cursor >= total
	)

	report [
		"aged_ids"
	] = aged_ids
	report [
		"complete"
	] = complete
	report [
		"streaming_pending"
	] = not complete
	report [
		"cursor"
	] = cursor
	report [
		"total"
	] = total
	report [
		"last_batch_processed"
	] = processed
	report [
		"last_batch_ms"
	] = maxi(
		0,
		int(
			Time.get_ticks_msec()
		) - started_ms
	)
	report [
		"all_population_iteration_on_one_frame"
	] = false

	gs.scenario_state [
		"age_up_zero_frame_npc_truth_cursor"
	] = cursor
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_complete"
	] = complete
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_pending"
	] = not complete
	gs.scenario_state [
		"age_up_zero_frame_npc_truth_stream_report"
	] = report

	if complete:
		commit_registry [
			commit_key
		] = true
		gs.scenario_state [
			"age_up_npc_time_truth_registry"
		] = commit_registry
		gs.scenario_state [
			"last_age_up_npc_time_truth_report"
		] = report.duplicate(false)
		gs.scenario_state [
			"age_up_npc_time_truth_committed_with_visible_time"
		] = false
		gs.scenario_state [
			"age_up_npc_time_truth_committed_in_background"
		] = true
		gs.scenario_state [
			"age_up_npc_time_truth_committed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return report.duplicate(false)
func continue_nonvisible_age_up_transaction(max_resume_passes: int = 2, max_commit_stages: int = 4) -> Dictionary:
	if gs == null:
		return {}

	var latest_result: Dictionary = {}
	var resume_passes: int = 0

	while resume_passes < max_resume_passes:
		var loading_bucket_raw: Variant = gs.scenario_state.get("loading_runtime", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
		var loading_bucket: Dictionary = loading_bucket_raw if typeof(loading_bucket_raw) == TYPE_DICTIONARY else {}
		var slice_guard_raw: Variant = gs.scenario_state.get("runtime_slice_guard", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
		var slice_guard: Dictionary = slice_guard_raw if typeof(slice_guard_raw) == TYPE_DICTIONARY else {}
		var current_phase: String = str(loading_bucket.get("current_phase", slice_guard.get("current_phase", "")))

		var local_commit_budget: int = 1
		if current_phase == "commit_settling":
			local_commit_budget = 2
		elif current_phase in ["player_phase_contract", "choice_and_opportunity_surfacing", "narrative_and_presentation"]:
			local_commit_budget = 2

		local_commit_budget = min(local_commit_budget, max(1, max_commit_stages))

		if bool(slice_guard.get("guard_tripped", false)):
			local_commit_budget = 1

		if runtime_engine != null and runtime_engine.has_pending_commit():
			runtime_engine.drain_pending_commit(local_commit_budget)
		elif gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			gs.year_budget_engine.drain_pending_year_pipeline(local_commit_budget)

		var tail_still_pending: bool = false
		if runtime_engine != null and runtime_engine.has_pending_commit():
			tail_still_pending = true
		elif gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			tail_still_pending = true

		var year_in_progress: bool = false
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			year_in_progress = bool(gs.scenario_state.get("year_in_progress", false))

		if gs.scenario_engine != null and year_in_progress:
			latest_result = _resolve_current_year_after_tick()
			if str(latest_result.get("type", "")) != "year_pipeline_pending":
				return latest_result
		elif not tail_still_pending:
			return latest_result

		if tail_still_pending:
			return {
				"type": "year_pipeline_pending",
				"text": "Time is still settling from last year...",
				"opps": []
			}

		resume_passes += 1

	return latest_result
func force_complete_nonvisible_age_up_transaction(reason: String = "remote_shell_force_complete") -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var time_contract_raw: Variant = gs.scenario_state.get("age_up_time_contract", {})
	var time_contract: Dictionary = time_contract_raw if typeof(time_contract_raw) == TYPE_DICTIONARY else {}

	var started_from_year: int = int(time_contract.get("source_year", gs.scenario_state.get("age_up_started_from_year", gs.year)))
	var started_from_age: int = int(time_contract.get("source_age", gs.scenario_state.get("age_up_started_from_age", gs.player.age if gs.player != null else 0)))
	var target_year: int = int(time_contract.get("target_year", gs.scenario_state.get("age_up_requested_year", started_from_year + 1)))
	var target_age: int = int(time_contract.get("target_age", gs.scenario_state.get("age_up_truth_expected_target_age", started_from_age + 1)))

	if target_year <= started_from_year:
		target_year = started_from_year + 1

	if target_age <= started_from_age:
		target_age = started_from_age + 1

	if runtime_engine != null and runtime_engine.has_pending_commit():
		runtime_engine.drain_pending_commit(64)

	if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
		gs.year_budget_engine.drain_pending_year_pipeline(64)



	if gs.player != null:
		if not gs.year_locked:
			gs.year = target_year

		gs.player.age = target_age

		if gs.player.has_method("set_meta"):
			gs.player.set_meta("last_temporal_biology_year", target_year)
			gs.player.set_meta("last_age_up_time_truth_year", target_year)
			gs.player.set_meta("last_age_up_time_truth_reason", reason)

	if runtime_engine != null and "active_year_context" in runtime_engine:
		runtime_engine.active_year_context ["year"] = target_year
		runtime_engine.active_year_context ["committed_year"] = target_year
		runtime_engine.active_year_context ["contract_source_year"] = started_from_year
		runtime_engine.active_year_context ["contract_target_year"] = target_year
		runtime_engine.active_year_context ["contract_source_age"] = started_from_age
		runtime_engine.active_year_context ["contract_target_age"] = target_age
		runtime_engine.active_year_context ["aged_player_id"] = int(gs.player.id) if gs.player != null else -1
		runtime_engine.active_year_context ["aged_player_year"] = target_year
		runtime_engine.active_year_context ["completed_year"] = target_year
		runtime_engine.active_year_context ["completed_player_age"] = target_age
		runtime_engine.active_year_context ["time_contract_committed"] = true

	var npc_time_report: Dictionary = _commit_npc_time_truth_for_age_up(
		started_from_year,
		target_year,
		reason
	)

	_simulate_world()

	if gs.year_budget_engine != null and gs.year_budget_engine.has_method("flush_year_pipeline"):
		gs.year_budget_engine.flush_year_pipeline()

	if gs.scenario_engine != null:
		gs.scenario_engine.finish_year_resolution()

	gs.scenario_state ["year_in_progress"] = false
	gs.scenario_state ["bundle_built"] = false
	gs.scenario_state ["post_runtime_result"] = {}
	gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
	gs.scenario_state ["runtime_slice_guard"] = {}
	gs.scenario_state ["loading_runtime"] = {}
	gs.scenario_state ["age_up_deferred_flush_pending"] = true
	gs.scenario_state ["age_up_deferred_flush_next_ms"] = 0
	gs.scenario_state ["last_force_completed_age_up_npc_time_report"] = npc_time_report.duplicate(true)

	return {
		"type": "year_passed",
		"text": "Another year passed. I am now %d." % target_age,
		"opps": [],
		"runtime_recovery_reason": reason,
		"year": target_year,
		"age": target_age,
		"time_authority": "age_up_time_contract",
		"npc_time_report": npc_time_report.duplicate(true)
	}
func _ensure_age_up_time_truth_committed(
	result: Dictionary,
	reason: String = "age_up_truth_commit"
) -> Dictionary:
	if gs == null:
		return result

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var out: Dictionary = result.duplicate(false)

	if gs.player == null:
		return out

	var time_contract_raw: Variant = gs.scenario_state.get(
		"age_up_time_contract",
		{}
	)
	var time_contract: Dictionary = (
		time_contract_raw as Dictionary
		if typeof(time_contract_raw) == TYPE_DICTIONARY
		else {}
	)

	var started_from_year: int = int(
		time_contract.get(
			"source_year",
			gs.scenario_state.get(
				"age_up_started_from_year",
				gs.year
			)
		)
	)
	var started_from_age: int = int(
		time_contract.get(
			"source_age",
			gs.scenario_state.get(
				"age_up_started_from_age",
				gs.player.age
			)
		)
	)
	var target_year: int = int(
		time_contract.get(
			"target_year",
			gs.scenario_state.get(
				"age_up_requested_year",
				started_from_year + 1
			)
		)
	)
	var target_age: int = int(
		time_contract.get(
			"target_age",
			gs.scenario_state.get(
				"age_up_truth_expected_target_age",
				started_from_age + 1
			)
		)
	)

	if target_year <= started_from_year:
		target_year = started_from_year + 1

	if target_age <= started_from_age:
		target_age = started_from_age + 1

	var year_locked_active: bool = bool(
		gs.year_locked
	)

	var runtime_slice_active: bool = false
	if (
		runtime_engine != null
		and runtime_engine.has_method(
			"has_active_runtime_slice"
		)
	):
		runtime_slice_active = bool(
			runtime_engine.has_active_runtime_slice()
		)


	if not year_locked_active:
		gs.year = target_year

	gs.player.age = target_age

	if gs.player.has_method(
		"set_meta"
	):
		gs.player.set_meta(
			"last_temporal_biology_year",
			target_year
		)
		gs.player.set_meta(
			"last_age_up_time_truth_year",
			target_year
		)
		gs.player.set_meta(
			"last_age_up_time_truth_reason",
			reason
		)

	if (
		runtime_engine != null
		and "active_year_context" in runtime_engine
	):
		runtime_engine.active_year_context [
			"year"
		] = target_year
		runtime_engine.active_year_context [
			"committed_year"
		] = target_year
		runtime_engine.active_year_context [
			"contract_source_year"
		] = started_from_year
		runtime_engine.active_year_context [
			"contract_target_year"
		] = target_year
		runtime_engine.active_year_context [
			"contract_source_age"
		] = started_from_age
		runtime_engine.active_year_context [
			"contract_target_age"
		] = target_age
		runtime_engine.active_year_context [
			"aged_player_id"
		] = int(
			gs.player.id
		)
		runtime_engine.active_year_context [
			"aged_player_year"
		] = target_year
		runtime_engine.active_year_context [
			"completed_player_age"
		] = target_age
		runtime_engine.active_year_context [
			"time_contract_committed"
		] = true

	var npc_time_report: Dictionary = (
		_commit_npc_time_truth_for_age_up(
			started_from_year,
			target_year,
			reason
		)
	)

	out = _canonicalize_age_up_result(
		out,
		started_from_year,
		target_year,
		started_from_age,
		target_age,
		reason
	)

	gs.scenario_state [
		"last_age_up_truth_commit"
	] = {
		"reason": reason,
		"started_from_year": started_from_year,
		"started_from_age": started_from_age,
		"target_year": target_year,
		"target_age": target_age,
		"landed_year": int(
			gs.year
		),
		"landed_age": int(
			gs.player.age
		),
		"year_locked": year_locked_active,
		"runtime_slice_active_at_commit": runtime_slice_active,
		"npc_time_report": npc_time_report.duplicate(false),
		"time_contract": time_contract.duplicate(false),
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	gs.scenario_state [
		"age_up_contract_last_visible_commit"
	] = {
		"source_year": started_from_year,
		"target_year": target_year,
		"source_age": started_from_age,
		"target_age": target_age,
		"npc_time_truth_complete": bool(
			npc_time_report.get(
				"complete",
				false
			)
		),
		"committed_at_ms": int(
			Time.get_ticks_msec()
		),
		"reason": reason
	}

	return out
func _build_year_resolution_popup_chain(final_followup: Dictionary = {}) -> Dictionary:
	var chained_result: Dictionary = {}

	if typeof(final_followup) == TYPE_DICTIONARY and not final_followup.is_empty():
		chained_result = final_followup.duplicate(true)

	if gs == null:
		return chained_result

	if not gs.has_method("pop_next_year_resolution_popup"):
		return chained_result

	var queued_popups: Array = []
	var safety_count: int = 0
	while safety_count < 64:
		safety_count += 1

		var next_popup: Dictionary = gs.pop_next_year_resolution_popup()
		if next_popup.is_empty():
			break

		queued_popups.append(next_popup)

	for i in range(queued_popups.size() - 1, -1, -1):
		var popup_result: Dictionary = queued_popups [i].duplicate(true)
		chained_result = _append_result_to_followup_tail(popup_result, chained_result)

	return chained_result


func _append_result_to_followup_tail(result: Dictionary, tail: Dictionary) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY or result.is_empty():
		if typeof(tail) == TYPE_DICTIONARY:
			return tail.duplicate(true)
		return {}

	var out: Dictionary = result.duplicate(true)

	if typeof(tail) != TYPE_DICTIONARY or tail.is_empty():
		return out

	var existing_followup_raw: Variant = out.get("followup_result", {})
	if typeof(existing_followup_raw) != TYPE_DICTIONARY:
		out ["followup_result"] = tail.duplicate(true)
		return out

	var existing_followup: Dictionary = existing_followup_raw as Dictionary
	if existing_followup.is_empty():
		out ["followup_result"] = tail.duplicate(true)
		return out

	out ["followup_result"] = _append_result_to_followup_tail(existing_followup.duplicate(true), tail)
	return out
func _resolve_current_year_after_tick() -> Dictionary:
	if gs == null or gs.scenario_engine == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var zero_frame_raw: Variant = gs.scenario_state.get("zero_frame_age_up_last_result", {})
	var zero_frame_result: Dictionary = zero_frame_raw if typeof(zero_frame_raw) == TYPE_DICTIONARY else {}
	if bool(zero_frame_result.get("zero_frame_age_up", false)):
		gs.scenario_state ["year_in_progress"] = false
		gs.scenario_state ["bundle_built"] = false
		gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
		gs.scenario_state ["runtime_slice_guard"] = {}
		gs.scenario_state ["last_resolved_age_up_result"] = zero_frame_result.duplicate(true)
		return zero_frame_result.duplicate(true)

	var stored_result_raw: Variant = gs.scenario_state.get("post_runtime_result", {})
	var stored_result: Dictionary = stored_result_raw if typeof(stored_result_raw) == TYPE_DICTIONARY else {}

	var runtime_prepared_raw: Variant = gs.scenario_state.get("runtime_prepared_scenario_setup", {})
	var runtime_prepared: Dictionary = {}
	if typeof(runtime_prepared_raw) == TYPE_DICTIONARY:
		runtime_prepared = runtime_prepared_raw

	if not runtime_prepared.is_empty():
		gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
		gs.scenario_state ["bundle_built"] = true
		gs.scenario_state ["runtime_slice_guard"] = {}

		var prepared_chain: Dictionary = _build_year_resolution_popup_chain(runtime_prepared)
		if prepared_chain.is_empty():
			prepared_chain = runtime_prepared.duplicate(true)
		prepared_chain = _ensure_age_up_time_truth_committed(prepared_chain, "resolve_current_year_after_tick_prepared_chain")
		return prepared_chain.duplicate(true)

	var bucket: Dictionary = _visible_age_up_loading_bucket()
	var now_ms: int = int(Time.get_ticks_msec())
	var visible_started_at_ms: int = int(bucket.get("visible_started_at_ms", bucket.get("started_at_ms", now_ms)))
	var visible_elapsed_ms: int = max(0, now_ms - visible_started_at_ms)

	var force_complete_ms: int = 8200
	if gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("get_runtime_phase_scheduler_context"):
		var scheduler: Dictionary = gs.game_state_contract_engine.get_runtime_phase_scheduler_context({
			"runtime_kind": "age_up",
			"force_complete_ms": force_complete_ms
		})
		force_complete_ms = int(scheduler.get("force_complete_ms", force_complete_ms))

	var still_marked_busy: bool = bool(gs.scenario_state.get("year_in_progress", false)) or bool(gs.scenario_state.get("bundle_built", false))

	if still_marked_busy and stored_result.is_empty() and visible_elapsed_ms < force_complete_ms:
		return {
			"type": "year_pipeline_pending",
			"text": "Time is still resolving the current year...",
			"opps": []
		}

	if still_marked_busy and stored_result.is_empty() and visible_elapsed_ms >= force_complete_ms:
		stored_result = {
			"type": "year_passed",
			"text": "Another year passed.",
			"opps": [],
			"runtime_recovery_reason": "visible_age_up_force_complete_%dms" % visible_elapsed_ms
		}

		var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
		guard ["last_action"] = "visible_age_up_force_complete"
		guard ["last_action_ms"] = now_ms
		guard ["force_complete_elapsed_ms"] = visible_elapsed_ms
		guard ["defer_noncritical_systems"] = true
		guard ["fallback_cached_ui"] = true
		gs.scenario_state ["runtime_guard"] = guard
		gs.scenario_state ["post_runtime_result"] = stored_result.duplicate(true)

	if stored_result.is_empty():
		return {}

	var final_result: Dictionary = _ensure_age_up_time_truth_committed(stored_result, "resolve_current_year_after_tick")
	var display_result: Dictionary = _build_year_resolution_popup_chain(final_result)
	if display_result.is_empty():
		display_result = final_result.duplicate(true)

	display_result = _ensure_age_up_time_truth_committed(display_result, "resolve_current_year_after_tick_surface_chain")

	gs.scenario_state ["year_in_progress"] = false
	gs.scenario_state ["bundle_built"] = false
	gs.scenario_state ["post_runtime_result"] = {}
	gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
	gs.scenario_state ["runtime_slice_guard"] = {}
	gs.scenario_state ["age_up_deferred_flush_pending"] = true
	gs.scenario_state ["age_up_deferred_flush_next_ms"] = 0
	gs.scenario_state ["last_resolved_age_up_result"] = display_result.duplicate(true)

	gs.scenario_engine.finish_year_resolution()

	return display_result.duplicate(true)

func _visible_age_up_loading_bucket() -> Dictionary:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {}
	var bucket_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	return bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}


func _merge_visible_age_up_loading(update: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var bucket: Dictionary = _visible_age_up_loading_bucket()
	if bucket.is_empty():
		bucket = {}
	for key in update.keys():
		bucket [key] = update [key]
	gs.scenario_state ["loading_runtime"] = bucket


func _complete_visible_age_up_runtime(result: Dictionary) -> Dictionary:
	var time_truth_result: Dictionary = _ensure_age_up_time_truth_committed(result, "visible_age_up_runtime_complete")
	var final_result: Dictionary = _build_year_resolution_popup_chain(time_truth_result)
	if final_result.is_empty():
		final_result = time_truth_result.duplicate(true)

	final_result = _ensure_age_up_time_truth_committed(final_result, "visible_age_up_runtime_complete_surface_chain")

	_merge_visible_age_up_loading({
		"completion_state": "complete",
		"is_complete": true,
		"current_phase": "complete",
		"session_stage": "complete",
		"final_result": final_result.duplicate(true),
		"resolved_result": final_result.duplicate(true),
		"last_result_type": str(final_result.get("type", ""))
	})
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_completed_visible_age_up_result"] = final_result.duplicate(true)
		gs.scenario_state ["age_up_deferred_flush_pending"] = true
		gs.scenario_state ["age_up_deferred_flush_next_ms"] = 0

	_queue_post_age_up_predictive_ui_prewarm(final_result)

	return {
		"state": "complete",
		"is_complete": true,
		"result": final_result.duplicate(true)
	}
func _queue_post_age_up_predictive_ui_prewarm(final_result: Dictionary = {}) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var current_year: int = int(gs.year)
	var target_year: int = current_year + 1
	var prewarm_key: String = "post_age_up_predictive_ui_prewarm:%d" % target_year
	var last_key: String = str(gs.scenario_state.get("last_post_age_up_predictive_ui_prewarm_key", ""))
	if last_key == prewarm_key:
		return

	gs.scenario_state ["last_post_age_up_predictive_ui_prewarm_key"] = prewarm_key
	gs.scenario_state ["post_age_up_predictive_ui_prewarm_pending"] = true
	gs.scenario_state ["post_age_up_predictive_ui_prewarm_target_year"] = target_year
	gs.scenario_state ["post_age_up_predictive_ui_prewarm_queued_at_ms"] = int(Time.get_ticks_msec())

	call_deferred("_run_post_age_up_predictive_ui_prewarm", target_year, final_result.duplicate(true))


func _run_post_age_up_predictive_ui_prewarm(target_year: int, final_result: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState unavailable."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var report: Dictionary = {
		"success": false,
		"schema": "eralife.life_engine_post_age_up_predictive_ui_prewarm_report",
		"version": LIFE_CONTRACT_VERSION,
		"target_year": int(target_year),
		"source": "life_engine.post_age_up_predictive_ui_prewarm",
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if "reality_orchestrator" in gs and gs.reality_orchestrator != null:
		if gs.reality_orchestrator.has_method("prewarm_next_year_ui_surfaces"):
			report = gs.reality_orchestrator.prewarm_next_year_ui_surfaces({
				"source": "life_engine.post_age_up_predictive_ui_prewarm",
				"target_year": int(target_year),
				"year": int(target_year),
				"prewarm_budget": 2,
				"max_predictive_surfaces": 32,
				"prewarm_artifact_transitions": true,
				"age_up_result": final_result.duplicate(true),
				"runtime_owner": "age_up_runtime",
				"streaming": true
			})
		elif gs.reality_orchestrator.has_method("queue_streaming_ui_surface_prewarm"):
			report = gs.reality_orchestrator.queue_streaming_ui_surface_prewarm([
				{ "surface_id": "life_panel"},
				{ "surface_id": "inventory_contract_hub"},
				{ "surface_id": "scenario_contract_hub"}
			], {
				"source": "life_engine.post_age_up_predictive_ui_prewarm_fallback",
				"target_year": int(target_year),
				"prewarm_budget": 2,
				"streaming": true
			})

	gs.scenario_state ["post_age_up_predictive_ui_prewarm_pending"] = false
	gs.scenario_state ["last_post_age_up_predictive_ui_prewarm_report"] = report.duplicate(true)
	return report


func _soft_flush_predictive_ui_prewarm(max_count: int = 2) -> void:
	if gs == null:
		return
	if not ("reality_orchestrator" in gs) or gs.reality_orchestrator == null:
		return
	if gs.reality_orchestrator.has_method("_flush_streaming_ui_surface_prewarm_queue"):
		gs.reality_orchestrator.call("_flush_streaming_ui_surface_prewarm_queue", max(1, int(max_count)))
func _has_visible_age_up_runtime_tail_work() -> bool:
	var zero_frame_result: Dictionary = _zero_frame_visible_result_for_current_year()
	if not zero_frame_result.is_empty():
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			var zero_frame_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
			var zero_frame_guard: Dictionary = zero_frame_guard_raw if typeof(zero_frame_guard_raw) == TYPE_DICTIONARY else {}
			zero_frame_guard ["zero_frame_age_up"] = true
			zero_frame_guard ["visible_tail_work_forbidden"] = true
			zero_frame_guard ["tail_runtime_after_visible_commit"] = true
			zero_frame_guard ["ui_tail_work_yield_to_input"] = true
			zero_frame_guard ["control_release_priority"] = "ui_first"
			gs.scenario_state ["runtime_guard"] = zero_frame_guard
		return false

	var bucket: Dictionary = _visible_age_up_loading_bucket()
	var now_ms: int = int(Time.get_ticks_msec())
	var visible_started_at_ms: int = int(bucket.get("visible_started_at_ms", bucket.get("started_at_ms", now_ms)))
	var visible_elapsed_ms: int = max(0, now_ms - visible_started_at_ms)

	var guard: Dictionary = {}
	var overlay_context: Dictionary = {}
	var year_in_progress: bool = false
	var bundle_built: bool = false

	if typeof(bucket.get("overlay_context", {})) == TYPE_DICTIONARY:
		overlay_context = (bucket.get("overlay_context", {}) as Dictionary).duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		guard = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
		year_in_progress = bool(gs.scenario_state.get("year_in_progress", false))
		bundle_built = bool(gs.scenario_state.get("bundle_built", false))

	var ui_first_requested: bool = bool(overlay_context.get("ui_first_year_handoff", false)) \
or str(guard.get("control_release_priority", "")).strip_edges().to_lower() == "ui_first" \
or bool(guard.get("post_loading_auto_stability", false)) \
or bool(guard.get("defer_refresh_once", false))

	var year_truth_landed: bool = gs != null and not year_in_progress and not bundle_built

	var has_runtime_tail: bool = runtime_engine != null and runtime_engine.has_pending_commit()
	var has_year_pipeline_tail: bool = gs != null \
and gs.year_budget_engine != null \
and gs.year_budget_engine.has_pending_year_pipeline()

	if ui_first_requested and year_truth_landed and (has_runtime_tail or has_year_pipeline_tail):
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			var ui_first_guard: Dictionary = guard.duplicate(true)
			ui_first_guard ["post_loading_auto_stability"] = true
			ui_first_guard ["defer_refresh_once"] = true
			ui_first_guard ["fallback_cached_ui"] = true
			ui_first_guard ["control_release_priority"] = "ui_first"
			ui_first_guard ["post_age_up_tail_settle_active"] = true
			ui_first_guard ["post_age_up_tail_settle_until_ms"] = now_ms + 2200
			ui_first_guard ["post_age_up_tail_flush_budget"] = 1
			ui_first_guard ["post_age_up_tail_flush_interval_ms"] = 240
			ui_first_guard ["last_action"] = "release_visible_age_up_before_tail_work"
			ui_first_guard ["last_action_ms"] = now_ms
			ui_first_guard ["tail_work_deferred_after_visible_handoff"] = true
			gs.scenario_state ["runtime_guard"] = ui_first_guard
			gs.scenario_state ["age_up_deferred_flush_pending"] = true
			gs.scenario_state ["age_up_deferred_flush_next_ms"] = now_ms + 260
		return false

	var watchdog_ms: int = 5200
	var force_complete_ms: int = 8200

	if gs != null and gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("get_runtime_phase_scheduler_context"):
		var scheduler: Dictionary = gs.game_state_contract_engine.get_runtime_phase_scheduler_context({
			"runtime_kind": "age_up",
			"visible_watchdog_ms": watchdog_ms,
			"force_complete_ms": force_complete_ms
		})
		watchdog_ms = int(scheduler.get("visible_watchdog_ms", watchdog_ms))
		force_complete_ms = int(scheduler.get("force_complete_ms", force_complete_ms))

	if visible_elapsed_ms >= force_complete_ms:
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			var force_guard: Dictionary = guard.duplicate(true)
			force_guard ["tail_settle_force_release"] = true
			force_guard ["post_loading_auto_stability"] = true
			force_guard ["defer_refresh_once"] = true
			force_guard ["control_release_priority"] = "ui_first"
			force_guard ["post_age_up_tail_flush_budget"] = 1
			force_guard ["post_age_up_tail_flush_interval_ms"] = 300
			force_guard ["last_action"] = "tail_settle_watchdog_force_release"
			force_guard ["last_action_ms"] = now_ms
			force_guard ["tail_settle_elapsed_ms"] = visible_elapsed_ms
			gs.scenario_state ["runtime_guard"] = force_guard
			gs.scenario_state ["age_up_deferred_flush_pending"] = true
			gs.scenario_state ["age_up_deferred_flush_next_ms"] = now_ms + 300
		return false

	if has_runtime_tail:
		return true

	if has_year_pipeline_tail:
		if visible_elapsed_ms >= watchdog_ms:
			if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
				var degrade_guard: Dictionary = guard.duplicate(true)
				degrade_guard ["commit_budget_cap"] = 2
				degrade_guard ["phase_budget_cap"] = 1
				degrade_guard ["defer_noncritical_systems"] = true
				degrade_guard ["tail_settle_watchdog_active"] = true
				degrade_guard ["last_action"] = "tail_settle_watchdog_degrade"
				degrade_guard ["last_action_ms"] = now_ms
				degrade_guard ["tail_settle_elapsed_ms"] = visible_elapsed_ms
				gs.scenario_state ["runtime_guard"] = degrade_guard

			if gs.year_budget_engine.has_method("drain_pending_year_pipeline"):
				gs.year_budget_engine.drain_pending_year_pipeline(1)

		return gs.year_budget_engine.has_pending_year_pipeline()

	return false

func _begin_visible_age_up_runtime_tail_settle(resolved: Dictionary) -> Dictionary:
	_merge_visible_age_up_loading({
		"session_stage": "settling_current_year",
		"completion_state": "running",
		"is_complete": false,
		"current_phase": "commit_settling",
		"subline": "Reality is stabilizing before the year is revealed...",
		"resolved_result": resolved.duplicate(true),
	})
	return {
		"state": "running",
		"is_complete": false
	}

func _step_visible_age_up_overlay_settle() -> Dictionary:
	if gs == null:
		return {
			"state": "complete",
			"is_complete": true,
			"result": {}
		}

	var bucket: Dictionary = _visible_age_up_loading_bucket()
	if bucket.is_empty():
		return {
			"state": "running",
			"is_complete": false
		}

	var settle_frames_remaining: int = clamp(int(bucket.get("overlay_settle_frames_remaining", 0)), 0, 1)
	var settle_until_ms: int = int(bucket.get("overlay_settle_until_ms", 0))
	var visible_started_at_ms: int = int(bucket.get("visible_started_at_ms", 0))
	var now_ms: int = int(Time.get_ticks_msec())

	if visible_started_at_ms <= 0:
		visible_started_at_ms = now_ms


	if settle_until_ms > 0:
		settle_until_ms = min(settle_until_ms, visible_started_at_ms + 18)

	var should_keep_settling: bool = settle_frames_remaining > 0
	if settle_until_ms > 0 and now_ms < settle_until_ms:
		should_keep_settling = true

	if should_keep_settling:
		_merge_visible_age_up_loading({
			"session_stage": "boot",
			"completion_state": "running",
			"is_complete": false,
			"current_phase": "overlay_entry",
			"subline": "Preparing the year...",
			"entry_boot_stage": "overlay_settle",
			"overlay_settle_frames_remaining": max(0, settle_frames_remaining - 1),
			"overlay_settle_until_ms": settle_until_ms
		})
		return {
			"state": "running",
			"is_complete": false
		}

	_merge_visible_age_up_loading({
		"session_stage": "boot",
		"completion_state": "running",
		"is_complete": false,
		"current_phase": "overlay_entry",
		"subline": "Preparing the year...",
		"entry_boot_stage": "prepare_year",
		"overlay_settle_frames_remaining": 0,
		"overlay_settle_until_ms": 0
	})
	return {
		"state": "running",
		"is_complete": false
	}
func _start_visible_age_up_runtime_year() -> Dictionary:
	if gs.player == null:
		return _complete_visible_age_up_runtime({})

	if not gs.player.alive:
		return _complete_visible_age_up_runtime(_age_up_afterlife_year())

	var pending_birth_prompt: Dictionary = _build_player_line_birth_prompt()
	if not pending_birth_prompt.is_empty():
		return _complete_visible_age_up_runtime(pending_birth_prompt)

	if gs.scenario_engine != null and gs.scenario_engine.has_pending_choice():
		var pending_surface_timing: String = str(gs.scenario_state.get("pending_surface_timing", "")).strip_edges().to_lower()
		var pending_allows_pre_year: bool = bool(gs.scenario_state.get("pending_allows_pre_year_age_up_surface", false))
		if pending_surface_timing in ["pre_year", "before_year", "before_time_resolves"] or pending_allows_pre_year:
			return _complete_visible_age_up_runtime(gs.scenario_engine.get_pending_choice_result())

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var loading_bucket: Dictionary = _visible_age_up_loading_bucket()
	var overlay_context_raw: Variant = loading_bucket.get("overlay_context", {})
	var overlay_context: Dictionary = overlay_context_raw if typeof(overlay_context_raw) == TYPE_DICTIONARY else {}

	var time_contract: Dictionary = _ensure_age_up_time_contract_open(
		"visible_age_up_runtime_start",
		overlay_context
	)

	var source_year: int = int(time_contract.get("source_year", gs.year))
	var source_age: int = int(time_contract.get("source_age", gs.player.age))
	var target_year: int = int(time_contract.get("target_year", source_year + 1))
	var target_age: int = int(time_contract.get("target_age", source_age + 1))

	var boot_stage: String = str(loading_bucket.get("entry_boot_stage", "")).strip_edges()
	var can_stage_visible_boot: bool = runtime_engine != null and runtime_engine.has_method("begin_runtime_slice_session")

	if can_stage_visible_boot:
		if boot_stage == "prepare_year":
			_merge_visible_age_up_loading({
				"session_stage": "boot",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "overlay_entry",
				"subline": "Preparing the year...",
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "begin_transaction",
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if boot_stage == "begin_transaction":
			if gs.scenario_engine != null:
				gs.scenario_state ["year_in_progress"] = true
				gs.scenario_state ["bundle_built"] = false
				gs.scenario_state ["post_runtime_result"] = {}
				gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
				gs.scenario_state ["runtime_slice_guard"] = {}

			runtime_engine.begin_year_transaction({
				"mode": "living",
				"year": target_year,
				"player_id": int(gs.player.id),
				"runtime_owner": "age_up_runtime_engine",
				"time_contract": time_contract.duplicate(true),
				"contract_source_year": source_year,
				"contract_target_year": target_year,
				"contract_source_age": source_age,
				"contract_target_age": target_age,
				"age_up_contracts": gs.scenario_state.get("age_up_contracts", [])
			})

			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "year_and_era_mutation",
				"subline": "Staging the year turn...",
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "advance_year",
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if boot_stage == "advance_year":
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "year_and_era_mutation",
				"subline": "Handing the year turn to the runtime...",
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "begin_slice",
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if boot_stage == "advance_year_settle":
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "year_and_era_mutation",
				"subline": "Handing the year turn to the runtime...",
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "begin_slice",
				"advance_year_settle_frames_remaining": 0,
				"advance_year_settle_until_ms": 0,
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if boot_stage == "begin_slice":
			if runtime_engine.active_year_context.is_empty():
				runtime_engine.begin_year_transaction({
					"mode": "living",
					"year": target_year,
					"player_id": int(gs.player.id),
					"runtime_owner": "age_up_runtime_engine",
					"time_contract": time_contract.duplicate(true),
					"contract_source_year": source_year,
					"contract_target_year": target_year,
					"contract_source_age": source_age,
					"contract_target_age": target_age,
					"age_up_contracts": gs.scenario_state.get("age_up_contracts", [])
				})

			runtime_engine.begin_runtime_slice_session()

			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "year_and_era_mutation",
				"subline": "Turning the year...",
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "slice_started",
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if gs.scenario_engine != null and bool(gs.scenario_state.get("year_in_progress", false)):
			if runtime_engine != null and runtime_engine.has_method("begin_runtime_slice_session") and boot_stage != "slice_started":
				runtime_engine.begin_runtime_slice_session()

			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": str(loading_bucket.get("current_phase", "year_and_era_mutation")),
				"final_result": {},
				"resolved_result": {},
				"last_result_type": "",
				"entry_boot_stage": "slice_started" if can_stage_visible_boot else boot_stage,
				"source_year": source_year,
				"source_age": source_age,
				"target_year": target_year,
				"target_age": target_age,
				"time_contract": time_contract.duplicate(true)
			})
			return {
				"state": "running",
				"is_complete": false
			}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs.scenario_engine != null:
		gs.scenario_state ["year_in_progress"] = true
		gs.scenario_state ["bundle_built"] = false
		gs.scenario_state ["post_runtime_result"] = {}
		gs.scenario_state ["runtime_prepared_scenario_setup"] = {}
		gs.scenario_state ["runtime_slice_guard"] = {}

	_merge_visible_age_up_loading({
		"session_stage": "running",
		"completion_state": "running",
		"is_complete": false,
		"current_phase": "year_and_era_mutation",
		"final_result": {},
		"resolved_result": {},
		"last_result_type": "",
		"source_year": source_year,
		"source_age": source_age,
		"target_year": target_year,
		"target_age": target_age,
		"time_contract": time_contract.duplicate(true)
	})

	if runtime_engine != null:
		runtime_engine.begin_year_transaction({
			"mode": "living",
			"year": target_year,
			"player_id": int(gs.player.id),
			"runtime_owner": "age_up_runtime_engine",
			"time_contract": time_contract.duplicate(true),
			"contract_source_year": source_year,
			"contract_target_year": target_year,
			"contract_source_age": source_age,
			"contract_target_age": target_age,
			"age_up_contracts": gs.scenario_state.get("age_up_contracts", [])
		})

	if runtime_engine != null and runtime_engine.has_method("begin_runtime_slice_session"):
		runtime_engine.begin_runtime_slice_session()
	elif runtime_engine != null:
		runtime_engine.advance_year_and_handle_era_shift(gs.player)
	else:
		_advance_year_and_handle_era_shift(gs.player)

	return {
		"state": "running",
		"is_complete": false
	}


func begin_visible_age_up_runtime_session(loading_context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"state": "complete",
			"is_complete": true,
			"result": {}
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var zero_frame_result: Dictionary = _zero_frame_visible_result_for_current_year()
	if not zero_frame_result.is_empty():
		gs.scenario_state ["loading_runtime"] = {
			"active": true,
			"session_stage": "complete",
			"completion_state": "complete",
			"is_complete": true,
			"started_at_ms": int(Time.get_ticks_msec()),
			"visible_started_at_ms": int(loading_context.get("visible_started_at_ms", Time.get_ticks_msec())),
			"headline": str(loading_context.get("headline", "Time is moving...")),
			"subline": "",
			"dominant_domain": "zero_frame_age_up",
			"overlay_context": loading_context.duplicate(true),
			"phase_order": [],
			"phase_index": 0,
			"phase_durations_ms": {},
			"current_phase": "complete",
			"stall_score": 0.0,
			"runtime_weight": 0.0,
			"last_result_type": str(zero_frame_result.get("type", "")),
			"final_result": zero_frame_result.duplicate(true),
			"resolved_result": zero_frame_result.duplicate(true),
			"zero_frame_age_up": true,
			"overlay_is_cosmetic": true
		}

		return {
			"state": "complete",
			"is_complete": true,
			"result": zero_frame_result.duplicate(true),
			"zero_frame_age_up": true
		}

	var visible_started_at_ms: int = int(loading_context.get("visible_started_at_ms", Time.get_ticks_msec()))
	var first_visible_runtime_boot: bool = bool(loading_context.get("first_visible_runtime_boot", false))
	var overlay_settle_frames_default: int = 1 if first_visible_runtime_boot else 0
	var overlay_settle_ms_default: int = 24 if first_visible_runtime_boot else 0
	var overlay_settle_frames: int = 0
	if loading_context.has("overlay_settle_frames"):
		overlay_settle_frames = max(0,
		int(loading_context.get("overlay_settle_frames", 0)))
	else:
		overlay_settle_frames = max(0,
		overlay_settle_frames_default)
	var overlay_settle_ms: int = 0
	if loading_context.has("overlay_settle_ms"):
		overlay_settle_ms = max(0,
		int(loading_context.get("overlay_settle_ms", 0)))
	else:
		overlay_settle_ms = max(0, overlay_settle_ms_default)
	var advance_year_settle_frames_default: int = 1 if first_visible_runtime_boot else 0
	var advance_year_settle_ms_default: int = 18 if first_visible_runtime_boot else 0
	var advance_year_settle_frames: int = max(0,
		int(loading_context.get("advance_year_settle_frames",
		advance_year_settle_frames_default)))
	var advance_year_settle_ms: int = max(0,
		int(loading_context.get("advance_year_settle_ms",
		advance_year_settle_ms_default)))
	gs.scenario_state ["loading_runtime"] = {
		"active": true,
		"session_stage": "boot",
		"completion_state": "running",
		"is_complete": false,
		"started_at_ms": int(Time.get_ticks_msec()),
		"visible_started_at_ms": visible_started_at_ms,
		"headline": str(loading_context.get("headline", "Time is moving...")),
		"subline": str(loading_context.get("subline", "Simulating the next year...")),
		"dominant_domain":
		str(loading_context.get("dominant_domain", "general")),
		"overlay_context": loading_context.duplicate(true),
		"phase_order": [],
		"phase_index": 0,
		"phase_durations_ms": {},
		"current_phase": "overlay_entry",
		"stall_score": 0.0,
		"runtime_weight": 0.0,
		"last_result_type": "",
		"final_result": {},
		"resolved_result": {},
		"entry_followup_pending": true,
		"entry_followup_started_at_ms": 0,
		"entry_followup_source": "visible_age_up_begin",
		"entry_boot_stage": "overlay_settle",
		"overlay_settle_frames_remaining": overlay_settle_frames,
		"overlay_settle_until_ms": visible_started_at_ms +
		overlay_settle_ms,
		"advance_year_settle_frames": advance_year_settle_frames,
		"advance_year_settle_ms": advance_year_settle_ms,
		"advance_year_settle_frames_remaining": 0,
		"advance_year_settle_until_ms": 0
	}
	_merge_visible_age_up_loading({
		"session_stage": "boot",
		"completion_state": "running",
		"is_complete": false,
		"current_phase": "overlay_entry",
		"subline": str(loading_context.get("subline", "Simulating the next year...")),
		"entry_boot_stage": "overlay_settle",
		"overlay_settle_frames_remaining": overlay_settle_frames,
		"overlay_settle_until_ms": visible_started_at_ms +
		overlay_settle_ms,
		"advance_year_settle_frames": advance_year_settle_frames,
		"advance_year_settle_ms": advance_year_settle_ms,
		"advance_year_settle_frames_remaining": 0,
		"advance_year_settle_until_ms": 0
	})
	return {
		"state": "running",
		"is_complete": false
	}

func _visible_age_up_runtime_ui_safe_commit_budget(proposed_budget: int, caller_budget: int, current_phase: String, session_stage: String, visible_elapsed_ms: int) -> int:
	var clean_phase: String = str(current_phase).strip_edges().to_lower()
	var clean_stage: String = str(session_stage).strip_edges().to_lower()

	var caller_cap: int = max(1, int(caller_budget))
	var hard_cap: int = min(caller_cap, 3)

	if clean_phase == "commit_settling" or clean_stage in ["settling_previous_year", "settling_current_year"]:
		hard_cap = min(max(hard_cap, 2), 3)

	if visible_elapsed_ms >= 2200:
		hard_cap = min(hard_cap + 1, 4)

	return clamp(int(proposed_budget), 1, hard_cap)
func step_visible_age_up_runtime_session(max_phase_steps: int = 3, max_commit_stages: int = 8) -> Dictionary:
	if gs == null:
		return {
			"state": "complete",
			"is_complete": true,
			"result": {}
		}

	var zero_frame_result: Dictionary = _zero_frame_visible_result_for_current_year()
	if not zero_frame_result.is_empty():
		_merge_visible_age_up_loading({
			"session_stage": "complete",
			"completion_state": "complete",
			"is_complete": true,
			"current_phase": "complete",
			"subline": "",
			"final_result": zero_frame_result.duplicate(true),
			"resolved_result": zero_frame_result.duplicate(true),
			"zero_frame_age_up": true,
			"overlay_is_cosmetic": true
		})

		return {
			"state": "complete",
			"is_complete": true,
			"result": zero_frame_result.duplicate(true),
			"zero_frame_age_up": true
		}

	var bucket: Dictionary = _visible_age_up_loading_bucket()
	if bucket.is_empty():
		return {
			"state": "complete",
			"is_complete": true,
			"result": {}
		}

	if bool(bucket.get("is_complete", false)):
		var final_raw: Variant = bucket.get("final_result", {})
		var final_result: Dictionary = final_raw if typeof(final_raw) == TYPE_DICTIONARY else {}
		return {
			"state": "complete",
			"is_complete": true,
			"result": final_result
		}

	var visible_started_at_ms: int = int(bucket.get("visible_started_at_ms", 0))
	var visible_elapsed_ms: int = 0
	if visible_started_at_ms > 0:
		visible_elapsed_ms = max(0, int(Time.get_ticks_msec()) - visible_started_at_ms)

	if bool(bucket.get("entry_followup_pending", false)):
		var entry_bucket: Dictionary = bucket.duplicate(true)
		entry_bucket ["entry_followup_pending"] = false
		entry_bucket ["entry_followup_started_at_ms"] = int(Time.get_ticks_msec())
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}
		gs.scenario_state ["loading_runtime"] = entry_bucket

		var deferred_rewind_snapshot: bool = bool(gs.scenario_state.get("rewind_snapshot_deferred", false))
		var rewind_pipeline_active: bool = false
		if gs.has_method("has_pending_rewind_snapshot_pipeline"):
			rewind_pipeline_active = gs.has_pending_rewind_snapshot_pipeline()
		if deferred_rewind_snapshot and not rewind_pipeline_active:
			gs.scenario_state ["rewind_snapshot_deferred"] = false

		var startup_settle_budget: int = min(max(1, int(max_commit_stages)), 2)
		if visible_elapsed_ms >= 700:
			startup_settle_budget = min(max(startup_settle_budget, 3), 3)

		if rewind_pipeline_active and gs.has_method("step_rewind_snapshot_pipeline"):
			gs.step_rewind_snapshot_pipeline(min(startup_settle_budget, 6))
			rewind_pipeline_active = gs.has_pending_rewind_snapshot_pipeline() if gs.has_method("has_pending_rewind_snapshot_pipeline") else false

		if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			gs.year_budget_engine.drain_pending_year_pipeline(startup_settle_budget)

		if rewind_pipeline_active:
			_merge_visible_age_up_loading({
				"session_stage": "settling_previous_year",
				"current_phase": "commit_settling",
				"subline": "Preserving last year's rewind point..."
			})
			return {
				"state": "running",
				"is_complete": false
			}

		if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			_merge_visible_age_up_loading({
				"session_stage": "settling_previous_year",
				"current_phase": "commit_settling",
				"subline": "Time is still settling from last year..."
			})
			return {
				"state": "running",
				"is_complete": false
			}

		return _step_visible_age_up_overlay_settle()

	var session_stage: String = str(bucket.get("session_stage", ""))
	var boot_stage: String = str(bucket.get("entry_boot_stage", "")).strip_edges()
	var current_phase_hint: String = str(bucket.get("current_phase", "preflight")).strip_edges()

	var visible_commit_budget: int = clamp(int(max_commit_stages), 1, 3)

	var overlay_context_raw: Variant = bucket.get("overlay_context", {})
	var overlay_context: Dictionary = overlay_context_raw if typeof(overlay_context_raw) == TYPE_DICTIONARY else {}
	var cooperative_runtime: bool = bool(overlay_context.get("cooperative_age_up_runtime", false))
	var cooperative_commit_cap: int = int(overlay_context.get("runtime_frame_commit_budget_cap", overlay_context.get("startup_soft_commit_budget_cap", 3)))

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
		cooperative_runtime = cooperative_runtime or bool(guard.get("cooperative_age_up_runtime", false))
		cooperative_commit_cap = min(cooperative_commit_cap, int(guard.get("visible_runtime_commit_budget_cap", guard.get("commit_budget_cap", cooperative_commit_cap))))

	if cooperative_runtime:
		visible_commit_budget = clamp(min(visible_commit_budget, cooperative_commit_cap), 1, 3)

	visible_commit_budget = _visible_age_up_runtime_ui_safe_commit_budget(
		visible_commit_budget,
		max_commit_stages,
		current_phase_hint,
		session_stage,
		visible_elapsed_ms
	)

	if boot_stage == "overlay_settle":
		return _step_visible_age_up_overlay_settle()
	if boot_stage in ["prepare_year", "begin_transaction", "advance_year", "begin_slice"]:
		return _start_visible_age_up_runtime_year()

	if session_stage == "settling_previous_year" or session_stage == "settling_current_year":
		var deferred_rewind_snapshot: bool = false
		if session_stage == "settling_previous_year" and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			deferred_rewind_snapshot = bool(gs.scenario_state.get("rewind_snapshot_deferred", false))

		var rewind_pipeline_active: bool = false
		if gs.has_method("has_pending_rewind_snapshot_pipeline"):
			rewind_pipeline_active = gs.has_pending_rewind_snapshot_pipeline()

		var drained_any: bool = false
		visible_commit_budget = _visible_age_up_runtime_ui_safe_commit_budget(
			visible_commit_budget,
			max_commit_stages,
			current_phase_hint,
			session_stage,
			visible_elapsed_ms
		)
		if session_stage == "settling_previous_year" and rewind_pipeline_active and gs.has_method("step_rewind_snapshot_pipeline"):
			gs.step_rewind_snapshot_pipeline(min(visible_commit_budget, 6))
			drained_any = true

		if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			gs.year_budget_engine.drain_pending_year_pipeline(visible_commit_budget)
			drained_any = true
		elif runtime_engine != null and runtime_engine.has_pending_commit():
			runtime_engine.drain_pending_commit(visible_commit_budget)
			drained_any = true

		if gs.has_method("has_pending_rewind_snapshot_pipeline"):
			rewind_pipeline_active = gs.has_pending_rewind_snapshot_pipeline()

		if session_stage == "settling_previous_year" and typeof(gs.scenario_state) == TYPE_DICTIONARY and not rewind_pipeline_active:
			gs.scenario_state ["rewind_snapshot_deferred"] = false

		var shared_commit_still_pending: bool = false
		if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
			shared_commit_still_pending = true
		elif runtime_engine != null and runtime_engine.has_pending_commit():
			shared_commit_still_pending = true

		var still_settling: bool = shared_commit_still_pending or rewind_pipeline_active
		var settle_started_ms: int = int(bucket.get("commit_settle_started_ms", 0))
		if settle_started_ms <= 0:
			settle_started_ms = int(Time.get_ticks_msec())

		var settle_elapsed_ms: int = max(0, int(Time.get_ticks_msec()) - settle_started_ms)
		var settle_signature: String = "%s|%s|%s" % [
			str(shared_commit_still_pending),
			str(rewind_pipeline_active),
			str(current_phase_hint)
		]
		var previous_settle_signature: String = str(bucket.get("commit_settle_signature", ""))
		var same_settle_count: int = int(bucket.get("commit_settle_same_count", 0))
		if settle_signature == previous_settle_signature:
			same_settle_count += 1
		else:
			same_settle_count = 0

		var loading_update: Dictionary = {
			"current_phase": "commit_settling",
			"commit_settle_started_ms": settle_started_ms,
			"commit_settle_elapsed_ms": settle_elapsed_ms,
			"commit_settle_signature": settle_signature,
			"commit_settle_same_count": same_settle_count
		}

		if session_stage == "settling_previous_year" and (rewind_pipeline_active or deferred_rewind_snapshot):
			loading_update ["subline"] = "Preserving last year's rewind point..."
		elif shared_commit_still_pending:
			loading_update ["subline"] = "Time is still settling from last year..."
		elif drained_any:
			loading_update ["subline"] = "Locking the finished runtime into the new year..."

		var force_release_settle: bool = false
		if still_settling and session_stage == "settling_current_year":
			if settle_elapsed_ms >= 1500:
				force_release_settle = true
			if same_settle_count >= 18:
				force_release_settle = true
			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				if bool(gs.scenario_state.get("year_in_progress", false)) or bool(gs.scenario_state.get("bundle_built", false)):
					force_release_settle = false

		if force_release_settle:
			loading_update ["completion_state"] = "complete"
			loading_update ["is_complete"] = true
			loading_update ["session_stage"] = "complete"
			loading_update ["current_phase"] = "complete"
			loading_update ["subline"] = ""

			var forced_result_raw: Variant = {}
			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				forced_result_raw = gs.scenario_state.get("post_runtime_result", {})
			var forced_result: Dictionary = forced_result_raw if typeof(forced_result_raw) == TYPE_DICTIONARY else {}

			if forced_result.is_empty():
				forced_result = {
					"type": "year_passed",
					"text": "Another year passed.",
					"opps": []
				}

			loading_update ["final_result"] = forced_result.duplicate(true)
			loading_update ["resolved_result"] = forced_result.duplicate(true)
			_merge_visible_age_up_loading(loading_update)

			if typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["runtime_guard"] = {}
				gs.scenario_state ["age_up_deferred_flush_pending"] = true
				gs.scenario_state ["age_up_deferred_flush_next_ms"] = 0

			return {
				"state": "complete",
				"is_complete": true,
				"result": forced_result
			}

		_merge_visible_age_up_loading(loading_update)

		if still_settling:
			return {
				"state": "running",
				"is_complete": false
			}

		if session_stage == "settling_previous_year":
			return _step_visible_age_up_overlay_settle()

		var resolved_raw: Variant = bucket.get("resolved_result", {})
		var resolved_result: Dictionary = resolved_raw if typeof(resolved_raw) == TYPE_DICTIONARY else {}
		return _complete_visible_age_up_runtime(resolved_result)

	var runtime_slice_in_flight: bool = false
	if runtime_engine != null and runtime_engine.has_method("has_active_runtime_slice"):
		runtime_slice_in_flight = runtime_engine.has_active_runtime_slice()

	if gs.scenario_engine == null:
		if runtime_slice_in_flight:
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": str(bucket.get("current_phase", "preflight"))
			})
			return {
				"state": "running",
				"is_complete": false
			}
		return _complete_visible_age_up_runtime({})

	if not bool(gs.scenario_state.get("year_in_progress", false)):
		if runtime_slice_in_flight:
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": str(bucket.get("current_phase", "preflight"))
			})
			return {
				"state": "running",
				"is_complete": false
			}
		var idle_result: Dictionary = _resolve_current_year_after_tick()
		if str(idle_result.get("type", "")) == "year_pipeline_pending" or (idle_result.is_empty() and (bool(gs.scenario_state.get("year_in_progress", false)) or bool(gs.scenario_state.get("bundle_built", false)))):
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": "commit_settling"
			})
			return {
				"state": "running",
				"is_complete": false
			}
		if _has_visible_age_up_runtime_tail_work():
			return _begin_visible_age_up_runtime_tail_settle(idle_result)
		if not idle_result.is_empty():
			return _complete_visible_age_up_runtime(idle_result)
		return _complete_visible_age_up_runtime({})

	if runtime_engine != null and runtime_engine.has_method("run_year_runtime_slice"):
		var slice_report: Dictionary = runtime_engine.run_year_runtime_slice(max(1, max_phase_steps), visible_commit_budget)
		if bool(slice_report.get("is_complete", false)):
			var resolved: Dictionary = _resolve_current_year_after_tick()
			if str(resolved.get("type", "")) == "year_pipeline_pending" or (resolved.is_empty() and (bool(gs.scenario_state.get("year_in_progress", false)) or bool(gs.scenario_state.get("bundle_built", false)))):
				_merge_visible_age_up_loading({
					"session_stage": "running",
					"completion_state": "running",
					"is_complete": false,
					"current_phase": "commit_settling"
				})
				return {
					"state": "running",
					"is_complete": false
				}
			if _has_visible_age_up_runtime_tail_work():
				return _begin_visible_age_up_runtime_tail_settle(resolved)
			return _complete_visible_age_up_runtime(resolved)

		var fallback_result: Dictionary = _resolve_current_year_after_tick()
		if str(fallback_result.get("type", "")) == "year_pipeline_pending" or bool(gs.scenario_state.get("year_in_progress", false)) or (fallback_result.is_empty() and bool(gs.scenario_state.get("bundle_built", false))):
			_merge_visible_age_up_loading({
				"session_stage": "running",
				"completion_state": "running",
				"is_complete": false,
				"current_phase": str(slice_report.get("current_phase", bucket.get("current_phase", "preflight")))
			})
			return {
				"state": "running",
				"is_complete": false
			}
		if _has_visible_age_up_runtime_tail_work():
			return _begin_visible_age_up_runtime_tail_settle(fallback_result)
		return _complete_visible_age_up_runtime(fallback_result)

	var final_fallback_result: Dictionary = _resolve_current_year_after_tick()
	if str(final_fallback_result.get("type", "")) == "year_pipeline_pending" or bool(gs.scenario_state.get("year_in_progress", false)) or (final_fallback_result.is_empty() and bool(gs.scenario_state.get("bundle_built", false))):
		_merge_visible_age_up_loading({
			"session_stage": "running",
			"completion_state": "running",
			"is_complete": false,
			"current_phase": str(bucket.get("current_phase", "preflight"))
		})
		return {
			"state": "running",
			"is_complete": false
		}
	if _has_visible_age_up_runtime_tail_work():
		return _begin_visible_age_up_runtime_tail_settle(final_fallback_result)
	return _complete_visible_age_up_runtime(final_fallback_result)
func _build_player_line_birth_prompt() -> Dictionary:
	if gs == null or gs.player == null:
		return {}

	if (
		typeof(gs.pending_player_line_birth) != TYPE_DICTIONARY
		or gs.pending_player_line_birth.is_empty()
	):
		return {}




	var pending: Dictionary = gs.pending_player_line_birth
	var child_gender: String = str(
		pending.get(
			"child_gender",
			""
		)
	).strip_edges()
	var child_sex_label: String = "baby"

	if child_gender == "Male":
		child_sex_label = "boy"
	elif child_gender == "Female":
		child_sex_label = "girl"

	var prompt_text: String = str(
		pending.get(
			"prompt_text",
			""
		)
	).strip_edges()

	if prompt_text == "":
		prompt_text = (
			"A %s is ready to be named.\n\nChoose the baby's first name and last name."
			% child_sex_label
		)

	return {
		"type": "player_line_birth_naming_form",
		"text": prompt_text,
		"opps": [],
		"birth_contract": pending.duplicate(false),
		"population_scan_performed": false,
	}
func resolve_player_line_birth_identity_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
		or gs.player == null
	):
		return {
			"success": false,
			"reason": "missing_birth_identity_actor_or_game_state",
			"type": "player_line_birth_identity_intent_rejected"
		}

	if int(actor.id) != int(gs.player.id):
		return {
			"success": false,
			"reason": "birth_identity_actor_is_not_controlled_identity",
			"type": "player_line_birth_identity_intent_rejected",
			"actor_id": int(actor.id),
			"controlled_actor_id": int(gs.player.id)
		}

	var first_name: String = str(
		payload.get(
			"first_name",
			""
		)
	).strip_edges()
	var last_name: String = str(
		payload.get(
			"last_name",
			""
		)
	).strip_edges()

	if first_name == "":
		return {
			"success": false,
			"reason": "missing_child_first_name",
			"type": "player_line_birth_identity_intent_rejected",
			"text": "Give the baby a first name."
		}

	var result: Dictionary = submit_player_line_birth_identity(
		first_name,
		last_name
	)
	result [
		"birth_identity_intent_routed"
	] = true
	result [
		"truth_owner"
	] = "life_engine"
	result [
		"ui_called_engine_directly"
	] = false
	return result
func resolve_year_lock_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
		or gs.player == null
	):
		return {
			"success": false,
			"reason": "missing_year_lock_actor_or_game_state",
			"type": "year_lock_intent_rejected"
		}

	if int(actor.id) != int(gs.player.id):
		return {
			"success": false,
			"reason": "year_lock_actor_is_not_controlled_identity",
			"type": "year_lock_intent_rejected",
			"actor_id": int(actor.id),
			"controlled_actor_id": int(gs.player.id)
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var locked: bool = bool(
		payload.get(
			"locked",
			not bool(gs.year_locked)
		)
	)

	gs.year_locked = locked
	gs.scenario_state [
		"year_lock_explicit_player_intent"
	] = true
	gs.scenario_state [
		"year_lock_explicit_player_intent_actor_id"
	] = int(actor.id)
	gs.scenario_state [
		"year_lock_explicit_player_intent_at_ms"
	] = int(Time.get_ticks_msec())

	return {
		"success": true,
		"type": "year_lock_intent_resolved",
		"actor_id": int(actor.id),
		"locked": locked,
		"truth_owner": "life_engine",
		"ui_called_engine_directly": false
	}
func submit_player_line_birth_identity(first_name: String, last_name: String) -> Dictionary:
	if gs == null or gs.player == null:
		return {
			"success": false,
			"text": "The birth could not be completed."
		}

	var pending_raw = gs.pending_player_line_birth
	if typeof(pending_raw) != TYPE_DICTIONARY or pending_raw.is_empty():
		return {
			"success": false,
			"text": "That baby is no longer waiting to be named."
		}

	var mother: Person = gs.get_or_reactivate_npc_by_id(int(pending_raw.get("mother_id", -1)))
	var father: Person = gs.get_or_reactivate_npc_by_id(int(pending_raw.get("father_id", -1)))
	if mother == null or father == null:
		gs.pending_player_line_birth = {}
		return {
			"success": false,
			"text": "The birth could not be completed."
		}

	var baby: Person = gs.spawn_child(father, mother, false)
	if baby == null:
		gs.pending_player_line_birth = {}
		return {
			"success": false,
			"text": "The birth could not be completed."
		}

	var clean_first: String = first_name.strip_edges()
	var clean_last: String = last_name.strip_edges()
	if clean_first != "":
		baby.first_name = clean_first
	if clean_last != "":
		baby.last_name = clean_last
	elif str(pending_raw.get("default_last_name", "")).strip_edges() != "":
		baby.last_name = str(pending_raw.get("default_last_name", "")).strip_edges()

	var forced_gender: String = str(pending_raw.get("child_gender", "")).strip_edges()
	if forced_gender in ["Male", "Female"]:
		baby.gender = forced_gender

	baby.age = 0

	var sex_label: String = "baby"
	if str(baby.gender) == "Male":
		sex_label = "boy"
	elif str(baby.gender) == "Female":
		sex_label = "girl"

	var child_full_name:= ("%s %s" % [baby.first_name, baby.last_name]).strip_edges()
	var diary_text:= ""
	var popup_text:= ""
	if int(mother.id) == int(gs.player.id):
		diary_text = "I gave birth to a %s named %s." % [sex_label, child_full_name]
		popup_text = "You gave birth to a %s.\n\nYou named the baby %s." % [sex_label, child_full_name]
	else:
		var mother_label: String = str(gs.get_relationship_label_between(gs.player, mother)).strip_edges()
		if mother_label == "" or mother_label == "Stranger":
			mother_label = "Partner"
		diary_text = "My %s gave birth to a %s named %s." % [mother_label.to_lower(), sex_label, child_full_name]
		popup_text = "Your %s gave birth to a %s.\n\nYou named the baby %s." % [mother_label.to_lower(), sex_label, child_full_name]

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.CHILD_BORN_PLAYER_LINE, {
			"npc_id": mother.id,
			"target_id": father.id,
			"child_id": baby.id,
			"text": "%s gave birth to %s's child, %s." % [
				mother.first_name,
				father.first_name,
				baby.first_name
			]
		})

	mother.pregnant_by_id = -1
	mother.unborn_child_other_parent_id = -1
	mother.pregnancy_progress = -1
	mother.pregnancy_known = false
	mother.pregnancy_context = ""
	gs.pending_player_line_birth = {}
	return {
		"success": true,
		"type": "player_line_birth_resolved",
		"text": diary_text,
		"popup_title": "New Baby",
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}
func _advance_year_and_handle_era_shift(actor_for_narrative: Person = null) -> void:
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

	if runtime_engine != null:
		if runtime_engine.has_method("begin_year_transaction") and runtime_engine.active_year_context.is_empty():
			runtime_engine.begin_year_transaction({
				"mode": "living",
				"year": target_year,
				"player_id": int(gs.player.id) if gs.player != null else -1,
				"runtime_owner": "age_up_runtime_engine",
				"time_contract": time_contract.duplicate(true),
				"contract_source_year": source_year,
				"contract_target_year": target_year,
				"contract_source_age": source_age,
				"contract_target_age": target_age,
				"fallback_reason": "life_engine_contract_fallback"
			})

		runtime_engine.advance_year_and_handle_era_shift(actor_for_narrative)
		return

	if not gs.year_locked:
		gs.year = target_year

	var turn_subject: Person = gs.player if gs.player != null else actor_for_narrative
	if turn_subject != null and turn_subject.alive:
		turn_subject.age = target_age

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.YEAR_PASSED, {
			"year": gs.year,
			"source_year": source_year,
			"target_year": target_year,
			"time_authority": "age_up_time_contract"
		})

	var previous_era_name: String = ""
	if gs.era != null:
		previous_era_name = gs.era.name

	var era_after = gs.era_engine._era_from_year(gs.year)
	if era_after.name != previous_era_name:
		gs.era = era_after

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.ERA_SHIFT, {
				"era": era_after.name,
				"year": int(gs.year),
				"time_authority": "age_up_time_contract"
			})

		if gs.world_chronicle_engine != null:
			gs.world_chronicle_engine.log(
				"The world entered the %s." % era_after.name
			)

		if actor_for_narrative != null:
			gs.narrative_engine.log_event(actor_for_narrative, {
				"type": "era_shift",
				"text": "As I turned %d, the world entered the %s." % [
					actor_for_narrative.age,
					era_after.name
				]
			})
func _age_up_afterlife_year() -> Dictionary:
	if runtime_engine != null and runtime_engine.has_pending_commit():
		runtime_engine.drain_pending_commit(64)
		if runtime_engine.has_pending_commit():
			return {
				"type": "year_pipeline_pending",
				"text": "Time is still settling from last year...",
				"opps": []
			}

	if gs.year_budget_engine != null and gs.year_budget_engine.has_pending_year_pipeline():
		gs.year_budget_engine.drain_pending_year_pipeline(64)
		if gs.year_budget_engine.has_pending_year_pipeline():
			return {
				"type": "year_pipeline_pending",
				"text": "Time is still settling from last year...",
				"opps": []
			}

	if gs.afterlife_influence_engine == null:
		return _handle_player_death()
	if not gs.afterlife_active:
		return _handle_player_death()
	if gs.afterlife_influence_engine.has_pending_choice():
		return gs.afterlife_influence_engine.get_pending_choice_result()

	if bool(gs.afterlife_state.get("round_ready_to_advance", false)):
		gs.afterlife_state ["round_ready_to_advance"] = false
		gs.afterlife_influence_engine.apply_committed_bias_for_year()

		if runtime_engine != null:
			runtime_engine.begin_year_transaction({
				"mode": "afterlife",
				"year": int(gs.year + 1),
				"player_id": int(gs.afterlife_state.get("anchored_descendant_id", -1))
			})

		_advance_year_and_handle_era_shift(null)
		_simulate_world()

		if gs.year_budget_engine != null:
			gs.year_budget_engine.flush_year_pipeline()

		return gs.afterlife_influence_engine.resolve_post_year_result()

	var setup: Dictionary = gs.afterlife_influence_engine.prepare_pre_year_intervention()
	if setup.has("type") and str(setup.get("type", "")).begins_with("afterlife"):
		return setup
	if gs.afterlife_influence_engine.has_pending_choice():
		return gs.afterlife_influence_engine.get_pending_choice_result()

	return {
		"type": "afterlife_idle",
		"text": "The afterlife is waiting for the next spiritual choice.",
		"opps": []
	}
func _simulate_world():
	if runtime_engine != null:
		runtime_engine.run_year_runtime()
		return






	gs.world_engine.run_world_year()
	gs.dynamic_world_event_engine.yearly_world_events()


	var groups = gs.spatial_culling_engine.classify()

	if gs.afterlife_active:
		var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
		if anchor_id > 0:
			var anchor_npc: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
			if anchor_npc != null and anchor_npc.alive:
				if anchor_npc not in groups.near:
					groups.near.append(anchor_npc)






	if gs.year_budget_engine != null:
		gs.year_budget_engine.process_near_npcs(groups.near)
		gs.year_budget_engine.start_year_pipeline(groups)
	else:
		for npc in groups.near:
			if npc == null or not npc.alive:
				continue
			gs.health_engine.update_health(npc)
			gs.career_engine.update_career(npc)
			gs.personality_engine.generate_traits(npc)
			gs.fate_engine.assign_arc(npc)
			gs.desire_engine.yearly_tick(npc)
			gs.goal_planning_engine.yearly_update(npc)
			gs.desire_behavior_bridge.process_npc(npc)
			gs.capability_graph_engine.yearly_growth(npc)

		for npc in groups.mid:
			if npc == null or not npc.alive:
				continue
			gs.health_engine.update_health(npc)
			gs.career_engine.update_career(npc)
			if randi() % 3 == 0:
				gs.personality_engine.generate_traits(npc)
			if randi() % 4 == 0:
				gs.desire_engine.yearly_tick(npc)

		for npc in groups.far:
			if npc == null or not npc.alive:
				continue
			gs.spatial_culling_engine.simulate_far_npc(npc)

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



func tick() -> Dictionary:
	if gs == null or gs.player == null:
		return {
			"success": false,
			"reason": "missing_realtime_actor",
			"is_complete": true,
			"cycle_complete": true
		}

	var cycle_active: bool = bool(
		get_meta(
			"life_realtime_cycle_active",
			false
		)
	)

	if not cycle_active:



		if gs.event_bus != null:
			gs.event_bus.emit(
				ActionEventTypes.REALTIME_TICK,
				{
					"npc_id": int(gs.player.id),
					"source": "life_engine_realtime_cycle",
					"dispatch_lane": "ambient",
					"qos_tier": "ambient",
					"fanout_hints": {
						"force_defer_bus": true,
						"event_batch_key": "life_realtime_tick|%d" % int(
							gs.player.id
						)
					}
				}
			)

		var relevance_snapshot: Dictionary = {}

		if (
			gs.simulation_director != null
			and gs.simulation_director.has_method(
				"get_resident_realtime_relevance_snapshot"
			)
		):
			relevance_snapshot = (
				gs.simulation_director
				.get_resident_realtime_relevance_snapshot()
			)

		if not bool(
			relevance_snapshot.get(
				"success",
				false
			)
		):
			set_meta(
				"life_realtime_cycle_active",
				false
			)
			remove_meta(
				"life_realtime_near_ids"
			)
			remove_meta(
				"life_realtime_near_cursor"
			)
			remove_meta(
				"life_realtime_relevance_source"
			)

			return {
				"success": true,
				"reason": "resident_relevance_snapshot_unavailable",
				"is_complete": true,
				"cycle_complete": true,
				"processed_this_quantum": 0,
				"remaining": 0,
				"intrinsically_bounded": true,
				"max_near_rows_per_quantum": 1
			}

		var authored_relevance_near_ids_raw: Variant = relevance_snapshot.get(
			"near_ids",
			[]
		)
		var resident_near_ids: Array = (
			authored_relevance_near_ids_raw as Array
			if typeof(authored_relevance_near_ids_raw) == TYPE_ARRAY
			else []
		)

		set_meta(
			"life_realtime_near_ids",
			resident_near_ids
		)
		set_meta(
			"life_realtime_near_cursor",
			0
		)
		set_meta(
			"life_realtime_relevance_source",
			str(
				relevance_snapshot.get(
					"source",
					""
				)
			)
		)
		set_meta(
			"life_realtime_cycle_active",
			true
		)
		set_meta(
			"life_realtime_cycle_started_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

	var near_ids_raw: Variant = get_meta(
		"life_realtime_near_ids",
		[]
	)
	var near_ids: Array = (
		near_ids_raw as Array
		if typeof(near_ids_raw) == TYPE_ARRAY
		else []
	)
	var cursor: int = clampi(
		int(
			get_meta(
				"life_realtime_near_cursor",
				0
			)
		),
		0,
		near_ids.size()
	)
	var relevance_source: String = str(
		get_meta(
			"life_realtime_relevance_source",
			""
		)
	)

	if cursor >= near_ids.size():
		remove_meta(
			"life_realtime_near_ids"
		)
		remove_meta(
			"life_realtime_near_cursor"
		)
		remove_meta(
			"life_realtime_relevance_source"
		)
		set_meta(
			"life_realtime_cycle_active",
			false
		)

		return {
			"success": true,
			"is_complete": true,
			"cycle_complete": true,
			"processed_this_quantum": 0,
			"remaining": 0,
			"intrinsically_bounded": true,
			"resident_relevance_source": relevance_source,
			"max_near_rows_per_quantum": 1
		}




	var npc_id: int = int(
		near_ids [cursor]
	)
	cursor += 1

	var npc = null

	if int(gs.player.id) == npc_id:
		npc = gs.player
	elif (
		npc_id > 0
		and gs.has_method(
			"get_npc_by_id"
		)
	):
		npc = gs.get_npc_by_id(
			npc_id,
			false
		)

	var processed_this_quantum: int = 0

	if (
		npc != null
		and npc != gs.player
		and npc.alive
	):
		if gs.relationship_engine != null:
			gs.relationship_engine.update_relationships_for_npc(
				npc,
				1
			)




		processed_this_quantum = 1

	var cycle_complete: bool = (
		cursor >= near_ids.size()
	)

	if cycle_complete:
		remove_meta(
			"life_realtime_near_ids"
		)
		remove_meta(
			"life_realtime_near_cursor"
		)
		remove_meta(
			"life_realtime_relevance_source"
		)
		set_meta(
			"life_realtime_cycle_active",
			false
		)
	else:
		set_meta(
			"life_realtime_near_cursor",
			cursor
		)

	return {
		"success": true,
		"is_complete": cycle_complete,
		"cycle_complete": cycle_complete,
		"processed_this_quantum": processed_this_quantum,
		"cursor": cursor,
		"remaining": maxi(
			0,
			near_ids.size() - cursor
		),
		"intrinsically_bounded": true,
		"resident_relevance_source": relevance_source,
		"max_near_rows_per_quantum": 1
	}
func _life_engine_inventory_item_is_weapon(
	item: Dictionary,
	category: String
) -> bool:
	if str(
		category
	).strip_edges().to_lower() == "weapons":
		return true

	if str(
		item.get(
			"asset_kind",
			""
		)
	).strip_edges().to_lower() == "weapon":
		return true

	if str(
		item.get(
			"type",
			""
		)
	).strip_edges().to_lower() == "weapon":
		return true

	for raw_domain in _life_safe_array(
		item.get(
			"object_domains",
			[]
		)
	):
		if str(
			raw_domain
		).strip_edges().to_lower() == "weapon":
			return true

	return not _life_safe_dictionary(
		item.get(
			"weapon_contract",
			{}
		)
	).is_empty()

func _resolve_owned_weapon_for_self_mortality(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or actor == null
		or gs.belongings_engine == null
	):
		return {}

	var inventory: Dictionary = (
		gs.belongings_engine.get_inventory(
			actor
		)
	)

	if inventory.is_empty():
		return {}

	var requested_instance_object_id: String = str(
		payload.get(
			"instance_object_id",
			""
		)
	).strip_edges()

	var requested_item_id: int = int(
		payload.get(
			"belonging_item_id",
			-1
		)
	)

	var requested_catalog_object_id: String = str(
		payload.get(
			"catalog_object_id",
			""
		)
	).strip_edges()

	var requested_name: String = str(
		payload.get(
			"weapon_name",
			""
		)
	).strip_edges().to_lower()

	var selector_mode: String = "name"

	if requested_instance_object_id != "":
		selector_mode = "instance"
	elif requested_item_id > 0:
		selector_mode = "item_id"
	elif requested_catalog_object_id != "":
		selector_mode = "catalog"

	for raw_category in inventory.keys():
		var category: String = str(
			raw_category
		)

		var raw_items: Variant = inventory.get(
			raw_category,
			[]
		)

		if typeof(
			raw_items
		) != TYPE_ARRAY:
			continue

		for raw_item in raw_items as Array:
			if typeof(
				raw_item
			) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = (
				raw_item as Dictionary
			)

			if not _life_engine_inventory_item_is_weapon(
				item,
				category
			):
				continue

			match selector_mode:
				"instance":
					var candidate_instance_id: String = str(
						item.get(
							"instance_object_id",
							item.get(
								"object_id",
								""
							)
						)
					).strip_edges()

					if (
						candidate_instance_id
						== requested_instance_object_id
					):
						return item.duplicate(true)

				"item_id":
					if int(
						item.get(
							"id",
							-1
						)
					) == requested_item_id:
						return item.duplicate(true)

				"catalog":
					if str(
						item.get(
							"catalog_object_id",
							""
						)
					).strip_edges() == requested_catalog_object_id:
						return item.duplicate(true)

				_:
					var candidate_name: String = str(
						item.get(
							"display_name",
							item.get(
								"name",
								""
							)
						)
					).strip_edges().to_lower()

					if (
						requested_name != ""
						and candidate_name == requested_name
					):
						return item.duplicate(true)

	return {}
func resolve_weapon_self_mortality_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
		or actor == null
	):
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"The controlled life is unavailable."
			),
			"popup_footer": "Tap anywhere to continue.",
			"ui_is_renderer_only": true
		}

	if int(
		actor.id
	) != int(
		gs.player.id
	):
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"That weapon action belonged to a stale viewpoint."
			),
			"popup_footer": "Tap anywhere to continue.",
			"ui_is_renderer_only": true
		}

	if not bool(
		actor.alive
	):
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"This life has already ended."
			),
			"popup_footer": "Tap anywhere to continue.",
			"ui_is_renderer_only": true
		}

	if (
		gs.health_engine == null
		or not gs.health_engine.has_method(
			"commit_weapon_self_mortality_core"
		)
		or not gs.health_engine.has_method(
			"queue_committed_death_fanout"
		)
	):
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"Mortality authority is unavailable."
			),
			"popup_footer": "Tap anywhere to continue.",
			"ui_is_renderer_only": true
		}

	var weapon: Dictionary = (
		_resolve_owned_weapon_for_self_mortality(
			actor,
			payload
		)
	)

	if weapon.is_empty():
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"That weapon is no longer owned by this life."
			),
			"popup_footer": "Tap anywhere to continue.",
			"weapon_ownership_revalidated": true,
			"ui_is_renderer_only": true
		}

	var weapon_name: String = str(
		weapon.get(
			"display_name",
			weapon.get(
				"name",
				"weapon"
			)
		)
	).strip_edges()

	if weapon_name == "":
		weapon_name = "weapon"

	var cause: String = (
		"Ended it all with a %s."
		% weapon_name
	)






	var mortality_core_report: Dictionary = (
		gs.health_engine.commit_weapon_self_mortality_core(
			actor,
			cause
		)
	)
	var death_committed: bool = bool(
		mortality_core_report.get(
			"death_committed",
			false
		)
	)

	if not death_committed:
		return {
			"success": false,
			"popup_title": "Weapon",
			"popup_text": (
				"Mortality authority did not commit the death."
			),
			"popup_footer": "Tap anywhere to continue.",
			"weapon_name": weapon_name,
			"cause": cause,
			"self_inflicted": true,
			"mortality_core_report": (
				mortality_core_report.duplicate(false)
			),
			"ui_is_renderer_only": true
		}






	var death_result: Dictionary = (
		_handle_player_death()
	)




	var fanout_report: Dictionary = (
		gs.health_engine.queue_committed_death_fanout(
			actor,
			mortality_core_report
		)
	)





	if str(
		death_result.get(
			"type",
			""
		)
	).strip_edges() != "afterlife_death_prompt":
		death_result [
			"type"
		] = "afterlife_death_prompt"
		death_result [
			"text"
		] = (
			"Cause of death: %s\n\nChoose what happens next."
			% cause
		)

		if not death_result.has(
			"opps"
		):
			death_result [
				"opps"
			] = _life_safe_array(
				death_result.get(
					"options",
					[]
				)
			).duplicate(true)

	death_result [
		"success"
	] = true
	death_result [
		"death_committed"
	] = true
	death_result [
		"mortality_core_committed"
	] = true
	death_result [
		"mortality_fanout_queued"
	] = bool(
		fanout_report.get(
			"success",
			false
		)
	)
	death_result [
		"mortality_fanout_queue_id"
	] = str(
		fanout_report.get(
			"queue_id",
			""
		)
	)
	death_result [
		"mortality_fanout_blocks_first_observable_death"
	] = false
	death_result [
		"mortality_fanout_requires_player_idle"
	] = false
	death_result [
		"self_inflicted"
	] = true
	death_result [
		"cause"
	] = cause
	death_result [
		"weapon_name"
	] = weapon_name
	death_result [
		"belonging_item_id"
	] = int(
		weapon.get(
			"id",
			-1
		)
	)
	death_result [
		"catalog_object_id"
	] = str(
		weapon.get(
			"catalog_object_id",
			""
		)
	)
	death_result [
		"instance_object_id"
	] = str(
		weapon.get(
			"instance_object_id",
			weapon.get(
				"object_id",
				""
			)
		)
	)
	death_result [
		"weapon_ownership_revalidated"
	] = true
	death_result [
		"source"
	] = "life_engine.weapon_self_mortality"
	death_result [
		"ui_is_renderer_only"
	] = true

	return death_result

func _handle_player_death():
	gs.awaiting_new_life = true
	if gs.afterlife_influence_engine == null or gs.player == null:
		return {
			"type": "no_descendants",
			"options": [
				"random_life",
				"custom_life",
				"rewind_one_year"
			]
		}

	if not gs.afterlife_active:
		gs.afterlife_influence_engine.enter_afterlife_for_player(gs.player, {
			"cause": gs.player.cause_of_death
		})

	return gs.afterlife_influence_engine.get_pending_choice_result()
func _resolve_living_descendants(ids: Array) -> Array:
	var out:= []

	for id in ids:
		var facts = gs.get_npc_facts_by_id(int(id))
		if facts == {}:
			continue
		if not bool(facts.get("alive", false)):
			continue

		var person = gs.get_npc_by_id(int(id))
		if person == null and gs.dormant_npcs.has(int(id)):
			person = gs.reactivate_npc(int(id))

		if person != null and person.alive:
			out.append(person)

	return out