extends Resource
class_name MilitaryContractEngine

const ENGINE_SCHEMA:= "eralife.military_contract_engine"
const CONTRACT_VERSION:= 1
const MILITARY_REGISTRY_PATH:= "user://war/military_registry.json"

var gs
var military_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "military.emit_surface" or command_id == "military.emit_registry":
		return emit_military_registry_contract(envelope)

	if command_id == "military.create_army":
		return create_army_contract(envelope)

	if command_id == "military.create_demo_armies":
		return create_demo_armies(envelope)

	return _fail("unknown_military_command", "MilitaryContractEngine did not recognize command.", envelope)


func emit_military_registry_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var armies: Dictionary = _safe_dictionary(military_registry.get("armies", {}))
	var army_list: Array = []

	for raw_key in armies.keys():
		var army: Dictionary = _safe_dictionary(armies.get(raw_key, {}))
		if not army.is_empty():
			army_list.append(army)

	army_list.sort_custom(Callable(self, "_sort_armies_by_updated"))

	last_report = {
		"schema": "eralife.military.registry_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "military_registry_ready",
		"armies": army_list,
		"army_count": army_list.size(),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "MilitaryContractEngine",
			"ui_mutation_allowed": false
		}
	}

	_commit_state()
	return last_report.duplicate(true)


