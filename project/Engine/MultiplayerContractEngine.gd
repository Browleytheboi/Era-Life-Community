extends Resource
class_name MultiplayerContractEngine

const ENGINE_SCHEMA:= "eralife.multiplayer_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_multiplayer_state"
const MAX_INVITATIONS:= 160
const MAX_TOURNAMENTS:= 48

var gs: GameState = null
var state: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func resolve_intent(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var action_id: String = _id(str(payload.get("action_id", payload.get("intent", ""))))

	match action_id:
		"invite_relationship":
			return create_relationship_invitation(
				actor,
				_person_by_id(int(payload.get("target_actor_id", -1))),
				str(payload.get("provider_id", "")),
				_dict(payload.get("host_contract", {})),
				payload
			)
		"invite_eraccount":
			return create_eraccount_invitation(
				actor,
				str(payload.get("recipient_username", "")),
				str(payload.get("provider_id", "")),
				_dict(payload.get("host_contract", {})),
				payload
			)
		"accept_invitation":
			return accept_invitation(actor, str(payload.get("invitation_id", "")), payload)
		"decline_invitation":
			return decline_invitation(actor, str(payload.get("invitation_id", "")), payload)
		"create_tournament":
			return create_tournament(actor, payload)
		"join_tournament":
			return join_tournament(actor, str(payload.get("tournament_id", "")), payload)
		_:
			return _failure(
				"unknown_multiplayer_intent",
				"The MultiplayerContractEngine did not recognize that intent."
			)


func participant_for_actor(
	actor: Person, controller: String = "local_player", local_slot: int = 0
) -> Dictionary:
	if actor == null:
		return {}

	var identity: Dictionary = _identity_context_for_actor(actor)
	var identity_key: String = str(identity.get("identity_key", "")).strip_edges()

	if identity_key == "":
		identity_key = "person:%d" % int(actor.id)

	return {
		"identity_key": identity_key,
		"identity_kind": str(identity.get("identity_kind", "person")),
		"eraccount_identity_id": str(identity.get("eraccount_identity_id", "")),
		"username": str(identity.get("username", "")),
		"actor_id": int(actor.id),
		"display_name": _person_name(actor),
		"controller": controller,
		"local_slot": local_slot,
		"is_ai": controller == "npc_ai",
		"is_local": controller in ["local_player", "local_split_screen", "npc_ai"],
		"is_online": controller == "online_eraccount",
	}


func participant_for_eraccount(username: String, identity_id: String = "") -> Dictionary:
	var clean_username: String = str(username).strip_edges()
	var clean_identity_id: String = str(identity_id).strip_edges()
	var identity_key: String = (
		"eraccount:%s" % clean_identity_id
		if clean_identity_id != ""
		else "eraccount_username:%s" % clean_username.to_lower()
	)
	return {
		"identity_key": identity_key,
		"identity_kind": "eraccount",
		"eraccount_identity_id": clean_identity_id,
		"username": clean_username,
		"actor_id": -1,
		"display_name": clean_username,
		"controller": "online_eraccount",
		"local_slot": -1,
		"is_ai": false,
		"is_local": false,
		"is_online": true,
	}


func create_relationship_invitation(
	actor: Person,
	target: Person,
	provider_id: String,
	host_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	if actor == null or target == null:
		return _failure(
			"relationship_target_missing", "Choose an observable relationship to invite."
		)

	var invitation: Dictionary = _new_invitation(
		{
			"invitation_kind": "relationship",
			"provider_id": _id(provider_id),
			"host_contract": host_contract.duplicate(true),
			"sender": participant_for_actor(actor),
			"recipient": participant_for_actor(target, "npc_ai", 1),
			"status": "pending",
			"context": _serializable_dictionary(context)
		}
	)
	_store_invitation(invitation)

	var auto_accept: bool = bool(context.get("npc_auto_accept", true))
	var acceptance: Dictionary = {}
	if auto_accept:
		acceptance = accept_invitation(
			target,
			str(invitation.get("invitation_id", "")),
			{ "accepted_by_ai": true, "source": "relationship_minigame_invitation"}
		)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode":
		(
			"relationship_invitation_accepted"
			if bool(acceptance.get("accepted", false))
			else "relationship_invitation_created"
		),
		"invitation": _dict(acceptance.get("invitation", invitation)).duplicate(true),
		"accepted": bool(acceptance.get("accepted", false)),
		"participants": _array(acceptance.get("participants", [])),
		"ui_is_renderer_only": true
	}


func create_eraccount_invitation(
	actor: Person,
	recipient_username: String,
	provider_id: String,
	host_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	if actor == null:
		return _failure(
			"actor_missing", "A real player identity is required to send a minigame invitation."
		)

	var sender_identity: Dictionary = _identity_context_for_actor(actor)
	if bool(sender_identity.get("is_guest", true)):
		return _failure(
			"eraccount_required", "Sign into an ErAccount before inviting a real friend."
		)

	var clean_username: String = str(recipient_username).strip_edges()
	if clean_username == "":
		return _failure("recipient_username_missing", "Choose an ErAccount username to invite.")

	var invitation: Dictionary = _new_invitation(
		{
			"invitation_kind": "eraccount_online",
			"provider_id": _id(provider_id),
			"host_contract": host_contract.duplicate(true),
			"sender": participant_for_actor(actor),
			"recipient": participant_for_eraccount(clean_username),
			"status": "pending",
			"context": _serializable_dictionary(context)
		}
	)
	_store_invitation(invitation)

	var delivery_report: Dictionary = {}
	var live_presence_report: Dictionary = {}
	var invitation_message: String = str(
		context.get("message", "Accept to join this persistent EraLife minigame session.")
	)

	if (
		gs != null
		and gs.self_host_network_contract_engine != null
		and gs.self_host_network_contract_engine.has_method("invite_username_to_live_reality")
	):
		live_presence_report = (
			gs
			.self_host_network_contract_engine
			.invite_username_to_live_reality(
				clean_username,
				invitation_message,
				{
					"source": "minigame_eraccount_invitation",
					"invitation": invitation.duplicate(true),
					"provider_id": _id(provider_id),
					"host_contract": host_contract.duplicate(true),
				}
			)
		)

	if (
		live_presence_report.is_empty()
		and gs != null
		and gs.mailbox_contract_engine != null
		and gs.mailbox_contract_engine.has_method("deliver_network_notification")
	):
		delivery_report = (gs.mailbox_contract_engine.deliver_network_notification(
			clean_username,
			"minigame_invitation",
			(
				"%s invited you to play %s"
				% [_person_name(actor), str(context.get("game_title", provider_id.capitalize()))]
			),
			invitation_message,
			{
				"invitation": invitation.duplicate(true),
				"accept_action":
				{
					"action_id": "accept_minigame_invitation",
					"invitation_id": str(invitation.get("invitation_id", ""))
				},
				"decline_action":
				{
					"action_id": "decline_minigame_invitation",
					"invitation_id": str(invitation.get("invitation_id", ""))
				},
			}
		))

	return {
		"success":
		bool(
			(live_presence_report if not live_presence_report.is_empty() else delivery_report).get(
				"success", true
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "eraccount_minigame_invitation_created",
		"invitation": invitation.duplicate(true),
		"delivery_report": delivery_report.duplicate(true),
		"live_presence_report": live_presence_report.duplicate(true),
		"accepted": false,
		"ui_is_renderer_only": true
	}


func accept_invitation(
	actor: Person, invitation_id: String, context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	var invitations: Dictionary = _dict(state.get("invitations", {}))
	var clean_id: String = str(invitation_id).strip_edges()
	var invitation: Dictionary = _dict(invitations.get(clean_id, {}))
	if invitation.is_empty():
		return _failure("invitation_missing", "That minigame invitation is no longer observable.")

	invitation ["status"] = "accepted"
	invitation ["accepted_at_ms"] = int(Time.get_ticks_msec())
	invitation ["acceptance_context"] = _serializable_dictionary(context)
	if actor != null:
		invitation ["accepted_by_actor_id"] = int(actor.id)
	invitations [clean_id] = invitation.duplicate(true)
	state ["invitations"] = invitations
	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "minigame_invitation_accepted",
		"accepted": true,
		"invitation": invitation.duplicate(true),
		"participants":
		[
			_dict(invitation.get("sender", {})).duplicate(true),
			_dict(invitation.get("recipient", {})).duplicate(true)
		],
		"ui_is_renderer_only": true
	}


func decline_invitation(
	actor: Person, invitation_id: String, context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	var invitations: Dictionary = _dict(state.get("invitations", {}))
	var invitation: Dictionary = _dict(invitations.get(invitation_id, {}))
	if invitation.is_empty():
		return _failure("invitation_missing", "That invitation is unavailable.")
	invitation ["status"] = "declined"
	invitation ["declined_at_ms"] = int(Time.get_ticks_msec())
	invitation ["declined_by_actor_id"] = int(actor.id) if actor != null else -1
	invitation ["decline_context"] = _serializable_dictionary(context)
	invitations [invitation_id] = invitation.duplicate(true)
	state ["invitations"] = invitations
	_publish_state()
	return {
		"success": true,
		"mode": "minigame_invitation_declined",
		"invitation": invitation.duplicate(true),
		"ui_is_renderer_only": true
	}


func add_spectator(session_id: String, actor: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.mini_game_runtime_engine == null:
		return _failure("runtime_unavailable", "The minigame runtime is unavailable.")
	var spectator: Dictionary = participant_for_actor(actor, "spectator", -1)
	spectator ["spectator"] = true
	spectator ["context"] = _serializable_dictionary(context)
	return gs.mini_game_runtime_engine.add_spectator(session_id, spectator)


func create_tournament(actor: Person, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()
	if actor == null:
		return _failure("actor_missing", "A tournament creator is required.")
	var tournament_id: String = (
		"tournament:%d:%d"
		% [int(Time.get_unix_time_from_system()), int(state.get("tournament_sequence", 0)) + 1]
	)
	state ["tournament_sequence"] = int(state.get("tournament_sequence", 0)) + 1
	var tournament: Dictionary = {
		"schema": "eralife.minigame_tournament_contract",
		"version": ENGINE_VERSION,
		"tournament_id": tournament_id,
		"title": str(payload.get("title", "Stick Fighter Tournament")),
		"provider_id": _id(str(payload.get("provider_id", "stick_fighter"))),
		"season_id": str(payload.get("season_id", "")),
		"host_contract": _dict(payload.get("host_contract", {})).duplicate(true),
		"participants": [participant_for_actor(actor)],
		"spectators": [],
		"rounds": [],
		"status": "registration",
		"maximum_participants": clampi(int(payload.get("maximum_participants", 16)), 2, 64),
		"created_at_ms": int(Time.get_ticks_msec()),
		"ui_is_renderer_only": true
	}
	var tournaments: Dictionary = _dict(state.get("tournaments", {}))
	tournaments [tournament_id] = tournament.duplicate(true)
	state ["tournaments"] = tournaments
	_prune_tournaments()
	_publish_state()
	return { "success": true, "mode": "tournament_created", "tournament": tournament}


func join_tournament(actor: Person, tournament_id: String, _context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var tournaments: Dictionary = _dict(state.get("tournaments", {}))
	var tournament: Dictionary = _dict(tournaments.get(tournament_id, {}))
	if tournament.is_empty():
		return _failure("tournament_missing", "That tournament is unavailable.")
	var participants: Array = _array(tournament.get("participants", []))
	if participants.size() >= int(tournament.get("maximum_participants", 16)):
		return _failure("tournament_full", "That tournament is full.")
	var participant: Dictionary = participant_for_actor(actor)
	var identity_key: String = str(participant.get("identity_key", ""))
	for raw_row in participants:
		if str(_dict(raw_row).get("identity_key", "")) == identity_key:
			return { "success": true, "mode": "already_registered", "tournament": tournament}
	participants.append(participant)
	tournament ["participants"] = participants
	tournament ["updated_at_ms"] = int(Time.get_ticks_msec())
	tournaments [tournament_id] = tournament.duplicate(true)
	state ["tournaments"] = tournaments
	_publish_state()
	return { "success": true, "mode": "tournament_joined", "tournament": tournament}


func emit_multiplayer_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var identity: Dictionary = _identity_context_for_actor(actor)
	var invitations: Array = []
	for raw_invitation in _dict(state.get("invitations", {})).values():
		var invitation: Dictionary = _dict(raw_invitation)
		var sender_key: String = str(_dict(invitation.get("sender", {})).get("identity_key", ""))
		var recipient_key: String = str(
			_dict(invitation.get("recipient", {})).get("identity_key", "")
		)
		var identity_key: String = str(identity.get("identity_key", ""))
		if identity_key == "" or identity_key in [sender_key, recipient_key]:
			invitations.append(invitation.duplicate(true))

	var tournaments: Array = []
	for raw_tournament in _dict(state.get("tournaments", {})).values():
		tournaments.append(_dict(raw_tournament).duplicate(true))

	return {
		"success": true,
		"schema": "eralife.minigame_multiplayer_projection",
		"version": ENGINE_VERSION,
		"identity": identity,
		"invitations": invitations,
		"tournaments": tournaments,
		"supported_modes":
		[
			"single_player",
			"npc_ai",
			"local_multiplayer",
			"split_screen",
			"online_eraccount",
			"spectator",
			"tournament"
		],
		"context": context.duplicate(true),
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


func _identity_context_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return { "is_guest": true, "identity_key": ""}
	if (
		gs != null
		and actor == gs.player
		and gs.identity_contract_engine != null
		and gs.identity_contract_engine.has_method("emit_identity_context")
	):
		var context: Dictionary = gs.identity_contract_engine.emit_identity_context(
			{ "source": "minigame_multiplayer_identity", "actor_id": int(actor.id)}
		)
		var username: String = (
			str(context.get("account_username", context.get("username", ""))).strip_edges()
		)
		var identity_id: String = (
			str(context.get("identity_id", context.get("account_identity_id", ""))).strip_edges()
		)
		context ["username"] = username
		context ["eraccount_identity_id"] = identity_id
		context ["identity_kind"] = (
			"eraccount" if not bool(context.get("is_guest", true)) else "guest_person"
		)
		context ["identity_key"] = (
			"eraccount:%s" % identity_id
			if identity_id != ""
			else (
				"eraccount_username:%s" % username.to_lower()
				if username != ""
				else "person:%d" % int(actor.id)
			)
		)
		return context
	return {
		"is_guest": true,
		"identity_kind": "person",
		"identity_key": "person:%d" % int(actor.id),
		"actor_id": int(actor.id),
		"username": "",
		"eraccount_identity_id": ""
	}


func _new_invitation(data: Dictionary) -> Dictionary:
	var sequence: int = int(state.get("invitation_sequence", 0)) + 1
	state ["invitation_sequence"] = sequence
	var out: Dictionary = data.duplicate(true)
	out ["schema"] = "eralife.minigame_invitation_contract"
	out ["version"] = ENGINE_VERSION
	out ["invitation_id"] = (
		"minigame_invite:%d:%d" % [int(Time.get_unix_time_from_system()), sequence]
	)
	out ["created_at_ms"] = int(Time.get_ticks_msec())
	out ["expires_at_ms"] = int(Time.get_ticks_msec()) + 7 * 24 * 60 * 60 * 1000
	out ["persistent_identity_required"] = str(out.get("invitation_kind", "")) == "eraccount_online"
	out ["ui_is_renderer_only"] = true
	return out


func _store_invitation(invitation: Dictionary) -> void:
	var invitations: Dictionary = _dict(state.get("invitations", {}))
	invitations [str(invitation.get("invitation_id", ""))] = invitation.duplicate(true)
	state ["invitations"] = invitations
	_prune_invitations()
	_publish_state()


func _prune_invitations() -> void:
	var invitations: Dictionary = _dict(state.get("invitations", {}))
	if invitations.size() <= MAX_INVITATIONS:
		return
	var rows: Array = invitations.values()
	rows.sort_custom(Callable(self, "_created_oldest_first"))
	while rows.size() > MAX_INVITATIONS:
		var row: Dictionary = _dict(rows.pop_front())
		invitations.erase(str(row.get("invitation_id", "")))
	state ["invitations"] = invitations


func _prune_tournaments() -> void:
	var tournaments: Dictionary = _dict(state.get("tournaments", {}))
	if tournaments.size() <= MAX_TOURNAMENTS:
		return
	var rows: Array = tournaments.values()
	rows.sort_custom(Callable(self, "_created_oldest_first"))
	while rows.size() > MAX_TOURNAMENTS:
		var row: Dictionary = _dict(rows.pop_front())
		tournaments.erase(str(row.get("tournament_id", "")))
	state ["tournaments"] = tournaments


func _created_oldest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) < int(b.get("created_at_ms", 0))


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	return gs.get_or_reactivate_npc_by_id(person_id)


func _person_name(person: Person) -> String:
	if person == null:
		return "Unknown Player"
	return "%s %s" % [str(person.first_name), str(person.last_name)]


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"invitation_sequence": 0,
			"tournament_sequence": 0,
			"invitations": {},
			"tournaments": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("invitations", {})) != TYPE_DICTIONARY:
		state ["invitations"] = {}
	if typeof(state.get("tournaments", {})) != TYPE_DICTIONARY:
		state ["tournaments"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _serializable_dictionary(value: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in value.keys():
		var raw_value: Variant = value.get(raw_key)
		if raw_value is Object or typeof(raw_value) == TYPE_CALLABLE:
			continue
		out [str(raw_key)] = raw_value
	return out


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


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []