extends Resource
class_name BendingEngine

var gs
const CONTRACT_SCHEMA:= "eralife.bending_engine_contract"
const CONTRACT_VERSION:= 1
var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var bending_person_guard_stack: Dictionary = {}
func _init(_gs):
	gs = _gs

func set_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = contract.duplicate(true)
	else:
		active_contract = _build_default_bending_contract()
	last_contract_report = {
		"schema": "eralife.bending_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.bending_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"advanced_bending_abilities_seeded": advanced_bending_abilities_seeded,
		"last_contract_report": last_contract_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BendingEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = (contract_raw as Dictionary).duplicate(true)

	advanced_bending_abilities_seeded = bool(data.get("advanced_bending_abilities_seeded", advanced_bending_abilities_seeded))

	var report_raw: Variant = data.get("last_contract_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_contract_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var overlay_value: Variant = overlay [key]

		if typeof(overlay_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(_safe_dictionary(out.get(key, {})), _safe_dictionary(overlay_value))
		elif typeof(overlay_value) == TYPE_DICTIONARY:
			out [key] = _safe_dictionary(overlay_value)
		elif typeof(overlay_value) == TYPE_ARRAY:
			out [key] = _safe_array(overlay_value)
		else:
			out [key] = overlay_value

	return out


func _build_default_bending_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_bending_contract",
		"elements": ["air", "earth", "fire", "water"],
		"birth_policies": {
		},
		"progression_policy": {
			"schema": "eralife.bending_progression_policy",
			"version": 1,
			"xp_curve": {
				"base_required_xp": 34,
				"linear_level_cost": 13,
				"power_curve": 1.72,
				"power_curve_weight": 1.45,
				"elite_level_start": 80,
				"elite_quadratic_weight": 11,
				"master_level_start": 90,
				"master_quadratic_weight": 19
			},
			"xp_gain": {
				"base_xp_per_raw_progress": 24,
				"minimum_training_xp": 8,
				"minimum_duel_xp": 14,
				"tournament_multiplier": 1.55,
				"ko_multiplier": 1.18,
				"death_multiplier": 1.45,
				"upset_multiplier": 1.35,
				"scenario_engine_multiplier": 0.72
			},
			"skill_points": {
				"award_on_level_interval": 5,
				"award_on_master_interval": 2,
				"master_level_start": 80,
				"tournament_bonus": 1,
				"upset_bonus": 1,
				"ko_bonus": 1,
				"max_duel_award": 7
			}
		},
		"skill_cap_policy": {
			"schema": "eralife.bending_skill_cap_policy",
			"version": 1,
			"default_cap_floor": 68,
			"default_cap_ceiling": 100,
			"lineage_weight": 24,
			"potential_weight": 0.18,
			"level_weight": 0.08,
			"element_bias_weight": 0.55,
			"avatar_cap_bonus": 5,
			"royal_cap_bonus": 2,
			"special_event_extension_key": "skill_cap_extensions"
		},
		"ability_upgrade_policy": {
			"schema": "eralife.bending_ability_upgrade_policy",
			"version": 1,
			"max_upgrade_level": 5,
			"upgrade_level_step": 5,
			"base_upgrade_cost": 1,
			"cost_per_tier": 1,
			"cost_per_required_level_bucket": 1,
			"required_level_bucket_size": 30,
			"category_requirement_base": 52,
			"category_requirement_per_tier": 8,
			"category_requirement_level_weight": 0.12,
			"upgrade_effectiveness_per_tier": 0.08,
			"neutralize_per_tier": 5
		},
		"world_championship_policy": {
			"enabled": true,
			"schema": "eralife.bending_world_championship_contract",
			"version": 3,
			"duel_age_min": 10,
			"opening_history_years": 16,
			"min_child_benders": 24,
			"participant_cap": 12,
			"main_bracket_size": 8,
			"play_in_target_participant_count": 12,
			"participation_rate_by_division": {
				"youth": 58,
				"adult": 46,
				"elder_male": 34,
				"elder_female": 34,
				"masters": 100
			},
			"tournament_cycle": {
				"cycle_length": 5,
				"active_world_years": 4,
				"champions_year": 5,
				"world_tournament_division": "adult",
				"champions_division": "masters"
			},
			"history": {
				"visible_recent_tournament_count": 5,
				"recordboard_limit": 5,
				"minimum_adult_prior_duels": 6,
				"maximum_adult_prior_duels": 84,
				"minimum_champion_tournament_wins": 3,
				"championship_win_floor_per_title": 3,
				"championship_low_seed_win_floor_per_title": 4,
				"championship_existing_record_repair": true,
				"world_feed_backfill_enabled": true,
				"world_feed_backfill_year_count": 8,
				"world_feed_backfill_max_entries_per_year": 8
			},
			"previous_avatar_reputation_imprint": {
				"enabled": true,
				"store_on_avatar_identity_residue": true
			},
			"youth": {
				"min_age": 10,
				"max_age": 17,
				"skill_weight": 0.62,
				"upset_weight": 0.38,
				"label": "Youth Bending World Championship"
			},
			"adult": {
				"min_age": 18,
				"max_age": 50,
				"skill_weight": 0.88,
				"upset_weight": 0.12,
				"label": "Adult Bending World Championship"
			},
			"elder": {
				"min_age": 51,
				"skill_weight": 0.78,
				"upset_weight": 0.22,
				"label": "Elder Bending World Championship"
			},
			"masters": {
				"enabled": true,
				"every_years": 5,
				"source_division": "adult",
				"top_n": 5,
				"bid_source": "adult_world_champions",
				"unique_bid_window_years": 4,
				"label": "Tournament of Champions"
			},
			"records": {
				"track_kos": true,
			},
			"rankings": {
				"adult_top_n": 100,
				"youth_top_n": 100,
			}
		},
		"save_policy": {
			"unknown_fields": "preserve",
			"hydration_lane": "core"
		}
	}




var NATIONS = [
	"Air Nomads",
	"Earth Kingdom",
	"Fire Nation",
	"Water Tribe"
]

var avatar_cycle: Array = [
	"Air Nomads",
	"Water Tribe",
	"Earth Kingdom",
	"Fire Nation"
]

var last_avatar_nation: String = ""

const BENDING_LEVEL_MAX:= 100
const BENDING_MASTERY_THRESHOLD:= 85
const BENDING_BOOTSTRAP_SKILL_SOFT_CAP:= 79
const BENDING_ELDER_DECLINE_START_AGE:= 75
const BENDING_ELDER_DECLINE_HARD_AGE:= 90
const BENDING_ELDER_DECLINE_FLOOR:= 8
const BENDING_LATENT_POTENTIAL_MAX:= 100
var BASE_ELEMENTS:= ["air", "earth", "fire", "water"]
var advanced_bending_abilities_seeded: bool = false
var BENDING_ABILITIES:= {
	"air": [
		{
			"id": "air_scooter",
			"name": "Air Scooter",
			"level": 5,
			"type": "escape",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A quick mobility burst that helps you escape danger before it becomes a fight.",
			"result_text": "You used Air Scooter to slip out of danger."
		},
		{
			"id": "gust_push",
			"name": "Gust Push",
			"level": 12,
			"type": "attack",
			"cooldown_years": 1,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A focused blast of air that can shove an enemy back without needing lethal force.",
			"result_text": "You knocked %s back with a sharp gust of air."
		},
		{
			"id": "air_shield",
			"name": "Air Shield",
			"level": 24,
			"type": "defense",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A rotating defensive current that softens incoming attacks.",
			"result_text": "You raised an Air Shield around yourself."
		},
		{
			"id": "Vacuum Step",
			"name": "Vacuum Step",
			"level": 42,
			"type": "escape",
			"cooldown_years": 2,
			"target_scope": "self",
			"popup_action": false,
			"description": "A high-skill evasion movement that lets you vanish from a bad situation before it traps you.",
			"result_text": "You vanished from danger with Vacuum Step."
		},
		{
			"id": "cyclone_ring",
			"name": "Cyclone Ring",
			"level": 62,
			"type": "control",
			"cooldown_years": 2,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A circular wind prison that can restrain an enemy long enough for you to escape or strike.",
			"result_text": "You trapped %s inside a spinning ring of air."
		},
		{
			"id": "breathless_lock",
			"name": "Breathless Lock",
			"level": 88,
			"type": "attack",
			"cooldown_years": 4,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A forbidden-level air technique that can overwhelm an enemy by controlling the air around them.",
			"result_text": "You used Breathless Lock against %s. The room went terrifyingly still."
		}
	],
	"water": [
		{
			"id": "water_whip",
			"name": "Water Whip",
			"level": 5,
			"type": "attack",
			"cooldown_years": 1,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A quick flexible strike that punishes an enemy without requiring close contact.",
			"result_text": "You struck %s with a Water Whip."
		},
		{
			"id": "ice_step",
			"name": "Ice Step",
			"level": 14,
			"type": "escape",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A fast escape technique that creates frozen footing under pressure.",
			"result_text": "You escaped on a trail of ice."
		},
		{
			"id": "healing_water",
			"name": "Healing Water",
			"level": 28,
			"type": "heal",
			"cooldown_years": 1,
			"target_scope": "self_or_nation",
			"popup_action": true,
			"description": "A restorative water technique that can repair injuries and stabilize someone after danger.",
			"result_text": "You used Healing Water on %s."
		},
		{
			"id": "ice_prison",
			"name": "Ice Prison",
			"level": 45,
			"type": "control",
			"cooldown_years": 2,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A restraining technique that locks an enemy in ice long enough to escape or finish the fight.",
			"result_text": "You trapped %s in an Ice Prison."
		},
		{
			"id": "blood_flow_sense",
			"name": "Blood Flow Sense",
			"level": 66,
			"type": "defense",
			"cooldown_years": 2,
			"target_scope": "self",
			"popup_action": false,
			"description": "A rare defensive awareness technique that helps you predict danger through motion and pulse.",
			"result_text": "You centered yourself and sensed danger through the flow around you."
		},
		{
			"id": "bloodbending",
			"name": "Bloodbending",
			"level": 92,
			"type": "control",
			"cooldown_years": 5,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A terrifying master-level technique that can seize control of an enemy's movement.",
			"result_text": "You used Bloodbending against %s. Even the silence felt afraid."
		}
	],
	"earth": [
		{
			"id": "stone_guard",
			"name": "Stone Guard",
			"level": 5,
			"type": "defense",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A quick earth shell that helps absorb physical danger.",
			"result_text": "You pulled stone around yourself for protection."
		},
		{
			"id": "seismic_stance",
			"name": "Seismic Stance",
			"level": 16,
			"type": "defense",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A grounded stance that helps you sense movement before an enemy reaches you.",
			"result_text": "You settled into Seismic Stance and read the ground."
		},
		{
			"id": "earth_wall",
			"name": "Earth Wall",
			"level": 26,
			"type": "defense",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A defensive wall raised from the ground to block incoming attacks.",
			"result_text": "You raised an Earth Wall."
		},
		{
			"id": "tremor_trip",
			"name": "Tremor Trip",
			"level": 40,
			"type": "attack",
			"cooldown_years": 2,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A focused ground shock that throws an enemy off balance.",
			"result_text": "You sent a tremor under %s and knocked them off balance."
		},
		{
			"id": "metal_sense",
			"name": "Metal Sense",
			"level": 62,
			"type": "utility",
			"cooldown_years": 2,
			"target_scope": "self",
			"popup_action": false,
			"description": "A refined earthbending sense that detects metal, restraints, armor, and hidden tools.",
			"result_text": "You focused and felt metal hidden in the world around you."
		},
		{
			"id": "metalbending",
			"name": "Metalbending",
			"level": 82,
			"type": "attack",
			"cooldown_years": 3,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A master-level earth technique that lets you bend refined metal in combat and escape scenarios.",
			"result_text": "You twisted metal around %s with masterful control."
		}
	],
	"fire": [
		{
			"id": "flame_jab",
			"name": "Flame Jab",
			"level": 5,
			"type": "attack",
			"cooldown_years": 1,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A fast fire strike that can end a small confrontation quickly.",
			"result_text": "You hit %s with a sharp Flame Jab."
		},
		{
			"id": "heat_burst",
			"name": "Heat Burst",
			"level": 14,
			"type": "escape",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A burst of heat and motion that creates space when someone closes in.",
			"result_text": "You used Heat Burst to force space around you."
		},
		{
			"id": "fire_wall",
			"name": "Fire Wall",
			"level": 28,
			"type": "defense",
			"cooldown_years": 1,
			"target_scope": "self",
			"popup_action": false,
			"description": "A defensive sheet of flame that discourages enemies from pressing forward.",
			"result_text": "You raised a Fire Wall."
		},
		{
			"id": "jet_step",
			"name": "Jet Step",
			"level": 44,
			"type": "escape",
			"cooldown_years": 2,
			"target_scope": "self",
			"popup_action": false,
			"description": "A controlled burst of fire propulsion used to escape, reposition, or dodge.",
			"result_text": "You launched away with Jet Step."
		},
		{
			"id": "lightning_redirect",
			"name": "Lightning Redirect",
			"level": 66,
			"type": "defense",
			"cooldown_years": 2,
			"target_scope": "self",
			"popup_action": false,
			"description": "A dangerous defensive skill that can turn lightning away instead of absorbing it.",
			"result_text": "You redirected lightning through disciplined breath."
		},
		{
			"id": "lightning_generation",
			"name": "Lightning Generation",
			"level": 86,
			"type": "attack",
			"cooldown_years": 4,
			"target_scope": "nation",
			"popup_action": true,
			"description": "A master-level fire technique that channels focused lightning into a devastating attack.",
			"result_text": "You generated lightning and struck %s."
		}
	]
}
func _ensure_advanced_bending_abilities_injected() -> void:
	if advanced_bending_abilities_seeded:
		return

	advanced_bending_abilities_seeded = true

	var extra_abilities:= {
		"air": [
			{
				"id": "sonic_slice",
				"name": "Sonic Slice",
				"level": 34,
				"type": "attack",
				"impact": "heavy",
				"cooldown_years": 2,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A compressed blade of air released with enough precision to cut through a defense before the target hears it coming.",
				"usage_text": "Best used against fast or evasive opponents when you need a clean disabling strike.",
				"result_text": "You carved a screaming crescent of air toward %s with Sonic Slice."
			},
			{
				"id": "pressure_dome",
				"name": "Pressure Dome",
				"level": 72,
				"type": "control",
				"impact": "elite",
				"cooldown_years": 3,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A crushing air-pressure field that pins enemies inside a tightening invisible dome.",
				"usage_text": "Useful for stopping dangerous benders without needing a direct hit.",
				"result_text": "You sealed %s inside a brutal dome of pressure."
			},
			{
				"id": "sky_burial_vortex",
				"name": "Sky Burial Vortex",
				"level": 96,
				"type": "attack",
				"impact": "catastrophic",
				"cooldown_years": 5,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A mythic airbending assault that lifts the target into a violent spiral of cutting wind and collapsing pressure.",
				"usage_text": "A terrifying finisher-level technique. It should feel rare, dramatic, and dangerous.",
				"result_text": "You raised %s into a Sky Burial Vortex. The air itself became a weapon."
			}
		],
		"water": [
			{
				"id": "razor_tide",
				"name": "Razor Tide",
				"level": 32,
				"type": "attack",
				"impact": "heavy",
				"cooldown_years": 2,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A fast wave shaped into slicing edges, designed to punish enemies from multiple angles.",
				"usage_text": "Strong against grounded targets and anyone relying on distance.",
				"result_text": "You sent a Razor Tide crashing into %s from every angle."
			},
			{
				"id": "ice_coffin",
				"name": "Ice Coffin",
				"level": 64,
				"type": "control",
				"impact": "elite",
				"cooldown_years": 3,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A brutal freezing technique that traps the target in layered ice before they can react.",
				"usage_text": "Perfect when you want control, containment, and fear without relying on raw damage alone.",
				"result_text": "You locked %s inside an Ice Coffin."
			},
			{
				"id": "blood_moon_grip",
				"name": "Blood Moon Grip",
				"level": 94,
				"type": "control",
				"impact": "catastrophic",
				"cooldown_years": 6,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A forbidden bloodbending-adjacent technique that overwhelms the body through water control and terrifying precision.",
				"usage_text": "A rare, morally heavy control technique. Use it when the story should feel scary.",
				"result_text": "You caught %s in Blood Moon Grip. Their body stopped arguing with your will."
			}
		],
		"earth": [
			{
				"id": "stone_barrage",
				"name": "Stone Barrage",
				"level": 30,
				"type": "attack",
				"impact": "heavy",
				"cooldown_years": 2,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A rapid-fire storm of stone shards launched with relentless pressure.",
				"usage_text": "Good for overwhelming enemies who can dodge one big strike but not a whole storm.",
				"result_text": "You hammered %s with a Stone Barrage."
			},
			{
				"id": "seismic_rupture",
				"name": "Seismic Rupture",
				"level": 70,
				"type": "attack",
				"impact": "elite",
				"cooldown_years": 3,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A violent fault-line strike that tears the ground open beneath an enemy.",
				"usage_text": "Best against powerful grounded enemies, rulers, guards, and battlefield threats.",
				"result_text": "You split the earth beneath %s with Seismic Rupture."
			},
			{
				"id": "mountain_coffin",
				"name": "Mountain Coffin",
				"level": 96,
				"type": "control",
				"impact": "catastrophic",
				"cooldown_years": 5,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A mythic earthbending prison that folds stone inward like the mountain itself decided to bury the target alive.",
				"usage_text": "A legendary containment move. It should feel like the ground passed judgment.",
				"result_text": "You folded the ground around %s with Mountain Coffin."
			}
		],
		"fire": [
			{
				"id": "dragon_breath",
				"name": "Dragon Breath",
				"level": 36,
				"type": "attack",
				"impact": "heavy",
				"cooldown_years": 2,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A focused cone of disciplined flame released with breath control instead of rage.",
				"usage_text": "A strong mid-level offensive option for firebenders who are becoming dangerous but not reckless.",
				"result_text": "You unleashed Dragon Breath against %s."
			},
			{
				"id": "blue_flame_torrent",
				"name": "Blue Flame Torrent",
				"level": 74,
				"type": "attack",
				"impact": "elite",
				"cooldown_years": 3,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A hotter, cleaner torrent of blue fire that burns with terrifying control.",
				"usage_text": "Use when normal flame is not enough and the scene needs to feel high-level.",
				"result_text": "You washed %s in a Blue Flame Torrent."
			},
			{
				"id": "comet_lance",
				"name": "Comet Lance",
				"level": 96,
				"type": "attack",
				"impact": "catastrophic",
				"cooldown_years": 5,
				"target_scope": "nation",
				"popup_action": true,
				"description": "A concentrated spear of fire and lightning-like heat, launched like a falling star.",
				"usage_text": "A rare master attack. It should feel like the fight crossed into legend.",
				"result_text": "You hurled Comet Lance at %s. The strike looked like a star falling sideways."
			}
		]
	}

	for element in extra_abilities.keys():
		if not BENDING_ABILITIES.has(element):
			BENDING_ABILITIES [element] = []

		var existing_ids:= {}
		for raw_existing in BENDING_ABILITIES [element]:
			var existing_ability: Dictionary = raw_existing
			existing_ids [str(existing_ability.get("id", ""))] = true

		for raw_extra in extra_abilities [element]:
			var extra_ability: Dictionary = raw_extra
			var extra_id: String = str(extra_ability.get("id", ""))
			if extra_id == "" or existing_ids.has(extra_id):
				continue
			BENDING_ABILITIES [element].append(extra_ability)
			existing_ids [extra_id] = true
func _base_bending_elements() -> Array:
	return ["air", "earth", "fire", "water"]
func _bending_person_guard_key(npc: Person, guard_name: String) -> String:
	if npc == null:
		return ""

	var clean_guard: String = str(guard_name).strip_edges().to_lower()
	if clean_guard == "":
		return ""

	return "_eralife_%s_%d" % [
		clean_guard,
		int(npc.get_instance_id())
	]


func _bending_person_guard_active(npc: Person, guard_name: String) -> bool:
	if npc == null:
		return false

	var key: String = _bending_person_guard_key(npc, guard_name)
	if key == "":
		return false

	return int(bending_person_guard_stack.get(key, 0)) > 0


func _set_bending_person_guard(npc: Person, guard_name: String, active: bool) -> void:
	if npc == null:
		return

	var key: String = _bending_person_guard_key(npc, guard_name)
	if key == "":
		return

	var current_depth: int = int(bending_person_guard_stack.get(key, 0))

	if active:
		bending_person_guard_stack [key] = current_depth + 1
		return

	if current_depth <= 1:
		bending_person_guard_stack.erase(key)
	else:
		bending_person_guard_stack [key] = current_depth - 1


func _ensure_bending_level_storage_only(npc: Person) -> void:
	if npc == null:
		return

	if typeof(npc.bending_mastery) != TYPE_DICTIONARY:
		npc.bending_mastery = {}

	for element in _base_bending_elements():
		if not npc.bending_mastery.has(element):
			npc.bending_mastery [element] = 0
		npc.bending_mastery [element] = clamp(
			int(npc.bending_mastery.get(element, 0)),
			0,
			BENDING_LEVEL_MAX
		)


func _ensure_bending_potential_storage_only(npc: Person) -> void:
	if npc == null:
		return

	if typeof(npc.bending_latent_potential) != TYPE_DICTIONARY:
		npc.bending_latent_potential = {}

	for element in _base_bending_elements():
		if not npc.bending_latent_potential.has(element):
			npc.bending_latent_potential [element] = 0
		npc.bending_latent_potential [element] = clamp(
			int(npc.bending_latent_potential.get(element, 0)),
			0,
			BENDING_LATENT_POTENTIAL_MAX
		)


func _raw_bending_level(npc: Person, element: String) -> int:
	if npc == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	if typeof(npc.bending_mastery) != TYPE_DICTIONARY:
		return 0

	return clamp(
		int(npc.bending_mastery.get(clean_element, 0)),
		0,
		BENDING_LEVEL_MAX
	)


func _raw_bending_latent_potential(npc: Person, element: String) -> int:
	if npc == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	if typeof(npc.bending_latent_potential) != TYPE_DICTIONARY:
		return 0

	return clamp(
		int(npc.bending_latent_potential.get(clean_element, 0)),
		0,
		BENDING_LATENT_POTENTIAL_MAX
	)


func _safe_birth_latent_potential_floor(npc: Person, element: String, tier_hint:= 1) -> int:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	var floor_value: int = 42
	var ceiling_value: int = 78

	if int(tier_hint) <= 0:
		floor_value = 28
		ceiling_value = 68
	elif int(tier_hint) == 2:
		floor_value = 58
		ceiling_value = 90
	elif int(tier_hint) >= 3:
		floor_value = 72
		ceiling_value = 100

	if npc != null and str(npc.bending_type).strip_edges().to_lower() == "avatar":
		floor_value = max(floor_value, 64)
		ceiling_value = max(ceiling_value, 94)

	if npc != null and (bool(npc.is_royal) or bool(npc.is_ruler)):
		floor_value = min(100, floor_value + 4)
		ceiling_value = min(100, ceiling_value + 4)

	return clamp(
		randi_range(floor_value, ceiling_value),
		0,
		BENDING_LATENT_POTENTIAL_MAX
	)
func _bending_level_migration_map() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var migrated_raw: Variant = gs.scenario_state.get("bending_level_100_migrated_ids", {})
	var migrated: Dictionary = migrated_raw if typeof(migrated_raw) == TYPE_DICTIONARY else {}
	gs.scenario_state ["bending_level_100_migrated_ids"] = migrated
	return migrated

func _legacy_mastery_to_level(value: int) -> int:
	match int(value):
		0:
			return 0
		1:
			return 18
		2:
			return 46
		3:
			return 74
	return clamp(int(value), 0, BENDING_LEVEL_MAX)
func _mark_bending_level_migrated(npc: Person) -> void:
	if gs == null or npc == null:
		return
	var migrated:= _bending_level_migration_map()
	migrated [str(npc.id)] = true
	gs.scenario_state ["bending_level_100_migrated_ids"] = migrated
func _bending_lookup_person(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.has_method("get_or_reactivate_npc_by_id"):
		var reactivated: Person = gs.get_or_reactivate_npc_by_id(person_id)
		if reactivated != null:
			return reactivated

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null


func _bending_family_line_strength(npc: Person, element: String) -> float:
	if npc == null:
		return 0.0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0.0

	if _bending_person_guard_active(npc, "bending_family_line_strength_guard"):
		return 0.0

	_set_bending_person_guard(npc, "bending_family_line_strength_guard", true)

	var family_signals: Array = []
	for raw_parent_id in npc.parents:
		var parent: Person = _bending_lookup_person(int(raw_parent_id))
		if parent == null:
			continue
		if int(parent.id) == int(npc.id):
			continue

		_ensure_bending_level_storage_only(parent)
		_ensure_bending_potential_storage_only(parent)

		var parent_signal: int = max(
			_raw_bending_level(parent, clean_element),
			_raw_bending_latent_potential(parent, clean_element)
		)

		var parent_type: String = str(parent.bending_type).strip_edges().to_lower()
		if parent_type == "avatar":
			parent_signal = max(parent_signal, 78)
		elif parent_type == clean_element:
			parent_signal = max(parent_signal, 62)

		if parent_signal > 0:
			family_signals.append(parent_signal)

	_set_bending_person_guard(npc, "bending_family_line_strength_guard", false)

	if family_signals.is_empty():
		return 0.0

	var total: int = 0
	for raw_family_signal in family_signals:
		total += int(raw_family_signal)

	return clamp(float(total) / float(family_signals.size()) / 100.0, 0.0, 1.0)


func _bending_realm_match_keys_for_person(npc: Person, element: String) -> Array:
	var keys: Array = []
	if npc == null:
		return keys

	var candidate_values: Array = [
		npc.home_country,
		npc.birth_country,
		npc.bending_nation,
		_nation_for_element(element)
	]

	for raw_value in candidate_values:
		var clean_value: String = str(raw_value).strip_edges().to_lower()
		if clean_value != "" and clean_value not in keys:
			keys.append(clean_value)

	return keys


func _bending_realm_match_score(realm: Dictionary, keys: Array, element: String) -> int:
	if realm.is_empty():
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	var score: int = 0
	var realm_values: Array = [
		realm.get("id", ""),
		realm.get("name", ""),
		realm.get("capital", ""),
		realm.get("capital_city", ""),
		realm.get("bending_nation", ""),
		realm.get("native_nation", ""),
		realm.get("native_element", ""),
		realm.get("element", "")
	]

	var realm_texts: Array = []
	for raw_realm_value in realm_values:
		var realm_text: String = str(raw_realm_value).strip_edges().to_lower()
		if realm_text != "":
			realm_texts.append(realm_text)

	for raw_key in keys:
		var key_text: String = str(raw_key).strip_edges().to_lower()
		if key_text == "":
			continue
		for raw_realm_text in realm_texts:
			var realm_text_value: String = str(raw_realm_text)
			if realm_text_value == key_text:
				score += 8
			elif realm_text_value.find(key_text) != -1 or key_text.find(realm_text_value) != -1:
				score += 4

	var name_text: String = str(realm.get("name", "")).strip_edges().to_lower()
	if clean_element != "":
		if str(realm.get("native_element", "")).strip_edges().to_lower() == clean_element:
			score += 10
		elif str(realm.get("element", "")).strip_edges().to_lower() == clean_element:
			score += 10
		elif name_text.find(clean_element) != -1:
			score += 5

	return score


func _bending_find_realm_for_person(npc: Person, element: String) -> Dictionary:
	if gs == null or npc == null:
		return {}

	var keys: Array = _bending_realm_match_keys_for_person(npc, element)
	if keys.is_empty():
		return {}

	var best_realm: Dictionary = {}
	var best_score: int = 0

	if gs.realm_engine != null:
		var realm_engine_sources: Array = []
		for raw_property in gs.realm_engine.get_property_list():
			if typeof(raw_property) != TYPE_DICTIONARY:
				continue

			var property_name: String = str(raw_property.get("name", "")).strip_edges()
			if property_name != "realms":
				continue

			var realm_source_raw: Variant = gs.realm_engine.get(property_name)
			if typeof(realm_source_raw) == TYPE_DICTIONARY:
				realm_engine_sources.append(realm_source_raw)
			break

		for raw_realm_source in realm_engine_sources:
			if typeof(raw_realm_source) != TYPE_DICTIONARY:
				continue

			var realm_source: Dictionary = raw_realm_source
			for raw_realm in realm_source.values():
				if typeof(raw_realm) != TYPE_DICTIONARY:
					continue

				var realm: Dictionary = raw_realm
				var score: int = _bending_realm_match_score(realm, keys, element)
				if score > best_score:
					best_score = score
					best_realm = realm

	if not best_realm.is_empty():
		return best_realm

	if gs.many_realms_engine != null:
		var many_realm_property_names: Array = [
			"realms",
			"hidden_realms"
		]
		var many_realm_sources: Array = []

		for raw_many_property in gs.many_realms_engine.get_property_list():
			if typeof(raw_many_property) != TYPE_DICTIONARY:
				continue

			var many_property_name: String = str(raw_many_property.get("name", "")).strip_edges()
			if not many_realm_property_names.has(many_property_name):
				continue

			var many_realm_source_raw: Variant = gs.many_realms_engine.get(many_property_name)
			if typeof(many_realm_source_raw) == TYPE_DICTIONARY:
				many_realm_sources.append(many_realm_source_raw)

		for raw_many_realm_source in many_realm_sources:
			if typeof(raw_many_realm_source) != TYPE_DICTIONARY:
				continue

			var many_realm_source: Dictionary = raw_many_realm_source
			for raw_many_realm in many_realm_source.values():
				if typeof(raw_many_realm) != TYPE_DICTIONARY:
					continue

				var many_realm: Dictionary = raw_many_realm
				var many_score: int = _bending_realm_match_score(many_realm, keys, element)
				if many_score > best_score:
					best_score = many_score
					best_realm = many_realm

	return best_realm


func _bending_realm_environment_context(npc: Person, element: String) -> Dictionary:
	var context:= {
		"realm_found": false,
		"realm_name": "",
		"stability": 70,
		"war_pressure": 0,
		"rebel_pressure": 0,
		"environment_pressure": 0
	}

	var realm: Dictionary = _bending_find_realm_for_person(npc, element)
	if realm.is_empty():
		return context

	var raw_stability: int = int(realm.get("stability", realm.get("prosperity", realm.get("current", 70))))
	var raw_war_pressure: int = int(realm.get("war_pressure", realm.get("conflict_pressure", 0)))
	var raw_rebel_pressure: int = int(realm.get("rebel_pressure", realm.get("unrest", 0)))

	if bool(realm.get("at_war", false)) or bool(realm.get("is_at_war", false)) or bool(realm.get("war_active", false)):
		raw_war_pressure = max(raw_war_pressure, 72)

	var pressure: int = clamp(max(raw_war_pressure, raw_rebel_pressure), 0, 100)
	var adjusted_stability: int = clamp(raw_stability - int(round(float(raw_war_pressure + raw_rebel_pressure) * 0.08)), 0, 100)

	context ["realm_found"] = true
	context ["realm_name"] = str(realm.get("name", "Unknown Realm")).strip_edges()
	context ["stability"] = adjusted_stability
	context ["war_pressure"] = clamp(raw_war_pressure, 0, 100)
	context ["rebel_pressure"] = clamp(raw_rebel_pressure, 0, 100)
	context ["environment_pressure"] = pressure

	return context


func _bending_era_spiritual_activity_modifier() -> float:
	if gs == null:
		return 1.0

	var era_text: String = ""
	if typeof(gs.era) == TYPE_DICTIONARY:
		era_text = ("%s %s" % [
			str(gs.era.get("id", "")),
			str(gs.era.get("name", ""))
		]).strip_edges().to_lower()
	else:
		era_text = str(gs.era).strip_edges().to_lower()

	var modifier: float = 1.0

	if era_text.find("ancient") != -1:
		modifier += 0.08
	if era_text.find("myth") != -1 or era_text.find("spiritual") != -1 or era_text.find("legend") != -1:
		modifier += 0.12
	if era_text.find("medieval") != -1 or era_text.find("classical") != -1:
		modifier += 0.04
	if era_text.find("industrial") != -1:
		modifier -= 0.04
	if era_text.find("modern") != -1:
		modifier -= 0.02
	if era_text.find("cyber") != -1 or era_text.find("space") != -1 or era_text.find("future") != -1:
		modifier -= 0.06

	if gs.reality_mode == gs.REALITY_CHAOS:
		modifier += 0.05
	elif gs.reality_mode == gs.REALITY_ENHANCED:
		modifier += 0.03

	return clamp(modifier, 0.82, 1.22)


func _bending_potential_ceiling_profile(npc: Person, element: String) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var family_strength: float = _bending_family_line_strength(npc, clean_element)
	var environment: Dictionary = _bending_realm_environment_context(npc, clean_element)
	var era_modifier: float = _bending_era_spiritual_activity_modifier()

	var stability: int = int(environment.get("stability", 70))
	var war_pressure: int = int(environment.get("war_pressure", 0))
	var rebel_pressure: int = int(environment.get("rebel_pressure", 0))
	var environment_pressure: int = int(environment.get("environment_pressure", 0))

	var floor_bonus: int = int(round((family_strength - 0.35) * 18.0))
	var ceiling_bonus: int = int(round((family_strength - 0.45) * 24.0))
	var ceiling_cap: int = BENDING_LATENT_POTENTIAL_MAX

	if family_strength >= 0.9:
		floor_bonus += 8
		ceiling_bonus += 8
	elif family_strength >= 0.75:
		floor_bonus += 5
		ceiling_bonus += 5
	elif family_strength <= 0.25:
		floor_bonus -= 5
		ceiling_bonus -= 8

	if stability >= 85:
		floor_bonus += 3
		ceiling_bonus += 4
	elif stability >= 70:
		ceiling_bonus += 1
	elif stability < 45:
		floor_bonus -= 4
		ceiling_bonus -= 8
		ceiling_cap -= 8
	elif stability < 60:
		floor_bonus -= 2
		ceiling_bonus -= 4
		ceiling_cap -= 4

	if war_pressure >= 80:
		floor_bonus -= 6
		ceiling_bonus -= 12
		ceiling_cap -= 18
	elif war_pressure >= 55:
		floor_bonus -= 4
		ceiling_bonus -= 8
		ceiling_cap -= 12
	elif war_pressure >= 30:
		ceiling_bonus -= 4
		ceiling_cap -= 6

	if rebel_pressure >= 70:
		ceiling_cap -= 6
	elif rebel_pressure >= 40:
		ceiling_cap -= 3

	ceiling_cap = int(round(float(ceiling_cap) * era_modifier))
	ceiling_bonus += int(round((era_modifier - 1.0) * 18.0))

	if npc != null and str(npc.bending_type).strip_edges().to_lower() == "avatar":
		ceiling_cap = max(ceiling_cap, 88)
		floor_bonus += 4
		ceiling_bonus += 4

	if npc != null and (bool(npc.is_royal) or bool(npc.is_ruler)):
		floor_bonus += 2
		ceiling_bonus += 3

	ceiling_cap = clamp(ceiling_cap, 35, BENDING_LATENT_POTENTIAL_MAX)

	return {
		"element": clean_element,
		"family_strength": family_strength,
		"realm_environment": environment,
		"era_spiritual_modifier": era_modifier,
		"floor_bonus": floor_bonus,
		"ceiling_bonus": ceiling_bonus,
		"ceiling_cap": ceiling_cap,
		"environment_pressure": environment_pressure
	}


func _bending_environment_pressure_growth_modifier(npc: Person, element: String, reason:= "", current_level: int = 0) -> float:
	if npc == null:
		return 1.0

	var clean_element: String = str(element).strip_edges().to_lower()
	var context: Dictionary = _bending_realm_environment_context(npc, clean_element)
	var era_modifier: float = _bending_era_spiritual_activity_modifier()
	var stability: int = int(context.get("stability", 70))
	var war_pressure: int = int(context.get("war_pressure", 0))
	var environment_pressure: int = int(context.get("environment_pressure", 0))
	var reason_text: String = str(reason).strip_edges().to_lower()

	var modifier: float = 1.0

	if stability >= 85:
		modifier *= 1.07
	elif stability >= 70:
		modifier *= 1.03
	elif stability < 35:
		modifier *= 0.84
	elif stability < 50:
		modifier *= 0.91

	if war_pressure >= 70:
		modifier *= 0.88
	elif war_pressure >= 45:
		modifier *= 0.94

	if environment_pressure >= 60:
		match clean_element:
			"fire":
				if reason_text.find("combat") != -1 or reason_text.find("fight") != -1 or reason_text.find("pressure") != -1:
					modifier *= 1.08
			"earth":
				if current_level >= 45:
					modifier *= 1.04
			"water":
				modifier *= 0.96
			"air":
				modifier *= 0.98

	modifier *= lerpf(1.0, era_modifier, 0.55)
	return clamp(modifier, 0.55, 1.35)


func _bending_training_context_growth_modifier(npc: Person, element: String, reason:= "", current_level: int = 0) -> float:
	if npc == null:
		return 1.0

	var clean_element: String = str(element).strip_edges().to_lower()
	var reason_text: String = str(reason).strip_edges().to_lower()
	var modifier: float = 1.0

	if reason_text.find("guided") != -1 or reason_text.find("teacher") != -1 or reason_text.find("master") != -1:
		modifier *= 1.12
		if current_level >= 70:
			modifier *= 1.04
	elif reason_text.find("solo") != -1:
		modifier *= 0.98
		if clean_element == "earth":
			modifier *= 1.06
		elif clean_element == "air" and int(npc.smarts) >= 70:
			modifier *= 1.05

	if reason_text.find("combat") != -1 or reason_text.find("fight") != -1:
		if clean_element == "fire":
			modifier *= 1.1
		elif clean_element == "water":
			modifier *= 0.97
		else:
			modifier *= 1.03

	if reason_text.find("precision") != -1 or reason_text.find("technical") != -1:
		if clean_element == "air":
			modifier *= 1.12
		else:
			modifier *= 1.02

	return clamp(modifier, 0.72, 1.35)
func ensure_bending_potential_state(npc: Person) -> void:
	if npc == null:
		return

	if _bending_person_guard_active(npc, "bending_potential_state_guard"):
		_ensure_bending_potential_storage_only(npc)
		return

	_set_bending_person_guard(npc, "bending_potential_state_guard", true)
	_ensure_bending_potential_storage_only(npc)
	_set_bending_person_guard(npc, "bending_potential_state_guard", false)

func _roll_birth_latent_potential(npc: Person, element: String, tier_hint:= 1) -> int:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	var floor_value: int = 42
	var ceiling_value: int = 78

	if int(tier_hint) <= 0:
		floor_value = 28
		ceiling_value = 68
	elif int(tier_hint) == 2:
		floor_value = 58
		ceiling_value = 90
	elif int(tier_hint) >= 3:
		floor_value = 72
		ceiling_value = 100

	if npc != null and str(npc.bending_type).strip_edges().to_lower() == "avatar":
		floor_value = max(floor_value, 64)
		ceiling_value = max(ceiling_value, 94)

	if npc != null and (bool(npc.is_royal) or bool(npc.is_ruler)):
		floor_value = min(100, floor_value + 4)
		ceiling_value = min(100, ceiling_value + 4)

	var ceiling_profile: Dictionary = _bending_potential_ceiling_profile(npc, clean_element)
	var ceiling_cap: int = int(ceiling_profile.get("ceiling_cap", BENDING_LATENT_POTENTIAL_MAX))

	floor_value += int(ceiling_profile.get("floor_bonus", 0))
	ceiling_value += int(ceiling_profile.get("ceiling_bonus", 0))
	ceiling_value = min(ceiling_value, ceiling_cap)

	if ceiling_value < floor_value:
		floor_value = max(0, ceiling_value - 8)

	floor_value = clamp(floor_value, 0, BENDING_LATENT_POTENTIAL_MAX)
	ceiling_value = clamp(ceiling_value, floor_value, BENDING_LATENT_POTENTIAL_MAX)

	return clamp(randi_range(floor_value, ceiling_value), 0, BENDING_LATENT_POTENTIAL_MAX)


func set_bending_latent_potential(npc: Person, element: String, value: int) -> void:
	if npc == null:
		return

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return

	ensure_bending_potential_state(npc)
	npc.bending_latent_potential [clean_element] = clamp(int(value), 0, BENDING_LATENT_POTENTIAL_MAX)


func seed_birth_bending_potential(npc: Person, element: String, tier_hint:= 1) -> int:
	if npc == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	var rolled_potential: int = _roll_birth_latent_potential(npc, clean_element, tier_hint)
	set_bending_latent_potential(npc, clean_element, rolled_potential)
	return rolled_potential


func get_bending_latent_potential(npc: Person, element: String) -> int:
	if npc == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	if _bending_person_guard_active(npc, "bending_potential_state_guard") or _bending_person_guard_active(npc, "bending_level_state_guard"):
		_ensure_bending_potential_storage_only(npc)
		return _raw_bending_latent_potential(npc, clean_element)

	ensure_bending_potential_state(npc)
	return _raw_bending_latent_potential(npc, clean_element)


func get_primary_bending_potential(npc: Person) -> int:
	if npc == null:
		return 0

	ensure_bending_potential_state(npc)

	var bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	if bending_type in _base_bending_elements():
		return get_bending_latent_potential(npc, bending_type)

	var best_potential: int = 0
	for element in _base_bending_elements():
		best_potential = max(best_potential, get_bending_latent_potential(npc, element))

	return best_potential


func _latent_potential_band(value: int) -> String:
	var safe_value: int = clamp(int(value), 0, 100)

	if safe_value >= 95:
		return "Mythic"
	if safe_value >= 85:
		return "Prodigy"
	if safe_value >= 70:
		return "Gifted"
	if safe_value >= 55:
		return "Promising"
	if safe_value >= 35:
		return "Faint"
	if safe_value > 0:
		return "Dormant"

	return "None"


func get_bending_potential_summary(npc: Person) -> Dictionary:
	var out:= {
		"text": "Latent Potential: None",
		"best_element": "",
		"best_potential": 0,
		"average_potential": 0,
		"band": "None"
	}

	if npc == null:
		return out

	ensure_bending_potential_state(npc)

	var active_elements: Array = []
	if str(npc.bending_type).strip_edges().to_lower() == "avatar":
		active_elements = _base_bending_elements()
	elif str(npc.bending_type).strip_edges().to_lower() in _base_bending_elements():
		active_elements = [str(npc.bending_type).strip_edges().to_lower()]
	else:
		for element in _base_bending_elements():
			if get_bending_latent_potential(npc, element) > 0:
				active_elements.append(element)

	if active_elements.is_empty():
		return out

	var best_element: String = ""
	var best_potential: int = -1
	var total_potential: int = 0

	for element in active_elements:
		var potential_value: int = get_bending_latent_potential(npc, str(element))
		total_potential += potential_value

		if potential_value > best_potential:
			best_potential = potential_value
			best_element = str(element)

	var average_potential: int = int(round(float(total_potential) / float(max(1, active_elements.size()))))
	var band: String = _latent_potential_band(best_potential)

	var text: String = "Latent Potential: %s" % band
	if str(npc.bending_type).strip_edges().to_lower() == "avatar":
		text = "Latent Potential: %s Avatar • Best: %s %d • Avg: %d" % [
			band,
			best_element.capitalize(),
			best_potential,
			average_potential
		]
	else:
		text = "Latent Potential: %s • %s %d" % [
			band,
			best_element.capitalize(),
			best_potential
		]

	out ["text"] = text
	out ["best_element"] = best_element
	out ["best_potential"] = best_potential
	out ["average_potential"] = average_potential
	out ["band"] = band
	return out

func _roll_spawn_bending_level(npc: Person, element: String, tier_hint:= 0) -> int:
	var age: int = int(npc.age) if npc != null else 18
	var clean_element: String = str(element).strip_edges().to_lower()

	if clean_element not in _base_bending_elements():
		return 0

	if age < 3:
		return 0
	if age < 8:
		return randi_range(0, 6)
	if age < 13:
		return randi_range(1, 14)
	if age < 16:
		return randi_range(3, 26)

	var roll: int = randi() % 100

	if int(tier_hint) >= 3:
		roll = max(roll, 78)
	elif int(tier_hint) == 2:
		roll = max(roll, 55)
	elif int(tier_hint) == 1:
		roll = min(roll, 74)

	if roll < 18:
		return randi_range(1, 9)
	if roll < 40:
		return randi_range(10, 24)
	if roll < 62:
		return randi_range(25, 44)
	if roll < 84:
		return randi_range(45, 63)
	return randi_range(64, BENDING_BOOTSTRAP_SKILL_SOFT_CAP)


func _resolve_forced_bending_level(npc: Person, element: String, mastery) -> int:
	var raw_mastery: int = int(mastery)
	if raw_mastery <= 0:
		return _roll_spawn_bending_level(npc, element, 0)
	if raw_mastery <= 3:
		return _roll_spawn_bending_level(npc, element, raw_mastery)
	return clamp(raw_mastery, 0, BENDING_LEVEL_MAX)


func _native_element_for_person(npc: Person) -> String:
	if npc == null:
		return "none"

	var direct_nation: String = str(npc.bending_nation).strip_edges()
	var direct_element: String = _element_from_nation(direct_nation)
	if direct_element != "none":
		return direct_element

	var realm_name: String = str(npc.home_country).strip_edges()
	if realm_name == "":
		realm_name = str(npc.birth_country).strip_edges()

	if realm_name != "" and gs != null and gs.realm_engine != null and gs.realm_engine.has_method("_realm_element_for_name"):
		var realm_element: String = str(gs.realm_engine._realm_element_for_name(realm_name)).strip_edges().to_lower()
		if realm_element in _base_bending_elements():
			return realm_element

	return "none"
func ensure_bending_level_state(npc: Person) -> void:
	if npc == null:
		return

	_ensure_bending_level_storage_only(npc)
	_ensure_bending_potential_storage_only(npc)

	if _bending_person_guard_active(npc, "bending_level_state_guard"):
		return

	_set_bending_person_guard(npc, "bending_level_state_guard", true)

	var migrated:= _bending_level_migration_map()
	var pid_key: String = str(npc.id)
	var bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	var is_newborn: bool = int(npc.age) < 3

	if not bool(migrated.get(pid_key, false)):
		for element in _base_bending_elements():
			var old_value: int = int(npc.bending_mastery.get(element, 0))
			var active_legacy_slot: bool = bending_type == element or bending_type == "avatar"

			if is_newborn and active_legacy_slot:
				if old_value > 0:
					var carried_potential: int = max(
						int(npc.bending_latent_potential.get(element, 0)),
						clamp(old_value + randi_range(28, 48), 45, 100)
					)
					npc.bending_latent_potential [element] = carried_potential
				npc.bending_mastery [element] = 0
			elif old_value > 0 and old_value <= 3 and active_legacy_slot:
				npc.bending_mastery [element] = _roll_spawn_bending_level(npc, element, old_value)
				if int(npc.bending_latent_potential.get(element, 0)) <= 0:
					npc.bending_latent_potential [element] = _safe_birth_latent_potential_floor(npc, element, old_value)
			else:
				npc.bending_mastery [element] = _legacy_mastery_to_level(old_value)
				if old_value > 0 and active_legacy_slot and int(npc.bending_latent_potential.get(element, 0)) <= 0:
					npc.bending_latent_potential [element] = clamp(
						int(npc.bending_mastery [element]) + randi_range(10, 26),
						35,
						100
					)

		migrated [pid_key] = true
		if gs != null:
			if typeof(gs.scenario_state) != TYPE_DICTIONARY:
				gs.scenario_state = {}
			gs.scenario_state ["bending_level_100_migrated_ids"] = migrated

	for element in _base_bending_elements():
		npc.bending_mastery [element] = clamp(
			int(npc.bending_mastery.get(element, 0)),
			0,
			BENDING_LEVEL_MAX
		)
		npc.bending_latent_potential [element] = clamp(
			int(npc.bending_latent_potential.get(element, 0)),
			0,
			BENDING_LATENT_POTENTIAL_MAX
		)

	_set_bending_person_guard(npc, "bending_level_state_guard", false)

func get_bending_level(npc: Person, element: String) -> int:
	if npc == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	if _bending_person_guard_active(npc, "bending_level_state_guard"):
		_ensure_bending_level_storage_only(npc)
		return _raw_bending_level(npc, clean_element)

	ensure_bending_level_state(npc)
	return _raw_bending_level(npc, clean_element)
func _avatar_has_mastered_all_base_elements(actor: Person) -> bool:
	if actor == null:
		return false
	if str(actor.bending_type).strip_edges().to_lower() != "avatar" and not bool(actor.avatar_state_unlocked):
		return false

	ensure_bending_level_state(actor)
	for raw_element in BASE_ELEMENTS:
		var element: String = str(raw_element)
		if int(get_bending_level(actor, element)) < BENDING_MASTERY_THRESHOLD:
			return false

	return true


func get_bending_training_elements(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	ensure_bending_level_state(actor)
	var actor_type: String = str(actor.bending_type).strip_edges().to_lower()
	var is_avatar: bool = actor_type == "avatar" or bool(actor.avatar_state_unlocked)

	for raw_element in BASE_ELEMENTS:
		var element: String = str(raw_element)
		var level: int = int(get_bending_level(actor, element))
		if level > 0 and element not in out:
			out.append(element)

	if actor_type in BASE_ELEMENTS and actor_type not in out:
		out.append(actor_type)

	if is_avatar and _avatar_has_mastered_all_base_elements(actor):
		if "avatar" not in out:
			out.append("avatar")

	return out


func get_bending_awakening_options(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	ensure_bending_level_state(actor)
	ensure_bending_potential_state(actor)

	var training_elements: Array = get_bending_training_elements(actor)
	for raw_element in _base_bending_elements():
		var element: String = str(raw_element)
		if element in training_elements:
			continue
		if int(get_bending_level(actor, element)) > 0:
			continue
		if not _can_attempt_bending_awakening(actor, element):
			continue
		out.append(element)

	return out


func can_train_bending_element(actor: Person, element: String) -> bool:
	if actor == null:
		return false

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return false

	var actor_type: String = str(actor.bending_type).strip_edges().to_lower()
	var is_avatar: bool = actor_type == "avatar" or bool(actor.avatar_state_unlocked)

	if clean_element == "avatar":
		return is_avatar and _avatar_has_mastered_all_base_elements(actor)

	return clean_element in get_bending_training_elements(actor)
func get_primary_bending_level(npc: Person) -> int:
	if npc == null:
		return 0
	ensure_bending_level_state(npc)
	var bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	if bending_type == "avatar":
		var best_level: int = 0
		for element in _base_bending_elements():
			best_level = max(best_level, get_bending_level(npc, element))
		return best_level
	if bending_type in _base_bending_elements():
		return get_bending_level(npc, bending_type)
	var fallback_best: int = 0
	for fallback_element in _base_bending_elements():
		fallback_best = max(fallback_best, get_bending_level(npc, fallback_element))
	return fallback_best
func bootstrap_spawn_bending_population(source_npcs: Array = []) -> void:
	if gs == null or not gs.is_feature_enabled("bending"):
		return

	var population: Array = source_npcs if not source_npcs.is_empty() else gs.npcs

	for raw_npc in population:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue

		var bending_type: String = str(npc.bending_type).strip_edges().to_lower()

		if bending_type == "avatar":
			ensure_bending_level_state(npc)
			for element in _base_bending_elements():
				if get_bending_level(npc, element) <= 3:
					npc.bending_mastery [element] = _roll_spawn_bending_level(npc, element, 1)
			_mark_bending_level_migrated(npc)
			_seed_lineage_bending_combat_profile(npc, {
				"force": false,
				"source": "bootstrap_avatar_population"
			})
			if gs.capability_graph_engine != null:
				gs.capability_graph_engine.refresh_bending_capabilities(npc)
			continue

		if bending_type in _base_bending_elements():
			ensure_bending_level_state(npc)
			if get_bending_level(npc, bending_type) <= 3:
				npc.bending_mastery [bending_type] = _roll_spawn_bending_level(npc, bending_type, 1)
				_mark_bending_level_migrated(npc)
			_seed_lineage_bending_combat_profile(npc, {
				"force": false,
				"source": "bootstrap_existing_bender"
			})
			if gs.capability_graph_engine != null:
				gs.capability_graph_engine.refresh_bending_capabilities(npc)
			continue

		var native_element: String = _native_element_for_person(npc)
		var ambient_chance: int = 12

		if int(npc.age) < 18:
			ambient_chance = 22
		if native_element in _base_bending_elements():
			ambient_chance = 48 if int(npc.age) < 18 else 38
		elif int(npc.age) >= 16:
			ambient_chance = 18

		if randi() % 100 >= ambient_chance:
			continue

		var chosen_element: String = native_element
		if chosen_element not in _base_bending_elements():
			chosen_element = str(BASE_ELEMENTS.pick_random())
		elif randi() % 100 >= 90:
			chosen_element = str(BASE_ELEMENTS.pick_random())

		force_bending_type(npc, chosen_element, _roll_spawn_bending_level(npc, chosen_element, 0))
		_seed_lineage_bending_combat_profile(npc, {
			"force": false,
			"source": "bootstrap_spawned_bender"
		})

	_bootstrap_bending_child_population_floor(population)
	_ensure_bending_world_bootstrap({
		"source": "bootstrap_spawn_bending_population"
	})
func _bending_world_policy() -> Dictionary:
	var defaults: Dictionary = {
		"enabled": true,
		"duel_age_min": 10,
		"opening_history_years": 16,
		"min_child_benders": 24,
		"participant_cap": 16,
		"participation_rate_by_division": {
			"youth": 58,
			"adult": 46,
			"elder_male": 34,
			"elder_female": 34,
			"masters": 100
		},
		"tournament_cycle": {
			"cycle_length": 5,
			"active_world_years": 4,
			"champions_year": 5,
			"world_tournament_division": "adult",
			"champions_division": "masters"
		},
		"history": {
			"visible_recent_tournament_count": 5,
			"recordboard_limit": 5,
			"minimum_adult_prior_duels": 6,
			"maximum_adult_prior_duels": 84,
			"minimum_champion_tournament_wins": 4,
			"championship_win_floor_per_title": 4,
			"world_feed_backfill_enabled": true,
			"world_feed_backfill_year_count": 8,
			"world_feed_backfill_max_entries_per_year": 8
		},
		"previous_avatar_reputation_imprint": {
			"enabled": true,
			"store_on_avatar_identity_residue": true
		},
		"media_eras": ["modern", "future", "digital", "cyber", "space"],
		"avatar_history_visible_count": 4,
		"rival_bloodline_heat_threshold": 3
	}

	var raw_policy: Variant = active_contract.get("world_championship_policy", {})
	var policy: Dictionary = raw_policy if typeof(raw_policy) == TYPE_DICTIONARY else {}

	if policy.is_empty():
		policy = defaults.duplicate(true)
	else:
		policy = _merge_dict(defaults, policy)

	return policy


func _register_bending_world_spawn(npc: Person) -> void:
	if gs == null or npc == null:
		return

	if gs.has_method("register_npc"):
		gs.register_npc(npc)
	else:
		if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY and npc not in gs.npcs:
			gs.npcs.append(npc)

	if gs.world_space_engine != null and gs.world_space_engine.has_method("place_npc"):
		gs.world_space_engine.place_npc(npc)
	if gs.chunk_simulation_engine != null and gs.chunk_simulation_engine.has_method("assign_npc"):
		gs.chunk_simulation_engine.assign_npc(npc)


func _bootstrap_bending_child_population_floor(source_population: Array = []) -> void:
	if gs == null or gs.npc_factory == null:
		return

	var policy: Dictionary = _bending_world_policy()
	var target_child_benders: int = max(0, int(policy.get("min_child_benders", 24)))
	if target_child_benders <= 0:
		return

	var current_child_benders: int = 0
	var scan_population: Array = source_population if not source_population.is_empty() else gs.npcs

	for raw_npc in scan_population:
		if raw_npc == null:
			continue

		var npc: Person = raw_npc
		if not bool(npc.alive):
			continue
		if int(npc.age) > 17:
			continue
		if str(npc.bending_type).strip_edges().to_lower() == "none":
			continue

		current_child_benders += 1

	var needed: int = max(0, target_child_benders - current_child_benders)
	if needed <= 0:
		return

	for i in range(needed):
		var child: Person = gs.npc_factory.create_random_npc()
		if child == null:
			continue

		child.age = randi_range(10, 17)
		child.alive = true

		var element: String = str(BASE_ELEMENTS.pick_random())
		force_bending_type(child, element, randi_range(8, 42))
		child.bending_nation = _nation_from_element(element)
		child.fame = max(int(child.fame), randi_range(0, 8))

		_seed_lineage_bending_combat_profile(child, {
			"force": true,
			"source": "bootstrap_child_bender_floor"
		})

		_register_bending_world_spawn(child)


func _nation_from_element(element: String) -> String:
	match str(element).strip_edges().to_lower():
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"
	return str(NATIONS.pick_random())


func _ensure_bending_world_bootstrap(options: Dictionary = {}) -> void:
	if gs == null:
		return

	var state: Dictionary = _bending_world_state()
	if bool(state.get("bootstrap_seeded", false)):
		var existing_history: Array = state.get("tournament_history", []) if typeof(state.get("tournament_history", [])) == TYPE_ARRAY else []
		var existing_archive: Array = state.get("match_archive", []) if typeof(state.get("match_archive", [])) == TYPE_ARRAY else []

		if existing_history.is_empty() or existing_archive.is_empty():
			_bootstrap_bending_child_population_floor()
			_seed_established_bending_records_for_population({
				"source": "repair_missing_bending_tournament_history",
				"bootstrap": true
			})
			_seed_lightweight_opening_bending_history({
				"source": "repair_missing_bending_tournament_history",
				"bootstrap": true,
				"historical_backfill": true
			})
			state = _bending_world_state()
			state ["history_repaired_at_year"] = int(gs.year)
			state ["history_repair_source"] = str(options.get("source", "bending_engine"))
			gs.scenario_state ["bending_world_championship"] = state

		_refresh_bending_tournament_recordboards([])
		_sync_bending_tournament_history_world_feed()
		return

	var source_text: String = str(options.get("source", "bending_engine")).strip_edges().to_lower()
	var ui_hot_path: bool = source_text in [
		"hub_payload",
		"tournament_history_payload",
		"match_archive_payload",
		"bending_hub_match_archive_pressed_deferred",
		"bending_hub_tournament_history_pressed_deferred",
		"bending_hub_surface_prewarm",
		"bending_hub_runtime_surface_cache",
		"bending_hub_enter_tournament_deferred"
	]

	_bootstrap_bending_child_population_floor()
	_seed_previous_avatar_history_for_current_world()
	_seed_established_bending_records_for_population(options)

	if ui_hot_path and not bool(options.get("allow_heavy_bootstrap", false)):
		_seed_lightweight_opening_bending_history(options)
		_refresh_bending_tournament_recordboards([])
		_sync_bending_tournament_history_world_feed()

		state = _bending_world_state()
		state ["bootstrap_seeded"] = true
		state ["bootstrap_seeded_year"] = int(gs.year)
		state ["bootstrap_source"] = str(options.get("source", "bending_engine"))
		state ["bootstrap_mode"] = "ui_safe_lightweight_history"
		state ["heavy_tournament_truth_deferred"] = true
		state ["heavy_tournament_truth_deferred_reason"] = source_text
		state ["heavy_tournament_truth_deferred_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["bending_world_championship"] = state
		return

	_bootstrap_opening_bending_records(options)
	_refresh_bending_tournament_recordboards([])
	_sync_bending_tournament_history_world_feed()

	state = _bending_world_state()
	state ["bootstrap_seeded"] = true
	state ["bootstrap_seeded_year"] = int(gs.year)
	state ["bootstrap_source"] = str(options.get("source", "bending_engine"))
	state ["bootstrap_mode"] = "full_opening_tournament_history"
	gs.scenario_state ["bending_world_championship"] = state
func _seed_lightweight_opening_bending_history(_options: Dictionary = {}) -> void:
	if gs == null:
		return

	var state: Dictionary = _bending_world_state()
	var history: Array = state.get("tournament_history", []) if typeof(state.get("tournament_history", [])) == TYPE_ARRAY else []
	var archive: Array = state.get("match_archive", []) if typeof(state.get("match_archive", [])) == TYPE_ARRAY else []

	var existing_history_ids: Dictionary = {}
	for raw_history in history:
		if typeof(raw_history) != TYPE_DICTIONARY:
			continue
		var history_row: Dictionary = raw_history
		var existing_id: String = str(history_row.get("tournament_id", "")).strip_edges()
		if existing_id != "":
			existing_history_ids [existing_id] = true

	var policy: Dictionary = _bending_world_policy()
	var history_years: int = max(5, int(policy.get("opening_history_years", 16)))
	var divisions: Array = ["youth", "adult", "elder_male", "elder_female"]
	var start_year: int = int(gs.year) - history_years

	for h in range(history_years):
		var history_year: int = start_year + h
		for raw_division in divisions:
			var division: String = str(raw_division).strip_edges().to_lower()
			var tournament_id: String = _bending_tournament_id_for_division(division, history_year)
			if existing_history_ids.has(tournament_id):
				continue

			var eligible: Array = _eligible_benders_for_division(division, {
				"source": "lightweight_opening_history",
				"bootstrap": true,
				"tournament_year": history_year
			})

			if eligible.is_empty():
				continue

			eligible.sort_custom(func (a, b):
				var score_a: float = _bending_competitive_score(a, division, false)
				var score_b: float = _bending_competitive_score(b, division, false)
				var noise_a: int = abs(int(("%d:%d:%s" % [int(a.id), history_year, division]).hash())) % 1000
				var noise_b: int = abs(int(("%d:%d:%s" % [int(b.id), history_year, division]).hash())) % 1000
				score_a += float(noise_a) / 1000.0
				score_b += float(noise_b) / 1000.0
				if score_a == score_b:
					return int(a.id) < int(b.id)
				return score_a > score_b
			)

			var winner: Person = eligible [0]
			if winner == null:
				continue

			var label: String = "Bending World Championship"
			match division:
				"youth":
					label = "Youth Bending World Championship"
				"adult":
					label = "Adult Bending World Championship"
				"elder_male":
					label = "Elder Men's Bending World Championship"
				"elder_female":
					label = "Elder Women's Bending World Championship"

			var tournament: Dictionary = {
				"schema": "eralife.bending_tournament",
				"version": 3,
				"id": tournament_id,
				"year": history_year,
				"division": division,
				"requested_division": division,
				"label": label,
				"status": "complete",
				"champion_id": int(winner.id),
				"champion_name": _bending_person_label(winner),
				"completed_year": history_year,
				"bootstrap": true,
				"historical_backfill": true,
				"bracket": []
			}

			_normalize_historical_champion_tournament_wins(winner, tournament, {
				"source": "lightweight_opening_history",
				"bootstrap": true,
				"historical_backfill": true,
				"tournament_year": history_year
			})

			_register_bending_tournament_history_result(winner, tournament, {
				"source": "lightweight_opening_history",
				"bootstrap": true,
				"historical_backfill": true,
				"simulated": true
			})

			if division == "adult":
				_register_tournament_of_champions_bid(winner, tournament)

			var rival: Person = null
			if eligible.size() > 1:
				rival = eligible [1]

			var participant_ids: Array = [int(winner.id)]
			var participant_names: Array = [_bending_person_label(winner)]
			if rival != null:
				participant_ids.append(int(rival.id))
				participant_names.append(_bending_person_label(rival))

			archive.append({
				"schema": "eralife.bending_match_archive_row",
				"version": 1,
				"id": "%s_archive_final" % tournament_id,
				"year": history_year,
				"year_label": _format_avatar_world_year(history_year),
				"tournament_id": tournament_id,
				"tournament_label": label,
				"division": division,
				"winner_id": int(winner.id),
				"winner_name": _bending_person_label(winner),
				"participant_ids": participant_ids,
				"participant_names": participant_names,
				"historic": true,
				"mythic": false,
				"legendary_score": 42 + (abs(int(tournament_id.hash())) % 24),
				"summary": "%s won the %s before this life began." % [_bending_person_label(winner), label],
				"source": "lightweight_opening_history"
			})

			existing_history_ids [tournament_id] = true

	while archive.size() > 160:
		archive.pop_front()

	state = _bending_world_state()
	state ["match_archive"] = archive
	gs.scenario_state ["bending_world_championship"] = state

func _bootstrap_opening_bending_records(_options: Dictionary = {}) -> void:
	if gs == null:
		return

	var policy: Dictionary = _bending_world_policy()
	var history_years: int = max(5, int(policy.get("opening_history_years", 16)))
	var divisions: Array = ["youth", "adult", "elder_male", "elder_female"]
	var start_year: int = int(gs.year) - history_years

	for h in range(history_years):
		var history_year: int = start_year + h
		for raw_division in divisions:
			var division: String = str(raw_division)
			var tournament: Dictionary = _ensure_bending_tournament_for_division(division, null, {
				"force_include_actor": false,
				"source": "world_birth_bootstrap",
				"bootstrap": true,
				"force_all_eligible": false,
				"history_offset": h,
				"tournament_year": history_year
			})

			if tournament.is_empty():
				continue

			if str(tournament.get("status", "")).strip_edges().to_lower() == "active":
				_settle_bending_cpu_tournament(str(tournament.get("id", "")), -1, {
					"source": "world_birth_bootstrap",
					"bootstrap": true,
					"history_offset": h,
					"tournament_year": history_year
				})

	_refresh_bending_tournament_recordboards([])


func _seed_previous_avatar_history_for_current_world() -> void:
	if gs == null:
		return

	var current_avatar: Person = null
	for raw_npc in gs.npcs:
		if raw_npc == null:
			continue

		var npc: Person = raw_npc
		if str(npc.bending_type).strip_edges().to_lower() == "avatar" and bool(npc.alive):
			current_avatar = npc
			break

	if current_avatar == null and gs.player != null and str(gs.player.bending_type).strip_edges().to_lower() == "avatar":
		current_avatar = gs.player

	if current_avatar == null:
		return

	_seed_previous_avatar_history_for_birth(current_avatar)


func _seed_previous_avatar_history_for_birth(current_avatar: Person) -> void:
	if gs == null or current_avatar == null:
		return

	var state: Dictionary = _bending_world_state()
	var previous: Array = state.get("previous_avatars", [])
	if previous.size() >= 4:
		return

	var cycle: Array = _avatar_cycle_nations()
	if cycle.is_empty():
		return

	var current_nation: String = _normalize_avatar_cycle_nation(str(current_avatar.bending_nation))
	if current_nation == "":
		current_nation = _normalize_avatar_cycle_nation(str(NATIONS.pick_random()))
	if current_nation == "":
		current_nation = str(cycle [0])

	var current_index: int = cycle.find(current_nation)
	if current_index < 0:
		current_index = 0

	var current_avatar_birth_year: int = int(gs.year) - int(current_avatar.age)
	var running_death_year: int = current_avatar_birth_year
	var needed: int = 4 - previous.size()
	var generated: Array = []

	for i in range(needed):
		var cycle_index: int = current_index - (i + 1)
		while cycle_index < 0:
			cycle_index += cycle.size()

		var nation: String = str(cycle [cycle_index])
		var lifespan: int = randi_range(52, 96)
		var born_year: int = running_death_year - lifespan
		var died_year: int = running_death_year

		generated.append({
			"schema": "eralife.previous_avatar_record",
			"version": 3,
			"name": "Avatar %s" % _avatar_history_name_seed(nation, i),
			"nation": nation,
			"native_element": _element_from_nation(nation),
			"birth_year": born_year,
			"birth_year_label": _format_avatar_world_year(born_year),
			"death_year": died_year,
			"death_year_label": _format_avatar_world_year(died_year),
			"lifespan": lifespan,
			"reputation_imprint": _previous_avatar_reputation_seed(nation, i, lifespan),
			"seeded": true,
			"seeded_for_avatar_id": int(current_avatar.id)
		})
		running_death_year = born_year

	generated.reverse()

	for record in generated:
		previous.append(record)

	while previous.size() > 12:
		previous.pop_front()

	state ["previous_avatars"] = previous
	gs.scenario_state ["bending_world_championship"] = state
	get_previous_avatar_reputation_imprint(current_avatar, {
		"source": "previous_avatar_birth_seed"
	})
func _format_avatar_world_year(year_value: int) -> String:
	if year_value >= 1:
		return "%d AD" % year_value

	return "%d BCE" % abs(year_value - 1)


func _avatar_history_name_seed(nation: String, offset: int) -> String:
	var element: String = _element_from_nation(nation)
	match element:
		"air":
			return ["Luan", "Sora", "Tenzai", "Ari"] [offset % 4]
		"water":
			return ["Naya", "Korrai", "Tala", "Unali"] [offset % 4]
		"earth":
			return ["Bolin", "Jin", "Taro", "Kyoshiro"] [offset % 4]
		"fire":
			return ["Roku", "Azan", "Kai", "Rina"] [offset % 4]
	return "Unknown"


func yearly_tick(_payload:= {}) -> void:
	if gs == null or not gs.is_feature_enabled("bending"):
		return

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue

		_apply_ai_bending_progression(npc)
		_apply_elder_bending_decline(npc)

	if gs.player != null and bool(gs.player.alive):
		_apply_elder_bending_decline(gs.player)

	_run_bending_world_stage_yearly_tick(_payload)

func _apply_ai_bending_progression(actor: Person) -> void:
	if actor == null:
		return
	if not bool(actor.alive):
		return
	if str(actor.bending_type).strip_edges().to_lower() == "none":
		return

	ensure_bending_level_state(actor)

	var training_elements: Array = get_bending_training_elements(actor)
	if training_elements.is_empty():
		return

	var element: String = str(training_elements.pick_random()).strip_edges().to_lower()
	if element == "":
		return

	var ambition_bonus: int = clamp(int(floor(float(actor.ambition) / 25.0)), 0, 4)
	var progress_gain: int = randi_range(0, 3) + ambition_bonus

	if progress_gain <= 0:
		return

	gain_bending_progress(actor, element, progress_gain, "ai_yearly_bending_progression")

	if randf() < 0.18:
		award_bending_skill_points(actor, 1, "ai_yearly_bending_growth")
func _apply_elder_bending_decline(npc: Person) -> void:
	if npc == null:
		return

	var age: int = int(npc.age)
	if age < BENDING_ELDER_DECLINE_START_AGE:
		return

	ensure_bending_level_state(npc)

	var decline_chance: int = 8
	if age >= BENDING_ELDER_DECLINE_HARD_AGE:
		decline_chance = 18
	elif age >= 82:
		decline_chance = 12

	var bending_level_declined: bool = false

	for element in _active_elements_for_actor(npc):
		var current_level: int = get_bending_level(npc, str(element))
		if current_level <= BENDING_ELDER_DECLINE_FLOOR:
			continue
		if randi() % 100 >= decline_chance:
			continue

		var loss: int = 1
		if age >= BENDING_ELDER_DECLINE_HARD_AGE and randi() % 100 < 35:
			loss += 1

		npc.bending_mastery [str(element)] = clamp(current_level - loss, BENDING_ELDER_DECLINE_FLOOR, BENDING_LEVEL_MAX)
		bending_level_declined = true

	if bending_level_declined and gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(npc)
func _active_elements_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	ensure_bending_level_state(actor)

	if str(actor.bending_type) == "avatar":
		for avatar_element in _base_bending_elements():
			out.append(avatar_element)
		return out

	for element in _base_bending_elements():
		if get_bending_level(actor, element) > 0 or str(actor.bending_type) == element:
			out.append(element)

	return out
func _bending_awakening_log() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get("bending_awakening_moments", {})
	var data: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	gs.scenario_state ["bending_awakening_moments"] = data
	return data


func _bending_awakening_moment_key(npc: Person, element: String, tier_id: String) -> String:
	if npc == null:
		return ""
	return "%d:%s:%s" % [
		int(npc.id),
		str(element).strip_edges().to_lower(),
		str(tier_id).strip_edges().to_lower()
	]


func _bending_awakening_moments() -> Array:
	return [
		{
			"id": "first_response",
			"level": 1
		},
		{
			"id": "formed_control",
			"level": 25
		},
		{
			"id": "deep_response",
			"level": 55
		},
		{
			"id": "mastery_presence",
			"level": 85
		},
		{
			"id": "legendary_presence",
			"level": 95
		}
	]


func _bending_awakening_diary_text(element: String, tier_id: String) -> String:
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_tier: String = str(tier_id).strip_edges().to_lower()

	match clean_element:
		"air":
			match clean_tier:
				"first_response":
					return "I felt the air answer me for the first time."
				"formed_control":
					return "I stopped chasing the wind and started moving with it."
				"deep_response":
					return "The air around me felt alive, like it knew where I wanted to go."
				"mastery_presence":
					return "My airbending became calm, precise, and almost impossible to trap."
				"legendary_presence":
					return "The air bent around my intent like the sky itself recognized me."
		"water":
			match clean_tier:
				"first_response":
					return "I felt the water respond for the first time."
				"formed_control":
					return "The water started moving with my breath instead of against my fear."
				"deep_response":
					return "My waterbending began to flow through emotion, patience, and control."
				"mastery_presence":
					return "My waterbending became adaptable, healing, defensive, and dangerous."
				"legendary_presence":
					return "The water moved like a living mirror of my soul."
		"earth":
			match clean_tier:
				"first_response":
					return "I felt the earth respond for the first time."
				"formed_control":
					return "The ground started trusting my stance."
				"deep_response":
					return "The earth beneath me felt steady, heavy, and awake."
				"mastery_presence":
					return "My earthbending became immovable, like the world had accepted my command."
				"legendary_presence":
					return "The earth answered me like an ancient giant opening its eyes."
		"fire":
			match clean_tier:
				"first_response":
					return "I felt fire answer my breath for the first time."
				"formed_control":
					return "My fire stopped feeling wild and started feeling disciplined."
				"deep_response":
					return "The flame moved cleaner now, stronger without becoming reckless."
				"mastery_presence":
					return "My firebending became controlled power instead of uncontrolled heat."
				"legendary_presence":
					return "The fire burned like sunlight had learned my name."

	return "I felt my bending awaken in a way I could not ignore."


func _bending_awakening_world_text(npc: Person, element: String, tier_id: String) -> String:
	if npc == null:
		return ""

	var full_name: String = ("%s %s" % [npc.first_name, npc.last_name]).strip_edges()
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_tier: String = str(tier_id).strip_edges().to_lower()

	match clean_tier:
		"first_response":
			return "%s felt %s bending answer for the first time." % [full_name, clean_element]
		"formed_control":
			return "%s began forming real control over %s bending." % [full_name, clean_element]
		"deep_response":
			return "%s reached a deeper response in %s bending." % [full_name, clean_element]
		"mastery_presence":
			return "%s's %s bending presence crossed into mastery." % [full_name, clean_element]
		"legendary_presence":
			return "%s's %s bending began to feel legendary." % [full_name, clean_element]

	return "%s experienced a %s bending awakening." % [full_name, clean_element]


func _is_world_feed_worthy_bending_awakening(npc: Person, tier_id: String) -> bool:
	if gs == null or npc == null:
		return false

	if gs.player != null and int(npc.id) == int(gs.player.id):
		return true

	if str(npc.bending_type).strip_edges().to_lower() == "avatar":
		return true

	if bool(npc.is_ruler) or bool(npc.is_royal):
		return true

	if int(npc.fame) >= 60:
		return true

	if str(tier_id) in ["mastery_presence", "legendary_presence"]:
		return true

	return false


func _record_bending_awakening_moment(npc: Person, element: String, tier_id: String, level_value: int) -> Dictionary:
	if gs == null or npc == null:
		return {}

	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_tier: String = str(tier_id).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return {}

	var key: String = _bending_awakening_moment_key(npc, clean_element, clean_tier)
	if key == "":
		return {}

	var awakening_log:= _bending_awakening_log()
	if bool(awakening_log.get(key, false)):
		return {}

	awakening_log [key] = true
	gs.scenario_state ["bending_awakening_moments"] = awakening_log

	var diary_text: String = _bending_awakening_diary_text(clean_element, clean_tier)
	var world_text: String = _bending_awakening_world_text(npc, clean_element, clean_tier)

	if gs.memory_engine != null:
		gs.memory_engine.remember(int(npc.id), diary_text)

	if gs.legacy_memory_engine != null:
		gs.legacy_memory_engine.record_dynasty_event(npc, diary_text)

	if _is_world_feed_worthy_bending_awakening(npc, clean_tier) and gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"npc_id": int(npc.id),
			"personally_relevant": gs.player != null and int(npc.id) == int(gs.player.id),
			"category": "bending",
			"event_name": "bending_awakening",
			"source": "bending_engine",
			"element": clean_element,
			"awakening_tier": clean_tier,
			"level": int(level_value),
			"player_text": diary_text,
			"world_text": world_text
		})

	return {
		"tier_id": clean_tier,
		"element": clean_element,
		"level": int(level_value),
		"diary_text": diary_text,
		"world_text": world_text
	}


func _process_bending_awakening_moments(npc: Person, element: String, old_level: int, new_level: int) -> Array:
	var out: Array = []
	if npc == null:
		return out

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return out

	var safe_old: int = clamp(int(old_level), 0, BENDING_LEVEL_MAX)
	var safe_new: int = clamp(int(new_level), 0, BENDING_LEVEL_MAX)
	if safe_new <= safe_old:
		return out

	for raw_moment in _bending_awakening_moments():
		var moment: Dictionary = raw_moment
		var threshold: int = int(moment.get("level", 0))
		var tier_id: String = str(moment.get("id", "")).strip_edges()
		if threshold <= 0 or tier_id == "":
			continue
		if safe_old < threshold and safe_new >= threshold:
			var recorded: Dictionary = _record_bending_awakening_moment(npc, clean_element, tier_id, safe_new)
			if not recorded.is_empty():
				out.append(recorded)

	return out
func _elemental_realm_name_keys(entry: Dictionary, realm: Dictionary) -> Array:
	var keys: Array = []

	var candidate_values: Array = [
		realm.get("name", ""),
		entry.get("name", ""),
		entry.get("entry_name", ""),
		entry.get("entry_id", ""),
		realm.get("id", ""),
		realm.get("capital_city", ""),
		realm.get("capital", ""),
		realm.get("bending_nation", ""),
		realm.get("native_nation", "")
	]

	for raw_value in candidate_values:
		var clean_value: String = str(raw_value).strip_edges().to_lower()
		if clean_value != "" and clean_value not in keys:
			keys.append(clean_value)

	return keys

func _elemental_realm_numeric_id(entry: Dictionary, realm: Dictionary) -> int:
	var candidate_values: Array = [
		entry.get("realm_id", -1),
		realm.get("realm_id", -1),
		realm.get("numeric_id", -1),
		entry.get("entry_id", -1),
		realm.get("id", -1)
	]

	for raw_value in candidate_values:
		var text_value: String = str(raw_value).strip_edges()
		if text_value == "":
			continue
		if text_value.is_valid_int():
			var resolved_id: int = int(text_value)
			if resolved_id > 0:
				return resolved_id

	return -1


func _person_is_direct_child_of_ruler(person: Person, ruler: Person) -> bool:
	if person == null or ruler == null:
		return false

	var person_id: int = int(person.id)
	var ruler_id: int = int(ruler.id)

	if person_id <= 0 or ruler_id <= 0:
		return false

	if person.parents.has(ruler_id):
		return true

	if ruler.children.has(person_id):
		return true

	return false


func _person_has_elemental_realm_succession_context(person: Person, entry: Dictionary, realm: Dictionary, ruler: Person) -> bool:
	if person == null:
		return false
	if not bool(person.alive):
		return false

	if ruler != null and int(person.id) == int(ruler.id):
		return false

	if _person_is_direct_child_of_ruler(person, ruler):
		return true

	var realm_id: int = _elemental_realm_numeric_id(entry, realm)
	if realm_id > 0 and int(person.realm_id) == realm_id:
		return true

	var has_succession_marker: bool = (
		bool(person.is_royal)
		or bool(person.is_ruler)
		or int(person.succession_rank) > 0
	)

	if not has_succession_marker:
		return false

	var home_country: String = str(person.home_country).strip_edges().to_lower()
	var birth_country: String = str(person.birth_country).strip_edges().to_lower()
	var realm_keys: Array = _elemental_realm_name_keys(entry, realm)

	for raw_key in realm_keys:
		var key_text: String = str(raw_key).strip_edges().to_lower()
		if key_text == "":
			continue
		if home_country == key_text or birth_country == key_text:
			return true

	return false
func _person_matches_elemental_realm(person: Person, entry: Dictionary, realm: Dictionary, element: String) -> bool:
	if person == null:
		return false
	if not bool(person.alive):
		return false

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return false

	ensure_bending_level_state(person)

	var person_bending_type: String = str(person.bending_type).strip_edges().to_lower()
	var person_level: int = get_bending_level(person, clean_element)
	if person_bending_type != clean_element and person_bending_type != "avatar" and person_level <= 0:
		return false

	var realm_keys: Array = _elemental_realm_name_keys(entry, realm)
	if realm_keys.is_empty():
		return false

	var home_country: String = str(person.home_country).strip_edges().to_lower()
	var birth_country: String = str(person.birth_country).strip_edges().to_lower()
	var bending_nation: String = str(person.bending_nation).strip_edges().to_lower()

	for realm_key in realm_keys:
		var key_text: String = str(realm_key)
		if key_text == "":
			continue
		if home_country == key_text or birth_country == key_text or bending_nation == key_text:
			return true
		if bending_nation != "" and key_text.find(bending_nation) != -1:
			return true
		if home_country != "" and key_text.find(home_country) != -1:
			return true

	var realm_name: String = str(realm.get("name", entry.get("name", ""))).strip_edges().to_lower()
	if realm_name.find("fire") != -1 and clean_element == "fire":
		return true
	if realm_name.find("water") != -1 and clean_element == "water":
		return true
	if realm_name.find("earth") != -1 and clean_element == "earth":
		return true
	if realm_name.find("air") != -1 and clean_element == "air":
		return true

	return false


func _resolve_elemental_realm_ruler(entry: Dictionary, realm: Dictionary, element: String) -> Person:
	if gs == null:
		return null

	var ruler_id: int = int(realm.get("ruler_id", realm.get("ruler_npc_id", realm.get("leader_id", -1))))
	if ruler_id > 0:
		var direct_ruler: Person = gs.get_or_reactivate_npc_by_id(ruler_id)
		if direct_ruler != null:
			ensure_realm_leader_bending_state(direct_ruler, realm)
			return direct_ruler

	var ruler_name: String = str(realm.get("ruler_name", "")).strip_edges().to_lower()
	if ruler_name != "" and ruler_name != "no fixed ruler":
		for raw_npc in gs.npcs:
			var npc: Person = raw_npc
			if npc == null:
				continue

			var full_name: String = ("%s %s" % [npc.first_name, npc.last_name]).strip_edges().to_lower()
			if full_name == ruler_name:
				ensure_realm_leader_bending_state(npc, realm)
				return npc

	for raw_candidate in gs.npcs:
		var candidate: Person = raw_candidate
		if candidate == null:
			continue
		if not bool(candidate.alive):
			continue
		if not bool(candidate.is_ruler):
			continue
		if _person_matches_elemental_realm(candidate, entry, realm, element):
			ensure_realm_leader_bending_state(candidate, realm)
			return candidate

	return null


func _elemental_realm_figure_payload(person: Person, element: String, role: String) -> Dictionary:
	if person == null:
		return {}

	var clean_element: String = str(element).strip_edges().to_lower()
	ensure_bending_level_state(person)

	var level_value: int = get_bending_level(person, clean_element)
	var bending_type_text: String = str(person.bending_type).strip_edges().capitalize()
	if bending_type_text == "":
		bending_type_text = clean_element.capitalize()

	var clean_role: String = str(role).strip_edges().to_lower()
	var is_heir_role: bool = clean_role.find("heir") != -1
	var is_ruler_role: bool = clean_role.find("ruler") != -1
	var is_top_bender_role: bool = clean_role.find("top") != -1 or clean_role.find("bender") != -1

	var title_text: String = str(person.royal_title).strip_edges()

	if is_top_bender_role and not is_heir_role and not is_ruler_role:
		title_text = "Bender"
	elif title_text == "":
		if is_ruler_role or bool(person.is_ruler):
			title_text = "Ruler"
		elif is_heir_role:
			title_text = "Possible Heir"
		elif bool(person.is_royal):
			title_text = "Royal"
		else:
			title_text = "Bender"

	var aura_tier: String = "Awakened"
	if level_value >= 95:
		aura_tier = "Legendary"
	elif level_value >= 85:
		aura_tier = "Master"
	elif level_value >= 65:
		aura_tier = "High-Tier"
	elif level_value >= 35:
		aura_tier = "Trained"

	var visible_succession_rank: int = 0
	if is_heir_role:
		visible_succession_rank = int(person.succession_rank)

	return {
		"id": int(person.id),
		"name": ("%s %s" % [person.first_name, person.last_name]).strip_edges(),
		"age": int(person.age),
		"role": str(role),
		"title": title_text,
		"bending_type": bending_type_text,
		"element": clean_element,
		"level": level_value,
		"succession_rank": visible_succession_rank,
		"is_ruler": bool(person.is_ruler),
		"is_royal": bool(person.is_royal),
		"fame": int(person.fame),
		"fame_tier": str(person.fame_tier),
		"aura_tier": aura_tier,
		"home_country": str(person.home_country),
		"bending_nation": str(person.bending_nation)
	}


func get_elemental_realm_notable_figures(entry: Dictionary, realm: Dictionary, element: String, top_limit: int = 5, heir_limit: int = 4) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var out:= {
		"element": clean_element,
		"ruler": {},
		"possible_heirs": [],
		"top_benders": []
	}

	if gs == null:
		return out
	if clean_element not in _base_bending_elements():
		return out

	var ruler: Person = _resolve_elemental_realm_ruler(entry, realm, clean_element)
	if ruler != null:
		out ["ruler"] = _elemental_realm_figure_payload(ruler, clean_element, "Ruler")

	var candidates: Array = []
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null:
			continue
		if not _person_matches_elemental_realm(npc, entry, realm, clean_element):
			continue

		var payload: Dictionary = _elemental_realm_figure_payload(npc, clean_element, "Top Bender")
		if payload.is_empty():
			continue

		candidates.append(payload)

	candidates.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		var a_score: float = float(a.get("level", 0)) + (float(a.get("fame", 0)) / 4.0)
		var b_score: float = float(b.get("level", 0)) + (float(b.get("fame", 0)) / 4.0)
		if is_equal_approx(a_score, b_score):
			return int(a.get("level", 0)) > int(b.get("level", 0))
		return a_score > b_score
	)

	var seen_top_ids:= {}
	for candidate_payload in candidates:
		var candidate_id: int = int(candidate_payload.get("id", -1))
		if candidate_id <= 0:
			continue
		if seen_top_ids.has(candidate_id):
			continue

		seen_top_ids [candidate_id] = true
		out ["top_benders"].append(candidate_payload)

		if out ["top_benders"].size() >= max(1, top_limit):
			break

	var heir_pool: Array = []
	var seen_heir_ids:= {}

	if ruler != null:
		for raw_child_id in ruler.children:
			var child: Person = gs.get_or_reactivate_npc_by_id(int(raw_child_id))
			if child == null:
				continue
			if not bool(child.alive):
				continue
			if seen_heir_ids.has(int(child.id)):
				continue

			seen_heir_ids [int(child.id)] = true
			var child_payload: Dictionary = _elemental_realm_figure_payload(child, clean_element, "Possible Heir")
			heir_pool.append(child_payload)

	for raw_npc in gs.npcs:
		var heir_candidate: Person = raw_npc
		if heir_candidate == null:
			continue
		if not bool(heir_candidate.alive):
			continue
		if seen_heir_ids.has(int(heir_candidate.id)):
			continue
		if int(heir_candidate.succession_rank) <= 0:
			continue
		if int(heir_candidate.succession_rank) > 12 and not bool(heir_candidate.is_royal):
			continue
		if not _person_has_elemental_realm_succession_context(heir_candidate, entry, realm, ruler):
			continue

		seen_heir_ids [int(heir_candidate.id)] = true
		heir_pool.append(_elemental_realm_figure_payload(heir_candidate, clean_element, "Possible Heir"))

	heir_pool.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		var a_rank: int = int(a.get("succession_rank", 9999))
		var b_rank: int = int(b.get("succession_rank", 9999))

		if a_rank <= 0:
			a_rank = 9999
		if b_rank <= 0:
			b_rank = 9999

		if a_rank == b_rank:
			return int(a.get("age", 0)) > int(b.get("age", 0))

		return a_rank < b_rank
	)

	for heir_payload in heir_pool:
		out ["possible_heirs"].append(heir_payload)

		if out ["possible_heirs"].size() >= max(1, heir_limit):
			break

	return out

func _actor_has_corrupted_bending(actor: Person, element: String = "") -> bool:
	if actor == null:
		return false

	var clean_element: String = str(element).strip_edges().to_lower()

	for raw_trait in actor.traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("corrupt") == -1 and trait_text.find("dark") == -1 and trait_text.find("taint") == -1:
			continue
		if trait_text.find("bending") != -1:
			return true
		if clean_element != "" and trait_text.find(clean_element) != -1:
			return true
		if trait_text in ["dark avatar", "corrupted avatar", "corrupted_bending", "dark_bending"]:
			return true

	return false


func get_bending_ability_visual_profile(actor: Person, ability: Dictionary) -> Dictionary:
	var profile:= {
		"visual_tier": "low",
		"visual_rank": 1,
		"visual_label": "Subtle Glow",
		"aura_radius": 12,
		"aura_alpha": 0.22,
		"pulse_speed": 0.85,
		"distortion": false,
		"legendary_vignette": false,
		"legendary_mastery": false,
		"corrupted_bending": false,
		"avatar_pulse": false
	}

	if actor == null or ability.is_empty():
		return profile

	var element: String = str(ability.get("element", "")).strip_edges().to_lower()
	var required_level: int = int(ability.get("level", 0))
	var current_level: int = int(ability.get("current_level", get_bending_level(actor, element)))
	var impact: String = str(ability.get("impact", "normal")).strip_edges().to_lower()
	var is_avatar: bool = str(actor.bending_type).strip_edges().to_lower() == "avatar"
	var corrupted: bool = _actor_has_corrupted_bending(actor, element)
	var legendary_mastery: bool = current_level >= 95

	if required_level >= 95 or impact == "catastrophic":
		profile ["visual_tier"] = "legendary"
		profile ["visual_rank"] = 4
		profile ["visual_label"] = "Legendary Ambient"
		profile ["aura_radius"] = 48
		profile ["aura_alpha"] = 0.54
		profile ["pulse_speed"] = 1.75
		profile ["distortion"] = true
		profile ["legendary_vignette"] = true
	elif required_level >= 70 or impact == "elite":
		profile ["visual_tier"] = "high"
		profile ["visual_rank"] = 3
		profile ["visual_label"] = "Breathing Distortion"
		profile ["aura_radius"] = 34
		profile ["aura_alpha"] = 0.42
		profile ["pulse_speed"] = 1.35
		profile ["distortion"] = true
	elif required_level >= 35 or impact == "heavy":
		profile ["visual_tier"] = "mid"
		profile ["visual_rank"] = 2
		profile ["visual_label"] = "Pulsing Aura"
		profile ["aura_radius"] = 24
		profile ["aura_alpha"] = 0.32
		profile ["pulse_speed"] = 1.05

	if legendary_mastery:
		profile ["legendary_mastery"] = true
		profile ["aura_radius"] = int(profile.get("aura_radius", 12)) + 18
		profile ["aura_alpha"] = clamp(float(profile.get("aura_alpha", 0.22)) + 0.12, 0.0, 0.8)

	if corrupted:
		profile ["corrupted_bending"] = true
		profile ["visual_label"] = "Corrupted %s" % str(profile.get("visual_label", "Aura"))

	if is_avatar:
		profile ["avatar_pulse"] = true

	return profile
func _bending_element_personality_profile(element: String) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()

	match clean_element:
		"fire":
			return {
				"id": "fire",
				"name": "Aggressive Growth",
				"description": "Fire grows quickly early, spikes from pressure, but becomes harder to discipline at high levels.",
				"early_scale": 1.22,
				"mid_scale": 1.06,
				"late_scale": 0.88,
				"mastery_scale": 0.78
			}
		"water":
			return {
				"id": "water",
				"name": "Adaptive Flow",
				"description": "Water adapts to the bender's condition, learning well through guidance, recovery, and emotional stability.",
				"early_scale": 1.0,
				"mid_scale": 1.08,
				"late_scale": 1.02,
				"mastery_scale": 0.94
			}
		"earth":
			return {
				"id": "earth",
				"name": "Slow Power",
				"description": "Earth grows slowly at first, but becomes powerful and durable once the foundation is built.",
				"early_scale": 0.78,
				"mid_scale": 0.94,
				"late_scale": 1.18,
				"mastery_scale": 1.08
			}
		"air":
			return {
				"id": "air",
				"name": "Technical Evasion",
				"description": "Air rewards intelligence, rhythm, and control. It is technical rather than brute-force.",
				"early_scale": 0.96,
				"mid_scale": 1.12,
				"late_scale": 1.04,
				"mastery_scale": 0.96
			}

	return {
		"id": clean_element,
		"name": "Neutral Growth",
		"description": "This element follows a balanced growth curve.",
		"early_scale": 1.0,
		"mid_scale": 1.0,
		"late_scale": 1.0,
		"mastery_scale": 1.0
	}


func _bending_element_growth_modifier(npc: Person, element: String, current_level: int, reason:= "") -> float:
	if npc == null:
		return 1.0

	var clean_element: String = str(element).strip_edges().to_lower()
	var profile: Dictionary = _bending_element_personality_profile(clean_element)
	var modifier: float = 1.0

	if current_level < 25:
		modifier *= float(profile.get("early_scale", 1.0))
	elif current_level < 60:
		modifier *= float(profile.get("mid_scale", 1.0))
	elif current_level < 85:
		modifier *= float(profile.get("late_scale", 1.0))
	else:
		modifier *= float(profile.get("mastery_scale", 1.0))

	var reason_text: String = str(reason).strip_edges().to_lower()

	match clean_element:
		"fire":
			if reason_text.find("fight") != -1 or reason_text.find("combat") != -1 or reason_text.find("pressure") != -1:
				modifier *= 1.1
			if float(npc.satisfaction) < 35.0 or float(npc.mental_health) < 35.0:
				modifier *= 1.06
		"water":
			if reason_text.find("guided") != -1 or reason_text.find("teacher") != -1:
				modifier *= 1.1
			if float(npc.mental_health) >= 65.0:
				modifier *= 1.06
			elif float(npc.mental_health) < 35.0:
				modifier *= 0.9
		"earth":
			if current_level >= 55:
				modifier *= 1.08
			if reason_text.find("solo") != -1:
				modifier *= 1.04
		"air":
			if int(npc.smarts) >= 70:
				modifier *= 1.12
			if reason_text.find("technical") != -1 or reason_text.find("precision") != -1:
				modifier *= 1.1

	return clamp(modifier, 0.35, 1.75)


func _avatar_balance_snapshot(npc: Person, focus_element: String = "") -> Dictionary:
	var snapshot:= {
		"is_avatar": false,
		"focus_element": str(focus_element).strip_edges().to_lower(),
		"lowest_level": 0,
		"highest_level": 0,
		"average_level": 0.0,
		"spread": 0,
		"weakest_elements": [],
		"strongest_elements": [],
		"focus_is_weakest": false,
		"focus_is_strongest": false,
		"imbalance_tier": "none"
	}

	if npc == null:
		return snapshot

	if str(npc.bending_type).strip_edges().to_lower() != "avatar":
		return snapshot

	ensure_bending_level_state(npc)
	snapshot ["is_avatar"] = true

	var lowest_level: int = BENDING_LEVEL_MAX
	var highest_level: int = 0
	var total_level: int = 0
	var element_count: int = 0
	var levels:= {}

	for raw_element in _base_bending_elements():
		var element: String = str(raw_element).strip_edges().to_lower()
		var level_value: int = get_bending_level(npc, element)
		levels [element] = level_value
		lowest_level = min(lowest_level, level_value)
		highest_level = max(highest_level, level_value)
		total_level += level_value
		element_count += 1

	if element_count <= 0:
		return snapshot

	var average_level: float = float(total_level) / float(element_count)
	var spread: int = highest_level - lowest_level
	var weakest_elements: Array = []
	var strongest_elements: Array = []

	for element_key in levels.keys():
		var element_level: int = int(levels [element_key])
		if element_level == lowest_level:
			weakest_elements.append(str(element_key))
		if element_level == highest_level:
			strongest_elements.append(str(element_key))

	var clean_focus: String = str(focus_element).strip_edges().to_lower()
	var imbalance_tier: String = "none"
	if spread >= 35:
		imbalance_tier = "severe"
	elif spread >= 22:
		imbalance_tier = "high"
	elif spread >= 12:
		imbalance_tier = "moderate"
	elif spread >= 6:
		imbalance_tier = "light"

	snapshot ["lowest_level"] = lowest_level
	snapshot ["highest_level"] = highest_level
	snapshot ["average_level"] = average_level
	snapshot ["spread"] = spread
	snapshot ["weakest_elements"] = weakest_elements
	snapshot ["strongest_elements"] = strongest_elements
	snapshot ["focus_is_weakest"] = clean_focus in weakest_elements
	snapshot ["focus_is_strongest"] = clean_focus in strongest_elements
	snapshot ["imbalance_tier"] = imbalance_tier

	return snapshot


func _avatar_imbalance_growth_modifier(npc: Person, element: String, current_level: int) -> float:
	if npc == null:
		return 1.0

	if str(npc.bending_type).strip_edges().to_lower() != "avatar":
		return 1.0

	var snapshot: Dictionary = _avatar_balance_snapshot(npc, element)
	var spread: int = int(snapshot.get("spread", 0))
	var focus_is_weakest: bool = bool(snapshot.get("focus_is_weakest", false))
	var focus_is_strongest: bool = bool(snapshot.get("focus_is_strongest", false))
	var modifier: float = 1.0

	if spread >= 35:
		if focus_is_strongest:
			modifier *= 0.42
		elif focus_is_weakest:
			modifier *= 1.45
		else:
			modifier *= 0.82
	elif spread >= 22:
		if focus_is_strongest:
			modifier *= 0.58
		elif focus_is_weakest:
			modifier *= 1.34
		else:
			modifier *= 0.9
	elif spread >= 12:
		if focus_is_strongest:
			modifier *= 0.76
		elif focus_is_weakest:
			modifier *= 1.2

	if int(npc.age) <= 16:
		if focus_is_strongest and current_level >= 35:
			modifier *= 0.82
		elif focus_is_weakest:
			modifier *= 1.1

	return clamp(modifier, 0.3, 1.6)


func _avatar_training_pressure_text(npc: Person, element: String) -> String:
	if npc == null:
		return ""
	if str(npc.bending_type).strip_edges().to_lower() != "avatar":
		return ""

	var snapshot: Dictionary = _avatar_balance_snapshot(npc, element)
	var spread: int = int(snapshot.get("spread", 0))
	var tier: String = str(snapshot.get("imbalance_tier", "none"))
	var weakest: Array = snapshot.get("weakest_elements", [])
	var strongest: Array = snapshot.get("strongest_elements", [])
	var base_text: String = ""

	if tier == "none" or spread <= 0:
		base_text = "Your Avatar training feels balanced for now."
	else:
		var weakest_text: String = ", ".join(weakest)
		var strongest_text: String = ", ".join(strongest)

		if bool(snapshot.get("focus_is_strongest", false)):
			base_text = "Avatar imbalance is pushing back. Your %s bending is already ahead, while %s needs attention." % [
				str(element).strip_edges().to_lower(),
				weakest_text
			]
		elif bool(snapshot.get("focus_is_weakest", false)):
			base_text = "Avatar balance is pulling you toward %s. Training your weakest element helps stabilize the cycle." % weakest_text
		else:
			base_text = "Your Avatar cycle is uneven. Strongest: %s. Weakest: %s." % [
				strongest_text,
				weakest_text
			]

	var imprint: Dictionary = get_previous_avatar_reputation_imprint(npc, {
		"source": "avatar_training_pressure",
		"focus_element": str(element).strip_edges().to_lower()
	})
	var imprint_text: String = str(imprint.get("training_expectation_text", "")).strip_edges()
	if imprint_text != "":
		base_text += "\n\n%s" % imprint_text

	return base_text

func get_avatar_training_pressure(npc: Person, focus_element: String = "") -> Dictionary:
	if npc == null:
		return {}

	var snapshot: Dictionary = _avatar_balance_snapshot(npc, focus_element)
	if not bool(snapshot.get("is_avatar", false)):
		return {}

	snapshot ["text"] = _avatar_training_pressure_text(npc, focus_element)
	return snapshot
func gain_bending_progress(npc: Person, element: String, raw_gain: int, reason:= "") -> Dictionary:
	if gs == null or not gs.is_feature_enabled("bending"):
		return { "success": false, "gain": 0, "text": "Bending is disabled in this reality mode."}
	if npc == null:
		return { "success": false, "gain": 0, "text": "No bender selected."}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return { "success": false, "gain": 0, "text": "Invalid element."}

	ensure_bending_level_state(npc)
	ensure_bending_potential_state(npc)

	var profile: Dictionary = ensure_bending_combat_profile(npc)
	var xp_state: Dictionary = _safe_dictionary(profile.get("level_xp", {}))
	var lifetime_xp_state: Dictionary = _safe_dictionary(profile.get("level_xp_lifetime", {}))
	var current_xp: int = max(0, int(xp_state.get(clean_element, 0)))
	var current_level: int = get_bending_level(npc, clean_element)
	var old_level: int = current_level

	var potential_ceiling_profile: Dictionary = _bending_potential_ceiling_profile(npc, clean_element)
	var raw_potential: int = get_bending_latent_potential(npc, clean_element)
	var effective_potential_cap: int = int(potential_ceiling_profile.get("ceiling_cap", BENDING_LATENT_POTENTIAL_MAX))
	var effective_potential: int = clamp(raw_potential, 0, effective_potential_cap)

	if current_level >= BENDING_LEVEL_MAX:
		return {
			"success": true,
			"gain": 0,
			"xp_gain": 0,
			"level": current_level,
			"old_level": old_level,
			"element": clean_element,
			"current_xp": current_xp,
			"next_level_xp": 0,
			"raw_potential": raw_potential,
			"effective_potential": effective_potential,
			"potential_ceiling_profile": potential_ceiling_profile,
			"element_personality": _bending_element_personality_profile(clean_element),
			"avatar_training_pressure": get_avatar_training_pressure(npc, clean_element),
			"text": "%s has already reached the peak of %s bending." % [npc.first_name, clean_element]
		}

	if raw_potential <= 0 and (str(npc.bending_type).strip_edges().to_lower() == clean_element or str(npc.bending_type).strip_edges().to_lower() == "avatar"):
		raw_potential = seed_birth_bending_potential(npc, clean_element, 1)
		potential_ceiling_profile = _bending_potential_ceiling_profile(npc, clean_element)
		effective_potential_cap = int(potential_ceiling_profile.get("ceiling_cap", BENDING_LATENT_POTENTIAL_MAX))
		effective_potential = clamp(raw_potential, 0, effective_potential_cap)

	var potential_ratio: float = clamp(float(effective_potential) / 100.0, 0.0, 1.0)
	var potential_scale: float = lerpf(0.72, 1.32, potential_ratio)

	if effective_potential > 0 and current_level > effective_potential:
		potential_scale *= 0.5
	elif effective_potential > 0 and current_level >= effective_potential - 5:
		potential_scale *= 0.72

	var element_personality: Dictionary = _bending_element_personality_profile(clean_element)
	var element_growth_scale: float = _bending_element_growth_modifier(npc, clean_element, current_level, reason)
	var avatar_imbalance_scale: float = _avatar_imbalance_growth_modifier(npc, clean_element, current_level)
	var training_context_scale: float = _bending_training_context_growth_modifier(npc, clean_element, reason, current_level)
	var environment_pressure_scale: float = _bending_environment_pressure_growth_modifier(npc, clean_element, reason, current_level)
	var avatar_pressure: Dictionary = get_avatar_training_pressure(npc, clean_element)

	var avatar_focus_is_strongest: bool = false
	if not avatar_pressure.is_empty():
		avatar_focus_is_strongest = bool(avatar_pressure.get("focus_is_strongest", false)) and int(avatar_pressure.get("spread", 0)) >= 22

	var ceiling_is_pressing: bool = effective_potential > 0 and current_level >= effective_potential and effective_potential < BENDING_LATENT_POTENTIAL_MAX

	var progression_policy: Dictionary = _bending_progression_policy()
	var gain_policy: Dictionary = _safe_dictionary(progression_policy.get("xp_gain", {}))
	var clean_reason: String = str(reason).strip_edges().to_lower()
	var base_xp_per_raw: int = max(1, int(gain_policy.get("base_xp_per_raw_progress", 24)))
	var xp_multiplier: float = 1.0

	if clean_reason.find("tournament") >= 0 or clean_reason.find("championship") >= 0:
		xp_multiplier *= float(gain_policy.get("tournament_multiplier", 1.55))
	if clean_reason.find("ko") >= 0 or clean_reason.find("knockout") >= 0:
		xp_multiplier *= float(gain_policy.get("ko_multiplier", 1.18))
	if clean_reason.find("death") >= 0 or clean_reason.find("fatal") >= 0:
		xp_multiplier *= float(gain_policy.get("death_multiplier", 1.45))
	if clean_reason.find("stronger") >= 0 or clean_reason.find("upset") >= 0:
		xp_multiplier *= float(gain_policy.get("upset_multiplier", 1.35))
	if clean_reason.find("scenario") >= 0:
		xp_multiplier *= float(gain_policy.get("scenario_engine_multiplier", 0.72))

	var xp_gain: int = int(round(
		float(max(0, raw_gain))
		* float(base_xp_per_raw)
		* xp_multiplier
		* potential_scale
		* element_growth_scale
		* avatar_imbalance_scale
		* training_context_scale
		* environment_pressure_scale
	))

	if raw_gain > 0 and xp_gain <= 0 and not avatar_focus_is_strongest:
		xp_gain = int(gain_policy.get("minimum_training_xp", 8))
	if clean_reason.find("duel") >= 0 and raw_gain > 0:
		xp_gain = max(xp_gain, int(gain_policy.get("minimum_duel_xp", 14)))

	if avatar_focus_is_strongest:
		xp_gain = int(round(float(xp_gain) * 0.35))

	if ceiling_is_pressing:
		xp_gain = int(round(float(xp_gain) * 0.45))

	current_xp += max(0, xp_gain)
	lifetime_xp_state [clean_element] = max(0, int(lifetime_xp_state.get(clean_element, 0)) + max(0, xp_gain))

	var levels_gained: int = 0
	var required_xp: int = _bending_xp_required_for_next_level(current_level)
	var guard: int = 0

	while current_level < BENDING_LEVEL_MAX and current_xp >= required_xp and guard < BENDING_LEVEL_MAX:
		current_xp -= required_xp
		current_level += 1
		levels_gained += 1
		required_xp = _bending_xp_required_for_next_level(current_level)
		guard += 1

	npc.bending_mastery [clean_element] = clamp(current_level, 0, BENDING_LEVEL_MAX)

	xp_state [clean_element] = max(0, current_xp)
	profile ["level_xp"] = xp_state
	profile ["level_xp_lifetime"] = lifetime_xp_state
	profile ["last_xp_report"] = {
		"element": clean_element,
		"raw_gain": int(raw_gain),
		"xp_gain": xp_gain,
		"old_level": old_level,
		"new_level": current_level,
		"levels_gained": levels_gained,
		"current_xp": current_xp,
		"next_level_xp": required_xp,
		"reason": reason,
		"year": int(gs.year) if gs != null else 0
	}
	_commit_bending_combat_profile(npc, profile)

	if npc.bending_type == "none" and current_level > 0:
		npc.bending_type = clean_element
		npc.bending_nation = _nation_for_element(clean_element)

	if gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(npc)

	_check_avatar_state(npc)

	var skill_points_awarded: int = _bending_skill_points_from_level_gain(old_level, current_level, reason)
	var skill_point_report: Dictionary = {}
	if skill_points_awarded > 0:
		skill_point_report = award_bending_skill_points(npc, skill_points_awarded, "bending_level_progression")

	var awakening_events: Array = _process_bending_awakening_moments(npc, clean_element, old_level, current_level)

	var reason_text: String = str(reason).strip_edges()
	var text: String = "%s gained %d %s bending XP." % [npc.first_name, xp_gain, clean_element]
	if levels_gained > 0:
		text = "%s's %s bending improved to level %d." % [npc.first_name, clean_element, current_level]
		if reason_text != "":
			text = "%s's %s bending improved to level %d through %s." % [npc.first_name, clean_element, current_level, reason_text]

	if levels_gained <= 0:
		text += " Progress: %d/%d XP." % [current_xp, required_xp]

	if xp_gain <= 0 and avatar_focus_is_strongest:
		text = "Avatar imbalance resisted the training. %s's %s bending is already too far ahead of the rest of the cycle." % [
			npc.first_name,
			clean_element
		]
	elif xp_gain <= 0 and ceiling_is_pressing:
		text = "%s's %s bending strained against their current potential ceiling." % [
			npc.first_name,
			clean_element
		]

	if not awakening_events.is_empty():
		var newest_moment: Dictionary = awakening_events [awakening_events.size() - 1]
		if gs.player != null and int(npc.id) == int(gs.player.id):
			text = str(newest_moment.get("diary_text", text))
		else:
			text = str(newest_moment.get("world_text", text))

	var pressure_text: String = str(avatar_pressure.get("text", "")).strip_edges()
	if pressure_text != "":
		text += "\n" + pressure_text

	var realm_environment: Dictionary = potential_ceiling_profile.get("realm_environment", {})
	var realm_name: String = str(realm_environment.get("realm_name", "")).strip_edges()
	var environment_pressure: int = int(realm_environment.get("environment_pressure", 0))
	if realm_name != "" and environment_pressure >= 55:
		text += "\n%s's instability is putting pressure on this bending path." % realm_name

	return {
		"success": true,
		"gain": levels_gained,
		"level_gain": levels_gained,
		"xp_gain": xp_gain,
		"level": current_level,
		"old_level": old_level,
		"element": clean_element,
		"current_xp": current_xp,
		"next_level_xp": required_xp,
		"raw_potential": raw_potential,
		"effective_potential": effective_potential,
		"effective_potential_cap": effective_potential_cap,
		"potential_ceiling_profile": potential_ceiling_profile,
		"element_personality": element_personality,
		"element_growth_scale": element_growth_scale,
		"avatar_imbalance_scale": avatar_imbalance_scale,
		"training_context_scale": training_context_scale,
		"environment_pressure_scale": environment_pressure_scale,
		"avatar_training_pressure": avatar_pressure,
		"skill_points_awarded": skill_points_awarded,
		"skill_point_report": skill_point_report,
		"awakening_events": awakening_events,
		"text": text
	}

func _bending_cooldown_key(actor: Person, ability_id: String) -> String:
	if actor == null:
		return ""
	return "%d:%s" % [int(actor.id), str(ability_id)]

func _bending_cooldowns() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var raw: Variant = gs.scenario_state.get("bending_ability_cooldowns", {})
	var data: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	gs.scenario_state ["bending_ability_cooldowns"] = data
	return data

func _ability_is_on_cooldown(actor: Person, ability_id: String) -> bool:
	if actor == null or gs == null:
		return false
	var cooldowns:= _bending_cooldowns()
	var key:= _bending_cooldown_key(actor, ability_id)
	return int(cooldowns.get(key, -999999)) > int(gs.year)

func _set_ability_cooldown(actor: Person, ability: Dictionary) -> void:
	if actor == null or gs == null:
		return
	var cooldowns:= _bending_cooldowns()
	var key:= _bending_cooldown_key(actor, str(ability.get("id", "")))
	var cooldown_years: int = max(0, int(ability.get("cooldown_years", 0)))
	cooldowns [key] = int(gs.year) + cooldown_years
	gs.scenario_state ["bending_ability_cooldowns"] = cooldowns

func get_bending_abilities_for_element(element: String) -> Array:
	_ensure_advanced_bending_abilities_injected()

	var clean_element: String = str(element).strip_edges().to_lower()
	if not BENDING_ABILITIES.has(clean_element):
		return []

	var abilities: Array = (BENDING_ABILITIES.get(clean_element, []) as Array).duplicate(true)
	abilities.sort_custom(func (a, b): return int((a as Dictionary).get("level", 0)) < int((b as Dictionary).get("level", 0)))
	return abilities
func _default_bending_ability_min_age(required_level: int) -> int:
	var clean_level: int = max(0, int(required_level))

	if clean_level >= 90:
		return 16
	if clean_level >= 70:
		return 14
	if clean_level >= 50:
		return 12
	if clean_level >= 30:
		return 8
	if clean_level >= 10:
		return 5
	if clean_level > 0:
		return 3

	return 0


func _bending_ability_goal_keys(ability: Dictionary) -> Array:
	var out: Array = []

	for field_name in ["required_goal", "goal_requirement", "required_story_flag", "required_flag"]:
		var key: String = str(ability.get(field_name, "")).strip_edges()
		if key != "" and not out.has(key):
			out.append(key)

	for field_name in ["required_goals", "goal_requirements", "required_story_flags", "required_flags"]:
		var raw_keys: Variant = ability.get(field_name, [])
		if typeof(raw_keys) != TYPE_ARRAY:
			continue

		for raw_key in raw_keys:
			var key: String = str(raw_key).strip_edges()
			if key != "" and not out.has(key):
				out.append(key)

	return out


func _actor_has_bending_unlock_flag(actor: Person, flag_key: String) -> bool:
	if actor == null:
		return false

	var clean_key: String = str(flag_key).strip_edges()
	if clean_key == "":
		return true

	for property_name in ["bending_goal_flags", "completed_bending_goals", "bending_story_flags", "story_flags", "quest_flags", "unlock_flags"]:
		var raw_actor_flags: Variant = actor.get(property_name)
		if typeof(raw_actor_flags) == TYPE_DICTIONARY and bool(raw_actor_flags.get(clean_key, false)):
			return true
		if typeof(raw_actor_flags) == TYPE_ARRAY and raw_actor_flags.has(clean_key):
			return true

	if typeof(actor.traits) == TYPE_ARRAY and actor.traits.has(clean_key):
		return true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for bucket_name in ["bending_goal_flags", "bending_story_flags", "bending_unlock_flags", "quest_flags", "story_flags"]:
			var raw_bucket: Variant = gs.scenario_state.get(bucket_name, {})
			if typeof(raw_bucket) == TYPE_DICTIONARY:
				if bool(raw_bucket.get(clean_key, false)):
					return true

				var actor_bucket: Variant = raw_bucket.get(str(actor.id), raw_bucket.get(int(actor.id), {}))
				if typeof(actor_bucket) == TYPE_DICTIONARY and bool(actor_bucket.get(clean_key, false)):
					return true
				if typeof(actor_bucket) == TYPE_ARRAY and actor_bucket.has(clean_key):
					return true

			if typeof(raw_bucket) == TYPE_ARRAY and raw_bucket.has(clean_key):
				return true

	return false


func _bending_ability_goals_completed(actor: Person, goal_keys: Array) -> bool:
	if goal_keys.is_empty():
		return true

	for raw_key in goal_keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		if not _actor_has_bending_unlock_flag(actor, key):
			return false

	return true


func _resolve_bending_ability_unlock(actor: Person, ability: Dictionary, element: String, current_level: int) -> Dictionary:
	var required_level: int = _bending_ability_required_level(ability)
	var unlock_kind: String = str(ability.get("unlock_kind", "")).strip_edges().to_lower()
	var goal_keys: Array = _bending_ability_goal_keys(ability)

	var goal_only: bool = unlock_kind in ["goal", "story_goal", "quest", "quest_only", "goal_only"]
	var uses_level_gate: bool = not bool(ability.get("ignore_level_gate", false)) and not goal_only
	var uses_age_gate: bool = not bool(ability.get("ignore_age_gate", false)) and not goal_only

	var min_age: int = 0
	if ability.has("min_age"):
		min_age = int(ability.get("min_age", 0))
	elif ability.has("age_requirement"):
		min_age = int(ability.get("age_requirement", 0))
	elif uses_age_gate:
		min_age = _default_bending_ability_min_age(required_level)

	var max_age: int = int(ability.get("max_age", -1))
	var age_unlocked: bool = true
	if uses_age_gate and min_age > 0 and int(actor.age) < min_age:
		age_unlocked = false
	if uses_age_gate and max_age > 0 and int(actor.age) > max_age:
		age_unlocked = false

	var level_unlocked: bool = true
	if uses_level_gate and current_level < required_level:
		level_unlocked = false

	var goal_unlocked: bool = true
	if goal_only and goal_keys.is_empty():
		goal_unlocked = false
	elif not goal_keys.is_empty():
		goal_unlocked = _bending_ability_goals_completed(actor, goal_keys)

	var lock_parts: Array = []

	if uses_age_gate and min_age > 0 and int(actor.age) < min_age:
		lock_parts.append("Age %d+" % min_age)
	if uses_age_gate and max_age > 0 and int(actor.age) > max_age:
		lock_parts.append("Before age %d" % max_age)
	if uses_level_gate and current_level < required_level:
		lock_parts.append("%s Level %d (%d/100)" % [
			str(element).capitalize(),
			required_level,
			current_level
		])
	if not goal_unlocked:
		if goal_keys.is_empty():
			lock_parts.append("Complete the required story goal")
		else:
			lock_parts.append("Goal: %s" % ", ".join(goal_keys))

	var unlocked: bool = lock_parts.is_empty()
	var lock_text: String = "Ready" if unlocked else " + ".join(lock_parts)
	var upgrade_report: Dictionary = _resolve_bending_ability_upgrade(actor, ability, element)

	return {
		"required_level": required_level,
		"min_age": min_age,
		"max_age": max_age,
		"age_requirement": min_age,
		"uses_age_gate": uses_age_gate,
		"uses_level_gate": uses_level_gate,
		"age_unlocked": age_unlocked,
		"level_unlocked": level_unlocked,
		"goal_unlocked": goal_unlocked,
		"goal_keys": goal_keys,
		"unlocked": unlocked,
		"lock_text": lock_text,
		"unlock_path": lock_text,
		"upgrade_level": int(upgrade_report.get("upgrade_level", 0)),
		"max_upgrade_level": int(upgrade_report.get("max_upgrade_level", 0)),
		"next_upgrade_level": int(upgrade_report.get("next_upgrade_level", 0)),
		"can_upgrade": bool(upgrade_report.get("can_upgrade", false)),
		"upgrade_cost": int(upgrade_report.get("upgrade_cost", 0)),
		"upgrade_requirements": _safe_dictionary(upgrade_report.get("upgrade_requirements", {})),
		"upgrade_requirement_text": str(upgrade_report.get("upgrade_requirement_text", "")),
		"category_bundle": _safe_dictionary(upgrade_report.get("category_bundle", {})),
		"upgrade_missing": _safe_array(upgrade_report.get("upgrade_missing", [])),
		"upgrade_level_gate": int(upgrade_report.get("upgrade_level_gate", required_level)),
		"upgrade_effectiveness_multiplier": float(upgrade_report.get("upgrade_effectiveness_multiplier", 1.0)),
		"neutralize_rating": int(upgrade_report.get("neutralize_rating", 0)),
		"upgrade_text": str(upgrade_report.get("upgrade_text", ""))
	}
func _commit_bending_world_state(
	state: Dictionary
) -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var previous_raw: Variant = (
		gs.scenario_state.get(
			"bending_world_championship",
			{}
		)
	)
	var previous: Dictionary = (
		previous_raw as Dictionary
		if typeof(previous_raw) == TYPE_DICTIONARY
		else {}
	)
	var previous_revision: int = int(
		previous.get(
			"projection_revision",
			0
		)
	)

	state ["projection_revision"] = (
		previous_revision + 1
	)
	state ["projection_revision_at_ms"] = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [
		"bending_world_championship"
	] = state
func _bending_world_state() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw_state: Variant = gs.scenario_state.get("bending_world_championship", {})
	var state: Dictionary = raw_state if typeof(raw_state) == TYPE_DICTIONARY else {}

	if state.is_empty():
		state = {
			"schema": "eralife.bending_world_championship_state",
			"version": 7,
			"created_year": int(gs.year),
			"bootstrap_seeded": false,
			"bootstrap_seeded_year": -1,
			"tournaments": {},
			"rankings": {},
			"dynasty_records": {},
			"bloodline_rivalries": {},
			"previous_avatars": [],
			"previous_avatar_reputation_imprints": {},
			"style_identity_index": {},
			"media_reactions": [],
			"spectator_feed": [],
			"player_entry_state": {},
			"annual_player_entry_signals": {},
			"tournament_history": [],
			"tournament_world_feed_index": {},
			"tournament_recordboard": {
				"overall": [],
				"tournament": [],
				"non_tournament": [],
				"championships": []
			},
			"tournament_of_champions_bids": {},
			"last_report": {}
		}
	else:
		state ["schema"] = str(state.get("schema", "eralife.bending_world_championship_state"))
		state ["version"] = max(8, int(state.get("version", 1)))

	if not state.has("created_year"):
		state ["created_year"] = int(gs.year)
	if not state.has("bootstrap_seeded"):
		state ["bootstrap_seeded"] = false
	if not state.has("bootstrap_seeded_year"):
		state ["bootstrap_seeded_year"] = -1
	if not state.has("tournaments") or typeof(state.get("tournaments")) != TYPE_DICTIONARY:
		state ["tournaments"] = {}
	if not state.has("rankings") or typeof(state.get("rankings")) != TYPE_DICTIONARY:
		state ["rankings"] = {}
	if not state.has("dynasty_records") or typeof(state.get("dynasty_records")) != TYPE_DICTIONARY:
		state ["dynasty_records"] = {}
	if not state.has("bloodline_rivalries") or typeof(state.get("bloodline_rivalries")) != TYPE_DICTIONARY:
		state ["bloodline_rivalries"] = {}
	if not state.has("previous_avatars") or typeof(state.get("previous_avatars")) != TYPE_ARRAY:
		state ["previous_avatars"] = []
	if not state.has("previous_avatar_reputation_imprints") or typeof(state.get("previous_avatar_reputation_imprints")) != TYPE_DICTIONARY:
		state ["previous_avatar_reputation_imprints"] = {}
	if not state.has("style_identity_index") or typeof(state.get("style_identity_index")) != TYPE_DICTIONARY:
		state ["style_identity_index"] = {}
	if not state.has("media_reactions") or typeof(state.get("media_reactions")) != TYPE_ARRAY:
		state ["media_reactions"] = []
	if not state.has("spectator_feed") or typeof(state.get("spectator_feed")) != TYPE_ARRAY:
		state ["spectator_feed"] = []
	if not state.has("player_entry_state") or typeof(state.get("player_entry_state")) != TYPE_DICTIONARY:
		state ["player_entry_state"] = {}
	if not state.has("annual_player_entry_signals") or typeof(state.get("annual_player_entry_signals")) != TYPE_DICTIONARY:
		state ["annual_player_entry_signals"] = {}
	if not state.has("tournament_history") or typeof(state.get("tournament_history")) != TYPE_ARRAY:
		state ["tournament_history"] = []
	if not state.has("tournament_world_feed_index") or typeof(state.get("tournament_world_feed_index")) != TYPE_DICTIONARY:
		state ["tournament_world_feed_index"] = {}
	if not state.has("tournament_recordboard") or typeof(state.get("tournament_recordboard")) != TYPE_DICTIONARY:
		state ["tournament_recordboard"] = {
			"overall": [],
			"tournament": [],
			"non_tournament": [],
			"championships": []
		}
	if not state.has("tournament_of_champions_bids") or typeof(state.get("tournament_of_champions_bids")) != TYPE_DICTIONARY:
		state ["tournament_of_champions_bids"] = {}
	if not state.has("last_report") or typeof(state.get("last_report")) != TYPE_DICTIONARY:
		state ["last_report"] = {}

	gs.scenario_state ["bending_world_championship"] = state
	return state
func _bending_tournament_runtime() -> Object:
	if gs == null:
		return null
	if "bending_tournament_engine" in gs and gs.bending_tournament_engine != null:
		return gs.bending_tournament_engine
	return null


func _bending_player_tournament_entry_gate(actor: Person, division: String, options: Dictionary = {}) -> Dictionary:
	var runtime: Object = _bending_tournament_runtime()
	if runtime != null and runtime.has_method("player_entry_gate"):
		return runtime.call("player_entry_gate", actor, division, options)

	return {
		"allowed": true,
		"reason": "no_tournament_runtime",
		"entry_button_label": "Enter Bending World Championship as %s" % str(actor.first_name) if actor != null else "Enter Bending World Championship",
		"entry_button_disabled": false
	}


func _bending_mark_player_tournament_started(actor: Person, tournament: Dictionary, options: Dictionary = {}) -> Dictionary:
	var runtime: Object = _bending_tournament_runtime()
	if runtime != null and runtime.has_method("mark_player_tournament_started"):
		return runtime.call("mark_player_tournament_started", actor, tournament, options)

	return {
		"success": false,
		"reason": "no_tournament_runtime"
	}


func _bending_decorate_tournament_hub_payload(actor: Person, payload: Dictionary) -> Dictionary:
	var runtime: Object = _bending_tournament_runtime()
	if runtime != null and runtime.has_method("decorate_hub_payload"):
		return runtime.call("decorate_hub_payload", actor, payload)

	return payload.duplicate(true)
func _ensure_bending_duel_records(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var records: Dictionary = actor.bending_duel_records if typeof(actor.bending_duel_records) == TYPE_DICTIONARY else {}

	if records.is_empty():
		records = _blank_bending_duel_records()

	records = _normalize_bending_duel_records(records)

	if not bool(records.get("established_history_seeded", false)):
		records = _seed_established_bending_records_for_actor(actor, records)
		records = _normalize_bending_duel_records(records)

	actor.bending_duel_records = records
	return records

func record_bending_duel_result(winner: Person, loser: Person, context: Dictionary = {}) -> Dictionary:
	if winner == null or loser == null:
		return {
			"success": false,
			"reason": "Winner or loser missing."
		}

	var is_tournament: bool = bool(context.get("tournament", false))
	var bucket_key: String = "tournament" if is_tournament else "non_tournament"
	var ko: bool = bool(context.get("ko", false))
	var death: bool = bool(context.get("death", false))

	var winner_records: Dictionary = _ensure_bending_duel_records(winner)
	var loser_records: Dictionary = _ensure_bending_duel_records(loser)

	var winner_bucket: Dictionary = winner_records.get(bucket_key, {})
	var winner_overall: Dictionary = winner_records.get("overall", {})
	var loser_bucket: Dictionary = loser_records.get(bucket_key, {})
	var loser_overall: Dictionary = loser_records.get("overall", {})

	winner_bucket ["wins"] = int(winner_bucket.get("wins", 0)) + 1
	winner_overall ["wins"] = int(winner_overall.get("wins", 0)) + 1
	loser_bucket ["losses"] = int(loser_bucket.get("losses", 0)) + 1
	loser_overall ["losses"] = int(loser_overall.get("losses", 0)) + 1

	if ko:
		winner_bucket ["kos"] = int(winner_bucket.get("kos", 0)) + 1
		winner_overall ["kos"] = int(winner_overall.get("kos", 0)) + 1

	if death:
		winner_bucket ["deaths"] = int(winner_bucket.get("deaths", 0)) + 1
		winner_overall ["deaths"] = int(winner_overall.get("deaths", 0)) + 1

	winner_records [bucket_key] = winner_bucket
	winner_records ["overall"] = winner_overall
	winner_records ["last_updated_year"] = int(gs.year) if gs != null else 0

	loser_records [bucket_key] = loser_bucket
	loser_records ["overall"] = loser_overall
	loser_records ["last_updated_year"] = int(gs.year) if gs != null else 0

	winner.bending_duel_records = winner_records
	loser.bending_duel_records = loser_records

	var archive_report: Dictionary = _record_bending_match_archive_event(winner, loser, context, winner_records, loser_records)

	var reward_report: Dictionary = _grant_bending_duel_progress_rewards(winner, loser, context, is_tournament, ko, death)

	var death_aftercare_report: Dictionary = {}
	if death:
		death_aftercare_report = _record_bending_duel_death_aftermath(winner, loser, context)

	var fame_gain: int = 2 if is_tournament else 1
	if ko:
		fame_gain += 1
	if death:
		fame_gain += 3

	winner.fame = clamp(int(winner.fame) + fame_gain, 0, 100)
	loser.fame = clamp(int(loser.fame) - 1, 0, 100)

	modify_respect(winner, 5 + fame_gain, "bending_duel_win", "bending")
	modify_respect(loser, -2, "bending_duel_loss", "bending")

	var dojo_legacy_report: Dictionary = {}
	if is_tournament and gs != null and "bending_dojo_engine" in gs and gs.bending_dojo_engine != null and gs.bending_dojo_engine.has_method("apply_dojo_tournament_legacy_from_duel"):
		dojo_legacy_report = gs.bending_dojo_engine.apply_dojo_tournament_legacy_from_duel(winner, loser, context)

	if gs != null and "bending_tournament_engine" in gs and gs.bending_tournament_engine != null:
		if gs.bending_tournament_engine.has_method("record_duel_result"):
			gs.bending_tournament_engine.record_duel_result(winner, loser, context)

	if is_tournament and str(context.get("tournament_id", "")) != "":
		_commit_bending_tournament_duel_result(winner, loser, context)

	return {
		"schema": "eralife.bending_duel_record_report",
		"success": true,
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"tournament": is_tournament,
		"bucket_key": bucket_key,
		"ko": ko,
		"death": death,
		"fame_gain": fame_gain,
		"archive_report": archive_report.duplicate(true),
		"reward_report": reward_report.duplicate(true),
		"death_aftercare_report": death_aftercare_report.duplicate(true),
		"dojo_legacy_report": dojo_legacy_report.duplicate(true),
		"winner_records": winner_records.duplicate(true),
		"loser_records": loser_records.duplicate(true)
	}
func _record_bending_duel_death_aftermath(winner: Person, loser: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null or winner == null or loser == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var death_ledger: Array = _safe_array(state.get("bending_duel_death_ledger", []))
	var revenge_queue: Array = _safe_array(state.get("bending_revenge_duel_queue", []))
	var tournament_bias: Dictionary = _safe_dictionary(state.get("bending_revenge_tournament_bias", {}))

	var revenge_candidates: Array = _bending_revenge_candidates_for_death(winner, loser, context)
	var candidate_ids: Array = []

	for raw_candidate in revenge_candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var candidate_id: int = int(candidate.get("person_id", -1))
		if candidate_id <= 0:
			continue

		candidate_ids.append(candidate_id)
		tournament_bias [str(candidate_id)] = {
			"schema": "eralife.bending_revenge_tournament_bias",
			"version": 1,
			"person_id": candidate_id,
			"target_id": int(winner.id),
			"dead_person_id": int(loser.id),
			"heat": int(candidate.get("revenge_heat", 20)),
			"start_year": int(gs.year) + 1,
			"expires_year": int(gs.year) + 4,
			"source": "bending_duel_death_aftercare"
		}

		revenge_queue.append({
			"schema": "eralife.bending_revenge_duel_hook",
			"version": 1,
			"revenge_id": "bending_revenge_%d_%d_%d" % [int(loser.id), int(winner.id), candidate_id],
			"challenger_id": candidate_id,
			"challenger_name": str(candidate.get("name", "")),
			"target_id": int(winner.id),
			"target_name": _bending_person_label(winner),
			"dead_person_id": int(loser.id),
			"dead_person_name": _bending_person_label(loser),
			"revenge_heat": int(candidate.get("revenge_heat", 20)),
			"eligible_from_year": int(gs.year),
			"expires_year": int(gs.year) + 5,
			"status": "queued"
		})

	while death_ledger.size() > 160:
		death_ledger.pop_front()
	while revenge_queue.size() > 160:
		revenge_queue.pop_front()

	var row: Dictionary = {
		"schema": "eralife.bending_duel_death_aftercare",
		"version": 1,
		"killer_id": int(winner.id),
		"killer_name": _bending_person_label(winner),
		"dead_person_id": int(loser.id),
		"dead_person_name": _bending_person_label(loser),
		"finish_move": str(context.get("finish_move", "")),
		"tournament": bool(context.get("tournament", false)),
		"tournament_id": str(context.get("tournament_id", "")),
		"tournament_match_id": str(context.get("tournament_match_id", "")),
		"moral_context": _bending_duel_death_era_context(),
		"revenge_candidate_ids": candidate_ids.duplicate(true),
		"revenge_candidate_count": candidate_ids.size(),
		"year": int(gs.year),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	death_ledger.append(row)
	state ["bending_duel_death_ledger"] = death_ledger
	state ["bending_revenge_duel_queue"] = revenge_queue
	state ["bending_revenge_tournament_bias"] = tournament_bias
	_commit_bending_world_state(state)

	return row.duplicate(true)


func _bending_revenge_candidates_for_death(killer: Person, dead_person: Person, _context: Dictionary = {}) -> Array:
	var out: Array = []
	if gs == null or killer == null or dead_person == null:
		return out

	var dead_last_name: String = str(dead_person.last_name).strip_edges().to_lower()
	var direct_family_ids: Dictionary = {}

	for raw_parent_id in dead_person.parents:
		direct_family_ids [int(raw_parent_id)] = true
	for raw_child_id in dead_person.children:
		direct_family_ids [int(raw_child_id)] = true

	for raw_npc in gs.npcs:
		if raw_npc == null:
			continue

		var candidate: Person = raw_npc
		if not bool(candidate.alive):
			continue
		if int(candidate.id) == int(killer.id) or int(candidate.id) == int(dead_person.id):
			continue
		if str(candidate.bending_type).strip_edges().to_lower() == "none":
			continue

		var same_family_name: bool = dead_last_name != "" and str(candidate.last_name).strip_edges().to_lower() == dead_last_name
		var direct_family: bool = direct_family_ids.has(int(candidate.id))
		if not same_family_name and not direct_family:
			continue

		var primary_level: int = int(get_primary_bending_level(candidate))
		var revenge_heat: int = 16 + clamp(int(floor(float(primary_level) / 4.0)), 0, 24)
		if direct_family:
			revenge_heat += 18
		if int(candidate.fame) >= 60:
			revenge_heat += 8
		if int(candidate.ambition) >= 70:
			revenge_heat += 7

		out.append({
			"person_id": int(candidate.id),
			"name": _bending_person_label(candidate),
			"level": primary_level,
			"fame": int(candidate.fame),
			"direct_family": direct_family,
			"same_family_name": same_family_name,
			"revenge_heat": clamp(revenge_heat, 1, 100)
		})

	out.sort_custom(func (a, b):
		if int(a.get("revenge_heat", 0)) != int(b.get("revenge_heat", 0)):
			return int(a.get("revenge_heat", 0)) > int(b.get("revenge_heat", 0))
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	while out.size() > 8:
		out.pop_back()

	return out

func _bending_duel_death_era_context() -> Dictionary:
	var era_key: String = "modern"
	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_era_key_from_year"):
		era_key = str(gs.era_engine.call("get_era_key_from_year", int(gs.year))).strip_edges().to_lower()
	elif gs != null and gs.era != null:
		era_key = str(gs.era.get("key") if typeof(gs.era) == TYPE_DICTIONARY else gs.era.name).strip_edges().to_lower()

	var judgment: String = "condemned"
	var revenge_multiplier: float = 1.0

	match era_key:
		"ancient":
			judgment = "ritualized_but_remembered"
			revenge_multiplier = 1.35
		"medieval":
			judgment = "honor_disputed"
			revenge_multiplier = 1.25
		"industrial":
			judgment = "public_scandal"
			revenge_multiplier = 1.05
		"future":
			judgment = "institutionally_condemned"
			revenge_multiplier = 0.9
		_:
			judgment = "morally_severe"
			revenge_multiplier = 1.0

	return {
		"era_key": era_key,
		"judgment": judgment,
		"revenge_multiplier": revenge_multiplier
	}


func adjust_bending_revenge_heat_for_funeral_choice(actor: Person, dead_person_id: int, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var revenge_queue: Array = _safe_array(state.get("bending_revenge_duel_queue", []))
	var attended: bool = bool(context.get("attended", false))
	var resentment_delta: int = int(context.get("resentment_delta", -2 if attended else 3))
	var updates: int = 0

	for i in range(revenge_queue.size()):
		if typeof(revenge_queue [i]) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = revenge_queue [i]
		if int(row.get("dead_person_id", -1)) != int(dead_person_id):
			continue
		if int(row.get("target_id", -1)) != int(actor.id):
			continue

		row ["revenge_heat"] = clamp(int(row.get("revenge_heat", 0)) + resentment_delta, 0, 100)
		row ["funeral_attended_by_target"] = attended
		row ["last_funeral_choice_year"] = int(gs.year)
		revenge_queue [i] = row
		updates += 1

	state ["bending_revenge_duel_queue"] = revenge_queue
	_commit_bending_world_state(state)

	return {
		"success": true,
		"updates": updates,
		"attended": attended,
		"dead_person_id": int(dead_person_id)
	}
func get_bending_world_championship_division(actor: Person, options: Dictionary = {}) -> String:
	if actor == null:
		return "ineligible"

	var age_value: int = int(actor.age)
	if age_value < 10:
		return "ineligible"
	if age_value < 18:
		return "youth"
	if age_value <= 50:
		return "adult"

	var gender_text: String = str(actor.gender).strip_edges().to_lower()
	var crossover: bool = bool(options.get("cross_league_history_run", false))

	if crossover:
		return "elder_open"
	if gender_text.begins_with("f"):
		return "elder_female"

	return "elder_male"


func _bending_competitive_score(actor: Person, division: String = "", include_upset_noise: bool = true) -> float:
	if actor == null:
		return -99999.0

	ensure_bending_level_state(actor)
	ensure_bending_combat_profile(actor)

	var clean_division: String = str(division).strip_edges().to_lower()
	var best_level: float = float(get_primary_bending_level(actor))
	var respect_value: float = float(get_respect(actor, "bending"))
	var fame_value: float = float(actor.fame)
	var health_value: float = min(float(actor.health), 125.0)
	var mental_value: float = float(actor.mental_health)
	var combat_profile: Dictionary = actor.bending_combat_profile if typeof(actor.bending_combat_profile) == TYPE_DICTIONARY else {}
	var read_value: float = float(combat_profile.get("read", combat_profile.get("battle_iq", 50)))
	var defense_value: float = float(combat_profile.get("defense", combat_profile.get("guard", 50)))
	var offense_value: float = float(combat_profile.get("offense", combat_profile.get("power", 50)))
	var skill_weight: float = 0.82
	var upset_noise: float = 10.0

	match clean_division:
		"youth", "child", "children", "top_child", "child_top":
			skill_weight = 0.62
			upset_noise = 24.0
		"adult", "adults", "top_adult", "adult_top", "adult_all":
			skill_weight = 0.88
			upset_noise = 8.0
		"elder_male", "elder_female", "elder_open":
			skill_weight = 0.78
			upset_noise = 14.0
		"masters":
			skill_weight = 0.94
			upset_noise = 5.0

	var score: float = (
		best_level * skill_weight
		+ read_value * 0.16
		+ defense_value * 0.1
		+ offense_value * 0.1
		+ respect_value * 0.12
		+ fame_value * 0.06
		+ health_value * 0.05
		+ mental_value * 0.04
	)

	if include_upset_noise:
		score += randf_range(- upset_noise, upset_noise)

	return score
func _sort_bending_cached_score_rows_desc(a, b) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return false

	var row_a: Dictionary = a
	var row_b: Dictionary = b

	var score_a: float = float(row_a.get("score", -99999.0))
	var score_b: float = float(row_b.get("score", -99999.0))
	if abs(score_a - score_b) > 0.0001:
		return score_a > score_b

	var level_a: int = int(row_a.get("level", 0))
	var level_b: int = int(row_b.get("level", 0))
	if level_a != level_b:
		return level_a > level_b

	var fame_a: int = int(row_a.get("fame", 0))
	var fame_b: int = int(row_b.get("fame", 0))
	if fame_a != fame_b:
		return fame_a > fame_b

	var age_a: int = int(row_a.get("age", 0))
	var age_b: int = int(row_b.get("age", 0))
	if age_a != age_b:
		return age_a > age_b

	return int(row_a.get("person_id", 0)) < int(row_b.get("person_id", 0))
func _eligible_benders_for_division(division: String, options: Dictionary = {}) -> Array:
	var out: Array = []
	if gs == null:
		return out

	var clean_division: String = str(division).strip_edges().to_lower()
	var excluded_ids: Dictionary = {}

	var excluded_raw: Variant = options.get("exclude_actor_ids", [])
	if typeof(excluded_raw) == TYPE_ARRAY:
		for raw_id in excluded_raw:
			excluded_ids [int(raw_id)] = true

	var exclude_actor_id: int = int(options.get("exclude_actor_id", -1))
	if exclude_actor_id > 0:
		excluded_ids [exclude_actor_id] = true

	var scored_rows: Array = []

	for raw_actor in _bending_candidate_pool():
		if raw_actor == null:
			continue

		var actor: Person = raw_actor
		if excluded_ids.has(int(actor.id)):
			continue
		if not bool(actor.alive):
			continue
		if str(actor.bending_type).strip_edges().to_lower() == "none":
			continue

		if clean_division == "agni_kai":
			if not _is_agni_kai_eligible(actor):
				continue
		else:
			var actor_division: String = get_bending_world_championship_division(actor, options)
			if actor_division != clean_division:
				continue

		if not bool(options.get("force_all_eligible", false)):
			if not _bending_actor_should_enter_world_stage(actor, clean_division, options):
				continue

		scored_rows.append({
			"person_id": int(actor.id),
			"actor": actor,
			"age": int(actor.age),
			"level": int(get_primary_bending_level(actor)),
			"fame": int(actor.fame),
			"score": _bending_competitive_score(actor, clean_division, false)
		})

	scored_rows.sort_custom(_sort_bending_cached_score_rows_desc)

	for raw_row in scored_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var ranked_actor: Person = row.get("actor", null)
		if ranked_actor != null:
			out.append(ranked_actor)

	return out
func _bending_actor_should_enter_world_stage(actor: Person, division: String, options: Dictionary = {}) -> bool:
	if actor == null:
		return false

	if bool(options.get("force_include_actor", false)):
		return true

	var clean_division: String = str(division).strip_edges().to_lower()
	var policy: Dictionary = _bending_world_policy()
	var rates_raw: Variant = policy.get("participation_rate_by_division", {})
	var rates: Dictionary = rates_raw if typeof(rates_raw) == TYPE_DICTIONARY else {}
	var base_rate: int = int(rates.get(clean_division, 45))

	var score: float = _bending_competitive_score(actor, clean_division)
	if score >= 90.0:
		base_rate += 18
	elif score >= 75.0:
		base_rate += 10
	elif score < 35.0:
		base_rate -= 12

	if int(actor.fame) >= 40:
		base_rate += 8

	var bloodline_heat: int = _bending_bloodline_heat(actor)
	base_rate += clamp(bloodline_heat, 0, 12)
	base_rate += _bending_revenge_tournament_entry_bonus(actor, clean_division)

	base_rate = clamp(base_rate, 5, 96)

	var year_value: int = int(gs.year) if gs != null else 0
	var salt: String = "%d:%s:%d:%s" % [
		int(actor.id),
		clean_division,
		year_value,
		str(options.get("source", "world_stage"))
	]
	var roll: int = abs(int(salt.hash())) % 100

	return roll < base_rate
func _bending_revenge_tournament_entry_bonus(actor: Person, _division: String = "") -> int:
	if gs == null or actor == null:
		return 0

	var state: Dictionary = _bending_world_state()
	var bias: Dictionary = _safe_dictionary(state.get("bending_revenge_tournament_bias", {}))
	var key: String = str(int(actor.id))
	if not bias.has(key):
		return 0

	var row: Dictionary = _safe_dictionary(bias.get(key, {}))
	var year_value: int = int(gs.year)
	if year_value < int(row.get("start_year", year_value)):
		return 0
	if year_value > int(row.get("expires_year", year_value)):
		return 0

	return clamp(int(floor(float(int(row.get("heat", 0))) / 4.0)), 0, 28)

func _bending_bloodline_heat(actor: Person) -> int:
	if actor == null:
		return 0

	var bloodline_key: String = str(actor.last_name).strip_edges()
	if bloodline_key == "":
		return 0

	var state: Dictionary = _bending_world_state()
	var dynasties: Dictionary = state.get("dynasty_records", {})
	var row: Dictionary = dynasties.get(bloodline_key, {})
	if row.is_empty():
		return 0

	return int(row.get("rivalry_heat", 0)) + int(row.get("tournament_wins", 0))

func get_bending_rankings(division: String = "adult", limit: int = 100, options: Dictionary = {}) -> Array:
	var clean_division: String = str(division).strip_edges().to_lower()
	var clean_element: String = str(options.get("element", "")).strip_edges().to_lower()
	var min_age: int = int(options.get("min_age", -1))
	var max_age: int = int(options.get("max_age", -1))
	var ranked_rows: Array = []

	for raw_actor in _bending_candidate_pool():
		if raw_actor == null:
			continue

		var actor: Person = raw_actor
		if not bool(actor.alive):
			continue
		if str(actor.bending_type).strip_edges().to_lower() == "none":
			continue

		var age_value: int = int(actor.age)
		if min_age >= 0 and age_value < min_age:
			continue
		if max_age >= 0 and age_value > max_age:
			continue

		var primary_element: String = _bending_person_primary_element(actor)
		if clean_element != "" and primary_element != clean_element:
			continue

		if clean_division in ["child", "children", "top_child", "child_top"]:
			if age_value >= 18:
				continue
		elif clean_division in ["adult", "adults", "top_adult", "adult_top", "adult_all"]:
			if age_value < 18:
				continue
		elif clean_division != "all":
			var actor_division: String = get_bending_world_championship_division(actor, options)
			if actor_division != clean_division:
				continue

		var stable_score: float = _bending_competitive_score(actor, clean_division, false)
		var level_value: int = int(get_primary_bending_level(actor))

		ranked_rows.append({
			"rank": 0,
			"person_id": int(actor.id),
			"name": _bending_person_label(actor),
			"age": age_value,
			"gender": str(actor.gender),
			"element": primary_element,
			"nation": str(actor.bending_nation),
			"level": level_value,
			"score": stable_score,
			"fame": int(actor.fame),
			"records": _ensure_bending_duel_records(actor).duplicate(true)
		})

	ranked_rows.sort_custom(_sort_bending_cached_score_rows_desc)

	var ranked: Array = []
	var capped: int = min(max(1, int(limit)), ranked_rows.size())

	for i in range(capped):
		var row: Dictionary = ranked_rows [i]
		row ["rank"] = i + 1
		ranked.append(row)

	return ranked
func _bending_candidate_pool() -> Array:
	var candidates: Array = []
	var seen_ids: Dictionary = {}

	if gs == null:
		return candidates

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue

			var npc: Person = raw_npc
			var npc_id: int = int(npc.id)
			if npc_id <= 0:
				continue
			if seen_ids.has(npc_id):
				continue

			seen_ids [npc_id] = true
			candidates.append(npc)

	if gs.player != null:
		var player_id: int = int(gs.player.id)
		if player_id > 0 and not seen_ids.has(player_id):
			seen_ids [player_id] = true
			candidates.append(gs.player)

	return candidates


func _bending_person_primary_element(actor: Person) -> String:
	if actor == null:
		return "none"

	ensure_bending_level_state(actor)

	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type in _base_bending_elements():
		return bending_type

	if bending_type == "avatar":
		return _bending_primary_style_element(actor)

	var best_element: String = "none"
	var best_level: int = -1

	for raw_element in _base_bending_elements():
		var element: String = str(raw_element)
		var level_value: int = int(get_bending_level(actor, element))
		if level_value > best_level:
			best_level = level_value
			best_element = element

	return best_element


func get_bending_world_top_bender_payload(limit_per_board: int = 100) -> Dictionary:
	var adult_by_element: Dictionary = {}

	for raw_element in _base_bending_elements():
		var element: String = str(raw_element)
		adult_by_element [element] = get_bending_rankings("adult_all", limit_per_board, {
			"element": element,
			"min_age": 18
		})

	var child_rankings: Array = get_bending_rankings("child", limit_per_board, {
		"max_age": 17
	})

	return {
		"schema": "eralife.bending_world_top_bender_payload",
		"version": 1,
		"adult_by_element": adult_by_element,
		"child_rankings": child_rankings,
		"limit_per_board": max(1, int(limit_per_board)),
		"year": int(gs.year) if gs != null else 0
	}


func _bending_runtime_tournament_division(division: String, year_value: int) -> String:
	var clean_division: String = str(division).strip_edges().to_lower()
	if clean_division != "adult":
		return clean_division

	var policy: Dictionary = _bending_world_policy()
	var cycle: Dictionary = _safe_dictionary(policy.get("tournament_cycle", {}))
	var cycle_length: int = max(1, int(cycle.get("cycle_length", 5)))
	var champions_year: int = clamp(int(cycle.get("champions_year", 5)), 1, cycle_length)
	var cycle_position: int = _bending_tournament_cycle_position(year_value, cycle_length)

	if cycle_position == champions_year:
		return str(cycle.get("champions_division", "masters")).strip_edges().to_lower()

	return clean_division


func _bending_tournament_id_for_division(division: String, year_value: int) -> String:
	var runtime_division: String = _bending_runtime_tournament_division(division, year_value)

	if runtime_division == "masters":
		return "masters_%d" % int(year_value)

	return "%s_%d" % [runtime_division, int(year_value)]

func _bending_world_stage_has_player_controlled_entry(tournament_id: String, tournament: Dictionary, player_actor_id: int = -1) -> bool:
	var clean_id: String = str(tournament_id).strip_edges()
	if clean_id == "":
		return false

	var state: Dictionary = _bending_world_state()
	var signals: Dictionary = _safe_dictionary(state.get("annual_player_entry_signals", {}))
	var entry_state: Dictionary = _safe_dictionary(state.get("player_entry_state", {}))

	if signals.has(clean_id):
		return true

	if entry_state.has(clean_id):
		return true

	if not tournament.is_empty():
		if bool(tournament.get("player_entry_started", false)):
			return true

		if int(tournament.get("player_entry_actor_id", -1)) > 0:
			return true

		if player_actor_id > 0 and _bending_tournament_has_actor_id(tournament, player_actor_id):
			return true

	return false
func _run_bending_world_stage_yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return

	_ensure_bending_world_bootstrap({
		"source": "yearly_world_stage_preflight"
	})

	var payload: Dictionary = _payload if typeof(_payload) == TYPE_DICTIONARY else {}
	var target_year: int = int(payload.get("target_year", payload.get("year", int(gs.year))))
	var source_year: int = int(payload.get("source_year", target_year - 1))

	if source_year >= target_year:
		source_year = target_year - 1

	if source_year <= -999999:
		source_year = int(gs.year)

	var state: Dictionary = _bending_world_state()
	if int(state.get("last_world_stage_tick_year", -999999)) == source_year:
		return

	var player_actor_id: int = int(gs.player.id) if gs.player != null else -1
	var divisions: Array = ["youth", "adult", "elder_male", "elder_female"]
	var reports: Array = []

	for raw_division in divisions:
		var division: String = str(raw_division).strip_edges().to_lower()
		var tournament_id: String = _bending_tournament_id_for_division(division, source_year)
		state = _bending_world_state()
		var tournaments: Dictionary = state.get("tournaments", {})
		var existing_tournament: Dictionary = tournaments.get(tournament_id, {}) if tournaments.has(tournament_id) else {}

		if _bending_world_stage_has_player_controlled_entry(tournament_id, existing_tournament, player_actor_id):
			continue

		var tournament: Dictionary = _ensure_bending_tournament_for_division(division, null, {
			"force_include_actor": false,
			"exclude_actor_id": player_actor_id,
			"tournament_year": source_year,
			"source": "yearly_world_stage_backfill",
			"force_all_eligible": false,
			"faction_fillers_enabled": true,
			"minimum_bracket_size": 8
		})

		if tournament.is_empty():
			continue

		if str(tournament.get("status", "")).strip_edges().to_lower() == "complete":
			continue

		if _bending_tournament_has_actor_id(tournament, player_actor_id):
			continue

		_settle_bending_cpu_tournament(str(tournament.get("id", "")), player_actor_id, {
			"source": "yearly_world_stage_backfill",
			"exclude_actor_id": player_actor_id,
			"historical_year": source_year,
			"simulated": true,
			"minimum_bracket_size": 8
		})

		var settled_tournament: Dictionary = _bending_tournament_reload_by_id(str(tournament.get("id", "")))
		reports.append({
			"division": division,
			"tournament_id": str(tournament.get("id", "")),
			"year": source_year,
			"status": str(settled_tournament.get("status", tournament.get("status", ""))),
			"champion_id": int(settled_tournament.get("champion_id", -1)),
			"champion_name": str(settled_tournament.get("champion_name", ""))
		})

	state = _bending_world_state()
	state ["last_world_stage_tick_year"] = source_year
	state ["last_world_stage_tick_reports"] = reports
	gs.scenario_state ["bending_world_championship"] = state

func _settle_bending_cpu_tournament(tournament_id: String, reserved_actor_id: int = -1, options: Dictionary = {}) -> void:
	if gs == null:
		return

	var clean_tournament_id: String = str(tournament_id).strip_edges()
	if clean_tournament_id == "":
		return

	var guard: int = 0

	while guard < 512:
		guard += 1

		var state: Dictionary = _bending_world_state()
		var tournaments: Dictionary = state.get("tournaments", {})
		if not tournaments.has(clean_tournament_id):
			return

		var tournament: Dictionary = tournaments.get(clean_tournament_id, {})
		if str(tournament.get("status", "")).strip_edges().to_lower() != "active":
			return

		var bracket: Array = tournament.get("bracket", [])
		var pending_match: Dictionary = {}

		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = raw_match
			if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))

			if reserved_actor_id > 0 and (fighter_a_id == reserved_actor_id or fighter_b_id == reserved_actor_id):
				return

			pending_match = match_row
			break

		if pending_match.is_empty():
			return

		var a_id: int = int(pending_match.get("fighter_a_id", -1))
		var b_id: int = int(pending_match.get("fighter_b_id", -1))
		var fighter_a: Person = _find_person_by_id(a_id)
		var fighter_b: Person = _find_person_by_id(b_id)

		if fighter_a == null and fighter_b == null:
			_mark_bending_tournament_match_void(clean_tournament_id, str(pending_match.get("match_id", "")))
			continue

		if fighter_a != null and fighter_b == null:
			_commit_bending_tournament_duel_result(fighter_a, null, {
				"tournament": true,
				"tournament_id": clean_tournament_id,
				"tournament_match_id": str(pending_match.get("match_id", "")),
				"simulated": true,
				"bye": true,
				"source": str(options.get("source", "cpu_tournament"))
			})
			continue

		if fighter_a == null and fighter_b != null:
			_commit_bending_tournament_duel_result(fighter_b, null, {
				"tournament": true,
				"tournament_id": clean_tournament_id,
				"tournament_match_id": str(pending_match.get("match_id", "")),
				"simulated": true,
				"bye": true,
				"source": str(options.get("source", "cpu_tournament"))
			})
			continue

		var winner: Person = _pick_bending_tournament_winner(fighter_a, fighter_b, str(tournament.get("division", "")))
		var loser: Person = fighter_b if winner == fighter_a else fighter_a

		record_bending_duel_result(winner, loser, {
			"tournament": true,
			"tournament_id": clean_tournament_id,
			"tournament_match_id": str(pending_match.get("match_id", "")),
			"simulated": true,
			"source": str(options.get("source", "cpu_tournament"))
		})


func _pick_bending_tournament_winner(fighter_a: Person, fighter_b: Person, division: String = "") -> Person:
	if fighter_a == null:
		return fighter_b
	if fighter_b == null:
		return fighter_a

	var a_score: float = _bending_competitive_score(fighter_a, division)
	var b_score: float = _bending_competitive_score(fighter_b, division)

	if is_equal_approx(a_score, b_score):
		return fighter_a if randi() % 2 == 0 else fighter_b

	return fighter_a if a_score >= b_score else fighter_b


func _mark_bending_tournament_match_void(tournament_id: String, match_id: String) -> void:
	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})

	if not tournaments.has(tournament_id):
		return

	var tournament: Dictionary = tournaments.get(tournament_id, {})
	var bracket: Array = tournament.get("bracket", [])

	for i in range(bracket.size()):
		var raw_match: Variant = bracket [i]
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("match_id", "")) != match_id:
			continue

		match_row ["status"] = "void"
		match_row ["winner_id"] = -1
		match_row ["winner_name"] = ""
		bracket [i] = match_row
		break

	tournament ["bracket"] = bracket
	tournaments [tournament_id] = tournament
	state ["tournaments"] = tournaments
	gs.scenario_state ["bending_world_championship"] = state
func get_agni_kai_championship_payload(actor: Person) -> Dictionary:
	_ensure_bending_world_bootstrap({
		"source": "agni_kai_hub_payload"
	})

	var eligible: bool = _is_agni_kai_eligible(actor)
	var hub_visible: bool = false

	if actor != null and bool(actor.alive):
		var clean_nation: String = str(actor.bending_nation).strip_edges().to_lower()
		var actor_element: String = _bending_person_primary_element(actor)
		if actor_element == "avatar":
			actor_element = _element_from_nation(str(actor.bending_nation))
		hub_visible = clean_nation == "fire nation" and actor_element == "fire"

	var year_value: int = int(gs.year) if gs != null else 0
	var tournament_id: String = _bending_tournament_id_for_division("agni_kai", year_value)
	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	var tournament: Dictionary = tournaments.get(tournament_id, {}) if tournaments.has(tournament_id) else {}
	var bracket: Array = tournament.get("bracket", []) if typeof(tournament.get("bracket", [])) == TYPE_ARRAY else []
	var status: String = str(tournament.get("status", "")).strip_edges().to_lower()
	var current_round: int = _bending_tournament_current_round(tournament) if not tournament.is_empty() else 1
	var actor_status: Dictionary = _bending_tournament_actor_status(tournament, actor)
	var actor_status_key: String = str(actor_status.get("status", "none")).strip_edges().to_lower()

	var entry_button_label: String = "Enter the Agni Kai" if eligible else "Agni Kai Locked — Fire Nation fire benders only"
	var entry_button_disabled: bool = not eligible
	var entry_button_tooltip: String = "A yearly Fire Nation championship where 50 elite fire benders fight for supremacy."

	match actor_status_key:
		"match_ready":
			entry_button_label = "Continue Agni Kai"
			entry_button_disabled = false
			entry_button_tooltip = "Continue your current Agni Kai tournament match."
		"advanced":
			entry_button_label = "Waiting on next Agni Kai tournament round"
			entry_button_disabled = true
		"entered_waiting":
			entry_button_label = "Waiting on Agni Kai tournament round"
			entry_button_disabled = true
		"champion":
			entry_button_label = "You already won the Agni Kai"
			entry_button_disabled = true
		"eliminated":
			entry_button_label = str(actor_status.get("entry_button_label", "Already Lost"))
			entry_button_disabled = true
		_:
			pass

	var can_advance_round: bool = false
	var can_spectate_match: bool = false

	if actor != null and not tournament.is_empty() and status == "active":
		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = raw_match
			if int(match_row.get("round", 1)) != current_round:
				continue
			if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
			if fighter_a_id == int(actor.id) or fighter_b_id == int(actor.id):
				continue

			can_advance_round = true
			can_spectate_match = true
			break

	return {
		"schema": "eralife.agni_kai_championship_hub_payload",
		"version": 2,
		"eligible": eligible,
		"hub_visible": hub_visible,
		"hidden_reason": "" if hub_visible else "Agni Kai is only shown to fire benders living in the Fire Nation.",
		"division": "agni_kai",
		"tournament_id": tournament_id,
		"label": "Agni Kai Championship of Unbreakable Fire",
		"tournament": tournament.duplicate(true),
		"bracket": bracket.duplicate(true),
		"current_round": current_round,
		"actor_tournament_status": actor_status.duplicate(true),
		"entry_button_disabled": entry_button_disabled,
		"entry_button_label": entry_button_label,
		"entry_button_tooltip": entry_button_tooltip,
		"can_advance_round": can_advance_round,
		"can_spectate_match": can_spectate_match,
		"has_active_bracket": status == "active" and not bracket.is_empty(),
		"bracket_visible": hub_visible and not bracket.is_empty(),
		"advance_button_label": "Advance Agni Kai tournament round",
		"bracket_label": "Agni Kai Bracket"
	}
func enter_agni_kai_championship(actor: Person, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Agni Kai Locked",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not _is_agni_kai_eligible(actor):
		return {
			"success": false,
			"popup_title": "Agni Kai Locked",
			"popup_text": "Only fire benders living in the Fire Nation may enter the Agni Kai.",
			"popup_footer": "Tap anywhere to continue."
		}

	var agni_options: Dictionary = options.duplicate(true)
	agni_options ["division"] = "agni_kai"
	agni_options ["source"] = str(agni_options.get("source", "agni_kai_player_entry"))
	agni_options ["force_include_actor"] = true
	agni_options ["repair_missing_match"] = true
	agni_options ["faction_fillers_enabled"] = true
	agni_options ["participant_cap"] = 50
	agni_options ["minimum_bracket_size"] = 50

	return enter_bending_world_championship(actor, agni_options)
func advance_agni_kai_championship_round(actor: Person, options: Dictionary = {}) -> Dictionary:
	var agni_options: Dictionary = options.duplicate(true)
	agni_options ["source"] = str(agni_options.get("source", "advance_agni_kai_championship_round"))
	agni_options ["division"] = "agni_kai"
	agni_options ["tournament_year"] = int(agni_options.get("tournament_year", int(gs.year) if gs != null else 0))
	agni_options ["participant_cap"] = 50
	agni_options ["minimum_bracket_size"] = 50

	return advance_bending_world_championship_round(actor, agni_options)
func enter_bending_world_championship(actor: Person, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Bending World Championship",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	_ensure_bending_world_bootstrap({
		"source": "enter_bending_world_championship"
	})

	var requested_division: String = str(options.get("division", "")).strip_edges().to_lower()
	var division: String = requested_division if requested_division != "" else get_bending_world_championship_division(actor, options)

	if requested_division == "agni_kai" and not _is_agni_kai_eligible(actor):
		return {
			"success": false,
			"popup_title": "Agni Kai Locked",
			"popup_text": "Only fire benders living in the Fire Nation may enter the Agni Kai.",
			"popup_footer": "Tap anywhere to continue."
		}

	if division == "ineligible":
		return {
			"success": false,
			"popup_title": "Tournament Locked",
			"popup_text": "You must be at least 10 years old to enter the Bending World Championship.",
			"popup_footer": "Tap anywhere to continue."
		}

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	var year_value: int = int(options.get("tournament_year", int(gs.year) if gs != null else 0))
	var tournament_id: String = _bending_tournament_id_for_division(division, year_value)
	var existing_tournament: Dictionary = tournaments.get(tournament_id, {}) if tournaments.has(tournament_id) else {}

	var gate_options: Dictionary = options.duplicate(true)
	gate_options ["tournament"] = existing_tournament.duplicate(true)
	gate_options ["tournament_id"] = tournament_id
	gate_options ["tournament_year"] = year_value

	var entry_gate: Dictionary = _bending_player_tournament_entry_gate(actor, division, gate_options)
	if not bool(entry_gate.get("allowed", true)):
		return {
			"success": false,
			"popup_title": str(entry_gate.get("popup_title", "Tournament Already Started")),
			"popup_text": str(entry_gate.get("popup_text", "This year's tournament already has a controlled entry.")),
			"popup_footer": str(entry_gate.get("popup_footer", "Tap anywhere to continue.")),
			"entry_gate": entry_gate.duplicate(true)
		}

	var entry_options: Dictionary = options.duplicate(true)
	entry_options ["division"] = division
	entry_options ["force_include_actor"] = true
	entry_options ["source"] = str(entry_options.get("source", "player_entry"))
	entry_options ["repair_missing_match"] = true
	entry_options ["faction_fillers_enabled"] = true

	var tournament: Dictionary = _ensure_bending_tournament_for_division(division, actor, entry_options)
	if tournament.is_empty():
		return {
			"success": false,
			"popup_title": "No Tournament Ready",
			"popup_text": "There are not enough eligible benders in your division to create a bracket yet.",
			"popup_footer": "Tap anywhere to continue."
		}

	tournament = _register_bending_tournament_entry(tournament, actor)
	_bending_mark_player_tournament_started(actor, tournament, entry_options)

	var actor_status: Dictionary = _bending_tournament_actor_status(tournament, actor)
	var actor_status_key: String = str(actor_status.get("status", "none")).strip_edges().to_lower()
	if actor_status_key == "eliminated":
		return {
			"success": false,
			"popup_title": "Tournament Run Over",
			"popup_text": "You already lost in the %s.\n\n%s finished you with %s." % [
				str(actor_status.get("round_label", "tournament")),
				str(actor_status.get("winner_name", "Your opponent")),
				str(actor_status.get("finish_move", "a finishing technique"))
			],
			"popup_footer": "Tap anywhere to continue.",
			"tournament": tournament,
			"actor_status": actor_status
		}

	if str(tournament.get("status", "")).strip_edges().to_lower() == "complete":
		return {
			"success": false,
			"popup_title": "Tournament Complete",
			"popup_text": "%s already ended this year.\n\nChampion: %s" % [
				str(tournament.get("label", "The tournament")),
				str(tournament.get("champion_name", "Unknown"))
			],
			"popup_footer": "Tap anywhere to continue.",
			"tournament": tournament,
			"actor_status": actor_status
		}

	var match_row: Dictionary = _find_or_create_player_tournament_match(tournament, actor)
	if match_row.is_empty():
		return {
			"success": false,
			"popup_title": "Round Not Ready",
			"popup_text": "Your next tournament match is not ready yet.\n\nAdvance the current round or spectate the remaining matches from the Bending Hub.",
			"popup_footer": "Tap anywhere to continue.",
			"tournament": tournament,
			"actor_status": actor_status
		}

	var refreshed_tournament: Dictionary = _bending_tournament_reload_by_id(tournament_id)
	if not refreshed_tournament.is_empty():
		tournament = refreshed_tournament
		var refreshed_match: Dictionary = _bending_pending_actor_tournament_match(tournament, int(actor.id), true)
		if not refreshed_match.is_empty():
			match_row = refreshed_match
		actor_status = _bending_tournament_actor_status(tournament, actor)

	var opponent_id: int = int(match_row.get("opponent_id", -1))
	var opponent: Person = _find_person_by_id(opponent_id)
	if opponent == null:
		return {
			"success": false,
			"popup_title": "Opponent Missing",
			"popup_text": "The tournament opponent could not be found.",
			"popup_footer": "Tap anywhere to continue.",
			"tournament": tournament
		}

	var scenario: Dictionary = build_bending_tournament_duel_scenario(actor, opponent, tournament, match_row)
	var style_identity: Dictionary = get_competitive_style_identity(actor, {
		"source": "tournament_entry",
		"system": "bending"
	})

	var avatar_line: String = ""
	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		avatar_line = "\n\nThe officials recognize you as the Avatar before you even step onto the floor."

	return {
		"success": true,
		"popup_title": "Tournament Match Ready",
		"popup_text": "Your %s match is ready.\n\nRound: %s\nOpponent: %s\nStyle Identity: %s%s\n\nWin and the world starts remembering your name." % [
			str(tournament.get("label", "Bending World Championship")),
			str(match_row.get("round_label", _bending_tournament_round_label(int(match_row.get("round", 1))))),
			_bending_person_label(opponent),
			str(style_identity.get("title", "A Forming Style")),
			avatar_line
		],
		"popup_footer": "Tap anywhere to continue.",
		"scenario": scenario,
		"tournament": tournament,
		"match": match_row,
		"actor_status": actor_status,
		"style_identity": style_identity.duplicate(true),
		"entry_gate": entry_gate.duplicate(true)
	}
func _bending_tournament_reload_by_id(tournament_id: String) -> Dictionary:
	if gs == null:
		return {}

	var clean_id: String = str(tournament_id).strip_edges()
	if clean_id == "":
		return {}

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	if not tournaments.has(clean_id):
		return {}

	var tournament: Dictionary = tournaments.get(clean_id, {})
	return tournament.duplicate(true) if typeof(tournament) == TYPE_DICTIONARY else {}


func _bending_tournament_live_theme_for_fighters(fighter_a: Person, fighter_b: Person) -> String:
	if fighter_a != null and str(fighter_a.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"
	if fighter_b != null and str(fighter_b.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"

	var element: String = _bending_person_primary_element(fighter_a)
	if element not in _base_bending_elements():
		element = _bending_person_primary_element(fighter_b)
	if element not in _base_bending_elements():
		element = "bending"

	return "bending_element_%s" % element


func _bending_tournament_live_move_name(actor: Person, exchange_index: int, finishing: bool = false) -> String:
	if actor == null:
		return "a bending motion"

	if finishing:
		return _bending_cpu_finish_move(actor)

	var element: String = _bending_person_primary_element(actor)
	match element:
		"fire":
			return ["Flame Jab", "Heat Feint", "Blazing Hook", "Pressure Burst"] [exchange_index % 4]
		"water":
			return ["Water Whip", "Mist Slip", "Tide Palm", "Flowing Counter"] [exchange_index % 4]
		"earth":
			return ["Stone Guard", "Rock Burst", "Ground Check", "Seismic Step"] [exchange_index % 4]
		"air":
			return ["Air Step", "Cyclone Flick", "Wind Slip", "Pressure Spiral"] [exchange_index % 4]
		_:
			return ["Basic Strike", "Guard Shift", "Rhythm Read", "Counter Step"] [exchange_index % 4]
func _bending_tournament_npc_mercy_decision(winner: Person, loser: Person, context: Dictionary = {}) -> Dictionary:
	if winner == null or loser == null:
		return {
			"action": "spare",
			"kill_chance": 0,
			"moral_label": "No mercy decision could be resolved."
		}

	var era_key: String = "modern"
	if gs != null and gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			era_key = str(gs.era.get("key", gs.era.get("name", "modern"))).strip_edges().to_lower()
		else:
			era_key = str(gs.era.name).strip_edges().to_lower()

	var kill_chance: int = 5
	match era_key:
		"ancient":
			kill_chance = 18
		"medieval":
			kill_chance = 14
		"industrial":
			kill_chance = 8
		"future":
			kill_chance = 4
		_:
			kill_chance = 5

	if bool(context.get("mock_match", false)) or bool(context.get("controlled_training", false)):
		kill_chance = 0

	kill_chance += int(clamp(float(winner.ambition) / 18.0, 0.0, 6.0))
	kill_chance += int(clamp(float(winner.fame) / 24.0, 0.0, 4.0))
	kill_chance -= int(clamp(float(winner.mental_health) / 25.0, 0.0, 4.0))
	kill_chance = int(clamp(kill_chance, 0, 35))

	var action: String = "kill" if (randi() % 100) < kill_chance else "spare"
	var finish_move: String = str(context.get("finish_move", _bending_cpu_finish_move(winner))).strip_edges()
	if finish_move == "":
		finish_move = _bending_cpu_finish_move(winner)

	var moral_label: String = "The crowd accepts the mercy."
	if action == "kill":
		moral_label = "The arena goes cold. The crowd knows they just witnessed something that will follow this bracket forever."

	return {
		"schema": "eralife.bending_npc_mercy_decision",
		"version": 1,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"loser_id": int(loser.id),
		"loser_name": _bending_person_label(loser),
		"action": action,
		"kill_chance": kill_chance,
		"finish_move": finish_move,
		"moral_label": moral_label,
		"source": str(context.get("source", "bending_tournament_live_match")),
		"tournament_id": str(context.get("tournament_id", "")),
		"tournament_match_id": str(context.get("tournament_match_id", "")),
		"year": int(gs.year) if gs != null else 0,
		"era": era_key
	}


func _apply_bending_tournament_npc_death(winner: Person, loser: Person, finish_move: String, context: Dictionary = {}) -> Dictionary:
	if winner == null or loser == null:
		return {}

	var cause: String = "Killed in a bending tournament by %s using %s" % [
		_bending_person_label(winner),
		finish_move
	]

	loser.health = 0
	loser.alive = false
	loser.cause_of_death = cause

	if gs != null and gs.has_method("sync_person_death_state_from_health"):
		gs.sync_person_death_state_from_health(loser, cause)

	var death_report: Dictionary = {
		"schema": "eralife.bending_tournament_npc_death_report",
		"version": 1,
		"success": true,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"loser_id": int(loser.id),
		"loser_name": _bending_person_label(loser),
		"finish_move": finish_move,
		"cause": cause,
		"source": str(context.get("source", "bending_tournament_live_match")),
		"tournament_id": str(context.get("tournament_id", "")),
		"tournament_match_id": str(context.get("tournament_match_id", "")),
		"year": int(gs.year) if gs != null else 0
	}

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed("%s killed %s after winning a bending tournament match with %s." % [
			_bending_person_label(winner),
			_bending_person_label(loser),
			finish_move
		], {
			"category": "bending",
			"event_name": "bending_tournament_npc_killed_opponent",
			"source": "bending_engine",
			"npc_id": int(winner.id),
			"target_id": int(loser.id),
			"personally_relevant": gs.player != null and (int(gs.player.id) == int(winner.id) or int(gs.player.id) == int(loser.id)),
			"tournament_id": str(context.get("tournament_id", "")),
			"tournament_match_id": str(context.get("tournament_match_id", ""))
		})

	return death_report
func _simulate_bending_tournament_live_match(fighter_a: Person, fighter_b: Person, tournament: Dictionary, match_row: Dictionary, options: Dictionary = {}) -> Dictionary:
	var division: String = str(tournament.get("division", ""))
	var round_value: int = int(match_row.get("round", _bending_tournament_current_round(tournament)))
	var round_field_size: int = _bending_tournament_field_size_for_round(tournament, round_value)
	var round_label: String = str(match_row.get("round_label", _bending_tournament_round_label(round_value, round_field_size)))
	var stage_label: String = _bending_tournament_stage_label(tournament, round_value)
	var a_score: float = _bending_competitive_score(fighter_a, division)
	var b_score: float = _bending_competitive_score(fighter_b, division)

	var a_element: String = _bending_person_primary_element(fighter_a)
	var b_element: String = _bending_person_primary_element(fighter_b)

	var a_hp_max: int = max(45, int(fighter_a.health) + int(a_score * 0.18))
	var b_hp_max: int = max(45, int(fighter_b.health) + int(b_score * 0.18))
	var a_hp: int = a_hp_max
	var b_hp: int = b_hp_max

	var a_adaptation: Dictionary = _bending_live_adaptation_profile(fighter_a, a_element, {
		"division": division,
		"side": "fighter_a",
		"opponent": fighter_b,
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", ""))
	})
	var b_adaptation: Dictionary = _bending_live_adaptation_profile(fighter_b, b_element, {
		"division": division,
		"side": "fighter_b",
		"opponent": fighter_a,
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", ""))
	})

	var frames: Array = []
	var exchanges: Array = []

	frames.append({
		"panel_title": "%s — SPECTATING" % stage_label.to_upper(),
		"text": "%s begins.\n\n%s and %s take the floor. Both fighters start reading the room before the first move.%s%s" % [
			round_label,
			_bending_person_label(fighter_a),
			_bending_person_label(fighter_b),
			"\n\n%s enters with archive study: %s" % [_bending_person_label(fighter_a), str(a_adaptation.get("archive_study", {}).get("line", ""))] if int(a_adaptation.get("archive_study_bonus", 0)) > 0 else "",
			"\n\n%s enters with archive study: %s" % [_bending_person_label(fighter_b), str(b_adaptation.get("archive_study", {}).get("line", ""))] if int(b_adaptation.get("archive_study_bonus", 0)) > 0 else ""
		],
		"footer_text": "Spectating live. No input needed.",
		"combat_ui": _bending_tournament_spectator_combat_ui(fighter_a, fighter_b, tournament, match_row, a_hp, a_hp_max, b_hp, b_hp_max, "%s • opening stances" % round_label),
		"opps": [
			{
				"label": "%s settles into stance" % _bending_person_label(fighter_a),
				"disabled": true,
				"button_theme": "bending_ability",
				"ability_element": a_element,
				"power_source": "bending"
			},
			{
				"label": "%s studies the angle" % _bending_person_label(fighter_b),
				"disabled": true,
				"button_theme": "bending_ability",
				"ability_element": b_element,
				"power_source": "bending"
			}
		]
	})

	var finish_move: String = ""
	var winner: Person = null
	var loser: Person = null
	var max_exchanges: int = int(options.get("max_exchanges", 6))

	for exchange_index in range(1, max_exchanges + 1):
		var a_bonus: int = int(a_adaptation.get("current_bonus", 0))
		var b_bonus: int = int(b_adaptation.get("current_bonus", 0))

		var a_roll: int = int(round(a_score)) + randi_range(4, 22) + a_bonus
		var b_roll: int = int(round(b_score)) + randi_range(4, 22) + b_bonus

		var a_move: String = _bending_tournament_adaptive_live_move_name(fighter_a, a_element, exchange_index, a_adaptation)
		var b_move: String = _bending_tournament_adaptive_live_move_name(fighter_b, b_element, exchange_index, b_adaptation)

		var exchange_text: String = ""
		var chosen_move: String = ""
		var exchange_winner_side: String = ""
		var exchange_damage: int = 0

		if a_roll >= b_roll:
			var damage_to_b: int = int(clamp(round(float(a_roll - b_roll) * 0.42 + float(a_score) * 0.04 + randf() * 10.0), 4, 34))
			exchange_damage = damage_to_b
			b_hp = max(0, b_hp - damage_to_b)
			chosen_move = a_move
			finish_move = a_move
			exchange_winner_side = "fighter_a"
			exchange_text = "%s chose %s.\n\n%s adapted late and lost %d health." % [
				_bending_person_label(fighter_a),
				a_move,
				_bending_person_label(fighter_b),
				damage_to_b
			]
			b_adaptation ["current_bonus"] = _bending_tournament_live_adaptation_gain(b_adaptation, true)
			a_adaptation ["current_bonus"] = _bending_tournament_live_adaptation_gain(a_adaptation, false)
		else:
			var damage_to_a: int = int(clamp(round(float(b_roll - a_roll) * 0.42 + float(b_score) * 0.04 + randf() * 10.0), 4, 34))
			exchange_damage = damage_to_a
			a_hp = max(0, a_hp - damage_to_a)
			chosen_move = b_move
			finish_move = b_move
			exchange_winner_side = "fighter_b"
			exchange_text = "%s chose %s.\n\n%s adjusted late and lost %d health." % [
				_bending_person_label(fighter_b),
				b_move,
				_bending_person_label(fighter_a),
				damage_to_a
			]
			a_adaptation ["current_bonus"] = _bending_tournament_live_adaptation_gain(a_adaptation, true)
			b_adaptation ["current_bonus"] = _bending_tournament_live_adaptation_gain(b_adaptation, false)

		var adaptation_line: String = _bending_tournament_live_adaptation_line(fighter_a, fighter_b, a_adaptation, b_adaptation)
		if adaptation_line != "":
			exchange_text += "\n\n%s" % adaptation_line

		exchanges.append({
			"exchange": exchange_index,
			"fighter_a_hp": a_hp,
			"fighter_b_hp": b_hp,
			"fighter_a_roll": a_roll,
			"fighter_b_roll": b_roll,
			"fighter_a_move": a_move,
			"fighter_b_move": b_move,
			"chosen_move": chosen_move,
			"exchange_winner_side": exchange_winner_side,
			"fighter_a_adaptation_bonus": int(a_adaptation.get("current_bonus", 0)),
			"fighter_b_adaptation_bonus": int(b_adaptation.get("current_bonus", 0))
		})

		var active_actor: Person = fighter_a if exchange_winner_side == "fighter_a" else fighter_b
		var active_target: Person = fighter_b if exchange_winner_side == "fighter_a" else fighter_a
		var active_element: String = a_element if exchange_winner_side == "fighter_a" else b_element
		var active_motion: String = "%s_exchange_flash" % active_element
		match active_element:
			"fire":
				active_motion = "flame_burst_exchange_flash"
			"water":
				active_motion = "water_ripple_exchange_flash"
			"earth":
				active_motion = "earth_impact_exchange_flash"
			"air":
				active_motion = "air_pressure_exchange_flash"
			"avatar":
				active_motion = "avatar_spectrum_exchange_flash"

		var exchange_combat_ui: Dictionary = _bending_tournament_spectator_combat_ui(fighter_a, fighter_b, tournament, match_row, a_hp, a_hp_max, b_hp, b_hp_max, "%s • exchange %d" % [round_label, exchange_index], {
			"elemental_flash": true,
			"active_element": active_element,
			"active_move": chosen_move,
			"active_actor_name": _bending_person_label(active_actor),
			"surge_direction": "fighter_a_to_fighter_b" if exchange_winner_side == "fighter_a" else "fighter_b_to_fighter_a",
			"surge_origin_id": int(active_actor.id) if active_actor != null else -1,
			"surge_target_id": int(active_target.id) if active_target != null else -1,
			"surge_line": "%s bent %s through %s." % [
				_bending_person_label(active_actor),
				active_element,
				chosen_move
			],
			"screen_damage": "high" if exchange_damage >= 22 else "medium",
			"screen_damage_intensity": clamp(0.42 + float(exchange_damage) / 42.0, 0.42, 0.95),
			"time_dilation": 0.68,
			"audio_muffle": 0.42,
			"impact_shake_amount": clamp(8.0 + float(exchange_damage) * 0.42, 8.0, 24.0),
			"motion": active_motion
		})

		frames.append({
			"panel_title": "%s — SPECTATING" % stage_label.to_upper(),
			"text": "%s • Exchange %d\n\n%s" % [round_label, exchange_index, exchange_text],
			"footer_text": "Spectating live. The bracket is resolving in real time.",
			"combat_ui": exchange_combat_ui,
			"opps": [
				{
					"label": "%s: %s" % [_bending_person_label(fighter_a), a_move],
					"disabled": true,
					"button_theme": "bending_ability",
					"ability_element": a_element,
					"power_source": "bending",
					"spectator_chosen": exchange_winner_side == "fighter_a",
					"elemental_flash": exchange_winner_side == "fighter_a"
				},
				{
					"label": "%s: %s" % [_bending_person_label(fighter_b), b_move],
					"disabled": true,
					"button_theme": "bending_ability",
					"ability_element": b_element,
					"power_source": "bending",
					"spectator_chosen": exchange_winner_side == "fighter_b",
					"elemental_flash": exchange_winner_side == "fighter_b"
				}
			]
		})

		if a_hp <= 0 or b_hp <= 0:
			break

	if a_hp == b_hp:
		winner = fighter_a if a_score >= b_score else fighter_b
	else:
		winner = fighter_a if a_hp > b_hp else fighter_b

	loser = fighter_b if winner == fighter_a else fighter_a

	if finish_move == "":
		finish_move = _bending_cpu_finish_move(winner)

	if loser == fighter_a:
		a_hp = 0
		b_hp = max(1, b_hp)
	else:
		b_hp = 0
		a_hp = max(1, a_hp)

	var mercy_decision: Dictionary = _bending_tournament_npc_mercy_decision(winner, loser, {
		"source": "bending_tournament_live_match",
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", "")),
		"finish_move": finish_move,
		"division": division
	})
	var mercy_action: String = str(mercy_decision.get("action", "spare")).strip_edges().to_lower()
	var death_report: Dictionary = {}
	var reality_surge_report: Dictionary = {}
	var reality_surge_packet: Dictionary = {}
	var surge_vector: Dictionary = {}

	var aftermath_text: String = ""
	if mercy_action == "kill":

		death_report = _apply_bending_tournament_npc_death(winner, loser, finish_move, {
			"source": "bending_tournament_live_match",
			"tournament_id": str(tournament.get("id", "")),
			"tournament_match_id": str(match_row.get("match_id", ""))
		})

		reality_surge_report = _trigger_bending_tournament_npc_fatal_reality_surge(winner, loser, finish_move, tournament, match_row, death_report)
		reality_surge_packet = _safe_dictionary(reality_surge_report.get("event_payload", {}))
		if reality_surge_packet.is_empty():
			reality_surge_packet = _bending_tournament_npc_fatal_surge_payload(winner, loser, finish_move, tournament, match_row, death_report)

		surge_vector = _bending_tournament_npc_fatal_surge_vector(winner, loser, finish_move, tournament, match_row)
		aftermath_text = "%s finished the match with %s.\n\n%s\n\n%s is eliminated from this round.\n\nThen %s chose not to spare %s.\n%s" % [
			_bending_person_label(winner),
			finish_move,
			str(surge_vector.get("text", "Their element surged through the final hit.")),
			_bending_person_label(loser),
			_bending_person_label(winner),
			_bending_person_label(loser),
			str(mercy_decision.get("moral_label", "The arena goes silent."))
		]
	else:
		if gs != null and gs.has_method("push_world_feed"):
			gs.push_world_feed("%s spared %s after winning a bending tournament match." % [
				_bending_person_label(winner),
				_bending_person_label(loser)
			], {
				"category": "bending",
				"event_name": "bending_tournament_npc_spared_opponent",
				"source": "bending_engine",
				"npc_id": int(winner.id),
				"target_id": int(loser.id),
				"personally_relevant": gs.player != null and (int(gs.player.id) == int(winner.id) or int(gs.player.id) == int(loser.id)),
				"tournament_id": str(tournament.get("id", "")),
				"tournament_match_id": str(match_row.get("match_id", ""))
			})

		aftermath_text = "%s finished the match with %s.\n\n%s is eliminated from this round.\n\n%s spared %s." % [
			_bending_person_label(winner),
			finish_move,
			_bending_person_label(loser),
			_bending_person_label(winner),
			_bending_person_label(loser)
		]

	var final_combat_ui: Dictionary = _bending_tournament_spectator_combat_ui(fighter_a, fighter_b, tournament, match_row, a_hp, a_hp_max, b_hp, b_hp_max, "%s • mercy resolved" % round_label)
	if mercy_action == "kill":
		final_combat_ui ["surge_vector"] = surge_vector.duplicate(true)
		final_combat_ui ["elemental_screen_damage"] = {
			"enabled": true,
			"screen_damage": "max",
			"screen_damage_intensity": 1.0,
			"screen_fracture": true,
			"screen_bleed": true,
			"time_dilation": 0.3,
			"audio_muffle": 1.0,
			"element": str(surge_vector.get("element", _bending_person_primary_element(winner))),
			"finish_move": finish_move,
			"motion": str(surge_vector.get("motion", "element_into_body"))
		}
		final_combat_ui ["reality_surge"] = reality_surge_report.duplicate(true)
		final_combat_ui ["reality_surge_packet"] = reality_surge_packet.duplicate(true)

	frames.append({
		"panel_title": "%s — SPECTATING" % stage_label.to_upper(),
		"text": aftermath_text,
		"footer_text": "Spectated match complete.",
		"combat_ui": final_combat_ui,
		"opps": [
			{
				"label": "Winner: %s" % _bending_person_label(winner),
				"disabled": true,
				"button_theme": "bending_ability",
				"ability_element": _bending_person_primary_element(winner),
				"power_source": "bending",
			},
			{
				"label": "Mercy: %s" % mercy_action.to_upper(),
				"disabled": true,
				"button_theme": "bending_duel_mercy" if mercy_action == "kill" else "defensive_escape",
				"power_source": "bending",
				"spectator_chosen": mercy_action == "kill"
			},
			{
				"label": "Finish: %s" % finish_move,
				"disabled": true,
				"button_theme": "artifact_action",
				"power_source": "knowledge"
			}
		]
	})

	return {
		"schema": "eralife.bending_tournament_live_match",
		"version": 3,
		"fighter_a_id": int(fighter_a.id),
		"fighter_b_id": int(fighter_b.id),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"finish_move": finish_move,
		"mercy_action": mercy_action,
		"mercy_decision": mercy_decision.duplicate(true),
		"death": mercy_action == "kill",
		"death_report": death_report.duplicate(true),
		"reality_surge_report": reality_surge_report.duplicate(true),
		"reality_surge_packet": reality_surge_packet.duplicate(true),
		"surge_vector": surge_vector.duplicate(true),
		"surge_direction": str(surge_vector.get("direction", "")),
		"surge_origin_id": int(surge_vector.get("origin_id", -1)),
		"surge_target_id": int(surge_vector.get("target_id", -1)),
		"surge_vector_mode": str(surge_vector.get("mode", "")),
		"fighter_a_final_hp": a_hp,
		"fighter_b_final_hp": b_hp,
		"fighter_a_hp_max": a_hp_max,
		"fighter_b_hp_max": b_hp_max,
		"fighter_a_adaptation": a_adaptation.duplicate(true),
		"fighter_b_adaptation": b_adaptation.duplicate(true),
		"exchanges": exchanges,
		"spectator_frames": frames
	}
func _bending_tournament_match_is_championship_final(tournament: Dictionary, match_row: Dictionary) -> bool:
	var match_round: int = int(match_row.get("round", _bending_tournament_current_round(tournament)))
	var field_size: int = _bending_tournament_field_size_for_round(tournament, match_round)
	var round_label: String = str(match_row.get("round_label", _bending_tournament_round_label(match_round, field_size))).strip_edges().to_lower()
	return round_label == "championship final" or field_size <= 2
func _bending_tournament_pending_championship_spectate_match(tournament: Dictionary, actor_id: int) -> Dictionary:
	if tournament.is_empty():
		return {}

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
			continue

		if not _bending_tournament_match_is_championship_final(tournament, match_row):
			continue

		var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
		var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
		if fighter_a_id <= 0 or fighter_b_id <= 0:
			continue

		if actor_id > 0 and (fighter_a_id == actor_id or fighter_b_id == actor_id):
			continue

		return match_row.duplicate(true)

	return {}
func _spectate_bending_tournament_championship_from_elimination(actor: Person, tournament: Dictionary, options: Dictionary = {}) -> Dictionary:
	if actor == null or tournament.is_empty():
		return {
			"success": false,
			"popup_title": "Championship Spectate",
			"popup_text": "No active tournament was available to spectate.",
			"popup_footer": "Tap anywhere to continue."
		}

	var tournament_id: String = str(tournament.get("id", "")).strip_edges()
	if tournament_id == "":
		return {
			"success": false,
			"popup_title": "Championship Spectate",
			"popup_text": "The tournament id was missing.",
			"popup_footer": "Tap anywhere to continue."
		}

	var actor_id: int = int(actor.id)
	var safety_limit: int = int(options.get("championship_skip_safety", 80))
	var last_result: Dictionary = {}

	for _step in range(safety_limit):
		var live_tournament: Dictionary = _bending_tournament_reload_by_id(tournament_id)
		if live_tournament.is_empty():
			live_tournament = tournament.duplicate(true)

		if str(live_tournament.get("status", "")).strip_edges().to_lower() == "complete":
			return {
				"success": true,
				"popup_title": "Tournament Complete",
				"popup_text": "%s is complete.\n\nChampion: %s" % [
					str(live_tournament.get("label", "The tournament")),
					str(live_tournament.get("champion_name", "Unknown"))
				],
				"popup_footer": "Tap anywhere to continue.",
				"tournament": live_tournament.duplicate(true)
			}

		var final_match: Dictionary = _bending_tournament_pending_championship_spectate_match(live_tournament, actor_id)
		if not final_match.is_empty():
			var spectate_options: Dictionary = options.duplicate(true)
			spectate_options ["mode"] = "spectate_next_live"
			spectate_options ["source"] = str(options.get("source", "bending_hub_skip_to_championship"))
			spectate_options ["spectator_frame_seconds"] = float(options.get("spectator_frame_seconds", 0.85))
			return advance_bending_world_championship_round(actor, spectate_options)

		var step_options: Dictionary = options.duplicate(true)
		step_options ["mode"] = "advance_current_round"
		step_options ["source"] = "skip_to_championship_auto_advance"
		last_result = advance_bending_world_championship_round(actor, step_options)

		if bool(last_result.get("blocked_by_elimination", false)):
			break

	return {
		"success": false,
		"popup_title": "Championship Not Ready",
		"popup_text": "The bracket could not safely skip all the way to the championship yet.\n\nLast result: %s" % str(last_result.get("popup_text", "No match result was produced.")),
		"popup_footer": "Tap anywhere to continue.",
		"tournament": _bending_tournament_reload_by_id(tournament_id)
	}
func _bending_tournament_npc_fatal_surge_vector(winner: Person, loser: Person, finish_move: String, tournament: Dictionary, match_row: Dictionary) -> Dictionary:
	var element: String = _bending_person_primary_element(winner)
	if element == "":
		element = "bending"

	var origin_name: String = _bending_person_label(winner)
	var target_name: String = _bending_person_label(loser)
	var championship_final: bool = _bending_tournament_match_is_championship_final(tournament, match_row)

	var motion: String = "element_into_body"
	var impact_line: String = "%s surged out of %s and into %s." % [
		element.capitalize(),
		origin_name,
		target_name
	]

	match element:
		"fire":
			motion = "flame_surge_into_body"
			impact_line = "Fire surged out of %s and into %s like the arena itself inhaled smoke." % [
				origin_name,
				target_name
			]
		"water":
			motion = "pressure_wave_into_body"
			impact_line = "Water surged out of %s and into %s with a pressure that made the crowd forget how to breathe." % [
				origin_name,
				target_name
			]
		"earth":
			motion = "stone_force_into_body"
			impact_line = "Earth surged out of %s and into %s with enough weight to make the bracket feel buried." % [
				origin_name,
				target_name
			]
		"air":
			motion = "vacuum_burst_into_body"
			impact_line = "Air surged out of %s and into %s, and the silence arrived before the body fell." % [
				origin_name,
				target_name
			]
		"avatar":
			motion = "four_element_surge_into_body"
			impact_line = "Fire, water, earth, and air surged out of %s and into %s at once." % [
				origin_name,
				target_name
			]

	if championship_final:
		impact_line += "\n\nBecause this was the championship final, the hit did not feel like a result. It felt like reality accepting a new champion."

	return {
		"schema": "eralife.bending_tournament_spectator_surge_vector",
		"version": 1,
		"direction": "actor_to_victim",
		"origin_id": int(winner.id) if winner != null else -1,
		"origin_name": origin_name,
		"target_id": int(loser.id) if loser != null else -1,
		"target_name": target_name,
		"element": element,
		"finish_move": finish_move,
		"mode": "element_into_body",
		"motion": motion,
		"championship_final": championship_final,
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", "")),
		"round": int(match_row.get("round", _bending_tournament_current_round(tournament))),
		"round_label": str(match_row.get("round_label", "")),
		"text": impact_line
	}

func _bending_tournament_npc_fatal_surge_payload(winner: Person, loser: Person, finish_move: String, tournament: Dictionary, match_row: Dictionary, death_report: Dictionary = {}) -> Dictionary:
	var surge_vector: Dictionary = _bending_tournament_npc_fatal_surge_vector(winner, loser, finish_move, tournament, match_row)
	var championship_final: bool = bool(surge_vector.get("championship_final", false))
	var element: String = str(surge_vector.get("element", "bending")).strip_edges().to_lower()

	return {
		"schema": "eralife.bending_fatal_finish_reality_break_event",
		"version": 3,
		"event_name": "bending.fatal_finish.reality.break",
		"domain": "bending",
		"reality_break": true,
		"championship": true,
		"championship_final": championship_final,
		"fatal_finish": true,
		"death": true,
		"winner_is_player": winner == gs.player if gs != null else false,
		"winner_id": int(winner.id) if winner != null else -1,
		"winner_name": _bending_person_label(winner),
		"victim_id": int(loser.id) if loser != null else -1,
		"victim_name": _bending_person_label(loser),
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", "")),
		"match_id": str(match_row.get("match_id", "")),
		"division": str(tournament.get("division", "")),
		"element": element,
		"finish_move": finish_move,
		"screen_damage": "max",
		"time_dilation": 0.3,
		"audio_muffle": 1.0,
		"surge_direction": str(surge_vector.get("direction", "actor_to_victim")),
		"surge_origin_id": int(surge_vector.get("origin_id", -1)),
		"surge_origin_name": str(surge_vector.get("origin_name", "")),
		"surge_target_id": int(surge_vector.get("target_id", -1)),
		"surge_target_name": str(surge_vector.get("target_name", "")),
		"surge_vector_mode": "element_into_body",
		"surge_line": str(surge_vector.get("text", "")),
		"surge_vector": surge_vector.duplicate(true),
		"death_report": death_report.duplicate(true),
		"salience": 100.0
	}
func _bending_tournament_npc_fatal_reality_surge_contract(contract_id: String, element: String, finish_move: String, championship_final: bool) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = "bending"

	return {
		"schema": "eralife.reality_surge_contract",
		"version": 2,
		"id": contract_id,
		"domain": "bending",
		"display_name": "NPC Tournament Fatal Finish Reality Break",
		"trigger": {
			"event": "bending.fatal_finish.reality.break",
			"filters": {
				"domain": "bending",
				"fatal_finish": true
			},
			"threshold": {
				"salience_min": 95.0
			}
		},
		"surge_profile": {
			"type": ["reality_break", "fatal_finish", "npc_spectator_match", "elemental_execution", "championship_final" if championship_final else "tournament_round"],
			"intensity": 1.0,
			"championship_final": championship_final,
			"finish_move": finish_move,
			"element": clean_element
		},
		"visual_layer": {
			"theme_resolver": "elemental_affinity_resolver",
			"shader_profile": "npc_fatal_reality_break_%s" % clean_element,
			"screen_damage": "max",
			"screen_damage_intensity": 1.0,
			"screen_fracture": true,
			"screen_bleed": true,
			"distortion": true,
			"particles": true,
			"fatal_finish": true,
			"element": clean_element,
			"finish_move": finish_move,
			"surge_vector_mode": "element_into_body"
		},
		"perception_layer": {
			"time_dilation": 0.3,
			"input_lock_ms": 1800,
			"camera_weight": 1.0,
			"audio_muffle": 1.0,
		},
		"reward_manifestation": {},
		"stat_echo": {},
		"stability": {
			"instability_gain": 0.42,
			"mutation_chance": 0.025,
		}
	}
func _trigger_bending_tournament_npc_fatal_reality_surge(winner: Person, loser: Person, finish_move: String, tournament: Dictionary, match_row: Dictionary, death_report: Dictionary = {}) -> Dictionary:
	if gs == null or winner == null or loser == null:
		return {}

	if not ("reality_surge_engine" in gs) or gs.reality_surge_engine == null:
		return {}

	if not gs.reality_surge_engine.has_method("trigger_surge"):
		return {}

	var payload: Dictionary = _bending_tournament_npc_fatal_surge_payload(winner, loser, finish_move, tournament, match_row, death_report)
	var element: String = str(payload.get("element", "bending")).strip_edges().to_lower()
	var championship_final: bool = bool(payload.get("championship_final", false))
	var contract_id: String = "bending.npc_championship_fatal_final.reality_break" if championship_final else "bending.npc_tournament_fatal_finish.reality_break"
	var contract: Dictionary = _bending_tournament_npc_fatal_reality_surge_contract(contract_id, element, finish_move, championship_final)

	if gs.reality_surge_engine.has_method("register_surge_contract"):
		gs.reality_surge_engine.register_surge_contract(contract)

	return gs.reality_surge_engine.trigger_surge(contract_id, winner, payload, {
		"source": "bending_engine_npc_tournament_spectator_fatal_reality_break",
		"force": true,
		"duplicate_window_ms": 900,
		"tournament_id": str(tournament.get("id", "")),
		"division": str(tournament.get("division", "")),
		"element": element,
		"fatal_finish": true,
		"championship_final": championship_final,
		"finish_move": finish_move,
		"surge_direction": str(payload.get("surge_direction", "actor_to_victim")),
		"surge_origin_id": int(payload.get("surge_origin_id", -1)),
		"surge_target_id": int(payload.get("surge_target_id", -1)),
		"surge_vector_mode": "element_into_body",
		"salience": 100.0
	})
func _bending_live_adaptation_profile(actor: Person, element: String, context: Dictionary = {}) -> Dictionary:
	var level: int = 0
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_bending_level"):
		level = int(gs.bending_engine.get_bending_level(actor, element))
	elif actor != null and typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		level = int(actor.bending_mastery.get(element, 0))

	var speed: float = 0.28
	if actor != null:
		speed += float(level) / 150.0
		speed += float(actor.smarts) / 280.0
		speed += float(actor.mental_health) / 420.0
		speed += float(actor.ambition) / 520.0

	var opponent: Person = context.get("opponent", null)
	var archive_study: Dictionary = {}
	if opponent != null:
		archive_study = get_bending_archival_study_report(actor, opponent, {
			"source": "live_tournament_adaptation_profile",
			"side": str(context.get("side", "")),
			"division": str(context.get("division", ""))
		})

	var study_bonus: int = int(archive_study.get("bonus", 0))
	if study_bonus > 0:
		speed += float(study_bonus) / 100.0

	speed = clamp(speed, 0.22, 1.45)

	return {
		"schema": "eralife.bending_live_adaptation_profile",
		"version": 2,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _bending_person_label(actor),
		"element": element,
		"level": level,
		"speed": speed,
		"ceiling": clamp(5 + int(round(float(level) / 7.5)) + int(float(study_bonus) / 2.0), 5, 32),
		"current_bonus": study_bonus,
		"archive_study_bonus": study_bonus,
		"archive_study": archive_study.duplicate(true),
		"side": str(context.get("side", ""))
	}
func _bending_tournament_live_adaptation_gain(profile: Dictionary, under_pressure: bool) -> int:
	var current_bonus: int = int(profile.get("current_bonus", 0))
	var ceiling: int = int(profile.get("ceiling", 12))
	var speed: float = float(profile.get("speed", 0.5))
	var gain: int = max(1, int(round(speed * (3.2 if under_pressure else 1.5))))
	return clamp(current_bonus + gain, 0, ceiling)
func _bending_tournament_adaptive_live_move_name(actor: Person, element: String, exchange_index: int, profile: Dictionary) -> String:
	var bonus: int = int(profile.get("current_bonus", 0))
	if bonus >= 18:
		match str(element).strip_edges().to_lower():
			"air":
				return "tournament void-step read"
			"water":
				return "championship current reversal"
			"earth":
				return "seismic counter checkmate"
			"fire":
				return "blue-flame tempo break"
			_:
				return "adaptive championship counter"
	if bonus >= 10:
		match str(element).strip_edges().to_lower():
			"air":
				return "angle-breaking air feint"
			"water":
				return "flow-reading water bind"
			"earth":
				return "root-shift counter"
			"fire":
				return "pressure-switch flame burst"
			_:
				return "adaptive bending feint"
	return _bending_tournament_live_move_name(actor, exchange_index, false)
func _bending_tournament_live_adaptation_line(fighter_a: Person, fighter_b: Person, a_profile: Dictionary, b_profile: Dictionary) -> String:
	var a_bonus: int = int(a_profile.get("current_bonus", 0))
	var b_bonus: int = int(b_profile.get("current_bonus", 0))
	if a_bonus >= 18 and b_bonus >= 18:
		return "Both fighters are adapting at championship speed now. Every move is getting answered before it fully forms."
	if a_bonus >= 14:
		return "%s has started reading the pattern in real time." % _bending_person_label(fighter_a)
	if b_bonus >= 14:
		return "%s has started reading the pattern in real time." % _bending_person_label(fighter_b)
	return ""
func _bending_tournament_spectator_combat_ui(
	fighter_a: Person,
	fighter_b: Person,
	tournament: Dictionary,
	match_row: Dictionary,
	a_hp: int,
	a_hp_max: int,
	b_hp: int,
	b_hp_max: int,
	status_text: String,
	context: Dictionary = {}
) -> Dictionary:
	var a_element: String = _bending_person_primary_element(fighter_a)
	var b_element: String = _bending_person_primary_element(fighter_b)
	var active_element: String = str(context.get("active_element", "")).strip_edges().to_lower()
	var active_move: String = str(context.get("active_move", "")).strip_edges()
	var active_origin_id: int = int(context.get("surge_origin_id", -1))
	var active_target_id: int = int(context.get("surge_target_id", -1))
	var active_direction: String = str(context.get("surge_direction", "actor_to_victim")).strip_edges()
	var flash_enabled: bool = bool(context.get("elemental_flash", false)) and active_element != ""

	var ui: Dictionary = {
		"visible": true,
		"theme": _bending_tournament_live_theme_for_fighters(fighter_a, fighter_b),
		"player_theme": _bending_actor_combat_theme(fighter_a),
		"enemy_theme": _bending_actor_combat_theme(fighter_b),
		"player_avatar_pulse": fighter_a != null and str(fighter_a.bending_type).strip_edges().to_lower() == "avatar",
		"enemy_avatar_pulse": fighter_b != null and str(fighter_b.bending_type).strip_edges().to_lower() == "avatar",
		"status_text": status_text,
		"player_label": "%s • %s bending • Record %s • WP %d" % [
			_bending_person_label(fighter_a),
			a_element.capitalize(),
			_bending_actor_record_summary(fighter_a),
			_bending_actor_willpower_score(fighter_a, { "source": "spectator_combat_ui"})
		],
		"player_value": max(0, a_hp),
		"player_max": max(1, a_hp_max),
		"enemy_label": "%s • %s bending • Record %s • WP %d" % [
			_bending_person_label(fighter_b),
			b_element.capitalize(),
			_bending_actor_record_summary(fighter_b),
			_bending_actor_willpower_score(fighter_b, { "source": "spectator_combat_ui"})
		],
		"enemy_value": max(0, b_hp),
		"enemy_max": max(1, b_hp_max),
		"impact_shake": true,
		"impact_shake_amount": float(context.get("impact_shake_amount", 8.0)),
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", ""))
	}

	if flash_enabled:
		ui ["surge_vector"] = {
			"enabled": true,
			"direction": active_direction,
			"origin_id": active_origin_id,
			"target_id": active_target_id,
			"element": active_element,
			"finish_move": active_move,
			"mode": "element_into_body" if bool(context.get("fatal_finish", false)) else "elemental_exchange",
			"text": str(context.get("surge_line", "%s bends %s through the exchange." % [str(context.get("active_actor_name", "A fighter")), active_element]))
		}
		ui ["elemental_screen_damage"] = {
			"enabled": true,
			"screen_damage": str(context.get("screen_damage", "medium")),
			"screen_damage_intensity": float(context.get("screen_damage_intensity", 0.62)),
			"screen_fracture": bool(context.get("screen_fracture", false)),
			"screen_bleed": bool(context.get("screen_bleed", false)),
			"time_dilation": float(context.get("time_dilation", 0.72)),
			"audio_muffle": float(context.get("audio_muffle", 0.35)),
			"element": active_element,
			"finish_move": active_move,
			"motion": str(context.get("motion", "%s_surge_flash" % active_element))
		}

	return ui


func _build_bending_tournament_spectator_result(
	fighter_a: Person,
	fighter_b: Person,
	winner: Person,
	loser: Person,
	finish_move: String,
	tournament: Dictionary,
	match_row: Dictionary,
	match_payload: Dictionary = {}
) -> Dictionary:
	if match_payload.is_empty():
		match_payload = _simulate_bending_tournament_live_match(fighter_a, fighter_b, tournament, match_row)

	var frames: Array = _safe_array(match_payload.get("spectator_frames", []))
	if frames.is_empty():
		return {
			"success": true,
			"uses_scenario_panel": true,
			"spectator_frames": [],
			"panel_title": "BENDING WORLD CHAMPIONSHIP — SPECTATING",
			"text": "%s defeated %s with %s." % [
				_bending_person_label(winner),
				_bending_person_label(loser),
				finish_move
			],
			"footer_text": "Spectated match complete.",
			"opps": [],
			"popup_title": "Tournament Match Spectated",
			"popup_text": "%s defeated %s with %s." % [
				_bending_person_label(winner),
				_bending_person_label(loser),
				finish_move
			],
			"popup_footer": "Tap anywhere to continue.",
			"settled_count": 1
		}

	return {
		"success": true,
		"uses_scenario_panel": true,
		"spectator_frames": frames,
		"panel_title": "BENDING WORLD CHAMPIONSHIP — SPECTATING",
		"text": str(frames [0].get("text", "")),
		"footer_text": "Spectating live. No input needed.",
		"combat_ui": frames [0].get("combat_ui", {}),
		"opps": frames [0].get("opps", []),
		"popup_title": "Tournament Match Spectated",
		"popup_text": "%s defeated %s with %s." % [
			_bending_person_label(winner),
			_bending_person_label(loser),
			finish_move
		],
		"popup_footer": "Tap anywhere to continue.",
		"match_payload": match_payload.duplicate(true),
		"settled_count": 1
	}
func _grant_bending_world_championship_win_rewards(winner: Person, tournament: Dictionary, context: Dictionary = {}) -> Dictionary:
	if winner == null:
		return {}
	if tournament.is_empty():
		return {}

	var winner_element: String = _bending_person_primary_element(winner)
	if winner_element == "avatar":
		winner_element = _element_from_nation(str(winner.bending_nation))
	if winner_element not in _base_bending_elements():
		return {}

	var title_key: String = _bending_championship_title_key(tournament)
	var title_label: String = _bending_championship_title_label(tournament)
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var completed_wins: int = max(1, _bending_completed_real_wins_for_tournament(winner, tournament))

	var raw_gain: int = 4 + completed_wins * 2
	if title_key == "tournament_of_champions":
		raw_gain += 6
	elif division == "adult":
		raw_gain += 4
	elif division == "masters":
		raw_gain += 3

	var final_match_payload: Dictionary = _safe_dictionary(context.get("match_payload", {}))
	var winner_hp_ratio: float = clamp(float(final_match_payload.get("winner_hp_ratio", 0.6)), 0.0, 1.0)
	if winner_hp_ratio <= 0.25:
		raw_gain += 2
	elif winner_hp_ratio >= 0.75:
		raw_gain += 1

	var progress_reason: String = "winning the %s championship" % title_label
	if title_key == "tournament_of_champions":
		progress_reason = "winning the Tournament of Champions"
	elif division == "adult":
		progress_reason = "winning the Adult World Bending Championship"

	var progress_report: Dictionary = gain_bending_progress(winner, winner_element, raw_gain, progress_reason)

	var point_policy: Dictionary = _safe_dictionary(_bending_progression_policy().get("skill_points", {}))
	var skill_points: int = clamp(
		3 + completed_wins + (3 if title_key == "tournament_of_champions" else 0),
		3,
		max(7, int(point_policy.get("max_duel_award", 7)) + 4)
	)
	var skill_report: Dictionary = award_bending_skill_points(winner, skill_points, "bending_world_championship_reward")

	var willpower_report: Dictionary = {}
	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("apply_willpower_growth"):
		var willpower_gain: float = clamp(
			4.0
			+ float(completed_wins) * 1.35
			+ (4.0 if title_key == "tournament_of_champions" else 0.0)
			+ (2.5 if division == "adult" else 0.0),
			3.0,
			14.0
		)
		willpower_report = gs.willpower_engine.apply_willpower_growth(winner, willpower_gain, {
			"source": "bending_world_championship_win",
			"scope": "bending",
			"reason": progress_reason,
			"title_key": title_key,
			"title_label": title_label,
			"division": division,
			"completed_wins": completed_wins,
			"tournament_id": str(tournament.get("id", ""))
		})
	var agni_kai_report: Dictionary = {}
	if title_key == "agni_kai_unbreakable_fire":
		agni_kai_report = _apply_agni_kai_unbreakable_fire_reward(winner)
	return {
		"schema": "eralife.bending_world_championship_win_reward_report",
		"version": 1,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"title_key": title_key,
		"title_label": title_label,
		"division": division,
		"completed_wins": completed_wins,
		"winner_element": winner_element,
		"raw_gain": raw_gain,
		"skill_points_awarded": skill_points,
		"progress_report": progress_report,
		"skill_report": skill_report,
		"agni_kai_report": agni_kai_report,
		"willpower_report": willpower_report
	}
func _apply_agni_kai_unbreakable_fire_reward(winner: Person) -> Dictionary:
	if winner == null:
		return {}

	ensure_bending_level_state(winner)
	ensure_bending_potential_state(winner)

	var previous_level: int = get_bending_level(winner, "fire")
	var previous_potential: int = get_bending_latent_potential(winner, "fire")

	set_bending_latent_potential(winner, "fire", BENDING_LATENT_POTENTIAL_MAX)
	winner.bending_mastery ["fire"] = BENDING_LATENT_POTENTIAL_MAX

	var profile: Dictionary = ensure_bending_combat_profile(winner)
	var level_xp: Dictionary = _safe_dictionary(profile.get("level_xp", {}))
	level_xp ["fire"] = 0
	profile ["level_xp"] = level_xp
	winner.bending_combat_profile = profile

	return {
		"schema": "eralife.agni_kai_unbreakable_fire_reward_report",
		"version": 1,
		"success": true,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"previous_fire_level": previous_level,
		"previous_fire_potential": previous_potential,
		"new_fire_level": get_bending_level(winner, "fire"),
		"new_fire_potential": get_bending_latent_potential(winner, "fire"),
		"reward": "fire_level_and_potential_maxed"
	}
func advance_bending_world_championship_round(actor: Person, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Agni Kai" if str(options.get("division", "")).strip_edges().to_lower() == "agni_kai" else "Bending World Championship",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var requested_division: String = str(options.get("division", "")).strip_edges().to_lower()
	var division: String = requested_division if requested_division != "" else get_bending_world_championship_division(actor, options)

	if requested_division == "agni_kai" and not _is_agni_kai_eligible(actor):
		return {
			"success": false,
			"popup_title": "Agni Kai Locked",
			"popup_text": "Only fire benders living in the Fire Nation may enter the Agni Kai.",
			"popup_footer": "Tap anywhere to continue."
		}

	if division == "ineligible":
		return {
			"success": false,
			"popup_title": "Tournament Locked",
			"popup_text": "You are not eligible for the Bending World Championship yet.",
			"popup_footer": "Tap anywhere to continue."
		}

	var tournament: Dictionary = _ensure_bending_tournament_for_division(division, actor, {
		"source": str(options.get("source", "advance_bending_world_championship_round")),
		"force_include_actor": true,
		"repair_missing_match": true,
		"faction_fillers_enabled": true,
		"tournament_year": int(options.get("tournament_year", int(gs.year) if gs != null else 0)),
		"participant_cap": int(options.get("participant_cap", 16)),
		"minimum_bracket_size": int(options.get("minimum_bracket_size", 8))
	})
	if tournament.is_empty():
		return {
			"success": false,
			"popup_title": "No Tournament",
			"popup_text": "No active tournament exists yet.",
			"popup_footer": "Tap anywhere to continue."
		}

	var tournament_display_label: String = str(tournament.get("label", _bending_tournament_label(division))).strip_edges()
	if tournament_display_label == "":
		tournament_display_label = "Bending World Championship"

	var continue_button_label: String = "Continue Agni Kai" if division == "agni_kai" else "Continue Bending World Championship"
	var spectator_panel_title: String = "%s — SPECTATING" % tournament_display_label.to_upper()

	var mode: String = str(options.get("mode", "advance_current_round")).strip_edges().to_lower()
	if mode == "spectate_next":
		mode = "spectate_next_live"

	var actor_status: Dictionary = _bending_tournament_actor_status(tournament, actor)
	var actor_status_key: String = str(actor_status.get("status", "none")).strip_edges().to_lower()

	if mode != "spectate_championship" and actor_status_key == "eliminated":
		return {
			"success": false,
			"blocked_by_elimination": true,
			"popup_title": "Tournament Run Over",
			"popup_text": "%s\n\nYou cannot continue fighting in this year's bracket. You can skip ahead to spectate the championship match." % str(actor_status.get("entry_button_label", "You were eliminated from this tournament.")),
			"popup_footer": "Tap anywhere to continue.",
			"tournament": tournament.duplicate(true),
			"actor_status": actor_status.duplicate(true)
		}

	if mode == "spectate_championship":
		return _spectate_bending_tournament_championship_from_elimination(actor, tournament, options)

	var current_round: int = _bending_tournament_current_round(tournament)
	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var settled_count: int = 0
	var spectated_text: String = ""
	var spectator_result: Dictionary = {}
	var tournament_id: String = str(tournament.get("id", ""))
	var actor_id: int = int(actor.id)
	var search_pass_count: int = 2 if mode == "spectate_next_live" else 1

	for search_pass in range(search_pass_count):
		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = raw_match
			if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var match_round: int = int(match_row.get("round", 1))
			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))

			if mode == "spectate_next_live":
				if search_pass == 0 and match_round != current_round:
					continue
				if fighter_a_id == actor_id or fighter_b_id == actor_id:
					continue
				if fighter_a_id <= 0 or fighter_b_id <= 0:
					continue
			else:
				if match_round != current_round:
					continue
				if fighter_a_id == actor_id or fighter_b_id == actor_id:
					continue

			var fighter_a: Person = _find_person_by_id(fighter_a_id)
			var fighter_b: Person = _find_person_by_id(fighter_b_id)

			if fighter_a == null and fighter_b == null:
				if mode == "spectate_next_live":
					continue

				_mark_bending_tournament_match_void(tournament_id, str(match_row.get("match_id", "")))
				settled_count += 1
				spectated_text = "The match was voided because both benders were unavailable."

			elif fighter_a != null and fighter_b == null:
				if mode == "spectate_next_live":
					continue

				_commit_bending_tournament_duel_result(fighter_a, null, {
					"tournament": true,
					"tournament_id": tournament_id,
					"tournament_match_id": str(match_row.get("match_id", "")),
					"simulated": true,
					"bye": true,
					"finish_move": "BYE",
					"source": str(options.get("source", "round_advance"))
				})
				settled_count += 1
				spectated_text = "%s advanced by BYE." % _bending_person_label(fighter_a)

			elif fighter_a == null and fighter_b != null:
				if mode == "spectate_next_live":
					continue

				_commit_bending_tournament_duel_result(fighter_b, null, {
					"tournament": true,
					"tournament_id": tournament_id,
					"tournament_match_id": str(match_row.get("match_id", "")),
					"simulated": true,
					"bye": true,
					"finish_move": "BYE",
					"source": str(options.get("source", "round_advance"))
				})
				settled_count += 1
				spectated_text = "%s advanced by BYE." % _bending_person_label(fighter_b)

			else:
				var live_match: Dictionary = _simulate_bending_tournament_live_match(fighter_a, fighter_b, tournament, match_row, {
					"source": str(options.get("source", "round_advance")),
					"mode": mode
				})

				var winner: Person = _find_person_by_id(int(live_match.get("winner_id", -1)))
				var loser: Person = _find_person_by_id(int(live_match.get("loser_id", -1)))

				if winner == null:
					winner = _pick_bending_tournament_winner(fighter_a, fighter_b, str(tournament.get("division", "")))
				if loser == null:
					loser = fighter_b if winner == fighter_a else fighter_a

				var finish_move: String = str(live_match.get("finish_move", _bending_cpu_finish_move(winner)))

				if mode == "spectate_next_live":
					spectator_result = _build_bending_tournament_spectator_result(
						fighter_a,
						fighter_b,
						winner,
						loser,
						finish_move,
						tournament,
						match_row,
						live_match
					)
					spectator_result ["spectator_frame_seconds"] = clamp(float(options.get("spectator_frame_seconds", 0.85)), 0.12, 3.0)
					spectator_result ["spectator_final_interactive"] = false

				var mercy_action: String = str(live_match.get("mercy_action", "spare")).strip_edges().to_lower()
				var npc_death: bool = bool(live_match.get("death", false)) or mercy_action == "kill"

				record_bending_duel_result(winner, loser, {
					"tournament": true,
					"tournament_id": tournament_id,
					"tournament_match_id": str(match_row.get("match_id", "")),
					"simulated": true,
					"finish_move": finish_move,
					"source": str(options.get("source", "round_advance")),
					"match_payload": live_match.duplicate(true),
					"mercy_action": mercy_action,
					"mercy_decision": _safe_dictionary(live_match.get("mercy_decision", {})),
					"death": npc_death,
					"death_report": _safe_dictionary(live_match.get("death_report", {})),
					"reality_surge_report": _safe_dictionary(live_match.get("reality_surge_report", {})),
					"reality_surge_packet": _safe_dictionary(live_match.get("reality_surge_packet", {})),
					"surge_vector": _safe_dictionary(live_match.get("surge_vector", {})),
					"surge_direction": str(live_match.get("surge_direction", "")),
					"surge_origin_id": int(live_match.get("surge_origin_id", -1)),
					"surge_target_id": int(live_match.get("surge_target_id", -1)),
					"surge_vector_mode": str(live_match.get("surge_vector_mode", ""))
				})
				settled_count += 1

				if npc_death:
					spectated_text = "%s defeated %s with %s, then killed them after the match." % [
						_bending_person_label(winner),
						_bending_person_label(loser),
						finish_move
					]
				else:
					spectated_text = "%s defeated %s with %s, then spared them." % [
						_bending_person_label(winner),
						_bending_person_label(loser),
						finish_move
					]

			if mode == "spectate_next_live" and settled_count > 0:
				break

		if mode == "spectate_next_live" and settled_count > 0:
			break

	if settled_count <= 0:
		if mode == "spectate_next_live":
			return {
				"success": true,
				"uses_scenario_panel": true,
				"spectator_frames": [
					{
						"panel_title": spectator_panel_title,
						"text": "No NPC tournament match is ready to spectate right now.\n\nYour own match may be the next unresolved fight, or the bracket is waiting for your result.",
						"footer_text": "Return to the tournament section and start your match.",
						"opps": []
					}
				],
				"spectator_frame_seconds": 0.6,
				"panel_title": spectator_panel_title,
				"text": "No NPC tournament match is ready to spectate right now.",
				"footer_text": "Return to the tournament section and start your match.",
				"popup_title": "No NPC Match Ready",
				"popup_text": "No NPC tournament match is ready to spectate right now.",
				"popup_footer": "Tap anywhere to continue."
			}

		return {
			"success": false,
			"popup_title": "No Matches To Advance",
			"popup_text": "There are no non-player matches ready to resolve in the current tournament round.",
			"popup_footer": "Tap anywhere to continue."
		}

	tournament = _bending_tournament_reload_by_id(tournament_id)
	if tournament.is_empty():
		tournament = _ensure_bending_tournament_for_division(division, actor, {
			"source": "advance_bending_world_championship_round_reload_recover",
			"force_include_actor": true,
			"repair_missing_match": false,
			"faction_fillers_enabled": true,
			"tournament_year": int(options.get("tournament_year", int(gs.year) if gs != null else 0)),
			"participant_cap": int(options.get("participant_cap", 16)),
			"minimum_bracket_size": int(options.get("minimum_bracket_size", 8))
		})

	if _bending_tournament_actor_round_advance_pending(tournament, actor_id):
		tournament = _bending_clear_actor_round_advance_pending(tournament, actor_id)
		tournament = _save_bending_tournament_state(tournament)

	actor_status = _bending_tournament_actor_status(tournament, actor)
	actor_status_key = str(actor_status.get("status", "none")).strip_edges().to_lower()

	if mode == "spectate_next_live":
		if not spectator_result.is_empty():
			spectator_result ["actor_status"] = actor_status.duplicate(true)
			spectator_result ["tournament"] = tournament.duplicate(true)
			return spectator_result
		return {
			"success": true,
			"uses_scenario_panel": true,
			"spectator_frames": [
				{
					"panel_title": spectator_panel_title,
					"text": spectated_text,
					"footer_text": "Spectated match complete.",
					"opps": []
				}
			],
			"spectator_frame_seconds": 0.6,
			"popup_title": "Tournament Match Spectated",
			"popup_text": spectated_text,
			"popup_footer": "Tap anywhere to continue.",
			"settled_count": settled_count,
			"actor_status": actor_status.duplicate(true),
			"tournament": tournament.duplicate(true)
		}

	var next_line: String = ""
	if str(actor_status.get("status", "")).strip_edges().to_lower() == "match_ready":
		next_line = "\n\nYour next match is ready. Hit %s." % continue_button_label
	elif str(actor_status.get("status", "")).strip_edges().to_lower() == "champion":
		next_line = "\n\nYou are the champion."
	elif str(actor_status.get("status", "")).strip_edges().to_lower() == "eliminated":
		next_line = "\n\nYour tournament run is already over."

	return {
		"success": true,
		"popup_title": "Tournament Round Advanced",
		"popup_text": "Resolved %d non-player match%s in the current round.%s" % [
			settled_count,
			"" if settled_count == 1 else "es",
			next_line
		],
		"popup_footer": "Tap anywhere to continue.",
		"settled_count": settled_count,
		"actor_status": actor_status.duplicate(true),
		"tournament": tournament.duplicate(true)
	}


func _bending_cpu_finish_move(winner: Person) -> String:
	var element: String = _bending_person_primary_element(winner)
	if element == "avatar":
		element = _element_from_nation(str(winner.bending_nation))
	if element == "":
		element = "bending"

	match element:
		"air":
			return "Cyclone Ring"
		"water":
			return "Moon-Tide Counter"
		"earth":
			return "Stone Lotus Crush"
		"fire":
			return "Sunfire Break"
		_:
			return "World Stage Finisher"
func _ensure_bending_tournament_for_division(division: String, actor: Person, options: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	var year_value: int = int(options.get("tournament_year", int(gs.year) if gs != null else 0))
	var requested_division: String = str(division).strip_edges().to_lower()
	var runtime_division: String = _bending_runtime_tournament_division(requested_division, year_value)
	var tournament_id: String = _bending_tournament_id_for_division(requested_division, year_value)

	if tournaments.has(tournament_id):
		var existing: Dictionary = _safe_dictionary(tournaments.get(tournament_id, {}))
		if actor != null and bool(options.get("repair_missing_match", false)):
			var repair_gate_options: Dictionary = options.duplicate(true)
			repair_gate_options ["tournament"] = existing.duplicate(true)
			repair_gate_options ["tournament_id"] = tournament_id
			repair_gate_options ["tournament_year"] = year_value
			var repair_gate: Dictionary = _bending_player_tournament_entry_gate(actor, requested_division, repair_gate_options)
			if bool(repair_gate.get("allowed", true)):
				existing = _register_bending_tournament_entry(existing, actor)
				existing = _repair_bending_tournament_for_actor_match(existing, actor)
		tournaments [tournament_id] = existing
		state ["tournaments"] = tournaments
		gs.scenario_state ["bending_world_championship"] = state
		return existing

	var policy: Dictionary = _bending_world_policy()
	var participant_cap: int = clamp(int(policy.get("participant_cap", 16)), 8, 16)
	if requested_division == "agni_kai":
		participant_cap = max(50, int(options.get("participant_cap", 50)))

	var participants: Array = []
	var force_include_actor: bool = bool(options.get("force_include_actor", actor != null))
	var eligible_options: Dictionary = options.duplicate(true)
	if force_include_actor:
		eligible_options ["force_include_actor"] = true

	if runtime_division == "masters":
		participants = _bending_tournament_of_champions_participants(year_value, eligible_options)
		if participants.is_empty():
			var adult_eligible: Array = _eligible_benders_for_division("adult", eligible_options)
			var masters_cap: int = min(5, adult_eligible.size())
			for i in range(masters_cap):
				var master_entrant: Person = adult_eligible [i]
				participants.append(_bending_tournament_participant_payload(master_entrant, i + 1))
	else:
		var eligible: Array = _eligible_benders_for_division(runtime_division, eligible_options)
		var cap_count: int = min(participant_cap, eligible.size())
		for i in range(cap_count):
			var entrant: Person = eligible [i]
			participants.append(_bending_tournament_participant_payload(entrant, i + 1))

	if force_include_actor and actor != null:
		var actor_included: bool = false
		for raw_row in participants:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			if int(row.get("person_id", -1)) == int(actor.id):
				actor_included = true
				break
		if not actor_included:
			participants.append(_bending_tournament_participant_payload(actor, participants.size() + 1))

	var minimum_bracket_size: int = int(options.get("minimum_bracket_size", 8))
	if runtime_division == "agni_kai":
		minimum_bracket_size = max(50, minimum_bracket_size)
	elif runtime_division in ["youth", "adult", "elder_male", "elder_female"]:
		minimum_bracket_size = max(16, minimum_bracket_size)
	elif runtime_division == "masters":
		minimum_bracket_size = max(4, minimum_bracket_size)

	while participants.size() < minimum_bracket_size:
		var anchor_for_depth: Person = actor
		if anchor_for_depth == null and not participants.is_empty():
			anchor_for_depth = _find_person_by_id(int(participants [0].get("person_id", -1)))
		var depth_filler: Person = _resolve_bending_tournament_filler(anchor_for_depth, runtime_division, _participant_id_lookup(participants))
		if depth_filler == null:
			break
		participants.append(_bending_tournament_participant_payload(depth_filler, participants.size() + 1))

	while participants.size() < 2 and actor != null:
		var emergency_filler: Person = _resolve_bending_tournament_filler(actor, runtime_division, _participant_id_lookup(participants))
		if emergency_filler == null:
			break
		participants.append(_bending_tournament_participant_payload(emergency_filler, participants.size() + 1))

	if participants.size() > 8 and runtime_division != "agni_kai":
		while participants.size() < 16:
			var anchor: Person = actor
			if anchor == null and not participants.is_empty():
				anchor = _find_person_by_id(int(participants [0].get("person_id", -1)))
			var bracket_filler: Person = _resolve_bending_tournament_filler(anchor, runtime_division, _participant_id_lookup(participants))
			if bracket_filler == null:
				break

			participants.append(_bending_tournament_participant_payload(bracket_filler, participants.size() + 1))

		if participants.size() > 16:
			participants = participants.slice(0, 16)

	if participants.size() % 2 != 0:
		var anchor_even: Person = actor
		if anchor_even == null and not participants.is_empty():
			anchor_even = _find_person_by_id(int(participants [0].get("person_id", -1)))
		var bye_filler: Person = _resolve_bending_tournament_filler(anchor_even, runtime_division, _participant_id_lookup(participants))
		if bye_filler != null:
			participants.append(_bending_tournament_participant_payload(bye_filler, participants.size() + 1))

	if participants.size() < 2:
		return {}

	var play_in_enabled: bool = false
	var _main_bye_count: int = 0
	var main_seed_byes: Array = []

	var bracket: Array = _build_bending_tournament_bracket(participants)
	var tournament: Dictionary = {
		"schema": "eralife.bending_world_championship_tournament",
		"version": 6,
		"id": tournament_id,
		"year": year_value,
		"division": runtime_division,
		"requested_division": requested_division,
		"label": _bending_tournament_label(runtime_division),
		"participants": participants,
		"main_seed_byes": main_seed_byes,
		"play_in_enabled": play_in_enabled,
		"bracket": bracket,
		"status": "active",
		"champion_id": -1,
		"champion_name": "",
		"entered_actor_ids": [],
		"created_at_ms": int(Time.get_ticks_msec()),
		"source": str(options.get("source", "bending_engine")),
		"contract": {
			"participant_cap": participant_cap,
			"fight_count_main_seed": 4,
			"fight_count_low_seed": 4,
			"main_bracket_size": 16,
			"play_in_target_participant_count": 16,
			"play_in_enabled": play_in_enabled,
			"faction_fillers_enabled": true,
		}
	}

	if actor != null:
		tournament = _register_bending_tournament_entry(tournament, actor)
		tournament = _repair_bending_tournament_for_actor_match(tournament, actor)

	tournaments [tournament_id] = tournament
	state ["tournaments"] = tournaments
	gs.scenario_state ["bending_world_championship"] = state
	return tournament
func _bending_tournament_participant_payload(actor: Person, bracket_seed: int) -> Dictionary:
	var style_identity: Dictionary = get_competitive_style_identity(actor, {
		"source": "tournament_participant_payload"
	})

	return {
		"person_id": int(actor.id),
		"name": _bending_person_label(actor),
		"seed": int(bracket_seed),
		"bloodline": str(actor.last_name).strip_edges(),
		"faction": _bending_world_faction_for_actor(actor),
		"element": _bending_person_primary_element(actor),
		"style_identity": style_identity.duplicate(true),
		"dynasty_title": _bending_best_dynasty_title_for_actor(actor)
	}


func _bending_world_faction_for_actor(actor: Person) -> String:
	if actor == null:
		return "Unknown Faction"

	var nation: String = str(actor.bending_nation).strip_edges()
	if nation != "":
		return nation

	var element: String = _bending_person_primary_element(actor)
	return _nation_from_element(element)


func _bending_best_dynasty_title_for_actor(actor: Person) -> String:
	if actor == null:
		return ""

	var bloodline_key: String = str(actor.last_name).strip_edges()
	if bloodline_key == "":
		return ""

	var state: Dictionary = _bending_world_state()
	var dynasties: Dictionary = state.get("dynasty_records", {})
	var row: Dictionary = dynasties.get(bloodline_key, {})
	if row.is_empty():
		return ""

	var titles_by_tournament: Dictionary = _safe_dictionary(row.get("titles_by_tournament", {}))
	if not titles_by_tournament.is_empty():
		var best_title_key: String = ""
		var best_count: int = 0

		for raw_key in titles_by_tournament.keys():
			var title_key: String = str(raw_key)
			var count: int = int(titles_by_tournament.get(title_key, 0))
			if count > best_count:
				best_count = count
				best_title_key = title_key

		if best_title_key != "":
			return "%s X%d" % [
				_bending_championship_title_label_from_key(best_title_key),
				best_count
			]

	var titles_raw: Variant = row.get("titles_by_faction", {})
	var titles: Dictionary = titles_raw if typeof(titles_raw) == TYPE_DICTIONARY else {}
	if titles.is_empty():
		return ""

	var best_title: String = ""
	var best_faction_count: int = 0

	for raw_key in titles.keys():
		var faction: String = str(raw_key)
		var count: int = int(titles.get(faction, 0))
		if count > best_faction_count:
			best_faction_count = count
			best_title = "%dx Champion of %s" % [count, faction]

	return best_title

func _build_bending_tournament_bracket(participants: Array) -> Array:
	var bracket: Array = []
	if participants.is_empty():
		return bracket

	var use_play_in: bool = participants.size() > 8 and participants.size() <= 12
	if use_play_in:
		var main_bye_count: int = _bending_tournament_main_bye_count(participants.size())
		var low_seed_rows: Array = participants.slice(main_bye_count, participants.size())
		var pair_count: int = int(floor(float(low_seed_rows.size()) / 2.0))
		for i in range(pair_count):
			var left: Dictionary = low_seed_rows [i]
			var right: Dictionary = low_seed_rows [low_seed_rows.size() - 1 - i]
			bracket.append({
				"match_id": "r0_m%d" % [i + 1],
				"round": 0,
				"round_label": "Play-In Qualifier",
				"status": "pending",
				"play_in": true,
				"qualifier_slot": i + 1,
				"fighter_a_id": int(left.get("person_id", -1)),
				"fighter_a_name": str(left.get("name", "BYE")),
				"fighter_a_seed": int(left.get("seed", 999)),
				"fighter_b_id": int(right.get("person_id", -1)),
				"fighter_b_name": str(right.get("name", "BYE")),
				"fighter_b_seed": int(right.get("seed", 999)),
				"winner_id": -1,
				"winner_name": "",
				"winner_seed": 999,
				"finish_move": ""
			})
		return bracket

	var round_index: int = 1
	var match_index: int = 1
	var i: int = 0
	while i < participants.size():
		var left_main: Dictionary = participants [i]
		var right_main: Dictionary = participants [i + 1] if i + 1 < participants.size() else {}
		bracket.append({
			"match_id": "r%d_m%d" % [round_index, match_index],
			"round": round_index,
			"round_label": _bending_tournament_round_label(round_index, participants.size()),
			"status": "pending",
			"play_in": false,
			"fighter_a_id": int(left_main.get("person_id", -1)),
			"fighter_a_name": str(left_main.get("name", "BYE")),
			"fighter_a_seed": int(left_main.get("seed", 999)),
			"fighter_b_id": int(right_main.get("person_id", -1)),
			"fighter_b_name": str(right_main.get("name", "BYE")),
			"fighter_b_seed": int(right_main.get("seed", 999)),
			"winner_id": -1,
			"winner_name": "",
			"winner_seed": 999,
			"finish_move": ""
		})
		match_index += 1
		i += 2
	return bracket
func _bending_tournament_main_bye_count(participant_count: int) -> int:
	if participant_count <= 8:
		return 0
	return clamp(16 - int(participant_count), 0, 8)


func _bending_tournament_round_label(round_value: int, field_size: int = 8) -> String:
	var clean_field_size: int = max(2, int(field_size))
	if round_value <= 0:
		return "Play-In Qualifier"
	if clean_field_size > 8:
		return "Round of %d" % clean_field_size
	if clean_field_size > 4:
		return "Quarterfinal"
	if clean_field_size > 2:
		return "Semifinal"
	return "Championship Final"
func _bending_tournament_field_size_for_round(tournament: Dictionary, round_value: int) -> int:
	if tournament.is_empty():
		return 8

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var participant_ids: Dictionary = {}

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if int(match_row.get("round", 1)) != int(round_value):
			continue

		var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
		var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))

		if fighter_a_id > 0:
			participant_ids [fighter_a_id] = true
		if fighter_b_id > 0:
			participant_ids [fighter_b_id] = true

	if participant_ids.size() > 0:
		return max(2, participant_ids.size())

	var participants: Array = _safe_array(tournament.get("participants", []))
	return max(2, participants.size())


func _bending_tournament_stage_label(tournament: Dictionary, round_value: int = -999999) -> String:
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var base_label: String = "Bending World Tournament"

	match division:
		"youth":
			base_label = "Youth Bending World Tournament"
		"adult":
			base_label = "Adult Bending World Tournament"
		"elder_male":
			base_label = "Elder Men's Bending World Tournament"
		"elder_female":
			base_label = "Elder Women's Bending World Tournament"
		"elder_open":
			base_label = "Elder Open Bending World Tournament"
		"masters":
			base_label = "Tournament of Champions"
		"agni_kai":
			base_label = "Agni Kai Tournament of Unbreakable Fire"

	var resolved_round: int = int(round_value)
	if resolved_round == -999999:
		resolved_round = _bending_tournament_current_round(tournament)

	var field_size: int = _bending_tournament_field_size_for_round(tournament, resolved_round)
	var round_label: String = _bending_tournament_round_label(resolved_round, field_size)

	if round_label == "Championship Final":
		match division:
			"adult":
				return "Adult Bending World Championship Final"
			"youth":
				return "Youth Bending World Championship Final"
			"elder_male":
				return "Elder Men's Bending World Championship Final"
			"elder_female":
				return "Elder Women's Bending World Championship Final"
			"elder_open":
				return "Elder Open Bending World Championship Final"
			"masters":
				return "Tournament of Champions Final"
			"agni_kai":
				return "Agni Kai Championship Final"
			_:
				return "Bending World Championship Final"

	return "%s • %s" % [base_label, round_label]


func _bending_tournament_current_round(tournament: Dictionary) -> int:
	var bracket: Array = tournament.get("bracket", [])
	var found_pending: bool = false
	var current_round: int = 999999

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
			continue

		found_pending = true
		current_round = min(current_round, int(match_row.get("round", 1)))

	if found_pending:
		return current_round

	return int(tournament.get("completed_round", 1))


func _bending_tournament_round_has_pending(tournament: Dictionary, round_value: int) -> bool:
	var bracket: Array = tournament.get("bracket", [])

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if int(match_row.get("round", 1)) != round_value:
			continue
		if str(match_row.get("status", "pending")).strip_edges().to_lower() == "pending":
			return true

	return false


func _bending_tournament_has_round(tournament: Dictionary, round_value: int) -> bool:
	var bracket: Array = tournament.get("bracket", [])

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if int(match_row.get("round", 1)) == round_value:
			return true

	return false


func _bending_tournament_winners_for_round(tournament: Dictionary, round_value: int) -> Array:
	var out: Array = []
	var bracket: Array = tournament.get("bracket", [])

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if int(match_row.get("round", 1)) != round_value:
			continue

		var winner_id: int = int(match_row.get("winner_id", -1))
		if winner_id <= 0:
			continue

		out.append({
			"person_id": winner_id,
			"name": str(match_row.get("winner_name", "")),
			"seed": int(match_row.get("winner_seed", 999))
		})

	return out

func _bending_tournament_actor_elimination_status(tournament: Dictionary, actor_id: int) -> Dictionary:
	if actor_id <= 0 or tournament.is_empty():
		return {}

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var eliminated_status: Dictionary = {}

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "pending")).strip_edges().to_lower() == "pending":
			continue

		var loser_id: int = int(match_row.get("loser_id", -1))
		if loser_id != actor_id:
			continue

		var winner_id: int = int(match_row.get("winner_id", -1))
		if winner_id <= 0:
			continue

		var match_round: int = int(match_row.get("round", 1))
		var match_field_size: int = _bending_tournament_field_size_for_round(tournament, match_round)
		var match_round_label: String = str(match_row.get("round_label", _bending_tournament_round_label(match_round, match_field_size)))
		var match_stage_label: String = _bending_tournament_stage_label(tournament, match_round)
		var finish_move: String = str(match_row.get("finish_move", "an unknown finishing move")).strip_edges()
		if finish_move == "":
			finish_move = "an unknown finishing move"

		var winner_name: String = str(match_row.get("winner_name", "Unknown")).strip_edges()
		if winner_name == "":
			winner_name = "Unknown"

		var winner_seed: int = int(match_row.get("winner_seed", 999))
		var seed_label: String = ""
		if winner_seed > 0 and winner_seed < 999:
			seed_label = " (Seed #%d)" % winner_seed

		var full_winner_label: String = "%s%s" % [winner_name, seed_label]

		if eliminated_status.is_empty() or match_round > int(eliminated_status.get("round", -999999)):
			eliminated_status = {
				"status": "eliminated",
				"round": match_round,
				"round_label": match_round_label,
				"stage_label": match_stage_label,
				"winner_id": winner_id,
				"winner_name": winner_name,
				"winner_seed": winner_seed,
				"winner_label": full_winner_label,
				"eliminated_by_id": winner_id,
				"eliminated_by_name": winner_name,
				"eliminated_by_seed": winner_seed,
				"finish_move": finish_move,
				"entry_button_label": "You lost in %s by a %s from %s" % [
					match_round_label,
					finish_move,
					full_winner_label
				],
				"entry_button_disabled": true,
				"entry_button_tooltip": "You were eliminated from this year's bracket. You can spectate the championship, but you cannot continue fighting until next year."
			}

	return eliminated_status
func _bending_tournament_actor_round_advance_pending(
	tournament: Dictionary,
	actor_id: int
) -> bool:
	if actor_id <= 0 or tournament.is_empty():
		return false

	if not bool(
		tournament.get(
			"player_round_advance_pending",
			false
		)
	):
		return false

	if int(
		tournament.get(
			"player_round_advance_pending_actor_id",
			-1
		)
	) != actor_id:
		return false




	var ready_match: Dictionary = (
		_bending_pending_actor_tournament_match(
			tournament,
			actor_id,
			false
		)
	)

	if not ready_match.is_empty():
		return false

	return true

func _bending_mark_actor_round_advance_pending(
	tournament: Dictionary,
	actor_id: int,
	completed_round: int
) -> Dictionary:
	var out: Dictionary = tournament.duplicate(true)

	if actor_id <= 0:
		return out

	if str(
		out.get(
			"status",
			""
		)
	).strip_edges().to_lower() == "complete":
		return out




	var ready_match: Dictionary = (
		_bending_pending_actor_tournament_match(
			out,
			actor_id,
			false
		)
	)

	if not ready_match.is_empty():
		out ["player_round_advance_pending"] = false
		out ["player_round_advance_pending_actor_id"] = -1
		out ["player_round_advance_from_round"] = -999999
		out ["player_round_advance_next_round"] = -999999
		out ["player_round_advance_suppressed_by_ready_match"] = true
		out ["player_round_advance_ready_match_id"] = str(
			ready_match.get(
				"match_id",
				""
			)
		)
		return out

	out ["player_round_advance_pending"] = true
	out ["player_round_advance_pending_actor_id"] = actor_id
	out ["player_round_advance_from_round"] = completed_round
	out ["player_round_advance_next_round"] = completed_round + 1
	out ["player_round_advance_created_at_ms"] = int(
		Time.get_ticks_msec()
	)

	return out


func _bending_clear_actor_round_advance_pending(tournament: Dictionary, actor_id: int) -> Dictionary:
	var out: Dictionary = tournament.duplicate(true)
	if actor_id <= 0:
		return out

	if int(out.get("player_round_advance_pending_actor_id", -1)) != actor_id:
		return out

	out ["player_round_advance_pending"] = false
	out ["player_round_advance_pending_actor_id"] = -1
	out ["player_round_advance_from_round"] = -999999
	out ["player_round_advance_next_round"] = -999999
	out ["player_round_advance_cleared_at_ms"] = int(Time.get_ticks_msec())
	return out


func _save_bending_tournament_state(tournament: Dictionary) -> Dictionary:
	if gs == null or tournament.is_empty():
		return tournament

	var tournament_id: String = str(tournament.get("id", "")).strip_edges()
	if tournament_id == "":
		return tournament

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = _safe_dictionary(state.get("tournaments", {}))
	tournaments [tournament_id] = tournament.duplicate(true)
	state ["tournaments"] = tournaments
	_commit_bending_world_state(state)
	return tournament
func _bending_tournament_actor_status(tournament: Dictionary, actor: Person) -> Dictionary:
	if actor == null or tournament.is_empty():
		return {
			"status": "none",
			"entry_button_label": "Enter Bending World Championship"
		}

	var actor_id: int = int(actor.id)
	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var entered: Array = _safe_array(tournament.get("entered_actor_ids", []))
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var current_round: int = _bending_tournament_current_round(tournament)
	var current_field_size: int = _bending_tournament_field_size_for_round(tournament, current_round)
	var current_round_label: String = _bending_tournament_round_label(current_round, current_field_size)
	var current_stage_label: String = _bending_tournament_stage_label(tournament, current_round)
	var latest_completed_round: int = _bending_tournament_actor_completed_round(tournament, actor_id)
	var wait_label: String = "Waiting on next Agni Kai tournament round" if division == "agni_kai" else "Waiting on next tournament round"

	if int(tournament.get("champion_id", -1)) == actor_id:
		return {
			"status": "champion",
			"round": current_round,
			"round_label": current_round_label,
			"stage_label": current_stage_label,
			"entry_button_label": "You already won the Agni Kai" if division == "agni_kai" else "You already won the Bending World Championship",
			"entry_button_disabled": true
		}

	var eliminated_status: Dictionary = _bending_tournament_actor_elimination_status(tournament, actor_id)
	if not eliminated_status.is_empty():
		return eliminated_status

	if _bending_tournament_actor_round_advance_pending(tournament, actor_id):
		return {
			"status": "advanced",
			"round": int(tournament.get("player_round_advance_from_round", latest_completed_round)),
			"round_label": current_round_label,
			"stage_label": current_stage_label,
			"entry_button_label": wait_label,
			"entry_button_disabled": true,
		}

	if latest_completed_round >= current_round and _bending_tournament_round_has_pending(tournament, current_round):
		return {
			"status": "advanced",
			"round": current_round,
			"round_label": current_round_label,
			"stage_label": current_stage_label,
			"entry_button_label": wait_label,
			"entry_button_disabled": true
		}

	var ready_match: Dictionary = _bending_pending_actor_tournament_match(tournament, actor_id, true)
	var advanced_status: Dictionary = {}

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
		var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
		var winner_id: int = int(match_row.get("winner_id", -1))
		var loser_id: int = int(match_row.get("loser_id", -1))
		var match_status: String = str(match_row.get("status", "pending")).strip_edges().to_lower()
		var match_round: int = int(match_row.get("round", 1))
		var match_field_size: int = _bending_tournament_field_size_for_round(tournament, match_round)
		var match_round_label: String = str(match_row.get("round_label", _bending_tournament_round_label(match_round, match_field_size)))
		var match_stage_label: String = _bending_tournament_stage_label(tournament, match_round)

		var actor_in_match: bool = (
			fighter_a_id == actor_id
			or fighter_b_id == actor_id
			or loser_id == actor_id
			or winner_id == actor_id
		)
		if not actor_in_match:
			continue

		if match_status == "pending":
			continue

		if winner_id == actor_id:
			if advanced_status.is_empty() or match_round > int(advanced_status.get("round", -999999)):
				advanced_status = {
					"status": "advanced",
					"round": match_round,
					"round_label": match_round_label,
					"stage_label": match_stage_label,
					"entry_button_label": wait_label,
					"entry_button_disabled": true
				}

	if not ready_match.is_empty():
		var ready_round: int = int(ready_match.get("round", 1))
		var ready_field_size: int = _bending_tournament_field_size_for_round(tournament, ready_round)
		var ready_round_label: String = str(ready_match.get("round_label", _bending_tournament_round_label(ready_round, ready_field_size)))
		var ready_stage_label: String = _bending_tournament_stage_label(tournament, ready_round)

		return {
			"status": "match_ready",
			"round": ready_round,
			"round_label": ready_round_label,
			"stage_label": ready_stage_label,
			"match_id": str(ready_match.get("match_id", "")),
			"entry_button_label": "Continue Agni Kai" if division == "agni_kai" else "Continue %s" % ready_stage_label,
			"entry_button_disabled": false
		}

	if not advanced_status.is_empty():
		return advanced_status

	if actor_id in entered:
		return {
			"status": "entered_waiting",
			"round": current_round,
			"round_label": current_round_label,
			"stage_label": current_stage_label,
			"entry_button_label": "Waiting on Agni Kai tournament round" if division == "agni_kai" else "Waiting on tournament round",
			"entry_button_disabled": true
		}

	return {
		"status": "not_entered",
		"round": current_round,
		"round_label": current_round_label,
		"stage_label": current_stage_label,
		"entry_button_label": "Enter the Agni Kai" if division == "agni_kai" else "Enter Bending World Championship as %s" % str(actor.first_name),
		"entry_button_disabled": false
	}
func _bending_finish_move_from_context(context: Dictionary) -> String:
	var direct_move: String = str(context.get("finish_move", "")).strip_edges()
	if direct_move != "":
		return direct_move

	var duel: Dictionary = context.get("duel", {})
	if typeof(duel) == TYPE_DICTIONARY:
		var stored_player_move: String = str(duel.get("last_player_move_name", duel.get("last_player_move", ""))).strip_edges()
		if stored_player_move != "":
			return stored_player_move

		var pending_attack: Dictionary = duel.get("pending_player_attack", {})
		if typeof(pending_attack) == TYPE_DICTIONARY:
			var player_move_name: String = str(pending_attack.get("name", pending_attack.get("ability_name", ""))).strip_edges()
			if player_move_name != "":
				return player_move_name

		var allow_enemy_finish_move: bool = bool(context.get("allow_enemy_finish_move", false))
		if allow_enemy_finish_move:
			var last_enemy_move: Dictionary = duel.get("last_enemy_move", {})
			if typeof(last_enemy_move) == TYPE_DICTIONARY:
				var enemy_move_name: String = str(last_enemy_move.get("name", "")).strip_edges()
				if enemy_move_name != "":
					return enemy_move_name

	return "a finishing technique"
func _bending_tournament_actor_completed_round(tournament: Dictionary, actor_id: int) -> int:
	if actor_id <= 0 or tournament.is_empty():
		return -999999

	var latest_round: int = -999999
	var bracket: Array = _safe_array(tournament.get("bracket", []))

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "pending")).strip_edges().to_lower() == "pending":
			continue

		var winner_id: int = int(match_row.get("winner_id", -1))
		var loser_id: int = int(match_row.get("loser_id", -1))
		if winner_id == actor_id or loser_id == actor_id:
			latest_round = max(latest_round, int(match_row.get("round", 1)))

	return latest_round


func _bending_tournament_actor_opponent_blocklist(tournament: Dictionary, actor_id: int) -> Dictionary:
	var out: Dictionary = {}
	if actor_id <= 0 or tournament.is_empty():
		return out

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "pending")).strip_edges().to_lower() == "pending":
			continue

		var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
		var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
		var winner_id: int = int(match_row.get("winner_id", -1))
		var loser_id: int = int(match_row.get("loser_id", -1))

		var actor_in_match: bool = (
			fighter_a_id == actor_id
			or fighter_b_id == actor_id
			or winner_id == actor_id
			or loser_id == actor_id
		)
		if not actor_in_match:
			continue

		for candidate_id in [fighter_a_id, fighter_b_id, winner_id, loser_id]:
			var clean_id: int = int(candidate_id)
			if clean_id > 0 and clean_id != actor_id:
				out [clean_id] = true

	return out


func _bending_tournament_actor_is_dead_or_unavailable(tournament: Dictionary, actor_id: int) -> bool:
	if actor_id <= 0:
		return true

	var dead_ids_raw: Variant = tournament.get("dead_actor_ids", [])
	var dead_ids: Array = dead_ids_raw if typeof(dead_ids_raw) == TYPE_ARRAY else []
	if actor_id in dead_ids:
		return true

	var actor: Person = _find_person_by_id(actor_id)
	if actor == null:
		return true

	return not bool(actor.alive)
func _bending_pending_actor_tournament_match(tournament: Dictionary, actor_id: int, prefer_current_round: bool = true) -> Dictionary:
	if actor_id <= 0 or tournament.is_empty():
		return {}

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var current_round: int = _bending_tournament_current_round(tournament)
	var latest_completed_round: int = _bending_tournament_actor_completed_round(tournament, actor_id)
	var blocked_opponents: Dictionary = _bending_tournament_actor_opponent_blocklist(tournament, actor_id)

	if prefer_current_round:
		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var current_match: Dictionary = raw_match
			var match_round: int = int(current_match.get("round", 1))
			if match_round != current_round:
				continue
			if match_round <= latest_completed_round:
				continue
			if str(current_match.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var current_a_id: int = int(current_match.get("fighter_a_id", -1))
			var current_b_id: int = int(current_match.get("fighter_b_id", -1))

			if current_a_id == actor_id and current_b_id > 0:
				if blocked_opponents.has(current_b_id) or _bending_tournament_actor_is_dead_or_unavailable(tournament, current_b_id):
					continue
				current_match ["opponent_id"] = current_b_id
				return current_match.duplicate(true)

			if current_b_id == actor_id and current_a_id > 0:
				if blocked_opponents.has(current_a_id) or _bending_tournament_actor_is_dead_or_unavailable(tournament, current_a_id):
					continue
				current_match ["opponent_id"] = current_a_id
				return current_match.duplicate(true)

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var pending_match: Dictionary = raw_match
		var pending_round: int = int(pending_match.get("round", 1))
		if pending_round <= latest_completed_round:
			continue
		if str(pending_match.get("status", "pending")).strip_edges().to_lower() != "pending":
			continue

		var pending_a_id: int = int(pending_match.get("fighter_a_id", -1))
		var pending_b_id: int = int(pending_match.get("fighter_b_id", -1))

		if pending_a_id == actor_id and pending_b_id > 0:
			if blocked_opponents.has(pending_b_id) or _bending_tournament_actor_is_dead_or_unavailable(tournament, pending_b_id):
				continue
			pending_match ["opponent_id"] = pending_b_id
			return pending_match.duplicate(true)

		if pending_b_id == actor_id and pending_a_id > 0:
			if blocked_opponents.has(pending_a_id) or _bending_tournament_actor_is_dead_or_unavailable(tournament, pending_a_id):
				continue
			pending_match ["opponent_id"] = pending_a_id
			return pending_match.duplicate(true)

	return {}


func _bending_tournament_actor_is_in_live_bracket(tournament: Dictionary, actor_id: int) -> bool:
	if actor_id <= 0 or tournament.is_empty():
		return false

	var bracket: Array = _safe_array(tournament.get("bracket", []))
	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if int(match_row.get("fighter_a_id", -1)) == actor_id:
			return true
		if int(match_row.get("fighter_b_id", -1)) == actor_id:
			return true

	return false


func _bending_force_player_tournament_match_now(tournament: Dictionary, actor: Person) -> Dictionary:
	if actor == null or tournament.is_empty():
		return tournament

	var out: Dictionary = tournament.duplicate(true)
	if str(out.get("status", "")).strip_edges().to_lower() == "complete":
		return out

	var tournament_id: String = str(out.get("id", "")).strip_edges()
	var actor_id: int = int(actor.id)
	var bracket: Array = _safe_array(out.get("bracket", []))
	var participants: Array = _safe_array(out.get("participants", []))
	var current_round: int = _bending_tournament_current_round(out)
	var latest_completed_round: int = _bending_tournament_actor_completed_round(out, actor_id)
	if latest_completed_round >= current_round:
		return out

	var division: String = str(out.get("division", "")).strip_edges().to_lower()

	var actor_row: Dictionary = {}
	for raw_participant in participants:
		if typeof(raw_participant) != TYPE_DICTIONARY:
			continue

		var participant: Dictionary = raw_participant
		if int(participant.get("person_id", -1)) == actor_id:
			actor_row = participant.duplicate(true)
			break

	if actor_row.is_empty():
		actor_row = _bending_tournament_participant_payload(actor, participants.size() + 1)
		participants.append(actor_row)
		out ["participants"] = participants

	var occupied_ids: Dictionary = _participant_id_lookup(participants)
	var blocked_opponents: Dictionary = _bending_tournament_actor_opponent_blocklist(out, actor_id)
	for blocked_id in blocked_opponents.keys():
		occupied_ids [int(blocked_id)] = true

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var seeded_match: Dictionary = raw_match
		var seeded_a_id: int = int(seeded_match.get("fighter_a_id", -1))
		var seeded_b_id: int = int(seeded_match.get("fighter_b_id", -1))

		if seeded_a_id > 0:
			occupied_ids [seeded_a_id] = true
		if seeded_b_id > 0:
			occupied_ids [seeded_b_id] = true

	for pass_index in range(2):
		for i in range(bracket.size()):
			if typeof(bracket [i]) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = bracket [i].duplicate(true)
			if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue
			if pass_index == 0 and int(match_row.get("round", 1)) != current_round:
				continue

			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))

			if fighter_a_id == actor_id and fighter_b_id <= 0:
				var filler_b: Person = _resolve_bending_tournament_filler(actor, division, occupied_ids)
				if filler_b == null:
					continue

				var filler_b_row: Dictionary = _bending_tournament_participant_payload(filler_b, participants.size() + 1)
				participants.append(filler_b_row)
				occupied_ids [int(filler_b.id)] = true

				match_row ["fighter_b_id"] = int(filler_b.id)
				match_row ["fighter_b_name"] = _bending_person_label(filler_b)
				match_row ["fighter_b_seed"] = int(filler_b_row.get("seed", participants.size()))
				match_row ["opponent_id"] = int(filler_b.id)

				bracket [i] = match_row
				out ["participants"] = participants
				out ["bracket"] = bracket
				_save_bending_tournament(out)
				return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

			if fighter_b_id == actor_id and fighter_a_id <= 0:
				var filler_a: Person = _resolve_bending_tournament_filler(actor, division, occupied_ids)
				if filler_a == null:
					continue

				var filler_a_row: Dictionary = _bending_tournament_participant_payload(filler_a, participants.size() + 1)
				participants.append(filler_a_row)
				occupied_ids [int(filler_a.id)] = true

				match_row ["fighter_a_id"] = int(filler_a.id)
				match_row ["fighter_a_name"] = _bending_person_label(filler_a)
				match_row ["fighter_a_seed"] = int(filler_a_row.get("seed", participants.size()))
				match_row ["opponent_id"] = int(filler_a.id)

				bracket [i] = match_row
				out ["participants"] = participants
				out ["bracket"] = bracket
				_save_bending_tournament(out)
				return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	if not _bending_tournament_actor_is_in_live_bracket(out, actor_id):
		for i in range(bracket.size()):
			if typeof(bracket [i]) != TYPE_DICTIONARY:
				continue

			var open_match: Dictionary = bracket [i].duplicate(true)
			if int(open_match.get("round", 1)) != current_round:
				continue
			if str(open_match.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var open_a_id: int = int(open_match.get("fighter_a_id", -1))
			var open_b_id: int = int(open_match.get("fighter_b_id", -1))

			if open_a_id <= 0 and open_b_id > 0:
				if blocked_opponents.has(open_b_id) or _bending_tournament_actor_is_dead_or_unavailable(out, open_b_id):
					continue
				open_match ["fighter_a_id"] = actor_id
				open_match ["fighter_a_name"] = _bending_person_label(actor)
				open_match ["fighter_a_seed"] = int(actor_row.get("seed", 999))
				open_match ["opponent_id"] = open_b_id

				bracket [i] = open_match
				out ["participants"] = participants
				out ["bracket"] = bracket
				_save_bending_tournament(out)
				return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

			if open_b_id <= 0 and open_a_id > 0:
				if blocked_opponents.has(open_a_id) or _bending_tournament_actor_is_dead_or_unavailable(out, open_a_id):
					continue
				open_match ["fighter_b_id"] = actor_id
				open_match ["fighter_b_name"] = _bending_person_label(actor)
				open_match ["fighter_b_seed"] = int(actor_row.get("seed", 999))
				open_match ["opponent_id"] = open_a_id

				bracket [i] = open_match
				out ["participants"] = participants
				out ["bracket"] = bracket
				_save_bending_tournament(out)
				return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

		var forced_opponent: Person = _resolve_bending_tournament_filler(actor, division, occupied_ids)
		if forced_opponent != null:
			var forced_opponent_row: Dictionary = _bending_tournament_participant_payload(forced_opponent, participants.size() + 1)
			participants.append(forced_opponent_row)
			occupied_ids [int(forced_opponent.id)] = true

			var forced_match: Dictionary = {
				"match_id": "r%d_player_%d_%d" % [current_round, actor_id, int(Time.get_ticks_msec())],
				"round": current_round,
				"round_label": _bending_tournament_round_label(current_round, participants.size()),
				"status": "pending",
				"fighter_a_id": actor_id,
				"fighter_a_name": _bending_person_label(actor),
				"fighter_a_seed": int(actor_row.get("seed", 999)),
				"fighter_b_id": int(forced_opponent.id),
				"fighter_b_name": _bending_person_label(forced_opponent),
				"fighter_b_seed": int(forced_opponent_row.get("seed", participants.size())),
				"opponent_id": int(forced_opponent.id),
			}

			bracket.append(forced_match)
			out ["participants"] = participants
			out ["bracket"] = bracket
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	out ["participants"] = participants
	out ["bracket"] = bracket
	_save_bending_tournament(out)
	return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

func _find_or_create_player_tournament_match(tournament: Dictionary, actor: Person) -> Dictionary:
	if actor == null or tournament.is_empty():
		return {}

	var actor_id: int = int(actor.id)
	var initial_status: Dictionary = _bending_tournament_actor_status(tournament, actor)
	var initial_status_key: String = str(initial_status.get("status", "none")).strip_edges().to_lower()

	if initial_status_key in ["advanced", "champion", "eliminated"]:
		return {}

	var direct_match: Dictionary = _bending_pending_actor_tournament_match(tournament, actor_id, true)
	if not direct_match.is_empty():
		return direct_match

	var repaired_tournament: Dictionary = _repair_bending_tournament_for_actor_match(tournament, actor)
	if repaired_tournament.is_empty():
		repaired_tournament = tournament.duplicate(true)

	var repaired_status: Dictionary = _bending_tournament_actor_status(repaired_tournament, actor)
	var repaired_status_key: String = str(repaired_status.get("status", "none")).strip_edges().to_lower()
	if repaired_status_key in ["advanced", "champion", "eliminated"]:
		return {}

	var current_round: int = _bending_tournament_current_round(repaired_tournament)
	var latest_completed_round: int = _bending_tournament_actor_completed_round(repaired_tournament, actor_id)

	if latest_completed_round >= current_round and _bending_tournament_round_has_pending(repaired_tournament, current_round):
		return {}

	if latest_completed_round >= current_round:
		return {}

	direct_match = _bending_pending_actor_tournament_match(repaired_tournament, actor_id, true)
	if not direct_match.is_empty():
		return direct_match

	var forced_tournament: Dictionary = _bending_force_player_tournament_match_now(repaired_tournament, actor)
	if forced_tournament.is_empty():
		return {}

	var forced_status: Dictionary = _bending_tournament_actor_status(forced_tournament, actor)
	var forced_status_key: String = str(forced_status.get("status", "none")).strip_edges().to_lower()
	if forced_status_key in ["advanced", "champion", "eliminated"]:
		return {}

	direct_match = _bending_pending_actor_tournament_match(forced_tournament, actor_id, true)
	if not direct_match.is_empty():
		return direct_match

	return {}
func _save_bending_tournament(tournament: Dictionary) -> void:
	if gs == null or tournament.is_empty():
		return

	var tournament_id: String = str(tournament.get("id", "")).strip_edges()
	if tournament_id == "":
		return

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	tournaments [tournament_id] = tournament
	state ["tournaments"] = tournaments
	gs.scenario_state ["bending_world_championship"] = state


func _register_bending_tournament_entry(tournament: Dictionary, actor: Person) -> Dictionary:
	if actor == null:
		return tournament

	var out: Dictionary = tournament.duplicate(true)
	var entered_raw: Variant = out.get("entered_actor_ids", [])
	var entered: Array = entered_raw if typeof(entered_raw) == TYPE_ARRAY else []
	var actor_id: int = int(actor.id)

	if actor_id not in entered:
		entered.append(actor_id)

	out ["entered_actor_ids"] = entered
	out ["player_entered"] = true
	out ["last_entered_actor_id"] = actor_id
	out ["last_entered_actor_name"] = _bending_person_label(actor)
	out ["last_entered_year"] = int(gs.year) if gs != null else int(out.get("year", 0))

	_add_tournament_participant_if_missing(out, actor)
	_save_bending_tournament(out)

	return out


func _repair_bending_tournament_for_actor_match(tournament: Dictionary, actor: Person) -> Dictionary:
	if actor == null or tournament.is_empty():
		return tournament

	var out: Dictionary = tournament.duplicate(true)
	var tournament_id: String = str(out.get("id", "")).strip_edges()
	var actor_id: int = int(actor.id)
	var bracket: Array = _safe_array(out.get("bracket", []))
	var participants: Array = _safe_array(out.get("participants", []))
	var current_round: int = _bending_tournament_current_round(out)
	var latest_completed_round: int = _bending_tournament_actor_completed_round(out, actor_id)

	if latest_completed_round >= current_round and _bending_tournament_round_has_pending(out, current_round):
		_save_bending_tournament(out)
		return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var pending_match: Dictionary = raw_match
		if str(pending_match.get("status", "pending")).strip_edges().to_lower() != "pending":
			continue

		var fighter_a_id: int = int(pending_match.get("fighter_a_id", -1))
		var fighter_b_id: int = int(pending_match.get("fighter_b_id", -1))

		if fighter_a_id == actor_id or fighter_b_id == actor_id:
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	var actor_row: Dictionary = {}
	for raw_participant in participants:
		if typeof(raw_participant) != TYPE_DICTIONARY:
			continue

		var participant: Dictionary = raw_participant
		if int(participant.get("person_id", -1)) == actor_id:
			actor_row = participant.duplicate(true)
			break

	if actor_row.is_empty():
		actor_row = _bending_tournament_participant_payload(actor, participants.size() + 1)
		participants.append(actor_row)
		out ["participants"] = participants

	var bracket_ids: Dictionary = _tournament_id_lookup(out)
	if not bracket_ids.has(actor_id):
		var has_completed_match: bool = false

		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var existing_match: Dictionary = raw_match
			if str(existing_match.get("status", "pending")).strip_edges().to_lower() != "pending":
				has_completed_match = true
				break

		if not has_completed_match:
			out ["bracket"] = _build_bending_tournament_bracket(participants)
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	for i in range(bracket.size()):
		if typeof(bracket [i]) != TYPE_DICTIONARY:
			continue

		var open_match: Dictionary = bracket [i]
		if str(open_match.get("status", "pending")).strip_edges().to_lower() != "pending":
			continue

		if int(open_match.get("round", 1)) <= latest_completed_round:
			continue

		if int(open_match.get("fighter_a_id", -1)) <= 0:
			open_match ["fighter_a_id"] = actor_id
			open_match ["fighter_a_name"] = _bending_person_label(actor)
			open_match ["fighter_a_seed"] = int(actor_row.get("seed", 999))
			bracket [i] = open_match
			out ["bracket"] = bracket
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

		if int(open_match.get("fighter_b_id", -1)) <= 0:
			open_match ["fighter_b_id"] = actor_id
			open_match ["fighter_b_name"] = _bending_person_label(actor)
			open_match ["fighter_b_seed"] = int(actor_row.get("seed", 999))
			bracket [i] = open_match
			out ["bracket"] = bracket
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	var latest_win_round: int = -999999
	for raw_match in bracket:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var completed_match: Dictionary = raw_match
		if int(completed_match.get("winner_id", -1)) == actor_id:
			latest_win_round = max(latest_win_round, int(completed_match.get("round", 1)))

	if latest_win_round > -999999:
		if latest_win_round >= current_round and _bending_tournament_round_has_pending(out, current_round):
			_save_bending_tournament(out)
			return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

		var next_round: int = latest_win_round + 1
		var actor_has_next_match: bool = false

		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var next_match_row: Dictionary = raw_match
			if int(next_match_row.get("round", 1)) != next_round:
				continue
			if str(next_match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var next_a_id: int = int(next_match_row.get("fighter_a_id", -1))
			var next_b_id: int = int(next_match_row.get("fighter_b_id", -1))
			if next_a_id == actor_id or next_b_id == actor_id:
				actor_has_next_match = true
				break

		if not actor_has_next_match:
			var round_winners: Array = _bending_tournament_winners_for_round(out, latest_win_round)
			if round_winners.size() > 1 and not _bending_tournament_round_has_pending(out, latest_win_round):
				var rebuilt_next_round: Array = _build_bending_tournament_bracket(round_winners)
				var rebuilt_bracket: Array = []

				for raw_match in bracket:
					if typeof(raw_match) != TYPE_DICTIONARY:
						rebuilt_bracket.append(raw_match)
						continue

					var existing_round_match: Dictionary = raw_match
					if int(existing_round_match.get("round", 1)) == next_round and str(existing_round_match.get("status", "pending")).strip_edges().to_lower() == "pending":
						continue

					rebuilt_bracket.append(existing_round_match.duplicate(true))

				for n in range(rebuilt_next_round.size()):
					var generated_match: Dictionary = rebuilt_next_round [n]
					generated_match ["round"] = next_round
					generated_match ["round_label"] = _bending_tournament_round_label(next_round, round_winners.size())
					generated_match ["match_id"] = "r%d_m%d" % [next_round, n + 1]
					rebuilt_bracket.append(generated_match)

				out ["bracket"] = rebuilt_bracket
				_save_bending_tournament(out)
				return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

	return _bending_tournament_reload_by_id(tournament_id) if tournament_id != "" else out

func _participant_id_lookup(participants: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw_row in participants:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var person_id: int = int(row.get("person_id", -1))
		if person_id > 0:
			out [person_id] = true
	return out


func _tournament_id_lookup(tournament: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	var participants_raw: Variant = tournament.get("participants", [])
	if typeof(participants_raw) == TYPE_ARRAY:
		for raw_participant in participants_raw:
			if typeof(raw_participant) != TYPE_DICTIONARY:
				continue
			var participant: Dictionary = raw_participant
			var participant_id: int = int(participant.get("person_id", -1))
			if participant_id > 0:
				out [participant_id] = true

	var bracket_raw: Variant = tournament.get("bracket", [])
	if typeof(bracket_raw) == TYPE_ARRAY:
		for raw_match in bracket_raw:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue
			var match_row: Dictionary = raw_match
			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
			if fighter_a_id > 0:
				out [fighter_a_id] = true
			if fighter_b_id > 0:
				out [fighter_b_id] = true

	return out


func _add_tournament_participant_if_missing(tournament: Dictionary, actor: Person) -> void:
	if actor == null:
		return

	var participants_raw: Variant = tournament.get("participants", [])
	var participants: Array = participants_raw if typeof(participants_raw) == TYPE_ARRAY else []
	var actor_id: int = int(actor.id)

	for raw_row in participants:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if int(row.get("person_id", -1)) == actor_id:
			return

	participants.append(_bending_tournament_participant_payload(actor, participants.size() + 1))
	tournament ["participants"] = participants


func _resolve_bending_tournament_filler(anchor: Person, division: String, excluded_ids: Dictionary = {}) -> Person:
	var clean_division: String = str(division).strip_edges().to_lower()

	var excluded_array: Array = []
	for raw_key in excluded_ids.keys():
		excluded_array.append(int(raw_key))

	var eligible: Array = _eligible_benders_for_division(clean_division, {
		"force_all_eligible": true,
		"exclude_actor_ids": excluded_array,
		"source": "faction_bracket_repair"
	})

	for raw_candidate in eligible:
		if raw_candidate == null:
			continue
		var candidate: Person = raw_candidate
		if anchor != null and int(candidate.id) == int(anchor.id):
			continue
		return candidate

	return _create_bending_faction_filler(anchor, clean_division)


func _create_bending_faction_filler(anchor: Person, division: String) -> Person:
	if gs == null or gs.npc_factory == null:
		return null

	var filler: Person = gs.npc_factory.create_random_npc()
	if filler == null:
		return null

	var clean_division: String = str(division).strip_edges().to_lower()
	match clean_division:
		"youth":
			filler.age = randi_range(10, 17)
		"elder_male":
			filler.age = randi_range(65, 88)
			filler.gender = "Male"
		"elder_female":
			filler.age = randi_range(65, 88)
			filler.gender = "Female"
		"masters":
			filler.age = randi_range(28, 74)
		"agni_kai":
			filler.age = randi_range(14, 54)
		_:
			filler.age = randi_range(18, 54)

	filler.alive = true

	var element: String = "fire"
	if clean_division != "agni_kai" and anchor != null:
		element = _bending_person_primary_element(anchor)
		if element == "avatar":
			element = _element_from_nation(str(anchor.bending_nation))
	if clean_division == "agni_kai":
		element = "fire"
	elif element not in _base_bending_elements():
		element = str(BASE_ELEMENTS.pick_random())

	var level_floor: int = 18
	var level_ceiling: int = 62
	if clean_division == "masters":
		level_floor = 55
		level_ceiling = 94
	elif clean_division == "agni_kai":
		level_floor = 42
		level_ceiling = 96
	elif clean_division == "youth":
		level_floor = 10
		level_ceiling = 48
	elif clean_division.begins_with("elder"):
		level_floor = 28
		level_ceiling = 78

	force_bending_type(filler, element, randi_range(level_floor, level_ceiling))
	filler.bending_nation = _nation_from_element(element)
	if clean_division == "agni_kai":
		filler.bending_nation = "Fire Nation"
	filler.fame = max(int(filler.fame), randi_range(0, 16))

	_seed_lineage_bending_combat_profile(filler, {
		"force": true,
		"source": "world_championship_faction_filler"
	})

	_register_bending_world_spawn(filler)

	return filler


func _bending_tournament_has_actor_id(tournament: Dictionary, actor_id: int) -> bool:
	if actor_id <= 0:
		return false

	var entered_raw: Variant = tournament.get("entered_actor_ids", [])
	if typeof(entered_raw) == TYPE_ARRAY and actor_id in entered_raw:
		return true

	var participants_raw: Variant = tournament.get("participants", [])
	if typeof(participants_raw) == TYPE_ARRAY:
		for raw_participant in participants_raw:
			if typeof(raw_participant) != TYPE_DICTIONARY:
				continue
			var participant: Dictionary = raw_participant
			if int(participant.get("person_id", -1)) == actor_id:
				return true

	var bracket_raw: Variant = tournament.get("bracket", [])
	if typeof(bracket_raw) == TYPE_ARRAY:
		for raw_match in bracket_raw:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue
			var match_row: Dictionary = raw_match
			if int(match_row.get("fighter_a_id", -1)) == actor_id:
				return true
			if int(match_row.get("fighter_b_id", -1)) == actor_id:
				return true

	return false
func _bending_actor_combat_theme(actor: Person) -> String:
	if actor == null:
		return "bending_duel"

	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"

	var element: String = _bending_person_primary_element(actor)
	if element in _base_bending_elements():
		return "bending_element_%s" % element

	return "bending_duel"


func _bending_actor_willpower_score(actor: Person, context: Dictionary = {}) -> int:
	if actor == null:
		return 0

	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null:
		if gs.willpower_engine.has_method("score"):
			return int(clamp(round(float(gs.willpower_engine.score(actor, {
				"source": str(context.get("source", "bending_prefight_read")),
				"scope": "bending"
			}))), 0, 999))
		if gs.willpower_engine.has_method("ensure_willpower"):
			var willpower_profile: Dictionary = gs.willpower_engine.ensure_willpower(actor, {
				"source": str(context.get("source", "bending_prefight_read")),
				"scope": "bending"
			})
			return int(clamp(round(float(willpower_profile.get("core_score", actor.willpower))), 0, 999))

	return int(clamp(round(float(actor.willpower)), 0, 999))


func _bending_actor_record_summary(actor: Person) -> String:
	if actor == null:
		return "0-0"

	var records: Dictionary = _ensure_bending_duel_records(actor)
	var overall: Dictionary = records.get("overall", {})
	var wins: int = int(overall.get("wins", 0))
	var losses: int = int(overall.get("losses", 0))
	var kos: int = int(overall.get("kos", 0))
	var deaths: int = int(overall.get("deaths", 0))

	var extra: Array = []
	if kos > 0:
		extra.append("%d KO" % kos)
	if deaths > 0:
		extra.append("%d lethal" % deaths)

	if extra.is_empty():
		return "%d-%d" % [wins, losses]

	return "%d-%d • %s" % [wins, losses, " | ".join(extra)]


func _bending_prefight_win_odds(actor: Person, opponent: Person, division: String = "") -> Dictionary:
	if actor == null or opponent == null:
		return {
			"actor_odds": 50,
			"opponent_odds": 50,
			"actor_score": 0.0,
			"opponent_score": 0.0
		}

	var actor_score: float = _bending_competitive_score(actor, division)
	var opponent_score: float = _bending_competitive_score(opponent, division)

	actor_score += float(_bending_actor_willpower_score(actor, { "source": "prefight_odds"})) * 0.35
	opponent_score += float(_bending_actor_willpower_score(opponent, { "source": "prefight_odds"})) * 0.35

	var total: float = max(1.0, actor_score + opponent_score)
	var actor_odds: int = int(clamp(round((actor_score / total) * 100.0), 5, 95))
	var opponent_odds: int = 100 - actor_odds

	return {
		"actor_odds": actor_odds,
		"opponent_odds": opponent_odds,
		"actor_score": actor_score,
		"opponent_score": opponent_score
	}


func _bending_prefight_combat_ui(actor: Person, opponent: Person, tournament: Dictionary = {}, match_row: Dictionary = {}, status_text: String = "Match ready") -> Dictionary:
	var division: String = str(tournament.get("division", match_row.get("division", "")))
	var actor_element: String = _bending_person_primary_element(actor)
	var opponent_element: String = _bending_person_primary_element(opponent)
	var actor_willpower: int = _bending_actor_willpower_score(actor, { "source": "prefight_combat_ui"})
	var opponent_willpower: int = _bending_actor_willpower_score(opponent, { "source": "prefight_combat_ui"})
	var odds: Dictionary = _bending_prefight_win_odds(actor, opponent, division)

	return {
		"visible": true,
		"theme": _bending_tournament_live_theme_for_fighters(actor, opponent),
		"player_theme": _bending_actor_combat_theme(actor),
		"enemy_theme": _bending_actor_combat_theme(opponent),
		"player_avatar_pulse": actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar",
		"enemy_avatar_pulse": opponent != null and str(opponent.bending_type).strip_edges().to_lower() == "avatar",
		"status_text": status_text,
		"player_label": "%s • %s bending • Record %s • WP %d • Win odds %d%%" % [
			_bending_person_label(actor),
			actor_element.capitalize(),
			_bending_actor_record_summary(actor),
			actor_willpower,
			int(odds.get("actor_odds", 50))
		],
		"player_value": int(actor.health) if actor != null else 100,
		"player_max": max(1, int(actor.health) if actor != null else 100),
		"enemy_label": "%s • %s bending • Record %s • WP %d • Win odds %d%%" % [
			_bending_person_label(opponent),
			opponent_element.capitalize(),
			_bending_actor_record_summary(opponent),
			opponent_willpower,
			int(odds.get("opponent_odds", 50))
		],
		"enemy_value": int(opponent.health) if opponent != null else 100,
		"enemy_max": max(1, int(opponent.health) if opponent != null else 100),
		"prefight_read": {
			"actor_id": int(actor.id) if actor != null else -1,
			"opponent_id": int(opponent.id) if opponent != null else -1,
			"actor_willpower": actor_willpower,
			"opponent_willpower": opponent_willpower,
			"actor_record": _bending_actor_record_summary(actor),
			"opponent_record": _bending_actor_record_summary(opponent),
			"actor_odds": int(odds.get("actor_odds", 50)),
			"opponent_odds": int(odds.get("opponent_odds", 50)),
			"division": division,
			"tournament_id": str(tournament.get("id", "")),
			"tournament_match_id": str(match_row.get("match_id", ""))
		}
	}
func build_bending_tournament_duel_scenario(actor: Person, opponent: Person, tournament: Dictionary, match_row: Dictionary) -> Dictionary:
	var actor_style: Dictionary = get_competitive_style_identity(actor, {
		"source": "tournament_scenario_actor"
	})
	var opponent_style: Dictionary = get_competitive_style_identity(opponent, {
		"source": "tournament_scenario_opponent"
	})

	var opponent_study: Dictionary = get_bending_archival_study_report(opponent, actor, {
		"source": "tournament_prefight_rival_study",
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", ""))
	})
	var actor_study: Dictionary = get_bending_archival_study_report(actor, opponent, {
		"source": "tournament_prefight_player_study",
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", ""))
	})

	var division: String = str(tournament.get("division", ""))
	var round_value: int = int(match_row.get("round", _bending_tournament_current_round(tournament)))
	var round_field_size: int = _bending_tournament_field_size_for_round(tournament, round_value)
	var round_label: String = str(match_row.get("round_label", _bending_tournament_round_label(round_value, round_field_size)))
	var stage_label: String = _bending_tournament_stage_label(tournament, round_value)
	var actor_willpower: int = _bending_actor_willpower_score(actor, { "source": "tournament_prefight"})
	var opponent_willpower: int = _bending_actor_willpower_score(opponent, { "source": "tournament_prefight"})
	var odds: Dictionary = _bending_prefight_win_odds(actor, opponent, division)

	var prompt_text: String = "You enter the arena against %s.\n\nThis is %s.\n\nRound: %s.\n\n%s is known as %s. %s" % [
		_bending_person_label(opponent),
		stage_label,
		round_label,
		_bending_person_label(opponent),
		str(opponent_style.get("title", "an unformed fighter")),
		str(opponent_style.get("pre_fight_read", "Nobody knows what kind of problem they are yet."))
	]

	prompt_text += "\n\nMatch Read:\nYou: %s • Willpower %d • Win odds %d%%\n%s: %s • Willpower %d • Win odds %d%%" % [
		_bending_actor_record_summary(actor),
		actor_willpower,
		int(odds.get("actor_odds", 50)),
		_bending_person_label(opponent),
		_bending_actor_record_summary(opponent),
		opponent_willpower,
		int(odds.get("opponent_odds", 50))
	]

	if int(opponent_study.get("bonus", 0)) > 0:
		prompt_text += "\n\n%s has studied archived footage of your old matches. %s" % [
			_bending_person_label(opponent),
			str(opponent_study.get("line", "They are not entering this fight blind."))
		]

	if int(actor_study.get("bonus", 0)) > 0:
		prompt_text += "\n\nYou recognize patterns from %s's archived matches. %s" % [
			_bending_person_label(opponent),
			str(actor_study.get("line", "The archive gives you a real pre-fight read."))
		]

	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		prompt_text += "\n\nThe arena recognizes you as the Avatar. Even the officials speak softer."

	if opponent != null and str(opponent.bending_type).strip_edges().to_lower() == "avatar":
		prompt_text += "\n\nYou are facing the Avatar. The crowd knows this is not a normal bracket anymore."

	var actor_seed: int = int(match_row.get("fighter_a_seed", 999))
	var opponent_seed: int = int(match_row.get("fighter_b_seed", 999))
	if int(match_row.get("fighter_b_id", -1)) == int(actor.id):
		actor_seed = int(match_row.get("fighter_b_seed", 999))
		opponent_seed = int(match_row.get("fighter_a_seed", 999))

	var seed_line: String = ""
	if actor_seed < 999 or opponent_seed < 999:
		seed_line = "\n\nSeeds:\nYou: #%d\n%s: #%d" % [
			actor_seed,
			_bending_person_label(opponent),
			opponent_seed
		]
		prompt_text += seed_line

	var opponent_name: String = "#%d %s" % [
		opponent_seed,
		_bending_person_label(opponent)
	] if opponent_seed < 999 else _bending_person_label(opponent)

	var choices: Array = [
		{
			"id": "bending_duel_accept",
			"label": "Start Match vs %s" % opponent_name,
			"kind": "scenario_choice",
			"journal_text": "I began my %s against %s." % [stage_label, opponent_name],
			"button_theme": "bending_ability",
			"power_source": "bending",
			"bending_duel_target_id": int(opponent.id),
			"payload": {
				"duel_action": "begin"
			}
		}
	]

	if _bending_era_supports_media() or bool(tournament.get("allow_press_conference", false)):
		choices.append({
			"id": "bending_press_trash_talk",
			"label": "Talk Trash At The Press Conference",
			"kind": "scenario_choice",
			"journal_text": "I talked trash before my %s." % stage_label,
			"button_theme": "fame_action",
			"power_source": "social",
			"bending_duel_target_id": int(opponent.id),
			"payload": {
				"duel_action": "trash_talk"
			}
		})

	choices.append({
		"id": "bending_duel_decline",
		"label": "Withdraw From Match",
		"kind": "scenario_choice",
		"journal_text": "I withdrew from my %s." % stage_label,
		"button_theme": "defensive_escape",
		"power_source": "survival",
		"bending_duel_target_id": int(opponent.id),
		"payload": {
			"duel_action": "concede"
		}
	})

	return {
		"id": "bending_tournament_%s_%s_%d" % [
			str(tournament.get("id", "tournament")),
			str(match_row.get("match_id", "match")),
			int(Time.get_ticks_msec())
		],
		"source": "scenario_engine",
		"category": "bending",
		"cooldown_key": "bending_world_championship",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": stage_label.to_upper(),
		"footer_text": "Tournament duel. Your actual bending skills, tactical reads, health, fear, respect, inventory, artifacts, matchup choices, archived match study, style echo pressure, willpower, and record history matter.",
		"prompt": prompt_text,
		"actor_id": int(actor.id),
		"target_id": int(opponent.id),
		"bending_duel_target_id": int(opponent.id),
		"tournament_duel": true,
		"tournament_id": str(tournament.get("id", "")),
		"tournament_match_id": str(match_row.get("match_id", "")),
		"tournament_division": str(tournament.get("division", "")),
		"tournament_round": round_value,
		"tournament_round_label": round_label,
		"tournament_stage_label": stage_label,
		"actor_style_identity": actor_style.duplicate(true),
		"opponent_style_identity": opponent_style.duplicate(true),
		"actor_archival_study": actor_study.duplicate(true),
		"opponent_archival_study": opponent_study.duplicate(true),
		"bending_duel_contract": {
			"schema": "eralife.bending_duel_contract",
			"version": 4,
			"source": "bending_world_championship",
			"uses_scenario_panel": true,
			"damage_reflects_on_stats": true,
			"elemental_screen_damage_contract": _bending_elemental_screen_damage_contract()
		},
		"combat_ui": _bending_prefight_combat_ui(actor, opponent, tournament, match_row, "Tournament match ready"),
		"choices": choices
	}
func get_competitive_style_identity(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var index: Dictionary = state.get("style_identity_index", {})
	var actor_key: String = str(int(actor.id))
	var existing: Dictionary = index.get(actor_key, {})

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var records: Dictionary = _ensure_bending_duel_records(actor)
	var overall: Dictionary = records.get("overall", {})

	var archetype_id: String = _resolve_competitive_style_archetype(actor, profile, overall)
	var title: String = _competitive_style_title(archetype_id)
	var description: String = _competitive_style_description(archetype_id)

	var heat: int = int(existing.get("heat", 0))
	heat += int(overall.get("wins", 0))
	heat += int(overall.get("kos", 0)) * 2
	heat += int(float(actor.fame) / 10.0)

	var echo_report: Dictionary = _bending_style_echo_report_for_actor(actor)
	heat += int(echo_report.get("echo_heat", 0))
	heat = clamp(heat, 0, 100)

	var style_identity: Dictionary = {
		"schema": "eralife.competitive_style_identity",
		"version": 2,
		"person_id": int(actor.id),
		"name": _bending_person_label(actor),
		"system": str(context.get("system", "bending")),
		"archetype_id": archetype_id,
		"title": title,
		"description": description,
		"pre_fight_read": _competitive_style_prefight_read(archetype_id, actor),
		"heat": heat,
		"updated_year": int(gs.year) if gs != null else 0,
		"style_echo": echo_report.duplicate(true),
		"stats": {
			"accuracy": int(profile.get("accuracy", 50)),
			"power": int(profile.get("power", 50)),
			"guard": int(profile.get("guard", 50)),
			"counter": int(profile.get("counter", 50)),
			"evasion": int(profile.get("evasion", 50)),
			"focus": int(profile.get("focus", 50))
		}
	}

	if not echo_report.is_empty() and str(echo_report.get("myth_title", "")).strip_edges() != "":
		style_identity ["pre_fight_read"] = "%s %s" % [
			str(style_identity.get("pre_fight_read", "")),
			str(echo_report.get("myth_title", ""))
		]

	index [actor_key] = style_identity
	state ["style_identity_index"] = index
	gs.scenario_state ["bending_world_championship"] = state

	return style_identity.duplicate(true)


func _resolve_competitive_style_archetype(actor: Person, profile: Dictionary, overall: Dictionary) -> String:
	var power: int = int(profile.get("power", 50))
	var guard: int = int(profile.get("guard", 50))
	var counter: int = int(profile.get("counter", 50))
	var evasion: int = int(profile.get("evasion", 50))
	var accuracy: int = int(profile.get("accuracy", 50))
	var focus: int = int(profile.get("focus", 50))
	var kos: int = int(overall.get("kos", 0))
	var wins: int = int(overall.get("wins", 0))
	var losses: int = int(overall.get("losses", 0))

	if counter >= max(power, evasion) and counter >= 68:
		return "counter_king"
	if evasion >= max(power, counter) and evasion >= 68:
		return "untouchable"
	if power >= 70 and kos >= 2:
		return "berserker"
	if guard >= 68 and focus >= 64:
		return "stone_wall"
	if accuracy >= 70 and focus >= 64:
		return "surgeon"
	if wins >= 8 and losses <= 1:
		return "dynasty_problem"
	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		return "avatar_pressure"

	return "forming_style"


func _competitive_style_title(archetype_id: String) -> String:
	match str(archetype_id):
		"counter_king":
			return "The Counter King"
		"untouchable":
			return "The Untouchable"
		"berserker":
			return "The Berserker"
		"stone_wall":
			return "The Stone Wall"
		"surgeon":
			return "The Surgeon"
		"dynasty_problem":
			return "The Dynasty Problem"
		"avatar_pressure":
			return "The Avatar Pressure"
	return "A Forming Style"


func _competitive_style_description(archetype_id: String) -> String:
	match str(archetype_id):
		"counter_king":
			return "They punish mistakes before opponents realize they made one."
		"untouchable":
			return "They make clean offense feel impossible."
		"berserker":
			return "They carry knockout danger into every exchange."
		"stone_wall":
			return "They absorb pressure and turn patience into damage."
		"surgeon":
			return "They win through precision, timing, and cruel accuracy."
		"dynasty_problem":
			return "Their bloodline has started feeling bigger than one fighter."
		"avatar_pressure":
			return "The matchup changes before the first move because the Avatar is in the room."
	return "Their competitive identity is still forming."


func _competitive_style_prefight_read(archetype_id: String, actor: Person) -> String:
	var actor_name: String = _bending_person_label(actor)
	match str(archetype_id):
		"counter_king":
			return "%s waits for one bad angle, then makes it expensive." % actor_name
		"untouchable":
			return "%s has a reputation for making opponents swing at air." % actor_name
		"berserker":
			return "%s does not need many clean shots to ruin a bracket." % actor_name
		"stone_wall":
			return "%s breaks opponents by refusing to break first." % actor_name
		"surgeon":
			return "%s fights like every mistake has already been measured." % actor_name
		"dynasty_problem":
			return "%s carries a family name that keeps showing up in finals." % actor_name
		"avatar_pressure":
			return "%s changes the entire arena just by breathing." % actor_name
	return "%s has not revealed a stable style identity yet." % actor_name


func record_bending_trash_talk(actor: Person, target: Person, _context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null or target == null:
		return {}

	var actor_style: Dictionary = get_competitive_style_identity(actor, {
		"source": "trash_talk",
		"system": "bending"
	})
	var target_style: Dictionary = get_competitive_style_identity(target, {
		"source": "trash_talk_target",
		"system": "bending"
	})

	modify_respect(actor, 2, "bending_trash_talk", "bending")
	modify_respect(target, 1, "bending_trash_talk_target", "bending")

	var text: String = "%s told %s, “Your style got a loading screen and I already skipped it.”" % [
		_bending_person_label(actor),
		_bending_person_label(target)
	]

	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		text = "%s told %s, “You are not fighting one lifetime. You are fighting all of mine.”" % [
			_bending_person_label(actor),
			_bending_person_label(target)
		]

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(text, {
			"category": "bending",
			"event_name": "bending_press_conference_trash_talk",
			"source": "bending_engine",
			"personally_relevant": actor == gs.player or target == gs.player,
			"actor_id": int(actor.id),
			"target_id": int(target.id),
			"actor_style_identity": actor_style.duplicate(true),
			"target_style_identity": target_style.duplicate(true)
		})

	return {
		"schema": "eralife.bending_trash_talk_report",
		"version": 1,
		"success": true,
		"text": text,
		"actor_style_identity": actor_style.duplicate(true),
		"target_style_identity": target_style.duplicate(true)
	}
func _bending_elemental_screen_damage_contract() -> Dictionary:
	return {
		"schema": "eralife.elemental_screen_damage_contract",
		"version": 1,
		"enabled": true,
		"source": "bending_engine",
		"damage_scale": {
			"minimum_visible_damage": 1,
			"soft_hit_ratio": 0.1,
			"heavy_hit_ratio": 0.28,
			"max_intensity": 1.0
		},
		"profiles": {
			"fire": {
				"visual_id": "screen_damage.fire",
				"flash_profile": "ember_heat_flash",
				"border_profile": "scorched_edge",
				"shader_profile": "heat_distortion",
				"particle_hint": "sparks",
				"audio_hint": "muffled_flame_pop"
			},
			"water": {
				"visual_id": "screen_damage.water",
				"flash_profile": "cold_blue_ripple",
				"border_profile": "wet_blur_edge",
				"shader_profile": "water_refraction",
				"particle_hint": "droplets",
				"audio_hint": "submerged_impact"
			},
			"earth": {
				"visual_id": "screen_damage.earth",
				"flash_profile": "dust_crack_flash",
				"border_profile": "stone_fracture_edge",
				"shader_profile": "screen_weight",
				"particle_hint": "dust",
				"audio_hint": "low_stone_hit"
			},
			"air": {
				"visual_id": "screen_damage.air",
				"flash_profile": "white_pressure_burst",
				"border_profile": "wind_shear_edge",
				"shader_profile": "pressure_warp",
				"particle_hint": "wind_lines",
				"audio_hint": "breath_cut"
			},
			"avatar": {
				"visual_id": "screen_damage.avatar",
				"flash_profile": "cycling_elemental_hit",
				"border_profile": "four_element_surge_edge",
				"shader_profile": "avatar_spectrum_warp",
				"particle_hint": "element_cycle",
				"audio_hint": "spirit_resonance_hit"
			}
		}
	}
func _bending_tournament_label(division: String) -> String:
	match str(division).strip_edges().to_lower():
		"youth":
			return "Youth Bending World Championship"
		"adult":
			return "Adult Bending World Championship"
		"elder_male":
			return "Elder Men's Bending World Championship"
		"elder_female":
			return "Elder Women's Bending World Championship"
		"elder_open":
			return "Elder Open Bending World Championship"
		"masters":
			return "Tournament of Champions"
		"agni_kai":
			return "Agni Kai Championship of Unbreakable Fire"
		_:
			return "Bending World Championship"
func _blank_bending_duel_records() -> Dictionary:
	return {
		"schema": "eralife.bending_duel_records",
		"version": 3,
		"non_tournament": {
			"wins": 0,
			"losses": 0,
			"kos": 0,
			"deaths": 0
		},
		"tournament": {
			"wins": 0,
			"losses": 0,
			"kos": 0,
			"deaths": 0
		},
		"overall": {
			"wins": 0,
			"losses": 0,
			"kos": 0,
			"deaths": 0
		},
		"championships": 0,
		"championship_years": [],
		"championship_tournament_ids": [],
		"championship_title_counts": {},
		"championships_by_division": {},
		"championships_by_label": {},
		"championship_title_rows": [],
		"championship_title_summary": "",
		"established_history_seeded": false,
		"last_updated_year": int(gs.year) if gs != null else 0
	}
func _bending_championship_title_key(tournament: Dictionary) -> String:
	return _bending_championship_title_key_from_division(
		str(tournament.get("division", "")),
		str(tournament.get("label", ""))
	)


func _bending_championship_title_label(tournament: Dictionary) -> String:
	return _bending_championship_title_label_from_key(_bending_championship_title_key(tournament))


func _bending_championship_title_key_from_division(division: String, label: String = "") -> String:
	var clean_division: String = str(division).strip_edges().to_lower()

	match clean_division:
		"youth":
			return "youth_bending_wc"
		"adult":
			return "adult_bending_wc"
		"elder_male":
			return "elder_mens_bending_wc"
		"elder_female":
			return "elder_womens_bending_wc"
		"elder_open":
			return "elder_open_bending_wc"
		"masters":
			return "tournament_of_champions"
		"agni_kai":
			return "agni_kai_unbreakable_fire"

	var clean_label: String = str(label).strip_edges().to_lower()
	clean_label = clean_label.replace("'", "")
	clean_label = clean_label.replace("’", "")
	clean_label = clean_label.replace("-", "_")
	clean_label = clean_label.replace(" ", "_")
	while clean_label.find("__") != -1:
		clean_label = clean_label.replace("__", "_")
	clean_label = clean_label.trim_prefix("_").trim_suffix("_")

	if clean_label == "":
		return "bending_world_championship"

	return clean_label


func _bending_championship_title_label_from_key(title_key: String) -> String:
	var clean_key: String = str(title_key).strip_edges().to_lower()

	match clean_key:
		"youth_bending_wc":
			return "Youth Bending WC"
		"adult_bending_wc":
			return "Adult Bending WC"
		"elder_mens_bending_wc":
			return "Elder Men's Bending WC"
		"elder_womens_bending_wc":
			return "Elder Women's Bending WC"
		"elder_open_bending_wc":
			return "Elder Open Bending WC"
		"tournament_of_champions":
			return "Tournament of Champions"
		"agni_kai_unbreakable_fire":
			return "Agni Kai Championship of Unbreakable Fire"

	return str(title_key).replace("_", " ").capitalize()
func _bending_championship_title_sort_order(title_key: String) -> int:
	match str(title_key).strip_edges().to_lower():
		"youth_bending_wc":
			return 10
		"adult_bending_wc":
			return 20
		"tournament_of_champions":
			return 30
		"agni_kai_unbreakable_fire":
			return 40
		"elder_mens_bending_wc":
			return 50
		"elder_womens_bending_wc":
			return 60
		"elder_open_bending_wc":
			return 70
		_:
			return 999


func _bending_sum_int_dictionary_values(row: Dictionary) -> int:
	var total: int = 0

	for raw_key in row.keys():
		total += max(0, int(row.get(raw_key, 0)))

	return total


func _bending_championship_title_rows_for_counts(counts: Dictionary) -> Array:
	var out: Array = []

	for raw_key in counts.keys():
		var title_key: String = str(raw_key).strip_edges().to_lower()
		if title_key == "":
			continue

		var count: int = max(0, int(counts.get(raw_key, 0)))
		if count <= 0:
			continue

		var title_label: String = _bending_championship_title_label_from_key(title_key)
		out.append({
			"schema": "eralife.bending_championship_title_count_row",
			"version": 2,
			"title_key": title_key,
			"title_label": title_label,
			"count": count,
			"sort_order": _bending_championship_title_sort_order(title_key),
			"display": "%s X%d" % [title_label, count]
		})

	out.sort_custom(func (a, b):
		var order_a: int = int(a.get("sort_order", 999))
		var order_b: int = int(b.get("sort_order", 999))
		if order_a != order_b:
			return order_a < order_b
		return str(a.get("title_label", "")) < str(b.get("title_label", ""))
	)

	return out


func _bending_championship_title_summary_for_records(records: Dictionary) -> String:
	var title_counts: Dictionary = _safe_dictionary(records.get("championship_title_counts", {}))
	var title_rows: Array = _bending_championship_title_rows_for_counts(title_counts)

	if title_rows.is_empty():
		var championships: int = max(0, int(records.get("championships", 0)))
		if championships <= 0:
			return ""
		return "Bending WC X%d" % championships

	var parts: Array = []
	for raw_row in title_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var display_text: String = str(row.get("display", "")).strip_edges()
		if display_text == "":
			continue
		parts.append(display_text)

	return " | ".join(parts)

func _bending_required_wins_for_championship_tournament(tournament: Dictionary) -> int:
	if tournament.is_empty():
		return 3

	var bracket_raw: Variant = tournament.get("bracket", [])
	var bracket: Array = bracket_raw if typeof(bracket_raw) == TYPE_ARRAY else []
	var champion_id: int = int(tournament.get("champion_id", -1))
	var completed_wins: int = 0

	if champion_id > 0:
		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = raw_match
			if int(match_row.get("winner_id", -1)) != champion_id:
				continue

			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
			if fighter_a_id <= 0 or fighter_b_id <= 0:
				continue

			completed_wins += 1

	if completed_wins > 0:
		return clamp(completed_wins, 3, 4)

	return 3


func _bending_repair_championship_record_math(records: Dictionary) -> Dictionary:
	var out: Dictionary = records.duplicate(true)
	var championships: int = max(0, int(out.get("championships", 0)))

	if championships <= 0:
		return out

	var policy: Dictionary = _bending_world_policy()
	var history_policy: Dictionary = _safe_dictionary(policy.get("history", {}))
	if not bool(history_policy.get("championship_existing_record_repair", true)):
		return out

	var win_floor_per_title: int = max(3, int(history_policy.get("championship_win_floor_per_title", 3)))
	var required_tournament_wins: int = championships * win_floor_per_title

	var tournament_bucket: Dictionary = _safe_dictionary(out.get("tournament", {}))
	var non_tournament_bucket: Dictionary = _safe_dictionary(out.get("non_tournament", {}))
	var overall_bucket: Dictionary = _safe_dictionary(out.get("overall", {}))

	var current_tournament_wins: int = int(tournament_bucket.get("wins", 0))
	if current_tournament_wins < required_tournament_wins:
		var missing: int = required_tournament_wins - current_tournament_wins
		tournament_bucket ["wins"] = current_tournament_wins + missing
		overall_bucket ["wins"] = int(overall_bucket.get("wins", 0)) + missing

	var expected_overall_wins: int = int(tournament_bucket.get("wins", 0)) + int(non_tournament_bucket.get("wins", 0))
	var expected_overall_losses: int = int(tournament_bucket.get("losses", 0)) + int(non_tournament_bucket.get("losses", 0))

	overall_bucket ["wins"] = max(int(overall_bucket.get("wins", 0)), expected_overall_wins)
	overall_bucket ["losses"] = max(int(overall_bucket.get("losses", 0)), expected_overall_losses)

	out ["tournament"] = tournament_bucket
	out ["non_tournament"] = non_tournament_bucket
	out ["overall"] = overall_bucket
	out ["championship_title_summary"] = _bending_championship_title_summary_for_records(out)

	return out


func _normalize_bending_duel_records(records: Dictionary) -> Dictionary:
	var out: Dictionary = records.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.bending_duel_records"))
	out ["version"] = max(3, int(out.get("version", 1)))

	for bucket_key in ["non_tournament", "tournament", "overall"]:
		var bucket_raw: Variant = out.get(bucket_key, {})
		var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}

		bucket ["wins"] = max(0, int(bucket.get("wins", 0)))
		bucket ["losses"] = max(0, int(bucket.get("losses", 0)))
		bucket ["kos"] = max(0, int(bucket.get("kos", 0)))
		bucket ["deaths"] = max(0, int(bucket.get("deaths", 0)))

		out [bucket_key] = bucket

	var championship_years_raw: Variant = out.get("championship_years", [])
	var championship_years: Array = championship_years_raw if typeof(championship_years_raw) == TYPE_ARRAY else []

	var championship_ids_raw: Variant = out.get("championship_tournament_ids", [])
	var championship_tournament_ids: Array = championship_ids_raw if typeof(championship_ids_raw) == TYPE_ARRAY else []

	var title_counts: Dictionary = {}
	var raw_title_counts: Dictionary = _safe_dictionary(out.get("championship_title_counts", {}))
	for raw_title_key in raw_title_counts.keys():
		var title_key: String = str(raw_title_key).strip_edges().to_lower()
		if title_key == "":
			continue
		var title_value: int = max(0, int(raw_title_counts.get(raw_title_key, 0)))
		if title_value <= 0:
			continue
		title_counts [title_key] = max(int(title_counts.get(title_key, 0)), title_value)

	var by_division: Dictionary = _safe_dictionary(out.get("championships_by_division", {}))
	var by_label: Dictionary = _safe_dictionary(out.get("championships_by_label", {}))

	var championship_count: int = max(0, int(out.get("championships", 0)))
	championship_count = max(championship_count, championship_tournament_ids.size())
	championship_count = max(championship_count, _bending_sum_int_dictionary_values(title_counts))
	championship_count = max(championship_count, _bending_sum_int_dictionary_values(by_division))
	championship_count = max(championship_count, _bending_sum_int_dictionary_values(by_label))

	if title_counts.is_empty() and championship_count > 0:
		title_counts ["bending_world_championship"] = championship_count

	out ["championships"] = championship_count
	out ["championship_years"] = championship_years
	out ["championship_tournament_ids"] = championship_tournament_ids
	out ["championship_title_counts"] = title_counts
	out ["championships_by_division"] = by_division
	out ["championships_by_label"] = by_label
	out ["championship_title_rows"] = _bending_championship_title_rows_for_counts(title_counts)
	out ["championship_title_summary"] = _bending_championship_title_summary_for_records(out)

	if not out.has("established_history_seeded"):
		out ["established_history_seeded"] = false

	if not out.has("last_updated_year"):
		out ["last_updated_year"] = int(gs.year) if gs != null else 0

	out = _bending_repair_championship_record_math(out)

	return out


func _seed_established_bending_records_for_actor(actor: Person, records: Dictionary) -> Dictionary:
	if actor == null:
		return records

	var out: Dictionary = records.duplicate(true)
	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type == "none":
		out ["established_history_seeded"] = true
		return out

	var age_value: int = int(actor.age)
	if age_value < 10:
		out ["established_history_seeded"] = true
		return out

	var policy: Dictionary = _bending_world_policy()
	var history_policy: Dictionary = _safe_dictionary(policy.get("history", {}))
	var minimum_duels: int = int(history_policy.get("minimum_adult_prior_duels", 6))
	var maximum_duels: int = int(history_policy.get("maximum_adult_prior_duels", 84))
	var seed_text: String = "%d:%s:%s:%d" % [
		int(actor.id),
		str(actor.first_name),
		str(actor.last_name),
		age_value
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(seed_text.hash()))

	var best_level: int = int(get_primary_bending_level(actor))
	var prior_years: int = max(0, age_value - 10)
	var total_duels: int = int(round(float(prior_years) * rng.randf_range(0.45, 1.35))) + int(rng.randi_range(0, 8))

	if age_value >= 18:
		total_duels = clamp(total_duels, minimum_duels, maximum_duels)
	else:
		total_duels = clamp(total_duels, 0, 24)

	var win_rate: float = 0.34
	win_rate += clamp(float(best_level) / 190.0, 0.0, 0.42)
	win_rate += clamp(float(actor.fame) / 320.0, 0.0, 0.2)
	win_rate += rng.randf_range(-0.12, 0.12)
	win_rate = clamp(win_rate, 0.1, 0.92)

	var wins: int = clamp(int(round(float(total_duels) * win_rate)), 0, total_duels)
	var losses: int = max(0, total_duels - wins)
	var tournament_share: float = 0.2 if age_value < 18 else 0.34
	var tournament_wins: int = int(round(float(wins) * tournament_share))
	var tournament_losses: int = int(round(float(losses) * tournament_share))
	var non_tournament_wins: int = max(0, wins - tournament_wins)
	var non_tournament_losses: int = max(0, losses - tournament_losses)

	var championships: int = 0
	var championship_window: int = 0

	if age_value >= 18:
		championship_window = max(0, int(floor(float(max(0, age_value - 18)) / 4.0)) + 1)
		championship_window = clamp(championship_window, 0, 18)

	if age_value >= 18 and best_level >= 70 and championship_window > 0:
		var fame_signal: int = int(actor.fame)
		var title_chance: int = clamp((best_level - 60) + int(float(fame_signal) * 0.42), 0, 90)

		if int(rng.randi_range(0, 99)) < title_chance:
			var title_base: int = 1
			title_base += int(floor(float(max(0, best_level - 70)) / 7.0))
			title_base += int(floor(float(max(0, fame_signal)) / 40.0))
			title_base += int(rng.randi_range(0, 2))
			championships = clamp(title_base, 1, championship_window)

			if best_level < 78:
				championships = min(championships, 2)
			elif best_level < 85:
				championships = min(championships, 5)
			elif best_level < 92:
				championships = min(championships, 9)

	var win_floor_per_title: int = max(3, int(history_policy.get("championship_win_floor_per_title", 3)))
	var low_seed_floor_per_title: int = max(win_floor_per_title, int(history_policy.get("championship_low_seed_win_floor_per_title", 4)))
	var low_seed_titles: int = 0

	if championships > 0:
		for i in range(championships):
			if rng.randf() < 0.28:
				low_seed_titles += 1

		var required_tournament_wins: int = championships * win_floor_per_title
		required_tournament_wins += low_seed_titles * (low_seed_floor_per_title - win_floor_per_title)

		tournament_wins = max(tournament_wins, required_tournament_wins)
		wins = max(wins, tournament_wins + non_tournament_wins)

		if tournament_losses <= 0 and championships >= 3:
			var championship_loss_ceiling: int = min(6, max(1, int(floor(float(championships) / 2.0))))
			tournament_losses = int(rng.randi_range(0, championship_loss_ceiling))

	var kos: int = clamp(int(round(float(wins) * rng.randf_range(0.05, 0.24))), 0, wins)
	var deaths: int = 0
	if wins > 0 and int(rng.randi_range(0, 99)) < 4:
		deaths = 1

	var tournament_kos: int = int(round(float(kos) * tournament_share))
	var non_tournament_kos: int = max(0, kos - tournament_kos)

	out ["non_tournament"] = {
		"wins": non_tournament_wins,
		"losses": non_tournament_losses,
		"kos": non_tournament_kos,
		"deaths": 0
	}
	out ["tournament"] = {
		"wins": tournament_wins,
		"losses": tournament_losses,
		"kos": tournament_kos,
		"deaths": deaths
	}
	out ["overall"] = {
		"wins": non_tournament_wins + tournament_wins,
		"losses": non_tournament_losses + tournament_losses,
		"kos": kos,
		"deaths": deaths
	}

	out ["championships"] = championships
	out ["championship_years"] = _seeded_championship_years_for_actor(actor, championships, rng)
	out ["championship_tournament_ids"] = []

	var championship_title_counts: Dictionary = {}
	var championships_by_division: Dictionary = {}
	var championships_by_label: Dictionary = {}

	if championships > 0:
		var title_key: String = _bending_championship_title_key_from_division("adult", "Adult Bending World Championship")
		var title_label: String = _bending_championship_title_label_from_key(title_key)
		championship_title_counts [title_key] = championships
		championships_by_division ["adult"] = championships
		championships_by_label [title_label] = championships

	out ["championship_title_counts"] = championship_title_counts
	out ["championships_by_division"] = championships_by_division
	out ["championships_by_label"] = championships_by_label
	out ["championship_title_rows"] = _bending_championship_title_rows_for_counts(championship_title_counts)
	out ["championship_title_summary"] = _bending_championship_title_summary_for_records(out)
	out ["established_history_seeded"] = true
	out ["established_history_source"] = "bending_world_spawn_history"
	out ["last_updated_year"] = int(gs.year) if gs != null else 0

	return _normalize_bending_duel_records(out)


func _seeded_championship_years_for_actor(actor: Person, championships: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out
	if championships <= 0:
		return out

	var earliest_year: int = int(gs.year) - max(1, int(actor.age) - 18)
	var latest_year: int = int(gs.year) - 1
	if latest_year < earliest_year:
		latest_year = earliest_year

	for i in range(championships):
		var year_value: int = int(rng.randi_range(earliest_year, latest_year))
		if year_value not in out:
			out.append(year_value)

	out.sort()
	return out


func _seed_established_bending_records_for_population(_options: Dictionary = {}) -> void:
	if gs == null:
		return

	var population: Array = []
	if gs.player != null:
		population.append(gs.player)

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc != null:
				population.append(raw_npc)

	for raw_actor in population:
		if raw_actor == null:
			continue

		var actor: Person = raw_actor
		if not bool(actor.alive):
			continue
		if str(actor.bending_type).strip_edges().to_lower() == "none":
			continue

		_ensure_bending_duel_records(actor)


func _bending_tournament_cycle_position(year_value: int, cycle_length: int = 5) -> int:
	var safe_cycle: int = max(1, int(cycle_length))
	var raw_position: int = int(year_value) % safe_cycle
	if raw_position <= 0:
		raw_position += safe_cycle
	return raw_position


func _bending_tournament_of_champions_window_key(year_value: int) -> String:
	var policy: Dictionary = _bending_world_policy()
	var cycle: Dictionary = _safe_dictionary(policy.get("tournament_cycle", {}))
	var cycle_length: int = max(1, int(cycle.get("cycle_length", 5)))
	var position: int = _bending_tournament_cycle_position(year_value, cycle_length)
	var start_year: int = int(year_value) - position + 1
	var end_year: int = start_year + cycle_length - 1
	return "%d_%d" % [start_year, end_year]


func _register_tournament_of_champions_bid(winner: Person, tournament: Dictionary) -> void:
	if gs == null or winner == null or tournament.is_empty():
		return

	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var requested_division: String = str(tournament.get("requested_division", division)).strip_edges().to_lower()
	if division != "adult" and requested_division != "adult":
		return

	var tournament_year: int = int(tournament.get("year", int(gs.year)))
	var window_key: String = _bending_tournament_of_champions_window_key(tournament_year)
	var state: Dictionary = _bending_world_state()
	var all_bids: Dictionary = state.get("tournament_of_champions_bids", {})
	var window: Dictionary = all_bids.get(window_key, {})
	if window.is_empty():
		window = {
			"schema": "eralife.tournament_of_champions_bid_window",
			"version": 1,
			"window_key": window_key,
			"bids": {}
		}

	var bids: Dictionary = window.get("bids", {})
	var person_key: String = str(int(winner.id))
	var existing: Dictionary = bids.get(person_key, {})
	var qualified_years: Array = existing.get("qualified_years", []) if typeof(existing.get("qualified_years", [])) == TYPE_ARRAY else []
	if tournament_year not in qualified_years:
		qualified_years.append(tournament_year)
	qualified_years.sort()

	bids [person_key] = {
		"schema": "eralife.tournament_of_champions_bid",
		"version": 1,
		"person_id": int(winner.id),
		"name": _bending_person_label(winner),
		"bloodline": str(winner.last_name).strip_edges(),
		"element": _bending_person_primary_element(winner),
		"qualified_years": qualified_years,
		"title_count_in_window": qualified_years.size(),
		"latest_qualifying_year": tournament_year,
		"source_tournament_id": str(tournament.get("id", "")),
		"source_tournament_label": str(tournament.get("label", "Adult Bending World Championship"))
	}

	window ["bids"] = bids
	all_bids [window_key] = window
	state ["tournament_of_champions_bids"] = all_bids
	gs.scenario_state ["bending_world_championship"] = state


func _bending_tournament_of_champions_participants(year_value: int, options: Dictionary = {}) -> Array:
	var out: Array = []
	var policy: Dictionary = _bending_world_policy()
	var masters_policy: Dictionary = _safe_dictionary(policy.get("masters", {}))
	var top_n: int = max(2, int(masters_policy.get("top_n", 5)))
	var window_key: String = _bending_tournament_of_champions_window_key(year_value)
	var state: Dictionary = _bending_world_state()
	var all_bids: Dictionary = state.get("tournament_of_champions_bids", {})
	var window: Dictionary = all_bids.get(window_key, {})
	var bids: Dictionary = window.get("bids", {}) if typeof(window.get("bids", {})) == TYPE_DICTIONARY else {}
	var rows: Array = []

	for raw_key in bids.keys():
		var bid: Dictionary = bids.get(raw_key, {})
		if bid.is_empty():
			continue

		var actor: Person = _find_person_by_id(int(bid.get("person_id", -1)))
		if actor == null:
			continue
		if not bool(actor.alive):
			continue

		rows.append({
			"actor": actor,
			"title_count": int(bid.get("title_count_in_window", 1)),
			"latest_year": int(bid.get("latest_qualifying_year", 0)),
			"score": _bending_competitive_score(actor, "masters", false)
		})

	rows.sort_custom(func (a, b):
		if int(a.get("title_count", 0)) != int(b.get("title_count", 0)):
			return int(a.get("title_count", 0)) > int(b.get("title_count", 0))
		if float(a.get("score", 0.0)) != float(b.get("score", 0.0)):
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
		return int(a.get("latest_year", 0)) > int(b.get("latest_year", 0))
	)

	for i in range(min(top_n, rows.size())):
		var row: Dictionary = rows [i]
		var actor: Person = row.get("actor", null)
		if actor != null:
			out.append(_bending_tournament_participant_payload(actor, out.size() + 1))

	if out.size() < top_n:
		var excluded: Dictionary = _participant_id_lookup(out)
		var adult_eligible: Array = _eligible_benders_for_division("adult", options)
		for raw_actor in adult_eligible:
			if raw_actor == null:
				continue

			var filler: Person = raw_actor
			if excluded.has(int(filler.id)):
				continue

			out.append(_bending_tournament_participant_payload(filler, out.size() + 1))
			excluded [int(filler.id)] = true

			if out.size() >= top_n:
				break

	return out

func _bending_completed_real_wins_for_tournament(winner: Person, tournament: Dictionary) -> int:
	if winner == null or tournament.is_empty():
		return 0

	var wins: int = 0
	var bracket_raw: Variant = tournament.get("bracket", [])
	if typeof(bracket_raw) != TYPE_ARRAY:
		return wins

	for raw_match in bracket_raw:
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue

		var match_row: Dictionary = raw_match
		if str(match_row.get("status", "")).strip_edges().to_lower() != "complete":
			continue

		if int(match_row.get("winner_id", -1)) != int(winner.id):
			continue

		if bool(match_row.get("bye", false)):
			continue

		if int(match_row.get("loser_id", -1)) <= 0:
			continue

		wins += 1

	return wins
func _normalize_historical_champion_tournament_wins(winner: Person, tournament: Dictionary, context: Dictionary = {}) -> void:
	if winner == null:
		return

	var records: Dictionary = _ensure_bending_duel_records(winner)
	var tournament_bucket: Dictionary = _safe_dictionary(records.get("tournament", {}))
	var overall_bucket: Dictionary = _safe_dictionary(records.get("overall", {}))

	var tournament_id: String = str(tournament.get("id", "")).strip_edges()
	var title_ids: Array = records.get("championship_tournament_ids", []) if typeof(records.get("championship_tournament_ids", [])) == TYPE_ARRAY else []
	var title_already_recorded: bool = tournament_id != "" and title_ids.has(tournament_id)

	if tournament_id != "" and not title_already_recorded:
		title_ids.append(tournament_id)

	var should_increment_title: bool = not title_already_recorded
	if tournament_id == "":
		should_increment_title = bool(context.get("force_title_increment", true))

	var title_key: String = _bending_championship_title_key(tournament)
	var title_label: String = _bending_championship_title_label(tournament)
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	if division == "":
		division = "world"

	var title_counts: Dictionary = _safe_dictionary(records.get("championship_title_counts", {}))
	var by_division: Dictionary = _safe_dictionary(records.get("championships_by_division", {}))
	var by_label: Dictionary = _safe_dictionary(records.get("championships_by_label", {}))

	if should_increment_title:
		records ["championships"] = max(0, int(records.get("championships", 0))) + 1
		title_counts [title_key] = int(title_counts.get(title_key, 0)) + 1
		by_division [division] = int(by_division.get(division, 0)) + 1
		by_label [title_label] = int(by_label.get(title_label, 0)) + 1
	else:
		records ["championships"] = max(1, int(records.get("championships", 0)))
		if int(title_counts.get(title_key, 0)) <= 0:
			title_counts [title_key] = 1
		if int(by_division.get(division, 0)) <= 0:
			by_division [division] = 1
		if int(by_label.get(title_label, 0)) <= 0:
			by_label [title_label] = 1

	var year_value: int = int(tournament.get("year", int(gs.year) if gs != null else 0))
	var years: Array = records.get("championship_years", []) if typeof(records.get("championship_years", [])) == TYPE_ARRAY else []
	if year_value not in years:
		years.append(year_value)
	years.sort()

	var actual_completed_wins: int = _bending_completed_real_wins_for_tournament(winner, tournament)
	var allow_historical_floor: bool = bool(context.get("bootstrap", false)) or bool(context.get("historical_backfill", false)) or bool(context.get("historical_seed", false))

	if allow_historical_floor:
		var historical_floor: int = max(3, actual_completed_wins)
		if str(tournament.get("division", "")).strip_edges().to_lower() == "masters":
			historical_floor = max(2, actual_completed_wins)

		if int(tournament_bucket.get("wins", 0)) < historical_floor:
			var missing_historical_wins: int = historical_floor - int(tournament_bucket.get("wins", 0))
			tournament_bucket ["wins"] = int(tournament_bucket.get("wins", 0)) + missing_historical_wins
			overall_bucket ["wins"] = int(overall_bucket.get("wins", 0)) + missing_historical_wins
	else:
		if actual_completed_wins > 0 and int(tournament_bucket.get("wins", 0)) < actual_completed_wins:
			var missing_actual_wins: int = actual_completed_wins - int(tournament_bucket.get("wins", 0))
			tournament_bucket ["wins"] = int(tournament_bucket.get("wins", 0)) + missing_actual_wins
			overall_bucket ["wins"] = int(overall_bucket.get("wins", 0)) + missing_actual_wins

	records ["tournament"] = tournament_bucket
	records ["overall"] = overall_bucket
	records ["championship_years"] = years
	records ["championship_tournament_ids"] = title_ids
	records ["championship_title_counts"] = title_counts
	records ["championships_by_division"] = by_division
	records ["championships_by_label"] = by_label
	records ["championship_title_rows"] = _bending_championship_title_rows_for_counts(title_counts)
	records ["championship_title_summary"] = _bending_championship_title_summary_for_records(records)
	records ["last_updated_year"] = int(gs.year) if gs != null else 0

	winner.bending_duel_records = _normalize_bending_duel_records(records)


func _register_bending_tournament_history_result(winner: Person, tournament: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or winner == null or tournament.is_empty():
		return

	var state: Dictionary = _bending_world_state()
	var history: Array = state.get("tournament_history", [])
	var tournament_id: String = str(tournament.get("id", "")).strip_edges()

	for raw_row in history:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var existing: Dictionary = raw_row
		if str(existing.get("tournament_id", "")) == tournament_id:
			return

	var records: Dictionary = _ensure_bending_duel_records(winner)
	var tournament_record: Dictionary = records.get("tournament", {})
	var overall_record: Dictionary = records.get("overall", {})
	var year_value: int = int(tournament.get("year", int(gs.year)))
	var dojo_affiliation: Dictionary = _bending_dojo_affiliation_for_actor(winner)

	history.append({
		"schema": "eralife.bending_tournament_history_result",
		"version": 2,
		"tournament_id": tournament_id,
		"year": year_value,
		"year_label": _format_avatar_world_year(year_value),
		"division": str(tournament.get("division", "")),
		"requested_division": str(tournament.get("requested_division", "")),
		"label": str(tournament.get("label", "Bending World Championship")),
		"champion_id": int(winner.id),
		"champion_name": _bending_person_label(winner),
		"champion_element": _bending_person_primary_element(winner),
		"champion_bloodline": str(winner.last_name).strip_edges(),
		"champion_tournament_record": tournament_record.duplicate(true),
		"champion_overall_record": overall_record.duplicate(true),
		"dojo_id": str(dojo_affiliation.get("dojo_id", "")),
		"dojo_name": str(dojo_affiliation.get("dojo_name", "")),
		"entry_affiliation": "dojo" if not dojo_affiliation.is_empty() else "solo",
		"simulated": bool(context.get("simulated", false)),
		"bootstrap": bool(context.get("bootstrap", false))
	})

	history.sort_custom(func (a, b):
		return int(a.get("year", 0)) > int(b.get("year", 0))
	)

	while history.size() > 80:
		history.pop_back()

	state ["tournament_history"] = history
	gs.scenario_state ["bending_world_championship"] = state

	_sync_bending_tournament_history_world_feed()
func _bending_dojo_affiliation_for_actor(actor: Person) -> Dictionary:
	if actor == null or gs == null:
		return {}

	if not ("bending_dojo_engine" in gs):
		return {}

	if gs.bending_dojo_engine == null:
		return {}

	if not gs.bending_dojo_engine.has_method("get_actor_dojo_membership"):
		return {}

	return gs.bending_dojo_engine.get_actor_dojo_membership(actor)


func _push_bending_tournament_champion_world_feed(winner: Person, tournament: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or winner == null or tournament.is_empty():
		return

	if not gs.has_method("push_world_feed"):
		return

	var state: Dictionary = _bending_world_state()
	var feed_index: Dictionary = _safe_dictionary(state.get("tournament_world_feed_index", {}))
	var tournament_id: String = str(tournament.get("id", "")).strip_edges()
	var year_value: int = int(tournament.get("year", int(gs.year)))
	var feed_key: String = "%s:%d" % [tournament_id, year_value]

	if feed_key.strip_edges() == ":":
		return

	if feed_index.has(feed_key):
		return

	var dojo_affiliation: Dictionary = _bending_dojo_affiliation_for_actor(winner)
	var dojo_line: String = ""
	if not dojo_affiliation.is_empty():
		dojo_line = " representing %s" % str(dojo_affiliation.get("dojo_name", "their dojo"))

	gs.push_world_feed("%s won the %s%s." % [
		_bending_person_label(winner),
		str(tournament.get("label", "Bending World Championship")),
		dojo_line
	], {
		"year": year_value,
		"year_label": _format_avatar_world_year(year_value),
		"category": "bending",
		"event_name": "bending_tournament_champion",
		"source": "bending_engine",
		"personally_relevant": winner == gs.player,
		"tournament_id": tournament_id,
		"division": str(tournament.get("division", "")),
		"dojo_id": str(dojo_affiliation.get("dojo_id", "")),
		"dojo_name": str(dojo_affiliation.get("dojo_name", "")),
		"entry_affiliation": "dojo" if not dojo_affiliation.is_empty() else "solo",
		"historical_backfill": year_value < int(gs.year),
		"simulated": bool(context.get("simulated", false))
	})

	feed_index [feed_key] = {
		"tournament_id": tournament_id,
		"year": year_value,
		"pushed_at_ms": int(Time.get_ticks_msec())
	}

	state ["tournament_world_feed_index"] = feed_index
	gs.scenario_state ["bending_world_championship"] = state


func _sync_bending_tournament_history_world_feed() -> void:
	if gs == null or not gs.has_method("push_world_feed"):
		return

	var policy: Dictionary = _bending_world_policy()
	var history_policy: Dictionary = _safe_dictionary(policy.get("history", {}))
	if not bool(history_policy.get("world_feed_backfill_enabled", true)):
		return

	var state: Dictionary = _bending_world_state()
	var history: Array = state.get("tournament_history", [])
	var feed_index: Dictionary = _safe_dictionary(state.get("tournament_world_feed_index", {}))
	var year_limit: int = max(1, int(history_policy.get("world_feed_backfill_year_count", 8)))
	var per_year_limit: int = max(1, int(history_policy.get("world_feed_backfill_max_entries_per_year", 8)))
	var year_order: Array = []
	var per_year_counts: Dictionary = {}

	for raw_row in history:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var year_value: int = int(row.get("year", int(gs.year)))

		if not year_order.has(year_value):
			if year_order.size() >= year_limit:
				continue
			year_order.append(year_value)

		var year_key: String = str(year_value)
		var count_for_year: int = int(per_year_counts.get(year_key, 0))
		if count_for_year >= per_year_limit:
			continue

		var tournament_id: String = str(row.get("tournament_id", "")).strip_edges()
		var feed_key: String = "%s:%d" % [tournament_id, year_value]
		if feed_key.strip_edges() == ":":
			continue

		if feed_index.has(feed_key):
			continue

		var dojo_name: String = str(row.get("dojo_name", "")).strip_edges()
		var dojo_line: String = ""
		if dojo_name != "":
			dojo_line = " representing %s" % dojo_name

		gs.push_world_feed("%s won the %s%s." % [
			str(row.get("champion_name", "An unknown bender")),
			str(row.get("label", "Bending World Championship")),
			dojo_line
		], {
			"year": year_value,
			"year_label": str(row.get("year_label", _format_avatar_world_year(year_value))),
			"category": "bending",
			"event_name": "bending_tournament_champion",
			"source": "bending_engine_history_backfill",
			"personally_relevant": false,
			"tournament_id": tournament_id,
			"division": str(row.get("division", "")),
			"dojo_id": str(row.get("dojo_id", "")),
			"dojo_name": dojo_name,
			"entry_affiliation": str(row.get("entry_affiliation", "solo")),
			"historical_backfill": year_value < int(gs.year),
			"simulated": bool(row.get("simulated", false)),
			"bootstrap": bool(row.get("bootstrap", false))
		})

		feed_index [feed_key] = {
			"tournament_id": tournament_id,
			"year": year_value,
			"pushed_at_ms": int(Time.get_ticks_msec()),
			"source": "history_backfill"
		}

		per_year_counts [year_key] = count_for_year + 1

	state ["tournament_world_feed_index"] = feed_index
	gs.scenario_state ["bending_world_championship"] = state


func _bending_recordboard_score(row: Dictionary) -> float:
	var wins: int = int(row.get("wins", 0))
	var losses: int = int(row.get("losses", 0))
	var fights: int = max(1, wins + losses)
	var win_pct: float = float(wins) / float(fights)
	var kos: int = int(row.get("kos", 0))
	var championships: int = int(row.get("championships", 0))
	return (float(championships) * 100000.0) + (float(wins) * 1000.0) + (win_pct * 500.0) + (float(kos) * 12.0) - float(losses)


func _bending_recordboard_row(actor: Person, bucket_key: String) -> Dictionary:
	var records: Dictionary = _ensure_bending_duel_records(actor)
	var bucket: Dictionary = records.get(bucket_key, {}) if bucket_key in ["overall", "tournament", "non_tournament"] else records.get("overall", {})
	var wins: int = int(bucket.get("wins", 0))
	var losses: int = int(bucket.get("losses", 0))
	var fights: int = max(1, wins + losses)
	var win_pct: float = float(wins) / float(fights)

	return {
		"schema": "eralife.bending_recordboard_row",
		"version": 1,
		"person_id": int(actor.id),
		"name": _bending_person_label(actor),
		"age": int(actor.age),
		"element": _bending_person_primary_element(actor),
		"bloodline": str(actor.last_name).strip_edges(),
		"bucket": bucket_key,
		"wins": wins,
		"losses": losses,
		"kos": int(bucket.get("kos", 0)),
		"deaths": int(bucket.get("deaths", 0)),
		"win_pct": win_pct,
		"championships": int(records.get("championships", 0)),
		"championship_years": records.get("championship_years", []) if typeof(records.get("championship_years", [])) == TYPE_ARRAY else [],
		"score": _bending_recordboard_score({
			"wins": wins,
			"losses": losses,
			"kos": int(bucket.get("kos", 0)),
			"championships": int(records.get("championships", 0))
		})
	}


func _refresh_bending_tournament_recordboards(extra_people: Array = []) -> void:
	if gs == null:
		return

	var state: Dictionary = _bending_world_state()
	var candidates: Array = []

	if gs.player != null:
		candidates.append(gs.player)

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc != null:
				candidates.append(raw_npc)

	for raw_extra in extra_people:
		if raw_extra != null:
			candidates.append(raw_extra)

	var unique: Dictionary = {}
	var overall_rows: Array = []
	var tournament_rows: Array = []
	var non_tournament_rows: Array = []
	var championship_rows: Array = []

	for raw_actor in candidates:
		if raw_actor == null:
			continue

		var actor: Person = raw_actor
		if unique.has(int(actor.id)):
			continue
		unique [int(actor.id)] = true

		if str(actor.bending_type).strip_edges().to_lower() == "none":
			continue

		var records: Dictionary = _ensure_bending_duel_records(actor)
		var overall: Dictionary = records.get("overall", {})
		if int(overall.get("wins", 0)) + int(overall.get("losses", 0)) <= 0:
			continue

		overall_rows.append(_bending_recordboard_row(actor, "overall"))
		tournament_rows.append(_bending_recordboard_row(actor, "tournament"))
		non_tournament_rows.append(_bending_recordboard_row(actor, "non_tournament"))

		if int(records.get("championships", 0)) > 0:
			championship_rows.append(_bending_recordboard_row(actor, "overall"))

	overall_rows.sort_custom(func (a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	tournament_rows.sort_custom(func (a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	non_tournament_rows.sort_custom(func (a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	championship_rows.sort_custom(func (a, b):
		if int(a.get("championships", 0)) != int(b.get("championships", 0)):
			return int(a.get("championships", 0)) > int(b.get("championships", 0))
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var limit: int = max(5, int(_safe_dictionary(_bending_world_policy().get("history", {})).get("recordboard_limit", 5)))
	state ["tournament_recordboard"] = {
		"overall": overall_rows.slice(0, min(limit, overall_rows.size())),
		"tournament": tournament_rows.slice(0, min(limit, tournament_rows.size())),
		"non_tournament": non_tournament_rows.slice(0, min(limit, non_tournament_rows.size())),
		"championships": championship_rows.slice(0, min(limit, championship_rows.size()))
	}
	gs.scenario_state ["bending_world_championship"] = state


func get_bending_tournament_history_payload(actor: Person = null) -> Dictionary:
	_ensure_bending_world_bootstrap({
		"source": "tournament_history_payload"
	})
	_refresh_bending_tournament_recordboards([])

	var state: Dictionary = _bending_world_state()
	var policy: Dictionary = _bending_world_policy()
	var history_policy: Dictionary = _safe_dictionary(policy.get("history", {}))
	var visible_count: int = max(5, int(history_policy.get("visible_recent_tournament_count", 5)))

	var history: Array = state.get("tournament_history", [])
	var recent: Array = []
	for raw_row in history:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		recent.append(raw_row.duplicate(true))
		if recent.size() >= visible_count:
			break

	var archive_payload: Dictionary = get_bending_match_archive_payload(actor, {
		"source": "tournament_history_payload",
		"limit": 24
	})

	return {
		"schema": "eralife.bending_tournament_history_payload",
		"version": 2,
		"actor_id": int(actor.id) if actor != null else -1,
		"year": int(gs.year) if gs != null else 0,
		"recent_winners": recent,
		"recordboards": state.get("tournament_recordboard", {}).duplicate(true),
		"tournament_of_champions_bids": state.get("tournament_of_champions_bids", {}).duplicate(true),
		"cycle_position": _bending_tournament_cycle_position(int(gs.year) if gs != null else 0, 5),
		"match_archive_payload": archive_payload.duplicate(true),
		"historic_matches": archive_payload.get("historic_matches", []),
		"pre_birth_matches": archive_payload.get("pre_birth_matches", []),
		"style_echoes": archive_payload.get("style_echoes", []),
		"mythic_matches": archive_payload.get("mythic_matches", [])
	}
func get_bending_match_archive_payload(actor: Person = null, options: Dictionary = {}) -> Dictionary:
	_ensure_bending_world_bootstrap({
		"source": str(options.get("source", "match_archive_payload"))
	})

	var state: Dictionary = _bending_world_state()
	var archive: Array = _safe_array(state.get("match_archive", []))
	var style_echo_index: Dictionary = _safe_dictionary(state.get("style_echo_index", {}))
	var limit: int = max(5, int(options.get("limit", 20)))

	var actor_id: int = int(actor.id) if actor != null else -1
	var actor_birth_year: int = int(gs.year) - int(actor.age) if gs != null and actor != null else -999999

	var actor_matches: Array = []
	var pre_birth_matches: Array = []
	var historic_matches: Array = []
	var mythic_matches: Array = []

	for raw_row in archive:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row.duplicate(true)
		var participant_ids: Array = _safe_array(row.get("participant_ids", []))
		var year_value: int = int(row.get("year", 0))
		var legendary_score: int = int(row.get("legendary_score", 0))

		if actor_id >= 0 and participant_ids.has(actor_id):
			actor_matches.append(row)

		if actor != null and year_value < actor_birth_year:
			pre_birth_matches.append(row)

		if bool(row.get("historic", false)) or legendary_score >= 35:
			historic_matches.append(row)

		if bool(row.get("mythic", false)) or legendary_score >= 55:
			mythic_matches.append(row)

	actor_matches.sort_custom(func (a, b):
		return int(a.get("year", 0)) > int(b.get("year", 0))
	)
	pre_birth_matches.sort_custom(func (a, b):
		return int(a.get("legendary_score", 0)) > int(b.get("legendary_score", 0))
	)
	historic_matches.sort_custom(func (a, b):
		return int(a.get("legendary_score", 0)) > int(b.get("legendary_score", 0))
	)
	mythic_matches.sort_custom(func (a, b):
		return int(a.get("legendary_score", 0)) > int(b.get("legendary_score", 0))
	)

	var style_echoes: Array = []
	for echo_key in style_echo_index.keys():
		var echo_row: Dictionary = _safe_dictionary(style_echo_index.get(echo_key, {}))
		if echo_row.is_empty():
			continue
		style_echoes.append(echo_row.duplicate(true))

	style_echoes.sort_custom(func (a, b):
		return int(a.get("echo_heat", 0)) > int(b.get("echo_heat", 0))
	)

	return {
		"schema": "eralife.bending_match_archive_payload",
		"version": 1,
		"actor_id": actor_id,
		"actor_name": _bending_person_label(actor) if actor != null else "",
		"year": int(gs.year) if gs != null else 0,
		"actor_birth_year": actor_birth_year,
		"actor_matches": actor_matches.slice(0, min(limit, actor_matches.size())),
		"pre_birth_matches": pre_birth_matches.slice(0, min(limit, pre_birth_matches.size())),
		"historic_matches": historic_matches.slice(0, min(limit, historic_matches.size())),
		"mythic_matches": mythic_matches.slice(0, min(limit, mythic_matches.size())),
		"style_echoes": style_echoes.slice(0, min(limit, style_echoes.size())),
		"archive_count": archive.size()
	}


func get_bending_match_replay_payload(match_id: String, _options: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(match_id).strip_edges()
	if clean_id == "":
		return {
			"success": false,
			"popup_title": "Match Archive",
			"popup_text": "No archived match id was provided.",
			"popup_footer": "Tap anywhere to continue."
		}

	var state: Dictionary = _bending_world_state()
	var archive: Array = _safe_array(state.get("match_archive", []))

	for raw_row in archive:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		if str(row.get("match_id", "")).strip_edges() != clean_id:
			continue

		var frames: Array = _safe_array(row.get("spectator_frames", []))
		if frames.is_empty():
			frames = _bending_replay_frames_from_archive_row(row)

		var title: String = str(row.get("title", "Archived Bending Match"))
		var summary: String = str(row.get("summary", "The archive remembers this fight."))

		if frames.is_empty():
			return {
				"success": true,
				"uses_scenario_panel": true,
				"spectator_frames": [],
				"panel_title": title,
				"text": summary,
				"footer_text": "Archived match replay.",
				"opps": [],
				"popup_title": "Archived Match",
				"popup_text": summary,
				"popup_footer": "Tap anywhere to continue.",
				"archive_row": row.duplicate(true)
			}

		return {
			"success": true,
			"uses_scenario_panel": true,
			"spectator_frames": frames.duplicate(true),
			"panel_title": title,
			"text": str(frames [0].get("text", summary)),
			"footer_text": "Archived match replay from the opening exchange.",
			"combat_ui": frames [0].get("combat_ui", {}),
			"opps": frames [0].get("opps", []),
			"popup_title": "Archived Match",
			"popup_text": summary,
			"popup_footer": "Tap anywhere to continue.",
			"archive_row": row.duplicate(true)
		}

	return {
		"success": false,
		"popup_title": "Match Not Found",
		"popup_text": "That archived match could not be found.",
		"popup_footer": "Tap anywhere to continue."
	}
func _bending_replay_frames_from_archive_row(row: Dictionary) -> Array:
	var out: Array = []
	var exchanges: Array = _safe_array(row.get("exchanges", []))
	if exchanges.is_empty():
		return out

	var winner_name: String = str(row.get("winner_name", "Winner"))
	var loser_name: String = str(row.get("loser_name", "Loser"))
	var winner_id: int = int(row.get("winner_id", -1))
	var loser_id: int = int(row.get("loser_id", -1))

	var fighter_a_id: int = int(row.get("fighter_a_id", winner_id))
	var fighter_b_id: int = int(row.get("fighter_b_id", loser_id))
	var fighter_a_name: String = str(row.get("fighter_a_name", winner_name)).strip_edges()
	var fighter_b_name: String = str(row.get("fighter_b_name", loser_name)).strip_edges()
	if fighter_a_name == "":
		fighter_a_name = winner_name
	if fighter_b_name == "":
		fighter_b_name = loser_name

	var fighter_a: Person = _find_person_by_id(fighter_a_id)
	var fighter_b: Person = _find_person_by_id(fighter_b_id)
	var a_hp_max: int = max(45, int(row.get("fighter_a_hp_max", int(fighter_a.health) if fighter_a != null else 100)))
	var b_hp_max: int = max(45, int(row.get("fighter_b_hp_max", int(fighter_b.health) if fighter_b != null else 100)))

	out.append({
		"panel_title": "ARCHIVED BENDING MATCH — REWATCH",
		"text": "%s vs %s begins again from the archive.\n\nThe record is replaying from the first remembered exchange, not just the final result." % [
			fighter_a_name,
			fighter_b_name
		],
		"footer_text": "Archived replay starting from the beginning.",
		"combat_ui": {
			"visible": true,
			"theme": "bending",
			"status_text": "Opening stance",
			"player_label": fighter_a_name,
			"player_value": a_hp_max,
			"player_max": a_hp_max,
			"enemy_label": fighter_b_name,
			"enemy_value": b_hp_max,
			"enemy_max": b_hp_max,
			"impact_shake": false
		},
		"opps": []
	})

	var last_a_hp: int = a_hp_max
	var last_b_hp: int = b_hp_max

	for raw_exchange in exchanges:
		if typeof(raw_exchange) != TYPE_DICTIONARY:
			continue

		var exchange: Dictionary = raw_exchange
		var exchange_index: int = int(exchange.get("exchange", out.size()))
		var a_move: String = str(exchange.get("fighter_a_move", "bending pressure"))
		var b_move: String = str(exchange.get("fighter_b_move", "defensive read"))
		var chosen_side: String = str(exchange.get("exchange_winner_side", ""))
		var chosen_move: String = str(exchange.get("chosen_move", ""))
		var next_a_hp: int = clamp(int(exchange.get("fighter_a_hp", last_a_hp)), 0, a_hp_max)
		var next_b_hp: int = clamp(int(exchange.get("fighter_b_hp", last_b_hp)), 0, b_hp_max)

		var damage_to_a: int = max(0, last_a_hp - next_a_hp)
		var damage_to_b: int = max(0, last_b_hp - next_b_hp)

		var exchange_text: String = "Exchange %d\n\n%s used %s.\n%s answered with %s." % [
			exchange_index,
			fighter_a_name,
			a_move,
			fighter_b_name,
			b_move
		]

		if damage_to_b > 0:
			exchange_text += "\n\n%s lost %d health." % [fighter_b_name, damage_to_b]
		elif damage_to_a > 0:
			exchange_text += "\n\n%s lost %d health." % [fighter_a_name, damage_to_a]
		else:
			exchange_text += "\n\nNeither fighter landed clean damage in that beat."

		if chosen_move != "":
			exchange_text += "\n\nThe archive marks %s as the exchange-breaking decision." % chosen_move

		out.append({
			"panel_title": "ARCHIVED BENDING MATCH — REWATCH",
			"text": exchange_text,
			"footer_text": "Archived replay • move-for-move memory",
			"combat_ui": {
				"visible": true,
				"theme": "bending",
				"status_text": "Exchange %d" % exchange_index,
				"player_label": fighter_a_name,
				"player_value": next_a_hp,
				"player_max": a_hp_max,
				"enemy_label": fighter_b_name,
				"enemy_value": next_b_hp,
				"enemy_max": b_hp_max,
				"impact_shake": true,
				"impact_shake_amount": 6.0
			},
			"opps": [
				{
					"label": "%s: %s" % [fighter_a_name, a_move],
					"disabled": true,
					"button_theme": "bending_ability",
					"power_source": "bending",
					"spectator_chosen": chosen_side == "fighter_a"
				},
				{
					"label": "%s: %s" % [fighter_b_name, b_move],
					"disabled": true,
					"button_theme": "defensive_escape",
					"power_source": "bending",
					"spectator_chosen": chosen_side == "fighter_b"
				},
				{
					"label": "Damage: %s / %s" % [str(damage_to_a), str(damage_to_b)],
					"disabled": true,
					"button_theme": "artifact_action",
					"power_source": "knowledge"
				}
			]
		})

		last_a_hp = next_a_hp
		last_b_hp = next_b_hp

	var finish_move: String = str(row.get("finish_move", "a finishing technique"))
	out.append({
		"panel_title": "ARCHIVED BENDING MATCH — REWATCH",
		"text": "%s defeated %s with %s.\n\nThe archive marks that as the winning technique before anything else happened after the duel was already decided." % [
			winner_name,
			loser_name,
			finish_move
		],
		"footer_text": "Archived replay complete.",
		"combat_ui": {
			"visible": true,
			"theme": "bending",
			"status_text": "Winning technique remembered",
			"player_label": fighter_a_name,
			"player_value": last_a_hp,
			"player_max": a_hp_max,
			"enemy_label": fighter_b_name,
			"enemy_value": last_b_hp,
			"enemy_max": b_hp_max,
			"impact_shake": true,
			"impact_shake_amount": 8.0
		},
		"opps": [
			{
				"label": "Winner: %s" % winner_name,
				"disabled": true,
				"button_theme": "bending_ability",
				"power_source": "bending",
			},
			{
				"label": "Finish: %s" % finish_move,
				"disabled": true,
				"button_theme": "artifact_action",
				"power_source": "knowledge"
			}
		]
	})

	if bool(row.get("death", false)):
		var death_report: Dictionary = _safe_dictionary(row.get("death_report", {}))
		var fatality_text: String = "%s had already won.\n\nThen %s chose not to spare %s.\n\nFatality: %s." % [
			winner_name,
			winner_name,
			loser_name,
			finish_move
		]
		var cause: String = str(death_report.get("cause", "")).strip_edges()
		if cause != "":
			fatality_text += "\n\nCause: %s" % cause

		out.append({
			"panel_title": "ARCHIVED BENDING MATCH — REWATCH",
			"text": fatality_text,
			"footer_text": "Archived replay • post-win fatality remembered",
			"combat_ui": {
				"visible": true,
				"theme": "bending",
				"status_text": "Fatality remembered",
				"player_label": fighter_a_name,
				"player_value": last_a_hp,
				"player_max": a_hp_max,
				"enemy_label": fighter_b_name,
				"enemy_value": last_b_hp,
				"enemy_max": b_hp_max,
				"impact_shake": true,
				"impact_shake_amount": 10.0
			},
			"opps": [
				{
					"label": "Winner: %s" % winner_name,
					"disabled": true,
					"button_theme": "bending_ability",
					"power_source": "bending",
				},
				{
					"label": "Mercy: KILL",
					"disabled": true,
					"button_theme": "bending_duel_mercy",
					"power_source": "bending",
				},
				{
					"label": "Fatality: %s" % finish_move,
					"disabled": true,
					"button_theme": "artifact_action",
					"power_source": "knowledge"
				}
			]
		})

	return out
func _is_agni_kai_eligible(actor: Person) -> bool:
	if actor == null:
		return false
	if not bool(actor.alive):
		return false
	if int(actor.age) < 10:
		return false

	var nation: String = str(actor.bending_nation).strip_edges().to_lower()
	if nation != "fire nation":
		return false

	var element: String = _bending_person_primary_element(actor)
	if element == "avatar":
		element = _element_from_nation(str(actor.bending_nation))

	return element == "fire"


func get_bending_archival_study_report(scholar: Person, target: Person, context: Dictionary = {}) -> Dictionary:
	if scholar == null or target == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var archive: Array = _safe_array(state.get("match_archive", []))

	var target_id: int = int(target.id)
	var scholar_id: int = int(scholar.id)
	var studied_rows: Array = []
	var studied_moves: Dictionary = {}
	var revenge_pressure: int = 0
	var direct_memory: bool = false

	for raw_row in archive:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var participant_ids: Array = _safe_array(row.get("participant_ids", []))
		if not participant_ids.has(target_id):
			continue

		studied_rows.append(row.duplicate(true))

		var tendency: Dictionary = _safe_dictionary(row.get("tendency_signature", {}))
		var finish_move: String = str(tendency.get("finish_move", row.get("finish_move", ""))).strip_edges()
		if finish_move != "":
			studied_moves [finish_move] = int(studied_moves.get(finish_move, 0)) + 1

		if participant_ids.has(scholar_id):
			direct_memory = true
			if int(row.get("winner_id", -1)) == target_id:
				revenge_pressure += 4

		if str(row.get("loser_bloodline", "")).strip_edges() != "" and str(row.get("loser_bloodline", "")).strip_edges() == str(scholar.last_name).strip_edges():
			revenge_pressure += 2

	if studied_rows.is_empty():
		return {
			"schema": "eralife.bending_archival_study_report",
			"version": 1,
			"success": true,
			"scholar_id": scholar_id,
			"target_id": target_id,
			"study_count": 0,
			"bonus": 0,
			"line": "",
			"studied_moves": {}
		}

	var intelligence_bonus: int = clamp(int(float(scholar.smarts) / 18.0), 0, 6)
	var age_bonus: int = 2 if int(scholar.age) >= 10 else 0
	var archive_bonus: int = clamp(studied_rows.size(), 0, 5)
	var direct_bonus: int = 3 if direct_memory else 0
	var bonus: int = clamp(intelligence_bonus + age_bonus + archive_bonus + direct_bonus + revenge_pressure, 1, 18)

	var top_move: String = ""
	var top_count: int = 0
	for move_key in studied_moves.keys():
		var count: int = int(studied_moves.get(move_key, 0))
		if count > top_count:
			top_count = count
			top_move = str(move_key)

	var line: String = "%s studied %d archived match%s involving %s." % [
		_bending_person_label(scholar),
		studied_rows.size(),
		"" if studied_rows.size() == 1 else "es",
		_bending_person_label(target)
	]

	if top_move != "":
		line += " The archive says %s often creates danger through %s." % [
			_bending_person_label(target),
			top_move
		]

	if revenge_pressure > 0:
		line += " There is revenge pressure in the study, not just strategy."

	return {
		"schema": "eralife.bending_archival_study_report",
		"version": 1,
		"success": true,
		"scholar_id": scholar_id,
		"scholar_name": _bending_person_label(scholar),
		"target_id": target_id,
		"target_name": _bending_person_label(target),
		"study_count": studied_rows.size(),
		"bonus": bonus,
		"direct_memory": direct_memory,
		"revenge_pressure": revenge_pressure,
		"top_move": top_move,
		"studied_moves": studied_moves.duplicate(true),
		"line": line,
		"source": str(context.get("source", "bending_archival_study"))
	}


func _record_bending_match_archive_event(winner: Person, loser: Person, context: Dictionary = {}, winner_records: Dictionary = {}, loser_records: Dictionary = {}) -> Dictionary:
	if gs == null or winner == null or loser == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var archive: Array = _safe_array(state.get("match_archive", []))
	var tournament_id: String = str(context.get("tournament_id", "")).strip_edges()
	var tournament_match_id: String = str(context.get("tournament_match_id", "")).strip_edges()
	var match_id: String = str(context.get("archive_match_id", "")).strip_edges()
	if match_id == "":
		if tournament_id != "" and tournament_match_id != "":
			match_id = "%s_%s" % [tournament_id, tournament_match_id]
		else:
			match_id = "bending_match_%d_%d_%d" % [int(winner.id), int(loser.id), int(Time.get_ticks_msec())]

	for raw_existing in archive:
		if typeof(raw_existing) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = raw_existing
		if str(existing.get("match_id", "")) == match_id:
			return {
				"success": true,
				"duplicate": true,
				"match_id": match_id
			}

	var match_payload: Dictionary = _safe_dictionary(context.get("match_payload", {}))
	var duel_state: Dictionary = _safe_dictionary(context.get("duel", {}))
	var frames: Array = _safe_array(match_payload.get("spectator_frames", []))
	var exchanges: Array = _safe_array(match_payload.get("exchanges", duel_state.get("exchange_memory", [])))

	var fighter_a_id: int = int(match_payload.get("fighter_a_id", int(winner.id)))
	var fighter_b_id: int = int(match_payload.get("fighter_b_id", int(loser.id)))
	var fighter_a_person: Person = _find_person_by_id(fighter_a_id)
	var fighter_b_person: Person = _find_person_by_id(fighter_b_id)
	var fighter_a_name: String = _bending_person_label(fighter_a_person) if fighter_a_person != null else _bending_person_label(winner if fighter_a_id == int(winner.id) else loser)
	var fighter_b_name: String = _bending_person_label(fighter_b_person) if fighter_b_person != null else _bending_person_label(loser if fighter_b_id == int(loser.id) else winner)
	var fighter_a_hp_max: int = max(1, int(match_payload.get("fighter_a_hp_max", 100)))
	var fighter_b_hp_max: int = max(1, int(match_payload.get("fighter_b_hp_max", 100)))

	var winner_style: Dictionary = get_competitive_style_identity(winner, {
		"source": "match_archive_winner"
	})
	var loser_style: Dictionary = get_competitive_style_identity(loser, {
		"source": "match_archive_loser"
	})
	var year_value: int = int(gs.year) if gs != null else int(context.get("year", 0))
	var finish_move: String = str(context.get("finish_move", match_payload.get("finish_move", "a finishing technique"))).strip_edges()
	var winner_dojo: Dictionary = _bending_dojo_affiliation_for_actor(winner)
	var loser_dojo: Dictionary = _bending_dojo_affiliation_for_actor(loser)
	var tendency_signature: Dictionary = _bending_match_tendency_signature(winner, loser, finish_move, exchanges, context)
	var legendary_score: int = _bending_match_legendary_score(winner, loser, context, winner_records, loser_records, frames, exchanges)
	var title: String = "%s vs %s" % [
		_bending_person_label(winner),
		_bending_person_label(loser)
	]
	var summary: String = "%s defeated %s with %s." % [
		_bending_person_label(winner),
		_bending_person_label(loser),
		finish_move
	]

	var row: Dictionary = {
		"schema": "eralife.bending_match_archive_row",
		"version": 1,
		"match_id": match_id,
		"title": title,
		"summary": summary,
		"year": year_value,
		"year_label": _format_avatar_world_year(year_value),

		"fighter_a_id": fighter_a_id,
		"fighter_a_name": fighter_a_name,
		"fighter_a_hp_max": fighter_a_hp_max,
		"fighter_b_id": fighter_b_id,
		"fighter_b_name": fighter_b_name,
		"fighter_b_hp_max": fighter_b_hp_max,

		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"winner_element": _bending_person_primary_element(winner),
		"winner_bloodline": str(winner.last_name).strip_edges(),
		"winner_style": winner_style.duplicate(true),
		"winner_dojo_id": str(winner_dojo.get("dojo_id", "")),
		"winner_dojo_name": str(winner_dojo.get("dojo_name", "")),

		"loser_id": int(loser.id),
		"loser_name": _bending_person_label(loser),
		"loser_element": _bending_person_primary_element(loser),
		"loser_bloodline": str(loser.last_name).strip_edges(),
		"loser_style": loser_style.duplicate(true),
		"loser_dojo_id": str(loser_dojo.get("dojo_id", "")),
		"loser_dojo_name": str(loser_dojo.get("dojo_name", "")),

		"participant_ids": [int(winner.id), int(loser.id)],
		"finish_move": finish_move,
		"tournament": bool(context.get("tournament", false)),
		"tournament_id": tournament_id,
		"tournament_match_id": tournament_match_id,
		"tournament_division": str(context.get("tournament_division", "")),
		"source": str(context.get("source", "bending_duel_result")),
		"simulated": bool(context.get("simulated", false)),
		"ko": bool(context.get("ko", false)),
		"death": bool(context.get("death", false)),
		"mercy_action": str(context.get("mercy_action", match_payload.get("mercy_action", ""))),
		"mercy_decision": _safe_dictionary(context.get("mercy_decision", match_payload.get("mercy_decision", {}))),
		"death_report": _safe_dictionary(context.get("death_report", match_payload.get("death_report", {}))),
		"spectator_frames": frames.duplicate(true),
		"exchanges": exchanges.duplicate(true),
		"tendency_signature": tendency_signature.duplicate(true),
		"legendary_score": legendary_score,
		"historic": legendary_score >= 35,
		"mythic": legendary_score >= 55,
		"myth_line": _bending_match_myth_line(winner, loser, finish_move, legendary_score, context),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	archive.append(row)
	archive.sort_custom(func (a, b):
		if int(a.get("year", 0)) == int(b.get("year", 0)):
			return int(a.get("created_at_ms", 0)) > int(b.get("created_at_ms", 0))
		return int(a.get("year", 0)) > int(b.get("year", 0))
	)

	var max_archive_size: int = int(_bending_match_archive_policy().get("max_match_archive_size", 240))
	while archive.size() > max_archive_size:
		archive.pop_back()

	state ["match_archive"] = archive
	gs.scenario_state ["bending_world_championship"] = state
	_apply_bending_style_echo_from_archive_row(row)

	return {
		"success": true,
		"match_id": match_id,
		"legendary_score": legendary_score,
		"historic": bool(row.get("historic", false)),
		"mythic": bool(row.get("mythic", false)),
		"row": row.duplicate(true)
	}


func _bending_match_archive_policy() -> Dictionary:
	var policy: Dictionary = _bending_world_policy()
	var archive_policy: Dictionary = _safe_dictionary(policy.get("match_archive", {}))

	if archive_policy.is_empty():
		archive_policy = {
			"max_match_archive_size": 240,
			"legendary_match_threshold": 35,
			"mythic_match_threshold": 55,
			"study_max_bonus": 18,
			"style_echo_decay_years": 25,
		}

	return archive_policy.duplicate(true)


func _bending_match_tendency_signature(winner: Person, loser: Person, finish_move: String, exchanges: Array, context: Dictionary = {}) -> Dictionary:
	var move_counts: Dictionary = {}
	var chosen_counts: Dictionary = {}

	for raw_exchange in exchanges:
		if typeof(raw_exchange) != TYPE_DICTIONARY:
			continue

		var exchange: Dictionary = raw_exchange
		for key in ["fighter_a_move", "fighter_b_move", "chosen_move"]:
			var move_name: String = str(exchange.get(key, "")).strip_edges()
			if move_name == "":
				continue
			move_counts [move_name] = int(move_counts.get(move_name, 0)) + 1

		var chosen_move: String = str(exchange.get("chosen_move", "")).strip_edges()
		if chosen_move != "":
			chosen_counts [chosen_move] = int(chosen_counts.get(chosen_move, 0)) + 1

	var tags: Array = []
	var finish_lower: String = finish_move.strip_edges().to_lower()

	if finish_lower.find("counter") >= 0 or finish_lower.find("reversal") >= 0:
		tags.append("counter_finisher")
	if finish_lower.find("pressure") >= 0 or finish_lower.find("flame") >= 0 or finish_lower.find("burst") >= 0:
		tags.append("pressure_finisher")
	if bool(context.get("ko", false)):
		tags.append("knockout_threat")
	if bool(context.get("death", false)):
		tags.append("lethal_legacy")

	return {
		"schema": "eralife.bending_match_tendency_signature",
		"version": 1,
		"winner_id": int(winner.id) if winner != null else -1,
		"loser_id": int(loser.id) if loser != null else -1,
		"finish_move": finish_move,
		"move_counts": move_counts.duplicate(true),
		"chosen_counts": chosen_counts.duplicate(true),
		"tags": tags
	}


func _bending_match_legendary_score(winner: Person, _loser: Person, context: Dictionary, winner_records: Dictionary, _loser_records: Dictionary, frames: Array, exchanges: Array) -> int:
	var score: int = 0

	if bool(context.get("tournament", false)):
		score += 12
	if bool(context.get("ko", false)):
		score += 8
	if bool(context.get("death", false)):
		score += 18

	score += clamp(int(float(winner.fame) / 4.0), 0, 25)
	score += clamp(int(_safe_array(exchanges).size() * 2), 0, 18)
	score += clamp(int(_safe_array(frames).size()), 0, 12)

	var winner_overall: Dictionary = _safe_dictionary(winner_records.get("overall", {}))
	score += clamp(int(winner_overall.get("wins", 0)), 0, 20)
	score += clamp(int(winner_overall.get("kos", 0)) * 2, 0, 20)

	if str(context.get("tournament_match_id", "")).strip_edges().find("final") >= 0:
		score += 10

	return clamp(score, 0, 100)


func _bending_match_myth_line(winner: Person, loser: Person, finish_move: String, legendary_score: int, context: Dictionary = {}) -> String:
	if legendary_score >= 75:
		return "Still spoken about as one of the defining bending fights of its era."
	if legendary_score >= 55:
		return "%s became mythic after finishing %s with %s." % [
			_bending_person_label(winner),
			_bending_person_label(loser),
			finish_move
		]
	if legendary_score >= 35:
		return "Historians still cite this match when discussing %s's rise." % _bending_person_label(winner)
	if bool(context.get("tournament", false)):
		return "A tournament match preserved in the official archive."
	return "A recorded duel preserved in the bending archive."


func _apply_bending_style_echo_from_archive_row(row: Dictionary) -> void:
	if gs == null or row.is_empty():
		return

	var state: Dictionary = _bending_world_state()
	var style_echo_index: Dictionary = _safe_dictionary(state.get("style_echo_index", {}))

	var winner_style: Dictionary = _safe_dictionary(row.get("winner_style", {}))
	var archetype_id: String = str(winner_style.get("archetype_id", "unknown_style")).strip_edges()
	var element: String = str(row.get("winner_element", "none")).strip_edges().to_lower()
	var dojo_id: String = str(row.get("winner_dojo_id", "")).strip_edges()
	var bloodline: String = str(row.get("winner_bloodline", "")).strip_edges()
	var nation_key: String = _bending_world_faction_for_actor(_find_person_by_id(int(row.get("winner_id", -1))))

	var echo_key: String = "%s:%s:%s:%s" % [
		element,
		archetype_id,
		dojo_id if dojo_id != "" else "solo",
		bloodline if bloodline != "" else "unknown_bloodline"
	]

	var echo_row: Dictionary = _safe_dictionary(style_echo_index.get(echo_key, {}))
	if echo_row.is_empty():
		echo_row = {
			"schema": "eralife.bending_style_echo",
			"version": 1,
			"echo_key": echo_key,
			"element": element,
			"archetype_id": archetype_id,
			"style_title": str(winner_style.get("title", "Unformed Style")),
			"dojo_id": dojo_id,
			"dojo_name": str(row.get("winner_dojo_name", "")),
			"bloodline": bloodline,
			"nation": nation_key,
			"echo_heat": 0,
			"match_ids": [],
			"finish_moves": {},
			"first_seen_year": int(row.get("year", 0)),
			"last_seen_year": int(row.get("year", 0))
		}

	echo_row ["echo_heat"] = clamp(int(echo_row.get("echo_heat", 0)) + max(1, int(float(int(row.get("legendary_score", 0))) / 5.0)), 0, 999)
	echo_row ["last_seen_year"] = max(int(echo_row.get("last_seen_year", 0)), int(row.get("year", 0)))

	var match_ids: Array = _safe_array(echo_row.get("match_ids", []))
	match_ids.append(str(row.get("match_id", "")))
	while match_ids.size() > 20:
		match_ids.pop_front()
	echo_row ["match_ids"] = match_ids

	var finish_moves: Dictionary = _safe_dictionary(echo_row.get("finish_moves", {}))
	var finish_move: String = str(row.get("finish_move", "")).strip_edges()
	if finish_move != "":
		finish_moves [finish_move] = int(finish_moves.get(finish_move, 0)) + 1
	echo_row ["finish_moves"] = finish_moves

	if int(echo_row.get("echo_heat", 0)) >= 80:
		echo_row ["myth_title"] = "This style has become a recognizable generational threat."
	elif int(echo_row.get("echo_heat", 0)) >= 45:
		echo_row ["myth_title"] = "Students are starting to copy this style across eras."
	else:
		echo_row ["myth_title"] = ""

	style_echo_index [echo_key] = echo_row
	state ["style_echo_index"] = style_echo_index
	gs.scenario_state ["bending_world_championship"] = state

func _bending_style_echo_report_for_actor(actor: Person) -> Dictionary:
	if actor == null or gs == null:
		return {}

	var state: Dictionary = _bending_world_state()
	var style_echo_index: Dictionary = _safe_dictionary(state.get("style_echo_index", {}))
	if style_echo_index.is_empty():
		return {}

	var element: String = _bending_person_primary_element(actor)
	var bloodline: String = str(actor.last_name).strip_edges()
	var dojo_affiliation: Dictionary = _bending_dojo_affiliation_for_actor(actor)
	var dojo_id: String = str(dojo_affiliation.get("dojo_id", "")).strip_edges()

	var strongest: Dictionary = {}
	for echo_key in style_echo_index.keys():
		var echo_row: Dictionary = _safe_dictionary(style_echo_index.get(echo_key, {}))
		if echo_row.is_empty():
			continue

		var matches_actor: bool = false
		if str(echo_row.get("element", "")).strip_edges().to_lower() == element:
			matches_actor = true
		if dojo_id != "" and str(echo_row.get("dojo_id", "")).strip_edges() == dojo_id:
			matches_actor = true
		if bloodline != "" and str(echo_row.get("bloodline", "")).strip_edges() == bloodline:
			matches_actor = true

		if not matches_actor:
			continue

		if strongest.is_empty() or int(echo_row.get("echo_heat", 0)) > int(strongest.get("echo_heat", 0)):
			strongest = echo_row.duplicate(true)

	if strongest.is_empty():
		return {}

	return {
		"schema": "eralife.bending_style_echo_report",
		"version": 1,
		"person_id": int(actor.id),
		"echo_key": str(strongest.get("echo_key", "")),
		"echo_heat": clamp(int(float(int(strongest.get("echo_heat", 0))) / 8.0), 0, 12),
		"raw_echo_heat": int(strongest.get("echo_heat", 0)),
		"style_title": str(strongest.get("style_title", "")),
		"myth_title": str(strongest.get("myth_title", "")),
		"source_echo": strongest.duplicate(true)
	}

func _previous_avatar_reputation_seed(nation: String, offset: int, lifespan: int) -> Dictionary:
	var element: String = _element_from_nation(nation)
	var archetypes: Array = [
		{
			"id": "merciful_balancer",
			"legacy_title": "Merciful Balancer",
			"personality_shadow": "patient and restorative",
			"rule_memory": "remembered for ending conflicts without humiliating the defeated",
			"expectation_style": "people expect the next Avatar to show restraint before force",
			"spiritual_reaction": "spirits approach with cautious warmth",
			"powerful_bender_reaction": "elite benders test your mercy to see if it is discipline or weakness"
		},
		{
			"id": "iron_peacemaker",
			"legacy_title": "Iron Peacemaker",
			"personality_shadow": "stern, decisive, and feared",
			"rule_memory": "remembered for crushing wars before they could grow",
			"expectation_style": "people expect the next Avatar to control chaos quickly",
			"spiritual_reaction": "spirits watch for signs that order has become pride",
			"powerful_bender_reaction": "elite benders respect your authority but look for cracks"
		},
		{
			"id": "wandering_teacher",
			"legacy_title": "Wandering Teacher",
			"personality_shadow": "curious, warm, and unpredictable",
			"rule_memory": "remembered for teaching common people instead of courting rulers",
			"expectation_style": "people expect the next Avatar to be accessible and emotionally wise",
			"spiritual_reaction": "spirits speak in riddles, expecting you to listen",
			"powerful_bender_reaction": "elite benders underestimate you until your technique answers"
		},
		{
			"id": "storm_avatar",
			"legacy_title": "Storm Avatar",
			"personality_shadow": "bold, volatile, and legendary",
			"rule_memory": "remembered for winning impossible fights and leaving complicated damage behind",
			"expectation_style": "people expect the next Avatar to be spectacular, dangerous, and hard to contain",
			"spiritual_reaction": "spirits react strongly to your emotional swings",
			"powerful_bender_reaction": "elite benders want the smoke because the legacy sounds beatable until it is not"
		}
	]

	var index: int = abs(int(("%s:%d:%d" % [nation, offset, lifespan]).hash())) % archetypes.size()
	var row: Dictionary = archetypes [index].duplicate(true)
	var memory_strength: int = int(clamp(40.0 + (float(lifespan) / 2.0) + (float(offset) * 3.0), 20.0, 100.0))

	row ["schema"] = "eralife.previous_avatar_reputation_imprint"
	row ["version"] = 1
	row ["native_element"] = element
	row ["native_nation"] = nation
	row ["bending_style_bias"] = element
	row ["public_memory_strength"] = memory_strength
	return row

func get_previous_avatar_reputation_imprint(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return {}

	var policy: Dictionary = _bending_world_policy()
	var imprint_policy: Dictionary = _safe_dictionary(policy.get("previous_avatar_reputation_imprint", {}))
	if not bool(imprint_policy.get("enabled", true)):
		return {}

	_seed_previous_avatar_history_for_birth(actor)

	var previous: Array = _previous_avatars_for_actor(actor)
	if previous.is_empty():
		return {}

	var previous_avatar: Dictionary = previous [0]
	var imprint: Dictionary = _safe_dictionary(previous_avatar.get("reputation_imprint", {}))
	if imprint.is_empty():
		imprint = _previous_avatar_reputation_seed(
			str(previous_avatar.get("nation", "")),
			int(previous_avatar.get("lifespan", 70)),
			int(previous_avatar.get("death_year", 0))
		)

	var parent_pressure: Dictionary = _avatar_parent_style_pressure(actor)
	var comparison: Dictionary = _compare_actor_to_previous_avatar_imprint(actor, imprint, parent_pressure)
	var payload: Dictionary = {
		"schema": "eralife.previous_avatar_reputation_imprint_payload",
		"version": 1,
		"source": str(context.get("source", "bending_engine")),
		"actor_id": int(actor.id),
		"actor_name": _bending_person_label(actor),
		"previous_avatar_name": str(previous_avatar.get("name", "Previous Avatar")),
		"previous_avatar_nation": str(previous_avatar.get("nation", "")),
		"previous_avatar_native_element": str(previous_avatar.get("native_element", "")),
		"imprint": imprint.duplicate(true),
		"parent_style_pressure": parent_pressure.duplicate(true),
		"comparison": comparison.duplicate(true),
		"public_comparison_text": str(comparison.get("public_comparison_text", "")),
		"training_expectation_text": str(comparison.get("training_expectation_text", "")),
		"spiritual_reaction_text": str(comparison.get("spiritual_reaction_text", "")),
		"powerful_bender_reaction_text": str(comparison.get("powerful_bender_reaction_text", ""))
	}

	if bool(imprint_policy.get("store_on_avatar_identity_residue", true)):
		var residue: Dictionary = actor.identity_residue if typeof(actor.identity_residue) == TYPE_DICTIONARY else {}
		residue ["previous_avatar_reputation_imprint"] = payload.duplicate(true)
		actor.identity_residue = residue

	return payload


func _avatar_parent_style_pressure(actor: Person) -> Dictionary:
	var out: Dictionary = {
		"schema": "eralife.avatar_parent_style_pressure",
		"version": 1,
		"parent_elements": [],
		"dominant_parent_element": "",
		"pressure_text": ""
	}
	if actor == null:
		return out

	var counts: Dictionary = {}
	for raw_parent_id in actor.parents:
		var parent: Person = _find_person_by_id(int(raw_parent_id))
		if parent == null:
			continue

		var element: String = _bending_person_primary_element(parent)
		if element == "avatar":
			element = _element_from_nation(str(parent.bending_nation))
		if element not in _base_bending_elements():
			continue

		var parent_elements: Array = out.get("parent_elements", [])
		parent_elements.append(element)
		out ["parent_elements"] = parent_elements
		counts [element] = int(counts.get(element, 0)) + 1

	var best_element: String = ""
	var best_count: int = 0
	for raw_key in counts.keys():
		var element_key: String = str(raw_key)
		var count: int = int(counts.get(element_key, 0))
		if count > best_count:
			best_count = count
			best_element = element_key

	out ["dominant_parent_element"] = best_element
	if best_element != "":
		out ["pressure_text"] = "Your family expects your %s instincts to show early." % best_element.capitalize()

	return out


func _compare_actor_to_previous_avatar_imprint(actor: Person, imprint: Dictionary, parent_pressure: Dictionary) -> Dictionary:
	var actor_element: String = _bending_primary_style_element(actor)
	var legacy_style: String = str(imprint.get("bending_style_bias", "")).strip_edges().to_lower()
	var legacy_title: String = str(imprint.get("legacy_title", "the previous Avatar"))
	var personality_shadow: String = str(imprint.get("personality_shadow", "complicated"))
	var parent_element: String = str(parent_pressure.get("dominant_parent_element", "")).strip_edges().to_lower()

	var style_match: bool = actor_element == legacy_style and actor_element != ""
	var parent_match: bool = parent_element == actor_element and actor_element != ""
	var public_text: String = "People keep comparing you to %s, especially the way they were %s." % [
		legacy_title,
		personality_shadow
	]
	var training_text: String = "The last Avatar's legacy bends expectation around your training."

	if style_match:
		training_text += " Your %s style feels familiar to older masters, and that makes them expect results faster." % actor_element.capitalize()
	elif legacy_style != "":
		training_text += " Masters keep watching for %s instincts, even when your current style wants something different." % legacy_style.capitalize()

	if parent_match:
		training_text += " Your parents' style reinforces that pressure."
	elif parent_element != "":
		training_text += " Your parents pull your training toward %s, creating a second expectation beside the Avatar cycle." % parent_element.capitalize()

	return {
		"schema": "eralife.previous_avatar_reputation_comparison",
		"version": 1,
		"style_match": style_match,
		"parent_match": parent_match,
		"actor_style": actor_element,
		"legacy_style": legacy_style,
		"parent_style": parent_element,
		"public_comparison_text": public_text,
		"training_expectation_text": training_text,
		"spiritual_reaction_text": str(imprint.get("spiritual_reaction", "")),
		"powerful_bender_reaction_text": str(imprint.get("powerful_bender_reaction", ""))
	}
func _find_person_by_id(person_id: int) -> Person:
	if gs == null:
		return null
	if gs.player != null and int(gs.player.id) == int(person_id):
		return gs.player
	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue
			var npc: Person = raw_npc
			if int(npc.id) == int(person_id):
				return npc
	return null
func _commit_bending_tournament_duel_result(winner: Person, loser: Person, context: Dictionary = {}) -> void:
	if gs == null:
		return
	if winner == null:
		return

	var tournament_id: String = str(context.get("tournament_id", "")).strip_edges()
	var match_id: String = str(context.get("tournament_match_id", "")).strip_edges()
	if tournament_id == "" or match_id == "":
		return

	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	if not tournaments.has(tournament_id):
		return

	var tournament: Dictionary = _safe_dictionary(tournaments.get(tournament_id, {}))
	var bracket: Array = _safe_array(tournament.get("bracket", []))
	var match_found: bool = false
	var completed_round: int = 1
	var finish_move: String = _bending_finish_move_from_context(context)

	for i in range(bracket.size()):
		var raw_match: Variant = bracket [i]
		if typeof(raw_match) != TYPE_DICTIONARY:
			continue
		var match_row: Dictionary = raw_match
		if str(match_row.get("match_id", "")) != match_id:
			continue

		completed_round = int(match_row.get("round", 1))
		var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
		var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
		var fighter_a_seed: int = int(match_row.get("fighter_a_seed", 999))
		var fighter_b_seed: int = int(match_row.get("fighter_b_seed", 999))

		match_row ["status"] = "complete"
		match_row ["winner_id"] = int(winner.id)
		match_row ["winner_name"] = _bending_person_label(winner)
		if int(winner.id) == fighter_a_id:
			match_row ["winner_seed"] = fighter_a_seed
		elif int(winner.id) == fighter_b_id:
			match_row ["winner_seed"] = fighter_b_seed
		else:
			match_row ["winner_seed"] = fighter_a_seed if fighter_a_seed != 999 else fighter_b_seed

		match_row ["loser_id"] = int(loser.id) if loser != null else -1
		match_row ["loser_name"] = _bending_person_label(loser) if loser != null else "BYE"
		match_row ["completed_year"] = int(tournament.get("year", int(gs.year)))
		match_row ["simulated"] = bool(context.get("simulated", false))
		match_row ["bye"] = bool(context.get("bye", false)) or loser == null
		match_row ["finish_move"] = finish_move
		match_row ["finish_move_source"] = str(context.get("source", ""))
		match_row ["mercy_action"] = str(context.get("mercy_action", ""))
		match_row ["mercy_decision"] = _safe_dictionary(context.get("mercy_decision", {}))
		match_row ["death"] = bool(context.get("death", false))
		match_row ["death_report"] = _safe_dictionary(context.get("death_report", {}))

		if bool(match_row.get("death", false)) and loser != null:
			var dead_actor_ids: Array = _safe_array(tournament.get("dead_actor_ids", []))
			if int(loser.id) not in dead_actor_ids:
				dead_actor_ids.append(int(loser.id))
			tournament ["dead_actor_ids"] = dead_actor_ids

			var death_ledger: Array = _safe_array(tournament.get("death_ledger", []))
			var death_row: Dictionary = _safe_dictionary(match_row.get("death_report", {}))
			if death_row.is_empty():
				death_row = {
					"schema": "eralife.bending_tournament_death_record",
					"version": 1,
					"winner_id": int(winner.id),
					"winner_name": _bending_person_label(winner),
					"loser_id": int(loser.id),
					"loser_name": _bending_person_label(loser),
					"finish_move": finish_move,
					"source": str(context.get("source", "bending_tournament")),
					"year": int(gs.year) if gs != null else int(tournament.get("year", 0))
				}

			death_row ["tournament_id"] = tournament_id
			death_row ["tournament_match_id"] = match_id
			death_row ["round"] = completed_round
			death_row ["round_label"] = str(match_row.get("round_label", _bending_tournament_round_label(completed_round)))
			death_ledger.append(death_row.duplicate(true))
			while death_ledger.size() > 80:
				death_ledger.pop_front()
			tournament ["death_ledger"] = death_ledger

		bracket [i] = match_row
		match_found = true
		break

	if not match_found:
		return

	tournament ["bracket"] = bracket
	tournament ["completed_round"] = completed_round

	var round_pending: bool = _bending_tournament_round_has_pending(tournament, completed_round)
	var round_winners: Array = _bending_tournament_winners_for_round(tournament, completed_round)

	if not round_pending:
		if completed_round <= 0:
			if not _bending_tournament_has_round(tournament, 1):
				var main_seed_byes: Array = _safe_array(tournament.get("main_seed_byes", []))
				var qualified: Array = []
				for raw_bye in main_seed_byes:
					if typeof(raw_bye) == TYPE_DICTIONARY:
						qualified.append(raw_bye)
				for raw_winner in round_winners:
					if typeof(raw_winner) == TYPE_DICTIONARY:
						qualified.append(raw_winner)

				var main_round: Array = _build_bending_tournament_bracket(qualified)
				for n in range(main_round.size()):
					var next_match: Dictionary = main_round [n]
					next_match ["round"] = 1
					next_match ["round_label"] = _bending_tournament_round_label(1, qualified.size())
					next_match ["match_id"] = "r1_m%d" % [n + 1]
					bracket.append(next_match)
				tournament ["bracket"] = bracket

		elif round_winners.size() == 1:
			tournament ["status"] = "complete"
			tournament ["champion_id"] = int(winner.id)
			tournament ["champion_name"] = _bending_person_label(winner)
			tournament ["completed_year"] = int(tournament.get("year", int(gs.year)))

			_record_bending_dynasty_signal(winner, {
				"won": true,
				"tournament": true,
				"championship_title": true,
				"division": str(tournament.get("division", "")),
				"tournament_label": str(tournament.get("label", "Bending World Championship")),
				"title_key": _bending_championship_title_key(tournament),
				"title_label": _bending_championship_title_label(tournament),
				"faction": _bending_world_faction_for_actor(winner),
				"context": context.duplicate(true)
			})
			var trophy_report: Dictionary = _grant_bending_world_championship_trophy(winner, tournament)
			if not trophy_report.is_empty():
				tournament ["championship_trophy_report"] = trophy_report.duplicate(true)

			var championship_reward_report: Dictionary = _grant_bending_world_championship_win_rewards(winner, tournament, context)
			tournament ["championship_reward_report"] = championship_reward_report.duplicate(true)

			var reality_surge_report: Dictionary = _trigger_bending_championship_reality_surge(winner, tournament, trophy_report, championship_reward_report, context)
			if not reality_surge_report.is_empty():
				tournament ["reality_surge_report"] = reality_surge_report.duplicate(true)

			_apply_bending_world_celebrity_status(winner, tournament, context)
			_push_bending_tournament_result_log(winner, loser, tournament, context)
			_push_bending_media_reaction(winner, loser, tournament, context)
			_push_bending_tournament_champion_world_feed(winner, tournament, context)

		elif round_winners.size() > 1:
			var next_round: int = completed_round + 1
			if not _bending_tournament_has_round(tournament, next_round):
				var next_matches: Array = _build_bending_tournament_bracket(round_winners)
				for n in range(next_matches.size()):
					var next_match: Dictionary = next_matches [n]
					next_match ["round"] = next_round
					next_match ["round_label"] = _bending_tournament_round_label(next_round, round_winners.size())
					next_match ["match_id"] = "r%d_m%d" % [next_round, n + 1]
					bracket.append(next_match)
				tournament ["bracket"] = bracket

	var controlled_actor_id: int = int(tournament.get("player_entry_actor_id", -1))
	var controlled_actor_was_in_match: bool = false
	if controlled_actor_id > 0:
		if int(winner.id) == controlled_actor_id:
			controlled_actor_was_in_match = true
		elif loser != null and int(loser.id) == controlled_actor_id:
			controlled_actor_was_in_match = true

	if controlled_actor_id > 0 and controlled_actor_was_in_match and str(tournament.get("status", "")).strip_edges().to_lower() != "complete":
		tournament = _bending_mark_actor_round_advance_pending(tournament, controlled_actor_id, completed_round)

	if controlled_actor_id > 0:
		var controlled_actor: Person = _find_person_by_id(controlled_actor_id)
		if controlled_actor != null:
			tournament = _repair_bending_tournament_for_actor_match(tournament, controlled_actor)

	tournaments [tournament_id] = tournament
	state ["tournaments"] = tournaments
	gs.scenario_state ["bending_world_championship"] = state

	if str(tournament.get("status", "")).strip_edges().to_lower() == "complete":
		_normalize_historical_champion_tournament_wins(winner, tournament, context)
		_register_bending_tournament_history_result(winner, tournament, context)
		_register_tournament_of_champions_bid(winner, tournament)

	_refresh_bending_tournament_recordboards([winner, loser])

	if gs != null and "bending_dojo_engine" in gs and gs.bending_dojo_engine != null:
		if gs.bending_dojo_engine.has_method("record_tournament_honor"):
			gs.bending_dojo_engine.record_tournament_honor(winner, tournament, {
				"source": "bending_tournament_champion",
				"won": true,
				"championship": true
			})
func _grant_bending_world_championship_trophy(winner: Person, tournament: Dictionary) -> Dictionary:
	if gs == null or winner == null or gs.belongings_engine == null:
		return {}
	if not gs.belongings_engine.has_method("add_item"):
		return {}

	var element: String = _bending_person_primary_element(winner)
	if element == "avatar":
		element = _element_from_nation(str(winner.bending_nation))
	if element not in _base_bending_elements():
		element = "bending"

	var nation: String = _bending_world_faction_for_actor(winner)
	var trophy_name: String = _bending_world_trophy_name(element, nation, tournament)
	var trophy_id: int = abs(int(("%s:%d:%d" % [
		str(tournament.get("id", "")),
		int(winner.id),
		int(gs.year)
	]).hash()))

	var trophy: Dictionary = {
		"id": trophy_id,
		"schema": "eralife.bending_world_championship_trophy",
		"version": 1,
		"name": trophy_name,
		"display_name": trophy_name,
		"type": "Bending World Championship Trophy",
		"asset_kind": "trophy",
		"subtype": "%s_nation_bending_trophy" % element,
		"element": element,
		"nation": nation,
		"champion_id": int(winner.id),
		"champion_name": _bending_person_label(winner),
		"tournament_id": str(tournament.get("id", "")),
		"tournament_label": str(tournament.get("label", "Bending World Championship")),
		"acquired_year": int(gs.year),
		"value": _bending_world_trophy_value(element, tournament),
		"rarity": 4.0,
		"heirloom": true,
		"prestige_signals": {
			"bending_champion": 1.0,
			"elemental_nation": element,
			"world_stage": 1.0
		},
		"provenance": {
			"source": "bending_world_championship",
			"acquired_year": int(gs.year),
			"earned_by": _bending_person_label(winner)
		}
	}

	gs.belongings_engine.add_item(winner, trophy, "Trophies", false)

	return {
		"schema": "eralife.bending_world_championship_trophy_report",
		"version": 1,
		"success": true,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"category": "Trophies",
		"item": trophy.duplicate(true),
		"tournament_id": str(tournament.get("id", "")),
		"tournament_label": str(tournament.get("label", "Bending World Championship")),
		"element": element,
		"nation": nation
	}
func _trigger_bending_championship_reality_surge(
	winner: Person,
	tournament: Dictionary,
	trophy_report: Dictionary = {},
	reward_report: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if gs == null or winner == null:
		return {}
	if not ("reality_surge_engine" in gs) or gs.reality_surge_engine == null:
		return {}
	if not gs.reality_surge_engine.has_method("trigger_surge"):
		return {}

	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var title_key: String = _bending_championship_title_key(tournament)
	var element: String = _bending_person_primary_element(winner)
	var is_avatar: bool = str(winner.bending_type).strip_edges().to_lower() == "avatar"

	if element == "avatar" and not is_avatar:
		element = _element_from_nation(str(winner.bending_nation))
	if element not in _base_bending_elements() and not is_avatar:
		element = "bending"

	var clean_element: String = "avatar" if is_avatar else element
	var fatal_finish: bool = bool(context.get("death", false)) or bool(context.get("fatal_finish", false))
	var finish_move: String = str(context.get("finish_move", "")).strip_edges()
	if finish_move == "":
		finish_move = "the final bending strike"

	var contract_id: String = "agni_kai.championship_final.reality_break" if title_key == "agni_kai_unbreakable_fire" or division == "agni_kai" else "bending.championship_final.reality_break"
	var reality_break_contract: Dictionary = _bending_championship_reality_break_contract(
		contract_id,
		division,
		title_key,
		clean_element,
		is_avatar,
		fatal_finish,
		finish_move,
		tournament
	)

	if gs.reality_surge_engine.has_method("register_surge_contract"):
		gs.reality_surge_engine.register_surge_contract(reality_break_contract)

	var salience: float = 100.0 if winner == gs.player else 92.0
	var visual_layer: Dictionary = _safe_dictionary(reality_break_contract.get("visual_layer", {}))
	var perception_layer: Dictionary = _safe_dictionary(reality_break_contract.get("perception_layer", {}))

	var event_payload: Dictionary = {
		"schema": "eralife.bending_championship_reality_surge_event",
		"version": 2,
		"event_name": "competitive.match.completed",
		"domain": "bending",
		"championship": true,
		"championship_final": true,
		"reality_break": true,
		"fatal_finish": fatal_finish,
		"winner_is_player": winner == gs.player,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"division": division,
		"title_key": title_key,
		"title_label": _bending_championship_title_label(tournament),
		"tournament_id": str(tournament.get("id", "")),
		"tournament_label": str(tournament.get("label", "Bending World Championship")),
		"tournament_year": int(tournament.get("year", int(gs.year) if gs != null else 0)),
		"element": clean_element,
		"is_avatar": is_avatar,
		"salience": salience,
		"finish_move": finish_move,
		"screen_damage": "max",
		"time_dilation": 0.3,
		"audio_muffle": 1.0,
		"visual_layer": visual_layer.duplicate(true),
		"perception_layer": perception_layer.duplicate(true),
		"reward_item": trophy_report.get("item", {}),
		"trophy_report": trophy_report.duplicate(true),
		"championship_reward_report": reward_report.duplicate(true)
	}

	return gs.reality_surge_engine.trigger_surge(contract_id, winner, event_payload, {
		"source": "bending_engine_championship_final_reality_break",
		"force": true,
		"duplicate_window_ms": 2200,
		"tournament_id": str(tournament.get("id", "")),
		"division": division,
		"element": clean_element,
		"fatal_finish": fatal_finish,
		"finish_move": finish_move,
		"reward_item": trophy_report.get("item", {}),
		"trophy_report": trophy_report.duplicate(true),
		"salience": salience
	})
func _bending_championship_reality_break_contract(
	contract_id: String,
	division: String,
	title_key: String,
	element: String,
	is_avatar: bool,
	fatal_finish: bool,
	finish_move: String,
	tournament: Dictionary
) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = "bending"

	var shader_profile: String = "championship_final_reality_break_%s" % clean_element
	var break_profile: Dictionary = _bending_championship_reality_break_profile(clean_element, fatal_finish, finish_move)

	return {
		"schema": "eralife.reality_surge_contract",
		"version": 2,
		"id": contract_id,
		"domain": "bending",
		"display_name": "Bending Championship Final Reality Break",
		"trigger": {
			"event": "competitive.match.completed",
			"filters": {
				"domain": "bending",
				"championship": true,
				"championship_final": true
			},
			"threshold": {
				"salience_min": 90.0
			}
		},
		"surge_profile": {
			"type": ["reality_break", "elemental_final_hit", "competitive_legacy", "championship_final"],
			"intensity": 1.0,
			"division": division,
			"title_key": title_key,
			"title_label": _bending_championship_title_label(tournament),
			"fatal_finish": fatal_finish,
			"finish_move": finish_move
		},
		"visual_layer": {
			"theme_resolver": "elemental_affinity_resolver",
			"shader_profile": shader_profile,
			"screen_damage": "max",
			"screen_damage_intensity": 1.0,
			"screen_fracture": true,
			"screen_bleed": fatal_finish,
			"distortion": true,
			"particles": true,
			"element": clean_element,
			"is_avatar": is_avatar,
			"fatal_finish": fatal_finish,
			"finish_move": finish_move,
			"break_profile": break_profile.duplicate(true)
		},
		"perception_layer": {
			"time_dilation": 0.3,
			"input_lock_ms": 2200 if fatal_finish else 1700,
			"camera_weight": 0.95,
			"audio_muffle": 1.0,
			"heartbeat_drop": fatal_finish,
		},
		"reward_manifestation": {
			"animate_to_inventory": true,
			"object_type": "trophy",
			"target_ui": "belongings_button",
			"spawn_effect": "materialize_from_reality_break",
			"category": "Trophies"
		},
		"stat_echo": {
			"temporary_boost": {
				"willpower": 20
			},
			"duration_ms": 3600,
			"decay_curve": "reality_snapback"
		},
		"stability": {
			"instability_gain": 0.45 if fatal_finish else 0.28,
			"mutation_chance": 0.04 if fatal_finish else 0.015,
		}
	}
func _bending_championship_reality_break_profile(element: String, fatal_finish: bool, finish_move: String) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var profile: Dictionary = {
		"schema": "eralife.bending_championship_final_reality_break_profile",
		"version": 1,
		"element": clean_element,
		"fatal_finish": fatal_finish,
		"finish_move": finish_move,
		"screen_damage": "max",
		"time_dilation": 0.3,
		"audio_muffle": 1.0,
	}

	match clean_element:
		"fire":
			profile ["title"] = "REALITY BREAK: FINAL FLAME"
			profile ["motion"] = "heat_bloom_screen_crack"
			profile ["impact_text"] = "The final hit does not land like an attack. It lands like the arena briefly became a furnace with a memory."
			profile ["fatal_text"] = "The flames close around the moment, and for one breath, the world understands that mercy has left the room."
		"water":
			profile ["title"] = "REALITY BREAK: FINAL TIDE"
			profile ["motion"] = "pressure_wave_ripple_freeze"
			profile ["impact_text"] = "The final hit folds through the arena like pressure under the skin of reality."
			profile ["fatal_text"] = "The water takes the sound first. Then the breath. Then the soul."
		"earth":
			profile ["title"] = "REALITY BREAK: FINAL STONE"
			profile ["motion"] = "gravity_slab_screen_collapse"
			profile ["impact_text"] = "The final hit drops with the weight of a mountain ending the fight forever."
			profile ["fatal_text"] = "The ground remembers them before the crowd can."
		"air":
			profile ["title"] = "REALITY BREAK: FINAL BREATH"
			profile ["motion"] = "vacuum_pull_border_shatter"
			profile ["impact_text"] = "The final hit removes the air from the body itself."
			profile ["fatal_text"] = "The silence grows after the body falls."
		"avatar":
			profile ["title"] = "REALITY BREAK: AVATAR FINALITY"
			profile ["motion"] = "four_element_spectrum_reality_split"
			profile ["impact_text"] = "The final hit cycles through all four elements so violently that this UI cannot decide what reality is supposed to be."
			profile ["fatal_text"] = "Fire, water, earth, and air agree for one terrible second."
		_:
			profile ["title"] = "REALITY BREAK: FINAL HIT"
			profile ["motion"] = "reality_pulse_screen_fracture"
			profile ["impact_text"] = "The final hit bends the match harder than the body."
			profile ["fatal_text"] = "The arena goes still before anyone is ready to react to what happened."

	return profile

func _apply_bending_world_celebrity_status(winner: Person, tournament: Dictionary, context: Dictionary = {}) -> Dictionary:
	if winner == null:
		return {}

	var era_key: String = _current_bending_celebrity_era_key()
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var champion_label: String = str(tournament.get("label", "Bending World Championship"))
	var element: String = _bending_person_primary_element(winner)

	if element == "avatar":
		element = _element_from_nation(str(winner.bending_nation))
	if element not in _base_bending_elements():
		element = "bending"

	var followers: int = _bending_world_celebrity_followers_for_era(winner, tournament, era_key)
	var fear_modifier: float = _bending_world_celebrity_fear_modifier(winner, tournament)
	var aura_label: String = _bending_world_celebrity_aura_label(winner, division, element)

	if typeof(winner.power_profiles) != TYPE_DICTIONARY:
		winner.power_profiles = {}

	var profiles: Dictionary = winner.power_profiles.duplicate(true)
	var bending: Dictionary = profiles.get("bending", {}) if typeof(profiles.get("bending", {})) == TYPE_DICTIONARY else {}
	var celebrity_profile: Dictionary = bending.get("celebrity_profile", {}) if typeof(bending.get("celebrity_profile", {})) == TYPE_DICTIONARY else {}

	celebrity_profile ["schema"] = "eralife.bending_world_celebrity_profile"
	celebrity_profile ["version"] = 1
	celebrity_profile ["is_bending_world_celebrity"] = true
	celebrity_profile ["champion_title"] = champion_label
	celebrity_profile ["champion_year"] = int(gs.year) if gs != null else 0
	celebrity_profile ["division"] = division
	celebrity_profile ["element"] = element
	celebrity_profile ["aura_label"] = aura_label
	celebrity_profile ["followers"] = followers
	celebrity_profile ["follower_label"] = _format_bending_world_followers(followers, era_key)
	celebrity_profile ["era_key"] = era_key
	celebrity_profile ["fear_modifier"] = fear_modifier
	celebrity_profile ["duel_presence_bonus"] = clamp(int(round(fear_modifier * 10.0)), 1, 18)
	celebrity_profile ["last_tournament_id"] = str(tournament.get("id", ""))
	celebrity_profile ["last_tournament_label"] = champion_label

	bending ["celebrity_profile"] = celebrity_profile.duplicate(true)
	profiles ["bending"] = bending
	winner.power_profiles = profiles

	winner.fame = max(int(winner.fame), 65)
	winner.fame_job = "Bending World Champion"
	if str(winner.fame_tier).strip_edges() == "" or str(winner.fame_tier).strip_edges().to_lower() in ["unknown", "none"]:
		winner.fame_tier = "Bending Celebrity"

	if "Bending World Celebrity" not in winner.traits:
		winner.traits.append("Bending World Celebrity")

	if gs != null and gs.fame_engine != null and gs.fame_engine.has_method("give_fame"):
		gs.fame_engine.give_fame(winner, clamp(18 + int(round(fear_modifier * 12.0)), 18, 55))

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed("%s became a world-famous bending champion with %s." % [
			_bending_person_label(winner),
			aura_label
		], {
			"category": "bending",
			"event_name": "bending_world_celebrity_created",
			"source": "bending_engine",
			"personally_relevant": winner == gs.player,
			"followers": followers,
			"fear_modifier": fear_modifier,
			"tournament_id": str(tournament.get("id", "")),
			"simulated": bool(context.get("simulated", false))
		})

	return celebrity_profile.duplicate(true)


func get_bending_world_celebrity_profile(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	if typeof(actor.power_profiles) != TYPE_DICTIONARY:
		return {}

	var profiles: Dictionary = actor.power_profiles
	var bending_raw: Variant = profiles.get("bending", {})
	if typeof(bending_raw) != TYPE_DICTIONARY:
		return {}

	var bending: Dictionary = bending_raw
	var celebrity_raw: Variant = bending.get("celebrity_profile", {})
	if typeof(celebrity_raw) != TYPE_DICTIONARY:
		return {}

	return (celebrity_raw as Dictionary).duplicate(true)


func _current_bending_celebrity_era_key() -> String:
	if gs == null:
		return "ancient"

	var year_value: int = int(gs.year)

	if year_value < 500:
		return "ancient"
	if year_value < 1500:
		return "medieval"
	if year_value < 1900:
		return "industrial"
	if year_value < 1995:
		return "modern"

	return "digital"


func _bending_world_celebrity_followers_for_era(winner: Person, tournament: Dictionary, era_key: String) -> int:
	var division: String = str(tournament.get("division", "")).strip_edges().to_lower()
	var base: int = 5000

	match era_key:
		"ancient":
			base = randi_range(1800, 18000)
		"medieval":
			base = randi_range(8000, 85000)
		"industrial":
			base = randi_range(45000, 650000)
		"modern":
			base = randi_range(200000, 2500000)
		"digital":
			base = randi_range(750000, 12000000)
		_:
			base = randi_range(4000, 40000)

	if division == "adult":
		base = int(round(float(base) * 1.35))
	elif division == "youth":
		base = int(round(float(base) * 0.82))

	if str(winner.bending_type).strip_edges().to_lower() == "avatar":
		base = int(round(float(base) * 2.25))

	base += int(winner.fame) * 1000
	return max(0, base)


func _bending_world_celebrity_fear_modifier(winner: Person, tournament: Dictionary) -> float:
	var power_score: float = 0.0
	var element: String = _bending_person_primary_element(winner)

	if element == "avatar":
		power_score += 0.55
		element = _element_from_nation(str(winner.bending_nation))

	if element in _base_bending_elements():
		power_score += clamp(float(get_bending_level(winner, element)) / 140.0, 0.0, 0.72)

	var profile: Dictionary = ensure_bending_combat_profile(winner)
	var combat_total: int = 0
	for stat_name in _bending_combat_stat_keys():
		combat_total += int(profile.get(stat_name, 50))

	var combat_average: float = float(combat_total) / float(max(1, _bending_combat_stat_keys().size()))
	power_score += clamp((combat_average - 50.0) / 90.0, 0.0, 0.55)

	if str(tournament.get("division", "")).strip_edges().to_lower() == "adult":
		power_score += 0.12

	return clamp(power_score, 0.08, 1.75)


func _bending_world_celebrity_aura_label(winner: Person, division: String, element: String) -> String:
	var clean_element: String = str(element).strip_edges().to_lower()
	var prefix: String = "World Champion"

	if str(winner.bending_type).strip_edges().to_lower() == "avatar":
		prefix = "Avatar Champion"
	elif division == "youth":
		prefix = "Youth Phenom"

	match clean_element:
		"air":
			return "%s aura: impossible to pin down" % prefix
		"water":
			return "%s aura: calm until it is too late" % prefix
		"earth":
			return "%s aura: mountain-pressure presence" % prefix
		"fire":
			return "%s aura: arena-heating menace" % prefix

	return "%s aura: legendary bending pressure" % prefix


func _format_bending_world_followers(followers: int, era_key: String) -> String:
	var unit: String = "followers"

	match era_key:
		"ancient":
			unit = "oral legend followers"
		"medieval":
			unit = "court-and-village followers"
		"industrial":
			unit = "newspaper-era followers"
		"modern":
			unit = "broadcast-era followers"
		"digital":
			unit = "cross-platform followers"

	return "%s %s" % [_format_large_number(followers), unit]


func _format_large_number(value: int) -> String:
	var amount: float = float(value)

	if amount >= 1000000000.0:
		return "%.1fB" % (amount / 1000000000.0)
	if amount >= 1000000.0:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 1000.0:
		return "%.1fK" % (amount / 1000.0)

	return str(value)
func _bending_world_trophy_name(element: String, nation: String, _tournament: Dictionary) -> String:
	match str(element).strip_edges().to_lower():
		"fire":
			return "Sunfire Crown Trophy of the %s" % nation
		"water":
			return "Moon-Tide Chalice of the %s" % nation
		"earth":
			return "Stone Lotus Trophy of the %s" % nation
		"air":
			return "Sky Spiral Trophy of the %s" % nation
		_:
			return "Bending World Championship Trophy"


func _bending_world_trophy_value(element: String, tournament: Dictionary) -> int:
	var base_value: int = 25000
	match str(element).strip_edges().to_lower():
		"fire":
			base_value = 42000
		"water":
			base_value = 39000
		"earth":
			base_value = 45000
		"air":
			base_value = 41000

	if str(tournament.get("division", "")).strip_edges().to_lower() == "masters":
		base_value = int(round(float(base_value) * 1.35))

	return base_value


func _push_bending_tournament_result_log(winner: Person, loser: Person, tournament: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or winner == null:
		return

	var state: Dictionary = _bending_world_state()
	var results_raw: Variant = state.get("previous_results", [])
	var results: Array = results_raw if typeof(results_raw) == TYPE_ARRAY else []

	var result_text: String = "%s won the %s." % [
		_bending_person_label(winner),
		str(tournament.get("label", "Bending World Championship"))
	]

	if loser != null:
		result_text = "%s defeated %s to win the %s." % [
			_bending_person_label(winner),
			_bending_person_label(loser),
			str(tournament.get("label", "Bending World Championship"))
		]

	results.append({
		"schema": "eralife.bending_tournament_result",
		"version": 1,
		"year": int(gs.year),
		"year_label": _format_avatar_world_year(int(gs.year)),
		"tournament_id": str(tournament.get("id", "")),
		"division": str(tournament.get("division", "")),
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"loser_id": int(loser.id) if loser != null else -1,
		"loser_name": _bending_person_label(loser) if loser != null else "",
		"text": result_text,
		"simulated": bool(context.get("simulated", false))
	})

	while results.size() > 40:
		results.pop_front()

	state ["previous_results"] = results
	gs.scenario_state ["bending_world_championship"] = state

func _record_bending_dynasty_signal(actor: Person, payload: Dictionary = {}) -> void:
	if actor == null or gs == null:
		return

	var bloodline_key: String = str(actor.last_name).strip_edges()
	if bloodline_key == "":
		bloodline_key = "Unknown Bloodline"

	var state: Dictionary = _bending_world_state()
	var dynasties: Dictionary = state.get("dynasty_records", {})
	var row: Dictionary = dynasties.get(bloodline_key, {
		"schema": "eralife.bending_dynasty_record",
		"version": 3,
		"bloodline": bloodline_key,
		"championship_wins": 0,
		"tournament_wins": 0,
		"duel_wins": 0,
		"kos": 0,
		"deaths": 0,
		"rivalry_heat": 0,
		"members": {},
		"titles_by_faction": {},
		"titles_by_tournament": {},
		"title_rows": [],
		"title_summary": "",
		"rivals": {},
		"first_seen_year": int(gs.year)
	})

	row ["version"] = max(3, int(row.get("version", 1)))
	row ["duel_wins"] = int(row.get("duel_wins", 0)) + 1

	if bool(payload.get("tournament", false)):
		row ["tournament_wins"] = int(row.get("tournament_wins", 0)) + 1

	if bool(payload.get("championship_title", false)):
		row ["championship_wins"] = int(row.get("championship_wins", 0)) + 1

		var faction: String = str(payload.get("faction", _bending_world_faction_for_actor(actor))).strip_edges()
		if faction == "":
			faction = "World Stage"

		var titles_by_faction: Dictionary = _safe_dictionary(row.get("titles_by_faction", {}))
		titles_by_faction [faction] = int(titles_by_faction.get(faction, 0)) + 1
		row ["titles_by_faction"] = titles_by_faction

		var title_key: String = str(payload.get("title_key", "")).strip_edges()
		if title_key == "":
			title_key = _bending_championship_title_key_from_division(
				str(payload.get("division", "")),
				str(payload.get("tournament_label", ""))
			)

		var title_label: String = str(payload.get("title_label", "")).strip_edges()
		if title_label == "":
			title_label = _bending_championship_title_label_from_key(title_key)

		var titles_by_tournament: Dictionary = _safe_dictionary(row.get("titles_by_tournament", {}))
		titles_by_tournament [title_key] = int(titles_by_tournament.get(title_key, 0)) + 1
		row ["titles_by_tournament"] = titles_by_tournament
		row ["title_rows"] = _bending_championship_title_rows_for_counts(titles_by_tournament)
		row ["title_summary"] = _bending_championship_title_summary_for_records({
			"championship_title_counts": titles_by_tournament,
			"championships": int(row.get("championship_wins", 0))
		})
		row ["dynasty_title"] = "%s X%d" % [
			title_label,
			int(titles_by_tournament.get(title_key, 0))
		]

	if bool(payload.get("ko", false)):
		row ["kos"] = int(row.get("kos", 0)) + 1
	if bool(payload.get("death", false)):
		row ["deaths"] = int(row.get("deaths", 0)) + 1

	var context: Dictionary = payload.get("context", {}) if typeof(payload.get("context", {})) == TYPE_DICTIONARY else {}
	var loser_id: int = int(context.get("loser_id", -1))
	var loser: Person = _find_person_by_id(loser_id)
	if loser != null:
		var rival_bloodline: String = str(loser.last_name).strip_edges()
		if rival_bloodline != "" and rival_bloodline != bloodline_key:
			var rivals: Dictionary = _safe_dictionary(row.get("rivals", {}))
			var rival_row: Dictionary = rivals.get(rival_bloodline, {
				"bloodline": bloodline_key,
				"rival_bloodline": rival_bloodline,
				"heat": 0,
				"wins": 0,
				"losses": 0,
				"last_result": ""
			})
			rival_row ["heat"] = int(rival_row.get("heat", 0)) + 1
			rival_row ["wins"] = int(rival_row.get("wins", 0)) + 1
			rival_row ["last_result"] = "%s defeated %s in %s" % [
				_bending_person_label(actor),
				_bending_person_label(loser),
				str(context.get("tournament_id", "a bending clash"))
			]
			rivals [rival_bloodline] = rival_row
			row ["rivals"] = rivals
			row ["rivalry_heat"] = int(row.get("rivalry_heat", 0)) + 1

			_record_global_bloodline_rivalry(row, rival_row)

	var members: Dictionary = _safe_dictionary(row.get("members", {}))
	members [str(int(actor.id))] = {
		"name": _bending_person_label(actor),
		"age": int(actor.age),
		"element": str(actor.bending_type),
		"faction": _bending_world_faction_for_actor(actor),
		"style_identity": get_competitive_style_identity(actor, {
			"source": "dynasty_signal"
		}),
		"last_win_year": int(gs.year)
	}
	row ["members"] = members
	row ["last_seen_year"] = int(gs.year)

	dynasties [bloodline_key] = row
	state ["dynasty_records"] = dynasties
	gs.scenario_state ["bending_world_championship"] = state
func _record_global_bloodline_rivalry(dynasty_row: Dictionary, rival_row: Dictionary) -> void:
	var state: Dictionary = _bending_world_state()
	var rivalries: Dictionary = state.get("bloodline_rivalries", {})

	var bloodline: String = str(rival_row.get("bloodline", dynasty_row.get("bloodline", ""))).strip_edges()
	var rival_bloodline: String = str(rival_row.get("rival_bloodline", "")).strip_edges()
	if bloodline == "" or rival_bloodline == "":
		return

	var ordered: Array = [bloodline, rival_bloodline]
	ordered.sort()
	var rivalry_key: String = "%s_vs_%s" % [str(ordered [0]), str(ordered [1])]

	var global_row: Dictionary = rivalries.get(rivalry_key, {
		"schema": "eralife.bending_bloodline_rivalry",
		"version": 1,
		"bloodline": str(ordered [0]),
		"rival_bloodline": str(ordered [1]),
		"heat": 0,
		"last_result": "",
		"last_seen_year": int(gs.year)
	})

	global_row ["heat"] = int(global_row.get("heat", 0)) + int(rival_row.get("heat", 1))
	global_row ["last_result"] = str(rival_row.get("last_result", "A tournament clash raised the heat."))
	global_row ["last_seen_year"] = int(gs.year)

	rivalries [rivalry_key] = global_row
	state ["bloodline_rivalries"] = rivalries
	gs.scenario_state ["bending_world_championship"] = state


func _bending_era_supports_media() -> bool:
	if gs == null:
		return false

	var era_name: String = ""
	if gs.era != null:
		era_name = str(gs.era.name).strip_edges().to_lower()

	var policy: Dictionary = _bending_world_policy()
	var media_eras: Array = policy.get("media_eras", ["modern", "future", "digital", "cyber", "space"])

	for raw_key in media_eras:
		var key: String = str(raw_key).strip_edges().to_lower()
		if key != "" and era_name.find(key) >= 0:
			return true

	return false


func _push_bending_media_reaction(winner: Person, loser: Person, tournament: Dictionary, _context: Dictionary = {}) -> void:
	if gs == null or winner == null:
		return
	if not _bending_era_supports_media():
		return

	var winner_style: Dictionary = get_competitive_style_identity(winner, {
		"source": "media_reaction_winner"
	})

	var reaction: String = "📺 Bending media is calling %s “%s” after winning the %s." % [
		_bending_person_label(winner),
		str(winner_style.get("title", "the problem")),
		str(tournament.get("label", "Bending World Championship"))
	]

	if str(winner.bending_type).strip_edges().to_lower() == "avatar":
		reaction = "📺 Every outlet is leading with the same headline: the Avatar just bent the bracket around them."

	var state: Dictionary = _bending_world_state()
	var media_reactions: Array = state.get("media_reactions", [])
	media_reactions.append({
		"schema": "eralife.bending_media_reaction",
		"version": 1,
		"year": int(gs.year),
		"text": reaction,
		"winner_id": int(winner.id),
		"winner_name": _bending_person_label(winner),
		"tournament_id": str(tournament.get("id", "")),
		"style_identity": winner_style.duplicate(true)
	})
	while media_reactions.size() > 80:
		media_reactions.pop_front()

	state ["media_reactions"] = media_reactions
	gs.scenario_state ["bending_world_championship"] = state

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(reaction, {
			"category": "bending",
			"event_name": "bending_media_reaction",
			"source": "bending_engine",
			"personally_relevant": winner == gs.player or loser == gs.player,
			"winner_id": int(winner.id),
			"tournament_id": str(tournament.get("id", ""))
		})
func get_bending_world_championship_hub_payload(actor: Person) -> Dictionary:
	_ensure_bending_world_bootstrap({
		"source": "hub_payload"
	})

	var division: String = get_bending_world_championship_division(actor)
	var records: Dictionary = _ensure_bending_duel_records(actor)
	var state: Dictionary = _bending_world_state()
	var tournaments: Dictionary = state.get("tournaments", {})
	var year_value: int = int(gs.year) if gs != null else 0
	var tournament_id: String = _bending_tournament_id_for_division(division, year_value)
	var tournament: Dictionary = tournaments.get(tournament_id, {})
	var bracket: Array = _safe_array(tournament.get("bracket", []))

	var top_payload: Dictionary = get_bending_world_top_bender_payload(100)
	var style_identity: Dictionary = get_competitive_style_identity(actor, {
		"source": "bending_hub_payload"
	})
	var actor_status: Dictionary = _bending_tournament_actor_status(tournament, actor)
	var actor_status_key: String = str(actor_status.get("status", "none")).strip_edges().to_lower()
	var actor_eliminated: bool = actor_status_key == "eliminated"

	var current_round: int = _bending_tournament_current_round(tournament) if not tournament.is_empty() else 1
	var current_field_size: int = _bending_tournament_field_size_for_round(tournament, current_round) if not tournament.is_empty() else 8
	var current_round_label: String = _bending_tournament_round_label(current_round, current_field_size)
	var current_stage_label: String = _bending_tournament_stage_label(tournament, current_round) if not tournament.is_empty() else "Bending World Tournament"

	var entry_label: String = str(actor_status.get(
		"entry_button_label",
		"Enter Bending World Championship as %s" % str(actor.first_name) if actor != null else "Enter Bending World Championship"
	))
	var entry_disabled: bool = bool(actor_status.get("entry_button_disabled", division == "ineligible"))

	var can_advance_round: bool = false
	var can_spectate_match: bool = false
	var can_spectate_championship: bool = false

	if actor != null and not tournament.is_empty() and str(tournament.get("status", "")).strip_edges().to_lower() == "active":
		for raw_match in bracket:
			if typeof(raw_match) != TYPE_DICTIONARY:
				continue

			var match_row: Dictionary = raw_match
			if str(match_row.get("status", "pending")).strip_edges().to_lower() != "pending":
				continue

			var fighter_a_id: int = int(match_row.get("fighter_a_id", -1))
			var fighter_b_id: int = int(match_row.get("fighter_b_id", -1))
			if fighter_a_id <= 0 or fighter_b_id <= 0:
				continue

			if actor_eliminated:
				can_spectate_championship = true
				continue

			if int(match_row.get("round", 1)) != current_round:
				continue

			if fighter_a_id == int(actor.id) or fighter_b_id == int(actor.id):
				continue

			can_advance_round = true
			can_spectate_match = true
			break

	if actor_eliminated:
		can_advance_round = false
		can_spectate_match = false

	var history_payload: Dictionary = get_bending_tournament_history_payload(actor)
	var previous_avatar_imprint: Dictionary = get_previous_avatar_reputation_imprint(actor, {
		"source": "bending_hub_payload"
	})
	var payload: Dictionary = {
		"schema": "eralife.bending_world_championship_hub_payload",
		"version": 10,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _bending_person_label(actor) if actor != null else "",
		"is_avatar": actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar",
		"division": division,
		"records": records.duplicate(true),
		"tournament": tournament.duplicate(true),
		"bracket": bracket.duplicate(true),
		"current_round": current_round,
		"current_round_label": current_round_label,
		"current_stage_label": current_stage_label,
		"actor_tournament_status": actor_status.duplicate(true),
		"actor_eliminated": actor_eliminated,
		"entry_button_label": entry_label,
		"entry_button_disabled": entry_disabled,
		"entry_button_tooltip": str(actor_status.get("entry_button_tooltip", "Tournament runs persist across the year. Fight your ready match, then advance or spectate unresolved NPC matches before the next round opens.")),
		"can_advance_round": can_advance_round,
		"can_spectate_match": can_spectate_match,
		"can_spectate_championship": can_spectate_championship,
		"championship_spectate_button_label": "Skip to Championship Match",
		"rankings": get_bending_rankings("adult" if division == "masters" else division, 100),
		"top_benders": top_payload.duplicate(true),
		"dynasties": state.get("dynasty_records", {}).duplicate(true),
		"dynasty_titles": _bending_dynasty_titles_for_actor(actor),
		"bloodline_rivalries": _bending_rivalries_for_actor(actor),
		"previous_avatars": _previous_avatars_for_actor(actor),
		"previous_avatar_reputation_imprint": previous_avatar_imprint.duplicate(true),
		"style_identity": style_identity.duplicate(true),
		"media_reactions": state.get("media_reactions", []).duplicate(true),
		"tournament_history": history_payload.duplicate(true)
	}

	return _bending_decorate_tournament_hub_payload(actor, payload)
func _bending_dynasty_titles_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var bloodline_key: String = str(actor.last_name).strip_edges()
	if bloodline_key == "":
		return out

	var state: Dictionary = _bending_world_state()
	var dynasties: Dictionary = state.get("dynasty_records", {})
	var row: Dictionary = dynasties.get(bloodline_key, {})
	if row.is_empty():
		return out

	var titles_by_tournament: Dictionary = _safe_dictionary(row.get("titles_by_tournament", {}))
	for raw_title_key in titles_by_tournament.keys():
		var title_key: String = str(raw_title_key)
		var count: int = int(titles_by_tournament.get(title_key, 0))
		if count <= 0:
			continue

		out.append({
			"bloodline": bloodline_key,
			"faction": str(row.get("bloodline", bloodline_key)),
			"title_key": title_key,
			"title_label": _bending_championship_title_label_from_key(title_key),
			"count": count,
			"title": "%s X%d" % [
				_bending_championship_title_label_from_key(title_key),
				count
			]
		})

	if out.is_empty():
		var titles_raw: Variant = row.get("titles_by_faction", {})
		var titles: Dictionary = titles_raw if typeof(titles_raw) == TYPE_DICTIONARY else {}

		for raw_faction in titles.keys():
			var faction: String = str(raw_faction)
			var count: int = int(titles.get(faction, 0))
			if count <= 0:
				continue

			out.append({
				"bloodline": bloodline_key,
				"faction": faction,
				"count": count,
				"title": "%dx Champion of %s" % [count, faction]
			})

	out.sort_custom(func (a, b):
		if int(a.get("count", 0)) != int(b.get("count", 0)):
			return int(a.get("count", 0)) > int(b.get("count", 0))
		return str(a.get("title", "")) < str(b.get("title", ""))
	)

	return out


func _bending_rivalries_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var bloodline_key: String = str(actor.last_name).strip_edges()
	if bloodline_key == "":
		return out

	var state: Dictionary = _bending_world_state()
	var rivalries: Dictionary = state.get("bloodline_rivalries", {})

	for raw_key in rivalries.keys():
		var row: Dictionary = rivalries.get(raw_key, {})
		if row.is_empty():
			continue

		var a: String = str(row.get("bloodline", ""))
		var b: String = str(row.get("rival_bloodline", ""))

		if a != bloodline_key and b != bloodline_key:
			continue

		out.append(row.duplicate(true))

	out.sort_custom(func (a, b): return int(a.get("heat", 0)) > int(b.get("heat", 0)))
	return out


func _previous_avatars_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return out

	_seed_previous_avatar_history_for_birth(actor)

	var state: Dictionary = _bending_world_state()
	var previous: Array = state.get("previous_avatars", [])
	var policy: Dictionary = _bending_world_policy()
	var visible_count: int = max(1, int(policy.get("avatar_history_visible_count", 4)))

	var start_index: int = max(0, previous.size() - visible_count)
	for i in range(start_index, previous.size()):
		if typeof(previous [i]) == TYPE_DICTIONARY:
			out.append(previous [i].duplicate(true))

	out.reverse()
	return out

func _bending_combat_stat_keys() -> Array:
	return ["accuracy", "power", "guard", "counter", "evasion", "focus"]

func _bending_default_combat_profile() -> Dictionary:
	return {
		"schema": "eralife.person_bending_combat_profile",
		"version": 4,
		"accuracy": 50,
		"power": 50,
		"guard": 50,
		"counter": 50,
		"evasion": 50,
		"focus": 50,
		"duel_records": {},
		"tournament_profile": {},
		"style_points_spent": 0,
		"ability_points_spent": 0,
		"skill_caps": {},
		"skill_cap_extensions": {},
		"ability_upgrades": {},
		"ability_upgrade_seeded": false,
		"ability_upgrade_seed_version": 0,
		"seeded_ability_upgrade_rows": [],
		"level_xp": {},
		"level_xp_lifetime": {},
		"last_xp_report": {},
		"lineage_style_seeded": false,
		"lineage_style_seed_version": 0,
		"lineage_style_source": "default"
	}

func _bending_progression_policy() -> Dictionary:
	var defaults: Dictionary = {
		"schema": "eralife.bending_progression_policy",
		"version": 1,
		"xp_curve": {
			"base_required_xp": 34,
			"linear_level_cost": 13,
			"power_curve": 1.72,
			"power_curve_weight": 1.45,
			"elite_level_start": 80,
			"elite_quadratic_weight": 11,
			"master_level_start": 90,
			"master_quadratic_weight": 19
		},
		"xp_gain": {
			"base_xp_per_raw_progress": 24,
			"minimum_training_xp": 8,
			"minimum_duel_xp": 14,
			"tournament_multiplier": 1.55,
			"ko_multiplier": 1.18,
			"death_multiplier": 1.45,
			"upset_multiplier": 1.35,
			"scenario_engine_multiplier": 0.72
		},
		"skill_points": {
			"award_on_level_interval": 5,
			"award_on_master_interval": 2,
			"master_level_start": 80,
			"tournament_bonus": 1,
			"upset_bonus": 1,
			"ko_bonus": 1,
			"max_duel_award": 7
		}
	}

	var configured: Dictionary = {}
	if typeof(active_contract) == TYPE_DICTIONARY:
		configured = _safe_dictionary(active_contract.get("progression_policy", {}))

	return _merge_dict(defaults, configured)


func _bending_skill_cap_policy() -> Dictionary:
	var defaults: Dictionary = {
		"schema": "eralife.bending_skill_cap_policy",
		"version": 1,
		"default_cap_floor": 68,
		"default_cap_ceiling": 100,
		"lineage_weight": 24,
		"potential_weight": 0.18,
		"level_weight": 0.08,
		"element_bias_weight": 0.55,
		"avatar_cap_bonus": 5,
		"royal_cap_bonus": 2,
		"special_event_extension_key": "skill_cap_extensions"
	}

	var configured: Dictionary = {}
	if typeof(active_contract) == TYPE_DICTIONARY:
		configured = _safe_dictionary(active_contract.get("skill_cap_policy", {}))

	return _merge_dict(defaults, configured)


func _bending_ability_upgrade_policy() -> Dictionary:
	var defaults: Dictionary = {
		"schema": "eralife.bending_ability_upgrade_policy",
		"version": 1,
		"max_upgrade_level": 5,
		"upgrade_level_step": 5,
		"base_upgrade_cost": 1,
		"cost_per_tier": 1,
		"cost_per_required_level_bucket": 1,
		"required_level_bucket_size": 30,
		"category_requirement_base": 52,
		"category_requirement_per_tier": 8,
		"category_requirement_level_weight": 0.12,
		"upgrade_effectiveness_per_tier": 0.08,
		"neutralize_per_tier": 5
	}

	var configured: Dictionary = {}
	if typeof(active_contract) == TYPE_DICTIONARY:
		configured = _safe_dictionary(active_contract.get("ability_upgrade_policy", {}))

	return _merge_dict(defaults, configured)


func _commit_bending_combat_profile(actor: Person, profile: Dictionary) -> Dictionary:
	if actor == null:
		return {}

	var committed: Dictionary = profile.duplicate(true)
	committed ["schema"] = "eralife.person_bending_combat_profile"
	committed ["version"] = max(4, int(committed.get("version", 4)))
	actor.bending_combat_profile = committed.duplicate(true)

	if typeof(actor.power_profiles) == TYPE_DICTIONARY:
		var profiles: Dictionary = actor.power_profiles.duplicate(true)
		var bending: Dictionary = profiles.get("bending", {}) if typeof(profiles.get("bending", {})) == TYPE_DICTIONARY else {}
		bending ["combat_profile"] = committed.duplicate(true)
		bending ["skill_points"] = int(actor.bending_skill_points)
		profiles ["bending"] = bending
		actor.power_profiles = profiles

	return committed.duplicate(true)


func _bending_xp_required_for_next_level(current_level: int) -> int:
	var policy: Dictionary = _bending_progression_policy()
	var curve: Dictionary = _safe_dictionary(policy.get("xp_curve", {}))

	var clean_level: int = clamp(int(current_level), 0, BENDING_LEVEL_MAX)
	var next_level: int = clamp(clean_level + 1, 1, BENDING_LEVEL_MAX)

	var base_required: int = max(1, int(curve.get("base_required_xp", 34)))
	var linear_cost: int = max(0, int(curve.get("linear_level_cost", 13)))
	var power_curve: float = max(1.0, float(curve.get("power_curve", 1.72)))
	var power_weight: float = max(0.0, float(curve.get("power_curve_weight", 1.45)))
	var elite_start: int = int(curve.get("elite_level_start", 80))
	var elite_weight: int = max(0, int(curve.get("elite_quadratic_weight", 11)))
	var master_start: int = int(curve.get("master_level_start", 90))
	var master_weight: int = max(0, int(curve.get("master_quadratic_weight", 19)))

	var required: int = base_required
	required += next_level * linear_cost
	required += int(round(pow(float(next_level), power_curve) * power_weight))

	if next_level >= elite_start:
		var elite_distance: int = max(0, next_level - elite_start + 1)
		required += elite_distance * elite_distance * elite_weight

	if next_level >= master_start:
		var master_distance: int = max(0, next_level - master_start + 1)
		required += master_distance * master_distance * master_weight

	return max(1, required)


func _bending_skill_points_from_level_gain(old_level: int, new_level: int, reason: String = "") -> int:
	if new_level <= old_level:
		return 0

	var policy: Dictionary = _bending_progression_policy()
	var point_policy: Dictionary = _safe_dictionary(policy.get("skill_points", {}))
	var normal_interval: int = max(1, int(point_policy.get("award_on_level_interval", 5)))
	var master_interval: int = max(1, int(point_policy.get("award_on_master_interval", 2)))
	var master_start: int = int(point_policy.get("master_level_start", 80))
	var points: int = 0

	for level_value in range(old_level + 1, new_level + 1):
		if level_value >= master_start:
			if level_value % master_interval == 0:
				points += 1
		elif level_value % normal_interval == 0:
			points += 1

	var clean_reason: String = str(reason).strip_edges().to_lower()
	if clean_reason.find("championship") >= 0 or clean_reason.find("tournament") >= 0:
		points += int(point_policy.get("tournament_bonus", 1))

	return max(0, points)


func _bending_resolve_skill_caps(actor: Person, profile: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if actor == null:
		return out

	var policy: Dictionary = _bending_skill_cap_policy()
	var floor_value: int = clamp(int(policy.get("default_cap_floor", 68)), 1, 100)
	var ceiling_value: int = clamp(int(policy.get("default_cap_ceiling", 100)), floor_value, 100)
	var lineage_weight: float = float(policy.get("lineage_weight", 24))
	var potential_weight: float = float(policy.get("potential_weight", 0.18))
	var level_weight: float = float(policy.get("level_weight", 0.08))
	var element_bias_weight: float = float(policy.get("element_bias_weight", 0.55))
	var primary_element: String = _bending_primary_style_element(actor)
	var primary_level: int = int(get_primary_bending_level(actor))
	var primary_potential: int = int(get_primary_bending_potential(actor))
	var lineage_strength: float = 0.32

	if primary_element in _base_bending_elements():
		primary_level = int(get_bending_level(actor, primary_element))
		primary_potential = max(primary_potential, int(get_bending_latent_potential(actor, primary_element)))
		lineage_strength = _bending_family_line_strength(actor, primary_element)

	var extensions_key: String = str(policy.get("special_event_extension_key", "skill_cap_extensions"))
	var extensions: Dictionary = _safe_dictionary(profile.get(extensions_key, profile.get("skill_cap_extensions", {})))

	for stat_name in _bending_combat_stat_keys():
		var cap: int = 78
		cap += int(round((float(primary_potential) - 50.0) * potential_weight))
		cap += int(round(float(primary_level) * level_weight))
		cap += int(round((lineage_strength - 0.32) * lineage_weight))
		cap += int(round(float(_bending_element_style_bias(primary_element, stat_name)) * element_bias_weight))
		cap += _stable_bending_variance(actor, "skill_cap_%s" % stat_name, 6)

		if str(actor.bending_type).strip_edges().to_lower() == "avatar" or bool(actor.avatar_state_unlocked):
			cap += int(policy.get("avatar_cap_bonus", 5))

		if bool(actor.is_royal) or bool(actor.is_ruler):
			if stat_name in ["focus", "guard", "counter"]:
				cap += int(policy.get("royal_cap_bonus", 2))

		cap += int(extensions.get(stat_name, 0))
		out [stat_name] = clamp(cap, floor_value, ceiling_value)

	return out


func _bending_skill_cap_for_stat(actor: Person, stat_name: String) -> int:
	if actor == null:
		return 0

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var caps: Dictionary = _safe_dictionary(profile.get("skill_caps", {}))
	var clean_stat: String = str(stat_name).strip_edges().to_lower()

	if not caps.has(clean_stat):
		caps = _bending_resolve_skill_caps(actor, profile)
		profile ["skill_caps"] = caps.duplicate(true)
		_commit_bending_combat_profile(actor, profile)

	return clamp(int(caps.get(clean_stat, 100)), 1, 100)


func _bending_ability_required_level(ability: Dictionary) -> int:
	return int(ability.get("min_level", ability.get("required_level", ability.get("level", 0))))


func _bending_ability_upgrade_stat_bundle(ability: Dictionary) -> Array:
	var ability_type: String = str(ability.get("type", "attack")).strip_edges().to_lower()

	match ability_type:
		"attack":
			return ["power", "accuracy", "focus"]
		"defense", "guard":
			return ["guard", "focus", "counter"]
		"escape":
			return ["evasion", "focus", "accuracy"]
		"control":
			return ["counter", "accuracy", "focus"]
		"heal":
			return ["focus", "guard", "counter"]
		_:
			return ["focus", "accuracy", "guard"]


func _bending_ability_upgrade_cost(ability: Dictionary, target_upgrade_level: int) -> int:
	var policy: Dictionary = _bending_ability_upgrade_policy()
	var required_level: int = _bending_ability_required_level(ability)
	var bucket_size: int = max(1, int(policy.get("required_level_bucket_size", 30)))

	var cost: int = int(policy.get("base_upgrade_cost", 1))
	cost += max(0, target_upgrade_level - 1) * int(policy.get("cost_per_tier", 1))
	cost += int(floor(float(required_level) / float(bucket_size))) * int(policy.get("cost_per_required_level_bucket", 1))

	return max(1, cost)


func _bending_ability_upgrade_requirements(ability: Dictionary, target_upgrade_level: int) -> Dictionary:
	var configured: Variant = ability.get("upgrade_requirements", {})
	var tier_key: String = str(target_upgrade_level)

	if typeof(configured) == TYPE_DICTIONARY:
		var configured_dict: Dictionary = configured
		if typeof(configured_dict.get(tier_key, {})) == TYPE_DICTIONARY:
			return _safe_dictionary(configured_dict.get(tier_key, {}))
		if typeof(configured_dict.get("tier_%d" % target_upgrade_level, {})) == TYPE_DICTIONARY:
			return _safe_dictionary(configured_dict.get("tier_%d" % target_upgrade_level, {}))

	var policy: Dictionary = _bending_ability_upgrade_policy()
	var required_level: int = _bending_ability_required_level(ability)
	var base_requirement: int = int(policy.get("category_requirement_base", 52))
	var tier_requirement: int = int(policy.get("category_requirement_per_tier", 8))
	var level_weight: float = float(policy.get("category_requirement_level_weight", 0.12))
	var ability_type: String = str(ability.get("type", "attack")).strip_edges().to_lower()

	var required_value: int = clamp(
		base_requirement + (max(1, target_upgrade_level) - 1) * tier_requirement + int(round(float(required_level) * level_weight)),
		1,
		99
	)

	var out: Dictionary = {}
	var bundle: Array = _bending_ability_upgrade_stat_bundle(ability)
	var index: int = 0

	for raw_stat in bundle:
		var stat_name: String = str(raw_stat).strip_edges().to_lower()
		if stat_name == "":
			continue

		var offset: int = 0
		match ability_type:
			"attack":
				if stat_name == "power":
					offset = 4
				elif stat_name == "accuracy":
					offset = 1
				elif stat_name == "focus":
					offset = -3
			"defense", "guard":
				if stat_name == "guard":
					offset = 4
				elif stat_name == "focus":
					offset = 1
				elif stat_name == "counter":
					offset = -2
			"escape":
				if stat_name == "evasion":
					offset = 4
				elif stat_name == "focus":
					offset = 1
				elif stat_name == "accuracy":
					offset = -2
			"control":
				if stat_name == "counter":
					offset = 4
				elif stat_name == "accuracy":
					offset = 1
				elif stat_name == "focus":
					offset = -2
			"heal":
				if stat_name == "focus":
					offset = 4
				elif stat_name == "guard":
					offset = 1
				elif stat_name == "counter":
					offset = -2
			_:
				offset = 2 - index

		var tier_variance: int = int((max(1, target_upgrade_level) + index) % 3) - 1
		out [stat_name] = clamp(required_value + offset + tier_variance, 1, 99)
		index += 1

	return out


func _bending_ability_upgrade_requirement_text(requirements: Dictionary) -> String:
	if requirements.is_empty():
		return "No category bundle"

	var parts: Array = []
	var used: Dictionary = {}

	for stat_name in _bending_combat_stat_keys():
		if not requirements.has(stat_name):
			continue

		parts.append("%s %d+" % [
			str(stat_name).capitalize(),
			int(requirements.get(stat_name, 0))
		])
		used [stat_name] = true

	for raw_key in requirements.keys():
		var clean_key: String = str(raw_key).strip_edges().to_lower()
		if clean_key == "" or bool(used.get(clean_key, false)):
			continue

		parts.append("%s %d+" % [
			clean_key.capitalize(),
			int(requirements.get(raw_key, 0))
		])

	return ", ".join(parts)

func _resolve_bending_ability_upgrade(actor: Person, ability: Dictionary, element: String) -> Dictionary:
	if actor == null:
		return {
			"upgrade_level": 0,
			"max_upgrade_level": 0,
			"can_upgrade": false,
			"upgrade_text": "No bender selected."
		}

	var policy: Dictionary = _bending_ability_upgrade_policy()
	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var upgrades: Dictionary = _safe_dictionary(profile.get("ability_upgrades", {}))
	var ability_id: String = str(ability.get("id", "")).strip_edges()
	var current_upgrade_level: int = clamp(int(upgrades.get(ability_id, 0)), 0, int(policy.get("max_upgrade_level", 5)))
	var max_upgrade_level: int = int(ability.get("max_upgrade_level", policy.get("max_upgrade_level", 5)))
	var target_upgrade_level: int = current_upgrade_level + 1

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = str(ability.get("element", "")).strip_edges().to_lower()

	var required_level: int = _bending_ability_required_level(ability)
	var upgrade_level_step: int = max(0, int(policy.get("upgrade_level_step", 5)))
	var target_level_gate: int = required_level + max(0, target_upgrade_level - 1) * upgrade_level_step
	var current_bending_level: int = get_bending_level(actor, clean_element)
	var requirements: Dictionary = _bending_ability_upgrade_requirements(ability, target_upgrade_level)
	var missing_parts: Array = []

	if current_upgrade_level >= max_upgrade_level:
		return {
			"upgrade_level": current_upgrade_level,
			"max_upgrade_level": max_upgrade_level,
			"next_upgrade_level": current_upgrade_level,
			"can_upgrade": false,
			"upgrade_cost": 0,
			"upgrade_requirements": {},
			"upgrade_effectiveness_multiplier": 1.0 + (float(current_upgrade_level) * float(policy.get("upgrade_effectiveness_per_tier", 0.08))),
			"neutralize_rating": int(current_upgrade_level) * int(policy.get("neutralize_per_tier", 5)),
			"upgrade_text": "Max upgrade reached."
		}

	if current_bending_level < target_level_gate:
		missing_parts.append("%s Level %d (%d/100)" % [
			clean_element.capitalize(),
			target_level_gate,
			current_bending_level
		])

	for raw_stat in requirements.keys():
		var stat_name: String = str(raw_stat).strip_edges().to_lower()
		var required_value: int = int(requirements.get(raw_stat, 0))
		var current_value: int = int(profile.get(stat_name, 50))
		var cap_value: int = _bending_skill_cap_for_stat(actor, stat_name)

		if cap_value < required_value:
			missing_parts.append("%s cap too low (%d/%d)" % [
				stat_name.capitalize(),
				cap_value,
				required_value
			])
		elif current_value < required_value:
			missing_parts.append("%s %d/%d" % [
				stat_name.capitalize(),
				current_value,
				required_value
			])

	var upgrade_cost: int = _bending_ability_upgrade_cost(ability, target_upgrade_level)
	var requirement_text: String = _bending_ability_upgrade_requirement_text(requirements)

	if int(actor.bending_skill_points) < upgrade_cost:
		missing_parts.append("Skill Points %d/%d" % [
			int(actor.bending_skill_points),
			upgrade_cost
		])

	var can_upgrade: bool = missing_parts.is_empty()
	var visible_missing: Array = missing_parts.duplicate(true)

	if requirement_text != "" and requirement_text != "No category bundle":
		if visible_missing.is_empty():
			visible_missing.append("Bundle: %s" % requirement_text)
		elif visible_missing.size() == 1 and str(visible_missing [0]).begins_with("Skill Points"):
			visible_missing.push_front("Bundle: %s" % requirement_text)

	var upgrade_status_text: String = "Ready to upgrade"
	if can_upgrade:
		upgrade_status_text = "Ready to upgrade • Bundle: %s" % requirement_text
	else:
		upgrade_status_text = "Upgrade needs: %s" % ", ".join(visible_missing)

	return {
		"upgrade_level": current_upgrade_level,
		"max_upgrade_level": max_upgrade_level,
		"next_upgrade_level": target_upgrade_level,
		"can_upgrade": can_upgrade,
		"upgrade_cost": upgrade_cost,
		"upgrade_requirements": requirements,
		"upgrade_requirement_text": requirement_text,
		"category_bundle": requirements.duplicate(true),
		"upgrade_missing": missing_parts,
		"upgrade_level_gate": target_level_gate,
		"upgrade_effectiveness_multiplier": 1.0 + (float(current_upgrade_level) * float(policy.get("upgrade_effectiveness_per_tier", 0.08))),
		"neutralize_rating": int(current_upgrade_level) * int(policy.get("neutralize_per_tier", 5)),
		"upgrade_text": upgrade_status_text
	}


func upgrade_bending_ability(actor: Person, ability_id: String) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Ability Upgrade",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var ability: Dictionary = get_bending_ability_by_id(actor, ability_id)
	if ability.is_empty():
		return {
			"success": false,
			"popup_title": "Ability Upgrade",
			"popup_text": "That bending ability is not available.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not bool(ability.get("unlocked", false)):
		return {
			"success": false,
			"popup_title": "Ability Locked",
			"popup_text": "%s must be unlocked before it can be upgraded.\n\n%s" % [
				str(ability.get("name", "That ability")),
				str(ability.get("lock_text", "Unlock path incomplete."))
			],
			"popup_footer": "Tap anywhere to continue."
		}

	var upgrade_report: Dictionary = _resolve_bending_ability_upgrade(actor, ability, str(ability.get("element", "")))
	if not bool(upgrade_report.get("can_upgrade", false)):
		return {
			"success": false,
			"popup_title": "Upgrade Locked",
			"popup_text": "%s cannot be upgraded yet.\n\n%s" % [
				str(ability.get("name", "That ability")),
				str(upgrade_report.get("upgrade_text", "Upgrade path incomplete."))
			],
			"popup_footer": "Tap anywhere to continue.",
			"upgrade_report": upgrade_report
		}

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var upgrades: Dictionary = _safe_dictionary(profile.get("ability_upgrades", {}))
	var clean_id: String = str(ability.get("id", ability_id)).strip_edges()
	var next_level: int = int(upgrade_report.get("next_upgrade_level", 1))
	var cost: int = int(upgrade_report.get("upgrade_cost", 1))

	actor.bending_skill_points = max(0, int(actor.bending_skill_points) - cost)
	upgrades [clean_id] = next_level
	profile ["ability_upgrades"] = upgrades
	profile ["ability_points_spent"] = max(0, int(profile.get("ability_points_spent", 0)) + cost)
	profile ["last_ability_upgrade"] = {
		"ability_id": clean_id,
		"ability_name": str(ability.get("name", clean_id)),
		"upgrade_level": next_level,
		"cost": cost,
		"year": int(gs.year) if gs != null else 0
	}

	_commit_bending_combat_profile(actor, profile)

	return {
		"success": true,
		"popup_title": "Ability Upgraded",
		"popup_text": "%s upgraded to Tier %d.\n\nSkill Points spent: %d\nRemaining Skill Points: %d" % [
			str(ability.get("name", "That ability")),
			next_level,
			cost,
			int(actor.bending_skill_points)
		],
		"popup_footer": "Tap anywhere to continue.",
		"ability_id": clean_id,
		"upgrade_level": next_level,
		"cost": cost,
		"remaining_points": int(actor.bending_skill_points)
	}


func _grant_bending_duel_progress_rewards(winner: Person, loser: Person, context: Dictionary, is_tournament: bool, ko: bool, death: bool) -> Dictionary:
	if winner == null or loser == null:
		return {}

	var winner_element: String = str(context.get("winner_element", context.get("element", ""))).strip_edges().to_lower()
	if winner_element == "":
		winner_element = _bending_person_primary_element(winner)

	if winner_element not in _base_bending_elements():
		return {}

	var winner_level: int = get_bending_level(winner, winner_element)
	var loser_level: int = get_primary_bending_level(loser)
	var level_delta: int = loser_level - winner_level
	var policy: Dictionary = _bending_progression_policy()
	var gain_policy: Dictionary = _safe_dictionary(policy.get("xp_gain", {}))
	var point_policy: Dictionary = _safe_dictionary(policy.get("skill_points", {}))

	var raw_gain: int = 1 + int(clamp(float(loser_level) / 22.0, 0.0, 5.0))

	if level_delta >= 8:
		raw_gain += 1
	if level_delta >= 18:
		raw_gain += 1
	if is_tournament:
		raw_gain += 2
	if ko:
		raw_gain += 1
	if death:
		raw_gain += 2

	var duel: Dictionary = _safe_dictionary(context.get("duel", {}))
	var damage_to_loser: int = int(duel.get("damage_to_target", duel.get("damage_to_loser", 0)))
	var damage_to_winner: int = int(duel.get("damage_to_player", duel.get("damage_to_winner", 0)))
	if damage_to_loser > damage_to_winner + 20:
		raw_gain += 1

	if str(context.get("source", "")).strip_edges().to_lower() == "scenario_engine":
		raw_gain = max(1, int(round(float(raw_gain) * float(gain_policy.get("scenario_engine_multiplier", 0.72)))))

	var reason: String = "winning a bending duel"
	if is_tournament:
		reason = "winning a bending tournament match"
	if level_delta >= 8:
		reason += " against a stronger bender"

	var progress_report: Dictionary = gain_bending_progress(winner, winner_element, raw_gain, reason)

	var skill_points: int = 1 + int(clamp(float(loser_level) / 32.0, 0.0, 3.0))
	if is_tournament:
		skill_points += int(point_policy.get("tournament_bonus", 1))
	if level_delta >= 8:
		skill_points += int(point_policy.get("upset_bonus", 1))
	if ko:
		skill_points += int(point_policy.get("ko_bonus", 1))
	if death:
		skill_points += 1

	skill_points = clamp(skill_points, 1, int(point_policy.get("max_duel_award", 7)))
	var skill_report: Dictionary = award_bending_skill_points(winner, skill_points, "bending_duel_reward")

	var willpower_report: Dictionary = {}
	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("apply_willpower_growth"):
		var winner_willpower: float = float(gs.willpower_engine.score(winner, {
			"source": "bending_duel_reward",
			"scope": "bending"
		}))
		var loser_willpower: float = float(gs.willpower_engine.score(loser, {
			"source": "bending_duel_reward_opponent",
			"scope": "bending"
		}))
		var beat_high_willpower_opponent: bool = loser_willpower >= 70.0 or loser_willpower >= winner_willpower + 8.0
		if beat_high_willpower_opponent:
			var willpower_gain: float = clamp(
				1.0
				+ max(0.0, loser_willpower - winner_willpower) / 18.0
				+ (1.25 if is_tournament else 0.0)
				+ (0.75 if ko else 0.0)
				+ (1.0 if level_delta >= 8 else 0.0),
				0.75,
				9.0
			)
			willpower_report = gs.willpower_engine.apply_willpower_growth(winner, willpower_gain, {
				"source": "high_willpower_bending_opponent_win",
				"scope": "bending",
				"reason": "defeating a high-willpower bending opponent",
				"opponent_id": int(loser.id),
				"opponent_name": _bending_person_label(loser),
				"opponent_willpower": loser_willpower,
				"winner_willpower_before": winner_willpower,
				"tournament": is_tournament,
				"ko": ko,
				"death": death
			})

	var loser_progress_report: Dictionary = {}
	if loser_level <= winner_level + 15:
		var loser_element: String = _bending_person_primary_element(loser)
		if loser_element in _base_bending_elements():
			loser_progress_report = gain_bending_progress(loser, loser_element, 1, "surviving a bending duel loss")

	return {
		"schema": "eralife.bending_duel_progress_reward_report",
		"version": 1,
		"winner_element": winner_element,
		"winner_level_before": winner_level,
		"loser_primary_level": loser_level,
		"level_delta": level_delta,
		"raw_gain": raw_gain,
		"skill_points_awarded": skill_points,
		"progress_report": progress_report,
		"skill_report": skill_report,
		"willpower_report": willpower_report,
		"loser_progress_report": loser_progress_report
	}
func _bending_combat_profile_needs_lineage_seed(profile: Dictionary) -> bool:
	if bool(profile.get("lineage_style_seeded", false)):
		return false
	if int(profile.get("style_points_spent", 0)) > 0:
		return false
	for stat_name in _bending_combat_stat_keys():
		if int(profile.get(stat_name, 50)) != 50:
			return false
	return true

func _stable_bending_variance(actor: Person, salt: String, spread: int = 14) -> int:
	if actor == null:
		return 0
	var clean_spread: int = max(0, int(spread))
	if clean_spread <= 0:
		return 0
	var signature: String = "%d|%s|%s|%s|%s|%s" % [
		int(actor.id),
		str(actor.first_name),
		str(actor.last_name),
		str(actor.bending_type),
		str(actor.bending_nation),
		str(salt)
	]
	var raw_hash: int = int(abs(signature.hash()))
	return int(raw_hash % ((clean_spread * 2) + 1)) - clean_spread

func _bending_primary_style_element(actor: Person) -> String:
	if actor == null:
		return ""
	ensure_bending_level_state(actor)
	var actor_type: String = str(actor.bending_type).strip_edges().to_lower()
	if actor_type in _base_bending_elements():
		return actor_type
	var best_element: String = ""
	var best_score: int = -999999
	for element in _base_bending_elements():
		var score: int = max(
			int(get_bending_level(actor, element)),
			int(get_bending_latent_potential(actor, element))
		)
		if actor_type == "avatar":
			score += 8
		if score > best_score:
			best_score = score
			best_element = element
	return best_element

func _bending_element_style_bias(element: String, stat_name: String) -> int:
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_stat: String = str(stat_name).strip_edges().to_lower()
	match clean_element:
		"air":
			match clean_stat:
				"evasion":
					return 12
				"accuracy", "focus":
					return 7
				"guard":
					return -3
				"power":
					return -5
		"earth":
			match clean_stat:
				"guard":
					return 12
				"power", "focus":
					return 7
				"evasion":
					return -5
		"fire":
			match clean_stat:
				"power":
					return 12
				"counter", "accuracy":
					return 7
				"guard":
					return -4
		"water":
			match clean_stat:
				"counter":
					return 10
				"guard", "focus":
					return 7
				"power":
					return -2
	return 0

func _bending_body_style_stat(actor: Person, stat_name: String) -> int:
	if actor == null:
		return 50
	ensure_bending_level_state(actor)
	ensure_bending_potential_state(actor)

	var clean_stat: String = str(stat_name).strip_edges().to_lower()
	var primary_element: String = _bending_primary_style_element(actor)
	var level_value: int = int(get_primary_bending_level(actor))
	var potential_value: int = int(get_primary_bending_potential(actor))
	if primary_element in _base_bending_elements():
		level_value = int(get_bending_level(actor, primary_element))
		potential_value = max(potential_value, int(get_bending_latent_potential(actor, primary_element)))

	var lineage_strength: float = 0.32
	if primary_element in _base_bending_elements():
		lineage_strength = _bending_family_line_strength(actor, primary_element)

	var value: int = 50
	value += _stable_bending_variance(actor, "combat_%s" % clean_stat, 17)
	value += _bending_element_style_bias(primary_element, clean_stat)
	value += int(round((float(potential_value) - 50.0) * 0.18))
	value += int(round(float(level_value) * 0.1))
	value += int(round((lineage_strength - 0.32) * 20.0))

	if bool(actor.is_royal) or bool(actor.is_ruler):
		if clean_stat in ["focus", "guard", "counter"]:
			value += 4

	var age_value: int = int(actor.age)
	if age_value < 18:
		var child_factor: float = clamp(float(max(0, age_value)) / 18.0, 0.16, 1.0)
		value = int(round(50.0 + ((float(value) - 50.0) * child_factor)))

	return clamp(value, 12, 98)

func _bending_parent_combat_average(actor: Person, stat_name: String) -> int:
	if actor == null:
		return -1
	var total: int = 0
	var count: int = 0
	for raw_parent_id in actor.parents:
		var parent: Person = _bending_lookup_person(int(raw_parent_id))
		if parent == null:
			continue
		var parent_profile: Dictionary = {}
		if typeof(parent.bending_combat_profile) == TYPE_DICTIONARY:
			parent_profile = parent.bending_combat_profile
		var parent_value: int = int(parent_profile.get(stat_name, _bending_body_style_stat(parent, stat_name)))
		if _bending_combat_profile_needs_lineage_seed(parent_profile):
			parent_value = _bending_body_style_stat(parent, stat_name)
		total += parent_value
		count += 1
	if count <= 0:
		return -1
	return clamp(int(round(float(total) / float(count))), 0, 100)

func _seed_lineage_bending_combat_profile(actor: Person, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var current: Dictionary = {}
	if typeof(actor.bending_combat_profile) == TYPE_DICTIONARY:
		current = actor.bending_combat_profile.duplicate(true)

	var force_seed: bool = bool(options.get("force", false))

	if int(current.get("style_points_spent", 0)) > 0:
		return current.duplicate(true)

	if not force_seed and not _bending_combat_profile_needs_lineage_seed(current):
		return current.duplicate(true)

	var seeded: Dictionary = _bending_default_combat_profile()

	for key in current.keys():
		seeded [key] = current [key]

	for stat_name in _bending_combat_stat_keys():
		var body_value: int = _bending_body_style_stat(actor, stat_name)
		var parent_value: int = _bending_parent_combat_average(actor, stat_name)
		var final_value: int = body_value

		if parent_value >= 0:
			final_value = int(round((float(body_value) * 0.42) + (float(parent_value) * 0.58)))

		if int(actor.age) < 18:
			var youth_factor: float = clamp(float(max(0, int(actor.age))) / 18.0, 0.16, 1.0)
			final_value = int(round(50.0 + ((float(final_value) - 50.0) * youth_factor)))

		seeded [stat_name] = clamp(final_value, 12, 98)

	seeded = _seed_spawn_bending_skill_allocation(actor, seeded, options)

	seeded ["schema"] = "eralife.person_bending_combat_profile"
	seeded ["version"] = 3
	seeded ["style_points_spent"] = max(0, int(seeded.get("style_points_spent", 0)))
	seeded ["lineage_style_seeded"] = true
	seeded ["lineage_style_seed_version"] = 2
	seeded ["lineage_style_source"] = str(options.get("source", "lineage_seed"))
	seeded ["lineage_primary_element"] = _bending_primary_style_element(actor)
	seeded ["lineage_seeded_at_year"] = int(gs.year) if gs != null else 0

	actor.bending_combat_profile = seeded.duplicate(true)

	if typeof(actor.power_profiles) == TYPE_DICTIONARY:
		var profiles: Dictionary = actor.power_profiles.duplicate(true)
		var bending: Dictionary = profiles.get("bending", {}) if typeof(profiles.get("bending", {})) == TYPE_DICTIONARY else {}
		bending ["combat_profile"] = seeded.duplicate(true)
		bending ["skill_points"] = int(actor.bending_skill_points)
		profiles ["bending"] = bending
		actor.power_profiles = profiles

	return seeded.duplicate(true)
func _seed_spawn_bending_skill_allocation(actor: Person, profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return profile

	var seeded: Dictionary = profile.duplicate(true)

	if bool(seeded.get("spawn_skill_allocation_seeded", false)):
		return seeded

	var primary_element: String = _bending_primary_style_element(actor)
	var primary_level: int = 0
	var primary_potential: int = 0

	if primary_element in _base_bending_elements():
		primary_level = int(get_bending_level(actor, primary_element))
		primary_potential = int(get_bending_latent_potential(actor, primary_element))

	var parent_signal: int = 0
	if primary_element in _base_bending_elements():
		parent_signal = _bending_parent_signal_for_element(actor, primary_element)

	var point_budget: int = 3
	point_budget += int(round(float(primary_potential) / 28.0))
	point_budget += int(round(float(primary_level) / 32.0))

	if parent_signal > 0:
		point_budget += clamp(int(round((float(parent_signal) - 50.0) / 18.0)), 0, 4)

	if str(actor.bending_type).strip_edges().to_lower() == "avatar":
		point_budget += 4

	point_budget = clamp(point_budget, 3, 14)

	var rng: RandomNumberGenerator = _stable_bending_rng(actor, "spawn_skill_allocation_%s" % str(options.get("source", "birth")))
	var stat_order: Array = _weighted_bending_spawn_stat_order(actor, primary_element, rng)
	var allocation: Dictionary = {}

	for stat_name in _bending_combat_stat_keys():
		allocation [stat_name] = 0

	for i in range(point_budget):
		if stat_order.is_empty():
			break

		var stat_name: String = str(stat_order [i % stat_order.size()])
		var parent_average: int = _bending_parent_combat_average(actor, stat_name)
		var family_nudge: int = 0

		if parent_average >= 0:
			family_nudge = clamp(int(round((float(parent_average) - 50.0) / 18.0)), -2, 4)

		var elemental_nudge: int = clamp(int(round(float(_bending_element_style_bias(primary_element, stat_name)) / 4.0)), -2, 4)
		var gain: int = 1 + int(rng.randi_range(0, 2))
		gain += max(0, family_nudge)
		gain += max(0, elemental_nudge)
		gain = clamp(gain, 1, 5)

		seeded [stat_name] = clamp(int(seeded.get(stat_name, 50)) + gain, 0, 100)
		allocation [stat_name] = int(allocation.get(stat_name, 0)) + gain

	seeded ["spawn_skill_allocation_seeded"] = true
	seeded ["spawn_skill_allocation_version"] = 1
	seeded ["spawn_skill_allocation_source"] = str(options.get("source", "birth"))
	seeded ["spawn_skill_allocation_points"] = point_budget
	seeded ["spawn_skill_allocation"] = allocation
	seeded ["spawn_skill_allocation_primary_element"] = primary_element
	seeded ["spawn_skill_allocation_parent_signal"] = parent_signal

	return seeded


func _weighted_bending_spawn_stat_order(actor: Person, primary_element: String, rng: RandomNumberGenerator) -> Array:
	var rows: Array = []

	for stat_name in _bending_combat_stat_keys():
		var parent_average: int = _bending_parent_combat_average(actor, stat_name)
		var parent_weight: int = 0

		if parent_average >= 0:
			parent_weight = clamp(int(round((float(parent_average) - 50.0) / 5.0)), -8, 12)

		var element_weight: int = _bending_element_style_bias(primary_element, stat_name)
		var random_weight: int = int(rng.randi_range(0, 12))

		rows.append({
			"stat": stat_name,
			"weight": 25 + parent_weight + element_weight + random_weight
		})

	rows.sort_custom(func (a, b): return int(a.get("weight", 0)) > int(b.get("weight", 0)))

	var out: Array = []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str(row.get("stat", "")))

	return out


func _stable_bending_rng(actor: Person, salt: String) -> RandomNumberGenerator:
	var rng:= RandomNumberGenerator.new()

	var signature: String = "%d|%s|%s|%s|%s|%s" % [
		int(actor.id) if actor != null else 0,
		str(actor.first_name) if actor != null else "",
		str(actor.last_name) if actor != null else "",
		str(actor.bending_type) if actor != null else "",
		str(actor.bending_nation) if actor != null else "",
		str(salt)
	]

	rng.seed = abs(int(signature.hash()))
	return rng

func _bending_parent_signal_for_element_from_list(parents: Array, element: String) -> int:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return 0

	var strongest: int = 0

	for raw_parent in parents:
		if raw_parent == null:
			continue
		if not raw_parent is Person:
			continue

		var parent: Person = raw_parent

		_ensure_bending_level_storage_only(parent)
		_ensure_bending_potential_storage_only(parent)

		var parent_type: String = str(parent.bending_type).strip_edges().to_lower()
		var parent_signal_value: int = max(
			_raw_bending_level(parent, clean_element),
			_raw_bending_latent_potential(parent, clean_element)
		)

		if parent_type == "avatar":
			parent_signal_value = max(parent_signal_value, 78)
		elif parent_type == clean_element:
			parent_signal_value = max(parent_signal_value, 62)

		strongest = max(strongest, parent_signal_value)

	return int(clamp(strongest, 0, 100))

func _bending_parent_signal_for_element(actor: Person, element: String) -> int:
	if actor == null:
		return 0
	return _bending_parent_signal_for_element_from_list(_resolve_birth_parents(actor), element)

func _apply_lineage_bending_child_profile(npc: Person, parents: Array = [], inherited_element: String = "", inherited_avatar: bool = false) -> void:
	if npc == null:
		return

	var resolved_parents: Array = parents.duplicate()
	if resolved_parents.is_empty():
		resolved_parents = _resolve_birth_parents(npc)

	ensure_bending_level_state(npc)
	ensure_bending_potential_state(npc)

	var clean_inherited_element: String = str(inherited_element).strip_edges().to_lower()
	var age_value: int = int(npc.age)

	for element in _base_bending_elements():
		var parent_signal: int = _bending_parent_signal_for_element_from_list(resolved_parents, element)
		var inherited_focus: bool = inherited_avatar or element == clean_inherited_element
		if parent_signal <= 0 and not inherited_focus:
			continue

		var base_signal: int = parent_signal
		if base_signal <= 0 and inherited_focus:
			base_signal = 58

		var variance: int = _stable_bending_variance(npc, "child_potential_%s" % element, 8)
		var mixed_potential: int = int(round(float(base_signal) * 0.72)) + variance
		var floor_value: int = 0

		if inherited_avatar:
			floor_value = 54
		elif element == clean_inherited_element:
			floor_value = 42
		elif parent_signal >= 85:
			floor_value = 26

		var current_potential: int = int(npc.bending_latent_potential.get(element, 0))
		var final_potential: int = clamp(max(current_potential, mixed_potential, floor_value), 0, BENDING_LATENT_POTENTIAL_MAX)
		npc.bending_latent_potential [element] = final_potential

		if age_value < 3:
			npc.bending_mastery [element] = 0
		elif final_potential > 0:
			var growth_factor: float = clamp(float(age_value - 3) / 15.0, 0.0, 1.0)
			var inherited_level: int = int(round(float(final_potential) * growth_factor * 0.55))
			npc.bending_mastery [element] = max(
				int(npc.bending_mastery.get(element, 0)),
				clamp(inherited_level, 0, BENDING_LEVEL_MAX)
			)

	if clean_inherited_element in _base_bending_elements() and int(npc.bending_latent_potential.get(clean_inherited_element, 0)) <= 0:
		seed_birth_bending_potential(npc, clean_inherited_element, 1)

	_seed_lineage_bending_combat_profile(npc, {
		"force": true,
		"source": "child_lineage_inheritance"
	})

func _has_rare_four_master_bending_potential(actor: Person) -> bool:
	if actor == null:
		return false
	ensure_bending_potential_state(actor)

	var actor_type: String = str(actor.bending_type).strip_edges().to_lower()
	if actor_type == "avatar" or bool(actor.avatar_state_unlocked):
		return true

	var high_count: int = 0
	var total: int = 0
	var strongest: int = 0
	for element in _base_bending_elements():
		var potential_value: int = int(get_bending_latent_potential(actor, element))
		var lineage_signal: int = int(round(_bending_family_line_strength(actor, element) * 100.0))
		var combined: int = max(potential_value, lineage_signal)
		total += combined
		strongest = max(strongest, combined)
		if combined >= 72:
			high_count += 1

	var average_value: int = int(round(float(total) / float(max(1, _base_bending_elements().size()))))
	return high_count >= 4 and average_value >= 68 and strongest >= 82

func _can_attempt_bending_awakening(actor: Person, element: String) -> bool:
	if actor == null:
		return false
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in _base_bending_elements():
		return false

	ensure_bending_level_state(actor)
	ensure_bending_potential_state(actor)

	if int(get_bending_level(actor, clean_element)) > 0:
		return false

	var actor_type: String = str(actor.bending_type).strip_edges().to_lower()
	var is_avatar: bool = actor_type == "avatar" or bool(actor.avatar_state_unlocked)
	if is_avatar:
		return true

	var potential_value: int = int(get_bending_latent_potential(actor, clean_element))
	if potential_value >= 84:
		return true

	var parent_signal: int = _bending_parent_signal_for_element(actor, clean_element)
	if parent_signal >= 82 and potential_value >= 62:
		return true

	if _has_rare_four_master_bending_potential(actor) and potential_value >= 58:
		return true

	return false
func ensure_bending_combat_profile(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	if typeof(actor.bending_combat_profile) != TYPE_DICTIONARY:
		actor.bending_combat_profile = {}

	var profile: Dictionary = actor.bending_combat_profile.duplicate(true)
	var defaults: Dictionary = _bending_default_combat_profile()

	for key in defaults.keys():
		if not profile.has(key):
			profile [key] = defaults [key]

	if _bending_combat_profile_needs_lineage_seed(profile):
		profile = _seed_lineage_bending_combat_profile(actor, {
			"force": true,
			"source": "ensure_bending_combat_profile"
		})
	else:
		var caps: Dictionary = _safe_dictionary(profile.get("skill_caps", {}))
		if caps.is_empty() or int(profile.get("skill_cap_version", 0)) < 1:
			caps = _bending_resolve_skill_caps(actor, profile)
			profile ["skill_caps"] = caps.duplicate(true)
			profile ["skill_cap_version"] = 1

		for key in _bending_combat_stat_keys():
			var cap_value: int = clamp(int(caps.get(key, 100)), 1, 100)
			profile [key] = clamp(int(profile.get(key, defaults.get(key, 50))), 0, cap_value)

		profile ["style_points_spent"] = max(0, int(profile.get("style_points_spent", 0)))
		profile ["ability_points_spent"] = max(0, int(profile.get("ability_points_spent", 0)))
		profile ["ability_upgrades"] = _safe_dictionary(profile.get("ability_upgrades", {}))
		profile ["level_xp"] = _safe_dictionary(profile.get("level_xp", {}))
		profile ["level_xp_lifetime"] = _safe_dictionary(profile.get("level_xp_lifetime", {}))

	if not bool(profile.get("ability_upgrade_seeded", false)) or int(profile.get("ability_upgrade_seed_version", 0)) < 1:
		profile = _seed_existing_bending_ability_upgrades(actor, profile)

	profile ["schema"] = "eralife.person_bending_combat_profile"
	profile ["version"] = 4

	return _commit_bending_combat_profile(actor, profile)
func _seeded_ability_upgrade_cap_for_level(level: int) -> int:
	var clean_level: int = clamp(int(level), 0, BENDING_LEVEL_MAX)

	if clean_level >= 85:
		return 4
	if clean_level >= 70:
		return 3
	if clean_level >= 55:
		return 2
	if clean_level >= 35:
		return 1

	return 0


func _seeded_ability_upgrade_budget_for_level(level: int) -> int:
	var clean_level: int = clamp(int(level), 0, BENDING_LEVEL_MAX)

	if clean_level >= 90:
		return 8
	if clean_level >= 75:
		return 6
	if clean_level >= 60:
		return 4
	if clean_level >= 40:
		return 2

	return 0


func _seed_existing_bending_ability_upgrades(actor: Person, profile: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	if actor == null:
		return out

	var upgrades: Dictionary = _safe_dictionary(out.get("ability_upgrades", {}))
	var seeded_rows: Array = _safe_array(out.get("seeded_ability_upgrade_rows", []))
	var seen_ids: Dictionary = {}

	for raw_element in _active_elements_for_actor(actor):
		var element: String = str(raw_element).strip_edges().to_lower()
		if element not in _base_bending_elements():
			continue

		var level: int = get_bending_level(actor, element)
		var max_seed_tier: int = _seeded_ability_upgrade_cap_for_level(level)
		var budget: int = _seeded_ability_upgrade_budget_for_level(level)

		if max_seed_tier <= 0 or budget <= 0:
			continue

		var candidates: Array = []

		for raw_ability in get_bending_abilities_for_element(element):
			if typeof(raw_ability) != TYPE_DICTIONARY:
				continue

			var ability: Dictionary = raw_ability
			var ability_id: String = str(ability.get("id", "")).strip_edges()
			if ability_id == "":
				continue
			if bool(seen_ids.get(ability_id, false)):
				continue

			var unlock_kind: String = str(ability.get("unlock_kind", "")).strip_edges().to_lower()
			if unlock_kind in ["goal", "story_goal", "quest", "quest_only", "goal_only"]:
				continue

			var required_level: int = _bending_ability_required_level(ability)
			var min_age: int = int(ability.get("min_age", ability.get("age_requirement", _default_bending_ability_min_age(required_level))))

			if int(actor.age) < min_age:
				continue
			if level < required_level:
				continue

			var depth: int = level - required_level
			if depth < 3:
				continue

			var seed_hash: int = abs(int(("%d:%s:%s" % [int(actor.id), element, ability_id]).hash()))

			candidates.append({
				"id": ability_id,
				"name": str(ability.get("name", ability_id)),
				"element": element,
				"required_level": required_level,
				"depth": depth,
				"seed_hash": seed_hash
			})

			seen_ids [ability_id] = true

		candidates.sort_custom(func (a, b):
			if int(a.get("required_level", 0)) != int(b.get("required_level", 0)):
				return int(a.get("required_level", 0)) > int(b.get("required_level", 0))
			return int(a.get("seed_hash", 0)) < int(b.get("seed_hash", 0))
		)

		var applied: int = 0
		for raw_candidate in candidates:
			if typeof(raw_candidate) != TYPE_DICTIONARY:
				continue
			if applied >= budget:
				break

			var candidate: Dictionary = raw_candidate
			var ability_id: String = str(candidate.get("id", "")).strip_edges()
			if ability_id == "":
				continue
			if int(upgrades.get(ability_id, 0)) > 0:
				continue

			var depth: int = int(candidate.get("depth", 0))
			var seed_hash: int = int(candidate.get("seed_hash", 0))
			var depth_cap: int = clamp(1 + int(floor(float(depth) / 18.0)), 1, max_seed_tier)
			var seeded_tier: int = clamp(1 + int(seed_hash % max_seed_tier), 1, depth_cap)

			upgrades [ability_id] = seeded_tier
			seeded_rows.append({
				"ability_id": ability_id,
				"ability_name": str(candidate.get("name", ability_id)),
				"element": element,
				"seeded_tier": seeded_tier,
				"actor_level": level,
				"required_level": int(candidate.get("required_level", 0)),
				"source": "existing_bender_history",
				"year": int(gs.year) if gs != null else 0
			})
			applied += 1

	out ["ability_upgrades"] = upgrades
	out ["ability_upgrade_seeded"] = true
	out ["ability_upgrade_seed_version"] = 1
	out ["seeded_ability_upgrade_rows"] = seeded_rows

	return out


func get_bending_combat_stat(actor: Person, stat_name: String) -> int:
	if actor == null:
		return 0
	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var clean_stat: String = str(stat_name).strip_edges().to_lower()
	return clamp(int(profile.get(clean_stat, 50)), 0, 100)


func award_bending_skill_points(actor: Person, amount: int, reason: String = "bending_growth") -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Missing actor."
		}

	var clean_amount: int = max(0, int(amount))
	if clean_amount <= 0:
		return {
			"success": true,
			"awarded": 0,
			"total": int(actor.bending_skill_points),
			"reason": reason
		}

	actor.bending_skill_points = max(0, int(actor.bending_skill_points) + clean_amount)
	ensure_bending_combat_profile(actor)

	return {
		"success": true,
		"awarded": clean_amount,
		"total": int(actor.bending_skill_points),
		"reason": reason
	}


func allocate_bending_skill_point(actor: Person, stat_name: String, amount: int = 1) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Missing actor."
		}

	var clean_stat: String = str(stat_name).strip_edges().to_lower()
	if clean_stat not in _bending_combat_stat_keys():
		return {
			"success": false,
			"reason": "Unknown bending combat stat."
		}

	var available_points: int = max(0, int(actor.bending_skill_points))
	var requested_spend: int = max(1, int(amount))

	if available_points <= 0:
		return {
			"success": false,
			"popup_title": "Not Enough Skill Points",
			"popup_text": "You need more bending skill points before upgrading %s." % clean_stat.capitalize(),
			"popup_footer": "Tap anywhere to continue.",
			"reason": "Not enough skill points."
		}

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var caps: Dictionary = _safe_dictionary(profile.get("skill_caps", {}))
	if caps.is_empty():
		caps = _bending_resolve_skill_caps(actor, profile)
		profile ["skill_caps"] = caps

	var cap_value: int = clamp(int(caps.get(clean_stat, 100)), 1, 100)
	var before_value: int = clamp(int(profile.get(clean_stat, 50)), 0, cap_value)

	if before_value >= cap_value:
		return {
			"success": false,
			"popup_title": "Category Capped",
			"popup_text": "%s is capped at %d for this build.\n\nYour family line, element style, potential, and special events determine this cap." % [
				clean_stat.capitalize(),
				cap_value
			],
			"popup_footer": "Tap anywhere to continue.",
			"reason": "Stat capped.",
			"cap": cap_value
		}

	var multiplier: float = _avatar_state_skill_multiplier_for_stat(actor, clean_stat)
	var remaining_gain: int = max(0, cap_value - before_value)
	var raw_points_to_cap: int = max(1, int(ceil(float(remaining_gain) / max(0.01, multiplier))))

	var actually_spent: int = min(requested_spend, available_points)
	actually_spent = min(actually_spent, raw_points_to_cap)

	var effective_gain: int = max(1, int(round(float(actually_spent) * multiplier)))
	var after_value: int = clamp(before_value + effective_gain, 0, cap_value)
	var actual_gain: int = after_value - before_value

	if actual_gain <= 0:
		return {
			"success": false,
			"popup_title": "Category Capped",
			"popup_text": "%s is capped at %d for this build." % [
				clean_stat.capitalize(),
				cap_value
			],
			"popup_footer": "Tap anywhere to continue.",
			"reason": "Stat capped.",
			"cap": cap_value
		}

	actor.bending_skill_points = max(0, int(actor.bending_skill_points) - actually_spent)

	profile [clean_stat] = after_value
	profile ["style_points_spent"] = max(0, int(profile.get("style_points_spent", 0)) + actually_spent)
	profile ["avatar_state_last_multiplier_used"] = multiplier
	_commit_bending_combat_profile(actor, profile)

	var multiplier_line: String = ""
	if multiplier > 1.0:
		multiplier_line = "\n\nAvatar State multiplier: %.2fx\nEffective gain: +%d" % [
			multiplier,
			actual_gain
		]

	return {
		"success": true,
		"popup_title": "Skill Points Added",
		"popup_text": "%s improved from %d to %d / %d.%s\n\nSkill Points spent: %d\nRemaining Skill Points: %d" % [
			clean_stat.capitalize(),
			before_value,
			after_value,
			cap_value,
			multiplier_line,
			actually_spent,
			int(actor.bending_skill_points)
		],
		"popup_footer": "Tap anywhere to continue.",
		"stat": clean_stat,
		"before": before_value,
		"after": after_value,
		"cap": cap_value,
		"spent": actually_spent,
		"effective_gain": actual_gain,
		"avatar_state_multiplier": multiplier,
		"remaining_points": int(actor.bending_skill_points)
	}


func get_bending_skill_allocation_rows(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var caps: Dictionary = _safe_dictionary(profile.get("skill_caps", {}))
	if caps.is_empty():
		caps = _bending_resolve_skill_caps(actor, profile)
		profile ["skill_caps"] = caps
		_commit_bending_combat_profile(actor, profile)

	var points: int = max(0, int(actor.bending_skill_points))
	out.append({
		"id": "bending_skill_points_summary",
		"name": "Available Skill Points",
		"type": "summary",
		"description": "Spend points earned from duels, tournaments, and level milestones to shape your bending style.\n\nCaps are deterministic and come from your family line, element style, potential, and special events. Rare events can extend them.",
		"value": points,
		"label": "Available Skill Points: %d" % points,
		"disabled": true
	})

	for stat_name in _bending_combat_stat_keys():
		var cap_value: int = clamp(int(caps.get(stat_name, 100)), 1, 100)
		var value: int = clamp(int(profile.get(stat_name, 50)), 0, cap_value)
		var multiplier: float = _avatar_state_skill_multiplier_for_stat(actor, stat_name)
		var remaining_gain: int = max(0, cap_value - value)
		var raw_points_to_cap: int = 0
		if remaining_gain > 0:
			raw_points_to_cap = max(1, int(ceil(float(remaining_gain) / max(0.01, multiplier))))

		var max_spend: int = min(points, raw_points_to_cap)
		var cap_line: String = "Natural cap: %d" % cap_value
		if multiplier > 1.0:
			cap_line += " • Avatar State efficiency %.2fx" % multiplier

		out.append({
			"id": "bending_allocate_%s" % stat_name,
			"name": stat_name.capitalize(),
			"type": "allocation",
			"stat": stat_name,
			"value": value,
			"cap": cap_value,
			"available_points": points,
			"max_spend": max_spend,
			"label": "%s %d/%d" % [stat_name.capitalize(), value, cap_value],
			"description": _bending_combat_stat_description(stat_name),
			"cap_label": cap_line,
			"button_label": "Add skill points",
			"action_id": "bending_allocate:%s" % stat_name,
			"disabled": points <= 0 or value >= cap_value or max_spend <= 0
		})

	return out
func _bending_combat_stat_description(stat_name: String) -> String:
	match str(stat_name).strip_edges().to_lower():
		"accuracy":
			return "Improves your chance to land bending attacks and advanced techniques."
		"power":
			return "Improves raw damage from offensive bending."
		"guard":
			return "Improves defensive stance, shields, and impact reduction."
		"counter":
			return "Improves attack-as-defense exchanges and reversal damage."
		"evasion":
			return "Improves movement, escape, and partial damage avoidance."
		"focus":
			return "Improves read bonuses, accuracy stability, and pressure resistance."
		_:
			return "Improves bending combat performance."


func modify_respect(actor: Person, delta: int, reason: String = "life_event", channel: String = "general") -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Missing actor."
		}

	if typeof(actor.respect_profile) != TYPE_DICTIONARY:
		actor.respect_profile = {}

	var clean_channel: String = str(channel).strip_edges().to_lower()
	if clean_channel == "":
		clean_channel = "general"

	var profile: Dictionary = actor.respect_profile.duplicate(true)
	var before_general: int = clamp(int(profile.get("general", actor.respect)), 0, 100)
	var before_channel: int = clamp(int(profile.get(clean_channel, before_general)), 0, 100)
	var clean_delta: int = int(delta)

	profile ["general"] = clamp(before_general + int(round(float(clean_delta) * 0.5)), 0, 100)
	profile [clean_channel] = clamp(before_channel + clean_delta, 0, 100)
	profile ["last_delta"] = clean_delta
	profile ["last_reason"] = reason
	actor.respect_profile = profile.duplicate(true)
	actor.respect = int(profile.get("general", 50))

	return {
		"success": true,
		"channel": clean_channel,
		"delta": clean_delta,
		"general": int(actor.respect),
		"channel_value": int(profile.get(clean_channel, 50)),
		"reason": reason
	}
func get_respect(actor: Person, channel: String = "general") -> int:
	if actor == null:
		return 0

	var clean_channel: String = str(channel).strip_edges().to_lower()
	if clean_channel == "":
		clean_channel = "general"

	if typeof(actor.respect_profile) != TYPE_DICTIONARY:
		actor.respect_profile = {
			"schema": "eralife.person_respect_profile",
			"version": 1,
			"general": clamp(int(actor.respect), 0, 100),
			"bending": clamp(int(actor.respect), 0, 100),
			"family": 50,
			"public": clamp(int(actor.fame), 0, 100),
			"fear": 0,
			"honor": 50,
			"last_delta": 0,
			"last_reason": "initialized_from_bending_engine"
		}

	var profile: Dictionary = actor.respect_profile
	var fallback_general: int = clamp(int(profile.get("general", actor.respect)), 0, 100)
	return clamp(int(profile.get(clean_channel, fallback_general)), 0, 100)

func build_bending_combat_packet(actor: Person, ability: Dictionary = {}, element: String = "") -> Dictionary:
	if actor == null:
		return {}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = str(ability.get("element", "")).strip_edges().to_lower()
	if clean_element == "":
		clean_element = str(actor.bending_type).strip_edges().to_lower()

	var level: int = get_bending_level(actor, clean_element)
	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var ability_type: String = str(ability.get("type", "attack")).strip_edges().to_lower()
	var required_level: int = _bending_ability_required_level(ability)
	var level_over_requirement: int = max(0, level - required_level)
	var upgrade_level: int = int(ability.get("upgrade_level", 0))
	var upgrade_multiplier: float = float(ability.get("upgrade_effectiveness_multiplier", 1.0))
	var neutralize_rating: int = int(ability.get("neutralize_rating", 0))

	var accuracy: int = clamp(
		42
		+ int(float(level) * 0.38)
		+ int(float(profile.get("accuracy", 50)) * 0.38)
		+ int(float(profile.get("focus", 50)) * 0.14)
		+ int(float(level_over_requirement) * 0.2)
		+ upgrade_level * 3,
		12,
		98
	)

	var power: int = clamp(
		8
		+ int(float(level) * 0.34)
		+ int(float(profile.get("power", 50)) * 0.24)
		+ int(float(actor.health) * 0.08)
		+ upgrade_level * 4,
		2,
		140
	)

	var guard: int = clamp(
		6
		+ int(float(level) * 0.24)
		+ int(float(profile.get("guard", 50)) * 0.34)
		+ int(float(profile.get("focus", 50)) * 0.12)
		+ upgrade_level * 4,
		0,
		140
	)

	var counter: int = clamp(
		5
		+ int(float(level) * 0.22)
		+ int(float(profile.get("counter", 50)) * 0.34)
		+ int(float(profile.get("accuracy", 50)) * 0.1)
		+ upgrade_level * 4,
		0,
		140
	)

	var evasion: int = clamp(
		4
		+ int(float(level) * 0.18)
		+ int(float(profile.get("evasion", 50)) * 0.42)
		+ int(float(profile.get("focus", 50)) * 0.08)
		+ upgrade_level * 4,
		0,
		140
	)

	if ability_type in ["defense", "guard"]:
		guard += 12 + neutralize_rating
	elif ability_type in ["control"]:
		accuracy += 5
		counter += 4 + neutralize_rating
	elif ability_type in ["escape"]:
		evasion += 18 + neutralize_rating
	elif ability_type in ["attack"]:
		power += 10 + int(round(float(neutralize_rating) * 0.45))

	power = int(round(float(power) * upgrade_multiplier))
	guard = int(round(float(guard) * upgrade_multiplier))
	counter = int(round(float(counter) * upgrade_multiplier))
	evasion = int(round(float(evasion) * upgrade_multiplier))

	return {
		"schema": "eralife.bending_combat_packet",
		"version": 2,
		"element": clean_element,
		"ability_id": str(ability.get("id", "")),
		"ability_type": ability_type,
		"level": level,
		"required_level": required_level,
		"upgrade_level": upgrade_level,
		"upgrade_effectiveness_multiplier": upgrade_multiplier,
		"neutralize_rating": neutralize_rating,
		"accuracy": clamp(accuracy, 1, 99),
		"power": max(1, power),
		"guard": max(0, guard),
		"counter": max(0, counter),
		"evasion": max(0, evasion),
		"focus": clamp(int(profile.get("focus", 50)), 0, 100)
	}
func get_available_bending_abilities(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	ensure_bending_level_state(actor)
	ensure_bending_combat_profile(actor)

	for element in _active_elements_for_actor(actor):
		var clean_element: String = str(element).strip_edges().to_lower()
		var level: int = get_bending_level(actor, clean_element)

		for raw_ability in get_bending_abilities_for_element(clean_element):
			var ability: Dictionary = raw_ability.duplicate(true)
			var cooldown_active: bool = _ability_is_on_cooldown(actor, str(ability.get("id", "")))
			var unlock_report: Dictionary = _resolve_bending_ability_unlock(actor, ability, clean_element, level)

			for unlock_key in unlock_report.keys():
				ability [str(unlock_key)] = unlock_report [unlock_key]

			ability ["element"] = clean_element
			ability ["level"] = int(unlock_report.get("required_level", int(ability.get("level", 0))))
			ability ["current_level"] = level
			ability ["on_cooldown"] = cooldown_active
			ability ["combat_packet"] = build_bending_combat_packet(actor, ability, clean_element)

			var visual_profile: Dictionary = get_bending_ability_visual_profile(actor, ability)
			for visual_key in visual_profile.keys():
				ability [str(visual_key)] = visual_profile [visual_key]

			if cooldown_active:
				ability ["lock_text"] = "Recovering"
				ability ["unlock_path"] = "Recovering"
			elif str(ability.get("lock_text", "")).strip_edges() == "":
				ability ["lock_text"] = "Ready" if bool(ability.get("unlocked", false)) else "Unlock path incomplete"
				ability ["unlock_path"] = str(ability.get("lock_text", ""))

			out.append(ability)

	return out
func get_unlocked_bending_combat_abilities(actor: Person, element_filter: String = "", options: Dictionary = {}) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var clean_filter: String = str(element_filter).strip_edges().to_lower()
	var include_cooldown: bool = bool(options.get("include_cooldown", false))

	for raw_ability in get_available_bending_abilities(actor):
		if typeof(raw_ability) != TYPE_DICTIONARY:
			continue

		var ability: Dictionary = raw_ability.duplicate(true)
		if not bool(ability.get("unlocked", false)):
			continue

		if bool(ability.get("on_cooldown", false)) and not include_cooldown:
			continue

		var ability_element: String = str(ability.get("element", "")).strip_edges().to_lower()
		if clean_filter != "" and ability_element != clean_filter:
			continue

		out.append(ability)

	out.sort_custom(func (a, b): return int(a.get("current_level", a.get("level", 0))) > int(b.get("current_level", b.get("level", 0))))
	return out


func get_unlocked_bending_ability_by_id(actor: Person, ability_id: String, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var clean_id: String = str(ability_id).strip_edges()
	if clean_id == "":
		return {}

	for ability in get_unlocked_bending_combat_abilities(actor, "", options):
		if str(ability.get("id", "")).strip_edges() == clean_id:
			return ability.duplicate(true)

	return {}
func get_bending_ability_by_id(actor: Person, ability_id: String) -> Dictionary:
	if actor == null:
		return {}
	for ability in get_available_bending_abilities(actor):
		if str(ability.get("id", "")) == str(ability_id):
			return ability.duplicate(true)
	return {}

func get_bending_targets_for_player(actor: Person, ability_id:= "", include_self:= false) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out

	var ability: Dictionary = get_bending_ability_by_id(actor, ability_id) if ability_id != "" else {}
	var scope: String = str(ability.get("target_scope", "nation")).strip_edges()
	if include_self or scope in ["self", "self_or_nation"]:
		out.append({
			"id": int(actor.id),
			"name": "%s %s" % [actor.first_name, actor.last_name],
			"relation": "Self",
			"score": 9999
		})
	if scope == "self":
		return out

	var actor_nation: String = str(actor.bending_nation).strip_edges()
	var actor_country: String = str(actor.home_country).strip_edges()
	if actor_country == "":
		actor_country = str(actor.birth_country).strip_edges()

	for candidate in gs.npcs:
		if candidate == null:
			continue
		if int(candidate.id) == int(actor.id):
			continue
		if not candidate.alive:
			continue

		var same_nation: bool = actor_nation != "" and str(candidate.bending_nation).strip_edges() == actor_nation
		var candidate_country: String = str(candidate.home_country).strip_edges()
		if candidate_country == "":
			candidate_country = str(candidate.birth_country).strip_edges()
		var same_country: bool = actor_country != "" and candidate_country == actor_country

		if not same_nation and not same_country:
			continue

		var score: int = 10
		var relation_text: String = "Nation"
		if actor.children.has(candidate.id) or candidate.children.has(actor.id):
			score += 300
			relation_text = "Family"
		elif actor.parents.has(candidate.id) or candidate.parents.has(actor.id):
			score += 280
			relation_text = "Family"
		elif candidate.id in actor.friends:
			score += 220
			relation_text = "Friend"

		if actor.affection.has(candidate.id):
			score += int(actor.affection.get(candidate.id, 0))
		if candidate.affection.has(actor.id):
			var candidate_affection_bonus: int = int(floor(float(candidate.affection.get(actor.id, 0)) / 2.0))
			score += candidate_affection_bonus

		out.append({
			"id": int(candidate.id),
			"name": "%s %s" % [candidate.first_name, candidate.last_name],
			"relation": relation_text,
			"score": score
		})

	out.sort_custom(func (a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return out

func use_bending_ability(actor: Person, target: Person, ability_id: String) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("bending"):
		return { "success": false, "text": "Bending is disabled in this reality mode."}

	if actor == null:
		return { "success": false, "text": "No bender selected."}

	var ability: Dictionary = get_bending_ability_by_id(actor, ability_id)
	if ability.is_empty():
		return { "success": false, "text": "That bending ability does not exist yet."}

	var element: String = str(ability.get("element", "")).strip_edges().to_lower()
	var _required_level: int = int(ability.get("level", 0))
	var current_level: int = int(ability.get("current_level", get_bending_level(actor, element)))
	var lock_text: String = str(ability.get("lock_text", "")).strip_edges()

	if not bool(ability.get("unlocked", false)):
		if lock_text == "":
			lock_text = "Unlock path incomplete."
		return {
			"success": false,
			"popup_title": "Bending Skill Locked",
			"popup_text": "%s is locked.\n\nUnlock Path: %s" % [
				str(ability.get("name", "That skill")),
				lock_text
			],
			"popup_footer": "Tap anywhere to continue.",
			"text": "%s is locked: %s" % [
				str(ability.get("name", "That skill")),
				lock_text
			]
		}

	if _ability_is_on_cooldown(actor, ability_id):
		return { "success": false, "text": "%s is still recovering." % str(ability.get("name", "That skill"))}

	var scope: String = str(ability.get("target_scope", "nation"))
	if target == null and scope != "self":
		return { "success": false, "text": "No target selected."}

	if target == null:
		target = actor

	var ability_type: String = str(ability.get("type", "utility")).strip_edges().to_lower()
	var impact: String = str(ability.get("impact", "normal")).strip_edges().to_lower()
	var current_level_float: float = float(current_level)
	var level_half: int = int(floor(current_level_float / 2.0))
	var level_seventh: int = int(floor(current_level_float / 7.0))
	var level_tenth: int = int(floor(current_level_float / 10.0))
	var level_fifth: int = int(floor(current_level_float / 5.0))
	var level_twentieth: int = int(floor(current_level_float / 20.0))

	var impact_bonus: int = 0
	match impact:
		"heavy":
			impact_bonus = 4
		"elite":
			impact_bonus = 9
		"catastrophic":
			impact_bonus = 16
		_:
			impact_bonus = 0

	var success_chance: int = int(clamp(45 + level_half - int(floor(float(impact_bonus) * 0.35)), 38, 94))
	var success_roll: bool = (randi() % 100) < success_chance
	var health_delta: int = 0

	match ability_type:
		"attack":
			health_delta = - int(clamp(4 + level_seventh + impact_bonus, 6, 44))
		"control":
			health_delta = - int(clamp(2 + level_tenth + int(floor(float(impact_bonus) * 0.7)), 3, 34))
		"heal":
			health_delta = int(clamp(8 + level_fifth + int(floor(float(impact_bonus) * 0.4)), 10, 38))
		"defense":
			health_delta = int(clamp(2 + level_tenth + int(floor(float(impact_bonus) * 0.25)), 3, 18))
		"escape":
			health_delta = int(clamp(1 + level_twentieth, 1, 8))
		_:
			health_delta = 0

	if success_roll:
		if ability_type in ["attack", "control"] and target != actor:
			target.health = clamp(int(target.health) + health_delta, 0, 200)
		elif ability_type in ["heal", "defense", "escape"]:
			target.health = clamp(int(target.health) + health_delta, 0, 200)

		_set_ability_cooldown(actor, ability)
		gain_bending_progress(actor, element, 1, "using %s" % str(ability.get("name", "a bending skill")))
	else:
		var backlash_max: int = 6 + int(floor(float(impact_bonus) * 0.35))
		actor.health = clamp(int(actor.health) - randi_range(1, max(2, backlash_max)), 0, 200)

	var target_name: String = "%s %s" % [target.first_name, target.last_name]
	var result_text: String = str(ability.get("result_text", "You used %s." % str(ability.get("name", "bending"))))

	if result_text.find("%s") != -1:
		result_text = result_text % target_name

	if not success_roll:
		result_text = "You attempted %s, but your control slipped." % str(ability.get("name", "a bending skill"))

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": result_text
		})

	return {
		"success": success_roll,
		"text": result_text,
		"ability": ability,
		"target_id": int(target.id),
		"popup_title": str(ability.get("name", "Bending")),
		"popup_text": result_text,
		"popup_footer": "Tap anywhere to continue."
	}
func get_contextual_bending_popup_actions(actor: Person, target: Person) -> Array:
	var out: Array = []
	if actor == null or target == null:
		return out
	for ability in get_available_bending_abilities(actor):
		if not bool(ability.get("unlocked", false)):
			continue
		if not bool(ability.get("popup_action", false)):
			continue
		if bool(ability.get("on_cooldown", false)):
			continue
		var scope: String = str(ability.get("target_scope", "nation"))
		if scope == "self":
			continue
		out.append({
			"id": "Use Bending:%s" % str(ability.get("id", "")),
			"label": "Use %s" % str(ability.get("name", "Bending")),
			"element": str(ability.get("element", "")),
			"level": int(ability.get("level", 0))
		})
	return out





func mark_player_avatar_cycle_birth(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return {
			"success": false,
			"reason": "Actor is not the Avatar."
		}

	var birth_nation: String = _normalize_avatar_birth_nation(str(actor.bending_nation))
	if birth_nation == "":
		birth_nation = _normalize_avatar_birth_nation(str(context.get("forced_nation", "")))
	if birth_nation == "":
		birth_nation = _normalize_avatar_birth_nation(str(context.get("birth_country", "")))
	if birth_nation == "":
		birth_nation = _normalize_avatar_birth_nation(str(actor.birth_country))
	if birth_nation == "":
		birth_nation = _normalize_avatar_birth_nation(str(actor.home_country))
	if birth_nation == "":
		birth_nation = str(_avatar_cycle_nations() [0]) if not _avatar_cycle_nations().is_empty() else ""

	var cycle_nation: String = _normalize_avatar_cycle_nation(birth_nation)
	if cycle_nation == "":
		cycle_nation = birth_nation

	actor.bending_nation = birth_nation
	last_avatar_nation = cycle_nation

	var birth_city: String = str(context.get("birth_city", actor.birth_city)).strip_edges()
	var birth_country: String = str(context.get("birth_country", actor.birth_country)).strip_edges()
	if birth_city == "":
		birth_city = str(actor.home_city).strip_edges()
	if birth_country == "":
		birth_country = str(actor.home_country).strip_edges()

	var state: Dictionary = _bending_world_state()
	var avatar_births: Array = _safe_array(state.get("living_avatar_births", []))
	var packet: Dictionary = {
		"schema": "eralife.avatar_cycle_birth_packet",
		"version": 1,
		"person_id": int(actor.id),
		"name": _bending_person_label(actor),
		"nation": birth_nation,
		"cycle_nation": cycle_nation,
		"native_element": _element_from_nation(birth_nation),
		"birth_city": birth_city,
		"birth_country": birth_country,
		"birth_year": int(gs.year) if gs != null else 0,
		"birth_year_label": _format_avatar_world_year(int(gs.year)) if gs != null else "",
		"source": str(context.get("source", "avatar_cycle_birth")),
		"is_player": gs != null and actor == gs.player,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var replaced: bool = false
	for i in range(avatar_births.size()):
		var row: Dictionary = _safe_dictionary(avatar_births [i])
		if int(row.get("person_id", -1)) == int(actor.id):
			avatar_births [i] = packet.duplicate(true)
			replaced = true
			break

	if not replaced:
		avatar_births.append(packet.duplicate(true))

	while avatar_births.size() > 24:
		avatar_births.pop_front()

	state ["living_avatar_births"] = avatar_births
	state ["current_avatar_cycle"] = packet.duplicate(true)
	state ["last_avatar_nation"] = cycle_nation
	state ["last_avatar_birth_nation"] = birth_nation
	_commit_bending_world_state(state)

	if gs != null and gs.memory_engine != null and gs.memory_engine.has_method("remember"):
		gs.memory_engine.remember(
			int(actor.id),
			"My soul was chosen to become the next Avatar, Master of 4 Elements."
		)

	return {
		"success": true,
		"schema": "eralife.avatar_cycle_birth_report",
		"person_id": int(actor.id),
		"nation": birth_nation,
		"cycle_nation": cycle_nation,
		"birth_city": birth_city,
		"birth_country": birth_country,
		"packet": packet.duplicate(true)
	}
func _apply_avatar_birth(npc: Person, forced_nation:= "") -> void:
	if npc == null:
		return

	npc.bending_type = "avatar"

	var resolved_birth_nation: String = str(forced_nation).strip_edges()
	if resolved_birth_nation == "":
		resolved_birth_nation = str(NATIONS.pick_random())

	npc.bending_nation = _normalize_avatar_birth_nation(resolved_birth_nation)
	if npc.bending_nation == "":
		npc.bending_nation = _normalize_avatar_birth_nation(str(NATIONS.pick_random()))
	if npc.bending_nation == "":
		npc.bending_nation = "Air Nomads"

	npc.avatar_state_unlocked = false
	npc.avatar_state_used = false
	npc.bending_mastery = {}
	npc.bending_latent_potential = {}

	for e in _base_bending_elements():
		npc.bending_mastery [e] = 0
		npc.bending_latent_potential [e] = _roll_birth_latent_potential(npc, e, 2)

	var native_element: String = _element_from_nation(npc.bending_nation)
	if native_element in _base_bending_elements():
		npc.bending_latent_potential [native_element] = max(
			int(npc.bending_latent_potential.get(native_element, 0)),
			_roll_birth_latent_potential(npc, native_element, 3)
		)

	if gs != null and "avatar_influence_engine" in gs and gs.avatar_influence_engine != null:
		if gs.avatar_influence_engine.has_method("apply_avatar_birth_influence"):
			gs.avatar_influence_engine.apply_avatar_birth_influence(npc, {
				"source": "avatar_birth",
				"forced_nation": str(forced_nation),
				"birth_nation": str(npc.bending_nation),
				"cycle_nation": _normalize_avatar_cycle_nation(str(npc.bending_nation))
			})

	_seed_lineage_bending_combat_profile(npc, {
		"force": true,
		"source": "avatar_birth"
	})

	_mark_bending_level_migrated(npc)

	if gs.fame_engine != null:
		gs.fame_engine.give_fame(npc, 100)

	npc.fame_tier = "Legend"
	npc.fame_job = "Avatar"

	if npc.memories == null:
		npc.memories = []

	npc.memories.append("My soul was chosen to become the next Avatar, Master of 4 Elements.")

	if gs != null and gs.has_method("push_world_feed"):
		var birth_city: String = str(npc.birth_city).strip_edges()
		var birth_country: String = str(npc.birth_country).strip_edges()

		if birth_city == "":
			birth_city = str(npc.home_city).strip_edges()
		if birth_country == "":
			birth_country = str(npc.home_country).strip_edges()
		if birth_city == "":
			birth_city = "an unknown city"
		if birth_country == "":
			birth_country = str(npc.bending_nation).strip_edges()
		if birth_country == "":
			birth_country = "an unknown nation"

		gs.push_world_feed(
			" The Avatar has been reincarnated in %s, %s." % [
				birth_city,
				birth_country
			],
			{
				"npc_id": npc.id,
				"personally_relevant": npc == gs.player,
				"category": "bending",
				"event_name": "avatar_reincarnated",
				"source": "bending_engine",
				"birth_city": birth_city,
				"birth_country": birth_country,
				"birth_nation": str(npc.bending_nation),
				"cycle_nation": _normalize_avatar_cycle_nation(str(npc.bending_nation))
			}
		)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
			"npc_id": npc.id,
			"type": "avatar_birth"
		})
func _resolve_birth_parents(npc: Person) -> Array:
	var out: Array = []
	if npc == null or gs == null:
		return out

	for pid in npc.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		if parent != null:
			out.append(parent)

	return out


func _apply_parental_bending_inheritance(npc: Person) -> bool:
	var parents: Array = _resolve_birth_parents(npc)
	if parents.is_empty():
		return false

	var avatar_parents: Array = []
	var elemental_parents: Array = []
	for parent in parents:
		if parent == null:
			continue
		var parent_type: String = str(parent.bending_type).strip_edges().to_lower()
		if parent_type == "avatar":
			avatar_parents.append(parent)
		elif parent_type in _base_bending_elements():
			elemental_parents.append(parent)

	if not avatar_parents.is_empty():
		var avatar_parent: Person = avatar_parents [randi() % avatar_parents.size()]
		var native_element: String = _family_base_element(avatar_parent)

		if native_element != "none" and randi() % 100 < 8:
			_apply_avatar_birth(npc, avatar_parent.bending_nation)
			_apply_lineage_bending_child_profile(npc, parents, native_element, true)
			return true

		if native_element != "none" and randi() % 100 < 72:
			var native_mastery: int = max(1, int(avatar_parent.bending_mastery.get(native_element, 1)))
			force_bending_type(npc, native_element, native_mastery)
			_apply_lineage_bending_child_profile(npc, parents, native_element, false)
			return true

	if elemental_parents.size() == 1:
		var only_parent: Person = elemental_parents [0]
		if randi() % 100 < 72:
			var only_element: String = str(only_parent.bending_type).strip_edges().to_lower()
			var only_mastery: int = max(1, int(only_parent.bending_mastery.get(only_element, 1)))
			force_bending_type(npc, only_element, only_mastery)
			_apply_lineage_bending_child_profile(npc, parents, only_element, false)
			return true

	if elemental_parents.size() >= 2:
		var first_parent: Person = elemental_parents [0]
		var second_parent: Person = elemental_parents [1]
		var first_element: String = str(first_parent.bending_type).strip_edges().to_lower()
		var second_element: String = str(second_parent.bending_type).strip_edges().to_lower()
		var same_element: bool = first_element == second_element

		if same_element:
			if randi() % 100 < 88:
				var inherited_element: String = first_element
				var inherited_mastery: int = max(
					max(1, int(first_parent.bending_mastery.get(inherited_element, 1))),
					max(1, int(second_parent.bending_mastery.get(inherited_element, 1)))
				)
				force_bending_type(npc, inherited_element, inherited_mastery)
				_apply_lineage_bending_child_profile(npc, parents, inherited_element, false)
				return true
		else:
			if randi() % 100 < 78:
				var chosen_parent: Person = elemental_parents [randi() % elemental_parents.size()]
				var chosen_element: String = str(chosen_parent.bending_type).strip_edges().to_lower()
				var chosen_mastery: int = max(1, int(chosen_parent.bending_mastery.get(chosen_element, 1)))
				force_bending_type(npc, chosen_element, chosen_mastery)
				_apply_lineage_bending_child_profile(npc, parents, chosen_element, false)
				return true

	return false
func assign_bending(payload):
	if gs == null or not gs.is_feature_enabled("bending"):
		return

	var npc: Person = null

	if typeof(payload) == TYPE_DICTIONARY:
		var npc_id = payload.get("npc_id", -1)
		npc = gs.get_npc_by_id(npc_id)
	elif payload is Person:
		npc = payload

	if npc == null:
		return

	if _apply_parental_bending_inheritance(npc):
		if gs.capability_graph_engine != null:
			gs.capability_graph_engine.refresh_bending_capabilities(npc)
		return

	var birth_realm_name: String = str(npc.home_country).strip_edges()
	if birth_realm_name == "":
		birth_realm_name = str(npc.birth_country).strip_edges()

	if birth_realm_name == "" and gs.realm_engine != null and int(npc.realm_id) > 0 and gs.realm_engine.realms.has(int(npc.realm_id)):
		var realm_raw: Variant = gs.realm_engine.realms.get(int(npc.realm_id), {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		birth_realm_name = str(realm.get("name", "")).strip_edges()

	if birth_realm_name == "":
		for parent in _resolve_birth_parents(npc):
			if parent == null:
				continue
			var parent_realm_name: String = str(parent.home_country).strip_edges()
			if parent_realm_name == "":
				parent_realm_name = str(parent.birth_country).strip_edges()
			if parent_realm_name != "":
				birth_realm_name = parent_realm_name
				break

	var native_element: String = ""
	if gs.realm_engine != null and birth_realm_name != "" and gs.realm_engine.has_method("_realm_element_for_name"):
		native_element = str(gs.realm_engine._realm_element_for_name(birth_realm_name)).strip_edges().to_lower()

	if randi() % 2000 == 0:
		_apply_avatar_birth(npc, birth_realm_name if native_element in _base_bending_elements() else "")
		if gs.capability_graph_engine != null:
			gs.capability_graph_engine.refresh_bending_capabilities(npc)
		return

	var no_bending_threshold: int = 65
	if native_element in _base_bending_elements():
		no_bending_threshold = 55

	if randi() % 100 < no_bending_threshold:
		npc.bending_type = "none"
		npc.bending_nation = ""
		npc.avatar_state_unlocked = false
		npc.avatar_state_used = false
		ensure_bending_level_state(npc)
		for e in _base_bending_elements():
			npc.bending_mastery [e] = 0
		_mark_bending_level_migrated(npc)
		if gs.capability_graph_engine != null:
			gs.capability_graph_engine.refresh_bending_capabilities(npc)
		return

	var chosen_element: String = ""

	if native_element in _base_bending_elements():
		if randi() % 100 < 94:
			chosen_element = native_element
		else:
			var off_types:= []
			for element_name in _base_bending_elements():
				if element_name != native_element:
					off_types.append(element_name)
			chosen_element = str(off_types.pick_random())
	else:
		chosen_element = str(BASE_ELEMENTS.pick_random())

	npc.bending_type = chosen_element
	npc.bending_nation = _nation_for_element(chosen_element)

	if native_element != "" and chosen_element == native_element and birth_realm_name != "":
		npc.bending_nation = birth_realm_name

	ensure_bending_level_state(npc)
	for e in _base_bending_elements():
		npc.bending_mastery [e] = 0

	npc.bending_mastery [chosen_element] = _roll_spawn_bending_level(npc, chosen_element, 0)

	if int(npc.bending_latent_potential.get(chosen_element, 0)) <= 0:
		seed_birth_bending_potential(npc, chosen_element, 1)

	_seed_lineage_bending_combat_profile(npc, {
		"source": "random_birth_assignment"
	})

	_mark_bending_level_migrated(npc)

	if gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(npc)



func train_element(npc: Person, element: String) -> Dictionary:
	if npc == null:
		return {
			"success": false,
			"text": "No bender was selected.",
			"popup_title": "Bending Training",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	if gs != null and gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("bending"):
		return {
			"success": false,
			"text": "Bending is disabled in this reality.",
			"popup_title": "Bending Training",
			"popup_text": "Bending is disabled in this reality.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return {
			"success": false,
			"text": "No bending element was selected.",
			"popup_title": "Bending Training",
			"popup_text": "No bending element was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not can_train_bending_element(npc, clean_element):
		var avatar_locked: bool = clean_element == "avatar"
		return {
			"success": false,
			"text": "I cannot train %s bending yet." % clean_element,
			"popup_title": "Training Locked",
			"popup_text": "You cannot train %s bending yet.%s" % [
				clean_element.capitalize(),
				"\n\nAvatar bending unlocks only after mastering air, earth, fire, and water." if avatar_locked else "\n\nTry awakening it first."
			],
			"popup_footer": "Tap anywhere to continue."
		}

	ensure_bending_level_state(npc)

	var before_level: int = int(get_bending_level(npc, clean_element))
	var progress_gain: int = randi_range(2, 5)
	var report: Dictionary = gain_bending_progress(npc, clean_element, progress_gain, "focused_%s_training" % clean_element)
	var after_level: int = int(get_bending_level(npc, clean_element))
	var xp_gain: int = int(report.get("xp_gain", 0))
	var current_xp: int = int(report.get("current_xp", 0))
	var next_level_xp: int = int(report.get("next_level_xp", _bending_xp_required_for_next_level(after_level)))
	var skill_gain: int = int(report.get("skill_points_awarded", 0))

	return {
		"success": true,
		"text": "I trained my %s bending." % clean_element,
		"popup_title": "%s Bending Training" % clean_element.capitalize(),
		"popup_text": "You trained your %s bending.\n\nLevel: %d → %d\nXP gained: +%d\nProgress: %d/%d XP\nSkill Points gained: %d" % [
			clean_element.capitalize(),
			before_level,
			after_level,
			xp_gain,
			current_xp,
			next_level_xp,
			skill_gain
		],
		"popup_footer": "Tap anywhere to continue.",
		"element": clean_element,
		"before_level": before_level,
		"after_level": after_level,
		"xp_gain": xp_gain,
		"current_xp": current_xp,
		"next_level_xp": next_level_xp,
		"skill_points_gained": skill_gain,
		"progress_report": report,
	}
func attempt_awaken_element(npc: Person, element: String) -> Dictionary:
	if npc == null:
		return {
			"success": false,
			"text": "No bender was selected.",
			"popup_title": "Bending Awakening",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element not in BASE_ELEMENTS:
		return {
			"success": false,
			"text": "That element cannot be awakened.",
			"popup_title": "Bending Awakening",
			"popup_text": "That element cannot be awakened.",
			"popup_footer": "Tap anywhere to continue."
		}

	ensure_bending_level_state(npc)

	if int(get_bending_level(npc, clean_element)) > 0:
		return {
			"success": true,
			"text": "I had already awakened %s bending." % clean_element,
			"popup_title": "Already Awakened",
			"popup_text": "Your %s bending is already awake.\n\nTrain it instead." % clean_element.capitalize(),
			"popup_footer": "Tap anywhere to continue."
		}

	var actor_type: String = str(npc.bending_type).strip_edges().to_lower()
	var is_avatar: bool = actor_type == "avatar" or bool(npc.avatar_state_unlocked)
	var potential_state: Dictionary = {}
	if typeof(npc.bending_latent_potential) == TYPE_DICTIONARY:
		potential_state = npc.bending_latent_potential

	var potential: float = float(potential_state.get(clean_element, 15.0))
	var chance: float = 6.0 + (potential * 0.35) + (float(npc.smarts) * 0.08) + (float(npc.imagination) * 0.05)

	if is_avatar:
		chance += 16.0
	elif actor_type == "none":
		chance += 4.0
	elif actor_type != clean_element:
		chance -= 12.0

	chance = clamp(chance, 3.0, 72.0)
	var roll: float = randf_range(0.0, 100.0)
	var success: bool = roll <= chance

	if success:
		if actor_type == "none":
			npc.bending_type = clean_element
		npc.bending_mastery [clean_element] = max(1, int(npc.bending_mastery.get(clean_element, 0)))
		gain_bending_progress(npc, clean_element, randi_range(1, 4), "solo_awakening_%s" % clean_element)
		award_bending_skill_points(npc, 1, "awakened_%s_bending" % clean_element)

		if gs != null and gs.has_method("push_world_feed"):
			gs.push_world_feed("%s awakened %s bending through sheer will." % [
				_bending_person_label(npc),
				clean_element.capitalize()
			], {
				"category": "bending",
				"event_name": "bending_awakening",
				"source": "bending_engine",
				"personally_relevant": npc == gs.player
			})

		return {
			"success": true,
			"text": "I awakened %s bending on my own." % clean_element,
			"popup_title": "%s Awakening" % clean_element.capitalize(),
			"popup_text": "You reached inward and something answered.\n\n%s bending awakened." % clean_element.capitalize(),
			"popup_footer": "Tap anywhere to continue.",
			"element": clean_element,
			"chance": chance,
			"roll": roll,
		}

	potential_state [clean_element] = clamp(potential + randf_range(1.0, 4.0), 0.0, 100.0)
	npc.bending_latent_potential = potential_state
	npc.mental_health = clamp(int(npc.mental_health) - 1, 0, 100)

	return {
		"success": false,
		"text": "I tried to awaken %s bending, but it did not answer yet." % clean_element,
		"popup_title": "%s Did Not Awaken" % clean_element.capitalize(),
		"popup_text": "You tried to awaken %s bending on your own.\n\nNothing fully opened yet, but the attempt stirred your latent potential." % clean_element.capitalize(),
		"popup_footer": "Tap anywhere to continue.",
		"element": clean_element,
		"chance": chance,
		"roll": roll,
	}
func _bending_person_label(person: Person) -> String:
	if person == null:
		return "Unknown bender"
	return ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
func train_with_teacher(teacher: Person, student: Person, element: String) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("bending"):
		return { "success": false, "text": "Bending is disabled in this reality mode."}
	if student == null:
		return { "success": false, "text": "No student selected."}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return { "success": false, "text": "No bending element selected."}

	ensure_bending_level_state(student)

	if not student.bending_mastery.has(clean_element):
		return { "success": false, "text": "%s cannot train %s bending." % [student.first_name, clean_element]}

	var student_level: int = get_bending_level(student, clean_element)
	var teacher_level: int = 0

	if teacher != null:
		ensure_bending_level_state(teacher)
		if str(teacher.bending_type).strip_edges().to_lower() == "avatar":
			teacher_level = max(teacher_level, get_bending_level(teacher, clean_element))
		elif str(teacher.bending_type).strip_edges().to_lower() == clean_element:
			teacher_level = get_bending_level(teacher, clean_element)

	if teacher != null and teacher_level <= student_level + 4:
		return {
			"success": false,
			"text": "%s could not teach much because their %s bending is not far enough ahead." % [
				teacher.first_name,
				clean_element
			]
		}

	var raw_gain: int = randi_range(3, 7)

	if teacher_level >= 75:
		raw_gain += 2
	elif teacher_level >= 55:
		raw_gain += 1

	var personality: Dictionary = _bending_element_personality_profile(clean_element)
	var result: Dictionary = gain_bending_progress(student, clean_element, raw_gain, "guided training")
	result ["teacher_level"] = teacher_level
	result ["training_style"] = "guided"
	result ["element_personality_name"] = str(personality.get("name", ""))

	var awakening_events: Array = result.get("awakening_events", [])
	if awakening_events.is_empty():
		result ["text"] = "%s practiced %s bending with guidance and reached level %d." % [
			student.first_name,
			clean_element,
			int(result.get("level", student_level))
		]

	var pressure_text: String = str(result.get("avatar_training_pressure", {}).get("text", "")).strip_edges()
	if pressure_text != "" and str(result.get("text", "")).find(pressure_text) == -1:
		result ["text"] = str(result.get("text", "")) + "\n" + pressure_text

	return result





func attempt_metalbending(npc: Person):
	if npc == null:
		return
	ensure_bending_level_state(npc)

	if get_bending_level(npc, "earth") < 78:
		return

	if randi() % 4 == 0:
		gain_bending_progress(npc, "earth", 2, "discovering metalbending")
		gs.push_world_feed(
			"🪨 %s %s discovered Metalbending." %
			[npc.first_name, npc.last_name],
			{
				"npc_id": npc.id,
				"personally_relevant": false,
				"category": "bending",
				"event_name": "metalbending_discovered",
				"source": "bending_engine"
			}
		)





func _check_avatar_state(npc):
	if npc == null:
		return
	if npc.bending_type != "avatar":
		return

	ensure_bending_level_state(npc)

	for e in ["air", "earth", "fire", "water"]:
		if get_bending_level(npc, e) < BENDING_MASTERY_THRESHOLD:
			return

	npc.avatar_state_unlocked = true


func activate_avatar_state(npc):
	if npc == null:
		return
	if not npc.avatar_state_unlocked:
		return
	if npc.avatar_state_used:
		return

	npc.avatar_state_used = true

	var multipliers: Dictionary = _ensure_avatar_state_skill_multipliers(npc)
	npc.health += 100
	npc.smarts += 50
	npc.looks += 25

	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("apply_avatar_state_willpower"):
		gs.willpower_engine.apply_avatar_state_willpower(npc, {
			"source": "avatar_state_activation",
			"scope": "bending_avatar_state"
		})

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"             %s %s has entered the AVATAR STATE." % [npc.first_name, npc.last_name],
			{
				"npc_id": npc.id,
				"personally_relevant": npc == gs.player,
				"category": "bending",
				"event_name": "avatar_state",
				"source": "bending_engine",
				"avatar_state_skill_multipliers": multipliers.duplicate(true)
			}
		)
func _ensure_avatar_state_skill_multipliers(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var profile: Dictionary = ensure_bending_combat_profile(actor)
	var existing: Dictionary = profile.get("avatar_state_skill_multipliers", {})
	if typeof(existing) == TYPE_DICTIONARY and not existing.is_empty():
		return existing.duplicate(true)

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(("%d:%s:%d:avatar_state_skill_multiplier" % [
		int(actor.id),
		str(actor.first_name),
		int(actor.age)
	]).hash()))

	var multipliers: Dictionary = {}
	for stat_name in ["accuracy", "power", "guard", "counter", "evasion", "focus"]:
		multipliers [stat_name] = snappedf(rng.randf_range(1.5, 2.5), 0.01)

	profile ["avatar_state_skill_multipliers"] = multipliers.duplicate(true)
	actor.bending_combat_profile = profile.duplicate(true)
	return multipliers.duplicate(true)


func _avatar_state_skill_multiplier_for_stat(actor: Person, stat_name: String) -> float:
	if actor == null:
		return 1.0

	var is_avatar: bool = str(actor.bending_type).strip_edges().to_lower() == "avatar"
	if not is_avatar:
		return 1.0
	if not bool(actor.avatar_state_used):
		return 1.0

	var multipliers: Dictionary = _ensure_avatar_state_skill_multipliers(actor)
	var clean_stat: String = str(stat_name).strip_edges().to_lower()
	return clamp(float(multipliers.get(clean_stat, 1.0)), 1.0, 2.5)
func on_avatar_death(payload):
	if gs == null or not gs.is_feature_enabled("bending"):
		return

	var npc_id = int(payload.get("npc_id", -1))
	if npc_id == -1:
		return

	var npc = gs.get_npc_by_id(npc_id)

	if npc != null:
		if npc.bending_type != "avatar":
			return

		_remember_previous_avatar_from_person(npc)
		last_avatar_nation = npc.bending_nation
		_reincarnate_avatar()
		return

	var facts = gs.get_npc_facts_by_id(npc_id)

	if facts == {}:
		return

	if str(facts.get("bending_type", "none")) != "avatar":
		return

	_remember_previous_avatar_from_facts(facts)
	last_avatar_nation = str(facts.get("bending_nation", ""))
	_reincarnate_avatar()
func _reincarnate_avatar():
	if gs == null or gs.npc_factory == null:
		return

	var next_nation = _next_avatar_nation(last_avatar_nation)
	var baby = gs.npc_factory.create_random_npc()

	if baby == null:
		return

	baby.age = 0
	_apply_avatar_birth(baby, next_nation)

	_register_bending_world_spawn(baby)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"🌀 The Avatar has been reborn in the %s." % next_nation,
			{
				"npc_id": baby.id,
				"personally_relevant": false,
				"category": "bending",
				"event_name": "avatar_reborn",
				"source": "bending_engine"
			}
		)

	if gs.memory_engine != null and gs.memory_engine.has_method("remember"):
		gs.memory_engine.remember(
			baby.id,
			"I feel echoes of past lives within me."
		)
func _remember_previous_avatar_from_person(npc: Person) -> void:
	if npc == null or gs == null:
		return

	var death_year: int = int(gs.year)
	var birth_year: int = death_year - int(npc.age)

	var record: Dictionary = {
		"schema": "eralife.previous_avatar_record",
		"version": 2,
		"person_id": int(npc.id),
		"name": _bending_person_label(npc),
		"nation": str(npc.bending_nation),
		"native_element": _element_from_nation(str(npc.bending_nation)),
		"birth_year": birth_year,
		"birth_year_label": _format_avatar_world_year(birth_year),
		"death_year": death_year,
		"death_year_label": _format_avatar_world_year(death_year),
		"lifespan": int(npc.age),
		"cause_of_death": str(npc.cause_of_death),
		"seeded": false
	}
	_store_previous_avatar_record(record)


func _remember_previous_avatar_from_facts(facts: Dictionary) -> void:
	if gs == null or facts.is_empty():
		return

	var death_year: int = int(gs.year)
	var age_value: int = int(facts.get("age", 0))
	var first_name: String = str(facts.get("first_name", facts.get("name", "Unknown")))
	var last_name: String = str(facts.get("last_name", "Avatar"))
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	var nation: String = str(facts.get("bending_nation", ""))

	var record: Dictionary = {
		"schema": "eralife.previous_avatar_record",
		"version": 2,
		"person_id": int(facts.get("id", -1)),
		"name": full_name,
		"nation": nation,
		"native_element": _element_from_nation(nation),
		"birth_year": death_year - age_value,
		"birth_year_label": _format_avatar_world_year(death_year - age_value),
		"death_year": death_year,
		"death_year_label": _format_avatar_world_year(death_year),
		"lifespan": age_value,
		"cause_of_death": str(facts.get("cause_of_death", "")),
		"seeded": false
	}

	_store_previous_avatar_record(record)


func _store_previous_avatar_record(record: Dictionary) -> void:
	if gs == null or record.is_empty():
		return

	var state: Dictionary = _bending_world_state()
	var previous: Array = state.get("previous_avatars", [])

	var record_id: int = int(record.get("person_id", -1))
	if record_id > 0:
		for raw_existing in previous:
			if typeof(raw_existing) != TYPE_DICTIONARY:
				continue
			var existing: Dictionary = raw_existing
			if int(existing.get("person_id", -999)) == record_id:
				return

	previous.append(record)
	while previous.size() > 12:
		previous.pop_front()

	state ["previous_avatars"] = previous
	gs.scenario_state ["bending_world_championship"] = state
func _next_avatar_nation(current):

	var cycle: Array = _avatar_cycle_nations()
	if cycle.is_empty():
		return ""
	var clean_current: String = _normalize_avatar_cycle_nation(str(current))
	var idx: int = cycle.find(clean_current)
	if idx == -1:
		return str(cycle [0])
	idx += 1
	if idx >= cycle.size():
		idx = 0
	return str(cycle [idx])
func get_bending_school_flavor(element: String) -> String:
	match element:
		"air":
			return "The Air Temples remain open to airbenders across every era."
		"water":
			return "Waterbending students train in patience, healing, and flow."
		"earth":
			return "Earthbending students learn strength, stance, and eventually metal."
		"fire":
			return "Firebending students learn discipline, breath, and controlled power."
		"avatar":
			return "The Avatar's path crosses every element."
	return ""




func teach_bending(master: Person, student: Person, element: String) -> Dictionary:
	if master == null or student == null:
		return { "success": false, "text": "Teaching needs a teacher and a student."}

	ensure_bending_level_state(master)
	ensure_bending_level_state(student)

	if get_bending_level(master, element) < BENDING_MASTERY_THRESHOLD and str(master.bending_type) != "avatar":
		return { "success": false, "text": "You need level %d %s bending before you can teach it." % [BENDING_MASTERY_THRESHOLD, element]}

	if student.bending_type == "none":
		return { "success": false, "text": "They cannot bend."}

	if student.bending_type != element and master.bending_type != "avatar":
		if randi() % 3 != 0:
			return { "success": false, "text": "Training was difficult. Progress was slow."}

	var result: Dictionary = train_with_teacher(master, student, element)

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(master, {
			"type": "text",
			"text": "I helped %s improve their %s bending." % [student.first_name, element]
		})

	return result







func _active_elements_for_target(target: Person) -> Array:
	var out: Array = []
	if target == null:
		return out

	for e in ["air", "earth", "fire", "water"]:
		if int(target.bending_mastery.get(e, 0)) > 0:
			out.append(e)

	return out


func _refresh_bending_identity_from_mastery(target: Person) -> void:
	var active:= _active_elements_for_target(target)

	if active.is_empty():
		target.bending_type = "none"
		target.bending_nation = ""
		return

	if target.bending_type == "avatar":
		return

	if str(target.bending_type) == "none" or int(target.bending_mastery.get(target.bending_type, 0)) <= 0:
		target.bending_type = str(active [0])
		target.bending_nation = str(active [0])


func avatar_grant_element(avatar: Person, target: Person, element: String):
	if avatar.bending_type != "avatar":
		return { "text": "Only the Avatar can grant bending."}
	if avatar == gs.player and avatar.age < 12:
		return { "text": "You must be at least 12 to grant bending."}
	if int(target.bending_mastery.get(element, 0)) > 0:
		return { "text": "They already possess this element."}

	var avatar_fame_state: Dictionary = {}
	var target_fame_state: Dictionary = {}
	if gs.fame_engine != null:
		avatar_fame_state = gs.fame_engine.snapshot_public_fame_state(avatar)
		target_fame_state = gs.fame_engine.snapshot_public_fame_state(target)

	target.bending_mastery [element] = 1
	_refresh_bending_identity_from_mastery(target)

	if gs.fame_engine != null:
		gs.fame_engine.restore_public_fame_state(avatar, avatar_fame_state)
		gs.fame_engine.restore_public_fame_state(target, target_fame_state)

	gs.push_world_feed(
		"%s granted %s the power of %s bending." %
		[avatar.first_name, target.first_name, element],
		{
			"npc_id": avatar.id,
			"personally_relevant": avatar == gs.player or target == gs.player,
			"category": "bending",
			"event_name": "avatar_granted_bending",
			"source": "bending_engine"
		}
	)
	return { "text": "Element granted."}


func avatar_remove_element(avatar: Person, target: Person, element: String):
	if avatar.bending_type != "avatar":
		return { "text": "Only the Avatar can remove bending."}
	if avatar == gs.player and avatar.age < 12:
		return { "text": "You must be at least 12 to remove bending."}
	if int(target.bending_mastery.get(element, 0)) <= 0:
		return { "text": "They do not currently possess %s bending." % element}

	var avatar_fame_state: Dictionary = {}
	var target_fame_state: Dictionary = {}
	if gs.fame_engine != null:
		avatar_fame_state = gs.fame_engine.snapshot_public_fame_state(avatar)
		target_fame_state = gs.fame_engine.snapshot_public_fame_state(target)

	target.bending_mastery [element] = 0
	_refresh_bending_identity_from_mastery(target)

	if gs.fame_engine != null:
		gs.fame_engine.restore_public_fame_state(avatar, avatar_fame_state)
		gs.fame_engine.restore_public_fame_state(target, target_fame_state)

	gs.push_world_feed(
		"%s removed %s bending from %s." %
		[avatar.first_name, element, target.first_name],
		{
			"npc_id": avatar.id,
			"personally_relevant": avatar == gs.player or target == gs.player,
			"category": "bending",
			"event_name": "avatar_removed_bending",
			"source": "bending_engine"
		}
	)
	return { "text": "Bending removed."}


func avatar_remove_bending(avatar: Person, target: Person):
	if avatar.bending_type != "avatar":
		return { "text": "Only the Avatar can remove bending."}
	if avatar == gs.player and avatar.age < 12:
		return { "text": "You must be at least 12 to remove bending."}

	var avatar_fame_state: Dictionary = {}
	var target_fame_state: Dictionary = {}
	if gs.fame_engine != null:
		avatar_fame_state = gs.fame_engine.snapshot_public_fame_state(avatar)
		target_fame_state = gs.fame_engine.snapshot_public_fame_state(target)

	for e in _active_elements_for_target(target):
		target.bending_mastery [e] = 0
	_refresh_bending_identity_from_mastery(target)

	if gs.fame_engine != null:
		gs.fame_engine.restore_public_fame_state(avatar, avatar_fame_state)
		gs.fame_engine.restore_public_fame_state(target, target_fame_state)

	gs.push_world_feed(
		"%s removed the bending of %s." %
		[avatar.first_name, target.first_name],
		{
			"npc_id": avatar.id,
			"personally_relevant": avatar == gs.player or target == gs.player,
			"category": "bending",
			"event_name": "avatar_removed_bending",
			"source": "bending_engine"
		}
	)
	return { "text": "Bending removed."}





func bending_duel(attacker: Person, defender: Person) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("bending"):
		return { "success": false, "text": "Bending is disabled in this reality mode."}
	if attacker == null or defender == null:
		return { "success": false, "text": "A bending duel needs two people."}
	if attacker.bending_type == "none":
		return { "success": false, "text": "You cannot bend."}

	if attacker == gs.player and int(attacker.age) < 13:
		return {
			"success": false,
			"popup_title": "Bending Duel Locked",
			"popup_text": "You are too young to seek a bending duel.\n\nDueling unlocks at age 13.",
			"popup_footer": "Tap anywhere to continue.",
			"text": "Bending duels unlock at age 13."
		}

	ensure_bending_level_state(attacker)
	ensure_bending_level_state(defender)

	var attacker_element: String = str(attacker.bending_type)
	if attacker_element == "avatar":
		var best_element: String = "air"
		var best_level: int = -1
		for element in _base_bending_elements():
			var level: int = get_bending_level(attacker, element)
			if level > best_level:
				best_level = level
				best_element = element
		attacker_element = best_element

	var atk_power = _bending_power(attacker)
	var def_power = _bending_power(defender)

	atk_power += randi_range(0, 18)
	def_power += randi_range(0, 18)

	if atk_power > def_power:
		defender.health = clamp(int(defender.health) - randi_range(6, 24), 0, 200)
		var gain_result: Dictionary = gain_bending_progress(attacker, attacker_element, randi_range(2, 5), "winning a bending duel")
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(attacker, {
				"type": "text",
				"text": "I defeated %s in a bending duel." % defender.first_name
			})
		return {
			"success": true,
			"text": "You won the bending duel. Your %s bending is now level %d." % [
				attacker_element,
				int(gain_result.get("level", get_bending_level(attacker, attacker_element)))
			],
			"popup_title": "Bending Duel",
			"popup_text": "You defeated %s %s in a bending duel." % [defender.first_name, defender.last_name],
			"popup_footer": "Tap anywhere to continue."
		}

	attacker.health = clamp(int(attacker.health) - randi_range(6, 24), 0, 200)
	if randi() % 100 < 35:
		gain_bending_progress(attacker, attacker_element, 1, "surviving a bending duel")
	return {
		"success": false,
		"text": "You lost the bending duel.",
		"popup_title": "Bending Duel",
		"popup_text": "%s %s defeated you in a bending duel." % [defender.first_name, defender.last_name],
		"popup_footer": "Tap anywhere to continue."
	}







func _bending_power(npc: Person) -> int:
	if npc == null:
		return 0

	ensure_bending_level_state(npc)

	var total: int = 0
	for e in _base_bending_elements():
		total += int(get_bending_level(npc, e))

	if npc.bending_type == "avatar":
		total += 30

	total += int(npc.health / 10.0)
	total += int(npc.smarts / 12.0)

	return total



func _element_from_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges()
	var key: String = clean_nation.to_lower()

	if key == "":
		return "none"

	match clean_nation:
		"Air Nomads", "Air Temples", "Air Nation":
			return "air"
		"Earth Kingdom", "Earth Nation":
			return "earth"
		"Fire Nation":
			return "fire"
		"Water Tribe", "Northern Water Tribe", "Southern Water Tribe", "Water Nation":
			return "water"

	if key.find("air") != -1:
		return "air"
	if key.find("earth") != -1:
		return "earth"
	if key.find("fire") != -1:
		return "fire"
	if key.find("water") != -1:
		return "water"

	return "none"
func _family_base_nation(source: Person) -> String:
	if source == null:
		return ""

	for raw_candidate in [source.bending_nation, source.birth_country, source.home_country]:
		var candidate: String = _normalize_avatar_birth_nation(str(raw_candidate))
		if candidate != "":
			return candidate

	if source.bending_type in ["air", "earth", "fire", "water"]:
		return _nation_for_element(source.bending_type)

	return ""

func _family_base_element(source: Person) -> String:

	if source.bending_type in ["air", "earth", "fire", "water"]:
		return source.bending_type



	if source.bending_type == "avatar":
		return _element_from_nation(source.bending_nation)

	return "none"


func _nation_for_element(element: String) -> String:
	match element:
		"air":
			return "Air Nomads"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"
		"water":
			return "Water Tribe"
	return ""
func _avatar_cycle_nations() -> Array:
	var out: Array = []
	if typeof(avatar_cycle) == TYPE_ARRAY:
		for raw_nation in avatar_cycle:
			var nation: String = _normalize_avatar_cycle_nation(str(raw_nation))
			if nation != "" and nation not in out:
				out.append(nation)

	if out.is_empty():
		out = [
			"Air Nomads",
			"Water Tribe",
			"Earth Kingdom",
			"Fire Nation"
		]

	return out
func _normalize_avatar_birth_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges()
	if clean_nation == "":
		return ""

	var key: String = clean_nation.to_lower()

	match clean_nation:
		"Northern Water Tribe":
			return "Northern Water Tribe"
		"Southern Water Tribe":
			return "Southern Water Tribe"
		"Water Tribe", "Water Nation":
			return "Water Tribe"
		"Fire Nation":
			return "Fire Nation"
		"Earth Kingdom", "Earth Nation":
			return "Earth Kingdom"
		"Air Nomads", "Air Temples", "Air Nation", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple":
			return "Air Nomads"

	if key.find("northern") != -1 and key.find("water") != -1:
		return "Northern Water Tribe"
	if key.find("southern") != -1 and key.find("water") != -1:
		return "Southern Water Tribe"
	if key.find("water") != -1:
		return "Water Tribe"
	if key.find("fire") != -1:
		return "Fire Nation"
	if key.find("earth") != -1:
		return "Earth Kingdom"
	if key.find("air") != -1:
		return "Air Nomads"

	return ""

func _normalize_avatar_cycle_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges()
	var element: String = _element_from_nation(clean_nation)

	match element:
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"

	return ""
func ensure_realm_leader_bending_state(ruler: Person, realm: Dictionary) -> void:
	if gs == null or not gs.is_feature_enabled("bending"):
		return
	if ruler == null or not ruler.alive:
		return
	if typeof(realm) != TYPE_DICTIONARY or realm.is_empty():
		return

	var realm_name: String = str(realm.get("name", ruler.bending_nation)).strip_edges()
	var native_element: String = _element_from_nation(realm_name)

	if native_element == "none" and gs.realm_engine != null and gs.realm_engine.has_method("_realm_element_for_name"):
		native_element = str(gs.realm_engine._realm_element_for_name(realm_name)).strip_edges().to_lower()

	if native_element == "none" or native_element == "":
		for native_key in ["native_element", "element", "bending_element", "realm_element"]:
			native_element = str(realm.get(native_key, "")).strip_edges().to_lower()
			if native_element in _base_bending_elements():
				break

	if native_element not in _base_bending_elements():
		return

	ensure_bending_level_state(ruler)
	ensure_bending_potential_state(ruler)

	var current_type: String = str(ruler.bending_type).strip_edges().to_lower()
	if current_type != "avatar":
		ruler.bending_type = native_element
		for element in _base_bending_elements():
			if element != native_element:
				ruler.bending_mastery [element] = 0

	ruler.bending_nation = realm_name
	ruler.avatar_state_used = false

	if int(ruler.realm_id) <= 0:
		for realm_id_key in ["realm_id", "numeric_id", "id"]:
			var raw_realm_id: Variant = realm.get(realm_id_key, -1)
			var realm_id_text: String = str(raw_realm_id).strip_edges()
			if realm_id_text.is_valid_int() and int(realm_id_text) > 0:
				ruler.realm_id = int(realm_id_text)
				break

	if str(ruler.home_country).strip_edges() == "":
		ruler.home_country = realm_name
	if str(ruler.birth_country).strip_edges() == "":
		ruler.birth_country = realm_name

	var current_level: int = get_bending_level(ruler, native_element)
	if current_level < 85:
		ruler.bending_mastery [native_element] = randi_range(85, 95)
	else:
		ruler.bending_mastery [native_element] = clamp(current_level, 85, BENDING_LEVEL_MAX)

	var current_potential: int = int(ruler.bending_latent_potential.get(native_element, 0))
	if current_potential < 90:
		ruler.bending_latent_potential [native_element] = randi_range(90, 100)

	_mark_bending_level_migrated(ruler)

	if gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(ruler)

func force_bending_type(npc: Person, element: String, mastery:= 18):
	if npc == null:
		return

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "avatar":
		return

	ensure_bending_level_state(npc)
	ensure_bending_potential_state(npc)

	npc.bending_type = "none"
	npc.bending_nation = ""
	npc.avatar_state_unlocked = false
	npc.avatar_state_used = false

	for e in _base_bending_elements():
		npc.bending_mastery [e] = 0

	if clean_element == "none" or clean_element == "":
		_mark_bending_level_migrated(npc)
		if gs.capability_graph_engine != null:
			gs.capability_graph_engine.refresh_bending_capabilities(npc)
		return

	if clean_element not in _base_bending_elements():
		return

	npc.bending_type = clean_element
	npc.bending_nation = _nation_for_element(clean_element)
	npc.bending_mastery [clean_element] = _resolve_forced_bending_level(npc, clean_element, mastery)

	if int(npc.bending_latent_potential.get(clean_element, 0)) <= 0:
		var resolved_level: int = int(npc.bending_mastery.get(clean_element, 0))
		npc.bending_latent_potential [clean_element] = clamp(
			max(
				_roll_birth_latent_potential(npc, clean_element, 1),
				resolved_level + randi_range(10, 26)
			),
			0,
			BENDING_LATENT_POTENTIAL_MAX
		)

	_seed_lineage_bending_combat_profile(npc, {
		"source": "force_bending_type"
	})

	_mark_bending_level_migrated(npc)

	if gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(npc)


func sync_family_bending(player: Person, relatives: Array):
	var family_element = _family_base_element(player)
	if family_element == "none":
		return

	var family_nation: String = _family_base_nation(player)

	for relative in relatives:
		if relative == null:
			continue
		if relative == player:
			continue
		if relative.bending_type == "avatar":
			continue

		var synced_level: int = _roll_spawn_bending_level(relative, family_element, 1)
		force_bending_type(relative, family_element, synced_level)

		if family_nation != "":
			relative.bending_nation = family_nation
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	if gs == null or not gs.is_feature_enabled("bending"):
		return out

	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out
	ensure_bending_level_state(player)
	var has_bending:= false
	if str(player.bending_type) != "" and str(player.bending_type) != "none":
		has_bending = true
	else:
		for element in ["air", "water", "earth", "fire"]:
			if int(player.bending_mastery.get(element, 0)) > 0:
				has_bending = true
				break

	if not has_bending:
		return out

	var style_label:= "my bending"
	if str(player.bending_type) == "avatar":
		style_label = "my Avatar training"
	elif str(player.bending_type) != "" and str(player.bending_type) != "none":
		style_label = "my %s bending" % str(player.bending_type)

	out.append({
		"id": "bending_discipline_%d" % int(context.get("year", 0)),
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.05
		},
		"tone": "discipline",
		"rarity": 0.58,
		"cooldown_key": "bending:discipline",
		"cooldown_years": 2,
		"priority": 10,
		"min_age": 6,
		"max_age": 130,
		"prompt": "Something in %s feels unsteady this year. What do I focus on?" % style_label,
		"followup_hooks": ["bending.discipline"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "train_quietly",
				"label": "Train quietly and sharpen control.",
				"journal_line": "I chose to train quietly and sharpen my control.",
				"journal_text": "I chose to train quietly and sharpen my control.",
				"followup_hooks": ["bending.discipline.control"],
				"bias_payloads": {
					"health_bias": {
						"stress_delta": -1.0
					},
					"desire_bias": {
						"self_reflection_weight": 8.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "test_publicly",
				"label": "Push myself in public and test my edge.",
				"journal_line": "I chose to test my bending in a more public way.",
				"journal_text": "I chose to test my bending in a more public way.",
				"followup_hooks": ["bending.discipline.public"],
				"bias_payloads": {
					"reputation_bias": {
						"public_attention": 6.0
					},
					"school_pressure": {
						"peer_tension": 3.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})
	return out