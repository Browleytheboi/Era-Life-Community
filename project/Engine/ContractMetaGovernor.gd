extends Resource
class_name ContractMetaGovernor

const CONTRACT_SCHEMA:= "eralife.contract_meta_governor"
const CONTRACT_VERSION:= 1

const DEFAULT_VISIBLE_REPORT_LIMIT:= 40

const ALLOWED_RULE_TYPES:= [
	"complexity_bound",
	"recursion_feedback",
	"runtime_budget",
	"contract_compatibility",
	"reality_safety"
]

const ALLOWED_COMPARATORS:= [
	">",
	">=",
	"<",
	"<=",
	"==",
	"!="
]

const ALLOWED_GUARD_PATCH_KEYS:= [
	"defer_noncritical_systems",
	"reduce_scenario_density",
	"reduce_identity_density",
	"fallback_cached_ui",
	"defer_refresh_once",
	"compressed_execution_current_year",
	"auto_stability_mode",
	"commit_budget_cap",
	"phase_budget_cap",
	"tail_settle_budget_cap",
	"runtime_snapshot_items_per_step",
	"control_release_priority",
	"post_age_up_tail_settle_active",
	"post_age_up_tail_settle_until_ms",
	"post_age_up_tail_flush_budget",
	"post_age_up_tail_flush_interval_ms",
	"post_age_up_tail_ui_stage_budget",
	"post_age_up_tail_rewind_delay_ms",
	"post_age_up_tail_speculative_delay_ms",
	"ui_idle_bus_flush_interval_ms",
	"ui_interaction_grace_until_ms",
	"ui_background_work_defer_ms",
	"ui_alive_priority",
	"ui_tail_work_yield_to_input",
	"contract_meta_governor_active",
	"contract_meta_governor_reason",
	"contract_meta_governor_rule_id",
	"contract_meta_governor_severity"
]

var gs
var contract_engine

var meta_contract_registry: Dictionary = {}
var rule_registry: Dictionary = {}
var visible_reports: Array = []
var last_report: Dictionary = {}

func _init(_gs = null, _contract_engine = null):
	gs = _gs
	contract_engine = _contract_engine
	reset_to_defaults()


func reset_to_defaults() -> void:
	meta_contract_registry.clear()
	rule_registry.clear()
	visible_reports.clear()
	last_report.clear()
	_ingest_contract(normalize_meta_contract(_build_default_meta_contract(), "builtin://default_contract_meta_governor"))


func configure(raw_bundle: Dictionary = {}) -> Dictionary:
	reset_to_defaults()

	var report:= {
		"schema": "eralife.contract_meta_governor_configure_report",
		"version": CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"configured_at_ms": int(Time.get_ticks_msec())
	}

	var contracts: Array = []

	var registry_raw: Variant = raw_bundle.get("meta_contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for key in (registry_raw as Dictionary).keys():
			var row_raw: Variant = (registry_raw as Dictionary).get(key, {})
			if typeof(row_raw) == TYPE_DICTIONARY:
				contracts.append((row_raw as Dictionary).duplicate(true))

	var contracts_raw: Variant = raw_bundle.get("contracts", raw_bundle.get("meta_contracts", []))
	if typeof(contracts_raw) == TYPE_ARRAY:
		for raw in contracts_raw:
			if typeof(raw) == TYPE_DICTIONARY:
				contracts.append((raw as Dictionary).duplicate(true))

	if contracts.is_empty() and not raw_bundle.is_empty():
		contracts.append(raw_bundle.duplicate(true))

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = normalize_meta_contract(raw_contract, str(raw_contract.get("source_path", "runtime_meta_contract")))
		var validation: Dictionary = normalized.get("validation", {})
		if not bool(validation.get("valid", false)):
			report ["failed"].append({
				"id": str(normalized.get("id", "")),
				"validation": validation.duplicate(true)
			})
			continue

		_ingest_contract(normalized)
		report ["loaded"].append({
			"id": str(normalized.get("id", "")),
			"rule_count": int(normalized.get("rules", []).size())
		})

	return report


func observe(context: Dictionary = {}, snapshot: Dictionary = {}) -> Dictionary:
	var clean_context: Dictionary = context.duplicate(true)
	var clean_snapshot: Dictionary = snapshot.duplicate(true)

	if clean_snapshot.is_empty():
		clean_snapshot = build_runtime_snapshot(clean_context)

	var violations: Array = []
	var guard_patch: Dictionary = {}
	var visible_events: Array = []

	var ordered_rules: Array = rule_registry.values()
	ordered_rules.sort_custom(func (a, b): return int(a.get("priority", 100)) < int(b.get("priority", 100)))

	for raw_rule in ordered_rules:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = raw_rule
		if not bool(rule.get("enabled", true)):
			continue

		var rule_report: Dictionary = evaluate_rule(rule, clean_snapshot, clean_context)
		if not bool(rule_report.get("violated", false)):
			continue

		violations.append(rule_report)

		var patch_raw: Variant = rule.get("guard_patch", {})
		var filtered_patch: Dictionary = _filter_guard_patch(patch_raw if typeof(patch_raw) == TYPE_DICTIONARY else {})

		filtered_patch ["contract_meta_governor_active"] = true
		filtered_patch ["contract_meta_governor_reason"] = str(rule_report.get("reason", "meta_constraint_triggered"))
		filtered_patch ["contract_meta_governor_rule_id"] = str(rule.get("id", ""))
		filtered_patch ["contract_meta_governor_severity"] = str(rule.get("severity", "warning"))

		for key in filtered_patch.keys():
			guard_patch [key] = filtered_patch [key]

		visible_events.append({
			"rule_id": str(rule.get("id", "")),
			"type": str(rule.get("type", "")),
			"severity": str(rule.get("severity", "warning")),
			"metric": str(rule.get("metric", "")),
			"observed": rule_report.get("observed"),
			"threshold": rule_report.get("threshold"),
			"action": str(rule.get("action", "apply_guard_patch")),
			"message": str(rule.get("message", rule_report.get("reason", ""))).strip_edges()
		})

	var report:= {
		"schema": "eralife.contract_meta_governor_report",
		"version": CONTRACT_VERSION,
		"context": clean_context.duplicate(true),
		"snapshot": clean_snapshot.duplicate(true),
		"violations": violations,
		"visible_events": visible_events,
		"runtime_guard_patch": guard_patch.duplicate(true),
		"valid": violations.is_empty(),
		"deterministic": true,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_report = report.duplicate(true)
	_record_visible_report(report)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["contract_meta_governor_report"] = report.duplicate(true)
		gs.scenario_state ["contract_meta_governor_visible_events"] = visible_events.duplicate(true)

	return report


func evaluate_rule(rule: Dictionary, snapshot: Dictionary, context: Dictionary = {}) -> Dictionary:
	var metric_path: String = str(rule.get("metric", "")).strip_edges()
	var comparator: String = str(rule.get("comparator", rule.get("operator", ">"))).strip_edges()
	if comparator not in ALLOWED_COMPARATORS:
		comparator = ">"

	var observed: Variant = _metric_value(metric_path, snapshot)
	var threshold: Variant = rule.get("threshold", 0)

	var violated: bool = _compare(observed, threshold, comparator)

	return {
		"rule_id": str(rule.get("id", "")),
		"type": str(rule.get("type", "")),
		"metric": metric_path,
		"comparator": comparator,
		"observed": observed,
		"threshold": threshold,
		"violated": violated,
		"reason": "%s %s %s" % [str(observed), comparator, str(threshold)],
		"context_phase": str(context.get("phase", ""))
	}


func normalize_meta_contract(raw_contract: Dictionary, source_path: String = "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", "contract_meta_governor"))).strip_edges()
	if contract_id == "":
		contract_id = "contract_meta_governor"

	var version: int = max(1, int(raw_contract.get("version", CONTRACT_VERSION)))
	if version > CONTRACT_VERSION:
		warnings.append("Meta contract '%s' was authored for version %d. Runtime supports %d." % [contract_id, version, CONTRACT_VERSION])

	var rules: Array = []
	for raw_rule in _safe_dictionary_array(raw_contract.get("rules", raw_contract.get("constraints", []))):
		var rule: Dictionary = normalize_meta_rule(raw_rule, contract_id)
		if str(rule.get("id", "")).strip_edges() == "":
			warnings.append("Skipped meta rule without id.")
			continue
		rules.append(rule)

	if rules.is_empty():
		errors.append("Meta contract '%s' has no rules." % contract_id)

	return {
		"schema": str(raw_contract.get("schema", CONTRACT_SCHEMA)).strip_edges(),
		"version": version,
		"runtime_contract_version": CONTRACT_VERSION,
		"id": contract_id,
		"source_path": source_path,
		"enabled": bool(raw_contract.get("enabled", true)),
		"priority": int(raw_contract.get("priority", 0)),
		"rules": rules,
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}


func normalize_meta_rule(raw_rule: Dictionary, contract_id: String = "") -> Dictionary:
	var rule_id: String = str(raw_rule.get("id", raw_rule.get("rule_id", ""))).strip_edges()
	var rule_type: String = str(raw_rule.get("type", raw_rule.get("category", "complexity_bound"))).strip_edges().to_lower()
	if rule_type not in ALLOWED_RULE_TYPES:
		rule_type = "complexity_bound"

	var comparator: String = str(raw_rule.get("comparator", raw_rule.get("operator", ">"))).strip_edges()
	if comparator not in ALLOWED_COMPARATORS:
		comparator = ">"

	return {
		"id": rule_id,
		"contract_id": contract_id,
		"enabled": bool(raw_rule.get("enabled", true)),
		"type": rule_type,
		"priority": int(raw_rule.get("priority", 100)),
		"severity": str(raw_rule.get("severity", "warning")).strip_edges().to_lower(),
		"metric": str(raw_rule.get("metric", "")).strip_edges(),
		"comparator": comparator,
		"threshold": raw_rule.get("threshold", 0),
		"action": str(raw_rule.get("action", "apply_guard_patch")).strip_edges(),
		"guard_patch": raw_rule.get("guard_patch", {}).duplicate(true) if typeof(raw_rule.get("guard_patch", {})) == TYPE_DICTIONARY else {},
		"message": str(raw_rule.get("message", "")).strip_edges(),
		"metadata": raw_rule.get("metadata", {}).duplicate(true) if typeof(raw_rule.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func build_runtime_snapshot(context: Dictionary = {}) -> Dictionary:
	var snapshot:= {
		"schema": "eralife.contract_meta_runtime_snapshot",
		"version": CONTRACT_VERSION,
		"context": context.duplicate(true),
		"registry": {},
		"runtime": {},
		"event_bus": {},
		"validation": {},
		"compatibility": {},
		"reality": {},
		"built_at_ms": int(Time.get_ticks_msec())
	}

	if contract_engine != null:
		snapshot ["registry"] = {
			"contracts": int(contract_engine.contract_registry.size()),
			"engines": int(contract_engine.engine_registry.size()),
			"save_slices": int(contract_engine.save_slice_registry.size()),
			"runtime_phases": int(contract_engine.runtime_phase_registry.size()),
			"event_subscriptions": int(contract_engine.event_subscription_registry.size()),
			"event_bus_contracts": int(contract_engine.event_bus_contract_registry.size()) if "event_bus_contract_registry" in contract_engine else 0,
			"meta_contracts": int(contract_engine.meta_contract_registry.size()) if "meta_contract_registry" in contract_engine else 0,
			"hydration_rules": int(contract_engine.hydration_registry.size())
		}

		var validation_report: Dictionary = contract_engine.last_validation_report if typeof(contract_engine.last_validation_report) == TYPE_DICTIONARY else {}
		snapshot ["validation"] = {
			"valid": bool(validation_report.get("valid", true)),
			"error_count": int(validation_report.get("errors", []).size()) if typeof(validation_report.get("errors", [])) == TYPE_ARRAY else 0,
			"warning_count": int(validation_report.get("warnings", []).size()) if typeof(validation_report.get("warnings", [])) == TYPE_ARRAY else 0
		}

		var phase_budget: Dictionary = contract_engine.runtime_phase_budget_report if typeof(contract_engine.runtime_phase_budget_report) == TYPE_DICTIONARY else {}
		snapshot ["runtime"] = {
			"phase_budget": phase_budget.duplicate(true),
			"phase_count": int(snapshot ["registry"].get("runtime_phases", 0))
		}

	if gs != null:
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			var overflow_log_raw: Variant = gs.scenario_state.get("runtime_phase_overflow_log", [])
			snapshot ["runtime"] ["phase_overflow_count"] = int(overflow_log_raw.size()) if typeof(overflow_log_raw) == TYPE_ARRAY else 0

			var runtime_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
			snapshot ["runtime"] ["runtime_guard"] = runtime_guard_raw.duplicate(true) if typeof(runtime_guard_raw) == TYPE_DICTIONARY else {}

		if gs.event_bus != null and gs.event_bus.has_method("get_contract_debug_snapshot"):
			snapshot ["event_bus"] = gs.event_bus.get_contract_debug_snapshot()

		snapshot ["reality"] = {
			"year": int(gs.year) if "year" in gs else 0,
			"npc_count": int(gs.npcs.size()) if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY else 0,
			"world_feed_count": int(gs.world_feed.size()) if "world_feed" in gs and typeof(gs.world_feed) == TYPE_ARRAY else 0
		}

	snapshot ["registry"] ["total_contract_surface"] = (
		int(snapshot ["registry"].get("contracts", 0))
		+ int(snapshot ["registry"].get("engines", 0))
		+ int(snapshot ["registry"].get("runtime_phases", 0))
		+ int(snapshot ["registry"].get("event_subscriptions", 0))
		+ int(snapshot ["registry"].get("event_bus_contracts", 0))
		+ int(snapshot ["registry"].get("meta_contracts", 0))
		+ int(snapshot ["registry"].get("hydration_rules", 0))
	)

	return snapshot


func export_debug_snapshot() -> Dictionary:
	return {
		"schema": "eralife.contract_meta_governor_debug",
		"version": CONTRACT_VERSION,
		"meta_contract_count": meta_contract_registry.size(),
		"rule_count": rule_registry.size(),
		"visible_report_count": visible_reports.size(),
		"last_report": last_report.duplicate(true)
	}


func export_visible_reports(limit: int = DEFAULT_VISIBLE_REPORT_LIMIT) -> Array:
	if limit <= 0:
		return []
	return visible_reports.slice(max(0, visible_reports.size() - limit), visible_reports.size()).duplicate(true)


func _ingest_contract(meta_contract: Dictionary) -> void:
	if not bool(meta_contract.get("enabled", true)):
		return

	var contract_id: String = str(meta_contract.get("id", "contract_meta_governor")).strip_edges()
	if contract_id == "":
		contract_id = "contract_meta_governor"

	meta_contract_registry [contract_id] = meta_contract.duplicate(true)

	for raw_rule in meta_contract.get("rules", []):
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = raw_rule
		var rule_id: String = str(rule.get("id", "")).strip_edges()
		if rule_id == "":
			continue

		rule_registry [rule_id] = rule.duplicate(true)


func _build_default_meta_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_contract_meta_governor",
		"enabled": true,
		"priority": 0,
		"rules": [
			{
				"id": "complexity_total_contract_surface",
				"type": "complexity_bound",
				"priority": 10,
				"severity": "warning",
				"metric": "registry.total_contract_surface",
				"comparator": ">",
				"threshold": 420,
				"action": "apply_guard_patch",
				"message": "The loaded reality contract surface is becoming too large for the current runtime window.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true,
					"contract_meta_governor_active": true
				}
			},
			{
				"id": "complexity_event_subscription_bound",
				"type": "complexity_bound",
				"priority": 20,
				"severity": "warning",
				"metric": "registry.event_subscriptions",
				"comparator": ">",
				"threshold": 160,
				"action": "apply_guard_patch",
				"message": "Too many event subscriptions are active for this runtime pass.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true
				}
			},
			{
				"id": "recursion_event_bus_lineage_depth",
				"type": "recursion_feedback",
				"priority": 30,
				"severity": "critical",
				"metric": "event_bus.lineage_depth",
				"comparator": ">=",
				"threshold": 10,
				"action": "apply_guard_patch",
				"message": "EventBus lineage depth is approaching the bounded recursion limit.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true,
					"compressed_execution_current_year": true,
					"phase_budget_cap": 1
				}
			},
			{
				"id": "runtime_phase_overflow_pressure",
				"type": "runtime_budget",
				"priority": 40,
				"severity": "critical",
				"metric": "runtime.phase_overflow_count",
				"comparator": ">",
				"threshold": 8,
				"action": "apply_guard_patch",
				"message": "Runtime phase overflow pressure is high; AgeUp should compress noncritical work.",
				"guard_patch": {
					"compressed_execution_current_year": true,
					"auto_stability_mode": true,
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true,
					"commit_budget_cap": 2,
					"phase_budget_cap": 1,
					"tail_settle_budget_cap": 1
				}
			},
			{
				"id": "post_age_up_deferred_queue_pressure",
				"type": "runtime_budget",
				"priority": 45,
				"severity": "warning",
				"metric": "event_bus.pending_deferred_count",
				"comparator": ">",
				"threshold": 24,
				"action": "apply_guard_patch",
				"message": "Post-AgeUp deferred event pressure is high; live UI should receive priority while the queue drains in bounded chunks.",
				"guard_patch": {
					"post_age_up_tail_settle_active": true,
					"post_age_up_tail_flush_budget": 3,
					"post_age_up_tail_flush_interval_ms": 72,
					"post_age_up_tail_ui_stage_budget": 1,
					"post_age_up_tail_rewind_delay_ms": 900,
					"post_age_up_tail_speculative_delay_ms": 1200,
					"ui_idle_bus_flush_interval_ms": 96,
					"defer_noncritical_systems": true,
					"fallback_cached_ui": true,
					"defer_refresh_once": true
				}
			},
			{
				"id": "compatibility_validation_error_bound",
				"type": "contract_compatibility",
				"priority": 50,
				"severity": "error",
				"metric": "validation.error_count",
				"comparator": ">",
				"threshold": 0,
				"action": "apply_guard_patch",
				"message": "Contract validation errors exist; runtime must avoid expanded domain work.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"fallback_cached_ui": true,
					"defer_refresh_once": true
				}
			},
			{
				"id": "reality_population_surface_bound",
				"type": "reality_safety",
				"priority": 60,
				"severity": "warning",
				"metric": "reality.npc_count",
				"comparator": ">",
				"threshold": 25000,
				"action": "apply_guard_patch",
				"message": "Live NPC surface exceeded the safe default bound for a visible year transition.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"runtime_snapshot_items_per_step": 128,
					"control_release_priority": true
				}
			}
		],
		"metadata": {
			"built_in": true,
			"deterministic": true,
		}
	}


