

extends RefCounted
class_name GlobalObjectCatalogSystem

const ENGINE_SCHEMA:= "eralife.global_object_catalog_system"
const ENGINE_VERSION:= 1
const OBJECT_SCHEMA:= "eralife.global_object_contract"
const OBJECT_VERSION:= 1
const PROVIDER_SCHEMA:= "eralife.object_catalog_provider_contract"
const MAX_OBJECTS_PER_QUERY:= 4096

var gs
var provider_registry: Dictionary = {}
var provider_order: Array = []
var registry_revision: int = 0
var last_query_report: Dictionary = {}
var last_resolution_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	bootstrap_default_providers()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	bootstrap_default_providers()


func bootstrap_default_providers() -> Dictionary:
	provider_registry.clear()
	provider_order.clear()

	_register_first_party_provider({
		"schema": PROVIDER_SCHEMA,
		"version": 1,
		"provider_id": "eralife.catalog.artifacts",
		"engine_property": "artifacts_catalog_contract_engine",
		"method": "get_available_objects",
		"domains": [
			"artifact"
		],
		"priority": 200,
		"required": false,
		"read_only": true
	})
	_register_first_party_provider({
		"schema": PROVIDER_SCHEMA,
		"version": 1,
		"provider_id": "eralife.catalog.heirlooms",
		"engine_property": "heirloom_catalog_contract_engine",
		"method": "get_available_objects",
		"domains": [
			"heirloom"
		],
		"priority": 210,
		"required": false,
		"read_only": true
	})
	_register_first_party_provider({
		"schema": PROVIDER_SCHEMA,
		"version": 1,
		"provider_id": "eralife.catalog.weapons",
		"engine_property": "weapons_catalog_expansion",
		"method": "get_available_objects",
		"domains": [
			"weapon"
		],
		"priority": 220,
		"required": false,
		"read_only": true
	})
	_register_first_party_provider({
		"schema": PROVIDER_SCHEMA,
		"version": 1,
		"provider_id": "eralife.catalog.belongings_instances",
		"engine_property": "belongings_engine",
		"method": "get_inventory",
		"domains": [
			"owned_object"
		],
		"priority": 300,
		"required": false,
		"read_only": true,
		"adapter": "belongings_inventory"
	})

	registry_revision += 1

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "global_object_catalog_bootstrap",
		"provider_count": provider_order.size(),
		"provider_ids": provider_order.duplicate(true),
		"registry_revision": registry_revision,
		"read_only": true,
		"ui_is_renderer_only": true
	}


func register_catalog_provider(
	provider_contract: Dictionary
) -> Dictionary:
	var normalized: Dictionary = _normalize_provider_contract(
		provider_contract
	)

	if normalized.is_empty():
		return _failure(
			"invalid_object_catalog_provider",
			"The object catalog provider contract is invalid."
		)

	var provider_id: String = str(
		normalized.get(
			"provider_id",
			""
		)
	)
	var existed: bool = provider_registry.has(
		provider_id
	)

	provider_registry [provider_id] = normalized.duplicate(true)

	if provider_id not in provider_order:
		provider_order.append(
			provider_id
		)

	_sort_provider_order()
	registry_revision += 1

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": (
			"object_catalog_provider_updated"
			if existed
			else "object_catalog_provider_registered"
		),
		"provider_id": provider_id,
		"provider": normalized.duplicate(true),
		"registry_revision": registry_revision,
		"read_only": true
	}


func unregister_catalog_provider(
	provider_id: String
) -> Dictionary:
	var clean_id: String = str(
		provider_id
	).strip_edges()

	if (
		clean_id == ""
		or not provider_registry.has(
			clean_id
		)
	):
		return _failure(
			"object_catalog_provider_not_found",
			"The requested object catalog provider is not registered."
		)

	provider_registry.erase(
		clean_id
	)
	provider_order.erase(
		clean_id
	)
	registry_revision += 1

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "object_catalog_provider_unregistered",
		"provider_id": clean_id,
		"registry_revision": registry_revision
	}


func provider_contracts() -> Array:
	var out: Array = []

	for provider_id in provider_order:
		var provider: Dictionary = _safe_dictionary(
			provider_registry.get(
				provider_id,
				{}
			)
		)

		if not provider.is_empty():
			out.append(
				provider
			)

	return out


