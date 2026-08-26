extends Resource
class_name IdentityContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.identity_contract_engine_state"
const IDENTITY_PROFILE_SCHEMA:= "eralife.identity.profile_contract"
const IDENTITY_CONTEXT_SCHEMA:= "eralife.identity.context"
const LOCAL_IDENTITY_SCHEMA:= "eralife.identity.local_disk_uuid"
const CONTRACT_VERSION:= 2
const LOCAL_IDENTITY_PATH:= "user://identity/local_identity.json"
const ACCOUNT_SESSION_SCHEMA:= "eralife.identity.account_session"
const ACCOUNT_SESSION_PATH:= "user://identity/account_session.json"
const ACCOUNT_REGISTRY_PATH:= "user://identity/account_registry.json"
var gs
var identity_profiles: Dictionary = {}
var identity_event_ledger: Array = []
var local_identity_context: Dictionary = {}
var cloud_identity_context: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()

func resolve_local_identity(context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_identity_dir()

	var disk_identity: Dictionary = _read_local_identity_from_disk()
	var repaired: bool = false

	if not _local_identity_is_valid(disk_identity):
		disk_identity = _build_local_identity(context)
		repaired = true
		_write_local_identity_to_disk(disk_identity)

	local_identity_context = disk_identity.duplicate(true)
	_commit_state()

	last_report = {
		"schema": "eralife.identity.local_resolution_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "local_identity_resolved",
		"identity_context": emit_identity_context({
			"source": str(context.get("source", "resolve_local_identity"))
		}),
		"repaired": repaired,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func attach_cloud_identity_async(cloud_payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var provider: String = str(cloud_payload.get("provider", "eralife")).strip_edges()
	var cloud_id: String = str(cloud_payload.get("cloud_identity_id", cloud_payload.get("identity_id", ""))).strip_edges()
	var attach_state: String = "pending"

	if cloud_id == "":
		attach_state = "guest_local_only"

	cloud_identity_context = {
		"schema": "eralife.identity.cloud_attachment",
		"version": CONTRACT_VERSION,
		"provider": provider,
		"cloud_identity_id": cloud_id,
		"state": attach_state,
		"nonblocking": true,
		"ui_mutation_allowed": false,
		"requested_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	_commit_state()
	last_report = {
		"schema": "eralife.identity.cloud_attach_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": attach_state,
		"cloud_identity": cloud_identity_context.duplicate(true),
		"nonblocking": true
	}
	return last_report.duplicate(true)

func emit_identity_context(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if local_identity_context.is_empty():
		var resolved: Dictionary = resolve_local_identity({
			"source": str(context.get("source", "emit_identity_context"))
		})
		var resolved_context: Dictionary = _safe_dictionary(resolved.get("identity_context", {}))
		if not resolved_context.is_empty():
			return resolved_context

	if cloud_identity_context.is_empty():
		cloud_identity_context = _read_account_session_from_disk()

	var cloud_id: String = str(cloud_identity_context.get("cloud_identity_id", "")).strip_edges()
	var is_guest: bool = cloud_id == ""

	return {
		"schema": IDENTITY_CONTEXT_SCHEMA,
		"version": CONTRACT_VERSION,
		"identity_id": str(local_identity_context.get("identity_id", "")),
		"local_identity_id": str(local_identity_context.get("identity_id", "")),
		"device_identity_id": str(local_identity_context.get("device_identity_id", "")),
		"cloud_identity_id": cloud_id,
		"account_username": str(cloud_identity_context.get("username", "")),
		"account_email": str(cloud_identity_context.get("email", "")),
		"cloud_state": str(cloud_identity_context.get("state", "guest_local_only" if is_guest else "attached")),
		"account_logged_in": not is_guest,
		"is_guest": is_guest,
		"created_at_ms": int(local_identity_context.get("created_at_ms", 0)),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "IdentityContractEngine",
			"ui_mutation_allowed": false,
			"save_key": "identity_context",
		}
	}
func create_or_attach_eralife_account(context: Dictionary = {}) -> Dictionary:
	return send_signup_verification(context)

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
		== "identity.send_signup_verification"
	):
		return send_signup_verification(
			envelope
		)

	if command_id == "identity.complete_signup":
		return complete_signup(
			envelope
		)

	if (
		command_id
		== "identity.login_eralife_account"
	):
		return login_eralife_account(
			envelope
		)

	if (
		command_id
		== "identity.disconnect_eralife_account"
	):
		return disconnect_eralife_account(
			envelope
		)

	if (
		command_id
		== "identity.create_or_attach_eralife_account"
	):
		return create_or_attach_eralife_account(
			envelope
		)

	if (
		command_id
		== "identity.queue_life_packet_transfer_email"
	):
		return queue_life_packet_transfer_email(
			envelope
		)

	if (
		command_id
		== "identity.change_account_username"
	):
		return change_account_username(
			envelope
		)

	if command_id == "identity.emit_context":
		return {
			"success": true,
			"mode": (
				"identity_context_emitted"
			),
			"identity_context": (
				emit_identity_context(
					envelope
				)
			)
		}

	return {
		"success": false,
		"reason": (
			"IdentityContractEngine did not recognize command."
		),
		"command": command_id
	}
func change_account_username(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	_ensure_identity_dir()

	var identity_context: Dictionary = (
		emit_identity_context({
			"source": (
				"change_account_username"
			)
		})
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return _account_fail(
			"account_required",
			"Sign into an ErAccount before changing its username."
		)

	var old_username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var new_username: String = str(
		context.get(
			"new_username",
			context.get(
				"username",
				""
			)
		)
	).strip_edges()
	var validation: Dictionary = (
		_validate_username_only(
			new_username
		)
	)

	if not bool(
		validation.get(
			"success",
			false
		)
	):
		return validation

	var old_key: String = (
		old_username.to_lower()
	)
	var new_key: String = (
		new_username.to_lower()
	)

	if old_key == new_key:
		return _account_fail(
			"username_unchanged",
			"That is already your ErAccount username."
		)

	var registry: Dictionary = (
		_read_account_registry()
	)
	var accounts: Dictionary = (
		_safe_dictionary(
			registry.get(
				"accounts",
				{}
			)
		)
	)

	if not accounts.has(old_key):
		return _account_fail(
			"account_missing",
			"The active ErAccount could not be found in the account registry."
		)

	if accounts.has(new_key):
		return _account_fail(
			"username_taken",
			"That username already belongs to another ErAccount."
		)

	var account: Dictionary = (
		_safe_dictionary(
			accounts.get(
				old_key,
				{}
			)
		)
	)
	var now_ms: int = int(
		Time.get_unix_time_from_system()
		* 1000.0
	)
	var history: Array = (
		_trim_identity_timestamp_history(
			_safe_array(
				account.get(
					"username_change_history_ms",
					[]
				)
			),
			now_ms,
			14 * 24 * 60 * 60 * 1000
		)
	)

	if history.size() >= 2:
		return _account_fail(
			"username_change_limit_reached",
			"ErAccount usernames may be changed twice every two weeks."
		)

	history.append(now_ms)
	account ["username"] = new_username
	account ["username_change_history_ms"] = (
		history
	)
	account ["updated_at_ms"] = now_ms

	accounts.erase(old_key)
	accounts [new_key] = account.duplicate(true)
	registry ["accounts"] = accounts
	registry ["updated_at_ms"] = now_ms
	_write_account_registry(registry)

	cloud_identity_context = account.duplicate(true)
	_write_account_session_to_disk(
		cloud_identity_context
	)

	var migration_reports: Array = []

	for engine_property in [
		"connection_graph_network",
		"eraccount_profile_contract_engine",
		"network_notes_contract_engine",
		"public_feed_contract_engine",
		"messenger_contract_engine",
		"mailbox_contract_engine",
		"self_host_network_contract_engine"
	]:
		_migrate_username_through_authority(
			str(engine_property),
			old_username,
			new_username,
			migration_reports
		)

	_commit_state()

	last_report = {
		"schema": (
			"eralife.identity.username_change_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"eraccount_username_changed"
		),
		"message": (
			"ErAccount username changed to @%s."
			% new_username
		),
		"old_username": old_username,
		"new_username": new_username,
		"identity_context": (
			emit_identity_context({
				"source": (
					"username_change_complete"
				)
			})
		),
		"change_limits": {
			"maximum": 2,
			"remaining": maxi(
				0,
				2 - history.size()
			),
			"window_days": 14
		},
		"migration_reports": migration_reports,
		"created_at_ms": now_ms,
		"contract_mesh": {
			"source_of_truth": (
				"IdentityContractEngine"
			),
			"social_authorities_migrate_references": (
				true
			),
			"ui_mutation_allowed": false
		}
	}

	return last_report.duplicate(true)


func _validate_username_only(
	username: String
) -> Dictionary:
	var clean_username: String = (
		username.strip_edges()
	)

	if clean_username.length() < 3:
		return _account_fail(
			"username_too_short",
			"Username must be at least 3 characters."
		)

	if clean_username.length() > 24:
		return _account_fail(
			"username_too_long",
			"Username cannot exceed 24 characters."
		)

	for character_index in range(
		clean_username.length()
	):
		var code: int = (
			clean_username.unicode_at(
				character_index
			)
		)
		var is_number: bool = (
			code >= 48
			and code <= 57
		)
		var is_upper: bool = (
			code >= 65
			and code <= 90
		)
		var is_lower: bool = (
			code >= 97
			and code <= 122
		)
		var is_underscore: bool = (
			code == 95
		)
		var is_period: bool = (
			code == 46
		)

		if not (
			is_number
			or is_upper
			or is_lower
			or is_underscore
			or is_period
		):
			return _account_fail(
				"username_character_invalid",
				"Usernames may contain letters, numbers, underscores, and periods."
			)

	return {
		"success": true
	}


func _trim_identity_timestamp_history(
	history: Array,
	now_ms: int,
	window_ms: int
) -> Array:
	var out: Array = []

	for raw_timestamp in history:
		var timestamp: int = int(
			raw_timestamp
		)

		if (
			timestamp > 0
			and now_ms - timestamp < window_ms
		):
			out.append(timestamp)

	return out


func _migrate_username_through_authority(
	engine_property: String,
	old_username: String,
	new_username: String,
	migration_reports: Array
) -> void:
	if (
		gs == null
		or not (engine_property in gs)
	):
		return

	var engine = gs.get(
		engine_property
	)

	if (
		engine == null
		or not engine.has_method(
			"migrate_username"
		)
	):
		return

	var raw_report: Variant = engine.call(
		"migrate_username",
		old_username,
		new_username,
		{
			"source": (
				"identity_username_change"
			),
			"identity_context": (
				emit_identity_context({
					"source": (
						"identity_username_migration"
					)
				})
			)
		}
	)

	if typeof(raw_report) == TYPE_DICTIONARY:
		migration_reports.append(
			(
				raw_report as Dictionary
			).duplicate(true)
		)
func queue_life_packet_transfer_email(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var life_packet: Dictionary = context.get("life_packet", {}) if typeof(context.get("life_packet", {})) == TYPE_DICTIONARY else {}
	var recipient_email: String = str(context.get("recipient_email", context.get("email", ""))).strip_edges().to_lower()

	if life_packet.is_empty():
		return _account_fail("life_packet_missing", "LifePacket transfer needs a LifePacket.")
	if recipient_email == "":
		return _account_fail("recipient_email_missing", "LifePacket transfer needs a recipient email.")

	if gs == null or not ("email_verification_transport_engine" in gs):
		return _account_fail("email_transport_missing", "Email verification transport is unavailable.")

	if gs.email_verification_transport_engine == null:
		gs.email_verification_transport_engine = EmailVerificationTransportEngine.new(gs)

	if gs.email_verification_transport_engine == null or not gs.email_verification_transport_engine.has_method("queue_life_packet_transfer_email"):
		return _account_fail("email_transport_missing", "Email verification transport is unavailable.")

	return gs.email_verification_transport_engine.queue_life_packet_transfer_email(life_packet, recipient_email, {
		"source": "identity_queue_life_packet_transfer_email",
		"sender_identity_context": emit_identity_context({ "source": "life_packet_transfer"})
	})
func send_signup_verification(context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_identity_dir()

	var username: String = str(context.get("username", "")).strip_edges()
	var email: String = str(context.get("email", "")).strip_edges().to_lower()
	var password: String = str(context.get("password", ""))

	var validation: Dictionary = _validate_signup_fields(username, email, password)
	if not bool(validation.get("success", false)):
		return validation

	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	if accounts.has(username.to_lower()):
		return _account_fail("username_taken", "That username already exists. Press L to log in.")

	var local_id: String = str(local_identity_context.get("identity_id", "")).strip_edges()
	if local_id == "":
		resolve_local_identity({ "source": "send_signup_verification"})
		local_id = str(local_identity_context.get("identity_id", "")).strip_edges()

	var transport_report: Dictionary = {}
	if gs != null and "email_verification_transport_engine" in gs:
		if gs.email_verification_transport_engine == null:
			gs.email_verification_transport_engine = EmailVerificationTransportEngine.new(gs)
		if gs.email_verification_transport_engine != null and gs.email_verification_transport_engine.has_method("send_verification_email"):
			transport_report = gs.email_verification_transport_engine.send_verification_email({
				"username": username,
				"email": email,
				"identity_id": local_id
			}, {
				"source": "identity_signup",
				"permission_scope": "bind_reality_to_identity"
			})

	if transport_report.is_empty():
		return _account_fail("verification_transport_missing", "Email verification transport is unavailable.")

	if not bool(transport_report.get("success", false)):
		return transport_report

	var code: String = str(transport_report.get("verification_code", "")).strip_edges()
	if code == "":
		return _account_fail("verification_code_missing", "Verification transport did not return a code.")

	var pending: Dictionary = {
		"schema": "eralife.identity.pending_signup",
		"version": CONTRACT_VERSION,
		"username": username,
		"email": email,
		"password_hash": _password_hash(password),
		"verification_code": code,
		"verification_transport": transport_report.duplicate(true),
		"permission_scope": "bind_reality_to_identity",
		"created_at_ms": int(Time.get_ticks_msec()),
		"expires_at_ms": int(transport_report.get("expires_at_ms", int(Time.get_ticks_msec()) + 600000))
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["pending_eralife_account_signup"] = pending.duplicate(true)

	return {
		"schema": "eralife.identity.signup_verification_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "verification_sent",
		"message": "2-step verification sent. Enter the code to finish creating your ErAccount.",
		"developer_verification_code": code,
		"verification_transport": transport_report.duplicate(true),
		"permission_scope": "bind_reality_to_identity",
		"created_at_ms": int(Time.get_ticks_msec())
	}

func complete_signup(context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_identity_dir()

	var pending: Dictionary = {}
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		pending = _safe_dictionary(gs.scenario_state.get("pending_eralife_account_signup", {}))

	if pending.is_empty():
		return _account_fail("verification_missing", "Send a 2-step verification code first.")

	var incoming_code: String = str(context.get("verification_code", "")).strip_edges()
	if incoming_code == "" or incoming_code != str(pending.get("verification_code", "")):
		return _account_fail("verification_failed", "That 2-step verification code is not correct.")

	if int(Time.get_ticks_msec()) > int(pending.get("expires_at_ms", 0)):
		return _account_fail("verification_expired", "That 2-step verification code expired. Send a new one.")

	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	var username_key: String = str(pending.get("username", "")).strip_edges().to_lower()

	if accounts.has(username_key):
		return _account_fail("username_taken", "That username already exists. Press L to log in.")

	var local_id: String = str(local_identity_context.get("identity_id", "")).strip_edges()
	if local_id == "":
		resolve_local_identity({ "source": "complete_signup"})
		local_id = str(local_identity_context.get("identity_id", "")).strip_edges()

	var account_id: String = _uuid_like("eraccount", "%s:%s:%d" % [
		username_key,
		local_id,
		int(Time.get_unix_time_from_system())
	])

	var account: Dictionary = {
		"schema": ACCOUNT_SESSION_SCHEMA,
		"version": CONTRACT_VERSION,
		"provider": "eralife",
		"cloud_identity_id": account_id,
		"identity_id": account_id,
		"local_identity_id": local_id,
		"username": str(pending.get("username", "")),
		"username_change_history_ms": [],
		"email": str(pending.get("email", "")),
		"password_hash": str(pending.get("password_hash", "")),
		"verified_permission_scope": str(pending.get("permission_scope", "bind_reality_to_identity")),
		"verification_transport": pending.get("verification_transport", {}) if typeof(pending.get("verification_transport", {})) == TYPE_DICTIONARY else {},
		"state": "attached_offline_account",
		"account_logged_in": true,
		"nonblocking": true,
		"ui_mutation_allowed": false,
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	accounts [username_key] = account.duplicate(true)
	registry ["schema"] = "eralife.identity.account_registry"
	registry ["version"] = CONTRACT_VERSION
	registry ["accounts"] = accounts.duplicate(true)
	_write_account_registry(registry)

	cloud_identity_context = account.duplicate(true)
	_write_account_session_to_disk(cloud_identity_context)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state.erase("pending_eralife_account_signup")

	_commit_state()

	last_report = {
		"schema": "eralife.identity.account_attach_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "signup_complete",
		"message": "ErAccount connected. Your portable lives are ready.",
		"identity_context": emit_identity_context({ "source": "complete_signup"}),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "IdentityContractEngine",
			"verification_owner": "EmailVerificationTransportEngine",
		}
	}
	return last_report.duplicate(true)

func login_eralife_account(context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_identity_dir()

	var username_key: String = str(context.get("username", "")).strip_edges().to_lower()
	var password: String = str(context.get("password", ""))

	if username_key == "":
		return _account_fail("username_missing", "Enter your username.")
	if password == "":
		return _account_fail("password_missing", "Enter your password.")

	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	if not accounts.has(username_key):
		return _account_fail("account_missing", "No ErAccount exists for that username.")

	var account: Dictionary = _safe_dictionary(accounts.get(username_key, {}))
	if str(account.get("password_hash", "")) != _password_hash(password):
		return _account_fail("password_incorrect", "That password is not correct.")

	account ["state"] = "attached_offline_account"
	account ["account_logged_in"] = true
	account ["updated_at_ms"] = int(Time.get_ticks_msec())

	cloud_identity_context = account.duplicate(true)
	_write_account_session_to_disk(cloud_identity_context)
	_commit_state()

	last_report = {
		"schema": "eralife.identity.account_login_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "login_complete",
		"message": "ErAccount connected. Your portable lives are ready.",
		"identity_context": emit_identity_context({ "source": "login_eralife_account"}),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func disconnect_eralife_account(_context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	cloud_identity_context = {}
	if FileAccess.file_exists(ACCOUNT_SESSION_PATH):
		DirAccess.remove_absolute(ACCOUNT_SESSION_PATH)

	_commit_state()

	last_report = {
		"schema": "eralife.identity.account_disconnect_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "account_disconnected",
		"message": "ErAccount disconnected. You are playing as a guest.",
		"identity_context": emit_identity_context({ "source": "disconnect_eralife_account"}),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func _validate_signup_fields(username: String, email: String, password: String) -> Dictionary:
	if username.strip_edges().length() < 3:
		return _account_fail("username_too_short", "Username must be at least 3 characters.")
	if email.find("@") == -1 or email.find(".") == -1:
		return _account_fail("email_invalid", "Enter a valid email.")
	if password.length() < 5:
		return _account_fail("password_too_short", "Password must be at least 5 characters.")
	if not _password_has_special_character(password):
		return _account_fail("password_missing_special", "Password needs at least one special character.")
	return { "success": true}

func _password_has_special_character(password: String) -> bool:
	for i in range(password.length()):
		var code:= password.unicode_at(i)
		var is_number:= code >= 48 and code <= 57
		var is_upper:= code >= 65 and code <= 90
		var is_lower:= code >= 97 and code <= 122
		if not is_number and not is_upper and not is_lower:
			return true
	return false

func _password_hash(password: String) -> String:
	return "pw_%d" % abs(int(hash("eralife_account_password:%s" % password)))

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

func _write_account_registry(registry: Dictionary) -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(ACCOUNT_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(registry, "\t"))
	file.close()

func _account_fail(reason_id: String, message: String) -> Dictionary:
	return {
		"schema": "eralife.identity.account_error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"created_at_ms": int(Time.get_ticks_msec())
	}
func _read_account_session_from_disk() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNT_SESSION_PATH):
		return {}
	var file:= FileAccess.open(ACCOUNT_SESSION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if str(data.get("cloud_identity_id", "")).strip_edges() != "":
			return data
	return {}

func _write_account_session_to_disk(account_session: Dictionary) -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(ACCOUNT_SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(account_session, "\t"))
	file.close()

func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"identity_profiles": identity_profiles.duplicate(true),
		"identity_event_ledger": identity_event_ledger.duplicate(true),
		"local_identity_context": local_identity_context.duplicate(true),
		"cloud_identity_context": cloud_identity_context.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	identity_profiles = _safe_dictionary(data.get("identity_profiles", {}))
	identity_event_ledger = _safe_array(data.get("identity_event_ledger", []))
	local_identity_context = _safe_dictionary(data.get("local_identity_context", {}))
	cloud_identity_context = _safe_dictionary(data.get("cloud_identity_context", {}))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_repair_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "identity_contract_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"profile_count": identity_profiles.size(),
		"event_count": identity_event_ledger.size(),
		"local_identity_present": not local_identity_context.is_empty(),
		"repaired": true
	}
	return last_report.duplicate(true)

func refresh_identity_for_actor(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(actor.id)
	var trait_profile: Dictionary = {}
	if gs != null and "traits_contract_engine" in gs and gs.traits_contract_engine != null:
		trait_profile = gs.traits_contract_engine.ensure_actor_traits(actor, {
			"source": "identity_refresh"
		})

	var before: Dictionary = _safe_dictionary(identity_profiles.get(str(actor_id), {}))
	var after: Dictionary = _build_identity_profile(actor, trait_profile, context)
	identity_profiles [str(actor_id)] = after.duplicate(true)

	var event: Dictionary = {
		"schema": "eralife.identity.event_contract",
		"version": CONTRACT_VERSION,
		"id": "identity_event_%d_%d" % [actor_id, int(Time.get_ticks_msec())],
		"actor_id": actor_id,
		"actor_name": _actor_name(actor),
		"before": before.duplicate(true),
		"after": after.duplicate(true),
		"context": context.duplicate(true),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	identity_event_ledger.append(event.duplicate(true))
	if identity_event_ledger.size() > 600:
		identity_event_ledger = identity_event_ledger.slice(identity_event_ledger.size() - 600, identity_event_ledger.size())

	_commit_state()

	last_report = {
		"success": true,
		"mode": "identity_refreshed",
		"actor_id": actor_id,
		"profile": after.duplicate(true),
		"event": event.duplicate(true)
	}
	return last_report.duplicate(true)

func get_identity_profile(actor_id: int) -> Dictionary:
	_ensure_state()
	return _safe_dictionary(identity_profiles.get(str(actor_id), {}))

func _build_identity_profile(actor: Person, trait_profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(actor.id)
	var traits: Dictionary = _safe_dictionary(trait_profile.get("traits", {}))
	var dominant_traits: Array = _dominant_traits(traits, 4)
	var identity_label: String = _identity_label_from_traits(dominant_traits)
	var identity_stage: String = _stage_for_age(actor.age)
	var relationship_dna_summary: Dictionary = _relationship_dna_summary_for_actor(actor_id)

	return {
		"schema": IDENTITY_PROFILE_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": _actor_name(actor),
		"age": int(actor.age),
		"stage": identity_stage,
		"identity_label": identity_label,
		"dominant_traits": dominant_traits.duplicate(true),
		"relationship_dna_summary": relationship_dna_summary.duplicate(true),
		"personality_pressure": _personality_pressure_from_traits_and_dna(dominant_traits, relationship_dna_summary),
		"narrative_summary": _identity_narrative_summary(identity_label, dominant_traits, identity_stage),
		"last_context": context.duplicate(true),
		"updated_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "IdentityContractEngine",
			"trait_owner": "TraitsContractEngine",
			"relationship_dna_owner": "ContractViewLayerContractEngine",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "identity_profiles"
		}
	}

func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	identity_profiles = _safe_dictionary(gs.scenario_state.get("identity_profiles", identity_profiles))
	identity_event_ledger = _safe_array(gs.scenario_state.get("identity_event_ledger", identity_event_ledger))
	local_identity_context = _safe_dictionary(gs.scenario_state.get("local_identity_context", local_identity_context))
	cloud_identity_context = _safe_dictionary(gs.scenario_state.get("cloud_identity_context", cloud_identity_context))

	_repair_state()
	_commit_state()
	if cloud_identity_context.is_empty():
		cloud_identity_context = _read_account_session_from_disk()
func _repair_state() -> void:
	var repaired: Dictionary = {}
	for raw_key in identity_profiles.keys():
		var profile: Dictionary = _safe_dictionary(identity_profiles.get(raw_key, {}))
		if profile.is_empty():
			continue
		var actor_id: int = int(profile.get("actor_id", int(str(raw_key))))
		if actor_id <= 0:
			continue
		profile ["schema"] = str(profile.get("schema", IDENTITY_PROFILE_SCHEMA))
		profile ["version"] = int(profile.get("version", CONTRACT_VERSION))
		repaired [str(actor_id)] = profile

	identity_profiles = repaired

	if identity_event_ledger.size() > 600:
		identity_event_ledger = identity_event_ledger.slice(identity_event_ledger.size() - 600, identity_event_ledger.size())

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["identity_profiles"] = identity_profiles.duplicate(true)
	gs.scenario_state ["identity_event_ledger"] = identity_event_ledger.duplicate(true)
	gs.scenario_state ["local_identity_context"] = local_identity_context.duplicate(true)
	gs.scenario_state ["cloud_identity_context"] = cloud_identity_context.duplicate(true)

func _build_local_identity(context: Dictionary = {}) -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())
	var unix_time: int = int(Time.get_unix_time_from_system())
	var entropy: String = "%d:%d:%d:%s" % [now_ms, unix_time, randi(), str(context)]
	var identity_id: String = _uuid_like("local", entropy)
	return {
		"schema": LOCAL_IDENTITY_SCHEMA,
		"version": CONTRACT_VERSION,
		"identity_id": identity_id,
		"device_identity_id": _uuid_like("device", "%s:%d" % [identity_id, unix_time]),
		"provider": "local_disk",
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms
	}

func _local_identity_is_valid(identity: Dictionary) -> bool:
	var identity_id: String = str(identity.get("identity_id", "")).strip_edges()
	return identity_id != "" and identity_id.length() >= 12

func _read_local_identity_from_disk() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_IDENTITY_PATH):
		return {}
	var file:= FileAccess.open(LOCAL_IDENTITY_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _write_local_identity_to_disk(identity: Dictionary) -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(LOCAL_IDENTITY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(identity, "\t"))
	file.close()

func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _uuid_like(prefix: String, entropy: String) -> String:
	var a: int = abs(int(hash("%s:a:%s" % [prefix, entropy])))
	var b: int = abs(int(hash("%s:b:%s" % [prefix, entropy])))
	var c: int = abs(int(hash("%s:c:%s" % [prefix, entropy])))
	var d: int = abs(int(hash("%s:d:%s" % [prefix, entropy])))
	return "%s_%d_%d_%d_%d_%d" % [
		prefix,
		a % 1000000000,
		b % 1000000,
		c % 1000000,
		d % 1000000,
		abs(int(hash(entropy))) % 1000000000000
	]

func _dominant_traits(traits: Dictionary, limit: int = 4) -> Array:
	var rows: Array = []
	for raw_trait_id in traits.keys():
		var trait_contract: Dictionary = _safe_dictionary(traits.get(raw_trait_id, {}))
		var intensity: float = float(trait_contract.get("intensity", 0.0))
		if intensity < 8.0:
			continue
		rows.append({
			"trait_id": str(raw_trait_id),
			"display_name": str(trait_contract.get("display_name", str(raw_trait_id).replace("_", " ").capitalize())),
			"intensity": intensity,
			"state": str(trait_contract.get("state", "forming")),
			"stage": str(trait_contract.get("stage", "adult"))
		})
	rows.sort_custom(Callable(self, "_sort_trait_rows_by_intensity"))
	if rows.size() > limit:
		rows = rows.slice(0, limit)
	return rows

func _identity_label_from_traits(dominant_traits: Array) -> String:
	if dominant_traits.is_empty():
		return "Unformed"
	var ids: Array = []
	for raw_row in dominant_traits:
		if typeof(raw_row) == TYPE_DICTIONARY:
			ids.append(str((raw_row as Dictionary).get("trait_id", "")))
	if "charming_rogue" in ids:
		return "Charming Rogue"
	if "strategic" in ids and "ambitious" in ids:
		return "Strategic Climber"
	if "guarded" in ids and "loyal" in ids:
		return "Guarded Loyalist"
	if "bitter" in ids and "calculated" in ids:
		return "Cold Strategist"
	if "compassionate" in ids and "loyal" in ids:
		return "Protector"
	if "rebellious" in ids and "independent" in ids:
		return "Independent Rebel"
	if "anxious" in ids and "perfectionist" in ids:
		return "Pressure-Built Perfectionist"
	var first: Dictionary = dominant_traits [0] as Dictionary
	return str(first.get("display_name", "Developing Identity"))

func _identity_narrative_summary(identity_label: String, dominant_traits: Array, stage: String) -> String:
	if dominant_traits.is_empty():
		return "This person is still becoming readable."
	var lead_trait: String = str((dominant_traits [0] as Dictionary).get("display_name", "something")).to_lower()
	match stage:
		"infancy":
			return "Their personality is only a spark, but %s is already showing through." % lead_trait
		"childhood":
			return "Their personality is still soft clay, with %s becoming noticeable." % lead_trait
		"teen":
			return "Their identity is testing itself, and %s is starting to affect their choices." % lead_trait
		"elder":
			return "Their identity is becoming legacy-shaped: %s is what people remember." % identity_label
		_:
			return "They are becoming known as %s, shaped by repeated choices and emotional history." % identity_label

func _personality_pressure_from_traits_and_dna(dominant_traits: Array, dna_summary: Dictionary) -> Dictionary:
	return {
		"social_pressure": float(dna_summary.get("trust_average", 50.0)),
		"defensive_pressure": float(dna_summary.get("suspicion_average", 0.0)) + float(dna_summary.get("fear_average", 0.0)),
		"resentment_pressure": float(dna_summary.get("resentment_average", 0.0)),
		"dominant_trait_count": dominant_traits.size()
	}

func _relationship_dna_summary_for_actor(actor_id: int) -> Dictionary:
	var out: Dictionary = {
		"pair_count": 0,
		"trust_average": 50.0,
		"suspicion_average": 0.0,
		"fear_average": 0.0,
		"resentment_average": 0.0
	}
	if gs == null or not ("contract_view_layer_contract_engine" in gs) or gs.contract_view_layer_contract_engine == null:
		return out
	var dna_index: Dictionary = _safe_dictionary(gs.contract_view_layer_contract_engine.get("relationship_dna_index"))
	var totals: Dictionary = { "trust": 0.0, "suspicion": 0.0, "fear": 0.0, "resentment": 0.0}
	var count: int = 0
	for raw_key in dna_index.keys():
		var key: String = str(raw_key)
		if not key.begins_with("%d:" % actor_id):
			continue
		var dna: Dictionary = _safe_dictionary(dna_index.get(raw_key, {}))
		if dna.is_empty():
			continue
		totals ["trust"] += float(dna.get("trust", 50.0))
		totals ["suspicion"] += float(dna.get("suspicion", 0.0))
		totals ["fear"] += float(dna.get("fear", 0.0))
		totals ["resentment"] += float(dna.get("resentment", 0.0))
		count += 1
	if count <= 0:
		return out
	out ["pair_count"] = count
	out ["trust_average"] = float(totals ["trust"]) / float(count)
	out ["suspicion_average"] = float(totals ["suspicion"]) / float(count)
	out ["fear_average"] = float(totals ["fear"]) / float(count)
	out ["resentment_average"] = float(totals ["resentment"]) / float(count)
	return out

func _sort_trait_rows_by_intensity(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("intensity", 0.0)) > float(b.get("intensity", 0.0))

func _stage_for_age(age_value: int) -> String:
	var age: int = int(age_value)
	if age <= 1:
		return "infancy"
	if age < 13:
		return "childhood"
	if age < 20:
		return "teen"
	if age < 60:
		return "adult"
	return "elder"

func _actor_name(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if full_name != "":
		return full_name
	return str(actor.name).strip_edges()

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []