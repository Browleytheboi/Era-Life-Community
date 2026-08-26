extends Resource
class_name AvatarInfluenceEngine

const CONTRACT_SCHEMA:= "eralife.avatar_influence_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.avatar_influence_state"

var gs
var active_contract: Dictionary = {}
var influence_state: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)


func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()

	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.avatar_influence_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "default_avatar_influence_contract")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)


func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"influence_state": influence_state.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "AvatarInfluenceEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = state.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw)

	var influence_raw: Variant = state.get("influence_state", {})
	if typeof(influence_raw) == TYPE_DICTIONARY:
		influence_state = influence_raw.duplicate(true)

	var report_raw: Variant = state.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = report_raw.duplicate(true)

	return {
		"success": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func apply_avatar_birth_influence(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Missing actor."
		}

	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return {
			"success": false,
			"reason": "Actor is not the Avatar."
		}

	var previous_avatars: Array = _previous_avatar_records_for(actor)
	var profile: Dictionary = _avatar_profile_for(actor)
	var influence: Dictionary = _calculate_birth_influence(actor, previous_avatars, context)

	_apply_latent_potential_influence(actor, influence)
	_apply_combat_profile_influence(actor, influence)

	profile ["schema"] = "eralife.person_avatar_influence_profile"
	profile ["version"] = CONTRACT_VERSION
	profile ["birth_influence_seeded"] = true
	profile ["birth_influence_seeded_year"] = _current_year()
	profile ["previous_avatar_count"] = previous_avatars.size()
	profile ["previous_avatar_names"] = influence.get("previous_avatar_names", [])
	profile ["elemental_memory"] = influence.get("elemental_memory", {})
	profile ["knowledge"] = influence.get("knowledge", {})
	profile ["interventions"] = _safe_dictionary(profile.get("interventions", {}))
	profile ["spirit_world"] = _safe_dictionary(profile.get("spirit_world", {}))

	_store_avatar_profile(actor, profile)

	var report: Dictionary = {
		"schema": "eralife.avatar_birth_influence_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"previous_avatar_count": previous_avatars.size(),
		"influence": influence.duplicate(true),
		"source": str(context.get("source", "avatar_birth"))
	}

	last_report = report.duplicate(true)
	return report.duplicate(true)


func maybe_intervene_in_duel(actor: Person, opponent: Person, duel: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return _empty_intervention("Missing actor.")
	if opponent == null:
		return _empty_intervention("Missing opponent.")
	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return _empty_intervention("Actor is not the Avatar.")

	var phase: String = str(context.get("phase", "duel")).strip_edges().to_lower()
	var profile: Dictionary = _avatar_profile_for(actor)
	var interventions: Dictionary = _safe_dictionary(profile.get("interventions", {}))
	var previous_avatars: Array = _previous_avatar_records_for(actor)

	if previous_avatars.is_empty():
		return _empty_intervention("No previous Avatar records.")

	var already_used: int = int(interventions.get("duel_intervention_count", 0))
	var blue_moon_used: bool = bool(interventions.get("blue_moon_avatar_state_used", false))
	var player_hp: int = int(duel.get("player_hp", int(actor.health)))
	var player_hp_max: int = max(1, int(duel.get("player_hp_max", max(1, int(actor.health)))))
	var target_hp: int = int(duel.get("target_hp", 1))
	var losing_badly: bool = float(player_hp) / float(player_hp_max) <= 0.28
	var near_finish: bool = target_hp <= max(12, int(float(duel.get("target_hp_max", 1)) * 0.18))

	var chance: int = int(_contract_value("duel_intervention_chance", 7))
	if phase == "opening_vision":
		chance = int(_contract_value("opening_vision_chance", 10))
	elif phase == "player_attack":
		chance = int(_contract_value("ghost_assist_chance", 8))
	elif phase in ["defense_response", "last_health_defense"]:
		chance = int(_contract_value("defense_intervention_chance", 9))

	if losing_badly:
		chance += int(_contract_value("low_health_bonus_chance", 22))
	if near_finish:
		chance += 5
	if already_used > 0:
		chance = max(1, int(round(float(chance) * pow(0.34, float(already_used)))))

	var rng: RandomNumberGenerator = _stable_rng(actor, "duel_%s_%d_%d_%d" % [
		phase,
		int(duel.get("round", 1)),
		int(opponent.id),
		already_used
	])

	if int(rng.randi_range(0, 99)) >= clamp(chance, 0, 95):
		return _empty_intervention("Roll failed.")

	var avatar_record: Dictionary = previous_avatars [int(rng.randi_range(0, previous_avatars.size() - 1))]
	var avatar_name: String = str(avatar_record.get("name", "a previous Avatar")).strip_edges()
	var avatar_element: String = str(avatar_record.get("native_element", "avatar")).strip_edges().to_lower()
	var intervention_type: String = "spiritual_dialogue"

	var damage_bonus: int = 0
	var guard_bonus: int = 0
	var read_bonus: int = 0
	var force_hit: bool = false
	var attack_name: String = "%s's echo" % avatar_name

	if phase == "opening_vision":
		intervention_type = "scenario_vision"
		read_bonus = int(rng.randi_range(4, 10))
	elif phase == "player_attack":
		intervention_type = "ghost_assist"
		damage_bonus = int(rng.randi_range(10, 26))
		read_bonus = int(rng.randi_range(2, 6))
		force_hit = int(rng.randi_range(0, 99)) < 35
		attack_name = "%s's %s echo strike" % [avatar_name, avatar_element]
	elif losing_badly and not blue_moon_used:
		intervention_type = "blue_moon_avatar_state"
		damage_bonus = int(rng.randi_range(24, 48))
		guard_bonus = int(rng.randi_range(18, 42))
		read_bonus = int(rng.randi_range(7, 14))
		force_hit = true
		interventions ["blue_moon_avatar_state_used"] = true
		attack_name = "%s's Avatar State surge" % avatar_name
	else:
		intervention_type = "ghost_guard"
		guard_bonus = int(rng.randi_range(14, 34))
		read_bonus = int(rng.randi_range(3, 9))

	interventions ["duel_intervention_count"] = already_used + 1
	interventions ["last_intervention_year"] = _current_year()
	interventions ["last_intervention_type"] = intervention_type
	interventions ["last_previous_avatar_name"] = avatar_name
	profile ["interventions"] = interventions
	_store_avatar_profile(actor, profile)

	var opponent_name: String = _person_label(opponent)
	var actor_name: String = _person_label(actor)
	var dialogue: String = _avatar_dialogue_for(intervention_type, avatar_name, avatar_element)
	var acknowledgement: String = "%s hesitates as %s manifests behind you." % [opponent_name, avatar_name]

	var text: String = "%s\n\n%s" % [
		dialogue,
		acknowledgement
	]

	var diary_text: String = "A previous Avatar, %s, intervened during my duel with %s." % [
		avatar_name,
		opponent_name
	]
	var world_text: String = "%s fought %s as the spirit of %s visibly intervened in the duel." % [
		actor_name,
		opponent_name,
		avatar_name
	]

	_log_avatar_intervention(actor, opponent, diary_text, world_text, {
		"intervention_type": intervention_type,
		"previous_avatar_name": avatar_name,
		"phase": phase
	})

	var packet: Dictionary = {
		"schema": "eralife.avatar_duel_intervention",
		"version": CONTRACT_VERSION,
		"success": true,
		"triggered": true,
		"intervention_type": intervention_type,
		"previous_avatar_name": avatar_name,
		"previous_avatar_element": avatar_element,
		"damage_bonus": damage_bonus,
		"guard_bonus": guard_bonus,
		"read_bonus": read_bonus,
		"force_hit": force_hit,
		"attack_name": attack_name,
		"text": text,
		"dialogue": dialogue,
		"acknowledgement_text": acknowledgement,
		"diary_text": diary_text,
		"world_text": world_text
	}

	last_report = packet.duplicate(true)
	return packet.duplicate(true)


func go_to_spirit_world(actor: Person, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Spirit World",
			"popup_text": "No Avatar was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	if str(actor.bending_type).strip_edges().to_lower() != "avatar":
		return {
			"success": false,
			"popup_title": "Spirit World Locked",
			"popup_text": "Only the Avatar can enter this path.",
			"popup_footer": "Tap anywhere to continue."
		}

	var previous_avatars: Array = _previous_avatar_records_for(actor)
	if previous_avatars.is_empty():
		return {
			"success": false,
			"popup_title": "Spirit World Quiet",
			"popup_text": "No previous Avatar echoes are reachable yet.",
			"popup_footer": "Tap anywhere to continue."
		}

	var mode: String = str(options.get("mode", "knowledge")).strip_edges().to_lower()
	var rng: RandomNumberGenerator = _stable_rng(actor, "spirit_world_%d_%s" % [_current_year(), mode])
	var chosen_index: int = clamp(int(options.get("avatar_index", rng.randi_range(0, previous_avatars.size() - 1))), 0, previous_avatars.size() - 1)
	var avatar_record: Dictionary = previous_avatars [chosen_index]
	var avatar_name: String = str(avatar_record.get("name", "a previous Avatar"))
	var avatar_element: String = str(avatar_record.get("native_element", "avatar")).strip_edges().to_lower()

	if mode == "knowledge":
		var knowledge_gain: int = clamp(2 + int(rng.randi_range(0, 3)), 2, 5)
		var willpower_gain: int = clamp(1 + int(rng.randi_range(0, 2)), 1, 3)

		var profile: Dictionary = _avatar_profile_for(actor)
		var spirit_world: Dictionary = _safe_dictionary(profile.get("spirit_world", {}))
		var meetings: Array = _safe_array(spirit_world.get("meetings", []))

		meetings.append({
			"schema": "eralife.previous_avatar_spirit_knowledge_meeting",
			"version": CONTRACT_VERSION,
			"year": _current_year(),
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": avatar_element,
			"knowledge_gained": knowledge_gain,
			"willpower_gain": willpower_gain,
			"mode": "knowledge"
		})

		while meetings.size() > 24:
			meetings.pop_front()

		spirit_world ["meetings"] = meetings
		spirit_world ["knowledge"] = int(spirit_world.get("knowledge", 0)) + knowledge_gain
		spirit_world ["last_previous_avatar_name"] = avatar_name
		spirit_world ["last_previous_avatar_element"] = avatar_element
		spirit_world ["last_mode"] = "knowledge"
		profile ["spirit_world"] = spirit_world
		_store_avatar_profile(actor, profile)

		var willpower_report: Dictionary = _spirit_world_apply_willpower_knowledge(actor, willpower_gain, {
			"source": "spirit_world_knowledge",
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": avatar_element
		})

		var lesson_line: String = _spirit_world_knowledge_line(avatar_name, avatar_element)
		var diary_text: String = "I entered the Spirit World and asked %s for knowledge. %s" % [
			avatar_name,
			lesson_line
		]
		var world_text: String = "%s entered the Spirit World and returned quieter, steadier, and more aligned with the Avatar Cycle." % _person_label(actor)

		_log_avatar_intervention(actor, null, diary_text, world_text, {
			"intervention_type": "spirit_world_knowledge",
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": avatar_element,
			"knowledge_gained": knowledge_gain,
			"willpower_gain": willpower_gain
		})

		return {
			"success": true,
			"popup_title": "Spirit World Knowledge",
			"popup_text": "You stepped deeper into the Spirit World and listened.\n\n%s did not test your fists.\nThey tested your understanding.\n\n%s\n\nAvatar Knowledge increased by %d.\nWillpower steadied by %d." % [
				avatar_name,
				lesson_line,
				knowledge_gain,
				willpower_gain
			],
			"popup_footer": "Tap anywhere to continue.",
			"diary_text": diary_text,
			"knowledge_gained": knowledge_gain,
			"willpower_gain": willpower_gain,
			"willpower_report": willpower_report.duplicate(true),
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": avatar_element,
		}

	var actor_score: int = _avatar_training_score(actor, avatar_element)
	var avatar_score: int = int(avatar_record.get("spirit_score", 70))
	if avatar_score <= 0:
		avatar_score = 58 + int(rng.randi_range(0, 34))

	var won_duel: bool = actor_score + int(rng.randi_range(-18, 24)) >= avatar_score
	var skill_points: int = 2
	if won_duel:
		skill_points += 2
	if actor_score < avatar_score:
		skill_points += 1
	if avatar_element in ["air", "water", "earth", "fire"]:
		skill_points += 1
	skill_points = clamp(skill_points, 2, 6)

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, skill_points, "spirit_world_previous_avatar_training")

	var training_profile: Dictionary = _avatar_profile_for(actor)
	var training_spirit_world: Dictionary = _safe_dictionary(training_profile.get("spirit_world", {}))
	var training_meetings: Array = _safe_array(training_spirit_world.get("meetings", []))

	training_meetings.append({
		"schema": "eralife.previous_avatar_spirit_meeting",
		"version": CONTRACT_VERSION,
		"year": _current_year(),
		"previous_avatar_name": avatar_name,
		"previous_avatar_element": avatar_element,
		"won_spiritual_duel": won_duel,
		"skill_points_gained": skill_points,
		"actor_score": actor_score,
		"avatar_score": avatar_score,
		"mode": "training"
	})

	while training_meetings.size() > 24:
		training_meetings.pop_front()

	training_spirit_world ["meetings"] = training_meetings
	training_spirit_world ["knowledge"] = int(training_spirit_world.get("knowledge", 0)) + skill_points
	training_spirit_world ["last_previous_avatar_name"] = avatar_name
	training_spirit_world ["last_previous_avatar_element"] = avatar_element
	training_spirit_world ["last_mode"] = "training"
	training_profile ["spirit_world"] = training_spirit_world
	_store_avatar_profile(actor, training_profile)

	var outcome_line: String = "You lost the spiritual duel, but the lesson stayed with you."
	if won_duel:
		outcome_line = "You won the spiritual duel, and the echo accepted your growth."

	var training_diary_text: String = "I entered the Spirit World and trained with %s. %s" % [
		avatar_name,
		outcome_line
	]
	var training_world_text: String = "%s entered the Spirit World and returned changed by the teachings of %s." % [
		_person_label(actor),
		avatar_name
	]

	_log_avatar_intervention(actor, null, training_diary_text, training_world_text, {
		"intervention_type": "spirit_world_training",
		"previous_avatar_name": avatar_name,
		"previous_avatar_element": avatar_element
	})

	return {
		"success": true,
		"popup_title": "Spirit World Training",
		"popup_text": "You entered the Spirit World and met %s.\n\nElemental Echo: %s\nSpiritual Duel: %s\nSkill Points gained: %d\nAvatar Knowledge increased." % [
			avatar_name,
			avatar_element.capitalize(),
			"Won" if won_duel else "Lost",
			skill_points
		],
		"popup_footer": "Tap anywhere to continue.",
		"diary_text": training_diary_text,
		"skill_points_gained": skill_points,
		"won_spiritual_duel": won_duel,
		"previous_avatar_name": avatar_name,
		"previous_avatar_element": avatar_element,
	}
func _spirit_world_knowledge_line(avatar_name: String, avatar_element: String) -> String:
	var clean_element: String = str(avatar_element).strip_edges().to_lower()

	match clean_element:
		"air":
			return "%s taught you that freedom without discipline becomes drift." % avatar_name
		"water":
			return "%s taught you that change is not weakness; it is survival remembering its shape." % avatar_name
		"earth":
			return "%s taught you that patience is not stillness. It is pressure choosing when to move." % avatar_name
		"fire":
			return "%s taught you that power without breath becomes hunger." % avatar_name
		_:
			return "%s spoke through the whole Avatar Cycle, and every element answered at once." % avatar_name
func _spirit_world_apply_willpower_knowledge(actor: Person, amount: int, context: Dictionary = {}) -> Dictionary:
	if actor == null or gs == null:
		return {}

	var clean_amount: int = clamp(int(amount), 0, 12)
	if clean_amount <= 0:
		return {}

	if "willpower_engine" in gs and gs.willpower_engine != null:
		if gs.willpower_engine.has_method("add_willpower"):
			return gs.willpower_engine.add_willpower(actor, clean_amount, context)
		if gs.willpower_engine.has_method("adjust_willpower"):
			return gs.willpower_engine.adjust_willpower(actor, clean_amount, context)
		if gs.willpower_engine.has_method("modify_willpower"):
			return gs.willpower_engine.modify_willpower(actor, clean_amount, context)
		if gs.willpower_engine.has_method("ensure_willpower"):
			return gs.willpower_engine.ensure_willpower(actor, context)

	return {
		"success": false,
		"reason": "No compatible willpower mutation method was available.",
		"amount": clean_amount
	}

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_avatar_influence_contract",
		"duel_intervention_chance": 7,
		"opening_vision_chance": 10,
		"ghost_assist_chance": 8,
		"defense_intervention_chance": 9,
		"low_health_bonus_chance": 22,
		"birth_influence": {
			"latent_potential_bonus_min": 3,
			"latent_potential_bonus_max": 12,
			"combat_memory_bonus_min": 1,
			"combat_memory_bonus_max": 5,
			"knowledge_floor": 1
		},
		"spirit_world": {
			"enabled": true,
			"min_age": 6,
			"skill_points_min": 2,
			"skill_points_max": 6
		},
		"logging": {
			"world_feed": true,
			"life_diary": true,
			"memory": true
		}
	}


func _calculate_birth_influence(actor: Person, previous_avatars: Array, context: Dictionary = {}) -> Dictionary:
	var elemental_memory: Dictionary = {}
	var previous_names: Array = []
	var knowledge: Dictionary = {
		"avatar_cycle_awareness": int(_contract_value("birth_influence.knowledge_floor", 1)),
		"spiritual_pressure": 0,
		"duel_instinct": 0
	}

	for element in ["air", "water", "earth", "fire"]:
		elemental_memory [element] = 0

	var rng: RandomNumberGenerator = _stable_rng(actor, "birth_influence_%s" % str(context.get("source", "birth")))

	for raw_record in previous_avatars:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = raw_record
		var avatar_name: String = str(record.get("name", "Previous Avatar")).strip_edges()
		if avatar_name != "" and avatar_name not in previous_names:
			previous_names.append(avatar_name)

		var element: String = str(record.get("native_element", "")).strip_edges().to_lower()
		if element not in ["air", "water", "earth", "fire"]:
			element = _element_from_nation(str(record.get("nation", "")))

		if element in ["air", "water", "earth", "fire"]:
			elemental_memory [element] = int(elemental_memory.get(element, 0)) + int(rng.randi_range(
				int(_contract_value("birth_influence.latent_potential_bonus_min", 3)),
				int(_contract_value("birth_influence.latent_potential_bonus_max", 12))
			))

		knowledge ["spiritual_pressure"] = int(knowledge.get("spiritual_pressure", 0)) + 1
		knowledge ["duel_instinct"] = int(knowledge.get("duel_instinct", 0)) + int(rng.randi_range(1, 3))

	return {
		"previous_avatar_names": previous_names,
		"elemental_memory": elemental_memory,
		"knowledge": knowledge
	}


func _apply_latent_potential_influence(actor: Person, influence: Dictionary) -> void:
	if actor == null:
		return
	if gs == null or gs.bending_engine == null:
		return
	if not gs.bending_engine.has_method("ensure_bending_potential_state"):
		return

	gs.bending_engine.ensure_bending_potential_state(actor)

	var elemental_memory: Dictionary = _safe_dictionary(influence.get("elemental_memory", {}))
	for raw_element in elemental_memory.keys():
		var element: String = str(raw_element).strip_edges().to_lower()
		if element not in ["air", "water", "earth", "fire"]:
			continue

		var before_value: int = int(actor.bending_latent_potential.get(element, 0))
		var bonus: int = int(elemental_memory.get(element, 0))
		actor.bending_latent_potential [element] = clamp(before_value + bonus, 0, 100)


func _apply_combat_profile_influence(actor: Person, influence: Dictionary) -> void:
	if actor == null:
		return
	if gs == null or gs.bending_engine == null:
		return
	if not gs.bending_engine.has_method("ensure_bending_combat_profile"):
		return

	var profile: Dictionary = gs.bending_engine.ensure_bending_combat_profile(actor)
	var knowledge: Dictionary = _safe_dictionary(influence.get("knowledge", {}))
	var duel_instinct: int = int(knowledge.get("duel_instinct", 0))

	for stat_name in ["accuracy", "counter", "focus", "guard"]:
		profile [stat_name] = clamp(int(profile.get(stat_name, 50)) + clamp(duel_instinct, 0, 9), 0, 100)

	profile ["avatar_influence_applied"] = true
	profile ["avatar_influence_version"] = CONTRACT_VERSION
	actor.bending_combat_profile = profile.duplicate(true)


func _avatar_training_score(actor: Person, element: String) -> int:
	if actor == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	var level: int = 0
	var potential: int = 0
	var focus: int = 50
	var counter: int = 50

	if gs != null and gs.bending_engine != null:
		if gs.bending_engine.has_method("get_bending_level"):
			level = int(gs.bending_engine.get_bending_level(actor, clean_element))
		if gs.bending_engine.has_method("get_bending_latent_potential"):
			potential = int(gs.bending_engine.get_bending_latent_potential(actor, clean_element))
		if gs.bending_engine.has_method("get_bending_combat_stat"):
			focus = int(gs.bending_engine.get_bending_combat_stat(actor, "focus"))
			counter = int(gs.bending_engine.get_bending_combat_stat(actor, "counter"))

	return clamp(int(round(
		float(level) * 0.36
		+ float(potential) * 0.26
		+ float(focus) * 0.2
		+ float(counter) * 0.18
	)), 0, 140)


func _previous_avatar_records_for(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_seed_previous_avatar_history_for_birth"):
		gs.bending_engine._seed_previous_avatar_history_for_birth(actor)

	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return out

	var state_raw: Variant = gs.scenario_state.get("bending_world_championship", {})
	if typeof(state_raw) != TYPE_DICTIONARY:
		return out

	var state: Dictionary = state_raw
	var previous_raw: Variant = state.get("previous_avatars", [])
	if typeof(previous_raw) != TYPE_ARRAY:
		return out

	for raw_record in previous_raw:
		if typeof(raw_record) == TYPE_DICTIONARY:
			out.append((raw_record as Dictionary).duplicate(true))

	out.reverse()
	return out


func _avatar_profile_for(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	if typeof(actor.power_profiles) != TYPE_DICTIONARY:
		actor.power_profiles = {}

	var profiles: Dictionary = actor.power_profiles.duplicate(true)
	var avatar_profile: Dictionary = {}

	if typeof(profiles.get("avatar_influence", {})) == TYPE_DICTIONARY:
		avatar_profile = profiles.get("avatar_influence", {}).duplicate(true)

	if avatar_profile.is_empty():
		avatar_profile = {
			"schema": "eralife.person_avatar_influence_profile",
			"version": CONTRACT_VERSION,
			"birth_influence_seeded": false,
			"previous_avatar_count": 0,
			"previous_avatar_names": [],
			"elemental_memory": {},
			"knowledge": {},
			"interventions": {},
			"spirit_world": {}
		}

	return avatar_profile


func _store_avatar_profile(actor: Person, profile: Dictionary) -> void:
	if actor == null:
		return

	if typeof(actor.power_profiles) != TYPE_DICTIONARY:
		actor.power_profiles = {}

	var profiles: Dictionary = actor.power_profiles.duplicate(true)
	profiles ["avatar_influence"] = profile.duplicate(true)
	actor.power_profiles = profiles


func _log_avatar_intervention(actor: Person, opponent: Person, diary_text: String, world_text: String, meta: Dictionary = {}) -> void:
	if actor == null:
		return

	var logging: Dictionary = _safe_dictionary(active_contract.get("logging", {}))

	if bool(logging.get("life_diary", true)) and gs != null and gs.narrative_engine != null:
		if gs.narrative_engine.has_method("log_event"):
			gs.narrative_engine.log_event(actor, {
				"type": "text",
				"text": diary_text,
				"category": "avatar_influence",
				"meta": meta.duplicate(true)
			})

	if bool(logging.get("memory", true)) and gs != null and gs.memory_engine != null:
		if gs.memory_engine.has_method("remember"):
			gs.memory_engine.remember(int(actor.id), diary_text)

	if bool(logging.get("world_feed", true)) and gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"category": "bending",
			"event_name": "avatar_influence_intervention",
			"source": "avatar_influence_engine",
			"personally_relevant": actor == gs.player or opponent == gs.player,
			"actor_id": int(actor.id),
			"opponent_id": int(opponent.id) if opponent != null else -1,
			"meta": meta.duplicate(true)
		})


func _avatar_dialogue_for(intervention_type: String, avatar_name: String, element: String) -> String:
	var clean_type: String = str(intervention_type).strip_edges().to_lower()
	var clean_element: String = str(element).strip_edges().to_lower()

	match clean_type:
		"scenario_vision":
			return "%s appears in a flash of breath and light: \"Do not fight their body. Read their rhythm.\"" % avatar_name
		"ghost_assist":
			return "%s steps through your shadow and guides your %s bending into the strike." % [avatar_name, clean_element]
		"blue_moon_avatar_state":
			return "%s places a hand over your spirit: \"Now. Let every life before you move as one.\"" % avatar_name
		"ghost_guard":
			return "%s raises a spectral guard beside you, bending the pressure away before it breaks you." % avatar_name

	return "%s whispers from the Avatar cycle: \"You are not alone.\"" % avatar_name


func _empty_intervention(reason: String = "") -> Dictionary:
	return {
		"schema": "eralife.avatar_duel_intervention",
		"version": CONTRACT_VERSION,
		"success": false,
		"triggered": false,
		"reason": reason
	}


func _stable_rng(actor: Person, salt: String) -> RandomNumberGenerator:
	var rng:= RandomNumberGenerator.new()
	var signature: String = "%d|%s|%s|%d|%s" % [
		int(actor.id) if actor != null else 0,
		str(actor.first_name) if actor != null else "",
		str(actor.last_name) if actor != null else "",
		_current_year(),
		str(salt)
	]
	rng.seed = abs(int(signature.hash()))
	return rng


func _contract_value(path: String, fallback: Variant) -> Variant:
	var parts: PackedStringArray = str(path).split(".")
	var cursor: Variant = active_contract

	for part in parts:
		if typeof(cursor) != TYPE_DICTIONARY:
			return fallback
		var dict: Dictionary = cursor
		if not dict.has(part):
			return fallback
		cursor = dict.get(part)

	return cursor


func _element_from_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges().to_lower()

	if clean_nation.find("air") >= 0:
		return "air"
	if clean_nation.find("water") >= 0:
		return "water"
	if clean_nation.find("earth") >= 0:
		return "earth"
	if clean_nation.find("fire") >= 0:
		return "fire"

	return ""


func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	return ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()


func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _merge_dict(base: Dictionary, override: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in override.keys():
		var incoming: Variant = override.get(key)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), incoming)
		else:
			out [key] = incoming

	return out