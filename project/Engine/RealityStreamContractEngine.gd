extends Resource
class_name RealityStreamContractEngine

const ENGINE_SCHEMA:= "eralife.reality_stream"
const CONTRACT_VERSION:= 1
const STREAM_REGISTRY_PATH:= (
	"user://identity/reality_stream_registry.json"
)
const STREAM_LIMIT:= 5000

var gs
var stream_registry: Dictionary = {}
var last_report: Dictionary = {}
var event_bus_bound: bool = false


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()
	bind_event_bus()


func bind_event_bus() -> void:
	if event_bus_bound:
		return

	if (
		gs == null
		or not ("event_bus" in gs)
		or gs.event_bus == null
	):
		return

	gs.event_bus.subscribe(
		ActionEventTypes.PROPERTY_PURCHASED,
		self,
		"on_property_purchased"
	)
	gs.event_bus.subscribe(
		ActionEventTypes.VEHICLE_PURCHASED,
		self,
		"on_vehicle_purchased"
	)
	gs.event_bus.subscribe(
		ActionEventTypes.CHILD_BORN_PLAYER_LINE,
		self,
		"on_player_line_birth"
	)
	gs.event_bus.subscribe(
		ActionEventTypes.PLAYER_DIED,
		self,
		"on_controlled_life_died"
	)
	gs.event_bus.subscribe(
		ActionEventTypes.DYNASTY_SHIFT,
		self,
		"on_dynasty_shift"
	)

	event_bus_bound = true


func record_life_started(
	presence: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return {
			"success": false,
			"mode": "guest_stream_suppressed"
		}

	var life_state: Dictionary = _safe_dictionary(
		presence.get(
			"life_state",
			{}
		)
	)
	var era_name: String = str(
		life_state.get(
			"era_name",
			"an unknown era"
		)
	).strip_edges()
	var username: String = str(
		identity_context.get(
			"account_username",
			"Unknown"
		)
	)
	var profile: Dictionary = _current_profile()
	var display_name: String = str(
		profile.get(
			"display_name",
			username
		)
	)

	var entry_report: Dictionary = record_stream_entry(
		"life_started",
		"🟢 %s just started a life in %s!" % [
			display_name,
			(
				era_name
				if era_name != ""
				else "an unknown era"
			)
		],
		{
			"presence": presence.duplicate(true),
			"life_id": str(
				presence.get(
					"life_id",
					""
				)
			),
			"era_name": era_name
		},
		_profile_visibility(
			"life_visibility",
			"connections"
		),
		context
	)

	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		gs.eraccount_profile_contract_engine.record_life_started(
			str(presence.get("life_id", "")),
			era_name,
			_current_reality_mode(),
			{
				"title": "%s's %s life" % [
					display_name,
					era_name
				],
				"life_id": str(
					presence.get(
						"life_id",
						""
					)
				),
				"era_name": era_name,
				"runtime_id": str(
					presence.get(
						"runtime_id",
						""
					)
				)
			},
			context
		)

	return entry_report


func record_reality_published(
	presence: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var profile: Dictionary = _current_profile()
	var display_name: String = str(
		profile.get(
			"display_name",
			_current_username()
		)
	)

	var reality_contract: Dictionary = {
		"title": "%s's Public Reality" % display_name,
		"life_id": str(presence.get("life_id", "")),
		"runtime_id": str(
			presence.get(
				"runtime_id",
				""
			)
		),
		"era_name": str(
			_safe_dictionary(
				presence.get(
					"life_state",
					{}
				)
			).get(
				"era_name",
				""
			)
		)
	}

	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		gs.eraccount_profile_contract_engine.record_reality_published(
			reality_contract,
			context
		)

	return record_stream_entry(
		"reality_published",
		"🌎 %s published their reality." % display_name,
		{
			"reality": reality_contract,
			"presence": presence.duplicate(true)
		},
		_profile_visibility(
			"life_visibility",
			"connections"
		),
		context
	)


func on_property_purchased(
	event: Dictionary
) -> void:
	if not _event_matches_controlled_actor(event):
		return

	var text: String = str(
		event.get(
			"text",
			""
		)
	).strip_edges()

	if text == "":
		text = "%s purchased a property." % (
			_current_display_name()
		)

	record_stream_entry(
		"property_purchased",
		"🏠 %s" % text,
		event,
		_profile_visibility(
			"milestone_visibility",
			"connections"
		),
		{
			"source": "property_purchased_event"
		}
	)


func on_vehicle_purchased(
	event: Dictionary
) -> void:
	if not _event_matches_controlled_actor(event):
		return

	var text: String = str(
		event.get(
			"text",
			""
		)
	).strip_edges()

	if text == "":
		text = "%s purchased a vehicle." % (
			_current_display_name()
		)

	record_stream_entry(
		"vehicle_purchased",
		"🚗 %s" % text,
		event,
		_profile_visibility(
			"milestone_visibility",
			"connections"
		),
		{
			"source": "vehicle_purchased_event"
		}
	)


func on_player_line_birth(
	event: Dictionary
) -> void:
	record_stream_entry(
		"player_line_birth",
		"👶 %s just welcomed a new child." % (
			_current_display_name()
		),
		event,
		_profile_visibility(
			"milestone_visibility",
			"connections"
		),
		{
			"source": "player_line_birth_event"
		}
	)


func on_dynasty_shift(
	event: Dictionary
) -> void:
	if not _event_matches_controlled_actor(event):
		return

	var text: String = str(
		event.get(
			"text",
			"%s entered a new dynasty chapter."
			% _current_display_name()
		)
	)

	record_stream_entry(
		"dynasty_shift",
		"👑 %s" % text,
		event,
		_profile_visibility(
			"milestone_visibility",
			"connections"
		),
		{
			"source": "dynasty_shift_event"
		}
	)


func on_controlled_life_died(
	event: Dictionary
) -> void:
	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		gs.eraccount_profile_contract_engine.record_controlled_life_death(
			{
				"source": "player_died_event",
				"event": event.duplicate(true)
			}
		)

	record_stream_entry(
		"controlled_life_completed",
		"🕯️ %s completed a life." % (
			_current_display_name()
		),
		event,
		_profile_visibility(
			"milestone_visibility",
			"connections"
		),
		{
			"source": "player_died_event"
		}
	)


func record_stream_entry(
	entry_type: String,
	text: String,
	payload: Dictionary = {},
	visibility: String = "connections",
	context: Dictionary = {}
) -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return {
			"success": false,
			"mode": "guest_stream_suppressed"
		}

	var identity_id: String = _identity_id(
		identity_context
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var now_ms: int = _now_ms()
	var entry_id: String = "stream_%d" % abs(
		hash(
			"%s|%s|%d|%s" % [
				identity_id,
				entry_type,
				now_ms,
				text
			]
		)
	)
	var clean_visibility: String = str(
		visibility
	).to_lower()

	if (
		clean_visibility
		not in ["public", "connections", "private"]
	):
		clean_visibility = "connections"

	var entry: Dictionary = {
		"schema": "eralife.reality_stream.entry",
		"version": CONTRACT_VERSION,
		"entry_id": entry_id,
		"entry_type": entry_type,
		"author_identity_id": identity_id,
		"author_username": username,
		"text": text,
		"payload": payload.duplicate(true),
		"visibility": clean_visibility,
		"created_at_ms": now_ms
	}

	var entries: Array = _safe_array(
		stream_registry.get(
			"entries",
			[]
		)
	)
	entries.push_front(entry)

	if entries.size() > STREAM_LIMIT:
		entries.resize(STREAM_LIMIT)

	stream_registry ["entries"] = entries
	_write_registry()

	_deliver_entry_notifications(
		entry,
		context
	)

	return {
		"schema": "eralife.reality_stream.record_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "reality_stream_entry_recorded",
		"entry": entry.duplicate(true),
		"created_at_ms": now_ms
	}


func emit_stream(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	var viewer_identity_id: String = _identity_id(
		identity_context
	)
	var connected_ids: Array = []

	if (
		viewer_identity_id != ""
		and gs != null
		and "connection_graph_network" in gs
		and gs.connection_graph_network != null
	):
		connected_ids = (
			gs.connection_graph_network
				.connected_identity_ids(
					viewer_identity_id
				)
		)

	var visible_entries: Array = []

	for raw_entry in _safe_array(
		stream_registry.get(
			"entries",
			[]
		)
	):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		).duplicate(true)
		var author_id: String = str(
			entry.get(
				"author_identity_id",
				""
			)
		)
		var visibility: String = str(
			entry.get(
				"visibility",
				"connections"
			)
		)

		if visibility == "private":
			if author_id != viewer_identity_id:
				continue
		elif visibility == "connections":
			if (
				author_id != viewer_identity_id
				and not connected_ids.has(
					author_id
				)
			):
				continue

		var profile: Dictionary = _profile_by_identity(
			author_id
		)
		entry ["author_display_name"] = str(
			profile.get(
				"display_name",
				entry.get(
					"author_username",
					"Unknown"
				)
			)
		)
		entry ["profile_photo"] = _safe_dictionary(
			profile.get(
				"profile_photo",
				{}
			)
		)
		visible_entries.append(entry)

	return {
		"schema": "eralife.reality_stream.contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "reality_stream_ready",
		"entries": visible_entries,
		"entry_count": visible_entries.size(),
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}


func route_command_envelope(
	envelope: Dictionary
) -> Dictionary:
	var command_id: String = str(
		envelope.get(
			"command",
			envelope.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()

	if command_id == "reality_stream.emit":
		return emit_stream(envelope)

	if command_id == "reality_stream.record_milestone":
		return record_stream_entry(
			str(
				envelope.get(
					"entry_type",
					"custom_milestone"
				)
			),
			str(envelope.get("text", "")),
			_safe_dictionary(
				envelope.get(
					"payload",
					{}
				)
			),
			str(
				envelope.get(
					"visibility",
					_profile_visibility(
						"milestone_visibility",
						"connections"
					)
				)
			),
			envelope
		)

	return {
		"success": false,
		"reason": (
			"RealityStreamContractEngine did not recognize command."
		)
	}


func _deliver_entry_notifications(
	entry: Dictionary,
	context: Dictionary
) -> void:
	if (
		gs == null
		or not ("connection_graph_network" in gs)
		or gs.connection_graph_network == null
		or not ("mailbox_contract_engine" in gs)
	):
		return

	var author_id: String = str(
		entry.get(
			"author_identity_id",
			""
		)
	)
	var connected_ids: Array = (
		gs.connection_graph_network
			.connected_identity_ids(
				author_id
			)
	)

	if gs.mailbox_contract_engine == null:
		gs.mailbox_contract_engine = (
			MailBoxContractEngine.new(gs)
		)

	for raw_identity_id in connected_ids:
		var recipient_identity_id: String = str(
			raw_identity_id
		)

		if (
			gs.eraccount_profile_contract_engine != null
			and not gs.eraccount_profile_contract_engine
				.notifications_enabled_for_identity(
					recipient_identity_id
				)
		):
			continue

		var recipient_profile: Dictionary = (
			_profile_by_identity(
				recipient_identity_id
			)
		)
		var recipient_username: String = str(
			recipient_profile.get(
				"username",
				""
			)
		)

		if recipient_username == "":
			continue

		gs.mailbox_contract_engine.deliver_network_notification(
			recipient_username,
			str(
				entry.get(
					"entry_type",
					"network_event"
				)
			),
			"EraLife Network",
			str(entry.get("text", "")),
			{
				"stream_entry": entry.duplicate(true),
				"context": context.duplicate(true)
			}
		)


func _event_matches_controlled_actor(
	event: Dictionary
) -> bool:
	if gs == null or gs.player == null:
		return false

	var event_actor_id: int = int(
		event.get(
			"npc_id",
			event.get(
				"actor_id",
				-1
			)
		)
	)

	if event_actor_id <= 0:
		return true

	return event_actor_id == int(gs.player.id)


func _current_profile() -> Dictionary:
	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		return (
			gs.eraccount_profile_contract_engine
				.emit_profile(
					"",
					{
						"source": "reality_stream"
					}
				)
		)

	return {}


func _profile_by_identity(
	identity_id: String
) -> Dictionary:
	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		return (
			gs.eraccount_profile_contract_engine
				.emit_profile_by_identity(
					identity_id,
					{
						"source": "reality_stream"
					}
				)
		)

	return {}


func _profile_visibility(
	key: String,
	fallback: String
) -> String:
	var profile: Dictionary = _current_profile()
	var permissions: Dictionary = _safe_dictionary(
		profile.get(
			"permissions",
			{}
		)
	)

	return str(
		permissions.get(
			key,
			fallback
		)
	)


func _current_display_name() -> String:
	var profile: Dictionary = _current_profile()

	return str(
		profile.get(
			"display_name",
			_current_username()
		)
	)


func _current_username() -> String:
	return str(
		_identity_context().get(
			"account_username",
			"Unknown"
		)
	)


func _current_reality_mode() -> String:
	if gs == null:
		return "Unknown"

	return str(
		gs.reality_mode
		if "reality_mode" in gs
		else "Unknown"
	).capitalize()


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
	):
		return gs.identity_contract_engine.emit_identity_context({
			"source": "reality_stream"
		})

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
	)


func _ensure_state() -> void:
	stream_registry = _read_registry()

	if (
		typeof(
			stream_registry.get(
				"entries",
				[]
			)
		)
		!= TYPE_ARRAY
	):
		stream_registry ["entries"] = []


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		STREAM_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"entries": []
		}

	var file:= FileAccess.open(
		STREAM_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"entries": []
		}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)

	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"entries": []
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		STREAM_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			stream_registry,
			"\t"
		)
	)
	file.close()


func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")

	if (
		root != null
		and not root.dir_exists("identity")
	):
		root.make_dir("identity")


func _now_ms() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)

	return []