func _metric_value(metric_path: String, snapshot: Dictionary) -> Variant:
	var clean_path: String = str(metric_path).strip_edges()
	if clean_path == "":
		return 0

	var parts: PackedStringArray = clean_path.split(".")
	var current: Variant = snapshot

	for part in parts:
		var key: String = str(part).strip_edges()
		if typeof(current) != TYPE_DICTIONARY:
			return 0
		if not (current as Dictionary).has(key):
			return 0
		current = (current as Dictionary).get(key)

	return current


func _compare(observed: Variant, threshold: Variant, comparator: String) -> bool:
	if typeof(observed) in [TYPE_INT, TYPE_FLOAT] or typeof(threshold) in [TYPE_INT, TYPE_FLOAT]:
		var a: float = float(observed)
		var b: float = float(threshold)

		match comparator:
			">":
				return a > b
			">=":
				return a >= b
			"<":
				return a < b
			"<=":
				return a <= b
			"==":
				return is_equal_approx(a, b)
			"!=":
				return not is_equal_approx(a, b)
			_:
				return false

	var left: String = str(observed)
	var right: String = str(threshold)

	match comparator:
		"==":
			return left == right
		"!=":
			return left != right
		_:
			return false


func _filter_guard_patch(raw_patch: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for key in raw_patch.keys():
		var clean_key: String = str(key).strip_edges()
		if clean_key not in ALLOWED_GUARD_PATCH_KEYS:
			continue
		out [clean_key] = raw_patch.get(key)

	return out


func _record_visible_report(report: Dictionary) -> void:
	visible_reports.append({
		"created_at_ms": int(report.get("created_at_ms", Time.get_ticks_msec())),
		"valid": bool(report.get("valid", true)),
		"violation_count": int(report.get("violations", []).size()) if typeof(report.get("violations", [])) == TYPE_ARRAY else 0,
		"visible_events": report.get("visible_events", []).duplicate(true) if typeof(report.get("visible_events", [])) == TYPE_ARRAY else [],
		"runtime_guard_patch": report.get("runtime_guard_patch", {}).duplicate(true) if typeof(report.get("runtime_guard_patch", {})) == TYPE_DICTIONARY else {}
	})

	while visible_reports.size() > DEFAULT_VISIBLE_REPORT_LIMIT:
		visible_reports.pop_front()


func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))

	return out