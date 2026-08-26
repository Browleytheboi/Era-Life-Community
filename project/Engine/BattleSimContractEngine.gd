extends Resource
class_name BattleSimContractEngine

const ENGINE_SCHEMA:= "eralife.battle_sim_contract_engine"
const CONTRACT_VERSION:= 1
const BATTLE_SIM_REGISTRY_PATH:= "user://war/battle_sim_registry.json"

var gs
var battle_sim_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "battle_sim.emit_snapshot":
		return emit_battle_snapshot(str(envelope.get("battle_id", "")), envelope)

	if command_id == "battle_sim.tick":
		return advance_battle_tick(str(envelope.get("battle_id", "")), int(envelope.get("delta_ms", 250)), envelope)

	if command_id == "battle_sim.apply_intent":
		return apply_commander_intent(str(envelope.get("battle_id", "")), envelope)

	return _fail("unknown_battle_sim_command", "BattleSimContractEngine did not recognize command.", envelope)


func seed_battle_simulation(battle_contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battle_id: String = str(battle_contract.get("battle_id", "")).strip_edges()
	if battle_id == "":
		return _fail("battle_missing", "Battle id is required to seed simulation.", context)

	var sim_units: Array = []
	var armies: Array = battle_contract.get("armies", []) if typeof(battle_contract.get("armies", [])) == TYPE_ARRAY else []

	for army_index in range(armies.size()):
		var army: Dictionary = _safe_dictionary(armies [army_index])
		var units: Array = army.get("units", []) if typeof(army.get("units", [])) == TYPE_ARRAY else []
		var side_sign: float = -1.0 if army_index == 0 else 1.0

		for unit_index in range(units.size()):
			var unit: Dictionary = _safe_dictionary(units [unit_index])
			var seeded_unit: Dictionary = _seed_sim_unit(unit, army, side_sign, unit_index)
			sim_units.append(seeded_unit)

	var battle_state: Dictionary = {
		"schema": "eralife.battle_sim.state",
		"version": CONTRACT_VERSION,
		"battle_id": battle_id,
		"terrain": str(battle_contract.get("terrain", "plains")),
		"weather": str(battle_contract.get("weather", "clear")),
		"engagement_type": str(battle_contract.get("engagement_type", "open_field")),
		"tick_index": 0,
		"elapsed_ms": 0,
		"units": sim_units,
		"engagement_edges": [],
		"pressure_edges": [],
		"commander_intents": _safe_dictionary(battle_contract.get("commander_intents", {})),
		"state": "running",
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"movement_model": {
			"formula": "movement = intent + pressure + cohesion + fear + delay",
		}
	}

	var battles: Dictionary = _safe_dictionary(battle_sim_registry.get("battles", {}))
	battles [battle_id] = battle_state.duplicate(true)
	battle_sim_registry ["battles"] = battles
	battle_sim_registry ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_registry()

	last_report = {
		"schema": "eralife.battle_sim.seed_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_sim_seeded",
		"battle_state": battle_state.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func apply_commander_intent(battle_id: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battle_state: Dictionary = _battle_state(battle_id)
	if battle_state.is_empty():
		return _fail("battle_missing", "Battle simulation was not found.", context)

	var army_id: String = str(context.get("army_id", "")).strip_edges()
	var intent: String = str(context.get("intent", "hold")).strip_edges().to_lower()

	var commander_intents: Dictionary = _safe_dictionary(battle_state.get("commander_intents", {}))
	commander_intents [army_id] = {
		"intent": intent,
		"issued_at_ms": int(Time.get_ticks_msec()),
		"influence_field": _intent_field(intent),
		"source": str(context.get("source", "unknown"))
	}

	battle_state ["commander_intents"] = commander_intents
	battle_state ["updated_at_ms"] = int(Time.get_ticks_msec())
	_save_battle_state(battle_id, battle_state)

	last_report = {
		"schema": "eralife.battle_sim.intent_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "commander_intent_applied",
		"battle_id": battle_id,
		"army_id": army_id,
		"intent": intent,
		"battle_state": battle_state.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)


func advance_battle_tick(battle_id: String, delta_ms: int = 250, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battle_state: Dictionary = _battle_state(battle_id)
	if battle_state.is_empty():
		return _fail("battle_missing", "Battle simulation was not found.", context)

	var units: Array = battle_state.get("units", []) if typeof(battle_state.get("units", [])) == TYPE_ARRAY else []
	var next_units: Array = []
	var engagement_edges: Array = []
	var pressure_edges: Array = []
	var delta_seconds: float = max(0.016, float(delta_ms) / 1000.0)

	for raw_unit in units:
		var unit: Dictionary = _safe_dictionary(raw_unit)
		var next_unit: Dictionary = _advance_unit(unit, units, battle_state, delta_seconds, engagement_edges, pressure_edges)
		next_units.append(next_unit)

	battle_state ["units"] = next_units
	battle_state ["engagement_edges"] = engagement_edges
	battle_state ["pressure_edges"] = pressure_edges
	battle_state ["tick_index"] = int(battle_state.get("tick_index", 0)) + 1
	battle_state ["elapsed_ms"] = int(battle_state.get("elapsed_ms", 0)) + delta_ms
	battle_state ["updated_at_ms"] = int(Time.get_ticks_msec())

	_save_battle_state(battle_id, battle_state)

	last_report = {
		"schema": "eralife.battle_sim.tick_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_tick_resolved",
		"battle_id": battle_id,
		"delta_ms": delta_ms,
		"snapshot": _snapshot_from_state(battle_state),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)


func emit_battle_snapshot(battle_id: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battle_state: Dictionary = _battle_state(battle_id)
	if battle_state.is_empty():
		return _fail("battle_missing", "Battle simulation was not found.", context)

	last_report = {
		"schema": "eralife.battle_sim.snapshot_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_snapshot_ready",
		"battle_id": battle_id,
		"snapshot": _snapshot_from_state(battle_state),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "BattleSimContractEngine",
			"movement_formula": "intent + pressure + cohesion + fear + delay"
		}
	}

	return last_report.duplicate(true)


func _advance_unit(unit: Dictionary, all_units: Array, battle_state: Dictionary, delta_seconds: float, engagement_edges: Array, pressure_edges: Array) -> Dictionary:
	var next_unit: Dictionary = unit.duplicate(true)
	var unit_id: String = str(unit.get("unit_id", ""))
	var army_id: String = str(unit.get("army_id", ""))
	var position: Vector2 = _dict_to_vector(unit.get("position", {}))
	var velocity: Vector2 = _dict_to_vector(unit.get("velocity", {}))
	var morale: float = clamp(float(unit.get("morale", 0.7)), 0.0, 1.0)
	var discipline: float = clamp(float(unit.get("discipline", 0.62)), 0.0, 1.0)
	var cohesion: float = clamp(float(unit.get("cohesion", 0.68)), 0.0, 1.0)
	var fear: float = clamp(float(unit.get("fear", 0.18)), 0.0, 1.0)

	var commander_intents: Dictionary = _safe_dictionary(battle_state.get("commander_intents", {}))
	var intent_contract: Dictionary = _safe_dictionary(commander_intents.get(army_id, {}))
	var intent_field: Vector2 = _dict_to_vector(intent_contract.get("influence_field", _intent_field("hold")))

	var attraction: Vector2 = intent_field * (62.0 + discipline * 42.0)
	var repulsion: Vector2 = Vector2.ZERO
	var cohesion_force: Vector2 = Vector2.ZERO
	var engagement_pressure: float = 0.0
	var nearby_allies: int = 0

	for raw_other in all_units:
		var other: Dictionary = _safe_dictionary(raw_other)
		var other_id: String = str(other.get("unit_id", ""))
		if other_id == "" or other_id == unit_id:
			continue

		var other_position: Vector2 = _dict_to_vector(other.get("position", {}))
		var offset: Vector2 = other_position - position
		var distance: float = max(1.0, offset.length())
		var same_army: bool = str(other.get("army_id", "")) == army_id

		if same_army and distance < 180.0:
			cohesion_force += offset.normalized() * ((180.0 - distance) / 180.0) * cohesion * 32.0
			nearby_allies += 1
			pressure_edges.append(_edge(unit_id, other_id, "ally_cohesion", cohesion, Color(0.48, 1.0, 0.62, 1.0)))
		elif not same_army and distance < 210.0:
			var pressure: float = (210.0 - distance) / 210.0
			engagement_pressure += pressure
			repulsion -= offset.normalized() * pressure * (fear * 82.0)
			attraction += offset.normalized() * pressure * max(0.0, morale - fear) * 46.0
			engagement_edges.append(_edge(unit_id, other_id, "engaged", pressure, Color(1.0, 0.2, 0.16, 1.0)))

	var terrain_bias: Vector2 = _terrain_bias(str(battle_state.get("terrain", "plains")), position)
	var delay_ratio: float = clamp(float(int(unit.get("decision_latency_ms", 220))) / 800.0, 0.08, 0.9)
	var force: Vector2 = attraction + repulsion + cohesion_force + terrain_bias
	var target_velocity: Vector2 = force * (1.0 - delay_ratio)

	velocity = velocity.lerp(target_velocity, clamp(delta_seconds * (1.2 + discipline), 0.0, 1.0))
	position += velocity * delta_seconds

	var morale_loss: float = engagement_pressure * (0.01 + fear * 0.018)
	var morale_gain: float = float(nearby_allies) * 0.0015 * cohesion
	morale = clamp(morale - morale_loss + morale_gain, 0.0, 1.0)
	fear = clamp(fear + engagement_pressure * 0.006 - discipline * 0.002, 0.0, 1.0)

	var state: String = "advancing"
	if morale < 0.18:
		state = "routing"
	elif engagement_pressure > 0.35:
		state = "engaged"
	elif velocity.length() < 5.0:
		state = "holding"

	next_unit ["position"] = _vector_dict(position)
	next_unit ["velocity"] = _vector_dict(velocity)
	next_unit ["morale"] = morale
	next_unit ["fear"] = fear
	next_unit ["state"] = state
	next_unit ["engagement_pressure"] = engagement_pressure
	next_unit ["movement_explanation"] = {
		"intent": _vector_dict(attraction),
		"pressure": _vector_dict(repulsion),
		"cohesion": _vector_dict(cohesion_force),
		"fear": fear,
		"delay_ratio": delay_ratio
	}

	return next_unit


func _seed_sim_unit(unit: Dictionary, army: Dictionary, side_sign: float, unit_index: int) -> Dictionary:
	var seeded: Dictionary = unit.duplicate(true)
	var base_position: Vector2 = _dict_to_vector(unit.get("position", {}))

	if base_position == Vector2.ZERO:
		base_position = Vector2(side_sign * 220.0, float(unit_index - 1) * 74.0)

	seeded ["army_id"] = str(army.get("army_id", seeded.get("army_id", "")))
	seeded ["faction_id"] = str(army.get("faction_id", ""))
	seeded ["position"] = _vector_dict(base_position)
	seeded ["velocity"] = { "x": 0.0, "y": 0.0}
	seeded ["intent_vector"] = _intent_field("advance" if side_sign < 0.0 else "hold")
	seeded ["state"] = "forming"
	seeded ["engagement_pressure"] = 0.0
	return seeded


func _intent_field(intent: String) -> Dictionary:
	match str(intent).strip_edges().to_lower():
		"advance":
			return { "x": 1.0, "y": 0.0}
		"flank_left":
			return { "x": 0.72, "y": -0.68}
		"flank_right":
			return { "x": 0.72, "y": 0.68}
		"retreat":
			return { "x": -1.0, "y": 0.0}
		"target_archers":
			return { "x": 0.85, "y": -0.28}
		"hold":
			return { "x": 0.0, "y": 0.0}
		_:
			return { "x": 0.0, "y": 0.0}


func _terrain_bias(terrain: String, position: Vector2) -> Vector2:
	match terrain.strip_edges().to_lower():
		"forest":
			return Vector2(- position.y * 0.012, position.x * 0.004)
		"city":
			return Vector2(- position.x * 0.006, - position.y * 0.006)
		"hill":
			return Vector2(0.0, -10.0)
		_:
			return Vector2.ZERO


func _snapshot_from_state(battle_state: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.battle_sim.snapshot",
		"version": CONTRACT_VERSION,
		"battle_id": str(battle_state.get("battle_id", "")),
		"tick_index": int(battle_state.get("tick_index", 0)),
		"elapsed_ms": int(battle_state.get("elapsed_ms", 0)),
		"terrain": str(battle_state.get("terrain", "plains")),
		"weather": str(battle_state.get("weather", "clear")),
		"units": battle_state.get("units", []) if typeof(battle_state.get("units", [])) == TYPE_ARRAY else [],
		"engagement_edges": battle_state.get("engagement_edges", []) if typeof(battle_state.get("engagement_edges", [])) == TYPE_ARRAY else [],
		"pressure_edges": battle_state.get("pressure_edges", []) if typeof(battle_state.get("pressure_edges", [])) == TYPE_ARRAY else [],
		"movement_model": battle_state.get("movement_model", {}) if typeof(battle_state.get("movement_model", {})) == TYPE_DICTIONARY else {}
	}


func _edge(from_id: String, to_id: String, edge_type: String, intensity: float, color: Color) -> Dictionary:
	return {
		"from": from_id,
		"to": to_id,
		"type": edge_type,
		"intensity": clamp(intensity, 0.0, 1.0),
		"pulse": true,
		"color": { "r": color.r, "g": color.g, "b": color.b, "a": color.a}
	}


func _battle_state(battle_id: String) -> Dictionary:
	var battles: Dictionary = _safe_dictionary(battle_sim_registry.get("battles", {}))
	return _safe_dictionary(battles.get(battle_id, {}))


func _save_battle_state(battle_id: String, battle_state: Dictionary) -> void:
	var battles: Dictionary = _safe_dictionary(battle_sim_registry.get("battles", {}))
	battles [battle_id] = battle_state.duplicate(true)
	battle_sim_registry ["battles"] = battles
	battle_sim_registry ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_registry()
	_commit_state()


func _dict_to_vector(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_DICTIONARY:
		var raw: Dictionary = value as Dictionary
		return Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
	return Vector2.ZERO


func _vector_dict(vector_value: Vector2) -> Dictionary:
	return { "x": vector_value.x, "y": vector_value.y}


func _ensure_state() -> void:
	battle_sim_registry = _read_registry()
	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(BATTLE_SIM_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "battles": {}}

	var file:= FileAccess.open(BATTLE_SIM_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "battles": {}}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("battles", {})) != TYPE_DICTIONARY:
			data ["battles"] = {}
		return data

	return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "battles": {}}


func _write_registry() -> void:
	_ensure_war_dir()
	var file:= FileAccess.open(BATTLE_SIM_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(battle_sim_registry, "\t"))
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
	gs.scenario_state ["battle_sim_registry"] = battle_sim_registry.duplicate(true)
	gs.scenario_state ["last_battle_sim_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.battle_sim.error",
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