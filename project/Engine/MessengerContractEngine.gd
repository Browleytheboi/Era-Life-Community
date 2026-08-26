extends Resource
class_name MessengerContractEngine

const ENGINE_SCHEMA:= "eralife.messenger_contract_engine"
const CONTRACT_VERSION:= 1
const MESSAGE_REGISTRY_PATH:= "user://identity/messenger_registry.json"

var gs
var message_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()

func send_direct_message(sender_username: String, recipient_username: String, message_text: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var sender: String = str(sender_username).strip_edges()
	var recipient: String = str(recipient_username).strip_edges()
	var body: String = str(message_text).strip_edges()

	if sender == "":
		return _fail("sender_missing", "Sender username is missing.", context)
	if recipient == "":
		return _fail("recipient_missing", "Recipient username is missing.", context)
	if body == "":
		return _fail("message_missing", "Message text is empty.", context)

	var thread_id: String = _thread_id(sender, recipient)
	var threads: Dictionary = _safe_dictionary(message_registry.get("threads", {}))
	var thread: Dictionary = _safe_dictionary(threads.get(thread_id, {}))
	var messages: Array = _safe_array(thread.get("messages", []))

	var message: Dictionary = {
		"schema": "eralife.messenger.message",
		"version": CONTRACT_VERSION,
		"message_id": "msg_%d_%d" % [int(Time.get_ticks_msec()), messages.size()],
		"thread_id": thread_id,
		"sender_username": sender,
		"recipient_username": recipient,
		"body": body,
		"context": context.duplicate(true),
		"read": false,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	messages.append(message)
	thread ["thread_id"] = thread_id
	thread ["participants"] = [sender, recipient]
	thread ["messages"] = messages
	thread ["updated_at_ms"] = int(Time.get_ticks_msec())
	threads [thread_id] = thread
	message_registry ["threads"] = threads
	_write_registry()

	last_report = {
		"schema": "eralife.messenger.send_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "direct_message_sent",
		"message": message.duplicate(true),
		"thread": thread.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)

func send_friend_request(sender_username: String, recipient_username: String, note: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var sender: String = str(sender_username).strip_edges()
	var recipient: String = str(recipient_username).strip_edges()

	if sender == "":
		return _fail("sender_missing", "Sender username is missing.", context)
	if recipient == "":
		return _fail("recipient_missing", "Recipient username is missing.", context)
	if sender.to_lower() == recipient.to_lower():
		return _fail("self_friend_request", "You cannot add yourself as a friend.", context)

	var requests: Dictionary = _safe_dictionary(message_registry.get("friend_requests", {}))
	var request_id: String = "friend_%s_to_%s" % [sender.to_lower(), recipient.to_lower()]

	var request: Dictionary = {
		"schema": "eralife.messenger.friend_request",
		"version": CONTRACT_VERSION,
		"request_id": request_id,
		"sender_username": sender,
		"recipient_username": recipient,
		"note": str(note),
		"state": "pending",
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	requests [request_id] = request
	message_registry ["friend_requests"] = requests
	_write_registry()

	last_report = {
		"schema": "eralife.messenger.friend_request_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "friend_request_sent",
		"friend_request": request.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)

func emit_messenger_context(username: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_username: String = str(username).strip_edges()
	var threads: Dictionary = _safe_dictionary(message_registry.get("threads", {}))
	var friend_requests: Dictionary = _safe_dictionary(message_registry.get("friend_requests", {}))
	var visible_threads: Array = []
	var visible_requests: Array = []

	for raw_thread_id in threads.keys():
		var thread: Dictionary = _safe_dictionary(threads.get(raw_thread_id, {}))
		var participants: Array = _safe_array(thread.get("participants", []))
		if clean_username in participants:
			visible_threads.append(thread)

	for raw_request_id in friend_requests.keys():
		var request: Dictionary = _safe_dictionary(friend_requests.get(raw_request_id, {}))
		if str(request.get("recipient_username", "")).to_lower() == clean_username.to_lower() or str(request.get("sender_username", "")).to_lower() == clean_username.to_lower():
			visible_requests.append(request)

	visible_threads.sort_custom(Callable(self, "_sort_updated_desc"))
	visible_requests.sort_custom(Callable(self, "_sort_created_desc"))

	return {
		"schema": "eralife.messenger.context",
		"version": CONTRACT_VERSION,
		"success": true,
		"username": clean_username,
		"threads": visible_threads,
		"friend_requests": visible_requests,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "messenger.send_direct_message":
		return send_direct_message(
			str(envelope.get("sender_username", "")),
			str(envelope.get("recipient_username", "")),
			str(envelope.get("message", envelope.get("body", ""))),
			envelope
		)

	if command_id == "messenger.send_friend_request":
		return send_friend_request(
			str(envelope.get("sender_username", "")),
			str(envelope.get("recipient_username", "")),
			str(envelope.get("note", "")),
			envelope
		)

	if command_id == "messenger.emit_context":
		return emit_messenger_context(str(envelope.get("username", "")), envelope)

	return _fail("unknown_messenger_command", "MessengerContractEngine did not recognize command.", envelope)

func _thread_id(a: String, b: String) -> String:
	var left: String = a.strip_edges().to_lower()
	var right: String = b.strip_edges().to_lower()
	if left <= right:
		return "%s__%s" % [left, right]
	return "%s__%s" % [right, left]

func _ensure_state() -> void:
	message_registry = _read_registry()
	_commit_state()

func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(MESSAGE_REGISTRY_PATH):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"threads": {},
			"friend_requests": {}
		}

	var file:= FileAccess.open(MESSAGE_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"threads": {},
			"friend_requests": {}
		}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("threads", {})) != TYPE_DICTIONARY:
			data ["threads"] = {}
		if typeof(data.get("friend_requests", {})) != TYPE_DICTIONARY:
			data ["friend_requests"] = {}
		return data

	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"threads": {},
		"friend_requests": {}
	}

func _write_registry() -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(MESSAGE_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(message_registry, "\t"))
	file.close()
func migrate_username(
	old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var old_clean: String = str(
		old_username
	).strip_edges()
	var new_clean: String = str(
		new_username
	).strip_edges()

	if old_clean == "" or new_clean == "":
		return _fail(
			"username_migration_invalid",
			"Messenger username migration requires both usernames.",
			context
		)

	var threads: Dictionary = (
		_safe_dictionary(
			message_registry.get(
				"threads",
				{}
			)
		)
	)
	var migrated_threads: Dictionary = {}

	for raw_thread_id in threads.keys():
		var thread: Dictionary = (
			_safe_dictionary(
				threads.get(
					raw_thread_id,
					{}
				)
			)
		)
		var participants: Array = _safe_array(
			thread.get(
				"participants",
				[]
			)
		)

		for participant_index in range(
			participants.size()
		):
			if str(
				participants [
					participant_index
				]
			).to_lower() == old_clean.to_lower():
				participants [
					participant_index
				] = new_clean

		var messages: Array = _safe_array(
			thread.get(
				"messages",
				[]
			)
		)

		for message_index in range(
			messages.size()
		):
			if (
				typeof(messages [message_index])
				!= TYPE_DICTIONARY
			):
				continue

			var message: Dictionary = (
				messages [message_index]
				as Dictionary
			).duplicate(true)

			if str(
				message.get(
					"sender_username",
					""
				)
			).to_lower() == old_clean.to_lower():
				message ["sender_username"] = (
					new_clean
				)

			if str(
				message.get(
					"recipient_username",
					""
				)
			).to_lower() == old_clean.to_lower():
				message ["recipient_username"] = (
					new_clean
				)

			messages [message_index] = message

		thread ["participants"] = participants
		thread ["messages"] = messages

		var migrated_thread_id: String = str(
			raw_thread_id
		)

		if participants.size() >= 2:
			migrated_thread_id = _thread_id(
				str(participants [0]),
				str(participants [1])
			)

		thread ["thread_id"] = migrated_thread_id
		migrated_threads [
			migrated_thread_id
		] = thread

	var requests: Dictionary = (
		_safe_dictionary(
			message_registry.get(
				"friend_requests",
				{}
			)
		)
	)
	var migrated_requests: Dictionary = {}

	for raw_request_id in requests.keys():
		var request: Dictionary = (
			_safe_dictionary(
				requests.get(
					raw_request_id,
					{}
				)
			)
		)

		if str(
			request.get(
				"sender_username",
				""
			)
		).to_lower() == old_clean.to_lower():
			request ["sender_username"] = (
				new_clean
			)

		if str(
			request.get(
				"recipient_username",
				""
			)
		).to_lower() == old_clean.to_lower():
			request ["recipient_username"] = (
				new_clean
			)

		var migrated_request_id: String = str(
			request.get(
				"request_id",
				raw_request_id
			)
		)

		if migrated_request_id.begins_with(
			"friend_"
		):
			migrated_request_id = (
				"friend_%s_to_%s"
				% [
					str(
						request.get(
							"sender_username",
							""
						)
					).to_lower(),
					str(
						request.get(
							"recipient_username",
							""
						)
					).to_lower()
				]
			)

		request ["request_id"] = (
			migrated_request_id
		)
		migrated_requests [
			migrated_request_id
		] = request

	message_registry ["threads"] = (
		migrated_threads
	)
	message_registry ["friend_requests"] = (
		migrated_requests
	)
	message_registry ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	_write_registry()

	last_report = {
		"schema": (
			"eralife.messenger.username_migration_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"messenger_username_migrated"
		),
		"old_username": old_clean,
		"new_username": new_clean,
		"context": context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	_commit_state()
	return last_report.duplicate(true)
func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["messenger_contract_engine_registry"] = message_registry.duplicate(true)
	gs.scenario_state ["last_messenger_contract_report"] = last_report.duplicate(true)

func _sort_updated_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))

func _sort_created_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) > int(b.get("created_at_ms", 0))

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.messenger.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)