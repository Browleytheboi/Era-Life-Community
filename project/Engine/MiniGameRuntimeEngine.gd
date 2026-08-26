extends Resource
class_name MiniGameRuntimeEngine

const ENGINE_SCHEMA:= "eralife.minigame_runtime_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_runtime_state"
const MAX_SESSIONS:= 256
const MAX_SESSION_EVENTS:= 240

const CONTINUOUS_FIXED_STEP_HZ:= 60
const CONTINUOUS_FIXED_STEP_DELTA:= (
	1.0 / float(
		CONTINUOUS_FIXED_STEP_HZ
	)
)
const CONTINUOUS_FIXED_STEP_USEC:= 16667
const CONTINUOUS_OBSERVATION_EVERY_STEPS:= 2
const CONTINUOUS_CHECKPOINT_EVERY_STEPS:= 15
const CONTINUOUS_MAX_EDGE_QUEUE:= 12




const CONTINUOUS_OBSERVATION_DELIVERY_QUANTUM:= 4

var gs: GameState = null
var state: Dictionary = {}



var continuous_hot_sessions: Dictionary = {}
var continuous_mutex: Mutex = Mutex.new()
var continuous_wake_semaphore: Semaphore = Semaphore.new()
var continuous_worker: Thread = null
var continuous_worker_start_pending: bool = false
var continuous_worker_stop_requested: bool = false








var continuous_pending_observation_by_session: Dictionary = {}
var continuous_observation_delivery_armed: bool = false


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func create_session(
	provider_contract: Dictionary,
	host_contract: Dictionary,
	participants: Array,
	provider_state: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var provider_id: String = _id(
		str(
			provider_contract.get(
				"provider_id",
				""
			)
		)
	)

	if provider_id == "":
		return _failure(
			"missing_provider_id",
			"A persistent minigame session requires a provider identity."
		)

	if participants.is_empty():
		return _failure(
			"missing_participants",
			"A persistent minigame session requires at least one participant."
		)

	var session_id: String = _next_session_id(
		provider_id
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var continuous_runtime: bool = bool(
		context.get(
			"continuous_runtime",
			false
		)
	)

	var session_contract: Dictionary = {
		"schema": "eralife.minigame_session_contract",
		"version": ENGINE_VERSION,
		"session_id": session_id,
		"provider_id": provider_id,
		"provider_revision": str(
			provider_contract.get(
				"provider_revision",
				"1"
			)
		),
		"game_title": str(
			provider_contract.get(
				"title",
				provider_id.capitalize()
			)
		),
		"host_contract": (
			host_contract.duplicate(true)
		),
		"participants": _dictionary_array(
			participants
		),
		"spectators": [],
		"status": "active",
		"multiplayer_mode": str(
			context.get(
				"multiplayer_mode",
				"single_vs_ai"
			)
		),
		"round": 1,
		"provider_state": (
			provider_state.duplicate(true)
		),
		"event_log": [],
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"completed_at_ms": 0,
		"winner_identity_key": "",
		"result_contract": {},
		"context": (
			_serializable_dictionary(
				context
			)
		),
		"continuous_runtime": continuous_runtime,
		"ui_is_renderer_only": true
	}

	var sessions: Dictionary = _dict(
		state.get(
			"sessions",
			{}
		)
	)

	sessions [
		session_id
	] = session_contract.duplicate(true)

	state [
		"sessions"
	] = sessions

	for raw_participant in participants:
		var participant: Dictionary = _dict(
			raw_participant
		)

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		).strip_edges()

		if identity_key == "":
			continue

		var active_by_identity: Dictionary = _dict(
			state.get(
				"active_session_by_identity",
				{}
			)
		)

		active_by_identity [
			identity_key
		] = session_id

		state [
			"active_session_by_identity"
		] = active_by_identity

	_prune_sessions()

	if continuous_runtime:
		_publish_session_delta(
			session_id,
			session_contract
		)
	else:
		_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "minigame_session_committed",
		"session_id": session_id,
		"session": (
			session_contract.duplicate(true)
		),
		"continuous_runtime": continuous_runtime,
		"ui_is_renderer_only": true
	}
func _publish_session_delta(
	session_id: String,
	session_row: Dictionary
) -> void:
	state [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var published_raw: Variant = (
		gs.scenario_state.get(
			STATE_KEY,
			{}
		)
	)

	var published_state: Dictionary = (
		(published_raw as Dictionary).duplicate(false)
		if typeof(published_raw) == TYPE_DICTIONARY
		else {}
	)

	published_state [
		"schema"
	] = ENGINE_SCHEMA
	published_state [
		"version"
	] = ENGINE_VERSION
	published_state [
		"session_sequence"
	] = int(
		state.get(
			"session_sequence",
			0
		)
	)
	published_state [
		"updated_at_ms"
	] = int(
		state.get(
			"updated_at_ms",
			0
		)
	)

	var authoritative_sessions: Dictionary = _dict(
		state.get(
			"sessions",
			{}
		)
	)

	var published_sessions: Dictionary = _dict(
		published_state.get(
			"sessions",
			{}
		)
	).duplicate(false)


	for raw_key in published_sessions.keys():
		if not authoritative_sessions.has(
			raw_key
		):
			published_sessions.erase(
				raw_key
			)

	if (
		session_id != ""
		and not session_row.is_empty()
	):
		published_sessions [
			session_id
		] = session_row.duplicate(true)

	published_state [
		"sessions"
	] = published_sessions

	published_state [
		"active_session_by_identity"
	] = _dict(
		state.get(
			"active_session_by_identity",
			{}
		)
	).duplicate(true)

	gs.scenario_state [
		STATE_KEY
	] = published_state
func activate_continuous_session(
	session_id: String,
	provider_id: String,
	provider_object: Object,
	provider_state: Dictionary,
	continuous_contract: Dictionary,
	initial_events: Array = [],
	context: Dictionary = {},
	observation_sink: Callable = Callable(),
	completion_sink: Callable = Callable()
) -> Dictionary:
	_ensure_state()

	var clean_session_id: String = _id(
		session_id
	)

	if clean_session_id == "":
		return _failure(
			"missing_session_id",
			"Continuous MiniGame authority requires a session."
		)

	if provider_object == null:
		return _failure(
			"provider_runtime_missing",
			"Continuous MiniGame authority requires a provider runtime."
		)

	var step_method: String = str(
		continuous_contract.get(
			"step_method",
			"advance_continuous_simulation"
		)
	).strip_edges()

	if step_method == "":
		step_method = "advance_continuous_simulation"

	if not provider_object.has_method(
		step_method
	):
		return _failure(
			"continuous_provider_method_missing",
			(
				"The provider does not expose its declared "
				+ "continuous simulation method: %s."
				% step_method
			)
		)

	var session_row: Dictionary = _dict(
		_dict(
			state.get(
				"sessions",
				{}
			)
		).get(
			clean_session_id,
			{}
		)
	)

	if session_row.is_empty():
		return _failure(
			"unknown_session",
			"The continuous MiniGame session does not exist."
		)





	if not _ensure_continuous_worker_running():
		return _failure(
			"continuous_worker_start_failed",
			(
				"The continuous MiniGame worker could not be started. "
				+ "The session was not attached to hot reality."
			)
		)

	var participant_keys: Dictionary = {}

	for raw_participant in _array(
		session_row.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)
		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key != "":
			participant_keys [
				identity_key
			] = true

	var pending_events: Array = []

	for raw_event in initial_events:
		if typeof(raw_event) == TYPE_DICTIONARY:
			pending_events.append(
				(raw_event as Dictionary).duplicate(true)
			)

	var hot_row: Dictionary = {
		"session_id": clean_session_id,
		"provider_id": _id(provider_id),
		"provider_object": provider_object,
		"provider_state": provider_state.duplicate(true),
		"continuous_contract": continuous_contract.duplicate(false),
		"participant_identity_keys": participant_keys,
		"input_by_identity": {},
		"pending_events": pending_events,
		"step_count": 0,
		"observation_revision": 0,
		"context": context.duplicate(false),
		"observation_sink": observation_sink,
		"completion_sink": completion_sink,
		"complete": false
	}

	continuous_mutex.lock()

	continuous_hot_sessions [
		clean_session_id
	] = hot_row

	continuous_mutex.unlock()


	continuous_wake_semaphore.post()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "continuous_session_activated",
		"session_id": clean_session_id,
		"step_method": step_method,
		"fixed_step_hz": CONTINUOUS_FIXED_STEP_HZ,
		"observation_hz": (
			float(CONTINUOUS_FIXED_STEP_HZ)
			/ float(CONTINUOUS_OBSERVATION_EVERY_STEPS)
		),
		"checkpoint_hz": (
			float(CONTINUOUS_FIXED_STEP_HZ)
			/ float(CONTINUOUS_CHECKPOINT_EVERY_STEPS)
		),
		"ui_is_renderer_only": true
	}

func submit_continuous_input(
	session_id: String,
	identity_key: String,
	input_action_id: String,
	pressed: bool,
	input_kind: String,
	input_sequence: int
) -> Dictionary:
	var clean_session_id: String = _id(
		session_id
	)
	var clean_identity_key: String = str(
		identity_key
	).strip_edges()
	var clean_action: String = _id(
		input_action_id
	)
	var clean_kind: String = _id(
		input_kind
	)

	if (
		clean_session_id == ""
		or clean_identity_key == ""
		or clean_action == ""
	):
		return _failure(
			"continuous_input_invalid",
			"Continuous MiniGame input is missing identity."
		)

	continuous_mutex.lock()

	var hot_row: Dictionary = _dict(
		continuous_hot_sessions.get(
			clean_session_id,
			{}
		)
	)

	if hot_row.is_empty():
		continuous_mutex.unlock()
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mode": "continuous_input_ignored",
			"session_id": clean_session_id,
			"identity_key": clean_identity_key,
			"input_action_id": clean_action,
			"pressed": pressed,
			"input_sequence": input_sequence,
			"input_ack": false,
		}

	var participant_keys: Dictionary = _dict(
		hot_row.get(
			"participant_identity_keys",
			{}
		)
	)

	if not participant_keys.has(
		clean_identity_key
	):
		continuous_mutex.unlock()
		return _failure(
			"continuous_identity_not_participant",
			"That identity is not a participant in this session."
		)

	var continuous_contract: Dictionary = _dict(
		hot_row.get(
			"continuous_contract",
			{}
		)
	)

	var held_inputs: Array = _array(
		continuous_contract.get(
			"held_inputs",
			[]
		)
	)
	var edge_inputs: Array = _array(
		continuous_contract.get(
			"edge_inputs",
			[]
		)
	)

	if (
		clean_action not in held_inputs
		and clean_action not in edge_inputs
	):
		continuous_mutex.unlock()
		return _failure(
			"continuous_input_not_allowed",
			"The continuous provider does not expose that input."
		)

	var input_by_identity: Dictionary = _dict(
		hot_row.get(
			"input_by_identity",
			{}
		)
	)

	var input_row: Dictionary = _dict(
		input_by_identity.get(
			clean_identity_key,
			{}
		)
	)

	var held: Dictionary = _dict(
		input_row.get(
			"held",
			{}
		)
	)

	var edges: Array = _array(
		input_row.get(
			"edges",
			[]
		)
	)

	if clean_kind == "held":
		held [
			clean_action
		] = pressed
	elif clean_kind == "edge":
		if edges.size() < CONTINUOUS_MAX_EDGE_QUEUE:
			edges.append(
				{
					"action_id": clean_action,
					"pressed": pressed,
					"input_sequence": input_sequence
				}
			)

	input_row [
		"held"
	] = held
	input_row [
		"edges"
	] = edges
	input_row [
		"last_input_sequence"
	] = input_sequence

	input_by_identity [
		clean_identity_key
	] = input_row

	hot_row [
		"input_by_identity"
	] = input_by_identity

	continuous_hot_sessions [
		clean_session_id
	] = hot_row

	continuous_mutex.unlock()

	continuous_wake_semaphore.post()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "continuous_input_latched",
		"session_id": clean_session_id,
		"identity_key": clean_identity_key,
		"input_action_id": clean_action,
		"pressed": pressed,
		"input_sequence": input_sequence,
		"input_ack": true,
	}
func _ensure_continuous_worker_deferred() -> void:
	continuous_worker_start_pending = false

	if _ensure_continuous_worker_running():
		continuous_wake_semaphore.post()
func _ensure_continuous_worker_running() -> bool:
	if (
		continuous_worker != null
		and continuous_worker.is_alive()
	):
		return true

	if continuous_worker != null:
		continuous_worker.wait_to_finish()
		continuous_worker = null

	continuous_worker_stop_requested = false

	continuous_worker = Thread.new()

	var start_error: int = continuous_worker.start(
		Callable(
			self,
			"_continuous_worker_loop"
		)
	)

	if start_error != OK:
		continuous_worker = null
		return false

	return true
