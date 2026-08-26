extends Resource
class_name ManyRealmsEngine

var gs

func _init(_gs):
	gs = _gs






var hidden_realms:= {}


var ring_owner_id: int = -1

const ERA_KINGDOM_ID:= "era_kingdom"

var RING_DEF:= {

	"name": "The Ring of Many Realms",
	"type": "Artifact",
	"rarity": "Mythic",
	"mythic_rank": "mythic",
	"item_family": "many_realms_ring",
	"singleton_key": "ring_of_many_realms",
	"color": "violet",
	"ability": "Reveals the hidden Era Kingdom, binds sovereignty to its wearer, and grants audience with the simulation's deepest balance structures.",
	"lore": "A sovereign artifact that reveals the hidden Era Kingdom to its wearer and binds them to its throne. Its metal remembers dynasties, wars, debts, and realities that ordinary rulers never even learn exist."

}







func yearly_discovery_chance():

	if ring_owner_id != -1:
		return


	if randi() % 85000 != 0:
		return

	var candidates:= []
	for npc in gs.npcs:
		if npc.alive and npc.age >= 18:
			candidates.append(npc)

	if candidates.size() == 0:
		return

	var holder = candidates [randi() % candidates.size()]
	give_ring(holder)


func give_ring(npc: Person):

	if npc == null:
		return
	if ring_owner_id != -1 and ring_owner_id != npc.id:
		var prev = gs.get_npc_by_id(ring_owner_id)
		if prev != null:
			prev.has_many_realms_ring = false
			prev.hidden_realm_visible = false
			prev.hidden_realm_title = ""
			if gs.belongings_engine != null and gs.belongings_engine.has_method("remove_item_named"):
				gs.belongings_engine.remove_item_named(prev, "Artifacts", str(RING_DEF ["name"]))
	ring_owner_id = npc.id
	npc.has_many_realms_ring = true
	npc.hidden_realm_visible = true
	npc.hidden_realm_title = "Sovereign of the Era Kingdom"
	npc.hidden_realm_id = ERA_KINGDOM_ID
	npc.is_ruler = true
	if gs.belongings_engine != null:
		var should_add_ring: bool = true
		if gs.belongings_engine.has_method("has_item_named"):
			should_add_ring = not gs.belongings_engine.has_item_named(npc, "Artifacts", str(RING_DEF ["name"]))
		if should_add_ring:
			var ring_item_id: int = int(gs.next_id)
			gs.next_id += 1
			gs.belongings_engine.add_item(npc, {
				"id": ring_item_id,
				"name": RING_DEF ["name"],
				"type": RING_DEF ["type"],
				"rarity": RING_DEF ["rarity"],
				"lore": RING_DEF ["lore"],
				"ability": RING_DEF ["ability"],
				"color": RING_DEF ["color"],
				"origin_era": str(gs.era.name),
				"acquired_year": int(gs.year),
				"mythic_rank": RING_DEF ["mythic_rank"],
				"item_family": RING_DEF ["item_family"],
				"singleton_key": RING_DEF ["singleton_key"]
			}, "Artifacts")
	if not hidden_realms.has(ERA_KINGDOM_ID):
		_initialize_era_kingdom(npc)
	else:
		_assign_sovereign(npc)
	var msg = " 👑 %s %s has obtained the Ring of Many Realms." % [

		npc.first_name, npc.last_name
	]
	gs.push_world_feed(msg, {
		"npc_id": npc.id,
		"personally_relevant": npc == gs.player,
		"category": "artifact",
		"event_name": ActionEventTypes.MANY_REALMS_RING_ACQUIRED,
		"source": "many_realms_engine"
	})
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, {
			"npc_id": npc.id,
			"text": msg
		})
	npc.memories.append(
		"I slipped on the Ring of Many Realms and the hidden Era Kingdom opened before me."
	)
func _roll_large_int_range(minimum_value: int, maximum_value: int) -> int:
	var floor_value: int = int(minimum_value)
	var ceiling_value: int = int(maximum_value)

	if ceiling_value < floor_value:
		var swap_value: int = floor_value
		floor_value = ceiling_value
		ceiling_value = swap_value

	floor_value = max(floor_value, 0)
	ceiling_value = max(ceiling_value, floor_value)

	if ceiling_value <= floor_value:
		return floor_value

	var span: float = float(ceiling_value - floor_value)
	var rolled_value: int = floor_value + int(floor(randf() * (span + 1.0)))
	return clamp(rolled_value, floor_value, ceiling_value)

func _roll_era_kingdom_population(min_population:= 10000000000, max_population:= 25000000000) -> int:
	var floor_population: int = max(int(min_population), 10000000000)
	var ceiling_population: int = max(floor_population, int(max_population))
	return _roll_large_int_range(floor_population, ceiling_population)

func _normalize_era_kingdom_population(raw_population: int, reroll_stale_floor:= false) -> int:
	var population_value: int = int(raw_population)

	if population_value < 10000000000:
		return _roll_era_kingdom_population(10000000000, 25000000000)

	if population_value > 25000000000:
		return 25000000000

	if reroll_stale_floor and population_value == 10000000000:
		return _roll_era_kingdom_population(10000000000, 25000000000)

	return population_value

