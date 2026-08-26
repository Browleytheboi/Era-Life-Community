extends Resource
class_name StickFighterMiniGameProvider

const PROVIDER_ID:= "stick_fighter"
const PROVIDER_REVISION:= "3.0.0"
const MAX_HEALTH:= 100
const MAX_STAMINA:= 100
const WIN_ROUNDS:= 2
const MAX_FIGHTERS:= 4

const COUNTDOWN_SECONDS:= 5
const COUNTDOWN_DROP_TRIGGER:= 1
const COUNTDOWN_LIVE_HANDOFF_SECONDS:= 1.0

const MAX_WEAPON_DROPS:= 8
const MAX_PROJECTILES:= 48
const MAX_COMBAT_EFFECTS:= 64

const MAX_JUMPS_PER_AIR_CYCLE:= 2



const STOCK_LIVES_PER_ROUND:= 3
const STOCK_RESPAWN_DELAY_STEPS:= 42
const STOCK_RESPAWN_PROTECTION_STEPS:= 90

const MAP_SIZE_CONTRACTS:= [
	{
		"map_size_id": "compact",
		"title": "COMPACT",
		"description": (
			"Tighter spacing, wider footing, and faster close-range pressure."
		),
		"platform_spacing_scale": 0.82,
		"platform_width_scale": 1.16,
		"vertical_spacing_scale": 0.88
	},
	{
		"map_size_id": "standard",
		"title": "STANDARD",
		"description": (
			"The authored arena geometry at its normal combat scale."
		),
		"platform_spacing_scale": 1.0,
		"platform_width_scale": 1.0,
		"vertical_spacing_scale": 1.0
	},
	{
		"map_size_id": "large",
		"title": "LARGE",
		"description": (
			"Wider gaps, narrower footing, and more room for ranged weapons."
		),
		"platform_spacing_scale": 1.12,
		"platform_width_scale": 0.82,
		"vertical_spacing_scale": 1.08
	}
]
const AI_DIFFICULTY_CONTRACTS:= [
	{
		"ai_difficulty_id": "easy",
		"title": "EASY",
		"description": (
			"Slower reactions, longer attack spacing, and more defensive hesitation."
		),
		"attack_interval_steps": 58,
		"weapon_attack_chance": 28,
		"special_attack_chance": 45,
		"kick_chance": 24,
		"punch_chance": 58,
		"block_chance": 48,
		"pickup_chance": 45,
		"engage_distance": 48.0
	},
	{
		"ai_difficulty_id": "normal",
		"title": "NORMAL",
		"description": (
			"Balanced reactions, spacing, blocking, weapon use, and aggression."
		),
		"attack_interval_steps": 46,
		"weapon_attack_chance": 42,
		"special_attack_chance": 65,
		"kick_chance": 36,
		"punch_chance": 72,
		"block_chance": 54,
		"pickup_chance": 65,
		"engage_distance": 44.0
	},
	{
		"ai_difficulty_id": "hard",
		"title": "HARD",
		"description": (
			"Stronger positioning and weapon pressure without attack spam."
		),
		"attack_interval_steps": 36,
		"weapon_attack_chance": 56,
		"special_attack_chance": 80,
		"kick_chance": 46,
		"punch_chance": 82,
		"block_chance": 60,
		"pickup_chance": 80,
		"engage_distance": 41.0
	},
	{
		"ai_difficulty_id": "extra_hard",
		"title": "EXTRA HARD",
		"description": (
			"Fast tactical decisions and strong weapon awareness, "
			+ "but every offensive commitment still has enforced recovery."
		),
		"attack_interval_steps": 30,
		"weapon_attack_chance": 66,
		"special_attack_chance": 90,
		"kick_chance": 52,
		"punch_chance": 88,
		"block_chance": 64,
		"pickup_chance": 92,
		"engage_distance": 38.0
	}
]


func _ai_difficulty_contracts() -> Array:
	return AI_DIFFICULTY_CONTRACTS.duplicate(true)


func _ai_difficulty_contract_from_id(
	ai_difficulty_id: String
) -> Dictionary:
	var clean_id: String = _id(
		ai_difficulty_id
	)

	for raw_contract in AI_DIFFICULTY_CONTRACTS:
		var contract: Dictionary = _dict(
			raw_contract
		)

		if _id(
			str(
				contract.get(
					"ai_difficulty_id",
					""
				)
			)
		) == clean_id:
			return contract.duplicate(true)

	return _dict(
		AI_DIFFICULTY_CONTRACTS [
			1
		]
	).duplicate(true)


func _ai_difficulty_contract(
	state: Dictionary
) -> Dictionary:
	return _ai_difficulty_contract_from_id(
		str(
			state.get(
				"ai_difficulty_id",
				"normal"
			)
		)
	)


func _ai_attack_ready(
	state: Dictionary,
	identity_key: String
) -> bool:
	var locks: Dictionary = _dict(
		state.get(
			"ai_attack_lock_by_identity",
			{}
		)
	)

	return int(
		state.get(
			"simulation_step",
			0
		)
	) >= int(
		locks.get(
			identity_key,
			0
		)
	)


func _commit_ai_attack_lock(
	state: Dictionary,
	identity_key: String,
	difficulty: Dictionary
) -> void:
	var locks: Dictionary = _dict(
		state.get(
			"ai_attack_lock_by_identity",
			{}
		)
	).duplicate(false)

	locks [
		identity_key
	] = int(
		state.get(
			"simulation_step",
			0
		)
	) + maxi(
		1,
		int(
			difficulty.get(
				"attack_interval_steps",
				46
			)
		)
	)

	state [
		"ai_attack_lock_by_identity"
	] = locks


func _mark_ai_extension_action(
	state: Dictionary,
	identity_key: String
) -> void:
	var steps: Dictionary = _dict(
		state.get(
			"ai_extension_action_step_by_identity",
			{}
		)
	).duplicate(false)

	steps [
		identity_key
	] = int(
		state.get(
			"simulation_step",
			0
		)
	)

	state [
		"ai_extension_action_step_by_identity"
	] = steps
const WEAPON_CATALOG:= [
	{
		"weapon_id": "baseball_bat",
		"title": "Baseball Bat",
		"kind": "melee",
		"visual_kind": "bat",
		"rarity": "common",
		"drop_weight": 24,
		"stamina_cost": 10,
		"minimum_damage": 10,
		"maximum_damage": 20,
		"range_x": 44.0,
		"range_y": 17.0,
		"minimum_range_x": 0.0,
		"hit_chance": 90,
		"cooldown_steps": 11,
		"knockback_multiplier": 1.7,
		"ammo": -1
	},
	{
		"weapon_id": "sword",
		"title": "Sword",
		"kind": "melee",
		"visual_kind": "sword",
		"rarity": "common",
		"drop_weight": 20,
		"stamina_cost": 11,
		"minimum_damage": 13,
		"maximum_damage": 24,
		"range_x": 49.0,
		"range_y": 18.0,
		"minimum_range_x": 0.0,
		"hit_chance": 93,
		"cooldown_steps": 10,
		"knockback_multiplier": 1.08,
		"ammo": -1
	},
	{
		"weapon_id": "hammer",
		"title": "War Hammer",
		"kind": "melee",
		"visual_kind": "hammer",
		"rarity": "uncommon",
		"drop_weight": 12,
		"stamina_cost": 22,
		"minimum_damage": 19,
		"maximum_damage": 35,
		"range_x": 39.0,
		"range_y": 18.0,
		"minimum_range_x": 0.0,
		"hit_chance": 76,
		"cooldown_steps": 28,
		"knockback_multiplier": 2.35,
		"ammo": -1
	},
	{
		"weapon_id": "spear",
		"title": "Spear",
		"kind": "melee",
		"visual_kind": "spear",
		"rarity": "uncommon",
		"drop_weight": 12,
		"stamina_cost": 14,
		"minimum_damage": 14,
		"maximum_damage": 24,
		"range_x": 64.0,
		"range_y": 15.0,
		"minimum_range_x": 15.0,
		"hit_chance": 88,
		"cooldown_steps": 15,
		"knockback_multiplier": 1.18,
		"ammo": -1
	},
	{
		"weapon_id": "shield",
		"title": "Shield",
		"kind": "melee",
		"visual_kind": "shield",
		"rarity": "uncommon",
		"drop_weight": 12,
		"stamina_cost": 12,
		"minimum_damage": 8,
		"maximum_damage": 15,
		"range_x": 34.0,
		"range_y": 18.0,
		"minimum_range_x": 0.0,
		"hit_chance": 94,
		"cooldown_steps": 13,
		"knockback_multiplier": 1.42,
		"guard_damage_scale": 0.14,
		"ammo": -1
	},
	{
		"weapon_id": "bow",
		"title": "Bow",
		"kind": "projectile",
		"visual_kind": "bow",
		"projectile_kind": "arrow",
		"rarity": "uncommon",
		"drop_weight": 9,
		"stamina_cost": 10,
		"minimum_damage": 12,
		"maximum_damage": 20,
		"hit_chance": 100,
		"cooldown_steps": 16,
		"knockback_multiplier": 0.9,
		"projectile_speed": 62.0,
		"projectile_gravity": 6.0,
		"projectile_lifetime_steps": 120,
		"ammo": 8
	},
	{
		"weapon_id": "throwing_knives",
		"title": "Throwing Knives",
		"kind": "projectile",
		"visual_kind": "knife",
		"projectile_kind": "knife",
		"rarity": "uncommon",
		"drop_weight": 8,
		"stamina_cost": 7,
		"minimum_damage": 10,
		"maximum_damage": 17,
		"hit_chance": 100,
		"cooldown_steps": 8,
		"knockback_multiplier": 0.72,
		"projectile_speed": 74.0,
		"projectile_gravity": 2.0,
		"projectile_lifetime_steps": 100,
		"ammo": 6
	},
	{
		"weapon_id": "pistol",
		"title": "Pistol",
		"kind": "projectile",
		"visual_kind": "pistol",
		"projectile_kind": "bullet",
		"rarity": "rare",
		"drop_weight": 6,
		"stamina_cost": 4,
		"minimum_damage": 14,
		"maximum_damage": 23,
		"hit_chance": 100,
		"cooldown_steps": 9,
		"knockback_multiplier": 0.92,
		"projectile_speed": 88.0,
		"projectile_gravity": 0.0,
		"projectile_lifetime_steps": 80,
		"ammo": 10
	},
	{
		"weapon_id": "uzi",
		"title": "Uzi",
		"kind": "projectile",
		"visual_kind": "uzi",
		"projectile_kind": "bullet",
		"rarity": "rare",
		"drop_weight": 4,
		"stamina_cost": 6,
		"minimum_damage": 7,
		"maximum_damage": 12,
		"hit_chance": 100,
		"cooldown_steps": 10,
		"knockback_multiplier": 0.58,
		"projectile_speed": 96.0,
		"projectile_gravity": 0.0,
		"projectile_lifetime_steps": 74,
		"burst_count": 3,
		"ammo": 24
	},
	{
		"weapon_id": "grenade",
		"title": "Grenade",
		"kind": "projectile",
		"visual_kind": "grenade",
		"projectile_kind": "grenade",
		"rarity": "epic",
		"drop_weight": 3,
		"stamina_cost": 8,
		"minimum_damage": 20,
		"maximum_damage": 34,
		"hit_chance": 100,
		"cooldown_steps": 22,
		"knockback_multiplier": 1.65,
		"projectile_speed": 34.0,
		"projectile_gravity": 20.0,
		"projectile_lifetime_steps": 82,
		"explosion_radius": 22.0,
		"ammo": 3
	},
	{
		"weapon_id": "rocket_launcher",
		"title": "Rocket Launcher",
		"kind": "projectile",
		"visual_kind": "rocket_launcher",
		"projectile_kind": "rocket",
		"rarity": "legendary",
		"drop_weight": 1,
		"stamina_cost": 12,
		"minimum_damage": 27,
		"maximum_damage": 42,
		"hit_chance": 100,
		"cooldown_steps": 30,
		"knockback_multiplier": 2.2,
		"projectile_speed": 44.0,
		"projectile_gravity": 0.0,
		"projectile_lifetime_steps": 100,
		"explosion_radius": 26.0,
		"ammo": 2
	}
]


func provider_contract() -> Dictionary:
	var contract: Dictionary = _base_provider_contract()
	contract ["flash_reality_provider"] = (flash_reality_provider_contract())
	return contract


func flash_reality_provider_contract() -> Dictionary:
	return {
		"schema": "eralife.flash_reality_provider_contract",
		"version": 1,
		"provider_id": PROVIDER_ID,
		"title": "Stick Fighter Flash Reality",
		"flash_activity_provider":
		{
			"rows":
			[
				{ "id": "practice_stick_fighting", "label": "Practice Stick Fighting"},
				{ "id": "challenge_relationship", "label": "Challenge a Relationship"},
				{ "id": "enter_stick_tournament", "label": "Enter a Stick Fighter Tournament"}
			]
		},
		"flash_minigame_provider": provider_contract_without_flash_recursion(),
		"flash_npc_provider":
		{
			"controller_modes": ["npc_ai", "relationship_ai"],
			"ai_profiles": ["cautious", "balanced", "aggressive", "chaotic"]
		},
		"flash_item_provider":
		{
			"rows":
			[
				{ "id": "foam_gloves", "title": "Foam Gloves", "cosmetic": true},
				{ "id": "arcade_token", "title": "Arcade Token", "consumable": true}
			]
		},
		"flash_sound_provider":
		{ "events": ["menu_open", "round_start", "hit", "block", "special", "knockout", "victory"]},
		"flash_achievement_provider": { "rows": achievement_definitions()},
		"flash_animation_provider":
		{
			"states":
			[
				"idle",
				"walk",
				"jump",
				"punch",
				"kick",
				"block",
				"special",
				"hurt",
				"knockout",
				"victory"
			]
		},
		"world_adapter":
		{
			"coordinate_mode": "normalized_2d_stage",
			"stage_width": 100,
			"stage_height": 56,
			"collision_mode": "provider_resolved",
			"physics_authority": PROVIDER_ID
		},
		"ui_projection":
		{
			"projection_kind": "stick_fighter_stage",
			"input_actions":
			["move_left", "move_right", "jump", "punch", "kick", "block", "special"],
			"ui_is_renderer_only": true
		}
	}


func provider_contract_without_flash_recursion() -> Dictionary:
	return _base_provider_contract()


func _base_provider_contract() -> Dictionary:
	return {
		"schema": "eralife.minigame_provider_contract",
		"version": 2,
		"provider_id": PROVIDER_ID,
		"provider_revision": PROVIDER_REVISION,
		"title": "Stick Fighter",
		"subtitle": (
			"2D platform stick combat for up to four fighters."
		),
		"description": (
			"Fight CPUs, family, NPCs, local players, or ErAccount friends "
			+ "across persistent multi-platform arenas. Every committed "
			+ "match remains part of EraLife reality."
		),
		"provider_kind": "first_party_flash_reality",
		"category": "fighting",
		"minimum_players": 1,
		"maximum_players": MAX_FIGHTERS,
		"supported_modes": [
			"single_vs_ai",
			"relationship_vs_ai",
			"local_multiplayer",
			"split_screen",
			"online_eraccount",
			"spectator",
			"tournament"
		],
		"supported_hosts": [
			"arcade_machine",
			"home_console",
			"computer",
			"school_computer",
			"internet_cafe_terminal",
			"phone",
			"television",
			"future_vr_center",
			"holographic_device",
			"mod_surface"
		],
		"presentation": {
			"theme_key": "flash_stick_fighter",
			"background": "#11141B",
			"panel": "#1B2230",
			"accent": "#FFB347",
			"player_one": "#78D7FF",
			"player_two": "#FF7189"
		},
		"achievement_definitions": (
			achievement_definitions()
		),
		"ui_is_renderer_only": true
	}
func setup_contract() -> Dictionary:
	return {
		"schema": "eralife.stick_fighter_setup_definition",
		"version": 3,
		"provider_id": PROVIDER_ID,
		"title": "STICK FIGHTER",
		"subtitle": (
			"Choose your arena, map size, CPU count, and AI difficulty."
		),
		"default_arena_id": "neon_alley",
		"default_map_size_id": "standard",
		"default_ai_difficulty_id": "normal",
		"default_opponent_count": 1,
		"minimum_opponents": 1,
		"maximum_opponents": 3,
		"maximum_total_players": MAX_FIGHTERS,
		"arenas": _arena_contracts(),
		"map_sizes": _map_size_contracts(),
		"ai_difficulties": _ai_difficulty_contracts(),
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}
func _arena_contracts() -> Array:
	return [
		{
			"arena_id": "neon_alley",
			"title": "Neon Alley",
			"description": (
				"A fast street arena with three elevated ledges."
			),
			"width": 100.0,
			"height": 56.0,
			"blast_zone_margin_x": 12.0,
			"blast_zone_margin_y": 10.0,
			"knockback_scale": 1.0,
			"background_rgba": [
				0.035,
				0.045,
				0.07,
				1.0
			],
			"platform_rgba": [
				0.3,
				0.39,
				0.52,
				0.92
			],
			"accent_rgba": [
				1.0,
				0.78,
				0.32,
				1.0
			],
			"platforms": [
				{
					"platform_id": "ground",
					"x": 0.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "center_street",
					"x": 40.0,
					"y": 50.0,
					"width": 20.0,
					"height": 6.0
				},
				{
					"platform_id": "east_street",
					"x": 70.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "left_ledge",
					"x": 8.0,
					"y": 34.0,
					"width": 24.0,
					"height": 2.5
				},
				{
					"platform_id": "center_ledge",
					"x": 38.0,
					"y": 25.0,
					"width": 24.0,
					"height": 2.5
				},
				{
					"platform_id": "right_ledge",
					"x": 68.0,
					"y": 34.0,
					"width": 24.0,
					"height": 2.5
				}
			],
			"spawn_points": [
				{ "x": 12.0, "platform_id": "ground"},
				{ "x": 50.0, "platform_id": "center_street"},
				{ "x": 79.0, "platform_id": "east_street"},
				{ "x": 92.0, "platform_id": "east_street"}
			]
		},
		{
			"arena_id": "rooftop_rush",
			"title": "Rooftop Rush",
			"description": (
				"Wide roof gaps and two high escape platforms."
			),
			"width": 100.0,
			"height": 56.0,
			"blast_zone_margin_x": 12.0,
			"blast_zone_margin_y": 10.0,
			"knockback_scale": 1.0,
			"background_rgba": [
				0.055,
				0.075,
				0.12,
				1.0
			],
			"platform_rgba": [
				0.46,
				0.5,
				0.61,
				0.94
			],
			"accent_rgba": [
				0.58,
				0.86,
				1.0,
				1.0
			],
			"platforms": [
				{
					"platform_id": "ground",
					"x": 0.0,
					"y": 50.0,
					"width": 29.0,
					"height": 6.0
				},
				{
					"platform_id": "center_roof_base",
					"x": 41.0,
					"y": 50.0,
					"width": 18.0,
					"height": 6.0
				},
				{
					"platform_id": "east_roof_base",
					"x": 71.0,
					"y": 50.0,
					"width": 29.0,
					"height": 6.0
				},
				{
					"platform_id": "west_roof",
					"x": 5.0,
					"y": 31.0,
					"width": 30.0,
					"height": 2.5
				},
				{
					"platform_id": "east_roof",
					"x": 65.0,
					"y": 31.0,
					"width": 30.0,
					"height": 2.5
				},
				{
					"platform_id": "antenna",
					"x": 43.0,
					"y": 19.0,
					"width": 14.0,
					"height": 2.5
				}
			],
			"spawn_points": [
				{ "x": 12.0, "platform_id": "ground"},
				{ "x": 50.0, "platform_id": "center_roof_base"},
				{ "x": 80.0, "platform_id": "east_roof_base"},
				{ "x": 92.0, "platform_id": "east_roof_base"}
			]
		},
		{
			"arena_id": "temple_ruins",
			"title": "Temple Ruins",
			"description": (
				"Ancient stone tiers create a vertical brawl."
			),
			"width": 100.0,
			"height": 56.0,
			"blast_zone_margin_x": 12.0,
			"blast_zone_margin_y": 10.0,
			"knockback_scale": 1.0,
			"background_rgba": [
				0.095,
				0.075,
				0.055,
				1.0
			],
			"platform_rgba": [
				0.52,
				0.43,
				0.31,
				0.96
			],
			"accent_rgba": [
				0.96,
				0.72,
				0.35,
				1.0
			],
			"platforms": [
				{
					"platform_id": "ground",
					"x": 0.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "temple_floor_center",
					"x": 40.0,
					"y": 50.0,
					"width": 20.0,
					"height": 6.0
				},
				{
					"platform_id": "temple_floor_east",
					"x": 70.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "west_ruin",
					"x": 10.0,
					"y": 38.0,
					"width": 22.0,
					"height": 3.0
				},
				{
					"platform_id": "altar",
					"x": 35.0,
					"y": 28.0,
					"width": 30.0,
					"height": 3.0
				},
				{
					"platform_id": "east_ruin",
					"x": 68.0,
					"y": 38.0,
					"width": 22.0,
					"height": 3.0
				}
			],
			"spawn_points": [
				{ "x": 12.0, "platform_id": "ground"},
				{ "x": 50.0, "platform_id": "temple_floor_center"},
				{ "x": 79.0, "platform_id": "temple_floor_east"},
				{ "x": 92.0, "platform_id": "temple_floor_east"}
			]
		},
		{
			"arena_id": "cyber_grid",
			"title": "Cyber Grid",
			"description": (
				"A luminous symmetrical arena built for four-way chaos."
			),
			"width": 100.0,
			"height": 56.0,
			"blast_zone_margin_x": 12.0,
			"blast_zone_margin_y": 10.0,
			"knockback_scale": 1.0,
			"background_rgba": [
				0.025,
				0.035,
				0.05,
				1.0
			],
			"platform_rgba": [
				0.22,
				0.72,
				0.78,
				0.88
			],
			"accent_rgba": [
				0.34,
				1.0,
				0.88,
				1.0
			],
			"platforms": [
				{
					"platform_id": "ground",
					"x": 0.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "core_floor",
					"x": 40.0,
					"y": 50.0,
					"width": 20.0,
					"height": 6.0
				},
				{
					"platform_id": "east_floor",
					"x": 70.0,
					"y": 50.0,
					"width": 30.0,
					"height": 6.0
				},
				{
					"platform_id": "west_grid",
					"x": 4.0,
					"y": 32.0,
					"width": 26.0,
					"height": 2.0
				},
				{
					"platform_id": "core_grid",
					"x": 37.0,
					"y": 22.0,
					"width": 26.0,
					"height": 2.0
				},
				{
					"platform_id": "east_grid",
					"x": 70.0,
					"y": 32.0,
					"width": 26.0,
					"height": 2.0
				}
			],
			"spawn_points": [
				{ "x": 12.0, "platform_id": "ground"},
				{ "x": 50.0, "platform_id": "core_floor"},
				{ "x": 79.0, "platform_id": "east_floor"},
				{ "x": 92.0, "platform_id": "east_floor"}
			]
		}
	]
func _arena_contract(
	arena_id: String
) -> Dictionary:
	var clean_arena_id: String = _id(
		arena_id
	)
	var arenas: Array = _arena_contracts()

	for raw_arena in arenas:
		var arena: Dictionary = _dict(
			raw_arena
		)

		if _id(
			str(
				arena.get(
					"arena_id",
					""
				)
			)
		) == clean_arena_id:
			return _decorate_arena_contract(
				arena.duplicate(true)
			)

	if arenas.is_empty():
		return {}

	return _decorate_arena_contract(
		_dict(
			arenas [0]
		).duplicate(true)
	)
func _map_size_contracts() -> Array:
	return MAP_SIZE_CONTRACTS.duplicate(true)


func _map_size_contract(
	map_size_id: String
) -> Dictionary:
	var clean_map_size_id: String = _id(
		map_size_id
	)

	for raw_contract in MAP_SIZE_CONTRACTS:
		var contract: Dictionary = _dict(
			raw_contract
		)

		if _id(
			str(
				contract.get(
					"map_size_id",
					""
				)
			)
		) == clean_map_size_id:
			return contract.duplicate(true)

	return _dict(
		MAP_SIZE_CONTRACTS [1]
	).duplicate(true)


func _decorate_arena_contract(
	arena: Dictionary
) -> Dictionary:
	var out: Dictionary = arena.duplicate(true)
	var arena_id: String = _id(
		str(
			out.get(
				"arena_id",
				""
			)
		)
	)
	var decorated_platforms: Array = []

	for raw_platform in _array(
		out.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		).duplicate(true)
		var platform_id: String = _id(
			str(
				platform.get(
					"platform_id",
					""
				)
			)
		)
		var platform_y: float = float(
			platform.get(
				"y",
				50.0
			)
		)
		var platform_height: float = float(
			platform.get(
				"height",
				2.5
			)
		)
		var surface_style: String = "metal"

		match arena_id:
			"temple_ruins":
				surface_style = (
					"grass"
					if platform_id in [
						"west_ruin",
						"east_ruin"
					]
					else "rock"
				)

			"cyber_grid":
				surface_style = "crystal"

			"rooftop_rush":
				surface_style = (
					"rock"
					if platform_id == "antenna"
					else "concrete"
				)

			"neon_alley":
				surface_style = (
					"grass"
					if platform_id in [
						"left_ledge",
						"right_ledge"
					]
					else "metal"
				)

		platform [
			"surface_style"
		] = surface_style
		platform [
			"solid"
		] = true
		platform [
			"drop_through"
		] = (
			platform_y < 49.0
			and platform_height <= 3.5
		)

		decorated_platforms.append(
			platform
		)

	out [
		"platforms"
	] = decorated_platforms
	out [
		"drop_through_platforms"
	] = true
	out [
		"platform_surface_contracts"
	] = true

	return out


func _arena_contract_for_map_size(
	arena_id: String,
	map_size_id: String
) -> Dictionary:
	var arena: Dictionary = _arena_contract(
		arena_id
	)

	if arena.is_empty():
		return {}

	var size_contract: Dictionary = _map_size_contract(
		map_size_id
	)
	var spacing_scale: float = maxf(
		0.1,
		float(
			size_contract.get(
				"platform_spacing_scale",
				1.0
			)
		)
	)
	var width_scale: float = maxf(
		0.1,
		float(
			size_contract.get(
				"platform_width_scale",
				1.0
			)
		)
	)
	var vertical_scale: float = maxf(
		0.1,
		float(
			size_contract.get(
				"vertical_spacing_scale",
				1.0
			)
		)
	)
	var stage_width: float = maxf(
		1.0,
		float(
			arena.get(
				"width",
				100.0
			)
		)
	)
	var stage_center_x: float = stage_width * 0.5
	var floor_y: float = 50.0
	var resized_platforms: Array = []

	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		).duplicate(true)
		var original_width: float = maxf(
			1.0,
			float(
				platform.get(
					"width",
					1.0
				)
			)
		)
		var original_x: float = float(
			platform.get(
				"x",
				0.0
			)
		)
		var original_y: float = float(
			platform.get(
				"y",
				floor_y
			)
		)
		var center_x: float = (
			original_x
			+ original_width * 0.5
		)
		var resized_width: float = clampf(
			original_width * width_scale,
			4.0,
			stage_width
		)
		var resized_center_x: float = (
			stage_center_x
			+ (
				center_x - stage_center_x
			) * spacing_scale
		)

		platform [
			"width"
		] = resized_width
		platform [
			"x"
		] = clampf(
			resized_center_x
			- resized_width * 0.5,
			0.0,
			maxf(
				0.0,
				stage_width - resized_width
			)
		)

		if original_y < floor_y:
			platform [
				"y"
			] = floor_y + (
				original_y - floor_y
			) * vertical_scale

		resized_platforms.append(
			platform
		)

	var resized_spawns: Array = []

	for raw_spawn in _array(
		arena.get(
			"spawn_points",
			[]
		)
	):
		var spawn: Dictionary = _dict(
			raw_spawn
		).duplicate(true)
		var spawn_x: float = float(
			spawn.get(
				"x",
				stage_center_x
			)
		)

		spawn [
			"x"
		] = clampf(
			stage_center_x
			+ (
				spawn_x - stage_center_x
			) * spacing_scale,
			4.0,
			stage_width - 4.0
		)

		resized_spawns.append(
			spawn
		)

	arena [
		"platforms"
	] = resized_platforms
	arena [
		"spawn_points"
	] = resized_spawns
	arena [
		"map_size_id"
	] = str(
		size_contract.get(
			"map_size_id",
			"standard"
		)
	)
	arena [
		"map_size_title"
	] = str(
		size_contract.get(
			"title",
			"STANDARD"
		)
	)
	arena [
		"map_size_contract"
	] = size_contract

	return arena


func _fighter_can_drop_through(
	arena: Dictionary,
	fighter: Dictionary
) -> bool:
	if bool(
		fighter.get(
			"vertical_transition_active",
			false
		)
	):
		return false

	var platform: Dictionary = _platform_contract(
		arena,
		str(
			fighter.get(
				"platform_id",
				""
			)
		)
	)

	if platform.is_empty():
		return false

	if not bool(
		platform.get(
			"drop_through",
			false
		)
	):
		return false

	return not _landing_platform_below_x(
		arena,
		float(
			fighter.get(
				"x",
				50.0
			)
		),
		float(
			fighter.get(
				"y",
				50.0
			)
		),
		0.01
	).is_empty()
func _platform_contract(
	arena: Dictionary,
	platform_id: String
) -> Dictionary:
	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		)

		if str(
			platform.get(
				"platform_id",
				""
			)
		) == platform_id:
			return platform

	return {}
func _platform_y(
	arena: Dictionary,
	platform_id: String
) -> float:
	var platform: Dictionary = (
		_platform_contract(
			arena,
			platform_id
		)
	)

	return float(
		platform.get(
			"y",
			50.0
		)
	)
func _spawn_contract_for_index(
	arena: Dictionary,
	index: int
) -> Dictionary:
	var spawn_points: Array = _array(
		arena.get(
			"spawn_points",
			[]
		)
	)

	if spawn_points.is_empty():
		return {
			"x": 50.0,
			"platform_id": "ground"
		}

	return _dict(
		spawn_points [
			clampi(
				index,
				0,
				spawn_points.size() - 1
			)
		]
	)

func achievement_definitions() -> Array:
	return [
		{
			"achievement_id": "first_bell",
			"title": "First Bell",
			"description": "Complete your first Stick Fighter match.",
			"criteria": { "type": "session_complete"}
		},
		{
			"achievement_id": "first_knockout",
			"title": "First Knockout",
			"description": "Win a Stick Fighter match.",
			"criteria": { "type": "win"}
		},
		{
			"achievement_id": "untouched",
			"title": "Untouched",
			"description": "Win without losing health in the final round.",
			"criteria": { "type": "flawless_win"}
		},
		{
			"achievement_id": "from_the_brink",
			"title": "From the Brink",
			"description": "Win after falling below 20 health.",
			"criteria": { "type": "comeback_win"}
		},
		{
			"achievement_id": "family_game_night",
			"title": "Family Game Night",
			"description": "Complete a match with another person.",
			"criteria": { "type": "social_match"}
		},
		{
			"achievement_id": "across_realities",
			"title": "Across Realities",
			"description": "Complete an online ErAccount match.",
			"criteria": { "type": "online_match"}
		}
	]
func continuous_runtime_contract() -> Dictionary:
	return {
		"schema": "eralife.minigame_continuous_runtime_contract",
		"version": 3,
		"provider_id": PROVIDER_ID,
		"enabled": true,
		"simulation_mode": "fixed_step_continuous",
		"step_method": "advance_continuous_flash_simulation",
		"fixed_step_hz": 60,
		"observation_hz": 30,
		"checkpoint_hz": 4,
		"held_inputs": [
			"move_left",
			"move_right",
			"block",
			"drop_down"
		],
		"edge_inputs": [
			"jump",
			"drop_down",
			"punch",
			"kick",
			"special",
			"pickup"
		],
		"ui_is_renderer_only": true
	}
func _ensure_stick_fighter_round_extension_state(
	state: Dictionary
) -> void:
	var round_revision: int = int(
		state.get(
			"round",
			1
		)
	)

	if int(
		state.get(
			"stick_fighter_extension_round_revision",
			-1
		)
	) == round_revision:
		return

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var fighter_count: int = int(
		state.get(
			"fighter_count",
			fighters.size()
		)
	)
	var stock_mode: bool = (
		fighter_count >= 3
	)
	var stock_lives_per_round: int = (
		STOCK_LIVES_PER_ROUND
		if stock_mode
		else 1
	)

	for raw_identity_key in fighters.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if fighter.is_empty():
			continue

		fighter ["jump_horizontal_velocity"] = 0.0
		fighter ["jump_arc_height"] = 9.0
		fighter ["jumps_remaining"] = MAX_JUMPS_PER_AIR_CYCLE
		fighter ["movement_axis"] = 0.0

		fighter ["swept_fall_started_step"] = -1
		fighter ["swept_fall_until_step"] = -1

		fighter ["stock_lives_remaining"] = stock_lives_per_round
		fighter ["respawn_pending"] = false
		fighter ["respawn_at_step"] = -1
		fighter ["eliminated"] = false
		fighter ["eliminated_at_step"] = -1

		fighters [
			identity_key
		] = fighter

	state ["fighters"] = fighters
	state ["stock_mode"] = stock_mode
	state ["stock_lives_per_round"] = stock_lives_per_round
	state [
		"stick_fighter_extension_round_revision"
	] = round_revision
func initial_session_state(
	participants: Array,
	context: Dictionary = {}
) -> Dictionary:
	var arena_id: String = _id(
		str(
			context.get(
				"arena_id",
				"neon_alley"
			)
		)
	)

	var map_size_id: String = _id(
		str(
			context.get(
				"map_size_id",
				"standard"
			)
		)
	)

	var requested_ai_difficulty_id: String = _id(
		str(
			context.get(
				"ai_difficulty_id",
				"normal"
			)
		)
	)

	var ai_difficulty: Dictionary = (
		_ai_difficulty_contract_from_id(
			requested_ai_difficulty_id
		)
	)

	var ai_difficulty_id: String = str(
		ai_difficulty.get(
			"ai_difficulty_id",
			"normal"
		)
	)

	var arena: Dictionary = _arena_contract_for_map_size(
		arena_id,
		map_size_id
	)

	var fighters: Dictionary = {}
	var normalized_participants: Array = []
	var index: int = 0

	for raw_participant in participants:
		if index >= MAX_FIGHTERS:
			break

		if typeof(
			raw_participant
		) != TYPE_DICTIONARY:
			continue

		var participant: Dictionary = (
			raw_participant as Dictionary
		).duplicate(true)

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		).strip_edges()

		if identity_key == "":
			continue

		var spawn: Dictionary = (
			_spawn_contract_for_index(
				arena,
				index
			)
		)

		var platform_id: String = str(
			spawn.get(
				"platform_id",
				"ground"
			)
		)

		var spawn_x: float = float(
			spawn.get(
				"x",
				50.0
			)
		)

		var spawn_y: float = _platform_y(
			arena,
			platform_id
		)

		participant [
			"fighter_index"
		] = index

		normalized_participants.append(
			participant
		)

		fighters [
			identity_key
		] = {
			"identity_key": identity_key,
			"display_name": str(
				participant.get(
					"display_name",
					"Fighter %d"
					% (
						index + 1
					)
				)
			),
			"health": MAX_HEALTH,
			"stamina": MAX_STAMINA,
			"special_meter": 0,
			"x": spawn_x,
			"y": spawn_y,
			"platform_id": platform_id,
			"spawn_platform_id": platform_id,
			"spawn_target_y": spawn_y,
			"facing": (
				1
				if spawn_x < 50.0
				else -1
			),
			"guarding": false,
			"airborne": false,
			"round_wins": 0,
			"lowest_health": MAX_HEALTH,
			"damage_dealt": 0,
			"damage_taken": 0,
			"state": "idle",
			"attack_cooldown_steps": 0,
			"vertical_transition_active": false,
			"vertical_transition_kind": "",
			"vertical_transition_elapsed": 0.0,
			"vertical_transition_duration": 0.0,
			"vertical_transition_from_y": spawn_y,
			"vertical_transition_to_y": spawn_y,
			"vertical_transition_target_platform_id": platform_id,
			"ai_action_id": "",
			"ai_next_decision_step": 0,
			"equipped_weapon": {}
		}

		index += 1

	var local_player_identity_key: String = (
		str(
			normalized_participants [
				0
			].get(
				"identity_key",
				""
			)
		)
		if not normalized_participants.is_empty()
		else ""
	)

	var state: Dictionary = {
		"schema": "eralife.stick_fighter_session_state",
		"version": 5,
		"participants": normalized_participants,
		"fighters": fighters,
		"fighter_count": normalized_participants.size(),
		"opponent_count": maxi(
			0,
			normalized_participants.size() - 1
		),
		"match_mode": str(
			context.get(
				"multiplayer_mode",
				"single_vs_ai"
			)
		),
		"local_player_identity_key": (
			local_player_identity_key
		),
		"round": 1,
		"round_wins_required": WIN_ROUNDS,

		"simulation_mode": "fixed_step_continuous",
		"simulation_step": 0,
		"simulation_time_sec": 0.0,
		"fixed_step_hz": 60,

		"ai_difficulty_id": ai_difficulty_id,
		"ai_difficulty_contract": ai_difficulty,
		"ai_attack_lock_by_identity": {},
		"ai_extension_action_step_by_identity": {},

		"phase": "countdown",
		"winner_identity_key": "",
		"draw": false,

		"arena_id": str(
			arena.get(
				"arena_id",
				arena_id
			)
		),
		"map_size_id": str(
			arena.get(
				"map_size_id",
				map_size_id
			)
		),
		"map_size_title": str(
			arena.get(
				"map_size_title",
				"STANDARD"
			)
		),
		"arena_contract": (
			arena.duplicate(true)
		),
		"stage": str(
			arena.get(
				"title",
				"Neon Alley"
			)
		),

		"last_event_text": str(
			COUNTDOWN_SECONDS
		),
		"local_damage_flash_revision": 0,
		"last_damage_feedback": {},

		"weapon_drops": [],
		"weapon_drop_sequence": 0,
		"next_weapon_drop_step": 0,

		"projectiles": [],
		"projectile_sequence": 0,

		"combat_effects": [],
		"combat_effect_sequence": 0,

		"session_seed": abs(
			int(
				hash(
					"stick_fighter:%d:%s"
					% [
						int(
							Time.get_unix_time_from_system()
						),
						str(
							context
						)
					]
				)
			)
		),
		"complete": false
	}

	_prepare_continuous_round_countdown(
		state
	)

	return state
func _prepare_continuous_round_countdown(
	state: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)
	var participants: Array = _array(
		state.get(
			"participants",
			[]
		)
	)
	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)
	var fixed_step_hz: int = maxi(
		1,
		int(
			state.get(
				"fixed_step_hz",
				60
			)
		)
	)
	var spawn_grace_until_step: int = (
		simulation_step
		+ maxi(
			1,
			int(
				round(
					(
						float(COUNTDOWN_SECONDS)
						+ 1.9
					) * float(fixed_step_hz)
				)
			)
		)
	)

	for index in range(
		participants.size()
	):
		var participant: Dictionary = _dict(
			participants [index]
		)
		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)
		var spawn: Dictionary = _spawn_contract_for_index(
			arena,
			index
		)
		var spawn_platform_id: String = str(
			spawn.get(
				"platform_id",
				"ground"
			)
		)
		var spawn_x: float = float(
			spawn.get(
				"x",
				50.0
			)
		)
		var spawn_target_y: float = _platform_y(
			arena,
			spawn_platform_id
		)



		fighter [
			"health"
		] = MAX_HEALTH
		fighter [
			"stamina"
		] = MAX_STAMINA
		fighter [
			"special_meter"
		] = 0
		fighter [
			"attack_cooldown_steps"
		] = 0
		fighter [
			"last_damage_step"
		] = simulation_step
		fighter [
			"hit_flash_until_step"
		] = -1
		fighter [
			"damage_protection_until_step"
		] = spawn_grace_until_step
		fighter [
			"x"
		] = spawn_x
		fighter [
			"y"
		] = (
			-10.0
			- float(index) * 2.5
		)
		fighter [
			"spawn_platform_id"
		] = spawn_platform_id
		fighter [
			"spawn_target_y"
		] = spawn_target_y
		fighter [
			"platform_id"
		] = "spawn_air"
		fighter [
			"airborne"
		] = true
		fighter [
			"guarding"
		] = false
		fighter [
			"state"
		] = "ready"
		fighter [
			"vertical_transition_active"
		] = false
		fighter [
			"vertical_transition_kind"
		] = ""
		fighter [
			"vertical_transition_elapsed"
		] = 0.0
		fighter [
			"vertical_transition_duration"
		] = 0.0
		fighter [
			"vertical_transition_from_y"
		] = fighter [
			"y"
		]
		fighter [
			"vertical_transition_to_y"
		] = spawn_target_y
		fighter [
			"vertical_transition_target_platform_id"
		] = spawn_platform_id
		fighter [
			"ai_action_id"
		] = ""
		fighter [
			"ai_next_decision_step"
		] = simulation_step
		fighter [
			"equipped_weapon"
		] = {}

		fighters [
			identity_key
		] = fighter

	state [
		"fighters"
	] = fighters
	state [
		"phase"
	] = "countdown"
	state [
		"countdown_from"
	] = COUNTDOWN_SECONDS
	state [
		"countdown_value"
	] = COUNTDOWN_SECONDS
	state [
		"countdown_elapsed_sec"
	] = 0.0
	state [
		"countdown_drop_trigger"
	] = COUNTDOWN_DROP_TRIGGER
	state [
		"countdown_drop_started"
	] = false
	state [
		"countdown_live_until_step"
	] = 0
	state [
		"last_event_text"
	] = str(
		COUNTDOWN_SECONDS
	)
	state [
		"weapon_drops"
	] = []
	state [
		"projectiles"
	] = []
	state [
		"combat_effects"
	] = []
	state [
		"next_weapon_drop_step"
	] = simulation_step + _first_weapon_drop_delay_steps(
		int(
			state.get(
				"fighter_count",
				participants.size()
			)
		)
	)


func _advance_continuous_match_countdown(
	state: Dictionary,
	fixed_delta: float
) -> Array:
	var events: Array = []

	var elapsed: float = float(
		state.get(
			"countdown_elapsed_sec",
			0.0
		)
	) + fixed_delta

	var previous_value: int = int(
		state.get(
			"countdown_value",
			COUNTDOWN_SECONDS
		)
	)

	var remaining_value: int = maxi(
		0,
		int(
			ceil(
				float(
					COUNTDOWN_SECONDS
				) - elapsed
			)
		)
	)

	state [
		"countdown_elapsed_sec"
	] = elapsed

	state [
		"countdown_value"
	] = remaining_value

	if (
		remaining_value <= COUNTDOWN_DROP_TRIGGER
		and not bool(
			state.get(
				"countdown_drop_started",
				false
			)
		)
	):
		state [
			"countdown_drop_started"
		] = true

		var fixed_step_hz: int = maxi(
			1,
			int(
				state.get(
					"fixed_step_hz",
					60
				)
			)
		)

		var live_handoff_steps: int = maxi(
			1,
			int(
				round(
					COUNTDOWN_LIVE_HANDOFF_SECONDS
					* float(
						fixed_step_hz
					)
				)
			)
		)

		var live_start_step: int = int(
			state.get(
				"simulation_step",
				0
			)
		)




		state [
			"countdown_live_until_step"
		] = (
			live_start_step
			+ live_handoff_steps
		)

		var drop_fighters: Dictionary = _dict(
			state.get(
				"fighters",
				{}
			)
		)

		for raw_key in drop_fighters.keys():
			var identity_key: String = str(
				raw_key
			)

			var fighter: Dictionary = _dict(
				drop_fighters.get(
					identity_key,
					{}
				)
			).duplicate(false)

			fighter [
				"vertical_transition_active"
			] = true

			fighter [
				"vertical_transition_kind"
			] = "spawn_drop"

			fighter [
				"vertical_transition_elapsed"
			] = 0.0

			fighter [
				"vertical_transition_duration"
			] = 1.55

			fighter [
				"vertical_transition_from_y"
			] = float(
				fighter.get(
					"y",
					-10.0
				)
			)

			fighter [
				"vertical_transition_to_y"
			] = float(
				fighter.get(
					"spawn_target_y",
					50.0
				)
			)

			fighter [
				"vertical_transition_target_platform_id"
			] = str(
				fighter.get(
					"spawn_platform_id",
					"ground"
				)
			)

			fighter [
				"state"
			] = "drop_in"

			drop_fighters [
				identity_key
			] = fighter

		state [
			"fighters"
		] = drop_fighters



		state [
			"next_weapon_drop_step"
		] = (
			live_start_step
			+ _first_weapon_drop_delay_steps(
				int(
					state.get(
						"fighter_count",
						drop_fighters.size()
					)
				)
			)
		)

		events.append({
			"event_type": "stick_fighter_countdown_drop",
			"simulation_step": live_start_step,
			"countdown_value": remaining_value,
			"text": "Fighters incoming."
		})

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	var countdown_fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_key in countdown_fighters.keys():
		var fighter: Dictionary = _dict(
			countdown_fighters.get(
				raw_key,
				{}
			)
		).duplicate(false)

		if bool(
			fighter.get(
				"vertical_transition_active",
				false
			)
		):
			fighter = _advance_continuous_vertical_transition(
				arena,
				fighter,
				fixed_delta
			)

			countdown_fighters [
				raw_key
			] = fighter

	state [
		"fighters"
	] = countdown_fighters

	if (
		remaining_value != previous_value
		and remaining_value > 0
	):
		state [
			"last_event_text"
		] = str(
			remaining_value
		)

		events.append({
			"event_type": "stick_fighter_countdown_tick",
			"simulation_step": int(
				state.get(
					"simulation_step",
					0
				)
			),
			"countdown_value": remaining_value,
			"combat_live": bool(
				state.get(
					"countdown_drop_started",
					false
				)
			),
			"text": str(
				remaining_value
			)
		})

	if elapsed < float(
		COUNTDOWN_SECONDS
	):
		return events




	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_key in fighters.keys():
		var fighter: Dictionary = _dict(
			fighters.get(
				raw_key,
				{}
			)
		).duplicate(false)

		var spawn_platform_id: String = str(
			fighter.get(
				"spawn_platform_id",
				"ground"
			)
		)

		fighter [
			"y"
		] = float(
			fighter.get(
				"spawn_target_y",
				_platform_y(
					arena,
					spawn_platform_id
				)
			)
		)

		fighter [
			"platform_id"
		] = spawn_platform_id

		fighter [
			"airborne"
		] = false

		fighter [
			"vertical_transition_active"
		] = false

		fighter [
			"vertical_transition_kind"
		] = ""

		fighter [
			"state"
		] = "idle"

		fighters [
			raw_key
		] = fighter

	state [
		"fighters"
	] = fighters

	state [
		"phase"
	] = "fighting"

	state [
		"countdown_value"
	] = 0

	state [
		"last_event_text"
	] = "FIGHT!"

	state [
		"fight_banner_until_step"
	] = int(
		state.get(
			"simulation_step",
			0
		)
	) + 30

	state [
		"next_weapon_drop_step"
	] = int(
		state.get(
			"simulation_step",
			0
		)
	) + _first_weapon_drop_delay_steps(
		int(
			state.get(
				"fighter_count",
				fighters.size()
			)
		)
	)

	events.append({
		"event_type": "stick_fighter_fight_started",
		"simulation_step": int(
			state.get(
				"simulation_step",
				0
			)
		),
		"round": int(
			state.get(
				"round",
				1
			)
		),
		"text": "FIGHT!"
	})

	return events
func available_actions(
	session_state: Dictionary,
	identity_key: String
) -> Array:
	if bool(
		session_state.get(
			"complete",
			false
		)
	):
		return []

	var fighter: Dictionary = _fighter(
		session_state,
		identity_key
	)

	if (
		fighter.is_empty()
		or int(
			fighter.get(
				"health",
				0
			)
		) <= 0
	):
		return []

	var special_ready: bool = (
		int(
			fighter.get(
				"special_meter",
				0
			)
		) >= 100
	)

	var arena: Dictionary = _dict(
		session_state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				session_state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)

	var jumps_remaining: int = int(
		fighter.get(
			"jumps_remaining",
			MAX_JUMPS_PER_AIR_CYCLE
		)
	)
	var can_drop: bool = (
		not bool(
			fighter.get(
				"vertical_transition_active",
				false
			)
		)
		and _fighter_can_drop_through(
			arena,
			fighter
		)
	)

	return [
		_action(
			"move_left",
			"MOVE LEFT",
			true,
			"Hold to move continuously left."
		),
		_action(
			"move_right",
			"MOVE RIGHT",
			true,
			"Hold to move continuously right."
		),
		_action(
			"jump",
			"JUMP",
			(
				int(
					fighter.get(
						"stamina",
						0
					)
				) >= 8
				and jumps_remaining > 0
			),
			(
				"Jump while the fixed-step simulation continues. "
				+ "One additional jump remains available in the air."
			)
		),
		_action(
			"drop_down",
			"DROP",
			can_drop,
			"Drop through the authored pass-through platform below you."
		),
		_action(
			"punch",
			"PUNCH",
			(
				int(
					fighter.get(
						"stamina",
						0
					)
				) >= 10
				and int(
					fighter.get(
						"attack_cooldown_steps",
						0
					)
				) <= 0
			),
			"Fast close-range strike. While airborne this becomes AIR PUNCH."
		),
		_action(
			"kick",
			"KICK",
			(
				int(
					fighter.get(
						"stamina",
						0
					)
				) >= 18
				and int(
					fighter.get(
						"attack_cooldown_steps",
						0
					)
				) <= 0
			),
			"Heavy strike. Hold DOWN while kicking to perform a SWEEP."
		),
		_action(
			"block",
			"BLOCK",
			true,
			"Hold to guard continuously."
		),
		_action(
			"special",
			"SPECIAL",
			(
				special_ready
				and int(
					fighter.get(
						"attack_cooldown_steps",
						0
					)
				) <= 0
			),
			"Spend a full special meter."
		)
	]
func resolve_action(
	_session_state: Dictionary,
	_identity_key: String,
	_action_id: String,
	_context: Dictionary = {}
) -> Dictionary:
	return _failure(
		"stick_fighter_discrete_authority_retired",
		(
			"Stick Fighter is a fixed-step continuous provider. "
			+ "Submit continuous_input state through MiniGameContractEngine "
			+ "instead of committing serialized game actions."
		)
	)
func _stick_fighter_body_center_y(
	fighter: Dictionary
) -> float:
	return float(
		fighter.get(
			"y",
			50.0
		)
	) - 2.55


func _weapon_melee_contact_contract(
	weapon_id: String
) -> Dictionary:
	match _id(
		weapon_id
	):
		"baseball_bat":
			return {
				"minimum_range_x": 0.0,
				"maximum_range_x": 4.8,
				"maximum_range_y": 4.4
			}
		"sword":
			return {
				"minimum_range_x": 0.0,
				"maximum_range_x": 5.4,
				"maximum_range_y": 4.4
			}
		"hammer":
			return {
				"minimum_range_x": 0.0,
				"maximum_range_x": 4.4,
				"maximum_range_y": 4.4
			}
		"spear":
			return {
				"minimum_range_x": 1.8,
				"maximum_range_x": 6.8,
				"maximum_range_y": 3.8
			}
		"shield":
			return {
				"minimum_range_x": 0.0,
				"maximum_range_x": 4.0,
				"maximum_range_y": 4.2
			}
		_:
			return {
				"minimum_range_x": 0.0,
				"maximum_range_x": 4.6,
				"maximum_range_y": 4.4
			}


func _weapon_fire_cooldown_steps(
	weapon_id: String,
	fallback_steps: int
) -> int:
	match _id(
		weapon_id
	):
		"bow":
			return 20
		"throwing_knives":
			return 11
		"pistol":
			return 14
		"uzi":
			return 7
		"grenade":
			return 30
		"rocket_launcher":
			return 36
		_:
			return maxi(
				1,
				fallback_steps
			)


func _stick_fighter_projectile_speed(
	weapon_id: String,
	fallback_speed: float
) -> float:
	match _id(
		weapon_id
	):
		"bow":
			return 30.0
		"throwing_knives":
			return 38.0
		"pistol":
			return 46.0
		"uzi":
			return 58.0
		"rocket_launcher":
			return 25.0
		_:
			return maxf(
				1.0,
				fallback_speed
			)


func _stick_fighter_explosion_radius(
	weapon_id: String,
	fallback_radius: float
) -> float:
	match _id(
		weapon_id
	):
		"grenade":
			return 6.5
		"rocket_launcher":
			return 8.5
		_:
			return clampf(
				fallback_radius,
				0.0,
				8.5
			)


func _projectile_segment_hits_fighter(
	previous_x: float,
	previous_y: float,
	current_x: float,
	current_y: float,
	fighter: Dictionary
) -> bool:
	var segment_start:= Vector2(
		previous_x,
		previous_y
	)
	var segment_end:= Vector2(
		current_x,
		current_y
	)
	var body_center:= Vector2(
		float(
			fighter.get(
				"x",
				50.0
			)
		),
		_stick_fighter_body_center_y(
			fighter
		)
	)

	var segment: Vector2 = (
		segment_end
		- segment_start
	)
	var segment_length_squared: float = (
		segment.length_squared()
	)
	var closest_point: Vector2 = segment_start

	if segment_length_squared > 1e-06:
		var t: float = clampf(
			(
				body_center
				- segment_start
			).dot(
				segment
			) / segment_length_squared,
			0.0,
			1.0
		)
		closest_point = (
			segment_start
			+ segment * t
		)

	var body_delta: Vector2 = (
		closest_point
		- body_center
	)

	return (
		absf(
			body_delta.x
		) <= 1.75
		and absf(
			body_delta.y
		) <= 2.65
	)
func advance_continuous_simulation(
	session_state: Dictionary,
	input_snapshot: Dictionary,
	fixed_delta: float,
	_context: Dictionary = {}
) -> Dictionary:
	if bool(
		session_state.get(
			"complete",
			false
		)
	):
		return {
			"success": true,
			"provider_state": session_state,
			"events": [],
			"complete": true
		}

	var step: int = int(
		session_state.get(
			"simulation_step",
			0
		)
	) + 1

	session_state [
		"simulation_step"
	] = step
	session_state [
		"simulation_time_sec"
	] = float(
		session_state.get(
			"simulation_time_sec",
			0.0
		)
	) + fixed_delta

	var arena: Dictionary = _dict(
		session_state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				session_state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)

	var fighters: Dictionary = _dict(
		session_state.get(
			"fighters",
			{}
		)
	)

	var intents: Dictionary = {}
	var events: Array = []





	for raw_participant in _array(
		session_state.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)
		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if (
			fighter.is_empty()
			or int(
				fighter.get(
					"health",
					0
				)
			) <= 0
		):
			continue

		var is_ai: bool = (
			bool(
				participant.get(
					"is_ai",
					false
				)
			)
			or str(
				participant.get(
					"controller",
					""
				)
			) == "npc_ai"
		)

		var held: Dictionary = {}
		var edges: Array = []
		var ai_decision_made: bool = false

		if is_ai:
			var next_decision_step: int = int(
				fighter.get(
					"ai_next_decision_step",
					0
				)
			)

			if step >= next_decision_step:
				var ai_action: String = (
					_choose_ai_action(
						session_state,
						identity_key
					)
				)

				fighter [
					"ai_action_id"
				] = ai_action
				fighter [
					"ai_next_decision_step"
				] = step + 7
				ai_decision_made = true

			var active_ai_action: String = str(
				fighter.get(
					"ai_action_id",
					"block"
				)
			)

			if active_ai_action in [
				"punch",
				"kick",
				"special",
				"weapon_primary"
			]:
				var ai_target_key: String = _target_key_for_action(
					session_state,
					identity_key,
					{}
				)
				var ai_target: Dictionary = _dict(
					fighters.get(
						ai_target_key,
						{}
					)
				)
				var requires_contact: bool = true

				if active_ai_action == "weapon_primary":
					var ai_weapon: Dictionary = _weapon_contract(
						str(
							_equipped_weapon(
								fighter
							).get(
								"weapon_id",
								""
							)
						)
					)
					requires_contact = (
						_id(
							str(
								ai_weapon.get(
									"kind",
									"melee"
								)
							)
						) != "projectile"
					)

				if (
					requires_contact
					and not ai_target.is_empty()
					and absf(
						float(
							ai_target.get(
								"x",
								50.0
							)
						)
						- float(
							fighter.get(
								"x",
								50.0
							)
						)
					) > 6.0
				):
					active_ai_action = (
						"move_left"
						if float(
							fighter.get(
								"x",
								50.0
							)
						) > float(
							ai_target.get(
								"x",
								50.0
							)
						)
						else "move_right"
					)

			if active_ai_action in [
				"move_left",
				"move_right",
				"block"
			]:
				held [
					active_ai_action
				] = true
			elif ai_decision_made:
				edges.append({
					"action_id": active_ai_action,
					"pressed": true,
					"input_sequence": step
				})
		else:
			var input_row: Dictionary = _dict(
				input_snapshot.get(
					identity_key,
					{}
				)
			)

			held = _dict(
				input_row.get(
					"held",
					{}
				)
			)

			edges = _array(
				input_row.get(
					"edges",
					[]
				)
			)

		intents [
			identity_key
		] = {
			"held": held.duplicate(false),
			"edges": edges.duplicate(true)
		}

		fighters [
			identity_key
		] = fighter

	session_state [
		"fighters"
	] = fighters






	for raw_identity_key in intents.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		var intent: Dictionary = _dict(
			intents.get(
				identity_key,
				{}
			)
		)

		var held: Dictionary = _dict(
			intent.get(
				"held",
				{}
			)
		)

		var edges: Array = _array(
			intent.get(
				"edges",
				[]
			)
		)

		fighter [
			"simulation_step"
		] = step

		var cooldown: int = maxi(
			0,
			int(
				fighter.get(
					"attack_cooldown_steps",
					0
				)
			) - 1
		)

		fighter [
			"attack_cooldown_steps"
		] = cooldown

		var move_left: bool = bool(
			held.get(
				"move_left",
				false
			)
		)
		var move_right: bool = bool(
			held.get(
				"move_right",
				false
			)
		)

		var move_axis: float = 0.0

		if move_left != move_right:
			move_axis = (
				-1.0
				if move_left
				else 1.0
			)

		var airborne: bool = (
			bool(
				fighter.get(
					"airborne",
					false
				)
			)
			or bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
		)

		if move_axis != 0.0:
			var movement_speed: float = (
				10.0
				if airborne
				else 30.0
			)

			fighter [
				"x"
			] = clampf(
				float(
					fighter.get(
						"x",
						50.0
					)
				)
				+ move_axis * movement_speed * fixed_delta,
				4.0,
				96.0
			)

			fighter [
				"facing"
			] = (
				-1
				if move_axis < 0.0
				else 1
			)

			if not airborne:
				fighter [
					"state"
				] = "walk"
				fighter = _normalize_fighter_platform_after_move(
					arena,
					fighter
				)

		fighter [
			"guarding"
		] = bool(
			held.get(
				"block",
				false
			)
		)

		if (
			bool(
				fighter.get(
					"guarding",
					false
				)
			)
			and not bool(
				fighter.get(
					"airborne",
					false
				)
			)
		):
			fighter [
				"state"
			] = "block"

		var requested_edges: Dictionary = {}

		for raw_edge in edges:
			var edge: Dictionary = _dict(
				raw_edge
			)

			if not bool(
				edge.get(
					"pressed",
					true
				)
			):
				continue

			var edge_action: String = _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			)

			if edge_action != "":
				requested_edges [
					edge_action
				] = true

		if (
			bool(
				requested_edges.get(
					"jump",
					false
				)
			)
			and not bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
			and int(
				fighter.get(
					"stamina",
					0
				)
			) >= 8
		):
			fighter [
				"stamina"
			] = maxi(
				0,
				int(
					fighter.get(
						"stamina",
						0
					)
				) - 8
			)

			fighter = _begin_continuous_vertical_transition(
				arena,
				fighter,
				"jump"
			)
		elif (
			bool(
				requested_edges.get(
					"drop_down",
					false
				)
			)
			and not bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
		):
			fighter = _begin_continuous_vertical_transition(
				arena,
				fighter,
				"drop_down"
			)

		fighter = _advance_continuous_vertical_transition(
			arena,
			fighter,
			fixed_delta
		)

		var equipped: Dictionary = _equipped_weapon(
			fighter
		).duplicate(false)

		if bool(
			equipped.get(
				"grenade_aim_active",
				false
			)
		):
			var grenade_fixed_step_hz: int = maxi(
				1,
				int(
					session_state.get(
						"fixed_step_hz",
						60
					)
				)
			)
			var charge_steps: int = maxi(
				0,
				step
				- int(
					equipped.get(
						"grenade_charge_started_step",
						step
					)
				)
			)
			equipped [
				"grenade_charge_ratio"
			] = clampf(
				float(
					charge_steps
				) / float(
					maxi(
						1,
						grenade_fixed_step_hz
					)
				),
				0.0,
				1.0
			)
			fighter [
				"equipped_weapon"
			] = equipped

			if not bool(
				fighter.get(
					"airborne",
					false
				)
			):
				fighter [
					"state"
				] = "grenade_aim"

		var stamina_value: int = int(
			fighter.get(
				"stamina",
				0
			)
		)

		if (
			not bool(
				fighter.get(
					"guarding",
					false
				)
			)
			and stamina_value < MAX_STAMINA
			and step % 3 == 0
		):
			fighter [
				"stamina"
			] = mini(
				MAX_STAMINA,
				stamina_value + 1
			)

		var health_value: int = int(
			fighter.get(
				"health",
				MAX_HEALTH
			)
		)
		var regen_fixed_step_hz: int = maxi(
			1,
			int(
				session_state.get(
					"fixed_step_hz",
					60
				)
			)
		)
		var regen_delay_steps: int = maxi(
			1,
			int(
				round(
					2.5 * float(
						regen_fixed_step_hz
					)
				)
			)
		)
		var regen_interval_steps: int = maxi(
			1,
			int(
				round(
					float(
						regen_fixed_step_hz
					) / 6.0
				)
			)
		)

		if (
			health_value > 0
			and health_value < MAX_HEALTH
			and step
			- int(
				fighter.get(
					"last_damage_step",
					-1000000
				)
			) >= regen_delay_steps
			and step % regen_interval_steps == 0
		):
			fighter [
				"health"
			] = mini(
				MAX_HEALTH,
				health_value + 1
			)

		fighters [
			identity_key
		] = fighter

	session_state [
		"fighters"
	] = fighters





	var attack_ledger: Array = []

	for raw_identity_key in intents.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if (
			fighter.is_empty()
			or int(
				fighter.get(
					"health",
					0
				)
			) <= 0
			or int(
				fighter.get(
					"attack_cooldown_steps",
					0
				)
			) > 0
		):
			continue

		var edges: Array = _array(
			_dict(
				intents.get(
					identity_key,
					{}
				)
			).get(
				"edges",
				[]
			)
		)

		var attack_action: String = ""

		for raw_edge in edges:
			var edge: Dictionary = _dict(
				raw_edge
			)

			if not bool(
				edge.get(
					"pressed",
					true
				)
			):
				continue

			var edge_action: String = _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			)

			if edge_action in [
				"special",
				"kick",
				"punch"
			]:
				attack_action = edge_action
				break

		if attack_action == "":
			continue

		var stamina_cost: int = 0
		var range_x: float = 0.0
		var range_y: float = 0.0
		var minimum_damage: int = 0
		var maximum_damage: int = 0
		var cooldown_steps: int = 0

		match attack_action:
			"punch":
				stamina_cost = 10
				range_x = 4.2
				range_y = 4.2
				minimum_damage = 5
				maximum_damage = 9
				cooldown_steps = 8

			"kick":
				stamina_cost = 18
				range_x = 4.9
				range_y = 4.5
				minimum_damage = 8
				maximum_damage = 13
				cooldown_steps = 12

			"special":
				if int(
					fighter.get(
						"special_meter",
						0
					)
				) < 100:
					continue

				range_x = 6.2
				range_y = 5.0
				minimum_damage = 16
				maximum_damage = 23
				cooldown_steps = 18

		if int(
			fighter.get(
				"stamina",
				0
			)
		) < stamina_cost:
			continue

		var target_key: String = (
			_target_key_for_action(
				session_state,
				identity_key,
				{}
			)
		)

		var target: Dictionary = _dict(
			fighters.get(
				target_key,
				{}
			)
		)

		if target.is_empty():
			continue

		var facing: float = (
			-1.0
			if int(
				fighter.get(
					"facing",
					1
				)
			) < 0
			else 1.0
		)
		var forward_distance: float = (
			float(
				target.get(
					"x",
					0.0
				)
			)
			- float(
				fighter.get(
					"x",
					0.0
				)
			)
		) * facing
		var vertical_distance: float = absf(
			_stick_fighter_body_center_y(
				fighter
			)
			- _stick_fighter_body_center_y(
				target
			)
		)
		var target_protected: bool = (
			step <= int(
				target.get(
					"damage_protection_until_step",
					-1
				)
			)
		)

		var hit: bool = (
			not target_protected
			and forward_distance >= -0.25
			and forward_distance <= range_x
			and vertical_distance <= range_y
		)

		var damage: int = 0

		if hit:
			damage = _roll(
				session_state,
				(
					"%s:%s:damage"
					% [
						identity_key,
						attack_action
					]
				),
				minimum_damage,
				maximum_damage
			)

		fighter [
			"stamina"
		] = maxi(
			0,
			int(
				fighter.get(
					"stamina",
					0
				)
			) - stamina_cost
		)

		if attack_action == "special":
			fighter [
				"special_meter"
			] = 0

		fighter [
			"attack_cooldown_steps"
		] = cooldown_steps
		fighter [
			"state"
		] = attack_action

		fighters [
			identity_key
		] = fighter

		attack_ledger.append({
			"source_identity_key": identity_key,
			"target_identity_key": target_key,
			"action_id": attack_action,
			"hit": hit,
			"damage": damage
		})

	session_state [
		"fighters"
	] = fighters





	for raw_attack in attack_ledger:
		var attack: Dictionary = _dict(
			raw_attack
		)

		var source_key: String = str(
			attack.get(
				"source_identity_key",
				""
			)
		)
		var target_key: String = str(
			attack.get(
				"target_identity_key",
				""
			)
		)
		var action_id: String = str(
			attack.get(
				"action_id",
				""
			)
		)
		var hit: bool = bool(
			attack.get(
				"hit",
				false
			)
		)
		var damage: int = int(
			attack.get(
				"damage",
				0
			)
		)

		var source: Dictionary = _dict(
			fighters.get(
				source_key,
				{}
			)
		).duplicate(false)
		var target: Dictionary = _dict(
			fighters.get(
				target_key,
				{}
			)
		).duplicate(false)

		if (
			source.is_empty()
			or target.is_empty()
		):
			continue

		var event_text: String = ""

		if not hit:
			event_text = (
				"%s's %s missed."
				% [
					str(
						source.get(
							"display_name",
							"Fighter"
						)
					),
					action_id
				]
			)
		else:
			if bool(
				target.get(
					"guarding",
					false
				)
			):
				damage = maxi(
					1,
					int(
						round(
							float(
								damage
							) * 0.38
						)
					)
				)

			target [
				"health"
			] = maxi(
				0,
				int(
					target.get(
						"health",
						MAX_HEALTH
					)
				) - damage
			)
			target [
				"last_damage_step"
			] = step
			target [
				"hit_flash_until_step"
			] = step + 8

			target [
				"lowest_health"
			] = mini(
				int(
					target.get(
						"lowest_health",
						MAX_HEALTH
					)
				),
				int(
					target.get(
						"health",
						0
					)
				)
			)

			target [
				"damage_taken"
			] = int(
				target.get(
					"damage_taken",
					0
				)
			) + damage

			source [
				"damage_dealt"
			] = int(
				source.get(
					"damage_dealt",
					0
				)
			) + damage

			source [
				"special_meter"
			] = mini(
				100,
				int(
					source.get(
						"special_meter",
						0
					)
				) + damage * 3
			)

			target [
				"special_meter"
			] = mini(
				100,
				int(
					target.get(
						"special_meter",
						0
					)
				) + damage * 2
			)

			target [
				"state"
			] = (
				"knockout"
				if int(
					target.get(
						"health",
						0
					)
				) <= 0
				else "hurt"
			)

			target = _apply_hit_spatial_reaction(
				session_state,
				source_key,
				action_id,
				damage,
				target
			)

			target = _resolve_blast_zone_elimination(
				session_state,
				source_key,
				target_key,
				action_id,
				damage,
				target
			)

			event_text = (
				"%s hit %s with %s for %d."
				% [
					str(
						source.get(
							"display_name",
							"Fighter"
						)
					),
					str(
						target.get(
							"display_name",
							"Fighter"
						)
					),
					action_id,
					damage
				]
			)

			if target_key == str(
				session_state.get(
					"local_player_identity_key",
					""
				)
			):
				session_state [
					"local_damage_flash_revision"
				] = int(
					session_state.get(
						"local_damage_flash_revision",
						0
					)
				) + 1

				session_state [
					"last_damage_feedback"
				] = {
					"revision": int(
						session_state [
							"local_damage_flash_revision"
						]
					),
					"amount": damage,
					"source_identity_key": source_key,
					"target_identity_key": target_key,
					"local_player_damaged": true,
					"truth_state": "hot"
				}

		fighters [
			source_key
		] = source
		fighters [
			target_key
		] = target

		events.append({
			"event_type": "stick_fighter_continuous_action",
			"simulation_step": step,
			"source_identity_key": source_key,
			"target_identity_key": target_key,
			"action_id": action_id,
			"hit": hit,
			"damage": damage,
			"text": event_text
		})

		if event_text != "":
			session_state [
				"last_event_text"
			] = event_text

	session_state [
		"fighters"
	] = fighters

	_resolve_continuous_round_if_needed(
		session_state
	)

	return {
		"success": true,
		"schema": "eralife.stick_fighter_continuous_step",
		"version": 1,
		"provider_state": session_state,
		"events": events,
		"simulation_step": step,
		"complete": bool(
			session_state.get(
				"complete",
				false
			)
		),
	}
func _begin_continuous_vertical_transition(
	arena: Dictionary,
	fighter: Dictionary,
	transition_kind: String
) -> Dictionary:
	var out: Dictionary = fighter.duplicate(false)
	var clean_kind: String = _id(
		transition_kind
	)
	var current_y: float = float(
		out.get(
			"y",
			50.0
		)
	)
	var target_y: float = current_y
	var target_platform_id: String = str(
		out.get(
			"platform_id",
			"ground"
		)
	)
	var duration: float = 0.34

	if clean_kind == "jump":
		var jumps_remaining: int = int(
			out.get(
				"jumps_remaining",
				MAX_JUMPS_PER_AIR_CYCLE
			)
		)

		if jumps_remaining <= 0:
			return out

		var was_airborne: bool = (
			bool(
				out.get(
					"airborne",
					false
				)
			)
			or bool(
				out.get(
					"vertical_transition_active",
					false
				)
			)
		)
		var destination: Dictionary = _jump_destination_platform(
			arena,
			out
		)
		var horizontal_gap: float = 0.0
		var jump_direction: int = int(
			out.get(
				"facing",
				1
			)
		)

		if not destination.is_empty():
			target_y = float(
				destination.get(
					"y",
					current_y
				)
			)
			target_platform_id = str(
				destination.get(
					"platform_id",
					target_platform_id
				)
			)
			horizontal_gap = float(
				destination.get(
					"jump_horizontal_gap",
					0.0
				)
			)
			jump_direction = int(
				destination.get(
					"jump_direction",
					jump_direction
				)
			)

		var climb_distance: float = maxf(
			0.0,
			current_y - target_y
		)




		duration = clampf(
			0.54 + climb_distance / 70.0,
			0.54,
			0.78
		)

		var assist_speed: float = 0.0

		if horizontal_gap > 0.5:
			assist_speed = clampf(
				(
					horizontal_gap
					/ maxf(
						duration,
						0.01
					)
				) * 0.68,
				8.0,
				14.0
			)

		out ["jumps_remaining"] = jumps_remaining - 1
		out ["jump_horizontal_velocity"] = (
			assist_speed
			* float(
				jump_direction
			)
		)
		out ["jump_arc_height"] = (
			10.5
			if was_airborne
			else 11.5
		)
		out ["state"] = (
			"double_jump"
			if was_airborne
			else "jump"
		)
	else:
		var minimum_drop: float = (
			0.01
			if clean_kind == "drop_down"
			else 0.001
		)
		var landing: Dictionary = _landing_platform_below_x(
			arena,
			float(
				out.get(
					"x",
					50.0
				)
			),
			current_y,
			minimum_drop
		)

		if landing.is_empty():
			target_y = (
				float(
					arena.get(
						"height",
						56.0
					)
				)
				+ float(
					arena.get(
						"blast_zone_margin_y",
						10.0
					)
				)
				+ 1.0
			)
			target_platform_id = "blast_zone"
		else:
			target_y = float(
				landing.get(
					"y",
					current_y
				)
			)
			target_platform_id = str(
				landing.get(
					"platform_id",
					"ground"
				)
			)

		var fall_distance: float = maxf(
			0.0,
			target_y - current_y
		)

		duration = clampf(
			fall_distance / 28.0,
			0.24,
			1.8
		)

		out ["jump_horizontal_velocity"] = 0.0
		out ["jump_arc_height"] = 0.0


		out ["jumps_remaining"] = mini(
			1,
			int(
				out.get(
					"jumps_remaining",
					1
				)
			)
		)

		out ["state"] = (
			"drop"
			if clean_kind == "drop_down"
			else "fall"
		)

	out ["vertical_transition_active"] = true
	out ["vertical_transition_kind"] = clean_kind
	out ["vertical_transition_elapsed"] = 0.0
	out ["vertical_transition_duration"] = duration
	out ["vertical_transition_from_y"] = current_y
	out ["vertical_transition_to_y"] = target_y
	out ["vertical_transition_target_platform_id"] = target_platform_id
	out ["platform_id"] = "air"
	out ["airborne"] = true

	return out

func _advance_continuous_vertical_transition(
	arena: Dictionary,
	fighter: Dictionary,
	fixed_delta: float
) -> Dictionary:
	if not bool(
		fighter.get(
			"vertical_transition_active",
			false
		)
	):
		return fighter

	var out: Dictionary = fighter.duplicate(false)
	var previous_y: float = float(
		out.get(
			"y",
			50.0
		)
	)
	var elapsed: float = float(
		out.get(
			"vertical_transition_elapsed",
			0.0
		)
	) + fixed_delta
	var duration: float = maxf(
		0.001,
		float(
			out.get(
				"vertical_transition_duration",
				0.34
			)
		)
	)
	var progress: float = clampf(
		elapsed / duration,
		0.0,
		1.0
	)
	var from_y: float = float(
		out.get(
			"vertical_transition_from_y",
			50.0
		)
	)
	var to_y: float = float(
		out.get(
			"vertical_transition_to_y",
			50.0
		)
	)
	var kind: String = str(
		out.get(
			"vertical_transition_kind",
			""
		)
	)
	var resolved_y: float = lerpf(
		from_y,
		to_y,
		progress
	)

	if kind == "jump":
		resolved_y -= (
			sin(
				progress * PI
			)
			* float(
				out.get(
					"jump_arc_height",
					11.5
				)
			)
		)



		out ["x"] = clampf(
			float(
				out.get(
					"x",
					50.0
				)
			)
			+ float(
				out.get(
					"jump_horizontal_velocity",
					0.0
				)
			) * fixed_delta,
			4.0,
			96.0
		)

	out ["y"] = resolved_y
	out ["vertical_transition_elapsed"] = elapsed

	var should_test_landing: bool = (
		kind in [
			"spawn_drop",
			"drop_down",
			"fall"
		]
		or (
			kind == "jump"
			and progress >= 0.45
			and resolved_y >= previous_y
		)
	)

	if should_test_landing:
		var landing: Dictionary = _landing_platform_below_x(
			arena,
			float(
				out.get(
					"x",
					50.0
				)
			),
			previous_y,
			0.001
		)

		if not landing.is_empty():
			var landing_y: float = float(
				landing.get(
					"y",
					resolved_y
				)
			)

			if (
				previous_y <= landing_y
				and resolved_y >= landing_y
			):
				out ["y"] = landing_y
				out ["platform_id"] = str(
					landing.get(
						"platform_id",
						"ground"
					)
				)
				out ["airborne"] = false
				out ["vertical_transition_active"] = false
				out ["vertical_transition_kind"] = ""
				out ["vertical_transition_elapsed"] = 0.0
				out ["vertical_transition_duration"] = 0.0
				out ["jump_horizontal_velocity"] = 0.0
				out ["jumps_remaining"] = MAX_JUMPS_PER_AIR_CYCLE
				out ["state"] = "idle"

				return out

	if progress < 1.0:
		return out

	var target_platform_id: String = str(
		out.get(
			"vertical_transition_target_platform_id",
			"ground"
		)
	)

	out ["vertical_transition_active"] = false
	out ["vertical_transition_kind"] = ""
	out ["vertical_transition_elapsed"] = 0.0
	out ["vertical_transition_duration"] = 0.0
	out ["jump_horizontal_velocity"] = 0.0
	out ["y"] = to_y

	if target_platform_id == "blast_zone":
		out ["platform_id"] = "blast_zone"
		out ["airborne"] = true
		out ["health"] = 0
		out ["state"] = "knockout"

		return out

	out ["platform_id"] = target_platform_id
	out ["airborne"] = false
	out ["jumps_remaining"] = MAX_JUMPS_PER_AIR_CYCLE
	out ["state"] = "idle"

	return _normalize_fighter_platform_after_move(
		arena,
		out
	)
func _resolve_continuous_round_if_needed(
	state: Dictionary
) -> Dictionary:
	if bool(
		state.get(
			"round_resolution_deferred",
			false
		)
	):
		return {
			"round_resolved": false,
			"round_resolution_deferred": true
		}

	var living_keys: Array = (
		_living_identity_keys(
			state
		)
	)

	var match_mode: String = str(
		state.get(
			"match_mode",
			"single_vs_ai"
		)
	)

	var local_player_key: String = str(
		state.get(
			"local_player_identity_key",
			""
		)
	)

	var round_winner_key: String = ""

	if match_mode == "single_vs_ai":
		var local_alive: bool = (
			local_player_key != ""
			and int(
				_fighter(
					state,
					local_player_key
				).get(
					"health",
					0
				)
			) > 0
		)

		var living_opponents: Array = []

		for raw_key in living_keys:
			var candidate_key: String = str(
				raw_key
			)

			if candidate_key != local_player_key:
				living_opponents.append(
					candidate_key
				)

		if (
			local_alive
			and not living_opponents.is_empty()
		):
			return {
				"round_resolved": false
			}

		if (
			local_alive
			and living_opponents.is_empty()
		):
			round_winner_key = local_player_key
		else:
			round_winner_key = (
				_highest_health_identity_key(
					state,
					living_opponents
				)
			)
	else:
		if living_keys.size() > 1:
			return {
				"round_resolved": false
			}

		if living_keys.size() == 1:
			round_winner_key = str(
				living_keys [
					0
				]
			)
		else:
			var fighter_keys: Array = _dict(
				state.get(
					"fighters",
					{}
				)
			).keys()

			round_winner_key = (
				_highest_health_identity_key(
					state,
					fighter_keys
				)
			)

	if round_winner_key == "":
		state [
			"draw"
		] = true

		return {
			"round_resolved": true,
			"match_complete": false,
			"draw": true
		}

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	var round_winner: Dictionary = _dict(
		fighters.get(
			round_winner_key,
			{}
		)
	).duplicate(false)

	round_winner [
		"round_wins"
	] = int(
		round_winner.get(
			"round_wins",
			0
		)
	) + 1

	fighters [
		round_winner_key
	] = round_winner

	state [
		"fighters"
	] = fighters

	if int(
		round_winner.get(
			"round_wins",
			0
		)
	) >= WIN_ROUNDS:
		state [
			"complete"
		] = true

		state [
			"phase"
		] = "complete"

		state [
			"winner_identity_key"
		] = round_winner_key

		state [
			"last_event_text"
		] = (
			"%s won the match!"
			% str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			)
		)

		return {
			"round_resolved": true,
			"match_complete": true
		}

	state [
		"round"
	] = int(
		state.get(
			"round",
			1
		)
	) + 1

	_reset_round(
		state
	)

	_clear_continuous_round_transients(
		state
	)

	state [
		"last_event_text"
	] = (
		"%s won the round. ROUND %d!"
		% [
			str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			),
			int(
				state.get(
					"round",
					1
				)
			)
		]
	)

	return {
		"round_resolved": true,
		"match_complete": false
	}
func _weapon_contract(
	weapon_id: String
) -> Dictionary:
	var clean_weapon_id: String = _id(
		weapon_id
	)

	for raw_weapon in WEAPON_CATALOG:
		var weapon: Dictionary = _dict(
			raw_weapon
		)

		if _id(
			str(
				weapon.get(
					"weapon_id",
					""
				)
			)
		) == clean_weapon_id:
			return weapon.duplicate(true)

	return {}


func _equipped_weapon(
	fighter: Dictionary
) -> Dictionary:
	return _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)


func _rarity_aura_rgba(
	rarity: String
) -> Array:
	match _id(
		rarity
	):
		"legendary":
			return [
				1.0,
				0.66,
				0.12,
				0.82
			]

		"epic":
			return [
				0.72,
				0.31,
				1.0,
				0.78
			]

		"rare":
			return [
				0.22,
				0.58,
				1.0,
				0.76
			]

		"uncommon":
			return [
				0.25,
				0.92,
				0.48,
				0.72
			]

		_:
			return [
				0.86,
				0.88,
				0.94,
				0.66
			]


func _weapon_drop_interval_steps(
	fighter_count: int
) -> int:
	return clampi(
		540
		- maxi(
			0,
			fighter_count - 2
		) * 120,
		300,
		540
	)


func _first_weapon_drop_delay_steps(
	fighter_count: int
) -> int:
	return clampi(
		180
		- maxi(
			0,
			fighter_count - 2
		) * 30,
		120,
		180
	)


func _weighted_weapon_contract(
	state: Dictionary,
	salt: String
) -> Dictionary:
	var total_weight: int = 0

	for raw_weapon in WEAPON_CATALOG:
		total_weight += maxi(
			1,
			int(
				_dict(
					raw_weapon
				).get(
					"drop_weight",
					1
				)
			)
		)

	if total_weight <= 0:
		return {}

	var roll_value: int = _roll(
		state,
		salt,
		1,
		total_weight
	)

	var cursor: int = 0

	for raw_weapon in WEAPON_CATALOG:
		var weapon: Dictionary = _dict(
			raw_weapon
		)

		cursor += maxi(
			1,
			int(
				weapon.get(
					"drop_weight",
					1
				)
			)
		)

		if roll_value <= cursor:
			return weapon.duplicate(true)

	return _dict(
		WEAPON_CATALOG [0]
	).duplicate(true)


func _service_weapon_drops(
	state: Dictionary,
	events: Array
) -> void:
	if str(
		state.get(
			"phase",
			"fighting"
		)
	) != "fighting":
		return

	var step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)
	var fixed_step_hz: int = maxi(
		1,
		int(
			state.get(
				"fixed_step_hz",
				60
			)
		)
	)
	var fixed_delta: float = (
		1.0 / float(
			fixed_step_hz
		)
	)
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)
	var drops: Array = _array(
		state.get(
			"weapon_drops",
			[]
		)
	)
	var retained: Array = []

	for raw_drop in drops:
		var drop: Dictionary = _dict(
			raw_drop
		).duplicate(false)

		if step > int(
			drop.get(
				"expires_step",
				step
			)
		):
			continue

		if bool(
			drop.get(
				"falling",
				false
			)
		):
			var previous_y: float = float(
				drop.get(
					"y",
					-6.0
				)
			)
			var velocity_y: float = float(
				drop.get(
					"vy",
					4.0
				)
			) + float(
				drop.get(
					"gravity",
					8.0
				)
			) * fixed_delta
			var next_y: float = (
				previous_y
				+ velocity_y * fixed_delta
			)

			drop [
				"vy"
			] = velocity_y
			drop [
				"y"
			] = next_y

			var landing: Dictionary = (
				_landing_platform_below_x(
					arena,
					float(
						drop.get(
							"x",
							50.0
						)
					),
					previous_y,
					0.001
				)
			)

			if not landing.is_empty():
				var landing_y: float = float(
					landing.get(
						"y",
						next_y
					)
				)

				if (
					previous_y <= landing_y
					and next_y >= landing_y
				):
					drop [
						"y"
					] = landing_y
					drop [
						"vy"
					] = 0.0
					drop [
						"falling"
					] = false
					drop [
						"platform_id"
					] = str(
						landing.get(
							"platform_id",
							"ground"
						)
					)

		retained.append(
			drop
		)

	drops = retained

	var fighter_count: int = maxi(
		1,
		int(
			state.get(
				"fighter_count",
				2
			)
		)
	)
	var next_drop_delay_steps: int = (
		_weapon_drop_interval_steps(
			fighter_count
		)
	)

	if step < int(
		state.get(
			"next_weapon_drop_step",
			0
		)
	):
		state [
			"weapon_drops"
		] = drops
		return

	if drops.size() >= MAX_WEAPON_DROPS:
		state [
			"weapon_drops"
		] = drops
		state [
			"next_weapon_drop_step"
		] = (
			step
			+ next_drop_delay_steps
		)
		return

	var platforms: Array = _array(
		arena.get(
			"platforms",
			[]
		)
	)
	var eligible_platforms: Array = []

	for raw_platform in platforms:
		var candidate_platform: Dictionary = _dict(
			raw_platform
		)

		if bool(
			candidate_platform.get(
				"solid",
				true
			)
		):
			eligible_platforms.append(
				candidate_platform.duplicate(true)
			)

	if eligible_platforms.is_empty():
		state [
			"weapon_drops"
		] = drops
		state [
			"next_weapon_drop_step"
		] = (
			step
			+ next_drop_delay_steps
		)
		return

	var weapon: Dictionary = _weighted_weapon_contract(
		state,
		"weapon_drop_weapon"
	)

	if weapon.is_empty():
		state [
			"weapon_drops"
		] = drops
		state [
			"next_weapon_drop_step"
		] = (
			step
			+ next_drop_delay_steps
		)
		return

	var weapon_id: String = str(
		weapon.get(
			"weapon_id",
			""
		)
	).strip_edges()

	if weapon_id == "":
		state [
			"weapon_drops"
		] = drops
		state [
			"next_weapon_drop_step"
		] = (
			step
			+ next_drop_delay_steps
		)
		return

	var platform_index: int = _roll(
		state,
		"weapon_drop_platform",
		0,
		eligible_platforms.size() - 1
	)
	var drop_platform: Dictionary = _dict(
		eligible_platforms [
			platform_index
		]
	)
	var platform_x: float = float(
		drop_platform.get(
			"x",
			0.0
		)
	)
	var platform_width: float = maxf(
		4.0,
		float(
			drop_platform.get(
				"width",
				20.0
			)
		)
	)
	var drop_x: float = (
		platform_x
		+ float(
			_roll(
				state,
				"weapon_drop_x",
				2,
				maxi(
					2,
					int(
						floor(
							platform_width - 2.0
						)
					)
				)
			)
		)
	)
	var sequence: int = int(
		state.get(
			"weapon_drop_sequence",
			0
		)
	) + 1

	state [
		"weapon_drop_sequence"
	] = sequence

	drops.append({
		"drop_id": (
			"weapon_drop_%d"
			% sequence
		),
		"weapon_id": weapon_id,
		"title": str(
			weapon.get(
				"title",
				weapon_id.capitalize()
			)
		),
		"x": drop_x,
		"y": -6.0,
		"vy": 4.0,
		"gravity": 8.0,
		"falling": true,
		"platform_id": "air",
		"target_platform_id": str(
			drop_platform.get(
				"platform_id",
				"ground"
			)
		),
		"spawn_step": step,
		"expires_step": step + 720,
		"aura_rgba": _rarity_aura_rgba(
			str(
				weapon.get(
					"rarity",
					"common"
				)
			)
		)
	})

	state [
		"weapon_drops"
	] = drops
	state [
		"next_weapon_drop_step"
	] = (
		step
		+ next_drop_delay_steps
	)

	events.append({
		"event_type": "stick_fighter_weapon_drop",
		"simulation_step": step,
		"weapon_id": weapon_id,
		"text": (
			"%s is dropping into the arena."
			% str(
				weapon.get(
					"title",
					weapon_id.capitalize()
				)
			)
		)
	})
func _resolve_weapon_primary_intents(
	state: Dictionary,
	weapon_intents: Array,
	events: Array
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_intent in weapon_intents:
		var intent: Dictionary = _dict(
			raw_intent
		)
		var identity_key: String = str(
			intent.get(
				"identity_key",
				""
			)
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if (
			identity_key == ""
			or fighter.is_empty()
			or int(
				fighter.get(
					"health",
					0
				)
			) <= 0
			or int(
				fighter.get(
					"attack_cooldown_steps",
					0
				)
			) > 0
		):
			continue

		var equipped: Dictionary = _equipped_weapon(
			fighter
		).duplicate(false)

		if equipped.is_empty():
			continue

		var weapon_id: String = str(
			equipped.get(
				"weapon_id",
				""
			)
		)
		var weapon: Dictionary = _weapon_contract(
			weapon_id
		)

		if weapon.is_empty():
			continue

		var stamina_cost: int = int(
			weapon.get(
				"stamina_cost",
				12
			)
		)

		if int(
			fighter.get(
				"stamina",
				0
			)
		) < stamina_cost:
			continue

		fighter [
			"stamina"
		] = maxi(
			0,
			int(
				fighter.get(
					"stamina",
					0
				)
			) - stamina_cost
		)
		fighter [
			"attack_cooldown_steps"
		] = _weapon_fire_cooldown_steps(
			weapon_id,
			int(
				weapon.get(
					"cooldown_steps",
					10
				)
			)
		)
		fighter [
			"state"
		] = (
			"fire"
			if str(
				weapon.get(
					"kind",
					"melee"
				)
			) == "projectile"
			else "weapon_attack"
		)

		fighters [
			identity_key
		] = fighter

		if str(
			weapon.get(
				"kind",
				"melee"
			)
		) == "projectile":
			state [
				"fighters"
			] = fighters

			_spawn_weapon_projectiles(
				state,
				identity_key,
				weapon,
				intent
			)
			continue

		var target_key: String = _target_key_for_action(
			state,
			identity_key,
			{}
		)
		var target: Dictionary = _dict(
			fighters.get(
				target_key,
				{}
			)
		)

		if target.is_empty():
			continue

		var contact: Dictionary = _weapon_melee_contact_contract(
			weapon_id
		)
		var minimum_range_x: float = float(
			contact.get(
				"minimum_range_x",
				0.0
			)
		)
		var maximum_range_x: float = float(
			contact.get(
				"maximum_range_x",
				4.6
			)
		)
		var maximum_range_y: float = float(
			contact.get(
				"maximum_range_y",
				4.4
			)
		)
		var facing: float = (
			-1.0
			if int(
				fighter.get(
					"facing",
					1
				)
			) < 0
			else 1.0
		)
		var forward_distance: float = (
			float(
				target.get(
					"x",
					50.0
				)
			)
			- float(
				fighter.get(
					"x",
					50.0
				)
			)
		) * facing
		var vertical_distance: float = absf(
			_stick_fighter_body_center_y(
				fighter
			)
			- _stick_fighter_body_center_y(
				target
			)
		)

		var hit: bool = (
			forward_distance >= minimum_range_x
			and forward_distance <= maximum_range_x
			and vertical_distance <= maximum_range_y
		)

		if not hit:
			continue

		var damage: int = _roll(
			state,
			(
				"%s:%s:weapon_damage"
				% [
					identity_key,
					weapon_id
				]
			),
			int(
				weapon.get(
					"minimum_damage",
					weapon.get(
						"damage_min",
						8
					)
				)
			),
			int(
				weapon.get(
					"maximum_damage",
					weapon.get(
						"damage_max",
						18
					)
				)
			)
		)

		_apply_weapon_damage(
			state,
			identity_key,
			target_key,
			weapon,
			damage,
			events
		)

	state [
		"fighters"
	] = fighters

func _projectile_crosses_solid_platform(
	arena: Dictionary,
	x: float,
	previous_y: float,
	current_y: float
) -> bool:
	if current_y < previous_y:
		return false

	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		)

		if not bool(
			platform.get(
				"solid",
				true
			)
		):
			continue

		var platform_x: float = float(
			platform.get(
				"x",
				0.0
			)
		)

		var platform_width: float = maxf(
			0.0,
			float(
				platform.get(
					"width",
					0.0
				)
			)
		)

		if (
			x < platform_x
			or x > (
				platform_x
				+ platform_width
			)
		):
			continue

		var platform_y: float = float(
			platform.get(
				"y",
				50.0
			)
		)

		if (
			previous_y <= platform_y
			and current_y >= platform_y
		):
			return true

	return false


func _resolve_weapon_projectile_explosion(
	state: Dictionary,
	projectile: Dictionary,
	events: Array
) -> void:
	var radius: float = float(
		projectile.get(
			"explosion_radius",
			0.0
		)
	)

	if radius <= 0.0:
		return

	var source_identity_key: String = str(
		projectile.get(
			"source_identity_key",
			""
		)
	)
	var projectile_x: float = float(
		projectile.get(
			"x",
			0.0
		)
	)
	var projectile_y: float = float(
		projectile.get(
			"y",
			0.0
		)
	)
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_target_key in fighters.keys():
		var target_key: String = str(
			raw_target_key
		)

		if target_key == source_identity_key:
			continue

		var target: Dictionary = _dict(
			fighters.get(
				target_key,
				{}
			)
		)

		if (
			target.is_empty()
			or int(
				target.get(
					"health",
					0
				)
			) <= 0
		):
			continue

		var dx: float = float(
			target.get(
				"x",
				50.0
			)
		) - projectile_x
		var dy: float = (
			_stick_fighter_body_center_y(
				target
			) - projectile_y
		)
		var distance: float = sqrt(
			dx * dx + dy * dy
		)

		if distance > radius:
			continue

		var falloff: float = clampf(
			1.0 - distance / maxf(
				1.0,
				radius
			),
			0.35,
			1.0
		)
		var damage: int = maxi(
			1,
			int(
				round(
					float(
						_roll(
							state,
							(
								"%s:%s:explosion_damage"
								% [
									source_identity_key,
									target_key
								]
							),
							int(
								projectile.get(
									"damage_min",
									8
								)
							),
							int(
								projectile.get(
									"damage_max",
									16
								)
							)
						)
					) * falloff
				)
			)
		)

		var weapon: Dictionary = _weapon_contract(
			str(
				projectile.get(
					"weapon_id",
					""
				)
			)
		)

		_apply_weapon_damage(
			state,
			source_identity_key,
			target_key,
			weapon,
			damage,
			events
		)

	_append_combat_effect(
		state,
		{
			"effect_kind": "explosion",
			"x": projectile_x,
			"y": projectile_y,
			"vx": 0.0,
			"vy": 0.0,
			"gravity": 0.0,
			"ttl_steps": 18
		}
	)


func _service_weapon_projectiles(
	state: Dictionary,
	fixed_delta: float,
	events: Array
) -> void:
	var projectiles: Array = _array(
		state.get(
			"projectiles",
			[]
		)
	)
	var retained: Array = []
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	for raw_projectile in projectiles:
		var projectile: Dictionary = _dict(
			raw_projectile
		).duplicate(false)

		var previous_x: float = float(
			projectile.get(
				"x",
				0.0
			)
		)
		var previous_y: float = float(
			projectile.get(
				"y",
				0.0
			)
		)

		projectile [
			"x"
		] = previous_x + float(
			projectile.get(
				"vx",
				0.0
			)
		) * fixed_delta

		projectile [
			"vy"
		] = float(
			projectile.get(
				"vy",
				0.0
			)
		) + float(
			projectile.get(
				"gravity",
				0.0
			)
		) * fixed_delta

		projectile [
			"y"
		] = previous_y + float(
			projectile.get(
				"vy",
				0.0
			)
		) * fixed_delta

		projectile [
			"ttl_steps"
		] = int(
			projectile.get(
				"ttl_steps",
				1
			)
		) - 1

		var consumed: bool = false
		var current_x: float = float(
			projectile.get(
				"x",
				0.0
			)
		)
		var current_y: float = float(
			projectile.get(
				"y",
				0.0
			)
		)
		var source_identity_key: String = str(
			projectile.get(
				"source_identity_key",
				""
			)
		)
		var weapon_id: String = str(
			projectile.get(
				"weapon_id",
				""
			)
		)
		var weapon: Dictionary = _weapon_contract(
			weapon_id
		)
		var fighters: Dictionary = _dict(
			state.get(
				"fighters",
				{}
			)
		)

		for raw_target_key in fighters.keys():
			var target_key: String = str(
				raw_target_key
			)

			if target_key == source_identity_key:
				continue

			var target: Dictionary = _dict(
				fighters.get(
					target_key,
					{}
				)
			)

			if (
				target.is_empty()
				or int(
					target.get(
						"health",
						0
					)
				) <= 0
			):
				continue

			if not _projectile_segment_hits_fighter(
				previous_x,
				previous_y,
				current_x,
				current_y,
				target
			):
				continue

			if float(
				projectile.get(
					"explosion_radius",
					0.0
				)
			) > 0.0:
				_resolve_weapon_projectile_explosion(
					state,
					projectile,
					events
				)
			elif not weapon.is_empty():
				var minimum_damage: int = int(
					projectile.get(
						"damage_min",
						int(
							weapon.get(
								"minimum_damage",
								8
							)
						)
					)
				)
				var maximum_damage: int = int(
					projectile.get(
						"damage_max",
						int(
							weapon.get(
								"maximum_damage",
								16
							)
						)
					)
				)
				var damage: int = _roll(
					state,
					(
						"%s:%s:%s:projectile_damage"
						% [
							source_identity_key,
							target_key,
							str(
								projectile.get(
									"projectile_id",
									"projectile"
								)
							)
						]
					),
					minimum_damage,
					maximum_damage
				)

				_apply_weapon_damage(
					state,
					source_identity_key,
					target_key,
					weapon,
					damage,
					events
				)

			consumed = true
			break

		if consumed:
			continue

		if _projectile_crosses_solid_platform(
			arena,
			current_x,
			previous_y,
			current_y
		):
			if float(
				projectile.get(
					"explosion_radius",
					0.0
				)
			) > 0.0:
				_resolve_weapon_projectile_explosion(
					state,
					projectile,
					events
				)

			continue

		if (
			current_x < -12.0
			or current_x > 112.0
			or current_y > float(
				arena.get(
					"height",
					56.0
				)
			) + 20.0
			or int(
				projectile.get(
					"ttl_steps",
					0
				)
			) <= 0
		):
			if float(
				projectile.get(
					"explosion_radius",
					0.0
				)
			) > 0.0:
				_resolve_weapon_projectile_explosion(
					state,
					projectile,
					events
				)

			continue

		retained.append(
			projectile
		)

	state [
		"projectiles"
	] = retained



func _nearest_weapon_drop_index(
	state: Dictionary,
	fighter: Dictionary
) -> int:
	var fighter_x: float = float(
		fighter.get(
			"x",
			50.0
		)
	)
	var fighter_y: float = _stick_fighter_body_center_y(
		fighter
	)
	var best_index: int = -1
	var best_distance: float = INF

	var drops: Array = _array(
		state.get(
			"weapon_drops",
			[]
		)
	)

	for index in range(
		drops.size()
	):
		var drop: Dictionary = _dict(
			drops [
				index
			]
		)
		var dx: float = absf(
			float(
				drop.get(
					"x",
					0.0
				)
			) - fighter_x
		)
		var dy: float = absf(
			float(
				drop.get(
					"y",
					50.0
				)
			) - fighter_y
		)

		if (
			dx > 4.8
			or dy > 5.2
		):
			continue

		var distance: float = (
			dx + dy
		)

		if distance < best_distance:
			best_distance = distance
			best_index = index

	return best_index


func _pickup_nearest_weapon(
	state: Dictionary,
	identity_key: String,
	events: Array
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var fighter: Dictionary = _dict(
		fighters.get(
			identity_key,
			{}
		)
	).duplicate(false)

	if (
		fighter.is_empty()
		or int(
			fighter.get(
				"health",
				0
			)
		) <= 0
	):
		return

	var drop_index: int = _nearest_weapon_drop_index(
		state,
		fighter
	)

	if drop_index < 0:
		return

	var drops: Array = _array(
		state.get(
			"weapon_drops",
			[]
		)
	)
	var drop: Dictionary = _dict(
		drops [
			drop_index
		]
	)
	var weapon: Dictionary = _weapon_contract(
		str(
			drop.get(
				"weapon_id",
				""
			)
		)
	)

	if weapon.is_empty():
		return

	var equipped: Dictionary = {
		"weapon_id": str(
			weapon.get(
				"weapon_id",
				""
			)
		),
		"title": str(
			weapon.get(
				"title",
				"Weapon"
			)
		),
		"kind": str(
			weapon.get(
				"kind",
				"melee"
			)
		),
		"visual_kind": str(
			weapon.get(
				"visual_kind",
				"weapon"
			)
		),
		"rarity": str(
			weapon.get(
				"rarity",
				"common"
			)
		),
		"ammo": int(
			weapon.get(
				"ammo",
				-1
			)
		)
	}

	fighter ["equipped_weapon"] = equipped
	fighter ["state"] = "pickup"

	fighters [
		identity_key
	] = fighter

	drops.remove_at(
		drop_index
	)

	state ["fighters"] = fighters
	state ["weapon_drops"] = drops

	_append_weapon_pickup_sparkle_burst(
		state,
		fighter,
		str(
			weapon.get(
				"weapon_id",
				""
			)
		)
	)

	state ["last_event_text"] = (
		"%s picked up %s."
		% [
			str(
				fighter.get(
					"display_name",
					"Fighter"
				)
			),
			str(
				weapon.get(
					"title",
					"a weapon"
				)
			)
		]
	)

	events.append({
		"event_type": "stick_fighter_weapon_pickup",
		"simulation_step": int(
			state.get(
				"simulation_step",
				0
			)
		),
		"identity_key": identity_key,
		"weapon_id": str(
			weapon.get(
				"weapon_id",
				""
			)
		),
		"text": str(
			state.get(
				"last_event_text",
				"Weapon picked up."
			)
		)
	})
func _append_weapon_pickup_sparkle_burst(
	state: Dictionary,
	fighter: Dictionary,
	weapon_id: String
) -> void:
	var center_x: float = float(
		fighter.get(
			"x",
			50.0
		)
	)
	var center_y: float = _stick_fighter_body_center_y(
		fighter
	)

	for sparkle_index in range(
		8
	):
		var angle: float = (
			TAU
			/ 8.0
			* float(
				sparkle_index
			)
		)

		_append_combat_effect(
			state,
			{
				"effect_kind": "pickup_sparkle",
				"weapon_id": weapon_id,
				"x": center_x,
				"y": center_y,
				"vx": cos(angle) * 7.0,
				"vy": sin(angle) * 7.0 - 2.0,
				"gravity": 3.0,
				"ttl_steps": 18
			}
		)


func _guard_damage_scale_for_fighter(
	fighter: Dictionary
) -> float:
	if not bool(
		fighter.get(
			"guarding",
			false
		)
	):
		return 1.0

	var equipped: Dictionary = _equipped_weapon(
		fighter
	)

	var weapon: Dictionary = _weapon_contract(
		str(
			equipped.get(
				"weapon_id",
				""
			)
		)
	)

	return clampf(
		float(
			weapon.get(
				"guard_damage_scale",
				0.38
			)
		),
		0.05,
		1.0
	)
func _append_combat_effect(
	state: Dictionary,
	effect: Dictionary
) -> void:
	var effects: Array = _array(
		state.get(
			"combat_effects",
			[]
		)
	)

	var sequence: int = int(
		state.get(
			"combat_effect_sequence",
			0
		)
	) + 1

	var row: Dictionary = effect.duplicate(true)

	state [
		"combat_effect_sequence"
	] = sequence

	row [
		"effect_id"
	] = str(
		row.get(
			"effect_id",
			"fx_%d_%d"
			% [
				int(
					state.get(
						"simulation_step",
						0
					)
				),
				sequence
			]
		)
	)

	row [
		"ttl_steps"
	] = maxi(
		1,
		int(
			row.get(
				"ttl_steps",
				8
			)
		)
	)

	effects.append(
		row
	)

	while effects.size() > MAX_COMBAT_EFFECTS:
		effects.pop_front()

	state [
		"combat_effects"
	] = effects


func _service_combat_effects(
	state: Dictionary,
	fixed_delta: float
) -> void:
	var next_effects: Array = []

	for raw_effect in _array(
		state.get(
			"combat_effects",
			[]
		)
	):
		var effect: Dictionary = _dict(
			raw_effect
		).duplicate(false)

		var ttl_steps: int = int(
			effect.get(
				"ttl_steps",
				0
			)
		) - 1

		if ttl_steps <= 0:
			continue

		effect [
			"ttl_steps"
		] = ttl_steps

		effect [
			"x"
		] = float(
			effect.get(
				"x",
				50.0
			)
		) + float(
			effect.get(
				"vx",
				0.0
			)
		) * fixed_delta

		effect [
			"y"
		] = float(
			effect.get(
				"y",
				30.0
			)
		) + float(
			effect.get(
				"vy",
				0.0
			)
		) * fixed_delta

		effect [
			"vy"
		] = float(
			effect.get(
				"vy",
				0.0
			)
		) + float(
			effect.get(
				"gravity",
				0.0
			)
		) * fixed_delta

		next_effects.append(
			effect
		)

	state [
		"combat_effects"
	] = next_effects


func _spawn_weapon_projectiles(
	state: Dictionary,
	source_identity_key: String,
	weapon: Dictionary,
	launch_contract: Dictionary = {}
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var fighter: Dictionary = _dict(
		fighters.get(
			source_identity_key,
			{}
		)
	).duplicate(false)

	if fighter.is_empty():
		return

	var equipped: Dictionary = _equipped_weapon(
		fighter
	).duplicate(false)
	var ammo: int = int(
		equipped.get(
			"ammo",
			int(
				weapon.get(
					"ammo",
					0
				)
			)
		)
	)

	if ammo == 0:
		return

	if ammo > 0:
		equipped [
			"ammo"
		] = ammo - 1
		fighter [
			"equipped_weapon"
		] = equipped
		fighters [
			source_identity_key
		] = fighter
		state [
			"fighters"
		] = fighters

	var weapon_id: String = str(
		weapon.get(
			"weapon_id",
			""
		)
	)
	var facing: float = (
		-1.0
		if int(
			fighter.get(
				"facing",
				1
			)
		) < 0
		else 1.0
	)
	var speed: float = _stick_fighter_projectile_speed(
		weapon_id,
		float(
			weapon.get(
				"projectile_speed",
				48.0
			)
		)
	)
	var gravity: float = float(
		weapon.get(
			"projectile_gravity",
			0.0
		)
	)
	var projectile_kind: String = str(
		weapon.get(
			"projectile_kind",
			"bullet"
		)
	)
	var burst_count: int = maxi(
		1,
		int(
			weapon.get(
				"burst_count",
				1
			)
		)
	)
	var burst_center: float = (
		float(
			burst_count - 1
		) * 0.5
	)
	var projectiles: Array = _array(
		state.get(
			"projectiles",
			[]
		)
	)
	var sequence: int = int(
		state.get(
			"projectile_sequence",
			0
		)
	)
	var body_center_y: float = _stick_fighter_body_center_y(
		fighter
	)
	var muzzle_x: float = float(
		fighter.get(
			"x",
			50.0
		)
	) + facing * 2.1
	var muzzle_y: float = (
		body_center_y - 0.1
	)
	var fixed_step_hz: int = maxi(
		1,
		int(
			state.get(
				"fixed_step_hz",
				60
			)
		)
	)
	var charge_ratio: float = clampf(
		float(
			int(
				launch_contract.get(
					"charge_steps",
					0
				)
			)
		) / float(
			fixed_step_hz
		),
		0.0,
		1.0
	)
	var projectile_lifetime_steps: int = maxi(
		1,
		int(
			weapon.get(
				"projectile_lifetime_steps",
				180
			)
		)
	)

	for burst_index in range(
		burst_count
	):
		if projectiles.size() >= MAX_PROJECTILES:
			break

		sequence += 1

		var projectile_speed: float = speed
		var velocity_y: float = (
			(
				float(
					burst_index
				) - burst_center
			) * 0.28
		)
		var spawn_x: float = (
			muzzle_x
			+ facing * float(
				burst_index
			) * 0.65
		)
		var damage_min: int = int(
			weapon.get(
				"minimum_damage",
				weapon.get(
					"damage_min",
					8
				)
			)
		)
		var damage_max: int = int(
			weapon.get(
				"maximum_damage",
				weapon.get(
					"damage_max",
					16
				)
			)
		)

		if weapon_id == "uzi":
			damage_min = 3
			damage_max = 6

		if projectile_kind == "grenade":
			projectile_speed = lerpf(
				14.0,
				30.0,
				charge_ratio
			)
			velocity_y = lerpf(
				-8.0,
				-22.0,
				charge_ratio
			)
			gravity = 20.0

		projectiles.append({
			"projectile_id": (
				"projectile_%d"
				% sequence
			),
			"source_identity_key": source_identity_key,
			"weapon_id": weapon_id,
			"projectile_kind": projectile_kind,
			"x": spawn_x,
			"y": muzzle_y,
			"vx": facing * projectile_speed,
			"vy": velocity_y,
			"gravity": gravity,
			"damage_min": damage_min,
			"damage_max": damage_max,
			"explosion_radius": _stick_fighter_explosion_radius(
				weapon_id,
				float(
					weapon.get(
						"explosion_radius",
						0.0
					)
				)
			),
			"knockback_multiplier": float(
				weapon.get(
					"knockback_multiplier",
					1.0
				)
			),
			"visual_kind": str(
				weapon.get(
					"visual_kind",
					projectile_kind
				)
			),
			"ttl_steps": projectile_lifetime_steps
		})

	state [
		"projectile_sequence"
	] = sequence
	state [
		"projectiles"
	] = projectiles

	_append_combat_effect(
		state,
		{
			"effect_kind": "muzzle_flash",
			"x": muzzle_x,
			"y": muzzle_y,
			"vx": facing * 2.0,
			"vy": 0.0,
			"gravity": 0.0,
			"ttl_steps": 6
		}
	)

func _apply_weapon_hit_spatial_reaction(
	state: Dictionary,
	source_identity_key: String,
	damage: int,
	fighter: Dictionary,
	knockback_multiplier: float
) -> Dictionary:
	var original: Dictionary = fighter.duplicate(true)

	var reacted: Dictionary = _apply_hit_spatial_reaction(
		state,
		source_identity_key,
		"punch",
		damage,
		fighter
	)

	var multiplier: float = maxf(
		0.1,
		knockback_multiplier
	)

	reacted [
		"x"
	] = float(
		original.get(
			"x",
			50.0
		)
	) + (
		float(
			reacted.get(
				"x",
				50.0
			)
		)
		- float(
			original.get(
				"x",
				50.0
			)
		)
	) * multiplier

	if bool(
		original.get(
			"airborne",
			false
		)
	):
		reacted [
			"y"
		] = float(
			original.get(
				"y",
				50.0
			)
		) + (
			float(
				reacted.get(
					"y",
					50.0
				)
			)
			- float(
				original.get(
					"y",
					50.0
				)
			)
		) * multiplier

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	return _normalize_fighter_platform_after_move(
		arena,
		reacted
	)


func _publish_local_weapon_damage_feedback(
	state: Dictionary,
	source_identity_key: String,
	target_identity_key: String,
	damage: int
) -> void:
	if target_identity_key != str(
		state.get(
			"local_player_identity_key",
			""
		)
	):
		return

	state [
		"local_damage_flash_revision"
	] = int(
		state.get(
			"local_damage_flash_revision",
			0
		)
	) + 1

	state [
		"last_damage_feedback"
	] = {
		"revision": int(
			state [
				"local_damage_flash_revision"
			]
		),
		"amount": damage,
		"source_identity_key": source_identity_key,
		"target_identity_key": target_identity_key,
		"local_player_damaged": true,
		"truth_state": "hot"
	}


func _apply_weapon_damage(
	state: Dictionary,
	source_identity_key: String,
	target_identity_key: String,
	weapon: Dictionary,
	damage: int,
	events: Array
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var source: Dictionary = _dict(
		fighters.get(
			source_identity_key,
			{}
		)
	).duplicate(false)
	var target: Dictionary = _dict(
		fighters.get(
			target_identity_key,
			{}
		)
	).duplicate(false)

	if source.is_empty() or target.is_empty():
		return

	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	if simulation_step <= int(
		target.get(
			"damage_protection_until_step",
			-1
		)
	):
		return

	var resolved_damage: int = clampi(
		damage,
		1,
		28
	)

	if bool(
		target.get(
			"guarding",
			false
		)
	):
		resolved_damage = maxi(
			1,
			int(
				round(
					float(
						resolved_damage
					) * _guard_damage_scale_for_fighter(
						target
					)
				)
			)
		)

	target [
		"health"
	] = maxi(
		0,
		int(
			target.get(
				"health",
				MAX_HEALTH
			)
		) - resolved_damage
	)
	target [
		"last_damage_step"
	] = simulation_step
	target [
		"hit_flash_until_step"
	] = simulation_step + 8
	target [
		"lowest_health"
	] = mini(
		int(
			target.get(
				"lowest_health",
				MAX_HEALTH
			)
		),
		int(
			target.get(
				"health",
				0
			)
		)
	)
	target [
		"damage_taken"
	] = int(
		target.get(
			"damage_taken",
			0
		)
	) + resolved_damage
	source [
		"damage_dealt"
	] = int(
		source.get(
			"damage_dealt",
			0
		)
	) + resolved_damage
	source [
		"special_meter"
	] = mini(
		100,
		int(
			source.get(
				"special_meter",
				0
			)
		) + resolved_damage * 3
	)
	target [
		"special_meter"
	] = mini(
		100,
		int(
			target.get(
				"special_meter",
				0
			)
		) + resolved_damage * 2
	)
	target [
		"state"
	] = (
		"knockout"
		if int(
			target.get(
				"health",
				0
			)
		) <= 0
		else "hurt"
	)

	fighters [
		source_identity_key
	] = source
	state [
		"fighters"
	] = fighters

	target = _apply_weapon_hit_spatial_reaction(
		state,
		source_identity_key,
		resolved_damage,
		target,
		float(
			weapon.get(
				"knockback_multiplier",
				1.0
			)
		)
	)
	target = _resolve_blast_zone_elimination(
		state,
		source_identity_key,
		target_identity_key,
		str(
			weapon.get(
				"weapon_id",
				"weapon"
			)
		),
		resolved_damage,
		target
	)

	fighters = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	fighters [
		target_identity_key
	] = target
	state [
		"fighters"
	] = fighters

	_append_combat_effect(
		state,
		{
			"effect_kind": "blood_spray",
			"x": float(
				target.get(
					"x",
					50.0
				)
			),
			"y": _stick_fighter_body_center_y(
				target
			),
			"vx": (
				4.0
				if float(
					target.get(
						"x",
						50.0
					)
				) >= float(
					source.get(
						"x",
						50.0
					)
				)
				else -4.0
			),
			"vy": -5.0,
			"gravity": 16.0,
			"ttl_steps": 16
		}
	)

	_publish_local_weapon_damage_feedback(
		state,
		source_identity_key,
		target_identity_key,
		resolved_damage
	)

	var event_text: String = (
		"%s hit %s with %s for %d."
		% [
			str(
				source.get(
					"display_name",
					"Fighter"
				)
			),
			str(
				target.get(
					"display_name",
					"Fighter"
				)
			),
			str(
				weapon.get(
					"title",
					"weapon"
				)
			),
			resolved_damage
		]
	)

	state [
		"last_event_text"
	] = event_text

	events.append({
		"event_type": "stick_fighter_weapon_hit",
		"simulation_step": simulation_step,
		"source_identity_key": source_identity_key,
		"target_identity_key": target_identity_key,
		"weapon_id": str(
			weapon.get(
				"weapon_id",
				""
			)
		),
		"damage": resolved_damage,
		"text": event_text
	})
func _extract_human_weapon_extension_intents(
	state: Dictionary,
	input_snapshot: Dictionary
) -> Dictionary:
	var sanitized: Dictionary = input_snapshot.duplicate(true)
	var weapon_intents: Array = []
	var pickup_identity_keys: Dictionary = {}

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	for raw_identity_key in sanitized.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		var input_row: Dictionary = _dict(
			sanitized.get(
				identity_key,
				{}
			)
		).duplicate(false)

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		var equipped: Dictionary = _equipped_weapon(
			fighter
		).duplicate(false)

		var retained_edges: Array = []

		for raw_edge in _array(
			input_row.get(
				"edges",
				[]
			)
		):
			var edge: Dictionary = _dict(
				raw_edge
			)

			var action_id: String = _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			)

			var pressed: bool = bool(
				edge.get(
					"pressed",
					true
				)
			)

			if action_id == "pickup":
				if pressed:
					pickup_identity_keys [
						identity_key
					] = true
				continue

			if (
				action_id == "punch"
				and not equipped.is_empty()
			):
				var weapon: Dictionary = _weapon_contract(
					str(
						equipped.get(
							"weapon_id",
							""
						)
					)
				)

				var projectile_kind: String = _id(
					str(
						weapon.get(
							"projectile_kind",
							""
						)
					)
				)

				if projectile_kind == "grenade":
					var available_ammo: int = int(
						equipped.get(
							"ammo",
							int(
								weapon.get(
									"ammo",
									0
								)
							)
						)
					)

					if available_ammo == 0:
						continue

					if pressed:
						if not bool(
							equipped.get(
								"grenade_aim_active",
								false
							)
						):
							equipped [
								"grenade_aim_active"
							] = true
							equipped [
								"grenade_charge_started_step"
							] = simulation_step
							equipped [
								"grenade_charge_ratio"
							] = 0.0
							fighter [
								"equipped_weapon"
							] = equipped
							fighter [
								"state"
							] = "grenade_aim"
							fighters [
								identity_key
							] = fighter
					else:
						if bool(
							equipped.get(
								"grenade_aim_active",
								false
							)
						):
							var charge_steps: int = maxi(
								1,
								simulation_step
								- int(
									equipped.get(
										"grenade_charge_started_step",
										simulation_step
									)
								)
							)

							weapon_intents.append({
								"identity_key": identity_key,
								"source_snapshot": fighter.duplicate(true),
								"input_sequence": int(
									edge.get(
										"input_sequence",
										0
									)
								),
								"charge_steps": charge_steps,
							})

							equipped [
								"grenade_aim_active"
							] = false
							equipped [
								"grenade_charge_ratio"
							] = 0.0
							fighter [
								"equipped_weapon"
							] = equipped
							fighters [
								identity_key
							] = fighter

					continue

				if pressed:
					weapon_intents.append({
						"identity_key": identity_key,
						"source_snapshot": fighter.duplicate(true),
						"input_sequence": int(
							edge.get(
								"input_sequence",
								0
							)
						)
					})
				continue

			if not pressed:
				continue

			retained_edges.append(
				edge.duplicate(true)
			)

		input_row [
			"edges"
		] = retained_edges

		sanitized [
			identity_key
		] = input_row

	state [
		"fighters"
	] = fighters

	return {
		"input_snapshot": sanitized,
		"weapon_intents": weapon_intents,
		"pickup_identity_keys": pickup_identity_keys
	}

func _sanitize_drop_through_inputs(
	state: Dictionary,
	input_snapshot: Dictionary
) -> Dictionary:
	var out: Dictionary = input_snapshot.duplicate(true)

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	for raw_identity_key in out.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		var fighter: Dictionary = _fighter(
			state,
			identity_key
		)

		var input_row: Dictionary = _dict(
			out.get(
				identity_key,
				{}
			)
		).duplicate(false)

		var retained_edges: Array = []

		for raw_edge in _array(
			input_row.get(
				"edges",
				[]
			)
		):
			var edge: Dictionary = _dict(
				raw_edge
			)

			var action_id: String = _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			)

			if (
				action_id == "drop_down"
				and not _fighter_can_drop_through(
					arena,
					fighter
				)
			):
				continue

			retained_edges.append(
				edge.duplicate(true)
			)

		input_row [
			"edges"
		] = retained_edges

		out [
			identity_key
		] = input_row

	return out


func _append_ai_weapon_extension_intents(
	state: Dictionary,
	pre_step_fighters: Dictionary,
	weapon_intents: Array,
	pickup_identity_keys: Dictionary
) -> void:
	var step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	var extension_steps: Dictionary = _dict(
		state.get(
			"ai_extension_action_step_by_identity",
			{}
		)
	)

	for raw_participant in _array(
		state.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)

		if not (
			bool(
				participant.get(
					"is_ai",
					false
				)
			)
			or str(
				participant.get(
					"controller",
					""
				)
			) == "npc_ai"
		):
			continue

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _fighter(
			state,
			identity_key
		)

		if fighter.is_empty():
			continue

		if int(
			extension_steps.get(
				identity_key,
				-1
			)
		) != step:
			continue

		match str(
			fighter.get(
				"ai_action_id",
				""
			)
		):
			"pickup":
				pickup_identity_keys [
					identity_key
				] = true

			"weapon_primary":
				weapon_intents.append({
					"identity_key": identity_key,
					"source_snapshot": _dict(
						pre_step_fighters.get(
							identity_key,
							fighter
						)
					).duplicate(true),
					"input_sequence": step
				})

func advance_continuous_flash_simulation(
	session_state: Dictionary,
	input_snapshot: Dictionary,
	fixed_delta: float,
	context: Dictionary = {}
) -> Dictionary:
	if bool(
		session_state.get(
			"complete",
			false
		)
	):
		return {
			"success": true,
			"provider_state": session_state,
			"events": [],
			"complete": true
		}

	_ensure_stick_fighter_round_extension_state(
		session_state
	)

	var countdown_handoff_events: Array = []







	if str(
		session_state.get(
			"phase",
			"fighting"
		)
	) == "countdown":
		var countdown_drop_started: bool = bool(
			session_state.get(
				"countdown_drop_started",
				false
			)
		)

		if not countdown_drop_started:
			var countdown_step: int = int(
				session_state.get(
					"simulation_step",
					0
				)
			) + 1

			session_state [
				"simulation_step"
			] = countdown_step

			session_state [
				"simulation_time_sec"
			] = float(
				session_state.get(
					"simulation_time_sec",
					0.0
				)
			) + fixed_delta

			var countdown_events: Array = (
				_advance_continuous_match_countdown(
					session_state,
					fixed_delta
				)
			)

			_service_combat_effects(
				session_state,
				fixed_delta
			)

			return {
				"success": true,
				"provider_state": session_state,
				"events": countdown_events,
				"complete": bool(
					session_state.get(
						"complete",
						false
					)
				)
			}

		var current_step: int = int(
			session_state.get(
				"simulation_step",
				0
			)
		)
		var countdown_live_until_step: int = int(
			session_state.get(
				"countdown_live_until_step",
				current_step
			)
		)

		if current_step >= countdown_live_until_step:
			session_state ["phase"] = "fighting"
			session_state ["countdown_value"] = 0
			session_state ["countdown_elapsed_sec"] = float(
				COUNTDOWN_SECONDS
			)
			session_state ["last_event_text"] = "FIGHT!"
			session_state ["fight_banner_until_step"] = (
				current_step + 30
			)

			countdown_handoff_events.append({
				"event_type": "stick_fighter_fight_started",
				"simulation_step": current_step,
				"round": int(
					session_state.get(
						"round",
						1
					)
				),
				"text": "FIGHT!"
			})



	var pre_step_fighters: Dictionary = _dict(
		session_state.get(
			"fighters",
			{}
		)
	).duplicate(true)

	var extension_contract: Dictionary = (
		_extract_human_weapon_extension_intents(
			session_state,
			input_snapshot
		)
	)

	var sanitized_input: Dictionary = (
		_sanitize_drop_through_inputs(
			session_state,
			_dict(
				extension_contract.get(
					"input_snapshot",
					{}
				)
			)
		)
	)

	var combo_intents: Dictionary = (
		_stick_fighter_combo_intents(
			session_state,
			sanitized_input,
			pre_step_fighters
		)
	)

	sanitized_input = _strip_sweep_drop_edges(
		sanitized_input,
		combo_intents
	)

	sanitized_input = _apply_stick_fighter_double_jump_edges(
		session_state,
		sanitized_input
	)

	var weapon_intents: Array = _array(
		extension_contract.get(
			"weapon_intents",
			[]
		)
	)

	var pickup_identity_keys: Dictionary = _dict(
		extension_contract.get(
			"pickup_identity_keys",
			{}
		)
	)

	session_state [
		"round_resolution_deferred"
	] = true

	var base_report: Dictionary = advance_continuous_simulation(
		session_state,
		sanitized_input,
		fixed_delta,
		context
	)

	var state: Dictionary = _dict(
		base_report.get(
			"provider_state",
			session_state
		)
	)

	var events: Array = (
		countdown_handoff_events.duplicate(true)
	)

	events.append_array(
		_array(
			base_report.get(
				"events",
				[]
			)
		).duplicate(true)
	)

	state ["round_resolution_deferred"] = false

	_apply_advanced_bare_combat_labels(
		state,
		events,
		combo_intents
	)

	_service_ai_recovery_jumps(
		state
	)

	_append_ai_weapon_extension_intents(
		state,
		pre_step_fighters,
		weapon_intents,
		pickup_identity_keys
	)

	for raw_identity_key in pickup_identity_keys.keys():
		_pickup_nearest_weapon(
			state,
			str(
				raw_identity_key
			),
			events
		)

	_resolve_weapon_primary_intents(
		state,
		weapon_intents,
		events
	)

	_service_weapon_projectiles(
		state,
		fixed_delta,
		events
	)

	_service_weapon_drops(
		state,
		events
	)

	_service_combat_effects(
		state,
		fixed_delta
	)

	_normalize_stick_fighter_transient_states(
		state,
		pre_step_fighters
	)

	_service_stock_respawns(
		state,
		events
	)

	var round_report: Dictionary = (
		_resolve_stock_round_if_needed(
			state
		)
		if bool(
			state.get(
				"stock_mode",
				false
			)
		)
		else _resolve_continuous_round_if_needed(
			state
		)
	)

	if (
		bool(
			round_report.get(
				"round_resolved",
				false
			)
		)
		and not bool(
			round_report.get(
				"match_complete",
				false
			)
		)
		and not bool(
			state.get(
				"draw",
				false
			)
		)
	):
		var round_result_text: String = str(
			state.get(
				"last_event_text",
				"Round complete."
			)
		)

		_prepare_continuous_round_countdown(
			state
		)

		_ensure_stick_fighter_round_extension_state(
			state
		)

		state [
			"round_result_text"
		] = round_result_text

	return {
		"success": true,
		"provider_state": state,
		"events": events,
		"complete": bool(
			state.get(
				"complete",
				false
			)
		)
	}
func _fighter_animation_contract(
	session_state: Dictionary,
	fighter: Dictionary
) -> Dictionary:
	var simulation_step: int = int(
		session_state.get(
			"simulation_step",
			0
		)
	)
	var state_id: String = _id(
		str(
			fighter.get(
				"state",
				"idle"
			)
		)
	)
	var animation_id: String = state_id
	var duration_steps: int = 1
	var progress: float = 0.0
	var active: bool = true
	var cooldown_steps: int = maxi(
		0,
		int(
			fighter.get(
				"attack_cooldown_steps",
				0
			)
		)
	)

	match state_id:
		"punch":
			animation_id = (
				"air_punch"
				if bool(
					fighter.get(
						"airborne",
						false
					)
				)
				else "punch"
			)
			duration_steps = 8
			active = cooldown_steps > 0
			progress = clampf(
				1.0
				- float(cooldown_steps)
				/ float(duration_steps),
				0.0,
				1.0
			)

		"air_punch":
			duration_steps = 8
			active = cooldown_steps > 0
			progress = clampf(
				1.0
				- float(cooldown_steps)
				/ float(duration_steps),
				0.0,
				1.0
			)

		"kick", "sweep":
			duration_steps = 12
			active = cooldown_steps > 0
			progress = clampf(
				1.0
				- float(cooldown_steps)
				/ float(duration_steps),
				0.0,
				1.0
			)

		"special":
			duration_steps = 18
			active = cooldown_steps > 0
			progress = clampf(
				1.0
				- float(cooldown_steps)
				/ float(duration_steps),
				0.0,
				1.0
			)

		"weapon_attack", "fire":
			var equipped: Dictionary = _equipped_weapon(
				fighter
			)
			var weapon: Dictionary = _weapon_contract(
				str(
					equipped.get(
						"weapon_id",
						""
					)
				)
			)

			duration_steps = maxi(
				6,
				_weapon_fire_cooldown_steps(
					str(
						weapon.get(
							"weapon_id",
							""
						)
					),
					int(
						weapon.get(
							"cooldown_steps",
							12
						)
					)
				)
			)
			active = cooldown_steps > 0
			progress = clampf(
				1.0
				- float(cooldown_steps)
				/ float(duration_steps),
				0.0,
				1.0
			)

		"swept_fall":
			var started_step: int = int(
				fighter.get(
					"swept_fall_started_step",
					simulation_step
				)
			)
			var until_step: int = int(
				fighter.get(
					"swept_fall_until_step",
					simulation_step
				)
			)

			duration_steps = maxi(
				1,
				until_step
				- started_step
			)
			active = (
				simulation_step
				<= until_step
			)
			progress = clampf(
				float(
					simulation_step
					- started_step
				)
				/ float(
					duration_steps
				),
				0.0,
				1.0
			)

		_:
			progress = 0.0

	if (
		not active
		and state_id in [
			"punch",
			"air_punch",
			"kick",
			"sweep",
			"special",
			"weapon_attack",
			"fire"
		]
	):
		animation_id = "idle"

	return {
		"animation_id": animation_id,
		"progress": progress,
		"duration_steps": duration_steps,
		"active": active,
		"movement_axis": float(
			fighter.get(
				"movement_axis",
				0.0
			)
		),
		"ui_is_renderer_only": true
	}
func _clear_continuous_round_transients(
	state: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_key in fighters.keys():
		var fighter: Dictionary = _dict(
			fighters.get(
				raw_key,
				{}
			)
		).duplicate(false)

		fighter [
			"attack_cooldown_steps"
		] = 0
		fighter [
			"vertical_transition_active"
		] = false
		fighter [
			"vertical_transition_kind"
		] = ""
		fighter [
			"vertical_transition_elapsed"
		] = 0.0
		fighter [
			"vertical_transition_duration"
		] = 0.0
		fighter [
			"ai_action_id"
		] = ""
		fighter [
			"ai_next_decision_step"
		] = int(
			state.get(
				"simulation_step",
				0
			)
		)

		fighters [
			raw_key
		] = fighter

	state [
		"fighters"
	] = fighters
func result_contract(session_state: Dictionary) -> Dictionary:
	var complete: bool = bool(session_state.get("complete", false))
	var winner_key: String = str(session_state.get("winner_identity_key", ""))
	var scores: Dictionary = {}
	var winner_fighter: Dictionary = _fighter(session_state, winner_key)
	var comeback: bool = false
	var flawless: bool = false

	for raw_key in _dict(session_state.get("fighters", {})).keys():
		var fighter: Dictionary = _fighter(session_state, str(raw_key))
		scores [str(raw_key)] = (
			int(fighter.get("round_wins", 0)) * 100 + int(fighter.get("health", 0))
		)

	if not winner_fighter.is_empty():
		comeback = int(winner_fighter.get("lowest_health", MAX_HEALTH)) < 20
		flawless = int(winner_fighter.get("health", 0)) >= MAX_HEALTH

	return {
		"schema": "eralife.stick_fighter_result_contract",
		"version": 1,
		"complete": complete,
		"winner_identity_key": winner_key,
		"draw": bool(session_state.get("draw", false)),
		"scores": scores,
		"round": int(session_state.get("round", 1)),
		"comeback": comeback,
		"flawless": flawless,
		"text": _result_text(session_state)
	}


func ui_projection(
	session_state: Dictionary
) -> Dictionary:
	var stage_contract: Dictionary = _dict(
		session_state.get(
			"arena_contract",
			{}
		)
	).duplicate(true)

	if stage_contract.is_empty():
		stage_contract = _arena_contract_for_map_size(
			str(
				session_state.get(
					"arena_id",
					"neon_alley"
				)
			),
			str(
				session_state.get(
					"map_size_id",
					"standard"
				)
			)
		)

	var stage_width: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"width",
				100.0
			)
		)
	)
	var stage_height: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"height",
				56.0
			)
		)
	)
	var blast_margin_x: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_x",
				12.0
			)
		)
	)
	var blast_margin_y: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_y",
				10.0
			)
		)
	)
	var participant_count: int = _array(
		session_state.get(
			"participants",
			[]
		)
	).size()
	var derived_stock_mode: bool = bool(
		session_state.get(
			"stock_mode",
			int(
				session_state.get(
					"fighter_count",
					participant_count
				)
			) >= 3
		)
	)
	var derived_stock_lives: int = int(
		session_state.get(
			"stock_lives_per_round",
			(
				STOCK_LIVES_PER_ROUND
				if derived_stock_mode
				else 1
			)
		)
	)
	var fighters: Array = []

	for raw_participant in _array(
		session_state.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)
		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)
		var fighter: Dictionary = _fighter(
			session_state,
			identity_key
		)

		if fighter.is_empty():
			continue

		var row: Dictionary = fighter.duplicate(true)

		row ["controller"] = str(
			participant.get(
				"controller",
				""
			)
		)
		row ["is_ai"] = bool(
			participant.get(
				"is_ai",
				false
			)
		)
		row ["fighter_index"] = int(
			participant.get(
				"fighter_index",
				fighters.size()
			)
		)
		row ["stage_x"] = clampf(
			float(
				fighter.get(
					"x",
					50.0
				)
			),
			- blast_margin_x,
			stage_width + blast_margin_x
		)
		row ["stage_y"] = clampf(
			float(
				fighter.get(
					"y",
					50.0
				)
			),
			-18.0,
			stage_height + blast_margin_y + 2.0
		)
		row ["platform_id"] = str(
			fighter.get(
				"platform_id",
				"ground"
			)
		)
		row ["simulation_step"] = int(
			session_state.get(
				"simulation_step",
				0
			)
		)
		row ["animation_contract"] = _fighter_animation_contract(
			session_state,
			fighter
		)
		row ["stock_lives_remaining"] = int(
			fighter.get(
				"stock_lives_remaining",
				derived_stock_lives
			)
		)
		row ["respawn_pending"] = bool(
			fighter.get(
				"respawn_pending",
				false
			)
		)
		row ["eliminated"] = bool(
			fighter.get(
				"eliminated",
				false
			)
		)

		fighters.append(
			row
		)

	stage_contract ["coordinate_mode"] = "normalized_2d_stage"
	stage_contract ["collision_mode"] = "provider_resolved"
	stage_contract ["physics_authority"] = PROVIDER_ID
	stage_contract ["truth_state"] = "hot"

	var projected_weapon_drops: Array = []

	for raw_drop in _array(
		session_state.get(
			"weapon_drops",
			[]
		)
	):
		var drop: Dictionary = _dict(
			raw_drop
		).duplicate(true)
		var weapon: Dictionary = _weapon_contract(
			str(
				drop.get(
					"weapon_id",
					""
				)
			)
		)

		if not weapon.is_empty():
			drop ["visual_kind"] = str(
				weapon.get(
					"visual_kind",
					"weapon"
				)
			)
			drop ["rarity"] = str(
				weapon.get(
					"rarity",
					"common"
				)
			)

		projected_weapon_drops.append(
			drop
		)

	var controls_key: Array = [
		{
			"label": "MOVE",
			"actions": "A / D or ← / →",
			"description": "Hold to move continuously."
		},
		{
			"label": "JUMP / DROP",
			"actions": "W / S or ↑ / ↓",
			"description": (
				"W / ↑ jumps. Press jump again in the air for the "
				+ "second jump. S / ↓ drops through authored "
				+ "pass-through platforms."
			)
		},
		{
			"label": "PRIMARY / AIR PUNCH",
			"actions": "Z / J",
			"description": (
				"Punch unarmed; swing or fire the equipped weapon. "
				+ "While airborne, Z / J becomes AIR PUNCH."
			)
		},
		{
			"label": "KICK / SWEEP",
			"actions": "X / K",
			"description": (
				"Kick normally. Hold S / ↓ + X / K while grounded "
				+ "to SWEEP."
			)
		},
		{
			"label": "BLOCK",
			"actions": "C / L • HOLD",
			"description": (
				"Hold to guard. Shields strengthen weapon blocking."
			)
		},
		{
			"label": "SPECIAL",
			"actions": "V / SPACE",
			"description": "Spend a full special meter."
		},
		{
			"label": "PICK UP",
			"actions": "TAB",
			"description": "Pick up the nearest glowing weapon drop."
		}
	]

	return {
		"schema": "eralife.flash_ui_projection",
		"version": 5,
		"projection_kind": "stick_fighter_stage",
		"provider_id": PROVIDER_ID,
		"simulation_mode": "fixed_step_continuous",
		"continuous_simulation": true,
		"simulation_step": int(
			session_state.get(
				"simulation_step",
				0
			)
		),
		"simulation_time_sec": float(
			session_state.get(
				"simulation_time_sec",
				0.0
			)
		),
		"arena_id": str(
			session_state.get(
				"arena_id",
				"neon_alley"
			)
		),
		"map_size_id": str(
			session_state.get(
				"map_size_id",
				"standard"
			)
		),
		"map_size_title": str(
			session_state.get(
				"map_size_title",
				"STANDARD"
			)
		),
		"stage": str(
			session_state.get(
				"stage",
				"Neon Alley"
			)
		),
		"fighter_count": int(
			session_state.get(
				"fighter_count",
				fighters.size()
			)
		),
		"opponent_count": int(
			session_state.get(
				"opponent_count",
				maxi(
					0,
					fighters.size() - 1
				)
			)
		),
		"stock_mode": derived_stock_mode,
		"stock_lives_per_round": derived_stock_lives,
		"round": int(
			session_state.get(
				"round",
				1
			)
		),
		"phase": str(
			session_state.get(
				"phase",
				"fighting"
			)
		),
		"countdown_from": int(
			session_state.get(
				"countdown_from",
				COUNTDOWN_SECONDS
			)
		),
		"countdown_value": int(
			session_state.get(
				"countdown_value",
				0
			)
		),
		"countdown_drop_started": bool(
			session_state.get(
				"countdown_drop_started",
				false
			)
		),
		"fight_banner_visible": (
			str(
				session_state.get(
					"phase",
					"fighting"
				)
			) == "fighting"
			and int(
				session_state.get(
					"simulation_step",
					0
				)
			) <= int(
				session_state.get(
					"fight_banner_until_step",
					-1
				)
			)
		),
		"fighters": fighters,
		"stage_contract": stage_contract,
		"weapon_drops": projected_weapon_drops,
		"projectiles": _array(
			session_state.get(
				"projectiles",
				[]
			)
		).duplicate(true),
		"combat_effects": _array(
			session_state.get(
				"combat_effects",
				[]
			)
		).duplicate(true),
		"controls_key": controls_key,
		"damage_feedback": _dict(
			session_state.get(
				"last_damage_feedback",
				{}
			)
		).duplicate(true),
		"local_damage_flash_revision": int(
			session_state.get(
				"local_damage_flash_revision",
				0
			)
		),
		"blast_feedback_revision": int(
			session_state.get(
				"blast_feedback_revision",
				0
			)
		),
		"blast_feedback_events": _array(
			session_state.get(
				"blast_feedback_events",
				[]
			)
		).duplicate(true),
		"headline": str(
			session_state.get(
				"last_event_text",
				""
			)
		),
		"last_event_text": str(
			session_state.get(
				"last_event_text",
				""
			)
		),
		"complete": bool(
			session_state.get(
				"complete",
				false
			)
		),
		"winner_identity_key": str(
			session_state.get(
				"winner_identity_key",
				""
			)
		),
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}
func _apply_action(
	state: Dictionary,
	identity_key: String,
	action_id: String,
	context: Dictionary
) -> Dictionary:
	if bool(
		state.get(
			"complete",
			false
		)
	):
		return _failure(
			"session_complete",
			"This Stick Fighter match is over."
		)

	if str(
		state.get(
			"current_turn_identity_key",
			""
		)
	) != identity_key:
		return _failure(
			"not_current_turn",
			"It is not this fighter's committed turn."
		)

	var fighter: Dictionary = _fighter(
		state,
		identity_key
	)

	if (
		fighter.is_empty()
		or int(
			fighter.get(
				"health",
				0
			)
		) <= 0
	):
		return _failure(
			"fighter_unavailable",
			"That fighter cannot commit another action."
		)

	var opponent_key: String = (
		_target_key_for_action(
			state,
			identity_key,
			context
		)
	)

	var opponent: Dictionary = _fighter(
		state,
		opponent_key
	)

	if opponent.is_empty():
		return _failure(
			"opponent_missing",
			"No living Stick Fighter opponent is available."
		)

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)




	if bool(
		fighter.get(
			"airborne",
			false
		)
	):
		fighter [
			"airborne"
		] = false

		if _id(
			str(
				fighter.get(
					"platform_id",
					"ground"
				)
			)
		) == "air":
			var landing_platform: Dictionary = (
				_landing_platform_below_x(
					arena,
					float(
						fighter.get(
							"x",
							50.0
						)
					),
					float(
						fighter.get(
							"y",
							50.0
						)
					),
					0.0
				)
			)

			if landing_platform.is_empty():
				fighter = _fighter_into_abyss(
					arena,
					fighter
				)
			else:
				fighter [
					"platform_id"
				] = str(
					landing_platform.get(
						"platform_id",
						"ground"
					)
				)
				fighter [
					"y"
				] = float(
					landing_platform.get(
						"y",
						50.0
					)
				)
				fighter [
					"airborne"
				] = false

	fighter [
		"guarding"
	] = (
		false
		if action_id != "block"
		else bool(
			fighter.get(
				"guarding",
				false
			)
		)
	)

	var text: String = ""
	var damage: int = 0
	var stamina_cost: int = 0
	var hit: bool = true

	var horizontal_distance: float = absf(
		float(
			fighter.get(
				"x",
				0.0
			)
		)
		- float(
			opponent.get(
				"x",
				0.0
			)
		)
	)

	var vertical_distance: float = absf(
		float(
			fighter.get(
				"y",
				50.0
			)
		)
		- float(
			opponent.get(
				"y",
				50.0
			)
		)
	)

	var sequence: int = int(
		state.get(
			"turn_sequence",
			0
		)
	) + 1

	state [
		"turn_sequence"
	] = sequence

	match action_id:
		"move_left":
			fighter [
				"x"
			] = clampf(
				float(
					fighter.get(
						"x",
						0.0
					)
				) - 9.0,
				4.0,
				96.0
			)

			fighter = (
				_normalize_fighter_platform_after_move(
					arena,
					fighter
				)
			)

			fighter [
				"facing"
			] = -1

			if _id(
				str(
					fighter.get(
						"state",
						""
					)
				)
			) != "fall":
				fighter [
					"state"
				] = "walk"

			text = (
				"%s dashed left."
				% str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				)
			)

		"move_right":
			fighter [
				"x"
			] = clampf(
				float(
					fighter.get(
						"x",
						0.0
					)
				) + 9.0,
				4.0,
				96.0
			)

			fighter = (
				_normalize_fighter_platform_after_move(
					arena,
					fighter
				)
			)

			fighter [
				"facing"
			] = 1

			if _id(
				str(
					fighter.get(
						"state",
						""
					)
				)
			) != "fall":
				fighter [
					"state"
				] = "walk"

			text = (
				"%s dashed right."
				% str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				)
			)

		"jump":
			stamina_cost = 8

			if int(
				fighter.get(
					"stamina",
					0
				)
			) < stamina_cost:
				return _failure(
					"stamina_low",
					"That fighter is too tired to jump."
				)

			var destination_platform: Dictionary = (
				_jump_destination_platform(
					arena,
					fighter
				)
			)

			if not destination_platform.is_empty():
				fighter [
					"platform_id"
				] = str(
					destination_platform.get(
						"platform_id",
						"ground"
					)
				)

				fighter [
					"y"
				] = float(
					destination_platform.get(
						"y",
						50.0
					)
				)

				text = (
					"%s jumped onto %s."
					% [
						str(
							fighter.get(
								"display_name",
								"Fighter"
							)
						),
						str(
							destination_platform.get(
								"platform_id",
								"the platform"
							)
						).replace(
							"_",
							" "
						).capitalize()
					]
				)
			else:
				fighter [
					"platform_id"
				] = "air"
				fighter [
					"y"
				] = maxf(
					8.0,
					float(
						fighter.get(
							"y",
							50.0
						)
					) - 13.0
				)

				text = (
					"%s leaped into the air."
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)

			fighter [
				"airborne"
			] = true
			fighter [
				"state"
			] = "jump"

		"drop_down":
			var landing_platform: Dictionary = (
				_landing_platform_below_x(
					arena,
					float(
						fighter.get(
							"x",
							50.0
						)
					),
					float(
						fighter.get(
							"y",
							50.0
						)
					),
					0.01
				)
			)

			if landing_platform.is_empty():
				fighter = _fighter_into_abyss(
					arena,
					fighter
				)

				text = (
					"%s dropped into the abyss."
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)
			else:
				fighter [
					"platform_id"
				] = str(
					landing_platform.get(
						"platform_id",
						"ground"
					)
				)
				fighter [
					"y"
				] = float(
					landing_platform.get(
						"y",
						50.0
					)
				)
				fighter [
					"airborne"
				] = false
				fighter [
					"state"
				] = "drop"

				text = (
					"%s dropped to %s."
					% [
						str(
							fighter.get(
								"display_name",
								"Fighter"
							)
						),
						str(
							landing_platform.get(
								"platform_id",
								"the lower platform"
							)
						).replace(
							"_",
							" "
						).capitalize()
					]
				)

		"block":
			fighter [
				"guarding"
			] = true
			fighter [
				"state"
			] = "block"
			fighter [
				"stamina"
			] = mini(
				MAX_STAMINA,
				int(
					fighter.get(
						"stamina",
						0
					)
				) + 8
			)

			text = (
				"%s raised a guard."
				% str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				)
			)

		"punch":
			stamina_cost = 10

			if int(
				fighter.get(
					"stamina",
					0
				)
			) < stamina_cost:
				return _failure(
					"stamina_low",
					"That fighter is too tired to punch."
				)

			hit = (
				horizontal_distance <= 34.0
				and vertical_distance <= 14.0
				and _roll(
					state,
					"punch_hit",
					1,
					100
				) <= 88
			)

			damage = (
				_roll(
					state,
					"punch_damage",
					8,
					18
				)
				if hit
				else 0
			)

			fighter [
				"state"
			] = "punch"

			text = (
				"%s landed a punch."
				% str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				)
				if hit
				else (
					"%s swung and missed."
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)
			)

		"kick":
			stamina_cost = 18

			if int(
				fighter.get(
					"stamina",
					0
				)
			) < stamina_cost:
				return _failure(
					"stamina_low",
					"That fighter is too tired to kick."
				)

			hit = (
				horizontal_distance <= 42.0
				and vertical_distance <= 16.0
				and _roll(
					state,
					"kick_hit",
					1,
					100
				) <= 74
			)

			damage = (
				_roll(
					state,
					"kick_damage",
					13,
					26
				)
				if hit
				else 0
			)

			fighter [
				"state"
			] = "kick"

			text = (
				"%s cracked a heavy kick."
				% str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				)
				if hit
				else (
					"%s threw a wild kick and missed."
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)
			)

		"special":
			if int(
				fighter.get(
					"special_meter",
					0
				)
			) < 100:
				return _failure(
					"special_not_ready",
					"The special meter is not full."
				)

			hit = (
				horizontal_distance <= 52.0
				and vertical_distance <= 18.0
				and _roll(
					state,
					"special_hit",
					1,
					100
				) <= 92
			)

			damage = (
				_roll(
					state,
					"special_damage",
					24,
					42
				)
				if hit
				else 0
			)

			fighter [
				"special_meter"
			] = 0
			fighter [
				"state"
			] = "special"

			text = (
				(
					"%s unleashed a ridiculous stick-combo special!"
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)
				if hit
				else (
					"%s's special exploded into absolutely nothing."
					% str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					)
				)
			)

		_:
			return _failure(
				"unknown_action",
				"Stick Fighter did not recognize that action."
			)

	if stamina_cost > 0:
		fighter [
			"stamina"
		] = maxi(
			0,
			int(
				fighter.get(
					"stamina",
					0
				)
			) - stamina_cost
		)
	elif action_id != "block":
		fighter [
			"stamina"
		] = mini(
			MAX_STAMINA,
			int(
				fighter.get(
					"stamina",
					0
				)
			) + 4
		)

	if damage > 0:
		if bool(
			opponent.get(
				"guarding",
				false
			)
		):
			damage = maxi(
				1,
				int(
					round(
						float(
							damage
						) * 0.38
					)
				)
			)

			text += (
				" The guard absorbed most of it."
			)

		if (
			bool(
				opponent.get(
					"airborne",
					false
				)
			)
			and _roll(
				state,
				"air_evade",
				1,
				100
			) <= 35
		):
			damage = 0

			text = (
				"%s jumped over the attack."
				% str(
					opponent.get(
						"display_name",
						"Fighter"
					)
				)
			)

	if damage > 0:
		opponent [
			"health"
		] = maxi(
			0,
			int(
				opponent.get(
					"health",
					MAX_HEALTH
				)
			) - damage
		)

		opponent [
			"lowest_health"
		] = mini(
			int(
				opponent.get(
					"lowest_health",
					MAX_HEALTH
				)
			),
			int(
				opponent.get(
					"health",
					0
				)
			)
		)

		opponent [
			"damage_taken"
		] = int(
			opponent.get(
				"damage_taken",
				0
			)
		) + damage

		fighter [
			"damage_dealt"
		] = int(
			fighter.get(
				"damage_dealt",
				0
			)
		) + damage

		fighter [
			"special_meter"
		] = mini(
			100,
			int(
				fighter.get(
					"special_meter",
					0
				)
			) + damage * 3
		)

		opponent [
			"special_meter"
		] = mini(
			100,
			int(
				opponent.get(
					"special_meter",
					0
				)
			) + damage * 2
		)

		opponent [
			"state"
		] = (
			"knockout"
			if int(
				opponent.get(
					"health",
					0
				)
			) <= 0
			else "hurt"
		)

		if opponent_key == str(
			state.get(
				"local_player_identity_key",
				""
			)
		):
			state [
				"local_damage_flash_revision"
			] = int(
				state.get(
					"local_damage_flash_revision",
					0
				)
			) + 1

			state [
				"last_damage_feedback"
			] = {
				"revision": int(
					state [
						"local_damage_flash_revision"
					]
				),
				"amount": damage,
				"source_identity_key": identity_key,
				"target_identity_key": opponent_key,
				"local_player_damaged": true,
				"truth_state": "hot"
			}

	_set_fighter(
		state,
		identity_key,
		fighter
	)

	_set_fighter(
		state,
		opponent_key,
		opponent
	)

	state [
		"last_event_text"
	] = text

	var round_report: Dictionary = (
		_resolve_round_if_needed(
			state
		)
	)

	if not bool(
		round_report.get(
			"round_resolved",
			false
		)
	):
		state [
			"current_turn_identity_key"
		] = _next_turn_identity_key(
			state,
			identity_key
		)

	return {
		"success": true,
		"event": {
			"event_type": "stick_fighter_action",
			"actor_identity_key": identity_key,
			"target_identity_key": opponent_key,
			"action_id": action_id,
			"damage": damage,
			"text": text,
			"turn_sequence": sequence,
			"round": int(
				state.get(
					"round",
					1
				)
			)
		}
	}

func _resolve_round_if_needed(
	state: Dictionary
) -> Dictionary:
	var living_keys: Array = (
		_living_identity_keys(
			state
		)
	)

	var match_mode: String = str(
		state.get(
			"match_mode",
			"single_vs_ai"
		)
	)

	var local_player_key: String = str(
		state.get(
			"local_player_identity_key",
			""
		)
	)

	var round_winner_key: String = ""

	if match_mode == "single_vs_ai":
		var local_alive: bool = (
			local_player_key != ""
			and int(
				_fighter(
					state,
					local_player_key
				).get(
					"health",
					0
				)
			) > 0
		)

		var living_opponents: Array = []

		for raw_key in living_keys:
			var candidate_key: String = str(
				raw_key
			)

			if candidate_key != local_player_key:
				living_opponents.append(
					candidate_key
				)

		if (
			local_alive
			and not living_opponents.is_empty()
		):
			return {
				"round_resolved": false
			}

		if (
			local_alive
			and living_opponents.is_empty()
		):
			round_winner_key = (
				local_player_key
			)
		else:
			round_winner_key = (
				_highest_health_identity_key(
					state,
					living_opponents
				)
			)
	else:
		if living_keys.size() > 1:
			return {
				"round_resolved": false
			}

		if living_keys.size() == 1:
			round_winner_key = str(
				living_keys [
					0
				]
			)
		else:
			var fighter_keys: Array = _dict(
				state.get(
					"fighters",
					{}
				)
			).keys()

			round_winner_key = (
				_highest_health_identity_key(
					state,
					fighter_keys
				)
			)

	if round_winner_key == "":
		state [
			"draw"
		] = true

		return {
			"round_resolved": true,
			"match_complete": false,
			"draw": true
		}

	var round_winner: Dictionary = _fighter(
		state,
		round_winner_key
	)

	round_winner [
		"round_wins"
	] = int(
		round_winner.get(
			"round_wins",
			0
		)
	) + 1

	_set_fighter(
		state,
		round_winner_key,
		round_winner
	)

	if int(
		round_winner.get(
			"round_wins",
			0
		)
	) >= WIN_ROUNDS:
		state [
			"complete"
		] = true
		state [
			"phase"
		] = "complete"
		state [
			"winner_identity_key"
		] = round_winner_key
		state [
			"current_turn_identity_key"
		] = ""
		state [
			"last_event_text"
		] = (
			"%s won the match!"
			% str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			)
		)

		return {
			"round_resolved": true,
			"match_complete": true
		}

	state [
		"round"
	] = int(
		state.get(
			"round",
			1
		)
	) + 1

	_reset_round(
		state
	)

	state [
		"current_turn_identity_key"
	] = (
		local_player_key
		if (
			match_mode == "single_vs_ai"
			and local_player_key != ""
		)
		else round_winner_key
	)

	state [
		"last_event_text"
	] = (
		"%s won the round. ROUND %d!"
		% [
			str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			),
			int(
				state.get(
					"round",
					1
				)
			)
		]
	)

	return {
		"round_resolved": true,
		"match_complete": false
	}
func _highest_health_identity_key(
	state: Dictionary,
	candidate_keys: Array
) -> String:
	var best_key: String = ""
	var best_health: int = -1

	for raw_key in candidate_keys:
		var identity_key: String = str(
			raw_key
		)

		var health: int = int(
			_fighter(
				state,
				identity_key
			).get(
				"health",
				0
			)
		)

		if health > best_health:
			best_health = health
			best_key = identity_key

	return best_key

func _reset_round(
	state: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)

	var participants: Array = _array(
		state.get(
			"participants",
			[]
		)
	)

	for index in range(
		participants.size()
	):
		var participant: Dictionary = _dict(
			participants [
				index
			]
		)

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _fighter(
			state,
			identity_key
		)

		var spawn: Dictionary = (
			_spawn_contract_for_index(
				arena,
				index
			)
		)

		var platform_id: String = str(
			spawn.get(
				"platform_id",
				"ground"
			)
		)

		var spawn_x: float = float(
			spawn.get(
				"x",
				50.0
			)
		)

		fighter [
			"health"
		] = MAX_HEALTH
		fighter [
			"stamina"
		] = MAX_STAMINA
		fighter [
			"special_meter"
		] = 0
		fighter [
			"x"
		] = spawn_x
		fighter [
			"y"
		] = _platform_y(
			arena,
			platform_id
		)
		fighter [
			"platform_id"
		] = platform_id
		fighter [
			"facing"
		] = (
			1
			if spawn_x < 50.0
			else -1
		)
		fighter [
			"guarding"
		] = false
		fighter [
			"airborne"
		] = false
		fighter [
			"state"
		] = "idle"

		fighters [
			identity_key
		] = fighter

	state [
		"fighters"
	] = fighters


func _choose_ai_action(
	state: Dictionary,
	identity_key: String
) -> String:
	var fighter: Dictionary = _fighter(
		state,
		identity_key
	)

	if fighter.is_empty():
		return "block"

	var difficulty: Dictionary = _ai_difficulty_contract(
		state
	)
	var attack_ready: bool = _ai_attack_ready(
		state,
		identity_key
	)
	var target_key: String = _target_key_for_action(
		state,
		identity_key,
		{}
	)
	var opponent: Dictionary = _fighter(
		state,
		target_key
	)

	if opponent.is_empty():
		return "block"

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)

	var health: int = int(
		fighter.get(
			"health",
			100
		)
	)
	var stamina: int = int(
		fighter.get(
			"stamina",
			100
		)
	)
	var fighter_x: float = float(
		fighter.get(
			"x",
			0.0
		)
	)
	var opponent_x: float = float(
		opponent.get(
			"x",
			0.0
		)
	)
	var horizontal_distance: float = absf(
		fighter_x - opponent_x
	)
	var vertical_delta: float = (
		float(
			fighter.get(
				"y",
				50.0
			)
		)
		- float(
			opponent.get(
				"y",
				50.0
			)
		)
	)
	var airborne: bool = (
		bool(
			fighter.get(
				"airborne",
				false
			)
		)
		or bool(
			fighter.get(
				"vertical_transition_active",
				false
			)
		)
	)
	var equipped: Dictionary = _equipped_weapon(
		fighter
	)

	if equipped.is_empty():
		if (
			_nearest_weapon_drop_index(
				state,
				fighter
			) >= 0
			and _roll(
				state,
				"ai_pickup:%s"
				% identity_key,
				1,
				100
			) <= int(
				difficulty.get(
					"pickup_chance",
					65
				)
			)
		):
			_mark_ai_extension_action(
				state,
				identity_key
			)

			return "pickup"
	else:
		var weapon_contract: Dictionary = _weapon_contract(
			str(
				equipped.get(
					"weapon_id",
					""
				)
			)
		)
		var weapon_kind: String = str(
			weapon_contract.get(
				"kind",
				"melee"
			)
		)
		var ammo: int = int(
			equipped.get(
				"ammo",
				-1
			)
		)
		var weapon_in_range: bool = true

		if weapon_kind == "melee":
			var contact: Dictionary = _weapon_melee_contact_contract(
				str(
					weapon_contract.get(
						"weapon_id",
						""
					)
				)
			)
			var minimum_range_x: float = maxf(
				0.0,
				float(
					contact.get(
						"minimum_range_x",
						0.0
					)
				)
			)
			var maximum_range_x: float = maxf(
				minimum_range_x,
				float(
					contact.get(
						"maximum_range_x",
						5.4
					)
				)
			)
			var maximum_range_y: float = maxf(
				0.0,
				float(
					contact.get(
						"maximum_range_y",
						4.4
					)
				)
			)




			weapon_in_range = (
				horizontal_distance >= minimum_range_x
				and horizontal_distance <= minf(
					6.0,
					maximum_range_x
				)
				and absf(
					vertical_delta
				) <= maximum_range_y
			)

		if (
			attack_ready
			and ammo != 0
			and weapon_in_range
			and int(
				fighter.get(
					"attack_cooldown_steps",
					0
				)
			) <= 0
			and _roll(
				state,
				"ai_weapon:%s"
				% identity_key,
				1,
				100
			) <= int(
				difficulty.get(
					"weapon_attack_chance",
					42
				)
			)
		):
			_commit_ai_attack_lock(
				state,
				identity_key,
				difficulty
			)
			_mark_ai_extension_action(
				state,
				identity_key
			)

			return "weapon_primary"

	if airborne:
		return _ai_safe_horizontal_approach_action(
			arena,
			fighter,
			opponent
		)

	if (
		vertical_delta > 10.0
		and stamina >= 8
		and int(
			fighter.get(
				"jumps_remaining",
				MAX_JUMPS_PER_AIR_CYCLE
			)
		) > 0
	):
		return "jump"

	if (
		vertical_delta < -12.0
		and _fighter_can_drop_through(
			arena,
			fighter
		)
	):
		return "drop_down"

	if (
		attack_ready
		and int(
			fighter.get(
				"special_meter",
				0
			)
		) >= 100
		and horizontal_distance <= 6.0
		and absf(
			vertical_delta
		) <= 5.0
		and _roll(
			state,
			"ai_special:%s"
			% identity_key,
			1,
			100
		) <= int(
			difficulty.get(
				"special_attack_chance",
				65
			)
		)
	):
		_commit_ai_attack_lock(
			state,
			identity_key,
			difficulty
		)

		return "special"

	if (
		health < 24
		and _roll(
			state,
			"ai_block:%s"
			% identity_key,
			1,
			100
		) <= int(
			difficulty.get(
				"block_chance",
				54
			)
		)
	):
		return "block"

	if horizontal_distance > 5.4:
		return _ai_safe_horizontal_approach_action(
			arena,
			fighter,
			opponent
		)

	if not attack_ready:
		return "block"

	if (
		stamina >= 18
		and absf(
			vertical_delta
		) <= 4.5
		and _roll(
			state,
			"ai_kick:%s"
			% identity_key,
			1,
			100
		) <= int(
			difficulty.get(
				"kick_chance",
				36
			)
		)
	):
		_commit_ai_attack_lock(
			state,
			identity_key,
			difficulty
		)

		return "kick"

	if (
		stamina >= 10
		and absf(
			vertical_delta
		) <= 4.2
		and _roll(
			state,
			"ai_punch:%s"
			% identity_key,
			1,
			100
		) <= int(
			difficulty.get(
				"punch_chance",
				72
			)
		)
	):
		_commit_ai_attack_lock(
			state,
			identity_key,
			difficulty
		)

		return "punch"

	return _ai_safe_horizontal_approach_action(
		arena,
		fighter,
		opponent
	)
func _service_ai_recovery_jumps(
	state: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	for raw_participant in _array(
		state.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)

		if not bool(
			participant.get(
				"is_ai",
				false
			)
		):
			continue

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if (
			fighter.is_empty()
			or int(
				fighter.get(
					"health",
					0
				)
			) <= 0
			or int(
				fighter.get(
					"stamina",
					0
				)
			) < 8
			or int(
				fighter.get(
					"jumps_remaining",
					0
				)
			) <= 0
		):
			continue

		if str(
			fighter.get(
				"vertical_transition_kind",
				""
			)
		) != "fall":
			continue

		if str(
			fighter.get(
				"vertical_transition_target_platform_id",
				""
			)
		) != "blast_zone":
			continue

		var target_key: String = _target_key_for_action(
			state,
			identity_key,
			{}
		)
		var target: Dictionary = _fighter(
			state,
			target_key
		)

		if not target.is_empty():
			fighter ["facing"] = (
				-1
				if float(
					target.get(
						"x",
						50.0
					)
				) < float(
					fighter.get(
						"x",
						50.0
					)
				)
				else 1
			)

		fighter ["stamina"] = maxi(
			0,
			int(
				fighter.get(
					"stamina",
					0
				)
			) - 8
		)

		fighter = _begin_continuous_vertical_transition(
			arena,
			fighter,
			"jump"
		)

		fighters [
			identity_key
		] = fighter

	state ["fighters"] = fighters
func _stock_contender_identity_keys(
	state: Dictionary
) -> Array:
	var out: Array = []
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	for raw_identity_key in fighters.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		)

		if fighter.is_empty():
			continue

		if bool(
			fighter.get(
				"eliminated",
				false
			)
		):
			continue

		if (
			int(
				fighter.get(
					"stock_lives_remaining",
					0
				)
			) <= 0
			and not bool(
				fighter.get(
					"respawn_pending",
					false
				)
			)
			and int(
				fighter.get(
					"health",
					0
				)
			) <= 0
		):
			continue

		out.append(
			identity_key
		)

	return out


func _arm_stock_sudden_death(
	state: Dictionary,
	events: Array
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	for raw_identity_key in fighters.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if fighter.is_empty():
			continue

		fighter ["health"] = 0
		fighter ["stock_lives_remaining"] = 1
		fighter ["respawn_pending"] = true
		fighter ["respawn_at_step"] = (
			simulation_step
			+ STOCK_RESPAWN_DELAY_STEPS
		)
		fighter ["eliminated"] = false
		fighter ["eliminated_at_step"] = -1
		fighter ["state"] = "knockout"

		fighters [
			identity_key
		] = fighter

	state ["fighters"] = fighters
	state [
		"last_event_text"
	] = "SUDDEN DEATH! One final stock."

	events.append({
		"event_type": "stick_fighter_sudden_death",
		"simulation_step": simulation_step,
		"text": "SUDDEN DEATH! One final stock."
	})


func _service_stock_respawns(
	state: Dictionary,
	events: Array
) -> void:
	if not bool(
		state.get(
			"stock_mode",
			false
		)
	):
		return

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var participants: Array = _array(
		state.get(
			"participants",
			[]
		)
	)
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)
	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	for index in range(
		participants.size()
	):
		var participant: Dictionary = _dict(
			participants [
				index
			]
		)
		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if fighter.is_empty():
			continue

		if bool(
			fighter.get(
				"eliminated",
				false
			)
		):
			continue

		if bool(
			fighter.get(
				"respawn_pending",
				false
			)
		):
			if simulation_step < int(
				fighter.get(
					"respawn_at_step",
					simulation_step + 1
				)
			):
				continue

			var spawn: Dictionary = _spawn_contract_for_index(
				arena,
				index
			)
			var spawn_platform_id: String = str(
				spawn.get(
					"platform_id",
					"ground"
				)
			)
			var spawn_x: float = float(
				spawn.get(
					"x",
					50.0
				)
			)
			var spawn_target_y: float = _platform_y(
				arena,
				spawn_platform_id
			)

			fighter ["health"] = MAX_HEALTH
			fighter ["stamina"] = MAX_STAMINA
			fighter ["special_meter"] = 0
			fighter ["attack_cooldown_steps"] = 0
			fighter ["guarding"] = false
			fighter ["x"] = spawn_x
			fighter ["y"] = (
				-10.0
				- float(index) * 2.5
			)
			fighter ["spawn_platform_id"] = spawn_platform_id
			fighter ["spawn_target_y"] = spawn_target_y
			fighter ["platform_id"] = "spawn_air"
			fighter ["airborne"] = true
			fighter ["state"] = "respawn"
			fighter ["vertical_transition_active"] = true
			fighter ["vertical_transition_kind"] = "spawn_drop"
			fighter ["vertical_transition_elapsed"] = 0.0
			fighter ["vertical_transition_duration"] = 0.52
			fighter [
				"vertical_transition_from_y"
			] = fighter ["y"]
			fighter [
				"vertical_transition_to_y"
			] = spawn_target_y
			fighter [
				"vertical_transition_target_platform_id"
			] = spawn_platform_id
			fighter ["jump_horizontal_velocity"] = 0.0
			fighter ["jumps_remaining"] = MAX_JUMPS_PER_AIR_CYCLE
			fighter ["respawn_pending"] = false
			fighter ["respawn_at_step"] = -1
			fighter [
				"damage_protection_until_step"
			] = (
				simulation_step
				+ STOCK_RESPAWN_PROTECTION_STEPS
			)
			fighter ["equipped_weapon"] = {}

			fighters [
				identity_key
			] = fighter

			events.append({
				"event_type": "stick_fighter_stock_respawn",
				"simulation_step": simulation_step,
				"identity_key": identity_key,
				"stocks_remaining": int(
					fighter.get(
						"stock_lives_remaining",
						0
					)
				),
				"text": (
					"%s respawned with %d stock%s left."
					% [
						str(
							fighter.get(
								"display_name",
								"Fighter"
							)
						),
						int(
							fighter.get(
								"stock_lives_remaining",
								0
							)
						),
						(
							""
							if int(
								fighter.get(
									"stock_lives_remaining",
									0
								)
							) == 1
							else "s"
						)
					]
				)
			})

			continue

		if int(
			fighter.get(
				"health",
				0
			)
		) > 0:
			continue

		var remaining_stocks: int = maxi(
			0,
			int(
				fighter.get(
					"stock_lives_remaining",
					STOCK_LIVES_PER_ROUND
				)
			) - 1
		)

		fighter [
			"stock_lives_remaining"
		] = remaining_stocks

		if remaining_stocks > 0:
			fighter ["respawn_pending"] = true
			fighter ["respawn_at_step"] = (
				simulation_step
				+ STOCK_RESPAWN_DELAY_STEPS
			)
			fighter ["state"] = "knockout"
		else:
			fighter ["respawn_pending"] = false
			fighter ["respawn_at_step"] = -1
			fighter ["eliminated"] = true
			fighter ["eliminated_at_step"] = simulation_step
			fighter ["state"] = "knockout"

		fighters [
			identity_key
		] = fighter

		var stock_event_text: String = (
			"%s is OUT!"
			% str(
				fighter.get(
					"display_name",
					"Fighter"
				)
			)
			if remaining_stocks <= 0
			else (
				"%s lost a stock. %d remaining."
				% [
					str(
						fighter.get(
							"display_name",
							"Fighter"
						)
					),
					remaining_stocks
				]
			)
		)

		events.append({
			"event_type": "stick_fighter_stock_lost",
			"simulation_step": simulation_step,
			"identity_key": identity_key,
			"stocks_remaining": remaining_stocks,
			"eliminated": remaining_stocks <= 0,
			"text": stock_event_text
		})

	state ["fighters"] = fighters

	if _stock_contender_identity_keys(
		state
	).is_empty():
		_arm_stock_sudden_death(
			state,
			events
		)


func _resolve_stock_round_if_needed(
	state: Dictionary
) -> Dictionary:
	if bool(
		state.get(
			"round_resolution_deferred",
			false
		)
	):
		return {
			"round_resolved": false,
			"round_resolution_deferred": true
		}

	var contender_keys: Array = _stock_contender_identity_keys(
		state
	)

	if contender_keys.size() > 1:
		return {
			"round_resolved": false
		}

	if contender_keys.is_empty():
		return {
			"round_resolved": false
		}

	var round_winner_key: String = str(
		contender_keys [
			0
		]
	)
	var standing_contender: Dictionary = _fighter(
		state,
		round_winner_key
	)


	if (
		int(
			standing_contender.get(
				"health",
				0
			)
		) <= 0
		or bool(
			standing_contender.get(
				"respawn_pending",
				false
			)
		)
		or bool(
			standing_contender.get(
				"eliminated",
				false
			)
		)
	):
		return {
			"round_resolved": false
		}

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var round_winner: Dictionary = _dict(
		fighters.get(
			round_winner_key,
			{}
		)
	).duplicate(false)

	round_winner ["round_wins"] = int(
		round_winner.get(
			"round_wins",
			0
		)
	) + 1

	fighters [
		round_winner_key
	] = round_winner

	state ["fighters"] = fighters

	if int(
		round_winner.get(
			"round_wins",
			0
		)
	) >= WIN_ROUNDS:
		state ["complete"] = true
		state ["phase"] = "complete"
		state [
			"winner_identity_key"
		] = round_winner_key
		state ["last_event_text"] = (
			"%s won the match!"
			% str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			)
		)

		return {
			"round_resolved": true,
			"match_complete": true
		}

	state ["round"] = int(
		state.get(
			"round",
			1
		)
	) + 1

	_reset_round(
		state
	)

	_clear_continuous_round_transients(
		state
	)

	state ["last_event_text"] = (
		"%s won the round. ROUND %d!"
		% [
			str(
				round_winner.get(
					"display_name",
					"Fighter"
				)
			),
			int(
				state.get(
					"round",
					1
				)
			)
		]
	)

	return {
		"round_resolved": true,
		"match_complete": false
	}
func _result_text(state: Dictionary) -> String:
	if not bool(state.get("complete", false)):
		return "The Stick Fighter match is still in progress."
	var winner: Dictionary = _fighter(state, str(state.get("winner_identity_key", "")))
	return (
		"%s won Stick Fighter after %d rounds."
		% [str(winner.get("display_name", "A fighter")), int(state.get("round", 1))]
	)


func _roll(
	state: Dictionary,
	salt: String,
	minimum: int,
	maximum: int
) -> int:
	var span: int = maxi(
		1,
		maximum - minimum + 1
	)

	var authority_sequence: int = int(
		state.get(
			"simulation_step",
			state.get(
				"turn_sequence",
				0
			)
		)
	)

	var value: int = abs(
		int(
			hash(
				(
					"%s:%s:%d"
					% [
						str(
							state.get(
								"session_seed",
								0
							)
						),
						salt,
						authority_sequence
					]
				)
			)
		)
	)

	return minimum + value % span

func _action(action_id: String, label: String, enabled: bool, description: String) -> Dictionary:
	return {
		"action_id": action_id,
		"label": label,
		"enabled": enabled,
		"description": description,
		"ui_is_renderer_only": true
	}


func _fighter(state: Dictionary, identity_key: String) -> Dictionary:
	return _dict(_dict(state.get("fighters", {})).get(identity_key, {})).duplicate(true)


func _set_fighter(
	state: Dictionary,
	identity_key: String,
	fighter: Dictionary
) -> void:
	var committed_fighter: Dictionary = (
		fighter.duplicate(true)
	)

	var previous_fighter: Dictionary = _fighter(
		state,
		identity_key
	)

	var current_turn_identity_key: String = str(
		state.get(
			"current_turn_identity_key",
			""
		)
	)

	var fighter_state: String = _id(
		str(
			committed_fighter.get(
				"state",
				"idle"
			)
		)
	)

	var previous_damage_taken: int = int(
		previous_fighter.get(
			"damage_taken",
			0
		)
	)

	var current_damage_taken: int = int(
		committed_fighter.get(
			"damage_taken",
			0
		)
	)

	var damage_delta: int = maxi(
		0,
		current_damage_taken - previous_damage_taken
	)

	var source_action_id: String = ""

	if current_turn_identity_key != "":
		source_action_id = _id(
			str(
				_fighter(
					state,
					current_turn_identity_key
				).get(
					"state",
					""
				)
			)
		)

	if (
		identity_key != ""
		and identity_key != current_turn_identity_key
		and damage_delta > 0
		and fighter_state in [
			"hurt",
			"knockout"
		]
		and source_action_id in [
			"punch",
			"kick",
			"special"
		]
	):
		committed_fighter = (
			_apply_hit_spatial_reaction(
				state,
				current_turn_identity_key,
				source_action_id,
				damage_delta,
				committed_fighter
			)
		)

	var blast_source_identity_key: String = (
		current_turn_identity_key
		if identity_key != current_turn_identity_key
		else ""
	)

	var blast_action_id: String = (
		source_action_id
		if blast_source_identity_key != ""
		else fighter_state
	)

	var blast_damage: int = (
		damage_delta
		if blast_source_identity_key != ""
		else 0
	)

	committed_fighter = (
		_resolve_blast_zone_elimination(
			state,
			blast_source_identity_key,
			identity_key,
			blast_action_id,
			blast_damage,
			committed_fighter
		)
	)

	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)

	fighters [
		identity_key
	] = committed_fighter.duplicate(true)

	state [
		"fighters"
	] = fighters



func _participant(state: Dictionary, identity_key: String) -> Dictionary:
	for raw_participant in _array(state.get("participants", [])):
		var participant: Dictionary = _dict(raw_participant)
		if str(participant.get("identity_key", "")) == identity_key:
			return participant
	return {}


func _opponent_key(
	state: Dictionary,
	identity_key: String
) -> String:
	return _target_key_for_action(
		state,
		identity_key,
		{}
	)
func _living_identity_keys(
	state: Dictionary
) -> Array:
	var out: Array = []

	for raw_participant in _array(
		state.get(
			"participants",
			[]
		)
	):
		var participant: Dictionary = _dict(
			raw_participant
		)

		var identity_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var fighter: Dictionary = _fighter(
			state,
			identity_key
		)

		if int(
			fighter.get(
				"health",
				0
			)
		) > 0:
			out.append(
				identity_key
			)

	return out
func _target_key_for_action(
	state: Dictionary,
	identity_key: String,
	context: Dictionary
) -> String:
	var explicit_target: String = str(
		context.get(
			"target_identity_key",
			""
		)
	)

	if (
		explicit_target != ""
		and explicit_target != identity_key
		and int(
			_fighter(
				state,
				explicit_target
			).get(
				"health",
				0
			)
		) > 0
	):
		return explicit_target

	var participant: Dictionary = (
		_participant(
			state,
			identity_key
		)
	)

	var is_ai: bool = (
		bool(
			participant.get(
				"is_ai",
				false
			)
		)
		or str(
			participant.get(
				"controller",
				""
			)
		) == "npc_ai"
	)

	var local_player_key: String = str(
		state.get(
			"local_player_identity_key",
			""
		)
	)

	if (
		is_ai
		and str(
			state.get(
				"match_mode",
				""
			)
		) == "single_vs_ai"
		and local_player_key != ""
		and local_player_key != identity_key
		and int(
			_fighter(
				state,
				local_player_key
			).get(
				"health",
				0
			)
		) > 0
	):
		return local_player_key

	var fighter: Dictionary = _fighter(
		state,
		identity_key
	)

	var best_key: String = ""
	var best_distance: float = INF

	for raw_key in _living_identity_keys(
		state
	):
		var candidate_key: String = str(
			raw_key
		)

		if candidate_key == identity_key:
			continue

		var candidate: Dictionary = _fighter(
			state,
			candidate_key
		)

		var distance: float = (
			absf(
				float(
					fighter.get(
						"x",
						0.0
					)
				)
				- float(
					candidate.get(
						"x",
						0.0
					)
				)
			)
			+ absf(
				float(
					fighter.get(
						"y",
						50.0
					)
				)
				- float(
					candidate.get(
						"y",
						50.0
					)
				)
			) * 1.4
		)

		if distance < best_distance:
			best_distance = distance
			best_key = candidate_key

	return best_key
func _next_turn_identity_key(
	state: Dictionary,
	current_identity_key: String
) -> String:
	var participants: Array = _array(
		state.get(
			"participants",
			[]
		)
	)

	if participants.is_empty():
		return ""

	var current_index: int = -1

	for index in range(
		participants.size()
	):
		var participant: Dictionary = _dict(
			participants [
				index
			]
		)

		if str(
			participant.get(
				"identity_key",
				""
			)
		) == current_identity_key:
			current_index = index
			break

	for offset in range(
		1,
		participants.size() + 1
	):
		var index: int = (
			(current_index + offset)
			% participants.size()
		)

		var participant: Dictionary = _dict(
			participants [
				index
			]
		)

		var candidate_key: String = str(
			participant.get(
				"identity_key",
				""
			)
		)

		if (
			candidate_key != ""
			and int(
				_fighter(
					state,
					candidate_key
				).get(
					"health",
					0
				)
			) > 0
		):
			return candidate_key

	return ""
func _jump_destination_platform(
	arena: Dictionary,
	fighter: Dictionary
) -> Dictionary:
	var fighter_x: float = float(
		fighter.get(
			"x",
			50.0
		)
	)
	var fighter_y: float = float(
		fighter.get(
			"y",
			50.0
		)
	)
	var current_platform_id: String = str(
		fighter.get(
			"platform_id",
			""
		)
	)
	var facing: int = (
		-1
		if int(
			fighter.get(
				"facing",
				1
			)
		) < 0
		else 1
	)

	var best: Dictionary = {}
	var best_score: float = INF

	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		)
		var platform_id: String = str(
			platform.get(
				"platform_id",
				""
			)
		)

		if (
			platform_id == ""
			or platform_id == current_platform_id
			or not bool(
				platform.get(
					"solid",
					true
				)
			)
		):
			continue

		var platform_x: float = float(
			platform.get(
				"x",
				0.0
			)
		)
		var platform_width: float = float(
			platform.get(
				"width",
				0.0
			)
		)
		var platform_y: float = float(
			platform.get(
				"y",
				50.0
			)
		)

		var platform_left: float = platform_x
		var platform_right: float = (
			platform_x
			+ platform_width
		)
		var horizontal_gap: float = 0.0

		if fighter_x < platform_left:
			horizontal_gap = (
				platform_left
				- fighter_x
			)
		elif fighter_x > platform_right:
			horizontal_gap = (
				fighter_x
				- platform_right
			)

		var rise: float = maxf(
			0.0,
			fighter_y - platform_y
		)
		var drop: float = maxf(
			0.0,
			platform_y - fighter_y
		)



		if rise > 22.0:
			continue

		if drop > 8.0:
			continue

		if horizontal_gap > 24.0:
			continue

		var platform_center_x: float = (
			platform_left
			+ platform_right
		) * 0.5
		var direction: int = (
			-1
			if platform_center_x < fighter_x
			else 1
		)
		var facing_penalty: float = (
			6.0
			if direction != facing
			else 0.0
		)
		var score: float = (
			horizontal_gap * 1.35
			+ rise * 0.75
			+ drop * 0.5
			+ facing_penalty
		)

		if score >= best_score:
			continue

		best_score = score
		best = platform.duplicate(false)
		best ["jump_horizontal_gap"] = horizontal_gap
		best ["jump_direction"] = direction
		best ["jump_destination_score"] = score

	return best
func _apply_stick_fighter_double_jump_edges(
	state: Dictionary,
	input_snapshot: Dictionary
) -> Dictionary:
	var out: Dictionary = input_snapshot.duplicate(true)
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	for raw_identity_key in out.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var input_row: Dictionary = _dict(
			out.get(
				identity_key,
				{}
			)
		).duplicate(false)
		var edges: Array = _array(
			input_row.get(
				"edges",
				[]
			)
		).duplicate(true)
		var jump_edge_index: int = -1

		for edge_index in range(
			edges.size()
		):
			var edge: Dictionary = _dict(
				edges [
					edge_index
				]
			)

			if (
				_id(
					str(
						edge.get(
							"action_id",
							""
						)
					)
				) == "jump"
				and bool(
					edge.get(
						"pressed",
						true
					)
				)
			):
				jump_edge_index = edge_index
				break

		if jump_edge_index < 0:
			continue

		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)

		if fighter.is_empty():
			continue

		var already_airborne: bool = (
			bool(
				fighter.get(
					"airborne",
					false
				)
			)
			or bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
		)

		if not already_airborne:
			continue

		if (
			int(
				fighter.get(
					"jumps_remaining",
					0
				)
			) <= 0
			or int(
				fighter.get(
					"stamina",
					0
				)
			) < 8
		):
			continue

		fighter ["stamina"] = maxi(
			0,
			int(
				fighter.get(
					"stamina",
					0
				)
			) - 8
		)

		fighter = _begin_continuous_vertical_transition(
			arena,
			fighter,
			"jump"
		)

		fighters [
			identity_key
		] = fighter




		edges.remove_at(
			jump_edge_index
		)
		input_row ["edges"] = edges
		out [
			identity_key
		] = input_row

	state ["fighters"] = fighters

	return out
func _stick_fighter_combo_intents(
	_state: Dictionary,
	input_snapshot: Dictionary,
	pre_step_fighters: Dictionary
) -> Dictionary:
	var combos: Dictionary = {}

	for raw_identity_key in input_snapshot.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var input_row: Dictionary = _dict(
			input_snapshot.get(
				identity_key,
				{}
			)
		)
		var held: Dictionary = _dict(
			input_row.get(
				"held",
				{}
			)
		)
		var fighter: Dictionary = _dict(
			pre_step_fighters.get(
				identity_key,
				{}
			)
		)
		var punch_pressed: bool = false
		var kick_pressed: bool = false

		for raw_edge in _array(
			input_row.get(
				"edges",
				[]
			)
		):
			var edge: Dictionary = _dict(
				raw_edge
			)

			if not bool(
				edge.get(
					"pressed",
					true
				)
			):
				continue

			match _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			):
				"punch":
					punch_pressed = true

				"kick":
					kick_pressed = true

		var airborne: bool = (
			bool(
				fighter.get(
					"airborne",
					false
				)
			)
			or bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
		)

		if (
			kick_pressed
			and not airborne
			and bool(
				held.get(
					"drop_down",
					false
				)
			)
		):
			combos [
				identity_key
			] = "sweep"
		elif (
			punch_pressed
			and airborne
		):
			combos [
				identity_key
			] = "air_punch"

	return combos


func _strip_sweep_drop_edges(
	input_snapshot: Dictionary,
	combo_intents: Dictionary
) -> Dictionary:
	if combo_intents.is_empty():
		return input_snapshot

	var out: Dictionary = input_snapshot.duplicate(true)

	for raw_identity_key in combo_intents.keys():
		var identity_key: String = str(
			raw_identity_key
		)

		if str(
			combo_intents.get(
				identity_key,
				""
			)
		) != "sweep":
			continue

		var input_row: Dictionary = _dict(
			out.get(
				identity_key,
				{}
			)
		).duplicate(false)
		var retained_edges: Array = []

		for raw_edge in _array(
			input_row.get(
				"edges",
				[]
			)
		):
			var edge: Dictionary = _dict(
				raw_edge
			)

			if _id(
				str(
					edge.get(
						"action_id",
						""
					)
				)
			) == "drop_down":
				continue

			retained_edges.append(
				edge.duplicate(true)
			)

		input_row ["edges"] = retained_edges
		out [
			identity_key
		] = input_row

	return out


func _apply_advanced_bare_combat_labels(
	state: Dictionary,
	events: Array,
	combo_intents: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	for event_index in range(
		events.size()
	):
		var event: Dictionary = _dict(
			events [
				event_index
			]
		).duplicate(false)

		if str(
			event.get(
				"event_type",
				""
			)
		) != "stick_fighter_continuous_action":
			continue

		var source_key: String = str(
			event.get(
				"source_identity_key",
				""
			)
		)
		var action_id: String = _id(
			str(
				event.get(
					"action_id",
					""
				)
			)
		)
		var advanced_action_id: String = str(
			combo_intents.get(
				source_key,
				""
			)
		)

		if (
			advanced_action_id == "air_punch"
			and action_id != "punch"
		):
			continue

		if (
			advanced_action_id == "sweep"
			and action_id != "kick"
		):
			continue

		if advanced_action_id == "":
			continue

		var source: Dictionary = _dict(
			fighters.get(
				source_key,
				{}
			)
		).duplicate(false)

		if not source.is_empty():
			source ["state"] = advanced_action_id
			fighters [
				source_key
			] = source

		event ["action_id"] = advanced_action_id

		var advanced_text: String = str(
			event.get(
				"text",
				""
			)
		)

		if advanced_action_id == "air_punch":
			advanced_text = advanced_text.replace(
				"punch",
				"air punch"
			)
		elif advanced_action_id == "sweep":
			advanced_text = advanced_text.replace(
				"kicked",
				"swept"
			)
			advanced_text = advanced_text.replace(
				"kick",
				"sweep"
			)

		event ["text"] = advanced_text

		if advanced_text != "":
			state ["last_event_text"] = advanced_text

		if (
			advanced_action_id == "sweep"
			and bool(
				event.get(
					"hit",
					false
				)
			)
		):
			var target_key: String = str(
				event.get(
					"target_identity_key",
					""
				)
			)
			var target: Dictionary = _dict(
				fighters.get(
					target_key,
					{}
				)
			).duplicate(false)

			if (
				not target.is_empty()
				and int(
					target.get(
						"health",
						0
					)
				) > 0
			):
				target ["state"] = "swept_fall"
				target [
					"swept_fall_started_step"
				] = simulation_step
				target [
					"swept_fall_until_step"
				] = simulation_step + 18

				fighters [
					target_key
				] = target

		events [
			event_index
		] = event

	state ["fighters"] = fighters
func _normalize_stick_fighter_transient_states(
	state: Dictionary,
	pre_step_fighters: Dictionary
) -> void:
	var fighters: Dictionary = _dict(
		state.get(
			"fighters",
			{}
		)
	)
	var simulation_step: int = int(
		state.get(
			"simulation_step",
			0
		)
	)

	for raw_identity_key in fighters.keys():
		var identity_key: String = str(
			raw_identity_key
		)
		var fighter: Dictionary = _dict(
			fighters.get(
				identity_key,
				{}
			)
		).duplicate(false)
		var previous: Dictionary = _dict(
			pre_step_fighters.get(
				identity_key,
				{}
			)
		)
		var delta_x: float = (
			float(
				fighter.get(
					"x",
					50.0
				)
			)
			- float(
				previous.get(
					"x",
					fighter.get(
						"x",
						50.0
					)
				)
			)
		)
		var movement_axis: float = 0.0

		if absf(
			delta_x
		) > 0.001:
			movement_axis = (
				-1.0
				if delta_x < 0.0
				else 1.0
			)

		fighter ["movement_axis"] = movement_axis

		if (
			str(
				fighter.get(
					"state",
					"idle"
				)
			) == "walk"
			and movement_axis == 0.0
			and not bool(
				fighter.get(
					"airborne",
					false
				)
			)
			and not bool(
				fighter.get(
					"vertical_transition_active",
					false
				)
			)
		):
			fighter ["state"] = "idle"

		var swept_until_step: int = int(
			fighter.get(
				"swept_fall_until_step",
				-1
			)
		)

		if (
			swept_until_step >= simulation_step
			and swept_until_step >= 0
			and int(
				fighter.get(
					"health",
					0
				)
			) > 0
		):
			fighter ["state"] = "swept_fall"
		elif (
			str(
				fighter.get(
					"state",
					""
				)
			) == "swept_fall"
			and simulation_step > swept_until_step
		):
			fighter ["state"] = (
				"fall"
				if bool(
					fighter.get(
						"airborne",
						false
					)
				)
				else "idle"
			)

		fighters [
			identity_key
		] = fighter

	state ["fighters"] = fighters
func _ai_safe_horizontal_approach_action(
	arena: Dictionary,
	fighter: Dictionary,
	opponent: Dictionary
) -> String:
	if (
		fighter.is_empty()
		or opponent.is_empty()
	):
		return "block"

	var fighter_x: float = float(
		fighter.get(
			"x",
			50.0
		)
	)
	var opponent_x: float = float(
		opponent.get(
			"x",
			50.0
		)
	)
	var direction: float = (
		-1.0
		if opponent_x < fighter_x
		else 1.0
	)
	var move_action: String = (
		"move_left"
		if direction < 0.0
		else "move_right"
	)
	var airborne: bool = (
		bool(
			fighter.get(
				"airborne",
				false
			)
		)
		or bool(
			fighter.get(
				"vertical_transition_active",
				false
			)
		)
	)

	if airborne:


		return move_action

	var platform: Dictionary = _platform_contract(
		arena,
		str(
			fighter.get(
				"platform_id",
				""
			)
		)
	)

	if platform.is_empty():
		return "block"

	var lookahead_x: float = clampf(
		fighter_x
		+ direction * 4.5,
		4.0,
		96.0
	)
	var left: float = (
		float(
			platform.get(
				"x",
				0.0
			)
		)
		+ 1.5
	)
	var right: float = (
		float(
			platform.get(
				"x",
				0.0
			)
		)
		+ float(
			platform.get(
				"width",
				0.0
			)
		)
		- 1.5
	)

	if (
		lookahead_x >= left
		and lookahead_x <= right
	):
		return move_action

	var jump_probe: Dictionary = fighter.duplicate(false)
	jump_probe ["facing"] = (
		-1
		if direction < 0.0
		else 1
	)

	if (
		int(
			fighter.get(
				"jumps_remaining",
				0
			)
		) > 0
		and int(
			fighter.get(
				"stamina",
				0
			)
		) >= 8
		and not _jump_destination_platform(
			arena,
			jump_probe
		).is_empty()
	):
		return "jump"

	return "block"
func _normalize_fighter_platform_after_move(
	arena: Dictionary,
	fighter: Dictionary
) -> Dictionary:
	var out: Dictionary = fighter.duplicate(false)

	if bool(
		out.get(
			"vertical_transition_active",
			false
		)
	):
		return out

	var platform_id: String = str(
		out.get(
			"platform_id",
			""
		)
	)

	var platform: Dictionary = _platform_contract(
		arena,
		platform_id
	)

	if platform.is_empty():
		return out

	var fighter_x: float = float(
		out.get(
			"x",
			50.0
		)
	)
	var platform_x: float = float(
		platform.get(
			"x",
			0.0
		)
	)
	var platform_width: float = float(
		platform.get(
			"width",
			0.0
		)
	)

	if (
		fighter_x >= platform_x
		and fighter_x <= platform_x + platform_width
	):
		return out



	return _begin_continuous_vertical_transition(
		arena,
		out,
		"fall"
	)
func _landing_platform_below_x(
	arena: Dictionary,
	x: float,
	from_y: float,
	minimum_drop: float = 0.0
) -> Dictionary:
	var minimum_y: float = (
		from_y
		+ maxf(
			0.0,
			minimum_drop
		)
	)

	var best_platform: Dictionary = {}
	var best_y: float = 1000000.0

	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		)

		if not bool(
			platform.get(
				"solid",
				true
			)
		):
			continue

		var platform_width: float = maxf(
			0.0,
			float(
				platform.get(
					"width",
					0.0
				)
			)
		)

		if platform_width <= 0.0:
			continue

		var platform_x: float = float(
			platform.get(
				"x",
				0.0
			)
		)

		var platform_right: float = (
			platform_x
			+ platform_width
		)

		if (
			x < platform_x
			or x > platform_right
		):
			continue

		var platform_y: float = float(
			platform.get(
				"y",
				50.0
			)
		)

		if platform_y + 0.001 < minimum_y:
			continue

		if platform_y < best_y:
			best_y = platform_y
			best_platform = platform.duplicate(true)

	return best_platform


func _lowest_solid_platform_y(
	arena: Dictionary
) -> float:
	var found: bool = false
	var lowest_y: float = 0.0

	for raw_platform in _array(
		arena.get(
			"platforms",
			[]
		)
	):
		var platform: Dictionary = _dict(
			raw_platform
		)

		if not bool(
			platform.get(
				"solid",
				true
			)
		):
			continue

		var platform_y: float = float(
			platform.get(
				"y",
				0.0
			)
		)

		if (
			not found
			or platform_y > lowest_y
		):
			found = true
			lowest_y = platform_y

	if found:
		return lowest_y

	return maxf(
		0.0,
		float(
			arena.get(
				"height",
				56.0
			)
		) - 6.0
	)


func _fighter_into_abyss(
	arena: Dictionary,
	fighter: Dictionary
) -> Dictionary:
	var out: Dictionary = fighter.duplicate(false)

	var stage_height: float = maxf(
		1.0,
		float(
			arena.get(
				"height",
				56.0
			)
		)
	)

	var blast_margin_y: float = maxf(
		0.0,
		float(
			arena.get(
				"blast_zone_margin_y",
				10.0
			)
		)
	)

	out [
		"platform_id"
	] = "air"
	out [
		"airborne"
	] = true
	out [
		"y"
	] = (
		stage_height
		+ blast_margin_y
		+ 1.0
	)
	out [
		"state"
	] = "fall"

	return out

func _apply_hit_spatial_reaction(
	state: Dictionary,
	source_identity_key: String,
	action_id: String,
	damage: int,
	fighter: Dictionary
) -> Dictionary:
	var out: Dictionary = fighter.duplicate(false)
	var source: Dictionary = _fighter(
		state,
		source_identity_key
	)

	if source.is_empty():
		return out

	var direction: float = (
		1.0
		if float(
			out.get(
				"x",
				50.0
			)
		) >= float(
			source.get(
				"x",
				50.0
			)
		)
		else -1.0
	)

	var base_knockback: float = (
		0.75
		+ float(damage) * 0.1
	)

	match _id(
		action_id
	):
		"kick":
			base_knockback = (
				1.0
				+ float(damage) * 0.15
			)
		"special":
			base_knockback = (
				1.4
				+ float(damage) * 0.22
			)

	var pressure_multiplier: float = clampf(
		1.0
		+ float(
			source.get(
				"special_meter",
				0
			)
		) / 100.0 * 0.35,
		1.0,
		1.35
	)

	base_knockback *= pressure_multiplier

	out [
		"x"
	] = clampf(
		float(
			out.get(
				"x",
				50.0
			)
		) + direction * base_knockback,
		-20.0,
		120.0
	)

	if bool(
		out.get(
			"airborne",
			false
		)
	):
		var vertical_reaction: float = (
			0.35
			+ float(damage) * 0.035
		)

		match _id(
			action_id
		):
			"kick":
				vertical_reaction = (
					0.55
					+ float(damage) * 0.065
				)
			"special":
				vertical_reaction = (
					0.85
					+ float(damage) * 0.11
				)

		out [
			"y"
		] = float(
			out.get(
				"y",
				50.0
			)
		) - vertical_reaction

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	return _normalize_fighter_platform_after_move(
		arena,
		out
	)
func _blast_zone_exit_contract(
	arena: Dictionary,
	fighter: Dictionary
) -> Dictionary:
	var stage_width: float = maxf(
		1.0,
		float(
			arena.get(
				"width",
				100.0
			)
		)
	)

	var stage_height: float = maxf(
		1.0,
		float(
			arena.get(
				"height",
				56.0
			)
		)
	)

	var horizontal_margin: float = maxf(
		0.0,
		float(
			arena.get(
				"blast_zone_margin_x",
				12.0
			)
		)
	)

	var vertical_margin: float = maxf(
		0.0,
		float(
			arena.get(
				"blast_zone_margin_y",
				10.0
			)
		)
	)

	var fighter_x: float = float(
		fighter.get(
			"x",
			stage_width * 0.5
		)
	)

	var fighter_y: float = float(
		fighter.get(
			"y",
			stage_height * 0.5
		)
	)

	if fighter_x < - horizontal_margin:
		return {
			"edge": "left",
			"reason": "side_ring_out",
			"stage_x": 0.0,
			"stage_y": clampf(
				fighter_y,
				0.0,
				stage_height
			)
		}

	if fighter_x > stage_width + horizontal_margin:
		return {
			"edge": "right",
			"reason": "side_ring_out",
			"stage_x": stage_width,
			"stage_y": clampf(
				fighter_y,
				0.0,
				stage_height
			)
		}

	if fighter_y > stage_height + vertical_margin:
		return {
			"edge": "bottom",
			"reason": "abyss",
			"stage_x": clampf(
				fighter_x,
				0.0,
				stage_width
			),
			"stage_y": stage_height
		}

	if fighter_y < - vertical_margin:
		return {
			"edge": "top",
			"reason": "sky_ring_out",
			"stage_x": clampf(
				fighter_x,
				0.0,
				stage_width
			),
			"stage_y": 0.0
		}

	return {}
func _resolve_blast_zone_elimination(
	state: Dictionary,
	source_identity_key: String,
	target_identity_key: String,
	action_id: String,
	damage: int,
	fighter: Dictionary
) -> Dictionary:
	var out: Dictionary = fighter.duplicate(true)

	if target_identity_key == "":
		return out

	if _id(
		str(
			out.get(
				"platform_id",
				""
			)
		)
	) == "blast_zone":
		return out

	var arena: Dictionary = _dict(
		state.get(
			"arena_contract",
			{}
		)
	)

	if arena.is_empty():
		arena = _arena_contract(
			str(
				state.get(
					"arena_id",
					"neon_alley"
				)
			)
		)

	var exit_contract: Dictionary = (
		_blast_zone_exit_contract(
			arena,
			out
		)
	)

	if exit_contract.is_empty():
		return out

	out [
		"health"
	] = 0

	out [
		"guarding"
	] = false

	out [
		"airborne"
	] = false

	out [
		"platform_id"
	] = "blast_zone"

	out [
		"state"
	] = "knockout"

	_publish_stick_fighter_blast_feedback(
		state,
		source_identity_key,
		target_identity_key,
		action_id,
		damage,
		out,
		exit_contract
	)

	return out
func _publish_stick_fighter_blast_feedback(
	state: Dictionary,
	source_identity_key: String,
	target_identity_key: String,
	action_id: String,
	damage: int,
	fighter: Dictionary,
	exit_contract: Dictionary
) -> void:
	var revision: int = int(
		state.get(
			"blast_feedback_revision",
			0
		)
	) + 1

	var participant: Dictionary = _participant(
		state,
		target_identity_key
	)

	var display_name: String = str(
		fighter.get(
			"display_name",
			participant.get(
				"display_name",
				"Fighter"
			)
		)
	)

	var edge: String = _id(
		str(
			exit_contract.get(
				"edge",
				"right"
			)
		)
	)

	var reason: String = _id(
		str(
			exit_contract.get(
				"reason",
				"blast_zone"
			)
		)
	)

	var feedback_text: String = (
		"%s was blasted out of the arena!"
		% display_name
	)

	match reason:
		"abyss":
			feedback_text = (
				"%s fell into the abyss!"
				% display_name
			)

		"sky_ring_out":
			feedback_text = (
				"%s was launched through the top blast zone!"
				% display_name
			)

	var feedback: Dictionary = {
		"schema": "eralife.stick_fighter_blast_feedback",
		"version": 1,
		"revision": revision,
		"event_type": "stick_fighter_blast",
		"fighter_identity_key": target_identity_key,
		"source_identity_key": source_identity_key,
		"fighter_index": int(
			participant.get(
				"fighter_index",
				0
			)
		),
		"action_id": action_id,
		"damage": damage,
		"edge": edge,
		"reason": reason,
		"stage_x": float(
			exit_contract.get(
				"stage_x",
				50.0
			)
		),
		"stage_y": float(
			exit_contract.get(
				"stage_y",
				50.0
			)
		),
		"exit_x": float(
			fighter.get(
				"x",
				50.0
			)
		),
		"exit_y": float(
			fighter.get(
				"y",
				50.0
			)
		),
		"round": int(
			state.get(
				"round",
				1
			)
		),
		"turn_sequence": int(
			state.get(
				"turn_sequence",
				0
			)
		),
		"text": feedback_text,
		"physics_authority": PROVIDER_ID,
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}

	var feedback_events: Array = _array(
		state.get(
			"blast_feedback_events",
			[]
		)
	).duplicate(true)

	feedback_events.append(
		feedback.duplicate(true)
	)

	while feedback_events.size() > 8:
		feedback_events.pop_front()

	state [
		"blast_feedback_revision"
	] = revision

	state [
		"blast_feedback_events"
	] = feedback_events

func _failure(reason: String, text: String) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"text": text,
		"provider_id": PROVIDER_ID,
		"ui_is_renderer_only": true
	}
func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()

func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []