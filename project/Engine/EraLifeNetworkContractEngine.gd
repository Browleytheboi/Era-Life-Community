extends Resource
class_name EraLifeNetworkContractEngine

const ENGINE_SCHEMA:= (
	"eralife.network_contract_engine"
)
const SURFACE_SCHEMA:= (
	"eralife.network.surface_contract"
)
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_dependencies()


func bind_game_state(_gs) -> void:
	gs = _gs
	_ensure_dependencies()


func emit_network_surface_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_dependencies()

	var identity_context: Dictionary = (
		_identity_context()
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)
	var transfer_context: Dictionary = (
		_transfer_context(context)
	)

	if is_guest:
		last_report = {
			"schema": SURFACE_SCHEMA,
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": (
				"offline_guest_network_optional"
			),
			"title": "ERA LIFE NETWORK",
			"account_required_for_social_features": (
				true
			),
			"identity_context": (
				identity_context.duplicate(true)
			),
			"profile": {},
			"connection_context": (
				_empty_connection_context()
			),
			"friends_live": [],
			"friends_live_count": 0,
			"reality_requests": [],
			"reality_request_count": 0,
			"public_feed": _empty_feed_contract(),
			"reality_stream": (
				_empty_stream_contract()
			),
			"visible_notes": (
				_empty_notes_contract()
			),
			"mailbox": _empty_mailbox_contract(),
			"incoming_transfers": [],
			"incoming_transfer_count": 0,
			"announcements": [],
			"announcement_count": 0,
			"community_realities": [],
			"community_reality_count": 0,
			"current_life": (
				_current_life_contract()
			),
			"life_account_transfer": (
				transfer_context.duplicate(true)
			),
			"menu_rows": (
				_menu_rows(
					0,
					0,
					0,
					0
				)
			),
			"primary_actions": (
				_primary_actions()
			),
			"message": (
				"EraLife Network is optional. Local lives remain fully playable and saveable."
			),
			"ui_is_renderer_only": true,
			"context": context.duplicate(true),
			"created_at_ms": _now_ms(),
			"contract_mesh": {
				"source_of_truth": (
					"EraLifeNetworkContractEngine"
				),
				"identity_authority": (
					"IdentityContractEngine"
				),
				"offline_simulation_authority": (
					"GameState"
				),
				"ui_mutation_allowed": false
			}
		}
		_commit_state()
		return last_report.duplicate(true)

	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var identity_id: String = (
		_identity_id(identity_context)
	)
	var mailbox_contract: Dictionary = (
		_mailbox_contract(context)
	)
	var connection_context: Dictionary = (
		_connection_context(
			username,
			context
		)
	)
	var profile_contract: Dictionary = (
		_profile_contract(
			username,
			context
		)
	)
	var notes_contract: Dictionary = (
		_notes_contract(context)
	)
	var feed_contract: Dictionary = (
		_feed_contract(context)
	)
	var stream_contract: Dictionary = (
		_stream_contract(context)
	)
	var self_host_network: Dictionary = (
		_self_host_network_contract(context)
	)
	var live_nodes: Array = _safe_array(
		self_host_network.get(
			"live_nodes",
			[]
		)
	)
	var friends_live: Array = _friends_live(
		connection_context,
		live_nodes
	)
	var mailbox_entries: Array = _safe_array(
		mailbox_contract.get(
			"entries",
			[]
		)
	)
	var reality_requests: Array = (
		_reality_request_rows(
			_safe_array(
				connection_context.get(
					"incoming_requests",
					[]
				)
			),
			mailbox_entries
		)
	)
	var incoming_transfers: Array = (
		_entries_of_types(
			mailbox_entries,
			[
				"life_packet",
				"item_packet",
				"reality_transfer",
				"live_reality_invite"
			]
		)
	)
	var announcements: Array = (
		_entries_of_types(
			mailbox_entries,
			[
				"announcement",
				"network_notification"
			]
		)
	)
	var community_realities: Array = (
		_community_realities(
			live_nodes,
			stream_contract,
			identity_id
		)
	)

	last_report = {
		"schema": SURFACE_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "network_surface_ready",
		"title": "ERA LIFE NETWORK",
		"account_required_for_social_features": (
			true
		),
		"identity_context": (
			identity_context.duplicate(true)
		),
		"username": username,
		"eraccount_id": identity_id,
		"profile": profile_contract.duplicate(true),
		"connection_context": (
			connection_context.duplicate(true)
		),
		"messenger_context": (
			_safe_dictionary(
				mailbox_contract.get(
					"messenger_context",
					{}
				)
			)
		),
		"mailbox": mailbox_contract.duplicate(true),
		"entries": mailbox_entries,
		"unread_count": int(
			mailbox_contract.get(
				"unread_count",
				0
			)
		),
		"friends_live": friends_live,
		"friends_live_count": friends_live.size(),
		"reality_requests": reality_requests,
		"reality_request_count": (
			reality_requests.size()
		),
		"public_feed": feed_contract.duplicate(true),
		"reality_stream": (
			stream_contract.duplicate(true)
		),
		"visible_notes": (
			notes_contract.duplicate(true)
		),
		"incoming_transfers": incoming_transfers,
		"incoming_transfer_count": (
			incoming_transfers.size()
		),
		"announcements": announcements,
		"announcement_count": (
			announcements.size()
		),
		"self_host_network": (
			self_host_network.duplicate(true)
		),
		"live_nodes": live_nodes,
		"live_node_count": live_nodes.size(),
		"community_realities": (
			community_realities
		),
		"community_reality_count": (
			community_realities.size()
		),
		"current_life": (
			_current_life_contract()
		),
		"life_account_transfer": (
			transfer_context.duplicate(true)
		),
		"menu_rows": _menu_rows(
			friends_live.size(),
			reality_requests.size(),
			incoming_transfers.size(),
			announcements.size()
		),
		"primary_actions": _primary_actions(),
		"ui_is_renderer_only": true,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms(),
		"contract_mesh": {
			"source_of_truth": (
				"EraLifeNetworkContractEngine"
			),
			"connection_authority": (
				"ConnectionGraphNetwork"
			),
			"delivery_authority": (
				"MailBoxContractEngine"
			),
			"chat_authority": (
				"MessengerContractEngine"
			),
			"profile_authority": (
				"ErAccountProfileContractEngine"
			),
			"notes_authority": (
				"NetworkNotesContractEngine"
			),
			"feed_authority": (
				"PublicFeedContractEngine"
			),
			"stream_authority": (
				"RealityStreamContractEngine"
			),
			"life_transfer_authority": (
				"LifeAccountTransferContractEngine"
			),
			"presence_authority": (
				"SelfHostNetworkContractEngine"
			),
			"ui_mutation_allowed": false
		}
	}
	_commit_state()
	return last_report.duplicate(true)


func route_command_envelope(
	envelope: Dictionary
) -> Dictionary:
	_ensure_dependencies()

	var command_id: String = str(
		envelope.get(
			"command",
			envelope.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()
	var report: Dictionary = {}

	if command_id in [
		"eralife_network.emit_surface",
		"eralife_network.emit",
		"reality_intake.emit_network_surface",
		"reality_intake.emit_contract",
		"mailbox.emit_reality_intake_contract"
	]:
		return emit_network_surface_contract(
			envelope
		)

	if (
		command_id
		== "eralife_network.continue_current_life"
	):
		return {
			"schema": (
				"eralife.network.navigation_action"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": (
				"continue_current_life_requested"
			),
			"action_id": "continue_current_life",
			"close_network_surface": true,
			"ui_is_renderer_only": true,
			"created_at_ms": _now_ms()
		}

	if (
		command_id
		== "eralife_network.browse_community_realities"
	):
		return {
			"schema": (
				"eralife.network.navigation_action"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": (
				"browse_community_realities_requested"
			),
			"action_id": (
				"browse_community_realities"
			),
			"surface_contract": (
				emit_network_surface_contract(
					envelope
				)
			),
			"ui_is_renderer_only": true,
			"created_at_ms": _now_ms()
		}

	if command_id.begins_with(
		"connection_graph."
	):
		report = _route_to_engine(
			"connection_graph_network",
			envelope
		)
	elif command_id.begins_with("profile."):
		report = _route_to_engine(
			"eraccount_profile_contract_engine",
			envelope
		)
	elif command_id.begins_with(
		"network_notes."
	):
		report = _route_to_engine(
			"network_notes_contract_engine",
			envelope
		)
	elif command_id.begins_with("public_feed."):
		report = _route_to_engine(
			"public_feed_contract_engine",
			envelope
		)
	elif command_id.begins_with(
		"reality_stream."
	):
		report = _route_to_engine(
			"reality_stream_contract_engine",
			envelope
		)
	elif command_id.begins_with(
		"life_account_transfer."
	):
		report = _route_to_engine(
			"life_account_transfer_contract_engine",
			envelope
		)
	elif command_id.begins_with("compression."):
		report = _route_to_engine(
			"compression",
			envelope
		)
	elif command_id.begins_with(
		"self_host_network."
	):
		report = _route_to_engine(
			"self_host_network_contract_engine",
			envelope
		)
	elif command_id.begins_with("messenger."):
		var messenger_envelope: Dictionary = (
			envelope.duplicate(true)
		)

		if str(
			messenger_envelope.get(
				"sender_username",
				""
			)
		).strip_edges() == "":
			messenger_envelope [
				"sender_username"
			] = str(
				_identity_context().get(
					"account_username",
					""
				)
			)

		report = _route_to_engine(
			"messenger_contract_engine",
			messenger_envelope
		)
	elif command_id.begins_with("mailbox."):
		report = _route_to_engine(
			"mailbox_contract_engine",
			envelope
		)
	elif command_id.begins_with("search."):
		report = _route_to_engine(
			"search_contract_engine",
			envelope
		)
	else:
		return _fail(
			"unknown_network_command",
			"EraLifeNetworkContractEngine did not recognize command.",
			envelope
		)

	if (
		bool(
			report.get(
				"success",
				false
			)
		)
		and not _command_is_read_only(
			command_id
		)
		and not report.has(
			"surface_contract"
		)
	):
		report ["surface_contract"] = (
			emit_network_surface_contract({
				"source": (
					"network_mutation_refresh"
				),
				"command": command_id
			})
		)

	last_report = report.duplicate(true)
	_commit_state()
	return report


func _route_to_engine(
	engine_property: String,
	envelope: Dictionary
) -> Dictionary:
	if (
		gs == null
		or not (engine_property in gs)
	):
		return _fail(
			"network_engine_missing",
			(
				"Network authority '%s' is not registered."
				% engine_property
			),
			envelope
		)

	var engine = gs.get(
		engine_property
	)

	if (
		engine == null
		or not engine.has_method(
			"route_command_envelope"
		)
	):
		return _fail(
			"network_engine_unavailable",
			(
				"Network authority '%s' cannot route commands."
				% engine_property
			),
			envelope
		)

	var raw_report: Variant = (
		engine.route_command_envelope(
			envelope.duplicate(true)
		)
	)

	if typeof(raw_report) == TYPE_DICTIONARY:
		return (
			raw_report as Dictionary
		).duplicate(true)

	return _fail(
		"network_engine_invalid_report",
		(
			"Network authority '%s' returned an invalid report."
			% engine_property
		),
		envelope
	)


func _mailbox_contract(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "mailbox_contract_engine" in gs
		and gs.mailbox_contract_engine != null
		and gs.mailbox_contract_engine.has_method(
			"emit_mailbox_contract"
		)
	):
		return (
			gs.mailbox_contract_engine
			.emit_mailbox_contract({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return _empty_mailbox_contract()


func _connection_context(
	username: String,
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "connection_graph_network" in gs
		and gs.connection_graph_network != null
	):
		return (
			gs.connection_graph_network
			.emit_connection_context(
				username,
				{
					"source": (
						"eralife_network_surface"
					),
					"context": context.duplicate(true)
				}
			)
		)

	return _empty_connection_context()


func _profile_contract(
	username: String,
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		return (
			gs.eraccount_profile_contract_engine
			.emit_profile(
				username,
				{
					"source": (
						"eralife_network_surface"
					),
					"context": context.duplicate(true)
				}
			)
		)

	return {}


func _notes_contract(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "network_notes_contract_engine" in gs
		and gs.network_notes_contract_engine != null
	):
		return (
			gs.network_notes_contract_engine
			.emit_visible_notes({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return _empty_notes_contract()


func _feed_contract(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "public_feed_contract_engine" in gs
		and gs.public_feed_contract_engine != null
	):
		return (
			gs.public_feed_contract_engine
			.emit_feed({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return _empty_feed_contract()


func _stream_contract(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "reality_stream_contract_engine" in gs
		and gs.reality_stream_contract_engine != null
	):
		return (
			gs.reality_stream_contract_engine
			.emit_stream({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return _empty_stream_contract()


func _self_host_network_contract(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "self_host_network_contract_engine" in gs
		and gs.self_host_network_contract_engine != null
	):
		return (
			gs.self_host_network_contract_engine
			.emit_network_presence_contract({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return {
		"success": true,
		"live_nodes": [],
		"live_node_count": 0,
		"self_presence": {}
	}


func _transfer_context(
	context: Dictionary
) -> Dictionary:
	if (
		gs != null
		and "life_account_transfer_contract_engine" in gs
		and gs.life_account_transfer_contract_engine != null
	):
		return (
			gs.life_account_transfer_contract_engine
			.emit_transfer_context({
				"source": (
					"eralife_network_surface"
				),
				"context": context.duplicate(true)
			})
		)

	return {
		"success": true,
		"local_lives": [],
		"unclaimed_lives": [],
		"current_account_lives": [],
		"transfer_available": false,
	}


func _friends_live(
	connection_context: Dictionary,
	live_nodes: Array
) -> Array:
	var connections: Array = _safe_array(
		connection_context.get(
			"connections",
			[]
		)
	)
	var connected_ids: Dictionary = {}
	var connected_usernames: Dictionary = {}

	for raw_connection in connections:
		if typeof(raw_connection) != TYPE_DICTIONARY:
			continue

		var connection: Dictionary = (
			raw_connection as Dictionary
		)
		var identity_id: String = str(
			connection.get(
				"identity_id",
				""
			)
		).strip_edges()
		var username_key: String = str(
			connection.get(
				"username",
				""
			)
		).strip_edges().to_lower()

		if identity_id != "":
			connected_ids [identity_id] = true

		if username_key != "":
			connected_usernames [username_key] = true

	var out: Array = []
	var seen_runtime_ids: Dictionary = {}

	for raw_node in live_nodes:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = (
			raw_node as Dictionary
		).duplicate(true)

		if not bool(
			node.get(
				"active",
				false
			)
		):
			continue

		var identity_id: String = str(
			node.get(
				"identity_id",
				""
			)
		).strip_edges()
		var username_key: String = str(
			node.get(
				"username",
				""
			)
		).strip_edges().to_lower()

		if (
			not connected_ids.has(identity_id)
			and not connected_usernames.has(
				username_key
			)
		):
			continue

		var runtime_id: String = str(
			node.get(
				"runtime_id",
				""
			)
		).strip_edges()

		if (
			runtime_id != ""
			and seen_runtime_ids.has(runtime_id)
		):
			continue

		if runtime_id != "":
			seen_runtime_ids [runtime_id] = true

		out.append(node)

	out.sort_custom(
		func (
			a: Dictionary,
			b: Dictionary
		) -> bool:
			return int(
				a.get(
					"updated_at_ms",
					0
				)
			) > int(
				b.get(
					"updated_at_ms",
					0
				)
			)
	)

	return out


func _community_realities(
	live_nodes: Array,
	stream_contract: Dictionary,
	viewer_identity_id: String
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_node in live_nodes:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = (
			raw_node as Dictionary
		).duplicate(true)

		if not bool(
			node.get(
				"active",
				false
			)
		):
			continue

		var runtime_id: String = str(
			node.get(
				"runtime_id",
				""
			)
		)
		var key: String = (
			"runtime:%s"
			% runtime_id
		)

		if seen.has(key):
			continue

		seen [key] = true

		var life_state: Dictionary = (
			_safe_dictionary(
				node.get(
					"life_state",
					{}
				)
			)
		)

		out.append({
			"schema": (
				"eralife.network.community_reality"
			),
			"version": CONTRACT_VERSION,
			"source_kind": "live_node",
			"reality_id": runtime_id,
			"username": str(
				node.get(
					"username",
					"Unknown"
				)
			),
			"identity_id": str(
				node.get(
					"identity_id",
					""
				)
			),
			"title": str(
				life_state.get(
					"player_name",
					"Live Reality"
				)
			),
			"era_name": str(
				life_state.get(
					"era_name",
					"Unknown Era"
				)
			),
			"active": true,
			"entry_modes": _safe_array(
				node.get(
					"entry_modes",
					[]
				)
			),
			"node": node.duplicate(true)
		})

	var stream_entries: Array = _safe_array(
		stream_contract.get(
			"entries",
			[]
		)
	)

	for raw_entry in stream_entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		)

		if str(
			entry.get(
				"entry_type",
				""
			)
		) != "reality_published":
			continue

		var payload: Dictionary = (
			_safe_dictionary(
				entry.get(
					"payload",
					{}
				)
			)
		)
		var reality_contract: Dictionary = (
			_safe_dictionary(
				payload.get(
					"reality",
					payload
				)
			)
		)
		var reality_id: String = str(
			reality_contract.get(
				"reality_id",
				reality_contract.get(
					"runtime_id",
					entry.get(
						"entry_id",
						""
					)
				)
			)
		)
		var key: String = (
			"published:%s"
			% reality_id
		)

		if seen.has(key):
			continue

		seen [key] = true

		out.append({
			"schema": (
				"eralife.network.community_reality"
			),
			"version": CONTRACT_VERSION,
			"source_kind": (
				"published_reality"
			),
			"reality_id": reality_id,
			"username": str(
				entry.get(
					"author_username",
					"Unknown"
				)
			),
			"identity_id": str(
				entry.get(
					"author_identity_id",
					""
				)
			),
			"title": str(
				reality_contract.get(
					"title",
					"Published Reality"
				)
			),
			"era_name": str(
				reality_contract.get(
					"era_name",
					"Unknown Era"
				)
			),
			"active": false,
			"viewer_is_owner": (
				str(
					entry.get(
						"author_identity_id",
						""
					)
				) == viewer_identity_id
			),
			"stream_entry": (
				entry.duplicate(true)
			)
		})

	return out


func _reality_request_rows(
	incoming_requests: Array,
	mailbox_entries: Array
) -> Array:
	var entry_id_by_request_id: Dictionary = {}

	for raw_entry in mailbox_entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		)

		if str(
			entry.get(
				"type",
				""
			)
		).to_lower() != "friend_request":
			continue

		var payload: Dictionary = (
			_safe_dictionary(
				entry.get(
					"payload",
					{}
				)
			)
		)
		var request_id: String = str(
			payload.get(
				"connection_request_id",
				_safe_dictionary(
					payload.get(
						"connection_request",
						{}
					)
				).get(
					"request_id",
					""
				)
			)
		).strip_edges()

		if request_id != "":
			entry_id_by_request_id [
				request_id
			] = str(
				entry.get(
					"entry_id",
					""
				)
			)

	var rows: Array = []

	for raw_request in incoming_requests:
		if typeof(raw_request) != TYPE_DICTIONARY:
			continue

		var request: Dictionary = (
			raw_request as Dictionary
		).duplicate(true)
		var request_id: String = str(
			request.get(
				"request_id",
				""
			)
		)

		request ["mailbox_entry_id"] = str(
			entry_id_by_request_id.get(
				request_id,
				""
			)
		)
		rows.append(request)

	return rows


func _entries_of_types(
	entries: Array,
	accepted_types: Array
) -> Array:
	var out: Array = []

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		)

		if str(
			entry.get(
				"type",
				""
			)
		).to_lower() in accepted_types:
			out.append(
				entry.duplicate(true)
			)

	return out


func _current_life_contract() -> Dictionary:
	var has_current_life: bool = (
		gs != null
		and gs.player != null
	)
	var player_name: String = "None yet"
	var age: int = 0
	var year: int = 0
	var era_name: String = "None yet"
	var life_id: String = ""

	if has_current_life:
		player_name = (
			"%s %s"
			% [
				str(gs.player.first_name),
				str(gs.player.last_name)
			]
		).strip_edges()
		age = int(gs.player.age)
		year = int(gs.year)

		if gs.era != null:
			era_name = str(gs.era.name)

		if typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY:
			life_id = str(
				gs.scenario_state.get(
					"life_id",
					""
				)
			)

	return {
		"schema": (
			"eralife.network.current_life_contract"
		),
		"version": CONTRACT_VERSION,
		"has_current_life": has_current_life,
		"life_id": life_id,
		"player_name": player_name,
		"age": age,
		"year": year,
		"era_name": era_name,
		"action_id": (
			"continue_current_life"
		)
	}


func _menu_rows(
	friends_live_count: int,
	reality_request_count: int,
	incoming_transfer_count: int,
	announcement_count: int
) -> Array:
	return [
		{
			"section_id": "friends_live",
			"label": "🟢 Friends Live",
			"count": friends_live_count
		},
		{
			"section_id": "requests",
			"label": "📨 Reality Requests",
			"count": reality_request_count
		},
		{
			"section_id": "public_feed",
			"label": "💬 Public Feed",
			"count": 0
		},
		{
			"section_id": "reality_stream",
			"label": "🌍 Reality Stream",
			"count": 0
		},
		{
			"section_id": "search",
			"label": "🔎 Search ErAccounts",
			"count": 0
		},
		{
			"section_id": "transfers",
			"label": "📦 Incoming Transfers",
			"count": incoming_transfer_count
		},
		{
			"section_id": "announcements",
			"label": "📢 Announcements",
			"count": announcement_count
		},
		{
			"section_id": "profile",
			"label": "👤 Profile",
			"count": 0
		}
	]


func _primary_actions() -> Array:
	return [
		{
			"action_id": (
				"continue_current_life"
			),
			"label": "▶ Continue Current Life"
		},
		{
			"action_id": (
				"browse_community_realities"
			),
			"label": (
				"▶ Browse Community Realities"
			)
		}
	]


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
	):
		return (
			gs.identity_contract_engine
			.emit_identity_context({
				"source": (
					"eralife_network_contract_engine"
				)
			})
		)

	return {
		"is_guest": true
	}


func _identity_id(
	identity_context: Dictionary
) -> String:
	return str(
		identity_context.get(
			"cloud_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()


func _command_is_read_only(
	command_id: String
) -> bool:
	return command_id in [
		"connection_graph.emit_context",
		"profile.emit",
		"profile.emit_public_profile",
		"network_notes.emit",
		"public_feed.emit",
		"reality_stream.emit",
		"life_account_transfer.emit",
		"self_host_network.emit_presence",
		"mailbox.emit_reality_intake_contract",
		"mailbox.emit_mailbox_contract",
		"search.query",
		"search.identity_live",
		"search.search_accounts",
		"search.identity_discovery"
	]


func _ensure_dependencies() -> void:
	if gs == null:
		return

	if gs.identity_contract_engine == null:
		gs.identity_contract_engine = (
			IdentityContractEngine.new(gs)
		)

	if gs.compression == null:
		gs.compression = Compression.new(gs)

	if gs.connection_graph_network == null:
		gs.connection_graph_network = (
			ConnectionGraphNetwork.new(gs)
		)

	if gs.messenger_contract_engine == null:
		gs.messenger_contract_engine = (
			MessengerContractEngine.new(gs)
		)

	if gs.mailbox_contract_engine == null:
		gs.mailbox_contract_engine = (
			MailBoxContractEngine.new(gs)
		)

	if gs.eraccount_profile_contract_engine == null:
		gs.eraccount_profile_contract_engine = (
			ErAccountProfileContractEngine.new(gs)
		)

	if gs.network_notes_contract_engine == null:
		gs.network_notes_contract_engine = (
			NetworkNotesContractEngine.new(gs)
		)

	if gs.public_feed_contract_engine == null:
		gs.public_feed_contract_engine = (
			PublicFeedContractEngine.new(gs)
		)

	if gs.reality_stream_contract_engine == null:
		gs.reality_stream_contract_engine = (
			RealityStreamContractEngine.new(gs)
		)

	if gs.life_account_transfer_contract_engine == null:
		gs.life_account_transfer_contract_engine = (
			LifeAccountTransferContractEngine.new(gs)
		)

	if gs.self_host_network_contract_engine == null:
		gs.self_host_network_contract_engine = (
			SelfHostNetworkContractEngine.new(gs)
		)

	if gs.search_contract_engine == null:
		gs.search_contract_engine = (
			SearchContractEngine.new(gs)
		)

	if (
		gs.reality_stream_contract_engine
		.has_method(
			"bind_event_bus"
		)
	):
		gs.reality_stream_contract_engine.bind_event_bus()


func _empty_connection_context() -> Dictionary:
	return {
		"success": true,
		"connections": [],
		"friends": [],
		"connection_count": 0,
		"incoming_requests": [],
		"outgoing_requests": [],
		"incoming_request_count": 0,
		"outgoing_request_count": 0
	}


func _empty_feed_contract() -> Dictionary:
	return {
		"success": true,
		"posts": [],
		"post_count": 0,
		"character_limit": 500
	}


func _empty_stream_contract() -> Dictionary:
	return {
		"success": true,
		"entries": [],
		"entry_count": 0
	}


func _empty_notes_contract() -> Dictionary:
	return {
		"success": true,
		"notes": [],
		"note_count": 0,
		"character_limit": 120
	}


func _empty_mailbox_contract() -> Dictionary:
	return {
		"success": true,
		"entries": [],
		"unread_count": 0,
		"messenger_context": {}
	}


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"last_eralife_network_contract"
	] = last_report.duplicate(true)


func _now_ms() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason_id: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.network.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	_commit_state()
	return last_report.duplicate(true)