func get_available_objects(
	context: Dictionary = {}
) -> Array:
	var normalized_context: Dictionary = _normalize_context(
		context
	)
	var actor: Person = _actor_from_context(
		normalized_context
	)
	var merged_index: Dictionary = {}
	var merge_order: Array = []
	var provider_reports: Array = []
	var raw_object_count: int = 0

	for provider_id in provider_order:
		var provider: Dictionary = _safe_dictionary(
			provider_registry.get(
				provider_id,
				{}
			)
		)

		if provider.is_empty():
			continue

		if not _provider_matches_query(
			provider,
			normalized_context
		):
			continue

		var provider_result: Dictionary = _emit_provider_objects(
			provider,
			actor,
			normalized_context
		)
		var rows: Array = _safe_array(
			provider_result.get(
				"objects",
				[]
			)
		)
		raw_object_count += rows.size()
		provider_reports.append({
			"provider_id": provider_id,
			"success": bool(
				provider_result.get(
					"success",
					false
				)
			),
			"object_count": rows.size(),
			"reason": str(
				provider_result.get(
					"reason",
					""
				)
			)
		})

		for raw_object in rows:
			if typeof(
				raw_object
			) != TYPE_DICTIONARY:
				continue

			var normalized_object: Dictionary = _normalize_object_contract(
				raw_object as Dictionary,
				provider,
				normalized_context
			)

			if normalized_object.is_empty():
				continue

			_merge_object_into_index(
				merged_index,
				merge_order,
				normalized_object
			)

			if merge_order.size() >= MAX_OBJECTS_PER_QUERY:
				break

		if merge_order.size() >= MAX_OBJECTS_PER_QUERY:
			break

	if bool(
		normalized_context.get(
			"include_modded",
			true
		)
	):
		for raw_mod_object in _global_mod_object_rows(
			actor,
			normalized_context
		):
			if typeof(
				raw_mod_object
			) != TYPE_DICTIONARY:
				continue

			var mod_provider: Dictionary = {
				"provider_id": str(
					(
						raw_mod_object as Dictionary
					).get(
						"provider_id",
						"eralife.mod.objects"
					)
				),
				"domains": _string_array(
					(
						raw_mod_object as Dictionary
					).get(
						"object_domains",
						[]
					)
				),
				"read_only": true,
				"modded": true
			}
			var normalized_mod_object: Dictionary = _normalize_object_contract(
				raw_mod_object as Dictionary,
				mod_provider,
				normalized_context
			)

			if normalized_mod_object.is_empty():
				continue

			_merge_object_into_index(
				merged_index,
				merge_order,
				normalized_mod_object
			)

	_enrich_instance_objects_with_definitions(
		merged_index,
		merge_order
	)

	var filtered: Array = []

	for merge_key in merge_order:
		var object_contract: Dictionary = _safe_dictionary(
			merged_index.get(
				merge_key,
				{}
			)
		)

		if object_contract.is_empty():
			continue

		object_contract = _attach_belongings_history(
			object_contract,
			actor,
			normalized_context
		)

		if not _object_matches_query(
			object_contract,
			normalized_context
		):
			continue

		filtered.append(
			object_contract
		)

	filtered.sort_custom(
		Callable(
			self,
			"_sort_objects"
		)
	)

	var limit: int = clampi(
		int(
			normalized_context.get(
				"limit",
				MAX_OBJECTS_PER_QUERY
			)
		),
		1,
		MAX_OBJECTS_PER_QUERY
	)

	if filtered.size() > limit:
		filtered = filtered.slice(
			0,
			limit
		)

	last_query_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "global_object_catalog_query",
		"actor_id": int(
			normalized_context.get(
				"actor_id",
				-1
			)
		),
		"raw_object_count": raw_object_count,
		"merged_object_count": merge_order.size(),
		"returned_object_count": filtered.size(),
		"provider_reports": provider_reports,
		"registry_revision": registry_revision,
		"query": normalized_context.duplicate(true),
		"read_only": true,
		"projected_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return filtered


func resolve_object(
	object_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_id: String = str(
		object_id
	).strip_edges().to_lower()

	if clean_id == "":
		last_resolution_report = _failure(
			"missing_object_id",
			"An object id is required."
		)
		return {}

	var query: Dictionary = context.duplicate(true)
	query ["limit"] = MAX_OBJECTS_PER_QUERY

	for raw_object in get_available_objects(
		query
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

		if clean_id not in candidate_ids:
			continue

		last_resolution_report = {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"mode": "global_object_resolved",
			"object_id": clean_id,
			"object": object_contract.duplicate(true),
			"read_only": true
		}
		return object_contract.duplicate(true)

	last_resolution_report = _failure(
		"global_object_not_found",
		"No object matched the supplied id and context."
	)
	last_resolution_report ["object_id"] = clean_id
	return {}


func get_object_actions(
	object_id: String,
	context: Dictionary = {}
) -> Array:
	var object_contract: Dictionary = resolve_object(
		object_id,
		context
	)

	if object_contract.is_empty():
		return []

	return _safe_array(
		_safe_dictionary(
			object_contract.get(
				"behavior_contract",
				{}
			)
		).get(
			"actions",
			[]
		)
	)


func get_object_history(
	object_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var object_contract: Dictionary = resolve_object(
		object_id,
		context
	)

	if object_contract.is_empty():
		return _failure(
			"global_object_not_found",
			"No object history is available because the object was not found."
		)

	var history_contract: Dictionary = _safe_dictionary(
		object_contract.get(
			"history_contract",
			{}
		)
	)

	return {
		"success": true,
		"schema": "eralife.global_object_history_contract",
		"version": 1,
		"object_id": str(
			object_contract.get(
				"object_id",
				object_id
			)
		),
		"catalog_object_id": str(
			object_contract.get(
				"catalog_object_id",
				""
			)
		),
		"display_name": str(
			object_contract.get(
				"display_name",
				"Object"
			)
		),
		"history": _safe_array(
			history_contract.get(
				"events",
				[]
			)
		),
		"ownership_chain": _safe_array(
			history_contract.get(
				"ownership_chain",
				_safe_dictionary(
					object_contract.get(
						"ownership_contract",
						{}
					)
				).get(
					"ownership_chain",
					[]
				)
			)
		),
		"origin_contract": _safe_dictionary(
			object_contract.get(
				"origin_contract",
				{}
			)
		),
		"read_only": true,
		"ui_is_renderer_only": true
	}


func emit_object_lens_contract(
	context: Dictionary = {}
) -> Dictionary:
	var objects: Array = get_available_objects(
		context
	)
	var domain_counts: Dictionary = {}

	for raw_object in objects:
		if typeof(
			raw_object
		) != TYPE_DICTIONARY:
			continue

		for raw_domain in _string_array(
			(
				raw_object as Dictionary
			).get(
				"object_domains",
				[]
			)
		):
			domain_counts [raw_domain] = int(
				domain_counts.get(
					raw_domain,
					0
				)
			) + 1

	return {
		"success": true,
		"schema": "eralife.global_object_lens_contract",
		"version": 1,
		"actor_id": int(
			_normalize_context(
				context
			).get(
				"actor_id",
				-1
			)
		),
		"objects": objects,
		"object_count": objects.size(),
		"domain_counts": domain_counts,
		"provider_contracts": provider_contracts(),
		"registry_revision": registry_revision,
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"catalog_is_read_only": true,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func export_state() -> Dictionary:

	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"registry_revision": registry_revision,
		"providers": provider_contracts(),
		"read_only": true
	}


func import_state(
	state: Dictionary
) -> Dictionary:


	var report: Dictionary = bootstrap_default_providers()
	var restored_provider_ids: Array = []

	for raw_provider in _safe_array(
		state.get(
			"providers",
			[]
		)
	):
		if typeof(
			raw_provider
		) != TYPE_DICTIONARY:
			continue

		var provider: Dictionary = _normalize_provider_contract(
			raw_provider as Dictionary
		)

		if provider.is_empty():
			continue

		var provider_id: String = str(
			provider.get(
				"provider_id",
				""
			)
		)

		if provider_id in [
			"eralife.catalog.artifacts",
			"eralife.catalog.heirlooms",
			"eralife.catalog.weapons",
			"eralife.catalog.belongings_instances"
		]:
			continue

		var engine_property: String = str(
			provider.get(
				"engine_property",
				""
			)
		)

		if (
			gs == null
			or gs.get(
				engine_property
			) == null
		):
			continue

		var register_report: Dictionary = register_catalog_provider(
			provider
		)

		if bool(
			register_report.get(
				"success",
				false
			)
		):
			restored_provider_ids.append(
				provider_id
			)

	report ["mode"] = "global_object_catalog_state_rebuilt"
	report ["restored_provider_ids"] = restored_provider_ids
	report ["restored_provider_count"] = restored_provider_ids.size()
	report ["object_truth_imported"] = false
	return report


func _register_first_party_provider(
	provider: Dictionary
) -> void:
	var normalized: Dictionary = _normalize_provider_contract(
		provider
	)

	if normalized.is_empty():
		return

	var provider_id: String = str(
		normalized.get(
			"provider_id",
			""
		)
	)
	provider_registry [provider_id] = normalized
	provider_order.append(
		provider_id
	)
	_sort_provider_order()


func _normalize_provider_contract(
	provider: Dictionary
) -> Dictionary:
	var out: Dictionary = provider.duplicate(true)
	var provider_id: String = str(
		out.get(
			"provider_id",
			""
		)
	).strip_edges()
	var engine_property: String = str(
		out.get(
			"engine_property",
			""
		)
	).strip_edges()
	var method_name: String = str(
		out.get(
			"method",
			"get_available_objects"
		)
	).strip_edges()

	if (
		provider_id == ""
		or engine_property == ""
		or method_name == ""
	):
		return {}

	out ["schema"] = PROVIDER_SCHEMA
	out ["version"] = int(
		out.get(
			"version",
			1
		)
	)
	out ["provider_id"] = provider_id
	out ["engine_property"] = engine_property
	out ["method"] = method_name
	out ["domains"] = _string_array(
		out.get(
			"domains",
			[]
		)
	)
	out ["priority"] = int(
		out.get(
			"priority",
			100
		)
	)
	out ["read_only"] = true
	return out


func _sort_provider_order() -> void:
	provider_order.sort_custom(
		func (
			left,
			right
		) -> bool:
			var left_provider: Dictionary = _safe_dictionary(
				provider_registry.get(
					left,
					{}
				)
			)
			var right_provider: Dictionary = _safe_dictionary(
				provider_registry.get(
					right,
					{}
				)
			)
			var left_priority: int = int(
				left_provider.get(
					"priority",
					100
				)
			)
			var right_priority: int = int(
				right_provider.get(
					"priority",
					100
				)
			)

			if left_priority == right_priority:
				return str(
					left
				) < str(
					right
				)

			return left_priority < right_priority
	)


func _emit_provider_objects(
	provider: Dictionary,
	actor: Person,
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"objects": []
		}

	var engine_property: String = str(
		provider.get(
			"engine_property",
			""
		)
	)
	var adapter: String = str(
		provider.get(
			"adapter",
			""
		)
	)
	var engine: Variant = gs.get(
		engine_property
	)

	if engine == null:
		return {
			"success": false,
			"reason": "object_catalog_provider_engine_unavailable",
			"engine_property": engine_property,
			"objects": []
		}

	if adapter == "belongings_inventory":
		return {
			"success": true,
			"objects": _belongings_instance_objects(
				actor,
				context
			)
		}

	var method_name: String = str(
		provider.get(
			"method",
			"get_available_objects"
		)
	)

	if not engine.has_method(
		method_name
	):
		return {
			"success": false,
			"reason": "object_catalog_provider_method_unavailable",
			"engine_property": engine_property,
			"method": method_name,
			"objects": []
		}

	var raw_result: Variant = engine.call(
		method_name,
		context
	)

	if typeof(
		raw_result
	) != TYPE_ARRAY:
		return {
			"success": false,
			"reason": "object_catalog_provider_returned_invalid_type",
			"engine_property": engine_property,
			"method": method_name,
			"returned_type": typeof(
				raw_result
			),
			"objects": []
		}

	return {
		"success": true,
		"objects": (
			raw_result as Array
		).duplicate(true)
	}


func _belongings_instance_objects(
	actor: Person,
	context: Dictionary
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
		).strip_edges()

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

			var item: Dictionary = (
				raw_item as Dictionary
			).duplicate(true)
			item ["owner_id"] = int(
				actor.id
			)
			item ["belongings_category"] = category
			out.append(
				_object_contract_from_belonging(
					item,
					context
				)
			)

	return out


func _object_contract_from_belonging(
	item: Dictionary,
	context: Dictionary
) -> Dictionary:
	var display_name: String = str(
		item.get(
			"display_name",
			item.get(
				"name",
				"Object"
			)
		)
	).strip_edges()
	var numeric_id: int = int(
		item.get(
			"id",
			-1
		)
	)
	var inferred_domain: String = _infer_domain(
		item,
		str(
			item.get(
				"belongings_category",
				""
			)
		)
	)
	var domains: Array = _string_array(
		item.get(
			"object_domains",
			[]
		)
	)

	if inferred_domain not in domains:
		domains.append(
			inferred_domain
		)

	var catalog_object_id: String = str(
		item.get(
			"catalog_object_id",
			"%s:%s" % [
				inferred_domain,
				_slug(
					display_name
				)
			]
		)
	).strip_edges().to_lower()
	var instance_object_id: String = str(
		item.get(
			"instance_object_id",
			(
				"object_instance:%d"
				if numeric_id > 0
				else "object_instance:%s:%d" % [
					_slug(
						display_name
					),
					abs(
						hash(
							item
						)
					)
				]
			)
		)
	).strip_edges().to_lower()
	var actions: Array = _safe_array(
		item.get(
			"actions",
			[]
		)
	)
	var ownership_chain: Array = _safe_array(
		item.get(
			"ownership_chain",
			[]
		)
	)
	var owner_id: int = int(
		item.get(
			"owner_id",
			context.get(
				"actor_id",
				-1
			)
		)
	)

	if (
		ownership_chain.is_empty()
		and owner_id > 0
	):
		ownership_chain.append({
			"owner_id": owner_id,
			"acquired_year": int(
				item.get(
					"acquired_year",
					context.get(
						"year",
						0
					)
				)
			),
			"mode": "current_owner"
		})

	return {
		"schema": OBJECT_SCHEMA,
		"version": OBJECT_VERSION,
		"object_id": instance_object_id,
		"catalog_object_id": catalog_object_id,
		"instance_object_id": instance_object_id,
		"display_name": display_name,
		"object_domains": domains,
		"primary_domain": inferred_domain,
		"asset_kind": str(
			item.get(
				"asset_kind",
				item.get(
					"type",
					inferred_domain
				)
			)
		).strip_edges().to_lower(),
		"description": str(
			item.get(
				"description",
				item.get(
					"ability",
					""
				)
			)
		),
		"lore": str(
			item.get(
				"lore",
				""
			)
		),
		"value_contract": {
			"base_value": float(
				item.get(
					"value",
					item.get(
						"cost",
						0
					)
				)
			),
			"historical_value": float(
				item.get(
					"historical_value",
					0.0
				)
			),
			"cultural_value": float(
				item.get(
					"cultural_value",
					0.0
				)
			)
		},
		"origin_contract": {
			"era": str(
				item.get(
					"origin_era",
					context.get(
						"era",
						""
					)
				)
			),
			"year": int(
				item.get(
					"origin_year",
					item.get(
						"acquired_year",
						context.get(
							"year",
							0
						)
					)
				)
			),
			"country": str(
				item.get(
					"origin_country",
					context.get(
						"country",
						""
					)
				)
			),
			"city": str(
				item.get(
					"origin_city",
					context.get(
						"city",
						""
					)
				)
			),
			"source_event_id": str(
				item.get(
					"source_event_id",
					""
				)
			)
		},
		"ownership_contract": {
			"owned": owner_id > 0,
			"owner_id": owner_id,
			"ownership_chain": ownership_chain,
			"transferable": bool(
				item.get(
					"transferable",
					true
				)
			),
			"inheritable": bool(
				item.get(
					"inheritable",
					true
				)
			)
		},
		"legal_contract": {
			"legal": bool(
				item.get(
					"legal",
					true
				)
			),
			"classification": str(
				item.get(
					"legal_classification",
					inferred_domain
				)
			),
			"stolen": bool(
				item.get(
					"stolen",
					false
				)
			)
		},
		"behavior_contract": {
			"actions": actions,
			"action_count": actions.size(),
			"mutation_authority": str(
				item.get(
					"mutation_authority",
					_domain_truth_engine(
						inferred_domain
					)
				)
			),
			"catalog_is_read_only": true
		},
		"history_contract": {
			"events": _safe_array(
				item.get(
					"history",
					item.get(
						"object_history",
						[]
					)
				)
			),
			"ownership_chain": ownership_chain,
			"narrative_anchor": true
		},
		"reality_contract": _safe_dictionary(
			item.get(
				"reality_identity",
				item.get(
					"reality_contract",
					{}
				)
			)
		),
		"provider_contract": {
			"provider_id": "eralife.catalog.belongings_instances",
			"source_kind": "belongings_instance",
			"truth_engine_property": "belongings_engine",
			"read_only": true
		},
		"source_payload": item.duplicate(true),
		"object_is_first_class": true,
		"catalog_is_read_only": true,
		"ui_is_renderer_only": true
	}


func _global_mod_object_rows(
	actor: Person,
	context: Dictionary
) -> Array:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows"
		)
	):
		return []

	return _safe_array(
		gs.mod_contract_engine.emit_provider_rows(
			"objects",
			actor,
			context
		)
	)


func _normalize_object_contract(
	raw_object: Dictionary,
	provider: Dictionary,
	context: Dictionary
) -> Dictionary:
	var out: Dictionary = raw_object.duplicate(true)
	var display_name: String = str(
		out.get(
			"display_name",
			out.get(
				"name",
				"Object"
			)
		)
	).strip_edges()
	var domains: Array = _string_array(
		out.get(
			"object_domains",
			out.get(
				"domains",
				provider.get(
					"domains",
					[]
				)
			)
		)
	)
	var primary_domain: String = str(
		out.get(
			"primary_domain",
			(
				domains [0]
				if not domains.is_empty()
				else _infer_domain(
					out,
					""
				)
			)
		)
	).strip_edges().to_lower()

	if primary_domain == "":
		primary_domain = "object"

	if primary_domain not in domains:
		domains.append(
			primary_domain
		)

	var catalog_object_id: String = str(
		out.get(
			"catalog_object_id",
			out.get(
				"object_id",
				"%s:%s" % [
					primary_domain,
					_slug(
						display_name
					)
				]
			)
		)
	).strip_edges().to_lower()
	var instance_object_id: String = str(
		out.get(
			"instance_object_id",
			""
		)
	).strip_edges().to_lower()
	var object_id: String = str(
		out.get(
			"object_id",
			(
				instance_object_id
				if instance_object_id != ""
				else catalog_object_id
			)
		)
	).strip_edges().to_lower()

	if (
		catalog_object_id == ""
		or object_id == ""
	):
		return {}

	out ["schema"] = OBJECT_SCHEMA
	out ["version"] = int(
		out.get(
			"version",
			OBJECT_VERSION
		)
	)
	out ["object_id"] = object_id
	out ["catalog_object_id"] = catalog_object_id
	out ["instance_object_id"] = instance_object_id
	out ["display_name"] = display_name
	out ["object_domains"] = domains
	out ["primary_domain"] = primary_domain
	var origin_contract: Dictionary = _safe_dictionary(
		out.get(
			"origin_contract",
			out.get(
				"origin",
				{}
			)
		)
	)
	var ownership_contract: Dictionary = _safe_dictionary(
		out.get(
			"ownership_contract",
			out.get(
				"ownership",
				{}
			)
		)
	)
	if not ownership_contract.has(
		"owned"
	):
		ownership_contract ["owned"] = bool(
			out.get(
				"owned",
				false
			)
		)
	if not ownership_contract.has(
		"owner_id"
	):
		ownership_contract ["owner_id"] = int(
			out.get(
				"owner_id",
				-1
			)
		)
	if not ownership_contract.has(
		"ownership_chain"
	):
		ownership_contract ["ownership_chain"] = _safe_array(
			ownership_contract.get(
				"chain",
				out.get(
					"ownership_chain",
					[]
				)
			)
		)
	var legal_contract: Dictionary = _safe_dictionary(
		out.get(
			"legal_contract",
			out.get(
				"legal",
				{}
			)
		)
	)
	if not legal_contract.has(
		"legal"
	):
		legal_contract ["legal"] = true
	var behavior_contract: Dictionary = _safe_dictionary(
		out.get(
			"behavior_contract",
			{}
		)
	)
	if not behavior_contract.has(
		"actions"
	):
		behavior_contract ["actions"] = _safe_array(
			out.get(
				"actions",
				[]
			)
		)
	if not behavior_contract.has(
		"providers"
	):
		behavior_contract ["providers"] = _safe_array(
			out.get(
				"behavior_providers",
				[]
			)
		)
	var history_contract: Dictionary = _safe_dictionary(
		out.get(
			"history_contract",
			{}
		)
	)
	if not history_contract.has(
		"events"
	):
		history_contract ["events"] = _safe_array(
			out.get(
				"history",
				out.get(
					"object_history",
					[]
				)
			)
		)
	if not history_contract.has(
		"ownership_chain"
	):
		history_contract ["ownership_chain"] = _safe_array(
			ownership_contract.get(
				"ownership_chain",
				[]
			)
		)
	out ["origin_contract"] = origin_contract
	out ["ownership_contract"] = ownership_contract
	out ["legal_contract"] = legal_contract
	out ["behavior_contract"] = _normalize_behavior_contract(
		behavior_contract,
		primary_domain
	)
	out ["history_contract"] = _normalize_history_contract(
		history_contract
	)
	var reality_source: Dictionary = _safe_dictionary(
		out.get(
			"reality_contract",
			{}
		)
	)
	if reality_source.is_empty():
		reality_source = origin_contract.duplicate(true)
	out ["reality_contract"] = _normalize_reality_contract(
		reality_source,
		context
	)
	var provider_contract: Dictionary = _safe_dictionary(
		out.get(
			"provider_contract",
			{}
		)
	)
	if provider_contract.is_empty():
		var provider_ids: Array = _string_array(
			out.get(
				"provider_ids",
				[]
			)
		)
		provider_contract = {
			"provider_ids": provider_ids,
			"source_kind": str(
				out.get(
					"source_kind",
					"catalog_definition"
				)
			),
			"modded": bool(
				out.get(
					"modded",
					false
				)
			)
		}
	provider_contract ["provider_id"] = str(
		provider_contract.get(
			"provider_id",
			provider.get(
				"provider_id",
				"unknown_object_provider"
			)
		)
	)
	provider_contract ["read_only"] = true
	provider_contract ["modded"] = bool(
		provider_contract.get(
			"modded",
			provider.get(
				"modded",
				false
			)
		)
	)
	out ["provider_contract"] = provider_contract
	out ["object_is_first_class"] = true
	out ["catalog_is_read_only"] = true
	out ["ui_is_renderer_only"] = true
	return out


func _normalize_behavior_contract(
	behavior: Dictionary,
	primary_domain: String
) -> Dictionary:
	var out: Dictionary = behavior.duplicate(true)
	var actions: Array = _safe_array(
		out.get(
			"actions",
			[]
		)
	)
	out ["actions"] = actions
	out ["action_count"] = actions.size()
	out ["mutation_authority"] = str(
		out.get(
			"mutation_authority",
			_domain_truth_engine(
				primary_domain
			)
		)
	)
	out ["catalog_is_read_only"] = true
	return out


func _normalize_history_contract(
	history: Dictionary
) -> Dictionary:
	var out: Dictionary = history.duplicate(true)
	out ["events"] = _safe_array(
		out.get(
			"events",
			[]
		)
	)
	out ["ownership_chain"] = _safe_array(
		out.get(
			"ownership_chain",
			[]
		)
	)
	out ["event_count"] = (
		out ["events"] as Array
	).size()
	out ["narrative_anchor"] = bool(
		out.get(
			"narrative_anchor",
			true
		)
	)
	return out


func _normalize_reality_contract(
	reality: Dictionary,
	context: Dictionary
) -> Dictionary:
	var out: Dictionary = reality.duplicate(true)

	for key in [
		"era",
		"country",
		"city",
		"location_id",
		"reality_signature",
		"reality_mode"
	]:
		if str(
			out.get(
				key,
				""
			)
		).strip_edges() == "":
			out [key] = context.get(
				key,
				""
			)

	return out


func _merge_object_into_index(
	index: Dictionary,
	order: Array,
	object_contract: Dictionary
) -> void:
	var key: String = _object_merge_key(
		object_contract
	)

	if key == "":
		return

	if not index.has(
		key
	):
		index [key] = object_contract.duplicate(true)
		order.append(
			key
		)
		return

	index [key] = _merge_object_contracts(
		_safe_dictionary(
			index.get(
				key,
				{}
			)
		),
		object_contract
	)


func _enrich_instance_objects_with_definitions(
	index: Dictionary,
	order: Array
) -> void:
	var definitions_by_catalog_id: Dictionary = {}

	for merge_key in order:
		var object_contract: Dictionary = _safe_dictionary(
			index.get(
				merge_key,
				{}
			)
		)

		if object_contract.is_empty():
			continue

		var instance_id: String = str(
			object_contract.get(
				"instance_object_id",
				""
			)
		).strip_edges().to_lower()
		var catalog_id: String = str(
			object_contract.get(
				"catalog_object_id",
				""
			)
		).strip_edges().to_lower()

		if (
			instance_id == ""
			and catalog_id != ""
		):
			definitions_by_catalog_id [catalog_id] = (
				object_contract.duplicate(true)
			)

	for merge_key in order:
		var instance_contract: Dictionary = _safe_dictionary(
			index.get(
				merge_key,
				{}
			)
		)

		if instance_contract.is_empty():
			continue

		var instance_id: String = str(
			instance_contract.get(
				"instance_object_id",
				""
			)
		).strip_edges().to_lower()
		var catalog_id: String = str(
			instance_contract.get(
				"catalog_object_id",
				""
			)
		).strip_edges().to_lower()

		if (
			instance_id == ""
			or catalog_id == ""
			or not definitions_by_catalog_id.has(
				catalog_id
			)
		):
			continue

		var definition: Dictionary = _safe_dictionary(
			definitions_by_catalog_id.get(
				catalog_id,
				{}
			)
		)
		var enriched: Dictionary = _merge_object_contracts(
			definition,
			instance_contract
		)
		enriched ["object_id"] = instance_id
		enriched ["instance_object_id"] = instance_id
		enriched ["catalog_object_id"] = catalog_id
		enriched ["catalog_definition_enriched"] = true
		index [merge_key] = enriched


func _object_merge_key(
	object_contract: Dictionary
) -> String:
	var instance_id: String = str(
		object_contract.get(
			"instance_object_id",
			""
		)
	).strip_edges().to_lower()

	if instance_id != "":
		return instance_id

	return str(
		object_contract.get(
			"catalog_object_id",
			object_contract.get(
				"object_id",
				""
			)
		)
	).strip_edges().to_lower()


func _merge_object_contracts(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in overlay.keys():
		var overlay_value: Variant = overlay.get(
			key
		)
		var base_value: Variant = out.get(
			key
		)

		if key in [
			"object_domains"
		]:
			var merged_strings: Array = _string_array(
				base_value
			)

			for raw_value in _string_array(
				overlay_value
			):
				if raw_value not in merged_strings:
					merged_strings.append(
						raw_value
					)

			out [key] = merged_strings
		elif key == "behavior_contract":
			out [key] = _merge_behavior_contracts(
				_safe_dictionary(
					base_value
				),
				_safe_dictionary(
					overlay_value
				)
			)
		elif key == "history_contract":
			out [key] = _merge_history_contracts(
				_safe_dictionary(
					base_value
				),
				_safe_dictionary(
					overlay_value
				)
			)
		elif (
			typeof(
				base_value
			) == TYPE_DICTIONARY
			and typeof(
				overlay_value
			) == TYPE_DICTIONARY
		):
			var merged_dictionary: Dictionary = _safe_dictionary(
				base_value
			)

			for nested_key in (
				overlay_value as Dictionary
			).keys():
				merged_dictionary [nested_key] = (
					overlay_value as Dictionary
				) [nested_key]

			out [key] = merged_dictionary
		elif _value_is_meaningful(
			overlay_value
		):
			out [key] = overlay_value

	out ["catalog_is_read_only"] = true
	out ["ui_is_renderer_only"] = true
	return out


func _merge_behavior_contracts(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var action_index: Dictionary = {}
	var action_order: Array = []

	for source_actions in [
		_safe_array(
			base.get(
				"actions",
				[]
			)
		),
		_safe_array(
			overlay.get(
				"actions",
				[]
			)
		)
	]:
		for raw_action in source_actions:
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
				action_id = "action_%d" % abs(
					hash(
						action
					)
				)

			if action_id not in action_order:
				action_order.append(
					action_id
				)

			action_index [action_id] = action

	var actions: Array = []

	for action_id in action_order:
		actions.append(
			_safe_dictionary(
				action_index.get(
					action_id,
					{}
				)
			)
		)

	for key in overlay.keys():
		if key != "actions":
			out [key] = overlay [key]

	out ["actions"] = actions
	out ["action_count"] = actions.size()
	out ["catalog_is_read_only"] = true
	return out


func _merge_history_contracts(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var events: Array = []
	var seen: Dictionary = {}

	for source_events in [
		_safe_array(
			base.get(
				"events",
				[]
			)
		),
		_safe_array(
			overlay.get(
				"events",
				[]
			)
		)
	]:
		for raw_event in source_events:
			if typeof(
				raw_event
			) != TYPE_DICTIONARY:
				continue

			var event: Dictionary = (
				raw_event as Dictionary
			).duplicate(true)
			var signature: String = str(
				event.get(
					"event_id",
					event.get(
						"id",
						abs(
							hash(
								event
							)
						)
					)
				)
			)

			if seen.has(
				signature
			):
				continue

			seen [signature] = true
			events.append(
				event
			)

	var ownership_chain: Array = _safe_array(
		base.get(
			"ownership_chain",
			[]
		)
	)

	for raw_owner in _safe_array(
		overlay.get(
			"ownership_chain",
			[]
		)
	):
		if raw_owner not in ownership_chain:
			ownership_chain.append(
				raw_owner
			)

	for key in overlay.keys():
		if key not in [
			"events",
			"ownership_chain"
		]:
			out [key] = overlay [key]

	out ["events"] = events
	out ["event_count"] = events.size()
	out ["ownership_chain"] = ownership_chain
	out ["narrative_anchor"] = true
	return out


func _attach_belongings_history(
	object_contract: Dictionary,
	actor: Person,
	_context: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.belongings_engine == null
		or not gs.belongings_engine.has_method(
			"export_state"
		)
	):
		return object_contract

	var instance_id: String = str(
		object_contract.get(
			"instance_object_id",
			""
		)
	).strip_edges().to_lower()
	var numeric_item_id: int = _numeric_item_id_from_instance(
		instance_id,
		object_contract
	)

	if numeric_item_id <= 0:
		return object_contract

	var exported: Dictionary = _safe_dictionary(
		gs.belongings_engine.export_state()
	)
	var candidate_ledgers: Array = []

	candidate_ledgers.append_array(
		_safe_array(
			exported.get(
				"ledger",
				[]
			)
		)
	)
	candidate_ledgers.append_array(
		_safe_array(
			exported.get(
				"belongings_ledger",
				[]
			)
		)
	)
	var world_state: Dictionary = _safe_dictionary(
		exported.get(
			"world_state",
			{}
		)
	)
	candidate_ledgers.append_array(
		_safe_array(
			world_state.get(
				"belongings_ledger",
				[]
			)
		)
	)
	candidate_ledgers.append_array(
		_safe_array(
			world_state.get(
				"object_myth_ledger",
				[]
			)
		)
	)

	var object_events: Array = []

	for raw_event in candidate_ledgers:
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = (
			raw_event as Dictionary
		)
		var event_item_id: int = int(
			event.get(
				"item_id",
				_safe_dictionary(
					event.get(
					"item",
					{}
				)
				).get(
					"id",
					-1
				)
			)
		)

		if event_item_id != numeric_item_id:
			continue

		if (
			actor != null
			and int(
				event.get(
					"owner_id",
					actor.id
				)
			) != int(
				actor.id
			)
			and not bool(
				event.get(
					"public_history",
					false
				)
			)
		):
			continue

		object_events.append(
			event.duplicate(true)
		)

	if object_events.is_empty():
		return object_contract

	var out: Dictionary = object_contract.duplicate(true)
	var history: Dictionary = _safe_dictionary(
		out.get(
			"history_contract",
			{}
		)
	)
	history = _merge_history_contracts(
		history,
		{
			"events": object_events
		}
	)
	out ["history_contract"] = history
	return out


func _numeric_item_id_from_instance(
	instance_id: String,
	object_contract: Dictionary
) -> int:
	var clean_id: String = str(
		instance_id
	).strip_edges().to_lower()

	if clean_id.begins_with(
		"object_instance:"
	):
		var tail: String = clean_id.trim_prefix(
			"object_instance:"
		)

		if tail.is_valid_int():
			return int(
				tail
			)

	return int(
		_safe_dictionary(
			object_contract.get(
				"source_payload",
				{}
			)
		).get(
			"id",
			-1
		)
	)


func _provider_matches_query(
	provider: Dictionary,
	context: Dictionary
) -> bool:
	var requested_domains: Array = _requested_domains(
		context
	)

	if requested_domains.is_empty():
		return true

	var provider_domains: Array = _string_array(
		provider.get(
			"domains",
			[]
		)
	)

	if "owned_object" in provider_domains:
		return true

	for domain in requested_domains:
		if domain in provider_domains:
			return true

	return false


func _object_matches_query(
	object_contract: Dictionary,
	context: Dictionary
) -> bool:
	var requested_domains: Array = _requested_domains(
		context
	)
	var object_domains: Array = _string_array(
		object_contract.get(
			"object_domains",
			[]
		)
	)

	if not requested_domains.is_empty():
		var domain_match: bool = false

		for domain in requested_domains:
			if domain in object_domains:
				domain_match = true
				break

		if not domain_match:
			return false

	var reality: Dictionary = _safe_dictionary(
		object_contract.get(
			"reality_contract",
			{}
		)
	)
	var requested_era: String = str(
		context.get(
			"era",
			""
		)
	).strip_edges().to_lower()
	var object_era: String = str(
		reality.get(
			"era",
			_safe_dictionary(
				object_contract.get(
					"origin_contract",
					{}
				)
			).get(
				"era",
				""
			)
		)
	).strip_edges().to_lower()

	if (
		requested_era != ""
		and object_era != ""
		and object_era != requested_era
		and not bool(
			reality.get(
				"cross_era_available",
				false
			)
		)
	):
		return false

	for location_key in [
		"country",
		"city",
		"location_id"
	]:
		var requested_location: String = str(
			context.get(
				location_key,
				""
			)
		).strip_edges().to_lower()
		var object_location: String = str(
			reality.get(
				location_key,
				""
			)
		).strip_edges().to_lower()

		if (
			requested_location != ""
			and object_location != ""
			and object_location != requested_location
			and not bool(
				reality.get(
					"globally_available",
					false
				)
			)
		):
			return false

	var ownership: Dictionary = _safe_dictionary(
		object_contract.get(
			"ownership_contract",
			{}
		)
	)
	var owned: bool = bool(
		ownership.get(
			"owned",
			false
		)
	)
	var owner_id: int = int(
		ownership.get(
			"owner_id",
			-1
		)
	)
	var actor_id: int = int(
		context.get(
			"actor_id",
			-1
		)
	)
	var ownership_scope: String = str(
		context.get(
			"ownership_scope",
			"all"
		)
	).strip_edges().to_lower()

	match ownership_scope:
		"owned":
			if not owned or owner_id != actor_id:
				return false
		"unowned", "available":
			if owned and owner_id == actor_id:
				return false
		"owned_or_available":
			pass
		_:
			pass

	var legal: Dictionary = _safe_dictionary(
		object_contract.get(
			"legal_contract",
			{}
		)
	)

	if (
		bool(
			context.get(
				"legal_only",
				false
			)
		)
		and not bool(
			legal.get(
				"legal",
				true
			)
		)
	):
		return false

	if (
		not bool(
			context.get(
				"include_illegal",
				true
			)
		)
		and not bool(
			legal.get(
				"legal",
				true
			)
		)
	):
		return false

	var provider: Dictionary = _safe_dictionary(
		object_contract.get(
			"provider_contract",
			{}
		)
	)

	if (
		not bool(
			context.get(
				"include_modded",
				true
			)
		)
		and bool(
			provider.get(
				"modded",
				false
			)
		)
	):
		return false

	var required_tags: Array = _string_array(
		context.get(
			"required_tags",
			[]
		)
	)
	var object_tags: Array = _string_array(
		object_contract.get(
			"tags",
			_safe_dictionary(
				object_contract.get(
					"source_payload",
					{}
				)
			).get(
				"contract_tags",
				[]
			)
		)
	)

	for required_tag in required_tags:
		if required_tag not in object_tags:
			return false

	return true


func _requested_domains(
	context: Dictionary
) -> Array:
	var domains: Array = _string_array(
		context.get(
			"domains",
			[]
		)
	)
	var single_domain: String = str(
		context.get(
			"domain",
			""
		)
	).strip_edges().to_lower()

	if (
		single_domain != ""
		and single_domain not in domains
	):
		domains.append(
			single_domain
		)

	return domains


func _sort_objects(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_owned: bool = bool(
		_safe_dictionary(
			left.get(
				"ownership_contract",
				{}
			)
		).get(
			"owned",
			false
		)
	)
	var right_owned: bool = bool(
		_safe_dictionary(
			right.get(
				"ownership_contract",
				{}
			)
		).get(
			"owned",
			false
		)
	)

	if left_owned != right_owned:
		return left_owned

	var left_domain: String = str(
		left.get(
			"primary_domain",
			"object"
		)
	)
	var right_domain: String = str(
		right.get(
			"primary_domain",
			"object"
		)
	)

	if left_domain != right_domain:
		return left_domain < right_domain

	return str(
		left.get(
			"display_name",
			""
		)
	).to_lower() < str(
		right.get(
			"display_name",
			""
		)
	).to_lower()


func _normalize_context(
	context: Dictionary
) -> Dictionary:
	var out: Dictionary = context.duplicate(true)

	if not out.has(
		"actor_id"
	):
		out ["actor_id"] = (
			int(
				gs.player.id
			)
			if (
				gs != null
				and gs.player != null
			)
			else -1
		)

	if str(
		out.get(
			"era",
			""
		)
	).strip_edges() == "":
		out ["era"] = _current_era_name()

	if not out.has(
		"year"
	):
		out ["year"] = (
			int(
				gs.year
			)
			if gs != null
			else 0
		)

	if not out.has(
		"include_modded"
	):
		out ["include_modded"] = true

	if not out.has(
		"include_catalog_definitions"
	):
		out ["include_catalog_definitions"] = true

	if not out.has(
		"include_owned_instances"
	):
		out ["include_owned_instances"] = true

	if not out.has(
		"include_illegal"
	):
		out ["include_illegal"] = true

	if not out.has(
		"ownership_scope"
	):
		out ["ownership_scope"] = "all"

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
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if (
		actor_id > 0
		and gs.has_method(
			"get_npc_by_id"
		)
	):
		var actor: Variant = gs.get_npc_by_id(
			actor_id
		)

		if actor is Person:
			return actor as Person

	return null


func _infer_domain(
	item: Dictionary,
	category: String
) -> String:
	var clean_category: String = str(
		category
	).strip_edges().to_lower()
	var asset_kind: String = str(
		item.get(
			"asset_kind",
			item.get(
				"type",
				clean_category
			)
		)
	).strip_edges().to_lower()

	if (
		clean_category.find(
			"weapon"
		) >= 0
		or asset_kind in [
			"weapon",
			"blade",
			"gun",
			"ranged",
			"energy"
		]
	):
		return "weapon"

	if (
		clean_category.find(
			"heirloom"
		) >= 0
		or bool(
			item.get(
				"lineage_bound",
				false
			)
		)
		or int(
			item.get(
				"inheritance_count",
				0
			)
		) > 0
	):
		return "heirloom"

	if (
		clean_category.find(
			"artifact"
		) >= 0
		or asset_kind in [
			"artifact",
			"relic",
			"stone"
		]
	):
		return "artifact"

	return (
		asset_kind
		if asset_kind != ""
		else "object"
	)


func _domain_truth_engine(
	domain: String
) -> String:
	match str(
		domain
	).strip_edges().to_lower():
		"weapon":
			return "weapons_engine"
		"artifact":
			return "artifacts_engine"
		"heirloom":
			return "heirloom_engine"
		_:
			return "belongings_engine"


func _current_era_name() -> String:
	if (
		gs != null
		and gs.era != null
	):
		return str(
			gs.era.name
		)

	return "Modern Era"


func _value_is_meaningful(
	value: Variant
) -> bool:
	match typeof(
		value
	):
		TYPE_NIL:
			return false
		TYPE_STRING, TYPE_STRING_NAME:
			return str(
				value
			).strip_edges() != ""
		TYPE_ARRAY:
			return not (
				value as Array
			).is_empty()
		TYPE_DICTIONARY:
			return not (
				value as Dictionary
			).is_empty()
		_:
			return true


func _slug(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"\\",
		":",
		".",
		",",
		"'",
		"\""
	]:
		clean = clean.replace(
			token,
			"_"
		)

	while "__" in clean:
		clean = clean.replace(
			"__",
			"_"
		)

	return clean.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)


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
		"catalog_is_read_only": true,
		"ui_is_renderer_only": true
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


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