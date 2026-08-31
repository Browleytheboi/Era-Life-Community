extends Resource
class_name PetShopContractEngine

const ENGINE_SCHEMA:= "eralife.relationship_producer.pet_shop_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor",
			"type": "pet_shop_intent_rejected"
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"emit_surface"
			)
		)
	).strip_edges().to_lower()
	var source: String = str(
		payload.get(
			"source",
			"pet_shop_contract_engine.resolve_intent"
		)
	)

	match action_id:
		"", "emit_surface", "refresh", "open_shop", "observe_shop":
			var surface_contract: Dictionary = (
				emit_shop_surface_contract(
					actor,
					{
						"source": source,
						"read_only": true,
						"ui_is_renderer_only": true
					}
				)
			)

			return {
				"success": bool(
					surface_contract.get(
						"success",
						false
					)
				),
				"type": "pet_shop_surface_resolved",
				"actor_id": int(actor.id),
				"pet_shop_surface_contract": (
					surface_contract.duplicate(true)
				),
				"ui_is_renderer_only": true
			}
		"acquire_listing", "purchase_listing", "adopt_listing":
			var listing_id: String = str(
				payload.get(
					"listing_id",
					""
				)
			).strip_edges()

			var variant_id: String = str(
				payload.get(
					"variant_id",
					""
				)
			).strip_edges()

			if listing_id == "":
				return {
					"success": false,
					"reason": "missing_listing_id",
					"type": "pet_shop_acquisition_resolved",
					"text": "No companion listing was selected.",
					"popup_title": shop_label_for_current_era(),
					"popup_text": "No companion listing was selected.",
					"popup_footer": "Tap anywhere to continue."
				}

			var result: Dictionary = acquire_listing(
				actor,
				listing_id,
				{
					"source": source,
					"variant_id": variant_id,
					"global_intent_routed": true,
					"ui_is_renderer_only": true
				}
			)

			result [
				"type"
			] = "pet_shop_acquisition_resolved"
			result [
				"actor_id"
			] = int(
				actor.id
			)
			result [
				"listing_id"
			] = listing_id
			result [
				"variant_id"
			] = str(
				result.get(
					"variant_id",
					variant_id
				)
			)
			result [
				"global_intent_routed"
			] = true

			return result
		_:
			return {
				"success": false,
				"reason": "unsupported_action",
				"type": "pet_shop_intent_rejected",
				"action_id": action_id,
				"actor_id": int(actor.id)
			}
func shop_label_for_current_era() -> String:
	var era_name: String = _current_era_name().to_lower()
	if _mythical_allowed():
		return "Creature Market"
	if era_name.find("ancient") != -1:
		return "Animal Market"
	if era_name.find("medieval") != -1:
		return "Stable & Menagerie"
	if era_name.find("industrial") != -1:
		return "Animal Dealer"
	if era_name.find("future") != -1:
		return "Bio-Companion Gallery"
	return "Pet Shop"

func emit_shop_surface_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(actor.id)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var cache_key: String = _pet_shop_surface_cache_key(
		actor
	)
	var cache: Dictionary = _pet_shop_surface_cache()
	var cached: Dictionary = _safe_dictionary(
		cache.get(
			cache_key,
			cache.get(
				str(actor_id),
				{}
			)
		)
	)
	var cached_listings: Array = _safe_array(
		cached.get(
			"listings",
			[]
		)
	)
	var cached_surface_hot: bool = (
		not cached.is_empty()
		and str(
			cached.get(
				"schema",
				""
			)
		) == "eralife.pet_shop.surface_contract"
		and bool(
			cached.get(
				"success",
				false
			)
		)
		and int(
			cached.get(
				"actor_id",
				-1
			)
		) == actor_id
		and not cached_listings.is_empty()
		and str(
			cached.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower() == "hot"
	)

	if (
		not bool(
			context.get(
				"force_refresh",
				false
			)
		)
		and cached_surface_hot
	):
		cached ["cache_hit"] = true
		cached ["blank_surface_impossible"] = true
		cached ["resident_card_ready"] = true
		cached ["resident_premium_cards_published"] = true
		cached ["resident_premium_multigrid_cards_published"] = true
		cached ["visible_click_work_required"] = false
		cached ["visible_click_work_forbidden"] = true
		cached ["ready_gate_member"] = false

		cache [cache_key] = cached.duplicate(true)
		cache [str(actor_id)] = cached.duplicate(true)

		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"resident_pet_shop_surface_contract_by_actor"
			] = cache
			gs.scenario_state [
				"observable_pet_shop_surface_contract_by_actor"
			] = cache
			gs.scenario_state [
				"resident_pet_shop_surface_hot_actor_id"
			] = actor_id
			gs.scenario_state [
				"resident_pet_shop_surface_listing_count"
			] = cached_listings.size()
			gs.scenario_state [
				"resident_pet_shop_surface_truth_state"
			] = "hot"
			gs.scenario_state [
				"resident_pet_shop_premium_cards_published"
			] = true
			gs.scenario_state [
				"resident_pet_shop_premium_multigrid_cards_published"
			] = true

		EraLog.truth(
			"SHOP_SURFACE_PUBLISHED"
			+ "|actor_id=" + str(actor_id)
			+ "|cache_hit=true"
			+ "|listing_count=" + str(cached_listings.size())
			+ "|resident_registry=resident_pet_shop_surface_contract_by_actor"
			+ "|observable_registry=observable_pet_shop_surface_contract_by_actor"
			+ "|blank_surface=false"
			+ "|build_on_click=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return cached

	if not cached.is_empty():
		cache.erase(
			cache_key
		)
		cache.erase(
			str(actor_id)
		)

	var listings: Array = shop_inventory(
		actor,
		context
	)

	EraLog.truth(
		"SHOP_INVENTORY_CREATED"
		+ "|actor_id=" + str(actor_id)
		+ "|source=shop_inventory"
		+ "|listing_count=" + str(listings.size())
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	if listings.is_empty():
		listings = _provider_backed_fallback_inventory(
			context
		)

		EraLog.truth(
			"SHOP_INVENTORY_CREATED"
			+ "|actor_id=" + str(actor_id)
			+ "|source=provider_backed_fallback"
			+ "|listing_count=" + str(listings.size())
			+ "|build_on_click=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	if listings.is_empty():
		listings = _canonical_minimum_resident_inventory(
			actor,
			context
		)

		EraLog.truth(
			"SHOP_INVENTORY_CREATED"
			+ "|actor_id=" + str(actor_id)
			+ "|source=canonical_minimum_resident_inventory"
			+ "|listing_count=" + str(listings.size())
			+ "|build_on_click=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	if listings.is_empty():
		var guaranteed_rows: Array = [
			{
				"listing_id": "animal:dog",
				"entity_kind": "animal",
				"species_id": "dog",
				"display_name": "Dog",
				"description": "Loyal companion • trainable • danger 1",
				"price": 350,
				"species_contract": {
					"species_id": "dog",
					"display_name": "Dog",
					"base_price": 350,
					"lifespan_min": 10,
					"lifespan_max": 16,
					"intelligence_min": 45,
					"intelligence_max": 85,
					"trainable": true,
					"danger_level": 1,
					"social_type": "companion",
					"behavior_traits": [
						"loyal",
						"playful",
						"protective"
					]
				},
			},
			{
				"listing_id": "animal:cat",
				"entity_kind": "animal",
				"species_id": "cat",
				"display_name": "Cat",
				"description": "Independent companion • trainable • danger 1",
				"price": 240,
				"species_contract": {
					"species_id": "cat",
					"display_name": "Cat",
					"base_price": 240,
					"lifespan_min": 12,
					"lifespan_max": 18,
					"intelligence_min": 45,
					"intelligence_max": 80,
					"trainable": true,
					"danger_level": 1,
					"social_type": "companion",
					"behavior_traits": [
						"curious",
						"quiet",
						"affectionate"
					]
				},
			},
			{
				"listing_id": "animal:rabbit",
				"entity_kind": "animal",
				"species_id": "rabbit",
				"display_name": "Rabbit",
				"description": "Gentle companion • not trainable • danger 0",
				"price": 120,
				"species_contract": {
					"species_id": "rabbit",
					"display_name": "Rabbit",
					"base_price": 120,
					"lifespan_min": 7,
					"lifespan_max": 12,
					"intelligence_min": 25,
					"intelligence_max": 55,
					"trainable": false,
					"danger_level": 0,
					"social_type": "companion",
					"behavior_traits": [
						"gentle",
						"skittish",
						"soft"
					]
				},
			},
			{
				"listing_id": "animal:horse",
				"entity_kind": "animal",
				"species_id": "horse",
				"display_name": "Horse",
				"description": "Majestic companion • trainable • danger 2",
				"price": 2800,
				"species_contract": {
					"species_id": "horse",
					"display_name": "Horse",
					"base_price": 2800,
					"lifespan_min": 22,
					"lifespan_max": 32,
					"intelligence_min": 40,
					"intelligence_max": 75,
					"trainable": true,
					"danger_level": 2,
					"social_type": "companion",
					"behavior_traits": [
						"majestic",
						"fast",
						"strong"
					]
				},
			}
		]

		for raw_row in guaranteed_rows:
			var guaranteed_listing: Dictionary = _safe_dictionary(
				raw_row
			)

			if guaranteed_listing.is_empty():
				continue

			listings.append(
				_enrich_shop_listing(
					actor,
					guaranteed_listing
				)
			)

		EraLog.truth(
			"SHOP_INVENTORY_CREATED"
			+ "|actor_id=" + str(actor_id)
			+ "|source=constitutional_guaranteed_rows"
			+ "|listing_count=" + str(listings.size())
			+ "|build_on_click=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	for index in range(
		listings.size()
	):
		var listing: Dictionary = _safe_dictionary(
			listings [index]
		)

		if listing.is_empty():
			continue

		if not bool(
			listing.get(
				"precomputed_card_truth",
				false
			)
		):
			listing = _enrich_shop_listing(
				actor,
				listing
			)

		listing ["truth_state"] = "hot"
		listing ["resident_card_ready"] = true
		listing ["resident_premium_card"] = true
		listing ["resident_premium_multigrid_card"] = true
		listing ["visible_click_work_required"] = false
		listing ["visible_click_work_forbidden"] = true
		listing ["purchase_button_is_intent_door_only"] = true
		listing ["ready_gate_member"] = false
		listing ["ui_is_renderer_only"] = true
		listings [index] = listing

	var hot_listings: Array = []

	for raw_listing in listings:
		var listing: Dictionary = _safe_dictionary(
			raw_listing
		)

		if listing.is_empty():
			continue

		hot_listings.append(
			listing
		)

	var surface_contract: Dictionary = {
		"schema": "eralife.pet_shop.surface_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"surface_id": "pet_shop_contract_panel",
		"title": shop_label_for_current_era(),
		"subtitle": _shop_subtitle(),
		"actor_id": actor_id,
		"actor_name": "%s %s" % [
			str(actor.first_name),
			str(actor.last_name)
		],
		"listings": hot_listings.duplicate(true),
		"listing_count": hot_listings.size(),
		"truth_state": "hot",
		"surface_revision": "%s:%s" % [
			cache_key,
			str(hash(hot_listings))
		],
		"cache_key": cache_key,
		"resident_card_ready": true,
		"resident_premium_cards_published": true,
		"resident_premium_multigrid_cards_published": true,
		"blank_surface_impossible": true,
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ready_gate_member": false,
		"render_policy": {
			"ui_is_pure_renderer": true,
			"purchase_button_is_intent_door_only": true,
			"build_on_click": false,
			"ready_gate_member": false
		},
		"created_at_ms": now_ms
	}

	EraLog.truth(
		"SHOP_SURFACE_CREATED"
		+ "|actor_id=" + str(actor_id)
		+ "|listing_count=" + str(hot_listings.size())
		+ "|surface_revision="
		+ str(
			surface_contract.get(
				"surface_revision",
				""
			)
		)
		+ "|blank_surface=false"
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	cache [cache_key] = surface_contract.duplicate(true)
	cache [str(actor_id)] = surface_contract.duplicate(true)

	EraLog.truth(
		"SHOP_SURFACE_REGISTERED"
		+ "|actor_id=" + str(actor_id)
		+ "|cache_key=" + cache_key
		+ "|actor_key=" + str(actor_id)
		+ "|listing_count=" + str(hot_listings.size())
		+ "|registered=true"
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"resident_pet_shop_surface_contract_by_actor"
		] = cache
		gs.scenario_state [
			"observable_pet_shop_surface_contract_by_actor"
		] = cache
		gs.scenario_state [
			"pet_shop_surface_contract_by_actor"
		] = cache
		gs.scenario_state [
			"resident_pet_shop_surface_hot_actor_id"
		] = actor_id
		gs.scenario_state [
			"resident_pet_shop_surface_listing_count"
		] = hot_listings.size()
		gs.scenario_state [
			"resident_pet_shop_surface_truth_state"
		] = "hot"
		gs.scenario_state [
			"resident_pet_shop_blank_surface_impossible"
		] = true
		gs.scenario_state [
			"resident_pet_shop_surface_build_on_click"
		] = false
		gs.scenario_state [
			"resident_pet_shop_surface_visible_click_work_required"
		] = false
		gs.scenario_state [
			"resident_pet_shop_surface_visible_click_work_forbidden"
		] = true
		gs.scenario_state [
			"resident_pet_shop_premium_cards_published"
		] = true
		gs.scenario_state [
			"resident_pet_shop_premium_multigrid_cards_published"
		] = true
		gs.scenario_state [
			"resident_pet_shop_cache_key"
		] = cache_key
		gs.scenario_state [
			"resident_pet_shop_surface_published_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	EraLog.truth(
		"SHOP_SURFACE_PUBLISHED"
		+ "|actor_id=" + str(actor_id)
		+ "|listing_count=" + str(hot_listings.size())
		+ "|resident_registry=resident_pet_shop_surface_contract_by_actor"
		+ "|observable_registry=observable_pet_shop_surface_contract_by_actor"
		+ "|renderable=true"
		+ "|blank_surface=false"
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	return surface_contract
func _provider_backed_fallback_inventory(
	context: Dictionary = {}
) -> Array:
	var out: Array = []

	if (
		gs == null
		or gs.animal_contract_engine == null
	):
		return out

	var provider = gs.animal_contract_engine

	if (
		not provider.has_method(
			"species_registry"
		)
		or not provider.has_method(
			"define_species"
		)
	):
		return out

	var registry: Dictionary = _safe_dictionary(
		provider.species_registry()
	)
	var preferred_species_ids: Array = [
		"dog",
		"cat",
		"horse",
		"cow",
		"chicken",
		"sheep",
		"goat",
		"rabbit",
		"duck",
		"crow"
	]
	var candidate_ids: Array = []

	for raw_preferred_id in preferred_species_ids:
		var preferred_id: String = str(
			raw_preferred_id
		).strip_edges().to_lower()

		if registry.has(preferred_id):
			candidate_ids.append(preferred_id)

	for raw_registry_id in registry.keys():
		var registry_id: String = str(
			raw_registry_id
		).strip_edges().to_lower()

		if (
			registry_id != ""
			and not candidate_ids.has(registry_id)
		):
			candidate_ids.append(registry_id)

	for raw_candidate_id in candidate_ids:
		var candidate_id: String = str(
			raw_candidate_id
		).strip_edges().to_lower()

		if candidate_id == "":
			continue

		if (
			provider.has_method(
				"species_allowed_in_current_era"
			)
			and not bool(
				provider.species_allowed_in_current_era(
					candidate_id
				)
			)
		):
			continue

		var species: Dictionary = _safe_dictionary(
			provider.define_species(
				candidate_id,
				context
			)
		)

		if species.is_empty():
			continue

		out.append({
			"listing_id": "animal:%s" % candidate_id,
			"entity_kind": "animal",
			"species_id": candidate_id,
			"display_name": str(
				species.get(
					"display_name",
					candidate_id.capitalize()
				)
			),
			"description": "%s • %s • danger %d" % [
				str(
					species.get(
						"social_type",
						"companion"
					)
				).replace(
					"_",
					" "
				).capitalize(),
				(
					"trainable"
					if bool(
						species.get(
							"trainable",
							false
						)
					)
					else "not trainable"
				),
				int(
					species.get(
						"danger_level",
						0
					)
				)
			],
			"price": int(
				species.get(
					"base_price",
					100
				)
			),
			"species_contract": species.duplicate(true),
			"provider_backed_fallback": true
		})

		if out.size() >= 12:
			break

	return out
func _canonical_minimum_resident_inventory(
	actor: Person,
	_context: Dictionary = {}
) -> Array:
	var rows: Array = [
		{
			"listing_id": "animal:dog",
			"entity_kind": "animal",
			"species_id": "dog",
			"display_name": "Dog",
			"description": "Loyal household companion • trainable • family-safe.",
			"price": 150,
			"social_type": "companion",
			"age_label": "Young",
			"traits": ["loyal", "playful", "trainable"],
			"stats": {
				"health": 92,
				"smarts": 72,
				"trust": 78,
				"training": 42,
				"danger": 1
			}
		},
		{
			"listing_id": "animal:cat",
			"entity_kind": "animal",
			"species_id": "cat",
			"display_name": "Cat",
			"description": "Independent household companion • graceful • low-maintenance.",
			"price": 120,
			"social_type": "companion",
			"age_label": "Young",
			"traits": ["independent", "clever", "quiet"],
			"stats": {
				"health": 90,
				"smarts": 76,
				"trust": 54,
				"training": 24,
				"danger": 1
			}
		},
		{
			"listing_id": "animal:horse",
			"entity_kind": "animal",
			"species_id": "horse",
			"display_name": "Horse",
			"description": "Powerful riding companion • movement-ready • estate-friendly.",
			"price": 1200,
			"social_type": "mount",
			"age_label": "Adult",
			"traits": ["fast", "strong", "noble"],
			"stats": {
				"health": 96,
				"smarts": 64,
				"trust": 61,
				"training": 58,
				"danger": 2
			}
		},
		{
			"listing_id": "animal:rabbit",
			"entity_kind": "animal",
			"species_id": "rabbit",
			"display_name": "Rabbit",
			"description": "Gentle small companion • soft-tempered • child-friendly.",
			"price": 75,
			"social_type": "companion",
			"age_label": "Young",
			"traits": ["gentle", "small", "cute"],
			"stats": {
				"health": 84,
				"smarts": 46,
				"trust": 66,
				"training": 18,
				"danger": 0
			}
		},
		{
			"listing_id": "animal:goat",
			"entity_kind": "animal",
			"species_id": "goat",
			"display_name": "Goat",
			"description": "Hardy working animal • stubborn • useful around property.",
			"price": 220,
			"social_type": "working",
			"age_label": "Adult",
			"traits": ["hardy", "stubborn", "useful"],
			"stats": {
				"health": 88,
				"smarts": 48,
				"trust": 50,
				"training": 34,
				"danger": 1
			}
		},
		{
			"listing_id": "animal:crow",
			"entity_kind": "animal",
			"species_id": "crow",
			"display_name": "Crow",
			"description": "Sharp-eyed exotic companion • clever • unusually observant.",
			"price": 300,
			"social_type": "exotic",
			"age_label": "Adult",
			"traits": ["clever", "watchful", "mysterious"],
			"stats": {
				"health": 82,
				"smarts": 92,
				"trust": 38,
				"training": 44,
				"danger": 2
			}
		}
	]

	for row_index in range(rows.size()):
		var row: Dictionary = (
			rows [row_index] as Dictionary
		).duplicate(true)
		row ["canonical_resident_inventory"] = true
		row ["provider_backed_fallback"] = true
		row ["resident_card_ready"] = true
		row ["affordable"] = (
			actor != null
			and int(actor.bank_balance) >= int(
				row.get(
					"price",
					0
				)
			)
		)
		row ["shop_label"] = shop_label_for_current_era()
		rows [row_index] = row

	return rows
func shop_inventory(
	actor: Person,
	context: Dictionary = {}
) -> Array:
	var out: Array = []

	if (
		gs != null
		and gs.animal_contract_engine != null
		and gs.animal_contract_engine.has_method(
			"pet_shop_inventory"
		)
	):
		out.append_array(
			gs.animal_contract_engine.pet_shop_inventory(
				context
			)
		)

	if (
		gs != null
		and gs.mythical_contract_engine != null
		and gs.mythical_contract_engine.has_method(
			"pet_shop_inventory"
		)
	):
		out.append_array(
			gs.mythical_contract_engine.pet_shop_inventory(
				context
			)
		)




	if out.is_empty():
		out = _provider_backed_fallback_inventory(
			context
		)
	if out.is_empty():
		out = _canonical_minimum_resident_inventory(
			actor,
			context
		)
	var normalized: Array = []
	var listing_ids: Dictionary = {}

	for raw_listing in out:
		var listing: Dictionary = _safe_dictionary(
			raw_listing
		)

		if listing.is_empty():
			continue

		var listing_id: String = str(
			listing.get(
				"listing_id",
				""
			)
		).strip_edges()

		if (
			listing_id == ""
			or listing_ids.has(listing_id)
		):
			continue

		listing_ids [listing_id] = true
		listing = _enrich_shop_listing(
			actor,
			listing
		)
		listing ["affordable"] = (
			actor != null
			and int(actor.bank_balance) >= int(
				listing.get(
					"price",
					0
				)
			)
		)
		listing ["shop_label"] = shop_label_for_current_era()
		listing ["resident_card_ready"] = true
		normalized.append(listing)

	normalized.sort_custom(
		Callable(
			self,
			"_listing_sort"
		)
	)

	return normalized

func acquire_listing(
	actor: Person,
	listing_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"text": (
				"The shop could not resolve the buyer."
			),
			"reason": (
				"missing_actor_or_game_state"
			)
		}

	var listing: Dictionary = _find_listing(
		actor,
		listing_id,
		context
	)

	if listing.is_empty():
		return {
			"success": false,
			"text": (
				"That companion is no longer available."
			),
			"reason": "listing_not_found"
		}

	var variant_id: String = str(
		context.get(
			"variant_id",
			""
		)
	).strip_edges()

	var variant: Dictionary = (
		_resident_listing_variant(
			listing,
			variant_id
		)
	)

	var price: int = int(
		variant.get(
			"price",
			listing.get(
				"price",
				0
			)
		)
	)

	if int(
		actor.bank_balance
	) < price:
		return {
			"success": false,
			"text": (
				"You cannot afford %s right now."
				% str(
					variant.get(
						"display_name",
						listing.get(
							"display_name",
							"that companion"
						)
					)
				)
			),
			"popup_title": (
				shop_label_for_current_era()
			),
			"popup_text": (
				"You need $%d to bring this companion home."
				% price
			),
			"popup_footer": (
				"Tap anywhere to continue."
			),
			"reason": "not_enough_money"
		}

	var entity: Dictionary = {}

	var entity_kind: String = str(
		listing.get(
			"entity_kind",
			"animal"
		)
	).strip_edges().to_lower()

	var species_id: String = str(
		listing.get(
			"species_id",
			""
		)
	)

	if (
		entity_kind == "mythical"
		and gs.mythical_contract_engine != null
	):
		entity = (
			gs.mythical_contract_engine
			.create_mythical_entity(
				species_id,
				int(
					actor.id
				),
				{
					"source": ENGINE_SCHEMA
				}
			)
		)

	elif gs.animal_contract_engine != null:
		var anchor: Person = (
			_household_pet_anchor_for_actor(
				actor
			)
		)

		entity = (
			gs.animal_contract_engine
			.create_animal_entity(
				species_id,
				int(
					actor.id
				),
				{
					"source": ENGINE_SCHEMA,
					"household_pet_anchor_id": int(
						anchor.id
					),
					"household_access_actor_id": int(
						actor.id
					),
					"gender": str(
						variant.get(
							"gender",
							""
						)
					),
					"age": int(
						variant.get(
							"age_years",
							0
						)
					),
					"sub_species_id": str(
						variant.get(
							"sub_species_id",
							""
						)
					),
					"defer_relationship_graph_registration": true,
					"compact_entity_receipt": true
				}
			)
		)

	if entity.is_empty():
		return {
			"success": false,
			"text": (
				"That companion could not be created."
			),
			"reason": (
				"entity_creation_failed"
			)
		}


	actor.bank_balance -= price

	var entity_id: String = str(
		entity.get(
			"entity_id",
			""
		)
	)

	var companion_name: String = str(
		entity.get(
			"display_name",
			"your new companion"
		)
	)

	var species_name: String = str(
		entity.get(
			"species_name",
			listing.get(
				"display_name",
				"companion"
			)
		)
	)

	var sub_species_name: String = str(
		entity.get(
			"sub_species_name",
			variant.get(
				"sub_species_name",
				""
			)
		)
	).strip_edges()

	var gender: String = str(
		entity.get(
			"gender",
			variant.get(
				"gender",
				""
			)
		)
	).strip_edges()

	var age_years: int = int(
		entity.get(
			"age_years",
			variant.get(
				"age_years",
				0
			)
		)
	)



	# Watch the deferred hand-off itself: if the tail never runs, or runs and returns
	# through one of its guards without finishing, nothing else would ever report it.
	# Report which runtime the purchase is writing to. If a loaded save leaves the game
	# pointed at a different GameState than the one the resume restored into, pets
	# would commit to an object nothing reads.
	EraLog.truth(
		"ERALIFE_PET_RUNTIME|gs=%d|graph_engine=%s|entity_count=%d|edges=%d"
		% [
			int(gs.get_instance_id()),
			str(gs.relationship_graph_contract_engine != null),
			gs.entity_registry.size() if typeof(gs.entity_registry) == TYPE_DICTIONARY else -1,
			_safe_dictionary(gs.canonical_relationship_graph.get("edges", {})).size()
		]
	)

	EraLog.watch_begin(
		"pet_acquisition:%s" % entity_id,
		"pet_acquisition_tail"
	)

	EraLog.truth(
		"ERALIFE_PET_ACQUISITION_DISPATCH|actor_id=%d|entity_id='%s'|kind=%s|listing=%s|price=%d"
		% [
			int(actor.id),
			entity_id,
			entity_kind,
			listing_id,
			price
		]
	)

	call_deferred(
		"_commit_acquisition_relationship_tail",
		int(
			actor.id
		),
		entity_id,
		entity_kind,
		price,
		listing_id
	)

	var identity_text: String = (
		sub_species_name
		if sub_species_name != ""
		else species_name
	)

	var text: String = (
		"You brought home %s, a %s."
		% [
			companion_name,
			identity_text
		]
	)

	var rename_choices: Array = []

	if (
		entity_kind == "animal"
		and entity_id != ""
	):
		rename_choices = [
			{
				"id": "keep_pet_name",
				"label": (
					"KEEP %s"
					% companion_name.to_upper()
				),
				"detail_action": "pet_keep_name",
				"entity_id": entity_id,
				"original_name": companion_name
			},
			{
				"id": "rename_pet",
				"label": "RENAME",
				"detail_action": "pet_rename_prompt",
				"entity_id": entity_id,
				"original_name": companion_name
			}
		]

	return {
		"success": true,
		"type": "pet_shop_acquisition_resolved",
		"text": text,
		"popup_title": (
			shop_label_for_current_era()
		),
		"popup_text": (
			"%s\n\n%s is now in your PETS tab."
			% [
				text,
				companion_name
			]
		),
		"popup_footer": (
			"Keep the current name or rename your new companion."
			if not rename_choices.is_empty()
			else "Tap anywhere to continue."
		),
		"choices": rename_choices,
		"entity_id": entity_id,
		"entity_kind": entity_kind,
		"species_id": species_id,
		"sub_species_name": sub_species_name,
		"gender": gender,
		"age_years": age_years,
		"variant_id": str(
			variant.get(
				"variant_id",
				variant_id
			)
		),
		"companion_name": companion_name,
		"producer": ENGINE_SCHEMA
	}
func _commit_acquisition_relationship_tail(
	actor_id: int,
	entity_id: String,
	entity_kind: String,
	price: int,
	listing_id: String
) -> void:
	# DIAGNOSTIC: every exit below was previously silent, while acquire_listing()
	# still returned a success receipt ("relationship_graph_blocks_purchase_receipt"
	# is false). That means a pet could be paid for, created, and never registered as
	# a pet, with nothing reported anywhere. Run with --eralife-logs to see which one
	# fires.
	if (
		gs == null
		or actor_id <= 0
		or entity_id == ""
	):
		EraLog.truth(
			"ERALIFE_PET_ACQUISITION_TAIL|stage=aborted_bad_args|gs=%s|actor_id=%d|entity_id='%s'|kind=%s|listing=%s"
			% [
				str(gs != null),
				actor_id,
				entity_id,
				entity_kind,
				listing_id
			]
		)
		EraLog.watch_end("pet_acquisition:%s" % entity_id)
		return

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
			actor_id
		)

	if actor == null:
		EraLog.truth(
			"ERALIFE_PET_ACQUISITION_TAIL|stage=aborted_actor_not_found|actor_id=%d|entity_id=%s"
			% [actor_id, entity_id]
		)
		EraLog.watch_end("pet_acquisition:%s" % entity_id)
		return

	var entity_raw: Variant = gs.entity_registry.get(
		entity_id,
		{}
	)
	var entity: Dictionary = (
		(entity_raw as Dictionary).duplicate(false)
		if typeof(entity_raw) == TYPE_DICTIONARY
		else {}
	)

	var anchor: Person = (
		_household_pet_anchor_for_actor(
			actor
		)
	)

	if anchor == null:
		anchor = actor

	var owner_relationship_success: bool = false
	var household_relationship_success: bool = (
		int(anchor.id) == actor_id
	)

	EraLog.truth(
		"ERALIFE_PET_ACQUISITION_TAIL|stage=entered|actor_id=%d|entity_id=%s|entity_found_in_registry=%s|anchor_id=%d|graph_engine=%s"
		% [
			actor_id,
			entity_id,
			str(not entity.is_empty()),
			int(anchor.id),
			str(gs.relationship_graph_contract_engine != null)
		]
	)

	if gs.relationship_graph_contract_engine != null:
		if not entity.is_empty():
			gs.relationship_graph_contract_engine.ensure_entity(
				entity,
				{
					"source": (
						"pet_shop_acquisition_tail"
					),
					"canonical_owner_person_id": actor_id,
					"household_pet_anchor_id": int(
						anchor.id
					),
					"ui_blocking_forbidden": true
				}
			)

		var actor_entity: Dictionary = (
			gs.relationship_graph_contract_engine
			.ensure_person_entity(
				actor,
				{
					"source": (
						"pet_shop_acquisition_tail"
					)
				}
			)
		)

		var tags: Array = [
			"pet",
			"acquired_pet"
		]

		var relationship_type: String = "pet"
		var object_role: String = "Pet"

		if entity_kind == "mythical":
			tags.append(
				"mythical_pet"
			)
			relationship_type = "mythical_pet"
			object_role = "Mythical Pet"
		else:
			tags.append(
				"animal"
			)

		var owner_report: Dictionary = (
			gs.relationship_graph_contract_engine
			.commit_relationship_event(
				{
					"producer": ENGINE_SCHEMA,
					"event_type": (
						"pet_shop_acquisition"
					),
					"relationship_type": (
						relationship_type
					),
					"relationship_tags": tags,
					"subject_entity_id": str(
						actor_entity.get(
							"entity_id",
							""
						)
					),
					"object_entity_id": entity_id,
					"subject_role": "Owner",
					"object_role": object_role,
					"bond": 48,
					"price": price,
					"listing_id": listing_id,
					"context": {
						"source": (
							"pet_shop_acquisition_tail"
						),
						"owner_person_id": actor_id,
						"household_pet_anchor_id": int(
							anchor.id
						),
						"ui_blocking_forbidden": true
					}
				},
				{
					"producer": ENGINE_SCHEMA
				}
			)
		)

		owner_relationship_success = bool(
			owner_report.get(
				"success",
				false
			)
		)

		if int(
			anchor.id
		) != actor_id:
			var anchor_entity: Dictionary = (
				gs.relationship_graph_contract_engine
				.ensure_person_entity(
					anchor,
					{
						"source": (
							"pet_shop_household_membership_tail"
						)
					}
				)
			)

			var household_tags: Array = [
				"pet",
				"family_pet",
				"acquired_pet"
			]

			if entity_kind == "mythical":
				household_tags.append(
					"mythical_pet"
				)
			else:
				household_tags.append(
					"animal"
				)

			var household_report: Dictionary = (
				gs.relationship_graph_contract_engine
				.commit_relationship_event(
					{
						"producer": ENGINE_SCHEMA,
						"event_type": (
							"pet_shop_household_membership"
						),
						"relationship_type": "family_pet",
						"relationship_tags": household_tags,
						"subject_entity_id": str(
							anchor_entity.get(
								"entity_id",
								""
							)
						),
						"object_entity_id": entity_id,
						"subject_role": "Household",
						"object_role": (
							"Mythical Pet"
							if entity_kind == "mythical"
							else "Family Pet"
						),
						"bond": 48,
						"price": price,
						"listing_id": listing_id,
						"context": {
							"source": (
								"pet_shop_household_membership_tail"
							),
							"owner_person_id": actor_id,
							"household_pet_anchor_id": int(
								anchor.id
							),
							"ui_blocking_forbidden": true
						}
					},
					{
						"producer": ENGINE_SCHEMA
					}
				)
			)

			household_relationship_success = bool(
				household_report.get(
					"success",
					false
				)
			)

	_emit_pet_acquisition_diary_tail(
		actor,
		entity,
		price,
		listing_id
	)

	_queue_pet_relationship_projection_tail(
		actor_id,
		"pet_shop_acquisition"
	)

	EraLog.watch_end(
		"pet_acquisition:%s" % entity_id
	)

	EraLog.truth(
		"ERALIFE_PET_ACQUISITION_TAIL|stage=completed|gs=%d|graph_edges_total=%d|actor_id=%d|entity_id=%s|owner_edge=%s|household_edge=%s|anchor_id=%d|anchor_is_actor=%s"
		% [
			int(gs.get_instance_id()),
			_safe_dictionary(gs.canonical_relationship_graph.get("edges", {})).size(),
			actor_id,
			entity_id,
			str(owner_relationship_success),
			str(household_relationship_success),
			int(anchor.id),
			str(int(anchor.id) == actor_id)
		]
	)

	# FIX: the pet is committed to the relationship graph correctly (owner_edge and
	# household_edge both true), but nothing ever asked for the resident surfaces to
	# be rebuilt. Opening the Relationships tab reports
	# engine_intent_expressed=false / projection_request_queued=false, so it repaints
	# the projection built at world start -- from before the pet existed.
	#
	# RealityResidencyManager.request_attached_actor_projection_rebind() is the
	# existing mechanism for exactly this: it sets residency_tail_pending, which
	# _service_record() drives through begin/step_resident_projection(). Until now it
	# had a single caller (UniversalSwitchContractEngine, on character switch), which
	# is why surfaces only refreshed when you swapped who you were controlling.
	#
	# Rebind both the buyer and the household anchor: the pet card can appear under
	# either, depending on which one the pets section resolves.
	if (
		gs.reality_residency_manager != null
		and gs.reality_residency_manager.has_method(
			"request_attached_actor_projection_rebind"
		)
	):
		# NOTE: request_attached_actor_projection_rebind() only accepts the currently
		# controlled actor -- rebinding the household anchor returns
		# projection_rebind_actor_mismatch. Only the buyer is rebound; the pets
		# section falls back to the actor's own edges when the anchor differs.
		var rebind_actor_ids: Array = [actor_id]

		for raw_rebind_actor_id in rebind_actor_ids:
			var rebind_report: Dictionary = _safe_dictionary(
				gs.reality_residency_manager
				.request_attached_actor_projection_rebind(
					int(raw_rebind_actor_id),
					{
						"source": "pet_shop_acquisition_tail",
						"controlled_actor_id": actor_id,
						"acquired_entity_id": entity_id,
						"build_on_click_forbidden": true,
						"ready_gate_member": false,
						"ui_is_renderer_only": true
					}
				)
			)

			EraLog.truth(
				"ERALIFE_PET_ACQUISITION_REBIND|actor_id=%d|rebind_actor_id=%d|success=%s|reason=%s"
				% [
					actor_id,
					int(raw_rebind_actor_id),
					str(rebind_report.get("success", false)),
					str(rebind_report.get("reason", rebind_report.get("reason_id", "-")))
				]
			)

	set_meta(
		"pet_shop_last_relationship_tail_entity_id",
		entity_id
	)
	set_meta(
		"pet_shop_last_relationship_tail_success",
		owner_relationship_success
	)
	set_meta(
		"pet_shop_last_household_relationship_tail_success",
		household_relationship_success
	)
	set_meta(
		"pet_shop_relationship_tail_blocks_purchase_receipt",
		false
	)
	set_meta(
		"pet_shop_post_commit_projection_requires_idle",
		false
	)
	set_meta(
		"pet_shop_post_commit_projection_build_on_click",
		false
	)
func _emit_pet_acquisition_diary_tail(
	actor: Person,
	entity: Dictionary,
	price: int,
	listing_id: String
) -> void:
	if (
		gs == null
		or actor == null
		or entity.is_empty()
		or gs.life_diary_contract_engine == null
	):
		return

	var entity_id: String = str(
		entity.get(
			"entity_id",
			""
		)
	).strip_edges()

	var companion_name: String = str(
		entity.get(
			"display_name",
			"my new companion"
		)
	).strip_edges()

	var sub_species_name: String = str(
		entity.get(
			"sub_species_name",
			""
		)
	).strip_edges()

	var species_name: String = str(
		entity.get(
			"species_name",
			entity.get(
				"species_id",
				"companion"
			)
		)
	).strip_edges()

	var identity_parts: Array = []

	if sub_species_name != "":
		identity_parts.append(
			sub_species_name
		)

	if (
		species_name != ""
		and species_name.to_lower()
		!= sub_species_name.to_lower()
	):
		identity_parts.append(
			species_name
		)

	var identity_text: String = (
		" ".join(
			identity_parts
		).strip_edges()
	)

	if identity_text == "":
		identity_text = "companion"

	var diary_text: String = (
		"I bought %s, a %s, for $%d."
		% [
			companion_name,
			identity_text,
			price
		]
	)

	gs.life_diary_contract_engine.emit_diary_intent(
		{
			"type": "action_event",
			"actor_id": int(
				actor.id
			),
			"actor_name": (
				"%s %s"
				% [
					str(
						actor.first_name
					),
					str(
						actor.last_name
					)
				]
			).strip_edges(),
			"year": int(
				gs.year
			),
			"age": int(
				actor.age
			),
			"text": diary_text,
			"life_diary_text": diary_text,
			"append_to_current_year_block": true,
			"dedupe_key": (
				"pet_acquisition:%s:%s"
				% [
					entity_id,
					listing_id
				]
			),
			"source": (
				"pet_shop_contract_engine."
				+ "acquisition_diary_tail"
			),
			"meta": {
				"entity_id": entity_id,
				"listing_id": listing_id,
				"price": price,
				"ui_blocking_forbidden": true
			}
		},
		{
			"source": (
				"pet_shop_contract_engine."
				+ "acquisition_diary_tail"
			),
			"background_only": true,
			"blocks_ui": false,
			"ready_gate_member": false
		}
	)
func _queue_pet_relationship_projection_tail(
	actor_id: int,
	reason: String
) -> void:
	if (
		gs == null
		or actor_id <= 0
		or gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"queue_resident_relationship_section_refresh"
		)
	):
		return

	gs.reality_projection_contract_engine.queue_resident_relationship_section_refresh(
		actor_id,
		[
			"pets",
			"household"
		],
		{
			"source": (
				"pet_shop_contract_engine."
				+ "relationship_projection_tail"
			),
			"reason": reason,
			"background_only": true,
			"blocks_ui": false,
			"ui_interaction_grace_ignored": true,
			"build_on_click_forbidden": true,
			"ready_gate_member": false
		}
	)
func _household_pet_anchor_for_actor(actor: Person) -> Person:
	if gs == null or actor == null:
		return actor
	if gs.pets_contract_engine != null and gs.pets_contract_engine.has_method("_household_pet_anchor_for_actor"):
		var anchor = gs.pets_contract_engine._household_pet_anchor_for_actor(actor)
		if anchor != null:
			return anchor
	return actor
func _find_listing(
	actor: Person,
	listing_id: String,
	_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var cache: Dictionary = _pet_shop_surface_cache()

	var cache_key: String = (
		_pet_shop_surface_cache_key(
			actor
		)
	)

	var cached_surface_raw: Variant = cache.get(
		cache_key,
		cache.get(
			str(
				int(
					actor.id
				)
			),
			{}
		)
	)

	if typeof(cached_surface_raw) != TYPE_DICTIONARY:
		return {}

	var cached_surface: Dictionary = (
		cached_surface_raw as Dictionary
	)

	var listings_raw: Variant = cached_surface.get(
		"listings",
		[]
	)

	if typeof(listings_raw) != TYPE_ARRAY:
		return {}

	var listings: Array = (
		listings_raw as Array
	)

	for raw_listing in listings:
		if typeof(raw_listing) != TYPE_DICTIONARY:
			continue

		var listing: Dictionary = (
			raw_listing as Dictionary
		)

		if str(
			listing.get(
				"listing_id",
				""
			)
		) != listing_id:
			continue

		var resolved: Dictionary = (
			listing.duplicate(false)
		)

		resolved [
			"resolved_from_resident_shop_surface"
		] = true
		resolved [
			"shop_inventory_regenerated_on_purchase"
		] = false
		resolved [
			"purchase_path_deep_copy_performed"
		] = false

		return resolved




	return {}
func _shop_subtitle() -> String:
	if _mythical_allowed():
		return "Animals and mythical companions route into the same canonical relationship graph."
	return "Companions route into the same canonical relationship graph as people."

func _mythical_allowed() -> bool:
	return gs != null and gs.mythical_contract_engine != null and gs.mythical_contract_engine.has_method("mythical_allowed_for_current_reality") and gs.mythical_contract_engine.mythical_allowed_for_current_reality()
func _pet_shop_surface_cache_key(
	actor: Person
) -> String:
	if actor == null:
		return ""

	return "%d:%d:%s" % [
		int(actor.id),
		int(gs.year) if gs != null else 0,
		_current_era_name().strip_edges().to_lower()
	]


func _pet_shop_surface_cache() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	return _safe_dictionary(
		gs.scenario_state.get(
			"resident_pet_shop_surface_contract_by_actor",
			{}
		)
	)


func _listing_seed_value(
	listing_id: String,
	actor_id: int,
	salt: String
) -> int:
	return abs(
		hash(
			"%s:%d:%d:%s" % [
				listing_id,
				actor_id,
				int(gs.year) if gs != null else 0,
				salt
			]
		)
	)


func _enrich_shop_listing(
	actor: Person,
	listing: Dictionary
) -> Dictionary:
	var out: Dictionary = listing.duplicate(false)

	var listing_id: String = str(
		out.get(
			"listing_id",
			"companion"
		)
	)

	var actor_id: int = (
		int(
			actor.id
		)
		if actor != null
		else -1
	)

	var species_raw: Variant = out.get(
		"species_contract",
		{}
	)

	var species: Dictionary = (
		species_raw as Dictionary
		if typeof(species_raw) == TYPE_DICTIONARY
		else {}
	)

	var intelligence_min: int = clampi(
		int(
			species.get(
				"intelligence_min",
				25
			)
		),
		0,
		100
	)

	var intelligence_max: int = clampi(
		int(
			species.get(
				"intelligence_max",
				70
			)
		),
		intelligence_min,
		100
	)

	var intelligence_span: int = maxi(
		1,
		intelligence_max - intelligence_min + 1
	)

	var trainable: bool = bool(
		species.get(
			"trainable",
			false
		)
	)

	var entity_kind: String = str(
		out.get(
			"entity_kind",
			"animal"
		)
	).strip_edges().to_lower()

	var variants: Array = []

	if (
		entity_kind == "animal"
		and gs != null
		and gs.animal_contract_engine != null
		and gs.animal_contract_engine.has_method(
			"pet_shop_variant_contracts_for_species"
		)
	):
		var variants_raw: Variant = (
			gs.animal_contract_engine
			.pet_shop_variant_contracts_for_species(
				str(
					out.get(
						"species_id",
						""
					)
				),
				actor_id,
				listing_id
			)
		)

		if typeof(variants_raw) == TYPE_ARRAY:
			variants = variants_raw as Array

	if variants.is_empty():
		var lifespan_min: int = maxi(
			2,
			int(
				species.get(
					"lifespan_min",
					8
				)
			)
		)

		var age_cap: int = maxi(
			1,
			mini(
				lifespan_min - 1,
				8
			)
		)

		var fallback_age: int = 1 + (
			_listing_seed_value(
				listing_id,
				actor_id,
				"age"
			) % age_cap
		)

		variants = [
			{
				"variant_id": (
					"%s:default"
					% listing_id
				),
				"listing_id": listing_id,
				"species_id": str(
					out.get(
						"species_id",
						""
					)
				),
				"species_name": str(
					out.get(
						"display_name",
						"Companion"
					)
				),
				"sub_species_id": "",
				"sub_species_name": str(
					out.get(
						"display_name",
						"Companion"
					)
				),
				"display_name": str(
					out.get(
						"display_name",
						"Companion"
					)
				),
				"gender": "",
				"gender_label": "",
				"age_years": fallback_age,
				"age_label": (
					"1 year old"
					if fallback_age == 1
					else "%d years old"
					% fallback_age
				),
				"age_stage": "resident",
				"age_stage_label": "Resident",
				"breeding_status_label": ""
			}
		]

	var enriched_variants: Array = []

	for raw_variant in variants:
		if typeof(raw_variant) != TYPE_DICTIONARY:
			continue

		var variant: Dictionary = (
			raw_variant as Dictionary
		).duplicate(false)

		var variant_id: String = str(
			variant.get(
				"variant_id",
				"%s:default" % listing_id
			)
		)

		variant [
			"price"
		] = int(
			out.get(
				"price",
				0
			)
		)

		variant [
			"stats"
		] = {
			"health": 72 + (
				_listing_seed_value(
					variant_id,
					actor_id,
					"health"
				) % 29
			),
			"smarts": intelligence_min + (
				_listing_seed_value(
					variant_id,
					actor_id,
					"smarts"
				) % intelligence_span
			),
			"trust": 28 + (
				_listing_seed_value(
					variant_id,
					actor_id,
					"trust"
				) % 43
			),
			"training": (
				_listing_seed_value(
					variant_id,
					actor_id,
					"training"
				) % 56
				if trainable
				else 0
			),
			"danger": clampi(
				int(
					species.get(
						"danger_level",
						0
					)
				),
				0,
				10
			),
			"magic_attunement": (
				55 + (
					_listing_seed_value(
						variant_id,
						actor_id,
						"magic"
					) % 46
				)
				if entity_kind == "mythical"
				else 0
			)
		}

		variant [
			"traits"
		] = (
			(
				species.get(
					"behavior_traits",
					[]
				) as Array
			).duplicate(false)
			if typeof(
				species.get(
					"behavior_traits",
					[]
				)
			) == TYPE_ARRAY
			else []
		)

		variant [
			"social_type"
		] = str(
			species.get(
				"social_type",
				"companion"
			)
		)

		variant [
			"trainable"
		] = trainable

		enriched_variants.append(
			variant
		)

	if enriched_variants.is_empty():
		return out

	var default_variant: Dictionary = (
		enriched_variants [
			0
		] as Dictionary
	)

	for key in [
		"age_years",
		"age_label",
		"age_stage",
		"age_stage_label",
		"gender",
		"gender_label",
		"sub_species_id",
		"sub_species_name",
		"breeding_age_reached",
		"breeding_status_label",
		"stats",
		"traits",
		"social_type",
		"trainable"
	]:
		if default_variant.has(
			key
		):
			out [
				key
			] = default_variant [
				key
			]

	out [
		"variant_contracts"
	] = enriched_variants
	out [
		"variant_count"
	] = enriched_variants.size()
	out [
		"default_variant_id"
	] = str(
		default_variant.get(
			"variant_id",
			""
		)
	)
	out [
		"variant_carousel_enabled"
	] = enriched_variants.size() > 1
	out [
		"variant_carousel_engine_calls_on_arrow"
	] = false
	out [
		"variant_carousel_all_truth_resident"
	] = true
	out [
		"precomputed_card_truth"
	] = true

	return out
func _resident_listing_variant(
	listing: Dictionary,
	variant_id: String
) -> Dictionary:
	var clean_variant_id: String = str(
		variant_id
	).strip_edges()

	var variants_raw: Variant = listing.get(
		"variant_contracts",
		[]
	)

	if typeof(variants_raw) != TYPE_ARRAY:
		return {}

	var variants: Array = (
		variants_raw as Array
	)

	if variants.is_empty():
		return {}

	if clean_variant_id == "":
		var first_raw: Variant = variants [
			0
		]

		return (
			(first_raw as Dictionary).duplicate(false)
			if typeof(first_raw) == TYPE_DICTIONARY
			else {}
		)

	for raw_variant in variants:
		if typeof(raw_variant) != TYPE_DICTIONARY:
			continue

		var variant: Dictionary = (
			raw_variant as Dictionary
		)

		if str(
			variant.get(
				"variant_id",
				""
			)
		) == clean_variant_id:
			return variant.duplicate(false)

	return {}
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.get("name", gs.era.get("id", ""))) if typeof(gs.era) == TYPE_DICTIONARY else str(gs.era.name)
	return "modern"

func _listing_sort(a, b) -> bool:
	return int(_safe_dictionary(a).get("price", 0)) < int(_safe_dictionary(b).get("price", 0))

func _safe_dictionary(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}