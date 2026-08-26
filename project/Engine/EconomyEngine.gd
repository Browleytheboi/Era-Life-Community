extends Resource
class_name EconomyEngine

var gs

func _init(_gs):
	gs = _gs

	_bind_silk_road_observation_inputs()
	_arm_silk_road_observation_monitor()
func _economy_dictionary_ref(
	value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return value as Dictionary

	return {}


func _economy_array_ref(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return value as Array

	return []


func _bind_silk_road_observation_inputs() -> void:
	if (
		gs == null
		or gs.event_bus == null
		or not gs.event_bus.has_method(
			"subscribe"
		)
	):
		return

	var event_bus_instance_id: int = int(
		gs.event_bus.get_instance_id()
	)

	if int(
		get_meta(
			"silk_road_bound_event_bus_instance_id",
			-1
		)
	) == event_bus_instance_id:
		return

	gs.event_bus.subscribe(
		"belongings.event",
		self,
		"_on_silk_road_belongings_event"
	)

	gs.event_bus.subscribe(
		ActionEventTypes.TRADE_EXECUTED,
		self,
		"_on_silk_road_market_truth_changed"
	)

	gs.event_bus.subscribe(
		ActionEventTypes.REALM_WAR,
		self,
		"_on_silk_road_market_truth_changed"
	)

	set_meta(
		"silk_road_bound_event_bus_instance_id",
		event_bus_instance_id
	)


func _on_silk_road_belongings_event(
	packet: Dictionary
) -> void:
	if (
		gs == null
		or gs.player == null
	):
		return

	if int(
		packet.get(
			"owner_id",
			-1
		)
	) != int(
		gs.player.id
	):
		return

	queue_resident_silk_road_projection(
		gs.player,
		{
			"source": "economy_engine.belongings_event",
			"reason": "controlled_actor_inventory_changed",
			"background_only": true,
			"blocks_ui": false,
			"requires_input_idle": false
		}
	)


func _on_silk_road_market_truth_changed(
	_payload: Dictionary
) -> void:
	if (
		gs == null
		or gs.player == null
	):
		return

	queue_resident_silk_road_projection(
		gs.player,
		{
			"source": "economy_engine.market_truth_changed",
			"reason": "macro_market_revision_changed",
			"background_only": true,
			"blocks_ui": false,
			"requires_input_idle": false
		}
	)


func _arm_silk_road_observation_monitor() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()

	if not (
		main_loop is SceneTree
	):
		return

	var tree: SceneTree = (
		main_loop as SceneTree
	)
	var callback:= Callable(
		self,
		"_drive_silk_road_observation_monitor"
	)

	if tree.process_frame.is_connected(
		callback
	):
		return

	tree.process_frame.connect(
		callback
	)

	set_meta(
		"silk_road_observation_monitor_active",
		true
	)
	set_meta(
		"silk_road_observation_monitor_requires_input_idle",
		false
	)
	set_meta(
		"silk_road_observation_monitor_uses_call_deferred",
		false
	)


func _drive_silk_road_observation_monitor() -> void:
	if posmod(
		int(
			Engine.get_process_frames()
		),
		4
	) != 2:
		return

	_bind_silk_road_observation_inputs()

	if (
		gs == null
		or gs.player == null
	):
		return

	var actor: Person = gs.player
	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return

	var observation_frontier: String = (
		"%d:%d:%d:%d"
		% [
			actor_id,
			int(
				gs.year
			),
			int(
				round(
					float(
						actor.bank_balance
					)
				)
			),
			int(
				round(
					float(
						market_multiplier
					) * 10000.0
				)
			)
		]
	)

	if observation_frontier == str(
		get_meta(
			"silk_road_last_observation_frontier",
			""
		)
	):
		return

	set_meta(
		"silk_road_last_observation_frontier",
		observation_frontier
	)

	queue_resident_silk_road_projection(
		actor,
		{
			"source": (
				"economy_engine."
				+ "continuous_silk_road_observation"
			),
			"reason": "controlled_market_frontier_changed",
			"background_only": true,
			"blocks_ui": false,
			"requires_input_idle": false
		}
	)


func _silk_road_catalog_size() -> int:
	return 15


func _silk_road_catalog_entry_at(
	index: int
) -> Dictionary:
	match index:
		0:
			return {
				"name": "Silk",
				"base_value": 200,
				"rarity": "Fine",
				"stable": true,
				"availability_percent": 100,
				"route": "Eastern Loom Route",
				"flavor": (
					"Fine bolts sought by courts, diplomats, "
					+ "merchant houses, and wealthy families."
				)
			}

		1:
			return {
				"name": "Spices",
				"base_value": 150,
				"rarity": "Fine",
				"stable": true,
				"availability_percent": 100,
				"route": "Southern Spice Route",
				"flavor": (
					"Medicinal and culinary cargo whose value "
					+ "changes sharply with route pressure."
				)
			}

		2:
			return {
				"name": "Tea",
				"base_value": 120,
				"rarity": "Staple",
				"stable": true,
				"availability_percent": 100,
				"route": "Tea Horse Corridor",
				"flavor": (
					"Reliable caravan stock with broad household "
					+ "and elite demand."
				)
			}

		3:
			return {
				"name": "Gold",
				"base_value": 500,
				"rarity": "Luxury",
				"stable": true,
				"availability_percent": 100,
				"route": "Imperial Treasury Route",
				"flavor": (
					"Portable wealth prized across political "
					+ "borders and currency systems."
				)
			}

		4:
			return {
				"name": "Salt",
				"base_value": 80,
				"rarity": "Staple",
				"stable": false,
				"availability_percent": 82,
				"route": "Salt Caravan",
				"flavor": (
					"Essential cargo whose scarcity can become "
					+ "politically explosive."
				)
			}

		5:
			return {
				"name": "Jade",
				"base_value": 260,
				"rarity": "Luxury",
				"stable": false,
				"availability_percent": 64,
				"route": "Jade Gate",
				"flavor": (
					"Ceremonial prestige stone favored for "
					+ "court gifts and elite display."
				)
			}

		6:
			return {
				"name": "Incense",
				"base_value": 110,
				"rarity": "Fine",
				"stable": false,
				"availability_percent": 72,
				"route": "Temple Route",
				"flavor": (
					"Ritual and luxury stock crossing temples, "
					+ "courts, and merchant quarters."
				)
			}

		7:
			return {
				"name": "Porcelain",
				"base_value": 180,
				"rarity": "Luxury",
				"stable": false,
				"availability_percent": 58,
				"route": "Kiln Caravan",
				"flavor": (
					"Fragile high-status ware with exceptional "
					+ "profit when a caravan arrives intact."
				)
			}

		8:
			return {
				"name": "Ivory",
				"base_value": 300,
				"rarity": "Rare",
				"stable": false,
				"availability_percent": 42,
				"route": "Southern Luxury Route",
				"flavor": (
					"Scarce prestige material whose availability "
					+ "changes drastically between years."
				)
			}

		9:
			return {
				"name": "Jewels",
				"base_value": 450,
				"rarity": "Rare",
				"stable": false,
				"availability_percent": 52,
				"route": "Royal Gem Route",
				"flavor": (
					"Compact luxury wealth moved between courts, "
					+ "bankers, and marriage alliances."
				)
			}

		10:
			return {
				"name": "Paper",
				"base_value": 95,
				"rarity": "Fine",
				"stable": false,
				"availability_percent": 70,
				"route": "Scholar's Route",
				"flavor": (
					"A high-demand knowledge good for courts, "
					+ "merchants, schools, and scribes."
				)
			}

		11:
			return {
				"name": "Saffron",
				"base_value": 240,
				"rarity": "Rare",
				"stable": false,
				"availability_percent": 38,
				"route": "Persian Caravan",
				"flavor": (
					"Extremely concentrated luxury cargo whose "
					+ "small shipments command large prices."
				)
			}

		12:
			return {
				"name": "Horses",
				"base_value": 340,
				"rarity": "Rare",
				"stable": false,
				"availability_percent": 46,
				"route": "Steppe Horse Route",
				"flavor": (
					"Prestige and military stock whose price "
					+ "surges around conflict and expansion."
				)
			}

		13:
			return {
				"name": "Glassware",
				"base_value": 165,
				"rarity": "Luxury",
				"stable": false,
				"availability_percent": 55,
				"route": "Western Artisan Route",
				"flavor": (
					"Rare artisan cargo that appears only when "
					+ "the right western caravan reaches market."
				)
			}

		14:
			return {
				"name": "Dyes",
				"base_value": 145,
				"rarity": "Fine",
				"stable": false,
				"availability_percent": 62,
				"route": "Textile Merchant Route",
				"flavor": (
					"Color concentrates prized by textile "
					+ "guilds, courts, and wealthy households."
				)
			}

	return {}


func _silk_road_listing_is_available(
	definition: Dictionary,
	actor: Person
) -> bool:
	if bool(
		definition.get(
			"stable",
			false
		)
	):
		return true

	var threshold: int = clampi(
		int(
			definition.get(
				"availability_percent",
				55
			)
		),
		0,
		100
	)

	var availability_roll: int = posmod(
		hash(
			"silk_road_availability|%s|%d|%d"
			% [
				str(
					definition.get(
						"name",
						""
					)
				),
				int(
					gs.year
				),
				int(
					actor.realm_id
				)
			]
		),
		100
	)

	return availability_roll < threshold


func _silk_road_price_for_definition(
	definition: Dictionary,
	actor: Person
) -> int:
	var good_name: String = str(
		definition.get(
			"name",
			"Unknown"
		)
	)
	var market_price: int = 0

	if (
		gs.global_market_engine != null
		and gs.global_market_engine.has_method(
			"get_price_for_good"
		)
	):
		market_price = int(
			gs.global_market_engine.get_price_for_good(
				good_name,
				int(
					actor.realm_id
				)
			)
		)


	if market_price > 0:
		return market_price




	var base_value: int = maxi(
		1,
		int(
			definition.get(
				"base_value",
				100
			)
		)
	)
	var yearly_step: int = (
		posmod(
			hash(
				"silk_road_price|%s|%d|%d"
				% [
					good_name,
					int(
						gs.year
					),
					int(
						actor.realm_id
					)
				]
			),
			61
		) - 30
	)
	var yearly_factor: float = (
		1.0
		+ (
			float(
				yearly_step
			) / 100.0
		)
	)

	return maxi(
		1,
		int(
			round(
				float(
					base_value
				)
				* yearly_factor
				* clampf(
					float(
						market_multiplier
					),
					0.7,
					1.5
				)
			)
		)
	)


func _silk_road_cached_contract(
	actor_id: int
) -> Dictionary:
	var cache_raw: Variant = get_meta(
		"silk_road_resident_contract_by_actor",
		{}
	)

	if typeof(
		cache_raw
	) != TYPE_DICTIONARY:
		return {}

	var cache: Dictionary = (
		cache_raw as Dictionary
	)
	var contract_raw: Variant = cache.get(
		str(
			actor_id
		),
		{}
	)

	if typeof(
		contract_raw
	) != TYPE_DICTIONARY:
		return {}

	return contract_raw as Dictionary


func _silk_road_previous_listing_price(
	actor_id: int,
	listing_id: String
) -> int:
	var previous_contract: Dictionary = (
		_silk_road_cached_contract(
			actor_id
		)
	)
	var previous_rows: Array = (
		_economy_array_ref(
			previous_contract.get(
				"listings",
				[]
			)
		)
	)


	for raw_row in previous_rows:
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		)

		if str(
			row.get(
				"listing_id",
				""
			)
		) != listing_id:
			continue

		return int(
			row.get(
				"price",
				0
			)
		)

	return 0


func _silk_road_barter_category_count() -> int:
	return 12


func _silk_road_barter_category_at(
	index: int
) -> String:
	match index:
		0:
			return "Trade Goods"
		1:
			return "Artifacts"
		2:
			return "Heirlooms"
		3:
			return "Weapons"
		4:
			return "Jewelry"
		5:
			return "Luxury"
		6:
			return "Clothing"
		7:
			return "Books"
		8:
			return "Collectibles"
		9:
			return "Tools"
		10:
			return "Food"
		11:
			return "Misc"

	return ""


func queue_resident_silk_road_projection(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": "missing_actor_or_game_state"
		}

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	var generation: int = int(
		get_meta(
			"silk_road_projection_generation",
			0
		)
	) + 1

	set_meta(
		"silk_road_projection_generation",
		generation
	)

	var jobs_raw: Variant = get_meta(
		"silk_road_resident_projection_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(
			jobs_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var order_raw: Variant = get_meta(
		"silk_road_resident_projection_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)
	var actor_key: String = str(
		actor_id
	)

	jobs [
		actor_key
	] = {
		"actor_id": actor_id,
		"generation": generation,
		"phase": "header",
		"catalog_cursor": 0,
		"listings": [],
		"barter_category_cursor": 0,
		"barter_item_cursor": 0,
		"barter_checks": 0,
		"barter_rows": [],
		"context": context.duplicate(false),
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if not order.has(
		actor_key
	):
		order.append(
			actor_key
		)

	set_meta(
		"silk_road_resident_projection_jobs",
		jobs
	)
	set_meta(
		"silk_road_resident_projection_order",
		order
	)

	_arm_resident_silk_road_projection_service()

	return {
		"success": true,
		"queued": true,
		"actor_id": actor_id,
		"generation": generation,
		"blocks_ui": false,
		"requires_input_idle": false,
		"uses_call_deferred": false,
		"ready_gate_member": false
	}


func _arm_resident_silk_road_projection_service() -> void:
	var order_raw: Variant = get_meta(
		"silk_road_resident_projection_order",
		[]
	)
	var order: Array = (
		order_raw as Array
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"silk_road_resident_projection_service_active",
			false
		)
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (
		main_loop is SceneTree
	):
		return

	var tree: SceneTree = (
		main_loop as SceneTree
	)
	var callback:= Callable(
		self,
		"_drive_resident_silk_road_projection_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		set_meta(
			"silk_road_resident_projection_service_active",
			true
		)
		return

	tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT
	)

	set_meta(
		"silk_road_resident_projection_service_active",
		true
	)


func _drive_resident_silk_road_projection_process_frame() -> void:
	set_meta(
		"silk_road_resident_projection_service_active",
		false
	)

	_service_resident_silk_road_projection_quantum()
	_arm_resident_silk_road_projection_service()


func _publish_silk_road_observation(
	actor_id: int,
	packet: Dictionary
) -> bool:
	if (
		gs == null
		or actor_id <= 0
		or packet.is_empty()
		or gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"publish_resident_continuous_observation"
		)
	):
		return false

	gs.reality_projection_contract_engine.publish_resident_continuous_observation(
		"silk_road:%d" % actor_id,
		packet
	)

	return true


func _service_resident_silk_road_projection_quantum() -> void:
	var order_raw: Variant = get_meta(
		"silk_road_resident_projection_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(
			order_raw
		) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		return

	var jobs_raw: Variant = get_meta(
		"silk_road_resident_projection_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(
			jobs_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var actor_key: String = str(
		order.pop_front()
	)
	var job_raw: Variant = jobs.get(
		actor_key,
		{}
	)
	var job: Dictionary = (
		(job_raw as Dictionary).duplicate(false)
		if typeof(
			job_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		jobs.erase(
			actor_key
		)
		set_meta(
			"silk_road_resident_projection_order",
			order
		)
		set_meta(
			"silk_road_resident_projection_jobs",
			jobs
		)
		return

	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var actor: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		actor = gs.player
	elif gs.has_method(
		"get_npc_by_id"
	):
		actor = gs.get_npc_by_id(
			actor_id,
			false
		)

	if actor == null:
		jobs.erase(
			actor_key
		)
		set_meta(
			"silk_road_resident_projection_order",
			order
		)
		set_meta(
			"silk_road_resident_projection_jobs",
			jobs
		)
		return

	if (
		gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"publish_resident_continuous_observation"
		)
	):
		jobs [
			actor_key
		] = job
		order.append(
			actor_key
		)
		set_meta(
			"silk_road_resident_projection_order",
			order
		)
		set_meta(
			"silk_road_resident_projection_jobs",
			jobs
		)
		return

	var generation: int = int(
		job.get(
			"generation",
			0
		)
	)
	var phase: String = str(
		job.get(
			"phase",
			"header"
		)
	).strip_edges().to_lower()
	var complete: bool = false

	match phase:
		"header":
			var market_open: bool = bool(
				silk_road_available()
			)

			_publish_silk_road_observation(
				actor_id,
				{
					"schema": "eralife.silk_road_market_observation",
					"version": 1,
					"observation_channel": "silk_road",
					"phase": "header",
					"actor_id": actor_id,
					"generation": generation,
					"market_year": int(
						gs.year
					),
					"realm_id": int(
						actor.realm_id
					),
					"market_open": market_open,
					"funds": float(
						actor.bank_balance
					),
					"funds_display": format_money(
						int(
							actor.bank_balance
						),
						actor
					),
					"catalog_size": _silk_road_catalog_size(),
					"stable_goods": 4,
					"projection_complete": false,
					"background_only": true,
					"blocks_ui": false,
					"requires_input_idle": false,
					"ui_is_renderer_only": true
				}
			)

			job [
				"phase"
			] = (
				"listings"
				if market_open
				else "complete"
			)

		"listings":
			var cursor: int = int(
				job.get(
					"catalog_cursor",
					0
				)
			)

			if cursor >= _silk_road_catalog_size():
				job [
					"phase"
				] = "barter"
			else:
				var definition: Dictionary = (
					_silk_road_catalog_entry_at(
						cursor
					)
				)

				job [
					"catalog_cursor"
				] = cursor + 1

				if (
					not definition.is_empty()
					and _silk_road_listing_is_available(
						definition,
						actor
					)
				):
					var good_name: String = str(
						definition.get(
							"name",
							"Unknown"
						)
					)
					var listing_id: String = (
						"silk_road::%s"
						% good_name.to_lower().replace(
							" ",
							"_"
						)
					)
					var price: int = (
						_silk_road_price_for_definition(
							definition,
							actor
						)
					)
					var previous_price: int = (
						_silk_road_previous_listing_price(
							actor_id,
							listing_id
						)
					)
					var price_delta: int = (
						price - previous_price
						if previous_price > 0
						else 0
					)
					var trend: String = "new"

					if previous_price > 0:
						if price_delta > 0:
							trend = "up"
						elif price_delta < 0:
							trend = "down"
						else:
							trend = "stable"

					var listing: Dictionary = {
						"listing_id": listing_id,
						"actor_id": actor_id,
						"market_generation": generation,
						"market_year": int(
							gs.year
						),
						"realm_id": int(
							actor.realm_id
						),
						"name": good_name,
						"base_value": int(
							definition.get(
								"base_value",
								price
							)
						),
						"price": price,
						"price_display": format_money(
							price,
							actor
						),
						"previous_price": previous_price,
						"price_delta": price_delta,
						"trend": trend,
						"flip_floor": int(
							round(
								float(
									price
								) * 1.15
							)
						),
						"flip_ceiling": int(
							round(
								float(
									price
								) * 2.4
							)
						),
						"rarity": str(
							definition.get(
								"rarity",
								"Fine"
							)
						),
						"stable_listing": bool(
							definition.get(
								"stable",
								false
							)
						),
						"route": str(
							definition.get(
								"route",
								"Caravan Route"
							)
						),
						"flavor": str(
							definition.get(
								"flavor",
								""
							)
						),
						"available": true,
						"projection_read_only": true,
						"ui_is_renderer_only": true
					}

					var listings_raw: Variant = job.get(
						"listings",
						[]
					)
					var listings: Array = (
						(listings_raw as Array).duplicate(false)
						if typeof(
							listings_raw
						) == TYPE_ARRAY
						else []
					)

					listings.append(
						listing
					)
					job [
						"listings"
					] = listings

					_publish_silk_road_observation(
						actor_id,
						{
							"schema": "eralife.silk_road_market_observation",
							"version": 1,
							"observation_channel": "silk_road",
							"phase": "listing",
							"actor_id": actor_id,
							"generation": generation,
							"listing": listing,
							"projection_complete": false,
							"background_only": true,
							"blocks_ui": false,
							"requires_input_idle": false,
							"ui_is_renderer_only": true
						}
					)

				if cursor + 1 >= _silk_road_catalog_size():
					job [
						"phase"
					] = "barter"

		"barter":
			var barter_rows_raw: Variant = job.get(
				"barter_rows",
				[]
			)
			var barter_rows: Array = (
				(barter_rows_raw as Array).duplicate(false)
				if typeof(
					barter_rows_raw
				) == TYPE_ARRAY
				else []
			)
			var barter_checks: int = int(
				job.get(
					"barter_checks",
					0
				)
			)
			var category_cursor: int = int(
				job.get(
					"barter_category_cursor",
					0
				)
			)
			var item_cursor: int = int(
				job.get(
					"barter_item_cursor",
					0
				)
			)

			if (
				barter_rows.size() >= 12
				or barter_checks >= 36
				or category_cursor >= _silk_road_barter_category_count()
			):
				job [
					"phase"
				] = "complete"
			else:
				var category: String = (
					_silk_road_barter_category_at(
						category_cursor
					)
				)
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

				var items_raw: Variant = inventory.get(
					category,
					[]
				)
				var items: Array = (
					items_raw as Array
					if typeof(
						items_raw
					) == TYPE_ARRAY
					else []
				)

				if item_cursor >= items.size():
					job [
						"barter_category_cursor"
					] = category_cursor + 1
					job [
						"barter_item_cursor"
					] = 0
				else:
					var raw_item: Variant = items [
						item_cursor
					]
					var item_id: int = -1

					if typeof(
						raw_item
					) == TYPE_DICTIONARY:
						item_id = int(
							(raw_item as Dictionary).get(
								"id",
								-1
							)
						)

					job [
						"barter_item_cursor"
					] = item_cursor + 1
					job [
						"barter_checks"
					] = barter_checks + 1

					if (
						item_id > 0
						and gs.belongings_engine != null
						and gs.belongings_engine.has_method(
							"barter_item_contract_at_index"
						)
					):
						var quote: Dictionary = (
							gs.belongings_engine
							.barter_item_contract_at_index(
								actor,
								category,
								item_cursor,
								item_id
							)
						)

						if not quote.is_empty():
							var item: Dictionary = (
								_economy_dictionary_ref(
									quote.get(
										"item",
										{}
									)
								)
							)
							var barter_value: int = int(
								quote.get(
									"barter_value",
									0
								)
							)
							var barter_row: Dictionary = {
								"barter_id": (
									"silk_barter:%d:%s:%d:%d"
									% [
										actor_id,
										category,
										item_id,
										generation
									]
								),
								"actor_id": actor_id,
								"market_generation": generation,
								"market_year": int(
									gs.year
								),
								"category": category,
								"item_index": item_cursor,
								"item_id": item_id,
								"name": str(
									item.get(
										"display_name",
										item.get(
											"name",
											"Belonging"
										)
									)
								),
								"barter_value": barter_value,
								"barter_value_display": format_money(
									barter_value,
									actor
								),
								"exact_value_exchange": true,
								"projection_read_only": true,
								"ui_is_renderer_only": true
							}

							barter_rows.append(
								barter_row
							)
							job [
								"barter_rows"
							] = barter_rows

							_publish_silk_road_observation(
								actor_id,
								{
									"schema": "eralife.silk_road_market_observation",
									"version": 1,
									"observation_channel": "silk_road",
									"phase": "barter",
									"actor_id": actor_id,
									"generation": generation,
									"barter": barter_row,
									"projection_complete": false,
									"background_only": true,
									"blocks_ui": false,
									"requires_input_idle": false,
									"ui_is_renderer_only": true
								}
							)

		"complete":
			var listings: Array = _economy_array_ref(
				job.get(
					"listings",
					[]
				)
			).duplicate(false)
			var barter_rows: Array = _economy_array_ref(
				job.get(
					"barter_rows",
					[]
				)
			).duplicate(false)
			var contract: Dictionary = {
				"success": true,
				"schema": "eralife.silk_road_market_contract",
				"version": 1,
				"actor_id": actor_id,
				"market_generation": generation,
				"market_year": int(
					gs.year
				),
				"realm_id": int(
					actor.realm_id
				),
				"market_open": bool(
					silk_road_available()
				),
				"funds": float(
					actor.bank_balance
				),
				"funds_display": format_money(
					int(
						actor.bank_balance
					),
					actor
				),
				"listings": listings,
				"barter_rows": barter_rows,
				"listing_count": listings.size(),
				"barter_count": barter_rows.size(),
				"truth_state": "hot",
				"projection_composed": true,
				"hydrated": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"ui_is_renderer_only": true
			}

			var cache_raw: Variant = get_meta(
				"silk_road_resident_contract_by_actor",
				{}
			)
			var cache: Dictionary = (
				(cache_raw as Dictionary).duplicate(false)
				if typeof(
					cache_raw
				) == TYPE_DICTIONARY
				else {}
			)

			cache [
				actor_key
			] = contract
			set_meta(
				"silk_road_resident_contract_by_actor",
				cache
			)

			_publish_silk_road_observation(
				actor_id,
				{
					"schema": "eralife.silk_road_market_observation",
					"version": 1,
					"observation_channel": "silk_road",
					"phase": "complete",
					"actor_id": actor_id,
					"generation": generation,
					"market_contract": contract,
					"listing_count": listings.size(),
					"barter_count": barter_rows.size(),
					"projection_complete": true,
					"background_only": true,
					"blocks_ui": false,
					"requires_input_idle": false,
					"ui_is_renderer_only": true
				}
			)

			complete = true

		_:
			complete = true

	if complete:
		jobs.erase(
			actor_key
		)
	else:
		jobs [
			actor_key
		] = job
		order.append(
			actor_key
		)

	set_meta(
		"silk_road_resident_projection_jobs",
		jobs
	)
	set_meta(
		"silk_road_resident_projection_order",
		order
	)
	set_meta(
		"silk_road_resident_projection_last_actor_id",
		actor_id
	)
	set_meta(
		"silk_road_resident_projection_last_phase",
		phase
	)
	set_meta(
		"silk_road_resident_projection_one_quantum_per_frame",
		true
	)
	set_meta(
		"silk_road_resident_projection_requires_input_idle",
		false
	)
	set_meta(
		"silk_road_resident_projection_uses_call_deferred",
		false
	)


func _silk_road_listing_for_intent(
	person: Person,
	payload: Dictionary
) -> Dictionary:
	if person == null:
		return {}

	var listing_id: String = str(
		payload.get(
			"listing_id",
			""
		)
	).strip_edges()
	var requested_generation: int = int(
		payload.get(
			"market_generation",
			-1
		)
	)

	if (
		listing_id == ""
		or requested_generation < 0
	):
		return {}

	var contract: Dictionary = (
		_silk_road_cached_contract(
			int(
				person.id
			)
		)
	)

	if (
		contract.is_empty()
		or int(
			contract.get(
				"market_generation",
				-1
			)
		) != requested_generation
		or int(
			contract.get(
				"market_year",
				-999999
			)
		) != int(
			gs.year
		)
		or int(
			contract.get(
				"realm_id",
				-1
			)
		) != int(
			person.realm_id
		)
	):
		return {}

	var listings: Array = _economy_array_ref(
		contract.get(
			"listings",
			[]
		)
	)


	for raw_listing in listings:
		if typeof(
			raw_listing
		) != TYPE_DICTIONARY:
			continue

		var listing: Dictionary = (
			raw_listing as Dictionary
		)

		if (
			str(
				listing.get(
					"listing_id",
					""
				)
			) == listing_id
			and bool(
				listing.get(
					"available",
					false
				)
			)
		):
			return listing

	return {}


func _silk_road_log_trade_story(
	person: Person,
	text: String,
	event_name: String
) -> void:
	if (
		person == null
		or gs == null
		or gs.narrative_engine == null
		or text.strip_edges() == ""
	):
		return

	gs.narrative_engine.log_event(
		person,
		{
			"type": "text",
			"text": text,
			"source": "economy_engine",
			"category": "trade",
			"event_name": event_name,
			"personally_relevant": (
				person == gs.player
			),
			"suppress_world_feed": true
		}
	)


func barter_silk_road_belonging(
	person: Person,
	payload: Dictionary
) -> Dictionary:
	if not silk_road_available():
		return {
			"success": false,
			"text": (
				"The Silk Road is not active in this era."
			)
		}

	if (
		person == null
		or gs == null
		or gs.belongings_engine == null
		or not gs.belongings_engine.has_method(
			"barter_item_contract_at_index"
		)
		or not gs.belongings_engine.has_method(
			"consume_barter_item_at_index"
		)
	):
		return {
			"success": false,
			"text": "No valid barter authority is available."
		}

	var category: String = str(
		payload.get(
			"category",
			""
		)
	)
	var item_index: int = int(
		payload.get(
			"item_index",
			-1
		)
	)
	var item_id: int = int(
		payload.get(
			"item_id",
			-1
		)
	)

	var quote: Dictionary = (
		gs.belongings_engine.barter_item_contract_at_index(
			person,
			category,
			item_index,
			item_id
		)
	)

	if quote.is_empty():
		return {
			"success": false,
			"text": (
				"That barter offer is no longer at the "
				+ "same inventory position."
			)
		}

	var barter_value: int = int(
		quote.get(
			"barter_value",
			0
		)
	)

	if barter_value <= 0:
		return {
			"success": false,
			"text": "That belonging has no barterable value."
		}

	var consume_report: Dictionary = (
		gs.belongings_engine.consume_barter_item_at_index(
			person,
			category,
			item_index,
			item_id,
			{
				"source": "economy_engine.silk_road_barter",
				"barter_value": barter_value
			}
		)
	)

	if not bool(
		consume_report.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"text": (
				"The barter contract changed before the "
				+ "exchange could settle."
			)
		}

	var removed_item: Dictionary = (
		_economy_dictionary_ref(
			consume_report.get(
				"item",
				{}
			)
		)
	)
	var item_name: String = str(
		removed_item.get(
			"display_name",
			removed_item.get(
				"name",
				"a belonging"
			)
		)
	)

	person.bank_balance += barter_value

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.TRADE_EXECUTED,
			{
				"npc_id": int(
					person.id
				),
				"good_name": item_name,
				"quantity": 1,
				"realm_id": int(
					person.realm_id
				),
				"purchase_price": 0,
				"sale_value": barter_value,
				"profit": barter_value,
				"barter_in": true,
				"exact_value_exchange": true
			}
		)

	var text: String = (
		"I bartered %s on the Silk Road for %s."
		% [
			item_name,
			format_money(
				barter_value,
				person
			)
		]
	)

	gs.push_world_feed(
		"%s bartered %s on the Silk Road for %s."
		% [
			person.first_name,
			item_name,
			format_money(
				barter_value,
				person
			)
		],
		{
			"npc_id": int(
				person.id
			),
			"personally_relevant": (
				person == gs.player
			),
			"category": "trade",
			"event_name": "silk_road_barter",
			"source": "economy_engine",
			"exact_value_exchange": true
		}
	)

	_silk_road_log_trade_story(
		person,
		text,
		"silk_road_barter"
	)

	return {
		"success": true,
		"type": "silk_road_barter_complete",
		"text": text,
		"barter_value": barter_value,
		"exact_value_exchange": true,
		"log_to_diary": false
	}


func resolve_silk_road_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			"refresh"
		)
	).strip_edges().to_lower()
	var result: Dictionary = {
		"success": true,
		"text": ""
	}

	match action_id:
		"open", "refresh":
			pass

		"trade", "buy_and_trade":
			var listing: Dictionary = (
				_economy_dictionary_ref(
					payload.get(
						"listing",
						payload
					)
				)
			)

			result = trade_silk_road(
				actor,
				listing
			)

		"keep", "buy_and_keep":
			var listing: Dictionary = (
				_economy_dictionary_ref(
					payload.get(
						"listing",
						payload
					)
				)
			)

			result = purchase_trade_good_to_keep(
				actor,
				listing
			)

		"barter", "trade_in_belonging":
			var barter_payload: Dictionary = (
				_economy_dictionary_ref(
					payload.get(
						"barter",
						payload
					)
				)
			)

			result = barter_silk_road_belonging(
				actor,
				barter_payload
			)

		_:
			return {
				"success": false,
				"reason": "unsupported_silk_road_intent",
				"action_id": action_id
			}

	var queue_report: Dictionary = (
		queue_resident_silk_road_projection(
			actor,
			{
				"source": "economy_engine.resolve_silk_road_intent",
				"reason": "silk_road_intent_%s" % action_id,
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false
			}
		)
	)

	return {
		"success": bool(
			result.get(
				"success",
				true
			)
		),
		"mode": "silk_road_intent_resolved",
		"action_id": action_id,
		"result": result,
		"projection_queue_report": queue_report,
		"ui_is_renderer_only": true
	}






var ERA_CURRENCIES = {

	"Ancient Era": {
		"name": "Denarii",
		"symbol": "D",
		"base_unit": 1
	},

	"Medieval Era": {
		"name": "Shekels",
		"symbol": "₪",
		"base_unit": 1
	},

	"Industrial Era": {
		"name": "Pounds",
		"symbol": "£",
		"base_unit": 1
	},

	"Modern Era": {
		"name": "USD",
		"symbol": "$",
		"base_unit": 1
	},

	"Future Era": {
		"name": "Credits",
		"symbol": "₡",
		"base_unit": 1
	}
}

func _realm_currency_symbol(
	currency_name: String,
	fallback_symbol: String
) -> String:
	var clean_name: String = str(
		currency_name
	).strip_edges()

	match clean_name.to_lower():
		"deben":
			return "Db "
		"drachmae":
			return "₯"
		"shekels":
			return "₪"
		"crowns":
			return "Cr "
		"solidi":
			return "S "
		"dollars":
			return "$"
		"pounds":
			return "£"
		"marks":
			return "M "
		"yen":
			return "¥"
		"reais":
			return "R$"
		"yuan":
			return "¥"
		"credits":
			return "₡"
		"solar credits":
			return "SC "
		"lunar credits":
			return "LC "
		"gold pieces":
			return "GP "
		"silver marks":
			return "SM "
		"monastery chits":
			return "MC "

	if clean_name == "":
		return fallback_symbol

	var initials: String = ""

	for raw_word in clean_name.split(
		" ",
		false
	):
		var word: String = str(
			raw_word
		).strip_edges()

		if word == "":
			continue

		initials += word.left(
			1
		).to_upper()

	if initials == "":
		return fallback_symbol

	return initials + " "


func _realm_currency_contract_for_person(
	person: Person,
	fallback_currency: Dictionary
) -> Dictionary:
	if (
		person == null
		or gs == null
		or gs.realm_engine == null
	):
		return {}

	var realm_id: int = int(
		person.realm_id
	)

	if realm_id <= 0:
		return {}

	var realms_raw: Variant = (
		gs.realm_engine.realms
	)

	if typeof(
		realms_raw
	) != TYPE_DICTIONARY:
		return {}

	var realms: Dictionary = (
		realms_raw as Dictionary
	)

	var realm_raw: Variant = realms.get(
		realm_id,
		{}
	)

	if typeof(
		realm_raw
	) != TYPE_DICTIONARY:
		return {}

	var realm: Dictionary = (
		realm_raw as Dictionary
	)

	var currency_name: String = str(
		realm.get(
			"currency_name",
			""
		)
	).strip_edges()

	if currency_name == "":
		return {}

	return {
		"name": currency_name,
		"symbol": _realm_currency_symbol(
			currency_name,
			str(
				fallback_currency.get(
					"symbol",
					""
				)
			)
		),
		"base_unit": int(
			fallback_currency.get(
				"base_unit",
				1
			)
		),
		"realm_id": realm_id,
		"realm_name": str(
			realm.get(
				"name",
				""
			)
		),
		"currency_authority": (
			"realm_engine"
		)
	}
func get_currency(
	person: Person = null
):
	var era_name: String = "Modern Era"

	if (
		gs != null
		and gs.era != null
	):
		era_name = str(
			gs.era.name
		)

	var era_currency: Dictionary = ERA_CURRENCIES.get(
		era_name,
		ERA_CURRENCIES ["Modern Era"]
	)
	var realm_currency: Dictionary = (
		_realm_currency_contract_for_person(
			person,
			era_currency
		)
	)

	if not realm_currency.is_empty():
		return realm_currency


	if era_name != "Modern Era":
		return era_currency

	var country_name: String = ""

	if person != null:
		country_name = str(
			person.home_country
		).strip_edges()

		if (
			country_name == ""
			and "birth_country" in person
		):
			country_name = str(
				person.birth_country
			).strip_edges()

	var country_currency_codes: Dictionary = {
		"USA": "USD",
		"United States": "USD",
		"United States of America": "USD",
		"Canada": "CAD",
		"Mexico": "MXN",
		"UK": "GBP",
		"United Kingdom": "GBP",
		"England": "GBP",
		"Scotland": "GBP",
		"Wales": "GBP",
		"Japan": "JPY",
		"China": "CNY",
		"South Korea": "KRW",
		"India": "INR",
		"Germany": "EUR",
		"France": "EUR",
		"Italy": "EUR",
		"Spain": "EUR",
		"Portugal": "EUR",
		"Netherlands": "EUR",
		"Ireland": "EUR",
		"Brazil": "BRL",
		"Australia": "AUD",
		"New Zealand": "NZD",
		"Russia": "RUB",
		"Nigeria": "NGN",
		"South Africa": "ZAR",
		"Egypt": "EGP",
		"Saudi Arabia": "SAR",
		"United Arab Emirates": "AED",
		"Somalia": "SOS",
		"Afghanistan": "AFN",
		"Haiti": "HTG"
	}
	var currency_by_code: Dictionary = {
		"USD": {
			"name": "USD",
			"symbol": "$",
			"base_unit": 1
		},
		"CAD": {
			"name": "CAD",
			"symbol": "C$",
			"base_unit": 1
		},
		"MXN": {
			"name": "MXN",
			"symbol": "MX$",
			"base_unit": 1
		},
		"GBP": {
			"name": "GBP",
			"symbol": "£",
			"base_unit": 1
		},
		"JPY": {
			"name": "JPY",
			"symbol": "¥",
			"base_unit": 1
		},
		"CNY": {
			"name": "CNY",
			"symbol": "¥",
			"base_unit": 1
		},
		"KRW": {
			"name": "KRW",
			"symbol": "₩",
			"base_unit": 1
		},
		"INR": {
			"name": "INR",
			"symbol": "₹",
			"base_unit": 1
		},
		"EUR": {
			"name": "EUR",
			"symbol": "€",
			"base_unit": 1
		},
		"BRL": {
			"name": "BRL",
			"symbol": "R$",
			"base_unit": 1
		},
		"AUD": {
			"name": "AUD",
			"symbol": "A$",
			"base_unit": 1
		},
		"NZD": {
			"name": "NZD",
			"symbol": "NZ$",
			"base_unit": 1
		},
		"RUB": {
			"name": "RUB",
			"symbol": "₽",
			"base_unit": 1
		},
		"NGN": {
			"name": "NGN",
			"symbol": "₦",
			"base_unit": 1
		},
		"ZAR": {
			"name": "ZAR",
			"symbol": "R",
			"base_unit": 1
		},
		"EGP": {
			"name": "EGP",
			"symbol": "E£",
			"base_unit": 1
		},
		"SAR": {
			"name": "SAR",
			"symbol": "SR",
			"base_unit": 1
		},
		"AED": {
			"name": "AED",
			"symbol": "AED ",
			"base_unit": 1
		},
		"SOS": {
			"name": "SOS",
			"symbol": "Sh",
			"base_unit": 1
		},
		"AFN": {
			"name": "AFN",
			"symbol": "؋",
			"base_unit": 1
		},
		"HTG": {
			"name": "HTG",
			"symbol": "G",
			"base_unit": 1
		}
	}

	var currency_code: String = str(
		country_currency_codes.get(
			country_name,
			""
		)
	)

	if currency_code == "":
		var country_economy: Dictionary = (
			country_profile(
				country_name
			)
		)
		currency_code = str(
			country_economy.get(
				"currency",
				"USD"
			)
		)

		if currency_code == "Yen":
			currency_code = "JPY"

	return currency_by_code.get(
		currency_code,
		ERA_CURRENCIES ["Modern Era"]
	)


func _format_int_with_commas(amount: int) -> String:
	var negative:= amount < 0
	var digits:= str(abs(amount))
	var grouped:= ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	if negative:
		grouped = "-" + grouped
	return grouped

func format_money_compact(
	amount,
	person: Person = null
):
	var currency = get_currency(
		person
	)
	var whole_amount: int = int(
		round(
			float(amount)
		)
	)

	return (
		"%s%s"
		% [
			str(
				currency.get(
					"symbol",
					"$"
				)
			),
			_format_int_with_commas(
				whole_amount
			)
		]
	)
func format_money(
	amount,
	person: Person = null
):
	var currency = get_currency(
		person
	)
	var whole_amount: int = int(
		round(
			float(amount)
		)
	)

	return (
		"%s%s %s"
		% [
			str(
				currency.get(
					"symbol",
					"$"
				)
			),
			_format_int_with_commas(
				whole_amount
			),
			str(
				currency.get(
					"name",
					"USD"
				)
			)
		]
	)






var COUNTRY_ECONOMIES = {

	"USA": { "currency": "USD", "value": 1.0, "risk": 0},
	"Japan": { "currency": "Yen", "value": 0.007, "risk": 0},
	"UK": { "currency": "GBP", "value": 1.3, "risk": 0},


	"Somalia": { "currency": "USD", "value": 1.0, "risk": 40},
	"Afghanistan": { "currency": "USD", "value": 1.0, "risk": 35},
	"Haiti": { "currency": "USD", "value": 1.0, "risk": 25}
}


func country_profile(country):

	return COUNTRY_ECONOMIES.get(country, {
		"currency": "USD",
		"value": 1.0,
		"risk": 0
	})






func apply_country_risk(person: Person):

	var profile = country_profile(person.home_country)

	var risk = profile.risk

	if risk == 0:
		return

	if randi() % 100 < risk:

		var events = [
			"A bombing occurred nearby.",
			"⚠️ Political unrest erupted in your city.",
			"🦠 A disease outbreak spread locally.",
			"⚔️ Armed conflict erupted in the region."
		]

		gs.narrative_engine.log_event(person, {
			"type": "text",
			"text": events.pick_random()
		})






var SILK_ROAD_START = -138
var SILK_ROAD_END = 1453

func silk_road_available():
	return gs.year >= SILK_ROAD_START and gs.year <= SILK_ROAD_END

func trade_silk_road(
	person: Person,
	item
):
	if not silk_road_available():
		return {
			"success": false,
			"text": "The Silk Road is not active in this era."
		}

	if person == null:
		return {
			"success": false,
			"text": "No valid trader was found."
		}

	if typeof(
		item
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"text": "That caravan quote is invalid."
		}

	var listing: Dictionary = (
		_silk_road_listing_for_intent(
			person,
			item as Dictionary
		)
	)

	if listing.is_empty():
		return {
			"success": false,
			"text": (
				"That caravan quote is no longer the "
				+ "resident market contract."
			)
		}

	var good_name: String = str(
		listing.get(
			"name",
			"Unknown"
		)
	)
	var local_realm_id: int = int(
		person.realm_id
	)
	var purchase_price: int = int(
		listing.get(
			"price",
			0
		)
	)

	if (
		purchase_price <= 0
		or int(
			person.bank_balance
		) < purchase_price
	):
		return {
			"success": false,
			"text": (
				"I do not have enough money to purchase %s for %s."
				% [
					good_name,
					format_money(
						purchase_price,
						person
					)
				]
			)
		}

	person.bank_balance -= purchase_price

	var route_bonus: float = randf_range(
		1.15,
		2.4
	)
	var sale_value: int = int(
		round(
			float(
				purchase_price
			) * route_bonus
		)
	)
	var profit: int = (
		sale_value - purchase_price
	)

	person.bank_balance += sale_value

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.TRADE_EXECUTED,
			{
				"npc_id": int(
					person.id
				),
				"good_name": good_name,
				"quantity": 1,
				"realm_id": local_realm_id,
				"purchase_price": purchase_price,
				"sale_value": sale_value,
				"profit": profit,
				"listing_id": str(
					listing.get(
						"listing_id",
						""
					)
				),
				"market_generation": int(
					listing.get(
						"market_generation",
						-1
					)
				)
			}
		)

	var text: String = (
		"I bought %s for %s and sold it for %s, netting %s."
		% [
			good_name,
			format_money(
				purchase_price,
				person
			),
			format_money(
				sale_value,
				person
			),
			format_money(
				profit,
				person
			)
		]
	)

	gs.push_world_feed(
		"%s bought %s for %s and sold it along the Silk Road for %s, netting %s."
		% [
			person.first_name,
			good_name,
			format_money(
				purchase_price,
				person
			),
			format_money(
				sale_value,
				person
			),
			format_money(
				profit,
				person
			)
		],
		{
			"npc_id": int(
				person.id
			),
			"personally_relevant": (
				person == gs.player
			),
			"category": "trade",
			"event_name": ActionEventTypes.TRADE_EXECUTED,
			"source": "economy_engine"
		}
	)

	_silk_road_log_trade_story(
		person,
		text,
		"silk_road_trade"
	)

	return {
		"success": true,
		"type": "silk_road_trade_complete",
		"text": text,
		"purchase_price": purchase_price,
		"sale_value": sale_value,
		"profit": profit,
		"log_to_diary": false
	}
func _silk_road_kept_belonging_contract(
	listing: Dictionary
) -> Dictionary:
	var good_name: String = str(
		listing.get(
			"name",
			""
		)
	).strip_edges().to_lower()

	var ownership_contract: Dictionary = {
		"schema": "eralife.silk_road_kept_belonging_contract",
		"version": 1,
		"category": "Trade Goods",
		"type": "TradeGood",
		"ownership_domain": "trade_good",
		"consumable": false,
		"is_luxury": false
	}

	match good_name:
		"tea":
			ownership_contract ["category"] = "Food"
			ownership_contract ["type"] = "Food"
			ownership_contract ["ownership_domain"] = "food"
			ownership_contract ["consumable"] = true

		"gold":
			ownership_contract ["category"] = "Luxury"
			ownership_contract ["type"] = "Precious Metal"
			ownership_contract ["ownership_domain"] = "luxury"
			ownership_contract ["is_luxury"] = true

		"jade":
			ownership_contract ["category"] = "Luxury"
			ownership_contract ["type"] = "Precious Stone"
			ownership_contract ["ownership_domain"] = "luxury"
			ownership_contract ["is_luxury"] = true

		"jewels":
			ownership_contract ["category"] = "Luxury"
			ownership_contract ["type"] = "Precious Stone"
			ownership_contract ["ownership_domain"] = "luxury"
			ownership_contract ["is_luxury"] = true

	return ownership_contract
func purchase_trade_good_to_keep(
	person: Person,
	item
):
	if not silk_road_available():
		return {
			"success": false,
			"text": "The Silk Road is not active in this era."
		}

	if person == null:
		return {
			"success": false,
			"text": "No valid buyer was found."
		}

	if typeof(
		item
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"text": "That caravan quote is invalid."
		}

	var listing: Dictionary = (
		_silk_road_listing_for_intent(
			person,
			item as Dictionary
		)
	)

	if listing.is_empty():
		return {
			"success": false,
			"text": (
				"That caravan quote is no longer the "
				+ "resident market contract."
			)
		}

	var good_name: String = str(
		listing.get(
			"name",
			"Unknown"
		)
	)

	var ownership_contract: Dictionary = (
		_silk_road_kept_belonging_contract(
			listing
		)
	)
	var belongings_category: String = str(
		ownership_contract.get(
			"category",
			"Trade Goods"
		)
	).strip_edges()
	var belonging_type: String = str(
		ownership_contract.get(
			"type",
			"TradeGood"
		)
	).strip_edges()

	if belongings_category == "":
		belongings_category = "Trade Goods"

	if belonging_type == "":
		belonging_type = "TradeGood"

	var local_realm_id: int = int(
		person.realm_id
	)
	var purchase_price: int = int(
		listing.get(
			"price",
			0
		)
	)

	if (
		purchase_price <= 0
		or int(
			person.bank_balance
		) < purchase_price
	):
		return {
			"success": false,
			"text": (
				"I do not have enough money to keep %s for %s."
				% [
					good_name,
					format_money(
						purchase_price,
						person
					)
				]
			)
		}

	person.bank_balance -= purchase_price

	var kept_item:= {
		"id": int(
			gs.next_id
		),
		"name": good_name,
		"value": purchase_price,
		"base_value": int(
			listing.get(
				"base_value",
				purchase_price
			)
		),
		"type": belonging_type,
		"category": belongings_category,
		"ownership_domain": str(
			ownership_contract.get(
				"ownership_domain",
				"trade_good"
			)
		),
		"consumable": bool(
			ownership_contract.get(
				"consumable",
				false
			)
		),
		"is_luxury": bool(
			ownership_contract.get(
				"is_luxury",
				false
			)
		),
		"silk_road_ownership_contract": (
			ownership_contract.duplicate(true)
		),
		"origin_realm_id": local_realm_id,
		"origin_era": (
			gs.era.name
			if gs.era != null
			else ""
		),
		"acquired_year": int(
			gs.year
		),
		"source": "Silk Road Market",
		"silk_road_listing_id": str(
			listing.get(
				"listing_id",
				""
			)
		)
	}

	gs.next_id += 1

	if gs.belongings_engine != null:
		gs.belongings_engine.add_item(
			person,
			kept_item,
			belongings_category
		)

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.TRADE_EXECUTED,
			{
				"npc_id": int(
					person.id
				),
				"good_name": good_name,
				"quantity": 1,
				"realm_id": local_realm_id,
				"purchase_price": purchase_price,
				"sale_value": purchase_price,
				"profit": 0,
			}
		)

	var text: String = (
		"I purchased %s for %s and kept it in my belongings."
		% [
			good_name,
			format_money(
				purchase_price,
				person
			)
		]
	)

	gs.push_world_feed(
		"%s purchased %s from the Silk Road bazaar for %s and kept it."
		% [
			person.first_name,
			good_name,
			format_money(
				purchase_price,
				person
			)
		],
		{
			"npc_id": int(
				person.id
			),
			"personally_relevant": (
				person == gs.player
			),
			"category": "trade",
			"event_name": "silk_road_keep_purchase",
			"source": "economy_engine"
		}
	)

	_silk_road_log_trade_story(
		person,
		text,
		"silk_road_keep_purchase"
	)

	return {
		"success": true,
		"type": "silk_road_keep_complete",
		"text": text,
		"log_to_diary": false
	}




var market_multiplier = 1.0


func yearly_market_update(
	_payload
):
	market_multiplier += randf_range(
		-0.05,
		0.05
	)
	market_multiplier = clamp(
		market_multiplier,
		0.7,
		1.5
	)







	if (
		gs != null
		and gs.player != null
	):
		queue_resident_silk_road_projection(
			gs.player,
			{
				"source": "economy_engine.yearly_market_update",
				"reason": "yearly_market_truth_advanced",
				"target_year": int(
					gs.year
				),
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false
			}
		)

func get_market_price(base_price):

	return int(base_price * market_multiplier)






func on_era_shift(_payload):

	market_multiplier = 1.0