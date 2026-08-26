extends Resource
class_name RuntimeFaultRouter

var gs

func _init(_gs):
	gs = _gs

func route_fault(fault: Dictionary, snapshot: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}
	var routed_fault: Dictionary = fault.duplicate(true)
	var engine_id: String = str(routed_fault.get("engine_id", ""))
	var contract: Dictionary = {}
	if gs.runtime_health_registry != null:
		contract = gs.runtime_health_registry.get_contract(engine_id)
	var signature: String = _build_signature(routed_fault, contract)
	var recurring: Dictionary = {}
	if gs.runtime_health_registry != null:
		recurring = gs.runtime_health_registry.remember_signature(signature, routed_fault)
	routed_fault ["signature"] = signature
	routed_fault ["occurrences"] = int(recurring.get("count", 1))
	routed_fault ["time_ms"] = int(routed_fault.get("time_ms", Time.get_ticks_msec()))
	var mitigation: Dictionary = {}
	if gs.live_patch_guard != null:
		mitigation = gs.live_patch_guard.suggest_mitigation(routed_fault, contract)
		if bool(mitigation.get("safe", false)):
			gs.live_patch_guard.apply_runtime_guard(mitigation)
			routed_fault ["temporary_mitigation"] = str(mitigation.get("action", "monitor_only"))
	var patch_card: Dictionary = {}
	if gs.patch_suggestion_engine != null:
		patch_card = gs.patch_suggestion_engine.build_patch_card(routed_fault, snapshot)

	var auto_patch: Dictionary = {}
	if gs.auto_patch_engine != null and int(routed_fault.get("occurrences", 1)) >= 2:
		auto_patch = gs.auto_patch_engine.maybe_generate_auto_patch(routed_fault, contract, snapshot, patch_card)

	if gs.runtime_health_registry != null:
		gs.runtime_health_registry.record_fault(routed_fault)
		if not mitigation.is_empty():
			gs.runtime_health_registry.record_mitigation(mitigation)
		if not patch_card.is_empty():
			gs.runtime_health_registry.record_patch_card(patch_card)
		if not auto_patch.is_empty():
			gs.runtime_health_registry.record_auto_patch(auto_patch)

	return {
		"fault": routed_fault.duplicate(true),
		"mitigation": mitigation.duplicate(true),
		"patch_card": patch_card.duplicate(true),
		"auto_patch": auto_patch.duplicate(true)
	}

func _build_signature(fault: Dictionary, contract: Dictionary = {}) -> String:
	var domain: String = str(fault.get("domain", "runtime"))
	var code: String = str(fault.get("code", "unknown"))
	var engine_id: String = str(fault.get("engine_id", contract.get("engine_id", "")))
	var phase: String = str(fault.get("current_phase", contract.get("phase_affinity", "")))
	var lane: String = str(fault.get("current_lane", contract.get("lane_affinity", "")))
	return "%s|%s|%s|%s|%s" % [domain, code, engine_id, phase, lane]