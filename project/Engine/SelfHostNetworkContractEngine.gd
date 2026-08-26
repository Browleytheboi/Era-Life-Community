extends Resource
class_name SelfHostNetworkContractEngine

const ENGINE_SCHEMA:= "eralife.self_host_network_contract_engine"
const CONTRACT_VERSION:= 1
const NETWORK_REGISTRY_PATH:= "user://identity/self_host_network_registry.json"

var gs
var network_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()

func publish_local_reality_presence(
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
			"Sign into an ErAccount to publish SelfHost presence.",
			context
		)

	var presence: Dictionary = _build_presence(
		identity_context,
		context
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var username_key: String = (
		username.to_lower()
	)
	var runtime_id: String = str(
		presence.get(
			"runtime_id",
			""
		)
	).strip_edges()
	var nodes: Dictionary = (
		_safe_dictionary(
			network_registry.get(
				"nodes",
				{}
			)
		)
	)

	nodes [username_key] = (
		presence.duplicate(true)
	)

	if runtime_id != "":
		nodes [runtime_id] = (
			presence.duplicate(true)
		)

	network_registry ["nodes"] = nodes
	network_registry ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	_write_registry()

	var stream_report: Dictionary = {}
	var life_id: String = str(
		presence.get(
			"life_id",
			""
		)
	).strip_edges()
	var announcement_key: String = (
		"%s|%s"
		% [
			str(
				presence.get(
					"identity_id",
					""
				)
			),
			life_id
		]
	)
	var already_announced: bool = false

	if gs != null:
		if typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		var announced_lives: Dictionary = (
			_safe_dictionary(
				gs.scenario_state.get(
					"network_live_announced_life_ids",
					{}
				)
			)
		)
		already_announced = bool(
			announced_lives.get(
				announcement_key,
				false
			)
		)

		if (
			life_id != ""
			and not already_announced
			and "reality_stream_contract_engine" in gs
			and gs.reality_stream_contract_engine != null
			and gs.reality_stream_contract_engine.has_method(
				"record_life_started"
			)
		):
			stream_report = (
				gs.reality_stream_contract_engine
				.record_life_started(
					presence,
					{
						"source": (
							"self_host_presence_publish"
						),
						"publish_context": (
							context.duplicate(true)
						)
					}
				)
			)

			if bool(
				stream_report.get(
					"success",
					false
				)
			):
				announced_lives [
					announcement_key
				] = true
				gs.scenario_state [
					"network_live_announced_life_ids"
				] = announced_lives

	last_report = {
		"schema": (
			"eralife.self_host_network.publish_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"local_reality_presence_published"
		),
		"message": (
			"Your current life is live on EraLife Network."
		),
		"presence": presence.duplicate(true),
		"reality_stream_report": (
			stream_report.duplicate(true)
		),
		"live_start_announced": bool(
			stream_report.get(
				"success",
				false
			)
		),
		"live_start_was_already_announced": (
			already_announced
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"source_of_truth": (
				"SelfHostNetworkContractEngine"
			),
			"stream_projection_authority": (
				"RealityStreamContractEngine"
			),
			"ui_is_lens": true
		}
	}
	_commit_state()
	return last_report.duplicate(true)
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
			"SelfHost username migration requires both usernames.",
			context
		)

	var old_key: String = old_clean.to_lower()
	var new_key: String = new_clean.to_lower()
	var nodes: Dictionary = (
		_safe_dictionary(
			network_registry.get(
				"nodes",
				{}
			)
		)
	)
	var migrated_presence: Dictionary = {}

	for raw_node_key in nodes.keys():
		var node: Dictionary = _safe_dictionary(
			nodes.get(
				raw_node_key,
				{}
			)
		)

		if str(
			node.get(
				"username",
				""
			)
		).to_lower() == old_key:
			node ["username"] = new_clean
			node ["presence_text"] = str(
				node.get(
					"presence_text",
					""
				)
			).replace(
				old_clean,
				new_clean
			)
			node ["updated_at_ms"] = int(
				Time.get_ticks_msec()
			)
			migrated_presence = (
				node.duplicate(true)
			)
			nodes [raw_node_key] = node

	if nodes.has(old_key):
		var username_node: Dictionary = (
			_safe_dictionary(
				nodes.get(
					old_key,
					{}
				)
			)
		)
		username_node ["username"] = new_clean
		nodes.erase(old_key)
		nodes [new_key] = username_node
		migrated_presence = (
			username_node.duplicate(true)
		)
	elif not migrated_presence.is_empty():
		nodes [new_key] = (
			migrated_presence.duplicate(true)
		)

	network_registry ["nodes"] = nodes
	network_registry ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	_write_registry()

	last_report = {
		"schema": (
			"eralife.self_host_network.username_migration_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"self_host_username_migrated"
		),
		"old_username": old_clean,
		"new_username": new_clean,
		"presence": migrated_presence,
		"context": context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	_commit_state()
	return last_report.duplicate(true)
func emit_network_presence_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	var self_presence: Dictionary = {}
	if not bool(identity_context.get("is_guest", true)):
		self_presence = _build_presence(identity_context, context)

	var nodes: Dictionary = _safe_dictionary(network_registry.get("nodes", {}))
	var live_nodes: Array = []

	for raw_key in nodes.keys():
		var node: Dictionary = _safe_dictionary(nodes.get(raw_key, {}))
		if node.is_empty():
			continue
		if str(node.get("username", "")).strip_edges() == "":
			continue
		if _contains_runtime_id(live_nodes, str(node.get("runtime_id", ""))):
			continue
		live_nodes.append(node)

	live_nodes.sort_custom(Callable(self, "_sort_nodes_alive_first"))

	return {
		"schema": "eralife.self_host_network.presence_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "self_host_network_ready",
		"identity_context": identity_context.duplicate(true),
		"self_presence": self_presence.duplicate(true),
		"live_nodes": live_nodes,
		"live_node_count": live_nodes.size(),
		"network_type": "reality_network",
		"core_unit": "life",
		"capabilities": {
		},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "SelfHostNetworkContractEngine",
			"platform_model": "users_host_reality_platform_connects_them",
			"ui_mutation_allowed": false
		}
	}

