extends Resource
class_name CRRContractEngine

const ENGINE_SCHEMA:= "eralife.crr_contract_engine"
const CONTRACT_VERSION:= 1
const CRR_REGISTRY_PATH:= "user://reality/crr_surface_registry.json"
const CRR_REGISTRY_DIRECTORY:= "user://reality"
const CRR_REGISTRY_FILE_NAME:= (
	"crr_surface_registry.json"
)
const CRR_REGISTRY_TEMP_FILE_NAME:= (
	"crr_surface_registry.json.tmp"
)
const CRR_REGISTRY_BACKUP_FILE_NAME:= (
	"crr_surface_registry.json.bak"
)
const MAX_SURFACE_FRAMES:= 24
const MAX_MUTATION_ROWS:= 160

var gs
var surface_registry: Dictionary = {}
var mutation_history: Array = []
var frame_sequence: int = 0
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "crr.apply_mutation":
		return apply_mutation(envelope.get("mutation", envelope), envelope)

	if command_id == "crr.observe_commit":
		return observe_commit_report(
			envelope.get("commit_report", {}) if typeof(envelope.get("commit_report", {})) == TYPE_DICTIONARY else {},
			envelope
		)

	if command_id == "crr.emit_surface":
		return emit_surface(str(envelope.get("surface_id", "")), envelope)

	if command_id == "crr.bind_surface":
		return bind_surface(str(envelope.get("surface_id", "")), envelope)

	if command_id == "crr.emit_registry":
		return emit_surface_registry(envelope)

	if command_id == "crr.publish_frame":
		return publish_frame(envelope)

	return _fail("unknown_crr_command", "CRRContractEngine did not recognize command.", envelope)


func observe_commit_report(commit_report: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if commit_report.is_empty():
		return _fail("empty_commit_report", "CRR cannot observe an empty commit report.", context)

	if not bool(commit_report.get("success", false)):
		return {
			"schema": "eralife.crr.observe_commit_report",
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "commit_not_mutation",
			"reason": "Rejected or blocked intents do not create observable reality.",
			"commit_id": str(commit_report.get("intent_id", "")),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var route_report: Dictionary = _safe_dictionary(context.get("route_report", commit_report.get("route_report", {})))
	var result: Dictionary = _safe_dictionary(route_report.get("result", commit_report.get("result", {})))
	var intent: Dictionary = _safe_dictionary(context.get("intent", {}))

	var mutation: Dictionary = {
		"schema": "eralife.crr.mutation_from_commit",
		"version": CONTRACT_VERSION,
		"mutation_id": "mutation_%s_%d" % [
			str(commit_report.get("intent_id", "unknown")),
			int(Time.get_ticks_msec())
		],
		"commit_id": str(commit_report.get("intent_id", "")),
		"entity_id": _entity_id_from_commit(commit_report, result),
		"surface_id": str(commit_report.get("surface_id", "")),
		"domain": str(commit_report.get("domain", "")),
		"mutation_type": str(commit_report.get("action_id", commit_report.get("intent_type", "mutation"))),
		"truth_state": str(result.get("truth_state", route_report.get("truth_state", "partial"))),
		"confidence": float(result.get("confidence", route_report.get("confidence", 0.72))),
		"payload": {
			"intent": intent.duplicate(true),
			"commit_report": commit_report.duplicate(true),
			"route_report": route_report.duplicate(true),
			"result": result.duplicate(true)
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"source": "GlobalIntentContractEngine"
	}

	return apply_mutation(mutation, context)


func apply_mutation(raw_mutation: Variant, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var mutation: Dictionary = _normalize_mutation(raw_mutation, context)
	if mutation.is_empty():
		return _fail("invalid_mutation", "CRR received a mutation it could not normalize.", context)

	var surface_id: String = _surface_id_for_mutation(mutation)
	var surface: Dictionary = _surface_for_id(surface_id)
	var frame: Dictionary = _frame_from_mutation(surface_id, mutation, context)

	var frames: Array = surface.get("frames", []) if typeof(surface.get("frames", [])) == TYPE_ARRAY else []
	frames.append(frame)
	if frames.size() > MAX_SURFACE_FRAMES:
		frames = frames.slice(frames.size() - MAX_SURFACE_FRAMES, frames.size())

	surface ["surface_id"] = surface_id
	surface ["schema"] = "eralife.crr.surface_contract"
	surface ["version"] = CONTRACT_VERSION
	surface ["truth_state"] = str(frame.get("truth_state", "partial"))
	surface ["confidence"] = float(frame.get("confidence", 0.5))
	surface ["render_state"] = frame.get("render_state", {}) if typeof(frame.get("render_state", {})) == TYPE_DICTIONARY else {}
	surface ["last_frame"] = frame.duplicate(true)
	surface ["frames"] = frames
	surface ["observable"] = true
	surface ["renderable"] = true
	surface ["exists_because_renderable"] = true
	surface ["updated_at_ms"] = int(Time.get_ticks_msec())
	surface ["contract_mesh"] = {
		"source_of_truth": "CRRContractEngine",
		"ui_is_lens": true,
		"ui_mutation_allowed": false
	}

	surface_registry [surface_id] = surface.duplicate(true)

	mutation_history.append(mutation.duplicate(true))
	if mutation_history.size() > MAX_MUTATION_ROWS:
		mutation_history = mutation_history.slice(mutation_history.size() - MAX_MUTATION_ROWS, mutation_history.size())

	last_report = {
		"schema": "eralife.crr.apply_mutation_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "observable_reality_frame_published",
		"surface_id": surface_id,
		"surface": surface.duplicate(true),
		"frame": frame.duplicate(true),
		"mutation": mutation.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "CRRContractEngine",
		}
	}

	_write_registry()
	_commit_state()
	return last_report.duplicate(true)


func publish_frame(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var surface_id: String = str(context.get("surface_id", "")).strip_edges()
	if surface_id == "":
		surface_id = "general_reality_surface"

	var surface: Dictionary = _surface_for_id(surface_id)
	var frame: Dictionary = {
		"schema": "eralife.crr.reality_frame",
		"version": CONTRACT_VERSION,
		"frame_id": _next_frame_id(surface_id),
		"surface_id": surface_id,
		"truth_state": str(context.get("truth_state", surface.get("truth_state", "partial"))),
		"confidence": float(context.get("confidence", surface.get("confidence", 0.5))),
		"render_state": _safe_dictionary(context.get("render_state", surface.get("render_state", {}))),
		"published_at_ms": int(Time.get_ticks_msec())
	}

	var frames: Array = surface.get("frames", []) if typeof(surface.get("frames", [])) == TYPE_ARRAY else []
	frames.append(frame)
	if frames.size() > MAX_SURFACE_FRAMES:
		frames = frames.slice(frames.size() - MAX_SURFACE_FRAMES, frames.size())

	surface ["frames"] = frames
	surface ["last_frame"] = frame.duplicate(true)
	surface ["render_state"] = frame.get("render_state", {})
	surface ["truth_state"] = str(frame.get("truth_state", "partial"))
	surface ["confidence"] = float(frame.get("confidence", 0.5))
	surface ["observable"] = true
	surface ["renderable"] = true
	surface ["updated_at_ms"] = int(Time.get_ticks_msec())

	surface_registry [surface_id] = surface.duplicate(true)
	_write_registry()
	_commit_state()

	return {
		"schema": "eralife.crr.publish_frame_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "reality_frame_published",
		"surface_id": surface_id,
		"surface": surface.duplicate(true),
		"frame": frame.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func emit_surface(surface_id: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_surface_id: String = str(surface_id).strip_edges()
	if clean_surface_id == "":
		clean_surface_id = str(context.get("surface_id", "general_reality_surface")).strip_edges()

	if clean_surface_id == "":
		clean_surface_id = "general_reality_surface"

	var surface: Dictionary = _surface_for_id(clean_surface_id)

	last_report = {
		"schema": "eralife.crr.emit_surface_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "surface_ready",
		"surface_id": clean_surface_id,
		"surface": surface.duplicate(true),
		"surface_contract": surface.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func bind_surface(surface_id: String, context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = emit_surface(surface_id, context)
	report ["mode"] = "surface_bound"
	report ["ui_subscription_allowed"] = true
	report ["ui_is_lens"] = true
	report ["ui_mutation_allowed"] = false
	return report


func emit_surface_registry(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	return {
		"schema": "eralife.crr.surface_registry_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "surface_registry_ready",
		"surfaces": surface_registry.duplicate(true),
		"surface_count": surface_registry.size(),
		"mutation_count": mutation_history.size(),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "CRRContractEngine",
		}
	}


func _normalize_mutation(raw_mutation: Variant, context: Dictionary = {}) -> Dictionary:
	if typeof(raw_mutation) != TYPE_DICTIONARY:
		return {}

	var mutation: Dictionary = (raw_mutation as Dictionary).duplicate(true)
	var mutation_id: String = str(mutation.get("mutation_id", mutation.get("id", ""))).strip_edges()

	if mutation_id == "":
		mutation_id = "mutation_%d_%d" % [mutation_history.size() + 1, int(Time.get_ticks_msec())]

	mutation ["schema"] = str(mutation.get("schema", "eralife.crr.mutation"))
	mutation ["version"] = int(mutation.get("version", CONTRACT_VERSION))
	mutation ["mutation_id"] = mutation_id
	mutation ["id"] = mutation_id
	mutation ["entity_id"] = str(mutation.get("entity_id", context.get("entity_id", "world"))).strip_edges()
	mutation ["surface_id"] = str(mutation.get("surface_id", context.get("surface_id", ""))).strip_edges()
	mutation ["domain"] = str(mutation.get("domain", context.get("domain", ""))).strip_edges()
	mutation ["mutation_type"] = str(mutation.get("mutation_type", mutation.get("type", context.get("mutation_type", "mutation")))).strip_edges()
	mutation ["truth_state"] = _truth_state_for_mutation(mutation, context)
	mutation ["confidence"] = clamp(float(mutation.get("confidence", context.get("confidence", 0.62))), 0.0, 1.0)

	if typeof(mutation.get("payload", {})) != TYPE_DICTIONARY:
		mutation ["payload"] = {}
	else:
		mutation ["payload"] = (mutation.get("payload", {}) as Dictionary).duplicate(true)

	mutation ["created_at_ms"] = int(mutation.get("created_at_ms", Time.get_ticks_msec()))
	mutation ["crr_observable_required"] = true
	return mutation


func _frame_from_mutation(surface_id: String, mutation: Dictionary, context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.crr.reality_frame",
		"version": CONTRACT_VERSION,
		"frame_id": _next_frame_id(surface_id),
		"surface_id": surface_id,
		"mutation_id": str(mutation.get("mutation_id", "")),
		"entity_id": str(mutation.get("entity_id", "world")),
		"mutation_type": str(mutation.get("mutation_type", "mutation")),
		"truth_state": str(mutation.get("truth_state", "partial")),
		"confidence": float(mutation.get("confidence", 0.62)),
		"render_state": _render_state_from_mutation(mutation, context),
		"source": str(mutation.get("source", context.get("source", "unknown"))),
		"published_at_ms": int(Time.get_ticks_msec()),
	}


func _render_state_from_mutation(mutation: Dictionary, context: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = _safe_dictionary(mutation.get("payload", {}))
	var result: Dictionary = _safe_dictionary(payload.get("result", {}))
	var route_report: Dictionary = _safe_dictionary(payload.get("route_report", {}))

	if typeof(result.get("render_state", {})) == TYPE_DICTIONARY:
		return (result.get("render_state", {}) as Dictionary).duplicate(true)

	if typeof(route_report.get("surface_contract", {})) == TYPE_DICTIONARY:
		return (route_report.get("surface_contract", {}) as Dictionary).duplicate(true)

	if typeof(result.get("surface_contract", {})) == TYPE_DICTIONARY:
		return (result.get("surface_contract", {}) as Dictionary).duplicate(true)

	return {
		"schema": "eralife.crr.generic_render_state",
		"version": CONTRACT_VERSION,
		"entity_id": str(mutation.get("entity_id", "world")),
		"mutation_type": str(mutation.get("mutation_type", "mutation")),
		"domain": str(mutation.get("domain", "")),
		"truth_state": str(mutation.get("truth_state", "partial")),
		"confidence": float(mutation.get("confidence", 0.62)),
		"summary": str(result.get("message", result.get("reason", result.get("mode", mutation.get("mutation_type", "Reality changed."))))),
		"payload_keys": payload.keys(),
		"context": context.duplicate(true),
		"renderable": true
	}


func _surface_id_for_mutation(mutation: Dictionary) -> String:
	var explicit_surface: String = str(mutation.get("surface_id", "")).strip_edges()
	if explicit_surface != "":
		return explicit_surface

	var domain: String = str(mutation.get("domain", "")).strip_edges().to_lower()
	var mutation_type: String = str(mutation.get("mutation_type", "")).strip_edges().to_lower()

	if domain.find("battle") != -1 or mutation_type.find("battle") != -1:
		return "battle_surface"

	if domain.find("war") != -1 or mutation_type.find("war") != -1:
		return "war_surface"

	if domain.find("military") != -1 or mutation_type.find("military") != -1:
		return "military_surface"

	if domain.find("relationship") != -1 or mutation_type.find("relationship") != -1:
		return "relationship_surface"

	if domain.find("population") != -1 or mutation_type.find("population") != -1:
		return "population_surface"

	if domain.find("self_host") != -1 or mutation_type.find("self_host") != -1:
		return "self_host_surface"

	if domain.find("mailbox") != -1 or domain.find("reality_intake") != -1:
		return "reality_intake_surface"

	if domain.find("world") != -1:
		return "world_surface"

	if domain.find("life") != -1:
		return "life_surface"

	return "general_reality_surface"


func _surface_for_id(surface_id: String) -> Dictionary:
	var clean_surface_id: String = str(surface_id).strip_edges()
	if clean_surface_id == "":
		clean_surface_id = "general_reality_surface"

	if surface_registry.has(clean_surface_id):
		var existing: Dictionary = _safe_dictionary(surface_registry.get(clean_surface_id, {}))
		if not existing.is_empty():
			return existing

	return {
		"schema": "eralife.crr.surface_contract",
		"version": CONTRACT_VERSION,
		"surface_id": clean_surface_id,
		"truth_state": "predicted",
		"confidence": 0.25,
		"render_state": {
			"schema": "eralife.crr.placeholder_render_state",
			"version": CONTRACT_VERSION,
			"surface_id": clean_surface_id,
			"message": "Observable surface prepared.",
			"renderable": true
		},
		"frames": [],
		"last_frame": {},
		"observable": true,
		"renderable": true,
		"exists_because_renderable": true,
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "CRRContractEngine",
			"ui_is_lens": true
		}
	}


func _entity_id_from_commit(commit_report: Dictionary, result: Dictionary = {}) -> String:
	var result_entity: String = str(result.get("entity_id", result.get("actor_id", ""))).strip_edges()
	if result_entity != "":
		return result_entity

	var target_id: int = int(commit_report.get("target_id", -1))
	if target_id > 0:
		return "person_%d" % target_id

	var actor_id: int = int(commit_report.get("actor_id", -1))
	if actor_id > 0:
		return "person_%d" % actor_id

	return "world"


func _truth_state_for_mutation(mutation: Dictionary, context: Dictionary = {}) -> String:
	var raw: String = str(mutation.get("truth_state", context.get("truth_state", ""))).strip_edges().to_lower()

	if raw in ["partial", "resolved", "predicted"]:
		return raw

	if bool(context.get("predicted", false)):
		return "predicted"

	if bool(context.get("resolved", false)):
		return "resolved"

	return "partial"


func _next_frame_id(surface_id: String) -> String:
	frame_sequence += 1
	return "crr_frame_%s_%d_%d" % [
		str(surface_id).strip_edges().replace(" ", "_"),
		frame_sequence,
		int(Time.get_ticks_msec())
	]


func _ensure_state() -> void:
	surface_registry = {}
	mutation_history = []
	frame_sequence = 0

	var loaded: Dictionary = _read_registry()
	surface_registry = _safe_dictionary(loaded.get("surfaces", {}))
	mutation_history = loaded.get("mutation_history", []) if typeof(loaded.get("mutation_history", [])) == TYPE_ARRAY else []
	frame_sequence = int(loaded.get("frame_sequence", 0))

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_surfaces: Dictionary = _safe_dictionary(gs.scenario_state.get("crr_surface_registry", {}))
		if not scenario_surfaces.is_empty():
			surface_registry = scenario_surfaces

		var scenario_mutations: Array = gs.scenario_state.get("crr_mutation_history", []) if typeof(gs.scenario_state.get("crr_mutation_history", [])) == TYPE_ARRAY else []
		if not scenario_mutations.is_empty():
			mutation_history = scenario_mutations

		frame_sequence = max(frame_sequence, int(gs.scenario_state.get("crr_frame_sequence", frame_sequence)))

	_commit_state()


func _read_registry() -> Dictionary:
	_ensure_reality_dir()

	var primary_report: Dictionary = (
		_read_registry_file(
			CRR_REGISTRY_PATH
		)
	)

	if bool(
		primary_report.get(
			"valid",
			false
		)
	):
		return _safe_dictionary(
			primary_report.get(
				"data",
				_default_registry()
			)
		)

	var backup_path: String = (
		"%s/%s"
		% [
			CRR_REGISTRY_DIRECTORY,
			CRR_REGISTRY_BACKUP_FILE_NAME
		]
	)
	var backup_report: Dictionary = (
		_read_registry_file(
			backup_path
		)
	)

	if bool(
		backup_report.get(
			"valid",
			false
		)
	):
		last_report = {
			"success": true,
			"mode": (
				"crr_registry_recovered_from_backup"
			),
			"primary_failure": (
				primary_report.duplicate(true)
			),
			"recovered_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		return _safe_dictionary(
			backup_report.get(
				"data",
				_default_registry()
			)
		)

	if FileAccess.file_exists(
		CRR_REGISTRY_PATH
	):
		_quarantine_corrupt_registry()

	last_report = {
		"success": true,
		"mode": (
			"crr_registry_reset_after_invalid_json"
		),
		"primary_failure": (
			primary_report.duplicate(true)
		),
		"backup_failure": (
			backup_report.duplicate(true)
		),
		"reset_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return _default_registry()


func _write_registry() -> void:
	_ensure_reality_dir()

	var registry: Dictionary = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"surfaces": surface_registry.duplicate(true),
		"mutation_history": mutation_history.duplicate(true),
		"frame_sequence": frame_sequence,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	var encoded: String = JSON.stringify(
		registry,
		"\t"
	)
	var temporary_path: String = (
		"%s/%s"
		% [
			CRR_REGISTRY_DIRECTORY,
			CRR_REGISTRY_TEMP_FILE_NAME
		]
	)
	var temporary_file:= FileAccess.open(
		temporary_path,
		FileAccess.WRITE
	)

	if temporary_file == null:
		last_report = {
			"success": false,
			"reason": (
				"crr_registry_temp_open_failed"
			)
		}
		return

	temporary_file.store_string(
		encoded
	)
	temporary_file.flush()
	temporary_file.close()

	var validation: Dictionary = (
		_read_registry_file(
			temporary_path
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		var cleanup_dir:= DirAccess.open(
			CRR_REGISTRY_DIRECTORY
		)

		if cleanup_dir != null:
			cleanup_dir.remove(
				CRR_REGISTRY_TEMP_FILE_NAME
			)

		last_report = {
			"success": false,
			"reason": (
				"crr_registry_temp_validation_failed"
			),
			"validation": validation.duplicate(true)
		}
		return

	var registry_dir:= DirAccess.open(
		CRR_REGISTRY_DIRECTORY
	)

	if registry_dir == null:
		last_report = {
			"success": false,
			"reason": (
				"crr_registry_directory_unavailable"
			)
		}
		return

	if registry_dir.file_exists(
		CRR_REGISTRY_BACKUP_FILE_NAME
	):
		registry_dir.remove(
			CRR_REGISTRY_BACKUP_FILE_NAME
		)

	if registry_dir.file_exists(
		CRR_REGISTRY_FILE_NAME
	):
		var backup_error: Error = (
			registry_dir.rename(
				CRR_REGISTRY_FILE_NAME,
				CRR_REGISTRY_BACKUP_FILE_NAME
			)
		)

		if backup_error != OK:
			registry_dir.remove(
				CRR_REGISTRY_TEMP_FILE_NAME
			)

			last_report = {
				"success": false,
				"reason": (
					"crr_registry_backup_rotation_failed"
				),
				"error": int(
					backup_error
				)
			}
			return

	var promote_error: Error = registry_dir.rename(
		CRR_REGISTRY_TEMP_FILE_NAME,
		CRR_REGISTRY_FILE_NAME
	)

	if promote_error != OK:
		if registry_dir.file_exists(
			CRR_REGISTRY_BACKUP_FILE_NAME
		):
			registry_dir.rename(
				CRR_REGISTRY_BACKUP_FILE_NAME,
				CRR_REGISTRY_FILE_NAME
			)

		last_report = {
			"success": false,
			"reason": (
				"crr_registry_atomic_promote_failed"
			),
			"error": int(
				promote_error
			)
		}
		return

	last_report = {
		"success": true,
		"mode": "crr_registry_atomic_commit",
		"frame_sequence": frame_sequence,
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _read_registry_file(
	path: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"valid": false,
			"reason": "registry_file_missing",
			"path": path
		}

	var file:= FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return {
			"valid": false,
			"reason": "registry_file_open_failed",
			"path": path
		}

	var raw_text: String = file.get_as_text()
	file.close()

	if raw_text.strip_edges() == "":
		return {
			"valid": false,
			"reason": "registry_file_empty",
			"path": path
		}

	var parser:= JSON.new()
	var parse_error: Error = parser.parse(
		raw_text
	)

	if parse_error != OK:
		return {
			"valid": false,
			"reason": "registry_json_invalid",
			"path": path,
			"error": int(
				parse_error
			),
			"error_line": (
				parser.get_error_line()
			),
			"error_message": (
				parser.get_error_message()
			)
		}

	if typeof(
		parser.data
	) != TYPE_DICTIONARY:
		return {
			"valid": false,
			"reason": (
				"registry_root_is_not_dictionary"
			),
			"path": path
		}

	var data: Dictionary = (
		(parser.data as Dictionary).duplicate(true)
	)

	if typeof(
		data.get(
			"surfaces",
			{}
		)
	) != TYPE_DICTIONARY:
		data ["surfaces"] = {}

	if typeof(
		data.get(
			"mutation_history",
			[]
		)
	) != TYPE_ARRAY:
		data ["mutation_history"] = []

	data ["schema"] = str(
		data.get(
			"schema",
			ENGINE_SCHEMA
		)
	)
	data ["version"] = int(
		data.get(
			"version",
			CONTRACT_VERSION
		)
	)
	data ["frame_sequence"] = maxi(
		0,
		int(
			data.get(
				"frame_sequence",
				0
			)
		)
	)

	return {
		"valid": true,
		"path": path,
		"data": data
	}


func _default_registry() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"surfaces": {},
		"mutation_history": [],
		"frame_sequence": 0
	}


func _quarantine_corrupt_registry() -> void:
	var registry_dir:= DirAccess.open(
		CRR_REGISTRY_DIRECTORY
	)

	if registry_dir == null:
		return

	if not registry_dir.file_exists(
		CRR_REGISTRY_FILE_NAME
	):
		return

	var quarantine_name: String = (
		"crr_surface_registry.corrupt.%d.json"
		% int(
			Time.get_unix_time_from_system()
		)
	)

	registry_dir.rename(
		CRR_REGISTRY_FILE_NAME,
		quarantine_name
	)

func _ensure_reality_dir() -> void:
	var root_dir:= DirAccess.open("user://")
	if root_dir != null and not root_dir.dir_exists("reality"):
		root_dir.make_dir("reality")


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["crr_surface_registry"] = surface_registry.duplicate(true)
	gs.scenario_state ["crr_mutation_history"] = mutation_history.duplicate(true)
	gs.scenario_state ["crr_frame_sequence"] = frame_sequence
	gs.scenario_state ["last_crr_report"] = last_report.duplicate(true)
	gs.scenario_state ["continuous_reality_rendering_law"] = {
		"schema": "eralife.crr.law",
		"version": CONTRACT_VERSION,
		"ui_is_lens": true,
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.crr.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)