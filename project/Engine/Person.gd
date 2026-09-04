extends Resource
class_name Person

const PERSON_CONTRACT_SCHEMA:= "eralife.person_contract"
const PERSON_CONTRACT_SLICE_SCHEMA:= "eralife.person_contract_slice"
const PERSON_CONTRACT_VERSION:= 1
const PERSON_POWER_PROFILE_SCHEMA:= "eralife.person_power_profiles"
const PERSON_WORLD_LAW_RESIDUE_SCHEMA:= "eralife.person_world_law_residue"


var id: int
var name: String
var first_name: String
var last_name: String
var gender: String
var age: int = 0
# Durable anchor for biological aging. Metas do NOT survive _deserialize_npc()
# (dormancy reactivation) or a save/load, so the meta this used to rely on came
# back absent and aging silently fell back to +1 per pass, losing every year an
# NPC was not reached. A property round-trips automatically: _deserialize_npc()
# copies any serialized key matching a property name.
var last_biology_year: int = -1
# Durable birth anchor. Unlike last_biology_year this is written ONCE and never
# updated, so no aging site can mis-stamp it -- age becomes
# target_year - birth_year rather than an accumulator that depends on every write
# site agreeing and on the bounded drain reaching this NPC every year.
# -1 means "not yet anchored"; the aging sites backfill it as
# target_year - age on first contact.
var birth_year: int = -1
var children: Array = []
var maiden_last_name: String = ""

var health: float = 100
var mental_health: float = 100
var hunger: float = -1.0
var last_minor_illness_age: int = -999
var smarts: int = 50
var looks: int = 50
var imagination: int = 0
var fertility: float = 50

var genetics_contract: Dictionary = {}
var body_type_contract: Dictionary = {}
var growth_curve_contract: Dictionary = {}
var height_contract: Dictionary = {}
var weight_contract: Dictionary = {}
var body_contract: Dictionary = {}

var terabithia_state: Dictionary = {}

var job: String = ""
var income: float = 0
var satisfaction: float = 50
var bank_balance = 0
var expenses = 0
var job_performance: int = 50
var job_experience: int = 0
var unemployed_years: int = 0
var work_stress: float = 0.0
var hours_worked_last_year: int = 0
var current_workplace_id: String = ""
var coworkers: Array = []




var career_profile: Dictionary = {
	"schema": "eralife.person_career_profile",
	"version": 1,
	"current_assignment_id": "",
	"application_ids": [],
	"career_history": [],
	"professional_reputation": {
		"reliability": 50,
		"leadership": 50,
		"kindness": 50,
		"innovation": 50,
		"efficiency": 50,
		"corruption": 0,
		"bravery": 50,
		"carelessness": 0
	},
	"professional_reputation_score": 50,
	"legacy": {
		"achievements": 0,
		"students_mentored": 0,
		"patents_created": 0,
		"books_written": 0,
		"buildings_created": 0,
		"battles_won": 0,
		"patients_saved": 0,
		"cases_won": 0,
		"discoveries": 0,
		"world_traces": 0
	}
}

var traits: Array = []
var memories: Array = []
var consciousness_contract: Dictionary = {}
var consciousness_state: Dictionary = {}
var consciousness_memory_index: Array = []
var soul_seed_contract: Dictionary = {}
var soul_seed_state: Dictionary = {}
var friends: Array = []
var partner: Person = null
var parents: Array = []
var respect: int = 50
var respect_profile: Dictionary = {
	"schema": "eralife.person_respect_profile",
	"version": 1,
	"general": 50,
	"bending": 50,
	"family": 50,
	"public": 50,
	"fear": 0,
	"honor": 50,
	"last_delta": 0,
	"last_reason": ""
}


var fate_arc: String = ""
var alive: bool = true
var birth_city: String = ""
var birth_state: String = ""
var birth_country: String = ""
var birthday: Dictionary = { "month": 1, "day": 1}
var zodiac: String = ""
var affection: Dictionary = {}
var cause_of_death: String = ""
var death_year: int = -999999
var dynasty_origin: String = ""
var dynasty_prestige: int = 0
var marital_status: String = "Single"
var ex_partners: Array = []
var home_city: String = ""
var home_state: String = ""
var home_country: String = ""


var current_context: String = "free"
var incarceration_state: Dictionary = {}
var incarceration_context: Dictionary = {}
var incarceration_stats: Dictionary = {}


var settlement_id: String = ""
var district_id: String = ""
var locality_id: String = ""
var origin_settlement_id: String = ""
var origin_district_id: String = ""
var origin_locality_id: String = ""
var birthplace_settlement_id: String = ""


var migration_history: Array = []
var diaspora_tags: Array = []
var identity_residue: Dictionary = {
	"birthplace_pride": 0.0,
	"homesickness": 0.0,
	"diaspora_belonging": 0.0,
	"local_acceptance": 0.0,
	"prejudice_exposure": 0.0,
	"nostalgia": 0.0,
	"return_home_pull": 0.0,
	"foreign_prestige": 0.0,
	"split_family_identity": 0.0,
	"language_drift": 0.0,
	"culture_drift": 0.0,
	"exile_weight": 0.0,
	"refugee_trauma": 0.0,
	"celebrity_transplant_heat": 0.0,
	"migrant_boxer_edge": 0.0
}



