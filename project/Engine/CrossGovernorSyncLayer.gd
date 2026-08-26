extends Resource
class_name CrossGovernorSyncLayer

const CONTRACT_SCHEMA:= "eralife.cross_governor_sync_layer"
const CONTRACT_VERSION:= 1

const DEFAULT_CORE_SLICE_IDS:= [
	"core_identity",
	"identity",
	"player",
	"life_identity",
	"timeline_identity",
	"era",
	"settings"
]

const HEAVY_SLICE_HINTS:= [
	"npc",
	"memory",
	"memories",
	"faction",
	"event",
	"world_feed",
	"realm",
	"population",
	"relationship",
	"chronicle"
]

var gs
var contract_engine
var last_report: Dictionary = {}

func _init(_gs = null, _contract_engine = null):
	gs = _gs
	contract_engine = _contract_engine

func synchronize(context: Dictionary = {}) -> Dictionary:
	var runtime_guard: Dictionary = _read_runtime_guard()
	var save_report: Dictionary = _read_save_report()
	var streaming_manifest: Dictionary = _read_streaming_manifest()
	var pending_slices: Dictionary = _read_pending_save_slices()

	var report:= {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"context": context.duplicate(true),
		"runtime_guard_before": runtime_guard.duplicate(true),
		"save_governor_report": save_report.duplicate(true),
		"streaming_manifest": streaming_manifest.duplicate(true),
		"pending_before_count": pending_slices.size(),
		"runtime_guard_patch": {},
		"pending_slice_patch": {},
		"blocked_migrations": [],
		"deferred_hydration": [],
		"allowed_hydration": [],
		"warnings": [],
		"synced_at_ms": int(Time.get_ticks_msec())
	}

	var core_only: bool = bool(runtime_guard.get("world_streaming_boot_core_only", false))
	var streaming_enabled: bool = bool(runtime_guard.get("world_streaming_enabled", false))
	var defer_noncritical: bool = bool(runtime_guard.get("defer_noncritical_systems", false))
	var ui_alive_priority: bool = bool(runtime_guard.get("ui_alive_priority", false))
	var boot_core_only: bool = core_only or (streaming_enabled and bool(_manifest_boot_core_only(streaming_manifest)))

	var guard_patch: Dictionary = {}
	if boot_core_only or defer_noncritical or ui_alive_priority:
		guard_patch ["cross_governor_sync_active"] = true
		guard_patch ["cross_governor_sync_reason"] = "runtime_save_streaming_alignment"
		guard_patch ["defer_noncritical_save_slices"] = true
		guard_patch ["save_hydration_core_only"] = boot_core_only
		guard_patch ["runtime_snapshot_items_per_step"] = min(
			max(1, int(runtime_guard.get("runtime_snapshot_items_per_step", 96))),
			96
		)
		guard_patch ["ui_alive_priority"] = true
		guard_patch ["ui_tail_work_yield_to_input"] = true

	var patched_pending: Dictionary = {}
	for raw_slice_id in pending_slices.keys():
		var slice_id: String = str(raw_slice_id).strip_edges()
		var pending_raw: Variant = pending_slices.get(raw_slice_id, {})
		var pending_row: Dictionary = pending_raw.duplicate(true) if typeof(pending_raw) == TYPE_DICTIONARY else { "data": pending_raw}

		var governor_policy: String = str(pending_row.get("governor_policy", pending_row.get("contract_policy", ""))).strip_edges().to_lower()
		var hydration_mode: String = str(pending_row.get("hydration_mode", "")).strip_edges().to_lower()
		var should_defer: bool = false

		if governor_policy == "stream_on_demand" or hydration_mode == "stream_on_demand":
			should_defer = true

		if boot_core_only and not _is_core_slice(slice_id, pending_row):
			should_defer = true

		if defer_noncritical and _looks_like_heavy_slice(slice_id, pending_row):
			should_defer = true

		if should_defer:
			pending_row ["hydration_mode"] = "stream_on_demand"
			pending_row ["cross_governor_deferred"] = true
			pending_row ["cross_governor_defer_reason"] = "runtime_guard_or_streaming_policy"
			patched_pending [slice_id] = pending_row
			report ["deferred_hydration"].append({
				"id": slice_id,
				"reason": str(pending_row.get("cross_governor_defer_reason", "")),
				"governor_policy": governor_policy
			})
		else:
			patched_pending [slice_id] = pending_row
			report ["allowed_hydration"].append({
				"id": slice_id,
				"governor_policy": governor_policy,
				"hydration_mode": hydration_mode
			})

	var migration_report: Dictionary = _read_migration_report()
	var migrated_rows: Array = migration_report.get("migrated", []) if typeof(migration_report.get("migrated", [])) == TYPE_ARRAY else []
	if not migrated_rows.is_empty() and (boot_core_only or defer_noncritical):
		guard_patch ["migration_hydration_must_be_bounded"] = true
		guard_patch ["defer_post_migration_expansion"] = true
		for row in migrated_rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			report ["blocked_migrations"].append({
				"id": str((row as Dictionary).get("id", "")),
				"reason": "post_migration_expansion_deferred_until_runtime_guard_allows"
			})

	report ["runtime_guard_patch"] = guard_patch.duplicate(true)
	report ["pending_slice_patch"] = patched_pending.duplicate(true)

	_apply_runtime_guard_patch(guard_patch)
	_apply_pending_slice_patch(patched_pending)

	report ["runtime_guard_after"] = _read_runtime_guard()
	report ["pending_after_count"] = patched_pending.size()

	last_report = report.duplicate(true)
	_write_report(report)

	return report

