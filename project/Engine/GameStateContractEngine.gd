extends Resource
class_name GameStateContractEngine

const CONTRACT_SCHEMA:= "eralife.game_state_contract"
const CONTRACT_VERSION:= 3
const DEFAULT_STATE_ID:= "eralife_default_world"
const GAME_STATE_PACK_FOLDER:= "user://eralife_packs/game_state"

const ALLOWED_BOOT_PHASES:= [
	"kernel",
	"world_structure",
	"identity",
	"memory",
	"scenario",
	"life_domain",
	"realm_domain",
	"economy_domain",
	"supernatural_domain",
	"combat_domain",
	"runtime",
	"diagnostics",
	"domain_extensions"
]

const DEFAULT_RUNTIME_PHASES:= [
	"pre_year",
	"year_and_era_mutation",
	"population_lifecycle",
	"realm_laws",
	"relationship_drift",
	"faction_pressure",
	"scenario_generation",
	"world_feed_commit",
	"ui_refresh",
	"post_year"
]

const ALLOWED_CONFLICT_POLICIES:= [
	"highest_priority",
	"replace",
	"merge",
	"keep_existing",
	"error"
]

const ALLOWED_MISSING_ENGINE_POLICIES:= [
	"warn",
	"recover",
	"fallback",
	"disable",
	"quarantine",
	"fail"
]

const ALLOWED_MIGRATION_ACTIONS:= [
	"set_default",
	"rename_key",
	"copy_key",
	"delete_key",
	"ensure_dictionary",
	"ensure_array",
	"call_method"
]

const DEFAULT_PHASE_BUDGET_MS:= 4
const DEFAULT_HARD_PHASE_BUDGET_MS:= 12
const DEFAULT_AGE_UP_FRAME_BUDGET_MS:= 6

const YEARLY_EXECUTION_CONTRACT_VERSION:= 1
const YEARLY_EXECUTION_INCREMENTAL:= "incremental"
const YEARLY_EXECUTION_CONSTANT_TIME:= "constant_time"
const YEARLY_EXECUTION_LEGACY:= "legacy_unclassified"

const DEFAULT_YEARLY_QUANTUM_MS:= 2
const DEFAULT_YEARLY_QUANTUM_ITEMS:= 64
const DEFAULT_AGE_UP_VISIBLE_WATCHDOG_MS:= 5200
const DEFAULT_AGE_UP_FORCE_COMPLETE_MS:= 8200

const URL_CAPSULE_SCHEMA:= "eralife.url_capsule"
const URL_CAPSULE_VERSION:= 1
const URL_CAPSULE_PREFIX:= "elc1."
const URL_CAPSULE_INLINE_MAX_CHARS:= 6800
const URL_CAPSULE_LOCAL_FOLDER:= "user://eralife_url_capsules"

const SELF_HOST_SCHEMA:= "eralife.self_host_mode"
const SELF_HOST_VERSION:= 1
const SELF_HOST_DEFAULT_PROTOCOL:= "http"
const SELF_HOST_DEFAULT_PUBLIC_HOST:= "eralife.duckdns.org"
const SELF_HOST_DEFAULT_LOCAL_BIND_HOST:= "0.0.0.0"
const SELF_HOST_DEFAULT_LOCAL_PORT:= 7817
const SELF_HOST_DEFAULT_PUBLIC_PORT:= 80

const LIFE_IDENTITY_SCHEMA:= "eralife.life_identity"
const LIFE_IDENTITY_VERSION:= 1
const LIFE_IDENTITY_FOLDER:= "user://eralife_life_identities"
const LIFE_TIMELINE_EVENT_LIMIT:= 240
const URL_CAPSULE_DECODE_MAX_BYTES:= 67108864

const RELEASE_LIVE_HOT_SWAP_MAX_BYTES:= 32768
const RELEASE_LIVE_HOT_SWAP_MAX_ROWS:= 16
const RELEASE_LIVE_HOT_SWAP_MAX_QUEUE:= 8
const RELEASE_LIVE_HOT_SWAP_SCHEMA:= "eralife.live_release_contract_bundle"
const RELEASE_LIVE_HOT_SWAP_VERSION:= 1

var gs
var active_state_id: String = DEFAULT_STATE_ID
var contract_registry: Dictionary = {}
var engine_registry: Dictionary = {}
var save_slice_registry: Dictionary = {}
var runtime_phase_registry: Dictionary = {}
var event_subscription_registry: Dictionary = {}
var event_bus_contract_registry: Dictionary = {}
var meta_contract_registry: Dictionary = {}
var hydration_registry: Dictionary = {}
var engine_identity_registry: Dictionary = {}
var contract_runtime_manifest: Dictionary = {}
var runtime_capability_registry: Dictionary = {}
var adaptive_resolution_registry: Dictionary = {}
var world_streaming_manifest: Dictionary = {}
var launch_link_registry: Dictionary = {}
var portable_save_capsule_registry: Dictionary = {}
var life_identity_registry: Dictionary = {}
var life_timeline_registry: Dictionary = {}
var multiplayer_world_runtime_registry: Dictionary = {}
var self_host_node_registry: Dictionary = {}

var live_contract_hot_swap_ledger: Array = []
var live_release_hot_swap_queue: Array = []
var live_release_hot_swap_sequence: int = 0
var last_live_release_hot_swap_service_report: Dictionary = {}
var runtime_capability_profile: Dictionary = {}
var last_capability_resolution_report: Dictionary = {}
var last_adaptive_resolution_report: Dictionary = {}
var last_streaming_boot_report: Dictionary = {}
var last_portable_save_capsule_report: Dictionary = {}
var last_multiplayer_runtime_report: Dictionary = {}
var last_self_host_report: Dictionary = {}
var last_live_contract_hot_swap_report: Dictionary = {}
var validation_reports: Dictionary = {}
var pack_file_mtimes: Dictionary = {}
var pending_save_slices: Dictionary = {}
var orphaned_save_slices: Dictionary = {}
var save_contract_registry: Dictionary = {}
var last_save_contract_governor_report: Dictionary = {}
var save_contract_governor
var cross_governor_sync_layer
var last_cross_governor_sync_report: Dictionary = {}
var cross_device_continuity_sync_layer
var cross_device_continuity_registry: Dictionary = {}
var last_cross_device_continuity_report: Dictionary = {}
var instantiated_contract_engines: Dictionary = {}
var runtime_guard: Dictionary = {}
var last_boot_report: Dictionary = {}
var last_validation_report: Dictionary = {}
var last_migration_report: Dictionary = {}
var last_recovery_report: Dictionary = {}
var last_conflict_report: Dictionary = {}
var last_meta_governor_report: Dictionary = {}
var runtime_phase_budget_report: Dictionary = {}
var contract_meta_governor
var conflict_reports: Array = []
var hot_reload_enabled: bool = true

func _ensure_contract_meta_governor():
	if contract_meta_governor == null:
		contract_meta_governor = ContractMetaGovernor.new(gs, self)
	return contract_meta_governor
func _ensure_save_contract_governor():
	if save_contract_governor == null:
		save_contract_governor = SaveContractGovernor.new(gs, self)
	return save_contract_governor
func _ensure_cross_governor_sync_layer():
	if cross_governor_sync_layer == null:
		cross_governor_sync_layer = CrossGovernorSyncLayer.new(gs, self)
	return cross_governor_sync_layer
func _ensure_cross_device_continuity_sync_layer():
	if cross_device_continuity_sync_layer == null:
		cross_device_continuity_sync_layer = CrossDeviceContinuitySyncLayer.new(gs, self)
	return cross_device_continuity_sync_layer
func build_cross_device_continuity_checkpoint(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var layer = _ensure_cross_device_continuity_sync_layer()
	if layer == null:
		return {
			"schema": "eralife.cross_device_continuity_sync_layer",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "CrossDeviceContinuitySyncLayer unavailable."
		}

	var checkpoint: Dictionary = layer.build_continuity_checkpoint(world_id, options)
	last_cross_device_continuity_report = layer.last_report.duplicate(true)

	if not checkpoint.is_empty():
		var checkpoint_id: String = str(checkpoint.get("checkpoint_id", "")).strip_edges()
		var short_resume_id: String = str(checkpoint.get("short_resume_id", "")).strip_edges()

		if checkpoint_id != "":
			cross_device_continuity_registry [checkpoint_id] = checkpoint.duplicate(true)
		if short_resume_id != "":
			cross_device_continuity_registry [short_resume_id] = checkpoint.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_device_continuity_checkpoint"] = checkpoint.duplicate(true)
		gs.scenario_state ["cross_device_continuity_report"] = last_cross_device_continuity_report.duplicate(true)

	return checkpoint

func import_cross_device_continuity_checkpoint(checkpoint: Dictionary, options: Dictionary = {}) -> Dictionary:
	var layer = _ensure_cross_device_continuity_sync_layer()
	if layer == null:
		return {
			"schema": "eralife.cross_device_continuity_import_report",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "CrossDeviceContinuitySyncLayer unavailable."
		}

	var report: Dictionary = layer.import_continuity_checkpoint(checkpoint, options)
	last_cross_device_continuity_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_device_continuity_report"] = report.duplicate(true)

	return report

func resolve_cross_device_continuity_checkpoint(id_or_short_id: String) -> Dictionary:
	var clean_id: String = str(id_or_short_id).strip_edges()
	if clean_id == "":
		return {}

	if cross_device_continuity_registry.has(clean_id):
		var row_raw: Variant = cross_device_continuity_registry.get(clean_id, {})
		return row_raw.duplicate(true) if typeof(row_raw) == TYPE_DICTIONARY else {}

	var layer = _ensure_cross_device_continuity_sync_layer()
	if layer != null and layer.has_method("resolve_continuity_checkpoint"):
		var checkpoint: Dictionary = layer.resolve_continuity_checkpoint(clean_id)
		if not checkpoint.is_empty():
			cross_device_continuity_registry [clean_id] = checkpoint.duplicate(true)
			return checkpoint

	return {}
func sync_cross_governors(context: Dictionary = {}) -> Dictionary:
	var sync_layer = _ensure_cross_governor_sync_layer()
	if sync_layer == null:
		return {
			"schema": "eralife.cross_governor_sync_layer",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "CrossGovernorSyncLayer unavailable."
		}

	var report: Dictionary = sync_layer.synchronize(context)
	last_cross_governor_sync_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["cross_governor_sync_report"] = report.duplicate(true)

	return report
func _init(_gs = null):
	gs = _gs
	_ensure_contract_meta_governor()
	_ensure_save_contract_governor()
	_ensure_cross_governor_sync_layer()
	_ensure_cross_device_continuity_sync_layer()
	call_deferred("_register_release_update_authority")
func _register_release_update_authority() -> void:
	if bool(
		get_meta(
			"release_update_authority_registered",
			false
		)
	):
		return

	var main_loop: MainLoop = Engine.get_main_loop()
	if (
		main_loop == null
		or not (main_loop is SceneTree)
	):
		return

	var tree: SceneTree = main_loop as SceneTree
	if tree.root == null:
		return

	var runtime_layer: Node = tree.root.get_node_or_null(
		"ReleaseUpdateRuntimeLayer"
	)

	if (
		runtime_layer == null
		or not runtime_layer.has_method(
			"register_contract_authority"
		)
	):
		var attempt_count: int = int(
			get_meta(
				"release_update_authority_registration_attempts",
				0
			)
		)

		if attempt_count >= 20:
			set_meta(
				"release_update_authority_registration_exhausted",
				true
			)
			set_meta(
				"release_update_authority_registration_exhausted_at_ms",
				int(
					Time.get_ticks_msec()
				)
			)
			return

		set_meta(
			"release_update_authority_registration_attempts",
			attempt_count + 1
		)




		var retry_timer:= tree.create_timer(
			0.5
		)
		retry_timer.timeout.connect(
			Callable(
				self,
				"_register_release_update_authority"
			),
			CONNECT_ONE_SHOT
		)
		return

	runtime_layer.call(
		"register_contract_authority",
		self
	)

	set_meta(
		"release_update_authority_registered",
		true
	)
	set_meta(
		"release_update_authority_registered_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"release_update_authority_registration_exhausted",
		false
	)

func ensure_pack_folders() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GAME_STATE_PACK_FOLDER))


func bootstrap_kernel_contract(
	options: Dictionary = {}
) -> Dictionary:
	ensure_pack_folders()
	conflict_reports.clear()

	var report:= {
		"schema": "eralife.game_state_contract_boot_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"loaded": [],
		"failed": [],
		"warnings": [],
		"builtin_packs": [],
		"capability_profile": {},
		"adaptive_resolution": {},
		"streaming_boot": {},
		"validation": {},
		"conflicts": [],
		"booted_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if not contract_registry.has(DEFAULT_STATE_ID):
		var default_contract: Dictionary = normalize_contract(
			_build_default_legacy_contract(),
			"builtin://eralife_default_world"
		)
		contract_registry [DEFAULT_STATE_ID] = (
			default_contract.duplicate(true)
		)
		_ingest_contract(
			default_contract
		)

	var mini_game_pack_report: Dictionary = (
		register_builtin_contract_pack_from_path(
			"res://MiniGameEcosystem/MiniGameEcosystemContractPack.gd",
			"builtin_minigame_ecosystem"
		)
	)

	report ["builtin_packs"].append(
		mini_game_pack_report.duplicate(true)
	)

	if not bool(
		mini_game_pack_report.get(
			"success",
			true
		)
	):
		report ["warnings"].append(
			"The optional MiniGame ecosystem contract pack could not be ingested."
		)

	var allow_external_contracts: bool = bool(
		options.get(
			"allow_external_contracts",
			true
		)
	)

	if allow_external_contracts:
		var external_report: Dictionary = (
			load_external_contracts()
		)

		for row in external_report.get(
			"loaded",
			[]
		):
			report ["loaded"].append(row)

		for row in external_report.get(
			"failed",
			[]
		):
			report ["failed"].append(row)

	var requested_state_id: String = str(
		options.get(
			"state_id",
			active_state_id
		)
	).strip_edges()

	if (
		requested_state_id != ""
		and contract_registry.has(
			requested_state_id
		)
	):
		active_state_id = requested_state_id
	elif not contract_registry.has(active_state_id):
		active_state_id = DEFAULT_STATE_ID

	report ["capability_profile"] = (
		resolve_runtime_capability_profile(
			options.get(
				"runtime_capability_profile",
				{}
			)
		)
	)
	report ["adaptive_resolution"] = (
		resolve_adaptive_contracts({
			"phase": "bootstrap_kernel_contract",
			"source": "bootstrap_kernel_contract",
			"capability_profile": (
				runtime_capability_profile.duplicate(true)
			)
		})
	)
	report ["streaming_boot"] = (
		prepare_world_streaming_boot({
			"phase": "bootstrap_kernel_contract",
			"source": "bootstrap_kernel_contract",
			"launch": options.get(
				"launch",
				{}
			)
		})
	)

	var validation: Dictionary = (
		validate_active_contracts({
			"phase": "bootstrap_kernel_contract",
			"include_runtime": false,
			"capability_profile": (
				runtime_capability_profile.duplicate(true)
			)
		})
	)

	report ["state_id"] = active_state_id
	report ["engine_count"] = engine_registry.size()
	report ["save_slice_count"] = (
		save_slice_registry.size()
	)
	report ["runtime_phase_count"] = (
		runtime_phase_registry.size()
	)
	report ["event_subscription_count"] = (
		event_subscription_registry.size()
	)
	report ["validation"] = validation.duplicate(true)
	report ["conflicts"] = conflict_reports.duplicate(true)

	if not bool(
		validation.get(
			"valid",
			true
		)
	):
		report ["warnings"].append(
			"GameState contract boot completed with validation issues."
		)

	last_boot_report = report.duplicate(true)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"game_state_contract_last_boot_report"
		] = report.duplicate(true)

	return report
func resolve_runtime_capability_profile(raw_profile: Variant = {}) -> Dictionary:
	var profile: Dictionary = {}

	if typeof(raw_profile) == TYPE_STRING:
		var profile_id: String = str(raw_profile).strip_edges()
		if runtime_capability_registry.has(profile_id):
			profile = runtime_capability_registry.get(profile_id, {}).duplicate(true)
	elif typeof(raw_profile) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw_profile
		var raw_id: String = str(raw_dict.get("id", raw_dict.get("profile_id", ""))).strip_edges()
		if raw_id != "" and runtime_capability_registry.has(raw_id):
			profile = runtime_capability_registry.get(raw_id, {}).duplicate(true)
			profile = _merged_dictionary_copy(profile, raw_dict)
		else:
			profile = raw_dict.duplicate(true)

	if profile.is_empty():
		profile = _detect_runtime_capability_profile()

	profile = _normalize_runtime_capability_profile(profile, active_state_id)
	runtime_capability_profile = profile.duplicate(true)

	last_capability_resolution_report = {
		"schema": "eralife.runtime_capability_resolution_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"profile": runtime_capability_profile.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["runtime_capability_profile"] = runtime_capability_profile.duplicate(true)
		gs.scenario_state ["runtime_capability_resolution_report"] = last_capability_resolution_report.duplicate(true)

	return last_capability_resolution_report.duplicate(true)


func resolve_adaptive_contracts(context: Dictionary = {}) -> Dictionary:
	if runtime_capability_profile.is_empty():
		resolve_runtime_capability_profile({})

	var capability: Dictionary = runtime_capability_profile.duplicate(true)
	var guard_patch: Dictionary = _guard_patch_for_capability_profile(capability)
	var report:= {
		"schema": "eralife.adaptive_contract_resolution_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"capability_profile": capability.duplicate(true),
		"applied": [],
		"skipped": [],
		"disabled_engines": [],
		"runtime_guard_patch": guard_patch.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	var rules: Array = _default_adaptive_resolution_rules()
	for raw_rule in adaptive_resolution_registry.values():
		if typeof(raw_rule) == TYPE_DICTIONARY:
			rules.append((raw_rule as Dictionary).duplicate(true))

	rules.sort_custom(func (a, b): return int(a.get("priority", 100)) < int(b.get("priority", 100)))

	for raw_rule in rules:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = raw_rule
		if not bool(rule.get("enabled", true)):
			continue

		if not _adaptive_rule_matches_capability(rule, capability):
			report ["skipped"].append({
				"id": str(rule.get("id", "")),
				"reason": "capability_mismatch"
			})
			continue

		var rule_report: Dictionary = _apply_adaptive_resolution_rule(rule, capability)
		if bool(rule_report.get("applied", false)):
			report ["applied"].append(rule_report)

			var rule_patch_raw: Variant = rule_report.get("runtime_guard_patch", {})
			if typeof(rule_patch_raw) == TYPE_DICTIONARY:
				guard_patch = _merged_dictionary_copy(guard_patch, rule_patch_raw as Dictionary)

			if str(rule_report.get("action", "")) == "disable_engine":
				report ["disabled_engines"].append(str(rule_report.get("engine_id", "")))
		else:
			report ["skipped"].append(rule_report)

	report ["runtime_guard_patch"] = guard_patch.duplicate(true)
	last_adaptive_resolution_report = report.duplicate(true)

	runtime_guard = _merged_dictionary_copy(runtime_guard, guard_patch)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["adaptive_contract_resolution_report"] = report.duplicate(true)

		var scenario_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var scenario_guard: Dictionary = scenario_guard_raw.duplicate(true) if typeof(scenario_guard_raw) == TYPE_DICTIONARY else {}
		scenario_guard = _merged_dictionary_copy(scenario_guard, guard_patch)
		gs.scenario_state ["runtime_guard"] = scenario_guard

	return report

func _legacy_yearly_runtime_task_ids() -> Dictionary:
	return {
		"world.age_npcs": true,
		"world.process_pregnancies": true,
		"world.npc_have_children": true,
		"world.process_divorces": true,
		"world.process_remarriages": true,
		"world.process_movement": true,

		"dynamic_world.era_events": true,
		"dynamic_world.artifact_events": true,
		"dynamic_world.bending_events": true,
		"dynamic_world.bonnet_events": true,
		"dynamic_world.asset_ecology_events": true,

		"life.refresh_relationship_targets": true,
		"life.finalize_life_year_contract": true
	}
func prepare_world_streaming_boot(context: Dictionary = {}) -> Dictionary:
	if runtime_capability_profile.is_empty():
		resolve_runtime_capability_profile({})

	if world_streaming_manifest.is_empty():
		world_streaming_manifest = _build_default_world_streaming_manifest(active_state_id)

	var profile: Dictionary = runtime_capability_profile.duplicate(true)
	var launch_raw: Variant = context.get("launch", {})
	var launch_context: Dictionary = launch_raw.duplicate(true) if typeof(launch_raw) == TYPE_DICTIONARY else {}

	var manifest: Dictionary = world_streaming_manifest.duplicate(true)
	manifest ["state_id"] = str(manifest.get("state_id", active_state_id)).strip_edges()
	if str(manifest.get("state_id", "")).strip_edges() == "":
		manifest ["state_id"] = active_state_id

	var raw_stages: Array = manifest.get("stages", []) if typeof(manifest.get("stages", [])) == TYPE_ARRAY else []
	var stage_rows: Array = []
	for raw_stage in raw_stages:
		if typeof(raw_stage) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = (raw_stage as Dictionary).duplicate(true)
		var stage_id: String = str(stage.get("id", "")).strip_edges()
		if stage_id == "":
			continue
		stage ["id"] = stage_id
		stage ["order"] = int(stage.get("order", 100))
		stage_rows.append(stage)

	stage_rows.sort_custom(func (a, b): return int(a.get("order", 100)) < int(b.get("order", 100)))

	var limits: Dictionary = manifest.get("limits", {}) if typeof(manifest.get("limits", {})) == TYPE_DICTIONARY else {}
	limits ["boot_core_only"] = bool(limits.get("boot_core_only", true))
	limits ["visible_npc_soft_cap"] = int(profile.get("npc_soft_cap", limits.get("visible_npc_soft_cap", 2500)))
	limits ["region_stream_radius"] = int(profile.get("region_stream_radius", limits.get("region_stream_radius", 1)))
	limits ["event_stream_limit"] = int(profile.get("event_stream_limit", limits.get("event_stream_limit", 80)))
	limits ["stream_chunk_budget"] = int(profile.get("stream_chunk_budget", limits.get("stream_chunk_budget", 96)))
	limits ["background_work_policy"] = str(profile.get("background_work_policy", limits.get("background_work_policy", "defer_until_idle")))

	var cache_policy: Dictionary = manifest.get("cache_policy", {}) if typeof(manifest.get("cache_policy", {})) == TYPE_DICTIONARY else {}
	cache_policy ["offline_capable"] = bool(profile.get("offline_capable", cache_policy.get("offline_capable", true)))
	cache_policy ["persistent_save"] = bool(profile.get("persistent_save", cache_policy.get("persistent_save", true)))
	cache_policy ["cache_namespace"] = str(profile.get("cache_namespace", cache_policy.get("cache_namespace", "eralife.worlds.v1")))
	cache_policy ["save_persistence_key"] = str(profile.get("save_persistence_key", launch_context.get("save_persistence_key", "eralife.save.%s" % _safe_link_id(active_state_id))))
	cache_policy ["service_worker_scope"] = str(cache_policy.get("service_worker_scope", "/"))
	cache_policy ["cache_core_identity_first"] = true

	var core_loaded: Array = []
	var pending: Array = []
	var stream_queue: Array = []

	for stage in stage_rows:
		var stage_id: String = str(stage.get("id", "")).strip_edges()
		var load_at_boot: bool = bool(stage.get("load_at_boot", false))
		var stream_key: String = str(stage.get("stream_key", stage_id)).strip_edges()

		if load_at_boot:
			core_loaded.append(stage_id)
		else:
			pending.append(stage_id)
			stream_queue.append({
				"id": stage_id,
				"stream_key": stream_key,
				"order": int(stage.get("order", 100)),
				"contains": stage.get("contains", []).duplicate(true) if typeof(stage.get("contains", [])) == TYPE_ARRAY else [],
				"chunk_budget": int(stage.get("chunk_budget", limits.get("stream_chunk_budget", 96))),
			})

	manifest ["enabled"] = bool(profile.get("streaming_enabled", manifest.get("enabled", true)))
	manifest ["strategy"] = str(manifest.get("strategy", "core_identity_first"))
	manifest ["stages"] = stage_rows
	manifest ["limits"] = limits
	manifest ["cache_policy"] = cache_policy
	manifest ["stream_queue"] = stream_queue
	manifest ["runtime_capability_profile"] = profile.duplicate(true)

	world_streaming_manifest = manifest.duplicate(true)

	var streaming_guard_patch:= {
		"world_streaming_enabled": bool(manifest.get("enabled", true)),
		"world_streaming_boot_core_only": bool(limits.get("boot_core_only", true)),
		"adaptive_npc_soft_cap": int(limits.get("visible_npc_soft_cap", 2500)),
		"runtime_snapshot_items_per_step": int(limits.get("stream_chunk_budget", 96)),
		"ui_alive_priority": true,
		"ui_tail_work_yield_to_input": true,
		"defer_noncritical_systems": true,
		"fallback_cached_ui": true,
		"save_persistence_key": str(cache_policy.get("save_persistence_key", "")),
		"offline_world_cache_namespace": str(cache_policy.get("cache_namespace", "eralife.worlds.v1"))
	}

	runtime_guard = _merged_dictionary_copy(runtime_guard, streaming_guard_patch)

	last_streaming_boot_report = {
		"schema": "eralife.world_streaming_boot_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"launch": launch_context.duplicate(true),
		"enabled": bool(manifest.get("enabled", true)),
		"core_only_boot": bool(limits.get("boot_core_only", true)),
		"core_loaded_stages": core_loaded,
		"pending_stream_stages": pending,
		"stream_queue": stream_queue.duplicate(true),
		"limits": limits.duplicate(true),
		"cache_policy": cache_policy.duplicate(true),
		"runtime_guard_patch": streaming_guard_patch.duplicate(true),
		"prepared_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["world_streaming_manifest"] = world_streaming_manifest.duplicate(true)
		gs.scenario_state ["world_streaming_boot_report"] = last_streaming_boot_report.duplicate(true)

		var scenario_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var scenario_guard: Dictionary = scenario_guard_raw.duplicate(true) if typeof(scenario_guard_raw) == TYPE_DICTIONARY else {}
		scenario_guard = _merged_dictionary_copy(scenario_guard, streaming_guard_patch)
		gs.scenario_state ["runtime_guard"] = scenario_guard

	return last_streaming_boot_report.duplicate(true)

func _strip_url_scheme_and_path(raw_host: String) -> String:
	var clean_host: String = str(raw_host).strip_edges()
	if clean_host == "":
		return ""

	clean_host = clean_host.replace("https://", "")
	clean_host = clean_host.replace("http://", "")

	var slash_idx: int = clean_host.find("/")
	if slash_idx >= 0:
		clean_host = clean_host.substr(0, slash_idx)

	return clean_host.trim_suffix("/")


func _url_port_suffix(protocol: String, port: int, host: String = "") -> String:
	var clean_protocol: String = str(protocol).strip_edges().to_lower()
	var clean_host: String = str(host).strip_edges()

	if port <= 0:
		return ""

	if clean_host.find(":") >= 0:
		return ""

	if clean_protocol == "http" and port == 80:
		return ""

	if clean_protocol == "https" and port == 443:
		return ""

	return ":%d" % port


func _normalize_duckdns_domain(raw_host: String) -> String:
	var clean_host: String = _strip_url_scheme_and_path(raw_host).to_lower()
	var suffix: String = ".duckdns.org"

	if clean_host.ends_with(suffix):
		return clean_host.substr(0, clean_host.length() - suffix.length())

	var colon_idx: int = clean_host.find(":")
	if colon_idx >= 0:
		clean_host = clean_host.substr(0, colon_idx)

	return clean_host
func _hand_self_host_contract_to_runtime_layer(report: Dictionary) -> void:
	if typeof(report) != TYPE_DICTIONARY or report.is_empty():
		return

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred"] = true
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred_reason"] = "always_deferred_scene_tree_boundary"
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["self_host_runtime_layer_deferred_contract"] = report.duplicate(true)
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_pending"] = true

	call_deferred("_flush_deferred_self_host_contract_to_runtime_layer")


func _flush_deferred_self_host_contract_to_runtime_layer() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var report_raw: Variant = gs.scenario_state.get("self_host_runtime_layer_deferred_contract", {})
	if typeof(report_raw) != TYPE_DICTIONARY:
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_pending"] = false
		return

	var report: Dictionary = (report_raw as Dictionary).duplicate(true)
	if report.is_empty():
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_pending"] = false
		return

	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred"] = true
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred_reason"] = "scene_tree_unavailable_retry"
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_retry_at_ms"] = int(Time.get_ticks_msec())
		call_deferred("_flush_deferred_self_host_contract_to_runtime_layer")
		return

	var tree: SceneTree = main_loop as SceneTree
	if tree.root == null:
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred"] = true
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred_reason"] = "scene_tree_root_unavailable_retry"
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_retry_at_ms"] = int(Time.get_ticks_msec())
		call_deferred("_flush_deferred_self_host_contract_to_runtime_layer")
		return

	var runtime_layer: Node = tree.root.get_node_or_null("SelfHostRuntimeLayer")
	if runtime_layer == null:
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred"] = true
		gs.scenario_state ["self_host_runtime_layer_handoff_deferred_reason"] = "self_host_runtime_layer_missing"
		gs.scenario_state ["self_host_runtime_layer_deferred_flush_pending"] = false
		return

	gs.scenario_state.erase("self_host_runtime_layer_deferred_contract")
	gs.scenario_state ["self_host_runtime_layer_handoff_deferred"] = false
	gs.scenario_state ["self_host_runtime_layer_deferred_flush_pending"] = false
	gs.scenario_state ["self_host_runtime_layer_handoff_flushed_at_ms"] = int(Time.get_ticks_msec())

	if runtime_layer.has_method("set_self_host_contract"):
		runtime_layer.call_deferred("set_self_host_contract", report)
func build_self_host_mode(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var safe_world_id: String = _safe_link_id(clean_world_id)
	var enabled: bool = bool(options.get("self_host_enabled", false))

	var protocol: String = str(options.get("self_host_protocol", SELF_HOST_DEFAULT_PROTOCOL)).strip_edges().to_lower()
	if protocol == "":
		protocol = SELF_HOST_DEFAULT_PROTOCOL

	var public_host: String = _strip_url_scheme_and_path(str(options.get("self_host_domain", options.get("host", SELF_HOST_DEFAULT_PUBLIC_HOST))))
	if public_host == "":
		public_host = SELF_HOST_DEFAULT_PUBLIC_HOST

	var local_bind_host: String = str(options.get("self_host_bind_host", SELF_HOST_DEFAULT_LOCAL_BIND_HOST)).strip_edges()
	if local_bind_host == "":
		local_bind_host = SELF_HOST_DEFAULT_LOCAL_BIND_HOST

	var local_port: int = int(options.get("self_host_local_port", SELF_HOST_DEFAULT_LOCAL_PORT))
	if local_port <= 0:
		local_port = SELF_HOST_DEFAULT_LOCAL_PORT

	var public_port: int = int(options.get("self_host_public_port", SELF_HOST_DEFAULT_PUBLIC_PORT))
	if public_port <= 0:
		public_port = SELF_HOST_DEFAULT_PUBLIC_PORT

	var duckdns_domain: String = _normalize_duckdns_domain(public_host)
	var public_port_suffix: String = _url_port_suffix(protocol, public_port, public_host)
	var local_port_suffix: String = _url_port_suffix("http", local_port, "127.0.0.1")

	var public_base_url: String = "%s://%s%s" % [protocol, public_host, public_port_suffix]
	var local_base_url: String = "http://127.0.0.1%s" % local_port_suffix
	var lan_base_url: String = "http://{LAN_IP}%s" % _url_port_suffix("http", local_port, "{LAN_IP}")

	var play_path: String = "/play/%s" % safe_world_id
	var token_configured: bool = bool(options.get("duckdns_token_configured", false))
	if str(options.get("duckdns_token", "")).strip_edges() != "":
		token_configured = true

	var runtime_id: String = str(options.get("self_host_runtime_id", "%s.self_host.%d" % [safe_world_id, int(Time.get_ticks_msec())])).strip_edges()
	if runtime_id == "":
		runtime_id = "%s.self_host.%d" % [safe_world_id, int(Time.get_ticks_msec())]

	var authority_mode: String = str(options.get("authority_mode", options.get("multiplayer_authority_mode", "host_authoritative"))).strip_edges().to_lower()
	if authority_mode == "":
		authority_mode = "host_authoritative"

	var report:= {
		"schema": SELF_HOST_SCHEMA,
		"version": SELF_HOST_VERSION,
		"runtime_contract_version": CONTRACT_VERSION,
		"enabled": enabled,
		"runtime_id": runtime_id,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"state_id": active_state_id,
		"authority_mode": authority_mode,
		"node": {
			"role": "host",
			"kind": "player_machine_reality_node",
			"local_bind_host": local_bind_host,
			"local_port": local_port,
			"public_host": public_host,
			"public_port": public_port,
			"protocol": protocol,
			"public_base_url": public_base_url,
			"local_base_url": local_base_url,
			"lan_base_url_template": lan_base_url
		},
		"links": {
			"public_play_url": "%s%s" % [public_base_url, play_path],
			"public_status_url": "%s/self_host/status" % public_base_url,
			"public_manifest_url": "%s/self_host/manifest/%s" % [public_base_url, safe_world_id],
			"local_play_url": "%s%s" % [local_base_url, play_path],
			"lan_play_url_template": "%s%s" % [lan_base_url, play_path],
			"webrtc_invite_url": "%s%s?multiplayer=1&transport=webrtc&authority=%s" % [public_base_url, play_path, authority_mode]
		},
		"duckdns": {
			"enabled": enabled and duckdns_domain != "",
			"domain": duckdns_domain,
			"public_host": public_host,
			"token_configured": token_configured,
			"token_persisted": false,
			"token_storage": "local_private_config_only",
			"update_url_template": "https://www.duckdns.org/update?domains=%s&token={DUCKDNS_TOKEN}&ip={PUBLIC_IP}&verbose=true" % duckdns_domain,
			"never_write_token_to_capsule": true,
			"never_write_token_to_share_url": true
		},
		"port_forwarding": {
			"router_rule": {
				"external_protocol": "tcp",
				"external_port": public_port,
				"internal_host": "{THIS_DEVICE_LAN_IP}",
				"internal_port": local_port
			},
			"fallback_if_unavailable": "webrtc_relay"
		},
		"transports": {
			"direct_http": {
				"enabled": enabled,
				"url": "%s%s" % [public_base_url, play_path]
			},
			"lan_http": {
				"enabled": enabled,
				"url_template": "%s%s" % [lan_base_url, play_path]
			},
			"webrtc_relay": {
				"enabled": bool(options.get("self_host_webrtc_relay_enabled", true)),
				"signaling_url": str(options.get("webrtc_signaling_url", "")).strip_edges(),
				"peer_class": "WebRTCMultiplayerPeer",
				"authority_mode": authority_mode
			}
		},
		"runtime_guard_patch": {
			"self_host_mode_enabled": enabled,
			"self_host_runtime_id": runtime_id,
			"self_host_transport_priority": [
				"direct_http",
				"lan_http",
				"webrtc_relay"
			],
			"multiplayer_authority_mode": authority_mode,
			"world_streaming_enabled": true,
			"ui_alive_priority": true,
			"ui_tail_work_yield_to_input": true,
			"defer_noncritical_systems": true
		},
		"security": {
			"recommended_default": "disabled_until_player_turns_on_self_host"
		},
		"compatibility": {
			"backwards_compatible": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	report ["background_tasks"] = {
	"duckdns_updater": {
		"schema": "eralife.self_host_background_task",
		"version": SELF_HOST_VERSION,
		"enabled": enabled and bool(report.get("duckdns", {}).get("enabled", false)) if typeof(report.get("duckdns", {})) == TYPE_DICTIONARY else false,
		"task_id": "%s.duckdns_updater" % runtime_id,
		"autoload": "SelfHostRuntimeLayer",
		"interval_sec": int(options.get("duckdns_update_interval_sec", 300)),
		"min_interval_sec": 60,
		"runs_in": "self_host_runtime_layer",
		"not_ui": true,
		"token_source": "user://self_host_config.json",
	}
}

	report ["continuity"] = {
		"schema": "eralife.self_host_continuity_contract",
		"version": SELF_HOST_VERSION,
		"enabled": enabled,
		"short_live_url": str(report.get("links", {}).get("public_play_url", "")) if typeof(report.get("links", {})) == TYPE_DICTIONARY else "",
	}

	if enabled:
		self_host_node_registry [runtime_id] = report.duplicate(true)
		self_host_node_registry [clean_world_id] = report.duplicate(true)
		self_host_node_registry [safe_world_id] = report.duplicate(true)
		runtime_guard = _merged_dictionary_copy(runtime_guard, report.get("runtime_guard_patch", {}))

	last_self_host_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["self_host_mode"] = report.duplicate(true)
		gs.scenario_state ["self_host_node_registry"] = self_host_node_registry.duplicate(true)
		gs.scenario_state ["last_self_host_report"] = last_self_host_report.duplicate(true)
		if enabled:
			var scenario_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
			var scenario_guard: Dictionary = scenario_guard_raw.duplicate(true) if typeof(scenario_guard_raw) == TYPE_DICTIONARY else {}
			scenario_guard = _merged_dictionary_copy(scenario_guard, report.get("runtime_guard_patch", {}))
			gs.scenario_state ["runtime_guard"] = scenario_guard

	_hand_self_host_contract_to_runtime_layer(report)
	return report
func build_default_self_host_tap_to_play_links(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var merged_options:= {
		"self_host_enabled": true,
		"self_host_domain": SELF_HOST_DEFAULT_PUBLIC_HOST,
		"self_host_protocol": SELF_HOST_DEFAULT_PROTOCOL,
		"self_host_public_port": SELF_HOST_DEFAULT_PUBLIC_PORT,
		"self_host_local_port": SELF_HOST_DEFAULT_LOCAL_PORT,
		"duckdns_token_configured": true,
		"self_host_webrtc_relay_enabled": true,
		"multiplayer_authority_mode": "host_authoritative",
		"include_life_identity": true,
		"duckdns_update_interval_sec": 300
	}

	for key in options.keys():
		merged_options [key] = options [key]

	merged_options.erase("duckdns_token")

	var links: Dictionary = build_tap_to_play_links(clean_world_id, merged_options)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["default_self_host_tap_to_play_links"] = links.duplicate(true)

	return links
func build_tap_to_play_links(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id
	var safe_world_id: String = _safe_link_id(clean_world_id)
	var url_origin: String = _resolve_share_url_origin(options)
	var self_host_requested: bool = bool(options.get("self_host_enabled", false))
	var host: String = str(options.get("host", "eralife.app")).strip_edges()
	if self_host_requested:
		host = str(options.get("self_host_domain", host)).strip_edges()
	if host == "":
		host = SELF_HOST_DEFAULT_PUBLIC_HOST if self_host_requested else "eralife.app"
	host = _strip_url_scheme_and_path(host)

	var link_protocol: String = str(options.get("link_protocol", "https")).strip_edges().to_lower()
	if self_host_requested:
		link_protocol = str(options.get("self_host_protocol", SELF_HOST_DEFAULT_PROTOCOL)).strip_edges().to_lower()
	if link_protocol == "":
		link_protocol = SELF_HOST_DEFAULT_PROTOCOL if self_host_requested else "https"

	var link_port: int = int(options.get("link_port", 0))
	if self_host_requested:
		link_port = int(options.get("self_host_public_port", SELF_HOST_DEFAULT_PUBLIC_PORT))
	var host_with_port: String = "%s%s" % [host, _url_port_suffix(link_protocol, link_port, host)]

	var scheme: String = str(options.get("scheme", "eralife")).strip_edges()
	if scheme == "":
		scheme = "eralife"

	var native_route: String = str(options.get("native_route", "play")).strip_edges().to_lower()
	if native_route == "":
		native_route = "play"

	var world_query_key: String = str(options.get("world_query_key", "world_id")).strip_edges()
	if world_query_key == "":
		world_query_key = "world_id"

	var capsule_query_key: String = str(options.get("capsule_query_key", "capsule")).strip_edges()
	if capsule_query_key == "":
		capsule_query_key = "capsule"

	var capsule_id_query_key: String = str(options.get("capsule_id_query_key", "capsule_id")).strip_edges()
	if capsule_id_query_key == "":
		capsule_id_query_key = "capsule_id"

	var static_host: String = str(options.get("static_host", "netlify")).strip_edges().to_lower()
	if self_host_requested:
		static_host = "self_host"
	if static_host == "":
		static_host = "netlify"

	var self_host_mode: Dictionary = build_self_host_mode(clean_world_id, options)
	var world_version: int = max(1, int(options.get("world_version", CONTRACT_VERSION)))
	var app_version: int = max(1, int(options.get("app_version", CONTRACT_VERSION)))

	var life_identity: Dictionary = {}
	if bool(options.get("include_life_identity", gs != null and gs.player != null)):
		var identity_options: Dictionary = options.duplicate(true)
		identity_options ["world_id"] = clean_world_id
		life_identity = ensure_life_identity(identity_options)

	var life_id: String = str(life_identity.get("life_id", "")).strip_edges()
	var timeline_id: String = str(life_identity.get("timeline_id", "")).strip_edges()
	var persistence_id: String = life_id if life_id != "" else safe_world_id

	var save_persistence_key: String = str(options.get("save_persistence_key", "eralife.save.%s" % persistence_id)).strip_edges()
	if save_persistence_key == "":
		save_persistence_key = "eralife.save.%s" % persistence_id

	var cache_namespace: String = str(options.get("cache_namespace", "eralife.world.%s" % safe_world_id)).strip_edges()
	if cache_namespace == "":
		cache_namespace = "eralife.world.%s" % safe_world_id

	var app_cache_name: String = str(options.get("app_cache_name", "eralife.app.v%d" % app_version)).strip_edges()
	var world_cache_name: String = str(options.get("world_cache_name", "%s.v%d" % [cache_namespace, world_version])).strip_edges()

	var base_path: String = str(options.get("base_path", "")).strip_edges()
	if base_path != "" and not base_path.begins_with("/"):
		base_path = "/%s" % base_path
	base_path = base_path.trim_suffix("/")

	var shell_path: String = "%s/index.html" % base_path
	if base_path == "":
		shell_path = "/index.html"

	var play_path: String = "%s/play/%s" % [base_path, safe_world_id]
	var mobile_path: String = "%s/m/play/%s" % [base_path, safe_world_id]
	var tv_path: String = "%s/tv/play/%s" % [base_path, safe_world_id]

	var required_assets:= [
		"%s/index.html" % base_path,
		"%s/index.js" % base_path,
		"%s/index.wasm" % base_path,
		"%s/index.pck" % base_path
	]

	var streamed_assets:= [
		"%s/world/core_identity" % base_path,
		"%s/world/regions" % base_path,
		"%s/world/factions" % base_path,
		"%s/world/people" % base_path,
		"%s/world/events" % base_path
	]

	var world_slice_routes:= {
		"core_identity": "%s/world/core_identity" % base_path,
		"regions": "%s/world/regions" % base_path,
		"factions": "%s/world/factions" % base_path,
		"people": "%s/world/people" % base_path,
		"events": "%s/world/events" % base_path
	}

	var netlify_redirects:= [
		"# EraLife routed runtime links -> Godot Web shell",
		"/play/* /index.html 200",
		"/tv/play/* /index.html 200",
		"/m/play/* /index.html 200",
		"/offline/* /index.html 200",
		"/capsule/* /index.html 200",
		"/multiplayer/* /index.html 200",
		"/* /index.html 200"
	]

	var netlify_headers:= [
		"/*",
		"\tCross-Origin-Opener-Policy: same-origin",
		"\tCross-Origin-Embedder-Policy: require-corp",
		"\tCross-Origin-Resource-Policy: same-origin",
		"\tX-Content-Type-Options: nosniff",
		"",
		"/index.html",
		"\tCache-Control: no-cache",
		"",
		"/index.js",
		"\tCache-Control: public, max-age=31536000, immutable",
		"",
		"/index.wasm",
		"\tContent-Type: application/wasm",
		"\tCache-Control: public, max-age=31536000, immutable",
		"",
		"/index.pck",
		"\tContent-Type: application/octet-stream",
		"\tCache-Control: public, max-age=31536000, immutable",
		"",
		"/index.service.worker.js",
		"\tCache-Control: no-cache",
		"",
		"/service-worker.js",
		"\tCache-Control: no-cache",
		"",
		"/index.manifest.json",
		"\tContent-Type: application/manifest+json",
		"\tCache-Control: no-cache",
		"",
		"/manifest.webmanifest",
		"\tContent-Type: application/manifest+json",
		"\tCache-Control: no-cache"
	]

	var native_play_url: String = "%s://%s?%s=%s" % [scheme, native_route, world_query_key, safe_world_id]
	var native_world_legacy_url: String = "%s://world?id=%s" % [scheme, safe_world_id]
	var native_capsule_template: String = "%s://%s?%s={encoded_capsule}" % [scheme, native_route, capsule_query_key]
	var native_capsule_id_template: String = "%s://%s?%s={capsule_id}" % [scheme, native_route, capsule_id_query_key]

	var launch_payload:= {
		"schema": "eralife.launch_payload",
		"version": CONTRACT_VERSION,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"state_id": str(options.get("state_id", active_state_id)),
		"life_id": life_id,
		"timeline_id": timeline_id,
		"life_identity": life_identity.duplicate(true),
		"runtime_capability_profile": options.get("runtime_capability_profile", {}).duplicate(true) if typeof(options.get("runtime_capability_profile", {})) == TYPE_DICTIONARY else {},
		"streaming": {
			"enabled": true,
			"strategy": "core_identity_first",
			"world_slice_routes": world_slice_routes.duplicate(true)
		},
		"persistence": {
			"save_persistence_key": save_persistence_key,
			"cache_namespace": cache_namespace,
			"app_cache_name": app_cache_name,
			"world_cache_name": world_cache_name,
			"offline_capable": true,
			"persistent": true,
			"official_update_policy": "stable_link_preserve_user_save"
		},
		"static_host": {
			"provider": static_host,
			"shell_path": shell_path,
			"netlify_redirects": netlify_redirects.duplicate(true),
			"netlify_headers": netlify_headers.duplicate(true)
		},
		"hot_swap": {
		},
		"multiplayer": {
			"authority_mode": str(options.get("multiplayer_authority_mode", "host_authoritative")),
			"delta_strategy": "append_only_world_journal"
		},
		"self_host": self_host_mode.duplicate(true),
		"device_ui": {
			"adaptive": true,
			"phone_layout": "vertical_life_runtime",
			"tablet_layout": "hybrid_life_runtime",
			"desktop_layout": "wide_life_runtime",
			"tv_layout": "leanback_world_runtime",
		},
		"url_capsules": {
			"supported": true,
			"max_inline_chars": int(options.get("max_inline_chars", URL_CAPSULE_INLINE_MAX_CHARS)),
			"schema": URL_CAPSULE_SCHEMA,
			"version": URL_CAPSULE_VERSION
		},
		"native_protocol": {
			"supported": true,
			"scheme": scheme,
			"route": native_route,
			"world_query_key": world_query_key,
			"capsule_query_key": capsule_query_key,
			"capsule_id_query_key": capsule_id_query_key,
			"play_url": native_play_url,
			"legacy_world_url": native_world_legacy_url,
			"capsule_template": native_capsule_template,
			"capsule_id_template": native_capsule_id_template,
		},
		"hybrid_transport": {
			"mode": "native_protocol_first_with_web_fallback",
			"web_fallback_host": host,
			"web_capsule_template": "%s://%s%s?capsule={encoded_capsule}" % [link_protocol, host_with_port, play_path],
			"web_capsule_id_template": "%s://%s%s?capsule_id={capsule_id}" % [link_protocol, host_with_port, play_path]
		}
	}

	var offline_manifest:= {
		"schema": "eralife.offline_world_manifest",
		"version": CONTRACT_VERSION,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"world_version": world_version,
		"app_version": app_version,
		"cache_namespace": cache_namespace,
		"app_cache_name": app_cache_name,
		"world_cache_name": world_cache_name,
		"save_persistence_key": save_persistence_key,
		"self_host": self_host_mode.duplicate(true),
		"service_worker_scope": "/",
		"service_worker_url": "%s/service-worker.js" % base_path,
		"godot_service_worker_url": "%s/index.service.worker.js" % base_path,
		"manifest_url": "%s/index.manifest.json" % base_path,
		"shell_path": shell_path,
		"required_assets": required_assets,
		"streamed_assets": streamed_assets,
		"world_slice_routes": world_slice_routes.duplicate(true),
		"static_host": {
			"provider": static_host,
			"netlify_redirects": netlify_redirects.duplicate(true),
			"netlify_headers": netlify_headers.duplicate(true)
		},
		"official_update_policy": {
		}
	}

	var links:= {
		"schema": "eralife.tap_to_play_links",
		"version": CONTRACT_VERSION,
		"world_version": world_version,
		"app_version": app_version,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"origin": url_origin,

		"native": native_play_url,
		"native_play": native_play_url,
		"native_world_legacy": native_world_legacy_url,
		"native_capsule": "%s://%s?%s=1" % [scheme, native_route, capsule_query_key],
		"native_capsule_template": native_capsule_template,
		"native_capsule_id_template": native_capsule_id_template,

		"main": "%s://%s%s?intro=1" % [link_protocol, host_with_port, shell_path],
		"web": "%s://%s%s" % [link_protocol, host_with_port, play_path],
		"short": "%s://%s%s" % [link_protocol, host_with_port, play_path],
		"live": "%s://%s%s" % [link_protocol, host_with_port, play_path],
		"continue": "%s://%s%s" % [link_protocol, host_with_port, play_path],
		"web_shell": "%s://%s%s" % [link_protocol, host_with_port, shell_path],
		"mobile": "%s://%s%s" % [link_protocol, host_with_port, mobile_path],
		"smart_tv": "%s://%s%s" % [link_protocol, host_with_port, tv_path],
		"tv_continue": "%s://%s%s" % [link_protocol, host_with_port, tv_path],
		"offline": "%s://%s%s?offline=1" % [link_protocol, host_with_port, play_path],
		"share": "%s://%s%s?share=1" % [link_protocol, host_with_port, play_path],

		"capsule": "%s://%s%s?capsule=1" % [link_protocol, host_with_port, play_path],
		"capsule_template": "%s://%s%s?capsule={encoded_capsule}" % [link_protocol, host_with_port, play_path],
		"capsule_id_template": "%s://%s%s?capsule_id={capsule_id}" % [link_protocol, host_with_port, play_path],

		"hybrid_capsule_template": native_capsule_template,
		"hybrid_capsule_id_template": native_capsule_id_template,
		"hybrid_web_capsule_template": "%s://%s%s?capsule={encoded_capsule}" % [link_protocol, host_with_port, play_path],
		"hybrid_web_capsule_id_template": "%s://%s%s?capsule_id={capsule_id}" % [link_protocol, host_with_port, play_path],

		"official_update": "%s://%s%s?update=%d&preserve_saves=1" % [link_protocol, host_with_port, shell_path, app_version],
		"multiplayer": "%s://%s%s?multiplayer=1" % [link_protocol, host_with_port, play_path],

		"self_host": str(self_host_mode.get("links", {}).get("public_play_url", "")) if typeof(self_host_mode.get("links", {})) == TYPE_DICTIONARY else "",
		"self_host_local": str(self_host_mode.get("links", {}).get("local_play_url", "")) if typeof(self_host_mode.get("links", {})) == TYPE_DICTIONARY else "",
		"self_host_webrtc": str(self_host_mode.get("links", {}).get("webrtc_invite_url", "")) if typeof(self_host_mode.get("links", {})) == TYPE_DICTIONARY else "",

		"launch_payload": launch_payload.duplicate(true),
		"offline_manifest": offline_manifest.duplicate(true),

		"deploy_manifest": {
			"provider": static_host,
			"publish_directory_requires": [
				"index.html",
				"index.js",
				"index.wasm",
				"index.pck",
				"index.manifest.json",
				"index.service.worker.js",
				"_redirects",
				"_headers"
			],
			"netlify_redirects": netlify_redirects.duplicate(true),
			"netlify_headers": netlify_headers.duplicate(true)
		},

		"metadata": {
			"portable": true,
			"offline_capable": true,
			"save_persistence_key": save_persistence_key,
			"cache_namespace": cache_namespace,
			"app_cache_name": app_cache_name,
			"world_cache_name": world_cache_name,
			"host": host,
			"static_host": static_host,
			"self_host_mode_enabled": bool(self_host_mode.get("enabled", false)),
			"self_host_public_host": host if self_host_requested else "",

			"native_protocol_scheme": scheme,
			"native_protocol_route": native_route,
			"capsule_query_key": capsule_query_key,
			"capsule_id_query_key": capsule_id_query_key,
			"world_query_key": world_query_key,
			"web_fallback_host": host,
		},

		"built_at_ms": int(Time.get_ticks_msec())
	}

	launch_link_registry [clean_world_id] = links.duplicate(true)
	launch_link_registry [safe_world_id] = links.duplicate(true)
	if life_id != "":
		launch_link_registry [life_id] = links.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["tap_to_play_links"] = links.duplicate(true)
		gs.scenario_state ["launch_link_registry"] = launch_link_registry.duplicate(true)
		gs.scenario_state ["offline_world_manifest"] = offline_manifest.duplicate(true)
		gs.scenario_state ["static_host_deploy_manifest"] = links.get("deploy_manifest", {}).duplicate(true)
		gs.scenario_state ["self_host_mode"] = self_host_mode.duplicate(true)

	return links

func build_portable_world_package(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var safe_world_id: String = _safe_link_id(clean_world_id)
	var links: Dictionary = build_tap_to_play_links(clean_world_id, options)

	if world_streaming_manifest.is_empty():
		world_streaming_manifest = _build_default_world_streaming_manifest(clean_world_id)

	var package:= {
		"schema": "eralife.portable_world_package",
		"version": CONTRACT_VERSION,
		"package_version": 2,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"state_id": active_state_id,
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_registry": export_registry(),
		"save_slices": export_save_slices(),
		"world_streaming_manifest": world_streaming_manifest.duplicate(true),
		"launch_links": links.duplicate(true),
		"runtime_capability_profiles": runtime_capability_registry.duplicate(true),
		"offline_manifest": links.get("offline_manifest", {}).duplicate(true) if typeof(links.get("offline_manifest", {})) == TYPE_DICTIONARY else {},
		"portable_save_capsule": build_portable_save_capsule(clean_world_id, options),
		"multiplayer_runtime_seed": build_multiplayer_world_runtime(clean_world_id, {
			"create_in_registry": false,
			"host_peer_id": str(options.get("host_peer_id", "local_host")),
			"authority_mode": str(options.get("multiplayer_authority_mode", "host_authoritative"))
		}),
		"metadata": {
			"portable": true,
			"offline_capable": true,
			"save_persistent": true,
			"backwards_compatible": true,
			"official_update_policy": "stable_link_preserve_user_save",
			"host": str(options.get("host", "eralife.app"))
		}
	}

	return _make_binary_safe(package)


func import_portable_world_package(package: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.portable_world_import_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"world_id": "",
		"state_id": active_state_id,
		"registry_imported": false,
		"save_slices_imported": false,
		"capsule_imported": false,
		"capability_profile": {},
		"adaptive_resolution": {},
		"streaming_boot": {},
		"hydration": {},
		"warnings": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(package) != TYPE_DICTIONARY:
		report ["warnings"].append("Portable world package must be a Dictionary.")
		return report

	var schema: String = str(package.get("schema", "")).strip_edges()
	if schema != "eralife.portable_world_package":
		report ["warnings"].append("Unexpected portable package schema '%s'." % schema)

	var clean_world_id: String = str(package.get("world_id", package.get("state_id", active_state_id))).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	report ["world_id"] = clean_world_id

	var registry_raw: Variant = package.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		import_registry(registry_raw as Dictionary)
		report ["registry_imported"] = true

	var streaming_raw: Variant = package.get("world_streaming_manifest", {})
	if typeof(streaming_raw) == TYPE_DICTIONARY:
		world_streaming_manifest = _normalize_world_streaming_manifest(streaming_raw, clean_world_id)

	var links_raw: Variant = package.get("launch_links", {})
	if typeof(links_raw) == TYPE_DICTIONARY:
		var links: Dictionary = links_raw
		launch_link_registry [clean_world_id] = links.duplicate(true)

		var safe_world_id: String = str(links.get("safe_world_id", _safe_link_id(clean_world_id))).strip_edges()
		if safe_world_id != "":
			launch_link_registry [safe_world_id] = links.duplicate(true)

	var capsule_raw: Variant = package.get("portable_save_capsule", {})
	if typeof(capsule_raw) == TYPE_DICTIONARY and not (capsule_raw as Dictionary).is_empty():
		var capsule_report: Dictionary = import_portable_save_capsule(capsule_raw as Dictionary, {
			"defer_hydration": true,
			"runtime_capability_profile": options.get("runtime_capability_profile", {})
		})
		report ["capsule_imported"] = bool(capsule_report.get("success", false))
		if not bool(capsule_report.get("success", false)):
			report ["warnings"].append("Portable save capsule import returned warnings.")

	var capability_raw: Variant = options.get("runtime_capability_profile", {})
	if typeof(capability_raw) != TYPE_DICTIONARY or (capability_raw as Dictionary).is_empty():
		var package_profiles_raw: Variant = package.get("runtime_capability_profiles", {})
		if typeof(package_profiles_raw) == TYPE_DICTIONARY:
			_ingest_runtime_capability_profiles(package_profiles_raw, clean_world_id)
		capability_raw = _detect_runtime_capability_profile()

	report ["capability_profile"] = resolve_runtime_capability_profile(capability_raw)

	report ["adaptive_resolution"] = resolve_adaptive_contracts({
		"phase": "import_portable_world_package",
		"source": "portable_world_package",
		"world_id": clean_world_id
	})

	report ["streaming_boot"] = prepare_world_streaming_boot({
		"phase": "import_portable_world_package",
		"source": "portable_world_package",
		"launch": package.get("launch_links", {})
	})

	var save_slices_raw: Variant = package.get("save_slices", {})
	if typeof(save_slices_raw) == TYPE_DICTIONARY:
		import_save_slices(save_slices_raw as Dictionary)
		report ["save_slices_imported"] = true

	if not bool(options.get("defer_hydration", false)):
		report ["hydration"] = hydrate_runtime_state({
			"phase": "import_portable_world_package",
			"source": "portable_world_package"
		})

	report ["state_id"] = active_state_id
	report ["success"] = true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["portable_world_import_report"] = report.duplicate(true)

	return report
func _resolve_contract_script_resource(
	script_path: String,
	fallback_script_path: String = "",
	global_class_name: String = ""
) -> Dictionary:
	var clean_script_path: String = str(
		script_path
	).strip_edges()

	var clean_fallback_script_path: String = str(
		fallback_script_path
	).strip_edges()

	var clean_global_class_name: String = str(
		global_class_name
	).strip_edges()

	var attempted_paths: Array = []
	var resource_path_found: bool = false

	var direct_candidates: Array = [
		{
			"path": clean_script_path,
			"mode": "declared_script_path"
		},
		{
			"path": clean_fallback_script_path,
			"mode": "fallback_script_path"
		}
	]

	for raw_candidate in direct_candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = (
			raw_candidate as Dictionary
		)

		var candidate_path: String = str(
			candidate.get(
				"path",
				""
			)
		).strip_edges()

		if (
			candidate_path == ""
			or candidate_path in attempted_paths
		):
			continue

		attempted_paths.append(
			candidate_path
		)

		if not ResourceLoader.exists(
			candidate_path
		):
			continue

		resource_path_found = true

		var candidate_resource: Resource = (
			ResourceLoader.load(
				candidate_path
			)
		)

		if candidate_resource is Script:
			return {
				"success": true,
				"script": candidate_resource as Script,
				"resolved_script_path": candidate_path,
				"resolution_mode": str(
					candidate.get(
						"mode",
						"contract_script_path"
					)
				),
				"global_class_name": (
					clean_global_class_name
				),
				"resource_path_found": true,
				"attempted_paths": (
					attempted_paths.duplicate()
				)
			}

	if clean_global_class_name != "":
		for raw_global_class in (
			ProjectSettings.get_global_class_list()
		):
			if typeof(raw_global_class) != TYPE_DICTIONARY:
				continue

			var global_class: Dictionary = (
				raw_global_class as Dictionary
			)

			var registered_class_name: String = str(
				global_class.get(
					"class",
					""
				)
			).strip_edges()

			if (
				registered_class_name
				!= clean_global_class_name
			):
				continue

			var registered_path: String = str(
				global_class.get(
					"path",
					""
				)
			).strip_edges()

			if registered_path == "":
				continue

			if registered_path not in attempted_paths:
				attempted_paths.append(
					registered_path
				)

			if not ResourceLoader.exists(
				registered_path
			):
				continue

			resource_path_found = true

			var registered_resource: Resource = (
				ResourceLoader.load(
					registered_path
				)
			)

			if registered_resource is Script:
				return {
					"success": true,
					"script": registered_resource as Script,
					"resolved_script_path": registered_path,
					"resolution_mode": (
						"global_class_registry"
					),
					"global_class_name": (
						clean_global_class_name
					),
					"resource_path_found": true,
					"attempted_paths": (
						attempted_paths.duplicate()
					)
				}

	return {
		"success": false,
		"script": null,
		"resolved_script_path": "",
		"resolution_mode": "unresolved",
		"global_class_name": clean_global_class_name,
		"resource_path_found": resource_path_found,
		"attempted_paths": attempted_paths.duplicate()
	}
func register_builtin_contract_pack_from_path(
	script_path: String,
	source: String = "builtin_contract_pack"
) -> Dictionary:
	var clean_path: String = str(
		script_path
	).strip_edges()

	if clean_path == "":
		return {
			"success": true,
			"skipped": true,
			"reason": "empty_contract_pack_path",
			"engine_ids": []
		}

	var expected_global_class_name: String = (
		clean_path
		.get_file()
		.get_basename()
	)

	var pack_resolution: Dictionary = (
		_resolve_contract_script_resource(
			clean_path,
			"",
			expected_global_class_name
		)
	)

	if not bool(
		pack_resolution.get(
			"success",
			false
		)
	):
		if not bool(
			pack_resolution.get(
				"resource_path_found",
				false
			)
		):
			return {
				"success": true,
				"skipped": true,
				"reason": (
					"optional_contract_pack_not_installed"
				),
				"script_path": clean_path,
				"resolved_script_path": "",
				"resolution_mode": "unresolved",
				"attempted_paths": (
					pack_resolution.get(
						"attempted_paths",
						[]
					)
				),
				"engine_ids": []
			}

		return {
			"success": false,
			"reason": "contract_pack_script_load_failed",
			"script_path": clean_path,
			"resolved_script_path": "",
			"resolution_mode": "unresolved",
			"attempted_paths": (
				pack_resolution.get(
					"attempted_paths",
					[]
				)
			),
			"engine_ids": []
		}

	var pack_script: Script = (
		pack_resolution.get(
			"script",
			null
		) as Script
	)

	if pack_script == null:
		return {
			"success": false,
			"reason": "contract_pack_script_load_failed",
			"script_path": clean_path,
			"resolved_script_path": str(
				pack_resolution.get(
					"resolved_script_path",
					""
				)
			),
			"resolution_mode": str(
				pack_resolution.get(
					"resolution_mode",
					"unresolved"
				)
			),
			"engine_ids": []
		}

	var contract_callable:= Callable(
		pack_script,
		"contract"
	)

	if not contract_callable.is_valid():
		return {
			"success": false,
			"reason": "contract_pack_factory_missing",
			"script_path": clean_path,
			"resolved_script_path": str(
				pack_resolution.get(
					"resolved_script_path",
					clean_path
				)
			),
			"resolution_mode": str(
				pack_resolution.get(
					"resolution_mode",
					"declared_script_path"
				)
			),
			"engine_ids": []
		}

	var raw_contract: Variant = (
		contract_callable.call()
	)

	if typeof(raw_contract) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": (
				"contract_pack_factory_returned_invalid_type"
			),
			"script_path": clean_path,
			"resolved_script_path": str(
				pack_resolution.get(
					"resolved_script_path",
					clean_path
				)
			),
			"resolution_mode": str(
				pack_resolution.get(
					"resolution_mode",
					"declared_script_path"
				)
			),
			"engine_ids": []
		}

	var normalized: Dictionary = normalize_contract(
		raw_contract as Dictionary,
		"%s://%s" % [
			source,
			clean_path
		]
	)
	var engine_ids: Array = []
	var already_ingested: bool = true

	for raw_engine in normalized.get(
		"engines",
		[]
	):
		if typeof(raw_engine) != TYPE_DICTIONARY:
			continue

		var engine: Dictionary = (
			raw_engine as Dictionary
		)
		var engine_id: String = str(
			engine.get(
				"id",
				""
			)
		).strip_edges()

		if engine_id == "":
			continue

		engine_ids.append(
			engine_id
		)

		if not engine_registry.has(engine_id):
			already_ingested = false

	if not already_ingested:
		_ingest_contract(
			normalized
		)

	return {
		"success": true,
		"skipped": already_ingested,
		"mode": (
			"builtin_contract_pack_already_ingested"
			if already_ingested
			else "builtin_contract_pack_ingested"
		),
		"script_path": clean_path,
		"resolved_script_path": str(
			pack_resolution.get(
				"resolved_script_path",
				clean_path
			)
		),
		"resolution_mode": str(
			pack_resolution.get(
				"resolution_mode",
				"declared_script_path"
			)
		),
		"path_fallback_used": (
			str(
				pack_resolution.get(
					"resolved_script_path",
					clean_path
				)
			)
			!= clean_path
		),
		"source": source,
		"engine_ids": engine_ids,
		"engine_count": engine_ids.size()
	}

func instantiate_contract_engine_extensions_for_ids(
	engine_ids: Array
) -> Dictionary:
	var report:= {
		"schema": (
			"eralife.targeted_contract_engine_instantiation_report"
		),
		"version": CONTRACT_VERSION,
		"instantiated": [],
		"skipped": [],
		"failed": []
	}

	if gs == null:
		report ["failed"].append({
			"reason": "No GameState bound."
		})
		return report

	var ordered: Array = []
	var seen: Dictionary = {}

	for raw_engine_id in engine_ids:
		var engine_id: String = str(
			raw_engine_id
		).strip_edges()

		if (
			engine_id == ""
			or seen.has(engine_id)
			or not engine_registry.has(engine_id)
		):
			continue

		seen [engine_id] = true
		ordered.append(
			engine_registry.get(
				engine_id,
				{}
			)
		)

	ordered.sort_custom(
		Callable(
			self,
			"_contract_engine_boot_order_less"
		)
	)

	for raw_engine in ordered:
		if typeof(raw_engine) != TYPE_DICTIONARY:
			continue

		var engine: Dictionary = (
			raw_engine as Dictionary
		)
		var engine_id: String = str(
			engine.get(
				"id",
				""
			)
		).strip_edges()

		if engine_id == "":
			continue

		_register_engine_identity_record(
			engine,
			str(
				engine.get(
					"state_id",
					active_state_id
				)
			)
		)

		var existing = get_engine_instance(
			engine_id
		)

		if existing != null:
			_bind_engine_instance(
				engine,
				existing
			)
			report ["skipped"].append({
				"engine_id": engine_id,
				"reason": "Engine already exists.",
				"contract_uid": str(
					engine.get(
						"contract_uid",
						""
					)
				)
			})
			continue

		if not bool(
			engine.get(
				"allow_contract_instantiation",
				false
			)
		):
			report ["skipped"].append({
				"engine_id": engine_id,
				"reason": (
					"Contract instantiation disabled."
				),
				"contract_uid": str(
					engine.get(
						"contract_uid",
						""
					)
				)
			})
			continue

		var instance = (
			_instantiate_engine_from_contract(
				engine
			)
		)

		if instance == null:
			report ["failed"].append({
				"engine_id": engine_id,
				"class": str(
					engine.get(
						"class",
						""
					)
				),
				"script_path": str(
					engine.get(
						"script_path",
						""
					)
				),
				"contract_uid": str(
					engine.get(
						"contract_uid",
						""
					)
				),
				"reason": (
					"Could not instantiate contract engine."
				)
			})
			continue

		_bind_engine_instance(
			engine,
			instance
		)
		instantiated_contract_engines [
			engine_id
		] = true

		report ["instantiated"].append({
			"engine_id": engine_id,
			"class": str(
				engine.get(
					"class",
					""
				)
			),
			"script_path": str(
				engine.get(
					"script_path",
					""
				)
			),
			"runtime_property": str(
				engine.get(
					"runtime_property",
					engine_id
				)
			),
			"contract_uid": str(
				engine.get(
					"contract_uid",
					""
				)
			)
		})

	contract_runtime_manifest = (
		_build_contract_runtime_manifest()
	)

	return report


func _contract_engine_boot_order_less(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return int(
		a.get(
			"boot_order",
			1000
		)
	) < int(
		b.get(
			"boot_order",
			1000
		)
	)
func build_portable_save_capsule(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var safe_world_id: String = _safe_link_id(clean_world_id)

	var identity_options: Dictionary = options.duplicate(true)
	identity_options ["world_id"] = clean_world_id
	var life_identity: Dictionary = ensure_life_identity(identity_options)

	var capsule_id: String = _build_capsule_version_id(life_identity, options)
	if capsule_id == "":
		capsule_id = "%s.%d" % [safe_world_id, int(Time.get_ticks_msec())]

	var continuation_kind: String = _detect_continuation_kind(life_identity, {}, options)

	var links_options: Dictionary = options.duplicate(true)
	links_options ["life_identity"] = life_identity.duplicate(true)
	links_options ["include_life_identity"] = true
	var links: Dictionary = build_tap_to_play_links(clean_world_id, links_options)

	var save_slices: Dictionary = export_save_slices()
	var core_life_snapshot: Dictionary = _build_core_life_snapshot(options)
	var life_summary: Dictionary = _build_life_capsule_summary(core_life_snapshot)

	var player_contract_slice: Dictionary = {}
	if gs != null and gs.player != null and gs.player.has_method("export_contract_slice"):
		player_contract_slice = gs.player.call("export_contract_slice", {
			"source": "build_portable_save_capsule",
			"world_id": clean_world_id,
			"capsule_id": capsule_id,
			"life_id": str(life_identity.get("life_id", "")),
			"lineage_id": str(life_identity.get("lineage_id", "")),
			"timeline_id": str(life_identity.get("timeline_id", "")),
			"portable": true
		})

	var preview: Dictionary = _build_portable_capsule_preview(
		core_life_snapshot,
		life_summary,
		player_contract_slice,
		clean_world_id,
		options
	)

	var fallback_contract: Dictionary = _build_portable_capsule_fallback_contract(
		clean_world_id,
		life_identity,
		preview,
		options
	)

	var capsule:= {
		"schema": "eralife.portable_save_capsule",
		"version": CONTRACT_VERSION,
		"capsule_version": 4,
		"capsule_id": capsule_id,
		"life_id": str(life_identity.get("life_id", "")),
		"lineage_id": str(life_identity.get("lineage_id", "")),
		"timeline_id": str(life_identity.get("timeline_id", "")),
		"continuation_kind": continuation_kind,
		"identity": life_identity.duplicate(true),

		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"state_id": active_state_id,
		"created_at_ms": int(Time.get_ticks_msec()),

		"contract_registry": export_registry(),
		"save_slices": save_slices.duplicate(true),
		"core_life_snapshot": core_life_snapshot.duplicate(true),
		"player_contract_slice": player_contract_slice.duplicate(true),
		"life_summary": life_summary.duplicate(true),

		"preview": preview.duplicate(true),
		"fallback_contract": fallback_contract.duplicate(true),

		"tap_to_play": {
			"mode": "hybrid",
			"native_capsule_template": str(links.get("native_capsule_template", "")),
			"native_capsule_id_template": str(links.get("native_capsule_id_template", "")),
			"web_capsule_template": str(links.get("capsule_template", "")),
			"web_capsule_id_template": str(links.get("capsule_id_template", "")),
			"fallback_host": str(options.get("host", "eralife.app")),
			"app_protocol": {
				"scheme": str(links.get("metadata", {}).get("native_protocol_scheme", str(options.get("scheme", "eralife")))) if typeof(links.get("metadata", {})) == TYPE_DICTIONARY else str(options.get("scheme", "eralife")),
				"route": str(links.get("metadata", {}).get("native_protocol_route", "play")) if typeof(links.get("metadata", {})) == TYPE_DICTIONARY else "play",
				"capsule_query_key": str(links.get("metadata", {}).get("capsule_query_key", "capsule")) if typeof(links.get("metadata", {})) == TYPE_DICTIONARY else "capsule",
				"capsule_id_query_key": str(links.get("metadata", {}).get("capsule_id_query_key", "capsule_id")) if typeof(links.get("metadata", {})) == TYPE_DICTIONARY else "capsule_id"
			}
		},

		"orphaned_save_slices": orphaned_save_slices.duplicate(true),
		"world_streaming_manifest": world_streaming_manifest.duplicate(true),
		"launch_links": links.duplicate(true),
		"offline_manifest": links.get("offline_manifest", {}).duplicate(true) if typeof(links.get("offline_manifest", {})) == TYPE_DICTIONARY else {},

		"cross_device_continuity": build_cross_device_continuity_checkpoint(clean_world_id, {
			"life_identity": life_identity.duplicate(true),
			"skip_portable_capsule": true,
			"scene_route": str(options.get("scene_route", "")),
			"ui_surface": str(options.get("ui_surface", "")),
			"source": "build_portable_save_capsule"
		}) if not bool(options.get("skip_continuity_checkpoint", false)) else {},

		"capsule_snapshot": {
			"life_id": str(life_identity.get("life_id", "")),
			"timeline_id": str(life_identity.get("timeline_id", "")),
			"capsule_id": capsule_id,
			"age": int(gs.player.age) if gs != null and gs.player != null else 0,
			"year": int(gs.year) if gs != null else 0,
			"snapshot_kind": "exact_runtime_state",
			"continuation_kind": continuation_kind
		},

		"persistence": {
			"save_persistence_key": str(links.get("offline_manifest", {}).get("save_persistence_key", "eralife.save.%s" % str(life_identity.get("life_id", safe_world_id)))) if typeof(links.get("offline_manifest", {})) == TYPE_DICTIONARY else "eralife.save.%s" % str(life_identity.get("life_id", safe_world_id)),
			"storage_strategy": "url_capsule_inline_first_userfs_indexeddb_optional",
		},

		"compatibility": {
			"min_runtime_contract_version": 1,
			"target_runtime_contract_version": CONTRACT_VERSION,
			"unknown_slice_policy": "orphan_not_delete",
			"migration_report": last_migration_report.duplicate(true),
		},

		"update_policy": {
			"preserve_unknown_slices": true,
		},

		"url_capsule": {
			"supported": true,
			"schema": URL_CAPSULE_SCHEMA,
			"version": URL_CAPSULE_VERSION,
			"inline_max_chars": int(options.get("max_inline_chars", URL_CAPSULE_INLINE_MAX_CHARS)),
			"large_capsule_policy": "compressed_inline_first_local_only_when_explicit"
		},

		"metadata": {
			"portable": true,
			"backwards_compatible": true,
			"contains_core_life_snapshot": not core_life_snapshot.is_empty(),
			"contains_preview": not preview.is_empty(),
		}
	}

	portable_save_capsule_registry [capsule_id] = capsule.duplicate(true)

	var version_report: Dictionary = record_life_capsule_version(life_identity, capsule, {
		"capsule_id": capsule_id,
		"continuation_kind": continuation_kind
	})

	last_portable_save_capsule_report = {
		"schema": "eralife.portable_save_capsule_build_report",
		"version": CONTRACT_VERSION,
		"capsule_id": capsule_id,
		"life_id": str(life_identity.get("life_id", "")),
		"timeline_id": str(life_identity.get("timeline_id", "")),
		"world_id": clean_world_id,
		"slice_count": int(save_slices.get("slices", {}).size()) if typeof(save_slices.get("slices", {})) == TYPE_DICTIONARY else 0,
		"has_core_life_snapshot": not core_life_snapshot.is_empty(),
		"has_preview": not preview.is_empty(),
		"life_version": version_report.duplicate(true),
		"built_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["portable_save_capsule_registry"] = portable_save_capsule_registry.duplicate(true)
		gs.scenario_state ["last_portable_save_capsule_report"] = last_portable_save_capsule_report.duplicate(true)

	return _make_binary_safe(capsule)


func import_portable_save_capsule(capsule: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.portable_save_capsule_import_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"capsule_id": "",
		"life_id": "",
		"timeline_id": "",
		"world_id": "",
		"continuation_kind": "",
		"life_identity_imported": false,
		"registry_imported": false,
		"save_slices_imported": false,
		"core_life_restored": false,
		"streaming_manifest_imported": false,
		"launch_links_imported": false,
		"capability_profile": {},
		"adaptive_resolution": {},
		"streaming_boot": {},
		"core_restore": {},
		"hydration": {},
		"warnings": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(capsule) != TYPE_DICTIONARY:
		report ["warnings"].append("Portable save capsule must be a Dictionary.")
		return report

	var schema: String = str(capsule.get("schema", "")).strip_edges()
	if schema == "eralife.portable_world_package":
		return import_portable_world_package(capsule, options)

	if schema == "eralife.hybrid_tap_to_play_contract":
		var encoded_capsule: String = str(capsule.get("encoded_capsule", "")).strip_edges()
		if encoded_capsule != "":
			var hybrid_url_report: Dictionary = import_url_capsule(encoded_capsule, options)
			var nested_import_raw: Variant = hybrid_url_report.get("import", {})
			return nested_import_raw if typeof(nested_import_raw) == TYPE_DICTIONARY else hybrid_url_report

		var fallback_raw: Variant = capsule.get("fallback_contract", {})
		if typeof(fallback_raw) == TYPE_DICTIONARY:
			var fallback_contract: Dictionary = fallback_raw
			var embedded_capsule_raw: Variant = fallback_contract.get("capsule", capsule.get("capsule", {}))
			if typeof(embedded_capsule_raw) == TYPE_DICTIONARY and not (embedded_capsule_raw as Dictionary).is_empty():
				var forwarded_options: Dictionary = options.duplicate(true)
				forwarded_options ["source"] = "hybrid_tap_to_play_contract"
				var nested_report: Dictionary = import_portable_save_capsule(embedded_capsule_raw as Dictionary, forwarded_options)
				nested_report ["hybrid_contract"] = capsule.duplicate(true)
				return nested_report

		report ["warnings"].append("Hybrid tap-to-play contract did not contain an importable capsule.")
		return report

	if schema != "eralife.portable_save_capsule":
		report ["warnings"].append("Unexpected portable save capsule schema '%s'." % schema)

	var capsule_id: String = str(capsule.get("capsule_id", "")).strip_edges()
	if capsule_id == "":
		capsule_id = "capsule.%d" % int(Time.get_ticks_msec())

	var clean_world_id: String = str(capsule.get("world_id", capsule.get("state_id", active_state_id))).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var loaded_state_id: String = str(capsule.get("state_id", clean_world_id)).strip_edges()
	if loaded_state_id != "":
		active_state_id = loaded_state_id

	report ["capsule_id"] = capsule_id
	report ["world_id"] = clean_world_id

	var identity_raw: Variant = capsule.get("identity", capsule.get("life_identity", {}))
	var life_identity: Dictionary = {}
	if typeof(identity_raw) == TYPE_DICTIONARY and not (identity_raw as Dictionary).is_empty():
		life_identity = _normalize_life_identity(identity_raw as Dictionary, {
			"world_id": clean_world_id,
			"capsule_id": capsule_id
		})
	else:
		life_identity = ensure_life_identity({
			"world_id": clean_world_id,
			"life_id": str(capsule.get("life_id", "")),
			"timeline_id": str(capsule.get("timeline_id", "")),
			"source": "capsule_import",
			"created_by_capsule": capsule_id
		})

	var continuation_kind: String = _detect_continuation_kind(life_identity, capsule, options)
	life_identity_registry [str(life_identity.get("life_id", ""))] = life_identity.duplicate(true)

	report ["life_id"] = str(life_identity.get("life_id", ""))
	report ["timeline_id"] = str(life_identity.get("timeline_id", ""))
	report ["continuation_kind"] = continuation_kind
	report ["life_identity_imported"] = str(life_identity.get("life_id", "")) != ""

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["life_identity"] = life_identity.duplicate(true)
		gs.scenario_state ["life_id"] = str(life_identity.get("life_id", ""))
		gs.scenario_state ["timeline_id"] = str(life_identity.get("timeline_id", ""))
		gs.scenario_state ["life_identity_registry"] = life_identity_registry.duplicate(true)

	var core_snapshot_raw: Variant = capsule.get("core_life_snapshot", {})
	if typeof(core_snapshot_raw) == TYPE_DICTIONARY and not (core_snapshot_raw as Dictionary).is_empty() and not bool(options.get("skip_core_life_restore", false)):
		var core_report: Dictionary = _restore_core_life_snapshot(core_snapshot_raw as Dictionary, {
			"phase": "import_portable_save_capsule",
			"source": "portable_save_capsule",
			"capsule_id": capsule_id,
			"world_id": clean_world_id,
			"life_id": str(life_identity.get("life_id", ""))
		})
		report ["core_restore"] = core_report.duplicate(true)
		report ["core_life_restored"] = bool(core_report.get("success", false))
		if not bool(core_report.get("success", false)):
			report ["warnings"].append("Core life snapshot restore failed; falling back to contract save slices.")

	var player_contract_slice_raw: Variant = capsule.get("player_contract_slice", {})
	if gs != null and gs.player != null and typeof(player_contract_slice_raw) == TYPE_DICTIONARY and gs.player.has_method("import_contract_slice"):
		var person_import_report: Dictionary = gs.player.call("import_contract_slice", player_contract_slice_raw as Dictionary, {
			"source": "import_portable_save_capsule",
			"capsule_id": capsule_id,
			"world_id": clean_world_id,
			"life_id": str(life_identity.get("life_id", "")),
			"lineage_id": str(life_identity.get("lineage_id", "")),
			"timeline_id": str(life_identity.get("timeline_id", "")),
		})
		report ["player_contract_import"] = person_import_report.duplicate(true)

	var registry_raw: Variant = capsule.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		import_registry(registry_raw as Dictionary)
		report ["registry_imported"] = true

	var streaming_raw: Variant = capsule.get("world_streaming_manifest", {})
	if typeof(streaming_raw) == TYPE_DICTIONARY:
		world_streaming_manifest = _normalize_world_streaming_manifest(streaming_raw, clean_world_id)
		report ["streaming_manifest_imported"] = true

	var links_raw: Variant = capsule.get("launch_links", {})
	if typeof(links_raw) == TYPE_DICTIONARY:
		var links: Dictionary = links_raw
		launch_link_registry [clean_world_id] = links.duplicate(true)

		var safe_world_id: String = str(links.get("safe_world_id", _safe_link_id(clean_world_id))).strip_edges()
		if safe_world_id != "":
			launch_link_registry [safe_world_id] = links.duplicate(true)

		var imported_life_id: String = str(life_identity.get("life_id", "")).strip_edges()
		if imported_life_id != "":
			launch_link_registry [imported_life_id] = links.duplicate(true)

		report ["launch_links_imported"] = true

	var save_slices_raw: Variant = capsule.get("save_slices", {})
	if typeof(save_slices_raw) == TYPE_DICTIONARY:
		import_save_slices(save_slices_raw as Dictionary)
		report ["save_slices_imported"] = true

	portable_save_capsule_registry [capsule_id] = capsule.duplicate(true)

	record_life_capsule_version(life_identity, capsule, {
		"capsule_id": capsule_id,
		"continuation_kind": continuation_kind
	})

	var continuity_raw: Variant = capsule.get("cross_device_continuity", {})
	if typeof(continuity_raw) == TYPE_DICTIONARY and not (continuity_raw as Dictionary).is_empty():
		var continuity_report: Dictionary = import_cross_device_continuity_checkpoint(continuity_raw as Dictionary, {
			"source": "portable_save_capsule",
			"defer_hydration": true,
		})
		report ["cross_device_continuity"] = continuity_report.duplicate(true)

	var capability_raw: Variant = options.get("runtime_capability_profile", {})
	if typeof(capability_raw) != TYPE_DICTIONARY or (capability_raw as Dictionary).is_empty():
		capability_raw = _detect_runtime_capability_profile()
	report ["capability_profile"] = resolve_runtime_capability_profile(capability_raw)

	report ["adaptive_resolution"] = resolve_adaptive_contracts({
		"phase": "import_portable_save_capsule",
		"source": "portable_save_capsule",
		"world_id": clean_world_id,
		"capsule_id": capsule_id,
		"life_id": str(life_identity.get("life_id", ""))
	})

	report ["streaming_boot"] = prepare_world_streaming_boot({
		"phase": "import_portable_save_capsule",
		"source": "portable_save_capsule",
		"launch": capsule.get("launch_links", {})
	})

	if not bool(options.get("defer_hydration", false)):
		report ["hydration"] = hydrate_runtime_state({
			"phase": "import_portable_save_capsule",
			"source": "portable_save_capsule",
			"capsule_id": capsule_id,
			"life_id": str(life_identity.get("life_id", ""))
		})

	report ["success"] = bool(report.get("core_life_restored", false)) \
or bool(report.get("save_slices_imported", false)) \
or bool(report.get("registry_imported", false)) \
or bool(report.get("life_identity_imported", false)) \
or bool(report.get("cross_device_continuity", {}).get("success", false) if typeof(report.get("cross_device_continuity", {})) == TYPE_DICTIONARY else false)

	last_portable_save_capsule_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["portable_save_capsule_registry"] = portable_save_capsule_registry.duplicate(true)
		gs.scenario_state ["last_portable_save_capsule_report"] = last_portable_save_capsule_report.duplicate(true)

		if typeof(capsule.get("preview", {})) == TYPE_DICTIONARY:
			gs.scenario_state ["latest_tap_to_play_preview"] = (capsule.get("preview", {}) as Dictionary).duplicate(true)
		if typeof(capsule.get("tap_to_play", {})) == TYPE_DICTIONARY:
			gs.scenario_state ["latest_tap_to_play_contract"] = (capsule.get("tap_to_play", {}) as Dictionary).duplicate(true)

	return report


func build_multiplayer_world_runtime(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var safe_world_id: String = _safe_link_id(clean_world_id)
	var runtime_id: String = str(options.get("runtime_id", "%s.runtime.%d" % [safe_world_id, int(Time.get_ticks_msec())])).strip_edges()
	var host_peer_id: String = str(options.get("host_peer_id", "local_host")).strip_edges()
	if host_peer_id == "":
		host_peer_id = "local_host"

	var authority_mode: String = str(options.get("authority_mode", "host_authoritative")).strip_edges().to_lower()
	if authority_mode == "":
		authority_mode = "host_authoritative"

	var links: Dictionary = build_tap_to_play_links(clean_world_id, options)
	var streaming_boot: Dictionary = prepare_world_streaming_boot({
		"phase": "build_multiplayer_world_runtime",
		"source": "multiplayer_world_runtime",
		"launch": links.duplicate(true)
	})

	var runtime:= {
		"schema": "eralife.multiplayer_world_runtime",
		"version": CONTRACT_VERSION,
		"runtime_id": runtime_id,
		"world_id": clean_world_id,
		"safe_world_id": safe_world_id,
		"state_id": active_state_id,
		"authority_mode": authority_mode,
		"host_peer_id": host_peer_id,
		"created_at_ms": int(Time.get_ticks_msec()),
		"peers": {
			host_peer_id: {
				"peer_id": host_peer_id,
				"role": "host",
				"joined_at_ms": int(Time.get_ticks_msec()),
				"last_seen_ms": int(Time.get_ticks_msec()),
				"capability_profile": runtime_capability_profile.duplicate(true)
			}
		},
		"streaming_boot": streaming_boot.duplicate(true),
		"launch_links": links.duplicate(true),
		"shared_journal": [],
		"deterministic_tick": 0,
		"delta_policy": {
			"strategy": "append_only_world_journal",
			"conflict_resolution": authority_mode,
			"save_slice_merge_policy": "host_authoritative_preserve_orphans",
		},
		"metadata": {
		}
	}

	if bool(options.get("create_in_registry", true)):
		multiplayer_world_runtime_registry [runtime_id] = runtime.duplicate(true)

	last_multiplayer_runtime_report = {
		"schema": "eralife.multiplayer_world_runtime_report",
		"version": CONTRACT_VERSION,
		"runtime_id": runtime_id,
		"world_id": clean_world_id,
		"peer_count": int(runtime.get("peers", {}).size()) if typeof(runtime.get("peers", {})) == TYPE_DICTIONARY else 0,
		"authority_mode": authority_mode,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["multiplayer_world_runtime_registry"] = multiplayer_world_runtime_registry.duplicate(true)
		gs.scenario_state ["last_multiplayer_runtime_report"] = last_multiplayer_runtime_report.duplicate(true)

	return _make_binary_safe(runtime)


func join_multiplayer_world_runtime(runtime_id: String, peer_id: String = "", profile: Dictionary = {}) -> Dictionary:
	var clean_runtime_id: String = str(runtime_id).strip_edges()
	var clean_peer_id: String = str(peer_id).strip_edges()
	if clean_peer_id == "":
		clean_peer_id = "peer_%d" % int(Time.get_ticks_msec())

	var report:= {
		"schema": "eralife.multiplayer_world_join_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"runtime_id": clean_runtime_id,
		"peer_id": clean_peer_id,
		"runtime": {},
		"warnings": [],
		"joined_at_ms": int(Time.get_ticks_msec())
	}

	if clean_runtime_id == "" or not multiplayer_world_runtime_registry.has(clean_runtime_id):
		report ["warnings"].append("Missing multiplayer world runtime '%s'." % clean_runtime_id)
		return report

	var runtime: Dictionary = multiplayer_world_runtime_registry.get(clean_runtime_id, {}).duplicate(true)
	var peers: Dictionary = runtime.get("peers", {}) if typeof(runtime.get("peers", {})) == TYPE_DICTIONARY else {}

	peers [clean_peer_id] = {
		"peer_id": clean_peer_id,
		"role": str(profile.get("role", "player")),
		"joined_at_ms": int(Time.get_ticks_msec()),
		"last_seen_ms": int(Time.get_ticks_msec()),
		"capability_profile": profile.duplicate(true)
	}

	runtime ["peers"] = peers
	runtime ["deterministic_tick"] = int(runtime.get("deterministic_tick", 0)) + 1
	multiplayer_world_runtime_registry [clean_runtime_id] = runtime.duplicate(true)

	report ["success"] = true
	report ["runtime"] = runtime.duplicate(true)
	last_multiplayer_runtime_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["multiplayer_world_runtime_registry"] = multiplayer_world_runtime_registry.duplicate(true)
		gs.scenario_state ["last_multiplayer_runtime_report"] = last_multiplayer_runtime_report.duplicate(true)

	return report


func record_multiplayer_world_delta(runtime_id: String, peer_id: String, delta: Dictionary = {}) -> Dictionary:
	var clean_runtime_id: String = str(runtime_id).strip_edges()
	var clean_peer_id: String = str(peer_id).strip_edges()

	var report:= {
		"schema": "eralife.multiplayer_world_delta_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"runtime_id": clean_runtime_id,
		"peer_id": clean_peer_id,
		"tick": 0,
		"warnings": [],
		"recorded_at_ms": int(Time.get_ticks_msec())
	}

	if clean_runtime_id == "" or not multiplayer_world_runtime_registry.has(clean_runtime_id):
		report ["warnings"].append("Missing multiplayer world runtime '%s'." % clean_runtime_id)
		return report

	var runtime: Dictionary = multiplayer_world_runtime_registry.get(clean_runtime_id, {}).duplicate(true)
	var journal: Array = runtime.get("shared_journal", []) if typeof(runtime.get("shared_journal", [])) == TYPE_ARRAY else []
	var next_tick: int = int(runtime.get("deterministic_tick", 0)) + 1

	var entry:= {
		"tick": next_tick,
		"peer_id": clean_peer_id,
		"delta": delta.duplicate(true),
		"recorded_at_ms": int(Time.get_ticks_msec())
	}

	journal.append(entry)
	runtime ["shared_journal"] = journal
	runtime ["deterministic_tick"] = next_tick
	multiplayer_world_runtime_registry [clean_runtime_id] = runtime.duplicate(true)

	report ["success"] = true
	report ["tick"] = next_tick
	last_multiplayer_runtime_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["multiplayer_world_runtime_registry"] = multiplayer_world_runtime_registry.duplicate(true)
		gs.scenario_state ["last_multiplayer_runtime_report"] = last_multiplayer_runtime_report.duplicate(true)

	return report


func live_hot_swap_contract_bundle(
	contract_bundle: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if bool(context.get("release_nonblocking_lane", false)):
		return _enqueue_live_release_hot_swap(
			contract_bundle,
			context
		)

	var report:= {
		"schema": "eralife.live_contract_hot_swap_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"source": str(context.get("source", "runtime_hot_swap")),
		"state_id_before": active_state_id,
		"state_id_after": active_state_id,
		"rollback_capsule_id": "",
		"load": {},
		"validation": {},
		"adaptive_resolution": {},
		"streaming_boot": {},
		"hydration": {},
		"rolled_back": false,
		"warnings": [],
		"hot_swapped_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(contract_bundle) != TYPE_DICTIONARY or contract_bundle.is_empty():
		report ["warnings"].append(
			"Live hot swap requires a non-empty contract bundle."
		)
		last_live_contract_hot_swap_report = report.duplicate(true)
		return report

	var allow_rollback: bool = bool(
		context.get("allow_rollback", true)
	)
	var rollback_capsule: Dictionary = build_portable_save_capsule(
		active_state_id,
		{
			"capsule_id": "rollback.%s.%d" % [
				_safe_link_id(active_state_id),
				int(Time.get_ticks_msec())
			],
			"host": str(context.get("host", "eralife.app"))
		}
	)
	report ["rollback_capsule_id"] = str(
		rollback_capsule.get("capsule_id", "")
	)

	var source_label: String = str(
		context.get(
			"source_label",
			"live_hot_swap://contract_bundle"
		)
	).strip_edges()
	if source_label == "":
		source_label = "live_hot_swap://contract_bundle"

	report ["load"] = load_contract_from_dictionary(
		contract_bundle,
		source_label
	)
	if not bool(report ["load"].get("success", false)):
		report ["warnings"].append(
			"Hot swap contract failed to load."
		)
		if allow_rollback:
			import_portable_save_capsule(
				rollback_capsule,
				{ "defer_hydration": false}
			)
			report ["rolled_back"] = true
		last_live_contract_hot_swap_report = report.duplicate(true)
		return report

	report ["validation"] = validate_active_contracts({
		"phase": "live_hot_swap_contract_bundle",
		"include_runtime": true
	})

	if not bool(report ["validation"].get("valid", true)):
		report ["warnings"].append(
			"Hot swap validation failed."
		)
		if allow_rollback:
			import_portable_save_capsule(
				rollback_capsule,
				{ "defer_hydration": false}
			)
			report ["rolled_back"] = true
		last_live_contract_hot_swap_report = report.duplicate(true)
		return report

	report ["adaptive_resolution"] = resolve_adaptive_contracts({
		"phase": "live_hot_swap_contract_bundle",
		"source": source_label,
		"capability_profile": runtime_capability_profile.duplicate(true)
	})

	report ["streaming_boot"] = prepare_world_streaming_boot({
		"phase": "live_hot_swap_contract_bundle",
		"source": source_label,
		"launch": context.get("launch", {})
	})

	report ["hydration"] = hydrate_runtime_state({
		"phase": "live_hot_swap_contract_bundle",
		"source": source_label
	})

	report ["state_id_after"] = active_state_id
	report ["success"] = true

	live_contract_hot_swap_ledger.append(
		report.duplicate(true)
	)
	while live_contract_hot_swap_ledger.size() > 80:
		live_contract_hot_swap_ledger.pop_front()

	last_live_contract_hot_swap_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["live_contract_hot_swap_ledger"] = (
			live_contract_hot_swap_ledger.duplicate(true)
		)
		gs.scenario_state ["last_live_contract_hot_swap_report"] = (
			last_live_contract_hot_swap_report.duplicate(true)
		)

	return report
func _enqueue_live_release_hot_swap(
	contract_bundle: Dictionary,
	context: Dictionary
) -> Dictionary:
	var admission: Dictionary = _live_release_hot_swap_admission(
		contract_bundle
	)
	var report:= {
		"schema": "eralife.live_release_hot_swap_enqueue_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"accepted": false,
		"pending": false,
		"deferred": bool(admission.get("deferred", false)),
		"restart_required": bool(
			admission.get("restart_required", false)
		),
		"source": str(
			context.get("source", "release_update_runtime")
		),
		"admission": admission.duplicate(true),
		"queue_depth": live_release_hot_swap_queue.size(),
		"queued_at_ms": int(Time.get_ticks_msec())
	}

	if not bool(admission.get("accepted", false)):
		return report

	if live_release_hot_swap_queue.size() >= RELEASE_LIVE_HOT_SWAP_MAX_QUEUE:
		report ["admission"] = {
			"accepted": false,
			"restart_required": false,
			"reason": "live_release_hot_swap_queue_full"
		}
		return report

	live_release_hot_swap_sequence += 1
	var transaction_id: String = "release_hot_swap.%d.%d" % [
		int(Time.get_ticks_msec()),
		live_release_hot_swap_sequence
	]

	var metadata: Dictionary = {}
	var metadata_raw: Variant = contract_bundle.get("metadata", {})
	if typeof(metadata_raw) == TYPE_DICTIONARY:
		metadata = (
			metadata_raw as Dictionary
		).duplicate(true)

	live_release_hot_swap_queue.append({
		"transaction_id": transaction_id,
		"patch_state_id": str(
			contract_bundle.get("state_id", "")
		).strip_edges(),
		"metadata": metadata,
		"raw_runtime_phase_overlays": _safe_dictionary_array(
			contract_bundle.get("runtime_phases", [])
		),
		"prepared_runtime_phases": [],
		"seen_phase_ids": {},
		"errors": [],
		"warnings": [],
		"stage": "prepare",
		"cursor": 0,
		"context": context.duplicate(true),
		"queued_at_ms": int(Time.get_ticks_msec())
	})

	report ["success"] = true
	report ["accepted"] = true
	report ["pending"] = true
	report ["transaction_id"] = transaction_id
	report ["queue_depth"] = live_release_hot_swap_queue.size()
	return report


func _live_release_hot_swap_admission(
	contract_bundle: Dictionary
) -> Dictionary:
	var reasons: Array = []
	var deferred_reasons: Array = []

	var allowed_top_level_keys: Array = [
		"schema",
		"version",
		"state_id",
		"metadata",
		"runtime_phases"
	]
	var allowed_phase_keys: Array = [
		"id",
		"phase",
		"enabled",
		"order",
		"priority",
		"conflict_policy",
		"runtime_tasks",
		"budget_ms",
		"soft_budget_ms",
		"hard_budget_ms",
		"auto_degrade_enabled",
		"degradation_policy",
		"degradation_steps",
		"metadata"
	]
	var allowed_task_keys: Array = [
		"id",
		"enabled",
		"order",
		"priority",
		"required",
		"allow_defer",
		"force_immediate",
		"max_quantum_ms",
		"max_items_per_quantum",
		"metadata"
	]

	if contract_bundle.is_empty():
		reasons.append("contract_bundle_empty")

	var encoded_size: int = JSON.stringify(
		contract_bundle
	).to_utf8_buffer().size()
	if encoded_size > RELEASE_LIVE_HOT_SWAP_MAX_BYTES:
		reasons.append(
			"contract_bundle_exceeds_live_release_byte_budget"
		)

	if str(
		contract_bundle.get("schema", "")
	) != RELEASE_LIVE_HOT_SWAP_SCHEMA:
		reasons.append("live_release_schema_invalid")

	if int(
		contract_bundle.get("version", 0)
	) != RELEASE_LIVE_HOT_SWAP_VERSION:
		reasons.append("live_release_version_invalid")

	var state_id: String = str(
		contract_bundle.get("state_id", "")
	).strip_edges()
	if not state_id.begins_with("release_patch."):
		reasons.append("release_overlay_state_id_required")

	var metadata_raw: Variant = contract_bundle.get(
		"metadata",
		{}
	)
	if typeof(metadata_raw) != TYPE_DICTIONARY:
		reasons.append(
			"release_overlay_metadata_must_be_dictionary"
		)
	else:
		var metadata: Dictionary = metadata_raw
		if not bool(metadata.get("release_overlay", false)):
			reasons.append(
				"release_overlay_metadata_required"
			)

	for raw_key in contract_bundle.keys():
		var key: String = str(raw_key)
		if key not in allowed_top_level_keys:
			reasons.append(
				"unsupported_live_release_key:%s" % key
			)

	var runtime_phases_raw: Variant = contract_bundle.get(
		"runtime_phases",
		[]
	)
	var row_count: int = 0

	if typeof(runtime_phases_raw) != TYPE_ARRAY:
		reasons.append("runtime_phases_must_be_array")
	else:
		row_count = (runtime_phases_raw as Array).size()

		for raw_phase in runtime_phases_raw:
			if typeof(raw_phase) != TYPE_DICTIONARY:
				reasons.append(
					"runtime_phases_contains_non_dictionary_row"
				)
				continue

			var phase: Dictionary = raw_phase
			var phase_id: String = str(
				phase.get(
					"id",
					phase.get("phase", "")
				)
			).strip_edges()

			if phase_id == "":
				reasons.append(
					"live_release_runtime_phase_id_required"
				)
			elif not runtime_phase_registry.has(phase_id):
				deferred_reasons.append(
					"live_release_runtime_phase_not_resident_yet:%s"
					% phase_id
				)

			for raw_phase_key in phase.keys():
				var phase_key: String = str(raw_phase_key)
				if phase_key not in allowed_phase_keys:
					reasons.append(
						"unsupported_live_release_runtime_phase_key:%s:%s"
						% [phase_id, phase_key]
					)

			var conflict_policy: String = str(
				phase.get(
					"conflict_policy",
					"replace"
				)
			).strip_edges().to_lower()
			if conflict_policy != "replace":
				reasons.append(
					"runtime_phase_live_release_conflict_policy_must_be_replace:%s"
					% phase_id
				)

			if (
				phase.has("metadata")
				and typeof(phase.get("metadata")) != TYPE_DICTIONARY
			):
				reasons.append(
					"live_release_runtime_phase_metadata_must_be_dictionary:%s"
					% phase_id
				)

			if phase.has("degradation_steps"):
				var degradation_steps_raw: Variant = phase.get(
					"degradation_steps",
					[]
				)
				if typeof(degradation_steps_raw) != TYPE_ARRAY:
					reasons.append(
						"live_release_degradation_steps_must_be_array:%s"
						% phase_id
					)
				else:
					for raw_step in degradation_steps_raw:
						if typeof(raw_step) != TYPE_DICTIONARY:
							reasons.append(
								"live_release_degradation_step_must_be_dictionary:%s"
								% phase_id
							)

			if phase.has("runtime_tasks"):
				var task_rows_raw: Variant = phase.get(
					"runtime_tasks",
					[]
				)
				if typeof(task_rows_raw) != TYPE_ARRAY:
					reasons.append(
						"live_release_runtime_tasks_must_be_array:%s"
						% phase_id
					)
				else:
					var existing_phase_raw: Variant = (
						runtime_phase_registry.get(
							phase_id,
							{}
						)
					)
					var existing_phase: Dictionary = (
						existing_phase_raw as Dictionary
						if typeof(existing_phase_raw) == TYPE_DICTIONARY
						else {}
					)
					var existing_tasks: Dictionary = (
						_live_release_runtime_task_map(
							existing_phase
						)
					)
					var seen_task_ids: Dictionary = {}

					for raw_task in task_rows_raw:
						if typeof(raw_task) != TYPE_DICTIONARY:
							reasons.append(
								"live_release_runtime_task_patch_must_be_dictionary:%s"
								% phase_id
							)
							continue

						var task: Dictionary = raw_task
						var task_id: String = str(
							task.get("id", "")
						).strip_edges()

						if task_id == "":
							reasons.append(
								"live_release_runtime_task_id_required:%s"
								% phase_id
							)
						elif (
							runtime_phase_registry.has(phase_id)
							and not existing_tasks.has(task_id)
						):
							reasons.append(
								"live_release_runtime_task_must_already_be_resident:%s:%s"
								% [phase_id, task_id]
							)

						if seen_task_ids.has(task_id):
							reasons.append(
								"duplicate_live_release_runtime_task_patch:%s:%s"
								% [phase_id, task_id]
							)
						seen_task_ids [task_id] = true

						for raw_task_key in task.keys():
							var task_key: String = str(
								raw_task_key
							)
							if task_key not in allowed_task_keys:
								reasons.append(
									"unsupported_live_release_runtime_task_key:%s:%s:%s"
									% [
										phase_id,
										task_id,
										task_key
									]
								)

						if (
							task.has("metadata")
							and typeof(
								task.get("metadata")
							) != TYPE_DICTIONARY
						):
							reasons.append(
								"live_release_runtime_task_metadata_must_be_dictionary:%s:%s"
								% [phase_id, task_id]
							)

	if row_count <= 0:
		reasons.append(
			"live_release_overlay_has_no_runtime_phases"
		)
	if row_count > RELEASE_LIVE_HOT_SWAP_MAX_ROWS:
		reasons.append(
			"contract_bundle_exceeds_live_release_row_budget"
		)

	return {
		"accepted": (
			reasons.is_empty()
			and deferred_reasons.is_empty()
		),
		"deferred": (
			reasons.is_empty()
			and not deferred_reasons.is_empty()
		),
		"restart_required": not reasons.is_empty(),
		"state_id": state_id,
		"encoded_bytes": encoded_size,
		"row_count": row_count,
		"reasons": reasons,
		"deferred_reasons": deferred_reasons,
		"checked_at_ms": int(Time.get_ticks_msec())
	}


func _live_release_runtime_task_map(
	phase: Dictionary
) -> Dictionary:
	var out: Dictionary = {}

	for raw_task in phase.get("runtime_tasks", []):
		if typeof(raw_task) != TYPE_DICTIONARY:
			continue

		var task: Dictionary = raw_task
		var task_id: String = str(
			task.get("id", "")
		).strip_edges()
		if task_id != "":
			out [task_id] = task

	return out


func _prepare_live_release_runtime_task(
	existing_task: Dictionary,
	task_overlay: Dictionary,
	phase_id: String
) -> Dictionary:
	var errors: Array = []
	var task: Dictionary = existing_task.duplicate(true)
	var task_id: String = str(
		existing_task.get("id", "")
	).strip_edges()

	if task_overlay.has("enabled"):
		task ["enabled"] = bool(
			task_overlay.get(
				"enabled",
				task.get("enabled", true)
			)
		)

	if task_overlay.has("order"):
		task ["order"] = int(
			task_overlay.get(
				"order",
				task.get("order", 100)
			)
		)

	if task_overlay.has("priority"):
		task ["priority"] = int(
			task_overlay.get(
				"priority",
				task.get("priority", 100)
			)
		)

	if task_overlay.has("required"):
		var incoming_required: bool = bool(
			task_overlay.get(
				"required",
				task.get("required", false)
			)
		)
		if (
			not bool(existing_task.get("required", false))
			and incoming_required
		):
			errors.append(
				"Live release runtime task '%s' in phase '%s' may not become required."
				% [task_id, phase_id]
			)
		else:
			task ["required"] = incoming_required

	if task_overlay.has("allow_defer"):
		var incoming_allow_defer: bool = bool(
			task_overlay.get(
				"allow_defer",
				task.get("allow_defer", true)
			)
		)
		if (
			bool(existing_task.get("allow_defer", true))
			and not incoming_allow_defer
		):
			errors.append(
				"Live release runtime task '%s' in phase '%s' may not disable deferral."
				% [task_id, phase_id]
			)
		else:
			task ["allow_defer"] = incoming_allow_defer

	if task_overlay.has("force_immediate"):
		var incoming_force_immediate: bool = bool(
			task_overlay.get(
				"force_immediate",
				task.get("force_immediate", false)
			)
		)
		if (
			not bool(
				existing_task.get(
					"force_immediate",
					false
				)
			)
			and incoming_force_immediate
		):
			errors.append(
				"Live release runtime task '%s' in phase '%s' may not become force_immediate."
				% [task_id, phase_id]
			)
		else:
			task ["force_immediate"] = (
				incoming_force_immediate
			)

	if task_overlay.has("max_quantum_ms"):
		var incoming_quantum_ms: int = clampi(
			int(
				task_overlay.get(
					"max_quantum_ms",
					task.get("max_quantum_ms", 1)
				)
			),
			1,
			6
		)
		if incoming_quantum_ms > int(
			existing_task.get("max_quantum_ms", 1)
		):
			errors.append(
				"Live release runtime task '%s' in phase '%s' may not increase max_quantum_ms."
				% [task_id, phase_id]
			)
		else:
			task ["max_quantum_ms"] = incoming_quantum_ms

	if task_overlay.has("max_items_per_quantum"):
		var incoming_quantum_items: int = clampi(
			int(
				task_overlay.get(
					"max_items_per_quantum",
					task.get(
						"max_items_per_quantum",
						1
					)
				)
			),
			1,
			512
		)
		if incoming_quantum_items > int(
			existing_task.get(
				"max_items_per_quantum",
				1
			)
		):
			errors.append(
				"Live release runtime task '%s' in phase '%s' may not increase max_items_per_quantum."
				% [task_id, phase_id]
			)
		else:
			task ["max_items_per_quantum"] = (
				incoming_quantum_items
			)

	if task_overlay.has("metadata"):
		var task_metadata_raw: Variant = task.get(
			"metadata",
			{}
		)
		var task_metadata: Dictionary = (
			task_metadata_raw.duplicate(true)
			if typeof(task_metadata_raw) == TYPE_DICTIONARY
			else {}
		)
		var task_metadata_overlay: Dictionary = (
			task_overlay.get("metadata", {})
		)
		task_metadata = _deep_merge_dictionary(
			task_metadata,
			task_metadata_overlay
		)
		task ["metadata"] = task_metadata

	return {
		"success": errors.is_empty(),
		"task": task,
		"errors": errors
	}


func _prepare_live_release_runtime_phase(
	phase_overlay: Dictionary
) -> Dictionary:
	var errors: Array = []
	var phase_id: String = str(
		phase_overlay.get(
			"id",
			phase_overlay.get("phase", "")
		)
	).strip_edges()

	var existing_raw: Variant = runtime_phase_registry.get(
		phase_id,
		{}
	)
	if typeof(existing_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"phase": {},
			"errors": [
				"Live release runtime phase '%s' is not resident."
				% phase_id
			]
		}

	var existing: Dictionary = existing_raw
	var phase: Dictionary = existing.duplicate(true)
	phase ["conflict_policy"] = "replace"

	if phase_overlay.has("enabled"):
		phase ["enabled"] = bool(
			phase_overlay.get(
				"enabled",
				phase.get("enabled", true)
			)
		)

	if phase_overlay.has("order"):
		phase ["order"] = int(
			phase_overlay.get(
				"order",
				phase.get("order", 0)
			)
		)

	if phase_overlay.has("priority"):
		phase ["priority"] = int(
			phase_overlay.get(
				"priority",
				phase.get("priority", 0)
			)
		)

	for budget_key in [
		"budget_ms",
		"soft_budget_ms",
		"hard_budget_ms"
	]:
		if not phase_overlay.has(budget_key):
			continue

		var incoming_budget: int = max(
			0,
			int(phase_overlay.get(budget_key, 0))
		)
		var existing_budget: int = int(
			existing.get(budget_key, 0)
		)

		if incoming_budget > existing_budget:
			errors.append(
				"Live release runtime phase '%s' may not increase %s."
				% [phase_id, budget_key]
			)
		else:
			phase [budget_key] = incoming_budget

	if (
		int(phase.get("hard_budget_ms", 0))
		< int(phase.get("budget_ms", 0))
	):
		errors.append(
			"Live release runtime phase '%s' requires hard_budget_ms >= budget_ms."
			% phase_id
		)

	if (
		int(phase.get("soft_budget_ms", 0))
		> int(phase.get("hard_budget_ms", 0))
	):
		errors.append(
			"Live release runtime phase '%s' requires soft_budget_ms <= hard_budget_ms."
			% phase_id
		)

	if phase_overlay.has("auto_degrade_enabled"):
		var incoming_auto_degrade: bool = bool(
			phase_overlay.get(
				"auto_degrade_enabled",
				phase.get("auto_degrade_enabled", true)
			)
		)
		if (
			bool(existing.get("auto_degrade_enabled", true))
			and not incoming_auto_degrade
		):
			errors.append(
				"Live release runtime phase '%s' may not disable auto degradation."
				% phase_id
			)
		else:
			phase ["auto_degrade_enabled"] = (
				incoming_auto_degrade
			)

	if phase_overlay.has("degradation_policy"):
		var incoming_degradation_policy: String = str(
			phase_overlay.get(
				"degradation_policy",
				""
			)
		).strip_edges().to_lower()

		if incoming_degradation_policy == "":
			errors.append(
				"Live release runtime phase '%s' requires a non-empty degradation policy."
				% phase_id
			)
		else:
			phase ["degradation_policy"] = (
				incoming_degradation_policy
			)

	if phase_overlay.has("degradation_steps"):
		phase ["degradation_steps"] = (
			_safe_dictionary_array(
				phase_overlay.get(
					"degradation_steps",
					[]
				)
			)
		)

	if phase_overlay.has("metadata"):
		var phase_metadata_raw: Variant = phase.get(
			"metadata",
			{}
		)
		var phase_metadata: Dictionary = (
			phase_metadata_raw.duplicate(true)
			if typeof(phase_metadata_raw) == TYPE_DICTIONARY
			else {}
		)
		var phase_metadata_overlay: Dictionary = (
			phase_overlay.get("metadata", {})
		)
		var existing_runtime_kind: String = str(
			phase_metadata.get("runtime_kind", "")
		).strip_edges()

		if phase_metadata_overlay.has("runtime_kind"):
			var incoming_runtime_kind: String = str(
				phase_metadata_overlay.get(
					"runtime_kind",
					""
				)
			).strip_edges()
			if incoming_runtime_kind != existing_runtime_kind:
				errors.append(
					"Live release runtime phase '%s' may not change metadata.runtime_kind."
					% phase_id
				)

		phase_metadata = _deep_merge_dictionary(
			phase_metadata,
			phase_metadata_overlay
		)
		phase ["metadata"] = phase_metadata

	if phase_overlay.has("runtime_tasks"):
		var task_map: Dictionary = (
			_live_release_runtime_task_map(existing)
		)
		var task_index_by_id: Dictionary = {}
		var runtime_tasks: Array = (
			existing.get(
				"runtime_tasks",
				[]
			).duplicate(true)
		)

		for i in range(runtime_tasks.size()):
			var runtime_task_raw: Variant = runtime_tasks [i]
			if typeof(runtime_task_raw) != TYPE_DICTIONARY:
				continue

			var runtime_task: Dictionary = runtime_task_raw
			var runtime_task_id: String = str(
				runtime_task.get("id", "")
			).strip_edges()
			if runtime_task_id != "":
				task_index_by_id [runtime_task_id] = i

		for raw_task_overlay in phase_overlay.get(
			"runtime_tasks",
			[]
		):
			if typeof(raw_task_overlay) != TYPE_DICTIONARY:
				continue

			var task_overlay: Dictionary = raw_task_overlay
			var task_id: String = str(
				task_overlay.get("id", "")
			).strip_edges()
			var existing_task_raw: Variant = task_map.get(
				task_id,
				{}
			)

			if typeof(existing_task_raw) != TYPE_DICTIONARY:
				errors.append(
					"Live release runtime task '%s' in phase '%s' is not resident."
					% [task_id, phase_id]
				)
				continue

			var task_report: Dictionary = (
				_prepare_live_release_runtime_task(
					existing_task_raw,
					task_overlay,
					phase_id
				)
			)

			for raw_error in task_report.get("errors", []):
				errors.append(str(raw_error))

			if not bool(
				task_report.get("success", false)
			):
				continue

			var task_index: int = int(
				task_index_by_id.get(task_id, -1)
			)
			if (
				task_index >= 0
				and task_index < runtime_tasks.size()
			):
				runtime_tasks [task_index] = (
					task_report.get(
						"task",
						{}
					).duplicate(true)
				)

		phase ["runtime_tasks"] = runtime_tasks
		phase ["domain_tasks"] = (
			runtime_tasks.duplicate(true)
		)

	return {
		"success": errors.is_empty(),
		"phase": phase,
		"errors": errors
	}


func _live_release_hot_swap_completion_report(
	transaction: Dictionary,
	success: bool
) -> Dictionary:
	var errors: Array = (
		transaction.get("errors", []).duplicate(true)
	)
	var warnings: Array = (
		transaction.get("warnings", []).duplicate(true)
	)
	var context_raw: Variant = transaction.get(
		"context",
		{}
	)
	var context: Dictionary = (
		context_raw as Dictionary
		if typeof(context_raw) == TYPE_DICTIONARY
		else {}
	)

	var report:= {
		"schema": "eralife.live_contract_hot_swap_report",
		"version": CONTRACT_VERSION,
		"success": success,
		"transaction_id": str(
			transaction.get("transaction_id", "")
		),
		"source": str(
			context.get(
				"source",
				"release_update_runtime"
			)
		),
		"state_id_before": active_state_id,
		"state_id_after": active_state_id,
		"release_patch_state_id": str(
			transaction.get("patch_state_id", "")
		),
		"release_revision": str(
			context.get("release_revision", "")
		),
		"rollback_capsule_id": "",
		"load": {
			"mode": "bounded_resident_runtime_phase_overlay",
		},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		},
		"adaptive_resolution": {
			"skipped": true,
			"reason": "release_overlay_may_not_reconcile_world"
		},
		"streaming_boot": {
			"skipped": true,
			"reason": "release_overlay_may_not_boot_world_streaming"
		},
		"hydration": {
			"skipped": true,
			"reason": "release_overlay_may_not_hydrate_user_world"
		},
		"rolled_back": false,
		"rollback_strategy": "signed_compensating_overlay",
		"warnings": warnings.duplicate(true),
		"hot_swapped_at_ms": int(Time.get_ticks_msec())
	}

	if not success:
		report ["warnings"].append(
			"Live release runtime phase overlay validation failed."
		)

	return report


func _commit_prepared_live_release_hot_swap(
	transaction: Dictionary
) -> Dictionary:
	var patch_state_id: String = str(
		transaction.get("patch_state_id", "")
	).strip_edges()
	var runtime_phases: Array = transaction.get(
		"prepared_runtime_phases",
		[]
	)

	for raw_phase in runtime_phases:
		if typeof(raw_phase) != TYPE_DICTIONARY:
			continue

		var phase: Dictionary = raw_phase
		var phase_id: String = str(
			phase.get("id", "")
		).strip_edges()

		_upsert_contract_registry_entry(
			runtime_phase_registry,
			phase_id,
			phase,
			"runtime_phase",
			patch_state_id
		)

	var resolved_overlay:= {
		"schema": RELEASE_LIVE_HOT_SWAP_SCHEMA,
		"version": RELEASE_LIVE_HOT_SWAP_VERSION,
		"state_id": patch_state_id,
		"metadata": transaction.get(
			"metadata",
			{}
		).duplicate(true),
		"runtime_phases": runtime_phases.duplicate(true),
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": transaction.get(
				"warnings",
				[]
			).duplicate(true)
		}
	}

	contract_registry [patch_state_id] = (
		resolved_overlay.duplicate(true)
	)
	validation_reports [patch_state_id] = (
		resolved_overlay ["validation"].duplicate(true)
	)

	var report: Dictionary = (
		_live_release_hot_swap_completion_report(
			transaction,
			true
		)
	)

	live_contract_hot_swap_ledger.append(
		report.duplicate(true)
	)
	while live_contract_hot_swap_ledger.size() > 80:
		live_contract_hot_swap_ledger.pop_front()

	last_live_contract_hot_swap_report = (
		report.duplicate(true)
	)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state ["live_contract_hot_swap_ledger"] = (
			live_contract_hot_swap_ledger.duplicate(true)
		)
		gs.scenario_state ["last_live_contract_hot_swap_report"] = (
			last_live_contract_hot_swap_report.duplicate(true)
		)

	return report


func _service_live_release_hot_swap_transaction(
	transaction: Dictionary
) -> Dictionary:
	var stage: String = str(
		transaction.get("stage", "prepare")
	)
	var cursor: int = int(
		transaction.get("cursor", 0)
	)

	match stage:
		"prepare":
			var phase_overlays: Array = (
				transaction.get(
					"raw_runtime_phase_overlays",
					[]
				)
			)

			if cursor >= phase_overlays.size():
				transaction ["stage"] = "commit"
				transaction ["cursor"] = 0
				return {
					"progressed": true,
					"completed": false
				}

			var phase_overlay_raw: Variant = (
				phase_overlays [cursor]
			)

			if typeof(
				phase_overlay_raw
			) != TYPE_DICTIONARY:
				transaction ["errors"].append(
					"Live release runtime phase overlay was not a Dictionary."
				)
			else:
				var phase_overlay: Dictionary = (
					phase_overlay_raw
				)
				var phase_id: String = str(
					phase_overlay.get(
						"id",
						phase_overlay.get(
							"phase",
							""
						)
					)
				).strip_edges()

				var seen_phase_ids: Dictionary = (
					transaction.get(
						"seen_phase_ids",
						{}
					)
				)

				if seen_phase_ids.has(phase_id):
					transaction ["errors"].append(
						"Duplicate live release runtime phase overlay '%s'."
						% phase_id
					)
				else:
					seen_phase_ids [phase_id] = true
					transaction ["seen_phase_ids"] = (
						seen_phase_ids
					)

					var phase_report: Dictionary = (
						_prepare_live_release_runtime_phase(
							phase_overlay
						)
					)

					for raw_error in phase_report.get(
						"errors",
						[]
					):
						transaction ["errors"].append(
							str(raw_error)
						)

					if bool(
						phase_report.get(
							"success",
							false
						)
					):
						var prepared_phase_raw: Variant = (
							phase_report.get(
								"phase",
								{}
							)
						)
						if (
							typeof(
								prepared_phase_raw
							) == TYPE_DICTIONARY
						):
							var prepared_phase: Dictionary = (
								prepared_phase_raw
							)
							prepared_phase ["state_id"] = str(
								transaction.get(
									"patch_state_id",
									""
								)
							)
							prepared_phase [
								"conflict_policy"
							] = "replace"
							transaction [
								"prepared_runtime_phases"
							].append(
								prepared_phase
							)

			cursor += 1
			transaction ["cursor"] = cursor

			if cursor >= phase_overlays.size():
				transaction ["stage"] = "commit"
				transaction ["cursor"] = 0

			return {
				"progressed": true,
				"completed": false
			}

		"commit":
			if not transaction.get(
				"errors",
				[]
			).is_empty():
				var failed_report: Dictionary = (
					_live_release_hot_swap_completion_report(
						transaction,
						false
					)
				)
				last_live_contract_hot_swap_report = (
					failed_report.duplicate(true)
				)
				return {
					"progressed": true,
					"completed": true,
					"report": failed_report
				}

			return {
				"progressed": true,
				"completed": true,
				"report": (
					_commit_prepared_live_release_hot_swap(
						transaction
					)
				)
			}

		_:
			transaction ["errors"].append(
				"Live release transaction entered an unknown service stage."
			)
			var invalid_stage_report: Dictionary = (
				_live_release_hot_swap_completion_report(
					transaction,
					false
				)
			)
			last_live_contract_hot_swap_report = (
				invalid_stage_report.duplicate(true)
			)
			return {
				"progressed": true,
				"completed": true,
				"report": invalid_stage_report
			}


func service_live_release_hot_swap(
	max_transactions: int = 1
) -> Dictionary:
	var transaction_limit: int = clampi(
		max_transactions,
		0,
		1
	)
	var reports: Array = []
	var progressed: int = 0
	var serviced: int = 0

	if (
		transaction_limit > 0
		and not live_release_hot_swap_queue.is_empty()
	):
		var raw_transaction: Variant = (
			live_release_hot_swap_queue [0]
		)

		if typeof(raw_transaction) != TYPE_DICTIONARY:
			live_release_hot_swap_queue.pop_front()
			progressed = 1
		else:
			var transaction: Dictionary = raw_transaction
			var step_report: Dictionary = (
				_service_live_release_hot_swap_transaction(
					transaction
				)
			)
			progressed = (
				1
				if bool(
					step_report.get(
						"progressed",
						false
					)
				)
				else 0
			)

			if bool(
				step_report.get(
					"completed",
					false
				)
			):
				live_release_hot_swap_queue.pop_front()
				var completion_raw: Variant = (
					step_report.get(
						"report",
						{}
					)
				)
				if (
					typeof(completion_raw)
					== TYPE_DICTIONARY
				):
					reports.append(
						(
							completion_raw as Dictionary
						).duplicate(true)
					)
				serviced = 1
			else:
				live_release_hot_swap_queue [0] = (
					transaction
				)

	last_live_release_hot_swap_service_report = {
		"schema": "eralife.live_release_hot_swap_service_report",
		"version": CONTRACT_VERSION,
		"requested": max_transactions,
		"progressed": progressed,
		"serviced": serviced,
		"queue_depth": live_release_hot_swap_queue.size(),
		"reports": reports,
		"serviced_at_ms": int(Time.get_ticks_msec())
	}

	return (
		last_live_release_hot_swap_service_report.duplicate(true)
	)

func _web_user_agent() -> String:
	if not OS.has_feature("web"):
		return ""
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var value: Variant = JavaScriptBridge.eval("navigator.userAgent || ''", true)
	return str(value)


func _is_likely_smart_tv_user_agent(user_agent: String) -> bool:
	var ua: String = str(user_agent).to_lower()
	if ua == "":
		return false

	var tv_tokens:= [
		"hisense",
		"vidaa",
		"smart-tv",
		"smarttv",
		"hbbtv",
		"tizen",
		"webos",
		"bravia",
		"viera",
		"aquos",
		"roku",
		"appletv",
		"googletv",
		"android tv",
		"fire tv",
		"aftm",
		"aftt",
		"aftb"
	]

	for token in tv_tokens:
		if ua.find(str(token)) >= 0:
			return true

	return false
func _detect_runtime_capability_profile() -> Dictionary:
	var os_name: String = OS.get_name().to_lower()
	var platform_name: String = OS.get_name()
	var user_agent: String = _web_user_agent().to_lower()

	var device_class: String = "desktop"
	if OS.has_feature("web"):
		device_class = "web"
	elif OS.has_feature("mobile") or os_name.find("android") >= 0 or os_name.find("ios") >= 0:
		device_class = "mobile"

	if _is_likely_smart_tv_user_agent(user_agent):
		device_class = "smart_tv"

	var input_mode: String = "pointer_keyboard"
	if device_class == "mobile":
		input_mode = "touch"
	elif device_class == "smart_tv":
		input_mode = "focus_remote"

	var cpu_tier: String = "mid"
	var memory_tier: String = "mid"
	var gpu_tier: String = "mid"
	var screen_class: String = "standard"
	var ui_layout: String = "standard"
	var simulation_cadence: String = "normal"
	var phase_budget_cap: int = 0
	var npc_soft_cap: int = 6000
	var region_stream_radius: int = 2
	var event_stream_limit: int = 120
	var stream_chunk_budget: int = 160
	var max_visible_choices: int = 8
	var ui_scale: float = 1.0

	if device_class == "web":
		cpu_tier = "low"
		memory_tier = "low"
		gpu_tier = "low"
		simulation_cadence = "reduced"
		phase_budget_cap = 2
		npc_soft_cap = 1200
		region_stream_radius = 1
		event_stream_limit = 40
		stream_chunk_budget = 96
	elif device_class == "mobile":
		cpu_tier = "low"
		memory_tier = "low"
		gpu_tier = "low"
		screen_class = "mobile"
		ui_layout = "mobile_compact"
		simulation_cadence = "reduced"
		phase_budget_cap = 2
		npc_soft_cap = 1400
		region_stream_radius = 1
		event_stream_limit = 48
		stream_chunk_budget = 96
		max_visible_choices = 6
		ui_scale = 1.08
	elif device_class == "smart_tv":
		cpu_tier = "low"
		memory_tier = "low"
		gpu_tier = "low"
		screen_class = "tv"
		ui_layout = "tv_focus"
		simulation_cadence = "reduced"
		phase_budget_cap = 2
		npc_soft_cap = 900
		region_stream_radius = 1
		event_stream_limit = 30
		stream_chunk_budget = 64
		max_visible_choices = 5
		ui_scale = 1.35

	return {
		"id": "auto",
		"profile_id": "auto",
		"state_id": active_state_id,
		"device_class": device_class,
		"platform": platform_name,
		"user_agent": user_agent,
		"input_mode": input_mode,
		"cpu_tier": cpu_tier,
		"memory_tier": memory_tier,
		"gpu_tier": gpu_tier,
		"screen_class": screen_class,
		"simulation_cadence": simulation_cadence,
		"phase_budget_cap": phase_budget_cap,
		"npc_soft_cap": npc_soft_cap,
		"region_stream_radius": region_stream_radius,
		"event_stream_limit": event_stream_limit,
		"stream_chunk_budget": stream_chunk_budget,
		"streaming_enabled": true,
		"offline_capable": true,
		"persistent_save": true,
		"save_persistence_key": "eralife.save.%s" % _safe_link_id(active_state_id),
		"cache_namespace": "eralife.worlds.v1",
		"ui_layout": ui_layout,
		"ui_scale": ui_scale,
		"max_visible_choices": max_visible_choices,
		"focus_navigation_enabled": device_class == "smart_tv",
		"background_work_policy": "defer_until_idle" if device_class in ["web", "mobile", "smart_tv"] else "normal",
		"guard_patch": {},
		"metadata": {
			"detected": true,
			"browser_streaming_supported": OS.has_feature("web"),
			"smart_tv_detected": device_class == "smart_tv"
		}
	}


func _normalize_runtime_capability_profiles(raw_profiles: Variant, state_id: String = "") -> Dictionary:
	var out: Dictionary = {}

	if typeof(raw_profiles) == TYPE_ARRAY:
		for raw in raw_profiles:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var profile: Dictionary = _normalize_runtime_capability_profile(raw as Dictionary, state_id)
			var profile_id: String = str(profile.get("id", "")).strip_edges()
			if profile_id != "":
				out [profile_id] = profile

	elif typeof(raw_profiles) == TYPE_DICTIONARY:
		var dict_profiles: Dictionary = raw_profiles
		if dict_profiles.has("device_class") or dict_profiles.has("profile_id") or dict_profiles.has("input_mode"):
			var single_profile: Dictionary = _normalize_runtime_capability_profile(dict_profiles, state_id)
			var single_id: String = str(single_profile.get("id", "auto")).strip_edges()
			out [single_id] = single_profile
		else:
			for key in dict_profiles.keys():
				var row_raw: Variant = dict_profiles.get(key, {})
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = (row_raw as Dictionary).duplicate(true)
				if not row.has("id"):
					row ["id"] = str(key)
				var profile: Dictionary = _normalize_runtime_capability_profile(row, state_id)
				var profile_id: String = str(profile.get("id", key)).strip_edges()
				out [profile_id] = profile

	if out.is_empty():
		var auto_profile: Dictionary = _normalize_runtime_capability_profile(_detect_runtime_capability_profile(), state_id)
		out ["auto"] = auto_profile

	return out


func _normalize_runtime_capability_profile(raw_profile: Dictionary, state_id: String = "") -> Dictionary:
	var profile_id: String = str(raw_profile.get("id", raw_profile.get("profile_id", "auto"))).strip_edges()
	if profile_id == "":
		profile_id = "auto"

	var device_class: String = str(raw_profile.get("device_class", raw_profile.get("device", "desktop"))).strip_edges().to_lower()
	if device_class == "":
		device_class = "desktop"

	var input_mode: String = str(raw_profile.get("input_mode", "pointer_keyboard")).strip_edges().to_lower()
	if input_mode == "":
		input_mode = "pointer_keyboard"

	if device_class == "smart_tv" and input_mode == "pointer_keyboard":
		input_mode = "focus_remote"

	var cpu_tier: String = str(raw_profile.get("cpu_tier", "mid")).strip_edges().to_lower()
	var memory_tier: String = str(raw_profile.get("memory_tier", "mid")).strip_edges().to_lower()
	var gpu_tier: String = str(raw_profile.get("gpu_tier", "mid")).strip_edges().to_lower()
	var ui_layout: String = str(raw_profile.get("ui_layout", "standard")).strip_edges().to_lower()
	if device_class == "smart_tv" and ui_layout == "standard":
		ui_layout = "tv_focus"

	var clean_state_id: String = str(state_id).strip_edges()
	if clean_state_id == "":
		clean_state_id = active_state_id

	var default_save_key: String = "eralife.save.%s" % _safe_link_id(clean_state_id)

	return {
		"id": profile_id,
		"profile_id": profile_id,
		"state_id": clean_state_id,
		"device_class": device_class,
		"platform": str(raw_profile.get("platform", OS.get_name())),
		"user_agent": str(raw_profile.get("user_agent", "")),
		"input_mode": input_mode,
		"cpu_tier": cpu_tier,
		"memory_tier": memory_tier,
		"gpu_tier": gpu_tier,
		"screen_class": str(raw_profile.get("screen_class", "tv" if device_class == "smart_tv" else "standard")).strip_edges().to_lower(),
		"simulation_cadence": str(raw_profile.get("simulation_cadence", "reduced" if device_class in ["web", "mobile", "smart_tv"] else "normal")).strip_edges().to_lower(),
		"phase_budget_cap": int(raw_profile.get("phase_budget_cap", 2 if device_class in ["web", "mobile", "smart_tv"] else 0)),
		"npc_soft_cap": int(raw_profile.get("npc_soft_cap", 900 if device_class == "smart_tv" else 1200 if device_class in ["web", "mobile"] else 2500)),
		"region_stream_radius": int(raw_profile.get("region_stream_radius", 1)),
		"event_stream_limit": int(raw_profile.get("event_stream_limit", 30 if device_class == "smart_tv" else 80)),
		"stream_chunk_budget": int(raw_profile.get("stream_chunk_budget", 64 if device_class == "smart_tv" else 96 if device_class in ["web", "mobile"] else 160)),
		"streaming_enabled": bool(raw_profile.get("streaming_enabled", true)),
		"offline_capable": bool(raw_profile.get("offline_capable", true)),
		"persistent_save": bool(raw_profile.get("persistent_save", true)),
		"save_persistence_key": str(raw_profile.get("save_persistence_key", default_save_key)),
		"cache_namespace": str(raw_profile.get("cache_namespace", "eralife.worlds.v1")),
		"ui_layout": ui_layout,
		"ui_scale": float(raw_profile.get("ui_scale", 1.35 if device_class == "smart_tv" else 1.0)),
		"max_visible_choices": int(raw_profile.get("max_visible_choices", 5 if device_class == "smart_tv" else 8)),
		"focus_navigation_enabled": bool(raw_profile.get("focus_navigation_enabled", device_class == "smart_tv" or input_mode in ["focus_remote", "remote"])),
		"background_work_policy": str(raw_profile.get("background_work_policy", "defer_until_idle" if device_class in ["web", "mobile", "smart_tv"] else "normal")),
		"guard_patch": raw_profile.get("guard_patch", {}).duplicate(true) if typeof(raw_profile.get("guard_patch", {})) == TYPE_DICTIONARY else {},
		"metadata": raw_profile.get("metadata", {}).duplicate(true) if typeof(raw_profile.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func _normalize_adaptive_resolution_rules(raw_rules: Variant, state_id: String = "") -> Array:
	var out: Array = []
	var rules: Array = []

	if typeof(raw_rules) == TYPE_ARRAY:
		rules = raw_rules
	elif typeof(raw_rules) == TYPE_DICTIONARY:
		for key in (raw_rules as Dictionary).keys():
			var row_raw: Variant = (raw_rules as Dictionary).get(key, {})
			if typeof(row_raw) == TYPE_DICTIONARY:
				var row: Dictionary = (row_raw as Dictionary).duplicate(true)
				if not row.has("id"):
					row ["id"] = str(key)
				rules.append(row)

	for raw in rules:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = (raw as Dictionary).duplicate(true)
		var rule_id: String = str(rule.get("id", rule.get("rule_id", ""))).strip_edges()
		if rule_id == "":
			rule_id = "adaptive_rule_%d" % out.size()

		rule ["id"] = rule_id
		rule ["state_id"] = state_id
		rule ["enabled"] = bool(rule.get("enabled", true))
		rule ["priority"] = int(rule.get("priority", 100))
		rule ["action"] = str(rule.get("action", "guard_patch")).strip_edges().to_lower()

		out.append(rule)

	return out


func _normalize_world_streaming_manifest(raw_manifest: Variant, state_id: String = "") -> Dictionary:
	if typeof(raw_manifest) != TYPE_DICTIONARY:
		return _build_default_world_streaming_manifest(state_id)

	var manifest: Dictionary = (raw_manifest as Dictionary).duplicate(true)
	if manifest.is_empty():
		return _build_default_world_streaming_manifest(state_id)

	manifest ["schema"] = str(manifest.get("schema", "eralife.world_streaming_manifest"))
	manifest ["version"] = max(1, int(manifest.get("version", CONTRACT_VERSION)))
	manifest ["state_id"] = str(manifest.get("state_id", state_id)).strip_edges()
	manifest ["enabled"] = bool(manifest.get("enabled", true))

	if typeof(manifest.get("stages", [])) != TYPE_ARRAY:
		manifest ["stages"] = _build_default_world_streaming_manifest(state_id).get("stages", [])

	if typeof(manifest.get("limits", {})) != TYPE_DICTIONARY:
		manifest ["limits"] = {}

	return manifest


func _normalize_launch_links(raw_links: Variant, state_id: String = "") -> Dictionary:
	var out: Dictionary = {}

	if typeof(raw_links) == TYPE_DICTIONARY:
		out = (raw_links as Dictionary).duplicate(true)

	if out.is_empty():
		out [str(state_id)] = build_tap_to_play_links(state_id, {})

	return out


func _ingest_runtime_capability_profiles(raw_profiles: Variant, state_id: String = "") -> void:
	var normalized: Dictionary = _normalize_runtime_capability_profiles(raw_profiles, state_id)
	for profile_id in normalized.keys():
		runtime_capability_registry [str(profile_id)] = normalized.get(profile_id, {}).duplicate(true)


func _ingest_adaptive_resolution_rules(raw_rules: Variant, state_id: String = "") -> void:
	var normalized: Array = _normalize_adaptive_resolution_rules(raw_rules, state_id)
	for raw_rule in normalized:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = raw_rule
		var rule_id: String = str(rule.get("id", "")).strip_edges()
		if rule_id == "":
			continue
		adaptive_resolution_registry [rule_id] = rule.duplicate(true)


func _default_adaptive_resolution_rules() -> Array:
	return [
		{
			"id": "default_low_power_guard_patch",
			"enabled": true,
			"priority": 10,
			"device_classes": ["web", "mobile", "smart_tv"],
			"cpu_tiers": ["low"],
			"action": "guard_patch",
			"guard_patch": {
				"defer_noncritical_systems": true,
				"reduce_scenario_density": true,
				"reduce_identity_density": true,
				"fallback_cached_ui": true,
				"defer_refresh_once": true,
				"ui_alive_priority": true,
				"ui_tail_work_yield_to_input": true,
				"phase_budget_cap": 2,
				"commit_budget_cap": 2,
				"runtime_snapshot_items_per_step": 96
			}
		},
		{
			"id": "default_tv_focus_ui",
			"enabled": true,
			"priority": 20,
			"device_classes": ["smart_tv"],
			"input_modes": ["focus_remote", "remote"],
			"action": "ui_layout",
			"ui_layout": "tv_focus"
		},
		{
			"id": "default_low_power_streaming",
			"enabled": true,
			"priority": 30,
			"device_classes": ["web", "mobile", "smart_tv"],
			"action": "streaming_limit",
			"limits": {
				"boot_core_only": true,
				"visible_npc_soft_cap": 1200,
				"region_stream_radius": 1,
				"event_stream_limit": 40
			}
		},
		{
			"id": "default_disable_live_diagnostics_on_low_power",
			"enabled": true,
			"priority": 40,
			"device_classes": ["web", "mobile", "smart_tv"],
			"cpu_tiers": ["low"],
			"action": "disable_engine",
			"engine_id": "live_diagnostics_engine",
			"reason": "Disabled by adaptive contract resolution for low-power runtime."
		}
	]


func _adaptive_rule_matches_capability(rule: Dictionary, capability: Dictionary) -> bool:
	var device_classes: Array = _safe_string_array(rule.get("device_classes", rule.get("devices", [])))
	if not device_classes.is_empty() and str(capability.get("device_class", "")).to_lower() not in device_classes:
		return false

	var input_modes: Array = _safe_string_array(rule.get("input_modes", []))
	if not input_modes.is_empty() and str(capability.get("input_mode", "")).to_lower() not in input_modes:
		return false

	var cpu_tiers: Array = _safe_string_array(rule.get("cpu_tiers", []))
	if not cpu_tiers.is_empty() and str(capability.get("cpu_tier", "")).to_lower() not in cpu_tiers:
		return false

	var memory_tiers: Array = _safe_string_array(rule.get("memory_tiers", []))
	if not memory_tiers.is_empty() and str(capability.get("memory_tier", "")).to_lower() not in memory_tiers:
		return false

	var gpu_tiers: Array = _safe_string_array(rule.get("gpu_tiers", []))
	if not gpu_tiers.is_empty() and str(capability.get("gpu_tier", "")).to_lower() not in gpu_tiers:
		return false

	return true


func _apply_adaptive_resolution_rule(rule: Dictionary, capability: Dictionary) -> Dictionary:
	var action: String = str(rule.get("action", "guard_patch")).strip_edges().to_lower()
	var report:= {
		"id": str(rule.get("id", "")),
		"action": action,
		"applied": false,
		"runtime_guard_patch": {}
	}

	match action:
		"disable_engine":
			var engine_id: String = str(rule.get("engine_id", "")).strip_edges()
			if engine_id == "" or not engine_registry.has(engine_id):
				report ["reason"] = "missing_engine"
				return report

			var engine: Dictionary = engine_registry.get(engine_id, {})
			if bool(engine.get("required", false)):
				report ["reason"] = "required_engine_not_disabled"
				return report

			engine ["enabled"] = false
			engine ["disabled_reason"] = str(rule.get("reason", "Disabled by adaptive contract resolution."))
			engine ["disabled_by_adaptive_resolution"] = true
			engine_registry [engine_id] = engine

			report ["applied"] = true
			report ["engine_id"] = engine_id
			report ["runtime_guard_patch"] = {
				"defer_noncritical_systems": true,
				"fallback_cached_ui": true
			}

		"enable_engine":
			var engine_id: String = str(rule.get("engine_id", "")).strip_edges()
			if engine_id == "" or not engine_registry.has(engine_id):
				report ["reason"] = "missing_engine"
				return report

			var engine: Dictionary = engine_registry.get(engine_id, {})
			engine ["enabled"] = true
			engine.erase("disabled_reason")
			engine.erase("disabled_by_adaptive_resolution")
			engine_registry [engine_id] = engine

			report ["applied"] = true
			report ["engine_id"] = engine_id

		"guard_patch":
			var patch: Dictionary = rule.get("guard_patch", {}).duplicate(true) if typeof(rule.get("guard_patch", {})) == TYPE_DICTIONARY else {}
			report ["applied"] = true
			report ["runtime_guard_patch"] = patch

		"ui_layout":
			var ui_layout: String = str(rule.get("ui_layout", capability.get("ui_layout", "standard"))).strip_edges().to_lower()
			report ["applied"] = true
			report ["ui_layout"] = ui_layout
			report ["runtime_guard_patch"] = {
				"ui_layout_mode": ui_layout,
				"ui_focus_navigation_enabled": ui_layout in ["tv_focus", "focus", "remote_focus"]
			}

		"simulation_cadence":
			var cadence: String = str(rule.get("simulation_cadence", rule.get("cadence", capability.get("simulation_cadence", "normal")))).strip_edges().to_lower()
			runtime_capability_profile ["simulation_cadence"] = cadence
			report ["applied"] = true
			report ["runtime_guard_patch"] = {
				"simulation_cadence": cadence,
				"simulation_cadence_divisor": _simulation_cadence_divisor(cadence)
			}

		"phase_budget":
			var phase_id: String = str(rule.get("phase_id", "all")).strip_edges()
			var soft_cap: int = int(rule.get("soft_budget_ms", rule.get("budget_ms", 0)))
			var hard_cap: int = int(rule.get("hard_budget_ms", soft_cap))

			for key in runtime_phase_registry.keys():
				if phase_id != "all" and str(key) != phase_id:
					continue

				var phase: Dictionary = runtime_phase_registry.get(key, {})
				if soft_cap > 0:
					phase ["soft_budget_ms"] = min(int(phase.get("soft_budget_ms", phase.get("budget_ms", DEFAULT_PHASE_BUDGET_MS))), soft_cap)
					phase ["budget_ms"] = min(int(phase.get("budget_ms", DEFAULT_PHASE_BUDGET_MS)), soft_cap)
				if hard_cap > 0:
					phase ["hard_budget_ms"] = min(int(phase.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS)), hard_cap)
				phase ["adaptive_budget_applied"] = true
				runtime_phase_registry [key] = phase

			report ["applied"] = true
			report ["runtime_guard_patch"] = {
				"phase_budget_cap": soft_cap
			}

		"streaming_limit":
			var limits: Dictionary = rule.get("limits", {}).duplicate(true) if typeof(rule.get("limits", {})) == TYPE_DICTIONARY else {}
			if world_streaming_manifest.is_empty():
				world_streaming_manifest = _build_default_world_streaming_manifest(active_state_id)

			var current_limits: Dictionary = world_streaming_manifest.get("limits", {}) if typeof(world_streaming_manifest.get("limits", {})) == TYPE_DICTIONARY else {}
			current_limits = _merged_dictionary_copy(current_limits, limits)
			world_streaming_manifest ["limits"] = current_limits
			world_streaming_manifest ["enabled"] = true

			report ["applied"] = true
			report ["limits"] = limits.duplicate(true)
			report ["runtime_guard_patch"] = {
				"world_streaming_enabled": true,
				"world_streaming_boot_core_only": bool(limits.get("boot_core_only", true)),
				"adaptive_npc_soft_cap": int(limits.get("visible_npc_soft_cap", capability.get("npc_soft_cap", 2500)))
			}

		_:
			report ["reason"] = "unknown_action"

	return report


func _guard_patch_for_capability_profile(profile: Dictionary) -> Dictionary:
	var patch: Dictionary = profile.get("guard_patch", {}).duplicate(true) if typeof(profile.get("guard_patch", {})) == TYPE_DICTIONARY else {}
	var device_class: String = str(profile.get("device_class", "desktop")).to_lower()
	var input_mode: String = str(profile.get("input_mode", "pointer_keyboard")).to_lower()
	var cpu_tier: String = str(profile.get("cpu_tier", "mid")).to_lower()
	var low_power_runtime: bool = device_class in ["web", "mobile", "smart_tv"] or cpu_tier == "low"

	if low_power_runtime:
		patch ["defer_noncritical_systems"] = true
		patch ["reduce_scenario_density"] = true
		patch ["reduce_identity_density"] = true
		patch ["fallback_cached_ui"] = true
		patch ["defer_refresh_once"] = true
		patch ["ui_alive_priority"] = true
		patch ["ui_tail_work_yield_to_input"] = true
		patch ["world_streaming_enabled"] = true
		patch ["world_streaming_boot_core_only"] = true
		patch ["adaptive_npc_soft_cap"] = int(profile.get("npc_soft_cap", 1200))
		patch ["runtime_snapshot_items_per_step"] = int(profile.get("stream_chunk_budget", 96))
		patch ["ui_background_work_defer_ms"] = 180
		patch ["ui_idle_bus_flush_interval_ms"] = 96

	if device_class == "smart_tv" or input_mode in ["focus_remote", "remote"]:
		patch ["ui_layout_mode"] = "tv_focus"
		patch ["ui_focus_navigation_enabled"] = true
		patch ["ui_remote_back_closes_panel"] = true
		patch ["ui_hover_effects_enabled"] = false
		patch ["ui_focus_highlight_enabled"] = true
		patch ["ui_max_visible_choices"] = int(profile.get("max_visible_choices", 5))
		patch ["ui_scale"] = float(profile.get("ui_scale", 1.35))
		patch ["simulation_cadence"] = str(profile.get("simulation_cadence", "reduced"))

	if int(profile.get("phase_budget_cap", 0)) > 0:
		patch ["phase_budget_cap"] = int(profile.get("phase_budget_cap", 0))

	patch ["simulation_cadence"] = str(profile.get("simulation_cadence", "normal"))
	patch ["simulation_cadence_divisor"] = _simulation_cadence_divisor(str(profile.get("simulation_cadence", "normal")))
	patch ["save_persistence_key"] = str(profile.get("save_persistence_key", "eralife.save.%s" % _safe_link_id(active_state_id)))
	patch ["offline_world_cache_namespace"] = str(profile.get("cache_namespace", "eralife.worlds.v1"))

	return patch


func _simulation_cadence_divisor(cadence: String) -> int:
	var clean: String = str(cadence).strip_edges().to_lower()
	match clean:
		"full":
			return 1
		"normal":
			return 1
		"reduced":
			return 2
		"slow":
			return 3
		"background":
			return 4
		"minimal":
			return 6
		_:
			return 1


func _build_default_world_streaming_manifest(state_id: String = "") -> Dictionary:
	var clean_state_id: String = str(state_id).strip_edges()
	if clean_state_id == "":
		clean_state_id = active_state_id

	var safe_state_id: String = _safe_link_id(clean_state_id)

	return {
		"schema": "eralife.world_streaming_manifest",
		"version": CONTRACT_VERSION,
		"state_id": clean_state_id,
		"safe_state_id": safe_state_id,
		"enabled": true,
		"strategy": "core_identity_first",
		"stages": [
			{
				"id": "core_identity",
				"order": 0,
				"load_at_boot": true,
				"stream_key": "core_identity",
				"chunk_budget": 32,
				"contains": ["player", "era", "year", "active_state_id", "runtime_capability_profile", "launch_payload"]
			},
			{
				"id": "regions",
				"order": 10,
				"load_at_boot": false,
				"stream_key": "regions",
				"chunk_budget": 64,
				"contains": ["world_space_tiles", "chunk_sim_chunks", "realm_realms"]
			},
			{
				"id": "factions",
				"order": 20,
				"load_at_boot": false,
				"stream_key": "factions",
				"chunk_budget": 64,
				"contains": ["universal_faction_state", "realm_contract_registry"]
			},
			{
				"id": "people",
				"order": 30,
				"load_at_boot": false,
				"stream_key": "people",
				"chunk_budget": 96,
				"contains": ["npcs", "dormant_npcs", "population_shards"]
			},
			{
				"id": "events",
				"order": 40,
				"load_at_boot": false,
				"stream_key": "events",
				"chunk_budget": 80,
				"contains": ["world_feed", "scenario_history", "world_chronicle"]
			}
		],
		"limits": {
			"boot_core_only": true,
			"visible_npc_soft_cap": 2500,
			"region_stream_radius": 1,
			"event_stream_limit": 80,
			"stream_chunk_budget": 96,
			"background_work_policy": "defer_until_idle"
		},
		"cache_policy": {
			"offline_capable": true,
			"persistent_save": true,
			"cache_namespace": "eralife.worlds.v1",
			"save_persistence_key": "eralife.save.%s" % safe_state_id,
			"service_worker_scope": "/",
			"cache_core_identity_first": true
		},
		"metadata": {
			"built_in": true,
			"backwards_compatible": true,
			"save_persistent": true,
		}
	}


func _deep_merge_dictionary(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		var base_value: Variant = out.get(key)

		if typeof(base_value) == TYPE_DICTIONARY and typeof(patch_value) == TYPE_DICTIONARY:
			out [key] = _deep_merge_dictionary(base_value as Dictionary, patch_value as Dictionary)
		else:
			out [key] = patch_value

	return out


func _safe_link_id(value: String) -> String:
	var out: String = str(value).strip_edges().to_lower()
	out = out.replace(" ", "-")
	out = out.replace("_", "-")
	out = out.replace("/", "-")
	out = out.replace("\\", "-")
	out = out.replace(":", "-")
	out = out.replace("?", "")
	out = out.replace("&", "-")
	out = out.replace("=", "-")

	while out.find("--") >= 0:
		out = out.replace("--", "-")

	out = out.trim_prefix("-")
	out = out.trim_suffix("-")

	if out == "":
		out = "world-%d" % abs(hash(value))

	return out
func ensure_life_identity(options: Dictionary = {}) -> Dictionary:
	_ensure_life_identity_folder()

	var world_id: String = str(options.get("world_id", active_state_id)).strip_edges()
	if world_id == "":
		world_id = active_state_id

	var existing_raw: Variant = options.get("life_identity", {})
	if typeof(existing_raw) != TYPE_DICTIONARY or (existing_raw as Dictionary).is_empty():
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			existing_raw = gs.scenario_state.get("life_identity", {})

	var identity: Dictionary = {}
	if typeof(existing_raw) == TYPE_DICTIONARY and not (existing_raw as Dictionary).is_empty():
		identity = _normalize_life_identity(existing_raw as Dictionary, options)
	else:
		identity = _build_new_life_identity(world_id, options)

	var life_id: String = str(identity.get("life_id", "")).strip_edges()
	if life_id == "":
		identity = _build_new_life_identity(world_id, options)
		life_id = str(identity.get("life_id", "")).strip_edges()

	life_identity_registry [life_id] = identity.duplicate(true)

	var timeline_id: String = str(identity.get("timeline_id", "")).strip_edges()
	if timeline_id != "" and not life_timeline_registry.has(timeline_id):
		life_timeline_registry [timeline_id] = {
			"schema": "eralife.life_timeline",
			"version": LIFE_IDENTITY_VERSION,
			"timeline_id": timeline_id,
			"life_id": life_id,
			"events": [],
			"created_at_ms": int(Time.get_ticks_msec()),
			"updated_at_ms": int(Time.get_ticks_msec())
		}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["life_identity"] = identity.duplicate(true)
		gs.scenario_state ["life_id"] = life_id
		gs.scenario_state ["timeline_id"] = timeline_id
		gs.scenario_state ["life_identity_registry"] = life_identity_registry.duplicate(true)
		gs.scenario_state ["life_timeline_registry"] = life_timeline_registry.duplicate(true)

	_write_life_identity(identity)
	return identity.duplicate(true)


func _build_new_life_identity(
	world_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var safe_world_id: String = _safe_link_id(
		world_id
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var player_name: String = "unknown"
	var player_id: String = ""
	var age: int = 0
	var year: int = 0
	var birth_year: int = 0

	if gs != null:
		year = (
			int(
				gs.year
			)
			if "year" in gs
			else 0
		)

		if gs.player != null:
			player_name = (
				"%s %s"
				% [
					str(
						gs.player.first_name
					),
					str(
						gs.player.last_name
					)
				]
			).strip_edges()
			player_id = (
				str(
					gs.player.get(
						"id"
					)
				)
				if gs.player.has_method(
					"get"
				)
				else ""
			)
			age = int(
				gs.player.age
			)
			birth_year = year - age

	var explicit_seed: String = str(
		options.get(
			"identity_seed",
			""
		)
	).strip_edges()
	var identity_seed_text: String = explicit_seed

	if identity_seed_text == "":
		identity_seed_text = (
			"%s|%s|%s|%d|%d|%d"
			% [
				world_id,
				player_name,
				player_id,
				birth_year,
				now_ms,
				randi()
			]
		)

	var digest: String = (
		identity_seed_text.sha256_text().substr(
			0,
			18
		)
	)

	var life_id: String = str(
		options.get(
			"life_id",
			""
		)
	).strip_edges()

	if life_id == "":
		life_id = (
			"life.%s.%s"
			% [
				safe_world_id,
				digest
			]
		)

	life_id = _safe_life_identifier(
		life_id
	)

	var lineage_id: String = str(
		options.get(
			"lineage_id",
			""
		)
	).strip_edges()

	if lineage_id == "":
		lineage_id = (
			"lineage.%s.%s"
			% [
				safe_world_id,
				digest.substr(
					0,
					12
				)
			]
		)

	lineage_id = _safe_life_identifier(
		lineage_id
	)

	var timeline_id: String = str(
		options.get(
			"timeline_id",
			""
		)
	).strip_edges()

	if timeline_id == "":
		timeline_id = (
			"timeline.%s.main"
			% life_id
		)

	timeline_id = _safe_life_identifier(
		timeline_id
	)

	return {
		"schema": LIFE_IDENTITY_SCHEMA,
		"version": LIFE_IDENTITY_VERSION,
		"life_id": life_id,
		"lineage_id": lineage_id,
		"timeline_id": timeline_id,
		"world_id": world_id,
		"safe_world_id": safe_world_id,
		"canonical": true,
		"player_name": player_name,
		"player_id": player_id,
		"birth_year": birth_year,



		"reality_start_year": year,

		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"parent_life_id": str(
			options.get(
				"parent_life_id",
				""
			)
		).strip_edges(),
		"parent_capsule_id": str(
			options.get(
				"parent_capsule_id",
				""
			)
		).strip_edges(),
		"origin": {
			"source": str(
				options.get(
					"source",
					"runtime"
				)
			).strip_edges(),
			"identity_seed_digest": digest,
			"created_by_capsule": str(
				options.get(
					"created_by_capsule",
					""
				)
			).strip_edges()
		},
		"timeline": {
			"capsule_count": 0,
			"latest_capsule_id": "",
			"latest_age": age,
			"latest_year": year,
			"latest_continuation_kind": "origin"
		}
	}

func _normalize_life_identity(
	raw_identity: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var identity: Dictionary = raw_identity.duplicate(
		true
	)

	var world_id: String = str(
		identity.get(
			"world_id",
			options.get(
				"world_id",
				active_state_id
			)
		)
	).strip_edges()

	if world_id == "":
		world_id = active_state_id

	var safe_world_id: String = _safe_link_id(
		world_id
	)

	var life_id: String = str(
		identity.get(
			"life_id",
			options.get(
				"life_id",
				""
			)
		)
	).strip_edges()

	if life_id == "":
		life_id = (
			"life.%s.%s"
			% [
				safe_world_id,
				str(
					Time.get_ticks_msec()
				).sha256_text().substr(
					0,
					18
				)
			]
		)

	life_id = _safe_life_identifier(
		life_id
	)

	var lineage_id: String = str(
		identity.get(
			"lineage_id",
			options.get(
				"lineage_id",
				""
			)
		)
	).strip_edges()

	if lineage_id == "":
		lineage_id = (
			"lineage.%s.%s"
			% [
				safe_world_id,
				life_id.sha256_text().substr(
					0,
					12
				)
			]
		)

	lineage_id = _safe_life_identifier(
		lineage_id
	)

	var timeline_id: String = str(
		identity.get(
			"timeline_id",
			options.get(
				"timeline_id",
				""
			)
		)
	).strip_edges()

	if timeline_id == "":
		timeline_id = (
			"timeline.%s.main"
			% life_id
		)

	timeline_id = _safe_life_identifier(
		timeline_id
	)

	var fallback_reality_start_year: int = 0

	if gs != null and "year" in gs:
		fallback_reality_start_year = int(
			gs.year
		)

	var reality_start_year: int = int(
		identity.get(
			"reality_start_year",
			options.get(
				"reality_start_year",
				fallback_reality_start_year
			)
		)
	)

	identity ["schema"] = LIFE_IDENTITY_SCHEMA
	identity ["version"] = max(
		1,
		int(
			identity.get(
				"version",
				LIFE_IDENTITY_VERSION
			)
		)
	)
	identity ["life_id"] = life_id
	identity ["lineage_id"] = lineage_id
	identity ["timeline_id"] = timeline_id
	identity ["world_id"] = world_id
	identity ["safe_world_id"] = safe_world_id
	identity ["canonical"] = bool(
		identity.get(
			"canonical",
			true
		)
	)
	identity ["reality_start_year"] = (
		reality_start_year
	)
	identity ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	if typeof(
		identity.get(
			"timeline",
			{}
		)
	) != TYPE_DICTIONARY:
		identity ["timeline"] = {}

	var timeline: Dictionary = identity.get(
		"timeline",
		{}
	)
	timeline ["capsule_count"] = int(
		timeline.get(
			"capsule_count",
			0
		)
	)
	timeline ["latest_capsule_id"] = str(
		timeline.get(
			"latest_capsule_id",
			""
		)
	)
	timeline ["latest_age"] = int(
		timeline.get(
			"latest_age",
			0
		)
	)
	timeline ["latest_year"] = int(
		timeline.get(
			"latest_year",
			0
		)
	)
	timeline ["latest_continuation_kind"] = str(
		timeline.get(
			"latest_continuation_kind",
			"continuation"
		)
	)
	identity ["timeline"] = timeline

	return identity

func _build_capsule_version_id(life_identity: Dictionary, options: Dictionary = {}) -> String:
	var explicit_capsule_id: String = str(options.get("capsule_id", "")).strip_edges()
	if explicit_capsule_id != "":
		return _safe_life_identifier(explicit_capsule_id)

	var life_id: String = str(life_identity.get("life_id", "life")).strip_edges()
	if life_id == "":
		life_id = "life"

	var timeline_raw: Variant = life_identity.get("timeline", {})
	var timeline: Dictionary = timeline_raw if typeof(timeline_raw) == TYPE_DICTIONARY else {}
	var next_index: int = int(timeline.get("capsule_count", 0)) + 1

	var age: int = 0
	var year: int = 0
	if gs != null:
		year = int(gs.year) if "year" in gs else 0
		if gs.player != null:
			age = int(gs.player.age)

	return "%s.capsule_%04d.age_%d.year_%d" % [
		_safe_life_identifier(life_id),
		next_index,
		age,
		year
	]


func record_life_capsule_version(life_identity: Dictionary, capsule: Dictionary, options: Dictionary = {}) -> Dictionary:
	var identity: Dictionary = _normalize_life_identity(life_identity, options)
	var life_id: String = str(identity.get("life_id", "")).strip_edges()
	var timeline_id: String = str(identity.get("timeline_id", "")).strip_edges()
	var capsule_id: String = str(capsule.get("capsule_id", options.get("capsule_id", ""))).strip_edges()

	var age: int = 0
	var year: int = 0
	if gs != null:
		year = int(gs.year) if "year" in gs else 0
		if gs.player != null:
			age = int(gs.player.age)

	var timeline: Dictionary = life_timeline_registry.get(timeline_id, {
		"schema": "eralife.life_timeline",
		"version": LIFE_IDENTITY_VERSION,
		"timeline_id": timeline_id,
		"life_id": life_id,
		"events": [],
		"created_at_ms": int(Time.get_ticks_msec())
	}).duplicate(true)

	var events: Array = timeline.get("events", []) if typeof(timeline.get("events", [])) == TYPE_ARRAY else []
	events.append({
		"type": "capsule_snapshot",
		"capsule_id": capsule_id,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"age": age,
		"year": year,
		"continuation_kind": str(capsule.get("continuation_kind", options.get("continuation_kind", "continuation"))),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	while events.size() > LIFE_TIMELINE_EVENT_LIMIT:
		events.pop_front()

	timeline ["events"] = events
	timeline ["updated_at_ms"] = int(Time.get_ticks_msec())
	life_timeline_registry [timeline_id] = timeline.duplicate(true)

	var identity_timeline: Dictionary = identity.get("timeline", {}) if typeof(identity.get("timeline", {})) == TYPE_DICTIONARY else {}
	identity_timeline ["capsule_count"] = int(identity_timeline.get("capsule_count", 0)) + 1
	identity_timeline ["latest_capsule_id"] = capsule_id
	identity_timeline ["latest_age"] = age
	identity_timeline ["latest_year"] = year
	identity_timeline ["latest_continuation_kind"] = str(capsule.get("continuation_kind", "continuation"))
	identity ["timeline"] = identity_timeline
	identity ["updated_at_ms"] = int(Time.get_ticks_msec())

	life_identity_registry [life_id] = identity.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["life_identity"] = identity.duplicate(true)
		gs.scenario_state ["life_identity_registry"] = life_identity_registry.duplicate(true)
		gs.scenario_state ["life_timeline_registry"] = life_timeline_registry.duplicate(true)

	_write_life_identity(identity)

	return {
		"schema": "eralife.life_capsule_version_report",
		"version": LIFE_IDENTITY_VERSION,
		"success": true,
		"life_id": life_id,
		"timeline_id": timeline_id,
		"capsule_id": capsule_id,
		"event_count": events.size(),
		"recorded_at_ms": int(Time.get_ticks_msec())
	}


func _safe_life_identifier(value: String) -> String:
	var out: String = str(value).strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace("-", "_")
	out = out.replace("/", "_")
	out = out.replace("\\", "_")
	out = out.replace(":", "_")
	out = out.replace("?", "")
	out = out.replace("&", "_")
	out = out.replace("=", "_")
	while out.find("__") >= 0:
		out = out.replace("__", "_")
	out = out.trim_prefix("_")
	out = out.trim_suffix("_")
	if out == "":
		out = "life_%d" % abs(hash(value))
	return out


func _detect_continuation_kind(identity: Dictionary, capsule: Dictionary = {}, options: Dictionary = {}) -> String:
	var explicit_kind: String = str(options.get("continuation_kind", capsule.get("continuation_kind", ""))).strip_edges().to_lower()
	if explicit_kind in ["origin", "continuation", "fork", "import", "rollback"]:
		return explicit_kind

	var incoming_life_id: String = str(identity.get("life_id", capsule.get("life_id", ""))).strip_edges()
	var current_life_id: String = ""
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		current_life_id = str(gs.scenario_state.get("life_id", "")).strip_edges()

	if current_life_id != "" and incoming_life_id != "" and current_life_id != incoming_life_id:
		return "fork"

	return "continuation"


func _ensure_life_identity_folder() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIFE_IDENTITY_FOLDER))


func _life_identity_path(life_id: String) -> String:
	var safe_id: String = _safe_life_identifier(life_id)
	if safe_id == "":
		safe_id = "life"
	return "%s/%s.json" % [LIFE_IDENTITY_FOLDER, safe_id]


func _write_life_identity(identity: Dictionary) -> void:
	var life_id: String = str(identity.get("life_id", "")).strip_edges()
	if life_id == "":
		return

	_ensure_life_identity_folder()

	var path: String = _life_identity_path(life_id)
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return

	f.store_string(JSON.stringify(identity, "\t"))
	f.close()


func _runtime_web_origin() -> String:
	if not OS.has_feature("web"):
		return ""
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""

	var origin_raw: Variant = JavaScriptBridge.eval("window.location.origin || ''", true)
	return str(origin_raw).strip_edges().trim_suffix("/")


func _resolve_share_url_origin(options: Dictionary = {}) -> String:
	var explicit_origin: String = str(options.get("origin", options.get("url_origin", ""))).strip_edges().trim_suffix("/")
	if explicit_origin != "":
		return explicit_origin

	var web_origin: String = _runtime_web_origin()
	if web_origin != "":
		return web_origin

	var host: String = str(options.get("host", "")).strip_edges().trim_suffix("/")
	if host == "":
		host = "eralife.app"

	if host.begins_with("http://") or host.begins_with("https://"):
		return host

	return "https://%s" % host


func _host_from_origin(origin: String) -> String:
	var clean: String = str(origin).strip_edges()
	clean = clean.trim_prefix("https://")
	clean = clean.trim_prefix("http://")
	var slash_index: int = clean.find("/")
	if slash_index >= 0:
		clean = clean.substr(0, slash_index)
	return clean


func _decode_url_capsule_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}

	var decoded: Dictionary = BinarySaveEngine.decode(bytes)
	if not decoded.is_empty():
		return decoded

	var compression_modes:= [
		FileAccess.COMPRESSION_ZSTD,
		FileAccess.COMPRESSION_GZIP,
		FileAccess.COMPRESSION_DEFLATE,
		FileAccess.COMPRESSION_FASTLZ
	]

	for raw_mode in compression_modes:
		var expanded: PackedByteArray = bytes.decompress_dynamic(URL_CAPSULE_DECODE_MAX_BYTES, int(raw_mode))
		if expanded.is_empty():
			continue

		decoded = BinarySaveEngine.decode(expanded)
		if not decoded.is_empty():
			return decoded

	return {}
func build_url_capsule(world_id: String = "", options: Dictionary = {}) -> Dictionary:
	var clean_world_id: String = str(world_id).strip_edges()
	if clean_world_id == "":
		clean_world_id = active_state_id

	var max_inline_chars: int = max(512, int(options.get("max_inline_chars", URL_CAPSULE_INLINE_MAX_CHARS)))
	var allow_local_fallback: bool = bool(options.get("allow_local_capsule_fallback", false))
	var preferred_share_mode: String = str(options.get("share_mode", "native_protocol")).strip_edges().to_lower()
	if preferred_share_mode == "":
		preferred_share_mode = "native_protocol"

	var capsule: Dictionary = build_portable_save_capsule(clean_world_id, options)
	var capsule_id: String = str(capsule.get("capsule_id", "%s.%d" % [_safe_link_id(clean_world_id), int(Time.get_ticks_msec())])).strip_edges()
	if capsule_id == "":
		capsule_id = "%s.%d" % [_safe_link_id(clean_world_id), int(Time.get_ticks_msec())]

	var links: Dictionary = build_tap_to_play_links(clean_world_id, options)
	var self_host_mode: Dictionary = links.get("launch_payload", {}).get("self_host", {}) if typeof(links.get("launch_payload", {})) == TYPE_DICTIONARY else {}

	var web_base_url: String = str(links.get("web", "")).strip_edges()
	if web_base_url == "":
		var url_origin: String = _resolve_share_url_origin(options)
		web_base_url = "%s/play/%s" % [url_origin, _safe_link_id(clean_world_id)]

	var native_base_url: String = str(links.get("native_play", links.get("native", ""))).strip_edges()
	if native_base_url == "":
		native_base_url = "%s://play" % str(options.get("scheme", "eralife")).strip_edges()

	var capsule_bytes: PackedByteArray = BinarySaveEngine.encode(capsule)
	var compressed_bytes: PackedByteArray = capsule_bytes.compress(FileAccess.COMPRESSION_ZSTD)
	var bytes_for_url: PackedByteArray = compressed_bytes if not compressed_bytes.is_empty() else capsule_bytes
	var token: String = _encode_url_capsule_token(bytes_for_url)

	var web_inline_url: String = "%s?capsule=%s" % [web_base_url, token.uri_encode()]
	var native_inline_url: String = "%s?capsule=%s" % [native_base_url, token.uri_encode()]

	var mode: String = "inline"
	var web_share_url: String = web_inline_url
	var native_share_url: String = native_inline_url
	var share_url: String = native_inline_url

	var stored_local: bool = false
	var local_path: String = ""
	var warnings: Array = []

	if token.length() > max_inline_chars:
		if allow_local_fallback:
			mode = "local_capsule_id"
			local_path = _write_local_url_capsule(capsule_id, capsule_bytes)
			stored_local = local_path != ""
			web_share_url = "%s?capsule_id=%s&storage=local" % [web_base_url, capsule_id.uri_encode()]
			native_share_url = "%s?capsule_id=%s&storage=local" % [native_base_url, capsule_id.uri_encode()]
			warnings.append("Capsule exceeded inline target and was stored locally. This link is same-device only.")
		else:
			mode = "inline_large"
			web_share_url = web_inline_url
			native_share_url = native_inline_url
			warnings.append("Capsule exceeded inline target, but local fallback is disabled so the link remains cross-device exact if the browser accepts the URL length.")

	share_url = native_share_url if preferred_share_mode != "web" else web_share_url

	var preview: Dictionary = capsule.get("preview", {}).duplicate(true) if typeof(capsule.get("preview", {})) == TYPE_DICTIONARY else {}
	var hybrid_contract: Dictionary = _build_hybrid_tap_to_play_contract(
		capsule,
		links,
		preview,
		token if mode != "local_capsule_id" else "",
		native_share_url,
		web_share_url,
		mode,
		warnings,
		options
	)

	var report:= {
		"schema": URL_CAPSULE_SCHEMA,
		"version": URL_CAPSULE_VERSION,
		"success": true,
		"mode": mode,

		"world_id": clean_world_id,
		"safe_world_id": _safe_link_id(clean_world_id),
		"life_id": str(capsule.get("life_id", "")),
		"timeline_id": str(capsule.get("timeline_id", "")),
		"capsule_id": capsule_id,

		"share_url": share_url,
		"native_url": native_share_url,
		"web_url": web_share_url,
		"fallback_url": web_share_url,

		"inline_url": web_inline_url if mode != "local_capsule_id" else "",
		"inline_native_url": native_inline_url if mode != "local_capsule_id" else "",

		"links": links.duplicate(true),
		"self_host_mode": self_host_mode.duplicate(true),

		"encoded_capsule": token if mode != "local_capsule_id" else "",
		"encoded_length": token.length(),
		"raw_byte_length": capsule_bytes.size(),
		"url_byte_length": bytes_for_url.size(),
		"compressed": bytes_for_url.size() < capsule_bytes.size(),
		"max_inline_chars": max_inline_chars,

		"stored_local": stored_local,
		"local_path": local_path,
		"cross_device_exact": mode != "local_capsule_id",
		"large_capsule_transfer_policy": "inline_compressed_first_local_only_when_explicit",

		"preview": preview.duplicate(true),
		"fallback_contract": hybrid_contract.get("fallback_contract", {}).duplicate(true) if typeof(hybrid_contract.get("fallback_contract", {})) == TYPE_DICTIONARY else {},
		"hybrid_contract": hybrid_contract.duplicate(true),

		"life_summary": capsule.get("life_summary", {}).duplicate(true) if typeof(capsule.get("life_summary", {})) == TYPE_DICTIONARY else {},
		"warnings": warnings,
		"built_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["latest_url_capsule_report"] = report.duplicate(true)
		gs.scenario_state ["latest_reality_share_url"] = share_url
		gs.scenario_state ["latest_hybrid_tap_to_play_contract"] = hybrid_contract.duplicate(true)

	return report

func _build_portable_capsule_preview(core_life_snapshot: Dictionary, life_summary: Dictionary, player_contract_slice: Dictionary, world_id: String, options: Dictionary = {}) -> Dictionary:
	var preview_name: String = ""
	var preview_age: int = 0
	var preview_world: String = str(options.get("world_label", world_id)).strip_edges()
	var preview_powers: Array = _extract_power_profile_ids_from_contract_slice(player_contract_slice)

	if typeof(life_summary) == TYPE_DICTIONARY:
		if preview_name == "":
			preview_name = str(life_summary.get("name", life_summary.get("display_name", ""))).strip_edges()
		if preview_age <= 0:
			preview_age = int(life_summary.get("age", 0))
		if preview_world == "" or preview_world == world_id:
			preview_world = str(life_summary.get("world", life_summary.get("world_label", preview_world))).strip_edges()

	if typeof(core_life_snapshot) == TYPE_DICTIONARY:
		if preview_name == "":
			preview_name = str(core_life_snapshot.get("name", core_life_snapshot.get("display_name", ""))).strip_edges()
		if preview_age <= 0:
			preview_age = int(core_life_snapshot.get("age", core_life_snapshot.get("player_age", 0)))
		if preview_world == "" or preview_world == world_id:
			preview_world = str(core_life_snapshot.get("world", core_life_snapshot.get("world_label", preview_world))).strip_edges()

	if preview_name == "" and gs != null and gs.player != null:
		preview_name = ("%s %s" % [str(gs.player.first_name), str(gs.player.last_name)]).strip_edges()
	if preview_age <= 0 and gs != null and gs.player != null:
		preview_age = int(gs.player.age)
	if preview_world == "":
		preview_world = world_id

	return {
		"name": preview_name,
		"age": preview_age,
		"world": preview_world,
		"powers": preview_powers.duplicate(true)
	}


func _extract_power_profile_ids_from_contract_slice(player_contract_slice: Dictionary) -> Array:
	var out: Array = []
	if typeof(player_contract_slice) != TYPE_DICTIONARY or player_contract_slice.is_empty():
		return out

	var profiles_raw: Variant = player_contract_slice.get("power_profiles", {})
	if typeof(profiles_raw) != TYPE_DICTIONARY:
		return out

	var profiles: Dictionary = profiles_raw
	for raw_key in profiles.keys():
		var clean_id: String = str(raw_key).strip_edges().to_lower()
		if clean_id == "":
			continue

		var row_raw: Variant = profiles.get(raw_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_raw

		var include_profile: bool = false

		if row.has("unlocked"):
			include_profile = bool(row.get("unlocked", false))
		elif row.has("is_wizard"):
			include_profile = bool(row.get("is_wizard", false))
		elif row.has("is_vampire"):
			include_profile = bool(row.get("is_vampire", false))
		elif row.has("type"):
			include_profile = str(row.get("type", "")).strip_edges().to_lower() not in ["", "none"]
		else:
			include_profile = not row.is_empty()

		if include_profile and not out.has(clean_id):
			out.append(clean_id)

	return out


func _build_portable_capsule_fallback_contract(world_id: String, life_identity: Dictionary, preview: Dictionary, options: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.tap_to_play_fallback_contract",
		"version": CONTRACT_VERSION,
		"world_id": str(world_id).strip_edges(),
		"life_id": str(life_identity.get("life_id", "")),
		"timeline_id": str(life_identity.get("timeline_id", "")),
		"lineage_id": str(life_identity.get("lineage_id", "")),
		"preview": preview.duplicate(true),
		"import_strategy": "portable_save_capsule",
		"expected_capsule_schema": "eralife.portable_save_capsule",
		"fallback_host": str(options.get("host", "eralife.app")),
		"import_methods": [
			"import_tap_to_play_launch",
			"import_url_capsule",
			"import_portable_save_capsule"
		]
	}


func _build_hybrid_tap_to_play_contract(capsule: Dictionary, links: Dictionary, preview: Dictionary, encoded_capsule: String, native_url: String, web_url: String, mode: String, warnings: Array, options: Dictionary = {}) -> Dictionary:
	var fallback_contract: Dictionary = capsule.get("fallback_contract", {}).duplicate(true) if typeof(capsule.get("fallback_contract", {})) == TYPE_DICTIONARY else {}
	fallback_contract ["capsule"] = capsule.duplicate(true)
	fallback_contract ["native_url"] = native_url
	fallback_contract ["web_url"] = web_url
	fallback_contract ["mode"] = mode

	var preferred_share_mode: String = str(options.get("share_mode", "native_protocol")).strip_edges().to_lower()
	if preferred_share_mode == "":
		preferred_share_mode = "native_protocol"

	return {
		"schema": "eralife.hybrid_tap_to_play_contract",
		"version": CONTRACT_VERSION,
		"mode": "hybrid",
		"transport_mode": str(mode),
		"capsule_id": str(capsule.get("capsule_id", "")),
		"world_id": str(capsule.get("world_id", "")),
		"life_id": str(capsule.get("life_id", "")),
		"timeline_id": str(capsule.get("timeline_id", "")),
		"preview": preview.duplicate(true),
		"encoded_capsule": encoded_capsule,
		"native_url": native_url,
		"fallback_url": web_url,
		"share_url": native_url if preferred_share_mode != "web" else web_url,
		"links": links.duplicate(true),
		"cross_device_exact": str(mode) != "local_capsule_id",
		"fallback_contract": fallback_contract.duplicate(true),
		"warnings": warnings.duplicate(true),
		"built_at_ms": int(Time.get_ticks_msec())
	}


func import_tap_to_play_launch(payload_or_url: Variant, options: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.tap_to_play_launch_import_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"mode": "",
		"import": {},
		"warnings": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(payload_or_url) == TYPE_STRING:
		var text: String = str(payload_or_url).strip_edges()
		if text == "":
			report ["warnings"].append("Tap-to-play launch payload was empty.")
			return report

		var capsule_id: String = _query_value_from_url(text, "capsule_id")
		if capsule_id != "":
			var local_report: Dictionary = import_local_url_capsule(capsule_id, options)
			report ["mode"] = "local_capsule_id"
			report ["import"] = local_report.duplicate(true)
			report ["success"] = bool(local_report.get("success", false))
			return report

		var url_report: Dictionary = import_url_capsule(text, options)
		report ["mode"] = "url_capsule"
		report ["import"] = url_report.duplicate(true)
		report ["success"] = bool(url_report.get("success", false))
		return report

	if typeof(payload_or_url) != TYPE_DICTIONARY:
		report ["warnings"].append("Tap-to-play launch payload must be a String or Dictionary.")
		return report

	var payload: Dictionary = payload_or_url
	var schema: String = str(payload.get("schema", "")).strip_edges()

	if schema == "eralife.hybrid_tap_to_play_contract":
		var encoded_capsule: String = str(payload.get("encoded_capsule", "")).strip_edges()
		if encoded_capsule != "":
			var url_report: Dictionary = import_url_capsule(encoded_capsule, options)
			report ["mode"] = "hybrid_encoded"
			report ["import"] = url_report.duplicate(true)
			report ["success"] = bool(url_report.get("success", false))
			return report

		var fallback_raw: Variant = payload.get("fallback_contract", {})
		if typeof(fallback_raw) == TYPE_DICTIONARY:
			var fallback_contract: Dictionary = fallback_raw
			var capsule_raw: Variant = fallback_contract.get("capsule", payload.get("capsule", {}))
			if typeof(capsule_raw) == TYPE_DICTIONARY and not (capsule_raw as Dictionary).is_empty():
				var capsule_report: Dictionary = import_portable_save_capsule(capsule_raw as Dictionary, options)
				report ["mode"] = "hybrid_fallback_contract"
				report ["import"] = capsule_report.duplicate(true)
				report ["success"] = bool(capsule_report.get("success", false))
				return report

		report ["warnings"].append("Hybrid tap-to-play launch did not contain an importable capsule.")
		return report

	if schema == URL_CAPSULE_SCHEMA:
		var encoded: String = str(payload.get("encoded_capsule", "")).strip_edges()
		var source_value: String = encoded if encoded != "" else str(payload.get("share_url", "")).strip_edges()
		var url_report: Dictionary = import_url_capsule(source_value, options)
		report ["mode"] = "url_capsule_contract"
		report ["import"] = url_report.duplicate(true)
		report ["success"] = bool(url_report.get("success", false))
		return report

	if schema in ["eralife.portable_save_capsule", "eralife.portable_world_package"]:
		var capsule_report: Dictionary = import_portable_save_capsule(payload, options)
		report ["mode"] = "portable_save_capsule"
		report ["import"] = capsule_report.duplicate(true)
		report ["success"] = bool(capsule_report.get("success", false))
		return report

	report ["warnings"].append("Unsupported tap-to-play launch schema '%s'." % schema)
	return report
func decode_url_capsule(encoded_capsule_or_url: String, _options: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.url_capsule_decode_report",
		"version": URL_CAPSULE_VERSION,
		"success": false,
		"capsule": {},
		"warnings": [],
		"decoded_at_ms": int(Time.get_ticks_msec())
	}

	var token: String = _extract_url_capsule_token(encoded_capsule_or_url)
	if token == "":
		report ["warnings"].append("No URL capsule token was found.")
		return report

	var capsule_bytes: PackedByteArray = _decode_url_capsule_token(token)
	if capsule_bytes.is_empty():
		report ["warnings"].append("URL capsule token could not be decoded.")
		return report

	var capsule: Dictionary = _decode_url_capsule_bytes(capsule_bytes)
	if capsule.is_empty():
		report ["warnings"].append("URL capsule decoded, but no capsule dictionary was recovered.")
		return report

	report ["success"] = true
	report ["capsule"] = capsule.duplicate(true)
	return report


func import_url_capsule(encoded_capsule_or_url: String, options: Dictionary = {}) -> Dictionary:
	var decode_report: Dictionary = decode_url_capsule(encoded_capsule_or_url, options)
	if not bool(decode_report.get("success", false)):
		return {
			"schema": "eralife.url_capsule_import_report",
			"version": URL_CAPSULE_VERSION,
			"success": false,
			"decode": decode_report.duplicate(true),
			"import": {},
			"warnings": decode_report.get("warnings", []).duplicate(true) if typeof(decode_report.get("warnings", [])) == TYPE_ARRAY else []
		}

	var capsule_raw: Variant = decode_report.get("capsule", {})
	var capsule: Dictionary = capsule_raw if typeof(capsule_raw) == TYPE_DICTIONARY else {}
	var import_report: Dictionary = import_portable_save_capsule(capsule, options)

	return {
		"schema": "eralife.url_capsule_import_report",
		"version": URL_CAPSULE_VERSION,
		"success": bool(import_report.get("success", false)),
		"decode": decode_report.duplicate(true),
		"import": import_report.duplicate(true),
		"warnings": import_report.get("warnings", []).duplicate(true) if typeof(import_report.get("warnings", [])) == TYPE_ARRAY else []
	}


func import_local_url_capsule(capsule_id: String, options: Dictionary = {}) -> Dictionary:
	var clean_capsule_id: String = str(capsule_id).strip_edges()
	var report:= {
		"schema": "eralife.local_url_capsule_import_report",
		"version": URL_CAPSULE_VERSION,
		"success": false,
		"capsule_id": clean_capsule_id,
		"import": {},
		"warnings": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if clean_capsule_id == "":
		report ["warnings"].append("Missing local capsule id.")
		return report

	var local_path: String = _local_url_capsule_path(clean_capsule_id)
	if not FileAccess.file_exists(local_path):
		report ["warnings"].append("Local capsule '%s' was not found on this device." % clean_capsule_id)
		return report

	var f:= FileAccess.open(local_path, FileAccess.READ)
	if f == null:
		report ["warnings"].append("Local capsule '%s' could not be opened." % clean_capsule_id)
		return report

	var capsule_bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var capsule: Dictionary = BinarySaveEngine.decode(capsule_bytes)
	if capsule.is_empty():
		report ["warnings"].append("Local capsule '%s' could not be decoded." % clean_capsule_id)
		return report

	var import_report: Dictionary = import_portable_save_capsule(capsule, options)
	report ["import"] = import_report.duplicate(true)
	report ["success"] = bool(import_report.get("success", false))
	return report


func _build_core_life_snapshot(options: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}

	_ensure_url_capsule_folder()

	var snapshot_path: String = "%s/core_life_snapshot_%d.bin" % [URL_CAPSULE_LOCAL_FOLDER, int(Time.get_ticks_msec())]
	gs.save_game(snapshot_path, {
		"skip_memory_compaction": bool(options.get("skip_memory_compaction", true)),
		"skip_world_feed_normalization": bool(options.get("skip_world_feed_normalization", false)),
		"skip_prune": bool(options.get("skip_prune", true)),
		"skip_archive": bool(options.get("skip_archive", true))
	})

	if not FileAccess.file_exists(snapshot_path):
		return {}

	var f:= FileAccess.open(snapshot_path, FileAccess.READ)
	if f == null:
		return {}

	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	_remove_user_file(snapshot_path)

	var decoded: Dictionary = BinarySaveEngine.decode(bytes)
	if decoded.is_empty():
		return {}

	return _make_binary_safe(decoded)


func _restore_core_life_snapshot(snapshot: Dictionary, context: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.core_life_snapshot_restore_report",
		"version": URL_CAPSULE_VERSION,
		"success": false,
		"context": context.duplicate(true),
		"path": "",
		"warnings": [],
		"restored_at_ms": int(Time.get_ticks_msec())
	}

	if gs == null:
		report ["warnings"].append("Missing GameState; cannot restore core life snapshot.")
		return report

	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		report ["warnings"].append("Core life snapshot is empty.")
		return report

	_ensure_url_capsule_folder()

	var restore_path: String = "%s/core_life_restore_%d.bin" % [URL_CAPSULE_LOCAL_FOLDER, int(Time.get_ticks_msec())]
	var bytes: PackedByteArray = BinarySaveEngine.encode(snapshot)

	var f:= FileAccess.open(restore_path, FileAccess.WRITE)
	if f == null:
		report ["warnings"].append("Could not create temporary restore file.")
		return report

	f.store_buffer(bytes)
	f.close()

	report ["path"] = restore_path

	gs.load_game(restore_path)
	_remove_user_file(restore_path)

	gs.game_state_contract_engine = self
	self.gs = gs

	report ["success"] = true
	return report


func _build_life_capsule_summary(snapshot: Dictionary = {}) -> Dictionary:
	var summary:= {
		"player_name": "",
		"age": 0,
		"year": 0,
		"era_name": "",
		"npc_count": 0,
		"world_feed_count": 0
	}

	if typeof(snapshot) == TYPE_DICTIONARY and not snapshot.is_empty():
		summary ["player_name"] = str(snapshot.get("player_name", ""))
		summary ["age"] = int(snapshot.get("last_saved_age", 0))
		summary ["year"] = int(snapshot.get("year", 0))
		summary ["era_name"] = str(snapshot.get("era_name", ""))
		summary ["npc_count"] = int(snapshot.get("npcs", []).size()) if typeof(snapshot.get("npcs", [])) == TYPE_ARRAY else 0
		summary ["world_feed_count"] = int(snapshot.get("world_feed", []).size()) if typeof(snapshot.get("world_feed", [])) == TYPE_ARRAY else 0

	if gs != null and gs.player != null:
		summary ["player_name"] = ("%s %s" % [gs.player.first_name, gs.player.last_name]).strip_edges()
		summary ["age"] = int(gs.player.age)
		summary ["year"] = int(gs.year)
		summary ["era_name"] = str(gs.era.name) if gs.era != null else str(summary.get("era_name", ""))

	return summary


func _encode_url_capsule_token(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""

	var token: String = Marshalls.raw_to_base64(bytes)
	token = token.replace("+", "-")
	token = token.replace("/", "_")
	token = token.replace("=", "")
	return "%s%s" % [URL_CAPSULE_PREFIX, token]


func _decode_url_capsule_token(token: String) -> PackedByteArray:
	var clean: String = str(token).strip_edges()
	clean = clean.uri_decode()

	if clean.begins_with(URL_CAPSULE_PREFIX):
		clean = clean.trim_prefix(URL_CAPSULE_PREFIX)

	clean = clean.replace("-", "+")
	clean = clean.replace("_", "/")

	while clean.length() % 4 != 0:
		clean += "="

	return Marshalls.base64_to_raw(clean)


func _extract_url_capsule_token(value: String) -> String:
	var clean: String = str(value).strip_edges()
	if clean == "":
		return ""

	var query_capsule: String = _query_value_from_url(clean, "capsule")
	if query_capsule != "":
		return query_capsule

	if clean.begins_with(URL_CAPSULE_PREFIX):
		return clean

	return clean.uri_decode()


func _query_value_from_url(url: String, key: String) -> String:
	var clean_url: String = str(url).strip_edges()
	if clean_url == "":
		return ""

	var sections: Array = []

	var query_start: int = clean_url.find("?")
	if query_start >= 0:
		var query: String = clean_url.substr(query_start + 1)
		var hash_start: int = query.find("#")
		if hash_start >= 0:
			query = query.substr(0, hash_start)
		sections.append(query)

	var hash_index: int = clean_url.find("#")
	if hash_index >= 0:
		var hash_query: String = clean_url.substr(hash_index + 1)
		if hash_query.begins_with("?"):
			hash_query = hash_query.substr(1)
		sections.append(hash_query)

	for section_raw in sections:
		var section: String = str(section_raw)
		for raw_part in section.split("&", false):
			var part: String = str(raw_part)
			var eq_index: int = part.find("=")
			var raw_key: String = part if eq_index < 0 else part.substr(0, eq_index)
			var raw_value: String = "" if eq_index < 0 else part.substr(eq_index + 1)

			if raw_key.uri_decode() == key:
				return raw_value.uri_decode()

	return ""


func _ensure_url_capsule_folder() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(URL_CAPSULE_LOCAL_FOLDER))


func _local_url_capsule_path(capsule_id: String) -> String:
	var safe_id: String = _safe_link_id(capsule_id)
	if safe_id == "":
		safe_id = "capsule"
	return "%s/%s.bin" % [URL_CAPSULE_LOCAL_FOLDER, safe_id]


func _write_local_url_capsule(capsule_id: String, bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""

	_ensure_url_capsule_folder()

	var path: String = _local_url_capsule_path(capsule_id)
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""

	f.store_buffer(bytes)
	f.close()
	return path


func _remove_user_file(path: String) -> void:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "":
		return
	if not FileAccess.file_exists(clean_path):
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(clean_path))

func load_external_contracts() -> Dictionary:
	ensure_pack_folders()

	var report:= {
		"schema": "eralife.game_state_contract_load_report",
		"version": CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"loaded_at_ms": int(Time.get_ticks_msec())
	}

	for file_path in _json_files_in_folder(GAME_STATE_PACK_FOLDER):
		var load_report: Dictionary = load_contract_file(file_path, false)
		if bool(load_report.get("success", false)):
			report ["loaded"].append(load_report)
		else:
			report ["failed"].append(load_report)

	return report


func hot_reload_external_contracts(force: bool = false) -> Dictionary:
	if not hot_reload_enabled and not force:
		return {
			"schema": "eralife.game_state_contract_hot_reload_report",
			"version": CONTRACT_VERSION,
			"changed": false,
			"reloaded": [],
			"failed": []
		}

	ensure_pack_folders()

	var changed_paths: Array = []
	for file_path in _json_files_in_folder(GAME_STATE_PACK_FOLDER):
		var mtime: int = int(FileAccess.get_modified_time(file_path))
		if force or int(pack_file_mtimes.get(file_path, -1)) != mtime:
			changed_paths.append(file_path)

	var report:= {
		"schema": "eralife.game_state_contract_hot_reload_report",
		"version": CONTRACT_VERSION,
		"hot_reload_enabled": hot_reload_enabled,
		"changed": not changed_paths.is_empty(),
		"reloaded": [],
		"failed": [],
		"checked_at_ms": int(Time.get_ticks_msec())
	}

	if changed_paths.is_empty():
		return report

	for file_path in changed_paths:
		var load_report: Dictionary = load_contract_file(file_path, true)
		if bool(load_report.get("success", false)):
			report ["reloaded"].append(load_report)
		else:
			report ["failed"].append(load_report)

	refresh_runtime_registry()
	return report


func load_contract_file(path: String, replace_existing: bool = false) -> Dictionary:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "":
		return _contract_failure(clean_path, "Missing GameState contract path.")

	if not FileAccess.file_exists(clean_path):
		return _contract_failure(clean_path, "GameState contract file does not exist.")

	var f:= FileAccess.open(clean_path, FileAccess.READ)
	if f == null:
		return _contract_failure(clean_path, "Could not open GameState contract file.")

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _contract_failure(clean_path, "GameState contract JSON root must be a Dictionary.")

	var normalized: Dictionary = normalize_contract(parsed as Dictionary, clean_path)
	var validation: Dictionary = normalized.get("validation", {})
	if not bool(validation.get("valid", false)):
		validation_reports [clean_path] = validation.duplicate(true)
		return {
			"success": false,
			"path": clean_path,
			"state_id": str(normalized.get("state_id", clean_path)),
			"validation": validation
		}

	var state_id: String = str(normalized.get("state_id", clean_path)).strip_edges()
	if replace_existing and contract_registry.has(state_id):
		contract_registry.erase(state_id)

	contract_registry [state_id] = normalized.duplicate(true)
	pack_file_mtimes [clean_path] = int(FileAccess.get_modified_time(clean_path))
	validation_reports [state_id] = validation.duplicate(true)
	_ingest_contract(normalized)

	return {
		"success": true,
		"path": clean_path,
		"state_id": state_id,
		"validation": validation
	}


func load_contract_from_dictionary(contract: Dictionary, source_label: String = "runtime_game_state_contract") -> Dictionary:
	var normalized: Dictionary = normalize_contract(contract, source_label)
	var validation: Dictionary = normalized.get("validation", {})

	if not bool(validation.get("valid", false)):
		validation_reports [source_label] = validation.duplicate(true)
		return {
			"success": false,
			"path": source_label,
			"state_id": str(normalized.get("state_id", source_label)),
			"validation": validation
		}

	var state_id: String = str(normalized.get("state_id", source_label)).strip_edges()
	contract_registry [state_id] = normalized.duplicate(true)
	validation_reports [state_id] = validation.duplicate(true)
	_ingest_contract(normalized)

	return {
		"success": true,
		"path": source_label,
		"state_id": state_id,
		"validation": validation
	}


func normalize_contract(contract: Dictionary, source_path: String = "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var state_id: String = str(contract.get("state_id", contract.get("id", ""))).strip_edges()
	if state_id == "":
		state_id = _stable_id_from_path(source_path)
		warnings.append("Missing state_id. Applied stable id '%s'." % state_id)

	var contract_version: int = max(1, int(contract.get("version", CONTRACT_VERSION)))
	if contract_version > CONTRACT_VERSION:
		warnings.append("Contract '%s' was authored for version %d. Runtime supports %d. Unknown fields will be preserved but ignored." % [state_id, contract_version, CONTRACT_VERSION])

	var engines: Array = _safe_dictionary_array(contract.get("engines", []))
	var save_slices: Array = _safe_dictionary_array(contract.get("save_slices", contract.get("saves", [])))
	var runtime_phases: Array = _safe_dictionary_array(contract.get("runtime_phases", []))
	var event_subscriptions: Array = _safe_dictionary_array(contract.get("event_subscriptions", contract.get("events", [])))
	var event_bus_contracts: Array = _safe_event_bus_contract_array(contract.get("event_bus_contracts", contract.get("event_bus", [])))
	var meta_contracts: Array = _safe_meta_contract_array(contract.get("meta_contracts", contract.get("contract_meta", contract.get("meta", []))))
	var hydration_rules: Array = _safe_dictionary_array(contract.get("hydration_rules", contract.get("hydration", [])))

	var capability_profiles_raw: Variant = contract.get("runtime_capability_profiles", contract.get("device_capability_profiles", {}))
	var adaptive_resolution_raw: Variant = contract.get("adaptive_resolution_rules", contract.get("contract_adaptation_rules", []))
	var streaming_manifest_raw: Variant = contract.get("world_streaming_manifest", contract.get("streaming_manifest", {}))
	var launch_links_raw: Variant = contract.get("launch_links", contract.get("tap_to_play_links", {}))

	var has_capability_profiles: bool = false
	if typeof(capability_profiles_raw) == TYPE_DICTIONARY:
		has_capability_profiles = not (capability_profiles_raw as Dictionary).is_empty()
	elif typeof(capability_profiles_raw) == TYPE_ARRAY:
		has_capability_profiles = not (capability_profiles_raw as Array).is_empty()

	var has_adaptive_resolution_rules: bool = false
	if typeof(adaptive_resolution_raw) == TYPE_DICTIONARY:
		has_adaptive_resolution_rules = not (adaptive_resolution_raw as Dictionary).is_empty()
	elif typeof(adaptive_resolution_raw) == TYPE_ARRAY:
		has_adaptive_resolution_rules = not (adaptive_resolution_raw as Array).is_empty()

	var has_streaming_manifest: bool = false
	if typeof(streaming_manifest_raw) == TYPE_DICTIONARY:
		has_streaming_manifest = not (streaming_manifest_raw as Dictionary).is_empty()

	var has_launch_links: bool = false
	if typeof(launch_links_raw) == TYPE_DICTIONARY:
		has_launch_links = not (launch_links_raw as Dictionary).is_empty()

	var runtime_capability_profiles: Dictionary = _normalize_runtime_capability_profiles(capability_profiles_raw, state_id)
	var adaptive_resolution_rules: Array = _normalize_adaptive_resolution_rules(adaptive_resolution_raw, state_id)
	var normalized_streaming_manifest: Dictionary = _normalize_world_streaming_manifest(streaming_manifest_raw, state_id)
	var normalized_launch_links: Dictionary = _normalize_launch_links(launch_links_raw, state_id)

	if engines.is_empty() and save_slices.is_empty() and runtime_phases.is_empty() and event_subscriptions.is_empty() and event_bus_contracts.is_empty() and meta_contracts.is_empty() and hydration_rules.is_empty() and not has_capability_profiles and not has_adaptive_resolution_rules and not has_streaming_manifest and not has_launch_links:
		errors.append("GameState contract has no supported kernel sections.")

	var normalized_engines: Array = []
	var seen_engines: Dictionary = {}
	for raw_engine in engines:
		var engine: Dictionary = normalize_engine_contract(raw_engine, state_id)
		var engine_id: String = str(engine.get("id", "")).strip_edges()
		if engine_id == "":
			warnings.append("Skipped engine contract without id.")
			continue
		if seen_engines.has(engine_id):
			warnings.append("Duplicate engine '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [engine_id, state_id])
		seen_engines [engine_id] = true
		normalized_engines.append(engine)

	var normalized_save_slices: Array = []
	var seen_slices: Dictionary = {}
	for raw_slice in save_slices:
		var save_slice: Dictionary = normalize_save_slice_contract(raw_slice, state_id)
		var slice_id: String = str(save_slice.get("id", "")).strip_edges()
		if slice_id == "":
			warnings.append("Skipped save slice without id.")
			continue
		if seen_slices.has(slice_id):
			warnings.append("Duplicate save slice '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [slice_id, state_id])
		seen_slices [slice_id] = true
		normalized_save_slices.append(save_slice)

	var normalized_runtime_phases: Array = []
	var seen_phases: Dictionary = {}
	if runtime_phases.is_empty():
		for phase_name in DEFAULT_RUNTIME_PHASES:
			normalized_runtime_phases.append(normalize_runtime_phase_contract({
				"id": phase_name,
				"enabled": true,
				"order": normalized_runtime_phases.size(),
				"budget_ms": DEFAULT_PHASE_BUDGET_MS,
				"hard_budget_ms": DEFAULT_HARD_PHASE_BUDGET_MS
			}, state_id, normalized_runtime_phases.size()))
	else:
		for raw_phase in runtime_phases:
			var phase: Dictionary = normalize_runtime_phase_contract(raw_phase, state_id, normalized_runtime_phases.size())
			var phase_id: String = str(phase.get("id", "")).strip_edges()
			if phase_id == "":
				warnings.append("Skipped runtime phase without id.")
				continue
			if seen_phases.has(phase_id):
				warnings.append("Duplicate runtime phase '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [phase_id, state_id])
			seen_phases [phase_id] = true
			normalized_runtime_phases.append(phase)

	var normalized_event_subscriptions: Array = []
	var seen_subs: Dictionary = {}
	for raw_sub in event_subscriptions:
		var sub: Dictionary = normalize_event_subscription_contract(raw_sub, state_id)
		var sub_id: String = str(sub.get("id", "")).strip_edges()
		if sub_id == "":
			warnings.append("Skipped event subscription without id.")
			continue
		if seen_subs.has(sub_id):
			warnings.append("Duplicate event subscription '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [sub_id, state_id])
		seen_subs [sub_id] = true
		normalized_event_subscriptions.append(sub)

	var normalized_event_bus_contracts: Array = []
	var seen_event_bus_contracts: Dictionary = {}
	for raw_bus_contract in event_bus_contracts:
		var bus_contract: Dictionary = normalize_event_bus_contract(raw_bus_contract, state_id)
		var bus_contract_id: String = str(bus_contract.get("id", "")).strip_edges()
		if bus_contract_id == "":
			warnings.append("Skipped EventBus contract without id.")
			continue
		if seen_event_bus_contracts.has(bus_contract_id):
			warnings.append("Duplicate EventBus contract '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [bus_contract_id, state_id])
		seen_event_bus_contracts [bus_contract_id] = true
		normalized_event_bus_contracts.append(bus_contract)

	var normalized_meta_contracts: Array = []
	var seen_meta_contracts: Dictionary = {}
	for raw_meta_contract in meta_contracts:
		var meta_contract: Dictionary = normalize_meta_contract(raw_meta_contract, state_id)
		var meta_contract_id: String = str(meta_contract.get("id", "")).strip_edges()
		if meta_contract_id == "":
			warnings.append("Skipped meta contract without id.")
			continue
		if seen_meta_contracts.has(meta_contract_id):
			warnings.append("Duplicate meta contract '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [meta_contract_id, state_id])
		seen_meta_contracts [meta_contract_id] = true
		normalized_meta_contracts.append(meta_contract)

	var normalized_hydration_rules: Array = []
	var seen_hydration: Dictionary = {}
	for raw_rule in hydration_rules:
		var rule: Dictionary = normalize_hydration_rule(raw_rule, state_id)
		var rule_id: String = str(rule.get("id", "")).strip_edges()
		if rule_id == "":
			warnings.append("Skipped hydration rule without id.")
			continue
		if seen_hydration.has(rule_id):
			warnings.append("Duplicate hydration rule '%s' inside contract '%s'. Conflict policy will resolve at ingest." % [rule_id, state_id])
		seen_hydration [rule_id] = true
		normalized_hydration_rules.append(rule)

	var section_validation: Dictionary = _validate_contract_sections(
		normalized_engines,
		normalized_save_slices,
		normalized_runtime_phases,
		normalized_event_subscriptions,
		normalized_event_bus_contracts,
		normalized_meta_contracts,
		normalized_hydration_rules
	)

	for err in section_validation.get("errors", []):
		errors.append(str(err))
	for warn in section_validation.get("warnings", []):
		warnings.append(str(warn))

	return {
		"schema": str(contract.get("schema", CONTRACT_SCHEMA)).strip_edges(),
		"version": contract_version,
		"runtime_contract_version": CONTRACT_VERSION,
		"state_id": state_id,
		"name": str(contract.get("name", state_id)).strip_edges(),
		"source_path": source_path,
		"engines": normalized_engines,
		"save_slices": normalized_save_slices,
		"runtime_phases": normalized_runtime_phases,
		"event_subscriptions": normalized_event_subscriptions,
		"event_bus_contracts": normalized_event_bus_contracts,
		"meta_contracts": normalized_meta_contracts,
		"hydration_rules": normalized_hydration_rules,
		"runtime_capability_profiles": runtime_capability_profiles,
		"adaptive_resolution_rules": adaptive_resolution_rules,
		"world_streaming_manifest": normalized_streaming_manifest,
		"launch_links": normalized_launch_links,
		"metadata": contract.get("metadata", {}).duplicate(true) if typeof(contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}


func normalize_engine_contract(raw_engine: Dictionary, state_id: String = "") -> Dictionary:
	var engine_id: String = str(raw_engine.get("id", raw_engine.get("engine_id", ""))).strip_edges()
	var class_name_text: String = str(raw_engine.get("class", raw_engine.get("class_name", ""))).strip_edges()
	var boot_phase: String = str(raw_engine.get("boot_phase", "domain_extensions")).strip_edges()
	var warnings: Array = []

	if boot_phase not in ALLOWED_BOOT_PHASES:
		warnings.append("Invalid boot_phase '%s'. Fallback: domain_extensions." % boot_phase)
		boot_phase = "domain_extensions"

	var conflict_policy: String = _normalize_conflict_policy(raw_engine.get("conflict_policy", "highest_priority"))
	var missing_engine_policy: String = _normalize_missing_engine_policy(raw_engine.get("missing_engine_policy", "warn"))
	var allow_contract_instantiation: bool = bool(raw_engine.get("allow_contract_instantiation", false))
	var script_path: String = str(raw_engine.get("script_path", "")).strip_edges()
	var fallback_script_path: String = str(raw_engine.get("fallback_script_path", "")).strip_edges()

	if allow_contract_instantiation and script_path == "" and fallback_script_path == "":
		warnings.append("Engine '%s' allows contract instantiation but has no script_path or fallback_script_path." % engine_id)

	var runtime_property: String = str(raw_engine.get("runtime_property", raw_engine.get("game_state_property", engine_id))).strip_edges()
	if runtime_property == "":
		runtime_property = engine_id

	var canonical_engine_id: String = str(raw_engine.get("canonical_engine_id", raw_engine.get("canonical_id", engine_id))).strip_edges()
	if canonical_engine_id == "":
		canonical_engine_id = engine_id

	var runtime_lookup_keys: Array = _safe_string_array(raw_engine.get("runtime_lookup_keys", []))
	for alias in _safe_string_array(raw_engine.get("aliases", raw_engine.get("engine_aliases", []))):
		_append_unique_string(runtime_lookup_keys, alias)
	_append_unique_string(runtime_lookup_keys, engine_id)
	_append_unique_string(runtime_lookup_keys, runtime_property)
	_append_unique_string(runtime_lookup_keys, canonical_engine_id)

	var mod_id: String = str(raw_engine.get("mod_id", raw_engine.get("source_mod_id", ""))).strip_edges()
	var engine_namespace: String = str(raw_engine.get("engine_namespace", raw_engine.get("namespace", state_id))).strip_edges()
	if engine_namespace == "":
		engine_namespace = state_id

	var contract_uid: String = str(raw_engine.get("contract_uid", raw_engine.get("portable_id", ""))).strip_edges()
	if contract_uid == "":
		contract_uid = _stable_engine_contract_uid(engine_id, state_id, class_name_text, script_path)

	var migration_namespace: String = str(raw_engine.get("migration_namespace", "%s.%s" % [engine_namespace, engine_id])).strip_edges()
	var save_key: String = str(raw_engine.get("save_key", engine_id)).strip_edges()
	if save_key == "":
		save_key = engine_id

	var auto_save_slice: bool = bool(raw_engine.get("auto_save_slice", false))
	if raw_engine.has("snapshot_export_method") or raw_engine.has("snapshot_import_method"):
		auto_save_slice = bool(raw_engine.get("auto_save_slice", true))

	var metadata: Dictionary = raw_engine.get("metadata", {}).duplicate(true) if typeof(raw_engine.get("metadata", {})) == TYPE_DICTIONARY else {}
	metadata ["contract_uid"] = contract_uid
	metadata ["canonical_engine_id"] = canonical_engine_id
	metadata ["runtime_property"] = runtime_property
	metadata ["migration_namespace"] = migration_namespace
	metadata ["device_persistence_key"] = str(raw_engine.get("device_persistence_key", contract_uid)).strip_edges()

	return {
		"id": engine_id,
		"engine_id": engine_id,
		"canonical_engine_id": canonical_engine_id,
		"contract_uid": contract_uid,
		"portable_id": contract_uid,
		"class": class_name_text,
		"class_name": class_name_text,
		"script_path": script_path,
		"fallback_script_path": fallback_script_path,
		"state_id": state_id,
		"mod_id": mod_id,
		"engine_namespace": engine_namespace,
		"migration_namespace": migration_namespace,
		"runtime_property": runtime_property,
		"runtime_lookup_keys": runtime_lookup_keys,
		"aliases": runtime_lookup_keys.duplicate(true),
		"device_persistence_key": str(raw_engine.get("device_persistence_key", contract_uid)).strip_edges(),
		"install_policy": str(raw_engine.get("install_policy", "merge_or_restore")).strip_edges(),
		"update_policy": str(raw_engine.get("update_policy", "preserve_save_slice")).strip_edges(),
		"version": max(1, int(raw_engine.get("version", 1))),
		"boot_phase": boot_phase,
		"boot_order": int(raw_engine.get("boot_order", 1000)),
		"priority": int(raw_engine.get("priority", 0)),
		"conflict_policy": conflict_policy,
		"enabled": bool(raw_engine.get("enabled", true)),
		"required": bool(raw_engine.get("required", false)),
		"allow_contract_instantiation": allow_contract_instantiation,
		"auto_save_slice": auto_save_slice,
		"missing_engine_policy": missing_engine_policy,
		"recovery_method": str(raw_engine.get("recovery_method", "")).strip_edges(),
		"recovery_payload": raw_engine.get("recovery_payload", {}).duplicate(true) if typeof(raw_engine.get("recovery_payload", {})) == TYPE_DICTIONARY else {},
		"save_key": save_key,
		"runtime_phases": _safe_string_array(raw_engine.get("runtime_phases", [])),
		"required_methods": _safe_string_array(raw_engine.get("required_methods", [])),
		"event_subscriptions": _safe_dictionary_array(raw_engine.get("event_subscriptions", [])),
		"snapshot_export_method": str(raw_engine.get("snapshot_export_method", "export_state")).strip_edges(),
		"snapshot_import_method": str(raw_engine.get("snapshot_import_method", "import_state")).strip_edges(),
		"degradation_tags": _safe_string_array(raw_engine.get("degradation_tags", [])),
		"metadata": metadata,
		"validation": {
			"valid": engine_id != "",
			"errors": [] if engine_id != "" else ["Engine contract missing id."],
			"warnings": warnings
		}
	}


func normalize_save_slice_contract(raw_slice: Dictionary, state_id: String = "") -> Dictionary:
	var slice_id: String = str(raw_slice.get("id", raw_slice.get("save_key", ""))).strip_edges()
	var engine_id: String = str(raw_slice.get("engine_id", raw_slice.get("engine", ""))).strip_edges()
	var target_version: int = max(1, int(raw_slice.get("version", raw_slice.get("target_version", 1))))
	var min_supported_version: int = max(1, int(raw_slice.get("min_supported_version", 1)))

	var save_policy: String = str(raw_slice.get("save_policy", raw_slice.get("policy", raw_slice.get("strategy", "migrate_by_schema")))).strip_edges().to_lower()
	if save_policy == "":
		save_policy = "migrate_by_schema"

	var compatibility_mode: String = str(raw_slice.get("compatibility_mode", "bidirectional")).strip_edges().to_lower()
	if compatibility_mode == "":
		compatibility_mode = "bidirectional"

	return {
		"id": slice_id,
		"save_key": str(raw_slice.get("save_key", slice_id)).strip_edges(),
		"state_id": state_id,
		"engine_id": engine_id,
		"enabled": bool(raw_slice.get("enabled", true)),
		"required": bool(raw_slice.get("required", false)),
		"priority": int(raw_slice.get("priority", 0)),
		"conflict_policy": _normalize_conflict_policy(raw_slice.get("conflict_policy", "highest_priority")),
		"missing_engine_policy": _normalize_missing_engine_policy(raw_slice.get("missing_engine_policy", "warn")),
		"export_method": str(raw_slice.get("export_method", "export_state")).strip_edges(),
		"import_method": str(raw_slice.get("import_method", "import_state")).strip_edges(),
		"hydrate_method": str(raw_slice.get("hydrate_method", "")).strip_edges(),
		"fallback_hydration_method": str(raw_slice.get("fallback_hydration_method", "")).strip_edges(),
		"schema": str(raw_slice.get("schema", "eralife.save_slice")).strip_edges(),
		"version": target_version,
		"target_version": target_version,
		"min_supported_version": min_supported_version,
		"save_policy": save_policy,
		"compatibility_mode": compatibility_mode,
		"preserve_unknown_fields": bool(raw_slice.get("preserve_unknown_fields", true)),
		"stream_on_demand": bool(raw_slice.get("stream_on_demand", save_policy == "stream_on_demand")),
		"allow_destructive_migrations": bool(raw_slice.get("allow_destructive_migrations", false)),
		"max_slice_bytes": max(0, int(raw_slice.get("max_slice_bytes", 33554432))),
		"migration_rules": _safe_dictionary_array(raw_slice.get("migration_rules", [])),
		"fallback_data": raw_slice.get("fallback_data", {}).duplicate(true) if typeof(raw_slice.get("fallback_data", {})) == TYPE_DICTIONARY else {},
		"default_data": raw_slice.get("default_data", {}).duplicate(true) if typeof(raw_slice.get("default_data", {})) == TYPE_DICTIONARY else {},
		"metadata": raw_slice.get("metadata", {}).duplicate(true) if typeof(raw_slice.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": slice_id != "",
			"errors": [] if slice_id != "" else ["Save slice missing id."],
			"warnings": []
		}
	}


func normalize_runtime_phase_contract(
	raw_phase: Dictionary,
	state_id: String = "",
	fallback_order: int = 0
) -> Dictionary:
	var phase_id: String = str(
		raw_phase.get(
			"id",
			raw_phase.get(
				"phase",
				""
			)
		)
	).strip_edges()

	var budget_ms: int = max(
		0,
		int(
			raw_phase.get(
				"budget_ms",
				DEFAULT_PHASE_BUDGET_MS
			)
		)
	)

	var hard_budget_ms: int = max(
		budget_ms,
		int(
			raw_phase.get(
				"hard_budget_ms",
				DEFAULT_HARD_PHASE_BUDGET_MS
			)
		)
	)

	var listeners: Array = _safe_dictionary_array(
		raw_phase.get(
			"listeners",
			[]
		)
	)

	var runtime_tasks: Array = []
	var rejected_runtime_task_ids: Array = []
	var yearly_contract_warnings: Array = []
	var yearly_contract_errors: Array = []

	for raw_task in _safe_dictionary_array(
		raw_phase.get(
			"runtime_tasks",
			raw_phase.get(
				"domain_tasks",
				[]
			)
		)
	):
		var task: Dictionary = normalize_runtime_phase_task(
			raw_task,
			phase_id,
			state_id
		)

		var validation_raw: Variant = task.get(
			"validation",
			{}
		)
		var validation: Dictionary = (
			validation_raw as Dictionary
			if typeof(validation_raw) == TYPE_DICTIONARY
			else {}
		)

		var task_id: String = str(
			task.get(
				"id",
				""
			)
		).strip_edges()

		if task_id == "":
			continue

		for raw_warning in validation.get(
			"warnings",
			[]
		):
			yearly_contract_warnings.append(
				str(raw_warning)
			)

		if not bool(
			validation.get(
				"valid",
				false
			)
		):
			rejected_runtime_task_ids.append(
				task_id
			)

			for raw_error in validation.get(
				"errors",
				[]
			):
				yearly_contract_errors.append(
					str(raw_error)
				)

			continue

		runtime_tasks.append(
			task
		)

	for raw_listener in listeners:
		var listener_task: Dictionary = (
			normalize_runtime_phase_task(
				raw_listener,
				phase_id,
				state_id
			)
		)

		var listener_id: String = str(
			listener_task.get(
				"id",
				""
			)
		).strip_edges()

		if listener_id == "":
			continue

		var listener_validation_raw: Variant = (
			listener_task.get(
				"validation",
				{}
			)
		)
		var listener_validation: Dictionary = (
			listener_validation_raw as Dictionary
			if typeof(
				listener_validation_raw
			) == TYPE_DICTIONARY
			else {}
		)

		for raw_warning in listener_validation.get(
			"warnings",
			[]
		):
			yearly_contract_warnings.append(
				str(raw_warning)
			)

		if not bool(
			listener_validation.get(
				"valid",
				false
			)
		):
			rejected_runtime_task_ids.append(
				listener_id
			)

			for raw_error in listener_validation.get(
				"errors",
				[]
			):
				yearly_contract_errors.append(
					str(raw_error)
				)

			continue

		runtime_tasks.append(
			listener_task
		)

	var phase_errors: Array = []

	if phase_id == "":
		phase_errors.append(
			"Runtime phase missing id."
		)

	return {
		"id": phase_id,
		"phase": phase_id,
		"state_id": state_id,
		"enabled": bool(
			raw_phase.get(
				"enabled",
				true
			)
		),
		"required": bool(
			raw_phase.get(
				"required",
				false
			)
		),
		"order": int(
			raw_phase.get(
				"order",
				fallback_order
			)
		),
		"priority": int(
			raw_phase.get(
				"priority",
				0
			)
		),
		"conflict_policy": (
			_normalize_conflict_policy(
				raw_phase.get(
					"conflict_policy",
					"highest_priority"
				)
			)
		),

		"listeners": listeners,
		"runtime_tasks": runtime_tasks,
		"domain_tasks": (
			runtime_tasks.duplicate(false)
		),

		"rejected_runtime_task_ids": (
			rejected_runtime_task_ids
		),
		"yearly_execution_contract_version": (
			YEARLY_EXECUTION_CONTRACT_VERSION
		),

		"guards": _safe_dictionary_array(
			raw_phase.get(
				"guards",
				[]
			)
		),
		"budget_ms": budget_ms,
		"soft_budget_ms": max(
			0,
			int(
				raw_phase.get(
					"soft_budget_ms",
					budget_ms
				)
			)
		),
		"hard_budget_ms": hard_budget_ms,
		"auto_degrade_enabled": bool(
			raw_phase.get(
				"auto_degrade_enabled",
				true
			)
		),
		"degradation_policy": str(
			raw_phase.get(
				"degradation_policy",
				"defer_noncritical"
			)
		).strip_edges().to_lower(),
		"degradation_steps": (
			_safe_dictionary_array(
				raw_phase.get(
					"degradation_steps",
					[]
				)
			)
		),
		"snapshot_before": bool(
			raw_phase.get(
				"snapshot_before",
				false
			)
		),
		"snapshot_after": bool(
			raw_phase.get(
				"snapshot_after",
				false
			)
		),
		"metadata": (
			raw_phase.get(
				"metadata",
				{}
			).duplicate(false)
			if typeof(
				raw_phase.get(
					"metadata",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),

		"validation": {
			"valid": phase_errors.is_empty(),
			"errors": phase_errors,
			"warnings": yearly_contract_warnings,
			"rejected_yearly_contract_errors": (
				yearly_contract_errors
			)
		}
	}
func normalize_runtime_phase_task(
	raw_task: Dictionary,
	phase_id: String = "",
	state_id: String = ""
) -> Dictionary:
	var engine_id: String = str(
		raw_task.get(
			"engine_id",
			raw_task.get(
				"target_engine_id",
				""
			)
		)
	).strip_edges()

	var task_id: String = str(
		raw_task.get(
			"task_id",
			raw_task.get(
				"id",
				""
			)
		)
	).strip_edges()

	var method_name: String = str(
		raw_task.get(
			"method",
			raw_task.get(
				"callback",
				raw_task.get(
					"method_name",
					""
				)
			)
		)
	).strip_edges()

	var task_row_id: String = str(
		raw_task.get(
			"id",
			""
		)
	).strip_edges()

	if task_row_id == "":
		task_row_id = "%s|%s|%s" % [
			phase_id,
			engine_id,
			task_id if task_id != "" else method_name
		]

	var dispatch: String = str(
		raw_task.get(
			"dispatch",
			raw_task.get(
				"dispatch_kind",
				""
			)
		)
	).strip_edges().to_lower()

	if dispatch == "":
		if engine_id == "world_engine":
			dispatch = "world_contract_task"
		elif engine_id == "life_engine":
			dispatch = "life_contract_task"
		else:
			dispatch = "engine_method"

	var execution_model_explicit: bool = (
		raw_task.has(
			"execution_model"
		)
		or raw_task.has(
			"yearly_execution_model"
		)
	)

	var execution_model: String = str(
		raw_task.get(
			"execution_model",
			raw_task.get(
				"yearly_execution_model",
				""
			)
		)
	).strip_edges().to_lower()

	var legacy_ids: Dictionary = (
		_legacy_yearly_runtime_task_ids()
	)
	var legacy_grandfathered: bool = false

	if execution_model == "":
		if (
			legacy_ids.has(
				task_row_id
			)
			or legacy_ids.has(
				task_id
			)
		):
			execution_model = YEARLY_EXECUTION_LEGACY
			legacy_grandfathered = true

	var errors: Array = []
	var warnings: Array = []

	if engine_id == "":
		errors.append(
			"Runtime phase task requires engine_id."
		)

	if (
		task_id == ""
		and method_name == ""
	):
		errors.append(
			"Runtime phase task requires task_id or method."
		)

	if execution_model not in [
		YEARLY_EXECUTION_INCREMENTAL,
		YEARLY_EXECUTION_CONSTANT_TIME,
		YEARLY_EXECUTION_LEGACY
	]:
		errors.append(
			(
				"Yearly task '%s' must explicitly declare "
				+ "execution_model='incremental' or "
				+ "execution_model='constant_time'."
			) % task_row_id
		)

	if (
		execution_model == YEARLY_EXECUTION_INCREMENTAL
		and not bool(
			raw_task.get(
				"passes_context",
				true
			)
		)
	):
		errors.append(
			(
				"Incremental yearly task '%s' must accept "
				+ "runtime context so its cursor/budget contract "
				+ "can be serviced."
			) % task_row_id
		)

	if (
		execution_model == YEARLY_EXECUTION_INCREMENTAL
		and bool(
			raw_task.get(
				"force_immediate",
				false
			)
		)
	):
		errors.append(
			(
				"Incremental yearly task '%s' cannot declare "
				+ "force_immediate=true."
			) % task_row_id
		)

	if execution_model == YEARLY_EXECUTION_LEGACY:
		warnings.append(
			(
				"Legacy yearly task '%s' is grandfathered only "
				+ "for compatibility. It must be migrated to an "
				+ "incremental or constant-time contract."
			) % task_row_id
		)

	var max_quantum_ms: int = clampi(
		int(
			raw_task.get(
				"max_quantum_ms",
				DEFAULT_YEARLY_QUANTUM_MS
			)
		),
		1,
		6
	)

	var max_items_per_quantum: int = clampi(
		int(
			raw_task.get(
				"max_items_per_quantum",
				DEFAULT_YEARLY_QUANTUM_ITEMS
			)
		),
		1,
		512
	)

	return {
		"id": task_row_id,
		"phase": phase_id,
		"state_id": state_id,
		"enabled": bool(
			raw_task.get(
				"enabled",
				true
			)
		),
		"engine_id": engine_id,
		"target_engine_id": engine_id,
		"task_id": task_id,
		"method": method_name,
		"dispatch": dispatch,
		"order": int(
			raw_task.get(
				"order",
				raw_task.get(
					"priority",
					100
				)
			)
		),
		"priority": int(
			raw_task.get(
				"priority",
				100
			)
		),
		"required": bool(
			raw_task.get(
				"required",
				false
			)
		),
		"passes_context": bool(
			raw_task.get(
				"passes_context",
				true
			)
		),
		"allow_defer": bool(
			raw_task.get(
				"allow_defer",
				true
			)
		),
		"force_immediate": bool(
			raw_task.get(
				"force_immediate",
				false
			)
		),
		"once_per_year": bool(
			raw_task.get(
				"once_per_year",
				false
			)
		),

		"yearly_execution_contract_version": (
			YEARLY_EXECUTION_CONTRACT_VERSION
		),
		"execution_model": execution_model,
		"execution_model_explicit": (
			execution_model_explicit
		),
		"legacy_execution_model_grandfathered": (
			legacy_grandfathered
		),
		"requires_progress_contract": (
			execution_model
			== YEARLY_EXECUTION_INCREMENTAL
		),
		"max_quantum_ms": max_quantum_ms,
		"max_items_per_quantum": (
			max_items_per_quantum
		),


		"ui_concurrent": true,
		"idle_required": false,
		"ui_may_preempt_between_quanta": true,
		"blocks_ui": false,

		"metadata": (
			raw_task.get(
				"metadata",
				{}
			).duplicate(false)
			if typeof(
				raw_task.get(
					"metadata",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),

		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}
func normalize_event_subscription_contract(raw_sub: Dictionary, state_id: String = "") -> Dictionary:
	var event_name: String = str(raw_sub.get("event", raw_sub.get("event_name", ""))).strip_edges()
	var target_engine_id: String = str(raw_sub.get("target_engine_id", raw_sub.get("engine_id", ""))).strip_edges()
	var method_name: String = str(raw_sub.get("method", raw_sub.get("callback", ""))).strip_edges()
	var sub_id: String = str(raw_sub.get("id", "")).strip_edges()

	if sub_id == "":
		sub_id = "%s|%s|%s" % [event_name, target_engine_id, method_name]

	return {
		"id": sub_id,
		"state_id": state_id,
		"enabled": bool(raw_sub.get("enabled", true)),
		"event": event_name,
		"event_name": event_name,
		"target_engine_id": target_engine_id,
		"method": method_name,
		"priority": int(raw_sub.get("priority", 100)),
		"lane": str(raw_sub.get("lane", raw_sub.get("dispatch_lane", ""))).strip_edges(),
		"allow_defer": bool(raw_sub.get("allow_defer", true)),
		"force_immediate": bool(raw_sub.get("force_immediate", false)),
		"replay_on_subscribe": bool(raw_sub.get("replay_on_subscribe", false)),
		"metadata": raw_sub.get("metadata", {}).duplicate(true) if typeof(raw_sub.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": event_name != "" and target_engine_id != "" and method_name != "",
			"errors": [] if event_name != "" and target_engine_id != "" and method_name != "" else ["Event subscription requires event, target_engine_id, and method."],
			"warnings": []
		}
	}

func normalize_event_bus_contract(raw_contract: Dictionary, state_id: String = "") -> Dictionary:
	var contract_id: String = str(raw_contract.get("id", raw_contract.get("contract_id", "event_bus_contract"))).strip_edges()
	if contract_id == "":
		contract_id = "event_bus_contract"

	var runtime_guards_raw: Variant = raw_contract.get("runtime_guards", raw_contract.get("runtime_guard", {}))
	var runtime_guards: Dictionary = runtime_guards_raw.duplicate(true) if typeof(runtime_guards_raw) == TYPE_DICTIONARY else {}

	var normalized_lanes: Array = []
	for raw_lane in _safe_dictionary_array(raw_contract.get("dispatch_lanes", raw_contract.get("lanes", []))):
		var lane: Dictionary = normalize_event_bus_lane_contract(raw_lane, state_id, contract_id)
		if str(lane.get("id", "")).strip_edges() == "":
			continue
		normalized_lanes.append(lane)

	var normalized_events: Array = []
	for raw_event in _safe_dictionary_array(raw_contract.get("events", raw_contract.get("event_contracts", []))):
		var event_contract: Dictionary = normalize_event_bus_event_contract(raw_event, state_id, contract_id)
		if str(event_contract.get("event", "")).strip_edges() == "":
			continue
		normalized_events.append(event_contract)

	return {
		"id": contract_id,
		"schema": str(raw_contract.get("schema", "eralife.event_bus_contract_layer")).strip_edges(),
		"version": max(1, int(raw_contract.get("version", 1))),
		"state_id": state_id,
		"enabled": bool(raw_contract.get("enabled", true)),
		"priority": int(raw_contract.get("priority", 0)),
		"conflict_policy": _normalize_conflict_policy(raw_contract.get("conflict_policy", "merge")),
		"runtime_guards": runtime_guards,
		"dispatch_lanes": normalized_lanes,
		"events": normalized_events,
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": []
		}
	}


func normalize_event_bus_lane_contract(raw_lane: Dictionary, state_id: String = "", contract_id: String = "") -> Dictionary:
	var lane_id: String = str(raw_lane.get("id", raw_lane.get("lane", ""))).strip_edges()
	var policy: String = str(raw_lane.get("policy", "qos")).strip_edges().to_lower()
	if policy not in ["immediate", "deferred", "qos", "drop_when_over_budget"]:
		policy = "qos"

	return {
		"id": lane_id,
		"lane": lane_id,
		"state_id": state_id,
		"contract_id": contract_id,
		"enabled": bool(raw_lane.get("enabled", true)),
		"priority": int(raw_lane.get("priority", 100)),
		"policy": policy,
		"force_immediate": bool(raw_lane.get("force_immediate", policy == "immediate")),
		"defer_by_default": bool(raw_lane.get("defer_by_default", policy == "deferred")),
		"queue_limit": max(0, int(raw_lane.get("queue_limit", 128))),
		"max_handlers_per_flush": max(1, int(raw_lane.get("max_handlers_per_flush", 64))),
		"metadata": raw_lane.get("metadata", {}).duplicate(true) if typeof(raw_lane.get("metadata", {})) == TYPE_DICTIONARY else {}
	}


func normalize_event_bus_event_contract(raw_event: Dictionary, state_id: String = "", contract_id: String = "") -> Dictionary:
	var event_name: String = str(raw_event.get("event", raw_event.get("event_name", raw_event.get("id", "")))).strip_edges()
	var event_id: String = str(raw_event.get("id", event_name)).strip_edges()

	var schema_policy: String = str(raw_event.get("schema_policy", "warn")).strip_edges().to_lower()
	if schema_policy not in ["warn", "drop", "quarantine", "strict"]:
		schema_policy = "warn"

	return {
		"id": event_id,
		"state_id": state_id,
		"contract_id": contract_id,
		"event": event_name,
		"event_name": event_name,
		"enabled": bool(raw_event.get("enabled", true)),
		"lane": str(raw_event.get("lane", raw_event.get("dispatch_lane", "important"))).strip_edges(),
		"priority": int(raw_event.get("priority", 100)),
		"schema_policy": schema_policy,
		"allow_unknown_keys": bool(raw_event.get("allow_unknown_keys", true)),
		"required_keys": _safe_string_array(raw_event.get("required_keys", [])),
		"optional_keys": _safe_string_array(raw_event.get("optional_keys", [])),
		"key_types": raw_event.get("key_types", {}).duplicate(true) if typeof(raw_event.get("key_types", {})) == TYPE_DICTIONARY else {},
		"defaults": raw_event.get("defaults", {}).duplicate(true) if typeof(raw_event.get("defaults", {})) == TYPE_DICTIONARY else {},
		"aliases": _safe_string_array(raw_event.get("aliases", raw_event.get("compatibility_aliases", []))),
		"canonical_event": str(raw_event.get("canonical_event", event_name)).strip_edges(),
		"max_depth": max(1, int(raw_event.get("max_depth", 12))),
		"suppress_duplicates": bool(raw_event.get("suppress_duplicates", true)),
		"duplicate_ttl_ms": max(0, int(raw_event.get("duplicate_ttl_ms", 120))),
		"duplicate_keys": _safe_string_array(raw_event.get("duplicate_keys", [])),
		"replay_enabled": bool(raw_event.get("replay_enabled", false)),
		"replay_buffer_limit": max(0, int(raw_event.get("replay_buffer_limit", 24))),
		"metadata": raw_event.get("metadata", {}).duplicate(true) if typeof(raw_event.get("metadata", {})) == TYPE_DICTIONARY else {}
	}

func normalize_meta_contract(raw_contract: Dictionary, state_id: String = "") -> Dictionary:
	var governor = _ensure_contract_meta_governor()
	if governor != null and governor.has_method("normalize_meta_contract"):
		var normalized: Dictionary = governor.normalize_meta_contract(raw_contract, str(raw_contract.get("source_path", state_id)))
		normalized ["state_id"] = state_id
		return normalized

	return {
		"id": str(raw_contract.get("id", "contract_meta_governor")).strip_edges(),
		"state_id": state_id,
		"schema": "eralife.contract_meta_governor",
		"version": 1,
		"enabled": bool(raw_contract.get("enabled", true)),
		"rules": _safe_dictionary_array(raw_contract.get("rules", raw_contract.get("constraints", []))),
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": []
		}
	}
func normalize_hydration_rule(raw_rule: Dictionary, state_id: String = "") -> Dictionary:
	var rule_id: String = str(raw_rule.get("id", "")).strip_edges()
	var target_engine_id: String = str(raw_rule.get("target_engine_id", raw_rule.get("engine_id", ""))).strip_edges()

	if rule_id == "":
		rule_id = "%s|%s" % [target_engine_id, str(raw_rule.get("method", "hydrate"))]

	return {
		"id": rule_id,
		"state_id": state_id,
		"enabled": bool(raw_rule.get("enabled", true)),
		"required": bool(raw_rule.get("required", false)),
		"order": int(raw_rule.get("order", 100)),
		"priority": int(raw_rule.get("priority", 0)),
		"conflict_policy": _normalize_conflict_policy(raw_rule.get("conflict_policy", "highest_priority")),
		"missing_engine_policy": _normalize_missing_engine_policy(raw_rule.get("missing_engine_policy", "warn")),
		"target_engine_id": target_engine_id,
		"method": str(raw_rule.get("method", raw_rule.get("hydrate_method", ""))).strip_edges(),
		"fallback_method": str(raw_rule.get("fallback_method", "")).strip_edges(),
		"phase": str(raw_rule.get("phase", "post_load")).strip_edges(),
		"payload": raw_rule.get("payload", {}).duplicate(true) if typeof(raw_rule.get("payload", {})) == TYPE_DICTIONARY else {},
		"fallback_payload": raw_rule.get("fallback_payload", {}).duplicate(true) if typeof(raw_rule.get("fallback_payload", {})) == TYPE_DICTIONARY else {},
		"metadata": raw_rule.get("metadata", {}).duplicate(true) if typeof(raw_rule.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": target_engine_id != "",
			"errors": [] if target_engine_id != "" else ["Hydration rule missing target_engine_id."],
			"warnings": []
		}
	}


func _ingest_contract(contract: Dictionary) -> void:
	var state_id: String = str(contract.get("state_id", DEFAULT_STATE_ID)).strip_edges()

	for raw_engine in contract.get("engines", []):
		if typeof(raw_engine) != TYPE_DICTIONARY:
			continue

		var engine: Dictionary = raw_engine
		var engine_id: String = str(engine.get("id", "")).strip_edges()
		if engine_id == "":
			continue

		_upsert_contract_registry_entry(engine_registry, engine_id, engine, "engine", state_id)

		var resolved_engine: Dictionary = engine_registry.get(engine_id, engine)
		_register_engine_identity_record(resolved_engine, state_id)

		if bool(resolved_engine.get("auto_save_slice", false)):
			var auto_slice: Dictionary = _build_auto_save_slice_from_engine(resolved_engine, state_id)
			var auto_slice_id: String = str(auto_slice.get("id", "")).strip_edges()
			if auto_slice_id != "":
				_upsert_contract_registry_entry(save_slice_registry, auto_slice_id, auto_slice, "save_slice", state_id)

	for raw_slice in contract.get("save_slices", []):
		if typeof(raw_slice) != TYPE_DICTIONARY:
			continue
		var save_slice: Dictionary = raw_slice
		var slice_id: String = str(save_slice.get("id", "")).strip_edges()
		if slice_id == "":
			continue
		_upsert_contract_registry_entry(save_slice_registry, slice_id, save_slice, "save_slice", state_id)

	for raw_phase in contract.get("runtime_phases", []):
		if typeof(raw_phase) != TYPE_DICTIONARY:
			continue
		var phase: Dictionary = raw_phase
		var phase_id: String = str(phase.get("id", "")).strip_edges()
		if phase_id == "":
			continue
		_upsert_contract_registry_entry(runtime_phase_registry, phase_id, phase, "runtime_phase", state_id)

	for raw_sub in contract.get("event_subscriptions", []):
		if typeof(raw_sub) != TYPE_DICTIONARY:
			continue
		var sub: Dictionary = raw_sub
		var sub_id: String = str(sub.get("id", "")).strip_edges()
		if sub_id == "":
			continue
		_upsert_contract_registry_entry(event_subscription_registry, sub_id, sub, "event_subscription", state_id)

	for raw_bus_contract in contract.get("event_bus_contracts", []):
		if typeof(raw_bus_contract) != TYPE_DICTIONARY:
			continue
		var bus_contract: Dictionary = raw_bus_contract
		var bus_contract_id: String = str(bus_contract.get("id", "")).strip_edges()
		if bus_contract_id == "":
			continue
		_upsert_contract_registry_entry(event_bus_contract_registry, bus_contract_id, bus_contract, "event_bus_contract", state_id)

	for raw_meta_contract in contract.get("meta_contracts", []):
		if typeof(raw_meta_contract) != TYPE_DICTIONARY:
			continue
		var meta_contract: Dictionary = raw_meta_contract
		var meta_contract_id: String = str(meta_contract.get("id", "")).strip_edges()
		if meta_contract_id == "":
			continue
		_upsert_contract_registry_entry(meta_contract_registry, meta_contract_id, meta_contract, "meta_contract", state_id)

	for raw_rule in contract.get("hydration_rules", []):
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = raw_rule
		var rule_id: String = str(rule.get("id", "")).strip_edges()
		if rule_id == "":
			continue
		_upsert_contract_registry_entry(hydration_registry, rule_id, rule, "hydration_rule", state_id)

	_ingest_runtime_capability_profiles(contract.get("runtime_capability_profiles", {}), state_id)
	_ingest_adaptive_resolution_rules(contract.get("adaptive_resolution_rules", []), state_id)

	var streaming_raw: Variant = contract.get("world_streaming_manifest", {})
	if typeof(streaming_raw) == TYPE_DICTIONARY and not (streaming_raw as Dictionary).is_empty():
		world_streaming_manifest = _deep_merge_dictionary(world_streaming_manifest, streaming_raw as Dictionary)

	var links_raw: Variant = contract.get("launch_links", {})
	if typeof(links_raw) == TYPE_DICTIONARY and not (links_raw as Dictionary).is_empty():
		launch_link_registry = _merged_dictionary_copy(launch_link_registry, links_raw as Dictionary)

	active_state_id = state_id if state_id != "" else active_state_id
	last_conflict_report = {
		"schema": "eralife.game_state_contract_conflict_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"conflicts": conflict_reports.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}


func instantiate_contract_engine_extensions() -> Dictionary:
	var report:= {
		"schema": "eralife.contract_engine_instantiation_report",
		"version": CONTRACT_VERSION,
		"instantiated": [],
		"skipped": [],
		"failed": []
	}

	if gs == null:
		report ["failed"].append({ "reason": "No GameState bound."})
		return report

	var ordered: Array = engine_registry.values()
	ordered.sort_custom(func (a, b): return int(a.get("boot_order", 1000)) < int(b.get("boot_order", 1000)))

	for engine in ordered:
		if typeof(engine) != TYPE_DICTIONARY:
			continue
		if not bool(engine.get("enabled", true)):
			continue

		var engine_id: String = str(engine.get("id", "")).strip_edges()
		if engine_id == "":
			continue

		_register_engine_identity_record(engine, str(engine.get("state_id", active_state_id)))

		var existing = get_engine_instance(engine_id)
		if existing != null:
			_bind_engine_instance(engine, existing)
			report ["skipped"].append({
				"engine_id": engine_id,
				"reason": "Engine already exists.",
				"contract_uid": str(engine.get("contract_uid", ""))
			})
			continue

		if not bool(engine.get("allow_contract_instantiation", false)):
			report ["skipped"].append({
				"engine_id": engine_id,
				"reason": "Contract instantiation disabled.",
				"contract_uid": str(engine.get("contract_uid", ""))
			})
			continue

		var instance = _instantiate_engine_from_contract(engine)
		if instance == null:
			report ["failed"].append({
				"engine_id": engine_id,
				"class": str(engine.get("class", "")),
				"script_path": str(engine.get("script_path", "")),
				"fallback_script_path": str(engine.get("fallback_script_path", "")),
				"missing_engine_policy": str(engine.get("missing_engine_policy", "warn")),
				"contract_uid": str(engine.get("contract_uid", "")),
				"reason": "Could not instantiate contract engine."
			})
			continue

		_bind_engine_instance(engine, instance)
		instantiated_contract_engines [engine_id] = true

		report ["instantiated"].append({
			"engine_id": engine_id,
			"class": str(engine.get("class", "")),
			"script_path": str(engine.get("script_path", "")),
			"runtime_property": str(engine.get("runtime_property", engine_id)),
			"contract_uid": str(engine.get("contract_uid", ""))
		})

	contract_runtime_manifest = _build_contract_runtime_manifest()
	return report


func _instantiate_engine_from_contract(engine: Dictionary):
	var script_resolution: Dictionary = (
		_resolve_contract_script_resource(
			str(
				engine.get(
					"script_path",
					""
				)
			),
			str(
				engine.get(
					"fallback_script_path",
					""
				)
			),
			str(
				engine.get(
					"class",
					engine.get(
						"class_name",
						""
					)
				)
			)
		)
	)

	if not bool(
		script_resolution.get(
			"success",
			false
		)
	):
		return null

	var script: Script = (
		script_resolution.get(
			"script",
			null
		) as Script
	)

	if (
		script == null
		or not script.can_instantiate()
	):
		return null

	var instantiation_args: Array = engine.get(
		"instantiation_args",
		["game_state"]
	) if typeof(
		engine.get(
			"instantiation_args",
			["game_state"]
		)
	) == TYPE_ARRAY else ["game_state"]

	if instantiation_args.is_empty():
		return script.new()

	return script.new(gs)

func get_engine_instance(engine_id: String):
	if gs == null:
		return null

	var clean_id: String = str(engine_id).strip_edges()
	if clean_id == "":
		return null

	var lookup_keys: Array = [clean_id]

	if engine_registry.has(clean_id):
		var contract: Dictionary = engine_registry.get(clean_id, {})
		for key in _engine_runtime_keys(contract):
			_append_unique_string(lookup_keys, key)

	if engine_identity_registry.has(clean_id):
		var identity: Dictionary = engine_identity_registry.get(clean_id, {})
		for key in _safe_string_array(identity.get("runtime_lookup_keys", [])):
			_append_unique_string(lookup_keys, key)
		_append_unique_string(lookup_keys, str(identity.get("engine_id", "")))
		_append_unique_string(lookup_keys, str(identity.get("runtime_property", "")))
		_append_unique_string(lookup_keys, str(identity.get("canonical_engine_id", "")))

	for key in lookup_keys:
		var clean_key: String = str(key).strip_edges()
		if clean_key == "":
			continue

		var from_property = gs.get(clean_key)
		if from_property != null:
			return from_property

		if typeof(gs.contract_runtime_engines) == TYPE_DICTIONARY and gs.contract_runtime_engines.has(clean_key):
			return gs.contract_runtime_engines.get(clean_key)

	return null


func register_existing_engines_from_game_state() -> Dictionary:
	var report:= {
		"schema": "eralife.game_state_existing_engine_registry_report",
		"version": CONTRACT_VERSION,
		"present": [],
		"missing": [],
		"registered_at_ms": int(Time.get_ticks_msec())
	}

	if gs == null:
		report ["missing"].append({ "reason": "No GameState bound."})
		return report

	for engine_id in engine_registry.keys():
		var contract: Dictionary = engine_registry.get(engine_id, {})
		_register_engine_identity_record(contract, str(contract.get("state_id", active_state_id)))

		var instance = get_engine_instance(str(engine_id))
		contract ["runtime_present"] = instance != null
		contract ["runtime_registered_at_ms"] = int(Time.get_ticks_msec())
		contract ["runtime_lookup_keys"] = _engine_runtime_keys(contract)

		if instance != null:
			_bind_engine_instance(contract, instance)
			contract ["runtime_class_guess"] = instance.get_class() if instance is Object else str(typeof(instance))
			report ["present"].append({
				"engine_id": str(engine_id),
				"runtime_property": str(contract.get("runtime_property", engine_id)),
				"contract_uid": str(contract.get("contract_uid", ""))
			})
		else:
			var row:= {
				"engine_id": str(engine_id),
				"class": str(contract.get("class", "")),
				"runtime_property": str(contract.get("runtime_property", engine_id)),
				"required": bool(contract.get("required", false)),
				"contract_uid": str(contract.get("contract_uid", "")),
				"missing_engine_policy": str(contract.get("missing_engine_policy", "warn"))
			}
			report ["missing"].append(row)

		engine_registry [engine_id] = contract

	contract_runtime_manifest = _build_contract_runtime_manifest()

	if typeof(gs.game_state_contract_registry) == TYPE_DICTIONARY:
		gs.game_state_contract_registry = export_registry()

	return report


func refresh_runtime_registry() -> Dictionary:
	var report:= register_existing_engines_from_game_state()
	apply_runtime_guards({ "phase": "refresh_runtime_registry"})
	return report


func apply_runtime_guards(context: Dictionary = {}) -> Dictionary:
	var warnings: Array = []
	var missing_required: Array = []
	var missing_optional: Array = []
	var degraded_engines: Array = []
	var quarantined_engines: Array = []

	var capability_report: Dictionary = resolve_runtime_capability_profile(context.get("runtime_capability_profile", runtime_capability_profile))
	var adaptive_report: Dictionary = resolve_adaptive_contracts({
		"phase": str(context.get("phase", "runtime_guard")),
		"source": "apply_runtime_guards",
		"capability_profile": runtime_capability_profile.duplicate(true)
	})
	var streaming_report: Dictionary = prepare_world_streaming_boot({
		"phase": str(context.get("phase", "runtime_guard")),
		"source": "apply_runtime_guards"
	})

	var recovery_report: Dictionary = recover_missing_engines(context)

	for engine_id in engine_registry.keys():
		var engine: Dictionary = engine_registry.get(engine_id, {})

		if not bool(engine.get("enabled", true)):
			degraded_engines.append({
				"engine_id": str(engine_id),
				"reason": str(engine.get("disabled_reason", "Contract disabled."))
			})
			continue

		var instance = get_engine_instance(str(engine_id))
		if instance == null:
			var row:= {
				"engine_id": str(engine_id),
				"class": str(engine.get("class", "")),
				"boot_phase": str(engine.get("boot_phase", "")),
				"required": bool(engine.get("required", false)),
				"missing_engine_policy": str(engine.get("missing_engine_policy", "warn"))
			}

			if str(engine.get("missing_engine_policy", "warn")) == "quarantine":
				quarantined_engines.append(row)

			if bool(engine.get("required", false)):
				missing_required.append(row)
			else:
				missing_optional.append(row)

			continue

		if instance is Object:
			for method_name in engine.get("required_methods", []):
				var clean_method: String = str(method_name).strip_edges()
				if clean_method == "":
					continue
				if not instance.has_method(clean_method):
					warnings.append("Engine '%s' is missing required method '%s'." % [str(engine_id), clean_method])

	for slice_id in save_slice_registry.keys():
		var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
		if not bool(save_slice.get("enabled", true)):
			continue

		var slice_engine_id: String = str(save_slice.get("engine_id", "")).strip_edges()
		if slice_engine_id == "":
			warnings.append("Save slice '%s' has no engine_id." % str(slice_id))
			continue

		var slice_instance = get_engine_instance(slice_engine_id)
		if slice_instance == null:
			var policy: String = str(save_slice.get("missing_engine_policy", "warn"))
			if bool(save_slice.get("required", false)) and policy == "fail":
				warnings.append("Required save slice '%s' points to missing engine '%s'." % [slice_id, slice_engine_id])
			elif policy in ["warn", "recover", "fallback"]:
				warnings.append("Save slice '%s' is waiting for missing engine '%s'." % [slice_id, slice_engine_id])

	var validation: Dictionary = validate_active_contracts({
		"phase": str(context.get("phase", "runtime_guard")),
		"include_runtime": true,
		"capability_profile": runtime_capability_profile.duplicate(true)
	})

	var phase_budget: Dictionary = build_runtime_phase_budget_report(context)

	var meta_report: Dictionary = apply_contract_meta_governor({
		"phase": str(context.get("phase", "runtime_guard")),
		"include_runtime": true,
		"source": "apply_runtime_guards"
	})

	var meta_guard_patch: Dictionary = {}
	var meta_patch_raw: Variant = meta_report.get("runtime_guard_patch", {})
	if typeof(meta_patch_raw) == TYPE_DICTIONARY:
		meta_guard_patch = (meta_patch_raw as Dictionary).duplicate(true)

	var adaptive_guard_patch: Dictionary = {}
	var adaptive_patch_raw: Variant = adaptive_report.get("runtime_guard_patch", {})
	if typeof(adaptive_patch_raw) == TYPE_DICTIONARY:
		adaptive_guard_patch = (adaptive_patch_raw as Dictionary).duplicate(true)

	var guard_valid: bool = missing_required.is_empty() and bool(validation.get("valid", true))
	var governor_raw: Variant = meta_report.get("governor_report", {})
	if typeof(governor_raw) == TYPE_DICTIONARY:
		guard_valid = guard_valid and bool((governor_raw as Dictionary).get("valid", true))

	runtime_guard = {
		"schema": "eralife.game_state_runtime_guard",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"capability_profile": runtime_capability_profile.duplicate(true),
		"capability_resolution": capability_report.duplicate(true),
		"adaptive_resolution": adaptive_report.duplicate(true),
		"streaming_boot": streaming_report.duplicate(true),
		"validation": validation.duplicate(true),
		"recovery_report": recovery_report.duplicate(true),
		"phase_budget": phase_budget.duplicate(true),
		"meta_governor": meta_report.duplicate(true),
		"missing_required_engines": missing_required,
		"missing_optional_engines": missing_optional,
		"degraded_engines": degraded_engines,
		"quarantined_engines": quarantined_engines,
		"warnings": warnings,
		"valid": guard_valid,
		"checked_at_ms": int(Time.get_ticks_msec())
	}

	for key in adaptive_guard_patch.keys():
		runtime_guard [key] = adaptive_guard_patch [key]
	for key in meta_guard_patch.keys():
		runtime_guard [key] = meta_guard_patch [key]

	if gs != null:
		if typeof(gs.game_state_runtime_guard) != TYPE_DICTIONARY:
			gs.game_state_runtime_guard = {}
		gs.game_state_runtime_guard = runtime_guard.duplicate(true)

		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["game_state_contract_runtime_guard"] = runtime_guard.duplicate(true)

			var scenario_runtime_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
			var scenario_runtime_guard: Dictionary = scenario_runtime_guard_raw if typeof(scenario_runtime_guard_raw) == TYPE_DICTIONARY else {}

			for key in adaptive_guard_patch.keys():
				scenario_runtime_guard [key] = adaptive_guard_patch [key]
			for key in meta_guard_patch.keys():
				scenario_runtime_guard [key] = meta_guard_patch [key]

			scenario_runtime_guard ["runtime_capability_profile"] = runtime_capability_profile.duplicate(true)
			scenario_runtime_guard ["adaptive_resolution_active"] = true
			scenario_runtime_guard ["world_streaming_enabled"] = bool(world_streaming_manifest.get("enabled", true))
			scenario_runtime_guard ["world_streaming_boot_core_only"] = bool(streaming_report.get("core_only_boot", true))

			gs.scenario_state ["runtime_guard"] = scenario_runtime_guard

	return runtime_guard

func export_meta_contract_layer() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.contract_meta_governor_bundle",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"meta_contract_registry": meta_contract_registry.duplicate(true),
		"contracts": meta_contract_registry.values(),
		"exported_at_ms": int(Time.get_ticks_msec())
	})


func build_contract_meta_snapshot(context: Dictionary = {}) -> Dictionary:
	var snapshot:= {
		"schema": "eralife.contract_meta_snapshot",
		"version": CONTRACT_VERSION,
		"context": context.duplicate(true),
		"registry": {
			"contracts": contract_registry.size(),
			"engines": engine_registry.size(),
			"save_slices": save_slice_registry.size(),
			"runtime_phases": runtime_phase_registry.size(),
			"event_subscriptions": event_subscription_registry.size(),
			"event_bus_contracts": event_bus_contract_registry.size(),
			"meta_contracts": meta_contract_registry.size(),
			"hydration_rules": hydration_registry.size()
		},
		"runtime": {
			"runtime_guard": runtime_guard.duplicate(true),
			"phase_budget": runtime_phase_budget_report.duplicate(true),
			"phase_overflow_count": 0
		},
		"event_bus": {},
		"validation": {
			"valid": bool(last_validation_report.get("valid", true)),
			"error_count": int(last_validation_report.get("errors", []).size()) if typeof(last_validation_report.get("errors", [])) == TYPE_ARRAY else 0,
			"warning_count": int(last_validation_report.get("warnings", []).size()) if typeof(last_validation_report.get("warnings", [])) == TYPE_ARRAY else 0
		},
		"reality": {},
		"built_at_ms": int(Time.get_ticks_msec())
	}

	snapshot ["registry"] ["total_contract_surface"] = (
		int(snapshot ["registry"].get("contracts", 0))
		+ int(snapshot ["registry"].get("engines", 0))
		+ int(snapshot ["registry"].get("save_slices", 0))
		+ int(snapshot ["registry"].get("runtime_phases", 0))
		+ int(snapshot ["registry"].get("event_subscriptions", 0))
		+ int(snapshot ["registry"].get("event_bus_contracts", 0))
		+ int(snapshot ["registry"].get("meta_contracts", 0))
		+ int(snapshot ["registry"].get("hydration_rules", 0))
	)

	if gs != null:
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			var overflow_log_raw: Variant = gs.scenario_state.get("runtime_phase_overflow_log", [])
			snapshot ["runtime"] ["phase_overflow_count"] = overflow_log_raw.size() if typeof(overflow_log_raw) == TYPE_ARRAY else 0

		if gs.event_bus != null and gs.event_bus.has_method("get_contract_debug_snapshot"):
			snapshot ["event_bus"] = gs.event_bus.get_contract_debug_snapshot()

		snapshot ["reality"] = {
			"year": int(gs.year) if "year" in gs else 0,
			"npc_count": int(gs.npcs.size()) if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY else 0,
			"world_feed_count": int(gs.world_feed.size()) if "world_feed" in gs and typeof(gs.world_feed) == TYPE_ARRAY else 0
		}

	return _make_binary_safe(snapshot)


func apply_contract_meta_governor(context: Dictionary = {}) -> Dictionary:
	var governor = _ensure_contract_meta_governor()

	var report:= {
		"schema": "eralife.game_state_contract_meta_governor_apply_report",
		"version": CONTRACT_VERSION,
		"applied": false,
		"contract_count": meta_contract_registry.size(),
		"warnings": [],
		"failed": []
	}

	if governor == null:
		report ["failed"].append({ "reason": "No ContractMetaGovernor available."})
		return report

	if governor.has_method("configure"):
		var configure_report: Dictionary = governor.configure(export_meta_contract_layer())
		report ["configure_report"] = configure_report.duplicate(true)

	var snapshot: Dictionary = build_contract_meta_snapshot(context)
	var governor_report: Dictionary = governor.observe(context, snapshot)

	report ["applied"] = true
	report ["governor_report"] = governor_report.duplicate(true)
	report ["runtime_guard_patch"] = governor_report.get("runtime_guard_patch", {}).duplicate(true) if typeof(governor_report.get("runtime_guard_patch", {})) == TYPE_DICTIONARY else {}

	last_meta_governor_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["contract_meta_governor_report"] = report.duplicate(true)
		gs.scenario_state ["contract_meta_governor_visible_events"] = governor_report.get("visible_events", []).duplicate(true) if typeof(governor_report.get("visible_events", [])) == TYPE_ARRAY else []

	return report
func apply_event_subscriptions(bus = null) -> Dictionary:
	var report:= {
		"schema": "eralife.game_state_contract_event_subscription_report",
		"version": CONTRACT_VERSION,
		"subscribed": [],
		"skipped": [],
		"failed": []
	}

	if bus == null and gs != null:
		bus = gs.event_bus

	if bus == null:
		report ["failed"].append({ "reason": "No EventBus available."})
		return report

	for sub_id in event_subscription_registry.keys():
		var sub: Dictionary = event_subscription_registry.get(sub_id, {})
		if not bool(sub.get("enabled", true)):
			continue

		var event_name: String = str(sub.get("event", "")).strip_edges()
		var target_engine_id: String = str(sub.get("target_engine_id", "")).strip_edges()
		var method_name: String = str(sub.get("method", "")).strip_edges()

		if event_name == "" or target_engine_id == "" or method_name == "":
			report ["failed"].append({
				"id": str(sub_id),
				"reason": "Subscription missing event, target_engine_id, or method."
			})
			continue

		var target = get_engine_instance(target_engine_id)
		if target == null:
			report ["failed"].append({
				"id": str(sub_id),
				"event": event_name,
				"target_engine_id": target_engine_id,
				"method": method_name,
				"reason": "Target engine missing."
			})
			continue

		if not target.has_method(method_name):
			report ["failed"].append({
				"id": str(sub_id),
				"event": event_name,
				"target_engine_id": target_engine_id,
				"method": method_name,
				"reason": "Target method missing."
			})
			continue

		var already_key: String = "subscribed|%s" % str(sub_id)
		if bool(sub.get(already_key, false)):
			report ["skipped"].append({
				"id": str(sub_id),
				"reason": "Already subscribed."
			})
			continue

		bus.subscribe(event_name, target, method_name, {
			"subscription_id": str(sub_id),
			"priority": int(sub.get("priority", 100)),
			"lane": str(sub.get("lane", "")).strip_edges(),
			"allow_defer": bool(sub.get("allow_defer", true)),
			"force_immediate": bool(sub.get("force_immediate", false)),
			"replay_on_subscribe": bool(sub.get("replay_on_subscribe", false))
		})

		sub [already_key] = true
		event_subscription_registry [sub_id] = sub

		report ["subscribed"].append({
			"id": str(sub_id),
			"event": event_name,
			"target_engine_id": target_engine_id,
			"method": method_name,
			"lane": str(sub.get("lane", "")).strip_edges()
		})

	return report
func export_event_bus_contract_layer() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.event_bus_contract_layer_bundle",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"event_bus_contract_registry": event_bus_contract_registry.duplicate(true),
		"contracts": event_bus_contract_registry.values(),
		"exported_at_ms": int(Time.get_ticks_msec())
	})


func apply_event_bus_contracts(bus = null) -> Dictionary:
	var report:= {
		"schema": "eralife.game_state_contract_event_bus_apply_report",
		"version": CONTRACT_VERSION,
		"applied": false,
		"contract_count": event_bus_contract_registry.size(),
		"warnings": [],
		"failed": []
	}

	if bus == null and gs != null:
		bus = gs.event_bus

	if bus == null:
		report ["failed"].append({ "reason": "No EventBus available."})
		return report

	if not bus.has_method("configure_from_contract"):
		report ["failed"].append({ "reason": "EventBus does not implement configure_from_contract()."})
		return report

	var configure_report: Dictionary = bus.configure_from_contract(export_event_bus_contract_layer())
	report ["applied"] = true
	report ["configure_report"] = configure_report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["event_bus_contract_layer_report"] = report.duplicate(true)

	return report


func hydrate_runtime_state(context: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.game_state_contract_hydration_report",
		"version": CONTRACT_VERSION,
		"context": context.duplicate(true),
		"cross_governor_sync": {},
		"hydrated": [],
		"fallback_hydrated": [],
		"orphaned": [],
		"skipped": [],
		"failed": []
	}

	if gs == null:
		report ["failed"].append({ "reason": "No GameState bound."})
		return report

	report ["cross_governor_sync"] = sync_cross_governors({
		"phase": str(context.get("phase", "hydrate_runtime_state")),
		"source": "hydrate_runtime_state",
		"intent": "pre_hydration",
		"force_streaming_hydration": bool(context.get("force_streaming_hydration", false))
	})

	recover_missing_engines({
		"phase": str(context.get("phase", "hydrate_runtime_state")),
		"reason": "pre_hydration_recovery"
	})

	var hydration_rules: Array = hydration_registry.values()
	hydration_rules.sort_custom(func (a, b): return int(a.get("order", 100)) < int(b.get("order", 100)))

	for rule in hydration_rules:
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		if not bool(rule.get("enabled", true)):
			continue

		var rule_id: String = str(rule.get("id", "")).strip_edges()
		var target_engine_id: String = str(rule.get("target_engine_id", "")).strip_edges()
		var method_name: String = str(rule.get("method", "")).strip_edges()
		var fallback_method: String = str(rule.get("fallback_method", "")).strip_edges()

		if target_engine_id == "":
			report ["failed"].append({ "id": rule_id, "reason": "Hydration rule missing target_engine_id."})
			continue

		var target = get_engine_instance(target_engine_id)
		if target == null:
			var policy: String = str(rule.get("missing_engine_policy", "warn"))
			if policy in ["fallback", "recover"] and fallback_method != "" and gs.has_method(fallback_method):
				gs.call(fallback_method, rule.get("fallback_payload", {}))
				report ["fallback_hydrated"].append({
					"id": rule_id,
					"target_engine_id": target_engine_id,
					"fallback_method": fallback_method
				})
			elif bool(rule.get("required", false)) and policy == "fail":
				report ["failed"].append({
					"id": rule_id,
					"target_engine_id": target_engine_id,
					"reason": "Required hydration target missing."
				})
			else:
				report ["skipped"].append({
					"id": rule_id,
					"target_engine_id": target_engine_id,
					"reason": "Target engine missing."
				})
			continue

		if method_name != "" and target.has_method(method_name):
			target.call(method_name, rule.get("payload", {}))
			report ["hydrated"].append({
				"id": rule_id,
				"target_engine_id": target_engine_id,
				"method": method_name
			})
		elif fallback_method != "" and target.has_method(fallback_method):
			target.call(fallback_method, rule.get("fallback_payload", {}))
			report ["fallback_hydrated"].append({
				"id": rule_id,
				"target_engine_id": target_engine_id,
				"fallback_method": fallback_method
			})
		elif bool(rule.get("required", false)):
			report ["failed"].append({
				"id": rule_id,
				"target_engine_id": target_engine_id,
				"reason": "Required hydration method missing."
			})

	var sync_layer = _ensure_cross_governor_sync_layer()
	var remaining_pending: Dictionary = {}

	for slice_id in pending_save_slices.keys():
		var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
		if save_slice.is_empty():
			orphaned_save_slices [slice_id] = pending_save_slices.get(slice_id, {})
			report ["orphaned"].append({
				"id": str(slice_id),
				"reason": "No save slice contract exists for pending data."
			})
			continue

		var pending_raw: Variant = pending_save_slices.get(slice_id, {})
		var pending_row: Dictionary = pending_raw if typeof(pending_raw) == TYPE_DICTIONARY else { "data": pending_raw}

		if sync_layer != null and sync_layer.has_method("should_hydrate_pending_slice"):
			if not bool(sync_layer.should_hydrate_pending_slice(str(slice_id), pending_row, context)):
				remaining_pending [slice_id] = pending_row.duplicate(true)
				report ["skipped"].append({
					"id": str(slice_id),
					"reason": "Deferred by CrossGovernorSyncLayer.",
					"hydration_mode": str(pending_row.get("hydration_mode", ""))
				})
				continue

		var payload: Variant = pending_row.get("data", {})
		var engine_id: String = str(save_slice.get("engine_id", "")).strip_edges()
		var import_method: String = str(save_slice.get("import_method", "import_state")).strip_edges()
		var hydrate_method: String = str(save_slice.get("hydrate_method", "")).strip_edges()
		var fallback_method: String = str(save_slice.get("fallback_hydration_method", "")).strip_edges()

		var target = get_engine_instance(engine_id)
		if target == null:
			var policy: String = str(save_slice.get("missing_engine_policy", "warn"))
			if policy in ["recover", "fallback"]:
				recover_missing_engines({
					"phase": str(context.get("phase", "hydrate_runtime_state")),
					"target_engine_id": engine_id,
					"reason": "pending_save_slice_target_missing"
				})
				target = get_engine_instance(engine_id)

			if target == null:
				orphaned_save_slices [slice_id] = pending_row.duplicate(true)
				report ["orphaned"].append({
					"id": str(slice_id),
					"engine_id": engine_id,
					"reason": "Pending slice target missing.",
					"policy": policy
				})
				continue

		if import_method != "" and target.has_method(import_method):
			target.call(import_method, payload)
			report ["hydrated"].append({
				"id": str(slice_id),
				"engine_id": engine_id,
				"method": import_method
			})
			continue

		if hydrate_method != "" and target.has_method(hydrate_method):
			target.call(hydrate_method, payload)
			report ["fallback_hydrated"].append({
				"id": str(slice_id),
				"engine_id": engine_id,
				"method": hydrate_method
			})
			continue

		if fallback_method != "" and target.has_method(fallback_method):
			target.call(fallback_method, save_slice.get("fallback_data", {}))
			report ["fallback_hydrated"].append({
				"id": str(slice_id),
				"engine_id": engine_id,
				"method": fallback_method
			})
			continue

		orphaned_save_slices [slice_id] = pending_row.duplicate(true)
		report ["orphaned"].append({
			"id": str(slice_id),
			"engine_id": engine_id,
			"reason": "No compatible import, hydrate, or fallback method exists."
		})

	pending_save_slices = remaining_pending.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["game_state_contract_hydration_report"] = report.duplicate(true)
		gs.scenario_state ["pending_save_slices_remaining"] = pending_save_slices.size()

	return report

func build_active_save_contract(context: Dictionary = {}) -> Dictionary:
	var raw_contract:= {
		"schema": "eralife.save_contract",
		"version": 1,
		"state_id": active_state_id,
		"world_id": str(context.get("world_id", active_state_id)),
		"save_slices": {},
		"policies": {
			"unknown_slice_policy": "orphan_preserve",
			"unknown_field_policy": "preserve",
			"destructive_migration_policy": "block_unless_explicit",
			"device_hydration_policy": "core_identity_first"
		},
		"limits": {
			"max_slices": 256,
			"max_orphaned_slices": 512,
			"max_migration_rules_per_slice": 64,
			"max_slice_bytes": 33554432
		},
		"metadata": {
		}
	}

	for slice_id in save_slice_registry.keys():
		var save_slice_raw: Variant = save_slice_registry.get(slice_id, {})
		if typeof(save_slice_raw) != TYPE_DICTIONARY:
			continue

		var save_slice: Dictionary = save_slice_raw
		var clean_slice_id: String = str(slice_id).strip_edges()
		if clean_slice_id == "":
			continue

		raw_contract ["save_slices"] [clean_slice_id] = {
			"id": clean_slice_id,
			"save_key": str(save_slice.get("save_key", clean_slice_id)).strip_edges(),
			"engine_id": str(save_slice.get("engine_id", "")).strip_edges(),
			"schema": str(save_slice.get("schema", "eralife.save_slice")).strip_edges(),
			"version": int(save_slice.get("version", 1)),
			"target_version": int(save_slice.get("target_version", save_slice.get("version", 1))),
			"min_supported_version": int(save_slice.get("min_supported_version", 1)),
			"policy": str(save_slice.get("save_policy", save_slice.get("policy", "migrate_by_schema"))).strip_edges(),
			"compatibility_mode": str(save_slice.get("compatibility_mode", "bidirectional")).strip_edges(),
			"preserve_unknown_fields": bool(save_slice.get("preserve_unknown_fields", true)),
			"stream_on_demand": bool(save_slice.get("stream_on_demand", false)),
			"allow_destructive_migrations": bool(save_slice.get("allow_destructive_migrations", false)),
			"max_slice_bytes": max(0, int(save_slice.get("max_slice_bytes", 33554432))),
			"migration_rules": save_slice.get("migration_rules", []).duplicate(true) if typeof(save_slice.get("migration_rules", [])) == TYPE_ARRAY else [],
			"metadata": save_slice.get("metadata", {}).duplicate(true) if typeof(save_slice.get("metadata", {})) == TYPE_DICTIONARY else {}
		}

	var governor = _ensure_save_contract_governor()
	var normalized: Dictionary = governor.normalize_save_contract(raw_contract, active_state_id, save_slice_registry)
	save_contract_registry [active_state_id] = normalized.duplicate(true)
	return normalized

func _resolve_active_save_contract_from_payload(data: Dictionary) -> Dictionary:
	var contract_raw: Variant = data.get("save_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		var governor = _ensure_save_contract_governor()
		return governor.normalize_save_contract(contract_raw as Dictionary, active_state_id, save_slice_registry)

	return build_active_save_contract({})
func export_save_slices() -> Dictionary:
	var save_contract: Dictionary = build_active_save_contract({
		"phase": "export_save_slices"
	})

	var out:= {
		"schema": "eralife.game_state_contract_save_slices",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"save_contract": save_contract.duplicate(true),
		"slices": {},
		"orphaned_slices": orphaned_save_slices.duplicate(true),
		"warnings": [],
		"exported_at_ms": int(Time.get_ticks_msec())
	}

	for slice_id in save_slice_registry.keys():
		var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
		if not bool(save_slice.get("enabled", true)):
			continue

		var engine_id: String = str(save_slice.get("engine_id", "")).strip_edges()
		var export_method: String = str(save_slice.get("export_method", "export_state")).strip_edges()
		var save_key: String = str(save_slice.get("save_key", slice_id)).strip_edges()

		if engine_id == "" or save_key == "":
			continue

		var target = get_engine_instance(engine_id)
		if target == null:
			if bool(save_slice.get("required", false)):
				out ["warnings"].append("Required save slice '%s' points to missing engine '%s'." % [slice_id, engine_id])
			if not save_slice.get("fallback_data", {}).is_empty():
				out ["slices"] [save_key] = {
					"id": str(slice_id),
					"save_key": save_key,
					"engine_id": engine_id,
					"schema": str(save_slice.get("schema", "eralife.save_slice")),
					"version": int(save_slice.get("version", 1)),
					"min_supported_version": int(save_slice.get("min_supported_version", 1)),
					"contract_policy": str(save_slice.get("save_policy", save_slice.get("policy", "migrate_by_schema"))),
					"compatibility_mode": str(save_slice.get("compatibility_mode", "bidirectional")),
					"preserve_unknown_fields": bool(save_slice.get("preserve_unknown_fields", true)),
					"stream_on_demand": bool(save_slice.get("stream_on_demand", false)),
					"data": _make_binary_safe(save_slice.get("fallback_data", {})),
					"fallback": true
				}
			continue

		if export_method == "" or not target.has_method(export_method):
			if bool(save_slice.get("required", false)):
				out ["warnings"].append("Required save slice '%s' could not call '%s' on '%s'." % [slice_id, export_method, engine_id])
			if not save_slice.get("fallback_data", {}).is_empty():
				out ["slices"] [save_key] = {
					"id": str(slice_id),
					"save_key": save_key,
					"engine_id": engine_id,
					"schema": str(save_slice.get("schema", "eralife.save_slice")),
					"version": int(save_slice.get("version", 1)),
					"min_supported_version": int(save_slice.get("min_supported_version", 1)),
					"contract_policy": str(save_slice.get("save_policy", save_slice.get("policy", "migrate_by_schema"))),
					"compatibility_mode": str(save_slice.get("compatibility_mode", "bidirectional")),
					"preserve_unknown_fields": bool(save_slice.get("preserve_unknown_fields", true)),
					"stream_on_demand": bool(save_slice.get("stream_on_demand", false)),
					"data": _make_binary_safe(save_slice.get("fallback_data", {})),
					"fallback": true
				}
			continue

		out ["slices"] [save_key] = {
			"id": str(slice_id),
			"save_key": save_key,
			"engine_id": engine_id,
			"schema": str(save_slice.get("schema", "eralife.save_slice")),
			"version": int(save_slice.get("version", 1)),
			"min_supported_version": int(save_slice.get("min_supported_version", 1)),
			"contract_policy": str(save_slice.get("save_policy", save_slice.get("policy", "migrate_by_schema"))),
			"compatibility_mode": str(save_slice.get("compatibility_mode", "bidirectional")),
			"preserve_unknown_fields": bool(save_slice.get("preserve_unknown_fields", true)),
			"stream_on_demand": bool(save_slice.get("stream_on_demand", false)),
			"data": _make_binary_safe(target.call(export_method)),
			"fallback": false
		}

	var governor = _ensure_save_contract_governor()
	var governed: Dictionary = governor.govern_export_save_slices(out, save_contract, save_slice_registry)
	var payload_raw: Variant = governed.get("payload", out)
	if typeof(payload_raw) == TYPE_DICTIONARY:
		out = payload_raw as Dictionary

	last_save_contract_governor_report = governed.get("report", {}).duplicate(true) if typeof(governed.get("report", {})) == TYPE_DICTIONARY else {}

	if gs != null:
		gs.game_state_contract_slices = out.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["save_contract_governor_report"] = last_save_contract_governor_report.duplicate(true)
			gs.scenario_state ["active_save_contract"] = save_contract.duplicate(true)

	return _make_binary_safe(out)


func import_save_slices(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var save_contract: Dictionary = _resolve_active_save_contract_from_payload(data)
	var governor = _ensure_save_contract_governor()
	var governed_import: Dictionary = governor.govern_import_save_slices(data, save_contract, save_slice_registry, orphaned_save_slices)

	var governed_slices_raw: Variant = governed_import.get("slices", {})
	if typeof(governed_slices_raw) != TYPE_DICTIONARY:
		return

	var orphaned_raw: Variant = governed_import.get("orphaned_slices", orphaned_save_slices)
	if typeof(orphaned_raw) == TYPE_DICTIONARY:
		orphaned_save_slices = (orphaned_raw as Dictionary).duplicate(true)

	last_save_contract_governor_report = governed_import.get("report", {}).duplicate(true) if typeof(governed_import.get("report", {})) == TYPE_DICTIONARY else {}

	var report:= {
		"schema": "eralife.game_state_contract_migration_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"governor": last_save_contract_governor_report.duplicate(true),
		"migrated": [],
		"unchanged": [],
		"orphaned": [],
		"failed": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	var slices: Dictionary = governed_slices_raw
	for save_key in slices.keys():
		var row_raw: Variant = slices.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			report ["failed"].append({
				"save_key": str(save_key),
				"reason": "Save slice row is not a Dictionary."
			})
			continue

		var row: Dictionary = row_raw
		var slice_id: String = str(row.get("id", save_key)).strip_edges()
		var payload: Variant = row.get("data", {})
		var saved_version: int = max(1, int(row.get("version", 1)))

		var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
		if save_slice.is_empty():
			orphaned_save_slices [slice_id] = row.duplicate(true)
			report ["orphaned"].append({
				"id": slice_id,
				"save_key": str(save_key),
				"reason": "No active save slice contract exists for this data."
			})
			continue

		var target_version: int = max(1, int(save_slice.get("version", 1)))
		var min_supported_version: int = max(1, int(save_slice.get("min_supported_version", 1)))

		var governor_contract_raw: Variant = row.get("governor_contract", {})
		var governor_contract: Dictionary = governor_contract_raw.duplicate(true) if typeof(governor_contract_raw) == TYPE_DICTIONARY else {}

		var migration_permission: Dictionary = governor.can_migrate_slice(slice_id, saved_version, target_version, save_slice, governor_contract)
		if not bool(migration_permission.get("allowed", true)):
			orphaned_save_slices [slice_id] = row.duplicate(true)
			report ["orphaned"].append({
				"id": slice_id,
				"save_key": str(save_key),
				"from_version": saved_version,
				"to_version": target_version,
				"reason": str(migration_permission.get("reason", "Migration blocked by save contract governor."))
			})
			continue

		if saved_version < min_supported_version:
			var fallback_data: Dictionary = save_slice.get("fallback_data", {})
			if not fallback_data.is_empty():
				payload = fallback_data.duplicate(true)
				report ["migrated"].append({
					"id": slice_id,
					"save_key": str(save_key),
					"from_version": saved_version,
					"to_version": target_version,
					"strategy": "fallback_data_due_to_unsupported_old_version"
				})
			else:
				orphaned_save_slices [slice_id] = row.duplicate(true)
				report ["orphaned"].append({
					"id": slice_id,
					"save_key": str(save_key),
					"from_version": saved_version,
					"min_supported_version": min_supported_version,
					"reason": "Saved slice is older than min_supported_version and no fallback_data exists."
				})
				continue
		elif saved_version != target_version:
			var migrated_payload: Variant = migrate_save_slice_data(slice_id, payload, saved_version, target_version)
			payload = migrated_payload
			report ["migrated"].append({
				"id": slice_id,
				"save_key": str(save_key),
				"from_version": saved_version,
				"to_version": target_version,
				"strategy": "contract_governed_migration_rules"
			})
		else:
			report ["unchanged"].append({
				"id": slice_id,
				"save_key": str(save_key),
				"version": saved_version
			})

		pending_save_slices [slice_id] = {
			"id": slice_id,
			"save_key": str(save_key),
			"saved_version": saved_version,
			"target_version": target_version,
			"hydration_mode": str(row.get("hydration_mode", "runtime_pending")),
			"governor_policy": str(row.get("governor_policy", row.get("contract_policy", "migrate_by_schema"))),
			"governor_contract": governor_contract.duplicate(true),
			"data": payload
		}

	last_migration_report = report.duplicate(true)

	var sync_report: Dictionary = sync_cross_governors({
		"phase": "post_import_save_slices",
		"source": "import_save_slices",
		"save_version": int(data.get("save_version", 0)),
		"pending_save_slice_count": pending_save_slices.size()
	})

	if gs != null:
		gs.game_state_contract_slices = data.duplicate(true)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["game_state_contract_migration_report"] = report.duplicate(true)
			gs.scenario_state ["save_contract_governor_report"] = last_save_contract_governor_report.duplicate(true)
			gs.scenario_state ["cross_governor_sync_report"] = sync_report.duplicate(true)
			gs.scenario_state ["orphaned_save_slices"] = orphaned_save_slices.duplicate(true)


func export_registry() -> Dictionary:
	contract_runtime_manifest = _build_contract_runtime_manifest()

	return _make_binary_safe({
		"schema": "eralife.game_state_contract_registry",
		"version": CONTRACT_VERSION,
		"registry_format_version": CONTRACT_VERSION,
		"active_state_id": active_state_id,
		"contract_registry": contract_registry.duplicate(true),
		"engine_registry": engine_registry.duplicate(true),
		"engine_identity_registry": engine_identity_registry.duplicate(true),
		"contract_runtime_manifest": contract_runtime_manifest.duplicate(true),
		"runtime_capability_registry": runtime_capability_registry.duplicate(true),
		"adaptive_resolution_registry": adaptive_resolution_registry.duplicate(true),
		"world_streaming_manifest": world_streaming_manifest.duplicate(true),
		"launch_link_registry": launch_link_registry.duplicate(true),
		"portable_save_capsule_registry": portable_save_capsule_registry.duplicate(true),
		"multiplayer_world_runtime_registry": multiplayer_world_runtime_registry.duplicate(true),
		"live_contract_hot_swap_ledger": live_contract_hot_swap_ledger.duplicate(true),
		"runtime_capability_profile": runtime_capability_profile.duplicate(true),
		"last_capability_resolution_report": last_capability_resolution_report.duplicate(true),
		"last_adaptive_resolution_report": last_adaptive_resolution_report.duplicate(true),
		"last_streaming_boot_report": last_streaming_boot_report.duplicate(true),
		"last_portable_save_capsule_report": last_portable_save_capsule_report.duplicate(true),
		"last_multiplayer_runtime_report": last_multiplayer_runtime_report.duplicate(true),
		"last_live_contract_hot_swap_report": last_live_contract_hot_swap_report.duplicate(true),
		"save_slice_registry": save_slice_registry.duplicate(true),
		"save_contract_registry": save_contract_registry.duplicate(true),
		"last_save_contract_governor_report": last_save_contract_governor_report.duplicate(true),
		"last_cross_governor_sync_report": last_cross_governor_sync_report.duplicate(true),
		"cross_device_continuity_registry": cross_device_continuity_registry.duplicate(true),
		"last_cross_device_continuity_report": last_cross_device_continuity_report.duplicate(true),
		"runtime_phase_registry": runtime_phase_registry.duplicate(true),
		"event_subscription_registry": event_subscription_registry.duplicate(true),
		"event_bus_contract_registry": event_bus_contract_registry.duplicate(true),
		"meta_contract_registry": meta_contract_registry.duplicate(true),
		"hydration_registry": hydration_registry.duplicate(true),
		"validation_reports": validation_reports.duplicate(true),
		"pack_file_mtimes": pack_file_mtimes.duplicate(true),
		"pending_save_slices": pending_save_slices.duplicate(true),
		"orphaned_save_slices": orphaned_save_slices.duplicate(true),
		"runtime_guard": runtime_guard.duplicate(true),
		"last_boot_report": last_boot_report.duplicate(true),
		"last_validation_report": last_validation_report.duplicate(true),
		"last_migration_report": last_migration_report.duplicate(true),
		"last_recovery_report": last_recovery_report.duplicate(true),
		"last_meta_governor_report": last_meta_governor_report.duplicate(true),
		"last_conflict_report": last_conflict_report.duplicate(true),
		"runtime_phase_budget_report": runtime_phase_budget_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	})


func import_registry(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	active_state_id = str(data.get("active_state_id", active_state_id)).strip_edges()
	if active_state_id == "":
		active_state_id = DEFAULT_STATE_ID

	var contracts_raw: Variant = data.get("contract_registry", {})
	if typeof(contracts_raw) == TYPE_DICTIONARY:
		contract_registry = (contracts_raw as Dictionary).duplicate(true)

	var engines_raw: Variant = data.get("engine_registry", {})
	if typeof(engines_raw) == TYPE_DICTIONARY:
		engine_registry = (engines_raw as Dictionary).duplicate(true)

	var identities_raw: Variant = data.get("engine_identity_registry", {})
	if typeof(identities_raw) == TYPE_DICTIONARY:
		engine_identity_registry = (identities_raw as Dictionary).duplicate(true)

	var manifest_raw: Variant = data.get("contract_runtime_manifest", {})
	if typeof(manifest_raw) == TYPE_DICTIONARY:
		contract_runtime_manifest = (manifest_raw as Dictionary).duplicate(true)
	var capability_registry_raw: Variant = data.get("runtime_capability_registry", {})
	if typeof(capability_registry_raw) == TYPE_DICTIONARY:
		runtime_capability_registry = (capability_registry_raw as Dictionary).duplicate(true)

	var adaptive_registry_raw: Variant = data.get("adaptive_resolution_registry", {})
	if typeof(adaptive_registry_raw) == TYPE_DICTIONARY:
		adaptive_resolution_registry = (adaptive_registry_raw as Dictionary).duplicate(true)

	var streaming_raw: Variant = data.get("world_streaming_manifest", {})
	if typeof(streaming_raw) == TYPE_DICTIONARY:
		world_streaming_manifest = (streaming_raw as Dictionary).duplicate(true)

	var links_raw: Variant = data.get("launch_link_registry", {})
	if typeof(links_raw) == TYPE_DICTIONARY:
		launch_link_registry = (links_raw as Dictionary).duplicate(true)
	var capsule_registry_raw: Variant = data.get("portable_save_capsule_registry", {})
	if typeof(capsule_registry_raw) == TYPE_DICTIONARY:
		portable_save_capsule_registry = (capsule_registry_raw as Dictionary).duplicate(true)
	var continuity_registry_raw: Variant = data.get("cross_device_continuity_registry", {})
	if typeof(continuity_registry_raw) == TYPE_DICTIONARY:
		cross_device_continuity_registry = (continuity_registry_raw as Dictionary).duplicate(true)

	var continuity_report_raw: Variant = data.get("last_cross_device_continuity_report", {})
	if typeof(continuity_report_raw) == TYPE_DICTIONARY:
		last_cross_device_continuity_report = (continuity_report_raw as Dictionary).duplicate(true)
	var multiplayer_registry_raw: Variant = data.get("multiplayer_world_runtime_registry", {})
	if typeof(multiplayer_registry_raw) == TYPE_DICTIONARY:
		multiplayer_world_runtime_registry = (multiplayer_registry_raw as Dictionary).duplicate(true)

	var hot_swap_ledger_raw: Variant = data.get("live_contract_hot_swap_ledger", [])
	if typeof(hot_swap_ledger_raw) == TYPE_ARRAY:
		live_contract_hot_swap_ledger = (hot_swap_ledger_raw as Array).duplicate(true)
	var capability_profile_raw: Variant = data.get("runtime_capability_profile", {})
	if typeof(capability_profile_raw) == TYPE_DICTIONARY:
		runtime_capability_profile = (capability_profile_raw as Dictionary).duplicate(true)

	var capability_report_raw: Variant = data.get("last_capability_resolution_report", {})
	if typeof(capability_report_raw) == TYPE_DICTIONARY:
		last_capability_resolution_report = (capability_report_raw as Dictionary).duplicate(true)

	var adaptive_report_raw: Variant = data.get("last_adaptive_resolution_report", {})
	if typeof(adaptive_report_raw) == TYPE_DICTIONARY:
		last_adaptive_resolution_report = (adaptive_report_raw as Dictionary).duplicate(true)

	var streaming_report_raw: Variant = data.get("last_streaming_boot_report", {})
	if typeof(streaming_report_raw) == TYPE_DICTIONARY:
		last_streaming_boot_report = (streaming_report_raw as Dictionary).duplicate(true)
	var capsule_report_raw: Variant = data.get("last_portable_save_capsule_report", {})
	if typeof(capsule_report_raw) == TYPE_DICTIONARY:
		last_portable_save_capsule_report = (capsule_report_raw as Dictionary).duplicate(true)

	var multiplayer_report_raw: Variant = data.get("last_multiplayer_runtime_report", {})
	if typeof(multiplayer_report_raw) == TYPE_DICTIONARY:
		last_multiplayer_runtime_report = (multiplayer_report_raw as Dictionary).duplicate(true)

	var hot_swap_report_raw: Variant = data.get("last_live_contract_hot_swap_report", {})
	if typeof(hot_swap_report_raw) == TYPE_DICTIONARY:
		last_live_contract_hot_swap_report = (hot_swap_report_raw as Dictionary).duplicate(true)
	var slices_raw: Variant = data.get("save_slice_registry", {})
	if typeof(slices_raw) == TYPE_DICTIONARY:
		save_slice_registry = (slices_raw as Dictionary).duplicate(true)
	var save_contracts_raw: Variant = data.get("save_contract_registry", {})
	if typeof(save_contracts_raw) == TYPE_DICTIONARY:
		save_contract_registry = (save_contracts_raw as Dictionary).duplicate(true)

	var save_governor_report_raw: Variant = data.get("last_save_contract_governor_report", {})
	if typeof(save_governor_report_raw) == TYPE_DICTIONARY:
		last_save_contract_governor_report = (save_governor_report_raw as Dictionary).duplicate(true)
	var cross_governor_report_raw: Variant = data.get("last_cross_governor_sync_report", {})
	if typeof(cross_governor_report_raw) == TYPE_DICTIONARY:
		last_cross_governor_sync_report = (cross_governor_report_raw as Dictionary).duplicate(true)
	var phases_raw: Variant = data.get("runtime_phase_registry", {})
	if typeof(phases_raw) == TYPE_DICTIONARY:
		runtime_phase_registry = (phases_raw as Dictionary).duplicate(true)

	var subs_raw: Variant = data.get("event_subscription_registry", {})
	if typeof(subs_raw) == TYPE_DICTIONARY:
		event_subscription_registry = (subs_raw as Dictionary).duplicate(true)

	var bus_contracts_raw: Variant = data.get("event_bus_contract_registry", {})
	if typeof(bus_contracts_raw) == TYPE_DICTIONARY:
		event_bus_contract_registry = (bus_contracts_raw as Dictionary).duplicate(true)

	var meta_contracts_raw: Variant = data.get("meta_contract_registry", {})
	if typeof(meta_contracts_raw) == TYPE_DICTIONARY:
		meta_contract_registry = (meta_contracts_raw as Dictionary).duplicate(true)

	var hydration_raw: Variant = data.get("hydration_registry", {})
	if typeof(hydration_raw) == TYPE_DICTIONARY:
		hydration_registry = (hydration_raw as Dictionary).duplicate(true)

	var reports_raw: Variant = data.get("validation_reports", {})
	if typeof(reports_raw) == TYPE_DICTIONARY:
		validation_reports = (reports_raw as Dictionary).duplicate(true)

	var mtimes_raw: Variant = data.get("pack_file_mtimes", {})
	if typeof(mtimes_raw) == TYPE_DICTIONARY:
		pack_file_mtimes = (mtimes_raw as Dictionary).duplicate(true)

	var pending_raw: Variant = data.get("pending_save_slices", {})
	if typeof(pending_raw) == TYPE_DICTIONARY:
		pending_save_slices = (pending_raw as Dictionary).duplicate(true)

	var orphaned_raw: Variant = data.get("orphaned_save_slices", {})
	if typeof(orphaned_raw) == TYPE_DICTIONARY:
		orphaned_save_slices = (orphaned_raw as Dictionary).duplicate(true)

	var guard_raw: Variant = data.get("runtime_guard", {})
	if typeof(guard_raw) == TYPE_DICTIONARY:
		runtime_guard = (guard_raw as Dictionary).duplicate(true)

	var boot_raw: Variant = data.get("last_boot_report", {})
	if typeof(boot_raw) == TYPE_DICTIONARY:
		last_boot_report = (boot_raw as Dictionary).duplicate(true)

	var validation_raw: Variant = data.get("last_validation_report", {})
	if typeof(validation_raw) == TYPE_DICTIONARY:
		last_validation_report = (validation_raw as Dictionary).duplicate(true)

	var migration_raw: Variant = data.get("last_migration_report", {})
	if typeof(migration_raw) == TYPE_DICTIONARY:
		last_migration_report = (migration_raw as Dictionary).duplicate(true)

	var recovery_raw: Variant = data.get("last_recovery_report", {})
	if typeof(recovery_raw) == TYPE_DICTIONARY:
		last_recovery_report = (recovery_raw as Dictionary).duplicate(true)

	var conflict_raw: Variant = data.get("last_conflict_report", {})
	if typeof(conflict_raw) == TYPE_DICTIONARY:
		last_conflict_report = (conflict_raw as Dictionary).duplicate(true)

	var meta_raw: Variant = data.get("last_meta_governor_report", {})
	if typeof(meta_raw) == TYPE_DICTIONARY:
		last_meta_governor_report = (meta_raw as Dictionary).duplicate(true)

	var budget_raw: Variant = data.get("runtime_phase_budget_report", {})
	if typeof(budget_raw) == TYPE_DICTIONARY:
		runtime_phase_budget_report = (budget_raw as Dictionary).duplicate(true)

	engine_identity_registry.clear()

	for state_id in contract_registry.keys():
		var contract_raw: Variant = contract_registry.get(state_id, {})
		if typeof(contract_raw) == TYPE_DICTIONARY:
			_ingest_contract(contract_raw as Dictionary)

	for engine_id in engine_registry.keys():
		var engine_raw: Variant = engine_registry.get(engine_id, {})
		if typeof(engine_raw) == TYPE_DICTIONARY:
			_register_engine_identity_record(engine_raw as Dictionary, str((engine_raw as Dictionary).get("state_id", active_state_id)))

	_ensure_contract_meta_governor()
	if runtime_capability_profile.is_empty():
		resolve_runtime_capability_profile({})

	prepare_world_streaming_boot({
		"phase": "import_registry",
		"source": "import_registry"
	})
	validate_active_contracts({
		"phase": "import_registry",
		"include_runtime": false
	})


func export_runtime_guard() -> Dictionary:
	return runtime_guard.duplicate(true)


func get_debug_report() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.game_state_contract_debug_report",
		"version": CONTRACT_VERSION,
		"active_state_id": active_state_id,
		"contract_count": contract_registry.size(),
		"engine_count": engine_registry.size(),
		"save_slice_count": save_slice_registry.size(),
		"runtime_phase_count": runtime_phase_registry.size(),
		"event_subscription_count": event_subscription_registry.size(),
		"event_bus_contract_count": event_bus_contract_registry.size(),
		"event_bus_contract_registry": event_bus_contract_registry.duplicate(true),
		"meta_contract_count": meta_contract_registry.size(),
		"meta_contract_registry": meta_contract_registry.duplicate(true),
		"last_meta_governor_report": last_meta_governor_report.duplicate(true),
		"hydration_rule_count": hydration_registry.size(),
		"pending_save_slice_count": pending_save_slices.size(),
		"orphaned_save_slice_count": orphaned_save_slices.size(),
		"runtime_guard": runtime_guard.duplicate(true),
		"last_boot_report": last_boot_report.duplicate(true),
		"last_validation_report": last_validation_report.duplicate(true),
		"last_migration_report": last_migration_report.duplicate(true),
		"last_recovery_report": last_recovery_report.duplicate(true),
		"last_conflict_report": last_conflict_report.duplicate(true),
		"runtime_phase_budget_report": runtime_phase_budget_report.duplicate(true)
	})

func yearly_tick(
	payload:= {}
) -> void:
	var context: Dictionary = (
		payload
		if typeof(
			payload
		) == TYPE_DICTIONARY
		else {}
	)

	var runtime_managed_age_up: bool = (
		bool(
			context.get(
				"runtime_managed",
				false
			)
		)
		and str(
			context.get(
				"runtime_owner",
				""
			)
		).strip_edges().to_lower()
		== "age_up_runtime"
	)

	var skip_hot_reload: bool = (
		runtime_managed_age_up
		or bool(
			context.get(
				"skip_game_state_contract_hot_reload",
				false
			)
		)
	)

	if not skip_hot_reload:
		hot_reload_external_contracts(
			false
		)

	validate_active_contracts({
		"phase": "yearly_tick",
		"include_runtime": true,
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"runtime_managed_age_up": runtime_managed_age_up,
		"hot_reload_performed": not skip_hot_reload
	})

	build_runtime_phase_budget_report({
		"phase": "yearly_tick",
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"runtime_managed_age_up": runtime_managed_age_up
	})

	apply_runtime_guards({
		"phase": "yearly_tick",
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"runtime_managed_age_up": runtime_managed_age_up
	})


func _build_default_legacy_contract() -> Dictionary:
	var engines: Array = [
		{
			"id": "reality_snapshot_contract_engine",
			"class": "RealitySnapshotContractEngine",
			"boot_phase": "kernel",
			"boot_order": 1,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"capture_resident_snapshot",
				"validate_snapshot",
				"snapshot_for_signature",
				"has_valid_snapshot",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "reality_projection_contract_engine",
			"class": "RealityProjectionContractEngine",
			"boot_phase": "kernel",
			"boot_order": 2,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"begin_resident_projection",
				"step_resident_projection",
				"projection_status",
				"emit_resident_projection",
				"projection_for_signature",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "reality_residency_manager",
			"class": "RealityResidencyManager",
			"boot_phase": "kernel",
			"boot_order": 3,
			"required": true,



			"auto_save_slice": true,

			"required_methods": [
				"bootstrap_default_contracts",
				"prime_chassis_pool",
				"reserve_reality",
				"service_residency",
				"attach_reality",
				"detach_lens",
				"status_contract",
				"resident_catalog",
				"get_resident_runtime",
				"bind_checkpoint_to_resident_record",
				"bootstrap_default_contracts",
				"capture_resident_snapshot",
				"validate_snapshot",
				"snapshot_for_signature",
				"has_valid_snapshot",
				"bind_checkpoint_to_snapshot",
				"export_state",
				"import_state"
			],
			"metadata": {
			}
		},
		{
			"id": "reality_residency_contract_engine",
			"class": "RealityResidencyContractEngine",
			"boot_phase": "kernel",
			"boot_order": 4,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_residency_contract",
				"export_state",
				"import_state"
			]
		},
		{ "id": "event_bus", "class": "EventBus", "boot_phase": "kernel", "boot_order": 0, "required": true},
		{ "id": "world_space_engine", "class": "WorldSpaceEngine", "boot_phase": "world_structure", "boot_order": 10},
		{ "id": "spatial_culling_engine", "class": "SpatialCullingEngine", "boot_phase": "world_structure", "boot_order": 20},
		{ "id": "emergent_story_engine", "class": "EmergentNPCStoryEngine", "boot_phase": "scenario", "boot_order": 30},
		{ "id": "economy_engine", "class": "EconomyEngine", "boot_phase": "economy_domain", "boot_order": 40},
		{ "id": "bank_engine", "class": "BankEngine", "boot_phase": "economy_domain", "boot_order": 45},
		{ "id": "global_market_engine", "class": "GlobalMarketEngine", "boot_phase": "economy_domain", "boot_order": 50},
		{ "id": "ecs_engine", "class": "ECSEngine", "boot_phase": "kernel", "boot_order": 60},
		{ "id": "chunk_simulation_engine", "class": "ChunkSimulationEngine", "boot_phase": "runtime", "boot_order": 70},
		{ "id": "population_shard_engine", "class": "PopulationShardEngine", "boot_phase": "world_structure", "boot_order": 80},
		{ "id": "population_lifecycle_manager", "class": "PopulationLifecycleManager", "boot_phase": "world_structure", "boot_order": 90},
		{ "id": "geo_engine", "class": "GeoEngine", "boot_phase": "world_structure", "boot_order": 100},
		{ "id": "migration_engine", "class": "MigrationEngine", "boot_phase": "world_structure", "boot_order": 110},
		{ "id": "settlement_presence_engine", "class": "SettlementPresenceEngine", "boot_phase": "world_structure", "boot_order": 120},
		{ "id": "place_influence_engine", "class": "PlaceInfluenceEngine", "boot_phase": "world_structure", "boot_order": 130},
		{ "id": "seed_engine", "class": "SeedEngine", "boot_phase": "kernel", "boot_order": 140},
		{ "id": "social_graph_engine", "class": "SocialGraphEngine", "boot_phase": "identity", "boot_order": 150},
		{ "id": "workplace_engine", "class": "WorkplaceEngine", "boot_phase": "life_domain", "boot_order": 160},
		{ "id": "player_action_engine", "class": "PlayerActionEngine", "boot_phase": "life_domain", "boot_order": 170},
		{ "id": "npc_memory_web_engine", "class": "NPCMemoryWebEngine", "boot_phase": "memory", "boot_order": 180},
		{ "id": "agent_memory_propagation_engine", "class": "AgentMemoryPropagationEngine", "boot_phase": "memory", "boot_order": 190},
		{ "id": "dynamic_world_event_engine", "class": "DynamicWorldEventEngine", "boot_phase": "scenario", "boot_order": 200},
		{ "id": "action_discovery_engine", "class": "ActionDiscoveryEngine", "boot_phase": "life_domain", "boot_order": 210},
		{ "id": "names_db", "class": "NamesDB", "boot_phase": "identity", "boot_order": 220},
		{ "id": "npc_factory", "class": "NPCFactory", "boot_phase": "identity", "boot_order": 230},
		{ "id": "character_creator", "class": "CharacterCreator", "boot_phase": "identity", "boot_order": 240},
		{ "id": "scenario_resolver", "class": "ScenarioResolver", "boot_phase": "scenario", "boot_order": 250},
		{ "id": "scenario_engine", "class": "ScenarioEngine", "boot_phase": "scenario", "boot_order": 260},
		{ "id": "world_engine", "class": "WorldEngine", "boot_phase": "world_structure", "boot_order": 270},
		{ "id": "event_engine", "class": "EventEngine", "boot_phase": "scenario", "boot_order": 280},
		{ "id": "relationship_engine", "class": "RelationshipEngine", "boot_phase": "life_domain", "boot_order": 290},
		{ "id": "memory_engine", "class": "MemoryEngine", "boot_phase": "memory", "boot_order": 300},
		{ "id": "health_engine", "class": "HealthEngine", "boot_phase": "life_domain", "boot_order": 310},
		{ "id": "career_runtime_engine", "class": "CareerRuntimeEngine", "boot_phase": "life_domain", "boot_order": 318},
		{
			"id": "career_contract_engine",
			"class": "CareerContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 319
		},
		{
			"id": "career_space_contract_engine",
			"class": "CareerSpaceContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 320,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_space_contract",
				"move_actor_to_zone",
				"exit_actor_space",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "career_hub_contract_engine",
			"class": "CareerHubContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 321,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"emit_observable_contract",
				"resolve_career_hub",
				"persist_section_lens",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "activities_contract_engine",
			"class": "ActivitiesContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 322,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"emit_hub_contract",
				"emit_observable_contract",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "activities_hub_contract_engine",
			"class": "ActivitiesHubContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 323,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"emit_hub_contract",
				"emit_observable_contract",
				"persist_section_lens",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "mod_contract_engine",
			"class": "ModContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 324,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_from_loader",
				"register_mod_contract",
				"validate_mod_contract",
				"register_provider_contract",
				"rebuild_provider_resolution",
				"compile_enabled_set_snapshot",
				"apply_enabled_set_transaction",
				"resolve_mod_intent",
				"emit_provider_rows",
				"resolve_provider_intent",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "caveman_reality_runtime_engine",
			"class": "CavemanRealityRuntimeEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 325,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"set_bundle_enabled",
				"perform_activity",
				"assign_role",
				"emit_bundle_menu_contract",
				"yearly_tick",
				"on_npc_born",
				"on_npc_died",
				"repair_state",
				"self_heal",
				"export_state",
				"import_state"
			],
			"metadata": {
				"bundle_id": "eralife.caveman_reality_pack",
				"experience_id": (
					"eralife.experience.caveman_survival"
				),
				"identity_safe": true,
				"ui_projection_mode": (
					"complete_contract_only"
				)
			}
		},
		{
			"id": "mod_bundle_contract_engine",
			"class": "ModBundleContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 326,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"register_bundle_contract",
				"validate_bundle_contract",
				"install_bundle",
				"install_bundle_component",
				"remove_bundle_component",
				"prewarm_bundle_toggle",
				"set_bundle_enabled",
				"uninstall_bundle",
				"resolve_bundle_service_intent",
				"bundle_catalog_rows",
				"bundle_summaries",
				"bundle_menu_contract",
				"active_experience_contract",
				"resolve_intent",
				"self_heal",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "mod_marketplace_contract_engine",
			"class": "ModMarketplaceContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 327,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"fetch_available_mods",
				"install_mod",
				"uninstall_mod",
				"check_compatibility",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "mod_hub_contract_engine",
			"class": "ModHubContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 328,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"emit_observable_contract",
				"emit_mod_hub_contract",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "mod_menu_contract_engine",
			"class": "ModMenuContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 329,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"resolve_intent",
				"emit_observable_contract",
				"emit_menu_contract",
				"export_state",
				"import_state"
			]
		},
		{ "id": "career_engine", "class": "CareerEngine", "boot_phase": "life_domain", "boot_order": 320},
		{ "id": "school_engine", "class": "SchoolEngine", "boot_phase": "life_domain", "boot_order": 330},
		{ "id": "family_contract_engine", "class": "FamilyContractEngine", "boot_phase": "life_domain", "boot_order": 335},
		{ "id": "family_control_engine", "class": "FamilyControlEngine", "boot_phase": "life_domain", "boot_order": 340},
		{ "id": "fate_engine", "class": "FateEngine", "boot_phase": "life_domain", "boot_order": 350},
		{ "id": "life_engine", "class": "LifeEngine", "boot_phase": "life_domain", "boot_order": 360},
		{ "id": "narrative_governor", "class": "NarrativeGovernor", "boot_phase": "scenario", "boot_order": 365},
		{ "id": "perceptual_integrity_engine", "class": "PerceptualIntegrityEngine", "boot_phase": "scenario", "boot_order": 365, "required": false,
		"auto_save_slice": true,
		"required_methods": [
			"evaluate_candidate",
			"accept_candidate",
			"register_used_moment_identity",
			"export_state",
			"import_state"
		]},
		{ "id": "lineage_engine", "class": "LineageEngine", "boot_phase": "scenario", "boot_order": 365},
		{ "id": "choose_adventure_ai_node_generator", "class": "ChooseAdventureAINodeGenerator", "boot_phase": "scenario", "boot_order": 366},
		{ "id": "choose_adventure_scenario_engine", "class": "ChooseAdventureScenarioEngine", "boot_phase": "scenario", "boot_order": 367},
		{ "id": "choose_adventure_engine", "class": "ChooseAdventureEngine", "boot_phase": "scenario", "boot_order": 368},
		{ "id": "narrative_engine", "class": "NarrativeEngine", "boot_phase": "scenario", "boot_order": 370},

		{ "id": "boxing_contract_engine", "class": "BoxingContractEngine", "boot_phase": "life_domain", "boot_order": 371},
		{ "id": "boxing_combat_resolution_engine", "class": "BoxingCombatResolutionEngine", "boot_phase": "life_domain", "boot_order": 371},
		{ "id": "boxing_fight_economy_engine", "class": "BoxingFightEconomyEngine", "boot_phase": "economy_domain", "boot_order": 372},
		{ "id": "boxing_engine", "class": "BoxingEngine", "boot_phase": "life_domain", "boot_order": 373},
		{ "id": "boxing_fighter_engine", "class": "BoxingFighterEngine", "boot_phase": "life_domain", "boot_order": 374},
		{ "id": "boxing_training_engine", "class": "BoxingTrainingEngine", "boot_phase": "life_domain", "boot_order": 375},
		{ "id": "boxing_matchmaking_engine", "class": "BoxingMatchmakingEngine", "boot_phase": "life_domain", "boot_order": 376},
		{ "id": "boxing_fight_sim_engine", "class": "BoxingFightSimEngine", "boot_phase": "life_domain", "boot_order": 377},
		{ "id": "boxing_ranking_engine", "class": "BoxingRankingEngine", "boot_phase": "life_domain", "boot_order": 378},
		{ "id": "boxing_title_engine", "class": "BoxingTitleEngine", "boot_phase": "life_domain", "boot_order": 379},
		{ "id": "boxing_injury_engine", "class": "BoxingInjuryEngine", "boot_phase": "life_domain", "boot_order": 379},
		{ "id": "boxing_round_log_engine", "class": "BoxingRoundLogEngine", "boot_phase": "life_domain", "boot_order": 381},
		{ "id": "boxing_rivalry_engine", "class": "BoxingRivalryEngine", "boot_phase": "life_domain", "boot_order": 382},
		{ "id": "boxing_gym_engine", "class": "BoxingGymEngine", "boot_phase": "life_domain", "boot_order": 383},
		{ "id": "boxing_promotion_engine", "class": "BoxingPromotionEngine", "boot_phase": "life_domain", "boot_order": 384},
		{ "id": "boxing_weight_engine", "class": "BoxingWeightEngine", "boot_phase": "life_domain", "boot_order": 385},
		{ "id": "boxing_mandatory_engine", "class": "BoxingMandatoryEngine", "boot_phase": "life_domain", "boot_order": 385},
		{ "id": "boxing_amateur_engine", "class": "BoxingAmateurEngine", "boot_phase": "life_domain", "boot_order": 386},
		{ "id": "boxing_media_engine", "class": "BoxingMediaEngine", "boot_phase": "life_domain", "boot_order": 387},
		{ "id": "boxing_legacy_engine", "class": "BoxingLegacyEngine", "boot_phase": "life_domain", "boot_order": 388},
		{ "id": "bending_engine", "class": "BendingEngine", "boot_phase": "supernatural_domain", "boot_order": 380},
		{ "id": "bending_tournament_engine", "class": "BendingTournamentEngine", "boot_phase": "supernatural_domain", "boot_order": 381},
		{ "id": "reality_orchestrator", "class": "RealityOrchestrator", "boot_phase": "runtime", "boot_order": 381, "required": true, "auto_save_slice": true,
		"required_methods": [
			"bootstrap_default_contracts",
			"orchestrate_intent",
			"route_command_envelope",
			"export_state",
			"import_state"
		]},
		{ "id": "wizard_engine", "class": "WizardEngine", "boot_phase": "supernatural_domain", "boot_order": 382},
		{ "id": "dynasty_engine", "class": "DynastyEngine", "boot_phase": "life_domain", "boot_order": 390},
		{ "id": "era_engine", "class": "EraEngine", "boot_phase": "world_structure", "boot_order": 400, "required": true},
		{
			"id": "era_contract_engine",
			"class": "EraContractEngine",
			"boot_phase": "world_domain",
			"boot_order": 401,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"refresh_base_registry",
				"choose_era",
				"resolve_base_era_from_year",
				"current_base_era_contract",
				"current_era_contract",
				"apply_active_overlay",
				"reconcile_effective_reality",
				"system_policy",
				"presentation_contract",
				"world_taxonomy_contract",
				"birth_narrative_contract",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "era_mod_contract_engine",
			"class": "EraModContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 402,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"rebuild_provider_cache",
				"active_era_overlay",
				"active_presentation_contract",
				"active_world_taxonomy",
				"active_system_policy",
				"active_role_contracts",
				"active_governance_contract",
				"active_economy_contract",
				"active_fauna_contracts",
				"active_birth_narrative",
				"bundle_menu_provider",
				"resolve_provider_intent",
				"export_state",
				"import_state"
			]
		},
		{ "id": "world_feed_engine", "class": "WorldFeedEngine", "boot_phase": "scenario", "boot_order": 410},
		{ "id": "world_chronicle_engine", "class": "WorldChronicleEngine", "boot_phase": "memory", "boot_order": 420},
		{ "id": "reputation_engine", "class": "ReputationEngine", "boot_phase": "life_domain", "boot_order": 430},
		{
			"id": "artifacts_engine",
			"class": "ArtifactsEngine",
			"boot_phase": "supernatural_domain",
			"boot_order": 440
		},
		{
			"id": "artifacts_catalog_contract_engine",
			"class": "ArtifactsCatalogContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 441,
			"required": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"provider_contract",
				"get_available_objects",
				"get_object_contract"
			],
			"metadata": {
				"truth_authority": "artifacts_engine",
				"universal_object_domain": "artifact"
			}
		},
		{
			"id": "artifact_interaction_contract_engine",
			"class": "ArtifactInteractionContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 442,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_observability_contract",
				"emit_item_projection",
				"artifact_action_specs",
				"artifact_market_profile",
				"red_bonnet_wishes",
				"wish_requires_target",
				"last_red_bonnet_action_result",
				"export_state",
				"import_state"
			],
			"metadata": {
				"artifact_truth_authority": "artifacts_engine",
				"red_bonnet_truth_authority": "red_bonnet_engine",
				"ui_is_renderer_only": true
			}
		},
		{
			"id": "artifact_shop_contract_engine",
			"class": "ArtifactShopContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 443,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_shop_contract",
				"action_specs_for_item",
				"owned_stone_count",
				"actor_has_all_stones",
				"artifact_signature_for_actor",
				"market_profile_for_item",
				"export_state",
				"import_state"
			],
			"metadata": {
				"interaction_authority": (
					"artifact_interaction_contract_engine"
				),
				"catalog_authority": (
					"artifacts_catalog_contract_engine"
				)
			}
		},
		{
			"id": "realm_contract_engine",
			"class": "RealmContractEngine",
			"boot_phase": "realm_domain",
			"boot_order": 450
		},
		{ "id": "simulation_contract_engine", "class": "SimulationContractEngine", "boot_phase": "kernel", "boot_order": 460},
		{ "id": "ui_contract_engine", "class": "UIContractEngine", "boot_phase": "kernel", "boot_order": 470},
		{ "id": "many_realms_engine", "class": "ManyRealmsEngine", "boot_phase": "realm_domain", "boot_order": 480},
		{ "id": "bridge_to_terabithia_engine", "class": "BridgeToTerabithiaEngine", "boot_phase": "realm_domain", "boot_order": 490},
		{ "id": "vormir_engine", "class": "VormirEngine", "boot_phase": "realm_domain", "boot_order": 500},
		{ "id": "nidavellir_engine", "class": "NidavellirEngine", "boot_phase": "realm_domain", "boot_order": 510},
		{ "id": "dragonballs_engine", "class": "DragonBallsEngine", "boot_phase": "supernatural_domain", "boot_order": 520},
		{
			"id": "weapons_catalog_expansion",
			"class": "WeaponsCatalogExpansion",
			"boot_phase": "domain_extensions",
			"boot_order": 521,
			"required": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"provider_contract",
				"get_available_objects",
				"get_object_contract",
				"resolve_weapon_definition",
				"purchase_definition_from_object"
			],
			"metadata": {
				"truth_authority": "weapons_engine",
				"universal_object_domain": "weapon"
			}
		},
		{ "id": "realm_engine", "class": "RealmEngine", "boot_phase": "realm_domain", "boot_order": 530, "required": true},
		{ "id": "class_engine", "class": "ClassEngine", "boot_phase": "life_domain", "boot_order": 540},
		{
			"id": "fame_engine",
			"class": "FameEngine",
			"boot_phase": "life_domain",
			"boot_order": 550
		},
		{
			"id": "royalty_runtime_engine",
			"class": "RoyaltyRuntimeEngine",
			"boot_phase": "realm_domain",
			"boot_order": 556,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"ensure_world_institutions",
				"ingest_actor",
				"institution_for_actor",
				"institution_for_realm",
				"commit_abdication",
				"appoint_heir",
				"commit_coronation",
				"establish_regency",
				"end_regency",
				"repair_state",
				"self_heal",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "royalty_mod_contract_engine",
			"class": "RoyaltyModContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 557,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"register_royalty_provider",
				"validate_royalty_provider",
				"rebuild_provider_cache",
				"emit_provider_rows",
				"resolve_provider_intent",
				"repair_state",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "royalty_contract_engine",
			"class": "RoyaltyContractEngine",
			"boot_phase": "realm_domain",
			"boot_order": 558,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"register_constitutional_contract",
				"validate_constitutional_contract",
				"resolve_intent",
				"evaluate_succession_for_institution",
				"permissions_for_actor",
				"summary_for_actor",
				"self_heal",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "crown_hub_contract_engine",
			"class": "CrownHubContractEngine",
			"boot_phase": "realm_domain",
			"boot_order": 559,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_observable_contract",
				"emit_crown_hub_contract",
				"persist_section_lens",
				"export_state",
				"import_state"
			]
		},
		{
			"id": "royalty_engine",
			"class": "RoyaltyEngine",
			"boot_phase": "realm_domain",
			"boot_order": 560,
			"required": true,
			"metadata": {
				"compatibility_facade": true,
				"constitutional_authority": (
					"royalty_contract_engine"
				),
				"runtime_authority": (
					"royalty_runtime_engine"
				),
				"ui_projection_authority": (
					"crown_hub_contract_engine"
				)
			}
		},
		{
			"id": "politics_engine",
			"class": "PoliticsEngine",
			"boot_phase": "realm_domain",
			"boot_order": 570
		},
		{
			"id": "heirloom_runtime_engine",
			"class": "HeirloomRuntimeEngine",
			"boot_phase": "life_domain",
			"boot_order": 574,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"commit_purchase",
				"commit_designation",
				"commit_transfer",
				"commit_estate_transfer",
				"commit_dispute",
				"resolve_dispute",
				"yearly_tick",
				"records_for_actor",
				"record_for_object",
				"disputes_for_actor",
				"repair_from_legacy_state",
				"export_state",
				"import_state"
			],
			"metadata": {
				"physical_object_authority": "belongings_engine",
				"ui_projection_authority": (
					"heirloom_hub_contract_engine"
				),
				"legacy_facade": "heirloom_engine"
			}
		},
		{
			"id": "heirloom_contract_engine",
			"class": "HeirloomContractEngine",
			"boot_phase": "life_domain",
			"boot_order": 575,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"register_heirloom_definition",
				"get_catalog_definitions",
				"resolve_intent",
				"generate_purchase_definition",
				"evaluate_purchase",
				"evaluate_designation",
				"evaluate_transfer",
				"evaluate_dispute",
				"yearly_tick",
				"permissions_for_actor",
				"export_state",
				"import_state"
			],
			"metadata": {
				"constitutional_authority": true,
				"runtime_authority": "heirloom_runtime_engine",
				"ui_is_renderer_only": true
			}
		},
		{
			"id": "heirloom_engine",
			"class": "HeirloomEngine",
			"boot_phase": "life_domain",
			"boot_order": 576,
			"required": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"buy_heirloom",
				"resolve_intent",
				"transfer_heirloom",
				"designate_heirloom",
				"contest_heirloom",
				"yearly_tick",
				"export_state",
				"import_state"
			],
			"metadata": {
				"compatibility_facade": true,
				"runtime_authority": "heirloom_runtime_engine",
				"constitutional_authority": (
					"heirloom_contract_engine"
				),
			}
		},
		{
			"id": "heirloom_catalog_contract_engine",
			"class": "HeirloomCatalogContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 577,
			"required": true,
			"required_methods": [
				"bootstrap_default_contracts",
				"provider_contract",
				"get_available_objects",
				"get_object_contract"
			],
			"metadata": {
				"truth_authority": "heirloom_runtime_engine",
				"constitutional_authority": (
					"heirloom_contract_engine"
				),
				"owned_instance_authority": "belongings_engine",
				"universal_object_domain": "heirloom"
			}
		},
		{
			"id": "heirloom_hub_contract_engine",
			"class": "HeirloomHubContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 578,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_observable_contract",
				"emit_heirloom_hub_contract",
				"export_state",
				"import_state"
			],
			"metadata": {
				"runtime_authority": "heirloom_runtime_engine",
				"constitutional_authority": (
					"heirloom_contract_engine"
				)
			}
		},
		{
			"id": "belongings_engine",
			"class": "BelongingsEngine",
			"boot_phase": "life_domain",
			"boot_order": 580
		},
		{
			"id": "global_object_catalog_system",
			"class": "GlobalObjectCatalogSystem",
			"boot_phase": "domain_extensions",
			"boot_order": 581,
			"required": true,
			"auto_save_slice": true,
			"required_methods": [
				"bootstrap_default_providers",
				"register_catalog_provider",
				"get_available_objects",
				"resolve_object",
				"get_object_actions",
				"get_object_history",
				"emit_object_lens_contract",
				"export_state",
				"import_state"
			],
			"metadata": {
				"owned_instance_authority": "belongings_engine",
			}
		},
		{
			"id": "object_hub_contract_engine",
			"class": "ObjectHubContractEngine",
			"boot_phase": "domain_extensions",
			"boot_order": 582,
			"required": true,
			"auto_save_slice": false,
			"required_methods": [
				"bootstrap_default_contracts",
				"resolve_intent",
				"emit_observable_contract",
				"emit_object_hub_contract",
				"export_state",
				"import_state"
			],
			"metadata": {
				"catalog_authority": (
					"global_object_catalog_system"
				),
				"ui_is_renderer_only": true
			}
		},
		{
			"id": "simulation_director",
			"class": "SimulationDirector",
			"boot_phase": "runtime",
			"boot_order": 590
		},
		{ "id": "year_budget_engine", "class": "YearBudgetEngine", "boot_phase": "runtime", "boot_order": 600},
		{ "id": "universal_faction_engine", "class": "UniversalFactionEngine", "boot_phase": "realm_domain", "boot_order": 610},
		{ "id": "runtime_health_registry", "class": "RuntimeHealthRegistry", "boot_phase": "diagnostics", "boot_order": 620},
		{ "id": "runtime_fault_router", "class": "RuntimeFaultRouter", "boot_phase": "diagnostics", "boot_order": 630},
		{ "id": "live_diagnostics_engine", "class": "LiveDiagnosticsEngine", "boot_phase": "diagnostics", "boot_order": 640}
	]

	var save_slices: Array = [
		{
			"id": "realm_contract_registry",
			"save_key": "realm_contract_registry",
			"engine_id": "realm_contract_engine",
			"export_method": "export_registry",
			"import_method": "import_registry",
			"schema": "eralife.realm_contract_registry",
			"version": 1
		},
		{
			"id": "simulation_contract_registry",
			"save_key": "simulation_contract_registry",
			"engine_id": "simulation_contract_engine",
			"export_method": "export_registry",
			"import_method": "import_registry",
			"schema": "eralife.simulation_contract_registry",
			"version": 1
		},
		{
			"id": "ui_contract_registry",
			"save_key": "ui_contract_registry",
			"engine_id": "ui_contract_engine",
			"export_method": "export_registry",
			"import_method": "import_registry",
			"schema": "eralife.ui_contract_registry",
			"version": 1
		},
		{
			"id": "perceptual_integrity_engine_state",
			"save_key": "perceptual_integrity_engine_state",
			"engine_id": "perceptual_integrity_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.perceptual_integrity_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "bank_engine_state",
			"save_key": "bank_engine_state",
			"engine_id": "bank_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.bank_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"money_authority": "bank_engine",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "crime_contract_engine_state",
			"save_key": "crime_contract_engine_state",
			"engine_id": "crime_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.crime_contract_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "investigation_layer_state",
			"save_key": "investigation_layer_state",
			"engine_id": "investigation_layer",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.investigation_layer_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "justice_system_engine_state",
			"save_key": "justice_system_engine_state",
			"engine_id": "justice_system_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.justice_system_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"judgment_authority": "justice_system_engine",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "jail_engine_state",
			"save_key": "jail_engine_state",
			"engine_id": "jail_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.jail_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "prison_engine_state",
			"save_key": "prison_engine_state",
			"engine_id": "prison_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.prison_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "case_orchestrator_state",
			"save_key": "case_orchestrator_state",
			"engine_id": "case_orchestrator",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.case_orchestrator_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "food_engine_state",
			"save_key": "food_engine_state",
			"engine_id": "food_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.food_engine_state",
			"version": 1,
			"metadata": {
			"hydration_lane": "core",
			"food_authority": "food_engine",
			"preserve_unknown_fields": true,
			"backwards_compatible": true
			}
		},
		{
			"id": "food_restaurant_engine_state",
			"save_key": "food_restaurant_engine_state",
			"engine_id": "food_restaurant_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.food_restaurant_engine_state",
			"version": 1,
			"metadata": {
			"hydration_lane": "commerce",
			"preserve_unknown_fields": true,
			"backwards_compatible": true
			}
		},
		{
			"id": "grocery_store_engine_state",
			"save_key": "grocery_store_engine_state",
			"engine_id": "grocery_store_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.grocery_store_engine_state",
			"version": 1,
			"metadata": {
			"hydration_lane": "commerce",
			"preserve_unknown_fields": true,
			"backwards_compatible": true
			}
		},
		{
			"id": "luxury_shop_engine_state",
			"save_key": "luxury_shop_engine_state",
			"engine_id": "luxury_shop_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.luxury_shop_engine_state",
			"version": 1,
			"metadata": {
			"hydration_lane": "commerce",
			"inventory_output": "belongings_engine",
			"money_authority": "bank_engine",
			"preserve_unknown_fields": true,
			"backwards_compatible": true
			}
		},
		{
			"id": "choose_adventure_state",
			"save_key": "choose_adventure_state",
			"engine_id": "choose_adventure_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.choose_adventure_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
			}
		},
		{
			"id": "lineage_engine_state",
			"save_key": "lineage_engine_state",
			"engine_id": "lineage_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.lineage_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"stream_on_demand": false
			}
		},
		{
			"id": "bending_engine_state",
			"save_key": "bending_engine_state",
			"engine_id": "bending_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.bending_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true
			}
		},
		{
			"id": "bending_tournament_engine_state",
			"save_key": "bending_tournament_engine_state",
			"engine_id": "bending_tournament_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.bending_tournament_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
			}
		},
		{
			"id": "reality_orchestrator_state",
			"save_key": "reality_orchestrator_state",
			"engine_id": "reality_orchestrator",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.reality_orchestrator_state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"preserve_unknown_slices": true,
				"backwards_compatible": true,
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "world_state"
				},
				{
					"action": "ensure_dictionary",
					"path": "contract_registry"
				},
				{
					"action": "ensure_array",
					"path": "world_state.orchestration_ledger"
				},
				{
					"action": "ensure_dictionary",
					"path": "world_state.authority_lattice"
				},
				{
					"action": "ensure_dictionary",
					"path": "world_state.domain_boundaries"
				}
			]
		},
		{
			"id": "wizard_engine_state",
			"save_key": "wizard_engine_state",
			"engine_id": "wizard_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.wizard_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
			}
		},
		{
			"id": "boxing_contract_engine_state",
			"save_key": "boxing_combat_resolution_engine_state",
			"engine_id": "boxing_combat_resolution_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.boxing_combat_resolution_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "boxing_fight_economy_engine_state",
			"save_key": "boxing_fight_economy_engine_state",
			"engine_id": "boxing_fight_economy_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.boxing_fight_economy_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			}
		},
		{
			"id": "boxing_title_engine_state",
			"save_key": "boxing_title_engine_state",
			"engine_id": "boxing_title_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.boxing_title_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true
			}
		},
		{
			"id": "boxing_amateur_engine_state",
			"save_key": "boxing_amateur_engine_state",
			"engine_id": "boxing_amateur_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.boxing_amateur_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true
			}
		},
		{
			"id": "boxing_media_engine_state",
			"save_key": "boxing_media_engine_state",
			"engine_id": "boxing_media_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.boxing_media_engine_state",
			"version": 1,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true
			}
		},
		{
			"id": "universal_faction_state",
			"save_key": "universal_faction_state",
			"engine_id": "universal_faction_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.universal_faction_state",
			"version": 1
		}
	]
	var event_bus_contracts: Array = [
		_build_default_event_bus_contract()
	]
	var meta_contracts: Array = [
		_build_default_contract_meta_governor_contract(),
		_build_default_reality_orchestrator_meta_contract()
	]
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"state_id": DEFAULT_STATE_ID,
		"name": "EraLife Default World Kernel",
		"engines": engines,
		"save_slices": save_slices,
		"runtime_phases": _build_default_age_up_runtime_phases(),
		"event_subscriptions": [
			{
				"id": "caveman_reality_runtime_yearly_tick",
				"event": ActionEventTypes.YEAR_PASSED,
				"target_engine_id": (
					"caveman_reality_runtime_engine"
				),
				"method": "yearly_tick",
				"priority": 83,
				"lane": "important",
				"allow_defer": true,
				"force_immediate": false
			},
			{
				"id": "caveman_reality_runtime_npc_born",
				"event": ActionEventTypes.NPC_BORN,
				"target_engine_id": (
					"caveman_reality_runtime_engine"
				),
				"method": "on_npc_born",
				"priority": 54,
				"lane": "important",
				"allow_defer": false,
				"force_immediate": true
			},
			{
				"id": "caveman_reality_runtime_npc_died",
				"event": ActionEventTypes.NPC_DIED,
				"target_engine_id": (
					"caveman_reality_runtime_engine"
				),
				"method": "on_npc_died",
				"priority": 53,
				"lane": "important",
				"allow_defer": false,
				"force_immediate": true
			}
		],
		"event_bus_contracts": event_bus_contracts,
		"meta_contracts": meta_contracts,
		"hydration_rules": [],
		"runtime_capability_profiles": {
			"auto": _detect_runtime_capability_profile(),
			"smart_tv": {
				"id": "smart_tv",
				"device_class": "smart_tv",
				"input_mode": "focus_remote",
				"cpu_tier": "low",
				"memory_tier": "low",
				"gpu_tier": "low",
				"screen_class": "tv",
				"simulation_cadence": "reduced",
				"phase_budget_cap": 2,
				"npc_soft_cap": 900,
				"region_stream_radius": 1,
				"event_stream_limit": 30,
				"streaming_enabled": true,
				"ui_layout": "tv_focus",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true,
					"fallback_cached_ui": true,
					"ui_alive_priority": true,
					"ui_tail_work_yield_to_input": true
				}
			}
		},
		"adaptive_resolution_rules": _default_adaptive_resolution_rules(),
		"world_streaming_manifest": _build_default_world_streaming_manifest(DEFAULT_STATE_ID),
		"launch_links": build_tap_to_play_links(DEFAULT_STATE_ID, {}),
		"metadata": {
			"built_in": true,
			"compatibility_mode": "legacy_game_state_overlay",
		}
	}

func _mod_contract_dictionary(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _mod_contract_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []


func set_mod_runtime_enabled(
	mod_id: String,
	enabled: bool,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = str(
		mod_id
	).strip_edges().to_lower()
	var report: Dictionary = {
		"success": true,
		"schema": "eralife.mod_runtime_enable_report",
		"version": CONTRACT_VERSION,
		"mod_id": clean_mod_id,
		"enabled": enabled,
		"context": context.duplicate(true),
		"updated": {},
		"runtime_instances": [],
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if clean_mod_id == "":
		report ["success"] = false
		report ["reason"] = "missing_mod_id"
		return report

	var registries: Dictionary = {
		"engines": engine_registry,
		"save_slices": save_slice_registry,
		"runtime_phases": runtime_phase_registry,
		"event_subscriptions": event_subscription_registry,
		"event_bus_contracts": event_bus_contract_registry,
		"meta_contracts": meta_contract_registry,
		"hydration_rules": hydration_registry
	}

	for registry_name in registries.keys():
		var registry: Dictionary = registries.get(
			registry_name,
			{}
		)
		var updated_ids: Array = []

		for raw_key in registry.keys():
			var key: String = str(raw_key)
			var row: Dictionary = _mod_contract_dictionary(
				registry.get(
					key,
					{}
				)
			)

			if not _contract_row_belongs_to_mod(
				row,
				clean_mod_id
			):
				continue

			row ["enabled"] = enabled
			row ["disabled_by_mod_lifecycle"] = not enabled
			row ["mod_lifecycle_updated_at_ms"] = int(
				Time.get_ticks_msec()
			)
			registry [key] = row
			updated_ids.append(key)

		report ["updated"] [registry_name] = updated_ids

	for raw_engine_id in _mod_contract_array(
		report ["updated"].get(
			"engines",
			[]
		)
	):
		var engine_id: String = str(raw_engine_id)
		var instance = get_engine_instance(engine_id)

		if instance == null:
			continue

		if instance.has_method("set_mod_enabled"):
			instance.call(
				"set_mod_enabled",
				enabled
			)

		if instance is Node:
			(instance as Node).set_process(enabled)
			(instance as Node).set_physics_process(enabled)

		report ["runtime_instances"].append(engine_id)

	apply_runtime_guards({
		"phase": "mod_runtime_enable_change",
		"mod_id": clean_mod_id,
		"enabled": enabled
	})

	return report

func remove_mod_runtime_contracts(
	mod_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = str(
		mod_id
	).strip_edges().to_lower()
	var preserve_save_data: bool = bool(
		context.get(
			"preserve_save_data",
			true
		)
	)
	var report: Dictionary = {
		"success": true,
		"schema": "eralife.mod_runtime_remove_report",
		"version": CONTRACT_VERSION,
		"mod_id": clean_mod_id,
		"preserve_save_data": preserve_save_data,
		"removed": {},
		"preserved_save_slices": [],
		"removed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if clean_mod_id == "":
		report ["success"] = false
		report ["reason"] = "missing_mod_id"
		return report

	set_mod_runtime_enabled(
		clean_mod_id,
		false,
		context
	)

	var engine_ids: Array = _registry_keys_for_mod(
		engine_registry,
		clean_mod_id
	)

	for raw_engine_id in engine_ids:
		var engine_id: String = str(raw_engine_id)
		var engine_contract: Dictionary = _mod_contract_dictionary(
			engine_registry.get(
				engine_id,
				{}
			)
		)
		var instance = get_engine_instance(engine_id)
		var runtime_property: String = str(
			engine_contract.get(
				"runtime_property",
				engine_id
			)
		).strip_edges()

		for raw_runtime_key in _engine_runtime_keys(
			engine_contract
		):
			if (
				gs != null
				and typeof(
					gs.contract_runtime_engines
				) == TYPE_DICTIONARY
			):
				gs.contract_runtime_engines.erase(
					str(raw_runtime_key)
				)

		if (
			gs != null
			and runtime_property != ""
			and runtime_property in gs
			and gs.get(runtime_property) == instance
		):
			gs.set(
				runtime_property,
				null
			)

		engine_identity_registry.erase(engine_id)
		runtime_capability_registry.erase(engine_id)
		adaptive_resolution_registry.erase(engine_id)
		engine_registry.erase(engine_id)

	report ["removed"] ["engines"] = engine_ids

	var slice_ids: Array = _registry_keys_for_mod(
		save_slice_registry,
		clean_mod_id
	)

	if preserve_save_data:
		for raw_slice_id in slice_ids:
			var slice_id: String = str(raw_slice_id)
			var slice_contract: Dictionary = _mod_contract_dictionary(
				save_slice_registry.get(
					slice_id,
					{}
				)
			)
			slice_contract ["enabled"] = false
			slice_contract ["orphaned_mod_slice"] = true
			slice_contract ["orphaned_mod_id"] = clean_mod_id
			save_slice_registry [slice_id] = slice_contract
			report ["preserved_save_slices"].append(slice_id)
	else:
		for raw_slice_id in slice_ids:
			save_slice_registry.erase(
				str(raw_slice_id)
			)

		report ["removed"] ["save_slices"] = slice_ids

	var removable_registries: Dictionary = {
		"runtime_phases": runtime_phase_registry,
		"event_subscriptions": event_subscription_registry,
		"event_bus_contracts": event_bus_contract_registry,
		"meta_contracts": meta_contract_registry,
		"hydration_rules": hydration_registry
	}

	for registry_name in removable_registries.keys():
		var registry: Dictionary = removable_registries.get(
			registry_name,
			{}
		)
		var keys: Array = _registry_keys_for_mod(
			registry,
			clean_mod_id
		)

		for raw_key in keys:
			registry.erase(
				str(raw_key)
			)

		report ["removed"] [registry_name] = keys

	var state_ids: Array = []

	for raw_state_id in contract_registry.keys():
		var state_id: String = str(raw_state_id)
		var state_contract: Dictionary = _mod_contract_dictionary(
			contract_registry.get(
				state_id,
				{}
			)
		)

		if _contract_row_belongs_to_mod(
			state_contract,
			clean_mod_id
		):
			state_ids.append(state_id)

	for raw_state_id in state_ids:
		contract_registry.erase(
			str(raw_state_id)
		)

	report ["removed"] ["state_contracts"] = state_ids

	validate_active_contracts({
		"phase": "mod_runtime_remove",
		"include_runtime": true,
		"mod_id": clean_mod_id
	})
	build_runtime_phase_budget_report({
		"phase": "mod_runtime_remove"
	})
	apply_runtime_guards({
		"phase": "mod_runtime_remove",
		"mod_id": clean_mod_id
	})

	return report


func _registry_keys_for_mod(
	registry: Dictionary,
	mod_id: String
) -> Array:
	var out: Array = []

	for raw_key in registry.keys():
		var key: String = str(raw_key)
		var row: Dictionary = _mod_contract_dictionary(
			registry.get(
				key,
				{}
			)
		)

		if _contract_row_belongs_to_mod(
			row,
			mod_id
		):
			out.append(key)

	out.sort()
	return out


func _contract_row_belongs_to_mod(
	row: Dictionary,
	mod_id: String
) -> bool:
	var clean_mod_id: String = str(
		mod_id
	).strip_edges().to_lower()

	if clean_mod_id == "":
		return false

	var row_mod_id: String = str(
		row.get(
			"mod_id",
			""
		)
	).strip_edges().to_lower()

	if row_mod_id == clean_mod_id:
		return true

	var metadata: Dictionary = _mod_contract_dictionary(
		row.get(
			"metadata",
			{}
		)
	)
	var metadata_mod_id: String = str(
		metadata.get(
			"mod_id",
			""
		)
	).strip_edges().to_lower()

	if metadata_mod_id == clean_mod_id:
		return true

	var source_state_id: String = str(
		row.get(
			"source_state_id",
			""
		)
	).strip_edges()

	if (
		source_state_id != ""
		and contract_registry.has(source_state_id)
	):
		var source_contract: Dictionary = _mod_contract_dictionary(
			contract_registry.get(
				source_state_id,
				{}
			)
		)
		var source_metadata: Dictionary = _mod_contract_dictionary(
			source_contract.get(
				"metadata",
				{}
			)
		)

		return str(
			source_metadata.get(
				"mod_id",
				""
			)
		).strip_edges().to_lower() == clean_mod_id

	return false
func _build_default_contract_meta_governor_contract() -> Dictionary:
	return {
		"schema": "eralife.contract_meta_governor",
		"version": 1,
		"id": "default_contract_meta_governor",
		"enabled": true,
		"priority": 0,
		"rules": [
			{
				"id": "default_complexity_total_surface",
				"type": "complexity_bound",
				"priority": 10,
				"severity": "warning",
				"metric": "registry.total_contract_surface",
				"comparator": ">",
				"threshold": 420,
				"action": "apply_guard_patch",
				"message": "The loaded reality contract surface is approaching the default safe complexity bound.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true
				}
			},
			{
				"id": "default_recursion_lineage_depth",
				"type": "recursion_feedback",
				"priority": 20,
				"severity": "critical",
				"metric": "event_bus.lineage_depth",
				"comparator": ">=",
				"threshold": 10,
				"action": "apply_guard_patch",
				"message": "Event lineage depth is near the bounded recursion ceiling.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"reduce_scenario_density": true,
					"compressed_execution_current_year": true,
					"phase_budget_cap": 1
				}
			},
			{
				"id": "default_runtime_overflow_pressure",
				"type": "runtime_budget",
				"priority": 30,
				"severity": "critical",
				"metric": "runtime.phase_overflow_count",
				"comparator": ">",
				"threshold": 8,
				"action": "apply_guard_patch",
				"message": "Runtime overflow pressure is high; AgeUp should compress noncritical work.",
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
				"id": "default_compatibility_validation_errors",
				"type": "contract_compatibility",
				"priority": 40,
				"severity": "error",
				"metric": "validation.error_count",
				"comparator": ">",
				"threshold": 0,
				"action": "apply_guard_patch",
				"message": "Contract validation errors exist; runtime should avoid expanded domain work.",
				"guard_patch": {
					"defer_noncritical_systems": true,
					"fallback_cached_ui": true,
					"defer_refresh_once": true
				}
			},
			{
				"id": "default_reality_live_population_surface",
				"type": "reality_safety",
				"priority": 50,
				"severity": "warning",
				"metric": "reality.npc_count",
				"comparator": ">",
				"threshold": 25000,
				"action": "apply_guard_patch",
				"message": "Live population surface exceeded the default safe visible-transition bound.",
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
func _build_default_reality_orchestrator_meta_contract() -> Dictionary:
	return {
		"schema": "eralife.contract_meta_governor",
		"version": 1,
		"id": "default_reality_orchestrator_meta_contract",
		"enabled": true,
		"priority": 25,
		"rules": [
			{
				"id": "reality_orchestrator_authority_boundary",
				"type": "orchestration_authority",
				"priority": 15,
				"severity": "error",
				"metric": "orchestration.authority_rank",
				"comparator": "<",
				"threshold": 30,
				"action": "block_or_quarantine",
				"message": "Scoped reality composition attempted to mutate a domain without Domain Authority.",
				"guard_patch": {
				}
			},
			{
				"id": "reality_orchestrator_cross_domain_edges",
				"type": "scoped_reality_composition",
				"priority": 20,
				"severity": "warning",
				"metric": "orchestration.cross_domain_edges",
				"comparator": ">",
				"threshold": 6,
				"action": "apply_guard_patch",
				"message": "Reality orchestration is crossing too many domains in one composition pass.",
				"guard_patch": {
					"defer_noncritical_systems": true,
				}
			},
			{
				"id": "reality_orchestrator_meta_patch_boundary",
				"type": "meta_contract_authority",
				"priority": 35,
				"severity": "critical",
				"metric": "orchestration.meta_patch_requested",
				"comparator": "==",
				"threshold": true,
				"action": "block_without_meta_authority",
				"message": "Meta-contract mutation requires Meta Contract Authority.",
				"guard_patch": {
				}
			},
			{
				"id": "reality_orchestrator_unknown_slice_protection",
				"type": "hydration_safety",
				"priority": 45,
				"severity": "critical",
				"metric": "hydration.unknown_slice_drop_requested",
				"comparator": "==",
				"threshold": true,
				"action": "block",
				"message": "Reality orchestration cannot drop unknown save slices.",
				"guard_patch": {
					"preserve_unknown_slices": true,
				}
			}
		],
		"metadata": {
			"built_in": true,
			"reality_orchestrator": true,
			"authority_hierarchy": [
				"local_event",
				"domain",
				"reality",
				"meta_contract"
			],
		}
	}
func _build_default_event_bus_contract() -> Dictionary:
	return {
		"id": "legacy_event_bus",
		"schema": "eralife.event_bus_contract_layer",
		"version": 1,
		"priority": 0,
		"conflict_policy": "merge",
		"runtime_guards": {
			"max_depth": 12,
			"duplicate_ttl_ms": 120,
			"duplicate_history_limit": 512,
			"default_replay_buffer_limit": 24
		},
		"dispatch_lanes": [
			{
				"id": "immediate",
				"policy": "immediate",
				"priority": 0,
				"force_immediate": true,
				"defer_by_default": false
			},
			{
				"id": "critical",
				"policy": "immediate",
				"priority": 10,
				"force_immediate": true,
				"defer_by_default": false
			},
			{
				"id": "important",
				"policy": "qos",
				"priority": 50,
				"force_immediate": false,
				"defer_by_default": false
			},
			{
				"id": "ambient",
				"policy": "deferred",
				"priority": 100,
				"force_immediate": false,
				"defer_by_default": true
			},
			{
				"id": "deferred",
				"policy": "deferred",
				"priority": 120,
				"force_immediate": false,
				"defer_by_default": true
			}
		],
		"events": [
			{
				"id": "legacy_default_event",
				"event": "*",
				"lane": "important",
				"schema_policy": "warn",
				"allow_unknown_keys": true,
				"required_keys": [],
				"key_types": {},
				"defaults": {},
				"max_depth": 12,
				"suppress_duplicates": true,
				"duplicate_ttl_ms": 120,
				"duplicate_keys": [],
				"replay_enabled": false,
				"replay_buffer_limit": 24
			}
		],
		"metadata": {
			"built_in": true,
			"compatibility_mode": "legacy_event_bus_overlay"
		}
	}
func _build_default_age_up_runtime_phases() -> Array:
	return [
		{
			"id": "year_and_era_mutation",
			"order": 10,
			"budget_ms": 5,
			"soft_budget_ms": 5,
			"hard_budget_ms": 16,
			"auto_degrade_enabled": true,
			"degradation_policy": "compress_then_continue",
			"runtime_tasks": [],
			"metadata": {
				"runtime_kind": "age_up",
				"native_owner": "age_up_runtime",
				"native_method": "_step_year_and_era_mutation_walker"
			}
		},
		{
			"id": "core_state_resolution",
			"order": 20,
			"budget_ms": 6,
			"soft_budget_ms": 6,
			"hard_budget_ms": 18,
			"auto_degrade_enabled": true,
			"degradation_policy": "compress_then_continue",
			"runtime_tasks": [
				{
					"id": "world.age_npcs",
					"engine_id": "world_engine",
					"task_id": "age_npcs",
					"dispatch": "world_contract_task",
					"order": 10,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "world.process_pregnancies",
					"engine_id": "world_engine",
					"task_id": "process_pregnancies",
					"dispatch": "world_contract_task",
					"order": 20,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "world.npc_have_children",
					"engine_id": "world_engine",
					"task_id": "npc_have_children",
					"dispatch": "world_contract_task",
					"order": 30,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "world.process_divorces",
					"engine_id": "world_engine",
					"task_id": "process_divorces",
					"dispatch": "world_contract_task",
					"order": 40,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "world.process_remarriages",
					"engine_id": "world_engine",
					"task_id": "process_remarriages",
					"dispatch": "world_contract_task",
					"order": 50,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "world.process_movement",
					"engine_id": "world_engine",
					"task_id": "process_movement",
					"dispatch": "world_contract_task",
					"order": 60,
					"passes_context": true,
					"required": true,
					"execution_model": "incremental",
					"allow_defer": false,
					"max_quantum_ms": 2,
					"max_items_per_quantum": 96
				},
				{
					"id": "dynamic_world.era_events",
					"engine_id": "dynamic_world_event_engine",
					"method": "_era_events",
					"dispatch": "engine_method",
					"order": 70,
					"passes_context": false
				},
				{
					"id": "dynamic_world.artifact_events",
					"engine_id": "dynamic_world_event_engine",
					"method": "_artifact_events",
					"dispatch": "engine_method",
					"order": 80,
					"passes_context": false
				},
				{
					"id": "dynamic_world.bending_events",
					"engine_id": "dynamic_world_event_engine",
					"method": "_bending_events",
					"dispatch": "engine_method",
					"order": 90,
					"passes_context": false
				},
				{
					"id": "dynamic_world.bonnet_events",
					"engine_id": "dynamic_world_event_engine",
					"method": "_bonnet_events",
					"dispatch": "engine_method",
					"order": 100,
					"passes_context": false
				},
				{
					"id": "dynamic_world.asset_ecology_events",
					"engine_id": "dynamic_world_event_engine",
					"method": "_asset_ecology_events",
					"dispatch": "engine_method",
					"order": 110,
					"passes_context": false
				}
			],
			"metadata": {
				"runtime_kind": "age_up",
				"domain_owner": "game_state_contract_engine"
			}
		},
		{
			"id": "internal_identity_drift",
			"order": 30,
			"budget_ms": 5,
			"soft_budget_ms": 5,
			"hard_budget_ms": 14,
			"auto_degrade_enabled": true,
			"degradation_policy": "defer_noncritical",
			"degradation_steps": [
				{ "set_runtime_guard": "reduce_identity_density"},
				{ "set_runtime_guard": "defer_noncritical_systems"}
			],
			"runtime_tasks": [
				{
					"id": "life.refresh_relationship_targets",
					"engine_id": "life_engine",
					"task_id": "refresh_relationship_targets",
					"dispatch": "life_contract_task",
					"order": 10,
					"passes_context": true
				}
			],
			"metadata": {
				"runtime_kind": "age_up",
				"domain_owner": "game_state_contract_engine"
			}
		},
		{
			"id": "data_defined_simulation_laws",
			"order": 40,
			"budget_ms": 5,
			"soft_budget_ms": 5,
			"hard_budget_ms": 16,
			"auto_degrade_enabled": true,
			"degradation_policy": "defer_noncritical",
			"degradation_steps": [
				{ "set_runtime_guard": "reduce_scenario_density"},
				{ "set_runtime_guard": "defer_noncritical_systems"}
			],
			"runtime_tasks": [],
			"metadata": {
				"runtime_kind": "age_up"
			}
		},
		{
			"id": "year_budget_pipeline_commit",
			"order": 50,
			"budget_ms": 6,
			"soft_budget_ms": 6,
			"hard_budget_ms": 20,
			"auto_degrade_enabled": true,
			"degradation_policy": "slice_commit",
			"degradation_steps": [
				{ "set_runtime_guard": "commit_budget_cap"},
				{ "set_runtime_guard": "tail_settle_budget_cap"}
			],
			"runtime_tasks": [],
			"metadata": {
				"runtime_kind": "age_up",
			}
		},
		{
			"id": "player_phase_contract",
			"order": 60,
			"budget_ms": 5,
			"soft_budget_ms": 5,
			"hard_budget_ms": 16,
			"auto_degrade_enabled": true,
			"degradation_policy": "micro_slice",
			"runtime_tasks": [],
			"metadata": {
				"runtime_kind": "age_up",
			}
		},
		{
			"id": "choice_and_opportunity_surfacing",
			"order": 70,
			"budget_ms": 4,
			"soft_budget_ms": 4,
			"hard_budget_ms": 10,
			"auto_degrade_enabled": true,
			"degradation_policy": "defer_noncritical",
			"degradation_steps": [
				{ "set_runtime_guard": "reduce_scenario_density"},
				{ "set_runtime_guard": "defer_noncritical_systems"}
			],
			"runtime_tasks": [],
			"metadata": {
				"runtime_kind": "age_up",
			}
		},
		{
			"id": "narrative_and_presentation",
			"order": 80,
			"budget_ms": 4,
			"soft_budget_ms": 4,
			"hard_budget_ms": 10,
			"auto_degrade_enabled": true,
			"degradation_policy": "defer_noncritical",
			"degradation_steps": [
				{ "set_runtime_guard": "fallback_cached_ui"},
				{ "set_runtime_guard": "defer_refresh_once"}
			],
			"runtime_tasks": [
				{
					"id": "life.finalize_life_year_contract",
					"engine_id": "life_engine",
					"task_id": "finalize_life_year_contract",
					"dispatch": "life_contract_task",
					"order": 90,
					"passes_context": true
				}
			],
			"metadata": {
				"runtime_kind": "age_up",
			}
		}
	]
func get_runtime_phase_scheduler_context(context: Dictionary = {}) -> Dictionary:
	var budget_report: Dictionary = build_runtime_phase_budget_report(context)
	var phase_rows_raw: Variant = budget_report.get("phases", [])
	var phase_rows: Array = phase_rows_raw if typeof(phase_rows_raw) == TYPE_ARRAY else []

	var runtime_kind: String = str(context.get("runtime_kind", "age_up")).strip_edges()
	var ordered: Array = []
	var phase_contracts: Dictionary = {}

	for row_raw in phase_rows:
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw
		var phase_id: String = str(row.get("id", "")).strip_edges()
		if phase_id == "":
			continue

		var contract_raw: Variant = runtime_phase_registry.get(phase_id, {})
		var contract: Dictionary = contract_raw if typeof(contract_raw) == TYPE_DICTIONARY else {}
		var metadata_raw: Variant = contract.get("metadata", {})
		var metadata: Dictionary = metadata_raw if typeof(metadata_raw) == TYPE_DICTIONARY else {}

		var row_runtime_kind: String = str(metadata.get("runtime_kind", runtime_kind)).strip_edges()
		if runtime_kind != "" and row_runtime_kind != runtime_kind:
			continue

		var runtime_tasks: Array = get_runtime_phase_tasks(phase_id)

		ordered.append({
			"id": phase_id,
			"order": int(row.get("order", contract.get("order", 100))),
			"budget_ms": int(row.get("budget_ms", contract.get("budget_ms", DEFAULT_PHASE_BUDGET_MS))),
			"soft_budget_ms": int(row.get("soft_budget_ms", contract.get("soft_budget_ms", DEFAULT_PHASE_BUDGET_MS))),
			"hard_budget_ms": int(row.get("hard_budget_ms", contract.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS)))
		})

		phase_contracts [phase_id] = {
			"id": phase_id,
			"order": int(row.get("order", contract.get("order", 100))),
			"budget_ms": int(row.get("budget_ms", contract.get("budget_ms", DEFAULT_PHASE_BUDGET_MS))),
			"soft_budget_ms": int(row.get("soft_budget_ms", contract.get("soft_budget_ms", DEFAULT_PHASE_BUDGET_MS))),
			"hard_budget_ms": int(row.get("hard_budget_ms", contract.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS))),
			"auto_degrade_enabled": bool(contract.get("auto_degrade_enabled", true)),
			"degradation_policy": str(contract.get("degradation_policy", "defer_noncritical")),
			"degradation_steps": contract.get("degradation_steps", []),
			"listeners": contract.get("listeners", []).duplicate(true) if typeof(contract.get("listeners", [])) == TYPE_ARRAY else [],
			"runtime_tasks": runtime_tasks.duplicate(true),
			"domain_tasks": runtime_tasks.duplicate(true),
			"metadata": metadata.duplicate(true)
		}

	ordered.sort_custom(func (a, b): return int(a.get("order", 100)) < int(b.get("order", 100)))

	var phase_order: Array = []
	for row in ordered:
		phase_order.append(str(row.get("id", "")))

	if phase_order.is_empty() and runtime_kind == "age_up":
		phase_order = [
			"year_and_era_mutation",
			"core_state_resolution",
			"internal_identity_drift",
			"data_defined_simulation_laws",
			"year_budget_pipeline_commit",
			"player_phase_contract",
			"choice_and_opportunity_surfacing",
			"narrative_and_presentation"
		]

	return {
		"schema": "eralife.runtime_phase_live_scheduler_context",
		"version": CONTRACT_VERSION,
		"runtime_kind": runtime_kind,
		"phase_order": phase_order,
		"phase_contracts": phase_contracts,
		"frame_budget_ms": int(context.get("frame_budget_ms", DEFAULT_AGE_UP_FRAME_BUDGET_MS)),
		"visible_watchdog_ms": int(context.get("visible_watchdog_ms", DEFAULT_AGE_UP_VISIBLE_WATCHDOG_MS)),
		"force_complete_ms": int(context.get("force_complete_ms", DEFAULT_AGE_UP_FORCE_COMPLETE_MS)),
		"budget_report": budget_report.duplicate(true),
		"built_at_ms": int(Time.get_ticks_msec())
	}
func get_runtime_phase_contract(phase_id: String) -> Dictionary:
	var clean_phase: String = str(phase_id).strip_edges()
	if clean_phase == "":
		return {}

	var raw: Variant = runtime_phase_registry.get(clean_phase, {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func get_runtime_phase_tasks(phase_id: String, engine_filter: String = "") -> Array:
	var contract: Dictionary = get_runtime_phase_contract(phase_id)
	if contract.is_empty():
		return []

	var tasks_raw: Variant = contract.get("runtime_tasks", contract.get("domain_tasks", []))
	var tasks: Array = tasks_raw if typeof(tasks_raw) == TYPE_ARRAY else []
	var out: Array = []
	var clean_engine_filter: String = str(engine_filter).strip_edges()

	for raw_task in tasks:
		if typeof(raw_task) != TYPE_DICTIONARY:
			continue

		var task: Dictionary = raw_task
		if not bool(task.get("enabled", true)):
			continue

		var engine_id: String = str(task.get("engine_id", task.get("target_engine_id", ""))).strip_edges()
		if clean_engine_filter != "" and engine_id != clean_engine_filter:
			continue

		out.append(task.duplicate(true))

	out.sort_custom(func (a, b): return int(a.get("order", a.get("priority", 100))) < int(b.get("order", b.get("priority", 100))))
	return out

func record_runtime_phase_overflow(phase_id: String, observed_ms: int, context: Dictionary = {}) -> Dictionary:
	var clean_phase: String = str(phase_id).strip_edges()
	var phase_contract: Dictionary = {}
	var contract_raw: Variant = runtime_phase_registry.get(clean_phase, {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		phase_contract = contract_raw

	var hard_budget_ms: int = int(phase_contract.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS))
	var soft_budget_ms: int = int(phase_contract.get("soft_budget_ms", phase_contract.get("budget_ms", DEFAULT_PHASE_BUDGET_MS)))
	var overflow_level: String = "soft"
	if observed_ms >= hard_budget_ms:
		overflow_level = "hard"

	var guard_patch:= {
		"defer_noncritical_systems": true,
		"reduce_scenario_density": true,
		"commit_budget_cap": max(1, int(context.get("commit_budget_cap", 2))),
		"phase_budget_cap": max(1, int(context.get("phase_budget_cap", 1))),
		"last_action": "contract_phase_overflow",
		"last_action_ms": int(Time.get_ticks_msec()),
		"overflow_phase": clean_phase,
		"overflow_level": overflow_level
	}

	var report:= {
		"schema": "eralife.runtime_phase_overflow_report",
		"version": CONTRACT_VERSION,
		"phase_id": clean_phase,
		"observed_ms": observed_ms,
		"soft_budget_ms": soft_budget_ms,
		"hard_budget_ms": hard_budget_ms,
		"overflow_level": overflow_level,
		"degradation_policy": str(phase_contract.get("degradation_policy", "defer_noncritical")),
		"guard_patch": guard_patch.duplicate(true),
		"context": context.duplicate(true),
		"recorded_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var overflow_log_raw: Variant = gs.scenario_state.get("runtime_phase_overflow_log", [])
		var overflow_log: Array = overflow_log_raw if typeof(overflow_log_raw) == TYPE_ARRAY else []
		overflow_log.append(report)
		if overflow_log.size() > 80:
			overflow_log = overflow_log.slice(overflow_log.size() - 80, overflow_log.size())
		gs.scenario_state ["runtime_phase_overflow_log"] = overflow_log

		var scenario_runtime_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
		var scenario_runtime_guard: Dictionary = scenario_runtime_guard_raw if typeof(scenario_runtime_guard_raw) == TYPE_DICTIONARY else {}
		for key in guard_patch.keys():
			scenario_runtime_guard [key] = guard_patch [key]
		gs.scenario_state ["runtime_guard"] = scenario_runtime_guard

		var meta_report: Dictionary = apply_contract_meta_governor({
			"phase": "record_runtime_phase_overflow",
			"overflow_phase": clean_phase,
			"overflow_level": overflow_level,
			"observed_ms": observed_ms,
			"source": "runtime_phase_overflow"
		})
		report ["meta_governor"] = meta_report.duplicate(true)

	return report
func _json_files_in_folder(folder_path: String) -> Array:
	var out: Array = []

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder_path)):
		return out

	var files: PackedStringArray = DirAccess.get_files_at(folder_path)
	for file_name in files:
		var clean_name: String = str(file_name).strip_edges()
		if clean_name.to_lower().ends_with(".json"):
			out.append("%s/%s" % [folder_path, clean_name])

	var dirs: PackedStringArray = DirAccess.get_directories_at(folder_path)
	for dir_name in dirs:
		var child_path:= "%s/%s" % [folder_path, str(dir_name)]
		for nested in _json_files_in_folder(child_path):
			out.append(nested)

	return out
func validate_active_contracts(context: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var include_runtime: bool = bool(context.get("include_runtime", false))

	for engine_id in engine_registry.keys():
		var engine: Dictionary = engine_registry.get(engine_id, {})
		if not bool(engine.get("enabled", true)):
			continue

		if str(engine.get("id", "")).strip_edges() == "":
			errors.append("Engine registry contains an engine with no id.")

		if str(engine.get("boot_phase", "")).strip_edges() not in ALLOWED_BOOT_PHASES:
			errors.append("Engine '%s' has invalid boot_phase '%s'." % [str(engine_id), str(engine.get("boot_phase", ""))])

		if bool(engine.get("allow_contract_instantiation", false)):
			var script_path: String = str(engine.get("script_path", "")).strip_edges()
			var fallback_script_path: String = str(engine.get("fallback_script_path", "")).strip_edges()
			if script_path == "" and fallback_script_path == "":
				warnings.append("Engine '%s' can be contract-instantiated but has no script_path or fallback_script_path." % str(engine_id))

		if include_runtime:
			var instance = get_engine_instance(str(engine_id))
			if instance != null and instance is Object:
				for method_name in engine.get("required_methods", []):
					var clean_method: String = str(method_name).strip_edges()
					if clean_method != "" and not instance.has_method(clean_method):
						errors.append("Runtime engine '%s' is missing required method '%s'." % [str(engine_id), clean_method])

	for slice_id in save_slice_registry.keys():
		var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
		if not bool(save_slice.get("enabled", true)):
			continue

		var engine_id: String = str(save_slice.get("engine_id", "")).strip_edges()
		if engine_id == "":
			errors.append("Save slice '%s' has no engine_id." % str(slice_id))
		elif not engine_registry.has(engine_id):
			warnings.append("Save slice '%s' references engine '%s', but that engine is not declared in the GameState contract." % [str(slice_id), engine_id])

		var min_supported_version: int = int(save_slice.get("min_supported_version", 1))
		var target_version: int = int(save_slice.get("version", 1))
		if min_supported_version > target_version:
			errors.append("Save slice '%s' has min_supported_version greater than target version." % str(slice_id))

		for raw_rule in save_slice.get("migration_rules", []):
			if typeof(raw_rule) != TYPE_DICTIONARY:
				warnings.append("Save slice '%s' has a non-dictionary migration rule." % str(slice_id))
				continue
			var action: String = str((raw_rule as Dictionary).get("action", "")).strip_edges().to_lower()
			if action not in ALLOWED_MIGRATION_ACTIONS:
				warnings.append("Save slice '%s' has unsupported migration action '%s'." % [str(slice_id), action])

	for phase_id in runtime_phase_registry.keys():
		var phase: Dictionary = runtime_phase_registry.get(phase_id, {})
		if not bool(phase.get("enabled", true)):
			continue

		var budget_ms: int = int(phase.get("budget_ms", DEFAULT_PHASE_BUDGET_MS))
		var hard_budget_ms: int = int(phase.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS))
		if budget_ms < 0:
			errors.append("Runtime phase '%s' has negative budget_ms." % str(phase_id))
		if hard_budget_ms < budget_ms:
			errors.append("Runtime phase '%s' has hard_budget_ms lower than budget_ms." % str(phase_id))

	for sub_id in event_subscription_registry.keys():
		var sub: Dictionary = event_subscription_registry.get(sub_id, {})
		if not bool(sub.get("enabled", true)):
			continue

		var target_engine_id: String = str(sub.get("target_engine_id", "")).strip_edges()
		if target_engine_id == "":
			errors.append("Event subscription '%s' has no target_engine_id." % str(sub_id))
		elif not engine_registry.has(target_engine_id):
			warnings.append("Event subscription '%s' targets undeclared engine '%s'." % [str(sub_id), target_engine_id])

	for rule_id in hydration_registry.keys():
		var rule: Dictionary = hydration_registry.get(rule_id, {})
		if not bool(rule.get("enabled", true)):
			continue

		var target_engine_id: String = str(rule.get("target_engine_id", "")).strip_edges()
		if target_engine_id == "":
			errors.append("Hydration rule '%s' has no target_engine_id." % str(rule_id))
		elif not engine_registry.has(target_engine_id):
			warnings.append("Hydration rule '%s' targets undeclared engine '%s'." % [str(rule_id), target_engine_id])

	last_validation_report = {
		"schema": "eralife.game_state_contract_validation_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"checked_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["game_state_contract_validation_report"] = last_validation_report.duplicate(true)

	return last_validation_report


func recover_missing_engines(context: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.game_state_contract_recovery_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"recovered": [],
		"disabled": [],
		"quarantined": [],
		"skipped": [],
		"failed": [],
		"recovered_at_ms": int(Time.get_ticks_msec())
	}

	if gs == null:
		report ["failed"].append({
			"reason": "No GameState bound."
		})
		last_recovery_report = report.duplicate(true)
		return report

	for engine_id in engine_registry.keys():
		var engine: Dictionary = engine_registry.get(
			engine_id,
			{}
		)

		if not bool(
			engine.get(
				"enabled",
				true
			)
		):
			continue

		var instance = get_engine_instance(
			str(engine_id)
		)

		if instance != null:
			continue

		var policy: String = str(
			engine.get(
				"missing_engine_policy",
				"warn"
			)
		).strip_edges().to_lower()

		if policy == "disable":
			engine ["enabled"] = false
			engine ["disabled_reason"] = (
				"missing_engine_policy:disable"
			)
			engine_registry [engine_id] = engine
			report ["disabled"].append({
				"engine_id": str(engine_id)
			})
			continue

		if policy == "quarantine":
			engine ["quarantined"] = true
			engine ["quarantine_reason"] = (
				"missing_engine_policy:quarantine"
			)
			engine_registry [engine_id] = engine
			report ["quarantined"].append({
				"engine_id": str(engine_id)
			})
			continue

		if policy not in [
			"recover",
			"fallback"
		]:
			report ["skipped"].append({
				"engine_id": str(engine_id),
				"policy": policy,
				"reason": (
					"Policy does not request recovery."
				)
			})
			continue

		var recovered = _recover_engine_from_contract(
			engine
		)

		if recovered != null:
			_bind_engine_instance(
				engine,
				recovered
			)

			instantiated_contract_engines [
				str(engine_id)
			] = true

			report ["recovered"].append({
				"engine_id": str(engine_id),
				"runtime_property": str(
					engine.get(
						"runtime_property",
						engine_id
					)
				),
				"strategy": "contract_script_or_fallback"
			})
			continue

		var recovery_method: String = str(
			engine.get(
				"recovery_method",
				""
			)
		).strip_edges()

		if (
			recovery_method != ""
			and gs.has_method(
				recovery_method
			)
		):
			var recovery_result = gs.call(
				recovery_method,
				engine.get(
					"recovery_payload",
					{}
				)
			)

			report ["recovered"].append({
				"engine_id": str(engine_id),
				"strategy": "game_state_recovery_method",
				"method": recovery_method,
				"result": _make_binary_safe(
					recovery_result
				)
			})
			continue

		report ["failed"].append({
			"engine_id": str(engine_id),
			"policy": policy,
			"reason": (
				"No recovery path succeeded."
			)
		})

	last_recovery_report = report.duplicate(true)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"game_state_contract_recovery_report"
		] = report.duplicate(true)

	return report


func _recover_engine_from_contract(engine: Dictionary):
	var script_resolution: Dictionary = (
		_resolve_contract_script_resource(
			str(
				engine.get(
					"script_path",
					""
				)
			),
			str(
				engine.get(
					"fallback_script_path",
					""
				)
			),
			str(
				engine.get(
					"class",
					engine.get(
						"class_name",
						""
					)
				)
			)
		)
	)

	if not bool(
		script_resolution.get(
			"success",
			false
		)
	):
		return null

	var script: Script = (
		script_resolution.get(
			"script",
			null
		) as Script
	)

	if (
		script == null
		or not script.can_instantiate()
	):
		return null

	return script.new(gs)
func migrate_save_slice_data(slice_id: String, payload: Variant, from_version: int, to_version: int) -> Variant:
	var save_slice: Dictionary = save_slice_registry.get(slice_id, {})
	if save_slice.is_empty():
		return payload

	var out: Variant = payload
	if typeof(out) == TYPE_DICTIONARY:
		out = (out as Dictionary).duplicate(true)
	elif not save_slice.get("default_data", {}).is_empty():
		out = save_slice.get("default_data", {}).duplicate(true)

	var rules: Array = save_slice.get("migration_rules", [])
	rules.sort_custom(func (a, b): return int(a.get("order", 100)) < int(b.get("order", 100)))

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

		out = _apply_migration_rule(out, rule)

	return out


func _apply_migration_rule(payload: Variant, rule: Dictionary) -> Variant:
	var action: String = str(rule.get("action", "")).strip_edges().to_lower()
	if action not in ALLOWED_MIGRATION_ACTIONS:
		return payload

	if action == "call_method":
		var method_name: String = str(rule.get("method", "")).strip_edges()
		if method_name != "" and gs != null and gs.has_method(method_name):
			return gs.call(method_name, payload, rule)
		return payload

	if typeof(payload) != TYPE_DICTIONARY:
		return payload

	var data: Dictionary = payload

	match action:
		"set_default":
			var path: String = str(rule.get("path", rule.get("key", ""))).strip_edges()
			if path != "" and not _has_nested_value(data, path):
				_set_nested_value(data, path, rule.get("value", null))

		"rename_key":
			var from_path: String = str(rule.get("from", "")).strip_edges()
			var to_path: String = str(rule.get("to", "")).strip_edges()
			if from_path != "" and to_path != "" and _has_nested_value(data, from_path):
				var value: Variant = _get_nested_value(data, from_path, null)
				_set_nested_value(data, to_path, value)
				_erase_nested_value(data, from_path)

		"copy_key":
			var from_path: String = str(rule.get("from", "")).strip_edges()
			var to_path: String = str(rule.get("to", "")).strip_edges()
			if from_path != "" and to_path != "" and _has_nested_value(data, from_path):
				_set_nested_value(data, to_path, _get_nested_value(data, from_path, null))

		"delete_key":
			var path: String = str(rule.get("path", rule.get("key", ""))).strip_edges()
			if path != "":
				_erase_nested_value(data, path)

		"ensure_dictionary":
			var path: String = str(rule.get("path", rule.get("key", ""))).strip_edges()
			if path != "" and typeof(_get_nested_value(data, path, {})) != TYPE_DICTIONARY:
				_set_nested_value(data, path, {})

		"ensure_array":
			var path: String = str(rule.get("path", rule.get("key", ""))).strip_edges()
			if path != "" and typeof(_get_nested_value(data, path, [])) != TYPE_ARRAY:
				_set_nested_value(data, path, [])

	return data


func build_runtime_phase_budget_report(context: Dictionary = {}) -> Dictionary:
	if runtime_capability_profile.is_empty():
		resolve_runtime_capability_profile({})

	var capability: Dictionary = runtime_capability_profile.duplicate(true)
	var cadence: String = str(capability.get("simulation_cadence", "normal")).strip_edges().to_lower()
	var cadence_divisor: int = _simulation_cadence_divisor(cadence)
	var phase_budget_cap: int = int(runtime_guard.get("phase_budget_cap", capability.get("phase_budget_cap", 0)))

	var report:= {
		"schema": "eralife.runtime_phase_budget_report",
		"version": CONTRACT_VERSION,
		"state_id": active_state_id,
		"context": context.duplicate(true),
		"capability_profile": capability.duplicate(true),
		"simulation_cadence": cadence,
		"simulation_cadence_divisor": cadence_divisor,
		"phase_budget_cap": phase_budget_cap,
		"streaming_enabled": bool(world_streaming_manifest.get("enabled", true)),
		"phases": [],
		"total_soft_budget_ms": 0,
		"total_hard_budget_ms": 0,
		"degradation_available": false,
		"built_at_ms": int(Time.get_ticks_msec())
	}

	var phases: Array = runtime_phase_registry.values()
	phases.sort_custom(func (a, b): return int(a.get("order", 100)) < int(b.get("order", 100)))

	for phase in phases:
		if typeof(phase) != TYPE_DICTIONARY:
			continue
		if not bool(phase.get("enabled", true)):
			continue

		var soft_budget: int = max(0, int(phase.get("soft_budget_ms", phase.get("budget_ms", DEFAULT_PHASE_BUDGET_MS))))
		var hard_budget: int = max(soft_budget, int(phase.get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS)))

		if phase_budget_cap > 0:
			soft_budget = min(soft_budget, phase_budget_cap)
			hard_budget = max(soft_budget, min(hard_budget, max(phase_budget_cap, soft_budget)))

		var degradation_steps: Array = phase.get("degradation_steps", [])
		if not degradation_steps.is_empty():
			report ["degradation_available"] = true

		report ["total_soft_budget_ms"] = int(report ["total_soft_budget_ms"]) + soft_budget
		report ["total_hard_budget_ms"] = int(report ["total_hard_budget_ms"]) + hard_budget

		report ["phases"].append({
			"id": str(phase.get("id", "")),
			"order": int(phase.get("order", 100)),
			"required": bool(phase.get("required", false)),
			"budget_ms": int(phase.get("budget_ms", DEFAULT_PHASE_BUDGET_MS)),
			"soft_budget_ms": soft_budget,
			"hard_budget_ms": hard_budget,
			"adaptive_cadence_divisor": cadence_divisor,
			"auto_degrade_enabled": bool(phase.get("auto_degrade_enabled", true)),
			"degradation_policy": str(phase.get("degradation_policy", "defer_noncritical")),
			"degradation_steps": degradation_steps
		})

	runtime_phase_budget_report = report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["runtime_phase_budget_report"] = report.duplicate(true)

	return report


func _validate_contract_sections(engines: Array, save_slices: Array, runtime_phases: Array, event_subscriptions: Array, event_bus_contracts: Array, meta_contracts: Array, hydration_rules: Array) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var declared_engines: Dictionary = {}

	for engine in engines:
		if typeof(engine) != TYPE_DICTIONARY:
			continue
		declared_engines [str((engine as Dictionary).get("id", ""))] = true

	for save_slice in save_slices:
		if typeof(save_slice) != TYPE_DICTIONARY:
			continue

		var engine_id: String = str((save_slice as Dictionary).get("engine_id", "")).strip_edges()
		if engine_id != "" and not declared_engines.has(engine_id):
			warnings.append("Save slice '%s' references undeclared engine '%s'." % [str((save_slice as Dictionary).get("id", "")), engine_id])

	for sub in event_subscriptions:
		if typeof(sub) != TYPE_DICTIONARY:
			continue

		var engine_id: String = str((sub as Dictionary).get("target_engine_id", "")).strip_edges()
		if engine_id != "" and not declared_engines.has(engine_id):
			warnings.append("Event subscription '%s' references undeclared engine '%s'." % [str((sub as Dictionary).get("id", "")), engine_id])

	for bus_contract in event_bus_contracts:
		if typeof(bus_contract) != TYPE_DICTIONARY:
			continue

		var lanes_seen: Dictionary = {}
		for raw_lane in (bus_contract as Dictionary).get("dispatch_lanes", []):
			if typeof(raw_lane) != TYPE_DICTIONARY:
				continue

			var lane_id: String = str((raw_lane as Dictionary).get("id", "")).strip_edges()
			if lane_id != "":
				lanes_seen [lane_id] = true

		for raw_event in (bus_contract as Dictionary).get("events", []):
			if typeof(raw_event) != TYPE_DICTIONARY:
				continue

			var event_name: String = str((raw_event as Dictionary).get("event", "")).strip_edges()
			if event_name == "":
				errors.append("EventBus contract '%s' has an event contract without event." % str((bus_contract as Dictionary).get("id", "")))

			var lane: String = str((raw_event as Dictionary).get("lane", "")).strip_edges()
			if lane != "" and not lanes_seen.has(lane):
				warnings.append("EventBus event '%s' references undeclared dispatch lane '%s'." % [event_name, lane])

	for meta_contract in meta_contracts:
		if typeof(meta_contract) != TYPE_DICTIONARY:
			continue

		for raw_rule in (meta_contract as Dictionary).get("rules", []):
			if typeof(raw_rule) != TYPE_DICTIONARY:
				continue

			var rule: Dictionary = raw_rule
			var rule_id: String = str(rule.get("id", "")).strip_edges()
			var metric: String = str(rule.get("metric", "")).strip_edges()
			var action: String = str(rule.get("action", "")).strip_edges()

			if rule_id == "":
				errors.append("Meta contract '%s' has a rule without id." % str((meta_contract as Dictionary).get("id", "")))

			if metric == "":
				errors.append("Meta rule '%s' has no observed metric." % rule_id)

			if action != "apply_guard_patch":
				warnings.append("Meta rule '%s' uses action '%s'. Only predefined guard patch application is supported by default." % [rule_id, action])

	for rule in hydration_rules:
		if typeof(rule) != TYPE_DICTIONARY:
			continue

		var engine_id: String = str((rule as Dictionary).get("target_engine_id", "")).strip_edges()
		if engine_id != "" and not declared_engines.has(engine_id):
			warnings.append("Hydration rule '%s' references undeclared engine '%s'." % [str((rule as Dictionary).get("id", "")), engine_id])

	for phase in runtime_phases:
		if typeof(phase) != TYPE_DICTIONARY:
			continue

		var budget_ms: int = int((phase as Dictionary).get("budget_ms", DEFAULT_PHASE_BUDGET_MS))
		var hard_budget_ms: int = int((phase as Dictionary).get("hard_budget_ms", DEFAULT_HARD_PHASE_BUDGET_MS))

		if hard_budget_ms < budget_ms:
			errors.append("Runtime phase '%s' has hard_budget_ms lower than budget_ms." % str((phase as Dictionary).get("id", "")))

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}
func _append_unique_string(target: Array, value: Variant) -> void:
	var clean: String = str(value).strip_edges()
	if clean == "":
		return
	if clean not in target:
		target.append(clean)


func _stable_engine_contract_uid(engine_id: String, state_id: String, class_name_text: String = "", script_path: String = "") -> String:
	var basis: String = "%s|%s|%s|%s" % [
		str(state_id).strip_edges(),
		str(engine_id).strip_edges(),
		str(class_name_text).strip_edges(),
		str(script_path).strip_edges()
	]
	var clean: String = basis.to_lower()
	clean = clean.replace(" ", "_")
	clean = clean.replace("/", "_")
	clean = clean.replace("\\", "_")
	clean = clean.replace(":", "_")
	clean = clean.replace(".", "_")
	clean = clean.replace("|", "_")
	while clean.find("__") >= 0:
		clean = clean.replace("__", "_")
	if clean.length() > 96:
		clean = "%s_%d" % [clean.substr(0, 72), abs(hash(basis))]
	if clean == "":
		clean = "engine_%d" % abs(hash(basis))
	return clean


func _engine_runtime_keys(engine: Dictionary) -> Array:
	var out: Array = []
	_append_unique_string(out, engine.get("id", ""))
	_append_unique_string(out, engine.get("engine_id", ""))
	_append_unique_string(out, engine.get("canonical_engine_id", ""))
	_append_unique_string(out, engine.get("runtime_property", ""))
	_append_unique_string(out, engine.get("contract_uid", ""))
	_append_unique_string(out, engine.get("portable_id", ""))

	for key in _safe_string_array(engine.get("runtime_lookup_keys", [])):
		_append_unique_string(out, key)
	for key in _safe_string_array(engine.get("aliases", [])):
		_append_unique_string(out, key)

	return out


func _register_engine_identity_record(engine: Dictionary, state_id: String = "") -> void:
	var engine_id: String = str(engine.get("id", engine.get("engine_id", ""))).strip_edges()
	if engine_id == "":
		return

	var clean_state_id: String = str(state_id).strip_edges()
	if clean_state_id == "":
		clean_state_id = str(engine.get("state_id", active_state_id)).strip_edges()

	var contract_uid: String = str(engine.get("contract_uid", engine.get("portable_id", ""))).strip_edges()
	if contract_uid == "":
		contract_uid = _stable_engine_contract_uid(
			engine_id,
			clean_state_id,
			str(engine.get("class", "")),
			str(engine.get("script_path", ""))
		)

	var identity:= {
		"schema": "eralife.engine_identity",
		"version": CONTRACT_VERSION,
		"engine_id": engine_id,
		"canonical_engine_id": str(engine.get("canonical_engine_id", engine_id)).strip_edges(),
		"contract_uid": contract_uid,
		"portable_id": contract_uid,
		"runtime_property": str(engine.get("runtime_property", engine_id)).strip_edges(),
		"runtime_lookup_keys": _engine_runtime_keys(engine),
		"state_id": clean_state_id,
		"mod_id": str(engine.get("mod_id", "")),
		"migration_namespace": str(engine.get("migration_namespace", "%s.%s" % [clean_state_id, engine_id])),
		"save_key": str(engine.get("save_key", engine_id)),
		"device_persistence_key": str(engine.get("device_persistence_key", contract_uid)),
		"registered_at_ms": int(Time.get_ticks_msec())
	}

	for key in _engine_runtime_keys(engine):
		engine_identity_registry [str(key)] = identity.duplicate(true)

	engine_identity_registry [engine_id] = identity.duplicate(true)
	engine_identity_registry [contract_uid] = identity.duplicate(true)


func _build_auto_save_slice_from_engine(engine: Dictionary, state_id: String = "") -> Dictionary:
	var engine_id: String = str(engine.get("id", engine.get("engine_id", ""))).strip_edges()
	var save_key: String = str(engine.get("save_key", engine_id)).strip_edges()
	if save_key == "":
		save_key = engine_id

	var slice_id: String = str(engine.get("save_slice_id", "%s_slice" % save_key)).strip_edges()

	return {
		"id": slice_id,
		"save_key": save_key,
		"state_id": str(state_id).strip_edges(),
		"engine_id": engine_id,
		"enabled": bool(engine.get("enabled", true)),
		"required": bool(engine.get("required", false)),
		"priority": int(engine.get("priority", 0)),
		"conflict_policy": str(engine.get("conflict_policy", "highest_priority")),
		"missing_engine_policy": str(engine.get("missing_engine_policy", "warn")),
		"export_method": str(engine.get("snapshot_export_method", "export_state")).strip_edges(),
		"import_method": str(engine.get("snapshot_import_method", "import_state")).strip_edges(),
		"hydrate_method": str(engine.get("hydrate_method", "")).strip_edges(),
		"fallback_hydration_method": str(engine.get("fallback_hydration_method", "")).strip_edges(),
		"schema": "eralife.save_slice",
		"version": max(1, int(engine.get("version", 1))),
		"target_version": max(1, int(engine.get("version", 1))),
		"min_supported_version": max(1, int(engine.get("min_supported_version", 1))),
		"migration_rules": _safe_dictionary_array(engine.get("migration_rules", [])),
		"fallback_data": engine.get("fallback_data", {}).duplicate(true) if typeof(engine.get("fallback_data", {})) == TYPE_DICTIONARY else {},
		"default_data": engine.get("default_data", {}).duplicate(true) if typeof(engine.get("default_data", {})) == TYPE_DICTIONARY else {},
		"metadata": {
			"contract_uid": str(engine.get("contract_uid", "")),
			"migration_namespace": str(engine.get("migration_namespace", "")),
			"device_persistence_key": str(engine.get("device_persistence_key", ""))
		},
		"validation": {
			"valid": slice_id != "",
			"errors": [] if slice_id != "" else ["Auto save slice missing id."],
			"warnings": []
		}
	}


func _bind_engine_instance(engine: Dictionary, instance) -> void:
	if gs == null or instance == null:
		return

	if typeof(gs.contract_runtime_engines) != TYPE_DICTIONARY:
		gs.contract_runtime_engines = {}

	for key in _engine_runtime_keys(engine):
		var clean_key: String = str(key).strip_edges()
		if clean_key == "":
			continue
		gs.contract_runtime_engines [clean_key] = instance

	var runtime_property: String = str(engine.get("runtime_property", engine.get("id", ""))).strip_edges()
	if runtime_property != "" and runtime_property in gs:
		gs.set(runtime_property, instance)


func _build_contract_runtime_manifest() -> Dictionary:
	if runtime_capability_profile.is_empty():
		resolve_runtime_capability_profile({})

	var manifest:= {
		"schema": "eralife.contract_runtime_manifest",
		"version": CONTRACT_VERSION,
		"active_state_id": active_state_id,
		"runtime_capability_profile": runtime_capability_profile.duplicate(true),
		"world_streaming_manifest": world_streaming_manifest.duplicate(true),
		"launch_links": launch_link_registry.duplicate(true),
		"engines": {},
		"built_at_ms": int(Time.get_ticks_msec())
	}

	for engine_id in engine_registry.keys():
		var engine: Dictionary = engine_registry.get(engine_id, {})
		var instance = get_engine_instance(str(engine_id))

		manifest ["engines"] [str(engine_id)] = {
			"engine_id": str(engine_id),
			"contract_uid": str(engine.get("contract_uid", "")),
			"runtime_property": str(engine.get("runtime_property", engine_id)),
			"runtime_lookup_keys": _engine_runtime_keys(engine),
			"runtime_present": instance != null,
			"enabled": bool(engine.get("enabled", true)),
			"disabled_by_adaptive_resolution": bool(engine.get("disabled_by_adaptive_resolution", false)),
			"save_key": str(engine.get("save_key", engine_id)),
			"mod_id": str(engine.get("mod_id", "")),
			"migration_namespace": str(engine.get("migration_namespace", "")),
			"device_persistence_key": str(engine.get("device_persistence_key", ""))
		}

	return manifest

func _upsert_contract_registry_entry(registry: Dictionary, key: String, incoming: Dictionary, entry_kind: String, state_id: String) -> void:
	if not registry.has(key):
		registry [key] = incoming.duplicate(true)
		return

	var existing: Dictionary = registry.get(key, {})
	var policy: String = _normalize_conflict_policy(incoming.get("conflict_policy", existing.get("conflict_policy", "highest_priority")))
	var action: String = _resolve_conflict_action(existing, incoming, policy)

	var conflict_row:= {
		"entry_kind": entry_kind,
		"id": key,
		"state_id": state_id,
		"policy": policy,
		"action": action,
		"existing_priority": int(existing.get("priority", 0)),
		"incoming_priority": int(incoming.get("priority", 0)),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	conflict_reports.append(conflict_row)

	match action:
		"replace":
			registry [key] = incoming.duplicate(true)
		"merge":
			var merged: Dictionary = existing.duplicate(true)
			_deep_merge_dictionary(merged, incoming)
			registry [key] = merged
		"keep_existing":
			registry [key] = existing
		"error":
			validation_reports ["conflict:%s:%s" % [entry_kind, key]] = {
				"valid": false,
				"errors": ["Contract conflict for %s '%s' could not be resolved." % [entry_kind, key]],
				"warnings": []
			}


func _resolve_conflict_action(existing: Dictionary, incoming: Dictionary, policy: String) -> String:
	match policy:
		"replace":
			return "replace"
		"merge":
			return "merge"
		"keep_existing":
			return "keep_existing"
		"error":
			return "error"
		_:
			var existing_priority: int = int(existing.get("priority", 0))
			var incoming_priority: int = int(incoming.get("priority", 0))
			if incoming_priority > existing_priority:
				return "replace"
			if incoming_priority == existing_priority:
				return "merge"
			return "keep_existing"


func _normalize_conflict_policy(value: Variant) -> String:
	var policy: String = str(value).strip_edges().to_lower()
	if policy not in ALLOWED_CONFLICT_POLICIES:
		return "highest_priority"
	return policy


func _normalize_missing_engine_policy(value: Variant) -> String:
	var policy: String = str(value).strip_edges().to_lower()
	if policy not in ALLOWED_MISSING_ENGINE_POLICIES:
		return "warn"
	return policy


func _merged_dictionary_copy(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		var base_value: Variant = out.get(key)

		if typeof(base_value) == TYPE_DICTIONARY and typeof(patch_value) == TYPE_DICTIONARY:
			out [key] = _merged_dictionary_copy(base_value as Dictionary, patch_value as Dictionary)
		else:
			out [key] = _make_binary_safe(patch_value)

	return out


func _path_parts(path: String) -> Array:
	var clean: String = str(path).strip_edges()
	if clean == "":
		return []
	clean = clean.replace("/", ".")
	var out: Array = []
	for part in clean.split("."):
		var p: String = str(part).strip_edges()
		if p != "":
			out.append(p)
	return out


func _has_nested_value(data: Dictionary, path: String) -> bool:
	var parts: Array = _path_parts(path)
	if parts.is_empty():
		return false

	var current: Variant = data
	for i in range(parts.size()):
		if typeof(current) != TYPE_DICTIONARY:
			return false
		var key: String = str(parts [i])
		if not (current as Dictionary).has(key):
			return false
		current = (current as Dictionary).get(key)

	return true


func _get_nested_value(data: Dictionary, path: String, fallback: Variant = null) -> Variant:
	var parts: Array = _path_parts(path)
	if parts.is_empty():
		return fallback

	var current: Variant = data
	for i in range(parts.size()):
		if typeof(current) != TYPE_DICTIONARY:
			return fallback
		var key: String = str(parts [i])
		if not (current as Dictionary).has(key):
			return fallback
		current = (current as Dictionary).get(key)

	return current


func _set_nested_value(data: Dictionary, path: String, value: Variant) -> void:
	var parts: Array = _path_parts(path)
	if parts.is_empty():
		return

	var current: Dictionary = data
	for i in range(parts.size() - 1):
		var key: String = str(parts [i])
		if not current.has(key) or typeof(current.get(key)) != TYPE_DICTIONARY:
			current [key] = {}
		current = current [key]

	current [str(parts.back())] = value


func _erase_nested_value(data: Dictionary, path: String) -> void:
	var parts: Array = _path_parts(path)
	if parts.is_empty():
		return

	var current: Dictionary = data
	for i in range(parts.size() - 1):
		var key: String = str(parts [i])
		if not current.has(key) or typeof(current.get(key)) != TYPE_DICTIONARY:
			return
		current = current [key]

	current.erase(str(parts.back()))

func _contract_failure(path: String, reason: String) -> Dictionary:
	return {
		"success": false,
		"path": path,
		"reason": reason,
		"validation": {
			"valid": false,
			"errors": [reason],
			"warnings": []
		}
	}
func _safe_meta_contract_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) == TYPE_ARRAY:
		for raw in value:
			if typeof(raw) == TYPE_DICTIONARY:
				out.append((raw as Dictionary).duplicate(true))
		return out

	if typeof(value) == TYPE_DICTIONARY:
		out.append((value as Dictionary).duplicate(true))

	return out
func _safe_event_bus_contract_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) == TYPE_ARRAY:
		for raw in value:
			if typeof(raw) == TYPE_DICTIONARY:
				out.append((raw as Dictionary).duplicate(true))
		return out

	if typeof(value) == TYPE_DICTIONARY:
		out.append((value as Dictionary).duplicate(true))

	return out
func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		out.append((raw as Dictionary).duplicate(true))

	return out


func _safe_string_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var direct: String = str(value).strip_edges()
		if direct != "":
			out.append(direct)
		return out

	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out

	for raw in value:
		var clean: String = str(raw).strip_edges()
		if clean != "":
			out.append(clean)

	return out


func _stable_id_from_path(path: String) -> String:
	var clean: String = str(path).strip_edges().get_file().get_basename().to_lower()
	return _stable_id_from_name(clean)


func _stable_id_from_name(name: String) -> String:
	var clean: String = str(name).strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")
	clean = clean.replace("/", "_")
	clean = clean.replace("'", "")
	clean = clean.replace("’", "")
	clean = clean.replace("•", "_")

	while clean.find("__") >= 0:
		clean = clean.replace("__", "_")

	if clean == "":
		return "game_state_contract"

	return clean


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