func invite_username_to_live_reality(recipient_username: String, message: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail("account_required", "Sign into an ErAccount to invite someone into your live reality.", context)

	var publish_report: Dictionary = publish_local_reality_presence({
		"source": "invite_username_to_live_reality",
		"reason": "live_invite_requires_presence"
	})

	if gs != null and "mailbox_contract_engine" in gs and gs.mailbox_contract_engine != null and gs.mailbox_contract_engine.has_method("send_live_reality_invite_to_username"):
		return gs.mailbox_contract_engine.send_live_reality_invite_to_username(recipient_username, message, {
			"source": "self_host_network_invite",
			"presence_publish_report": publish_report.duplicate(true)
		})

	return _fail("mailbox_unavailable", "MailBoxContractEngine cannot send the live invite.", context)

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "self_host_network.publish_presence":
		return publish_local_reality_presence(envelope)

	if command_id == "self_host_network.disconnect_presence":
		return disconnect_local_reality_presence(envelope)

	if command_id == "self_host_network.emit_presence":
		return emit_network_presence_contract(envelope)

	if command_id == "self_host_network.invite_live_reality":
		return invite_username_to_live_reality(
			str(envelope.get("recipient_username", "")),
			str(envelope.get("message", "")),
			envelope
		)

	return _fail("unknown_self_host_network_command", "SelfHostNetworkContractEngine did not recognize command.", envelope)
func disconnect_local_reality_presence(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail("account_required", "Sign into an ErAccount to disconnect SelfHost presence.", context)

	var username: String = str(identity_context.get("account_username", "")).strip_edges()
	var username_key: String = username.to_lower()
	var nodes: Dictionary = _safe_dictionary(network_registry.get("nodes", {}))
	var disconnected_presence: Dictionary = {}

	if nodes.has(username_key):
		disconnected_presence = _safe_dictionary(nodes.get(username_key, {}))
	else:
		var current_presence: Dictionary = _build_presence(identity_context, context)
		var runtime_id: String = str(current_presence.get("runtime_id", "")).strip_edges()
		if runtime_id != "" and nodes.has(runtime_id):
			disconnected_presence = _safe_dictionary(nodes.get(runtime_id, {}))
		else:
			disconnected_presence = current_presence.duplicate(true)

	disconnected_presence ["active"] = false
	disconnected_presence ["hosting"] = false
	disconnected_presence ["mode"] = "self_host_presence_disconnected"
	disconnected_presence ["presence_text"] = "%s disconnected from the live reality network." % username
	disconnected_presence ["updated_at_ms"] = int(Time.get_ticks_msec())
	disconnected_presence ["disconnected_at_ms"] = int(Time.get_ticks_msec())

	var runtime_id_out: String = str(disconnected_presence.get("runtime_id", "")).strip_edges()
	nodes [username_key] = disconnected_presence.duplicate(true)
	if runtime_id_out != "":
		nodes [runtime_id_out] = disconnected_presence.duplicate(true)

	network_registry ["nodes"] = nodes
	network_registry ["updated_at_ms"] = int(Time.get_ticks_msec())
	_write_registry()

	var runtime_layer: Node = _runtime_layer()
	if runtime_layer != null:
		if runtime_layer.has_method("disconnect_presence"):
			runtime_layer.call("disconnect_presence")
		elif runtime_layer.has_method("stop_hosting"):
			runtime_layer.call("stop_hosting")
		elif runtime_layer.has_method("stop_runtime"):
			runtime_layer.call("stop_runtime")

	last_report = {
		"schema": "eralife.self_host_network.disconnect_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "local_reality_presence_disconnected",
		"message": "SelfHost presence disconnected.",
		"presence": disconnected_presence.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "SelfHostNetworkContractEngine",
			"ui_is_lens": true
		}
	}

	_commit_state()
	return last_report.duplicate(true)
func _build_presence(
	identity_context: Dictionary,
	_context: Dictionary = {}
) -> Dictionary:
	var runtime_status: Dictionary = (
		_runtime_status()
	)
	var life_id: String = (
		_current_life_id(identity_context)
	)
	var runtime_id: String = str(
		runtime_status.get(
			"runtime_id",
			""
		)
	).strip_edges()
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var identity_id: String = str(
		identity_context.get(
			"cloud_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()

	if runtime_id == "":
		runtime_id = (
			"self_host_%s_%s"
			% [
				(
					username.to_lower()
					if username != ""
					else "node"
				),
				life_id
			]
		)

	var links: Dictionary = {}

	if typeof(
		runtime_status.get(
			"remote_shell",
			{}
		)
	) == TYPE_DICTIONARY:
		var remote_shell: Dictionary = (
			_safe_dictionary(
				runtime_status.get(
					"remote_shell",
					{}
				)
			)
		)
		links ["local_status_url"] = (
			"http://%s:%d/self_host/status"
			% [
				str(
					remote_shell.get(
						"bind_host",
						"127.0.0.1"
					)
				),
				int(
					remote_shell.get(
						"port",
						7821
					)
				)
			]
		)

	if str(
		runtime_status.get(
			"public_play_url",
			""
		)
	).strip_edges() != "":
		links ["public_play_url"] = str(
			runtime_status.get(
				"public_play_url",
				""
			)
		)

	var presence: Dictionary = {
		"schema": (
			"eralife.self_host_network.node_presence"
		),
		"version": CONTRACT_VERSION,
		"active": true,
		"hosting": true,
		"runtime_id": runtime_id,
		"identity_id": identity_id,
		"eraccount_id": identity_id,
		"username": username,
		"life_id": life_id,
		"life_state": (
			_current_life_state_summary()
		),
		"links": links.duplicate(true),
		"runtime_status": (
			runtime_status.duplicate(true)
		),
		"presence_text": (
			"%s is live right now."
			% username
		),
		"entry_modes": [
			"enter_live",
			"observe_live",
			"fork_snapshot"
		],
		"node_role": (
			"player_machine_reality_node"
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	presence ["validation_signature"] = (
		_packet_signature(presence)
	)
	return presence

func _runtime_status() -> Dictionary:
	var runtime_layer: Node = _runtime_layer()
	if runtime_layer != null and runtime_layer.has_method("get_runtime_status"):
		var raw_status: Variant = runtime_layer.call("get_runtime_status")
		if typeof(raw_status) == TYPE_DICTIONARY:
			return (raw_status as Dictionary).duplicate(true)

	if FileAccess.file_exists("user://self_host_runtime_status.json"):
		var file:= FileAccess.open("user://self_host_runtime_status.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				return (parsed as Dictionary).duplicate(true)

	return {
		"schema": "eralife.self_host_runtime_status",
		"version": CONTRACT_VERSION,
		"active": false,
		"runtime_id": "",
		"mode": "local_first_presence_ready"
	}

func _runtime_layer() -> Node:
	var main_loop:= Engine.get_main_loop()
	if main_loop == null:
		return null
	if main_loop is SceneTree:
		var tree:= main_loop as SceneTree
		if tree.root == null:
			return null
		return tree.root.get_node_or_null("SelfHostRuntimeLayer")
	return null

func _current_life_id(identity_context: Dictionary) -> String:
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

	return life_id

func _current_life_state_summary() -> Dictionary:
	var out: Dictionary = {
		"player_name": "Unknown Life",
		"age": 0,
		"year": 0,
		"era_name": "",
		"location": ""
	}

	if gs == null:
		return out

	out ["year"] = int(gs.year) if "year" in gs else 0

	if typeof(gs.era) == TYPE_DICTIONARY:
		out ["era_name"] = str(gs.era.get("name", ""))

	if gs.player != null:
		out ["player_name"] = ("%s %s" % [str(gs.player.first_name), str(gs.player.last_name)]).strip_edges()
		out ["age"] = int(gs.player.age)

	return out

func _identity_context() -> Dictionary:
	if gs != null and "identity_contract_engine" in gs and gs.identity_contract_engine != null and gs.identity_contract_engine.has_method("emit_identity_context"):
		return gs.identity_contract_engine.emit_identity_context({ "source": "self_host_network_identity_context"})
	return { "is_guest": true}

func _ensure_state() -> void:
	network_registry = _read_registry()
	_commit_state()

func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(NETWORK_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "nodes": {}}

	var file:= FileAccess.open(NETWORK_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "nodes": {}}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("nodes", {})) != TYPE_DICTIONARY:
			data ["nodes"] = {}
		return data

	return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "nodes": {}}

func _write_registry() -> void:
	_ensure_identity_dir()
	var file:= FileAccess.open(NETWORK_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(network_registry, "\t"))
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
	gs.scenario_state ["self_host_network_registry"] = network_registry.duplicate(true)
	gs.scenario_state ["last_self_host_network_report"] = last_report.duplicate(true)

func _contains_runtime_id(nodes: Array, runtime_id: String) -> bool:
	for raw_node in nodes:
		if typeof(raw_node) == TYPE_DICTIONARY and str((raw_node as Dictionary).get("runtime_id", "")) == runtime_id:
			return true
	return false

func _sort_nodes_alive_first(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("active", false)) != bool(b.get("active", false)):
		return bool(a.get("active", false))
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))

func _packet_signature(packet: Dictionary) -> String:
	var unsigned: Dictionary = packet.duplicate(true)
	unsigned.erase("validation_signature")
	return "sig_%d" % abs(int(hash(JSON.stringify(unsigned))))

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.self_host_network.error",
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