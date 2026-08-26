

extends RefCounted
class_name WeaponsCatalogExpansion

const ENGINE_SCHEMA:= "eralife.weapons_catalog_expansion"
const ENGINE_VERSION:= 1
const OBJECT_SCHEMA:= "eralife.global_object_contract"
const OBJECT_VERSION:= 1

var gs
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state


func bootstrap_default_contracts() -> Dictionary:
	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"provider_id": "eralife.catalog.weapons",
		"domains": [
			"weapon"
		],
		"truth_engine_property": "weapons_engine",
		"mod_provider_types": [
			"weapons",
			"objects"
		],
		"read_only": true,
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func provider_contract() -> Dictionary:
	return {
		"schema": "eralife.object_catalog_provider_contract",
		"version": 1,
		"provider_id": "eralife.catalog.weapons",
		"engine_property": "weapons_catalog_expansion",
		"method": "get_available_objects",
		"domains": [
			"weapon"
		],
		"priority": 220,
		"read_only": true,
		"truth_engine_property": "weapons_engine",
	}


func get_available_objects(
	context: Dictionary = {}
) -> Array:
	var normalized_context: Dictionary = _normalize_context(
		context
	)
	var out: Array = []

	for raw_weapon in _base_weapon_rows(
		normalized_context
	):
		if typeof(
			raw_weapon
		) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = object_contract_for_weapon(
			raw_weapon as Dictionary,
			normalized_context,
			"base_weapon_catalog"
		)

		if not contract.is_empty():
			out.append(contract)

	for raw_mod_weapon in _mod_weapon_rows(
		normalized_context
	):
		if typeof(
			raw_mod_weapon
		) != TYPE_DICTIONARY:
			continue

		var mod_contract: Dictionary = object_contract_for_weapon(
			raw_mod_weapon as Dictionary,
			normalized_context,
			"mod_provider"
		)

		if not mod_contract.is_empty():
			out.append(mod_contract)

	out = _dedupe_by_catalog_id(
		out
	)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "weapon_catalog_projection",
		"era": str(
			normalized_context.get(
				"era",
				""
			)
		),
		"country": str(
			normalized_context.get(
				"country",
				""
			)
		),
		"object_count": out.size(),
		"read_only": true,
		"projected_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return out


