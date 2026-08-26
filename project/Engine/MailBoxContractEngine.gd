extends Resource
class_name MailBoxContractEngine

const ENGINE_SCHEMA:= "eralife.global_reality_intake_mailbox"
const CONTRACT_VERSION:= 1
const INTAKE_REGISTRY_PATH:= "user://identity/reality_intake_registry.json"
const ACCOUNT_REGISTRY_PATH:= "user://identity/account_registry.json"

var gs
var intake_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()

func emit_reality_intake_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs != null:
		if gs.eralife_network_contract_engine == null:
			gs.eralife_network_contract_engine = (
				EraLifeNetworkContractEngine.new(gs)
			)

		if (
			gs.eralife_network_contract_engine != null
			and gs.eralife_network_contract_engine.has_method(
				"emit_network_surface_contract"
			)
		):
			return (
				gs.eralife_network_contract_engine
				.emit_network_surface_contract({
					"source": (
						"mailbox.emit_reality_intake_contract"
					),
					"mailbox_context": (
						context.duplicate(true)
					)
				})
			)

	return emit_mailbox_contract(context)
func emit_mailbox_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return {
			"schema": (
				"eralife.reality_intake.mailbox_contract"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": (
				"guest_mailbox_unavailable"
			),
			"reason": (
				"An ErAccount is required for network delivery."
			),
			"identity_context": (
				identity_context.duplicate(true)
			),
			"entries": [],
			"unread_count": 0,
			"messenger_context": {},
			"self_host_runtime": {},
			"self_host_network": {},
			"context": context.duplicate(true),
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"contract_mesh": {
				"source_of_truth": (
					"MailBoxContractEngine"
				),
				"ui_mutation_allowed": false
			}
		}

	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var mailbox: Dictionary = (
		_mailbox_for_username(username)
	)
	var entries: Array = _safe_array(
		mailbox.get(
			"entries",
			[]
		)
	)
	entries.sort_custom(
		Callable(
			self,
			"_sort_entries_newest_first"
		)
	)

	var messenger_context: Dictionary = {}

	if (
		gs != null
		and "messenger_contract_engine" in gs
		and gs.messenger_contract_engine != null
		and gs.messenger_contract_engine.has_method(
			"emit_messenger_context"
		)
	):
		messenger_context = (
			gs.messenger_contract_engine
			.emit_messenger_context(
				username,
				{
					"source": (
						"mailbox_contract"
					)
				}
			)
		)

	var self_host_runtime: Dictionary = (
		_self_host_runtime_presence_contract(
			identity_context,
			context
		)
	)
	var self_host_network: Dictionary = (
		_self_host_network_contract(
			identity_context,
			context
		)
	)

	var contract: Dictionary = {
		"schema": (
			"eralife.reality_intake.mailbox_contract"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "mailbox_ready",
		"title": (
			"%s's Reality Intake"
			% username
		),
		"username": username,
		"identity_context": (
			identity_context.duplicate(true)
		),
		"entries": entries,
		"unread_count": (
			_unread_count(entries)
		),
		"messenger_context": (
			messenger_context.duplicate(true)
		),
		"self_host_runtime": (
			self_host_runtime.duplicate(true)
		),
		"self_host_network": (
			self_host_network.duplicate(true)
		),
		"live_nodes": _safe_array(
			self_host_network.get(
				"live_nodes",
				[]
			)
		),
		"live_node_count": int(
			self_host_network.get(
				"live_node_count",
				0
			)
		),
		"supported_payloads": [
			"live_reality_invite",
			"life_packet",
			"item_packet",
			"fork_notice",
			"reality_transfer",
			"direct_message",
			"friend_request",
			"network_notification",
			"announcement"
		],
		"ui_is_lens": true,
		"context": context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"source_of_truth": (
				"MailBoxContractEngine"
			),
			"connection_authority": (
				"ConnectionGraphNetwork"
			),
			"chat_authority": (
				"MessengerContractEngine"
			),
			"ui_mutation_allowed": false
		}
	}

	last_report = contract.duplicate(true)
	_commit_state()
	return contract
func _self_host_network_contract(identity_context: Dictionary, context: Dictionary = {}) -> Dictionary:
	if gs != null and "self_host_network_contract_engine" in gs:
		if gs.self_host_network_contract_engine == null:
			gs.self_host_network_contract_engine = SelfHostNetworkContractEngine.new(gs)
		if gs.self_host_network_contract_engine != null and gs.self_host_network_contract_engine.has_method("emit_network_presence_contract"):
			return gs.self_host_network_contract_engine.emit_network_presence_contract({
				"source": "mailbox_reality_intake_contract",
				"identity_context": identity_context.duplicate(true),
				"context": context.duplicate(true)
			})

	return {
		"schema": "eralife.self_host_network.presence_contract",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason": "SelfHostNetworkContractEngine unavailable.",
		"live_nodes": [],
		"live_node_count": 0
	}

func search_registered_usernames(query: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_query: String = str(query).strip_edges().to_lower()
	var identity_context: Dictionary = _identity_context()
	var current_username: String = str(identity_context.get("account_username", "")).strip_edges().to_lower()
	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	var results: Array = []

	for raw_key in accounts.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if key == "":
			continue
		if key == current_username:
			continue
		var account: Dictionary = _safe_dictionary(accounts.get(raw_key, {}))
		var username: String = str(account.get("username", raw_key)).strip_edges()
		var email: String = str(account.get("email", "")).strip_edges()
		if clean_query != "" and username.to_lower().find(clean_query) == -1:
			continue
		results.append({
			"username": username,
			"email": email,
			"cloud_identity_id": str(account.get("cloud_identity_id", "")),
			"state": str(account.get("state", "registered"))
		})

	results.sort_custom(Callable(self, "_sort_user_results"))

	return {
		"schema": "eralife.reality_intake.username_search",
		"version": CONTRACT_VERSION,
		"success": true,
		"query": clean_query,
		"results": results,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func send_friend_request_to_username(
	recipient_username: String,
	note: String = "",
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return _fail(
			"account_required",
			"Sign into an ErAccount to send a reality connection request.",
			context
		)

	var sender_username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var recipient: Dictionary = (
		_registered_account_for_username(
			recipient_username
		)
	)

	if recipient.is_empty():
		return _fail(
			"recipient_missing",
			"That ErAccount username was not found.",
			context
		)

	var recipient_name: String = str(
		recipient.get(
			"username",
			recipient_username
		)
	).strip_edges()
	var recipient_identity_id: String = str(
		recipient.get(
			"cloud_identity_id",
			recipient.get(
				"identity_id",
				""
			)
		)
	).strip_edges()

	if (
		gs != null
		and gs.eraccount_profile_contract_engine != null
	):
		var request_permission: String = str(
			gs.eraccount_profile_contract_engine
			.permission_for_identity(
				recipient_identity_id,
				"connection_requests",
				"everyone"
			)
		).to_lower()

		if request_permission in [
			"nobody",
			"none",
			"private",
			"disabled"
		]:
			return _fail(
				"connection_requests_disabled",
				"That ErAccount is not accepting connection requests.",
				context
			)

	if gs == null:
		return _fail(
			"connection_authority_unavailable",
			"ConnectionGraphNetwork is unavailable.",
			context
		)

	if gs.connection_graph_network == null:
		gs.connection_graph_network = (
			ConnectionGraphNetwork.new(gs)
		)

	var graph_report: Dictionary = (
		gs.connection_graph_network
		.create_connection_request(
			sender_username,
			recipient_name,
			note,
			{
				"source": (
					"mailbox.send_friend_request"
				),
				"delivery_context": (
					context.duplicate(true)
				)
			}
		)
	)

	if not bool(
		graph_report.get(
			"success",
			false
		)
	):
		return graph_report

	var connection_request: Dictionary = (
		_safe_dictionary(
			graph_report.get(
				"connection_request",
				{}
			)
		)
	)

	if connection_request.is_empty():
		return graph_report

	var entry: Dictionary = _make_entry({
		"type": "friend_request",
		"title": (
			"Reality connection request received"
		),
		"sender_username": sender_username,
		"recipient_username": recipient_name,
		"message": str(
			note
		).strip_edges(),
		"actions": [
			"accept",
			"ignore"
		],
		"payload": {
			"connection_request_id": str(
				connection_request.get(
					"request_id",
					""
				)
			),
			"connection_request": (
				connection_request.duplicate(true)
			),
			"connection_graph_report": (
				graph_report.duplicate(true)
			)
		}
	})
	_push_entry(
		recipient_name,
		entry
	)

	var report: Dictionary = {
		"schema": (
			"eralife.reality_intake.connection_request_send_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": str(
			graph_report.get(
				"mode",
				"connection_request_created"
			)
		),
		"message": str(
			graph_report.get(
				"message",
				"Reality connection request sent."
			)
		),
		"entry": entry.duplicate(true),
		"connection_request": (
			connection_request.duplicate(true)
		),
		"connection_graph_report": (
			graph_report.duplicate(true)
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"request_authority": (
				"ConnectionGraphNetwork"
			),
			"delivery_authority": (
				"MailBoxContractEngine"
			),
			"ui_mutation_allowed": false
		}
	}

	last_report = report.duplicate(true)
	_commit_state()
	return report
func deliver_network_notification(
	recipient_username: String,
	notification_type: String,
	title: String,
	message: String,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var recipient: Dictionary = (
		_registered_account_for_username(
			recipient_username
		)
	)

	if recipient.is_empty():
		return _fail(
			"recipient_missing",
			"The notification recipient could not be resolved.",
			payload
		)

	var recipient_name: String = str(
		recipient.get(
			"username",
			recipient_username
		)
	).strip_edges()
	var entry: Dictionary = _make_entry({
		"type": "network_notification",
		"title": str(
			title
		).strip_edges(),
		"sender_username": "EraLife Network",
		"recipient_username": recipient_name,
		"message": str(
			message
		).strip_edges(),
		"actions": [
			"open"
		],
		"payload": {
			"notification_type": str(
				notification_type
			).strip_edges(),
			"notification_payload": (
				payload.duplicate(true)
			)
		}
	})
	_push_entry(
		recipient_name,
		entry
	)

	var report: Dictionary = {
		"schema": (
			"eralife.reality_intake.notification_delivery_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"network_notification_delivered"
		),
		"entry": entry.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	last_report = report.duplicate(true)
	_commit_state()
	return report
func send_current_life_to_username(recipient_username: String, dm_message: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail("account_required", "Sign into an ErAccount to send a life.", context)

	var sender_username: String = str(identity_context.get("account_username", "")).strip_edges()
	var recipient: Dictionary = _registered_account_for_username(recipient_username)
	if recipient.is_empty():
		return _fail("recipient_missing", "That ErAccount username was not found.", context)

	var recipient_name: String = str(recipient.get("username", recipient_username)).strip_edges()
	var recipient_email: String = str(recipient.get("email", "")).strip_edges()
	var life_packet: Dictionary = _build_current_life_packet(identity_context, context)

	var messenger_report: Dictionary = {}
	if str(dm_message).strip_edges() != "" and gs != null and "messenger_contract_engine" in gs and gs.messenger_contract_engine != null and gs.messenger_contract_engine.has_method("send_direct_message"):
		messenger_report = gs.messenger_contract_engine.send_direct_message(sender_username, recipient_name, dm_message, {
			"source": "send_current_life_to_username",
			"attached_life_id": str(life_packet.get("life_id", ""))
		})

	var transport_report: Dictionary = {}
	if gs != null and "email_verification_transport_engine" in gs and gs.email_verification_transport_engine != null and gs.email_verification_transport_engine.has_method("queue_life_packet_transfer_email"):
		transport_report = gs.email_verification_transport_engine.queue_life_packet_transfer_email(life_packet, recipient_email, {
			"source": "mailbox_life_packet_transfer",
			"sender_username": sender_username,
			"recipient_username": recipient_name
		})

	var entry: Dictionary = _make_entry({
		"type": "life_packet",
		"title": "Life from %s" % sender_username,
		"sender_username": sender_username,
		"recipient_username": recipient_name,
		"message": dm_message,
		"actions": ["play", "observe", "fork"],
		"payload": {
			"life_packet": life_packet.duplicate(true),
			"transport_report": transport_report.duplicate(true),
			"messenger_report": messenger_report.duplicate(true)
		}
	})
	_push_entry(recipient_name, entry)

	return {
		"schema": "eralife.reality_intake.life_send_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "life_sent_to_reality_intake",
		"entry": entry.duplicate(true),
		"life_packet": life_packet.duplicate(true),
		"transport_report": transport_report.duplicate(true),
		"messenger_report": messenger_report.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func send_item_packet_to_username(recipient_username: String, item_packet: Dictionary = {}, dm_message: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail("account_required", "Sign into an ErAccount to send an item packet.", context)

	var sender_username: String = str(identity_context.get("account_username", "")).strip_edges()
	var recipient: Dictionary = _registered_account_for_username(recipient_username)
	if recipient.is_empty():
		return _fail("recipient_missing", "That ErAccount username was not found.", context)

	var recipient_name: String = str(recipient.get("username", recipient_username)).strip_edges()
	var packet: Dictionary = _normalize_item_packet(item_packet, identity_context, context)

	var entry: Dictionary = _make_entry({
		"type": "item_packet",
		"title": "ItemPacket from %s" % sender_username,
		"sender_username": sender_username,
		"recipient_username": recipient_name,
		"message": dm_message,
		"actions": ["open", "verify", "import"],
		"payload": {
			"item_packet": packet.duplicate(true)
		}
	})
	_push_entry(recipient_name, entry)

	return {
		"schema": "eralife.reality_intake.item_send_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "item_packet_sent_to_reality_intake",
		"entry": entry.duplicate(true),
		"item_packet": packet.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func consume_entry_action(
	entry_id: String,
	action: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return _fail(
			"account_required",
			"Sign into an ErAccount to use Reality Intake.",
			context
		)

	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var mailbox: Dictionary = (
		_mailbox_for_username(username)
	)
	var entries: Array = _safe_array(
		mailbox.get(
			"entries",
			[]
		)
	)
	var clean_entry_id: String = str(
		entry_id
	).strip_edges()
	var clean_action: String = str(
		action
	).strip_edges().to_lower()

	for entry_index in range(entries.size()):
		var entry: Dictionary = (
			_safe_dictionary(
				entries [entry_index]
			)
		)

		if str(
			entry.get(
				"entry_id",
				""
			)
		) != clean_entry_id:
			continue

		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		).to_lower()
		var payload: Dictionary = (
			_safe_dictionary(
				entry.get(
					"payload",
					{}
				)
			)
		)
		var authority_report: Dictionary = {}

		if entry_type == "friend_request":
			var request_payload: Dictionary = (
				_safe_dictionary(
					payload.get(
						"connection_request",
						{}
					)
				)
			)
			var request_id: String = str(
				payload.get(
					"connection_request_id",
					request_payload.get(
						"request_id",
						""
					)
				)
			).strip_edges()

			if gs == null:
				return _fail(
					"connection_authority_unavailable",
					"ConnectionGraphNetwork is unavailable.",
					context
				)

			if gs.connection_graph_network == null:
				gs.connection_graph_network = (
					ConnectionGraphNetwork.new(gs)
				)

			authority_report = (
				gs.connection_graph_network
				.resolve_connection_request(
					request_id,
					username,
					clean_action,
					{
						"source": (
							"mailbox.consume_entry_action"
						),
						"entry_id": clean_entry_id,
						"entry": (
							entry.duplicate(true)
						)
					}
				)
			)

			if not bool(
				authority_report.get(
					"success",
					false
				)
			):
				return authority_report

			var sender_username: String = str(
				entry.get(
					"sender_username",
					""
				)
			).strip_edges()

			if (
				clean_action == "accept"
				and sender_username != ""
			):
				deliver_network_notification(
					sender_username,
					"connection_accepted",
					"Reality connection accepted",
					(
						"%s accepted your reality connection request."
						% username
					),
					{
						"connection_report": (
							authority_report.duplicate(true)
						)
					}
				)

		entry ["read"] = true
		entry ["resolved"] = clean_action in [
			"accept",
			"ignore",
			"decline",
			"reject",
			"import",
			"verify"
		]
		entry ["resolution_state"] = str(
			authority_report.get(
				"mode",
				clean_action
			)
		)
		entry ["last_action"] = clean_action
		entry ["last_action_at_ms"] = int(
			Time.get_ticks_msec()
		)
		entry ["authority_report"] = (
			authority_report.duplicate(true)
		)

		entries [entry_index] = entry
		mailbox ["entries"] = entries
		_set_mailbox_for_username(
			username,
			mailbox
		)

		var report: Dictionary = {
			"schema": (
				"eralife.reality_intake.entry_action_report"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": str(
				authority_report.get(
					"mode",
					"entry_action_resolved"
				)
			),
			"message": str(
				authority_report.get(
					"message",
					"Reality Intake action resolved."
				)
			),
			"entry": entry.duplicate(true),
			"action": clean_action,
			"authority_report": (
				authority_report.duplicate(true)
			),
			"action_contract": (
				_action_contract_for_entry(
					entry,
					clean_action
				)
			),
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}
		last_report = report.duplicate(true)
		_commit_state()
		return report

	return _fail(
		"entry_missing",
		"Reality Intake entry was not found.",
		context
	)
func migrate_username(
	old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var old_key: String = str(
		old_username
	).strip_edges().to_lower()
	var new_key: String = str(
		new_username
	).strip_edges().to_lower()

	if old_key == "" or new_key == "":
		return _fail(
			"username_missing",
			"Both usernames are required for mailbox migration.",
			context
		)

	var mailboxes: Dictionary = (
		_safe_dictionary(
			intake_registry.get(
				"mailboxes",
				{}
			)
		)
	)

	if mailboxes.has(old_key):
		var own_mailbox: Dictionary = (
			_safe_dictionary(
				mailboxes.get(
					old_key,
					{}
				)
			)
		)
		own_mailbox ["username"] = new_username
		mailboxes.erase(old_key)
		mailboxes [new_key] = own_mailbox

	for raw_key in mailboxes.keys():
		var mailbox: Dictionary = (
			_safe_dictionary(
				mailboxes.get(
					raw_key,
					{}
				)
			)
		)
		var entries: Array = _safe_array(
			mailbox.get(
				"entries",
				[]
			)
		)

		for entry_index in range(entries.size()):
			if (
				typeof(entries [entry_index])
				!= TYPE_DICTIONARY
			):
				continue

			var entry: Dictionary = (
				entries [entry_index] as Dictionary
			).duplicate(true)

			if str(
				entry.get(
					"sender_username",
					""
				)
			).to_lower() == old_key:
				entry ["sender_username"] = (
					new_username
				)

			if str(
				entry.get(
					"recipient_username",
					""
				)
			).to_lower() == old_key:
				entry ["recipient_username"] = (
					new_username
				)

			entries [entry_index] = entry

		mailbox ["entries"] = entries
		mailboxes [raw_key] = mailbox

	intake_registry ["mailboxes"] = mailboxes
	_write_registry()

	return {
		"success": true,
		"mode": (
			"mailbox_username_migrated"
		),
		"old_username": old_username,
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

	if (
		command_id
		== "mailbox.emit_reality_intake_contract"
	):
		return emit_reality_intake_contract(
			envelope
		)

	if (
		command_id
		== "mailbox.emit_mailbox_contract"
	):
		return emit_mailbox_contract(
			envelope
		)

	if command_id == "mailbox.search_users":
		return search_registered_usernames(
			str(
				envelope.get(
					"query",
					""
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.send_friend_request"
	):
		return send_friend_request_to_username(
			str(
				envelope.get(
					"recipient_username",
					""
				)
			),
			str(
				envelope.get(
					"note",
					""
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.send_current_life"
	):
		return send_current_life_to_username(
			str(
				envelope.get(
					"recipient_username",
					""
				)
			),
			str(
				envelope.get(
					"message",
					""
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.send_live_reality_invite"
	):
		return send_live_reality_invite_to_username(
			str(
				envelope.get(
					"recipient_username",
					""
				)
			),
			str(
				envelope.get(
					"message",
					""
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.send_item_packet"
	):
		return send_item_packet_to_username(
			str(
				envelope.get(
					"recipient_username",
					""
				)
			),
			_safe_dictionary(
				envelope.get(
					"item_packet",
					{}
				)
			),
			str(
				envelope.get(
					"message",
					""
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.consume_entry_action"
	):
		return consume_entry_action(
			str(
				envelope.get(
					"entry_id",
					""
				)
			),
			str(
				envelope.get(
					"entry_action",
					envelope.get(
						"action",
						""
					)
				)
			),
			envelope
		)

	if (
		command_id
		== "mailbox.deliver_network_notification"
	):
		return deliver_network_notification(
			str(
				envelope.get(
					"recipient_username",
					""
				)
			),
			str(
				envelope.get(
					"notification_type",
					"network_event"
				)
			),
			str(
				envelope.get(
					"title",
					"EraLife Network"
				)
			),
			str(
				envelope.get(
					"message",
					""
				)
			),
			_safe_dictionary(
				envelope.get(
					"payload",
					{}
				)
			)
		)

	return _fail(
		"unknown_mailbox_command",
		"MailBoxContractEngine did not recognize command.",
		envelope
	)
func send_live_reality_invite_to_username(recipient_username: String, dm_message: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail("account_required", "Sign into an ErAccount to invite someone into your live reality.", context)

	var sender_username: String = str(identity_context.get("account_username", "")).strip_edges()
	var recipient: Dictionary = _registered_account_for_username(recipient_username)
	if recipient.is_empty():
		return _fail("recipient_missing", "That ErAccount username was not found.", context)

	var recipient_name: String = str(recipient.get("username", recipient_username)).strip_edges()
	var live_reality: Dictionary = _build_live_reality_invite_packet(identity_context, recipient, context)

	var messenger_report: Dictionary = {}
	if str(dm_message).strip_edges() != "" and gs != null and "messenger_contract_engine" in gs and gs.messenger_contract_engine != null and gs.messenger_contract_engine.has_method("send_direct_message"):
		messenger_report = gs.messenger_contract_engine.send_direct_message(sender_username, recipient_name, dm_message, {
			"source": "send_live_reality_invite_to_username",
			"attached_runtime_id": str(live_reality.get("runtime_id", "")),
			"attached_life_id": str(live_reality.get("life_id", ""))
		})

	var entry: Dictionary = _make_entry({
		"type": "live_reality_invite",
		"title": "%s invited you into a live reality" % sender_username,
		"sender_username": sender_username,
		"recipient_username": recipient_name,
		"message": dm_message,
		"actions": ["enter_live", "observe_live", "fork_snapshot"],
		"payload": {
			"live_reality": live_reality.duplicate(true),
			"messenger_report": messenger_report.duplicate(true)
		}
	})

	_push_entry(recipient_name, entry)

	return {
		"schema": "eralife.reality_intake.live_reality_invite_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "live_reality_invite_sent",
		"entry": entry.duplicate(true),
		"live_reality": live_reality.duplicate(true),
		"messenger_report": messenger_report.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "MailBoxContractEngine",
			"self_host_runtime_layer": "SelfHostRuntimeLayer",
			"ui_is_lens": true
		}
	}
func _build_live_reality_invite_packet(identity_context: Dictionary, recipient_account: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var runtime_presence: Dictionary = _self_host_runtime_presence_contract(identity_context, context)
	var life_packet: Dictionary = _build_current_life_packet(identity_context, context)
	var life_id: String = str(life_packet.get("life_id", "")).strip_edges()
	var runtime_id: String = str(runtime_presence.get("runtime_id", "")).strip_edges()

	if runtime_id == "":
		runtime_id = "local_runtime_%s_%d" % [
			str(identity_context.get("identity_id", "local")),
			int(Time.get_unix_time_from_system())
		]

	var invite: Dictionary = {
		"schema": "eralife.live_reality_invite",
		"version": CONTRACT_VERSION,
		"runtime_id": runtime_id,
		"host_identity_id": str(identity_context.get("identity_id", "")),
		"host_username": str(identity_context.get("account_username", "")),
		"recipient_username": str(recipient_account.get("username", "")),
		"life_id": life_id,
		"life_packet_ref": {
			"life_id": life_id,
			"player_name": str(life_packet.get("player_name", "Unknown Life")),
			"owner_username": str(life_packet.get("owner_username", "")),
			"origin_id": str(life_packet.get("origin_id", life_id))
		},
		"runtime_presence": runtime_presence.duplicate(true),
		"entry_modes": ["enter_live", "observe_live", "fork_snapshot"],
		"created_at_ms": int(Time.get_ticks_msec())
	}

	invite ["validation_signature"] = _packet_signature(invite)
	return invite


func _self_host_runtime_presence_contract(identity_context: Dictionary, context: Dictionary = {}) -> Dictionary:
	var runtime_layer: Node = _self_host_runtime_layer()
	var runtime_status: Dictionary = {}

	if runtime_layer != null and runtime_layer.has_method("get_runtime_status"):
		var raw_status: Variant = runtime_layer.call("get_runtime_status")
		if typeof(raw_status) == TYPE_DICTIONARY:
			runtime_status = (raw_status as Dictionary).duplicate(true)

	var life_id: String = ""
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		life_id = str(gs.scenario_state.get("life_id", "")).strip_edges()

	if life_id == "":
		life_id = "life_%s_%d" % [
			str(identity_context.get("identity_id", "local")),
			int(Time.get_unix_time_from_system())
		]
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["life_id"] = life_id

	var runtime_id: String = str(runtime_status.get("runtime_id", "")).strip_edges()
	if runtime_id == "":
		runtime_id = "self_host_%s_%s" % [
			str(identity_context.get("account_username", "guest")).strip_edges().to_lower(),
			life_id
		]

	var links: Dictionary = {}
	if typeof(runtime_status.get("remote_shell", {})) == TYPE_DICTIONARY:
		var remote_shell: Dictionary = runtime_status.get("remote_shell", {})
		links ["local_status_url"] = "http://%s:%d/self_host/status" % [
			str(remote_shell.get("bind_host", "127.0.0.1")),
			int(remote_shell.get("port", 7821))
		]

	if str(runtime_status.get("public_play_url", "")).strip_edges() != "":
		links ["public_play_url"] = str(runtime_status.get("public_play_url", ""))

	return {
		"schema": "eralife.self_host.runtime_presence",
		"version": CONTRACT_VERSION,
		"success": true,
		"active": bool(runtime_status.get("active", false)),
		"runtime_id": runtime_id,
		"host_identity_id": str(identity_context.get("identity_id", "")),
		"host_username": str(identity_context.get("account_username", "")),
		"life_id": life_id,
		"links": links.duplicate(true),
		"runtime_status": runtime_status.duplicate(true),
		"capabilities": {
		},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _self_host_runtime_layer() -> Node:
	var main_loop:= Engine.get_main_loop()
	if main_loop == null:
		return null

	if main_loop is SceneTree:
		var tree:= main_loop as SceneTree
		if tree.root == null:
			return null
		return tree.root.get_node_or_null("SelfHostRuntimeLayer")

	return null
func _build_current_life_packet(identity_context: Dictionary, context: Dictionary = {}) -> Dictionary:
	var life_id: String = ""
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		life_id = str(gs.scenario_state.get("life_id", "")).strip_edges()
	if life_id == "":
		life_id = "life_%s_%d" % [str(identity_context.get("identity_id", "local")), int(Time.get_unix_time_from_system())]
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["life_id"] = life_id

	var player_name: String = "Unknown Life"
	var actor_id: int = -1
	var age: int = 0
	if gs != null and gs.player != null:
		player_name = ("%s %s" % [str(gs.player.first_name), str(gs.player.last_name)]).strip_edges()
		actor_id = int(gs.player.id)
		age = int(gs.player.age)
	elif gs != null:
		actor_id = int(gs.player_id)

	var packet: Dictionary = {
		"schema": "eralife.life_packet",
		"version": 1,
		"identity_id": str(identity_context.get("identity_id", "")),
		"owner_identity_id": str(identity_context.get("identity_id", "")),
		"owner_username": str(identity_context.get("account_username", "")),
		"life_id": life_id,
		"origin_id": str(context.get("origin_id", life_id)),
		"fork_id": str(context.get("fork_id", "")),
		"player_name": player_name,
		"actor_id": actor_id,
		"checkpoint_snapshot": {
			"year": int(gs.year) if gs != null else 0,
			"age": age,
			"player_id": actor_id
		},
		"event_stream": [],
		"relationship_graph": {},
		"world_state_refs": {
			"world_seed": int(gs.world_seed) if gs != null and "world_seed" in gs else 0,
			"era_name": str(gs.era.get("name", "")) if gs != null and typeof(gs.era) == TYPE_DICTIONARY else ""
		},
		"sharing": {
			"play": true,
			"observe": true,
			"fork": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}
	packet ["signature"] = _packet_signature(packet)
	return packet

func _normalize_item_packet(item_packet: Dictionary, identity_context: Dictionary, context: Dictionary = {}) -> Dictionary:
	var packet: Dictionary = item_packet.duplicate(true)
	packet ["schema"] = "eralife.item_packet"
	packet ["version"] = int(packet.get("version", 1))
	packet ["item_id"] = str(packet.get("item_id", "item_%d" % int(Time.get_ticks_msec())))
	packet ["origin_life_id"] = str(packet.get("origin_life_id", context.get("origin_life_id", "")))
	packet ["ownership_history"] = _safe_array(packet.get("ownership_history", []))
	packet ["ownership_history"].append({
		"owner_identity_id": str(identity_context.get("identity_id", "")),
		"owner_username": str(identity_context.get("account_username", "")),
		"action": "packet_created_or_forwarded",
		"at_ms": int(Time.get_ticks_msec())
	})
	packet ["world_context"] = packet.get("world_context", {}) if typeof(packet.get("world_context", {})) == TYPE_DICTIONARY else {}
	packet ["validation_signature"] = _packet_signature(packet)
	return packet

func _make_entry(data: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.reality_intake.entry",
		"version": CONTRACT_VERSION,
		"entry_id": "intake_%d_%d" % [int(Time.get_ticks_msec()), abs(int(hash(JSON.stringify(data)))) % 1000000],
		"type": str(data.get("type", "reality_transfer")),
		"title": str(data.get("title", "Reality Transfer")),
		"sender_username": str(data.get("sender_username", "")),
		"recipient_username": str(data.get("recipient_username", "")),
		"message": str(data.get("message", "")),
		"actions": _safe_array(data.get("actions", [])),
		"payload": data.get("payload", {}) if typeof(data.get("payload", {})) == TYPE_DICTIONARY else {},
		"read": false,
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _push_entry(username: String, entry: Dictionary) -> void:
	var mailbox: Dictionary = _mailbox_for_username(username)
	var entries: Array = _safe_array(mailbox.get("entries", []))
	entries.append(entry.duplicate(true))
	if entries.size() > 300:
		entries = entries.slice(entries.size() - 300, entries.size())
	mailbox ["entries"] = entries
	_set_mailbox_for_username(username, mailbox)

func _mailbox_for_username(username: String) -> Dictionary:
	var key: String = str(username).strip_edges().to_lower()
	var mailboxes: Dictionary = _safe_dictionary(intake_registry.get("mailboxes", {}))
	if not mailboxes.has(key):
		mailboxes [key] = {
			"schema": "eralife.reality_intake.mailbox",
			"version": CONTRACT_VERSION,
			"username": username,
			"entries": [],
			"created_at_ms": int(Time.get_ticks_msec())
		}
		intake_registry ["mailboxes"] = mailboxes
		_write_registry()
	return _safe_dictionary(mailboxes.get(key, {}))

func _set_mailbox_for_username(username: String, mailbox: Dictionary) -> void:
	var key: String = str(username).strip_edges().to_lower()
	var mailboxes: Dictionary = _safe_dictionary(intake_registry.get("mailboxes", {}))
	mailboxes [key] = mailbox.duplicate(true)
	intake_registry ["mailboxes"] = mailboxes
	_write_registry()
	_commit_state()

func _registered_account_for_username(username: String) -> Dictionary:
	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	var key: String = str(username).strip_edges().to_lower()
	if accounts.has(key):
		return _safe_dictionary(accounts.get(key, {}))
	return {}

func _read_account_registry() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNT_REGISTRY_PATH):
		return { "schema": "eralife.identity.account_registry", "version": CONTRACT_VERSION, "accounts": {}}
	var file:= FileAccess.open(ACCOUNT_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": "eralife.identity.account_registry", "version": CONTRACT_VERSION, "accounts": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("accounts", {})) != TYPE_DICTIONARY:
			data ["accounts"] = {}
		return data
	return { "schema": "eralife.identity.account_registry", "version": CONTRACT_VERSION, "accounts": {}}

func _identity_context() -> Dictionary:
	if gs != null and "identity_contract_engine" in gs and gs.identity_contract_engine != null and gs.identity_contract_engine.has_method("emit_identity_context"):
		return gs.identity_contract_engine.emit_identity_context({ "source": "mailbox_identity_context"})
	return { "is_guest": true}

func _action_contract_for_entry(entry: Dictionary, action: String) -> Dictionary:
	var clean_action: String = str(action).strip_edges().to_lower()
	var entry_type: String = str(entry.get("type", "")).strip_edges().to_lower()
	var payload: Dictionary = entry.get("payload", {}) if typeof(entry.get("payload", {})) == TYPE_DICTIONARY else {}

	return {
		"schema": "eralife.reality_intake.action_contract",
		"version": CONTRACT_VERSION,
		"entry_id": str(entry.get("entry_id", "")),
		"entry_type": entry_type,
		"action": clean_action,
		"payload": payload.duplicate(true),
		"simulation_injection_required": clean_action in ["play", "observe", "fork", "resume", "import", "open", "enter_live", "observe_live", "fork_snapshot"],
		"self_host_runtime_required": entry_type == "live_reality_invite" and clean_action in ["enter_live", "observe_live"],
		"crr_merge_required": entry_type == "live_reality_invite",
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _unread_count(entries: Array) -> int:
	var count: int = 0
	for raw_entry in entries:
		if typeof(raw_entry) == TYPE_DICTIONARY and not bool((raw_entry as Dictionary).get("read", false)):
			count += 1
	return count

func _ensure_state() -> void:
	intake_registry = _read_registry()
	_commit_state()

func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(INTAKE_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "mailboxes": {}}
	var file:= FileAccess.open(INTAKE_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "mailboxes": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("mailboxes", {})) != TYPE_DICTIONARY:
			data ["mailboxes"] = {}
		return data
	return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "mailboxes": {}}

func _write_registry() -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(INTAKE_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(intake_registry, "\t"))
	file.close()

func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["reality_intake_registry"] = intake_registry.duplicate(true)
	gs.scenario_state ["last_reality_intake_report"] = last_report.duplicate(true)

func _packet_signature(packet: Dictionary) -> String:
	var unsigned: Dictionary = packet.duplicate(true)
	unsigned.erase("signature")
	unsigned.erase("validation_signature")
	return "sig_%d" % abs(int(hash(JSON.stringify(unsigned))))

func _sort_entries_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at_ms", 0)) > int(b.get("created_at_ms", 0))

func _sort_user_results(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("username", "")).to_lower() < str(b.get("username", "")).to_lower()

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
		"schema": "eralife.reality_intake.error",
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