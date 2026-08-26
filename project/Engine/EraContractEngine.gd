

extends RefCounted
class_name EraContractEngine

const ENGINE_SCHEMA:= "eralife.era_contract_engine"
const ENGINE_VERSION:= 1
const ERA_SCHEMA:= "eralife.era_contract"
const ERA_VERSION:= 1
const STATE_KEY:= "era_contract_state"

var gs
var base_era_registry: Dictionary = {}
var effective_era_contract: Dictionary = {}
var last_report: Dictionary = {}
var registry_revision: int = 0


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	refresh_base_registry({
		"source": (
			"era_contract_engine."
			+ "bootstrap_default_contracts"
		)
	})

	return reconcile_effective_reality({
		"source": (
			"era_contract_engine."
			+ "bootstrap_default_contracts"
		)
	})


func refresh_base_registry(
	context: Dictionary = {}
) -> Dictionary:
	base_era_registry.clear()

	if (
		gs != null
		and gs.era_engine != null
		and typeof(
			gs.era_engine.eras
		) == TYPE_DICTIONARY
	):
		for raw_key in gs.era_engine.eras.keys():
			var key: String = str(
				raw_key
			)
			var contract: Dictionary = _dict(
				gs.era_engine.eras.get(
					raw_key,
					{}
				)
			)

			if contract.is_empty():
				continue

			contract ["schema"] = ERA_SCHEMA
			contract ["version"] = ERA_VERSION
			contract ["id"] = str(
				contract.get(
					"id",
					key
				)
			)
			contract ["base_era_key"] = key
			contract ["base_era_contract"] = true
			base_era_registry [key] = contract

	registry_revision += 1

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"base_era_count": (
			base_era_registry.size()
		),
		"source": str(
			context.get(
				"source",
				"refresh_base_registry"
			)
		)
	}


func choose_era(
	player_settings: Dictionary
) -> Dictionary:
	var selected: Dictionary = {}
	var custom_era_key: String = str(
		player_settings.get(
			"era",
			""
		)
	).strip_edges()

	if custom_era_key != "":
		selected = era_contract_by_key(
			custom_era_key
		)

	if selected.is_empty():
		selected = resolve_base_era_from_year(
			int(
				gs.year
				if gs != null
				else 2000
			)
		)

	return apply_active_overlay(
		selected,
		{
			"source": (
				"era_contract_engine.choose_era"
			)
		}
	)


func resolve_base_era_from_year(
	year: int
) -> Dictionary:
	if base_era_registry.is_empty():
		refresh_base_registry()

	var ordered: Array = (
		base_era_registry.keys()
	)
	ordered.sort_custom(
		func (
			left,
			right
		) -> bool:
			return int(
				_dict(
					base_era_registry.get(
						left,
						{}
					)
				).get(
					"start_year",
					-999999999
				)
			) < int(
				_dict(
					base_era_registry.get(
						right,
						{}
					)
				).get(
					"start_year",
					-999999999
				)
			)
	)

	for raw_key in ordered:
		var contract: Dictionary = _dict(
			base_era_registry.get(
				raw_key,
				{}
			)
		)
		var start_year: int = int(
			contract.get(
				"start_year",
				-999999999
			)
		)
		var end_year: int = int(
			contract.get(
				"end_year",
				999999999
			)
		)

		if year >= start_year and year <= end_year:
			return contract

	if not ordered.is_empty():
		return _dict(
			base_era_registry.get(
				ordered.back(),
				{}
			)
		)

	return {}


func current_base_era_contract() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.era) == TYPE_DICTIONARY:
		var current: Dictionary = _dict(
			gs.era
		)

		if not current.is_empty():
			return current

	return resolve_base_era_from_year(
		int(gs.year)
	)


func current_era_contract() -> Dictionary:
	if effective_era_contract.is_empty():
		reconcile_effective_reality({
			"source": (
				"era_contract_engine."
				+ "current_era_contract"
			)
		})

	return effective_era_contract.duplicate(true)


