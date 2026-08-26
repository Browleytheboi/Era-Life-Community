extends Resource
class_name CrossDeviceContinuitySyncLayer

const CONTRACT_SCHEMA:= "eralife.cross_device_continuity_sync_layer"
const CONTRACT_VERSION:= 1
const CONTINUITY_FOLDER:= "user://eralife_continuity"
const DEVICE_ID_PATH:= "user://eralife_device_identity.json"
const DEFAULT_MAX_CHECKPOINTS_PER_LIFE:= 24

var gs
var contract_engine
var continuity_registry: Dictionary = {}
var device_identity: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null, _contract_engine = null):
	gs = _gs
	contract_engine = _contract_engine
	_ensure_continuity_folder()
	device_identity = _load_or_create_device_identity()

func build_continuity_checkpoint(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "" and contract_engine != null:
		clean_world_id = str(contract_engine.active_state_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = "eralife_default_world"

	var identity: Dictionary = {}
	if contract_engine != null and contract_engine.has_method("ensure_life_identity"):
		var identity_options: Dictionary = options.duplicate(true)
		identity_options ["world_id"] = clean_world_id
		identity = contract_engine.ensure_life_identity(identity_options)

	var life_id: String = str(identity.get("life_id", options.get("life_id", ""))).strip_edges()
	var timeline_id: String = str(identity.get("timeline_id", options.get("timeline_id", ""))).strip_edges()
	if life_id == "":
		life_id = _short_id("life", "%s.%d" % [clean_world_id, int(Time.get_ticks_msec())])
	if timeline_id == "":
		timeline_id = _short_id("timeline", life_id)

	var resume_cursor: Dictionary = _build_resume_cursor(options)
	var checkpoint_id: String = str(options.get("checkpoint_id", "")).strip_edges()
	if checkpoint_id == "":
		checkpoint_id = _short_id("cc", "%s.%s.%s.%d" % [
			clean_world_id,
			life_id,
			timeline_id,
			int(Time.get_ticks_msec())
		])

	var portable_capsule: Dictionary = {}
	if contract_engine != null and contract_engine.has_method("build_portable_save_capsule") and not bool(options.get("skip_portable_capsule", false)):
		var capsule_options: Dictionary = options.duplicate(true)
		capsule_options ["life_identity"] = identity.duplicate(true)
		capsule_options ["include_life_identity"] = true
		capsule_options ["continuation_kind"] = "mid_year_device_continuation"
		capsule_options ["continuity_checkpoint_id"] = checkpoint_id
		capsule_options ["skip_continuity_checkpoint"] = true
		portable_capsule = contract_engine.build_portable_save_capsule(clean_world_id, capsule_options)

	var short_resume_id: String = _short_id("r", "%s.%s" % [life_id, checkpoint_id])
	var checkpoint:= {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"checkpoint_id": checkpoint_id,
		"short_resume_id": short_resume_id,
		"world_id": clean_world_id,
		"state_id": str(contract_engine.active_state_id) if contract_engine != null else clean_world_id,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"lineage_id": str(identity.get("lineage_id", "")),
		"continuation_kind": "mid_year_device_continuation",
		"device": device_identity.duplicate(true),
		"resume_cursor": resume_cursor.duplicate(true),
		"portable_save_capsule": portable_capsule.duplicate(true),
		"runtime": {
			"save_persistent": true
		},
		"compatibility": {
			"backwards_compatible": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_register_checkpoint(checkpoint)
	_persist_checkpoint(checkpoint)

	last_report = {
		"schema": "eralife.cross_device_continuity_checkpoint_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"checkpoint_id": checkpoint_id,
		"short_resume_id": short_resume_id,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"device_id": str(device_identity.get("device_id", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_write_runtime_report(last_report)
	return checkpoint

func import_continuity_checkpoint(checkpoint: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.cross_device_continuity_import_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"checkpoint_id": "",
		"short_resume_id": "",
		"life_id": "",
		"timeline_id": "",
		"capsule_import": {},
		"warnings": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(checkpoint) != TYPE_DICTIONARY or checkpoint.is_empty():
		report ["warnings"].append("Continuity checkpoint must be a Dictionary.")
		last_report = report.duplicate(true)
		return report

	var checkpoint_id: String = str(checkpoint.get("checkpoint_id", "")).strip_edges()
	var short_resume_id: String = str(checkpoint.get("short_resume_id", "")).strip_edges()
	report ["checkpoint_id"] = checkpoint_id
	report ["short_resume_id"] = short_resume_id
	report ["life_id"] = str(checkpoint.get("life_id", ""))
	report ["timeline_id"] = str(checkpoint.get("timeline_id", ""))

	_register_checkpoint(checkpoint)
	_persist_checkpoint(checkpoint)

	var capsule_raw: Variant = checkpoint.get("portable_save_capsule", {})
	if typeof(capsule_raw) == TYPE_DICTIONARY and not (capsule_raw as Dictionary).is_empty() and contract_engine != null and contract_engine.has_method("import_portable_save_capsule"):
		var import_options: Dictionary = options.duplicate(true)
		import_options ["continuity_resume"] = true
		import_options ["defer_hydration"] = bool(options.get("defer_hydration", false))
		import_options ["force_streaming_hydration"] = false
		report ["capsule_import"] = contract_engine.import_portable_save_capsule(capsule_raw as Dictionary, import_options)
	else:
		report ["warnings"].append("No portable capsule was present; checkpoint registry was imported only.")

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_device_continuity_checkpoint"] = checkpoint.duplicate(true)
		gs.scenario_state ["cross_device_resume_cursor"] = checkpoint.get("resume_cursor", {}).duplicate(true) if typeof(checkpoint.get("resume_cursor", {})) == TYPE_DICTIONARY else {}
		gs.scenario_state ["active_continuity_checkpoint_id"] = checkpoint_id
		gs.scenario_state ["active_continuity_short_resume_id"] = short_resume_id

	report ["success"] = bool(report.get("capsule_import", {}).get("success", false)) if typeof(report.get("capsule_import", {})) == TYPE_DICTIONARY else true
	last_report = report.duplicate(true)
	_write_runtime_report(report)
	return report

func resolve_continuity_checkpoint(id_or_short_id: String) -> Dictionary:
	var clean_id: String = str(id_or_short_id).strip_edges()
	if clean_id == "":
		return {}

	if continuity_registry.has(clean_id):
		var row_raw: Variant = continuity_registry.get(clean_id, {})
		return row_raw.duplicate(true) if typeof(row_raw) == TYPE_DICTIONARY else {}

	var path: String = "%s/%s.json" % [CONTINUITY_FOLDER, clean_id]
	if FileAccess.file_exists(path):
		var f:= FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				_register_checkpoint(parsed as Dictionary)
				return (parsed as Dictionary).duplicate(true)

	return {}

func export_debug_snapshot() -> Dictionary:
	return {
		"schema": "eralife.cross_device_continuity_debug",
		"version": CONTRACT_VERSION,
		"device_identity": device_identity.duplicate(true),
		"checkpoint_count": continuity_registry.size(),
		"last_report": last_report.duplicate(true)
	}

func _build_resume_cursor(options: Dictionary = {}) -> Dictionary:
	var cursor:= {
		"schema": "eralife.continuity_resume_cursor",
		"version": CONTRACT_VERSION,
		"year": 0,
		"age": 0,
		"player_id": -1,
		"scene_route": str(options.get("scene_route", "")),
		"ui_surface": str(options.get("ui_surface", "")),
		"mid_year": true,
		"cursor_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null:
		if "year" in gs:
			cursor ["year"] = int(gs.year)
		if "player_id" in gs:
			cursor ["player_id"] = int(gs.player_id)
		if "player" in gs and gs.player != null and "age" in gs.player:
			cursor ["age"] = int(gs.player.age)

	return cursor

func _register_checkpoint(checkpoint: Dictionary) -> void:
	var checkpoint_id: String = str(checkpoint.get("checkpoint_id", "")).strip_edges()
	var short_resume_id: String = str(checkpoint.get("short_resume_id", "")).strip_edges()
	var life_id: String = str(checkpoint.get("life_id", "")).strip_edges()

	if checkpoint_id != "":
		continuity_registry [checkpoint_id] = checkpoint.duplicate(true)
	if short_resume_id != "":
		continuity_registry [short_resume_id] = checkpoint.duplicate(true)
	if life_id != "":
		var life_rows: Array = []
		var existing_raw: Variant = continuity_registry.get("life:%s" % life_id, [])
		if typeof(existing_raw) == TYPE_ARRAY:
			life_rows = (existing_raw as Array).duplicate(true)

		life_rows.append({
			"checkpoint_id": checkpoint_id,
			"short_resume_id": short_resume_id,
			"created_at_ms": int(checkpoint.get("created_at_ms", Time.get_ticks_msec()))
		})

		while life_rows.size() > DEFAULT_MAX_CHECKPOINTS_PER_LIFE:
			life_rows.pop_front()

		continuity_registry ["life:%s" % life_id] = life_rows

	if contract_engine != null and "cross_device_continuity_registry" in contract_engine:
		contract_engine.cross_device_continuity_registry = continuity_registry.duplicate(true)

func _persist_checkpoint(checkpoint: Dictionary) -> void:
	var checkpoint_id: String = str(checkpoint.get("checkpoint_id", "")).strip_edges()
	var short_resume_id: String = str(checkpoint.get("short_resume_id", "")).strip_edges()
	if checkpoint_id == "":
		return

	var primary_path: String = "%s/%s.json" % [CONTINUITY_FOLDER, checkpoint_id]
	_write_json(primary_path, checkpoint)

	if short_resume_id != "":
		var short_path: String = "%s/%s.json" % [CONTINUITY_FOLDER, short_resume_id]
		_write_json(short_path, checkpoint)

func _write_runtime_report(report: Dictionary) -> void:
	if contract_engine != null and "last_cross_device_continuity_report" in contract_engine:
		contract_engine.last_cross_device_continuity_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_device_continuity_report"] = report.duplicate(true)

func _load_or_create_device_identity() -> Dictionary:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var f:= FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and str((parsed as Dictionary).get("device_id", "")).strip_edges() != "":
				return (parsed as Dictionary).duplicate(true)

	var identity:= {
		"schema": "eralife.device_identity",
		"version": CONTRACT_VERSION,
		"device_id": _short_id("dev", "%s.%d.%d" % [OS.get_name(), int(Time.get_unix_time_from_system()), randi()]),
		"device_os": OS.get_name(),
		"device_class": "unknown_runtime_device",
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_write_json(DEVICE_ID_PATH, identity)
	return identity

func _ensure_continuity_folder() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTINUITY_FOLDER))

func _write_json(path: String, data: Dictionary) -> void:
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _short_id(prefix: String, id_source: String) -> String:
	var value: int = abs(hash(str(id_source)))
	return "%s%s" % [prefix, _to_base36(value)]

func _to_base36(value: int) -> String:
	var alphabet:= "0123456789abcdefghijklmnopqrstuvwxyz"
	if value <= 0:
		return "0"

	var out:= ""
	var n: int = value
	while n > 0:
		var idx: int = n % 36
		out = alphabet.substr(idx, 1) + out
		n = floori(float(n) / 36.0)

	return out