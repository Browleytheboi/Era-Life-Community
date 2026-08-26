extends Resource
class_name ScoreboardContractEngine

const ENGINE_SCHEMA:= "eralife.scoreboard_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_scoreboard_state"
const MAX_LADDER_ROWS:= 200

var gs: GameState = null
var state: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func record_session_result(
	session: Dictionary, result_contract: Dictionary, context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	var provider_id: String = _id(str(session.get("provider_id", "unknown")))
	var season_id: String = _season_id(provider_id, context)
	var winner_key: String = str(result_contract.get("winner_identity_key", ""))
	var draw: bool = bool(result_contract.get("draw", false))
	var provider_stats: Dictionary = _dict(
		_dict(state.get("provider_stats", {})).get(provider_id, {})
	)
	var season_stats: Dictionary = _dict(_dict(state.get("season_stats", {})).get(season_id, {}))
	var participant_reports: Array = []

	for raw_participant in _array(session.get("participants", [])):
		var participant: Dictionary = _dict(raw_participant)
		var identity_key: String = str(participant.get("identity_key", "")).strip_edges()

		if identity_key == "":
			continue

		var row: Dictionary = _dict(provider_stats.get(identity_key, {}))
		var season_row: Dictionary = _dict(season_stats.get(identity_key, {}))
		var won: bool = not draw and identity_key == winner_key
		var lost: bool = not draw and winner_key != "" and identity_key != winner_key
		var score_delta: int = int(_dict(result_contract.get("scores", {})).get(identity_key, 0))

		row = _apply_result_to_row(row, participant, won, lost, draw, score_delta, false)
		season_row = _apply_result_to_row(
			season_row, participant, won, lost, draw, score_delta, true
		)
		provider_stats [identity_key] = row
		season_stats [identity_key] = season_row
		participant_reports.append(
			{
				"identity_key": identity_key,
				"wins": int(row.get("wins", 0)),
				"losses": int(row.get("losses", 0)),
				"draws": int(row.get("draws", 0)),
				"rating": int(row.get("rating", 1000)),
				"season_rating": int(season_row.get("rating", 1000))
			}
		)

	var provider_root: Dictionary = _dict(state.get("provider_stats", {}))
	provider_root [provider_id] = provider_stats
	state ["provider_stats"] = provider_root

	var season_root: Dictionary = _dict(state.get("season_stats", {}))
	season_root [season_id] = season_stats
	state ["season_stats"] = season_root
	state ["last_result"] = {
		"session_id": str(session.get("session_id", "")),
		"provider_id": provider_id,
		"season_id": season_id,
		"winner_identity_key": winner_key,
		"draw": draw,
		"recorded_at_ms": int(Time.get_ticks_msec())
	}
	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "scoreboard_result_recorded",
		"provider_id": provider_id,
		"season_id": season_id,
		"participant_reports": participant_reports,
		"ui_is_renderer_only": true
	}


func emit_scoreboard_contract(provider_id: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var clean_provider_id: String = _id(provider_id)
	var provider_root: Dictionary = _dict(state.get("provider_stats", {}))
	var rows: Array = []

	if clean_provider_id != "":
		rows = _rows_from_stats(_dict(provider_root.get(clean_provider_id, {})))
	else:
		for raw_provider_id in provider_root.keys():
			for raw_row in _rows_from_stats(_dict(provider_root.get(raw_provider_id, {}))):
				var row: Dictionary = _dict(raw_row)
				row ["provider_id"] = str(raw_provider_id)
				rows.append(row)

	rows.sort_custom(Callable(self, "_rating_desc"))
	if rows.size() > MAX_LADDER_ROWS:
		rows = rows.slice(0, MAX_LADDER_ROWS)

	var season_id: String = _season_id(clean_provider_id, context)
	var seasonal_rows: Array = _rows_from_stats(
		_dict(_dict(state.get("season_stats", {})).get(season_id, {}))
	)
	seasonal_rows.sort_custom(Callable(self, "_rating_desc"))

	return {
		"success": true,
		"schema": "eralife.minigame_scoreboard_projection",
		"version": ENGINE_VERSION,
		"provider_id": clean_provider_id,
		"season_id": season_id,
		"all_time_rows": rows,
		"seasonal_rows": seasonal_rows,
		"truth_state": "hot",
		"authoritative_projection": true,
		"context": context.duplicate(true),
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


func _apply_result_to_row(
	row: Dictionary,
	participant: Dictionary,
	won: bool,
	lost: bool,
	draw: bool,
	score_delta: int,
	seasonal: bool
) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	out ["identity_key"] = str(participant.get("identity_key", ""))
	out ["display_name"] = str(participant.get("display_name", "Player"))
	out ["identity_kind"] = str(participant.get("identity_kind", "person"))
	out ["matches"] = int(out.get("matches", 0)) + 1
	out ["wins"] = int(out.get("wins", 0)) + (1 if won else 0)
	out ["losses"] = int(out.get("losses", 0)) + (1 if lost else 0)
	out ["draws"] = int(out.get("draws", 0)) + (1 if draw else 0)
	out ["score"] = int(out.get("score", 0)) + score_delta
	out ["current_streak"] = (int(out.get("current_streak", 0)) + 1 if won else 0)
	out ["best_streak"] = maxi(int(out.get("best_streak", 0)), int(out.get("current_streak", 0)))
	var rating_delta: int = 0
	if won:
		rating_delta = 24
	elif lost:
		rating_delta = -18
	elif draw:
		rating_delta = 4
	out ["rating"] = maxi(100, int(out.get("rating", 1000)) + rating_delta)
	out ["seasonal"] = seasonal
	out ["updated_at_ms"] = int(Time.get_ticks_msec())
	return out


func _rows_from_stats(stats: Dictionary) -> Array:
	var out: Array = []
	for raw_row in stats.values():
		if typeof(raw_row) == TYPE_DICTIONARY:
			out.append((raw_row as Dictionary).duplicate(true))
	return out


func _season_id(provider_id: String, context: Dictionary) -> String:
	var world_year: int = int(context.get("year", gs.year if gs != null else 0))
	var season_number: int = int(context.get("season_number", 1))
	return (
		"season:%s:%d:%d"
		% [provider_id if provider_id != "" else "all", world_year, maxi(1, season_number)]
	)


func _rating_desc(a: Dictionary, b: Dictionary) -> bool:
	var rating_a: int = int(a.get("rating", 0))
	var rating_b: int = int(b.get("rating", 0))
	if rating_a == rating_b:
		return int(a.get("wins", 0)) > int(b.get("wins", 0))
	return rating_a > rating_b


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"provider_stats": {},
			"season_stats": {},
			"last_result": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("provider_stats", {})) != TYPE_DICTIONARY:
		state ["provider_stats"] = {}
	if typeof(state.get("season_stats", {})) != TYPE_DICTIONARY:
		state ["season_stats"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []