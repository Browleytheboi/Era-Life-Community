extends Resource
class_name GlobalPrewarmContractEngine

const ENGINE_SCHEMA:= "eralife.global_prewarm_contract_engine"
const REGISTRY_SCHEMA:= "eralife.global_prewarm_registry"
const CONTRACT_SCHEMA:= "eralife.global_prewarm_contract"
const CONTRACT_VERSION:= 1

const STATUS_NOT_STARTED:= "NOT_STARTED"
const STATUS_DISCOVERED:= "DISCOVERED"
const STATUS_QUEUED:= "QUEUED"
const STATUS_PREWARMING:= "PREWARMING"
const STATUS_VERIFYING:= "VERIFYING"
const STATUS_HOT:= "HOT"
const STATUS_FAILED:= "FAILED"

var gs = null
var contracts_by_id: Dictionary = {}
var dependency_children_by_id: Dictionary = {}
var last_report: Dictionary = {}
var execution_wave_index: int = 0
var game_state_subscription_ready: bool = false


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
	gs = _gs
	_commit_registry()


func register_prewarm_contract(contract_id: String, contract: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return _fail_report("empty_contract_id", "")

	var existing: Dictionary = {}
	if contracts_by_id.has(clean_id) and typeof(contracts_by_id.get(clean_id, {})) == TYPE_DICTIONARY:
		existing = contracts_by_id.get(clean_id, {}).duplicate(false)

	var normalized: Dictionary = existing.duplicate(false)

	normalized ["schema"] = CONTRACT_SCHEMA
	normalized ["version"] = CONTRACT_VERSION
	normalized ["id"] = clean_id
	normalized ["title"] = str(contract.get("title", existing.get("title", clean_id))).strip_edges()
	normalized ["group"] = str(contract.get("group", existing.get("group", "general"))).strip_edges()
	normalized ["lane"] = str(contract.get("lane", existing.get("lane", "main"))).strip_edges()
	normalized ["priority"] = int(contract.get("priority", existing.get("priority", 100)))
	normalized ["required"] = bool(contract.get("required", existing.get("required", true)))
	normalized ["can_parallelize"] = bool(contract.get("can_parallelize", existing.get("can_parallelize", true)))
	normalized ["ready_gate"] = bool(contract.get("ready_gate", existing.get("ready_gate", true)))

	normalized ["owner"] = contract.get("owner", existing.get("owner", null))
	normalized ["execute_method"] = str(contract.get("execute_method", existing.get("execute_method", ""))).strip_edges()
	normalized ["execute_args"] = _safe_array(contract.get("execute_args", existing.get("execute_args", [])))
	normalized ["verify_method"] = str(contract.get("verify_method", existing.get("verify_method", ""))).strip_edges()
	normalized ["verify_args"] = _safe_array(contract.get("verify_args", existing.get("verify_args", [])))
	normalized ["recover_method"] = str(contract.get("recover_method", existing.get("recover_method", ""))).strip_edges()
	normalized ["recover_args"] = _safe_array(contract.get("recover_args", existing.get("recover_args", [])))

	normalized ["dependencies"] = _safe_array(contract.get("dependencies", existing.get("dependencies", [])))
	normalized ["metadata"] = _safe_dictionary(contract.get("metadata", existing.get("metadata", {})))

	if not normalized.has("status") or str(normalized.get("status", "")).strip_edges() == "":
		normalized ["status"] = STATUS_DISCOVERED
	elif str(normalized.get("status", "")) == STATUS_NOT_STARTED:
		normalized ["status"] = STATUS_DISCOVERED

	normalized ["discovered_at_ms"] = int(normalized.get("discovered_at_ms", Time.get_ticks_msec()))
	normalized ["updated_at_ms"] = int(Time.get_ticks_msec())
	normalized ["execution_count"] = int(normalized.get("execution_count", 0))
	normalized ["verify_count"] = int(normalized.get("verify_count", 0))
	normalized ["failure_count"] = int(normalized.get("failure_count", 0))
	normalized ["recovery_count"] = int(normalized.get("recovery_count", 0))
	normalized ["last_result"] = _safe_dictionary(normalized.get("last_result", {}))

	contracts_by_id [clean_id] = normalized
	_rebuild_dependency_index()
	_commit_registry()

	return _public_contract_snapshot(normalized)


func register_many(contracts: Array) -> Dictionary:
	var registered: Array = []

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = raw_contract
		var contract_id: String = str(contract.get("id", contract.get("contract_id", ""))).strip_edges()
		if contract_id == "":
			continue

		registered.append(register_prewarm_contract(contract_id, contract))

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"registered_count": registered.size(),
		"registered": registered,
		"at_ms": int(Time.get_ticks_msec())
	}
func execute_ready_gate_only(reason: String = "global_prewarm_execute_ready_gate_only") -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())

	set_ready_gate_discovered_to_queued(reason)

	execution_wave_index = 0

	var guard: int = 0
	var max_guard: int = maxi(contracts_by_id.size() * 4, 16)

	while _has_executable_or_queued_ready_gate_contracts() and guard < max_guard:
		guard += 1

		var wave: Array = _next_executable_ready_gate_wave()
		if wave.is_empty():
			_fail_blocked_ready_gate_contracts(reason)
			break

		execution_wave_index += 1

		for raw_contract_id in wave:
			var contract_id: String = str(raw_contract_id).strip_edges()
			if contract_id == "":
				continue

			_execute_contract(contract_id, "%s_wave_%d" % [reason, execution_wave_index])

	var report: Dictionary = verify_ready_gate_only("%s_final_verify" % reason)
	report ["executed_reason"] = reason
	report ["execution_guard"] = guard
	report ["execution_wave_count"] = execution_wave_index
	report ["executed_at_ms"] = now_ms
	report ["ready_gate_only_execution"] = true
	report ["non_ready_contracts_not_executed_before_ready"] = true

	last_report = report.duplicate(true)
	_commit_registry()

	return report


func verify_ready_gate_only(reason: String = "global_prewarm_verify_ready_gate_only") -> Dictionary:
	var required_count: int = 0
	var required_hot_count: int = 0
	var verified_contract_ids: Array = []
	var blocking_failures: Array = []
	var missing_required: Array = []

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id).strip_edges()
		if contract_id == "":
			continue

		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if not bool(contract.get("required", true)):
			continue

		if not bool(contract.get("ready_gate", true)):
			continue

		required_count += 1

		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		if status != STATUS_HOT and status != STATUS_FAILED:
			_verify_contract(contract_id, reason)
			verified_contract_ids.append(contract_id)
			contract = _contract(contract_id)
			status = str(contract.get("status", STATUS_NOT_STARTED))

		if status == STATUS_HOT:
			required_hot_count += 1
		elif status == STATUS_FAILED:
			blocking_failures.append(_public_contract_snapshot(contract))
		else:
			missing_required.append(_public_contract_snapshot(contract))

	var required_hot: bool = required_count == 0 or required_hot_count >= required_count

	var report: Dictionary = {
		"success": required_hot,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": reason,
		"required_count": required_count,
		"required_hot_count": required_hot_count,
		"required_hot": required_hot,
		"verified_contract_ids": verified_contract_ids.duplicate(true),
		"blocking_failures": blocking_failures,
		"missing_required": missing_required,
		"ready_may_appear": required_hot,
		"ui_is_renderer_only": true,
		"verified_at_ms": int(Time.get_ticks_msec())
	}

	last_report = report.duplicate(true)
	_commit_registry()

	return report


func set_ready_gate_discovered_to_queued(reason: String = "queue_ready_gate_only") -> void:
	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if not bool(contract.get("required", true)):
			continue

		if not bool(contract.get("ready_gate", true)):
			continue

		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		if status in [STATUS_NOT_STARTED, STATUS_DISCOVERED]:
			contract ["status"] = STATUS_QUEUED
			contract ["queued_at_ms"] = int(Time.get_ticks_msec())
			contract ["queued_reason"] = reason
			contract ["updated_at_ms"] = int(Time.get_ticks_msec())
			contracts_by_id [contract_id] = contract

	_commit_registry()


func _has_executable_or_queued_ready_gate_contracts() -> bool:
	for raw_contract_id in contracts_by_id.keys():
		var contract: Dictionary = _contract(str(raw_contract_id))
		if contract.is_empty():
			continue

		if not bool(contract.get("required", true)):
			continue

		if not bool(contract.get("ready_gate", true)):
			continue

		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		if status in [STATUS_QUEUED, STATUS_DISCOVERED, STATUS_NOT_STARTED, STATUS_PREWARMING, STATUS_VERIFYING]:
			return true

	return false


func _next_executable_ready_gate_wave() -> Array:
	var wave: Array = []

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if not bool(contract.get("required", true)):
			continue

		if not bool(contract.get("ready_gate", true)):
			continue

		if str(contract.get("status", STATUS_NOT_STARTED)) != STATUS_QUEUED:
			continue

		if not _dependencies_hot(contract):
			continue

		wave.append(contract_id)

	wave.sort_custom(func (a, b):
		var a_contract: Dictionary = _contract(str(a))
		var b_contract: Dictionary = _contract(str(b))
		return int(a_contract.get("priority", 100)) < int(b_contract.get("priority", 100))
	)

	return wave


func _fail_blocked_ready_gate_contracts(reason: String) -> void:
	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if not bool(contract.get("required", true)):
			continue

		if not bool(contract.get("ready_gate", true)):
			continue

		if str(contract.get("status", STATUS_NOT_STARTED)) != STATUS_QUEUED:
			continue

		if _dependencies_hot(contract):
			continue

		contract ["status"] = STATUS_FAILED
		contract ["failed_at_ms"] = int(Time.get_ticks_msec())
		contract ["failure_reason"] = "ready_gate_dependency_not_hot"
		contract ["failure_count"] = int(contract.get("failure_count", 0)) + 1
		contract ["blocked_reason"] = reason
		contract ["updated_at_ms"] = int(Time.get_ticks_msec())
		contracts_by_id [contract_id] = contract

	_commit_registry()

func execute_all(reason: String = "global_prewarm_execute_all") -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())

	set_all_discovered_to_queued(reason)

	execution_wave_index = 0

	var guard: int = 0
	var max_guard: int = maxi(contracts_by_id.size() * 4, 16)

	while _has_executable_or_queued_contracts() and guard < max_guard:
		guard += 1

		var wave: Array = _next_executable_wave()
		if wave.is_empty():
			_fail_blocked_contracts(reason)
			break

		execution_wave_index += 1

		for raw_contract_id in wave:
			var contract_id: String = str(raw_contract_id).strip_edges()
			if contract_id == "":
				continue

			_execute_contract(contract_id, "%s_wave_%d" % [reason, execution_wave_index])

	var report: Dictionary = verify_all("%s_final_verify" % reason)
	report ["executed_reason"] = reason
	report ["execution_guard"] = guard
	report ["execution_wave_count"] = execution_wave_index
	report ["executed_at_ms"] = now_ms

	last_report = report.duplicate(true)
	_commit_registry()

	return report


func verify_all(reason: String = "global_prewarm_verify_all") -> Dictionary:
	var all_hot_count: int = 0
	var failed_count: int = 0
	var required_count: int = 0
	var required_hot_count: int = 0
	var verification_pass_count: int = 0
	var verified_contract_ids: Array = []
	var blocking_failures: Array = []
	var missing_required: Array = []

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(
			raw_contract_id
		).strip_edges()

		if contract_id == "":
			continue

		var contract: Dictionary = _contract(
			contract_id
		)

		if contract.is_empty():
			continue

		var belongs_to_ready_gate: bool = (
			bool(
				contract.get(
					"required",
					true
				)
			)
			and bool(
				contract.get(
					"ready_gate",
					true
				)
			)
		)

		if belongs_to_ready_gate:
			required_count += 1

		var status: String = str(
			contract.get(
				"status",
				STATUS_NOT_STARTED
			)
		)

		if (
			status != STATUS_HOT
			and status != STATUS_FAILED
		):
			_verify_contract(
				contract_id,
				reason
			)
			verification_pass_count += 1
			verified_contract_ids.append(
				contract_id
			)

			contract = _contract(
				contract_id
			)
			status = str(
				contract.get(
					"status",
					STATUS_NOT_STARTED
				)
			)

		if status == STATUS_HOT:
			all_hot_count += 1

			if belongs_to_ready_gate:
				required_hot_count += 1
		elif status == STATUS_FAILED:
			failed_count += 1

			if belongs_to_ready_gate:
				blocking_failures.append(
					_public_contract_snapshot(
						contract
					)
				)
		elif belongs_to_ready_gate:
			missing_required.append(
				_public_contract_snapshot(
					contract
				)
			)

	var required_hot: bool = (
		required_count == 0
		or required_hot_count >= required_count
	)
	var progress: Dictionary = (
		_progress_packet()
	)
	var ready_ratio: float = float(
		progress.get(
			"ready_ratio",
			progress.get(
				"ratio",
				1.0
			)
		)
	)
	var ready_percent: int = int(
		progress.get(
			"ready_percent",
			progress.get(
				"percent",
				100
			)
		)
	)

	var report: Dictionary = {
		"success": required_hot,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": reason,


		"total_count": contracts_by_id.size(),
		"hot_count": all_hot_count,
		"failed_count": failed_count,

		"required_count": required_count,
		"required_hot_count": required_hot_count,
		"required_hot": required_hot,


		"progress_ratio": ready_ratio,
		"progress_percent": ready_percent,
		"ready_progress_ratio": ready_ratio,
		"ready_progress_percent": ready_percent,

		"background_progress_ratio": float(
			progress.get(
				"background_ratio",
				1.0
			)
		),
		"background_progress_percent": int(
			progress.get(
				"background_percent",
				100
			)
		),
		"all_progress_ratio": float(
			progress.get(
				"all_ratio",
				1.0
			)
		),
		"all_progress_percent": int(
			progress.get(
				"all_percent",
				100
			)
		),

		"verification_pass_count": verification_pass_count,
		"verified_contract_ids": verified_contract_ids.duplicate(true),
		"blocking_failures": blocking_failures,
		"missing_required": missing_required,
		"verified_at_ms": int(
			Time.get_ticks_msec()
		),
		"ready_may_appear": required_hot,
		"ready_door_may_open": required_hot,
		"ui_is_renderer_only": true
	}

	last_report = report.duplicate(true)
	_commit_registry()

	return report


func ready_gate_is_hot() -> bool:
	var report: Dictionary = (
		verify_ready_gate_only(
			"ready_gate_truth_check"
		)
	)

	return bool(
		report.get(
			"required_hot",
			false
		)
	)

func set_all_discovered_to_queued(reason: String = "queue_all") -> void:
	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		if status in [STATUS_NOT_STARTED, STATUS_DISCOVERED]:
			contract ["status"] = STATUS_QUEUED
			contract ["queued_at_ms"] = int(Time.get_ticks_msec())
			contract ["queued_reason"] = reason
			contract ["updated_at_ms"] = int(Time.get_ticks_msec())
			contracts_by_id [contract_id] = contract

	_commit_registry()


func contract_status(contract_id: String) -> String:
	var contract: Dictionary = _contract(contract_id)
	if contract.is_empty():
		return STATUS_NOT_STARTED

	return str(contract.get("status", STATUS_NOT_STARTED))


func export_registry() -> Dictionary:
	var public_contracts: Dictionary = {}

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		public_contracts [contract_id] = _public_contract_snapshot(contract)

	return {
		"schema": REGISTRY_SCHEMA,
		"version": CONTRACT_VERSION,
		"engine_schema": ENGINE_SCHEMA,
		"contracts_by_id": public_contracts,
		"dependency_children_by_id": dependency_children_by_id.duplicate(true),
		"last_report": last_report.duplicate(true),
		"contract_count": contracts_by_id.size(),
		"status_counts": _status_counts(),
		"progress": _progress_packet(),
		"ready_gate_hot": _last_required_hot(),
		"ui_is_renderer_only": true
	}


func _execute_contract(contract_id: String, reason: String) -> Dictionary:
	var contract: Dictionary = _contract(contract_id)
	if contract.is_empty():
		return _fail_report("missing_contract", contract_id)

	var status: String = str(contract.get("status", STATUS_NOT_STARTED))
	if status == STATUS_HOT:
		return {
			"success": true,
			"reason": "already_hot",
			"contract_id": contract_id
		}

	if not _dependencies_hot(contract):
		contract ["status"] = STATUS_QUEUED
		contract ["blocked_reason"] = "waiting_for_dependencies"
		contract ["updated_at_ms"] = int(Time.get_ticks_msec())
		contracts_by_id [contract_id] = contract
		_commit_registry()

		return {
			"success": false,
			"reason": "waiting_for_dependencies",
			"contract_id": contract_id
		}

	contract ["status"] = STATUS_PREWARMING
	contract ["prewarming_at_ms"] = int(Time.get_ticks_msec())
	contract ["prewarming_reason"] = reason
	contract ["execution_count"] = int(contract.get("execution_count", 0)) + 1
	contract ["execution_wave_index"] = execution_wave_index
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contracts_by_id [contract_id] = contract
	_commit_registry()

	var execute_result: Dictionary = _call_contract_method(contract, "execute_method", "execute_args", reason)
	contract = _contract(contract_id)
	contract ["last_execute_result"] = execute_result.duplicate(true)
	contracts_by_id [contract_id] = contract

	var verify_result: Dictionary = _verify_contract(contract_id, reason)

	if bool(verify_result.get("success", false)):
		return verify_result

	contract = _contract(contract_id)

	if str(contract.get("recover_method", "")).strip_edges() != "":
		contract ["recovery_count"] = int(contract.get("recovery_count", 0)) + 1
		contract ["recovery_at_ms"] = int(Time.get_ticks_msec())
		contracts_by_id [contract_id] = contract

		var recover_result: Dictionary = _call_contract_method(contract, "recover_method", "recover_args", "%s_recovery" % reason)
		contract = _contract(contract_id)
		contract ["last_recover_result"] = recover_result.duplicate(true)
		contracts_by_id [contract_id] = contract

		verify_result = _verify_contract(contract_id, "%s_after_recovery" % reason)
		if bool(verify_result.get("success", false)):
			return verify_result

	contract = _contract(contract_id)
	contract ["status"] = STATUS_FAILED
	contract ["failed_at_ms"] = int(Time.get_ticks_msec())
	contract ["failure_count"] = int(contract.get("failure_count", 0)) + 1
	contract ["failure_reason"] = str(verify_result.get("reason", "verify_failed"))
	contract ["last_result"] = verify_result.duplicate(true)
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contracts_by_id [contract_id] = contract
	_commit_registry()

	return verify_result


func _verify_contract(contract_id: String, reason: String) -> Dictionary:
	var contract: Dictionary = _contract(contract_id)
	if contract.is_empty():
		return _fail_report("missing_contract", contract_id)

	contract ["status"] = STATUS_VERIFYING
	contract ["verifying_at_ms"] = int(Time.get_ticks_msec())
	contract ["verifying_reason"] = reason
	contract ["verify_count"] = int(contract.get("verify_count", 0)) + 1
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contracts_by_id [contract_id] = contract
	_commit_registry()

	var verify_result: Dictionary = _call_contract_method(contract, "verify_method", "verify_args", reason)
	var success: bool = bool(verify_result.get("success", false))

	contract = _contract(contract_id)
	contract ["last_verify_result"] = verify_result.duplicate(true)
	contract ["last_result"] = verify_result.duplicate(true)

	if success:
		contract ["status"] = STATUS_HOT
		contract ["hot_at_ms"] = int(Time.get_ticks_msec())
		contract ["hot_reason"] = reason
	else:
		contract ["status"] = STATUS_FAILED if bool(contract.get("required", true)) else STATUS_FAILED
		contract ["failed_at_ms"] = int(Time.get_ticks_msec())
		contract ["failure_count"] = int(contract.get("failure_count", 0)) + 1
		contract ["failure_reason"] = str(verify_result.get("reason", "verify_failed"))

	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contracts_by_id [contract_id] = contract
	_commit_registry()

	return verify_result