func create_army_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var faction_id: String = str(context.get("faction_id", "neutral_faction")).strip_edges()
	var army_name: String = str(context.get("army_name", "%s Army" % faction_id)).strip_edges()
	var commander_id: int = int(context.get("commander_person_id", 0))
	var army_id: String = str(context.get("army_id", "")).strip_edges()

	if army_id == "":
		army_id = "army_%s_%d" % [faction_id.to_lower().replace(" ", "_"), int(Time.get_ticks_msec())]

	var units: Array = []
	if typeof(context.get("units", [])) == TYPE_ARRAY:
		for raw_unit in context.get("units", []):
			if typeof(raw_unit) == TYPE_DICTIONARY:
				units.append(_normalize_unit(raw_unit as Dictionary, army_id, units.size()))

	if units.is_empty():
		units = _default_units_for_army(army_id, faction_id)

	var army: Dictionary = {
		"schema": "eralife.military.army_contract",
		"version": CONTRACT_VERSION,
		"army_id": army_id,
		"army_name": army_name,
		"faction_id": faction_id,
		"commander_person_id": commander_id,
		"command_hierarchy": {
			"commander_person_id": commander_id,
			"delegation": [],
			"command_latency_ms": int(context.get("command_latency_ms", 260))
		},
		"units": units,
		"morale": float(context.get("morale", 0.72)),
		"supply": float(context.get("supply", 0.78)),
		"loyalty": float(context.get("loyalty", 0.7)),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	var armies: Dictionary = _safe_dictionary(military_registry.get("armies", {}))
	armies [army_id] = army.duplicate(true)
	military_registry ["armies"] = armies
	military_registry ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_registry()

	last_report = {
		"schema": "eralife.military.create_army_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "army_created",
		"army": army.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func create_demo_armies(context: Dictionary = {}) -> Dictionary:
	var side_a_report: Dictionary = create_army_contract({
		"army_id": str(context.get("side_a_army_id", "army_sunspire")),
		"army_name": str(context.get("side_a_army_name", "Sunspire Vanguard")),
		"faction_id": str(context.get("side_a_faction_id", "sunspire")),
		"commander_person_id": int(context.get("side_a_commander_person_id", 0)),
		"morale": 0.78,
		"supply": 0.74,
		"loyalty": 0.82
	})

	var side_b_report: Dictionary = create_army_contract({
		"army_id": str(context.get("side_b_army_id", "army_blackvale")),
		"army_name": str(context.get("side_b_army_name", "Blackvale Host")),
		"faction_id": str(context.get("side_b_faction_id", "blackvale")),
		"commander_person_id": int(context.get("side_b_commander_person_id", 0)),
		"morale": 0.7,
		"supply": 0.68,
		"loyalty": 0.76
	})

	return {
		"schema": "eralife.military.demo_armies_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "demo_armies_created",
		"side_a": side_a_report.get("army", {}),
		"side_b": side_b_report.get("army", {}),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func get_army(army_id: String) -> Dictionary:
	_ensure_state()
	var armies: Dictionary = _safe_dictionary(military_registry.get("armies", {}))
	return _safe_dictionary(armies.get(army_id, {}))


func _normalize_unit(raw_unit: Dictionary, army_id: String, index: int) -> Dictionary:
	var unit_type: String = str(raw_unit.get("unit_type", raw_unit.get("type", "infantry"))).strip_edges().to_lower()
	var unit_id: String = str(raw_unit.get("unit_id", "")).strip_edges()

	if unit_id == "":
		unit_id = "%s_%s_%02d" % [army_id, unit_type, index]

	return {
		"schema": "eralife.military.unit_contract",
		"version": CONTRACT_VERSION,
		"unit_id": unit_id,
		"army_id": army_id,
		"unit_type": unit_type,
		"display_name": str(raw_unit.get("display_name", unit_type.capitalize())),
		"count": int(raw_unit.get("count", 100)),
		"morale": float(raw_unit.get("morale", 0.7)),
		"discipline": float(raw_unit.get("discipline", 0.62)),
		"cohesion": float(raw_unit.get("cohesion", 0.68)),
		"fear": float(raw_unit.get("fear", 0.18)),
		"fatigue": float(raw_unit.get("fatigue", 0.0)),
		"supply": float(raw_unit.get("supply", 0.75)),
		"loyalty": float(raw_unit.get("loyalty", 0.7)),
		"formation_bias": str(raw_unit.get("formation_bias", "line")),
		"decision_latency_ms": int(raw_unit.get("decision_latency_ms", 220 + (index * 35))),
		"intent_vector": _vector_dict(raw_unit.get("intent_vector", { "x": 0.0, "y": 0.0})),
		"position": _vector_dict(raw_unit.get("position", { "x": float(index) * 70.0, "y": 0.0})),
		"velocity": _vector_dict(raw_unit.get("velocity", { "x": 0.0, "y": 0.0})),
		"state": str(raw_unit.get("state", "holding"))
	}


func _default_units_for_army(army_id: String, faction_id: String) -> Array:
	var side_offset: float = -220.0 if faction_id.to_lower().find("sun") != -1 else 220.0
	return [
		_normalize_unit({ "unit_type": "infantry", "display_name": "Infantry Line", "count": 220, "position": { "x": side_offset, "y": -60.0}}, army_id, 0),
		_normalize_unit({ "unit_type": "archers", "display_name": "Archer Wing", "count": 120, "position": { "x": side_offset * 1.08, "y": -130.0}}, army_id, 1),
		_normalize_unit({ "unit_type": "cavalry", "display_name": "Cavalry Wing", "count": 80, "position": { "x": side_offset, "y": 65.0}}, army_id, 2),
		_normalize_unit({ "unit_type": "specialists", "display_name": "Specialists", "count": 32, "position": { "x": side_offset * 0.92, "y": 138.0}}, army_id, 3)
	]


func _vector_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_VECTOR2:
		var vector_value: Vector2 = value as Vector2
		return { "x": vector_value.x, "y": vector_value.y}
	if typeof(value) == TYPE_DICTIONARY:
		var raw: Dictionary = value as Dictionary
		return { "x": float(raw.get("x", 0.0)), "y": float(raw.get("y", 0.0))}
	return { "x": 0.0, "y": 0.0}


func _ensure_state() -> void:
	military_registry = _read_registry()
	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(MILITARY_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "armies": {}}

	var file:= FileAccess.open(MILITARY_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "armies": {}}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("armies", {})) != TYPE_DICTIONARY:
			data ["armies"] = {}
		return data

	return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "armies": {}}


func _write_registry() -> void:
	_ensure_war_dir()
	var file:= FileAccess.open(MILITARY_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(military_registry, "\t"))
	file.close()


func _ensure_war_dir() -> void:
	var root_dir:= DirAccess.open("user://")
	if root_dir != null and not root_dir.dir_exists("war"):
		root_dir.make_dir("war")


func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["military_registry"] = military_registry.duplicate(true)
	gs.scenario_state ["last_military_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _sort_armies_by_updated(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.military.error",
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