extends Resource
class_name SearchContractEngine

const ENGINE_SCHEMA:= "eralife.search_contract_engine"
const CONTRACT_VERSION:= 1
const ACCOUNT_REGISTRY_PATH:= "user://identity/account_registry.json"
const SELF_HOST_NETWORK_REGISTRY_PATH:= "user://identity/self_host_network_registry.json"
const PRESENCE_FRESH_MS:= 300000

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "search.identity_discovery" or command_id == "search.eraccount" or command_id == "search.live_identity_discovery":
		return search_identity_discovery(str(envelope.get("query", "")), envelope)

	return _fail("unknown_search_command", "SearchContractEngine did not recognize command.", envelope)


func search_identity_discovery(query: String, context: Dictionary = {}) -> Dictionary:
	var clean_query: String = str(query).strip_edges().to_lower()
	var query_seq: int = int(context.get("query_seq", 0))
	var limit: int = clamp(int(context.get("limit", 6)), 1, 12)

	if clean_query == "":
		return _report(clean_query, query_seq, [], context, false)

	var registry: Dictionary = _read_account_registry()
	var accounts: Dictionary = _safe_dictionary(registry.get("accounts", {}))
	var network_registry: Dictionary = _read_self_host_network_registry()
	var nodes: Dictionary = _safe_dictionary(network_registry.get("nodes", {}))
	var results: Array = []

	for raw_key in accounts.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if key == "":
			continue

		var account: Dictionary = _safe_dictionary(accounts.get(raw_key, {}))
		var username: String = str(account.get("username", raw_key)).strip_edges()
		var username_lower: String = username.to_lower()

		if username_lower.find(clean_query) == -1:
			continue

		var presence: Dictionary = _presence_for_username(username, nodes)
		var alive_now: bool = _presence_is_live(presence)
		var result: Dictionary = {
			"schema": "eralife.search.identity_result",
			"version": CONTRACT_VERSION,
			"username": username,
			"query_match": clean_query,
			"prefix_match": username_lower.begins_with(clean_query),
			"cloud_identity_id": str(account.get("cloud_identity_id", "")),
			"state": str(account.get("state", "registered")),
			"alive_now": alive_now,
			"hosting": alive_now,
			"presence_label": _presence_label(username, presence, alive_now),
			"presence": presence.duplicate(true),
			"result_truth": {
			}
		}
		results.append(result)

	results.sort_custom(Callable(self, "_sort_identity_results"))

	if results.size() > limit:
		results = results.slice(0, limit)

	return _report(clean_query, query_seq, results, context, false)


func _report(query: String, query_seq: int, results: Array, context: Dictionary, partial: bool) -> Dictionary:
	last_report = {
		"schema": "eralife.search.identity_discovery",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "identity_discovery_results",
		"query": query,
		"query_seq": query_seq,
		"results": results.duplicate(true),
		"partial": partial,
		"empty_state": "No identities found.\nThe network is quiet here.",
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "SearchContractEngine",
			"ui_mutation_allowed": false
		}
	}
	return last_report.duplicate(true)


func _presence_for_username(username: String, nodes: Dictionary) -> Dictionary:
	var clean_username: String = str(username).strip_edges().to_lower()

	if nodes.has(clean_username):
		return _safe_dictionary(nodes.get(clean_username, {}))

	for raw_key in nodes.keys():
		var node: Dictionary = _safe_dictionary(nodes.get(raw_key, {}))
		if str(node.get("username", "")).strip_edges().to_lower() == clean_username:
			return node

	return {}


func _presence_is_live(presence: Dictionary) -> bool:
	if presence.is_empty():
		return false
	if not bool(presence.get("active", false)):
		return false

	var now_ms: int = int(Time.get_ticks_msec())
	var updated_ms: int = int(presence.get("updated_at_ms", 0))

	if updated_ms <= 0:
		return false
	if updated_ms > now_ms:
		return false

	return now_ms - updated_ms <= PRESENCE_FRESH_MS


func _presence_label(_username: String, presence: Dictionary, alive_now: bool) -> String:
	if alive_now:
		if bool(presence.get("hosting", true)):
			return "alive right now"
		return "hosting"

	if not presence.is_empty():
		return "recent network presence"

	return "registered ErAccount"


func _sort_identity_results(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("alive_now", false)) != bool(b.get("alive_now", false)):
		return bool(a.get("alive_now", false))

	if bool(a.get("prefix_match", false)) != bool(b.get("prefix_match", false)):
		return bool(a.get("prefix_match", false))

	return str(a.get("username", "")).to_lower() < str(b.get("username", "")).to_lower()


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


func _read_self_host_network_registry() -> Dictionary:
	if not FileAccess.file_exists(SELF_HOST_NETWORK_REGISTRY_PATH):
		return { "schema": "eralife.self_host_network_contract_engine", "version": CONTRACT_VERSION, "nodes": {}}

	var file:= FileAccess.open(SELF_HOST_NETWORK_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": "eralife.self_host_network_contract_engine", "version": CONTRACT_VERSION, "nodes": {}}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("nodes", {})) != TYPE_DICTIONARY:
			data ["nodes"] = {}
		return data

	return { "schema": "eralife.self_host_network_contract_engine", "version": CONTRACT_VERSION, "nodes": {}}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.search.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)