func _era_kingdom_current_life_key() -> String:
	if gs == null:
		return "no_gs"

	var player_instance_id: int = 0
	var player_id: int = 0
	var player_name: String = "no_player"

	if gs.player != null:
		player_instance_id = int(gs.player.get_instance_id())
		player_id = int(gs.player.id)
		player_name = "%s_%s" % [
			str(gs.player.first_name).strip_edges(),
			str(gs.player.last_name).strip_edges()
		]

	return "%s:%s:%s:%s" % [
		str(player_instance_id),
		str(player_id),
		player_name,
		str(gs.year)
	]
func _initialize_era_kingdom(sovereign: Person):
	var founding_houses:= _generate_ruling_houses(sovereign)
	var subzones:= _build_era_kingdom_subzones()
	var population_profile:= _get_or_create_era_kingdom_surface_preview_profile()
	if population_profile.is_empty():
		population_profile = _build_era_kingdom_population_profile(
			_roll_era_kingdom_population(10000000000, 25000000000)
		)
	var total_population: int = _normalize_era_kingdom_population(
		int(population_profile.get("total_population", 0)),
		true
	)
	population_profile ["total_population"] = total_population
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["era_kingdom_surface_preview_profile"] = population_profile.duplicate(true)

	var military_values: Dictionary = _build_era_kingdom_military_values(total_population, population_profile)
	var military_units_value: int = int(military_values.get("military_units", 0))
	var military_stockpile_value: int = int(military_values.get("military_stockpile", military_units_value))

	var goods_stockpile_floor: int = max(320000000, int(round(float(total_population) * 0.02)))
	var goods_stockpile_ceiling: int = max(goods_stockpile_floor, int(round(float(total_population) * 0.07)))
	var goods_stockpile_value: int = randi_range(goods_stockpile_floor, goods_stockpile_ceiling)
	goods_stockpile_value = clamp(goods_stockpile_value, 0, total_population)

	var treasury_floor: int = max(420000000000000000, int(round(float(total_population) * 42000000.0)))
	var treasury_ceiling: int = max(treasury_floor, int(round(float(total_population) * 98000000.0)))
	var treasury_value: int = _roll_large_int_range(treasury_floor, treasury_ceiling)
	treasury_value = max(treasury_value, treasury_floor)

	hidden_realms [ERA_KINGDOM_ID] = {
		"id": ERA_KINGDOM_ID,
		"name": "Era Kingdom",
		"realm_kind": "sovereign_hidden_country",
		"dimension_type": "hidden_parallel_realm",
		"visible_to_owner_only": true,
		"is_country_surface": true,
		"government_style": "Sovereign Arbitration Monarchy",
		"capital_city": str(subzones [0]),
		"subzones": subzones.duplicate(),
		"population": total_population,
		"population_profile": population_profile.duplicate(true),
		"entry_rule": "ring_required",
		"ui_population_browse_allowed": false,
		"hide_people_button": true,
		"loyalty": 100,
		"prosperity": 100,
		"stability": 100,
		"military_pressure": randi_range(0, 5),
		"rebel_pressure": 0,
		"military_units": military_units_value,
		"military_stockpile": military_stockpile_value,
		"military": int(military_values.get("military", military_stockpile_value)),
		"goods_stockpile": goods_stockpile_value,
		"land": randi_range(88000000, 190000000),
		"land_label": "Interrealm Holdings",
		"treasury": treasury_value,
		"currency_name": "Era Crowns",
		"build_budget_infinite": true,
		"trade_rules": _build_era_kingdom_trade_rules(),
		"services": _build_era_kingdom_service_capabilities(),
		"bender_demographics": _build_era_kingdom_bender_distribution(total_population),
		"ruler_id": sovereign.id,
		"ruling_houses": founding_houses,
		"faction_matrix": _build_era_kingdom_faction_matrix(sovereign, founding_houses),
		"founded_year": gs.year,
		"history": [
			"Founded in %d when %s %s first wore the Ring of Many Realms." % [
				gs.year, sovereign.first_name, sovereign.last_name
			]
		]
	}
	var msg = "\nThe hidden Era Kingdom has manifested for %s %s." % [
		sovereign.first_name, sovereign.last_name
	]
	gs.push_world_feed(msg, {
		"npc_id": sovereign.id,
		"personally_relevant": sovereign == gs.player,
		"category": "realm",
		"event_name": ActionEventTypes.MANY_REALMS_REALM_CREATED,
		"source": "many_realms_engine"
	})
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.MANY_REALMS_REALM_CREATED, {
			"npc_id": sovereign.id,
			"text": msg
		})
func emit_world_browser_hidden_surface_registry(
	context: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {}

	var registry: Dictionary = hidden_realms.duplicate(false)
	var include_era_kingdom_preview: bool = bool(
		context.get(
			"include_era_kingdom_preview",
			true
		)
	)

	if registry.has(ERA_KINGDOM_ID):
		var resident_raw: Variant = registry.get(
			ERA_KINGDOM_ID,
			{}
		)

		if typeof(resident_raw) == TYPE_DICTIONARY:
			var resident_realm: Dictionary = (
				resident_raw as Dictionary
			).duplicate(true)
			resident_realm = repair_era_kingdom_surface_realm(
				resident_realm
			)
			resident_realm ["entry_id"] = ERA_KINGDOM_ID
			resident_realm ["realm_browser_section"] = (
				"interrealm_authority"
			)
			resident_realm ["browser_sort_priority"] = 0
			resident_realm ["surface_exists"] = true
			resident_realm ["surface_preview_only"] = false
			resident_realm ["manifested"] = true
			resident_realm ["ui_is_renderer_only"] = true
			registry [ERA_KINGDOM_ID] = resident_realm

		return registry

	if not include_era_kingdom_preview:
		return registry

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var preview_life_key: String = _era_kingdom_current_life_key()
	var cached_life_key: String = str(
		gs.scenario_state.get(
			"era_kingdom_world_browser_preview_life_key",
			""
		)
	).strip_edges()
	var cached_preview_raw: Variant = gs.scenario_state.get(
		"era_kingdom_world_browser_preview_contract",
		{}
	)
	var cached_preview: Dictionary = (
		(cached_preview_raw as Dictionary).duplicate(true)
		if typeof(cached_preview_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		cached_life_key == preview_life_key
		and not cached_preview.is_empty()
	):
		registry [ERA_KINGDOM_ID] = cached_preview
		return registry

	var population_profile: Dictionary = (
		_get_or_create_era_kingdom_surface_preview_profile()
	)
	var population: int = _normalize_era_kingdom_population(
		int(
			population_profile.get(
				"total_population",
				10000000000
			)
		)
	)
	population_profile ["total_population"] = population

	var military_values: Dictionary = (
		_build_era_kingdom_military_values(
			population,
			population_profile
		)
	)
	var military_units: int = int(
		military_values.get(
			"military_units",
			int(round(float(population) * 0.08))
		)
	)
	var military_stockpile: int = int(
		military_values.get(
			"military_stockpile",
			int(round(float(population) * 0.12))
		)
	)
	var treasury: int = _roll_large_int_range(
		720000000000000000,
		999999999999999999
	)
	var goods_stockpile: int = _roll_large_int_range(
		420000000,
		920000000
	)
	var preview: Dictionary = {
		"id": ERA_KINGDOM_ID,
		"entry_id": ERA_KINGDOM_ID,
		"name": "Era Kingdom",
		"realm_kind": "sovereign_hidden_country",
		"dimension_type": "hidden_parallel_realm",
		"realm_browser_section": "interrealm_authority",
		"browser_sort_priority": 0,
		"visible_to_owner_only": true,
		"is_country_surface": true,
		"government_style": "Prophetic Regency",
		"ruler_name": "Prophecy Regent",
		"capital_city": "Chronos Gate",
		"subzones": [
			"Chronos Gate",
			"Crown of Glass",
			"The Archive Basin",
			"Balance Reach"
		],
		"population": population,
		"population_profile": population_profile.duplicate(true),
		"land": 144000000,
		"land_label": "Interrealm Holdings",
		"treasury": treasury,
		"build_budget_infinite": true,
		"currency_name": "Era Crowns",
		"military_units": military_units,
		"military_stockpile": military_stockpile,
		"military": int(
			military_values.get(
				"military",
				military_stockpile
			)
		),
		"goods_stockpile": goods_stockpile,
		"entry_rule": "prophecy_locked",
		"access_state": "prophecy_locked",
		"ui_population_browse_allowed": false,
		"hide_people_button": true,
		"loyalty": 100,
		"prosperity": 100,
		"stability": 100,
		"trade_rules": _build_era_kingdom_trade_rules(),
		"services": _build_era_kingdom_service_capabilities(),
		"surface_exists": true,
		"surface_preview_only": true,
		"manifested": false,
		"truth_state": "observable_preview",
		"click_path_build_forbidden": true,
		"ui_is_renderer_only": true
	}

	gs.scenario_state [
		"era_kingdom_world_browser_preview_life_key"
	] = preview_life_key
	gs.scenario_state [
		"era_kingdom_world_browser_preview_contract"
	] = preview.duplicate(true)
	gs.scenario_state [
		"era_kingdom_world_browser_preview_ready_gate_member"
	] = false
	gs.scenario_state [
		"era_kingdom_world_browser_preview_engine_owned"
	] = true

	registry [ERA_KINGDOM_ID] = preview
	return registry
func _build_era_kingdom_subzones() -> Array:

	return [
		"Chronos Gate",
		"Crown of Glass",
		"The Archive Basin",
		"Balance Reach",
		"The Violet Foundry",
		"House Meridian",
		"The Loan Vault",
		"Judgment Terrace",
		"The Fourfold Quarter",
		"The Lineage Gardens",
		"The Quiet Barracks",
		"The Astral Docks"
	]

func _build_era_kingdom_population_profile(total_population_override:= -1) -> Dictionary:
	var total_population: int = int(total_population_override)
	if total_population <= 0:
		total_population = _roll_era_kingdom_population(10000000000, 25000000000)
	total_population = _normalize_era_kingdom_population(total_population, true)

	var children: int = int(round(float(total_population) * 0.24))
	var young_adults: int = int(round(float(total_population) * 0.19))
	var adults: int = int(round(float(total_population) * 0.36))
	var older_adults: int = int(round(float(total_population) * 0.14))
	var elders: int = max(1, total_population - children - young_adults - adults - older_adults)

	var military_units_ratio: float = randf_range(0.08, 0.13)
	var military_display_ratio: float = randf_range(max(military_units_ratio, 0.08), 0.18)

	return {
		"total_population": total_population,
		"profile_source": "era_kingdom_population_profile_v3",
		"population_range_min": 10000000000,
		"population_range_max": 25000000000,
		"age_bands": {
			"children": children,
			"young_adults": young_adults,
			"adults": adults,
			"older_adults": older_adults,
			"elders": elders
		},
		"military_profile": {
			"units_ratio": military_units_ratio,
			"display_ratio": military_display_ratio
		},
		"lineage_density": "mythic_dense",
		"bootstrap_strategy": "on_demand_hidden_realm_shards",
		"instantiated_resident_cap": 480,
		"notes": [
			"Citizens are represented as lineage-backed demographic truth first, then instantiated through shard/bootstrap pathways only when a surface genuinely needs a live person.",
			"No player can be born here without the Ring of Many Realms."
		]
	}
func _era_kingdom_population_profile_needs_repair(population_profile: Dictionary) -> bool:
	if population_profile.is_empty():
		return true

	var total_population: int = int(population_profile.get("total_population", 0))
	if total_population <= 0:
		return true
	if total_population < 10000000000 or total_population > 25000000000:
		return true

	var profile_source: String = str(population_profile.get("profile_source", "")).strip_edges()
	if total_population <= 10000000000:
		return true
	if profile_source not in ["era_kingdom_population_profile_v2", "era_kingdom_population_profile_v3"]:
		return true

	var age_bands_raw: Variant = population_profile.get("age_bands", {})
	var military_profile_raw: Variant = population_profile.get("military_profile", {})
	if typeof(age_bands_raw) != TYPE_DICTIONARY:
		return true
	if typeof(military_profile_raw) != TYPE_DICTIONARY:
		return true

	return false
func _get_or_create_era_kingdom_surface_preview_profile() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var current_life_key: String = _era_kingdom_current_life_key()
	var cached_life_key: String = str(gs.scenario_state.get("era_kingdom_surface_preview_profile_life_key", "")).strip_edges()

	var cached_raw: Variant = gs.scenario_state.get("era_kingdom_surface_preview_profile", {})
	var cached: Dictionary = cached_raw if typeof(cached_raw) == TYPE_DICTIONARY else {}
	if cached_life_key == current_life_key and not cached.is_empty() and not _era_kingdom_population_profile_needs_repair(cached):
		var cached_total: int = _normalize_era_kingdom_population(int(cached.get("total_population", 0)), true)
		if cached_total >= 10000000000 and cached_total <= 25000000000:
			cached ["total_population"] = cached_total
			cached ["profile_source"] = "era_kingdom_population_profile_v3"
			cached ["population_range_min"] = 10000000000
			cached ["population_range_max"] = 25000000000
			gs.scenario_state ["era_kingdom_surface_preview_profile"] = cached.duplicate(true)
			gs.scenario_state ["era_kingdom_surface_preview_profile_life_key"] = current_life_key
			return cached.duplicate(true)

	var profile: Dictionary = _build_era_kingdom_population_profile(
		_roll_era_kingdom_population(10000000000, 25000000000)
	)
	profile ["total_population"] = _normalize_era_kingdom_population(
		int(profile.get("total_population", 0)),
		true
	)
	profile ["profile_source"] = "era_kingdom_population_profile_v3"
	profile ["population_range_min"] = 10000000000
	profile ["population_range_max"] = 25000000000
	gs.scenario_state ["era_kingdom_surface_preview_profile"] = profile.duplicate(true)
	gs.scenario_state ["era_kingdom_surface_preview_profile_life_key"] = current_life_key
	return profile.duplicate(true)
func repair_era_kingdom_surface_realm(realm: Dictionary) -> Dictionary:
	if realm.is_empty():
		return realm

	var repaired_realm: Dictionary = realm.duplicate(true)
	var population_profile_raw: Variant = repaired_realm.get("population_profile", {})
	var population_profile: Dictionary = population_profile_raw if typeof(population_profile_raw) == TYPE_DICTIONARY else {}

	if _era_kingdom_population_profile_needs_repair(population_profile):
		population_profile = _get_or_create_era_kingdom_surface_preview_profile()
	else:
		var profile_population: int = _normalize_era_kingdom_population(
			int(population_profile.get("total_population", repaired_realm.get("population", 0))),
			true
		)
		population_profile ["total_population"] = profile_population
		population_profile ["profile_source"] = "era_kingdom_population_profile_v2"
		population_profile ["population_range_min"] = 10000000000
		population_profile ["population_range_max"] = 25000000000

	var total_population: int = _normalize_era_kingdom_population(
		int(population_profile.get("total_population", repaired_realm.get("population", 0))),
		true
	)
	population_profile ["total_population"] = total_population

	var military_values: Dictionary = _build_era_kingdom_military_values(total_population, population_profile)
	var military_units_value: int = int(military_values.get("military_units", int(round(float(total_population) * 0.08))))
	var military_stockpile_value: int = int(military_values.get("military_stockpile", int(round(float(total_population) * 0.12))))
	var military_display_value: int = int(military_values.get("military", military_stockpile_value))

	military_units_value = clamp(military_units_value, int(round(float(total_population) * 0.08)), int(round(float(total_population) * 0.13)))
	military_stockpile_value = clamp(military_stockpile_value, military_units_value, int(round(float(total_population) * 0.18)))
	military_display_value = clamp(military_display_value, military_units_value, int(round(float(total_population) * 0.18)))

	repaired_realm ["population"] = total_population
	repaired_realm ["population_profile"] = population_profile.duplicate(true)
	repaired_realm ["military_units"] = military_units_value
	repaired_realm ["military_stockpile"] = military_stockpile_value
	repaired_realm ["military"] = military_display_value
	repaired_realm ["goods_stockpile"] = max(int(repaired_realm.get("goods_stockpile", 0)), 0)
	repaired_realm ["treasury"] = max(int(repaired_realm.get("treasury", 0)), 0)

	if str(repaired_realm.get("id", "")).strip_edges() == ERA_KINGDOM_ID:
		hidden_realms [ERA_KINGDOM_ID] = repaired_realm.duplicate(true)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}
		gs.scenario_state ["era_kingdom_surface_preview_profile"] = population_profile.duplicate(true)

	return repaired_realm
func _build_era_kingdom_military_values(total_population: int, population_profile: Dictionary = {}) -> Dictionary:
	var safe_population: int = _normalize_era_kingdom_population(total_population)
	safe_population = clamp(safe_population, 10000000000, 25000000000)

	var military_profile_raw: Variant = population_profile.get("military_profile", {})
	var military_profile: Dictionary = military_profile_raw if typeof(military_profile_raw) == TYPE_DICTIONARY else {}

	var units_ratio: float = clampf(float(military_profile.get("units_ratio", randf_range(0.08, 0.13))), 0.08, 0.13)
	var display_ratio: float = clampf(float(military_profile.get("display_ratio", randf_range(units_ratio, 0.18))), units_ratio, 0.18)

	var minimum_units: int = int(round(float(safe_population) * 0.08))
	var maximum_units: int = int(round(float(safe_population) * 0.13))
	var maximum_display: int = int(round(float(safe_population) * 0.18))

	var military_units_value: int = int(round(float(safe_population) * units_ratio))
	var military_stockpile_value: int = int(round(float(safe_population) * display_ratio))

	military_units_value = clamp(military_units_value, minimum_units, maximum_units)
	military_stockpile_value = clamp(military_stockpile_value, military_units_value, maximum_display)

	return {
		"military_units": military_units_value,
		"military_stockpile": military_stockpile_value,
		"military": military_stockpile_value
	}

func _build_era_kingdom_bender_distribution(total_population: int) -> Dictionary:

	var safe_total: int = max(1, total_population)
	return {
		"air": int(round(float(safe_total) * 0.18)),
		"water": int(round(float(safe_total) * 0.2)),
		"earth": int(round(float(safe_total) * 0.24)),
		"fire": int(round(float(safe_total) * 0.22)),
		"non_bender": int(round(float(safe_total) * 0.16)),
		"dual_element_rare": max(120000, int(round(float(safe_total) * 0.0012))),
		"triple_element_rare": max(12000, int(round(float(safe_total) * 8e-05))),
		"quad_element_mythic": max(240, int(round(float(safe_total) * 2e-06)))
	}

func _build_era_kingdom_trade_rules() -> Dictionary:

	return {
		"accepts_bribes": false,
		"rare_artifacts_only": true,
		"allowed_categories": ["Artifact"],
		"minimum_rarity": "Rare",
		"forbidden_categories": ["cash", "standard_goods", "political_favors"]
	}

func _build_era_kingdom_service_capabilities() -> Dictionary:

	return {
		"war_resolution": {
			"enabled": true,
			"restores_balance_weight": 100
		},
		"massive_loans": {
			"enabled": true,
			"max_loan_value": 500000000000000,
			"default_consequence": "debt_enforcement_pressure"
		},
		"balance_restoration": {
			"enabled": true,
		}
	}

func _build_era_kingdom_faction_matrix(sovereign: Person, founding_houses: Array) -> Array:

	var out: Array = [
		{
			"id": "era_crown",
			"name": "Era Crown",
			"kind": "sovereign_court",
			"leader_id": sovereign.id,
			"standing": 100.0,
			"purpose": "balance_arbitration",
			"represented_population": 0
		},
		{
			"id": "artifact_conclave",
			"name": "Artifact Conclave",
			"kind": "artifact_order",
			"leader_id": sovereign.id,
			"standing": 94.0,
			"purpose": "rare_artifact_trade",
			"represented_population": 0
		},
		{
			"id": "loan_tribunal",
			"name": "Loan Tribunal",
			"kind": "hidden_tribunal",
			"leader_id": sovereign.id,
			"standing": 91.0,
			"purpose": "massive_loans",
			"represented_population": 0
		},
		{
			"id": "balance_ministry",
			"name": "Balance Ministry",
			"kind": "state_ministry",
			"leader_id": sovereign.id,
			"standing": 97.0,
			"purpose": "war_resolution",
			"represented_population": 0
		}
	]
	for raw_house in founding_houses:
		var house_name: String = str(raw_house).strip_edges()
		if house_name == "":
			continue
		out.append({
			"id": "house_%s" % house_name.to_lower().replace(" ", "_"),
			"name": "House %s" % house_name,
			"kind": "ruling_house",
			"leader_id": sovereign.id,
			"standing": 82.0,
			"purpose": "lineage_governance",
			"represented_population": 0
		})
	return out

func can_npc_access_era_kingdom(npc: Person) -> bool:

	if npc == null:
		return false
	return bool(npc.has_many_realms_ring) or int(npc.id) == int(ring_owner_id)

func can_be_born_in_era_kingdom() -> bool:

	return false


func _assign_sovereign(npc: Person):
	var realm = hidden_realms.get(ERA_KINGDOM_ID, {})
	if realm == {}:
		return

	realm = repair_era_kingdom_surface_realm(realm)
	realm ["ruler_id"] = npc.id

	if not realm.has("history") or typeof(realm.get("history", [])) != TYPE_ARRAY:
		realm ["history"] = []

	realm ["history"].append(
		"%d: Sovereignty passed to %s %s." % [gs.year, npc.first_name, npc.last_name]
	)
	hidden_realms [ERA_KINGDOM_ID] = realm


func _generate_ruling_houses(sovereign: Person) -> Array:
	var houses:= []
	houses.append(sovereign.last_name)

	for i in range(4):
		var house_name = gs.names_db.random_last_for_era(gs.era.name)
		if house_name not in houses:
			houses.append(house_name)

	return houses





func yearly_tick(_payload:= {}):
	if gs == null or not gs.is_feature_enabled("many_realms"):
		return

	if not hidden_realms.has(ERA_KINGDOM_ID):
		return

	var realm = hidden_realms [ERA_KINGDOM_ID]
	var ruler = gs.get_npc_by_id(realm.get("ruler_id", -1))

	if ruler == null or not ruler.alive:
		_process_ownerless_instability()
		return

	_simulate_realm_drift(realm, ruler)
	_roll_dynasty_hunts(ruler, realm)
	_roll_rebellion(ruler, realm)

	hidden_realms [ERA_KINGDOM_ID] = realm


func _simulate_realm_drift(realm: Dictionary, ruler: Person):

	var loyalty_shift = randi_range(-6, 6)
	var prosperity_shift = randi_range(-5, 7)
	var stability_shift = randi_range(-5, 5)

	if ruler.smarts >= 75:
		prosperity_shift += 3
		stability_shift += 2

	if ruler.fame >= 50:
		loyalty_shift += 2

	if "Impulsive" in ruler.traits:
		stability_shift -= 4

	if "Kind" in ruler.traits:
		loyalty_shift += 3

	if "Mean" in ruler.traits:
		loyalty_shift -= 4

	realm ["population"] = max(1000, int(realm ["population"]) + randi_range(-4000, 9000))
	realm ["loyalty"] = clamp(int(realm ["loyalty"]) + loyalty_shift, 0, 100)
	realm ["prosperity"] = clamp(int(realm ["prosperity"]) + prosperity_shift, 0, 100)
	realm ["stability"] = clamp(int(realm ["stability"]) + stability_shift, 0, 100)

	if int(realm ["build_budget_infinite"]):

		realm ["prosperity"] = clamp(int(realm ["prosperity"]) + 2, 0, 100)

	if int(realm ["prosperity"]) >= 80 and randi() % 4 == 0:
		var txt = "🏰 The Era Kingdom flourishes under %s %s." % [
			ruler.first_name, ruler.last_name
		]
		gs.push_world_feed(txt, {
			"npc_id": ruler.id,
			"personally_relevant": ruler == gs.player,
			"category": "realm",
			"event_name": ActionEventTypes.MANY_REALMS_BUILD,
			"source": "many_realms_engine"
		})
		realm ["history"].append("%d: %s" % [gs.year, txt])


func _roll_dynasty_hunts(ruler: Person, realm: Dictionary):

	var hunt_chance = 8

	if int(realm ["prosperity"]) > 75:
		hunt_chance += 8
	if int(realm ["population"]) > 140000:
		hunt_chance += 6
	if ruler.fame_tier in ["National", "Global", "Legend"]:
		hunt_chance += 8

	if randi() % 100 >= hunt_chance:
		return

	var rival_dynasty = _pick_rival_dynasty(ruler.last_name)
	if rival_dynasty == "":
		return

	var txt = "🗡️ Rumors spread that the %s dynasty is hunting the Ring of Many Realms." % rival_dynasty

	gs.push_world_feed(txt, {
		"npc_id": ruler.id,
		"personally_relevant": ruler == gs.player,
		"category": "dynasty",
		"event_name": ActionEventTypes.MANY_REALMS_HUNT,
		"source": "many_realms_engine"
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.MANY_REALMS_HUNT, {
			"npc_id": ruler.id,
			"text": txt,
			"rival_dynasty": rival_dynasty
		})

	gs.dynasty_legacy_engine.dynasty_grudges [
		"%s->%s" % [ruler.last_name, rival_dynasty]
	] = gs.dynasty_legacy_engine.dynasty_grudges.get(
		"%s->%s" % [ruler.last_name, rival_dynasty], 0
	) + 8


func _pick_rival_dynasty(excluded: String) -> String:
	var options:= []
	for d in gs.dynasty_engine.dynasties.keys():
		if d != excluded:
			options.append(d)

	if options.size() == 0:
		return ""

	return options [randi() % options.size()]


func _roll_rebellion(ruler: Person, realm: Dictionary):

	var rebellion_risk = 0

	if int(realm ["loyalty"]) < 35:
		rebellion_risk += 20
	if int(realm ["stability"]) < 35:
		rebellion_risk += 20
	if int(realm ["prosperity"]) < 30:
		rebellion_risk += 12
	if "Impulsive" in ruler.traits:
		rebellion_risk += 8

	rebellion_risk = clamp(rebellion_risk, 0, 80)

	if randi() % 100 >= rebellion_risk:
		return

	realm ["rebel_pressure"] = int(realm ["rebel_pressure"]) + randi_range(10, 25)

	var txt = "🔥 Rebellion stirs in the hidden Era Kingdom against %s %s." % [
		ruler.first_name, ruler.last_name
	]

	gs.push_world_feed(txt, {
		"npc_id": ruler.id,
		"personally_relevant": ruler == gs.player,
		"category": "realm",
		"event_name": ActionEventTypes.MANY_REALMS_REBELLION,
		"source": "many_realms_engine"
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.MANY_REALMS_REBELLION, {
			"npc_id": ruler.id,
			"text": txt
		})

	realm ["history"].append("%d: %s" % [gs.year, txt])


func _process_ownerless_instability():

	var realm = hidden_realms.get(ERA_KINGDOM_ID, {})
	if realm == {}:
		return

	realm ["stability"] = clamp(int(realm ["stability"]) - 12, 0, 100)
	realm ["loyalty"] = clamp(int(realm ["loyalty"]) - 10, 0, 100)
	realm ["rebel_pressure"] = int(realm ["rebel_pressure"]) + 15

	hidden_realms [ERA_KINGDOM_ID] = realm





func handle_inheritance(payload: Dictionary):
	if gs == null or not gs.is_feature_enabled("many_realms"):
		return
	var dead_id = int(payload.get("npc_id", -1))
	if gs.should_skip_manual_player_inheritance(dead_id):
		return
	if dead_id != ring_owner_id:
		return
	var dead_facts = gs.get_npc_facts_by_id(dead_id)
	if dead_facts == {}:
		return
	var dead = gs.get_npc_by_id(dead_id)
	if dead != null:
		dead.has_many_realms_ring = false
		dead.hidden_realm_visible = false
		dead.hidden_realm_title = ""
	var heir = gs.get_random_living_person_from_ids(dead_facts.get("children", []))
	if heir == null:
		ring_owner_id = -1
		return
	give_ring(heir)

	var txt = "👑 Sovereignty over the Era Kingdom passed to %s %s." % [
		heir.first_name, heir.last_name
	]

	gs.push_world_feed(txt, {
		"npc_id": heir.id,
		"personally_relevant": heir == gs.player,
		"category": "realm",
		"event_name": ActionEventTypes.MANY_REALMS_SUCCESSION,
		"source": "many_realms_engine"
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.MANY_REALMS_SUCCESSION, {
			"npc_id": heir.id,
			"text": txt
		})


func resolve_era_kingdom_bribe_attempt(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
		or not actor.alive
	):
		return {
			"success": false,
			"committed": false,
			"popup_title": "Bribe Failed",
			"popup_text": (
				"No valid ruler could make the attempt."
			)
		}

	var amount: int = maxi(
		1,
		int(
			payload.get(
				"amount",
				150000
			)
		)
	)

	if int(
		actor.bank_balance
	) < amount:
		return {
			"success": false,
			"committed": false,
			"popup_title": "Not Enough Money",
			"popup_text": (
				"You do not have enough money to attempt that bribe."
			)
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var warning_count: int = int(
		gs.scenario_state.get(
			"era_kingdom_bribe_warning_count",
			0
		)
	)
	var world_seed: int = int(
		gs.scenario_state.get(
			"world_seed",
			-1
		)
	)
	var response_roll: int = abs(
		hash(
			"%d:%d:%d:%d:era_kingdom_bribe"
			% [
				world_seed,
				int(
					gs.year
				),
				int(
					actor.id
				),
				warning_count
			]
		)
	) % 100

	actor.bank_balance = int(
		actor.bank_balance
	) - amount
	actor.scandal = clampi(
		int(
			actor.scandal
		) + 6,
		0,
		100
	)
	actor.approval = clampi(
		int(
			actor.approval
		) - 4,
		0,
		100
	)

	var war_threshold: int = (
		82
		if warning_count > 0
		else 36
	)
	var declares_war: bool = (
		response_roll < war_threshold
	)

	if declares_war:
		if (
			gs.war_contract_engine == null
			or int(
				actor.realm_id
			) <= 0
		):
			return {
				"success": true,
				"committed": true,
				"popup_title": (
					"THE ERA KINGDOM IS FURIOUS"
				),
				"popup_text": (
					"The Era Kingdom rejected your bribe and issued an immediate sovereign threat."
				),
				"amount_spent": amount
			}

		var queued_war_report: Dictionary = (
			gs.war_contract_engine
			.queue_war_declaration_contract(
				{
					"attacker_realm_id": (
						WarContractEngine
						.ERA_KINGDOM_WAR_REALM_ID
					),
					"defender_realm_id": int(
						actor.realm_id
					),
					"year": int(
						gs.year
					),
					"casus_belli": (
						"sovereign_retaliation_for_bribery"
					),
					"declaration_source": (
						"era_kingdom_retaliation"
					),
					"attacker_realm_key": (
						"era_kingdom"
					),
					"attacker_name": (
						"Era Kingdom"
					)
				}
			)
		)

		return {
			"success": true,
			"committed": true,
			"mode": (
				"era_kingdom_declared_war"
			),
			"popup_title": (
				"THE ERA KINGDOM DECLARES WAR"
			),
			"popup_text": (
				"The Era Kingdom did not laugh. "
				+ "It answered your bribe attempt with WAR."
			),
			"war_declaration_queue_report": (
				queued_war_report
			),
			"war_declaration_pending": bool(
				queued_war_report.get(
					"queued",
					false
				)
			),
			"dynamic_war_tab_required": false,
			"amount_spent": amount,
		}

	gs.scenario_state [
		"era_kingdom_bribe_warning_count"
	] = warning_count + 1
	gs.scenario_state [
		"era_kingdom_last_bribe_warning_year"
	] = int(
		gs.year
	)

	return {
		"success": true,
		"committed": true,
		"mode": "era_kingdom_laughed_off_bribe",
		"popup_title": (
			"THE ERA KINGDOM LAUGHS"
		),
		"popup_text": (
			"The Era Kingdom laughed off your bribe attempt.\n\n"
			+ "\"Do not ever try that again.\""
		),
		"amount_spent": amount,
		"warning_count": warning_count + 1
	}


func get_player_hidden_realm() -> Dictionary:
	if gs.player == null:
		return {}

	if not gs.player.has_many_realms_ring:
		return {}

	return hidden_realms.get(ERA_KINGDOM_ID, {})


func build_in_era_kingdom(project_name: String, prosperity_gain:= 5, loyalty_gain:= 2) -> Dictionary:
	if gs.player == null or not gs.player.has_many_realms_ring:
		return { "success": false, "text": "❌ I do not possess the Ring of Many Realms."}

	if not hidden_realms.has(ERA_KINGDOM_ID):
		return { "success": false, "text": "❌ The Era Kingdom is not initialized."}

	var realm = hidden_realms [ERA_KINGDOM_ID]
	realm ["prosperity"] = clamp(int(realm ["prosperity"]) + prosperity_gain, 0, 100)
	realm ["loyalty"] = clamp(int(realm ["loyalty"]) + loyalty_gain, 0, 100)
	realm ["history"].append("%d: Built %s." % [gs.year, project_name])
	hidden_realms [ERA_KINGDOM_ID] = realm

	var txt = "🏗️ I used the Ring's treasury to build %s in the Era Kingdom." % project_name

	gs.narrative_engine.log_event(gs.player, {
		"type": "text",
		"text": txt
	})

	gs.push_world_feed(txt, {
		"npc_id": gs.player.id,
		"personally_relevant": true,
		"category": "realm",
		"event_name": ActionEventTypes.MANY_REALMS_BUILD,
		"source": "many_realms_engine"
	})

	return { "success": true, "text": txt}