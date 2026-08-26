extends Resource
class_name DragonBallsEngine

const CONTRACT_SCHEMA:= "eralife.dragonballs_contract"
const CONTRACT_VERSION:= 2
const STATE_SCHEMA:= "eralife.dragonballs_state"
const STATE_KEY:= "dragonballs_state"
const MAX_WISH_LEDGER:= 120
const MAX_GENETIC_LEDGER:= 220

var gs
var wish_generation_contract: Dictionary = {}
var saiyan_contract: Dictionary = {}
var affordance_fusion_contracts: Dictionary = {}
var ki_ability_contracts: Dictionary = {}
var last_wish_report: Dictionary = {}
var last_genetic_report: Dictionary = {}
func _init(_gs):
	gs = _gs
	bootstrap_default_contracts()
func bootstrap_default_contracts() -> Dictionary:
	saiyan_contract = _default_saiyan_contract()
	wish_generation_contract = _default_wish_generation_contract()
	affordance_fusion_contracts = _default_affordance_fusion_contracts()
	ki_ability_contracts = _default_ki_ability_contracts()

	var state: Dictionary = _world_state()
	state ["active_contract"] = {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"saiyan_contract": saiyan_contract.duplicate(true),
		"wish_generation_contract": wish_generation_contract.duplicate(true),
		"affordance_fusion_contracts": affordance_fusion_contracts.duplicate(true),
		"ki_ability_contracts": ki_ability_contracts.duplicate(true)
	}
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.dragonballs_contract_bootstrap_report",
		"version": CONTRACT_VERSION,
		"wish_generation_schema": str(wish_generation_contract.get("schema", "eralife.wish_generation")),
		"saiyan_contract_id": str(saiyan_contract.get("id", "saiyan_core")),
		"fusion_contract_count": affordance_fusion_contracts.size(),
		"ki_ability_count": ki_ability_contracts.size()
	}
func get_saiyan_power_modifier_packet(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"power_multiplier": 1.0,
			"flat_bonus": 0.0,
			"active_forms": []
		}

	if not _is_saiyan_person(actor):
		return {
			"success": true,
			"power_multiplier": 1.0,
			"flat_bonus": 0.0,
			"active_forms": []
		}

	var contract: Dictionary = get_saiyan_contract()
	var modifiers: Dictionary = _safe_dictionary(contract.get("form_modifiers", {}))
	var order: Array = _safe_array(contract.get("form_order", []))
	var active_forms: Array = []
	var highest_form_multiplier: float = 1.0
	var kaioken_multiplier: float = 1.0
	var instability: float = 0.0
	var mythic_presence: float = 0.0
	var world_distortion: float = 0.0
	var highest_form_label: String = "Base Saiyan"

	for raw_form_id in order:
		var form_id: String = str(raw_form_id).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(modifiers.get(form_id, {}))
		if row.is_empty():
			continue

		var active_trait: String = str(row.get("trait_active", "")).strip_edges()
		if active_trait == "" or not _trait_has(actor, active_trait):
			continue

		active_forms.append(form_id)

		var multiplier: float = max(1.0, float(row.get("power_multiplier", 1.0)))
		if str(row.get("stacking_mode", "highest_form")) == "amplifier":
			kaioken_multiplier = max(kaioken_multiplier, multiplier)
		else:
			if multiplier >= highest_form_multiplier:
				highest_form_multiplier = multiplier
				highest_form_label = str(row.get("display_name", form_id.capitalize()))

		instability += float(row.get("instability", 0.0))
		mythic_presence += float(row.get("mythic_presence", 0.0))
		world_distortion += float(row.get("world_distortion", 0.0))

	var era_scaling: Dictionary = _safe_dictionary(_safe_dictionary(contract.get("lineage_rules", {})).get("era_scaling", {}))
	var era_multiplier: float = float(era_scaling.get(_era_key(), 1.0))

	var total_multiplier: float = max(1.0, highest_form_multiplier * kaioken_multiplier * era_multiplier)

	return {
		"success": true,
		"schema": "eralife.saiyan_power_modifier_packet",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"power_multiplier": total_multiplier,
		"flat_bonus": 2500.0,
		"base_form_label": highest_form_label,
		"active_forms": active_forms.duplicate(true),
		"instability": instability,
		"mythic_presence": mythic_presence,
		"world_distortion": world_distortion,
		"context": context.duplicate(true)
	}


func _next_saiyan_form_to_unlock(actor: Person) -> Dictionary:
	var contract: Dictionary = get_saiyan_contract()
	var modifiers: Dictionary = _safe_dictionary(contract.get("form_modifiers", {}))
	var order: Array = _safe_array(contract.get("form_order", []))

	for raw_form_id in order:
		var form_id: String = str(raw_form_id).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(modifiers.get(form_id, {}))
		if row.is_empty():
			continue
		var unlocked_trait: String = str(row.get("trait_unlocked", "")).strip_edges()
		if unlocked_trait == "":
			continue
		if not _trait_has(actor, unlocked_trait):
			var out: Dictionary = row.duplicate(true)
			out ["id"] = form_id
			return out

	return {}
func get_saiyan_contract() -> Dictionary:
	if saiyan_contract.is_empty():
		bootstrap_default_contracts()
	return saiyan_contract.duplicate(true)

func _default_saiyan_contract() -> Dictionary:
	return {
		"schema": "eralife.saiyan_bloodline",
		"version": CONTRACT_VERSION,
		"id": "saiyan_core",
		"display_name": "Saiyan Bloodline",
		"genetics": {
			"base_race": "saiyan",
			"dominance_curve": 0.65,
			"offspring_parent_share_model": "weighted_half_split",
			"internal_slice_variance": 0.22,
		},
		"power_model": {
			"scaling": "combat_growth_exponential",
			"zenkai": true,
		},
		"affordance_tags": [
			"combat_adaptation",
			"rage_scaling",
			"limit_breaker",
			"ki_channel",
			"zenkai_recovery"
		],
		"forms": ["kaioken", "ssj1", "ssj2", "ssj3", "ssj4", "ssgss"],
		"form_order": ["kaioken", "ssj1", "ssj2", "ssj3", "ssj4", "ssgss"],
		"form_modifiers": {
			"kaioken": {
				"display_name": "Kaio-Ken",
				"trait_unlocked": "KaiokenUnlocked",
				"trait_active": "KaiokenActive",
				"power_multiplier": 2.0,
				"fatigue_pressure": 0.18,
				"instability": 8,
				"world_distortion": 4,
				"stacking_mode": "amplifier"
			},
			"ssj1": {
				"display_name": "Super Saiyan",
				"trait_unlocked": "SSJ1Unlocked",
				"trait_active": "SSJ1Active",
				"power_multiplier": 50.0,
				"fatigue_pressure": 0.12,
				"instability": 12,
				"mythic_presence": 20,
				"stacking_mode": "highest_form"
			},
			"ssj2": {
				"display_name": "Super Saiyan 2",
				"trait_unlocked": "SSJ2Unlocked",
				"trait_active": "SSJ2Active",
				"power_multiplier": 100.0,
				"fatigue_pressure": 0.18,
				"instability": 24,
				"mythic_presence": 38,
				"stacking_mode": "highest_form"
			},
			"ssj3": {
				"display_name": "Super Saiyan 3",
				"trait_unlocked": "SSJ3Unlocked",
				"trait_active": "SSJ3Active",
				"power_multiplier": 400.0,
				"fatigue_pressure": 0.32,
				"instability": 42,
				"mythic_presence": 62,
				"stacking_mode": "highest_form"
			},
			"ssj4": {
				"display_name": "Super Saiyan 4",
				"trait_unlocked": "SSJ4Unlocked",
				"trait_active": "SSJ4Active",
				"power_multiplier": 500.0,
				"fatigue_pressure": 0.24,
				"instability": 38,
				"mythic_presence": 78,
				"stacking_mode": "highest_form"
			},
			"ssgss": {
				"display_name": "Super Saiyan Blue",
				"trait_unlocked": "SSGSSUnlocked",
				"trait_active": "SSGSSActive",
				"power_multiplier": 1000.0,
				"fatigue_pressure": 0.28,
				"instability": 55,
				"mythic_presence": 100,
				"world_distortion": 35,
				"stacking_mode": "highest_form"
			}
		},
		"risks": {
			"rage_instability": 0.4,
			"destruction_impulse": 0.2,
			"power_overflow_mutation": 0.14,
			"timeline_attention": 0.1
		},
		"lineage_rules": {
			"inheritance_mode": "contract_driven",
			"minimum_expression_share": 0.16,
			"saiyan_expression_share": 0.18,
			"avatar_echo_expression_share": 0.16,
			"bending_expression_share": 0.12,
			"superpower_expression_share": 0.14,
			"era_scaling": {
				"ancient": 0.88,
				"medieval": 0.94,
				"industrial": 1.0,
				"modern": 1.08,
				"future": 1.16
			}
		}
	}
func _default_wish_generation_contract() -> Dictionary:
	return {
		"schema": "eralife.wish_generation",
		"version": CONTRACT_VERSION,
		"inputs": [
			"capability_tags",
			"affordances",
			"composed_affordances",
			"behavior_signature",
			"artifacts",
			"genetics",
			"lineage_ripples",
			"past_wishes",
			"life_stage",
			"era"
		],
		"output": "contextual_wish_set",
		"rules": {
		}
	}


func _default_affordance_fusion_contracts() -> Dictionary:
	return {
		"avatar_saiyan_time_overdrive": {
			"id": "avatar_saiyan_time_overdrive",
			"requires": ["avatar_state", "ssj2", "time_dominance"],
			"produces": {
				"id": "reality_overdrive",
				"description": "Move, think, and act beyond time itself while channeling all elements.",
				"success_weight": 0.99
			},
			"modifiers": {
				"instability": 40,
				"mythic_presence": 100,
				"world_distortion": 75
			}
		},
		"avatar_saiyan_polymorph_overdrive": {
			"id": "avatar_saiyan_polymorph_overdrive",
			"requires": ["avatar_state", "saiyan_bloodline", "infant_chaos_polymorph"],
			"produces": {
				"id": "chaotic_elemental_zenkai",
				"description": "Your polymorph body learns to mutate around elemental mastery and Saiyan combat growth.",
				"success_weight": 0.94
			},
			"modifiers": {
				"instability": 58,
				"mythic_presence": 120,
				"world_distortion": 64,
				"mutation_adaptability": 100
			}
		},
		"saiyan_bending_ki_channel": {
			"id": "saiyan_bending_ki_channel",
			"requires": ["saiyan_bloodline", "bending_affinity"],
			"produces": {
				"id": "ki_bending_channel",
				"description": "Ki pressure and elemental motion begin sharing the same combat channel.",
				"success_weight": 0.88
			},
			"modifiers": {
				"instability": 18,
				"mythic_presence": 38,
				"world_distortion": 20
			}
		}
	}


func _default_ki_ability_contracts() -> Dictionary:
	return {
		"ki_sense": {
			"id": "ki_sense",
			"display_name": "Ki Sense",
			"battle_xp_required": 1,
			"requires_saiyan": false,
			"power_id": "ki_sense",
			"description": "Sense life-force pressure before the fight fully announces itself."
		},
		"ki_blast": {
			"id": "ki_blast",
			"display_name": "Ki Blast",
			"battle_xp_required": 2,
			"requires_saiyan": false,
			"power_id": "ki_blast",
			"description": "Fire a focused burst of combat energy."
		},
		"charged_ki_beam": {
			"id": "charged_ki_beam",
			"display_name": "Charged Ki Beam",
			"battle_xp_required": 5,
			"requires_saiyan": false,
			"power_id": "charged_ki_beam",
			"description": "Channel ki into a heavier beam that can end a fight violently."
		},
		"battle_flight": {
			"id": "battle_flight",
			"display_name": "Battle Flight",
			"battle_xp_required": 8,
			"requires_saiyan": true,
			"power_id": "battle_flight",
			"description": "Use ki control to move through the air during combat."
		},
		"ki_barrier": {
			"id": "ki_barrier",
			"display_name": "Ki Barrier",
			"battle_xp_required": 12,
			"requires_saiyan": true,
			"power_id": "ki_barrier",
			"description": "Wrap yourself in ki pressure to resist catastrophic damage."
		}
	}
func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"ownership": ownership.duplicate(true),
		"wish_generation_contract": wish_generation_contract.duplicate(true),
		"saiyan_contract": saiyan_contract.duplicate(true),
		"affordance_fusion_contracts": affordance_fusion_contracts.duplicate(true),
		"ki_ability_contracts": ki_ability_contracts.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_wish_report": last_wish_report.duplicate(true),
		"last_genetic_report": last_genetic_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "DragonBallsEngine import_state expected Dictionary."
		}

	var ownership_raw: Variant = data.get("ownership", {})
	if typeof(ownership_raw) == TYPE_DICTIONARY:
		ownership = (ownership_raw as Dictionary).duplicate(true)

	var wish_raw: Variant = data.get("wish_generation_contract", {})
	if typeof(wish_raw) == TYPE_DICTIONARY and not (wish_raw as Dictionary).is_empty():
		wish_generation_contract = (wish_raw as Dictionary).duplicate(true)
	else:
		wish_generation_contract = _default_wish_generation_contract()

	var saiyan_raw: Variant = data.get("saiyan_contract", {})
	if typeof(saiyan_raw) == TYPE_DICTIONARY and not (saiyan_raw as Dictionary).is_empty():
		saiyan_contract = (saiyan_raw as Dictionary).duplicate(true)
	else:
		saiyan_contract = _default_saiyan_contract()

	var fusion_raw: Variant = data.get("affordance_fusion_contracts", {})
	if typeof(fusion_raw) == TYPE_DICTIONARY:
		affordance_fusion_contracts = (fusion_raw as Dictionary).duplicate(true)
	else:
		affordance_fusion_contracts = _default_affordance_fusion_contracts()

	var ki_raw: Variant = data.get("ki_ability_contracts", {})
	if typeof(ki_raw) == TYPE_DICTIONARY:
		ki_ability_contracts = (ki_raw as Dictionary).duplicate(true)
	else:
		ki_ability_contracts = _default_ki_ability_contracts()

	var world_raw: Variant = data.get("world_state", {})
	if typeof(world_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_raw as Dictionary))

	var wish_report_raw: Variant = data.get("last_wish_report", {})
	if typeof(wish_report_raw) == TYPE_DICTIONARY:
		last_wish_report = (wish_report_raw as Dictionary).duplicate(true)

	var genetic_report_raw: Variant = data.get("last_genetic_report", {})
	if typeof(genetic_report_raw) == TYPE_DICTIONARY:
		last_genetic_report = (genetic_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.dragonballs_import_report",
		"version": CONTRACT_VERSION,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


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
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))

	if typeof(out.get("wish_ledger", [])) != TYPE_ARRAY:
		out ["wish_ledger"] = []
	if typeof(out.get("genetic_ledger", [])) != TYPE_ARRAY:
		out ["genetic_ledger"] = []
	if typeof(out.get("genetic_profiles", {})) != TYPE_DICTIONARY:
		out ["genetic_profiles"] = {}
	if typeof(out.get("lineage_ripples", {})) != TYPE_DICTIONARY:
		out ["lineage_ripples"] = {}
	if typeof(out.get("ki_battle_xp", {})) != TYPE_DICTIONARY:
		out ["ki_battle_xp"] = {}
	if typeof(out.get("unlocked_ki_abilities", {})) != TYPE_DICTIONARY:
		out ["unlocked_ki_abilities"] = {}

	return out


func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)


func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)


func _era_key() -> String:
	if gs == null or gs.era == null:
		return "modern"
	return str(gs.era.name).strip_edges().to_lower()


func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		return "Person #%d" % int(person.id)
	return full_name


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id < 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var direct: Person = gs.get_or_reactivate_npc_by_id(person_id)
		if direct != null:
			return direct
	if typeof(gs.npcs) == TYPE_ARRAY:
		for npc in gs.npcs:
			if npc != null and int(npc.id) == person_id:
				return npc
	return null
func on_npc_born(payload:= {}) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return {}
	if typeof(payload) != TYPE_DICTIONARY:
		return {}

	var raw_child: Variant = payload.get("npc", null)
	var child: Person = raw_child as Person
	if child == null:
		var child_id: int = int(payload.get("npc_id", payload.get("child_id", -1)))
		child = _person_by_id(child_id)

	if child == null:
		return {}

	var parent_ids: Array = []
	if "parents" in child and typeof(child.parents) == TYPE_ARRAY:
		parent_ids = child.parents.duplicate()

	if parent_ids.size() < 2:
		return {}

	var parent1: Person = _person_by_id(int(parent_ids [0]))
	var parent2: Person = _person_by_id(int(parent_ids [1]))
	if parent1 == null or parent2 == null:
		return {}

	return resolve_child_genetic_affordance_fusion(child, parent1, parent2, {
		"source": "dragonballs_engine.on_npc_born",
		"event_payload": payload.duplicate(true)
	})


func resolve_child_genetic_affordance_fusion(child: Person, parent1: Person, parent2: Person, context: Dictionary = {}) -> Dictionary:
	if child == null or parent1 == null or parent2 == null:
		return {
			"success": false,
			"reason": "Child and both parents are required."
		}

	var parent1_packet: Dictionary = _genetic_packet_for_parent(parent1)
	var parent2_packet: Dictionary = _genetic_packet_for_parent(parent2)

	var first_parent_share: float = clamp(0.5 + randf_range(-0.12, 0.12), 0.33, 0.67)
	var second_parent_share: float = 1.0 - first_parent_share

	var child_slices: Dictionary = {}
	_merge_parent_slices_into_child(child_slices, _safe_dictionary(parent1_packet.get("slices", {})), first_parent_share)
	_merge_parent_slices_into_child(child_slices, _safe_dictionary(parent2_packet.get("slices", {})), second_parent_share)

	child_slices = _normalize_float_dictionary(child_slices)

	var expression_report: Dictionary = _apply_child_genetic_expression(child, child_slices, parent1, parent2, context)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.cross_system_genetic_affordance_fusion_report",
		"version": CONTRACT_VERSION,
		"child_id": int(child.id),
		"child_name": _person_label(child),
		"parent_ids": [int(parent1.id), int(parent2.id)],
		"parent_names": [_person_label(parent1), _person_label(parent2)],
		"parent_share": {
			str(parent1.id): first_parent_share,
			str(parent2.id): second_parent_share
		},
		"child_slices": child_slices.duplicate(true),
		"expression_report": expression_report.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("genetic_profiles", {}))
	profiles [str(child.id)] = report.duplicate(true)
	state ["genetic_profiles"] = profiles

	var ledger: Array = _safe_array(state.get("genetic_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_GENETIC_LEDGER:
		ledger.pop_front()
	state ["genetic_ledger"] = ledger

	_commit_world_state(state)
	last_genetic_report = report.duplicate(true)

	return report.duplicate(true)


func _genetic_packet_for_parent(parent: Person) -> Dictionary:
	var slices: Dictionary = {}
	_add_weighted_slice(slices, "earthling", 1.0)

	if _trait_has(parent, "Saiyan") or "saiyan_bloodline" in _active_power_ids_for_person(parent):
		_add_weighted_slice(slices, "saiyan", 1.0)

	if _is_avatar(parent):
		_add_weighted_slice(slices, "avatar_four_element_affinity", 1.0)
	elif _is_bender(parent):
		for raw_element in _bending_elements_for_person(parent):
			var element: String = str(raw_element).strip_edges().to_lower()
			if element != "":
				_add_weighted_slice(slices, "bending:%s" % element, 0.85)

	for raw_power_id in _active_power_ids_for_person(parent):
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue
		if power_id == "saiyan_bloodline":
			continue
		_add_weighted_slice(slices, "power:%s" % power_id, 0.7)

	if _trait_has(parent, "InfantChaosPolymorph") or "infant_chaos_polymorph" in _active_power_ids_for_person(parent):
		_add_weighted_slice(slices, "power:infant_chaos_polymorph", 1.0)

	_apply_lineage_ripple_slices(parent, slices)

	return {
		"person_id": int(parent.id),
		"person_name": _person_label(parent),
		"slices": _normalize_float_dictionary(_apply_slice_variance(slices)),
		"capability_tags": _capability_tags_for_person(parent),
		"power_ids": _active_power_ids_for_person(parent)
	}


func _merge_parent_slices_into_child(child_slices: Dictionary, parent_slices: Dictionary, parent_share: float) -> void:
	for raw_key in parent_slices.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if key == "":
			continue
		var value: float = max(0.0, float(parent_slices.get(raw_key, 0.0))) * parent_share
		_add_weighted_slice(child_slices, key, value)


func _add_weighted_slice(slices: Dictionary, key: String, amount: float) -> void:
	var clean_key: String = str(key).strip_edges().to_lower()
	if clean_key == "":
		return
	slices [clean_key] = float(slices.get(clean_key, 0.0)) + max(0.0, amount)


func _apply_slice_variance(slices: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in slices.keys():
		var key: String = str(raw_key)
		var variance: float = randf_range(0.78, 1.22)
		out [key] = max(0.0, float(slices.get(raw_key, 0.0)) * variance)
	return out


func _normalize_float_dictionary(data: Dictionary) -> Dictionary:
	var total: float = 0.0
	for raw_key in data.keys():
		total += max(0.0, float(data.get(raw_key, 0.0)))

	if total <= 0.0:
		return {}

	var out: Dictionary = {}
	for raw_key in data.keys():
		var key: String = str(raw_key)
		out [key] = clamp(max(0.0, float(data.get(raw_key, 0.0))) / total, 0.0, 1.0)
	return out


func _apply_child_genetic_expression(child: Person, child_slices: Dictionary, parent1: Person, parent2: Person, context: Dictionary = {}) -> Dictionary:
	var expressions: Array = []
	var contract: Dictionary = get_saiyan_contract()
	var rules: Dictionary = _safe_dictionary(contract.get("lineage_rules", {}))

	var saiyan_share: float = float(child_slices.get("saiyan", 0.0))
	var avatar_share: float = float(child_slices.get("avatar_four_element_affinity", 0.0))
	var polymorph_share: float = float(child_slices.get("power:infant_chaos_polymorph", 0.0))
	var saiyan_threshold: float = float(rules.get("saiyan_expression_share", 0.18))
	var avatar_threshold: float = float(rules.get("avatar_echo_expression_share", 0.16))
	var bending_threshold: float = float(rules.get("bending_expression_share", 0.12))
	var power_threshold: float = float(rules.get("superpower_expression_share", 0.14))

	if saiyan_share >= saiyan_threshold or randf() <= clamp(saiyan_share * 0.65, 0.0, 0.55):
		_append_trait(child, "SaiyanHybrid")
		_append_trait(child, "SaiyanBloodlineCarrier")
		_grant_saiyan_power_to_person(child, "genetic_inheritance", {
			"inherited": true,
			"parent_ids": [int(parent1.id), int(parent2.id)],
			"dna_share": saiyan_share,
			"genetic_context": context.duplicate(true)
		})
		expressions.append("saiyan_bloodline")

	if avatar_share >= avatar_threshold:
		_append_trait(child, "AvatarLineageEcho")
		_append_trait(child, "RareFourElementPotential")
		if randf() <= clamp(avatar_share * 0.42, 0.02, 0.28):
			if str(child.bending_type).strip_edges().to_lower() in ["", "none"]:
				child.bending_type = "avatar"
			_append_trait(child, "FourElementBender")
			expressions.append("rare_four_element_bender")
		else:
			expressions.append("avatar_lineage_echo")

	for raw_key in child_slices.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if not key.begins_with("bending:"):
			continue
		var element: String = key.replace("bending:", "")
		var share: float = float(child_slices.get(raw_key, 0.0))
		if share < bending_threshold:
			continue
		_append_trait(child, "%sBendingLineageCarrier" % element.capitalize())
		if str(child.bending_type).strip_edges().to_lower() in ["", "none"]:
			if randf() <= clamp(share * 0.7, 0.0, 0.45):
				child.bending_type = element
				expressions.append("%s_bender" % element)

	for raw_key in child_slices.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if not key.begins_with("power:"):
			continue
		var power_id: String = key.replace("power:", "")
		var share: float = float(child_slices.get(raw_key, 0.0))
		if share < power_threshold:
			continue
		if randf() <= clamp(share * 0.62, 0.0, 0.5):
			_grant_inherited_power_to_child(child, power_id, share, context)
			expressions.append("power:%s" % power_id)

	if polymorph_share >= power_threshold:
		_append_trait(child, "ChaosPolymorphLineageCarrier")

	if _is_bender(child) and (_trait_has(child, "SaiyanHybrid") or _trait_has(child, "SaiyanBloodlineCarrier")):
		_append_trait(child, "SaiyanBendingHybrid")
		if gs.power_engine != null and gs.power_engine.has_method("resolve_elemental_mutation_contract_packet"):
			gs.power_engine.resolve_elemental_mutation_contract_packet(child, {
				"source": "dragonballs_child_genetic_affordance_fusion",
				"fusion_stack": ["saiyan_bloodline", "bending_affinity", "genetic_affordance"]
			})
		expressions.append("saiyan_bending_hybrid")

	return {
		"expressions": expressions,
		"saiyan_share": saiyan_share,
		"avatar_share": avatar_share,
		"polymorph_share": polymorph_share
	}


func _grant_saiyan_power_to_person(person: Person, source: String, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	_append_trait(person, "Saiyan")
	_append_trait(person, "SuperSaiyanPotential")
	_append_trait(person, "TransformationBoost")
	_append_trait(person, "SaiyanBloodlineAwakened")

	if gs == null or gs.power_engine == null or not gs.power_engine.has_method("grant_power"):
		return {}

	var dna_share: float = clamp(float(context.get("dna_share", 1.0)), 0.05, 1.0)
	var base_level: int = int(round(180000.0 * dna_share))
	var latent_level: int = int(round(4500000.0 * max(0.25, dna_share)))

	return gs.power_engine.grant_power(person, "saiyan_bloodline", source, {
		"origin": source,
		"rarity": "legendary",
		"visibility": "family_known" if bool(context.get("inherited", false)) else "unknown",
		"configured_at_birth": bool(context.get("configured_at_birth", false)),
		"latent_locked": false,
		"inherited": bool(context.get("inherited", false)),
		"base_power_level": base_level,
		"latent_potential": latent_level,
		"superpower_sandbox_config": {
			"schema": "eralife.superpower_sandbox_config",
			"scope": "lineage_seed",
			"origin": source,
			"primary_power": "saiyan_bloodline",
			"rarity": "legendary",
			"saiyan_bloodline": get_saiyan_contract(),
			"inheritance": {
				"mode": "bloodline",
				"dna_share": dna_share
			}
		},
		"family_legacy": {
			"bloodline_id": "saiyan_bloodline",
			"display_name": "Saiyan Bloodline",
			"dna_share": dna_share,
			"origin": source
		}
	})


func _grant_inherited_power_to_child(child: Person, power_id: String, share: float, context: Dictionary = {}) -> Dictionary:
	if child == null or gs == null or gs.power_engine == null:
		return {}
	if not gs.power_engine.has_method("grant_power"):
		return {}

	return gs.power_engine.grant_power(child, power_id, "cross_system_genetic_affordance_fusion", {
		"inherited": true,
		"visibility": "family_known",
		"rarity": "rare",
		"base_power_level": int(round(400.0 + share * 2500.0)),
		"latent_potential": int(round(1600.0 + share * 18000.0)),
		"genetic_share": share,
		"context": context.duplicate(true)
	})


func _apply_lineage_ripple_slices(parent: Person, slices: Dictionary) -> void:
	if parent == null:
		return

	var state: Dictionary = _world_state()
	var lineage_ripples: Dictionary = _safe_dictionary(state.get("lineage_ripples", {}))
	var ripples: Array = _safe_array(lineage_ripples.get(str(parent.id), []))

	for raw_ripple in ripples:
		if typeof(raw_ripple) != TYPE_DICTIONARY:
			continue
		var ripple: Dictionary = raw_ripple
		if not bool(ripple.get("inheritable", true)):
			continue
		var ripple_id: String = str(ripple.get("wish_id", "wish")).strip_edges().to_lower()
		var weight: float = clamp(float(ripple.get("lineage_weight", 0.08)), 0.0, 0.4)
		if ripple_id != "":
			_add_weighted_slice(slices, "wish_ripple:%s" % ripple_id, weight)
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _trait_has(person: Person, trait_name: String) -> bool:
	if person == null:
		return false
	return trait_name in person.traits

func _append_trait(person: Person, trait_name: String) -> void:
	if person == null:
		return
	if trait_name == "":
		return
	if trait_name not in person.traits:
		person.traits.append(trait_name)

func _player_has_time_stone(owner: Person) -> bool:
	if gs == null or owner == null or gs.belongings_engine == null:
		return false
	if not gs.belongings_engine.has_method("has_item_named"):
		return false
	return gs.belongings_engine.has_item_named(owner, "Artifacts", "Time Stone")

func _active_power_ids_for_person(owner: Person) -> Array:
	if gs == null or owner == null or gs.power_engine == null:
		return []
	if not gs.power_engine.has_method("get_active_power_ids"):
		return []
	return _safe_array(gs.power_engine.get_active_power_ids(owner))

func _is_avatar(owner: Person) -> bool:
	if owner == null:
		return false
	var bending_type: String = str(owner.bending_type).strip_edges().to_lower()
	return bending_type == "avatar" or bool(owner.avatar_state_unlocked)

func _is_bender(owner: Person) -> bool:
	if owner == null:
		return false
	var bending_type: String = str(owner.bending_type).strip_edges().to_lower()
	return bending_type != "" and bending_type != "none"

func _bending_elements_for_person(owner: Person) -> Array:
	if owner == null:
		return []
	var bending_type: String = str(owner.bending_type).strip_edges().to_lower()
	if bending_type == "avatar":
		return ["fire", "water", "earth", "air"]
	if bending_type in ["fire", "water", "earth", "air"]:
		return [bending_type]
	return []

func get_available_wishes_for_player(owner: Person) -> Array:
	var out: Array = []
	if gs == null or owner == null:
		return out
	if not player_has_all():
		return out

	var identity: Dictionary = _identity_packet_for_wishes(owner)
	var power_ids: Array = _safe_array(identity.get("power_ids", []))
	var is_saiyan: bool = bool(identity.get("is_saiyan", false))
	var is_bender: bool = bool(identity.get("is_bender", false))
	var is_avatar: bool = bool(identity.get("is_avatar", false))
	var has_time_stone: bool = bool(identity.get("has_time_stone", false))
	var has_any_stone: bool = bool(identity.get("has_any_infinity_stone", false))
	var is_high_status: bool = bool(identity.get("is_high_status", false))
	var has_polymorph: bool = bool(identity.get("has_infant_chaos_polymorph", false))
	var past_wish_ids: Array = _past_wish_ids_for_person(owner)

	out.append({
		"id": "immortality",
		"label": "✨ Become immortal",
		"wish_class": "base"
	})

	out.append({
		"id": "resurrection",
		"label": "💫 Resurrect a fallen soul",
		"wish_class": "base"
	})

	out.append({
		"id": "max_dynasty",
		"label": "👑 Max your dynasty prestige",
		"wish_class": "base"
	})

	if not is_saiyan:
		out.append({
			"id": "saiyan",
			"label": "🔥 Rewrite your blood into Saiyan lineage",
			"wish_class": "bloodline"
		})

	if has_any_stone:
		out.append({
			"id": "all_stones_no_consequence",
			"label": "🌌 Hold all Infinity Stones without consequence",
			"wish_class": "artifact"
		})

	if is_saiyan:
		out.append({
			"id": "unlock_form_beyond_limits",
			"label": "🔥 Unlock a form beyond your current limits",
			"wish_class": "saiyan"
		})

		out.append({
			"id": "awaken_ki_arsenal",
			"label": "💥 Awaken your hidden ki arsenal",
			"wish_class": "saiyan"
		})

	if is_bender:
		var bending_label: String = "🌊 Max your bending mastery"
		if is_avatar:
			bending_label = "🌪 Max all four elements and Avatar State mastery"
		out.append({
			"id": "max_bending_mastery",
			"label": bending_label,
			"wish_class": "bending"
		})

	if has_time_stone:
		out.append({
			"id": "collapse_time_loops",
			"label": "⚡ Collapse time loops into permanent advantage",
			"wish_class": "time"
		})

	if is_high_status:
		out.append({
			"id": "rewrite_lineage_into_legend",
			"label": "👁 Rewrite your lineage into legend",
			"wish_class": "lineage"
		})

	if is_saiyan or not power_ids.is_empty():
		out.append({
			"id": "anchor_power_beyond_consequence",
			"label": "🌌 Anchor your power beyond consequence",
			"wish_class": "power"
		})

	if is_avatar and is_saiyan and has_time_stone:
		out.append({
			"id": "avatar_saiyan_time_overdrive",
			"label": "🕰 Become Avatar Saiyan Time Overdrive",
			"wish_class": "fusion"
		})

	if is_avatar and is_saiyan and has_polymorph:
		out.append({
			"id": "avatar_saiyan_polymorph_overdrive",
			"label": "🧬 Mutate Avatar, Saiyan, and Chaos Polymorph into one living build",
			"wish_class": "fusion"
		})

	if "rewrite_lineage_into_legend" in past_wish_ids and is_saiyan:
		out.append({
			"id": "bind_saiyan_legacy_to_descendants",
			"label": "🩸 Bind your Saiyan legend across future descendants",
			"wish_class": "generation_ripple"
		})

	return out


func _identity_packet_for_wishes(owner: Person) -> Dictionary:
	var power_ids: Array = _active_power_ids_for_person(owner)
	var has_time_stone: bool = _player_has_time_stone(owner)
	var has_any_stone: bool = has_time_stone

	if gs != null and gs.belongings_engine != null and gs.belongings_engine.has_method("has_item_named"):
		has_any_stone = has_any_stone or gs.belongings_engine.has_item_named(owner, "Artifacts", "Power Stone")
		has_any_stone = has_any_stone or gs.belongings_engine.has_item_named(owner, "Artifacts", "Space Stone")
		has_any_stone = has_any_stone or gs.belongings_engine.has_item_named(owner, "Artifacts", "Reality Stone")
		has_any_stone = has_any_stone or gs.belongings_engine.has_item_named(owner, "Artifacts", "Mind Stone")
		has_any_stone = has_any_stone or gs.belongings_engine.has_item_named(owner, "Artifacts", "Soul Stone")

	return {
		"schema": "eralife.dragonballs_identity_wish_input",
		"version": CONTRACT_VERSION,
		"person_id": int(owner.id),
		"power_ids": power_ids.duplicate(true),
		"is_saiyan": _trait_has(owner, "Saiyan") or "saiyan_bloodline" in power_ids,
		"is_bender": _is_bender(owner),
		"is_avatar": _is_avatar(owner),
		"has_time_stone": has_time_stone,
		"has_any_infinity_stone": has_any_stone,
		"is_high_status": int(owner.fame) >= 60 or int(owner.dynasty_prestige) >= 100,
		"has_infant_chaos_polymorph": _trait_has(owner, "InfantChaosPolymorph") or "infant_chaos_polymorph" in power_ids,
		"capability_tags": _capability_tags_for_person(owner),
		"genetics": _genetic_packet_for_parent(owner),
		"past_wishes": _past_wish_ids_for_person(owner),
		"era": _era_key()
	}


func _capability_tags_for_person(owner: Person) -> Array:
	var tags: Array = []
	if owner == null:
		return tags

	if _is_saiyan_person(owner):
		tags.append("saiyan_bloodline")
		tags.append("combat_adaptation")
		tags.append("rage_scaling")
		tags.append("limit_breaker")

	if _is_bender(owner):
		tags.append("bending_affinity")
		for element in _bending_elements_for_person(owner):
			tags.append("bending:%s" % str(element))

	if _is_avatar(owner):
		tags.append("avatar_state")
		tags.append("four_element_channel")

	for power_id in _active_power_ids_for_person(owner):
		tags.append("power:%s" % str(power_id))

	if _player_has_time_stone(owner):
		tags.append("time_dominance")

	return tags


func _is_saiyan_person(owner: Person) -> bool:
	if owner == null:
		return false
	return _trait_has(owner, "Saiyan") or "saiyan_bloodline" in _active_power_ids_for_person(owner)


func _past_wish_ids_for_person(owner: Person) -> Array:
	var out: Array = []
	if owner == null:
		return out

	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("wish_ledger", []))
	for raw_row in ledger:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if int(row.get("person_id", -1)) != int(owner.id):
			continue
		var wish_id: String = str(row.get("wish_id", "")).strip_edges().to_lower()
		if wish_id != "" and wish_id not in out:
			out.append(wish_id)
	return out

func summon_shenron(owner: Person, source_payload: Dictionary = {}) -> Dictionary:
	if gs == null or owner == null:
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "The Dragon Ball runtime is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	if gs.player == null or int(owner.id) != int(gs.player.id):
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "Only the current player flow can summon Shenron through this UI seam.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not player_has_all():
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "You do not possess all 7 Dragon Balls.",
			"popup_footer": "Tap anywhere to continue."
		}

	if gs.scenario_engine == null or not gs.scenario_engine.has_method("queue_external_scenario"):
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "ScenarioEngine.queue_external_scenario() is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	var source_item: Dictionary = _safe_dictionary(source_payload.get("source_item", source_payload))
	var surge_report: Dictionary = _trigger_shenron_reality_surge(owner, source_item)
	_record_shenron_summon_life_echo(owner, source_item, surge_report)
	var scenario: Dictionary = _build_shenron_scenario(owner, source_item)
	if scenario.is_empty():
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "No wishes could be generated from your current identity.",
			"popup_footer": "Tap anywhere to continue."
		}

	scenario ["reality_surge_report"] = surge_report.duplicate(true)

	var queued_result: Variant = gs.scenario_engine.queue_external_scenario(scenario)
	if typeof(queued_result) != TYPE_DICTIONARY:
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "The summon reached the scenario runtime, but it did not return a Dictionary.",
			"popup_footer": "Tap anywhere to continue."
		}

	var result: Dictionary = (queued_result as Dictionary).duplicate(true)
	var summon_frames: Array = _build_shenron_manifestation_frames(owner, result)
	if not summon_frames.is_empty():
		result ["spectator_frames"] = summon_frames
		result ["spectator_final_interactive"] = true
		result ["spectator_frame_seconds"] = 0.82

	return result


func _build_shenron_scenario(owner: Person, source_item: Dictionary = {}) -> Dictionary:
	var wishes: Array = get_available_wishes_for_player(owner)
	if wishes.is_empty():
		return {}

	var choices: Array = []
	for raw_wish in wishes:
		if typeof(raw_wish) != TYPE_DICTIONARY:
			continue

		var wish_row: Dictionary = raw_wish
		var wish_id: String = str(wish_row.get("id", "")).strip_edges().to_lower()
		var label: String = str(wish_row.get("label", "")).strip_edges()
		if wish_id == "" or label == "":
			continue

		var visual: Dictionary = _shenron_wish_visual_packet(wish_id, wish_row)

		choices.append({
			"id": "shenron_%s" % wish_id,
			"wish_id": wish_id,
			"label": label,
			"journal_text": "I called Shenron and considered a wish shaped by my current identity.",
			"resolver_method": "_resolve_dragonball_scenario_choice",
			"theme": "dragonball",
			"button_theme": "dragonball",
			"tone": "mythic",
			"accent": str(visual.get("accent", "#F7B733")),
			"emoji": str(visual.get("emoji", "🐉")),
			"text": str(visual.get("text", "A mythic wish shaped by your current identity.")),
			"overview": str(visual.get("overview", "")),
			"display_kind": str(visual.get("display_kind", "adventure_card"))
		})

	var identity: Dictionary = _identity_packet_for_wishes(owner)
	var memory_summary: String = _wish_memory_summary_for_person(owner)
	var shenron_power: Dictionary = _shenron_power_level_packet(owner, identity)
	var shenron_power_line: String = _format_shenron_power_level(shenron_power)
	var idle_frames: Array = _build_shenron_idle_escalation_frames(owner, shenron_power)

	return {
		"id": "summon_shenron_%d" % int(Time.get_ticks_msec()),
		"source": "dragonballs_engine",
		"resolver_owner": "dragonballs_engine",
		"resolver_method": "_resolve_dragonball_scenario_choice",
		"panel_title": "SHENRON • WISH AUTHORITY",
		"subtitle": "Identity-Read Wishes • Consequence-Bound Reality",
		"accent": "#F7B733",
		"emoji": "🐉",
		"theme": "dragonball",
		"footer_text": "A dragon answers. Speak your wish carefully.",
		"prompt": "The seven Dragon Balls answer your orbit.\n\nA colossal dragon rises through reality itself.\n\n%s\n\nShenron reads your bloodline, powers, artifacts, reputation, era, and past wishes.\n\n%s\n\nWhat wish will you speak?" % [
			shenron_power_line,
			memory_summary
		],
		"category": "dragonball",
		"surface_timing": "immediate",
		"allows_pre_year_age_up_surface": true,
		"blocks_age_up_before_time_resolves": true,
		"wish_generation_contract": wish_generation_contract.duplicate(true),
		"identity_packet": identity.duplicate(true),
		"shenron_power_level_packet": shenron_power.duplicate(true),
		"idle_escalation_frames": idle_frames.duplicate(true),
		"idle_escalation_seconds": 7.6,
		"source_item": source_item.duplicate(true),
		"choices": choices
	}
func _shenron_wish_visual_packet(wish_id: String, wish_row: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(wish_id).strip_edges().to_lower()
	var label: String = str(wish_row.get("label", clean_id.replace("_", " ").capitalize())).strip_edges()

	match clean_id:
		"immortality":
			return {
				"accent": "#7CFFB2",
				"emoji": "♾️",
				"text": "Bind your life force beyond normal mortality.",
				"overview": "A longevity-class wish. Shenron does not simply extend your lifespan; he pressures the rules that decide whether age gets the final word.",
				"display_kind": "adventure_card"
			}
		"resurrection":
			return {
				"accent": "#F4E06D",
				"emoji": "🕊️",
				"text": "Call a soul back through the Dragon Balls.",
				"overview": "A soul-return wish. The world remembers death, but Shenron can force the timeline to make room for someone who was already gone.",
				"display_kind": "adventure_card"
			}
		"max_dynasty":
			return {
				"accent": "#FFB347",
				"emoji": "👑",
				"text": "Push your family name into mythic prestige.",
				"overview": "A dynasty wish. This bends reputation, inheritance pressure, and legacy weight around your bloodline.",
				"display_kind": "adventure_card"
			}
		"saiyan":
			return {
				"accent": "#FFD44D",
				"emoji": "⚡",
				"text": "Ask Shenron to awaken Saiyan potential.",
				"overview": "A bloodline escalation wish. This routes through biology, power identity, combat potential, and future transformation ceilings.",
				"display_kind": "adventure_card"
			}
		"all_stones_no_consequence":
			return {
				"accent": "#B56BFF",
				"emoji": "💎",
				"text": "Demand cosmic relics without the normal consequence chain.",
				"overview": "A cosmic artifact wish. Extremely mythic. Reality may obey, but the wish still leaves a trace in the systems watching impossible objects.",
				"display_kind": "adventure_card"
			}
		"unlock_form_beyond_limits":
			return {
				"accent": "#FF5F8F",
				"emoji": "🔥",
				"text": "Break the ceiling on your next stable form.",
				"overview": "A form-limit wish. Shenron searches your current build for the next legitimate escalation path instead of handing you a random power.",
				"display_kind": "adventure_card"
			}
		"awaken_ki_arsenal":
			return {
				"accent": "#67D7FF",
				"emoji": "🌌",
				"text": "Awaken a deeper combat energy toolkit.",
				"overview": "A ki-system wish. This turns hidden combat affordances into usable runtime abilities.",
				"display_kind": "adventure_card"
			}
		"max_bending_mastery":
			return {
				"accent": "#7EE87E",
				"emoji": "🌊",
				"text": "Force your bending channel toward mastery.",
				"overview": "A bending wish. Shenron reads your element, lineage, Avatar status, training history, and mastery caps before granting anything.",
				"display_kind": "adventure_card"
			}
		"collapse_time_loops":
			return {
				"accent": "#8BE9FD",
				"emoji": "⏳",
				"text": "Collapse unstable time-loop pressure.",
				"overview": "A temporal wish. This only works where your timeline authority is high enough to safely collapse the loop.",
				"display_kind": "adventure_card"
			}
		"rewrite_lineage_into_legend":
			return {
				"accent": "#FFCF70",
				"emoji": "📜",
				"text": "Rewrite your lineage into something history cannot ignore.",
				"overview": "A family myth wish. This binds your name, ancestors, descendants, and reputation into a stronger historical gravity well.",
				"display_kind": "adventure_card"
			}
		"anchor_power_beyond_consequence":
			return {
				"accent": "#FF6AD5",
				"emoji": "🧬",
				"text": "Anchor power so consequence cannot easily strip it away.",
				"overview": "A power-stability wish. Shenron reinforces the identity contract around your abilities instead of merely boosting numbers.",
				"display_kind": "adventure_card"
			}
		"avatar_saiyan_time_overdrive":
			return {
				"accent": "#FFFFFF",
				"emoji": "🌠",
				"text": "Fuse Avatar, Saiyan, and temporal pressure into overdrive.",
				"overview": "A hybrid overdrive wish. This is only surfaced when your identity is already ridiculous enough for Shenron to negotiate with multiple power laws at once.",
				"display_kind": "adventure_card"
			}
		"avatar_saiyan_polymorph_overdrive":
			return {
				"accent": "#D66BFF",
				"emoji": "🌀",
				"text": "Let chaos, Avatar force, and Saiyan biology negotiate a new ceiling.",
				"overview": "A dangerous hybrid wish. This reads polymorph instability as part of the build, not as a bug.",
				"display_kind": "adventure_card"
			}
		"bind_saiyan_legacy_to_descendants":
			return {
				"accent": "#FF9E4D",
				"emoji": "🩸",
				"text": "Bind Saiyan legend into your descendants.",
				"overview": "A bloodline inheritance wish. This turns your power story into family pressure that can echo into future lives.",
				"display_kind": "adventure_card"
			}
		_:
			return {
				"accent": "#F7B733",
				"emoji": "🐉",
				"text": "Speak %s through Shenron's wish authority." % label,
				"overview": "A mythic wish shaped by your current identity packet.",
				"display_kind": "adventure_card"
			}

func _build_shenron_manifestation_frames(owner: Person, queued_result: Dictionary) -> Array:
	var frames: Array = []
	var owner_name: String = _person_label(owner)
	var opps: Array = _safe_array(queued_result.get("opps", []))
	var shenron_power: Dictionary = _safe_dictionary(queued_result.get("shenron_power_level_packet", {}))
	if shenron_power.is_empty():
		shenron_power = _shenron_power_level_packet(owner, _identity_packet_for_wishes(owner))

	var shenron_power_line: String = _format_shenron_power_level(shenron_power)
	var idle_frames: Array = _safe_array(queued_result.get("idle_escalation_frames", []))
	if idle_frames.is_empty():
		idle_frames = _build_shenron_idle_escalation_frames(owner, shenron_power)

	frames.append({
		"panel_title": "SHENRON • SUMMONING",
		"theme": "dragonball",
		"text": "The seven Dragon Balls rise from your belongings and begin orbiting one another.\n\nGolden arcs crawl across the screen.\n\nReality Surge opens first, because the world has to make room before Shenron can speak.",
		"footer_text": "The wish lattice is stabilizing..."
	})

	frames.append({
		"panel_title": "SHENRON • MANIFESTING",
		"theme": "dragonball",
		"text": "A vast silhouette coils through the fracture in the air.\n\n%s\n\nYour powers, bloodline signals, artifacts, behavior, and genetic affordances bend toward one answer.\n\nShenron is not offering random wishes. He is reading %s's current identity." % [
			shenron_power_line,
			owner_name
		],
		"footer_text": "Your identity is being interpreted..."
	})

	frames.append({
		"panel_title": str(queued_result.get("panel_title", "SHENRON • WISH")),
		"theme": "dragonball",
		"text": "“Speak your wish...”\n\n%s" % str(queued_result.get("text", queued_result.get("popup_text", "The dragon waits."))),
		"footer_text": "Choose a wish shaped by your current build.",
		"opps": opps.duplicate(true),
		"idle_escalation_frames": idle_frames.duplicate(true),
		"idle_escalation_seconds": float(queued_result.get("idle_escalation_seconds", 4.6)),
		"shenron_power_level_packet": shenron_power.duplicate(true)
	})

	return frames
func _shenron_power_level_packet(owner: Person, identity: Dictionary = {}) -> Dictionary:
	var resolved_identity: Dictionary = identity.duplicate(true)
	if resolved_identity.is_empty() and owner != null:
		resolved_identity = _identity_packet_for_wishes(owner)

	var identity_weight: float = 0.58
	identity_weight += float(_safe_array(resolved_identity.get("power_ids", [])).size()) * 0.035
	identity_weight += float(_safe_array(resolved_identity.get("capability_tags", [])).size()) * 0.018

	if bool(resolved_identity.get("is_saiyan", false)):
		identity_weight += 0.1
	if bool(resolved_identity.get("is_bender", false)):
		identity_weight += 0.08
	if bool(resolved_identity.get("is_avatar", false)):
		identity_weight += 0.14
	if bool(resolved_identity.get("has_any_infinity_stone", false)):
		identity_weight += 0.18
	if bool(resolved_identity.get("has_time_stone", false)):
		identity_weight += 0.08
	if bool(resolved_identity.get("has_infant_chaos_polymorph", false)):
		identity_weight += 0.12
	if bool(resolved_identity.get("is_high_status", false)):
		identity_weight += 0.06

	identity_weight = clamp(identity_weight, 0.58, 1.0)

	return {
		"schema": "eralife.shenron_power_level_packet",
		"version": CONTRACT_VERSION,
		"entity": "shenron",
		"display_name": "Shenron",
		"power_level_display": "∞",
		"power_class": "Reality-Class Dragon",
		"wish_authority": 7,
		"wish_authority_label": "7/7 Dragon Balls",
		"bounded_reality": true,
		"identity_read_strength": identity_weight,
		"can_read": [
			"bloodline",
			"powers",
			"artifacts",
			"reputation",
			"era",
			"past_wishes",
			"lineage_ripples"
		],
		"limitations": [
			"bounded_wish_contract",
			"identity_anchor_rules",
			"lineage_consequence_rules",
			"reality_surge_stability"
		]
	}
func _format_shenron_power_level(packet: Dictionary) -> String:
	if packet.is_empty():
		return "Shenron Power Level: ∞ • Reality-Class Dragon"

	return "Shenron Power Level: %s • %s • Wish Authority %s • Identity Read %.0f%%" % [
		str(packet.get("power_level_display", "∞")),
		str(packet.get("power_class", "Reality-Class Dragon")),
		str(packet.get("wish_authority_label", "7/7 Dragon Balls")),
		float(packet.get("identity_read_strength", 1.0)) * 100.0
	]
func _build_shenron_idle_escalation_frames(owner: Person, shenron_power: Dictionary = {}) -> Array:
	var owner_name: String = _person_label(owner)
	var power_line: String = _format_shenron_power_level(shenron_power)
	var identity: Dictionary = _identity_packet_for_wishes(owner)

	var frames: Array = [
		{
			"delay_seconds": 6.8,
			"panel_title": "SHENRON • PRESSURE",
			"theme": "dragonball",
			"text": "“You hesitate...”\n\nThe dragon's eyes narrow above the wish lattice.\n\n%s\n\nThe Dragon Balls pulse like seven living suns, waiting for %s to speak." % [
				power_line,
				owner_name
			],
			"footer_text": "Shenron waits, but not patiently."
		},
		{
			"delay_seconds": 8.0,
			"panel_title": "SHENRON • IMPATIENCE",
			"theme": "dragonball",
			"text": "“I grow impatient...”\n\nClouds bend inward. The world holds its breath.\n\nSomewhere in the family tree, future descendants feel a ripple they cannot name.",
			"footer_text": "Wish consequences may echo beyond you."
		},
		{
			"delay_seconds": 9.2,
			"panel_title": "SHENRON • COMMAND",
			"theme": "dragonball",
			"text": "“Speak your wish...”\n\nThe dragon does not blink.\n\nThe choices below are still yours, but the moment is no longer quiet.",
			"footer_text": "Choose before the wish pressure marks this year forever."
		}
	]

	if bool(identity.get("is_avatar", false)):
		frames.append({
			"delay_seconds": 8.6,
			"panel_title": "SHENRON • AVATAR RECOGNITION",
			"theme": "dragonball",
			"text": "“Avatar...”\n\nShenron lowers his head just enough for the elements to notice.\n\n“Your soul already belongs to a cycle. Do not waste a wish pretending you are ordinary.”",
			"footer_text": "The four elements stir under the dragon's voice."
		})

	if bool(identity.get("is_saiyan", false)):
		frames.append({
			"delay_seconds": 8.6,
			"panel_title": "SHENRON • BLOODLINE PRESSURE",
			"theme": "dragonball",
			"text": "“Saiyan blood burns loudly...”\n\nThe wish lattice flickers gold around %s.\n\n“Your hunger for limits is louder than your hesitation.”" % owner_name,
			"footer_text": "Your bloodline is being weighed."
		})

	if bool(identity.get("has_time_stone", false)):
		frames.append({
			"delay_seconds": 8.6,
			"panel_title": "SHENRON • TIME STONE STATIC",
			"theme": "dragonball",
			"text": "“Time bends near you...”\n\nFor one second, Shenron speaks before he opens his mouth.\n\n“Do not confuse delay with control.”",
			"footer_text": "Temporal pressure detected."
		})

	if bool(identity.get("has_infant_chaos_polymorph", false)):
		frames.append({
			"delay_seconds": 8.6,
			"panel_title": "SHENRON • CHAOS READING",
			"theme": "dragonball",
			"text": "“Your form is not settled.”\n\nThe dragon's pupils tighten into burning rings.\n\n“Even your identity is still negotiating with reality.”",
			"footer_text": "Chaos polymorph identity pressure rising."
		})

	if bool(identity.get("is_high_status", false)):
		frames.append({
			"delay_seconds": 8.6,
			"panel_title": "SHENRON • LEGACY PRESSURE",
			"theme": "dragonball",
			"text": "“Your name already has weight.”\n\nThe sky coils around your lineage.\n\n“Wish carefully. Great houses do not echo quietly.”",
			"footer_text": "Dynasty consequence field active."
		})

	frames.append({
		"delay_seconds": 10.4,
		"panel_title": "SHENRON • FINAL WARNING",
		"theme": "dragonball",
		"text": "“I will ask again...”\n\nThe Dragon Balls flare.\n\n“Speak. Your. Wish.”",
		"footer_text": "The pressure loops until a wish is chosen.",
		"loop_to_index": 0
	})

	return frames

func _trigger_shenron_reality_surge(owner: Person, source_item: Dictionary = {}) -> Dictionary:
	if gs == null or owner == null:
		return {}
	if not ("reality_surge_engine" in gs) or gs.reality_surge_engine == null:
		return {}
	if not gs.reality_surge_engine.has_method("trigger_surge"):
		return {}

	var contract_id: String = "dragonballs.shenron_summon.reality_surge"
	if gs.reality_surge_engine.has_method("register_surge_contract"):
		gs.reality_surge_engine.register_surge_contract(_shenron_reality_surge_contract(contract_id))

	var event_payload: Dictionary = {
		"event_name": "dragonballs.shenron_summon",
		"domain": "dragonball",
		"source": "dragonballs_engine",
		"source_item": source_item.duplicate(true),
		"salience": 100.0,
		"screen_damage": "mythic",
		"time_dilation": 0.42,
		"audio_muffle": 1.0
	}

	var result: Variant = gs.reality_surge_engine.trigger_surge(contract_id, owner, event_payload, {
		"source": "dragonballs_engine.summon_shenron",
		"force": true,
		"duplicate_window_ms": 2200
	})

	if typeof(result) == TYPE_DICTIONARY:
		return (result as Dictionary).duplicate(true)

	return {}


func _shenron_reality_surge_contract(contract_id: String) -> Dictionary:
	return {
		"schema": "eralife.reality_surge_contract",
		"version": 2,
		"id": contract_id,
		"domain": "dragonball",
		"display_name": "Shenron Summon Reality Surge",
		"trigger": {
			"event": "dragonballs.shenron_summon",
			"filters": {
				"domain": "dragonball"
			},
			"threshold": {
				"salience_min": 80.0
			}
		},
		"surge_profile": {
			"type": ["wish_authority", "mythic_manifestation", "dragon_summon"],
			"intensity": 1.0
		},
		"visual_layer": {
			"theme_resolver": "dragonball_wish_resolver",
			"shader_profile": "shenron_manifestation",
			"screen_damage": "mythic",
			"screen_fracture": true,
			"distortion": true,
			"particles": true
		},
		"perception_layer": {
			"time_dilation": 0.42,
			"input_lock_ms": 1800,
			"camera_weight": 1.0,
			"audio_muffle": 1.0,
		},
		"reward_manifestation": {},
		"stat_echo": {},
		"stability": {
			"instability_gain": 0.22,
			"mutation_chance": 0.018,
		}
	}

func _resolve_dragonball_scenario_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {
			"success": false,
			"popup_title": "Shenron",
			"popup_text": "The wish runtime lost its anchor.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var wish_id: String = str(choice.get("wish_id", choice.get("id", ""))).strip_edges().to_lower()
	if wish_id.begins_with("shenron_"):
		wish_id = wish_id.replace("shenron_", "")

	var wish_result: Dictionary = make_wish(wish_id, {
		"source": "dragonballs_engine.shenron_staged_wish",
		"defer_scatter": true,
		"defer_wish_side_effects": true,
		"renderer_first": true
	})
	var result_text: String = str(wish_result.get("text", "")).strip_edges()
	if result_text == "":
		result_text = "The dragon watched you, but reality did not move."

	var life_diary_text: String = str(wish_result.get("life_diary_text", "")).strip_edges()
	if life_diary_text == "":
		life_diary_text = "I asked Shenron for %s." % wish_id.replace("_", " ")

	wish_result ["life_diary_text"] = life_diary_text
	_append_unique_memory(actor, "I summoned Shenron and chose a wish from the shape of my life.")

	if not bool(wish_result.get("success", result_text != "")):
		return {
			"success": false,
			"type": "scenario_commit_complete",
			"text": result_text,
			"life_diary_text": life_diary_text,
			"log_to_diary": true,
			"popup_title": "Shenron",
			"popup_text": result_text,
			"popup_footer": "The Dragon Balls dim, but the timeline remembers.",
			"footer_text": "The wish failed to bind.",
			"wish_report": wish_result.duplicate(true),
			"theme": "dragonball",
			"accent": str(choice.get("accent", "#F7B733")),
			"emoji": str(choice.get("emoji", "🐉")),
			"opps": []
		}

	_queue_shenron_departure_choice(actor, wish_id, wish_result, choice)

	return {
		"success": true,
		"type": "scenario_prompt",
		"schema": "eralife.shenron_staged_wish_grant_prompt",
		"version": CONTRACT_VERSION,
		"panel_title": "SHENRON • WISH SPOKEN",
		"subtitle": "Bounded Reality Grant • Departure Pending",
		"accent": str(choice.get("accent", "#F7B733")),
		"emoji": str(choice.get("emoji", "🐉")),
		"theme": "dragonball",
		"text": "You speak your wish.\n\nWish: %s\n\nShenron's eyes burn brighter as the Dragon Balls hold their orbit." % wish_id.replace("_", " ").capitalize(),
		"footer_text": "The dragon is deciding how reality will obey.",
		"wish_id": wish_id,
		"wish_report": wish_result.duplicate(true),
		"spectator_frames": _build_shenron_wish_grant_frames(actor, wish_id, wish_result, choice),
		"spectator_final_interactive": true,
		"spectator_frame_seconds": 1.0,
		"opps": []
	}
func _queue_shenron_departure_choice(actor: Person, wish_id: String, wish_result: Dictionary, source_choice: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var goodbye_label: String = "Say goodbye to Shenron"
	var timeout_label: String = "Let Shenron leave"

	var departure_scenario: Dictionary = {
		"id": "shenron_departure_%d" % int(Time.get_ticks_msec()),
		"source": "dragonballs_engine",
		"resolver_owner": "dragonballs_engine",
		"resolver_method": "_resolve_dragonball_departure_choice",
		"category": "dragonball",
		"wish_id": str(wish_id).strip_edges().to_lower(),
		"wish_report": wish_result.duplicate(true),
		"source_choice": source_choice.duplicate(true)
	}

	gs.scenario_state ["current_bundle"] = [departure_scenario]
	gs.scenario_state ["current_bundle_index"] = 0
	gs.scenario_state ["pending_type"] = "scenario_prompt"
	gs.scenario_state ["pending_text"] = "Shenron is waiting long enough for one final word."
	gs.scenario_state ["pending_panel_title"] = "SHENRON • DEPARTURE"
	gs.scenario_state ["pending_footer_text"] = "Say goodbye before the dragon leaves."
	gs.scenario_state ["pending_subtitle"] = "Relationship Echo • Timed Departure"
	gs.scenario_state ["pending_accent"] = str(source_choice.get("accent", "#F7B733"))
	gs.scenario_state ["pending_emoji"] = str(source_choice.get("emoji", "🐉"))
	gs.scenario_state ["pending_theme"] = "dragonball"
	gs.scenario_state ["pending_combat_ui"] = {}
	gs.scenario_state ["pending_surface_timing"] = "immediate"
	gs.scenario_state ["pending_allows_pre_year_age_up_surface"] = true
	gs.scenario_state ["pending_blocks_age_up_before_time_resolves"] = true
	gs.scenario_state ["pending_source"] = "dragonballs_engine"
	gs.scenario_state ["pending_options"] = [
		{
			"label": goodbye_label,
			"theme": "dragonball",
			"button_theme": "dragonball",
			"tone": "warm",
			"accent": str(source_choice.get("accent", "#F7B733")),
			"emoji": "👋",
			"tooltip": "Acknowledge Shenron before he scatters the Dragon Balls."
		}
	]
	gs.scenario_state ["pending_lookup"] = {
		goodbye_label: {
			"id": "shenron_goodbye",
			"label": goodbye_label,
			"wish_id": str(wish_id).strip_edges().to_lower(),
			"resolver_method": "_resolve_dragonball_departure_choice",
			"said_goodbye": true,
			"wish_report": wish_result.duplicate(true),
			"source_choice": source_choice.duplicate(true)
		},
		timeout_label: {
			"id": "shenron_departure_timeout",
			"label": timeout_label,
			"wish_id": str(wish_id).strip_edges().to_lower(),
			"resolver_method": "_resolve_dragonball_departure_choice",
			"said_goodbye": false,
			"wish_report": wish_result.duplicate(true),
			"source_choice": source_choice.duplicate(true),
		}
	}


func _build_shenron_wish_grant_frames(actor: Person, wish_id: String, wish_result: Dictionary, source_choice: Dictionary = {}) -> Array:
	var actor_name: String = _person_label(actor)
	var clean_wish: String = str(wish_id).strip_edges().to_lower()
	var wish_label: String = clean_wish.replace("_", " ").capitalize()
	var result_text: String = str(wish_result.get("text", "")).strip_edges()
	if result_text == "":
		result_text = "Reality bends, but Shenron offers no explanation."

	var accent: String = str(source_choice.get("accent", "#F7B733"))
	var emoji: String = str(source_choice.get("emoji", "🐉"))

	return [
		{
			"panel_title": "SHENRON • WISH SPOKEN",
			"theme": "dragonball",
			"accent": accent,
			"emoji": emoji,
			"hide_actions": true,
			"delay_seconds": 1.55,
			"text": "%s speaks the wish.\n\nWish: %s\n\nThe buttons vanish. The Dragon Balls do not scatter yet. They burn in place, waiting for Shenron's verdict." % [
				actor_name,
				wish_label
			],
			"footer_text": "The wish has entered Shenron's authority."
		},
		{
			"panel_title": "SHENRON • READING REALITY",
			"theme": "dragonball",
			"accent": accent,
			"emoji": emoji,
			"hide_actions": true,
			"delay_seconds": 2.35,
			"text": "%s\n\nShenron's eyes sweep through your bloodline, powers, inventory, consequences, and the parts of the timeline that pretend they are not listening." % _shenron_processing_line(clean_wish),
			"footer_text": "Reality is being inspected, not skipped."
		},
		{
			"panel_title": "SHENRON • GRANTING",
			"theme": "dragonball",
			"accent": accent,
			"emoji": emoji,
			"hide_actions": true,
			"delay_seconds": 2.65,
			"text": "“Your wish has been granted.”\n\n%s" % result_text,
			"footer_text": "The Dragon Balls remain suspended for one last breath."
		},
		{
			"panel_title": "SHENRON • DEPARTURE NOTICE",
			"theme": "dragonball",
			"accent": accent,
			"emoji": emoji,
			"hide_actions": true,
			"delay_seconds": 2.15,
			"text": "%s\n\nThe dragon coils upward as the Dragon Balls begin to tremble." % _shenron_vacation_line(clean_wish),
			"footer_text": "Shenron is almost done with you."
		},
		{
			"panel_title": "SHENRON • FINAL WORD",
			"theme": "dragonball",
			"accent": accent,
			"emoji": emoji,
			"delay_seconds": 1.0,
			"auto_emit_after_seconds": 6.5,
			"auto_emit_label": "Let Shenron leave",
			"text": "Shenron pauses before leaving.\n\nFor a moment, the dragon actually waits for you.\n\nYou can say goodbye before the Dragon Balls scatter.",
			"footer_text": "Timed choice: say goodbye before Shenron leaves.",
			"opps": [
				{
					"label": "Say goodbye to Shenron",
					"theme": "dragonball",
					"button_theme": "dragonball",
					"tone": "warm",
					"accent": accent,
					"emoji": "👋",
					"tooltip": "Build a small relationship echo with Shenron."
				}
			],
			"idle_escalation_seconds": 6.5,
			"idle_escalation_frames": [
				{
					"delay_seconds": 6.5,
					"panel_title": "SHENRON • STILL WAITING",
					"theme": "dragonball",
					"text": "“I am still here.”\n\nThe dragon's stare gets heavier.\n\nThis is either very respectful silence or you forgot Shenron was on the screen.",
					"footer_text": "The Dragon Balls are seconds from scattering."
				}
			]
		}
	]


func _shenron_processing_line(wish_id: String) -> String:
	var lines: Array = [
		"“Let's see...”",
		"“Hmm. This one has weight.”",
		"“Let me look through the shape of your life.”",
		"“A wish is not a button. It is a wound in reality with manners.”",
		"“Interesting. You ask boldly.”"
	]

	match str(wish_id).strip_edges().to_lower():
		"immortality":
			lines.append("“You wish to outlive endings. Ambitious.”")
		"resurrection":
			lines.append("“You call toward the dead. Speak carefully around souls.”")
		"saiyan":
			lines.append("“Your blood wants thunder. I can hear it.”")
		"all_stones_no_consequence":
			lines.append("“You ask for impossible stones and no bill. Cute.”")
		"max_bending_mastery":
			lines.append("“The elements are already listening.”")
		"collapse_time_loops":
			lines.append("“Time again? Mortals discover one loop and become unbearable.”")
		"avatar_saiyan_time_overdrive", "avatar_saiyan_polymorph_overdrive":
			lines.append("“This is not a wish. This is several power systems arguing in a trench coat.”")

	return str(lines [randi() % lines.size()])


func _shenron_vacation_line(wish_id: String) -> String:
	var lines: Array = [
		"“I am going on vacation now.”",
		"“Do not summon me again for at least five dramatic minutes.”",
		"“I am returning to my sky nap.”",
		"“The dragon is clocking out.”",
		"“If anyone asks, I was never here.”",
		"“Next time, bring snacks. Reality work is exhausting.”"
	]

	match str(wish_id).strip_edges().to_lower():
		"all_stones_no_consequence":
			lines.append("“After that wish, I deserve a beach, a smoothie, and legal immunity.”")
		"avatar_saiyan_polymorph_overdrive":
			lines.append("“I am absolutely telling the other dragons about this nonsense.”")
		"collapse_time_loops":
			lines.append("“If you loop this goodbye, I will know.”")
		"rewrite_lineage_into_legend":
			lines.append("“Your descendants are going to make this everyone else's problem.”")

	return str(lines [randi() % lines.size()])
func _resolve_dragonball_departure_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {
			"success": false,
			"type": "scenario_commit_complete",
			"text": "Shenron left, but the departure runtime lost its anchor.",
			"popup_title": "Shenron",
			"popup_text": "Shenron left, but the departure runtime lost its anchor.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var wish_id: String = str(choice.get("wish_id", scenario.get("wish_id", ""))).strip_edges().to_lower()
	if wish_id == "":
		wish_id = "unknown_wish"

	var wish_report: Dictionary = _safe_dictionary(choice.get("wish_report", scenario.get("wish_report", {})))
	var said_goodbye: bool = bool(choice.get("said_goodbye", false))

	return _finalize_deferred_shenron_departure(actor, wish_id, wish_report, said_goodbye)


func _finalize_deferred_shenron_departure(actor: Person, wish_id: String, wish_report: Dictionary, said_goodbye: bool = false) -> Dictionary:
	var clean_wish: String = str(wish_id).strip_edges().to_lower()
	if clean_wish == "":
		clean_wish = "unknown_wish"

	var result_text: String = str(wish_report.get("text", "")).strip_edges()
	if result_text == "":
		result_text = "Shenron granted the wish, and the sky began to breathe again."

	var life_diary_text: String = str(wish_report.get("life_diary_text", "")).strip_edges()
	if life_diary_text == "":
		life_diary_text = "I asked Shenron for %s. %s" % [
			clean_wish.replace("_", " "),
			result_text
		]

	var goodbye_line: String = ""
	if said_goodbye:
		_adjust_shenron_relationship(actor, 3, {
			"source": "dragonballs_engine",
			"event_type": "shenron_goodbye",
			"wish_id": clean_wish,
			"renderer_first": true
		})
		goodbye_line = "\n\nBefore he left, I said goodbye to Shenron. The dragon seemed to remember the respect."
	else:
		goodbye_line = "\n\nShenron left before I said anything else."

	life_diary_text += goodbye_line

	var scatter_report: Dictionary = _dragonball_scatter_preview_report(actor, clean_wish, wish_report)
	var scatter_runtime_payload: Dictionary = {
		"schema": "eralife.deferred_dragonball_scatter_runtime_payload",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"wish_id": clean_wish,
		"wish_report": wish_report.duplicate(true),
		"runtime_key": "scatter:%d:%s:%d" % [
			int(actor.id) if actor != null else -1,
			clean_wish,
			int(Time.get_ticks_msec())
		],
		"source": "dragonballs_engine.shenron_departure_renderer_first",
		"renderer_first": true,
		"visual_must_not_wait_for_runtime": true,
	}

	var scatter_animation: Dictionary = _dragonball_scatter_animation_packet(actor, scatter_report)
	scatter_animation ["deferred_runtime_payload"] = scatter_runtime_payload.duplicate(true)
	scatter_animation ["renderer_first"] = true
	scatter_animation ["visual_must_not_wait_for_runtime"] = true
	scatter_animation ["suppress_toast"] = false
	scatter_animation ["consume_result_popup"] = true
	scatter_animation ["duration_seconds"] = 2.65

	wish_report ["dragonball_scatter_report"] = scatter_report.duplicate(true)
	wish_report ["dragonball_scatter_animation"] = scatter_animation.duplicate(true)
	wish_report ["dragonball_scatter_pending"] = true
	wish_report ["dragonball_scatter_deferred"] = true
	wish_report ["dragonball_scatter_renderer_first"] = true

	var popup_text: String = "%s\n\nThe Dragon Balls burst from your belongings and scatter back across the world." % result_text
	if said_goodbye:
		popup_text += "\n\nShenron heard your goodbye before vanishing."

	return {
		"success": true,
		"type": "scenario_commit_complete",
		"text": popup_text,
		"life_diary_text": life_diary_text,
		"log_to_diary": true,
		"popup_title": "Shenron",
		"popup_text": popup_text,
		"popup_footer": "The wish has been granted. The Dragon Balls are scattering back across the world.",
		"footer_text": "The dragon has departed.",
		"theme": "dragonball",
		"accent": "#F7B733",
		"emoji": "🐉",
		"wish_id": clean_wish,
		"wish_report": wish_report.duplicate(true),
		"dragonball_scatter_report": scatter_report.duplicate(true),
		"dragonball_scatter_animation": scatter_animation.duplicate(true),
		"deferred_dragonball_scatter_runtime": scatter_runtime_payload.duplicate(true),
		"renderer_first": true,
		"visual_must_not_wait_for_runtime": true,
		"opps": []
	}
func _dragonball_scatter_preview_report(actor: Person, wish_id: String, _report: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var actor_id: int = int(actor.id)
	var stars: Array = []

	if ownership.has(actor_id):
		stars = _safe_array(ownership.get(actor_id, [])).duplicate(true)
	elif ownership.has(str(actor_id)):
		stars = _safe_array(ownership.get(str(actor_id), [])).duplicate(true)

	if stars.is_empty():
		stars = [1, 2, 3, 4, 5, 6, 7]

	return {
		"success": true,
		"preview_only": true,
		"schema": "eralife.dragonballs_scatter_report",
		"version": CONTRACT_VERSION,
		"person_id": actor_id,
		"person_name": _person_label(actor),
		"wish_id": str(wish_id).strip_edges().to_lower(),
		"stars": stars.duplicate(true),
		"text": "The Dragon Balls scattered back across the world.",
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func finalize_deferred_dragonball_scatter(payload: Dictionary = {}) -> Dictionary:
	if gs == null or typeof(payload) != TYPE_DICTIONARY:
		return {}

	var runtime_key: String = str(payload.get("runtime_key", "")).strip_edges()
	var state: Dictionary = _world_state()
	var finalized: Dictionary = _safe_dictionary(state.get("finalized_deferred_scatter", {}))

	if runtime_key != "" and finalized.has(runtime_key):
		return _safe_dictionary(finalized.get(runtime_key, {}))

	if runtime_key != "":
		finalized [runtime_key] = {
			"success": false,
			"pending": true,
			"runtime_key": runtime_key,
			"reserved_at_ms": int(Time.get_ticks_msec())
		}
		state ["finalized_deferred_scatter"] = finalized
		_commit_world_state(state)

	var actor_id: int = int(payload.get("actor_id", -1))
	var actor: Person = _person_by_id(actor_id)
	if actor == null:
		return {}

	var wish_id: String = str(payload.get("wish_id", "unknown_wish")).strip_edges().to_lower()
	var wish_report: Dictionary = _safe_dictionary(payload.get("wish_report", {}))
	var report: Dictionary = _scatter_dragon_balls_after_wish(actor, wish_id, wish_report)

	if runtime_key != "":
		state = _world_state()
		finalized = _safe_dictionary(state.get("finalized_deferred_scatter", {}))
		finalized [runtime_key] = report.duplicate(true)
		state ["finalized_deferred_scatter"] = finalized
		_commit_world_state(state)

	return report.duplicate(true)

func _adjust_shenron_relationship(actor: Person, amount: int = 1, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var state: Dictionary = _world_state()
	var relationships: Dictionary = _safe_dictionary(state.get("shenron_relationships", {}))
	var key: String = str(int(actor.id))
	var row: Dictionary = _safe_dictionary(relationships.get(key, {}))

	row ["person_id"] = int(actor.id)
	row ["person_name"] = _person_label(actor)
	row ["relationship"] = clamp(int(row.get("relationship", 0)) + int(amount), -100, 100)
	row ["last_changed_year"] = _current_year()
	row ["last_changed_ms"] = int(Time.get_ticks_msec())

	var ledger: Array = _safe_array(row.get("ledger", []))
	ledger.append({
		"amount": int(amount),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	while ledger.size() > 40:
		ledger.pop_front()
	row ["ledger"] = ledger

	relationships [key] = row
	state ["shenron_relationships"] = relationships
	state ["last_shenron_relationship_report"] = row.duplicate(true)
	_commit_world_state(state)

	return row.duplicate(true)


func _wish_unlock_form_beyond_limits() -> Dictionary:

	var p: Person = gs.player
	if not _is_saiyan_person(p):
		return _wish_saiyan()
	var next_form: Dictionary = _next_saiyan_form_to_unlock(p)
	if next_form.is_empty():
		return _wish_result(true, "unlock_form_beyond_limits", "🔥 Shenron found no higher stable Saiyan form left in the current contract.")
	var form_id: String = str(next_form.get("id", "")).strip_edges().to_lower()
	var display_name: String = str(next_form.get("display_name", form_id.capitalize()))
	var unlocked_trait: String = str(next_form.get("trait_unlocked", ""))
	var active_trait: String = str(next_form.get("trait_active", ""))
	_append_trait(p, unlocked_trait)
	_append_trait(p, active_trait)
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"🔥 %s shattered a previous ceiling and awakened %s through Shenron's blessing!" % [_person_label(p), display_name],
			{
				"npc_id": p.id,
				"personally_relevant": true,
				"category": "dragonball",
				"event_name": ActionEventTypes.WISH_MADE,
				"source": "dragonballs_engine"
			}
		)
	return _wish_result(true, "unlock_form_beyond_limits", "🔥 Shenron forced your body beyond its previous ceiling.\n\nNew form unlocked: %s." % display_name, {
		"form_id": form_id,
		"form": next_form.duplicate(true),
		"inheritable": true,
		"lineage_weight": 0.12
	})

func _wish_awaken_ki_arsenal() -> Dictionary:

	var p: Person = gs.player
	var unlocked: Array = []
	for raw_key in ki_ability_contracts.keys():
		var ability: Dictionary = _safe_dictionary(ki_ability_contracts.get(raw_key, {}))
		if ability.is_empty():
			continue
		var power_id: String = str(ability.get("power_id", ability.get("id", ""))).strip_edges().to_lower()
		if power_id == "":
			continue
		if bool(ability.get("requires_saiyan", false)) and not _is_saiyan_person(p):
			continue
		_grant_inherited_power_to_child(p, power_id, 1.0, {
			"source": "dragonball_ki_arsenal_wish"
		})
		unlocked.append(str(ability.get("display_name", power_id.capitalize())))
	return _wish_result(true, "awaken_ki_arsenal", "💥 Shenron opened your ki arsenal.\n\nUnlocked: %s." % ", ".join(unlocked), {
		"unlocked_ki": unlocked.duplicate(true),
		"inheritable": true,
		"lineage_weight": 0.09
	})

func _wish_max_bending_mastery() -> Dictionary:

	var p: Person = gs.player
	if not _is_bender(p):
		return _wish_result(false, "max_bending_mastery", "🌊 Shenron searched your spirit, but there is no bending lineage to elevate.")
	var elements: Array = _bending_elements_for_person(p)
	if elements.is_empty():
		return _wish_result(false, "max_bending_mastery", "🌊 Shenron found no stable bending channel to maximize.")
	for raw_element in elements:
		var element: String = str(raw_element).strip_edges().to_lower()
		if element == "":
			continue
		p.bending_mastery [element] = max(int(p.bending_mastery.get(element, 0)), 18)
	p.bending_skill_points = max(int(p.bending_skill_points), 160)
	if _is_avatar(p):
		p.avatar_state_unlocked = true
	if gs.capability_graph_engine != null and gs.capability_graph_engine.has_method("refresh_bending_capabilities"):
		gs.capability_graph_engine.refresh_bending_capabilities(p)
	if gs.power_engine != null and gs.power_engine.has_method("resolve_elemental_mutation_contract_packet"):
		gs.power_engine.resolve_elemental_mutation_contract_packet(p, {
			"source": "dragonball_max_bending_wish"
		})
	return _wish_result(true, "max_bending_mastery", "🌪 Shenron maxed your bending path.\n\nMastery, skill points, level-up pressure, and elemental mutation affordances surged upward at once.", {
		"inheritable": true,
		"lineage_weight": 0.1
	})

func _wish_collapse_time_loops() -> Dictionary:

	var p: Person = gs.player
	if not _player_has_time_stone(p):
		return _wish_result(false, "collapse_time_loops", "⚡ Shenron cannot collapse loops you do not yet hold authority over.")
	_append_trait(p, "TimeLoopCollapseAdvantage")
	_append_trait(p, "PermanentTimeAdvantage")
	return _wish_result(true, "collapse_time_loops", "⚡ Shenron collapsed your active time loops into permanent advantage.\n\nTemporal hesitation now favors you.", {
		"inheritable": true,
		"lineage_weight": 0.08
	})

func _wish_rewrite_lineage_into_legend() -> Dictionary:

	var p: Person = gs.player
	p.dynasty_prestige = max(int(p.dynasty_prestige), 999)
	p.fame = max(int(p.fame), 90)
	_append_trait(p, "LegendaryLineage")
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"👁 The lineage of %s was rewritten into legend by a wish that history will never fully explain." % _person_label(p),
			{
				"npc_id": p.id,
				"personally_relevant": true,
				"category": "dragonball",
				"event_name": ActionEventTypes.WISH_MADE,
				"source": "dragonballs_engine"
			}
		)
	return _wish_result(true, "rewrite_lineage_into_legend", "👁 Your lineage has been rewritten into legend.\n\nPrestige, fame, and historical gravity now orbit your family name.", {
		"inheritable": true,
		"lineage_weight": 0.18
	})

func _wish_anchor_power_beyond_consequence() -> Dictionary:

	var p: Person = gs.player
	_append_trait(p, "NoCosmicConsequence")
	_append_trait(p, "IdentityAnchoredPower")
	_append_trait(p, "ConsequenceShieldedPower")
	return _wish_result(true, "anchor_power_beyond_consequence", "🌌 Shenron anchored your power beyond consequence.\n\nYour build now carries a deeper shield against cosmic backlash.", {
		"inheritable": true,
		"lineage_weight": 0.12
	})

func _wish_avatar_saiyan_time_overdrive() -> Dictionary:

	var p: Person = gs.player
	_append_trait(p, "AvatarSaiyanTimeOverdrive")
	_append_trait(p, "SSJ2Unlocked")
	_append_trait(p, "SSJ2Active")
	_append_trait(p, "TimeLoopCollapseAdvantage")
	_append_trait(p, "NoCosmicConsequence")
	if gs.power_engine != null and gs.power_engine.has_method("resolve_elemental_mutation_contract_packet"):
		gs.power_engine.resolve_elemental_mutation_contract_packet(p, {
			"source": "avatar_saiyan_time_overdrive",
			"fusion_contract": _safe_dictionary(affordance_fusion_contracts.get("avatar_saiyan_time_overdrive", {}))
		})
	return _wish_result(true, "avatar_saiyan_time_overdrive", "🕰 Shenron fused Avatar State, Saiyan escalation, and temporal dominance into a single overdrive state.\n\nReality Overdrive now exists in your body as a mythic affordance.", {
		"fusion_contract_id": "avatar_saiyan_time_overdrive",
		"inheritable": true,
		"lineage_weight": 0.2
	})

func _wish_avatar_saiyan_polymorph_overdrive() -> Dictionary:

	var p: Person = gs.player
	_append_trait(p, "AvatarSaiyanPolymorphOverdrive")
	_append_trait(p, "ChaosElementalZenkai")
	_append_trait(p, "SaiyanBendingHybrid")
	_append_trait(p, "RealityMutationBody")
	if gs.power_engine != null and gs.power_engine.has_method("resolve_elemental_mutation_contract_packet"):
		gs.power_engine.resolve_elemental_mutation_contract_packet(p, {
			"source": "avatar_saiyan_polymorph_overdrive",
			"fusion_contract": _safe_dictionary(affordance_fusion_contracts.get("avatar_saiyan_polymorph_overdrive", {})),
			"fusion_stack": ["avatar_state", "saiyan_bloodline", "infant_chaos_polymorph"]
		})
	return _wish_result(true, "avatar_saiyan_polymorph_overdrive", "🧬 Shenron mutated Avatar State, Saiyan biology, and Chaos Polymorph into one living build.\n\nYour abilities can now recompose around life stage, form activation, bending state, and rage pressure.", {
		"fusion_contract_id": "avatar_saiyan_polymorph_overdrive",
		"inheritable": true,
		"lineage_weight": 0.24
	})

func _wish_bind_saiyan_legacy_to_descendants() -> Dictionary:

	var p: Person = gs.player
	_append_trait(p, "GenerationalSaiyanLegend")
	_append_trait(p, "DescendantLimitBreakerSeed")
	return _wish_result(true, "bind_saiyan_legacy_to_descendants", "🩸 Shenron bound your Saiyan legend into the family tree.\n\nFuture descendants may express stronger Saiyan slices even when the bloodline dilutes.", {
		"inheritable": true,
		"lineage_weight": 0.28
	})



var BALLS = {
	1: { "name": "1-Star Dragon Ball"},
	2: { "name": "2-Star Dragon Ball"},
	3: { "name": "3-Star Dragon Ball"},
	4: { "name": "4-Star Dragon Ball"},
	5: { "name": "5-Star Dragon Ball"},
	6: { "name": "6-Star Dragon Ball"},
	7: { "name": "7-Star Dragon Ball"}
}


var ownership = {}




func yearly_chance(_payload:= {}) -> void:
	var payload: Dictionary = (
		_payload as Dictionary
		if typeof(_payload) == TYPE_DICTIONARY
		else {}
	)

	if (
		bool(
			payload.get(
				"runtime_managed",
				false
			)
		)
		and str(
			payload.get(
				"runtime_owner",
				""
			)
		).strip_edges() == "age_up_runtime"
	):
		return

	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return
	if typeof(gs.npcs) != TYPE_ARRAY:
		return

	for npc in gs.npcs:
		if npc == null:
			continue
		if not npc.alive:
			continue
		if randi() % 40000 == 0:
			_spawn_ball_randomly(npc)



func _spawn_ball_randomly(npc):
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return
	var available = _get_unclaimed_balls()
	if available.size() == 0:
		return

	var pick = available [randi() % available.size()]
	_give_ball(npc, pick)

func _get_unclaimed_balls():
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return
	var all = BALLS.keys()
	var claimed = []
	for arr in ownership.values():
		for b in arr:
			claimed.append(b)

	var result = []
	for n in all:
		if n not in claimed:
			result.append(n)
	return result
func is_ball_shop_available(star: int) -> bool:
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return false
	return star in _get_unclaimed_balls()


func grant_shop_ball(npc: Person, star: int) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return { "success": false, "text": "Dragon Balls are not active in this reality."}

	if npc == null:
		return { "success": false, "text": "No valid buyer was selected."}

	if not BALLS.has(star):
		return { "success": false, "text": "That Dragon Ball does not exist."}

	if ownership.has(npc.id) and star in ownership [npc.id]:
		return { "success": false, "text": "You already own the %s." % BALLS [star] ["name"]}

	if not is_ball_shop_available(star):
		return { "success": false, "text": "The %s has already been claimed somewhere in this world." % BALLS [star] ["name"]}

	if not ownership.has(npc.id):
		ownership [npc.id] = []

	ownership [npc.id].append(star)

	var ball_item_id: int = gs.next_id
	gs.next_id += 1

	var profile: Dictionary = get_ball_market_profile(star, gs.year)

	gs.belongings_engine.add_item(npc, {
		"id": ball_item_id,
		"name": str(profile.get("name", BALLS [star] ["name"])),
		"type": "DragonBall",
		"star": star,
		"origin_era": gs.era.name,
		"acquired_year": gs.year,
		"lore": str(profile.get("lore", "")),
		"value": int(profile.get("base_value", 0)),
		"base_value": int(profile.get("base_value", 0)),
		"annual_appreciation_rate": float(profile.get("annual_appreciation_rate", 0.0)),
		"shop_item_id": str(profile.get("shop_item_id", ""))
	}, "Dragon Balls")

	var msg:= "%s %s purchased the %s from the Artifact Shop." % [
		npc.first_name,
		npc.last_name,
		str(profile.get("name", BALLS [star] ["name"]))
	]

	gs.push_world_feed(msg, {
		"npc_id": npc.id,
		"personally_relevant": npc == gs.player,
		"category": "dragonball",
		"event_name": ActionEventTypes.DRAGONBALL_FOUND,
		"source": "dragonballs_engine"
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.DRAGONBALL_FOUND, {
			"npc_id": npc.id,
			"dragon_ball": str(profile.get("name", BALLS [star] ["name"])),
			"text": msg,
			"source": "dragonballs_engine"
		})

	npc.memories.append("I purchased the legendary %s from the Artifact Shop." % str(profile.get("name", BALLS [star] ["name"])))

	return {
		"success": true,
		"effect_text": "Its surface hums with ancient wish energy."
	}



func _give_ball(npc: Person, star: int):
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return
	if not ownership.has(npc.id):
		ownership [npc.id] = []

	if star in ownership [npc.id]:
		return

	ownership [npc.id].append(star)

	var ball_item_id: int = gs.next_id
	gs.next_id += 1

	var profile: Dictionary = get_ball_market_profile(star, gs.year)

	gs.belongings_engine.add_item(npc, {
		"id": ball_item_id,
		"name": str(profile.get("name", BALLS [star] ["name"])),
		"type": "DragonBall",
		"star": star,
		"origin_era": gs.era.name,
		"acquired_year": gs.year,
		"lore": str(profile.get("lore", "")),
		"value": int(profile.get("base_value", 0)),
		"base_value": int(profile.get("base_value", 0)),
		"annual_appreciation_rate": float(profile.get("annual_appreciation_rate", 0.0)),
		"shop_item_id": str(profile.get("shop_item_id", ""))
	}, "Dragon Balls")

	gs.push_world_feed(
		"   %s %s has discovered the %s!" % [
			npc.first_name, npc.last_name, str(profile.get("name", BALLS [star] ["name"]))
		],
		{
			"npc_id": npc.id,
			"personally_relevant": false,
			"category": "dragonball",
			"event_name": ActionEventTypes.DRAGONBALL_FOUND,
			"source": "dragonballs_engine"
		}
	)

	npc.memories.append(
		"I found the legendary %s." % str(profile.get("name", BALLS [star] ["name"]))
	)




func handle_inheritance(payload):
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return
	var dead_id = int(payload.get("npc_id", -1))
	if gs.should_skip_manual_player_inheritance(dead_id):
		return
	if dead_id == -1:
		return
	if not ownership.has(dead_id):
		return
	var balls = ownership [dead_id]
	var dead_facts = gs.get_npc_facts_by_id(dead_id)
	if dead_facts == {}:
		return
	var heir = gs.get_random_living_person_from_ids(dead_facts.get("children", []))
	if heir == null:
		return
	for b in balls:
		_give_ball(heir, b)
	ownership.erase(dead_id)
func grant_all_balls_to_person(npc: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return { "success": false, "text": "Dragon Balls cannot resolve without GameState."}
	if npc == null:
		return { "success": false, "text": "A valid person is required."}

	if not ownership.has(npc.id):
		ownership [npc.id] = []

	var acquired: Array = []
	var already_owned: Array = []
	var transferred_from: Array = []

	for raw_star in BALLS.keys():
		var star: int = int(raw_star)
		if star in ownership [npc.id]:
			already_owned.append(star)
			continue

		_remove_ball_from_previous_owners(star, int(npc.id), transferred_from)
		ownership [npc.id].append(star)
		_materialize_dragonball_belonging(npc, star, context)
		acquired.append(star)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.dragonballs_grant_all_report",
		"version": CONTRACT_VERSION,
		"person_id": int(npc.id),
		"person_name": "%s %s" % [str(npc.first_name), str(npc.last_name)],
		"acquired": acquired.duplicate(true),
		"already_owned": already_owned.duplicate(true),
		"transferred_from": transferred_from.duplicate(true),
		"source": str(context.get("source", "dragonballs_engine")),
		"created_at_year": int(gs.year),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	var defer_echoes: bool = bool(context.get("defer_memory_echoes", false)) or bool(context.get("defer_post_summon_effects", false))
	if defer_echoes:
		_queue_deferred_dragonball_grant_echoes(npc, report, context)
	else:
		if gs.has_method("push_world_feed"):
			gs.push_world_feed(
				" %s %s summoned all 7 Dragon Balls into their possession." % [
					npc.first_name,
					npc.last_name
				],
				{
					"npc_id": npc.id,
					"personally_relevant": npc == gs.player,
					"category": "dragonball",
					"event_name": ActionEventTypes.DRAGONBALL_FOUND,
					"source": str(context.get("source", "dragonballs_engine")),
					"grant_all": true
				}
			)
		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.DRAGONBALL_FOUND, {
				"npc_id": npc.id,
				"dragon_ball": "All 7 Dragon Balls",
				"text": "%s summoned all 7 Dragon Balls." % npc.first_name,
				"source": str(context.get("source", "dragonballs_engine")),
				"grant_all": true
			})
		if npc.memories != null:
			var memory_text: String = "All 7 Dragon Balls answered my call."
			if not npc.memories.has(memory_text):
				npc.memories.append(memory_text)

	return report
func _queue_deferred_dragonball_grant_echoes(actor: Person, report: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_grant_echo_queue", []))
	queue.append({
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"report": report.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	gs.scenario_state ["dragonball_grant_echo_queue"] = queue
	gs.scenario_state ["dragonball_grant_echo_queue_size"] = queue.size()

	if bool(context.get("manual_flush_deferred_echoes", false)) or bool(context.get("manual_flush_deferred_effects", false)):
		gs.scenario_state ["dragonball_grant_echo_manual_flush_required"] = true
		gs.scenario_state ["dragonball_grant_echo_manual_flush_reason"] = str(context.get("source", "dragonballs_engine"))
		return

	call_deferred("_flush_deferred_dragonball_grant_echoes", 1)


func _flush_deferred_dragonball_grant_echoes(max_count: int = 1) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_grant_echo_queue", []))
	if queue.is_empty():
		gs.scenario_state ["dragonball_grant_echo_queue_size"] = 0
		return {
			"success": true,
			"processed": 0,
			"remaining": 0
		}

	var processed: int = 0
	var budget: int = max(1, int(max_count))

	while processed < budget and not queue.is_empty():
		var row: Dictionary = _safe_dictionary(queue.pop_front())
		var actor_id: int = int(row.get("actor_id", -1))
		var actor: Person = null

		if actor_id > 0:
			if gs.has_method("get_or_reactivate_npc_by_id"):
				actor = gs.get_or_reactivate_npc_by_id(actor_id)
			elif gs.has_method("get_npc_by_id"):
				actor = gs.get_npc_by_id(actor_id)

		if actor == null and gs.player != null and int(gs.player.id) == actor_id:
			actor = gs.player

		if actor != null:
			var context: Dictionary = _safe_dictionary(row.get("context", {}))
			if gs.has_method("push_world_feed"):
				gs.push_world_feed(
					" %s summoned all 7 Dragon Balls into their possession." % _person_label(actor),
					{
						"npc_id": int(actor.id),
						"personally_relevant": actor == gs.player,
						"category": "dragonball",
						"event_name": ActionEventTypes.DRAGONBALL_FOUND,
						"source": str(context.get("source", "dragonballs_engine")),
						"grant_all": true,
						"deferred": true
					}
				)

			if gs.event_bus != null:
				gs.event_bus.emit(ActionEventTypes.DRAGONBALL_FOUND, {
					"npc_id": int(actor.id),
					"dragon_ball": "All 7 Dragon Balls",
					"text": "%s summoned all 7 Dragon Balls." % _person_label(actor),
					"source": str(context.get("source", "dragonballs_engine")),
					"grant_all": true,
					"deferred": true
				})

			if actor.memories != null:
				var memory_text: String = "All 7 Dragon Balls answered my call."
				if not actor.memories.has(memory_text):
					actor.memories.append(memory_text)

		processed += 1

	gs.scenario_state ["dragonball_grant_echo_queue"] = queue
	gs.scenario_state ["dragonball_grant_echo_queue_size"] = queue.size()
	gs.scenario_state ["dragonball_grant_echo_last_flush"] = {
		"processed": processed,
		"remaining": queue.size(),
		"flushed_at_ms": int(Time.get_ticks_msec())
	}

	if not queue.is_empty():
		call_deferred("_flush_deferred_dragonball_grant_echoes", budget)

	return {
		"success": true,
		"processed": processed,
		"remaining": queue.size()
	}
func _remove_ball_from_previous_owners(star: int, new_owner_id: int, transferred_from: Array) -> void:
	var owners_to_clear: Array = []
	for raw_owner_id in ownership.keys():
		var owner_id: int = int(raw_owner_id)
		if owner_id == new_owner_id:
			continue
		var held: Array = ownership.get(raw_owner_id, [])
		if star in held:
			held.erase(star)
			transferred_from.append({
				"star": star,
				"previous_owner_id": owner_id
			})
			if held.is_empty():
				owners_to_clear.append(raw_owner_id)
			else:
				ownership [raw_owner_id] = held
			_remove_dragonball_belonging_for_person(owner_id, star)

	for raw_owner_id in owners_to_clear:
		ownership.erase(raw_owner_id)

func _remove_dragonball_belonging_for_person(person_id: int, star: int) -> void:
	if gs == null or gs.belongings_engine == null:
		return
	var owner: Person = null
	if gs.player != null and int(gs.player.id) == person_id:
		owner = gs.player
	elif gs.has_method("get_or_reactivate_npc_by_id"):
		owner = gs.get_or_reactivate_npc_by_id(person_id)
	elif gs.has_method("get_npc_by_id"):
		owner = gs.get_npc_by_id(person_id)

	if owner == null:
		return

	var items: Array = gs.belongings_engine.get_category_items(owner, "Dragon Balls")
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item as Dictionary
		if int(item.get("star", -1)) != star:
			continue
		gs.belongings_engine.remove_item_by_id(owner, "Dragon Balls", int(item.get("id", -1)))
		return

func _materialize_dragonball_belonging(npc: Person, star: int, context: Dictionary = {}) -> void:
	if gs == null or npc == null:
		return
	if gs.belongings_engine == null:
		return
	if not BALLS.has(star):
		return

	var ball_item_id: int = gs.next_id
	gs.next_id += 1

	var profile: Dictionary = get_ball_market_profile(star, int(gs.year))

	gs.belongings_engine.add_item(npc, {
		"id": ball_item_id,
		"name": str(profile.get("name", BALLS [star] ["name"])),
		"display_name": str(profile.get("name", BALLS [star] ["name"])),
		"type": "DragonBall",
		"contract_id": "dragonball",
		"star": star,
		"origin_era": gs.era.name,
		"acquired_year": gs.year,
		"lore": str(profile.get("lore", "")),
		"value": int(profile.get("base_value", 0)),
		"base_value": int(profile.get("base_value", 0)),
		"annual_appreciation_rate": float(profile.get("annual_appreciation_rate", 0.0)),
		"shop_item_id": str(profile.get("shop_item_id", "")),
		"source": str(context.get("source", "grant_all_balls_to_person")),
		"identity": {
			"type": "dragonball",
			"authority": "reality",
			"alignment": "wish_artifact",
			"star": star
		},
		"affordances": [
			"summon_shenron",
			"inspect_myth",
			"gift",
			"inherit"
		],
		"relationships": {
			"owned_by": int(npc.id),
			"owner_name": "%s %s" % [str(npc.first_name), str(npc.last_name)],
			"recognition": "wish_artifact",
			"ownership_type": "artifact_possession"
		}
	}, "Dragon Balls")



func player_has_all() -> bool:
	var pid = gs.player.id
	if not ownership.has(pid):
		return false
	return ownership [pid].size() == 7




func make_wish(wish: String, context: Dictionary = {}) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("dragonballs"):
		return _wish_result(false, wish, "🐉 Dragon Balls are not active in this reality.")

	if not player_has_all():
		return _wish_result(false, wish, "🐉 You do not possess all 7 Dragon Balls.")

	var clean_wish: String = str(wish).strip_edges().to_lower()
	if clean_wish == "":
		return _wish_result(false, wish, "🐉 Unknown wish.")

	var available_lookup: Dictionary = {}
	for raw_wish in get_available_wishes_for_player(gs.player):
		if typeof(raw_wish) != TYPE_DICTIONARY:
			continue
		var wish_row: Dictionary = raw_wish
		var wish_id: String = str(wish_row.get("id", "")).strip_edges().to_lower()
		if wish_id != "":
			available_lookup [wish_id] = wish_row.duplicate(true)

	if not available_lookup.has(clean_wish):
		return _wish_result(false, clean_wish, "🐉 Shenron will not grant that wish from this version of your identity.")

	var report: Dictionary = {}
	match clean_wish:
		"immortality":
			report = _wish_immortality()
		"resurrection":
			report = _wish_resurrection()
		"max_dynasty":
			report = _wish_max_dynasty()
		"saiyan":
			report = _wish_saiyan()
		"all_stones_no_consequence":
			report = _wish_all_stones_no_consequence()
		"unlock_form_beyond_limits":
			report = _wish_unlock_form_beyond_limits()
		"awaken_ki_arsenal":
			report = _wish_awaken_ki_arsenal()
		"max_bending_mastery":
			report = _wish_max_bending_mastery()
		"collapse_time_loops":
			report = _wish_collapse_time_loops()
		"rewrite_lineage_into_legend":
			report = _wish_rewrite_lineage_into_legend()
		"anchor_power_beyond_consequence":
			report = _wish_anchor_power_beyond_consequence()
		"avatar_saiyan_time_overdrive":
			report = _wish_avatar_saiyan_time_overdrive()
		"avatar_saiyan_polymorph_overdrive":
			report = _wish_avatar_saiyan_polymorph_overdrive()
		"bind_saiyan_legacy_to_descendants":
			report = _wish_bind_saiyan_legacy_to_descendants()
		_:
			report = _wish_result(false, clean_wish, "🐉 Unknown wish.")

	if bool(context.get("defer_wish_side_effects", false)):
		_queue_deferred_dragonball_wish_side_effects(gs.player, clean_wish, report, context)
		report ["wish_side_effects_deferred"] = true
	else:
		_record_wish_report(gs.player, clean_wish, report)
		_record_dragonball_wish_life_echo(gs.player, clean_wish, report)

	if bool(report.get("success", false)):
		if bool(context.get("defer_scatter", false)):
			report ["dragonball_scatter_pending"] = true
			report ["dragonball_scatter_deferred"] = true
			report ["dragonball_scatter_context"] = context.duplicate(true)
		else:
			var scatter_report: Dictionary = _scatter_dragon_balls_after_wish(gs.player, clean_wish, report)
			report ["dragonball_scatter_report"] = scatter_report.duplicate(true)
			report ["dragonball_scatter_animation"] = _dragonball_scatter_animation_packet(gs.player, scatter_report)

	return report.duplicate(true)
func _queue_deferred_dragonball_wish_side_effects(actor: Person, wish_id: String, report: Dictionary, context: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_wish_side_effect_queue", []))
	queue.append({
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"wish_id": str(wish_id).strip_edges().to_lower(),
		"report": report.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	gs.scenario_state ["dragonball_wish_side_effect_queue"] = queue
	gs.scenario_state ["dragonball_wish_side_effect_queue_size"] = queue.size()

	call_deferred("_flush_deferred_dragonball_wish_side_effects", 1)


func _flush_deferred_dragonball_wish_side_effects(max_count: int = 1) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_wish_side_effect_queue", []))
	if queue.is_empty():
		gs.scenario_state ["dragonball_wish_side_effect_queue_size"] = 0
		return {
			"success": true,
			"processed": 0,
			"remaining": 0
		}

	var processed: int = 0
	var budget: int = max(1, int(max_count))

	while processed < budget and not queue.is_empty():
		var row: Dictionary = _safe_dictionary(queue.pop_front())
		var actor_id: int = int(row.get("actor_id", -1))
		var actor: Person = null

		if actor_id > 0:
			if gs.has_method("get_or_reactivate_npc_by_id"):
				actor = gs.get_or_reactivate_npc_by_id(actor_id)
			elif gs.has_method("get_npc_by_id"):
				actor = gs.get_npc_by_id(actor_id)

		if actor == null and gs.player != null and int(gs.player.id) == actor_id:
			actor = gs.player

		if actor != null:
			var wish_id: String = str(row.get("wish_id", "")).strip_edges().to_lower()
			var report: Dictionary = _safe_dictionary(row.get("report", {}))
			_record_wish_report(actor, wish_id, report)
			_record_dragonball_wish_life_echo(actor, wish_id, report)

		processed += 1

	gs.scenario_state ["dragonball_wish_side_effect_queue"] = queue
	gs.scenario_state ["dragonball_wish_side_effect_queue_size"] = queue.size()
	gs.scenario_state ["dragonball_wish_side_effect_last_flush"] = {
		"processed": processed,
		"remaining": queue.size(),
		"flushed_at_ms": int(Time.get_ticks_msec())
	}

	if not queue.is_empty():
		call_deferred("_flush_deferred_dragonball_wish_side_effects", budget)

	return {
		"success": true,
		"processed": processed,
		"remaining": queue.size()
	}
func _wish_result(success: bool, wish_id: String, text: String, extra: Dictionary = {}) -> Dictionary:

	var out: Dictionary = extra.duplicate(true)
	out ["success"] = success
	out ["wish_id"] = str(wish_id).strip_edges().to_lower()
	out ["text"] = text
	out ["popup_title"] = "Shenron"
	out ["popup_text"] = text
	out ["popup_footer"] = "The Dragon Balls dim, but the timeline remembers."
	return out

func _record_wish_report(person: Person, wish_id: String, report: Dictionary) -> void:

	if person == null:
		return
	var clean_wish: String = str(wish_id).strip_edges().to_lower()
	var row: Dictionary = report.duplicate(true)
	row ["schema"] = "eralife.dragonball_wish_report"
	row ["version"] = CONTRACT_VERSION
	row ["person_id"] = int(person.id)
	row ["person_name"] = _person_label(person)
	row ["wish_id"] = clean_wish
	row ["created_at_year"] = _current_year()
	row ["created_at_ms"] = int(Time.get_ticks_msec())
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("wish_ledger", []))
	ledger.append(row.duplicate(true))
	while ledger.size() > MAX_WISH_LEDGER:
		ledger.pop_front()
	state ["wish_ledger"] = ledger
	var lineage_ripples: Dictionary = _safe_dictionary(state.get("lineage_ripples", {}))
	var ripples: Array = _safe_array(lineage_ripples.get(str(person.id), []))
	ripples.append({
		"wish_id": clean_wish,
		"text": str(report.get("text", "")),
		"inheritable": bool(report.get("inheritable", true)),
		"lineage_weight": float(report.get("lineage_weight", 0.08)),
		"created_at_year": _current_year()
	})
	lineage_ripples [str(person.id)] = ripples
	state ["lineage_ripples"] = lineage_ripples
	_commit_world_state(state)
	last_wish_report = row.duplicate(true)
func _record_shenron_summon_life_echo(actor: Person, _source_item: Dictionary = {}, surge_report: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return

	var actor_name: String = _person_label(actor)
	var player_text: String = "I summoned Shenron after gathering all 7 Dragon Balls."
	var family_text: String = "%s summoned Shenron. I felt the sky bend around our family name." % actor_name
	var observer_text: String = "%s summoned Shenron. I saw the world darken around seven burning lights." % actor_name

	_append_unique_memory(actor, player_text)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed("      %s summoned Shenron with all 7 Dragon Balls." % actor_name, {
			"npc_id": int(actor.id),
			"personally_relevant": actor == gs.player,
			"category": "dragonball",
			"event_name": ActionEventTypes.WISH_MADE,
			"source": "dragonballs_engine",
			"reality_surge_report": surge_report.duplicate(true)
		})

	_queue_deferred_dragonball_life_echoes(actor, family_text, observer_text, {
		"source": "dragonballs_engine",
		"event_type": "shenron_summon",
		"reality_surge_report": surge_report.duplicate(true)
	})
func _record_dragonball_wish_life_echo(actor: Person, wish_id: String, report: Dictionary) -> void:
	if gs == null or actor == null:
		return

	var clean_wish: String = str(wish_id).strip_edges().to_lower()
	var actor_name: String = _person_label(actor)
	var result_text: String = str(report.get("text", "")).strip_edges()

	var player_text: String = "I asked Shenron for %s." % clean_wish.replace("_", " ")
	if result_text != "":
		player_text += " %s" % result_text.strip_edges()

	var family_text: String = "%s made a wish to Shenron. The wish felt close enough to touch our family line." % actor_name
	var observer_text: String = "%s made a wish to Shenron. The Dragon Balls dimmed after the sky answered." % actor_name

	report ["life_diary_text"] = player_text
	_append_unique_memory(actor, player_text)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed("      %s made a wish to Shenron." % actor_name, {
			"npc_id": int(actor.id),
			"personally_relevant": actor == gs.player,
			"category": "dragonball",
			"event_name": ActionEventTypes.WISH_MADE,
			"source": "dragonballs_engine",
			"wish_id": clean_wish
		})

	_queue_deferred_dragonball_life_echoes(actor, family_text, observer_text, {
		"source": "dragonballs_engine",
		"event_type": "shenron_wish",
		"wish_id": clean_wish
	})
func _queue_deferred_dragonball_life_echoes(actor: Person, family_text: String, observer_text: String, context: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_life_echo_queue", []))
	var observer_count: int = 0

	for observer in _shenron_memory_observers(actor):
		if observer == null:
			continue
		if int(observer.id) == int(actor.id):
			continue

		var echo_text: String = observer_text
		var observer_role: String = "local_observer"
		if _is_family_observer(observer, actor):
			echo_text = family_text
			observer_role = "family"

		echo_text = str(echo_text).strip_edges()
		if echo_text == "":
			continue

		queue.append({
			"observer_id": int(observer.id),
			"observer_role": observer_role,
			"text": echo_text,
			"context": context.duplicate(true),
			"created_at_year": _current_year(),
			"created_at_ms": int(Time.get_ticks_msec())
		})
		observer_count += 1

	gs.scenario_state ["dragonball_life_echo_queue"] = queue
	gs.scenario_state ["dragonball_life_echo_queue_size"] = queue.size()
	gs.scenario_state ["dragonball_life_echo_last_queued_count"] = observer_count

	if observer_count > 0:
		call_deferred("_flush_deferred_dragonball_life_echoes", 12)


func _flush_deferred_dragonball_life_echoes(max_count: int = 12) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("dragonball_life_echo_queue", []))
	if queue.is_empty():
		gs.scenario_state ["dragonball_life_echo_queue_size"] = 0
		return {
			"success": true,
			"processed": 0,
			"remaining": 0
		}

	var processed: int = 0
	var budget: int = max(1, int(max_count))

	while processed < budget and not queue.is_empty():
		var row: Dictionary = _safe_dictionary(queue.pop_front())
		var observer_id: int = int(row.get("observer_id", -1))
		var echo_text: String = str(row.get("text", "")).strip_edges()
		var context: Dictionary = _safe_dictionary(row.get("context", {}))

		if observer_id > 0 and echo_text != "":
			var observer: Person = null
			if gs.has_method("get_or_reactivate_npc_by_id"):
				observer = gs.get_or_reactivate_npc_by_id(observer_id)
			elif gs.has_method("get_npc_by_id"):
				observer = gs.get_npc_by_id(observer_id)

			if observer != null:
				if gs.narrative_engine != null:
					gs.narrative_engine.log_event(observer, {
						"type": "text",
						"text": echo_text,
						"life_diary_text": echo_text,
						"force_first_person_memory": true,
						"source": str(context.get("source", "dragonballs_engine")),
						"category": "dragonball",
						"event_name": ActionEventTypes.WISH_MADE,
						"npc_id": observer_id,
						"suppress_world_feed": true,
						"observer_role": str(row.get("observer_role", "observer")),
						"wish_id": str(context.get("wish_id", ""))
					})
				else:
					_append_unique_memory(observer, echo_text)

		processed += 1

	gs.scenario_state ["dragonball_life_echo_queue"] = queue
	gs.scenario_state ["dragonball_life_echo_queue_size"] = queue.size()
	gs.scenario_state ["dragonball_life_echo_last_flush"] = {
		"processed": processed,
		"remaining": queue.size(),
		"flushed_at_ms": int(Time.get_ticks_msec())
	}

	if not queue.is_empty():
		call_deferred("_flush_deferred_dragonball_life_echoes", budget)

	return {
		"success": true,
		"processed": processed,
		"remaining": queue.size()
	}
func _shenron_memory_observers(actor: Person) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out
	if typeof(gs.npcs) != TYPE_ARRAY:
		return out

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc as Person
		if npc == null:
			continue
		if not npc.alive:
			continue
		if int(npc.id) == int(actor.id):
			continue
		if _is_family_observer(npc, actor) or _is_local_observer(npc, actor):
			out.append(npc)

	return out
func _is_family_observer(observer: Person, actor: Person) -> bool:
	if observer == null or actor == null:
		return false
	if int(observer.id) == int(actor.id):
		return true
	if observer.partner != null and int(observer.partner.id) == int(actor.id):
		return true
	if actor.partner != null and int(actor.partner.id) == int(observer.id):
		return true
	if int(observer.id) in actor.parents:
		return true
	if int(actor.id) in observer.parents:
		return true
	if int(observer.id) in actor.children:
		return true
	if int(actor.id) in observer.children:
		return true
	if str(observer.last_name).strip_edges() != "" and str(observer.last_name).strip_edges() == str(actor.last_name).strip_edges():
		return true
	return false
func _is_local_observer(observer: Person, actor: Person) -> bool:
	if observer == null or actor == null:
		return false
	if str(observer.locality_id).strip_edges() != "" and str(observer.locality_id).strip_edges() == str(actor.locality_id).strip_edges():
		return true
	if str(observer.district_id).strip_edges() != "" and str(observer.district_id).strip_edges() == str(actor.district_id).strip_edges():
		return true
	if str(observer.home_city).strip_edges() != "" and str(observer.home_city).strip_edges() == str(actor.home_city).strip_edges():
		return true
	if str(observer.birth_city).strip_edges() != "" and str(observer.birth_city).strip_edges() == str(actor.birth_city).strip_edges():
		return true
	return false
func _append_unique_memory(person: Person, text: String) -> void:
	if person == null:
		return
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return
	if person.memories == null:
		person.memories = []
	if not person.memories.has(clean_text):
		person.memories.append(clean_text)
func _scatter_dragon_balls_after_wish(actor: Person, wish_id: String, _report: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var actor_id: int = int(actor.id)
	var stars: Array = []

	if ownership.has(actor_id):
		stars = _safe_array(ownership.get(actor_id, [])).duplicate(true)
		ownership.erase(actor_id)
	elif ownership.has(str(actor_id)):
		stars = _safe_array(ownership.get(str(actor_id), [])).duplicate(true)
		ownership.erase(str(actor_id))

	if stars.is_empty():
		stars = [1, 2, 3, 4, 5, 6, 7]

	for raw_star in stars:
		_remove_dragonball_belonging_for_person(actor_id, int(raw_star))

	var state: Dictionary = _world_state()
	var scatter_ledger: Array = _safe_array(state.get("scatter_ledger", []))
	var scatter_report: Dictionary = {
		"success": true,
		"schema": "eralife.dragonballs_scatter_report",
		"version": CONTRACT_VERSION,
		"person_id": actor_id,
		"person_name": _person_label(actor),
		"wish_id": str(wish_id).strip_edges().to_lower(),
		"stars": stars.duplicate(true),
		"text": "The Dragon Balls scattered back across the world.",
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	scatter_ledger.append(scatter_report.duplicate(true))
	while scatter_ledger.size() > MAX_WISH_LEDGER:
		scatter_ledger.pop_front()

	state ["scatter_ledger"] = scatter_ledger
	state ["last_scatter_report"] = scatter_report.duplicate(true)
	_commit_world_state(state)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed("🐉 The Dragon Balls scattered back across the world after %s's wish." % _person_label(actor), {
			"npc_id": actor_id,
			"personally_relevant": actor == gs.player,
			"category": "dragonball",
			"event_name": ActionEventTypes.WISH_MADE,
			"source": "dragonballs_engine",
			"wish_id": str(wish_id).strip_edges().to_lower(),
		})

	_append_unique_memory(actor, "After my wish, the Dragon Balls shot out of my belongings and scattered back across the world.")

	return scatter_report
func _dragonball_scatter_animation_packet(actor: Person, scatter_report: Dictionary = {}) -> Dictionary:
	return {
		"active": true,
		"schema": "eralife.dragonball_scatter_animation_packet",
		"version": CONTRACT_VERSION,
		"source": "dragonballs_engine",
		"actor_id": int(actor.id) if actor != null else -1,
		"stars": _safe_array(scatter_report.get("stars", [1, 2, 3, 4, 5, 6, 7])),
		"origin_surface": "belongings_hud_button",
		"consume_result_popup": true,
		"duration_seconds": 3.15,
		"popup_title": "Dragon Balls Scattered",
		"popup_text": "The Dragon Balls burst from your belongings and scatter back across the world.\n\nThey are no longer in your belongings. They can be found again.",
		"popup_footer": "The hunt begins again."
	}
func _wish_memory_summary_for_person(owner: Person) -> String:

	var past_ids: Array = _past_wish_ids_for_person(owner)
	if past_ids.is_empty():
		return "Shenron has no past wish memory for you yet."
	return "Shenron remembers your past wishes: %s." % ", ".join(past_ids)



func _wish_immortality() -> Dictionary:

	var p: Person = gs.player
	_append_trait(p, "Immortal")
	return _wish_result(true, "immortality", "✨ You have become IMMORTAL.\n\nShenron did not just extend your life. He altered the rule that expected it to end.", {
		"inheritable": false,
		"lineage_weight": 0.02
	})

func _wish_resurrection() -> Dictionary:

	var target: Person = null
	for npc in gs.npcs:
		if npc == null:
			continue
		if npc.alive:
			continue
		if "SoulStoneSacrifice" in npc.traits:
			continue
		target = npc
		break
	if target == null:
		return _wish_result(false, "resurrection", "💫 No resurrectable soul answered. Souls sacrificed on Vormir cannot return.")
	target.alive = true
	target.health = 100
	target.mental_health = 80
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"💫 Shenron has reluctantly resurrected %s!" % _person_label(target),
			{
				"npc_id": target.id,
				"personally_relevant": target.id in gs.player.parents or gs.player.id in target.parents,
				"category": "dragonball",
				"event_name": ActionEventTypes.WISH_MADE,
				"source": "dragonballs_engine"
			}
		)
	return _wish_result(true, "resurrection", "💫 %s has been resurrected." % _person_label(target), {
		"target_id": int(target.id),
		"inheritable": false,
		"lineage_weight": 0.03
	})

func _wish_max_dynasty() -> Dictionary:

	var p: Person = gs.player
	p.dynasty_prestige = max(int(p.dynasty_prestige), 999)
	return _wish_result(true, "max_dynasty", "👑 Your dynasty now holds supreme prestige.", {
		"inheritable": true,
		"lineage_weight": 0.12
	})

func _wish_saiyan() -> Dictionary:

	var p: Person = gs.player
	var grant_report: Dictionary = _grant_saiyan_power_to_person(p, "dragonball_wish", {
		"inherited": false,
		"dna_share": 1.0,
		"configured_at_birth": false
	})
	if _is_bender(p) and gs.power_engine != null and gs.power_engine.has_method("resolve_elemental_mutation_contract_packet"):
		gs.power_engine.resolve_elemental_mutation_contract_packet(p, {
			"source": "dragonball_saiyan_wish",
			"fusion_stack": ["saiyan_bloodline", "bending_affinity", "wish_amplifier"]
		})
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"🔥 A golden aura erupts around %s — the Saiyan bloodline awakens as a contract-driven lineage!" % _person_label(p),
			{
				"npc_id": p.id,
				"personally_relevant": true,
				"category": "dragonball",
				"event_name": ActionEventTypes.WISH_MADE,
				"source": "dragonballs_engine"
			}
		)
	return _wish_result(true, "saiyan", "🔥 You have become a Saiyan.\n\nYour bloodline is now routed through a power contract, inheritance seed, power-level model, and cross-system mutation seam.", {
		"grant_report": grant_report.duplicate(true),
		"inheritable": true,
		"lineage_weight": 0.22
	})

func _wish_all_stones_no_consequence() -> Dictionary:

	var p: Person = gs.player
	if gs.artifacts_engine != null and "STONES" in gs.artifacts_engine:
		for stone in gs.artifacts_engine.STONES.keys():
			if gs.artifacts_engine.has_method("_give_stone"):
				gs.artifacts_engine._give_stone(p, stone)
	_append_trait(p, "NoCosmicConsequence")
	return _wish_result(true, "all_stones_no_consequence", "🌌 You possess all Infinity Stones — with no cosmic punishment.", {
		"inheritable": true,
		"lineage_weight": 0.1
	})
func get_asset_signal_rollup_for_owner(owner: Person) -> Dictionary:
	var out: Dictionary = {}
	if gs == null or owner == null:
		return out

	var owned_items: Array = ownership.get(int(owner.id), [])
	if typeof(owned_items) != TYPE_ARRAY or owned_items.is_empty():
		return out

	var ball_count: int = owned_items.size()
	out ["asset_count"] = ball_count
	out ["dependency_pressure"] = 0.0
	out ["prestige_total"] = float(ball_count) * 2.5
	out ["modifier_weight"] = 0.0
	out ["portfolio_tags"] = {
		"portfolio_mood.quest_object": ball_count,
		"portfolio_mood.mythic_gravity": 1
	}
	out ["event_hooks"] = {
		"artifact_hunters": ball_count,
		"wish_seekers": 1
	}
	out ["passive_modifiers"] = {}
	out ["prestige_signals"] = {
		"legendary_presence": float(ball_count)
	}
	out ["status_signals"] = {
		"public_attention": float(ball_count) * 1.5,
		"romance_signal": min(3.0, float(ball_count) * 0.5)
	}
	out ["pressure_profile"] = {
		"spectacle": float(ball_count),
		"criminal_usefulness": float(ball_count) * 0.75
	}
	out ["asset_namespaces"] = {
		"artifact.dragon_ball": ball_count
	}
	out ["asset_class_filters"] = {
		"artifact": ball_count
	}
	out ["asset_identity_modes"] = {
		"wish_anchor": 1
	}
	out ["asset_tier_profile"] = {
		"mythic": float(ball_count)
	}
	out ["asset_provenance_signals"] = {
		"discovered": float(ball_count)
	}
	out ["asset_condition_profile"] = {
		"pristine": float(ball_count)
	}
	out ["max_asset_tier_score"] = 5.0 if ball_count > 0 else 0.0
	out ["asset_uniqueness_score"] = float(ball_count) * 2.0
	return out
func get_yearly_event_fragments_for_owner(owner: Person) -> Array:
	var out: Array = []
	if gs == null or owner == null:
		return out

	var rollup: Dictionary = get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return out

	out.append({
		"text": "🟠 People around %s seemed to sense that Rare wish artifacts were orbiting their life." % owner.first_name,
		"category": "assets",
		"weight": 4
	})
	return out
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if gs == null or player == null or not player.alive:
		return out
	if not gs.is_feature_enabled("dragonballs"):
		return out

	var year: int = int(context.get("year", 0))

	out.append({
		"id": "dragonball_seekers_at_my_door_%d" % year,
		"source": "dragonballs_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.14
		},
		"tone": "mysterious",
		"rarity": 0.73,
		"cooldown_key": "dragonball.seekers.arrival",
		"cooldown_years": 2,
		"priority": 14,
		"min_age": 10,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.dragon_ball": 2.7},
		"required_asset_event_hooks": ["wish_seekers"],
		"asset_identity_mode": ["wish_anchor"],
		"asset_weight_pressure_profile": { "spectacle": 1.5, "criminal_usefulness": 1.0},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.1,
		"asset_arc_family": "dragonball_seekers",
		"asset_arc_step": "arrival_pressure",
		"asset_repeat_group": "artifact.dragonball.seekers",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "More seekers than usual seem to know I’m connected to something rare. Do I scatter them, hear them out, or recruit the useful ones?",
		"followup_hooks": ["artifact.dragonball.seekers.arrival"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "scatter_them",
				"label": "Scatter them before they settle in.",
				"journal_line": "I scattered the seekers before their curiosity could turn into a permanent orbit.",
				"followup_hooks": ["artifact.dragonball.seekers.scatter"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": -1.0},
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "hear_them_out",
				"label": "Hear them out and sort motives.",
				"journal_line": "I heard the seekers out long enough to separate faith from opportunism.",
				"followup_hooks": ["artifact.dragonball.seekers.listen"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 3.0},
					"reputation_bias": { "public_attention": 2.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "recruit_the_useful",
				"label": "Recruit the useful ones quietly.",
				"journal_line": "I quietly recruited the useful ones instead of letting random devotion shape the board for me.",
				"followup_hooks": ["artifact.dragonball.seekers.recruit"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 2.0},
					"crime_pressure": { "rumor_heat": 1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "dragonball_wish_broker_pressure_%d" % year,
		"source": "dragonballs_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.16
		},
		"tone": "tense",
		"rarity": 0.69,
		"cooldown_key": "dragonball.wish_brokers",
		"cooldown_years": 2,
		"priority": 13,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.dragon_ball": 2.6},
		"required_asset_event_hooks": ["artifact_hunters"],
		"asset_identity_mode": ["wish_anchor"],
		"asset_weight_pressure_profile": { "criminal_usefulness": 1.5},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.0,
		"asset_arc_family": "dragonball_brokers",
		"asset_arc_step": "wish_market_pressure",
		"asset_repeat_group": "artifact.dragonball.brokers",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "People are starting to treat my connection to the Dragon Balls like a market. Do I shut that down, set terms, or disappear from the bargaining game?",
		"followup_hooks": ["artifact.dragonball.brokers.market_pressure"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "shut_it_down",
				"label": "Shut the whole market down.",
				"journal_line": "I shut the market logic down before people could start pricing miracle into politics.",
				"followup_hooks": ["artifact.dragonball.brokers.shutdown"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 1.0},
					"crime_pressure": { "rumor_heat": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "set_terms",
				"label": "Set strict terms and control the room.",
				"journal_line": "I set strict terms so desire would have to face structure before it got near me.",
				"followup_hooks": ["artifact.dragonball.brokers.terms"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 2.0},
					"reputation_bias": { "public_attention": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "disappear_from_bargaining",
				"label": "Disappear from the bargaining game.",
				"journal_line": "I disappeared from the bargaining game before everybody else’s wishes started sounding like chains.",
				"followup_hooks": ["artifact.dragonball.brokers.disappear"],
				"bias_payloads": {
					"health_bias": { "stress_delta": -1.0},
					"relationship_bias": { "social_visibility": -2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	return out
func get_ball_market_profile(star: int, acquired_year: int = 0) -> Dictionary:
	if not BALLS.has(star):
		return {}

	var lore_by_star: Dictionary = {
		1: "Its glow feels ancient even when resting still.",
		2: "Collectors whisper that this one tends to surface near turning points in history.",
		3: "Its internal light bends like a living flame.",
		4: "The most sentimental traders refuse to name their price for this one.",
		5: "Merchants claim the room changes temperature when it is near.",
		6: "Its glow feels too intelligent to be ordinary treasure.",
		7: "The rarest dealers won't even look directly at it for too long."
	}

	var price_by_star: Dictionary = {
		1: 1000000000,
		2: 2500000000,
		3: 5000000000,
		4: 10000000000,
		5: 15000000000,
		6: 25000000000,
		7: 40000000000
	}

	var base_value: int = int(price_by_star.get(star, 0))
	var annual_appreciation_rate: float = 0.09
	var years_held: int = 0

	if gs != null and acquired_year > 0:
		years_held = max(0, int(gs.year) - acquired_year)

	var current_value: int = base_value
	if annual_appreciation_rate > 0.0 and years_held > 0:
		current_value = int(round(float(base_value) * pow(1.0 + annual_appreciation_rate, years_held)))

	return {
		"name": str(BALLS [star] ["name"]),
		"lore": str(lore_by_star.get(star, "Its surface hums with ancient wish energy.")),
		"base_value": base_value,
		"value": current_value,
		"current_value": current_value,
		"annual_appreciation_rate": annual_appreciation_rate,
		"shop_item_id": "dragonball_%d" % star
	}