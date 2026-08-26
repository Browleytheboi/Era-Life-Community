extends Resource
class_name ConnectionGraphNetwork

const ENGINE_SCHEMA:= "eralife.connection_graph_network"
const CONTRACT_VERSION:= 1

const GRAPH_REGISTRY_PATH:= (
	"user://identity/connection_graph_registry.json"
)
const ACCOUNT_REGISTRY_PATH:= (
	"user://identity/account_registry.json"
)

var gs
var graph_registry: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func create_connection_request(
	sender_username: String,
	recipient_username: String,
	note: String = "",
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var sender_account: Dictionary = _account_for_username(
		sender_username
	)
	var recipient_account: Dictionary = _account_for_username(
		recipient_username
	)

	if sender_account.is_empty():
		return _fail(
			"sender_missing",
			"The sending ErAccount could not be resolved.",
			context
		)

	if recipient_account.is_empty():
		return _fail(
			"recipient_missing",
			"The receiving ErAccount could not be resolved.",
			context
		)

	var sender_id: String = _account_identity_id(
		sender_account
	)
	var recipient_id: String = _account_identity_id(
		recipient_account
	)

	if sender_id == "" or recipient_id == "":
		return _fail(
			"identity_missing",
			"A canonical ErAccount ID could not be resolved.",
			context
		)

	if sender_id == recipient_id:
		return _fail(
			"self_connection",
			"You cannot connect your ErAccount to itself.",
			context
		)

	if are_connected(sender_id, recipient_id):
		return {
			"schema": (
				"eralife.connection_graph.request_report"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "already_connected",
			"message": "These ErAccounts are already connected.",
			"connection": _edge_for_pair(
				sender_id,
				recipient_id
			),
			"created_at_ms": _now_ms()
		}

	var existing_request: Dictionary = (
		_pending_request_between(
			sender_id,
			recipient_id
		)
	)

	if not existing_request.is_empty():
		return {
			"schema": (
				"eralife.connection_graph.request_report"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "connection_request_already_pending",
			"message": "A connection request is already pending.",
			"connection_request": (
				existing_request.duplicate(true)
			),
			"created_at_ms": _now_ms()
		}

	var now_ms: int = _now_ms()
	var request_id: String = "connection_request_%d" % abs(
		hash(
			"%s|%s|%d" % [
				sender_id,
				recipient_id,
				now_ms
			]
		)
	)

	var request: Dictionary = {
		"schema": "eralife.connection_graph.request",
		"version": CONTRACT_VERSION,
		"request_id": request_id,
		"sender_identity_id": sender_id,
		"sender_username": str(
			sender_account.get(
				"username",
				sender_username
			)
		),
		"recipient_identity_id": recipient_id,
		"recipient_username": str(
			recipient_account.get(
				"username",
				recipient_username
			)
		),
		"note": str(note).strip_edges(),
		"state": "pending",
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	var requests: Dictionary = _safe_dictionary(
		graph_registry.get(
			"requests",
			{}
		)
	)
	requests [request_id] = request
	graph_registry ["requests"] = requests

	_write_registry()

	last_report = {
		"schema": "eralife.connection_graph.request_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "connection_request_created",
		"message": "Reality connection request sent.",
		"connection_request": request.duplicate(true),
		"created_at_ms": now_ms
	}
	_commit_state()
	return last_report.duplicate(true)


func resolve_connection_request(
	request_id: String,
	acting_username: String,
	decision: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var requests: Dictionary = _safe_dictionary(
		graph_registry.get(
			"requests",
			{}
		)
	)
	var clean_request_id: String = str(
		request_id
	).strip_edges()

	if (
		clean_request_id == ""
		or not requests.has(clean_request_id)
	):
		return _fail(
			"request_missing",
			"That reality connection request no longer exists.",
			context
		)

	var request: Dictionary = _safe_dictionary(
		requests.get(
			clean_request_id,
			{}
		)
	)
	var acting_account: Dictionary = _account_for_username(
		acting_username
	)
	var acting_identity_id: String = _account_identity_id(
		acting_account
	)

	if acting_identity_id == "":
		return _fail(
			"acting_identity_missing",
			"The accepting ErAccount could not be resolved.",
			context
		)

	if (
		acting_identity_id
		!= str(
			request.get(
				"recipient_identity_id",
				""
			)
		)
	):
		return _fail(
			"request_permission_denied",
			"Only the recipient may resolve this request.",
			context
		)

	var clean_decision: String = str(
		decision
	).strip_edges().to_lower()

	if clean_decision in ["ignore", "decline", "reject"]:
		request ["state"] = "declined"
		request ["resolved_at_ms"] = _now_ms()
		request ["updated_at_ms"] = _now_ms()
		request ["resolved_by_identity_id"] = (
			acting_identity_id
		)
		requests [clean_request_id] = request
		graph_registry ["requests"] = requests
		_write_registry()

		last_report = {
			"schema": (
				"eralife.connection_graph.resolution_report"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "connection_request_declined",
			"message": "Reality connection request ignored.",
			"connection_request": request.duplicate(true),
			"created_at_ms": _now_ms()
		}
		_commit_state()
		return last_report.duplicate(true)

	if clean_decision != "accept":
		return _fail(
			"unsupported_decision",
			"That connection decision is not supported.",
			context
		)

	var sender_id: String = str(
		request.get(
			"sender_identity_id",
			""
		)
	)
	var recipient_id: String = str(
		request.get(
			"recipient_identity_id",
			""
		)
	)
	var edge_key: String = _edge_key(
		sender_id,
		recipient_id
	)
	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)
	var now_ms: int = _now_ms()

	var edge: Dictionary = {
		"schema": "eralife.connection_graph.edge",
		"version": CONTRACT_VERSION,
		"connection_id": edge_key,
		"identity_ids": [
			sender_id,
			recipient_id
		],
		"usernames": [
			str(
				request.get(
					"sender_username",
					""
				)
			),
			str(
				request.get(
					"recipient_username",
					""
				)
			)
		],
		"request_id": clean_request_id,
		"state": "connected",
		"connected_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"permissions": {
			"messages": true,
			"notes": true,
			"profile": true,
			"life_visibility": "profile_controlled",
			"milestones": "profile_controlled"
		}
	}

	edges [edge_key] = edge
	graph_registry ["edges"] = edges

	request ["state"] = "accepted"
	request ["resolved_at_ms"] = now_ms
	request ["updated_at_ms"] = now_ms
	request ["resolved_by_identity_id"] = (
		acting_identity_id
	)
	requests [clean_request_id] = request
	graph_registry ["requests"] = requests

	_write_registry()

	last_report = {
		"schema": "eralife.connection_graph.resolution_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "connection_request_accepted",
		"message": "Reality connection accepted.",
		"connection": edge.duplicate(true),
		"connection_request": request.duplicate(true),
		"connection_context": emit_connection_context(
			acting_username,
			{
				"source": (
					"resolve_connection_request"
				)
			}
		),
		"created_at_ms": now_ms
	}
	_commit_state()
	return last_report.duplicate(true)


func remove_connection(
	other_username: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"An ErAccount is required to remove a connection.",
			context
		)

	var own_account: Dictionary = _account_for_username(
		str(
			identity_context.get(
				"account_username",
				""
			)
		)
	)
	var other_account: Dictionary = _account_for_username(
		other_username
	)

	var own_id: String = _account_identity_id(
		own_account
	)
	var other_id: String = _account_identity_id(
		other_account
	)
	var key: String = _edge_key(
		own_id,
		other_id
	)
	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)

	if not edges.has(key):
		return _fail(
			"connection_missing",
			"That ErAccount is not currently connected.",
			context
		)

	var removed_edge: Dictionary = _safe_dictionary(
		edges.get(
			key,
			{}
		)
	)
	edges.erase(key)
	graph_registry ["edges"] = edges
	_write_registry()

	return {
		"schema": "eralife.connection_graph.remove_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "connection_removed",
		"message": "Reality connection removed.",
		"connection": removed_edge,
		"created_at_ms": _now_ms()
	}


func emit_connection_context(
	username: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var account: Dictionary = _account_for_username(
		username
	)
	var identity_id: String = _account_identity_id(
		account
	)

	if identity_id == "":
		return {
			"schema": "eralife.connection_graph.context",
			"version": CONTRACT_VERSION,
			"success": false,
			"mode": "identity_missing",
			"username": username,
			"connections": [],
			"friends": [],
			"incoming_requests": [],
			"outgoing_requests": [],
			"context": context.duplicate(true),
			"created_at_ms": _now_ms()
		}

	var connections: Array = []
	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)

	for raw_key in edges.keys():
		var edge: Dictionary = _safe_dictionary(
			edges.get(
				raw_key,
				{}
			)
		)

		if str(edge.get("state", "")) != "connected":
			continue

		var identity_ids: Array = _safe_array(
			edge.get(
				"identity_ids",
				[]
			)
		)

		if not identity_ids.has(identity_id):
			continue

		var other_id: String = ""

		for raw_identity_id in identity_ids:
			var candidate_id: String = str(
				raw_identity_id
			)

			if candidate_id != identity_id:
				other_id = candidate_id
				break

		if other_id == "":
			continue

		var other_account: Dictionary = _account_for_identity(
			other_id
		)

		connections.append({
			"connection_id": str(
				edge.get(
					"connection_id",
					raw_key
				)
			),
			"identity_id": other_id,
			"username": str(
				other_account.get(
					"username",
					"Unknown"
				)
			),
			"connected_at_ms": int(
				edge.get(
					"connected_at_ms",
					0
				)
			),
			"state": "connected",
			"edge": edge.duplicate(true)
		})

	connections.sort_custom(
		Callable(
			self,
			"_sort_connection_rows"
		)
	)

	var incoming_requests: Array = []
	var outgoing_requests: Array = []
	var requests: Dictionary = _safe_dictionary(
		graph_registry.get(
			"requests",
			{}
		)
	)

	for raw_request_id in requests.keys():
		var request: Dictionary = _safe_dictionary(
			requests.get(
				raw_request_id,
				{}
			)
		)

		if str(request.get("state", "")) != "pending":
			continue

		if (
			str(
				request.get(
					"recipient_identity_id",
					""
				)
			)
			== identity_id
		):
			incoming_requests.append(request)

		if (
			str(
				request.get(
					"sender_identity_id",
					""
				)
			)
			== identity_id
		):
			outgoing_requests.append(request)

	incoming_requests.sort_custom(
		Callable(
			self,
			"_sort_request_rows"
		)
	)
	outgoing_requests.sort_custom(
		Callable(
			self,
			"_sort_request_rows"
		)
	)

	return {
		"schema": "eralife.connection_graph.context",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "connection_graph_ready",
		"identity_id": identity_id,
		"username": str(
			account.get(
				"username",
				username
			)
		),
		"connections": connections,
		"friends": connections.duplicate(true),
		"connection_count": connections.size(),
		"incoming_requests": incoming_requests,
		"outgoing_requests": outgoing_requests,
		"incoming_request_count": incoming_requests.size(),
		"outgoing_request_count": outgoing_requests.size(),
		"context": context.duplicate(true),
		"created_at_ms": _now_ms(),
		"contract_mesh": {
			"source_of_truth": "ConnectionGraphNetwork",
			"ui_mutation_allowed": false
		}
	}


func connected_identity_ids(
	identity_id: String
) -> Array:
	_ensure_state()

	var out: Array = []
	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)

	for raw_key in edges.keys():
		var edge: Dictionary = _safe_dictionary(
			edges.get(
				raw_key,
				{}
			)
		)

		if str(edge.get("state", "")) != "connected":
			continue

		var ids: Array = _safe_array(
			edge.get(
				"identity_ids",
				[]
			)
		)

		if not ids.has(identity_id):
			continue

		for raw_id in ids:
			var candidate: String = str(raw_id)

			if (
				candidate != identity_id
				and not out.has(candidate)
			):
				out.append(candidate)

	return out


func are_connected(
	first_identity_id: String,
	second_identity_id: String
) -> bool:
	if (
		first_identity_id == ""
		or second_identity_id == ""
	):
		return false

	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)
	var edge: Dictionary = _safe_dictionary(
		edges.get(
			_edge_key(
				first_identity_id,
				second_identity_id
			),
			{}
		)
	)

	return (
		not edge.is_empty()
		and str(edge.get("state", "")) == "connected"
	)


func migrate_username(
	identity_id: String,
	old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var requests: Dictionary = _safe_dictionary(
		graph_registry.get(
			"requests",
			{}
		)
	)

	for raw_request_id in requests.keys():
		var request: Dictionary = _safe_dictionary(
			requests.get(
				raw_request_id,
				{}
			)
		)

		if (
			str(
				request.get(
					"sender_identity_id",
					""
				)
			)
			== identity_id
		):
			request ["sender_username"] = new_username

		if (
			str(
				request.get(
					"recipient_identity_id",
					""
				)
			)
			== identity_id
		):
			request ["recipient_username"] = new_username

		requests [raw_request_id] = request

	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)

	for raw_edge_id in edges.keys():
		var edge: Dictionary = _safe_dictionary(
			edges.get(
				raw_edge_id,
				{}
			)
		)
		var ids: Array = _safe_array(
			edge.get(
				"identity_ids",
				[]
			)
		)

		if not ids.has(identity_id):
			continue

		var usernames: Array = _safe_array(
			edge.get(
				"usernames",
				[]
			)
		)

		for i in range(usernames.size()):
			if (
				str(usernames [i]).to_lower()
				== old_username.to_lower()
			):
				usernames [i] = new_username

		edge ["usernames"] = usernames
		edge ["updated_at_ms"] = _now_ms()
		edges [raw_edge_id] = edge

	graph_registry ["requests"] = requests
	graph_registry ["edges"] = edges
	_write_registry()

	return {
		"success": true,
		"mode": "connection_graph_username_migrated",
		"identity_id": identity_id,
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

	if command_id == "connection_graph.emit_context":
		var identity_context: Dictionary = _identity_context()

		return emit_connection_context(
			str(
				envelope.get(
					"username",
					identity_context.get(
						"account_username",
						""
					)
				)
			),
			envelope
		)

	if command_id == "connection_graph.create_request":
		return create_connection_request(
			str(envelope.get("sender_username", "")),
			str(envelope.get("recipient_username", "")),
			str(envelope.get("note", "")),
			envelope
		)

	if command_id == "connection_graph.resolve_request":
		var identity_context: Dictionary = _identity_context()

		return resolve_connection_request(
			str(envelope.get("request_id", "")),
			str(
				envelope.get(
					"acting_username",
					identity_context.get(
						"account_username",
						""
					)
				)
			),
			str(envelope.get("decision", "")),
			envelope
		)

	if command_id == "connection_graph.remove":
		return remove_connection(
			str(envelope.get("username", "")),
			envelope
		)

	return _fail(
		"unknown_connection_graph_command",
		"ConnectionGraphNetwork did not recognize command.",
		envelope
	)


func _pending_request_between(
	first_identity_id: String,
	second_identity_id: String
) -> Dictionary:
	var requests: Dictionary = _safe_dictionary(
		graph_registry.get(
			"requests",
			{}
		)
	)

	for raw_request_id in requests.keys():
		var request: Dictionary = _safe_dictionary(
			requests.get(
				raw_request_id,
				{}
			)
		)

		if str(request.get("state", "")) != "pending":
			continue

		var sender_id: String = str(
			request.get(
				"sender_identity_id",
				""
			)
		)
		var recipient_id: String = str(
			request.get(
				"recipient_identity_id",
				""
			)
		)

		if (
			(
				sender_id == first_identity_id
				and recipient_id == second_identity_id
			)
			or (
				sender_id == second_identity_id
				and recipient_id == first_identity_id
			)
		):
			return request

	return {}


func _edge_for_pair(
	first_identity_id: String,
	second_identity_id: String
) -> Dictionary:
	var edges: Dictionary = _safe_dictionary(
		graph_registry.get(
			"edges",
			{}
		)
	)

	return _safe_dictionary(
		edges.get(
			_edge_key(
				first_identity_id,
				second_identity_id
			),
			{}
		)
	)


func _edge_key(
	first_identity_id: String,
	second_identity_id: String
) -> String:
	if first_identity_id <= second_identity_id:
		return "%s__%s" % [
			first_identity_id,
			second_identity_id
		]

	return "%s__%s" % [
		second_identity_id,
		first_identity_id
	]


func _account_identity_id(
	account: Dictionary
) -> String:
	return str(
		account.get(
			"identity_id",
			account.get(
				"cloud_identity_id",
				""
			)
		)
	).strip_edges()


func _account_for_username(
	username: String
) -> Dictionary:
	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(
		registry.get(
			"accounts",
			{}
		)
	)
	var key: String = str(
		username
	).strip_edges().to_lower()

	return _safe_dictionary(
		accounts.get(
			key,
			{}
		)
	)


func _account_for_identity(
	identity_id: String
) -> Dictionary:
	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(
		registry.get(
			"accounts",
			{}
		)
	)

	for raw_key in accounts.keys():
		var account: Dictionary = _safe_dictionary(
			accounts.get(
				raw_key,
				{}
			)
		)

		if _account_identity_id(account) == identity_id:
			return account

	return {}


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
		and gs.identity_contract_engine.has_method(
			"emit_identity_context"
		)
	):
		return gs.identity_contract_engine.emit_identity_context({
			"source": "connection_graph_network"
		})

	return {
		"is_guest": true,
		"account_username": ""
	}


func _ensure_state() -> void:
	graph_registry = _read_registry()

	if (
		typeof(
			graph_registry.get(
				"requests",
				{}
			)
		)
		!= TYPE_DICTIONARY
	):
		graph_registry ["requests"] = {}

	if (
		typeof(
			graph_registry.get(
				"edges",
				{}
			)
		)
		!= TYPE_DICTIONARY
	):
		graph_registry ["edges"] = {}

	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		GRAPH_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"requests": {},
			"edges": {}
		}

	var file:= FileAccess.open(
		GRAPH_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"requests": {},
			"edges": {}
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
		"requests": {},
		"edges": {}
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		GRAPH_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			graph_registry,
			"\t"
		)
	)
	file.close()
	_commit_state()


func _read_account_registry() -> Dictionary:
	if not FileAccess.file_exists(
		ACCOUNT_REGISTRY_PATH
	):
		return {
			"accounts": {}
		}

	var file:= FileAccess.open(
		ACCOUNT_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"accounts": {}
		}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)

	return {
		"accounts": {}
	}


func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")

	if (
		root != null
		and not root.dir_exists("identity")
	):
		root.make_dir("identity")


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"connection_graph_network_registry"
	] = graph_registry.duplicate(true)
	gs.scenario_state [
		"last_connection_graph_report"
	] = last_report.duplicate(true)


func _sort_connection_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return (
		str(a.get("username", "")).to_lower()
		< str(b.get("username", "")).to_lower()
	)


func _sort_request_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return (
		int(a.get("created_at_ms", 0))
		> int(b.get("created_at_ms", 0))
	)


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
		"schema": "eralife.connection_graph.error",
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