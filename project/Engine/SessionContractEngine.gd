extends Resource
class_name SessionContractEngine

const SESSION_POINTER_SCHEMA:= "eralife.session.pointer"
const SESSION_CONTEXT_SCHEMA:= "eralife.session.context"
const CONTRACT_VERSION:= 1
const SESSION_POINTER_PATH:= "user://identity/session_pointer.json"

var gs
var last_session_pointer: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func try_restore_last_session_pointer(identity_context: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var pointer: Dictionary = _read_pointer()
	var valid: bool = _pointer_is_valid(pointer, identity_context)

	last_session_pointer = pointer.duplicate(true) if valid else {}
	_commit_state()

	last_report = {
		"schema": SESSION_CONTEXT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "session_pointer_restored" if valid else "session_pointer_missing",
		"has_session": valid,
		"session_pointer": last_session_pointer.duplicate(true),
		"identity_id": str(identity_context.get("identity_id", "")),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func update_session_pointer(pointer: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_pointer(pointer, context)
	if not _pointer_is_valid(normalized, _safe_dictionary(context.get("identity_context", {}))):
		return {
			"schema": "eralife.session.pointer_update_report",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "invalid_session_pointer",
			"pointer": normalized
		}

	last_session_pointer = normalized.duplicate(true)
	_write_pointer(last_session_pointer)
	_commit_state()

	last_report = {
		"schema": "eralife.session.pointer_update_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "session_pointer_updated",
		"session_pointer": last_session_pointer.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func emit_session_context(context: Dictionary = {}) -> Dictionary:
	if last_session_pointer.is_empty():
		try_restore_last_session_pointer(_safe_dictionary(context.get("identity_context", {})), context)
	return {
		"schema": SESSION_CONTEXT_SCHEMA,
		"version": CONTRACT_VERSION,
		"has_session": not last_session_pointer.is_empty(),
		"session_pointer": last_session_pointer.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func clear_session_pointer(reason: String = "clear_session_pointer") -> Dictionary:
	last_session_pointer = {}
	if FileAccess.file_exists(SESSION_POINTER_PATH):
		DirAccess.remove_absolute(SESSION_POINTER_PATH)
	_commit_state()
	return {
		"success": true,
		"mode": "session_pointer_cleared",
		"reason": reason,
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _normalize_pointer(pointer: Dictionary, context: Dictionary = {}) -> Dictionary:
	var identity_context: Dictionary = _safe_dictionary(context.get("identity_context", pointer.get("identity_context", {})))
	var out: Dictionary = pointer.duplicate(true)
	out ["schema"] = SESSION_POINTER_SCHEMA
	out ["version"] = CONTRACT_VERSION
	out ["identity_id"] = str(out.get("identity_id", identity_context.get("identity_id", ""))).strip_edges()
	out ["life_id"] = str(out.get("life_id", _life_id_from_context(context))).strip_edges()
	out ["actor_id"] = int(out.get("actor_id", _player_id()))
	out ["checkpoint_path"] = str(out.get("checkpoint_path", context.get("checkpoint_path", ""))).strip_edges()
	out ["location"] = str(out.get("location", context.get("location", "life"))).strip_edges()
	out ["active_context"] = str(out.get("active_context", context.get("active_context", "life"))).strip_edges()
	out ["ui_surface"] = str(out.get("ui_surface", context.get("ui_surface", ""))).strip_edges()
	out ["scene_route"] = str(out.get("scene_route", context.get("scene_route", ""))).strip_edges()
	out ["updated_at_ms"] = int(out.get("updated_at_ms", Time.get_ticks_msec()))
	out ["timestamp"] = int(out.get("timestamp", Time.get_unix_time_from_system()))
	out ["contract_mesh"] = {
		"source_of_truth": "SessionContractEngine",
		"ui_mutation_allowed": false,
		"checkpoint_owner": "RealityCheckpointContractEngine"
	}
	return out

func _pointer_is_valid(
	pointer: Dictionary,
	identity_context: Dictionary = {}
) -> bool:
	if pointer.is_empty():
		return false

	var checkpoint_path: String = str(
		pointer.get(
			"checkpoint_path",
			""
		)
	).strip_edges()

	if (
		checkpoint_path == ""
		or not FileAccess.file_exists(
			checkpoint_path
		)
	):
		return false

	var life_id: String = str(
		pointer.get(
			"life_id",
			""
		)
	).strip_edges()

	if life_id == "":
		return false

	var pointer_identity_set: Dictionary = {}
	var current_identity_set: Dictionary = {}

	for identity_key in [
		"identity_id",
		"local_identity_id",
		"cloud_identity_id",
		"owner_identity_id",
		"account_identity_id"
	]:
		var pointer_identity: String = str(
			pointer.get(
				identity_key,
				""
			)
		).strip_edges()

		if pointer_identity != "":
			pointer_identity_set [
				pointer_identity
			] = true

		var current_identity: String = str(
			identity_context.get(
				identity_key,
				""
			)
		).strip_edges()

		if current_identity != "":
			current_identity_set [
				current_identity
			] = true

	if (
		not pointer_identity_set.is_empty()
		and not current_identity_set.is_empty()
	):
		var identity_match_found: bool = false

		for pointer_identity_raw in pointer_identity_set.keys():
			var pointer_identity: String = str(
				pointer_identity_raw
			)

			if current_identity_set.has(
				pointer_identity
			):
				identity_match_found = true
				break

		if not identity_match_found:
			return false

	return true
func _life_id_from_context(context: Dictionary) -> String:
	var explicit_id: String = str(context.get("life_id", "")).strip_edges()
	if explicit_id != "":
		return explicit_id
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		explicit_id = str(gs.scenario_state.get("life_id", "")).strip_edges()
		if explicit_id != "":
			return explicit_id
	return "life_%d_%d" % [_player_id(), int(Time.get_unix_time_from_system())]

func _player_id() -> int:
	if gs == null:
		return -1
	if gs.player != null:
		return int(gs.player.id)
	return int(gs.player_id)

func _read_pointer() -> Dictionary:
	if not FileAccess.file_exists(SESSION_POINTER_PATH):
		return {}
	var file:= FileAccess.open(SESSION_POINTER_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _write_pointer(pointer: Dictionary) -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(SESSION_POINTER_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(pointer, "\t"))
	file.close()

func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["last_session_pointer"] = last_session_pointer.duplicate(true)
	gs.scenario_state ["last_session_contract_report"] = last_report.duplicate(true)

func _safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}