var place_identity_tags: Array = []
var locality_faction_affinities: Dictionary = {}


var years_in_current_place: int = 0
var total_place_moves: int = 0
var last_place_shift_year: int = -999999
var place_echo_stack: Array = []
var place_influence_profile: Dictionary = {}
var place_conflict_profile: Dictionary = {}
var place_trait_drift_profile: Dictionary = {}
var place_influence_strength: float = 0.0
var place_identity_summary: Dictionary = {}
var place_yearly_snapshots: Array = []
var place_adaptation_flags: Array = []

var fame: int = 0
var fame_tier: String = "None"
var fame_job: String = ""
var scandal: int = 0
var paparazzi_heat: int = 0




var social_class: String = "Commoner"
var class_mobility: int = 0




var is_royal: bool = false
var royal_title: String = ""
var civic_title: String = ""
var civic_office_contract: Dictionary = {}
var realm_id: int = -1
var approval: int = 50
var is_ruler: bool = false
var succession_rank: int = 99
var exiled: bool = false
var deposed: bool = false
var palace_owned: bool = false



var has_many_realms_ring: bool = false
var hidden_realm_id: String = ""
var hidden_realm_title: String = ""
var hidden_realm_visible: bool = false

var parents_exploit_fame: bool = false

var pregnant_by_id: int = -1
var pregnancy_progress: int = -1
var unborn_child_other_parent_id: int = -1
var pregnancy_known: bool = false
var pregnancy_context: String = ""



var desires = {
	"core": [],
	"active": [],
	"impulses": []
}
var motivation: float = 50
var ambition: float = 50
var willpower: float = 50
var willpower_profile: Dictionary = {
	"schema": "eralife.person_willpower_profile",
	"version": 1,
	"core_score": 50.0,
	"resistance": {
		"emotional_resistance": 50.0,
		"fear_resistance": 50.0,
		"pain_resistance": 50.0,
		"pressure_resistance": 50.0
	},
	"persistence": {
		"long_term_endurance": 50.0,
		"retry_willingness": 50.0,
		"failure_tolerance": 50.0
	},
	"reality_defiance": {
		"fate_resistance": 0.0,
		"timeline_stability": 0.0,
		"outcome_rejection_strength": 0.0
	},
	"degradation": {
		"burnout": 0.0,
		"mental_fatigue": 0.0,
		"collapse_threshold": 100.0,
		"collapse_pressure": 0.0
	},
	"duel_state": {
		"last_stand_count": 0,
		"last_stand_year": -999999,
		"last_stand_ms": 0
	}
}




var long_term_goals: Array = []


var strategic_focus: String = ""




var bending_type: String = "none"
var bending_mastery = {
	"air": 0,
	"earth": 0,
	"fire": 0,
	"water": 0,
	"metal": 0
}

var bending_latent_potential = {
	"air": 0,
	"earth": 0,
	"fire": 0,
	"water": 0
}

var avatar_state_unlocked: bool = false
var avatar_state_used: bool = false
var bending_nation: String = ""
var bending_skill_points: int = 0
var bending_duel_records: Dictionary = {}
var bending_tournament_profile: Dictionary = {}
var bending_combat_profile: Dictionary = {
	"schema": "eralife.person_bending_combat_profile",
	"version": 1,
	"accuracy": 50,
	"power": 50,
	"guard": 50,
	"counter": 50,
	"evasion": 50,
	"focus": 50,
	"duel_records": bending_duel_records.duplicate(true),
	"tournament_profile": bending_tournament_profile.duplicate(true),
	"style_points_spent": 0
}



var wizard_profile: Dictionary = {
	"schema": "eralife.person_wizard_profile",
	"version": 1,
	"is_wizard": false,
	"wizard_blood_status": "human",
	"full_wizard": false,
	"magic_status": "inactive",
	"lineage_id": "",
	"family_power_rank": "ordinary",
	"archetype": "scholar",
	"skill": {
		"spellcraft": 0,
		"wand_control": 0,
		"spell_theory": 0,
		"dueling": 0,
		"artifact_lore": 0,
		"dark_magic": 0,
		"energy_balance": 50
	},
	"xp": {
		"study": 0,
		"practice": 0,
		"duels": 0,
		"library": 0,
		"wand": 0
	},
	"wand": {
		"id": "training_wand",
		"name": "Training Wand",
		"tier": "training",
		"level": 1,
		"stability": 65,
		"power": 8
	},
	"known_spells": [],
	"spell_history": [],
	"dark_magic": {
		"exposure": 0,
		"temptation": 0,
		"used_forbidden_spell": false
	},
	"council": {
		"oath_violations": [],
		"heat": 0,
		"stripped": false,
		"exiled": false,
	},
	"competition": {
		"eligible_age": 18,
		"available": false,
		"entered": false,
		"resolved": false,
		"result": "",
		"rounds": [],
		"score": 0,
		"champion_year": -1
	},
	"energy": {
		"magic": 40,
		"chi": 0,
		"flow_balance": 100,
		"instability": 0
	},
	"family": {
		"parent_status": "",
		"sibling_rivalry": 0,
		"competition_sibling_ids": []
	}
}




var school_mode: String = ""
var school_name: String = ""
var school_status: String = ""
var education_level: String = "None"
var schoolmates: Array = []



var capabilities = {
	"nodes": {},
	"edges": {}
}



var combat_sports_unlocked: Array = []
var boxing_profile:= {
	"is_boxer": false,
	"turned_pro": false,
	"retired": false,
	"gym_name": "",
	"stance": "",
	"weight_class": "",
	"natural_weight": 0,
	"promoter": "",
	"record": {
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"kos": 0
	},
	"amateur_record": {
		"wins": 0,
		"losses": 0
	},
	"ratings": {
		"power": 50,
		"speed": 50,
		"chin": 50,
		"ring_iq": 50,
		"defense": 50,
		"footwork": 50,
		"cardio": 50,
		"killer_instinct": 50
	},
	"style_tags": [],
	"division_rank": -1,
	"belts": [],
	"title_defenses": 0,
	"undisputed_divisions": [],
	"current_injuries": [],
	"scar_tissue": 0,
	"wear": 0,
	"last_fight_year": -9999,
	"next_fight_year": -1,
	"scheduled_opponent_id": -1,





	"nickname": "",
	"boxing_personality": {
		"discipline": 50,
		"ego": 50,
		"courage": 50,
		"showmanship": 50,
		"violence": 50,
		"adaptability": 50,
		"professionalism": 50
	},
	"fight_history": [],
	"rivalries": [],
	"callouts": [],
	"media_heat": 0,
	"fan_favorite": 0,
	"promoter_trust": 50,
	"amateur_circuit": {
		"is_amateur": false,
		"tournaments_won": 0,
		"olympic_gold": false,
		"olympic_medals": 0
	},
	"weight_management": {
		"walkaround_weight": 0,
		"weight_cut_difficulty": 0,
		"last_weight_miss_year": -9999,
		"division_history": [],
		"preferred_division": ""
	},
	"mandatory_status": {
		"is_mandatory": false,
		"belt": "",
		"division": "",
		"deadline_year": -1
	},
	"boxing_family": {
		"parent_boxer_ids": [],
		"family_gym": "",
		"legacy_pressure": 0,
		"fighting_dynasty_name": ""
	},
	"prime_years": {
		"start": -1,
		"end": -1
	},
	"faction_id": "",
	"faction_role": "",
	"boxing_world_tier": "local",
	"boxing_circuit_flags": {
	},
	"round_log_last_fight": [],
	"signature_wins": [],
	"signature_losses": [],
	"ducked_by_ids": [],
	"ducked_opponents": [],
	"trash_talk_reputation": 0
}
var vampire_profile = {
	"is_vampire": false,
	"vampire_stage": "",
	"maker_id": -1,
	"bloodline_name": "",
	"coven_id": "",
	"thirst": 0,
	"humanity": 100,
	"masquerade_heat": 0,
	"sun_resistance": 0,
	"blood_potency": 0,
	"generation_depth": 0,
	"turned_year": 0,
	"last_feed_year": 0,
	"preferred_prey_type": "human",
	"vampire_traits": [],
	"known_by_ids": [],
	"hunters_after_me": [],
	"is_cured": false,
	"daywalker": false,
	"coffin_home_id": -1,
	"victim_history": [],
	"maker_bond_strength": 0,
	"fed_this_year": false
}




var person_contract: Dictionary = {}
var person_contract_slices: Dictionary = {}

var power_profiles: Dictionary = {
	"wizard": {},
	"bending": {},
	"vampire": {},
	"saiyan": {},
	"omnitrix": {}
}

var combat_profiles: Dictionary = {
	"boxing": {}
}

var supernatural_contracts: Dictionary = {}
var inherited_systems: Dictionary = {
	"bloodlines": [],
	"dynasties": [],
	"family_trials": [],
	"power_inheritance": {},
	"contract_inheritance": {}
}

var world_law_residue: Dictionary = {
	"schema": PERSON_WORLD_LAW_RESIDUE_SCHEMA,
	"version": PERSON_CONTRACT_VERSION,
	"source_world_id": "",
	"source_reality_mode": "",
	"entered_world_ids": [],
	"foreign_rule_exposure": {},
	"law_conflicts": [],
	"law_adaptations": {},
	"identity_echoes": [],
	"power_echoes": {},
	"capsule_echoes": {}
}

var reality_fusion_identity: Dictionary = {
	"original_person_id": -1,
	"original_universe_year": -1,
	"original_world_label": "",
	"current_universe_label": "",
	"fusion_history": [],
	"identity_instability": 0.0,
	"foreign_universe_count": 0,
	"last_fusion_ms": 0
}

var tap_to_play_identity: Dictionary = {
	"portable": true,
	"capsule_id": "",
	"life_id": "",
	"lineage_id": "",
	"timeline_id": "",
	"stable_person_key": "",
	"restore_policy": "contract_first_legacy_mirror_second",
	"unknown_profile_policy": "preserve"
}
func _init() -> void:
	ensure_person_contract({
		"source": "person_init"
	})


func ensure_person_contract(context: Dictionary = {}) -> Dictionary:
	_normalize_power_profiles_from_legacy()

	var defaults: Dictionary = _default_person_contract(context)
	var existing: Dictionary = _safe_dictionary(person_contract)
	var resolved: Dictionary = _merge_dict(defaults, existing)

	resolved ["schema"] = PERSON_CONTRACT_SCHEMA
	resolved ["version"] = PERSON_CONTRACT_VERSION
	resolved ["updated_at_ms"] = int(Time.get_ticks_msec())
	resolved ["last_context"] = context.duplicate(true)

	resolved ["identity"] = _build_identity_contract()
	resolved ["biology"] = _build_biology_contract()
	resolved ["class_status"] = _build_class_status_contract()
	resolved ["place_memory"] = _build_place_memory_contract()
	resolved ["consciousness"] = _build_consciousness_contract()
	resolved ["family_graph"] = _build_family_graph_contract()
	resolved ["family"] = _build_family_contract(context)
	resolved ["social_status"] = _build_social_status_contract()
	resolved ["power_profiles"] = _safe_dictionary(power_profiles)
	resolved ["combat_profiles"] = _safe_dictionary(combat_profiles)
	resolved ["supernatural_contracts"] = _safe_dictionary(supernatural_contracts)
	resolved ["inherited_systems"] = _safe_dictionary(inherited_systems)
	resolved ["world_law_residue"] = _build_world_law_residue_contract(context)
	resolved ["reality_fusion_identity"] = _safe_dictionary(reality_fusion_identity)
	resolved ["tap_to_play_identity"] = _build_tap_to_play_identity_contract(context)
	resolved ["legacy_bridge"] = _build_legacy_bridge_contract()

	person_contract = _make_binary_safe(resolved)
	apply_power_profiles_to_legacy()

	return person_contract.duplicate(true)


func export_contract_slice(options: Dictionary = {}) -> Dictionary:
	var contract: Dictionary = ensure_person_contract(options)

	return _make_binary_safe({
		"schema": PERSON_CONTRACT_SLICE_SCHEMA,
		"version": PERSON_CONTRACT_VERSION,
		"person_id": int(id),
		"person_name": _display_name(),
		"source": str(options.get("source", "person_export")),
		"exported_at_ms": int(Time.get_ticks_msec()),
		"contract": contract.duplicate(true),
		"power_profiles": _safe_dictionary(power_profiles),
		"combat_profiles": _safe_dictionary(combat_profiles),
		"genetics_contract": _safe_dictionary(genetics_contract),
		"body_type_contract": _safe_dictionary(body_type_contract),
		"growth_curve_contract": _safe_dictionary(growth_curve_contract),
		"height_contract": _safe_dictionary(height_contract),
		"weight_contract": _safe_dictionary(weight_contract),
		"body_contract": _safe_dictionary(body_contract),
		"world_law_residue": _safe_dictionary(world_law_residue),
		"reality_fusion_identity": _safe_dictionary(reality_fusion_identity),
		"tap_to_play_identity": _safe_dictionary(tap_to_play_identity),
		"legacy_bridge": _build_legacy_bridge_contract(),
		"compatibility": {
			"unknown_profile_policy": "preserve",
		}
	})


func import_contract_slice(slice: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.person_contract_import_report",
		"version": PERSON_CONTRACT_VERSION,
		"success": false,
		"person_id": int(id),
		"source": str(options.get("source", "person_import")),
		"warnings": [],
		"imported_profiles": [],
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(slice) != TYPE_DICTIONARY or slice.is_empty():
		report ["warnings"].append("Person contract slice was empty.")
		return report

	var contract_raw: Dictionary = _safe_dictionary(slice.get("contract", {}))
	if contract_raw.is_empty() and str(slice.get("schema", "")) == PERSON_CONTRACT_SCHEMA:
		contract_raw = slice.duplicate(true)

	if not contract_raw.is_empty():
		person_contract = _merge_dict(_default_person_contract(options), contract_raw)

	var profile_raw: Dictionary = _safe_dictionary(slice.get("power_profiles", contract_raw.get("power_profiles", {})))
	if not profile_raw.is_empty():
		var merged_profiles: Dictionary = _safe_dictionary(power_profiles)
		for profile_id in profile_raw.keys():
			var clean_id: String = str(profile_id).strip_edges().to_lower()
			if clean_id == "":
				continue
			merged_profiles [clean_id] = _merge_dict(_safe_dictionary(merged_profiles.get(clean_id, {})), _safe_dictionary(profile_raw.get(profile_id, {})))
			report ["imported_profiles"].append(clean_id)
		power_profiles = merged_profiles

	var combat_raw: Dictionary = _safe_dictionary(slice.get("combat_profiles", contract_raw.get("combat_profiles", {})))
	if not combat_raw.is_empty():
		combat_profiles = _merge_dict(_safe_dictionary(combat_profiles), combat_raw)
	var genetics_raw: Dictionary = _safe_dictionary(slice.get("genetics_contract", contract_raw.get("genetics_contract", {})))
	if not genetics_raw.is_empty():
		genetics_contract = _merge_dict(_safe_dictionary(genetics_contract), genetics_raw)

	var body_type_raw: Dictionary = _safe_dictionary(slice.get("body_type_contract", contract_raw.get("body_type_contract", {})))
	if not body_type_raw.is_empty():
		body_type_contract = _merge_dict(_safe_dictionary(body_type_contract), body_type_raw)

	var growth_raw: Dictionary = _safe_dictionary(slice.get("growth_curve_contract", contract_raw.get("growth_curve_contract", {})))
	if not growth_raw.is_empty():
		growth_curve_contract = _merge_dict(_safe_dictionary(growth_curve_contract), growth_raw)

	var height_raw: Dictionary = _safe_dictionary(slice.get("height_contract", contract_raw.get("height_contract", {})))
	if not height_raw.is_empty():
		height_contract = _merge_dict(_safe_dictionary(height_contract), height_raw)

	var weight_raw: Dictionary = _safe_dictionary(slice.get("weight_contract", contract_raw.get("weight_contract", {})))
	if not weight_raw.is_empty():
		weight_contract = _merge_dict(_safe_dictionary(weight_contract), weight_raw)

	var body_raw: Dictionary = _safe_dictionary(slice.get("body_contract", contract_raw.get("body_contract", {})))
	if not body_raw.is_empty():
		body_contract = _merge_dict(_safe_dictionary(body_contract), body_raw)
	var residue_raw: Dictionary = _safe_dictionary(slice.get("world_law_residue", contract_raw.get("world_law_residue", {})))
	if not residue_raw.is_empty():
		world_law_residue = _merge_dict(_safe_dictionary(world_law_residue), residue_raw)

	var fusion_raw: Dictionary = _safe_dictionary(slice.get("reality_fusion_identity", contract_raw.get("reality_fusion_identity", {})))
	if not fusion_raw.is_empty():
		reality_fusion_identity = _merge_dict(_safe_dictionary(reality_fusion_identity), fusion_raw)

	var tap_raw: Dictionary = _safe_dictionary(slice.get("tap_to_play_identity", contract_raw.get("tap_to_play_identity", {})))
	if not tap_raw.is_empty():
		tap_to_play_identity = _merge_dict(_safe_dictionary(tap_to_play_identity), tap_raw)

	apply_power_profiles_to_legacy()
	ensure_person_contract({
		"source": str(options.get("source", "person_import_finalize")),
		"imported_slice_schema": str(slice.get("schema", "")),
		"imported_profiles": report ["imported_profiles"].duplicate(true)
	})

	report ["success"] = true
	return report


func get_power_profile(profile_id: String, ensure_exists: bool = true) -> Dictionary:
	var clean_id: String = str(profile_id).strip_edges().to_lower()
	if clean_id == "":
		return {}

	if ensure_exists:
		_normalize_power_profiles_from_legacy()

	return _safe_dictionary(power_profiles.get(clean_id, {}))


func set_power_profile(profile_id: String, profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(profile_id).strip_edges().to_lower()
	if clean_id == "":
		return {
			"success": false,
			"reason": "Power profile id missing."
		}

	var profiles: Dictionary = _safe_dictionary(power_profiles)
	var current: Dictionary = _safe_dictionary(profiles.get(clean_id, {}))
	var merged: Dictionary = _merge_dict(current, profile)
	merged ["profile_id"] = clean_id
	merged ["updated_at_ms"] = int(Time.get_ticks_msec())
	merged ["source"] = str(options.get("source", "set_power_profile"))

	profiles [clean_id] = merged
	power_profiles = profiles

	apply_power_profiles_to_legacy()
	ensure_person_contract({
		"source": "set_power_profile",
		"profile_id": clean_id
	})

	return {
		"success": true,
		"profile_id": clean_id,
		"profile": merged.duplicate(true)
	}


func apply_power_profiles_to_legacy() -> void:
	var bending: Dictionary = _safe_dictionary(power_profiles.get("bending", {}))
	if not bending.is_empty():
		bending_type = str(bending.get("type", bending_type))
		bending_mastery = _safe_dictionary(bending.get("mastery", bending_mastery))
		bending_latent_potential = _safe_dictionary(bending.get("latent_potential", bending_latent_potential))
		avatar_state_unlocked = bool(bending.get("avatar_state_unlocked", avatar_state_unlocked))
		avatar_state_used = bool(bending.get("avatar_state_used", avatar_state_used))
		bending_nation = str(bending.get("nation", bending_nation))
		bending_skill_points = int(bending.get("skill_points", bending_skill_points))
		bending_combat_profile = _safe_dictionary(bending.get("combat_profile", bending_combat_profile))
		bending_duel_records = _safe_dictionary(bending.get("duel_records", {}))
		bending_tournament_profile = _safe_dictionary(bending.get("tournament_profile", {}))
	var wizard: Dictionary = _safe_dictionary(power_profiles.get("wizard", {}))
	if not wizard.is_empty():
		wizard_profile = wizard.duplicate(true)

	var vampire: Dictionary = _safe_dictionary(power_profiles.get("vampire", {}))
	if not vampire.is_empty():
		vampire_profile = vampire.duplicate(true)

	var boxing: Dictionary = _safe_dictionary(combat_profiles.get("boxing", power_profiles.get("boxing", {})))
	if not boxing.is_empty():
		boxing_profile = boxing.duplicate(true)


func _normalize_power_profiles_from_legacy() -> void:
	var profiles: Dictionary = _safe_dictionary(power_profiles)

	profiles ["wizard"] = _merge_dict(_safe_dictionary(profiles.get("wizard", {})), _safe_dictionary(wizard_profile))

	profiles ["bending"] = _merge_dict(_safe_dictionary(profiles.get("bending", {})), {
		"schema": "eralife.person_power_profile.bending",
		"version": PERSON_CONTRACT_VERSION,
		"profile_id": "bending",
		"type": str(bending_type),
		"mastery": _safe_dictionary(bending_mastery),
		"latent_potential": _safe_dictionary(bending_latent_potential),
		"avatar_state_unlocked": bool(avatar_state_unlocked),
		"avatar_state_used": bool(avatar_state_used),
		"nation": str(bending_nation),
		"skill_points": int(bending_skill_points),
		"combat_profile": _safe_dictionary(bending_combat_profile)
	})

	profiles ["vampire"] = _merge_dict(_safe_dictionary(profiles.get("vampire", {})), _safe_dictionary(vampire_profile))

	if not profiles.has("saiyan") or typeof(profiles.get("saiyan")) != TYPE_DICTIONARY:
		profiles ["saiyan"] = {
			"schema": "eralife.person_power_profile.saiyan",
			"version": PERSON_CONTRACT_VERSION,
			"profile_id": "saiyan",
			"unlocked": false,
			"bloodline": "",
			"forms": [],
			"ki": 0,
			"battle_power": 0,
			"zenkai_history": [],
			"tail_state": "none",
			"rage_multiplier": 1.0
		}

	if not profiles.has("omnitrix") or typeof(profiles.get("omnitrix")) != TYPE_DICTIONARY:
		profiles ["omnitrix"] = {
			"schema": "eralife.person_power_profile.omnitrix",
			"version": PERSON_CONTRACT_VERSION,
			"profile_id": "omnitrix",
			"unlocked": false,
			"device_id": "",
			"activation_mode": "manual_or_emergency",
			"current_form": "",
			"saved_identity_forms": [],
			"alien_forms": [],
			"cooldown": 0,
			"instability": 0,
			"reversion_policy": {
			}
		}

	power_profiles = profiles

	var combats: Dictionary = _safe_dictionary(combat_profiles)
	combats ["boxing"] = _merge_dict(_safe_dictionary(combats.get("boxing", {})), _safe_dictionary(boxing_profile))
	combat_profiles = combats


func _default_person_contract(context: Dictionary = {}) -> Dictionary:
	return {
		"schema": PERSON_CONTRACT_SCHEMA,
		"version": PERSON_CONTRACT_VERSION,
		"model": {
			"identity": true,
			"biology": true,
			"class": true,
			"place_memory": true,
			"consciousness": true,
			"family_graph": true,
			"family": true,
			"social_status": true,
			"power_profiles": true,
			"combat_profiles": true,
			"supernatural_contracts": true,
			"inherited_systems": true,
			"world_law_residue": true,
			"reality_fusion_identity": true,
			"tap_to_play_identity": true
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"last_context": context.duplicate(true),
		"compatibility": {
		}
	}


func _build_identity_contract() -> Dictionary:
	return {
		"id": int(id),
		"name": _display_name(),
		"first_name": str(first_name),
		"last_name": str(last_name),
		"gender": str(gender),
		"age": int(age),
		"alive": bool(alive),
		"birth_city": str(birth_city),
		"birth_country": str(birth_country),
		"home_city": str(home_city),
		"home_country": str(home_country),
		"birthday": _safe_dictionary(birthday),
		"zodiac": str(zodiac),
		"fate_arc": str(fate_arc),
		"dynasty_origin": str(dynasty_origin),
		"dynasty_prestige": int(dynasty_prestige)
	}


func _build_biology_contract() -> Dictionary:
	return {
		"health": float(health),
		"mental_health": float(mental_health),
		"hunger": float(hunger),
		"fertility": float(fertility),
		"last_minor_illness_age": int(last_minor_illness_age),
		"alive": bool(alive),
		"cause_of_death": str(cause_of_death),
		"death_year": int(death_year),
		"genetics_contract": _safe_dictionary(genetics_contract),
		"body_type_contract": _safe_dictionary(body_type_contract),
		"growth_curve_contract": _safe_dictionary(growth_curve_contract),
		"height_contract": _safe_dictionary(height_contract),
		"weight_contract": _safe_dictionary(weight_contract),
		"body_contract": _safe_dictionary(body_contract),
		"pregnancy": {
			"pregnant_by_id": int(pregnant_by_id),
			"pregnancy_progress": int(pregnancy_progress),
			"unborn_child_other_parent_id": int(unborn_child_other_parent_id),
			"pregnancy_known": bool(pregnancy_known),
			"pregnancy_context": str(pregnancy_context)
		}
	}

func _build_class_status_contract() -> Dictionary:
	return {
		"social_class": str(social_class),
		"class_mobility": int(class_mobility),
		"job": str(job),
		"income": income,
		"bank_balance": bank_balance,
		"expenses": expenses,
		"satisfaction": float(satisfaction),
		"job_performance": int(job_performance),
		"job_experience": int(job_experience),
		"unemployed_years": int(unemployed_years),
		"work_stress": float(work_stress),
		"hours_worked_last_year": int(hours_worked_last_year),
		"current_workplace_id": str(current_workplace_id)
	}


func _build_place_memory_contract() -> Dictionary:
	return {
		"settlement_id": str(settlement_id),
		"district_id": str(district_id),
		"locality_id": str(locality_id),
		"origin_settlement_id": str(origin_settlement_id),
		"origin_district_id": str(origin_district_id),
		"origin_locality_id": str(origin_locality_id),
		"birthplace_settlement_id": str(birthplace_settlement_id),
		"migration_history": _safe_array(migration_history),
		"diaspora_tags": _safe_array(diaspora_tags),
		"identity_residue": _safe_dictionary(identity_residue),
		"place_identity_tags": _safe_array(place_identity_tags),
		"locality_faction_affinities": _safe_dictionary(locality_faction_affinities),
		"years_in_current_place": int(years_in_current_place),
		"total_place_moves": int(total_place_moves),
		"last_place_shift_year": int(last_place_shift_year),
		"place_echo_stack": _safe_array(place_echo_stack),
		"place_influence_profile": _safe_dictionary(place_influence_profile),
		"place_conflict_profile": _safe_dictionary(place_conflict_profile),
		"place_trait_drift_profile": _safe_dictionary(place_trait_drift_profile),
		"place_influence_strength": float(place_influence_strength),
		"place_identity_summary": _safe_dictionary(place_identity_summary),
		"place_yearly_snapshots": _safe_array(place_yearly_snapshots),
		"place_adaptation_flags": _safe_array(place_adaptation_flags)
	}


func _build_consciousness_contract() -> Dictionary:
	return {
		"traits": _safe_array(traits),
		"memories": _safe_array(memories),
		"consciousness_contract": _safe_dictionary(consciousness_contract),
		"consciousness_state": _safe_dictionary(consciousness_state),
		"consciousness_memory_index": _safe_array(consciousness_memory_index),
		"soul_seed_contract": _safe_dictionary(soul_seed_contract),
		"soul_seed_state": _safe_dictionary(soul_seed_state),
		"desires": _safe_dictionary(desires),
		"motivation": float(motivation),
		"ambition": float(ambition),
		"willpower": float(willpower),
		"willpower_profile": _safe_dictionary(willpower_profile),
		"long_term_goals": _safe_array(long_term_goals),
		"strategic_focus": str(strategic_focus),
		"capabilities": _safe_dictionary(capabilities),
		"terabithia_state": _safe_dictionary(terabithia_state)
	}

func _build_family_graph_contract() -> Dictionary:
	return {
		"parent_ids": _person_id_array(parents),
		"child_ids": _person_id_array(children),
		"partner_id": _person_ref_id(partner),
		"marital_status": str(marital_status),
		"ex_partners": _safe_array(ex_partners),
		"maiden_last_name": str(maiden_last_name),
		"parents_exploit_fame": bool(parents_exploit_fame)
	}


func _build_family_contract(context: Dictionary = {}) -> Dictionary:
	var existing_contract: Dictionary = _safe_dictionary(person_contract)
	var existing_family: Dictionary = _safe_dictionary(existing_contract.get("family", {}))
	var parent_ids: Array = _person_id_array(parents)
	var child_ids: Array = _person_id_array(children)
	var partner_id: int = _person_ref_id(partner)

	var family_contract: Dictionary = existing_family.duplicate(true)
	family_contract ["schema"] = "eralife.person_contract.family"
	family_contract ["version"] = PERSON_CONTRACT_VERSION
	family_contract ["person_id"] = int(id)
	family_contract ["person_name"] = _display_name()
	family_contract ["source"] = str(context.get("source", "person_contract_family_surface"))
	family_contract ["parents"] = parent_ids
	family_contract ["children"] = child_ids
	family_contract ["siblings"] = _safe_array(existing_family.get("siblings", []))
	family_contract ["partner"] = {
		"partner_id": partner_id,
		"marital_status": str(marital_status),
		"active": partner_id > 0
	}
	family_contract ["household"] = _safe_dictionary(existing_family.get("household", {}))
	family_contract ["custodial_adult"] = _safe_dictionary(existing_family.get("custodial_adult", {}))
	family_contract ["inheritance_chain"] = _safe_array(existing_family.get("inheritance_chain", []))
	family_contract ["estate"] = _safe_dictionary(existing_family.get("estate", {}))
	family_contract ["dynasty"] = {
		"dynasty_origin": str(dynasty_origin),
		"dynasty_prestige": int(dynasty_prestige),
		"last_name": str(last_name)
	}
	family_contract ["royal_family"] = {
		"is_royal": bool(is_royal),
		"is_ruler": bool(is_ruler),
		"royal_title": str(royal_title),
		"realm_id": int(realm_id),
		"succession_rank": int(succession_rank),
		"approval": int(approval),
		"exiled": bool(exiled),
		"deposed": bool(deposed),
		"palace_owned": bool(palace_owned)
	}
	family_contract ["household_cluster"] = _safe_dictionary(existing_family.get("household_cluster", {}))
	family_contract ["family_graph_legacy"] = _build_family_graph_contract()
	family_contract ["contract_mesh"] = {
		"source_of_truth": "person_self_surface_until_family_contract_engine_hydrates",
	}
	family_contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	return family_contract


func _build_social_status_contract() -> Dictionary:
	return {
		"friends": _safe_array(friends),
		"coworkers": _safe_array(coworkers),
		"schoolmates": _safe_array(schoolmates),
		"affection": _safe_dictionary(affection),
		"respect": int(respect),
		"respect_profile": _safe_dictionary(respect_profile),
		"fame": int(fame),
		"fame_tier": str(fame_tier),
		"fame_job": str(fame_job),
		"scandal": int(scandal),
		"paparazzi_heat": int(paparazzi_heat),
		"royalty": {
			"is_royal": bool(is_royal),
			"royal_title": str(royal_title),
			"realm_id": int(realm_id),
			"approval": int(approval),
			"is_ruler": bool(is_ruler),
			"succession_rank": int(succession_rank),
			"exiled": bool(exiled),
			"deposed": bool(deposed),
			"palace_owned": bool(palace_owned)
		},
		"many_realms": {
			"has_many_realms_ring": bool(has_many_realms_ring),
			"hidden_realm_id": str(hidden_realm_id),
			"hidden_realm_title": str(hidden_realm_title),
			"hidden_realm_visible": bool(hidden_realm_visible)
		},
		"school": {
			"school_mode": str(school_mode),
			"school_name": str(school_name),
			"school_status": str(school_status),
			"education_level": str(education_level)
		}
	}


func _build_world_law_residue_contract(context: Dictionary = {}) -> Dictionary:
	var residue: Dictionary = _safe_dictionary(world_law_residue)
	residue ["schema"] = PERSON_WORLD_LAW_RESIDUE_SCHEMA
	residue ["version"] = PERSON_CONTRACT_VERSION
	residue ["identity_residue"] = _safe_dictionary(identity_residue)
	residue ["place_identity_tags"] = _safe_array(place_identity_tags)
	residue ["last_context"] = context.duplicate(true)

	if str(context.get("source_reality_mode", "")).strip_edges() != "":
		residue ["source_reality_mode"] = str(context.get("source_reality_mode", "")).strip_edges()

	if str(context.get("target_reality_mode", "")).strip_edges() != "":
		residue ["target_reality_mode"] = str(context.get("target_reality_mode", "")).strip_edges()

	if str(context.get("world_id", "")).strip_edges() != "":
		residue ["source_world_id"] = str(context.get("world_id", "")).strip_edges()

	world_law_residue = residue.duplicate(true)
	return residue


func _build_tap_to_play_identity_contract(context: Dictionary = {}) -> Dictionary:
	var tap: Dictionary = _safe_dictionary(tap_to_play_identity)

	if str(tap.get("stable_person_key", "")).strip_edges() == "":
		tap ["stable_person_key"] = "%s.%s.%s" % [str(first_name).to_lower(), str(last_name).to_lower(), str(id)]

	for key in ["capsule_id", "life_id", "lineage_id", "timeline_id"]:
		if str(context.get(key, "")).strip_edges() != "":
			tap [key] = str(context.get(key, "")).strip_edges()

	tap ["portable"] = true
	tap ["restore_policy"] = str(tap.get("restore_policy", "contract_first_legacy_mirror_second"))
	tap ["unknown_profile_policy"] = str(tap.get("unknown_profile_policy", "preserve"))
	tap_to_play_identity = tap.duplicate(true)
	return tap


func _build_legacy_bridge_contract() -> Dictionary:
	return {
		"mirror_policy": "contract_updates_legacy_fields_after_import",
		"power_legacy_fields": {
			"wizard_profile": "power_profiles.wizard",
			"bending_type": "power_profiles.bending.type",
			"bending_mastery": "power_profiles.bending.mastery",
			"bending_latent_potential": "power_profiles.bending.latent_potential",
			"avatar_state_unlocked": "power_profiles.bending.avatar_state_unlocked",
			"avatar_state_used": "power_profiles.bending.avatar_state_used",
			"bending_nation": "power_profiles.bending.nation",
			"vampire_profile": "power_profiles.vampire",
			"boxing_profile": "combat_profiles.boxing"
		},
		"save_compatibility": {
		}
	}


func _display_name() -> String:
	var full: String = ("%s %s" % [str(first_name), str(last_name)]).strip_edges()
	if full != "":
		return full
	return str(name)


func _person_id_array(values: Array) -> Array:
	var out: Array = []
	for raw_value in values:
		var ref_id: int = _person_ref_id(raw_value)
		if ref_id >= 0 and not out.has(ref_id):
			out.append(ref_id)
	return out


func _person_ref_id(value: Variant) -> int:
	if value == null:
		return -1

	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_DICTIONARY:
		return int((value as Dictionary).get("id", -1))

	if typeof(value) == TYPE_OBJECT:
		if "id" in value:
			return int(value.id)
		return -1

	var clean_text: String = str(value).strip_edges()
	if clean_text == "":
		return -1

	return int(clean_text)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for raw_key in overlay.keys():
		var overlay_value: Variant = overlay.get(raw_key)
		var base_value: Variant = out.get(raw_key)

		if typeof(base_value) == TYPE_DICTIONARY and typeof(overlay_value) == TYPE_DICTIONARY:
			out [raw_key] = _merge_dict(base_value as Dictionary, overlay_value as Dictionary)
		else:
			out [raw_key] = _make_binary_safe(overlay_value)

	return out


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item in value as Array:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_OBJECT:
			return str(value)
		_:
			return value