extends Resource
class_name NarrativeGovernor

const CONTRACT_SCHEMA:= "eralife.narrative_governor"
const CONTRACT_VERSION:= 1
const DEFAULT_MAX_NODE_INJECTIONS_PER_CYCLE:= 2
const DEFAULT_MAX_PRESSURE_INTENSITY:= 24.0
const DEFAULT_MAX_TOTAL_PRESSURE_PER_CYCLE:= 64.0
const DEFAULT_BIRTH_SATURATION_THRESHOLD:= 100.0

var gs
var active_contract: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	active_contract = _build_default_contract()


func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_narrative_governor",
		"limits": {
			"max_node_injections_per_cycle": DEFAULT_MAX_NODE_INJECTIONS_PER_CYCLE,
			"max_pressure_intensity": DEFAULT_MAX_PRESSURE_INTENSITY,
			"max_total_pressure_per_cycle": DEFAULT_MAX_TOTAL_PRESSURE_PER_CYCLE,
			"birth_saturation_threshold": DEFAULT_BIRTH_SATURATION_THRESHOLD
		},
		"policies": {
			"theme_consistency": "bounded",
			"dynamic_node_policy": "allow_with_cap",
			"birth_trigger_policy": "saturation_threshold",
			"pressure_packet_policy": "bounded_intent"
		}
	}


func normalize_contract(raw_contract: Dictionary = {}) -> Dictionary:
	var source: Dictionary = raw_contract.duplicate(true) if not raw_contract.is_empty() else _build_default_contract()
	var limits_raw: Variant = source.get("limits", {})
	var limits: Dictionary = limits_raw.duplicate(true) if typeof(limits_raw) == TYPE_DICTIONARY else {}

	limits ["max_node_injections_per_cycle"] = max(0, int(limits.get("max_node_injections_per_cycle", DEFAULT_MAX_NODE_INJECTIONS_PER_CYCLE)))
	limits ["max_pressure_intensity"] = max(1.0, float(limits.get("max_pressure_intensity", DEFAULT_MAX_PRESSURE_INTENSITY)))
	limits ["max_total_pressure_per_cycle"] = max(1.0, float(limits.get("max_total_pressure_per_cycle", DEFAULT_MAX_TOTAL_PRESSURE_PER_CYCLE)))
	limits ["birth_saturation_threshold"] = max(1.0, float(limits.get("birth_saturation_threshold", DEFAULT_BIRTH_SATURATION_THRESHOLD)))

	var policies_raw: Variant = source.get("policies", {})
	var policies: Dictionary = policies_raw.duplicate(true) if typeof(policies_raw) == TYPE_DICTIONARY else {}
	if str(policies.get("theme_consistency", "")).strip_edges() == "":
		policies ["theme_consistency"] = "bounded"
	if str(policies.get("dynamic_node_policy", "")).strip_edges() == "":
		policies ["dynamic_node_policy"] = "allow_with_cap"
	if str(policies.get("birth_trigger_policy", "")).strip_edges() == "":
		policies ["birth_trigger_policy"] = "saturation_threshold"
	if str(policies.get("pressure_packet_policy", "")).strip_edges() == "":
		policies ["pressure_packet_policy"] = "bounded_intent"

	return {
		"schema": str(source.get("schema", CONTRACT_SCHEMA)),
		"version": max(1, int(source.get("version", CONTRACT_VERSION))),
		"id": str(source.get("id", "default_narrative_governor")),
		"limits": limits,
		"policies": policies,
		"metadata": source.get("metadata", {}).duplicate(true) if typeof(source.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func govern_choice(choice: Dictionary, node: Dictionary, state: Dictionary, contract: Dictionary = {}) -> Dictionary:
	var clean_contract: Dictionary = normalize_contract(contract if not contract.is_empty() else active_contract)
	var limits: Dictionary = clean_contract.get("limits", {})

	var pressure_raw: Variant = choice.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	var max_intensity: float = float(limits.get("max_pressure_intensity", DEFAULT_MAX_PRESSURE_INTENSITY))
	var max_total: float = float(limits.get("max_total_pressure_per_cycle", DEFAULT_MAX_TOTAL_PRESSURE_PER_CYCLE))
	var max_injections: int = int(limits.get("max_node_injections_per_cycle", DEFAULT_MAX_NODE_INJECTIONS_PER_CYCLE))

	var governed_pressure: Dictionary = {}
	var total_abs: float = 0.0

	for raw_key in pressure.keys():
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue

		var value: float = clamp(float(pressure.get(raw_key, 0.0)), - max_intensity, max_intensity)
		var remaining: float = max(0.0, max_total - total_abs)
		if abs(value) > remaining:
			var direction: float = 1.0 if value >= 0.0 else -1.0
			value = direction * remaining

		if abs(value) <= 0.001:
			continue

		governed_pressure [key] = value
		total_abs += abs(value)

	var node_injections_this_cycle: int = int(state.get("node_injections_this_cycle", 0))
	var requested_dynamic_node: bool = bool(choice.get("dynamic_node", false))
	var allow_dynamic_node: bool = requested_dynamic_node and node_injections_this_cycle < max_injections

	var saturation_before: float = float(state.get("saturation", 0.0))
	var saturation_after: float = saturation_before + total_abs
	var birth_threshold: float = float(limits.get("birth_saturation_threshold", DEFAULT_BIRTH_SATURATION_THRESHOLD))
	var birth_ready: bool = saturation_after >= birth_threshold or bool(choice.get("birth_candidate", false))

	var warnings: Array = []
	if requested_dynamic_node and not allow_dynamic_node:
		warnings.append("Dynamic node injection capped by NarrativeGovernor.")

	var report:= {
		"schema": "eralife.narrative_governor_choice_report",
		"version": CONTRACT_VERSION,
		"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
		"node_id": str(node.get("id", "")),
		"pressure": governed_pressure,
		"pressure_total_abs": total_abs,
		"allow_dynamic_node": allow_dynamic_node,
		"requested_dynamic_node": requested_dynamic_node,
		"saturation_before": saturation_before,
		"saturation_after": saturation_after,
		"birth_ready": birth_ready,
		"birth_threshold": birth_threshold,
		"warnings": warnings,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_report = report.duplicate(true)
	return report