func apply_active_overlay(
	base_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var effective: Dictionary = (
		base_contract.duplicate(true)
	)
	var overlay: Dictionary = {}

	if (
		gs != null
		and gs.era_mod_contract_engine != null
	):
		overlay = (
			gs.era_mod_contract_engine
			.active_era_overlay(
				gs.player,
				context
			)
		)

	if not overlay.is_empty():
		effective = _deep_merge(
			effective,
			overlay
		)
		effective ["base_era_contract"] = (
			base_contract.duplicate(true)
		)
		effective ["base_era_id"] = str(
			base_contract.get(
				"id",
				base_contract.get(
					"name",
					""
				)
			)
		)
		effective ["mod_overlay_active"] = true
		effective ["overlay_provider_key"] = str(
			overlay.get(
				"canonical_provider_key",
				""
			)
		)
	else:
		effective ["mod_overlay_active"] = false

	effective ["schema"] = ERA_SCHEMA
	effective ["version"] = ERA_VERSION
	effective ["effective_reality_contract"] = true

	return effective


func reconcile_effective_reality(
	context: Dictionary = {}
) -> Dictionary:
	if base_era_registry.is_empty():
		refresh_base_registry(context)

	var base_contract: Dictionary = (
		current_base_era_contract()
	)
	effective_era_contract = apply_active_overlay(
		base_contract,
		context
	)
	registry_revision += 1
	_publish_state()

	last_report = {
		"success": (
			not effective_era_contract.is_empty()
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"base_era_id": str(
			base_contract.get(
				"id",
				base_contract.get(
					"name",
					""
				)
			)
		),
		"effective_era_id": str(
			effective_era_contract.get(
				"id",
				effective_era_contract.get(
					"name",
					""
				)
			)
		),
		"mod_overlay_active": bool(
			effective_era_contract.get(
				"mod_overlay_active",
				false
			)
		),
		"registry_revision": registry_revision,
		"source": str(
			context.get(
				"source",
				"reconcile_effective_reality"
			)
		)
	}

	return last_report.duplicate(true)


func era_contract_by_key(
	value: String
) -> Dictionary:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	for raw_key in base_era_registry.keys():
		var key: String = str(
			raw_key
		)
		var contract: Dictionary = _dict(
			base_era_registry.get(
				raw_key,
				{}
			)
		)
		var candidates: Array = [
			key.to_lower(),
			str(
				contract.get(
					"id",
					""
				)
			).to_lower(),
			str(
				contract.get(
					"name",
					""
				)
			).to_lower()
		]

		if clean in candidates:
			return contract

	return {}


func system_policy(
	system_id: String
) -> Dictionary:
	if (
		gs != null
		and gs.era_mod_contract_engine != null
	):
		return (
			gs.era_mod_contract_engine
			.active_system_policy(
				system_id,
				gs.player
			)
		)

	return {
		"system_id": str(
			system_id
		).strip_edges().to_lower(),
		"mode": "base",
		"visible": true,
		"replacement_system_id": ""
	}


func presentation_contract() -> Dictionary:
	if (
		gs != null
		and gs.era_mod_contract_engine != null
	):
		return (
			gs.era_mod_contract_engine
			.active_presentation_contract(
				gs.player
			)
		)

	return {}


func world_taxonomy_contract() -> Dictionary:
	if (
		gs != null
		and gs.era_mod_contract_engine != null
	):
		return (
			gs.era_mod_contract_engine
			.active_world_taxonomy(
				gs.player
			)
		)

	return {}


func birth_narrative_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs != null
		and gs.era_mod_contract_engine != null
	):
		return (
			gs.era_mod_contract_engine
			.active_birth_narrative(
				actor,
				context
			)
		)

	return {}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"base_era_registry": (
			base_era_registry.duplicate(true)
		),
		"effective_era_contract": (
			effective_era_contract.duplicate(true)
		),
		"registry_revision": registry_revision,
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	base_era_registry = _dict(
		data.get(
			"base_era_registry",
			{}
		)
	)
	effective_era_contract = _dict(
		data.get(
			"effective_era_contract",
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

	return reconcile_effective_reality({
		"source": (
			"era_contract_engine.import_state"
		)
	})


func _publish_state() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"effective_era_contract": (
			effective_era_contract.duplicate(true)
		),
		"registry_revision": registry_revision,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _deep_merge(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for raw_key in overlay.keys():
		var key: String = str(
			raw_key
		)
		var overlay_value: Variant = (
			overlay.get(raw_key)
		)

		if (
			typeof(overlay_value) == TYPE_DICTIONARY
			and typeof(
				out.get(
					key,
					{}
				)
			) == TYPE_DICTIONARY
		):
			out [key] = _deep_merge(
				_dict(
					out.get(
						key,
						{}
					)
				),
				_dict(overlay_value)
			)
		else:
			out [key] = overlay_value

	return out


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}