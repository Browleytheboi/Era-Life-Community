extends Resource
class_name GroceryStoreEngine

const GROCERY_VERSION:= 1

var gs
var grocery_contract: Dictionary = {}
var grocery_ledger: Array = []
var grocery_carts_by_actor_id: Dictionary = {}
var grocery_memberships_by_actor_id: Dictionary = {}
var grocery_shopper_sessions_by_store_id: Dictionary = {}
var grocery_store_worker_sessions_by_store_id: Dictionary = {}
var grocery_self_checkout_sessions_by_actor_id: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	grocery_contract = _default_grocery_contract()
func start_grocery_store_realtime_session(
	store_id: String,
	player_aisle_id: String = "",
	context: Dictionary = {}
) -> Dictionary:
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var aisle_ids: Array = aisle_ids_for_store(
		clean_store_id
	)

	if aisle_ids.is_empty():
		return {}

	var clean_player_aisle_id: String = str(
		player_aisle_id
	).strip_edges()

	if clean_player_aisle_id == "":
		clean_player_aisle_id = str(
			aisle_ids [0]
		)

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if session.is_empty():
		var aisle_population_counts: Dictionary = {}
		var aisle_shopper_ids: Dictionary = {}

		for raw_aisle_id in aisle_ids:
			var resident_aisle_id: String = str(
				raw_aisle_id
			).strip_edges()

			if resident_aisle_id == "":
				continue

			aisle_population_counts [
				resident_aisle_id
			] = 0
			aisle_shopper_ids [
				resident_aisle_id
			] = []

		session = {
			"store_id": clean_store_id,
			"active": true,
			"aisle_ids": aisle_ids.duplicate(false),
			"shoppers": {},
			"departed_shopper_ids": [],
			"aisle_population_counts": aisle_population_counts,
			"aisle_shopper_ids": aisle_shopper_ids,
			"arrival_wave_index": 0,
			"arrival_sequence": 0,
			"departure_sequence": 0,
			"completed_purchase_count": 0,
			"next_arrival_wave_ms": now_ms,
			"next_resident_arrival_ms": now_ms,
			"generated_ambient_serial": 0,
			"created_at_ms": now_ms,
			"last_tick_ms": 0,
			"updated_at_ms": now_ms,
			"tick_cycle_active": false,
			"tick_cursor": 0,
			"tick_actor_ids": [],
		}

	session ["active"] = true
	session ["aisle_ids"] = aisle_ids.duplicate(false)
	session ["player_aisle_id"] = clean_player_aisle_id
	session ["worker_shift"] = (
		_ensure_grocery_store_worker_shift(
			clean_store_id,
			context
		)
	)
	session ["updated_at_ms"] = now_ms

	if typeof(
		session.get(
			"aisle_population_counts",
			{}
		)
	) != TYPE_DICTIONARY:
		session ["aisle_population_counts"] = {}

	if typeof(
		session.get(
			"aisle_shopper_ids",
			{}
		)
	) != TYPE_DICTIONARY:
		session ["aisle_shopper_ids"] = {}

	var resident_counts: Dictionary = (
		session ["aisle_population_counts"]
	)
	var resident_ids: Dictionary = (
		session ["aisle_shopper_ids"]
	)

	for raw_aisle_id in aisle_ids:
		var resident_aisle_id: String = str(
			raw_aisle_id
		).strip_edges()

		if resident_aisle_id == "":
			continue

		if not resident_counts.has(
			resident_aisle_id
		):
			resident_counts [
				resident_aisle_id
			] = 0

		if (
			not resident_ids.has(
				resident_aisle_id
			)
			or typeof(
				resident_ids.get(
					resident_aisle_id,
					[]
				)
			) != TYPE_ARRAY
		):
			resident_ids [
				resident_aisle_id
			] = []

	session ["aisle_population_counts"] = resident_counts
	session ["aisle_shopper_ids"] = resident_ids

	var target_count: int = (
		_grocery_store_target_shopper_count(
			clean_store_id
		)
	)
	var current_shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var current_shoppers: Dictionary = (
		current_shoppers_raw as Dictionary
		if typeof(current_shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var prime_pending: bool = (
		current_shoppers.size() < target_count
	)





	session ["population_prime_target_count"] = target_count
	session ["population_prime_pending"] = prime_pending
	session ["population_prime_service_active"] = false
	session ["population_prime_driver"] = "intrinsic_realtime_runtime"
	session ["entry_frame_population_spawn_performed"] = false
	session ["entry_frame_backfill_loop_performed"] = false
	session ["entry_frame_world_population_scan_performed"] = false
	session ["entry_frame_constant_time"] = true
	session ["resident_arrival_clock_owned"] = true
	session ["resident_departure_clock_owned"] = true
	session ["player_aisle_spawn_bias_forbidden"] = true
	session ["aisle_population_scan_per_quantum_forbidden"] = true

	grocery_shopper_sessions_by_store_id [
		clean_store_id
	] = session

	var duration_ms: int = maxi(
		0,
		int(
			Time.get_ticks_msec()
		) - started_at_ms
	)

	EraLog.truth(
		(
			"ERALIFE_GROCERY_ENTRY_TRUTH"
			+ "|store_id=%s"
			+ "|aisle_id=%s"
			+ "|visible_shoppers=%d"
			+ "|population_prime_pending=%s"
			+ "|backfill_loop=false"
			+ "|world_population_scan=false"
			+ "|duration_ms=%d"
			+ "|at_ms=%d"
		)
		% [
			clean_store_id,
			clean_player_aisle_id,
			current_shoppers.size(),
			str(prime_pending).to_lower(),
			duration_ms,
			int(Time.get_ticks_msec())
		]
	)

	return session.duplicate(false)

func _continue_grocery_store_realtime_session_prime(
		store_id: String,
		player_aisle_id: String
) -> void:
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)

	if typeof(session_raw) != TYPE_DICTIONARY:
		return

	var session: Dictionary = (
		session_raw as Dictionary
	)

	if (
		session.is_empty()
		or not bool(
			session.get(
				"active",
				false
			)
		)
	):
		return

	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var target_count: int = int(
		session.get(
			"population_prime_target_count",
			_grocery_store_target_shopper_count(
				clean_store_id
			)
		)
	)

	if shoppers.size() < target_count:
		_grocery_spawn_resident_shopper_quantum(
			clean_store_id,
			player_aisle_id,
			session
		)

	shoppers_raw = session.get(
		"shoppers",
		{}
	)
	shoppers = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)

	var complete: bool = (
		shoppers.size() >= target_count
	)

	session ["population_prime_pending"] = not complete
	session ["population_prime_service_active"] = false
	session ["population_prime_driver"] = "intrinsic_realtime_runtime"
	session ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	grocery_shopper_sessions_by_store_id [
		clean_store_id
	] = session

	EraLog.truth(
		(
			"ERALIFE_GROCERY_POPULATION_PRIME_TRUTH"
			+ "|store_id=%s"
			+ "|shopper_count=%d"
			+ "|target_count=%d"
			+ "|one_shopper_per_quantum=true"
			+ "|self_reschedule=false"
			+ "|blocking_loop=false"
			+ "|at_ms=%d"
		)
		% [
			clean_store_id,
			shoppers.size(),
			target_count,
			int(Time.get_ticks_msec())
		]
	)

func stop_grocery_store_realtime_session(store_id: String = "") -> void:
	var clean_store_id: String = str(store_id).strip_edges()

	if clean_store_id == "":
		for raw_key in grocery_shopper_sessions_by_store_id.keys():
			var key: String = str(raw_key)
			var session: Dictionary = grocery_shopper_sessions_by_store_id.get(key, {}) if typeof(grocery_shopper_sessions_by_store_id.get(key, {})) == TYPE_DICTIONARY else {}
			session ["active"] = false
			session ["updated_at_ms"] = int(Time.get_ticks_msec())
			grocery_shopper_sessions_by_store_id [key] = session
		return

	var store_session: Dictionary = grocery_shopper_sessions_by_store_id.get(clean_store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(clean_store_id, {})) == TYPE_DICTIONARY else {}
	if store_session.is_empty():
		return

	store_session ["active"] = false
	store_session ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_shopper_sessions_by_store_id [clean_store_id] = store_session


func drive_grocery_store_realtime_session(
	store_id: String,
	player_aisle_id: String = "",
	_delta: float = 0.0,
	context: Dictionary = {}
) -> Dictionary:
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	if session.is_empty():
		session = start_grocery_store_realtime_session(
			clean_store_id,
			player_aisle_id,
			context
		)

	if session.is_empty():
		return {}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var clean_player_aisle_id: String = str(
		player_aisle_id
	).strip_edges()
	var aisle_ids_raw: Variant = session.get(
		"aisle_ids",
		[]
	)
	var aisle_ids: Array = (
		aisle_ids_raw as Array
		if typeof(aisle_ids_raw) == TYPE_ARRAY
		else aisle_ids_for_store(
			clean_store_id
		)
	)
	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var departed_raw: Variant = session.get(
		"departed_shopper_ids",
		[]
	)
	var departed_shopper_ids: Array = (
		departed_raw as Array
		if typeof(departed_raw) == TYPE_ARRAY
		else []
	)
	var counts_raw: Variant = session.get(
		"aisle_population_counts",
		{}
	)
	var aisle_population_counts: Dictionary = (
		counts_raw as Dictionary
		if typeof(counts_raw) == TYPE_DICTIONARY
		else {}
	)
	var ids_raw: Variant = session.get(
		"aisle_shopper_ids",
		{}
	)
	var aisle_shopper_ids: Dictionary = (
		ids_raw as Dictionary
		if typeof(ids_raw) == TYPE_DICTIONARY
		else {}
	)

	session ["active"] = true
	session ["player_aisle_id"] = clean_player_aisle_id

	var target_count: int = (
		_grocery_store_target_shopper_count(
			clean_store_id
		)
	)
	var minimum_count: int = (
		_grocery_store_min_shopper_count(
			clean_store_id
		)
	)
	var maximum_count: int = (
		_grocery_store_max_shopper_count(
			clean_store_id
		)
	)



	if (
		shoppers.size() < target_count
		and now_ms >= int(
			session.get(
				"next_resident_arrival_ms",
				0
			)
		)
	):
		_grocery_spawn_resident_shopper_quantum(
			clean_store_id,
			clean_player_aisle_id,
			session
		)

		shoppers_raw = session.get(
			"shoppers",
			{}
		)
		shoppers = (
			shoppers_raw as Dictionary
			if typeof(shoppers_raw) == TYPE_DICTIONARY
			else {}
		)

		counts_raw = session.get(
			"aisle_population_counts",
			{}
		)
		aisle_population_counts = (
			counts_raw as Dictionary
			if typeof(counts_raw) == TYPE_DICTIONARY
			else {}
		)

		ids_raw = session.get(
			"aisle_shopper_ids",
			{}
		)
		aisle_shopper_ids = (
			ids_raw as Dictionary
			if typeof(ids_raw) == TYPE_DICTIONARY
			else {}
		)

	session ["population_prime_pending"] = (
		shoppers.size() < minimum_count
	)
	session ["population_prime_service_active"] = false
	session ["population_prime_driver"] = (
		"intrinsic_realtime_runtime"
	)



	var actor: Person = _actor_from_context(
		context
	)

	if actor != null:
		var self_checkout_prime: Dictionary = (
			_prime_self_checkout_session_quantum(
				actor,
				clean_store_id,
				context
			)
		)

		session ["self_checkout_residency"] = {
			"resident_ready": bool(
				self_checkout_prime.get(
					"resident_ready",
					false
				)
			),
			"published_machine_count": int(
				self_checkout_prime.get(
					"machine_prime_cursor",
					0
				)
			),
			"target_machine_count": int(
				self_checkout_prime.get(
					"machine_prime_target",
					0
				)
			)
		}

	var tick_cycle_active: bool = bool(
		session.get(
			"tick_cycle_active",
			false
		)
	)
	var last_tick_ms: int = int(
		session.get(
			"last_tick_ms",
			0
		)
	)

	if (
		not tick_cycle_active
		and now_ms - last_tick_ms
		< _grocery_store_shopper_tick_ms()
	):
		session ["shoppers"] = shoppers
		session ["aisle_population_counts"] = (
			aisle_population_counts
		)
		session ["aisle_shopper_ids"] = (
			aisle_shopper_ids
		)
		session ["updated_at_ms"] = now_ms
		session ["last_service_quantum_duration_ms"] = maxi(
			0,
			int(
				Time.get_ticks_msec()
			) - started_at_ms
		)
		session ["lens_patch_contract"] = (
			_grocery_realtime_lens_patch_contract(
				clean_store_id,
				clean_player_aisle_id,
				context
			)
		)

		grocery_shopper_sessions_by_store_id [
			clean_store_id
		] = session

		return session.duplicate(false)

	var tick_actor_ids_raw: Variant = session.get(
		"tick_actor_ids",
		[]
	)
	var tick_actor_ids: Array = (
		tick_actor_ids_raw as Array
		if typeof(tick_actor_ids_raw) == TYPE_ARRAY
		else []
	)
	var tick_cursor: int = int(
		session.get(
			"tick_cursor",
			0
		)
	)

	if not tick_cycle_active:
		tick_actor_ids = shoppers.keys()
		tick_cursor = 0
		tick_cycle_active = true

	var quantum_limit: int = clampi(
		int(
			context.get(
				"shopper_quantum_limit",
				1
			)
		),
		1,
		3
	)
	var processed: int = 0

	while (
		tick_cursor < tick_actor_ids.size()
		and processed < quantum_limit
	):
		var shopper_id: String = str(
			tick_actor_ids [tick_cursor]
		)
		tick_cursor += 1
		processed += 1

		var shopper_raw: Variant = shoppers.get(
			shopper_id,
			{}
		)

		if typeof(shopper_raw) != TYPE_DICTIONARY:
			continue

		var shopper: Dictionary = (
			shopper_raw as Dictionary
		)

		if shopper.is_empty():
			shoppers.erase(
				shopper_id
			)
			continue

		var current_aisle_id: String = str(
			shopper.get(
				"aisle_id",
				""
			)
		).strip_edges()
		var current_aisle_count: int = int(
			aisle_population_counts.get(
				current_aisle_id,
				0
			)
		)

		if _grocery_shopper_snapshot_is_unaccompanied_under_15(
			shopper,
			shoppers
		):
			shopper ["left_store"] = true
			shopper ["left_at_ms"] = now_ms
			shopper ["removed_reason"] = (
				"under_15_without_adult_companion"
			)

			shoppers.erase(
				shopper_id
			)

			if current_aisle_id != "":
				aisle_population_counts [
					current_aisle_id
				] = maxi(
					0,
					current_aisle_count - 1
				)

				var underage_ids_raw: Variant = (
					aisle_shopper_ids.get(
						current_aisle_id,
						[]
					)
				)
				var underage_ids: Array = (
					underage_ids_raw as Array
					if typeof(underage_ids_raw) == TYPE_ARRAY
					else []
				)
				underage_ids.erase(
					shopper_id
				)
				aisle_shopper_ids [
					current_aisle_id
				] = underage_ids

			if not departed_shopper_ids.has(
				int(shopper_id)
			):
				departed_shopper_ids.append(
					int(shopper_id)
				)

			session ["departure_sequence"] = int(
				session.get(
					"departure_sequence",
					0
				)
			) + 1

			continue

		var protected_shopper: bool = (
			clean_player_aisle_id != ""
			and current_aisle_id
			== clean_player_aisle_id
			and current_aisle_count <= 1
		)

		var rng: RandomNumberGenerator = (
			_grocery_shopper_rng(
				"%s|%s|quantum|%d"
				% [
					clean_store_id,
					shopper_id,
					int(
						floor(
							float(now_ms)
							/ float(
								maxi(
									1,
									_grocery_store_shopper_tick_ms()
								)
							)
						)
					)
				]
			)
		)

		var is_lingering: bool = (
			now_ms
			< int(
				shopper.get(
					"linger_until_ms",
					0
				)
			)
		)




		shopper = _grocery_tick_shopper_behavior(
			shopper,
			rng,
			now_ms
		)

		if bool(
			shopper.get(
				"checkout_departure_ready",
				false
			)
		):
			shopper ["left_store"] = true
			shopper ["left_at_ms"] = now_ms
			shopper ["removed_reason"] = (
				"purchase_completed"
			)

			session ["completed_purchase_count"] = int(
				session.get(
					"completed_purchase_count",
					0
				)
			) + 1
			session ["last_completed_purchase"] = {
				"shopper_id": shopper_id,
				"store_id": clean_store_id,
				"item_count": int(
					shopper.get(
						"purchase_item_count",
						0
					)
				),
				"total": float(
					shopper.get(
						"purchase_total",
						0.0
					)
				),
				"completed_at_ms": now_ms
			}

			shoppers.erase(
				shopper_id
			)

			if current_aisle_id != "":
				aisle_population_counts [
					current_aisle_id
				] = maxi(
					0,
					current_aisle_count - 1
				)

				var checkout_ids_raw: Variant = (
					aisle_shopper_ids.get(
						current_aisle_id,
						[]
					)
				)
				var checkout_ids: Array = (
					checkout_ids_raw as Array
					if typeof(checkout_ids_raw) == TYPE_ARRAY
					else []
				)
				checkout_ids.erase(
					shopper_id
				)
				aisle_shopper_ids [
					current_aisle_id
				] = checkout_ids

			if not departed_shopper_ids.has(
				int(shopper_id)
			):
				departed_shopper_ids.append(
					int(shopper_id)
				)

			session ["departure_sequence"] = int(
				session.get(
					"departure_sequence",
					0
				)
			) + 1

			continue

		var occupancy_span: int = maxi(
			1,
			maximum_count - minimum_count
		)
		var occupancy_pressure: float = clampf(
			float(
				shoppers.size() - minimum_count
			) / float(
				occupancy_span
			),
			0.0,
			1.0
		)
		var shopping_state: String = str(
			shopper.get(
				"shopping_state",
				"actively_shopping"
			)
		).strip_edges().to_lower()
		var ambient_departure_chance: float = lerpf(
			0.008,
			0.085,
			occupancy_pressure
		)



		if shopping_state in [
			"checkout_bound",
			"checking_out"
		]:
			ambient_departure_chance = 0.0

		if (
			not protected_shopper
			and not is_lingering
			and shoppers.size() > minimum_count
			and rng.randf() < ambient_departure_chance
		):
			shopper ["left_store"] = true
			shopper ["left_at_ms"] = now_ms
			shopper ["removed_reason"] = (
				"ambient_trip_complete"
			)

			shoppers.erase(
				shopper_id
			)

			if current_aisle_id != "":
				aisle_population_counts [
					current_aisle_id
				] = maxi(
					0,
					current_aisle_count - 1
				)

				var ambient_ids_raw: Variant = (
					aisle_shopper_ids.get(
						current_aisle_id,
						[]
					)
				)
				var ambient_ids: Array = (
					ambient_ids_raw as Array
					if typeof(ambient_ids_raw) == TYPE_ARRAY
					else []
				)
				ambient_ids.erase(
					shopper_id
				)
				aisle_shopper_ids [
					current_aisle_id
				] = ambient_ids

			if not departed_shopper_ids.has(
				int(shopper_id)
			):
				departed_shopper_ids.append(
					int(shopper_id)
				)

			session ["departure_sequence"] = int(
				session.get(
					"departure_sequence",
					0
				)
			) + 1

			continue

		if (
			not protected_shopper
			and not is_lingering
			and rng.randf() < 0.24
			and aisle_ids.size() > 1
		):
			var next_aisle_id: String = (
				current_aisle_id
			)
			var attempts: int = 0

			while (
				next_aisle_id == current_aisle_id
				and attempts < 6
			):
				next_aisle_id = str(
					aisle_ids [
						int(
							rng.randi_range(
								0,
								aisle_ids.size() - 1
							)
						)
					]
				).strip_edges()
				attempts += 1

			if (
				next_aisle_id != ""
				and next_aisle_id != current_aisle_id
			):
				shopper ["aisle_id"] = next_aisle_id
				shopper ["last_aisle_change_ms"] = now_ms
				shopper ["linger_until_ms"] = (
					now_ms
					+ int(
						rng.randi_range(
							2200,
							9200
						)
					)
				)

				if current_aisle_id != "":
					aisle_population_counts [
						current_aisle_id
					] = maxi(
						0,
						current_aisle_count - 1
					)

					var old_ids_raw: Variant = (
						aisle_shopper_ids.get(
							current_aisle_id,
							[]
						)
					)
					var old_ids: Array = (
						old_ids_raw as Array
						if typeof(old_ids_raw) == TYPE_ARRAY
						else []
					)
					old_ids.erase(
						shopper_id
					)
					aisle_shopper_ids [
						current_aisle_id
					] = old_ids

				aisle_population_counts [
					next_aisle_id
				] = int(
					aisle_population_counts.get(
						next_aisle_id,
						0
					)
				) + 1

				var next_ids_raw: Variant = (
					aisle_shopper_ids.get(
						next_aisle_id,
						[]
					)
				)
				var next_ids: Array = (
					next_ids_raw as Array
					if typeof(next_ids_raw) == TYPE_ARRAY
					else []
				)

				if shopper_id not in next_ids:
					next_ids.append(
						shopper_id
					)

				aisle_shopper_ids [
					next_aisle_id
				] = next_ids

		shopper ["updated_at_ms"] = now_ms
		shoppers [shopper_id] = shopper

	if tick_cursor >= tick_actor_ids.size():
		tick_cycle_active = false
		tick_cursor = 0
		tick_actor_ids = []
		session ["last_tick_ms"] = now_ms

	session ["tick_cycle_active"] = tick_cycle_active
	session ["tick_cursor"] = tick_cursor
	session ["tick_actor_ids"] = tick_actor_ids
	session ["shoppers"] = shoppers
	session ["departed_shopper_ids"] = (
		departed_shopper_ids
	)
	session ["aisle_population_counts"] = (
		aisle_population_counts
	)
	session ["aisle_shopper_ids"] = (
		aisle_shopper_ids
	)
	session ["updated_at_ms"] = now_ms
	session ["last_service_quantum_count"] = processed
	session ["last_service_quantum_duration_ms"] = maxi(
		0,
		int(
			Time.get_ticks_msec()
		) - started_at_ms
	)
	session ["full_shopper_loop_performed"] = false
	session ["arrival_backfill_loop_performed"] = false
	session ["aisle_population_full_scan_performed"] = false
	session ["arrival_and_departure_balanced_live"] = true
	session ["lens_patch_contract"] = (
		_grocery_realtime_lens_patch_contract(
			clean_store_id,
			clean_player_aisle_id,
			context
		)
	)

	grocery_shopper_sessions_by_store_id [
		clean_store_id
	] = session

	if int(
		session.get(
			"last_service_quantum_duration_ms",
			0
		)
	) > 2:
		EraLog.truth(
			(
				"ERALIFE_GROCERY_REALTIME_BUDGET_TRUTH"
				+ "|store_id=%s"
				+ "|processed=%d"
				+ "|remaining=%d"
				+ "|duration_ms=%d"
				+ "|full_loop=false"
				+ "|at_ms=%d"
			)
			% [
				clean_store_id,
				processed,
				maxi(
					0,
					tick_actor_ids.size() - tick_cursor
				),
				int(
					session.get(
						"last_service_quantum_duration_ms",
						0
					)
				),
				now_ms
			]
		)

	return session.duplicate(false)
func get_grocery_aisle_shopper_summary(
		store_id: String,
		aisle_id: String,
		_context: Dictionary = {}
) -> Dictionary:
	var clean_store_id: String = str(
		store_id
	).strip_edges()
	var clean_aisle_id: String = str(
		aisle_id
	).strip_edges()

	if (
		clean_store_id == ""
		or clean_aisle_id == ""
	):
		return {
			"store_id": clean_store_id,
			"aisle_id": clean_aisle_id,
			"count": 0,
			"shoppers": [],
			"shoppers_by_id": {},
			"projection_only": true
		}

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)
	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var aisle_shoppers: Array = []

	for raw_id in shoppers.keys():
		var shopper_raw: Variant = shoppers.get(
			raw_id,
			{}
		)

		if typeof(shopper_raw) != TYPE_DICTIONARY:
			continue

		var shopper: Dictionary = (
			shopper_raw as Dictionary
		)

		if str(
			shopper.get(
				"aisle_id",
				""
			)
		).strip_edges() != clean_aisle_id:
			continue

		aisle_shoppers.append(
			shopper.duplicate(false)
		)

	return {
		"store_id": clean_store_id,
		"aisle_id": clean_aisle_id,
		"count": aisle_shoppers.size(),
		"shoppers": aisle_shoppers,
		"shoppers_by_id": shoppers.duplicate(false),
		"updated_at_ms": int(
			session.get(
				"updated_at_ms",
				0
			)
		),
		"projection_only": true,
	}
func get_grocery_aisle_shopper_popup_rows(
	store_id: String,
	aisle_id: String,
	context: Dictionary = {}
) -> Array:
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var summary: Dictionary = (
		get_grocery_aisle_shopper_summary(
			store_id,
			aisle_id,
			context
		)
	)
	var shoppers_raw: Variant = summary.get(
		"shoppers",
		[]
	)
	var shoppers: Array = (
		shoppers_raw as Array
		if typeof(shoppers_raw) == TYPE_ARRAY
		else []
	)
	var shoppers_by_id_raw: Variant = summary.get(
		"shoppers_by_id",
		{}
	)
	var shoppers_by_id: Dictionary = (
		shoppers_by_id_raw as Dictionary
		if typeof(shoppers_by_id_raw) == TYPE_DICTIONARY
		else {}
	)
	var out: Array = []

	for raw_shopper in shoppers:
		if typeof(raw_shopper) != TYPE_DICTIONARY:
			continue

		var shopper: Dictionary = (
			raw_shopper as Dictionary
		)

		if _grocery_shopper_snapshot_is_unaccompanied_under_15(
			shopper,
			shoppers_by_id
		):
			continue

		var preview_raw: Variant = shopper.get(
			"preview_identity",
			{}
		)
		var preview_identity: Dictionary = (
			preview_raw as Dictionary
			if typeof(preview_raw) == TYPE_DICTIONARY
			else {}
		)
		var display_name: String = str(
			shopper.get(
				"name",
				preview_identity.get(
					"display_name",
					preview_identity.get(
						"name",
						"Unknown shopper"
					)
				)
			)
		).strip_edges()
		var profession: String = str(
			shopper.get(
				"profession",
				preview_identity.get(
					"profession",
					"Between jobs"
				)
			)
		).strip_edges()

		if display_name == "":
			display_name = "Unknown shopper"

		if profession == "":
			profession = "Between jobs"

		var age: int = _grocery_shopper_snapshot_age(
			shopper
		)
		var shopping_state: String = str(
			shopper.get(
				"shopping_state",
				"shopping"
			)
		).strip_edges().to_lower()
		var last_added_text: String = str(
			shopper.get(
				"last_cart_addition_text",
				""
			)
		).strip_edges()
		var person_id: int = int(
			shopper.get(
				"materialized_person_id",
				shopper.get(
					"person_id",
					-1
				)
			)
		)
		var shard_id: String = str(
			shopper.get(
				"shard_id",
				""
			)
		)
		var identity_sort_token: String = shard_id

		if person_id > 0:
			identity_sort_token = str(person_id)

		if identity_sort_token == "":
			identity_sort_token = display_name.to_lower()

		var cart_total: float = float(
			shopper.get(
				"cart_total",
				0.0
			)
		)
		var cart_item_count: int = int(
			shopper.get(
				"cart_item_count",
				0
			)
		)
		var preview_copy: Dictionary = (
			preview_identity.duplicate(false)
		)
		var crbs_raw: Variant = shopper.get(
			"crbs",
			{}
		)
		var crbs: Dictionary = (
			(crbs_raw as Dictionary).duplicate(false)
			if typeof(crbs_raw) == TYPE_DICTIONARY
			else {}
		)
		var cart_items_raw: Variant = shopper.get(
			"cart_items",
			[]
		)
		var cart_items: Array = (
			(cart_items_raw as Array).duplicate(false)
			if typeof(cart_items_raw) == TYPE_ARRAY
			else []
		)
		var last_addition_raw: Variant = shopper.get(
			"last_cart_addition",
			{}
		)
		var last_addition: Dictionary = (
			(last_addition_raw as Dictionary).duplicate(false)
			if typeof(last_addition_raw) == TYPE_DICTIONARY
			else {}
		)

		out.append({
			"person_id": person_id,
			"shard_id": shard_id,
			"name": display_name,
			"profession": profession,
			"age": age,
			"preview_age": int(
				preview_identity.get(
					"age",
					age
				)
			),
			"identity_state": str(
				shopper.get(
					"identity_state",
					"deferred_public_shard"
				)
			),
			"shopping_state": shopping_state,
			"presence_kind": str(
				shopper.get(
					"presence_kind",
					"public_space_shard"
				)
			),
			"simulation_depth": str(
				shopper.get(
					"simulation_depth",
					"resident_snapshot"
				)
			),
			"preview_identity": preview_copy,
			"crbs": crbs,
			"aisle_id": str(
				shopper.get(
					"aisle_id",
					aisle_id
				)
			),
			"cart_total": cart_total,
			"cart_item_count": cart_item_count,
			"cart_items": cart_items,
			"last_cart_addition": last_addition,
			"last_cart_addition_text": last_added_text,
			"sort_key": "%s|%s|%s" % [
				str(
					shopper.get(
						"aisle_id",
						aisle_id
					)
				),
				display_name.to_lower(),
				identity_sort_token
			],
			"description": (
				"%s • %s • %s • %d item/s in cart "
				+ "• Cart estimate: $%.2f.%s"
			) % [
				display_name,
				profession,
				shopping_state.replace(
					"_",
					" "
				),
				cart_item_count,
				cart_total,
				(
					" %s" % last_added_text
					if last_added_text != ""
					else ""
				)
			],
			"projection_only": true,
		})

	out.sort_custom(
		Callable(
			self,
			"_grocery_compare_shopper_popup_rows"
		)
	)

	var finished_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var duration_ms: int = maxi(
		0,
		finished_at_ms - started_at_ms
	)

	EraLog.truth(
		"ERALIFE_GROCERY_SHOPPER_PACKET_TRUTH"
		+ "|store_id=" + str(store_id)
		+ "|aisle_id=" + str(aisle_id)
		+ "|rows=" + str(out.size())
		+ "|identity_materialization=false"
		+ "|npc_reactivation=false"
		+ "|deep_copy=false"
		+ "|duration_ms=" + str(duration_ms)
		+ "|at_ms=" + str(finished_at_ms)
	)

	return out
func _grocery_compare_shopper_popup_rows(a: Variant, b: Variant) -> bool:
	var row_a: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {}
	var row_b: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {}
	return str(row_a.get("sort_key", row_a.get("name", ""))) < str(row_b.get("sort_key", row_b.get("name", "")))
func materialize_grocery_shopper_for_ui(person_id: int, context: Dictionary = {}) -> Dictionary:
	var requested_id: int = int(person_id)
	var store_id: String = str(context.get("store_id", "")).strip_edges()
	var aisle_id: String = str(context.get("aisle_id", "")).strip_edges()
	var requested_shard_id: String = str(context.get("shard_id", "")).strip_edges()

	if requested_id > 0:
		var existing_person: Person = gs.get_npc_by_id(requested_id) if gs != null and gs.has_method("get_npc_by_id") else null
		if existing_person == null and gs != null and gs.has_method("get_or_reactivate_npc_by_id"):
			existing_person = gs.get_or_reactivate_npc_by_id(requested_id)
		if existing_person != null:
			if has_method("sanitize_grocery_identity_for_relationship_profile"):
				sanitize_grocery_identity_for_relationship_profile(existing_person, {
					"source": "materialize_grocery_shopper_existing_person",
					"store_id": store_id,
					"aisle_id": aisle_id,
					"shard_id": requested_shard_id
				})
			return {
				"success": true,
				"person_id": int(existing_person.id),
				"reason": "Shopper was already a canonical NPC."
			}

	if store_id == "":
		store_id = _grocery_find_store_id_for_shopper_id(requested_id)

	if store_id == "":
		return {
			"success": false,
			"person_id": -1,
			"reason": "Could not resolve deferred grocery shopper store."
		}

	var session: Dictionary = grocery_shopper_sessions_by_store_id.get(store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(store_id, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return {
			"success": false,
			"person_id": -1,
			"reason": "Grocery shopper session is no longer active."
		}

	var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
	var old_key: String = str(requested_id)

	if not shoppers.has(old_key) and requested_shard_id != "":
		for raw_key in shoppers.keys():
			var candidate: Dictionary = shoppers.get(raw_key, {}) if typeof(shoppers.get(raw_key, {})) == TYPE_DICTIONARY else {}
			if str(candidate.get("shard_id", "")).strip_edges() == requested_shard_id:
				old_key = str(raw_key)
				requested_id = int(candidate.get("person_id", requested_id))
				break

	if not shoppers.has(old_key):
		return {
			"success": false,
			"person_id": -1,
			"reason": "Deferred shopper already left the store."
		}

	var shopper: Dictionary = shoppers.get(old_key, {}) if typeof(shoppers.get(old_key, {})) == TYPE_DICTIONARY else {}
	if shopper.is_empty():
		return {
			"success": false,
			"person_id": -1,
			"reason": "Deferred shopper snapshot was empty."
		}

	shopper = _grocery_resolve_deferred_shopper_identity(shopper, {
		"store_id": store_id,
		"aisle_id": aisle_id,
		"source": "materialize_grocery_shopper_for_ui"
	})

	var existing_materialized_id: int = int(shopper.get("materialized_person_id", -1))
	if existing_materialized_id > 0:
		return {
			"success": true,
			"person_id": existing_materialized_id,
			"reason": "Shopper had already been materialized."
		}

	var person: Person = _grocery_create_materialized_shard_person(shopper, context)
	if person == null:
		return {
			"success": false,
			"person_id": -1,
			"reason": "Could not materialize grocery shopper shard."
		}

	var causal_reason: Dictionary = _grocery_materialized_shopper_causal_reason(store_id, aisle_id, shopper, context)
	shopper ["person_id"] = int(person.id)
	shopper ["materialized_person_id"] = int(person.id)
	shopper ["name"] = _grocery_person_name(person)
	shopper ["profession"] = _grocery_person_profession(person)
	shopper ["identity_state"] = "materialized"
	shopper ["presence_kind"] = "world_npc_from_shard"
	shopper ["cje"] = causal_reason.duplicate(true)
	shopper ["crbs"] = {
		"visibility_state": "visible",
		"interaction_state": "live",
		"execution_state": "complete"
	}
	shopper ["rias"] = {
		"anchored": true,
		"anchor_id": "npc_%d" % int(person.id),
		"anchor_rule": "Materialized from grocery presence shard after player intent."
	}

	shoppers.erase(old_key)
	shoppers [str(int(person.id))] = shopper

	var materialized_shard_ids: Dictionary = session.get("materialized_shard_ids", {}) if typeof(session.get("materialized_shard_ids", {})) == TYPE_DICTIONARY else {}
	var shard_key: String = str(shopper.get("shard_id", "")).strip_edges()
	if shard_key != "":
		materialized_shard_ids [shard_key] = int(person.id)

	session ["shoppers"] = shoppers
	session ["materialized_shard_ids"] = materialized_shard_ids
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_shopper_sessions_by_store_id [store_id] = session

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var anchors: Dictionary = gs.scenario_state.get("grocery_shard_identity_anchors", {}) if typeof(gs.scenario_state.get("grocery_shard_identity_anchors", {})) == TYPE_DICTIONARY else {}
		if shard_key != "":
			anchors [shard_key] = {
				"person_id": int(person.id),
				"store_id": store_id,
				"aisle_id": aisle_id,
				"cje": causal_reason.duplicate(true),
				"anchored_at_year": int(gs.year),
				"anchored_at_ms": int(Time.get_ticks_msec())
			}
			gs.scenario_state ["grocery_shard_identity_anchors"] = anchors

	return {
		"success": true,
		"person_id": int(person.id),
		"shopper": shopper.duplicate(true),
		"cje": causal_reason.duplicate(true),
		"text": "%s becomes a real anchored person in the world." % _grocery_person_name(person)
	}

func _grocery_find_store_id_for_shopper_id(person_id: int) -> String:
	var target_key: String = str(int(person_id))
	for raw_store_id in grocery_shopper_sessions_by_store_id.keys():
		var store_id: String = str(raw_store_id)
		var session: Dictionary = grocery_shopper_sessions_by_store_id.get(store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(store_id, {})) == TYPE_DICTIONARY else {}
		var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
		if shoppers.has(target_key):
			return store_id
	return ""


func _grocery_create_materialized_shard_person(shopper: Dictionary, context: Dictionary = {}) -> Person:
	if gs == null:
		return null

	shopper = _grocery_resolve_deferred_shopper_identity(shopper, context)

	var shard_id: String = str(shopper.get("shard_id", "grocery_shard")).strip_edges()
	var preview_identity: Dictionary = shopper.get("preview_identity", {}) if typeof(shopper.get("preview_identity", {})) == TYPE_DICTIONARY else {}

	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|materialize|%s|%s" % [
		shard_id,
		str(context.get("store_id", shopper.get("store_id", ""))),
		str(context.get("aisle_id", shopper.get("aisle_id", "")))
	])

	var person: Person = null
	if gs.npc_factory != null and gs.npc_factory.has_method("_create_base_npc"):
		person = gs.npc_factory._create_base_npc()
	else:
		person = Person.new()
		person.id = int(gs.next_id)
		gs.next_id += 1
		person.parents = []
		person.children = []
		person.memories = []

	if person == null:
		return null

	var preview_first_name: String = str(preview_identity.get("first_name", "")).strip_edges()
	var preview_last_name: String = str(preview_identity.get("last_name", "")).strip_edges()
	var preview_gender: String = str(preview_identity.get("gender", "")).strip_edges()
	var preview_job: String = str(preview_identity.get("job", "")).strip_edges()
	var preview_age: int = int(preview_identity.get("age", 0))

	if preview_first_name == "":
		var first_names: Array = _grocery_generated_first_names()
		preview_first_name = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])

	if preview_last_name == "":
		var last_names: Array = _grocery_generated_last_names()
		preview_last_name = str(last_names [int(rng.randi_range(0, last_names.size() - 1))])

	if preview_gender == "":
		var gender_options: Array = ["Male", "Female"]
		preview_gender = str(gender_options [int(rng.randi_range(0, gender_options.size() - 1))])

	if preview_age <= 0:
		preview_age = _grocery_materialized_shopper_age(rng)

	if preview_job == "":
		preview_job = "Student" if preview_age < 18 else _grocery_pick_materialized_shopper_job(rng)

	person.first_name = preview_first_name
	person.last_name = preview_last_name
	person.gender = preview_gender
	person.age = preview_age
	person.job = preview_job

	if str(person.home_city).strip_edges() == "" and gs.player != null:
		person.home_city = str(gs.player.home_city)
	if str(person.home_country).strip_edges() == "" and gs.player != null:
		person.home_country = str(gs.player.home_country)
	if str(person.birth_city).strip_edges() == "":
		person.birth_city = str(person.home_city)
	if str(person.birth_country).strip_edges() == "":
		person.birth_country = str(person.home_country)

	if typeof(person.memories) != TYPE_ARRAY:
		person.memories = []

	var causal_reason: Dictionary = _grocery_materialized_shopper_causal_reason(
		str(context.get("store_id", shopper.get("store_id", ""))),
		str(context.get("aisle_id", shopper.get("aisle_id", ""))),
		shopper,
		context
	)

	person.memories.append("I was at %s because %s" % [
		str(causal_reason.get("store_id", "a grocery store")),
		str(causal_reason.get("why_here", "I needed groceries."))
	])

	_grocery_attach_materialized_shopper_family(person, rng)

	if gs.has_method("apply_reality_rules_to_person"):
		gs.apply_reality_rules_to_person(person)

	_grocery_enforce_materialized_shopper_identity(person, preview_identity, shopper)

	_grocery_register_materialized_person(person)

	if gs.soul_seed_engine != null and gs.soul_seed_engine.has_method("ensure_soul_seed"):
		gs.soul_seed_engine.ensure_soul_seed(person, {
			"source": "grocery_presence_shard_materialization",
			"role": "npc",
			"shard_id": shard_id,
			"preview_identity": preview_identity.duplicate(true),
			"cje": causal_reason.duplicate(true)
		})

	return person
func sanitize_grocery_identity_for_relationship_profile(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return { "success": false, "reason": "No person supplied."}

	var requested_store_id: String = str(context.get("store_id", "")).strip_edges()
	var shopper: Dictionary = _grocery_find_shopper_snapshot_for_actor(int(person.id), requested_store_id)

	if shopper.is_empty():
		return {
			"success": true,
			"changed": false,
			"person_id": int(person.id),
			"reason": "Person is not currently anchored as a grocery shopper."
		}

	shopper = _grocery_resolve_deferred_shopper_identity(shopper, {
		"store_id": str(context.get("store_id", shopper.get("store_id", ""))),
		"aisle_id": str(context.get("aisle_id", shopper.get("aisle_id", ""))),
		"source": "sanitize_grocery_identity_for_relationship_profile"
	})

	var preview_identity: Dictionary = shopper.get("preview_identity", {}) if typeof(shopper.get("preview_identity", {})) == TYPE_DICTIONARY else {}
	var identity_state: String = str(shopper.get("identity_state", "")).strip_edges().to_lower()
	var ambient_generated: bool = bool(shopper.get("ambient_generated", false))
	var should_lock_identity: bool = ambient_generated or not preview_identity.is_empty() or identity_state == "identity_preview"

	if not should_lock_identity:
		return {
			"success": true,
			"changed": false,
			"person_id": int(person.id),
			"reason": "Canonical shopper identity does not need grocery locking."
		}

	_grocery_enforce_materialized_shopper_identity(person, preview_identity, shopper)
	_grocery_update_shopper_identity_snapshot_from_person(person, shopper)

	return {
		"success": true,
		"changed": true,
		"person_id": int(person.id),
		"job": _grocery_person_profession(person),
		"reason": "Grocery shopper identity was locked before relationship profile render."
	}
func _grocery_update_shopper_identity_snapshot_from_person(person: Person, shopper: Dictionary = {}) -> void:
	if person == null:
		return

	var store_id: String = str(shopper.get("store_id", "")).strip_edges()
	if store_id == "":
		store_id = _grocery_find_store_id_for_shopper_id(int(person.id))
	if store_id == "":
		return

	var session: Dictionary = grocery_shopper_sessions_by_store_id.get(store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(store_id, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return

	var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
	var key: String = str(int(person.id))
	if not shoppers.has(key):
		return

	var row: Dictionary = shoppers.get(key, {}) if typeof(shoppers.get(key, {})) == TYPE_DICTIONARY else {}
	row ["name"] = _grocery_person_name(person)
	row ["profession"] = _grocery_person_profession(person)
	row ["materialized_person_id"] = int(person.id)
	row ["person_id"] = int(person.id)
	row ["identity_state"] = "materialized"
	row ["updated_at_ms"] = int(Time.get_ticks_msec())

	shoppers [key] = row
	session ["shoppers"] = shoppers
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_shopper_sessions_by_store_id [store_id] = session
func _grocery_enforce_materialized_shopper_identity(person: Person, preview_identity: Dictionary, shopper: Dictionary = {}) -> void:
	if person == null:
		return

	var store_id: String = str(shopper.get("store_id", "")).strip_edges()
	var seed_text: String = str(shopper.get("shard_id", person.id)).strip_edges()
	var preview_job: String = str(preview_identity.get("job", shopper.get("profession", ""))).strip_edges()

	if preview_job == "":
		preview_job = str(shopper.get("profession", "")).strip_edges()

	preview_job = _grocery_sanitize_public_job_text(preview_job, int(person.age), null, {
		"store_id": store_id,
		"seed_text": seed_text
	})

	if preview_job == "":
		preview_job = "Student" if int(person.age) < 18 else "Office Worker"

	person.job = preview_job

	if person.has_method("set_meta"):
		person.set_meta("grocery_identity_locked", true)
		person.set_meta("grocery_identity_locked_job", preview_job)
		person.set_meta("grocery_identity_locked_source", "deferred_shopper_materialization")
		person.set_meta("grocery_identity_locked_at_ms", int(Time.get_ticks_msec()))

	var preview_is_royal: bool = _grocery_job_text_is_royal(preview_job)
	if not preview_is_royal:
		person.is_royal = false
		person.is_ruler = false
		person.royal_title = ""
		person.succession_rank = -1

	_grocery_seed_public_income_for_person(person, {
		"store_id": store_id,
		"seed_text": seed_text
	})

func _grocery_materialized_shopper_age(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.18:
		return int(rng.randi_range(15, 17))
	return int(rng.randi_range(18, 84))


func _grocery_pick_materialized_shopper_job(rng: RandomNumberGenerator) -> String:
	var jobs: Array = []

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_job_pool"):
		jobs = gs.era_engine.get_job_pool()

	var clean_jobs: Array = []
	for raw_job in jobs:
		var job_text: String = str(raw_job).strip_edges()
		if job_text == "":
			continue
		if _grocery_job_text_is_invalid_public_job(job_text):
			continue
		if _grocery_job_text_is_royal(job_text):
			continue
		clean_jobs.append(job_text)

	if not clean_jobs.is_empty():
		return str(clean_jobs [int(rng.randi_range(0, clean_jobs.size() - 1))])

	var fallback_jobs: Array = _grocery_generated_professions()
	return str(fallback_jobs [int(rng.randi_range(0, fallback_jobs.size() - 1))])

func _grocery_attach_materialized_shopper_family(person: Person, rng: RandomNumberGenerator) -> void:
	if person == null or gs == null or gs.npc_factory == null:
		return
	if typeof(person.parents) == TYPE_ARRAY and not person.parents.is_empty():
		return
	if not gs.npc_factory.has_method("_create_parent"):
		return

	var family_last_name: String = str(person.last_name).strip_edges()
	if family_last_name == "":
		family_last_name = str(_grocery_generated_last_names() [int(rng.randi_range(0, _grocery_generated_last_names().size() - 1))])
		person.last_name = family_last_name

	var father: Person = gs.npc_factory._create_parent("Male", str(person.home_city), str(person.home_country))
	var mother: Person = gs.npc_factory._create_parent("Female", str(person.home_city), str(person.home_country))

	if father == null or mother == null:
		return

	if gs.npc_factory.has_method("align_immediate_family_stats_to_child"):
		gs.npc_factory.align_immediate_family_stats_to_child(person, father, mother)

	father.last_name = family_last_name
	mother.last_name = family_last_name
	father.partner = mother
	mother.partner = father
	father.marital_status = "Married"
	mother.marital_status = "Married"

	person.parents = [int(father.id), int(mother.id)]

	_grocery_register_materialized_person(father)
	_grocery_register_materialized_person(mother)

	if gs.npc_factory.has_method("ensure_parent_lineage"):
		gs.npc_factory.ensure_parent_lineage(mother, str(mother.last_name))
		gs.npc_factory.ensure_parent_lineage(father, str(father.last_name))


func _grocery_register_materialized_person(person: Person) -> void:
	if person == null or gs == null:
		return

	if gs.has_method("register_npc"):
		gs.register_npc(person)
		return

	if gs.has_method("get_npc_by_id") and gs.get_npc_by_id(int(person.id)) == null:
		gs.npcs.append(person)
		if gs.has_method("_rebuild_npc_index"):
			gs._rebuild_npc_index()


func _grocery_materialized_shopper_causal_reason(store_id: String, aisle_id: String, shopper: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()
	var clean_aisle_id: String = str(aisle_id).strip_edges()
	var shard_id: String = str(shopper.get("shard_id", "")).strip_edges()
	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|cje|%s|%s" % [
		shard_id,
		clean_store_id,
		clean_aisle_id
	])

	var why_options: Array = [
		"they live nearby and needed groceries.",
		"they were shopping for their household.",
		"they stopped in during a break from work.",
		"they came in for a few essentials and got distracted by the aisles.",
		"they were restocking food for the week.",
		"they followed a normal errand route through this part of town."
	]
	var why_here: String = str(why_options [int(rng.randi_range(0, why_options.size() - 1))])

	return {
		"status": "resolved_after_intent",
		"store_id": clean_store_id,
		"aisle_id": clean_aisle_id,
		"why_here": why_here,
		"why_now": "The player inspected this deferred public-space shard.",
		"what_before": str(shopper.get("shopping_state", "shopping")).replace("_", " "),
		"created_at_year": int(gs.year) if gs != null else 0,
		"created_at_ms": int(Time.get_ticks_msec())
	}
func _grocery_store_shopper_tick_ms() -> int:
	return 1150


func _grocery_store_target_shopper_count(store_id: String) -> int:
	var clean_store_id: String = str(store_id).strip_edges()
	var min_count: int = _grocery_store_min_shopper_count(clean_store_id)
	var max_count: int = _grocery_store_max_shopper_count(clean_store_id)
	var crowd_bucket_ms: float = 15000.0
	var crowd_bucket: int = int(floor(float(Time.get_ticks_msec()) / crowd_bucket_ms))
	var crowd_span: int = max(1, (max_count - min_count + 1))
	var swing: int = abs(int(hash("%s|crowd|%s" % [clean_store_id, str(crowd_bucket)]))) % crowd_span
	return clamp(min_count + swing, min_count, max_count)
func _grocery_backfill_public_arrival_wave(store_id: String, aisle_ids: Array, session: Dictionary, context: Dictionary = {}, reason: String = "") -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()
	if clean_store_id == "" or aisle_ids.is_empty():
		return session

	var now_ms: int = int(Time.get_ticks_msec())
	var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
	var departed_shopper_ids: Array = session.get("departed_shopper_ids", []) if typeof(session.get("departed_shopper_ids", [])) == TYPE_ARRAY else []
	var min_count: int = _grocery_store_min_shopper_count(clean_store_id)
	var max_count: int = _grocery_store_max_shopper_count(clean_store_id)
	var target_count: int = _grocery_store_target_shopper_count(clean_store_id)
	var next_arrival_wave_ms: int = int(session.get("next_arrival_wave_ms", 0))
	var arrival_due: bool = now_ms >= next_arrival_wave_ms
	var below_floor: bool = shoppers.size() < min_count
	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|arrival_wave|%s|%s|%s" % [
		clean_store_id,
		str(int(session.get("arrival_wave_index", 0))),
		str(int(floor(float(now_ms) / 1000.0))),
		reason
	])

	var desired_count: int = target_count
	if below_floor:
		desired_count = max(desired_count, min(max_count, min_count + int(rng.randi_range(1, 3))))
	elif arrival_due and shoppers.size() < max_count:
		desired_count = max(desired_count, min(max_count, shoppers.size() + _grocery_arrival_wave_size(clean_store_id, rng)))

	if not below_floor and not arrival_due and shoppers.size() >= desired_count:
		session ["shoppers"] = shoppers
		session ["departed_shopper_ids"] = departed_shopper_ids
		return session

	var spawn_attempts: int = 0
	var spawn_attempt_limit: int = max(80, desired_count + 12)
	while shoppers.size() < desired_count and spawn_attempts < spawn_attempt_limit:
		spawn_attempts += 1
		if not _grocery_spawn_ambient_shopper(clean_store_id, aisle_ids, shoppers, context, departed_shopper_ids, session):
			break

	if arrival_due or below_floor or next_arrival_wave_ms <= 0:
		session ["arrival_wave_index"] = int(session.get("arrival_wave_index", 0)) + 1
		session ["next_arrival_wave_ms"] = now_ms + _grocery_next_arrival_wave_delay_ms(clean_store_id, rng)

	session ["shoppers"] = shoppers
	session ["departed_shopper_ids"] = departed_shopper_ids
	session ["last_arrival_reason"] = reason
	session ["updated_at_ms"] = now_ms
	return session


func _grocery_arrival_wave_size(store_id: String, rng: RandomNumberGenerator) -> int:
	var clean_store_id: String = str(store_id).strip_edges()
	match clean_store_id:
		"basket_lane_market":
			return int(rng.randi_range(2, 6))
		"goldleaf_grocers":
			return int(rng.randi_range(1, 4))
		"nutripod_exchange":
			return int(rng.randi_range(1, 5))
		_:
			return int(rng.randi_range(1, 4))


func _grocery_next_arrival_wave_delay_ms(store_id: String, rng: RandomNumberGenerator) -> int:
	var clean_store_id: String = str(store_id).strip_edges()
	match clean_store_id:
		"basket_lane_market":
			return int(rng.randi_range(2400, 6800))
		"goldleaf_grocers":
			return int(rng.randi_range(3600, 9200))
		"nutripod_exchange":
			return int(rng.randi_range(3000, 7600))
		_:
			return int(rng.randi_range(3200, 8200))

func _grocery_initial_shopper_state(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.18:
		return "entering"
	if roll < 0.46:
		return "lingering"
	if roll < 0.86:
		return "actively_shopping"
	return "checkout_bound"


func _grocery_next_shopper_state(current_state: String, rng: RandomNumberGenerator) -> String:
	var clean_state: String = str(current_state).strip_edges().to_lower()
	var roll: float = rng.randf()

	match clean_state:
		"entering":
			if roll < 0.62:
				return "actively_shopping"
			if roll < 0.82:
				return "lingering"
			return "checkout_bound"
		"lingering":
			if roll < 0.48:
				return "actively_shopping"
			if roll < 0.82:
				return "lingering"
			return "checkout_bound"
		"actively_shopping":
			if roll < 0.66:
				return "actively_shopping"
			if roll < 0.84:
				return "lingering"
			return "checkout_bound"
		"checkout_bound":
			if roll < 0.74:
				return "checkout_bound"
			return "checking_out"
		"checking_out":
			return "checking_out"
		_:
			return _grocery_initial_shopper_state(rng)


func _grocery_tick_shopper_behavior(
	shopper: Dictionary,
	rng: RandomNumberGenerator,
	now_ms: int
) -> Dictionary:
	if shopper.is_empty():
		return shopper

	shopper = _grocery_normalize_shopper_cart_fields(
		shopper
	)

	shopper ["checkout_departure_ready"] = false

	var state: String = str(
		shopper.get(
			"shopping_state",
			"actively_shopping"
		)
	).strip_edges().to_lower()

	if state == "":
		state = "actively_shopping"

	if now_ms >= int(
		shopper.get(
			"next_behavior_shift_ms",
			0
		)
	):
		state = _grocery_next_shopper_state(
			state,
			rng
		)
		shopper ["shopping_state"] = state
		shopper ["next_behavior_shift_ms"] = (
			now_ms
			+ int(
				rng.randi_range(
					3200,
					12000
				)
			)
		)

	match state:
		"actively_shopping":
			if rng.randf() < 0.58:
				shopper = (
					_grocery_add_realtime_item_to_shopper_cart(
						shopper,
						rng,
						now_ms
					)
				)

		"checkout_bound":
			if (
				int(
					shopper.get(
						"cart_item_count",
						0
					)
				) <= 0
				or rng.randf() < 0.1
			):
				shopper = (
					_grocery_add_realtime_item_to_shopper_cart(
						shopper,
						rng,
						now_ms
					)
				)

		"checking_out":
			var checkout_started_ms: int = int(
				shopper.get(
					"checkout_started_ms",
					0
				)
			)

			if checkout_started_ms <= 0:
				checkout_started_ms = now_ms

				shopper ["checkout_started_ms"] = (
					checkout_started_ms
				)
				shopper ["checkout_complete_at_ms"] = (
					now_ms
					+ int(
						rng.randi_range(
							1600,
							4800
						)
					)
				)
				shopper ["checkout_payment_state"] = (
					"processing"
				)

			var checkout_complete_at_ms: int = int(
				shopper.get(
					"checkout_complete_at_ms",
					checkout_started_ms + 1600
				)
			)

			if now_ms >= checkout_complete_at_ms:
				shopper ["checkout_payment_state"] = "paid"
				shopper ["purchase_completed"] = true
				shopper ["purchase_completed_at_ms"] = now_ms
				shopper ["purchase_item_count"] = int(
					shopper.get(
						"cart_item_count",
						0
					)
				)
				shopper ["purchase_total"] = float(
					shopper.get(
						"cart_total",
						0.0
					)
				)
				shopper ["checkout_departure_ready"] = true

		"entering", "lingering":
			pass

	return shopper
func _grocery_normalize_shopper_cart_fields(shopper: Dictionary) -> Dictionary:
	if typeof(shopper.get("cart_items", [])) != TYPE_ARRAY:
		shopper ["cart_items"] = []

	if not shopper.has("cart_total"):
		shopper ["cart_total"] = 0.0

	if not shopper.has("cart_item_count"):
		shopper ["cart_item_count"] = 0

	return shopper


func _grocery_add_realtime_item_to_shopper_cart(shopper: Dictionary, rng: RandomNumberGenerator, now_ms: int) -> Dictionary:
	var store_id: String = str(shopper.get("store_id", "")).strip_edges()
	var aisle_id: String = str(shopper.get("aisle_id", "")).strip_edges()
	var item: Dictionary = _grocery_pick_realtime_shopper_item(store_id, aisle_id, rng)

	if item.is_empty():
		var fallback_amount: float = round(rng.randf_range(1.5, 18.75) * 100.0) / 100.0
		shopper ["cart_total"] = snapped(float(shopper.get("cart_total", 0.0)) + fallback_amount, 0.01)
		shopper ["cart_item_count"] = int(shopper.get("cart_item_count", 0)) + 1
		shopper ["last_cart_addition"] = {
			"name": "Something from the aisle",
			"price": fallback_amount,
			"quantity": 1,
			"added_at_ms": now_ms
		}
		shopper ["last_cart_addition_text"] = "+ Something from the aisle • $%.2f" % fallback_amount
		return shopper

	var price: float = snapped(float(item.get("price", 0.0)), 0.01)
	var quantity: int = 1
	if rng.randf() < 0.16:
		quantity = 2

	var cart_item: Dictionary = item.duplicate(true)
	cart_item ["quantity"] = quantity
	cart_item ["store_id"] = store_id
	cart_item ["aisle_id"] = aisle_id
	cart_item ["price"] = price
	cart_item ["purchase_price"] = price
	cart_item ["unit_price_paid"] = price
	cart_item ["price_after_tax"] = price
	cart_item ["tax_paid"] = 0.0
	cart_item ["value"] = price
	cart_item ["tax_exempt"] = true
	cart_item ["price_after_tax_locked"] = true
	cart_item ["source"] = "realtime_grocery_shopper_cart"

	var cart_items: Array = shopper.get("cart_items", []) if typeof(shopper.get("cart_items", [])) == TYPE_ARRAY else []
	var merged: bool = false

	for i in range(cart_items.size()):
		if typeof(cart_items [i]) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = cart_items [i]
		if str(existing.get("id", "")) == str(cart_item.get("id", "")):
			existing ["quantity"] = int(existing.get("quantity", 1)) + quantity
			cart_items [i] = existing
			merged = true
			break

	if not merged:
		cart_items.append(cart_item)

	var added_total: float = snapped(price * float(quantity), 0.01)
	shopper ["cart_items"] = cart_items
	shopper ["cart_total"] = snapped(float(shopper.get("cart_total", 0.0)) + added_total, 0.01)
	shopper ["cart_item_count"] = int(shopper.get("cart_item_count", 0)) + quantity
	shopper ["last_cart_addition"] = {
		"id": str(cart_item.get("id", "")),
		"name": str(cart_item.get("name", "grocery item")),
		"price": price,
		"quantity": quantity,
		"added_total": added_total,
		"added_at_ms": now_ms
	}
	shopper ["last_cart_addition_text"] = "+ %s%s • $%.2f" % [
		str(cart_item.get("name", "grocery item")),
		" x%d" % quantity if quantity > 1 else "",
		added_total
	]

	return shopper


func _grocery_pick_realtime_shopper_item(store_id: String, aisle_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var store: Dictionary = get_store(store_id)
	if store.is_empty():
		return {}

	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	if inventory.is_empty():
		return {}

	var aisle_items: Array = []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if aisle_id != "" and _grocery_aisle_id_for_item(item) != aisle_id:
			continue
		aisle_items.append(item)

	if aisle_items.is_empty():
		aisle_items = inventory.duplicate(true)

	if aisle_items.is_empty():
		return {}

	return (aisle_items [int(rng.randi_range(0, aisle_items.size() - 1))] as Dictionary).duplicate(true)
func _grocery_generated_ambient_shopper_snapshot(store_id: String, aisle_id: String, shoppers: Dictionary, departed_shopper_ids: Array, session: Dictionary, rng: RandomNumberGenerator, now_ms: int) -> Dictionary:
	var serial: int = int(session.get("generated_ambient_serial", 0)) + 1
	var store_offset: int = abs(int(hash(str(store_id)))) % 500000
	var generated_id: int = - int(1000000 + store_offset + serial)

	while shoppers.has(str(generated_id)) or departed_shopper_ids.has(generated_id):
		serial += 1
		generated_id = - int(1000000 + store_offset + serial)

	session ["generated_ambient_serial"] = serial

	var shard_id: String = "grocery_shard_%s_%s" % [
		str(store_id),
		str(serial)
	]
	var starter_total: float = 0.0
	var starter_count: int = 0
	var shopper_state: String = _grocery_initial_shopper_state(rng)

	if shopper_state == "actively_shopping":
		starter_total = round(rng.randf_range(3.25, 64.0) * 100.0) / 100.0
		starter_count = int(rng.randi_range(1, 8))
	elif shopper_state == "checkout_bound":
		starter_total = round(rng.randf_range(18.0, 180.0) * 100.0) / 100.0
		starter_count = int(rng.randi_range(4, 22))

	var shopper: Dictionary = {
		"person_id": generated_id,
		"shard_id": shard_id,
		"name": "",
		"profession": "",
		"identity_state": "deferred",
		"presence_kind": "population_shard",
		"simulation_depth": "presence_only",
		"aisle_id": aisle_id,
		"store_id": store_id,
		"cart_total": starter_total,
		"cart_item_count": starter_count,
		"shopping_state": shopper_state,
		"entered_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"linger_until_ms": now_ms + int(rng.randi_range(3800, 18000)),
		"next_behavior_shift_ms": now_ms + int(rng.randi_range(3200, 11000)),
		"left_store": false,
		"ambient_generated": true,
		"materialized_person_id": -1,
		"crbs": {
			"visibility_state": "visible",
			"interaction_state": "identity_preview",
			"execution_state": "deferred_life_until_inspection"
		},
		"cje": {
			"status": "pending_intent",
			"question": "Why is this shopper here?"
		},
		"rias": {
			"anchored": false,
			"anchor_id": "",
			"anchor_rule": "Anchor only if the player opens or switches to this shopper."
		}
	}

	return _grocery_resolve_deferred_shopper_identity(shopper, {
		"store_id": store_id,
		"aisle_id": aisle_id,
		"serial": serial
	})
func _grocery_resolve_deferred_shopper_identity(shopper: Dictionary, context: Dictionary = {}) -> Dictionary:
	if shopper.is_empty():
		return shopper

	var identity_state: String = str(shopper.get("identity_state", "")).strip_edges().to_lower()
	var ambient_generated: bool = bool(shopper.get("ambient_generated", false))
	if not ambient_generated or identity_state == "materialized":
		return shopper

	var preview_identity: Dictionary = shopper.get("preview_identity", {}) if typeof(shopper.get("preview_identity", {})) == TYPE_DICTIONARY else {}
	var display_name: String = str(shopper.get("name", "")).strip_edges()
	var profession: String = str(shopper.get("profession", "")).strip_edges()
	var needs_identity: bool = preview_identity.is_empty() or display_name == "" or display_name.begins_with("Shopper ") or profession == "" or profession == "Identity deferred"

	var shard_id: String = str(shopper.get("shard_id", "")).strip_edges()
	var store_id: String = str(context.get("store_id", shopper.get("store_id", ""))).strip_edges()
	var aisle_id: String = str(context.get("aisle_id", shopper.get("aisle_id", ""))).strip_edges()
	var seed_text: String = "%s|%s|%s|identity_preview" % [
		shard_id,
		store_id,
		aisle_id
	]
	var rng: RandomNumberGenerator = _grocery_shopper_rng(seed_text)

	if needs_identity:
		var gender_options: Array = ["Male", "Female"]
		var gender: String = str(gender_options [int(rng.randi_range(0, gender_options.size() - 1))])
		var first_names: Array = _grocery_generated_first_names(gender, context)
		var last_names: Array = _grocery_generated_last_names(context)

		var first_name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
		var last_name: String = str(last_names [int(rng.randi_range(0, last_names.size() - 1))])
		var age: int = _grocery_materialized_shopper_age(rng)
		if age < 15:
			age = int(rng.randi_range(15, 17))

		var job: String = "Student" if age < 18 else _grocery_sanitize_public_job_text("", age, rng, {
			"store_id": store_id,
			"aisle_id": aisle_id,
			"seed_text": seed_text
		})

		preview_identity = {
			"first_name": first_name,
			"last_name": last_name,
			"gender": gender,
			"age": age,
			"job": job,
			"identity_resolution": "name_job_age_preview_only",
		}
	else:
		var preview_age: int = int(preview_identity.get("age", 18))
		var preview_job: String = _grocery_sanitize_public_job_text(str(preview_identity.get("job", profession)), preview_age, rng, {
			"store_id": store_id,
			"aisle_id": aisle_id,
			"seed_text": seed_text
		})
		preview_identity ["job"] = preview_job

	display_name = ("%s %s" % [
		str(preview_identity.get("first_name", "")),
		str(preview_identity.get("last_name", ""))
	]).strip_edges()
	profession = str(preview_identity.get("job", "Between jobs")).strip_edges()

	if display_name == "":
		display_name = "Unknown shopper"
	if profession == "":
		profession = "Between jobs"

	var crbs: Dictionary = shopper.get("crbs", {}) if typeof(shopper.get("crbs", {})) == TYPE_DICTIONARY else {}
	crbs ["visibility_state"] = "visible"
	crbs ["interaction_state"] = "identity_preview"
	crbs ["execution_state"] = "deferred_life_until_inspection"

	shopper ["name"] = display_name
	shopper ["profession"] = profession
	shopper ["preview_identity"] = preview_identity
	shopper ["identity_state"] = "identity_preview"
	shopper ["simulation_depth"] = "identity_only"
	shopper ["crbs"] = crbs

	return shopper
func _grocery_generated_first_names(gender: String = "", context: Dictionary = {}) -> Array:
	var era_bucket: String = _grocery_name_era_bucket(context)
	var clean_gender: String = str(gender).strip_edges().to_lower()

	var modern_male: Array = [
		"Marcus", "Ethan", "Sergio", "Carl", "Morgan", "Lucius", "Jordan", "Zavier", "Kaden", "Liam",
		"Avery", "Noah", "Elijah", "Isaiah", "Micah", "Julian", "Adrian", "Malachi", "Xavier", "Miles",
		"Dominic", "Jalen", "Damian", "Roman", "Nolan", "Caleb", "Levi", "Josiah", "Nathan", "Aaron",
		"Cameron", "Bryson", "Tyrese", "Darius", "Andre", "Malik", "Jaylen", "Terrence", "Devin", "Tristan",
		"Rylan", "Kyrie", "Emmett", "Desmond", "Phoenix", "Asher", "Silas", "Ezra", "Theo", "Grayson",
		"Blake", "Wesley", "Donovan", "Zion", "Kareem", "Omari", "Joaquin", "Matteo", "Soren", "Bennett",
		"Cole", "Ronan", "Kellan", "Dante", "Cam", "Dorian", "Tobias", "Marcellus", "Nasir", "Elian"
	]
	var modern_female: Array = [
		"Maya", "Genevieve", "Gabby", "Molly", "Taylor", "Amber", "Victoria", "Brigitte", "Leah", "Sarai",
		"Amina", "Chloe", "Jada", "Selene", "Naomi", "Zaria", "Amara", "Jasmine", "Kiara", "Layla",
		"Aria", "Arielle", "Nyla", "Imani", "Talia", "Camila", "Elena", "Bianca", "Monroe", "Sloane",
		"Aubrey", "Mckenna", "Riley", "Jocelyn", "Avery", "Mila", "Aaliyah", "Destiny", "Brielle", "Teagan",
		"Autumn", "Kennedy", "Sabrina", "Valeria", "Anaya", "Zoe", "Luna", "Isla", "Noelle", "Sasha",
		"Serena", "Nia", "Renee", "Skye", "Alina", "Malia", "Tiana", "Samara", "Kehlani", "Maren"
	]
	var future_male: Array = [
		"Orion", "Atlas", "Cassian", "Neo", "Caius", "Zeno", "Kairo", "Axton", "Lazaro", "Sion",
		"Veyron", "Makai", "Draven", "Zephyr", "Cobalt", "Niko", "Aurex", "Koda", "Talon", "Cyrus",
		"Evren", "Sol", "Lucan", "Ryker", "Onyx", "Maddox", "Jett", "Arius", "Cosmo", "Riven",
		"Vale", "Kael", "Zenith", "Aero", "Bastian", "Miro", "Sage", "Tavian", "Cruz", "Kairox"
	]
	var future_female: Array = [
		"Nova", "Lyra", "Vega", "Astra", "Zora", "Nyx", "Seren", "Elara", "Vesper", "Solara",
		"Xyla", "Aven", "Cyra", "Lumi", "Aurelia", "Nixie", "Kaira", "Sable", "Mira", "Calypso",
		"Azura", "Zinnia", "Halo", "Artemis", "Evolet", "Sora", "Lux", "Celeste", "Veda", "Indigo",
		"Echo", "Thalia", "Rhea", "Soleil", "Navi", "Zadie", "Ariya", "Saphira", "Maelle", "Nyra"
	]

	if era_bucket == "future":
		if clean_gender == "male":
			return future_male
		if clean_gender == "female":
			return future_female
		return future_male + future_female

	if clean_gender == "male":
		return modern_male
	if clean_gender == "female":
		return modern_female
	return modern_male + modern_female


func _grocery_generated_last_names(context: Dictionary = {}) -> Array:
	var era_bucket: String = _grocery_name_era_bucket(context)

	var modern_last: Array = [
		"Morgan", "Brooks", "Ellis", "Hayes", "Cole", "Porter", "Stone", "Reed", "Cross", "Banks",
		"Bell", "Wells", "Price", "Lane", "Monroe", "Vale", "Bennett", "Carter", "Holland", "Knight",
		"West", "Summers", "Hale", "Warren", "Mason", "Fields", "Grant", "Foster", "Parker", "Wright",
		"Collins", "Bailey", "Sullivan", "Ramirez", "Thompson", "Hughes", "Mitchell", "Sanders", "Reyes", "Owens",
		"Washington", "Coleman", "Jenkins", "Murray", "Lawson", "Kim", "Patel", "Nguyen", "Garcia", "Williams"
	]
	var future_last: Array = [
		"Starling", "Voss", "Aureon", "Nightsky", "Solaris", "Vant", "Kade", "Nova", "Holloway", "Crest",
		"Arc", "Cipher", "Quill", "Rift", "Vale", "Drift", "Stonewake", "Moonwell", "Ashborne", "Brightline",
		"Cloud", "Ferro", "Ion", "Lumen", "Skyward", "Vireo", "Northstar", "Glass", "Helix", "Orbit",
		"Prism", "Sable", "Zen", "Aster", "Cobalt", "Rune", "Dawn", "Ever", "Pulse", "Vega"
	]

	if era_bucket == "future":
		return future_last

	return modern_last


func _grocery_name_era_bucket(context: Dictionary = {}) -> String:
	var era_text: String = str(context.get("era", context.get("era_name", context.get("era_key", "")))).strip_edges().to_lower()

	if era_text == "" and gs != null:
		era_text = str(gs.era).strip_edges().to_lower()

	if era_text.find("future") >= 0 or era_text.find("cyber") >= 0 or era_text.find("space") >= 0:
		return "future"

	if gs != null and int(gs.year) >= 2050:
		return "future"

	return "modern"


func _grocery_generated_professions() -> Array:
	return [
		"Teacher", "Nurse", "Soldier", "Cashier", "Mechanic", "Student", "Chef",
		"Security Guard", "Streamer", "Office Worker", "Artist", "Delivery Driver",
		"Engineer", "Personal Trainer", "Entrepreneur", "Retail Manager",
		"Software Developer", "Paramedic", "Construction Worker", "Accountant",
		"Barber", "Stylist", "Bus Driver", "Warehouse Worker", "Dental Assistant"
	]
func _grocery_job_text_is_royal(job_text: String) -> bool:
	var lower_job: String = str(job_text).strip_edges().to_lower()
	if lower_job == "":
		return false

	var royal_terms: Array = [
		"king",
		"queen",
		"prince",
		"princess",
		"duke",
		"duchess",
		"emperor",
		"empress",
		"ruler",
		"royal"
	]

	for raw_term in royal_terms:
		if lower_job.find(str(raw_term)) >= 0:
			return true

	return false


func _grocery_job_text_is_invalid_public_job(job_text: String) -> bool:
	var lower_job: String = str(job_text).strip_edges().to_lower()
	return lower_job == "" or lower_job == "parent" or lower_job == "mother" or lower_job == "father" or lower_job == "guardian"


func _grocery_store_allows_royalty_shopper(store_id: String, seed_text: String = "") -> bool:
	var clean_store_id: String = str(store_id).strip_edges()
	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|royalty_store_roll|%s|%d" % [
		clean_store_id,
		str(seed_text),
		int(gs.year) if gs != null else 0
	])

	var chance: float = 0.0025
	if clean_store_id == "goldleaf_grocers":
		chance = 0.0125
	elif clean_store_id == "nutripod_exchange":
		chance = 0.004

	return rng.randf() <= chance


func _grocery_sanitize_public_job_text(job_text: String, age: int = 18, rng: RandomNumberGenerator = null, context: Dictionary = {}) -> String:
	var clean_job: String = str(job_text).strip_edges()
	var store_id: String = str(context.get("store_id", "")).strip_edges()
	var seed_text: String = str(context.get("seed_text", clean_job)).strip_edges()

	if int(age) < 18:
		return "Student"

	if _grocery_job_text_is_invalid_public_job(clean_job):
		clean_job = ""

	if _grocery_job_text_is_royal(clean_job) and not _grocery_store_allows_royalty_shopper(store_id, seed_text):
		clean_job = ""

	if clean_job != "":
		return clean_job

	var local_rng: RandomNumberGenerator = rng
	if local_rng == null:
		local_rng = _grocery_shopper_rng("%s|fallback_public_job|%s|%d" % [
			store_id,
			seed_text,
			int(age)
		])

	var fallback_jobs: Array = _grocery_generated_professions()
	if fallback_jobs.is_empty():
		return "Office Worker"

	var fallback: String = str(fallback_jobs [int(local_rng.randi_range(0, fallback_jobs.size() - 1))]).strip_edges()
	if fallback == "" or _grocery_job_text_is_invalid_public_job(fallback) or _grocery_job_text_is_royal(fallback):
		return "Office Worker"

	return fallback


func _grocery_seed_public_income_for_person(person: Person, context: Dictionary = {}) -> void:
	if person == null:
		return
	if int(person.age) < 16:
		return
	if float(person.income) > 0.0:
		return

	var job_text: String = _grocery_sanitize_public_job_text(str(person.job), int(person.age), null, context)
	var lower_job: String = job_text.to_lower()
	var base_income: float = 36000.0

	if lower_job.find("teacher") >= 0:
		base_income = 52000.0
	elif lower_job.find("nurse") >= 0:
		base_income = 76000.0
	elif lower_job.find("soldier") >= 0:
		base_income = 42000.0
	elif lower_job.find("cashier") >= 0:
		base_income = 28500.0
	elif lower_job.find("mechanic") >= 0:
		base_income = 47000.0
	elif lower_job.find("chef") >= 0:
		base_income = 44000.0
	elif lower_job.find("security") >= 0:
		base_income = 34000.0
	elif lower_job.find("streamer") >= 0:
		base_income = 41000.0
	elif lower_job.find("office") >= 0:
		base_income = 43000.0
	elif lower_job.find("artist") >= 0:
		base_income = 39000.0
	elif lower_job.find("delivery") >= 0:
		base_income = 36000.0
	elif lower_job.find("engineer") >= 0 or lower_job.find("software") >= 0:
		base_income = 92000.0
	elif lower_job.find("trainer") >= 0:
		base_income = 48000.0
	elif lower_job.find("entrepreneur") >= 0:
		base_income = 68000.0
	elif lower_job.find("manager") >= 0:
		base_income = 56000.0
	elif lower_job.find("paramedic") >= 0:
		base_income = 45000.0
	elif lower_job.find("construction") >= 0:
		base_income = 49000.0
	elif lower_job.find("accountant") >= 0:
		base_income = 64000.0
	elif lower_job.find("barber") >= 0 or lower_job.find("stylist") >= 0:
		base_income = 38000.0
	elif lower_job.find("driver") >= 0:
		base_income = 39000.0
	elif lower_job.find("warehouse") >= 0:
		base_income = 37000.0
	elif lower_job.find("dental") >= 0:
		base_income = 43000.0

	var class_text: String = str(person.social_class).strip_edges().to_lower()
	if class_text.find("upper") >= 0 or class_text.find("elite") >= 0 or class_text.find("noble") >= 0:
		base_income *= 1.75
	elif class_text.find("middle") >= 0:
		base_income *= 1.15
	elif class_text.find("poor") >= 0 or class_text.find("lower") >= 0:
		base_income *= 0.72

	var rng: RandomNumberGenerator = _grocery_shopper_rng("%d|%s|income_seed" % [
		int(person.id),
		job_text
	])
	var variance: float = rng.randf_range(0.86, 1.18)
	person.income = int(round(base_income * variance))

	if float(person.bank_balance) <= 0.0:
		person.bank_balance = int(round(float(person.income) * rng.randf_range(0.12, 0.55)))
func _grocery_shopper_rng(seed_text: String) -> RandomNumberGenerator:
	var rng:= RandomNumberGenerator.new()
	var seed_value: int = int(hash(str(seed_text)))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1
	rng.seed = seed_value
	return rng


func _grocery_spawn_ambient_shopper(store_id: String, aisle_ids: Array, shoppers: Dictionary, context: Dictionary = {}, departed_shopper_ids: Array = [], session: Dictionary = {}) -> bool:
	if aisle_ids.is_empty():
		return false

	var candidate: Person = _grocery_pick_ambient_shopper(store_id, shoppers, context, departed_shopper_ids)
	var now_ms: int = int(Time.get_ticks_msec())

	if candidate == null:
		var generated_rng: RandomNumberGenerator = _grocery_shopper_rng("%s|generated_spawn|%s|%s" % [
			store_id,
			str(now_ms),
			str(int(session.get("generated_ambient_serial", 0)))
		])
		var generated_aisle_id: String = _grocery_pick_spawn_aisle(store_id, aisle_ids, shoppers, generated_rng)
		var generated_shopper: Dictionary = _grocery_generated_ambient_shopper_snapshot(store_id, generated_aisle_id, shoppers, departed_shopper_ids, session, generated_rng, now_ms)
		if generated_shopper.is_empty():
			return false
		shoppers [str(int(generated_shopper.get("person_id", -1)))] = generated_shopper
		return true

	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|%s|spawn|%s" % [
		store_id,
		str(candidate.id),
		str(now_ms)
	])
	var aisle_id: String = _grocery_pick_spawn_aisle(store_id, aisle_ids, shoppers, rng)
	var starter_total: float = round(rng.randf_range(2.5, 38.0) * 100.0) / 100.0
	var starter_count: int = int(rng.randi_range(1, 4))

	shoppers [str(int(candidate.id))] = {
		"person_id": int(candidate.id),
		"shard_id": "",
		"name": _grocery_person_name(candidate),
		"profession": _grocery_person_profession(candidate),
		"identity_state": "materialized",
		"presence_kind": "world_npc",
		"aisle_id": aisle_id,
		"store_id": store_id,
		"cart_total": starter_total,
		"cart_item_count": starter_count,
		"shopping_state": _grocery_initial_shopper_state(rng),
		"entered_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"linger_until_ms": now_ms + int(rng.randi_range(2800, 11000)),
		"next_behavior_shift_ms": now_ms + int(rng.randi_range(2600, 9200)),
		"left_store": false,
		"ambient_generated": false,
		"materialized_person_id": int(candidate.id),
		"crbs": {
			"visibility_state": "visible",
			"interaction_state": "live",
			"execution_state": "complete"
		},
		"cje": {
			"status": "pre_existing_world_npc",
			"question": ""
		},
		"rias": {
			"anchored": true,
			"anchor_id": "npc_%d" % int(candidate.id),
			"anchor_rule": "Already part of canonical world population."
		}
	}

	return true


func _grocery_pick_ambient_shopper(store_id: String, shoppers: Dictionary, _context: Dictionary = {}, departed_shopper_ids: Array = []) -> Person:
	if gs == null:
		return null

	var common_candidates: Array = []
	var rare_royalty_candidates: Array = []

	for raw_person in gs.npcs:
		if raw_person == null or not (raw_person is Person):
			continue

		var person: Person = raw_person as Person

		if gs.player != null and int(person.id) == int(gs.player.id):
			continue

		if not bool(person.alive):
			continue

		if shoppers.has(str(int(person.id))):
			continue

		if departed_shopper_ids.has(int(person.id)):
			continue

		if int(person.age) < 15 and not _grocery_person_has_adult_companion_in_shopper_session(person, shoppers):
			continue

		var person_job: String = str(person.job).strip_edges()
		var person_is_royalty: bool = bool(person.is_royal) or bool(person.is_ruler) or str(person.royal_title).strip_edges() != "" or _grocery_job_text_is_royal(person_job)

		if person_is_royalty:
			rare_royalty_candidates.append(person)
			continue

		var clean_job: String = _grocery_sanitize_public_job_text(person_job, int(person.age), null, {
			"store_id": store_id,
			"seed_text": "canonical_%d" % int(person.id)
		})
		if clean_job != "" and clean_job != person_job:
			person.job = clean_job

		_grocery_seed_public_income_for_person(person, {
			"store_id": store_id,
			"seed_text": "canonical_%d" % int(person.id)
		})

		common_candidates.append(person)

	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|pick|%s|%s|%d" % [
		store_id,
		str(common_candidates.size()),
		str(rare_royalty_candidates.size()),
		int(Time.get_ticks_msec())
	])

	if not rare_royalty_candidates.is_empty() and _grocery_store_allows_royalty_shopper(store_id, "canonical_royalty_pick"):
		return rare_royalty_candidates [int(rng.randi_range(0, rare_royalty_candidates.size() - 1))]

	if common_candidates.is_empty():
		return null

	return common_candidates [int(rng.randi_range(0, common_candidates.size() - 1))]
func _grocery_person_has_adult_companion_in_shopper_session(person: Person, shoppers: Dictionary) -> bool:
	if person == null:
		return false

	var possible_adult_ids: Array = []

	if typeof(person.parents) == TYPE_ARRAY:
		for raw_parent_id in person.parents:
			var parent_id: int = int(raw_parent_id)
			if parent_id > 0 and not possible_adult_ids.has(parent_id):
				possible_adult_ids.append(parent_id)

	for raw_adult_id in possible_adult_ids:
		var adult_id: int = int(raw_adult_id)
		if not shoppers.has(str(adult_id)):
			continue

		var adult_person: Person = gs.get_npc_by_id(adult_id) if gs != null and gs.has_method("get_npc_by_id") else null
		if adult_person != null and bool(adult_person.alive) and int(adult_person.age) >= 18:
			return true

	return false


func _grocery_shopper_snapshot_age(shopper: Dictionary) -> int:
	if shopper.is_empty():
		return -1

	var preview_identity: Dictionary = shopper.get("preview_identity", {}) if typeof(shopper.get("preview_identity", {})) == TYPE_DICTIONARY else {}
	var preview_age: int = int(preview_identity.get("age", shopper.get("age", -1)))
	if preview_age > 0:
		return preview_age

	var person_id: int = int(shopper.get("materialized_person_id", shopper.get("person_id", -1)))
	if person_id > 0 and gs != null and gs.has_method("get_npc_by_id"):
		var person: Person = gs.get_npc_by_id(person_id)
		if person != null:
			return int(person.age)

	return -1


func _grocery_shopper_snapshot_has_adult_companion(shopper: Dictionary, shoppers: Dictionary) -> bool:
	if shopper.is_empty():
		return false

	var adult_companion_id: int = int(shopper.get("adult_companion_id", -1))
	if adult_companion_id > 0 and shoppers.has(str(adult_companion_id)):
		var companion_snapshot: Dictionary = shoppers.get(str(adult_companion_id), {}) if typeof(shoppers.get(str(adult_companion_id), {})) == TYPE_DICTIONARY else {}
		if _grocery_shopper_snapshot_age(companion_snapshot) >= 18:
			return true

	var person_id: int = int(shopper.get("materialized_person_id", shopper.get("person_id", -1)))
	if person_id <= 0 or gs == null or not gs.has_method("get_npc_by_id"):
		return false

	var person: Person = gs.get_npc_by_id(person_id)
	if person == null:
		return false

	return _grocery_person_has_adult_companion_in_shopper_session(person, shoppers)


func _grocery_shopper_snapshot_is_unaccompanied_under_15(shopper: Dictionary, shoppers: Dictionary) -> bool:
	var age: int = _grocery_shopper_snapshot_age(shopper)
	if age < 0:
		return false
	if age >= 15:
		return false
	return not _grocery_shopper_snapshot_has_adult_companion(shopper, shoppers)


func _grocery_person_name(person: Person) -> String:
	if person == null:
		return "Unknown shopper"

	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Unknown shopper"

	return full_name
func _grocery_person_profession(person: Person) -> String:
	if person == null:
		return "Between jobs"

	if person.has_method("has_meta") and person.has_meta("grocery_identity_locked_job"):
		var locked_job: String = str(person.get_meta("grocery_identity_locked_job")).strip_edges()
		if locked_job != "":
			return locked_job

	var job_text: String = str(person.job).strip_edges()
	if job_text != "":
		return job_text

	var fame_job_text: String = str(person.fame_job).strip_edges()
	if fame_job_text != "":
		return fame_job_text

	var royal_title_text: String = str(person.royal_title).strip_edges()
	if royal_title_text != "":
		return royal_title_text

	if bool(person.is_royal):
		return "Royal"

	if int(person.age) < 18:
		return "Student"

	return "Between jobs"

func _grocery_store_min_shopper_count(store_id: String) -> int:
	match str(store_id).strip_edges():
		"basket_lane_market":
			return 82
		"goldleaf_grocers":
			return 34
		"nutripod_exchange":
			return 46
		_:
			return 28


func _grocery_store_max_shopper_count(store_id: String) -> int:
	match str(store_id).strip_edges():
		"basket_lane_market":
			return 220
		"goldleaf_grocers":
			return 96
		"nutripod_exchange":
			return 140
		_:
			return 72


func _grocery_pick_spawn_aisle(_store_id: String, aisle_ids: Array, shoppers: Dictionary, rng: RandomNumberGenerator) -> String:
	if aisle_ids.is_empty():
		return ""

	var occupied_aisles: Array = []
	for raw_id in shoppers.keys():
		var shopper: Dictionary = shoppers.get(raw_id, {}) if typeof(shoppers.get(raw_id, {})) == TYPE_DICTIONARY else {}
		var shopper_aisle_id: String = str(shopper.get("aisle_id", "")).strip_edges()
		if shopper_aisle_id != "" and aisle_ids.has(shopper_aisle_id):
			occupied_aisles.append(shopper_aisle_id)

	if not occupied_aisles.is_empty() and rng.randf() < 0.42:
		return str(occupied_aisles [int(rng.randi_range(0, occupied_aisles.size() - 1))])

	return str(aisle_ids [int(rng.randi_range(0, aisle_ids.size() - 1))])


func get_grocery_store_presence_summary(
		store_id: String,
		_context: Dictionary = {}
) -> Dictionary:
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {
			"store_id": "",
			"people_in_store": 0,
			"shopper_count": 0,
			"player_count": 0,
			"cashier_count": 0,
			"projection_only": true
		}

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)
	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var worker_shift_raw: Variant = (
		grocery_store_worker_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var worker_shift: Dictionary = (
		worker_shift_raw as Dictionary
		if typeof(worker_shift_raw) == TYPE_DICTIONARY
		else {}
	)
	var active_cashier_raw: Variant = worker_shift.get(
		"active_cashier",
		{}
	)
	var active_cashier: Dictionary = (
		active_cashier_raw as Dictionary
		if typeof(active_cashier_raw) == TYPE_DICTIONARY
		else {}
	)
	var player_count: int = (
		1
		if bool(
			session.get(
				"active",
				false
			)
		)
		else 0
	)
	var cashier_count: int = (
		1
		if not active_cashier.is_empty()
		else 0
	)
	var shopper_count: int = shoppers.size()

	return {
		"store_id": clean_store_id,
		"people_in_store": (
			shopper_count
			+ player_count
			+ cashier_count
		),
		"shopper_count": shopper_count,
		"player_count": player_count,
		"cashier_count": cashier_count,
		"active_cashier": (
			active_cashier.duplicate(false)
		),
		"updated_at_ms": int(
			session.get(
				"updated_at_ms",
				0
			)
		),
		"arrival_wave_index": int(
			session.get(
				"arrival_wave_index",
				0
			)
		),
		"next_arrival_wave_ms": int(
			session.get(
				"next_arrival_wave_ms",
				0
			)
		),
		"projection_only": true,
	}
func _grocery_realtime_lens_patch_contract(
	store_id: String,
	aisle_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_store_id: String = str(
		store_id
	).strip_edges()
	var clean_aisle_id: String = str(
		aisle_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var actor: Person = _actor_from_context(
		context
	)
	var presence_summary: Dictionary = (
		get_grocery_store_presence_summary(
			clean_store_id,
			context
		)
	)
	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)
	var counts_raw: Variant = session.get(
		"aisle_population_counts",
		{}
	)
	var aisle_population_counts: Dictionary = (
		counts_raw as Dictionary
		if typeof(counts_raw) == TYPE_DICTIONARY
		else {}
	)
	var aisle_shopper_count: int = int(
		aisle_population_counts.get(
			clean_aisle_id,
			0
		)
	)

	var cart: Dictionary = {}

	if actor != null:
		var cart_raw: Variant = (
			grocery_carts_by_actor_id.get(
				str(int(actor.id)),
				{}
			)
		)

		if typeof(cart_raw) == TYPE_DICTIONARY:
			cart = (
				cart_raw as Dictionary
			).duplicate(false)

	var cart_item_count: int = 0
	var cart_total: float = 0.0

	if not cart.is_empty():
		cart_item_count = (
			_grocery_cart_item_count(
				cart
			)
		)
		cart_total = float(
			_grocery_cart_price_breakdown(
				cart
			).get(
				"total",
				0.0
			)
		)

	var aisle_display_name: String = ""

	if clean_aisle_id != "":
		aisle_display_name = (
			_grocery_aisle_label(
				clean_aisle_id
			).strip_edges()
		)

	return {
		"schema": "eralife.grocery.realtime_lens_patch",
		"version": GROCERY_VERSION,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"store_id": clean_store_id,
		"aisle_id": clean_aisle_id,
		"aisle_display_name": aisle_display_name,
		"people_in_store": int(
			presence_summary.get(
				"people_in_store",
				0
			)
		),
		"store_shopper_count": int(
			presence_summary.get(
				"shopper_count",
				0
			)
		),
		"aisle_shopper_count": aisle_shopper_count,
		"cart_item_count": cart_item_count,
		"cart_total": cart_total,
		"cart_has_items": cart_item_count > 0,
		"completed_ambient_purchase_count": int(
			session.get(
				"completed_purchase_count",
				0
			)
		),
		"goldleaf_premium_active": (
			actor_has_goldleaf_premium(
				actor
			)
			if actor != null
			else false
		),
		"projection_only": true,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _ensure_grocery_store_worker_shift(
	store_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var shift_key: String = "%s|%s|%s" % [
		clean_store_id,
		str(
			gs.year
			if gs != null
			else 0
		),
		str(
			context.get(
				"worker_shift_seed",
				"daily"
			)
		)
	]
	var existing_raw: Variant = (
		grocery_store_worker_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)

	if typeof(existing_raw) == TYPE_DICTIONARY:
		var existing: Dictionary = (
			existing_raw as Dictionary
		)

		if (
			not existing.is_empty()
			and str(
				existing.get(
					"shift_key",
					""
				)
			) == shift_key
		):
			return existing.duplicate(false)

	var fallback_names: Array = (
		_grocery_fallback_worker_names(
			clean_store_id
		)
	)
	var workers: Array = []

	for raw_name in fallback_names:
		if workers.size() >= 5:
			break

		var worker_name: String = str(
			raw_name
		).strip_edges()

		if worker_name == "":
			continue

		workers.append({
			"person_id": -1,
			"name": worker_name,
			"first_name": worker_name.get_slice(
				" ",
				0
			),
			"profession": "Grocery Worker",
			"role": "cashier",
			"identity_state": "resident_shift_contract",
		})

	while workers.size() < 5:
		var worker_number: int = workers.size() + 1

		workers.append({
			"person_id": -1,
			"name": "Store Worker %d" % worker_number,
			"first_name": "Worker",
			"profession": "Grocery Worker",
			"role": "cashier",
			"identity_state": "resident_shift_contract",
		})

	var manager: Dictionary = (
		workers [0] as Dictionary
	).duplicate(false)

	manager ["role"] = "manager"
	manager ["profession"] = "Store Manager"

	var cashiers: Array = []

	for i in range(
		1,
		workers.size()
	):
		var worker: Dictionary = (
			workers [i] as Dictionary
		).duplicate(false)

		worker ["role"] = "cashier"
		worker ["profession"] = "Cashier"
		cashiers.append(worker)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var shift: Dictionary = {
		"store_id": clean_store_id,
		"shift_key": shift_key,
		"manager": manager,
		"cashiers": cashiers,
		"checkout_counter": -1,
		"active_cashier": (
			cashiers [0] as Dictionary
		).duplicate(false),
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"world_population_scan_performed": false,
	}

	grocery_store_worker_sessions_by_store_id [
		clean_store_id
	] = shift

	EraLog.truth(
		(
			"ERALIFE_GROCERY_WORKER_SHIFT_TRUTH"
			+ "|store_id=%s"
			+ "|worker_count=%d"
			+ "|world_population_scan=false"
			+ "|constant_time=true"
			+ "|at_ms=%d"
		)
		% [
			clean_store_id,
			workers.size(),
			now_ms
		]
	)

	return shift.duplicate(false)
func _grocery_spawn_resident_shopper_quantum(
	store_id: String,
	_player_aisle_id: String,
	session: Dictionary
) -> bool:
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return false

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var next_arrival_ms: int = int(
		session.get(
			"next_resident_arrival_ms",
			0
		)
	)

	if now_ms < next_arrival_ms:
		return false

	var aisle_ids_raw: Variant = session.get(
		"aisle_ids",
		[]
	)
	var aisle_ids: Array = (
		aisle_ids_raw as Array
		if typeof(aisle_ids_raw) == TYPE_ARRAY
		else aisle_ids_for_store(
			clean_store_id
		)
	)

	if aisle_ids.is_empty():
		return false

	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)
	var departed_raw: Variant = session.get(
		"departed_shopper_ids",
		[]
	)
	var departed_shopper_ids: Array = (
		departed_raw as Array
		if typeof(departed_raw) == TYPE_ARRAY
		else []
	)
	var serial: int = int(
		session.get(
			"generated_ambient_serial",
			0
		)
	)
	var target_count: int = (
		_grocery_store_target_shopper_count(
			clean_store_id
		)
	)
	var minimum_count: int = (
		_grocery_store_min_shopper_count(
			clean_store_id
		)
	)

	if shoppers.size() >= target_count:
		return false

	var population_gap: int = maxi(
		0,
		target_count - shoppers.size()
	)
	var rng: RandomNumberGenerator = _grocery_shopper_rng(
		"%s|resident_quantum|%d|%d"
		% [
			clean_store_id,
			serial,
			now_ms
		]
	)




	var spawn_index: int = int(
		rng.randi_range(
			0,
			aisle_ids.size() - 1
		)
	)
	var spawn_aisle_id: String = str(
		aisle_ids [
			spawn_index
		]
	).strip_edges()

	if spawn_aisle_id == "":
		return false

	var generated_shopper: Dictionary = (
		_grocery_generated_ambient_shopper_snapshot(
			clean_store_id,
			spawn_aisle_id,
			shoppers,
			departed_shopper_ids,
			session,
			rng,
			now_ms
		)
	)

	if generated_shopper.is_empty():
		session ["next_resident_arrival_ms"] = (
			now_ms + 500
		)
		return false

	var shopper_key: String = str(
		generated_shopper.get(
			"person_id",
			""
		)
	)

	if shopper_key == "":
		shopper_key = str(
			generated_shopper.get(
				"shard_id",
				"generated_%d" % serial
			)
		)

	shoppers [shopper_key] = generated_shopper

	var counts_raw: Variant = session.get(
		"aisle_population_counts",
		{}
	)
	var aisle_population_counts: Dictionary = (
		counts_raw as Dictionary
		if typeof(counts_raw) == TYPE_DICTIONARY
		else {}
	)
	aisle_population_counts [
		spawn_aisle_id
	] = int(
		aisle_population_counts.get(
			spawn_aisle_id,
			0
		)
	) + 1

	var ids_raw: Variant = session.get(
		"aisle_shopper_ids",
		{}
	)
	var aisle_shopper_ids: Dictionary = (
		ids_raw as Dictionary
		if typeof(ids_raw) == TYPE_DICTIONARY
		else {}
	)
	var aisle_residents_raw: Variant = (
		aisle_shopper_ids.get(
			spawn_aisle_id,
			[]
		)
	)
	var aisle_residents: Array = (
		aisle_residents_raw as Array
		if typeof(aisle_residents_raw) == TYPE_ARRAY
		else []
	)

	if shopper_key not in aisle_residents:
		aisle_residents.append(
			shopper_key
		)

	aisle_shopper_ids [
		spawn_aisle_id
	] = aisle_residents

	var arrival_delay_ms: int = 0

	if shoppers.size() < minimum_count:


		arrival_delay_ms = int(
			rng.randi_range(
				180,
				520
			)
		)
	else:


		arrival_delay_ms = clampi(
			3600 - (population_gap * 70),
			850,
			3600
		)
		arrival_delay_ms += int(
			rng.randi_range(
				0,
				650
			)
		)

	session ["shoppers"] = shoppers
	session ["departed_shopper_ids"] = (
		departed_shopper_ids
	)
	session ["aisle_population_counts"] = (
		aisle_population_counts
	)
	session ["aisle_shopper_ids"] = (
		aisle_shopper_ids
	)
	session ["generated_ambient_serial"] = serial + 1
	session ["arrival_sequence"] = int(
		session.get(
			"arrival_sequence",
			0
		)
	) + 1
	session ["next_resident_arrival_ms"] = (
		now_ms + arrival_delay_ms
	)
	session ["next_arrival_wave_ms"] = (
		now_ms + arrival_delay_ms
	)
	session ["updated_at_ms"] = now_ms
	session [
		"last_population_quantum_at_ms"
	] = now_ms
	session [
		"last_population_quantum_world_scan"
	] = false
	session ["player_aisle_spawn_bias_used"] = false
	session ["arrival_backfill_loop_performed"] = false

	return true

func _grocery_pick_worker_people(store_id: String, desired_count: int, _context: Dictionary = {}) -> Array:
	var out: Array = []
	if gs == null:
		return out

	var candidates: Array = []
	for raw_person in gs.npcs:
		if raw_person == null or not (raw_person is Person):
			continue
		var person: Person = raw_person as Person
		if gs.player != null and int(person.id) == int(gs.player.id):
			continue
		if not bool(person.alive):
			continue
		if int(person.age) < 16:
			continue
		candidates.append(person)

	var rng: RandomNumberGenerator = _grocery_shopper_rng("%s|worker_shift|%s|%s" % [
		store_id,
		str(gs.year if gs != null else 0),
		str(candidates.size())
	])

	while out.size() < desired_count and not candidates.is_empty():
		var index: int = int(rng.randi_range(0, candidates.size() - 1))
		out.append(candidates [index])
		candidates.remove_at(index)

	return out


func _grocery_worker_row_from_person(person: Person, role: String) -> Dictionary:
	return {
		"person_id": int(person.id) if person != null else -1,
		"name": _grocery_person_name(person),
		"first_name": str(person.first_name).strip_edges() if person != null else "Worker",
		"profession": _grocery_person_profession(person),
		"role": role
	}


func _grocery_fallback_worker_names(store_id: String) -> Array:
	match str(store_id).strip_edges():
		"basket_lane_market":
			return ["Tasha Monroe", "Kenny Brooks", "Jada Ellis", "Luis Porter", "Brielle Cross", "Marlon Hayes"]
		"goldleaf_grocers":
			return ["Selene Hart", "Ellis Vale", "Priya Cole", "Noah Sterling", "Amara Wells", "Grant Bell"]
		"nutripod_exchange":
			return ["Jessa Nine", "Orin Flux", "Mika Sol", "Nova Kade", "Tali Byte", "Ren Vox"]
		_:
			return ["Ari Lane", "Morgan Reed", "Casey Bell", "Jordan Pike", "Taylor West", "Riley Quinn"]


func _grocery_worker_first_name(worker: Dictionary) -> String:
	var first_name: String = str(worker.get("first_name", "")).strip_edges()
	if first_name != "":
		return first_name

	var full_name: String = str(worker.get("name", "Worker")).strip_edges()
	if full_name.find(" ") >= 0:
		return full_name.get_slice(" ", 0)

	return full_name


func _grocery_cashier_first_names_line(cashiers: Array) -> String:
	var names: Array = []
	for raw_cashier in cashiers:
		if typeof(raw_cashier) != TYPE_DICTIONARY:
			continue
		var cashier: Dictionary = raw_cashier
		var first_name: String = _grocery_worker_first_name(cashier)
		if first_name != "":
			names.append(first_name)

	if names.is_empty():
		return "Lane"

	return ", ".join(names)


func assign_next_checkout_cashier(store_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()
	if clean_store_id == "":
		return {}

	var shift: Dictionary = _ensure_grocery_store_worker_shift(clean_store_id, context)
	var cashiers: Array = shift.get("cashiers", []) if typeof(shift.get("cashiers", [])) == TYPE_ARRAY else []
	if cashiers.is_empty():
		return {}

	var next_counter: int = int(shift.get("checkout_counter", -1)) + 1
	var selected_cashier: Dictionary = cashiers [next_counter % cashiers.size()] if typeof(cashiers [next_counter % cashiers.size()]) == TYPE_DICTIONARY else {}

	shift ["checkout_counter"] = next_counter
	shift ["active_cashier"] = selected_cashier.duplicate(true)
	shift ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_store_worker_sessions_by_store_id [clean_store_id] = shift

	return selected_cashier.duplicate(true)


func _grocery_active_cashier_for_store(store_id: String, context: Dictionary = {}) -> Dictionary:
	var shift: Dictionary = _ensure_grocery_store_worker_shift(store_id, context)
	var active_cashier: Dictionary = shift.get("active_cashier", {}) if typeof(shift.get("active_cashier", {})) == TYPE_DICTIONARY else {}
	if not active_cashier.is_empty():
		return active_cashier.duplicate(true)

	var cashiers: Array = shift.get("cashiers", []) if typeof(shift.get("cashiers", [])) == TYPE_ARRAY else []
	if not cashiers.is_empty() and typeof(cashiers [0]) == TYPE_DICTIONARY:
		return (cashiers [0] as Dictionary).duplicate(true)

	return {}
func get_grocery_store_rows(context: Dictionary = {}) -> Array:
	var era_name: String = _era_name_from_context(context)
	var out: Array = []
	var notice: String = str(context.get("notice", "")).strip_edges()
	var actor: Person = _actor_from_context(context)

	if notice != "":
		out.append({
			"label": "Store Notice",
			"description": notice,
			"kind": "grocery_notice"
		})

	for store in get_stores_for_era(era_name):
		var store_id: String = str(store.get("id", "")).strip_edges()
		var tier: String = str(store.get("tier", "market")).strip_edges()
		var tax_rate: float = float(store.get("tax_rate", 0.0)) * 100.0
		var tax_preview_text: String = ("%.2f" % tax_rate) + "%"
		var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
		var worker_shift: Dictionary = _ensure_grocery_store_worker_shift(store_id, context)
		var manager: Dictionary = worker_shift.get("manager", {}) if typeof(worker_shift.get("manager", {})) == TYPE_DICTIONARY else {}
		var cashiers: Array = worker_shift.get("cashiers", []) if typeof(worker_shift.get("cashiers", [])) == TYPE_ARRAY else []
		var manager_name: String = str(manager.get("name", "Store Manager")).strip_edges()
		var cashier_names: String = _grocery_cashier_first_names_line(cashiers)

		var visual_theme: String = "grocery_standard"
		var entrance_text: String = "Enter Store"
		var storefront_line: String = "Everyday aisles, cart wheels, and food contracts waiting on the shelves."

		match store_id:
			"basket_lane_market":
				visual_theme = "era_mart"
				entrance_text = "Enter Era-Mart"
				storefront_line = "Gold-lit discount aisles, freezer hum, cereal prophecies, and snack choices that feel slightly dangerous."
			"goldleaf_grocers":
				visual_theme = "goldleaf"
				entrance_text = "Enter Goldleaf"
				storefront_line = "Soft premium lighting, polished floors, expensive produce mist, boutique snacks, and rich-person cart energy."
			"nutripod_exchange":
				visual_theme = "future_market"
				entrance_text = "Enter Nutripod Exchange"
				storefront_line = "Floating aisle signs, scanner hum, future food pods, synthetic cereals, and vending AI watching the shelves."

		var actions: Array = []
		if store_id == "goldleaf_grocers":
			if actor_has_goldleaf_premium(actor):
				actions.append({
					"id": "grocery_goldleaf_membership:status",
					"label": _goldleaf_membership_status_text(actor),
					"kind": "packet",
					"style": "secondary",
					"visual_theme": "goldleaf"
				})
			else:
				actions.append({
					"id": "grocery_goldleaf_membership:buy",
					"label": "Buy Premium Membership • " + _goldleaf_currency_symbol_for_actor(actor) + "250/Mo",
					"kind": "packet",
					"style": "primary",
					"visual_theme": "goldleaf"
				})

		actions.append({
			"id": "grocery_store:%s" % store_id,
			"label": entrance_text,
			"kind": "packet",
			"style": "primary",
			"visual_theme": visual_theme
		})

		var membership_line: String = ""
		if store_id == "goldleaf_grocers":
			membership_line = "\n\n" + _goldleaf_membership_line_for_actor(actor, actor_has_goldleaf_premium(actor))

		var description_text: String = storefront_line
		description_text += "\n\n" + str(store.get("description", "Bright aisles, humming refrigerators, and shelves full of contract-routed food."))
		description_text += "\n\nManager: " + manager_name
		description_text += "\nCashiers Today: " + cashier_names
		description_text += "\n\nInventory pool: " + str(inventory.size()) + " items • Local tax preview: " + tax_preview_text
		description_text += membership_line

		out.append({
			"label": " %s • %s" % [
				str(store.get("name", "Grocery Store")),
				tier.replace("_", " ").capitalize()
			],
			"description": description_text,
			"store_id": store_id,
			"kind": "grocery_store_premium",
			"tier": tier,
			"visual_theme": visual_theme,
			"text_align": "center",
			"actions": actions
		})

	return out
func get_grocery_item_rows(context: Dictionary = {}) -> Array:
	var store_id: String = str(context.get("store_id", "")).strip_edges()
	var aisle_id: String = str(context.get("aisle_id", "")).strip_edges()
	var store: Dictionary = get_store(store_id)
	var out: Array = []

	if store.is_empty():
		out.append({
			"label": "Choose a store first",
			"description": "Go back to Grocery Stores and pick a store before browsing items.",
			"kind": "grocery_missing_store"
		})
		return out

	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var item_aisle: String = _grocery_aisle_id_for_item(item)
		if aisle_id != "" and item_aisle != aisle_id:
			continue

		var food_id: String = str(item.get("id", "")).strip_edges()
		out.append({
			"label": "%s • $%d • shelf %d years" % [
				str(item.get("name", "Food")),
				int(item.get("price", 0)),
				int(item.get("shelf_life_years", 1))
			],
			"description": "%s aisle item. Nutrition %d. Quality: %s." % [
				_grocery_aisle_label(item_aisle),
				int(item.get("nutrition", 0)),
				str(item.get("quality", "basic"))
			],
			"store_id": store_id,
			"food_id": food_id,
			"aisle_id": item_aisle,
			"kind": "grocery_item",
			"actions": [
				{
					"id": "grocery_add:%s:%s" % [store_id, food_id],
					"label": "Add to Cart",
					"kind": "packet",
					"style": "success"
				}
			]
		})

	return out
func get_grocery_aisle_rows(context: Dictionary = {}) -> Array:
	var store_id: String = str(context.get("store_id", "")).strip_edges()
	var selected_aisle_id: String = str(context.get("aisle_id", "")).strip_edges()
	var store: Dictionary = get_store(store_id)
	var out: Array = []

	if store.is_empty():
		out.append({
			"label": "Choose a store first",
			"description": "Pick a grocery store before browsing aisles.",
			"kind": "grocery_missing_store"
		})
		return out

	var aisle_ids: Array = []
	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var aisle_id: String = _grocery_aisle_id_for_item(raw_item as Dictionary)
		if aisle_id == "":
			continue

		if not aisle_ids.has(aisle_id):
			aisle_ids.append(aisle_id)

	if selected_aisle_id == "" and not aisle_ids.is_empty():
		selected_aisle_id = str(aisle_ids [0])

	var selected_index: int = aisle_ids.find(selected_aisle_id)
	if selected_index < 0 and not aisle_ids.is_empty():
		selected_index = 0
		selected_aisle_id = str(aisle_ids [0])

	var previous_aisle_id: String = selected_aisle_id
	var next_aisle_id: String = selected_aisle_id
	if not aisle_ids.is_empty():
		previous_aisle_id = str(aisle_ids [(selected_index - 1 + aisle_ids.size()) % aisle_ids.size()])
		next_aisle_id = str(aisle_ids [(selected_index + 1) % aisle_ids.size()])

	var cart_has_items: bool = false
	var actor: Person = _actor_from_context(context)
	if actor != null:
		cart_has_items = actor_cart_has_items(actor)

	var shopper_summary: Dictionary = get_grocery_aisle_shopper_summary(store_id, selected_aisle_id, context)
	var shopper_count: int = int(shopper_summary.get("count", 0))

	var inside_store_description: String = "You are inside this store now. Use the aisle arrows below, add items, then press Done Browsing when you are ready for your cart."
	match store_id:
		"basket_lane_market":
			inside_store_description = "Era-Mart glows cherry and coral overhead. Carts rattle. Freezers hum. The aisles feel warm, playful, glossy, and dangerously snackable."
		"goldleaf_grocers":
			inside_store_description = "Goldleaf feels polished and expensive. The produce mist is dramatic, the carts glide too smoothly, and every shelf looks like it has a publicist."
		"nutripod_exchange":
			inside_store_description = "The Nutripod Exchange glows with floating aisle signs, scanner pings, synthetic food pods, and future-market ambience."

	out.append({
		"label": "Inside %s" % str(store.get("name", "the store")),
		"description": inside_store_description,
		"kind": "grocery_inside_store_header",
		"store_id": store_id,
		"layout_group": "grocery_inside_presence_row",
		"layout_group_order": 0,
		"layout_columns": 2,
		"compact_height": true,
		"action_columns": 2,
		"actions": [
			{
				"id": "grocery_back:stores",
				"label": "Back",
				"kind": "packet",
				"style": "secondary"
			},
			{
				"id": "grocery_done_browsing",
				"label": "Done Browsing",
				"kind": "packet",
				"style": "success",
				"enabled": cart_has_items
			}
		]
	})

	if selected_aisle_id != "":
		var aisle_display_name: String = _grocery_aisle_label(selected_aisle_id).strip_edges()
		var shopper_word: String = "person" if shopper_count == 1 else "people"

		out.append({
			"label": "%d other %s in the %s aisle" % [
				shopper_count,
				shopper_word,
				aisle_display_name
			],
			"description": "Live store movement is active. People linger, drift between aisles, keep their carts, and leave only when they finish shopping.",
			"kind": "grocery_aisle_shopper_count",
			"store_id": store_id,
			"aisle_id": selected_aisle_id,
			"shopper_count": shopper_count,
			"layout_group": "grocery_inside_presence_row",
			"layout_group_order": 1,
			"layout_columns": 2,
			"compact_height": true,
			"action_columns": 1,
			"actions": [
				{
					"id": "grocery_shoppers_popup:%s:%s" % [store_id, selected_aisle_id],
					"label": "View Shoppers",
					"kind": "packet",
					"style": "primary"
				}
			]
		})

	if selected_aisle_id != "":
		out.append({
			"label": " %s " % _grocery_aisle_label(selected_aisle_id),
			"description": _grocery_aisle_description(selected_aisle_id, store),
			"kind": "grocery_aisle_carousel",
			"text_align": "center",
			"store_id": store_id,
			"aisle_id": selected_aisle_id,
			"actions": [
				{
					"id": "grocery_aisle:%s:%s" % [
						store_id,
						previous_aisle_id
					],
					"label": "←",
					"kind": "packet",
					"style": "secondary"
			},
			{
					"id": "grocery_aisle:%s:%s" % [
						store_id,
						next_aisle_id
					],
					"label": "→",
					"kind": "packet",
					"style": "primary"
			}
			]
		})

	if selected_aisle_id == "":
		return out
	var grocery_food_card_order: int = 0
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var item_aisle: String = _grocery_aisle_id_for_item(item)
		if item_aisle != selected_aisle_id:
			continue

		var food_id: String = str(item.get("id", "")).strip_edges()
		var price_breakdown: Dictionary = _grocery_item_price_breakdown(store, item, actor)
		var brand_lane: String = str(item.get("brand_lane", "store_brand")).strip_edges()
		var brand_text: String = "EraLife Name Brand" if brand_lane == "name_brand" else "Knockoff / Store Brand"
		var item_quality: String = str(item.get("quality", "basic"))
		var discount_text: String = ""
		var price_label: String = "%s • %s" % [
			str(item.get("name", "Food")),
			_goldleaf_format_money_for_actor(float(price_breakdown.get("total", 0.0)), actor)
		]

		if bool(price_breakdown.get("goldleaf_premium_discount_applied", false)):
			discount_text = "Goldleaf Premium: 50% off + no tax"
			price_label = "%s\n%s\n%s (Goldleaf Premium)" % [
				str(item.get("name", "Food")),
				_goldleaf_format_money_for_actor(float(price_breakdown.get("base_total", item.get("price", 0.0))), actor),
				_goldleaf_format_money_for_actor(float(price_breakdown.get("total", 0.0)), actor)
			]

		out.append({
			"label": price_label,
			"description": "%s • Nutrition %d • Quality: %s • Shelf life: %d years%s" % [
				brand_text,
				int(item.get("nutrition", 0)),
				item_quality,
				int(item.get("shelf_life_years", 1)),
				"\n%s" % discount_text if discount_text != "" else ""
			],
			"store_id": store_id,
			"food_id": food_id,
			"aisle_id": item_aisle,
			"brand_lane": brand_lane,
			"quality": item_quality,
			"price": float(price_breakdown.get("subtotal", 0.0)),
			"tax": float(price_breakdown.get("tax", 0.0)),
			"price_after_tax": float(price_breakdown.get("total", 0.0)),
			"layout_group": "grocery_food_cards:%s:%s" % [
					store_id,
					selected_aisle_id
			],
			"layout_group_order": grocery_food_card_order,
			"layout_columns": 3,
			"compact_height": false,
			"kind": "grocery_item",
			"actions": [
				{
					"id": "grocery_add:%s:%s" % [store_id, food_id],
					"label": "Add to Cart",
					"kind": "packet",
					"style": "primary"
				}
			]
		})
	grocery_food_card_order += 1
	return out
func get_grocery_cart_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	var out: Array = []
	var notice: String = str(context.get("notice", "")).strip_edges()

	if notice != "":
		out.append({
			"label": "Cart Notice",
			"description": notice,
			"kind": "grocery_notice"
		})

	if items.is_empty():
		out.append({
			"label": "Your cart is empty",
			"description": "Add items from the aisles before checking out or attempting to shoplift.",
			"kind": "grocery_empty_cart"
		})
		return out

	var store_id: String = str(cart.get("store_id", context.get("store_id", ""))).strip_edges()
	var store: Dictionary = get_store(store_id)
	var cart_breakdown: Dictionary = _grocery_cart_price_breakdown(cart)
	var subtotal: float = float(cart_breakdown.get("subtotal", 0.0))
	var tax: float = float(cart_breakdown.get("tax", 0.0))
	var total: float = float(cart_breakdown.get("total", 0.0))

	out.append({
		"label": "Receipt",
		"description": "Review the receipt before choosing a cashier, self-checkout, shoplifting, or going back.",
		"kind": "grocery_receipt_header",
		"store_id": store_id
	})

	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var qty: int = max(1, int(item.get("quantity", 1)))
		var line_breakdown: Dictionary = _grocery_line_item_price_breakdown(store, item, qty)
		var qty_text: String = " ×%d" % qty if qty > 1 else ""
		var discount_text: String = ""
		var receipt_label: String = "%s%s: %s" % [
			str(item.get("name", "Food")),
			qty_text,
			_goldleaf_format_money_for_actor(float(line_breakdown.get("total", 0.0)), actor)
		]

		if bool(item.get("goldleaf_premium_discount_applied", false)):
			discount_text = "Goldleaf Premium discount applied: 50% off and no tax."
			receipt_label = "%s%s:\n%s\n%s (Goldleaf Premium)" % [
				str(item.get("name", "Food")),
				qty_text,
				_goldleaf_format_money_for_actor(float(item.get("base_total_before_goldleaf", line_breakdown.get("total", 0.0))) * float(qty), actor),
				_goldleaf_format_money_for_actor(float(line_breakdown.get("total", 0.0)), actor)
			]

		out.append({
			"label": receipt_label,
			"description": discount_text,
			"kind": "grocery_receipt_line",
			"store_id": store_id
		})

	out.append({
		"label": "Subtotal: %s" % _goldleaf_format_money_for_actor(subtotal, actor),
		"description": "Tax: %s\nTotal: %s" % [
			_goldleaf_format_money_for_actor(tax, actor),
			_goldleaf_format_money_for_actor(total, actor)
		],
		"kind": "grocery_receipt_total",
		"store_id": store_id
	})

	return out
func actor_cart_has_items(actor: Person) -> bool:
	if actor == null:
		return false

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	return not items.is_empty()
func _actor_from_context(context: Dictionary = {}) -> Person:
	if gs == null:
		return null

	var actor_id: int = int(context.get("actor_id", context.get("npc_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor

	return gs.player

func get_grocery_cashier_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var store_id: String = str(cart.get("store_id", context.get("store_id", ""))).strip_edges()
	var store: Dictionary = get_store(store_id)
	var active_cashier: Dictionary = _grocery_active_cashier_for_store(store_id, context)
	var cashier_name: String = str(active_cashier.get("name", store.get("cashier_name", "the cashier"))).strip_edges()
	var cashier_profession: String = str(active_cashier.get("profession", "Cashier")).strip_edges()

	if cashier_name == "":
		cashier_name = "the cashier"
	if cashier_profession == "":
		cashier_profession = "Cashier"

	return [
		{
			"label": "Cashier • %s" % cashier_name,
			"description": "%s • %s\n\"Find everything alright?\" %s watches the cart, the scanner glowing under the store lights." % [
				cashier_name,
				cashier_profession,
				cashier_name
			],
			"kind": "grocery_cashier",
			"store_id": store_id,
			"cashier": active_cashier.duplicate(true),
			"actions": [
				{
					"id": "grocery_checkout",
					"label": "Pay for Cart",
					"kind": "packet",
					"style": "success"
				},
				{
					"id": "grocery_shoplift",
					"label": "Try to Walk Out",
					"kind": "packet",
					"style": "danger"
				}
			]
		}
	]

func _self_checkout_session_key(actor: Person) -> String:
	if actor == null:
		return ""
	return str(int(actor.id))


func _self_checkout_payment_prompt_audio_path() -> String:
	return "res://Audio/SelfCheckOut.ogg"


func _self_checkout_machine_count_for_store(store_id: String) -> int:
	match str(store_id).strip_edges():
		"goldleaf_grocers":
			return 6
		"nutripod_exchange":
			return 8
		_:
			return 5

func _self_checkout_live_tick_interval_ms() -> int:
	return 1250


func _self_checkout_machine_service_duration_ms(rng: RandomNumberGenerator, status: String) -> int:
	match str(status).strip_edges().to_lower():
		"offline":
			return int(rng.randi_range(9000, 22000))
		"in_use":
			return int(rng.randi_range(6000, 18000))
		_:
			return int(rng.randi_range(3500, 9000))


func _self_checkout_prepare_machine_for_status(machine: Dictionary, status: String, rng: RandomNumberGenerator, now_ms: int, occupant_label: String = "") -> Dictionary:
	var clean_status: String = str(status).strip_edges().to_lower()
	if clean_status == "":
		clean_status = "available"

	machine ["status"] = clean_status
	machine ["updated_at_ms"] = now_ms
	machine ["status_started_at_ms"] = now_ms

	match clean_status:
		"available":
			machine ["status_label"] = "Available"
			machine ["occupant_label"] = ""
			machine ["occupant_name"] = ""
			machine ["occupant_person_id"] = -1
			machine ["occupant_source"] = ""
			machine ["ambient_cart_item_count"] = 0
			machine ["ambient_cart_total"] = 0.0
			machine ["ambient_cart_total_text"] = ""
			machine ["ambient_receipt"] = {}
			machine ["expected_available_at_ms"] = 0
		"in_use":
			var resolved_occupant_label: String = str(occupant_label).strip_edges()
			if resolved_occupant_label == "":
				resolved_occupant_label = _self_checkout_occupant_label(rng, str(machine.get("store_id", "")))

			machine ["status_label"] = "In Use"
			machine ["occupant_label"] = resolved_occupant_label
			machine ["expected_available_at_ms"] = now_ms + _self_checkout_machine_service_duration_ms(rng, clean_status)
		"offline":
			machine ["status_label"] = "Temporarily Offline"
			machine ["occupant_label"] = "assistance light blinking"
			machine ["occupant_name"] = ""
			machine ["occupant_person_id"] = -1
			machine ["occupant_source"] = ""
			machine ["ambient_cart_item_count"] = 0
			machine ["ambient_cart_total"] = 0.0
			machine ["ambient_cart_total_text"] = ""
			machine ["ambient_receipt"] = {}
			machine ["expected_available_at_ms"] = now_ms + _self_checkout_machine_service_duration_ms(rng, clean_status)
		"assigned":
			machine ["status_label"] = "Ready For Payment"
			machine ["occupant_label"] = "Me"
			machine ["occupant_name"] = "Me"
			machine ["occupant_person_id"] = -1
			machine ["occupant_source"] = "player"
			machine ["ambient_cart_item_count"] = 0
			machine ["ambient_cart_total"] = 0.0
			machine ["ambient_cart_total_text"] = ""
			machine ["ambient_receipt"] = {}
			machine ["expected_available_at_ms"] = 0
		"complete":
			machine ["status_label"] = "Payment Complete"
			machine ["occupant_label"] = "Me"
			machine ["occupant_name"] = "Me"
			machine ["occupant_person_id"] = -1
			machine ["occupant_source"] = "player"
			machine ["ambient_cart_item_count"] = 0
			machine ["ambient_cart_total"] = 0.0
			machine ["ambient_cart_total_text"] = ""
			machine ["ambient_receipt"] = {}
			machine ["expected_available_at_ms"] = 0
		_:
			machine ["status_label"] = clean_status.capitalize()
			machine ["occupant_label"] = occupant_label
			machine ["expected_available_at_ms"] = 0

	return machine


func _self_checkout_live_rng(session: Dictionary, salt: String = "") -> RandomNumberGenerator:
	var seed_text: String = "%s|%s|%s|%d" % [
		str(session.get("store_id", "")),
		str(session.get("actor_id", "")),
		str(salt),
		int(Time.get_ticks_msec() / max(1, _self_checkout_live_tick_interval_ms()))
	]
	return _grocery_shopper_rng(seed_text)
func _self_checkout_machine_occupant_ids(machines: Array, actor: Person = null) -> Dictionary:
	var used_ids: Dictionary = {}

	if actor != null:
		used_ids [str(int(actor.id))] = true
		used_ids ["person:%d" % int(actor.id)] = true

	for raw_machine in machines:
		if typeof(raw_machine) != TYPE_DICTIONARY:
			continue

		var machine: Dictionary = raw_machine
		var occupant_id: int = int(machine.get("occupant_person_id", -1))
		var occupant_name: String = str(machine.get("occupant_name", "")).strip_edges()
		var identity_key: String = str(machine.get("occupant_identity_key", "")).strip_edges()

		if occupant_id > 0:
			used_ids [str(occupant_id)] = true
			used_ids ["person:%d" % occupant_id] = true

		if occupant_name != "":
			used_ids ["name:%s" % occupant_name.to_lower()] = true

		if identity_key != "":
			used_ids [identity_key] = true

	return used_ids


func _self_checkout_person_name_from_id(person_id: int) -> String:
	if person_id <= 0 or gs == null or not gs.has_method("get_npc_by_id"):
		return ""

	var person: Person = gs.get_npc_by_id(person_id)
	if person == null:
		return ""

	return _grocery_person_name(person)

func _self_checkout_occupant_identity_key(profile: Dictionary) -> String:
	var person_id: int = int(profile.get("person_id", -1))
	if person_id > 0:
		return "person:%d" % person_id

	var person_name: String = str(profile.get("name", "")).strip_edges().to_lower()
	if person_name != "":
		return "name:%s" % person_name

	return "fallback:%s" % str(profile.get("source", "unknown")).strip_edges().to_lower()


func _self_checkout_occupant_profile_is_locked(profile: Dictionary, locks: Dictionary) -> bool:
	var person_id: int = int(profile.get("person_id", -1))
	var person_name: String = str(profile.get("name", "")).strip_edges()
	var identity_key: String = _self_checkout_occupant_identity_key(profile)

	if identity_key != "" and locks.has(identity_key):
		return true

	if person_id > 0:
		if locks.has(str(person_id)):
			return true
		if locks.has("person:%d" % person_id):
			return true

	if person_name != "" and locks.has("name:%s" % person_name.to_lower()):
		return true

	return false


func _self_checkout_filter_unlocked_occupant_profiles(candidates: Array, locks: Dictionary) -> Array:
	var out: Array = []

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		if _self_checkout_occupant_profile_is_locked(candidate, locks):
			continue

		var identity_key: String = _self_checkout_occupant_identity_key(candidate)
		candidate ["identity_key"] = identity_key
		out.append(candidate.duplicate(true))

	return out
func _self_checkout_named_store_shopper_candidates(
		store_id: String,
		excluded_ids: Dictionary = {}
) -> Array:
	var out: Array = []
	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return out

	var session_raw: Variant = (
		grocery_shopper_sessions_by_store_id.get(
			clean_store_id,
			{}
		)
	)

	if typeof(session_raw) != TYPE_DICTIONARY:
		return out

	var session: Dictionary = (
		session_raw as Dictionary
	)
	var shoppers_raw: Variant = session.get(
		"shoppers",
		{}
	)
	var shoppers: Dictionary = (
		shoppers_raw as Dictionary
		if typeof(shoppers_raw) == TYPE_DICTIONARY
		else {}
	)

	for raw_key in shoppers.keys():
		var shopper_raw: Variant = shoppers.get(
			raw_key,
			{}
		)

		if typeof(shopper_raw) != TYPE_DICTIONARY:
			continue

		var shopper: Dictionary = (
			shopper_raw as Dictionary
		)
		var preview_raw: Variant = shopper.get(
			"preview_identity",
			{}
		)
		var preview_identity: Dictionary = (
			preview_raw as Dictionary
			if typeof(preview_raw) == TYPE_DICTIONARY
			else {}
		)
		var person_id: int = int(
			shopper.get(
				"materialized_person_id",
				shopper.get(
					"person_id",
					-1
				)
			)
		)
		var shopper_name: String = str(
			shopper.get(
				"name",
				preview_identity.get(
					"display_name",
					preview_identity.get(
						"name",
						""
					)
				)
			)
		).strip_edges()

		if (
			shopper_name == ""
			or shopper_name == "Unknown shopper"
		):
			continue

		var profile: Dictionary = {
			"person_id": person_id,
			"name": shopper_name,
			"source": (
				"resident_grocery_shopper_snapshot"
			),
		}

		profile ["identity_key"] = (
			_self_checkout_occupant_identity_key(
				profile
			)
		)

		if _self_checkout_occupant_profile_is_locked(
			profile,
			excluded_ids
		):
			continue

		out.append(profile)

	return out

func _self_checkout_named_world_npc_candidates(excluded_ids: Dictionary = {}) -> Array:
	var out: Array = []

	if gs == null or typeof(gs.npcs) != TYPE_ARRAY:
		return out

	for raw_person in gs.npcs:
		if raw_person == null or not (raw_person is Person):
			continue

		var person: Person = raw_person
		if int(person.id) <= 0:
			continue

		if not bool(person.alive):
			continue

		var person_name: String = _grocery_person_name(person)
		if person_name == "" or person_name == "Unknown shopper":
			continue

		var profile: Dictionary = {
			"person_id": int(person.id),
			"name": person_name,
			"source": "world_npc_pool"
		}
		profile ["identity_key"] = _self_checkout_occupant_identity_key(profile)

		if _self_checkout_occupant_profile_is_locked(profile, excluded_ids):
			continue

		out.append(profile)

	return out

func _self_checkout_pick_named_occupant_profile(
		store_id: String,
		rng: RandomNumberGenerator,
		excluded_ids: Dictionary = {}
) -> Dictionary:
	var candidates: Array = (
		_self_checkout_named_store_shopper_candidates(
			store_id,
			excluded_ids
		)
	)

	candidates = (
		_self_checkout_filter_unlocked_occupant_profiles(
			candidates,
			excluded_ids
		)
	)

	if candidates.is_empty():
		var fallback_names: Array = [
			"Marisol Reed",
			"Devon Price",
			"Nia Coleman",
			"Rafael Brooks",
			"Imani Clarke",
			"Micah Turner",
			"Jules Navarro",
			"Taylor Knox"
		]
		var fallback_start: int = int(
			rng.randi_range(
				0,
				fallback_names.size() - 1
			)
		)

		for offset in range(
			fallback_names.size()
		):
			var fallback_index: int = (
				fallback_start + offset
			) % fallback_names.size()
			var fallback_profile: Dictionary = {
				"person_id": -1,
				"name": str(
					fallback_names [fallback_index]
				),
				"source": (
					"resident_self_checkout_presence_contract"
				),
				"world_population_scan_performed": false
			}

			fallback_profile ["identity_key"] = (
				_self_checkout_occupant_identity_key(
					fallback_profile
				)
			)

			if _self_checkout_occupant_profile_is_locked(
				fallback_profile,
				excluded_ids
			):
				continue

			return fallback_profile

		return {
			"person_id": -1,
			"name": "Another shopper",
			"source": (
				"resident_self_checkout_presence_contract"
			),
			"identity_key": (
				"resident_self_checkout_fallback"
			),
			"world_population_scan_performed": false
		}

	var index: int = int(
		rng.randi_range(
			0,
			candidates.size() - 1
		)
	)
	var picked: Dictionary = (
		candidates [index] as Dictionary
	).duplicate(false)

	picked ["identity_key"] = (
		_self_checkout_occupant_identity_key(
			picked
		)
	)
	picked [
		"world_population_scan_performed"
	] = false

	return picked
func _self_checkout_apply_occupant_profile(machine: Dictionary, profile: Dictionary) -> Dictionary:
	var person_id: int = int(profile.get("person_id", -1))
	var person_name: String = str(profile.get("name", "")).strip_edges()
	var identity_key: String = str(profile.get("identity_key", "")).strip_edges()

	if person_name == "":
		person_name = "Unknown shopper"

	if identity_key == "":
		identity_key = _self_checkout_occupant_identity_key(profile)

	machine ["occupant_person_id"] = person_id
	machine ["occupant_name"] = person_name
	machine ["occupant_label"] = "%s is using this terminal." % person_name
	machine ["occupant_source"] = str(profile.get("source", "self_checkout_runtime"))
	machine ["occupant_identity_key"] = identity_key

	return machine
func _self_checkout_person_from_id(person_id: int) -> Person:
	if person_id <= 0 or gs == null or not gs.has_method("get_npc_by_id"):
		return null

	var person: Person = gs.get_npc_by_id(person_id)
	return person


func _self_checkout_format_spend_amount(amount: float, person_id: int, fallback_actor: Person = null) -> String:
	var buyer: Person = _self_checkout_person_from_id(person_id)
	if buyer != null:
		return _goldleaf_format_money_for_actor(amount, buyer)

	return _goldleaf_format_money_for_actor(amount, fallback_actor)


func _self_checkout_build_ambient_receipt(store_id: String, profile: Dictionary, rng: RandomNumberGenerator, fallback_actor: Person = null) -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()
	var store: Dictionary = get_store(clean_store_id)
	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	var buyer_id: int = int(profile.get("person_id", -1))
	var buyer: Person = _self_checkout_person_from_id(buyer_id)
	var total: float = 0.0
	var item_count: int = 0
	var line_count: int = 0
	var sample_items: Array = []

	if not store.is_empty() and not inventory.is_empty():
		var target_lines: int = int(rng.randi_range(1, min(6, inventory.size())))

		for _line_index in range(target_lines):
			var picked_index: int = int(rng.randi_range(0, inventory.size() - 1))
			var raw_item: Variant = inventory [picked_index]

			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = (raw_item as Dictionary).duplicate(true)
			var quantity: int = 1
			if rng.randf() < 0.35:
				quantity = int(rng.randi_range(2, 3))

			var price_breakdown: Dictionary = _grocery_item_price_breakdown(store, item, buyer)
			var line_total: float = float(price_breakdown.get("total", float(item.get("price", 0.0)))) * float(quantity)

			total += line_total
			item_count += quantity
			line_count += 1

			var item_name: String = str(item.get("name", "")).strip_edges()
			if item_name != "" and sample_items.size() < 3:
				sample_items.append(item_name)

	if item_count <= 0:
		item_count = int(rng.randi_range(1, 12))

	if total <= 0.0:
		total = rng.randf_range(8.0, 185.0)

	total = snapped(total, 0.01)

	return {
		"store_id": clean_store_id,
		"person_id": buyer_id,
		"person_name": str(profile.get("name", "Unknown shopper")),
		"item_count": item_count,
		"line_count": line_count,
		"sample_items": sample_items.duplicate(true),
		"total": total,
		"total_text": _self_checkout_format_spend_amount(total, buyer_id, fallback_actor),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _self_checkout_apply_ambient_receipt(machine: Dictionary, store_id: String, profile: Dictionary, rng: RandomNumberGenerator, fallback_actor: Person = null) -> Dictionary:
	var receipt: Dictionary = _self_checkout_build_ambient_receipt(store_id, profile, rng, fallback_actor)

	machine ["ambient_receipt"] = receipt.duplicate(true)
	machine ["ambient_cart_item_count"] = int(receipt.get("item_count", 0))
	machine ["ambient_cart_total"] = float(receipt.get("total", 0.0))
	machine ["ambient_cart_total_text"] = str(receipt.get("total_text", "")).strip_edges()

	return machine


func _self_checkout_departure_event_for_machine(machine: Dictionary, fallback_actor: Person = null) -> String:
	var machine_label: String = str(machine.get("label", "A self-checkout machine")).strip_edges()
	if machine_label == "":
		machine_label = "A self-checkout machine"

	var occupant_name: String = str(machine.get("occupant_name", "")).strip_edges()
	if occupant_name == "":
		occupant_name = str(machine.get("occupant_label", "")).replace(" is using this terminal.", "").strip_edges()
	if occupant_name == "":
		occupant_name = "A shopper"

	var buyer_id: int = int(machine.get("occupant_person_id", -1))
	var total_text: String = str(machine.get("ambient_cart_total_text", "")).strip_edges()
	if total_text == "":
		var total: float = float(machine.get("ambient_cart_total", 0.0))
		if total > 0.0:
			total_text = _self_checkout_format_spend_amount(total, buyer_id, fallback_actor)

	var item_count: int = int(machine.get("ambient_cart_item_count", 0))
	var item_text: String = ""
	if item_count > 0:
		item_text = " on %d item%s" % [
			item_count,
			"" if item_count == 1 else "s"
		]

	if total_text != "":
		return "%s finishes at %s, spends %s%s, grabs the receipt, and leaves. %s opens up." % [
			occupant_name,
			machine_label,
			total_text,
			item_text,
			machine_label
		]

	return "%s finishes at %s, grabs the receipt, and leaves. %s opens up." % [
		occupant_name,
		machine_label,
		machine_label
	]
func _build_self_checkout_machine_rows(store_id: String, actor: Person, _context: Dictionary = {}) -> Array:
	var out: Array = []
	var actor_id: int = int(actor.id) if actor != null else 0
	var count: int = _self_checkout_machine_count_for_store(store_id)
	var now_ms: int = int(Time.get_ticks_msec())
	var seed_text: String = "%s|%d|%d|self_checkout_machines" % [
		str(store_id),
		actor_id,
		int(gs.year) if gs != null else 0
	]
	var rng: RandomNumberGenerator = _grocery_shopper_rng(seed_text)
	var available_count: int = 0

	for index in range(count):
		var machine_number: int = index + 1
		var machine_id: String = "sco_%02d" % machine_number
		var roll: float = rng.randf()
		var status: String = "available"

		if roll < 0.1:
			status = "offline"
		elif roll < 0.68:
			status = "in_use"

		var machine: Dictionary = {
			"machine_id": machine_id,
			"machine_number": machine_number,
			"label": "Self Checkout %d" % machine_number,
			"store_id": store_id
		}

		if status == "in_use":
			var used_ids: Dictionary = _self_checkout_machine_occupant_ids(out, actor)
			var occupant_profile: Dictionary = _self_checkout_pick_named_occupant_profile(store_id, rng, used_ids)

			machine = _self_checkout_prepare_machine_for_status(machine, status, rng, now_ms, "%s is using this terminal." % str(occupant_profile.get("name", "Unknown shopper")))
			machine = _self_checkout_apply_occupant_profile(machine, occupant_profile)
			machine = _self_checkout_apply_ambient_receipt(machine, store_id, occupant_profile, rng, actor)

			var started_ago_ms: int = int(rng.randi_range(500, 7000))
			machine ["status_started_at_ms"] = now_ms - started_ago_ms
			machine ["expected_available_at_ms"] = now_ms + int(rng.randi_range(2500, 9000))
		else:
			machine = _self_checkout_prepare_machine_for_status(machine, status, rng, now_ms, "")
			if status == "offline":
				machine ["expected_available_at_ms"] = now_ms + int(rng.randi_range(7000, 18000))

		if str(machine.get("status", "")) == "available":
			available_count += 1

		out.append(machine)

	if available_count >= count and out.size() > 2:
		for force_index in range(1, min(3, out.size())):
			var forced_machine: Dictionary = out [force_index]
			var forced_used_ids: Dictionary = _self_checkout_machine_occupant_ids(out, actor)
			var forced_profile: Dictionary = _self_checkout_pick_named_occupant_profile(store_id, rng, forced_used_ids)

			forced_machine = _self_checkout_prepare_machine_for_status(forced_machine, "in_use", rng, now_ms, "%s is finishing payment." % str(forced_profile.get("name", "Unknown shopper")))
			forced_machine = _self_checkout_apply_occupant_profile(forced_machine, forced_profile)
			forced_machine = _self_checkout_apply_ambient_receipt(forced_machine, store_id, forced_profile, rng, actor)
			out [force_index] = forced_machine

	return out

func _self_checkout_occupant_label(rng: RandomNumberGenerator, store_id: String = "", session: Dictionary = {}) -> String:
	var excluded_ids: Dictionary = {}

	if typeof(session.get("machines", [])) == TYPE_ARRAY:
		excluded_ids = _self_checkout_machine_occupant_ids(session.get("machines", []))

	var profile: Dictionary = _self_checkout_pick_named_occupant_profile(store_id, rng, excluded_ids)
	var person_name: String = str(profile.get("name", "")).strip_edges()

	if person_name == "":
		person_name = "Unknown shopper"

	return "%s is using this terminal." % person_name


func _self_checkout_available_machine(session: Dictionary) -> Dictionary:
	var machines: Array = session.get("machines", []) if typeof(session.get("machines", [])) == TYPE_ARRAY else []
	for raw_machine in machines:
		if typeof(raw_machine) != TYPE_DICTIONARY:
			continue
		var machine: Dictionary = raw_machine
		if str(machine.get("status", "")).strip_edges().to_lower() == "available":
			return machine.duplicate(true)
	return {}


func _self_checkout_machine_by_id(session: Dictionary, machine_id: String) -> Dictionary:
	var clean_machine_id: String = str(machine_id).strip_edges()
	var machines: Array = session.get("machines", []) if typeof(session.get("machines", [])) == TYPE_ARRAY else []
	for raw_machine in machines:
		if typeof(raw_machine) != TYPE_DICTIONARY:
			continue
		var machine: Dictionary = raw_machine
		if str(machine.get("machine_id", "")).strip_edges() == clean_machine_id:
			return machine.duplicate(true)
	return {}


func _self_checkout_set_machine_status(session: Dictionary, machine_id: String, status: String, status_label: String = "", occupant_label: String = "") -> Dictionary:
	var clean_machine_id: String = str(machine_id).strip_edges()
	var machines: Array = session.get("machines", []) if typeof(session.get("machines", [])) == TYPE_ARRAY else []
	var rng: RandomNumberGenerator = _self_checkout_live_rng(session, "set_status_%s_%s" % [clean_machine_id, status])
	var now_ms: int = int(Time.get_ticks_msec())

	for index in range(machines.size()):
		if typeof(machines [index]) != TYPE_DICTIONARY:
			continue

		var machine: Dictionary = machines [index]
		if str(machine.get("machine_id", "")).strip_edges() != clean_machine_id:
			continue

		machine = _self_checkout_prepare_machine_for_status(machine, status, rng, now_ms, occupant_label)
		if status_label != "":
			machine ["status_label"] = status_label
		machines [index] = machine
		break

	session ["machines"] = machines
	session ["updated_at_ms"] = now_ms
	return session
func _refresh_self_checkout_live_session(actor: Person, session: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null or session.is_empty():
		return session

	var now_ms: int = int(Time.get_ticks_msec())
	var lane_state: String = str(session.get("state", "choose_machine")).strip_edges().to_lower()
	var assigned_machine_id: String = str(session.get("assigned_machine_id", "")).strip_edges()
	var queue_position: int = max(0, int(session.get("queue_position", 0)))
	var machines: Array = session.get("machines", []) if typeof(session.get("machines", [])) == TYPE_ARRAY else []
	var live_events: Array = session.get("live_events", []) if typeof(session.get("live_events", [])) == TYPE_ARRAY else []
	var lane_changed: bool = false
	var opened_machine_count: int = 0
	var available_count: int = 0
	var rng: RandomNumberGenerator = _self_checkout_live_rng(session, "live_tick")
	var store_id: String = str(session.get("store_id", "")).strip_edges()

	for index in range(machines.size()):
		if typeof(machines [index]) != TYPE_DICTIONARY:
			continue

		var machine: Dictionary = machines [index]
		var machine_id: String = str(machine.get("machine_id", "")).strip_edges()
		var status: String = str(machine.get("status", "available")).strip_edges().to_lower()

		if machine_id == assigned_machine_id and lane_state in ["payment_prompt", "paid"]:
			machines [index] = machine
			continue

		var expected_available_at_ms: int = int(machine.get("expected_available_at_ms", 0))
		var status_started_at_ms: int = int(machine.get("status_started_at_ms", now_ms))

		if status in ["in_use", "offline"] and expected_available_at_ms > 0 and now_ms >= expected_available_at_ms:
			var previous_status: String = status
			var departing_machine: Dictionary = machine.duplicate(true)

			machine = _self_checkout_prepare_machine_for_status(machine, "available", rng, now_ms, "")
			opened_machine_count += 1
			lane_changed = true

			if previous_status == "offline":
				live_events.append("%s comes back online." % str(machine.get("label", "A self-checkout machine")))
			else:
				live_events.append(_self_checkout_departure_event_for_machine(departing_machine, actor))

		elif status == "available":
			var open_time_ms: int = now_ms - status_started_at_ms
			if open_time_ms >= 4200:
				var take_roll: float = rng.randf()
				if take_roll < 0.18:
					var used_ids: Dictionary = _self_checkout_machine_occupant_ids(machines, actor)
					var occupant_profile: Dictionary = _self_checkout_pick_named_occupant_profile(store_id, rng, used_ids)
					var occupant_name: String = str(occupant_profile.get("name", "Unknown shopper")).strip_edges()

					machine = _self_checkout_prepare_machine_for_status(machine, "in_use", rng, now_ms, "%s is using this terminal." % occupant_name)
					machine = _self_checkout_apply_occupant_profile(machine, occupant_profile)
					machine = _self_checkout_apply_ambient_receipt(machine, store_id, occupant_profile, rng, actor)
					lane_changed = true

					live_events.append("%s gets taken by %s." % [
						str(machine.get("label", "A self-checkout machine")),
						occupant_name
					])

		if str(machine.get("status", "")).strip_edges().to_lower() == "available":
			available_count += 1

		machines [index] = machine

	var force_queue_advance: bool = bool(context.get("force_queue_advance", false))
	var last_queue_tick_ms: int = int(session.get("last_queue_tick_ms", 0))
	var queue_tick_due: bool = now_ms - last_queue_tick_ms >= 3500

	if lane_state == "waiting":
		if force_queue_advance or opened_machine_count > 0 or queue_tick_due:
			queue_position = max(0, queue_position - 1)
			session ["last_queue_tick_ms"] = now_ms
			lane_changed = true

			if queue_position > 0:
				live_events.append("The self-checkout line moves. %d shopper%s ahead." % [
					queue_position,
					"" if queue_position == 1 else "s"
				])
			else:
				lane_state = "choose_machine"
				live_events.append("I reach the front of the self-checkout line.")

	if lane_state == "choose_machine" and available_count <= 0 and assigned_machine_id == "":
		lane_state = "waiting"
		if queue_position <= 0:
			queue_position = int(rng.randi_range(1, 3))
		lane_changed = true
		live_events.append("All machines are busy again. I wait in line.")

	if live_events.size() > 10:
		live_events = live_events.slice(live_events.size() - 10, live_events.size())

	session ["machines"] = machines
	session ["state"] = lane_state
	session ["queue_position"] = queue_position
	session ["live_events"] = live_events
	session ["last_live_tick_ms"] = now_ms
	session ["updated_at_ms"] = now_ms if lane_changed else int(session.get("updated_at_ms", now_ms))

	return session

func tick_self_checkout_lane_for_actor(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var key: String = (
		_self_checkout_session_key(
			actor
		)
	)
	var session_raw: Variant = (
		grocery_self_checkout_sessions_by_actor_id.get(
			key,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	if session.is_empty():
		return {
			"success": false,
			"reason": "No active self-checkout session."
		}

	if not bool(
		session.get(
			"active",
			false
		)
	):
		return {
			"success": false,
			"reason": "Self-checkout is resident but not active."
		}

	var store_id: String = str(
		session.get(
			"store_id",
			""
		)
	).strip_edges()

	if not bool(
		session.get(
			"resident_ready",
			false
		)
	):
		session = (
			_prime_self_checkout_session_quantum(
				actor,
				store_id,
				context
			)
		)

	if not bool(
		session.get(
			"resident_ready",
			false
		)
	):
		grocery_self_checkout_sessions_by_actor_id [
			key
		] = session

		return {
			"success": true,
			"actor_id": int(actor.id),
			"store_id": store_id,
			"self_checkout_active": true,
			"self_checkout_state": str(
				session.get(
					"state",
					"warming"
				)
			),
			"queue_position": int(
				session.get(
					"queue_position",
					0
				)
			),
			"target_section": "self_checkout",
			"active_section_id": "self_checkout",
			"live_events": (
				session.get(
					"live_events",
					[]
				)
				if typeof(
					session.get(
						"live_events",
						[]
					)
				) == TYPE_ARRAY
				else []
			),
			"session": session.duplicate(true),
			"text": (
				"Self-checkout machines are publishing live."
			)
		}

	session = (
		_refresh_self_checkout_live_session(
			actor,
			session,
			context
		)
	)
	grocery_self_checkout_sessions_by_actor_id [
		key
	] = session

	return {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": str(
			session.get(
				"store_id",
				""
			)
		),
		"self_checkout_active": bool(
			session.get(
				"active",
				true
			)
		),
		"self_checkout_state": str(
			session.get(
				"state",
				""
			)
		),
		"queue_position": int(
			session.get(
				"queue_position",
				0
			)
		),
		"target_section": "self_checkout",
		"active_section_id": "self_checkout",
		"live_events": (
			session.get(
				"live_events",
				[]
			)
			if typeof(
				session.get(
					"live_events",
					[]
				)
			) == TYPE_ARRAY
			else []
		),
		"session": session.duplicate(true),
		"text": "The self-checkout lane updates live."
	}
func begin_self_checkout_lane(
		actor: Person,
		store_id: String = "",
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var cart: Dictionary = (
		_grocery_cart_for_actor(
			actor
		)
	)
	var items: Array = (
		cart.get(
			"items",
			[]
		)
		if typeof(
			cart.get(
				"items",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	if items.is_empty():
		return {
			"success": false,
			"reason": "My grocery cart is empty."
		}

	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		clean_store_id = str(
			cart.get(
				"store_id",
				context.get(
					"store_id",
					""
				)
			)
		).strip_edges()

	if clean_store_id == "":
		return {
			"success": false,
			"reason": (
				"I need to be inside a store before using self-checkout."
			)
		}

	var key: String = (
		_self_checkout_session_key(
			actor
		)
	)
	var session_raw: Variant = (
		grocery_self_checkout_sessions_by_actor_id.get(
			key,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		session.is_empty()
		or str(
			session.get(
				"store_id",
				""
			)
		) != clean_store_id
		or bool(
			session.get(
				"finished",
				false
			)
		)
	):
		session = {
			"actor_id": int(actor.id),
			"store_id": clean_store_id,
			"active": true,
			"finished": false,
			"state": "warming",
			"queue_position": 0,
			"machines": [],
			"assigned_machine_id": "",
			"payment_type": "",
			"confirmation_text": "",
			"resident_year": (
				int(gs.year)
				if gs != null
				else 0
			),
			"resident_ready": false,
			"machine_prime_cursor": 0,
			"machine_prime_target": (
				_self_checkout_machine_count_for_store(
					clean_store_id
				)
			),
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"updated_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	session ["active"] = true
	session ["finished"] = false
	session ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	var machines: Array = (
		session.get(
			"machines",
			[]
		)
		if typeof(
			session.get(
				"machines",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var resident_ready: bool = bool(
		session.get(
			"resident_ready",
			false
		)
	)
	var starting_state: String = "warming"
	var queue_position: int = 0
	var notice_text: String = (
		"Self-checkout is live. Its resident machines are publishing now."
	)

	if resident_ready:
		var available_machine: Dictionary = (
			_self_checkout_available_machine(
				{
					"machines": machines
				}
			)
		)

		if available_machine.is_empty():
			var rng: RandomNumberGenerator = (
				_grocery_shopper_rng(
					"%s|%d|self_checkout_queue|%d"
					% [
						clean_store_id,
						int(actor.id),
						int(
							Time.get_ticks_msec()
						)
					]
				)
			)
			queue_position = int(
				rng.randi_range(
					1,
					3
				)
			)
			starting_state = "waiting"
			notice_text = (
				"Every self-checkout machine is being used. I joined the line."
			)
		else:
			starting_state = "choose_machine"
			notice_text = (
				"Self-checkout is open. Pick an available machine."
			)

	session ["state"] = starting_state
	session ["queue_position"] = queue_position

	grocery_self_checkout_sessions_by_actor_id [
		key
	] = session

	return {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": clean_store_id,
		"self_checkout_active": true,
		"self_checkout_state": starting_state,
		"queue_position": queue_position,
		"target_section": "self_checkout",
		"audio_cue": "self_checkout_payment_prompt",
		"audio_cue_path": (
			_self_checkout_payment_prompt_audio_path()
		),
		"active_section_id": "self_checkout",
		"session": session.duplicate(true),
		"resident_ready": resident_ready,
		"text": notice_text
	}

func advance_self_checkout_lane(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var key: String = _self_checkout_session_key(actor)
	var session: Dictionary = grocery_self_checkout_sessions_by_actor_id.get(key, {}) if typeof(grocery_self_checkout_sessions_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return begin_self_checkout_lane(actor, str(context.get("store_id", "")), context)

	var tick_context: Dictionary = context.duplicate(true)
	tick_context ["force_queue_advance"] = true
	var tick_report: Dictionary = tick_self_checkout_lane_for_actor(actor, tick_context)
	if not bool(tick_report.get("success", false)):
		return tick_report

	var queue_position: int = int(tick_report.get("queue_position", 0))
	var state: String = str(tick_report.get("self_checkout_state", ""))

	if state == "choose_machine":
		tick_report ["text"] = "A self-checkout machine opened up."
	elif state == "waiting":
		tick_report ["text"] = "I moved up in the self-checkout line. %d shopper%s ahead of me." % [
			queue_position,
			"" if queue_position == 1 else "s"
		]

	return tick_report


func select_self_checkout_machine(actor: Person, machine_id: String, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var key: String = _self_checkout_session_key(actor)
	var session: Dictionary = grocery_self_checkout_sessions_by_actor_id.get(key, {}) if typeof(grocery_self_checkout_sessions_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return { "success": false, "reason": "I need to enter the self-checkout lane first."}



	var clean_machine_id: String = str(machine_id).strip_edges()
	var machine: Dictionary = _self_checkout_machine_by_id(session, clean_machine_id)
	if machine.is_empty():
		return { "success": false, "reason": "That self-checkout machine does not exist."}

	var machine_status: String = str(machine.get("status", "")).strip_edges().to_lower()
	if machine_status != "available":
		grocery_self_checkout_sessions_by_actor_id [key] = session

		return {
			"success": false,
			"actor_id": int(actor.id),
			"store_id": str(session.get("store_id", "")),
			"self_checkout_active": true,
			"self_checkout_state": str(session.get("state", "choose_machine")),
			"target_section": "self_checkout",
			"active_section_id": "self_checkout",
			"session": session.duplicate(true),
			"reason": "%s is not available yet." % str(machine.get("label", "That machine"))
		}

	session = _self_checkout_set_machine_status(session, clean_machine_id, "assigned", "Ready For Payment", "Me")
	session ["assigned_machine_id"] = clean_machine_id
	session ["state"] = "payment_prompt"
	session ["queue_position"] = 0
	session ["updated_at_ms"] = int(Time.get_ticks_msec())



	grocery_self_checkout_sessions_by_actor_id [key] = session

	return {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": str(session.get("store_id", "")),
		"self_checkout_active": true,
		"self_checkout_state": "payment_prompt",
		"assigned_machine_id": clean_machine_id,
		"target_section": "self_checkout",
		"active_section_id": "self_checkout",
		"session": session.duplicate(true),
		"audio_cue": "self_checkout_payment_prompt",
		"audio_cue_path": _self_checkout_payment_prompt_audio_path(),
		"text": "%s lights up and asks me to use cash or select a payment type." % str(machine.get("label", "The self-checkout machine"))
	}

func pay_self_checkout_machine(actor: Person, payment_type: String = "card", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var key: String = _self_checkout_session_key(actor)
	var session: Dictionary = grocery_self_checkout_sessions_by_actor_id.get(key, {}) if typeof(grocery_self_checkout_sessions_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return { "success": false, "reason": "I need to use a self-checkout machine first."}

	var assigned_machine_id: String = str(session.get("assigned_machine_id", "")).strip_edges()
	if assigned_machine_id == "":
		return { "success": false, "reason": "I need to choose an open self-checkout machine first."}

	var clean_payment_type: String = str(payment_type).strip_edges().to_lower()
	if clean_payment_type == "":
		clean_payment_type = "card"

	var checkout_report: Dictionary = checkout_cart_for_ui(actor, {
		"source": "self_checkout_machine",
		"checkout_lane": "self_checkout",
		"self_checkout_machine_id": assigned_machine_id,
		"payment_type": clean_payment_type,
		"context": context.duplicate(true)
	})

	if not bool(checkout_report.get("success", false)):
		return checkout_report

	var machine: Dictionary = _self_checkout_machine_by_id(session, assigned_machine_id)
	var machine_label: String = str(machine.get("label", "Self Checkout")).strip_edges()
	var confirmation_text: String = "%s confirms the %s payment. Receipt accepted. I can exit the store." % [
		machine_label,
		clean_payment_type.replace("_", " ")
	]

	session = _self_checkout_set_machine_status(session, assigned_machine_id, "complete", "Payment Complete", "Me")
	session ["state"] = "paid"
	session ["payment_type"] = clean_payment_type
	session ["confirmation_text"] = confirmation_text
	session ["checkout_report"] = checkout_report.duplicate(true)
	session ["exit_ready"] = true
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_self_checkout_sessions_by_actor_id [key] = session

	var report: Dictionary = checkout_report.duplicate(true)
	report ["self_checkout_active"] = true
	report ["self_checkout_state"] = "paid"
	report ["assigned_machine_id"] = assigned_machine_id
	report ["payment_type"] = clean_payment_type
	report ["target_section"] = "self_checkout"
	report ["active_section_id"] = "self_checkout"
	report ["session"] = session.duplicate(true)
	report ["text"] = confirmation_text
	report ["show_popup"] = true
	report ["popup_title"] = "Self Checkout"
	report ["popup_text"] = confirmation_text
	report ["popup_footer"] = "Exit the store when ready."

	last_report = report.duplicate(true)
	return report


func finish_self_checkout_exit(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var key: String = _self_checkout_session_key(actor)
	var session: Dictionary = grocery_self_checkout_sessions_by_actor_id.get(key, {}) if typeof(grocery_self_checkout_sessions_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	grocery_self_checkout_sessions_by_actor_id.erase(key)

	return {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": str(session.get("store_id", context.get("store_id", ""))) if not session.is_empty() else str(context.get("store_id", "")),
		"self_checkout_active": false,
		"self_checkout_state": "",
		"target_section": "stores",
		"active_section_id": "stores",
		"text": "I took my receipt, bagged groceries, and exited the store."
	}


func get_grocery_self_checkout_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var session_key: String = (
		_self_checkout_session_key(
			actor
		)
	)
	var session_raw: Variant = (
			grocery_self_checkout_sessions_by_actor_id.get(
				session_key,
				{}
			)
	)
	var session: Dictionary = (
			(session_raw as Dictionary).duplicate(true)
			if typeof(session_raw) == TYPE_DICTIONARY
			else {}
	)
	var out: Array = []

	if session.is_empty():
		out.append({
			"label": "Self Checkout Lane",
			"description": "Press Self Checkout from the cart to enter the lane.",
			"kind": "grocery_self_checkout_empty"
		})
		return out

	var lane_state: String = str(session.get("state", "choose_machine")).strip_edges().to_lower()
	var queue_position: int = int(session.get("queue_position", 0))
	var machines: Array = session.get("machines", []) if typeof(session.get("machines", [])) == TYPE_ARRAY else []
	var live_events: Array = session.get("live_events", []) if typeof(session.get("live_events", [])) == TYPE_ARRAY else []
	var assigned_machine_id: String = str(session.get("assigned_machine_id", "")).strip_edges()
	var machine_live_lines_by_id: Dictionary = {}
	var global_live_lines: Array = []
	if lane_state == "warming":
		out.append({
			"label": "Machines Publishing",
			"description": (
				"The self-checkout lane is already active. "
				+ "%d of %d resident machines have published so far. "
				+ "The UI remains interactive while the remaining machines arrive."
			) % [
				int(
					session.get(
						"machine_prime_cursor",
						machines.size()
					)
				),
				int(
					session.get(
						"machine_prime_target",
						machines.size()
					)
				)
			],
			"kind": "grocery_self_checkout_resident_progress"
		})
	for raw_event in live_events:
		var event_text: String = str(raw_event).strip_edges()
		if event_text == "":
			continue

		var matched_machine_id: String = ""
		for raw_machine_for_event in machines:
			if typeof(raw_machine_for_event) != TYPE_DICTIONARY:
				continue

			var event_machine: Dictionary = raw_machine_for_event
			var event_machine_id: String = str(event_machine.get("machine_id", "")).strip_edges()
			var event_machine_label: String = str(event_machine.get("label", "")).strip_edges()
			if event_machine_id == "" or event_machine_label == "":
				continue

			if event_text.find(event_machine_label) != -1:
				matched_machine_id = event_machine_id
				break

		if matched_machine_id != "":
			var machine_lines: Array = machine_live_lines_by_id.get(matched_machine_id, []) if typeof(machine_live_lines_by_id.get(matched_machine_id, [])) == TYPE_ARRAY else []
			machine_lines.append(event_text)
			machine_live_lines_by_id [matched_machine_id] = machine_lines
		else:
			global_live_lines.append(event_text)

	if not global_live_lines.is_empty():
		var fallback_machine_id: String = assigned_machine_id
		if fallback_machine_id == "":
			for raw_fallback_machine in machines:
				if typeof(raw_fallback_machine) != TYPE_DICTIONARY:
					continue

				var fallback_machine: Dictionary = raw_fallback_machine
				if str(fallback_machine.get("status", "")).strip_edges().to_lower() == "available":
					fallback_machine_id = str(fallback_machine.get("machine_id", "")).strip_edges()
					break

		if fallback_machine_id == "" and not machines.is_empty() and typeof(machines [0]) == TYPE_DICTIONARY:
			fallback_machine_id = str((machines [0] as Dictionary).get("machine_id", "")).strip_edges()

		if fallback_machine_id != "":
			var fallback_lines: Array = machine_live_lines_by_id.get(fallback_machine_id, []) if typeof(machine_live_lines_by_id.get(fallback_machine_id, [])) == TYPE_ARRAY else []
			for global_line in global_live_lines:
				fallback_lines.append(str(global_line))
			machine_live_lines_by_id [fallback_machine_id] = fallback_lines

	out.append({
		"label": "Self Checkout Lane",
		"description": "Scanner beds, bagging scales, card readers, blinking assistance lights, and terminals updating live as shoppers finish, machines open, and the line moves.",
		"kind": "grocery_self_checkout_header",
		"store_id": str(session.get("store_id", "")),
		"state": lane_state
	})

	if lane_state == "waiting":
		out.append({
			"label": "Waiting In Line",
			"description": "%d shopper%s ahead of me. Watch the terminals below for live movement, then press Wait My Turn when the line advances." % [
				queue_position,
				"" if queue_position == 1 else "s"
			],
			"kind": "grocery_self_checkout_queue",
			"actions": [
				{
					"id": "grocery_self_checkout_wait",
					"label": "Wait My Turn",
					"kind": "packet",
					"style": "primary"
				},
				{
					"id": "grocery_back:cart",
					"label": "Back To Cart",
					"kind": "packet",
					"style": "secondary"
				}
			]
		})

	for raw_machine in machines:
		if typeof(raw_machine) != TYPE_DICTIONARY:
			continue

		var machine: Dictionary = raw_machine
		var machine_id: String = str(machine.get("machine_id", "")).strip_edges()
		var status: String = str(machine.get("status", "")).strip_edges().to_lower()
		var status_label: String = str(machine.get("status_label", status.capitalize())).strip_edges()
		var occupant_label: String = str(machine.get("occupant_label", "")).strip_edges()
		var actions: Array = []

		if lane_state == "choose_machine" and status == "available":
			actions.append({
				"id": "grocery_self_checkout_machine:%s" % machine_id,
				"label": "Use This Machine",
				"kind": "packet",
				"style": "success"
			})

		if lane_state == "payment_prompt" and machine_id == assigned_machine_id:
			status_label = "Ready For Payment"
			actions.append({
				"id": "grocery_self_checkout_pay:debit_card",
				"label": "Pay With Debit Card",
				"kind": "packet",
				"style": "success"
			})
			actions.append({
				"id": "grocery_self_checkout_pay:credit_card",
				"label": "Pay With Credit Card",
				"kind": "packet",
				"style": "success"
			})
			actions.append({
				"id": "grocery_self_checkout_pay:cash",
				"label": "Pay With Cash",
				"kind": "packet",
				"style": "primary"
			})
			actions.append({
				"id": "grocery_self_checkout_pay:digital_wallet",
				"label": "Pay With Digital Wallet",
				"kind": "packet",
				"style": "primary"
			})

		if lane_state == "paid" and machine_id == assigned_machine_id:
			status_label = "Payment Complete"
			actions.append({
				"id": "grocery_self_checkout_exit",
				"label": "Exit Store",
				"kind": "packet",
				"style": "success"
			})

		var machine_description: String = ""
		match status:
			"available":
				machine_description = "Scanner ready, bagging scale clear, payment terminal waiting."
			"in_use":
				machine_description = occupant_label if occupant_label != "" else "A shopper is scanning items here."
			"offline":
				machine_description = "The screen is dim and the assistance light is waiting for a store worker."
			"assigned":
				machine_description = "The terminal says: Use cash or select payment type. The scanner bed is quiet, the receipt printer is armed, and the payment terminal is blinking."
			"complete":
				machine_description = str(session.get("confirmation_text", "The self-checkout machine confirms the payment."))
			_:
				machine_description = occupant_label if occupant_label != "" else "The terminal is active."

		var machine_live_lines: Array = machine_live_lines_by_id.get(machine_id, []) if typeof(machine_live_lines_by_id.get(machine_id, [])) == TYPE_ARRAY else []
		if not machine_live_lines.is_empty():
			var live_text: String = ""
			for raw_live_line in machine_live_lines:
				if live_text != "":
					live_text += "\n"
				live_text += str(raw_live_line)

			machine_description = "Live terminal update:\n%s\n\n%s" % [
				live_text,
				machine_description
			]

		out.append({
			"label": "%s • %s" % [
				str(machine.get("label", "Self Checkout")),
				status_label
			],
			"description": machine_description,
			"kind": "grocery_self_checkout_machine",
			"machine_id": machine_id,
			"status": status,
			"state": lane_state,
			"assigned": machine_id == assigned_machine_id,
			"actions": actions
		})

	return out
func add_to_cart(actor: Person, store_id: String, food_id: String, quantity: int = 1, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var store: Dictionary = get_store(store_id)
	if store.is_empty():
		return { "success": false, "reason": "Grocery store not found."}

	var item: Dictionary = _find_store_item(store, food_id)
	if item.is_empty():
		return { "success": false, "reason": "Grocery item not found."}

	var price_breakdown: Dictionary = _grocery_item_price_breakdown(store, item, actor)
	var unit_shelf_price: float = float(price_breakdown.get("subtotal", float(item.get("price", 0.0))))
	var unit_tax: float = float(price_breakdown.get("tax", 0.0))
	var unit_after_tax: float = float(price_breakdown.get("total", unit_shelf_price))
	var goldleaf_discount_applied: bool = bool(price_breakdown.get("goldleaf_premium_discount_applied", false))

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	if str(cart.get("store_id", "")).strip_edges() != "" and str(cart.get("store_id", "")) != store_id:
		cart = {
			"store_id": store_id,
			"items": [],
			"created_at_ms": int(Time.get_ticks_msec())
		}

	cart ["store_id"] = store_id
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	var found_existing: bool = false

	for i in range(items.size()):
		if typeof(items [i]) != TYPE_DICTIONARY:
			continue

		var existing: Dictionary = items [i]
		if str(existing.get("id", "")) == food_id:
			existing ["quantity"] = int(existing.get("quantity", 1)) + max(1, int(quantity))
			existing ["base_price"] = float(item.get("price", 0.0))
			existing ["price"] = unit_shelf_price
			existing ["purchase_price"] = unit_shelf_price
			existing ["unit_price_paid"] = unit_after_tax
			existing ["price_after_tax"] = unit_after_tax
			existing ["tax_paid"] = unit_tax
			existing ["value"] = unit_after_tax
			existing ["goldleaf_premium_discount_applied"] = goldleaf_discount_applied
			existing ["base_total_before_goldleaf"] = float(price_breakdown.get("base_total", item.get("price", 0.0)))
			existing ["goldleaf_premium_price_label"] = str(price_breakdown.get("goldleaf_premium_label", ""))
			existing ["tax_exempt"] = goldleaf_discount_applied or bool(existing.get("tax_exempt", false))
			existing ["price_after_tax_locked"] = goldleaf_discount_applied or bool(existing.get("price_after_tax_locked", false))
			items [i] = existing
			found_existing = true
			break

	if not found_existing:
		var cart_item: Dictionary = item.duplicate(true)
		cart_item ["quantity"] = max(1, int(quantity))
		cart_item ["store_id"] = store_id
		cart_item ["aisle_id"] = _grocery_aisle_id_for_item(cart_item)
		cart_item ["base_price"] = float(item.get("price", 0.0))
		cart_item ["price"] = unit_shelf_price
		cart_item ["base_total_before_goldleaf"] = float(price_breakdown.get("base_total", item.get("price", 0.0)))
		cart_item ["goldleaf_premium_price_label"] = str(price_breakdown.get("goldleaf_premium_label", ""))
		cart_item ["purchase_price"] = unit_shelf_price
		cart_item ["unit_price_paid"] = unit_after_tax
		cart_item ["price_after_tax"] = unit_after_tax
		cart_item ["tax_paid"] = unit_tax
		cart_item ["value"] = unit_after_tax
		cart_item ["goldleaf_premium_discount_applied"] = goldleaf_discount_applied
		cart_item ["tax_exempt"] = goldleaf_discount_applied or bool(cart_item.get("tax_exempt", false))
		cart_item ["price_after_tax_locked"] = goldleaf_discount_applied or bool(cart_item.get("price_after_tax_locked", false))
		items.append(cart_item)

	cart ["items"] = items
	cart ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_carts_by_actor_id [str(int(actor.id))] = cart

	var discount_sentence: String = ""
	if goldleaf_discount_applied:
		discount_sentence = " Goldleaf Premium took 50% off and removed the tax."

	var cart_item_count: int = 0
	for raw_cart_item in items:
		if typeof(raw_cart_item) != TYPE_DICTIONARY:
			continue
		var cart_item: Dictionary = raw_cart_item
		cart_item_count += max(1, int(cart_item.get("quantity", 1)))

	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": store_id,
		"food_id": food_id,
		"aisle_id": _grocery_aisle_id_for_item(item),
		"item_name": str(item.get("name", "food")),
		"quantity": max(1, int(quantity)),
		"unit_shelf_price": unit_shelf_price,
		"unit_tax": unit_tax,
		"unit_price_paid": unit_after_tax,
		"added_total_delta": unit_after_tax * float(max(1, int(quantity))),
		"cart_total": _grocery_cart_total(cart),
		"cart_item_count": cart_item_count,
		"goldleaf_premium_discount_applied": goldleaf_discount_applied,
		"updated_at_ms": int(Time.get_ticks_msec()),
		"text": "I added %s to my cart.%s" % [str(item.get("name", "food")), discount_sentence]
	}
	last_report = report.duplicate(true)
	return report

func checkout_cart(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	if items.is_empty():
		return { "success": false, "reason": "My grocery cart is empty."}

	var total: float = _grocery_cart_total(cart)
	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, total, {
		"source": "grocery_checkout_cart",
		"cart": cart.duplicate(true),
		"context": context.duplicate(true)
	})
	if not bool(pay_report.get("success", false)):
		return pay_report

	var pantry_reports: Array = []
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var qty: int = max(1, int(item.get("quantity", 1)))
		pantry_reports.append(gs.food_engine.add_pantry_item(actor, item, qty, {
			"source": "grocery_checkout_cart",
			"store_id": str(cart.get("store_id", ""))
		}))

	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": str(cart.get("store_id", "")),
		"total": total,
		"item_stack_count": items.size(),
		"payment_report": pay_report.duplicate(true),
		"pantry_reports": pantry_reports,
		"text": "I paid $%.2f and brought the groceries home." % total
	}

	grocery_ledger.append(report.duplicate(true))
	grocery_carts_by_actor_id.erase(str(int(actor.id)))
	last_report = report.duplicate(true)
	return report
func checkout_cart_for_ui(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	if items.is_empty():
		return { "success": false, "reason": "My grocery cart is empty."}

	var actor_id: int = int(actor.id)
	var cart_snapshot: Dictionary = cart.duplicate(true)
	var total: float = _grocery_cart_total(cart_snapshot)
	var checkout_lane: String = str(context.get("checkout_lane", "cashier")).strip_edges().to_lower()
	if checkout_lane == "":
		checkout_lane = "cashier"

	var checkout_store_id: String = str(cart_snapshot.get("store_id", "")).strip_edges()
	reset_grocery_cart_for_actor(actor, checkout_store_id, {
		"reason": "checkout_started",
		"source": "checkout_cart_for_ui"
	})

	var active_cashier: Dictionary = _grocery_active_cashier_for_store(checkout_store_id, context)
	var cashier_name: String = str(active_cashier.get("name", "the cashier")).strip_edges()
	if cashier_name == "":
		cashier_name = "the cashier"

	var checkout_text: String = "I paid %s at %s's lane and the grocery checkout is being packed into my pantry." % [
		_goldleaf_format_money_for_actor(total, actor),
		cashier_name
	]

	if checkout_lane == "self_checkout":
		checkout_text = "I used self-checkout, paid %s, and bagged my groceries myself." % _goldleaf_format_money_for_actor(total, actor)

	var goldleaf_receipt_lines: Array = []
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var receipt_item: Dictionary = raw_item
		if not bool(receipt_item.get("goldleaf_premium_discount_applied", false)):
			continue

		var receipt_qty: int = max(1, int(receipt_item.get("quantity", 1)))
		var receipt_line: Dictionary = _grocery_line_item_price_breakdown(get_store(checkout_store_id), receipt_item, receipt_qty)
		goldleaf_receipt_lines.append("%s ×%d\n%s\n%s (Goldleaf Premium)" % [
			str(receipt_item.get("name", "Food")),
			receipt_qty,
			_goldleaf_format_money_for_actor(float(receipt_item.get("base_total_before_goldleaf", receipt_line.get("total", 0.0))) * float(receipt_qty), actor),
			_goldleaf_format_money_for_actor(float(receipt_line.get("total", 0.0)), actor)
		])

	var pending_report: Dictionary = {
		"success": true,
		"deferred": true,
		"actor_id": actor_id,
		"store_id": checkout_store_id,
		"checkout_lane": checkout_lane,
		"cashier": active_cashier.duplicate(true),
		"cashier_name": cashier_name,
		"total": total,
		"goldleaf_receipt_lines": goldleaf_receipt_lines.duplicate(true),
		"item_stack_count": items.size(),
		"text": checkout_text,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_report = pending_report.duplicate(true)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["belongings_inventory_dirty_actor_id"] = actor_id
		gs.scenario_state ["belongings_inventory_dirty_reason"] = "grocery_checkout_started"
		gs.scenario_state ["belongings_inventory_dirty_at_ms"] = int(Time.get_ticks_msec())

	call_deferred("_commit_grocery_checkout_snapshot", actor_id, cart_snapshot, context.duplicate(true))
	return pending_report

func _commit_grocery_checkout_snapshot(actor_id: int, cart_snapshot: Dictionary, context: Dictionary = {}) -> void:
	var actor: Person = null

	if gs != null and gs.has_method("get_npc_by_id"):
		actor = gs.get_npc_by_id(int(actor_id))

	if actor == null and gs != null and gs.player != null and int(gs.player.id) == int(actor_id):
		actor = gs.player

	if actor == null or gs == null or gs.food_engine == null:
		grocery_carts_by_actor_id [str(int(actor_id))] = cart_snapshot.duplicate(true)
		last_report = {
			"success": false,
			"deferred": true,
			"actor_id": int(actor_id),
			"reason": "Grocery checkout could not find the actor or FoodEngine.",
			"created_at_ms": int(Time.get_ticks_msec())
		}
		return

	var items: Array = cart_snapshot.get("items", []) if typeof(cart_snapshot.get("items", [])) == TYPE_ARRAY else []
	if items.is_empty():
		last_report = {
			"success": false,
			"deferred": true,
			"actor_id": int(actor_id),
			"reason": "Deferred grocery cart was empty.",
			"created_at_ms": int(Time.get_ticks_msec())
		}
		return

	var total: float = _grocery_cart_total(cart_snapshot)
	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, total, {
		"source": "grocery_checkout_cart_deferred",
		"cart": cart_snapshot.duplicate(true),
		"context": context.duplicate(true)
	})

	if not bool(pay_report.get("success", false)):
		grocery_carts_by_actor_id [str(int(actor_id))] = cart_snapshot.duplicate(true)
		last_report = {
			"success": false,
			"deferred": true,
			"actor_id": int(actor_id),
			"store_id": str(cart_snapshot.get("store_id", "")),
			"total": total,
			"payment_report": pay_report.duplicate(true),
			"reason": str(pay_report.get("reason", "Payment failed.")),
			"created_at_ms": int(Time.get_ticks_msec())
		}
		return

	call_deferred(
		"_commit_grocery_checkout_pantry_batch",
		actor_id,
		cart_snapshot,
		context,
		pay_report,
		[],
		0
)


func _commit_grocery_checkout_pantry_batch(
		actor_id: int,
		cart_snapshot: Dictionary,
		context: Dictionary,
		pay_report: Dictionary,
		pantry_reports: Array,
		start_index: int
) -> void:
	var actor: Person = null

	if (
		gs != null
		and gs.has_method(
			"get_npc_by_id"
		)
	):
		actor = gs.get_npc_by_id(
			int(actor_id)
		)

	if (
		actor == null
		and gs != null
		and gs.player != null
		and int(gs.player.id) == int(actor_id)
	):
		actor = gs.player

	if (
		actor == null
		or gs == null
		or gs.food_engine == null
	):
		return

	var items: Array = (
		cart_snapshot.get(
			"items",
			[]
		)
		if typeof(
			cart_snapshot.get(
				"items",
				[]
			)
		) == TYPE_ARRAY
		else []
	)


	var batch_limit: int = 1
	var end_index: int = min(
		items.size(),
		int(start_index) + batch_limit
	)

	for i in range(
		int(start_index),
		end_index
	):
		if (
			i < 0
			or i >= items.size()
		):
			continue

		if typeof(items [i]) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = items [i]
		var qty: int = max(
			1,
			int(
				item.get(
					"quantity",
					1
				)
			)
		)
		pantry_reports.append(
			gs.food_engine.add_pantry_item(
				actor,
				item,
				qty,
				{
					"source": (
						"grocery_checkout_cart_deferred"
					),
					"store_id": str(
						cart_snapshot.get(
							"store_id",
							""
						)
					),
					"actor_id": int(actor_id),
					"context": context
				}
			)
		)

	if end_index < items.size():



		call_deferred(
			"_commit_grocery_checkout_pantry_batch",
			actor_id,
			cart_snapshot,
			context,
			pay_report,
			pantry_reports,
			end_index
		)
		return

	var total: float = (
		_grocery_cart_total(
			cart_snapshot
		)
	)
	var report: Dictionary = {
		"success": true,
		"deferred": true,
		"actor_id": int(actor_id),
		"store_id": str(
			cart_snapshot.get(
				"store_id",
				""
			)
		),
		"total": total,
		"item_stack_count": items.size(),
		"payment_report": pay_report.duplicate(true),
		"pantry_reports": pantry_reports.duplicate(true),
		"text": (
			"I paid $%.2f and brought the groceries home."
			% total
		),
		"completed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	grocery_ledger.append(
		report.duplicate(true)
	)
	last_report = report.duplicate(true)

	reset_grocery_cart_for_actor(
		actor,
		str(
			cart_snapshot.get(
				"store_id",
				""
			)
		),
		{
			"reason": "checkout_completed",
			"source": (
				"_commit_grocery_checkout_pantry_batch"
			)
		}
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"belongings_inventory_dirty_actor_id"
		] = int(actor_id)
		gs.scenario_state [
			"belongings_inventory_dirty_reason"
		] = "grocery_checkout_completed"
		gs.scenario_state [
			"belongings_inventory_dirty_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"last_grocery_checkout_commit_report"
		] = report.duplicate(true)
func shoplift_cart(actor: Person, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var cart: Dictionary = _grocery_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	if items.is_empty():
		return { "success": false, "reason": "My grocery cart is empty."}

	var total: float = _grocery_cart_total(cart)
	var rng:= RandomNumberGenerator.new()
	rng.seed = int(abs(hash("%s|%s|%s|shoplift" % [str(int(actor.id)), str(gs.year if gs != null else 0), str(Time.get_ticks_msec())])))
	var caught_chance: float = clamp(0.18 + (total / 240.0), 0.18, 0.82)
	var caught: bool = rng.randf() <= caught_chance

	var pantry_reports: Array = []
	if not caught:
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = raw_item
			var qty: int = max(1, int(item.get("quantity", 1)))
			pantry_reports.append(gs.food_engine.add_pantry_item(actor, item, qty, {
				"source": "grocery_shoplift",
				"store_id": str(cart.get("store_id", ""))
			}))

	var report: Dictionary = {
		"success": not caught,
		"actor_id": int(actor.id),
		"store_id": str(cart.get("store_id", "")),
		"total": total,
		"caught": caught,
		"crime_type": "shoplifting",
		"pantry_reports": pantry_reports,
		"text": "I slipped out with the groceries." if not caught else "I tried to shoplift, but the store caught me."
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_criminal_behavior_signal"] = {
			"type": "shoplifting",
			"actor_id": int(actor.id),
			"store_id": str(cart.get("store_id", "")),
			"caught": caught,
			"value": total,
			"year": int(gs.year),
			"at_ms": int(Time.get_ticks_msec())
		}

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit("crime.shoplifting_attempted", report.duplicate(true))

	grocery_ledger.append(report.duplicate(true))
	grocery_carts_by_actor_id.erase(str(int(actor.id)))
	last_report = report.duplicate(true)
	return report
func anchor_control_switch_origin_actor_in_grocery_store(previous_actor_id: int, store_id: String, aisle_id: String = "", context: Dictionary = {}) -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()
	if clean_store_id == "":
		return { "success": false, "reason": "No grocery store supplied for previous actor anchoring."}

	var previous_actor: Person = null
	if gs != null and gs.has_method("get_npc_by_id"):
		previous_actor = gs.get_npc_by_id(int(previous_actor_id))
	if previous_actor == null and gs != null and gs.has_method("get_or_reactivate_npc_by_id"):
		previous_actor = gs.get_or_reactivate_npc_by_id(int(previous_actor_id))
	if previous_actor == null:
		return { "success": false, "reason": "Previous controlled actor could not be resolved."}

	var clean_aisle_id: String = str(aisle_id).strip_edges()
	if clean_aisle_id == "":
		clean_aisle_id = first_aisle_id_for_store(clean_store_id)

	var session: Dictionary = start_grocery_store_realtime_session(clean_store_id, clean_aisle_id, context)
	var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
	var key: String = str(int(previous_actor.id))
	var now_ms: int = int(Time.get_ticks_msec())
	var cart: Dictionary = _grocery_cart_for_actor(previous_actor)

	var shopper: Dictionary = shoppers.get(key, {}) if typeof(shoppers.get(key, {})) == TYPE_DICTIONARY else {}
	if shopper.is_empty():
		shopper = {
			"person_id": int(previous_actor.id),
			"shard_id": "",
			"name": _grocery_person_name(previous_actor),
			"profession": _grocery_person_profession(previous_actor),
			"identity_state": "materialized",
			"presence_kind": "recently_controlled_actor",
			"simulation_depth": "complete",
			"aisle_id": clean_aisle_id,
			"store_id": clean_store_id,
			"entered_at_ms": now_ms,
			"ambient_generated": false,
			"materialized_person_id": int(previous_actor.id),
			"crbs": {
				"visibility_state": "visible",
				"interaction_state": "live",
				"execution_state": "complete"
			},
			"cje": {
				"status": "control_switch_origin_actor",
				"question": "Why are they still here?",
				"answer": "The player was controlling them moments ago, so their body remains in the store."
			},
			"rias": {
				"anchored": true,
				"anchor_id": "npc_%d" % int(previous_actor.id),
				"anchor_rule": "Previous controlled actor remains spatially present after control switch."
			}
		}

	shopper ["name"] = _grocery_person_name(previous_actor)
	shopper ["profession"] = _grocery_person_profession(previous_actor)
	shopper ["aisle_id"] = clean_aisle_id
	shopper ["store_id"] = clean_store_id
	shopper ["shopping_state"] = "lingering"
	shopper ["left_store"] = false
	shopper ["updated_at_ms"] = now_ms
	shopper ["linger_until_ms"] = now_ms + int(context.get("linger_ms", 45000))
	shopper ["next_behavior_shift_ms"] = now_ms + 9000
	shopper ["cart_items"] = cart.get("items", []).duplicate(true) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	shopper ["cart_total"] = _grocery_cart_total(cart)
	shopper ["cart_item_count"] = _grocery_cart_item_count(cart)
	shopper ["last_presence_reason"] = "recent_control_switch_origin"

	shoppers [key] = shopper
	session ["shoppers"] = shoppers
	session ["updated_at_ms"] = now_ms
	grocery_shopper_sessions_by_store_id [clean_store_id] = session

	return {
		"success": true,
		"actor_id": int(previous_actor.id),
		"store_id": clean_store_id,
		"aisle_id": clean_aisle_id,
		"text": "%s stays in the store for a while after the control switch." % _grocery_person_name(previous_actor)
	}
func transfer_grocery_shopper_cart_to_actor(actor: Person, store_id: String, aisle_id: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var clean_store_id: String = str(store_id).strip_edges()
	var clean_aisle_id: String = str(aisle_id).strip_edges()

	if clean_store_id == "":
		clean_store_id = _grocery_find_store_id_for_shopper_id(int(actor.id))

	if clean_store_id == "":
		return { "success": false, "reason": "Could not resolve grocery store for switched shopper."}

	var shopper: Dictionary = _grocery_find_shopper_snapshot_for_actor(int(actor.id), clean_store_id)
	if shopper.is_empty():
		var existing_cart: Dictionary = _grocery_cart_for_actor(actor)
		existing_cart ["store_id"] = clean_store_id
		existing_cart ["updated_at_ms"] = int(Time.get_ticks_msec())
		grocery_carts_by_actor_id [str(int(actor.id))] = existing_cart
		return {
			"success": true,
			"actor_id": int(actor.id),
			"store_id": clean_store_id,
			"cart_total": _grocery_cart_total(existing_cart),
			"cart_item_count": _grocery_cart_item_count(existing_cart),
			"reason": "Actor did not have an active shopper snapshot; preserved actor cart."
		}

	shopper = _grocery_normalize_shopper_cart_fields(shopper)
	var cart_items: Array = _grocery_actor_cart_items_from_shopper_snapshot(shopper, clean_store_id, clean_aisle_id, actor)
	var cart: Dictionary = {
		"store_id": clean_store_id,
		"items": cart_items,
		"created_at_ms": int(shopper.get("entered_at_ms", Time.get_ticks_msec())),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": "grocery_shopper_session_transfer",
		"transfer_context": context.duplicate(true)
	}

	grocery_carts_by_actor_id [str(int(actor.id))] = cart

	_grocery_mark_shopper_cart_transferred(int(actor.id), clean_store_id)

	return {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": clean_store_id,
		"aisle_id": clean_aisle_id,
		"cart_total": _grocery_cart_total(cart),
		"cart_item_count": _grocery_cart_item_count(cart),
		"text": "I kept the cart I already had while shopping."
	}


func _grocery_find_shopper_snapshot_for_actor(actor_id: int, store_id: String = "") -> Dictionary:
	var target_key: String = str(int(actor_id))
	var clean_store_id: String = str(store_id).strip_edges()

	for raw_store_id in grocery_shopper_sessions_by_store_id.keys():
		var session_store_id: String = str(raw_store_id).strip_edges()
		if clean_store_id != "" and session_store_id != clean_store_id:
			continue

		var session: Dictionary = grocery_shopper_sessions_by_store_id.get(session_store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(session_store_id, {})) == TYPE_DICTIONARY else {}
		var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
		if shoppers.has(target_key):
			var shopper: Dictionary = shoppers.get(target_key, {}) if typeof(shoppers.get(target_key, {})) == TYPE_DICTIONARY else {}
			return shopper.duplicate(true)

	return {}


func _grocery_actor_cart_items_from_shopper_snapshot(shopper: Dictionary, store_id: String, aisle_id: String, actor: Person) -> Array:
	var out: Array = []
	var raw_cart_items: Array = shopper.get("cart_items", []) if typeof(shopper.get("cart_items", [])) == TYPE_ARRAY else []
	var known_total: float = 0.0

	for raw_item in raw_cart_items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = (raw_item as Dictionary).duplicate(true)
		var quantity: int = max(1, int(item.get("quantity", 1)))
		var price: float = snapped(float(item.get("price_after_tax", item.get("price", item.get("value", 0.0)))), 0.01)

		item ["quantity"] = quantity
		item ["store_id"] = store_id
		item ["aisle_id"] = str(item.get("aisle_id", aisle_id))
		item ["price"] = price
		item ["purchase_price"] = price
		item ["unit_price_paid"] = price
		item ["price_after_tax"] = price
		item ["tax_paid"] = 0.0
		item ["value"] = price
		item ["tax_exempt"] = true
		item ["price_after_tax_locked"] = true
		item ["source"] = "grocery_shopper_session_transfer_item"

		known_total += price * float(quantity)
		out.append(item)

	var shopper_total: float = snapped(float(shopper.get("cart_total", 0.0)), 0.01)
	var remainder: float = snapped(max(0.0, shopper_total - known_total), 0.01)

	if out.is_empty() or remainder >= 0.5:
		out.append({
			"id": "ambient_grocery_cart_bundle_%d" % int(actor.id),
			"name": "Groceries already in the cart",
			"category": "ambient_grocery_cart",
			"store_id": store_id,
			"aisle_id": aisle_id,
			"quantity": 1,
			"price": remainder if remainder >= 0.5 else max(0.01, shopper_total),
			"purchase_price": remainder if remainder >= 0.5 else max(0.01, shopper_total),
			"unit_price_paid": remainder if remainder >= 0.5 else max(0.01, shopper_total),
			"price_after_tax": remainder if remainder >= 0.5 else max(0.01, shopper_total),
			"tax_paid": 0.0,
			"value": remainder if remainder >= 0.5 else max(0.01, shopper_total),
			"tax_exempt": true,
			"price_after_tax_locked": true,
			"source": "grocery_shopper_session_transfer_bundle",
			"description": "Items this shopper had already picked before the player took control."
		})

	return out
func reset_grocery_cart_for_actor(actor: Person, store_id: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var actor_id: int = int(actor.id)
	var clean_store_id: String = str(store_id).strip_edges()

	if clean_store_id == "":
		clean_store_id = _grocery_find_store_id_for_shopper_id(actor_id)

	grocery_carts_by_actor_id.erase(str(actor_id))

	if clean_store_id != "":
		_grocery_clear_shopper_snapshot_cart_for_actor(actor_id, clean_store_id, str(context.get("reason", "cart_reset")))

	return {
		"success": true,
		"actor_id": actor_id,
		"store_id": clean_store_id,
		"reason": str(context.get("reason", "cart_reset")),
		"reset_at_ms": int(Time.get_ticks_msec())
	}


func _grocery_clear_shopper_snapshot_cart_for_actor(actor_id: int, store_id: String = "", reason: String = "cart_reset") -> void:
	var clean_store_id: String = str(store_id).strip_edges()
	var actor_key: String = str(int(actor_id))

	for raw_store_id in grocery_shopper_sessions_by_store_id.keys():
		var session_store_id: String = str(raw_store_id).strip_edges()
		if clean_store_id != "" and session_store_id != clean_store_id:
			continue

		var session: Dictionary = grocery_shopper_sessions_by_store_id.get(session_store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(session_store_id, {})) == TYPE_DICTIONARY else {}
		if session.is_empty():
			continue

		var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
		if not shoppers.has(actor_key):
			continue

		var shopper: Dictionary = shoppers.get(actor_key, {}) if typeof(shoppers.get(actor_key, {})) == TYPE_DICTIONARY else {}
		shopper ["cart_items"] = []
		shopper ["cart_total"] = 0.0
		shopper ["cart_item_count"] = 0
		shopper ["last_cart_addition"] = {}
		shopper ["last_cart_addition_text"] = ""
		shopper ["cart_transferred_to_controlled_actor"] = false
		shopper ["cart_reset_reason"] = reason
		shopper ["cart_reset_at_ms"] = int(Time.get_ticks_msec())

		shoppers [actor_key] = shopper
		session ["shoppers"] = shoppers
		session ["updated_at_ms"] = int(Time.get_ticks_msec())
		grocery_shopper_sessions_by_store_id [session_store_id] = session

func _grocery_mark_shopper_cart_transferred(actor_id: int, store_id: String) -> void:
	var clean_store_id: String = str(store_id).strip_edges()
	var session: Dictionary = grocery_shopper_sessions_by_store_id.get(clean_store_id, {}) if typeof(grocery_shopper_sessions_by_store_id.get(clean_store_id, {})) == TYPE_DICTIONARY else {}
	if session.is_empty():
		return

	var shoppers: Dictionary = session.get("shoppers", {}) if typeof(session.get("shoppers", {})) == TYPE_DICTIONARY else {}
	var key: String = str(int(actor_id))
	if not shoppers.has(key):
		return

	var shopper: Dictionary = shoppers.get(key, {}) if typeof(shoppers.get(key, {})) == TYPE_DICTIONARY else {}
	shopper ["cart_transferred_to_controlled_actor"] = true
	shopper ["cart_transferred_at_ms"] = int(Time.get_ticks_msec())
	shoppers [key] = shopper
	session ["shoppers"] = shoppers
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_shopper_sessions_by_store_id [clean_store_id] = session


func _grocery_cart_item_count(cart: Dictionary) -> int:
	var count: int = 0
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		count += max(1, int((raw_item as Dictionary).get("quantity", 1)))
	return count

func _grocery_cart_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var key: String = str(int(actor.id))
	if not grocery_carts_by_actor_id.has(key):
		grocery_carts_by_actor_id [key] = {
			"store_id": "",
			"items": [],
			"created_at_ms": int(Time.get_ticks_msec())
		}

	return grocery_carts_by_actor_id [key].duplicate(true)


func _grocery_cart_total(cart: Dictionary) -> float:
	return float(_grocery_cart_price_breakdown(cart).get("total", 0.0))


func _grocery_cart_subtotal(cart: Dictionary) -> float:
	return float(_grocery_cart_price_breakdown(cart).get("subtotal", 0.0))


func _grocery_cart_price_breakdown(cart: Dictionary) -> Dictionary:
	var store_id: String = str(cart.get("store_id", "")).strip_edges()
	var store: Dictionary = get_store(store_id)
	var subtotal: float = 0.0
	var tax: float = 0.0
	var total: float = 0.0
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []

	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var qty: int = max(1, int(item.get("quantity", 1)))
		var line: Dictionary = _grocery_line_item_price_breakdown(store, item, qty)
		subtotal += float(line.get("subtotal", 0.0))
		tax += float(line.get("tax", 0.0))
		total += float(line.get("total", 0.0))

	return {
		"subtotal": snapped(subtotal, 0.01),
		"tax": snapped(tax, 0.01),
		"total": snapped(total, 0.01)
	}


func _grocery_line_item_price_breakdown(store: Dictionary, item: Dictionary, quantity: int = 1) -> Dictionary:
	var qty: int = max(1, int(quantity))
	var unit: Dictionary = _grocery_item_price_breakdown(store, item)
	return {
		"subtotal": snapped(float(unit.get("subtotal", 0.0)) * float(qty), 0.01),
		"tax_rate": float(unit.get("tax_rate", 0.0)),
		"tax": snapped(float(unit.get("tax", 0.0)) * float(qty), 0.01),
		"total": snapped(float(unit.get("total", 0.0)) * float(qty), 0.01)
	}


func _grocery_item_price_breakdown(store: Dictionary, item: Dictionary, actor: Person = null) -> Dictionary:
	var subtotal: float = max(0.0, float(item.get("price", 0.0)))
	var base_breakdown: Dictionary = _grocery_price_breakdown(store, subtotal)
	var base_tax: float = float(base_breakdown.get("tax", 0.0))
	var base_total: float = float(base_breakdown.get("total", subtotal))

	if _goldleaf_premium_applies(actor, store):
		var discounted_subtotal: float = snapped(subtotal * 0.5, 0.01)
		return {
			"subtotal": discounted_subtotal,
			"tax_rate": 0.0,
			"tax": 0.0,
			"total": discounted_subtotal,
			"goldleaf_premium_discount_applied": true,
			"base_subtotal": snapped(subtotal, 0.01),
			"base_tax": snapped(base_tax, 0.01),
			"base_total": snapped(base_total, 0.01),
			"discount_amount": snapped(base_total - discounted_subtotal, 0.01),
			"goldleaf_premium_label": "%s\n%s (Goldleaf Premium)" % [
				_goldleaf_format_money_for_actor(base_total, actor),
				_goldleaf_format_money_for_actor(discounted_subtotal, actor)
			]
		}

	if bool(item.get("tax_exempt", false)) or bool(item.get("price_after_tax_locked", false)):
		return {
			"subtotal": snapped(subtotal, 0.01),
			"tax_rate": 0.0,
			"tax": 0.0,
			"total": snapped(subtotal, 0.01),
			"base_subtotal": snapped(subtotal, 0.01),
			"base_tax": 0.0,
			"base_total": snapped(subtotal, 0.01)
		}

	if item.has("tax_rate_override"):
		var override_rate: float = clamp(float(item.get("tax_rate_override", 0.0)), 0.0, 0.25)
		var override_tax: float = snapped(subtotal * override_rate, 0.01)
		return {
			"subtotal": snapped(subtotal, 0.01),
			"tax_rate": override_rate,
			"tax": override_tax,
			"total": snapped(subtotal + override_tax, 0.01),
			"base_subtotal": snapped(subtotal, 0.01),
			"base_tax": override_tax,
			"base_total": snapped(subtotal + override_tax, 0.01)
		}

	base_breakdown ["base_subtotal"] = snapped(subtotal, 0.01)
	base_breakdown ["base_tax"] = snapped(base_tax, 0.01)
	base_breakdown ["base_total"] = snapped(base_total, 0.01)
	return base_breakdown
func _goldleaf_monthly_price() -> float:
	return 250.0


func _goldleaf_annual_renewal_price() -> float:
	return _goldleaf_monthly_price() * 12.0

func _goldleaf_discount_summary_text() -> String:
	return "50" + "% off every product • no tax while active"


func _goldleaf_membership_line_for_actor(actor: Person, active: bool = false) -> String:
	var symbol: String = _goldleaf_currency_symbol_for_actor(actor)
	if active:
		return "Premium Membership: ACTIVE • " + symbol + "250/Mo • " + _goldleaf_discount_summary_text()
	return "Premium Membership: " + symbol + "250/Mo • " + _goldleaf_discount_summary_text()
func _goldleaf_currency_symbol_for_actor(actor: Person = null) -> String:
	var country: String = ""
	if actor != null:
		country = str(actor.home_country).strip_edges().to_lower()

	match country:
		"united kingdom", "england", "scotland", "wales":
			return "£"
		"japan":
			return "¥"
		"canada":
			return "C$"
		"australia":
			return "A$"
		"eurozone", "france", "germany", "italy", "spain", "ireland", "netherlands":
			return "€"
		_:
			return "$"


func _goldleaf_format_money_for_actor(amount: float, actor: Person = null) -> String:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("format_money"):
		return gs.economy_engine.format_money(int(round(amount)))
	return "%s%.2f" % [_goldleaf_currency_symbol_for_actor(actor), float(amount)]


func _goldleaf_membership_status_text(actor: Person) -> String:
	var symbol: String = _goldleaf_currency_symbol_for_actor(actor)
	return "Goldleaf Premium Member • " + symbol + "250/Mo • " + _goldleaf_discount_summary_text()

func ensure_goldleaf_premium_membership_current(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "active": false, "reason": "No actor supplied."}
	if gs == null:
		return { "success": false, "active": false, "reason": "GameState unavailable."}

	var key: String = str(int(actor.id))
	var membership: Dictionary = grocery_memberships_by_actor_id.get(key, {}) if typeof(grocery_memberships_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	if membership.is_empty():
		return { "success": true, "active": false, "reason": "No Goldleaf Premium Membership."}

	if str(membership.get("store_id", "")) != "goldleaf_grocers":
		return { "success": true, "active": false, "reason": "Membership belongs to another store."}

	if bool(membership.get("cancelled", false)):
		return { "success": true, "active": false, "membership": membership.duplicate(true), "reason": "Goldleaf Premium Membership is cancelled."}

	if not bool(membership.get("active", false)):
		return { "success": true, "active": false, "membership": membership.duplicate(true), "reason": "Goldleaf Premium Membership is inactive."}

	var current_year: int = int(gs.year)
	var renewal_due_year: int = int(membership.get("renewal_due_year", current_year + 1))
	if current_year < renewal_due_year:
		return { "success": true, "active": true, "membership": membership.duplicate(true), "reason": "Goldleaf Premium Membership is current."}

	if gs.food_engine == null:
		membership ["active"] = false
		membership ["lapsed"] = true
		membership ["lapse_reason"] = "FoodEngine unavailable during renewal."
		membership ["renewal_failed_year"] = current_year
		membership ["updated_at_ms"] = int(Time.get_ticks_msec())
		grocery_memberships_by_actor_id [key] = membership
		return { "success": false, "active": false, "membership": membership.duplicate(true), "reason": membership ["lapse_reason"]}

	var annual_price: float = float(membership.get("annual_renewal_price", _goldleaf_annual_renewal_price()))
	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, annual_price, {
		"source": "goldleaf_premium_membership_yearly_renewal",
		"store_id": "goldleaf_grocers",
		"monthly_price": float(membership.get("monthly_price", _goldleaf_monthly_price())),
		"annual_renewal_price": annual_price,
		"context": context.duplicate(true)
	})

	if not bool(pay_report.get("success", false)):
		membership ["active"] = false
		membership ["lapsed"] = true
		membership ["lapse_reason"] = str(pay_report.get("reason", "I could not afford the Goldleaf Premium renewal."))
		membership ["renewal_failed_year"] = current_year
		membership ["updated_at_ms"] = int(Time.get_ticks_msec())
		grocery_memberships_by_actor_id [key] = membership
		last_report = {
			"success": false,
			"actor_id": int(actor.id),
			"membership": membership.duplicate(true),
			"payment_report": pay_report.duplicate(true),
			"text": "My Goldleaf Premium Membership lapsed because I could not afford the renewal."
		}
		return { "success": false, "active": false, "membership": membership.duplicate(true), "payment_report": pay_report.duplicate(true), "reason": membership ["lapse_reason"]}

	membership ["active"] = true
	membership ["lapsed"] = false
	membership ["last_renewal_year"] = current_year
	membership ["renewal_due_year"] = current_year + 1
	membership ["annual_renewal_price"] = annual_price
	membership ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_memberships_by_actor_id [key] = membership

	last_report = {
		"success": true,
		"actor_id": int(actor.id),
		"membership": membership.duplicate(true),
		"payment_report": pay_report.duplicate(true),
		"text": "Goldleaf Premium renewed for another year."
	}

	return { "success": true, "active": true, "membership": membership.duplicate(true), "payment_report": pay_report.duplicate(true), "reason": "Goldleaf Premium renewed."}


func yearly_tick() -> void:
	if gs == null:
		return
	for raw_key in grocery_memberships_by_actor_id.keys():
		var actor_id: int = int(raw_key)
		if actor_id <= 0:
			continue

		var actor: Person = null
		if gs.has_method("get_npc_by_id"):
			actor = gs.get_npc_by_id(actor_id)
		if actor == null and gs.player != null and int(gs.player.id) == actor_id:
			actor = gs.player
		if actor == null:
			continue

		ensure_goldleaf_premium_membership_current(actor, {
			"source": "grocery_store_engine_yearly_tick"
		})
func actor_has_goldleaf_premium(
		actor: Person
) -> bool:
	if actor == null:
		return false

	var key: String = str(
		int(actor.id)
	)

	if not grocery_memberships_by_actor_id.has(
		key
	):
		return false

	var membership_raw: Variant = (
		grocery_memberships_by_actor_id.get(
			key,
			{}
		)
	)
	var membership: Dictionary = (
		membership_raw as Dictionary
		if typeof(membership_raw) == TYPE_DICTIONARY
		else {}
	)

	if membership.is_empty():
		return false

	if str(
		membership.get(
			"store_id",
			""
		)
	).strip_edges() != "goldleaf_grocers":
		return false

	if bool(
		membership.get(
			"cancelled",
			false
		)
	):
		return false

	if bool(
		membership.get(
			"lapsed",
			false
		)
	):
		return false

	return bool(
		membership.get(
			"active",
			false
		)
	)
func _build_self_checkout_machine_quantum(
		store_id: String,
		actor: Person,
		machine_index: int,
		existing_machines: Array,
		_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var machine_number: int = (
		int(machine_index) + 1
	)
	var machine_id: String = (
		"sco_%02d"
		% machine_number
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var rng: RandomNumberGenerator = (
		_grocery_shopper_rng(
			"%s|%d|%d|self_checkout_machine|%d"
			% [
				clean_store_id,
				int(actor.id),
				int(gs.year) if gs != null else 0,
				machine_index
			]
		)
	)
	var roll: float = rng.randf()
	var status: String = "available"

	if roll < 0.1:
		status = "offline"
	elif roll < 0.68:
		status = "in_use"

	var machine: Dictionary = {
		"machine_id": machine_id,
		"machine_number": machine_number,
		"label": "Self Checkout %d" % machine_number,
		"store_id": clean_store_id
	}

	if status == "in_use":
		var used_ids: Dictionary = (
			_self_checkout_machine_occupant_ids(
				existing_machines,
				actor
			)
		)
		var occupant_profile: Dictionary = (
			_self_checkout_pick_named_occupant_profile(
				clean_store_id,
				rng,
				used_ids
			)
		)

		machine = (
			_self_checkout_prepare_machine_for_status(
				machine,
				status,
				rng,
				now_ms,
				"%s is using this terminal."
				% str(
					occupant_profile.get(
						"name",
						"Unknown shopper"
					)
				)
			)
		)
		machine = (
			_self_checkout_apply_occupant_profile(
				machine,
				occupant_profile
			)
		)
		machine = (
			_self_checkout_apply_ambient_receipt(
				machine,
				clean_store_id,
				occupant_profile,
				rng,
				actor
			)
		)

		var started_ago_ms: int = int(
			rng.randi_range(
				500,
				7000
			)
		)
		machine ["status_started_at_ms"] = (
			now_ms - started_ago_ms
		)
		machine ["expected_available_at_ms"] = (
			now_ms
			+ int(
				rng.randi_range(
					2500,
					9000
				)
			)
		)
	else:
		machine = (
			_self_checkout_prepare_machine_for_status(
				machine,
				status,
				rng,
				now_ms,
				""
			)
		)

		if status == "offline":
			machine ["expected_available_at_ms"] = (
				now_ms
				+ int(
					rng.randi_range(
						7000,
						18000
					)
				)
			)

	return machine
func _prime_self_checkout_session_quantum(
		actor: Person,
		store_id: String,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var clean_store_id: String = str(
		store_id
	).strip_edges()

	if clean_store_id == "":
		return {}

	var key: String = (
		_self_checkout_session_key(
			actor
		)
	)
	var session_raw: Variant = (
		grocery_self_checkout_sessions_by_actor_id.get(
			key,
			{}
		)
	)
	var session: Dictionary = (
		session_raw as Dictionary
		if typeof(session_raw) == TYPE_DICTIONARY
		else {}
	)

	var current_year: int = (
		int(gs.year)
		if gs != null
		else 0
	)
	var target_count: int = (
		_self_checkout_machine_count_for_store(
			clean_store_id
		)
	)

	var needs_new_resident_deck: bool = (
		session.is_empty()
		or str(
			session.get(
				"store_id",
				""
			)
		) != clean_store_id
		or int(
			session.get(
				"resident_year",
				current_year
			)
		) != current_year
		or bool(
			session.get(
				"finished",
				false
			)
		)
	)

	if needs_new_resident_deck:
		session = {
			"actor_id": int(actor.id),
			"store_id": clean_store_id,
			"active": false,
			"finished": false,
			"state": "resident_priming",
			"queue_position": 0,
			"machines": [],
			"assigned_machine_id": "",
			"payment_type": "",
			"confirmation_text": "",
			"resident_year": current_year,
			"resident_ready": false,
			"machine_prime_cursor": 0,
			"machine_prime_target": target_count,
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"updated_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	var machines: Array = (
		session.get(
			"machines",
			[]
		)
		if typeof(
			session.get(
				"machines",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var cursor: int = int(
		session.get(
			"machine_prime_cursor",
			machines.size()
		)
	)

	if cursor < target_count:
		var machine: Dictionary = (
			_build_self_checkout_machine_quantum(
				clean_store_id,
				actor,
				cursor,
				machines,
				context
			)
		)

		if not machine.is_empty():
			machines.append(
				machine
			)
			cursor += 1

	var complete: bool = (
		cursor >= target_count
	)

	session ["machines"] = machines
	session ["machine_prime_cursor"] = cursor
	session ["machine_prime_target"] = target_count
	session ["resident_ready"] = complete
	session ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	if complete:
		if bool(
			session.get(
				"active",
				false
			)
		):
			var lane_state: String = str(
				session.get(
					"state",
					""
				)
			).strip_edges().to_lower()

			if lane_state in [
				"warming",
				"resident_priming",
				"resident_ready"
			]:
				var available_machine: Dictionary = (
					_self_checkout_available_machine(
						{
							"machines": machines
						}
					)
				)

				if available_machine.is_empty():
					session ["state"] = "waiting"

					if int(
						session.get(
							"queue_position",
							0
						)
					) <= 0:
						var queue_rng: RandomNumberGenerator = (
							_grocery_shopper_rng(
								"%s|%d|self_checkout_queue"
								% [
									clean_store_id,
									int(actor.id)
								]
							)
						)
						session ["queue_position"] = int(
							queue_rng.randi_range(
								1,
								3
							)
						)
				else:
					session ["state"] = "choose_machine"
					session ["queue_position"] = 0
		else:
			session ["state"] = "resident_ready"
	else:
		if bool(
			session.get(
				"active",
				false
			)
		):
			session ["state"] = "warming"

	grocery_self_checkout_sessions_by_actor_id [
		key
	] = session

	return session.duplicate(false)
func buy_goldleaf_premium_membership(actor: Person, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	if actor_has_goldleaf_premium(actor):
		return {
			"success": true,
			"actor_id": int(actor.id),
			"show_popup": true,
			"popup_title": "Goldleaf Premium",
			"popup_text": "I am already a Goldleaf Premium Member.",
			"popup_footer": "Tap anywhere to continue.",
			"text": "I am already a Goldleaf Premium Member."
		}

	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var monthly_price: float = _goldleaf_monthly_price()
	var annual_price: float = _goldleaf_annual_renewal_price()
	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, monthly_price, {
		"source": "goldleaf_premium_membership",
		"store_id": "goldleaf_grocers",
		"monthly_price": monthly_price,
		"annual_renewal_price": annual_price
	})

	if not bool(pay_report.get("success", false)):
		return pay_report

	var current_year: int = int(gs.year) if gs != null else 0
	var membership: Dictionary = {
		"store_id": "goldleaf_grocers",
		"active": true,
		"cancelled": false,
		"lapsed": false,
		"monthly_price": monthly_price,
		"annual_renewal_price": annual_price,
		"discount_rate": 0.5,
		"tax_exempt": true,
		"joined_year": current_year,
		"last_payment_year": current_year,
		"renewal_due_year": current_year + 1,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	grocery_memberships_by_actor_id [str(int(actor.id))] = membership

	var symbol: String = _goldleaf_currency_symbol_for_actor(actor)
	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"membership": membership.duplicate(true),
		"payment_report": pay_report.duplicate(true),
		"show_popup": true,
		"popup_title": "Goldleaf Premium",
		"popup_text": "I bought a Goldleaf Premium Membership.\n\n" + symbol + "250/Mo\n" + "50" + "% off every product\nNo tax while active\nRenews yearly. If I cannot afford renewal, my membership lapses and I have to rebuy it.", "membership_cost_pulse_text": "-" + symbol + "250/Mo",
		"popup_footer": "Tap anywhere to continue.",
		"membership_cost_delta": - monthly_price,
		"updated_at_ms": int(Time.get_ticks_msec()),
		"text": "I bought a Goldleaf Premium Membership."
	}

	last_report = report.duplicate(true)
	return report

func cancel_goldleaf_premium_membership(actor: Person, _context: Dictionary = {}) -> Dictionary:

	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var key: String = str(int(actor.id))
	var membership: Dictionary = grocery_memberships_by_actor_id.get(key, {}) if typeof(grocery_memberships_by_actor_id.get(key, {})) == TYPE_DICTIONARY else {}
	if membership.is_empty():
		return { "success": false, "reason": "I do not have a Goldleaf Premium Membership."}
	membership ["active"] = false
	membership ["cancelled"] = true
	membership ["cancelled_year"] = int(gs.year) if gs != null else 0
	membership ["updated_at_ms"] = int(Time.get_ticks_msec())
	grocery_memberships_by_actor_id [key] = membership
	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"membership": membership.duplicate(true),
		"show_popup": true,
		"popup_title": "Goldleaf Premium Cancelled",
		"popup_text": "I cancelled my Goldleaf Premium Membership. I can still shop at Goldleaf, but I pay full price again.",
		"popup_footer": "Tap anywhere to continue.",
		"text": "I cancelled my Goldleaf Premium Membership."
	}
	last_report = report.duplicate(true)
	return report

func _goldleaf_premium_applies(actor: Person, store: Dictionary) -> bool:

	if actor == null:
		return false
	if str(store.get("id", "")).strip_edges() != "goldleaf_grocers":
		return false
	return actor_has_goldleaf_premium(actor)


func _grocery_price_breakdown(store: Dictionary, subtotal: float) -> Dictionary:
	var clean_subtotal: float = max(0.0, float(subtotal))
	var tax_rate: float = _grocery_tax_rate_for_store(store)
	var tax: float = snapped(clean_subtotal * tax_rate, 0.01)
	var total: float = snapped(clean_subtotal + tax, 0.01)

	return {
		"subtotal": snapped(clean_subtotal, 0.01),
		"tax_rate": tax_rate,
		"tax": tax,
		"total": total
	}


func _grocery_tax_rate_for_store(store: Dictionary = {}) -> float:
	if typeof(store) == TYPE_DICTIONARY and store.has("tax_rate"):
		return clamp(float(store.get("tax_rate", 0.0825)), 0.0, 0.25)

	var era_name: String = _era_name_from_context({})
	match era_name:
		"Future Era":
			return 0.065
		_:
			return 0.0825


func _grocery_aisle_id_for_item(item: Dictionary) -> String:
	var explicit: String = str(item.get("aisle", "")).strip_edges().to_lower()
	if explicit != "":
		return explicit

	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	if category != "":
		return category

	var quality: String = str(item.get("quality", "")).strip_edges().to_lower()
	var name: String = str(item.get("name", "")).strip_edges().to_lower()

	if name.find("cereal") >= 0 or name.find("flakes") >= 0 or name.find("puffs") >= 0 or name.find("loops") >= 0:
		return "cereal"
	if name.find("chips") >= 0 or name.find("cookies") >= 0 or name.find("snack") >= 0 or name.find("crunch") >= 0:
		return "snacks"
	if name.find("soda") >= 0 or name.find("juice") >= 0 or name.find("tea") >= 0 or name.find("water") >= 0:
		return "drinks"
	if name.find("milk") >= 0 or name.find("cheese") >= 0 or name.find("yogurt") >= 0:
		return "dairy"
	if name.find("can") >= 0 or name.find("canned") >= 0 or name.find("beans") >= 0 or name.find("soup") >= 0:
		return "canned"
	if name.find("salmon") >= 0 or name.find("chicken") >= 0 or name.find("beef") >= 0 or float(item.get("protein", 0.0)) >= 10.0:
		return "protein"
	if name.find("frozen") >= 0:
		return "frozen"
	if quality.find("premium") >= 0 or quality.find("organic") >= 0:
		return "organic"
	if float(item.get("vitamins", 0.0)) >= 10.0:
		return "produce"

	return "pantry"

func _grocery_aisle_label(aisle_id: String) -> String:
	match str(aisle_id).strip_edges().to_lower():
		"cereal":
			return "Cereal🥣"
		"snacks":
			return "🍩Junk Food & Snacks🍪"
		"drinks":
			return "Drinks🧃"
		"dairy":
			return "Dairy🥛"
		"canned":
			return "Canned Goods🥫"
		"produce":
			return "Fruits & Veggies🍎"
		"protein":
			return "Meat & Seafood🥩"
		"frozen":
			return "Frozen Foods🧊"
		"organic":
			return "Organic🌿"
		"future":
			return "Nutripods🔋"
		_:
			return "Pantry🍞"


func _grocery_aisle_description(aisle_id: String, _store: Dictionary = {}) -> String:
	match str(aisle_id).strip_edges().to_lower():
		"cereal":
			return "Bright boxes, off-brand bags, sugar mascots, family-size crunch, and quick breakfast choices."
		"snacks":
			return "Chips, cookies, sweet shelves, salty shelves, and suspiciously addictive discount bags."
		"drinks":
			return "Cold cases, soda shelves, juices, flavored water, energy cans, and fridge-door temptation."
		"dairy":
			return "Milk, cheese, yogurt, creamers, and chilled everyday basics."
		"canned":
			return "Stacked soups, beans, vegetables, sauces, and emergency pantry survival."
		"produce":
			return "Fresh bins, misting shelves, fruit, vegetables, and bright nutrition labels."
		"protein":
			return "Cold cases, wrapped cuts, seafood trays, and meal-prep protein."
		"frozen":
			return "Freezers hum while quick meals wait behind frosted glass."
		"organic":
			return "Premium shelves with cleaner labels and expensive little promises."
		"future":
			return "Sterile tubes of compressed nutrition and glowing futuremarket packages."
		_:
			return "Dry goods, staples, bags, cans, and everyday pantry survival."
func buy_grocery(actor: Person, store_id: String, food_id: String, quantity: int = 1, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var store: Dictionary = get_store(store_id)
	if store.is_empty():
		return { "success": false, "reason": "Grocery store not found."}

	var item: Dictionary = _find_store_item(store, food_id)
	if item.is_empty():
		return { "success": false, "reason": "Grocery item not found."}

	var qty: int = max(1, int(quantity))
	var total_price: float = float(item.get("price", 0.0)) * float(qty)
	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, total_price, {
		"source": "grocery_store_engine",
		"store_id": store_id
	})
	if not bool(pay_report.get("success", false)):
		return pay_report

	var pantry_report: Dictionary = gs.food_engine.add_pantry_item(actor, item, qty, {
		"source": "grocery_store_engine",
		"store_id": store_id
	})

	var report:= {
		"success": true,
		"actor_id": int(actor.id),
		"store_id": store_id,
		"food_id": food_id,
		"quantity": qty,
		"payment_report": pay_report.duplicate(true),
		"pantry_report": pantry_report.duplicate(true),
		"text": "I bought %s ×%d from %s." % [str(item.get("name", "food")), qty, str(store.get("name", "the store"))]
	}
	grocery_ledger.append(report.duplicate(true))
	last_report = report.duplicate(true)
	return report

func get_stores_for_era(era_name: String = "") -> Array:
	var clean_era_name: String = str(era_name).strip_edges()
	if clean_era_name == "":
		clean_era_name = "Modern Era"

	var eras: Dictionary = grocery_contract.get("eras", {}) if typeof(grocery_contract.get("eras", {})) == TYPE_DICTIONARY else {}
	var raw_stores: Variant = eras.get(clean_era_name, eras.get("Modern Era", []))
	var stores: Array = raw_stores.duplicate(true) if typeof(raw_stores) == TYPE_ARRAY else []

	if _era_mart_should_exist_in_era(clean_era_name):
		stores = _ensure_store_list_has_era_mart(stores)

	return stores

func get_store(store_id: String) -> Dictionary:
	var clean_store_id: String = str(store_id).strip_edges()

	for era_key in grocery_contract.get("eras", {}).keys():
		var stores: Array = grocery_contract ["eras"].get(era_key, [])
		for raw_store in stores:
			if typeof(raw_store) != TYPE_DICTIONARY:
				continue
			var store: Dictionary = raw_store
			if str(store.get("id", "")).strip_edges() == clean_store_id:
				return store.duplicate(true)

	if clean_store_id == "basket_lane_market":
		return _era_mart_store_contract()

	return {}
func first_aisle_id_for_store(store_id: String) -> String:
	var aisle_ids: Array = aisle_ids_for_store(store_id)
	if aisle_ids.is_empty():
		return ""

	return str(aisle_ids [0])
func aisle_ids_for_store(store_id: String) -> Array:
	var store: Dictionary = get_store(store_id)
	var out: Array = []

	if store.is_empty():
		return out

	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var aisle_id: String = _grocery_aisle_id_for_item(raw_item as Dictionary)
		if aisle_id == "":
			continue

		if out.has(aisle_id):
			continue

		out.append(aisle_id)

	return out


func aisle_slide_direction_for_store(store_id: String, from_aisle_id: String, to_aisle_id: String) -> int:
	var aisle_ids: Array = aisle_ids_for_store(store_id)
	if aisle_ids.size() <= 1:
		return 0

	var from_index: int = aisle_ids.find(str(from_aisle_id).strip_edges())
	var to_index: int = aisle_ids.find(str(to_aisle_id).strip_edges())

	if from_index < 0 or to_index < 0:
		return 0

	if from_index == to_index:
		return 0

	var forward_distance: int = (to_index - from_index + aisle_ids.size()) % aisle_ids.size()
	var backward_distance: int = (from_index - to_index + aisle_ids.size()) % aisle_ids.size()

	if forward_distance <= backward_distance:
		return 1

	return -1


func _era_mart_should_exist_in_era(era_name: String) -> bool:
	var clean_era_name: String = str(era_name).strip_edges()
	return clean_era_name in ["Modern Era", "Future Era"]


func _ensure_store_list_has_era_mart(stores: Array) -> Array:
	var out: Array = stores.duplicate(true)
	if _grocery_store_index_by_id(out, "basket_lane_market") < 0:
		out.insert(0, _era_mart_store_contract())
	return out


func _era_mart_store_contract() -> Dictionary:
	return {
		"id": "basket_lane_market",
		"name": "Era-Mart",
		"tier": "standard",
		"tax_rate": 0.0825,
		"description": "Bright cherry-coral aisles, humming refrigerators, parody-name brands, store-brand knockoffs, suspicious snacks, and checkout lanes under classic Era-Mart lights. Era-Mart survives every era.",
		"cashier_name": "Marla",
		"era_availability": ["Modern Era", "Future Era"],
		"inventory": _era_mart_inventory()
	}
func export_state() -> Dictionary:
	return {
		"schema": "eralife.grocery_store_engine_state",
		"version": GROCERY_VERSION,
		"grocery_contract": grocery_contract.duplicate(true),
		"grocery_ledger": grocery_ledger.duplicate(true),
		"grocery_carts_by_actor_id": grocery_carts_by_actor_id.duplicate(true),
		"grocery_memberships_by_actor_id": grocery_memberships_by_actor_id.duplicate(true),
		"grocery_shopper_sessions_by_store_id": grocery_shopper_sessions_by_store_id.duplicate(true),
		"grocery_store_worker_sessions_by_store_id": grocery_store_worker_sessions_by_store_id.duplicate(true),
		"grocery_self_checkout_sessions_by_actor_id": grocery_self_checkout_sessions_by_actor_id.duplicate(true),
		"last_report": last_report.duplicate(true)
	}
func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "GroceryStoreEngine import data must be a Dictionary."}

	grocery_contract = data.get("grocery_contract", _default_grocery_contract()).duplicate(true) if typeof(data.get("grocery_contract", {})) == TYPE_DICTIONARY else _default_grocery_contract()
	grocery_ledger = data.get("grocery_ledger", []).duplicate(true) if typeof(data.get("grocery_ledger", [])) == TYPE_ARRAY else []
	grocery_carts_by_actor_id = data.get("grocery_carts_by_actor_id", {}).duplicate(true) if typeof(data.get("grocery_carts_by_actor_id", {})) == TYPE_DICTIONARY else {}
	grocery_memberships_by_actor_id = data.get("grocery_memberships_by_actor_id", {}).duplicate(true) if typeof(data.get("grocery_memberships_by_actor_id", {})) == TYPE_DICTIONARY else {}
	grocery_shopper_sessions_by_store_id = data.get("grocery_shopper_sessions_by_store_id", {}).duplicate(true) if typeof(data.get("grocery_shopper_sessions_by_store_id", {})) == TYPE_DICTIONARY else {}
	grocery_store_worker_sessions_by_store_id = data.get("grocery_store_worker_sessions_by_store_id", {}).duplicate(true) if typeof(data.get("grocery_store_worker_sessions_by_store_id", {})) == TYPE_DICTIONARY else {}
	grocery_self_checkout_sessions_by_actor_id = data.get("grocery_self_checkout_sessions_by_actor_id", {}).duplicate(true) if typeof(data.get("grocery_self_checkout_sessions_by_actor_id", {})) == TYPE_DICTIONARY else {}
	last_report = data.get("last_report", {}).duplicate(true) if typeof(data.get("last_report", {})) == TYPE_DICTIONARY else {}
	last_report = data.get("last_report", {}).duplicate(true) if typeof(data.get("last_report", {})) == TYPE_DICTIONARY else {}

	_merge_default_grocery_catalog_forward()

	return { "success": true}
func _merge_default_grocery_catalog_forward() -> void:
	var default_contract: Dictionary = _default_grocery_contract()
	var default_eras: Dictionary = default_contract.get("eras", {}) if typeof(default_contract.get("eras", {})) == TYPE_DICTIONARY else {}

	if typeof(grocery_contract) != TYPE_DICTIONARY:
		grocery_contract = default_contract.duplicate(true)
		return

	if not grocery_contract.has("eras") or typeof(grocery_contract.get("eras", {})) != TYPE_DICTIONARY:
		grocery_contract ["eras"] = {}

	var live_eras: Dictionary = grocery_contract.get("eras", {})
	for era_name in default_eras.keys():
		var default_stores: Array = default_eras.get(era_name, []) if typeof(default_eras.get(era_name, [])) == TYPE_ARRAY else []
		var live_stores: Array = live_eras.get(era_name, []) if typeof(live_eras.get(era_name, [])) == TYPE_ARRAY else []

		for raw_default_store in default_stores:
			if typeof(raw_default_store) != TYPE_DICTIONARY:
				continue

			var default_store: Dictionary = raw_default_store
			var default_store_id: String = str(default_store.get("id", "")).strip_edges()
			if default_store_id == "":
				continue

			var existing_index: int = _grocery_store_index_by_id(live_stores, default_store_id)
			if existing_index < 0:
				live_stores.append(default_store.duplicate(true))
				continue

			var live_store: Dictionary = live_stores [existing_index] if typeof(live_stores [existing_index]) == TYPE_DICTIONARY else {}

			for store_key in ["name", "tier", "description", "tax_rate", "cashier_name"]:
				if default_store.has(store_key):
					live_store [store_key] = default_store.get(store_key)

			var live_inventory: Array = live_store.get("inventory", []) if typeof(live_store.get("inventory", [])) == TYPE_ARRAY else []
			var default_inventory: Array = default_store.get("inventory", []) if typeof(default_store.get("inventory", [])) == TYPE_ARRAY else []

			for raw_default_item in default_inventory:
				if typeof(raw_default_item) != TYPE_DICTIONARY:
					continue

				var default_item: Dictionary = raw_default_item
				var default_item_id: String = str(default_item.get("id", "")).strip_edges()
				if default_item_id == "":
					continue

				var existing_item_index: int = _grocery_item_index_by_id(live_inventory, default_item_id)
				if existing_item_index < 0:
					live_inventory.append(default_item.duplicate(true))
					continue

				var live_item: Dictionary = live_inventory [existing_item_index] if typeof(live_inventory [existing_item_index]) == TYPE_DICTIONARY else {}
				for item_key in default_item.keys():
					if not live_item.has(item_key):
						live_item [item_key] = default_item.get(item_key)
				live_inventory [existing_item_index] = live_item

			live_store ["inventory"] = live_inventory
			live_stores [existing_index] = live_store

		live_eras [era_name] = live_stores

	grocery_contract ["eras"] = live_eras

func _grocery_store_index_by_id(stores: Array, store_id: String) -> int:
	var clean_id: String = str(store_id).strip_edges()
	for i in range(stores.size()):
		if typeof(stores [i]) != TYPE_DICTIONARY:
			continue
		if str((stores [i] as Dictionary).get("id", "")).strip_edges() == clean_id:
			return i
	return -1


func _grocery_item_index_by_id(items: Array, item_id: String) -> int:
	var clean_id: String = str(item_id).strip_edges()
	for i in range(items.size()):
		if typeof(items [i]) != TYPE_DICTIONARY:
			continue
		if str((items [i] as Dictionary).get("id", "")).strip_edges() == clean_id:
			return i
	return -1

func _find_store_item(store: Dictionary, food_id: String) -> Dictionary:
	var inventory: Array = store.get("inventory", []) if typeof(store.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if str(item.get("id", "")) == str(food_id):
			return item.duplicate(true)
	return {}

func _era_name_from_context(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("era_name", "")).strip_edges()
	if clean != "":
		return clean
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "Modern Era"

func _default_grocery_contract() -> Dictionary:
	return {
		"schema": "eralife.grocery_contract",
		"version": GROCERY_VERSION,
		"eras": {
			"Modern Era": [
				_era_mart_store_contract(),
				{
					"id": "goldleaf_grocers",
					"name": "Goldleaf Grocers",
					"tier": "premium",
					"tax_rate": 0.0825,
					"description": "Premium carts, polished floors, expensive produce mist, boutique cereals, luxury snacks, and brands that look like they have publicists.",
					"cashier_name": "Ellis",
					"inventory": _goldleaf_grocers_inventory()
				}
			],
			"Future Era": [
				_era_mart_store_contract(),
				{
					"id": "nutripod_exchange",
					"name": "Nutripod Exchange",
					"tier": "future_market",
					"tax_rate": 0.065,
					"description": "A glowing futuremarket where aisle signs float, scanners hum, and parody brands are somehow legally generated by vending AI.",
					"cashier_name": "Unit Jessa-9",
					"inventory": _nutripod_exchange_inventory()
				}
			]
		}
	}
func _grocery_item(id: String, name: String, price: float, aisle: String, brand_lane: String, hunger_restore: int, nutrition: int, quality: String, extra: Dictionary = {}) -> Dictionary:
	var item: Dictionary = {
		"id": str(id),
		"name": str(name),
		"price": float(price),
		"aisle": str(aisle),
		"brand_lane": str(brand_lane),
		"hunger_restore": int(hunger_restore),
		"nutrition": int(nutrition),
		"shelf_life_years": int(extra.get("shelf_life_years", 1)),
		"quality": str(quality)
	}

	for key in extra.keys():
		item [key] = extra.get(key)

	return item


func _era_mart_inventory() -> Array:
	return [
		_grocery_item("acrellos_cereal", "AcrellO’s", 420.69, "cereal", "name_brand", 99, 99, "legendary_cereal", { "sugar": 69, "shelf_life_years": 7, "tax_exempt": true, "price_after_tax_locked": true, "description": "The box says breakfast. The price says prophecy."}),
		_grocery_item("marshmellow_mateys", "Marshmellow Mateys", 4.79, "cereal", "name_brand", 20, 18, "sugary_name_brand", { "sugar": 16, "shelf_life_years": 2}),
		_grocery_item("cocoa_fudge_rounds", "Cocoa Fudge Rounds", 5.29, "cereal", "name_brand", 22, 16, "chocolate_name_brand", { "sugar": 18, "shelf_life_years": 2}),
		_grocery_item("loopty_loops_cereal", "Loopty Loops Cereal", 4.99, "cereal", "name_brand", 18, 24, "fun_name_brand", { "sugar": 10, "shelf_life_years": 2}),
		_grocery_item("frosty_shouts_cereal", "Frosty Shouts", 5.49, "cereal", "name_brand", 20, 20, "sugary_name_brand", { "sugar": 14, "shelf_life_years": 2}),
		_grocery_item("crackleberry_puffs", "Crackleberry Puffs", 3.89, "cereal", "store_brand", 17, 23, "store_brand_cereal", { "sugar": 9, "shelf_life_years": 2}),
		_grocery_item("circle_oats_cereal", "Circle Oats", 2.49, "cereal", "knockoff", 16, 22, "store_brand", { "sugar": 8, "shelf_life_years": 2}),
		_grocery_item("coldy_yells_cereal", "Coldy Yells", 2.99, "cereal", "knockoff", 18, 18, "cheap_sugary", { "sugar": 13, "shelf_life_years": 2}),
		_grocery_item("budget_bran_bricks", "Budget Bran Bricks", 1.99, "cereal", "knockoff", 15, 35, "cheap_fiber", { "sugar": 2, "shelf_life_years": 3}),

		_grocery_item("galatic_brownies", "Galatic Brownies", 3.99, "snacks", "name_brand", 16, 7, "sweet_name_brand", { "sugar": 19, "shelf_life_years": 1}),
		_grocery_item("galatic_brownies_sprinkles", "Galatic Brownies w/ Sprinkles", 4.49, "snacks", "name_brand", 17, 7, "sweet_name_brand", { "sugar": 21, "shelf_life_years": 1}),
		_grocery_item("fatcakes_regular", "Fatcakes • Regular", 2.99, "snacks", "name_brand", 20, 5, "danger_snack", { "sugar": 20, "sodium": 8, "shelf_life_years": 1, "warning": "By ButterSockCompany."}),
		_grocery_item("fatcakes_chunked_meat", "Fatcakes • Chunked Meat", 3.49, "snacks", "name_brand", 24, 4, "cursed_snack", { "sugar": 16, "sodium": 16, "shelf_life_years": 1, "warning": "By ButterSockCompany. May contain meat."}),
		_grocery_item("crunchy_prophets_chips", "Crunchy Prophets Chips", 3.99, "snacks", "name_brand", 14, 8, "snack_name_brand", { "sodium": 12, "shelf_life_years": 1}),
		_grocery_item("budget_crackle_chips", "Budget Crackle Chips", 1.79, "snacks", "knockoff", 12, 6, "cheap_snack", { "sodium": 14, "shelf_life_years": 1}),
		_grocery_item("cloud_cookie_sandwiches", "Cloud Cookie Sandwiches", 4.29, "snacks", "name_brand", 16, 9, "sweet_name_brand", { "sugar": 13, "shelf_life_years": 1}),
		_grocery_item("sandwich_creme_discs", "Sandwich Creme Discs", 2.19, "snacks", "knockoff", 14, 7, "discount_sweet", { "sugar": 12, "shelf_life_years": 1}),
		_grocery_item("cheese_dust_tornadoes", "Cheese Dust Tornadoes", 3.59, "snacks", "store_brand", 15, 6, "orange_finger_snack", { "sodium": 15, "shelf_life_years": 1}),

		_grocery_item("sparkle_pop_soda", "Sparkle Pop Soda", 1.99, "drinks", "name_brand", 8, 3, "soda_name_brand", { "sugar": 18, "shelf_life_years": 2}),
		_grocery_item("bubbly_burp_cola", "Bubbly Burp Cola", 0.99, "drinks", "knockoff", 7, 2, "cheap_soda", { "sugar": 17, "shelf_life_years": 2}),
		_grocery_item("blue_raspberry_chaos_juice", "Blue Raspberry Chaos Juice", 2.49, "drinks", "name_brand", 9, 5, "hyper_sweet_drink", { "sugar": 22, "shelf_life_years": 2}),
		_grocery_item("plainish_water_pack", "Plainish Water Pack", 3.99, "drinks", "store_brand", 1, 10, "water", { "sugar": 0, "shelf_life_years": 3}),
		_grocery_item("half_energy_can", "Half-Energy Can", 2.29, "drinks", "knockoff", 4, 4, "questionable_energy", { "sugar": 10, "shelf_life_years": 2}),

		_grocery_item("rice_bag", "Rice Bag", 5.0, "pantry", "store_brand", 26, 48, "basic", { "shelf_life_years": 4}),
		_grocery_item("noodle_brick_stack", "Noodle Brick Stack", 3.49, "pantry", "store_brand", 28, 20, "cheap_pantry", { "sodium": 18, "shelf_life_years": 5}),
		_grocery_item("pasta_swirl_box", "Pasta Swirl Box", 2.89, "pantry", "store_brand", 25, 36, "basic_pantry", { "shelf_life_years": 4}),
		_grocery_item("instant_gravy_dust", "Instant Gravy Dust", 1.39, "pantry", "knockoff", 8, 5, "questionable_pantry", { "sodium": 20, "shelf_life_years": 6}),

		_grocery_item("canned_sunday_beans", "Canned Sunday Beans", 1.49, "canned", "store_brand", 20, 42, "basic", { "protein": 6, "shelf_life_years": 5}),
		_grocery_item("suspicious_chunk_soup", "Suspicious Chunk Soup", 1.19, "canned", "knockoff", 18, 18, "cheap_canned", { "sodium": 18, "shelf_life_years": 6}),
		_grocery_item("tomato_saucey_sauce", "Tomato Saucey Sauce", 1.89, "canned", "store_brand", 10, 28, "sauce", { "shelf_life_years": 5}),

		_grocery_item("frozen_family_meal", "Frozen Family Meal", 9.0, "frozen", "store_brand", 30, 32, "cheap", { "sodium": 10, "shelf_life_years": 3}),
		_grocery_item("freezer_king_pizza", "Freezer King Pizza", 6.99, "frozen", "name_brand", 32, 26, "frozen_name_brand", { "sodium": 15, "shelf_life_years": 2}),
		_grocery_item("pizza_square_discount", "Pizza Square Discount", 3.99, "frozen", "knockoff", 28, 20, "cheap_frozen", { "sodium": 16, "shelf_life_years": 2}),
		_grocery_item("frozen_taco_loosies", "Frozen Taco Loosies", 5.49, "frozen", "store_brand", 26, 22, "frozen_discount", { "sodium": 14, "shelf_life_years": 2}),

		_grocery_item("fresh_salmon_pack", "Fresh Salmon Pack", 18.0, "protein", "name_brand", 34, 78, "high_quality", { "protein": 12, "shelf_life_years": 1}),
		_grocery_item("family_chicken_tray", "Family Chicken Tray", 12.49, "protein", "store_brand", 36, 65, "basic_protein", { "protein": 14, "shelf_life_years": 1}),
		_grocery_item("mystery_meat_roll", "Mystery Meat Roll", 4.99, "protein", "knockoff", 30, 18, "questionable_protein", { "protein": 8, "shelf_life_years": 1, "warning": "May be meat. May be ambition."}),

		_grocery_item("sunny_oranges_bag", "Sunny Oranges Bag", 4.49, "produce", "store_brand", 12, 62, "fresh", { "vitamins": 14, "shelf_life_years": 1}),
		_grocery_item("green_crisp_salad_kit", "Green Crisp Salad Kit", 5.99, "produce", "name_brand", 14, 70, "fresh_name_brand", { "vitamins": 16, "shelf_life_years": 1}),
		_grocery_item("sad_banana_bunch", "Sad Banana Bunch", 1.49, "produce", "knockoff", 10, 45, "discount_produce", { "vitamins": 10, "shelf_life_years": 1}),

		_grocery_item("everyday_milk_jug", "Everyday Milk Jug", 3.79, "dairy", "store_brand", 10, 35, "basic_dairy", { "protein": 5, "shelf_life_years": 1}),
		_grocery_item("cheddar_rectangle", "Cheddar Rectangle", 4.29, "dairy", "store_brand", 12, 30, "basic_dairy", { "protein": 6, "shelf_life_years": 1}),
		_grocery_item("yogurt_cups_of_destiny", "Yogurt Cups of Destiny", 5.19, "dairy", "name_brand", 9, 40, "cultured_name_brand", { "protein": 7, "shelf_life_years": 1})
	]


func _goldleaf_grocers_inventory() -> Array:
	return [
		_grocery_item("organic_family_crate", "Organic Family Crate", 80.0, "organic", "name_brand", 42, 88, "premium", { "vitamins": 18, "shelf_life_years": 1}),
		_grocery_item("saint_granola_clusters", "Saint Granola Clusters", 8.99, "cereal", "name_brand", 22, 64, "premium_cereal", { "sugar": 5, "shelf_life_years": 2}),
		_grocery_item("almost_saint_granola", "Almost Saint Granola", 4.49, "cereal", "knockoff", 20, 48, "discount_premium", { "sugar": 7, "shelf_life_years": 2}),
		_grocery_item("velvet_marsh_clouds", "Velvet Marsh Clouds", 11.49, "cereal", "name_brand", 21, 50, "luxury_sweet_cereal", { "sugar": 9, "shelf_life_years": 2}),
		_grocery_item("golden_oat_rings", "Golden Oat Rings", 9.79, "cereal", "name_brand", 20, 58, "premium_oat", { "sugar": 4, "shelf_life_years": 2}),
		_grocery_item("rich_people_flakes", "Rich People Flakes", 13.99, "cereal", "name_brand", 18, 55, "luxury_cereal", { "sugar": 3, "shelf_life_years": 2}),

		_grocery_item("moonlit_truffle_chips", "Moonlit Truffle Chips", 7.99, "snacks", "name_brand", 15, 18, "premium_snack", { "sodium": 8, "shelf_life_years": 1}),
		_grocery_item("velvet_cookie_thins", "Velvet Cookie Thins", 8.49, "snacks", "name_brand", 15, 20, "premium_sweet", { "sugar": 8, "shelf_life_years": 1}),
		_grocery_item("artisan_brownie_squares", "Artisan Brownie Squares", 9.29, "snacks", "name_brand", 17, 19, "premium_sweet", { "sugar": 11, "shelf_life_years": 1}),
		_grocery_item("goldleaf_fatcakes_almond", "Goldleaf Fatcakes • Almond Cream", 6.99, "snacks", "name_brand", 18, 14, "premium_cursed_snack", { "warning": "Still by ButterSockCompany. Less legally alarming.", "shelf_life_years": 1}),

		_grocery_item("velvet_berry_sparkle_water", "Velvet Berry Sparkle Water", 3.49, "drinks", "name_brand", 4, 12, "premium_drink", { "sugar": 1, "shelf_life_years": 2}),
		_grocery_item("fancy_air_water", "Fancy Air Water", 1.69, "drinks", "knockoff", 3, 8, "discount_drink", { "sugar": 0, "shelf_life_years": 2}),
		_grocery_item("pressed_sunrise_juice", "Pressed Sunrise Juice", 6.49, "drinks", "name_brand", 8, 42, "premium_juice", { "sugar": 9, "shelf_life_years": 1}),

		_grocery_item("goldleaf_salmon_board", "Goldleaf Salmon Board", 38.0, "protein", "name_brand", 38, 90, "premium_protein", { "protein": 16, "shelf_life_years": 1}),
		_grocery_item("grassfed_steak_medallions", "Grassfed Steak Medallions", 42.0, "protein", "name_brand", 40, 82, "luxury_protein", { "protein": 18, "shelf_life_years": 1}),
		_grocery_item("heritage_chicken_cutlets", "Heritage Chicken Cutlets", 24.0, "protein", "name_brand", 36, 75, "premium_protein", { "protein": 16, "shelf_life_years": 1}),

		_grocery_item("rain_misted_berries", "Rain-Misted Berries", 12.99, "produce", "name_brand", 13, 82, "premium_produce", { "vitamins": 20, "shelf_life_years": 1}),
		_grocery_item("celebrity_avocado_pair", "Celebrity Avocado Pair", 9.99, "produce", "name_brand", 12, 72, "luxury_produce", { "vitamins": 16, "shelf_life_years": 1}),
		_grocery_item("designer_salad_leaves", "Designer Salad Leaves", 14.99, "produce", "name_brand", 10, 86, "premium_leaf", { "vitamins": 24, "shelf_life_years": 1}),

		_grocery_item("glass_bottle_milk", "Glass Bottle Milk", 6.99, "dairy", "name_brand", 10, 45, "premium_dairy", { "protein": 7, "shelf_life_years": 1}),
		_grocery_item("tiny_french_cheese_wheel", "Tiny French-ish Cheese Wheel", 15.99, "dairy", "name_brand", 16, 52, "luxury_dairy", { "protein": 9, "shelf_life_years": 1})
	]


func _nutripod_exchange_inventory() -> Array:
	return [
		_grocery_item("compressed_nutripods", "Compressed Nutripods", 25.0, "future", "name_brand", 38, 76, "synthetic_balanced", { "shelf_life_years": 10}),
		_grocery_item("budget_nutri_dots", "Budget Nutri-Dots", 9.99, "future", "knockoff", 28, 52, "cheap_synthetic", { "shelf_life_years": 8}),
		_grocery_item("holo_loops_cereal", "Holo Loops Cereal", 12.99, "cereal", "name_brand", 22, 48, "future_name_brand", { "sugar": 8, "shelf_life_years": 5}),
		_grocery_item("fake_holo_circles", "Fake Holo Circles", 5.49, "cereal", "knockoff", 18, 36, "future_knockoff", { "sugar": 10, "shelf_life_years": 5}),
		_grocery_item("nebula_crunch_bag", "Nebula Crunch Bag", 8.5, "snacks", "name_brand", 16, 22, "future_snack", { "sodium": 6, "shelf_life_years": 5}),
		_grocery_item("space_dust_crisps", "Space Dust Crisps", 3.25, "snacks", "knockoff", 13, 14, "cheap_future_snack", { "sodium": 8, "shelf_life_years": 5}),
		_grocery_item("ion_soda_tube", "Ion Soda Tube", 4.99, "drinks", "name_brand", 8, 8, "future_drink", { "sugar": 9, "shelf_life_years": 5}),
		_grocery_item("bubble_battery_water", "Bubble Battery Water", 2.25, "drinks", "knockoff", 5, 5, "cheap_future_drink", { "sugar": 3, "shelf_life_years": 5})
	]