func get_object_contract(
	object_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_id: String = str(
		object_id
	).strip_edges().to_lower()

	if clean_id == "":
		return {}

	for raw_object in get_available_objects(
		context
	):
		if typeof(
			raw_object
		) != TYPE_DICTIONARY:
			continue

		var object_contract: Dictionary = (
			raw_object as Dictionary
		)
		var object_ids: Array = [
			str(
				object_contract.get(
					"object_id",
					""
				)
			).strip_edges().to_lower(),
			str(
				object_contract.get(
					"catalog_object_id",
					""
				)
			).strip_edges().to_lower()
		]

		if clean_id in object_ids:
			return object_contract.duplicate(true)

	return {}


func get_external_weapon_data(
	weapon_name: String,
	era_name: String = "",
	context: Dictionary = {}
) -> Dictionary:
	var clean_name: String = str(
		weapon_name
	).strip_edges().to_lower()

	if clean_name == "":
		return {}

	var query: Dictionary = context.duplicate(true)
	query ["era"] = (
		str(
			era_name
		).strip_edges()
		if str(
			era_name
		).strip_edges() != ""
		else _current_era_name()
	)
	query ["include_base_catalog"] = false
	query ["include_modded"] = true

	for raw_weapon in _mod_weapon_rows(
		_normalize_context(
			query
		)
	):
		if typeof(
			raw_weapon
		) != TYPE_DICTIONARY:
			continue

		var weapon: Dictionary = (
			raw_weapon as Dictionary
		)
		var candidate_name: String = str(
			weapon.get(
				"name",
				weapon.get(
					"display_name",
					""
				)
			)
		).strip_edges().to_lower()

		if candidate_name == clean_name:
			return weapon.duplicate(true)

	return {}


func resolve_weapon_definition(
	weapon_name: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_name: String = str(
		weapon_name
	).strip_edges()

	if clean_name == "":
		return {}

	var normalized_context: Dictionary = _normalize_context(
		context
	)

	if (
		gs != null
		and gs.weapons_engine != null
		and gs.weapons_engine.has_method(
			"get_weapon_data_for_era"
		)
	):
		var base_definition: Dictionary = _safe_dictionary(
			gs.weapons_engine.get_weapon_data_for_era(
				clean_name,
				str(
					normalized_context.get(
						"era",
						_current_era_name()
					)
				)
			)
		)

		if not base_definition.is_empty():
			base_definition ["source_kind"] = "base_weapon_catalog"
			return base_definition

	var external_definition: Dictionary = get_external_weapon_data(
		clean_name,
		str(
			normalized_context.get(
				"era",
				_current_era_name()
			)
		),
		normalized_context
	)

	if not external_definition.is_empty():
		external_definition ["source_kind"] = "mod_provider"

	return external_definition


func object_contract_for_weapon(
	weapon: Dictionary,
	context: Dictionary = {},
	source_kind: String = "base_weapon_catalog"
) -> Dictionary:
	var clean_weapon: Dictionary = weapon.duplicate(true)
	var name: String = str(
		clean_weapon.get(
			"name",
			clean_weapon.get(
				"display_name",
				""
			)
		)
	).strip_edges()

	if name == "":
		return {}

	var catalog_id: String = str(
		clean_weapon.get(
			"catalog_object_id",
			clean_weapon.get(
				"object_id",
				""
			)
		)
	).strip_edges().to_lower()

	if catalog_id == "":
		catalog_id = "weapon:%s" % _slug(
			str(
				clean_weapon.get(
					"id",
					name
				)
			)
		)

	var era_name: String = str(
		clean_weapon.get(
			"era",
			context.get(
				"era",
				_current_era_name()
			)
		)
	).strip_edges()
	var action_contract: Dictionary = _weapon_action_contract(
		name,
		era_name,
		clean_weapon
	)
	var actions: Array = _safe_array(
		action_contract.get(
			"actions",
			clean_weapon.get(
				"actions",
				[]
			)
		)
	)
	var legal: bool = bool(
		clean_weapon.get(
			"legal",
			true
		)
	)
	var license_required: bool = bool(
		clean_weapon.get(
			"license_required",
			false
		)
	)
	var provider_ids: Array = [
		"eralife.catalog.weapons"
	]
	var mod_id: String = str(
		clean_weapon.get(
			"mod_id",
			""
		)
	).strip_edges()

	if mod_id != "":
		provider_ids.append(
			"mod:%s" % mod_id
		)

	return {
		"schema": OBJECT_SCHEMA,
		"version": OBJECT_VERSION,
		"object_id": catalog_id,
		"catalog_object_id": catalog_id,
		"instance_object_id": "",
		"name": name,
		"display_name": str(
			clean_weapon.get(
				"display_name",
				name
			)
		),
		"type": "Weapon",
		"subtype": str(
			clean_weapon.get(
				"type",
				clean_weapon.get(
					"weapon_type",
					"weapon"
				)
			)
		).strip_edges().to_lower(),
		"domains": _weapon_domains(
			clean_weapon
		),
		"provider_ids": _unique_strings(
			provider_ids
		),
		"source_kind": source_kind,
		"modded": (
			mod_id != ""
			or source_kind == "mod_provider"
		),
		"mod_id": mod_id,
		"owned": bool(
			clean_weapon.get(
				"owned",
				false
			)
		),
		"available": bool(
			clean_weapon.get(
				"available",
				true
			)
		),
		"cost": int(
			clean_weapon.get(
				"cost",
				clean_weapon.get(
					"value",
					0
				)
			)
		),
		"value": int(
			clean_weapon.get(
				"value",
				clean_weapon.get(
					"cost",
					0
				)
			)
		),
		"origin": {
			"era": era_name,
			"country": str(
				clean_weapon.get(
					"country",
					context.get(
						"country",
						""
					)
				)
			),
			"city": str(
				clean_weapon.get(
					"city",
					context.get(
						"city",
						""
					)
				)
			),
			"source": source_kind,
			"provider": (
				"mod_contract_engine"
				if mod_id != ""
				else "weapons_engine"
			)
		},
		"ownership": {
			"owner_id": -1,
			"scope": "available",
			"chain": []
		},
		"legal": {
			"classification": "weapon",
			"legal": legal,
			"restricted": not legal,
			"license_required": license_required,
			"label": str(
				clean_weapon.get(
					"legality_label",
					(
						"Illegal / Restricted"
						if not legal
						else (
							"Legal With License"
							if license_required
							else "Legal"
						)
					)
				)
			)
		},
		"cultural": {
			"rarity": str(
				clean_weapon.get(
					"rarity",
					"Common"
				)
			),
			"historical_value": int(
				clean_weapon.get(
					"historical_value",
					0
				)
			),
			"reputation_label": str(
				clean_weapon.get(
					"reputation_label",
					""
				)
			)
		},
		"actions": _dedupe_actions(
			actions
		),
		"behavior_providers": [
			{
				"provider_id": "weapons_engine",
				"domain": "weapon",
				"authority": "weapon_truth",
			},
			{
				"provider_id": "crime_contract_engine",
				"domain": "crime",
				"authority": "weapon_action_validation",
			},
			{
				"provider_id": "crime_engine",
				"domain": "consequence",
				"authority": "committed_weapon_outcomes",
			}
		],
		"damage_profile": _safe_dictionary(
			clean_weapon.get(
				"damage_profile",
				{
					"profile_id": str(
						action_contract.get(
							"profile_id",
							""
						)
					),
					"actions": _safe_array(
						action_contract.get(
							"actions",
							[]
						)
					)
				}
			)
		),
		"weapon_contract": action_contract.duplicate(true),
		"source_contract": clean_weapon.duplicate(true),
		"read_only_catalog_projection": true,
		"ui_is_renderer_only": true,
		"projected_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func purchase_definition_from_object(
	object_contract: Dictionary
) -> Dictionary:
	var source_contract: Dictionary = _safe_dictionary(
		object_contract.get(
			"source_contract",
			{}
		)
	)

	if source_contract.is_empty():
		source_contract = object_contract.duplicate(true)

	source_contract ["name"] = str(
		object_contract.get(
			"name",
			source_contract.get(
				"name",
				""
			)
		)
	)
	source_contract ["catalog_object_id"] = str(
		object_contract.get(
			"catalog_object_id",
			object_contract.get(
				"object_id",
				""
			)
		)
	)
	source_contract ["object_domains"] = _safe_array(
		object_contract.get(
			"object_domains",
			object_contract.get(
				"domains",
				[
					"weapon"
				]
			)
		)
	)
	source_contract ["weapon_contract"] = _safe_dictionary(
		object_contract.get(
			"weapon_contract",
			{}
		)
	)
	source_contract ["catalog_validated"] = true
	return source_contract


func _base_weapon_rows(
	context: Dictionary
) -> Array:
	if not bool(
		context.get(
			"include_base_catalog",
			true
		)
	):
		return []

	if (
		gs == null
		or gs.weapons_engine == null
	):
		return []

	var era_name: String = str(
		context.get(
			"era",
			_current_era_name()
		)
	)
	var rows: Array = []

	if gs.weapons_engine.has_method(
		"get_weapons_for_context"
	):
		rows = _safe_array(
			gs.weapons_engine.get_weapons_for_context(
				context
			)
		)
	elif gs.weapons_engine.has_method(
		"get_store_for_era"
	):
		rows = _safe_array(
			gs.weapons_engine.get_store_for_era(
				era_name
			)
		)

	return rows


func _mod_weapon_rows(
	context: Dictionary
) -> Array:
	if (
		not bool(
			context.get(
				"include_modded",
				true
			)
		)
		or gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows"
		)
	):
		return []

	var actor: Person = _actor_from_context(
		context
	)
	var out: Array = []

	for provider_type in [
		"weapons",
		"objects"
	]:
		for raw_row in _safe_array(
			gs.mod_contract_engine.emit_provider_rows(
				provider_type,
				actor,
				context
			)
		):
			if typeof(
				raw_row
			) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			).duplicate(true)
			var domains: Array = _unique_strings(
				_safe_array(
					row.get(
						"domains",
						row.get(
							"object_domains",
							[]
						)
					)
				)
			)
			var row_type: String = str(
				row.get(
					"type",
					row.get(
						"object_type",
						""
					)
				)
			).strip_edges().to_lower()

			if (
				provider_type == "objects"
				and "weapon" not in domains
				and row_type.find(
					"weapon"
				) < 0
			):
				continue

			row ["modded"] = true
			row ["source_kind"] = "mod_provider"
			out.append(row)

	return out


func _weapon_action_contract(
	weapon_name: String,
	era_name: String,
	weapon: Dictionary
) -> Dictionary:
	var embedded: Dictionary = _safe_dictionary(
		weapon.get(
			"weapon_contract",
			weapon.get(
				"action_contract",
				{}
			)
		)
	)

	if not embedded.is_empty():
		return embedded

	if (
		gs != null
		and gs.weapons_engine != null
		and gs.weapons_engine.has_method(
			"get_weapon_action_contract"
		)
	):
		var resolved: Dictionary = _safe_dictionary(
			gs.weapons_engine.get_weapon_action_contract(
				weapon_name,
				era_name
			)
		)

		if not resolved.is_empty():
			return resolved

	var actions: Array = _safe_array(
		weapon.get(
			"actions",
			[]
		)
	)

	return {
		"schema": "eralife.weapon_action_contract",
		"version": 1,
		"weapon_id": str(
			weapon.get(
				"id",
				_slug(
					weapon_name
				)
			)
		),
		"weapon_name": weapon_name,
		"weapon_type": str(
			weapon.get(
				"type",
				"weapon"
			)
		),
		"profile_id": str(
			weapon.get(
				"profile_id",
				"modded_weapon"
			)
		),
		"era": era_name,
		"legal": bool(
			weapon.get(
				"legal",
				true
			)
		),
		"license_required": bool(
			weapon.get(
				"license_required",
				false
			)
		),
		"actions": actions,
		"action_count": actions.size(),
		"source_kind": "catalog_fallback"
	}


func _weapon_domains(
	weapon: Dictionary
) -> Array:
	var domains: Array = [
		"weapon"
	]

	for raw_domain in _safe_array(
		weapon.get(
			"domains",
			weapon.get(
				"object_domains",
				[]
			)
		)
	):
		domains.append(
			raw_domain
		)

	if bool(
		weapon.get(
			"heirloom",
			false
		)
	):
		domains.append(
			"heirloom"
		)

	if bool(
		weapon.get(
			"artifact",
			false
		)
	):
		domains.append(
			"artifact"
		)

	return _unique_strings(
		domains
	)


func _normalize_context(
	context: Dictionary
) -> Dictionary:
	var out: Dictionary = context.duplicate(true)
	out ["era"] = str(
		out.get(
			"era",
			_current_era_name()
		)
	).strip_edges()
	out ["country"] = str(
		out.get(
			"country",
			_current_country()
		)
	).strip_edges()
	out ["city"] = str(
		out.get(
			"city",
			_current_city()
		)
	).strip_edges()
	out ["actor_id"] = int(
		out.get(
			"actor_id",
			(
				int(
					gs.player.id
				)
				if (
					gs != null
					and gs.player != null
				)
				else -1
			)
		)
	)
	return out


func _actor_from_context(
	context: Dictionary
) -> Person:
	if gs == null:
		return null

	var actor_id: int = int(
		context.get(
			"actor_id",
			-1
		)
	)

	if (
		gs.player != null
		and (
			actor_id <= 0
			or int(
				gs.player.id
			) == actor_id
		)
	):
		return gs.player

	if (
		actor_id > 0
		and gs.has_method(
			"get_npc_by_id"
		)
	):
		var actor = gs.get_npc_by_id(
			actor_id
		)

		if actor is Person:
			return actor as Person

	return null


func _current_era_name() -> String:
	if (
		gs != null
		and gs.era != null
	):
		return str(
			gs.era.name
			if "name" in gs.era
			else gs.era
		).strip_edges()

	return "Modern Era"


func _current_country() -> String:
	if (
		gs != null
		and gs.player != null
	):
		for key in [
			"country",
			"birth_country",
			"current_country",
			"home_country"
		]:
			var value: String = str(
				gs.player.get(
					key
				)
			).strip_edges()

			if value != "":
				return value

	return "United States"


func _current_city() -> String:
	if (
		gs != null
		and gs.player != null
	):
		for key in [
			"city",
			"birth_city",
			"current_city",
			"home_city"
		]:
			var value: String = str(
				gs.player.get(
					key
				)
			).strip_edges()

			if value != "":
				return value

	return "Unknown City"


func _dedupe_by_catalog_id(
	objects: Array
) -> Array:
	var out: Array = []
	var index_by_id: Dictionary = {}

	for raw_object in objects:
		if typeof(
			raw_object
		) != TYPE_DICTIONARY:
			continue

		var object_contract: Dictionary = (
			raw_object as Dictionary
		).duplicate(true)
		var catalog_id: String = str(
			object_contract.get(
				"catalog_object_id",
				object_contract.get(
					"object_id",
					""
				)
			)
		).strip_edges().to_lower()

		if catalog_id == "":
			continue

		if not index_by_id.has(
			catalog_id
		):
			index_by_id [catalog_id] = out.size()
			out.append(object_contract)
			continue

		var index: int = int(
			index_by_id.get(
				catalog_id,
				-1
			)
		)

		if (
			index < 0
			or index >= out.size()
		):
			continue

		var existing: Dictionary = _safe_dictionary(
			out [index]
		)

		if (
			bool(
				object_contract.get(
					"modded",
					false
				)
			)
			and not bool(
				existing.get(
					"modded",
					false
				)
			)
		):
			out [index] = object_contract

	return out


func _dedupe_actions(
	actions: Array
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_action in actions:
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		).duplicate(true)
		var action_id: String = str(
			action.get(
				"id",
				action.get(
					"action_id",
					""
				)
			)
		).strip_edges().to_lower()

		if action_id == "":
			action_id = "action_%d" % out.size()

		if seen.has(
			action_id
		):
			continue

		seen [action_id] = true
		action ["id"] = action_id
		out.append(action)

	return out


func _unique_strings(
	values: Array
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_value in values:
		var value: String = str(
			raw_value
		).strip_edges().to_lower()

		if (
			value == ""
			or seen.has(
				value
			)
		):
			continue

		seen [value] = true
		out.append(value)

	return out


func _slug(
	value: String
) -> String:
	return str(
		value
	).strip_edges().to_lower().replace(
		" ",
		"_"
	).replace(
		"-",
		"_"
	).replace(
		"/",
		"_"
	).replace(
		":",
		"_"
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []