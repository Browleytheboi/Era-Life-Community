

extends RefCounted
class_name CavemanRealityRuntimeEngine

const ENGINE_SCHEMA:= "eralife.caveman_reality_runtime_engine"
const ENGINE_VERSION:= 1
const STATE_SCHEMA:= "eralife.caveman_reality_runtime_engine.state"
const STATE_KEY:= "caveman_reality_runtime_state"
const BUNDLE_ID:= "eralife.caveman_reality_pack"
const ROOT_MOD_ID:= "eralife.caveman_pack"
const EXPERIENCE_ID:= "eralife.experience.caveman_survival"
const MENU_SECTION_IDS:= [
	"roles",
	"survival",
	"resources",
	"tribe",
	"settings"
]
const RESOURCE_ORDER:= [
	"elk_meat",
	"rabbit_meat",
	"bush_berries",
	"wild_roots",
	"marrow",
	"smoked_meat",
	"wood",
	"stone",
	"hide",
	"bone",
	"fire"
]
const ACTIVITY_IDS:= [
	"listen_to_fire",
	"reach_for_family",
	"crawl_across_hides",
	"babble_at_tribe",
	"nap_by_fire",
	"play_with_smooth_stone",
	"snuggle_parent",
	"listen_to_grandparent_story",
	"follow_gatherer",
	"gather_kindling",
	"learn_animal_tracks",
	"gather_roots_berries",
	"craft_stone_tools",
	"start_fire",
	"explore_territory",
	"hunt_herd",
	"share_food_with_tribe",
	"make_wild_cave_love",
	"try_for_cave_baby"
]
const TRIBE_NAME_PREFIXES:= [
	"Ash",
	"Ember",
	"Mammoth",
	"Stone",
	"River",
	"Moon",
	"Thunder",
	"Red",
	"Deep",
	"Flint"
]
const TRIBE_NAME_SUFFIXES:= [
	"Tusk",
	"Claw",
	"Hide",
	"Flame",
	"Horn",
	"Track",
	"Jaw",
	"Echo",
	"Root",
	"Fang"
]
const CAVE_NAME_PREFIXES:= [
	"Ember",
	"Mammoth",
	"Moon",
	"Flint",
	"Red",
	"Deep",
	"Echo",
	"Bear",
	"River",
	"Smoke"
]
const CAVE_NAME_SUFFIXES:= [
	"Mouth",
	"Hollow",
	"Rest",
	"Den",
	"Vault",
	"Shelter",
	"Passage",
	"Chamber",
	"Cleft",
	"Cavern"
]

const DEFAULT_SETTINGS:= {
	"survival_intensity": 3,
	"megafauna_frequency": "Balanced",
	"unlock_survival_all_ages": false
}
const MAX_ACTIVITY_HISTORY:= 240
const MAX_TRIBE_HISTORY:= 120

var gs
var state: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs
	_ensure_state_shape()


func bootstrap_default_contracts() -> Dictionary:
	if state.is_empty():
		state = _default_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"bundle_id": BUNDLE_ID,
		"experience_id": EXPERIENCE_ID,
		"enabled": bool(
			state.get(
				"enabled",
				false
			)
		),
		"repair_report": {
			"success": true,
			"mode": "no_bootstrap_repair",
		},
		"identity_safe": true,
		"explicit_migration_authority": "repair_state",
		"ui_is_renderer_only": true
	}

func set_bundle_enabled(
		enabled: bool,
		context: Dictionary = {}
) -> Dictionary:
	if state.is_empty():
		state = _default_state()

	var selected: Array = _normalize_component_ids(
		_array(
			context.get(
				"component_ids",
				state.get(
					"selected_component_ids",
					[]
				)
			)
		)
	)

	if enabled and selected.is_empty():
		selected = _normalize_component_ids(
			CavemanRealityBundlePack.component_order()
		)

	if not selected.is_empty():
		state ["selected_component_ids"] = (
			selected.duplicate(false)
		)

	state ["enabled"] = enabled
	state ["active_component_ids"] = (
		selected.duplicate(false)
		if enabled
		else []
	)
	state [
		"last_enabled_at_ms"
		if enabled
		else "last_disabled_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	state ["last_transition_source"] = str(
		context.get(
			"source",
			"set_bundle_enabled"
		)
	)
	state ["transition_revision"] = int(
		state.get(
			"transition_revision",
			0
		)
	) + 1

	var controlled_profile: Dictionary = {}
	var surface_contract: Dictionary = {}

	if gs != null and gs.player != null:
		controlled_profile = (
			_actor_profile_observation(
				gs.player
			)
		)
		surface_contract = (
			emit_reality_surface_contract(
				gs.player,
				{
					"source": "set_bundle_enabled",
					"enabled": enabled,
					"prefer_cached_surface": true,
					"simulation_mutation_forbidden": true
				}
			)
		)

	_emit_runtime_event(
		"mod_bundle.caveman.runtime_toggled",
		{
			"enabled": enabled,
			"active_component_ids": _array(
				state.get(
					"active_component_ids",
					[]
				)
			),
			"surface_revision": str(
				surface_contract.get(
					"surface_revision",
					""
				)
			),
		}
	)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": (
			"caveman_runtime_enabled"
			if enabled
			else "caveman_runtime_disabled"
		),
		"bundle_id": BUNDLE_ID,
		"enabled": enabled,
		"active_component_ids": _array(
			state.get(
				"active_component_ids",
				[]
			)
		),
		"controlled_profile": controlled_profile,
		"family_report": {
			"success": true,
		},
		"role_report": {
			"success": true,
		},
		"repair_report": {
			"success": true,
		},
		"reality_surface_contract": surface_contract,
		"resident_surface_reused": bool(
			surface_contract.get(
				"resident_surface_cache_hit",
				false
			)
		),
		"runtime_state_preserved": true,
		"loading_screen_required": false,
		"text": (
			"Caveman survival reality is now active."
			if enabled
			else (
				"Caveman runtime is dormant. "
				+ "Its tribal history remains preserved."
			)
		),
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)
func _actor_profile_observation(
		actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var actor_key: String = str(
		int(actor.id)
	)
	var profiles_raw: Variant = state.get(
		"actor_profiles",
		{}
	)

	if typeof(profiles_raw) == TYPE_DICTIONARY:
		var profile_raw: Variant = (
			(profiles_raw as Dictionary).get(
				actor_key,
				{}
			)
		)

		if (
			typeof(profile_raw) == TYPE_DICTIONARY
			and not (profile_raw as Dictionary).is_empty()
		):
			return (
				(profile_raw as Dictionary).duplicate(true)
			)



	var tribe_id: String = _tribe_id_for_actor(
		actor
	)
	var default_role_id: String = (
		_default_role_for_actor(actor)
	)
	var role_ids: Array = [
		default_role_id
	]

	if _birth_giver_is_eligible(actor):
		role_ids.append(
			"birth_giver"
		)

	return {
		"actor_id": int(actor.id),
		"actor_name": _actor_name(actor),
		"tribe_id": tribe_id,
		"primary_role_id": default_role_id,
		"role_ids": role_ids,
		"survival_contribution": 0,
		"activity_counts": {},
		"role_history": [],
		"last_active_year": _current_year(),
		"projection_only_cold_fallback": true
	}


func _tribe_observation_for_actor(
		actor: Person,
		profile: Dictionary
) -> Dictionary:
	if actor == null:
		return {}

	var tribe_id: String = str(
		profile.get(
			"tribe_id",
			""
		)
	).strip_edges()

	if tribe_id == "":
		tribe_id = _tribe_id_for_actor(
			actor
		)

	var tribes_raw: Variant = state.get(
		"tribes",
		{}
	)

	if typeof(tribes_raw) == TYPE_DICTIONARY:
		var tribe_raw: Variant = (
			(tribes_raw as Dictionary).get(
				tribe_id,
				{}
			)
		)

		if (
			typeof(tribe_raw) == TYPE_DICTIONARY
			and not (tribe_raw as Dictionary).is_empty()
		):
			return (
				(tribe_raw as Dictionary).duplicate(true)
			)




	var tribe: Dictionary = _default_tribe(
		tribe_id,
		_tribe_name_for_actor(actor)
	)
	tribe ["territory_name"] = (
		_territory_name_for_actor(actor)
	)
	tribe ["cave_name"] = (
		_cave_name_for_actor(actor)
	)
	tribe ["member_ids"] = [
		int(actor.id)
	]
	tribe ["projection_only_cold_fallback"] = true

	return tribe
func _compose_reality_surface_contract(
		actor: Person,
		profile: Dictionary,
		tribe: Dictionary,
		family_report: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
	var settings: Dictionary = _normalized_settings(
		_dict(
			state.get(
				"settings",
				DEFAULT_SETTINGS
			)
		)
	)
	var base_contract: Dictionary = (
		_base_bundle_menu_contract()
	)
	var presentation: Dictionary = _dict(
		base_contract.get(
			"presentation",
			{}
		)
	)
	var cave_name: String = str(
		tribe.get(
			"cave_name",
			tribe.get(
				"territory_name",
				"Unresolved Cave"
			)
		)
	)
	var tribe_name: String = str(
		tribe.get(
			"name",
			"Unresolved Tribe"
		)
	)
	var activity_categories: Array = (
		_activity_category_rows(
			actor,
			profile,
			tribe,
			settings
		)
	)
	var birth_projection: Dictionary = (
		_birth_intro_projection(
			actor,
			profile,
			tribe
		)
	)
	var world_entries: Array = (
		_world_browser_tribe_entries(
			actor,
			tribe
		)
	)
	var year_label: String = (
		_caveman_display_year_label(
			tribe
		)
	)

	return {
		"success": true,
		"schema": "eralife.reality_surface_contract",
		"version": 1,
		"bundle_id": BUNDLE_ID,
		"experience_id": EXPERIENCE_ID,
		"enabled": true,
		"actor_id": int(actor.id),
		"presentation": presentation,
		"effective_era": {
			"id": "caveman_survival_overlay",
			"name": "Caveman Era",
			"display_name": "Caveman Era",
			"theme_key": "prehistoric",
			"career_mode": "roles_only",
			"economy_mode": "resource_survival",
		},
		"world_taxonomy": {
			"world": "TRIBES",
			"other_countries": "OTHER TRIBES",
			"other_realms": "OTHER CLANS",
			"country": "TRIBE",
			"city": "CAVE",
			"property": "CAVE SHELTER",
			"career": "ROLES",
			"money": "RESOURCES"
		},
		"display_calendar": {
			"mode": "tribal_fire_count",
			"year_label": year_label,
			"apply_to_all_visible_years": true,
			"chronological_year": (
				int(gs.year)
				if gs != null
				else 0
			),
		},
		"location_projection": {
			"label": cave_name,
			"cave_name": cave_name,
			"tribe_name": tribe_name,
			"subtitle": (
				"%s • Caveman Era"
				% cave_name
			),
			"base_birth_city_preserved": str(
				actor.birth_city
			),
			"base_birth_country_preserved": str(
				actor.birth_country
			)
		},
		"birth_intro_projection": birth_projection,
		"activities_contract": {
			"replace_base_catalog": true,
			"title": "    SURVIVAL HUB",
			"subtitle": (
				"%s • Caveman Era"
				% cave_name
			),
			"identity_overview": {
				"actor_id": int(actor.id),
				"name": _actor_name(actor),
				"age": int(actor.age),
				"era_name": "Caveman Era",
				"year_label": year_label,
				"location": cave_name,
				"tribe_name": tribe_name,
				"role_label": _profile_role_label(
					profile
				),
				"ui_is_renderer_only": true
			},
			"category_rows": activity_categories,
			"surface_revision": (
				"caveman_activities:%d:%d"
				% [
					int(actor.id),
					int(
						state.get(
							"revision",
							0
						)
					)
				]
			)
		},
		"replace_base_activity_catalog": true,
		"world_browser_entries": world_entries,
		"property_projection": {
			"mode": "cave_shelter_projection",
			"default_label": "Family Cave",
			"cave_name": cave_name,
			"types": [
				"Fire Cave",
				"Deep Shelter Cave",
				"Mammoth-Bone Cave",
				"River Cleft Cave",
				"Stone-Tool Cave"
			]
		},
		"family_report": family_report,
		"tribe_id": str(
			tribe.get(
				"tribe_id",
				""
			)
		),
		"tribe_name": tribe_name,
		"cave_name": cave_name,
		"settings": settings,
		"surface_revision": (
			"caveman_surface:%d:%d:%d"
			% [
				int(actor.id),
				int(
					state.get(
						"revision",
						0
					)
				),
				int(
					state.get(
						"transition_revision",
						0
					)
				)
			]
		),
		"simulation_mutation_performed": false,
		"loading_screen_required": false,
		"source": str(
			context.get(
				"source",
				"compose_reality_surface_contract"
			)
		),
		"ui_is_renderer_only": true
	}
func emit_reality_surface_contract(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Caveman reality observer could be resolved."
		)

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return {
			"success": true,
			"schema": "eralife.reality_surface_contract",
			"version": 1,
			"bundle_id": BUNDLE_ID,
			"enabled": false,
			"actor_id": int(actor.id),
			"presentation": {},
			"replace_base_activity_catalog": false,
			"surface_revision": (
				"caveman:dormant:%d"
				% int(actor.id)
			),
			"simulation_mutation_performed": false,
			"ui_is_renderer_only": true
		}

	var actor_key: String = str(
		int(actor.id)
	)
	var content_revision: int = int(
		state.get(
			"revision",
			0
		)
	)



	var surface_cache_raw: Variant = state.get(
		"reality_surface_cache",
		{}
	)

	if typeof(surface_cache_raw) == TYPE_DICTIONARY:
		var cached_row_raw: Variant = (
			(surface_cache_raw as Dictionary).get(
				actor_key,
				{}
			)
		)

		if typeof(cached_row_raw) == TYPE_DICTIONARY:
			var cached_row: Dictionary = (
				cached_row_raw as Dictionary
			)

			if (
				bool(
					context.get(
						"prefer_cached_surface",
						true
					)
				)
				and int(
					cached_row.get(
						"content_revision",
						-1
					)
				) == content_revision
			):
				var cached_contract_raw: Variant = (
					cached_row.get(
						"contract",
						{}
					)
				)

				if (
					typeof(cached_contract_raw)
					== TYPE_DICTIONARY
					and not (
						cached_contract_raw as Dictionary
					).is_empty()
				):
					var cached_contract: Dictionary = (
						(cached_contract_raw as Dictionary)
						.duplicate(true)
					)
					cached_contract ["enabled"] = true
					cached_contract [
						"transition_revision"
					] = int(
						state.get(
							"transition_revision",
							0
						)
					)
					cached_contract [
						"resident_surface_cache_hit"
					] = true
					cached_contract [
						"simulation_mutation_performed"
					] = false
					cached_contract [
						"loading_screen_required"
					] = false
					return cached_contract




	var profile: Dictionary = (
		_actor_profile_observation(
			actor
		)
	)
	var tribe: Dictionary = (
		_tribe_observation_for_actor(
			actor,
			profile
		)
	)
	var member_ids: Array = _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	)
	var family_report: Dictionary = {
		"success": true,
		"schema": "eralife.caveman_family_tribe_observation",
		"version": 1,
		"tribe_id": str(
			tribe.get(
				"tribe_id",
				""
			)
		),
		"tribe_name": str(
			tribe.get(
				"name",
				"Unresolved Tribe"
			)
		),
		"cave_name": str(
			tribe.get(
				"cave_name",
				"Unresolved Cave"
			)
		),
		"member_ids": member_ids,
		"member_count": member_ids.size(),
		"population_scan_performed": false,
		"ui_is_renderer_only": true
	}

	var contract: Dictionary = (
		_compose_reality_surface_contract(
			actor,
			profile,
			tribe,
			family_report,
			context
		)
	)

	contract ["resident_surface_cache_hit"] = false
	contract ["projection_only_cold_fallback"] = true
	contract ["simulation_mutation_performed"] = false

	return contract
func _caveman_activity_contract(
	activity_id: String
) -> Dictionary:
	var clean_activity_id: String = _slug(
		activity_id
	)

	if clean_activity_id == "":
		return {}

	for raw_contract in CavemanRealityBundlePack.caveman_activity_contracts():
		var contract: Dictionary = _dict(
			raw_contract
		)

		if _slug(
			str(
				contract.get(
					"id",
					""
				)
			)
		) == clean_activity_id:
			return contract

	return {}
func perform_activity(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Caveman activity actor could be resolved."
		)

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return _failure(
			"bundle_disabled",
			"The Caveman Reality Pack is not active."
		)

	if not _component_active(
		"activities"
	):
		return _failure(
			"activities_component_disabled",
			"Caveman activities are not installed."
		)

	var activity_id: String = _activity_id_from_payload(
		payload
	)
	var activity_contract: Dictionary = _caveman_activity_contract(
		activity_id
	)

	if activity_contract.is_empty():
		return _failure(
			"unknown_caveman_activity",
			"That Caveman activity is not registered."
		)

	var profile: Dictionary = _ensure_actor_profile(
		actor,
		{
			"source": "perform_activity"
		}
	)
	var tribe_id: String = str(
		profile.get(
			"tribe_id",
			""
		)
	)
	var tribe: Dictionary = _tribe(
		tribe_id
	)

	if tribe.is_empty():
		return _failure(
			"missing_tribe",
			"The actor's tribe could not be resolved."
		)

	var eligibility: Dictionary = _activity_eligibility(
		activity_id,
		actor,
		profile,
		tribe
	)

	if not bool(
		eligibility.get(
			"eligible",
			false
		)
	):
		return _failure(
			str(
				eligibility.get(
					"reason",
					"activity_locked"
				)
			),
			str(
				eligibility.get(
					"text",
					"That activity is currently locked."
				)
			)
		)

	match activity_id:
		"toggle_survival_age_unlock":
			var settings: Dictionary = _normalized_settings(
				_dict(
					state.get(
						"settings",
						DEFAULT_SETTINGS
					)
				)
			)
			settings ["unlock_survival_all_ages"] = bool(
				payload.get(
					"value",
					not bool(
						settings.get(
							"unlock_survival_all_ages",
							false
						)
					)
				)
			)
			state ["settings"] = settings
			_bump_revision()
			_publish_state()

			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"type": "caveman_survival_age_policy_changed",
				"bundle_id": BUNDLE_ID,
				"enabled": bool(
					settings [
						"unlock_survival_all_ages"
					]
				),
				"text": (
					"Survival activities are now unlocked for every age."
						if bool(
							settings [
								"unlock_survival_all_ages"
							]
						)
						else "Original survival age gates were restored."
				),
				"ui_is_renderer_only": true
			}

		"give_resource_item":
			return _give_resource_item_to_actor(
				actor,
				profile,
				tribe,
				payload
			)

		"make_wild_cave_love":
			return _perform_wild_cave_love(
				actor,
				profile,
				tribe,
				false
			)

		"try_for_cave_baby":
			return _perform_wild_cave_love(
				actor,
				profile,
				tribe,
				true
			)

		"share_food_with_tribe":
			return _share_resource_with_tribe(
				actor,
				tribe,
				payload
			)

	var activity_counts: Dictionary = _dict(
		profile.get(
			"activity_counts",
			{}
		)
	)
	var sequence: int = int(
		activity_counts.get(
			activity_id,
			0
		)
	)
	var rng:= RandomNumberGenerator.new()
	rng.seed = int(
		hash(
			"%s:%d:%d:%d" % [
				activity_id,
				int(
					actor.id
				),
				_current_year(),
				sequence
			]
		)
	)
	var resolution: Dictionary = _resolve_activity(
		activity_id,
		actor,
		tribe,
		rng
	)

	if not bool(
		resolution.get(
			"success",
			false
		)
	):
		return resolution

	var resource_deltas: Dictionary = _dict(
		resolution.get(
			"resource_deltas",
			{}
		)
	)
	var contribution_delta: int = int(
		resolution.get(
			"contribution_delta",
			0
		)
	)

	_apply_resource_deltas(
		tribe,
		resource_deltas
	)
	activity_counts [activity_id] = sequence + 1
	profile ["activity_counts"] = activity_counts
	profile ["survival_contribution"] = maxi(
		0,
		int(
			profile.get(
				"survival_contribution",
				0
			)
		) + contribution_delta
	)
	profile ["last_activity_id"] = activity_id
	profile ["last_activity_at_ms"] = int(
		Time.get_ticks_msec()
	)
	profile ["last_active_year"] = _current_year()

	var actor_key: String = str(
		int(
			actor.id
		)
	)
	var contribution_by_actor: Dictionary = _dict(
		tribe.get(
			"contribution_by_actor",
			{}
		)
	)
	contribution_by_actor [actor_key] = maxi(
		0,
		int(
			contribution_by_actor.get(
				actor_key,
				0
			)
		) + contribution_delta
	)
	tribe ["contribution_by_actor"] = contribution_by_actor
	tribe ["last_activity_id"] = activity_id
	tribe ["last_activity_actor_id"] = int(
		actor.id
	)
	tribe ["last_activity_year"] = _current_year()

	if activity_id == "craft_stone_tools":
		tribe ["tool_count"] = int(
			tribe.get(
				"tool_count",
				0
			)
		) + int(
			resolution.get(
				"tool_count_delta",
				1
			)
		)

	if activity_id == "explore_territory":
		var discovered: Array = _array(
			tribe.get(
				"discovered_territories",
				[]
			)
		)
		var territory_id: String = str(
			resolution.get(
				"territory_id",
				""
			)
		)

		if (
			territory_id != ""
				and territory_id not in discovered
		):
			discovered.append(
				territory_id
			)

		tribe ["discovered_territories"] = discovered

	_recalculate_tribe_metrics(
		tribe
	)
	_store_profile(
		profile
	)
	_store_tribe(
		tribe
	)

	var history_row: Dictionary = {
		"type": "caveman_activity_resolved",
		"activity_id": activity_id,
		"actor_id": int(
			actor.id
		),
		"actor_name": _actor_name(
			actor
		),
		"tribe_id": tribe_id,
		"year": _current_year(),
		"resource_deltas": resource_deltas,
		"contribution_delta": contribution_delta,
		"text": str(
			resolution.get(
				"text",
				"The survival activity was completed."
			)
		),
		"resolved_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_append_activity_history(
		history_row
	)
	_append_tribe_history(
		tribe_id,
		history_row
	)
	_bump_revision()
	_publish_state()
	_emit_runtime_event(
		"mod_bundle.caveman.activity_resolved",
		history_row
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "caveman_activity_resolved",
		"bundle_id": BUNDLE_ID,
		"activity_id": activity_id,
		"actor_id": int(
			actor.id
		),
		"tribe_id": tribe_id,
		"resource_deltas": resource_deltas,
		"contribution_delta": contribution_delta,
		"survival_contribution": int(
			profile.get(
				"survival_contribution",
				0
			)
		),
		"text": str(
			resolution.get(
				"text",
				"The survival activity was completed."
			)
		),
		"log_to_diary": true,
		"ui_is_renderer_only": true
	}
func _activity_eligibility(
	activity_id: String,
	actor: Person,
	_profile: Dictionary,
	_tribe_context: Dictionary
) -> Dictionary:
	var contract: Dictionary = {}

	for raw_contract in CavemanRealityBundlePack.caveman_activity_contracts():
		var candidate: Dictionary = _dict(raw_contract)

		if str(candidate.get("id", "")) == activity_id:
			contract = candidate
			break

	if contract.is_empty():
		return {
			"eligible": false,
			"reason": "activity_contract_missing",
			"text": "The Caveman activity contract is missing."
		}

	var minimum_age: int = int(
		_dict(contract.get("eligibility", {})).get("minimum_age", 0)
	)
	var maximum_age: int = int(
		_dict(contract.get("eligibility", {})).get("maximum_age", 130)
	)
	var settings: Dictionary = _normalized_settings(
		_dict(state.get("settings", DEFAULT_SETTINGS))
	)
	var age_gate_overridden: bool = (
		bool(settings.get("unlock_survival_all_ages", false))
		and bool(contract.get("survival_age_gate", false))
	)

	if (
		not age_gate_overridden
		and (
			int(actor.age) < minimum_age
			or int(actor.age) > maximum_age
		)
	):
		return {
			"eligible": false,
			"reason": "actor_age_outside_activity_contract",
			"text": (
				"This cave activity is available from age %d to %d."
				% [minimum_age, maximum_age]
			)
		}

	if bool(contract.get("requires_current_partner", false)):
		var partner: Person = (
			gs.get_valid_partner(actor, true, true)
			if gs != null
			else null
		)

		if partner == null:
			return {
				"eligible": false,
				"reason": "current_partner_required",
				"text": "This option only appears for current partners."
			}

		if (
			bool(contract.get("adult_partner_only", false))
			and (
				int(actor.age) < 18
				or int(partner.age) < 18
			)
		):
			return {
				"eligible": false,
				"reason": "adult_partners_required",
				"text": "Both partners must be adults."
			}

	return {
		"eligible": true,
		"reason": "",
		"text": "",
		"age_gate_overridden": age_gate_overridden
	}


func _perform_wild_cave_love(
	actor: Person,
	profile: Dictionary,
	tribe: Dictionary,
	try_for_child: bool
) -> Dictionary:
	if gs == null:
		return _failure("missing_game_state", "GameState is unavailable.")

	var partner: Person = gs.get_valid_partner(actor, true, true)

	if partner == null:
		return _failure(
			"current_partner_required",
			"Wild cave love is only available to current partners."
		)

	if int(actor.age) < 18 or int(partner.age) < 18:
		return _failure(
			"adult_partners_required",
			"Both partners must be adults."
		)

	if not try_for_child:
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"type": "wild_cave_love_resolved",
			"bundle_id": BUNDLE_ID,
			"actor_id": int(actor.id),
			"partner_id": int(partner.id),
			"text": "%s and %s disappeared deeper into %s for a private moment." % [
				_actor_name(actor),
				_actor_name(partner),
				str(tribe.get("cave_name", "the cave"))
			],
			"log_to_diary": true,
			"ui_is_renderer_only": true
		}

	if not gs.can_create_child(actor, partner, true):
		return _failure(
			"cave_baby_contract_not_satisfied",
			"The partners cannot create a child right now."
		)

	var child: Person = gs.spawn_child(actor, partner, true)

	if child == null:
		return _failure(
			"cave_baby_creation_failed",
			"No cave baby could be created."
		)

	var child_profile: Dictionary = _ensure_actor_profile(
		child,
		{
			"source": "cave_baby_created"
		}
	)
	child_profile ["tribe_id"] = str(profile.get("tribe_id", ""))
	child_profile ["primary_role_id"] = "infant"
	child_profile ["role_ids"] = ["infant"]
	_store_profile(child_profile)

	var member_ids: Array = _int_array(tribe.get("member_ids", []))

	if int(child.id) not in member_ids:
		member_ids.append(int(child.id))

	tribe ["member_ids"] = member_ids
	_store_tribe(tribe)
	_bump_revision()
	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "cave_baby_created",
		"bundle_id": BUNDLE_ID,
		"actor_id": int(actor.id),
		"partner_id": int(partner.id),
		"child_id": int(child.id),
		"text": "%s and %s welcomed a cave baby into %s." % [
			_actor_name(actor),
			_actor_name(partner),
			str(tribe.get("name", "the tribe"))
		],
		"log_to_diary": true,
		"ui_is_renderer_only": true
	}


func _give_resource_item_to_actor(
	actor: Person,
	_profile: Dictionary,
	tribe: Dictionary,
	payload: Dictionary
) -> Dictionary:
	if gs == null or gs.belongings_engine == null:
		return _failure(
			"belongings_engine_unavailable",
			"The inventory authority is unavailable."
		)

	var resource_id: String = _slug(
		str(
			payload.get(
				"resource_id",
				""
			)
		)
	)
	var amount: int = maxi(
		1,
		int(
			payload.get(
				"amount",
				1
			)
		)
	)
	var resource: Dictionary = _resource_contract(
		resource_id
	)

	if resource.is_empty():
		return _failure(
			"unknown_caveman_resource",
			"That Caveman resource is not registered."
		)

	var resources: Dictionary = _dict(
		tribe.get(
			"resources",
			{}
		)
	)
	var available: int = int(
		resources.get(
			resource_id,
			0
		)
	)

	if available < amount:
		return _failure(
			"insufficient_tribe_resource",
			"The tribe does not have enough of that resource."
		)

	var category: String = (
		"Food"
			if bool(
				resource.get(
					"is_food",
					false
				)
			)
			else "Resources"
	)
	var item: Dictionary = _resource_inventory_item(
		resource_id,
		resource,
		actor,
		tribe,
		amount
	)
	var item_id: int = int(
		item.get(
			"id",
			-1
		)
	)



	gs.belongings_engine.add_item(
		actor,
		item,
		category,
		false,
		{
			"source": "caveman_reality_runtime.give_resource_item",
			"bundle_id": BUNDLE_ID,
			"tribe_id": str(
				tribe.get(
					"tribe_id",
					""
				)
			),
			"resource_id": resource_id,
		}
	)

	if not _belongings_has_item_instance(
		actor,
		category,
		item_id
	):
		return _failure(
			"caveman_resource_inventory_commit_failed",
			"The resource could not be committed to Belongings."
		)

	resources [resource_id] = available - amount
	tribe ["resources"] = resources
	_store_tribe(
		tribe
	)
	_bump_revision()
	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "caveman_resource_given_to_actor",
		"bundle_id": BUNDLE_ID,
		"actor_id": int(
			actor.id
		),
		"resource_id": resource_id,
		"inventory_category": category,
		"item_id": item_id,
		"item": item.duplicate(true),
		"text": "%s took %d %s from the tribal stockpile." % [
			_actor_name(
				actor
			),
			amount,
			str(
				resource.get(
					"label",
					resource_id.capitalize()
				)
			)
		],
		"log_to_diary": true,
		"ui_is_renderer_only": true
	}
func _belongings_has_item_instance(
	actor: Person,
	category: String,
	item_id: int
) -> bool:
	if (
		actor == null
			or item_id <= 0
			or gs == null
			or gs.belongings_engine == null
			or not gs.belongings_engine.has_method(
				"get_inventory"
			)
	):
		return false

	var inventory_raw: Variant = (
		gs.belongings_engine.get_inventory(
			actor
		)
	)

	if typeof(
		inventory_raw
	) != TYPE_DICTIONARY:
		return false

	var inventory: Dictionary = inventory_raw as Dictionary
	var rows: Array = _array(
		inventory.get(
			category,
			[]
		)
	)

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		)

		if int(
			row.get(
				"id",
				-1
			)
		) == item_id:
			return true

	return false

func _resource_inventory_item(
	resource_id: String,
	resource: Dictionary,
	actor: Person,
	tribe: Dictionary,
	amount: int
) -> Dictionary:
	var is_food: bool = bool(
		resource.get(
			"is_food",
			false
		)
	)
	var requires_cooking: bool = bool(
		resource.get(
			"requires_cooking",
			false
		)
	)
	var nutrition: float = float(
		{
			"elk_meat": 58.0,
			"rabbit_meat": 42.0,
			"bush_berries": 24.0,
			"wild_roots": 30.0,
			"marrow": 48.0,
			"smoked_meat": 62.0
		}.get(
			resource_id,
			18.0
		)
	)
	var resource_item_sequence: int = int(
		state.get(
			"resource_item_sequence",
			0
		)
	) + 1
	state ["resource_item_sequence"] = resource_item_sequence

	var item_id: int = abs(
		int(
			hash(
				"%s:%d:%d:%d:%d" % [
					resource_id,
					int(
						actor.id
					),
					_current_year(),
					resource_item_sequence,
					int(
						Time.get_ticks_msec()
					)
				]
			)
		)
	)

	if item_id <= 0:
		item_id = resource_item_sequence

	return {
		"id": item_id,
		"inventory_instance_id": (
			"caveman_resource:%d:%d"
				% [
					int(
						actor.id
					),
					resource_item_sequence
				]
		),
		"contract_id": (
			"caveman_resource_item:%s"
				% resource_id
		),
		"item_contract": {
			"schema": "eralife.item_contract",
			"version": 1,
			"id": (
				"caveman_resource_item:%s"
					% resource_id
			),
			"display_name": str(
				resource.get(
					"label",
					resource_id.capitalize()
				)
			),
			"category": (
				"Food"
					if is_food
					else "Resources"
			),
			"identity": {
				"type": (
					"food"
						if is_food
						else "caveman_resource"
				),
				"authority": ENGINE_SCHEMA
			},
			"persistence": {
				"save_persistent": true,
				"generationally_persistent": true,
				"age_persistent": true,
				"backwards_compatible": true,
				"preserve_unknown_fields": true,
			}
		},
		"name": str(
			resource.get(
				"label",
				resource_id.capitalize()
			)
		),
		"type": (
			"Food"
				if is_food
				else "Caveman Resource"
		),
		"quantity": amount,
		"stackable": false,
		"nutrition": nutrition,
		"hunger_restore": nutrition * 0.62,
		"may_consume_raw": is_food,
		"requires_cooking": requires_cooking,
		"raw_consumption_risk": (
			0.24
				if requires_cooking
				else 0.02
		),
		"caveman_food": is_food,
		"resource_id": resource_id,
		"bundle_id": BUNDLE_ID,
		"tribe_id": str(
			tribe.get(
				"tribe_id",
				""
			)
		),
		"origin_era": "Caveman Era",
		"acquired_year": _current_year(),
		"source": "caveman_reality_runtime",
		"persistence": {
			"save_persistent": true,
			"generationally_persistent": true,
			"age_persistent": true,
			"backwards_compatible": true,
			"preserve_unknown_fields": true,
		},
		"relationships": {
			"owned_by": int(
				actor.id
			),
			"bound_to": int(
				actor.id
			),
			"ownership_type": "personal_belonging",
			"origin_tribe_id": str(
				tribe.get(
					"tribe_id",
					""
				)
			)
		},
		"overview_lines": [
			"Taken from %s." % str(
				tribe.get(
					"name",
					"the tribe"
				)
			),
			(
				"Raw meat can be eaten, shared, or cooked over the fire."
					if requires_cooking
					else "This resource can be used immediately."
			),
			"This is a separate persistent belonging instance."
		]
	}

func _share_resource_with_tribe(
	actor: Person,
	tribe: Dictionary,
	payload: Dictionary
) -> Dictionary:
	var resource_id: String = _slug(
		str(payload.get("resource_id", "bush_berries"))
	)
	var amount: int = maxi(1, int(payload.get("amount", 1)))
	var resources: Dictionary = _dict(tribe.get("resources", {}))

	if int(resources.get(resource_id, 0)) < amount:
		return _failure(
			"insufficient_tribe_resource",
			"The tribe does not have enough food to share."
		)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "caveman_food_shared_with_tribe",
		"bundle_id": BUNDLE_ID,
		"actor_id": int(actor.id),
		"resource_id": resource_id,
		"amount": amount,
		"text": "%s shared %s with the whole tribe." % [
			_actor_name(actor),
			str(_resource_contract(resource_id).get("label", resource_id.capitalize()))
		],
		"log_to_diary": true,
		"ui_is_renderer_only": true
	}

func assign_role(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Caveman role actor could be resolved."
		)

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return _failure(
			"bundle_disabled",
			"The Caveman Reality Pack is not active."
		)

	if not _component_active("roles"):
		return _failure(
			"roles_component_disabled",
			"Tribal roles are not installed."
		)

	var role_id: String = _slug(
		str(
			payload.get(
				"role_id",
				payload.get(
					"target_role_id",
					""
				)
			)
		)
	)
	var role_contract: Dictionary = _role_contract(
		role_id
	)

	if role_contract.is_empty():
		return _failure(
			"unknown_role",
			"That tribal role is not registered."
		)

	var profile: Dictionary = _ensure_actor_profile(
		actor,
		{
			"source": "assign_role"
		}
	)
	var tribe: Dictionary = _tribe(
		str(
			profile.get(
				"tribe_id",
				""
			)
		)
	)
	var eligibility: Dictionary = _role_eligibility(
		actor,
		role_contract,
		profile,
		tribe
	)

	if not bool(
		eligibility.get(
			"eligible",
			false
		)
	):
		return _failure(
			"role_ineligible",
			str(
				eligibility.get(
					"reason",
					"That role is unavailable."
				)
			)
		)

	var previous_primary_role_id: String = str(
		profile.get(
			"primary_role_id",
			""
		)
	)
	var role_ids: Array = _array(
		profile.get(
			"role_ids",
			[]
		)
	)

	if bool(
		role_contract.get(
			"exclusive",
			false
		)
	):
		var preserved: Array = []

		for existing_id in role_ids:
			if not bool(
				_role_contract(
					str(existing_id)
				).get(
					"exclusive",
					false
				)
			):
				preserved.append(
					str(existing_id)
				)

		role_ids = preserved

	if role_id not in role_ids:
		role_ids.append(role_id)

	if role_id != "birth_giver":
		profile ["primary_role_id"] = role_id

	profile ["role_ids"] = role_ids
	profile ["last_role_change_year"] = _current_year()
	profile ["last_role_change_at_ms"] = int(
		Time.get_ticks_msec()
	)

	var role_history: Array = _array(
		profile.get(
			"role_history",
			[]
		)
	)
	role_history.append({
		"role_id": role_id,
		"previous_primary_role_id": (
			previous_primary_role_id
		),
		"year": _current_year(),
		"assigned_at_ms": int(
			Time.get_ticks_msec()
		),
		"source": str(
			payload.get(
				"source",
				"caveman_role_assignment"
			)
		)
	})

	while role_history.size() > 80:
		role_history.pop_front()

	profile ["role_history"] = role_history

	if role_id == "tribe_leader":
		tribe ["leader_actor_id"] = int(
			actor.id
		)
		tribe ["leader_assigned_year"] = _current_year()

	if role_id in [
		"elder",
		"shaman"
	]:
		var council_ids: Array = _int_array(
			tribe.get(
				"council_member_ids",
				[]
			)
		)

		if int(actor.id) not in council_ids:
			council_ids.append(
				int(actor.id)
			)

		tribe ["council_member_ids"] = council_ids

	_store_profile(profile)
	_recalculate_tribe_metrics(tribe)
	_store_tribe(tribe)
	_bump_revision()
	_publish_state()

	var role_label: String = str(
		role_contract.get(
			"label",
			role_id.capitalize()
		)
	)
	var text: String = (
		"%s now serves the tribe as %s."
		% [
			_actor_name(actor),
			role_label
		]
	)

	_emit_runtime_event(
		"mod_bundle.caveman.role_assigned",
		{
			"actor_id": int(actor.id),
			"tribe_id": str(
				profile.get(
					"tribe_id",
					""
				)
			),
			"role_id": role_id,
			"previous_primary_role_id": (
				previous_primary_role_id
			),
			"text": text
		}
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "caveman_role_assigned",
		"bundle_id": BUNDLE_ID,
		"actor_id": int(actor.id),
		"role_id": role_id,
		"role_label": role_label,
		"previous_primary_role_id": (
			previous_primary_role_id
		),
		"text": text,
		"log_to_diary": true,
		"ui_is_renderer_only": true
	}


func emit_bundle_menu_contract(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Caveman menu observer could be resolved."
		)

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return _failure(
			"bundle_disabled",
			"The Caveman Reality Pack is not active."
		)

	var profile: Dictionary = (
		_actor_profile_observation(
			actor
		)
	)
	var tribe: Dictionary = (
		_tribe_observation_for_actor(
			actor,
			profile
		)
	)
	var base_contract: Dictionary = (
		_base_bundle_menu_contract()
	)
	var active_section: String = str(
		context.get(
			"active_section",
			base_contract.get(
				"default_section",
				"roles"
			)
		)
	).strip_edges().to_lower()

	if active_section not in MENU_SECTION_IDS:
		active_section = "roles"

	var section_surfaces: Dictionary = {
		"roles": _roles_section_rows(
			actor,
			profile,
			tribe
		),
		"survival": _survival_section_rows(
			actor,
			profile,
			tribe
		),
		"resources": _resources_section_rows(
			actor,
			tribe
		),
		"tribe": _tribe_section_rows(
			actor,
			profile,
			tribe
		),
		"settings": _settings_section_rows()
	}
	var presentation: Dictionary = _dict(
		base_contract.get(
			"presentation",
			{}
		)
	)
	var reality_surface: Dictionary = (
		emit_reality_surface_contract(
			actor,
			{
				"source": "emit_bundle_menu_contract",
				"simulation_mutation_forbidden": true
			}
		)
	)

	return {
		"success": true,
		"schema": "eralife.bundle_menu_runtime_contract",
		"version": 2,
		"bundle_id": BUNDLE_ID,
		"experience_id": EXPERIENCE_ID,
		"actor_id": int(actor.id),
		"actor_name": _actor_name(actor),
		"title": str(
			base_contract.get(
				"title",
				"CAVEMAN MENU"
			)
		),
		"subtitle": "%s • %s • %s" % [
			str(
				tribe.get(
					"name",
					"Unresolved Tribe"
				)
			),
			str(
				tribe.get(
					"cave_name",
					"Unresolved Cave"
				)
			),
			_profile_role_label(profile)
		],
		"surface_mode": "bundle_menu",
		"active_bundle_id": BUNDLE_ID,
		"active_section": active_section,
		"identity_overview": _identity_overview(
			actor,
			profile,
			tribe
		),
		"section_tabs": _array(
			base_contract.get(
				"section_tabs",
				[]
			)
		),
		"section_surfaces": section_surfaces,
		"section_rows": _array(
			section_surfaces.get(
				active_section,
				[]
			)
		),
		"presentation": presentation,
		"reality_presentation": presentation,
		"reality_surface_contract": reality_surface,
		"toolbar_actions": [
			{
				"action_id": "open_menu",
				"label": "All Mods",
				"icon": "←",
				"enabled": true
			},
			{
				"action_id": "disable_bundle",
				"label": "Return to Base Reality",
				"icon": "↺",
				"bundle_id": BUNDLE_ID,
				"enabled": true
			}
		],
		"status_text": (
			"Reality controls are hot. "
			+ "Section clicks reveal resident contracts."
		),
		"truth_state": "authoritative_hot",
		"authoritative_projection": true,
		"simulation_mutation_performed": false,
		"surface_revision": (
			"%s:menu"
			% str(
				reality_surface.get(
					"surface_revision",
					""
				)
			)
		),
		"ui_is_renderer_only": true
	}
func yearly_tick(
	payload = {}
) -> Dictionary:
	_ensure_state_shape()

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"type": "caveman_yearly_tick_dormant",
			"enabled": false,
		}

	var context: Dictionary = _dict(payload)
	var year: int = int(
		context.get(
			"year",
			_current_year()
		)
	)

	if int(
		state.get(
			"last_year_processed",
			-999999
		)
	) == year:
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"type": (
				"caveman_yearly_tick_already_processed"
			),
			"year": year,
		}

	var tribe_reports: Array = []
	var tribe_ids: Array = _dict(
		state.get(
			"tribes",
			{}
		)
	).keys()
	tribe_ids.sort()

	for raw_tribe_id in tribe_ids:
		var tribe_id: String = str(
			raw_tribe_id
		)
		var tribe: Dictionary = _tribe(
			tribe_id
		)

		if tribe.is_empty():
			continue

		var member_count: int = maxi(
			1,
			_int_array(
				tribe.get(
					"member_ids",
					[]
				)
			).size()
		)
		var intensity: int = clampi(
			int(
				_dict(
					state.get(
						"settings",
						DEFAULT_SETTINGS
					)
				).get(
					"survival_intensity",
					3
				)
			),
			1,
			5
		)
		var resources: Dictionary = _dict(
			tribe.get(
				"resources",
				{}
			)
		)
		var food_before: int = int(
			resources.get(
				"food",
				0
			)
		)
		var wood_before: int = int(
			resources.get(
				"wood",
				0
			)
		)
		var food_cost: int = (
			member_count * intensity
		)
		var wood_cost: int = maxi(
			1,
			int(
				ceil(
					float(member_count) * 0.5
				)
			)
		)

		resources ["food"] = maxi(
			0,
			food_before - food_cost
		)
		resources ["wood"] = maxi(
			0,
			wood_before - wood_cost
		)
		resources ["fire"] = (
			1
			if int(
				resources.get(
					"wood",
					0
				)
			) > 0
			else 0
		)

		tribe ["resources"] = resources
		tribe ["last_year_tick"] = year
		tribe ["food_shortage"] = (
			food_before < food_cost
		)
		tribe ["fuel_shortage"] = (
			wood_before < wood_cost
		)

		var contributions: Dictionary = _dict(
			tribe.get(
				"contribution_by_actor",
				{}
			)
		)

		for raw_actor_key in contributions.keys():
			var actor_key: String = str(
				raw_actor_key
			)
			contributions [actor_key] = maxi(
				0,
				int(
					contributions.get(
						actor_key,
						0
					)
				) - 1
			)

		tribe ["contribution_by_actor"] = contributions

		_elect_tribe_leader(tribe)
		_recalculate_tribe_metrics(tribe)
		_store_tribe(tribe)

		var tribe_report: Dictionary = {
			"tribe_id": tribe_id,
			"year": year,
			"member_count": member_count,
			"food_consumed": mini(
				food_before,
				food_cost
			),
			"wood_consumed": mini(
				wood_before,
				wood_cost
			),
			"food_shortage": bool(
				tribe.get(
					"food_shortage",
					false
				)
			),
			"fuel_shortage": bool(
				tribe.get(
					"fuel_shortage",
					false
				)
			),
			"survival_status": str(
				tribe.get(
					"survival_status",
					"stable"
				)
			)
		}

		tribe_reports.append(tribe_report)

		_append_tribe_history(
			tribe_id,
			{
				"type": (
					"caveman_yearly_survival_resolution"
				),
				"year": year,
				"report": tribe_report,
				"resolved_at_ms": int(
					Time.get_ticks_msec()
				)
			}
		)

	state ["last_year_processed"] = year

	_bump_revision()
	_publish_state()

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "caveman_yearly_tick_resolved",
		"year": year,
		"tribe_reports": tribe_reports,
		"tribe_count": tribe_reports.size(),
	}

	_emit_runtime_event(
		"mod_bundle.caveman.year_resolved",
		last_report
	)

	return last_report.duplicate(true)


func on_npc_born(
		payload = {}
) -> void:
	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return

	var actor: Person = _person_from_payload(
		payload
	)

	if actor == null:
		return

	_ensure_actor_profile(
		actor,
		{
			"source": "caveman_runtime_npc_born"
		}
	)






func on_npc_died(
	payload = {}
) -> void:
	var actor: Person = _person_from_payload(
		payload
	)

	if actor == null:
		return

	var actor_id: int = int(actor.id)
	var actor_key: String = str(actor_id)
	var tribe_id: String = str(
		_dict(
			state.get(
				"actor_tribe_index",
				{}
			)
		).get(
			actor_key,
			""
		)
	)
	var tribe: Dictionary = _tribe(
		tribe_id
	)

	if tribe.is_empty():
		return

	var member_ids: Array = _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	)
	member_ids.erase(actor_id)
	tribe ["member_ids"] = member_ids

	var departed_member_ids: Array = _int_array(
		tribe.get(
			"departed_member_ids",
			[]
		)
	)

	if actor_id not in departed_member_ids:
		departed_member_ids.append(actor_id)

	tribe ["departed_member_ids"] = (
		departed_member_ids
	)

	if int(
		tribe.get(
			"leader_actor_id",
			-1
		)
	) == actor_id:
		tribe ["leader_actor_id"] = -1

	var council_ids: Array = _int_array(
		tribe.get(
			"council_member_ids",
			[]
		)
	)
	council_ids.erase(actor_id)
	tribe ["council_member_ids"] = council_ids

	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	var profile: Dictionary = _dict(
		profiles.get(
			actor_key,
			{}
		)
	)

	if not profile.is_empty():
		profile ["departed"] = true
		profile ["departed_year"] = _current_year()
		profile ["departed_at_ms"] = int(
			Time.get_ticks_msec()
		)
		profiles [actor_key] = profile
		state ["actor_profiles"] = profiles

	_elect_tribe_leader(tribe)
	_recalculate_tribe_metrics(tribe)
	_store_tribe(tribe)

	_append_tribe_history(
		tribe_id,
		{
			"type": (
				"caveman_tribe_member_departed"
			),
			"actor_id": actor_id,
			"actor_name": _actor_name(actor),
			"year": _current_year(),
			"resolved_at_ms": int(
				Time.get_ticks_msec()
			)
		}
	)

	_bump_revision()
	_publish_state()


func self_heal(
	context: Dictionary = {}
) -> Dictionary:
	return repair_state(context)


func repair_state(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state_shape()

	var repairs: Array = []
	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	var tribes: Dictionary = _dict(
		state.get(
			"tribes",
			{}
		)
	)
	var actor_tribe_index: Dictionary = _dict(
		state.get(
			"actor_tribe_index",
			{}
		)
	)

	state ["selected_component_ids"] = (
		_normalize_component_ids(
			_array(
				state.get(
					"selected_component_ids",
					[]
				)
			)
		)
	)

	if bool(
		state.get(
			"enabled",
			false
		)
	):
		var active: Array = _normalize_component_ids(
			_array(
				state.get(
					"active_component_ids",
					[]
				)
			)
		)
		state ["active_component_ids"] = (
			active
			if not active.is_empty()
			else _array(
				state.get(
					"selected_component_ids",
					[]
				)
			)
		)
	else:
		state ["active_component_ids"] = []

	for raw_actor_key in profiles.keys():
		var actor_key: String = str(
			raw_actor_key
		)
		var profile: Dictionary = _dict(
			profiles.get(
				raw_actor_key,
				{}
			)
		)
		var actor_id: int = int(
			profile.get(
				"actor_id",
				actor_key.to_int()
			)
		)

		if actor_id <= 0:
			profiles.erase(raw_actor_key)
			repairs.append({
				"repair": (
					"invalid_actor_profile_removed"
				),
				"actor_key": actor_key
			})
			continue

		profile ["actor_id"] = actor_id
		profile ["role_ids"] = _string_array(
			profile.get(
				"role_ids",
				[]
			)
		)
		profile ["activity_counts"] = _dict(
			profile.get(
				"activity_counts",
				{}
			)
		)
		profile ["role_history"] = _array(
			profile.get(
				"role_history",
				[]
			)
		)
		profile ["survival_contribution"] = maxi(
			0,
			int(
				profile.get(
					"survival_contribution",
					0
				)
			)
		)

		var tribe_id: String = str(
			profile.get(
				"tribe_id",
				actor_tribe_index.get(
					actor_key,
					""
				)
			)
		).strip_edges().to_lower()

		if tribe_id == "":
			tribe_id = "tribe_unresolved"
			profile ["tribe_id"] = tribe_id
			repairs.append({
				"repair": "actor_tribe_relinked",
				"actor_id": actor_id,
				"tribe_id": tribe_id
			})

		actor_tribe_index [actor_key] = tribe_id
		profiles [actor_key] = profile

		if not tribes.has(tribe_id):
			tribes [tribe_id] = _default_tribe(
				tribe_id,
				"Unresolved Tribe"
			)

	for raw_tribe_id in tribes.keys():
		var tribe_id: String = str(
			raw_tribe_id
		)
		var tribe: Dictionary = _dict(
			tribes.get(
				raw_tribe_id,
				{}
			)
		)

		tribe ["tribe_id"] = tribe_id
		tribe ["member_ids"] = _int_array(
			tribe.get(
				"member_ids",
				[]
			)
		)
		tribe ["departed_member_ids"] = _int_array(
			tribe.get(
				"departed_member_ids",
				[]
			)
		)
		tribe ["council_member_ids"] = _int_array(
			tribe.get(
				"council_member_ids",
				[]
			)
		)
		tribe ["resources"] = _normalize_resources(
			_dict(
				tribe.get(
					"resources",
					{}
				)
			)
		)
		tribe ["contribution_by_actor"] = _dict(
			tribe.get(
				"contribution_by_actor",
				{}
			)
		)
		tribe ["history"] = _array(
			tribe.get(
				"history",
				[]
			)
		)
		tribe ["discovered_territories"] = (
			_string_array(
				tribe.get(
					"discovered_territories",
					[]
				)
			)
		)

		for actor_id in _int_array(
			tribe.get(
				"member_ids",
				[]
			)
		):
			actor_tribe_index [
				str(actor_id)
			] = tribe_id

		_elect_tribe_leader(tribe)
		_recalculate_tribe_metrics(tribe)
		tribes [tribe_id] = tribe

	state ["actor_profiles"] = profiles
	state ["tribes"] = tribes
	state ["actor_tribe_index"] = actor_tribe_index
	state ["settings"] = _normalized_settings(
		_dict(
			state.get(
				"settings",
				DEFAULT_SETTINGS
			)
		)
	)
	state ["activity_history"] = _array(
		state.get(
			"activity_history",
			[]
		)
	)

	if (
		bool(
			context.get(
				"ensure_controlled_actor",
				false
			)
		)
		and gs != null
		and gs.player != null
	):
		_ensure_actor_profile(
			gs.player,
			{
				"source": (
					"repair_state_controlled_actor"
				)
			}
		)

	state ["last_repaired_at_ms"] = int(
		Time.get_ticks_msec()
	)
	state ["last_repair_source"] = str(
		context.get(
			"source",
			"repair_state"
		)
	)

	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"repair_rows": repairs,
		"actor_profile_count": _dict(
			state.get(
				"actor_profiles",
				{}
			)
		).size(),
		"tribe_count": _dict(
			state.get(
				"tribes",
				{}
			)
		).size(),
		"enabled": bool(
			state.get(
				"enabled",
				false
			)
		),
	}


func export_state() -> Dictionary:
	_ensure_state_shape()

	return {
		"schema": STATE_SCHEMA,
		"version": ENGINE_VERSION,
		"state": state.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func import_state(
		data: Dictionary = {}
) -> Dictionary:
	var imported: Dictionary = _dict(
		data.get(
			"state",
			data
		)
	)

	state = (
		imported.duplicate(true)
		if not imported.is_empty()
		else _default_state()
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)




	_ensure_state_shape()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"enabled": bool(
			state.get(
				"enabled",
				false
			)
		),
		"repair_report": {
			"success": true,
			"mode": "hydrated_without_repair"
		},
		"ui_is_renderer_only": true
	}

func _roles_section_rows(
	actor: Person,
	profile: Dictionary,
	tribe: Dictionary
) -> Array:
	if not _component_active("roles"):
		return [
			_component_unavailable_row("roles", "Tribal Roles")
		]

	var primary_role_id: String = str(profile.get("primary_role_id", ""))
	var primary_role: Dictionary = _role_contract(primary_role_id)
	var rows: Array = [
		{
			"row_kind": "caveman_role_summary",
			"id": "current_role",
			"title": "Automatic Tribal Role",
			"subtitle": str(primary_role.get("label", primary_role_id.capitalize())),
			"description": (
				"Roles are assigned automatically from age, tribe size, "
				+ "eligibility, contribution, and existing role coverage. "
				+ "Manual actions are explicit reassignments."
			),
			"chips": [
				"Contribution %d" % int(profile.get("survival_contribution", 0)),
				"Tribe %s" % str(tribe.get("name", "Unresolved")),
				"No Career System"
			],
			"enabled": true,
			"actions": []
		}
	]

	for raw_role in _role_contracts():
		var role: Dictionary = _dict(raw_role)
		var role_id: String = str(role.get("id", ""))

		if role_id == "":
			continue

		var eligibility: Dictionary = _role_eligibility(
			actor,
			role,
			profile,
			tribe
		)
		var is_current: bool = role_id == primary_role_id
		var action: Dictionary = _role_assignment_action(
			role_id,
			bool(eligibility.get("eligible", false)) and not is_current
		)
		action ["label"] = "Reassign Role"
		rows.append({
			"row_kind": "caveman_role",
			"id": "role_%s" % role_id,
			"title": str(role.get("label", role_id.capitalize())),
			"subtitle": (
				"CURRENT ROLE"
				if is_current
				else (
					"ELIGIBLE"
					if bool(eligibility.get("eligible", false))
					else "LOCKED"
				)
			),
			"description": str(role.get("description", _role_description(role_id))),
			"chips": [
				"Age %d-%d" % [
					int(role.get("minimum_age", 0)),
					int(role.get("maximum_age", 130))
				],
				(
					"Assigned Automatically"
					if is_current
					else "Available for Reassignment"
				)
			],
			"enabled": bool(eligibility.get("eligible", false)),
			"disabled_reason": str(eligibility.get("reason", "")),
			"actions": [action]
		})

	return rows


func _survival_section_rows(
	actor: Person,
	profile: Dictionary,
	tribe: Dictionary
) -> Array:
	var settings: Dictionary = _normalized_settings(
		_dict(state.get("settings", DEFAULT_SETTINGS))
	)
	var rows: Array = [
		{
			"row_kind": "caveman_survival_summary",
			"id": "survival_summary",
			"title": "Survival Status",
			"subtitle": str(tribe.get("survival_status", "stable")).to_upper(),
			"description": "The tribe survives through food, fire, shelter, tools, territory, family, and contribution.",
			"chips": [
				"Food Security %d" % int(tribe.get("food_security", 0)),
				"Warmth %d" % int(tribe.get("warmth", 0)),
				"Shelter %d" % int(tribe.get("shelter", 0)),
				"Danger %d" % int(tribe.get("danger", 0)),
				(
					"ALL AGES UNLOCKED"
					if bool(settings.get("unlock_survival_all_ages", false))
					else "AGE GATES ACTIVE"
				)
			],
			"enabled": true,
			"actions": []
		}
	]

	if not _component_active("activities"):
		rows.append(_component_unavailable_row("activities", "Caveman Activities"))
		return rows

	for raw_contract in CavemanRealityBundlePack.caveman_activity_contracts():
		var contract: Dictionary = _dict(raw_contract)

		if bool(contract.get("hidden_from_activities", false)):
			continue

		var activity_id: String = str(contract.get("id", ""))
		var eligibility: Dictionary = _activity_eligibility(
			activity_id,
			actor,
			profile,
			tribe
		)
		rows.append({
			"row_kind": "caveman_activity",
			"id": "activity_%s" % activity_id,
			"title": str(contract.get("title", contract.get("label", activity_id.capitalize()))),
			"subtitle": str(contract.get("category_id", "SURVIVAL")).replace("_", " ").to_upper(),
			"description": str(contract.get("description", "")),
			"chips": [
				"Contribution %d" % _activity_contribution_preview(activity_id),
				"Completed %d times" % int(
					_dict(profile.get("activity_counts", {})).get(activity_id, 0)
				)
			],
			"enabled": bool(eligibility.get("eligible", false)),
			"disabled_reason": str(eligibility.get("text", "")),
			"actions": [
				_activity_provider_action(
					activity_id,
					bool(eligibility.get("eligible", false))
				)
			]
		})

	return rows

func _resources_section_rows(
	_actor: Person,
	tribe: Dictionary
) -> Array:
	if not _component_active(
		"survival_economy"
	):
		return [
			_component_unavailable_row(
				"survival_economy",
				"Resource Survival Economy"
			)
		]

	var rows: Array = []
	var resources: Dictionary = _dict(
		tribe.get(
			"resources",
			{}
		)
	)

	for resource_id in RESOURCE_ORDER:
		var contract: Dictionary = _resource_contract(
			resource_id
		)
		var amount: int = int(
			resources.get(
				resource_id,
				0
			)
		)
		var is_food: bool = bool(
			contract.get(
				"is_food",
				false
			)
		)
		var actions: Array = []

		if amount > 0:
			var give_action: Dictionary = _activity_provider_action(
				"give_resource_item",
				true
			)
			give_action ["label"] = "GIVE YOURSELF"
			give_action ["resource_id"] = resource_id
			give_action ["amount"] = 1
			give_action ["hover_only"] = true
			give_action ["hover_reveal"] = true
			give_action ["ui_is_expression_only"] = true
			actions.append(
				give_action
			)

		if is_food and amount > 0:
			var share_action: Dictionary = _activity_provider_action(
				"share_food_with_tribe",
				true
			)
			share_action ["label"] = "SHARE WITH TRIBE"
			share_action ["resource_id"] = resource_id
			share_action ["amount"] = 1
			actions.append(
				share_action
			)

		rows.append({
			"row_kind": "caveman_resource",
			"id": "resource_%s" % resource_id,
			"title": str(
				contract.get(
					"label",
					resource_id.capitalize()
				)
			),
			"subtitle": "%d AVAILABLE" % amount,
			"description": _resource_description(
				resource_id
			),
			"chips": [
				"Shared Tribe Stockpile",
				_resource_condition_label(
					resource_id,
					amount
				),
				(
					"RAW OR COOKED"
						if bool(
							contract.get(
								"requires_cooking",
								false
							)
						)
						else "READY TO USE"
				)
			],
			"enabled": amount > 0,
			"animate_title_on_hover": true,
			"actions": actions
		})

	return rows

func _tribe_section_rows(
		actor: Person,
		profile: Dictionary,
		tribe: Dictionary
) -> Array:
	var leader_id: int = int(
		tribe.get(
			"leader_actor_id",
			-1
		)
	)
	var leader: Person = _person_by_id(
		leader_id
	)
	var member_ids: Array = _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	)
	var rows: Array = [
		{
			"row_kind": "caveman_tribe_summary",
			"id": "tribe_summary",
			"title": str(
				tribe.get(
					"name",
					"Unresolved Tribe"
				)
			),
			"subtitle": "%d MEMBERS • %s" % [
				member_ids.size(),
				str(
					tribe.get(
						"cave_name",
						"Unresolved Cave"
					)
				)
			],
			"description": (
				"Your household, parents, children, partner, siblings, "
				+ "and living grandparents share one persistent tribe projection."
			),
			"chips": [
				"Cave %s" % str(
					tribe.get(
						"cave_name",
						"Unknown Cave"
					)
				),
				"Tools %d" % int(
					tribe.get(
						"tool_count",
						0
					)
				),
				"Family Tribe"
			],
			"enabled": true,
			"actions": []
		},
		{
			"row_kind": "caveman_governance",
			"id": "tribe_leadership",
			"title": "Tribe Leader",
			"subtitle": (
				_actor_name(leader)
				if leader != null
				else "VACANT"
			),
			"description": (
				"Leadership is balanced automatically from adult "
				+ "eligibility and survival contribution."
			),
			"chips": [
				"Current Actor Contribution %d"
				% int(
					profile.get(
						"survival_contribution",
						0
					)
				),
				"Automatic Succession"
			],
			"enabled": true,
			"actions": []
		}
	]

	var profiles_raw: Variant = state.get(
		"actor_profiles",
		{}
	)
	var profiles: Dictionary = (
		profiles_raw as Dictionary
		if typeof(profiles_raw) == TYPE_DICTIONARY
		else {}
	)
	var member_projection_limit: int = 64
	var projected_member_count: int = 0

	for member_id in member_ids:
		if (
			projected_member_count
			>= member_projection_limit
		):
			break

		var member: Person = _person_by_id(
			member_id
		)

		if member == null:
			continue

		var member_profile: Dictionary = {}
		var member_profile_raw: Variant = (
			profiles.get(
				str(member_id),
				{}
			)
		)

		if typeof(member_profile_raw) == TYPE_DICTIONARY:
			member_profile = (
				(member_profile_raw as Dictionary)
				.duplicate(true)
			)

		rows.append({
			"row_kind": "caveman_tribe_member",
			"id": "tribe_member_%d" % member_id,
			"title": _actor_name(member),
			"subtitle": (
				_profile_role_label(
					member_profile
				).to_upper()
			),
			"description": (
				"Age %d • persistent identity • family relationship preserved"
				% int(member.age)
			),
			"chips": [
				(
					"CONTROLLED ACTOR"
					if member_id == int(actor.id)
					else "TRIBE MEMBER"
				),
				"Contribution %d"
				% int(
					member_profile.get(
						"survival_contribution",
						0
					)
				)
			],
			"enabled": true,
			"actions": []
		})
		projected_member_count += 1

	if member_ids.size() > projected_member_count:
		rows.append({
			"row_kind": "caveman_tribe_observation_tail",
			"id": "tribe_members_resident_tail",
			"title": (
				"%d More Tribe Members"
				% (
					member_ids.size()
					- projected_member_count
				)
			),
			"subtitle": "RESIDENT • NOT IN THIS OBSERVATION QUANTUM",
			"description": (
				"Additional tribe members remain simulation-resident "
				+ "and may publish progressively without blocking this lens."
			),
			"enabled": false,
			"actions": [],
			"ui_is_renderer_only": true
		})

	return rows
func _settings_section_rows() -> Array:
	var settings: Dictionary = _normalized_settings(
		_dict(state.get("settings", DEFAULT_SETTINGS))
	)

	return [
		{
			"row_kind": "mod_setting",
			"id": "unlock_survival_all_ages",
			"mod_id": ROOT_MOD_ID,
			"setting_id": "unlock_survival_all_ages",
			"setting_type": "bool",
			"title": "All-Age Survival",
			"subtitle": (
				"UNRESTRICTED"
				if bool(settings.get("unlock_survival_all_ages", false))
				else "AGE-GATED"
			),
			"description": "Unlock every survival action for every age, or restore the original age progression instantly.",
			"value": bool(settings.get("unlock_survival_all_ages", false)),
			"enabled": true,
			"provider_action_id": "toggle_survival_age_unlock",
			"bundle_id": BUNDLE_ID,
			"service_id": "caveman_reality",
			"method": "perform_activity"
		},
		{
			"row_kind": "mod_setting",
			"id": "survival_intensity",
			"mod_id": ROOT_MOD_ID,
			"setting_id": "survival_intensity",
			"setting_type": "integer",
			"title": "Survival Intensity",
			"description": "Adjust resource pressure without rebuilding the reality.",
			"value": int(settings.get("survival_intensity", 3)),
			"enabled": true
		}
	]

func _resolve_activity(
	activity_id: String,
	actor: Person,
	tribe: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var resources: Dictionary = _dict(
		tribe.get("resources", {})
	)

	match activity_id:
		"listen_to_fire":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s watched firelight move across the cave walls." % _actor_name(actor)
			}
		"reach_for_family":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s reached toward a familiar face in the tribe." % _actor_name(actor)
			}
		"crawl_across_hides":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s crawled across the family's sleeping hides." % _actor_name(actor)
			}
		"babble_at_tribe":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s babbled until the cave answered with familiar voices." % _actor_name(actor)
			}
		"nap_by_fire":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s slept beside the tribe's warmth." % _actor_name(actor)
			}
		"play_with_smooth_stone":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 1,
				"text": "%s played with a smooth river stone." % _actor_name(actor)
			}
		"snuggle_parent":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 2,
				"text": "%s curled close to a parent for warmth." % _actor_name(actor)
			}
		"listen_to_grandparent_story":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 2,
				"text": "%s listened to an elder preserve the tribe's memory." % _actor_name(actor)
			}
		"follow_gatherer":
			return {
				"success": true,
				"resource_deltas": { "bush_berries": rng.randi_range(1, 3)},
				"contribution_delta": 3,
				"text": "%s followed a gatherer and learned safe plants." % _actor_name(actor)
			}
		"gather_kindling":
			return {
				"success": true,
				"resource_deltas": { "wood": rng.randi_range(1, 4)},
				"contribution_delta": 4,
				"text": "%s carried dry kindling back to the cave." % _actor_name(actor)
			}
		"learn_animal_tracks":
			return {
				"success": true,
				"resource_deltas": {},
				"contribution_delta": 4,
				"text": "%s learned to read tracks and broken grass." % _actor_name(actor)
			}
		"hunt_herd":
			return {
				"success": true,
				"resource_deltas": {
					"elk_meat": rng.randi_range(6, 14),
					"marrow": rng.randi_range(1, 3),
					"hide": rng.randi_range(1, 4),
					"bone": rng.randi_range(1, 3)
				},
				"contribution_delta": 12,
				"text": "%s returned from the hunt with elk meat, marrow, hide, and bone." % _actor_name(actor)
			}
		"gather_roots_berries":
			return {
				"success": true,
				"resource_deltas": {
					"bush_berries": rng.randi_range(4, 9),
					"wild_roots": rng.randi_range(3, 7),
					"wood": rng.randi_range(1, 3)
				},
				"contribution_delta": 8,
				"text": "%s gathered bush berries, wild roots, and usable wood." % _actor_name(actor)
			}
		"craft_stone_tools":
			if int(resources.get("stone", 0)) < 2 or int(resources.get("wood", 0)) < 1:
				return _failure(
					"insufficient_tool_resources",
					"Crafting tools requires 2 stone and 1 wood."
				)
			return {
				"success": true,
				"resource_deltas": { "stone": -2, "wood": -1},
				"tool_count_delta": 1,
				"contribution_delta": 10,
				"text": "%s crafted a new stone tool for the tribe." % _actor_name(actor)
			}
		"start_fire":
			if int(resources.get("wood", 0)) < 2:
				return _failure(
					"insufficient_firewood",
					"Starting a protective fire requires 2 wood."
				)
			return {
				"success": true,
				"resource_deltas": { "wood": -2, "fire": 1},
				"contribution_delta": 7,
				"text": "%s restored the tribe's protective fire." % _actor_name(actor)
			}
		"explore_territory":
			var territory_id: String = "territory_%d" % (
				_array(tribe.get("discovered_territories", [])).size() + 1
			)
			return {
				"success": true,
				"resource_deltas": {
					"stone": rng.randi_range(1, 4),
					"wood": rng.randi_range(1, 3)
				},
				"territory_id": territory_id,
				"contribution_delta": 9,
				"text": "%s explored new territory and marked safe resources." % _actor_name(actor)
			}

	return _failure(
		"unknown_caveman_activity",
		"That Caveman activity is not registered."
	)
func _activity_category_rows(
	actor: Person,
	profile: Dictionary,
	tribe: Dictionary,
	_settings: Dictionary
) -> Array:
	var grouped_rows: Dictionary = {}
	var grouped_actions: Dictionary = {}
	var order: Array = [
		"cave_baby",
		"young_survival",
		"tribe_bonds",
		"tribe_survival"
	]

	for raw_contract in CavemanRealityBundlePack.caveman_activity_contracts():
		var contract: Dictionary = _dict(
			raw_contract
		)

		if bool(
			contract.get(
				"hidden_from_activities",
				false
			)
		):
			continue

		var activity_id: String = str(
			contract.get(
				"id",
				""
			)
		)
		var category_id: String = str(
			contract.get(
				"category_id",
				"tribe_survival"
			)
		)
		var eligibility: Dictionary = _activity_eligibility(
			activity_id,
			actor,
			profile,
			tribe
		)
		var activity_enabled: bool = bool(
			eligibility.get(
				"eligible",
				false
			)
		)
		var action: Dictionary = _activity_provider_action(
			activity_id,
			activity_enabled
		)
		var activity_label: String = str(
			contract.get(
				"label",
				activity_id.capitalize()
			)
		)
		var activity_description: String = str(
			contract.get(
				"description",
				""
			)
		)
		var disabled_reason: String = str(
			eligibility.get(
				"text",
				""
			)
		)

		action ["id"] = (
			"activity_action_%s" % activity_id
		)
		action ["label"] = activity_label
		action ["title"] = activity_label
		action ["description"] = activity_description
		action ["category_id"] = category_id
		action ["disabled_reason"] = disabled_reason
		action ["ui_is_renderer_only"] = true

		var rows: Array = _array(
			grouped_rows.get(
				category_id,
				[]
			)
		)
		rows.append({
			"id": "activity_%s" % activity_id,
			"row_kind": "caveman_activity",
			"title": str(
				contract.get(
					"title",
					activity_label
				)
			),
			"subtitle": (
				"AVAILABLE"
				if activity_enabled
				else "LOCKED"
			),
			"description": activity_description,
			"enabled": activity_enabled,
			"disabled_reason": disabled_reason,
			"chips": [
				"Contribution %d"
				% _activity_contribution_preview(
					activity_id
				),
				"Completed %d times"
				% int(
					_dict(
						profile.get(
							"activity_counts",
							{}
						)
					).get(
						activity_id,
						0
					)
				)
			],
			"actions": [
				action.duplicate(true)
			],
			"ui_is_renderer_only": true
		})
		grouped_rows [category_id] = rows

		var actions: Array = _array(
			grouped_actions.get(
				category_id,
				[]
			)
		)
		actions.append(
			action.duplicate(true)
		)
		grouped_actions [category_id] = actions

	var out: Array = []
	var labels: Dictionary = {
		"cave_baby": "CAVE BABY",
		"young_survival": "YOUNG SURVIVAL",
		"tribe_bonds": "TRIBE BONDS",
		"tribe_survival": "SURVIVAL"
	}
	var icons: Dictionary = {
		"cave_baby": "🪨",
		"young_survival": "🪵",
		"tribe_bonds": "🔥",
		"tribe_survival": "🦴"
	}
	var descriptions: Dictionary = {
		"cave_baby": (
			"Personal discoveries, family bonds, and "
			+ "tiny cave-person chaos."
		),
		"young_survival": (
			"Learn the safe beginnings of tribal survival."
		),
		"tribe_bonds": (
			"Build bonds with family, partners, and tribe members."
		),
		"tribe_survival": (
			"Hunt, gather, craft, cook, guard, and explore."
		)
	}

	for raw_category_id in order:
		var category_id: String = str(
			raw_category_id
		)
		var rows: Array = _array(
			grouped_rows.get(
				category_id,
				[]
			)
		)
		var actions: Array = _array(
			grouped_actions.get(
				category_id,
				[]
			)
		)

		if rows.is_empty() and actions.is_empty():
			continue

		out.append({
			"id": category_id,
			"label": str(
				labels.get(
					category_id,
					category_id.to_upper()
				)
			),
			"icon": str(
				icons.get(
					category_id,
					"•"
				)
			),
			"description": str(
				descriptions.get(
					category_id,
					""
				)
			),

			"rows": rows,

			"actions": actions,
			"visible": true,
			"ui_is_renderer_only": true
		})

	return out

func _birth_intro_projection(
	actor: Person,
	_profile: Dictionary,
	tribe: Dictionary
) -> Dictionary:
	var tribe_name: String = str(
		tribe.get(
			"name",
			"the tribe"
		)
	)
	var cave_name: String = str(
		tribe.get(
			"cave_name",
			"the cave"
		)
	)
	var birth_gender: String = _gender_key(
		actor
	)
	var birthday: Dictionary = _dict(
		actor.birthday
	)
	var birth_month: int = clampi(
		int(
			birthday.get(
				"month",
				1
			)
		),
		1,
		12
	)
	var birth_day: int = EraUtils.clamp_day_for_month(
		int(
			birthday.get(
				"day",
				1
			)
		),
		birth_month,
		0
	)
	var zodiac: String = str(
		actor.zodiac
	).strip_edges()
	var lines: Array = [
		"I was born during %s."
		% _caveman_display_year_label(
			tribe
		),
		"I was born a %s in %s, home of %s."
		% [
			birth_gender,
			cave_name,
			tribe_name
		],
		_caveman_conception_story(
			actor,
			tribe
		),
		"My birthday is %s %d.%s"
		% [
			_caveman_month_name(
				birth_month
			),
			birth_day,
			(
				" I am a %s." % zodiac
				if zodiac != ""
				else ""
			)
		],
		"My name is %s."
		% _actor_name(actor)
	]

	lines.append_array(
		_birth_family_role_lines(
			actor
		)
	)

	return {
		"replace_visible_birth_intro": true,
		"headline": (
			"A new life entered %s."
			% tribe_name
		),
		"lines": lines,
		"base_birth_city_preserved": str(
			actor.birth_city
		),
		"base_birth_country_preserved": str(
			actor.birth_country
		),
		"ui_is_renderer_only": true
	}
func _caveman_conception_story(
	actor: Person,
	tribe: Dictionary
) -> String:
	var stories: Array = [
		(
			"I was conceived after my parents drank too much "
			+ "fermented berry mash and disappeared behind "
			+ "the mammoth hides while the tribe loudly "
			+ "pretended not to hear anything."
		),
		(
			"I was conceived during a thunderstorm when a "
			+ "collapsed sleeping hide, terrible judgment, "
			+ "and astonishing enthusiasm became family history."
		),
		(
			"I was conceived after a successful hunt, three "
			+ "bowls of fermented roots, and a wager neither "
			+ "of my parents understood correctly."
		),
		(
			"I was conceived in the darkest corner of the cave "
			+ "while an elder guarded the entrance and later "
			+ "denied being involved in the operation."
		),
		(
			"I was conceived on a pile of stolen wolf pelts "
			+ "after my parents were told very specifically "
			+ "not to touch the ceremonial bedding."
		),
		(
			"I was conceived after my parents volunteered for "
			+ "night watch and somehow watched absolutely "
			+ "nothing except each other."
		),
		(
			"I was conceived behind the food-storage rocks, "
			+ "which explains why the tribe found two missing "
			+ "adults and several crushed baskets of berries."
		),
		(
			"I was conceived after a fire-dancing celebration "
			+ "that ended with my parents banned from using "
			+ "the chief's private sleeping hides."
		)
	]
	var story_index: int = abs(
		int(
			hash(
				"caveman_conception:%d:%s"
				% [
					int(actor.id),
					str(
						tribe.get(
							"tribe_id",
							""
						)
					)
				]
			)
		)
	) % stories.size()

	return str(
		stories [story_index]
	)


func _birth_family_role_lines(
	actor: Person
) -> Array:
	var lines: Array = []
	var classified: Dictionary = {}
	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	var parent_ids: Array = _int_array(
		actor.parents
	)

	for parent_index in range(
		parent_ids.size()
	):
		var parent: Person = _person_by_id(
			int(
				parent_ids [parent_index]
			)
		)

		if parent == null:
			continue

		var side: String = _birth_parent_side(
			parent,
			parent_index
		)
		var relation: String = (
			_birth_parent_relation_label(
				parent
			)
		)

		lines.append(
			_birth_member_role_line(
				parent,
				relation,
				profiles
			)
		)
		classified [
			int(parent.id)
		] = true

		_append_birth_ancestor_role_lines(
			lines,
			classified,
			parent,
			side,
			1,
			6,
			profiles
		)

	if gs != null:
		for raw_candidate in gs.npcs:
			var candidate:= raw_candidate as Person

			if (
				candidate == null
				or candidate == actor
				or classified.has(
					int(candidate.id)
				)
			):
				continue

			var shares_parent: bool = false

			for raw_parent_id in parent_ids:
				if raw_parent_id in _int_array(
					candidate.parents
				):
					shares_parent = true
					break

			if not shares_parent:
				continue

			lines.append(
				_birth_member_role_line(
					candidate,
					_birth_sibling_relation_label(
						candidate
					),
					profiles
				)
			)
			classified [
				int(candidate.id)
			] = true

	if actor.partner != null:
		var partner_id: int = int(
			actor.partner.id
		)

		if not classified.has(partner_id):
			lines.append(
				_birth_member_role_line(
					actor.partner,
					"partner",
					profiles
				)
			)
			classified [partner_id] = true

	for raw_child_id in _int_array(
		actor.children
	):
		var child: Person = _person_by_id(
			raw_child_id
		)

		if (
			child == null
			or classified.has(
				int(child.id)
			)
		):
			continue

		var child_relation: String = "child"
		var child_gender: String = _gender_key(
			child
		)

		if child_gender == "female":
			child_relation = "daughter"
		elif child_gender == "male":
			child_relation = "son"

		lines.append(
			_birth_member_role_line(
				child,
				child_relation,
				profiles
			)
		)
		classified [
			int(child.id)
		] = true



	for raw_member in _controlled_family_members(
		actor
	):
		var member:= raw_member as Person

		if (
			member == null
			or member == actor
			or classified.has(
				int(member.id)
			)
		):
			continue

		lines.append(
			_birth_member_role_line(
				member,
				"relative",
				profiles
			)
		)
		classified [
			int(member.id)
		] = true

	return lines


func _append_birth_ancestor_role_lines(
	lines: Array,
	classified: Dictionary,
	descendant: Person,
	side: String,
	generation: int,
	maximum_generation: int,
	profiles: Dictionary
) -> void:
	if (
		descendant == null
		or generation > maximum_generation
	):
		return

	for raw_ancestor_id in _int_array(
		descendant.parents
	):
		var ancestor: Person = _person_by_id(
			raw_ancestor_id
		)

		if ancestor == null:
			continue

		var ancestor_id: int = int(
			ancestor.id
		)

		if classified.has(
			ancestor_id
		):
			continue

		var relation: String = (
			_birth_ancestor_relation_label(
				side,
				ancestor,
				generation
			)
		)

		lines.append(
			_birth_member_role_line(
				ancestor,
				relation,
				profiles
			)
		)
		classified [ancestor_id] = true

		_append_birth_ancestor_role_lines(
			lines,
			classified,
			ancestor,
			side,
			generation + 1,
			maximum_generation,
			profiles
		)


func _birth_member_role_line(
	member: Person,
	relation: String,
	profiles: Dictionary
) -> String:
	var member_profile: Dictionary = _dict(
		profiles.get(
			str(
				int(member.id)
			),
			{}
		)
	)
	var role_label: String = _profile_role_label(
		member_profile
	)

	if role_label.strip_edges() == "":
		role_label = "Tribe Member"

	return (
		"My %s is %s, the tribe's %s (age %d)."
		% [
			relation,
			_actor_name(member),
			role_label,
			int(member.age)
		]
	)


func _birth_parent_side(
	parent: Person,
	parent_index: int
) -> String:
	var gender: String = _gender_key(
		parent
	)

	if gender == "female":
		return "maternal"

	if gender == "male":
		return "paternal"

	return (
		"maternal"
		if parent_index == 0
		else "paternal"
	)


func _birth_parent_relation_label(
	parent: Person
) -> String:
	var gender: String = _gender_key(
		parent
	)

	if gender == "female":
		return "mother"

	if gender == "male":
		return "father"

	return "parent"


func _birth_sibling_relation_label(
	sibling: Person
) -> String:
	var gender: String = _gender_key(
		sibling
	)

	if gender == "female":
		return "sister"

	if gender == "male":
		return "brother"

	return "sibling"


func _birth_ancestor_relation_label(
	side: String,
	ancestor: Person,
	generation: int
) -> String:
	var gender: String = _gender_key(
		ancestor
	)
	var base_relation: String = "grandparent"

	if gender == "female":
		base_relation = "grandmother"
	elif gender == "male":
		base_relation = "grandfather"

	if generation <= 1:
		return "%s %s" % [
			side,
			base_relation
		]

	var great_prefix: String = ""

	for _index in range(
		generation - 1
	):
		great_prefix += "great-"

	return "%s %s%s" % [
		side,
		great_prefix,
		base_relation
	]


func _caveman_month_name(
	month: int
) -> String:
	var months: Array = [
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December"
	]

	return str(
		months [
			clampi(
				month,
				1,
				12
			) - 1
		]
	)

func _world_browser_tribe_entries(
	actor: Person,
	current_tribe: Dictionary
) -> Array:
	var out: Array = []
	var current_tribe_id: String = str(
		current_tribe.get(
			"tribe_id",
			""
		)
	)
	var tribe_seed: int = abs(
		int(
			hash(
				"tribe_browser:%d"
				% _lineage_root_id(actor)
			)
		)
	)

	for index in range(8):
		var prefix: String = str(
			TRIBE_NAME_PREFIXES [
				(tribe_seed + index * 3)
				% TRIBE_NAME_PREFIXES.size()
			]
		)
		var suffix: String = str(
			TRIBE_NAME_SUFFIXES [
				(tribe_seed + index * 5 + 1)
				% TRIBE_NAME_SUFFIXES.size()
			]
		)
		var cave_prefix: String = str(
			CAVE_NAME_PREFIXES [
				(tribe_seed + index * 7)
				% CAVE_NAME_PREFIXES.size()
			]
		)
		var cave_suffix: String = str(
			CAVE_NAME_SUFFIXES [
				(tribe_seed + index * 11)
				% CAVE_NAME_SUFFIXES.size()
			]
		)
		var tribe_id: String = (
			"observed_tribe_%d_%d"
			% [
				tribe_seed,
				index
			]
		)

		if tribe_id == current_tribe_id:
			continue

		var tribe_name: String = (
			"The %s%s Tribe"
			% [
				prefix,
				suffix
			]
		)
		var cave_name: String = (
			"%s %s"
			% [
				cave_prefix,
				cave_suffix
			]
		)

		out.append({
			"entry_id": tribe_id,
			"entry_kind": "realm",
			"name": tribe_name,
			"realm": {
				"realm_id": -1 - index,
				"name": tribe_name,
				"realm_type": "cave_tribe",
				"capital_city": cave_name,
				"description": (
					"A neighboring cave society with its own "
					+ "people, resources, dangers, and "
					+ "survival history."
				),
				"population": (
					6
					+ (
						(tribe_seed + index * 13)
						% 24
					)
				),
				"danger": (
					20
					+ (
						(tribe_seed + index * 17)
						% 65
					)
				),
				"browser_visual_theme": "caveman_tribe",
				"overview_visual_theme": "caveman_tribe",
				"caveman_reality": true
			},
			"ui_is_renderer_only": true
		})

	return out

func _caveman_display_year_label(
	tribe: Dictionary
) -> String:
	var fire_count: int = maxi(
		1,
		int(tribe.get("fire_count_epoch", 1))
		+ maxi(0, _current_year() - int(tribe.get("origin_year", _current_year())))
	)

	return "Fire Count %d" % fire_count


func _profile_role_label(
	profile: Dictionary
) -> String:
	var role_id: String = str(profile.get("primary_role_id", ""))
	var role: Dictionary = _role_contract(role_id)

	return str(role.get("label", role_id.capitalize()))
func _ensure_actor_profile(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	if state.is_empty():
		state = _default_state()

	var actor_key: String = str(
		int(actor.id)
	)
	var profiles_raw: Variant = state.get(
		"actor_profiles",
		{}
	)
	var profiles: Dictionary = (
		profiles_raw as Dictionary
		if typeof(profiles_raw) == TYPE_DICTIONARY
		else {}
	)
	var profile: Dictionary = {}
	var profile_raw: Variant = profiles.get(
		actor_key,
		{}
	)

	if typeof(profile_raw) == TYPE_DICTIONARY:
		profile = (
			(profile_raw as Dictionary).duplicate(true)
		)

	var tribe: Dictionary = _ensure_tribe_for_actor(
		actor
	)
	var tribe_id: String = str(
		tribe.get(
			"tribe_id",
			"tribe_unresolved"
		)
	)

	if profile.is_empty():
		var default_role_id: String = (
			_default_role_for_actor(actor)
		)

		profile = {
			"actor_id": int(actor.id),
			"actor_name": _actor_name(actor),
			"tribe_id": tribe_id,
			"primary_role_id": default_role_id,
			"role_ids": [
				default_role_id
			],
			"survival_contribution": 0,
			"activity_counts": {},
			"role_history": [
				{
					"role_id": default_role_id,
					"year": _current_year(),
					"source": str(
						context.get(
							"source",
							"actor_profile_created"
						)
					)
				}
			],
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"last_active_year": _current_year()
		}

		if _birth_giver_is_eligible(actor):
			profile ["role_ids"].append(
				"birth_giver"
			)
	else:
		profile ["actor_name"] = _actor_name(actor)
		profile ["tribe_id"] = tribe_id
		profile ["survival_contribution"] = maxi(
			0,
			int(
				profile.get(
					"survival_contribution",
					0
				)
			)
		)
		profile ["activity_counts"] = _dict(
			profile.get(
				"activity_counts",
				{}
			)
		)
		profile ["role_ids"] = _string_array(
			profile.get(
				"role_ids",
				[]
			)
		)

	var primary_id: String = str(
		profile.get(
			"primary_role_id",
			""
		)
	)
	var primary_contract: Dictionary = (
		_role_contract(primary_id)
	)

	if (
		primary_contract.is_empty()
		or not bool(
			_role_eligibility(
				actor,
				primary_contract,
				profile,
				tribe,
				true
			).get(
				"age_valid",
				false
			)
		)
	):
		var replacement: String = (
			_default_role_for_actor(actor)
		)
		profile ["primary_role_id"] = replacement

		if replacement not in _array(
			profile.get(
				"role_ids",
				[]
			)
		):
			profile ["role_ids"].append(
				replacement
			)

	profiles [actor_key] = profile
	state ["actor_profiles"] = profiles

	var index_raw: Variant = state.get(
		"actor_tribe_index",
		{}
	)
	var index: Dictionary = (
		index_raw as Dictionary
		if typeof(index_raw) == TYPE_DICTIONARY
		else {}
	)
	index [actor_key] = tribe_id
	state ["actor_tribe_index"] = index

	var member_ids: Array = _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	)

	if int(actor.id) not in member_ids:
		member_ids.append(
			int(actor.id)
		)

	tribe ["member_ids"] = member_ids
	_store_tribe(tribe)

	return profile.duplicate(true)
func _ensure_controlled_family_tribe(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null or gs == null:
		return _failure(
			"missing_family_actor",
			"No controlled family could be resolved."
		)

	var family_members: Array = _controlled_family_members(
		actor
	)
	var tribe_id: String = _tribe_id_for_actor(
		actor
	)
	var tribes: Dictionary = _dict(
		state.get(
			"tribes",
			{}
		)
	)
	var tribe: Dictionary = _dict(
		tribes.get(
			tribe_id,
			{}
		)
	)

	if tribe.is_empty():
		tribe = _default_tribe(
			tribe_id,
			_tribe_name_for_actor(actor)
		)

	tribe ["cave_name"] = _cave_name_for_actor(actor)
	tribe ["territory_name"] = str(
		tribe.get(
			"cave_name",
			"Unresolved Cave"
		)
	)

	var member_ids: Array = _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	)
	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	var index: Dictionary = _dict(
		state.get(
			"actor_tribe_index",
			{}
		)
	)

	for raw_member in family_members:
		var member:= raw_member as Person

		if member == null:
			continue

		var member_id: int = int(member.id)
		var member_key: String = str(member_id)

		if member_id not in member_ids:
			member_ids.append(member_id)

		index [member_key] = tribe_id

		var profile: Dictionary = _dict(
			profiles.get(
				member_key,
				{}
			)
		)

		if profile.is_empty():
			var default_role_id: String = _default_role_for_actor(
				member
			)
			profile = {
				"actor_id": member_id,
				"actor_name": _actor_name(member),
				"tribe_id": tribe_id,
				"primary_role_id": default_role_id,
				"role_ids": [default_role_id],
				"survival_contribution": 0,
				"activity_counts": {},
				"role_history": [
					{
						"role_id": default_role_id,
						"year": _current_year(),
						"source": str(
							context.get(
								"source",
								"controlled_family_tribe"
							)
						)
					}
				],
				"created_at_ms": int(Time.get_ticks_msec()),
				"last_active_year": _current_year()
			}
		else:
			profile ["actor_name"] = _actor_name(member)
			profile ["tribe_id"] = tribe_id

		if (
			_birth_giver_is_eligible(member)
			and "birth_giver" not in _array(
				profile.get(
					"role_ids",
					[]
				)
			)
		):
			profile ["role_ids"].append("birth_giver")

		profiles [member_key] = profile

	tribe ["member_ids"] = member_ids
	tribes [tribe_id] = tribe
	state ["tribes"] = tribes
	state ["actor_profiles"] = profiles
	state ["actor_tribe_index"] = index

	return {
		"success": true,
		"schema": "eralife.caveman_family_tribe_contract",
		"version": 1,
		"tribe_id": tribe_id,
		"tribe_name": str(tribe.get("name", "Unresolved Tribe")),
		"cave_name": str(tribe.get("cave_name", "Unresolved Cave")),
		"member_ids": member_ids.duplicate(true),
		"member_count": member_ids.size(),
		"ui_is_renderer_only": true
	}


func _controlled_family_members(
	actor: Person
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	_append_family_member(
		out,
		seen,
		actor
	)



	var ancestor_frontier: Array = _int_array(
		actor.parents
	)
	var visited_ancestor_ids: Dictionary = {}
	var ancestry_depth: int = 0
	var maximum_ancestry_depth: int = 8

	while (
		not ancestor_frontier.is_empty()
		and ancestry_depth < maximum_ancestry_depth
	):
		var next_frontier: Array = []

		for raw_ancestor_id in ancestor_frontier:
			var ancestor_id: int = int(
				raw_ancestor_id
			)

			if (
				ancestor_id <= 0
				or visited_ancestor_ids.has(
					ancestor_id
				)
			):
				continue

			visited_ancestor_ids [ancestor_id] = true

			var ancestor: Person = _person_by_id(
				ancestor_id
			)

			if ancestor == null:
				continue

			_append_family_member(
				out,
				seen,
				ancestor
			)

			for raw_parent_id in _int_array(
				ancestor.parents
			):
				var parent_id: int = int(
					raw_parent_id
				)

				if (
					parent_id > 0
					and not visited_ancestor_ids.has(
						parent_id
					)
				):
					next_frontier.append(
						parent_id
					)

		ancestor_frontier = next_frontier
		ancestry_depth += 1

	for raw_child_id in _int_array(
		actor.children
	):
		_append_family_member(
			out,
			seen,
			_person_by_id(
				raw_child_id
			)
		)

	if actor.partner != null:
		_append_family_member(
			out,
			seen,
			actor.partner
		)

	if gs != null:
		var actor_parent_ids: Array = _int_array(
			actor.parents
		)

		for raw_candidate in gs.npcs:
			var candidate:= raw_candidate as Person

			if candidate == null or candidate == actor:
				continue

			var shares_parent: bool = false

			for raw_parent_id in actor_parent_ids:
				if raw_parent_id in _int_array(
					candidate.parents
				):
					shares_parent = true
					break

			if shares_parent:
				_append_family_member(
					out,
					seen,
					candidate
				)

	return out


func _append_family_member(
	out: Array,
	seen: Dictionary,
	member: Person
) -> void:
	if member == null:
		return

	var member_id: int = int(member.id)

	if member_id <= 0 or seen.has(member_id):
		return

	seen [member_id] = true
	out.append(member)


func _rebalance_tribe_roles(
	tribe_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var tribe: Dictionary = _tribe(tribe_id)

	if tribe.is_empty():
		return _failure(
			"missing_tribe",
			"The tribe could not be balanced."
		)

	var members: Array = []

	for raw_member_id in _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	):
		var member: Person = _person_by_id(raw_member_id)

		if member != null and bool(member.alive):
			members.append(member)

	members.sort_custom(
		func (a, b):
			var left:= a as Person
			var right:= b as Person
			return int(left.id) < int(right.id)
	)

	var adult_index: int = 0
	var changed_actor_ids: Array = []
	var adult_cycle: Array = [
		"gatherer",
		"hunter",
		"fire_keeper",
		"tool_maker",
		"scout"
	]

	for raw_member in members:
		var member:= raw_member as Person
		var profile: Dictionary = _ensure_actor_profile(
			member,
			{
				"source": str(
					context.get(
						"source",
						"rebalance_tribe_roles"
					)
				)
			}
		)
		var previous_role_id: String = str(
			profile.get(
				"primary_role_id",
				""
			)
		)
		var next_role_id: String = _default_role_for_actor(member)

		if int(member.age) >= 45:
			next_role_id = "elder"
		elif int(member.age) >= 12:
			next_role_id = str(
				adult_cycle [
					adult_index % adult_cycle.size()
				]
			)
			adult_index += 1

		profile ["primary_role_id"] = next_role_id
		profile ["role_ids"] = [next_role_id]

		if _birth_giver_is_eligible(member):
			profile ["role_ids"].append("birth_giver")

		if previous_role_id != next_role_id:
			changed_actor_ids.append(int(member.id))

		_store_profile(profile)

	_elect_tribe_leader(tribe)
	var elected_leader_id: int = int(
		tribe.get(
			"leader_actor_id",
			-1
		)
	)

	if elected_leader_id <= 0:
		var best_age: int = -1

		for raw_member in members:
			var candidate:= raw_member as Person

			if candidate == null or int(candidate.age) < 18:
				continue

			if (
				int(candidate.age) > best_age
				or (
					int(candidate.age) == best_age
					and (
						elected_leader_id <= 0
						or int(candidate.id) < elected_leader_id
					)
				)
			):
				elected_leader_id = int(candidate.id)
				best_age = int(candidate.age)

		tribe ["leader_actor_id"] = elected_leader_id

	if elected_leader_id > 0:
		var leader_profile: Dictionary = _dict(
			_dict(
				state.get(
					"actor_profiles",
					{}
				)
			).get(
				str(elected_leader_id),
				{}
			)
		)
		leader_profile ["primary_role_id"] = "tribe_leader"
		leader_profile ["role_ids"] = ["tribe_leader"]
		_store_profile(leader_profile)

	_recalculate_tribe_metrics(tribe)
	_store_tribe(tribe)

	return {
		"success": true,
		"schema": "eralife.caveman_role_balance_contract",
		"version": 1,
		"tribe_id": tribe_id,
		"member_count": members.size(),
		"changed_actor_ids": changed_actor_ids,
		"leader_actor_id": elected_leader_id,
		"manual_action_label": "Reassign Role",
		"ui_is_renderer_only": true
	}

func _ensure_tribe_for_actor(
		actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	if state.is_empty():
		state = _default_state()

	var tribe_id: String = _tribe_id_for_actor(
		actor
	)
	var tribes_raw: Variant = state.get(
		"tribes",
		{}
	)
	var tribes: Dictionary = (
		tribes_raw as Dictionary
		if typeof(tribes_raw) == TYPE_DICTIONARY
		else {}
	)
	var tribe: Dictionary = {}
	var tribe_raw: Variant = tribes.get(
		tribe_id,
		{}
	)

	if typeof(tribe_raw) == TYPE_DICTIONARY:
		tribe = (
			(tribe_raw as Dictionary).duplicate(true)
		)

	if tribe.is_empty():
		tribe = _default_tribe(
			tribe_id,
			_tribe_name_for_actor(actor)
		)

	tribe ["territory_name"] = (
		_territory_name_for_actor(actor)
	)
	tribes [tribe_id] = tribe
	state ["tribes"] = tribes

	return tribe

func _default_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": ENGINE_VERSION,
		"bundle_id": BUNDLE_ID,
		"root_mod_id": ROOT_MOD_ID,
		"experience_id": EXPERIENCE_ID,
		"enabled": false,
		"selected_component_ids": [],
		"active_component_ids": [],
		"actor_profiles": {},
		"tribes": {},
		"actor_tribe_index": {},
		"surface_initialized_actor_ids": {},
		"reality_surface_cache": {},
		"transition_revision": 0,
		"settings": DEFAULT_SETTINGS.duplicate(true),
		"activity_history": [],
		"last_year_processed": -999999,
		"revision": 0,
		"last_enabled_at_ms": 0,
		"last_disabled_at_ms": 0,
		"last_repaired_at_ms": 0,
		"last_transition_source": ""
	}


func _ensure_state_shape() -> Dictionary:
	if state.is_empty():
		var mirrored: Dictionary = {}

		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			mirrored = _dict(
				gs.scenario_state.get(
					STATE_KEY,
					{}
				)
			)

		state = (
			mirrored
			if not mirrored.is_empty()
			else _default_state()
		)

	state ["schema"] = STATE_SCHEMA
	state ["version"] = ENGINE_VERSION
	state ["bundle_id"] = BUNDLE_ID
	state ["root_mod_id"] = ROOT_MOD_ID
	state ["experience_id"] = EXPERIENCE_ID
	state ["enabled"] = bool(
		state.get(
			"enabled",
			false
		)
	)
	state ["selected_component_ids"] = (
		_normalize_component_ids(
			_array(
				state.get(
					"selected_component_ids",
					[]
				)
			)
		)
	)
	state ["active_component_ids"] = (
		_normalize_component_ids(
			_array(
				state.get(
					"active_component_ids",
					[]
				)
			)
		)
	)
	state ["actor_profiles"] = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	state ["surface_initialized_actor_ids"] = _dict(
		state.get(
			"surface_initialized_actor_ids",
			{}
		)
	)
	state ["reality_surface_cache"] = _dict(
		state.get(
			"reality_surface_cache",
			{}
		)
	)
	state ["transition_revision"] = maxi(
		0,
		int(state.get("transition_revision", 0))
	)
	state ["tribes"] = _dict(
		state.get(
			"tribes",
			{}
		)
	)
	state ["actor_tribe_index"] = _dict(
		state.get(
			"actor_tribe_index",
			{}
		)
	)
	state ["settings"] = _normalized_settings(
		_dict(
			state.get(
				"settings",
				DEFAULT_SETTINGS
			)
		)
	)
	state ["activity_history"] = _array(
		state.get(
			"activity_history",
			[]
		)
	)
	state ["last_year_processed"] = int(
		state.get(
			"last_year_processed",
			-999999
		)
	)
	state ["revision"] = maxi(
		0,
		int(
			state.get(
				"revision",
				0
			)
		)
	)

	return state


func _publish_state() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = (
		state.duplicate(true)
	)


func _default_tribe(
	tribe_id: String,
	tribe_name: String
) -> Dictionary:
	return {
		"tribe_id": tribe_id,
		"name": tribe_name,
		"territory_name": "Unknown Territory",
		"member_ids": [],
		"departed_member_ids": [],
		"leader_actor_id": -1,
		"council_member_ids": [],
		"resources": _default_resources(),
		"contribution_by_actor": {},
		"cave_name": "Unresolved Cave",
		"origin_year": _current_year(),
		"fire_count_epoch": 1,
		"discovered_territories": [],
		"tool_count": 0,
		"food_security": 50,
		"warmth": 50,
		"shelter": 40,
		"danger": 35,
		"survival_status": "stable",
		"history": [],
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"last_year_tick": -999999
	}


func _default_resources() -> Dictionary:
	var resources: Dictionary = {}

	for raw_resource in _array(
		_economy_contract().get(
			"resources",
			[]
		)
	):
		var resource: Dictionary = _dict(raw_resource)
		var resource_id: String = str(
			resource.get(
				"id",
				""
			)
		)

		if resource_id == "":
			continue

		resources [resource_id] = maxi(
			0,
			int(
				resource.get(
					"starting_amount",
					0
				)
			)
		)

	return resources



func _normalize_resources(
	resources: Dictionary
) -> Dictionary:
	var out: Dictionary = _default_resources()

	for raw_resource_id in resources.keys():
		out [str(raw_resource_id)] = maxi(
			0,
			int(
				resources.get(
					raw_resource_id,
					0
				)
			)
		)

	return out


func _normalized_settings(
	settings: Dictionary
) -> Dictionary:
	return {
		"survival_intensity": clampi(
			int(
				settings.get(
					"survival_intensity",
					3
				)
			),
			1,
			5
		),
		"megafauna_frequency": str(
			settings.get(
				"megafauna_frequency",
				"Balanced"
			)
		),
		"unlock_survival_all_ages": bool(
			settings.get(
				"unlock_survival_all_ages",
				false
			)
		)
	}
func _normalize_component_ids(
	component_ids: Array
) -> Array:
	var requested: Dictionary = {}
	var out: Array = []

	for raw_component_id in component_ids:
		requested [
			_slug(
				str(raw_component_id)
			)
		] = true

	for raw_component_id in (
		CavemanRealityBundlePack.component_order()
	):
		var component_id: String = _slug(
			str(raw_component_id)
		)

		if requested.has(component_id):
			out.append(component_id)

	return out


func _component_active(
	component_id: String
) -> bool:
	return (
		bool(
			state.get(
				"enabled",
				false
			)
		)
		and _slug(component_id) in _array(
			state.get(
				"active_component_ids",
				[]
			)
		)
	)


func _provider_contract(
	provider_type: String
) -> Dictionary:
	var selected: Array = _array(
		state.get(
			"selected_component_ids",
			CavemanRealityBundlePack.component_order()
		)
	)

	if selected.is_empty():
		selected = (
			CavemanRealityBundlePack.component_order()
		)

	var mod_contract: Dictionary = (
		CavemanRealityBundlePack
		.assembled_mod_contract(selected)
	)

	for raw_provider in _array(
		mod_contract.get(
			"providers",
			[]
		)
	):
		var provider: Dictionary = _dict(
			raw_provider
		)

		if str(
			provider.get(
				"provider_type",
				""
			)
		) == provider_type:
			return provider

	return {}


func _role_contracts() -> Array:
	return _array(
		_provider_contract(
			"roles"
		).get(
			"rows",
			[]
		)
	)


func _role_contract(
	role_id: String
) -> Dictionary:
	var clean_id: String = _slug(
		role_id
	)

	for raw_role in _role_contracts():
		var role: Dictionary = _dict(
			raw_role
		)

		if _slug(
			str(
				role.get(
					"id",
					""
				)
			)
		) == clean_id:
			return role

	return {}


func _economy_contract() -> Dictionary:
	var rows: Array = _array(
		_provider_contract(
			"economy_modes"
		).get(
			"rows",
			[]
		)
	)

	return (
		{}
		if rows.is_empty()
		else _dict(rows [0])
	)


func _resource_contract(
	resource_id: String
) -> Dictionary:
	for raw_resource in _array(
		_economy_contract().get(
			"resources",
			[]
		)
	):
		var resource: Dictionary = _dict(
			raw_resource
		)

		if str(
			resource.get(
				"id",
				""
			)
		) == resource_id:
			return resource

	return {
		"id": resource_id,
		"label": resource_id.capitalize(),
		"minimum": 0
	}


func _role_eligibility(
	actor: Person,
	role_contract: Dictionary,
	profile: Dictionary,
	tribe: Dictionary,
	ignore_capacity: bool = false
) -> Dictionary:
	var role_id: String = str(
		role_contract.get(
			"id",
			""
		)
	)
	var minimum_age: int = int(
		role_contract.get(
			"minimum_age",
			0
		)
	)
	var maximum_age: int = int(
		role_contract.get(
			"maximum_age",
			130
		)
	)
	var age_valid: bool = (
		int(actor.age) >= minimum_age
		and int(actor.age) <= maximum_age
	)

	if not age_valid:
		return {
			"eligible": false,
			"age_valid": false,
			"reason": (
				"This role requires an age "
				+ "between %d and %d."
			) % [
				minimum_age,
				maximum_age
			]
		}

	var sex_requirement: String = str(
		role_contract.get(
			"sex_requirement",
			""
		)
	).strip_edges().to_lower()

	if (
		sex_requirement != ""
		and sex_requirement != _gender_key(actor)
	):
		return {
			"eligible": false,
			"age_valid": true,
			"reason": (
				"This role's biological eligibility "
				+ "contract is not satisfied."
			)
		}

	var minimum_contribution: int = int(
		role_contract.get(
			"minimum_survival_contribution",
			0
		)
	)

	if int(
		profile.get(
			"survival_contribution",
			0
		)
	) < minimum_contribution:
		return {
			"eligible": false,
			"age_valid": true,
			"reason": (
				"This role requires at least %d "
				+ "survival contribution."
			) % minimum_contribution
		}

	var maximum_per_tribe: int = int(
		role_contract.get(
			"maximum_per_tribe",
			0
		)
	)

	if (
		not ignore_capacity
		and maximum_per_tribe > 0
		and _role_count_in_tribe(
			role_id,
			tribe,
			int(actor.id)
		) >= maximum_per_tribe
	):
		return {
			"eligible": false,
			"age_valid": true,
			"reason": (
				"The tribe already has the maximum "
				+ "number of people in this role."
			)
		}

	if role_id == "tribe_leader":
		var current_leader_id: int = int(
			tribe.get(
				"leader_actor_id",
				-1
			)
		)

		if current_leader_id not in [
			-1,
			int(actor.id)
		]:
			return {
				"eligible": false,
				"age_valid": true,
				"reason": (
					"This tribe already has "
					+ "a living leader."
				)
			}

	return {
		"eligible": true,
		"age_valid": true,
		"reason": ""
	}


func _role_count_in_tribe(
	role_id: String,
	tribe: Dictionary,
	excluding_actor_id: int = -1
) -> int:
	var count: int = 0
	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)

	for actor_id in _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	):
		if actor_id == excluding_actor_id:
			continue

		var actor: Person = _person_by_id(
			actor_id
		)

		if (
			actor != null
			and not bool(actor.alive)
		):
			continue

		if role_id in _array(
			_dict(
				profiles.get(
					str(actor_id),
					{}
				)
			).get(
				"role_ids",
				[]
			)
		):
			count += 1

	return count


func _default_role_for_actor(
	actor: Person
) -> String:
	var age: int = int(actor.age)

	if age <= 2:
		return "infant"

	if age <= 11:
		return "child"

	var choices: Array = [
		"hunter",
		"gatherer",
		"tool_maker",
		"fire_keeper",
		"scout"
	]

	return str(
		choices [
			abs(
				int(actor.id)
			) % choices.size()
		]
	)


func _birth_giver_is_eligible(
	actor: Person
) -> bool:
	return (
		int(actor.age) >= 16
		and int(actor.age) <= 55
		and _gender_key(actor) == "female"
	)


func _elect_tribe_leader(
	tribe: Dictionary
) -> void:


	if not _component_active("governance"):
		return

	var current_leader_id: int = int(
		tribe.get(
			"leader_actor_id",
			-1
		)
	)
	var current_leader: Person = _person_by_id(
		current_leader_id
	)

	if (
		current_leader != null
		and bool(current_leader.alive)
	):
		return

	var contributions: Dictionary = _dict(
		tribe.get(
			"contribution_by_actor",
			{}
		)
	)
	var best_actor_id: int = -1
	var best_score: int = -1

	for actor_id in _int_array(
		tribe.get(
			"member_ids",
			[]
		)
	):
		var actor: Person = _person_by_id(
			actor_id
		)

		if (
			actor == null
			or not bool(actor.alive)
			or int(actor.age) < 18
		):
			continue

		var score: int = int(
			contributions.get(
				str(actor_id),
				0
			)
		)

		if score < 60:
			continue

		if (
			score > best_score
			or (
				score == best_score
				and (
					best_actor_id < 0
					or actor_id < best_actor_id
				)
			)
		):
			best_actor_id = actor_id
			best_score = score

	tribe ["leader_actor_id"] = best_actor_id

	if best_actor_id <= 0:
		return

	var profiles: Dictionary = _dict(
		state.get(
			"actor_profiles",
			{}
		)
	)
	var profile: Dictionary = _dict(
		profiles.get(
			str(best_actor_id),
			{}
		)
	)
	var role_ids: Array = _array(
		profile.get(
			"role_ids",
			[]
		)
	)

	if "tribe_leader" not in role_ids:
		role_ids.append("tribe_leader")

	profile ["role_ids"] = role_ids
	profile ["primary_role_id"] = "tribe_leader"
	profiles [str(best_actor_id)] = profile
	state ["actor_profiles"] = profiles


func _recalculate_tribe_metrics(
	tribe: Dictionary
) -> void:
	var resources: Dictionary = _dict(
		tribe.get(
			"resources",
			{}
		)
	)
	var member_count: int = maxi(
		1,
		_int_array(
			tribe.get(
				"member_ids",
				[]
			)
		).size()
	)
	var food_security: int = clampi(
		int(
			float(
				int(
					resources.get(
						"food",
						0
					)
				)
			) / float(member_count) * 12.0
		),
		0,
		100
	)
	var warmth: int = clampi(
		int(
			resources.get(
				"fire",
				0
			)
		) * 45
		+ int(
			resources.get(
				"wood",
				0
			)
		) * 2,
		0,
		100
	)
	var shelter: int = clampi(
		35
		+ int(
			resources.get(
				"hide",
				0
			)
		) * 3
		+ int(
			tribe.get(
				"tool_count",
				0
			)
		) * 4,
		0,
		100
	)
	var danger: int = clampi(
		55
		- _array(
			tribe.get(
				"discovered_territories",
				[]
			)
		).size() * 4
		- int(
			tribe.get(
				"tool_count",
				0
			)
		) * 3,
		5,
		95
	)
	var survival_score: int = int(
		float(
			food_security
			+ warmth
			+ shelter
			+ (
				100 - danger
			)
		) / 4.0
	)
	var survival_status: String = "critical"

	if survival_score >= 75:
		survival_status = "thriving"
	elif survival_score >= 55:
		survival_status = "stable"
	elif survival_score >= 35:
		survival_status = "strained"

	tribe ["food_security"] = food_security
	tribe ["warmth"] = warmth
	tribe ["shelter"] = shelter
	tribe ["danger"] = danger
	tribe ["survival_score"] = survival_score
	tribe ["survival_status"] = survival_status

func _apply_resource_deltas(
	tribe: Dictionary,
	deltas: Dictionary
) -> void:
	var resources: Dictionary = _normalize_resources(
		_dict(
			tribe.get(
				"resources",
				{}
			)
		)
	)

	for raw_resource_id in deltas.keys():
		var resource_id: String = str(
			raw_resource_id
		)
		resources [resource_id] = maxi(
			0,
			int(
				resources.get(
					resource_id,
					0
				)
			) + int(
				deltas.get(
					raw_resource_id,
					0
				)
			)
		)

	tribe ["resources"] = resources


func _store_profile(
		profile: Dictionary
) -> void:
	var actor_id: int = int(
		profile.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return

	var profiles_raw: Variant = state.get(
		"actor_profiles",
		{}
	)
	var profiles: Dictionary = (
		profiles_raw as Dictionary
		if typeof(profiles_raw) == TYPE_DICTIONARY
		else {}
	)

	profiles [str(actor_id)] = (
		profile.duplicate(true)
	)
	state ["actor_profiles"] = profiles

func _store_tribe(
		tribe: Dictionary
) -> void:
	var tribe_id: String = str(
		tribe.get(
			"tribe_id",
			""
		)
	)

	if tribe_id == "":
		return

	var tribes_raw: Variant = state.get(
		"tribes",
		{}
	)
	var tribes: Dictionary = (
		tribes_raw as Dictionary
		if typeof(tribes_raw) == TYPE_DICTIONARY
		else {}
	)

	tribes [tribe_id] = (
		tribe.duplicate(true)
	)
	state ["tribes"] = tribes


func _tribe(
		tribe_id: String
) -> Dictionary:
	var tribes_raw: Variant = state.get(
		"tribes",
		{}
	)

	if typeof(tribes_raw) != TYPE_DICTIONARY:
		return {}

	var tribe_raw: Variant = (
		(tribes_raw as Dictionary).get(
			tribe_id,
			{}
		)
	)

	if typeof(tribe_raw) != TYPE_DICTIONARY:
		return {}

	return (
		(tribe_raw as Dictionary).duplicate(true)
	)

func _append_activity_history(
	row: Dictionary
) -> void:
	var history: Array = _array(
		state.get(
			"activity_history",
			[]
		)
	)
	history.append(
		row.duplicate(true)
	)

	while history.size() > MAX_ACTIVITY_HISTORY:
		history.pop_front()

	state ["activity_history"] = history


func _append_tribe_history(
	tribe_id: String,
	row: Dictionary
) -> void:
	var tribe: Dictionary = _tribe(
		tribe_id
	)

	if tribe.is_empty():
		return

	var history: Array = _array(
		tribe.get(
			"history",
			[]
		)
	)
	history.append(
		row.duplicate(true)
	)

	while history.size() > MAX_TRIBE_HISTORY:
		history.pop_front()

	tribe ["history"] = history
	_store_tribe(tribe)


func _identity_overview(
	actor: Person,
	profile: Dictionary,
	tribe: Dictionary
) -> Dictionary:
	var installed_mod_count: int = 0
	var enabled_mod_count: int = 0
	var provider_count: int = 0
	var conflict_count: int = 0

	if (
		gs != null
		and gs.mod_contract_engine != null
	):
		installed_mod_count = _dict(
			gs.mod_contract_engine.mod_registry
		).size()
		enabled_mod_count = _dict(
			gs.mod_contract_engine.enabled_mod_ids
		).size()
		provider_count = _dict(
			gs.mod_contract_engine.provider_registry
		).size()
		conflict_count = _dict(
			gs.mod_contract_engine
			.provider_conflict_registry
		).size()

	return {
		"actor_id": int(actor.id),
		"actor_name": _actor_name(actor),
		"installed_mod_count": installed_mod_count,
		"enabled_mod_count": enabled_mod_count,
		"provider_count": provider_count,
		"conflict_count": conflict_count,
		"tribe_id": str(
			profile.get(
				"tribe_id",
				""
			)
		),
		"tribe_name": str(
			tribe.get(
				"name",
				"Unresolved Tribe"
			)
		),
		"primary_role_id": str(
			profile.get(
				"primary_role_id",
				""
			)
		),
		"survival_contribution": int(
			profile.get(
				"survival_contribution",
				0
			)
		)
	}


func _base_bundle_menu_contract() -> Dictionary:
	return _dict(
		CavemanRealityBundlePack
		.bundle_contract()
		.get(
			"bundle_menu_contract",
			{}
		)
	)


func _role_assignment_action(
	role_id: String,
	enabled: bool
) -> Dictionary:
	return {
		"action_id": "provider_intent",
		"label": "Assign Role",
		"canonical_provider_key": (
			ROOT_MOD_ID
			+ "::caveman.roles"
		),
		"provider_action_id": "assign_role",
		"namespaced_action_id": (
			ROOT_MOD_ID
			+ "::caveman.roles::assign_role"
		),
		"role_id": role_id,
		"bundle_id": BUNDLE_ID,
		"enabled": enabled
	}


func _activity_provider_action(
	activity_id: String,
	enabled: bool
) -> Dictionary:
	return {
		"action_id": "provider_intent",
		"label": _activity_label(activity_id),
		"canonical_provider_key": (
			ROOT_MOD_ID
			+ "::caveman.activities"
		),
		"provider_action_id": activity_id,
		"namespaced_action_id": (
			ROOT_MOD_ID
			+ "::caveman.activities::"
			+ activity_id
		),
		"bundle_id": BUNDLE_ID,
		"enabled": enabled
	}


func _component_unavailable_row(
	component_id: String,
	component_name: String
) -> Dictionary:
	return {
		"row_kind": "bundle_component_unavailable",
		"id": (
			"component_unavailable_%s"
			% component_id
		),
		"title": component_name,
		"subtitle": "COMPONENT NOT ACTIVE",
		"description": (
			"This section is preserved, but its "
			+ "provider component is not active "
			+ "in the bundle topology."
		),
		"chips": [
			"Safe Fallback",
			"No Runtime Failure"
		],
		"enabled": false,
		"actions": []
	}


func _activity_id_from_payload(
	payload: Dictionary
) -> String:
	var activity_id: String = _slug(
		str(
			payload.get(
				"provider_action_id",
				payload.get(
					"activity_id",
					""
				)
			)
		)
	)

	if activity_id != "":
		return activity_id

	var parts:= str(
		payload.get(
			"namespaced_action_id",
			""
		)
	).split(
		"::",
		false
	)

	if parts.size() >= 3:
		return _slug(
			parts [2]
		)

	return _slug(
		str(
			payload.get(
				"action_label",
				""
			)
		)
	)


func _activity_label(
	activity_id: String
) -> String:
	return str(
		{
			"hunt_herd": "Hunt Herd",
			"gather_roots_berries": (
				"Gather Roots and Berries"
			),
			"craft_stone_tools": (
				"Craft Stone Tools"
			),
			"start_fire": "Start Fire",
			"explore_territory": (
				"Explore Territory"
			)
		}.get(
			activity_id,
			activity_id.capitalize()
		)
	)


func _activity_description(
	activity_id: String
) -> String:
	return str(
		{
			"hunt_herd": (
				"Track prey and return with "
				+ "food, hide, and bone."
			),
			"gather_roots_berries": (
				"Search nearby territory for "
				+ "edible plants and wood."
			),
			"craft_stone_tools": (
				"Convert stone and wood into "
				+ "reusable survival tools."
			),
			"start_fire": (
				"Consume wood to restore warmth "
				+ "and protection."
			),
			"explore_territory": (
				"Reveal territory, resources, "
				+ "and safer movement routes."
			)
		}.get(
			activity_id,
			"A Caveman survival activity."
		)
	)


func _activity_contribution_preview(
	activity_id: String
) -> int:
	return int(
		{
			"hunt_herd": 12,
			"gather_roots_berries": 8,
			"craft_stone_tools": 10,
			"start_fire": 7,
			"explore_territory": 9
		}.get(
			activity_id,
			0
		)
	)


func _role_description(
	role_id: String
) -> String:
	return str(
		{
			"infant": (
				"A newborn life protected by the tribe."
			),
			"child": (
				"A young tribe member learning "
				+ "survival through observation."
			),
			"hunter": (
				"Tracks prey and contributes "
				+ "food, hide, and bone."
			),
			"gatherer": (
				"Finds edible plants, wood, "
				+ "and everyday materials."
			),
			"tool_maker": (
				"Turns stone, wood, and bone "
				+ "into survival technology."
			),
			"fire_keeper": (
				"Maintains warmth, light, "
				+ "cooking, and protection."
			),
			"scout": (
				"Explores territory and identifies "
				+ "threats and resources."
			),
			"shaman": (
				"A limited spiritual and cultural "
				+ "authority within the tribe."
			),
			"elder": (
				"A limited council role carrying "
				+ "memory and legitimacy."
			),
			"birth_giver": (
				"An eligible adult reproductive "
				+ "and caregiving role."
			),
			"tribe_leader": (
				"The tribe's singular "
				+ "contribution-gated authority."
			)
		}.get(
			role_id,
			"A contribution role within the tribe."
		)
	)


func _resource_description(
	resource_id: String
) -> String:
	return str(
		{
			"food": (
				"Shared calories that determine "
				+ "immediate food security."
			),
			"wood": (
				"Fuel, shelter material, handles, "
				+ "and construction stock."
			),
			"stone": (
				"The foundation of tools, "
				+ "cutting edges, and defenses."
			),
			"hide": (
				"Protection, bedding, clothing, "
				+ "and shelter material."
			),
			"bone": (
				"Needles, hooks, tools, weapons, "
				+ "and ritual material."
			),
			"fire": (
				"The tribe's active warmth, light, "
				+ "cooking, and protection."
			)
		}.get(
			resource_id,
			"A shared Caveman survival resource."
		)
	)


func _resource_condition_label(
	resource_id: String,
	amount: int
) -> String:
	var threshold: int = (
		15
		if resource_id in [
			"food",
			"wood",
			"stone"
		]
		else 5
	)

	if amount <= 0:
		return "Depleted"

	if amount < threshold:
		return "Low"

	return "Stable"


func _tribe_id_for_actor(
	actor: Person
) -> String:
	var root_id: int = _lineage_root_id(actor)

	return "tribe_%d_%d" % [
		root_id,
		abs(int(hash("caveman_tribe:%d" % root_id))) % 997
	]


func _tribe_name_for_actor(
	actor: Person
) -> String:
	var root_id: int = _lineage_root_id(actor)
	var prefix: String = str(
		TRIBE_NAME_PREFIXES [
			abs(int(hash("tribe_prefix:%d" % root_id)))
			% TRIBE_NAME_PREFIXES.size()
		]
	)
	var suffix: String = str(
		TRIBE_NAME_SUFFIXES [
			abs(int(hash("tribe_suffix:%d" % root_id)))
			% TRIBE_NAME_SUFFIXES.size()
		]
	)

	return "The %s%s Tribe" % [
		prefix,
		suffix
	]


func _territory_name_for_actor(
	actor: Person
) -> String:
	return _cave_name_for_actor(actor)


func _cave_name_for_actor(
	actor: Person
) -> String:
	var root_id: int = _lineage_root_id(actor)
	var prefix: String = str(
		CAVE_NAME_PREFIXES [
			abs(int(hash("cave_prefix:%d" % root_id)))
			% CAVE_NAME_PREFIXES.size()
		]
	)
	var suffix: String = str(
		CAVE_NAME_SUFFIXES [
			abs(int(hash("cave_suffix:%d" % root_id)))
			% CAVE_NAME_SUFFIXES.size()
		]
	)

	return "%s %s" % [
		prefix,
		suffix
	]


func _lineage_root_id(
	actor: Person
) -> int:
	if actor == null:
		return 1

	var root_id: int = maxi(1, int(actor.id))
	var frontier: Array = _int_array(actor.parents)
	var visited: Dictionary = {}
	var depth: int = 0

	while not frontier.is_empty() and depth < 4:
		var next_frontier: Array = []

		for raw_parent_id in frontier:
			var parent_id: int = int(raw_parent_id)

			if parent_id <= 0 or visited.has(parent_id):
				continue

			visited [parent_id] = true
			root_id = mini(root_id, parent_id)

			var parent: Person = _person_by_id(parent_id)

			if parent != null:
				next_frontier.append_array(
					_int_array(parent.parents)
				)

		frontier = next_frontier
		depth += 1

	return root_id


func _person_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(gs.player.id) == actor_id
	):
		return gs.player

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(
			actor_id
		)

	return null


func _person_from_payload(
	payload
) -> Person:
	if payload is Person:
		return payload as Person

	if typeof(payload) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = payload as Dictionary

	for key in [
		"actor",
		"person",
		"npc"
	]:
		var candidate = data.get(
			key,
			null
		)

		if candidate is Person:
			return candidate as Person

	for key in [
		"actor_id",
		"person_id",
		"npc_id",
		"id"
	]:
		var actor: Person = _person_by_id(
			int(
				data.get(
					key,
					-1
				)
			)
		)

		if actor != null:
			return actor

	for nested_key in [
		"payload",
		"data",
		"event_payload",
		"context"
	]:
		var nested = data.get(
			nested_key,
			null
		)

		if typeof(nested) != TYPE_DICTIONARY:
			continue

		var nested_actor: Person = (
			_person_from_payload(nested)
		)

		if nested_actor != null:
			return nested_actor

	return null


func _actor_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Tribe Member"

	var full_name: String = "%s %s" % [
		str(
			actor.first_name
		).strip_edges(),
		str(
			actor.last_name
		).strip_edges()
	]
	full_name = full_name.strip_edges()

	return (
		full_name
		if full_name != ""
		else "Unnamed Tribe Member"
	)


func _gender_key(
	actor: Person
) -> String:
	var value: String = str(
		actor.gender
	).strip_edges().to_lower()

	if value in [
		"female",
		"woman",
		"girl"
	]:
		return "female"

	if value in [
		"male",
		"man",
		"boy"
	]:
		return "male"

	return value


func _current_year() -> int:
	return int(
		gs.year
		if gs != null
		else 0
	)


func _emit_runtime_event(
	event_id: String,
	payload: Dictionary
) -> void:
	if (
		gs == null
		or gs.event_bus == null
		or not gs.event_bus.has_method("emit")
	):
		return

	var event_payload: Dictionary = (
		payload.duplicate(true)
	)
	event_payload ["bundle_id"] = BUNDLE_ID
	event_payload ["experience_id"] = EXPERIENCE_ID
	event_payload ["source_engine"] = ENGINE_SCHEMA

	gs.event_bus.emit(
		event_id,
		event_payload
	)


func _bump_revision() -> void:
	state ["revision"] = int(
		state.get(
			"revision",
			0
		)
	) + 1


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
		"\\"
	]:
		clean = clean.replace(
			token,
			"_"
		)

	while clean.contains("__"):
		clean = clean.replace(
			"__",
			"_"
		)

	return clean


func _string_array(
	value: Variant
) -> Array:
	var out: Array = []

	if typeof(value) != TYPE_ARRAY:
		return out

	for raw_value in value as Array:
		var clean: String = _slug(
			str(raw_value)
		)

		if (
			clean != ""
			and clean not in out
		):
			out.append(clean)

	return out


func _int_array(
	value: Variant
) -> Array:
	var out: Array = []

	if typeof(value) != TYPE_ARRAY:
		return out

	for raw_value in value as Array:
		var clean: int = int(raw_value)

		if (
			clean > 0
			and clean not in out
		):
			out.append(clean)

	return out


func _dict(
	value: Variant
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value: Variant
) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
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
		"bundle_id": BUNDLE_ID,
		"ui_is_renderer_only": true
	}