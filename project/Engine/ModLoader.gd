extends Resource
class_name ModLoader

const MOD_CONTRACT_SCHEMA:= "eralife.mod_contract"
const MOD_CONTRACT_VERSION:= 3
const MOD_PROVIDER_SCHEMA:= "eralife.mod_provider_contract"
const MOD_PROVIDER_VERSION:= 1
const MOD_FOLDER:= "user://mods"
const MOD_PACK_FOLDER:= "user://eralife_packs/mods"

const ALLOWED_CONFLICT_POLICIES:= [
	"highest_priority",
	"replace",
	"merge",
	"keep_existing",
	"error"
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

const ALLOWED_MOD_EXTENSIONS:= [
	".json",
	".mod.json",
	".pack",
	".elp",
	".bin",
	".gd"
]

var gs
var loaded_mods: Array = []
var mod_data: Dictionary = {}
var mod_priority: Dictionary = {}

var mod_contract_registry: Dictionary = {}
var mod_manifest_registry: Dictionary = {}
var mod_migration_registry: Dictionary = {}
var mod_validation_reports: Dictionary = {}
var mod_file_mtimes: Dictionary = {}
var mod_ingest_reports: Array = []
var quarantined_mods: Dictionary = {}
var active_mod_ids: Dictionary = {}
var last_load_report: Dictionary = {}
var last_hot_apply_report: Dictionary = {}
var hot_reload_enabled: bool = true

func _init(_gs):
	gs = _gs

func load_mods(options: Dictionary = {}) -> Dictionary:
	ensure_mod_folders()

	var reset_existing: bool = bool(options.get("reset", false))
	if reset_existing:
		_reset_mod_runtime_state()

	var report:= {
		"schema": "eralife.mod_contract_load_report",
		"version": MOD_CONTRACT_VERSION,
		"loaded": [],
		"failed": [],
		"skipped": [],
		"hot_apply": {},
		"loaded_at_ms": int(Time.get_ticks_msec())
	}

	var paths: Array = []
	for file_path in _mod_files_in_folder(MOD_FOLDER):
		paths.append(file_path)
	for file_path in _mod_files_in_folder(MOD_PACK_FOLDER):
		if file_path not in paths:
			paths.append(file_path)

	paths.sort()

	for file_path in paths:
		var load_report: Dictionary = load_mod_bundle_file(file_path, false)
		if bool(load_report.get("success", false)):
			report ["loaded"].append(load_report)
		elif bool(load_report.get("skipped", false)):
			report ["skipped"].append(load_report)
		else:
			report ["failed"].append(load_report)

	if bool(options.get("hot_apply", true)):
		report ["hot_apply"] = hot_apply_mod_contracts({
			"source": "load_mods",
			"force": bool(options.get("force", false))
		})

	last_load_report = report.duplicate(true)
	if gs != null:
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["mod_contract_last_load_report"] = report.duplicate(true)
		if "mod_contract_registry" in gs:
			gs.mod_contract_registry = export_registry()

	return report

func hot_reload_mods(
	force: bool = false
) -> Dictionary:
	return reload_mod_sources({
		"force": force,
		"hot_apply": true,
		"source": "hot_reload_mods"
	})


func reload_mod_sources(
	options: Dictionary = {}
) -> Dictionary:
	var force: bool = bool(
		options.get(
			"force",
			false
		)
	)
	var allow_hot_apply: bool = bool(
		options.get(
			"hot_apply",
			false
		)
	)

	if not hot_reload_enabled and not force:
		return {
			"schema": "eralife.mod_contract_hot_reload_report",
			"version": MOD_CONTRACT_VERSION,
			"changed": false,
			"reloaded": [],
			"failed": [],
			"hot_apply": {}
		}

	ensure_mod_folders()
	var changed_paths: Array = []

	for file_path in _mod_files_in_folder(MOD_FOLDER):
		var mtime: int = int(
			FileAccess.get_modified_time(file_path)
		)
		if (
			force
			or int(
				mod_file_mtimes.get(
					file_path,
					-1
				)
			) != mtime
		):
			changed_paths.append(file_path)

	for file_path in _mod_files_in_folder(MOD_PACK_FOLDER):
		var mtime: int = int(
			FileAccess.get_modified_time(file_path)
		)
		if (
			force
			or int(
				mod_file_mtimes.get(
					file_path,
					-1
				)
			) != mtime
		):
			if file_path not in changed_paths:
				changed_paths.append(file_path)

	var report: Dictionary = {
		"schema": "eralife.mod_contract_hot_reload_report",
		"version": MOD_CONTRACT_VERSION,
		"hot_reload_enabled": hot_reload_enabled,
		"changed": not changed_paths.is_empty(),
		"reloaded": [],
		"failed": [],
		"hot_apply": {},
		"source": str(
			options.get(
				"source",
				"reload_mod_sources"
			)
		),
		"checked_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if changed_paths.is_empty():
		return report

	changed_paths.sort()
	for file_path in changed_paths:
		var load_report: Dictionary = load_mod_bundle_file(
			file_path,
			true
		)
		if bool(
			load_report.get(
				"success",
				false
			)
		):
			report ["reloaded"].append(load_report)
		else:
			report ["failed"].append(load_report)

	if allow_hot_apply:
		report ["hot_apply"] = hot_apply_mod_contracts({
			"source": str(
				options.get(
					"source",
					"reload_mod_sources"
				)
			),
			"force": force
		})

	return report
func load_mod_bundle_file(path: String, replace_existing: bool = false) -> Dictionary:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "":
		return _mod_failure(clean_path, "Missing mod bundle path.")

	if not FileAccess.file_exists(clean_path):
		return _mod_failure(clean_path, "Mod bundle does not exist.")

	var parsed_report: Dictionary = parse_mod_bundle_file(clean_path)
	if not bool(parsed_report.get("success", false)):
		return parsed_report

	var raw_bundle: Dictionary = parsed_report.get("bundle", {})
	var normalized: Dictionary = normalize_mod_contract(raw_bundle, clean_path)
	var validation: Dictionary = validate_mod_contract(normalized)

	normalized ["validation"] = validation.duplicate(true)

	var mod_id: String = str(normalized.get("mod_id", clean_path)).strip_edges()
	if mod_id == "":
		mod_id = _stable_mod_id_from_path(clean_path)
		normalized ["mod_id"] = mod_id
		normalized ["id"] = mod_id

	mod_validation_reports [mod_id] = validation.duplicate(true)
	mod_file_mtimes [clean_path] = int(FileAccess.get_modified_time(clean_path))

	if not bool(validation.get("valid", false)):
		quarantined_mods [mod_id] = {
			"path": clean_path,
			"validation": validation.duplicate(true),
			"quarantined_at_ms": int(Time.get_ticks_msec())
		}
		return {
			"success": false,
			"path": clean_path,
			"mod_id": mod_id,
			"validation": validation.duplicate(true),
			"quarantined": true
		}

	if replace_existing and mod_contract_registry.has(mod_id):
		mod_contract_registry.erase(mod_id)
		mod_manifest_registry.erase(mod_id)
		active_mod_ids.erase(mod_id)

	_ingest_mod_contract(normalized, clean_path)

	return {
		"success": true,
		"path": clean_path,
		"mod_id": mod_id,
		"version": int(normalized.get("version", MOD_CONTRACT_VERSION)),
		"priority": int(normalized.get("priority", 0)),
		"validation": validation.duplicate(true)
	}

func parse_mod_bundle_file(path: String) -> Dictionary:
	var clean_path: String = str(path).strip_edges()
	var lower_path: String = clean_path.to_lower()

	if lower_path.ends_with(".gd"):
		return {
			"success": true,
			"path": clean_path,
			"bundle": _build_script_bridge_mod_contract(clean_path)
		}

	if lower_path.ends_with(".bin"):
		var f_bin:= FileAccess.open(clean_path, FileAccess.READ)
		if f_bin == null:
			return _mod_failure(clean_path, "Could not open binary mod bundle.")
		var bytes: PackedByteArray = f_bin.get_buffer(f_bin.get_length())
		f_bin.close()

		var decoded: Variant = BinarySaveEngine.decode(bytes)
		if typeof(decoded) != TYPE_DICTIONARY:
			return _mod_failure(clean_path, "Binary mod bundle did not decode to a Dictionary.")

		return {
			"success": true,
			"path": clean_path,
			"bundle": decoded
		}

	var f:= FileAccess.open(clean_path, FileAccess.READ)
	if f == null:
		return _mod_failure(clean_path, "Could not open mod bundle.")

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _mod_failure(clean_path, "Mod bundle JSON root must be a Dictionary.")

	return {
		"success": true,
		"path": clean_path,
		"bundle": parsed
	}

func normalize_mod_contract(
	raw_bundle: Dictionary,
	source_path: String = ""
) -> Dictionary:
	var warnings: Array = []
	var raw: Dictionary = raw_bundle.duplicate(true)

	if not _looks_like_mod_contract(raw):
		raw = _wrap_legacy_bundle_as_mod_contract(
			raw,
			source_path
		)

	var mod_id: String = str(
		raw.get(
			"mod_id",
			raw.get(
				"id",
				""
			)
		)
	).strip_edges()
	if mod_id == "":
		mod_id = _stable_mod_id_from_path(source_path)
		warnings.append(
			"Missing mod_id. Applied stable id '%s'." % mod_id
		)

	var version: int = max(
		1,
		int(
			raw.get(
				"version",
				MOD_CONTRACT_VERSION
			)
		)
	)
	if version > MOD_CONTRACT_VERSION:
		warnings.append(
			"Mod '%s' was authored for version %d. Runtime supports %d. Unknown fields will be preserved." % [
				mod_id,
				version,
				MOD_CONTRACT_VERSION
			]
		)

	var conflict_policy: String = str(
		raw.get(
			"conflict_policy",
			"highest_priority"
		)
	).strip_edges().to_lower()
	if conflict_policy not in ALLOWED_CONFLICT_POLICIES:
		warnings.append(
			"Invalid conflict policy '%s'. Falling back to highest_priority." % conflict_policy
		)
		conflict_policy = "highest_priority"

	var contracts_raw: Variant = raw.get(
		"contracts",
		{}
	)
	var contracts: Dictionary = (
		contracts_raw.duplicate(true)
		if typeof(contracts_raw) == TYPE_DICTIONARY
		else {}
	)
	var game_state_contract: Dictionary = (
		_extract_game_state_contract(
			raw,
			contracts,
			mod_id,
			conflict_policy
		)
	)
	var layer_contracts: Dictionary = (
		_extract_layer_contracts(
			raw,
			contracts,
			mod_id
		)
	)
	var providers: Array = _extract_provider_contracts(
		raw,
		contracts,
		mod_id
	)
	var migrations: Array = _safe_dictionary_array(
		raw.get(
			"migrations",
			raw.get(
				"save_migrations",
				[]
			)
		)
	)
	var compatibility: Dictionary = (
		raw.get(
			"compatibility",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"compatibility",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var metadata: Dictionary = (
		raw.get(
			"metadata",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"metadata",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var permissions: Dictionary = (
		raw.get(
			"permissions",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"permissions",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var marketplace: Dictionary = (
		raw.get(
			"marketplace",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"marketplace",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var settings_schema: Dictionary = (
		raw.get(
			"settings_schema",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"settings_schema",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var default_settings: Dictionary = (
		raw.get(
			"default_settings",
			{}
		).duplicate(true)
		if typeof(
			raw.get(
				"default_settings",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if not permissions.has("execution_mode"):
		permissions ["execution_mode"] = (
			"trusted_native_code"
			if source_path.to_lower().ends_with(".gd")
			else "data_only"
		)
	if not permissions.has("trusted_ui_contracts"):
		permissions ["trusted_ui_contracts"] = false

	metadata ["source_path"] = source_path
	metadata ["mod_id"] = mod_id
	metadata ["ingestion_authority"] = "mod_loader"
	metadata ["lifecycle_authority"] = "mod_contract_engine"

	return {
		"schema": str(
			raw.get(
				"schema",
				MOD_CONTRACT_SCHEMA
			)
		).strip_edges(),
		"version": version,
		"runtime_contract_version": MOD_CONTRACT_VERSION,
		"id": mod_id,
		"mod_id": mod_id,
		"name": str(
			raw.get(
				"name",
				mod_id
			)
		).strip_edges(),
		"description": str(
			raw.get(
				"description",
				""
			)
		).strip_edges(),
		"author": str(
			raw.get(
				"author",
				""
			)
		).strip_edges(),
		"release_version": str(
			raw.get(
				"release_version",
				raw.get(
					"marketplace_version",
					"1.0.0"
				)
			)
		).strip_edges(),
		"enabled": bool(
			raw.get(
				"enabled",
				true
			)
		),
		"priority": int(
			raw.get(
				"priority",
				0
			)
		),
		"conflict_policy": conflict_policy,
		"target_state_ids": _safe_string_array(
			raw.get(
				"target_state_ids",
				raw.get(
					"targets",
					[]
				)
			)
		),
		"required_mods": _safe_string_array(
			raw.get(
				"required_mods",
				raw.get(
					"dependencies",
					[]
				)
			)
		),
		"incompatible_mods": _safe_string_array(
			raw.get(
				"incompatible_mods",
				[]
			)
		),
		"compatibility": compatibility,
		"permissions": permissions,
		"marketplace": marketplace,
		"settings_schema": settings_schema,
		"default_settings": default_settings,
		"providers": providers,
		"game_state_contract": game_state_contract,
		"layer_contracts": layer_contracts,
		"migrations": migrations,
		"legacy_data_patch": (
			raw.get(
				"legacy_data_patch",
				raw.get(
					"data_patch",
					{}
				)
			).duplicate(true)
			if typeof(
				raw.get(
					"legacy_data_patch",
					raw.get(
						"data_patch",
						{}
					)
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"metadata": metadata,
		"warnings": warnings,
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": warnings
		}
	}

func validate_mod_contract(
	mod_contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var mod_id: String = str(
		mod_contract.get(
			"mod_id",
			""
		)
	).strip_edges()

	if mod_id == "":
		errors.append("Mod contract requires mod_id.")

	if not bool(
		mod_contract.get(
			"enabled",
			true
		)
	):
		warnings.append(
			"Mod '%s' is disabled." % mod_id
		)

	var required_mods: Array = mod_contract.get(
		"required_mods",
		[]
	)
	for required_mod in required_mods:
		var required_id: String = str(
			required_mod
		).strip_edges()
		if required_id == "":
			continue
		if (
			not active_mod_ids.has(required_id)
			and not mod_contract_registry.has(required_id)
		):
			warnings.append(
				"Required mod '%s' is not currently active. Load order may resolve this later." % required_id
			)

	var incompatible_mods: Array = mod_contract.get(
		"incompatible_mods",
		[]
	)
	for incompatible_mod in incompatible_mods:
		var incompatible_id: String = str(
			incompatible_mod
		).strip_edges()
		if incompatible_id == "":
			continue
		if (
			active_mod_ids.has(incompatible_id)
			or mod_contract_registry.has(incompatible_id)
		):
			errors.append(
				"Mod '%s' is incompatible with active mod '%s'." % [
					mod_id,
					incompatible_id
				]
			)

	var compatibility: Dictionary = (
		mod_contract.get(
			"compatibility",
			{}
		)
		if typeof(
			mod_contract.get(
				"compatibility",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var min_game_state_contract_version: int = int(
		compatibility.get(
			"min_game_state_contract_version",
			1
		)
	)
	var supported_game_state_contract_version: int = (
		GameStateContractEngine.CONTRACT_VERSION
	)
	if (
		min_game_state_contract_version
		> supported_game_state_contract_version
	):
		errors.append(
			"Mod '%s' requires GameStateContractEngine version %d, but runtime supports %d." % [
				mod_id,
				min_game_state_contract_version,
				supported_game_state_contract_version
			]
		)

	var game_state_contract: Dictionary = (
		mod_contract.get(
			"game_state_contract",
			{}
		)
		if typeof(
			mod_contract.get(
				"game_state_contract",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var layer_contracts: Dictionary = (
		mod_contract.get(
			"layer_contracts",
			{}
		)
		if typeof(
			mod_contract.get(
				"layer_contracts",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var legacy_patch: Dictionary = (
		mod_contract.get(
			"legacy_data_patch",
			{}
		)
		if typeof(
			mod_contract.get(
				"legacy_data_patch",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var providers: Array = (
		mod_contract.get(
			"providers",
			[]
		)
		if typeof(
			mod_contract.get(
				"providers",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	if (
		game_state_contract.is_empty()
		and layer_contracts.is_empty()
		and legacy_patch.is_empty()
		and providers.is_empty()
	):
		errors.append(
			"Mod '%s' has no supported contract surface." % mod_id
		)

	if not game_state_contract.is_empty():
		var contract_engine = _ensure_game_state_contract_engine()
		if (
			contract_engine != null
			and contract_engine.has_method("normalize_contract")
		):
			var normalized_state_contract: Dictionary = (
				contract_engine.normalize_contract(
					game_state_contract,
					"mod://%s" % mod_id
				)
			)
			var state_validation: Dictionary = (
				normalized_state_contract.get(
					"validation",
					{}
				)
			)
			for err in state_validation.get(
				"errors",
				[]
			):
				errors.append(
					"GameState contract: %s" % str(err)
				)
			for warn in state_validation.get(
				"warnings",
				[]
			):
				warnings.append(
					"GameState contract: %s" % str(warn)
				)

	for raw_provider in providers:
		if typeof(raw_provider) != TYPE_DICTIONARY:
			errors.append(
				"Every mod provider must be a Dictionary contract."
			)
			continue

		var provider: Dictionary = raw_provider as Dictionary
		if str(
			provider.get(
				"provider_id",
				provider.get(
					"id",
					""
				)
			)
		).strip_edges() == "":
			errors.append(
				"A mod provider requires provider_id."
			)
		if str(
			provider.get(
				"provider_type",
				provider.get(
					"type",
					""
				)
			)
		).strip_edges() == "":
			errors.append(
				"A mod provider requires provider_type."
			)

	for raw_migration in mod_contract.get(
		"migrations",
		[]
	):
		if typeof(raw_migration) != TYPE_DICTIONARY:
			continue

		var action: String = str(
			(raw_migration as Dictionary).get(
				"action",
				""
			)
		).strip_edges()
		if action not in ALLOWED_MIGRATION_ACTIONS:
			errors.append(
				"Unsupported mod migration action '%s'." % action
			)

	for warn in mod_contract.get(
		"warnings",
		[]
	):
		warnings.append(str(warn))

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}
func _extract_provider_contracts(
	raw: Dictionary,
	contracts: Dictionary,
	mod_id: String
) -> Array:
	var providers_raw: Variant = raw.get(
		"providers",
		contracts.get(
			"providers",
			[]
		)
	)

	if typeof(providers_raw) != TYPE_ARRAY:
		return []

	var providers: Array = []
	var provider_index: int = 0

	for raw_provider in providers_raw as Array:
		if typeof(raw_provider) != TYPE_DICTIONARY:
			continue

		var provider: Dictionary = (
			raw_provider as Dictionary
		).duplicate(true)
		var provider_id: String = str(
			provider.get(
				"provider_id",
				provider.get(
					"id",
					"provider_%d" % provider_index
				)
			)
		).strip_edges().to_lower()

		provider ["schema"] = str(
			provider.get(
				"schema",
				MOD_PROVIDER_SCHEMA
			)
		)
		provider ["version"] = max(
			1,
			int(
				provider.get(
					"version",
					MOD_PROVIDER_VERSION
				)
			)
		)
		provider ["mod_id"] = mod_id
		provider ["provider_id"] = provider_id
		provider ["id"] = provider_id
		provider ["provider_type"] = str(
			provider.get(
				"provider_type",
				provider.get(
					"type",
					""
				)
			)
		).strip_edges().to_lower()
		provider ["target_id"] = str(
			provider.get(
				"target_id",
				provider.get(
					"target",
					"default"
				)
			)
		).strip_edges().to_lower()
		provider ["api_version"] = max(
			1,
			int(
				provider.get(
					"api_version",
					1
				)
			)
		)
		provider ["enabled"] = bool(
			provider.get(
				"enabled",
				true
			)
		)
		provider ["priority"] = int(
			provider.get(
				"priority",
				raw.get(
					"priority",
					0
				)
			)
		)
		provider ["conflict_policy"] = str(
			provider.get(
				"conflict_policy",
				"namespace"
			)
		).strip_edges().to_lower()
		provider ["namespace"] = str(
			provider.get(
				"namespace",
				mod_id
			)
		).strip_edges()

		var provider_metadata: Dictionary = {}
		var provider_metadata_raw: Variant = provider.get(
			"metadata",
			{}
		)

		if typeof(provider_metadata_raw) == TYPE_DICTIONARY:
			provider_metadata = (
				provider_metadata_raw as Dictionary
			).duplicate(true)

		provider_metadata ["source"] = "mod_contract"
		provider_metadata ["mod_id"] = mod_id
		provider ["metadata"] = provider_metadata

		providers.append(provider)
		provider_index += 1

	return providers
func hot_apply_mod_contracts(context: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.mod_contract_hot_apply_report",
		"version": MOD_CONTRACT_VERSION,
		"context": context.duplicate(true),
		"applied": [],
		"skipped": [],
		"failed": [],
		"runtime_refresh": {},
		"applied_at_ms": int(Time.get_ticks_msec())
	}

	var contract_engine = _ensure_game_state_contract_engine()
	if contract_engine == null:
		report ["failed"].append({
			"reason": "GameStateContractEngine unavailable."
		})
		last_hot_apply_report = report.duplicate(true)
		return report

	var ordered_mods: Array = mod_contract_registry.values()
	ordered_mods.sort_custom(func (a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))

	for raw_mod in ordered_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod_contract: Dictionary = raw_mod
		var mod_id: String = str(mod_contract.get("mod_id", "")).strip_edges()

		if mod_id == "":
			report ["failed"].append({
				"reason": "Mod contract missing mod_id."
			})
			continue

		if not bool(mod_contract.get("enabled", true)):
			report ["skipped"].append({
				"mod_id": mod_id,
				"reason": "disabled"
			})
			continue

		var apply_report: Dictionary = apply_mod_contract(mod_contract)
		if bool(apply_report.get("success", false)):
			report ["applied"].append(apply_report)
			active_mod_ids [mod_id] = true
			if mod_id not in loaded_mods:
				loaded_mods.append(mod_id)
		else:
			report ["failed"].append(apply_report)

	if contract_engine.has_method("instantiate_contract_engine_extensions"):
		report ["runtime_refresh"] ["instantiation"] = contract_engine.instantiate_contract_engine_extensions()
	if contract_engine.has_method("register_existing_engines_from_game_state"):
		report ["runtime_refresh"] ["registered_engines"] = contract_engine.register_existing_engines_from_game_state()
	if contract_engine.has_method("validate_active_contracts"):
		report ["runtime_refresh"] ["validation"] = contract_engine.validate_active_contracts({
			"phase": "mod_contract_hot_apply",
			"include_runtime": true
		})
	if contract_engine.has_method("build_runtime_phase_budget_report"):
		report ["runtime_refresh"] ["phase_budget"] = contract_engine.build_runtime_phase_budget_report({
			"phase": "mod_contract_hot_apply"
		})
	if contract_engine.has_method("apply_runtime_guards"):
		report ["runtime_refresh"] ["runtime_guard"] = contract_engine.apply_runtime_guards({
			"phase": "mod_contract_hot_apply"
		})
	if contract_engine.has_method("hydrate_runtime_state"):
		report ["runtime_refresh"] ["hydration"] = contract_engine.hydrate_runtime_state({
			"phase": "mod_contract_hot_apply"
		})

	last_hot_apply_report = report.duplicate(true)

	if gs != null:
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["mod_contract_last_hot_apply_report"] = report.duplicate(true)
		if "mod_contract_runtime_report" in gs:
			gs.mod_contract_runtime_report = report.duplicate(true)
		if "mod_contract_registry" in gs:
			gs.mod_contract_registry = export_registry()

	return report

func apply_mod_contract(mod_contract: Dictionary) -> Dictionary:
	var mod_id: String = str(mod_contract.get("mod_id", "")).strip_edges()

	var report:= {
		"schema": "eralife.mod_contract_apply_report",
		"version": MOD_CONTRACT_VERSION,
		"mod_id": mod_id,
		"success": false,
		"game_state_contract": {},
		"layers": {},
		"legacy_patch": {},
		"applied_at_ms": int(Time.get_ticks_msec())
	}

	var contract_engine = _ensure_game_state_contract_engine()
	if contract_engine == null:
		report ["reason"] = "GameStateContractEngine unavailable."
		return report

	var game_state_contract: Dictionary = mod_contract.get("game_state_contract", {}) if typeof(mod_contract.get("game_state_contract", {})) == TYPE_DICTIONARY else {}
	if not game_state_contract.is_empty():
		if contract_engine.has_method("load_contract_from_dictionary"):
			report ["game_state_contract"] = contract_engine.load_contract_from_dictionary(game_state_contract, "mod://%s" % mod_id)
		else:
			report ["game_state_contract"] = {
				"success": false,
				"reason": "GameStateContractEngine missing load_contract_from_dictionary."
			}

		if not bool(report ["game_state_contract"].get("success", false)):
			report ["reason"] = "GameState contract failed to load."
			return report

	var layer_contracts: Dictionary = mod_contract.get("layer_contracts", {}) if typeof(mod_contract.get("layer_contracts", {})) == TYPE_DICTIONARY else {}
	report ["layers"] = _apply_layer_contracts(layer_contracts, mod_id)

	var legacy_patch: Dictionary = mod_contract.get("legacy_data_patch", {}) if typeof(mod_contract.get("legacy_data_patch", {})) == TYPE_DICTIONARY else {}
	if not legacy_patch.is_empty():
		report ["legacy_patch"] = _apply_data_patch(legacy_patch, mod_id)

	report ["success"] = true
	return report

func apply_save_migrations(save_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = save_data.duplicate(true)

	var migration_ledger: Dictionary = migrated.get("save_migration_ledger", {}) if typeof(migrated.get("save_migration_ledger", {})) == TYPE_DICTIONARY else {}
	var ordered_mods: Array = mod_contract_registry.values()
	ordered_mods.sort_custom(func (a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))

	for raw_mod in ordered_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod_contract: Dictionary = raw_mod
		if not bool(mod_contract.get("enabled", true)):
			continue

		var mod_id: String = str(mod_contract.get("mod_id", "")).strip_edges()
		if mod_id == "":
			continue

		for raw_migration in mod_contract.get("migrations", []):
			if typeof(raw_migration) != TYPE_DICTIONARY:
				continue

			var migration: Dictionary = raw_migration
			var migration_key: String = _migration_ledger_key(mod_id, migration)
			if migration_key == "":
				continue

			if bool(migration_ledger.get(migration_key, false)):
				continue

			migrated = _apply_save_migration(migrated, migration, mod_id)
			migration_ledger [migration_key] = true

	migrated ["save_migration_ledger"] = migration_ledger
	migrated ["last_mod_migration_pass"] = {
		"schema": "eralife.mod_save_migration_pass",
		"version": MOD_CONTRACT_VERSION,
		"mod_count": ordered_mods.size(),
		"applied_count": migration_ledger.size(),
		"migrated_at_ms": int(Time.get_ticks_msec())
	}

	return migrated
func _migration_ledger_key(mod_id: String, migration: Dictionary) -> String:
	var clean_mod_id: String = str(mod_id).strip_edges()
	if clean_mod_id == "":
		return ""

	var migration_id: String = str(migration.get("id", migration.get("migration_id", ""))).strip_edges()
	if migration_id == "":
		migration_id = "%s:%s:%s:%s:%s" % [
			str(migration.get("action", "")),
			str(migration.get("key", "")),
			str(migration.get("from", "")),
			str(migration.get("to", "")),
			str(migration.get("method", ""))
		]

	var target_version: String = str(migration.get("target_version", migration.get("version", ""))).strip_edges()
	var migration_namespace: String = str(migration.get("namespace", clean_mod_id)).strip_edges()

	return "%s|%s|%s|%s" % [clean_mod_id, migration_namespace, migration_id, target_version]

func import_registry(raw_registry: Dictionary = {}) -> Dictionary:
	_reset_mod_runtime_state()

	var report:= {
		"schema": "eralife.mod_contract_import_report",
		"version": MOD_CONTRACT_VERSION,
		"imported": [],
		"failed": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	var registry_raw: Variant = raw_registry.get("mod_contract_registry", raw_registry.get("contracts", {}))
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for key in (registry_raw as Dictionary).keys():
			var mod_raw: Variant = (registry_raw as Dictionary).get(key, {})
			if typeof(mod_raw) != TYPE_DICTIONARY:
				continue

			var normalized: Dictionary = normalize_mod_contract(mod_raw, str((mod_raw as Dictionary).get("metadata", {}).get("source_path", "save://mod_registry")) if typeof((mod_raw as Dictionary).get("metadata", {})) == TYPE_DICTIONARY else "save://mod_registry")
			var validation: Dictionary = validate_mod_contract(normalized)
			normalized ["validation"] = validation.duplicate(true)

			if not bool(validation.get("valid", false)):
				report ["failed"].append({
					"mod_id": str(normalized.get("mod_id", key)),
					"validation": validation.duplicate(true)
				})
				continue

			_ingest_mod_contract(normalized, str(normalized.get("metadata", {}).get("source_path", "save://mod_registry")) if typeof(normalized.get("metadata", {})) == TYPE_DICTIONARY else "save://mod_registry")
			report ["imported"].append(str(normalized.get("mod_id", key)))

	loaded_mods = raw_registry.get("loaded_mods", []).duplicate(true) if typeof(raw_registry.get("loaded_mods", [])) == TYPE_ARRAY else []
	mod_data = raw_registry.get("mod_data", {}).duplicate(true) if typeof(raw_registry.get("mod_data", {})) == TYPE_DICTIONARY else {}
	mod_priority = raw_registry.get("mod_priority", {}).duplicate(true) if typeof(raw_registry.get("mod_priority", {})) == TYPE_DICTIONARY else {}
	mod_file_mtimes = raw_registry.get("mod_file_mtimes", {}).duplicate(true) if typeof(raw_registry.get("mod_file_mtimes", {})) == TYPE_DICTIONARY else {}

	return report

func export_registry() -> Dictionary:
	return {
		"schema": "eralife.mod_contract_registry",
		"version": MOD_CONTRACT_VERSION,
		"mod_contract_registry": mod_contract_registry.duplicate(true),
		"mod_manifest_registry": mod_manifest_registry.duplicate(true),
		"mod_migration_registry": mod_migration_registry.duplicate(true),
		"mod_validation_reports": mod_validation_reports.duplicate(true),
		"mod_file_mtimes": mod_file_mtimes.duplicate(true),
		"loaded_mods": loaded_mods.duplicate(true),
		"mod_data": mod_data.duplicate(true),
		"mod_priority": mod_priority.duplicate(true),
		"quarantined_mods": quarantined_mods.duplicate(true),
		"last_load_report": last_load_report.duplicate(true),
		"last_hot_apply_report": last_hot_apply_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return export_registry()

func import_state(raw_state: Dictionary = {}) -> Dictionary:
	return import_registry(raw_state)

func register_event_hook(event_name: String, target, method: String):
	if gs == null or gs.event_bus == null:
		return
	gs.event_bus.subscribe(event_name, target, method)

func _load_json_mod(filename):
	return load_mod_bundle_file(_mod_path_from_filename(filename), false)

func _load_script_mod(filename):
	return load_mod_bundle_file(_mod_path_from_filename(filename), false)

func _apply_data_patch(data: Dictionary, mod_id: String = "legacy") -> Dictionary:
	var report:= {
		"schema": "eralife.mod_legacy_data_patch_report",
		"version": MOD_CONTRACT_VERSION,
		"mod_id": mod_id,
		"patched_keys": []
	}

	if not mod_data.has(mod_id):
		mod_data [mod_id] = {}

	var bucket: Dictionary = mod_data.get(mod_id, {})
	for key in data.keys():
		bucket [key] = data [key]
		report ["patched_keys"].append(str(key))

	mod_data [mod_id] = bucket
	return report

func _apply_layer_contracts(layer_contracts: Dictionary, mod_id: String) -> Dictionary:
	var report:= {
		"mod_id": mod_id,
		"applied": [],
		"skipped": [],
		"failed": []
	}

	var layer_targets:= {
		"realm": "realm_contract_engine",
		"realms": "realm_contract_engine",
		"simulation": "simulation_contract_engine",
		"ui": "ui_contract_engine",
		"world": "world_engine",
		"world_engine": "world_engine",
		"life": "life_engine",
		"life_engine": "life_engine",
		"event_bus": "event_bus_contract_layer"
	}

	for layer_key in layer_contracts.keys():
		var clean_layer: String = str(layer_key).strip_edges()
		var engine_property: String = str(layer_targets.get(clean_layer, "")).strip_edges()
		var payload: Variant = layer_contracts.get(layer_key)

		if engine_property == "":
			report ["skipped"].append({
				"layer": clean_layer,
				"reason": "unknown_layer"
			})
			continue

		var engine = _engine_from_game_state(engine_property)
		if engine == null:
			report ["failed"].append({
				"layer": clean_layer,
				"engine": engine_property,
				"reason": "missing_engine"
			})
			continue

		var layer_report: Dictionary = _apply_contract_payload_to_engine(engine, payload, "mod://%s/%s" % [mod_id, clean_layer])
		if bool(layer_report.get("success", false)):
			report ["applied"].append({
				"layer": clean_layer,
				"engine": engine_property,
				"report": layer_report
			})
		else:
			report ["failed"].append({
				"layer": clean_layer,
				"engine": engine_property,
				"report": layer_report
			})

	return report

func _apply_contract_payload_to_engine(engine, payload: Variant, source_label: String) -> Dictionary:
	if typeof(payload) != TYPE_DICTIONARY and typeof(payload) != TYPE_ARRAY:
		return {
			"success": false,
			"reason": "payload_must_be_dictionary_or_array"
		}

	if engine.has_method("load_contract_from_dictionary") and typeof(payload) == TYPE_DICTIONARY:
		return engine.load_contract_from_dictionary(payload, source_label)

	if engine.has_method("configure") and typeof(payload) == TYPE_DICTIONARY:
		return {
			"success": true,
			"configure_report": engine.configure(payload)
		}

	if engine.has_method("import_registry") and typeof(payload) == TYPE_DICTIONARY:
		return {
			"success": true,
			"import_report": engine.import_registry(payload)
		}

	if engine.has_method("load_contracts_from_array") and typeof(payload) == TYPE_ARRAY:
		return {
			"success": true,
			"load_report": engine.load_contracts_from_array(payload, source_label)
		}

	return {
		"success": false,
		"reason": "target_engine_has_no_supported_contract_ingest_method"
	}

func _apply_save_migration(save_data: Dictionary, migration: Dictionary, mod_id: String) -> Dictionary:
	var out: Dictionary = save_data.duplicate(true)
	var action: String = str(migration.get("action", "")).strip_edges()

	match action:
		"set_default":
			var key: String = str(migration.get("key", "")).strip_edges()
			if key != "" and not out.has(key):
				out [key] = migration.get("value")
		"rename_key":
			var from_key: String = str(migration.get("from", "")).strip_edges()
			var to_key: String = str(migration.get("to", "")).strip_edges()
			if from_key != "" and to_key != "" and out.has(from_key) and not out.has(to_key):
				out [to_key] = out.get(from_key)
				out.erase(from_key)
		"copy_key":
			var from_copy: String = str(migration.get("from", "")).strip_edges()
			var to_copy: String = str(migration.get("to", "")).strip_edges()
			if from_copy != "" and to_copy != "" and out.has(from_copy) and not out.has(to_copy):
				out [to_copy] = out.get(from_copy)
		"delete_key":
			var delete_key: String = str(migration.get("key", "")).strip_edges()
			if delete_key != "" and out.has(delete_key):
				out.erase(delete_key)
		"ensure_dictionary":
			var dict_key: String = str(migration.get("key", "")).strip_edges()
			if dict_key != "" and typeof(out.get(dict_key, {})) != TYPE_DICTIONARY:
				out [dict_key] = {}
		"ensure_array":
			var array_key: String = str(migration.get("key", "")).strip_edges()
			if array_key != "" and typeof(out.get(array_key, [])) != TYPE_ARRAY:
				out [array_key] = []
		"call_method":
			var method_name: String = str(migration.get("method", "")).strip_edges()
			if method_name != "" and has_method(method_name):
				var result: Variant = callv(method_name, [out, migration, mod_id])
				if typeof(result) == TYPE_DICTIONARY:
					out = result
		_:
			pass

	return out

func _ingest_mod_contract(mod_contract: Dictionary, source_path: String = "") -> void:
	var mod_id: String = str(mod_contract.get("mod_id", "")).strip_edges()
	if mod_id == "":
		return

	mod_contract_registry [mod_id] = mod_contract.duplicate(true)
	mod_manifest_registry [mod_id] = {
		"mod_id": mod_id,
		"name": str(mod_contract.get("name", mod_id)),
		"version": int(mod_contract.get("version", MOD_CONTRACT_VERSION)),
		"priority": int(mod_contract.get("priority", 0)),
		"enabled": bool(mod_contract.get("enabled", true)),
		"source_path": source_path,
		"loaded_at_ms": int(Time.get_ticks_msec())
	}
	mod_priority [mod_id] = int(mod_contract.get("priority", 0))
	mod_migration_registry [mod_id] = mod_contract.get("migrations", []).duplicate(true) if typeof(mod_contract.get("migrations", [])) == TYPE_ARRAY else []

	mod_ingest_reports.append({
		"mod_id": mod_id,
		"source_path": source_path,
		"priority": int(mod_contract.get("priority", 0)),
		"ingested_at_ms": int(Time.get_ticks_msec())
	})

func _extract_game_state_contract(
	raw: Dictionary,
	contracts: Dictionary,
	mod_id: String,
	conflict_policy: String
) -> Dictionary:
	var out: Dictionary = {}
	var direct_raw: Variant = raw.get(
		"game_state_contract",
		contracts.get(
			"game_state",
			{}
		)
	)
	if typeof(direct_raw) == TYPE_DICTIONARY:
		out = (
			direct_raw as Dictionary
		).duplicate(true)

	var supported_sections: Array = [
		"engines",
		"save_slices",
		"runtime_phases",
		"event_subscriptions",
		"event_bus_contracts",
		"meta_contracts",
		"hydration_rules"
	]
	for section in supported_sections:
		if raw.has(section):
			out [section] = raw.get(section)
		elif contracts.has(section):
			out [section] = contracts.get(section)

	if out.is_empty():
		return {}

	out ["state_id"] = str(
		out.get(
			"state_id",
			"mod.%s" % mod_id
		)
	).strip_edges()
	out ["id"] = str(
		out.get(
			"id",
			out.get(
				"state_id",
				"mod.%s" % mod_id
			)
		)
	).strip_edges()
	out ["schema"] = str(
		out.get(
			"schema",
			"eralife.game_state_contract"
		)
	).strip_edges()
	out ["version"] = max(
		1,
		int(
			out.get(
				"version",
				2
			)
		)
	)
	out ["name"] = str(
		out.get(
			"name",
			mod_id
		)
	).strip_edges()

	var metadata: Dictionary = (
		out.get(
			"metadata",
			{}
		).duplicate(true)
		if typeof(
			out.get(
				"metadata",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	metadata ["source"] = "mod_contract"
	metadata ["mod_id"] = mod_id
	out ["metadata"] = metadata

	for section in supported_sections:
		var section_raw: Variant = out.get(
			section,
			[]
		)
		if typeof(section_raw) != TYPE_ARRAY:
			continue

		var normalized_rows: Array = []
		for row_raw in section_raw:
			if typeof(row_raw) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				row_raw as Dictionary
			).duplicate(true)

			if not row.has("conflict_policy"):
				row ["conflict_policy"] = conflict_policy
			if not row.has("priority"):
				row ["priority"] = int(
					raw.get(
						"priority",
						0
					)
				)

			row ["mod_id"] = mod_id
			row ["mod_namespace"] = "mod.%s" % mod_id

			var row_metadata: Dictionary = (
				row.get(
					"metadata",
					{}
				).duplicate(true)
				if typeof(
					row.get(
						"metadata",
						{}
					)
				) == TYPE_DICTIONARY
				else {}
			)
			row_metadata ["source"] = "mod_contract"
			row_metadata ["mod_id"] = mod_id
			row_metadata ["source_state_id"] = out ["state_id"]
			row ["metadata"] = row_metadata

			normalized_rows.append(row)

		out [section] = normalized_rows

	return out

func _extract_layer_contracts(raw: Dictionary, contracts: Dictionary, _mod_id: String) -> Dictionary:
	var out: Dictionary = {}

	var layer_keys:= [
		"realm",
		"realms",
		"simulation",
		"ui",
		"world",
		"world_engine",
		"life",
		"life_engine",
		"event_bus"
	]

	for key in layer_keys:
		if contracts.has(key):
			out [key] = contracts.get(key)
		elif raw.has("%s_contract" % key):
			out [key] = raw.get("%s_contract" % key)

	return out

func _looks_like_mod_contract(raw: Dictionary) -> bool:
	if str(raw.get("schema", "")).strip_edges() == MOD_CONTRACT_SCHEMA:
		return true
	if raw.has("mod_id") or raw.has("contracts") or raw.has("compatibility") or raw.has("migrations"):
		return true
	return false

func _wrap_legacy_bundle_as_mod_contract(raw: Dictionary, source_path: String) -> Dictionary:
	var mod_id: String = _stable_mod_id_from_path(source_path)

	if _has_game_state_contract_sections(raw):
		return {
			"schema": MOD_CONTRACT_SCHEMA,
			"version": MOD_CONTRACT_VERSION,
			"mod_id": mod_id,
			"name": mod_id,
			"priority": int(raw.get("priority", 0)),
			"conflict_policy": str(raw.get("conflict_policy", "highest_priority")),
			"game_state_contract": raw.duplicate(true),
			"metadata": {
				"source_path": source_path
			}
		}

	return {
		"schema": MOD_CONTRACT_SCHEMA,
		"version": MOD_CONTRACT_VERSION,
		"mod_id": mod_id,
		"name": mod_id,
		"priority": int(raw.get("priority", 0)),
		"legacy_data_patch": raw.duplicate(true),
		"metadata": {
			"source_path": source_path
		}
	}

func _build_script_bridge_mod_contract(
	script_path: String
) -> Dictionary:
	var mod_id: String = _stable_mod_id_from_path(
		script_path
	)
	var engine_id: String = "mod_%s_engine" % (
		mod_id
			.replace(".", "_")
			.replace("-", "_")
	)

	return {
		"schema": MOD_CONTRACT_SCHEMA,
		"version": MOD_CONTRACT_VERSION,
		"mod_id": mod_id,
		"name": mod_id,
		"priority": 0,
		"conflict_policy": "highest_priority",
		"permissions": {
			"execution_mode": "trusted_native_code",
			"trusted_ui_contracts": false
		},
		"game_state_contract": {
			"schema": "eralife.game_state_contract",
			"version": (
				GameStateContractEngine.CONTRACT_VERSION
			),
			"state_id": "mod.%s" % mod_id,
			"name": mod_id,
			"engines": [
				{
					"id": engine_id,
					"class": engine_id,
					"script_path": script_path,
					"runtime_property": engine_id,
					"runtime_lookup_keys": [
						engine_id
					],
					"aliases": [
						engine_id,
						mod_id
					],
					"boot_phase": "domain_extensions",
					"boot_order": 10000,
					"priority": 0,
					"enabled": true,
					"required": false,
					"allow_contract_instantiation": true,
					"auto_save_slice": true,
					"snapshot_export_method": "export_state",
					"snapshot_import_method": "import_state",
					"migration_namespace": "mod.%s.%s" % [
						mod_id,
						engine_id
					],
					"device_persistence_key": "mod.%s.%s" % [
						mod_id,
						engine_id
					],
					"update_policy": "preserve_save_slice",
					"missing_engine_policy": "quarantine",
					"conflict_policy": "highest_priority",
					"mod_id": mod_id,
					"metadata": {
						"source": "legacy_script_bridge",
						"mod_id": mod_id,
					}
				}
			],
			"metadata": {
				"source": "legacy_script_bridge",
				"mod_id": mod_id
			}
		},
		"metadata": {
			"source_path": script_path
		}
	}
func _has_game_state_contract_sections(raw: Dictionary) -> bool:
	for key in ["engines", "save_slices", "runtime_phases", "event_subscriptions", "event_bus_contracts", "meta_contracts", "hydration_rules"]:
		if raw.has(key):
			return true
	return false

func _ensure_game_state_contract_engine():
	if gs == null:
		return null
	if gs.game_state_contract_engine == null:
		gs.game_state_contract_engine = GameStateContractEngine.new(gs)
	return gs.game_state_contract_engine

func _engine_from_game_state(engine_property: String):
	if gs == null:
		return null
	var clean_property: String = str(engine_property).strip_edges()
	if clean_property == "":
		return null
	return gs.get(clean_property)

func ensure_mod_folders() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOD_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOD_PACK_FOLDER))

func _mod_files_in_folder(folder_path: String) -> Array:
	var out: Array = []
	var dir:= DirAccess.open(folder_path)
	if dir == null:
		return out

	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var path: String = folder_path.path_join(file)
			if _is_supported_mod_file(path):
				out.append(path)
		file = dir.get_next()
	dir.list_dir_end()

	return out

func _is_supported_mod_file(path: String) -> bool:
	var lower_path: String = str(path).to_lower()
	for ext in ALLOWED_MOD_EXTENSIONS:
		if lower_path.ends_with(str(ext)):
			return true
	return false

func _mod_path_from_filename(filename: String) -> String:
	var clean_filename: String = str(filename).strip_edges()
	if clean_filename.begins_with("user://"):
		return clean_filename
	return MOD_FOLDER.path_join(clean_filename)

func _stable_mod_id_from_path(path: String) -> String:
	var clean_path: String = str(path).strip_edges()
	var file_name: String = clean_path.get_file()
	var without_ext: String = file_name

	for ext in ALLOWED_MOD_EXTENSIONS:
		if without_ext.to_lower().ends_with(str(ext)):
			without_ext = without_ext.substr(0, without_ext.length() - str(ext).length())

	without_ext = without_ext.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_").to_lower()
	if without_ext == "":
		without_ext = "mod_%d" % abs(hash(clean_path))

	return without_ext

func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))

	return out

func _safe_string_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		var text: String = str(raw).strip_edges()
		if text != "":
			out.append(text)

	return out

func _reset_mod_runtime_state() -> void:
	loaded_mods.clear()
	mod_data.clear()
	mod_priority.clear()
	mod_contract_registry.clear()
	mod_manifest_registry.clear()
	mod_migration_registry.clear()
	mod_validation_reports.clear()
	mod_file_mtimes.clear()
	mod_ingest_reports.clear()
	quarantined_mods.clear()
	active_mod_ids.clear()
	last_load_report.clear()
	last_hot_apply_report.clear()

func _mod_failure(path: String, reason: String) -> Dictionary:
	return {
		"success": false,
		"path": path,
		"reason": reason
	}