func _call_contract_method(contract: Dictionary, method_key: String, args_key: String, reason: String) -> Dictionary:
	var owner = contract.get("owner", null)
	var method_name: String = str(contract.get(method_key, "")).strip_edges()
	var args: Array = _safe_array(contract.get(args_key, []))

	if method_name == "":
		return {
			"success": true,
			"reason": "no_method_required",
			"method_key": method_key,
			"contract_id": str(contract.get("id", "")),
			"at_ms": int(Time.get_ticks_msec())
		}

	if owner == null:
		return {
			"success": false,
			"reason": "missing_owner",
			"method": method_name,
			"contract_id": str(contract.get("id", "")),
			"at_ms": int(Time.get_ticks_msec())
		}

	if not owner.has_method(method_name):
		return {
			"success": false,
			"reason": "missing_method",
			"method": method_name,
			"contract_id": str(contract.get("id", "")),
			"at_ms": int(Time.get_ticks_msec())
		}

	var result = owner.callv(method_name, args)

	if typeof(result) == TYPE_DICTIONARY:
		var result_dict: Dictionary = result
		if not result_dict.has("success"):
			result_dict ["success"] = true
		if not result_dict.has("contract_id"):
			result_dict ["contract_id"] = str(contract.get("id", ""))
		if not result_dict.has("method"):
			result_dict ["method"] = method_name
		return result_dict

	return {
		"success": true if result == null else bool(result),
		"raw_result": result,
		"method": method_name,
		"contract_id": str(contract.get("id", "")),
		"reason": reason,
		"at_ms": int(Time.get_ticks_msec())
	}


func _next_executable_wave() -> Array:
	var wave: Array = []

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if str(contract.get("status", STATUS_NOT_STARTED)) != STATUS_QUEUED:
			continue

		if not _dependencies_hot(contract):
			continue

		wave.append(contract_id)

	wave.sort_custom(func (a, b):
		var a_contract: Dictionary = _contract(str(a))
		var b_contract: Dictionary = _contract(str(b))
		return int(a_contract.get("priority", 100)) < int(b_contract.get("priority", 100))
	)

	return wave


func _has_executable_or_queued_contracts() -> bool:
	for raw_contract_id in contracts_by_id.keys():
		var contract: Dictionary = _contract(str(raw_contract_id))
		if contract.is_empty():
			continue

		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		if status in [STATUS_QUEUED, STATUS_DISCOVERED, STATUS_NOT_STARTED, STATUS_PREWARMING, STATUS_VERIFYING]:
			return true

	return false


func _dependencies_hot(contract: Dictionary) -> bool:
	var dependencies: Array = _safe_array(contract.get("dependencies", []))

	for raw_dependency in dependencies:
		var dependency_id: String = str(raw_dependency).strip_edges()
		if dependency_id == "":
			continue

		var dependency: Dictionary = _contract(dependency_id)
		if dependency.is_empty():
			return false

		if str(dependency.get("status", STATUS_NOT_STARTED)) != STATUS_HOT:
			return false

	return true


func _fail_blocked_contracts(reason: String) -> void:
	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		if str(contract.get("status", STATUS_NOT_STARTED)) != STATUS_QUEUED:
			continue

		if _dependencies_hot(contract):
			continue

		contract ["status"] = STATUS_FAILED
		contract ["failed_at_ms"] = int(Time.get_ticks_msec())
		contract ["failure_reason"] = "dependency_not_hot"
		contract ["failure_count"] = int(contract.get("failure_count", 0)) + 1
		contract ["blocked_reason"] = reason
		contract ["updated_at_ms"] = int(Time.get_ticks_msec())
		contracts_by_id [contract_id] = contract


func _rebuild_dependency_index() -> void:
	dependency_children_by_id.clear()

	for raw_contract_id in contracts_by_id.keys():
		var contract_id: String = str(raw_contract_id)
		var contract: Dictionary = _contract(contract_id)
		if contract.is_empty():
			continue

		var dependencies: Array = _safe_array(contract.get("dependencies", []))
		for raw_dependency in dependencies:
			var dependency_id: String = str(raw_dependency).strip_edges()
			if dependency_id == "":
				continue

			if not dependency_children_by_id.has(dependency_id):
				dependency_children_by_id [dependency_id] = []

			var children: Array = dependency_children_by_id [dependency_id]
			if not children.has(contract_id):
				children.append(contract_id)

			dependency_children_by_id [dependency_id] = children


func _contract(contract_id: String) -> Dictionary:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return {}

	var raw: Variant = contracts_by_id.get(clean_id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}

	return raw as Dictionary


func _public_contract_snapshot(contract: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for key in contract.keys():
		if str(key) == "owner":
			continue

		out [key] = contract [key]

	return out


func _status_counts() -> Dictionary:
	var counts: Dictionary = {
		STATUS_NOT_STARTED: 0,
		STATUS_DISCOVERED: 0,
		STATUS_QUEUED: 0,
		STATUS_PREWARMING: 0,
		STATUS_VERIFYING: 0,
		STATUS_HOT: 0,
		STATUS_FAILED: 0
	}

	for raw_contract_id in contracts_by_id.keys():
		var contract: Dictionary = _contract(str(raw_contract_id))
		var status: String = str(contract.get("status", STATUS_NOT_STARTED))
		counts [status] = int(counts.get(status, 0)) + 1

	return counts


func _progress_packet() -> Dictionary:
	var all_total_count: int = 0
	var all_hot_count: int = 0

	var ready_total_count: int = 0
	var ready_hot_count: int = 0

	var background_total_count: int = 0
	var background_hot_count: int = 0

	for raw_contract_id in contracts_by_id.keys():
		var contract: Dictionary = _contract(
			str(raw_contract_id)
		)

		if contract.is_empty():
			continue

		all_total_count += 1

		var status: String = str(
			contract.get(
				"status",
				STATUS_NOT_STARTED
			)
		)
		var is_hot: bool = (
			status == STATUS_HOT
		)
		var belongs_to_ready_gate: bool = (
			bool(
				contract.get(
					"required",
					true
				)
			)
			and bool(
				contract.get(
					"ready_gate",
					true
				)
			)
		)

		if is_hot:
			all_hot_count += 1

		if belongs_to_ready_gate:
			ready_total_count += 1

			if is_hot:
				ready_hot_count += 1
		else:
			background_total_count += 1

			if is_hot:
				background_hot_count += 1

	var ready_ratio: float = 1.0

	if ready_total_count > 0:
		ready_ratio = (
			float(ready_hot_count)
			/ float(ready_total_count)
		)

	var background_ratio: float = 1.0

	if background_total_count > 0:
		background_ratio = (
			float(background_hot_count)
			/ float(background_total_count)
		)

	var all_ratio: float = 1.0

	if all_total_count > 0:
		all_ratio = (
			float(all_hot_count)
			/ float(all_total_count)
		)

	return {


		"hot_count": ready_hot_count,
		"total_count": ready_total_count,
		"ratio": ready_ratio,
		"percent": int(
			round(
				ready_ratio * 100.0
			)
		),

		"ready_hot_count": ready_hot_count,
		"ready_total_count": ready_total_count,
		"ready_ratio": ready_ratio,
		"ready_percent": int(
			round(
				ready_ratio * 100.0
			)
		),
		"ready_gate_hot": (
			ready_total_count == 0
			or ready_hot_count >= ready_total_count
		),
		"ready_door_may_open": (
			ready_total_count == 0
			or ready_hot_count >= ready_total_count
		),

		"background_hot_count": (
			background_hot_count
		),
		"background_total_count": (
			background_total_count
		),
		"background_ratio": background_ratio,
		"background_percent": int(
			round(
				background_ratio * 100.0
			)
		),
		"background_complete": (
			background_total_count == 0
			or background_hot_count
			>= background_total_count
		),

		"all_hot_count": all_hot_count,
		"all_total_count": all_total_count,
		"all_ratio": all_ratio,
		"all_percent": int(
			round(
				all_ratio * 100.0
			)
		),

		"ui_is_renderer_only": true
	}

func _last_required_hot() -> bool:
	if last_report.is_empty():
		return false

	return bool(last_report.get("required_hot", false))


func _commit_registry() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["global_prewarm_contract_engine_registry"] = export_registry()
	gs.scenario_state ["global_prewarm_contract_engine_hot"] = _last_required_hot()
	gs.scenario_state ["global_prewarm_contract_engine_progress"] = _progress_packet()
	gs.scenario_state ["global_prewarm_contract_engine_status_counts"] = _status_counts()
	gs.scenario_state ["global_prewarm_contract_engine_ready_click_may_not_execute_contracts"] = true
	gs.scenario_state ["global_prewarm_contract_engine_ui_is_renderer_only"] = true


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _fail_report(reason: String, contract_id: String = "") -> Dictionary:
	var report: Dictionary = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"reason": reason,
		"contract_id": contract_id,
		"reported_at_ms": int(Time.get_ticks_msec()),
	}

	last_report = report.duplicate(true)
	_commit_registry()

	return report