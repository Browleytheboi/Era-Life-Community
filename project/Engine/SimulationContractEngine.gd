extends Resource
class_name SimulationContractEngine

const PACK_SCHEMA:= "eralife.simulation_pack"
const PACK_VERSION:= 1

const DEFAULT_PACK_ROOT:= "user://eralife_packs"
const REALM_PACK_FOLDER:= "user://eralife_packs/realms"
const SIMULATION_PACK_FOLDER:= "user://eralife_packs/simulation_layers"
const UI_PACK_FOLDER:= "user://eralife_packs/ui"
const ERA_PACK_FOLDER:= "user://eralife_packs/eras"
const NPC_PACK_FOLDER:= "user://eralife_packs/npc_generation"
const SCENARIO_PACK_FOLDER:= "user://eralife_packs/scenarios"
const FACTION_PACK_FOLDER:= "user://eralife_packs/factions"

const ALLOWED_TIME_MODELS:= [
	"normal",
	"looping",
	"stasis",
	"belief_progression",
	"accelerated",
	"fragmented"
]

const ALLOWED_POPULATION_MODELS:= [
	"static",
	"linear_growth",
	"linear_decline",
	"exponential_growth",
	"scarcity_decline",
	"belief_scaled",
	"cyclical"
]

const ALLOWED_FACTION_PRESSURE_MODELS:= [
	"none",
	"stable",
	"territorial_conflict",
	"court_intrigue",
	"belief_schism",
	"resource_war",
	"dynastic_tension"
]

const ALLOWED_DEATH_LOGIC:= [
	"normal",
	"ritual_based",
	"immortal",
	"belief_fade",
	"loop_reset",
	"realm_bound"
]

const SUPPORTED_SIMULATION_LAYERS:= [
	"relationships",
	"careers",
	"factions",
	"religion",
	"economy",
	"war",
	"activities",
	"belongings",
	"artifact_actions",
	"ui",
	"scenarios",
	"npc_generation",
	"eras",
	"jobs"
]

var gs

var pack_registry: Dictionary = {}
var pack_file_mtimes: Dictionary = {}
var layer_registry: Dictionary = {}
var validation_reports: Dictionary = {}
var system_registry: Dictionary = {}
var era_contract_registry: Dictionary = {}
var job_contract_registry: Dictionary = {}
var npc_generation_registry: Dictionary = {}
var scenario_contract_registry: Dictionary = {}
var faction_contract_registry: Dictionary = {}
var hot_reload_enabled: bool = true
var last_hot_reload_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func ensure_pack_folders() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEFAULT_PACK_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REALM_PACK_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SIMULATION_PACK_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UI_PACK_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ERA_PACK_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NPC_PACK_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENARIO_PACK_FOLDER))

func load_external_packs() -> Dictionary:
	ensure_pack_folders()

	var report:= {
		"schema": PACK_SCHEMA,
		"version": PACK_VERSION,
		"loaded": [],
		"failed": [],
		"validation_reports": {},
		"loaded_at_ms": int(Time.get_ticks_msec())
	}

	for folder_path in [REALM_PACK_FOLDER, SIMULATION_PACK_FOLDER, UI_PACK_FOLDER, ERA_PACK_FOLDER, NPC_PACK_FOLDER, SCENARIO_PACK_FOLDER, FACTION_PACK_FOLDER]:
		var folder_report: Dictionary = _load_packs_from_folder(folder_path)
		for row in folder_report.get("loaded", []):
			report ["loaded"].append(row)
		for row in folder_report.get("failed", []):
			report ["failed"].append(row)

	report ["validation_reports"] = validation_reports.duplicate(true)
	last_hot_reload_report = report.duplicate(true)
	return report

func hot_reload_external_packs(force: bool = false) -> Dictionary:
	if not hot_reload_enabled and not force:
		return {
			"schema": PACK_SCHEMA,
			"version": PACK_VERSION,
			"changed": false,
			"reloaded": [],
			"failed": []
		}

	ensure_pack_folders()

	var changed_paths: Array = []
	for folder_path in [REALM_PACK_FOLDER, SIMULATION_PACK_FOLDER, UI_PACK_FOLDER, ERA_PACK_FOLDER, NPC_PACK_FOLDER, SCENARIO_PACK_FOLDER, FACTION_PACK_FOLDER]:
		for file_path in _json_files_in_folder(folder_path):
			var mtime: int = int(FileAccess.get_modified_time(file_path))
			if force or int(pack_file_mtimes.get(file_path, -1)) != mtime:
				changed_paths.append(file_path)

	var report:= {
		"schema": PACK_SCHEMA,
		"version": PACK_VERSION,
		"hot_reload_enabled": hot_reload_enabled,
		"changed": not changed_paths.is_empty(),
		"reloaded": [],
		"failed": [],
		"checked_at_ms": int(Time.get_ticks_msec())
	}

	if changed_paths.is_empty():
		last_hot_reload_report = report.duplicate(true)
		return report

	for file_path in changed_paths:
		var load_report: Dictionary = load_pack_file(file_path, true)
		if bool(load_report.get("success", false)):
			report ["reloaded"].append(load_report)
		else:
			report ["failed"].append(load_report)

	if gs != null and gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("repair_runtime_realm_maps"):
		gs.realm_contract_engine.repair_runtime_realm_maps()

	last_hot_reload_report = report.duplicate(true)
	return report

func load_pack_file(path: String, replace_existing: bool = false) -> Dictionary:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "":
		return _pack_failure(clean_path, "Missing pack path.")

	if not FileAccess.file_exists(clean_path):
		return _pack_failure(clean_path, "Pack file does not exist.")

	var f:= FileAccess.open(clean_path, FileAccess.READ)
	if f == null:
		return _pack_failure(clean_path, "Could not open pack file.")

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _pack_failure(clean_path, "Pack JSON root must be a Dictionary.")

	var pack: Dictionary = parsed
	var normalized: Dictionary = normalize_pack(pack, clean_path)
	var validation: Dictionary = normalized.get("validation", {})

	if not bool(validation.get("valid", false)):
		validation_reports [clean_path] = validation.duplicate(true)
		return {
			"success": false,
			"path": clean_path,
			"pack_id": str(normalized.get("id", clean_path)),
			"validation": validation
		}

	var pack_id: String = str(normalized.get("id", clean_path)).strip_edges()
	if replace_existing and pack_registry.has(pack_id):
		pack_registry.erase(pack_id)

	pack_registry [pack_id] = normalized.duplicate(true)
	pack_file_mtimes [clean_path] = int(FileAccess.get_modified_time(clean_path))
	validation_reports [pack_id] = validation.duplicate(true)

	_ingest_pack(normalized)

	return {
		"success": true,
		"path": clean_path,
		"pack_id": pack_id,
		"validation": validation
	}

func load_pack_from_dictionary(pack: Dictionary, source_label: String = "runtime_pack") -> Dictionary:
	var normalized: Dictionary = normalize_pack(pack, source_label)
	var validation: Dictionary = normalized.get("validation", {})
	if not bool(validation.get("valid", false)):
		validation_reports [source_label] = validation.duplicate(true)
		return {
			"success": false,
			"path": source_label,
			"pack_id": str(normalized.get("id", source_label)),
			"validation": validation
		}

	var pack_id: String = str(normalized.get("id", source_label)).strip_edges()
	pack_registry [pack_id] = normalized.duplicate(true)
	validation_reports [pack_id] = validation.duplicate(true)
	_ingest_pack(normalized)

	return {
		"success": true,
		"path": source_label,
		"pack_id": pack_id,
		"validation": validation
	}

func normalize_pack(pack: Dictionary, source_path: String = "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var pack_id: String = str(pack.get("id", "")).strip_edges()
	if pack_id == "":
		pack_id = _stable_id_from_path(source_path)
		warnings.append("Missing pack id. Applied stable id '%s'." % pack_id)

	var pack_name: String = str(pack.get("name", pack_id)).strip_edges()
	if pack_name == "":
		pack_name = pack_id

	var realms: Array = _safe_dictionary_array(pack.get("realms", pack.get("realm_contracts", [])))
	var layers_raw: Variant = pack.get("simulation_layers", pack.get("layers", {}))
	var layers: Dictionary = layers_raw if typeof(layers_raw) == TYPE_DICTIONARY else {}

	var systems: Array = _safe_dictionary_array(pack.get("systems", []))
	var ui_surfaces: Array = _safe_dictionary_array(pack.get("ui_surfaces", pack.get("surfaces", [])))
	var era_contracts: Array = _safe_dictionary_array(pack.get("eras", pack.get("era_contracts", [])))
	var job_contracts: Array = _safe_dictionary_array(pack.get("jobs", pack.get("job_contracts", [])))
	var npc_profiles: Array = _safe_dictionary_array(pack.get("npc_generation_profiles", pack.get("population_profiles", [])))
	var scenario_contracts: Array = _safe_dictionary_array(pack.get("scenarios", pack.get("scenario_contracts", [])))
	var faction_contracts: Array = _safe_dictionary_array(pack.get("faction_contracts", pack.get("factions", [])))
	if realms.is_empty() and layers.is_empty() and systems.is_empty() and ui_surfaces.is_empty() and era_contracts.is_empty() and job_contracts.is_empty() and npc_profiles.is_empty() and scenario_contracts.is_empty() and faction_contracts.is_empty():
		errors.append("Pack has no supported contracts.")

	var normalized_realms: Array = []
	for raw_realm in realms:
		var realm: Dictionary = raw_realm.duplicate(true)
		var realm_id: String = str(realm.get("id", "")).strip_edges()
		if realm_id == "":
			realm_id = _stable_id_from_name(str(realm.get("name", "external_realm")))
			realm ["id"] = realm_id
			warnings.append("Realm missing id. Applied '%s'." % realm_id)

		realm ["behavior"] = normalize_behavior_contract(realm.get("behavior", realm), realm_id)
		realm ["simulation_layers"] = normalize_simulation_layers(realm.get("simulation_layers", {}), realm_id)
		realm ["npc_generation_profile_id"] = str(realm.get("npc_generation_profile_id", realm_id)).strip_edges()
		normalized_realms.append(realm)

	var normalized_layers: Dictionary = {}
	for raw_key in layers.keys():
		var layer_key: String = str(raw_key).strip_edges().to_lower()
		if layer_key not in SUPPORTED_SIMULATION_LAYERS:
			warnings.append("Unsupported simulation layer '%s' ignored." % layer_key)
			continue
		var layer_raw: Variant = layers.get(raw_key, {})
		var layer: Dictionary = layer_raw if typeof(layer_raw) == TYPE_DICTIONARY else {}
		normalized_layers [layer_key] = normalize_layer_contract(layer_key, layer, pack_id)

	var normalized_systems: Array = []
	for raw_system in systems:
		var system: Dictionary = raw_system.duplicate(true)
		var system_id: String = str(system.get("system_id", system.get("id", ""))).strip_edges()
		if system_id == "":
			system_id = "%s_system_%d" % [pack_id, normalized_systems.size()]
			system ["system_id"] = system_id
			warnings.append("System missing system_id. Applied '%s'." % system_id)
		system ["owner_pack"] = pack_id
		normalized_systems.append(system)

	var normalized_eras: Array = []
	for raw_era in era_contracts:
		var era: Dictionary = normalize_era_contract(raw_era, pack_id)
		if str(era.get("id", "")).strip_edges() == "":
			warnings.append("Skipped era contract without id.")
			continue
		normalized_eras.append(era)

	var normalized_jobs: Array = []
	for raw_job in job_contracts:
		var job: Dictionary = normalize_job_contract(raw_job, pack_id)
		if str(job.get("id", "")).strip_edges() == "":
			warnings.append("Skipped job contract without id.")
			continue
		normalized_jobs.append(job)

	var normalized_npc_profiles: Array = []
	for raw_profile in npc_profiles:
		var profile: Dictionary = normalize_npc_generation_profile(raw_profile, pack_id)
		if str(profile.get("id", "")).strip_edges() == "":
			warnings.append("Skipped NPC generation profile without id.")
			continue
		normalized_npc_profiles.append(profile)

	var normalized_scenarios: Array = []
	for raw_scenario in scenario_contracts:
		var scenario: Dictionary = normalize_scenario_contract(raw_scenario, pack_id)
		if str(scenario.get("id", "")).strip_edges() == "":
			warnings.append("Skipped scenario contract without id.")
			continue
		normalized_scenarios.append(scenario)
	var normalized_factions: Array = []
	for raw_faction in faction_contracts:
		var faction: Dictionary = normalize_faction_contract(raw_faction, pack_id)
		if str(faction.get("id", "")).strip_edges() == "":
			warnings.append("Skipped faction contract without id.")
			continue
		normalized_factions.append(faction)
	return {
		"schema": str(pack.get("schema", PACK_SCHEMA)).strip_edges(),
		"version": int(pack.get("version", PACK_VERSION)),
		"id": pack_id,
		"name": pack_name,
		"source_path": source_path,
		"systems": normalized_systems,
		"realms": normalized_realms,
		"simulation_layers": normalized_layers,
		"ui_surfaces": ui_surfaces,
		"eras": normalized_eras,
		"jobs": normalized_jobs,
		"npc_generation_profiles": normalized_npc_profiles,
		"scenarios": normalized_scenarios,
		"faction_contracts": normalized_factions,
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

func normalize_behavior_contract(raw_behavior: Variant, owner_id: String = "") -> Dictionary:
	var behavior: Dictionary = raw_behavior if typeof(raw_behavior) == TYPE_DICTIONARY else {}
	var warnings: Array = []

	var time_model: String = str(behavior.get("time_model", "normal")).strip_edges().to_lower()
	var population_model: String = str(behavior.get("population_model", "static")).strip_edges().to_lower()
	var faction_pressure_model: String = str(behavior.get("faction_pressure_model", "stable")).strip_edges().to_lower()
	var death_logic: String = str(behavior.get("death_logic", "normal")).strip_edges().to_lower()

	if time_model not in ALLOWED_TIME_MODELS:
		warnings.append("Invalid time_model '%s'. Fallback: normal." % time_model)
		time_model = "normal"

	if population_model not in ALLOWED_POPULATION_MODELS:
		warnings.append("Invalid population_model '%s'. Fallback: static." % population_model)
		population_model = "static"

	if faction_pressure_model not in ALLOWED_FACTION_PRESSURE_MODELS:
		warnings.append("Invalid faction_pressure_model '%s'. Fallback: stable." % faction_pressure_model)
		faction_pressure_model = "stable"

	if death_logic not in ALLOWED_DEATH_LOGIC:
		warnings.append("Invalid death_logic '%s'. Fallback: normal." % death_logic)
		death_logic = "normal"

	return {
		"owner_id": owner_id,
		"time_model": time_model,
		"population_model": population_model,
		"faction_pressure_model": faction_pressure_model,
		"death_logic": death_logic,
		"belief_key": str(behavior.get("belief_key", "belief")).strip_edges(),
		"growth_rate": clamp(float(behavior.get("growth_rate", 0.025)), -0.5, 0.5),
		"decline_rate": clamp(float(behavior.get("decline_rate", 0.025)), 0.0, 0.5),
		"pressure_rate": clamp(float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0),
		"loop_year_span": max(1, int(behavior.get("loop_year_span", 12))),
		"minimum_population": max(0, int(behavior.get("minimum_population", 0))),
		"maximum_population": max(0, int(behavior.get("maximum_population", 0))),
		"rules": behavior.get("rules", {}).duplicate(true) if typeof(behavior.get("rules", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": warnings
		}
	}

func normalize_simulation_layers(raw_layers: Variant, owner_id: String = "") -> Dictionary:
	var out: Dictionary = {}
	var layers: Dictionary = raw_layers if typeof(raw_layers) == TYPE_DICTIONARY else {}
	for raw_key in layers.keys():
		var layer_key: String = str(raw_key).strip_edges().to_lower()
		if layer_key not in SUPPORTED_SIMULATION_LAYERS:
			continue
		var layer_raw: Variant = layers.get(raw_key, {})
		var layer: Dictionary = layer_raw if typeof(layer_raw) == TYPE_DICTIONARY else {}
		out [layer_key] = normalize_layer_contract(layer_key, layer, owner_id)
	return out

func normalize_layer_contract(layer_key: String, layer: Dictionary, owner_id: String = "") -> Dictionary:
	var enabled: bool = bool(layer.get("enabled", true))
	return {
		"owner_id": owner_id,
		"layer": layer_key,
		"enabled": enabled,
		"model": str(layer.get("model", "default")).strip_edges().to_lower(),
		"weight": clamp(float(layer.get("weight", 1.0)), 0.0, 10.0),
		"rules": layer.get("rules", {}).duplicate(true) if typeof(layer.get("rules", {})) == TYPE_DICTIONARY else {},
		"events": _safe_dictionary_array(layer.get("events", [])),
		"actions": _safe_dictionary_array(layer.get("actions", [])),
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": []
		}
	}

func run_yearly_simulation_laws(
	context: Dictionary = {}
) -> Dictionary:
	var report:= {
		"schema": "eralife.data_defined_simulation_laws_report",
		"version": PACK_VERSION,
		"year": int(
			context.get(
				"year",
				gs.year
				if gs != null
				else 0
			)
		),
		"realm_updates": [],
		"layer_updates": [],
		"warnings": [],
		"ran_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if gs == null:
		report [
			"warnings"
		].append(
			"No GameState bound."
		)

		return report

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

	var allow_hot_reload: bool = bool(
		context.get(
			"allow_contract_hot_reload",
			not runtime_managed_age_up
		)
	)

	if allow_hot_reload:
		if (
			gs.realm_contract_engine != null
			and gs.realm_contract_engine.has_method(
				"hot_reload_external_packs"
			)
		):
			gs.realm_contract_engine.hot_reload_external_packs(
				false
			)

		hot_reload_external_packs(
			false
		)

	report [
		"hot_reload_performed"
	] = allow_hot_reload

	report [
		"resident_contract_registry_used"
	] = not allow_hot_reload

	report [
		"runtime_managed_age_up"
	] = runtime_managed_age_up

	_run_realm_behavior_models(
		report
	)

	_run_simulation_layers(
		report
	)

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"last_data_defined_simulation_report"
	] = report.duplicate(false)

	return report

func export_registry() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.simulation_contract_registry",
		"version": PACK_VERSION,
		"pack_registry": pack_registry.duplicate(true),
		"layer_registry": layer_registry.duplicate(true),
		"system_registry": system_registry.duplicate(true),
		"era_contract_registry": era_contract_registry.duplicate(true),
		"job_contract_registry": job_contract_registry.duplicate(true),
		"npc_generation_registry": npc_generation_registry.duplicate(true),
		"scenario_contract_registry": scenario_contract_registry.duplicate(true),
		"faction_contract_registry": faction_contract_registry.duplicate(true),
		"validation_reports": validation_reports.duplicate(true),
		"pack_file_mtimes": pack_file_mtimes.duplicate(true),
		"last_hot_reload_report": last_hot_reload_report.duplicate(true)
	})

func import_registry(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var packs_raw: Variant = data.get("pack_registry", {})
	if typeof(packs_raw) == TYPE_DICTIONARY:
		pack_registry = (packs_raw as Dictionary).duplicate(true)

	var layers_raw: Variant = data.get("layer_registry", {})
	if typeof(layers_raw) == TYPE_DICTIONARY:
		layer_registry = (layers_raw as Dictionary).duplicate(true)

	var reports_raw: Variant = data.get("validation_reports", {})
	if typeof(reports_raw) == TYPE_DICTIONARY:
		validation_reports = (reports_raw as Dictionary).duplicate(true)

	var mtimes_raw: Variant = data.get("pack_file_mtimes", {})
	if typeof(mtimes_raw) == TYPE_DICTIONARY:
		pack_file_mtimes = (mtimes_raw as Dictionary).duplicate(true)

	var reload_raw: Variant = data.get("last_hot_reload_report", {})
	if typeof(reload_raw) == TYPE_DICTIONARY:
		last_hot_reload_report = (reload_raw as Dictionary).duplicate(true)
	var systems_raw: Variant = data.get("system_registry", {})
	if typeof(systems_raw) == TYPE_DICTIONARY:
		system_registry = (systems_raw as Dictionary).duplicate(true)

	var eras_raw: Variant = data.get("era_contract_registry", {})
	if typeof(eras_raw) == TYPE_DICTIONARY:
		era_contract_registry = (eras_raw as Dictionary).duplicate(true)

	var jobs_raw: Variant = data.get("job_contract_registry", {})
	if typeof(jobs_raw) == TYPE_DICTIONARY:
		job_contract_registry = (jobs_raw as Dictionary).duplicate(true)

	var npc_raw: Variant = data.get("npc_generation_registry", {})
	if typeof(npc_raw) == TYPE_DICTIONARY:
		npc_generation_registry = (npc_raw as Dictionary).duplicate(true)

	var scenarios_raw: Variant = data.get("scenario_contract_registry", {})
	if typeof(scenarios_raw) == TYPE_DICTIONARY:
		scenario_contract_registry = (scenarios_raw as Dictionary).duplicate(true)
	var factions_raw: Variant = data.get("faction_contract_registry", {})
	if typeof(factions_raw) == TYPE_DICTIONARY:
		faction_contract_registry = (factions_raw as Dictionary).duplicate(true)
	for pack_id in pack_registry.keys():
		var pack_raw: Variant = pack_registry.get(pack_id, {})
		if typeof(pack_raw) == TYPE_DICTIONARY:
			_ingest_pack(pack_raw as Dictionary)

func get_debug_report() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.contract_debug_report",
		"version": PACK_VERSION,
		"pack_count": pack_registry.size(),
		"layer_count": layer_registry.size(),
		"packs": pack_registry.keys(),
		"layers": layer_registry.keys(),
		"validation_reports": validation_reports.duplicate(true),
		"last_hot_reload_report": last_hot_reload_report.duplicate(true),
		"last_data_defined_simulation_report": gs.scenario_state.get("last_data_defined_simulation_report", {}) if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	})

func _ingest_pack(pack: Dictionary) -> void:
	var pack_id: String = str(pack.get("id", "pack")).strip_edges()
	var realms: Array = pack.get("realms", [])

	if gs != null and gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("ingest_external_realm_pack"):
		gs.realm_contract_engine.ingest_external_realm_pack(pack)

	if gs != null and gs.ui_contract_engine != null and gs.ui_contract_engine.has_method("ingest_pack"):
		gs.ui_contract_engine.ingest_pack(pack)
	if gs != null and gs.universal_faction_engine != null and gs.universal_faction_engine.has_method("ingest_faction_contract_pack"):
		gs.universal_faction_engine.ingest_faction_contract_pack(pack)
	for raw_system in pack.get("systems", []):
		if typeof(raw_system) != TYPE_DICTIONARY:
			continue
		var system: Dictionary = raw_system
		var system_id: String = str(system.get("system_id", system.get("id", ""))).strip_edges()
		if system_id == "":
			continue
		system_registry [system_id] = system.duplicate(true)

	var layers: Dictionary = pack.get("simulation_layers", {})
	for layer_key in layers.keys():
		var layer: Dictionary = layers.get(layer_key, {})
		if typeof(layer) != TYPE_DICTIONARY:
			continue
		var registry_key: String = "%s.%s" % [pack_id, str(layer_key)]
		layer_registry [registry_key] = layer.duplicate(true)

	for raw_realm in realms:
		if typeof(raw_realm) != TYPE_DICTIONARY:
			continue
		var realm: Dictionary = raw_realm
		var realm_id: String = str(realm.get("id", "realm")).strip_edges()
		var realm_layers: Dictionary = realm.get("simulation_layers", {})
		for layer_key in realm_layers.keys():
			var layer: Dictionary = realm_layers.get(layer_key, {})
			if typeof(layer) != TYPE_DICTIONARY:
				continue
			var registry_key: String = "%s.%s" % [realm_id, str(layer_key)]
			layer_registry [registry_key] = layer.duplicate(true)

	for raw_era in pack.get("eras", []):
		if typeof(raw_era) != TYPE_DICTIONARY:
			continue
		var era: Dictionary = raw_era
		var era_id: String = str(era.get("id", era.get("name", ""))).strip_edges()
		if era_id == "":
			continue
		era_contract_registry [era_id] = era.duplicate(true)

	for raw_job in pack.get("jobs", []):
		if typeof(raw_job) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = raw_job
		var job_id: String = str(job.get("id", job.get("name", ""))).strip_edges()
		if job_id == "":
			continue
		job_contract_registry [job_id] = job.duplicate(true)

	for raw_profile in pack.get("npc_generation_profiles", []):
		if typeof(raw_profile) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = raw_profile
		var profile_id: String = str(profile.get("id", "")).strip_edges()
		if profile_id == "":
			continue
		npc_generation_registry [profile_id] = profile.duplicate(true)
	for raw_faction in pack.get("faction_contracts", []):
		if typeof(raw_faction) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = raw_faction
		var faction_id: String = str(faction.get("id", "")).strip_edges()
		if faction_id == "":
			continue
		faction_contract_registry [faction_id] = faction.duplicate(true)
	for raw_scenario in pack.get("scenarios", []):
		if typeof(raw_scenario) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = raw_scenario
		var scenario_id: String = str(scenario.get("id", "")).strip_edges()
		if scenario_id == "":
			continue
		scenario_contract_registry [scenario_id] = scenario.duplicate(true)
func normalize_faction_contract(raw_faction: Dictionary, owner_pack: String = "") -> Dictionary:
	var faction_id: String = str(raw_faction.get("id", raw_faction.get("faction_id", ""))).strip_edges()
	var projection_raw: Variant = raw_faction.get("projection", {})
	var projection: Dictionary = projection_raw if typeof(projection_raw) == TYPE_DICTIONARY else {}
	var resources_raw: Variant = raw_faction.get("resources", raw_faction.get("resource_ledger", {}))
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	var metrics_raw: Variant = raw_faction.get("metrics", {})
	var metrics: Dictionary = metrics_raw if typeof(metrics_raw) == TYPE_DICTIONARY else {}

	return {
		"id": faction_id,
		"faction_id": str(raw_faction.get("faction_id", faction_id)).strip_edges(),
		"name": str(raw_faction.get("name", faction_id)).strip_edges(),
		"owner_pack": owner_pack,
		"domain": str(raw_faction.get("domain", projection.get("domain", "faction_contract_layer"))).strip_edges(),
		"kind": str(raw_faction.get("kind", raw_faction.get("type", "contract_faction"))).strip_edges(),
		"enabled": bool(raw_faction.get("enabled", true)),
		"visibility_rule": raw_faction.get("visibility_rule", "always"),
		"tags": _safe_string_array(raw_faction.get("tags", [])),
		"members": _safe_dictionary_array(raw_faction.get("members", [])),
		"member_rules": _safe_dictionary_array(raw_faction.get("member_rules", raw_faction.get("membership_rules", []))),
		"territories": _safe_dictionary_array(raw_faction.get("territories", [])),
		"territory_rules": _safe_dictionary_array(raw_faction.get("territory_rules", [])),
		"resources": resources.duplicate(true),
		"resource_rules": _safe_dictionary_array(raw_faction.get("resource_rules", [])),
		"metrics": metrics.duplicate(true),
		"pressure_rules": _safe_dictionary_array(raw_faction.get("pressure_rules", [])),
		"relationship_rules": _safe_dictionary_array(raw_faction.get("relationship_rules", [])),
		"scenario_hooks": _safe_dictionary_array(raw_faction.get("scenario_hooks", [])),
		"projection": projection.duplicate(true),
		"metadata": raw_faction.get("metadata", {}).duplicate(true) if typeof(raw_faction.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": faction_id != "",
			"errors": [] if faction_id != "" else ["Faction contract missing id."],
			"warnings": []
		}
	}


func get_faction_contract_registry() -> Dictionary:
	return faction_contract_registry.duplicate(true)


func get_era_contract_registry() -> Dictionary:
	return era_contract_registry.duplicate(true)
func _run_realm_behavior_models(report: Dictionary) -> void:
	if gs == null or gs.realm_contract_engine == null:
		return

	if gs.realm_engine != null:
		for raw_realm_id in gs.realm_engine.realms.keys():
			var realm_raw: Variant = gs.realm_engine.realms.get(raw_realm_id, {})
			if typeof(realm_raw) != TYPE_DICTIONARY:
				continue
			var realm: Dictionary = realm_raw
			var updated: Dictionary = _apply_behavior_to_realm(realm, str(raw_realm_id), report)
			gs.realm_engine.realms [raw_realm_id] = updated

	if gs.many_realms_engine != null:
		var hidden_raw: Variant = gs.many_realms_engine.hidden_realms
		var hidden: Dictionary = hidden_raw if typeof(hidden_raw) == TYPE_DICTIONARY else {}
		for raw_hidden_id in hidden.keys():
			var realm_raw: Variant = hidden.get(raw_hidden_id, {})
			if typeof(realm_raw) != TYPE_DICTIONARY:
				continue
			var realm: Dictionary = realm_raw
			hidden [raw_hidden_id] = _apply_behavior_to_realm(realm, str(raw_hidden_id), report)
		gs.many_realms_engine.hidden_realms = hidden

	if gs.realm_contract_engine.has_method("get_external_surface_entries"):
		var external_entries: Array = gs.realm_contract_engine.get_external_surface_entries()
		for entry in external_entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var realm_raw: Variant = (entry as Dictionary).get("realm", {})
			if typeof(realm_raw) != TYPE_DICTIONARY:
				continue
			var updated_realm: Dictionary = _apply_behavior_to_realm(realm_raw, str((entry as Dictionary).get("entry_id", "")), report)
			entry ["realm"] = updated_realm

func _apply_behavior_to_realm(realm: Dictionary, realm_id: String, report: Dictionary) -> Dictionary:
	var out: Dictionary = realm.duplicate(true)

	var behavior_raw: Variant = out.get("behavior", {})
	if typeof(behavior_raw) != TYPE_DICTIONARY:
		var contract_raw: Variant = out.get("realm_contract", {})
		if typeof(contract_raw) == TYPE_DICTIONARY:
			behavior_raw = (contract_raw as Dictionary).get("behavior", {})
	var behavior: Dictionary = normalize_behavior_contract(behavior_raw, realm_id)

	var population_model: String = str(behavior.get("population_model", "static"))
	var time_model: String = str(behavior.get("time_model", "normal"))
	var faction_pressure_model: String = str(behavior.get("faction_pressure_model", "stable"))

	var population: int = max(0, int(out.get("population", out.get("resident_count", 0))))
	var old_population: int = population

	match population_model:
		"linear_growth":
			population += max(1, int(population * float(behavior.get("growth_rate", 0.025))))
		"linear_decline":
			population -= max(1, int(population * float(behavior.get("decline_rate", 0.025))))
		"exponential_growth":
			population = int(round(float(population) * (1.0 + float(behavior.get("growth_rate", 0.025)))))
		"scarcity_decline":
			var pressure: float = float(out.get("faction_pressure", out.get("instability", 0.0)))
			population = int(round(float(population) * (1.0 - clamp(pressure * 0.035, 0.0, 0.4))))
		"belief_scaled":
			var belief_score: float = _resolve_realm_belief_score(out, behavior)
			population = int(round(float(population) * (0.98 + belief_score * 0.08)))
		"cyclical":
			var cycle: float = sin(float(gs.year if gs != null else 0) / 4.0)
			population = int(round(float(population) * (1.0 + cycle * 0.025)))
		_:
			population = population

	var minimum_population: int = int(behavior.get("minimum_population", 0))
	var maximum_population: int = int(behavior.get("maximum_population", 0))
	if minimum_population > 0:
		population = max(minimum_population, population)
	if maximum_population > 0:
		population = min(maximum_population, population)

	out ["population"] = max(0, population)
	out ["resident_count"] = max(0, int(out.get("resident_count", out ["population"])))

	match time_model:
		"looping":
			var loop_span: int = max(1, int(behavior.get("loop_year_span", 12)))
			out ["realm_time_index"] = int(gs.year if gs != null else 0) % loop_span
			out ["realm_time_model_active"] = "looping"
		"stasis":
			out ["realm_time_model_active"] = "stasis"
			out ["population"] = old_population
		"belief_progression":
			out ["realm_time_model_active"] = "belief_progression"
			out ["belief_progression_score"] = _resolve_realm_belief_score(out, behavior)
		"accelerated":
			out ["realm_time_index"] = int(out.get("realm_time_index", 0)) + 2
			out ["realm_time_model_active"] = "accelerated"
		"fragmented":
			out ["realm_time_index"] = int(out.get("realm_time_index", 0)) + randi_range(0, 3)
			out ["realm_time_model_active"] = "fragmented"
		_:
			out ["realm_time_model_active"] = "normal"

	match faction_pressure_model:
		"territorial_conflict":
			out ["faction_pressure"] = clamp(float(out.get("faction_pressure", 0.0)) + float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0)
		"court_intrigue":
			out ["court_intrigue_pressure"] = clamp(float(out.get("court_intrigue_pressure", 0.0)) + float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0)
		"belief_schism":
			out ["belief_schism_pressure"] = clamp(float(out.get("belief_schism_pressure", 0.0)) + float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0)
		"resource_war":
			out ["resource_pressure"] = clamp(float(out.get("resource_pressure", 0.0)) + float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0)
		"dynastic_tension":
			out ["dynastic_tension"] = clamp(float(out.get("dynastic_tension", 0.0)) + float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0)
		_:
			out ["faction_pressure"] = max(0.0, float(out.get("faction_pressure", 0.0)) * 0.98)

	out ["behavior"] = behavior.duplicate(true)
	out ["last_behavior_tick_year"] = int(gs.year if gs != null else 0)

	report ["realm_updates"].append({
		"realm_id": realm_id,
		"name": str(out.get("name", realm_id)),
		"population_model": population_model,
		"time_model": time_model,
		"faction_pressure_model": faction_pressure_model,
		"old_population": old_population,
		"new_population": int(out.get("population", old_population))
	})

	return out

func _run_simulation_layers(report: Dictionary) -> void:
	for registry_key in layer_registry.keys():
		var layer_raw: Variant = layer_registry.get(registry_key, {})
		if typeof(layer_raw) != TYPE_DICTIONARY:
			continue

		var layer: Dictionary = layer_raw
		if not bool(layer.get("enabled", true)):
			continue

		report ["layer_updates"].append({
			"layer_key": str(registry_key),
			"layer": str(layer.get("layer", "")),
			"model": str(layer.get("model", "default")),
			"weight": float(layer.get("weight", 1.0)),
			"status": "registered"
		})

func _resolve_realm_belief_score(realm: Dictionary, behavior: Dictionary) -> float:
	var belief_key: String = str(behavior.get("belief_key", "belief")).strip_edges()
	var direct_score: float = float(realm.get(belief_key, realm.get("belief_score", realm.get("imagination_pressure", 0.5))))
	return clamp(direct_score, 0.0, 1.0)

func _load_packs_from_folder(folder_path: String) -> Dictionary:
	var report:= {
		"loaded": [],
		"failed": []
	}

	for file_path in _json_files_in_folder(folder_path):
		var load_report: Dictionary = load_pack_file(file_path, false)
		if bool(load_report.get("success", false)):
			report ["loaded"].append(load_report)
		else:
			report ["failed"].append(load_report)

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

func _pack_failure(path: String, reason: String) -> Dictionary:
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
		return "external_pack"
	return clean
func normalize_era_contract(raw_era: Dictionary, owner_pack: String = "") -> Dictionary:
	var era_id: String = str(raw_era.get("id", raw_era.get("name", ""))).strip_edges()
	return {
		"id": era_id,
		"name": str(raw_era.get("name", era_id)).strip_edges(),
		"owner_pack": owner_pack,
		"year_min": int(raw_era.get("year_min", raw_era.get("start_year", -999999999))),
		"year_max": int(raw_era.get("year_max", raw_era.get("end_year", 999999999))),
		"birth_locations": _safe_string_array(raw_era.get("birth_locations", [])),
		"conception_stories": _safe_string_array(raw_era.get("conception_stories", [])),
		"age_bounds": raw_era.get("age_bounds", {}).duplicate(true) if typeof(raw_era.get("age_bounds", {})) == TYPE_DICTIONARY else {},
		"job_pool": _safe_string_array(raw_era.get("job_pool", raw_era.get("jobs", []))),
		"part_time_job_pool": _safe_string_array(raw_era.get("part_time_job_pool", raw_era.get("part_time_jobs", []))),
		"famous_career_tracks": _safe_string_array(raw_era.get("famous_career_tracks", [])),
		"rules": raw_era.get("rules", {}).duplicate(true) if typeof(raw_era.get("rules", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": era_id != "",
			"errors": [] if era_id != "" else ["Era contract missing id."],
			"warnings": []
		}
	}

func normalize_job_contract(raw_job: Dictionary, owner_pack: String = "") -> Dictionary:
	var job_id: String = str(raw_job.get("id", raw_job.get("name", ""))).strip_edges()
	return {
		"id": job_id,
		"name": str(raw_job.get("name", job_id)).strip_edges(),
		"owner_pack": owner_pack,
		"category": str(raw_job.get("category", "full_time")).strip_edges().to_lower(),
		"allowed_eras": _safe_string_array(raw_job.get("allowed_eras", [])),
		"min_age": int(raw_job.get("min_age", 18)),
		"max_age": int(raw_job.get("max_age", 999)),
		"salary_min": int(raw_job.get("salary_min", 0)),
		"salary_max": int(raw_job.get("salary_max", 0)),
		"requirements": raw_job.get("requirements", {}).duplicate(true) if typeof(raw_job.get("requirements", {})) == TYPE_DICTIONARY else {},
		"progression": raw_job.get("progression", {}).duplicate(true) if typeof(raw_job.get("progression", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": job_id != "",
			"errors": [] if job_id != "" else ["Job contract missing id."],
			"warnings": []
		}
	}

func normalize_npc_generation_profile(raw_profile: Dictionary, owner_pack: String = "") -> Dictionary:
	var profile_id: String = str(raw_profile.get("id", "")).strip_edges()
	return {
		"id": profile_id,
		"owner_pack": owner_pack,
		"realm_id": str(raw_profile.get("realm_id", profile_id)).strip_edges(),
		"name_profile": raw_profile.get("name_profile", {}).duplicate(true) if typeof(raw_profile.get("name_profile", {})) == TYPE_DICTIONARY else {},
		"age_bounds": raw_profile.get("age_bounds", {}).duplicate(true) if typeof(raw_profile.get("age_bounds", {})) == TYPE_DICTIONARY else {},
		"trait_weights": raw_profile.get("trait_weights", {}).duplicate(true) if typeof(raw_profile.get("trait_weights", {})) == TYPE_DICTIONARY else {},
		"job_weights": raw_profile.get("job_weights", {}).duplicate(true) if typeof(raw_profile.get("job_weights", {})) == TYPE_DICTIONARY else {},
		"social_class_weights": raw_profile.get("social_class_weights", {}).duplicate(true) if typeof(raw_profile.get("social_class_weights", {})) == TYPE_DICTIONARY else {},
		"bending_profile": raw_profile.get("bending_profile", {}).duplicate(true) if typeof(raw_profile.get("bending_profile", {})) == TYPE_DICTIONARY else {},
		"appearance_profile": raw_profile.get("appearance_profile", {}).duplicate(true) if typeof(raw_profile.get("appearance_profile", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": profile_id != "",
			"errors": [] if profile_id != "" else ["NPC generation profile missing id."],
			"warnings": []
		}
	}

func normalize_scenario_contract(raw_scenario: Dictionary, owner_pack: String = "") -> Dictionary:
	var scenario_id: String = str(raw_scenario.get("id", "")).strip_edges()
	return {
		"id": scenario_id,
		"owner_pack": owner_pack,
		"source": str(raw_scenario.get("source", owner_pack)).strip_edges(),
		"category": str(raw_scenario.get("category", "general")).strip_edges(),
		"cooldown_key": str(raw_scenario.get("cooldown_key", scenario_id)).strip_edges(),
		"panel_title": str(raw_scenario.get("panel_title", raw_scenario.get("title", "Scenario"))).strip_edges(),
		"prompt": str(raw_scenario.get("prompt", "")).strip_edges(),
		"footer_text": str(raw_scenario.get("footer_text", "Choose what to do.")).strip_edges(),
		"visibility_rule": raw_scenario.get("visibility_rule", "always"),
		"choices": _safe_dictionary_array(raw_scenario.get("choices", [])),
		"effects": _safe_dictionary_array(raw_scenario.get("effects", [])),
		"validation": {
			"valid": scenario_id != "",
			"errors": [] if scenario_id != "" else ["Scenario contract missing id."],
			"warnings": []
		}
	}

func get_era_contract_for_year(target_year: int) -> Dictionary:
	var best: Dictionary = {}
	for era_id in era_contract_registry.keys():
		var era: Dictionary = era_contract_registry.get(era_id, {})
		if target_year < int(era.get("year_min", -999999999)):
			continue
		if target_year > int(era.get("year_max", 999999999)):
			continue
		best = era
		break
	return best

func get_job_contracts_for_era(era_name: String, category: String = "") -> Array:
	var out: Array = []
	var clean_era: String = str(era_name).strip_edges()
	var clean_category: String = str(category).strip_edges().to_lower()

	for job_id in job_contract_registry.keys():
		var job: Dictionary = job_contract_registry.get(job_id, {})
		var allowed: Array = job.get("allowed_eras", [])
		if not allowed.is_empty() and clean_era not in allowed:
			continue
		if clean_category != "" and str(job.get("category", "")).strip_edges().to_lower() != clean_category:
			continue
		out.append(str(job.get("name", job_id)))

	return out

func get_npc_generation_profile_for_realm(realm_id: Variant) -> Dictionary:
	var key: String = str(realm_id).strip_edges()
	if key == "":
		return {}
	if npc_generation_registry.has(key):
		return npc_generation_registry [key].duplicate(true)
	if gs != null and gs.realm_engine != null:
		var realm_raw: Variant = gs.realm_engine.realms.get(key, {})
		if typeof(realm_raw) != TYPE_DICTIONARY and key.is_valid_int():
			realm_raw = gs.realm_engine.realms.get(int(key), {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw as Dictionary
			var profile_id: String = str(realm.get("npc_generation_profile_id", "")).strip_edges()
			if profile_id != "" and npc_generation_registry.has(profile_id):
				return npc_generation_registry [profile_id].duplicate(true)
	return {}

func get_available_scenario_contracts(context: Dictionary = {}) -> Array:
	var out: Array = []
	for scenario_id in scenario_contract_registry.keys():
		var scenario: Dictionary = scenario_contract_registry.get(scenario_id, {})
		if _passes_contract_visibility(scenario.get("visibility_rule", "always"), context):
			out.append(scenario.duplicate(true))
	return out

func build_scenario_dictionary(scenario_id: String) -> Dictionary:
	var scenario: Dictionary = scenario_contract_registry.get(scenario_id, {})
	if scenario.is_empty():
		return {}

	var out:= {
		"id": str(scenario.get("id", scenario_id)),
		"source": str(scenario.get("source", "simulation_contract_engine")),
		"category": str(scenario.get("category", "general")),
		"cooldown_key": str(scenario.get("cooldown_key", scenario_id)),
		"resolver_method": "_resolve_data_driven_scenario_choice",
		"panel_title": str(scenario.get("panel_title", "Scenario")),
		"footer_text": str(scenario.get("footer_text", "Choose what to do.")),
		"prompt": str(scenario.get("prompt", "")),
		"choices": []
	}

	for raw_choice in scenario.get("choices", []):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = raw_choice.duplicate(true)
		choice ["data_scenario_id"] = scenario_id
		out ["choices"].append(choice)

	return out

func resolve_data_driven_scenario_choice(actor: Person, scenario_id: String, choice: Dictionary) -> Dictionary:
	var scenario: Dictionary = scenario_contract_registry.get(scenario_id, {})
	if scenario.is_empty():
		return {
			"type": "scenario_commit_complete",
			"text": "The scenario contract could not be found.",
			"opps": []
		}

	var text: String = str(choice.get("result_text", choice.get("journal_text", "The moment passed."))).strip_edges()
	_apply_effect_packets(actor, choice.get("effects", []))
	return {
		"type": "scenario_commit_complete",
		"text": text,
		"popup_title": str(choice.get("popup_title", scenario.get("panel_title", "Scenario"))),
		"popup_text": str(choice.get("popup_text", text)),
		"popup_footer": str(choice.get("popup_footer", "Tap anywhere to continue.")),
		"opps": []
	}

func _apply_effect_packets(actor: Person, effects: Variant) -> void:
	if actor == null or typeof(effects) != TYPE_ARRAY:
		return
	for raw in effects:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw
		var stat: String = str(effect.get("stat", "")).strip_edges()
		var delta: int = int(effect.get("delta", 0))
		match stat:
			"health":
				actor.health = clamp(int(actor.health) + delta, 0, 100)
			"happiness", "satisfaction":
				actor.satisfaction = clamp(int(actor.satisfaction) + delta, 0, 100)
			"mental_health":
				actor.mental_health = clamp(int(actor.mental_health) + delta, 0, 100)
			"smarts":
				actor.smarts = clamp(int(actor.smarts) + delta, 0, 100)
			"looks":
				actor.looks = clamp(int(actor.looks) + delta, 0, 100)

func _passes_contract_visibility(rule: Variant, _context: Dictionary = {}) -> bool:
	if typeof(rule) == TYPE_BOOL:
		return bool(rule)
	var clean: String = str(rule).strip_edges().to_lower()
	match clean:
		"", "always", "true":
			return true
		"player_alive":
			return gs != null and gs.player != null and gs.player.alive
		_:
			return true
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
func yearly_tick(payload:= {}) -> void:
	run_yearly_simulation_laws(payload if typeof(payload) == TYPE_DICTIONARY else {})