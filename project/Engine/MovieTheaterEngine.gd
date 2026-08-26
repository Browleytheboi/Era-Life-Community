extends Resource
class_name MovieTheaterEngine

const CONTRACT_SCHEMA:= "eralife.movie_theater_engine"
const CONTRACT_VERSION:= 1

var gs
var movie_theater_sessions_by_actor_id: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func bootstrap_ui_contracts() -> Dictionary:
	if gs == null or gs.ui_contract_engine == null:
		return { "success": false, "reason": "UIContractEngine unavailable."}
	if not gs.ui_contract_engine.has_method("ingest_pack"):
		return { "success": false, "reason": "UIContractEngine cannot ingest packs."}
	return gs.ui_contract_engine.ingest_pack(build_ui_contract_pack())

func build_ui_contract_pack() -> Dictionary:
	return {
		"id": "eralife_movie_theater_ui_pack",
		"data_sources": [
			{ "id": "movie.theaters", "engine_property": "movie_theater_engine", "method": "get_movie_theater_rows", "call_mode": "context"},
			{ "id": "movie.selection", "engine_property": "movie_theater_engine", "method": "get_movie_selection_rows", "call_mode": "context"},
			{ "id": "movie.lobby", "engine_property": "movie_theater_engine", "method": "get_movie_lobby_rows", "call_mode": "context"},
			{ "id": "movie.concessions", "engine_property": "movie_theater_engine", "method": "get_movie_concession_rows", "call_mode": "context"},
			{ "id": "movie.auditorium", "engine_property": "movie_theater_engine", "method": "get_movie_auditorium_rows", "call_mode": "context"},
			{ "id": "movie.friction", "engine_property": "movie_theater_engine", "method": "get_movie_friction_rows", "call_mode": "context"}
		],
		"ui_surfaces": [
			{
				"surface_id": "movie_theater_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Movies",
				"title": "Movie Theater",
				"subtitle": "Choose a theater, buy a ticket, survive the lobby line, grab concessions, then deal with live audience friction during the movie.",
				"icon": "🎬",
				"sort_priority": 33,
				"persistent_state": true,
				"sections": [
					{ "id": "theaters", "label": "Theaters", "is_default": true, "data_source": "movie.theaters"},
					{ "id": "movies", "label": "Movie Selection", "data_source": "movie.selection"},
					{ "id": "lobby", "label": "Lobby Line", "data_source": "movie.lobby"},
					{ "id": "concessions", "label": "Concessions", "data_source": "movie.concessions"},
					{ "id": "auditorium", "label": "Theater", "data_source": "movie.auditorium"},
					{ "id": "friction", "label": "Social Friction", "data_source": "movie.friction"}
				]
			}
		]
	}

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"movie_theater_sessions_by_actor_id": movie_theater_sessions_by_actor_id.duplicate(true),
		"last_report": last_report.duplicate(true)
	})

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "MovieTheaterEngine import_state expected a Dictionary."}
	movie_theater_sessions_by_actor_id = _safe_dictionary(data.get("movie_theater_sessions_by_actor_id", {}))
	last_report = _safe_dictionary(data.get("last_report", {}))
	return { "success": true, "session_count": movie_theater_sessions_by_actor_id.size()}

func yearly_tick() -> void:
	if gs == null:
		return

	if gs.runtime_contract_engine != null and gs.runtime_contract_engine.has_method("emit_movie_theater_contracts_for_current_world"):
		gs.runtime_contract_engine.emit_movie_theater_contracts_for_current_world({
			"source": "movie_theater_yearly_tick"
		})

	var current_year: int = int(gs.year)
	var stale_actor_keys: Array = []
	for raw_key in movie_theater_sessions_by_actor_id.keys():
		var actor_key: String = str(raw_key)
		var session: Dictionary = _safe_dictionary(movie_theater_sessions_by_actor_id.get(actor_key, {}))
		if current_year - int(session.get("updated_year", current_year)) > 1:
			stale_actor_keys.append(actor_key)
	for actor_key in stale_actor_keys:
		movie_theater_sessions_by_actor_id.erase(actor_key)

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Movie theater command envelope is empty."}
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))
	var actor: Person = _actor_from_context(payload)
	return resolve_movie_action(actor, command_id, payload)

func resolve_movie_action(actor: Person, action_id: String, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var clean_action: String = str(action_id).strip_edges().to_lower()
	var parts:= clean_action.split(":")
	var verb: String = str(parts [0]).strip_edges().to_lower() if parts.size() > 0 else clean_action
	match verb:
		"movie_theater_select", "movie.theater.select":
			var theater_id: String = str(payload.get("theater_id", "")).strip_edges()
			if theater_id == "" and parts.size() >= 2:
				theater_id = str(parts [1]).strip_edges()
			return select_theater(actor, theater_id, payload)
		"movie_select", "movie.select", "movie_select_movie":
			var movie_id: String = str(payload.get("movie_id", "")).strip_edges()
			if movie_id == "" and parts.size() >= 2:
				movie_id = str(parts [parts.size() - 1]).strip_edges()
			return select_movie(actor, movie_id, payload)
		"movie_stand_line", "movie.line.stand":
			return stand_in_ticket_line(actor, payload)
		"movie_advance_line", "movie.line.advance":
			return advance_ticket_line(actor, payload)
		"movie_buy_ticket", "movie.ticket.buy":
			return buy_ticket(actor, payload)
		"movie_buy_concession", "movie.concession.buy":
			var concession_id: String = str(payload.get("concession_id", "")).strip_edges()
			if concession_id == "" and parts.size() >= 2:
				concession_id = str(parts [1]).strip_edges()
			return buy_concession(actor, concession_id, payload)
		"movie_enter_auditorium", "movie.auditorium.enter":
			return enter_auditorium(actor, payload)
		"movie_generate_friction", "movie.friction.generate":
			return generate_friction_event(actor, payload)
		"movie_friction_response", "movie.friction.response":
			var event_id: String = str(payload.get("event_id", "")).strip_edges()
			var choice_id: String = str(payload.get("choice_id", "")).strip_edges()
			if event_id == "" and parts.size() >= 2:
				event_id = str(parts [1]).strip_edges()
			if choice_id == "" and parts.size() >= 3:
				choice_id = str(parts [2]).strip_edges()
			return resolve_friction_response(actor, event_id, choice_id, payload)
		"movie_leave", "movie.theater.leave":
			return leave_theater(actor, payload)
		"movie_back":
			var target_section: String = str(payload.get("target_section", "theaters")).strip_edges()
			if parts.size() >= 2:
				target_section = str(parts [1]).strip_edges()
			return _section_only_report(actor, target_section, "Movie theater navigation updated.")
		_:
			return { "success": false, "reason": "Unknown movie theater action.", "action_id": clean_action}

func movie_theater_surface_state_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	return _session_for_actor(actor).duplicate(true)

func get_movie_theater_presence_summary(theater_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_theater: String = str(theater_id).strip_edges()
	if clean_theater == "":
		var actor: Person = _actor_from_context(context)
		var session: Dictionary = _session_for_actor(actor)
		clean_theater = str(session.get("theater_id", "")).strip_edges()

	if clean_theater == "":
		return { "success": false, "people_in_building": 0, "zone_counts": {}}

	var runtime_contract: Dictionary = _runtime_contract_for_theater(clean_theater, context)
	if not runtime_contract.is_empty() and gs != null and gs.shared_public_space_engine != null and gs.shared_public_space_engine.has_method("import_runtime_contract"):
		gs.shared_public_space_engine.import_runtime_contract(runtime_contract)

	if gs == null or gs.shared_public_space_engine == null:
		if not runtime_contract.is_empty():
			return _presence_summary_from_runtime_contract(runtime_contract)
		return { "success": false, "people_in_building": 0, "zone_counts": {}}

	return gs.shared_public_space_engine.presence_summary("movie_theater", clean_theater, _shared_space_context(clean_theater, context))
func get_movie_theater_rows(context: Dictionary = {}) -> Array:
	var rows: Array = []
	var _actor: Person = _actor_from_context(context)
	var era_name: String = _era_name_from_context(context)
	for raw_theater in get_theaters_for_era(era_name):
		if typeof(raw_theater) != TYPE_DICTIONARY:
			continue
		var theater: Dictionary = raw_theater as Dictionary
		var theater_id: String = str(theater.get("id", "")).strip_edges()
		var presence: Dictionary = get_movie_theater_presence_summary(theater_id, context)
		var runtime_contract: Dictionary = _runtime_contract_for_theater(theater_id, context)
		var runtime_movie: Dictionary = _runtime_movie_from_contract(runtime_contract)
		var lifecycle: Dictionary = _safe_dictionary(runtime_contract.get("lifecycle", {}))
		var live_line: String = "Runtime contract: inactive"
		if not runtime_contract.is_empty():
			live_line = "Runtime contract: %s • %s • %s active tension(s)" % [
				str(lifecycle.get("phase", "active")).capitalize(),
				str(runtime_movie.get("title", "Live showing")),
				str(_safe_array(runtime_contract.get("active_friction_events", [])).size())
			]

		rows.append({
			"id": theater_id,
			"label": str(theater.get("name", theater_id)),
			"description": "%s\n\n%s\nPeople in building: %d\nTicket: $%.2f" % [str(theater.get("description", "Movie theater.")), live_line, int(presence.get("people_in_building", int(theater.get("baseline_population", 12)))), float(theater.get("ticket_price", 12.0))],
			"kind": "movie_theater",
			"sort_priority": int(theater.get("sort_priority", 50)),
			"actions": [
				{ "id": "movie_theater_select:%s" % theater_id, "label": "Enter Theater", "kind": "packet", "style": "primary", "payload": { "theater_id": theater_id}}
			]
		})
	if rows.is_empty():
		rows.append({ "id": "no_movies", "label": "No movie theaters are available in this era.", "description": "Movie theaters unlock in the Modern and Future eras."})
	return rows

func get_movie_selection_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	var session: Dictionary = _session_for_actor(actor)
	var theater_id: String = str(session.get("theater_id", "")).strip_edges()
	if theater_id == "":
		return [_locked_row("Choose a theater first.", "Go back to Theaters and enter a building before picking a movie.")]
	var rows: Array = []
	for raw_movie in _movies_for_theater(theater_id):
		if typeof(raw_movie) != TYPE_DICTIONARY:
			continue
		var movie: Dictionary = raw_movie as Dictionary
		var movie_id: String = str(movie.get("id", "")).strip_edges()
		var genre: String = str(movie.get("genre", "Drama")).strip_edges()
		rows.append({
			"id": movie_id,
			"label": "%s • %s" % [str(movie.get("title", movie_id)), genre],
			"description": "%s\n\nCrowd influence: %s" % [str(movie.get("description", "A movie is playing.")), _genre_crowd_description(genre)],
			"kind": "movie_selection",
			"actions": [
				{ "id": "movie_select:%s" % movie_id, "label": "Choose This Movie", "kind": "packet", "style": "primary", "payload": { "movie_id": movie_id}}
			]
		})
	return rows

func get_movie_lobby_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	var session: Dictionary = _session_for_actor(actor)
	if str(session.get("movie_id", "")).strip_edges() == "":
		return [_locked_row("Choose a movie first.", "Pick what you are seeing before entering the lobby line.")]
	var theater_id: String = str(session.get("theater_id", "")).strip_edges()
	var presence: Dictionary = get_movie_theater_presence_summary(theater_id, context)
	var line_position: int = int(session.get("line_position", -1))
	var line_ready: bool = bool(session.get("line_ready", false))
	var ticket_bought: bool = bool(session.get("ticket_bought", false))
	var actions: Array = []
	if ticket_bought:
		actions.append({ "id": "movie_back:concessions", "label": "Go To Concessions", "kind": "packet", "style": "primary", "payload": { "target_section": "concessions"}})
	elif line_position < 0:
		actions.append({ "id": "movie_stand_line", "label": "Stand In Ticket Line", "kind": "packet", "style": "primary"})
	elif line_ready:
		actions.append({ "id": "movie_buy_ticket", "label": "Buy Ticket", "kind": "packet", "style": "success"})
	else:
		actions.append({ "id": "movie_advance_line", "label": "Wait For Line To Move", "kind": "packet", "style": "primary"})
	actions.append({ "id": "movie_back:movies", "label": "Back", "kind": "packet", "style": "secondary", "payload": { "target_section": "movies"}})
	var status: String = "You are in the lobby."
	if line_position >= 0 and not line_ready:
		status = "You are standing in line. %d people are ahead of you." % line_position
	elif line_ready:
		status = "The cashier is ready for you."
	elif ticket_bought:
		status = "Ticket bought. You can grab food or enter the theater."
	return [{
		"id": "movie_lobby_status",
		"label": "Lobby",
		"description": "%s\n\nPeople in building: %d\nLobby: %d\nLine: %d" % [status, int(presence.get("people_in_building", 0)), int(_safe_dictionary(presence.get("zone_counts", {})).get("lobby", 0)), int(_safe_dictionary(presence.get("zone_counts", {})).get("line", 0))],
		"kind": "movie_lobby_state",
		"actions": actions
	}]

func get_movie_concession_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	var session: Dictionary = _session_for_actor(actor)
	if not bool(session.get("ticket_bought", false)):
		return [_locked_row("Buy a ticket first.", "The concessions section opens after the cashier sells you a ticket.")]
	var rows: Array = []
	for raw_item in _concession_items():
		var item: Dictionary = raw_item as Dictionary
		var item_id: String = str(item.get("id", "")).strip_edges()
		rows.append({
			"id": item_id,
			"label": "%s • $%.2f" % [str(item.get("name", item_id)), float(item.get("price", 0.0))],
			"description": str(item.get("description", "Movie snack.")),
			"kind": "movie_concession_item",
			"actions": [
				{ "id": "movie_buy_concession:%s" % item_id, "label": "Buy", "kind": "packet", "style": "primary", "payload": { "concession_id": item_id}}
			]
		})
	rows.append({
		"id": "enter_auditorium",
		"label": "Enter The Theater",
		"description": "Take your seat and let the shared audience friction engine start breathing.",
		"kind": "movie_enter_room",
		"actions": [
			{ "id": "movie_enter_auditorium", "label": "Find Seat", "kind": "packet", "style": "success"},
			{ "id": "movie_back:lobby", "label": "Back To Lobby", "kind": "packet", "style": "secondary", "payload": { "target_section": "lobby"}}
		]
	})
	return rows

func get_movie_auditorium_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	var session: Dictionary = _session_for_actor(actor)
	if not bool(session.get("ticket_bought", false)):
		return [_locked_row("You need a ticket first.", "Buy a ticket before entering the theater.")]
	var movie: Dictionary = _movie_by_id(str(session.get("theater_id", "")), str(session.get("movie_id", "")))
	var active_event: Dictionary = _safe_dictionary(session.get("active_friction_event", {}))
	var actions: Array = []
	if active_event.is_empty():
		actions.append({ "id": "movie_generate_friction", "label": "Let The Movie Play", "kind": "packet", "style": "primary"})
	else:
		actions.append({ "id": "movie_back:friction", "label": "Respond To Friction", "kind": "packet", "style": "danger", "payload": { "target_section": "friction"}})
	actions.append({ "id": "movie_leave", "label": "Leave Theater", "kind": "packet", "style": "secondary"})
	var concessions: Array = _safe_array(session.get("concessions", []))
	return [{
		"id": "movie_room_state",
		"label": "Inside The Theater • %s" % str(movie.get("title", "Movie")),
		"description": "Genre: %s\nSnacks: %d\nResolved friction events: %d\n\n%s" % [str(movie.get("genre", "Drama")), concessions.size(), _safe_array(session.get("resolved_friction_events", [])).size(), _genre_crowd_description(str(movie.get("genre", "Drama")))],
		"kind": "movie_auditorium_state",
		"actions": actions
	}]

func get_movie_friction_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	var session: Dictionary = _session_for_actor(actor)
	var active_event: Dictionary = _safe_dictionary(session.get("active_friction_event", {}))
	if active_event.is_empty():
		return [{
			"id": "no_friction",
			"label": "No active friction right now.",
			"description": "Let the movie play to generate the next shared-audience scenario.",
			"actions": [
				{ "id": "movie_generate_friction", "label": "Let The Movie Play", "kind": "packet", "style": "primary"},
				{ "id": "movie_back:auditorium", "label": "Back", "kind": "packet", "style": "secondary", "payload": { "target_section": "auditorium"}}
			]
		}]
	var event_id: String = str(active_event.get("event_id", "friction"))
	var actions: Array = []
	for raw_choice in _safe_array(active_event.get("choices", [])):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = raw_choice as Dictionary
		var choice_id: String = str(choice.get("id", "")).strip_edges()
		if choice_id == "":
			continue
		actions.append({
			"id": "movie_friction_response:%s:%s" % [event_id, choice_id],
			"label": str(choice.get("label", choice_id)),
			"kind": "packet",
			"style": str(choice.get("style", "primary")),
			"payload": { "event_id": event_id, "choice_id": choice_id}
		})
	return [{
		"id": event_id,
		"label": str(active_event.get("title", "Movie Theater Friction")),
		"description": "%s\n\nIntensity: %d/10\nPersonality influence: %s\nEscalation risk: %s" % [str(active_event.get("description", "Something is happening in the theater.")), int(active_event.get("intensity", 1)), str(active_event.get("personality_influence", "medium")), str(active_event.get("escalation_risk", "low"))],
		"kind": "movie_social_friction_event",
		"stat_bars": [
			{ "label": "Intensity", "value": int(active_event.get("intensity", 1)), "max": 10},
			{ "label": "Escalation", "value": int(active_event.get("escalation_score", 1)), "max": 10}
		],
		"actions": actions
	}]

func select_theater(actor: Person, theater_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var theater: Dictionary = get_theater(theater_id)
	if theater.is_empty():
		return { "success": false, "reason": "Movie theater not found."}

	var runtime_contract: Dictionary = _runtime_contract_for_theater(theater_id, context)
	var runtime_movie: Dictionary = _runtime_movie_from_contract(runtime_contract)
	var runtime_event: Dictionary = _runtime_active_friction_from_contract(runtime_contract)

	var session: Dictionary = _session_for_actor(actor)
	session.clear()
	session ["actor_id"] = int(actor.id)
	session ["theater_id"] = theater_id
	session ["theater_name"] = str(theater.get("name", theater_id))
	session ["runtime_contract_id"] = str(runtime_contract.get("contract_id", ""))
	session ["runtime_contract_state"] = str(runtime_contract.get("state", "active"))

	if runtime_movie.is_empty():
		session ["movie_id"] = ""
		session ["movie_title"] = ""
		session ["genre"] = ""
	else:
		session ["movie_id"] = str(runtime_movie.get("id", ""))
		session ["movie_title"] = str(runtime_movie.get("title", "Live Showing"))
		session ["genre"] = str(runtime_movie.get("genre", "Drama"))

	session ["ticket_bought"] = false
	session ["line_position"] = -1
	session ["line_ready"] = false
	session ["concessions"] = []
	session ["active_friction_event"] = runtime_event
	session ["resolved_friction_events"] = []
	session ["kicked_out"] = false
	session ["paid_total"] = 0.0
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session

	if gs != null and gs.shared_public_space_engine != null:
		gs.shared_public_space_engine.enter_space(actor, "movie_theater", theater_id, _shared_space_context(theater_id, context))

	var target_section: String = "movies"
	var text: String = "I entered %s." % str(theater.get("name", theater_id))
	if not runtime_contract.is_empty():
		target_section = "lobby"
		text = "I entered %s and stepped into an already-running showing of %s." % [
			str(theater.get("name", theater_id)),
			str(runtime_movie.get("title", "a movie"))
		]

	return _make_action_report(actor, true, target_section, text, {
		"mode": "movie_theater_select_runtime_contract",
		"theater_id": theater_id,
		"theater_name": str(theater.get("name", theater_id)),
		"runtime_contract_id": str(runtime_contract.get("contract_id", ""))
	})
func select_movie(actor: Person, movie_id: String, _context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	var theater_id: String = str(session.get("theater_id", "")).strip_edges()
	if theater_id == "":
		return { "success": false, "reason": "Choose a theater first."}
	var movie: Dictionary = _movie_by_id(theater_id, movie_id)
	if movie.is_empty():
		return { "success": false, "reason": "Movie not found."}
	session ["movie_id"] = movie_id
	session ["movie_title"] = str(movie.get("title", movie_id))
	session ["genre"] = str(movie.get("genre", "Drama"))
	session ["line_position"] = -1
	session ["line_ready"] = false
	session ["ticket_bought"] = false
	session ["active_friction_event"] = {}
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	return _make_action_report(actor, true, "lobby", "I decided to watch %s." % str(movie.get("title", movie_id)), { "mode": "movie_select", "movie_id": movie_id, "genre": str(movie.get("genre", "Drama"))})

func stand_in_ticket_line(actor: Person, context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	if str(session.get("movie_id", "")).strip_edges() == "":
		return { "success": false, "reason": "Choose a movie first."}
	var rng:= _rng_for_actor(actor, "ticket_line")
	var position: int = int(rng.randi_range(1, 5))
	session ["line_position"] = position
	session ["line_ready"] = position <= 0
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	if gs != null and gs.shared_public_space_engine != null:
		gs.shared_public_space_engine.move_actor_to_zone(actor, "movie_theater", str(session.get("theater_id", "")), "line", _shared_space_context(str(session.get("theater_id", "")), context))
	return _make_action_report(actor, true, "lobby", "I stood in the movie theater ticket line. %d people were ahead of me." % position, { "mode": "movie_stand_line", "line_position": position})

func advance_ticket_line(actor: Person, _context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	var position: int = max(0, int(session.get("line_position", 0)) - 1)
	session ["line_position"] = position
	session ["line_ready"] = position <= 0
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	var text: String = "The ticket line moved."
	if position > 0:
		text = "The ticket line moved. %d people are still ahead of me." % position
	else:
		text = "I reached the movie theater cashier."
	return _make_action_report(actor, true, "lobby", text, { "mode": "movie_advance_line", "line_position": position, "line_ready": position <= 0})

func buy_ticket(actor: Person, context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	if str(session.get("movie_id", "")).strip_edges() == "":
		return { "success": false, "reason": "Choose a movie first."}
	var theater: Dictionary = get_theater(str(session.get("theater_id", "")))
	var ticket_price: float = float(theater.get("ticket_price", 12.0))
	var pay_report: Dictionary = _pay(actor, ticket_price, { "source": "movie_theater_ticket", "context": context.duplicate(true)})
	if not bool(pay_report.get("success", false)):
		return _make_action_report(actor, false, "lobby", str(pay_report.get("reason", "I could not afford the movie ticket.")), { "mode": "movie_buy_ticket", "payment_report": pay_report.duplicate(true)})
	session ["ticket_bought"] = true
	session ["line_ready"] = false
	session ["paid_total"] = float(session.get("paid_total", 0.0)) + ticket_price
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	return _make_action_report(actor, true, "concessions", "I bought a ticket to see %s." % str(session.get("movie_title", "a movie")), { "mode": "movie_buy_ticket", "ticket_price": ticket_price, "payment_report": pay_report.duplicate(true)})

func buy_concession(actor: Person, concession_id: String, context: Dictionary = {}) -> Dictionary:
	var item: Dictionary = _concession_by_id(concession_id)
	if item.is_empty():
		return { "success": false, "reason": "Concession item not found."}
	var price: float = float(item.get("price", 0.0))
	var pay_report: Dictionary = _pay(actor, price, { "source": "movie_theater_concession", "context": context.duplicate(true)})
	if not bool(pay_report.get("success", false)):
		return _make_action_report(actor, false, "concessions", str(pay_report.get("reason", "I could not afford that concession.")), { "mode": "movie_buy_concession", "payment_report": pay_report.duplicate(true)})
	var session: Dictionary = _session_for_actor(actor)
	var concessions: Array = _safe_array(session.get("concessions", []))
	concessions.append(item.duplicate(true))
	session ["concessions"] = concessions
	session ["paid_total"] = float(session.get("paid_total", 0.0)) + price
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	return _make_action_report(actor, true, "concessions", "I bought %s at the movie theater." % str(item.get("name", "a snack")), { "mode": "movie_buy_concession", "concession_id": concession_id, "payment_report": pay_report.duplicate(true)})

func enter_auditorium(actor: Person, context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	if not bool(session.get("ticket_bought", false)):
		return { "success": false, "reason": "Buy a ticket first."}
	if gs != null and gs.shared_public_space_engine != null:
		gs.shared_public_space_engine.move_actor_to_zone(actor, "movie_theater", str(session.get("theater_id", "")), "auditorium", _shared_space_context(str(session.get("theater_id", "")), context))
	session ["entered_auditorium"] = true
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	return generate_friction_event(actor, { "source": "enter_auditorium"})

func generate_friction_event(actor: Person, context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	if not bool(session.get("ticket_bought", false)):
		return { "success": false, "reason": "Buy a ticket first."}
	var movie: Dictionary = _movie_by_id(str(session.get("theater_id", "")), str(session.get("movie_id", "")))
	var event: Dictionary = _build_friction_event(actor, movie, context)
	session ["active_friction_event"] = event.duplicate(true)
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	return _make_action_report(actor, true, "friction", str(event.get("setup_text", event.get("description", "A movie theater friction moment started."))), { "mode": "movie_generate_friction", "active_friction_event": event.duplicate(true)})

func resolve_friction_response(actor: Person, event_id: String, choice_id: String, context: Dictionary = {}) -> Dictionary:
	var session: Dictionary = _session_for_actor(actor)
	var event: Dictionary = _safe_dictionary(session.get("active_friction_event", {}))
	if event.is_empty():
		return { "success": false, "reason": "No active movie theater friction event."}
	if event_id != "" and str(event.get("event_id", "")) != event_id:
		return { "success": false, "reason": "That movie theater friction event is no longer active."}
	var result: Dictionary = _resolve_event_choice(actor, event, choice_id, context)
	var resolved: Array = _safe_array(session.get("resolved_friction_events", []))
	resolved.append({
		"event": event.duplicate(true),
		"choice_id": choice_id,
		"result": result.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	})
	session ["resolved_friction_events"] = resolved
	session ["active_friction_event"] = {}
	if bool(result.get("kicked_out", false)):
		session ["kicked_out"] = true
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	movie_theater_sessions_by_actor_id [str(int(actor.id))] = session
	_record_movie_diary(actor, str(result.get("diary_text", result.get("text", "I dealt with a movie theater moment."))))
	var target_section: String = "auditorium"
	if bool(result.get("kicked_out", false)):
		target_section = "theaters"
		leave_theater(actor, { "skip_diary": true})
	return _make_action_report(actor, bool(result.get("success", true)), target_section, str(result.get("text", "Movie theater friction resolved.")), { "mode": "movie_friction_response", "choice_id": choice_id, "friction_result": result.duplicate(true), "show_popup": true, "popup_title": str(result.get("popup_title", "Movie Theater")), "popup_text": str(result.get("text", "Movie theater friction resolved.")), "popup_footer": "Tap anywhere to continue."})

func leave_theater(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var session: Dictionary = _session_for_actor(actor)
	var theater_id: String = str(session.get("theater_id", "")).strip_edges()
	if gs != null and gs.shared_public_space_engine != null:
		gs.shared_public_space_engine.exit_space(actor, "movie_theater", theater_id, context)
	movie_theater_sessions_by_actor_id.erase(str(int(actor.id)))
	if not bool(context.get("skip_diary", false)):
		_record_movie_diary(actor, "I left the movie theater.")
	return _make_action_report(actor, true, "theaters", "I left the movie theater.", { "mode": "movie_leave", "close_contract_surface": false})

func get_theaters_for_era(era_name: String = "") -> Array:
	var era: String = str(era_name).strip_edges()
	if era == "":
		era = _current_era_name()
	if era not in ["Modern Era", "Future Era"]:
		return []
	var theaters: Array = [
		{
			"id": "crown_8_cinemas",
			"name": "Crown 8 Cinemas",
			"description": "A clean chain theater with family crowds, teens, couples, and a snack counter that smells like butter from orbit.",
			"ticket_price": 13.5,
			"min_population": 18,
			"max_population": 44,
			"baseline_population": 28,
			"sort_priority": 10
		},
		{
			"id": "starlight_grand",
			"name": "Starlight Grand Theater",
			"description": "A nicer theater with reserved seating energy, expensive popcorn, and people who act like whispering is a constitutional crisis.",
			"ticket_price": 18.0,
			"min_population": 12,
			"max_population": 32,
			"baseline_population": 22,
			"sort_priority": 20
		}
	]
	if era == "Future Era":
		theaters.append({
			"id": "holo_max_pavilion",
			"name": "HoloMax Pavilion",
			"description": "A future theater with immersive seats, reactive screens, AI ushers, and crowds that still somehow talk during the movie.",
			"ticket_price": 32.0,
			"min_population": 20,
			"max_population": 58,
			"baseline_population": 38,
			"sort_priority": 5
		})
	return theaters

func get_theater(theater_id: String) -> Dictionary:
	var clean_id: String = str(theater_id).strip_edges()
	for raw_theater in get_theaters_for_era(_current_era_name()):
		if typeof(raw_theater) != TYPE_DICTIONARY:
			continue
		var theater: Dictionary = raw_theater as Dictionary
		if str(theater.get("id", "")) == clean_id:
			return theater.duplicate(true)
	return {}

func _movies_for_theater(_theater_id: String) -> Array:
	return [
		{ "id": "night_house_iii", "title": "Night House III", "genre": "Horror", "description": "A haunted-house sequel with jump scares strong enough to make the whole row levitate."},
		{ "id": "love_after_laundry", "title": "Love After Laundry", "genre": "Romance", "description": "A soft romance movie where every other person in the audience thinks they are also on screen."},
		{ "id": "hyperlane_riot", "title": "Hyperlane Riot", "genre": "Action", "description": "Explosions, chase scenes, and a crowd that keeps audibly powering up."},
		{ "id": "little_planet_big_dream", "title": "Little Planet, Big Dream", "genre": "Family", "description": "A bright animated movie with families, kids, spilled candy, and at least one dramatic whisper argument."}
	]

func _movie_by_id(theater_id: String, movie_id: String) -> Dictionary:
	var clean_id: String = str(movie_id).strip_edges()
	for raw_movie in _movies_for_theater(theater_id):
		if typeof(raw_movie) != TYPE_DICTIONARY:
			continue
		var movie: Dictionary = raw_movie as Dictionary
		if str(movie.get("id", "")) == clean_id:
			return movie.duplicate(true)
	return {}

func _concession_items() -> Array:
	return [
		{ "id": "popcorn", "name": "Popcorn", "price": 8.5, "description": "Movie theater popcorn. It costs too much because civilization chose chaos."},
		{ "id": "soda", "name": "Large Soda", "price": 6.25, "description": "A drink big enough to create third-act bathroom tension."},
		{ "id": "nachos", "name": "Nachos", "price": 9.75, "description": "Warm chips, cheese, and the risky smell of confidence."},
		{ "id": "candy", "name": "Box Candy", "price": 5.5, "description": "Classic boxed candy that sounds like maracas if opened wrong."}
	]

func _concession_by_id(concession_id: String) -> Dictionary:
	var clean_id: String = str(concession_id).strip_edges()
	for raw_item in _concession_items():
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item as Dictionary
		if str(item.get("id", "")) == clean_id:
			return item.duplicate(true)
	return {}

func _build_friction_event(actor: Person, movie: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var genre: String = str(movie.get("genre", "Drama")).strip_edges()
	var rng:= _rng_for_actor(actor, "friction_%s_%s" % [genre, str(_safe_array(_session_for_actor(actor).get("resolved_friction_events", [])).size())])
	var pool: Array = _base_friction_pool()
	match genre.to_lower():
		"horror":
			pool.append(_genre_friction_event("horror_scream_chain", "The row behind you keeps screaming before anything even happens.", "Horror crowds overreact, laugh nervously, and spread jump-scare panic.", 6, "medium"))
		"romance":
			pool.append(_genre_friction_event("romance_couple_kissing", "A couple nearby starts kissing loud enough to become surround sound.", "Romance crowds bring date energy, PDA, awkward whispers, and jealousy spikes.", 5, "medium"))
		"action":
			pool.append(_genre_friction_event("action_hype_crowd", "A hype group starts clapping and yelling after every punch.", "Action crowds get loud, reactive, and contagious.", 6, "high"))
	var picked: Dictionary = pool [int(rng.randi_range(0, pool.size() - 1))]
	picked ["event_id"] = "%s_%d" % [str(picked.get("id", "movie_friction")), int(Time.get_ticks_msec())]
	picked ["genre"] = genre
	picked ["setup_text"] = str(picked.get("description", "A social friction moment starts."))
	return picked

func _base_friction_pool() -> Array:
	return [
		{
			"id": "tall_person_front",
			"title": "Someone Tall Sits In Front Of You",
			"description": "A tall person sits directly in front of you right as the movie starts blocking half the screen.",
			"intensity": 4,
			"escalation_score": 5,
			"personality_influence": "patience lowers irritation; boldness makes confrontation more likely",
			"escalation_risk": "medium",
			"choices": [
				{ "id": "lean", "label": "Lean Left/Right", "style": "secondary"},
				{ "id": "ask_move", "label": "Ask Them To Move", "style": "primary"},
				{ "id": "kick_seat", "label": "Kick Seat", "style": "danger"},
				{ "id": "deal", "label": "Deal With It", "style": "secondary"}
			]
		},
		{
			"id": "couple_arguing",
			"title": "Couple Arguing Next To You",
			"description": "The couple next to you starts whisper-fighting like they bought tickets to their own breakup.",
			"intensity": 5,
			"escalation_score": 4,
			"personality_influence": "empathy may de-escalate; nosiness may pull you into it",
			"escalation_risk": "medium",
			"choices": [
				{ "id": "ignore", "label": "Ignore", "style": "secondary"},
				{ "id": "eavesdrop", "label": "Eavesdrop", "style": "primary"},
				{ "id": "intervene", "label": "Intervene", "style": "danger"},
				{ "id": "laugh_internal", "label": "Laugh Internally", "style": "secondary"}
			]
		},
		{
			"id": "phone_brightness",
			"title": "Phone Brightness 100%",
			"description": "Someone nearby opens their phone at full brightness and turns the row into a tiny lighthouse.",
			"intensity": 6,
			"escalation_score": 6,
			"personality_influence": "boldness increases confrontation; impulse increases popcorn violence",
			"escalation_risk": "high",
			"choices": [
				{ "id": "say_something", "label": "Say Something", "style": "primary"},
				{ "id": "throw_popcorn", "label": "Throw Popcorn 😭", "style": "danger"},
				{ "id": "complain_staff", "label": "Complain To Staff", "style": "secondary"},
				{ "id": "ignore", "label": "Ignore", "style": "secondary"}
			]
		}
	]

func _genre_friction_event(event_id: String, title: String, description: String, intensity: int, escalation_risk: String) -> Dictionary:
	return {
		"id": event_id,
		"title": title,
		"description": description,
		"intensity": intensity,
		"escalation_score": intensity,
		"personality_influence": "genre crowd pressure modifies patience, boldness, and impulse checks",
		"escalation_risk": escalation_risk,
		"choices": [
			{ "id": "ignore", "label": "Ignore", "style": "secondary"},
			{ "id": "say_something", "label": "Say Something", "style": "primary"},
			{ "id": "join_energy", "label": "Join The Energy", "style": "primary"},
			{ "id": "complain_staff", "label": "Complain To Staff", "style": "secondary"}
		]
	}

func _resolve_event_choice(actor: Person, event: Dictionary, choice_id: String, _context: Dictionary = {}) -> Dictionary:
	var clean_choice: String = str(choice_id).strip_edges().to_lower()
	var intensity: int = int(event.get("intensity", 4))
	var escalation: int = int(event.get("escalation_score", intensity))
	var rng:= _rng_for_actor(actor, "resolve_%s_%s" % [str(event.get("event_id", "event")), clean_choice])
	var impulse: float = _actor_impulse(actor)
	var patience: float = _actor_patience(actor)
	var boldness: float = _actor_boldness(actor)
	var risk: float = (float(escalation) / 10.0) + (impulse * 0.18) + (boldness * 0.12) - (patience * 0.16)
	var outcome: String = "ignored"
	var kicked_out: bool = false
	var fight: bool = false
	match clean_choice:
		"deal", "ignore", "lean", "laugh_internal":
			outcome = "contained"
			if rng.randf() < 0.16 + (float(intensity) / 80.0):
				outcome = "annoyed_but_safe"
		"ask_move", "say_something":
			outcome = "deescalated"
			if rng.randf() < risk:
				outcome = "argument"
		"eavesdrop", "join_energy":
			outcome = "awkward_memory"
			if rng.randf() < risk * 0.55:
				outcome = "called_out"
		"intervene", "kick_seat", "throw_popcorn":
			outcome = "argument"
			if rng.randf() < risk + 0.2:
				fight = true
				outcome = "fight"
			if rng.randf() < risk + 0.12:
				kicked_out = true
				outcome = "kicked_out"
		"complain_staff":
			outcome = "staff_warning"
			if rng.randf() < risk * 0.22:
				outcome = "awkward_staff_scene"
		_:
			outcome = "uncertain"
	var text: String = _outcome_text(event, clean_choice, outcome)
	var diary: String = "At the movie theater, %s" % text.to_lower()
	if fight or kicked_out:
		_propagate_movie_friction(actor, event, outcome, text)
	return {
		"success": true,
		"choice_id": clean_choice,
		"outcome": outcome,
		"fight": fight,
		"kicked_out": kicked_out,
		"text": text,
		"diary_text": diary,
		"popup_title": "Movie Theater Friction"
	}

func _outcome_text(event: Dictionary, choice_id: String, outcome: String) -> String:
	var title: String = str(event.get("title", "the situation"))
	match outcome:
		"contained":
			return "You handled %s without making the theater worse." % title
		"annoyed_but_safe":
			return "You stayed quiet, but %s kept irritating you through the scene." % title
		"deescalated":
			return "You spoke up and %s calmed down without a scene." % title
		"argument":
			return "Your choice started an argument during %s." % title
		"fight":
			return "Your choice escalated %s into a fight in the theater." % title
		"kicked_out":
			return "Your choice escalated %s so badly that staff kicked you out." % title
		"staff_warning":
			return "Staff stepped in and warned the person causing %s." % title
		"awkward_staff_scene":
			return "Staff got involved, but %s became awkward and everybody stared." % title
		"awkward_memory":
			return "You leaned into %s and walked away with a ridiculous memory." % title
		"called_out":
			return "You got called out for involving yourself in %s." % title
		_:
			return "You chose %s during %s." % [choice_id.replace("_", " "), title]

func _propagate_movie_friction(actor: Person, event: Dictionary, outcome: String, text: String) -> void:
	if gs == null or actor == null:
		return
	if gs.upce_engine != null and gs.upce_engine.has_method("process_public_event"):
		gs.upce_engine.process_public_event({
			"actor_id": int(actor.id),
			"event_type": "movie_theater_social_friction",
			"classification": {
				"public": true,
				"violent": outcome == "fight",
				"lethality": 0,
				"intent": "social_friction_response"
			},
			"event_facts": {
				"title": str(event.get("title", "Movie theater friction")),
				"outcome": outcome,
				"text": text
			},
			"perception_channels": ["witness", "staff", "rumor"]
		})
	elif typeof(gs.world_feed) == TYPE_ARRAY and outcome in ["fight", "kicked_out"]:
		gs.world_feed.append("🎬 %s caused a scene at the movie theater." % _person_name(actor))

func _pay(actor: Person, amount: float, context: Dictionary = {}) -> Dictionary:
	if amount <= 0.0:
		return { "success": true, "amount": 0.0}
	if gs != null and gs.food_engine != null and gs.food_engine.has_method("_pay_for_food"):
		return gs.food_engine._pay_for_food(actor, amount, context)
	if actor.bank_balance < amount:
		return { "success": false, "reason": "Not enough money.", "amount": amount}
	actor.bank_balance -= amount
	return { "success": true, "mode": "legacy_bank_balance", "amount": amount}

func _make_action_report(actor: Person, success: bool, target_section: String, text: String, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"success": success,
		"handled": true,
		"surface_id": "movie_theater_contract_hub",
		"next_surface_id": "movie_theater_contract_hub",
		"target_section": target_section,
		"active_section_id": target_section,
		"text": text,
		"show_popup": bool(extra.get("show_popup", false)),
		"popup_title": str(extra.get("popup_title", "Movie Theater")),
		"popup_text": str(extra.get("popup_text", text)),
		"popup_footer": str(extra.get("popup_footer", "Tap anywhere to continue.")),
		"state_patch": _session_for_actor(actor).duplicate(true),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	for key in extra.keys():
		report [key] = extra [key]
	last_report = _make_binary_safe(report)
	return last_report.duplicate(true)

func _section_only_report(actor: Person, target_section: String, text: String) -> Dictionary:
	return _make_action_report(actor, true, target_section, text, { "mode": "movie_back"})

func _session_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	var key: String = str(int(actor.id))
	var session: Dictionary = _safe_dictionary(movie_theater_sessions_by_actor_id.get(key, {}))
	if session.is_empty():
		session = {
			"actor_id": int(actor.id),
			"theater_id": "",
			"theater_name": "",
			"movie_id": "",
			"movie_title": "",
			"genre": "",
			"ticket_bought": false,
			"line_position": -1,
			"line_ready": false,
			"concessions": [],
			"active_friction_event": {},
			"resolved_friction_events": [],
			"paid_total": 0.0,
			"updated_year": _current_year(),
			"updated_at_ms": int(Time.get_ticks_msec())
		}
		movie_theater_sessions_by_actor_id [key] = session
	return session

func _shared_space_context(theater_id: String, context: Dictionary = {}) -> Dictionary:
	var theater: Dictionary = get_theater(theater_id)
	var out: Dictionary = context.duplicate(true)
	out ["actor_id"] = int(out.get("actor_id", gs.player.id if gs != null and gs.player != null else -1))
	out ["zone_ids"] = ["lobby", "line", "concessions", "auditorium", "exit"]
	out ["min_population"] = int(theater.get("min_population", 12))
	out ["max_population"] = int(theater.get("max_population", 30))
	out ["seed_salt"] = "movie_theater"
	return out

func _locked_row(label: String, description: String) -> Dictionary:
	return { "id": "locked", "label": label, "description": description, "kind": "locked"}

func _genre_crowd_description(genre: String) -> String:
	match str(genre).strip_edges().to_lower():
		"horror":
			return "People scream, laugh after jump scares, and accidentally bond through fear."
		"romance":
			return "Couples show up everywhere, whisper, flirt, argue, kiss, and judge each other."
		"action":
			return "The crowd gets hype, reacts loudly, and treats big moments like a live fight."
		"family":
			return "Families, kids, candy noise, and soft chaos fill the room."
		_:
			return "A mixed crowd settles in with normal theater tension."
func _runtime_contract_for_theater(theater_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_theater: String = str(theater_id).strip_edges()
	if clean_theater == "" or gs == null or gs.runtime_contract_engine == null:
		return {}

	if not gs.runtime_contract_engine.has_method("get_contract_for_space"):
		return {}

	return gs.runtime_contract_engine.get_contract_for_space("movie_theater", clean_theater, {
		"source": str(context.get("source", "movie_theater_runtime_lookup")),
		"theater_id": clean_theater
	})


func _runtime_movie_from_contract(contract: Dictionary) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {}
	return _safe_dictionary(contract.get("movie", {}))


func _runtime_active_friction_from_contract(contract: Dictionary) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {}

	var events: Array = _safe_array(contract.get("active_friction_events", []))
	if events.is_empty():
		return {}

	var raw_event: Variant = events [0]
	if typeof(raw_event) != TYPE_DICTIONARY:
		return {}

	var event: Dictionary = raw_event as Dictionary
	return {
		"event_id": str(event.get("event_id", event.get("type", "runtime_friction"))),
		"id": str(event.get("type", "runtime_friction")),
		"title": str(event.get("title", "Live Theater Friction")),
		"description": str(event.get("description", "A social friction moment is already active in the theater.")),
		"intensity": int(round(float(event.get("intensity", 0.5)) * 10.0)),
		"escalation_score": int(round(float(event.get("intensity", 0.5)) * 10.0)),
		"personality_influence": "runtime contract pressure combines with patience, boldness, impulse, and relationship context",
		"escalation_risk": "runtime",
		"choices": _choices_for_runtime_friction(str(event.get("type", "")))
	}


func _choices_for_runtime_friction(event_type: String) -> Array:
	match str(event_type).strip_edges().to_lower():
		"phone_brightness":
			return [
				{ "id": "say_something", "label": "Say Something", "style": "primary"},
				{ "id": "throw_popcorn", "label": "Throw Popcorn 😭", "style": "danger"},
				{ "id": "complain_staff", "label": "Complain To Staff", "style": "secondary"},
				{ "id": "ignore", "label": "Ignore", "style": "secondary"}
			]
		"couple_arguing":
			return [
				{ "id": "ignore", "label": "Ignore", "style": "secondary"},
				{ "id": "eavesdrop", "label": "Eavesdrop", "style": "primary"},
				{ "id": "intervene", "label": "Intervene", "style": "danger"},
				{ "id": "laugh_internal", "label": "Laugh Internally", "style": "secondary"}
			]
		"tall_person_front":
			return [
				{ "id": "lean", "label": "Lean Left/Right", "style": "secondary"},
				{ "id": "ask_move", "label": "Ask Them To Move", "style": "primary"},
				{ "id": "kick_seat", "label": "Kick Seat", "style": "danger"},
				{ "id": "deal", "label": "Deal With It", "style": "secondary"}
			]
		_:
			return [
				{ "id": "ignore", "label": "Ignore", "style": "secondary"},
				{ "id": "say_something", "label": "Say Something", "style": "primary"},
				{ "id": "join_energy", "label": "Join The Energy", "style": "primary"},
				{ "id": "complain_staff", "label": "Complain To Staff", "style": "secondary"}
			]


func _presence_summary_from_runtime_contract(contract: Dictionary) -> Dictionary:
	var zones: Dictionary = _safe_dictionary(contract.get("zones", {}))
	var zone_counts: Dictionary = {}
	var people_in_building: int = 0

	for raw_zone in zones.keys():
		var zone_id: String = str(raw_zone)
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		var count: int = _safe_array(zone.get("actor_ids", [])).size() + _safe_array(zone.get("ambient_people", [])).size()
		zone_counts [zone_id] = count
		people_in_building += count

	return {
		"success": true,
		"mode": "runtime_contract_presence_summary",
		"people_in_building": people_in_building,
		"zone_counts": zone_counts,
		"contract_id": str(contract.get("contract_id", ""))
	}
func _record_movie_diary(actor: Person, text: String) -> void:
	if actor == null:
		return
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return
	if typeof(actor.memories) == TYPE_ARRAY:
		actor.memories.append(clean_text)
	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "movie_theater_lifestyle",
			"text": clean_text,
			"life_diary_text": clean_text
		})

func _actor_from_context(context: Dictionary = {}) -> Person:
	if gs == null:
		return null
	var actor_id: int = int(context.get("actor_id", context.get("player_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor
	return gs.player

func _actor_impulse(actor: Person) -> float:
	if actor == null:
		return 0.5
	return clamp((100.0 - float(actor.smarts)) / 100.0, 0.05, 0.95)

func _actor_patience(actor: Person) -> float:
	if actor == null:
		return 0.5
	return clamp((float(actor.mental_health) + float(actor.smarts)) / 200.0, 0.05, 0.95)

func _actor_boldness(actor: Person) -> float:
	if actor == null:
		return 0.5
	return clamp((float(actor.looks) + float(actor.health)) / 200.0, 0.05, 0.95)

func _rng_for_actor(actor: Person, salt: String) -> RandomNumberGenerator:
	var rng:= RandomNumberGenerator.new()
	var actor_id: int = int(actor.id) if actor != null else 0
	var live_seed_bucket: int = _movie_live_seed_bucket(250.0)
	rng.seed = _stable_seed("movie|%s|%s|%s|%s" % [str(_current_year()), str(actor_id), str(salt), str(live_seed_bucket)])
	return rng
func _movie_live_seed_bucket(bucket_ms: float = 250.0) -> int:
	var clean_bucket: float = max(1.0, float(bucket_ms))
	return int(floor(float(Time.get_ticks_msec()) / clean_bucket))

func _person_name(person: Person) -> String:
	if person == null:
		return "Someone"
	var full_name: String = "%s %s" % [str(person.first_name), str(person.last_name)]
	full_name = full_name.strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Someone"
	return full_name

func _era_name_from_context(context: Dictionary = {}) -> String:
	var era_name: String = str(context.get("era_name", "")).strip_edges()
	if era_name != "":
		return era_name
	return _current_era_name()

func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "Modern Era"

func _current_year() -> int:
	if gs != null:
		return int(gs.year)
	return 0

func _stable_seed(material: String) -> int:
	var value: int = int(hash(str(material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)