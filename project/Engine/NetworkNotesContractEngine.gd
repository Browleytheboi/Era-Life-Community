extends Resource
class_name NetworkNotesContractEngine

const ENGINE_SCHEMA:= "eralife.network_notes"
const CONTRACT_VERSION:= 1
const NOTE_REGISTRY_PATH:= (
	"user://identity/network_notes_registry.json"
)

const NOTE_CHARACTER_LIMIT:= 120
const NOTE_LIFETIME_MS:= 86400000

var gs
var note_registry: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func set_note(
	text: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to post a note.",
			context
		)

	var identity_id: String = _identity_id(
		identity_context
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var clean_text: String = str(
		text
	).strip_edges()

	if clean_text.length() > NOTE_CHARACTER_LIMIT:
		return _fail(
			"note_too_long",
			"Notes are limited to %d characters."
			% NOTE_CHARACTER_LIMIT,
			context
		)

	var notes: Dictionary = _safe_dictionary(
		note_registry.get(
			"notes",
			{}
		)
	)

	if clean_text == "":
		notes.erase(identity_id)
		note_registry ["notes"] = notes
		_write_registry()

		return {
			"schema": "eralife.network_notes.report",
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "note_cleared",
			"message": "Your note was cleared.",
			"created_at_ms": _now_ms()
		}

	var mentions: Array = _mentions_from_text(
		clean_text
	)
	var connected_usernames: Array = (
		_connected_usernames(
			username
		)
	)

	for raw_mention in mentions:
		var mention: String = str(
			raw_mention
		)

		if not _contains_case_insensitive(
			connected_usernames,
			mention
		):
			return _fail(
				"mention_not_connected",
				"You can only tag ErAccounts you are connected with.",
				{
					"mention": mention,
					"context": context.duplicate(true)
				}
			)

	var now_ms: int = _now_ms()
	var note_id: String = "note_%d" % abs(
		hash(
			"%s|%d|%s" % [
				identity_id,
				now_ms,
				clean_text
			]
		)
	)
	var note: Dictionary = {
		"schema": "eralife.network_notes.note",
		"version": CONTRACT_VERSION,
		"note_id": note_id,
		"author_identity_id": identity_id,
		"author_username": username,
		"text": clean_text,
		"mentions": mentions,
		"visibility": "connections",
		"created_at_ms": now_ms,
		"expires_at_ms": now_ms + NOTE_LIFETIME_MS
	}

	notes [identity_id] = note
	note_registry ["notes"] = notes
	_write_registry()

	last_report = {
		"schema": "eralife.network_notes.report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "note_published",
		"message": "Your note is live for your connections.",
		"note": note.duplicate(true),
		"created_at_ms": now_ms
	}
	return last_report.duplicate(true)


func emit_visible_notes(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return {
			"schema": "eralife.network_notes.context",
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "guest_notes_unavailable",
			"notes": [],
			"created_at_ms": _now_ms()
		}

	var viewer_identity_id: String = _identity_id(
		identity_context
	)
	var viewer_username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var connected_ids: Array = (
		_connected_identity_ids(
			viewer_identity_id
		)
	)
	var notes: Dictionary = _safe_dictionary(
		note_registry.get(
			"notes",
			{}
		)
	)
	var visible_notes: Array = []
	var expired_ids: Array = []
	var now_ms: int = _now_ms()

	for raw_author_id in notes.keys():
		var author_id: String = str(
			raw_author_id
		)
		var note: Dictionary = _safe_dictionary(
			notes.get(
				raw_author_id,
				{}
			)
		)

		if int(
			note.get(
				"expires_at_ms",
				0
			)
		) <= now_ms:
			expired_ids.append(author_id)
			continue

		if (
			author_id != viewer_identity_id
			and not connected_ids.has(
				author_id
			)
		):
			continue

		var note_visibility: String = "connections"

		if (
			gs != null
			and "eraccount_profile_contract_engine" in gs
			and gs.eraccount_profile_contract_engine != null
		):
			note_visibility = str(
				gs.eraccount_profile_contract_engine
					.permission_for_identity(
						author_id,
						"notes_visibility",
						"connections"
					)
			)

		if (
			note_visibility == "private"
			and author_id != viewer_identity_id
		):
			continue

		var profile: Dictionary = _profile_by_identity(
			author_id
		)

		note ["author_display_name"] = str(
			profile.get(
				"display_name",
				note.get(
					"author_username",
					"Unknown"
				)
			)
		)
		note ["profile_photo"] = _safe_dictionary(
			profile.get(
				"profile_photo",
				{}
			)
		)
		note ["is_self"] = (
			author_id == viewer_identity_id
		)
		note ["can_reply"] = (
			author_id != viewer_identity_id
		)
		note ["viewer_username"] = viewer_username
		visible_notes.append(note)

	for expired_id in expired_ids:
		notes.erase(expired_id)

	if not expired_ids.is_empty():
		note_registry ["notes"] = notes
		_write_registry()

	visible_notes.sort_custom(
		Callable(
			self,
			"_sort_notes"
		)
	)

	return {
		"schema": "eralife.network_notes.context",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "visible_connection_notes",
		"notes": visible_notes,
		"note_count": visible_notes.size(),
		"character_limit": NOTE_CHARACTER_LIMIT,
		"context": context.duplicate(true),
		"created_at_ms": now_ms
	}


func reply_to_note(
	note_id: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_message: String = str(
		message
	).strip_edges()

	if clean_message == "":
		return _fail(
			"reply_missing",
			"Enter a reply to this note.",
			context
		)

	var note: Dictionary = _note_by_id(
		note_id
	)

	if note.is_empty():
		return _fail(
			"note_missing",
			"That note is no longer available.",
			context
		)

	var identity_context: Dictionary = _identity_context()
	var sender_username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var recipient_username: String = str(
		note.get(
			"author_username",
			""
		)
	)

	if (
		gs == null
		or not ("messenger_contract_engine" in gs)
	):
		return _fail(
			"messenger_unavailable",
			"MessengerContractEngine is unavailable.",
			context
		)

	if gs.messenger_contract_engine == null:
		gs.messenger_contract_engine = (
			MessengerContractEngine.new(gs)
		)

	return gs.messenger_contract_engine.send_direct_message(
		sender_username,
		recipient_username,
		clean_message,
		{
			"source": "network_note_reply",
			"note_id": note_id,
			"note_text": str(note.get("text", ""))
		}
	)


func migrate_username(
	identity_id: String,
	_old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	var notes: Dictionary = _safe_dictionary(
		note_registry.get(
			"notes",
			{}
		)
	)

	if notes.has(identity_id):
		var note: Dictionary = _safe_dictionary(
			notes.get(
				identity_id,
				{}
			)
		)
		note ["author_username"] = new_username
		notes [identity_id] = note
		note_registry ["notes"] = notes
		_write_registry()

	return {
		"success": true,
		"mode": "network_note_username_migrated",
		"identity_id": identity_id,
		"new_username": new_username,
		"context": context.duplicate(true)
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

	if command_id == "network_notes.set":
		return set_note(
			str(envelope.get("text", "")),
			envelope
		)

	if command_id == "network_notes.emit":
		return emit_visible_notes(envelope)

	if command_id == "network_notes.reply":
		return reply_to_note(
			str(envelope.get("note_id", "")),
			str(envelope.get("message", "")),
			envelope
		)

	return _fail(
		"unknown_network_notes_command",
		"NetworkNotesContractEngine did not recognize command.",
		envelope
	)


func _note_by_id(
	note_id: String
) -> Dictionary:
	var notes: Dictionary = _safe_dictionary(
		note_registry.get(
			"notes",
			{}
		)
	)

	for raw_author_id in notes.keys():
		var note: Dictionary = _safe_dictionary(
			notes.get(
				raw_author_id,
				{}
			)
		)

		if str(note.get("note_id", "")) == note_id:
			return note

	return {}


func _mentions_from_text(
	text: String
) -> Array:
	var mentions: Array = []

	for raw_word in text.split(
		" ",
		false
	):
		var word: String = str(
			raw_word
		).strip_edges()

		if not word.begins_with("@"):
			continue

		var username: String = word.trim_prefix("@")

		for punctuation in [
			".",
			",",
			"!",
			"?",
			":",
			";"
		]:
			username = username.trim_suffix(
				punctuation
			)

		if (
			username != ""
			and not _contains_case_insensitive(
				mentions,
				username
			)
		):
			mentions.append(username)

	return mentions


func _connected_usernames(
	username: String
) -> Array:
	var out: Array = []

	if (
		gs == null
		or not ("connection_graph_network" in gs)
	):
		return out

	if gs.connection_graph_network == null:
		gs.connection_graph_network = (
			ConnectionGraphNetwork.new(gs)
		)

	var context: Dictionary = (
		gs.connection_graph_network
			.emit_connection_context(
				username,
				{
					"source": "network_notes"
				}
			)
	)

	for raw_connection in context.get(
		"connections",
		[]
	):
		if typeof(raw_connection) != TYPE_DICTIONARY:
			continue

		out.append(
			str(
				(raw_connection as Dictionary).get(
					"username",
					""
				)
			)
		)

	return out


func _connected_identity_ids(
	identity_id: String
) -> Array:
	if (
		gs != null
		and "connection_graph_network" in gs
		and gs.connection_graph_network != null
	):
		return (
			gs.connection_graph_network
				.connected_identity_ids(
					identity_id
				)
		)

	return []


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
						"source": "network_notes"
					}
				)
		)

	return {}


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
	):
		return gs.identity_contract_engine.emit_identity_context({
			"source": "network_notes"
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


func _contains_case_insensitive(
	values: Array,
	target: String
) -> bool:
	for raw_value in values:
		if (
			str(raw_value).to_lower()
			== target.to_lower()
		):
			return true

	return false


func _sort_notes(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return (
		int(a.get("created_at_ms", 0))
		> int(b.get("created_at_ms", 0))
	)


func _ensure_state() -> void:
	note_registry = _read_registry()

	if (
		typeof(
			note_registry.get(
				"notes",
				{}
			)
		)
		!= TYPE_DICTIONARY
	):
		note_registry ["notes"] = {}


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		NOTE_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"notes": {}
		}

	var file:= FileAccess.open(
		NOTE_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"notes": {}
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
		"notes": {}
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		NOTE_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			note_registry,
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
		"schema": "eralife.network_notes.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	return last_report.duplicate(true)