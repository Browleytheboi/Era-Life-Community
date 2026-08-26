extends Resource
class_name ECLContractLanguageEngine

const CONTRACT_SCHEMA:= "eralife.ecl_contract_language_engine"
const CONTRACT_VERSION:= 1
const ECL_SCRIPT_SCHEMA:= "eralife.ecl_script"
const ECL_AST_SCHEMA:= "eralife.ecl_reality_intent_graph"
const ECL_QUEUE_SCHEMA:= "eralife.ecl_queued_runtime"
const DEFAULT_QUEUE_LIMIT:= 256

var gs
var active_contract: Dictionary = {}
var pending_runtime_queue: Array = []
var compiled_script_registry: Dictionary = {}
var last_compile_report: Dictionary = {}
var last_queue_report: Dictionary = {}
var last_play_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	return {
		"schema": "eralife.ecl_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

func compile_script(script: String, context: Dictionary = {}) -> Dictionary:
	var clean_script: String = str(script)
	var script_id: String = str(context.get("script_id", "")).strip_edges()
	if script_id == "":
		script_id = _short_id("ecl_script", "%s.%d.%d" % [clean_script, int(Time.get_ticks_msec()), randi()])

	var tokens: Array = _lex_script(clean_script)
	var ast: Dictionary = _parse_tokens_to_ast(tokens, {
		"script_id": script_id,
		"context": context.duplicate(true)
	})

	var resolution: Dictionary = _resolve_ast_contracts(ast, context)
	var envelopes: Array = resolution.get("envelopes", []).duplicate(true) if typeof(resolution.get("envelopes", [])) == TYPE_ARRAY else []
	var errors: Array = ast.get("errors", []).duplicate(true) if typeof(ast.get("errors", [])) == TYPE_ARRAY else []
	var resolver_errors: Array = resolution.get("errors", []).duplicate(true) if typeof(resolution.get("errors", [])) == TYPE_ARRAY else []
	for err in resolver_errors:
		errors.append(err)

	var report:= {
		"schema": "eralife.ecl_compile_report",
		"version": CONTRACT_VERSION,
		"success": errors.is_empty(),
		"script_id": script_id,
		"script_schema": ECL_SCRIPT_SCHEMA,
		"ast_schema": ECL_AST_SCHEMA,
		"token_count": tokens.size(),
		"intent_count": ast.get("nodes", []).size() if typeof(ast.get("nodes", [])) == TYPE_ARRAY else 0,
		"envelope_count": envelopes.size(),
		"errors": errors,
		"warnings": resolution.get("warnings", []).duplicate(true) if typeof(resolution.get("warnings", [])) == TYPE_ARRAY else [],
		"tokens": tokens,
		"ast": ast,
		"envelopes": envelopes,
		"compiled_at_ms": int(Time.get_ticks_msec())
	}

	compiled_script_registry [script_id] = report.duplicate(true)
	last_compile_report = report.duplicate(true)
	return report

func queue_script(script: String, context: Dictionary = {}) -> Dictionary:
	var compile_report: Dictionary = compile_script(script, context)
	var queue_id: String = str(context.get("queue_id", "")).strip_edges()
	if queue_id == "":
		queue_id = _short_id("ecl_queue", "%s.%d.%d" % [
			str(compile_report.get("script_id", "")),
			int(Time.get_ticks_msec()),
			randi()
		])

	var report:= {
		"schema": "eralife.ecl_queue_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"queue_id": queue_id,
		"script_id": str(compile_report.get("script_id", "")),
		"queued_count": 0,
		"pending_count": pending_runtime_queue.size(),
		"compile_report": compile_report.duplicate(true),
		"queued_entries": [],
		"errors": [],
		"queued_at_ms": int(Time.get_ticks_msec())
	}

	if not bool(compile_report.get("success", false)):
		report ["errors"] = compile_report.get("errors", []).duplicate(true) if typeof(compile_report.get("errors", [])) == TYPE_ARRAY else []
		last_queue_report = report.duplicate(true)
		return report

	var envelopes: Array = compile_report.get("envelopes", []).duplicate(true) if typeof(compile_report.get("envelopes", [])) == TYPE_ARRAY else []
	for envelope_raw in envelopes:
		if typeof(envelope_raw) != TYPE_DICTIONARY:
			continue

		if pending_runtime_queue.size() >= int(active_contract.get("queue_limit", DEFAULT_QUEUE_LIMIT)):
			report ["errors"].append("ECL queue limit reached. The remaining envelopes were not queued.")
			break

		var envelope: Dictionary = envelope_raw.duplicate(true)
		var entry_id: String = _short_id("ecl_entry", "%s.%s.%d" % [
			queue_id,
			str(envelope.get("request_id", "")),
			pending_runtime_queue.size()
		])

		var entry:= {
			"schema": ECL_QUEUE_SCHEMA,
			"version": CONTRACT_VERSION,
			"entry_id": entry_id,
			"queue_id": queue_id,
			"script_id": str(compile_report.get("script_id", "")),
			"state": "queued",
			"envelope": envelope,
			"created_at_ms": int(Time.get_ticks_msec()),
			"executed_at_ms": 0,
			"result": {}
		}

		pending_runtime_queue.append(entry)
		report ["queued_entries"].append(entry.duplicate(true))

	report ["queued_count"] = report ["queued_entries"].size()
	report ["pending_count"] = pending_runtime_queue.size()
	report ["success"] = report ["queued_count"] > 0 and report ["errors"].is_empty()
	last_queue_report = report.duplicate(true)
	return report

func drain_queued_runtime(options: Dictionary = {}, executor: Callable = Callable()) -> Dictionary:
	var max_entries: int = int(options.get("max_entries", pending_runtime_queue.size()))
	if max_entries <= 0:
		max_entries = pending_runtime_queue.size()

	var report:= {
		"schema": "eralife.ecl_runtime_play_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"executed_count": 0,
		"failed_count": 0,
		"remaining_count": pending_runtime_queue.size(),
		"results": [],
		"errors": [],
		"played_at_ms": int(Time.get_ticks_msec())
	}

	if not executor.is_valid():
		report ["success"] = false
		report ["errors"].append("ECL runtime executor was not provided. Queue was preserved.")
		last_play_report = report.duplicate(true)
		return report

	var executed: int = 0
	while not pending_runtime_queue.is_empty() and executed < max_entries:
		var entry_raw: Variant = pending_runtime_queue.pop_front()
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_raw.duplicate(true)
		entry ["state"] = "executing"
		var envelope_raw: Variant = entry.get("envelope", {})
		if typeof(envelope_raw) != TYPE_DICTIONARY:
			entry ["state"] = "failed"
			entry ["result"] = {
				"success": false,
				"reason": "queued_entry_missing_envelope"
			}
			report ["failed_count"] = int(report ["failed_count"]) + 1
			report ["results"].append(entry)
			executed += 1
			continue

		var result_raw: Variant = executor.call((envelope_raw as Dictionary).duplicate(true))
		var result: Dictionary = result_raw.duplicate(true) if typeof(result_raw) == TYPE_DICTIONARY else {
			"success": false,
			"value": result_raw
		}

		entry ["state"] = "resolved" if bool(result.get("success", false)) else "failed"
		entry ["executed_at_ms"] = int(Time.get_ticks_msec())
		entry ["result"] = result.duplicate(true)

		if bool(result.get("success", false)):
			report ["executed_count"] = int(report ["executed_count"]) + 1
		else:
			report ["failed_count"] = int(report ["failed_count"]) + 1

		report ["results"].append(entry)
		executed += 1

	report ["remaining_count"] = pending_runtime_queue.size()
	report ["success"] = int(report ["failed_count"]) == 0
	last_play_report = report.duplicate(true)
	return report

func clear_queue(reason: String = "") -> Dictionary:
	var cleared_count: int = pending_runtime_queue.size()
	pending_runtime_queue.clear()
	var report:= {
		"schema": "eralife.ecl_queue_clear_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"cleared_count": cleared_count,
		"reason": reason,
		"cleared_at_ms": int(Time.get_ticks_msec())
	}
	last_queue_report = report.duplicate(true)
	return report

func export_state() -> Dictionary:
	return {
		"schema": "eralife.ecl_language_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"pending_runtime_queue": pending_runtime_queue.duplicate(true),
		"compiled_script_registry": compiled_script_registry.duplicate(true),
		"last_compile_report": last_compile_report.duplicate(true),
		"last_queue_report": last_queue_report.duplicate(true),
		"last_play_report": last_play_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "ECL import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = (contract_raw as Dictionary).duplicate(true)

	var queue_raw: Variant = data.get("pending_runtime_queue", [])
	if typeof(queue_raw) == TYPE_ARRAY:
		pending_runtime_queue = (queue_raw as Array).duplicate(true)

	var compiled_raw: Variant = data.get("compiled_script_registry", {})
	if typeof(compiled_raw) == TYPE_DICTIONARY:
		compiled_script_registry = (compiled_raw as Dictionary).duplicate(true)

	var compile_report_raw: Variant = data.get("last_compile_report", {})
	if typeof(compile_report_raw) == TYPE_DICTIONARY:
		last_compile_report = (compile_report_raw as Dictionary).duplicate(true)

	var queue_report_raw: Variant = data.get("last_queue_report", {})
	if typeof(queue_report_raw) == TYPE_DICTIONARY:
		last_queue_report = (queue_report_raw as Dictionary).duplicate(true)

	var play_report_raw: Variant = data.get("last_play_report", {})
	if typeof(play_report_raw) == TYPE_DICTIONARY:
		last_play_report = (play_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"pending_count": pending_runtime_queue.size(),
		"compiled_script_count": compiled_script_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func export_debug_snapshot() -> Dictionary:
	return {
		"schema": "eralife.ecl_debug_snapshot",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "")),
		"pending_count": pending_runtime_queue.size(),
		"compiled_script_count": compiled_script_registry.size(),
		"last_compile_success": bool(last_compile_report.get("success", false)),
		"last_queue_success": bool(last_queue_report.get("success", false)),
		"last_play_success": bool(last_play_report.get("success", false)),
		"reported_at_ms": int(Time.get_ticks_msec())
	}

func _lex_script(script: String) -> Array:
	var tokens: Array = []
	var line_number: int = 1
	var column: int = 1
	var i: int = 0
	var text: String = str(script)

	while i < text.length():
		var ch: String = text.substr(i, 1)

		if ch == "
":
			i += 1
			continue

		if ch == "\n":
			tokens.append(_token("NEWLINE", "\n", line_number, column))
			line_number += 1
			column = 1
			i += 1
			continue

		if ch in [" ", "\t"]:
			i += 1
			column += 1
			continue

		if ch == "#":
			while i < text.length() and text.substr(i, 1) != "\n":
				i += 1
				column += 1
			continue

		if ch == "/" and i + 1 < text.length() and text.substr(i + 1, 1) == "/":
			while i < text.length() and text.substr(i, 1) != "\n":
				i += 1
				column += 1
			continue

		if ch in ["\"", "'"]:
			var quote: String = ch
			var start_column: int = column
			var value:= ""
			i += 1
			column += 1
			while i < text.length():
				var inner: String = text.substr(i, 1)
				if inner == quote:
					i += 1
					column += 1
					break
				if inner == "\\" and i + 1 < text.length():
					var escaped: String = text.substr(i + 1, 1)
					value += escaped
					i += 2
					column += 2
					continue
				value += inner
				i += 1
				column += 1
			tokens.append(_token("STRING", value, line_number, start_column))
			continue

		if _is_digit(ch):
			var start: int = i
			var start_col: int = column
			var dot_seen: bool = false
			while i < text.length():
				var c: String = text.substr(i, 1)
				if c == "." and not dot_seen:
					dot_seen = true
					i += 1
					column += 1
					continue
				if not _is_digit(c):
					break
				i += 1
				column += 1
			tokens.append(_token("NUMBER", text.substr(start, i - start), line_number, start_col))
			continue

		if _is_identifier_start(ch):
			var ident_start: int = i
			var ident_col: int = column
			while i < text.length() and _is_identifier_char(text.substr(i, 1)):
				i += 1
				column += 1
			var ident: String = text.substr(ident_start, i - ident_start)
			tokens.append(_token("IDENT", ident, line_number, ident_col))
			continue

		if ch == "+" and i + 1 < text.length() and text.substr(i + 1, 1) == "=":
			tokens.append(_token("OP", "+=", line_number, column))
			i += 2
			column += 2
			continue

		if ch == "-" and i + 1 < text.length() and text.substr(i + 1, 1) == "=":
			tokens.append(_token("OP", "-=", line_number, column))
			i += 2
			column += 2
			continue

		if ch in ["=", ":", ",", ";", "(", ")"]:
			tokens.append(_token("SYMBOL", ch, line_number, column))
			i += 1
			column += 1
			continue

		tokens.append(_token("UNKNOWN", ch, line_number, column))
		i += 1
		column += 1

	return tokens

func _parse_tokens_to_ast(tokens: Array, context: Dictionary = {}) -> Dictionary:
	var script_id: String = str(context.get("script_id", "")).strip_edges()
	var nodes: Array = []
	var errors: Array = []
	var statement: Array = []

	for token_raw in tokens:
		if typeof(token_raw) != TYPE_DICTIONARY:
			continue

		var token: Dictionary = token_raw
		var token_text: String = str(token.get("text", ""))
		var token_type: String = str(token.get("type", ""))

		if token_type == "NEWLINE" or token_text == ";":
			if not statement.is_empty():
				var node: Dictionary = _parse_statement_tokens(statement, nodes.size())
				if bool(node.get("success", false)):
					nodes.append(node)
				else:
					errors.append(node)
				statement.clear()
			continue

		statement.append(token)

	if not statement.is_empty():
		var tail_node: Dictionary = _parse_statement_tokens(statement, nodes.size())
		if bool(tail_node.get("success", false)):
			nodes.append(tail_node)
		else:
			errors.append(tail_node)

	return {
		"schema": ECL_AST_SCHEMA,
		"version": CONTRACT_VERSION,
		"script_id": script_id,
		"nodes": nodes,
		"errors": errors,
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _parse_statement_tokens(tokens: Array, index: int) -> Dictionary:
	if tokens.is_empty():
		return _parse_error("empty_statement", index, tokens)

	var head: String = _token_text(tokens [0]).to_lower()
	match head:
		"do":
			return _parse_do_statement(tokens, index)
		"allow":
			return _parse_allow_statement(tokens, index)
		"law":
			return _parse_law_statement(tokens, index)
		"set":
			return _parse_set_statement(tokens, index)
		"spawn":
			return _parse_spawn_statement(tokens, index)
		_:
			if _looks_like_command_id(head):
				return _parse_bare_command_statement(tokens, index)
			return _parse_error("unknown_statement", index, tokens)

func _parse_do_statement(tokens: Array, index: int) -> Dictionary:
	if tokens.size() < 2:
		return _parse_error("do_statement_missing_command", index, tokens)

	var command_id: String = _token_text(tokens [1]).to_lower()
	var args: Dictionary = _parse_call_or_where_args(tokens, 2)
	var times: int = _parse_times(tokens)

	return _intent_node("command_intent", index, tokens, {
		"command_id": command_id,
		"root": _command_root(command_id),
		"verb": _command_verb(command_id),
		"args": args,
		"times": times
	})

func _parse_bare_command_statement(tokens: Array, index: int) -> Dictionary:
	var command_id: String = _token_text(tokens [0]).to_lower()
	var args: Dictionary = _parse_call_or_where_args(tokens, 1)
	var times: int = _parse_times(tokens)

	return _intent_node("command_intent", index, tokens, {
		"command_id": command_id,
		"root": _command_root(command_id),
		"verb": _command_verb(command_id),
		"args": args,
		"times": times
	})

func _parse_allow_statement(tokens: Array, index: int) -> Dictionary:
	if tokens.size() < 2:
		return _parse_error("allow_statement_missing_target", index, tokens)

	var target_command_id: String = _token_text(tokens [1]).to_lower()
	var args: Dictionary = _parse_call_or_where_args(tokens, 2)

	return _intent_node("simulation_law_allow", index, tokens, {
		"command_id": "simulation.law.allow",
		"root": "simulation",
		"verb": "law.allow",
		"args": {
			"target_command_id": target_command_id,
			"target_root": _command_root(target_command_id),
			"target_verb": _command_verb(target_command_id),
			"constraints": args
		},
		"times": 1
	})

func _parse_law_statement(tokens: Array, index: int) -> Dictionary:
	if tokens.size() < 2:
		return _parse_error("law_statement_missing_id", index, tokens)

	var law_id: String = _token_text(tokens [1])
	var colon_index: int = _find_symbol_index(tokens, ":")
	var child_tokens: Array = []
	if colon_index >= 0 and colon_index + 1 < tokens.size():
		child_tokens = tokens.slice(colon_index + 1)
	else:
		child_tokens = tokens.slice(2)

	var child: Dictionary = {}
	if not child_tokens.is_empty():
		child = _parse_statement_tokens(child_tokens, index)

	return _intent_node("simulation_law_define", index, tokens, {
		"command_id": "simulation.law.define",
		"root": "simulation",
		"verb": "law.define",
		"args": {
			"law_id": law_id,
			"child_intent": child.duplicate(true),
			"expression": _tokens_to_text(tokens)
		},
		"times": 1
	})

func _parse_set_statement(tokens: Array, index: int) -> Dictionary:
	if tokens.size() < 4:
		return _parse_error("set_statement_requires_path_operator_value", index, tokens)

	var path: String = _token_text(tokens [1])
	var op: String = _token_text(tokens [2])
	var value_tokens: Array = tokens.slice(3)
	var value: Variant = _value_from_tokens(value_tokens)

	return _intent_node("state_transformation", index, tokens, {
		"command_id": "state.set",
		"root": "state",
		"verb": "set",
		"args": {
			"path": path,
			"operator": op,
			"value": value
		},
		"times": 1
	})

func _parse_spawn_statement(tokens: Array, index: int) -> Dictionary:
	if tokens.size() < 2:
		return _parse_error("spawn_statement_missing_entity_type", index, tokens)

	var entity_type: String = _token_text(tokens [1]).to_lower()
	var args: Dictionary = _parse_call_or_where_args(tokens, 2)
	args ["entity_type"] = entity_type

	return _intent_node("spawn_intent", index, tokens, {
		"command_id": "%s.spawn" % entity_type,
		"root": entity_type,
		"verb": "spawn",
		"args": args,
		"times": 1
	})

func _resolve_ast_contracts(ast: Dictionary, context: Dictionary = {}) -> Dictionary:
	var envelopes: Array = []
	var warnings: Array = []
	var errors: Array = []

	var nodes: Array = ast.get("nodes", []).duplicate(true) if typeof(ast.get("nodes", [])) == TYPE_ARRAY else []
	for node_raw in nodes:
		if typeof(node_raw) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = node_raw
		var resolution: Dictionary = _resolve_intent_contract(node, context)
		if not bool(resolution.get("allowed", false)):
			errors.append({
				"reason": "intent_rejected_by_contract",
				"node": node.duplicate(true),
				"resolution": resolution.duplicate(true)
			})
			continue

		var repeat_count: int = max(1, int(node.get("times", 1)))
		for n in range(repeat_count):
			var envelope: Dictionary = _build_command_envelope(node, context, resolution, n)
			if not envelope.is_empty():
				envelopes.append(envelope)

		if not bool(resolution.get("native_adapter_available", false)):
			warnings.append({
				"reason": "future_adapter_ack_only",
				"command_id": str(resolution.get("command_id", "")),
				"message": "This ECL intent compiles safely, but the runtime adapter can still fall through to contract ack until implemented."
			})

	return {
		"schema": "eralife.ecl_contract_resolution_report",
		"version": CONTRACT_VERSION,
		"success": errors.is_empty(),
		"envelopes": envelopes,
		"warnings": warnings,
		"errors": errors,
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

func _resolve_intent_contract(node: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var command_id: String = str(node.get("command_id", "")).strip_edges().to_lower()
	var registry: Dictionary = active_contract.get("command_contracts", {}).duplicate(true) if typeof(active_contract.get("command_contracts", {})) == TYPE_DICTIONARY else {}
	var known_raw: Variant = registry.get(command_id, {})
	var known: Dictionary = known_raw.duplicate(true) if typeof(known_raw) == TYPE_DICTIONARY else {}

	if command_id == "":
		return {
			"allowed": false,
			"reason": "missing_command_id"
		}

	if command_id.begins_with("ecl."):
		return {
			"allowed": false,
			"reason": "ecl_scripts_cannot_enqueue_reserved_ecl_runtime_commands",
			"command_id": command_id
		}

	if not known.is_empty():
		return {
			"allowed": true,
			"command_id": command_id,
			"contract": known.duplicate(true),
			"native_adapter_available": bool(known.get("native_adapter_available", false)),
			"resolution_mode": "registered_contract"
		}

	return {
		"allowed": bool(active_contract.get("allow_unknown_future_commands", true)),
		"command_id": command_id,
		"contract": {
			"schema": "eralife.future_command_contract",
			"version": CONTRACT_VERSION,
			"command_id": command_id,
			"execution_policy": "queued_ack_until_adapter_exists",
			"unknown_fields": "preserve"
		},
		"native_adapter_available": false,
		"resolution_mode": "future_contract_ack"
	}

func _build_command_envelope(node: Dictionary, context: Dictionary, resolution: Dictionary, repeat_index: int = 0) -> Dictionary:
	var command_id: String = str(node.get("command_id", "")).strip_edges().to_lower()
	if command_id == "":
		return {}

	var source: Dictionary = context.get("source", {}).duplicate(true) if typeof(context.get("source", {})) == TYPE_DICTIONARY else {}
	var world: Dictionary = context.get("world", {}).duplicate(true) if typeof(context.get("world", {})) == TYPE_DICTIONARY else {}
	var life_identity: Dictionary = context.get("life_identity", {}).duplicate(true) if typeof(context.get("life_identity", {})) == TYPE_DICTIONARY else {}

	if source.is_empty():
		source = {
			"adapter": "ecl",
			"platform": "local",
			"user_id": "ecl_user"
		}

	if world.is_empty():
		world = {
			"container_id": "ecl.local.world",
			"mode": "solo"
		}

	if life_identity.is_empty():
		life_identity = {
			"life_node_id": str(source.get("user_id", "ecl_user"))
		}

	var args: Dictionary = node.get("args", {}).duplicate(true) if typeof(node.get("args", {})) == TYPE_DICTIONARY else {}
	args ["_ecl_contract_resolution"] = resolution.duplicate(true)
	args ["_ecl_node"] = node.duplicate(true)

	return {
		"schema": "eralife.ecl_compiled_command_envelope",
		"version": CONTRACT_VERSION,
		"request_id": _short_id("ecl_req", "%s.%s.%d.%d" % [
			str(node.get("node_id", "")),
			command_id,
			repeat_index,
			int(Time.get_ticks_msec())
		]),
		"source": source,
		"world": world,
		"life_identity": life_identity,
		"command": {
			"id": command_id,
			"root": str(node.get("root", _command_root(command_id))),
			"verb": str(node.get("verb", _command_verb(command_id))),
			"args": args
		},
		"ecl": {
			"script_id": str(node.get("script_id", "")),
			"node_id": str(node.get("node_id", "")),
			"intent_type": str(node.get("type", "")),
			"repeat_index": repeat_index,
		}
	}

func _parse_call_or_where_args(tokens: Array, start_index: int) -> Dictionary:
	var paren_index: int = _find_symbol_index_from(tokens, "(", start_index)
	if paren_index >= 0:
		var close_index: int = _find_symbol_index_from(tokens, ")", paren_index + 1)
		if close_index > paren_index:
			return _parse_key_value_tokens(tokens.slice(paren_index + 1, close_index))

	var where_index: int = _find_keyword_index(tokens, "where")
	if where_index >= 0 and where_index + 1 < tokens.size():
		return _parse_key_value_tokens(tokens.slice(where_index + 1))

	return {}

func _parse_key_value_tokens(tokens: Array) -> Dictionary:
	var out: Dictionary = {}
	var key: String = ""
	var value_tokens: Array = []
	var reading_value: bool = false

	for token_raw in tokens:
		if typeof(token_raw) != TYPE_DICTIONARY:
			continue

		var token: Dictionary = token_raw
		var text: String = str(token.get("text", ""))

		if text == ",":
			if key != "":
				out [key] = _value_from_tokens(value_tokens)
			key = ""
			value_tokens.clear()
			reading_value = false
			continue

		if not reading_value and key == "":
			key = text
			continue

		if not reading_value and text in ["=", ":"]:
			reading_value = true
			continue

		if reading_value:
			value_tokens.append(token)

	if key != "":
		out [key] = _value_from_tokens(value_tokens)

	return out

func _value_from_tokens(tokens: Array) -> Variant:
	if tokens.is_empty():
		return true

	if tokens.size() == 1 and typeof(tokens [0]) == TYPE_DICTIONARY:
		var token: Dictionary = tokens [0]
		var token_type: String = str(token.get("type", ""))
		var text: String = str(token.get("text", ""))

		if token_type == "STRING":
			return text
		if token_type == "NUMBER":
			if text.find(".") != -1:
				return float(text)
			return int(text)
		if text.to_lower() == "true":
			return true
		if text.to_lower() == "false":
			return false

	var parts: Array = []
	for token_raw in tokens:
		if typeof(token_raw) == TYPE_DICTIONARY:
			parts.append(str((token_raw as Dictionary).get("text", "")))
	return " ".join(parts).strip_edges()

func _parse_times(tokens: Array) -> int:
	var times_index: int = _find_keyword_index(tokens, "times")
	if times_index >= 0 and times_index + 1 < tokens.size():
		return max(1, int(_token_text(tokens [times_index + 1])))
	return 1

func _intent_node(intent_type: String, index: int, tokens: Array, patch: Dictionary = {}) -> Dictionary:
	var command_id: String = str(patch.get("command_id", "")).strip_edges().to_lower()
	var node:= {
		"success": true,
		"schema": "eralife.ecl_intent_node",
		"version": CONTRACT_VERSION,
		"node_id": _short_id("ecl_node", "%s.%d.%s" % [intent_type, index, _tokens_to_text(tokens)]),
		"script_id": "",
		"type": intent_type,
		"index": index,
		"command_id": command_id,
		"root": str(patch.get("root", _command_root(command_id))),
		"verb": str(patch.get("verb", _command_verb(command_id))),
		"args": patch.get("args", {}).duplicate(true) if typeof(patch.get("args", {})) == TYPE_DICTIONARY else {},
		"times": max(1, int(patch.get("times", 1))),
		"raw": _tokens_to_text(tokens),
		"tokens": tokens.duplicate(true)
	}

	return node

func _parse_error(reason: String, index: int, tokens: Array) -> Dictionary:
	return {
		"success": false,
		"schema": "eralife.ecl_parse_error",
		"version": CONTRACT_VERSION,
		"reason": reason,
		"index": index,
		"raw": _tokens_to_text(tokens),
		"tokens": tokens.duplicate(true)
	}

func _token(type: String, text: String, line: int, column: int) -> Dictionary:
	return {
		"type": type,
		"text": text,
		"line": line,
		"column": column
	}

func _token_text(token_raw: Variant) -> String:
	if typeof(token_raw) == TYPE_DICTIONARY:
		return str((token_raw as Dictionary).get("text", ""))
	return str(token_raw)

func _tokens_to_text(tokens: Array) -> String:
	var parts: Array = []
	for token_raw in tokens:
		if typeof(token_raw) == TYPE_DICTIONARY:
			parts.append(str((token_raw as Dictionary).get("text", "")))
	return " ".join(parts).strip_edges()

func _find_keyword_index(tokens: Array, keyword: String) -> int:
	return _find_keyword_index_from(tokens, keyword, 0)

func _find_keyword_index_from(tokens: Array, keyword: String, start_index: int) -> int:
	for i in range(start_index, tokens.size()):
		if _token_text(tokens [i]).to_lower() == keyword.to_lower():
			return i
	return -1

func _find_symbol_index(tokens: Array, symbol: String) -> int:
	return _find_symbol_index_from(tokens, symbol, 0)

func _find_symbol_index_from(tokens: Array, symbol: String, start_index: int) -> int:
	for i in range(start_index, tokens.size()):
		if _token_text(tokens [i]) == symbol:
			return i
	return -1

func _looks_like_command_id(value: String) -> bool:
	var clean: String = str(value).strip_edges().to_lower()
	return clean.find(".") > 0 and not clean.begins_with(".") and not clean.ends_with(".")

func _command_root(command_id: String) -> String:
	var clean: String = str(command_id).strip_edges().to_lower()
	var parts: PackedStringArray = clean.split(".", false)
	if parts.size() > 0:
		return str(parts [0])
	return clean

func _command_verb(command_id: String) -> String:
	var clean: String = str(command_id).strip_edges().to_lower()
	var parts: PackedStringArray = clean.split(".", false)
	if parts.size() <= 1:
		return clean
	var verb_parts: Array = []
	for i in range(1, parts.size()):
		verb_parts.append(str(parts [i]))
	return ".".join(verb_parts)

func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"

func _is_identifier_start(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_"

func _is_identifier_char(ch: String) -> bool:
	return _is_identifier_start(ch) or _is_digit(ch) or ch in [".", "-", "_"]

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_ecl_contract_language",
		"queue_limit": DEFAULT_QUEUE_LIMIT,
		"allow_unknown_future_commands": true,
		"policies": {
			"execution": "queued_only",
			"unknown_fields": "preserve",
			"unknown_commands": "compile_to_future_contract_ack",
			"reserved_ecl_commands_inside_scripts": "reject",
			"mutation_mode": "contract_envelope_only"
		},
		"command_contracts": {
			"life.start": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"random.life": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"life.stats": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"life.age": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"life.diary": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"world.feed": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"world.status": {
				"native_adapter_available": true,
				"execution_policy": "queued_runtime",
			},
			"simulation.law.allow": {
				"native_adapter_available": false,
				"execution_policy": "queued_ack_until_adapter_exists",
			},
			"simulation.law.define": {
				"native_adapter_available": false,
				"execution_policy": "queued_ack_until_adapter_exists",
			},
			"state.set": {
				"native_adapter_available": false,
				"execution_policy": "queued_ack_until_adapter_exists",
			}
		}
	}

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		out [key] = patch [key]
	return out

func _short_id(prefix: String, source: String) -> String:
	var value: int = abs(hash(str(source)))
	return "%s_%s" % [prefix, String.num_int64(value, 36)]