extends Resource
class_name BelongingsEngine

const CONTRACT_SCHEMA:= "eralife.belongings_engine_contract"
const ITEM_CONTRACT_SCHEMA:= "eralife.item_contract"
const INHERITANCE_CONTRACT_SCHEMA:= "eralife.inheritance_contract"
const OBJECT_MYTH_SCHEMA:= "eralife.object_myth_contract"
const OBJECT_PERCEPTION_SCHEMA:= "eralife.object_perception_packet"
const CONTRACT_VERSION:= 3
const STATE_SCHEMA:= "eralife.belongings_engine_state"
const STATE_KEY:= "belongings_engine_state"
const MAX_BELONGINGS_LEDGER:= 240
const MAX_OBJECT_MYTH_LEDGER:= 280
const MAX_OBJECT_PERCEPTION_MEMORY:= 420

var gs
var relationship_item_transfer_queue: Array = []
var relationship_item_transfer_service_armed: bool = false
var belongings = {}
var active_contract: Dictionary = {}
var item_contract_registry: Dictionary = {}
var inheritance_contract_registry: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_inheritance_report: Dictionary = {}
var last_myth_report: Dictionary = {}

func _init(_gs, contract: Dictionary = {}):
	gs = _gs
	set_contract(contract)
func _belongings_owner_key_for_person(person: Person) -> Variant:
	if person == null:
		return -1

	var numeric_id: int = int(person.id)
	if belongings.has(numeric_id):
		return numeric_id

	var string_id: String = str(numeric_id)
	if belongings.has(string_id):
		return string_id

	return numeric_id
func add_item(
	person: Person,
	item: Dictionary,
	category: String,
	mirror_only:= false,
	event_context: Dictionary = {}
):
	if person == null:
		return

	# DIAGNOSTIC: report every Vehicles add with its id, so a category that keeps
	# growing on each Assets visit names whatever is adding to it.
	if str(category) == "Vehicles":
		EraLog.truth(
			"ERALIFE_BELONGINGS_ADD|owner=%d|category=%s|item_id=%s|name=%s"
			% [
				int(person.id),
				str(category),
				str(item.get("id", -1)) if typeof(item) == TYPE_DICTIONARY else "?",
				str(item.get("display_name", item.get("model", "?"))) if typeof(item) == TYPE_DICTIONARY else "?"
			]
		)

	if typeof(
		item
	) != TYPE_DICTIONARY:
		return

	var clean_category: String = str(
		category
	).strip_edges()

	if clean_category == "":
		clean_category = "Misc"

	var owner_key: Variant = (
		_belongings_owner_key_for_person(
			person
		)
	)

	if not belongings.has(
		owner_key
	):
		belongings [
			owner_key
		] = {}

	if not belongings [
		owner_key
	].has(
		clean_category
	):
		belongings [
			owner_key
		] [
			clean_category
		] = []

	var entry: Dictionary = (
		_normalize_belonging_entry(
			person,
			item,
			clean_category,
			mirror_only,
			true
		)
	)

	entry [
		"owner_id"
	] = int(
		person.id
	)

	var record_context: Dictionary = (
		event_context.duplicate(false)
	)

	record_context [
		"mirror_only"
	] = bool(
		mirror_only
	)

	if not record_context.has(
		"source"
	):
		record_context [
			"source"
		] = str(
			entry.get(
				"source",
				"belongings_engine"
			)
		)

	var suppress_transaction_event: bool = (
		mirror_only
		and bool(
			record_context.get(
				"transaction_enrichment_deferred",
				false
			)
		)
		and bool(
			record_context.get(
				"ui_blocking_forbidden",
				false
			)
		)
	)

	if (
		bool(
			entry.get(
				"temporary_ownership",
				false
			)
		)
		or bool(
			entry.get(
				"government_owned",
				false
			)
		)
	):
		record_context [
			"spawn_existing_asset"
		] = bool(
			record_context.get(
				"spawn_existing_asset",
				true
			)
		)

	if str(
		entry.get(
			"asset_kind",
			""
		)
	).strip_edges() == "official_residence":
		record_context [
			"spawn_existing_asset"
		] = bool(
			record_context.get(
				"spawn_existing_asset",
				true
			)
		)
		record_context [
			"official_residence"
		] = true

	var item_id: int = int(
		entry.get(
			"id",
			-1
		)
	)

	var items: Array = belongings [
		owner_key
	] [
		clean_category
	]

	if item_id > 0:
		for i in range(
			items.size()
		):
			var existing: Variant = items [
				i
			]

			if typeof(
				existing
			) != TYPE_DICTIONARY:
				continue

			if int(
				(existing as Dictionary).get(
					"id",
					-1
				)
			) != item_id:
				continue

			items [
				i
			] = entry

			belongings [
				owner_key
			] [
				clean_category
			] = items

			if not suppress_transaction_event:
				var update_context: Dictionary = (
					record_context.duplicate(false)
				)

				update_context [
					"reason"
				] = "matching_item_id"

				_record_belongings_event(
					"item_updated",
					person,
					entry,
					clean_category,
					update_context
				)

			set_meta(
				"last_mirror_transaction_event_suppressed",
				suppress_transaction_event
			)
			return

	items.append(
		entry
	)

	belongings [
		owner_key
	] [
		clean_category
	] = items

	if not suppress_transaction_event:
		_record_belongings_event(
			"item_acquired",
			person,
			entry,
			clean_category,
			record_context
		)

	set_meta(
		"last_mirror_transaction_event_suppressed",
		suppress_transaction_event
	)
func queue_relationship_item_transfer(
	giver_id: int,
	receiver_id: int,
	category: String,
	item_key: String,
	reason: String
) -> Dictionary:
	if (
		giver_id <= 0
		or receiver_id <= 0
		or giver_id == receiver_id
		or item_key.strip_edges() == ""
	):
		return {
			"success": false,
			"reason": "invalid_relationship_item_transfer"
		}

	relationship_item_transfer_queue.append({
		"giver_id": giver_id,
		"receiver_id": receiver_id,
		"category": (
			category
			if category.strip_edges() != ""
			else "Luxury"
		),
		"item_key": item_key,
		"reason": reason,
		"cursor": 0,
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	_arm_relationship_item_transfer_service()

	return {
		"success": true,
		"queued": true,
		"giver_id": giver_id,
		"receiver_id": receiver_id,
		"item_key": item_key,
		"blocks_ui": false
	}


func _resident_belongings_person_by_id(
	person_id: int
) -> Person:
	if (
		gs == null
		or person_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == person_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			person_id,
			false
		)

	return null


func _arm_relationship_item_transfer_service() -> void:
	if relationship_item_transfer_service_armed:
		return

	if relationship_item_transfer_queue.is_empty():
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (main_loop is SceneTree):
		return

	relationship_item_transfer_service_armed = true

	var timer:= (
		main_loop as SceneTree
	).create_timer(
		0.02
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_relationship_item_transfer_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _service_relationship_item_transfer_quantum() -> void:
	relationship_item_transfer_service_armed = false

	if relationship_item_transfer_queue.is_empty():
		return

	var job_raw: Variant = (
		relationship_item_transfer_queue [
			0
		]
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		relationship_item_transfer_queue.pop_front()
		_arm_relationship_item_transfer_service()
		return

	var giver: Person = _resident_belongings_person_by_id(
		int(
			job.get(
				"giver_id",
				-1
			)
		)
	)
	var receiver: Person = _resident_belongings_person_by_id(
		int(
			job.get(
				"receiver_id",
				-1
			)
		)
	)

	if (
		giver == null
		or receiver == null
	):
		relationship_item_transfer_queue.pop_front()
		_arm_relationship_item_transfer_service()
		return

	var category: String = str(
		job.get(
			"category",
			"Luxury"
		)
	)
	var item_key: String = str(
		job.get(
			"item_key",
			""
		)
	)

	var giver_key: Variant = (
		_belongings_owner_key_for_person(
			giver
		)
	)
	var receiver_key: Variant = (
		_belongings_owner_key_for_person(
			receiver
		)
	)

	if not belongings.has(
		giver_key
	):
		relationship_item_transfer_queue.pop_front()
		_arm_relationship_item_transfer_service()
		return

	var giver_inventory_raw: Variant = (
		belongings.get(
			giver_key,
			{}
		)
	)
	var giver_inventory: Dictionary = (
		giver_inventory_raw as Dictionary
		if typeof(
			giver_inventory_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var items_raw: Variant = giver_inventory.get(
		category,
		[]
	)
	var items: Array = (
		items_raw as Array
		if typeof(items_raw) == TYPE_ARRAY
		else []
	)

	var cursor: int = int(
		job.get(
			"cursor",
			0
		)
	)

	if cursor >= items.size():
		relationship_item_transfer_queue.pop_front()
		_arm_relationship_item_transfer_service()
		return


	var raw_item: Variant = items [
		cursor
	]
	job ["cursor"] = cursor + 1

	if typeof(raw_item) == TYPE_DICTIONARY:
		var item: Dictionary = (
			raw_item as Dictionary
		)

		var candidate_key: String = str(
			item.get(
				"personal_item_id",
				item.get(
					"id",
					item.get(
						"item_id",
						""
					)
				)
			)
		).strip_edges()

		if candidate_key == item_key:
			var transferred: Dictionary = (
				_normalize_belonging_entry(
					receiver,
					item,
					category,
					false,
					true
				)
			)

			transferred ["owner_id"] = int(
				receiver.id
			)
			transferred [
				"relationship_transfer_reason"
			] = str(
				job.get(
					"reason",
					"relationship_transfer"
				)
			)


			var last_index: int = (
				items.size() - 1
			)

			if cursor != last_index:
				items [
					cursor
				] = items [
					last_index
				]

			items.pop_back()

			giver_inventory [
				category
			] = items
			belongings [
				giver_key
			] = giver_inventory

			if not belongings.has(
				receiver_key
			):
				belongings [
					receiver_key
				] = {}

			var receiver_inventory: Dictionary = (
				belongings [
					receiver_key
				] as Dictionary
			)

			if not receiver_inventory.has(
				category
			):
				receiver_inventory [
					category
				] = []

			var receiver_items: Array = (
				receiver_inventory [
					category
				] as Array
			)

			receiver_items.append(
				transferred
			)

			receiver_inventory [
				category
			] = receiver_items

			belongings [
				receiver_key
			] = receiver_inventory

			var event_context: Dictionary = {
				"reason": str(
					job.get(
						"reason",
						"relationship_transfer"
					)
				),
				"defer_reality_routing": true,
				"ui_blocking_forbidden": true
			}

			_record_belongings_event(
				"item_removed",
				giver,
				item,
				category,
				event_context
			)

			_record_belongings_event(
				"item_acquired",
				receiver,
				transferred,
				category,
				event_context
			)

			relationship_item_transfer_queue.pop_front()
			_arm_relationship_item_transfer_service()
			return

	relationship_item_transfer_queue [
		0
	] = job

	_arm_relationship_item_transfer_service()
func emit_trade_goods_catalog_contract(
	person: Person,
	context: Dictionary = {}
) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"schema": (
				"eralife.trade_goods_catalog_contract"
			),
			"version": CONTRACT_VERSION,
			"goods_rows": [],
			"reason": "missing_person"
		}

	var rows: Array = []

	for raw_item in TRADE_GOODS:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = (
			raw_item as Dictionary
		)

		var good_name: String = str(
			item.get(
				"name",
				"Trade Good"
			)
		)

		var base_value: int = int(
			item.get(
				"value",
				0
			)
		)

		var market_value: int = base_value

		if (
			gs != null
			and "global_market_engine" in gs
			and gs.global_market_engine != null
		):
			market_value = int(
				gs.global_market_engine.get_price_for_good(
					good_name,
					int(
						person.realm_id
					)
				)
			)

		rows.append({
			"good_id": (
				"trade_good::%s"
				% good_name.to_lower().replace(
					" ",
					"_"
				)
			),
			"title": good_name,
			"name": good_name,
			"description": (
				"A live trade good available to merchant "
				+ "and market professions."
			),
			"base_value": base_value,
			"market_value": market_value,
			"value_text": (
				"$%d"
				% market_value
			),
			"origin_realm_id": int(
				person.realm_id
			),
			"era_name": _current_era_name(),
			"contract_id": "trade_good",
			"projection_read_only": true,
			"ui_is_renderer_only": true
		})

	return {
		"success": true,
		"schema": (
			"eralife.trade_goods_catalog_contract"
		),
		"version": CONTRACT_VERSION,
		"actor_id": int(
			person.id
		),
		"realm_id": int(
			person.realm_id
		),
		"goods_rows": rows,
		"source": str(
			context.get(
				"source",
				"belongings_engine.trade_goods_catalog"
			)
		),
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}
func get_inventory(person: Person) -> Dictionary:
	if person == null:
		return {}

	var owner_key: Variant = _belongings_owner_key_for_person(person)
	var raw_inventory: Variant = belongings.get(owner_key, {})
	if typeof(raw_inventory) != TYPE_DICTIONARY:
		return {}

	return raw_inventory as Dictionary

func get_inventory_categories(person: Person) -> Array:
	if person == null:
		return []
	var inventory: Dictionary = get_inventory(person)
	var categories: Array = inventory.keys()
	categories.sort()
	return categories
func get_player_inventory_rows(context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []
	return get_inventory_rows_for_actor(gs.player, context)

func get_inventory_rows_for_actor(
	actor: Person,
	_context: Dictionary = {}
) -> Array:
	if actor == null:
		return []

	var inventory: Dictionary = get_inventory(actor)
	var rows: Array = []
	var categories: Array = inventory.keys()
	categories.sort()

	for raw_category in categories:
		var category: String = str(
			raw_category
		)
		var items_raw: Variant = inventory.get(
			raw_category,
			[]
		)
		var items: Array = []

		if typeof(items_raw) == TYPE_ARRAY:
			items = items_raw as Array

		if items.is_empty():
			continue

		rows.append({
			"label": "— %s —" % category,
			"kind": "inventory_category",
			"category": category
		})

		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var raw_item_contract: Dictionary = (
				raw_item as Dictionary
			).duplicate(true)
			var raw_asset_kind: String = str(
				raw_item_contract.get(
					"asset_kind",
					""
				)
			).strip_edges().to_lower()
			var raw_storage_status: String = str(
				raw_item_contract.get(
					"storage_status",
					"unstored"
				)
			).strip_edges().to_lower()
			var stored_property_id: int = int(
				raw_item_contract.get(
					"stored_at_property_id",
					-1
				)
			)





			if (
				raw_asset_kind == "transport"
				and (
					raw_storage_status == "stored"
					or stored_property_id > 0
				)
			):
				continue

			var item: Dictionary = _normalize_belonging_entry(
				actor,
				raw_item_contract,
				category,
				bool(
					raw_item_contract.get(
						"mirrored_asset",
						false
					)
				),
				false
			)
			var contract: Dictionary = _resolve_item_contract(
				item,
				category
			)
			var myth: Dictionary = get_item_myth_profile(
				item
			)
			var bond: Dictionary = get_item_bond_profile(
				actor,
				item
			)
			var actions: Array = []




			if (
				category == "Artifacts"
				and gs != null
				and gs.artifact_interaction_contract_engine != null
			):
				var artifact_projection: Dictionary = _safe_dictionary(
					gs.artifact_interaction_contract_engine
						.emit_item_projection(
							actor,
							item
						)
				)

				item ["artifact_action_specs"] = _safe_array(
					artifact_projection.get(
						"action_specs",
						[]
					)
				)
				item ["artifact_market_profile"] = _safe_dictionary(
					artifact_projection.get(
						"market_profile",
						{}
					)
				)
				item ["available_wishes"] = _safe_array(
					artifact_projection.get(
						"available_wishes",
						[]
					)
				)
				item ["wish_rows"] = _safe_array(
					artifact_projection.get(
						"wish_rows",
						[]
					)
				)
				item ["artifact_interaction_contract"] = (
					artifact_projection.duplicate(true)
				)

			if (
				(
					category == "Heirlooms"
					or "heirloom" in _safe_array(
						item.get(
							"object_domains",
							[]
						)
					)
				)
				and gs != null
				and gs.heirloom_runtime_engine != null
			):
				var heirloom_object_id: String = str(
					item.get(
						"instance_object_id",
						item.get(
							"object_id",
							item.get(
								"id",
								""
							)
						)
					)
				)

				var heirloom_record: Dictionary = _safe_dictionary(
					gs.heirloom_runtime_engine.record_for_object(
						heirloom_object_id
					)
				)

				if not heirloom_record.is_empty():
					item ["heirloom_record"] = (
						heirloom_record.duplicate(true)
					)
					item ["lineage_id"] = str(
						heirloom_record.get(
							"lineage_id",
							item.get(
								"lineage_id",
								""
							)
						)
					)
					item ["historical_value"] = int(
						heirloom_record.get(
							"historical_value",
							item.get(
								"historical_value",
								0
							)
						)
					)
					item ["cultural_value"] = int(
						heirloom_record.get(
							"cultural_value",
							item.get(
								"cultural_value",
								0
							)
						)
					)
					item ["lineage_prestige"] = int(
						heirloom_record.get(
							"lineage_prestige",
							0
						)
					)
					item ["ownership_chain"] = _safe_array(
						heirloom_record.get(
							"ownership_chain",
							item.get(
								"ownership_chain",
								[]
							)
						)
					)

			if typeof(
				item.get(
					"actions",
					[]
				)
			) == TYPE_ARRAY:
				actions = (
					item.get("actions", []) as Array
				).duplicate(true)

			for action in _actions_from_item_contract(
				actor,
				item,
				category,
				contract
			):
				actions.append(action)

			if _should_show_summon_shenron_action(
				actor,
				item,
				category
			):
				actions.append(
					_summon_shenron_action_for_item(
						item
					)
				)

			var age_text: String = ""
			var item_age: int = int(
				item.get(
					"age",
					item.get(
						"age_years",
						0
					)
				)
			)

			if item_age > 0:
				age_text = " • age %d" % item_age

			var contract_label: String = str(
				contract.get(
					"display_name",
					item.get(
						"contract_id",
						""
					)
				)
			).strip_edges()

			if contract_label != "":
				contract_label = " • %s" % contract_label

			var myth_label: String = str(
				myth.get(
					"myth_level",
					""
				)
			).strip_edges()

			if myth_label != "":
				myth_label = " • myth %s" % myth_label.replace(
					"_",
					" "
				)

			var bond_label: String = ""
			var bond_score: float = float(
				bond.get(
					"bond_score",
					0.0
				)
			)

			if bond_score > 0.0:
				bond_label = " • bond %d%%" % int(
					round(
						bond_score * 100.0
					)
				)

			var hunter_label: String = ""

			if float(
				myth.get(
					"hunter_pressure",
					0.0
				)
			) >= 0.45:
				hunter_label = " • hunted"

			var row: Dictionary = {
				"label": "%s • %s • value %d%s%s%s%s%s" % [
					str(
						item.get(
							"display_name",
							item.get(
								"name",
								"Unnamed Item"
							)
						)
					),
					str(
						item.get(
							"type",
							item.get(
								"category",
								category
							)
						)
					),
					int(
						item.get(
							"value",
							item.get(
								"price",
								0
							)
						)
					),
					age_text,
					contract_label,
					myth_label,
					bond_label,
					hunter_label
				],
				"kind": "inventory_item",
				"category": category,
				"item_id": str(
					item.get("id", "")
				),
				"contract_id": str(
					item.get(
						"contract_id",
						contract.get(
							"id",
							""
						)
					)
				),
				"value": int(
					item.get(
						"value",
						item.get(
							"price",
							0
						)
					)
				),
				"age": item_age,
				"identity": _safe_dictionary(
					item.get(
						"identity",
						item.get(
							"reality_identity",
							{}
						)
					)
				),
				"affordances": _safe_array(
					item.get(
						"affordances",
						[]
					)
				),
				"relationships": _safe_dictionary(
					item.get(
						"relationships",
						{}
					)
				),
				"myth": myth.duplicate(true),
				"bond": bond.duplicate(true),
				"item": item.duplicate(true)
			}

			if not actions.is_empty():
				row ["actions"] = actions

			rows.append(row)

	return rows
func _should_show_summon_shenron_action(actor: Person, item: Dictionary, category: String) -> bool:
	if gs == null or actor == null:
		return false
	if gs.player == null or int(actor.id) != int(gs.player.id):
		return false
	if not ("dragonballs_engine" in gs) or gs.dragonballs_engine == null:
		return false
	if not gs.dragonballs_engine.has_method("player_has_all"):
		return false
	if not bool(gs.dragonballs_engine.player_has_all()):
		return false

	var clean_category: String = str(category).strip_edges().to_lower()
	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	var item_name: String = str(item.get("name", item.get("display_name", ""))).strip_edges().to_lower()

	if clean_category == "dragon balls":
		return true
	if item_type == "dragonball":
		return true
	if item_name.find("dragon ball") >= 0:
		return true

	return false


func _summon_shenron_action_for_item(item: Dictionary) -> Dictionary:
	return {
		"id": "summon_shenron_%s" % str(item.get("id", item.get("star", "dragonball"))),
		"label": "🐉 Summon Shenron",
		"kind": "engine_call",
		"engine_property": "dragonballs_engine",
		"method": "summon_shenron",
		"call_mode": "player_payload",
		"payload": {
			"source": "belongings_inventory",
			"source_item": item.duplicate(true)
		},
		"refresh_after": true
	}
func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"generationally_persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"belongings": belongings.duplicate(true),
		"active_contract": active_contract.duplicate(true),
		"item_contract_registry": item_contract_registry.duplicate(true),
		"inheritance_contract_registry": inheritance_contract_registry.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_inheritance_report": last_inheritance_report.duplicate(true),
		"last_myth_report": last_myth_report.duplicate(true),
		"exported_at_year": _current_year(),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "BelongingsEngine import data must be a Dictionary."}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		set_contract(contract_raw as Dictionary)
	else:
		set_contract({})

	var registry_raw: Variant = data.get("item_contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		for raw_key in (registry_raw as Dictionary).keys():
			var contract: Dictionary = _safe_dictionary((registry_raw as Dictionary).get(raw_key, {}))
			if contract.is_empty():
				continue
			register_item_contract(contract)

	var inheritance_raw: Variant = data.get("inheritance_contract_registry", {})
	if typeof(inheritance_raw) == TYPE_DICTIONARY:
		inheritance_contract_registry = (inheritance_raw as Dictionary).duplicate(true)
	else:
		inheritance_contract_registry = {}

	var raw: Variant = data.get("belongings", data)
	if typeof(raw) == TYPE_DICTIONARY:
		belongings = _normalize_belongings_store(raw as Dictionary)
	else:
		belongings = {}

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	var inheritance_report_raw: Variant = data.get("last_inheritance_report", {})
	if typeof(inheritance_report_raw) == TYPE_DICTIONARY:
		last_inheritance_report = (inheritance_report_raw as Dictionary).duplicate(true)

	var myth_report_raw: Variant = data.get("last_myth_report", {})
	if typeof(myth_report_raw) == TYPE_DICTIONARY:
		last_myth_report = (myth_report_raw as Dictionary).duplicate(true)
	else:
		last_myth_report = _safe_dictionary(_world_state().get("last_object_myth_report", {}))

	return {
		"success": true,
		"schema": "eralife.belongings_engine_import_report",
		"version": CONTRACT_VERSION,
		"backwards_compatible": true,
		"normalized_item_count": _total_item_count_all(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}
func get_total_item_count(person: Person) -> int:
	if person == null:
		return 0
	var inventory: Dictionary = get_inventory(person)
	var total: int = 0
	for category in inventory.keys():
		var items: Array = inventory.get(category, [])
		total += items.size()
	return total

func get_all_items_flat(person: Person) -> Array:
	var out: Array = []
	if person == null:
		return out
	var inventory: Dictionary = get_inventory(person)
	for category in inventory.keys():
		var items: Array = inventory.get(category, [])
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = _normalize_belonging_entry(person, raw_item as Dictionary, str(category), bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
			entry ["category"] = str(category)
			out.append(entry)
	return out
func has_item_named(person: Person, category: String, item_name: String) -> bool:
	if person == null:
		return false
	if not belongings.has(person.id):
		return false
	if not belongings [person.id].has(category):
		return false
	for raw_item in belongings [person.id] [category]:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		if str(raw_item.get("name", "")) == item_name:
			return true
	return false
func get_category_items(person: Person, category: String) -> Array:
	if person == null:
		return []

	var inventory: Dictionary = get_inventory(person)
	if inventory.is_empty():
		return []

	if not inventory.has(category):
		return []

	var raw_items: Variant = inventory.get(category, [])
	if typeof(raw_items) != TYPE_ARRAY:
		return []

	return (raw_items as Array).duplicate(true)

func remove_item_by_id(person: Person, category: String, item_id: int) -> Dictionary:
	if person == null:
		return {}
	if not belongings.has(person.id):
		return {}
	if not belongings [person.id].has(category):
		return {}
	var items: Array = belongings [person.id] [category]
	for i in range(items.size()):
		var item = items [i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if int(item.get("id", -1)) != item_id:
			continue
		var removed: Dictionary = _normalize_belonging_entry(person, item as Dictionary, category, bool((item as Dictionary).get("mirrored_asset", false)), false)
		items.remove_at(i)
		belongings [person.id] [category] = items
		_record_belongings_event("item_removed", person, removed, category, {
			"reason": "remove_item_by_id"
		})
		return removed
	return {}

func gift_item_to_person(giver: Person, receiver: Person, category: String, item_id: int) -> Dictionary:
	if giver == null or receiver == null:
		return { "success": false, "text": "A valid giver and receiver are required."}
	var removed: Dictionary = remove_item_by_id(giver, category, item_id)
	if removed.is_empty():
		return { "success": false, "text": "That item could not be found in belongings."}

	var transfer_packet: Dictionary = _build_transfer_packet(giver, receiver, removed, category, {
		"transfer_type": "gift",
		"source": "gift_item_to_person"
	})
	removed ["relationships"] = _transfer_relationships_for_item(giver, receiver, removed, category, transfer_packet)
	removed ["transfer_history"] = _safe_array(removed.get("transfer_history", []))
	removed ["transfer_history"].append(transfer_packet)

	add_item(receiver, removed, category)

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"🎁 %s gifted %s to %s." % [
				giver.first_name,
				str(removed.get("name", "an item")),
				receiver.first_name
			],
			{
				"npc_id": giver.id,
				"personally_relevant": giver == gs.player or receiver == gs.player,
				"category": "belongings",
				"event_name": ActionEventTypes.PLAYER_GIFTED_NPC,
				"source": "belongings_engine",
				"contract_id": str(removed.get("contract_id", "")),
				"transfer_packet": transfer_packet.duplicate(true)
			}
		)

	_record_belongings_event("item_gifted", receiver, removed, category, transfer_packet)

	return {
		"success": true,
		"schema": "eralife.belongings_transfer_report",
		"version": CONTRACT_VERSION,
		"text": "🎁 I gifted %s to %s." % [
			str(removed.get("name", "an item")),
			receiver.first_name
		],
		"transfer_packet": transfer_packet.duplicate(true)
	}




func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	item_contract_registry = {}
	var default_item_contracts: Dictionary = _safe_dictionary(active_contract.get("item_contracts", {}))
	for raw_key in default_item_contracts.keys():
		var normalized: Dictionary = _normalize_item_contract(_safe_dictionary(default_item_contracts.get(raw_key, {})), {}, "")
		var contract_id: String = str(normalized.get("id", raw_key)).strip_edges()
		if contract_id == "":
			continue
		item_contract_registry [contract_id] = normalized.duplicate(true)

	last_contract_report = {
		"success": true,
		"schema": "eralife.belongings_contract_set_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "belongings.default")),
		"registered_item_contract_count": item_contract_registry.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)

func bootstrap_default_contracts() -> Dictionary:
	set_contract(active_contract)
	var state: Dictionary = _world_state()
	state ["active_contract"] = active_contract.duplicate(true)
	state ["item_contract_registry"] = item_contract_registry.duplicate(true)
	state ["inheritance_contract_registry"] = inheritance_contract_registry.duplicate(true)
	_commit_world_state(state)
	return {
		"success": true,
		"schema": "eralife.belongings_bootstrap_report",
		"version": CONTRACT_VERSION,
		"registered_item_contract_count": item_contract_registry.size(),
		"bootstrapped_at_ms": int(Time.get_ticks_msec())
	}

func register_item_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return { "success": false, "reason": "Item contract missing."}
	var normalized: Dictionary = _normalize_item_contract(contract, {}, "")
	var contract_id: String = str(normalized.get("id", "")).strip_edges()
	if contract_id == "":
		return { "success": false, "reason": "Item contract id missing."}
	item_contract_registry [contract_id] = normalized.duplicate(true)

	if typeof(active_contract.get("item_contracts", {})) != TYPE_DICTIONARY:
		active_contract ["item_contracts"] = {}
	active_contract ["item_contracts"] [contract_id] = normalized.duplicate(true)

	return {
		"success": true,
		"schema": "eralife.item_contract_register_report",
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"registered_at_ms": int(Time.get_ticks_msec())
	}

func get_item_contract(contract_id: String) -> Dictionary:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return {}
	if item_contract_registry.has(clean_id):
		return _safe_dictionary(item_contract_registry.get(clean_id, {}))
	return {}

func materialize_contract_item(person: Person, contract_id: String, overrides: Dictionary = {}, category: String = "") -> Dictionary:
	if person == null:
		return { "success": false, "reason": "A valid owner is required."}
	var contract: Dictionary = get_item_contract(contract_id)
	if contract.is_empty():
		return { "success": false, "reason": "No item contract found for %s." % str(contract_id)}

	var identity: Dictionary = _safe_dictionary(contract.get("identity", {}))
	var clean_category: String = str(category).strip_edges()
	if clean_category == "":
		clean_category = str(contract.get("category", identity.get("category", "Artifacts"))).strip_edges()
	if clean_category == "":
		clean_category = "Artifacts"

	var item: Dictionary = {
		"id": _next_item_id(),
		"name": str(contract.get("item_name", contract.get("display_name", contract_id))),
		"display_name": str(contract.get("display_name", contract.get("item_name", contract_id))),
		"type": str(identity.get("type", contract.get("type", "Item"))),
		"contract_id": contract_id,
		"item_contract": contract.duplicate(true),
		"identity": identity.duplicate(true),
		"affordances": _safe_array(contract.get("affordances", [])),
		"relationships": _safe_dictionary(contract.get("relationships", {})),
		"value": int(contract.get("value", overrides.get("value", 0))),
		"origin_era": _current_era_name(),
		"acquired_year": _current_year(),
		"source": str(overrides.get("source", "materialize_contract_item"))
	}

	for raw_key in overrides.keys():
		item [raw_key] = overrides.get(raw_key)

	add_item(person, item, clean_category)

	return {
		"success": true,
		"schema": "eralife.contract_item_materialization_report",
		"version": CONTRACT_VERSION,
		"owner_id": int(person.id),
		"category": clean_category,
		"contract_id": contract_id,
		"item": _normalize_belonging_entry(person, item, clean_category, false, false)
	}

func resolve_item_reality_contract(person: Person, item: Dictionary, category: String = "", context: Dictionary = {}) -> Dictionary:
	if person == null:
		return { "success": false, "reason": "A valid actor is required."}
	if typeof(item) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Item must be a Dictionary."}

	var clean_category: String = str(category).strip_edges()
	if clean_category == "":
		clean_category = str(item.get("category", "Misc")).strip_edges()
	if clean_category == "":
		clean_category = "Misc"

	var normalized: Dictionary = _normalize_belonging_entry(person, item, clean_category, bool(item.get("mirrored_asset", false)), false)
	var contract: Dictionary = _resolve_item_contract(normalized, clean_category)

	return {
		"success": true,
		"schema": "eralife.belonging_reality_contract_packet",
		"version": CONTRACT_VERSION,
		"actor_id": int(person.id),
		"category": clean_category,
		"item_id": int(normalized.get("id", -1)),
		"contract_id": str(contract.get("id", normalized.get("contract_id", ""))),
		"identity": _safe_dictionary(normalized.get("identity", normalized.get("reality_identity", {}))),
		"affordances": _safe_array(normalized.get("affordances", [])),
		"relationships": _safe_dictionary(normalized.get("relationships", {})),
		"persistence": _safe_dictionary(normalized.get("persistence", {})),
		"item": normalized.duplicate(true),
		"contract": contract.duplicate(true),
		"context": context.duplicate(true),
		"resolved_at_year": _current_year(),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

func create_inheritance_contract(owner: Person, heirs: Array, options: Dictionary = {}) -> Dictionary:
	if owner == null:
		return { "success": false, "reason": "A valid owner is required."}
	var normalized_heirs: Array = _normalize_inheritance_heirs(heirs)
	if normalized_heirs.is_empty():
		return { "success": false, "reason": "At least one heir is required."}

	var contract_id: String = str(options.get("id", "inheritance_%d_%d" % [int(owner.id), int(Time.get_ticks_msec())])).strip_edges()
	var contract: Dictionary = {
		"schema": INHERITANCE_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"owner_id": int(owner.id),
		"owner_name": _person_label(owner),
		"heirs": normalized_heirs,
		"rules": {
			"transfer_mode": str(options.get("transfer_mode", "contract_weighted")),
			"default_policy": str(options.get("default_policy", "weighted_round_robin")),
			"include_mirrored_assets": bool(options.get("include_mirrored_assets", false)),
			"preserve_item_contracts": bool(options.get("preserve_item_contracts", true)),
			"preserve_unknown_fields": bool(options.get("preserve_unknown_fields", true)),
			"emit_world_feed": bool(options.get("emit_world_feed", true))
		},
		"filters": {
			"categories": _safe_array(options.get("categories", [])),
			"specific_item_ids": _safe_array(options.get("specific_item_ids", [])),
			"excluded_item_ids": _safe_array(options.get("excluded_item_ids", []))
		},
		"persistence": {
			"generationally_persistent": true,
			"save_persistent": true,
		},
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	inheritance_contract_registry [str(owner.id)] = contract.duplicate(true)
	last_inheritance_report = {
		"success": true,
		"schema": "eralife.inheritance_contract_create_report",
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"owner_id": int(owner.id),
		"heir_count": normalized_heirs.size()
	}
	return last_inheritance_report.duplicate(true)

func get_inheritance_contract(owner: Person) -> Dictionary:
	if owner == null:
		return {}
	return _safe_dictionary(inheritance_contract_registry.get(str(owner.id), {}))

func execute_inheritance_contract(owner: Person, contract_id: String = "", context: Dictionary = {}) -> Dictionary:
	if owner == null:
		return { "success": false, "reason": "A valid owner is required."}

	var contract: Dictionary = get_inheritance_contract(owner)
	if contract.is_empty():
		return { "success": false, "reason": "No inheritance contract found for %s." % _person_label(owner)}

	if str(contract_id).strip_edges() != "" and str(contract.get("id", "")) != str(contract_id).strip_edges():
		return { "success": false, "reason": "Inheritance contract id mismatch."}

	var rules: Dictionary = _safe_dictionary(contract.get("rules", {}))
	var filters: Dictionary = _safe_dictionary(contract.get("filters", {}))
	var heirs: Array = _safe_array(contract.get("heirs", []))
	var owner_inventory: Dictionary = get_inventory(owner)
	var transfer_reports: Array = []
	var assigned_counts: Dictionary = {}

	for category in owner_inventory.keys():
		var clean_category: String = str(category)
		if not _inheritance_category_allowed(clean_category, filters):
			continue

		var items: Array = []
		if typeof(owner_inventory.get(category, [])) == TYPE_ARRAY:
			items = owner_inventory.get(category, [])

		var item_ids_to_remove: Array = []

		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = _normalize_belonging_entry(owner, raw_item as Dictionary, clean_category, bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
			if bool(item.get("mirrored_asset", false)) and not bool(rules.get("include_mirrored_assets", false)):
				continue
			if not _inheritance_item_allowed(item, filters):
				continue

			var heir_row: Dictionary = _select_inheritance_heir_for_item(item, clean_category, heirs, assigned_counts)
			var heir: Person = _person_from_id(int(heir_row.get("person_id", -1)))
			if heir == null:
				continue

			var transfer_packet: Dictionary = _build_transfer_packet(owner, heir, item, clean_category, {
				"transfer_type": "inheritance",
				"source": "execute_inheritance_contract",
				"contract_id": str(contract.get("id", "")),
				"context": context.duplicate(true)
			})

			item ["relationships"] = _transfer_relationships_for_item(owner, heir, item, clean_category, transfer_packet)
			item ["inheritance_history"] = _safe_array(item.get("inheritance_history", []))
			item ["inheritance_history"].append(transfer_packet)

			add_item(heir, item, clean_category)
			item_ids_to_remove.append(int(item.get("id", -1)))

			var heir_key: String = str(heir.id)
			assigned_counts [heir_key] = int(assigned_counts.get(heir_key, 0)) + 1

			transfer_reports.append({
				"item_id": int(item.get("id", -1)),
				"item_name": str(item.get("display_name", item.get("name", "an item"))),
				"category": clean_category,
				"from_id": int(owner.id),
				"to_id": int(heir.id),
				"to_name": _person_label(heir),
				"contract_id": str(item.get("contract_id", "")),
				"transfer_packet": transfer_packet.duplicate(true)
			})

		for remove_id in item_ids_to_remove:
			remove_item_by_id(owner, clean_category, int(remove_id))

	if bool(rules.get("emit_world_feed", true)) and gs != null and gs.has_method("push_world_feed") and not transfer_reports.is_empty():
		gs.push_world_feed(
			"📜 %s's belongings passed through an inheritance contract." % _person_label(owner),
			{
				"npc_id": owner.id,
				"personally_relevant": owner == gs.player,
				"category": "belongings",
				"event_name": "belongings_inheritance_resolved",
				"source": "belongings_engine",
				"contract_id": str(contract.get("id", "")),
				"transfer_count": transfer_reports.size()
			}
		)

	last_inheritance_report = {
		"success": true,
		"schema": "eralife.inheritance_execution_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(contract.get("id", "")),
		"owner_id": int(owner.id),
		"transfer_count": transfer_reports.size(),
		"transfers": transfer_reports,
		"executed_at_year": _current_year(),
		"executed_at_ms": int(Time.get_ticks_msec())
	}

	_record_belongings_ledger(last_inheritance_report)
	return last_inheritance_report.duplicate(true)

func age_belongings_for_year(target_year: int = -999999999) -> Dictionary:
	var year: int = target_year
	if year == -999999999:
		year = _current_year()

	var touched: int = 0
	for owner_id in belongings.keys():
		if typeof(belongings.get(owner_id, {})) != TYPE_DICTIONARY:
			continue
		var inventory: Dictionary = belongings.get(owner_id, {})
		for category in inventory.keys():
			if typeof(inventory.get(category, [])) != TYPE_ARRAY:
				continue
			var items: Array = inventory.get(category, [])
			for i in range(items.size()):
				if typeof(items [i]) != TYPE_DICTIONARY:
					continue
				var item: Dictionary = (items [i] as Dictionary).duplicate(true)
				item ["age"] = _item_age_for_year(item, year)
				item ["age_years"] = int(item.get("age", 0))
				items [i] = item
				touched += 1
			inventory [category] = items
		belongings [owner_id] = inventory

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.belongings_age_report",
		"version": CONTRACT_VERSION,
		"target_year": year,
		"touched_item_count": touched,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_record_belongings_ledger(report)
	return report

func _normalize_belongings_store(raw_store: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for owner_id in raw_store.keys():
		if typeof(raw_store.get(owner_id, {})) != TYPE_DICTIONARY:
			continue
		var inventory: Dictionary = raw_store.get(owner_id, {})
		out [owner_id] = {}
		var owner: Person = _person_from_id(int(owner_id))
		for category in inventory.keys():
			var clean_category: String = str(category).strip_edges()
			if clean_category == "":
				clean_category = "Misc"
			out [owner_id] [clean_category] = []
			if typeof(inventory.get(category, [])) != TYPE_ARRAY:
				continue
			for raw_item in inventory.get(category, []):
				if typeof(raw_item) != TYPE_DICTIONARY:
					continue
				var normalized: Dictionary = {}
				if owner != null:
					normalized = _normalize_belonging_entry(owner, raw_item as Dictionary, clean_category, bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
				else:
					normalized = (raw_item as Dictionary).duplicate(true)
					normalized ["category"] = clean_category
				out [owner_id] [clean_category].append(normalized)
	return out

func _normalize_belonging_entry(
	person: Person,
	item: Dictionary,
	category: String,
	mirror_only:= false,
	assign_missing_id:= true
) -> Dictionary:
	var entry: Dictionary = item.duplicate(true)
	var clean_category: String = str(
		category
	).strip_edges()

	if clean_category == "":
		clean_category = str(
			entry.get(
				"category",
				"Misc"
			)
		).strip_edges()

	if clean_category == "":
		clean_category = "Misc"

	entry [
		"category"
	] = clean_category
	entry [
		"mirrored_asset"
	] = bool(
		mirror_only
	)

	var resolved_name: String = str(
		entry.get(
			"name",
			""
		)
	).strip_edges()

	if resolved_name == "":
		resolved_name = str(
			entry.get(
				"display_name",
				entry.get(
					"nickname",
					entry.get(
						"type",
						"Unnamed Item"
					)
				)
			)
		).strip_edges()

	if resolved_name == "":
		resolved_name = "Unnamed Item"

	entry [
		"name"
	] = resolved_name

	if str(
		entry.get(
			"display_name",
			""
		)
	).strip_edges() == "":
		entry [
			"display_name"
		] = resolved_name

	var resolved_type: String = str(
		entry.get(
			"type",
			""
		)
	).strip_edges()

	if resolved_type == "":
		resolved_type = str(
			entry.get(
				"subtype",
				entry.get(
					"asset_kind",
					"Item"
				)
			)
		).strip_edges()

	if resolved_type == "":
		resolved_type = clean_category

	entry [
		"type"
	] = resolved_type

	var resolved_value: int = int(
		entry.get(
			"value",
			-1
		)
	)

	if (
		resolved_value <= 0
		and entry.has(
			"worth"
		)
	):
		resolved_value = int(
			entry.get(
				"worth",
				0
			)
		)

	if (
		resolved_value <= 0
		and entry.has(
			"price"
		)
	):
		resolved_value = int(
			entry.get(
				"price",
				0
			)
		)

	if (
		resolved_value <= 0
		and entry.has(
			"estimated_value"
		)
	):
		resolved_value = int(
			entry.get(
				"estimated_value",
				0
			)
		)

	if resolved_value > 0:
		entry [
			"value"
		] = resolved_value

	if (
		int(
			entry.get(
				"id",
				-1
			)
		) <= 0
		and assign_missing_id
		and _auto_assign_item_ids()
	):
		entry [
			"id"
		] = _next_item_id()

	if (
		str(
			entry.get(
				"origin_era",
				""
			)
		).strip_edges() == ""
		and str(
			entry.get(
				"era_name",
				""
			)
		).strip_edges() != ""
	):
		entry [
			"origin_era"
		] = str(
			entry.get(
				"era_name",
				""
			)
		)

	if str(
		entry.get(
			"origin_era",
			""
		)
	).strip_edges() == "":
		entry [
			"origin_era"
		] = _current_era_name()

	if (
		int(
			entry.get(
				"acquired_year",
				0
			)
		) == 0
		and typeof(
			entry.get(
				"provenance",
				{}
			)
		) == TYPE_DICTIONARY
	):
		var provenance: Dictionary = entry.get(
			"provenance",
			{}
		)

		entry [
			"acquired_year"
		] = int(
			provenance.get(
				"acquired_year",
				0
			)
		)

	if int(
		entry.get(
			"acquired_year",
			0
		)
	) == 0:
		entry [
			"acquired_year"
		] = _current_year()

	var contract: Dictionary = _resolve_item_contract(
		entry,
		clean_category
	)

	var contract_id: String = str(
		contract.get(
			"id",
			entry.get(
				"contract_id",
				""
			)
		)
	).strip_edges()

	if contract_id == "":
		contract_id = "generic_item"

	entry [
		"contract_id"
	] = contract_id
	entry [
		"item_contract"
	] = contract.duplicate(true)

	entry [
		"identity"
	] = _compose_item_identity(
		person,
		entry,
		clean_category,
		contract
	)
	entry [
		"reality_identity"
	] = _safe_dictionary(
		entry.get(
			"identity",
			{}
		)
	).duplicate(true)
	entry [
		"affordances"
	] = _merge_unique_arrays(
		_safe_array(
			contract.get(
				"affordances",
				[]
			)
		),
		_safe_array(
			entry.get(
				"affordances",
				[]
			)
		)
	)
	entry [
		"relationships"
	] = _compose_item_relationships(
		person,
		entry,
		clean_category,
		contract
	)
	entry [
		"persistence"
	] = _compose_item_persistence(
		entry,
		contract
	)
	entry [
		"age"
	] = _item_age_for_year(
		entry,
		_current_year()
	)
	entry [
		"age_years"
	] = int(
		entry.get(
			"age",
			0
		)
	)

	entry [
		"actions"
	] = _ensure_weapon_self_mortality_action(
		entry,
		clean_category,
		_safe_array(
			entry.get(
				"actions",
				[]
			)
		)
	)

	entry [
		"reality_contract"
	] = _build_item_reality_packet(
		person,
		entry,
		clean_category,
		contract
	)

	return entry
func _belonging_entry_is_weapon(
	item: Dictionary,
	category: String
) -> bool:
	if str(
		category
	).strip_edges().to_lower() == "weapons":
		return true

	if str(
		item.get(
			"asset_kind",
			""
		)
	).strip_edges().to_lower() == "weapon":
		return true

	if str(
		item.get(
			"type",
			""
		)
	).strip_edges().to_lower() == "weapon":
		return true

	for raw_domain in _safe_array(
		item.get(
			"object_domains",
			[]
		)
	):
		if str(
			raw_domain
		).strip_edges().to_lower() == "weapon":
			return true

	return not _safe_dictionary(
		item.get(
			"weapon_contract",
			{}
		)
	).is_empty()


func _ensure_weapon_self_mortality_action(
	item: Dictionary,
	category: String,
	actions: Array
) -> Array:
	var out: Array = actions.duplicate(true)

	if not _belonging_entry_is_weapon(
		item,
		category
	):
		return out

	for raw_action in out:
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		)

		var action_id: String = str(
			action.get(
				"id",
				action.get(
					"action_id",
					""
				)
			)
		).strip_edges().to_lower()

		var payload: Dictionary = _safe_dictionary(
			action.get(
				"payload",
				{}
			)
		)

		var payload_action_id: String = str(
			payload.get(
				"action_id",
				""
			)
		).strip_edges().to_lower()

		if (
			action_id == "weapon_end_it_all"
			or payload_action_id == "end_it_all_with_weapon"
		):
			return out

	var weapon_name: String = str(
		item.get(
			"display_name",
			item.get(
				"name",
				"Weapon"
			)
		)
	).strip_edges()

	if weapon_name == "":
		weapon_name = "Weapon"

	out.append(
		{
			"id": "weapon_end_it_all",
			"label": "End it all",
			"engine_property": "life_engine",
			"method": "resolve_weapon_self_mortality_intent",
			"call_mode": "player_payload",
			"refresh_after": false,



			"authority_deferred": true,




			"skip_crr_observation": true,

			"payload": {
				"action_id": "end_it_all_with_weapon",
				"belonging_item_id": int(
					item.get(
						"id",
						-1
					)
				),
				"catalog_object_id": str(
					item.get(
						"catalog_object_id",
						""
					)
				),
				"instance_object_id": str(
					item.get(
						"instance_object_id",
						item.get(
							"object_id",
							""
						)
					)
				),
				"weapon_name": weapon_name,
				"self_inflicted": true,
				"source": "belongings.weapon_self_mortality",
				"skip_crr_observation": true,
				"ui_is_renderer_only": true
			},
			"ui_is_renderer_only": true
		}
	)

	return out

func _resolve_item_contract(item: Dictionary, category: String) -> Dictionary:
	var direct_id: String = str(item.get("contract_id", item.get("item_contract_id", ""))).strip_edges()
	if direct_id != "" and item_contract_registry.has(direct_id):
		return _safe_dictionary(item_contract_registry.get(direct_id, {}))

	var embedded_contract: Dictionary = _safe_dictionary(item.get("item_contract", {}))
	if not embedded_contract.is_empty():
		return _normalize_item_contract(embedded_contract, item, category)

	var inferred_id: String = _infer_item_contract_id(item, category)
	if inferred_id != "" and item_contract_registry.has(inferred_id):
		return _safe_dictionary(item_contract_registry.get(inferred_id, {}))

	if item_contract_registry.has("generic_item"):
		return _normalize_item_contract(_safe_dictionary(item_contract_registry.get("generic_item", {})), item, category)

	return _normalize_item_contract({}, item, category)

func _infer_item_contract_id(item: Dictionary, category: String) -> String:
	var clean_category: String = str(category).strip_edges().to_lower()
	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	var item_name: String = str(item.get("name", item.get("display_name", ""))).strip_edges().to_lower()

	if str(item.get("contract_id", "")).strip_edges() != "":
		return str(item.get("contract_id", "")).strip_edges()
	if item_name == "time stone" or item_name.find("time stone") >= 0:
		return "time_stone"
	if item_name.find("flame sword") >= 0 or item_name.find("flaming sword") >= 0:
		return "flame_sword_contract"
	if clean_category == "dragon balls" or item_type == "dragonball" or item_name.find("dragon ball") >= 0:
		return "dragonball"
	if item_type == "tradegood" or clean_category == "trade goods":
		return "trade_good"
	return "generic_item"

func _normalize_item_contract(contract: Dictionary, fallback_item: Dictionary = {}, category: String = "") -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var fallback_id: String = _contract_id_from_fallback(fallback_item, category)

	out ["schema"] = str(out.get("schema", ITEM_CONTRACT_SCHEMA))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", fallback_id)).strip_edges()
	if str(out.get("id", "")).strip_edges() == "":
		out ["id"] = "generic_item"

	out ["display_name"] = str(out.get("display_name", fallback_item.get("display_name", fallback_item.get("name", str(out.get("id", "Generic Item"))))))
	out ["category"] = str(out.get("category", fallback_item.get("category", category))).strip_edges()

	if typeof(out.get("identity", {})) != TYPE_DICTIONARY:
		out ["identity"] = {}
	var identity: Dictionary = _safe_dictionary(out.get("identity", {}))
	if str(identity.get("type", "")).strip_edges() == "":
		identity ["type"] = str(fallback_item.get("type", out.get("category", "item"))).strip_edges().to_lower()
	if str(identity.get("authority", "")).strip_edges() == "":
		identity ["authority"] = str(out.get("authority", "local_event")).strip_edges().to_lower()
	out ["identity"] = identity

	if typeof(out.get("affordances", [])) != TYPE_ARRAY:
		out ["affordances"] = []

	if typeof(out.get("relationships", {})) != TYPE_DICTIONARY:
		out ["relationships"] = {}

	if typeof(out.get("persistence", {})) != TYPE_DICTIONARY:
		out ["persistence"] = {}
	var persistence: Dictionary = _safe_dictionary(out.get("persistence", {}))
	persistence ["save_persistent"] = bool(persistence.get("save_persistent", true))
	persistence ["generationally_persistent"] = bool(persistence.get("generationally_persistent", true))
	persistence ["age_persistent"] = bool(persistence.get("age_persistent", true))
	persistence ["preserve_unknown_fields"] = bool(persistence.get("preserve_unknown_fields", true))
	out ["persistence"] = persistence

	if typeof(out.get("inheritance", {})) != TYPE_DICTIONARY:
		out ["inheritance"] = {
			"eligible": true,
			"default_policy": "contract_weighted"
		}

	return out

func _contract_id_from_fallback(item: Dictionary, category: String) -> String:
	var clean_type: String = str(item.get("type", category)).strip_edges().to_lower().replace(" ", "_")
	var clean_name: String = str(item.get("name", item.get("display_name", ""))).strip_edges().to_lower().replace(" ", "_")
	if clean_name != "":
		return clean_name
	if clean_type != "":
		return clean_type
	return "generic_item"

func _compose_item_identity(person: Person, item: Dictionary, category: String, contract: Dictionary) -> Dictionary:
	var identity: Dictionary = _safe_dictionary(contract.get("identity", {}))
	var item_identity: Dictionary = _safe_dictionary(item.get("identity", {}))
	identity = _merge_dict(identity, item_identity)

	identity ["category"] = str(category)
	identity ["item_id"] = int(item.get("id", -1))
	identity ["item_name"] = str(item.get("display_name", item.get("name", "Unnamed Item")))
	identity ["owner_id"] = int(person.id) if person != null else int(identity.get("owner_id", -1))
	identity ["owner_name"] = _person_label(person)
	identity ["contract_id"] = str(contract.get("id", item.get("contract_id", "generic_item")))
	identity ["owned_reality_object"] = true

	if not identity.has("authority"):
		identity ["authority"] = str(contract.get("authority", "local_event")).strip_edges().to_lower()

	return identity

func _compose_item_relationships(person: Person, item: Dictionary, category: String, contract: Dictionary) -> Dictionary:
	var relationships: Dictionary = _safe_dictionary(contract.get("relationships", {}))
	relationships = _merge_dict(relationships, _safe_dictionary(item.get("relationships", {})))

	relationships ["owned_by"] = int(person.id) if person != null else int(relationships.get("owned_by", -1))
	relationships ["owner_name"] = _person_label(person)
	relationships ["category"] = str(category)
	relationships ["ownership_type"] = str(relationships.get("ownership_type", "personal_belonging"))
	relationships ["bound_to"] = relationships.get("bound_to", int(person.id) if person != null else -1)
	relationships ["recognition"] = str(relationships.get("recognition", contract.get("recognition", "owned_object")))

	var item_relationship_profile: Dictionary = _item_relationship_summary_for_item(_item_key(item))
	if not item_relationship_profile.is_empty():
		relationships ["item_relationships"] = item_relationship_profile

	return relationships

func _compose_item_persistence(item: Dictionary, contract: Dictionary) -> Dictionary:
	var persistence: Dictionary = _safe_dictionary(contract.get("persistence", {}))
	persistence = _merge_dict(persistence, _safe_dictionary(item.get("persistence", {})))
	persistence ["save_persistent"] = bool(persistence.get("save_persistent", true))
	persistence ["generationally_persistent"] = bool(persistence.get("generationally_persistent", true))
	persistence ["age_persistent"] = bool(persistence.get("age_persistent", true))
	persistence ["backwards_compatible"] = bool(persistence.get("backwards_compatible", true))
	persistence ["preserve_unknown_fields"] = bool(persistence.get("preserve_unknown_fields", true))
	return persistence

func _build_item_reality_packet(person: Person, item: Dictionary, category: String, contract: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.belonging_reality_object",
		"version": CONTRACT_VERSION,
		"item_id": int(item.get("id", -1)),
		"contract_id": str(contract.get("id", item.get("contract_id", "generic_item"))),
		"owner_id": int(person.id) if person != null else -1,
		"category": str(category),
		"identity": _safe_dictionary(item.get("identity", {})),
		"affordances": _safe_array(item.get("affordances", [])),
		"relationships": _safe_dictionary(item.get("relationships", {})),
		"persistence": _safe_dictionary(item.get("persistence", {})),
		"age": int(item.get("age", 0)),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _actions_from_item_contract(_actor: Person, item: Dictionary, category: String, contract: Dictionary) -> Array:
	var out: Array = []
	var affordances: Array = _merge_unique_arrays(_safe_array(contract.get("affordances", [])), _safe_array(item.get("affordances", [])))

	for raw_affordance in affordances:
		var affordance: String = str(raw_affordance).strip_edges().to_lower()
		match affordance:
			"time_loop":
				out.append(_contract_action(item, "time_loop", "⏳ Start Time Loop", "artifacts_engine", "resolve_artifact_action", {
					"action": "time_loop",
					"category": category
				}))
			"rewind":
				out.append(_contract_action(item, "rewind", "↩️ Rewind Moment", "artifacts_engine", "resolve_artifact_action", {
					"action": "rewind",
					"category": category
				}))
			"future_sight":
				out.append(_contract_action(item, "future_sight", "👁️ Glimpse Future", "artifacts_engine", "resolve_artifact_action", {
					"action": "future_sight",
					"category": category
				}))
			"melee_attack":
				out.append(_contract_action(item, "melee_attack", "⚔️ Attack With Item", "scenario_engine", "queue_external_scenario", {
					"scenario_type": "item_combat",
					"action": "melee_attack",
					"category": category
				}))
			"ignite_targets":
				out.append(_contract_action(item, "ignite_targets", "🔥 Ignite Target", "scenario_engine", "queue_external_scenario", {
					"scenario_type": "item_combat",
					"action": "ignite_targets",
					"category": category
				}))
			"intimidation_presence":
				out.append(_contract_action(item, "intimidation_presence", "😨 Intimidate", "relationship_engine", "resolve_social_action", {
					"action": "intimidation_presence",
					"category": category
				}))
			"summon_dragon_balls":
				out.append(_contract_action(item, "summon_dragon_balls", "🐉 Summon All 7 Dragon Balls", "red_bonnet_engine", "summon_dragon_balls_to_inventory", {
					"action": "summon_dragon_balls",
					"category": category
				}))
			"inspect_myth":
				out.append(_contract_action(item, "inspect_myth", "📖 Inspect Myth", "belongings_engine", "resolve_belongings_item_action", {
					"action": "inspect_myth",
					"category": category
				}))
			"bond_with_item":
				out.append(_contract_action(item, "bond_with_item", "🤝 Bond With Item", "belongings_engine", "resolve_belongings_item_action", {
					"action": "bond_with_item",
					"category": category
				}))
			"maintain":
				out.append(_contract_action(item, "maintain", "🛠 Maintain", "belongings_engine", "resolve_belongings_item_action", {
					"action": "maintain",
					"category": category
				}))
			"drive":
				out.append(_contract_action(item, "drive", "🚗 Drive", "belongings_engine", "resolve_belongings_item_action", {
					"action": "drive",
					"category": category
				}))
			"display":
				out.append(_contract_action(item, "display", "🏛 Display Publicly", "belongings_engine", "resolve_belongings_item_action", {
					"action": "display",
					"category": category
				}))
			"sell":
				out.append(_contract_action(item, "sell", "💰 Sell", "global_market_engine", "sell_item_payload", {
					"action": "sell",
					"category": category
				}))
			"trade":
				out.append(_contract_action(item, "trade", "🤝 Trade", "global_market_engine", "trade_item_payload", {
					"action": "trade",
					"category": category
				}))
	return out
func _contract_action(item: Dictionary, action_id: String, label: String, engine_property: String, method: String, payload: Dictionary = {}) -> Dictionary:
	var final_payload: Dictionary = payload.duplicate(true)
	final_payload ["source"] = "belongings_inventory"
	final_payload ["source_item"] = item.duplicate(true)
	final_payload ["contract_id"] = str(item.get("contract_id", ""))

	return {
		"id": "%s_%s" % [action_id, str(item.get("id", item.get("contract_id", "item")))],
		"label": label,
		"kind": "engine_call",
		"engine_property": engine_property,
		"method": method,
		"call_mode": "player_payload",
		"payload": final_payload,
		"refresh_after": true
	}

func _build_transfer_packet(from_person: Person, to_person: Person, item: Dictionary, category: String, context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.belonging_transfer_packet",
		"version": CONTRACT_VERSION,
		"transfer_type": str(context.get("transfer_type", "transfer")),
		"source": str(context.get("source", "belongings_engine")),
		"from_id": int(from_person.id) if from_person != null else -1,
		"from_name": _person_label(from_person),
		"to_id": int(to_person.id) if to_person != null else -1,
		"to_name": _person_label(to_person),
		"item_id": int(item.get("id", -1)),
		"item_name": str(item.get("display_name", item.get("name", "an item"))),
		"category": str(category),
		"contract_id": str(item.get("contract_id", "")),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _transfer_relationships_for_item(from_person: Person, to_person: Person, item: Dictionary, category: String, transfer_packet: Dictionary) -> Dictionary:
	var relationships: Dictionary = _safe_dictionary(item.get("relationships", {}))
	relationships ["previous_owner_id"] = int(from_person.id) if from_person != null else int(relationships.get("owned_by", -1))
	relationships ["previous_owner_name"] = _person_label(from_person)
	relationships ["owned_by"] = int(to_person.id) if to_person != null else -1
	relationships ["owner_name"] = _person_label(to_person)
	relationships ["bound_to"] = relationships.get("bound_to", int(to_person.id) if to_person != null else -1)
	relationships ["category"] = str(category)
	relationships ["last_transfer"] = transfer_packet.duplicate(true)
	return relationships




func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return
	var policy: Dictionary = _safe_dictionary(active_contract.get("runtime_policy", {}))
	if bool(policy.get("age_items_each_year", true)):
		age_belongings_for_year(_current_year())
	if bool(policy.get("object_myth_yearly_tick", true)):
		_yearly_object_myth_tick(_current_year())

func resolve_belongings_item_action(actor_or_payload = {}, maybe_payload: Dictionary = {}) -> Dictionary:
	var actor: Person = gs.player if gs != null else null
	var payload: Dictionary = {}

	if typeof(actor_or_payload) == TYPE_DICTIONARY:
		payload = actor_or_payload
	elif typeof(maybe_payload) == TYPE_DICTIONARY:
		payload = maybe_payload
		if actor_or_payload is Person:
			actor = actor_or_payload

	if typeof(payload) != TYPE_DICTIONARY:
		return { "success": false, "text": "Belongings action payload must be a Dictionary."}

	if gs == null or actor == null:
		return { "success": false, "text": "No active actor could resolve that item action."}

	var action: String = str(payload.get("action", payload.get("action_id", ""))).strip_edges().to_lower()
	var source_item: Dictionary = _safe_dictionary(payload.get("source_item", {}))
	var category: String = str(payload.get("category", source_item.get("category", "Misc"))).strip_edges()
	if category == "":
		category = "Misc"
	if (
		category == "Vehicles"
		and gs.vehicle_engine != null
		and gs.vehicle_engine.has_method(
			"run_asset_action"
		)
	):
		return gs.vehicle_engine.run_asset_action(
			actor,
			int(
				source_item.get(
					"id",
					source_item.get(
						"asset_id",
						-1
					)
				)
			),
			action
		)
	match action:
		"inspect_myth":
			var myth: Dictionary = get_item_myth_profile(source_item)
			return {
				"success": true,
				"popup_title": "Object Myth",
				"popup_text": _format_object_myth_text(source_item, myth),
				"popup_footer": "Belongings → Object Consciousness → UPCE memory.",
				"myth": myth.duplicate(true)
			}

		"bond_with_item", "maintain", "drive":
			return grow_bond_with_item(actor, category, int(source_item.get("id", -1)), {
				"action": action,
				"source": "belongings_inventory",
				"source_item": source_item.duplicate(true)
			})

		"display":
			return record_item_use_by_contract(actor, str(source_item.get("contract_id", "")), category, {
				"event_type": "item_displayed_publicly",
				"action": action,
				"source": "belongings_inventory",
				"public_visibility": true,
				"source_item": source_item.duplicate(true)
			})

		"access_federal_republic_crown_hub":
			return {
				"success": true,
				"type": "open_crown_hub",
				"open_crown_hub": true,
				"crown_hub_section": "throne",
				"crown_hub_layout_variant": "federal_republic",
				"popup_title": "White House Access",
				"popup_text": "You access the Federal Republic command surface through The White House residence contract.",
				"popup_footer": "Opening Federal Republic Crown Hub.",
				"text": "I accessed The White House federal office surface.",
				"log_to_diary": false,
				"force_immediate_popup": true,
				"source_item": source_item.duplicate(true)
			}

		"throw_official_residence_party":
			return _official_residence_party_choice_result(actor, source_item)

		"throw_official_residence_party_execute":
			return _official_residence_party_execute(actor, source_item, payload)

		_:
			return {
				"success": false,
				"text": "That belonging does not know how to resolve %s yet." % action
			}
func _official_residence_party_choice_result(_actor: Person, source_item: Dictionary) -> Dictionary:
	return {
		"success": true,
		"popup_title": "Throw Party",
		"popup_text": "Choose the scale and privacy level for the official residence party. Attendance will be resolved by fame, presidential approval, privacy, and party size.",
		"popup_footer": "Intent is not action. Choosing a party option commits the party.",
		"force_immediate_popup": true,
		"choices": [
			_official_residence_party_choice("small_private", "Small Private Party", "small", "private", source_item),
			_official_residence_party_choice("medium_invite", "Invite-Only Reception", "medium", "invite_only", source_item),
			_official_residence_party_choice("large_public", "Large Public Celebration", "large", "public", source_item),
			_official_residence_party_choice("national_public", "National White House Event", "national", "public", source_item)
		]
	}


func _official_residence_party_choice(choice_id: String, label: String, size: String, privacy: String, source_item: Dictionary) -> Dictionary:
	return {
		"id": choice_id,
		"label": label,
		"text": label,
		"detail_action": "engine_call",
		"engine_property": "belongings_engine",
		"method": "resolve_belongings_item_action",
		"payload": {
			"action": "throw_official_residence_party_execute",
			"party_size": size,
			"privacy": privacy,
			"category": "Government Residences",
			"source_item": source_item.duplicate(true)
		},
		"preview_lines": [
			"Size: %s" % size.capitalize(),
			"Privacy: %s" % privacy.replace("_", " ").capitalize(),
			"Attendance resolves after commitment."
		]
	}


func _official_residence_party_execute(actor: Person, source_item: Dictionary, payload: Dictionary) -> Dictionary:
	var party_size: String = str(payload.get("party_size", "medium")).strip_edges().to_lower()
	var privacy: String = str(payload.get("privacy", "invite_only")).strip_edges().to_lower()
	var attendance: int = _official_residence_party_attendance(actor, source_item, party_size, privacy)

	var party_label: String = party_size.capitalize()
	var privacy_label: String = privacy.replace("_", " ").capitalize()

	var text: String = "I threw a %s, %s party at The White House. %s people attended." % [
		privacy_label,
		party_label,
		_format_official_residence_number(attendance)
	]

	return {
		"success": true,
		"popup_title": "White House Party",
		"popup_text": "%s people attended your %s, %s White House party." % [
			_format_official_residence_number(attendance),
			privacy_label,
			party_label
		],
		"popup_footer": "Attendance resolved from fame, approval, privacy, and party size.",
		"text": text,
		"log_to_diary": true,
		"party_attendance": attendance,
		"party_size": party_size,
		"privacy": privacy,
		"source_item": source_item.duplicate(true)
	}


func _official_residence_party_attendance(actor: Person, source_item: Dictionary, party_size: String, privacy: String) -> int:
	var actor_fame: int = int(actor.fame) if actor != null else 0
	var actor_approval: int = int(actor.approval) if actor != null else 0

	var president_fame: int = actor_fame
	var president_approval: int = actor_approval
	var legal_owner_id: int = int(source_item.get("legal_owner_id", -1))

	if gs != null and legal_owner_id > 0 and gs.has_method("get_npc_by_id"):
		var president: Person = gs.get_npc_by_id(legal_owner_id)
		if president != null:
			president_fame = int(president.fame)
			president_approval = int(president.approval)

	var base: int = 250
	match party_size:
		"small":
			base = 80
		"medium":
			base = 420
		"large":
			base = 1800
		"national":
			base = 6200
		_:
			base = 420

	var privacy_factor: float = 1.0
	match privacy:
		"private":
			privacy_factor = 0.28
		"invite_only":
			privacy_factor = 0.72
		"public":
			privacy_factor = 1.38
		_:
			privacy_factor = 1.0

	var draw: float = float(base)
	draw += float(actor_fame) * 6.0
	draw += float(actor_approval) * 4.0
	draw += float(president_fame) * 14.0
	draw += float(president_approval) * 18.0

	var attendance: int = int(round(draw * privacy_factor))
	return max(8, attendance)


func _format_official_residence_number(value: int) -> String:
	var number: int = int(value)
	var sign_text: String = ""
	if number < 0:
		sign_text = "-"
		number = abs(number)

	var raw_text: String = str(number)
	var out: String = ""
	var counter: int = 0

	for i in range(raw_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			out = "," + out
		out = raw_text.substr(i, 1) + out
		counter += 1

	return sign_text + out

func record_item_use_by_contract(actor: Person, contract_id: String, category: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "A valid actor is required."}
	var clean_contract_id: String = str(contract_id).strip_edges()
	if clean_contract_id == "":
		return { "success": false, "text": "A valid item contract id is required."}

	var inventory: Dictionary = get_inventory(actor)
	for raw_category in inventory.keys():
		var clean_category: String = str(raw_category)
		if str(category).strip_edges() != "" and clean_category != str(category).strip_edges():
			continue
		var items: Array = []
		if typeof(inventory.get(raw_category, [])) == TYPE_ARRAY:
			items = inventory.get(raw_category, [])
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = _normalize_belonging_entry(actor, raw_item as Dictionary, clean_category, bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
			if str(item.get("contract_id", "")).strip_edges() != clean_contract_id:
				continue
			var event_type: String = str(context.get("event_type", "item_used")).strip_edges()
			_record_belongings_event(event_type, actor, item, clean_category, context)
			return {
				"success": true,
				"schema": "eralife.item_use_report",
				"version": CONTRACT_VERSION,
				"contract_id": clean_contract_id,
				"item_id": int(item.get("id", -1)),
				"item_name": str(item.get("display_name", item.get("name", "item"))),
				"category": clean_category,
				"text": "%s answered reality through %s." % [_person_label(actor), str(item.get("display_name", item.get("name", "an item")))]
			}

	return {
		"success": false,
		"text": "%s does not currently hold an item with contract %s." % [_person_label(actor), clean_contract_id]
	}

func grow_bond_with_item(actor: Person, category: String, item_id: int, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "A valid actor is required."}
	if item_id <= 0:
		return { "success": false, "text": "A valid item id is required."}

	var item: Dictionary = _find_item_entry_for_actor(actor, category, item_id)
	if item.is_empty():
		return { "success": false, "text": "That item could not be found."}

	var item_key: String = _item_key(item)
	var state: Dictionary = _world_state()
	var bonds: Dictionary = _safe_dictionary(state.get("object_bond_registry", {}))
	var actor_key: String = str(actor.id)
	var item_bonds: Dictionary = _safe_dictionary(bonds.get(item_key, {}))
	var bond_row: Dictionary = _safe_dictionary(item_bonds.get(actor_key, {}))

	var action: String = str(context.get("action", "bond_with_item")).strip_edges().to_lower()
	var gain: float = 0.06
	match action:
		"maintain":
			gain = 0.08
		"drive":
			gain = 0.05
		"bond_with_item":
			gain = 0.1

	var old_score: float = float(bond_row.get("bond_score", 0.0))
	var new_score: float = clamp(old_score + gain, 0.0, 1.0)
	bond_row ["schema"] = "eralife.object_bond_profile"
	bond_row ["version"] = CONTRACT_VERSION
	bond_row ["actor_id"] = int(actor.id)
	bond_row ["actor_name"] = _person_label(actor)
	bond_row ["item_key"] = item_key
	bond_row ["item_id"] = item_id
	bond_row ["item_name"] = str(item.get("display_name", item.get("name", "an item")))
	bond_row ["bond_score"] = new_score
	bond_row ["bond_level"] = _object_bond_level(new_score)
	bond_row ["last_action"] = action
	bond_row ["updated_at_year"] = _current_year()
	bond_row ["updated_at_ms"] = int(Time.get_ticks_msec())

	item_bonds [actor_key] = bond_row
	bonds [item_key] = item_bonds
	state ["object_bond_registry"] = bonds
	_commit_world_state(state)

	_record_belongings_event("item_bond_deepened", actor, item, category, {
		"action": action,
		"bond_gain": gain,
		"bond_score": new_score,
		"public_visibility": false
	})

	return {
		"success": true,
		"schema": "eralife.object_bond_report",
		"version": CONTRACT_VERSION,
		"text": "%s feels more connected to %s." % [_person_label(actor), str(item.get("display_name", item.get("name", "the item")))],
		"popup_title": "Object Bond",
		"popup_text": "%s\n\nBond: %s (%d%%)" % [
			str(item.get("display_name", item.get("name", "The item"))),
			str(bond_row.get("bond_level", "familiar")).replace("_", " ").capitalize(),
			int(round(new_score * 100.0))
		],
		"popup_footer": "Normal objects can become emotionally persistent now.",
		"bond": bond_row.duplicate(true)
	}

func perceive_item(observer: Person, owner: Person, item: Dictionary, category: String, context: Dictionary = {}) -> Dictionary:
	if observer == null:
		return { "success": false, "reason": "Observer missing."}
	if owner == null:
		return { "success": false, "reason": "Owner missing."}
	if typeof(item) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Item missing."}

	var normalized: Dictionary = _normalize_belonging_entry(owner, item, category, bool(item.get("mirrored_asset", false)), false)
	var myth: Dictionary = get_item_myth_profile(normalized)
	var bias_profile: String = _observer_item_bias_profile(observer, normalized, myth, context)
	var interpretation: Dictionary = _interpret_item_for_observer(observer, owner, normalized, myth, bias_profile, context)

	var report: Dictionary = {
		"success": true,
		"schema": OBJECT_PERCEPTION_SCHEMA,
		"version": CONTRACT_VERSION,
		"observer_id": int(observer.id),
		"observer_name": _person_label(observer),
		"owner_id": int(owner.id),
		"owner_name": _person_label(owner),
		"item_key": _item_key(normalized),
		"item_id": int(normalized.get("id", -1)),
		"item_name": str(normalized.get("display_name", normalized.get("name", "an item"))),
		"category": str(category),
		"contract_id": str(normalized.get("contract_id", "")),
		"bias_profile": bias_profile,
		"interpretation": interpretation.duplicate(true),
		"myth": myth.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_store_object_perception(report)
	_route_upce_item_perception(report)
	return report

func get_item_myth_profile(item: Dictionary) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY:
		return {}
	var state: Dictionary = _world_state()
	var registry: Dictionary = _safe_dictionary(state.get("object_myth_registry", {}))
	var item_key: String = _item_key(item)
	var profile: Dictionary = _safe_dictionary(registry.get(item_key, {}))
	if profile.is_empty():
		profile = _empty_object_myth_profile(item)
	return profile

func get_item_bond_profile(actor: Person, item: Dictionary) -> Dictionary:
	if actor == null or typeof(item) != TYPE_DICTIONARY:
		return {}
	var state: Dictionary = _world_state()
	var bonds: Dictionary = _safe_dictionary(state.get("object_bond_registry", {}))
	var item_bonds: Dictionary = _safe_dictionary(bonds.get(_item_key(item), {}))
	return _safe_dictionary(item_bonds.get(str(actor.id), {}))
func get_item_relationship_profile(item: Dictionary) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY:
		return {}
	return _item_relationship_summary_for_item(_item_key(item))


func record_item_relationship(actor: Person, source_query: Dictionary, target_query: Dictionary, relationship_type: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "A valid actor is required."}

	var policy: Dictionary = _item_relationship_policy()
	if not bool(policy.get("enabled", true)):
		return { "success": false, "text": "Item relationships are disabled by contract."}

	var source_item: Dictionary = _find_first_item_entry_for_actor(actor, source_query)
	if source_item.is_empty():
		return { "success": false, "text": "No source item matched the relationship query."}

	var target_items: Array = _find_item_entries_for_actor(actor, target_query)
	if target_items.is_empty():
		return { "success": false, "text": "No target items matched the relationship query."}

	var reports: Array = []
	for raw_target in target_items:
		if typeof(raw_target) != TYPE_DICTIONARY:
			continue
		var target_item: Dictionary = raw_target as Dictionary
		if _item_key(source_item) == _item_key(target_item):
			continue
		var row: Dictionary = _record_item_relationship_packet(actor, source_item, target_item, relationship_type, context)
		if not row.is_empty():
			reports.append(row)

	if reports.is_empty():
		return { "success": false, "text": "No item relationship could be recorded."}

	return {
		"success": true,
		"schema": "eralife.item_relationship_batch_report",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"relationship_type": str(relationship_type).strip_edges().to_lower(),
		"source_item": _item_relationship_item_packet(source_item),
		"relationship_count": reports.size(),
		"relationships": reports,
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _record_item_relationship_packet(actor: Person, source_item: Dictionary, target_item: Dictionary, relationship_type: String, context: Dictionary = {}) -> Dictionary:
	var clean_type: String = str(relationship_type).strip_edges().to_lower()
	if clean_type == "":
		clean_type = "association"

	var source_key: String = _item_key(source_item)
	var target_key: String = _item_key(target_item)
	if source_key == "" or target_key == "":
		return {}

	var policy: Dictionary = _item_relationship_policy()
	var relationship_contracts: Dictionary = _safe_dictionary(policy.get("relationship_types", {}))
	var relationship_contract: Dictionary = _safe_dictionary(relationship_contracts.get(clean_type, {}))

	var base_weight: float = float(relationship_contract.get("base_weight", context.get("relationship_weight", 0.1)))
	var context_weight: float = float(context.get("relationship_weight", base_weight))
	var polarity: int = int(context.get("polarity", relationship_contract.get("polarity", _item_relationship_polarity(clean_type))))
	var strength_gain: float = abs(context_weight)
	var relationship_key: String = "%s>%s:%s" % [source_key, target_key, clean_type]

	var state: Dictionary = _world_state()
	var registry: Dictionary = _safe_dictionary(state.get("object_relationship_registry", {}))
	var ledger: Array = _safe_array(state.get("object_relationship_ledger", []))
	var row: Dictionary = _safe_dictionary(registry.get(relationship_key, {}))

	var old_strength: float = float(row.get("strength", 0.0))
	var new_strength: float = clamp(old_strength + strength_gain, 0.0, 1.0)

	var synergy_gain: float = 0.0
	var rivalry_gain: float = 0.0
	var rejection_gain: float = 0.0
	if polarity >= 0:
		synergy_gain = strength_gain
	else:
		if clean_type == "rejection":
			rejection_gain = strength_gain
		else:
			rivalry_gain = strength_gain

	row ["schema"] = "eralife.item_relationship_profile"
	row ["version"] = CONTRACT_VERSION
	row ["relationship_key"] = relationship_key
	row ["relationship_type"] = clean_type
	row ["source_key"] = source_key
	row ["target_key"] = target_key
	row ["source_item"] = _item_relationship_item_packet(source_item)
	row ["target_item"] = _item_relationship_item_packet(target_item)
	row ["actor_id"] = int(actor.id)
	row ["actor_name"] = _person_label(actor)
	row ["polarity"] = polarity
	row ["strength"] = new_strength
	row ["relationship_level"] = _item_relationship_level(new_strength)
	row ["synergy"] = clamp(float(row.get("synergy", 0.0)) + synergy_gain, 0.0, 1.0)
	row ["rivalry"] = clamp(float(row.get("rivalry", 0.0)) + rivalry_gain, 0.0, 1.0)
	row ["rejection"] = clamp(float(row.get("rejection", 0.0)) + rejection_gain, 0.0, 1.0)
	row ["last_context"] = context.duplicate(true)
	row ["updated_at_year"] = _current_year()
	row ["updated_at_ms"] = int(Time.get_ticks_msec())
	if not row.has("created_at_year"):
		row ["created_at_year"] = _current_year()
	if not row.has("created_at_ms"):
		row ["created_at_ms"] = int(Time.get_ticks_msec())

	var history: Array = _safe_array(row.get("history", []))
	history.append({
		"relationship_type": clean_type,
		"strength_gain": strength_gain,
		"polarity": polarity,
		"source": str(context.get("source", "belongings_engine")),
		"event_type": str(context.get("event_type", relationship_contract.get("myth_event_type", "item_relationship_formed"))),
		"year": _current_year(),
		"context": context.duplicate(true)
	})
	while history.size() > 40:
		history.pop_front()
	row ["history"] = history

	registry [relationship_key] = row.duplicate(true)

	var ledger_row: Dictionary = row.duplicate(true)
	ledger.append(ledger_row)
	var max_ledger: int = max(40, int(policy.get("max_relationship_ledger", 320)))
	while ledger.size() > max_ledger:
		ledger.pop_front()

	state ["object_relationship_registry"] = registry
	state ["object_relationship_ledger"] = ledger
	state ["last_object_relationship_report"] = row.duplicate(true)
	_commit_world_state(state)

	var myth_event_type: String = str(context.get("event_type", relationship_contract.get("myth_event_type", "item_relationship_formed")))
	_record_belongings_event(myth_event_type, actor, source_item, str(source_item.get("category", "")), {
		"source": str(context.get("source", "belongings_engine")),
		"public_visibility": bool(context.get("public_visibility", new_strength >= 0.35)),
		"relationship": row.duplicate(true),
		"target_item": target_item.duplicate(true)
	})

	if bool(policy.get("emit_world_feed", true)) and bool(context.get("public_visibility", new_strength >= 0.55)):
		_emit_item_relationship_world_feed(actor, row, context)

	if bool(policy.get("emit_event_bus", true)) and gs != null and "event_bus" in gs and gs.event_bus != null:
		gs.event_bus.emit("belongings.item_relationship.recorded", row.duplicate(true))

	return row.duplicate(true)


func _find_first_item_entry_for_actor(actor: Person, query: Dictionary) -> Dictionary:
	var matches: Array = _find_item_entries_for_actor(actor, query)
	if matches.is_empty():
		return {}
	if typeof(matches [0]) == TYPE_DICTIONARY:
		return (matches [0] as Dictionary).duplicate(true)
	return {}


func _find_item_entries_for_actor(actor: Person, query: Dictionary) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var inventory: Dictionary = get_inventory(actor)
	var max_results: int = int(query.get("max_results", 0))
	for raw_category in inventory.keys():
		var category: String = str(raw_category)
		if not _item_query_category_matches(category, query):
			continue

		var items: Array = []
		if typeof(inventory.get(raw_category, [])) == TYPE_ARRAY:
			items = inventory.get(raw_category, [])

		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = _normalize_belonging_entry(actor, raw_item as Dictionary, category, bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
			if not _item_matches_query(item, category, query):
				continue
			out.append(item)
			if max_results > 0 and out.size() >= max_results:
				return out

	return out


func _item_query_category_matches(category: String, query: Dictionary) -> bool:
	var clean_category: String = str(query.get("category", "")).strip_edges().to_lower()
	if clean_category == "":
		return true
	return str(category).strip_edges().to_lower() == clean_category


func _item_matches_query(item: Dictionary, _category: String, query: Dictionary) -> bool:
	if typeof(item) != TYPE_DICTIONARY:
		return false

	if query.has("item_id") and int(query.get("item_id", -1)) > 0:
		if int(item.get("id", -1)) != int(query.get("item_id", -1)):
			return false

	var item_contract_id: String = str(item.get("contract_id", "")).strip_edges().to_lower()
	var query_contract_id: String = str(query.get("contract_id", "")).strip_edges().to_lower()
	if query_contract_id != "" and item_contract_id != query_contract_id:
		return false

	var contract_ids: Array = _safe_array(query.get("contract_ids", []))
	if not contract_ids.is_empty():
		var found_contract: bool = false
		for raw_contract_id in contract_ids:
			if str(raw_contract_id).strip_edges().to_lower() == item_contract_id:
				found_contract = true
				break
		if not found_contract:
			return false

	var query_type: String = str(query.get("type", "")).strip_edges().to_lower()
	if query_type != "" and str(item.get("type", "")).strip_edges().to_lower() != query_type:
		return false

	var query_artifact_kind: String = str(query.get("artifact_kind", "")).strip_edges().to_lower()
	if query_artifact_kind != "" and str(item.get("artifact_kind", "")).strip_edges().to_lower() != query_artifact_kind:
		return false

	var query_stone_key: String = str(query.get("stone_key", "")).strip_edges().to_lower()
	if query_stone_key != "" and str(item.get("stone_key", "")).strip_edges().to_lower() != query_stone_key:
		return false

	var item_name: String = str(item.get("display_name", item.get("name", ""))).strip_edges().to_lower()
	var query_name: String = str(query.get("name", "")).strip_edges().to_lower()
	if query_name != "" and item_name != query_name:
		return false

	var name_contains: String = str(query.get("name_contains", "")).strip_edges().to_lower()
	if name_contains != "" and item_name.find(name_contains) < 0:
		return false

	var affordance: String = str(query.get("affordance", "")).strip_edges().to_lower()
	if affordance != "":
		var affordances: Array = _safe_array(item.get("affordances", []))
		var found_affordance: bool = false
		for raw_affordance in affordances:
			if str(raw_affordance).strip_edges().to_lower() == affordance:
				found_affordance = true
				break
		if not found_affordance:
			return false

	return true


func _item_relationship_policy() -> Dictionary:
	var out: Dictionary = {
		"enabled": true,
		"emit_world_feed": true,
		"emit_event_bus": true,
		"max_relationship_ledger": 320,
		"relationship_types": {
			"artifact_synergy": {
				"polarity": 1,
				"base_weight": 0.22,
				"myth_event_type": "item_relationship_formed"
			},
			"resonance": {
				"polarity": 1,
				"base_weight": 0.14,
				"myth_event_type": "item_relationship_resonated"
			},
			"rivalry": {
				"polarity": -1,
				"base_weight": 0.18,
				"myth_event_type": "item_relationship_rivalry"
			},
			"rejection": {
				"polarity": -1,
				"base_weight": 0.24,
				"myth_event_type": "item_relationship_rejected"
			},
			"dependency": {
				"polarity": 1,
				"base_weight": 0.1,
				"myth_event_type": "item_relationship_dependency"
			}
		}
	}

	var contract_policy: Dictionary = _safe_dictionary(active_contract.get("item_relationship_policy", {}))
	if not contract_policy.is_empty():
		out = _merge_dict(out, contract_policy)
	return out


func _item_relationship_polarity(relationship_type: String) -> int:
	match str(relationship_type).strip_edges().to_lower():
		"rivalry", "rejection", "incompatibility":
			return -1
		_:
			return 1


func _item_relationship_level(score: float) -> String:
	if score >= 0.95:
		return "myth_bound"
	if score >= 0.7:
		return "deeply_entangled"
	if score >= 0.4:
		return "active"
	if score >= 0.15:
		return "forming"
	return "faint"


func _item_relationship_item_packet(item: Dictionary) -> Dictionary:
	return {
		"item_key": _item_key(item),
		"item_id": int(item.get("id", -1)),
		"item_name": str(item.get("display_name", item.get("name", "an item"))),
		"category": str(item.get("category", "")),
		"contract_id": str(item.get("contract_id", "")),
		"type": str(item.get("type", "")),
		"artifact_kind": str(item.get("artifact_kind", "")),
		"stone_key": str(item.get("stone_key", ""))
	}


func _item_relationship_summary_for_item(item_key: String) -> Dictionary:
	var clean_key: String = str(item_key).strip_edges()
	if clean_key == "":
		return {}

	var state: Dictionary = _world_state()
	var registry: Dictionary = _safe_dictionary(state.get("object_relationship_registry", {}))
	var relationships: Array = []
	var strongest_synergy: float = 0.0
	var strongest_rivalry: float = 0.0
	var strongest_rejection: float = 0.0

	for raw_key in registry.keys():
		var row: Dictionary = _safe_dictionary(registry.get(raw_key, {}))
		if row.is_empty():
			continue
		if str(row.get("source_key", "")) != clean_key and str(row.get("target_key", "")) != clean_key:
			continue
		relationships.append(row.duplicate(true))
		strongest_synergy = max(strongest_synergy, float(row.get("synergy", 0.0)))
		strongest_rivalry = max(strongest_rivalry, float(row.get("rivalry", 0.0)))
		strongest_rejection = max(strongest_rejection, float(row.get("rejection", 0.0)))

	if relationships.is_empty():
		return {}

	var dominant_state: String = "associated"
	if strongest_rejection >= 0.45:
		dominant_state = "rejecting"
	elif strongest_rivalry >= 0.45:
		dominant_state = "rivalrous"
	elif strongest_synergy >= 0.45:
		dominant_state = "synergized"

	return {
		"schema": "eralife.item_relationship_summary",
		"version": CONTRACT_VERSION,
		"item_key": clean_key,
		"relationship_count": relationships.size(),
		"dominant_state": dominant_state,
		"strongest_synergy": strongest_synergy,
		"strongest_rivalry": strongest_rivalry,
		"strongest_rejection": strongest_rejection,
		"relationships": relationships
	}


func _emit_item_relationship_world_feed(actor: Person, row: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	if not gs.has_method("push_world_feed"):
		return

	var source_item: Dictionary = _safe_dictionary(row.get("source_item", {}))
	var target_item: Dictionary = _safe_dictionary(row.get("target_item", {}))
	var source_name: String = str(source_item.get("item_name", "An item"))
	var target_name: String = str(target_item.get("item_name", "another item"))
	var relationship_type: String = str(row.get("relationship_type", "relationship")).replace("_", " ")
	var text: String = "%s and %s formed a %s around %s." % [
		source_name,
		target_name,
		relationship_type,
		_person_label(actor)
	]

	if str(context.get("world_feed_text", "")).strip_edges() != "":
		text = str(context.get("world_feed_text", "")).strip_edges()

	gs.push_world_feed(text, {
		"npc_id": int(actor.id),
		"personally_relevant": actor == gs.player,
		"category": "belongings",
		"event_name": "item_relationship_formed",
		"source": str(context.get("source", "belongings_engine")),
		"relationship_type": str(row.get("relationship_type", "")),
		"relationship_key": str(row.get("relationship_key", "")),
		"source_item": source_item,
		"target_item": target_item
	})
func _resolve_object_myth_from_event(owner: Person, item: Dictionary, category: String, event_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	if owner == null or typeof(item) != TYPE_DICTIONARY:
		return {}

	var policy: Dictionary = _safe_dictionary(active_contract.get("object_consciousness_policy", {}))
	if not bool(policy.get("enabled", true)):
		return {}

	var state: Dictionary = _world_state()
	var registry: Dictionary = _safe_dictionary(state.get("object_myth_registry", {}))
	var ledger: Array = _safe_array(state.get("object_myth_ledger", []))
	var item_key: String = _item_key(item)
	var profile: Dictionary = _safe_dictionary(registry.get(item_key, {}))
	if profile.is_empty():
		profile = _empty_object_myth_profile(item)

	var myth_contract: Dictionary = _myth_contract_for_item(item, category)
	var event_type: String = str(event_packet.get("event_type", "event")).strip_edges().to_lower()
	var event_weight: float = _object_myth_event_weight(event_type, item, myth_contract, context)
	var public_visibility: bool = bool(context.get("public_visibility", event_type in ["item_acquired", "item_gifted", "item_used", "item_displayed_publicly"]))

	profile ["item_key"] = item_key
	profile ["item_id"] = int(item.get("id", -1))
	profile ["item_name"] = str(item.get("display_name", item.get("name", "an item")))
	profile ["contract_id"] = str(item.get("contract_id", ""))
	profile ["category"] = str(category)
	profile ["owner_id"] = int(owner.id)
	profile ["owner_name"] = _person_label(owner)
	profile ["myth_points"] = max(0.0, float(profile.get("myth_points", 0.0)) + event_weight)
	profile ["reputation"] = max(0.0, float(profile.get("reputation", 0.0)) + event_weight * 0.75)
	profile ["fear"] = clamp(float(profile.get("fear", 0.0)) + _myth_fear_gain(item, myth_contract, event_type, event_weight), 0.0, 1.0)
	profile ["worship"] = clamp(float(profile.get("worship", 0.0)) + _myth_worship_gain(item, myth_contract, event_type, event_weight), 0.0, 1.0)
	profile ["hunter_pressure"] = clamp(float(profile.get("hunter_pressure", 0.0)) + _myth_hunter_gain(item, myth_contract, event_type, event_weight), 0.0, 1.0)
	profile ["myth_level"] = _object_myth_level(float(profile.get("myth_points", 0.0)), myth_contract)
	profile ["publicly_known"] = bool(profile.get("publicly_known", false)) or public_visibility
	profile ["last_event_type"] = event_type
	profile ["last_seen_year"] = _current_year()
	profile ["updated_at_ms"] = int(Time.get_ticks_msec())

	var event_row: Dictionary = {
		"event_type": event_type,
		"weight": event_weight,
		"owner_id": int(owner.id),
		"owner_name": _person_label(owner),
		"year": _current_year(),
		"context": context.duplicate(true)
	}
	var history: Array = _safe_array(profile.get("history", []))
	history.append(event_row)
	while history.size() > 40:
		history.pop_front()
	profile ["history"] = history

	registry [item_key] = profile.duplicate(true)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.object_myth_report",
		"version": CONTRACT_VERSION,
		"item_key": item_key,
		"item_id": int(item.get("id", -1)),
		"item_name": str(item.get("display_name", item.get("name", "an item"))),
		"event_type": event_type,
		"event_weight": event_weight,
		"myth_level": str(profile.get("myth_level", "known_object")),
		"fear": float(profile.get("fear", 0.0)),
		"worship": float(profile.get("worship", 0.0)),
		"hunter_pressure": float(profile.get("hunter_pressure", 0.0)),
		"profile": profile.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_OBJECT_MYTH_LEDGER:
		ledger.pop_front()

	state ["object_myth_registry"] = registry
	state ["object_myth_ledger"] = ledger
	state ["last_object_myth_report"] = report.duplicate(true)
	_commit_world_state(state)

	last_myth_report = report.duplicate(true)

	if not bool(context.get("suppress_myth_world_feed", false)) and _should_emit_object_myth_world_feed(profile, event_type, event_weight):
		_emit_object_myth_world_feed(owner, item, category, profile, event_type)

	return report

func _route_object_perception_packet(owner: Person, item: Dictionary, category: String, event_packet: Dictionary, myth_report: Dictionary = {}) -> void:
	if owner == null or typeof(item) != TYPE_DICTIONARY:
		return

	var event_context: Dictionary = _safe_dictionary(event_packet.get("context", {}))
	if bool(event_context.get("suppress_object_perception", false)) or bool(event_context.get("suppress_upce_perception", false)):
		return

	var policy: Dictionary = _safe_dictionary(active_contract.get("object_consciousness_policy", {}))
	if not bool(policy.get("npc_perception_enabled", true)):
		return

	var observers: Array = _candidate_item_observers(owner, item, category, event_packet)
	for observer in observers:
		if observer == null:
			continue
		perceive_item(observer, owner, item, category, {
			"source": "belongings_event",
			"event_packet": event_packet.duplicate(true),
			"myth_report": myth_report.duplicate(true),
			"suppress_player_ui_interpretation": bool(event_context.get("suppress_player_ui_interpretation", false)),
			"suppress_life_diary": bool(event_context.get("suppress_life_diary", false)),
			"birth_loadout": bool(event_context.get("birth_loadout", false))
		})
func _yearly_object_myth_tick(year: int) -> Dictionary:
	var state: Dictionary = _world_state()
	var registry: Dictionary = _safe_dictionary(state.get("object_myth_registry", {}))
	var myth_profiles_updated: int = 0

	for raw_key in registry.keys():
		var key: String = str(raw_key)
		var profile: Dictionary = _safe_dictionary(registry.get(raw_key, {}))
		if profile.is_empty():
			continue

		var decay: float = 0.02
		if bool(profile.get("publicly_known", false)):
			decay = 0.005

		profile ["fear"] = clamp(float(profile.get("fear", 0.0)) - decay, 0.0, 1.0)
		profile ["worship"] = clamp(float(profile.get("worship", 0.0)) - decay * 0.5, 0.0, 1.0)
		profile ["hunter_pressure"] = clamp(float(profile.get("hunter_pressure", 0.0)) + _yearly_hunter_pressure_gain(profile), 0.0, 1.0)
		profile ["myth_points"] = max(0.0, float(profile.get("myth_points", 0.0)) + _yearly_myth_memory_gain(profile))
		profile ["myth_level"] = _object_myth_level(float(profile.get("myth_points", 0.0)), _myth_contract_for_profile(profile))
		profile ["last_tick_year"] = year
		registry [key] = profile
		myth_profiles_updated += 1

	state ["object_myth_registry"] = registry
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.object_myth_yearly_tick_report",
		"version": CONTRACT_VERSION,
		"year": year,
		"changed_count": myth_profiles_updated
	}

func _empty_object_myth_profile(item: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.object_myth_profile",
		"version": CONTRACT_VERSION,
		"item_key": _item_key(item),
		"item_id": int(item.get("id", -1)),
		"item_name": str(item.get("display_name", item.get("name", "an item"))),
		"contract_id": str(item.get("contract_id", "")),
		"myth_points": 0.0,
		"reputation": 0.0,
		"fear": 0.0,
		"worship": 0.0,
		"hunter_pressure": 0.0,
		"myth_level": "unknown_object",
		"publicly_known": false,
		"history": [],
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _myth_contract_for_item(item: Dictionary, category: String) -> Dictionary:
	var policy: Dictionary = _safe_dictionary(active_contract.get("myth_formation_policy", {}))
	var profiles: Dictionary = _safe_dictionary(policy.get("profiles", {}))
	var contract_id: String = str(item.get("contract_id", "")).strip_edges()
	if contract_id != "" and profiles.has(contract_id):
		return _safe_dictionary(profiles.get(contract_id, {}))

	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	if profiles.has(item_type):
		return _safe_dictionary(profiles.get(item_type, {}))

	var clean_category: String = str(category).strip_edges().to_lower()
	if clean_category.find("dragon") >= 0 and profiles.has("dragonball"):
		return _safe_dictionary(profiles.get("dragonball", {}))
	if clean_category.find("artifact") >= 0 and profiles.has("artifact"):
		return _safe_dictionary(profiles.get("artifact", {}))
	if profiles.has("generic"):
		return _safe_dictionary(profiles.get("generic", {}))
	return {}

func _myth_contract_for_profile(profile: Dictionary) -> Dictionary:
	var policy: Dictionary = _safe_dictionary(active_contract.get("myth_formation_policy", {}))
	var profiles: Dictionary = _safe_dictionary(policy.get("profiles", {}))
	var contract_id: String = str(profile.get("contract_id", "")).strip_edges()
	if contract_id != "" and profiles.has(contract_id):
		return _safe_dictionary(profiles.get(contract_id, {}))
	if profiles.has("generic"):
		return _safe_dictionary(profiles.get("generic", {}))
	return {}

func _object_myth_event_weight(event_type: String, item: Dictionary, myth_contract: Dictionary, context: Dictionary = {}) -> float:
	var weights: Dictionary = _safe_dictionary(myth_contract.get("event_weights", {}))
	var base: float = float(weights.get(event_type, weights.get("default", 1.0)))
	var identity: Dictionary = _safe_dictionary(item.get("identity", {}))
	var authority: String = str(identity.get("authority", "")).strip_edges().to_lower()
	if authority == "reality":
		base *= 2.4
	elif authority == "domain":
		base *= 1.45
	if bool(context.get("public_visibility", false)):
		base *= 1.35
	return max(0.0, base)

func _object_myth_level(points: float, myth_contract: Dictionary = {}) -> String:
	var thresholds: Dictionary = _safe_dictionary(myth_contract.get("thresholds", {}))
	var known: float = float(thresholds.get("known", 3.0))
	var notable: float = float(thresholds.get("notable", 9.0))
	var legendary: float = float(thresholds.get("legendary", 22.0))
	var mythic: float = float(thresholds.get("mythic", 46.0))
	if points >= mythic:
		return "mythic"
	if points >= legendary:
		return "legendary"
	if points >= notable:
		return "notable"
	if points >= known:
		return "known"
	return "unknown_object"

func _myth_fear_gain(item: Dictionary, myth_contract: Dictionary, event_type: String, weight: float) -> float:
	var fear_bias: float = float(myth_contract.get("fear_bias", 0.0))
	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	if item_type.find("dragon") >= 0 or item_type.find("artifact") >= 0:
		fear_bias += 0.02
	if event_type.find("wish") >= 0 or event_type.find("summon") >= 0:
		fear_bias += 0.05
	return clamp((weight * 0.012) + fear_bias, 0.0, 0.18)

func _myth_worship_gain(_item: Dictionary, myth_contract: Dictionary, event_type: String, weight: float) -> float:
	var worship_bias: float = float(myth_contract.get("worship_bias", 0.0))
	if event_type.find("revive") >= 0 or event_type.find("wish") >= 0:
		worship_bias += 0.06
	return clamp((weight * 0.014) + worship_bias, 0.0, 0.2)

func _myth_hunter_gain(item: Dictionary, myth_contract: Dictionary, event_type: String, weight: float) -> float:
	var hunter_bias: float = float(myth_contract.get("hunter_bias", 0.0))
	var affordances: Array = _safe_array(item.get("affordances", []))
	if affordances.has("summon_dragon_balls") or affordances.has("rewind") or affordances.has("time_loop"):
		hunter_bias += 0.04
	if event_type.find("display") >= 0 or event_type.find("acquired") >= 0:
		hunter_bias += 0.03
	return clamp((weight * 0.01) + hunter_bias, 0.0, 0.16)

func _yearly_hunter_pressure_gain(profile: Dictionary) -> float:
	var myth_level: String = str(profile.get("myth_level", "")).strip_edges().to_lower()
	match myth_level:
		"mythic":
			return 0.035
		"legendary":
			return 0.02
		"notable":
			return 0.008
	return 0.0

func _yearly_myth_memory_gain(profile: Dictionary) -> float:
	if not bool(profile.get("publicly_known", false)):
		return 0.0
	var myth_level: String = str(profile.get("myth_level", "")).strip_edges().to_lower()
	match myth_level:
		"mythic":
			return 1.5
		"legendary":
			return 0.75
		"notable":
			return 0.25
	return 0.0

func _should_emit_object_myth_world_feed(profile: Dictionary, event_type: String, event_weight: float) -> bool:
	if event_weight < 4.0:
		return false
	var myth_level: String = str(profile.get("myth_level", "")).strip_edges().to_lower()
	return myth_level in ["notable", "legendary", "mythic"] or event_type.find("summon") >= 0

func _emit_object_myth_world_feed(owner: Person, item: Dictionary, _category: String, profile: Dictionary, event_type: String) -> void:
	if gs == null or owner == null or not gs.has_method("push_world_feed"):
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var item_name: String = str(item.get("display_name", item.get("name", "an item"))).strip_edges()
	if item_name == "":
		item_name = "an item"

	var myth_level: String = str(profile.get("myth_level", "known")).replace("_", " ").strip_edges()
	if myth_level == "":
		myth_level = "known"

	var feed_key: String = "object_myth:%s:%s:%s:%d" % [
		str(profile.get("item_key", _item_key(item))),
		str(event_type).strip_edges().to_lower(),
		myth_level,
		_current_year()
	]
	var feed_guard: Dictionary = _safe_dictionary(gs.scenario_state.get("object_myth_world_feed_guard", {}))
	if bool(feed_guard.get(feed_key, false)):
		return
	feed_guard [feed_key] = true
	gs.scenario_state ["object_myth_world_feed_guard"] = feed_guard

	var item_ref: String = item_name
	if owner == gs.player:
		item_ref = "my %s" % item_name
	elif _person_label(owner) != "Unknown":
		item_ref = "%s's %s" % [_person_label(owner), item_name]

	var text: String = "📜 Rumors around %s intensified. People now speak of it as if it is %s." % [item_ref, myth_level]
	if event_type.find("summon") >= 0:
		text = "🌌 %s answered a reality-level call from %s. The story around it grew teeth." % [item_name, _person_label(owner)]

	gs.push_world_feed(text, {
		"npc_id": owner.id,
		"personally_relevant": owner == gs.player,
		"suppress_diary": true,
		"category": "belongings",
		"event_name": "object_myth_formed",
		"source": "belongings_engine",
		"item_id": int(item.get("id", -1)),
		"contract_id": str(item.get("contract_id", "")),
		"myth_level": str(profile.get("myth_level", "known"))
	})
func _candidate_item_observers(owner: Person, _item: Dictionary, _category: String, _event_packet: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var policy: Dictionary = _safe_dictionary(active_contract.get("object_consciousness_policy", {}))
	var max_observers: int = max(1, int(policy.get("max_passive_observers_per_event", 8)))

	if owner != null:
		out.append(owner)
		seen [str(owner.id)] = true

	if gs != null and gs.player != null and not seen.has(str(gs.player.id)):
		out.append(gs.player)
		seen [str(gs.player.id)] = true

	if gs != null and "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		var pool: Array = gs.npcs.duplicate()
		pool.shuffle()
		for raw_npc in pool:
			if out.size() >= max_observers:
				break
			if raw_npc == null or not (raw_npc is Person):
				continue
			var npc: Person = raw_npc
			if not npc.alive:
				continue
			if seen.has(str(npc.id)):
				continue
			out.append(npc)
			seen [str(npc.id)] = true

	return out

func _observer_item_bias_profile(observer: Person, item: Dictionary, myth: Dictionary, context: Dictionary = {}) -> String:
	var forced: String = str(context.get("bias_profile", "")).strip_edges().to_lower()
	if forced != "":
		return forced

	var traits: Array = []
	if observer != null and typeof(observer.traits) == TYPE_ARRAY:
		traits = observer.traits

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("religious") >= 0 or trait_text.find("devout") >= 0 or trait_text.find("faith") >= 0:
			if float(myth.get("worship", 0.0)) >= 0.55:
				return "religious_extremist"
			return "spiritual"
		if trait_text.find("scientist") >= 0 or trait_text.find("genius") >= 0 or trait_text.find("scholar") >= 0:
			return "scientific"
		if trait_text.find("paranoid") >= 0 or trait_text.find("trauma") >= 0:
			return "paranoid"

	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	var contract_id: String = str(item.get("contract_id", "")).strip_edges().to_lower()
	if contract_id == "red_bonnet" or item_type.find("artifact") >= 0 or item_type.find("dragon") >= 0:
		return "mythic_folk"
	if item_type.find("car") >= 0 or str(item.get("category", "")).strip_edges().to_lower().find("vehicle") >= 0:
		return "personal_attachment"
	return "ordinary_social"

func _interpret_item_for_observer(_observer: Person, owner: Person, item: Dictionary, myth: Dictionary, bias_profile: String, _context: Dictionary = {}) -> Dictionary:
	var item_name: String = str(item.get("display_name", item.get("name", "an item")))
	var owner_name: String = _person_label(owner)
	var fear: float = float(myth.get("fear", 0.0))
	var worship: float = float(myth.get("worship", 0.0))
	var hunter_pressure: float = float(myth.get("hunter_pressure", 0.0))
	var relationship_delta: int = 0
	var desire_to_claim: float = hunter_pressure * 0.45
	var memory_text: String = "%s owns %s." % [owner_name, item_name]
	var interpretation_label: String = "noticed_object"

	match bias_profile:
		"religious_extremist", "spiritual":
			interpretation_label = "divine_sign"
			relationship_delta += int(round(worship * 8.0))
			memory_text = "%s may have been chosen through %s." % [owner_name, item_name]
		"scientific":
			interpretation_label = "anomaly"
			desire_to_claim += 0.08
			memory_text = "%s owns an anomaly worth studying: %s." % [owner_name, item_name]
		"paranoid":
			interpretation_label = "threat"
			relationship_delta -= int(round(fear * 12.0))
			desire_to_claim += 0.04
			memory_text = "%s possessing %s feels dangerous." % [owner_name, item_name]
		"mythic_folk":
			interpretation_label = "folk_legend"
			relationship_delta += int(round(worship * 4.0)) - int(round(fear * 3.0))
			desire_to_claim += hunter_pressure * 0.25
			memory_text = "People whisper that %s is tied to %s." % [owner_name, item_name]
		"personal_attachment":
			interpretation_label = "sentimental_object"
			relationship_delta += 1
			memory_text = "%s seems attached to %s." % [owner_name, item_name]
		_:
			interpretation_label = "owned_object"

	return {
		"label": interpretation_label,
		"memory_text": memory_text,
		"relationship_delta": relationship_delta,
		"desire_to_claim": clamp(desire_to_claim, 0.0, 1.0),
		"fear": fear,
		"worship": worship,
		"hunter_pressure": hunter_pressure
	}

func _store_object_perception(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var memory: Dictionary = _safe_dictionary(state.get("object_perception_memory", {}))
	var item_key: String = str(report.get("item_key", ""))
	if item_key == "":
		return
	var item_memory: Dictionary = _safe_dictionary(memory.get(item_key, {}))
	item_memory [str(report.get("observer_id", -1))] = report.duplicate(true)
	memory [item_key] = item_memory

	var total: int = 0
	for raw_key in memory.keys():
		var bucket: Dictionary = _safe_dictionary(memory.get(raw_key, {}))
		total += bucket.size()
	if total > MAX_OBJECT_PERCEPTION_MEMORY:
		memory = _trim_object_perception_memory(memory)

	state ["object_perception_memory"] = memory
	_commit_world_state(state)

func _route_upce_item_perception(report: Dictionary) -> void:
	if gs == null:
		return

	var report_context: Dictionary = _safe_dictionary(report.get("context", {}))
	var event_packet: Dictionary = _safe_dictionary(report_context.get("event_packet", {}))
	var event_context: Dictionary = _safe_dictionary(event_packet.get("context", {}))
	if bool(report_context.get("birth_loadout", false)) or bool(event_context.get("birth_loadout", false)):
		return
	if bool(report_context.get("suppress_upce_perception", false)) or bool(event_context.get("suppress_upce_perception", false)):
		return

	var interpretation: Dictionary = _safe_dictionary(report.get("interpretation", {}))
	var item_name: String = str(report.get("item_name", "an item")).strip_edges()
	if item_name == "":
		item_name = "an item"

	var owner_id: int = int(report.get("owner_id", -1))
	var observer_id: int = int(report.get("observer_id", -1))
	var contract_id: String = str(report.get("contract_id", "")).strip_edges().to_lower()
	var myth: Dictionary = _safe_dictionary(report.get("myth", {}))
	var myth_level: String = str(myth.get("myth_level", "known")).replace("_", " ").strip_edges()
	var is_artifact: bool = contract_id == "red_bonnet" or str(report.get("category", "")).strip_edges().to_lower() == "artifacts" or item_name.to_lower().find("stone") >= 0

	var perception_text: String = "%s was noticed, and people tried to decide whether it was property, symbol, threat, blessing, or myth." % item_name
	if contract_id == "red_bonnet":
		perception_text = "The Red Bonnet was noticed, and the room around it started turning belief into rumor."
	elif item_name.to_lower().find("stone") >= 0:
		perception_text = "%s was noticed, and even ordinary witnesses felt like they were looking at something that did not belong to normal history." % item_name

	var payload: Dictionary = {
		"schema": OBJECT_PERCEPTION_SCHEMA,
		"version": CONTRACT_VERSION,
		"event_name": "object.perceived",
		"event_type": "object_perception",
		"source": "belongings_engine",
		"actor_id": owner_id,
		"observer_id": observer_id,
		"owner_id": owner_id,
		"target_id": observer_id,
		"item_id": int(report.get("item_id", -1)),
		"item_name": item_name,
		"contract_id": str(report.get("contract_id", "")),
		"bias_profile": str(report.get("bias_profile", "ordinary_social")),
		"interpretation": interpretation.duplicate(true),
		"memory_text": str(interpretation.get("memory_text", "")),
		"relationship_delta": int(interpretation.get("relationship_delta", 0)),
		"myth": myth.duplicate(true),
		"myth_level": myth_level,
		"text": perception_text,
		"public": bool(event_context.get("public_visibility", false)),
		"witness_count": 0,
		"classification": {
			"object_perception": true,
			"social": true,
			"supernatural": is_artifact,
			"public": bool(event_context.get("public_visibility", false))
		},
		"suppress_player_ui_interpretation": bool(report_context.get("suppress_player_ui_interpretation", event_context.get("suppress_player_ui_interpretation", false))),
		"suppress_life_diary": bool(report_context.get("suppress_life_diary", event_context.get("suppress_life_diary", false)))
	}

	if "reality_orchestrator" in gs and gs.reality_orchestrator != null and gs.reality_orchestrator.has_method("orchestrate_perception_event"):
		gs.reality_orchestrator.orchestrate_perception_event(payload, {
			"source": "belongings_engine",
			"domain": "perception"
		})
	elif "upce_engine" in gs and gs.upce_engine != null and gs.upce_engine.has_method("interpret_event"):
		gs.upce_engine.interpret_event(payload)

func _trim_object_perception_memory(memory: Dictionary) -> Dictionary:
	var out: Dictionary = memory.duplicate(true)
	while _object_perception_memory_count(out) > MAX_OBJECT_PERCEPTION_MEMORY:
		var first_key: String = ""
		for raw_key in out.keys():
			first_key = str(raw_key)
			break
		if first_key == "":
			break
		out.erase(first_key)
	return out

func _object_perception_memory_count(memory: Dictionary) -> int:
	var total: int = 0
	for raw_key in memory.keys():
		total += _safe_dictionary(memory.get(raw_key, {})).size()
	return total

func _format_object_myth_text(item: Dictionary, myth: Dictionary) -> String:
	var item_name: String = str(item.get("display_name", item.get("name", "This item")))
	if myth.is_empty():
		return "%s has not formed a public myth yet." % item_name
	return "%s\n\nMyth Level: %s\nReputation: %.1f\nFear: %d%%\nWorship: %d%%\nHunter Pressure: %d%%" % [
		item_name,
		str(myth.get("myth_level", "unknown_object")).replace("_", " ").capitalize(),
		float(myth.get("reputation", 0.0)),
		int(round(float(myth.get("fear", 0.0)) * 100.0)),
		int(round(float(myth.get("worship", 0.0)) * 100.0)),
		int(round(float(myth.get("hunter_pressure", 0.0)) * 100.0))
	]

func _find_item_entry_for_actor(actor: Person, category: String, item_id: int) -> Dictionary:
	if actor == null:
		return {}
	var inventory: Dictionary = get_inventory(actor)
	var clean_category: String = str(category).strip_edges()
	for raw_category in inventory.keys():
		if clean_category != "" and str(raw_category) != clean_category:
			continue
		var items: Array = []
		if typeof(inventory.get(raw_category, [])) == TYPE_ARRAY:
			items = inventory.get(raw_category, [])
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			if int((raw_item as Dictionary).get("id", -1)) == item_id:
				return _normalize_belonging_entry(actor, raw_item as Dictionary, str(raw_category), bool((raw_item as Dictionary).get("mirrored_asset", false)), false)
	return {}

func _item_key(item: Dictionary) -> String:
	var item_id: int = int(item.get("id", -1))
	if item_id > 0:
		return "item:%d" % item_id
	var contract_id: String = str(item.get("contract_id", "")).strip_edges()
	var item_name: String = str(item.get("name", item.get("display_name", "item"))).strip_edges().to_lower().replace(" ", "_")
	if contract_id != "":
		return "contract:%s:%s" % [contract_id, item_name]
	return "item_name:%s" % item_name

func _object_bond_level(score: float) -> String:
	if score >= 0.95:
		return "soul_bound"
	if score >= 0.7:
		return "deep_bond"
	if score >= 0.4:
		return "trusted"
	if score >= 0.15:
		return "familiar"
	return "new_object"
func _belongings_event_should_suppress_initial_item_story(
	event_type: String,
	person: Person,
	item: Dictionary,
	category: String,
	context: Dictionary
) -> bool:
	var clean_event_type: String = str(event_type).strip_edges().to_lower()
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_event_type not in ["item_acquired", "item_updated"]:
		return false

	var source_text: String = str(context.get("source", item.get("source", ""))).strip_edges().to_lower()
	var contract_id: String = str(item.get("contract_id", "")).strip_edges().to_lower()
	var asset_kind: String = str(item.get("asset_kind", "")).strip_edges().to_lower()
	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	var reality_identity: Dictionary = _safe_dictionary(item.get("reality_identity", item.get("identity", {})))

	var official_residence: bool = contract_id == "official_residence_white_house" \
or asset_kind == "official_residence" \
or item_type == "official residence" \
or clean_category == "government residences" \
or bool(reality_identity.get("official_residence", false)) \
or bool(context.get("official_residence", false))

	var spawn_existing_asset: bool = bool(context.get("spawn_existing_asset", false)) \
or bool(context.get("initial_inventory", false)) \
or bool(context.get("seed_granted", false)) \
or bool(context.get("birth_loadout", false)) \
or bool(context.get("mirror_only", false)) \
or source_text in [
			"presidential_parent_contract",
			"spawn_contract",
			"birth_shell",
			"seed_prewarm",
			"initial_world_seed",
			"property_engine_bootstrap"
		]

	var explicit_purchase_action: bool = bool(context.get("purchase_committed", false)) \
or bool(context.get("actual_purchase", false)) \
or bool(context.get("bought_by_actor", false)) \
or bool(context.get("transaction_committed", false)) \
or source_text.find("purchase") >= 0 \
or source_text.find("shop") >= 0 \
or source_text.find("store") >= 0 \
or source_text.find("checkout") >= 0

	if explicit_purchase_action:
		return false

	if official_residence:
		return true

	if spawn_existing_asset:
		return true

	if person != null and int(person.age) <= 0 and clean_event_type == "item_acquired":
		return true

	return false
func _record_belongings_event(event_type: String, person: Person, item: Dictionary, category: String, context: Dictionary = {}) -> void:
	var event_context: Dictionary = context.duplicate(true)
	var clean_event_type: String = str(event_type).strip_edges()
	var clean_category: String = str(category).strip_edges()
	var clean_contract_id: String = str(item.get("contract_id", "")).strip_edges().to_lower()
	var clean_item_type: String = str(item.get("type", "")).strip_edges().to_lower()
	var clean_artifact_kind: String = str(item.get("artifact_kind", "")).strip_edges().to_lower()

	var is_birth_loadout_artifact: bool = false
	if person != null and int(person.age) <= 0 and clean_category.to_lower() == "artifacts":
		if clean_contract_id == "red_bonnet" or clean_artifact_kind == "stone" or clean_item_type.find("artifact") >= 0:
			is_birth_loadout_artifact = true

	var suppress_initial_item_story: bool = _belongings_event_should_suppress_initial_item_story(
		clean_event_type,
		person,
		item,
		clean_category,
		event_context
	)

	if is_birth_loadout_artifact or suppress_initial_item_story:
		event_context ["spawn_existing_asset"] = suppress_initial_item_story
		event_context ["birth_loadout"] = bool(event_context.get("birth_loadout", is_birth_loadout_artifact))
		event_context ["suppress_object_perception"] = true
		event_context ["suppress_upce_perception"] = true
		event_context ["suppress_player_ui_interpretation"] = true
		event_context ["suppress_life_diary"] = true
		event_context ["suppress_myth_world_feed"] = true
		event_context ["suppress_duplicate_discovery_text"] = true
		event_context ["suppress_reality_orchestration"] = true
		event_context ["defer_reality_routing"] = true
		event_context ["initial_shell_story_forbidden"] = true

	var packet: Dictionary = {
		"success": true,
		"schema": "eralife.belongings_event",
		"version": CONTRACT_VERSION,
		"event_type": clean_event_type,
		"owner_id": int(person.id) if person != null else -1,
		"owner_name": _person_label(person),
		"item_id": int(item.get("id", -1)),
		"item_name": str(item.get("display_name", item.get("name", "Unnamed Item"))),
		"category": clean_category,
		"contract_id": str(item.get("contract_id", "")),
		"identity": _safe_dictionary(item.get("identity", {})),
		"affordances": _safe_array(item.get("affordances", [])),
		"relationships": _safe_dictionary(item.get("relationships", {})),
		"context": event_context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var myth_report: Dictionary = {}
	if not bool(event_context.get("suppress_object_perception", false)) and not bool(event_context.get("suppress_upce_perception", false)):
		myth_report = _resolve_object_myth_from_event(person, item, clean_category, packet, event_context)
		if not myth_report.is_empty():
			packet ["myth_report"] = myth_report.duplicate(true)

	_record_belongings_ledger(packet)

	if not bool(event_context.get("suppress_reality_orchestration", false)) and not bool(event_context.get("defer_reality_routing", false)):
		_route_belongings_reality_packet(packet)

	if not bool(event_context.get("suppress_object_perception", false)) and not bool(event_context.get("suppress_upce_perception", false)):
		_route_object_perception_packet(person, item, clean_category, packet, myth_report)
func _record_belongings_ledger(packet: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("belongings_ledger", []))
	ledger.append(packet.duplicate(true))
	while ledger.size() > MAX_BELONGINGS_LEDGER:
		ledger.pop_front()
	state ["belongings_ledger"] = ledger
	state ["last_belongings_event"] = packet.duplicate(true)
	_commit_world_state(state)

	if gs != null and "event_bus" in gs and gs.event_bus != null:
		if gs.event_bus.has_method("emit"):
			gs.event_bus.emit("belongings.event", packet)

func _route_belongings_reality_packet(packet: Dictionary) -> void:
	if gs == null:
		return

	var packet_context: Dictionary = _safe_dictionary(packet.get("context", {}))
	if bool(packet_context.get("suppress_reality_orchestration", false)) or bool(packet_context.get("defer_reality_routing", false)):
		return

	if not ("reality_orchestrator" in gs) or gs.reality_orchestrator == null:
		return

	if not gs.reality_orchestrator.has_method("orchestrate_intent"):
		return

	var authority: String = str(_safe_dictionary(packet.get("identity", {})).get("authority", "local_event")).strip_edges().to_lower()
	if authority == "":
		authority = "local_event"

	gs.reality_orchestrator.orchestrate_intent({
		"id": "belongings.%s" % str(packet.get("event_type", "event")),
		"domain": "artifacts",
		"authority": authority,
		"engine_property": "belongings_engine",
		"event_payload": packet.duplicate(true),
		"effects": [
			"inventory_manifestation",
			"ownership_relationship_update",
			"item_affordance_resolution",
			"object_consciousness_update",
			"object_perception_memory",
			"myth_formation",
			"historical_storage",
			"ui_manifestation"
		],
		"composition_stack": [
			"belongings_engine",
			"item_contract_registry",
			"object_consciousness_runtime",
			"upce_engine",
			"relationship_context",
			"artifact_context",
			"memory_engine",
			"reputation_engine",
			"world_chronicle_engine",
			"historical_storage",
			"ui_manifestation"
		]
	}, {
		"source": "belongings_engine",
		"domain": "artifacts"
	})
func _inheritance_category_allowed(category: String, filters: Dictionary) -> bool:
	var allowed_categories: Array = _safe_array(filters.get("categories", []))
	if allowed_categories.is_empty():
		return true
	for raw_category in allowed_categories:
		if str(raw_category).strip_edges().to_lower() == str(category).strip_edges().to_lower():
			return true
	return false

func _inheritance_item_allowed(item: Dictionary, filters: Dictionary) -> bool:
	var item_id: int = int(item.get("id", -1))
	var specific_item_ids: Array = _safe_array(filters.get("specific_item_ids", []))
	var excluded_item_ids: Array = _safe_array(filters.get("excluded_item_ids", []))

	for raw_excluded in excluded_item_ids:
		if int(raw_excluded) == item_id:
			return false

	if specific_item_ids.is_empty():
		return true

	for raw_specific in specific_item_ids:
		if int(raw_specific) == item_id:
			return true

	return false

func _normalize_inheritance_heirs(heirs: Array) -> Array:
	var out: Array = []
	var equal_share: float = 1.0
	if heirs.size() > 0:
		equal_share = 1.0 / float(heirs.size())

	for raw_heir in heirs:
		var row: Dictionary = {}
		if typeof(raw_heir) == TYPE_OBJECT and raw_heir is Person:
			var person: Person = raw_heir
			row = {
				"person_id": int(person.id),
				"name": _person_label(person),
				"share": equal_share,
				"priority": 100,
				"categories": [],
				"specific_item_ids": []
			}
		elif typeof(raw_heir) == TYPE_DICTIONARY:
			row = (raw_heir as Dictionary).duplicate(true)
			row ["person_id"] = int(row.get("person_id", row.get("id", -1)))
			row ["name"] = str(row.get("name", "Heir %d" % int(row.get("person_id", -1))))
			row ["share"] = float(row.get("share", equal_share))
			row ["priority"] = int(row.get("priority", 100))
			if typeof(row.get("categories", [])) != TYPE_ARRAY:
				row ["categories"] = []
			if typeof(row.get("specific_item_ids", [])) != TYPE_ARRAY:
				row ["specific_item_ids"] = []
		else:
			row = {
				"person_id": int(raw_heir),
				"name": "Heir %d" % int(raw_heir),
				"share": equal_share,
				"priority": 100,
				"categories": [],
				"specific_item_ids": []
			}

		if int(row.get("person_id", -1)) > 0:
			out.append(row)

	return out

func _select_inheritance_heir_for_item(item: Dictionary, category: String, heirs: Array, assigned_counts: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999999.0
	for raw_heir in heirs:
		if typeof(raw_heir) != TYPE_DICTIONARY:
			continue
		var heir: Dictionary = raw_heir as Dictionary
		var score: float = float(heir.get("priority", 100))
		score += float(heir.get("share", 0.0)) * 100.0
		score -= float(assigned_counts.get(str(heir.get("person_id", -1)), 0)) * 12.0

		var heir_categories: Array = _safe_array(heir.get("categories", []))
		if not heir_categories.is_empty():
			var category_match: bool = false
			for raw_category in heir_categories:
				if str(raw_category).strip_edges().to_lower() == str(category).strip_edges().to_lower():
					category_match = true
					break
			if category_match:
				score += 80.0
			else:
				score -= 40.0

		var specific_ids: Array = _safe_array(heir.get("specific_item_ids", []))
		for raw_item_id in specific_ids:
			if int(raw_item_id) == int(item.get("id", -1)):
				score += 500.0

		if score > best_score:
			best_score = score
			best = heir.duplicate(true)

	if best.is_empty() and not heirs.is_empty() and typeof(heirs [0]) == TYPE_DICTIONARY:
		best = (heirs [0] as Dictionary).duplicate(true)

	return best

func _person_from_id(person_id: int) -> Person:
	if person_id <= 0 or gs == null:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var found = gs.get_or_reactivate_npc_by_id(person_id)
		if found != null:
			return found
	if gs.has_method("get_npc_by_id"):
		var npc = gs.get_npc_by_id(person_id)
		if npc != null:
			return npc
	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_person in gs.npcs:
			if raw_person == null:
				continue
			if raw_person is Person and int(raw_person.id) == person_id:
				return raw_person
	return null

func _item_age_for_year(item: Dictionary, year: int) -> int:
	var acquired_year: int = int(item.get("acquired_year", 0))
	if acquired_year == 0:
		acquired_year = int(item.get("origin_year", 0))
	if acquired_year == 0:
		return int(item.get("age", item.get("age_years", 0)))
	return max(0, year - acquired_year)

func _total_item_count_all() -> int:
	var total: int = 0
	for owner_id in belongings.keys():
		if typeof(belongings.get(owner_id, {})) != TYPE_DICTIONARY:
			continue
		var inventory: Dictionary = belongings.get(owner_id, {})
		for category in inventory.keys():
			if typeof(inventory.get(category, [])) == TYPE_ARRAY:
				total += (inventory.get(category, []) as Array).size()
	return total

func _auto_assign_item_ids() -> bool:
	var policy: Dictionary = _safe_dictionary(active_contract.get("runtime_policy", {}))
	return bool(policy.get("auto_assign_item_ids", true))

func _next_item_id() -> int:
	if gs != null and "next_id" in gs:
		var out: int = int(gs.next_id)
		if out <= 0:
			out = int(Time.get_ticks_msec())
		gs.next_id = out + 1
		return out
	return int(Time.get_ticks_msec())

func _current_year() -> int:
	if gs == null:
		return 0
	if "year" in gs:
		return int(gs.year)
	return 0

func _current_era_name() -> String:
	if gs == null:
		return ""
	if "era" in gs and gs.era != null:
		if "name" in gs.era:
			return str(gs.era.name)
	return ""

func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges() if "name" in person else "Unknown"
	return full_name

func _world_state() -> Dictionary:
	if gs == null:
		return _normalize_state({})
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var raw: Variant = gs.scenario_state.get(STATE_KEY, {})
	var state: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		state = (raw as Dictionary).duplicate(true)
	state = _normalize_state(state)
	gs.scenario_state [STATE_KEY] = state
	return state

func _normalize_state(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out ["schema"] = str(out.get("schema", STATE_SCHEMA))
	out ["version"] = max(CONTRACT_VERSION, int(out.get("version", 1)))
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["generationally_persistent"] = bool(out.get("generationally_persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))
	if typeof(out.get("belongings_ledger", [])) != TYPE_ARRAY:
		out ["belongings_ledger"] = []
	if typeof(out.get("last_belongings_event", {})) != TYPE_DICTIONARY:
		out ["last_belongings_event"] = {}
	if typeof(out.get("item_contract_registry", {})) != TYPE_DICTIONARY:
		out ["item_contract_registry"] = {}
	if typeof(out.get("inheritance_contract_registry", {})) != TYPE_DICTIONARY:
		out ["inheritance_contract_registry"] = {}
	if typeof(out.get("object_myth_registry", {})) != TYPE_DICTIONARY:
		out ["object_myth_registry"] = {}
	if typeof(out.get("object_myth_ledger", [])) != TYPE_ARRAY:
		out ["object_myth_ledger"] = []
	if typeof(out.get("object_perception_memory", {})) != TYPE_DICTIONARY:
		out ["object_perception_memory"] = {}
	if typeof(out.get("object_bond_registry", {})) != TYPE_DICTIONARY:
		out ["object_bond_registry"] = {}
	if typeof(out.get("object_relationship_registry", {})) != TYPE_DICTIONARY:
		out ["object_relationship_registry"] = {}
	if typeof(out.get("object_relationship_ledger", [])) != TYPE_ARRAY:
		out ["object_relationship_ledger"] = []
	if typeof(out.get("last_object_relationship_report", {})) != TYPE_DICTIONARY:
		out ["last_object_relationship_report"] = {}
	if typeof(out.get("last_object_myth_report", {})) != TYPE_DICTIONARY:
		out ["last_object_myth_report"] = {}
	return out
func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _merge_unique_arrays(base: Array, overlay: Array) -> Array:
	var out: Array = []
	for raw_value in base:
		if not out.has(raw_value):
			out.append(raw_value)
	for raw_value in overlay:
		if not out.has(raw_value):
			out.append(raw_value)
	return out

func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var incoming: Variant = overlay.get(key)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(_safe_dictionary(out.get(key, {})), _safe_dictionary(incoming))
		elif typeof(incoming) == TYPE_DICTIONARY:
			out [key] = _safe_dictionary(incoming)
		elif typeof(incoming) == TYPE_ARRAY:
			out [key] = (incoming as Array).duplicate(true)
		else:
			out [key] = incoming
	return out

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "belongings.default",
		"runtime_policy": {
			"auto_assign_item_ids": true,
			"preserve_unknown_fields": true,
			"backwards_compatible": true,
			"emit_event_bus": true,
			"age_items_each_year": true,
			"object_myth_yearly_tick": true
		},
		"unified_reality_policy": {
		},
		"object_consciousness_policy": {
			"enabled": true,
			"npc_perception_enabled": true,
			"max_passive_observers_per_event": 8,
		},
		"item_relationship_policy": {
			"enabled": true,
			"emit_world_feed": true,
			"emit_event_bus": true,
			"max_relationship_ledger": 320,
			"relationship_types": {
				"artifact_synergy": {
					"polarity": 1,
					"base_weight": 0.22,
					"myth_event_type": "item_relationship_formed"
				},
				"resonance": {
					"polarity": 1,
					"base_weight": 0.14,
					"myth_event_type": "item_relationship_resonated"
				},
				"rivalry": {
					"polarity": -1,
					"base_weight": 0.18,
					"myth_event_type": "item_relationship_rivalry"
				},
				"rejection": {
					"polarity": -1,
					"base_weight": 0.24,
					"myth_event_type": "item_relationship_rejected"
				},
				"dependency": {
					"polarity": 1,
					"base_weight": 0.1,
					"myth_event_type": "item_relationship_dependency"
				}
			}
		},
		"myth_formation_policy": {
			"schema": OBJECT_MYTH_SCHEMA,
			"version": CONTRACT_VERSION,
			"profiles": {
				"generic": {
					"thresholds": {
						"known": 4.0,
						"notable": 16.0,
						"legendary": 44.0,
						"mythic": 90.0
					},
					"event_weights": {
						"default": 0.75,
						"item_acquired": 1.0,
						"item_bond_deepened": 0.65,
						"item_displayed_publicly": 2.0
					},
					"fear_bias": 0.0,
					"worship_bias": 0.0,
					"hunter_bias": 0.0
				},
				"artifact": {
					"thresholds": {
						"known": 2.0,
						"notable": 7.0,
						"legendary": 18.0,
						"mythic": 38.0
					},
					"event_weights": {
						"default": 1.4,
						"item_acquired": 3.0,
						"item_used": 5.0,
						"item_displayed_publicly": 6.0,
						"item_gifted": 3.5
					},
					"fear_bias": 0.015,
					"worship_bias": 0.018,
					"hunter_bias": 0.02
				},
				"red_bonnet": {
					"thresholds": {
						"known": 1.0,
						"notable": 4.0,
						"legendary": 10.0,
						"mythic": 22.0
					},
					"event_weights": {
						"default": 3.0,
						"item_acquired": 8.0,
						"item_used": 10.0,
						"red_bonnet_summoned_dragon_balls": 20.0,
						"item_displayed_publicly": 12.0
					},
					"fear_bias": 0.04,
					"worship_bias": 0.08,
					"hunter_bias": 0.06
				},
				"dragonball": {
					"thresholds": {
						"known": 1.0,
						"notable": 5.0,
						"legendary": 14.0,
						"mythic": 30.0
					},
					"event_weights": {
						"default": 2.0,
						"item_acquired": 5.0,
						"item_gifted": 4.0,
						"item_used": 8.0,
						"summon_shenron": 14.0
					},
					"fear_bias": 0.025,
					"worship_bias": 0.05,
					"hunter_bias": 0.05
				},
				"time_stone": {
					"thresholds": {
						"known": 1.0,
						"notable": 4.0,
						"legendary": 11.0,
						"mythic": 24.0
					},
					"event_weights": {
						"default": 3.0,
						"item_acquired": 7.0,
						"time_loop": 14.0,
						"rewind": 12.0,
						"future_sight": 9.0
					},
					"fear_bias": 0.06,
					"worship_bias": 0.03,
					"hunter_bias": 0.07
				}
			}
		},
		"inheritance_policy": {
			"default_transfer_mode": "contract_weighted",
			"emit_world_feed": true
		},
		"item_contracts": {
			"generic_item": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "generic_item",
				"display_name": "Generic Item",
				"category": "Misc",
				"identity": {
					"type": "item",
					"authority": "local_event",
					"alignment": "mundane"
				},
				"affordances": [
					"gift",
					"inherit",
					"inspect_myth",
					"bond_with_item"
				],
				"relationships": {
					"recognition": "owned_object",
					"ownership_type": "personal_belonging"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "contract_weighted"
				}
			},
			"red_bonnet": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "red_bonnet",
				"display_name": "Red Bonnet",
				"category": "Artifacts",
				"identity": {
					"type": "mythic_artifact",
					"authority": "reality",
					"alignment": "fate_bloodline_wish",
				},
				"affordances": [
					"bounded_reality_wish",
					"summon_dragon_balls",
					"inspect_myth",
					"bond_with_item",
					"display",
					"gift",
					"inherit"
				],
				"relationships": {
					"recognition": "heaven_sent_mythic_artifact",
					"ownership_type": "reality_bound_artifact"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "chosen_bloodline_or_named_heir"
				}
			},
			"time_stone": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "time_stone",
				"display_name": "Time Stone",
				"category": "Artifacts",
				"identity": {
					"type": "cosmic_artifact",
					"authority": "reality",
					"alignment": "temporal"
				},
				"affordances": [
					"time_loop",
					"rewind",
					"future_sight",
					"inspect_myth",
					"gift",
					"inherit"
				],
				"relationships": {
					"recognition": "infinity_stone",
					"ownership_type": "reality_bound_artifact"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "named_heir_or_reality_claim"
				}
			},
			"flame_sword_contract": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "flame_sword_contract",
				"display_name": "Flaming Sword",
				"category": "Weapons",
				"identity": {
					"type": "weapon",
					"authority": "domain",
					"element": "fire",
					"alignment": "combat"
				},
				"affordances": [
					"melee_attack",
					"ignite_targets",
					"intimidation_presence",
					"inspect_myth",
					"bond_with_item",
					"gift",
					"inherit"
				],
				"relationships": {
					"recognition": "legendary_weapon",
					"ownership_type": "bound_weapon"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "bloodline_or_named_heir"
				}
			},
			"dragonball": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "dragonball",
				"display_name": "Dragon Ball",
				"category": "Dragon Balls",
				"identity": {
					"type": "dragonball",
					"authority": "reality",
					"alignment": "wish_artifact"
				},
				"affordances": [
					"summon_shenron",
					"inspect_myth",
					"gift",
					"inherit"
				],
				"relationships": {
					"recognition": "wish_artifact",
					"ownership_type": "artifact_possession"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "artifact_transfer"
				}
			},
			"trade_good": {
				"schema": ITEM_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": "trade_good",
				"display_name": "Trade Good",
				"category": "Trade Goods",
				"identity": {
					"type": "trade_good",
					"authority": "domain",
					"alignment": "economic"
				},
				"affordances": [
					"sell",
					"trade",
					"gift",
					"inherit",
					"market_speculation",
					"inspect_myth"
				],
				"relationships": {
					"recognition": "market_asset",
					"ownership_type": "portable_wealth"
				},
				"persistence": {
					"save_persistent": true,
					"generationally_persistent": true,
					"age_persistent": true,
					"preserve_unknown_fields": true
				},
				"inheritance": {
					"eligible": true,
					"default_policy": "liquid_asset_distribution"
				}
			}
		}
	}



var TRADE_GOODS = [
	{ "name": "Silk", "value": 200},
	{ "name": "Spices", "value": 150},
	{ "name": "Gold", "value": 500},
	{ "name": "Salt", "value": 80},
	{ "name": "Tea", "value": 120},
	{ "name": "Ivory", "value": 300},
	{ "name": "Jewels", "value": 450}
]
func barter_item_contract_at_index(
	person: Person,
	category: String,
	item_index: int,
	item_id: int
) -> Dictionary:
	if person == null:
		return {}

	var clean_category: String = str(
		category
	).strip_edges()

	if clean_category == "":
		return {}

	var owner_key: Variant = (
		_belongings_owner_key_for_person(
			person
		)
	)

	if not belongings.has(
		owner_key
	):
		return {}

	var inventory_raw: Variant = belongings [
		owner_key
	]

	if typeof(
		inventory_raw
	) != TYPE_DICTIONARY:
		return {}

	var inventory: Dictionary = (
		inventory_raw as Dictionary
	)
	var items_raw: Variant = inventory.get(
		clean_category,
		[]
	)

	if typeof(
		items_raw
	) != TYPE_ARRAY:
		return {}

	var items: Array = (
		items_raw as Array
	)

	if (
		item_index < 0
		or item_index >= items.size()
	):
		return {}

	var raw_item: Variant = items [
		item_index
	]

	if typeof(
		raw_item
	) != TYPE_DICTIONARY:
		return {}

	var raw_item_dictionary: Dictionary = (
		raw_item as Dictionary
	)

	if int(
		raw_item_dictionary.get(
			"id",
			-1
		)
	) != item_id:
		return {}

	if (
		bool(
			raw_item_dictionary.get(
				"mirrored_asset",
				false
			)
		)
		or bool(
			raw_item_dictionary.get(
				"temporary_ownership",
				false
			)
		)
		or bool(
			raw_item_dictionary.get(
				"government_owned",
				false
			)
		)
	):
		return {}

	var asset_kind: String = str(
		raw_item_dictionary.get(
			"asset_kind",
			""
		)
	).strip_edges().to_lower()

	if asset_kind in [
		"property",
		"real_estate",
		"transport",
		"vehicle",
		"official_residence",
		"creature",
		"pet"
	]:
		return {}

	var item: Dictionary = (
		_normalize_belonging_entry(
			person,
			raw_item_dictionary,
			clean_category,
			false,
			false
		)
	)

	var barter_value: int = 0

	for value_key in [
		"market_value",
		"value",
		"base_value",
		"cost",
		"purchase_price"
	]:
		var candidate_value: int = int(
			item.get(
				value_key,
				0
			)
		)

		if candidate_value > 0:
			barter_value = candidate_value
			break

	if barter_value <= 0:
		return {}

	return {
		"success": true,
		"owner_id": int(
			person.id
		),
		"category": clean_category,
		"item_index": item_index,
		"item_id": item_id,
		"item": item,
		"barter_value": barter_value,
		"exact_value_exchange": true,
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}


func consume_barter_item_at_index(
	person: Person,
	category: String,
	item_index: int,
	item_id: int,
	context: Dictionary = {}
) -> Dictionary:
	var quote: Dictionary = (
		barter_item_contract_at_index(
			person,
			category,
			item_index,
			item_id
		)
	)

	if quote.is_empty():
		return {
			"success": false,
			"reason": "barter_item_coordinate_stale"
		}

	var owner_key: Variant = (
		_belongings_owner_key_for_person(
			person
		)
	)
	var inventory: Dictionary = (
		belongings [
			owner_key
		] as Dictionary
	)
	var clean_category: String = str(
		quote.get(
			"category",
			category
		)
	)
	var items: Array = (
		inventory [
			clean_category
		] as Array
	)
	var removed: Dictionary = (
		quote.get(
			"item",
			{}
		) as Dictionary
	)



	var last_index: int = (
		items.size() - 1
	)

	if item_index != last_index:
		items [
			item_index
		] = items [
			last_index
		]

	items.pop_back()

	inventory [
		clean_category
	] = items
	belongings [
		owner_key
	] = inventory

	var event_context: Dictionary = (
		context.duplicate(false)
	)

	event_context [
		"reason"
	] = "silk_road_barter"
	event_context [
		"exact_value_exchange"
	] = true

	_record_belongings_event(
		"item_removed",
		person,
		removed,
		clean_category,
		event_context
	)

	return {
		"success": true,
		"owner_id": int(
			person.id
		),
		"category": clean_category,
		"item_id": item_id,
		"item": removed,
		"barter_value": int(
			quote.get(
				"barter_value",
				0
			)
		),
		"exact_value_exchange": true
	}
func get_random_trade_good(person: Person) -> Dictionary:
	if person == null:
		return {}

	var item = TRADE_GOODS [randi() % TRADE_GOODS.size()]
	var realm_id = person.realm_id
	var market_value = item.value
	if gs != null and "global_market_engine" in gs and gs.global_market_engine != null:
		market_value = gs.global_market_engine.get_price_for_good(item.name, realm_id)

	var trade_item = {
		"id": _next_item_id(),
		"name": item.name,
		"display_name": item.name,
		"value": market_value,
		"base_value": item.value,
		"type": "TradeGood",
		"contract_id": "trade_good",
		"identity": {
			"type": "trade_good",
			"economic_role": "portable_market_value",
		},
		"affordances": [
			"sell",
			"trade",
			"gift",
			"inherit",
			"market_speculation"
		],
		"origin_realm_id": realm_id,
		"origin_era": _current_era_name(),
		"acquired_year": _current_year()
	}

	add_item(person, trade_item, "Trade Goods")

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"%s acquired trade goods: %s (market value %d)." %
			[person.first_name, item.name, market_value],
			{
				"npc_id": person.id,
				"personally_relevant": person == gs.player,
				"category": "trade",
				"event_name": "trade_goods_acquired",
				"source": "belongings_engine",
				"contract_id": "trade_good"
			}
		)

	return _normalize_belonging_entry(person, trade_item, "Trade Goods", false, false)