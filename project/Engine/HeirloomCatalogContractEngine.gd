

extends RefCounted
class_name HeirloomCatalogContractEngine

const ENGINE_SCHEMA:= "eralife.heirloom_catalog_contract_engine"
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
		"provider_id": "eralife.catalog.heirlooms",
		"domains": [
			"heirloom"
		],
		"truth_engine_property": (
			"heirloom_runtime_engine"
		),
		"constitutional_engine_property": (
			"heirloom_contract_engine"
		),
		"compatibility_facade_property": (
			"heirloom_engine"
		),
		"ownership_truth_engine_property": (
			"belongings_engine"
		),
		"mod_provider_types": [
			"heirlooms",
			"objects"
		],
		"read_only": true,
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)


func provider_contract() -> Dictionary:
	return {
		"schema": (
			"eralife.object_catalog_provider_contract"
		),
		"version": 1,
		"provider_id": "eralife.catalog.heirlooms",
		"engine_property": (
			"heirloom_catalog_contract_engine"
		),
		"method": "get_available_objects",
		"domains": [
			"heirloom"
		],
		"priority": 210,
		"read_only": true,
		"truth_engine_property": (
			"heirloom_runtime_engine"
		),
		"constitutional_engine_property": (
			"heirloom_contract_engine"
		),
		"compatibility_facade_property": (
			"heirloom_engine"
		),
	}


func get_available_objects(
	context: Dictionary = {}
) -> Array:
	var normalized_context: Dictionary = _normalize_context(
		context
	)
	var actor: Person = _actor_from_context(
		normalized_context
	)
	var out: Array = []

	for raw_item in _owned_heirloom_rows(
		actor,
		normalized_context
	):
		if typeof(
			raw_item
		) != TYPE_DICTIONARY:
			continue

		var owned_contract: Dictionary = (
			object_contract_for_heirloom(
				raw_item as Dictionary,
				normalized_context,
				"belongings_instance"
			)
		)

		if not owned_contract.is_empty():
			out.append(
				owned_contract
			)

	var runtime_rows: Array = _runtime_heirloom_rows(
		normalized_context
	)

	for raw_runtime_row in runtime_rows:
		if typeof(
			raw_runtime_row
		) != TYPE_DICTIONARY:
			continue

		var runtime_contract: Dictionary = (
			object_contract_for_heirloom(
				raw_runtime_row as Dictionary,
				normalized_context,
				"heirloom_runtime"
			)
		)

		if not runtime_contract.is_empty():
			out.append(
				runtime_contract
			)

	if bool(
		normalized_context.get(
			"include_catalog_definitions",
			true
		)
	):
		for raw_definition in _definition_heirloom_rows(
			normalized_context
		):
			if typeof(
				raw_definition
			) != TYPE_DICTIONARY:
				continue

			var definition_contract: Dictionary = (
				object_contract_for_heirloom(
					raw_definition as Dictionary,
					normalized_context,
					"heirloom_constitution"
				)
			)

			if not definition_contract.is_empty():
				out.append(
					definition_contract
				)



	if runtime_rows.is_empty():
		for raw_legacy_row in _legacy_heirloom_rows(
			normalized_context
		):
			if typeof(
				raw_legacy_row
			) != TYPE_DICTIONARY:
				continue

			var legacy_contract: Dictionary = (
				object_contract_for_heirloom(
					raw_legacy_row as Dictionary,
					normalized_context,
					"legacy_heirloom_facade"
				)
			)

			if not legacy_contract.is_empty():
				out.append(
					legacy_contract
				)

	for raw_mod_row in _mod_heirloom_rows(
		actor,
		normalized_context
	):
		if typeof(
			raw_mod_row
		) != TYPE_DICTIONARY:
			continue

		var mod_contract: Dictionary = (
			object_contract_for_heirloom(
				raw_mod_row as Dictionary,
				normalized_context,
				"mod_provider"
			)
		)

		if not mod_contract.is_empty():
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
		"mode": "heirloom_catalog_projection",
		"actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"object_count": out.size(),
		"runtime_record_count": runtime_rows.size(),
		"read_only": true,
		"truth_engine_property": (
			"heirloom_runtime_engine"
		),
		"constitutional_engine_property": (
			"heirloom_contract_engine"
		),
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


func object_contract_for_heirloom(
	raw_object: Dictionary,
	context: Dictionary = {},
	source_kind: String = "heirloom_engine"
) -> Dictionary:
	var source: Dictionary = raw_object.duplicate(true)
	var normalized_context: Dictionary = _normalize_context(
		context
	)
	var display_name: String = str(
		source.get(
			"display_name",
			source.get(
				"name",
				"Heirloom"
			)
		)
	).strip_edges()
	var source_id: String = str(
		source.get(
			"catalog_object_id",
			source.get(
				"object_id",
				source.get(
					"id",
					""
				)
			)
		)
	).strip_edges().to_lower()

	if source_id == "":
		source_id = _slug(
			display_name
		)

	if source_id == "":
		return {}

	var numeric_item_id: int = int(
		source.get(
			"id",
			-1
		)
	)
	var instance_object_id: String = str(
		source.get(
			"instance_object_id",
			""
		)
	).strip_edges().to_lower()

	if (
		instance_object_id == ""
		and numeric_item_id > 0
	):
		instance_object_id = "object_instance:%d" % numeric_item_id

	var catalog_object_id: String = str(
		source.get(
			"catalog_object_id",
			"heirloom:%s" % source_id
		)
	).strip_edges().to_lower()
	var object_id: String = (
		instance_object_id
		if instance_object_id != ""
		else catalog_object_id
	)
	var owner_id: int = int(
		source.get(
			"owner_id",
			normalized_context.get(
				"actor_id",
				-1
			)
		)
	)
	var origin: Dictionary = _origin_contract(
		source,
		normalized_context
	)
	var ownership_chain: Array = _ownership_chain(
		source,
		owner_id,
		origin
	)
	var domains: Array = _string_array(
		source.get(
			"object_domains",
			[]
		)
	)

	for required_domain in [
		"heirloom"
	]:
		if required_domain not in domains:
			domains.append(
				required_domain
			)

	var asset_kind: String = str(
		source.get(
			"asset_kind",
			source.get(
				"type",
				"heirloom"
			)
		)
	).strip_edges().to_lower()

	if asset_kind in [
		"weapon",
		"blade",
		"gun",
		"ranged"
	] and "weapon" not in domains:
		domains.append(
			"weapon"
		)

	if (
		bool(
			source.get(
				"artifact",
				false
			)
		)
		or str(
			source.get(
				"rarity",
				""
			)
		).strip_edges() != ""
	) and "artifact" not in domains:
		domains.append(
			"artifact"
		)

	var lineage_contract: Dictionary = {
		"lineage_bound": true,
		"lineage_id": str(
			source.get(
				"lineage_id",
				source.get(
					"dynasty_id",
					""
				)
			)
		),
		"inheritance_count": maxi(
			0,
			int(
				source.get(
					"inheritance_count",
					maxi(
						0,
						ownership_chain.size() - 1
					)
				)
			)
		),
		"ownership_chain": ownership_chain.duplicate(true),
		"dispute_eligible": bool(
			source.get(
				"inheritance_dispute_eligible",
				ownership_chain.size() > 1
			)
		),
		"relationship_influence": _safe_dictionary(
			source.get(
				"relationship_influence",
				{}
			)
		),
		"reputation_influence": _safe_dictionary(
			source.get(
				"reputation_influence",
				{}
			)
		)
	}
	var history: Array = _history_rows(
		source,
		ownership_chain
	)
	var actions: Array = _action_rows(
		source,
		catalog_object_id
	)
	var provider_id: String = str(
		source.get(
			"provider_id",
			(
				"eralife.mod.heirlooms"
				if source_kind == "mod_provider"
				else "eralife.catalog.heirlooms"
			)
		)
	).strip_edges()

	return {
		"schema": OBJECT_SCHEMA,
		"version": OBJECT_VERSION,
		"object_id": object_id,
		"catalog_object_id": catalog_object_id,
		"instance_object_id": instance_object_id,
		"display_name": display_name,
		"object_domains": domains,
		"primary_domain": "heirloom",
		"asset_kind": asset_kind,
		"description": str(
			source.get(
				"description",
				source.get(
					"ability",
					"A lineage-bound object."
				)
			)
		),
		"lore": str(
			source.get(
				"lore",
				source.get(
					"history_text",
					""
				)
			)
		),
		"value_contract": {
			"base_value": float(
				source.get(
					"base_value",
					source.get(
						"value",
						source.get(
							"cost",
							0
						)
					)
				)
			),
			"historical_value": float(
				source.get(
					"historical_value",
					0.0
				)
			),
			"cultural_value": float(
				source.get(
					"cultural_value",
					0.0
				)
			),
			"lineage_multiplier": 1.0 + minf(
				2.5,
				float(
					lineage_contract.get(
						"inheritance_count",
						0
					)
				) * 0.12
			)
		},
		"origin_contract": origin,
		"ownership_contract": {
			"owned": owner_id > 0,
			"owner_id": owner_id,
			"ownership_chain": ownership_chain.duplicate(true),
			"transferable": bool(
				source.get(
					"transferable",
					true
				)
			),
			"inheritable": true
		},
		"lineage_contract": lineage_contract,
		"legal_contract": _legal_contract(
			source
		),
		"cultural_contract": {
			"culture_id": str(
				source.get(
					"culture_id",
					""
				)
			),
			"status_weight": float(
				source.get(
					"status_weight",
					0.0
				)
			),
			"political_leverage": float(
				source.get(
					"political_leverage",
					0.0
				)
			),
			"theft_interest": clampf(
				float(
					source.get(
						"theft_interest",
						0.18
					)
				),
				0.0,
				1.0
			)
		},
		"behavior_contract": {
			"actions": actions,
			"action_count": actions.size(),
			"interaction_rules": _safe_dictionary(
				source.get(
					"interaction_rules",
					{}
				)
			),
			"mutation_authority": "heirloom_runtime_engine",
			"constitutional_authority": "heirloom_contract_engine",
			"compatibility_facade": "heirloom_engine",
			"catalog_is_read_only": true
		},
		"history_contract": {
			"events": history,
			"event_count": history.size(),
			"ownership_chain": ownership_chain.duplicate(true),
			"narrative_anchor": true
		},
		"reality_contract": _reality_contract(
			source,
			normalized_context
		),
		"provider_contract": {
			"provider_id": provider_id,
			"source_kind": source_kind,
			"truth_engine_property": "heirloom_runtime_engine",
			"ownership_truth_engine_property": "belongings_engine",
			"modded": source_kind == "mod_provider",
			"read_only": true
		},
		"source_payload": source.duplicate(true),
		"object_is_first_class": true,
		"catalog_is_read_only": true,
		"ui_is_renderer_only": true
	}


func _owned_heirloom_rows(
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
		var items: Array = _safe_array(
			inventory.get(
				raw_category,
				[]
			)
		)

		for raw_item in items:
			if typeof(
				raw_item
			) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = (
				raw_item as Dictionary
			).duplicate(true)

			if not _item_is_heirloom_candidate(
				item,
				category,
				context
			):
				continue

			item ["owner_id"] = int(
				actor.id
			)
			item ["belongings_category"] = category
			item ["heirloom_candidate"] = true
			out.append(
				item
			)

	return out

func _runtime_heirloom_rows(
	context: Dictionary
) -> Array:
	if (
		gs == null
		or gs.heirloom_runtime_engine == null
	):
		return []

	var actor_id: int = int(
		context.get(
			"actor_id",
			-1
		)
	)
	var include_unowned: bool = bool(
		context.get(
			"include_unowned",
			true
		)
	)

	if (
		actor_id > 0
		and not include_unowned
	):
		return (
			gs.heirloom_runtime_engine.records_for_actor(
				actor_id,
				{
					"include_archived": false
				}
			)
		)

	var state: Dictionary = _safe_dictionary(
		gs.heirloom_runtime_engine.export_state()
	)
	var records: Dictionary = _safe_dictionary(
		state.get(
			"records",
			{}
		)
	)
	var out: Array = []

	for record_key in records.keys():
		var record: Dictionary = _safe_dictionary(
			records.get(
				record_key,
				{}
			)
		)

		if record.is_empty():
			continue

		if bool(
			record.get(
				"archived",
				false
			)
		):
			continue

		if (
			not include_unowned
			and actor_id > 0
			and int(
				record.get(
					"owner_id",
					-1
				)
			) != actor_id
		):
			continue

		var source_item: Dictionary = _safe_dictionary(
			record.get(
				"source_item",
				{}
			)
		)

		if source_item.is_empty():
			source_item = record.duplicate(true)
		else:
			for key in record.keys():
				if not source_item.has(
					key
				):
					source_item [key] = record [key]

		out.append(
			source_item
		)

	return out


func _definition_heirloom_rows(
	context: Dictionary
) -> Array:
	if (
		gs == null
		or gs.heirloom_contract_engine == null
		or not gs.heirloom_contract_engine.has_method(
			"get_catalog_definitions"
		)
	):
		return []

	return _safe_array(
		gs.heirloom_contract_engine.get_catalog_definitions(
			context
		)
	)
func _legacy_heirloom_rows(
	context: Dictionary
) -> Array:
	if (
		gs == null
		or gs.heirloom_engine == null
	):
		return []

	var raw_registry: Variant = gs.heirloom_engine.get(
		"heirlooms"
	)
	var out: Array = []

	if typeof(
		raw_registry
	) == TYPE_DICTIONARY:
		for raw_owner_id in (
			raw_registry as Dictionary
		).keys():
			var owner_rows: Array = _safe_array(
				(
					raw_registry as Dictionary
				).get(
					raw_owner_id,
					[]
				)
			)

			for raw_row in owner_rows:
				if typeof(
					raw_row
				) != TYPE_DICTIONARY:
					continue

				var row: Dictionary = (
					raw_row as Dictionary
				).duplicate(true)
				row ["owner_id"] = int(
					row.get(
						"owner_id",
						raw_owner_id
					)
				)
				out.append(
					row
				)
	elif typeof(
		raw_registry
	) == TYPE_ARRAY:
		for raw_row in (raw_registry as Array):
			if typeof(
				raw_row
			) == TYPE_DICTIONARY:
				out.append(
					(
						raw_row as Dictionary
					).duplicate(true)
				)

	if not bool(
		context.get(
			"include_unowned",
			true
		)
	):
		var actor_id: int = int(
			context.get(
				"actor_id",
				-1
			)
		)
		var owned_only: Array = []

		for raw_row in out:
			if typeof(
				raw_row
			) != TYPE_DICTIONARY:
				continue

			if int(
				(
					raw_row as Dictionary
				).get(
					"owner_id",
					-1
				)
			) == actor_id:
				owned_only.append(
					raw_row
				)

		return owned_only

	return out


func _mod_heirloom_rows(
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
		"heirlooms",
		"objects"
	]:
		var rows: Array = _safe_array(
			gs.mod_contract_engine.emit_provider_rows(
				provider_type,
				actor,
				context
			)
		)

		for raw_row in rows:
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
				and "heirloom" not in domains
				and not bool(
					row.get(
						"heirloom",
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


func _item_is_heirloom_candidate(
	item: Dictionary,
	category: String,
	context: Dictionary
) -> bool:
	var clean_category: String = str(
		category
	).strip_edges().to_lower()
	var domains: Array = _string_array(
		item.get(
			"object_domains",
			[]
		)
	)

	if (
		"heirloom" in domains
		or clean_category.find(
			"heirloom"
		) >= 0
		or bool(
			item.get(
				"heirloom",
				false
			)
		)
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
		return true

	if not bool(
		context.get(
			"include_heirloom_candidates",
			true
		)
	):
		return false

	var chain: Array = _safe_array(
		item.get(
			"ownership_chain",
			[]
		)
	)
	var object_age: int = maxi(
		0,
		int(
			context.get(
				"year",
				_current_year()
			)
		) - int(
			item.get(
				"acquired_year",
				item.get(
					"origin_year",
					_current_year()
				)
			)
		)
	)

	return (
		chain.size() > 1
		or bool(
			item.get(
				"inheritable",
				false
			)
		)
		and object_age >= 20
	)


func _origin_contract(
	source: Dictionary,
	context: Dictionary
) -> Dictionary:
	return {
		"era": str(
			source.get(
				"origin_era",
				context.get(
					"era",
					_current_era_name()
				)
			)
		),
		"year": int(
			source.get(
				"origin_year",
				source.get(
					"acquired_year",
					context.get(
						"year",
						_current_year()
					)
				)
			)
		),
		"country": str(
			source.get(
				"origin_country",
				context.get(
					"country",
					""
				)
			)
		),
		"city": str(
			source.get(
				"origin_city",
				context.get(
					"city",
					""
				)
			)
		),
		"creator_id": int(
			source.get(
				"creator_id",
				-1
			)
		),
		"source_event_id": str(
			source.get(
				"source_event_id",
				""
			)
		)
	}


func _ownership_chain(
	source: Dictionary,
	owner_id: int,
	origin: Dictionary
) -> Array:
	var chain: Array = _safe_array(
		source.get(
			"ownership_chain",
			source.get(
				"owner_history",
				[]
			)
		)
	)

	if (
		chain.is_empty()
		and owner_id > 0
	):
		chain.append({
			"owner_id": owner_id,
			"acquired_year": int(
				source.get(
					"acquired_year",
					origin.get(
						"year",
						_current_year()
					)
				)
			),
			"mode": str(
				source.get(
					"acquisition_mode",
					"current_owner"
				)
			)
		})

	return chain


func _history_rows(
	source: Dictionary,
	ownership_chain: Array
) -> Array:
	var out: Array = []

	for key in [
		"history",
		"object_history",
		"event_history",
		"provenance_events",
		"myth_events"
	]:
		for raw_event in _safe_array(
			source.get(
				key,
				[]
			)
		):
			if typeof(
				raw_event
			) == TYPE_DICTIONARY:
				out.append(
					(
						raw_event as Dictionary
					).duplicate(true)
				)

	for raw_owner in ownership_chain:
		if typeof(
			raw_owner
		) != TYPE_DICTIONARY:
			continue

		var owner_row: Dictionary = (
			raw_owner as Dictionary
		)
		out.append({
			"event_type": "ownership_chain_entry",
			"owner_id": int(
				owner_row.get(
					"owner_id",
					-1
				)
			),
			"year": int(
				owner_row.get(
					"acquired_year",
					-1
				)
			),
			"mode": str(
				owner_row.get(
					"mode",
					"inheritance"
				)
			)
		})

	return out


func _action_rows(
	source: Dictionary,
	catalog_object_id: String
) -> Array:
	var actions: Array = _safe_array(
		source.get(
			"actions",
			[]
		)
	)

	var instance_object_id: String = str(
		source.get(
			"instance_object_id",
			source.get(
				"object_id",
				""
			)
		)
	).strip_edges()

	if actions.is_empty():
		actions.append({
			"id": "inspect_provenance",
			"label": "Inspect Provenance",
			"route": {
				"engine_property": (
					"global_object_catalog_system"
				),
				"method": "get_object_history",
				"read_only": true
			},
			"payload": {
				"object_id": (
					instance_object_id
					if instance_object_id != ""
					else catalog_object_id
				)
			}
		})

	if instance_object_id != "":
		actions.append({
			"id": "open_heirloom_history",
			"label": "Open Heirloom History",
			"route": {
				"engine_property": (
					"heirloom_hub_contract_engine"
				),
				"method": "resolve_intent",
				"pass_actor_payload": true
			},
			"payload": {
				"action_id": "open",
				"section_id": "history",
				"object_id": instance_object_id
			}
		})

		actions.append({
			"id": "transfer_heirloom",
			"label": "Pass To Someone",
			"requires_target": true,
			"route": {
				"engine_property": (
					"heirloom_hub_contract_engine"
				),
				"method": "resolve_intent",
				"pass_actor_payload": true
			},
			"payload": {
				"action_id": "transfer_heirloom",
				"object_id": instance_object_id,
				"transfer_mode": "gift"
			}
		})

		actions.append({
			"id": "contest_heirloom",
			"label": "Open Lineage Claim",
			"route": {
				"engine_property": (
					"heirloom_hub_contract_engine"
				),
				"method": "resolve_intent",
				"pass_actor_payload": true
			},
			"payload": {
				"action_id": "contest_heirloom",
				"object_id": instance_object_id,
				"claim_basis": "lineage_claim"
			}
		})

	return actions


func _legal_contract(
	source: Dictionary
) -> Dictionary:
	return {
		"legal": bool(
			source.get(
				"legal",
				true
			)
		),
		"classification": str(
			source.get(
				"legal_classification",
				"property"
			)
		),
		"stolen": bool(
			source.get(
				"stolen",
				false
			)
		),
		"disputed": bool(
			source.get(
				"ownership_disputed",
				false
			)
		),
		"jurisdiction_tags": _string_array(
			source.get(
				"jurisdiction_tags",
				[]
			)
		)
	}


func _reality_contract(
	source: Dictionary,
	context: Dictionary
) -> Dictionary:
	return {
		"era": str(
			context.get(
				"era",
				source.get(
					"origin_era",
					_current_era_name()
				)
			)
		),
		"country": str(
			context.get(
				"country",
				source.get(
					"origin_country",
					""
				)
			)
		),
		"city": str(
			context.get(
				"city",
				source.get(
					"origin_city",
					""
				)
			)
		),
		"location_id": str(
			context.get(
				"location_id",
				source.get(
					"location_id",
					""
				)
			)
		),
		"reality_signature": str(
			context.get(
				"reality_signature",
				""
			)
		),
		"cross_reality_persistent": bool(
			source.get(
				"cross_reality_persistent",
				true
			)
		)
	}


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

		if not index.has(
			key
		):
			order.append(
				key
			)
			index [key] = object_contract
		else:
			index [key] = _merge_contracts(
				_safe_dictionary(
					index.get(
						key,
						{}
					)
				),
				object_contract
			)

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


func _merge_contracts(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in overlay.keys():
		if key in [
			"object_domains"
		]:
			var merged_array: Array = _string_array(
				out.get(
					key,
					[]
				)
			)

			for raw_value in _string_array(
				overlay.get(
					key,
					[]
				)
			):
				if raw_value not in merged_array:
					merged_array.append(
						raw_value
					)

			out [key] = merged_array
		elif typeof(
			overlay.get(
				key
			)
		) == TYPE_DICTIONARY and typeof(
			out.get(
				key
			)
		) == TYPE_DICTIONARY:
			var merged_dictionary: Dictionary = _safe_dictionary(
				out.get(
					key,
					{}
				)
			)

			for nested_key in (
				overlay.get(
					key,
					{}
				) as Dictionary
			).keys():
				merged_dictionary [nested_key] = (
					overlay.get(
						key,
						{}
					) as Dictionary
				) [nested_key]

			out [key] = merged_dictionary
		else:
			out [key] = overlay [key]

	return out


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
		out ["year"] = _current_year()

	if not out.has(
		"include_modded"
	):
		out ["include_modded"] = true

	if not out.has(
		"include_unowned"
	):
		out ["include_unowned"] = true

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


func _current_era_name() -> String:
	if (
		gs != null
		and gs.era != null
	):
		return str(
			gs.era.name
		)

	return "Modern Era"


func _current_year() -> int:
	return (
		int(
			gs.year
		)
		if gs != null
		else 0
	)


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