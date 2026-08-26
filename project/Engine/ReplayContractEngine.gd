extends Resource
class_name ReplayContractEngine

const ENGINE_SCHEMA:= "eralife.replay_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_replay_state"
const MAX_REPLAYS:= 120
const MAX_EVENTS_PER_REPLAY:= 300

var gs: GameState = null
var state: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func begin_replay(
	session: Dictionary
) -> Dictionary:
	_ensure_state()

	var replay_id: String = (
		"replay:%s"
		% str(
			session.get(
				"session_id",
				"unknown"
			)
		)
	)
	var replays: Dictionary = _dict(
		state.get(
			"replays",
			{}
		)
	)

	if replays.has(
		replay_id
	):
		return _dict(
			replays.get(
				replay_id,
				{}
			)
		).duplicate(true)

	var replay_contract: Dictionary = {
		"schema": "eralife.minigame_replay_contract",
		"version": ENGINE_VERSION,
		"replay_id": replay_id,
		"session_id": str(
			session.get(
				"session_id",
				""
			)
		),
		"provider_id": str(
			session.get(
				"provider_id",
				""
			)
		),
		"game_title": str(
			session.get(
				"game_title",
				"MiniGame"
			)
		),
		"participants": _array(
			session.get(
				"participants",
				[]
			)
		).duplicate(true),
		"host_contract": _dict(
			session.get(
				"host_contract",
				{}
			)
		).duplicate(true),
		"events": [],
		"status": "recording",
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"completed_at_ms": 0,
		"result_contract": {},
		"ui_is_renderer_only": true
	}

	replays [replay_id] = (
		replay_contract.duplicate(true)
	)
	state ["replays"] = replays

	_prune_replays()
	_publish_state()

	return replay_contract


func append_event(
	session_id: String,
	event: Dictionary
) -> Dictionary:
	_ensure_state()

	var replay_id: String = (
		"replay:%s" % session_id
	)
	var replays: Dictionary = _dict(
		state.get(
			"replays",
			{}
		)
	)
	var replay_contract: Dictionary = _dict(
		replays.get(
			replay_id,
			{}
		)
	)

	if replay_contract.is_empty():
		return {
			"success": false,
			"reason": "replay_not_started"
		}

	var events: Array = _array(
		replay_contract.get(
			"events",
			[]
		)
	)
	var row: Dictionary = (
		event.duplicate(true)
	)
	row ["sequence"] = events.size()
	row ["recorded_at_ms"] = int(
		row.get(
			"recorded_at_ms",
			Time.get_ticks_msec()
		)
	)

	events.append(
		row
	)

	while (
		events.size()
		> MAX_EVENTS_PER_REPLAY
	):
		events.pop_front()

	replay_contract ["events"] = events
	replay_contract ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	replays [replay_id] = (
		replay_contract.duplicate(true)
	)
	state ["replays"] = replays

	_publish_state()

	return {
		"success": true,
		"replay_id": replay_id,
		"event_count": events.size()
	}


func finalize_replay(
	session: Dictionary,
	result_contract: Dictionary
) -> Dictionary:
	_ensure_state()

	var replay_id: String = (
		"replay:%s"
		% str(
			session.get(
				"session_id",
				""
			)
		)
	)
	var replays: Dictionary = _dict(
		state.get(
			"replays",
			{}
		)
	)
	var replay_contract: Dictionary = _dict(
		replays.get(
			replay_id,
			{}
		)
	)

	if replay_contract.is_empty():
		replay_contract = begin_replay(
			session
		)

	replay_contract ["status"] = "complete"
	replay_contract ["completed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	replay_contract ["result_contract"] = (
		result_contract.duplicate(true)
	)
	replay_contract ["final_provider_state"] = _dict(
		session.get(
			"provider_state",
			{}
		)
	).duplicate(true)

	replays [replay_id] = (
		replay_contract.duplicate(true)
	)
	state ["replays"] = replays

	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "replay_finalized",
		"replay": (
			replay_contract.duplicate(true)
		),
		"ui_is_renderer_only": true
	}

func append_events_batch(
	session_id: String,
	event_rows: Array
) -> Dictionary:
	_ensure_state()

	var replay_id: String = (
		"replay:%s"
		% session_id
	)

	var replays: Dictionary = _dict(
		state.get(
			"replays",
			{}
		)
	)

	var replay_contract: Dictionary = _dict(
		replays.get(
			replay_id,
			{}
		)
	).duplicate(false)

	if replay_contract.is_empty():
		return {
			"success": false,
			"reason": "replay_not_started"
		}

	var events: Array = _array(
		replay_contract.get(
			"events",
			[]
		)
	)

	for raw_event in event_rows:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_event as Dictionary
		).duplicate(true)

		row [
			"sequence"
		] = events.size()
		row [
			"recorded_at_ms"
		] = int(
			row.get(
				"recorded_at_ms",
				Time.get_ticks_msec()
			)
		)

		events.append(
			row
		)

	while events.size() > MAX_EVENTS_PER_REPLAY:
		events.pop_front()

	replay_contract [
		"events"
	] = events
	replay_contract [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	replays [
		replay_id
	] = replay_contract.duplicate(true)
	state [
		"replays"
	] = replays



	_publish_state()

	return {
		"success": true,
		"replay_id": replay_id,
		"event_count": events.size(),
	}
func emit_replay_contract(
	provider_id: String = "",
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var clean_provider: String = str(
		provider_id
	).strip_edges().to_lower()
	var rows: Array = []

	for raw_replay in _dict(
		state.get(
			"replays",
			{}
		)
	).values():
		var replay_contract: Dictionary = _dict(
			raw_replay
		)

		if (
			clean_provider != ""
			and str(
				replay_contract.get(
					"provider_id",
					""
				)
			).to_lower() != clean_provider
		):
			continue

		var events: Array = _array(
			replay_contract.get(
				"events",
				[]
			)
		)




		rows.append(
			{
				"replay_id": str(
					replay_contract.get(
						"replay_id",
						""
					)
				),
				"provider_id": str(
					replay_contract.get(
						"provider_id",
						""
					)
				),
				"game_title": str(
					replay_contract.get(
						"game_title",
						replay_contract.get(
							"provider_id",
							"Replay"
						)
					)
				),
				"status": str(
					replay_contract.get(
						"status",
						"recording"
					)
				),
				"event_count": events.size(),
				"created_at_ms": int(
					replay_contract.get(
						"created_at_ms",
						0
					)
				),
				"updated_at_ms": int(
					replay_contract.get(
						"updated_at_ms",
						0
					)
				),
				"completed_at_ms": int(
					replay_contract.get(
						"completed_at_ms",
						0
					)
				),
				"winner_identity_key": str(
					replay_contract.get(
						"winner_identity_key",
						""
					)
				),
				"ui_is_renderer_only": true
			}
		)

	rows.sort_custom(
		Callable(
			self,
			"_newest_first"
		)
	)

	return {
		"success": true,
		"schema": (
			"eralife.minigame_replay_projection"
		),
		"version": ENGINE_VERSION,
		"provider_id": clean_provider,
		"rows": rows,
		"context": context.duplicate(false),
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}

func replay(replay_id: String) -> Dictionary:
	_ensure_state()
	return _dict(_dict(state.get("replays", {})).get(replay_id, {})).duplicate(true)


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _prune_replays() -> void:
	var replays: Dictionary = _dict(state.get("replays", {}))
	if replays.size() <= MAX_REPLAYS:
		return
	var rows: Array = replays.values()
	rows.sort_custom(Callable(self, "_oldest_first"))
	while rows.size() > MAX_REPLAYS:
		var row: Dictionary = _dict(rows.pop_front())
		replays.erase(str(row.get("replay_id", "")))
	state ["replays"] = replays


func _newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) > int(b.get("created_at_ms", 0))


func _oldest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) < int(b.get("created_at_ms", 0))


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"replays": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("replays", {})) != TYPE_DICTIONARY:
		state ["replays"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []