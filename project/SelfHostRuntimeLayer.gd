extends Node
class_name SelfHostRuntimeLayer

const CONTRACT_SCHEMA:= "eralife.self_host_runtime_layer"
const CONTRACT_VERSION:= 1
const CONFIG_PATH:= "user://self_host_config.json"
const DEFAULT_DUCKDNS_INTERVAL_SEC:= 300.0
const MIN_DUCKDNS_INTERVAL_SEC:= 60.0

const REMOTE_SHELL_SCHEMA:= "eralife.remote_shell_bridge"
const REMOTE_SHELL_VERSION:= 1
const DEFAULT_REMOTE_SHELL_BIND_HOST:= "127.0.0.1"
const DEFAULT_REMOTE_SHELL_PORT:= 7821
const REMOTE_SHELL_MAX_BODY_BYTES:= 65536
const REMOTE_SHELL_CLIENT_TIMEOUT_MS:= 15000
const REMOTE_SHELL_MIN_KEY_BYTES:= 32

var active_contract: Dictionary = {}
var local_config: Dictionary = {}
var last_duckdns_report: Dictionary = {}
var last_remote_shell_report: Dictionary = {}
var duckdns_enabled: bool = false
var remote_shell_enabled: bool = false
var update_in_flight: bool = false
var tick_timer: Timer
var http_request: HTTPRequest
var remote_shell_server: TCPServer
var remote_shell_clients: Array = []
var ecl_language_engine: ECLContractLanguageEngine
var discord_server_world_registry: Dictionary = {}
var discord_world_event_registry: Dictionary = {}
var discord_relationship_request_registry: Dictionary = {}
var discord_job_pressure_registry: Dictionary = {}
var eranet_global_world_registry: Dictionary = {}
var eranet_identity_registry: Dictionary = {}
var eranet_cross_world_relationship_registry: Dictionary = {}
var eranet_world_routes: Dictionary = {}
var eranet_global_economy_registry: Dictionary = {}

var eranet_realtime_accumulator_sec: float = 0.0
var eranet_realtime_tick_interval_sec: float = 5.0


var eranet_realtime_cycle_active: bool = false
var eranet_realtime_cycle_elapsed_sec: float = 0.0
var eranet_realtime_cycle_world_ids: Array = []
var eranet_realtime_cycle_cursor: int = 0


const ERANET_REALTIME_WORLD_QUANTUM: int = 1
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_runtime_nodes()
	_ensure_ecl_language_engine()
	load_local_config()
	write_local_config_template()
	EraLog.truth("SELF HOST CONFIG PATH: ", get_local_config_path())
	_ensure_default_remote_shell_config()
	_refresh_remote_shell_from_contract_or_config()
func _ensure_default_remote_shell_config() -> void:
	local_config = load_local_config()

	var changed: bool = false

	if not local_config.has("remote_shell_enabled"):
		local_config ["remote_shell_enabled"] = false
		changed = true

	if not local_config.has(
		"remote_shell_explicit_local_opt_in"
	):
		local_config [
			"remote_shell_explicit_local_opt_in"
		] = false
		changed = true

	if not local_config.has(
		"remote_shell_allow_non_loopback"
	):
		local_config [
			"remote_shell_allow_non_loopback"
		] = false
		changed = true

	if str(
		local_config.get(
			"remote_shell_bind_host",
			""
		)
	).strip_edges() == "":
		local_config ["remote_shell_bind_host"] = (
			DEFAULT_REMOTE_SHELL_BIND_HOST
		)
		changed = true

	if int(
		local_config.get("remote_shell_port", 0)
	) <= 0:
		local_config ["remote_shell_port"] = (
			DEFAULT_REMOTE_SHELL_PORT
		)
		changed = true

	var current_key: String = str(
		local_config.get("remote_shell_key", "")
	).strip_edges()

	if (
		current_key != ""
		and current_key.to_utf8_buffer().size()
		< REMOTE_SHELL_MIN_KEY_BYTES
	):
		local_config ["remote_shell_key"] = ""
		local_config ["remote_shell_enabled"] = false
		local_config [
			"remote_shell_explicit_local_opt_in"
		] = false
		changed = true

	var key_configured: bool = (
		_remote_shell_local_key_is_acceptable(
			local_config
		)
	)
	if bool(
		local_config.get(
			"remote_shell_key_configured",
			false
		)
	) != key_configured:
		local_config ["remote_shell_key_configured"] = (
			key_configured
		)
		changed = true

	if changed:
		local_config ["updated_at_ms"] = int(
			Time.get_ticks_msec()
		)
		_write_json(
			CONFIG_PATH,
			local_config
		)
func _process(delta: float) -> void:
	_poll_remote_shell_bridge()
	_eranet_realtime_tick(delta)

func set_self_host_contract(contract: Dictionary) -> Dictionary:
	active_contract = _sanitize_self_host_contract(contract)
	duckdns_enabled = _should_enable_duckdns(active_contract)
	_refresh_remote_shell_from_contract_or_config()

	var report:= {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"accepted": not active_contract.is_empty(),
		"duckdns_enabled": duckdns_enabled,
		"remote_shell_enabled": remote_shell_enabled,
		"remote_shell": _safe_remote_shell_status(),
		"token_configured_locally": _has_local_duckdns_token(),
		"runtime_id": str(active_contract.get("runtime_id", "")),
		"received_at_ms": int(Time.get_ticks_msec())
	}

	if duckdns_enabled:
		start_duckdns_updater({
			"reason": "self_host_contract_received",
			"immediate": true
		})
	else:
		stop_duckdns_updater("duckdns_not_enabled_by_contract")

	_persist_runtime_status()
	return report
func start_duckdns_updater(options: Dictionary = {}) -> void:
	_ensure_runtime_nodes()

	var interval_sec: float = max(
		MIN_DUCKDNS_INTERVAL_SEC,
		float(options.get("interval_sec", _resolve_duckdns_interval_sec()))
	)

	tick_timer.stop()
	tick_timer.wait_time = interval_sec
	tick_timer.start()

	if bool(options.get("immediate", true)):
		_tick_duckdns_update("immediate_start")

func stop_duckdns_updater(reason: String = "") -> void:
	if tick_timer != null:
		tick_timer.stop()

	last_duckdns_report = {
		"schema": "eralife.duckdns_update_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"stopped": true,
		"reason": reason,
		"stopped_at_ms": int(Time.get_ticks_msec())
	}
	_persist_runtime_status()

func save_local_duckdns_token(token: String) -> Dictionary:
	var clean_token: String = str(token).strip_edges()

	local_config = load_local_config()
	if clean_token == "":
		local_config.erase("duckdns_token")
	else:
		local_config ["duckdns_token"] = clean_token

	local_config ["duckdns_token_configured"] = clean_token != ""
	local_config ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_json(CONFIG_PATH, local_config)

	return {
		"schema": "eralife.self_host_local_config_report",
		"version": CONTRACT_VERSION,
		"duckdns_token_configured": clean_token != "",
		"token_storage": "user://self_host_config.json",
		"token_echoed": false,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func load_local_config() -> Dictionary:
	if FileAccess.file_exists(CONFIG_PATH):
		var f:= FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				local_config = (parsed as Dictionary).duplicate(true)
				return local_config.duplicate(true)

	local_config = {
		"schema": "eralife.self_host_local_config",
		"version": CONTRACT_VERSION,
		"duckdns_token_configured": false,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_write_json(CONFIG_PATH, local_config)
	return local_config.duplicate(true)
func write_local_config_template() -> Dictionary:
	local_config = load_local_config()

	if not local_config.has("duckdns_token"):
		local_config ["duckdns_token"] = ""

	if not local_config.has("remote_shell_enabled"):
		local_config ["remote_shell_enabled"] = false

	if not local_config.has(
		"remote_shell_explicit_local_opt_in"
	):
		local_config [
			"remote_shell_explicit_local_opt_in"
		] = false

	if not local_config.has(
		"remote_shell_allow_non_loopback"
	):
		local_config [
			"remote_shell_allow_non_loopback"
		] = false

	if not local_config.has("remote_shell_bind_host"):
		local_config ["remote_shell_bind_host"] = (
			DEFAULT_REMOTE_SHELL_BIND_HOST
		)

	if not local_config.has("remote_shell_port"):
		local_config ["remote_shell_port"] = (
			DEFAULT_REMOTE_SHELL_PORT
		)

	if not local_config.has("remote_shell_key"):
		local_config ["remote_shell_key"] = ""

	local_config ["duckdns_token_configured"] = (
		str(
			local_config.get("duckdns_token", "")
		).strip_edges() != ""
	)
	local_config ["remote_shell_key_configured"] = (
		_remote_shell_local_key_is_acceptable(
			local_config
		)
	)
	local_config ["instructions"] = (
		"Paste private tokens here locally only. Never commit this file. "
		+ "DuckDNS uses duckdns_token. EraLife Discord Remote Shell requires "
		+ "an explicit local opt-in and a private remote_shell_key of at least "
		+ "32 UTF-8 bytes."
	)
	local_config ["token_storage"] = (
		"user://self_host_config.json"
	)
	local_config ["token_echoed"] = false
	local_config ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_write_json(CONFIG_PATH, local_config)

	return {
		"schema": "eralife.self_host_local_config_template_report",
		"version": CONTRACT_VERSION,
		"config_path": CONFIG_PATH,
		"duckdns_token_configured": bool(
			local_config.get(
				"duckdns_token_configured",
				false
			)
		),
		"remote_shell_enabled": bool(
			local_config.get(
				"remote_shell_enabled",
				false
			)
		),
		"remote_shell_explicit_local_opt_in": bool(
			local_config.get(
				"remote_shell_explicit_local_opt_in",
				false
			)
		),
		"remote_shell_allow_non_loopback": bool(
			local_config.get(
				"remote_shell_allow_non_loopback",
				false
			)
		),
		"remote_shell_key_configured": bool(
			local_config.get(
				"remote_shell_key_configured",
				false
			)
		),
		"token_echoed": false,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func get_local_config_path() -> String:
	return ProjectSettings.globalize_path(CONFIG_PATH)

func reload_local_config() -> Dictionary:
	local_config = load_local_config()
	return {
		"schema": "eralife.self_host_local_config_reload_report",
		"version": CONTRACT_VERSION,
		"config_path": CONFIG_PATH,
		"globalized_path": get_local_config_path(),
		"duckdns_token_configured": _has_local_duckdns_token(),
		"token_echoed": false,
		"reloaded_at_ms": int(Time.get_ticks_msec())
	}
func get_runtime_status() -> Dictionary:
	return {
		"schema": "eralife.self_host_runtime_status",
		"version": CONTRACT_VERSION,
		"active": duckdns_enabled or remote_shell_enabled,
		"duckdns_active": duckdns_enabled,
		"remote_shell_active": remote_shell_enabled,
		"ecl_active": ecl_language_engine != null,
		"update_in_flight": update_in_flight,
		"runtime_id": str(active_contract.get("runtime_id", "")),
		"public_play_url": _read_public_play_url(),
		"duckdns": _safe_duckdns_status(),
		"remote_shell": _safe_remote_shell_status(),
		"ecl": _safe_ecl_status(),
		"eranet": {
			"world_count": eranet_global_world_registry.size(),
			"identity_count": eranet_identity_registry.size(),
			"economy_era_count": eranet_global_economy_registry.size(),
			"routes": eranet_world_routes.duplicate(true),
			"global_economy": eranet_global_economy_registry.duplicate(true),
			"realtime_tick_interval_sec": eranet_realtime_tick_interval_sec
		},
		"last_duckdns_report": last_duckdns_report.duplicate(true),
		"last_remote_shell_report": last_remote_shell_report.duplicate(true),
		"token_configured_locally": _has_local_duckdns_token(),
		"reported_at_ms": int(Time.get_ticks_msec())
	}

func _ensure_runtime_nodes() -> void:
	if http_request == null:
		http_request = HTTPRequest.new()
		http_request.name = "DuckDNSHTTPRequest"
		add_child(http_request)
		if not http_request.request_completed.is_connected(_on_duckdns_update_completed):
			http_request.request_completed.connect(_on_duckdns_update_completed)

	if tick_timer == null:
		tick_timer = Timer.new()
		tick_timer.name = "DuckDNSUpdateTimer"
		tick_timer.one_shot = false
		tick_timer.autostart = false
		add_child(tick_timer)
		if not tick_timer.timeout.is_connected(_on_duckdns_tick):
			tick_timer.timeout.connect(_on_duckdns_tick)

	if remote_shell_server == null:
		remote_shell_server = TCPServer.new()
func save_local_remote_shell_config(
	config: Dictionary = {}
) -> Dictionary:
	local_config = load_local_config()

	if config.has("enabled"):
		local_config ["remote_shell_enabled"] = bool(
			config.get("enabled", false)
		)

	if config.has("explicit_local_opt_in"):
		local_config [
			"remote_shell_explicit_local_opt_in"
		] = bool(
			config.get(
				"explicit_local_opt_in",
				false
			)
		)

	if config.has("allow_non_loopback"):
		local_config [
			"remote_shell_allow_non_loopback"
		] = bool(
			config.get(
				"allow_non_loopback",
				false
			)
		)

	if config.has("bind_host"):
		var bind_host: String = str(
			config.get(
				"bind_host",
				DEFAULT_REMOTE_SHELL_BIND_HOST
			)
		).strip_edges()
		if bind_host == "":
			bind_host = DEFAULT_REMOTE_SHELL_BIND_HOST
		local_config ["remote_shell_bind_host"] = (
			bind_host
		)

	if config.has("port"):
		var port: int = int(
			config.get(
				"port",
				DEFAULT_REMOTE_SHELL_PORT
			)
		)
		if port <= 0:
			port = DEFAULT_REMOTE_SHELL_PORT
		local_config ["remote_shell_port"] = port

	if config.has("remote_shell_key"):
		var remote_shell_key: String = str(
			config.get("remote_shell_key", "")
		).strip_edges()

		if (
			remote_shell_key != ""
			and remote_shell_key.to_utf8_buffer().size()
			< REMOTE_SHELL_MIN_KEY_BYTES
		):
			remote_shell_key = ""
			local_config ["remote_shell_enabled"] = false
			local_config [
				"remote_shell_explicit_local_opt_in"
			] = false

		local_config ["remote_shell_key"] = (
			remote_shell_key
		)

	local_config ["remote_shell_key_configured"] = (
		_remote_shell_local_key_is_acceptable(
			local_config
		)
	)
	local_config ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_write_json(CONFIG_PATH, local_config)
	_refresh_remote_shell_from_contract_or_config()

	return {
		"schema": "eralife.remote_shell_local_config_report",
		"version": REMOTE_SHELL_VERSION,
		"enabled": bool(
			local_config.get(
				"remote_shell_enabled",
				false
			)
		),
		"explicit_local_opt_in": bool(
			local_config.get(
				"remote_shell_explicit_local_opt_in",
				false
			)
		),
		"allow_non_loopback": bool(
			local_config.get(
				"remote_shell_allow_non_loopback",
				false
			)
		),
		"bind_host": str(
			local_config.get(
				"remote_shell_bind_host",
				DEFAULT_REMOTE_SHELL_BIND_HOST
			)
		),
		"port": int(
			local_config.get(
				"remote_shell_port",
				DEFAULT_REMOTE_SHELL_PORT
			)
		),
		"remote_shell_key_configured": bool(
			local_config.get(
				"remote_shell_key_configured",
				false
			)
		),
		"token_echoed": false,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

func _refresh_remote_shell_from_contract_or_config() -> void:
	_ensure_runtime_nodes()
	local_config = load_local_config()

	var remote_contract: Dictionary = (
		_read_remote_shell_contract(
			active_contract
		)
	)

	var contract_allows: bool = true
	if remote_contract.has("enabled"):
		contract_allows = bool(
			remote_contract.get("enabled", false)
		)

	var local_enabled: bool = bool(
		local_config.get(
			"remote_shell_enabled",
			false
		)
	)
	var explicit_local_opt_in: bool = bool(
		local_config.get(
			"remote_shell_explicit_local_opt_in",
			false
		)
	)
	var key_ready: bool = (
		_remote_shell_local_key_is_acceptable(
			local_config
		)
	)
	var should_enable: bool = (
		local_enabled
		and explicit_local_opt_in
		and key_ready
		and contract_allows
	)

	if should_enable:
		start_remote_shell_bridge({
			"reason": "explicit_local_config_refresh",
			"contract": remote_contract.duplicate(true)
		})
	else:
		stop_remote_shell_bridge(
			"remote_shell_local_capability_not_granted"
		)

func start_remote_shell_bridge(
	options: Dictionary = {}
) -> Dictionary:
	_ensure_runtime_nodes()
	local_config = load_local_config()

	var remote_contract: Dictionary = (
		_read_remote_shell_contract(
			active_contract
		)
	)

	if (
		remote_contract.has("enabled")
		and not bool(
			remote_contract.get("enabled", false)
		)
	):
		stop_remote_shell_bridge(
			"remote_shell_contract_denied"
		)
		return {
			"schema": "eralife.remote_shell_start_report",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"error": FAILED,
			"reason": "remote_shell_contract_denied",
			"token_echoed": false,
			"started_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	var local_enabled: bool = bool(
		local_config.get(
			"remote_shell_enabled",
			false
		)
	)
	var explicit_local_opt_in: bool = bool(
		local_config.get(
			"remote_shell_explicit_local_opt_in",
			false
		)
	)
	var key_ready: bool = (
		_remote_shell_local_key_is_acceptable(
			local_config
		)
	)

	if (
		not local_enabled
		or not explicit_local_opt_in
		or not key_ready
	):
		stop_remote_shell_bridge(
			"remote_shell_local_capability_not_granted"
		)
		return {
			"schema": "eralife.remote_shell_start_report",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"error": FAILED,
			"reason": "remote_shell_local_capability_not_granted",
			"token_echoed": false,
			"started_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	var bind_host: String = str(
		local_config.get(
			"remote_shell_bind_host",
			DEFAULT_REMOTE_SHELL_BIND_HOST
		)
	).strip_edges()
	if bind_host == "":
		bind_host = DEFAULT_REMOTE_SHELL_BIND_HOST

	var allow_non_loopback: bool = bool(
		local_config.get(
			"remote_shell_allow_non_loopback",
			false
		)
	)

	if (
		not _remote_shell_bind_host_is_loopback(
			bind_host
		)
		and not allow_non_loopback
	):
		stop_remote_shell_bridge(
			"remote_shell_non_loopback_not_locally_authorized"
		)
		return {
			"schema": "eralife.remote_shell_start_report",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"error": FAILED,
			"bind_host": bind_host,
			"reason": "remote_shell_non_loopback_not_locally_authorized",
			"token_echoed": false,
			"started_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	var port: int = int(
		local_config.get(
			"remote_shell_port",
			DEFAULT_REMOTE_SHELL_PORT
		)
	)
	if port <= 0:
		port = DEFAULT_REMOTE_SHELL_PORT

	if (
		remote_shell_server != null
		and remote_shell_server.is_listening()
	):
		var current_status:= (
			_safe_remote_shell_status()
		)

		if (
			str(
				current_status.get(
					"bind_host",
					""
				)
			) == bind_host
			and int(
				current_status.get(
					"port",
					0
				)
			) == port
		):
			remote_shell_enabled = true
			return current_status

		stop_remote_shell_bridge(
			"restart_for_new_bind_or_port"
		)

	var err: int = remote_shell_server.listen(
		port,
		bind_host
	)
	remote_shell_enabled = err == OK

	last_remote_shell_report = {
		"schema": "eralife.remote_shell_start_report",
		"version": REMOTE_SHELL_VERSION,
		"success": remote_shell_enabled,
		"error": err,
		"bind_host": bind_host,
		"port": port,
		"reason": str(
			options.get("reason", "")
		),
		"token_echoed": false,
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_persist_runtime_status()
	return last_remote_shell_report.duplicate(true)

func stop_remote_shell_bridge(reason: String = "") -> void:
	if remote_shell_server != null and remote_shell_server.is_listening():
		remote_shell_server.stop()

	for row in remote_shell_clients:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var peer: StreamPeerTCP = row.get("peer", null)
		if peer != null:
			peer.disconnect_from_host()

	remote_shell_clients.clear()
	remote_shell_enabled = false

	last_remote_shell_report = {
		"schema": "eralife.remote_shell_stop_report",
		"version": REMOTE_SHELL_VERSION,
		"success": true,
		"stopped": true,
		"reason": reason,
		"stopped_at_ms": int(Time.get_ticks_msec())
	}

	_persist_runtime_status()


func _poll_remote_shell_bridge() -> void:
	if not remote_shell_enabled:
		return
	if remote_shell_server == null:
		return
	if not remote_shell_server.is_listening():
		return

	while remote_shell_server.is_connection_available():
		var peer: StreamPeerTCP = remote_shell_server.take_connection()
		if peer != null:
			remote_shell_clients.append({
				"peer": peer,
				"buffer": PackedByteArray(),
				"connected_at_ms": int(Time.get_ticks_msec())
			})

	var now_ms: int = int(Time.get_ticks_msec())
	for i in range(remote_shell_clients.size() - 1, -1, -1):
		var row_raw: Variant = remote_shell_clients [i]
		if typeof(row_raw) != TYPE_DICTIONARY:
			remote_shell_clients.remove_at(i)
			continue

		var row: Dictionary = row_raw
		var peer: StreamPeerTCP = row.get("peer", null)
		if peer == null:
			remote_shell_clients.remove_at(i)
			continue

		if now_ms - int(row.get("connected_at_ms", now_ms)) > REMOTE_SHELL_CLIENT_TIMEOUT_MS:
			peer.disconnect_from_host()
			remote_shell_clients.remove_at(i)
			continue

		var status: int = peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			remote_shell_clients.remove_at(i)
			continue

		var available_bytes: int = peer.get_available_bytes()
		if available_bytes <= 0:
			continue

		var packet: Array = peer.get_data(available_bytes)
		if packet.size() < 2 or int(packet [0]) != OK:
			_send_remote_shell_error(peer, 400, "tcp_read_failed")
			remote_shell_clients.remove_at(i)
			continue

		var buffer: PackedByteArray = row.get("buffer", PackedByteArray())
		buffer.append_array(packet [1])
		row ["buffer"] = buffer
		remote_shell_clients [i] = row

		var response: PackedByteArray = _try_build_remote_shell_response(buffer)
		if response.is_empty():
			continue

		peer.put_data(response)
		peer.disconnect_from_host()
		remote_shell_clients.remove_at(i)


func _try_build_remote_shell_response(
	buffer: PackedByteArray
) -> PackedByteArray:
	if buffer.size() > REMOTE_SHELL_MAX_BODY_BYTES:
		return _remote_shell_http_response(413, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "request_too_large"
		})

	var raw_text: String = buffer.get_string_from_utf8()
	var header_end: int = raw_text.find("
\n
\n")
	if header_end < 0:
		return PackedByteArray()

	var header_text: String = raw_text.substr(0, header_end)
	var body_text: String = raw_text.substr(header_end + 4)
	var request_line: String = _remote_shell_request_line(header_text)
	var method: String = _remote_shell_request_method(request_line)
	var path: String = _remote_shell_request_path(request_line)

	if method == "OPTIONS":
		return _remote_shell_http_response(204, {})

	if method == "GET" and path in [
		"/",
		"/eralife",
		"/eralife/remote-shell",
		"/eralife/remote-shell/status"
	]:
		return _remote_shell_http_response(200, {
			"schema": "eralife.remote_shell_status_response",
			"version": REMOTE_SHELL_VERSION,
			"success": true,
			"message": "EraLife Remote Shell bridge is online.",
			"status": _safe_remote_shell_status(),
			"runtime": get_runtime_status(),
			"routes": {
				"status": {
					"method": "GET",
					"path": "/eralife/remote-shell/status"
				},
				"command": {
					"method": "POST",
					"path": "/eralife/remote-shell/command",
					"content_type": "application/json"
				}
			}
		})

	if method == "GET" and path in [
		"/eralife/remote-shell/failures",
		"/eralife/remote-shell/failures/reset"
	]:
		# Live failure tally. Counting is always on, so this works in a release build
		# with logging gated off -- you can watch failures accumulate during play
		# instead of scrolling a console. The /reset path clears the counters.
		var failure_report: Dictionary = EraLog.failure_summary()

		if path == "/eralife/remote-shell/failures/reset":
			EraLog.reset_failures()
			failure_report ["reset"] = true

		return _remote_shell_http_response(200, {
			"schema": "eralife.remote_shell_failure_tally_response",
			"version": REMOTE_SHELL_VERSION,
			"success": true,
			"failures": failure_report
		})

	if method == "GET" and path == "/eralife/remote-shell/command":
		return _remote_shell_http_response(200, {
			"schema": "eralife.remote_shell_command_route_diagnostic",
			"version": REMOTE_SHELL_VERSION,
			"success": true,
			"message": "This route is working. Send POST JSON here from the Discord gateway; browser GET is only a diagnostic.",
			"accepted_method": "POST",
			"path": "/eralife/remote-shell/command",
			"status_route": "/eralife/remote-shell/status",
			"token_required": _remote_shell_requires_key(),
			"token_echoed": false,
			"example_envelope": {
				"schema": "eralife.discord_remote_shell_envelope",
				"version": 1,
				"request_id": "local-test",
				"source": {
					"adapter": "manual",
					"platform": "local",
					"user_id": "local_user"
				},
				"world": {
					"container_id": "local.world",
					"mode": "solo"
				},
				"life_identity": {
					"life_node_id": "local.user.local_user"
				},
				"command": {
					"id": "world.status",
					"root": "world",
					"verb": "status",
					"args": {}
				}
			}
		})

	if path != "/eralife/remote-shell/command":
		return _remote_shell_http_response(404, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "route_not_found",
			"method": method,
			"path": path,
			"accepted_routes": [
				"GET /eralife/remote-shell/status",
				"POST /eralife/remote-shell/command"
			]
		})

	if method != "POST":
		return _remote_shell_http_response(405, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "method_not_allowed",
			"method": method,
			"path": path,
			"accepted_method": "POST"
		})

	var content_length: int = _remote_shell_content_length(header_text)
	if content_length <= 0:
		return _remote_shell_http_response(400, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "missing_content_length"
		})

	if content_length > REMOTE_SHELL_MAX_BODY_BYTES:
		return _remote_shell_http_response(413, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "body_too_large"
		})

	if body_text.to_utf8_buffer().size() < content_length:
		return PackedByteArray()

	if not _remote_shell_auth_ok(header_text):
		return _remote_shell_http_response(401, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "remote_shell_key_required_or_invalid",
			"token_echoed": false
		})

	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _remote_shell_http_response(400, {
			"schema": "eralife.remote_shell_error",
			"version": REMOTE_SHELL_VERSION,
			"success": false,
			"reason": "invalid_json"
		})

	var result: Dictionary = _dispatch_remote_shell_envelope(
		parsed as Dictionary
	)
	return _remote_shell_http_response(
		200 if bool(result.get("success", false)) else 422,
		result
	)
func _dispatch_remote_shell_envelope(
	envelope: Dictionary
) -> Dictionary:
	var normalized: Dictionary = _normalize_remote_shell_envelope(
		envelope
	)
	var command_id: String = str(
		normalized.get("command_id", "")
	).strip_edges().to_lower()

	var result: Dictionary = {}

	match command_id:
		"ui.render", "ui.surface", "ui.open":
			result = _remote_shell_ui_render(normalized)

		"ui.action", "ui.interact", "ui.route":
			result = _remote_shell_ui_action(normalized)

		"life.start", "random.life", "random_life":
			result = _remote_shell_start_life(normalized)

		"life.stats":
			result = _remote_shell_life_stats(normalized)

		"life.age":
			result = _remote_shell_life_age(normalized)

		"life.diary":
			result = _remote_shell_life_diary(normalized)

		"life.save", "life.save_life":
			result = _remote_shell_save_life(normalized)

		"life.load", "life.load_life":
			result = _remote_shell_load_life(normalized)

		"life.family":
			result = _remote_shell_life_family(
				normalized,
				"family"
			)

		"life.siblings":
			result = _remote_shell_life_family(
				normalized,
				"siblings"
			)

		"life.grandparents":
			result = _remote_shell_life_family(
				normalized,
				"grandparents"
			)

		"life.greatgrandparents":
			result = _remote_shell_life_family(
				normalized,
				"greatgrandparents"
			)

		"life.relationship":
			result = _remote_shell_life_relationship_action(
				normalized
			)

		"life.school":
			result = _remote_shell_life_school(normalized)

		"life.jobs":
			result = _remote_shell_life_jobs(normalized)

		"bank.status", "bank.balance", "bank.summary":
			result = _remote_shell_bank_status(normalized)

		"bank.deposit":
			result = _remote_shell_bank_action(
				normalized,
				"deposit"
			)

		"bank.withdraw":
			result = _remote_shell_bank_action(
				normalized,
				"withdraw"
			)

		"bank.transfer":
			result = _remote_shell_bank_action(
				normalized,
				"transfer"
			)

		"life.find_date":
			result = _remote_shell_life_find_date(normalized)

		"life.propose":
			result = _remote_shell_life_propose(normalized)

		"life.ask_out":
			result = _remote_shell_life_ask_out(normalized)

		"life.choice":
			result = _remote_shell_life_choice(normalized)

		"life.shop", "life.restaurant", "life.grocery", "life.luxury_shop", "life.inventory":
			result = _remote_shell_life_shop_route(normalized)

		"life.weapon_shop":
			result = _remote_shell_life_weapon_shop(normalized)

		"life.artifacts", "life.artifacts.shop":
			result = _remote_shell_life_artifacts_shop(normalized)

		"life.artifacts.buy":
			result = _remote_shell_life_artifacts_buy(normalized)

		"world.list", "server_world.list":
			result = _remote_shell_world_list(normalized)

		"world.start":
			result = _remote_shell_world_start(normalized)

		"world.join":
			result = _remote_shell_world_join(normalized)

		"world.age":
			result = _remote_shell_world_age(normalized)

		"world.members":
			result = _remote_shell_world_members(normalized)

		"world.feed":
			result = _remote_shell_world_feed(normalized)

		"world.status":
			result = _remote_shell_world_status(normalized)

		"runtime.intent", "reality.intent", "reality.invert", "hero.track_villain", "hero.recruit_sidekick", "hero.recruit_ally", "hero.create_team", "bending.find_duel", "bending.seek_duel":
			result = _remote_shell_causality_inversion_intent(
				normalized
			)

		"ecl.compile":
			result = _remote_shell_ecl_compile(normalized)

		"ecl.queue", "ecl.paste", "ecl.script":
			result = _remote_shell_ecl_queue(normalized)

		"ecl.play", "ecl.run":
			result = _remote_shell_ecl_play(normalized)

		"ecl.status":
			result = _remote_shell_ecl_status(normalized)

		"ecl.clear":
			result = _remote_shell_ecl_clear(normalized)

		_:
			result = _remote_shell_contract_ack(normalized)

	last_remote_shell_report = {
		"schema": "eralife.remote_shell_command_report",
		"version": REMOTE_SHELL_VERSION,
		"success": bool(result.get("success", false)),
		"command_id": command_id,
		"request_id": str(
			normalized.get("request_id", "")
		),
		"world_container_id": str(
			normalized.get("world_container_id", "")
		),
		"life_node_id": str(
			normalized.get("life_node_id", "")
		),
		"handled_at_ms": int(Time.get_ticks_msec())
	}

	_persist_runtime_status()

	return result


func execute_remote_shell_envelope(
	envelope: Dictionary
) -> Dictionary:


	return _dispatch_remote_shell_envelope(envelope)
func _normalize_remote_shell_envelope(envelope: Dictionary) -> Dictionary:
	var source_raw: Variant = envelope.get("source", {})
	var source: Dictionary = source_raw.duplicate(true) if typeof(source_raw) == TYPE_DICTIONARY else {}

	var command_raw: Variant = envelope.get("command", {})
	var command: Dictionary = command_raw.duplicate(true) if typeof(command_raw) == TYPE_DICTIONARY else {}

	var world_raw: Variant = envelope.get("world", {})
	var world: Dictionary = world_raw.duplicate(true) if typeof(world_raw) == TYPE_DICTIONARY else {}

	var life_raw: Variant = envelope.get("life_identity", {})
	var life_identity: Dictionary = life_raw.duplicate(true) if typeof(life_raw) == TYPE_DICTIONARY else {}

	var args: Dictionary = command.get("args", {}).duplicate(true) if typeof(command.get("args", {})) == TYPE_DICTIONARY else {}

	var birth_raw: Variant = envelope.get("birth", {})
	var birth: Dictionary = birth_raw.duplicate(true) if typeof(birth_raw) == TYPE_DICTIONARY else {}

	if birth.is_empty():
		var args_birth_raw: Variant = args.get("birth", {})
		if typeof(args_birth_raw) == TYPE_DICTIONARY:
			birth = (args_birth_raw as Dictionary).duplicate(true)

	var top_level_ecl_script: String = str(envelope.get("ecl_script", envelope.get("script", "")))
	if top_level_ecl_script.strip_edges() != "" and not args.has("script"):
		args ["script"] = top_level_ecl_script

	var root: String = str(command.get("root", envelope.get("root", ""))).strip_edges().to_lower()
	var verb: String = str(command.get("verb", envelope.get("verb", ""))).strip_edges().to_lower()
	var command_id: String = str(command.get("id", envelope.get("command_id", ""))).strip_edges().to_lower()

	if command_id == "" and str(args.get("script", "")).strip_edges() != "":
		root = "ecl"
		verb = "queue"
		command_id = "ecl.queue"

	if command_id == "":
		if root != "" and verb != "":
			command_id = "%s.%s" % [root, verb]
		elif root != "":
			command_id = root
		elif verb != "":
			command_id = verb
	var target_user_ids: Array = []
	var target_ids_raw: Variant = command.get("target_user_ids", [])
	if typeof(target_ids_raw) == TYPE_ARRAY:
		for raw_target in target_ids_raw:
			var clean_target: String = str(raw_target).strip_edges()
			if clean_target != "":
				target_user_ids.append(clean_target)
	return {
		"schema": "eralife.remote_shell_normalized_envelope",
		"version": REMOTE_SHELL_VERSION,
		"request_id": str(envelope.get("request_id", "%d" % int(Time.get_ticks_msec()))),
		"adapter": str(source.get("adapter", "unknown")),
		"platform": str(source.get("platform", "discord")),
		"guild_id": str(source.get("guild_id", "")),
		"channel_id": str(source.get("channel_id", "")),
		"user_id": str(source.get("user_id", "")),
		"username": str(source.get("username", "")),
		"world_container_id": str(world.get("container_id", source.get("guild_id", "solo"))),
		"world_mode": str(world.get("mode", "solo")),
		"life_node_id": str(life_identity.get("life_node_id", source.get("user_id", ""))),
		"external_user_id": str(life_identity.get("external_user_id", source.get("user_id", ""))),
		"target_user_ids": target_user_ids,
		"root": root,
		"verb": verb,
		"command_id": command_id,
		"args": args,
		"birth": birth,
		"raw": envelope.duplicate(true)
	}

func _remote_shell_bank_status(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null or gs_ref.bank_engine == null:
		return _remote_shell_response(false, envelope, "bank.status", "BankEngine is not online yet.", {})
	if gs_ref.bank_engine.has_method("repair_legacy_player_money_mirror"):
		gs_ref.bank_engine.repair_legacy_player_money_mirror()
	var owner_id: String = ""
	if gs_ref.player != null and gs_ref.bank_engine.has_method("owner_key_from_actor"):
		owner_id = gs_ref.bank_engine.owner_key_from_actor(gs_ref.player)
	var summary: Dictionary = gs_ref.bank_engine.get_owner_summary(owner_id, {
		"world_id": str(envelope.get("world_container_id", envelope.get("guild_id", "discord.guild.local"))),
		"user_id": str(envelope.get("user_id", "")),
		"guild_id": str(envelope.get("guild_id", "")),
		"life_node_id": str(envelope.get("life_node_id", ""))
	})
	var text:= "Bank Hub online. Cash: %s | Bank: %s | InterWorld: %s" % [
		str(summary.get("cash_on_hand", 0.0)),
		str(summary.get("bank_balance", 0.0)),
		str(summary.get("interworld_credit", 0.0))
	]
	return _remote_shell_response(true, envelope, "bank.status", text, {
		"bank": summary,
		"player": _remote_shell_player_snapshot(gs_ref)
	})

func _remote_shell_bank_action(envelope: Dictionary, bank_action: String) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null or gs_ref.bank_engine == null:
		return _remote_shell_response(false, envelope, "bank.%s" % bank_action, "BankEngine is not online yet.", {})
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var owner_id: String = ""
	if gs_ref.player != null and gs_ref.bank_engine.has_method("owner_key_from_actor"):
		owner_id = gs_ref.bank_engine.owner_key_from_actor(gs_ref.player)
	var payload:= {
		"action": bank_action,
		"owner_id": owner_id,
		"target_owner_id": str(args.get("target_owner_id", "")),
		"target_world_id": str(args.get("target_world_id", "")),
		"amount": float(args.get("amount", args.get("value", 0.0))),
		"currency": str(args.get("currency", "USD")),
		"transfer_scope": str(args.get("transfer_scope", "local")),
		"governed": true
	}
	var context:= {
		"source": "remote_shell",
		"platform": str(envelope.get("platform", "discord")),
		"world_id": str(envelope.get("world_container_id", envelope.get("guild_id", "discord.guild.local"))),
		"guild_id": str(envelope.get("guild_id", "")),
		"user_id": str(envelope.get("user_id", "")),
		"life_node_id": str(envelope.get("life_node_id", "")),
		"owner_id": owner_id
	}
	var report: Dictionary = gs_ref.bank_engine.request_bank_action(payload, context)
	var text: String = "Bank action completed." if bool(report.get("success", false)) else str(report.get("reason", "Bank action failed."))
	return _remote_shell_response(bool(report.get("success", false)), envelope, "bank.%s" % bank_action, text, {
		"bank_report": report,
		"bank": report.get("summary", {}),
		"player": _remote_shell_player_snapshot(gs_ref)
	})
func _remote_shell_start_life(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.start", "GameState was not found yet.", {})

	var birth_settings: Dictionary = _remote_shell_birth_settings_from_envelope(envelope, gs_ref)

	if gs_ref.has_method("start_random_new_life"):
		if birth_settings.is_empty():
			gs_ref.call("start_random_new_life")
		else:
			gs_ref.call("start_random_new_life", birth_settings)

	var player = gs_ref.player if "player" in gs_ref else null
	if player != null:
		_remote_shell_apply_birth_identity(player, birth_settings)
		_remote_shell_repair_discord_birth_family_class(gs_ref, player, birth_settings)
		_remote_shell_apply_family_weighted_birth_stats(gs_ref, player)

	var snapshot: Dictionary = _remote_shell_player_snapshot(gs_ref)
	var intro_text: String = _remote_shell_build_birth_intro(gs_ref, snapshot, birth_settings)
	var links: Dictionary = _remote_shell_snapshot_links(gs_ref, envelope, birth_settings)
	var snapshot_url: String = str(links.get("self_host", links.get("url", ""))).strip_edges()

	var payload:= {
		"player": snapshot,
		"stats": _remote_shell_stat_bars(snapshot),
		"world": _remote_shell_world_snapshot(gs_ref),
		"birth": birth_settings.duplicate(true),
		"family": _remote_shell_family_payload(gs_ref, "family"),
		"snapshot_links": links,
		"snapshot_url": snapshot_url,
		"theme": {
			"era_color": int(birth_settings.get("era_color", 2829617)),
			"reality_color": int(birth_settings.get("reality_color", 2829617))
		}
	}
	if str(envelope.get("world_mode", "")).strip_edges().to_lower() == "server":
		_remote_shell_sync_server_member_from_player(envelope, snapshot, birth_settings)
	return _remote_shell_response(true, envelope, "life.start", intro_text, payload)
func _remote_shell_birth_settings_from_envelope(envelope: Dictionary, gs_ref) -> Dictionary:
	var birth_raw: Variant = envelope.get("birth", {})
	var birth: Dictionary = birth_raw.duplicate(true) if typeof(birth_raw) == TYPE_DICTIONARY else {}

	var args_raw: Variant = envelope.get("args", {})
	var args: Dictionary = args_raw.duplicate(true) if typeof(args_raw) == TYPE_DICTIONARY else {}

	if birth.is_empty() and not bool(args.get("birth_lobby", false)):
		return {}

	var birth_engine = _ensure_birth_contract_engine(gs_ref)
	if birth_engine == null:
		return {}

	var context:= {
		"source": str(args.get("source", birth.get("source", "discord_birth_lobby"))),
		"fallback_name": str(envelope.get("username", "Someone")),
		"world_mode": str(envelope.get("world_mode", args.get("mode", "solo"))),
		"world_container_id": str(envelope.get("world_container_id", "")),
		"life_node_id": str(envelope.get("life_node_id", "")),
		"external_user_id": str(envelope.get("external_user_id", envelope.get("user_id", "")))
	}

	var settings: Dictionary = birth_engine.normalize_birth_intent({
		"birth": birth,
		"args": args
	}, context)

	settings ["schema"] = "eralife.discord_birth_settings"
	settings ["source"] = "discord_birth_lobby"
	settings ["_god_mode_entry_kind"] = "discord_birth_lobby"

	var raw: Dictionary = envelope.get("raw", {}).duplicate(true) if typeof(envelope.get("raw", {})) == TYPE_DICTIONARY else {}
	var theme: Dictionary = raw.get("theme", {}).duplicate(true) if typeof(raw.get("theme", {})) == TYPE_DICTIONARY else {}

	settings ["era_color"] = int(theme.get("era_color", 2829617))
	settings ["reality_color"] = int(theme.get("reality_color", 2829617))
	settings ["discord_birth_intent"] = raw.duplicate(true)

	settings ["month"] = clamp(int(settings.get("month", 1)), 1, 12)
	# FIX: was clamp(day, 1, 31) with no month awareness, so a birth intent could set
	# February 31st through the remote shell as well as through the UI.
	settings ["day"] = EraUtils.clamp_day_for_month(
		int(settings.get("day", 1)),
		int(settings.get("month", 1)),
		int(settings.get("year", 0))
	)

	if str(settings.get("birthday_text", "")).strip_edges() == "":
		settings ["birthday_text"] = _remote_shell_month_name(int(settings.get("month", 1))) + " " + str(int(settings.get("day", 1)))

	if str(settings.get("zodiac_sign", "")).strip_edges() == "":
		settings ["zodiac_sign"] = _remote_shell_zodiac_sign(int(settings.get("month", 1)), int(settings.get("day", 1)))

	settings ["discord_birth_social_class_forced"] = true

	return settings
func _remote_shell_life_find_date(envelope: Dictionary) -> Dictionary:
	var world: Dictionary = _discord_world_for_envelope(envelope)
	var members: Dictionary = world.get("members", {}).duplicate(true) if typeof(world.get("members", {})) == TYPE_DICTIONARY else {}
	var user_id: String = str(envelope.get("user_id", "")).strip_edges()

	var self_member: Dictionary = members.get(user_id, {}).duplicate(true) if typeof(members.get(user_id, {})) == TYPE_DICTIONARY else {}
	var age: int = int(self_member.get("age", 0))

	if age < 18:
		return _remote_shell_response(false, envelope, "life.find_date", "I have to be 18 before I can use Find Date.", {
			"server_world": world
		})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var date_type: String = str(args.get("type", "npc")).strip_edges().to_lower()

	if date_type == "public":
		var rows: Array = []
		for raw_key in members.keys():
			if str(raw_key) == user_id:
				continue

			var member: Dictionary = members.get(raw_key, {}).duplicate(true) if typeof(members.get(raw_key, {})) == TYPE_DICTIONARY else {}
			if int(member.get("age", 0)) < 18:
				continue

			if bool(member.get("looking_for_date", false)):
				rows.append(member)

		if rows.is_empty():
			self_member ["looking_for_date"] = true
			members [user_id] = self_member
			world ["members"] = members
			discord_server_world_registry [str(world.get("world_id", "discord.guild.local"))] = world

			return _remote_shell_response(true, envelope, "life.find_date", "I am now visible to other public daters in this server world.", {
				"server_world": world,
				"public_dating_pool": []
			})

		return _remote_shell_response(true, envelope, "life.find_date", "People looking for dates in this server world are available.", {
			"server_world": world,
			"public_dating_pool": rows
		})

	var npc_dates: Array = _remote_shell_generate_npc_dates(envelope, world, 3)
	return _remote_shell_response(true, envelope, "life.find_date", "I found some people I could date.", {
		"server_world": world,
		"npc_dates": npc_dates
	})
func _remote_shell_generate_npc_dates(envelope: Dictionary, world: Dictionary, count: int = 3) -> Array:
	var rows: Array = []
	var base_seed: int = abs(hash(str(envelope.get("request_id", "")) + str(Time.get_ticks_msec())))

	var names: Array = [
		"Amara Wells",
		"Naomi Rivers",
		"Jasmine Cole",
		"Selah Brooks",
		"Maya King",
		"Andre Stone",
		"Marcus Vale",
		"Julian Cross",
		"Isaiah Reed"
	]

	for i in range(max(1, count)):
		var idx: int = abs(base_seed + i * 31) % names.size()
		var age: int = 18 + abs(base_seed + i * 17) % 25
		var money: int = abs(base_seed + i * 101) % 250000

		rows.append({
			"schema": "eralife.discord_npc_date_candidate",
			"version": 1,
			"id": "npc_date_%d_%d" % [int(Time.get_ticks_msec()), i],
			"name": str(names [idx]),
			"age": age,
			"bank_account": money,
			"stats": {
				"looks": 35 + abs(base_seed + i * 3) % 66,
				"smarts": 35 + abs(base_seed + i * 5) % 66,
				"kindness": 35 + abs(base_seed + i * 7) % 66,
				"humor": 35 + abs(base_seed + i * 11) % 66
			},
			"era_key": str(world.get("era_key", "Modern")),
			"world_id": str(world.get("world_id", "discord.guild.local"))
		})

	return rows
func _remote_shell_life_propose(envelope: Dictionary) -> Dictionary:
	var world: Dictionary = _discord_world_for_envelope(envelope)
	var world_id: String = str(world.get("world_id", envelope.get("world_container_id", "discord.guild.local"))).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var members: Dictionary = world.get("members", {}).duplicate(true) if typeof(world.get("members", {})) == TYPE_DICTIONARY else {}
	var user_id: String = str(envelope.get("user_id", "")).strip_edges()
	if user_id == "":
		return _remote_shell_response(false, envelope, "life.propose", "I need a Discord user identity before I can propose.", {
			"server_world": world
		})

	var self_member: Dictionary = members.get(user_id, {}).duplicate(true) if typeof(members.get(user_id, {})) == TYPE_DICTIONARY else {}
	if self_member.is_empty():
		self_member = {
			"user_id": user_id,
			"username": str(envelope.get("username", user_id)),
			"life_node_id": str(envelope.get("life_node_id", user_id)),
			"age": 0,
			"online": true,
			"joined_at_ms": int(Time.get_ticks_msec())
		}

	var age: int = int(self_member.get("age", 0))
	if age < 18:
		return _remote_shell_response(false, envelope, "life.propose", "I have to be 18 before I can propose.", {
			"server_world": world,
			"member": self_member
		})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var target_user_ids: Array = envelope.get("target_user_ids", []) if typeof(envelope.get("target_user_ids", [])) == TYPE_ARRAY else []

	var target_user_id: String = ""
	if not target_user_ids.is_empty():
		target_user_id = str(target_user_ids [0]).strip_edges()

	if target_user_id == "":
		target_user_id = str(args.get("target_user_id", args.get("partner_user_id", ""))).strip_edges()

	var target_name: String = str(args.get("target_name", args.get("partner_name", ""))).strip_edges()
	var ring_name: String = str(args.get("ring_name", "proposal ring")).strip_edges()
	if ring_name == "":
		ring_name = "proposal ring"

	if target_user_id != "":
		if target_user_id == user_id:
			return _remote_shell_response(false, envelope, "life.propose", "I cannot propose to myself.", {
				"server_world": world
			})

		if not members.has(target_user_id):
			return _remote_shell_response(false, envelope, "life.propose", "That server member has not joined this EraLife world yet.", {
				"server_world": world,
				"target_user_id": target_user_id
			})

		var decision_id: String = "proposal_%s_%s" % [
			str(envelope.get("request_id", int(Time.get_ticks_msec()))),
			target_user_id
		]

		discord_relationship_request_registry [decision_id] = {
			"schema": "eralife.discord_relationship_request",
			"version": 2,
			"type": "proposal",
			"decision_id": decision_id,
			"asker_user_id": user_id,
			"target_user_id": target_user_id,
			"asker_life_node_id": str(envelope.get("life_node_id", "")),
			"world_container_id": world_id,
			"ring_name": ring_name,
			"created_at_ms": int(Time.get_ticks_msec())
		}

		var proposal_text: String = "<@%s>, <@%s> proposed to you with a %s.\n\nChoose yes or no below." % [
			target_user_id,
			user_id,
			ring_name
		]

		return _remote_shell_response(true, envelope, "life.propose", proposal_text, {
			"server_world": world,
			"decision": {
				"id": decision_id,
				"type": "proposal",
				"choices": [
					{ "id": "accept", "label": "Say Yes"},
					{ "id": "decline", "label": "Say No"}
				]
			}
		})

	if target_name == "":
		target_name = str(self_member.get("partner_name", self_member.get("dating_name", ""))).strip_edges()

	if target_name == "":
		return _remote_shell_response(false, envelope, "life.propose", "I need a partner to propose to. Use Find Date first, or pass target_name / partner_name.", {
			"server_world": world,
			"member": self_member
		})

	self_member ["relationship_status"] = "engaged"
	self_member ["partner_name"] = target_name
	self_member ["engaged_at_ms"] = int(Time.get_ticks_msec())
	self_member ["proposal_ring"] = ring_name
	members [user_id] = self_member
	world ["members"] = members

	var couples: Array = world.get("couples", []) if typeof(world.get("couples", [])) == TYPE_ARRAY else []
	couples.append({
		"asker_user_id": user_id,
		"target_user_id": "",
		"target_name": target_name,
		"status": "engaged",
		"ring_name": ring_name,
		"started_at_ms": int(Time.get_ticks_msec())
	})
	world ["couples"] = couples

	discord_server_world_registry [world_id] = world
	_eranet_touch_identity(envelope, world, self_member)
	_eranet_register_world(world)

	_discord_world_add_feed_event(world_id, "%s proposed to %s with a %s." % [
		str(self_member.get("name", self_member.get("username", user_id))),
		target_name,
		ring_name
	], 16765286)

	return _remote_shell_response(true, envelope, "life.propose", "I proposed to %s with a %s. We are engaged." % [
		target_name,
		ring_name
	], {
		"server_world": world,
		"member": self_member,
		"relationship_status": "engaged",
		"broadcast_events": [
			{
				"title": "💍 EraLife Proposal",
				"text": "%s proposed to %s. They are engaged." % [
					str(self_member.get("name", self_member.get("username", user_id))),
					target_name
				],
				"color": 16765286
			}
		]
	})
func _remote_shell_apply_birth_identity(player: Person, settings: Dictionary) -> void:
	if player == null:
		return

	var birth_settings: Dictionary = settings.duplicate(true)
	var requested_gender: String = str(birth_settings.get("requested_gender", "random")).strip_edges().to_lower()
	var resolved_gender: String = str(birth_settings.get("gender", "")).strip_edges().to_lower()

	if requested_gender not in ["male", "female", "random", ""]:
		requested_gender = "random"

	if resolved_gender == "" and requested_gender in ["male", "female"]:
		resolved_gender = requested_gender

	if resolved_gender in ["male", "female"] and player.get("gender") != null:
		player.gender = resolved_gender

	var clean_country: String = str(birth_settings.get("country", "")).strip_edges()
	var clean_city: String = str(birth_settings.get("city", "")).strip_edges()

	if "birth_month" in player:
		player.birth_month = int(birth_settings.get("month", 1))
	if "birth_day" in player:
		player.birth_day = int(birth_settings.get("day", 1))
	if "birthday_text" in player:
		player.birthday_text = str(birth_settings.get("birthday_text", ""))
	if "zodiac_sign" in player:
		player.zodiac_sign = str(birth_settings.get("zodiac_sign", ""))

	if "home_country" in player and clean_country != "":
		player.home_country = clean_country
	if "birth_country" in player and clean_country != "":
		player.birth_country = clean_country
	if "home_city" in player and clean_city != "":
		player.home_city = clean_city
	if "birth_city" in player and clean_city != "":
		player.birth_city = clean_city

func _remote_shell_repair_discord_birth_family_class(gs_ref, player: Person, settings: Dictionary) -> void:
	if gs_ref == null or player == null:
		return

	var social_class: String = str(settings.get("social_class", "")).strip_edges()
	if social_class == "" or social_class == "Random / Era Default":
		return

	player.social_class = social_class

	var should_clear_royalty: bool = social_class not in ["Royal", "Noble"]

	if should_clear_royalty and "royalty_engine" in gs_ref and gs_ref.royalty_engine != null:
		if gs_ref.royalty_engine.has_method("clear_custom_player_house_royal_identity"):
			gs_ref.royalty_engine.clear_custom_player_house_royal_identity(player)
		elif gs_ref.royalty_engine.has_method("clear_royal_identity"):
			gs_ref.royalty_engine.clear_royal_identity(player)

	var family_members: Array = []
	var seen: Dictionary = {}
	_remote_shell_append_family_for_class_repair(gs_ref, player, family_members, seen)

	for member in family_members:
		if member == null:
			continue

		member.social_class = social_class

		if should_clear_royalty and "royalty_engine" in gs_ref and gs_ref.royalty_engine != null:
			if gs_ref.royalty_engine.has_method("clear_royal_identity"):
				gs_ref.royalty_engine.clear_royal_identity(member)

		var current_job: String = str(member.job).strip_edges() if "job" in member else ""
		if should_clear_royalty and _remote_shell_job_text_is_royal_title(current_job):
			member.job = ""

	if "career_engine" in gs_ref and gs_ref.career_engine != null:
		if gs_ref.career_engine.has_method("reseed_household_jobs_for_class"):
			gs_ref.career_engine.reseed_household_jobs_for_class(player)


func _remote_shell_append_family_for_class_repair(gs_ref, person: Person, out: Array, seen: Dictionary) -> void:
	if gs_ref == null or person == null:
		return

	var pid: int = int(person.id)
	if pid <= 0 or seen.has(pid):
		return

	seen [pid] = true
	out.append(person)

	for raw_parent_id in person.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue

		_remote_shell_append_family_for_class_repair(gs_ref, parent, out, seen)

		for raw_sibling_id in parent.children:
			var sibling: Person = _remote_shell_person_by_id(gs_ref, int(raw_sibling_id))
			if sibling != null:
				_remote_shell_append_family_for_class_repair(gs_ref, sibling, out, seen)


func _remote_shell_job_text_is_royal_title(job_text: String) -> bool:
	var text: String = str(job_text).strip_edges().to_lower()
	if text == "":
		return false

	var royal_words:= [
		"king",
		"queen",
		"emperor",
		"empress",
		"pharaoh",
		"prince",
		"princess",
		"duke",
		"duchess",
		"lord",
		"lady",
		"consort",
		"regent",
		"sovereign",
		"heir"
	]

	for word in royal_words:
		if text.find(str(word)) >= 0:
			return true

	return false

func _remote_shell_apply_family_weighted_birth_stats(gs_ref, player: Person) -> void:
	if gs_ref == null or player == null:
		return

	var ancestors: Array = []
	ancestors.append_array(_remote_shell_direct_people_from_ids(gs_ref, player.parents))

	for raw_parent_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue
		ancestors.append_array(_remote_shell_direct_people_from_ids(gs_ref, parent.parents))

	if ancestors.is_empty():
		return

	var stat_keys:= [
		{ "person_key": "health", "snapshot_key": "health"},
		{ "person_key": "mental_health", "snapshot_key": "mental"},
		{ "person_key": "satisfaction", "snapshot_key": "happiness"},
		{ "person_key": "looks", "snapshot_key": "looks"},
		{ "person_key": "smarts", "snapshot_key": "smarts"},
		{ "person_key": "imagination", "snapshot_key": "imagination"}
	]

	for stat in stat_keys:
		var person_key: String = str(stat.get("person_key", ""))
		if person_key == "" or not (person_key in player):
			continue

		var total: float = 0.0
		var count: int = 0

		for ancestor in ancestors:
			if ancestor == null or not (person_key in ancestor):
				continue
			total += float(ancestor.get(person_key))
			count += 1

		if count <= 0:
			continue

		var family_average: float = total / float(count)
		var random_variance: float = float((randi() % 31) - 15)
		var existing_value: float = float(player.get(person_key))
		var blended: float = (existing_value * 0.35) + (family_average * 0.65) + random_variance
		player.set(person_key, clamp(blended, 0.0, 100.0))


func _remote_shell_build_birth_intro(gs_ref, snapshot: Dictionary, settings: Dictionary) -> String:
	var lines: Array = []
	var era_text: String = str(settings.get("era_name", "")).strip_edges()
	var year_text: String = str(snapshot.get("year_text", _remote_shell_format_year(int(settings.get("year", 0))))).strip_edges()
	var age_text: String = str(snapshot.get("age", 0))

	if era_text != "":
		lines.append("Birth Lobby accepted: %s" % era_text)
	else:
		lines.append("Birth Lobby accepted")

	if year_text != "":
		lines.append("Year: %s" % year_text)

	lines.append("Age: %s" % age_text)

	lines.append(_remote_shell_conception_story(settings))

	if year_text != "":
		lines.append("I was born in %s." % year_text)

	var gender_text: String = str(snapshot.get("gender", "")).strip_edges().to_lower()
	if gender_text == "":
		gender_text = "a child"

	var place_text: String = _remote_shell_birth_place_text(snapshot, settings)
	if place_text != "":
		lines.append("I was born %s in %s." % [_remote_shell_gender_phrase(gender_text), place_text])
	else:
		lines.append("I was born %s." % _remote_shell_gender_phrase(gender_text))

	var birthday: String = str(settings.get("birthday_text", "")).strip_edges()
	var zodiac: String = str(settings.get("zodiac_sign", "")).strip_edges()
	if birthday != "" and zodiac != "":
		lines.append("My birthday is %s. I am a %s." % [birthday, zodiac])
	elif birthday != "":
		lines.append("My birthday is %s." % birthday)

	lines.append("My name is %s." % str(snapshot.get("name", "Someone")))

	var player = gs_ref.player if gs_ref != null and "player" in gs_ref else null
	if player != null:
		lines.append_array(_remote_shell_parent_intro_lines(gs_ref, player))
		lines.append_array(_remote_shell_grandparent_intro_lines(gs_ref, player))
		lines.append_array(_remote_shell_sibling_intro_lines(gs_ref, player))

	return "\n".join(lines)


func _remote_shell_birth_place_text(snapshot: Dictionary, settings: Dictionary) -> String:
	var city: String = str(snapshot.get("city", settings.get("city", ""))).strip_edges()
	var country: String = str(snapshot.get("country", settings.get("country", ""))).strip_edges()
	var bits: Array = []

	if city != "":
		bits.append(city)
	if country != "":
		bits.append(country)

	return ", ".join(bits)


func _remote_shell_gender_phrase(gender_text: String) -> String:
	var clean: String = str(gender_text).strip_edges().to_lower()

	if clean == "female" or clean == "woman" or clean == "girl":
		return "a female"
	if clean == "male" or clean == "man" or clean == "boy":
		return "a male"

	return "a child"


func _remote_shell_conception_story(settings: Dictionary) -> String:
	var era_key: String = str(settings.get("era_key", "Modern")).strip_edges()
	var reality_mode: String = str(settings.get("reality_mode", "realistic")).strip_edges().to_lower()
	var seed_source: String = "%s.%s.%s.%s.%s" % [
		str(settings.get("name", "Someone")),
		era_key,
		str(settings.get("year", "0")),
		str(settings.get("city", "")),
		reality_mode
	]

	var stories: Array = []

	match era_key:
		"Industrial":
			stories = [
				"I was conceived after my mother slipped on coal dust and my father helped her up.",
				"I was conceived after a factory bell rang late and my parents walked home under smoke-stained stars.",
				"I was conceived in a year where machines were louder than prayers, but my family still made room for me."
			]
		"Medieval":
			stories = [
				"I was conceived after a rainstorm trapped my parents beneath the same chapel roof.",
				"I was conceived after my father returned from market with bread, bruised pride, and a reason to laugh.",
				"I was conceived in a world of bells, mud, hunger, and whispered promises."
			]
		"Ancient":
			stories = [
				"I was conceived after my parents met near a crowded market where dust, gods, and gossip moved together.",
				"I was conceived after my mother carried water at dusk and my father walked beside her longer than he needed to.",
				"I was conceived beneath an old sky where people still believed every birth had a sign."
			]
		"Future":
			stories = [
				"I was conceived after a citywide power flicker made my parents remember they were human before they were data.",
				"I was conceived in a future that could predict almost everything except me.",
				"I was conceived while the world argued with machines and my family chose life anyway."
			]
		_:
			stories = [
				"I was conceived after my parents found each other in the ordinary chaos of life.",
				"I was conceived in a quiet moment that became the beginning of my whole world.",
				"I was conceived before anyone knew what my life would ask of them."
			]

	if reality_mode == "fantasy":
		stories.append("I was conceived during a night where something impossible moved through my family line.")
	elif reality_mode == "enhanced":
		stories.append("I was conceived in a moment that felt ordinary to everyone except destiny.")

	var index: int = abs(hash(seed_source)) % max(1, stories.size())
	return str(stories [index])


func _remote_shell_parent_intro_lines(gs_ref, player: Person) -> Array:
	var lines: Array = []

	for raw_parent_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue

		var label: String = "parent"
		var gender: String = str(parent.gender).strip_edges().to_lower() if "gender" in parent else ""
		if gender == "male":
			label = "father"
		elif gender == "female":
			label = "mother"

		lines.append("My %s is %s, %s (age %d)." % [
			label,
			_remote_shell_person_name(parent),
			_remote_shell_person_job_phrase(parent),
			int(parent.age) if "age" in parent else 0
		])

	return lines


func _remote_shell_grandparent_intro_lines(gs_ref, player: Person) -> Array:
	var lines: Array = []

	for raw_parent_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue

		var side: String = "maternal"
		var parent_gender: String = str(parent.gender).strip_edges().to_lower() if "gender" in parent else ""
		if parent_gender == "male":
			side = "paternal"

		for raw_gp_id in parent.parents:
			var gp: Person = _remote_shell_person_by_id(gs_ref, int(raw_gp_id))
			if gp == null:
				continue

			var gp_label: String = "grandparent"
			var gp_gender: String = str(gp.gender).strip_edges().to_lower() if "gender" in gp else ""
			if gp_gender == "male":
				gp_label = "grandfather"
			elif gp_gender == "female":
				gp_label = "grandmother"

			lines.append("My %s %s is %s, %s (age %d)." % [
				side,
				gp_label,
				_remote_shell_person_name(gp),
				_remote_shell_person_job_phrase(gp),
				int(gp.age) if "age" in gp else 0
			])

	return lines


func _remote_shell_sibling_intro_lines(gs_ref, player: Person) -> Array:
	var lines: Array = []
	var siblings: Array = _remote_shell_collect_siblings(gs_ref, player, {})

	for raw_sibling in siblings:
		if typeof(raw_sibling) != TYPE_DICTIONARY:
			continue

		var sibling: Dictionary = raw_sibling
		var relationship: String = str(sibling.get("relationship", "sibling")).to_lower()
		if relationship.find("sister") == -1 and relationship.find("brother") == -1:
			relationship = "sibling"

		lines.append("My %s is %s (age %d)." % [
			relationship,
			str(sibling.get("name", "Unknown")),
			int(sibling.get("age", 0))
		])

	return lines


func _remote_shell_person_job_phrase(person: Person) -> String:
	if person == null:
		return "unknown"

	if "alive" in person and not bool(person.alive):
		return "dead"

	var job_text: String = ""
	if "job" in person:
		job_text = str(person.job).strip_edges()
	if job_text == "" and "career" in person:
		job_text = str(person.career).strip_edges()

	if job_text == "":
		if "age" in person and int(person.age) >= 65:
			return "retired"
		return "unemployed"

	var article: String = "a"
	var first_char: String = job_text.substr(0, 1).to_lower()
	if first_char in ["a", "e", "i", "o", "u"]:
		article = "an"

	return "%s %s" % [article, job_text]


func _remote_shell_month_name(month: int) -> String:
	var names:= [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]

	var index: int = clamp(month, 1, 12) - 1
	return names [index]


func _remote_shell_zodiac_sign(month: int, day: int) -> String:
	var m: int = clamp(month, 1, 12)
	var d: int = clamp(day, 1, 31)

	if (m == 1 and d >= 20) or (m == 2 and d <= 18):
		return "Aquarius"
	if (m == 2 and d >= 19) or (m == 3 and d <= 20):
		return "Pisces"
	if (m == 3 and d >= 21) or (m == 4 and d <= 19):
		return "Aries"
	if (m == 4 and d >= 20) or (m == 5 and d <= 20):
		return "Taurus"
	if (m == 5 and d >= 21) or (m == 6 and d <= 20):
		return "Gemini"
	if (m == 6 and d >= 21) or (m == 7 and d <= 22):
		return "Cancer"
	if (m == 7 and d >= 23) or (m == 8 and d <= 22):
		return "Leo"
	if (m == 8 and d >= 23) or (m == 9 and d <= 22):
		return "Virgo"
	if (m == 9 and d >= 23) or (m == 10 and d <= 22):
		return "Libra"
	if (m == 10 and d >= 23) or (m == 11 and d <= 21):
		return "Scorpio"
	if (m == 11 and d >= 22) or (m == 12 and d <= 21):
		return "Sagittarius"

	return "Capricorn"


func _remote_shell_direct_people_from_ids(gs_ref, ids: Array) -> Array:
	var out: Array = []

	for raw_id in ids:
		var person: Person = _remote_shell_person_by_id(gs_ref, int(raw_id))
		if person != null:
			out.append(person)

	return out


func _remote_shell_snapshot_links(gs_ref, envelope: Dictionary, settings: Dictionary) -> Dictionary:
	if gs_ref == null:
		return {}

	var world_id: String = str(envelope.get("world_container_id", "eralife-discord-world")).strip_edges()
	if world_id == "":
		world_id = "eralife-discord-world"

	if gs_ref.game_state_contract_engine != null and gs_ref.game_state_contract_engine.has_method("build_tap_to_play_links"):
		var links: Variant = gs_ref.game_state_contract_engine.build_tap_to_play_links(world_id, {
			"source": "discord_birth",
			"birth": settings.duplicate(true),
		})
		if typeof(links) == TYPE_DICTIONARY:
			return links

	return {
		"url": "eralife://snapshot/%s" % world_id.uri_encode(),
		"mode": "snapshot_stub",
		"hydration_target": "full_game_later"
	}
func _remote_shell_birth_starting_money(settings: Dictionary) -> int:
	var seed_source: String = str(settings.get("birth_seed", "")).strip_edges()
	if seed_source == "":
		seed_source = "%s.%s.%s.%s" % [
			str(settings.get("name", "Someone")),
			str(settings.get("era_key", "Modern")),
			str(settings.get("year", "0")),
			str(settings.get("city", ""))
		]

	var roll: int = abs(hash(seed_source)) % 450
	return roll
func _remote_shell_birth_social_class(settings: Dictionary) -> String:
	var explicit_class: String = str(settings.get("social_class", settings.get("class", ""))).strip_edges()
	if explicit_class != "" and explicit_class != "Random / Era Default":
		return explicit_class

	var era_key: String = str(settings.get("era_key", settings.get("era", "Modern"))).strip_edges()
	var reality_mode: String = str(settings.get("reality_mode", "realistic")).strip_edges().to_lower()
	var seed_source: String = "%s.%s.%s.%s.%s.social_class" % [
		str(settings.get("birth_seed", "")),
		str(settings.get("name", "")),
		era_key,
		str(settings.get("country", "")),
		reality_mode
	]
	var roll: int = abs(hash(seed_source)) % 1000

	match era_key:
		"Ancient":
			if roll < 70:
				return "Merchant"
			if roll < 230:
				return "Commoner"
			if roll < 650:
				return "Peasant"
			return "Lower Class"
		"Medieval":
			if roll < 80:
				return "Merchant"
			if roll < 260:
				return "Commoner"
			if roll < 720:
				return "Peasant"
			return "Lower Class"
		"Industrial":
			if roll < 80:
				return "Upperclass"
			if roll < 260:
				return "Merchant"
			if roll < 620:
				return "Working Class"
			return "Commoner"
		"Future":
			if roll < 90:
				return "Elite"
			if roll < 260:
				return "Upperclass"
			if roll < 650:
				return "Middle Class"
			return "Working Class"
		_:
			if roll < 80:
				return "Elite"
			if roll < 240:
				return "Upperclass"
			if roll < 620:
				return "Middle Class"
			if roll < 830:
				return "Working Class"
			return "Commoner"
func _remote_shell_normalize_era_key(value: String) -> String:
	var clean: String = str(value).strip_edges()
	clean = clean.replace(" Era", "")
	clean = clean.replace(" era", "")

	match clean.to_lower():
		"ancient":
			return "Ancient"
		"medieval":
			return "Medieval"
		"industrial":
			return "Industrial"
		"modern":
			return "Modern"
		"future":
			return "Future"

	return "Modern"


func _remote_shell_era_display_name(era_key: String) -> String:
	match _remote_shell_normalize_era_key(era_key):
		"Ancient":
			return "Ancient Era"
		"Medieval":
			return "Medieval Era"
		"Industrial":
			return "Industrial Era"
		"Modern":
			return "Modern Era"
		"Future":
			return "Future Era"
		_:
			return "Modern Era"


func _remote_shell_life_stats(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.stats", "GameState was not found yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var target_query: String = str(args.get("target", args.get("person", args.get("name", "")))).strip_edges()

	if target_query == "":
		var snapshot: Dictionary = _remote_shell_player_snapshot(gs_ref)
		var text:= "%s\nAge: %d\nYear: %s" % [
			str(snapshot.get("name", "Unknown Life")),
			int(snapshot.get("age", 0)),
			str(snapshot.get("year_text", snapshot.get("year", "")))
		]

		return _remote_shell_response(true, envelope, "life.stats", text, {
			"player": snapshot,
			"stats": _remote_shell_stat_bars(snapshot),
			"world": _remote_shell_world_snapshot(gs_ref)
		})

	var matches: Array = _remote_shell_find_stat_targets(gs_ref, target_query)

	if matches.is_empty():
		return _remote_shell_response(false, envelope, "life.stats", "I could not find a visible family member matching \"%s\"." % target_query, {
			"query": target_query,
			"family": _remote_shell_family_payload(gs_ref, "family")
		})

	if matches.size() > 1:
		var lines: Array = ["I found more than one match. Choose who you meant:"]
		var choices: Array = []
		var capped_count: int = min(matches.size(), 5)

		for i in range(capped_count):
			var row: Dictionary = matches [i]
			var person_id: int = int(row.get("id", -1))
			var person_name: String = str(row.get("name", "Unknown"))
			var relationship: String = str(row.get("relationship", "Family"))

			lines.append("• %s — %s — age %d — id:%d" % [
				relationship,
				person_name,
				int(row.get("age", 0)),
				person_id
			])

			choices.append({
				"id": "stats_person:%d" % person_id,
				"label": "%s (%s)" % [person_name, relationship]
			})

		return _remote_shell_response(true, envelope, "life.stats", "\n".join(lines), {
			"stat_candidates": matches,
			"decision": {
				"id": "stats_target_%s" % str(envelope.get("request_id", int(Time.get_ticks_msec()))),
				"type": "stats_target",
				"choices": choices
			}
		})

	var selected_id: int = int(matches [0].get("id", -1))
	var target: Person = _remote_shell_person_by_id(gs_ref, selected_id)

	if target == null:
		return _remote_shell_response(false, envelope, "life.stats", "That person could not be loaded anymore.", {
			"person_id": selected_id
		})

	return _remote_shell_life_stats_for_person(gs_ref, envelope, target, "life.stats")
func _remote_shell_life_stats_for_person(gs_ref, envelope: Dictionary, target: Person, command_id: String = "life.stats") -> Dictionary:
	if gs_ref == null:
		return _remote_shell_response(false, envelope, command_id, "GameState was not found yet.", {})
	if target == null:
		return _remote_shell_response(false, envelope, command_id, "That person was not found.", {})

	var snapshot: Dictionary = _remote_shell_person_snapshot_for_stats(gs_ref, target)
	var text:= "%s\nAge: %d\nYear: %s\nRelationship: %s" % [
		str(snapshot.get("name", "Unknown Life")),
		int(snapshot.get("age", 0)),
		str(snapshot.get("year_text", snapshot.get("year", ""))),
		str(snapshot.get("relationship", "Family"))
	]

	return _remote_shell_response(true, envelope, command_id, text, {
		"player": snapshot,
		"target": snapshot,
		"stats": _remote_shell_stat_bars(snapshot),
		"world": _remote_shell_world_snapshot(gs_ref)
	})


func _remote_shell_find_stat_targets(gs_ref, query: String) -> Array:
	var out: Array = []
	if gs_ref == null:
		return out

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return out

	var clean: String = str(query).strip_edges().to_lower()
	if clean == "":
		return out

	if clean.begins_with("id:"):
		var id_text: String = clean.replace("id:", "").strip_edges()
		var id_target: Person = _remote_shell_person_by_id(gs_ref, int(id_text))
		if id_target != null:
			out.append(_remote_shell_person_card(gs_ref, player, id_target, _remote_shell_relationship_label(gs_ref, player, id_target)))
		return out

	var aliases:= {
		"mom": "mother",
		"mama": "mother",
		"mother": "mother",
		"dad": "father",
		"daddy": "father",
		"father": "father",
		"bro": "brother",
		"brother": "brother",
		"sis": "sister",
		"sister": "sister",
		"grandma": "grandmother",
		"grandmother": "grandmother",
		"grandpa": "grandfather",
		"grandfather": "grandfather",
		"child": "child",
		"son": "son",
		"daughter": "daughter"
	}

	if aliases.has(clean):
		clean = str(aliases.get(clean, clean))

	var payload: Dictionary = _remote_shell_family_payload(gs_ref, "family")
	var rows: Array = payload.get("rows", []) if typeof(payload.get("rows", [])) == TYPE_ARRAY else []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var name_text: String = str(row.get("name", "")).strip_edges().to_lower()
		var relationship_text: String = str(row.get("relationship", "")).strip_edges().to_lower()
		var id_text: String = str(row.get("id", "")).strip_edges().to_lower()

		if name_text == clean or name_text.find(clean) >= 0:
			out.append(row.duplicate(true))
			continue

		if relationship_text == clean or relationship_text.find(clean) >= 0:
			out.append(row.duplicate(true))
			continue

		if id_text == clean:
			out.append(row.duplicate(true))

	return out


func _remote_shell_person_snapshot_for_stats(gs_ref, p: Person) -> Dictionary:
	if p == null:
		return {}

	var player = gs_ref.player if gs_ref != null and "player" in gs_ref else null
	var year_value: int = int(gs_ref.year) if gs_ref != null and "year" in gs_ref else 0

	return {
		"id": int(p.id) if "id" in p else 0,
		"name": _remote_shell_person_name(p),
		"first_name": str(p.first_name) if "first_name" in p else "",
		"last_name": str(p.last_name) if "last_name" in p else "",
		"gender": str(p.gender) if "gender" in p else "",
		"age": int(p.age) if "age" in p else 0,
		"alive": bool(p.alive) if "alive" in p else true,
		"relationship": _remote_shell_relationship_label(gs_ref, player, p) if player != null else "Family",
		"year": year_value,
		"year_text": _remote_shell_format_year(year_value),
		"health": clamp(float(p.health) if "health" in p else 0.0, 0.0, 100.0),
		"mental": clamp(float(p.mental_health) if "mental_health" in p else 0.0, 0.0, 100.0),
		"hunger": clamp(float(p.hunger) if "hunger" in p else 0.0, 0.0, 100.0),
		"happiness": clamp(float(p.satisfaction) if "satisfaction" in p else 0.0, 0.0, 100.0),
		"looks": clamp(float(p.looks) if "looks" in p else 0.0, 0.0, 100.0),
		"smarts": clamp(float(p.smarts) if "smarts" in p else 0.0, 0.0, 100.0),
		"imagination": clamp(float(p.imagination) if "imagination" in p else 0.0, 0.0, 100.0),
		"fame": clamp(float(p.fame) if "fame" in p else 0.0, 0.0, 100.0),
		"country": str(p.home_country) if "home_country" in p else "",
		"city": str(p.home_city) if "home_city" in p else "",
		"birth_country": str(p.birth_country) if "birth_country" in p else "",
		"birth_city": str(p.birth_city) if "birth_city" in p else "",
		"job": str(p.job) if "job" in p else "",
		"birthday_text": str(p.birthday_text) if "birthday_text" in p else "",
		"zodiac_sign": str(p.zodiac_sign) if "zodiac_sign" in p else ""
	}


func _remote_shell_life_age(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.age", "GameState was not found yet.", {})

	var year_before: int = int(gs_ref.year) if "year" in gs_ref else 0
	var player_age_before: int = int(gs_ref.player.age) if "player" in gs_ref and gs_ref.player != null and "age" in gs_ref.player else -1
	var npc_age_snapshot_before: Dictionary = _remote_shell_capture_npc_age_snapshot(gs_ref)

	var death_count_before: int = 0
	var inheritance_count_before: int = 0
	var popup_count_before: int = 0

	if "pending_death_messages" in gs_ref and typeof(gs_ref.pending_death_messages) == TYPE_ARRAY:
		death_count_before = gs_ref.pending_death_messages.size()

	if "pending_inheritance_messages" in gs_ref and typeof(gs_ref.pending_inheritance_messages) == TYPE_ARRAY:
		inheritance_count_before = gs_ref.pending_inheritance_messages.size()

	if "pending_year_resolution_popups" in gs_ref and typeof(gs_ref.pending_year_resolution_popups) == TYPE_ARRAY:
		popup_count_before = gs_ref.pending_year_resolution_popups.size()

	var result: Variant = {}
	if "life_engine" in gs_ref and gs_ref.life_engine != null and gs_ref.life_engine.has_method("age_up"):
		result = gs_ref.life_engine.call("age_up")
	elif gs_ref.has_method("age_up"):
		result = gs_ref.call("age_up")
	else:
		return _remote_shell_response(false, envelope, "life.age", "No age-up route was available for this runtime.", {
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var result_dict: Dictionary = _remote_shell_year_result_dict(result)
	if _remote_shell_year_result_is_pending(result_dict):
		var settled: Dictionary = _remote_shell_settle_nonvisible_age_up(gs_ref, result_dict)
		if not settled.is_empty():
			result_dict = settled

	var clock_repair_report: Dictionary = _remote_shell_repair_discord_age_up_clock(
		gs_ref,
		result_dict,
		year_before,
		player_age_before,
		npc_age_snapshot_before
	)

	var player_snapshot: Dictionary = _remote_shell_player_snapshot(gs_ref)
	var stat_rows: Dictionary = _remote_shell_stat_bars(player_snapshot)
	var world_feed_tail: Array = _remote_shell_world_feed_tail(gs_ref, 8)
	var death_messages: Array = []
	var inheritance_messages: Array = []
	var year_resolution_popups: Array = []
	var broadcast_events: Array = []

	if "pending_death_messages" in gs_ref and typeof(gs_ref.pending_death_messages) == TYPE_ARRAY:
		if death_count_before < gs_ref.pending_death_messages.size():
			death_messages = gs_ref.pending_death_messages.slice(death_count_before, gs_ref.pending_death_messages.size())

	if "pending_inheritance_messages" in gs_ref and typeof(gs_ref.pending_inheritance_messages) == TYPE_ARRAY:
		if inheritance_count_before < gs_ref.pending_inheritance_messages.size():
			inheritance_messages = gs_ref.pending_inheritance_messages.slice(inheritance_count_before, gs_ref.pending_inheritance_messages.size())

	if "pending_year_resolution_popups" in gs_ref and typeof(gs_ref.pending_year_resolution_popups) == TYPE_ARRAY:
		if popup_count_before < gs_ref.pending_year_resolution_popups.size():
			year_resolution_popups = gs_ref.pending_year_resolution_popups.slice(popup_count_before, gs_ref.pending_year_resolution_popups.size())

	for raw_popup in year_resolution_popups:
		if typeof(raw_popup) != TYPE_DICTIONARY:
			continue

		var popup: Dictionary = raw_popup.duplicate(true)
		var popup_title: String = str(popup.get("popup_title", popup.get("title", "Notice"))).strip_edges()
		var popup_text: String = str(popup.get("popup_text", popup.get("text", ""))).strip_edges()

		if popup_text == "":
			continue

		var popup_color: int = 5793266
		var title_lower: String = popup_title.to_lower()
		if title_lower.find("death") >= 0:
			popup_color = 16731501
		elif title_lower.find("inheritance") >= 0:
			popup_color = 16765286

		broadcast_events.append({
			"title": popup_title,
			"text": popup_text,
			"color": popup_color
		})

	var text: String = str(result_dict.get("text", "")).strip_edges()
	if text == "" or _remote_shell_year_result_is_pending(result_dict) or bool(clock_repair_report.get("repaired_year", false)):
		text = "Time moved. I am now age %d in %s." % [
			int(player_snapshot.get("age", 0)),
			str(player_snapshot.get("year_text", player_snapshot.get("year", "")))
		]

	return _remote_shell_response(true, envelope, "life.age", text, {
		"result": result_dict,
		"clock_repair": clock_repair_report,
		"player": player_snapshot,
		"stats": stat_rows,
		"world_feed_tail": world_feed_tail,
		"death_messages": death_messages,
		"inheritance_messages": inheritance_messages,
		"year_resolution_popups": year_resolution_popups,
		"broadcast_events": broadcast_events,
		"notices": {
			"death_messages": death_messages,
			"inheritance_messages": inheritance_messages,
			"year_resolution_popups": year_resolution_popups
		}
	})
func _remote_shell_capture_npc_age_snapshot(gs_ref) -> Dictionary:
	var out: Dictionary = {}

	if gs_ref == null:
		return out

	if not ("npcs" in gs_ref) or typeof(gs_ref.npcs) != TYPE_ARRAY:
		return out

	for npc in gs_ref.npcs:
		if npc == null:
			continue
		if not ("id" in npc) or not ("age" in npc):
			continue

		out [int(npc.id)] = int(npc.age)

	return out


func _remote_shell_repair_discord_age_up_clock(gs_ref, _result_dict: Dictionary, year_before: int, player_age_before: int, npc_age_snapshot_before: Dictionary) -> Dictionary:
	var report:= {
		"checked": true,
		"repaired_year": false,
		"repaired_npc_ages": 0,
		"year_before": year_before,
		"year_after": int(gs_ref.year) if gs_ref != null and "year" in gs_ref else year_before,
		"reason": ""
	}

	if gs_ref == null:
		report ["reason"] = "missing_game_state"
		return report

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		report ["reason"] = "missing_player"
		return report

	var player_age_after: int = int(player.age) if "age" in player else player_age_before
	var year_after: int = int(gs_ref.year) if "year" in gs_ref else year_before

	if player_age_before >= 0 and player_age_after <= player_age_before:
		report ["reason"] = "player_age_did_not_advance"
		return report

	if year_after > year_before:
		report ["reason"] = "year_already_advanced"
		return report

	var repaired_year: int = year_before + 1
	gs_ref.year = repaired_year
	report ["repaired_year"] = true
	report ["year_after"] = repaired_year
	report ["reason"] = "discord_age_up_year_was_stalled"

	if "npcs" in gs_ref and typeof(gs_ref.npcs) == TYPE_ARRAY:
		for npc in gs_ref.npcs:
			if npc == null:
				continue
			if npc == player:
				continue
			if not ("id" in npc) or not ("age" in npc):
				continue

			var npc_id: int = int(npc.id)
			if not npc_age_snapshot_before.has(npc_id):
				continue

			var before_age: int = int(npc_age_snapshot_before.get(npc_id, int(npc.age)))
			if int(npc.age) == before_age:
				npc.age = before_age + 1
				report ["repaired_npc_ages"] = int(report.get("repaired_npc_ages", 0)) + 1

	if gs_ref.has_method("normalize_world_feed_entry") and "world_feed" in gs_ref and typeof(gs_ref.world_feed) == TYPE_ARRAY:
		gs_ref.world_feed.append(gs_ref.normalize_world_feed_entry({
			"year": repaired_year,
			"text": "Discord runtime advanced the world clock to %s." % _remote_shell_format_year(repaired_year),
			"kind": "discord_clock_repair",
			"created_at_ms": int(Time.get_ticks_msec())
		}))

	return report
func _remote_shell_year_result_dict(result: Variant) -> Dictionary:
	if typeof(result) == TYPE_DICTIONARY:
		return (result as Dictionary).duplicate(true)

	return {
		"value": result
	}


func _remote_shell_year_result_is_pending(result_dict: Dictionary) -> bool:
	var result_type: String = str(result_dict.get("type", "")).strip_edges().to_lower()
	if result_type == "year_pipeline_pending":
		return true

	var text: String = str(result_dict.get("text", "")).strip_edges().to_lower()
	if text.find("still resolving") >= 0:
		return true
	if text.find("still settling") >= 0:
		return true

	return false


func _remote_shell_settle_nonvisible_age_up(gs_ref, current_result: Dictionary) -> Dictionary:
	if gs_ref == null:
		return current_result

	var result_dict: Dictionary = current_result.duplicate(true)

	if "life_engine" in gs_ref and gs_ref.life_engine != null:
		if gs_ref.life_engine.has_method("continue_nonvisible_age_up_transaction"):
			for i in range(6):
				var resumed: Variant = gs_ref.life_engine.call("continue_nonvisible_age_up_transaction", 4, 8)
				var resumed_dict: Dictionary = _remote_shell_year_result_dict(resumed)
				if not resumed_dict.is_empty():
					result_dict = resumed_dict
				if not _remote_shell_year_result_is_pending(result_dict):
					return result_dict

		if gs_ref.life_engine.has_method("force_complete_nonvisible_age_up_transaction"):
			var forced: Variant = gs_ref.life_engine.call("force_complete_nonvisible_age_up_transaction", "discord_remote_shell_age_command")
			var forced_dict: Dictionary = _remote_shell_year_result_dict(forced)
			if not forced_dict.is_empty():
				return forced_dict

	return result_dict

func _remote_shell_life_diary(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.diary", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	var lines: Array = []

	if player != null and "memories" in player:
		var memories_raw: Variant = player.memories
		if typeof(memories_raw) == TYPE_ARRAY:
			lines = memories_raw.duplicate(true)

	while lines.size() > 12:
		lines.pop_front()

	var text: String = "No diary entries yet."
	if not lines.is_empty():
		text = "\n".join(lines.map(func (x): return str(x)))

	return _remote_shell_response(true, envelope, "life.diary", text, {
		"entries": lines
	})
func _remote_shell_save_life(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.save", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.save", "No player life is active yet.", {})

	var path: String = _remote_shell_personal_save_path(envelope)
	if path == "":
		return _remote_shell_response(false, envelope, "life.save", "I could not build a personal save path for this Discord user.", {})

	if gs_ref.has_method("save_game"):
		gs_ref.save_game(path, {
			"source": "discord_remote_shell",
			"user_id": str(envelope.get("user_id", "")),
			"life_node_id": str(envelope.get("life_node_id", "")),
			"skip_archive": false,
			"skip_prune": false,
			"skip_memory_compaction": false,
			"skip_world_feed_normalization": false
		})
	else:
		return _remote_shell_response(false, envelope, "life.save", "GameState does not expose save_game().", {})

	var saved: bool = FileAccess.file_exists(path)
	var snapshot: Dictionary = _remote_shell_player_snapshot(gs_ref)

	return _remote_shell_response(saved, envelope, "life.save", "Life saved for %s." % str(snapshot.get("name", "this Discord user")), {
		"save_path": path,
		"player": snapshot,
		"world": _remote_shell_world_snapshot(gs_ref)
	})


func _remote_shell_load_life(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.load", "GameState was not found yet.", {})

	var path: String = _remote_shell_personal_save_path(envelope)
	if path == "":
		return _remote_shell_response(false, envelope, "life.load", "I could not build a personal save path for this Discord user.", {})

	if not FileAccess.file_exists(path):
		return _remote_shell_response(false, envelope, "life.load", "No saved life exists for this Discord user yet. Use /save_life first.", {
			"save_path": path,
		})

	if gs_ref.has_method("load_game"):
		gs_ref.load_game(path)
	else:
		return _remote_shell_response(false, envelope, "life.load", "GameState does not expose load_game().", {})

	if gs_ref.has_method("_rebuild_npc_index"):
		gs_ref._rebuild_npc_index()

	var snapshot: Dictionary = _remote_shell_player_snapshot(gs_ref)

	return _remote_shell_response(true, envelope, "life.load", "Loaded saved life for %s." % str(snapshot.get("name", "this Discord user")), {
		"save_path": path,
		"player": snapshot,
		"stats": _remote_shell_stat_bars(snapshot),
		"world": _remote_shell_world_snapshot(gs_ref),
		"family": _remote_shell_family_payload(gs_ref, "family")
	})


func _remote_shell_personal_save_path(envelope: Dictionary) -> String:
	var user_id: String = str(envelope.get("user_id", "")).strip_edges()
	if user_id == "":
		user_id = str(envelope.get("external_user_id", "")).strip_edges()
	if user_id == "":
		user_id = str(envelope.get("life_node_id", "local_user")).strip_edges()

	var safe_user_id: String = _remote_shell_safe_file_key(user_id)
	if safe_user_id == "":
		safe_user_id = "local_user"

	var dir_path: String = "user://discord_lives"
	var global_dir_path: String = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(global_dir_path)

	return "%s/%s.bin" % [dir_path, safe_user_id]


func _remote_shell_safe_file_key(value: String) -> String:
	var clean: String = str(value).strip_edges()
	var allowed: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
	var out: String = ""

	for i in range(clean.length()):
		var ch: String = clean.substr(i, 1)
		if allowed.find(ch) >= 0:
			out += ch
		else:
			out += "_"

	while out.find("__") >= 0:
		out = out.replace("__", "_")

	return out.strip_edges()
func _remote_shell_life_family(envelope: Dictionary, section: String = "family") -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.%s" % section, "GameState was not found yet.", {})

	var payload: Dictionary = _remote_shell_family_payload(gs_ref, section)
	var rows: Array = payload.get("rows", []) if typeof(payload.get("rows", [])) == TYPE_ARRAY else []

	var title: String = str(payload.get("title", "Family")).strip_edges()
	var lines: Array = [title]

	if rows.is_empty():
		lines.append("No visible family members found for this lane yet.")
	else:
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			lines.append("%s — %s | Age %s | Bond %s | id:%s" % [
				str(row.get("relationship", "Family")),
				str(row.get("name", "Unknown")),
				str(row.get("age", "—")),
				str(row.get("bond", "—")),
				str(row.get("id", ""))
			])

	return _remote_shell_response(true, envelope, "life.%s" % section, "\n".join(lines), {
		"player": _remote_shell_player_snapshot(gs_ref),
		"stats": _remote_shell_stat_bars(_remote_shell_player_snapshot(gs_ref)),
		"family": payload
	})


func _remote_shell_life_relationship_action(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.relationship", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.relationship", "No player life is active yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var target_id: int = int(args.get("person_id", args.get("target_id", -1)))
	var action: String = str(args.get("action", "talk")).strip_edges().to_lower()

	var target: Person = _remote_shell_person_by_id(gs_ref, target_id)
	if target == null:
		return _remote_shell_response(false, envelope, "life.relationship", "That person id was not found. Use /family, /siblings, or /grandparents first.", {
			"person_id": target_id
		})

	var delta: int = _remote_shell_relationship_delta(action)
	if gs_ref.social_graph_engine != null and gs_ref.social_graph_engine.has_method("modify_affection"):
		gs_ref.social_graph_engine.modify_affection(int(player.id), int(target.id), delta)

	var relationship_label: String = _remote_shell_relationship_label(gs_ref, player, target)
	var target_name: String = _remote_shell_person_name(target)
	var bond: int = _remote_shell_bond(gs_ref, player, target)

	var action_text: String = _remote_shell_relationship_action_text(action, target_name, relationship_label, delta, bond)

	if "memories" in player:
		player.memories.append(action_text)

	return _remote_shell_response(true, envelope, "life.relationship", action_text, {
		"player": _remote_shell_player_snapshot(gs_ref),
		"stats": _remote_shell_stat_bars(_remote_shell_player_snapshot(gs_ref)),
		"target": _remote_shell_person_card(gs_ref, player, target, relationship_label)
	})


func _remote_shell_family_payload(gs_ref, section: String = "family") -> Dictionary:
	var player = gs_ref.player if gs_ref != null and "player" in gs_ref else null
	if player == null:
		return {
			"title": "Family",
			"rows": []
		}

	var rows: Array = []
	var seen: Dictionary = {}

	match section:
		"siblings":
			rows.append_array(_remote_shell_collect_siblings(gs_ref, player, seen))
			return {
				"title": "Siblings",
				"rows": rows
			}
		"grandparents":
			rows.append_array(_remote_shell_collect_grandparents(gs_ref, player, seen))
			return {
				"title": "Grandparents",
				"rows": rows
			}
		"greatgrandparents":
			rows.append_array(_remote_shell_collect_great_grandparents(gs_ref, player, seen))
			return {
				"title": "Great-Grandparents",
				"rows": rows
			}
		_:
			rows.append_array(_remote_shell_collect_parents(gs_ref, player, seen))
			rows.append_array(_remote_shell_collect_siblings(gs_ref, player, seen))
			rows.append_array(_remote_shell_collect_grandparents(gs_ref, player, seen))
			rows.append_array(_remote_shell_collect_children(gs_ref, player, seen))
			return {
				"title": "Whole Family",
				"rows": rows
			}


func _remote_shell_collect_parents(gs_ref, player: Person, seen: Dictionary) -> Array:
	var out: Array = []
	for raw_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_id))
		if parent == null:
			continue
		out.append(_remote_shell_person_card(gs_ref, player, parent, _remote_shell_relationship_label(gs_ref, player, parent), seen))
	return out


func _remote_shell_collect_siblings(gs_ref, player: Person, seen: Dictionary) -> Array:
	var out: Array = []
	var parent_key: String = JSON.stringify(player.parents)
	for npc in gs_ref.npcs:
		if npc == null:
			continue
		if int(npc.id) == int(player.id):
			continue
		if JSON.stringify(npc.parents) == parent_key:
			out.append(_remote_shell_person_card(gs_ref, player, npc, _remote_shell_relationship_label(gs_ref, player, npc), seen))
	return out


func _remote_shell_collect_grandparents(gs_ref, player: Person, seen: Dictionary) -> Array:
	var out: Array = []
	for raw_parent_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue
		for raw_gp_id in parent.parents:
			var gp: Person = _remote_shell_person_by_id(gs_ref, int(raw_gp_id))
			if gp == null:
				continue
			out.append(_remote_shell_person_card(gs_ref, player, gp, _remote_shell_relationship_label(gs_ref, player, gp), seen))
	return out


func _remote_shell_collect_great_grandparents(gs_ref, player: Person, seen: Dictionary) -> Array:
	var out: Array = []
	for raw_parent_id in player.parents:
		var parent: Person = _remote_shell_person_by_id(gs_ref, int(raw_parent_id))
		if parent == null:
			continue
		for raw_gp_id in parent.parents:
			var gp: Person = _remote_shell_person_by_id(gs_ref, int(raw_gp_id))
			if gp == null:
				continue
			for raw_ggp_id in gp.parents:
				var ggp: Person = _remote_shell_person_by_id(gs_ref, int(raw_ggp_id))
				if ggp == null:
					continue
				out.append(_remote_shell_person_card(gs_ref, player, ggp, _remote_shell_relationship_label(gs_ref, player, ggp), seen))
	return out


func _remote_shell_collect_children(gs_ref, player: Person, seen: Dictionary) -> Array:
	var out: Array = []
	for raw_id in player.children:
		var child: Person = _remote_shell_person_by_id(gs_ref, int(raw_id))
		if child == null:
			continue
		out.append(_remote_shell_person_card(gs_ref, player, child, _remote_shell_relationship_label(gs_ref, player, child), seen))
	return out


func _remote_shell_person_by_id(gs_ref, person_id: int) -> Person:
	if gs_ref == null or person_id <= 0:
		return null

	if gs_ref.has_method("get_or_reactivate_npc_by_id"):
		return gs_ref.get_or_reactivate_npc_by_id(person_id)

	if gs_ref.has_method("get_npc_by_id"):
		return gs_ref.get_npc_by_id(person_id)

	if "npcs" in gs_ref:
		for npc in gs_ref.npcs:
			if npc != null and int(npc.id) == person_id:
				return npc

	return null


func _remote_shell_person_card(gs_ref, player: Person, target: Person, relationship_label: String = "", seen: Dictionary = {}) -> Dictionary:
	if target == null:
		return {}

	var target_id: int = int(target.id)
	if seen.has(target_id):
		return {}
	seen [target_id] = true

	if relationship_label == "":
		relationship_label = _remote_shell_relationship_label(gs_ref, player, target)

	return {
		"id": target_id,
		"name": _remote_shell_person_name(target),
		"relationship": relationship_label,
		"age": int(target.age) if "age" in target else 0,
		"alive": bool(target.alive) if "alive" in target else true,
		"bond": _remote_shell_bond(gs_ref, player, target),
		"city": str(target.home_city) if "home_city" in target else "",
		"country": str(target.home_country) if "home_country" in target else ""
	}


func _remote_shell_person_name(person: Person) -> String:
	if person == null:
		return "Unknown"

	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges() if "name" in person else "Unknown"

	return full_name


func _remote_shell_relationship_label(gs_ref, player: Person, target: Person) -> String:
	if gs_ref != null and gs_ref.has_method("get_relationship_label_between"):
		return str(gs_ref.get_relationship_label_between(player, target))
	return "Family"


func _remote_shell_bond(gs_ref, player: Person, target: Person) -> int:
	if gs_ref == null or player == null or target == null:
		return 50

	if gs_ref.social_graph_engine != null and gs_ref.social_graph_engine.has_method("get_affection"):
		return int(gs_ref.social_graph_engine.get_affection(int(player.id), int(target.id)))

	return 50


func _remote_shell_relationship_delta(action: String) -> int:
	match action:
		"compliment":
			return 5
		"spend_time":
			return 7
		"play":
			return 6
		"apologize":
			return 4
		"gift":
			return 8
		_:
			return 3


func _remote_shell_relationship_action_text(action: String, target_name: String, relationship_label: String, delta: int, bond: int) -> String:
	var verb_text: String = "talked with"
	match action:
		"compliment":
			verb_text = "complimented"
		"spend_time":
			verb_text = "spent time with"
		"play":
			verb_text = "played with"
		"apologize":
			verb_text = "apologized to"
		"gift":
			verb_text = "gave a gift to"

	return "You %s %s, your %s. Bond increased by %d. Current bond: %d." % [
		verb_text,
		target_name,
		relationship_label,
		delta,
		bond
	]
func _remote_shell_life_school(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.school", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.school", "No player life is active yet.", {})

	if gs_ref.school_engine == null:
		return _remote_shell_response(false, envelope, "life.school", "SchoolEngine is not available yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var action: String = str(args.get("action", "status")).strip_edges().to_lower()

	if not gs_ref.school_engine.can_attend_school(player):
		return _remote_shell_response(false, envelope, "life.school", "I am not school age, or this era does not allow me to attend school yet.", {
			"player": _remote_shell_player_snapshot(gs_ref),
			"stats": _remote_shell_stat_bars(_remote_shell_player_snapshot(gs_ref))
		})

	if not gs_ref.school_engine.enrollment.has(player.id):
		var enroll_result: Dictionary = gs_ref.school_engine.enroll_in_era_school(player)
		if not bool(enroll_result.get("success", false)):
			return _remote_shell_response(false, envelope, "life.school", str(enroll_result.get("text", "School enrollment failed.")), {
				"player": _remote_shell_player_snapshot(gs_ref)
			})

	var rec: Dictionary = gs_ref.school_engine.enrollment.get(player.id, {}).duplicate(true)
	var school_name: String = ""
	if str(rec.get("mode", "")) == "dual":
		school_name = "%s and %s" % [str(rec.get("era_school", "")), str(rec.get("bending_school", ""))]
	else:
		school_name = str(rec.get("school_name", player.school_name if "school_name" in player else "school"))

	var teachers: Array = gs_ref.school_engine.get_teachers_for(player)
	var classmates: Array = gs_ref.school_engine.get_classmates(player)

	if action == "teachers":
		var teacher_lines: Array = []
		for teacher in teachers:
			if teacher is Person:
				teacher_lines.append("• %s — id %d — %s" % [
					_remote_shell_person_name(teacher),
					int(teacher.id),
					_remote_shell_person_job_phrase(teacher)
				])
		var teacher_text: String = "My school is %s.\n\nTeachers:" % school_name
		teacher_text += "\n" + ("\n".join(teacher_lines) if not teacher_lines.is_empty() else "No teachers are visible yet.")
		return _remote_shell_response(true, envelope, "life.school", teacher_text, {
			"school_name": school_name,
			"teachers": _remote_shell_people_rows(teachers)
		})

	if action == "classmates":
		var classmate_lines: Array = []
		for classmate in classmates:
			if classmate is Person:
				classmate_lines.append("• %s — id %d" % [_remote_shell_person_name(classmate), int(classmate.id)])
		var classmate_text: String = "My school is %s.\n\nClassmates:" % school_name
		classmate_text += "\n" + ("\n".join(classmate_lines) if not classmate_lines.is_empty() else "No classmates are visible yet.")
		return _remote_shell_response(true, envelope, "life.school", classmate_text, {
			"school_name": school_name,
			"classmates": _remote_shell_people_rows(classmates)
		})

	if action == "talk":
		var person_id: int = int(args.get("person_id", -1))
		var target: Person = _remote_shell_person_by_id(gs_ref, person_id)
		if target == null:
			return _remote_shell_response(false, envelope, "life.school", "That student or teacher id was not found.", {
				"person_id": person_id
			})
		var line: String = "I talked with %s at %s." % [_remote_shell_person_name(target), school_name]
		if gs_ref.social_graph_engine != null and gs_ref.social_graph_engine.has_method("modify_affection"):
			gs_ref.social_graph_engine.modify_affection(int(player.id), int(target.id), 4)
		if "memories" in player:
			player.memories.append(line)
		return _remote_shell_response(true, envelope, "life.school", line, {
			"target": _remote_shell_person_card(gs_ref, player, target, _remote_shell_relationship_label(gs_ref, player, target))
		})

	var text: String = "School: %s\nStatus: %s\nTeachers: %d\nClassmates: %d" % [
		school_name,
		str(rec.get("status", "active")).capitalize(),
		teachers.size(),
		classmates.size()
	]

	return _remote_shell_response(true, envelope, "life.school", text, {
		"school_name": school_name,
		"school_record": rec,
		"teachers": _remote_shell_people_rows(teachers),
		"classmates": _remote_shell_people_rows(classmates),
		"player": _remote_shell_player_snapshot(gs_ref)
	})


func _remote_shell_life_jobs(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.jobs", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.jobs", "No player life is active yet.", {})

	if gs_ref.career_engine == null:
		return _remote_shell_response(false, envelope, "life.jobs", "CareerEngine is not available yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var action: String = str(args.get("action", "list")).strip_edges().to_lower()
	var job_name: String = str(args.get("job_name", "")).strip_edges()
	var intensity: String = str(args.get("intensity", "normal")).strip_edges().to_lower()

	match action:
		"apply":
			var apply_result: Dictionary = {}
			if int(player.age) >= 18:
				apply_result = gs_ref.career_engine.apply_for_job(player, job_name)
			else:
				apply_result = gs_ref.career_engine.apply_for_part_time_job(player, job_name)
			return _remote_shell_response(bool(apply_result.get("success", false)), envelope, "life.jobs", str(apply_result.get("text", "Job application resolved.")), {
				"player": _remote_shell_player_snapshot(gs_ref),
				"stats": _remote_shell_stat_bars(_remote_shell_player_snapshot(gs_ref)),
				"job_result": apply_result
			})

		"work":
			var work_result: Dictionary = gs_ref.career_engine.work_shift(player, intensity)
			var boss_text: String = _remote_shell_apply_job_pressure(envelope, player, intensity)
			var full_text: String = str(work_result.get("text", "Work shift resolved."))
			if boss_text != "":
				full_text += "\n\n" + boss_text
			return _remote_shell_response(bool(work_result.get("success", false)), envelope, "life.jobs", full_text, {
				"player": _remote_shell_player_snapshot(gs_ref),
				"stats": _remote_shell_stat_bars(_remote_shell_player_snapshot(gs_ref)),
				"job_result": work_result
			})

		"quit":
			var quit_result: Dictionary = gs_ref.career_engine.quit_job(player)
			return _remote_shell_response(bool(quit_result.get("success", false)), envelope, "life.jobs", str(quit_result.get("text", "Quit job resolved.")), {
				"player": _remote_shell_player_snapshot(gs_ref),
				"job_result": quit_result
			})

		"describe":
			var described: Dictionary = gs_ref.career_engine.describe_job(player)
			return _remote_shell_response(bool(described.get("success", false)), envelope, "life.jobs", str(described.get("text", "No job description available.")), {
				"player": _remote_shell_player_snapshot(gs_ref),
				"job": described
			})

	var full_time: Array = gs_ref.career_engine.get_available_jobs_for(player)
	var part_time: Array = gs_ref.career_engine.get_available_part_time_jobs_for(player)
	var lines: Array = []

	if int(player.age) < 16:
		lines.append("Jobs unlock at age 16 for part-time work.")
	elif int(player.age) < 18:
		lines.append("Part-Time Jobs:")
		for job in part_time:
			lines.append("• %s" % str(job))
	else:
		lines.append("Full-Time Jobs:")
		for job in full_time:
			lines.append("• %s" % str(job))

	return _remote_shell_response(true, envelope, "life.jobs", "\n".join(lines), {
		"full_time": full_time,
		"part_time": part_time,
		"player": _remote_shell_player_snapshot(gs_ref)
	})


func _remote_shell_apply_job_pressure(envelope: Dictionary, player: Person, intensity: String) -> String:
	if player == null:
		return ""

	var key: String = str(envelope.get("life_node_id", envelope.get("user_id", ""))).strip_edges()
	if key == "":
		key = str(player.id)

	var state: Dictionary = discord_job_pressure_registry.get(key, {}).duplicate(true) if typeof(discord_job_pressure_registry.get(key, {})) == TYPE_DICTIONARY else {}

	if str(player.job).strip_edges() == "":
		state.clear()
		discord_job_pressure_registry [key] = state
		return ""

	var warning_count: int = int(state.get("boss_warning_count", 0))
	var perf: int = int(player.job_performance)

	if intensity == "hard":
		warning_count = max(0, warning_count - 1)
	elif intensity == "slack" or perf < 35:
		warning_count += 1

	state ["boss_warning_count"] = warning_count
	state ["job_name"] = str(player.job)
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	discord_job_pressure_registry [key] = state

	if warning_count >= 3:
		var fired_job: String = str(player.job)
		player.job = ""
		player.income = 0
		player.job_performance = 50
		player.job_experience = 0
		player.work_stress = 0.0
		state ["boss_warning_count"] = 0
		state ["fired_from"] = fired_job
		discord_job_pressure_registry [key] = state
		return "My boss finally got tired of me playing with the job. I got fired from %s." % fired_job

	if warning_count > 0:
		return "My boss is getting irritated with me. Warning level: %d/3." % warning_count

	return "My boss noticed the effort. My job feels safer for now."


func _remote_shell_life_ask_out(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.ask_out", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.ask_out", "No player life is active yet.", {})

	if int(player.age) < 14:
		return _remote_shell_response(false, envelope, "life.ask_out", "I am too young to ask someone out.", {
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var target_user_ids: Array = envelope.get("target_user_ids", []) if typeof(envelope.get("target_user_ids", [])) == TYPE_ARRAY else []
	if target_user_ids.is_empty():
		return _remote_shell_response(false, envelope, "life.ask_out", "Pick a Discord server member to ask out.", {
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var target_user_id: String = str(target_user_ids [0]).strip_edges()
	var asker_user_id: String = str(envelope.get("user_id", "")).strip_edges()
	var decision_id: String = "ask_out_%s_%s" % [str(envelope.get("request_id", int(Time.get_ticks_msec()))), target_user_id]

	discord_relationship_request_registry [decision_id] = {
		"schema": "eralife.discord_relationship_request",
		"version": 1,
		"decision_id": decision_id,
		"asker_user_id": asker_user_id,
		"target_user_id": target_user_id,
		"asker_life_node_id": str(envelope.get("life_node_id", "")),
		"world_container_id": str(envelope.get("world_container_id", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var text: String = "<@%s>, <@%s> asked you out.\n\nChoose yes or no below." % [
		target_user_id,
		asker_user_id
	]

	return _remote_shell_response(true, envelope, "life.ask_out", text, {
		"decision": {
			"id": decision_id,
			"choices": [
				{ "id": "accept", "label": "Say Yes"},
				{ "id": "decline", "label": "Say No"}
			]
		}
	})


func _remote_shell_life_choice(envelope: Dictionary) -> Dictionary:
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var decision_id: String = str(args.get("decision_id", "")).strip_edges()
	var choice_id: String = str(args.get("choice_id", "")).strip_edges().to_lower()
	var clicker_user_id: String = str(envelope.get("user_id", "")).strip_edges()
	if choice_id.begins_with("stats_person:"):
		var gs_ref = _resolve_game_state()
		if gs_ref == null:
			return _remote_shell_response(false, envelope, "life.choice", "GameState was not found yet.", {})

		var person_id_text: String = choice_id.replace("stats_person:", "").strip_edges()
		var target: Person = _remote_shell_person_by_id(gs_ref, int(person_id_text))
		if target == null:
			return _remote_shell_response(false, envelope, "life.choice", "That person could not be loaded anymore.", {
				"person_id": int(person_id_text)
			})

		return _remote_shell_life_stats_for_person(gs_ref, envelope, target, "life.stats")
	if discord_relationship_request_registry.has(decision_id):
		var request: Dictionary = discord_relationship_request_registry.get(decision_id, {}).duplicate(true)
		var target_user_id: String = str(request.get("target_user_id", ""))
		var request_type: String = str(request.get("type", "ask_out")).strip_edges().to_lower()

		if clicker_user_id != target_user_id:
			return _remote_shell_response(false, envelope, "life.choice", "Only <@%s> can answer this relationship request." % target_user_id, {})

		discord_relationship_request_registry.erase(decision_id)

		var accepted: bool = choice_id in ["accept", "yes", "say_yes"]
		var asker_user_id: String = str(request.get("asker_user_id", ""))
		var world_id: String = str(request.get("world_container_id", envelope.get("world_container_id", ""))).strip_edges()
		if world_id == "":
			world_id = "discord.guild.local"

		var world: Dictionary = _discord_world_for_envelope(envelope)
		var members: Dictionary = world.get("members", {}).duplicate(true) if typeof(world.get("members", {})) == TYPE_DICTIONARY else {}
		var couples: Array = world.get("couples", []) if typeof(world.get("couples", [])) == TYPE_ARRAY else []

		if accepted:
			var status: String = "engaged" if request_type == "proposal" else "dating"
			couples.append({
				"asker_user_id": asker_user_id,
				"target_user_id": target_user_id,
				"status": status,
				"ring_name": str(request.get("ring_name", "")),
				"started_at_ms": int(Time.get_ticks_msec())
			})

			for member_id in [asker_user_id, target_user_id]:
				var member: Dictionary = members.get(member_id, {}).duplicate(true) if typeof(members.get(member_id, {})) == TYPE_DICTIONARY else {}
				member ["relationship_status"] = status
				member ["partner_user_id"] = target_user_id if member_id == asker_user_id else asker_user_id
				member ["relationship_updated_at_ms"] = int(Time.get_ticks_msec())
				members [member_id] = member

			world ["members"] = members
			world ["couples"] = couples
			discord_server_world_registry [world_id] = world
			_eranet_register_world(world)

			_discord_world_add_feed_event(world_id, "<@%s> and <@%s> are now %s in this EraLife server world." % [
				asker_user_id,
				target_user_id,
				status
			], 16742314)

			return _remote_shell_response(true, envelope, "life.choice", "<@%s> said yes. <@%s> and <@%s> are now %s." % [
				target_user_id,
				asker_user_id,
				target_user_id,
				status
			], {
				"server_world": world,
				"broadcast_events": [
					{
						"title": "💞 Relationship Update",
						"text": "<@%s> and <@%s> are now %s." % [asker_user_id, target_user_id, status],
						"color": 16742314
					}
				]
			})

		var decline_text: String = "<@%s> turned down <@%s>." % [target_user_id, asker_user_id]
		_discord_world_add_feed_event(world_id, decline_text, 9145227)

		return _remote_shell_response(true, envelope, "life.choice", "<@%s> said no." % target_user_id, {
			"broadcast_events": [
				{
					"title": "Relationship Update",
					"text": decline_text,
					"color": 9145227
				}
			]
		})

	return _remote_shell_contract_ack(envelope)

func _remote_shell_life_shop_route(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.shop", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.shop", "No player life is active yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var command_id: String = str(envelope.get("command_id", "life.shop")).strip_edges().to_lower()
	var action: String = str(args.get("action", "list")).strip_edges().to_lower()

	if action in ["", "list", "open", "hub"]:
		var surface_id: String = _remote_shell_surface_id_for_command(command_id, args)
		if surface_id != "":
			var embedded_engine = _ensure_embedded_ui_contract_engine(gs_ref)
			if embedded_engine != null:
				var context: Dictionary = _remote_shell_embedded_ui_context(envelope, args)
				var report: Dictionary = embedded_engine.render_surface(surface_id, context)
				if bool(report.get("success", false)):
					return _remote_shell_response(true, envelope, command_id, "Embedded UI surface rendered.", {
						"embedded_ui": report,
						"ui_model": report.get("render_model", {}),
						"surface_id": surface_id,
						"player": _remote_shell_player_snapshot(gs_ref)
					})

	match command_id:
		"life.restaurant":
			return _remote_shell_life_restaurant_command(gs_ref, player, envelope, args, action)
		"life.grocery":
			return _remote_shell_life_grocery_command(gs_ref, player, envelope, args, action)
		"life.luxury_shop":
			return _remote_shell_life_luxury_shop_command(gs_ref, player, envelope, args, action)
		"life.inventory":
			return _remote_shell_life_inventory_command(gs_ref, player, envelope)

	var lines: Array = [
		"EraLife Shop Terminal",
		"",
		"Available places:",
		"• /restaurant action:list",
		"• /grocery action:list",
		"• /luxury_shop action:list",
		"• /inventory"
	]

	return _remote_shell_response(true, envelope, "life.shop", "\n".join(lines), {
		"player": _remote_shell_player_snapshot(gs_ref),
		"shop_routes": [
			{ "command": "/restaurant", "kind": "food_restaurant"},
			{ "command": "/grocery", "kind": "grocery_store"},
			{ "command": "/luxury_shop", "kind": "luxury_shop"},
			{ "command": "/inventory", "kind": "inventory"}
		]
	})
func _remote_shell_life_restaurant_command(gs_ref, player: Person, envelope: Dictionary, args: Dictionary, action: String) -> Dictionary:
	if gs_ref.food_restaurant_engine == null:
		return _remote_shell_response(false, envelope, "life.restaurant", "FoodRestaurantEngine is not available yet.", {})

	var restaurant_id: String = str(args.get("restaurant_id", "")).strip_edges()
	var food_id: String = str(args.get("food_id", "")).strip_edges()

	if action == "menu":
		var menu_rows: Array = gs_ref.food_restaurant_engine.get_menu_rows({
			"restaurant_id": restaurant_id
		})
		return _remote_shell_rows_response(envelope, "life.restaurant", "Restaurant menu:", menu_rows)

	if action in ["eat", "order", "takeout", "buy"]:
		if restaurant_id == "" or food_id == "":
			return _remote_shell_response(false, envelope, "life.restaurant", "Use restaurant_id and food_id to order.", {})
		var order_mode: String = "takeout" if action == "takeout" else "eat_now"
		var report: Dictionary = gs_ref.food_restaurant_engine.place_order(player, restaurant_id, food_id, {
			"source": "discord_restaurant_command",
			"order_mode": order_mode,
			"service_mode": str(args.get("service_mode", "dine_in"))
		})
		return _remote_shell_response(bool(report.get("success", false)), envelope, "life.restaurant", str(report.get("text", report.get("reason", "Restaurant order complete."))), {
			"restaurant_report": report,
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var rows: Array = gs_ref.food_restaurant_engine.get_restaurant_rows({})
	return _remote_shell_rows_response(envelope, "life.restaurant", "Restaurants:", rows)


func _remote_shell_life_grocery_command(gs_ref, player: Person, envelope: Dictionary, args: Dictionary, action: String) -> Dictionary:
	if gs_ref.grocery_store_engine == null:
		return _remote_shell_response(false, envelope, "life.grocery", "GroceryStoreEngine is not available yet.", {})

	var store_id: String = str(args.get("store_id", "")).strip_edges()
	var food_id: String = str(args.get("food_id", "")).strip_edges()

	if action == "items":
		var item_rows: Array = gs_ref.grocery_store_engine.get_grocery_item_rows({
			"store_id": store_id
		})
		return _remote_shell_rows_response(envelope, "life.grocery", "Grocery items:", item_rows)

	if action == "buy":
		if store_id == "" or food_id == "":
			return _remote_shell_response(false, envelope, "life.grocery", "Use store_id and food_id to buy groceries.", {})
		var qty: int = max(1, int(args.get("quantity", 1)))
		var report: Dictionary = gs_ref.grocery_store_engine.buy_grocery(player, store_id, food_id, qty, {
			"source": "discord_grocery_command"
		})
		return _remote_shell_response(bool(report.get("success", false)), envelope, "life.grocery", str(report.get("text", report.get("reason", "Grocery purchase complete."))), {
			"grocery_report": report,
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var rows: Array = gs_ref.grocery_store_engine.get_grocery_store_rows({})
	return _remote_shell_rows_response(envelope, "life.grocery", "Grocery stores:", rows)


func _remote_shell_life_luxury_shop_command(gs_ref, player: Person, envelope: Dictionary, args: Dictionary, action: String) -> Dictionary:
	if gs_ref.luxury_shop_engine == null:
		return _remote_shell_response(false, envelope, "life.luxury_shop", "LuxuryShopEngine is not available yet.", {})

	var shop_id: String = str(args.get("shop_id", "")).strip_edges()
	var item_id: String = str(args.get("item_id", "")).strip_edges()

	if action == "items":
		var item_rows: Array = gs_ref.luxury_shop_engine.get_luxury_item_rows({
			"shop_id": shop_id
		})
		return _remote_shell_rows_response(envelope, "life.luxury_shop", "Luxury items:", item_rows)
	if action in ["overview", "inspect", "lore"]:
		var overview_rows: Array = gs_ref.luxury_shop_engine.get_luxury_item_overview_rows({
			"shop_id": shop_id,
			"item_id": item_id
		})
		return _remote_shell_rows_response(envelope, "life.luxury_shop", "Luxury item overview:", overview_rows)
	if action == "buy":
		if shop_id == "" or item_id == "":
			return _remote_shell_response(false, envelope, "life.luxury_shop", "Use shop_id and item_id to buy luxury items.", {})
		var report: Dictionary = gs_ref.luxury_shop_engine.buy_luxury_item(player, shop_id, item_id, {
			"source": "discord_luxury_shop_command"
		})
		return _remote_shell_response(bool(report.get("success", false)), envelope, "life.luxury_shop", str(report.get("text", report.get("reason", "Luxury purchase complete."))), {
			"luxury_report": report,
			"player": _remote_shell_player_snapshot(gs_ref)
		})

	var rows: Array = gs_ref.luxury_shop_engine.get_luxury_shop_rows({})
	return _remote_shell_rows_response(envelope, "life.luxury_shop", "Luxury shops:", rows)


func _remote_shell_life_inventory_command(gs_ref, player: Person, envelope: Dictionary) -> Dictionary:
	if gs_ref.belongings_engine == null:
		return _remote_shell_response(false, envelope, "life.inventory", "BelongingsEngine is not available yet.", {})

	var rows: Array = gs_ref.belongings_engine.get_inventory_rows_for_actor(player, {
		"source": "discord_inventory_command"
	})

	return _remote_shell_rows_response(envelope, "life.inventory", "Inventory:", rows)


func _remote_shell_rows_response(envelope: Dictionary, command_id: String, title: String, rows: Array) -> Dictionary:
	var lines: Array = [title]

	if rows.is_empty():
		lines.append("Nothing is available yet.")
	else:
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			lines.append("• %s" % str(row.get("label", row)))

	return _remote_shell_response(true, envelope, command_id, "\n".join(lines), {
		"rows": rows
	})
func _remote_shell_life_weapon_shop(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.weapon_shop", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.weapon_shop", "No player life is active yet.", {})

	if gs_ref.weapons_engine == null:
		return _remote_shell_response(false, envelope, "life.weapon_shop", "WeaponsEngine is not available yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var action: String = str(args.get("action", "shop")).strip_edges().to_lower()
	var item_name: String = str(args.get("item", args.get("weapon_name", ""))).strip_edges()

	if action == "inventory":
		var inventory: Array = gs_ref.weapons_engine.get_inventory()
		return _remote_shell_response(true, envelope, "life.weapon_shop", "My weapons:\n%s" % ("\n".join(inventory) if not inventory.is_empty() else "None"), {
			"inventory": inventory
		})

	if action == "buy":
		if item_name == "":
			return _remote_shell_response(false, envelope, "life.weapon_shop", "Choose a weapon name from /weapon_shop action:shop.", {})
		var buy_text: String = gs_ref.weapons_engine.buy_weapon(item_name)
		return _remote_shell_response(true, envelope, "life.weapon_shop", buy_text, {
			"player": _remote_shell_player_snapshot(gs_ref),
			"inventory": gs_ref.weapons_engine.get_inventory()
		})

	if action == "use":
		if item_name == "":
			return _remote_shell_response(false, envelope, "life.weapon_shop", "Choose a weapon to use.", {})
		if not gs_ref.weapons_engine.owns_weapon(item_name):
			return _remote_shell_response(false, envelope, "life.weapon_shop", "I do not own a %s." % item_name, {})

		var target_user_ids: Array = envelope.get("target_user_ids", []) if typeof(envelope.get("target_user_ids", [])) == TYPE_ARRAY else []
		var person_id: int = int(args.get("person_id", -1))

		if not target_user_ids.is_empty():
			var target_user_id: String = str(target_user_ids [0])
			var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
			_discord_world_add_feed_event(world_id, "⚔️ <@%s> used %s against <@%s> in the server world." % [
				str(envelope.get("user_id", "")),
				item_name,
				target_user_id
			], 11154227)
			return _remote_shell_response(true, envelope, "life.weapon_shop", "I used %s against <@%s>." % [item_name, target_user_id], {
				"broadcast_events": [
					{
						"title": "⚔️ EraLife Conflict",
						"text": "<@%s> used %s against <@%s>." % [str(envelope.get("user_id", "")), item_name, target_user_id],
						"color": 11154227
					}
				]
			})

		if person_id > 0:
			var target: Person = _remote_shell_person_by_id(gs_ref, person_id)
			if target == null:
				return _remote_shell_response(false, envelope, "life.weapon_shop", "That family/NPC person id was not found.", {})
			if "health" in target:
				target.health = clamp(float(target.health) - 12.0, 0.0, 100.0)
			var target_line: String = "I used %s during a conflict with %s." % [item_name, _remote_shell_person_name(target)]
			if "memories" in player:
				player.memories.append(target_line)
			return _remote_shell_response(true, envelope, "life.weapon_shop", target_line, {
				"target": _remote_shell_person_card(gs_ref, player, target, _remote_shell_relationship_label(gs_ref, player, target))
			})

		return _remote_shell_response(false, envelope, "life.weapon_shop", "Choose a server member target or a family/NPC person_id.", {})

	var rows: Array = _remote_shell_weapon_store_rows(gs_ref)
	var lines: Array = ["Era Weapon Shop — %s" % str(gs_ref.era.name)]
	for row in rows:
		lines.append("• %s — %s coins — %s%s" % [
			str(row.get("name", "")),
			str(row.get("cost", "0")),
			str(row.get("type", "weapon")).capitalize(),
			" — License Required" if bool(row.get("license_required", false)) else ""
		])

	return _remote_shell_response(true, envelope, "life.weapon_shop", "\n".join(lines), {
		"weapons": rows,
		"player": _remote_shell_player_snapshot(gs_ref)
	})


func _remote_shell_life_artifacts_shop(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.artifacts.shop", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.artifacts.shop", "No player life is active yet.", {})

	if gs_ref.artifacts_engine == null:
		return _remote_shell_response(false, envelope, "life.artifacts.shop", "ArtifactsEngine is not available yet.", {})

	var rows: Array = gs_ref.artifacts_engine.get_shop_inventory(player)
	var lines: Array = ["Fantasy Artifact Shop:"]
	for row in rows:
		lines.append("• %s `%s` — %s — %s — %s" % [
			str(row.get("name", "Artifact")),
			str(row.get("id", "")),
			str(row.get("cost_display", "")),
			str(row.get("rarity", "Unknown")),
			str(row.get("status_text", "Available"))
		])

	return _remote_shell_response(true, envelope, "life.artifacts.shop", "\n".join(lines), {
		"artifacts": rows,
		"player": _remote_shell_player_snapshot(gs_ref)
	})


func _remote_shell_life_artifacts_buy(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "life.artifacts.buy", "GameState was not found yet.", {})

	var player = gs_ref.player if "player" in gs_ref else null
	if player == null:
		return _remote_shell_response(false, envelope, "life.artifacts.buy", "No player life is active yet.", {})

	if gs_ref.artifacts_engine == null:
		return _remote_shell_response(false, envelope, "life.artifacts.buy", "ArtifactsEngine is not available yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var item_id: String = str(args.get("item_id", "")).strip_edges()

	if item_id == "":
		return _remote_shell_response(false, envelope, "life.artifacts.buy", "Choose an artifact item_id from /artifacts shop.", {})

	var result: Dictionary = gs_ref.artifacts_engine.purchase_shop_item(player, item_id)
	return _remote_shell_response(bool(result.get("success", false)), envelope, "life.artifacts.buy", str(result.get("text", "Artifact purchase resolved.")), {
		"purchase": result,
		"player": _remote_shell_player_snapshot(gs_ref)
	})


func _remote_shell_world_age(envelope: Dictionary) -> Dictionary:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var world: Dictionary = _discord_world_for_envelope(envelope)
	var year_value: int = int(world.get("year", 2026)) + 1
	world ["year"] = year_value
	world ["year_text"] = _remote_shell_format_year(year_value)

	var members_raw: Variant = world.get("members", {})
	var members: Dictionary = members_raw.duplicate(true) if typeof(members_raw) == TYPE_DICTIONARY else {}
	var broadcast_events: Array = []

	for raw_key in members.keys():
		var member: Dictionary = members.get(raw_key, {}).duplicate(true) if typeof(members.get(raw_key, {})) == TYPE_DICTIONARY else {}
		var age: int = int(member.get("age", 0)) + 1
		member ["age"] = age

		if bool(member.get("alive", true)):
			var old_age_limit: int = int(member.get("old_age_limit", 78 + (abs(hash(str(raw_key))) % 35)))
			member ["old_age_limit"] = old_age_limit

			if age >= old_age_limit:
				member ["alive"] = false
				var death_line: String = "🕯️ %s died of old age at %d in %s." % [
					str(member.get("username", raw_key)),
					age,
					str(world.get("year_text", "the current year"))
				]
				_discord_world_add_feed_event(world_id, death_line, 6052956)
				broadcast_events.append({
					"title": "🕯️ EraLife Death",
					"text": death_line,
					"color": 6052956
				})

		members [raw_key] = member

	world ["members"] = members
	discord_server_world_registry [world_id] = world

	var feed_line: String = "🌐 The server world aged into %s. %d lives synced." % [
		str(world.get("year_text", "")),
		members.size()
	]
	_discord_world_add_feed_event(world_id, feed_line, 5209938)

	return _remote_shell_response(true, envelope, "world.age", feed_line, {
		"server_world": world.duplicate(true),
		"broadcast_events": broadcast_events
	})


func _remote_shell_people_rows(people: Array) -> Array:
	var rows: Array = []
	for person in people:
		if person is Person:
			rows.append({
				"id": int(person.id),
				"name": _remote_shell_person_name(person),
				"age": int(person.age) if "age" in person else 0,
				"job": _remote_shell_person_job_phrase(person)
			})
	return rows


func _remote_shell_weapon_store_rows(gs_ref) -> Array:
	var rows: Array = []
	if gs_ref == null or gs_ref.weapons_engine == null:
		return rows

	var store: Array = gs_ref.weapons_engine.get_store()
	for raw_weapon in store:
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			continue
		var weapon: Dictionary = raw_weapon.duplicate(true)
		rows.append({
			"name": str(weapon.get("name", "")),
			"cost": int(weapon.get("cost", 0)),
			"type": str(weapon.get("type", "weapon")),
			"legal": bool(weapon.get("legal", true)),
			"license_required": bool(weapon.get("license_required", false)),
			"origin_era": str(gs_ref.era.name)
		})
	return rows
func _eranet_realtime_tick(delta: float) -> void:
	eranet_realtime_accumulator_sec += max(
		0.0,
		delta
	)

	if not eranet_realtime_cycle_active:
		if (
			eranet_realtime_accumulator_sec
			< eranet_realtime_tick_interval_sec
		):
			return

		eranet_realtime_cycle_elapsed_sec = (
			eranet_realtime_accumulator_sec
		)
		eranet_realtime_accumulator_sec = 0.0



		eranet_realtime_cycle_world_ids = (
			discord_server_world_registry.keys()
		)
		eranet_realtime_cycle_cursor = 0
		eranet_realtime_cycle_active = true

	if eranet_realtime_cycle_world_ids.is_empty():
		eranet_realtime_cycle_active = false
		eranet_realtime_cycle_elapsed_sec = 0.0
		eranet_realtime_cycle_cursor = 0
		return

	var processed_this_quantum: int = 0

	while (
		eranet_realtime_cycle_cursor
		< eranet_realtime_cycle_world_ids.size()
		and processed_this_quantum
		< ERANET_REALTIME_WORLD_QUANTUM
	):
		var raw_world_id: Variant = (
			eranet_realtime_cycle_world_ids [
				eranet_realtime_cycle_cursor
			]
		)
		eranet_realtime_cycle_cursor += 1
		processed_this_quantum += 1

		var world_id: String = str(
			raw_world_id
		).strip_edges()

		if world_id == "":
			continue

		var world_raw: Variant = (
			discord_server_world_registry.get(
				world_id,
				{}
			)
		)

		if typeof(world_raw) != TYPE_DICTIONARY:
			continue

		var previous_world: Dictionary = (
			world_raw as Dictionary
		)

		if not bool(
			previous_world.get(
				"auto_time",
				false
			)
		):
			continue

		var ticked_world: Dictionary = (
			_eranet_tick_world(
				previous_world,
				eranet_realtime_cycle_elapsed_sec
			)
		)

		discord_server_world_registry [
			world_id
		] = ticked_world

		_eranet_register_world(
			ticked_world
		)

		_eranet_apply_realtime_global_economy_delta(
			previous_world,
			ticked_world
		)

	if (
		eranet_realtime_cycle_cursor
		>= eranet_realtime_cycle_world_ids.size()
	):
		eranet_realtime_cycle_active = false
		eranet_realtime_cycle_elapsed_sec = 0.0
		eranet_realtime_cycle_world_ids = []
		eranet_realtime_cycle_cursor = 0
func _eranet_apply_realtime_global_economy_delta(
	previous_world: Dictionary,
	next_world: Dictionary
) -> void:
	if (
		previous_world.is_empty()
		or next_world.is_empty()
	):
		return

	var previous_era: String = str(
		previous_world.get(
			"era_key",
			"Modern"
		)
	).strip_edges()
	var next_era: String = str(
		next_world.get(
			"era_key",
			"Modern"
		)
	).strip_edges()



	if (
		previous_era == ""
		or next_era == ""
		or previous_era != next_era
	):
		if previous_era != "":
			_eranet_rebuild_global_economy_for_era(
				previous_era
			)

		if (
			next_era != ""
			and next_era != previous_era
		):
			_eranet_rebuild_global_economy_for_era(
				next_era
			)

		return

	var previous_economy_raw: Variant = (
		previous_world.get(
			"economy",
			{}
		)
	)
	var next_economy_raw: Variant = (
		next_world.get(
			"economy",
			{}
		)
	)

	if (
		typeof(previous_economy_raw) != TYPE_DICTIONARY
		or typeof(next_economy_raw) != TYPE_DICTIONARY
	):
		_eranet_rebuild_global_economy_for_era(
			next_era
		)
		return

	var previous_economy: Dictionary = (
		previous_economy_raw as Dictionary
	)
	var next_economy: Dictionary = (
		next_economy_raw as Dictionary
	)

	var global_raw: Variant = (
		eranet_global_economy_registry.get(
			next_era,
			{}
		)
	)

	if typeof(global_raw) != TYPE_DICTIONARY:
		_eranet_rebuild_global_economy_for_era(
			next_era
		)
		return

	var global_row: Dictionary = (
		(global_raw as Dictionary).duplicate(false)
	)

	if global_row.is_empty():
		_eranet_rebuild_global_economy_for_era(
			next_era
		)
		return

	var world_count: int = maxi(
		1,
		int(
			global_row.get(
				"world_count",
				1
			)
		)
	)

	global_row [
		"treasury"
	] = (
		int(
			global_row.get(
				"treasury",
				0
			)
		)
		- int(
			previous_economy.get(
				"treasury",
				0
			)
		)
		+ int(
			next_economy.get(
				"treasury",
				0
			)
		)
	)

	global_row [
		"money_supply"
	] = (
		int(
			global_row.get(
				"money_supply",
				0
			)
		)
		- int(
			previous_economy.get(
				"money_supply",
				0
			)
		)
		+ int(
			next_economy.get(
				"money_supply",
				0
			)
		)
	)

	global_row [
		"trade_volume"
	] = (
		int(
			global_row.get(
				"trade_volume",
				0
			)
		)
		- int(
			previous_economy.get(
				"trade_volume",
				0
			)
		)
		+ int(
			next_economy.get(
				"trade_volume",
				0
			)
		)
	)

	global_row [
		"member_count"
	] = (
		int(
			global_row.get(
				"member_count",
				0
			)
		)
		- int(
			previous_economy.get(
				"member_count",
				0
			)
		)
		+ int(
			next_economy.get(
				"member_count",
				0
			)
		)
	)

	var inflation_total: float = (
		float(
			global_row.get(
				"average_inflation",
				0.0
			)
		)
		* float(world_count)
	)
	inflation_total -= float(
		previous_economy.get(
			"inflation",
			0.0
		)
	)
	inflation_total += float(
		next_economy.get(
			"inflation",
			0.0
		)
	)

	var market_pressure_total: float = (
		float(
			global_row.get(
				"average_market_pressure",
				1.0
			)
		)
		* float(world_count)
	)
	market_pressure_total -= float(
		previous_economy.get(
			"market_pressure",
			1.0
		)
	)
	market_pressure_total += float(
		next_economy.get(
			"market_pressure",
			1.0
		)
	)

	global_row [
		"average_inflation"
	] = inflation_total / float(
		world_count
	)
	global_row [
		"average_market_pressure"
	] = market_pressure_total / float(
		world_count
	)
	global_row [
		"rebuilt_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	global_row [
		"realtime_incremental_aggregate"
	] = true
	global_row [
		"full_registry_scan_per_realtime_tick"
	] = false

	eranet_global_economy_registry [
		next_era
	] = global_row

func _eranet_tick_world(
	world: Dictionary,
	elapsed_sec: float
) -> Dictionary:



	var out: Dictionary = world.duplicate(false)

	var timeline_raw: Variant = out.get(
		"timeline",
		{}
	)
	var timeline: Dictionary = (
		(timeline_raw as Dictionary).duplicate(false)
		if typeof(timeline_raw) == TYPE_DICTIONARY
		else {}
	)

	var seconds_per_year: float = max(
		10.0,
		float(
			timeline.get(
				"seconds_per_year",
				out.get(
					"seconds_per_year",
					300.0
				)
			)
		)
	)
	var progress: float = float(
		timeline.get(
			"pending_year_progress",
			0.0
		)
	)
	progress += elapsed_sec / seconds_per_year

	var years_advanced: int = 0

	if progress >= 1.0:
		years_advanced = min(
			5,
			int(
				floor(progress)
			)
		)
		progress -= float(
			years_advanced
		)

	if years_advanced > 0:
		var current_year: int = int(
			out.get(
				"year",
				2026
			)
		)
		current_year += years_advanced

		out [
			"year"
		] = current_year
		out [
			"year_text"
		] = _remote_shell_format_year(
			current_year
		)

		var members_raw: Variant = out.get(
			"members",
			{}
		)
		var members: Dictionary = (
			(members_raw as Dictionary).duplicate(false)
			if typeof(members_raw) == TYPE_DICTIONARY
			else {}
		)

		for raw_user_id in members.keys():
			var member_raw: Variant = members.get(
				raw_user_id,
				{}
			)
			var member: Dictionary = (
				(member_raw as Dictionary).duplicate(false)
				if typeof(member_raw) == TYPE_DICTIONARY
				else {}
			)

			member [
				"age"
			] = (
				int(
					member.get(
						"age",
						0
					)
				)
				+ years_advanced
			)
			member [
				"last_auto_aged_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			members [
				raw_user_id
			] = member

		out [
			"members"
		] = members

		_discord_world_add_feed_event(
			str(
				out.get(
					"world_id",
					"discord.guild.local"
				)
			),
			"The shared timeline advanced to %s."
			% str(
				out.get(
					"year_text",
					""
				)
			),
			8118258
		)

	timeline [
		"pending_year_progress"
	] = progress
	timeline [
		"seconds_per_year"
	] = seconds_per_year
	timeline [
		"last_tick_ms"
	] = int(
		Time.get_ticks_msec()
	)
	timeline [
		"last_elapsed_sec"
	] = elapsed_sec
	timeline [
		"last_years_advanced"
	] = years_advanced

	out [
		"timeline"
	] = timeline

	out [
		"economy"
	] = _eranet_tick_world_economy(
		out,
		elapsed_sec,
		years_advanced
	)

	return out

func _eranet_tick_world_economy(
	world: Dictionary,
	elapsed_sec: float,
	years_advanced: int = 0
) -> Dictionary:
	var economy_raw: Variant = world.get(
		"economy",
		{}
	)
	var economy: Dictionary = (
		(economy_raw as Dictionary).duplicate(false)
		if typeof(economy_raw) == TYPE_DICTIONARY
		else _eranet_world_default_economy(
			world
		)
	)



	var members_raw: Variant = world.get(
		"members",
		{}
	)
	var member_count: int = (
		max(
			1,
			(members_raw as Dictionary).size()
		)
		if typeof(members_raw) == TYPE_DICTIONARY
		else 1
	)

	var treasury: int = int(
		economy.get(
			"treasury",
			0
		)
	)
	var money_supply: int = int(
		economy.get(
			"money_supply",
			1000 * member_count
		)
	)
	var jobs_open: int = int(
		economy.get(
			"jobs_open",
			12
		)
	)
	var inflation: float = float(
		economy.get(
			"inflation",
			0.02
		)
	)
	var market_pressure: float = float(
		economy.get(
			"market_pressure",
			1.0
		)
	)
	var trade_volume: int = int(
		economy.get(
			"trade_volume",
			0
		)
	)

	var passive_trade: int = int(
		round(
			float(member_count)
			* 3.0
			* max(
				1.0,
				elapsed_sec
			)
		)
	)
	trade_volume += passive_trade
	treasury += int(
		round(
			float(passive_trade)
			* 0.08
		)
	)
	money_supply += int(
		round(
			float(passive_trade)
			* 0.35
		)
	)

	if years_advanced > 0:
		var yearly_pressure: float = (
			0.0025
			* float(years_advanced)
		)
		inflation = clamp(
			inflation
			+ yearly_pressure
			+ (
				float(member_count)
				* 0.0001
			),
			-0.25,
			0.75
		)
		market_pressure = clamp(
			market_pressure
			+ (
				float(
					jobs_open
					- member_count
				)
				* 0.002
			),
			0.25,
			3.0
		)
		jobs_open = max(
			0,
			jobs_open
			+ int(
				round(
					float(member_count)
					* 0.15
				)
			)
			- years_advanced
		)

	economy [
		"schema"
	] = "eralife.eranet_world_economy"
	economy [
		"version"
	] = 1
	economy [
		"treasury"
	] = treasury
	economy [
		"money_supply"
	] = money_supply
	economy [
		"jobs_open"
	] = jobs_open
	economy [
		"inflation"
	] = inflation
	economy [
		"market_pressure"
	] = market_pressure
	economy [
		"trade_volume"
	] = trade_volume
	economy [
		"member_count"
	] = member_count
	economy [
		"last_tick_ms"
	] = int(
		Time.get_ticks_msec()
	)

	return economy

func _eranet_world_default_economy(world: Dictionary) -> Dictionary:
	var member_count: int = 1
	var members_raw: Variant = world.get("members", {})
	if typeof(members_raw) == TYPE_DICTIONARY:
		member_count = max(1, (members_raw as Dictionary).size())

	return {
		"schema": "eralife.eranet_world_economy",
		"version": 1,
		"treasury": 0,
		"money_supply": 1000 * member_count,
		"jobs_open": 12,
		"inflation": 0.02,
		"market_pressure": 1.0,
		"trade_volume": 0,
		"member_count": member_count,
		"created_at_ms": int(Time.get_ticks_msec()),
		"last_tick_ms": int(Time.get_ticks_msec())
	}


func _eranet_rebuild_global_economy_for_era(era_key: String) -> Dictionary:
	var clean_era: String = str(era_key).strip_edges()
	if clean_era == "":
		clean_era = "Modern"

	var total_treasury: int = 0
	var total_money_supply: int = 0
	var total_trade_volume: int = 0
	var total_members: int = 0
	var world_count: int = 0
	var inflation_total: float = 0.0
	var market_pressure_total: float = 0.0

	for raw_world_id in discord_server_world_registry.keys():
		var world_raw: Variant = discord_server_world_registry.get(raw_world_id, {})
		if typeof(world_raw) != TYPE_DICTIONARY:
			continue

		var world: Dictionary = (world_raw as Dictionary)
		if str(world.get("era_key", "Modern")).strip_edges() != clean_era:
			continue

		var economy: Dictionary = world.get("economy", {}).duplicate(true) if typeof(world.get("economy", {})) == TYPE_DICTIONARY else _eranet_world_default_economy(world)
		world_count += 1
		total_treasury += int(economy.get("treasury", 0))
		total_money_supply += int(economy.get("money_supply", 0))
		total_trade_volume += int(economy.get("trade_volume", 0))
		total_members += int(economy.get("member_count", 0))
		inflation_total += float(economy.get("inflation", 0.0))
		market_pressure_total += float(economy.get("market_pressure", 1.0))

	var global_row:= {
		"schema": "eralife.eranet_global_economy",
		"version": 1,
		"era_key": clean_era,
		"world_count": world_count,
		"member_count": total_members,
		"treasury": total_treasury,
		"money_supply": total_money_supply,
		"trade_volume": total_trade_volume,
		"average_inflation": inflation_total / float(max(1, world_count)),
		"average_market_pressure": market_pressure_total / float(max(1, world_count)),
		"rebuilt_at_ms": int(Time.get_ticks_msec())
	}

	eranet_global_economy_registry [clean_era] = global_row
	return global_row.duplicate(true)
func _eranet_touch_identity(envelope: Dictionary, world: Dictionary, member: Dictionary = {}) -> Dictionary:
	var user_id: String = str(envelope.get("user_id", member.get("user_id", ""))).strip_edges()
	if user_id == "":
		user_id = "discord_user_%d" % int(Time.get_ticks_msec())

	var global_identity_id: String = "discord:%s" % user_id
	var world_id: String = str(world.get("world_id", envelope.get("world_container_id", "discord.guild.local"))).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var identity: Dictionary = eranet_identity_registry.get(global_identity_id, {}).duplicate(true) if typeof(eranet_identity_registry.get(global_identity_id, {})) == TYPE_DICTIONARY else {}
	if identity.is_empty():
		identity = {
			"schema": "eralife.eranet_identity",
			"version": 1,
			"global_identity_id": global_identity_id,
			"platform": "discord",
			"user_id": user_id,
			"username": str(envelope.get("username", member.get("username", user_id))),
			"worlds": {},
			"relationships": {},
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var worlds: Dictionary = identity.get("worlds", {}).duplicate(true) if typeof(identity.get("worlds", {})) == TYPE_DICTIONARY else {}
	worlds [world_id] = {
		"world_id": world_id,
		"guild_id": str(world.get("guild_id", envelope.get("guild_id", ""))),
		"era_key": str(world.get("era_key", "Modern")),
		"era_name": str(world.get("era_name", "Modern Era")),
		"life_node_id": str(member.get("life_node_id", envelope.get("life_node_id", user_id))),
		"name": str(member.get("name", member.get("username", identity.get("username", user_id)))),
		"age": int(member.get("age", 0)),
		"alive": bool(member.get("alive", true)),
		"relationship_status": str(member.get("relationship_status", "")),
		"last_seen_at_ms": int(Time.get_ticks_msec())
	}

	identity ["worlds"] = worlds
	identity ["username"] = str(envelope.get("username", identity.get("username", user_id)))
	identity ["last_seen_at_ms"] = int(Time.get_ticks_msec())

	eranet_identity_registry [global_identity_id] = identity
	return identity.duplicate(true)
func _eranet_register_world(
	world: Dictionary
) -> Dictionary:
	var world_id: String = str(
		world.get(
			"world_id",
			""
		)
	).strip_edges()

	if world_id == "":
		world_id = "discord.guild.local"

	var era_key: String = str(
		world.get(
			"era_key",
			"Modern"
		)
	).strip_edges()

	if era_key == "":
		era_key = "Modern"

	var guild_id: String = str(
		world.get(
			"guild_id",
			""
		)
	).strip_edges()



	var row: Dictionary = world.duplicate(false)

	row [
		"schema"
	] = "eralife.eranet_world_registry_row"
	row [
		"version"
	] = 1
	row [
		"world_id"
	] = world_id
	row [
		"guild_id"
	] = guild_id
	row [
		"era_key"
	] = era_key
	row [
		"discoverable"
	] = bool(
		world.get(
			"discoverable",
			true
		)
	)
	row [
		"global_events_enabled"
	] = bool(
		world.get(
			"global_events_enabled",
			true
		)
	)
	row [
		"private_events_enabled"
	] = bool(
		world.get(
			"private_events_enabled",
			true
		)
	)
	row [
		"registered_at_ms"
	] = int(
		row.get(
			"registered_at_ms",
			Time.get_ticks_msec()
		)
	)
	row [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	row [
		"recursive_world_copy_performed"
	] = false

	eranet_global_world_registry [
		world_id
	] = row

	if not eranet_world_routes.has(
		era_key
	):
		eranet_world_routes [
			era_key
		] = []

	var routes_raw: Variant = (
		eranet_world_routes.get(
			era_key,
			[]
		)
	)
	var routes: Array = (
		(routes_raw as Array).duplicate(false)
		if typeof(routes_raw) == TYPE_ARRAY
		else []
	)

	if world_id not in routes:
		routes.append(
			world_id
		)

	eranet_world_routes [
		era_key
	] = routes

	return row.duplicate(false)
func _discord_world_for_envelope(envelope: Dictionary) -> Dictionary:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	if discord_server_world_registry.has(world_id):
		return discord_server_world_registry.get(world_id, {}).duplicate(true)

	var world:= {
		"schema": "eralife.discord_server_world",
		"version": 1,
		"world_id": world_id,
		"guild_id": str(envelope.get("guild_id", "")),
		"era_key": "Modern",
		"era_name": "Modern Era",
		"year": 2026,
		"year_text": "2026 AD",
		"reality_mode": "realistic",
		"members": {},
		"couples": [],
		"started_by": "auto",
		"started_at_ms": int(Time.get_ticks_msec())
	}
	discord_server_world_registry [world_id] = world
	return world.duplicate(true)


func _discord_world_add_feed_event(world_id: String, text: String, color: int = 2829617) -> void:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = "discord.guild.local"

	var feed: Array = discord_world_event_registry.get(clean_world_id, []) if typeof(discord_world_event_registry.get(clean_world_id, [])) == TYPE_ARRAY else []
	feed.append({
		"text": text,
		"color": color,
		"created_at_ms": int(Time.get_ticks_msec())
	})

	while feed.size() > 50:
		feed.pop_front()

	discord_world_event_registry [clean_world_id] = feed
func _remote_shell_world_start(envelope: Dictionary) -> Dictionary:
	var guild_id: String = str(envelope.get("guild_id", "")).strip_edges()
	if guild_id == "":
		guild_id = str(envelope.get("world_container_id", "discord.guild.local")).strip_edges()

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var birth: Dictionary = envelope.get("birth", {}).duplicate(true) if typeof(envelope.get("birth", {})) == TYPE_DICTIONARY else {}
	var raw: Dictionary = envelope.get("raw", {}).duplicate(true) if typeof(envelope.get("raw", {})) == TYPE_DICTIONARY else {}
	var raw_theme: Dictionary = raw.get("theme", {}).duplicate(true) if typeof(raw.get("theme", {})) == TYPE_DICTIONARY else {}

	var world_id: String = str(envelope.get("world_container_id", "discord.guild.%s" % guild_id)).strip_edges()
	var era_name: String = str(birth.get("era_name", args.get("era_name", "Modern Era"))).strip_edges()
	var era_key: String = str(birth.get("era_key", args.get("era_key", "Modern"))).strip_edges()
	var year_value: int = int(birth.get("year", args.get("year", 2026)))
	var reality_mode: String = str(birth.get("reality_mode", args.get("reality_mode", "realistic"))).strip_edges().to_lower()
	var reality_name: String = str(birth.get("reality_name", args.get("reality_name", reality_mode.capitalize() + " Mode"))).strip_edges()
	var founding_month: int = clamp(int(birth.get("month", args.get("month", 1))), 1, 12)
	var founding_day: int = clamp(int(birth.get("day", args.get("day", 1))), 1, 31)
	var homeland: String = str(birth.get("country", args.get("country", ""))).strip_edges()
	var capital_city: String = str(birth.get("city", args.get("city", ""))).strip_edges()
	var founding_date_text: String = str(birth.get("founding_date_text", birth.get("birthday_text", ""))).strip_edges()
	if founding_date_text == "":
		founding_date_text = _remote_shell_month_name(founding_month) + " " + str(founding_day)

	var era_color: int = int(raw_theme.get("era_color", 3066993))
	var reality_color: int = int(raw_theme.get("reality_color", era_color))

	var world:= {
		"schema": "eralife.discord_server_world",
		"version": 3,
		"mode": "server",
		"world_mode": "server",
		"world_id": world_id,
		"guild_id": guild_id,
		"era_key": era_key,
		"era_name": era_name,
		"year": year_value,
		"year_text": _remote_shell_format_year(year_value),
		"reality_mode": reality_mode,
		"reality_name": reality_name,
		"founding_month": founding_month,
		"founding_day": founding_day,
		"founding_date_text": founding_date_text,
		"homeland": homeland,
		"capital_city": capital_city,
		"members": {},
		"couples": [],
		"economy": _eranet_world_default_economy({
			"world_id": world_id,
			"members": {}
		}),
		"timeline": {
			"schema": "eralife.eranet_shared_timeline",
			"version": 1,
			"auto_time": true,
			"seconds_per_year": max(10.0, float(args.get("seconds_per_year", 300.0))),
			"pending_year_progress": 0.0,
			"started_at_ms": int(Time.get_ticks_msec()),
			"last_tick_ms": int(Time.get_ticks_msec())
		},
		"factions": {},
		"wars": [],
		"auto_time": true,
		"discoverable": true,
		"global_events_enabled": bool(args.get("global_events_enabled", true)),
		"private_events_enabled": bool(args.get("private_events_enabled", true)),
		"started_by": str(envelope.get("user_id", "")),
		"started_by_username": str(envelope.get("username", "Someone")),
		"started_at_ms": int(Time.get_ticks_msec())
	}

	discord_server_world_registry [world_id] = world

	var registry_row: Dictionary = _eranet_register_world(world)
	_eranet_rebuild_global_economy_for_era(era_key)

	var feed_text: String = "%s founded a public EraLife civilization in %s, %s." % [
		str(envelope.get("username", "Someone")),
		era_name,
		_remote_shell_format_year(year_value)
	]

	if homeland != "":
		feed_text += " Homeland: %s." % homeland
	if capital_city != "":
		feed_text += " First capital: %s." % capital_city

	_discord_world_add_feed_event(world_id, feed_text, era_color)

	var location_line: String = ""
	if homeland != "" or capital_city != "":
		location_line = "\nHomeland: %s\nCapital: %s" % [
			homeland if homeland != "" else "Unclaimed",
			capital_city if capital_city != "" else "Unbuilt"
		]

	var text: String = "🌍 **A SERVER WORLD HAS BEEN FOUNDED.**\n\nThe gates opened, the timeline caught, and this Discord server now has a shared civilization container.\n\nEra: %s\nYear: %s\nReality Mode: %s\nFounding Day: %s%s\nAuto Time: ON\nEraNet: REGISTERED\n\nPlayers can now use `/server_world join` to enter the shared timeline." % [
		era_name,
		_remote_shell_format_year(year_value),
		reality_name,
		founding_date_text,
		location_line
	]

	return _remote_shell_response(true, envelope, "world.start", text, {
		"server_world": discord_server_world_registry [world_id].duplicate(true),
		"eranet_registry_row": registry_row,
		"theme": {
			"era_color": era_color,
			"reality_color": reality_color
		},
		"broadcast_events": [
			{
				"title": "🌍 EraLife Server World Founded",
				"text": "@%s HAS FOUNDED A SERVER WORLD IN %s, YEAR %s.\nUse /server_world join to enter the shared timeline." % [
					str(envelope.get("username", "Someone")),
					era_name,
					_remote_shell_format_year(year_value)
				],
				"color": era_color
			}
		]
	})

func _remote_shell_world_list(envelope: Dictionary) -> Dictionary:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	var current_world: Dictionary = _discord_world_for_envelope(envelope)
	var current_era: String = str(current_world.get("era_key", "Modern")).strip_edges()

	var rows: Array = []
	var lines: Array = []

	for raw_world_id in eranet_global_world_registry.keys():
		var other_raw: Variant = eranet_global_world_registry.get(raw_world_id, {})
		if typeof(other_raw) != TYPE_DICTIONARY:
			continue

		var other: Dictionary = (other_raw as Dictionary).duplicate(true)
		if not bool(other.get("discoverable", true)):
			continue

		if str(other.get("era_key", "")) != current_era:
			continue

		rows.append(other)
		lines.append("• %s — %s, %s — Members: %d" % [
			str(other.get("world_id", raw_world_id)),
			str(other.get("era_name", current_era)),
			str(other.get("year_text", "")),
			int(other.get("members", {}).size()) if typeof(other.get("members", {})) == TYPE_DICTIONARY else 0
		])

	var text: String = "No EraNet worlds are visible in this era yet."
	if not lines.is_empty():
		text = "EraNet worlds visible from %s:\n%s" % [
			current_era,
			"\n".join(lines)
		]

	return _remote_shell_response(true, envelope, "world.list", text, {
		"current_world_id": world_id,
		"era_key": current_era,
		"worlds": rows
	})


func _remote_shell_world_join(envelope: Dictionary) -> Dictionary:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	if not discord_server_world_registry.has(world_id):
		discord_server_world_registry [world_id] = {
			"schema": "eralife.discord_server_world",
			"version": 1,
			"world_id": world_id,
			"guild_id": str(envelope.get("guild_id", "")),
			"era_key": "Modern",
			"era_name": "Modern Era",
			"year": 2026,
			"year_text": "2026 AD",
			"reality_mode": "realistic",
			"members": {},
			"started_by": "auto",
			"started_at_ms": int(Time.get_ticks_msec())
		}

	var world: Dictionary = discord_server_world_registry.get(world_id, {}).duplicate(true)

	var members_raw: Variant = world.get("members", {})
	var members: Dictionary = {}
	if typeof(members_raw) == TYPE_DICTIONARY:
		members = (members_raw as Dictionary).duplicate(true)

	var user_id: String = str(envelope.get("user_id", "")).strip_edges()
	if user_id == "":
		user_id = "discord_user_%d" % int(Time.get_ticks_msec())

	members [user_id] = {
		"user_id": user_id,
		"username": str(envelope.get("username", user_id)),
		"life_node_id": str(envelope.get("life_node_id", user_id)),
		"joined_at_ms": int(Time.get_ticks_msec()),
		"online": true
	}

	world ["members"] = members
	discord_server_world_registry [world_id] = world

	var identity: Dictionary = _eranet_touch_identity(envelope, world, members [user_id])
	var registry_row: Dictionary = _eranet_register_world(world)
	_eranet_rebuild_global_economy_for_era(str(world.get("era_key", "Modern")))

	var era_text: String = str(world.get("era_name", "Modern Era"))
	var year_text: String = str(world.get("year_text", ""))
	if year_text == "":
		year_text = _remote_shell_format_year(int(world.get("year", 2026)))

	var response_text: String = "You joined the EraLife server world.\n\nEra:\n\t%s\nYear: %s\nSouls active in this timeline: %d" \
% [
		era_text,
		year_text,
		members.size()
	]

	var payload: Dictionary = {
		"server_world": world.duplicate(true),
		"eranet_identity": identity,
		"eranet_registry_row": registry_row,
		"global_economy": eranet_global_economy_registry.get(str(world.get("era_key", "Modern")), {}).duplicate(true) if typeof(eranet_global_economy_registry.get(str(world.get("era_key", "Modern")), {})) == TYPE_DICTIONARY else {}
	}

	return _remote_shell_response(true, envelope, "world.join", response_text, payload)


func _remote_shell_world_members(envelope: Dictionary) -> Dictionary:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var world: Dictionary = {}
	if discord_server_world_registry.has(world_id):
		world = discord_server_world_registry.get(world_id, {}).duplicate(true)

	if world.is_empty():
		return _remote_shell_response(true, envelope, "world.members", "No EraLife server world is active yet.", {
			"members": [],
			"online_count": 0
		})

	var members_raw: Variant = world.get("members", {})
	var members: Dictionary = {}
	if typeof(members_raw) == TYPE_DICTIONARY:
		members = (members_raw as Dictionary).duplicate(true)

	var lines: Array = []
	var rows: Array = []
	var online_count: int = 0

	for raw_key in members.keys():
		var member_raw: Variant = members.get(raw_key, {})
		var member: Dictionary = {}

		if typeof(member_raw) == TYPE_DICTIONARY:
			member = (member_raw as Dictionary).duplicate(true)
		else:
			member = {
				"user_id": str(raw_key),
				"username": str(raw_key),
				"online": false
			}

		rows.append(member)

		var username: String = str(member.get("username", raw_key))
		var is_online: bool = bool(member.get("online", true))
		var online_text: String = "active" if is_online else "dormant"

		if is_online:
			online_count += 1

		lines.append("• %s — %s" % [username, online_text])

	var response_text: String = "Souls active in this timeline: %d" % online_count
	if not lines.is_empty():
		response_text += "\n" + "\n".join(lines)

	return _remote_shell_response(true, envelope, "world.members", response_text, {
		"server_world": world.duplicate(true),
		"members": rows,
		"online_count": online_count,
		"souls_active_in_this_timeline": online_count
	})
func _remote_shell_world_feed(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var discord_feed: Array = discord_world_event_registry.get(world_id, []) if typeof(discord_world_event_registry.get(world_id, [])) == TYPE_ARRAY else []
	var game_feed: Array = []
	if gs_ref != null:
		game_feed = _remote_shell_world_feed_tail(gs_ref, 10)

	var combined: Array = []
	combined.append_array(discord_feed)
	combined.append_array(game_feed)

	var text: String = "The world is quiet."
	if not combined.is_empty():
		var rendered: Array = []
		for entry in combined.slice(max(0, combined.size() - 10), combined.size()):
			if typeof(entry) == TYPE_DICTIONARY:
				rendered.append(str((entry as Dictionary).get("text", entry)))
			else:
				rendered.append(str(entry))
		text = "\n".join(rendered)

	return _remote_shell_response(true, envelope, "world.feed", text, {
		"world_feed_tail": combined,
		"server_world": _discord_world_for_envelope(envelope),
		"world": _remote_shell_world_snapshot(gs_ref) if gs_ref != null else {}
	})


func _remote_shell_world_status(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "world.status", "GameState was not found yet.", {})

	return _remote_shell_response(true, envelope, "world.status", "EraLife runtime is online.", {
		"world": _remote_shell_world_snapshot(gs_ref),
		"bridge": _safe_remote_shell_status()
	})

func _remote_shell_ecl_compile(envelope: Dictionary) -> Dictionary:
	_ensure_ecl_language_engine()
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var script: String = str(args.get("script", args.get("ecl_script", "")))

	if script.strip_edges() == "":
		return _remote_shell_response(false, envelope, "ecl.compile", "No ECL script was provided.", {
			"expected_arg": "script"
		})

	var context: Dictionary = _ecl_context_from_envelope(envelope, args)
	var report: Dictionary = ecl_language_engine.compile_script(script, context)

	var text: String = "ECL compiled into %d queued-safe command envelope(s)." % int(report.get("envelope_count", 0))
	if not bool(report.get("success", false)):
		text = "ECL compile failed before runtime queueing."

	return _remote_shell_response(bool(report.get("success", false)), envelope, "ecl.compile", text, {
		"ecl": report
	})

func _remote_shell_ecl_queue(envelope: Dictionary) -> Dictionary:
	_ensure_ecl_language_engine()
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var script: String = str(args.get("script", args.get("ecl_script", "")))

	if script.strip_edges() == "":
		return _remote_shell_response(false, envelope, "ecl.queue", "No ECL script was provided.", {
			"expected_arg": "script"
		})

	var context: Dictionary = _ecl_context_from_envelope(envelope, args)
	var report: Dictionary = ecl_language_engine.queue_script(script, context)

	var text: String = "ECL accepted. %d command envelope(s) are queued. Nothing executed yet." % int(report.get("queued_count", 0))
	if not bool(report.get("success", false)):
		text = "ECL was not queued because contract compilation failed."

	return _remote_shell_response(bool(report.get("success", false)), envelope, "ecl.queue", text, {
		"ecl": report
	})

func _remote_shell_ecl_play(envelope: Dictionary) -> Dictionary:
	_ensure_ecl_language_engine()
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}

	var report: Dictionary = ecl_language_engine.drain_queued_runtime(args, Callable(self, "_execute_queued_ecl_envelope"))

	var text: String = "ECL runtime queue played %d command envelope(s)." % int(report.get("executed_count", 0))
	if int(report.get("failed_count", 0)) > 0:
		text += " %d queued envelope(s) failed contract execution." % int(report.get("failed_count", 0))

	return _remote_shell_response(bool(report.get("success", false)), envelope, "ecl.play", text, {
		"ecl": report
	})

func _remote_shell_ecl_status(envelope: Dictionary) -> Dictionary:
	_ensure_ecl_language_engine()
	var snapshot: Dictionary = ecl_language_engine.export_debug_snapshot()

	return _remote_shell_response(true, envelope, "ecl.status", "ECL runtime is online.", {
		"ecl": snapshot
	})

func _remote_shell_ecl_clear(envelope: Dictionary) -> Dictionary:
	_ensure_ecl_language_engine()
	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var report: Dictionary = ecl_language_engine.clear_queue(str(args.get("reason", "remote_shell_clear")))

	return _remote_shell_response(true, envelope, "ecl.clear", "ECL runtime queue cleared.", {
		"ecl": report
	})

func _execute_queued_ecl_envelope(
	envelope: Dictionary
) -> Dictionary:
	var normalized: Dictionary = _normalize_remote_shell_envelope(
		envelope
	)
	var command_id: String = str(
		normalized.get("command_id", "")
	).strip_edges().to_lower()

	if command_id.begins_with("ecl."):
		return _remote_shell_response(
			false,
			normalized,
			command_id,
			"Nested ECL runtime commands are not allowed inside ECL scripts.",
			{
				"reason": "nested_ecl_command_rejected"
			}
		)

	return _dispatch_remote_shell_envelope(envelope)

func _ecl_context_from_envelope(envelope: Dictionary, args: Dictionary = {}) -> Dictionary:
	var source:= {
		"adapter": str(envelope.get("adapter", "ecl")),
		"platform": str(envelope.get("platform", "remote_shell")),
		"guild_id": str(envelope.get("guild_id", "")),
		"channel_id": str(envelope.get("channel_id", "")),
		"user_id": str(envelope.get("user_id", "ecl_user")),
		"username": str(envelope.get("username", ""))
	}

	var world:= {
		"container_id": str(envelope.get("world_container_id", "ecl.local.world")),
		"mode": str(envelope.get("world_mode", "solo"))
	}

	var life_identity:= {
		"life_node_id": str(envelope.get("life_node_id", source.get("user_id", "ecl_user"))),
		"external_user_id": str(envelope.get("external_user_id", source.get("user_id", "")))
	}

	return {
		"script_id": str(args.get("script_id", "")),
		"queue_id": str(args.get("queue_id", "")),
		"source": source,
		"world": world,
		"life_identity": life_identity,
		"request_id": str(envelope.get("request_id", "")),
	}

func _ensure_ecl_language_engine() -> void:
	if ecl_language_engine == null:
		ecl_language_engine = ECLContractLanguageEngine.new(_resolve_game_state(), {
			"id": "self_host_remote_shell_ecl_contract",
			"allow_unknown_future_commands": true
		})

func _safe_ecl_status() -> Dictionary:
	_ensure_ecl_language_engine()
	if ecl_language_engine == null:
		return {
			"schema": "eralife.ecl_status",
			"version": CONTRACT_VERSION,
			"enabled": false,
			"reason": "ECL engine unavailable."
		}

	var snapshot: Dictionary = ecl_language_engine.export_debug_snapshot()
	snapshot ["enabled"] = true
	snapshot ["queue_mode"] = "queued_runtime_only"
	snapshot ["paste_script_command"] = "ecl.queue"
	snapshot ["play_command"] = "ecl.play"
	return snapshot
func _ensure_birth_contract_engine(gs_ref = null):
	var active_gs = gs_ref if gs_ref != null else _resolve_game_state()
	if active_gs == null:
		return null

	if active_gs.has_method("get"):
		var existing = active_gs.get("birth_contract_engine")
		if existing != null:
			return existing

	var created = BirthContractEngine.new(active_gs)

	if "birth_contract_engine" in active_gs:
		active_gs.birth_contract_engine = created

	return created


func _ensure_embedded_ui_contract_engine(gs_ref = null):
	var active_gs = gs_ref if gs_ref != null else _resolve_game_state()
	if active_gs == null:
		return null

	if active_gs.has_method("get"):
		var existing = active_gs.get("embedded_ui_contract_engine")
		if existing != null:
			return existing

	var created = EmbeddedUIContractEngine.new(active_gs)

	if "embedded_ui_contract_engine" in active_gs:
		active_gs.embedded_ui_contract_engine = created

	return created


func _remote_shell_surface_id_for_command(command_id: String, args: Dictionary = {}) -> String:
	var explicit_surface: String = str(args.get("surface_id", args.get("surface", ""))).strip_edges()
	if explicit_surface != "":
		return explicit_surface

	match str(command_id).strip_edges().to_lower():
		"life.home", "life.hub", "ui.home", "discord.life_hub":
			return "discord_life_hub"
		"life.shop":
			return "bank_contract_hub"
		"life.restaurant":
			return "restaurant_contract_hub"
		"life.grocery":
			return "grocery_contract_hub"
		"life.luxury_shop":
			return "luxury_contract_hub"
		"life.inventory":
			return "inventory_contract_hub"
		"life.jobs":
			return "career_contract_hub"
		"life.school":
			return "school_contract_hub"
		"bank.status", "bank.balance", "bank.summary":
			return "bank_contract_hub"
		_:
			return ""


func _remote_shell_embedded_ui_context(envelope: Dictionary, args: Dictionary = {}) -> Dictionary:
	return {
		"platform": str(args.get("platform", envelope.get("platform", "discord"))),
		"adapter": str(envelope.get("adapter", "discord.js")),
		"device_profile": str(args.get("device_profile", "phone")),
		"ephemeral": bool(args.get("ephemeral", false)),
		"guild_id": str(envelope.get("guild_id", "")),
		"channel_id": str(envelope.get("channel_id", "")),
		"user_id": str(envelope.get("user_id", "")),
		"username": str(envelope.get("username", "")),
		"world_mode": str(envelope.get("world_mode", "solo")),
		"world_container_id": str(envelope.get("world_container_id", "")),
		"life_node_id": str(envelope.get("life_node_id", "")),
		"external_user_id": str(envelope.get("external_user_id", "")),
		"era_color": int(args.get("era_color", 2829617)),
		"reality_color": int(args.get("reality_color", 2829617))
	}


func _remote_shell_ui_render(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "ui.render", "GameState was not found yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var command_id: String = str(envelope.get("command_id", "ui.render")).strip_edges().to_lower()
	var surface_id: String = _remote_shell_surface_id_for_command(command_id, args)

	if surface_id == "":
		surface_id = str(args.get("surface_id", args.get("surface", ""))).strip_edges()

	if surface_id == "":
		return _remote_shell_response(false, envelope, "ui.render", "No embedded UI surface_id was provided.", {})

	var embedded_engine = _ensure_embedded_ui_contract_engine(gs_ref)
	if embedded_engine == null:
		return _remote_shell_response(false, envelope, "ui.render", "EmbeddedUIContractEngine is not available yet.", {})

	var context: Dictionary = _remote_shell_embedded_ui_context(envelope, args)
	var report: Dictionary = embedded_engine.render_surface(surface_id, context)

	return _remote_shell_response(bool(report.get("success", false)), envelope, "ui.render", str(report.get("text", "Embedded UI surface rendered.")), {
		"embedded_ui": report,
		"ui_model": report.get("render_model", {}),
		"surface_id": surface_id,
		"player": _remote_shell_player_snapshot(gs_ref)
	})
func _remote_shell_causality_inversion_intent(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "reality.invert", "GameState was not found yet.", {})

	var actor = gs_ref.player if "player" in gs_ref else null
	if actor == null:
		return _remote_shell_response(false, envelope, "reality.invert", "No playable life is hydrated yet.", {
			"local_shell": {
				"visibility_state": "visible",
				"interaction_state": "buffered",
				"execution_state": "deferred",
				"text": "The remote runtime heard the intent, but no identity anchor is live yet."
			}
		})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var command_id: String = str(envelope.get("command_id", "reality.invert")).strip_edges().to_lower()
	var action_id: String = str(args.get("action_id", args.get("action", command_id))).strip_edges().to_lower()

	match command_id:
		"hero.track_villain":
			action_id = "track_villain"
		"hero.recruit_sidekick", "hero.recruit_ally":
			action_id = "recruit_ally"
		"hero.create_team":
			action_id = "start_team"
		"bending.find_duel", "bending.seek_duel":
			action_id = "seek_bending_duel"

	var domain_id: String = str(args.get("domain", "")).strip_edges().to_lower()
	if domain_id == "":
		if action_id in ["track_villain", "respond_to_crime", "patrol_city"]:
			domain_id = "villains"
		elif action_id in ["recruit_ally", "recruit_sidekick", "start_team"]:
			domain_id = "sidekicks"
		elif action_id.find("duel") >= 0:
			domain_id = "bending_duels"
		else:
			domain_id = "runtime"

	if not gs_ref.has_method("resolve_causality_inverted_intent"):
		return _remote_shell_response(false, envelope, "reality.invert", "Causality inversion is not wired into GameState yet.", {})

	var report: Dictionary = gs_ref.resolve_causality_inverted_intent(actor, {
		"action_id": action_id,
		"domain": domain_id,
		"payload": args.duplicate(true),
		"resolution_strategy": str(args.get("resolution_strategy", "generate_if_missing")),
		"constraint_weights": args.get("constraint_weights", {}),
		"generation_policy": args.get("generation_policy", {})
	}, {
		"source": "self_host_runtime_layer",
		"remote_truth_layer": true,
		"platform": str(envelope.get("platform", "discord")),
		"guild_id": str(envelope.get("guild_id", "")),
		"user_id": str(envelope.get("user_id", "")),
		"world_container_id": str(envelope.get("world_container_id", "")),
		"life_node_id": str(envelope.get("life_node_id", ""))
	})

	var text: String = str(report.get("text", report.get("popup_text", "Reality intent resolved.")))
	return _remote_shell_response(bool(report.get("success", false)), envelope, "reality.invert", text, {
		"causality": report.duplicate(true),
		"canonical_truth": report.get("canonical_truth", {}),
		"reality_composition": report.get("reality_composition", {}),
		"player": _remote_shell_player_snapshot(gs_ref)
	})

func _remote_shell_ui_action(envelope: Dictionary) -> Dictionary:
	var gs_ref = _resolve_game_state()
	if gs_ref == null:
		return _remote_shell_response(false, envelope, "ui.action", "GameState was not found yet.", {})

	var args: Dictionary = envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	var surface_id: String = str(args.get("surface_id", args.get("surface", ""))).strip_edges()
	var action_id: String = str(args.get("action_id", args.get("action", ""))).strip_edges()

	if surface_id == "":
		return _remote_shell_response(false, envelope, "ui.action", "No embedded UI surface_id was provided.", {})

	if action_id == "":
		return _remote_shell_response(false, envelope, "ui.action", "No embedded UI action_id was provided.", {})

	var payload: Dictionary = args.get("payload", {}).duplicate(true) if typeof(args.get("payload", {})) == TYPE_DICTIONARY else {}
	var context: Dictionary = _remote_shell_embedded_ui_context(envelope, args)

	var embedded_engine = _ensure_embedded_ui_contract_engine(gs_ref)
	if embedded_engine == null:
		return _remote_shell_response(false, envelope, "ui.action", "EmbeddedUIContractEngine is not available yet.", {})

	var report: Dictionary = embedded_engine.route_interaction(surface_id, action_id, payload, context)

	return _remote_shell_response(bool(report.get("success", false)), envelope, "ui.action", "Embedded UI action routed.", {
		"embedded_ui": report.get("render_report", report),
		"ui_route": report,
		"surface_id": surface_id,
		"action_id": action_id,
		"player": _remote_shell_player_snapshot(gs_ref)
	})
func _remote_shell_contract_ack(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command_id", "unknown"))
	return _remote_shell_response(true, envelope, command_id, "Command contract accepted. No runtime adapter is wired for this verb yet.", {
		"command_id": command_id,
		"args": envelope.get("args", {}).duplicate(true) if typeof(envelope.get("args", {})) == TYPE_DICTIONARY else {}
	})


func _remote_shell_response(success: bool, envelope: Dictionary, command_id: String, text: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.remote_shell_response",
		"version": REMOTE_SHELL_VERSION,
		"success": success,
		"command_id": command_id,
		"request_id": str(envelope.get("request_id", "")),
		"world_container_id": str(envelope.get("world_container_id", "")),
		"life_node_id": str(envelope.get("life_node_id", "")),
		"text": text,
		"payload": payload.duplicate(true),
		"render": {
			"adapter": "discord",
			"style": "terminal_panel",
			"ephemeral": command_id in ["life.stats", "life.diary"]
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _remote_shell_player_snapshot(gs_ref) -> Dictionary:
	var p = gs_ref.player if gs_ref != null and "player" in gs_ref else null
	if p == null:
		return {}

	var full_name: String = ("%s %s" % [str(p.first_name),
str(p.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(p.name).strip_edges() if "name" in p else "Unknown Life"

	var year_value: int = int(gs_ref.year) if "year" in gs_ref else 0
	var bank_summary: Dictionary = {}
	if gs_ref != null and "bank_engine" in gs_ref and gs_ref.bank_engine != null:
		if gs_ref.bank_engine.has_method("repair_legacy_player_money_mirror"):
			gs_ref.bank_engine.repair_legacy_player_money_mirror()
		if gs_ref.bank_engine.has_method("get_owner_summary_for_actor"):
			bank_summary = gs_ref.bank_engine.get_owner_summary_for_actor(p, {})

	return {
		"id": int(p.id) if "id" in p else -1,
		"name": full_name,
		"first_name": str(p.first_name) if "first_name" in p else "",
		"last_name": str(p.last_name) if "last_name" in p else "",
		"gender": str(p.gender) if "gender" in p else "",
		"age": int(p.age) if "age" in p else 0,
		"alive": bool(p.alive) if "alive" in p else true,
		"year": year_value,
		"year_text": _remote_shell_format_year(year_value),
		"health": clamp(float(p.health) if "health" in p else 0.0, 0.0, 100.0),
		"mental": clamp(float(p.mental_health) if "mental_health" in p else 0.0, 0.0, 100.0),
		"hunger": clamp(float(p.hunger) if "hunger" in p else 0.0, 0.0, 100.0),
		"happiness": clamp(float(p.satisfaction) if "satisfaction" in p else 0.0, 0.0, 100.0),
		"looks": clamp(float(p.looks) if "looks" in p else 0.0, 0.0, 100.0),
		"smarts": clamp(float(p.smarts) if "smarts" in p else 0.0, 0.0, 100.0),
		"imagination": clamp(float(p.imagination) if "imagination" in p else 0.0, 0.0, 100.0),
		"fame": clamp(float(p.fame) if "fame" in p else 0.0, 0.0, 100.0),
		"money": float(bank_summary.get("total_accessible", float(p.bank_balance) if "bank_balance" in p else 0.0)),
		"cash_on_hand": float(bank_summary.get("cash_on_hand", 0.0)),
		"bank_balance": float(bank_summary.get("bank_balance", float(p.bank_balance) if "bank_balance" in p else 0.0)),
		"interworld_credit": float(bank_summary.get("interworld_credit", 0.0)),
		"money_authority": "bank_engine" if not bank_summary.is_empty() else "legacy_bank_balance",
		"country": str(p.home_country) if "home_country" in p else "",
		"city": str(p.home_city) if "home_city" in p else "",
		"birth_country": str(p.birth_country) if "birth_country" in p else "",
		"birth_city": str(p.birth_city) if "birth_city" in p else "",
		"job": str(p.job) if "job" in p else "",
		"social_class": str(p.social_class) if "social_class" in p else "",
		"birthday_text": str(p.birthday_text) if "birthday_text" in p else "",
		"zodiac_sign": str(p.zodiac_sign) if "zodiac_sign" in p else "",
		"birth_month": int(p.birth_month) if "birth_month" in p else 0,
		"birth_day": int(p.birth_day) if "birth_day" in p else 0,
	}


func _remote_shell_stat_bars(snapshot: Dictionary) -> Dictionary:
	return {
		"health": _remote_shell_bar(float(snapshot.get("health", 0.0))),
		"mental": _remote_shell_bar(float(snapshot.get("mental", 0.0))),
		"hunger": _remote_shell_bar(float(snapshot.get("hunger", 0.0))),
		"happiness": _remote_shell_bar(float(snapshot.get("happiness", 0.0))),
		"looks": _remote_shell_bar(float(snapshot.get("looks", 0.0))),
		"imagination": _remote_shell_bar(float(snapshot.get("imagination", 0.0))),
		"fame": _remote_shell_bar(float(snapshot.get("fame", 0.0)))
	}


func _remote_shell_bar(value: float, segments: int = 10) -> String:
	var clamped: float = clamp(value, 0.0, 100.0)
	var filled: int = int(round((clamped / 100.0) * float(segments)))
	var out: String = ""
	for i in range(segments):
		out += "▰" if i < filled else "▱"
	return "%s %d" % [out, int(round(clamped))]


func _remote_shell_world_snapshot(gs_ref) -> Dictionary:
	if gs_ref == null:
		return {}

	return {
		"year": int(gs_ref.year) if "year" in gs_ref else 0,
		"year_text": _remote_shell_format_year(int(gs_ref.year) if "year" in gs_ref else 0),
		"npc_count": int(gs_ref.npcs.size()) if "npcs" in gs_ref and typeof(gs_ref.npcs) == TYPE_ARRAY else 0,
		"world_feed_count": int(gs_ref.world_feed.size()) if "world_feed" in gs_ref and typeof(gs_ref.world_feed) == TYPE_ARRAY else 0
	}

func _remote_shell_sync_server_member_from_player(envelope: Dictionary, snapshot: Dictionary, settings: Dictionary) -> void:
	var world_id: String = str(envelope.get("world_container_id", "")).strip_edges()
	if world_id == "":
		world_id = "discord.guild.local"

	var world: Dictionary = _discord_world_for_envelope(envelope)
	var members: Dictionary = world.get("members", {}).duplicate(true) if typeof(world.get("members", {})) == TYPE_DICTIONARY else {}

	var user_id: String = str(envelope.get("user_id", "")).strip_edges()
	if user_id == "":
		user_id = "discord_user_%d" % int(Time.get_ticks_msec())

	members [user_id] = {
		"user_id": user_id,
		"username": str(envelope.get("username", user_id)),
		"life_node_id": str(envelope.get("life_node_id", user_id)),
		"name": str(snapshot.get("name", settings.get("name", user_id))),
		"age": int(snapshot.get("age", 0)),
		"alive": true,
		"birth_year": int(settings.get("year", world.get("year", 2026))),
		"era_key": str(settings.get("era_key", world.get("era_key", "Modern"))),
		"reality_mode": str(settings.get("reality_mode", world.get("reality_mode", "realistic"))),
		"joined_at_ms": int(Time.get_ticks_msec()),
		"online": true
	}

	world ["members"] = members
	discord_server_world_registry [world_id] = world

	_eranet_touch_identity(envelope, world, members [user_id])
	_eranet_register_world(world)
	_eranet_rebuild_global_economy_for_era(str(world.get("era_key", "Modern")))

	_discord_world_add_feed_event(world_id, "%s was born into the server world." % str(members [user_id].get("name", user_id)), int(settings.get("era_color", 2829617)))
func _remote_shell_world_feed_tail(gs_ref, max_count: int = 10) -> Array:
	if gs_ref == null or not ("world_feed" in gs_ref):
		return []

	var feed_raw: Variant = gs_ref.world_feed
	if typeof(feed_raw) != TYPE_ARRAY:
		return []

	var feed: Array = (feed_raw as Array).duplicate(true)
	var start_idx: int = max(0, feed.size() - max_count)
	return feed.slice(start_idx, feed.size())


func _resolve_game_state():
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return null

	var tree: SceneTree = main_loop as SceneTree
	if tree.root == null:
		return null

	var direct: Node = tree.root.get_node_or_null("GameState")
	if direct != null:
		return direct

	for child in tree.root.get_children():
		if child == null:
			continue
		if "gs" in child and child.get("gs") != null:
			return child.get("gs")
		if "game_state" in child and child.get("game_state") != null:
			return child.get("game_state")

	return null


func _remote_shell_request_line(header_text: String) -> String:
	var lines: PackedStringArray = header_text.split("
\n", false)
	if lines.size() <= 0:
		return ""
	return str(lines [0])


func _remote_shell_request_method(request_line: String) -> String:
	var parts: PackedStringArray = request_line.split(" ", false)
	if parts.size() <= 0:
		return ""
	return str(parts [0]).strip_edges().to_upper()


func _remote_shell_request_path(request_line: String) -> String:
	var parts: PackedStringArray = request_line.split(" ", false)
	if parts.size() < 2:
		return ""

	return _remote_shell_normalize_path(str(parts [1]).strip_edges())
func _remote_shell_normalize_path(path: String) -> String:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "":
		return ""

	var scheme_idx: int = clean_path.find("://")
	if scheme_idx >= 0:
		var authority_end: int = clean_path.find("/", scheme_idx + 3)
		if authority_end >= 0:
			clean_path = clean_path.substr(authority_end)
		else:
			clean_path = "/"

	var query_idx: int = clean_path.find("?")
	if query_idx >= 0:
		clean_path = clean_path.substr(0, query_idx)

	var fragment_idx: int = clean_path.find("#")
	if fragment_idx >= 0:
		clean_path = clean_path.substr(0, fragment_idx)

	if not clean_path.begins_with("/"):
		clean_path = "/%s" % clean_path

	while clean_path.length() > 1 and clean_path.ends_with("/"):
		clean_path = clean_path.substr(0, clean_path.length() - 1)

	return clean_path


func _remote_shell_content_length(header_text: String) -> int:
	var headers: Dictionary = _remote_shell_headers(header_text)
	return int(headers.get("content-length", 0))


func _remote_shell_headers(header_text: String) -> Dictionary:
	var out: Dictionary = {}
	var lines: PackedStringArray = header_text.split("
\n", false)
	for i in range(1, lines.size()):
		var line: String = str(lines [i])
		var colon: int = line.find(":")
		if colon < 0:
			continue
		var key: String = line.substr(0, colon).strip_edges().to_lower()
		var value: String = line.substr(colon + 1).strip_edges()
		if key != "":
			out [key] = value
	return out


func _remote_shell_auth_ok(
	header_text: String
) -> bool:
	if not _remote_shell_local_key_is_acceptable(
		local_config
	):
		return false

	var headers: Dictionary = (
		_remote_shell_headers(header_text)
	)
	var provided: String = str(
		headers.get(
			"x-eralife-remote-key",
			""
		)
	).strip_edges()
	var expected: String = str(
		local_config.get(
			"remote_shell_key",
			""
		)
	).strip_edges()

	if provided == "":
		return false

	var crypto:= Crypto.new()
	return crypto.constant_time_compare(
		expected.to_utf8_buffer(),
		provided.to_utf8_buffer()
	)


func _remote_shell_requires_key() -> bool:
	return true


func _remote_shell_local_key_is_acceptable(
	config: Dictionary
) -> bool:
	if config.is_empty():
		return false

	var key: String = str(
		config.get(
			"remote_shell_key",
			""
		)
	).strip_edges()

	return (
		key != ""
		and key.to_utf8_buffer().size()
		>= REMOTE_SHELL_MIN_KEY_BYTES
	)


func _remote_shell_bind_host_is_loopback(
	bind_host: String
) -> bool:
	var clean_host: String = str(
		bind_host
	).strip_edges().to_lower()

	return clean_host in [
		"127.0.0.1",
		"::1",
		"localhost"
	]

func _send_remote_shell_error(peer: StreamPeerTCP, status_code: int, reason: String) -> void:
	if peer == null:
		return
	peer.put_data(_remote_shell_http_response(status_code, {
		"schema": "eralife.remote_shell_error",
		"version": REMOTE_SHELL_VERSION,
		"success": false,
		"reason": reason
	}))


func _remote_shell_http_response(status_code: int, payload: Dictionary) -> PackedByteArray:
	var reason: String = "OK"
	match status_code:
		200:
			reason = "OK"
		204:
			reason = "No Content"
		400:
			reason = "Bad Request"
		401:
			reason = "Unauthorized"
		404:
			reason = "Not Found"
		405:
			reason = "Method Not Allowed"
		413:
			reason = "Payload Too Large"
		422:
			reason = "Unprocessable Entity"
		_:
			reason = "OK"

	var body: String = JSON.stringify(payload)
	var body_bytes: PackedByteArray = body.to_utf8_buffer()

	var raw: String = "HTTP/1.1 %d %s
\nContent-Type: application/json; charset=utf-8
\nContent-Length: %d
\nAccess-Control-Allow-Origin: *
\nAccess-Control-Allow-Headers: content-type,x-eralife-remote-key
\nAccess-Control-Allow-Methods: GET,POST,OPTIONS
\nConnection: close
\n
\n%s" % [
		status_code,
		reason,
		body_bytes.size(),
		body
	]

	return raw.to_utf8_buffer()


func _read_remote_shell_contract(contract: Dictionary = {}) -> Dictionary:
	var source: Dictionary = contract if not contract.is_empty() else active_contract
	var remote_raw: Variant = source.get("remote_shell", {})
	return remote_raw.duplicate(true) if typeof(remote_raw) == TYPE_DICTIONARY else {}


func _safe_remote_shell_status() -> Dictionary:
	if local_config.is_empty():
		local_config = load_local_config()

	var bind_host: String = str(
		local_config.get(
			"remote_shell_bind_host",
			DEFAULT_REMOTE_SHELL_BIND_HOST
		)
	).strip_edges()
	if bind_host == "":
		bind_host = DEFAULT_REMOTE_SHELL_BIND_HOST

	var port: int = int(
		local_config.get(
			"remote_shell_port",
			DEFAULT_REMOTE_SHELL_PORT
		)
	)
	if port <= 0:
		port = DEFAULT_REMOTE_SHELL_PORT

	return {
		"schema": "eralife.remote_shell_status",
		"version": REMOTE_SHELL_VERSION,
		"enabled": remote_shell_enabled,
		"listening": (
			remote_shell_server != null
			and remote_shell_server.is_listening()
		),
		"bind_host": bind_host,
		"port": port,
		"command_url": (
			"http://%s:%d/eralife/remote-shell/command"
			% [bind_host, port]
		),
		"status_url": (
			"http://%s:%d/eralife/remote-shell/status"
			% [bind_host, port]
		),
		"client_count": remote_shell_clients.size(),
		"explicit_local_opt_in": bool(
			local_config.get(
				"remote_shell_explicit_local_opt_in",
				false
			)
		),
		"allow_non_loopback": bool(
			local_config.get(
				"remote_shell_allow_non_loopback",
				false
			)
		),
		"key_configured": (
			_remote_shell_local_key_is_acceptable(
				local_config
			)
		),
		"token_echoed": false
	}
func _remote_shell_format_year(year_value: int) -> String:
	if year_value < 0:
		return "%d BC" % abs(year_value)
	return "%d AD" % year_value

func _on_duckdns_tick() -> void:
	_tick_duckdns_update("timer_tick")

func _tick_duckdns_update(reason: String = "") -> void:
	if update_in_flight:
		return

	if active_contract.is_empty():
		last_duckdns_report = _build_duckdns_report(false, "no_active_self_host_contract", reason)
		_persist_runtime_status()
		return

	if not _should_enable_duckdns(active_contract):
		last_duckdns_report = _build_duckdns_report(false, "duckdns_disabled_by_contract", reason)
		_persist_runtime_status()
		return

	if not _has_local_duckdns_token():
		last_duckdns_report = _build_duckdns_report(false, "missing_local_duckdns_token", reason)
		_persist_runtime_status()
		return

	var update_url: String = _build_duckdns_update_url()
	if update_url == "":
		last_duckdns_report = _build_duckdns_report(false, "duckdns_update_url_unavailable", reason)
		_persist_runtime_status()
		return

	update_in_flight = true
	var err: int = http_request.request(update_url)
	if err != OK:
		update_in_flight = false
		last_duckdns_report = _build_duckdns_report(false, "http_request_failed_%d" % err, reason)
		_persist_runtime_status()

func _on_duckdns_update_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	update_in_flight = false

	var body_text: String = body.get_string_from_utf8().strip_edges()
	var success: bool = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and body_text.to_upper().begins_with("OK")

	last_duckdns_report = {
		"schema": "eralife.duckdns_update_report",
		"version": CONTRACT_VERSION,
		"success": success,
		"result": result,
		"response_code": response_code,
		"body": body_text,
		"public_play_url": _read_public_play_url(),
		"duckdns_domain": str(_read_duckdns_contract().get("domain", "")),
		"token_echoed": false,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	_persist_runtime_status()

func _build_duckdns_update_url() -> String:
	var duckdns: Dictionary = _read_duckdns_contract()
	var template: String = str(duckdns.get("update_url_template", "")).strip_edges()
	if template == "":
		return ""

	var token: String = str(local_config.get("duckdns_token", "")).strip_edges()
	if token == "":
		return ""

	var public_ip: String = str(local_config.get("public_ip_override", "")).strip_edges()
	return template.replace("{DUCKDNS_TOKEN}", token).replace("{PUBLIC_IP}", public_ip)

func _sanitize_self_host_contract(contract: Dictionary) -> Dictionary:
	var safe_contract: Dictionary = contract.duplicate(true)
	safe_contract.erase("duckdns_token")
	safe_contract.erase("remote_shell_key")

	var duckdns_raw: Variant = safe_contract.get("duckdns", {})
	if typeof(duckdns_raw) == TYPE_DICTIONARY:
		var duckdns: Dictionary = (duckdns_raw as Dictionary).duplicate(true)
		duckdns.erase("token")
		duckdns.erase("duckdns_token")
		duckdns ["token_persisted"] = false
		duckdns ["token_storage"] = "local_private_config_only"
		duckdns ["never_write_token_to_capsule"] = true
		duckdns ["never_write_token_to_share_url"] = true
		safe_contract ["duckdns"] = duckdns

	var remote_raw: Variant = safe_contract.get("remote_shell", {})
	if typeof(remote_raw) == TYPE_DICTIONARY:
		var remote_shell: Dictionary = (remote_raw as Dictionary).duplicate(true)
		remote_shell.erase("token")
		remote_shell.erase("secret")
		remote_shell.erase("shared_secret")
		remote_shell.erase("remote_shell_key")
		remote_shell ["token_persisted"] = false
		remote_shell ["token_storage"] = "local_private_config_only"
		remote_shell ["never_write_token_to_capsule"] = true
		remote_shell ["never_write_token_to_share_url"] = true
		safe_contract ["remote_shell"] = remote_shell

	return safe_contract

func _should_enable_duckdns(contract: Dictionary) -> bool:
	if contract.is_empty():
		return false

	var duckdns: Dictionary = _read_duckdns_contract(contract)
	return bool(contract.get("enabled", false)) and bool(duckdns.get("enabled", false)) and bool(duckdns.get("token_configured", false))

func _read_duckdns_contract(contract: Dictionary = {}) -> Dictionary:
	var source: Dictionary = contract if not contract.is_empty() else active_contract
	var duckdns_raw: Variant = source.get("duckdns", {})
	return duckdns_raw.duplicate(true) if typeof(duckdns_raw) == TYPE_DICTIONARY else {}

func _read_public_play_url() -> String:
	var links_raw: Variant = active_contract.get("links", {})
	if typeof(links_raw) != TYPE_DICTIONARY:
		return ""
	return str((links_raw as Dictionary).get("public_play_url", "")).strip_edges()

func _safe_duckdns_status() -> Dictionary:
	var duckdns: Dictionary = _read_duckdns_contract()
	return {
		"enabled": bool(duckdns.get("enabled", false)),
		"domain": str(duckdns.get("domain", "")),
		"public_host": str(duckdns.get("public_host", "")),
		"token_configured_by_contract": bool(duckdns.get("token_configured", false)),
		"token_configured_locally": _has_local_duckdns_token(),
		"token_echoed": false
	}

func _has_local_duckdns_token() -> bool:
	return str(local_config.get("duckdns_token", "")).strip_edges() != ""

func _resolve_duckdns_interval_sec() -> float:
	var background_task_raw: Variant = active_contract.get("background_tasks", {})
	if typeof(background_task_raw) == TYPE_DICTIONARY:
		var duckdns_raw: Variant = (background_task_raw as Dictionary).get("duckdns_updater", {})
		if typeof(duckdns_raw) == TYPE_DICTIONARY:
			return float((duckdns_raw as Dictionary).get("interval_sec", DEFAULT_DUCKDNS_INTERVAL_SEC))

	return DEFAULT_DUCKDNS_INTERVAL_SEC

func _build_duckdns_report(success: bool, reason: String, tick_reason: String = "") -> Dictionary:
	return {
		"schema": "eralife.duckdns_update_report",
		"version": CONTRACT_VERSION,
		"success": success,
		"reason": reason,
		"tick_reason": tick_reason,
		"public_play_url": _read_public_play_url(),
		"duckdns_domain": str(_read_duckdns_contract().get("domain", "")),
		"token_echoed": false,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func _persist_runtime_status() -> void:
	var status_path:= "user://self_host_runtime_status.json"
	_write_json(status_path, get_runtime_status())

func _write_json(path: String, data: Dictionary) -> void:
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()