func _continuous_worker_loop() -> void:
	var next_step_usec: int = int(
		Time.get_ticks_usec()
	)

	while not continuous_worker_stop_requested:
		continuous_mutex.lock()
		var session_ids: Array = (
			continuous_hot_sessions.keys()
		)
		continuous_mutex.unlock()

		if session_ids.is_empty():
			continuous_wake_semaphore.wait()
			next_step_usec = int(
				Time.get_ticks_usec()
			)
			continue

		var now_usec: int = int(
			Time.get_ticks_usec()
		)

		if now_usec < next_step_usec:
			OS.delay_usec(
				maxi(
					100,
					mini(
						2000,
						next_step_usec - now_usec
					)
				)
			)
			continue

		for raw_session_id in session_ids:
			_service_continuous_session_worker_step(
				str(raw_session_id),
				CONTINUOUS_FIXED_STEP_DELTA
			)

		next_step_usec += CONTINUOUS_FIXED_STEP_USEC


		var after_step_usec: int = int(
			Time.get_ticks_usec()
		)

		if (
			after_step_usec
			- next_step_usec
			> CONTINUOUS_FIXED_STEP_USEC * 4
		):
			next_step_usec = (
				after_step_usec
				+ CONTINUOUS_FIXED_STEP_USEC
			)


func _consume_continuous_input_snapshot_locked(
	hot_row: Dictionary
) -> Dictionary:
	var source: Dictionary = _dict(
		hot_row.get(
			"input_by_identity",
			{}
		)
	)

	var snapshot: Dictionary = {}

	for raw_identity_key in source.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		var input_row: Dictionary = _dict(
			source.get(
				raw_identity_key,
				{}
			)
		)

		var held: Dictionary = _dict(
			input_row.get(
				"held",
				{}
			)
		).duplicate(false)

		var edges: Array = _array(
			input_row.get(
				"edges",
				[]
			)
		).duplicate(true)

		snapshot [
			identity_key
		] = {
			"held": held,
			"edges": edges
		}

		input_row [
			"edges"
		] = []

		source [
			raw_identity_key
		] = input_row

	hot_row [
		"input_by_identity"
	] = source

	return snapshot


func _service_continuous_session_worker_step(
	session_id: String,
	fixed_delta: float
) -> void:
	continuous_mutex.lock()

	var hot_row: Dictionary = _dict(
		continuous_hot_sessions.get(
			session_id,
			{}
		)
	)

	if (
		hot_row.is_empty()
		or bool(
			hot_row.get(
				"complete",
				false
			)
		)
	):
		continuous_mutex.unlock()
		return

	var provider_object: Object = hot_row.get(
		"provider_object",
		null
	)

	var provider_state: Dictionary = _dict(
		hot_row.get(
			"provider_state",
			{}
		)
	)

	var context: Dictionary = _dict(
		hot_row.get(
			"context",
			{}
		)
	)

	var continuous_contract: Dictionary = _dict(
		hot_row.get(
			"continuous_contract",
			{}
		)
	)

	var step_method: String = str(
		continuous_contract.get(
			"step_method",
			"advance_continuous_simulation"
		)
	).strip_edges()

	if step_method == "":
		step_method = "advance_continuous_simulation"

	var observation_sink: Callable = hot_row.get(
		"observation_sink",
		Callable()
	)

	var completion_sink: Callable = hot_row.get(
		"completion_sink",
		Callable()
	)

	var input_snapshot: Dictionary = (
		_consume_continuous_input_snapshot_locked(
			hot_row
		)
	)

	continuous_hot_sessions [
		session_id
	] = hot_row

	continuous_mutex.unlock()

	if (
		provider_object == null
		or not provider_object.has_method(
			step_method
		)
	):
		return

	var report_raw: Variant = provider_object.call(
		step_method,
		provider_state,
		input_snapshot,
		fixed_delta,
		context
	)

	if typeof(
		report_raw
	) != TYPE_DICTIONARY:
		return

	var report: Dictionary = (
		report_raw as Dictionary
	)

	if not bool(
		report.get(
			"success",
			false
		)
	):
		return

	var next_state: Dictionary = _dict(
		report.get(
			"provider_state",
			provider_state
		)
	)

	var events: Array = _array(
		report.get(
			"events",
			[]
		)
	)

	var complete: bool = bool(
		report.get(
			"complete",
			false
		)
	)

	var step_count: int = 0
	var observation_revision: int = 0
	var publish_observation: bool = false
	var publish_checkpoint: bool = false
	var checkpoint_state: Dictionary = {}
	var checkpoint_events: Array = []

	continuous_mutex.lock()

	hot_row = _dict(
		continuous_hot_sessions.get(
			session_id,
			{}
		)
	)

	if hot_row.is_empty():
		continuous_mutex.unlock()
		return

	hot_row [
		"provider_state"
	] = next_state

	step_count = int(
		hot_row.get(
			"step_count",
			0
		)
	) + 1

	hot_row [
		"step_count"
	] = step_count

	var pending_events: Array = _array(
		hot_row.get(
			"pending_events",
			[]
		)
	)

	for raw_event in events:
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		pending_events.append(
			(raw_event as Dictionary).duplicate(true)
		)

	while pending_events.size() > MAX_SESSION_EVENTS:
		pending_events.pop_front()

	hot_row [
		"pending_events"
	] = pending_events

	publish_observation = (
		step_count
		% CONTINUOUS_OBSERVATION_EVERY_STEPS
		== 0
	)

	if publish_observation:
		observation_revision = int(
			hot_row.get(
				"observation_revision",
				0
			)
		) + 1

		hot_row [
			"observation_revision"
		] = observation_revision

	publish_checkpoint = (
		not complete
		and step_count
		% CONTINUOUS_CHECKPOINT_EVERY_STEPS
		== 0
	)

	if publish_checkpoint:
		checkpoint_state = next_state.duplicate(true)
		checkpoint_events = pending_events.duplicate(true)

		hot_row [
			"pending_events"
		] = []

	if complete:
		hot_row [
			"complete"
		] = true

		checkpoint_state = next_state.duplicate(true)
		checkpoint_events = pending_events.duplicate(true)

		hot_row [
			"pending_events"
		] = []

	continuous_hot_sessions [
		session_id
	] = hot_row

	continuous_mutex.unlock()

	if publish_observation:
		var projection_raw: Variant = provider_object.call(
			"ui_projection",
			next_state
		)

		var projection: Dictionary = (
			projection_raw as Dictionary
			if typeof(
				projection_raw
			) == TYPE_DICTIONARY
			else {}
		)




		_queue_latest_continuous_observation(
			{
				"session_id": session_id,
				"provider_id": str(
					hot_row.get(
						"provider_id",
						""
					)
				),
				"revision": observation_revision,
				"simulation_step": int(
					next_state.get(
						"simulation_step",
						step_count
					)
				),
				"ui_projection": projection,
				"status_text": str(
					next_state.get(
						"last_event_text",
						"Stick Fighter is live."
					)
				),
				"complete": complete
			},
			observation_sink
		)

	if publish_checkpoint:
		call_deferred(
			"_commit_continuous_checkpoint_main",
			session_id,
			checkpoint_state,
			checkpoint_events,
			context
		)

	if complete:
		var result_raw: Variant = provider_object.call(
			"result_contract",
			next_state
		)

		var result_contract: Dictionary = (
			result_raw as Dictionary
			if typeof(
				result_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var final_projection_raw: Variant = provider_object.call(
			"ui_projection",
			next_state
		)

		var final_projection: Dictionary = (
			final_projection_raw as Dictionary
			if typeof(
				final_projection_raw
			) == TYPE_DICTIONARY
			else {}
		)

		call_deferred(
			"_complete_continuous_session_main",
			session_id,
			checkpoint_state,
			checkpoint_events,
			result_contract,
			final_projection,
			context,
			observation_sink,
			completion_sink
		)
func _queue_latest_continuous_observation(
	packet: Dictionary,
	observation_sink: Callable
) -> void:
	var session_id: String = str(
		packet.get(
			"session_id",
			""
		)
	).strip_edges()

	if session_id == "":
		return

	var should_arm: bool = false

	continuous_mutex.lock()



	continuous_pending_observation_by_session [
		session_id
	] = {
		"packet": packet.duplicate(false),
		"observation_sink": observation_sink
	}

	if not continuous_observation_delivery_armed:
		continuous_observation_delivery_armed = true
		should_arm = true

	continuous_mutex.unlock()

	if should_arm:
		call_deferred(
			"_flush_latest_continuous_observations_main"
		)
func _flush_latest_continuous_observations_main() -> void:
	var deliveries: Array = []
	var has_more: bool = false

	continuous_mutex.lock()

	var pending_keys: Array = (
		continuous_pending_observation_by_session.keys()
	)

	var delivery_count: int = mini(
		CONTINUOUS_OBSERVATION_DELIVERY_QUANTUM,
		pending_keys.size()
	)

	for index in range(
		delivery_count
	):
		var session_id: String = str(
			pending_keys [
				index
			]
		)

		var pending_row: Dictionary = _dict(
			continuous_pending_observation_by_session.get(
				session_id,
				{}
			)
		)

		continuous_pending_observation_by_session.erase(
			session_id
		)

		if not pending_row.is_empty():
			deliveries.append(
				pending_row
			)

	has_more = (
		not continuous_pending_observation_by_session.is_empty()
	)

	if not has_more:
		continuous_observation_delivery_armed = false

	continuous_mutex.unlock()

	for raw_delivery in deliveries:
		var delivery: Dictionary = _dict(
			raw_delivery
		)

		var packet: Dictionary = _dict(
			delivery.get(
				"packet",
				{}
			)
		)

		var observation_sink: Callable = delivery.get(
			"observation_sink",
			Callable()
		)

		if packet.is_empty():
			continue

		_deliver_continuous_observation_main(
			packet,
			observation_sink
		)




	if has_more:
		var tree:= (
			Engine.get_main_loop() as SceneTree
		)

		if tree != null:
			tree.process_frame.connect(
				Callable(
					self,
					"_flush_latest_continuous_observations_main"
				),
				CONNECT_ONE_SHOT
			)
		else:
			call_deferred(
				"_flush_latest_continuous_observations_main"
			)

	set_meta(
		"continuous_observation_delivery_quantum",
		CONTINUOUS_OBSERVATION_DELIVERY_QUANTUM
	)
	set_meta(
		"continuous_observation_deferred_backlog_allowed",
		false
	)
	set_meta(
		"continuous_observation_latest_wins_upstream",
		true
	)
func project_active_session_cursor(
	identity_key: String
) -> Dictionary:
	_ensure_state()

	var clean_identity_key: String = str(
		identity_key
	).strip_edges()

	if clean_identity_key == "":
		return {}

	var session_id: String = str(
		_dict(
			state.get(
				"active_session_by_identity",
				{}
			)
		).get(
			clean_identity_key,
			""
		)
	).strip_edges()

	if session_id == "":
		return {}

	var session_row: Dictionary = _dict(
		_dict(
			state.get(
				"sessions",
				{}
			)
		).get(
			session_id,
			{}
		)
	)

	if session_row.is_empty():
		return {}

	return {
		"session_id": session_id,
		"provider_id": _id(
			str(
				session_row.get(
					"provider_id",
					""
				)
			)
		),
		"status": str(
			session_row.get(
				"status",
				"active"
			)
		),
		"continuous_runtime": bool(
			session_row.get(
				"continuous_runtime",
				false
			)
		),
	}

func _deliver_continuous_observation_main(
	packet: Dictionary,
	observation_sink: Callable
) -> void:
	if observation_sink.is_valid():
		observation_sink.call(
			packet
		)
func _commit_continuous_checkpoint_main(
	session_id: String,
	provider_state: Dictionary,
	events: Array,
	context: Dictionary
) -> Dictionary:
	_ensure_state()

	var clean_session_id: String = _id(
		session_id
	)

	var sessions: Dictionary = _dict(
		state.get(
			"sessions",
			{}
		)
	)

	var session_row: Dictionary = _dict(
		sessions.get(
			clean_session_id,
			{}
		)
	).duplicate(false)

	if session_row.is_empty():
		return _failure(
			"unknown_session",
			"The continuous MiniGame session no longer exists."
		)

	if str(
		session_row.get(
			"status",
			""
		)
	) == "completed":
		return _failure(
			"session_already_completed",
			"Completed MiniGame reality cannot accept a checkpoint."
		)

	session_row [
		"provider_state"
	] = provider_state.duplicate(true)
	session_row [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	var event_log: Array = _array(
		session_row.get(
			"event_log",
			[]
		)
	)

	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = (
			raw_event as Dictionary
		).duplicate(true)

		event [
			"sequence"
		] = event_log.size()
		event [
			"committed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		event_log.append(
			event
		)

	while event_log.size() > MAX_SESSION_EVENTS:
		event_log.pop_front()

	session_row [
		"event_log"
	] = event_log
	session_row [
		"last_commit_context"
	] = _serializable_dictionary(
		context
	)

	sessions [
		clean_session_id
	] = session_row
	state [
		"sessions"
	] = sessions

	_publish_session_delta(
		clean_session_id,
		session_row
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "continuous_checkpoint_committed",
		"session_id": clean_session_id,
	}


func _complete_continuous_session_main(
	session_id: String,
	provider_state: Dictionary,
	events: Array,
	result_contract: Dictionary,
	final_projection: Dictionary,
	context: Dictionary,
	observation_sink: Callable,
	completion_sink: Callable
) -> void:
	_commit_continuous_checkpoint_main(
		session_id,
		provider_state,
		events,
		context
	)

	var clean_session_id: String = _id(
		session_id
	)

	var sessions: Dictionary = _dict(
		state.get(
			"sessions",
			{}
		)
	)

	var session_row: Dictionary = _dict(
		sessions.get(
			clean_session_id,
			{}
		)
	).duplicate(false)

	if session_row.is_empty():
		return

	session_row [
		"status"
	] = "completed"
	session_row [
		"completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	session_row [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	session_row [
		"winner_identity_key"
	] = str(
		result_contract.get(
			"winner_identity_key",
			""
		)
	)
	session_row [
		"result_contract"
	] = result_contract.duplicate(true)

	sessions [
		clean_session_id
	] = session_row
	state [
		"sessions"
	] = sessions

	var active_by_identity: Dictionary = _dict(
		state.get(
			"active_session_by_identity",
			{}
		)
	)

	for raw_participant in _array(
		session_row.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if str(
			active_by_identity.get(
				identity_key,
				""
			)
		) == clean_session_id:
			active_by_identity.erase(
				identity_key
			)

	state [
		"active_session_by_identity"
	] = active_by_identity

	_publish_session_delta(
		clean_session_id,
		session_row
	)

	continuous_mutex.lock()

	var hot_row: Dictionary = _dict(
		continuous_hot_sessions.get(
			clean_session_id,
			{}
		)
	)

	var revision: int = int(
		hot_row.get(
			"observation_revision",
			0
		)
	) + 1

	continuous_hot_sessions.erase(
		clean_session_id
	)



	continuous_pending_observation_by_session.erase(
		clean_session_id
	)

	continuous_mutex.unlock()

	var final_packet: Dictionary = {
		"session_id": clean_session_id,
		"provider_id": str(
			session_row.get(
				"provider_id",
				""
			)
		),
		"revision": revision,
		"simulation_step": int(
			provider_state.get(
				"simulation_step",
				0
			)
		),
		"ui_projection": final_projection,
		"status_text": str(
			final_projection.get(
				"headline",
				"Match complete."
			)
		),
		"complete": true
	}

	if observation_sink.is_valid():
		observation_sink.call(
			final_packet
		)

	if completion_sink.is_valid():
		completion_sink.call({
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mode": "continuous_session_completed",
			"session_id": clean_session_id,
			"provider_id": str(
				session_row.get(
					"provider_id",
					""
				)
			),
			"session": session_row.duplicate(true),
			"result_contract": result_contract.duplicate(true),
			"ui_projection": final_projection,
			"revision": revision,
			"simulation_step": int(
				provider_state.get(
					"simulation_step",
					0
				)
			),
			"events": events.duplicate(true),
			"context": context.duplicate(false),
		})

func session(session_id: String) -> Dictionary:
	_ensure_state()
	return _dict(_dict(state.get("sessions", {})).get(_id(session_id), {})).duplicate(true)


func session_for_identity(identity_key: String) -> Dictionary:
	_ensure_state()
	var session_id: String = str(
		_dict(state.get("active_session_by_identity", {})).get(identity_key, "")
	)
	return session(session_id)


func commit_session_state(
	session_id: String,
	provider_state: Dictionary,
	events: Array = [],
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var clean_session_id: String = _id(
		session_id
	)
	var sessions: Dictionary = _dict(
		state.get(
			"sessions",
			{}
		)
	)
	var session_row: Dictionary = _dict(
		sessions.get(
			clean_session_id,
			{}
		)
	)

	if session_row.is_empty():
		return _failure(
			"unknown_session",
			"The minigame session no longer exists."
		)

	if str(
		session_row.get(
			"status",
			""
		)
	) == "completed":
		return _failure(
			"session_already_completed",
			"Completed minigame reality cannot accept additional actions."
		)

	session_row [
		"provider_state"
	] = provider_state.duplicate(true)
	session_row [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	var event_log: Array = _array(
		session_row.get(
			"event_log",
			[]
		)
	)

	for raw_event in events:
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = (
			raw_event as Dictionary
		).duplicate(true)

		event [
			"sequence"
		] = event_log.size()

		event [
			"committed_at_ms"
		] = int(
			event.get(
				"committed_at_ms",
				Time.get_ticks_msec()
			)
		)

		event_log.append(
			event
		)

	while event_log.size() > MAX_SESSION_EVENTS:
		event_log.pop_front()

	session_row [
		"event_log"
	] = event_log
	session_row [
		"last_commit_context"
	] = _serializable_dictionary(
		context
	)

	sessions [
		clean_session_id
	] = session_row.duplicate(true)
	state [
		"sessions"
	] = sessions

	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "minigame_session_state_committed",
		"session_id": clean_session_id,
		"session": session_row.duplicate(true),
		"ui_is_renderer_only": true
	}

func add_spectator(session_id: String, spectator: Dictionary) -> Dictionary:
	_ensure_state()
	var sessions: Dictionary = _dict(state.get("sessions", {}))
	var session_row: Dictionary = _dict(sessions.get(_id(session_id), {}))

	if session_row.is_empty():
		return _failure("unknown_session", "The requested minigame session is unavailable.")

	var spectators: Array = _array(session_row.get("spectators", []))
	var identity_key: String = str(spectator.get("identity_key", "")).strip_edges()

	for raw_row in spectators:
		var row: Dictionary = _dict(raw_row)
		if str(row.get("identity_key", "")) == identity_key:
			return {
				"success": true,
				"mode": "spectator_already_attached",
				"session": session_row.duplicate(true)
			}

	spectators.append(spectator.duplicate(true))
	session_row ["spectators"] = spectators
	session_row ["updated_at_ms"] = int(Time.get_ticks_msec())
	sessions [_id(session_id)] = session_row.duplicate(true)
	state ["sessions"] = sessions
	_publish_state()

	return { "success": true, "mode": "spectator_attached", "session": session_row.duplicate(true)}


func complete_session(session_id: String, result_contract: Dictionary) -> Dictionary:
	_ensure_state()
	var clean_session_id: String = _id(session_id)
	var sessions: Dictionary = _dict(state.get("sessions", {}))
	var session_row: Dictionary = _dict(sessions.get(clean_session_id, {}))

	if session_row.is_empty():
		return _failure(
			"unknown_session", "The minigame session could not be completed because it is absent."
		)

	session_row ["status"] = "completed"
	session_row ["completed_at_ms"] = int(Time.get_ticks_msec())
	session_row ["updated_at_ms"] = int(Time.get_ticks_msec())
	session_row ["winner_identity_key"] = str(result_contract.get("winner_identity_key", ""))
	session_row ["result_contract"] = result_contract.duplicate(true)
	sessions [clean_session_id] = session_row.duplicate(true)
	state ["sessions"] = sessions

	var active_by_identity: Dictionary = _dict(state.get("active_session_by_identity", {}))
	for raw_participant in _array(session_row.get("participants", [])):
		var participant: Dictionary = _dict(raw_participant)
		var identity_key: String = str(participant.get("identity_key", ""))
		if str(active_by_identity.get(identity_key, "")) == clean_session_id:
			active_by_identity.erase(identity_key)
	state ["active_session_by_identity"] = active_by_identity
	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "minigame_session_completed",
		"session_id": clean_session_id,
		"session": session_row.duplicate(true),
		"result_contract": result_contract.duplicate(true),
		"ui_is_renderer_only": true
	}


func active_sessions() -> Array:
	_ensure_state()
	var out: Array = []
	for raw_session in _dict(state.get("sessions", {})).values():
		var session_row: Dictionary = _dict(raw_session)
		if str(session_row.get("status", "")) == "active":
			out.append(session_row.duplicate(true))
	return out


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"session_count": _dict(state.get("sessions", {})).size()
	}


func _next_session_id(provider_id: String) -> String:
	var sequence: int = int(state.get("session_sequence", 0)) + 1
	state ["session_sequence"] = sequence
	return "minigame:%s:%d:%d" % [_id(provider_id), int(Time.get_unix_time_from_system()), sequence]


func _prune_sessions() -> void:
	var sessions: Dictionary = _dict(state.get("sessions", {}))
	if sessions.size() <= MAX_SESSIONS:
		return

	var rows: Array = sessions.values()
	rows.sort_custom(Callable(self, "_session_oldest_first"))
	while rows.size() > MAX_SESSIONS:
		var removed: Dictionary = _dict(rows.pop_front())
		sessions.erase(str(removed.get("session_id", "")))
	state ["sessions"] = sessions


func _session_oldest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) < int(b.get("created_at_ms", 0))


func _ensure_state() -> void:
	if state.is_empty():
		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
			and typeof(gs.scenario_state.get(STATE_KEY, {})) == TYPE_DICTIONARY
		):
			state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)

	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"session_sequence": 0,
			"sessions": {},
			"active_session_by_identity": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}

	if typeof(state.get("sessions", {})) != TYPE_DICTIONARY:
		state ["sessions"] = {}
	if typeof(state.get("active_session_by_identity", {})) != TYPE_DICTIONARY:
		state ["active_session_by_identity"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		STATE_KEY
	] = state.duplicate(true)


func _serializable_dictionary(value: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in value.keys():
		var key: String = str(raw_key)
		var raw_value: Variant = value.get(raw_key)
		if raw_value is Object or typeof(raw_value) == TYPE_CALLABLE:
			continue
		out [key] = raw_value
	return out


func _dictionary_array(value: Array) -> Array:
	var out: Array = []
	for raw_row in value:
		if typeof(raw_row) == TYPE_DICTIONARY:
			out.append((raw_row as Dictionary).duplicate(true))
	return out


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


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