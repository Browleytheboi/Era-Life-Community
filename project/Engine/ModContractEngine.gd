

extends RefCounted
class_name ModContractEngine

const ENGINE_SCHEMA:= "eralife.mod_contract_engine"
const ENGINE_VERSION:= 1
const MOD_SCHEMA:= "eralife.mod_contract"
const MOD_SCHEMA_VERSION:= 3
const PROVIDER_SCHEMA:= "eralife.mod_provider_contract"
const PROVIDER_SCHEMA_VERSION:= 1

const MAX_MOD_CONTRACT_BYTES:= 4 * 1024 * 1024
const MAX_PROVIDER_CONTRACT_BYTES:= 512 * 1024
const MAX_PROVIDERS_PER_MOD:= 128
const MAX_ROWS_PER_PROVIDER:= 512
const MAX_EMITTED_ROWS_PER_TARGET:= 512

const PROVIDER_TYPES:= [
	"activities",
	"careers",
	"world_generators",
	"eras",
	"laws",
	"ui_surfaces",
	"event_contracts",
	"network_surfaces",


	"era_overlays",
	"roles",
	"governance",
	"economy_modes",
	"fauna",
	"world_taxonomy",
	"birth_narratives",
	"presentation",
	"mod_menus",
	"system_policies",


	"royal_court",
	"succession",
	"ceremony",
	"dynasty",
	"heraldry",
	"nobility",
	"royal_title",
	"coronation",
	"royal_marriage",
	"royal_inheritance",


	"minigames",




	"objects",
	"weapons",
	"artifacts",
	"heirlooms",



	"flash_realities",
	"flash_activities",
	"flash_minigames",
	"flash_npcs",
	"flash_items",
	"flash_sounds",
	"flash_achievements",
	"flash_animations"
	]

const PROVIDER_API_VERSIONS:= {
	"activities": 1,
	"careers": 1,
	"world_generators": 1,
	"eras": 1,
	"laws": 1,
	"ui_surfaces": 1,
	"event_contracts": 1,
	"network_surfaces": 1,

	"era_overlays": 1,
	"roles": 1,
	"governance": 1,
	"economy_modes": 1,
	"fauna": 1,
	"world_taxonomy": 1,
	"birth_narratives": 1,
	"presentation": 1,
	"mod_menus": 1,
	"system_policies": 1,

	"royal_court": 1,
	"succession": 1,
	"ceremony": 1,
	"dynasty": 1,
	"heraldry": 1,
	"nobility": 1,
	"royal_title": 1,
	"coronation": 1,
	"royal_marriage": 1,
	"royal_inheritance": 1,
	"minigames": 1,
	"objects": 1,
	"weapons": 1,
	"artifacts": 1,
	"heirlooms": 1,
	"flash_realities": 1,
	"flash_activities": 1,
	"flash_minigames": 1,
	"flash_npcs": 1,
	"flash_items": 1,
	"flash_sounds": 1,
	"flash_achievements": 1,
	"flash_animations": 1
}

const CONFLICT_POLICIES:= [
	"namespace",
	"highest_priority",
	"replace",
	"merge",
	"keep_existing",
	"error"
]

const SAFE_ROUTE_KINDS:= [
	"result_contract",
	"mod_runtime_method",



	"bundle_service_method"
]

var gs
var mod_registry: Dictionary = {}
var mod_lifecycle_registry: Dictionary = {}
var provider_registry: Dictionary = {}
var provider_target_index: Dictionary = {}
var provider_resolution_registry: Dictionary = {}
var provider_conflict_registry: Dictionary = {}
var mod_settings_registry: Dictionary = {}
var enabled_mod_ids: Dictionary = {}
var quarantined_mods: Dictionary = {}
var registration_sequence: int = 0
var registry_revision: int = 0


var provider_topology_revision: int = 0
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mod_schema": MOD_SCHEMA,
		"mod_schema_version": MOD_SCHEMA_VERSION,
		"provider_schema": PROVIDER_SCHEMA,
		"provider_schema_version": PROVIDER_SCHEMA_VERSION,
		"provider_api_versions": (
			PROVIDER_API_VERSIONS.duplicate(true)
		),
		"ui_is_renderer_only": true
	}


func bootstrap_from_loader(
		context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"schema": "eralife.mod_platform_bootstrap_report",
		"version": ENGINE_VERSION,
		"context": context.duplicate(true),
		"registered": [],
		"quarantined": [],
		"failed": [],
		"runtime_apply": {},
		"runtime_reconciliation": {},
		"bundle_residency": {},
		"provider_resolution": {},
		"booted_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if gs == null or gs.mod_loader == null:
		return _failure(
			"missing_mod_loader",
			"The ModLoader ingestion adapter is unavailable."
		)

	var previous_mod_ids: Array = mod_registry.keys()
	var preserved_settings: Dictionary = (
		mod_settings_registry.duplicate(true)
	)




	provider_topology_revision += 1

	mod_registry = {}
	mod_lifecycle_registry = {}
	provider_registry = {}
	provider_target_index = {}
	provider_resolution_registry = {}
	provider_conflict_registry = {}
	enabled_mod_ids = {}
	quarantined_mods = {}
	mod_settings_registry = preserved_settings

	var loader_registry: Dictionary = {}
	if gs.mod_loader.has_method("export_registry"):
		loader_registry = _dict(
			gs.mod_loader.export_registry()
		)

	var contracts: Dictionary = _dict(
		loader_registry.get(
			"mod_contract_registry",
			{}
		)
	)
	var ordered_mod_ids: Array = _dependency_order(
		contracts
	)

	for raw_mod_id in ordered_mod_ids:
		var mod_id: String = str(
			raw_mod_id
		).strip_edges()
		var mod_contract: Dictionary = _dict(
			contracts.get(
				mod_id,
				{}
			)
		)
		var registration_report: Dictionary = (
			register_mod_contract(
				mod_id,
				mod_contract,
				{
					"source": str(
						context.get(
							"source",
							"mod_contract_engine.bootstrap_from_loader"
						)
					),
					"apply_runtime": false,
					"defer_resolution": true
				}
			)
		)

		if bool(
			registration_report.get(
				"success",
				false
			)
		):
			report ["registered"].append(
				registration_report
			)
		elif bool(
			registration_report.get(
				"quarantined",
				false
			)
		):
			report ["quarantined"].append(
				registration_report
			)
		else:
			report ["failed"].append(
				registration_report
			)

	for raw_previous_mod_id in previous_mod_ids:
		var previous_mod_id: String = str(
			raw_previous_mod_id
		)

		if contracts.has(previous_mod_id):
			continue

		report ["runtime_reconciliation"] [
			"removed_missing_%s" % previous_mod_id
		] = _remove_mod_runtime_contracts(
			previous_mod_id,
			{
				"source": (
					"mod_contract_engine.loader_reconciliation"
				),
				"preserve_save_data": true
			}
		)






	if (
		gs.mod_bundle_contract_engine != null
		and gs.mod_bundle_contract_engine.has_method(
			"prepare_resident_bundle_toggles"
		)
	):
		report ["bundle_residency"] = (
			gs.mod_bundle_contract_engine
			.prepare_resident_bundle_toggles(
				{
					"source": str(
						context.get(
							"source",
							"mod_contract_engine.bootstrap_from_loader"
						)
					),
				}
			)
		)



	report ["provider_resolution"] = (
		rebuild_provider_resolution()
	)

	if bool(
		context.get(
			"apply_runtime",
			true
		)
	):
		report ["runtime_apply"] = _apply_enabled_mod_runtime({
			"source": str(
				context.get(
					"source",
					"mod_contract_engine.bootstrap_from_loader"
				)
			),
			"batch": true
		})

	report ["success"] = (
		_array(
			report.get(
				"failed",
				[]
			)
		).is_empty()
		and bool(
			_dict(
				report.get(
					"bundle_residency",
					{
						"success": true
					}
				)
			).get(
				"success",
				true
			)
		)
	)

	_publish_registry_snapshot()
	last_report = report.duplicate(true)
	return report


func register_mod_contract(
	mod_id: String,
	contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = _id(mod_id)
	var normalized: Dictionary = contract.duplicate(true)

	if clean_mod_id == "":
		clean_mod_id = _id(
			str(
				normalized.get(
					"mod_id",
					""
				)
			)
		)

	if clean_mod_id == "":
		return _failure(
			"missing_mod_id",
			"A mod contract requires a stable mod_id."
		)

	normalized ["mod_id"] = clean_mod_id
	normalized ["id"] = clean_mod_id

	var validation: Dictionary = validate_mod_contract(
		normalized
	)
	normalized ["platform_validation"] = (
		validation.duplicate(true)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		var quarantine_report: Dictionary = {
			"success": false,
			"quarantined": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mod_id": clean_mod_id,
			"validation": validation.duplicate(true),
			"quarantined_at_ms": int(
				Time.get_ticks_msec()
			)
		}
		quarantined_mods [clean_mod_id] = (
			quarantine_report.duplicate(true)
		)
		return quarantine_report

	registration_sequence += 1
	normalized ["registration_sequence"] = (
		registration_sequence
	)
	mod_registry [clean_mod_id] = normalized.duplicate(true)
	mod_lifecycle_registry [clean_mod_id] = {
		"mod_id": clean_mod_id,
		"installed": true,
		"enabled": bool(
			normalized.get(
				"enabled",
				true
			)
		),
		"lifecycle_state": (
			"enabled"
			if bool(
				normalized.get(
					"enabled",
					true
				)
			)
			else "disabled"
		),
		"source_path": _source_path(normalized),
		"registered_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if bool(
		normalized.get(
			"enabled",
			true
		)
	):
		enabled_mod_ids [clean_mod_id] = true
	else:
		enabled_mod_ids.erase(clean_mod_id)

	var defaults: Dictionary = _dict(
		normalized.get(
			"default_settings",
			{}
		)
	)
	if not mod_settings_registry.has(clean_mod_id):
		mod_settings_registry [clean_mod_id] = defaults

	_remove_provider_contracts_for_mod(clean_mod_id)
	var provider_reports: Array = []

	for raw_provider in _array(
		normalized.get(
			"providers",
			[]
		)
	):
		if typeof(raw_provider) != TYPE_DICTIONARY:
			continue

		provider_reports.append(
			register_provider_contract(
				clean_mod_id,
				raw_provider as Dictionary
			)
		)

	registry_revision += 1

	if not bool(
		context.get(
			"defer_resolution",
			false
		)
	):
		rebuild_provider_resolution()
		_publish_registry_snapshot()

	var report: Dictionary = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mod_id": clean_mod_id,
		"provider_reports": provider_reports,
		"registry_revision": registry_revision
	}

	if bool(
		context.get(
			"apply_runtime",
			false
		)
	):
		report ["runtime_apply"] = _apply_single_mod_runtime(
			clean_mod_id,
			context
		)

	last_report = report.duplicate(true)
	return report


func validate_mod_contract(
	contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var mod_id: String = _id(
		str(
			contract.get(
				"mod_id",
				""
			)
		)
	)

	if mod_id == "":
		errors.append(
			"Mod contract requires mod_id."
		)

	var contract_bytes: int = _estimated_bytes(contract)
	if contract_bytes > MAX_MOD_CONTRACT_BYTES:
		errors.append(
			"Mod '%s' exceeds the %d-byte contract budget." % [
				mod_id,
				MAX_MOD_CONTRACT_BYTES
			]
		)

	var isolation_report: Dictionary = (
		_validate_isolation(contract)
	)
	errors.append_array(
		_array(
			isolation_report.get(
				"errors",
				[]
			)
		)
	)
	warnings.append_array(
		_array(
			isolation_report.get(
				"warnings",
				[]
			)
		)
	)

	var providers: Array = _array(
		contract.get(
			"providers",
			[]
		)
	)
	if providers.size() > MAX_PROVIDERS_PER_MOD:
		errors.append(
			"Mod '%s' declares %d providers; the maximum is %d." % [
				mod_id,
				providers.size(),
				MAX_PROVIDERS_PER_MOD
			]
		)

	var provider_ids: Dictionary = {}
	for raw_provider in providers:
		if typeof(raw_provider) != TYPE_DICTIONARY:
			errors.append(
				"Every provider entry must be a Dictionary."
			)
			continue

		var provider: Dictionary = raw_provider as Dictionary
		var provider_report: Dictionary = (
			validate_provider_contract(
				mod_id,
				provider
			)
		)
		errors.append_array(
			_array(
				provider_report.get(
					"errors",
					[]
				)
			)
		)
		warnings.append_array(
			_array(
				provider_report.get(
					"warnings",
					[]
				)
			)
		)

		var provider_id: String = _id(
			str(
				provider.get(
					"provider_id",
					provider.get(
						"id",
						""
					)
				)
			)
		)
		if provider_id != "":
			if provider_ids.has(provider_id):
				errors.append(
					"Mod '%s' declares provider_id '%s' more than once." % [
						mod_id,
						provider_id
					]
				)
			provider_ids [provider_id] = true

	for raw_required in _array(
		contract.get(
			"required_mods",
			[]
		)
	):
		var required_id: String = _id(
			str(raw_required)
		)
		if required_id == "":
			continue
		if required_id == mod_id:
			errors.append(
				"A mod cannot require itself."
			)

	for raw_incompatible in _array(
		contract.get(
			"incompatible_mods",
			[]
		)
	):
		var incompatible_id: String = _id(
			str(raw_incompatible)
		)
		if incompatible_id == mod_id:
			errors.append(
				"A mod cannot declare itself incompatible with itself."
			)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"estimated_bytes": contract_bytes,
		"provider_count": providers.size(),
		"isolation": isolation_report
	}


func validate_provider_contract(
	mod_id: String,
	provider_contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var provider_id: String = _id(
		str(
			provider_contract.get(
				"provider_id",
				provider_contract.get(
					"id",
					""
				)
			)
		)
	)
	var provider_type: String = str(
		provider_contract.get(
			"provider_type",
			provider_contract.get(
				"type",
				""
			)
		)
	).strip_edges().to_lower()
	var target_id: String = _id(
		str(
			provider_contract.get(
				"target_id",
				provider_contract.get(
					"target",
					"default"
				)
			)
		)
	)
	var policy: String = str(
		provider_contract.get(
			"conflict_policy",
			"namespace"
		)
	).strip_edges().to_lower()

	if provider_id == "":
		errors.append(
			"Mod '%s' has a provider without provider_id." % mod_id
		)
	if provider_type not in PROVIDER_TYPES:
		errors.append(
			"Provider '%s' uses unsupported provider_type '%s'." % [
				provider_id,
				provider_type
			]
		)
	if target_id == "":
		errors.append(
			"Provider '%s' requires target_id." % provider_id
		)
	if policy not in CONFLICT_POLICIES:
		errors.append(
			"Provider '%s' uses unsupported conflict_policy '%s'." % [
				provider_id,
				policy
			]
		)

	var supported_api_version: int = int(
		PROVIDER_API_VERSIONS.get(
			provider_type,
			0
		)
	)
	var requested_api_version: int = max(
		1,
		int(
			provider_contract.get(
				"api_version",
				1
			)
		)
	)
	if requested_api_version > supported_api_version:
		errors.append(
			"Provider '%s' requires %s API v%d, but EraLife supports v%d." % [
				provider_id,
				provider_type,
				requested_api_version,
				supported_api_version
			]
		)

	var rows: Array = _array(
		provider_contract.get(
			"rows",
			[]
		)
	)
	if rows.size() > MAX_ROWS_PER_PROVIDER:
		errors.append(
			"Provider '%s' declares %d rows; the maximum is %d." % [
				provider_id,
				rows.size(),
				MAX_ROWS_PER_PROVIDER
			]
		)

	var provider_bytes: int = _estimated_bytes(
		provider_contract
	)
	if provider_bytes > MAX_PROVIDER_CONTRACT_BYTES:
		errors.append(
			"Provider '%s' exceeds the %d-byte provider budget." % [
				provider_id,
				MAX_PROVIDER_CONTRACT_BYTES
			]
		)

	var intent_routes: Dictionary = _dict(
		provider_contract.get(
			"intent_routes",
			{}
		)
	)
	for raw_route_key in intent_routes.keys():
		var route: Dictionary = _dict(
			intent_routes.get(
				raw_route_key,
				{}
			)
		)
		var route_kind: String = str(
			route.get(
				"route_kind",
				"result_contract"
			)
		).strip_edges().to_lower()

		if route_kind not in SAFE_ROUTE_KINDS:
			errors.append(
				"Provider '%s' declares unsafe route_kind '%s'." % [
					provider_id,
					route_kind
				]
			)

		if route_kind == "mod_runtime_method":
			var engine_id: String = _id(
				str(
					route.get(
						"engine_id",
						""
					)
				)
			)
			var method_name: String = str(
				route.get(
					"method",
					""
				)
			).strip_edges()

			if not _id_is_mod_namespaced(
				engine_id,
				mod_id
			):
				errors.append(
					"Provider '%s' runtime route must target an engine namespaced to mod '%s'." % [
						provider_id,
						mod_id
					]
				)
			if (
				method_name == ""
				or method_name.begins_with("_")
			):
				errors.append(
					"Provider '%s' runtime route requires a public method." % provider_id
				)
		if route_kind == "bundle_service_method":
			var bundle_id: String = _id(
				str(
					route.get(
						"bundle_id",
						""
					)
				)
			)
			var service_id: String = _id(
				str(
					route.get(
						"service_id",
						""
					)
				)
			)
			var method_name: String = str(
				route.get(
					"method",
					""
				)
			).strip_edges()

			if bundle_id == "":
				errors.append(
					"Provider '%s' bundle route requires bundle_id."
					% provider_id
				)

			if service_id == "":
				errors.append(
					"Provider '%s' bundle route requires service_id."
					% provider_id
				)

			if (
				method_name == ""
				or method_name.begins_with("_")
			):
				errors.append(
					"Provider '%s' bundle route requires a public method."
					% provider_id
				)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"estimated_bytes": provider_bytes
	}


func register_provider_contract(
		mod_id: String,
		provider_contract: Dictionary
) -> Dictionary:
	var normalized: Dictionary = (
		_normalize_provider_contract(
			mod_id,
			provider_contract
		)
	)
	var validation: Dictionary = (
		validate_provider_contract(
			mod_id,
			normalized
		)
	)
	var provider_key: String = str(
		normalized.get(
			"canonical_provider_key",
			""
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		return {
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mod_id": mod_id,
			"provider_key": provider_key,
			"validation": validation
		}

	registration_sequence += 1
	normalized ["registration_sequence"] = (
		registration_sequence
	)
	normalized ["validation"] = validation
	provider_registry [provider_key] = (
		normalized.duplicate(true)
	)

	var target_key: String = _provider_target_key(
		normalized
	)
	if not provider_target_index.has(target_key):
		provider_target_index [target_key] = []

	var target_keys: Array = _array(
		provider_target_index.get(
			target_key,
			[]
		)
	)
	if provider_key not in target_keys:
		target_keys.append(provider_key)

	provider_target_index [target_key] = target_keys



	provider_topology_revision += 1

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mod_id": mod_id,
		"provider_key": provider_key,
		"target_key": target_key,
		"provider_topology_revision": (
			provider_topology_revision
		)
	}

func rebuild_provider_resolution() -> Dictionary:



	provider_resolution_registry = {}
	provider_conflict_registry = {}

	var target_keys: Array = provider_target_index.keys()
	target_keys.sort()

	for raw_target_key in target_keys:
		var target_key: String = str(
			raw_target_key
		)
		var candidates: Array = []

		for raw_provider_key in _array(
			provider_target_index.get(
				target_key,
				[]
			)
		):
			var provider_key: String = str(
				raw_provider_key
			)
			var provider: Dictionary = _dict(
				provider_registry.get(
					provider_key,
					{}
				)
			)

			if provider.is_empty():
				continue

			if not bool(
				provider.get(
					"enabled",
					true
				)
			):
				continue

			if not enabled_mod_ids.has(
				str(
					provider.get(
						"mod_id",
						""
					)
				)
			):
				continue

			candidates.append(provider)

		candidates.sort_custom(
			_provider_precedes
		)

		provider_resolution_registry [target_key] = (
			_resolve_provider_target(
				target_key,
				candidates
			)
		)

	registry_revision += 1
	_publish_registry_snapshot()

	return {
		"success": true,
		"schema": "eralife.mod_provider_resolution_report",
		"version": PROVIDER_SCHEMA_VERSION,
		"target_count": provider_resolution_registry.size(),
		"conflict_count": provider_conflict_registry.size(),
		"provider_topology_revision": (
			provider_topology_revision
		),
		"registry_revision": registry_revision
	}
func emit_provider_rows_from_resolution_snapshot(
		resolution_snapshot: Dictionary,
		provider_type: String,
		actor: Person,
		context: Dictionary = {}
) -> Array:
	var clean_type: String = str(
		provider_type
	).strip_edges().to_lower()
	var target_filter: String = _id(
		str(
			context.get(
				"target_id",
				""
			)
		)
	)
	var rows: Array = []
	var target_keys: Array = []

	if target_filter != "":
		var exact_target_key: String = (
			"%s::%s"
			% [
				clean_type,
				target_filter
			]
		)

		if resolution_snapshot.has(
			exact_target_key
		):
			target_keys.append(
				exact_target_key
			)
	else:
		target_keys = resolution_snapshot.keys()
		target_keys.sort()

	for raw_target_key in target_keys:
		var target_key: String = str(
			raw_target_key
		)
		var resolution_raw: Variant = (
			resolution_snapshot.get(
				target_key,
				{}
			)
		)

		if typeof(resolution_raw) != TYPE_DICTIONARY:
			continue

		var resolution: Dictionary = (
			resolution_raw as Dictionary
		)

		if str(
			resolution.get(
				"provider_type",
				""
			)
		) != clean_type:
			continue

		if (
			target_filter != ""
			and str(
				resolution.get(
					"target_id",
					""
				)
			) != target_filter
		):
			continue

		if bool(
			resolution.get(
				"blocked",
				false
			)
		):
			continue

		var active_providers_raw: Variant = (
			resolution.get(
				"active_providers",
				[]
			)
		)

		if typeof(active_providers_raw) != TYPE_ARRAY:
			continue

		for raw_provider in active_providers_raw as Array:
			if typeof(raw_provider) != TYPE_DICTIONARY:
				continue

			var provider: Dictionary = (
				raw_provider as Dictionary
			)
			var provider_rows_raw: Variant = (
				provider.get(
					"rows",
					[]
				)
			)

			if typeof(provider_rows_raw) != TYPE_ARRAY:
				continue

			for raw_row in provider_rows_raw as Array:
				if typeof(raw_row) != TYPE_DICTIONARY:
					continue



				var row: Dictionary = (
					raw_row as Dictionary
				).duplicate(false)

				row ["mod_id"] = str(
					provider.get(
						"mod_id",
						""
					)
				)
				row ["provider_id"] = str(
					provider.get(
						"provider_id",
						""
					)
				)
				row ["provider_type"] = clean_type
				row ["provider_target_id"] = str(
					provider.get(
						"target_id",
						""
					)
				)
				row ["canonical_provider_key"] = str(
					provider.get(
						"canonical_provider_key",
						""
					)
				)
				row ["source_kind"] = "mod_provider"
				row ["actor_id"] = (
					int(actor.id)
					if actor != null
					else -1
				)
				row ["ui_is_renderer_only"] = true

				rows.append(row)

				if (
					rows.size()
					>= MAX_EMITTED_ROWS_PER_TARGET
				):
					return rows

	return rows


func resolve_mod_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()
	var mod_id: String = _id(
		str(
			payload.get(
				"mod_id",
				""
			)
		)
	)
	var report: Dictionary

	match action_id:
		"refresh", "open_hub", "observe_partial":
			report = {
				"success": true,
				"type": "mod_registry_refreshed"
			}
		"enable_mod":
			report = set_mod_enabled(
				mod_id,
				true,
				payload
			)
		"disable_mod":
			report = set_mod_enabled(
				mod_id,
				false,
				payload
			)
		"uninstall_mod":
			report = uninstall_mod(
				mod_id,
				payload
			)
		"reload_mods":
			report = reload_mod_sources(payload)
		"set_mod_setting":
			report = set_mod_setting(
				mod_id,
				str(
					payload.get(
						"setting_id",
						""
					)
				),
				payload.get("value"),
				payload
			)
		"provider_intent":
			report = resolve_provider_intent(
				actor,
				payload
			)
		_:
			report = _failure(
				"unknown_mod_intent",
				"The mod platform does not recognize that intent."
			)

	last_report = report.duplicate(true)
	return report


func set_mod_enabled(
	mod_id: String,
	enabled: bool,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = _id(mod_id)

	if not mod_registry.has(clean_mod_id):
		return _failure(
			"unknown_mod",
			"Mod '%s' is not installed." % clean_mod_id
		)

	var desired_enabled_set: Dictionary = (
		enabled_mod_ids.duplicate(true)
	)

	if enabled:
		desired_enabled_set [clean_mod_id] = true
	else:
		desired_enabled_set.erase(clean_mod_id)

	var prepared_snapshot: Dictionary = _dict(
		context.get(
			"prepared_snapshot",
			{}
		)
	)

	if prepared_snapshot.is_empty():
		prepared_snapshot = compile_enabled_set_snapshot(
			desired_enabled_set,
			{
				"source": str(
					context.get(
						"source",
						"set_mod_enabled"
					)
				),
				"mod_id": clean_mod_id
			}
		)

	var transaction_context: Dictionary = (
		context.duplicate(true)
	)
	transaction_context ["prepared_snapshot"] = (
		prepared_snapshot
	)
	transaction_context ["single_mod_id"] = clean_mod_id

	var report: Dictionary = (
		apply_enabled_set_transaction(
			desired_enabled_set,
			transaction_context
		)
	)

	if not bool(
		report.get(
			"success",
			false
		)
	):
		return report

	report ["type"] = (
		"mod_enabled"
		if enabled
		else "mod_disabled"
	)
	report ["mod_id"] = clean_mod_id
	report ["enabled"] = enabled
	report ["text"] = (
		"%s was enabled." % _mod_name(clean_mod_id)
		if enabled
		else "%s was disabled." % _mod_name(clean_mod_id)
	)

	return report
func compile_enabled_set_snapshot(
	desired_enabled_mod_ids: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var normalized_enabled_set: Dictionary = {}
	var unknown_mod_ids: Array = []

	for raw_mod_id in desired_enabled_mod_ids.keys():
		var mod_id: String = _id(
			str(raw_mod_id)
		)

		if mod_id == "":
			continue

		if not mod_registry.has(mod_id):
			unknown_mod_ids.append(mod_id)
			continue

		normalized_enabled_set [mod_id] = true

	if not unknown_mod_ids.is_empty():
		return {
			"success": false,
			"schema": "eralife.mod_enabled_set_snapshot",
			"version": 1,
			"reason": "unknown_mods_in_enabled_set",
			"unknown_mod_ids": unknown_mod_ids,
			"enabled_mod_ids": normalized_enabled_set
		}

	var snapshot_resolution: Dictionary = {}
	var snapshot_conflicts: Dictionary = {}
	var previous_conflicts: Dictionary = (
		provider_conflict_registry
	)




	provider_conflict_registry = snapshot_conflicts

	var target_keys: Array = (
		provider_target_index.keys()
	)
	target_keys.sort()

	for raw_target_key in target_keys:
		var target_key: String = str(
			raw_target_key
		)
		var candidates: Array = []

		for raw_provider_key in _array(
			provider_target_index.get(
				target_key,
				[]
			)
		):
			var provider_key: String = str(
				raw_provider_key
			)
			var provider: Dictionary = _dict(
				provider_registry.get(
					provider_key,
					{}
				)
			)

			if provider.is_empty():
				continue

			if not bool(
				provider.get(
					"enabled",
					true
				)
			):
				continue

			if not normalized_enabled_set.has(
				str(
					provider.get(
						"mod_id",
						""
					)
				)
			):
				continue

			candidates.append(provider)

		candidates.sort_custom(
			_provider_precedes
		)

		snapshot_resolution [target_key] = (
			_resolve_provider_target(
				target_key,
				candidates
			)
		)

	snapshot_conflicts = (
		provider_conflict_registry.duplicate(true)
	)
	provider_conflict_registry = previous_conflicts

	return {
		"success": true,
		"schema": "eralife.mod_enabled_set_snapshot",
		"version": 1,
		"enabled_mod_ids": normalized_enabled_set,
		"provider_resolution_registry": (
			snapshot_resolution
		),
		"provider_conflict_registry": (
			snapshot_conflicts
		),
		"target_count": snapshot_resolution.size(),
		"conflict_count": snapshot_conflicts.size(),
		"source_topology_revision": (
			provider_topology_revision
		),
		"source": str(
			context.get(
				"source",
				"compile_enabled_set_snapshot"
			)
		),
		"compiled_at_ms": int(
			Time.get_ticks_msec()
		),
	}
func apply_enabled_set_transaction(
		desired_enabled_mod_ids: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
	var atomic_bundle_transition: bool = bool(
		context.get(
			"atomic_bundle_transition",
			false
		)
	)
	var prepared_raw: Variant = context.get(
		"prepared_snapshot",
		{}
	)
	var prepared_snapshot: Dictionary = (
		prepared_raw as Dictionary
		if typeof(prepared_raw) == TYPE_DICTIONARY
		else {}
	)

	var prepared_snapshot_hot: bool = (
		not prepared_snapshot.is_empty()
		and bool(
			prepared_snapshot.get(
				"success",
				false
			)
		)
		and int(
			prepared_snapshot.get(
				"source_topology_revision",
				-1
			)
		) == provider_topology_revision
	)

	if not prepared_snapshot_hot:
		if atomic_bundle_transition:
			return _failure(
				"prepared_bundle_snapshot_required",
				(
					"Atomic reality transitions require an already-resident "
					+ "enabled-set snapshot. Compilation on the transition "
					+ "path is forbidden."
				)
			)

		prepared_snapshot = (
			compile_enabled_set_snapshot(
				desired_enabled_mod_ids,
				context
			)
		)

	if not bool(
		prepared_snapshot.get(
			"success",
			false
		)
	):
		return prepared_snapshot

	var normalized_enabled_raw: Variant = (
		prepared_snapshot.get(
			"enabled_mod_ids",
			{}
		)
	)
	if typeof(normalized_enabled_raw) != TYPE_DICTIONARY:
		return _failure(
			"invalid_prepared_enabled_set",
			"The prepared enabled-set snapshot is malformed."
		)

	var normalized_enabled_set: Dictionary = (
		normalized_enabled_raw as Dictionary
	)
	var single_mod_id: String = _id(
		str(
			context.get(
				"single_mod_id",
				""
			)
		)
	)

	var candidate_mod_ids: Array = []

	if atomic_bundle_transition:
		if single_mod_id == "":
			return _failure(
				"atomic_bundle_requires_single_mod_id",
				(
					"Atomic reality-bundle transitions must identify "
					+ "their resident root mod."
				)
			)

		if not mod_registry.has(single_mod_id):
			return _failure(
				"atomic_bundle_root_not_resident",
				(
					"The reality bundle root mod is not resident "
					+ "in provider topology."
				)
			)

		var requested_enabled: bool = (
			desired_enabled_mod_ids.has(
				single_mod_id
			)
		)
		var prepared_enabled: bool = (
			normalized_enabled_set.has(
				single_mod_id
			)
		)

		if requested_enabled != prepared_enabled:
			return _failure(
				"prepared_bundle_snapshot_state_mismatch",
				(
					"The prepared bundle snapshot does not match "
					+ "the requested enabled state."
				)
			)

		candidate_mod_ids.append(
			single_mod_id
		)
	else:
		candidate_mod_ids = mod_registry.keys()
		candidate_mod_ids.sort()

	var changed_mod_ids: Array = []
	var changed_enabled_state: Dictionary = {}

	for raw_mod_id in candidate_mod_ids:
		var mod_id: String = str(
			raw_mod_id
		)
		var was_enabled: bool = (
			enabled_mod_ids.has(mod_id)
		)
		var should_enable: bool = (
			normalized_enabled_set.has(mod_id)
		)

		if was_enabled == should_enable:
			continue

		if atomic_bundle_transition:
			var mod_contract_raw: Variant = (
				mod_registry.get(
					mod_id,
					{}
				)
			)
			var mod_contract: Dictionary = (
				mod_contract_raw as Dictionary
				if typeof(mod_contract_raw) == TYPE_DICTIONARY
				else {}
			)

			if _mod_contract_requires_runtime_application(
				mod_contract
			):
				return _failure(
					"atomic_bundle_generic_runtime_forbidden",
					(
						"Atomic reality bundles may not instantiate or "
						+ "remove generic GameState runtime contracts "
						+ "during the hot transition. Their runtime "
						+ "service must already be resident."
					)
				)

		changed_mod_ids.append(mod_id)
		changed_enabled_state [mod_id] = should_enable



	for raw_mod_id in changed_mod_ids:
		var mod_id: String = str(
			raw_mod_id
		)
		var should_enable: bool = bool(
			changed_enabled_state.get(
				mod_id,
				false
			)
		)
		var lifecycle: Dictionary = _dict(
			mod_lifecycle_registry.get(
				mod_id,
				{}
			)
		)

		lifecycle ["installed"] = true
		lifecycle ["enabled"] = should_enable
		lifecycle ["lifecycle_state"] = (
			"enabled"
			if should_enable
			else "disabled"
		)
		lifecycle ["updated_at_ms"] = int(
			Time.get_ticks_msec()
		)
		lifecycle ["last_atomic_transition"] = (
			atomic_bundle_transition
		)
		mod_lifecycle_registry [mod_id] = lifecycle

	var prepared_resolution_raw: Variant = (
		prepared_snapshot.get(
			"provider_resolution_registry",
			{}
		)
	)
	var prepared_conflicts_raw: Variant = (
		prepared_snapshot.get(
			"provider_conflict_registry",
			{}
		)
	)

	if (
		typeof(prepared_resolution_raw) != TYPE_DICTIONARY
		or typeof(prepared_conflicts_raw) != TYPE_DICTIONARY
	):
		return _failure(
			"invalid_prepared_provider_snapshot",
			"The prepared provider snapshot is malformed."
		)









	provider_resolution_registry = (
		prepared_resolution_raw as Dictionary
	)
	provider_conflict_registry = (
		prepared_conflicts_raw as Dictionary
	)



	enabled_mod_ids = (
		normalized_enabled_set.duplicate(false)
	)

	registry_revision += 1

	var runtime_reports: Dictionary = {}

	if atomic_bundle_transition:
		for raw_mod_id in changed_mod_ids:
			runtime_reports [str(raw_mod_id)] = {
				"success": true,
				"mode": "resident_provider_snapshot_commit",
			}
	else:
		for raw_mod_id in changed_mod_ids:
			var mod_id: String = str(
				raw_mod_id
			)
			var should_enable: bool = bool(
				changed_enabled_state.get(
					mod_id,
					false
				)
			)

			if should_enable:
				runtime_reports [mod_id] = (
					_apply_single_mod_runtime(
						mod_id,
						context
					)
				)
			else:
				runtime_reports [mod_id] = (
					_set_mod_runtime_enabled(
						mod_id,
						false,
						context
					)
				)

	_publish_enabled_set_commit_snapshot(
		changed_mod_ids,
		{
			"single_mod_id": single_mod_id,
			"atomic_bundle_transition": (
				atomic_bundle_transition
			)
		}
	)

	last_report = {
		"success": true,
		"schema": (
			"eralife.mod_enabled_set_transaction_report"
		),
		"version": 1,
		"changed_mod_ids": changed_mod_ids,
		"enabled_mod_ids": enabled_mod_ids.keys(),
		"runtime_reports": runtime_reports,
		"target_count": (
			provider_resolution_registry.size()
		),
		"conflict_count": (
			provider_conflict_registry.size()
		),
		"provider_topology_revision": (
			provider_topology_revision
		),
		"registry_revision": registry_revision,
		"atomic_bundle_transition": (
			atomic_bundle_transition
		),
		"generic_runtime_apply_performed": (
			not atomic_bundle_transition
		),
		"loading_screen_required": false,
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return last_report.duplicate(true)
func uninstall_mod(
	mod_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = _id(mod_id)

	if not mod_registry.has(clean_mod_id):
		return _failure(
			"unknown_mod",
			"Mod '%s' is not installed." % clean_mod_id
		)

	var runtime_report: Dictionary = (
		_remove_mod_runtime_contracts(
			clean_mod_id,
			context
		)
	)

	_remove_provider_contracts_for_mod(clean_mod_id)
	mod_registry.erase(clean_mod_id)
	mod_lifecycle_registry.erase(clean_mod_id)
	mod_settings_registry.erase(clean_mod_id)
	enabled_mod_ids.erase(clean_mod_id)
	quarantined_mods.erase(clean_mod_id)

	if (
		gs != null
		and gs.mod_loader != null
		and gs.mod_loader.has_method(
			"remove_mod_contract"
		)
	):
		gs.mod_loader.remove_mod_contract(clean_mod_id)

	rebuild_provider_resolution()
	_publish_registry_snapshot()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "mod_uninstalled",
		"mod_id": clean_mod_id,
		"runtime_report": runtime_report,
		"preserved_save_data": bool(
			context.get(
				"preserve_save_data",
				true
			)
		),
		"text": "Mod '%s' was uninstalled." % clean_mod_id
	}


func reload_mod_sources(
	context: Dictionary = {}
) -> Dictionary:
	if gs == null or gs.mod_loader == null:
		return _failure(
			"missing_mod_loader",
			"The ModLoader ingestion adapter is unavailable."
		)

	var loader_report: Dictionary = {}
	if gs.mod_loader.has_method("reload_mod_sources"):
		loader_report = _dict(
			gs.mod_loader.reload_mod_sources({
				"force": bool(
					context.get(
						"force",
						false
					)
				),
				"hot_apply": false,
				"source": str(
					context.get(
						"source",
						"mod_contract_engine.reload"
					)
				)
			})
		)
	else:
		loader_report = _dict(
			gs.mod_loader.hot_reload_mods(
				bool(
					context.get(
						"force",
						false
					)
				)
			)
		)

	var bootstrap_report: Dictionary = (
		bootstrap_from_loader({
			"source": str(
				context.get(
					"source",
					"mod_contract_engine.reload"
				)
			),
			"apply_runtime": true
		})
	)

	return {
		"success": bool(
			bootstrap_report.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "mods_reloaded",
		"loader_report": loader_report,
		"bootstrap_report": bootstrap_report,
		"text": (
			"Mod sources were rescanned and reconciled."
		)
	}


func set_mod_setting(
	mod_id: String,
	setting_id: String,
	value: Variant,
	_context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = _id(mod_id)
	var clean_setting_id: String = _id(setting_id)

	if not mod_registry.has(clean_mod_id):
		return _failure(
			"unknown_mod",
			"That mod is not installed."
		)
	if clean_setting_id == "":
		return _failure(
			"missing_setting_id",
			"A setting_id is required."
		)

	var schema: Dictionary = _dict(
		_dict(
			mod_registry.get(
				clean_mod_id,
				{}
			)
		).get(
			"settings_schema",
			{}
		)
	)
	if not schema.has(clean_setting_id):
		return _failure(
			"unknown_setting",
			"Mod '%s' does not expose setting '%s'." % [
				clean_mod_id,
				clean_setting_id
			]
		)

	var setting_contract: Dictionary = _dict(
		schema.get(
			clean_setting_id,
			{}
		)
	)
	var value_report: Dictionary = _validate_setting_value(
		setting_contract,
		value
	)
	if not bool(
		value_report.get(
			"valid",
			false
		)
	):
		return _failure(
			"invalid_setting_value",
			str(
				value_report.get(
					"reason",
					"That setting value is invalid."
				)
			)
		)

	var settings: Dictionary = _dict(
		mod_settings_registry.get(
			clean_mod_id,
			{}
		)
	)
	settings [clean_setting_id] = value
	mod_settings_registry [clean_mod_id] = settings

	_publish_registry_snapshot()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "mod_setting_updated",
		"mod_id": clean_mod_id,
		"setting_id": clean_setting_id,
		"value": value,
		"text": "%s setting updated." % _mod_name(
			clean_mod_id
		)
	}


func emit_provider_rows(
		provider_type: String,
		actor: Person,
		context: Dictionary = {}
) -> Array:
	return emit_provider_rows_from_resolution_snapshot(
		provider_resolution_registry,
		provider_type,
		actor,
		context
	)

func resolve_provider_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var provider_key: String = str(
		payload.get(
			"canonical_provider_key",
			payload.get(
				"provider_key",
				""
			)
		)
	).strip_edges()
	var action_id: String = _id(
		str(
			payload.get(
				"provider_action_id",
				payload.get(
					"action_id",
					""
				)
			)
		)
	)

	if provider_key == "":
		provider_key = _provider_key_from_action_id(
			str(
				payload.get(
					"namespaced_action_id",
					""
				)
			)
		)

	if not provider_registry.has(provider_key):
		return _failure(
			"unknown_provider",
			"The requested mod provider is not registered."
		)

	var provider: Dictionary = _dict(
		provider_registry.get(
			provider_key,
			{}
		)
	)
	var target_key: String = (
		_provider_target_key(provider)
	)
	var resolution: Dictionary = _dict(
		provider_resolution_registry.get(
			target_key,
			{}
		)
	)

	if bool(
		resolution.get(
			"blocked",
			false
		)
	):
		return _failure(
			"provider_conflict_blocked",
			(
				"That mod provider is blocked by "
				+ "an unresolved conflict."
			)
		)

	if not _resolution_contains_provider(
		resolution,
		provider_key
	):
		return _failure(
			"provider_shadowed",
			(
				"That mod provider is installed but is "
				+ "not the active provider for its target."
			)
		)

	var routes: Dictionary = _dict(
		provider.get(
			"intent_routes",
			{}
		)
	)
	var route: Dictionary = _dict(
		routes.get(
			action_id,
			{}
		)
	)

	if route.is_empty():
		return _failure(
			"unknown_provider_action",
			"The provider does not expose that action."
		)

	var route_kind: String = str(
		route.get(
			"route_kind",
			"result_contract"
		)
	).strip_edges().to_lower()

	match route_kind:
		"result_contract":
			var result: Dictionary = _dict(
				route.get(
					"result",
					{}
				)
			)
			result ["success"] = bool(
				result.get(
					"success",
					true
				)
			)
			result ["type"] = str(
				result.get(
					"type",
					"mod_provider_result"
				)
			)
			result ["mod_id"] = str(
				provider.get(
					"mod_id",
					""
				)
			)
			result ["provider_id"] = str(
				provider.get(
					"provider_id",
					""
				)
			)
			result ["canonical_provider_key"] = (
				provider_key
			)
			result ["ui_is_renderer_only"] = true
			return result

		"mod_runtime_method":
			return _resolve_provider_runtime_route(
				actor,
				provider,
				route,
				payload
			)

		"bundle_service_method":
			if (
				gs == null
				or gs.mod_bundle_contract_engine == null
				or not (
					gs.mod_bundle_contract_engine
					.has_method(
						"resolve_bundle_service_intent"
					)
				)
			):
				return _failure(
					"bundle_service_authority_unavailable",
					(
						"The installable reality bundle "
						+ "authority is unavailable."
					)
				)

			return (
				gs.mod_bundle_contract_engine
				.resolve_bundle_service_intent(
					actor,
					provider,
					route,
					payload
				)
			)

		_:
			return _failure(
				"unsafe_provider_route",
				(
					"The provider route was rejected "
					+ "by isolation law."
				)
			)

func installed_mod_summaries() -> Array:
	var rows: Array = []
	var ids: Array = mod_registry.keys()
	ids.sort()

	for raw_mod_id in ids:
		rows.append(
			_mod_summary(
				str(raw_mod_id)
			)
		)

	return rows


func active_provider_summaries() -> Array:
	var rows: Array = []
	var target_keys: Array = (
		provider_resolution_registry.keys()
	)
	target_keys.sort()

	for raw_target_key in target_keys:
		var resolution: Dictionary = _dict(
			provider_resolution_registry.get(
				raw_target_key,
				{}
			)
		)
		rows.append({
			"target_key": str(raw_target_key),
			"provider_type": str(
				resolution.get(
					"provider_type",
					""
				)
			),
			"target_id": str(
				resolution.get(
					"target_id",
					""
				)
			),
			"resolution_policy": str(
				resolution.get(
					"resolution_policy",
					""
				)
			),
			"blocked": bool(
				resolution.get(
					"blocked",
					false
				)
			),
			"active_count": _array(
				resolution.get(
					"active_providers",
					[]
				)
			).size(),
			"active_provider_keys": _array(
				resolution.get(
					"active_provider_keys",
					[]
				)
			)
		})

	return rows


func export_registry() -> Dictionary:
	return {
		"schema": "eralife.mod_platform_registry",
		"version": ENGINE_VERSION,
		"mod_registry": mod_registry.duplicate(true),
		"mod_lifecycle_registry": (
			mod_lifecycle_registry.duplicate(true)
		),
		"provider_registry": provider_registry.duplicate(true),
		"provider_target_index": (
			provider_target_index.duplicate(true)
		),
		"provider_resolution_registry": (
			provider_resolution_registry.duplicate(true)
		),
		"provider_conflict_registry": (
			provider_conflict_registry.duplicate(true)
		),
		"mod_settings_registry": (
			mod_settings_registry.duplicate(true)
		),
		"enabled_mod_ids": enabled_mod_ids.duplicate(true),
		"quarantined_mods": quarantined_mods.duplicate(true),
		"registry_revision": registry_revision,
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func import_registry(
	data: Dictionary = {}
) -> Dictionary:
	mod_registry = _dict(
		data.get(
			"mod_registry",
			{}
		)
	)
	mod_lifecycle_registry = _dict(
		data.get(
			"mod_lifecycle_registry",
			{}
		)
	)
	provider_registry = _dict(
		data.get(
			"provider_registry",
			{}
		)
	)
	provider_target_index = _dict(
		data.get(
			"provider_target_index",
			{}
		)
	)
	provider_resolution_registry = _dict(
		data.get(
			"provider_resolution_registry",
			{}
		)
	)
	provider_conflict_registry = _dict(
		data.get(
			"provider_conflict_registry",
			{}
		)
	)
	mod_settings_registry = _dict(
		data.get(
			"mod_settings_registry",
			{}
		)
	)
	enabled_mod_ids = _dict(
		data.get(
			"enabled_mod_ids",
			{}
		)
	)
	quarantined_mods = _dict(
		data.get(
			"quarantined_mods",
			{}
		)
	)
	registry_revision = int(
		data.get(
			"registry_revision",
			0
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	rebuild_provider_resolution()
	_publish_registry_snapshot()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func export_state() -> Dictionary:
	return export_registry()


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	return import_registry(data)


func _normalize_provider_contract(
	mod_id: String,
	provider_contract: Dictionary
) -> Dictionary:
	var out: Dictionary = provider_contract.duplicate(true)
	var provider_id: String = _id(
		str(
			out.get(
				"provider_id",
				out.get(
					"id",
					"provider"
				)
			)
		)
	)
	var provider_type: String = str(
		out.get(
			"provider_type",
			out.get(
				"type",
				""
			)
		)
	).strip_edges().to_lower()
	var target_id: String = _id(
		str(
			out.get(
				"target_id",
				out.get(
					"target",
					"default"
				)
			)
		)
	)
	var clean_mod_id: String = _id(mod_id)
	var namespace_id: String = _id(
		str(
			out.get(
				"namespace",
				clean_mod_id
			)
		)
	)

	out ["schema"] = PROVIDER_SCHEMA
	out ["version"] = PROVIDER_SCHEMA_VERSION
	out ["mod_id"] = clean_mod_id
	out ["provider_id"] = provider_id
	out ["provider_type"] = provider_type
	out ["target_id"] = target_id
	out ["namespace"] = namespace_id
	out ["api_version"] = max(
		1,
		int(
			out.get(
				"api_version",
				1
			)
		)
	)
	out ["enabled"] = bool(
		out.get(
			"enabled",
			true
		)
	)
	out ["priority"] = int(
		out.get(
			"priority",
			0
		)
	)
	out ["conflict_policy"] = str(
		out.get(
			"conflict_policy",
			"namespace"
		)
	).strip_edges().to_lower()
	out ["allow_override"] = bool(
		out.get(
			"allow_override",
			false
		)
	)
	out ["rows"] = _namespace_provider_rows(
		clean_mod_id,
		provider_id,
		_array(
			out.get(
				"rows",
				[]
			)
		)
	)
	out ["intent_routes"] = _dict(
		out.get(
			"intent_routes",
			{}
		)
	)
	out ["allowed_methods"] = _array(
		out.get(
			"allowed_methods",
			[]
		)
	)
	out ["budget"] = _dict(
		out.get(
			"budget",
			{}
		)
	)
	out ["metadata"] = _dict(
		out.get(
			"metadata",
			{}
		)
	)
	out ["canonical_provider_key"] = "%s::%s" % [
		clean_mod_id,
		provider_id
	]

	return out


func _namespace_provider_rows(
	mod_id: String,
	provider_id: String,
	rows: Array
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for row_index in range(rows.size()):
		var raw_row: Variant = rows [row_index]
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		).duplicate(true)
		var local_action_id: String = _id(
			str(
				row.get(
					"provider_action_id",
					row.get(
						"action_id",
						row.get(
							"id",
							"row_%d" % row_index
						)
					)
				)
			)
		)
		if local_action_id == "":
			local_action_id = "row_%d" % row_index

		if seen.has(local_action_id):
			local_action_id = "%s_%d" % [
				local_action_id,
				row_index
			]
		seen [local_action_id] = true

		row ["provider_action_id"] = local_action_id
		row ["namespaced_action_id"] = "%s::%s::%s" % [
			mod_id,
			provider_id,
			local_action_id
		]
		row ["canonical_provider_key"] = "%s::%s" % [
			mod_id,
			provider_id
		]
		row ["source_kind"] = "mod_provider"
		row ["ui_is_renderer_only"] = true
		out.append(row)

	return out


func _resolve_provider_target(
	target_key: String,
	candidates: Array
) -> Dictionary:
	var provider_type: String = ""
	var target_id: String = ""

	if target_key.contains("::"):
		var parts: PackedStringArray = target_key.split(
			"::",
			false
		)
		if parts.size() >= 2:
			provider_type = parts [0]
			target_id = parts [1]

	if candidates.is_empty():
		return {
			"target_key": target_key,
			"provider_type": provider_type,
			"target_id": target_id,
			"blocked": false,
			"resolution_policy": "empty",
			"active_providers": [],
			"active_provider_keys": []
		}

	if candidates.size() == 1:
		var only_provider: Dictionary = _dict(
			candidates [0]
		)
		return _provider_resolution_contract(
			target_key,
			provider_type,
			target_id,
			"single",
			[
				only_provider
			],
			candidates
		)

	for raw_candidate in candidates:
		var candidate: Dictionary = _dict(
			raw_candidate
		)
		if str(
			candidate.get(
				"conflict_policy",
				"namespace"
			)
		) == "error":
			var blocked: Dictionary = (
				_provider_resolution_contract(
					target_key,
					provider_type,
					target_id,
					"error",
					[],
					candidates
				)
			)
			blocked ["blocked"] = true
			blocked ["reason"] = (
				"A provider declared error-on-conflict."
			)
			provider_conflict_registry [target_key] = (
				blocked.duplicate(true)
			)
			return blocked

	var all_namespace: bool = true
	for raw_candidate in candidates:
		if str(
			_dict(
				raw_candidate
			).get(
				"conflict_policy",
				"namespace"
			)
		) != "namespace":
			all_namespace = false
			break

	if all_namespace:
		return _provider_resolution_contract(
			target_key,
			provider_type,
			target_id,
			"namespace",
			candidates,
			candidates
		)

	var leader: Dictionary = _dict(candidates [0])
	var leader_policy: String = str(
		leader.get(
			"conflict_policy",
			"highest_priority"
		)
	)

	match leader_policy:
		"merge":
			var merged: Dictionary = leader.duplicate(true)
			for candidate_index in range(
				1,
				candidates.size()
			):
				merged = _merge_provider_contracts(
					merged,
					_dict(
						candidates [candidate_index]
					)
				)

			merged ["canonical_provider_key"] = (
				"merged::%s" % target_key
			)
			merged ["provider_id"] = (
				"merged_%s" % target_id
			)

			return _provider_resolution_contract(
				target_key,
				provider_type,
				target_id,
				"merge",
				[
					merged
				],
				candidates
			)

		"keep_existing":
			var earliest: Dictionary = _dict(
				candidates [0]
			)
			for raw_candidate in candidates:
				var candidate: Dictionary = _dict(
					raw_candidate
				)
				if int(
					candidate.get(
						"registration_sequence",
						0
					)
				) < int(
					earliest.get(
						"registration_sequence",
						0
					)
				):
					earliest = candidate

			return _provider_resolution_contract(
				target_key,
				provider_type,
				target_id,
				"keep_existing",
				[
					earliest
				],
				candidates
			)

		"replace":
			if bool(
				leader.get(
					"allow_override",
					false
				)
			):
				return _provider_resolution_contract(
					target_key,
					provider_type,
					target_id,
					"replace",
					[
						leader
					],
					candidates
				)

			var blocked_replace: Dictionary = (
				_provider_resolution_contract(
					target_key,
					provider_type,
					target_id,
					"replace_denied",
					[],
					candidates
				)
			)
			blocked_replace ["blocked"] = true
			blocked_replace ["reason"] = (
				"The leading provider requested replace without allow_override."
			)
			provider_conflict_registry [target_key] = (
				blocked_replace.duplicate(true)
			)
			return blocked_replace

		_:
			return _provider_resolution_contract(
				target_key,
				provider_type,
				target_id,
				"highest_priority",
				[
					leader
				],
				candidates
			)


func _provider_resolution_contract(
	target_key: String,
	provider_type: String,
	target_id: String,
	policy: String,
	active_providers: Array,
	candidates: Array
) -> Dictionary:
	var active_keys: Array = []

	for raw_provider in active_providers:
		active_keys.append(
			str(
				_dict(
					raw_provider
				).get(
					"canonical_provider_key",
					""
				)
			)
		)

	return {
		"schema": "eralife.mod_provider_resolution_contract",
		"version": PROVIDER_SCHEMA_VERSION,
		"target_key": target_key,
		"provider_type": provider_type,
		"target_id": target_id,
		"blocked": false,
		"resolution_policy": policy,
		"active_providers": active_providers.duplicate(true),
		"active_provider_keys": active_keys,
		"candidate_count": candidates.size(),
		"candidate_provider_keys": _provider_keys(candidates),
		"resolved_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _provider_precedes(
	a: Variant,
	b: Variant
) -> bool:
	var left: Dictionary = _dict(a)
	var right: Dictionary = _dict(b)

	var left_priority: int = int(
		left.get(
			"priority",
			0
		)
	)
	var right_priority: int = int(
		right.get(
			"priority",
			0
		)
	)
	if left_priority != right_priority:
		return left_priority > right_priority

	var left_version: Array = _semantic_version_parts(
		_mod_release_version(
			str(
				left.get(
					"mod_id",
					""
				)
			)
		)
	)
	var right_version: Array = _semantic_version_parts(
		_mod_release_version(
			str(
				right.get(
					"mod_id",
					""
				)
			)
		)
	)
	var version_compare: int = (
		_compare_semantic_version_parts(
			left_version,
			right_version
		)
	)
	if version_compare != 0:
		return version_compare > 0

	var left_mod_id: String = str(
		left.get(
			"mod_id",
			""
		)
	)
	var right_mod_id: String = str(
		right.get(
			"mod_id",
			""
		)
	)
	if left_mod_id != right_mod_id:
		return left_mod_id < right_mod_id

	return str(
		left.get(
			"provider_id",
			""
		)
	) < str(
		right.get(
			"provider_id",
			""
		)
	)


func _merge_provider_contracts(
	base: Dictionary,
	incoming: Dictionary
) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)

	for key in incoming.keys():
		var incoming_value: Variant = incoming.get(key)
		var existing_value: Variant = merged.get(key)

		if (
			typeof(existing_value) == TYPE_DICTIONARY
			and typeof(incoming_value) == TYPE_DICTIONARY
		):
			merged [key] = _deep_merge_dictionary_copy(
				existing_value as Dictionary,
				incoming_value as Dictionary
			)
		elif (
			typeof(existing_value) == TYPE_ARRAY
			and typeof(incoming_value) == TYPE_ARRAY
		):
			merged [key] = _merge_arrays_by_identity(
				existing_value as Array,
				incoming_value as Array
			)
		elif not merged.has(key):
			merged [key] = incoming_value

	return merged


func _resolve_provider_runtime_route(
	actor: Person,
	provider: Dictionary,
	route: Dictionary,
	payload: Dictionary
) -> Dictionary:
	var mod_id: String = _id(
		str(
			provider.get(
				"mod_id",
				""
			)
		)
	)
	var engine_id: String = _id(
		str(
			route.get(
				"engine_id",
				""
			)
		)
	)
	var method_name: String = str(
		route.get(
			"method",
			""
		)
	).strip_edges()

	if not _id_is_mod_namespaced(
		engine_id,
		mod_id
	):
		return _failure(
			"cross_mod_engine_route_forbidden",
			"A provider can only route to an engine owned by the same mod."
		)

	if (
		method_name == ""
		or method_name.begins_with("_")
	):
		return _failure(
			"private_provider_method_forbidden",
			"A provider route must target a declared public method."
		)

	if (
		gs == null
		or gs.game_state_contract_engine == null
	):
		return _failure(
			"missing_contract_runtime",
			"The contract runtime is unavailable."
		)

	var engine_contract: Dictionary = _dict(
		gs.game_state_contract_engine.engine_registry.get(
			engine_id,
			{}
		)
	)
	if _id(
		str(
			engine_contract.get(
				"mod_id",
				""
			)
		)
	) != mod_id:
		return _failure(
			"engine_ownership_mismatch",
			"The requested provider engine is not owned by that mod."
		)

	var allowed_methods: Array = _array(
		provider.get(
			"allowed_methods",
			[]
		)
	)
	if method_name not in allowed_methods:
		return _failure(
			"undeclared_provider_method",
			"The provider route did not declare that method."
		)

	var instance = (
		gs.game_state_contract_engine.get_engine_instance(
			engine_id
		)
	)
	if (
		instance == null
		or not instance.has_method(method_name)
	):
		return _failure(
			"provider_runtime_unavailable",
			"The mod provider runtime is unavailable."
		)

	var result: Variant = instance.callv(
		method_name,
		[
			actor,
			payload.duplicate(true)
		]
	)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure(
			"invalid_provider_runtime_result",
			"The provider runtime must return a Dictionary contract."
		)

	var report: Dictionary = (
		result as Dictionary
	).duplicate(true)
	report ["mod_id"] = mod_id
	report ["provider_id"] = str(
		provider.get(
			"provider_id",
			""
		)
	)
	report ["canonical_provider_key"] = str(
		provider.get(
			"canonical_provider_key",
			""
		)
	)
	report ["ui_is_renderer_only"] = true

	return report


func _apply_enabled_mod_runtime(
	context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"applied": [],
		"failed": [],
		"runtime_refresh": {}
	}
	var ordered_ids: Array = _dependency_order(
		mod_registry
	)

	for raw_mod_id in ordered_ids:
		var mod_id: String = str(raw_mod_id)
		if not enabled_mod_ids.has(mod_id):
			continue

		var apply_report: Dictionary = (
			_apply_single_mod_runtime(
				mod_id,
				context
			)
		)
		if bool(
			apply_report.get(
				"success",
				false
			)
		):
			report ["applied"].append(apply_report)
		else:
			report ["failed"].append(apply_report)

	report ["runtime_refresh"] = (
		_refresh_contract_runtime(context)
	)
	report ["success"] = _array(
		report.get(
			"failed",
			[]
		)
	).is_empty()

	return report

func _mod_contract_requires_runtime_application(
		mod_contract: Dictionary
) -> bool:
	if mod_contract.is_empty():
		return false

	var game_state_raw: Variant = mod_contract.get(
		"game_state_contract",
		{}
	)
	if (
		typeof(game_state_raw) == TYPE_DICTIONARY
		and not (game_state_raw as Dictionary).is_empty()
	):
		return true

	var layer_contracts_raw: Variant = mod_contract.get(
		"layer_contracts",
		{}
	)
	if (
		typeof(layer_contracts_raw) == TYPE_DICTIONARY
		and not (layer_contracts_raw as Dictionary).is_empty()
	):
		return true

	var legacy_patch_raw: Variant = mod_contract.get(
		"legacy_data_patch",
		{}
	)
	if (
		typeof(legacy_patch_raw) == TYPE_DICTIONARY
		and not (legacy_patch_raw as Dictionary).is_empty()
	):
		return true

	return false
func _apply_single_mod_runtime(
		mod_id: String,
		context: Dictionary = {}
) -> Dictionary:
	if not mod_registry.has(mod_id):
		return _failure(
			"unknown_mod",
			"That mod is not registered."
		)

	if not enabled_mod_ids.has(mod_id):
		return _failure(
			"mod_disabled",
			"That mod is disabled."
		)

	var mod_contract: Dictionary = _dict(
		mod_registry.get(
			mod_id,
			{}
		)
	)




	if not _mod_contract_requires_runtime_application(
		mod_contract
	):
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mod_id": mod_id,
			"mode": "provider_snapshot_only",
			"ui_is_renderer_only": true
		}

	if gs == null or gs.mod_loader == null:
		return _failure(
			"missing_mod_loader",
			"The ModLoader adapter is unavailable."
		)

	var report: Dictionary = _dict(
		gs.mod_loader.apply_mod_contract(
			mod_contract
		)
	)

	if bool(
		report.get(
			"success",
			false
		)
	):
		_set_mod_runtime_enabled(
			mod_id,
			true,
			context
		)

	return report

func _refresh_contract_runtime(
	context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {}

	if (
		gs == null
		or gs.game_state_contract_engine == null
	):
		return report

	var engine = gs.game_state_contract_engine

	if engine.has_method(
		"instantiate_contract_engine_extensions"
	):
		report ["instantiation"] = (
			engine.instantiate_contract_engine_extensions()
		)

	if engine.has_method(
		"register_existing_engines_from_game_state"
	):
		report ["registered_engines"] = (
			engine.register_existing_engines_from_game_state()
		)

	if engine.has_method("validate_active_contracts"):
		report ["validation"] = (
			engine.validate_active_contracts({
				"phase": str(
					context.get(
						"source",
						"mod_platform_runtime_refresh"
					)
				),
				"include_runtime": true
			})
		)

	if engine.has_method(
		"build_runtime_phase_budget_report"
	):
		report ["phase_budget"] = (
			engine.build_runtime_phase_budget_report({
				"phase": "mod_platform_runtime_refresh"
			})
		)

	if engine.has_method("apply_runtime_guards"):
		report ["runtime_guard"] = (
			engine.apply_runtime_guards({
				"phase": "mod_platform_runtime_refresh"
			})
		)

	if engine.has_method("hydrate_runtime_state"):
		report ["hydration"] = engine.hydrate_runtime_state({
			"phase": "mod_platform_runtime_refresh"
		})

	return report


func _set_mod_runtime_enabled(
	mod_id: String,
	enabled: bool,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.game_state_contract_engine == null
	):
		return {}

	if gs.game_state_contract_engine.has_method(
		"set_mod_runtime_enabled"
	):
		return _dict(
			gs.game_state_contract_engine.set_mod_runtime_enabled(
				mod_id,
				enabled,
				context
			)
		)

	return {}


func _remove_mod_runtime_contracts(
	mod_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.game_state_contract_engine == null
	):
		return {}

	if gs.game_state_contract_engine.has_method(
		"remove_mod_runtime_contracts"
	):
		return _dict(
			gs.game_state_contract_engine.remove_mod_runtime_contracts(
				mod_id,
				context
			)
		)

	return _set_mod_runtime_enabled(
		mod_id,
		false,
		context
	)


func _validate_isolation(
	contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var mod_id: String = _id(
		str(
			contract.get(
				"mod_id",
				""
			)
		)
	)
	var permissions: Dictionary = _dict(
		contract.get(
			"permissions",
			{}
		)
	)
	var execution_mode: String = str(
		permissions.get(
			"execution_mode",
			"data_only"
		)
	).strip_edges().to_lower()
	var source_path: String = _source_path(contract)
	var is_script_bridge: bool = (
		source_path.to_lower().ends_with(".gd")
	)
	var trusted_script_mods_enabled: bool = false

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		trusted_script_mods_enabled = bool(
			gs.scenario_state.get(
				"allow_trusted_script_mods",
				false
			)
		)

	if (
		is_script_bridge
		or execution_mode == "trusted_native_code"
	):
		if not trusted_script_mods_enabled:
			errors.append(
				"Mod '%s' contains native GDScript. Untrusted script mods cannot be sandboxed; enable trusted script mods explicitly to load it." % mod_id
			)
		else:
			warnings.append(
				"Mod '%s' is trusted native code and is outside the data-contract sandbox." % mod_id
			)

	var forbidden_path: String = (
		_find_forbidden_runtime_value(
			contract,
			"root"
		)
	)
	if forbidden_path != "":
		errors.append(
			"Mod '%s' contains a non-data runtime value at %s." % [
				mod_id,
				forbidden_path
			]
		)

	var game_state_contract: Dictionary = _dict(
		contract.get(
			"game_state_contract",
			{}
		)
	)
	for raw_engine in _array(
		game_state_contract.get(
			"engines",
			[]
		)
	):
		if typeof(raw_engine) != TYPE_DICTIONARY:
			continue

		var engine_row: Dictionary = (
			raw_engine as Dictionary
		)
		var engine_id: String = _id(
			str(
				engine_row.get(
					"id",
					""
				)
			)
		)
		var runtime_property: String = _id(
			str(
				engine_row.get(
					"runtime_property",
					engine_id
				)
			)
		)

		if not _id_is_mod_namespaced(
			engine_id,
			mod_id
		):
			errors.append(
				"Mod engine id '%s' must be namespaced to '%s'." % [
					engine_id,
					mod_id
				]
			)

		if not _id_is_mod_namespaced(
			runtime_property,
			mod_id
		):
			errors.append(
				"Mod runtime_property '%s' must be namespaced to '%s'." % [
					runtime_property,
					mod_id
				]
			)

	var layer_contracts: Dictionary = _dict(
		contract.get(
			"layer_contracts",
			{}
		)
	)
	if (
		layer_contracts.has("ui")
		and not bool(
			permissions.get(
				"trusted_ui_contracts",
				false
			)
		)
	):
		errors.append(
			"Mod '%s' declares a direct UI layer. Mods must contribute ui_surfaces providers instead." % mod_id
		)

	return {
		"valid": errors.is_empty(),
		"execution_mode": execution_mode,
		"errors": errors,
		"warnings": warnings
	}


func _find_forbidden_runtime_value(
	value: Variant,
	path: String
) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_BASIS, TYPE_PROJECTION, TYPE_QUATERNION, TYPE_AABB, TYPE_PLANE, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return ""

		TYPE_ARRAY:
			var array_value: Array = value as Array
			for index in range(array_value.size()):
				var nested_path: String = (
					_find_forbidden_runtime_value(
						array_value [index],
						"%s[%d]" % [
							path,
							index
						]
					)
				)
				if nested_path != "":
					return nested_path
			return ""

		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = (
				value as Dictionary
			)
			for key in dictionary_value.keys():
				var nested_path: String = (
					_find_forbidden_runtime_value(
						dictionary_value.get(key),
						"%s.%s" % [
							path,
							str(key)
						]
					)
				)
				if nested_path != "":
					return nested_path
			return ""

		_:
			return path


func _dependency_order(
	registry: Dictionary
) -> Array:
	var ordered: Array = []
	var permanent: Dictionary = {}
	var temporary: Dictionary = {}
	var ids: Array = registry.keys()
	ids.sort()

	for raw_mod_id in ids:
		_visit_dependency(
			str(raw_mod_id),
			registry,
			permanent,
			temporary,
			ordered
		)

	return ordered


func _visit_dependency(
	mod_id: String,
	registry: Dictionary,
	permanent: Dictionary,
	temporary: Dictionary,
	ordered: Array
) -> void:
	if permanent.has(mod_id):
		return
	if temporary.has(mod_id):
		return

	temporary [mod_id] = true

	var mod_contract: Dictionary = _dict(
		registry.get(
			mod_id,
			{}
		)
	)
	var dependencies: Array = _array(
		mod_contract.get(
			"required_mods",
			[]
		)
	)
	dependencies.sort()

	for raw_dependency in dependencies:
		var dependency_id: String = _id(
			str(raw_dependency)
		)
		if registry.has(dependency_id):
			_visit_dependency(
				dependency_id,
				registry,
				permanent,
				temporary,
				ordered
			)

	temporary.erase(mod_id)
	permanent [mod_id] = true
	ordered.append(mod_id)


func _remove_provider_contracts_for_mod(
		mod_id: String
) -> void:
	var remove_keys: Array = []

	for raw_provider_key in provider_registry.keys():
		var provider_key: String = str(
			raw_provider_key
		)
		var provider_raw: Variant = (
			provider_registry.get(
				provider_key,
				{}
			)
		)

		if typeof(provider_raw) != TYPE_DICTIONARY:
			continue

		if _id(
			str(
				(provider_raw as Dictionary).get(
					"mod_id",
					""
				)
			)
		) == mod_id:
			remove_keys.append(provider_key)

	if remove_keys.is_empty():
		return

	for provider_key in remove_keys:
		provider_registry.erase(provider_key)

	var next_target_index: Dictionary = {}

	for raw_provider_key in provider_registry.keys():
		var provider_key: String = str(
			raw_provider_key
		)
		var provider_raw: Variant = (
			provider_registry.get(
				provider_key,
				{}
			)
		)

		if typeof(provider_raw) != TYPE_DICTIONARY:
			continue

		var provider: Dictionary = (
			provider_raw as Dictionary
		)
		var target_key: String = _provider_target_key(
			provider
		)

		if not next_target_index.has(target_key):
			next_target_index [target_key] = []

		var keys: Array = (
			next_target_index [target_key] as Array
		)
		keys.append(provider_key)

	provider_target_index = next_target_index



	provider_topology_revision += 1

func _provider_target_key(
	provider: Dictionary
) -> String:
	return "%s::%s" % [
		str(
			provider.get(
				"provider_type",
				""
			)
		),
		str(
			provider.get(
				"target_id",
				"default"
			)
		)
	]


func _provider_keys(
	providers: Array
) -> Array:
	var out: Array = []

	for raw_provider in providers:
		out.append(
			str(
				_dict(
					raw_provider
				).get(
					"canonical_provider_key",
					""
				)
			)
		)

	return out


func _resolution_contains_provider(
	resolution: Dictionary,
	provider_key: String
) -> bool:
	return provider_key in _array(
		resolution.get(
			"active_provider_keys",
			[]
		)
	)


func _provider_key_from_action_id(
	namespaced_action_id: String
) -> String:
	var parts: PackedStringArray = str(
		namespaced_action_id
	).split(
		"::",
		false
	)
	if parts.size() < 2:
		return ""

	return "%s::%s" % [
		parts [0],
		parts [1]
	]


func _id_is_mod_namespaced(
	value: String,
	mod_id: String
) -> bool:
	var clean_value: String = _id(value)
	var clean_mod_id: String = _id(mod_id)
	var legacy_mod_prefix: String = "mod_%s_" % (
		clean_mod_id
			.replace(".", "_")
			.replace("-", "_")
	)

	return (
		clean_value.begins_with(
			"%s." % clean_mod_id
		)
		or clean_value.begins_with(
			"%s::" % clean_mod_id
		)
		or clean_value.begins_with(
			"mod.%s." % clean_mod_id
		)
		or clean_value.begins_with(
			legacy_mod_prefix
		)
	)


func _mod_summary(
	mod_id: String
) -> Dictionary:
	var mod_contract: Dictionary = _dict(
		mod_registry.get(
			mod_id,
			{}
		)
	)
	var lifecycle: Dictionary = _dict(
		mod_lifecycle_registry.get(
			mod_id,
			{}
		)
	)
	var provider_count: int = 0
	var active_provider_count: int = 0

	for raw_provider in provider_registry.values():
		var provider: Dictionary = _dict(raw_provider)
		if str(
			provider.get(
				"mod_id",
				""
			)
		) != mod_id:
			continue

		provider_count += 1

		var resolution: Dictionary = _dict(
			provider_resolution_registry.get(
				_provider_target_key(provider),
				{}
			)
		)
		if _resolution_contains_provider(
			resolution,
			str(
				provider.get(
					"canonical_provider_key",
					""
				)
			)
		):
			active_provider_count += 1

	return {
		"mod_id": mod_id,
		"name": str(
			mod_contract.get(
				"name",
				mod_id
			)
		),
		"description": str(
			mod_contract.get(
				"description",
				""
			)
		),
		"author": str(
			mod_contract.get(
				"author",
				""
			)
		),
		"release_version": str(
			mod_contract.get(
				"release_version",
				"1.0.0"
			)
		),
		"enabled": enabled_mod_ids.has(mod_id),
		"installed": bool(
			lifecycle.get(
				"installed",
				true
			)
		),
		"lifecycle_state": str(
			lifecycle.get(
				"lifecycle_state",
				"installed"
			)
		),
		"priority": int(
			mod_contract.get(
				"priority",
				0
			)
		),
		"provider_count": provider_count,
		"active_provider_count": active_provider_count,
		"settings_schema": _dict(
			mod_contract.get(
				"settings_schema",
				{}
			)
		),
		"settings": _dict(
			mod_settings_registry.get(
				mod_id,
				{}
			)
		),
		"marketplace": _dict(
			mod_contract.get(
				"marketplace",
				{}
			)
		),
		"validation": _dict(
			mod_contract.get(
				"platform_validation",
				{}
			)
		),
		"source_path": _source_path(mod_contract)
	}


func _mod_name(
	mod_id: String
) -> String:
	return str(
		_dict(
			mod_registry.get(
				mod_id,
				{}
			)
		).get(
			"name",
			mod_id
		)
	)


func _mod_release_version(
	mod_id: String
) -> String:
	return str(
		_dict(
			mod_registry.get(
				mod_id,
				{}
			)
		).get(
			"release_version",
			"1.0.0"
		)
	)


func _semantic_version_parts(
	version_text: String
) -> Array:
	var clean: String = str(
		version_text
	).strip_edges()
	var core: String = (
		clean.split(
			"-",
			false
		) [0]
		if clean.contains("-")
		else clean
	)
	var pieces: PackedStringArray = core.split(
		".",
		false
	)
	var out: Array = [
		0,
		0,
		0
	]

	for index in range(
		min(
			3,
			pieces.size()
		)
	):
		out [index] = int(pieces [index])

	return out


func _compare_semantic_version_parts(
	left: Array,
	right: Array
) -> int:
	for index in range(3):
		var left_value: int = (
			int(left [index])
			if index < left.size()
			else 0
		)
		var right_value: int = (
			int(right [index])
			if index < right.size()
			else 0
		)

		if left_value > right_value:
			return 1
		if left_value < right_value:
			return -1

	return 0


func _merge_arrays_by_identity(
	base: Array,
	incoming: Array
) -> Array:
	var out: Array = base.duplicate(true)
	var index_by_key: Dictionary = {}

	for index in range(out.size()):
		index_by_key [
			_array_item_identity(
				out [index],
				index
			)
		] = index

	for incoming_index in range(incoming.size()):
		var item: Variant = incoming [incoming_index]
		var identity: String = _array_item_identity(
			item,
			incoming_index
		)

		if index_by_key.has(identity):
			var existing_index: int = int(
				index_by_key.get(
					identity,
					-1
				)
			)
			if (
				existing_index >= 0
				and typeof(
					out [existing_index]
				) == TYPE_DICTIONARY
				and typeof(item) == TYPE_DICTIONARY
			):
				out [existing_index] = (
					_deep_merge_dictionary_copy(
						out [existing_index] as Dictionary,
						item as Dictionary
					)
				)
		else:
			index_by_key [identity] = out.size()
			out.append(item)

	return out


func _array_item_identity(
	item: Variant,
	fallback_index: int
) -> String:
	if typeof(item) == TYPE_DICTIONARY:
		var row: Dictionary = item as Dictionary

		for key in [
			"id",
			"action_id",
			"provider_action_id",
			"provider_id",
			"key"
		]:
			var value: String = str(
				row.get(
					key,
					""
				)
			).strip_edges()
			if value != "":
				return "%s:%s" % [
					key,
					value
				]

	return "value:%s:%d" % [
		str(item),
		fallback_index
	]


func _deep_merge_dictionary_copy(
	base: Dictionary,
	incoming: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in incoming.keys():
		var incoming_value: Variant = incoming.get(key)
		var existing_value: Variant = out.get(key)

		if (
			typeof(existing_value) == TYPE_DICTIONARY
			and typeof(incoming_value) == TYPE_DICTIONARY
		):
			out [key] = _deep_merge_dictionary_copy(
				existing_value as Dictionary,
				incoming_value as Dictionary
			)
		elif (
			typeof(existing_value) == TYPE_ARRAY
			and typeof(incoming_value) == TYPE_ARRAY
		):
			out [key] = _merge_arrays_by_identity(
				existing_value as Array,
				incoming_value as Array
			)
		else:
			out [key] = incoming_value

	return out


func _validate_setting_value(
	setting_contract: Dictionary,
	value: Variant
) -> Dictionary:
	var setting_type: String = str(
		setting_contract.get(
			"type",
			"string"
		)
	).strip_edges().to_lower()

	match setting_type:
		"bool", "boolean":
			if typeof(value) != TYPE_BOOL:
				return {
					"valid": false,
					"reason": "Expected a boolean value."
				}

		"int", "integer":
			if typeof(value) != TYPE_INT:
				return {
					"valid": false,
					"reason": "Expected an integer value."
				}

		"float", "number":
			if typeof(value) not in [
				TYPE_INT,
				TYPE_FLOAT
			]:
				return {
					"valid": false,
					"reason": "Expected a numeric value."
				}

		"option":
			if value not in _array(
				setting_contract.get(
					"options",
					[]
				)
			):
				return {
					"valid": false,
					"reason": (
						"Value is not one of the permitted options."
					)
				}

		_:
			if typeof(value) != TYPE_STRING:
				return {
					"valid": false,
					"reason": "Expected a text value."
				}

	return {
		"valid": true
	}

func _publish_enabled_set_commit_snapshot(
		changed_mod_ids: Array,
		context: Dictionary = {}
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"mod_platform_registry_revision"
	] = registry_revision

	gs.scenario_state [
		"mod_platform_last_enabled_set_commit"
	] = {
		"changed_mod_ids": changed_mod_ids.duplicate(),
		"single_mod_id": str(
			context.get(
				"single_mod_id",
				""
			)
		),
		"enabled_mod_count": enabled_mod_ids.size(),
		"provider_target_count": (
			provider_resolution_registry.size()
		),
		"conflict_count": (
			provider_conflict_registry.size()
		),
		"provider_topology_revision": (
			provider_topology_revision
		),
		"registry_revision": registry_revision,
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _publish_registry_snapshot() -> void:
	if gs == null:
		return

	if "mod_contract_registry" in gs:
		gs.mod_contract_registry = export_registry()

	if "mod_provider_registry" in gs:
		gs.mod_provider_registry = (
			provider_resolution_registry.duplicate(true)
		)

	if "mod_conflict_registry" in gs:
		gs.mod_conflict_registry = (
			provider_conflict_registry.duplicate(true)
		)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"mod_platform_registry_revision"
		] = registry_revision
		gs.scenario_state [
			"mod_platform_last_snapshot"
		] = {
			"installed_mod_count": mod_registry.size(),
			"enabled_mod_count": enabled_mod_ids.size(),
			"provider_count": provider_registry.size(),
			"provider_target_count": (
				provider_resolution_registry.size()
			),
			"conflict_count": (
				provider_conflict_registry.size()
			),
			"revision": registry_revision,
			"published_at_ms": int(
				Time.get_ticks_msec()
			)
		}


func _source_path(
	contract: Dictionary
) -> String:
	return str(
		_dict(
			contract.get(
				"metadata",
				{}
			)
		).get(
			"source_path",
			""
		)
	).strip_edges()


func _estimated_bytes(
	value: Variant
) -> int:
	return JSON.stringify(
		value
	).to_utf8_buffer().size()


func _id(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")
	clean = clean.replace("/", ".")
	clean = clean.replace("\\", ".")

	while clean.contains("__"):
		clean = clean.replace("__", "_")

	return clean


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)
	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)
	return []


func _failure(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}