func should_hydrate_pending_slice(slice_id: String, pending_row: Dictionary = {}, context: Dictionary = {}) -> bool:
	var runtime_guard: Dictionary = _read_runtime_guard()
	var hydration_mode: String = str(pending_row.get("hydration_mode", "")).strip_edges().to_lower()

	if hydration_mode == "stream_on_demand":
		return bool(context.get("force_streaming_hydration", false))

	if bool(pending_row.get("cross_governor_deferred", false)) and not bool(context.get("force_streaming_hydration", false)):
		return false

	if bool(runtime_guard.get("save_hydration_core_only", false)) and not _is_core_slice(slice_id, pending_row):
		return false

	return true

func _read_runtime_guard() -> Dictionary:
	var out: Dictionary = {}
	if contract_engine != null:
		var engine_guard_raw: Variant = contract_engine.runtime_guard if "runtime_guard" in contract_engine else {}
		if typeof(engine_guard_raw) == TYPE_DICTIONARY:
			out = _merge_dict(out, engine_guard_raw as Dictionary)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		if typeof(scenario_guard_raw) == TYPE_DICTIONARY:
			out = _merge_dict(out, scenario_guard_raw as Dictionary)

	return out

func _read_save_report() -> Dictionary:
	if contract_engine == null:
		return {}
	var raw: Variant = contract_engine.last_save_contract_governor_report if "last_save_contract_governor_report" in contract_engine else {}
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _read_migration_report() -> Dictionary:
	if contract_engine == null:
		return {}
	var raw: Variant = contract_engine.last_migration_report if "last_migration_report" in contract_engine else {}
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _read_streaming_manifest() -> Dictionary:
	if contract_engine == null:
		return {}
	var raw: Variant = contract_engine.world_streaming_manifest if "world_streaming_manifest" in contract_engine else {}
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _read_pending_save_slices() -> Dictionary:
	if contract_engine == null:
		return {}
	var raw: Variant = contract_engine.pending_save_slices if "pending_save_slices" in contract_engine else {}
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _manifest_boot_core_only(manifest: Dictionary) -> bool:
	var limits_raw: Variant = manifest.get("limits", {})
	if typeof(limits_raw) != TYPE_DICTIONARY:
		return false
	return bool((limits_raw as Dictionary).get("boot_core_only", false))

func _is_core_slice(slice_id: String, pending_row: Dictionary = {}) -> bool:
	var clean_id: String = str(slice_id).strip_edges().to_lower()
	if clean_id in DEFAULT_CORE_SLICE_IDS:
		return true

	var save_key: String = str(pending_row.get("save_key", "")).strip_edges().to_lower()
	if save_key in DEFAULT_CORE_SLICE_IDS:
		return true

	var governor_contract_raw: Variant = pending_row.get("governor_contract", {})
	if typeof(governor_contract_raw) == TYPE_DICTIONARY:
		var metadata_raw: Variant = (governor_contract_raw as Dictionary).get("metadata", {})
		if typeof(metadata_raw) == TYPE_DICTIONARY:
			if bool((metadata_raw as Dictionary).get("core_identity_slice", false)):
				return true
			if str((metadata_raw as Dictionary).get("hydration_lane", "")).strip_edges().to_lower() == "core":
				return true

	return false

func _looks_like_heavy_slice(slice_id: String, pending_row: Dictionary = {}) -> bool:
	var haystack: String = "%s %s %s" % [
		str(slice_id).strip_edges().to_lower(),
		str(pending_row.get("save_key", "")).strip_edges().to_lower(),
		str(pending_row.get("governor_policy", "")).strip_edges().to_lower()
	]

	for hint in HEAVY_SLICE_HINTS:
		if haystack.find(str(hint)) >= 0:
			return true

	return false

func _apply_runtime_guard_patch(patch: Dictionary) -> void:
	if patch.is_empty():
		return

	if contract_engine != null and "runtime_guard" in contract_engine:
		var current_raw: Variant = contract_engine.runtime_guard
		var current: Dictionary = current_raw.duplicate(true) if typeof(current_raw) == TYPE_DICTIONARY else {}
		contract_engine.runtime_guard = _merge_dict(current, patch)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var scenario_guard: Dictionary = scenario_raw.duplicate(true) if typeof(scenario_raw) == TYPE_DICTIONARY else {}
		gs.scenario_state ["runtime_guard"] = _merge_dict(scenario_guard, patch)

func _apply_pending_slice_patch(patched_pending: Dictionary) -> void:
	if contract_engine == null:
		return
	if not ("pending_save_slices" in contract_engine):
		return
	contract_engine.pending_save_slices = patched_pending.duplicate(true)

func _write_report(report: Dictionary) -> void:
	if contract_engine != null and "last_cross_governor_sync_report" in contract_engine:
		contract_engine.last_cross_governor_sync_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_governor_sync_report"] = report.duplicate(true)

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		out [key] = patch [key]
	return out