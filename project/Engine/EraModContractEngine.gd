

extends RefCounted
class_name EraModContractEngine

const ENGINE_SCHEMA:= "eralife.era_mod_contract_engine"
const ENGINE_VERSION:= 1

const ERA_PROVIDER_TYPES:= [
	"era_overlays",
	"roles",
	"governance",
	"economy_modes",
	"fauna",
	"world_taxonomy",
	"birth_narratives",
	"presentation",
	"mod_menus",
	"system_policies"
]

var gs
var provider_cache: Dictionary = {}
var registry_revision: int = 0
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return rebuild_provider_cache({
		"source": (
			"era_mod_contract_engine."
			+ "bootstrap_default_contracts"
		)
	})


func rebuild_provider_cache(
	context: Dictionary = {}
) -> Dictionary:
	provider_cache.clear()

	var actor: Person = (
		gs.player
		if gs != null
		else null
	)
	var total_rows: int = 0

	for provider_type in ERA_PROVIDER_TYPES:
		var rows: Array = []

		if (
			gs != null
			and gs.mod_contract_engine != null
			and gs.mod_contract_engine.has_method(
				"emit_provider_rows"
			)
		):
			rows = _array(
				gs.mod_contract_engine.emit_provider_rows(
					provider_type,
					actor,
					{
						"source": str(
							context.get(
								"source",
								"era_mod_provider_cache"
							)
						)
					}
				)
			)

		provider_cache [provider_type] = rows
		total_rows += rows.size()

	registry_revision += 1

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_type_count": provider_cache.size(),
		"row_count": total_rows,
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
		return _failure(
			"missing_mod_contract_engine",
			(
				"ModContractEngine cannot compile the prepared "
				+ "Era provider cache."
			)
		)

	var compiled_cache: Dictionary = {}
	var total_rows: int = 0

	for provider_type in ERA_PROVIDER_TYPES:
		var rows: Array = (
			gs.mod_contract_engine
			.emit_provider_rows_from_resolution_snapshot(
				provider_resolution_snapshot,
				str(provider_type),
				actor,
				{
					"source": str(
						context.get(
							"source",
							"era_mod_prepared_cache_compile"
						)
					)
				}
			)
		)

		compiled_cache [str(provider_type)] = rows
		total_rows += rows.size()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA + ".prepared_provider_cache",
		"version": ENGINE_VERSION,
		"provider_cache": compiled_cache,
		"provider_type_count": compiled_cache.size(),
		"row_count": total_rows,
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

	if typeof(cache_raw) != TYPE_DICTIONARY:
		return _failure(
			"invalid_prepared_provider_cache",
			"The prepared Era provider cache is malformed."
		)



	provider_cache = (
		(cache_raw as Dictionary).duplicate(false)
	)
	registry_revision += 1

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
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
func active_era_overlay(
	actor: Person = null,
	context: Dictionary = {}
) -> Dictionary:
	return _leading_row(
		"era_overlays",
		actor,
		context
	)


func active_presentation_contract(
	actor: Person = null,
	context: Dictionary = {}
) -> Dictionary:
	return _leading_row(
		"presentation",
		actor,
		context
	)


func active_world_taxonomy(
	actor: Person = null,
	context: Dictionary = {}
) -> Dictionary:
	return _leading_row(
		"world_taxonomy",
		actor,
		context
	)


func active_system_policy(
	system_id: String,
	actor: Person = null
) -> Dictionary:
	var clean_system_id: String = str(
		system_id
	).strip_edges().to_lower()

	for raw_row in _rows(
		"system_policies",
		actor
	):
		var row: Dictionary = _dict(
			raw_row
		)

		if str(
			row.get(
				"system_id",
				row.get(
					"id",
					""
				)
			)
		).strip_edges().to_lower() == clean_system_id:
			return row

	return {
		"system_id": clean_system_id,
		"mode": "base",
		"visible": true,
		"replacement_system_id": ""
	}


func active_role_contracts(
	actor: Person = null
) -> Array:
	return _rows(
		"roles",
		actor
	)


func active_governance_contract(
	actor: Person = null
) -> Dictionary:
	return _leading_row(
		"governance",
		actor
	)


func active_economy_contract(
	actor: Person = null
) -> Dictionary:
	return _leading_row(
		"economy_modes",
		actor
	)


func active_fauna_contracts(
	actor: Person = null
) -> Array:
	return _rows(
		"fauna",
		actor
	)


func active_birth_narrative(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	for raw_row in _rows(
		"birth_narratives",
		actor
	):
		var row: Dictionary = _dict(
			raw_row
		)
		var minimum_age: int = int(
			row.get(
				"minimum_age",
				0
			)
		)
		var maximum_age: int = int(
			row.get(
				"maximum_age",
				130
			)
		)

		if (
			int(actor.age) < minimum_age
			or int(actor.age) > maximum_age
		):
			continue

		var required_event: String = str(
			row.get(
				"event_id",
				""
			)
		).strip_edges().to_lower()
		var actual_event: String = str(
			context.get(
				"event_id",
				"birth_intro"
			)
		).strip_edges().to_lower()

		if (
			required_event != ""
			and required_event != actual_event
		):
			continue

		return row

	return {}


func bundle_menu_provider(
	bundle_id: String,
	actor: Person = null
) -> Dictionary:
	var clean_bundle_id: String = str(
		bundle_id
	).strip_edges().to_lower()

	for raw_row in _rows(
		"mod_menus",
		actor
	):
		var row: Dictionary = _dict(
			raw_row
		)
		var provider_target: String = str(
			row.get(
				"provider_target_id",
				row.get(
					"bundle_id",
					""
				)
			)
		).strip_edges().to_lower()

		if provider_target == clean_bundle_id:
			return row

	return {}


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
		return _failure(
			"missing_mod_contract_engine",
			(
				"ModContractEngine cannot resolve "
				+ "the era provider intent."
			)
		)

	return _dict(
		gs.mod_contract_engine.resolve_provider_intent(
			actor,
			payload
		)
	)


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"provider_cache": (
			provider_cache.duplicate(true)
		),
		"registry_revision": registry_revision,
		"last_report": last_report.duplicate(true)
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

	return rebuild_provider_cache({
		"source": (
			"era_mod_contract_engine.import_state"
		)
	})


func _leading_row(
	provider_type: String,
	actor: Person = null,
	_context: Dictionary = {}
) -> Dictionary:
	var rows: Array = _rows(
		provider_type,
		actor
	)

	if rows.is_empty():
		return {}

	return _dict(
		rows [0]
	)


func _rows(
	provider_type: String,
	_actor: Person = null
) -> Array:
	return _array(
		provider_cache.get(
			provider_type,
			[]
		)
	)


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