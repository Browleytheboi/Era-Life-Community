extends Resource
class_name SaveContractGovernor

const CONTRACT_SCHEMA:= "eralife.save_contract_governor"
const CONTRACT_VERSION:= 1
const SAVE_CONTRACT_SCHEMA:= "eralife.save_contract"
const SAVE_CONTRACT_VERSION:= 1
const SAVE_ENVELOPE_SCHEMA:= "eralife.contract_driven_binary_save"
const SAVE_SLICE_BUNDLE_SCHEMA:= "eralife.game_state_contract_save_slices"

const DEFAULT_MAX_SLICES:= 256
const DEFAULT_MAX_ORPHANED_SLICES:= 512
const DEFAULT_MAX_MIGRATION_RULES_PER_SLICE:= 64
const DEFAULT_MAX_SLICE_BYTES:= 33554432

const ALLOWED_SAVE_POLICIES:= [
	"preserve_unknown_fields",
	"migrate_by_schema",
	"stream_on_demand",
	"compress_delta_journal",
	"versioned_domain_blob",
	"snapshot_blob"
]

const ALLOWED_COMPATIBILITY_MODES:= [
	"strict",
	"forward_compatible",
	"backward_compatible",
	"bidirectional",
	"quarantine"
]

const DESTRUCTIVE_MIGRATION_ACTIONS:= [
	"delete_key",
	"drop_key",
	"purge_slice",
	"replace_slice",
	"clear_dictionary",
	"clear_array"
]

const STANDARD_SAVED_ROW_KEYS:= [
	"id",
	"save_key",
	"engine_id",
	"schema",
	"version",
	"min_supported_version",
	"target_version",
	"data",
	"fallback",
	"contract",
	"contract_policy",
	"contract_schema",
	"contract_version",
	"compatibility_mode",
	"preserve_unknown_fields",
	"stream_on_demand",
	"hydration_mode",
	"unknown_fields",
	"metadata",
	"exported_at_ms"
]

var gs
var contract_engine
var last_report: Dictionary = {}

func _init(_gs = null, _contract_engine = null):
	gs = _gs
	contract_engine = _contract_engine

func normalize_save_contract(raw_contract: Dictionary = {}, state_id: String = "", save_slice_registry: Dictionary = {}) -> Dictionary:
	var clean_state_id: String = str(state_id).strip_edges()
	if clean_state_id == "":
		clean_state_id = str(raw_contract.get("state_id", raw_contract.get("world_id", "eralife_default_world"))).strip_edges()
	if clean_state_id == "":
		clean_state_id = "eralife_default_world"

	var warnings: Array = []
	var errors: Array = []

	var limits_raw: Variant = raw_contract.get("limits", {})
	var limits: Dictionary = limits_raw.duplicate(true) if typeof(limits_raw) == TYPE_DICTIONARY else {}
	limits ["max_slices"] = max(1, int(limits.get("max_slices", DEFAULT_MAX_SLICES)))
	limits ["max_orphaned_slices"] = max(0, int(limits.get("max_orphaned_slices", DEFAULT_MAX_ORPHANED_SLICES)))
	limits ["max_migration_rules_per_slice"] = max(1, int(limits.get("max_migration_rules_per_slice", DEFAULT_MAX_MIGRATION_RULES_PER_SLICE)))
	limits ["max_slice_bytes"] = max(0, int(limits.get("max_slice_bytes", DEFAULT_MAX_SLICE_BYTES)))

	var policies_raw: Variant = raw_contract.get("policies", {})
	var policies: Dictionary = policies_raw.duplicate(true) if typeof(policies_raw) == TYPE_DICTIONARY else {}
	policies ["unknown_slice_policy"] = str(policies.get("unknown_slice_policy", "orphan_preserve")).strip_edges()
	policies ["unknown_field_policy"] = str(policies.get("unknown_field_policy", "preserve")).strip_edges()
	policies ["destructive_migration_policy"] = str(policies.get("destructive_migration_policy", "block_unless_explicit")).strip_edges()
	policies ["device_hydration_policy"] = str(policies.get("device_hydration_policy", "core_identity_first")).strip_edges()

	var normalized_slices: Dictionary = {}
	var raw_slices: Variant = raw_contract.get("save_slices", raw_contract.get("slices", {}))

	if typeof(raw_slices) == TYPE_DICTIONARY:
		for raw_key in (raw_slices as Dictionary).keys():
			var slice_id: String = str(raw_key).strip_edges()
			if slice_id == "":
				continue

			var registry_raw: Variant = save_slice_registry.get(slice_id, {})
			var registry_row: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
			var slice_contract: Dictionary = normalize_save_slice_authority(slice_id, (raw_slices as Dictionary).get(raw_key), registry_row, limits)
			normalized_slices [slice_id] = slice_contract

	elif typeof(raw_slices) == TYPE_ARRAY:
		for raw_row in raw_slices:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = raw_row
			var slice_id: String = str(row.get("id", row.get("save_key", ""))).strip_edges()
			if slice_id == "":
				warnings.append("Skipped save contract slice without id.")
				continue

			var registry_raw: Variant = save_slice_registry.get(slice_id, {})
			var registry_row: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
			var slice_contract: Dictionary = normalize_save_slice_authority(slice_id, row, registry_row, limits)
			normalized_slices [slice_id] = slice_contract

	if normalized_slices.is_empty():
		for slice_id in save_slice_registry.keys():
			var clean_slice_id: String = str(slice_id).strip_edges()
			if clean_slice_id == "":
				continue

			var registry_raw: Variant = save_slice_registry.get(clean_slice_id, {})
			var registry_row: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
			normalized_slices [clean_slice_id] = normalize_save_slice_authority(clean_slice_id, {}, registry_row, limits)

	if normalized_slices.size() > int(limits.get("max_slices", DEFAULT_MAX_SLICES)):
		errors.append("Save contract declares %d slices, exceeding max_slices %d." % [normalized_slices.size(), int(limits.get("max_slices", DEFAULT_MAX_SLICES))])

	for slice_id in normalized_slices.keys():
		var slice_contract: Dictionary = normalized_slices.get(slice_id, {})
		var validation_raw: Variant = slice_contract.get("validation", {})
		var validation: Dictionary = validation_raw if typeof(validation_raw) == TYPE_DICTIONARY else {}
		for warning in validation.get("warnings", []):
			warnings.append("%s: %s" % [str(slice_id), str(warning)])
		for error in validation.get("errors", []):
			errors.append("%s: %s" % [str(slice_id), str(error)])

	var normalized:= {
		"schema": SAVE_CONTRACT_SCHEMA,
		"version": SAVE_CONTRACT_VERSION,
		"runtime_contract_version": CONTRACT_VERSION,
		"state_id": clean_state_id,
		"world_id": str(raw_contract.get("world_id", clean_state_id)).strip_edges(),
		"save_slices": normalized_slices,
		"policies": policies,
		"limits": limits,
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		},
		"normalized_at_ms": int(Time.get_ticks_msec())
	}

	return normalized

func normalize_save_slice_authority(slice_id: String, raw_policy: Variant = {}, registry_row: Dictionary = {}, limits: Dictionary = {}) -> Dictionary:
	var clean_slice_id: String = str(slice_id).strip_edges()
	var raw_row: Dictionary = {}

	if typeof(raw_policy) == TYPE_STRING or typeof(raw_policy) == TYPE_STRING_NAME:
		raw_row ["policy"] = str(raw_policy).strip_edges()
	elif typeof(raw_policy) == TYPE_DICTIONARY:
		raw_row = (raw_policy as Dictionary).duplicate(true)
	elif raw_policy != null:
		raw_row ["policy"] = str(raw_policy).strip_edges()

	var registry_metadata_raw: Variant = registry_row.get("metadata", {})
	var registry_metadata: Dictionary = registry_metadata_raw.duplicate(true) if typeof(registry_metadata_raw) == TYPE_DICTIONARY else {}

	var metadata_raw: Variant = raw_row.get("metadata", registry_metadata)
	var metadata: Dictionary = metadata_raw.duplicate(true) if typeof(metadata_raw) == TYPE_DICTIONARY else {}

	var policy_name: String = _normalize_save_policy(raw_row.get("policy", raw_row.get("strategy", metadata.get("save_policy", metadata.get("persistence_policy", "migrate_by_schema")))))
	var compatibility_mode: String = _normalize_compatibility_mode(raw_row.get("compatibility_mode", metadata.get("compatibility_mode", "bidirectional")))

	var migration_raw: Variant = raw_row.get("migration_rules", registry_row.get("migration_rules", []))
	var migration_rules: Array = _safe_dictionary_array(migration_raw)

	var warnings: Array = []
	var errors: Array = []

	if clean_slice_id == "":
		errors.append("Save slice authority missing id.")

	if migration_rules.size() > int(limits.get("max_migration_rules_per_slice", DEFAULT_MAX_MIGRATION_RULES_PER_SLICE)):
		errors.append("Save slice '%s' has too many migration rules." % clean_slice_id)

	var allow_destructive: bool = bool(raw_row.get("allow_destructive_migrations", registry_row.get("allow_destructive_migrations", false)))
	if not allow_destructive and _migration_rules_are_destructive(migration_rules):
		warnings.append("Destructive migration rules are present but not explicitly allowed.")

	var stream_on_demand: bool = bool(raw_row.get("stream_on_demand", registry_row.get("stream_on_demand", policy_name == "stream_on_demand")))
	if policy_name == "stream_on_demand":
		stream_on_demand = true

	return {
		"id": clean_slice_id,
		"save_key": str(raw_row.get("save_key", registry_row.get("save_key", clean_slice_id))).strip_edges(),
		"engine_id": str(raw_row.get("engine_id", registry_row.get("engine_id", ""))).strip_edges(),
		"schema": str(raw_row.get("schema", registry_row.get("schema", "eralife.save_slice"))).strip_edges(),
		"version": max(1, int(raw_row.get("version", registry_row.get("version", 1)))),
		"target_version": max(1, int(raw_row.get("target_version", raw_row.get("version", registry_row.get("target_version", registry_row.get("version", 1)))))),
		"min_supported_version": max(1, int(raw_row.get("min_supported_version", registry_row.get("min_supported_version", 1)))),
		"policy": policy_name,
		"compatibility_mode": compatibility_mode,
		"preserve_unknown_fields": bool(raw_row.get("preserve_unknown_fields", registry_row.get("preserve_unknown_fields", policy_name == "preserve_unknown_fields"))),
		"stream_on_demand": stream_on_demand,
		"allow_destructive_migrations": allow_destructive,
		"max_slice_bytes": max(0, int(raw_row.get("max_slice_bytes", registry_row.get("max_slice_bytes", limits.get("max_slice_bytes", DEFAULT_MAX_SLICE_BYTES))))),
		"migration_rules": migration_rules,
		"metadata": metadata,
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

func govern_export_save_slices(payload: Dictionary, raw_contract: Dictionary = {}, save_slice_registry: Dictionary = {}) -> Dictionary:
	var state_id: String = str(payload.get("state_id", raw_contract.get("state_id", ""))).strip_edges()
	var contract: Dictionary = normalize_save_contract(raw_contract, state_id, save_slice_registry)

	var out: Dictionary = payload.duplicate(true)
	var warnings: Array = []
	var errors: Array = []
	var exported: Array = []

	var slices_raw: Variant = out.get("slices", {})
	if typeof(slices_raw) != TYPE_DICTIONARY:
		errors.append("Save slice payload has no Dictionary 'slices' surface.")
		slices_raw = {}

	var slices: Dictionary = slices_raw
	var governed_slices: Dictionary = {}

	var limits: Dictionary = contract.get("limits", {})
	if slices.size() > int(limits.get("max_slices", DEFAULT_MAX_SLICES)):
		errors.append("Export payload has %d slices, exceeding governed max_slices %d." % [slices.size(), int(limits.get("max_slices", DEFAULT_MAX_SLICES))])

	for save_key in slices.keys():
		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			warnings.append("Skipped exported save_key '%s' because row is not a Dictionary." % str(save_key))
			continue

		var row: Dictionary = (row_raw as Dictionary).duplicate(true)
		var slice_id: String = str(row.get("id", save_key)).strip_edges()
		var contract_row: Dictionary = _resolve_slice_contract(slice_id, contract, save_slice_registry)
		var unknown_fields: Dictionary = _collect_unknown_fields(row, STANDARD_SAVED_ROW_KEYS)

		row ["id"] = slice_id
		row ["save_key"] = str(row.get("save_key", save_key)).strip_edges()
		row ["contract"] = contract_row.duplicate(true)
		row ["contract_policy"] = str(contract_row.get("policy", "migrate_by_schema"))
		row ["contract_schema"] = str(contract_row.get("schema", row.get("schema", "eralife.save_slice")))
		row ["contract_version"] = int(contract_row.get("version", row.get("version", 1)))
		row ["compatibility_mode"] = str(contract_row.get("compatibility_mode", "bidirectional"))
		row ["preserve_unknown_fields"] = bool(contract_row.get("preserve_unknown_fields", true))
		row ["stream_on_demand"] = bool(contract_row.get("stream_on_demand", false))

		if not unknown_fields.is_empty() and bool(row.get("preserve_unknown_fields", true)):
			row ["unknown_fields"] = unknown_fields

		if bool(row.get("stream_on_demand", false)):
			row ["hydration_mode"] = "stream_on_demand"
		else:
			row ["hydration_mode"] = str(row.get("hydration_mode", "eager_or_runtime_pending"))

		exported.append({
			"id": slice_id,
			"save_key": str(save_key),
			"policy": str(row.get("contract_policy", "migrate_by_schema")),
			"hydration_mode": str(row.get("hydration_mode", ""))
		})

		governed_slices [save_key] = _make_binary_safe(row)

	out ["schema"] = SAVE_SLICE_BUNDLE_SCHEMA
	out ["save_contract"] = contract.duplicate(true)
	out ["slices"] = governed_slices
	out ["contract_governor_report"] = {
		"schema": "eralife.save_contract_governor_export_report",
		"version": CONTRACT_VERSION,
		"state_id": state_id,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"exported": exported,
		"slice_count": governed_slices.size(),
		"governed_at_ms": int(Time.get_ticks_msec())
	}

	last_report = out ["contract_governor_report"].duplicate(true)
	return {
		"payload": _make_binary_safe(out),
		"contract": contract.duplicate(true),
		"report": last_report.duplicate(true)
	}

func govern_import_save_slices(data: Dictionary, raw_contract: Dictionary = {}, save_slice_registry: Dictionary = {}, existing_orphaned_slices: Dictionary = {}) -> Dictionary:
	var state_id: String = str(data.get("state_id", raw_contract.get("state_id", ""))).strip_edges()
	var embedded_contract_raw: Variant = data.get("save_contract", raw_contract)
	var embedded_contract: Dictionary = embedded_contract_raw.duplicate(true) if typeof(embedded_contract_raw) == TYPE_DICTIONARY else {}
	var contract: Dictionary = normalize_save_contract(embedded_contract, state_id, save_slice_registry)

	var slices_raw: Variant = data.get("slices", data)
	var slices: Dictionary = slices_raw if typeof(slices_raw) == TYPE_DICTIONARY else {}

	var accepted_slices: Dictionary = {}
	var orphaned: Dictionary = existing_orphaned_slices.duplicate(true)
	var accepted: Array = []
	var quarantined: Array = []
	var failed: Array = []
	var warnings: Array = []

	for save_key in slices.keys():
		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			failed.append({
				"save_key": str(save_key),
				"reason": "Imported save slice row is not a Dictionary."
			})
			continue

		var row: Dictionary = (row_raw as Dictionary).duplicate(true)
		var slice_id: String = str(row.get("id", save_key)).strip_edges()
		if slice_id == "":
			failed.append({
				"save_key": str(save_key),
				"reason": "Imported save slice row has no id."
			})
			continue

		var active_slice_raw: Variant = save_slice_registry.get(slice_id, {})
		var active_slice: Dictionary = active_slice_raw.duplicate(true) if typeof(active_slice_raw) == TYPE_DICTIONARY else {}

		if active_slice.is_empty():
			orphaned [slice_id] = row.duplicate(true)
			quarantined.append({
				"id": slice_id,
				"save_key": str(save_key),
				"reason": "No active save slice contract exists. Preserved as orphan."
			})
			continue

		var contract_row: Dictionary = _resolve_slice_contract(slice_id, contract, save_slice_registry)
		var saved_version: int = max(1, int(row.get("version", 1)))
		var target_version: int = max(1, int(active_slice.get("version", contract_row.get("target_version", 1))))

		var migration_permission: Dictionary = can_migrate_slice(slice_id, saved_version, target_version, active_slice, contract_row)
		if not bool(migration_permission.get("allowed", true)):
			orphaned [slice_id] = row.duplicate(true)
			quarantined.append({
				"id": slice_id,
				"save_key": str(save_key),
				"from_version": saved_version,
				"to_version": target_version,
				"reason": str(migration_permission.get("reason", "Migration blocked by save contract governor."))
			})
			continue

		row ["governor_contract"] = contract_row.duplicate(true)
		row ["governor_policy"] = str(contract_row.get("policy", "migrate_by_schema"))
		row ["hydration_mode"] = "stream_on_demand" if bool(contract_row.get("stream_on_demand", false)) else str(row.get("hydration_mode", "runtime_pending"))

		accepted_slices [save_key] = row
		accepted.append({
			"id": slice_id,
			"save_key": str(save_key),
			"policy": str(row.get("governor_policy", "migrate_by_schema")),
			"hydration_mode": str(row.get("hydration_mode", "runtime_pending"))
		})

	var report:= {
		"schema": "eralife.save_contract_governor_import_report",
		"version": CONTRACT_VERSION,
		"state_id": state_id,
		"valid": failed.is_empty(),
		"accepted": accepted,
		"quarantined": quarantined,
		"failed": failed,
		"warnings": warnings,
		"accepted_count": accepted_slices.size(),
		"orphaned_count": orphaned.size(),
		"governed_at_ms": int(Time.get_ticks_msec())
	}

	last_report = report.duplicate(true)
	return {
		"slices": accepted_slices,
		"orphaned_slices": orphaned,
		"contract": contract.duplicate(true),
		"report": report.duplicate(true)
	}

func can_migrate_slice(slice_id: String, from_version: int, to_version: int, active_slice: Dictionary = {}, contract_row: Dictionary = {}) -> Dictionary:
	if from_version == to_version:
		return {
			"allowed": true,
			"reason": "versions_match"
		}

	var allow_destructive: bool = bool(contract_row.get("allow_destructive_migrations", active_slice.get("allow_destructive_migrations", false)))
	var migration_rules_raw: Variant = active_slice.get("migration_rules", contract_row.get("migration_rules", []))
	var migration_rules: Array = _safe_dictionary_array(migration_rules_raw)

	if not allow_destructive and _migration_rules_are_destructive_for_window(migration_rules, from_version, to_version):
		return {
			"allowed": false,
			"reason": "Destructive migration blocked for slice '%s' from v%d to v%d." % [slice_id, from_version, to_version]
		}

	return {
		"allowed": true,
		"reason": "migration_allowed"
	}

func _resolve_slice_contract(slice_id: String, contract: Dictionary, save_slice_registry: Dictionary = {}) -> Dictionary:
	var contract_slices_raw: Variant = contract.get("save_slices", {})
	var contract_slices: Dictionary = contract_slices_raw if typeof(contract_slices_raw) == TYPE_DICTIONARY else {}

	var row_raw: Variant = contract_slices.get(slice_id, {})
	if typeof(row_raw) == TYPE_DICTIONARY and not (row_raw as Dictionary).is_empty():
		return (row_raw as Dictionary).duplicate(true)

	var registry_raw: Variant = save_slice_registry.get(slice_id, {})
	var registry_row: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
	return normalize_save_slice_authority(slice_id, {}, registry_row, contract.get("limits", {}))

func _normalize_save_policy(value: Variant) -> String:
	var policy: String = str(value).strip_edges().to_lower()
	if policy == "":
		policy = "migrate_by_schema"
	if policy not in ALLOWED_SAVE_POLICIES:
		return "migrate_by_schema"
	return policy

func _normalize_compatibility_mode(value: Variant) -> String:
	var mode: String = str(value).strip_edges().to_lower()
	if mode == "":
		mode = "bidirectional"
	if mode not in ALLOWED_COMPATIBILITY_MODES:
		return "bidirectional"
	return mode

func _migration_rules_are_destructive(rules: Array) -> bool:
	for raw_rule in rules:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue
		var action: String = str((raw_rule as Dictionary).get("action", "")).strip_edges().to_lower()
		if action in DESTRUCTIVE_MIGRATION_ACTIONS:
			return true
	return false

func _migration_rules_are_destructive_for_window(rules: Array, from_version: int, to_version: int) -> bool:
	for raw_rule in rules:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = raw_rule
		var rule_from: int = int(rule.get("from_version", from_version))
		var rule_to: int = int(rule.get("to_version", to_version))

		if from_version > rule_from:
			continue
		if to_version < rule_to:
			continue

		var action: String = str(rule.get("action", "")).strip_edges().to_lower()
		if action in DESTRUCTIVE_MIGRATION_ACTIONS:
			return true

	return false

func _collect_unknown_fields(row: Dictionary, known_keys: Array) -> Dictionary:
	var unknown: Dictionary = {}
	for key in row.keys():
		var clean_key: String = str(key)
		if clean_key not in known_keys:
			unknown [clean_key] = _make_binary_safe(row.get(key))
	return unknown

func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))

	return out

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)