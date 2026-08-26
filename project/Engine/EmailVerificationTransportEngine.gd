extends Resource
class_name EmailVerificationTransportEngine

const TRANSPORT_SCHEMA:= "eralife.email_verification_transport"
const CONTRACT_VERSION:= 1
const OUTBOX_PATH:= "user://identity/email_transport_outbox.json"
const RATE_LIMIT_PATH:= "user://identity/email_transport_rate_limits.json"

const VERIFY_WINDOW_MS:= 10 * 60 * 1000
const VERIFY_MAX_PER_EMAIL:= 3
const VERIFY_MAX_PER_IDENTITY:= 10
const IDENTITY_WINDOW_MS:= 60 * 60 * 1000

var gs
var outbox: Array = []
var rate_limit_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()

func send_verification_email(request: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var email: String = str(request.get("email", context.get("email", ""))).strip_edges().to_lower()
	var username: String = str(request.get("username", context.get("username", ""))).strip_edges()
	var identity_id: String = str(request.get("identity_id", context.get("identity_id", _identity_id_from_game_state()))).strip_edges()

	if email == "" or email.find("@") == -1 or email.find(".") == -1:
		return _fail("email_invalid", "Enter a valid email before requesting verification.", request, context)

	var rate_report: Dictionary = _claim_rate_limit(email, identity_id)
	if not bool(rate_report.get("success", false)):
		return rate_report

	var code: String = _build_verification_code(email, username, identity_id)
	var now_ms: int = int(Time.get_ticks_msec())
	var expires_at_ms: int = now_ms + VERIFY_WINDOW_MS

	var email_record: Dictionary = {
		"schema": "eralife.email.outbox_record",
		"version": CONTRACT_VERSION,
		"kind": "identity_verification",
		"to_email": email,
		"username": username,
		"identity_id": identity_id,
		"subject": "Your ErAccount verification code",
		"body_text": "Your ErAccount verification code is %s. This code binds portable reality permissions to your identity. It expires in 10 minutes." % code,
		"verification_code": code,
		"expires_at_ms": expires_at_ms,
		"transport_mode": "local_simulated_email_backend",
		"created_at_ms": now_ms
	}

	outbox.append(email_record)
	_trim_outbox()
	_write_outbox()
	_write_rate_limits()

	last_report = {
		"schema": "eralife.email.verification_send_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "verification_email_queued_locally",
		"message": "2-step verification queued. Enter the code to finish creating your ErAccount.",
		"to_email": email,
		"verification_code": code,
		"developer_verification_code": code,
		"expires_at_ms": expires_at_ms,
		"transport_mode": "local_simulated_email_backend",
		"rate_limit": rate_report.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "EmailVerificationTransportEngine",
			"ui_mutation_allowed": false
		}
	}
	_commit_state()
	return last_report.duplicate(true)

func queue_life_packet_transfer_email(life_packet: Dictionary = {}, recipient_email: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var email: String = str(recipient_email).strip_edges().to_lower()
	if email == "" or email.find("@") == -1 or email.find(".") == -1:
		return _fail("recipient_email_invalid", "Enter a valid recipient email.", life_packet, context)

	var sender_identity_id: String = _identity_id_from_game_state()
	var life_id: String = str(life_packet.get("life_id", context.get("life_id", ""))).strip_edges()
	if life_id == "":
		return _fail("life_id_missing", "LifePacket transfer needs a life_id.", life_packet, context)

	var claim_token: String = _build_claim_token(life_id, email, sender_identity_id)
	var claim_link: String = "eralife://life/claim/%s" % claim_token

	var email_record: Dictionary = {
		"schema": "eralife.email.outbox_record",
		"version": CONTRACT_VERSION,
		"kind": "life_packet_transfer",
		"to_email": email,
		"subject": "You received a life in EraLife",
		"body_text": "You received a life in EraLife. Open this claim link to Play, Observe, or Fork: %s" % claim_link,
		"claim_link": claim_link,
		"claim_token": claim_token,
		"life_id": life_id,
		"sender_identity_id": sender_identity_id,
		"life_metadata": {
			"life_id": life_id,
			"origin_id": str(life_packet.get("origin_id", "")),
			"fork_id": str(life_packet.get("fork_id", "")),
			"owner_identity_id": str(life_packet.get("owner_identity_id", life_packet.get("identity_id", "")))
		},
		"available_entry_modes": ["play", "observe", "fork"],
		"transport_mode": "local_simulated_email_backend",
		"created_at_ms": int(Time.get_ticks_msec())
	}

	outbox.append(email_record)
	_trim_outbox()
	_write_outbox()

	last_report = {
		"schema": "eralife.email.life_packet_transfer_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "life_packet_transfer_email_queued",
		"message": "LifePacket transfer email queued locally.",
		"recipient_email": email,
		"claim_link": claim_link,
		"claim_token": claim_token,
		"life_id": life_id,
		"contract_mesh": {
			"source_of_truth": "EmailVerificationTransportEngine",
			"ui_mutation_allowed": false
		}
	}
	_commit_state()
	return last_report.duplicate(true)

func export_outbox() -> Dictionary:
	_ensure_state()
	return {
		"schema": TRANSPORT_SCHEMA,
		"version": CONTRACT_VERSION,
		"outbox": outbox.duplicate(true),
		"rate_limit_registry": rate_limit_registry.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "email.send_verification" or command_id == "email_transport.send_verification":
		return send_verification_email(envelope, envelope)

	if command_id == "email.queue_life_packet_transfer" or command_id == "email_transport.queue_life_packet_transfer":
		var life_packet: Dictionary = envelope.get("life_packet", {}) if typeof(envelope.get("life_packet", {})) == TYPE_DICTIONARY else {}
		return queue_life_packet_transfer_email(life_packet, str(envelope.get("recipient_email", envelope.get("email", ""))), envelope)

	if command_id == "email.export_outbox" or command_id == "email_transport.export_outbox":
		return {
			"success": true,
			"mode": "email_outbox_exported",
			"email_transport": export_outbox()
		}

	return _fail("unknown_email_transport_command", "Email transport did not recognize command.", envelope, envelope)

func _ensure_state() -> void:
	outbox = _safe_array(_read_json_dictionary(OUTBOX_PATH).get("outbox", outbox))
	rate_limit_registry = _safe_dictionary(_read_json_dictionary(RATE_LIMIT_PATH).get("rate_limit_registry", rate_limit_registry))
	_commit_state()

func _claim_rate_limit(email: String, identity_id: String) -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())
	var email_key: String = "email:%s" % email
	var identity_key: String = "identity:%s" % identity_id

	var email_bucket: Array = _fresh_hits(_safe_array(rate_limit_registry.get(email_key, [])), now_ms, VERIFY_WINDOW_MS)
	var identity_bucket: Array = _fresh_hits(_safe_array(rate_limit_registry.get(identity_key, [])), now_ms, IDENTITY_WINDOW_MS)

	if email_bucket.size() >= VERIFY_MAX_PER_EMAIL:
		return _fail("email_rate_limited", "Too many verification emails were requested for that email. Wait a few minutes.", { "email": email}, {})
	if identity_bucket.size() >= VERIFY_MAX_PER_IDENTITY:
		return _fail("identity_rate_limited", "Too many verification emails were requested from this device. Wait before trying again.", { "identity_id": identity_id}, {})

	email_bucket.append(now_ms)
	identity_bucket.append(now_ms)
	rate_limit_registry [email_key] = email_bucket
	rate_limit_registry [identity_key] = identity_bucket

	return {
		"success": true,
		"mode": "rate_limit_claimed",
		"email_hits": email_bucket.size(),
		"identity_hits": identity_bucket.size()
	}

func _fresh_hits(hits: Array, now_ms: int, window_ms: int) -> Array:
	var out: Array = []
	for raw_hit in hits:
		var hit_ms: int = int(raw_hit)
		if now_ms - hit_ms <= window_ms:
			out.append(hit_ms)
	return out

func _build_verification_code(email: String, username: String, identity_id: String) -> String:
	var material: String = "%s:%s:%s:%d:%d" % [
		email,
		username,
		identity_id,
		int(Time.get_ticks_msec()),
		int(Time.get_ticks_usec())
	]
	return "%06d" % int(abs(hash(material)) % 1000000)

func _build_claim_token(life_id: String, email: String, sender_identity_id: String) -> String:
	var material: String = "%s:%s:%s:%d:%d" % [
		life_id,
		email,
		sender_identity_id,
		int(Time.get_ticks_msec()),
		int(Time.get_ticks_usec())
	]
	return "claim_%d_%d" % [
		abs(int(hash(material))) % 1000000000,
		abs(int(hash("eralife:%s" % material))) % 1000000000
	]

func _identity_id_from_game_state() -> String:
	if gs == null:
		return ""
	if "identity_contract_engine" in gs and gs.identity_contract_engine != null and gs.identity_contract_engine.has_method("emit_identity_context"):
		var identity_context: Dictionary = gs.identity_contract_engine.emit_identity_context({ "source": "email_transport_identity_lookup"})
		return str(identity_context.get("identity_id", ""))
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var local_identity: Dictionary = gs.scenario_state.get("local_identity_context", {}) if typeof(gs.scenario_state.get("local_identity_context", {})) == TYPE_DICTIONARY else {}
		return str(local_identity.get("identity_id", ""))
	return ""

func _trim_outbox() -> void:
	if outbox.size() > 500:
		outbox = outbox.slice(outbox.size() - 500, outbox.size())

func _write_outbox() -> void:
	_ensure_identity_dir()
	_write_json_dictionary(OUTBOX_PATH, {
		"schema": TRANSPORT_SCHEMA,
		"version": CONTRACT_VERSION,
		"outbox": outbox.duplicate(true)
	})

func _write_rate_limits() -> void:
	_ensure_identity_dir()
	_write_json_dictionary(RATE_LIMIT_PATH, {
		"schema": "eralife.email_transport.rate_limits",
		"version": CONTRACT_VERSION,
		"rate_limit_registry": rate_limit_registry.duplicate(true)
	})

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["email_verification_transport_outbox"] = outbox.duplicate(true)
	gs.scenario_state ["email_verification_transport_rate_limits"] = rate_limit_registry.duplicate(true)
	gs.scenario_state ["last_email_verification_transport_report"] = last_report.duplicate(true)

func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("identity"):
		root.make_dir("identity")

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file:= FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _write_json_dictionary(path: String, data: Dictionary) -> void:
	var file:= FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _fail(reason_id: String, message: String, request: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.email_transport.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"request": request.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "EmailVerificationTransportEngine",
		}
	}
	_commit_state()
	return last_report.duplicate(true)