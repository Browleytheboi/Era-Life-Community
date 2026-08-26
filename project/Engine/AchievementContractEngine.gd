extends Resource
class_name AchievementContractEngine

const ENGINE_SCHEMA:= "eralife.achievement_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_achievement_state"

var gs: GameState = null
var state: Dictionary = {}
var definitions: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func register_achievement_definitions(provider_id: String, rows: Array) -> Dictionary:
	var clean_provider_id: String = _id(provider_id)
	if clean_provider_id == "":
		return _failure("missing_provider_id")

	var normalized: Array = []
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = (raw_row as Dictionary).duplicate(true)
		var achievement_id: String = _id(str(row.get("achievement_id", row.get("id", ""))))
		if achievement_id == "":
			continue
		row ["achievement_id"] = achievement_id
		row ["provider_id"] = clean_provider_id
		row ["title"] = str(row.get("title", achievement_id.capitalize()))
		row ["description"] = str(row.get("description", ""))
		row ["criteria"] = _dict(row.get("criteria", {}))
		normalized.append(row)

	definitions [clean_provider_id] = normalized
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_id": clean_provider_id,
		"definition_count": normalized.size()
	}


func evaluate_session(
	session: Dictionary, result_contract: Dictionary, context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	var provider_id: String = _id(str(session.get("provider_id", "")))
	var provider_definitions: Array = _array(definitions.get(provider_id, []))
	var unlocked_rows: Array = []

	for raw_participant in _array(session.get("participants", [])):
		var participant: Dictionary = _dict(raw_participant)
		var identity_key: String = str(participant.get("identity_key", "")).strip_edges()
		if identity_key == "":
			continue
		for raw_definition in provider_definitions:
			var definition: Dictionary = _dict(raw_definition)
			if not _criteria_matches(definition, identity_key, session, result_contract, context):
				continue
			var unlock_report: Dictionary = _unlock(identity_key, definition, session)
			if bool(unlock_report.get("newly_unlocked", false)):
				unlocked_rows.append(unlock_report)

	_publish_state()
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "achievements_evaluated",
		"provider_id": provider_id,
		"unlocked": unlocked_rows,
		"ui_is_renderer_only": true
	}


func emit_achievement_contract(identity_key: String = "", provider_id: String = "") -> Dictionary:
	_ensure_state()
	var clean_identity: String = str(identity_key).strip_edges()
	var clean_provider: String = _id(provider_id)
	var earned_root: Dictionary = _dict(state.get("earned", {}))
	var rows: Array = []

	if clean_identity != "":
		for raw_row in _dict(earned_root.get(clean_identity, {})).values():
			var row: Dictionary = _dict(raw_row)
			if clean_provider == "" or str(row.get("provider_id", "")) == clean_provider:
				rows.append(row.duplicate(true))
	else:
		for raw_identity_rows in earned_root.values():
			for raw_row in _dict(raw_identity_rows).values():
				var row: Dictionary = _dict(raw_row)
				if clean_provider == "" or str(row.get("provider_id", "")) == clean_provider:
					rows.append(row.duplicate(true))

	rows.sort_custom(Callable(self, "_newest_first"))
	return {
		"success": true,
		"schema": "eralife.minigame_achievement_projection",
		"version": ENGINE_VERSION,
		"identity_key": clean_identity,
		"provider_id": clean_provider,
		"earned": rows,
		"definitions":
		_array(definitions.get(clean_provider, [])).duplicate(true) if clean_provider != "" else [],
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _criteria_matches(
	definition: Dictionary,
	identity_key: String,
	session: Dictionary,
	result_contract: Dictionary,
	_context: Dictionary
) -> bool:
	var criteria: Dictionary = _dict(definition.get("criteria", {}))
	var criteria_type: String = _id(str(criteria.get("type", "session_complete")))
	var winner_key: String = str(result_contract.get("winner_identity_key", ""))
	var participant_count: int = _array(session.get("participants", [])).size()
	var scores: Dictionary = _dict(result_contract.get("scores", {}))
	var own_score: int = int(scores.get(identity_key, 0))

	match criteria_type:
		"session_complete":
			return true
		"win":
			return winner_key == identity_key
		"flawless_win":
			return winner_key == identity_key and bool(result_contract.get("flawless", false))
		"comeback_win":
			return winner_key == identity_key and bool(result_contract.get("comeback", false))
		"social_match":
			return participant_count >= 2
		"online_match":
			return (
				str(session.get("multiplayer_mode", ""))
				in ["online", "online_eraccount", "eraccount_online"]
			)
		"score_at_least":
			return own_score >= int(criteria.get("value", 1))
		_:
			return false


func _unlock(identity_key: String, definition: Dictionary, session: Dictionary) -> Dictionary:
	var earned_root: Dictionary = _dict(state.get("earned", {}))
	var identity_rows: Dictionary = _dict(earned_root.get(identity_key, {}))
	var key: String = (
		"%s:%s"
		% [str(definition.get("provider_id", "")), str(definition.get("achievement_id", ""))]
	)
	if identity_rows.has(key):
		var existing: Dictionary = _dict(identity_rows.get(key, {}))
		existing ["newly_unlocked"] = false
		return existing

	var row: Dictionary = definition.duplicate(true)
	row ["identity_key"] = identity_key
	row ["session_id"] = str(session.get("session_id", ""))
	row ["unlocked_at_ms"] = int(Time.get_ticks_msec())
	row ["newly_unlocked"] = true
	identity_rows [key] = row.duplicate(true)
	earned_root [identity_key] = identity_rows
	state ["earned"] = earned_root
	return row


func _newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("unlocked_at_ms", 0)) > int(b.get("unlocked_at_ms", 0))


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"earned": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("earned", {})) != TYPE_DICTIONARY:
		state ["earned"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _failure(reason: String) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return { "success": false, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION, "reason": reason}


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []