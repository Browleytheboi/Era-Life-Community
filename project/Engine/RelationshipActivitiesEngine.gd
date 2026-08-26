extends Resource
class_name RelationshipActivitiesEngine

const RELATIONSHIP_ACTIVITY_CONTRACT_SCHEMA:= "eralife.relationship_activity_contract"
const RELATIONSHIP_ACTIVITY_CONTRACT_VERSION:= 1
const FAMILY_CARE_DIAPER_YEAR_LIMIT:= 3
const FAMILY_CARE_FOOD_PICKER_LIMIT:= 8
const RELATIONSHIP_LIFECYCLE_SCHEMA:= (
	"eralife.relationship_lifecycle_contract"
)

const RELATIONSHIP_ROMANCE_PROJECTION_SCHEMA:= (
	"eralife.relationship_romance_projection"
)

const RELATIONSHIP_ROMANCE_SERVICE_DELAY_SECONDS:= 0.025
const MODERN_FUTURE_HOOKUP_SPECIAL_REJECTION_CHANCE:= 20
var relationship_lifecycle_runtime_bound: bool = false

var relationship_romance_projection_queue: Array = []
var relationship_romance_projection_keys: Dictionary = {}
var relationship_romance_projection_service_armed: bool = false
var relationship_romance_projection_generation: int = 0
var relationship_romance_projection_revision: int = 0
var gs
var active_contract: Dictionary = {}

func _init(_gs):
	gs = _gs
	set_contract()



	call_deferred(
		"_bind_relationship_lifecycle_runtime"
	)
func _relationship_dict(
	value: Variant
) -> Dictionary:
	return (
		value as Dictionary
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _relationship_array(
	value: Variant
) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)


func _relationship_current_year() -> int:
	if gs == null:
		return 0

	return int(
		gs.year
	)


func _relationship_pair_key(
	actor_id: int,
	target_id: int
) -> String:
	if (
		actor_id <= 0
		or target_id <= 0
	):
		return ""

	var low_id: int = mini(
		actor_id,
		target_id
	)
	var high_id: int = maxi(
		actor_id,
		target_id
	)

	return "%d:%d" % [
		low_id,
		high_id
	]


func _relationship_resident_person_by_id(
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


func _relationship_pair_bond(
	actor: Person,
	target: Person
) -> int:
	if (
		actor == null
		or target == null
	):
		return 0

	var actor_to_target: int = int(
		actor.affection.get(
			int(
				target.id
			),
			50
		)
	)
	var target_to_actor: int = int(
		target.affection.get(
			int(
				actor.id
			),
			50
		)
	)

	return clampi(
		int(
			round(
				(
					float(actor_to_target)
					+ float(target_to_actor)
				) * 0.5
			)
		),
		0,
		100
	)


func _relationship_adjust_pair_bond(
	actor: Person,
	target: Person,
	delta: int
) -> void:
	if (
		actor == null
		or target == null
	):
		return

	actor.affection [
		int(
			target.id
		)
	] = clampi(
		int(
			actor.affection.get(
				int(
					target.id
				),
				50
			)
		) + delta,
		0,
		100
	)

	target.affection [
		int(
			actor.id
		)
	] = clampi(
		int(
			target.affection.get(
				int(
					actor.id
				),
				50
			)
		) + delta,
		0,
		100
	)


func _relationship_lifecycle_registry(
	create_if_missing: bool = false
) -> Dictionary:
	if gs == null:
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		if not create_if_missing:
			return {}

		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get(
		"relationship_lifecycle_by_pair",
		{}
	)

	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary

	if not create_if_missing:
		return {}

	gs.scenario_state [
		"relationship_lifecycle_by_pair"
	] = {}

	return gs.scenario_state [
		"relationship_lifecycle_by_pair"
	] as Dictionary


func _resident_relationship_lifecycle_contract(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {}

	var pair_key: String = _relationship_pair_key(
		int(
			actor.id
		),
		int(
			target.id
		)
	)

	if pair_key == "":
		return {}

	var registry: Dictionary = (
		_relationship_lifecycle_registry(
			false
		)
	)

	var raw: Variant = registry.get(
		pair_key,
		{}
	)

	return (
		raw as Dictionary
		if typeof(raw) == TYPE_DICTIONARY
		else {}
	)


func _ensure_relationship_lifecycle_contract(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {}

	var pair_key: String = _relationship_pair_key(
		int(
			actor.id
		),
		int(
			target.id
		)
	)

	if pair_key == "":
		return {}

	var registry: Dictionary = (
		_relationship_lifecycle_registry(
			true
		)
	)
	var raw: Variant = registry.get(
		pair_key,
		{}
	)
	var lifecycle: Dictionary = (
		raw as Dictionary
		if typeof(raw) == TYPE_DICTIONARY
		else {}
	)

	if lifecycle.is_empty():
		lifecycle = {
			"schema": RELATIONSHIP_LIFECYCLE_SCHEMA,
			"version": 1,
			"pair_key": pair_key,
			"actor_a_id": mini(
				int(
					actor.id
				),
				int(
					target.id
				)
			),
			"actor_b_id": maxi(
				int(
					actor.id
				),
				int(
					target.id
				)
			),
			"dating_started_year": (
				_relationship_current_year()
			),
			"engaged_year": -999999,
			"marriage_year": -999999,
			"divorce_year": -999999,
			"prenup_signed": false,
			"last_partner_proposal_roll_year": -999999,
			"status": str(
				actor.marital_status
			),
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"updated_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	registry [
		pair_key
	] = lifecycle

	return lifecycle


func _store_relationship_lifecycle_contract(
	lifecycle: Dictionary
) -> void:
	if lifecycle.is_empty():
		return

	var pair_key: String = str(
		lifecycle.get(
			"pair_key",
			""
		)
	).strip_edges()

	if pair_key == "":
		return

	var registry: Dictionary = (
		_relationship_lifecycle_registry(
			true
		)
	)

	lifecycle [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	registry [
		pair_key
	] = lifecycle


func _relationship_romance_projection_registry(
	create_if_missing: bool = false
) -> Dictionary:
	if gs == null:
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		if not create_if_missing:
			return {}

		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get(
		"relationship_romance_projection_by_pair",
		{}
	)

	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary

	if not create_if_missing:
		return {}

	gs.scenario_state [
		"relationship_romance_projection_by_pair"
	] = {}

	return gs.scenario_state [
		"relationship_romance_projection_by_pair"
	] as Dictionary


func _resident_relationship_romance_projection(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {}

	var pair_key: String = _relationship_pair_key(
		int(
			actor.id
		),
		int(
			target.id
		)
	)

	if pair_key == "":
		return {}

	var registry: Dictionary = (
		_relationship_romance_projection_registry(
			false
		)
	)
	var raw: Variant = registry.get(
		pair_key,
		{}
	)

	return (
		raw as Dictionary
		if typeof(raw) == TYPE_DICTIONARY
		else {}
	)


func resident_romance_projection_revision_for_pair(
	actor: Person,
	target: Person
) -> int:
	var projection: Dictionary = (
		_resident_relationship_romance_projection(
			actor,
			target
		)
	)

	return int(
		projection.get(
			"revision",
			0
		)
	)


func _proposal_item_key(
	item: Dictionary
) -> String:
	var personal_item_id: String = str(
		item.get(
			"personal_item_id",
			""
		)
	).strip_edges()

	if personal_item_id != "":
		return personal_item_id

	var raw_id: String = str(
		item.get(
			"id",
			item.get(
				"item_id",
				""
			)
		)
	).strip_edges()

	return raw_id


func _proposal_item_value(
	item: Dictionary
) -> float:
	var provenance: Dictionary = _relationship_dict(
		item.get(
			"provenance",
			{}
		)
	)

	return maxf(
		0.0,
		float(
			item.get(
				"value",
				item.get(
					"price",
					provenance.get(
						"price_paid",
						0.0
					)
				)
			)
		)
	)


func _proposal_jewelry_projection_row(
	item: Dictionary,
	_actor_id: int,
	target_id: int
) -> Dictionary:
	var item_key: String = _proposal_item_key(
		item
	)

	if item_key == "":
		return {}

	var item_name: String = str(
		item.get(
			"name",
			item.get(
				"display_name",
				"Jewelry"
			)
		)
	).strip_edges()

	var item_value: float = (
		_proposal_item_value(
			item
		)
	)

	return {
		"item_key": item_key,
		"item_name": item_name,
		"value": item_value,
		"value_label": "$%0.2f" % item_value,
		"category": "Luxury",
		"usable_for_proposal": true,
		"choice_contract": {
			"id": (
				"proposal_jewelry:%s"
				% item_key
			),
			"label": (
				"%s • $%0.2f"
				% [
					item_name,
					item_value
				]
			),
			"detail_action": "engine_call",
			"engine_property": (
				"relationship_activities_engine"
			),
			"method": (
				"resolve_relationship_lifecycle_intent"
			),
			"payload": {
				"action_id": (
					"submit_proposal_with_jewelry"
				),
				"target_id": target_id,
				"jewelry_key": item_key,
				"source": (
					"relationship_proposal_resident_jewelry"
				)
			},
			"commits_reality_truth": true,
			"authority_prevalidated": false
		}
	}


func _relationship_wedding_types_for_current_era() -> Array:
	var era_name: String = ""

	if (
		gs != null
		and gs.era != null
	):
		era_name = str(
			gs.era.name
		).strip_edges()

	match era_name:
		"Ancient Era":
			return [
				{
					"id": "temple_ceremony",
					"label": "Temple Ceremony",
					"cost": 180.0
				},
				{
					"id": "family_feast",
					"label": "Family Feast",
					"cost": 420.0
				},
				{
					"id": "royal_union",
					"label": "Royal Union",
					"cost": 3200.0
				}
			]

		"Medieval Era":
			return [
				{
					"id": "village_wedding",
					"label": "Village Wedding",
					"cost": 350.0
				},
				{
					"id": "chapel_wedding",
					"label": "Chapel Wedding",
					"cost": 900.0
				},
				{
					"id": "castle_wedding",
					"label": "Castle Wedding",
					"cost": 6500.0
				}
			]

		"Industrial Era":
			return [
				{
					"id": "civil_ceremony",
					"label": "Civil Ceremony",
					"cost": 650.0
				},
				{
					"id": "church_wedding",
					"label": "Church Wedding",
					"cost": 1800.0
				},
				{
					"id": "grand_hall_wedding",
					"label": "Grand Hall Wedding",
					"cost": 7200.0
				}
			]

		"Future Era":
			return [
				{
					"id": "civil_union",
					"label": "Civil Union",
					"cost": 1800.0
				},
				{
					"id": "immersive_ceremony",
					"label": "Immersive Ceremony",
					"cost": 8400.0
				},
				{
					"id": "orbital_wedding",
					"label": "Orbital Wedding",
					"cost": 26000.0
				}
			]

		_:
			return [
				{
					"id": "courthouse",
					"label": "Courthouse Wedding",
					"cost": 450.0
				},
				{
					"id": "intimate_wedding",
					"label": "Intimate Wedding",
					"cost": 2600.0
				},
				{
					"id": "traditional_wedding",
					"label": "Traditional Wedding",
					"cost": 8500.0
				},
				{
					"id": "luxury_wedding",
					"label": "Luxury Wedding",
					"cost": 28000.0
				}
			]


func _relationship_property_identity_key(
	property_asset: Dictionary
) -> String:
	for raw_key in [
		"property_id",
		"asset_id",
		"id"
	]:
		var value: String = str(
			property_asset.get(
				raw_key,
				""
			)
		).strip_edges()

		if value != "":
			return value

	var address: String = str(
		property_asset.get(
			"address",
			""
		)
	).strip_edges()

	if address != "":
		return "address:%s" % address.to_lower()

	return ""


func _honeymoon_realm_projection_row(
	realm_id: int,
	realm: Dictionary
) -> Dictionary:
	if (
		realm_id <= 0
		or realm.is_empty()
	):
		return {}

	var realm_name: String = str(
		realm.get(
			"name",
			"Realm %d" % realm_id
		)
	).strip_edges()

	var population: float = maxf(
		1.0,
		float(
			realm.get(
				"population",
				1
			)
		)
	)

	var prestige_component: float = clampf(
		log(
			population + 1.0
		) * 55.0,
		0.0,
		1250.0
	)

	var deterministic_component: float = float(
		abs(
			hash(
				"honeymoon:%d:%s"
				% [
					realm_id,
					realm_name
				]
			)
		) % 1400
	)

	var cost: float = (
		350.0
		+ prestige_component
		+ deterministic_component
	)

	var realm_type: String = str(
		realm.get(
			"realm_type",
			realm.get(
				"dimension_type",
				""
			)
		)
	).strip_edges().to_lower()

	if realm_type in [
		"space",
		"space_realm",
		"interrealm",
		"interrealm_authority"
	]:
		cost *= 2.4

	return {
		"realm_id": realm_id,
		"id": str(
			realm_id
		),
		"label": realm_name,
		"realm_name": realm_name,
		"cost": cost,
		"cost_label": "$%0.2f" % cost,
		"realm_type": realm_type,
	}


func queue_relationship_romance_projection(
	actor: Person,
	target: Person,
	reason: String = "relationship_romance_truth_changed"
) -> Dictionary:
	if (
		actor == null
		or target == null
		or not actor.alive
		or not target.alive
	):
		return {
			"success": false,
			"reason": "invalid_relationship_pair"
		}

	var actor_id: int = int(
		actor.id
	)
	var target_id: int = int(
		target.id
	)
	var pair_key: String = _relationship_pair_key(
		actor_id,
		target_id
	)

	if pair_key == "":
		return {
			"success": false,
			"reason": "invalid_relationship_pair_key"
		}

	if relationship_romance_projection_keys.has(
		pair_key
	):
		return {
			"success": true,
			"queued": false,
			"already_queued": true,
			"pair_key": pair_key
		}

	relationship_romance_projection_generation += 1

	var wedding_types: Array = (
		_relationship_wedding_types_for_current_era()
	)
	var wedding_type_by_id: Dictionary = {}


	for raw_wedding in wedding_types:
		if typeof(raw_wedding) != TYPE_DICTIONARY:
			continue

		var wedding: Dictionary = (
			raw_wedding as Dictionary
		)

		wedding_type_by_id [
			str(
				wedding.get(
					"id",
					""
				)
			)
		] = wedding

	relationship_romance_projection_keys [
		pair_key
	] = true

	relationship_romance_projection_queue.append({
		"generation": (
			relationship_romance_projection_generation
		),
		"pair_key": pair_key,
		"actor_id": actor_id,
		"target_id": target_id,
		"reason": reason,
		"phase": "actor_jewelry",
		"actor_jewelry_cursor": 0,
		"target_jewelry_cursor": 0,
		"actor_property_cursor": 0,
		"target_property_cursor": 0,
		"realm_cursor": 0,
		"actor_proposal_jewelry": [],
		"target_proposal_jewelry": [],
		"actor_proposal_jewelry_by_key": {},
		"target_proposal_jewelry_by_key": {},
		"actor_proposal_choice_contracts": [],
		"best_target_proposal_jewelry": {},
		"best_target_proposal_jewelry_value": -1.0,
		"premarital_property_keys_actor": {},
		"premarital_property_keys_target": {},
		"wedding_types": wedding_types,
		"wedding_type_by_id": wedding_type_by_id,
		"honeymoon_realms": [],
		"honeymoon_realm_by_id": {},
		"started_at_ms": int(
			Time.get_ticks_msec()
		),
		"observation_required": false,
		"idle_required": false,
		"ready_gate_member": false
	})

	_arm_relationship_romance_projection_service()

	return {
		"success": true,
		"queued": true,
		"pair_key": pair_key,
		"reason": reason,
		"blocks_ui": false
	}


func _arm_relationship_romance_projection_service() -> void:
	if relationship_romance_projection_service_armed:
		return

	if relationship_romance_projection_queue.is_empty():
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (main_loop is SceneTree):
		return

	relationship_romance_projection_service_armed = true

	var timer:= (
		main_loop as SceneTree
	).create_timer(
		RELATIONSHIP_ROMANCE_SERVICE_DELAY_SECONDS
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_relationship_romance_projection_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _publish_relationship_romance_projection(
	job: Dictionary,
	complete: bool
) -> void:
	var pair_key: String = str(
		job.get(
			"pair_key",
			""
		)
	)

	if pair_key == "":
		return

	relationship_romance_projection_revision += 1

	var projection: Dictionary = {
		"schema": RELATIONSHIP_ROMANCE_PROJECTION_SCHEMA,
		"version": 1,
		"pair_key": pair_key,
		"actor_id": int(
			job.get(
				"actor_id",
				-1
			)
		),
		"target_id": int(
			job.get(
				"target_id",
				-1
			)
		),
		"revision": (
			relationship_romance_projection_revision
		),
		"projection_complete": complete,
		"projection_pending": not complete,
		"actor_proposal_jewelry": (
			_relationship_array(
				job.get(
					"actor_proposal_jewelry",
					[]
				)
			)
		),
		"target_proposal_jewelry": (
			_relationship_array(
				job.get(
					"target_proposal_jewelry",
					[]
				)
			)
		),
		"actor_proposal_jewelry_by_key": (
			_relationship_dict(
				job.get(
					"actor_proposal_jewelry_by_key",
					{}
				)
			)
		),
		"target_proposal_jewelry_by_key": (
			_relationship_dict(
				job.get(
					"target_proposal_jewelry_by_key",
					{}
				)
			)
		),
		"actor_proposal_choice_contracts": (
			_relationship_array(
				job.get(
					"actor_proposal_choice_contracts",
					[]
				)
			)
		),
		"best_target_proposal_jewelry": (
			_relationship_dict(
				job.get(
					"best_target_proposal_jewelry",
					{}
				)
			)
		),
		"premarital_property_keys_actor": (
			_relationship_dict(
				job.get(
					"premarital_property_keys_actor",
					{}
				)
			)
		),
		"premarital_property_keys_target": (
			_relationship_dict(
				job.get(
					"premarital_property_keys_target",
					{}
				)
			)
		),
		"wedding_types": (
			_relationship_array(
				job.get(
					"wedding_types",
					[]
				)
			)
		),
		"wedding_type_by_id": (
			_relationship_dict(
				job.get(
					"wedding_type_by_id",
					{}
				)
			)
		),
		"honeymoon_realms": (
			_relationship_array(
				job.get(
					"honeymoon_realms",
					[]
				)
			)
		),
		"honeymoon_realm_by_id": (
			_relationship_dict(
				job.get(
					"honeymoon_realm_by_id",
					{}
				)
			)
		),
		"progressive_observability": true,
		"observation_required": false,
		"idle_required": false,
		"ready_gate_member": false,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	var registry: Dictionary = (
		_relationship_romance_projection_registry(
			true
		)
	)

	registry [
		pair_key
	] = projection

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"relationship.romance_projection.published",
			{
				"actor_id": int(
					projection.get(
						"actor_id",
						-1
					)
				),
				"target_id": int(
					projection.get(
						"target_id",
						-1
					)
				),
				"pair_key": pair_key,
				"revision": int(
					projection.get(
						"revision",
						0
					)
				),
				"complete": complete,
				"qos_tier": "ambient",
				"fanout_hints": {
					"force_defer_bus": true
				}
			}
		)


func _service_relationship_romance_projection_quantum() -> void:
	relationship_romance_projection_service_armed = false

	if relationship_romance_projection_queue.is_empty():
		return

	var job_raw: Variant = (
		relationship_romance_projection_queue [
			0
		]
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		relationship_romance_projection_queue.pop_front()
		_arm_relationship_romance_projection_service()
		return

	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var target_id: int = int(
		job.get(
			"target_id",
			-1
		)
	)
	var pair_key: String = str(
		job.get(
			"pair_key",
			""
		)
	)

	var actor: Person = (
		_relationship_resident_person_by_id(
			actor_id
		)
	)
	var target: Person = (
		_relationship_resident_person_by_id(
			target_id
		)
	)

	if (
		actor == null
		or target == null
	):
		relationship_romance_projection_keys.erase(
			pair_key
		)
		relationship_romance_projection_queue.pop_front()
		_arm_relationship_romance_projection_service()
		return

	var phase: String = str(
		job.get(
			"phase",
			"actor_jewelry"
		)
	)

	match phase:
		"actor_jewelry":
			var inventory: Dictionary = {}

			if (
				gs.belongings_engine != null
				and gs.belongings_engine.has_method(
					"get_inventory"
				)
			):
				inventory = (
					gs.belongings_engine.get_inventory(
						actor
					)
				)

			var luxury_rows: Array = (
				_relationship_array(
					inventory.get(
						"Luxury",
						[]
					)
				)
			)
			var cursor: int = int(
				job.get(
					"actor_jewelry_cursor",
					0
				)
			)

			if cursor < luxury_rows.size():
				var raw_item: Variant = luxury_rows [
					cursor
				]

				job [
					"actor_jewelry_cursor"
				] = cursor + 1

				if typeof(raw_item) == TYPE_DICTIONARY:
					var item: Dictionary = (
						raw_item as Dictionary
					)

					if bool(
						item.get(
							"usable_for_proposal",
							false
						)
					):
						var row: Dictionary = (
							_proposal_jewelry_projection_row(
								item,
								actor_id,
								target_id
							)
						)

						if not row.is_empty():
							var rows: Array = (
								_relationship_array(
									job.get(
										"actor_proposal_jewelry",
										[]
									)
								)
							)
							rows.append(
								row
							)

							var by_key: Dictionary = (
								_relationship_dict(
									job.get(
										"actor_proposal_jewelry_by_key",
										{}
									)
								)
							)
							by_key [
								str(
									row.get(
										"item_key",
										""
									)
								)
							] = row

							var choices: Array = (
								_relationship_array(
									job.get(
										"actor_proposal_choice_contracts",
										[]
									)
								)
							)
							choices.append(
								_relationship_dict(
									row.get(
										"choice_contract",
										{}
									)
								)
							)

							job [
								"actor_proposal_jewelry"
							] = rows
							job [
								"actor_proposal_jewelry_by_key"
							] = by_key
							job [
								"actor_proposal_choice_contracts"
							] = choices

				_publish_relationship_romance_projection(
					job,
					false
				)

				relationship_romance_projection_queue [
					0
				] = job
				_arm_relationship_romance_projection_service()
				return

			job ["phase"] = "target_jewelry"

		"target_jewelry":
			var inventory: Dictionary = {}

			if (
				gs.belongings_engine != null
				and gs.belongings_engine.has_method(
					"get_inventory"
				)
			):
				inventory = (
					gs.belongings_engine.get_inventory(
						target
					)
				)

			var luxury_rows: Array = (
				_relationship_array(
					inventory.get(
						"Luxury",
						[]
					)
				)
			)
			var cursor: int = int(
				job.get(
					"target_jewelry_cursor",
					0
				)
			)

			if cursor < luxury_rows.size():
				var raw_item: Variant = luxury_rows [
					cursor
				]

				job [
					"target_jewelry_cursor"
				] = cursor + 1

				if typeof(raw_item) == TYPE_DICTIONARY:
					var item: Dictionary = (
						raw_item as Dictionary
					)

					if bool(
						item.get(
							"usable_for_proposal",
							false
						)
					):
						var row: Dictionary = (
							_proposal_jewelry_projection_row(
								item,
								target_id,
								actor_id
							)
						)

						if not row.is_empty():
							var rows: Array = (
								_relationship_array(
									job.get(
										"target_proposal_jewelry",
										[]
									)
								)
							)
							rows.append(
								row
							)

							var by_key: Dictionary = (
								_relationship_dict(
									job.get(
										"target_proposal_jewelry_by_key",
										{}
									)
								)
							)
							by_key [
								str(
									row.get(
										"item_key",
										""
									)
								)
							] = row

							job [
								"target_proposal_jewelry"
							] = rows
							job [
								"target_proposal_jewelry_by_key"
							] = by_key

							var row_value: float = float(
								row.get(
									"value",
									0.0
								)
							)

							if row_value > float(
								job.get(
									"best_target_proposal_jewelry_value",
									-1.0
								)
							):
								job [
									"best_target_proposal_jewelry_value"
								] = row_value
								job [
									"best_target_proposal_jewelry"
								] = row

				_publish_relationship_romance_projection(
					job,
					false
				)

				relationship_romance_projection_queue [
					0
				] = job
				_arm_relationship_romance_projection_service()
				return

			job ["phase"] = "actor_properties"

		"actor_properties":
			var property_rows: Array = []

			if gs.property_engine != null:
				property_rows = (
					_relationship_array(
						gs.property_engine.properties.get(
							actor_id,
							[]
						)
					)
				)

			var cursor: int = int(
				job.get(
					"actor_property_cursor",
					0
				)
			)

			if cursor < property_rows.size():
				var raw_property: Variant = (
					property_rows [
						cursor
					]
				)

				job [
					"actor_property_cursor"
				] = cursor + 1

				if typeof(raw_property) == TYPE_DICTIONARY:
					var property_asset: Dictionary = (
						raw_property as Dictionary
					)
					var property_key: String = (
						_relationship_property_identity_key(
							property_asset
						)
					)

					if property_key != "":
						var property_keys: Dictionary = (
							_relationship_dict(
								job.get(
									"premarital_property_keys_actor",
									{}
								)
							)
						)

						property_keys [
							property_key
						] = true

						job [
							"premarital_property_keys_actor"
						] = property_keys

				_publish_relationship_romance_projection(
					job,
					false
				)

				relationship_romance_projection_queue [
					0
				] = job
				_arm_relationship_romance_projection_service()
				return

			job ["phase"] = "target_properties"

		"target_properties":
			var property_rows: Array = []

			if gs.property_engine != null:
				property_rows = (
					_relationship_array(
						gs.property_engine.properties.get(
							target_id,
							[]
						)
					)
				)

			var cursor: int = int(
				job.get(
					"target_property_cursor",
					0
				)
			)

			if cursor < property_rows.size():
				var raw_property: Variant = (
					property_rows [
						cursor
					]
				)

				job [
					"target_property_cursor"
				] = cursor + 1

				if typeof(raw_property) == TYPE_DICTIONARY:
					var property_asset: Dictionary = (
						raw_property as Dictionary
					)
					var property_key: String = (
						_relationship_property_identity_key(
							property_asset
						)
					)

					if property_key != "":
						var property_keys: Dictionary = (
							_relationship_dict(
								job.get(
									"premarital_property_keys_target",
									{}
								)
							)
						)

						property_keys [
							property_key
						] = true

						job [
							"premarital_property_keys_target"
						] = property_keys

				_publish_relationship_romance_projection(
					job,
					false
				)

				relationship_romance_projection_queue [
					0
				] = job
				_arm_relationship_romance_projection_service()
				return

			job ["phase"] = "realms"

		"realms":
			if (
				gs.realm_engine == null
				or not gs.realm_engine.has_method(
					"resident_realm_identity_count"
				)
				or not gs.realm_engine.has_method(
					"resident_realm_id_at"
				)
			):
				relationship_romance_projection_queue [
					0
				] = job

				_arm_relationship_romance_projection_service()
				return

			var realm_cursor: int = int(
				job.get(
					"realm_cursor",
					0
				)
			)
			var realm_count: int = int(
				gs.realm_engine
				.resident_realm_identity_count()
			)

			if realm_cursor < realm_count:
				var realm_id: int = int(
					gs.realm_engine.resident_realm_id_at(
						realm_cursor
					)
				)

				job ["realm_cursor"] = (
					realm_cursor + 1
				)

				var realm_raw: Variant = (
					gs.realm_engine.realms.get(
						realm_id,
						{}
					)
				)
				var realm: Dictionary = (
					realm_raw as Dictionary
					if typeof(realm_raw) == TYPE_DICTIONARY
					else {}
				)

				if not realm.is_empty():
					var realistic_mode: bool = (
						str(
							gs.reality_mode
						).strip_edges().to_lower()
						== "realistic"
					)

					var elemental_realm: bool = bool(
						realm.get(
							"elemental_realm",
							false
						)
					)

					if not (
						realistic_mode
						and elemental_realm
					):
						var row: Dictionary = (
							_honeymoon_realm_projection_row(
								realm_id,
								realm
							)
						)

						if not row.is_empty():
							var realm_rows: Array = (
								_relationship_array(
									job.get(
										"honeymoon_realms",
										[]
									)
								)
							)
							var realm_by_id: Dictionary = (
								_relationship_dict(
									job.get(
										"honeymoon_realm_by_id",
										{}
									)
								)
							)

							realm_rows.append(
								row
							)

							realm_by_id [
								str(
									realm_id
								)
							] = row

							job [
								"honeymoon_realms"
							] = realm_rows
							job [
								"honeymoon_realm_by_id"
							] = realm_by_id

				_publish_relationship_romance_projection(
					job,
					false
				)

				relationship_romance_projection_queue [
					0
				] = job
				_arm_relationship_romance_projection_service()
				return

			job ["phase"] = "complete"

		"complete":
			pass

	_publish_relationship_romance_projection(
		job,
		true
	)

	relationship_romance_projection_keys.erase(
		pair_key
	)
	relationship_romance_projection_queue.pop_front()



	_maybe_author_partner_proposal_for_current_player()

	_arm_relationship_romance_projection_service()
func set_contract(contract: Dictionary = {}) -> Dictionary:
	var base: Dictionary = _build_default_relationship_activity_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		base = _deep_merge_dictionary(base, contract)
	active_contract = base.duplicate(true)
	return active_contract.duplicate(true)

func get_contract() -> Dictionary:
	if active_contract.is_empty():
		set_contract()
	return active_contract.duplicate(true)

func _build_default_relationship_activity_contract() -> Dictionary:
	return {
		"schema": RELATIONSHIP_ACTIVITY_CONTRACT_SCHEMA,
		"version": RELATIONSHIP_ACTIVITY_CONTRACT_VERSION,
		"contract_id": "eralife.relationship_activities.family_care",
		"surface": "relationship_profile",
		"source": "relationship_activities_engine",
		"age_stages": {
			"newborn": {
				"min_age": 0,
				"max_age": 1,
				"actor_actions": ["baby_whine_breastfed", "baby_whine_held", "baby_cry_diaper_change"],
				"caregiver_actions": ["caregiver_breastfeed_child", "caregiver_hold_child", "caregiver_change_diaper"]
			},
			"child": {
				"min_age": 2,
				"max_age": 12,
				"actor_actions": ["child_ask_to_be_fed", "child_ask_to_play"],
				"caregiver_actions": ["caregiver_feed_child_picker", "caregiver_play_peekaboo", "caregiver_play_toys", "caregiver_tell_silly_story"]
			},
			"teen": {
				"min_age": 13,
				"max_age": 17,
				"actor_actions": ["teen_ask_to_hang_out"],
				"caregiver_actions": ["caregiver_check_in_teen", "caregiver_share_meal_teen"]
			},
			"adult": {
				"min_age": 18,
				"max_age": 999,
				"actor_actions": [],
				"caregiver_actions": []
			}
		},
		"care_rules": {
			"breastfeed": {
				"max_child_age": 1,
				"hunger_restore": 42.0,
				"health_delta": 5.0,
				"bond_delta": 8,
				"full_refusal_threshold": 96.0,
				"overeating_chance": 0.18,
				"overeating_health_delta": -1.0,
				"overeating_mental_delta": -1.0
			},
			"hold": {
				"max_child_age": 3,
				"minimum_holder_age": 2,
				"bond_delta": 5,
				"mental_delta": 1
			},
			"diaper_change": {
				"max_child_age": 2,
				"allowed_caregivers": ["parent", "aunt", "uncle"],
				"yearly_limit": FAMILY_CARE_DIAPER_YEAR_LIMIT,
				"bond_delta": 3,
				"health_delta": 1.0
			},
			"feed_child": {
				"max_child_age": 12,
				"open_surface_id": "food_contract_hub",
				"open_section_id": "stores",
				"bond_delta": 4,
				"health_delta": 2.0,
				"full_refusal_threshold": 96.0,
				"overeating_chance": 0.22,
				"overeating_health_delta": -1.0,
				"overeating_mental_delta": -1.0
			},
			"play": {
				"max_child_age": 12,
				"bond_delta": 6,
				"mental_delta": 2,
				"satisfaction_delta": 2
			},
			"teen_connection": {
				"min_child_age": 13,
				"max_child_age": 17,
				"bond_delta": 4,
				"mental_delta": 2
			}
		}
	}
func _relationship_pair_is_adult_romantic_partner(
	actor: Person,
	target: Person
) -> bool:
	if (
		actor == null
		or target == null
		or not actor.alive
		or not target.alive
	):
		return false

	if (
		int(actor.age) < 18
		or int(target.age) < 18
	):
		return false

	if actor.partner == null:
		return false

	return int(
		actor.partner.id
	) == int(
		target.id
	)


func _relationship_pair_can_try_for_baby(
	actor: Person,
	target: Person
) -> bool:
	if not _relationship_pair_is_adult_romantic_partner(
		actor,
		target
	):
		return false

	var actor_gender: String = str(
		actor.gender
	).strip_edges()
	var target_gender: String = str(
		target.gender
	).strip_edges()

	var carrier: Person = null

	if (
		actor_gender == "Female"
		and target_gender == "Male"
	):
		carrier = actor
	elif (
		actor_gender == "Male"
		and target_gender == "Female"
	):
		carrier = target
	else:



		return false

	return int(
		carrier.pregnancy_progress
	) < 0
func get_contextual_relationship_actions(
	actor: Person,
	target: Person,
	_context: Dictionary = {}
) -> Array:
	var actions: Array = []

	if actor == null or target == null:
		return actions

	if not actor.alive or not target.alive:
		return actions

	if int(actor.id) == int(target.id):
		return actions

	if active_contract.is_empty():
		set_contract()

	var actor_age: int = int(actor.age)
	var target_age: int = int(target.age)

	if (
		_is_newborn(actor)
		and _is_family_member(
			target,
			actor
		)
	):
		if _is_mother_of(
			target,
			actor
		):
			actions.append(
				_relationship_contract_action(
					"Whine to be Breastfed",
					"baby_whine_breastfed",
					"Family Care"
				)
			)

		if _can_hold_child(
			target,
			actor
		):
			actions.append(
				_relationship_contract_action(
					"Whine to be Held",
					"baby_whine_held",
					"Family Care"
				)
			)

		if _can_change_diaper(
			target,
			actor
		):
			var diaper_state: Dictionary = (
				_child_care_state(
					actor
				)
			)

			if (
				bool(
					diaper_state.get(
						"diaper_dirty",
						true
					)
				)
				and int(
					diaper_state.get(
						"diaper_changes_this_year",
						0
					)
				) < FAMILY_CARE_DIAPER_YEAR_LIMIT
			):
				actions.append(
					_relationship_contract_action(
						"Cry for Diaper Change",
						"baby_cry_diaper_change",
						"Family Care"
					)
				)

	if (
		actor_age >= 2
		and actor_age <= 12
		and _is_family_member(
			target,
			actor
		)
	):
		actions.append(
			_relationship_contract_action(
				"Ask to be Fed",
				"child_ask_to_be_fed",
				"Family Care"
			)
		)

		actions.append(
			_relationship_contract_action(
				"Ask to Play",
				"child_ask_to_play",
				"Family Care"
			)
		)

	if (
		actor_age >= 13
		and actor_age <= 17
		and _is_family_member(
			target,
			actor
		)
	):
		actions.append(
			_relationship_contract_action(
				"Ask to Hang Out",
				"teen_ask_to_hang_out",
				"Family Care"
			)
		)

	if (
		target_age <= 1
		and _is_mother_of(
			actor,
			target
		)
	):
		actions.append(
			_relationship_contract_action(
				"Breastfeed Child",
				"caregiver_breastfeed_child",
				"Family Care"
			)
		)

	if (
		target_age <= 3
		and _can_hold_child(
			actor,
			target
		)
	):
		actions.append(
			_relationship_contract_action(
				"Hold Child",
				"caregiver_hold_child",
				"Family Care"
			)
		)

	if (
		target_age <= 2
		and _can_change_diaper(
			actor,
			target
		)
	):
		var target_diaper_state: Dictionary = (
			_child_care_state(
				target
			)
		)

		if bool(
			target_diaper_state.get(
				"diaper_dirty",
				true
			)
		):
			actions.append(
				_relationship_contract_action(
					"Change Diaper",
					"caregiver_change_diaper",
					"Family Care"
				)
			)

	if (
		target_age >= 2
		and target_age <= 12
		and _can_feed_child(
			actor,
			target
		)
	):
		var food_actions: Array = (
			_food_picker_actions_for_child(
				actor,
				target
			)
		)

		for action in food_actions:
			actions.append(
				action
			)

		actions.append(
			_relationship_contract_action(
				"Play Peekaboo",
				"caregiver_play_peekaboo",
				"Family Care"
			)
		)

		actions.append(
			_relationship_contract_action(
				"Play With Toys",
				"caregiver_play_toys",
				"Family Care"
			)
		)

		actions.append(
			_relationship_contract_action(
				"Tell a Silly Story",
				"caregiver_tell_silly_story",
				"Family Care"
			)
		)

	if (
		target_age >= 13
		and target_age <= 17
		and _is_family_member(
			actor,
			target
		)
	):
		actions.append(
			_relationship_contract_action(
				"Check In With Them",
				"caregiver_check_in_teen",
				"Family Care"
			)
		)

		actions.append(
			_relationship_contract_action(
				"Share a Meal With Them",
				"caregiver_share_meal_teen",
				"Family Care"
			)
		)

	var adult_romantic_partner: bool = (
		_relationship_pair_is_adult_romantic_partner(
			actor,
			target
		)
	)

	if adult_romantic_partner:
		var relationship_status: String = str(
			actor.marital_status
		).strip_edges().to_lower()

		match relationship_status:
			"dating", "partnered":
				actions.append(
					_relationship_contract_action(
						"Propose",
						"propose",
						"Romance"
					)
				)

			"engaged":
				actions.append(
					_relationship_contract_action(
						"Plan Marriage",
						"plan_marriage",
						"Romance"
					)
				)

			"married":
				actions.append(
					_relationship_contract_action(
						"Divorce",
						"divorce",
						"Romance"
					)
				)

		actions.append(
			_relationship_contract_action(
				"Make Love",
				"make_love",
				"Romance"
			)
		)

		if _relationship_pair_can_try_for_baby(
			actor,
			target
		):
			actions.append(
				_relationship_contract_action(
					"Try for Baby",
					"try_for_baby",
					"Romance"
				)
			)

	if (
		actor_age >= 18
		and target_age >= 18
		and int(
			target.id
		) in actor.friends
		and (
			actor.partner == null
			or int(
				actor.partner.id
			) != int(
				target.id
			)
		)
		and not _pair_has_relationship_graph_type(
			actor,
			target,
			"friends_with_benefits"
		)
	):
		actions.append(
			_relationship_contract_action(
				"Ask to Be FWB",
				"ask_fwb",
				"Romance"
			)
		)

	return actions
func _relationship_lifecycle_choice(
	label: String,
	choice_id: String,
	payload: Dictionary,
	commits_truth: bool = true
) -> Dictionary:
	var choice_payload: Dictionary = (
		payload.duplicate(false)
	)

	choice_payload [
		"source"
	] = str(
		choice_payload.get(
			"source",
			"relationship_activities_engine.lifecycle_choice"
		)
	)

	return {
		"id": choice_id,
		"label": label,
		"detail_action": "engine_call",
		"engine_property": (
			"relationship_activities_engine"
		),
		"method": (
			"resolve_relationship_lifecycle_intent"
		),
		"payload": choice_payload,
		"commits_reality_truth": commits_truth,
		"authority_prevalidated": not commits_truth
	}


func _proposal_entry_result(
	_actor: Person,
	target: Person
) -> Dictionary:
	return {
		"success": true,
		"popup_title": "Propose",
		"popup_text": (
			"Do you want to propose to %s with a ring or other jewelry?"
			% target.first_name
		),
		"popup_footer": "Choose how you want to propose.",
		"choices": [
			_relationship_lifecycle_choice(
				"Yes — Choose Jewelry",
				"proposal_with_jewelry",
				{
					"action_id": (
						"proposal_choose_jewelry"
					),
					"target_id": int(
						target.id
					)
				},
				false
			),
			_relationship_lifecycle_choice(
				"No Jewelry",
				"proposal_without_jewelry",
				{
					"action_id": (
						"proposal_confirm_without_jewelry"
					),
					"target_id": int(
						target.id
					)
				},
				false
			)
		]
	}


func _engage_relationship_pair(
	actor: Person,
	target: Person,
	_context: Dictionary = {}
) -> void:
	if (
		actor == null
		or target == null
	):
		return

	actor.partner = target
	target.partner = actor

	actor.marital_status = "Engaged"
	target.marital_status = "Engaged"

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	lifecycle [
		"status"
	] = "Engaged"
	lifecycle [
		"engaged_year"
	] = _relationship_current_year()
	lifecycle [
		"engaged_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	_store_relationship_lifecycle_contract(
		lifecycle
	)

	_relationship_adjust_pair_bond(
		actor,
		target,
		10
	)

	queue_relationship_romance_projection(
		actor,
		target,
		"relationship_engaged"
	)

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			ActionEventTypes.NPC_PARTNERED,
			{
				"npc_id": int(
					actor.id
				),
				"target_id": int(
					target.id
				),
				"other_person_id": int(
					target.id
				),
				"relationship_status": "Engaged",
				"text": (
					"%s and %s became engaged."
					% [
						actor.first_name,
						target.first_name
					]
				),
				"source": (
					"relationship_activities_engine"
				),
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true
				}
			}
		)


func _submit_proposal_with_jewelry(
	actor: Person,
	target: Person,
	jewelry_key: String
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"popup_title": "Proposal",
			"popup_text": "That proposal is no longer valid.",
			"popup_footer": "Tap anywhere to continue."
		}

	var projection: Dictionary = (
		_resident_relationship_romance_projection(
			actor,
			target
		)
	)

	var jewelry_by_key: Dictionary = (
		_relationship_dict(
			projection.get(
				"actor_proposal_jewelry_by_key",
				{}
			)
		)
	)

	var jewelry: Dictionary = _relationship_dict(
		jewelry_by_key.get(
			jewelry_key,
			{}
		)
	)

	if jewelry.is_empty():
		return {
			"success": false,
			"popup_title": "Proposal",
			"popup_text": (
				"That jewelry is no longer part of the resident "
				+ "proposal inventory."
			),
			"popup_footer": "Choose another item."
		}

	var bond: int = _relationship_pair_bond(
		actor,
		target
	)
	var mental: int = clampi(
		int(
			target.mental_health
		),
		0,
		100
	)
	var jewelry_value: float = float(
		jewelry.get(
			"value",
			0.0
		)
	)


	if mental < 35:
		var theft_chance: int = clampi(
			20 + (
				35 - mental
			) * 2,
			20,
			62
		)

		if randi() % 100 < theft_chance:
			if (
				gs.belongings_engine != null
				and gs.belongings_engine.has_method(
					"queue_relationship_item_transfer"
				)
			):
				gs.belongings_engine.queue_relationship_item_transfer(
					int(
						actor.id
					),
					int(
						target.id
					),
					"Luxury",
					jewelry_key,
					"proposal_ring_stolen"
				)

			_relationship_adjust_pair_bond(
				actor,
				target,
				-28
			)

			if gs != null:
				gs.end_partnership(
					actor,
					true
				)

			return {
				"success": true,
				"text": (
					"%s took my %s and broke up with me."
					% [
						target.first_name,
						str(
							jewelry.get(
								"item_name",
								"jewelry"
							)
						)
					]
				),
				"popup_title": "They Took It",
				"popup_text": (
					"%s pocketed your %s and ended the relationship."
					% [
						target.first_name,
						str(
							jewelry.get(
								"item_name",
								"jewelry"
							)
						)
					]
				),
				"popup_footer": (
					"The item is transferring into their belongings."
				)
			}

	var jewelry_bonus: int = clampi(
		int(
			jewelry_value / 500.0
		),
		0,
		30
	)

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)
	var dating_years: int = maxi(
		0,
		_relationship_current_year()
		- int(
			lifecycle.get(
				"dating_started_year",
				_relationship_current_year()
			)
		)
	)

	var acceptance_chance: int = clampi(
		18
		+ int(
			float(bond) * 0.52
		)
		+ mini(
			12,
			dating_years * 4
		)
		+ jewelry_bonus,
		5,
		98
	)

	if randi() % 100 < acceptance_chance:
		_engage_relationship_pair(
			actor,
			target,
			{
				"proposal_jewelry_key": jewelry_key
			}
		)

		if (
			gs.belongings_engine != null
			and gs.belongings_engine.has_method(
				"queue_relationship_item_transfer"
			)
		):
			gs.belongings_engine.queue_relationship_item_transfer(
				int(
					actor.id
				),
				int(
					target.id
				),
				"Luxury",
				jewelry_key,
				"proposal_accepted"
			)

		return {
			"success": true,
			"text": (
				"I proposed to %s. They said yes."
				% target.first_name
			),
			"popup_title": "Engaged!",
			"popup_text": (
				"%s said yes. You are now engaged."
				% target.first_name
			),
			"popup_footer": (
				"Plan Marriage is now available in relationship activities."
			)
		}

	_relationship_adjust_pair_bond(
		actor,
		target,
		-8
	)

	return {
		"success": true,
		"text": (
			"I proposed to %s, but they rejected me."
			% target.first_name
		),
		"popup_title": "Proposal Rejected",
		"popup_text": (
			"%s said no."
			% target.first_name
		),
		"popup_footer": (
			"Your bond dropped."
		)
	}


func _submit_proposal_without_jewelry(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"popup_title": "Proposal",
			"popup_text": "That proposal is no longer valid.",
			"popup_footer": "Tap anywhere to continue."
		}

	var mental: int = clampi(
		int(
			target.mental_health
		),
		0,
		100
	)



	if mental >= 45:
		_relationship_adjust_pair_bond(
			actor,
			target,
			-12
		)

		return {
			"success": true,
			"text": (
				"I proposed to %s without any jewelry. They rejected me."
				% target.first_name
			),
			"popup_title": "Proposal Rejected",
			"popup_text": (
				"%s rejected your jewelry-less proposal."
				% target.first_name
			),
			"popup_footer": (
				"Your bond dropped noticeably."
			)
		}

	var bond: int = _relationship_pair_bond(
		actor,
		target
	)

	var acceptance_chance: int = clampi(
		10
		+ int(
			float(bond) * 0.45
		),
		5,
		75
	)

	if randi() % 100 < acceptance_chance:
		_engage_relationship_pair(
			actor,
			target
		)

		return {
			"success": true,
			"text": (
				"I proposed to %s without jewelry. They still said yes."
				% target.first_name
			),
			"popup_title": "Engaged!",
			"popup_text": (
				"%s accepted the proposal."
				% target.first_name
			),
			"popup_footer": (
				"Plan Marriage is now available."
			)
		}

	_relationship_adjust_pair_bond(
		actor,
		target,
		-10
	)

	return {
		"success": true,
		"text": (
			"I proposed to %s without jewelry. They rejected me."
			% target.first_name
		),
		"popup_title": "Proposal Rejected",
		"popup_text": (
			"%s said no."
			% target.first_name
		),
		"popup_footer": "Your bond dropped."
	}
func resolve_relationship_lifecycle_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"popup_title": "Relationship",
			"popup_text": "That relationship decision is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			""
		)
	).strip_edges().to_lower()

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)

	var target: Person = (
		_relationship_resident_person_by_id(
			target_id
		)
	)

	if (
		target == null
		and action_id not in [
			"show_marriage_finance_merge"
		]
	):
		return {
			"success": false,
			"popup_title": "Relationship",
			"popup_text": (
				"That person is no longer resident in this relationship lens."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	match action_id:
		"proposal_choose_jewelry":
			var projection: Dictionary = (
				_resident_relationship_romance_projection(
					actor,
					target
				)
			)

			var projection_complete: bool = bool(
				projection.get(
					"projection_complete",
					false
				)
			)

			var choices: Array = (
				_relationship_array(
					projection.get(
						"actor_proposal_choice_contracts",
						[]
					)
				)
			)

			if choices.is_empty():
				var shop_choice: Dictionary = (
					_relationship_lifecycle_choice(
						"Go to Luxury Shop",
						"open_luxury_shop",
						{
							"action_id": (
								"open_luxury_shop_for_proposal"
							),
							"target_id": int(
								target.id
							)
						},
						false
					)
				)

				return {
					"success": true,
					"popup_title": "Proposal Jewelry",
					"popup_text": (
						"No proposal-worthy jewelry is resident "
						+ "in your belongings."
						if projection_complete
						else (
							"Your proposal jewelry is still publishing. "
							+ "You can keep playing while it finishes."
						)
					),
					"popup_footer": (
						"Luxury shops sell rings and jewelry."
					),
					"choices": [
						shop_choice
					]
				}

			return {
				"success": true,
				"popup_title": "Choose Proposal Jewelry",
				"popup_text": (
					"Choose the ring or jewelry you want to propose with."
				),
				"popup_footer": (
					"More valuable jewelry improves the acceptance odds."
				),

				"choices": choices
			}

		"proposal_confirm_without_jewelry":
			return {
				"success": true,
				"popup_title": "No Jewelry?",
				"popup_text": (
					"Are you SURE you want to propose without ANY jewelry?"
				),
				"popup_footer": (
					"This can seriously affect how they react."
				),
				"choices": [
					_relationship_lifecycle_choice(
						"Yes, Propose Anyway",
						"confirm_no_jewelry",
						{
							"action_id": (
								"submit_proposal_without_jewelry"
							),
							"target_id": int(
								target.id
							)
						}
					),
					{
						"id": "cancel",
						"label": "Never Mind",
						"detail_action": "close"
					}
				]
			}

		"submit_proposal_with_jewelry":
			return _submit_proposal_with_jewelry(
				actor,
				target,
				str(
					payload.get(
						"jewelry_key",
						""
					)
				)
			)

		"submit_proposal_without_jewelry":
			return _submit_proposal_without_jewelry(
				actor,
				target
			)

		"open_luxury_shop_for_proposal":
			return {
				"success": true,
				"open_surface_id": "luxury_contract_hub",
				"open_section_id": "shops",
				"text": (
					"I went to look for proposal jewelry."
				)
			}

		"reveal_marriage_planner":
			return {
				"success": true,
				"relationship_hub_reveal_section": "partner",
				"text": (
					"The resident marriage planner is in the Partner section."
				),
				"ui_is_renderer_only": true
			}

		"commit_marriage_plan":
			return _commit_relationship_marriage_plan(
				actor,
				target,
				payload
			)

		"show_marriage_finance_merge":
			return _marriage_finance_merge_result(
				actor,
				target
			)

		"apply_marriage_name_choice":
			return _apply_marriage_name_choice(
				actor,
				target,
				payload
			)

		"commit_divorce":
			return _commit_relationship_divorce(
				actor,
				target
			)

		_:
			return {
				"success": false,
				"popup_title": "Relationship",
				"popup_text": (
					"That relationship lifecycle action is not registered."
				),
				"popup_footer": "Tap anywhere to continue."
			}
func _commit_relationship_marriage_plan(
	actor: Person,
	target: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"popup_title": "Marriage",
			"popup_text": "That marriage can no longer be planned.",
			"popup_footer": "Tap anywhere to continue."
		}

	if (
		str(
			actor.marital_status
		).strip_edges().to_lower()
		!= "engaged"
		or str(
			target.marital_status
		).strip_edges().to_lower()
		!= "engaged"
	):
		return {
			"success": false,
			"popup_title": "Marriage",
			"popup_text": "You need to be engaged first.",
			"popup_footer": "Tap anywhere to continue."
		}

	var projection: Dictionary = (
		_resident_relationship_romance_projection(
			actor,
			target
		)
	)

	if not bool(
		projection.get(
			"projection_complete",
			false
		)
	):
		return {
			"success": false,
			"popup_title": "Marriage Planner",
			"popup_text": (
				"Wedding and honeymoon reality is still publishing. "
				+ "Nothing has blocked; keep playing and try again once "
				+ "the resident planner has the destination you want."
			),
			"popup_footer": (
				"The planner continues publishing without observation."
			)
		}

	var wedding_type_id: String = str(
		payload.get(
			"wedding_type_id",
			""
		)
	).strip_edges()
	var honeymoon_realm_id: int = int(
		payload.get(
			"honeymoon_realm_id",
			-1
		)
	)

	var wedding_by_id: Dictionary = (
		_relationship_dict(
			projection.get(
				"wedding_type_by_id",
				{}
			)
		)
	)
	var honeymoon_by_id: Dictionary = (
		_relationship_dict(
			projection.get(
				"honeymoon_realm_by_id",
				{}
			)
		)
	)

	var wedding: Dictionary = _relationship_dict(
		wedding_by_id.get(
			wedding_type_id,
			{}
		)
	)
	var honeymoon: Dictionary = _relationship_dict(
		honeymoon_by_id.get(
			str(
				honeymoon_realm_id
			),
			{}
		)
	)

	if wedding.is_empty():
		return {
			"success": false,
			"popup_title": "Marriage Planner",
			"popup_text": "Choose a wedding type.",
			"popup_footer": "Tap anywhere to continue."
		}

	if honeymoon.is_empty():
		return {
			"success": false,
			"popup_title": "Marriage Planner",
			"popup_text": (
				"Choose a resident realm for your honeymoon."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var wedding_cost: float = float(
		wedding.get(
			"cost",
			0.0
		)
	)
	var honeymoon_cost: float = float(
		honeymoon.get(
			"cost",
			0.0
		)
	)

	var total_cost: float = (
		wedding_cost
		+ honeymoon_cost
	)

	if float(
		actor.bank_balance
	) < total_cost:
		return {
			"success": false,
			"popup_title": "Marriage Planner",
			"popup_text": (
				"You need $%0.2f, but you only have $%0.2f."
				% [
					total_cost,
					float(
						actor.bank_balance
					)
				]
			),
			"popup_footer": "Choose a cheaper plan or earn more money."
		}

	var requested_prenup: bool = bool(
		payload.get(
			"request_prenup",
			false
		)
	)
	var bond: int = _relationship_pair_bond(
		actor,
		target
	)
	var prenup_signed: bool = false

	if requested_prenup:
		var prenup_acceptance: int = clampi(
			28
			+ int(
				float(bond) * 0.55
			)
			+ int(
				float(
					target.mental_health
				) * 0.12
			),
			5,
			96
		)

		prenup_signed = (
			randi() % 100
			< prenup_acceptance
		)

		if not prenup_signed:
			return {
				"success": true,
				"text": (
					"%s refused to sign the prenup."
					% target.first_name
				),
				"popup_title": "Prenup Refused",
				"popup_text": (
					"%s would not sign the prenuptial agreement. "
					+ "The wedding has not happened."
				) % target.first_name,
				"popup_footer": (
					"You can change the plan or try again later."
				)
			}


	var actor_premarital_balance: float = float(
		actor.bank_balance
	)
	var target_premarital_balance: float = float(
		target.bank_balance
	)

	actor.bank_balance = (
		float(
			actor.bank_balance
		) - total_cost
	)

	var combined_after_wedding_cost: float = (
		float(
			actor.bank_balance
		)
		+ float(
			target.bank_balance
		)
	)

	var merged_share: float = (
		combined_after_wedding_cost * 0.5
	)

	actor.bank_balance = merged_share
	target.bank_balance = merged_share

	actor.marital_status = "Married"
	target.marital_status = "Married"
	actor.partner = target
	target.partner = actor

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	lifecycle ["status"] = "Married"
	lifecycle ["marriage_year"] = (
		_relationship_current_year()
	)
	lifecycle ["married_at_ms"] = int(
		Time.get_ticks_msec()
	)
	lifecycle ["prenup_requested"] = (
		requested_prenup
	)
	lifecycle ["prenup_signed"] = (
		prenup_signed
	)
	lifecycle [
		"actor_premarital_balance"
	] = actor_premarital_balance
	lifecycle [
		"target_premarital_balance"
	] = target_premarital_balance
	lifecycle [
		"premarital_property_keys_actor"
	] = _relationship_dict(
		projection.get(
			"premarital_property_keys_actor",
			{}
		)
	)
	lifecycle [
		"premarital_property_keys_target"
	] = _relationship_dict(
		projection.get(
			"premarital_property_keys_target",
			{}
		)
	)
	lifecycle ["wedding_type_id"] = wedding_type_id
	lifecycle ["wedding_type_label"] = str(
		wedding.get(
			"label",
			"Wedding"
		)
	)
	lifecycle ["honeymoon_realm_id"] = (
		honeymoon_realm_id
	)
	lifecycle ["honeymoon_realm_name"] = str(
		honeymoon.get(
			"realm_name",
			""
		)
	)
	lifecycle ["wedding_cost"] = wedding_cost
	lifecycle ["honeymoon_cost"] = honeymoon_cost
	lifecycle ["total_wedding_cost"] = total_cost
	lifecycle ["finance_merge_report"] = {
		"combined_after_wedding_cost": (
			combined_after_wedding_cost
		),
		"actor_balance_after_merge": (
			float(
				actor.bank_balance
			)
		),
		"target_balance_after_merge": (
			float(
				target.bank_balance
			)
		),
		"prenup_signed": prenup_signed,
		"actor_premarital_balance": (
			actor_premarital_balance
		),
		"target_premarital_balance": (
			target_premarital_balance
		)
	}



	if (
		str(
			actor.gender
		).strip_edges().to_lower()
		== "male"
		and str(
			target.gender
		).strip_edges().to_lower()
		== "female"
		and str(
			actor.last_name
		).strip_edges() != ""
	):
		var take_name_chance: int = clampi(
			42
			+ int(
				float(bond) * 0.48
			),
			20,
			95
		)

		var target_took_name: bool = (
			randi() % 100
			< take_name_chance
		)

		lifecycle [
			"target_wanted_actor_last_name"
		] = target_took_name

		if target_took_name:
			lifecycle [
				"target_previous_last_name"
			] = str(
				target.last_name
			)

			target.last_name = str(
				actor.last_name
			)

	_store_relationship_lifecycle_contract(
		lifecycle
	)

	if (
		gs.event_bus != null
	):
		gs.event_bus.emit(
			ActionEventTypes.NPC_MARRIED,
			{
				"npc_id": int(
					actor.id
				),
				"actor_id": int(
					actor.id
				),
				"target_id": int(
					target.id
				),
				"spouse_id": int(
					target.id
				),
				"marriage_year": int(
					lifecycle.get(
						"marriage_year",
						gs.year
					)
				),
				"prenup_signed": prenup_signed,
				"premarital_property_keys_actor": (
					_relationship_dict(
						lifecycle.get(
							"premarital_property_keys_actor",
							{}
						)
					)
				),
				"premarital_property_keys_target": (
					_relationship_dict(
						lifecycle.get(
							"premarital_property_keys_target",
							{}
						)
					)
				),
				"text": (
					"%s married %s."
					% [
						actor.first_name,
						target.first_name
					]
				),
				"source": (
					"relationship_activities_engine"
				),
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true
				}
			}
		)

	queue_relationship_romance_projection(
		actor,
		target,
		"marriage_committed"
	)

	return {
		"success": true,
		"text": (
			"I married %s."
			% target.first_name
		),
		"popup_title": "We're Married!",
		"popup_text": (
			"You had a %s and honeymooned in %s.\n\n"
			+ "Wedding: $%0.2f\n"
			+ "Honeymoon: $%0.2f"
		) % [
			str(
				wedding.get(
					"label",
					"wedding"
				)
			),
			str(
				honeymoon.get(
					"realm_name",
					"another realm"
				)
			),
			wedding_cost,
			honeymoon_cost
		],
		"popup_footer": (
			"Continue to see your merged finances."
		),
		"choices": [
			_relationship_lifecycle_choice(
				"Continue",
				"show_finance_merge",
				{
					"action_id": (
						"show_marriage_finance_merge"
					),
					"target_id": int(
						target.id
					)
				},
				false
			)
		]
	}


func _marriage_finance_merge_result(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"popup_title": "Marriage Finances",
			"popup_text": (
				"The marriage finance contract is unavailable."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var lifecycle: Dictionary = (
		_resident_relationship_lifecycle_contract(
			actor,
			target
		)
	)
	var report: Dictionary = _relationship_dict(
		lifecycle.get(
			"finance_merge_report",
			{}
		)
	)

	var prenup_text: String = (
		"A signed prenup protects what each of you brought into the marriage."
		if bool(
			lifecycle.get(
				"prenup_signed",
				false
			)
		)
		else (
			"No prenup was signed. The marital estate is subject "
			+ "to equal divorce settlement."
		)
	)

	var result: Dictionary = {
		"success": true,
		"popup_title": "Merging Finances",
		"popup_text": (
			"You are now financially joined.\n\n"
			+ "Combined post-wedding liquid wealth: $%0.2f\n"
			+ "Your current share: $%0.2f\n"
			+ "%s's current share: $%0.2f\n\n"
			+ "%s"
		) % [
			float(
				report.get(
					"combined_after_wedding_cost",
					0.0
				)
			),
			float(
				actor.bank_balance
			),
			target.first_name,
			float(
				target.bank_balance
			),
			prenup_text
		],
		"popup_footer": "Tap anywhere to continue.",
		"choices": []
	}


	if (
		str(
			actor.gender
		).strip_edges().to_lower()
		== "female"
		and str(
			target.gender
		).strip_edges().to_lower()
		== "male"
		and str(
			target.last_name
		).strip_edges() != ""
		and str(
			actor.last_name
		) != str(
			target.last_name
		)
	):
		result ["popup_footer"] = (
			"Do you want to take %s's last name?"
			% target.first_name
		)

		result ["choices"] = [
			_relationship_lifecycle_choice(
				"Take %s" % target.last_name,
				"take_spouse_last_name",
				{
					"action_id": (
						"apply_marriage_name_choice"
					),
					"target_id": int(
						target.id
					),
					"take_spouse_last_name": true
				}
			),
			_relationship_lifecycle_choice(
				"Keep %s" % actor.last_name,
				"keep_last_name",
				{
					"action_id": (
						"apply_marriage_name_choice"
					),
					"target_id": int(
						target.id
					),
					"take_spouse_last_name": false
				}
			)
		]

	return result


func _apply_marriage_name_choice(
	actor: Person,
	target: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"popup_title": "Marriage",
			"popup_text": "That name choice is no longer available.",
			"popup_footer": "Tap anywhere to continue."
		}

	var take_name: bool = bool(
		payload.get(
			"take_spouse_last_name",
			false
		)
	)

	if take_name:
		var previous_name: String = str(
			actor.last_name
		)

		actor.last_name = str(
			target.last_name
		)

		return {
			"success": true,
			"text": (
				"I took %s's last name."
				% target.first_name
			),
			"popup_title": "New Family Name",
			"popup_text": (
				"You changed your surname from %s to %s."
				% [
					previous_name,
					actor.last_name
				]
			),
			"popup_footer": "Tap anywhere to continue."
		}

	return {
		"success": true,
		"text": "I kept my last name.",
		"popup_title": "Family Name",
		"popup_text": (
			"You decided to keep your current surname."
		),
		"popup_footer": "Tap anywhere to continue."
	}


func _divorce_entry_result(
	actor: Person,
	target: Person
) -> Dictionary:
	var lifecycle: Dictionary = (
		_resident_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	var prenup_signed: bool = bool(
		lifecycle.get(
			"prenup_signed",
			false
		)
	)

	return {
		"success": true,
		"popup_title": "Divorce",
		"popup_text": (
			"Are you sure you want to divorce %s?\n\n%s"
			% [
				target.first_name,
				(
					"A signed prenup will protect premarital property and liquid wealth."
					if prenup_signed
					else (
						"There is no prenup. The marital estate will "
						+ "be divided equally."
					)
				)
			]
		),
		"popup_footer": (
			"This permanently ends the marriage."
		),
		"choices": [
			_relationship_lifecycle_choice(
				"Divorce",
				"confirm_divorce",
				{
					"action_id": "commit_divorce",
					"target_id": int(
						target.id
					)
				}
			),
			{
				"id": "cancel",
				"label": "Stay Married",
				"detail_action": "close"
			}
		]
	}


func _commit_relationship_divorce(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
		or str(
			actor.marital_status
		).strip_edges().to_lower()
		!= "married"
	):
		return {
			"success": false,
			"popup_title": "Divorce",
			"popup_text": "You are not legally married.",
			"popup_footer": "Tap anywhere to continue."
		}

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	var prenup_signed: bool = bool(
		lifecycle.get(
			"prenup_signed",
			false
		)
	)

	var actor_before: float = float(
		actor.bank_balance
	)
	var target_before: float = float(
		target.bank_balance
	)
	var combined: float = (
		actor_before
		+ target_before
	)

	var actor_after: float = 0.0
	var target_after: float = 0.0

	if prenup_signed:
		var actor_protected: float = maxf(
			0.0,
			float(
				lifecycle.get(
					"actor_premarital_balance",
					0.0
				)
			)
		)
		var target_protected: float = maxf(
			0.0,
			float(
				lifecycle.get(
					"target_premarital_balance",
					0.0
				)
			)
		)

		var protected_total: float = (
			actor_protected
			+ target_protected
		)

		if combined >= protected_total:
			var marital_gain: float = (
				combined
				- protected_total
			)

			actor_after = (
				actor_protected
				+ marital_gain * 0.5
			)
			target_after = (
				target_protected
				+ marital_gain * 0.5
			)
		elif protected_total > 0.0:



			var actor_ratio: float = (
				actor_protected
				/ protected_total
			)

			actor_after = (
				combined
				* actor_ratio
			)
			target_after = (
				combined
				- actor_after
			)
		else:
			actor_after = combined * 0.5
			target_after = combined * 0.5
	else:
		actor_after = combined * 0.5
		target_after = combined * 0.5

	actor.bank_balance = actor_after
	target.bank_balance = target_after

	lifecycle ["status"] = "Divorced"
	lifecycle ["divorce_year"] = (
		_relationship_current_year()
	)
	lifecycle ["divorced_at_ms"] = int(
		Time.get_ticks_msec()
	)
	lifecycle ["divorce_finance_report"] = {
		"prenup_signed": prenup_signed,
		"combined_before": combined,
		"actor_before": actor_before,
		"target_before": target_before,
		"actor_after": actor_after,
		"target_after": target_after
	}

	_store_relationship_lifecycle_contract(
		lifecycle
	)

	var actor_id: int = int(
		actor.id
	)
	var target_id: int = int(
		target.id
	)



	gs.end_partnership(
		actor,
		true
	)

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.NPC_DIVORCED,
			{
				"npc_id": actor_id,
				"actor_id": actor_id,
				"target_id": target_id,
				"spouse_id": target_id,
				"prenup_signed": prenup_signed,
				"marriage_year": int(
					lifecycle.get(
						"marriage_year",
						-999999
					)
				),
				"premarital_property_keys_actor": (
					_relationship_dict(
						lifecycle.get(
							"premarital_property_keys_actor",
							{}
						)
					)
				),
				"premarital_property_keys_target": (
					_relationship_dict(
						lifecycle.get(
							"premarital_property_keys_target",
							{}
						)
					)
				),
				"text": (
					"%s and %s divorced."
					% [
						actor.first_name,
						target.first_name
					]
				),
				"source": (
					"relationship_activities_engine"
				),
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true
				}
			}
		)

	return {
		"success": true,
		"text": (
			"I divorced %s."
			% target.first_name
		),
		"popup_title": "Divorced",
		"popup_text": (
			"Your marriage ended.\n\n"
			+ "Your liquid balance: $%0.2f\n"
			+ "%s's liquid balance: $%0.2f\n\n"
			+ "%s"
		) % [
			actor_after,
			target.first_name,
			target_after,
			(
				"The signed prenup protected premarital assets."
				if prenup_signed
				else (
					"The marital liquid estate was divided equally."
				)
			)
		],
		"popup_footer": (
			"Real-estate settlement continues in the background."
		)
	}
func _bind_relationship_lifecycle_runtime() -> void:
	if (
		relationship_lifecycle_runtime_bound
		or gs == null
		or gs.event_bus == null
	):
		return

	relationship_lifecycle_runtime_bound = true

	gs.event_bus.subscribe(
		ActionEventTypes.REALTIME_TICK,
		self,
		"_on_relationship_lifecycle_realtime_tick",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 142,
			"subscription_id": (
				"relationship_lifecycle_controlled_pair_probe"
			)
		}
	)

	gs.event_bus.subscribe(
		ActionEventTypes.YEAR_PASSED,
		self,
		"_on_relationship_lifecycle_year_passed",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 143,
			"subscription_id": (
				"relationship_lifecycle_year"
			)
		}
	)

	for raw_event in [
		ActionEventTypes.NPC_PARTNERED,
		ActionEventTypes.NPC_MARRIED,
		ActionEventTypes.NPC_DIVORCED
	]:
		var event_name: String = str(
			raw_event
		)

		gs.event_bus.subscribe(
			event_name,
			self,
			"_on_relationship_lifecycle_pair_event",
			{
				"lane": "ambient",
				"allow_defer": true,
				"subscription_priority": 144,
				"subscription_id": (
					"relationship_lifecycle_pair:%s"
					% event_name
				)
			}
		)

	gs.event_bus.subscribe(
		"belongings.event",
		self,
		"_on_relationship_lifecycle_belongings_event",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 145,
			"subscription_id": (
				"relationship_lifecycle_belongings"
			)
		}
	)

	_on_relationship_lifecycle_realtime_tick(
		{}
	)


func _on_relationship_lifecycle_realtime_tick(
	_payload: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.player == null
	):
		return

	var actor: Person = gs.player
	var partner: Person = actor.partner

	var partner_id: int = (
		int(
			partner.id
		)
		if partner != null
		else -1
	)

	var signature: String = (
		"%d:%d:%s:%d:%s"
		% [
			int(
				actor.id
			),
			partner_id,
			str(
				actor.marital_status
			),
			_relationship_current_year(),
			str(
				gs.reality_mode
			)
		]
	)

	var previous_signature: String = str(
		get_meta(
			"relationship_lifecycle_controlled_pair_signature",
			""
		)
	)

	if signature == previous_signature:
		return

	set_meta(
		"relationship_lifecycle_controlled_pair_signature",
		signature
	)

	if (
		partner == null
		or not partner.alive
	):
		return

	_ensure_relationship_lifecycle_contract(
		actor,
		partner
	)

	queue_relationship_romance_projection(
		actor,
		partner,
		"controlled_pair_changed"
	)


func _on_relationship_lifecycle_pair_event(
	payload: Dictionary = {}
) -> void:
	if gs == null:
		return

	var actor_id: int = int(
		payload.get(
			"npc_id",
			payload.get(
				"actor_id",
				-1
			)
		)
	)
	var target_id: int = int(
		payload.get(
			"target_id",
			payload.get(
				"other_person_id",
				-1
			)
		)
	)

	var actor: Person = (
		_relationship_resident_person_by_id(
			actor_id
		)
	)
	var target: Person = (
		_relationship_resident_person_by_id(
			target_id
		)
	)

	if (
		actor == null
		or target == null
	):
		return

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	lifecycle [
		"status"
	] = str(
		actor.marital_status
	)

	if (
		str(
			actor.marital_status
		).strip_edges().to_lower()
		== "dating"
		and int(
			lifecycle.get(
				"dating_started_year",
				-999999
			)
		) <= -999000
	):
		lifecycle [
			"dating_started_year"
		] = _relationship_current_year()

	_store_relationship_lifecycle_contract(
		lifecycle
	)

	if (
		gs.player != null
		and int(
			gs.player.id
		) in [
			actor_id,
			target_id
		]
	):
		var controlled_actor: Person = gs.player
		var controlled_partner: Person = (
			target
			if int(
				controlled_actor.id
			) == actor_id
			else actor
		)

		queue_relationship_romance_projection(
			controlled_actor,
			controlled_partner,
			"relationship_pair_event"
		)


func _on_relationship_lifecycle_belongings_event(
	payload: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.player == null
		or gs.player.partner == null
	):
		return

	var owner_id: int = int(
		payload.get(
			"owner_id",
			payload.get(
				"actor_id",
				payload.get(
					"npc_id",
					-1
				)
			)
		)
	)

	if owner_id not in [
		int(
			gs.player.id
		),
		int(
			gs.player.partner.id
		)
	]:
		return

	queue_relationship_romance_projection(
		gs.player,
		gs.player.partner,
		"relationship_belongings_changed"
	)


func _on_relationship_lifecycle_year_passed(
	_payload: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.player == null
		or gs.player.partner == null
	):
		return

	queue_relationship_romance_projection(
		gs.player,
		gs.player.partner,
		"relationship_year_changed"
	)

	_maybe_author_partner_proposal_for_current_player()


func _maybe_author_partner_proposal_for_current_player() -> void:
	if (
		gs == null
		or gs.player == null
		or gs.player.partner == null
		or gs.scenario_runtime_contract_engine == null
	):
		return

	var actor: Person = gs.player
	var target: Person = actor.partner

	if (
		not actor.alive
		or not target.alive
		or int(
			actor.age
		) < 18
		or int(
			target.age
		) < 18
		or str(
			actor.marital_status
		).strip_edges().to_lower()
		!= "dating"
	):
		return

	var lifecycle: Dictionary = (
		_ensure_relationship_lifecycle_contract(
			actor,
			target
		)
	)

	var current_year: int = (
		_relationship_current_year()
	)
	var dating_started_year: int = int(
		lifecycle.get(
			"dating_started_year",
			current_year
		)
	)
	var dating_years: int = maxi(
		0,
		current_year - dating_started_year
	)

	if dating_years < 2:
		return

	var bond: int = _relationship_pair_bond(
		actor,
		target
	)

	if bond < 75:
		return

	if int(
		lifecycle.get(
			"last_partner_proposal_roll_year",
			-999999
		)
	) == current_year:
		return

	var projection: Dictionary = (
		_resident_relationship_romance_projection(
			actor,
			target
		)
	)

	if not bool(
		projection.get(
			"projection_complete",
			false
		)
	):
		return

	lifecycle [
		"last_partner_proposal_roll_year"
	] = current_year

	_store_relationship_lifecycle_contract(
		lifecycle
	)

	var proposal_chance: int = clampi(
		8
		+ (
			bond - 75
		)
		+ mini(
			16,
			(
				dating_years - 2
			) * 4
		),
		8,
		55
	)

	if randi() % 100 >= proposal_chance:
		return

	var jewelry: Dictionary = _relationship_dict(
		projection.get(
			"best_target_proposal_jewelry",
			{}
		)
	)
	var jewelry_name: String = str(
		jewelry.get(
			"item_name",
			""
		)
	).strip_edges()

	var proposal_text: String = (
		"%s asked you to marry them."
		% target.first_name
	)

	if jewelry_name != "":
		proposal_text = (
			"%s proposed to you with %s."
			% [
				target.first_name,
				jewelry_name
			]
		)

	gs.scenario_runtime_contract_engine.activate_popup_contract({
		"schema": (
			"eralife.relationship.partner_proposal"
		),
		"version": 1,
		"title": "A Proposal!",
		"text": proposal_text,
		"actor_id": int(
			actor.id
		),
		"target_id": int(
			target.id
		),
		"partner_proposal_jewelry": jewelry,
		"response_options": [
			{
				"id": "accept",
				"label": "Say Yes",
				"resolution_payload": {
					"action_id": (
						"accept_partner_proposal"
					),
					"target_id": int(
						target.id
					),
					"jewelry_key": str(
						jewelry.get(
							"item_key",
							""
						)
					)
				}
			},
			{
				"id": "decline",
				"label": "Say No",
				"resolution_payload": {
					"action_id": (
						"decline_partner_proposal"
					),
					"target_id": int(
						target.id
					)
				}
			}
		],
		"resolution_route": {
			"engine_property": (
				"relationship_activities_engine"
			),
			"method": (
				"resolve_partner_proposal_response"
			),
			"pass_actor_payload": true
		},
		"ui_is_renderer_only": true
	})


func resolve_partner_proposal_response(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"popup_title": "Proposal",
			"popup_text": "That proposal is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)
	var target: Person = (
		_relationship_resident_person_by_id(
			target_id
		)
	)

	if target == null:
		return {
			"success": false,
			"popup_title": "Proposal",
			"popup_text": "Your partner is no longer resident.",
			"popup_footer": "Tap anywhere to continue."
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"option_id",
				""
			)
		)
	).strip_edges().to_lower()

	if action_id in [
		"accept",
		"accept_partner_proposal"
	]:
		_engage_relationship_pair(
			actor,
			target
		)

		var jewelry_key: String = str(
			payload.get(
				"jewelry_key",
				""
			)
		).strip_edges()

		if (
			jewelry_key != ""
			and gs.belongings_engine != null
			and gs.belongings_engine.has_method(
				"queue_relationship_item_transfer"
			)
		):
			gs.belongings_engine.queue_relationship_item_transfer(
				int(
					target.id
				),
				int(
					actor.id
				),
				"Luxury",
				jewelry_key,
				"partner_proposal_accepted"
			)

		return {
			"success": true,
			"text": (
				"I accepted %s's proposal."
				% target.first_name
			),
			"popup_title": "Engaged!",
			"popup_text": (
				"You said yes to %s."
				% target.first_name
			),
			"popup_footer": (
				"Plan Marriage is now available."
			)
		}

	_relationship_adjust_pair_bond(
		actor,
		target,
		-9
	)

	return {
		"success": true,
		"text": (
			"I turned down %s's proposal."
			% target.first_name
		),
		"popup_title": "Proposal Declined",
		"popup_text": (
			"You told %s no."
			% target.first_name
		),
		"popup_footer": (
			"Your relationship continues, but the bond dropped."
		)
	}
func _pair_has_relationship_graph_type(
	actor: Person,
	target: Person,
	relationship_type: String
) -> bool:
	if (
		actor == null
		or target == null
		or gs == null
		or gs.relationship_graph_contract_engine == null
		or not gs.relationship_graph_contract_engine.has_method(
			"relationships_for_entity"
		)
	):
		return false

	var clean_type: String = str(
		relationship_type
	).strip_edges().to_lower()

	if clean_type == "":
		return false

	var actor_entity_id: String = (
		"human:%d"
		% int(
			actor.id
		)
	)
	var target_entity_id: String = (
		"human:%d"
		% int(
			target.id
		)
	)

	for raw_edge in (
		gs.relationship_graph_contract_engine
		.relationships_for_entity(
			actor_entity_id
		)
	):
		var edge: Dictionary = (
			raw_edge as Dictionary
			if typeof(
				raw_edge
			) == TYPE_DICTIONARY
			else {}
		)

		if edge.is_empty():
			continue

		if (
			str(
				edge.get(
					"entity_a",
					""
				)
			) != target_entity_id
			and str(
				edge.get(
					"entity_b",
					""
				)
			) != target_entity_id
		):
			continue

		var relationship_types: Dictionary = (
			edge.get(
				"relationship_types",
				{}
			) as Dictionary
			if typeof(
				edge.get(
					"relationship_types",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		)

		if bool(
			relationship_types.get(
				clean_type,
				false
			)
		):
			return true

	return false
func resolve_relationship_action(
	actor: Person,
	target: Person,
	action_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null or target == null:
		return {
			"success": false,
			"text": "I couldn't resolve that relationship action.",
			"popup_title": "Relationship Action",
			"popup_text": "No valid relationship target was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_action: String = str(
		action_id
	).strip_edges()

	if clean_action.begins_with(
		"relationship_contract:"
	):
		clean_action = clean_action.replace(
			"relationship_contract:",
			""
		)

	if clean_action.begins_with(
		"feed_child_item:"
	):
		var item_id_text: String = clean_action.replace(
			"feed_child_item:",
			""
		)

		return _resolve_feed_child_with_item(
			actor,
			target,
			int(
				item_id_text
			),
			context
		)

	match clean_action:
		"propose":
			return _proposal_entry_result(
				actor,
				target
			)

		"plan_marriage":
			return {
				"success": true,
				"popup_title": "Plan Marriage",
				"popup_text": (
					"Open the resident marriage planner?"
				),
				"popup_footer": (
					"Wedding types and honeymoon realms publish before observation."
				),
				"choices": [
					_relationship_lifecycle_choice(
						"Open Planner",
						"open_marriage_planner",
						{
							"action_id": (
								"reveal_marriage_planner"
							),
							"target_id": int(
								target.id
							)
						},
						false
					)
				]
			}

		"commit_marriage_plan":
			return _commit_relationship_marriage_plan(
				actor,
				target,
				context
			)

		"divorce":
			return _divorce_entry_result(
				actor,
				target
			)

		"baby_whine_breastfed":
			return _resolve_baby_whine_breastfed(
				actor,
				target,
				context
			)

		"baby_whine_held":
			return _resolve_baby_whine_held(
				actor,
				target,
				context
			)

		"baby_cry_diaper_change":
			return _resolve_baby_cry_diaper_change(
				actor,
				target,
				context
			)

		"child_ask_to_be_fed":
			return _resolve_child_ask_to_be_fed(
				actor,
				target,
				context
			)

		"child_ask_to_play":
			return _resolve_child_ask_to_play(
				actor,
				target,
				context
			)

		"teen_ask_to_hang_out":
			return _resolve_teen_ask_to_hang_out(
				actor,
				target,
				context
			)

		"caregiver_breastfeed_child":
			return _resolve_caregiver_breastfeed_child(
				actor,
				target,
				context
			)

		"ask_fwb":
			return _resolve_ask_fwb(
				actor,
				target,
				context
			)

		"make_love":
			return make_love(
				target
			)

		"try_for_baby":
			return try_for_baby(
				target
			)

		"caregiver_hold_child":
			return _resolve_caregiver_hold_child(
				actor,
				target,
				context
			)

		"caregiver_change_diaper":
			return _resolve_caregiver_change_diaper(
				actor,
				target,
				context
			)

		"caregiver_play_peekaboo", \
"caregiver_play_toys", \
"caregiver_tell_silly_story":
			return _resolve_caregiver_play_with_child(
				actor,
				target,
				clean_action,
				context
			)

		"caregiver_check_in_teen":
			return _resolve_caregiver_check_in_teen(
				actor,
				target,
				context
			)

		"caregiver_share_meal_teen":
			return _resolve_caregiver_share_meal_teen(
				actor,
				target,
				context
			)

		"open_food_hub":
			return _open_food_hub_result()

		_:
			return {
				"success": false,
				"text": "I didn't know how to do that relationship action.",
				"popup_title": "Relationship Action",
				"popup_text": (
					"That relationship activity is not registered in the "
					+ "relationship activity contract."
				),
				"popup_footer": "Tap anywhere to continue."
			}
func get_resident_marriage_planner_row(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or target == null
		or str(
			actor.marital_status
		).strip_edges().to_lower()
		!= "engaged"
	):
		return {}

	var projection: Dictionary = (
		_resident_relationship_romance_projection(
			actor,
			target
		)
	)

	return {
		"row_kind": (
			"relationship_marriage_planner"
		),
		"title": "PLAN MARRIAGE",
		"target_id": int(
			target.id
		),
		"partner_name": (
			"%s %s"
			% [
				target.first_name,
				target.last_name
			]
		).strip_edges(),
		"wedding_types": (
			_relationship_array(
				projection.get(
					"wedding_types",
					[]
				)
			)
		),
		"honeymoon_realms": (
			_relationship_array(
				projection.get(
					"honeymoon_realms",
					[]
				)
			)
		),
		"projection_complete": bool(
			projection.get(
				"projection_complete",
				false
			)
		),
		"projection_pending": not bool(
			projection.get(
				"projection_complete",
				false
			)
		),
		"request_prenup_available": true,
		"commit_action": {
			"action_id": (
				"relationship_contract:commit_marriage_plan"
			),
			"target_id": int(
				target.id
			)
		},
		"progressive_observability": true,
		"observation_required": false,
		"ui_is_renderer_only": true
	}
func _resolve_ask_fwb(
	actor: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or target == null
	):
		return {
			"success": false,
			"text": "That FWB request could not be resolved.",
			"popup_title": "Friends With Benefits",
			"popup_text": "No valid relationship target was available.",
			"popup_footer": "Tap anywhere to continue."
		}

	if (
		int(
			actor.age
		) < 18
		or int(
			target.age
		) < 18
	):
		return {
			"success": false,
			"text": "That relationship option is unavailable.",
			"popup_title": "Friends With Benefits",
			"popup_text": (
				"Friends-with-benefits relationships are adult-only."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	if not (
		int(
			target.id
		) in actor.friends
	):
		return {
			"success": false,
			"text": "We weren't friends.",
			"popup_title": "Friends With Benefits",
			"popup_text": (
				"You need an existing friendship before asking "
				+ "for a friends-with-benefits relationship."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	if (
		actor.partner != null
		and int(
			actor.partner.id
		) == int(
			target.id
		)
	):
		return {
			"success": false,
			"text": "We were already together.",
			"popup_title": "Friends With Benefits",
			"popup_text": (
				"That person is already your romantic partner."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	if _pair_has_relationship_graph_type(
		actor,
		target,
		"friends_with_benefits"
	):
		return {
			"success": true,
			"text": "We were already friends with benefits.",
			"popup_title": "Friends With Benefits",
			"popup_text": (
				"You already have a friends-with-benefits "
				+ "relationship with this person."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var chance: int = _reaction_chance(
		target,
		58
	)
	var accepted: bool = (
		randi() % 100 < chance
	)
	var target_reference: String = (
		_target_reference(
			target
		)
	)

	if not accepted:
		_decrease_affection(
			actor,
			target,
			3
		)

		var rejection_text: String = (
			"I asked %s if we could be friends with benefits, "
			+ "but they weren't interested."
		) % target_reference

		if (
			gs != null
			and gs.narrative_engine != null
		):
			gs.narrative_engine.log_event(
				actor,
				{
					"type": "text",
					"text": rejection_text
				}
			)

		return {
			"success": false,
			"text": rejection_text,
			"popup_title": "Friends With Benefits",
			"popup_text": (
				"%s wasn't interested."
				% target_reference
			),
			"popup_footer": "Tap anywhere to continue.",
		}

	_increase_affection(
		actor,
		target,
		8
	)

	var graph_report: Dictionary = {}

	if (
		gs != null
		and gs.human_relationship_contract_engine != null
		and gs.human_relationship_contract_engine.has_method(
			"ensure_pair_edge"
		)
	):
		graph_report = (
			gs.human_relationship_contract_engine
			.ensure_pair_edge(
				actor,
				target,
				{
					"relationship_type": (
						"friends_with_benefits"
					),
					"relationship_tags": [
						"human",
						"social",
						"friend",
						"romance",
						"fwb",
						"friends_with_benefits"
					],
					"subject_role": "FWB",
					"object_role": "FWB",
					"bond_delta": 8,
					"source": (
						"relationship_activities_engine."
						+ "ask_fwb"
					),
					"context": (
						context.duplicate(false)
					)
				}
			)
		)

	var text: String = (
		"I asked %s if we could be friends with benefits, "
		+ "and they agreed."
	) % target_reference

	if (
		gs != null
		and gs.narrative_engine != null
	):
		gs.narrative_engine.log_event(
			actor,
			{
				"type": "text",
				"text": text
			}
		)

	return {
		"success": true,
		"text": text,
		"popup_title": "Friends With Benefits?",
		"popup_text": (
			"You and %s are now friends with benefits. OOO La La!"
			% target_reference
		),
		"popup_footer": "Tap anywhere to continue your life.",
		"relationship_type": "FWB",
		"relationship_graph_report": graph_report,
		"ui_is_renderer_only": false
	}


func _reaction_chance(npc: Person, base: int) -> int:

	var mod = base

	if "Petulant" in npc.traits:
		mod -= 15

	if "Crazy" in npc.traits:
		mod -= 25

	if "Optimist" in npc.traits:
		mod += 10

	if "Jealous" in npc.traits:
		mod -= 5

	return clamp(mod, 5, 95)





func compliment(target: Person) -> Dictionary:
	if gs.player == null or target == null:
		return {
			"text": "I couldn't compliment anyone.",
			"popup_title": "Compliment",
			"popup_text": "There is no one to compliment right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	var ref:= _target_reference(target)
	var chance:= _reaction_chance(target, 72)
	var success:= randi() % 100 < chance

	if success:
		_increase_affection(gs.player, target, 6)
		return _log_player(
			"I complimented %s. They smiled." % ref,
			"You complimented %s. They smiled." % ref,
			{
				"success": true,
				"popup_title": "Compliment",
				"popup_footer": "Tap anywhere to continue."
			}
		)

	_decrease_affection(gs.player, target, 2)
	return _log_player(
		"I complimented %s, but they brushed it off." % ref,
		"You complimented %s, but they brushed it off." % ref,
		{
			"success": true,
			"popup_title": "Compliment",
			"popup_footer": "Tap anywhere to continue."
		}
	)





func converse(target: Person) -> Dictionary:
	var ref:= _target_reference(target)
	var outcomes_good = [
		"We laughed about something stupid.",
		"We had a surprisingly deep talk.",
		"We bonded over shared memories."
	]
	var outcomes_bad = [
		"Our conversation got tense.",
		"%s argued with me for no reason." % ref,
		"We misunderstood each other completely."
	]
	var chance = _reaction_chance(target, 60)
	var success = randi() % 100 < chance
	if success:
		var pick = outcomes_good [randi() % outcomes_good.size()]
		_increase_affection(gs.player, target, 8)
		return _log_player("I talked with %s. %s" % [
			ref,
			pick
		])
	else:
		var pick = outcomes_bad [randi() % outcomes_bad.size()]
		_decrease_affection(gs.player, target, 6)
		return _log_player("I tried talking with %s. %s" % [
			ref,
			pick
		])





func discuss_birth_control(target: Person) -> Dictionary:
	if gs.player == null or target == null:
		return { "text": "\n❌\n No one is there to have that discussion with."}
	if not (gs.player.gender == "Male" and target.gender == "Female"):
		return { "text": "\n❌\n That discussion wouldn't make sense here."}
	var active_partner: Person = gs.get_valid_partner(gs.player, true, true)
	if active_partner == null or active_partner.id != target.id:
		return { "text": "\n❌\n You can only discuss birth control with someone you're romantically involved with."}
	var ref:= _target_reference(target)
	var chance = _reaction_chance(target, 65)
	var success = randi() % 100 < chance
	if success:
		_increase_affection(gs.player, target, 4)
		return _log_player("I discussed birth control with %s. We agreed respectfully." % ref)
	else:
		_decrease_affection(gs.player, target, 4)
		return _log_player("%s was uncomfortable discussing birth control." % ref)




func gift(target: Person, item: Dictionary) -> Dictionary:

	var item_name = str(item.get("name", "a gift"))
	var item_value = int(item.get("value", 0))
	if gs.player.bank_balance < item_value:
		return { "text": "\n❌\n I couldn't afford that gift."}
	gs.player.bank_balance -= item_value
	var ref:= _target_reference(target)
	var chance = _reaction_chance(target, 75)
	var success = randi() % 100 < chance
	if success:
		@warning_ignore("integer_division")
		_increase_affection(gs.player, target, int(item_value / 10))
		var event_txt = "I gifted %s %s. They appreciated it." % [target.first_name, item_name]
		var player_txt = "I gifted %s %s. They appreciated it." % [ref, item_name]
		_emit_social_event(ActionEventTypes.PLAYER_GIFTED_NPC, target, event_txt, {
			"item_name": item_name,
			"item_value": item_value,
			"positive": true
		})
		return _log_player(player_txt)
	else:
		_decrease_affection(gs.player, target, 5)
		var event_txt = "I gave %s %s, but %s didn't care for it." % [
			target.first_name, item_name, target.first_name
		]
		var player_txt = "I gave %s %s, but %s didn't care for it." % [
			ref, item_name, ref
		]
		_emit_social_event(ActionEventTypes.PLAYER_GIFTED_NPC, target, event_txt, {
			"item_name": item_name,
			"item_value": item_value,
			"positive": false
		})
		return _log_player(player_txt)
func insult(target: Person) -> Dictionary:
	var ref:= _target_reference(target)
	var lines = [
		"I insulted %s.",
		"I humiliated %s in front of others.",
		"I said something cruel to %s."
	]
	var txt = lines [randi() % lines.size()] % ref
	_decrease_affection(gs.player, target, 12)
	_emit_social_event(ActionEventTypes.NPC_INSULTED, target, txt, { "severity": 1})
	return _log_player(txt)
func betray(target: Person) -> Dictionary:
	var ref:= _target_reference(target)
	var txt = "I betrayed %s's trust." % ref
	_decrease_affection(gs.player, target, 20)
	gs.social_graph_engine.modify_affection(gs.player.id, target.id, -20)
	_emit_social_event(ActionEventTypes.NPC_BETRAYED, target, txt, { "severity": 2})
	return _log_player(txt)
func heroic_rescue(target: Person) -> Dictionary:
	var chance = 55
	if "Athletic" in gs.player.traits:
		chance += 10
	if "Kind" in gs.player.traits:
		chance += 10
	if gs.player.health < 40:
		chance -= 15

	var ref:= _target_reference(target)
	var success = randi() % 100 < chance
	var txt:= ""

	if success:
		_increase_affection(gs.player, target, 18)
		txt = "I heroically rescued %s from danger." % ref
		_emit_social_event(ActionEventTypes.HEROIC_RESCUE, target, txt, { "success": true})
		return _log_player(txt)

	gs.player.health -= randf() * 10.0
	txt = "I tried to rescue %s, but things went badly." % ref
	_emit_social_event(ActionEventTypes.HEROIC_RESCUE, target, txt, { "success": false})
	return _log_player(txt)



func give_money(target: Person, amount: int) -> Dictionary:
	if gs.player == null or target == null:
		return { "success": false, "text": "\n❌\n Nobody is there to receive the money."}
	var send_amount: int = clamp(int(amount), 0, int(gs.player.bank_balance))
	if send_amount <= 0:
		return { "success": false, "text": "\n❌\n I didn't send any money."}
	if int(gs.player.bank_balance) < send_amount:
		return { "success": false, "text": " I couldn't afford that."}
	gs.player.bank_balance -= send_amount
	target.bank_balance = int(target.bank_balance) + send_amount
	var affection_gain: int = clamp(int(floor(float(send_amount) / 250.0)), 2, 20)
	_increase_affection(gs.player, target, affection_gain)
	var ref:= _target_reference(target)
	var event_txt:= "I sent %s to %s. They appreciated the help." % [
		gs.economy_engine.format_money(send_amount),
		target.first_name
	]
	_emit_social_event(ActionEventTypes.PLAYER_GIFTED_NPC, target, event_txt, {
		"item_name": "Cash",
		"item_value": send_amount,
		"positive": true,
		"gift_type": "money"
	})
	return _log_player("I gave %d coins to %s." % [amount, ref])





func movies(target: Person) -> Dictionary:
	if gs.era.name in ["Ancient Era", "Medieval Era"]:
		return { "text": "\n🎭\n People in this era go to plays instead of movies."}

	var ref:= _target_reference(target)
	var chance = _reaction_chance(target, 65)
	var success = randi() % 100 < chance

	if success:
		_increase_affection(gs.player, target, 7)
		return _log_player("I took %s to the movies. We had a fun time." % ref)
	else:
		_decrease_affection(gs.player, target, 5)
		return _log_player("%s declined going to the movies with me." % ref)




func _modern_future_hookup_special_rejection_eligible(
	target: Person
) -> bool:
	if (
		gs == null
		or gs.player == null
		or gs.era == null
		or target == null
	):
		return false

	if str(
		gs.era.name
	).strip_edges() not in [
		"Modern Era",
		"Future Era"
	]:
		return false

	return (
		str(
			gs.player.gender
		) == "Male"
		and str(
			target.gender
		) == "Female"
	)


func _hookup_rejection_relationship_title_from_reference(
	target_reference: String,
	target: Person
) -> String:
	if target == null:
		return "relationship"

	var clean_reference: String = (
		target_reference.strip_edges()
	)
	var prefix: String = "my "
	var suffix: String = (
		" %s"
		% str(
			target.first_name
		).strip_edges()
	)

	if (
		clean_reference.begins_with(
			prefix
		)
		and clean_reference.ends_with(
			suffix
		)
	):
		var title_length: int = (
			clean_reference.length()
			- prefix.length()
			- suffix.length()
		)

		if title_length > 0:
			var resolved_title: String = (
				clean_reference.substr(
					prefix.length(),
					title_length
				).strip_edges().to_lower()
			)

			if resolved_title != "":
				return resolved_title

	return "relationship"


func _hookup_rejection_response_choice(
	label: String,
	response_id: String,
	target: Person,
	relationship_title: String
) -> Dictionary:
	if target == null:
		return {}

	return {
		"id": response_id,
		"label": label,
		"detail_action": "engine_call",
		"engine_property": "relationship_activities_engine",
		"method": "resolve_hookup_rejection_response",
		"payload": {
			"action_id": response_id,
			"response_id": response_id,
			"target_id": int(
				target.id
			),
			"target_first_name": str(
				target.first_name
			),
			"relationship_title": (
				relationship_title
			),
			"source": (
				"relationship_activities_engine."
				+ "hookup_rejection_followup_choice"
			),
		},
		"commits_reality_truth": true,
		"authority_prevalidated": false
	}
func hookup(target: Person) -> Dictionary:
	if (
		gs == null
		or gs.player == null
		or target == null
	):
		return {
			"success": false,
			"text": "There was nobody to hook up with."
		}

	var chance = _reaction_chance(
		target,
		50
	)

	if (
		target.gender == gs.player.gender
		and gs.era.rights.gay_persecution
	):
		chance -= 20

	var ref:= _target_reference(
		target
	)
	var success = (
		randi() % 100 < chance
	)
	var already_official_partner: bool = (
		gs.player.partner != null
		and int(
			gs.player.partner.id
		) == int(
			target.id
		)
	)
	var was_friend: bool = (
		int(
			target.id
		) in gs.player.friends
	)

	if success:
		_increase_affection(
			gs.player,
			target,
			12
		)

		var txt = (
			"I hooked up with %s."
			% ref
		)

		if (
			not already_official_partner
			and gs.human_relationship_contract_engine != null
			and gs.human_relationship_contract_engine.has_method(
				"ensure_pair_edge"
			)
		):
			var relationship_type: String = (
				"friends_with_benefits"
				if was_friend
				else "fling"
			)
			var relationship_role: String = (
				"FWB"
				if was_friend
				else "Fling"
			)
			var relationship_tags: Array = [
				"human",
				"romance",
				relationship_type
			]

			if was_friend:
				relationship_tags.append(
					"friend"
				)
				relationship_tags.append(
					"fwb"
				)

			gs.human_relationship_contract_engine.ensure_pair_edge(
				gs.player,
				target,
				{
					"relationship_type": relationship_type,
					"relationship_tags": relationship_tags,
					"subject_role": relationship_role,
					"object_role": relationship_role,
					"bond_delta": 12,
					"source": (
						"relationship_activities_engine."
						+ "hookup"
					),
					"ui_is_renderer_only": false
				}
			)

			if was_friend:
				txt += (
					" We became friends with benefits."
				)

		if (
			gs.player.partner != null
			and gs.player.partner != target
		):
			_emit_social_event(
				ActionEventTypes.NPC_CHEATED,
				target,
				txt,
				{
					"partner_id": (
						gs.player.partner.id
					)
				}
			)
			_emit_social_event(
				ActionEventTypes.ROMANCE_BETRAYAL,
				gs.player.partner,
				"%s cheated on %s."
				% [
					gs.player.first_name,
					gs.player.partner.first_name
				],
				{
					"other_person_id": target.id
				}
			)

		gs.world_engine.try_start_player_line_pregnancy(
			gs.player,
			target,
			"hookup"
		)

		return _log_player(
			txt
		)

	_decrease_affection(
		gs.player,
		target,
		10
	)

	var special_rejection: bool = (
		_modern_future_hookup_special_rejection_eligible(
			target
		)
		and (
			randi() % 100
			< MODERN_FUTURE_HOOKUP_SPECIAL_REJECTION_CHANCE
		)
	)

	if special_rejection:
		var relationship_title: String = (
			_hookup_rejection_relationship_title_from_reference(
				ref,
				target
			)
		)

		return {
			"success": true,
			"text": (
				"%s rejected my advances."
				% ref
			),
			"popup_title": "Hookup",
			"popup_text": (
				"Your %s %s said no to hooking up. "
				+ "She said \"Take your time. What’s the rush?\""
			) % [
				relationship_title,
				target.first_name
			],
			"popup_footer": "Choose how to respond.",
			"choices": [
				_hookup_rejection_response_choice(
					"Be patient",
					"hookup_rejection_be_patient",
					target,
					relationship_title
				),
				_hookup_rejection_response_choice(
					"Baby i’m a dog, i’m a mutt",
					"hookup_rejection_dog_mutt",
					target,
					relationship_title
				)
			],
			"special_rejection_chance": (
				MODERN_FUTURE_HOOKUP_SPECIAL_REJECTION_CHANCE
			),
			"target_id": int(
				target.id
			),
			"relationship_title": relationship_title,
			"ui_is_renderer_only": true
		}

	return _log_player(
		"%s rejected my advances."
		% ref
	)
func resolve_hookup_rejection_response(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
		or actor == null
		or int(
			actor.id
		) != int(
			gs.player.id
		)
	):
		return {
			"success": false,
			"popup_title": "Hookup",
			"popup_text": (
				"That hookup response could not be resolved."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var response_id: String = str(
		payload.get(
			"response_id",
			payload.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()

	var target_first_name: String = str(
		payload.get(
			"target_first_name",
			"her"
		)
	).strip_edges()

	if target_first_name == "":
		target_first_name = "her"

	match response_id:
		"hookup_rejection_be_patient":
			return _log_player(
				(
					"I asked %s to hook up with me. "
					+ "She told me to take my time, "
					+ "and I decided to be patient."
				) % target_first_name,
				(
					"You decided to be patient with %s."
					% target_first_name
				),
				{
					"success": true,
					"popup_title": "Hookup",
					"popup_footer": "Tap anywhere to continue.",
					"hookup_rejection_response": (
						"be_patient"
					)
				}
			)

		"hookup_rejection_dog_mutt":
			return _log_player(
				(
					"I asked %s to hook up with me. "
					+ "She said \"Baby take your time, what’s the rush?\" "
					+ "I said \"Baby i’m a dog, ima mutt.\" "
					+ "She laughed."
				) % target_first_name,
				(
					"%s laughed."
					% target_first_name
				),
				{
					"success": true,
					"popup_title": "Hookup",
					"popup_footer": "Tap anywhere to continue.",
					"hookup_rejection_response": (
						"dog_mutt"
					)
				}
			)

		_:
			return {
				"success": false,
				"popup_title": "Hookup",
				"popup_text": (
					"That hookup response is not registered."
				),
				"popup_footer": "Tap anywhere to continue."
			}
func make_love(target: Person) -> Dictionary:
	if (
		gs == null
		or gs.player == null
		or target == null
	):
		return {
			"success": false,
			"text": "I couldn't make love right now.",
			"popup_title": "Make Love",
			"popup_text": "There is no one here to make love with right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not _relationship_pair_is_adult_romantic_partner(
		gs.player,
		target
	):
		return {
			"success": false,
			"text": (
				"I couldn't make love with %s."
				% _target_reference(target)
			),
			"popup_title": "Make Love",
			"popup_text": (
				"Make Love is available only between adult romantic partners."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var ref:= _target_reference(
		target
	)
	var chance:= _reaction_chance(
		target,
		85
	)
	var success:= (
		randi() % 100 < chance
	)

	if success:
		_increase_affection(
			gs.player,
			target,
			15
		)

		var txt:= "I made love with %s." % ref
		var popup_text:= (
			"You made love with %s." % ref
		)
		var out:= _log_player(
			txt,
			popup_text,
			{
				"success": true,
				"popup_title": "Make Love",
				"popup_footer": "Tap anywhere to continue."
			}
		)

		var pregnancy_result: Dictionary = {}

		if (
			gs.world_engine != null
			and gs.world_engine.has_method(
				"try_start_player_line_pregnancy_details"
			)
		):
			pregnancy_result = (
				gs.world_engine
				.try_start_player_line_pregnancy_details(
					gs.player,
					target,
					"make_love"
				)
			)

		if bool(
			pregnancy_result.get(
				"pregnancy_started",
				false
			)
		):
			var carrier_id: int = int(
				pregnancy_result.get(
					"carrier_id",
					-1
				)
			)
			var carrier: Person = (
				gs.get_or_reactivate_npc_by_id(
					carrier_id
				)
			)

			out [
				"followup_result"
			] = _build_player_line_pregnancy_followup_result(
				carrier,
				target,
				pregnancy_result
			)

		return out

	var reason:= _make_love_rejection_reason(
		target
	)

	_decrease_affection(
		gs.player,
		target,
		8
	)
	gs.player.satisfaction = clamp(
		int(
			gs.player.satisfaction
		) - 6,
		0,
		100
	)

	return _log_player(
		(
			"I tried to make love with %s, but they rejected me because %s."
			% [
				ref,
				reason
			]
		),
		(
			"You tried to make love with %s, but they rejected you because %s."
			% [
				ref,
				reason
			]
		),
		{
			"success": false,
			"popup_title": "Make Love",
			"popup_footer": "Tap anywhere to continue."
		}
	)
func try_for_baby(
	target: Person
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
		or target == null
	):
		return {
			"success": false,
			"text": "I couldn't try for a baby right now.",
			"popup_title": "Try for Baby",
			"popup_text": "There is no valid partner here right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not _relationship_pair_is_adult_romantic_partner(
		gs.player,
		target
	):
		return {
			"success": false,
			"text": (
				"I couldn't try for a baby with %s."
				% _target_reference(target)
			),
			"popup_title": "Try for Baby",
			"popup_text": (
				"You can only try for a baby with your adult romantic partner."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	if not _relationship_pair_can_try_for_baby(
		gs.player,
		target
	):
		return {
			"success": false,
			"text": (
				"I couldn't try for a baby with %s right now."
				% _target_reference(target)
			),
			"popup_title": "Try for Baby",
			"popup_text": (
				"A new pregnancy cannot begin between you right now."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var ref: String = _target_reference(
		target
	)

	_increase_affection(
		gs.player,
		target,
		4
	)

	var out: Dictionary = _log_player(
		"I tried for a baby with %s." % ref,
		"You tried for a baby with %s." % ref,
		{
			"success": true,
			"popup_title": "Try for Baby",
			"popup_footer": "Tap anywhere to continue."
		}
	)

	var pregnancy_result: Dictionary = {}

	if (
		gs.world_engine != null
		and gs.world_engine.has_method(
			"try_start_player_line_pregnancy_details"
		)
	):
		pregnancy_result = (
			gs.world_engine
			.try_start_player_line_pregnancy_details(
				gs.player,
				target,
				"try_for_baby"
			)
		)

	if bool(
		pregnancy_result.get(
			"pregnancy_started",
			false
		)
	):
		var carrier_id: int = int(
			pregnancy_result.get(
				"carrier_id",
				-1
			)
		)
		var carrier: Person = (
			gs.get_or_reactivate_npc_by_id(
				carrier_id
			)
		)

		out [
			"followup_result"
		] = _build_player_line_pregnancy_followup_result(
			carrier,
			target,
			pregnancy_result
		)

		return out

	out ["popup_text"] = (
		"You tried for a baby with %s, but no pregnancy started."
		% ref
	)

	return out



func counseling(target: Person) -> Dictionary:
	if gs.player.partner != target:
		return { "text": "\n❌\n Counseling only applies to partners."}

	var ref:= _target_reference(target)
	var chance = _reaction_chance(target, 60)
	var success = randi() % 100 < chance

	if success:
		_increase_affection(gs.player, target, 20)
		return _log_player("I attended counseling with %s. It helped us reconnect." % ref)
	else:
		_decrease_affection(gs.player, target, 10)
		return _log_player("Counseling with %s didn't help at all." % ref)





func crime_on_person(target: Person, crime_name: String) -> Dictionary:
	var ref:= _target_reference(target)
	var fail_text = "\n \n I failed to commit %s on %s." % [crime_name, ref]
	var crimes = {
		"pickpocket": { "success": 60, "harm": 0},
		"attack": { "success": 40, "harm": 25},
		"poison": { "success": 25, "harm": 60},
	}
	if not crimes.has(crime_name):
		return { "text": "\n \n Unknown personal crime."}

	var c = crimes [crime_name]
	var roll = randi() % 100
	var success = roll < c.success

	if success:
		_decrease_affection(gs.player, target, 40)
		target.health -= c.harm

		var target_died: bool = false
		if int(target.health) <= 0 and gs.health_engine != null:
			var death_cause: String = "Killed in an attack by %s." % gs.player.first_name
			if crime_name == "poison":
				death_cause = "Poisoned by %s." % gs.player.first_name
			target_died = bool(gs.health_engine.try_kill(target, death_cause))

		var txt = "I committed %s on %s." % [crime_name, ref]
		if target_died:
			if crime_name == "attack":
				txt = "I attacked %s and killed them." % ref
			elif crime_name == "poison":
				txt = "I poisoned %s to death." % ref

		var public_narration: Dictionary = {}
		if gs.crime_engine != null and gs.crime_engine.has_method("build_targeted_crime_public_narration"):
			public_narration = gs.crime_engine.build_targeted_crime_public_narration(gs.player, target, crime_name, target_died)

		var public_world_text: String = str(public_narration.get("world_text", "")).strip_edges()
		var rumor_text: String = str(public_narration.get("memory_text", "")).strip_edges()
		var pressure_profile: Dictionary = public_narration.get("pressure_profile", {})
		var trace: Array = pressure_profile.get("pressure_trace", []).duplicate(true)
		var target_context_label: String = str(pressure_profile.get("context_label", "")).strip_edges()

		if crime_name == "attack" and not target_died:
			_emit_social_event(
				ActionEventTypes.NPC_FOUGHT,
				target,
				"%s attacked %s." % [gs.player.first_name, target.first_name],
				{
					"crime_name": crime_name,
					"target_pressure_trace": trace,
					"target_context_label": target_context_label
				}
			)
		else:
			_emit_social_event(
				ActionEventTypes.NPC_COMMITTED_CRIME,
				target,
				public_world_text if public_world_text != "" else txt,
				{
					"crime_name": crime_name,
					"target_died": target_died,
					"target_pressure_trace": trace,
					"target_context_label": target_context_label
				}
			)

		if rumor_text == "":
			rumor_text = "Rumors spread that %s targeted %s." % [gs.player.first_name, target.first_name]
			if target_died:
				rumor_text = "Rumors spread that %s killed %s." % [gs.player.first_name, target.first_name]

		_emit_social_event(
			ActionEventTypes.CRIME_RUMOR_SPREAD,
			target,
			rumor_text,
			{
				"crime_name": crime_name,
				"target_died": target_died,
				"target_pressure_trace": trace,
				"target_context_label": target_context_label
			}
		)

		if gs.crime_engine != null and gs.crime_engine.has_method("resolve_targeted_crime_outcome"):
			return gs.crime_engine.resolve_targeted_crime_outcome(target, crime_name, true, txt, target_died)
		return _log_player(txt)
	else:
		if gs.crime_engine != null and gs.crime_engine.has_method("resolve_targeted_crime_outcome"):
			return gs.crime_engine.resolve_targeted_crime_outcome(target, crime_name, false, fail_text, false)
		return _log_player(fail_text)





func era_activity(target: Person) -> Dictionary:
	var ref:= _target_reference(target)

	match gs.era.name:
		"Ancient Era":
			return _log_player("I helped %s gather water from the well." % ref)
		"Medieval Era":
			return _log_player("I walked %s to the village market." % ref)
		"Industrial Era":
			return _log_player("I shared tea with %s during a foggy evening." % ref)
		"Modern Era":
			return movies(target)
		"Future Era":
			return _log_player("I invited %s to a holo-theater simulation." % ref)

	return { "text": "Nothing to do in this era."}





func help_bending(target: Person, element: String) -> Dictionary:

	if gs.player.bending_type == "none":
		return { "text": "❌ You cannot teach bending."}

	return gs.bending_engine.teach_bending(gs.player, target, element)

func _target_reference(target: Person) -> String:
	if gs == null:
		if target == null:
			return "them"
		if str(target.last_name).strip_edges() != "":
			return "%s %s" % [target.first_name, target.last_name]
		return target.first_name
	return gs.get_target_reference_for_observer(gs.player, target)

func _relationship_label_for_target(target: Person) -> String:
	if target == null or gs.player == null:
		return "Stranger"
	var p: Person = gs.player
	var my_facts: Dictionary = gs.get_npc_facts_by_id(int(p.id))
	var target_facts: Dictionary = gs.get_npc_facts_by_id(int(target.id))
	if my_facts == {} or target_facts == {}:
		return "Stranger"
	var my_parent_ids: Array = my_facts.get("parents", [])
	var my_child_ids: Array = my_facts.get("children", [])
	var my_partner_id: int = int(my_facts.get("partner_id", -1))
	var target_parent_ids: Array = target_facts.get("parents", [])
	var sibling_ids: Array = []
	if my_parent_ids.size() > 0:
		sibling_ids = gs.get_npc_field_by_id(int(my_parent_ids [0]), "children", [])
	if my_parent_ids.size() > 0 and int(my_parent_ids [0]) == target.id:
		return "Father"
	if my_parent_ids.size() > 1 and int(my_parent_ids [1]) == target.id:
		return "Mother"
	if int(my_partner_id) == int(target.id):
		return "Husband" if str(target.gender) == "Male" else "Wife"
	if int(target.id) in my_child_ids:
		return "Son" if str(target.gender) == "Male" else "Daughter"
	if my_parent_ids.size() > 0 and target_parent_ids == my_parent_ids and target.id != p.id:
		return "Brother" if str(target.gender) == "Male" else "Sister"


	if my_partner_id > 0:
		var partner_facts: Dictionary = gs.get_npc_facts_by_id(my_partner_id)
		var partner_parents: Array = partner_facts.get("parents", [])
		if target.id in partner_parents:
			return "Father-in-Law" if str(target.gender) == "Male" else "Mother-in-Law"


	if my_partner_id > 0:
		var partner_facts_2: Dictionary = gs.get_npc_facts_by_id(my_partner_id)
		var partner_parent_ids: Array = partner_facts_2.get("parents", [])
		if not partner_parent_ids.is_empty() and target_parent_ids == partner_parent_ids and target.id != my_partner_id:
			return "Brother-in-Law" if str(target.gender) == "Male" else "Sister-in-Law"


	for sibling_id in sibling_ids:
		var sid: int = int(sibling_id)
		if sid <= 0 or sid == int(p.id):
			continue
		var sibling_facts: Dictionary = gs.get_npc_facts_by_id(sid)
		if sibling_facts == {}:
			continue
		if int(sibling_facts.get("partner_id", -1)) == int(target.id):
			return "Brother-in-Law" if str(target.gender) == "Male" else "Sister-in-Law"


	if my_partner_id > 0:
		var partner_facts_3: Dictionary = gs.get_npc_facts_by_id(my_partner_id)
		var partner_parents_2: Array = partner_facts_3.get("parents", [])
		for ppid in partner_parents_2:
			var spouse_parent_facts: Dictionary = gs.get_npc_facts_by_id(int(ppid))
			if spouse_parent_facts == {}:
				continue
			var spouse_gp_ids: Array = spouse_parent_facts.get("parents", [])
			if int(target.id) in spouse_gp_ids:
				return "Grandfather-in-Law" if str(target.gender) == "Male" else "Grandmother-in-Law"
			for spgpid in spouse_gp_ids:
				var spouse_gp_facts: Dictionary = gs.get_npc_facts_by_id(int(spgpid))
				if spouse_gp_facts == {}:
					continue
				var spouse_ggp_ids: Array = spouse_gp_facts.get("parents", [])
				if int(target.id) in spouse_ggp_ids:
					return "Great Grandfather-in-Law" if str(target.gender) == "Male" else "Great Grandmother-in-Law"

	if p.parents.size() > 1:
		var mother: Person = gs.get_or_reactivate_npc_by_id(int(p.parents [1]))
		if mother != null and mother.parents.size() > 0:
			if int(mother.parents [0]) == target.id:
				return "Maternal Grandfather"
		if mother != null and mother.parents.size() > 1:
			if int(mother.parents [1]) == target.id:
				return "Maternal Grandmother"

	if p.parents.size() > 0:
		var father: Person = gs.get_or_reactivate_npc_by_id(int(p.parents [0]))
		if father != null and father.parents.size() > 0:
			if int(father.parents [0]) == target.id:
				return "Paternal Grandfather"
		if father != null and father.parents.size() > 1:
			if int(father.parents [1]) == target.id:
				return "Paternal Grandmother"

	if p.parents.size() > 1:
		var mother2: Person = gs.get_or_reactivate_npc_by_id(int(p.parents [1]))
		if mother2 != null and mother2.parents.size() > 0:
			var maternal_gf: Person = gs.get_or_reactivate_npc_by_id(int(mother2.parents [0]))
			var maternal_gm: Person = gs.get_or_reactivate_npc_by_id(int(mother2.parents [1])) if mother2.parents.size() > 1 else null
			if maternal_gf != null and maternal_gf.parents.size() > 0:
				if int(maternal_gf.parents [0]) == target.id or (maternal_gf.parents.size() > 1 and int(maternal_gf.parents [1]) == target.id):
					return "Maternal Great Grandfather" if str(target.gender) == "Male" else "Maternal Great Grandmother"
			if maternal_gm != null and maternal_gm.parents.size() > 0:
				if int(maternal_gm.parents [0]) == target.id or (maternal_gm.parents.size() > 1 and int(maternal_gm.parents [1]) == target.id):
					return "Maternal Great Grandfather" if str(target.gender) == "Male" else "Maternal Great Grandmother"

	if p.parents.size() > 0:
		var father2: Person = gs.get_or_reactivate_npc_by_id(int(p.parents [0]))
		if father2 != null and father2.parents.size() > 0:
			var paternal_gf: Person = gs.get_or_reactivate_npc_by_id(int(father2.parents [0]))
			var paternal_gm: Person = gs.get_or_reactivate_npc_by_id(int(father2.parents [1])) if father2.parents.size() > 1 else null
			if paternal_gf != null and paternal_gf.parents.size() > 0:
				if int(paternal_gf.parents [0]) == target.id or (paternal_gf.parents.size() > 1 and int(paternal_gf.parents [1]) == target.id):
					return "Paternal Great Grandfather" if str(target.gender) == "Male" else "Paternal Great Grandmother"
			if paternal_gm != null and paternal_gm.parents.size() > 0:
				if int(paternal_gm.parents [0]) == target.id or (paternal_gm.parents.size() > 1 and int(paternal_gm.parents [1]) == target.id):
					return "Paternal Great Grandfather" if str(target.gender) == "Male" else "Paternal Great Grandmother"

	if p.partner != null and p.partner.id == target.id:
		match str(p.marital_status):
			"Married":
				return "Husband" if str(target.gender) == "Male" else "Wife"
			"Engaged":
				return "Fiancé" if str(target.gender) == "Male" else "Fiancée"
			"Dating":
				return "Boyfriend" if str(target.gender) == "Male" else "Girlfriend"
			_:
				return "Partner"

	for cid in p.children:
		if int(cid) == target.id:
			return "Child"

	for fid in p.friends:
		if int(fid) == target.id:
			return "Friend"

	for xid in p.ex_partners:
		if int(xid) == target.id:
			return "Ex"

	if gs.school_engine != null:
		gs.school_engine.sync_person_school_fields(p)
		for c in gs.school_engine.get_classmates(p):
			if c != null and c.id == target.id:
				return "Classmate"
		for t in gs.school_engine.get_teachers_for(p):
			if t != null and t.id == target.id:
				return "Teacher"

	return "Stranger"



func _increase_affection(player, target, amount):
	var resolved_amount: int = int(
		amount
	)

	if (
		resolved_amount > 0
		and gs != null
		and gs.school_engine != null
		and gs.school_engine.has_method(
			"relationship_bond_gain_contract"
		)
	):
		var school_modifier: Dictionary = (
			gs.school_engine.relationship_bond_gain_contract(
				player,
				target,
				resolved_amount
			)
		)

		resolved_amount = int(
			school_modifier.get(
				"adjusted_amount",
				resolved_amount
			)
		)

	target.affection [
		player.id
	] = (
		target.affection.get(
			player.id,
			50
		)
		+ resolved_amount
	)
func apply_school_clique_intro_bond(
	actor: Person,
	target: Person,
	amount: int = 10
) -> Dictionary:
	if (
		actor == null
		or target == null
		or amount <= 0
	):
		return {
			"success": false,
			"reason": "invalid_school_clique_bond_request"
		}

	_adjust_bond(
		actor,
		target,
		amount
	)

	return {
		"success": true,
		"actor_id": int(
			actor.id
		),
		"target_id": int(
			target.id
		),
		"bond_delta": amount,
		"relationship_authority": (
			"RelationshipActivitiesEngine"
		)
	}

func _decrease_affection(player, target, amount):
	target.affection [player.id] = target.affection.get(player.id, 50) - amount

func _log_player(text: String, popup_text: String = "", extra:= {}) -> Dictionary:
	gs.narrative_engine.log_event(gs.player, { "type": "text", "text": text})

	var out: Dictionary = {
		"text": text
	}

	if popup_text.strip_edges() != "":
		out ["popup_text"] = popup_text

	for k in extra.keys():
		out [k] = extra [k]

	return out
func _make_love_rejection_reason(target: Person) -> String:
	if target == null:
		return "they suddenly claimed the moon felt judgmental"

	var reasons: Array = [
		"they said Mercury was in hater mode",
		"they said the ceiling looked spiritually disappointed",
		"they felt an ancestral side-eye in the room",
		"they said my romantic aura had bad Wi-Fi",
		"they claimed the bed had a weird energy signature",
		"they said tonight felt too historically suspicious",
		"they suddenly remembered a fake appointment with destiny",
		"they said the vibes were off by one pixel",
		"they heard an imaginary pastor cough in the distance",
		"they said love should never begin this close to a Tuesday"
	]

	if "Jealous" in target.traits:
		return "they said I looked emotionally downloadable"
	if "Paranoid" in target.traits:
		return "they thought the walls were collecting evidence"
	if "Religious" in target.traits:
		return "they said heaven was watching in 4K"
	if "Loyal" in target.traits and gs.player.partner != target:
		return "they said betrayal was not on the menu"
	if "Impulsive" in target.traits:
		return "they changed their mind at light speed and blamed the atmosphere"

	return str(reasons [randi() % reasons.size()])

func _build_make_love_pregnancy_popup_text(
	carrier: Person,
	target: Person
) -> String:
	if (
		gs == null
		or gs.player == null
		or carrier == null
	):
		return "A pregnancy began."

	var modern_or_future: bool = (
		_modern_or_future_pregnancy_choice_era()
	)

	if int(
		carrier.id
	) == int(
		gs.player.id
	):
		var partner_label: String = str(
			gs.get_relationship_label_between(
				gs.player,
				target
			)
		).strip_edges()

		if (
			partner_label == ""
			or partner_label == "Stranger"
		):
			partner_label = "Partner"

		var player_carrier_text: String = (
			"You are pregnant with your %s %s's baby!"
			% [
				partner_label.to_lower(),
				str(
					target.first_name
				).strip_edges()
			]
		)

		if modern_or_future:
			player_carrier_text += (
				"\n\nWhat will you do?"
			)

		return player_carrier_text

	var carrier_label: String = str(
		gs.get_relationship_label_between(
			gs.player,
			carrier
		)
	).strip_edges()

	if (
		carrier_label == ""
		or carrier_label == "Stranger"
	):
		carrier_label = "Partner"

	var other_carrier_text: String = (
		"Your %s %s is Pregnant with your baby!"
		% [
			carrier_label.to_lower(),
			str(
				carrier.first_name
			).strip_edges()
		]
	)

	if modern_or_future:
		other_carrier_text += (
			"\n\nWhat will you do?"
		)

	return other_carrier_text
func _modern_or_future_pregnancy_choice_era() -> bool:
	if (
		gs == null
		or gs.era == null
	):
		return false

	return str(
		gs.era.name
	).strip_edges() in [
		"Modern Era",
		"Future Era"
	]


func _pregnancy_response_choice(
	label: String,
	response_id: String,
	carrier_id: int,
	other_parent_id: int,
	relationship_target_id: int
) -> Dictionary:
	return {
		"id": response_id,
		"label": label,
		"detail_action": "engine_call",
		"engine_property": "relationship_activities_engine",
		"method": "resolve_pregnancy_response",
		"payload": {
			"action_id": response_id,
			"response_id": response_id,
			"carrier_id": carrier_id,
			"other_parent_id": other_parent_id,
			"relationship_target_id": relationship_target_id,
			"target_id": relationship_target_id,
			"source": (
				"relationship_activities_engine."
				+ "pregnancy_followup_choice"
			)
		},
		"commits_reality_truth": true,
		"authority_prevalidated": false
	}


func _build_player_line_pregnancy_followup_result(
	carrier: Person,
	target: Person,
	pregnancy_result: Dictionary
) -> Dictionary:
	var out: Dictionary = {
		"success": true,
		"text": str(
			pregnancy_result.get(
				"diary_text",
				"A pregnancy began."
			)
		),
		"popup_title": "Pregnancy",
		"popup_text": (
			_build_make_love_pregnancy_popup_text(
				carrier,
				target
			)
		),
		"popup_footer": "Tap anywhere to continue.",
		"choices": []
	}

	if (
		gs == null
		or gs.player == null
		or carrier == null
		or target == null
	):
		return out

	if not _modern_or_future_pregnancy_choice_era():
		return out

	var carrier_id: int = int(
		pregnancy_result.get(
			"carrier_id",
			carrier.id
		)
	)
	var other_parent_id: int = int(
		pregnancy_result.get(
			"other_parent_id",
			-1
		)
	)
	var relationship_target_id: int = int(
		target.id
	)
	var choices: Array = []

	if carrier_id == int(
		gs.player.id
	):
		choices.append(
			_pregnancy_response_choice(
				"Get rid of it",
				"terminate_pregnancy",
				carrier_id,
				other_parent_id,
				relationship_target_id
			)
		)
		choices.append(
			_pregnancy_response_choice(
				"Keep it",
				"keep_pregnancy",
				carrier_id,
				other_parent_id,
				relationship_target_id
			)
		)
	else:
		choices.append(
			_pregnancy_response_choice(
				"Ask her to get rid of it",
				"ask_terminate_pregnancy",
				carrier_id,
				other_parent_id,
				relationship_target_id
			)
		)
		choices.append(
			_pregnancy_response_choice(
				"Go get the milk (ghost her)",
				"ghost_pregnant_partner",
				carrier_id,
				other_parent_id,
				relationship_target_id
			)
		)
		choices.append(
			_pregnancy_response_choice(
				"Stay",
				"stay_with_pregnant_partner",
				carrier_id,
				other_parent_id,
				relationship_target_id
			)
		)

	out [
		"choices"
	] = choices

	return out
func resolve_pregnancy_response(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"popup_title": "Pregnancy",
			"popup_text": "That pregnancy decision could not be resolved.",
			"popup_footer": "Tap anywhere to continue."
		}

	var response_id: String = str(
		payload.get(
			"response_id",
			payload.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()
	var carrier_id: int = int(
		payload.get(
			"carrier_id",
			-1
		)
	)
	var other_parent_id: int = int(
		payload.get(
			"other_parent_id",
			-1
		)
	)

	var carrier: Person = (
		gs.get_or_reactivate_npc_by_id(
			carrier_id
		)
	)
	var other_parent: Person = (
		gs.get_or_reactivate_npc_by_id(
			other_parent_id
		)
	)

	if (
		carrier == null
		or other_parent == null
	):
		return {
			"success": false,
			"popup_title": "Pregnancy",
			"popup_text": "That pregnancy is no longer observable.",
			"popup_footer": "Tap anywhere to continue."
		}

	if (
		int(
			carrier.pregnancy_progress
		) < 0
		or int(
			carrier.unborn_child_other_parent_id
		) != int(
			other_parent.id
		)
	):
		return {
			"success": false,
			"popup_title": "Pregnancy",
			"popup_text": "That pregnancy has already ended or changed.",
			"popup_footer": "Tap anywhere to continue."
		}

	var actor_is_carrier: bool = (
		int(
			actor.id
		) == int(
			carrier.id
		)
	)
	var actor_is_other_parent: bool = (
		int(
			actor.id
		) == int(
			other_parent.id
		)
	)
	var modern_or_future: bool = (
		_modern_or_future_pregnancy_choice_era()
	)

	if (
		not actor_is_carrier
		and not actor_is_other_parent
	):
		return {
			"success": false,
			"popup_title": "Pregnancy",
			"popup_text": (
				"You do not have authority over this pregnancy decision."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	match response_id:
		"keep_pregnancy":
			if not actor_is_carrier:
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": "That choice belongs to the pregnant parent.",
					"popup_footer": "Tap anywhere to continue."
				}

			return _log_player(
				"I decided to continue my pregnancy.",
				"You decided to continue the pregnancy.",
				{
					"success": true,
					"popup_title": "Pregnancy",
					"popup_footer": (
						"The baby will be born on a future age-up."
					)
				}
			)

		"terminate_pregnancy":
			if (
				not modern_or_future
				or not actor_is_carrier
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"That pregnancy choice is not available here."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			if (
				gs.world_engine == null
				or not gs.world_engine.has_method(
					"terminate_player_line_pregnancy"
				)
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"The pregnancy authority is unavailable."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			var termination_report: Dictionary = (
				gs.world_engine
				.terminate_player_line_pregnancy(
					carrier,
					other_parent,
					{
						"source": (
							"relationship_activities_engine."
							+ "player_abortion"
						),
						"requested_by_actor_id": int(
							actor.id
						)
					}
				)
			)

			if not bool(
				termination_report.get(
					"success",
					false
				)
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"The pregnancy could not be terminated."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			return _log_player(
				"I got an abortion and ended my pregnancy.",
				"You got an abortion. The pregnancy ended.",
				{
					"success": true,
					"popup_title": "Pregnancy Ended",
					"popup_footer": "Tap anywhere to continue."
				}
			)

		"ask_terminate_pregnancy":
			if (
				not modern_or_future
				or not actor_is_other_parent
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"That pregnancy choice is not available here."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			var acceptance_chance: int = (
				_reaction_chance(
					carrier,
					52
				)
			)
			var accepted: bool = (
				randi() % 100
				< acceptance_chance
			)

			if not accepted:
				_decrease_affection(
					actor,
					carrier,
					8
				)

				return _log_player(
					(
						"I asked %s to get an abortion, but she refused."
						% carrier.first_name
					),
					(
						"%s refused to end the pregnancy."
						% carrier.first_name
					),
					{
						"success": true,
						"popup_title": "Pregnancy",
						"popup_footer": (
							"The pregnancy is continuing."
						)
					}
				)

			if (
				gs.world_engine == null
				or not gs.world_engine.has_method(
					"terminate_player_line_pregnancy"
				)
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"The pregnancy authority is unavailable."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			var requested_termination_report: Dictionary = (
				gs.world_engine
				.terminate_player_line_pregnancy(
					carrier,
					other_parent,
					{
						"source": (
							"relationship_activities_engine."
							+ "partner_requested_abortion"
						),
						"requested_by_actor_id": int(
							actor.id
						),
						"accepted_by_carrier_id": int(
							carrier.id
						)
					}
				)
			)

			if not bool(
				requested_termination_report.get(
					"success",
					false
				)
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"The pregnancy could not be terminated."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			_decrease_affection(
				actor,
				carrier,
				4
			)

			return _log_player(
				(
					"I asked %s to get an abortion. She agreed."
					% carrier.first_name
				),
				(
					"%s agreed to get an abortion. The pregnancy ended."
					% carrier.first_name
				),
				{
					"success": true,
					"popup_title": "Pregnancy Ended",
					"popup_footer": "Tap anywhere to continue."
				}
			)

		"ghost_pregnant_partner":
			if (
				not modern_or_future
				or not actor_is_other_parent
			):
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": (
						"That pregnancy choice is not available here."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			if actor.partner == carrier:
				gs.end_partnership(
					actor,
					true
				)

			if carrier.partner == actor:
				carrier.partner = null

			if str(
				actor.marital_status
			) in [
				"Dating",
				"Engaged",
				"Married",
				"Partnered"
			]:
				actor.marital_status = "Single"

			if str(
				carrier.marital_status
			) in [
				"Dating",
				"Engaged",
				"Married",
				"Partnered"
			]:
				carrier.marital_status = "Single"

			if int(
				carrier.id
			) not in actor.ex_partners:
				actor.ex_partners.append(
					int(
						carrier.id
					)
				)

			if int(
				actor.id
			) not in carrier.ex_partners:
				carrier.ex_partners.append(
					int(
						actor.id
					)
				)

			_decrease_affection(
				actor,
				carrier,
				30
			)

			return _log_player(
				(
					"I ghosted %s after finding out she was pregnant."
					% carrier.first_name
				),
				(
					"You went to get the milk and ghosted %s. "
					+ "The pregnancy is continuing."
				) % carrier.first_name,
				{
					"success": true,
					"popup_title": "You Left",
					"popup_footer": "Tap anywhere to continue."
				}
			)

		"stay_with_pregnant_partner":
			if not actor_is_other_parent:
				return {
					"success": false,
					"popup_title": "Pregnancy",
					"popup_text": "That choice is no longer available.",
					"popup_footer": "Tap anywhere to continue."
				}

			_increase_affection(
				actor,
				carrier,
				4
			)

			return _log_player(
				(
					"I decided to stay with %s through the pregnancy."
					% carrier.first_name
				),
				(
					"You decided to stay with %s. "
					+ "The pregnancy is continuing."
				) % carrier.first_name,
				{
					"success": true,
					"popup_title": "Pregnancy",
					"popup_footer": (
						"The baby will be born on a future age-up."
					)
				}
			)

		_:
			return {
				"success": false,
				"popup_title": "Pregnancy",
				"popup_text": "That pregnancy choice is not registered.",
				"popup_footer": "Tap anywhere to continue."
			}
func ask_out(target: Person) -> Dictionary:
	if gs.player == null or target == null:
		return {
			"text": "I couldn't ask anyone out.",
			"popup_title": "Ask Out",
			"popup_text": "There is no one to ask out right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	if gs.player.id == target.id:
		return {
			"text": "I tried to ask myself out. That went nowhere.",
			"popup_title": "Ask Out",
			"popup_text": "You cannot ask yourself out.",
			"popup_footer": "Tap anywhere to continue."
		}

	var ref:= _target_reference(target)

	if not gs.player.alive or not target.alive:
		return {
			"text": "I couldn't ask %s out." % ref,
			"popup_title": "Ask Out",
			"popup_text": "That relationship can't happen right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	var player_age: int = int(gs.player.age)
	var target_age: int = int(target.age)
	var player_is_minor: bool = player_age < 18
	var target_is_minor: bool = target_age < 18

	if player_age < 14:
		return {
			"text": "I am too young to start dating.",
			"popup_title": "Ask Out",
			"popup_text": "You are too young to ask someone out.",
			"popup_footer": "Tap anywhere to continue."
		}

	if player_is_minor != target_is_minor:
		return {
			"text": "I asked out %s, but it wasn't appropriate." % ref,
			"popup_title": "Ask Out",
			"popup_text": "That age gap is not allowed.",
			"popup_footer": "Tap anywhere to continue."
		}

	if player_is_minor:
		if target_age < 14 or target_age > 17:
			return {
				"text": "I asked out %s, but it wasn't appropriate." % ref,
				"popup_title": "Ask Out",
				"popup_text": "Minors can only date ages 14 to 17.",
				"popup_footer": "Tap anywhere to continue."
			}
	else:
		if target_age < 18:
			return {
				"text": "I asked out %s, but it wasn't appropriate." % ref,
				"popup_title": "Ask Out",
				"popup_text": "Adults can only date adults.",
				"popup_footer": "Tap anywhere to continue."
			}

	var base_chance: int = 35
	base_chance += int(target.affection.get(gs.player.id, 50) / 2)
	base_chance = _reaction_chance(target, base_chance)
	base_chance = clamp(base_chance, 5, 95)

	var success: bool = randi() % 100 < base_chance
	if success:
		gs.player.partner = target
		target.partner = gs.player
		gs.player.marital_status = "Dating"
		target.marital_status = "Dating"
		_increase_affection(gs.player, target, 15)

		_emit_social_event(
			ActionEventTypes.NPC_PARTNERED,
			target,
			"%s and %s started dating." % [gs.player.first_name, target.first_name],
			{
				"relationship_status": "Dating",
				"other_person_id": target.id
			}
		)

		return _log_player(
			"I asked out %s. They accepted." % ref,
			"You asked out %s. They accepted." % ref,
			{
				"success": true,
				"popup_title": "Ask Out",
				"popup_footer": "Tap anywhere to continue."
			}
		)

	_decrease_affection(gs.player, target, 6)

	if gs.school_engine != null and gs.school_engine.are_classmates(gs.player, target) and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCHOOL_DRAMA, {
			"npc_id": gs.player.id,
			"target_id": target.id,
			"text": "%s asked out %s and got rejected." % [gs.player.first_name, target.first_name],
			"source": "relationship_activities_engine",
			"drama_type": "rejection"
		})

	return _log_player(
		"I asked out %s. They rejected me." % ref,
		"You asked out %s. They rejected you." % ref,
		{
			"success": true,
			"popup_title": "Ask Out",
			"popup_footer": "Tap anywhere to continue."
		}
	)
func _emit_social_event(event_name: String, target: Person, text: String, extra:= {}):
	if gs.event_bus == null:
		return

	var payload = {
		"npc_id": gs.player.id,
		"target_id": target.id if target != null else -1,
		"text": text
	}

	for k in extra.keys():
		payload [k] = extra [k]

	gs.event_bus.emit(event_name, payload)

	if target != null and gs.school_engine != null and gs.school_engine.are_classmates(gs.player, target):
		gs.event_bus.emit(ActionEventTypes.SCHOOL_DRAMA, {
			"npc_id": gs.player.id,
			"target_id": target.id,
			"text": text
		})

	if target != null and gs.player.last_name != "" and target.last_name != "" and gs.player.last_name != target.last_name:
		if event_name in [
			ActionEventTypes.NPC_INSULTED,
			ActionEventTypes.NPC_FOUGHT,
			ActionEventTypes.NPC_BETRAYED,
			ActionEventTypes.ROMANCE_BETRAYAL
		]:
			gs.event_bus.emit(ActionEventTypes.DYNASTY_FEUD_STARTED, {
				"npc_id": gs.player.id,
				"target_id": target.id,
				"text": "Bad blood grew between the %s and %s dynasties." % [
					gs.player.last_name, target.last_name
				]
			})
func _relationship_contract_action(label: String, action_id: String, section: String = "Family Care") -> Dictionary:
	return {
		"schema": "eralife.relationship_profile_action",
		"version": 1,
		"label": label,
		"id": "relationship_contract:%s" % action_id,
		"section": section,
		"source": "relationship_activities_engine",
		"contract_id": str(get_contract().get("contract_id", "eralife.relationship_activities.family_care"))
	}

func _resolve_baby_whine_breastfed(baby: Person, mother: Person, context: Dictionary = {}) -> Dictionary:
	if not _is_newborn(baby) or not _is_mother_of(mother, baby):
		return _family_care_blocked("Breastfeeding", "That breastfeeding action is only available between a newborn and their mother.")
	return _apply_breastfeeding(mother, baby, true, context)

func _resolve_caregiver_breastfeed_child(mother: Person, child: Person, context: Dictionary = {}) -> Dictionary:
	if not _is_newborn(child) or not _is_mother_of(mother, child):
		return _family_care_blocked("Breastfeeding", "Only a newborn's mother can breastfeed them.")
	return _apply_breastfeeding(mother, child, false, context)
func _care_rule_value(rule_id: String, key: String, default_value):
	var contract: Dictionary = get_contract()
	var care_rules_raw: Variant = contract.get("care_rules", {})
	if typeof(care_rules_raw) != TYPE_DICTIONARY:
		return default_value

	var care_rules: Dictionary = care_rules_raw
	var rule_raw: Variant = care_rules.get(rule_id, {})
	if typeof(rule_raw) != TYPE_DICTIONARY:
		return default_value

	var rule: Dictionary = rule_raw
	return rule.get(key, default_value)

func _relationship_current_hunger(person: Person) -> float:
	if person == null:
		return 0.0

	var hunger_value: float = 0.0
	if person.get("hunger") != null:
		hunger_value = float(person.hunger)

	if gs != null and gs.food_engine != null and gs.food_engine.has_method("ensure_actor_food_profile"):
		var profile: Dictionary = gs.food_engine.ensure_actor_food_profile(person)
		hunger_value = float(profile.get("hunger", hunger_value))

	return clamp(hunger_value, 0.0, 100.0)

func _resolve_full_feeding_outcome(provider: Person, child: Person, rule_id: String, food_name: String, context: Dictionary = {}) -> Dictionary:
	if child == null:
		return {
			"active": false,
			"allow_feed": true
		}

	var hunger_now: float = _relationship_current_hunger(child)
	var full_threshold: float = float(_care_rule_value(rule_id, "full_refusal_threshold", 96.0))

	if hunger_now < full_threshold:
		return {
			"active": false,
			"allow_feed": true,
			"hunger": hunger_now
		}

	var overeat_chance: float = clamp(float(_care_rule_value(rule_id, "overeating_chance", 0.18)), 0.0, 1.0)
	var rng:= RandomNumberGenerator.new()
	rng.randomize()
	var will_overeat: bool = rng.randf() < overeat_chance

	return {
		"active": true,
		"allow_feed": will_overeat,
		"refused": not will_overeat,
		"overeating": will_overeat,
		"hunger": hunger_now,
		"threshold": full_threshold,
		"food_name": str(food_name),
		"provider_id": int(provider.id) if provider != null else -1,
		"child_id": int(child.id),
		"source": str(context.get("source", "relationship_feeding_fullness_guard"))
	}

func _full_child_refusal_result(provider: Person, child: Person, food_name: String, child_requested: bool, _rule_id: String, fullness: Dictionary) -> Dictionary:
	var child_name: String = _display_name(child)
	var provider_ref: String = _target_reference(provider)
	var hunger_now: float = float(fullness.get("hunger", _relationship_current_hunger(child)))

	var child_text: String = "I was already full, so I refused more food."
	var provider_text: String = "%s was already full and refused more food." % child_name
	var popup_text: String = "You offered %s, but %s was already full and refused to eat.\n\n%s's Hunger: %d%% - Full" % [
		food_name,
		child_name,
		child_name,
		int(round(hunger_now))
	]
	var actor_text: String = provider_text
	var other_text: String = child_text

	if child_requested:
		actor_text = "I thought I wanted food, but I was already full."
		other_text = "%s seemed full and refused more food." % child_name
		popup_text = "You asked %s for food, but your body was already full.\n\nHunger: %d%% - Full" % [
			provider_ref,
			int(round(hunger_now))
		]

	return _log_family_care_event(
		child if child_requested else provider,
		provider if child_requested else child,
		actor_text,
		other_text,
		"Already Full",
		popup_text,
		{
			"fullness_report": fullness.duplicate(true),
			"hunger_before": hunger_now,
			"hunger_after": hunger_now,
			"hunger_delta": 0.0,
		}
	)

func _apply_overeating_pressure(child: Person, rule_id: String) -> Dictionary:
	if child == null:
		return {}

	var health_delta: float = float(_care_rule_value(rule_id, "overeating_health_delta", -1.0))
	var mental_delta: float = float(_care_rule_value(rule_id, "overeating_mental_delta", -1.0))

	_apply_health_delta(child, health_delta)
	_apply_mental_delta(child, mental_delta)

	return {
		"health_delta": health_delta,
		"mental_delta": mental_delta
	}
func _apply_breastfeeding(mother: Person, baby: Person, baby_requested: bool, context: Dictionary = {}) -> Dictionary:
	if mother == null or baby == null:
		return _family_care_blocked("Breastfeeding", "No valid breastfeeding pair was selected.")

	var baby_name: String = _display_name(baby)
	var mother_ref: String = _target_reference(mother)
	var baby_obj: String = _objective_pronoun(baby)
	var hunger_restore: float = float(_care_rule_value("breastfeed", "hunger_restore", 42.0))
	var hunger_before: float = _relationship_current_hunger(baby)
	var fullness: Dictionary = _resolve_full_feeding_outcome(mother, baby, "breastfeed", "breast milk", context)

	if bool(fullness.get("active", false)) and not bool(fullness.get("allow_feed", true)):
		return _full_child_refusal_result(mother, baby, "breast milk", baby_requested, "breastfeed", fullness)

	var overate: bool = bool(fullness.get("overeating", false))
	var hunger_report: Dictionary = {}

	if gs != null and gs.food_engine != null:
		if gs.food_engine.has_method("apply_sustenance_to_actor"):
			hunger_report = gs.food_engine.apply_sustenance_to_actor(baby, hunger_restore, {
				"source": "relationship_family_care_breastfeeding",
				"provider_id": int(mother.id),
				"child_id": int(baby.id),
				"food_id": "breast_milk",
				"quality": "maternal",
				"overeating": overate
			})
		else:
			hunger_report = gs.food_engine.consume_food(baby, {
				"id": "breast_milk",
				"food_id": "breast_milk",
				"name": "breast milk",
				"quality": "maternal",
				"hunger_restore": hunger_restore,
				"nutrition": 86.0,
				"protein": 6.0,
				"vitamins": 8.0
			}, {
				"source": "relationship_family_care_breastfeeding",
				"provider_id": int(mother.id),
				"child_id": int(baby.id),
				"overeating": overate
			})

	if hunger_report.is_empty() or not bool(hunger_report.get("success", false)):
		var fallback_after: float = clamp(hunger_before + hunger_restore, 0.0, 100.0)
		if baby.get("hunger") != null:
			baby.hunger = fallback_after
		hunger_report = {
			"success": true,
			"actor_id": int(baby.id),
			"hunger_before": hunger_before,
			"hunger_after": fallback_after,
			"hunger_delta": fallback_after - hunger_before,
			"hunger": fallback_after,
			"source": "relationship_family_care_breastfeeding_fallback",
			"overeating": overate
		}

	_apply_health_delta(baby, float(_care_rule_value("breastfeed", "health_delta", 5.0)))
	_adjust_bond(mother, baby, int(_care_rule_value("breastfeed", "bond_delta", 8)))
	_mark_child_diaper_dirty_after_feeding(baby)

	var overeating_report: Dictionary = {}
	if overate:
		overeating_report = _apply_overeating_pressure(baby, "breastfeed")

	var hunger_after: float = float(hunger_report.get("hunger_after", hunger_report.get("hunger", _relationship_current_hunger(baby))))
	var hunger_delta: float = max(0.0, hunger_after - hunger_before)

	var baby_text: String = "I was hungry, so %s breast fed me." % mother_ref
	var mother_text: String = "%s was hungry, so I breast fed %s." % [baby_name, baby_obj]
	var popup_text: String = "You whined softly until %s breast fed you. Warmth settled through your body.\n\nHunger: %d -> %d" % [mother_ref, int(round(hunger_before)), int(round(hunger_after))]
	var actor_text: String = baby_text

	if not baby_requested:
		actor_text = "I breast fed %s because %s was hungry." % [baby_name, _subject_pronoun(baby)]
		popup_text = "You breast fed %s. Their tiny body settled as they finally got sustenance.\n\n%s's Hunger: %d -> %d" % [baby_name, baby_name, int(round(hunger_before)), int(round(hunger_after))]

	if overate:
		popup_text += "\n\n%s was already full, but accepted anyway and became uncomfortable from overeating." % baby_name
		baby_text = "I was already full, but I still drank and felt uncomfortable afterward."
		mother_text = "%s was already full, but I offered more anyway and they overate." % baby_name
		if not baby_requested:
			actor_text = mother_text

	return _log_family_care_event(
		baby if baby_requested else mother,
		mother if baby_requested else baby,
		actor_text,
		mother_text if baby_requested else baby_text,
		"Breastfed",
		popup_text,
		{
			"hunger_report": hunger_report.duplicate(true),
			"fullness_report": fullness.duplicate(true),
			"overeating_report": overeating_report.duplicate(true),
			"hunger_actor_id": int(baby.id),
			"hunger_before": hunger_before,
			"hunger_after": hunger_after,
			"hunger_delta": hunger_delta,
			"overeating": overate,
		}
	)
func _resolve_baby_whine_held(baby: Person, caregiver: Person, context: Dictionary = {}) -> Dictionary:
	if not _is_newborn(baby) or not _can_hold_child(caregiver, baby):
		return _family_care_blocked("Hold", "That person cannot hold this baby right now.")
	return _apply_hold_child(caregiver, baby, true, context)

func _resolve_caregiver_hold_child(caregiver: Person, child: Person, context: Dictionary = {}) -> Dictionary:
	if not _can_hold_child(caregiver, child):
		return _family_care_blocked("Hold", "That person cannot hold this child right now.")
	return _apply_hold_child(caregiver, child, false, context)

func _apply_hold_child(caregiver: Person, child: Person, child_requested: bool, _context: Dictionary = {}) -> Dictionary:
	var child_name: String = _display_name(child)
	var caregiver_ref: String = _target_reference(caregiver)
	var child_relation_for_caregiver: String = _family_care_subject_reference_for_observer(caregiver, child)
	_adjust_bond(caregiver, child, int(get_contract().get("care_rules", {}).get("hold", {}).get("bond_delta", 5)))
	_apply_mental_delta(child, float(get_contract().get("care_rules", {}).get("hold", {}).get("mental_delta", 1.0)))
	var child_text: String = "I whined to be held, and %s picked me up." % caregiver_ref
	var caregiver_text: String = "%s wanted to be held, so I picked %s up." % [child_relation_for_caregiver, _objective_pronoun(child)]
	var popup_text: String = "You whined until %s picked you up. Being held made the world feel less enormous." % caregiver_ref
	var actor_text: String = child_text
	if not child_requested:
		actor_text = "I held %s close for a while." % child_name
		popup_text = "You held %s close. Their body relaxed against you." % child_name
	return _log_family_care_event(
		child if child_requested else caregiver,
		caregiver if child_requested else child,
		actor_text,
		caregiver_text if child_requested else child_text,
		"Held",
		popup_text,
		{ "refresh_profile": true}
	)
func _resolve_baby_cry_diaper_change(baby: Person, caregiver: Person, context: Dictionary = {}) -> Dictionary:
	if not _is_newborn(baby) or not _can_change_diaper(caregiver, baby):
		return _family_care_blocked("Diaper Change", "That person cannot change this baby's diaper right now.")
	return _apply_diaper_change(caregiver, baby, true, context)

func _resolve_caregiver_change_diaper(caregiver: Person, child: Person, context: Dictionary = {}) -> Dictionary:
	if not _can_change_diaper(caregiver, child):
		return _family_care_blocked("Diaper Change", "That person cannot change this child's diaper right now.")
	return _apply_diaper_change(caregiver, child, false, context)

func _apply_diaper_change(caregiver: Person, child: Person, child_requested: bool, _context: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _child_care_state(child)
	if not bool(state.get("diaper_dirty", true)):
		return _family_care_blocked("Diaper Change", "%s's diaper is already clean." % _display_name(child))
	if int(state.get("diaper_changes_this_year", 0)) >= FAMILY_CARE_DIAPER_YEAR_LIMIT:
		return _family_care_blocked("Diaper Change", "This baby's diaper-change limit has already been reached for the year.")
	state ["diaper_dirty"] = false
	state ["diaper_changes_this_year"] = int(state.get("diaper_changes_this_year", 0)) + 1
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	_save_child_care_state(child, state)
	_adjust_bond(caregiver, child, int(get_contract().get("care_rules", {}).get("diaper_change", {}).get("bond_delta", 3)))
	_apply_health_delta(child, float(get_contract().get("care_rules", {}).get("diaper_change", {}).get("health_delta", 1.0)))
	var child_name: String = _display_name(child)
	var caregiver_ref: String = _target_reference(caregiver)
	var child_text: String = "I cried because my diaper was dirty, and %s changed me." % caregiver_ref
	var caregiver_text: String = "%s needed a diaper change, so I changed %s." % [child_name, _objective_pronoun(child)]
	var popup_text: String = "You cried until %s changed your diaper. The discomfort finally eased." % caregiver_ref
	var actor_text: String = child_text
	if not child_requested:
		actor_text = "I changed %s's diaper." % child_name
		popup_text = "You changed %s's diaper. They calmed down after being cleaned up." % child_name
	return _log_family_care_event(
		child if child_requested else caregiver,
		caregiver if child_requested else child,
		actor_text,
		caregiver_text if child_requested else child_text,
		"Diaper Change",
		popup_text,
		{ "refresh_profile": true}
	)

func _resolve_child_ask_to_be_fed(child: Person, provider: Person, context: Dictionary = {}) -> Dictionary:
	if int(child.age) < 2 or int(child.age) > 12 or not _is_family_member(provider, child):
		return _family_care_blocked("Ask to be Fed", "That child cannot ask this person to feed them.")
	var food_pick: Dictionary = _first_owned_food_item(provider)
	if food_pick.is_empty():
		return _open_food_hub_result("I asked %s for food, but they did not have anything ready." % _target_reference(provider))
	return _feed_child_from_food(provider, child, food_pick, true, context)

func _resolve_feed_child_with_item(actor: Person, target: Person, item_id: int, context: Dictionary = {}) -> Dictionary:
	var provider: Person = actor
	var child: Person = target
	if int(actor.age) <= 12 and _is_family_member(target, actor):
		provider = target
		child = actor
	if not _can_feed_child(provider, child):
		return _family_care_blocked("Feed Child", "That person cannot feed this child right now.")
	var food_pick: Dictionary = _owned_food_item_by_id(provider, item_id)
	if food_pick.is_empty():
		return _family_care_blocked("Feed Child", "That food item could not be found.")
	return _feed_child_from_food(provider, child, food_pick, false, context)

func _feed_child_from_food(provider: Person, child: Person, food_pick: Dictionary, child_requested: bool, context: Dictionary = {}) -> Dictionary:
	if provider == null or child == null:
		return _family_care_blocked("Feed Child", "No valid feeding pair was selected.")

	var item: Dictionary = food_pick.get("item", {}).duplicate(true)
	var category: String = str(food_pick.get("category", "Food"))
	var item_id: int = int(item.get("id", -1))
	var food_name: String = str(item.get("name", item.get("display_name", "food"))).strip_edges()
	if food_name == "":
		food_name = "food"

	var hunger_before: float = _relationship_current_hunger(child)
	var fullness: Dictionary = _resolve_full_feeding_outcome(provider, child, "feed_child", food_name, context)

	if bool(fullness.get("active", false)) and not bool(fullness.get("allow_feed", true)):
		return _full_child_refusal_result(provider, child, food_name, child_requested, "feed_child", fullness)

	var overate: bool = bool(fullness.get("overeating", false))
	var consume_report: Dictionary = {}

	if gs != null and gs.food_engine != null:
		consume_report = gs.food_engine.consume_food(child, item, {
			"source": "relationship_family_care_feed_child",
			"provider_id": int(provider.id),
			"child_id": int(child.id),
			"overeating": overate
		})

	if gs != null and gs.belongings_engine != null and item_id > 0:
		gs.belongings_engine.remove_item_by_id(provider, category, item_id)

	_apply_health_delta(child, float(_care_rule_value("feed_child", "health_delta", 2.0)))
	_adjust_bond(provider, child, int(_care_rule_value("feed_child", "bond_delta", 4)))

	var overeating_report: Dictionary = {}
	if overate:
		overeating_report = _apply_overeating_pressure(child, "feed_child")

	var hunger_after: float = float(consume_report.get("hunger_after", consume_report.get("hunger", _relationship_current_hunger(child))))
	var hunger_delta: float = max(0.0, hunger_after - hunger_before)

	var child_name: String = _display_name(child)
	var provider_ref: String = _target_reference(provider)
	var child_text: String = "I asked %s for food, and %s fed me %s." % [provider_ref, provider_ref, food_name]
	var provider_text: String = "%s was hungry, so I fed %s %s." % [child_name, _objective_pronoun(child), food_name]
	var popup_text: String = "You asked %s for food. They fed you %s.\n\nHunger: %d -> %d" % [
		provider_ref,
		food_name,
		int(round(hunger_before)),
		int(round(hunger_after))
	]
	var actor_text: String = child_text

	if not child_requested:
		actor_text = "I fed %s %s." % [child_name, food_name]
		popup_text = "You fed %s %s.\n\n%s's Hunger: %d -> %d" % [
			child_name,
			food_name,
			child_name,
			int(round(hunger_before)),
			int(round(hunger_after))
		]

	if overate:
		popup_text += "\n\n%s was already full, but accepted anyway and became uncomfortable from overeating." % child_name
		child_text = "I was already full, but I still ate %s and felt uncomfortable afterward." % food_name
		provider_text = "%s was already full, but I offered %s anyway and they overate." % [child_name, food_name]
		if not child_requested:
			actor_text = provider_text

	return _log_family_care_event(
		child if child_requested else provider,
		provider if child_requested else child,
		actor_text,
		provider_text if child_requested else child_text,
		"Fed",
		popup_text,
		{
			"hunger_report": consume_report.duplicate(true),
			"fullness_report": fullness.duplicate(true),
			"overeating_report": overeating_report.duplicate(true),
			"hunger_actor_id": int(child.id),
			"hunger_before": hunger_before,
			"hunger_after": hunger_after,
			"hunger_delta": hunger_delta,
			"overeating": overate,
		}
	)

func _resolve_child_ask_to_play(child: Person, family_member: Person, _context: Dictionary = {}) -> Dictionary:
	if int(child.age) < 2 or int(child.age) > 12 or not _is_family_member(family_member, child):
		return _family_care_blocked("Ask to Play", "That child cannot ask this person to play right now.")
	_adjust_bond(family_member, child, int(get_contract().get("care_rules", {}).get("play", {}).get("bond_delta", 6)))
	_apply_mental_delta(child, float(get_contract().get("care_rules", {}).get("play", {}).get("mental_delta", 2.0)))
	var child_text: String = "I asked %s to play with me, and they did." % _target_reference(family_member)
	var family_text: String = "%s asked me to play, so I spent time with %s." % [_display_name(child), _objective_pronoun(child)]
	return _log_family_care_event(
		child,
		family_member,
		child_text,
		family_text,
		"Played Together",
		"You asked %s to play with you, and they made time for you." % _target_reference(family_member),
		{ "refresh_profile": true}
	)

func _resolve_caregiver_play_with_child(caregiver: Person, child: Person, play_action: String, _context: Dictionary = {}) -> Dictionary:
	if int(child.age) < 2 or int(child.age) > 12 or not _is_family_member(caregiver, child):
		return _family_care_blocked("Play", "That person cannot play with this child right now.")
	var play_label: String = "played with"
	match play_action:
		"caregiver_play_peekaboo":
			play_label = "played peekaboo with"
		"caregiver_play_toys":
			play_label = "played with toys beside"
		"caregiver_tell_silly_story":
			play_label = "told a silly story to"
	_adjust_bond(caregiver, child, int(get_contract().get("care_rules", {}).get("play", {}).get("bond_delta", 6)))
	_apply_mental_delta(child, float(get_contract().get("care_rules", {}).get("play", {}).get("mental_delta", 2.0)))
	caregiver.satisfaction = clamp(float(caregiver.satisfaction) + float(get_contract().get("care_rules", {}).get("play", {}).get("satisfaction_delta", 2.0)), 0.0, 100.0)
	var child_name: String = _display_name(child)
	var caregiver_text: String = "I %s %s." % [play_label, child_name]
	var child_text: String = "%s %s me." % [_target_reference(caregiver), play_label]
	return _log_family_care_event(
		caregiver,
		child,
		caregiver_text,
		child_text,
		"Played Together",
		"You %s %s. The bond between you grew warmer." % [play_label, child_name],
		{ "refresh_profile": true}
	)

func _resolve_teen_ask_to_hang_out(teen: Person, family_member: Person, _context: Dictionary = {}) -> Dictionary:
	if int(teen.age) < 13 or int(teen.age) > 17 or not _is_family_member(family_member, teen):
		return _family_care_blocked("Ask to Hang Out", "That teen cannot ask this person to hang out right now.")
	_adjust_bond(family_member, teen, int(get_contract().get("care_rules", {}).get("teen_connection", {}).get("bond_delta", 4)))
	_apply_mental_delta(teen, float(get_contract().get("care_rules", {}).get("teen_connection", {}).get("mental_delta", 2.0)))
	var teen_text: String = "I asked %s to hang out, and they made time for me." % _target_reference(family_member)
	var family_text: String = "%s asked me to hang out, so I made time for %s." % [_display_name(teen), _objective_pronoun(teen)]
	return _log_family_care_event(
		teen,
		family_member,
		teen_text,
		family_text,
		"Family Time",
		"You asked %s to hang out, and they made time for you." % _target_reference(family_member),
		{ "refresh_profile": true}
	)

func _resolve_caregiver_check_in_teen(caregiver: Person, teen: Person, _context: Dictionary = {}) -> Dictionary:
	if int(teen.age) < 13 or int(teen.age) > 17 or not _is_family_member(caregiver, teen):
		return _family_care_blocked("Check In", "That person cannot check in with this teen right now.")
	_adjust_bond(caregiver, teen, int(get_contract().get("care_rules", {}).get("teen_connection", {}).get("bond_delta", 4)))
	_apply_mental_delta(teen, float(get_contract().get("care_rules", {}).get("teen_connection", {}).get("mental_delta", 2.0)))
	var teen_name: String = _display_name(teen)
	return _log_family_care_event(
		caregiver,
		teen,
		"I checked in with %s and listened to what was on their mind." % teen_name,
		"%s checked in with me and listened to what was on my mind." % _target_reference(caregiver),
		"Checked In",
		"You checked in with %s and listened without rushing them." % teen_name,
		{ "refresh_profile": true}
	)

func _resolve_caregiver_share_meal_teen(caregiver: Person, teen: Person, _context: Dictionary = {}) -> Dictionary:
	if int(teen.age) < 13 or int(teen.age) > 17 or not _is_family_member(caregiver, teen):
		return _family_care_blocked("Share Meal", "That person cannot share a meal with this teen right now.")
	_adjust_bond(caregiver, teen, 3)
	var teen_name: String = _display_name(teen)
	return _log_family_care_event(
		caregiver,
		teen,
		"I shared a meal with %s and caught up with them." % teen_name,
		"%s shared a meal with me and caught up with me." % _target_reference(caregiver),
		"Shared a Meal",
		"You shared a meal with %s. It gave both of you a quiet moment together." % teen_name,
		{ "refresh_profile": true}
	)

func _food_picker_actions_for_child(provider: Person, _child: Person) -> Array:
	var actions: Array = []
	var foods: Array = _owned_food_items(provider)
	if foods.is_empty():
		actions.append(_relationship_contract_action("Open Store", "open_food_hub", "Family Care"))
		return actions
	var limit: int = min(FAMILY_CARE_FOOD_PICKER_LIMIT, foods.size())
	for i in range(limit):
		var food_pick: Dictionary = foods [i]
		var item: Dictionary = food_pick.get("item", {})
		var item_id: int = int(item.get("id", -1))
		if item_id <= 0:
			continue
		var food_name: String = str(item.get("name", item.get("display_name", "Food"))).strip_edges()
		if food_name == "":
			food_name = "Food"
		actions.append(_relationship_contract_action("Feed: %s" % food_name, "feed_child_item:%d" % item_id, "Family Care"))
	return actions

func _owned_food_items(owner: Person) -> Array:
	var out: Array = []
	if owner == null or gs == null or gs.belongings_engine == null:
		return out
	var inventory: Dictionary = gs.belongings_engine.get_inventory(owner)
	for raw_category in inventory.keys():
		var category: String = str(raw_category)
		var category_lower: String = category.to_lower()
		var items_raw: Variant = inventory.get(raw_category, [])
		if typeof(items_raw) != TYPE_ARRAY:
			continue
		for raw_item in items_raw:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = (raw_item as Dictionary).duplicate(true)
			var item_kind: String = str(item.get("kind", item.get("type", item.get("category", "")))).to_lower()
			var item_name: String = str(item.get("name", item.get("display_name", ""))).to_lower()
			var looks_like_food: bool = category_lower.find("food") >= 0 or category_lower.find("grocery") >= 0 or item_kind.find("food") >= 0 or item_name.find("meal") >= 0
			if not looks_like_food and not item.has("hunger_restore"):
				continue
			out.append({
				"category": category,
				"item": item
			})
	return out

func _first_owned_food_item(owner: Person) -> Dictionary:
	var foods: Array = _owned_food_items(owner)
	if foods.is_empty():
		return {}
	return foods [0]

func _owned_food_item_by_id(owner: Person, item_id: int) -> Dictionary:
	if item_id <= 0:
		return {}
	for food_pick in _owned_food_items(owner):
		var item: Dictionary = food_pick.get("item", {})
		if int(item.get("id", -1)) == item_id:
			return food_pick
	return {}

func _open_food_hub_result(text: String = "") -> Dictionary:
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		clean_text = "I needed food, so I opened the food hub."
	return {
		"success": true,
		"text": clean_text,
		"popup_title": "Food Needed",
		"popup_text": "There is no suitable food ready. Open the Food hub and buy something first.",
		"popup_footer": "Tap anywhere to continue.",
		"open_surface_id": "food_contract_hub",
		"open_section_id": "stores",
	}

func _family_care_blocked(title: String, reason: String) -> Dictionary:
	return {
		"success": false,
		"text": reason,
		"popup_title": title,
		"popup_text": reason,
		"popup_footer": "Tap anywhere to continue.",
	}

func _log_family_care_event(actor: Person, other: Person, actor_text: String, other_text: String, popup_title: String, popup_text: String, extra: Dictionary = {}) -> Dictionary:
	var clean_actor_text: String = actor_text.strip_edges()
	var clean_other_text: String = other_text.strip_edges()
	if clean_actor_text == "":
		clean_actor_text = "I spent time with family."
	if clean_other_text == "":
		clean_other_text = "I spent time with family."

	clean_other_text = _family_care_other_diary_text(actor, other, clean_other_text)

	if gs != null and gs.narrative_engine != null:
		if actor != null:
			gs.narrative_engine.log_event(actor, {
				"type": "text",
				"text": clean_actor_text,
				"life_diary_text": clean_actor_text,
				"force_first_person_memory": true,
				"category": "family_care",
				"source": "relationship_activities_engine",
				"suppress_world_feed": true,
				"diary_scope": "actor"
			})
		if other != null:
			gs.narrative_engine.log_event(other, {
				"type": "text",
				"text": clean_other_text,
				"life_diary_text": clean_other_text,
				"force_first_person_memory": true,
				"category": "family_care",
				"source": "relationship_activities_engine",
				"other_person_id": int(actor.id) if actor != null else -1,
				"suppress_world_feed": true,
				"diary_scope": "other_person"
			})
	elif gs != null and gs.memory_engine != null:
		if actor != null:
			gs.memory_engine.remember(int(actor.id), clean_actor_text)
		if other != null:
			gs.memory_engine.remember(int(other.id), clean_other_text)

	var out: Dictionary = {
		"success": true,
		"text": clean_actor_text,
		"journal_text": clean_actor_text,
		"player_text": clean_actor_text,
		"other_person_diary_text": clean_other_text,
		"other_person_id": int(other.id) if other != null else -1,
		"suppress_world_feed": true,
		"popup_title": popup_title,
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue.",
		"relationship_activity_contract": get_contract()
	}
	for key in extra.keys():
		out [key] = extra [key]
	return out
func _family_care_other_diary_text(subject: Person, observer: Person, text: String) -> String:
	var clean_text: String = str(text).strip_edges()
	if subject == null or observer == null or clean_text == "":
		return clean_text

	var subject_name: String = _display_name(subject)
	if subject_name == "":
		return clean_text

	var subject_reference: String = _family_care_subject_reference_for_observer(observer, subject)

	if clean_text.begins_with(subject_name):
		return "%s%s" % [
			subject_reference,
			clean_text.substr(subject_name.length(), clean_text.length() - subject_name.length())
		]

	return clean_text


func _family_care_subject_reference_for_observer(observer: Person, subject: Person) -> String:
	if observer == null or subject == null:
		return "My family member"

	var subject_name: String = _display_name(subject)
	var relation_label: String = _family_care_relation_label(observer, subject)
	if relation_label == "":
		return subject_name

	return "My %s %s" % [relation_label, subject_name]


func _family_care_relation_label(observer: Person, subject: Person) -> String:
	if observer == null or subject == null:
		return ""

	if int(subject.id) in observer.children:
		if str(subject.gender) == "Male":
			return "son"
		if str(subject.gender) == "Female":
			return "daughter"
		return "child"

	if int(observer.id) in subject.children:
		if str(subject.gender) == "Male":
			return "father"
		if str(subject.gender) == "Female":
			return "mother"
		return "parent"

	if _family_care_people_share_any_parent(observer, subject):
		if str(subject.gender) == "Male":
			return "brother"
		if str(subject.gender) == "Female":
			return "sister"
		return "sibling"

	return "family member"


func _family_care_people_share_any_parent(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	for raw_parent_id in a.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0:
			continue
		if parent_id in b.parents:
			return true

	return false

func _child_care_state(child: Person) -> Dictionary:
	if child == null or gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var root_raw: Variant = gs.scenario_state.get("relationship_family_care_state", {})
	if typeof(root_raw) != TYPE_DICTIONARY:
		gs.scenario_state ["relationship_family_care_state"] = {}
		root_raw = gs.scenario_state.get("relationship_family_care_state", {})
	var root: Dictionary = root_raw as Dictionary
	var key: String = str(int(child.id))
	var state_raw: Variant = root.get(key, {})
	var state: Dictionary = state_raw.duplicate(true) if typeof(state_raw) == TYPE_DICTIONARY else {}
	var current_year: int = int(gs.year)
	if state.is_empty():
		state = {
			"child_id": int(child.id),
			"diaper_dirty": int(child.age) <= 1,
			"diaper_changes_this_year": 0,
			"diaper_year": current_year,
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if int(state.get("diaper_year", current_year)) != current_year:
		state ["diaper_year"] = current_year
		state ["diaper_changes_this_year"] = 0
		state ["diaper_dirty"] = int(child.age) <= 1
		state ["updated_at_ms"] = int(Time.get_ticks_msec())
	root [key] = state.duplicate(true)
	gs.scenario_state ["relationship_family_care_state"] = root
	return state.duplicate(true)

func _save_child_care_state(child: Person, state: Dictionary) -> void:
	if child == null or gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var root_raw: Variant = gs.scenario_state.get("relationship_family_care_state", {})
	var root: Dictionary = root_raw.duplicate(true) if typeof(root_raw) == TYPE_DICTIONARY else {}
	root [str(int(child.id))] = state.duplicate(true)
	gs.scenario_state ["relationship_family_care_state"] = root

func _mark_child_diaper_dirty_after_feeding(child: Person) -> void:
	if child == null or int(child.age) > 1:
		return
	var state: Dictionary = _child_care_state(child)
	state ["diaper_dirty"] = true
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	_save_child_care_state(child, state)

func _is_newborn(person: Person) -> bool:
	return person != null and int(person.age) <= 1

func _is_mother_of(mother: Person, child: Person) -> bool:
	if mother == null or child == null:
		return false
	if str(mother.gender) != "Female":
		return false
	if child.parents.size() > 1 and int(child.parents [1]) == int(mother.id):
		return true
	return int(mother.id) in child.parents

func _is_parent_of(parent: Person, child: Person) -> bool:
	if parent == null or child == null:
		return false
	return int(parent.id) in child.parents

func _is_sibling_of(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false
	if int(a.id) == int(b.id):
		return false
	if a.parents.is_empty() or b.parents.is_empty():
		return false
	for parent_id in a.parents:
		if int(parent_id) in b.parents:
			return true
	return false

func _is_aunt_or_uncle_of(adult: Person, child: Person) -> bool:
	if adult == null or child == null or gs == null:
		return false
	for parent_id_value in child.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(parent_id_value))
		if parent != null and _is_sibling_of(adult, parent):
			return true
	return false

func _is_family_member(
	a: Person,
	b: Person
) -> bool:
	if a == null or b == null:
		return false

	if int(a.id) == int(b.id):
		return false




	if (
		gs != null
		and gs.relationship_engine != null
		and gs.relationship_engine.has_method(
			"people_are_family"
		)
	):
		return bool(
			gs.relationship_engine.people_are_family(
				a,
				b
			)
		)


	if (
		_is_parent_of(a, b)
		or _is_parent_of(b, a)
	):
		return true

	if _is_sibling_of(a, b):
		return true

	if (
		_is_aunt_or_uncle_of(a, b)
		or _is_aunt_or_uncle_of(b, a)
	):
		return true

	if (
		int(a.id) in b.children
		or int(b.id) in a.children
	):
		return true

	return false

func _can_hold_child(caregiver: Person, child: Person) -> bool:
	if caregiver == null or child == null:
		return false
	if int(caregiver.age) <= 1:
		return false
	if int(child.age) > 3:
		return false
	return _is_family_member(caregiver, child)

func _can_change_diaper(
	caregiver: Person,
	child: Person
) -> bool:
	if caregiver == null or child == null:
		return false

	if int(child.age) > 2:
		return false

	if int(caregiver.age) <= 1:
		return false



	return _is_family_member(
		caregiver,
		child
	)

func _can_feed_child(provider: Person, child: Person) -> bool:
	if provider == null or child == null:
		return false
	if int(child.age) > 12:
		return false
	return _is_family_member(provider, child)

func _adjust_bond(a: Person, b: Person, amount: int) -> void:
	if a == null or b == null:
		return
	if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("adjust_relationship"):
		gs.relationship_engine.adjust_relationship(a, b, amount)
		return
	if typeof(a.affection) != TYPE_DICTIONARY:
		a.affection = {}
	if typeof(b.affection) != TYPE_DICTIONARY:
		b.affection = {}
	a.affection [b.id] = clamp(int(a.affection.get(b.id, 50)) + amount, 0, 100)
	b.affection [a.id] = clamp(int(b.affection.get(a.id, 50)) + amount, 0, 100)

func _apply_health_delta(person: Person, amount: float) -> void:
	if person == null:
		return
	person.health = clamp(float(person.health) + amount, 0.0, 200.0)

func _apply_mental_delta(person: Person, amount: float) -> void:
	if person == null:
		return
	person.mental_health = clamp(float(person.mental_health) + amount, 0.0, 100.0)

func _display_name(person: Person) -> String:
	if person == null:
		return "Someone"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Someone"
	return full_name

func _subject_pronoun(person: Person) -> String:
	if person == null:
		return "they"
	if str(person.gender) == "Male":
		return "he"
	if str(person.gender) == "Female":
		return "she"
	return "they"

func _objective_pronoun(person: Person) -> String:
	if person == null:
		return "them"
	if str(person.gender) == "Male":
		return "him"
	if str(person.gender) == "Female":
		return "her"
	return "them"

func _deep_merge_dictionary(base: Dictionary, override: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in override.keys():
		var incoming: Variant = override.get(key)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _deep_merge_dictionary(out.get(key, {}), incoming)
		else:
			out [key] = incoming
	return out