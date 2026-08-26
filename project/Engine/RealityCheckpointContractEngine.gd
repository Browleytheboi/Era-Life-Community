extends Resource
class_name RealityCheckpointContractEngine

const CHECKPOINT_CANDIDATES_SCHEMA:= "eralife.reality.checkpoint_candidates"
const LOCAL_POINTER_PATH:= "user://identity/local_checkpoint_pointer.json"
const CONTRACT_VERSION:= 1

var gs
var last_candidates: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func fetch_local_checkpoint(identity_context: Dictionary = {}, session_context: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var pointer: Dictionary = _safe_dictionary(session_context.get("session_pointer", {}))
	var session_candidate: Dictionary = _candidate_from_pointer(pointer, "session_pointer", identity_context)
	if _candidate_is_valid(session_candidate):
		return session_candidate

	var disk_pointer: Dictionary = _read_local_pointer()
	var pointer_candidate: Dictionary = _candidate_from_pointer(disk_pointer, "local_checkpoint_pointer", identity_context)
	if _candidate_is_valid(pointer_candidate):
		return pointer_candidate

	var newest_path: String = _newest_saved_life_path()
	if newest_path != "":
		return _candidate_from_path(newest_path, "saved_lives_scan", identity_context, context)

	return {
		"schema": "eralife.reality.checkpoint_candidate",
		"version": CONTRACT_VERSION,
		"success": false,
		"authority": "local",
		"reason": "no_local_checkpoint"
	}

func fetch_cloud_checkpoint_async(identity_context: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.reality.checkpoint_candidate",
		"version": CONTRACT_VERSION,
		"success": false,
		"authority": "cloud",
		"state": "not_attached" if str(identity_context.get("cloud_identity_id", "")) == "" else "pending",
		"nonblocking": true,
		"context": context.duplicate(true)
	}

func emit_checkpoint_candidates(identity_context: Dictionary = {}, session_context: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var local_candidate: Dictionary = fetch_local_checkpoint(identity_context, session_context, context)
	var cloud_candidate: Dictionary = fetch_cloud_checkpoint_async(identity_context, context)

	last_candidates = {
		"schema": CHECKPOINT_CANDIDATES_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"identity_context": identity_context.duplicate(true),
		"session_context": session_context.duplicate(true),
		"local_checkpoint": local_candidate.duplicate(true),
		"cloud_checkpoint": cloud_candidate.duplicate(true),
		"candidates": [local_candidate.duplicate(true), cloud_candidate.duplicate(true)],
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "RealityCheckpointContractEngine",
			"ui_mutation_allowed": false
		}
	}
	_commit_state()
	return last_candidates.duplicate(true)

func commit_local_checkpoint(
	checkpoint: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = checkpoint.duplicate(true)

	normalized ["schema"] = "eralife.reality.local_checkpoint_pointer"
	normalized ["version"] = CONTRACT_VERSION
	normalized ["checkpoint_path"] = str(
		normalized.get(
			"checkpoint_path",
			context.get(
				"checkpoint_path",
				""
			)
		)
	).strip_edges()
	normalized ["identity_id"] = str(
		normalized.get(
			"identity_id",
			context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()
	normalized ["life_id"] = str(
		normalized.get(
			"life_id",
			context.get(
				"life_id",
				""
			)
		)
	).strip_edges()
	normalized ["actor_id"] = int(
		normalized.get(
			"actor_id",
			context.get(
				"actor_id",
				-1
			)
		)
	)
	normalized ["residency_signature"] = str(
		normalized.get(
			"residency_signature",
			context.get(
				"residency_signature",
				(
					str(
						gs.scenario_state.get(
							"resident_runtime_signature",
							gs.scenario_state.get(
								"resident_runtime_attached_signature",
								""
							)
						)
					).strip_edges()
					if (
						gs != null
						and typeof(gs.scenario_state) == TYPE_DICTIONARY
					)
					else ""
				)
			)
		)
	).strip_edges()
	normalized ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	normalized ["timestamp"] = int(
		Time.get_unix_time_from_system()
	)

	if str(
		normalized.get(
			"checkpoint_path",
			""
		)
	) == "":
		return {
			"success": false,
			"reason": "checkpoint_path_missing"
		}

	_ensure_identity_dir()

	var file:= FileAccess.open(
		LOCAL_POINTER_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return {
			"success": false,
			"reason": "local_checkpoint_pointer_write_failed"
		}

	file.store_string(
		JSON.stringify(
			normalized,
			"\t"
		)
	)
	file.close()

	var snapshot_bind_report: Dictionary = {}
	var residency_bind_report: Dictionary = {}
	var signature: String = str(
		normalized.get(
			"residency_signature",
			""
		)
	).strip_edges()

	if (
		gs != null
		and signature != ""
		and gs.reality_snapshot_contract_engine != null
		and gs.reality_snapshot_contract_engine.has_method(
			"bind_checkpoint_to_snapshot"
		)
	):
		snapshot_bind_report = (
			gs.reality_snapshot_contract_engine.bind_checkpoint_to_snapshot(
				signature,
				normalized
			)
		)

	if (
		gs != null
		and signature != ""
		and gs.reality_residency_manager != null
		and gs.reality_residency_manager.has_method(
			"bind_checkpoint_to_resident_record"
		)
	):
		residency_bind_report = (
			gs.reality_residency_manager.bind_checkpoint_to_resident_record(
				signature,
				normalized
			)
		)

	last_report = {
		"success": true,
		"mode": "local_checkpoint_pointer_committed",
		"checkpoint": normalized.duplicate(true),
		"snapshot_bind_report": snapshot_bind_report.duplicate(true),
		"residency_bind_report": residency_bind_report.duplicate(true),
		"restart_hydration_ready": (
			signature != ""
			and FileAccess.file_exists(
				str(
					normalized.get(
						"checkpoint_path",
						""
					)
				)
			)
		)
	}

	_commit_state()

	return last_report.duplicate(true)
func _candidate_from_pointer(pointer: Dictionary, source: String, identity_context: Dictionary = {}) -> Dictionary:
	if pointer.is_empty():
		return {}
	return _candidate_from_path(str(pointer.get("checkpoint_path", "")), source, identity_context, pointer)

func _candidate_from_path(
	path: String,
	source: String,
	identity_context: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	var clean_path: String = str(
		path
	).strip_edges()
	var exists: bool = (
		clean_path != ""
		and FileAccess.file_exists(
			clean_path
		)
	)
	var modified_unix: int = (
		int(
			FileAccess.get_modified_time(
				clean_path
			)
		)
		if exists
		else 0
	)
	var resume_raw: Variant = context.get(
		"checkpoint_resume_contract",
		{}
	)
	var resume_contract: Dictionary = (
		(resume_raw as Dictionary).duplicate(false)
		if typeof(
			resume_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var current_panel: String = str(
		context.get(
			"current_panel",
			resume_contract.get(
				"current_panel",
				"life"
			)
		)
	).strip_edges().to_lower()

	if current_panel == "":
		current_panel = "life"

	return {
		"schema": "eralife.reality.checkpoint_candidate",
		"version": CONTRACT_VERSION,
		"success": exists,
		"authority": "local",
		"source": source,
		"checkpoint_path": clean_path,
		"path": clean_path,
		"identity_id": str(
			context.get(
				"identity_id",
				identity_context.get(
					"identity_id",
					""
				)
			)
		),
		"life_id": str(
			context.get(
				"life_id",
				""
			)
		),
		"actor_id": int(
			context.get(
				"actor_id",
				resume_contract.get(
					"actor_id",
					-1
				)
			)
		),
		"controlled_actor_id": int(
			context.get(
				"controlled_actor_id",
				resume_contract.get(
					"controlled_actor_id",
					-1
				)
			)
		),
		"residency_signature": str(
			context.get(
				"residency_signature",
				resume_contract.get(
					"residency_signature",
					""
				)
			)
		).strip_edges(),
		"current_panel": current_panel,
		"checkpoint_resume_contract": (
			resume_contract
		),
		"updated_at_ms": int(
			context.get(
				"updated_at_ms",
				modified_unix * 1000
			)
		),
		"timestamp": int(
			context.get(
				"timestamp",
				modified_unix
			)
		),
		"valid_fast_path": exists,
		"restart_hydration_ready": exists,
		"controlled_actor_checkpoint": (
			int(
				resume_contract.get(
					"actor_id",
					-1
				)
			) > 0
		),
		"blank_life_shell_forbidden": true,
		"nonblocking": true
	}

func _candidate_is_valid(candidate: Dictionary) -> bool:
	return bool(candidate.get("success", false)) and FileAccess.file_exists(str(candidate.get("checkpoint_path", "")))

func _newest_saved_life_path() -> String:
	var root:= DirAccess.open("user://saved_lives")
	if root == null:
		return ""
	var newest_path: String = ""
	var newest_modified: int = -1
	for file_name in root.get_files():
		var lower_name: String = str(file_name).to_lower()
		if not (lower_name.ends_with(".bin") or lower_name.ends_with(".json")):
			continue
		var full_path: String = "user://saved_lives/%s" % file_name
		var modified: int = int(FileAccess.get_modified_time(full_path))
		if modified > newest_modified:
			newest_modified = modified
			newest_path = full_path
	return newest_path

func _read_local_pointer() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_POINTER_PATH):
		return {}
	var file:= FileAccess.open(LOCAL_POINTER_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["checkpoint_candidates"] = last_candidates.duplicate(true)
	gs.scenario_state ["last_reality_checkpoint_report"] = last_report.duplicate(true)

func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}