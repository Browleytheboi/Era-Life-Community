extends Resource
class_name MiniGameContractEngine

const ENGINE_SCHEMA:= "eralife.minigame_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_contract_state"
const MAX_PROVIDER_ROWS:= 512

signal session_observation_ready(
	session_id: String,
	packet: Dictionary
)

var gs: GameState = null
var state: Dictionary = {}
var provider_objects: Dictionary = {}
var provider_contracts: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func bootstrap_default_contracts() -> Dictionary:
	var provider:= StickFighterMiniGameProvider.new()
	var registration: Dictionary = register_provider(
		provider,
		provider.provider_contract(),
		{ "source": "builtin_stick_fighter", "first_party": true}
	)
	if gs != null and gs.adobe_flash_contract_engine != null:
		gs.adobe_flash_contract_engine.register_flash_reality_provider(
			provider.flash_reality_provider_contract(),
			{ "source": "mini_game_contract_engine.bootstrap_default_contracts"}
		)
	if gs != null and gs.achievement_contract_engine != null:
		gs.achievement_contract_engine.register_achievement_definitions(
			StickFighterMiniGameProvider.PROVIDER_ID, provider.achievement_definitions()
		)
	return {
		"success": bool(registration.get("success", false)),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_count": provider_contracts.size(),
		"registration": registration.duplicate(true)
	}


func register_provider(
	provider_object: Object, provider_contract: Dictionary, context: Dictionary = {}
) -> Dictionary:
	var provider_id: String = _id(str(provider_contract.get("provider_id", "")))
	if provider_id == "":
		return _failure("missing_provider_id", "MiniGame providers require a stable provider_id.")
	if provider_object == null:
		return _failure(
			"provider_object_missing",
			"A first-party MiniGame provider requires a runtime provider object."
		)
	for required_method in [
		"initial_session_state",
		"available_actions",
		"resolve_action",
		"result_contract",
		"ui_projection"
	]:
		if not provider_object.has_method(required_method):
			return _failure(
				"provider_method_missing",
				"Provider '%s' does not expose %s()." % [provider_id, required_method]
			)

	var normalized: Dictionary = provider_contract.duplicate(true)
	normalized ["schema"] = "eralife.minigame_provider_contract"
	normalized ["version"] = int(normalized.get("version", 1))
	normalized ["provider_id"] = provider_id
	normalized ["registered_at_ms"] = int(Time.get_ticks_msec())
	normalized ["registration_context"] = _serializable_dictionary(context)
	normalized ["ui_is_renderer_only"] = true
	provider_objects [provider_id] = provider_object
	provider_contracts [provider_id] = normalized
	var registered: Dictionary = _dict(state.get("registered_providers", {}))
	registered [provider_id] = {
		"provider_id": provider_id,
		"title": str(normalized.get("title", provider_id.capitalize())),
		"provider_revision": str(normalized.get("provider_revision", "1")),
		"provider_kind": str(normalized.get("provider_kind", "first_party")),
		"registered_at_ms": int(Time.get_ticks_msec())
	}
	state ["registered_providers"] = registered
	_publish_state()
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "minigame_provider_registered",
		"provider_id": provider_id,
		"provider_contract": normalized.duplicate(true),
		"ui_is_renderer_only": true
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_bootstrap()

	var action_id: String = _id(
		str(
			payload.get(
				"action_id",
				payload.get(
					"intent",
					"emit_hub"
				)
			)
		)
	)

	match action_id:
		"emit_hub", "refresh":
			return _open_ecosystem_section_surface(
				actor,
				payload
			)

		"open_host", "open_minigame_host":
			var provider_id: String = _id(
				str(
					payload.get(
						"provider_id",
						""
					)
				)
			)

			var launch_direct: bool = bool(
				payload.get(
					"launch_direct",
					false
				)
			)

			var open_provider_setup: bool = bool(
				payload.get(
					"open_provider_setup",
					false
				)
			)

			if (
				open_provider_setup
				and provider_id != ""
			):
				return _open_provider_setup(
					actor,
					payload
				)

			if (
				launch_direct
				and provider_id != ""
			):
				var launch_payload: Dictionary = (
					payload.duplicate(false)
				)

				launch_payload [
					"action_id"
				] = "launch_provider"

				launch_payload [
					"provider_id"
				] = provider_id

				launch_payload [
					"active_section"
				] = "session"

				launch_payload [
					"multiplayer_mode"
				] = str(
					payload.get(
						"multiplayer_mode",
						"single_vs_ai"
					)
				)

				return _launch_provider(
					actor,
					launch_payload
				)




			return _open_host_surface(
				actor,
				payload
			)

		"open_provider_setup":
			return _open_provider_setup(
				actor,
				payload
			)

		"configure_provider":
			return _configure_provider_setup(
				actor,
				payload
			)

		"launch_provider", "start_game":
			return _launch_provider(
				actor,
				payload
			)


		"continuous_input":
			return _commit_continuous_provider_input(
				actor,
				payload
			)


		"commit_action", "game_action":
			return _commit_provider_action(
				actor,
				payload
			)

		"invite_relationship", "invite_eraccount", "accept_invitation", \
"decline_invitation", "create_tournament", "join_tournament":
			return _resolve_multiplayer_intent(
				actor,
				payload
			)

		"spectate_session":
			return _spectate_session(
				actor,
				payload
			)

		"leave_session":
			return _open_host_surface(
				actor,
				{
					"active_section": "games",
					"host_contract": _dict(
						payload.get(
							"host_contract",
							{}
						)
					),
					"status_text": (
						"The minigame session remains persistent in reality."
					)
				}
			)

		_:
			return _failure(
				"unknown_minigame_intent",
				"MiniGameContractEngine did not recognize that intent."
			)
func _open_ecosystem_section_surface(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	var requested_section: String = _id(
		str(
			payload.get(
				"active_section",
				"games"
			)
		)
	)

	if requested_section not in [
		"games",
		"session",
		"multiplayer",
		"tournaments",
		"leaderboards",
		"achievements",
		"replays",
		"mods"
	]:
		requested_section = "games"

	if requested_section == "games":
		return _open_host_surface(
			actor,
			payload
		)

	var host_contract: Dictionary = _resolve_host(
		actor,
		payload
	)

	var section_context: Dictionary = (
		payload.duplicate(false)
	)

	section_context [
		"observation_scope"
	] = "ecosystem_section"
	section_context [
		"active_section"
	] = requested_section
	section_context [
		"host_contract"
	] = host_contract
	section_context [
		"status_text"
	] = str(
		payload.get(
			"status_text",
			(
				"%s truth is current."
				% requested_section.replace(
					"_",
					" "
				).capitalize()
			)
		)
	)

	return _wrap_hub_result(
		actor,
		section_context,
		{
			"mode": "minigame_section_surface_observed",
			"active_section": requested_section,
		}
	)
func _emit_ecosystem_section_surface_packet(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var active_section: String = _id(
		str(
			context.get(
				"active_section",
				"games"
			)
		)
	)

	if active_section not in [
		"session",
		"multiplayer",
		"tournaments",
		"leaderboards",
		"achievements",
		"replays",
		"mods"
	]:
		active_section = "games"

	var host_contract: Dictionary = _dict(
		context.get(
			"host_contract",
			{}
		)
	)

	if host_contract.is_empty():
		host_contract = _resolve_host(
			actor,
			context
		)

	var identity: Dictionary = _participant_for_actor(
		actor
	)
	var identity_key: String = str(
		identity.get(
			"identity_key",
			""
		)
	)

	var active_session_cursor: Dictionary = {}

	if (
		gs != null
		and gs.mini_game_runtime_engine != null
		and gs.mini_game_runtime_engine.has_method(
			"project_active_session_cursor"
		)
	):
		active_session_cursor = (
			gs.mini_game_runtime_engine
			.project_active_session_cursor(
				identity_key
			)
		)

	var provider_id: String = _id(
		str(
			context.get(
				"provider_id",
				""
			)
		)
	)

	if provider_id == "":
		provider_id = _id(
			str(
				active_session_cursor.get(
					"provider_id",
					""
				)
			)
		)

	var provider_rows: Array = []
	var session_contract: Dictionary = {}
	var scoreboard: Dictionary = {}
	var achievements: Dictionary = {}
	var replays: Dictionary = {}
	var multiplayer: Dictionary = {}
	var relationship_invite_rows: Array = []

	match active_section:
		"session":
			var session_id: String = str(
				context.get(
					"session_id",
					active_session_cursor.get(
						"session_id",
						""
					)
				)
			).strip_edges()

			if session_id != "":
				session_contract = emit_session_contract(
					actor,
					session_id,
					context
				)

		"multiplayer":
			if (
				gs != null
				and gs.multiplayer_contract_engine != null
			):
				multiplayer = (
					gs.multiplayer_contract_engine
					.emit_multiplayer_contract(
						actor,
						context
					)
				)

				var invitation_provider_id: String = provider_id

				if invitation_provider_id == "":
					invitation_provider_id = (
						StickFighterMiniGameProvider.PROVIDER_ID
					)

				relationship_invite_rows = (
					_relationship_invite_rows(
						actor,
						invitation_provider_id,
						host_contract
					)
				)

		"tournaments":
			if (
				gs != null
				and gs.multiplayer_contract_engine != null
			):
				multiplayer = (
					gs.multiplayer_contract_engine
					.emit_multiplayer_contract(
						actor,
						context
					)
				)

		"leaderboards":
			if (
				gs != null
				and gs.scoreboard_contract_engine != null
			):
				scoreboard = (
					gs.scoreboard_contract_engine
					.emit_scoreboard_contract(
						provider_id,
						context
					)
				)

		"achievements":
			if (
				gs != null
				and gs.achievement_contract_engine != null
			):
				achievements = (
					gs.achievement_contract_engine
					.emit_achievement_contract(
						identity_key,
						provider_id
					)
				)

		"replays":
			if (
				gs != null
				and gs.replay_contract_engine != null
			):
				replays = (
					gs.replay_contract_engine
					.emit_replay_contract(
						provider_id,
						context
					)
				)

		"mods":
			provider_rows = _available_provider_rows(
				actor,
				host_contract,
				context
			)

	return {
		"success": true,
		"schema": "eralife.minigame_surface_packet",
		"version": 2,
		"surface_scope": active_section,
		"actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"actor_name": _person_name(
			actor
		),
		"title": str(
			host_contract.get(
				"title",
				"MINIGAME ECOSYSTEM"
			)
		),
		"subtitle": (
			"Each MiniGame section observes only its own "
			+ "authoritative contract lane."
		),
		"active_section": active_section,
		"section_tabs": _mini_game_section_tabs(),
		"host_contract": host_contract,
		"provider_rows": provider_rows,
		"provider_setup_contract": {},
		"session_contract": session_contract,
		"scoreboard_contract": scoreboard,
		"achievement_contract": achievements,
		"replay_contract": replays,
		"multiplayer_contract": multiplayer,
		"relationship_invite_rows": relationship_invite_rows,
		"status_text": str(
			context.get(
				"status_text",
				"Section truth is current."
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"progressive_observability": true,
		"ui_is_renderer_only": true
	}
func _open_host_surface(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	var host_contract: Dictionary = _resolve_host(
		actor,
		payload
	)

	var provider_rows: Array = (
		_available_first_party_provider_rows(
			host_contract
		)
	)

	return _wrap_hub_result(
		actor,
		{
			"observation_scope": "games",
			"active_section": "games",
			"host_contract": host_contract,
			"provider_rows_override": provider_rows,
			"status_text": str(
				payload.get(
					"status_text",
					"Choose a game."
				)
			)
		},
		{
			"mode": "minigame_games_surface_observed",
			"provider_count": provider_rows.size(),
		}
	)


func _available_first_party_provider_rows(
	host_contract: Dictionary
) -> Array:
	var out: Array = []

	var host_identity: Dictionary = (
		_host_intent_identity(
			host_contract
		)
	)

	for raw_contract in provider_contracts.values():
		var provider: Dictionary = _dict(
			raw_contract
		).duplicate(false)

		if not _provider_supported_by_host(
			provider,
			host_contract
		):
			continue

		var provider_id: String = _id(
			str(
				provider.get(
					"provider_id",
					""
				)
			)
		)

		if provider_id == "":
			continue

		var provider_object: Object = (
			provider_objects.get(
				provider_id,
				null
			)
		)

		var exposes_setup: bool = (
			provider_object != null
			and provider_object.has_method(
				"setup_contract"
			)
		)

		var launch_action: Dictionary = (
			host_identity.duplicate(false)
		)

		launch_action [
			"action_id"
		] = (
			"open_provider_setup"
			if exposes_setup
			else "launch_provider"
		)

		launch_action [
			"provider_id"
		] = provider_id

		launch_action [
			"multiplayer_mode"
		] = "single_vs_ai"

		launch_action [
			"active_section"
		] = (
			"games"
			if exposes_setup
			else "session"
		)

		provider [
			"source_kind"
		] = "first_party_provider"

		provider [
			"setup_available"
		] = exposes_setup

		provider [
			"launch_action"
		] = launch_action

		out.append(
			provider
		)

		if out.size() >= MAX_PROVIDER_ROWS:
			break

	return out


func _emit_games_surface_packet(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var host_contract: Dictionary = _dict(
		context.get(
			"host_contract",
			{}
		)
	)

	var provider_rows_raw: Variant = context.get(
		"provider_rows_override",
		[]
	)

	var provider_rows: Array = (
		provider_rows_raw as Array
		if typeof(
			provider_rows_raw
		) == TYPE_ARRAY
		else []
	)

	return {
		"success": true,
		"schema": "eralife.minigame_surface_packet",
		"version": 2,
		"surface_scope": "games",
		"actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"actor_name": _person_name(
			actor
		),
		"title": str(
			host_contract.get(
				"title",
				"MINIGAME ECOSYSTEM"
			)
		),
		"subtitle": (
			"Resident games are ready for observation."
		),
		"active_section": "games",
		"section_tabs": _mini_game_section_tabs(),
		"host_contract": host_contract,
		"provider_rows": provider_rows,
		"provider_setup_contract": {},
		"session_contract": {},
		"status_text": str(
			context.get(
				"status_text",
				"Choose a game."
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"progressive_observability": true,
		"ui_is_renderer_only": true
	}
func _provider_setup_key(
	actor: Person,
	host_contract: Dictionary,
	provider_id: String
) -> String:
	return (
		"%d::%s::%s"
		% [
			int(actor.id)
			if actor != null
			else -1,
			str(
				host_contract.get(
					"host_id",
					"global"
				)
			),
			_id(
				provider_id
			)
		]
	)
func _host_intent_identity(
	host_contract: Dictionary
) -> Dictionary:
	return {
		"host_id": str(
			host_contract.get(
				"host_id",
				""
			)
		),
		"host_kind": str(
			host_contract.get(
				"host_kind",
				""
			)
		),
		"fixture_id": str(
			host_contract.get(
				"fixture_id",
				""
			)
		),
		"property_id": int(
			host_contract.get(
				"property_id",
				-1
			)
		),
		"room_id": str(
			host_contract.get(
				"room_id",
				""
			)
		),
		"ui_is_renderer_only": true,
	}
func _provider_setup_contract(
	actor: Person,
	provider_id: String,
	host_contract: Dictionary,
	_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var clean_provider_id: String = _id(
		provider_id
	)
	var provider_object: Object = provider_objects.get(
		clean_provider_id,
		null
	)

	if (
		provider_object == null
		or not provider_object.has_method(
			"setup_contract"
		)
	):
		return {}

	var base_raw: Variant = provider_object.call(
		"setup_contract"
	)

	if typeof(base_raw) != TYPE_DICTIONARY:
		return {}

	var base: Dictionary = (
		base_raw as Dictionary
	).duplicate(true)

	if base.is_empty():
		return {}

	var setup_key: String = (
		_provider_setup_key(
			actor,
			host_contract,
			clean_provider_id
		)
	)

	var registry: Dictionary = _dict(
		state.get(
			"provider_setup_by_actor_host",
			{}
		)
	)

	var saved: Dictionary = _dict(
		registry.get(
			setup_key,
			{}
		)
	)

	var arenas: Array = _array(
		base.get(
			"arenas",
			[]
		)
	)

	var default_arena_id: String = _id(
		str(
			base.get(
				"default_arena_id",
				(
					str(
						_dict(
							arenas [0]
						).get(
							"arena_id",
							""
						)
					)
					if not arenas.is_empty()
					else ""
				)
			)
		)
	)

	var selected_arena_id: String = _id(
		str(
			saved.get(
				"arena_id",
				default_arena_id
			)
		)
	)

	var arena_ids: Dictionary = {}

	for raw_arena in arenas:
		var arena: Dictionary = _dict(
			raw_arena
		)
		var arena_id: String = _id(
			str(
				arena.get(
					"arena_id",
					""
				)
			)
		)

		if arena_id != "":
			arena_ids [
				arena_id
			] = true

	if not arena_ids.has(
		selected_arena_id
	):
		selected_arena_id = default_arena_id

	var maximum_total_players: int = clampi(
		int(
			base.get(
				"maximum_total_players",
				4
			)
		),
		2,
		4
	)

	var minimum_opponents: int = maxi(
		1,
		int(
			base.get(
				"minimum_opponents",
				1
			)
		)
	)

	var maximum_opponents: int = clampi(
		int(
			base.get(
				"maximum_opponents",
				maximum_total_players - 1
			)
		),
		minimum_opponents,
		maximum_total_players - 1
	)

	var selected_opponent_count: int = clampi(
		int(
			saved.get(
				"opponent_count",
				base.get(
					"default_opponent_count",
					1
				)
			)
		),
		minimum_opponents,
		maximum_opponents
	)

	var host_identity: Dictionary = (
		_host_intent_identity(
			host_contract
		)
	)

	var arena_rows: Array = []

	for raw_arena in arenas:
		var arena: Dictionary = _dict(
			raw_arena
		).duplicate(true)

		var arena_id: String = _id(
			str(
				arena.get(
					"arena_id",
					""
				)
			)
		)

		if arena_id == "":
			continue

		var select_action: Dictionary = (
			host_identity.duplicate(false)
		)

		select_action [
			"action_id"
		] = "configure_provider"
		select_action [
			"provider_id"
		] = clean_provider_id
		select_action [
			"setup_field"
		] = "arena_id"
		select_action [
			"setup_value"
		] = arena_id
		select_action [
			"active_section"
		] = "games"

		arena [
			"selected"
		] = (
			arena_id == selected_arena_id
		)
		arena [
			"select_action"
		] = select_action

		arena_rows.append(
			arena
		)
	var map_sizes: Array = _array(
		base.get(
			"map_sizes",
			[]
		)
	)

	var default_map_size_id: String = _id(
		str(
			base.get(
				"default_map_size_id",
				(
					str(
						_dict(
							map_sizes [0]
						).get(
							"map_size_id",
							"standard"
						)
					)
					if not map_sizes.is_empty()
					else "standard"
				)
			)
		)
	)

	var selected_map_size_id: String = _id(
		str(
			saved.get(
				"map_size_id",
				default_map_size_id
			)
		)
	)

	var map_size_ids: Dictionary = {}

	for raw_map_size in map_sizes:
		var map_size: Dictionary = _dict(
			raw_map_size
		)

		var map_size_id: String = _id(
			str(
				map_size.get(
					"map_size_id",
					""
				)
			)
		)

		if map_size_id != "":
			map_size_ids [
				map_size_id
			] = true

	if (
		not map_sizes.is_empty()
		and not map_size_ids.has(
			selected_map_size_id
		)
	):
		selected_map_size_id = default_map_size_id

	var map_size_rows: Array = []

	for raw_map_size in map_sizes:
		var map_size: Dictionary = _dict(
			raw_map_size
		).duplicate(true)

		var map_size_id: String = _id(
			str(
				map_size.get(
					"map_size_id",
					""
				)
			)
		)

		if map_size_id == "":
			continue

		var select_action: Dictionary = (
			host_identity.duplicate(false)
		)

		select_action [
			"action_id"
		] = "configure_provider"

		select_action [
			"provider_id"
		] = clean_provider_id

		select_action [
			"setup_field"
		] = "map_size_id"

		select_action [
			"setup_value"
		] = map_size_id

		select_action [
			"active_section"
		] = "games"

		map_size [
			"selected"
		] = (
			map_size_id
			== selected_map_size_id
		)

		map_size [
			"select_action"
		] = select_action

		map_size_rows.append(
			map_size
		)
	var opponent_rows: Array = []

	for opponent_count in range(
		minimum_opponents,
		maximum_opponents + 1
	):
		var select_action: Dictionary = (
			host_identity.duplicate(false)
		)

		select_action [
			"action_id"
		] = "configure_provider"
		select_action [
			"provider_id"
		] = clean_provider_id
		select_action [
			"setup_field"
		] = "opponent_count"
		select_action [
			"setup_value"
		] = opponent_count
		select_action [
			"active_section"
		] = "games"

		opponent_rows.append({
			"opponent_count": opponent_count,
			"total_fighters": opponent_count + 1,
			"selected": (
				opponent_count
				== selected_opponent_count
			),
			"select_action": select_action
		})

	var start_action: Dictionary = (
		host_identity.duplicate(false)
	)

	start_action [
		"action_id"
	] = "launch_provider"

	start_action [
		"provider_id"
	] = clean_provider_id

	start_action [
		"multiplayer_mode"
	] = "single_vs_ai"

	start_action [
		"use_saved_setup"
	] = true

	start_action [
		"arena_id"
	] = selected_arena_id

	start_action [
		"map_size_id"
	] = selected_map_size_id

	start_action [
		"opponent_count"
	] = selected_opponent_count

	start_action [
		"active_section"
	] = "session"

	var back_action: Dictionary = (
		host_identity.duplicate(false)
	)

	back_action [
		"action_id"
	] = "emit_hub"

	back_action [
		"active_section"
	] = "games"

	var out: Dictionary = base.duplicate(true)

	out [
		"schema"
	] = "eralife.minigame_provider_setup_contract"

	out [
		"version"
	] = 2

	out [
		"actor_id"
	] = int(
		actor.id
	)

	out [
		"provider_id"
	] = clean_provider_id

	out [
		"host_id"
	] = str(
		host_contract.get(
			"host_id",
			""
		)
	)

	out [
		"arena_rows"
	] = arena_rows

	out [
		"map_size_rows"
	] = map_size_rows

	out [
		"opponent_rows"
	] = opponent_rows

	out [
		"selected_arena_id"
	] = selected_arena_id

	out [
		"selected_map_size_id"
	] = selected_map_size_id

	out [
		"selected_opponent_count"
	] = selected_opponent_count

	out [
		"total_fighters"
	] = selected_opponent_count + 1

	out [
		"start_action"
	] = start_action

	out [
		"back_action"
	] = back_action

	out [
		"setup_revision"
	] = (
		"%s:%s:%s:%d"
		% [
			setup_key,
			selected_arena_id,
			selected_map_size_id,
			selected_opponent_count
		]
	)

	out [
		"truth_state"
	] = "hot"

	out [
		"authoritative_configuration"
	] = true

	out [
		"ui_is_renderer_only"
	] = true

	return out
func _open_provider_setup(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return _failure(
			"actor_missing",
			"A controlled actor is required to configure a minigame."
		)

	var provider_id: String = _id(
		str(
			payload.get(
				"provider_id",
				StickFighterMiniGameProvider.PROVIDER_ID
			)
		)
	)

	var host_contract: Dictionary = (
		_resolve_host(
			actor,
			payload
		)
	)

	var setup_contract: Dictionary = (
		_provider_setup_contract(
			actor,
			provider_id,
			host_contract,
			payload
		)
	)

	if setup_contract.is_empty():
		return _failure(
			"provider_setup_unavailable",
			(
				"Provider '%s' does not expose a setup contract."
				% provider_id
			)
		)

	setup_contract = _attach_provider_setup_extensions(
		actor,
		provider_id,
		host_contract,
		setup_contract
	)

	return _wrap_hub_result(
		actor,
		{
			"observation_scope": "provider_setup",
			"active_section": "games",
			"host_contract": host_contract,
			"provider_id": provider_id,
			"provider_setup_open": true,
			"provider_setup_contract_override": (
				setup_contract
			),
			"status_text": (
				"Choose an arena, map size, CPU count, and difficulty."
			)
		},
		{
			"mode": "minigame_provider_setup_opened",
			"provider_id": provider_id,
			"setup_revision": str(
				setup_contract.get(
					"setup_revision",
					""
				)
			),
		}
	)


func _attach_provider_setup_extensions(
	actor: Person,
	provider_id: String,
	host_contract: Dictionary,
	setup_contract: Dictionary
) -> Dictionary:
	var out: Dictionary = setup_contract.duplicate(false)

	var difficulty_definitions: Array = _array(
		out.get(
			"ai_difficulties",
			[]
		)
	)

	if difficulty_definitions.is_empty():
		return out

	var setup_key: String = _provider_setup_key(
		actor,
		host_contract,
		provider_id
	)

	var registry: Dictionary = _dict(
		state.get(
			"provider_setup_by_actor_host",
			{}
		)
	)

	var saved: Dictionary = _dict(
		registry.get(
			setup_key,
			{}
		)
	)

	var default_difficulty_id: String = _id(
		str(
			out.get(
				"default_ai_difficulty_id",
				"normal"
			)
		)
	)

	var selected_difficulty_id: String = _id(
		str(
			saved.get(
				"ai_difficulty_id",
				default_difficulty_id
			)
		)
	)

	var valid_ids: Dictionary = {}

	for raw_difficulty in difficulty_definitions:
		var difficulty: Dictionary = _dict(
			raw_difficulty
		)

		var difficulty_id: String = _id(
			str(
				difficulty.get(
					"ai_difficulty_id",
					""
				)
			)
		)

		if difficulty_id != "":
			valid_ids [
				difficulty_id
			] = true

	if not valid_ids.has(
		selected_difficulty_id
	):
		selected_difficulty_id = default_difficulty_id

	var host_identity: Dictionary = (
		_host_intent_identity(
			host_contract
		)
	)

	var rows: Array = []

	for raw_difficulty in difficulty_definitions:
		var difficulty: Dictionary = _dict(
			raw_difficulty
		).duplicate(true)

		var difficulty_id: String = _id(
			str(
				difficulty.get(
					"ai_difficulty_id",
					""
				)
			)
		)

		if difficulty_id == "":
			continue

		var select_action: Dictionary = (
			host_identity.duplicate(false)
		)

		select_action [
			"action_id"
		] = "configure_provider"

		select_action [
			"provider_id"
		] = provider_id

		select_action [
			"setup_field"
		] = "ai_difficulty_id"

		select_action [
			"setup_value"
		] = difficulty_id

		select_action [
			"active_section"
		] = "games"

		difficulty [
			"selected"
		] = (
			difficulty_id
			== selected_difficulty_id
		)

		difficulty [
			"select_action"
		] = select_action

		rows.append(
			difficulty
		)

	out [
		"ai_difficulty_rows"
	] = rows

	out [
		"selected_ai_difficulty_id"
	] = selected_difficulty_id

	var start_action: Dictionary = _dict(
		out.get(
			"start_action",
			{}
		)
	).duplicate(false)

	start_action [
		"ai_difficulty_id"
	] = selected_difficulty_id

	out [
		"start_action"
	] = start_action

	out [
		"setup_revision"
	] = (
		"%s:%s"
		% [
			str(
				out.get(
					"setup_revision",
					setup_key
				)
			),
			selected_difficulty_id
		]
	)

	return out
func _configure_provider_setup(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return _failure(
			"actor_missing",
			"A controlled actor is required to configure a minigame."
		)

	var provider_id: String = _id(
		str(
			payload.get(
				"provider_id",
				StickFighterMiniGameProvider.PROVIDER_ID
			)
		)
	)

	var host_contract: Dictionary = (
		_resolve_host(
			actor,
			payload
		)
	)

	var current_setup: Dictionary = (
		_provider_setup_contract(
			actor,
			provider_id,
			host_contract,
			payload
		)
	)

	if current_setup.is_empty():
		return _failure(
			"provider_setup_unavailable",
			"That minigame does not expose configurable setup truth."
		)

	current_setup = _attach_provider_setup_extensions(
		actor,
		provider_id,
		host_contract,
		current_setup
	)

	var setup_key: String = (
		_provider_setup_key(
			actor,
			host_contract,
			provider_id
		)
	)

	var registry: Dictionary = _dict(
		state.get(
			"provider_setup_by_actor_host",
			{}
		)
	).duplicate(false)

	var saved: Dictionary = _dict(
		registry.get(
			setup_key,
			{}
		)
	).duplicate(false)

	var setup_field: String = _id(
		str(
			payload.get(
				"setup_field",
				""
			)
		)
	)

	match setup_field:
		"arena_id":
			var requested_arena_id: String = _id(
				str(
					payload.get(
						"setup_value",
						""
					)
				)
			)

			var arena_valid: bool = false

			for raw_arena in _array(
				current_setup.get(
					"arena_rows",
					[]
				)
			):
				var arena: Dictionary = _dict(
					raw_arena
				)

				if _id(
					str(
						arena.get(
							"arena_id",
							""
						)
					)
				) == requested_arena_id:
					arena_valid = true
					break

			if not arena_valid:
				return _failure(
					"arena_not_available",
					"That Stick Fighter arena is not observable."
				)

			saved [
				"arena_id"
			] = requested_arena_id

		"map_size_id":
			var requested_map_size_id: String = _id(
				str(
					payload.get(
						"setup_value",
						""
					)
				)
			)

			var map_size_valid: bool = false

			for raw_map_size in _array(
				current_setup.get(
					"map_size_rows",
					[]
				)
			):
				var map_size: Dictionary = _dict(
					raw_map_size
				)

				if _id(
					str(
						map_size.get(
							"map_size_id",
							""
						)
					)
				) == requested_map_size_id:
					map_size_valid = true
					break

			if not map_size_valid:
				return _failure(
					"map_size_not_available",
					"That Stick Fighter map size is not observable."
				)

			saved [
				"map_size_id"
			] = requested_map_size_id

		"ai_difficulty_id":
			var requested_difficulty_id: String = _id(
				str(
					payload.get(
						"setup_value",
						""
					)
				)
			)

			var difficulty_valid: bool = false

			for raw_difficulty in _array(
				current_setup.get(
					"ai_difficulty_rows",
					[]
				)
			):
				var difficulty: Dictionary = _dict(
					raw_difficulty
				)

				if _id(
					str(
						difficulty.get(
							"ai_difficulty_id",
							""
						)
					)
				) == requested_difficulty_id:
					difficulty_valid = true
					break

			if not difficulty_valid:
				return _failure(
					"ai_difficulty_not_available",
					"That AI difficulty is not observable."
				)

			saved [
				"ai_difficulty_id"
			] = requested_difficulty_id

		"opponent_count":
			var maximum_opponents: int = maxi(
				1,
				int(
					current_setup.get(
						"maximum_opponents",
						3
					)
				)
			)

			saved [
				"opponent_count"
			] = clampi(
				int(
					payload.get(
						"setup_value",
						1
					)
				),
				1,
				maximum_opponents
			)

		_:
			return _failure(
				"unknown_provider_setup_field",
				"That minigame setup field is not recognized."
			)

	saved [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	registry [
		setup_key
	] = saved

	state [
		"provider_setup_by_actor_host"
	] = registry

	_publish_provider_setup_delta(
		registry
	)

	var refresh_payload: Dictionary = (
		payload.duplicate(false)
	)

	refresh_payload [
		"provider_setup_open"
	] = true

	refresh_payload [
		"active_section"
	] = "games"

	return _open_provider_setup(
		actor,
		refresh_payload
	)


func _publish_provider_setup_delta(
	setup_registry: Dictionary
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

	var published: Dictionary = _dict(
		gs.scenario_state.get(
			STATE_KEY,
			{}
		)
	).duplicate(false)

	if published.is_empty():
		published = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"registered_providers": {},
			"provider_setup_by_actor_host": {}
		}

	published [
		"schema"
	] = ENGINE_SCHEMA

	published [
		"version"
	] = ENGINE_VERSION

	published [
		"updated_at_ms"
	] = int(
		state.get(
			"updated_at_ms",
			Time.get_ticks_msec()
		)
	)

	published [
		"registered_providers"
	] = _dict(
		state.get(
			"registered_providers",
			{}
		)
	).duplicate(false)



	published [
		"provider_setup_by_actor_host"
	] = setup_registry.duplicate(false)

	gs.scenario_state [
		STATE_KEY
	] = published
func _provider_ai_participant(
	provider_id: String,
	owner_actor_id: int,
	slot: int
) -> Dictionary:
	return {
		"identity_key": (
			"provider_ai:%s:%d:%d"
			% [
				_id(provider_id),
				owner_actor_id,
				slot
			]
		),
		"identity_kind": "provider_ai",
		"actor_id": -1,
		"display_name": "CPU %d" % slot,
		"controller": "npc_ai",
		"local_slot": slot,
		"is_ai": true,
		"is_local": false,
		"is_online": false,
	}

func emit_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_bootstrap()

	var host_contract: Dictionary = (
		_resolve_host(
			actor,
			context
		)
	)

	var providers: Array = (
		_available_provider_rows(
			actor,
			host_contract,
			context
		)
	)

	var identity: Dictionary = (
		_participant_for_actor(
			actor
		)
	)

	var identity_key: String = str(
		identity.get(
			"identity_key",
			""
		)
	)

	var active_session: Dictionary = {}

	if (
		gs != null
		and gs.mini_game_runtime_engine != null
	):
		active_session = (
			gs.mini_game_runtime_engine
			.session_for_identity(
				identity_key
			)
		)

	var session_contract: Dictionary = {}

	if not active_session.is_empty():
		session_contract = emit_session_contract(
			actor,
			str(
				active_session.get(
					"session_id",
					""
				)
			),
			context
		)

	var requested_provider_id: String = _id(
		str(
			context.get(
				"provider_id",
				""
			)
		)
	)

	var provider_id: String = (
		requested_provider_id
		if requested_provider_id != ""
		else _id(
			str(
				active_session.get(
					"provider_id",
					""
				)
			)
		)
	)

	var provider_setup_contract: Dictionary = {}

	if (
		bool(
			context.get(
				"provider_setup_open",
				false
			)
		)
		and provider_id != ""
		and actor != null
	):
		provider_setup_contract = (
			_provider_setup_contract(
				actor,
				provider_id,
				host_contract,
				context
			)
		)

	var scoreboard: Dictionary = {}
	var achievements: Dictionary = {}
	var replays: Dictionary = {}
	var multiplayer: Dictionary = {}
	var relationship_invite_rows: Array = []

	if (
		gs != null
		and gs.scoreboard_contract_engine != null
	):
		scoreboard = (
			gs.scoreboard_contract_engine
			.emit_scoreboard_contract(
				provider_id,
				context
			)
		)

	if (
		gs != null
		and gs.achievement_contract_engine != null
	):
		achievements = (
			gs.achievement_contract_engine
			.emit_achievement_contract(
				identity_key,
				provider_id
			)
		)

	if (
		gs != null
		and gs.replay_contract_engine != null
	):
		replays = (
			gs.replay_contract_engine
			.emit_replay_contract(
				provider_id,
				context
			)
		)

	if (
		gs != null
		and gs.multiplayer_contract_engine != null
	):
		multiplayer = (
			gs.multiplayer_contract_engine
			.emit_multiplayer_contract(
				actor,
				context
			)
		)

		relationship_invite_rows = (
			_relationship_invite_rows(
				actor,
				provider_id,
				host_contract
			)
		)

	var active_section: String = _id(
		str(
			context.get(
				"active_section",
				(
					"session"
					if not session_contract.is_empty()
					else "games"
				)
			)
		)
	)

	if (
		active_section not in [
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
		active_section = "games"

	return {
		"success": true,
		"schema": "eralife.minigame_hub_contract",
		"version": ENGINE_VERSION,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": _person_name(
			actor
		),
		"title": str(
			host_contract.get(
				"title",
				"MINIGAME ECOSYSTEM"
			)
		),
		"subtitle": (
			"Games are persistent reality sessions. "
			+ "The UI only renders committed contracts."
		),
		"active_section": active_section,
		"section_tabs": [
			{
				"id": "games",
				"label": "GAMES",
				"icon": "▦"
			},
			{
				"id": "session",
				"label": "LIVE SESSION",
				"icon": "▶"
			},
			{
				"id": "multiplayer",
				"label": "MULTIPLAYER",
				"icon": "◎"
			},
			{
				"id": "tournaments",
				"label": "TOURNAMENTS",
				"icon": "♛"
			},
			{
				"id": "leaderboards",
				"label": "LEADERBOARDS",
				"icon": "≡"
			},
			{
				"id": "achievements",
				"label": "ACHIEVEMENTS",
				"icon": "★"
			},
			{
				"id": "replays",
				"label": "REPLAYS",
				"icon": "↺"
			},
			{
				"id": "mods",
				"label": "MOD GAMES",
				"icon": "◆"
			}
		],
		"host_contract": host_contract,
		"provider_rows": providers,
		"provider_setup_contract": provider_setup_contract,
		"session_contract": session_contract,
		"scoreboard_contract": scoreboard,
		"achievement_contract": achievements,
		"replay_contract": replays,
		"multiplayer_contract": multiplayer,
		"relationship_invite_rows": relationship_invite_rows,
		"status_text": str(
			context.get(
				"status_text",
				"Choose a game or continue the committed session."
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"surface_revision": (
			"%d:%s:%d:%s:%s"
			% [
				int(actor.id)
				if actor != null
				else -1,
				str(
					host_contract.get(
						"host_id",
						"global"
					)
				),
				providers.size(),
				str(
					active_session.get(
						"updated_at_ms",
						0
					)
				),
				str(
					provider_setup_contract.get(
						"setup_revision",
						""
					)
				)
			]
		),
		"ui_is_renderer_only": true
	}

func emit_session_contract(
	actor: Person, session_id: String, context: Dictionary = {}
) -> Dictionary:
	_ensure_bootstrap()
	if gs == null or gs.mini_game_runtime_engine == null:
		return _failure("runtime_unavailable", "MiniGameRuntimeEngine is unavailable.")
	var session: Dictionary = gs.mini_game_runtime_engine.session(session_id)
	if session.is_empty():
		return {}
	var provider_id: String = _id(str(session.get("provider_id", "")))
	var provider_object: Object = provider_objects.get(provider_id, null)
	var identity: Dictionary = _participant_for_actor(actor)
	var identity_key: String = str(identity.get("identity_key", ""))
	var provider_state: Dictionary = _dict(session.get("provider_state", {}))
	var actions: Array = []
	var projection: Dictionary = {}
	if provider_object != null:
		actions = provider_object.available_actions(provider_state, identity_key)
		projection = provider_object.ui_projection(provider_state)
	var can_act: bool = not actions.is_empty()
	var spectator: bool = _identity_is_spectator(session, identity_key)
	return {
		"success": true,
		"schema": "eralife.minigame_session_projection",
		"version": ENGINE_VERSION,
		"session_id": session_id,
		"provider_id": provider_id,
		"game_title": str(session.get("game_title", provider_id.capitalize())),
		"host_contract": _dict(session.get("host_contract", {})).duplicate(true),
		"participants": _array(session.get("participants", [])).duplicate(true),
		"spectators": _array(session.get("spectators", [])).duplicate(true),
		"status": str(session.get("status", "active")),
		"provider_state": provider_state.duplicate(true),
		"ui_projection": projection,
		"actions": actions,
		"can_act": can_act,
		"spectator": spectator,
		"result_contract": _dict(session.get("result_contract", {})).duplicate(true),
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
	bootstrap_default_contracts()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _launch_provider(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return _failure(
			"actor_missing",
			(
				"A controlled actor is required to commit "
				+ "a minigame session."
			)
		)

	var provider_id: String = _id(
		str(
			payload.get(
				"provider_id",
				StickFighterMiniGameProvider.PROVIDER_ID
			)
		)
	)

	var provider_contract: Dictionary = _dict(
		provider_contracts.get(
			provider_id,
			{}
		)
	)

	var provider_object: Object = (
		provider_objects.get(
			provider_id,
			null
		)
	)

	if (
		provider_contract.is_empty()
		or provider_object == null
	):
		return _launch_mod_provider(
			actor,
			provider_id,
			payload
		)

	var host_contract: Dictionary = (
		_resolve_host(
			actor,
			payload
		)
	)

	var launch_payload: Dictionary = (
		payload.duplicate(false)
	)

	var setup_contract: Dictionary = {}

	if provider_object.has_method(
		"setup_contract"
	):
		setup_contract = (
			_provider_setup_contract(
				actor,
				provider_id,
				host_contract,
				payload
			)
		)

	if not setup_contract.is_empty():
		launch_payload [
			"arena_id"
		] = _id(
			str(
				payload.get(
					"arena_id",
					setup_contract.get(
						"selected_arena_id",
						""
					)
				)
			)
		)

		launch_payload [
			"opponent_count"
		] = clampi(
			int(
				payload.get(
					"opponent_count",
					setup_contract.get(
						"selected_opponent_count",
						1
					)
				)
			),
			1,
			int(
				setup_contract.get(
					"maximum_opponents",
					3
				)
			)
		)

	var multiplayer_mode: String = _id(
		str(
			launch_payload.get(
				"multiplayer_mode",
				"single_vs_ai"
			)
		)
	)

	var maximum_players: int = clampi(
		int(
			provider_contract.get(
				"maximum_players",
				1
			)
		),
		1,
		4
	)

	var participants: Array = []

	if (
		multiplayer_mode == "single_vs_ai"
		and not setup_contract.is_empty()
	):
		participants.append(
			_participant_for_actor(
				actor
			)
		)

		var opponent_count: int = clampi(
			int(
				launch_payload.get(
					"opponent_count",
					1
				)
			),
			1,
			maxi(
				1,
				maximum_players - 1
			)
		)

		for slot in range(
			1,
			opponent_count + 1
		):
			participants.append(
				_provider_ai_participant(
					provider_id,
					int(
						actor.id
					),
					slot
				)
			)
	else:
		participants = (
			_participants_for_launch(
				actor,
				launch_payload
			)
		)

		if (
			participants.size() < 2
			and maximum_players >= 2
		):
			var ai_actor: Person = (
				_default_ai_opponent(
					actor,
					launch_payload
				)
			)

			if ai_actor != null:
				participants.append(
					_participant_for_actor(
						ai_actor,
						"npc_ai",
						1
					)
				)
			else:
				participants.append(
					_provider_ai_participant(
						provider_id,
						int(
							actor.id
						),
						1
					)
				)

	while participants.size() > maximum_players:
		participants.pop_back()

	var continuous_contract: Dictionary = {}

	if provider_object.has_method(
		"continuous_runtime_contract"
	):
		var continuous_raw: Variant = (
			provider_object.call(
				"continuous_runtime_contract"
			)
		)

		if typeof(
			continuous_raw
		) == TYPE_DICTIONARY:
			continuous_contract = (
				continuous_raw as Dictionary
			)

	var continuous_runtime: bool = bool(
		continuous_contract.get(
			"enabled",
			false
		)
	)

	launch_payload [
		"continuous_runtime"
	] = continuous_runtime
	launch_payload [
		"actor_id"
	] = int(actor.id)

	var provider_state: Dictionary = (
		provider_object.initial_session_state(
			participants,
			launch_payload
		)
	)

	var runtime_report: Dictionary = (
		gs.mini_game_runtime_engine
		.create_session(
			provider_contract,
			host_contract,
			participants,
			provider_state,
			launch_payload
		)
	)

	if not bool(
		runtime_report.get(
			"success",
			false
		)
	):
		return runtime_report

	var session: Dictionary = _dict(
		runtime_report.get(
			"session",
			{}
		)
	)

	session [
		"multiplayer_mode"
	] = multiplayer_mode

	var session_id: String = str(
		session.get(
			"session_id",
			""
		)
	)

	var start_events: Array = [
		{
			"event_type": "minigame_session_started",
			"provider_id": provider_id,
			"arena_id": str(
				launch_payload.get(
					"arena_id",
					""
				)
			),
			"opponent_count": int(
				launch_payload.get(
					"opponent_count",
					maxi(
						0,
						participants.size() - 1
					)
				)
			),
			"text": (
				"%s started %s."
				% [
					_person_name(actor),
					str(
						provider_contract.get(
							"title",
							provider_id.capitalize()
						)
					)
				]
			)
		}
	]

	if continuous_runtime:
		var activation_report: Dictionary = (
			gs.mini_game_runtime_engine
			.activate_continuous_session(
				session_id,
				provider_id,
				provider_object,
				provider_state,
				continuous_contract,
				start_events,
				launch_payload,
				Callable(
					self,
					"_publish_continuous_session_observation"
				),
				Callable(
					self,
					"_complete_continuous_session_observation"
				)
			)
		)

		if not bool(
			activation_report.get(
				"success",
				false
			)
		):
			return activation_report

		var initial_session_projection: Dictionary = (
			_session_projection_from_state(
				actor,
				session,
				provider_object,
				provider_state,
				launch_payload
			)
		)

		return _wrap_hub_result(
			actor,
			{
				"observation_scope": "session",
				"active_section": "session",
				"session_id": session_id,
				"host_contract": host_contract,
				"session_contract_override": (
					initial_session_projection
				),
				"status_text": (
					"The continuous minigame session is live."
				)
			},
			{
				"mode": "minigame_continuous_session_started",
				"session_id": session_id,
				"runtime_report": activation_report,
				"arena_id": str(
					launch_payload.get(
						"arena_id",
						""
					)
				),
				"fighter_count": participants.size(),
			}
		)


	gs.mini_game_runtime_engine.commit_session_state(
		session_id,
		provider_state,
		start_events,
		launch_payload
	)

	if gs.replay_contract_engine != null:
		gs.replay_contract_engine.begin_replay(
			session
		)

	return _wrap_hub_result(
		actor,
		{
			"active_section": "session",
			"host_contract": host_contract,
			"status_text": (
				"The minigame session was committed to reality."
			)
		},
		{
			"mode": "minigame_session_started",
			"session_id": session_id,
			"runtime_report": runtime_report,
			"arena_id": str(
				launch_payload.get(
					"arena_id",
					""
				)
			),
			"fighter_count": participants.size()
		}
	)
func _publish_continuous_session_observation(
	runtime_packet: Dictionary
) -> void:
	var session_id: String = str(
		runtime_packet.get(
			"session_id",
			""
		)
	)

	if session_id == "":
		return

	var packet: Dictionary = {
		"success": true,
		"schema": "eralife.minigame_session_observation_packet",
		"version": 1,
		"session_id": session_id,
		"provider_id": str(
			runtime_packet.get(
				"provider_id",
				""
			)
		),
		"revision": int(
			runtime_packet.get(
				"revision",
				0
			)
		),
		"simulation_step": int(
			runtime_packet.get(
				"simulation_step",
				0
			)
		),
		"ui_projection": _dict(
			runtime_packet.get(
				"ui_projection",
				{}
			)
		),
		"status_text": str(
			runtime_packet.get(
				"status_text",
				"Stick Fighter is live."
			)
		),
		"complete": bool(
			runtime_packet.get(
				"complete",
				false
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"observation_channel": "minigame_session",
		"ui_is_renderer_only": true
	}

	if (
		gs != null
		and gs.reality_projection_contract_engine != null
		and gs.reality_projection_contract_engine.has_method(
			"publish_resident_continuous_observation"
		)
	):
		gs.reality_projection_contract_engine.publish_resident_continuous_observation(
			session_id,
			packet
		)



	session_observation_ready.emit(
		session_id,
		packet
	)

func _complete_continuous_session_observation(
	runtime_report: Dictionary
) -> void:
	var session_id: String = str(
		runtime_report.get(
			"session_id",
			""
		)
	)

	if session_id == "":
		return

	var final_projection: Dictionary = _dict(
		runtime_report.get(
			"ui_projection",
			{}
		)
	)

	_publish_continuous_session_observation({
		"session_id": session_id,
		"provider_id": str(
			runtime_report.get(
				"provider_id",
				""
			)
		),
		"revision": int(
			runtime_report.get(
				"revision",
				0
			)
		),
		"simulation_step": int(
			runtime_report.get(
				"simulation_step",
				0
			)
		),
		"ui_projection": final_projection,
		"status_text": str(
			final_projection.get(
				"headline",
				"Stick Fighter match complete."
			)
		),
		"complete": true
	})


	call_deferred(
		"_finalize_continuous_session_after_observation",
		runtime_report.duplicate(false)
	)


func _finalize_continuous_session_after_observation(
	runtime_report: Dictionary
) -> void:
	var session: Dictionary = _dict(
		runtime_report.get(
			"session",
			{}
		)
	)

	var result_contract: Dictionary = _dict(
		runtime_report.get(
			"result_contract",
			{}
		)
	)

	if (
		session.is_empty()
		or result_contract.is_empty()
	):
		return

	var context: Dictionary = _dict(
		runtime_report.get(
			"context",
			{}
		)
	)

	var actor: Person = _person_by_id(
		int(
			context.get(
				"actor_id",
				-1
			)
		)
	)

	if gs.replay_contract_engine != null:
		gs.replay_contract_engine.begin_replay(
			session
		)

		if gs.replay_contract_engine.has_method(
			"append_events_batch"
		):
			gs.replay_contract_engine.append_events_batch(
				str(
					session.get(
						"session_id",
						""
					)
				),
				_array(
					runtime_report.get(
						"events",
						[]
					)
				)
			)

	_finalize_session(
		session,
		result_contract,
		actor,
		context
	)

func _commit_provider_action(actor: Person, payload: Dictionary) -> Dictionary:
	if actor == null or gs == null or gs.mini_game_runtime_engine == null:
		return _failure("runtime_unavailable", "The committed minigame runtime is unavailable.")
	var session_id: String = str(payload.get("session_id", "")).strip_edges()
	var session: Dictionary = gs.mini_game_runtime_engine.session(session_id)
	if session.is_empty():
		return _failure("session_missing", "The requested minigame session does not exist.")
	var provider_id: String = _id(str(session.get("provider_id", "")))
	var provider_object: Object = provider_objects.get(provider_id, null)
	if provider_object == null:
		return _failure(
			"provider_runtime_missing", "The provider runtime for this session is unavailable."
		)
	var identity: Dictionary = _participant_for_actor(actor)
	var identity_key: String = str(identity.get("identity_key", ""))
	var provider_report: Dictionary = provider_object.resolve_action(
		_dict(session.get("provider_state", {})),
		identity_key,
		str(
			payload.get(
				"game_action_id",
				payload.get("provider_action_id", payload.get("selected_action_id", ""))
			)
		),
		payload
	)
	if not bool(provider_report.get("success", false)):
		return provider_report
	var provider_state: Dictionary = _dict(provider_report.get("provider_state", {}))
	var events: Array = _array(provider_report.get("events", []))
	var runtime_report: Dictionary = gs.mini_game_runtime_engine.commit_session_state(
		session_id, provider_state, events, payload
	)
	for raw_event in events:
		if gs.replay_contract_engine != null:
			gs.replay_contract_engine.append_event(session_id, _dict(raw_event))
	var completion_reports: Dictionary = {}
	if bool(provider_report.get("complete", false)):
		var result_contract: Dictionary = _dict(provider_report.get("result_contract", {}))
		var completed: Dictionary = gs.mini_game_runtime_engine.complete_session(
			session_id, result_contract
		)
		completion_reports = _finalize_session(
			_dict(completed.get("session", {})), result_contract, actor, payload
		)
	return _wrap_hub_result(
		actor,
		{
			"active_section": "session",
			"host_contract": _dict(session.get("host_contract", {})),
			"status_text": str(_last_event_text(events, "The game action was committed."))
		},
		{
			"mode": "minigame_action_committed",
			"session_id": session_id,
			"provider_report": provider_report,
			"runtime_report": runtime_report,
			"completion_reports": completion_reports
		}
	)


func _finalize_session(
	session: Dictionary, result_contract: Dictionary, actor: Person, context: Dictionary
) -> Dictionary:
	var reports: Dictionary = {}
	if gs.scoreboard_contract_engine != null:
		reports ["scoreboard"] = gs.scoreboard_contract_engine.record_session_result(
			session, result_contract, context
		)
	if gs.achievement_contract_engine != null:
		reports ["achievements"] = gs.achievement_contract_engine.evaluate_session(
			session, result_contract, context
		)
	if gs.replay_contract_engine != null:
		reports ["replay"] = gs.replay_contract_engine.finalize_replay(session, result_contract)
	reports ["relationships"] = _commit_relationship_game_events(session, result_contract)
	reports ["diary"] = _commit_diary_memory(actor, session, result_contract)
	return reports


func _resolve_multiplayer_intent(actor: Person, payload: Dictionary) -> Dictionary:
	if gs == null or gs.multiplayer_contract_engine == null:
		return _failure("multiplayer_unavailable", "MultiplayerContractEngine is unavailable.")
	var multiplayer_report: Dictionary = gs.multiplayer_contract_engine.resolve_intent(
		actor, payload
	)
	var launch_after_accept: bool = (
		bool(multiplayer_report.get("accepted", false))
		and not _array(multiplayer_report.get("participants", [])).is_empty()
	)
	if launch_after_accept:
		var launch_payload: Dictionary = payload.duplicate(true)
		launch_payload ["action_id"] = "launch_provider"
		launch_payload ["participants"] = (
			_array(multiplayer_report.get("participants", [])).duplicate(true)
		)
		launch_payload ["multiplayer_mode"] = str(
			_dict(multiplayer_report.get("invitation", {})).get("invitation_kind", "relationship")
		)
		return _launch_provider(actor, launch_payload)
	return _wrap_hub_result(
		actor,
		payload,
		{ "mode": "multiplayer_intent_resolved", "multiplayer_report": multiplayer_report}
	)


func _spectate_session(actor: Person, payload: Dictionary) -> Dictionary:
	if gs == null or gs.multiplayer_contract_engine == null:
		return _failure("multiplayer_unavailable", "Spectator authority is unavailable.")
	var report: Dictionary = gs.multiplayer_contract_engine.add_spectator(
		str(payload.get("session_id", "")), actor, payload
	)
	return _wrap_hub_result(
		actor,
		{
			"active_section": "session",
			"session_id": str(payload.get("session_id", "")),
			"status_text": "You are now observing the committed session."
		},
		{ "mode": "spectator_attached", "spectator_report": report}
	)


func _available_provider_rows(
	actor: Person,
	host_contract: Dictionary,
	context: Dictionary
) -> Array:
	var out: Array = []
	var host_identity: Dictionary = (
		_host_intent_identity(
			host_contract
		)
	)

	for raw_contract in provider_contracts.values():
		var provider: Dictionary = _dict(
			raw_contract
		).duplicate(true)

		if not _provider_supported_by_host(
			provider,
			host_contract
		):
			continue

		var provider_id: String = _id(
			str(
				provider.get(
					"provider_id",
					""
				)
			)
		)

		var provider_object: Object = (
			provider_objects.get(
				provider_id,
				null
			)
		)

		var exposes_setup: bool = (
			provider_object != null
			and provider_object.has_method(
				"setup_contract"
			)
		)

		var launch_action: Dictionary = (
			host_identity.duplicate(false)
		)

		launch_action [
			"action_id"
		] = (
			"open_provider_setup"
			if exposes_setup
			else "launch_provider"
		)
		launch_action [
			"provider_id"
		] = provider_id
		launch_action [
			"multiplayer_mode"
		] = "single_vs_ai"
		launch_action [
			"active_section"
		] = (
			"games"
			if exposes_setup
			else "session"
		)

		provider [
			"source_kind"
		] = "first_party_provider"
		provider [
			"setup_available"
		] = exposes_setup
		provider [
			"launch_action"
		] = launch_action

		out.append(
			provider
		)

	if (
		gs != null
		and gs.mod_contract_engine != null
	):
		for raw_row in (
			gs.mod_contract_engine
			.emit_provider_rows(
				"minigames",
				actor,
				{
					"target_id": str(
						context.get(
							"target_id",
							"minigame_ecosystem"
						)
					),
					"host_contract": (
						host_contract.duplicate(true)
					),
					"source": (
						"mini_game_contract_engine."
						+ "available_provider_rows"
					)
				}
			)
		):
			var row: Dictionary = _dict(
				raw_row
			).duplicate(true)

			row [
				"source_kind"
			] = "mod_provider"
			row [
				"mod_created_minigame"
			] = true
			row [
				"launch_action"
			] = {
				"action_id": "launch_provider",
				"provider_id": str(
					row.get(
						"provider_id",
						""
					)
				),
				"canonical_provider_key": str(
					row.get(
						"canonical_provider_key",
						""
					)
				),
				"provider_action_id": str(
					row.get(
						"launch_action_id",
						"launch"
					)
				),
				"host_contract": (
					host_contract.duplicate(true)
				),
				"ui_is_renderer_only": true
			}

			out.append(
				row
			)

			if out.size() >= MAX_PROVIDER_ROWS:
				break

	return out

func _launch_mod_provider(actor: Person, provider_id: String, payload: Dictionary) -> Dictionary:
	if gs == null or gs.mod_contract_engine == null:
		return _failure("provider_missing", "That MiniGame provider is not installed.")
	var route_payload: Dictionary = payload.duplicate(true)
	route_payload ["provider_id"] = provider_id
	var route_report: Dictionary = gs.mod_contract_engine.resolve_provider_intent(
		actor, route_payload
	)
	if not bool(route_report.get("success", false)):
		return route_report
	var launch_contract: Dictionary = _dict(
		route_report.get("minigame_launch_contract", route_report.get("result", {}))
	)
	if launch_contract.is_empty():
		return _failure(
			"mod_provider_launch_contract_missing",
			"The mod provider did not return a minigame launch contract."
		)
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "mod_minigame_provider_resolved",
		"mod_provider_report": route_report,
		"minigame_launch_contract": launch_contract,
		"ui_is_renderer_only": true
	}


func _participants_for_launch(actor: Person, payload: Dictionary) -> Array:
	var supplied: Array = _array(payload.get("participants", []))
	if not supplied.is_empty():
		var out: Array = []
		for raw_row in supplied:
			if typeof(raw_row) == TYPE_DICTIONARY:
				out.append((raw_row as Dictionary).duplicate(true))
		return out
	var participants: Array = [_participant_for_actor(actor)]
	var target_actor_id: int = int(payload.get("target_actor_id", -1))
	if target_actor_id > 0:
		var target: Person = _person_by_id(target_actor_id)
		if target != null:
			participants.append(_participant_for_actor(target, "npc_ai", 1))
	return participants


func _default_ai_opponent(actor: Person, payload: Dictionary) -> Person:
	var target_actor_id: int = int(payload.get("target_actor_id", -1))
	if target_actor_id > 0:
		var targeted: Person = _person_by_id(target_actor_id)
		if targeted != null:
			return targeted
	if gs == null:
		return null
	var candidate_ids: Array = []
	for raw_id in actor.parents:
		candidate_ids.append(int(raw_id))
	for raw_id in actor.children:
		candidate_ids.append(int(raw_id))
	if actor.partner != null:
		candidate_ids.append(int(actor.partner.id))
	for raw_id in candidate_ids:
		var candidate: Person = _person_by_id(int(raw_id))
		if candidate != null and candidate != actor:
			return candidate
	for raw_candidate in gs.npcs:
		var candidate:= raw_candidate as Person
		if candidate != null and candidate != actor and bool(candidate.alive):
			return candidate
	return null


func _relationship_invite_rows(
	actor: Person,
	provider_id: String,
	host_contract: Dictionary
) -> Array:
	if actor == null:
		return []

	var candidate_ids: Array = []
	var seen: Dictionary = {}

	for raw_id in actor.parents:
		candidate_ids.append(
			int(
				raw_id
			)
		)

	for raw_id in actor.children:
		candidate_ids.append(
			int(
				raw_id
			)
		)

	if actor.partner != null:
		candidate_ids.append(
			int(
				actor.partner.id
			)
		)




	for raw_parent_id in actor.parents:
		var parent: Person = _person_by_id(
			int(
				raw_parent_id
			)
		)

		if parent == null:
			continue

		for raw_child_id in parent.children:
			var sibling_id: int = int(
				raw_child_id
			)

			if sibling_id == int(
				actor.id
			):
				continue

			candidate_ids.append(
				sibling_id
			)

	var out: Array = []

	for raw_id in candidate_ids:
		var actor_id: int = int(
			raw_id
		)

		if (
			actor_id <= 0
			or actor_id == int(
				actor.id
			)
			or seen.has(
				actor_id
			)
		):
			continue

		seen [
			actor_id
		] = true

		var target: Person = _person_by_id(
			actor_id
		)

		if (
			target == null
			or not bool(
				target.alive
			)
		):
			continue

		out.append(
			{
				"actor_id": actor_id,
				"display_name": _person_name(
					target
				),
				"age": int(
					target.age
				),
				"provider_id": provider_id,
				"invite_action": {
					"action_id": "invite_relationship",
					"target_actor_id": actor_id,
					"provider_id": provider_id,
					"host_contract": host_contract.duplicate(false),
					"npc_auto_accept": true,
					"ui_is_renderer_only": true
				},
				"ui_is_renderer_only": true
			}
		)

	return out

func _resolve_host(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var direct: Dictionary = _dict(
		context.get(
			"host_contract",
			{}
		)
	)

	if not direct.is_empty():
		return direct.duplicate(false)

	if (
		gs != null
		and gs.mini_game_host_adapter_engine != null
	):
		if gs.mini_game_host_adapter_engine.has_method(
			"project_host_contract"
		):
			return (
				gs.mini_game_host_adapter_engine
				.project_host_contract(
					actor,
					context
				)
			)

		return (
			gs.mini_game_host_adapter_engine
			.resolve_host_contract(
				actor,
				context
			)
		)

	return {
		"schema": "eralife.minigame_host_contract",
		"version": 1,
		"host_id": "minigame_host:global",
		"host_kind": "mod_surface",
		"title": "EraLife MiniGame Surface",
		"supported_provider_categories": [],
		"network_capabilities": {
			"spectators": true,
			"tournaments": true
		},
		"ui_is_renderer_only": true
	}

func _provider_supported_by_host(provider: Dictionary, host: Dictionary) -> bool:
	var host_kind: String = _id(str(host.get("host_kind", "mod_surface")))
	var supported_hosts: Array = _array(provider.get("supported_hosts", []))
	return (
		supported_hosts.is_empty()
		or host_kind in supported_hosts
		or "mod_surface" in supported_hosts
	)


func _commit_relationship_game_events(
	session: Dictionary, result_contract: Dictionary
) -> Dictionary:
	if gs == null or gs.relationship_graph_contract_engine == null:
		return { "success": true, "mode": "relationship_graph_unavailable"}
	var participants: Array = _array(session.get("participants", []))
	var reports: Array = []
	for index_a in range(participants.size()):
		for index_b in range(index_a + 1, participants.size()):
			var a: Dictionary = _dict(participants [index_a])
			var b: Dictionary = _dict(participants [index_b])
			var actor_a_id: int = int(a.get("actor_id", -1))
			var actor_b_id: int = int(b.get("actor_id", -1))
			if actor_a_id <= 0 or actor_b_id <= 0:
				continue
			var bond_delta: int = 3
			if (
				str(result_contract.get("winner_identity_key", ""))
				in [str(a.get("identity_key", "")), str(b.get("identity_key", ""))]
			):
				bond_delta = 4
			reports.append(
				gs.relationship_graph_contract_engine.commit_relationship_event(
					{
						"subject_entity_id": "human:%d" % actor_a_id,
						"object_entity_id": "human:%d" % actor_b_id,
						"event_type": "played_minigame_together",
						"relationship_type": "gaming_companion",
						"relationship_tags":
						["minigame", "played_together", str(session.get("provider_id", ""))],
						"bond_delta": bond_delta,
						"producer": ENGINE_SCHEMA
					},
					{ "session_id": str(session.get("session_id", ""))}
				)
			)
	return { "success": true, "reports": reports}


func _commit_diary_memory(
	actor: Person, session: Dictionary, result_contract: Dictionary
) -> Dictionary:
	if actor == null or gs == null or gs.life_diary_contract_engine == null:
		return { "success": true, "mode": "diary_unavailable"}
	var text: String = str(result_contract.get("text", "I finished a minigame session."))
	return gs.life_diary_contract_engine.emit_diary_intent(
		{
			"type": "minigame_memory",
			"actor_id": int(actor.id),
			"year": int(gs.year),
			"age": int(actor.age),
			"headline": str(session.get("game_title", "MiniGame")),
			"text": text,
			"lines": [text],
			"source": ENGINE_SCHEMA,
			"tags": ["minigame", str(session.get("provider_id", "")), "persistent_session"],
			"payload":
			{
				"session_id": str(session.get("session_id", "")),
				"provider_id": str(session.get("provider_id", "")),
				"result_contract": result_contract.duplicate(true)
			}
		},
		{ "source": "minigame_session_completion"}
	)


func _participant_for_actor(
	actor: Person, controller: String = "local_player", local_slot: int = 0
) -> Dictionary:
	if gs != null and gs.multiplayer_contract_engine != null:
		return gs.multiplayer_contract_engine.participant_for_actor(actor, controller, local_slot)
	if actor == null:
		return {}
	return {
		"identity_key": "person:%d" % int(actor.id),
		"identity_kind": "person",
		"actor_id": int(actor.id),
		"display_name": _person_name(actor),
		"controller": controller,
		"local_slot": local_slot,
		"is_ai": controller == "npc_ai",
	}


func _identity_is_spectator(session: Dictionary, identity_key: String) -> bool:
	for raw_row in _array(session.get("spectators", [])):
		if str(_dict(raw_row).get("identity_key", "")) == identity_key:
			return true
	return false


func _wrap_hub_result(
	actor: Person,
	context: Dictionary,
	result: Dictionary
) -> Dictionary:
	var out: Dictionary = result.duplicate(false)
	var effective_context: Dictionary = (
		context.duplicate(false)
	)

	out [
		"success"
	] = bool(
		out.get(
			"success",
			true
		)
	)

	out [
		"schema"
	] = ENGINE_SCHEMA

	out [
		"version"
	] = ENGINE_VERSION

	var observation_scope: String = _id(
		str(
			effective_context.get(
				"observation_scope",
				"hub"
			)
		)
	)



	if observation_scope == "hub":
		var inferred_section: String = _id(
			str(
				effective_context.get(
					"active_section",
					""
				)
			)
		)

		if inferred_section == "session":
			observation_scope = "session"
			effective_context [
				"observation_scope"
			] = "session"

			if str(
				effective_context.get(
					"session_id",
					""
				)
			).strip_edges() == "":
				effective_context [
					"session_id"
				] = str(
					out.get(
						"session_id",
						""
					)
				)

		elif inferred_section in [
			"multiplayer",
			"tournaments",
			"leaderboards",
			"achievements",
			"replays",
			"mods"
		]:
			observation_scope = "ecosystem_section"
			effective_context [
				"observation_scope"
			] = "ecosystem_section"

	match observation_scope:
		"games":
			out [
				"mini_game_contract"
			] = _emit_games_surface_packet(
				actor,
				effective_context
			)

		"provider_setup":
			out [
				"mini_game_contract"
			] = _emit_provider_setup_surface_packet(
				actor,
				effective_context
			)

		"session":
			out [
				"mini_game_contract"
			] = _emit_session_surface_packet(
				actor,
				effective_context
			)

		"ecosystem_section":
			out [
				"mini_game_contract"
			] = _emit_ecosystem_section_surface_packet(
				actor,
				effective_context
			)

		_:


			out [
				"mini_game_contract"
			] = emit_hub_contract(
				actor,
				effective_context
			)

	out [
		"type"
	] = "open_minigame_surface"

	out [
		"ui_is_renderer_only"
	] = true

	out [
		"observation_scope"
	] = observation_scope

	return out
func _mini_game_section_tabs() -> Array:
	return [
		{
			"id": "games",
			"label": "GAMES",
			"icon": "▦"
		},
		{
			"id": "session",
			"label": "LIVE SESSION",
			"icon": "▶"
		},
		{
			"id": "multiplayer",
			"label": "MULTIPLAYER",
			"icon": "◎"
		},
		{
			"id": "tournaments",
			"label": "TOURNAMENTS",
			"icon": "♛"
		},
		{
			"id": "leaderboards",
			"label": "LEADERBOARDS",
			"icon": "≡"
		},
		{
			"id": "achievements",
			"label": "ACHIEVEMENTS",
			"icon": "★"
		},
		{
			"id": "replays",
			"label": "REPLAYS",
			"icon": "↺"
		},
		{
			"id": "mods",
			"label": "MOD GAMES",
			"icon": "◆"
		}
	]


func _emit_provider_setup_surface_packet(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var setup_raw: Variant = context.get(
		"provider_setup_contract_override",
		{}
	)

	var setup_contract: Dictionary = (
		setup_raw as Dictionary
		if typeof(setup_raw) == TYPE_DICTIONARY
		else {}
	)

	return {
		"success": true,
		"schema": "eralife.minigame_surface_packet",
		"version": 1,
		"surface_scope": "provider_setup",
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": _person_name(actor),
		"title": "MINIGAME ECOSYSTEM",
		"subtitle": (
			"Configure the resident game contract."
		),
		"active_section": "games",
		"section_tabs": _mini_game_section_tabs(),
		"host_contract": _dict(
			context.get(
				"host_contract",
				{}
			)
		),
		"provider_rows": [],
		"provider_setup_contract": setup_contract,
		"session_contract": {},
		"status_text": str(
			context.get(
				"status_text",
				"Configure the match."
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}


func _emit_session_surface_packet(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var session_raw: Variant = context.get(
		"session_contract_override",
		{}
	)

	var session_contract: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	if session_contract.is_empty():
		var session_id: String = str(
			context.get(
				"session_id",
				""
			)
		)

		if session_id != "":
			session_contract = emit_session_contract(
				actor,
				session_id,
				context
			)

	return {
		"success": true,
		"schema": "eralife.minigame_surface_packet",
		"version": 1,
		"surface_scope": "session",
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": _person_name(actor),
		"title": "MINIGAME ECOSYSTEM",
		"subtitle": (
			"The live session is observed independently "
			+ "from the wider MiniGame ecosystem."
		),
		"active_section": "session",
		"section_tabs": _mini_game_section_tabs(),
		"host_contract": _dict(
			context.get(
				"host_contract",
				{}
			)
		),
		"provider_rows": [],
		"provider_setup_contract": {},
		"session_contract": session_contract,
		"status_text": str(
			context.get(
				"status_text",
				"The session is live."
			)
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}
func _session_projection_from_state(
	actor: Person,
	session: Dictionary,
	provider_object: Object,
	provider_state: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var identity: Dictionary = (
		_participant_for_actor(
			actor
		)
	)

	var identity_key: String = str(
		identity.get(
			"identity_key",
			""
		)
	)

	var actions: Array = []
	var projection: Dictionary = {}

	if provider_object != null:
		actions = provider_object.available_actions(
			provider_state,
			identity_key
		)
		projection = provider_object.ui_projection(
			provider_state
		)

	return {
		"success": true,
		"schema": "eralife.minigame_session_projection",
		"version": ENGINE_VERSION,
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
		"host_contract": _dict(
			session.get(
				"host_contract",
				{}
			)
		),
		"participants": _array(
			session.get(
				"participants",
				[]
			)
		),
		"spectators": _array(
			session.get(
				"spectators",
				[]
			)
		),
		"status": str(
			session.get(
				"status",
				"active"
			)
		),
		"provider_state": provider_state,
		"ui_projection": projection,
		"actions": actions,
		"can_act": not actions.is_empty(),
		"spectator": false,
		"result_contract": _dict(
			session.get(
				"result_contract",
				{}
			)
		),
		"context": context.duplicate(false),
		"truth_state": "hot",
		"authoritative_projection": true,
		"continuous_observation": bool(
			projection.get(
				"continuous_simulation",
				false
			)
		),
		"ui_is_renderer_only": true
	}


func _commit_continuous_provider_input(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.mini_game_runtime_engine == null
	):
		return _failure(
			"runtime_unavailable",
			"The continuous MiniGame runtime is unavailable."
		)

	var session_id: String = str(
		payload.get(
			"session_id",
			""
		)
	).strip_edges()

	if session_id == "":
		return _failure(
			"session_missing",
			"Continuous input requires a session identity."
		)

	var identity: Dictionary = (
		_participant_for_actor(
			actor
		)
	)

	var identity_key: String = str(
		identity.get(
			"identity_key",
			""
		)
	)

	if identity_key == "":
		return _failure(
			"identity_missing",
			"The controlled MiniGame participant identity is unavailable."
		)

	var runtime_report: Dictionary = (
		gs.mini_game_runtime_engine
		.submit_continuous_input(
			session_id,
			identity_key,
			str(
				payload.get(
					"input_action_id",
					""
				)
			),
			bool(
				payload.get(
					"pressed",
					false
				)
			),
			str(
				payload.get(
					"input_kind",
					"edge"
				)
			),
			int(
				payload.get(
					"input_sequence",
					0
				)
			)
		)
	)

	if not bool(
		runtime_report.get(
			"success",
			false
		)
	):
		return runtime_report

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "continuous_input_accepted",
		"session_id": session_id,
		"input_ack": true,
		"runtime_report": runtime_report,
		"ui_is_renderer_only": true
	}


func _last_event_text(events: Array, fallback: String) -> String:
	if events.is_empty():
		return fallback
	return str(_dict(events [events.size() - 1]).get("text", fallback))


func _ensure_bootstrap() -> void:
	_ensure_state()


func _ensure_state() -> void:
	if (
		state.is_empty()
		and gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		state = _dict(
			gs.scenario_state.get(
				STATE_KEY,
				{}
			)
		).duplicate(true)

	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"registered_providers": {},
			"provider_setup_by_actor_host": {},
			"updated_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	if typeof(
		state.get(
			"registered_providers",
			{}
		)
	) != TYPE_DICTIONARY:
		state [
			"registered_providers"
		] = {}

	if typeof(
		state.get(
			"provider_setup_by_actor_host",
			{}
		)
	) != TYPE_DICTIONARY:
		state [
			"provider_setup_by_actor_host"
		] = {}

func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	return gs.get_or_reactivate_npc_by_id(person_id)


func _person_name(person: Person) -> String:
	if person == null:
		return "Current Life"
	return "%s %s" % [str(person.first_name), str(person.last_name)]


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