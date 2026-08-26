

extends RefCounted
class_name ArtifactsCatalogContractEngine

const ENGINE_SCHEMA:= "eralife.artifacts_catalog_contract_engine"
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
		"provider_id": "eralife.catalog.artifacts",
		"domains": [
			"artifact"
		],
		"truth_engine_property": "artifacts_engine",
		"mod_provider_types": [
			"artifacts",
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
		"provider_id": "eralife.catalog.artifacts",
		"engine_property": "artifacts_catalog_contract_engine",
		"method": "get_available_objects",
		"domains": [
			"artifact"
		],
		"priority": 200,
		"read_only": true,
		"truth_engine_property": "artifacts_engine",
	}


func get_available_objects(
	context: Dictionary = {}
) -> Array:
	if (
		gs == null
		or gs.artifacts_engine == null
	):
		return []

	var normalized_context: Dictionary = _normalize_context(
		context
	)
	var actor: Person = _actor_from_context(
		normalized_context
	)
	var include_shop: bool = bool(
		normalized_context.get(
			"include_catalog_definitions",
			true
		)
	)
	var include_owned: bool = bool(
		normalized_context.get(
			"include_owned_instances",
			true
		)
	)
	var out: Array = []

	if include_shop:
		for raw_entry in _artifact_shop_rows(
			actor
		):
			if typeof(
				raw_entry
			) != TYPE_DICTIONARY:
				continue

			var contract: Dictionary = object_contract_for_shop_entry(
				raw_entry as Dictionary,
				normalized_context
			)

			if not contract.is_empty():
				out.append(
					contract
				)

		for raw_entry in _exchange_artifact_catalog_rows(
			actor
		):
			if typeof(
				raw_entry
			) != TYPE_DICTIONARY:
				continue

			var exchange_contract: Dictionary = (
				object_contract_for_exchange_artifact_entry(
					raw_entry as Dictionary,
					normalized_context
				)
			)

			if not exchange_contract.is_empty():
				out.append(
					exchange_contract
				)

	if include_owned:
		for raw_item in _owned_artifact_items(
			actor
		):
			if typeof(
				raw_item
			) != TYPE_DICTIONARY:
				continue

			var owned_contract: Dictionary = object_contract_for_owned_item(
				raw_item as Dictionary,
				actor,
				normalized_context
			)

			if not owned_contract.is_empty():
				out.append(owned_contract)

	for raw_stone in _stone_ownership_rows(
		actor,
		normalized_context
	):
		if typeof(
			raw_stone
		) != TYPE_DICTIONARY:
			continue

		out.append(
			(raw_stone as Dictionary).duplicate(true)
		)

	for raw_mod_artifact in _mod_artifact_rows(
		actor,
		normalized_context
	):
		if typeof(
			raw_mod_artifact
		) != TYPE_DICTIONARY:
			continue

		var mod_entry: Dictionary = (
			raw_mod_artifact as Dictionary
		).duplicate(true)
		var mod_contract: Dictionary = object_contract_for_shop_entry(
			mod_entry,
			normalized_context
		)

		if mod_contract.is_empty():
			continue

		mod_contract ["provider_id"] = str(
			mod_entry.get(
				"provider_id",
				"eralife.mod.artifacts"
			)
		)
		mod_contract ["source_kind"] = "mod_provider"
		mod_contract ["modded"] = true
		mod_contract ["mod_id"] = str(
			mod_entry.get(
				"mod_id",
				""
			)
		)
		out.append(
			mod_contract
		)

	out = _dedupe_objects(
		out
	)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "artifact_catalog_projection",
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
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
		var candidate_ids: Array = [
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
			).strip_edges().to_lower(),
			str(
				object_contract.get(
					"instance_object_id",
					""
				)
			).strip_edges().to_lower()
		]

		if clean_id in candidate_ids:
			return object_contract.duplicate(true)

	return {}


func object_contract_for_shop_entry(
	entry: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_entry: Dictionary = entry.duplicate(true)
	var item_id: String = str(
		clean_entry.get(
			"id",
			clean_entry.get(
				"shop_item_id",
				""
			)
		)
	).strip_edges().to_lower()
	var name: String = str(
		clean_entry.get(
			"name",
			"Artifact"
		)
	).strip_edges()

	if item_id == "":
		item_id = _slug(name)

	if item_id == "":
		return {}

	var grant_type: String = str(
		clean_entry.get(
			"grant_type",
			"artifact"
		)
	).strip_edges().to_lower()
	var artifact_kind: String = str(
		clean_entry.get(
			"artifact_kind",
			grant_type
		)
	).strip_edges().to_lower()
	var available: bool = str(
		clean_entry.get(
			"status_text",
			"Available"
		)
	).strip_edges().to_lower() == "available"
	var cost: int = int(
		clean_entry.get(
			"cost",
			clean_entry.get(
				"value",
				0
			)
		)
	)
	var catalog_id: String = "artifact:%s" % item_id
	var actions: Array = _artifact_actions_for_item({
		"name": name,
		"artifact_kind": artifact_kind,
		"shop_item_id": item_id
	})

	return _base_object_contract({
		"object_id": catalog_id,
		"catalog_object_id": catalog_id,
		"instance_object_id": "",
		"name": name,
		"display_name": name,
		"type": "Artifact",
		"subtype": artifact_kind,
		"domains": _artifact_domains(
			clean_entry
		),
		"provider_id": "eralife.catalog.artifacts",
		"source_kind": "catalog_definition",
		"owned": false,
		"available": available,
		"cost": cost,
		"value": int(
			clean_entry.get(
				"value",
				cost
			)
		),
		"rarity": str(
			clean_entry.get(
				"rarity",
				"Rare"
			)
		),
		"lore": str(
			clean_entry.get(
				"lore",
				""
			)
		),
		"ability": str(
			clean_entry.get(
				"ability",
				""
			)
		),
		"origin": {
			"era": str(
				context.get(
					"era",
					_current_era_name()
				)
			),
			"location": str(
				context.get(
					"location",
					context.get(
						"country",
						""
					)
				)
			),
			"source": "artifact_shop",
			"provider": "artifacts_engine"
		},
		"ownership": {
			"owner_id": -1,
			"scope": "available",
			"chain": []
		},
		"legal": {
			"classification": "artifact",
			"legal": true,
			"restricted": bool(
				clean_entry.get(
					"restricted",
					false
				)
			)
		},
		"cultural": {
			"rarity": str(
				clean_entry.get(
					"rarity",
					"Rare"
				)
			),
			"mythic_rank": str(
				clean_entry.get(
					"mythic_rank",
					""
				)
			),
			"historical_value": int(
				clean_entry.get(
					"historical_value",
					0
				)
			)
		},
		"actions": actions,
		"behavior_providers": _artifact_behavior_providers(
			actions
		),
		"source_contract": clean_entry
	})


func object_contract_for_owned_item(
	item: Dictionary,
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var clean_item: Dictionary = item.duplicate(true)
	var numeric_id: int = int(
		clean_item.get(
			"id",
			-1
		)
	)
	var name: String = str(
		clean_item.get(
			"display_name",
			clean_item.get(
				"name",
				"Artifact"
			)
		)
	).strip_edges()
	var catalog_id: String = str(
		clean_item.get(
			"catalog_object_id",
			""
		)
	).strip_edges().to_lower()

	if catalog_id == "":
		var shop_id: String = str(
			clean_item.get(
				"shop_item_id",
				""
			)
		).strip_edges().to_lower()

		if shop_id != "":
			catalog_id = "artifact:%s" % shop_id
		else:
			catalog_id = "artifact:%s" % _slug(name)

	var instance_id: String = str(
		clean_item.get(
			"object_id",
			clean_item.get(
				"instance_object_id",
				""
			)
		)
	).strip_edges().to_lower()

	if instance_id == "":
		instance_id = (
			"object:%d" % numeric_id
			if numeric_id > 0
			else "%s:owned:%d" % [
				catalog_id,
				(
					int(actor.id)
					if actor != null
					else -1
				)
			]
		)

	var actions: Array = _safe_array(
		clean_item.get(
			"actions",
			[]
		)
	)

	for action in _artifact_actions_for_item(
		clean_item
	):
		actions.append(action)

	actions = _dedupe_actions(
		actions
	)

	return _base_object_contract({
		"object_id": instance_id,
		"instance_object_id": instance_id,
		"catalog_object_id": catalog_id,
		"name": name,
		"display_name": name,
		"type": str(
			clean_item.get(
				"type",
				"Artifact"
			)
		),
		"subtype": str(
			clean_item.get(
				"artifact_kind",
				clean_item.get(
					"item_family",
					"artifact"
				)
			)
		),
		"domains": _artifact_domains(
			clean_item
		),
		"provider_id": "eralife.catalog.artifacts",
		"source_kind": "owned_instance",
		"owned": true,
		"available": true,
		"owner_id": (
			int(actor.id)
			if actor != null
			else int(
				clean_item.get(
					"owner_id",
					-1
				)
			)
		),
		"value": int(
			clean_item.get(
				"value",
				clean_item.get(
					"worth",
					0
				)
			)
		),
		"rarity": str(
			clean_item.get(
				"rarity",
				"Rare"
			)
		),
		"lore": str(
			clean_item.get(
				"lore",
				""
			)
		),
		"ability": str(
			clean_item.get(
				"ability",
				""
			)
		),
		"origin": {
			"era": str(
				clean_item.get(
					"origin_era",
					context.get(
						"era",
						_current_era_name()
					)
				)
			),
			"country": str(
				clean_item.get(
					"origin_country",
					""
				)
			),
			"source": str(
				clean_item.get(
					"source",
					"belongings_engine"
				)
			),
			"acquired_year": int(
				clean_item.get(
					"acquired_year",
					0
				)
			)
		},
		"ownership": {
			"owner_id": (
				int(actor.id)
				if actor != null
				else int(
					clean_item.get(
						"owner_id",
						-1
					)
				)
			),
			"scope": "owned",
			"chain": _safe_array(
				clean_item.get(
					"ownership_chain",
					[]
				)
			)
		},
		"legal": _safe_dictionary(
			clean_item.get(
				"legal_contract",
				{
					"classification": "artifact",
					"legal": true,
					"restricted": false
				}
			)
		),
		"cultural": {
			"rarity": str(
				clean_item.get(
					"rarity",
					"Rare"
				)
			),
			"mythic_rank": str(
				clean_item.get(
					"mythic_rank",
					""
				)
			),
			"historical_value": int(
				clean_item.get(
					"historical_value",
					0
				)
			),
			"myth_profile": _safe_dictionary(
				clean_item.get(
					"myth_profile",
					{}
				)
			)
		},
		"actions": actions,
		"behavior_providers": _artifact_behavior_providers(
			actions
		),
		"source_contract": clean_item
	})


func _artifact_shop_rows(
	actor: Person
) -> Array:
	if (
		gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"get_shop_inventory"
		)
	):
		return []

	var rows: Variant = gs.artifacts_engine.get_shop_inventory(
		actor
	)

	return _safe_array(
		rows
	)

func _exchange_artifact_catalog_rows(
	actor: Person
) -> Array:
	if (
		gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"get_exchange_artifact_catalog_rows"
		)
	):
		return []

	var rows: Variant = (
		gs.artifacts_engine.get_exchange_artifact_catalog_rows(
			actor
		)
	)

	return _safe_array(
		rows
	)
func object_contract_for_exchange_artifact_entry(
	entry: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var contract: Dictionary = (
		object_contract_for_shop_entry(
			entry,
			context
		)
	)

	if contract.is_empty():
		return {}

	contract [
		"source_kind"
	] = "persistent_exchange_artifact_definition"

	var origin: Dictionary = _safe_dictionary(
		contract.get(
			"origin",
			{}
		)
	)

	origin [
		"source"
	] = "luxury_sanctorum_artifact_authority"
	origin [
		"provider"
	] = "artifacts_engine"

	contract [
		"origin"
	] = origin

	var ownership: Dictionary = _safe_dictionary(
		contract.get(
			"ownership",
			{}
		)
	)

	ownership [
		"scope"
	] = "canonical_exchange_supply"

	contract [
		"ownership"
	] = ownership
	contract [
		"source_contract"
	] = entry.duplicate(true)

	return contract
func _owned_artifact_items(
	actor: Person
) -> Array:
	if (
		actor == null
		or gs == null
		or gs.belongings_engine == null
		or not gs.belongings_engine.has_method(
			"get_inventory"
		)
	):
		return []

	var inventory: Dictionary = _safe_dictionary(
		gs.belongings_engine.get_inventory(
			actor
		)
	)
	var out: Array = []

	for raw_category in inventory.keys():
		var category: String = str(
			raw_category
		).strip_edges().to_lower()

		if (
			category.find(
				"artifact"
			) < 0
			and category.find(
				"relic"
			) < 0
			and category.find(
				"dragon ball"
			) < 0
		):
			continue

		for raw_item in _safe_array(
			inventory.get(
				raw_category,
				[]
			)
		):
			if typeof(
				raw_item
			) != TYPE_DICTIONARY:
				continue

			out.append(
				(raw_item as Dictionary).duplicate(true)
			)

	return out


func _stone_ownership_rows(
	actor: Person,
	context: Dictionary
) -> Array:
	if (
		actor == null
		or gs == null
		or gs.artifacts_engine == null
		or not _object_has_property(
			gs.artifacts_engine,
			"ownership"
		)
	):
		return []

	var ownership: Dictionary = _safe_dictionary(
		gs.artifacts_engine.get(
			"ownership"
		)
	)
	var stone_names: Array = _safe_array(
		ownership.get(
			int(actor.id),
			ownership.get(
				str(
					int(actor.id)
				),
				[]
			)
		)
	)
	var out: Array = []

	for raw_stone_name in stone_names:
		var stone_name: String = str(
			raw_stone_name
		).strip_edges()

		if stone_name == "":
			continue

		var item: Dictionary = {
			"id": -1,
			"name": "%s Stone" % stone_name,
			"display_name": "%s Stone" % stone_name,
			"type": "Artifact",
			"artifact_kind": "stone",
			"item_family": "stone",
			"origin_era": str(
				context.get(
					"era",
					_current_era_name()
				)
			),
			"owner_id": int(
				actor.id
			),
			"mythic_rank": "mythic"
		}
		var contract: Dictionary = object_contract_for_owned_item(
			item,
			actor,
			context
		)
		contract ["catalog_object_id"] = "artifact:%s_stone" % _slug(
			stone_name
		)
		contract ["object_id"] = "artifact:%s_stone:owner:%d" % [
			_slug(
				stone_name
			),
			int(
				actor.id
			)
		]
		contract ["instance_object_id"] = str(
			contract ["object_id"]
		)
		out.append(contract)

	return out


func _artifact_actions_for_item(
	item: Dictionary
) -> Array:
	if (
		gs == null
		or gs.artifacts_engine == null
	):
		return []

	var out: Array = []

	if gs.artifacts_engine.has_method(
		"get_artifact_action_definitions"
	):
		for raw_action in _safe_array(
			gs.artifacts_engine.get_artifact_action_definitions(
				item
			)
		):
			if typeof(
				raw_action
			) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = (
				raw_action as Dictionary
			).duplicate(true)
			action ["route"] = {
				"engine_property": "artifacts_engine",
				"method": "use_artifact_on_target",
				"route_kind": "engine_method",
				"requires_target": true
			}
			action ["source_kind"] = "artifact_truth_engine"
			out.append(action)

	if gs.artifacts_engine.has_method(
		"get_artifact_action_specs"
	):
		for raw_spec in _safe_array(
			gs.artifacts_engine.get_artifact_action_specs(
				item
			)
		):
			if typeof(
				raw_spec
			) != TYPE_DICTIONARY:
				continue

			var spec: Dictionary = (
				raw_spec as Dictionary
			).duplicate(true)
			spec ["route"] = {
				"engine_property": "artifacts_engine",
				"method": str(
					spec.get(
						"resolver_method",
						"perform_artifact_action"
					)
				),
				"route_kind": "engine_method",
				"requires_target": bool(
					spec.get(
						"requires_target",
						false
					)
				)
			}
			spec ["source_kind"] = "artifact_truth_engine"
			out.append(spec)

	return _dedupe_actions(
		out
	)


func _artifact_behavior_providers(
	actions: Array
) -> Array:
	var out: Array = [
		{
			"provider_id": "artifacts_engine",
			"domain": "artifact",
			"authority": "simulation_truth",
		}
	]

	if not actions.is_empty():
		out.append({
			"provider_id": "artifacts_engine.actions",
			"domain": "interaction",
			"authority": "artifact_action_resolution",
		})

	return out


func _artifact_domains(
	item: Dictionary
) -> Array:
	var domains: Array = [
		"artifact"
	]
	var name: String = str(
		item.get(
			"name",
			item.get(
				"display_name",
				""
			)
		)
	).strip_edges().to_lower()
	var item_type: String = str(
		item.get(
			"type",
			""
		)
	).strip_edges().to_lower()

	if (
		item_type.find(
			"weapon"
		) >= 0
		or name.find(
			"sword"
		) >= 0
		or name.find(
			"blade"
		) >= 0
		or name.find(
			"dagger"
		) >= 0
	):
		domains.append(
			"weapon"
		)

	if (
		bool(
			item.get(
				"heirloom",
				false
			)
		)
		or bool(
			_safe_dictionary(
				item.get(
					"persistence",
					{}
				)
			).get(
				"generationally_persistent",
				false
			)
		)
	):
		domains.append(
			"heirloom"
		)

	return _unique_strings(
		domains
	)


func _base_object_contract(
	fields: Dictionary
) -> Dictionary:
	var out: Dictionary = fields.duplicate(true)
	out ["schema"] = OBJECT_SCHEMA
	out ["version"] = OBJECT_VERSION
	out ["object_id"] = str(
		out.get(
			"object_id",
			out.get(
				"catalog_object_id",
				""
			)
		)
	).strip_edges().to_lower()
	out ["catalog_object_id"] = str(
		out.get(
			"catalog_object_id",
			out.get(
				"object_id",
				""
			)
		)
	).strip_edges().to_lower()
	out ["instance_object_id"] = str(
		out.get(
			"instance_object_id",
			""
		)
	).strip_edges().to_lower()
	out ["domains"] = _unique_strings(
		_safe_array(
			out.get(
				"domains",
				[
					"artifact"
				]
			)
		)
	)
	out ["provider_ids"] = _unique_strings([
		str(
			out.get(
				"provider_id",
				"eralife.catalog.artifacts"
			)
		)
	])
	out ["history"] = _safe_array(
		out.get(
			"history",
			[]
		)
	)
	out ["actions"] = _dedupe_actions(
		_safe_array(
			out.get(
				"actions",
				[]
			)
		)
	)
	out ["behavior_providers"] = _safe_array(
		out.get(
			"behavior_providers",
			[]
		)
	)
	out ["read_only_catalog_projection"] = true
	out ["ui_is_renderer_only"] = true
	out ["projected_at_ms"] = int(
		Time.get_ticks_msec()
	)
	return out


func _mod_artifact_rows(
	actor: Person,
	context: Dictionary
) -> Array:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows"
		)
		or not bool(
			context.get(
				"include_modded",
				true
			)
		)
	):
		return []

	var out: Array = []

	for provider_type in [
		"artifacts",
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
			var domains: Array = _string_array(
				row.get(
					"object_domains",
					row.get(
						"domains",
						[]
					)
				)
			)

			if (
				provider_type == "objects"
				and "artifact" not in domains
				and not bool(
					row.get(
						"artifact",
						false
					)
				)
			):
				continue

			row ["provider_id"] = str(
				row.get(
					"provider_id",
					"eralife.mod.%s" % provider_type
				)
			)
			out.append(
				row
			)

	return out


func _dedupe_objects(
	objects: Array
) -> Array:
	var index: Dictionary = {}
	var order: Array = []

	for raw_object in objects:
		if typeof(
			raw_object
		) != TYPE_DICTIONARY:
			continue

		var object_contract: Dictionary = (
			raw_object as Dictionary
		).duplicate(true)
		var key: String = str(
			object_contract.get(
				"instance_object_id",
				object_contract.get(
					"catalog_object_id",
					object_contract.get(
						"object_id",
						""
					)
				)
			)
		).strip_edges().to_lower()

		if key == "":
			continue

		if key not in order:
			order.append(
				key
			)

		index [key] = object_contract

	var out: Array = []

	for key in order:
		out.append(
			_safe_dictionary(
				index.get(
					key,
					{}
				)
			)
		)

	return out


func _string_array(
	value: Variant
) -> Array:
	var out: Array = []

	for raw_value in _safe_array(
		value
	):
		var clean: String = str(
			raw_value
		).strip_edges().to_lower()

		if (
			clean != ""
			and clean not in out
		):
			out.append(
				clean
			)

	return out


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

	if (
		actor_id > 0
		and gs.has_method(
			"get_or_reactivate_npc_by_id"
		)
	):
		var restored = gs.get_or_reactivate_npc_by_id(
			actor_id
		)

		if restored is Person:
			return restored as Person

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


func _object_has_property(
	target: Object,
	property_name: String
) -> bool:
	if target == null:
		return false

	for raw_property in target.get_property_list():
		if typeof(
			raw_property
		) != TYPE_DICTIONARY:
			continue

		if str(
			(raw_property as Dictionary).get(
				"name",
				""
			)
		) == property_name:
			return true

	return false


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