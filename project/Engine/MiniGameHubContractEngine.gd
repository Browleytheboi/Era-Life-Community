extends Resource
class_name MiniGameHubContractEngine

const ENGINE_SCHEMA:= "eralife.minigame_hub_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_hub_contract_state"

var gs: GameState = null
var state: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func resolve_intent(actor: Person, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _failure(
			"actor_missing", "A controlled actor is required to observe the MiniGame ecosystem."
		)

	var actor_id: int = int(actor.id)
	var active_section: String = _section(
		str(payload.get("active_section", _section_for_actor(actor_id)))
	)
	_set_section_for_actor(actor_id, active_section)

	if gs == null or gs.mini_game_contract_engine == null:
		return _failure(
			"minigame_contract_engine_unavailable", "MiniGameContractEngine is not resident."
		)

	var routed_payload: Dictionary = payload.duplicate(true)
	routed_payload ["active_section"] = active_section
	routed_payload ["source"] = str(
		payload.get("source", "mini_game_hub_contract_engine.resolve_intent")
	)
	routed_payload ["ui_is_renderer_only"] = true

	var result: Dictionary = gs.mini_game_contract_engine.resolve_intent(actor, routed_payload)

	if not bool(result.get("success", false)):
		return result

	var contract: Dictionary = _extract_contract(result)

	if contract.is_empty():
		contract = emit_hub_contract(actor, routed_payload)

	result ["mini_game_contract"] = contract.duplicate(true)
	result ["hub_contract"] = contract.duplicate(true)
	result ["ui_is_renderer_only"] = true
	return result


func emit_observable_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	return emit_hub_contract(actor, context)


func emit_hub_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _failure("actor_missing", "A controlled actor is required to emit the MiniGame Hub.")

	if gs == null or gs.mini_game_contract_engine == null:
		return _failure(
			"minigame_contract_engine_unavailable", "MiniGameContractEngine is not resident."
		)

	var actor_id: int = int(actor.id)
	var routed_context: Dictionary = context.duplicate(true)
	routed_context ["active_section"] = _section(
		str(context.get("active_section", _section_for_actor(actor_id)))
	)
	routed_context ["source"] = str(
		context.get("source", "mini_game_hub_contract_engine.emit_hub_contract")
	)
	routed_context ["ui_is_renderer_only"] = true

	var contract: Dictionary = gs.mini_game_contract_engine.emit_hub_contract(actor, routed_context)

	if bool(contract.get("success", false)):
		_set_section_for_actor(actor_id, str(contract.get("active_section", "games")))

	return contract


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _extract_contract(result: Dictionary) -> Dictionary:
	for raw_key in ["mini_game_contract", "hub_contract", "contract"]:
		var row: Dictionary = _dict(result.get(raw_key, {}))

		if not row.is_empty():
			return row

	return {}


func _section_for_actor(actor_id: int) -> String:
	return _section(
		str(_dict(state.get("active_section_by_actor", {})).get(str(actor_id), "games"))
	)


func _set_section_for_actor(actor_id: int, section_id: String) -> void:
	var sections: Dictionary = _dict(state.get("active_section_by_actor", {}))
	sections [str(actor_id)] = _section(section_id)
	state ["active_section_by_actor"] = sections
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	_publish_state()


func _section(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()

	if (
		clean
		in [
			"games",
			"session",
			"multiplayer",
			"tournaments",
			"leaderboards",
			"achievements",
			"replays",
			"mods"
		]
	):
		return clean

	return "games"


func _ensure_state() -> void:
	if typeof(state) != TYPE_DICTIONARY:
		state = {}

	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)

	if typeof(state.get("active_section_by_actor", {})) != TYPE_DICTIONARY:
		state ["active_section_by_actor"] = {}

	state ["schema"] = ENGINE_SCHEMA
	state ["version"] = ENGINE_VERSION
	_publish_state()


func _publish_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _failure(reason: String, text: String) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}