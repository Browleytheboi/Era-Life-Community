

extends Resource
class_name RoyaltyModContractEngine

const ENGINE_SCHEMA:= "eralife.royalty_mod_contract_engine"
const ENGINE_VERSION:= 1

const ROYALTY_PROVIDER_TYPES:= [
	"royal_court",
	"succession",
	"ceremony",
	"dynasty",
	"heraldry",
	"nobility",
	"royal_title",
	"coronation",
	"royal_marriage",
	"royal_inheritance"
]

const PROVIDER_API_VERSIONS:= {
	"royal_court": 1,
	"succession": 1,
	"ceremony": 1,
	"dynasty": 1,
	"heraldry": 1,
	"nobility": 1,
	"royal_title": 1,
	"coronation": 1,
	"royal_marriage": 1,
	"royal_inheritance": 1
}

const MAX_ROWS_PER_PROVIDER_TYPE:= 1024

var gs
var provider_cache: Dictionary = {}
var provider_validation_registry: Dictionary = {}
var registry_revision: int = 0
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return rebuild_provider_cache({
		"source": (
			"royalty_mod_contract_engine."
			+ "bootstrap_default_contracts"
		)
	})


func register_royalty_provider(
	mod_id: String,
	provider: Dictionary
) -> Dictionary:
	var validation: Dictionary = (
		validate_royalty_provider(provider)
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
			"validation": validation
		}

	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"register_provider_contract"
		)
	):
		return _fail(
			"missing_mod_contract_engine",
			"ModContractEngine is unavailable."
		)

	var report: Dictionary = _dict(
		gs.mod_contract_engine.register_provider_contract(
			mod_id,
			provider
		)
	)

	if bool(
		report.get(
			"success",
			false
		)
	):
		gs.mod_contract_engine.rebuild_provider_resolution()
		rebuild_provider_cache({
			"source": "register_royalty_provider"
		})

	return report


func validate_royalty_provider(
	provider: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var provider_type: String = str(
		provider.get(
			"provider_type",
			provider.get(
				"type",
				""
			)
		)
	).strip_edges().to_lower()
	var provider_id: String = str(
		provider.get(
			"provider_id",
			provider.get(
				"id",
				""
			)
		)
	).strip_edges()

	if provider_id == "":
		errors.append(
			"A royalty provider requires provider_id."
		)

	if provider_type not in ROYALTY_PROVIDER_TYPES:
		errors.append(
			"Unsupported royalty provider type '%s'." % (
				provider_type
			)
		)

	var requested_api: int = max(
		1,
		int(
			provider.get(
				"api_version",
				1
			)
		)
	)
	var supported_api: int = int(
		PROVIDER_API_VERSIONS.get(
			provider_type,
			0
		)
	)

	if requested_api > supported_api:
		errors.append(
			"Provider '%s' requires API v%d; runtime supports v%d." % [
				provider_id,
				requested_api,
				supported_api
			]
		)

	var rows: Array = _array(
		provider.get(
			"rows",
			[]
		)
	)

	if rows.size() > MAX_ROWS_PER_PROVIDER_TYPE:
		errors.append(
			"Provider '%s' exceeds the royalty row budget." % (
				provider_id
			)
		)

	if provider_type == "succession":
		for raw_row in rows:
			var row: Dictionary = _dict(raw_row)

			if row.is_empty():
				continue

			if str(
				row.get(
					"succession_mode",
					row.get(
						"mode",
						""
					)
				)
			).strip_edges() == "":
				warnings.append(
					"A succession provider row has no mode."
				)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"provider_type": provider_type,
		"provider_id": provider_id
	}


func rebuild_provider_cache(
	context: Dictionary = {}
) -> Dictionary:
	provider_cache.clear()
	provider_validation_registry.clear()

	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows"
		)
	):
		registry_revision += 1

		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"provider_count": 0,
		}

	var total_rows: int = 0
	var actor: Person = (
		gs.player
		if gs.player != null
		else null
	)

	for provider_type in ROYALTY_PROVIDER_TYPES:
		var rows: Array = _array(
			gs.mod_contract_engine.emit_provider_rows(
				provider_type,
				actor,
				{
					"source": str(
						context.get(
							"source",
							"rebuild_provider_cache"
						)
					)
				}
			)
		)
		var validated_rows: Array = []

		for raw_row in rows:
			var row: Dictionary = _dict(raw_row)

			if row.is_empty():
				continue

			var row_id: String = str(
				row.get(
					"namespaced_action_id",
					row.get(
						"id",
						""
					)
				)
			)

			if row_id == "":
				continue

			row ["royalty_provider_type"] = provider_type
			row ["ui_is_renderer_only"] = true
			validated_rows.append(row)
			provider_validation_registry [row_id] = {
				"valid": true,
				"provider_type": provider_type,
				"validated_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			if (
				validated_rows.size()
				>= MAX_ROWS_PER_PROVIDER_TYPE
			):
				break

		provider_cache [provider_type] = validated_rows
		total_rows += validated_rows.size()

	registry_revision += 1

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_count": total_rows,
		"provider_type_count": provider_cache.size(),
		"registry_revision": registry_revision,
		"source": str(
			context.get(
				"source",
				"rebuild_provider_cache"
			)
		)
	}

	return last_report.duplicate(true)
func compile_provider_cache_snapshot(
		provider_resolution_snapshot: Dictionary,
		actor: Person = null,
		context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows_from_resolution_snapshot"
		)
	):
		return _fail(
			"missing_mod_contract_engine",
			(
				"ModContractEngine cannot compile the prepared "
				+ "royalty provider cache."
			)
		)

	var compiled_cache: Dictionary = {}
	var compiled_validation: Dictionary = {}
	var total_rows: int = 0

	for provider_type in ROYALTY_PROVIDER_TYPES:
		var source_rows: Array = (
			gs.mod_contract_engine
			.emit_provider_rows_from_resolution_snapshot(
				provider_resolution_snapshot,
				str(provider_type),
				actor,
				{
					"source": str(
						context.get(
							"source",
							"royalty_mod_prepared_cache_compile"
						)
					)
				}
			)
		)
		var validated_rows: Array = []

		for raw_row in source_rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			).duplicate(false)
			var row_id: String = str(
				row.get(
					"namespaced_action_id",
					row.get(
						"id",
						""
					)
				)
			).strip_edges()

			if row_id == "":
				continue

			row ["royalty_provider_type"] = str(
				provider_type
			)
			row ["ui_is_renderer_only"] = true
			validated_rows.append(row)
			compiled_validation [row_id] = {
				"valid": true,
				"provider_type": str(
					provider_type
				),
				"prepared_snapshot": true
			}

			if (
				validated_rows.size()
				>= MAX_ROWS_PER_PROVIDER_TYPE
			):
				break

		compiled_cache [str(provider_type)] = (
			validated_rows
		)
		total_rows += validated_rows.size()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA + ".prepared_provider_cache",
		"version": ENGINE_VERSION,
		"provider_cache": compiled_cache,
		"provider_validation_registry": (
			compiled_validation
		),
		"provider_count": total_rows,
		"provider_type_count": compiled_cache.size(),
		"ui_is_renderer_only": true
	}


func install_prepared_provider_cache_snapshot(
		snapshot: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
	var cache_raw: Variant = snapshot.get(
		"provider_cache",
		{}
	)
	var validation_raw: Variant = snapshot.get(
		"provider_validation_registry",
		{}
	)

	if (
		typeof(cache_raw) != TYPE_DICTIONARY
		or typeof(validation_raw) != TYPE_DICTIONARY
	):
		return _fail(
			"invalid_prepared_provider_cache",
			"The prepared royalty provider cache is malformed."
		)

	provider_cache = (
		(cache_raw as Dictionary).duplicate(false)
	)
	provider_validation_registry = (
		(validation_raw as Dictionary).duplicate(false)
	)
	registry_revision += 1

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_count": (
			provider_validation_registry.size()
		),
		"provider_type_count": provider_cache.size(),
		"registry_revision": registry_revision,
		"source": str(
			context.get(
				"source",
				"install_prepared_provider_cache_snapshot"
			)
		)
	}

	return last_report.duplicate(true)

func emit_provider_rows(
	provider_type: String,
	_actor: Person,
	context: Dictionary = {}
) -> Array:
	var clean_type: String = str(
		provider_type
	).strip_edges().to_lower()

	if clean_type not in ROYALTY_PROVIDER_TYPES:
		return []

	var rows: Array = _array(
		provider_cache.get(
			clean_type,
			[]
		)
	)
	var target_id: String = str(
		context.get(
			"target_id",
			""
		)
	).strip_edges().to_lower()

	if target_id == "":
		return rows

	var filtered: Array = []

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)
		var row_target: String = str(
			row.get(
				"provider_target_id",
				row.get(
					"target_id",
					""
				)
			)
		).strip_edges().to_lower()

		if (
			row_target == ""
			or row_target == target_id
		):
			filtered.append(row)

	return filtered


func resolve_provider_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"resolve_provider_intent"
		)
	):
		return _fail(
			"missing_mod_contract_engine",
			"ModContractEngine cannot resolve the provider intent."
		)

	var result: Dictionary = _dict(
		gs.mod_contract_engine.resolve_provider_intent(
			actor,
			payload
		)
	)
	result ["royalty_mod_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true

	return result


func repair_state(
	context: Dictionary = {}
) -> Dictionary:
	return rebuild_provider_cache({
		"source": str(
			context.get(
				"source",
				"royalty_mod_contract_engine_repair"
			)
		)
	})


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.royalty_mod_contract_engine_state"
		),
		"version": ENGINE_VERSION,
		"provider_cache": provider_cache.duplicate(true),
		"provider_validation_registry": (
			provider_validation_registry.duplicate(true)
		),
		"registry_revision": registry_revision,
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	provider_cache = _dict(
		data.get(
			"provider_cache",
			{}
		)
	)
	provider_validation_registry = _dict(
		data.get(
			"provider_validation_registry",
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



	return repair_state({
		"source": "royalty_mod_contract_engine_import"
	})


func _dict(
	value
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _array(
	value
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []


func _fail(
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