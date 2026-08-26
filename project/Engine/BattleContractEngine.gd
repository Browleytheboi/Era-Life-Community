extends Resource
class_name BattleContractEngine

const ENGINE_SCHEMA:= "eralife.battle_contract_engine"
const CONTRACT_VERSION:= 1
const BATTLE_REGISTRY_PATH:= "user://war/battle_registry.json"

var gs
var battle_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "battle.emit_registry":
		return emit_battle_registry_contract(envelope)

	if command_id == "battle.create":
		return create_battle_contract(envelope)

	if command_id == "battle.create_demo":
		return create_demo_battle(envelope)

	if command_id == "battle.issue_intent":
		return issue_battle_intent(envelope)

	return _fail("unknown_battle_command", "BattleContractEngine did not recognize command.", envelope)


func emit_battle_registry_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battles: Dictionary = _safe_dictionary(battle_registry.get("battles", {}))
	var battle_list: Array = []

	for raw_key in battles.keys():
		var battle: Dictionary = _safe_dictionary(battles.get(raw_key, {}))
		if not battle.is_empty():
			battle_list.append(battle)

	battle_list.sort_custom(Callable(self, "_sort_battles_by_updated"))

	last_report = {
		"schema": "eralife.battle.registry_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_registry_ready",
		"battles": battle_list,
		"battle_count": battle_list.size(),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "BattleContractEngine",
			"simulation_authority": "BattleSimContractEngine",
			"ui_mutation_allowed": false
		}
	}

	_commit_state()
	return last_report.duplicate(true)


func create_battle_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var battle_id: String = str(context.get("battle_id", "")).strip_edges()
	if battle_id == "":
		battle_id = "battle_%d" % int(Time.get_ticks_msec())

	var war_id: String = str(context.get("war_id", "")).strip_edges()
	var army_ids: Array = _safe_array(context.get("army_ids", []))
	var terrain: String = str(context.get("terrain", "plains")).strip_edges()
	var weather: String = str(context.get("weather", "clear")).strip_edges()
	var engagement_type: String = str(context.get("engagement_type", "open_field")).strip_edges()

	var armies: Array = []
	for raw_army_id in army_ids:
		var army_id: String = str(raw_army_id).strip_edges()
		if army_id == "":
			continue
		var army_contract: Dictionary = _army_contract(army_id)
		if not army_contract.is_empty():
			armies.append(army_contract)

	if armies.is_empty() and typeof(context.get("armies", [])) == TYPE_ARRAY:
		for raw_army in context.get("armies", []):
			if typeof(raw_army) == TYPE_DICTIONARY:
				armies.append((raw_army as Dictionary).duplicate(true))

	var battle_contract: Dictionary = {
		"schema": "eralife.battle.spawn_contract",
		"version": CONTRACT_VERSION,
		"battle_id": battle_id,
		"war_id": war_id,
		"armies": armies,
		"terrain": terrain,
		"weather": weather,
		"engagement_type": engagement_type,
		"initial_formation": str(context.get("initial_formation", "opposed_lines")),
		"commander_intents": _safe_dictionary(context.get("commander_intents", {})),
		"state": "forming",
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "BattleContractEngine",
			"ui_mutation_allowed": false
		}
	}

	var battles: Dictionary = _safe_dictionary(battle_registry.get("battles", {}))
	battles [battle_id] = battle_contract.duplicate(true)
	battle_registry ["battles"] = battles
	battle_registry ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_registry()

	if gs != null and "war_contract_engine" in gs and gs.war_contract_engine != null and gs.war_contract_engine.has_method("register_active_battle"):
		if war_id != "":
			gs.war_contract_engine.register_active_battle(war_id, battle_id)

	if gs != null and "battle_sim_contract_engine" in gs and gs.battle_sim_contract_engine != null and gs.battle_sim_contract_engine.has_method("seed_battle_simulation"):
		gs.battle_sim_contract_engine.seed_battle_simulation(battle_contract, {
			"source": "BattleContractEngine.create_battle_contract"
		})

	last_report = {
		"schema": "eralife.battle.create_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_created",
		"battle": battle_contract.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func create_demo_battle(context: Dictionary = {}) -> Dictionary:
	if gs != null and "military_contract_engine" in gs:
		if gs.military_contract_engine == null:
			gs.military_contract_engine = MilitaryContractEngine.new(gs)
		if gs.military_contract_engine != null and gs.military_contract_engine.has_method("create_demo_armies"):
			gs.military_contract_engine.create_demo_armies(context)

	return create_battle_contract({
		"battle_id": str(context.get("battle_id", "battle_demo_pressure_field")),
		"war_id": str(context.get("war_id", "war_demo")),
		"army_ids": [
			str(context.get("side_a_army_id", "army_sunspire")),
			str(context.get("side_b_army_id", "army_blackvale"))
		],
		"terrain": str(context.get("terrain", "plains")),
		"weather": str(context.get("weather", "clear")),
		"engagement_type": str(context.get("engagement_type", "open_field")),
		"initial_formation": "opposed_lines"
	})


func issue_battle_intent(context: Dictionary = {}) -> Dictionary:
	var battle_id: String = str(context.get("battle_id", "")).strip_edges()
	if battle_id == "":
		return _fail("battle_missing", "Battle id is required.", context)

	if gs != null and "battle_sim_contract_engine" in gs:
		if gs.battle_sim_contract_engine == null:
			gs.battle_sim_contract_engine = BattleSimContractEngine.new(gs)
		if gs.battle_sim_contract_engine != null and gs.battle_sim_contract_engine.has_method("apply_commander_intent"):
			return gs.battle_sim_contract_engine.apply_commander_intent(battle_id, context)

	return _fail("battle_sim_unavailable", "BattleSimContractEngine unavailable.", context)


func get_battle(battle_id: String) -> Dictionary:
	_ensure_state()
	var battles: Dictionary = _safe_dictionary(battle_registry.get("battles", {}))
	return _safe_dictionary(battles.get(battle_id, {}))


func _army_contract(army_id: String) -> Dictionary:
	if gs != null and "military_contract_engine" in gs:
		if gs.military_contract_engine == null:
			gs.military_contract_engine = MilitaryContractEngine.new(gs)
		if gs.military_contract_engine != null and gs.military_contract_engine.has_method("get_army"):
			return gs.military_contract_engine.get_army(army_id)
	return {}


func _ensure_state() -> void:
	battle_registry = _read_registry()
	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(BATTLE_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "battles": {}}

	var file:= FileAccess.open(BATTLE_REGISTRY_PATH, FileAccess.READ)
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
	var file:= FileAccess.open(BATTLE_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(battle_registry, "\t"))
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
	gs.scenario_state ["battle_registry"] = battle_registry.duplicate(true)
	gs.scenario_state ["last_battle_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _sort_battles_by_updated(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.battle.error",
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