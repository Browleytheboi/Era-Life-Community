extends Resource
class_name BreedingContractEngine

const ENGINE_SCHEMA:= "eralife.reproduction.breeding_contract_engine"
const CONTRACT_VERSION:= 1
const PREGNANCY_STATE_KEY:= "animal_breeding_pregnancies"
const NAMING_CONTRACT_STATE_KEY:= "animal_birth_naming_contracts"

var gs: GameState = null
var last_report: Dictionary = {}

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()

func breeding_partner_selector_contract(actor: Person, parent_a_entity_id: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null or actor == null:
		return _failure("missing_actor_or_game_state")

	var parent_a: Dictionary = _entity(parent_a_entity_id)
	if parent_a.is_empty():
		return _failure("missing_parent_a")

	var candidates: Array = _breedable_partner_choices(actor, parent_a, context)
	if candidates.is_empty():
		return {
			"success": true,
			"committed": true,
			"type": "animal_breeding_selector",
			"popup_title": "No Compatible Animals",
			"popup_text": "%s has no compatible breeding partner in your household right now.\n\nYou need a mature, healthy animal of the same species with the opposite sex." % str(parent_a.get("display_name", "This animal")),
			"popup_footer": "Visit the animal shop or wait until another animal matures.",
			"choices": [],
			"force_immediate_popup": true,
			"ui_is_pure_renderer": true,
			"commit_authority": ENGINE_SCHEMA
		}

	return {
		"success": true,
		"committed": true,
		"type": "animal_breeding_selector",
		"popup_title": "Choose Breeding Partner",
		"popup_text": "Choose which animal should breed with %s.\n\nThe engine will validate species, sex, maturity, health, household capacity, and environmental pressure before anything becomes real." % str(parent_a.get("display_name", "your animal")),
		"popup_footer": "The button is only a door. The breeding commit happens inside BreedingContractEngine.",
		"choices": candidates.duplicate(true),
		"force_immediate_popup": true,
		"ui_is_pure_renderer": true,
		"commit_authority": ENGINE_SCHEMA
	}

func commit_breeding_pair_from_choice(actor: Person, payload: Dictionary = {}) -> Dictionary:
	return commit_breeding_pair(
		actor,
		str(payload.get("parent_a_entity_id", "")),
		str(payload.get("parent_b_entity_id", "")),
		payload
	)

func commit_breeding_pair(actor: Person, parent_a_entity_id: String, parent_b_entity_id: String, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var validation: Dictionary = validate_breeding_pair(actor, parent_a_entity_id, parent_b_entity_id, context)
	if not bool(validation.get("success", false)):
		return validation

	var mother: Dictionary = _safe_dictionary(validation.get("mother", {}))
	var father: Dictionary = _safe_dictionary(validation.get("father", {}))
	var reproduction: Dictionary = _reproduction_profile_for_entity(mother)
	var reproduction_type: String = str(reproduction.get("type", "mammal_single")).strip_edges().to_lower()

	if reproduction_type == "egg_layer":
		return _commit_egg_laying(actor, mother, father, "natural_breeding", context)

	var pregnancy_id: String = "animal_pregnancy:%s:%s:%d" % [
		str(mother.get("entity_id", "")),
		str(father.get("entity_id", "")),
		int(gs.year if gs != null else 0)
	]

	var pregnancies: Dictionary = _pregnancies()
	if pregnancies.has(pregnancy_id):
		return {
			"success": false,
			"reason": "pregnancy_already_exists",
			"popup_title": "Already Pregnant",
			"popup_text": "%s already has a pregnancy contract in reality." % str(mother.get("display_name", "This animal")),
			"popup_footer": "Age up to let the pregnancy progress."
		}

	var litter_count: int = _roll_litter_count(mother, father, reproduction, pregnancy_id)
	var due_year: int = int(gs.year if gs != null else 0) + max(1, int(reproduction.get("gestation_years", 1)))

	pregnancies [pregnancy_id] = {
		"schema": "eralife.animal_pregnancy_contract",
		"version": CONTRACT_VERSION,
		"id": pregnancy_id,
		"contract_id": pregnancy_id,
		"state": "pregnant",
		"owner_person_id": int(actor.id),
		"mother_entity_id": str(mother.get("entity_id", "")),
		"father_entity_id": str(father.get("entity_id", "")),
		"species_id": str(mother.get("species_id", "")),
		"species_name": str(mother.get("species_name", "Animal")),
		"offspring_label": str(reproduction.get("offspring_label", "baby animal")),
		"offspring_count": litter_count,
		"created_year": int(gs.year if gs != null else 0),
		"due_year": due_year,
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_authority": ENGINE_SCHEMA
	}

	_set_pregnancies(pregnancies)

	_set_entity_flag(str(mother.get("entity_id", "")), "pregnant", true)
	_set_entity_flag(str(mother.get("entity_id", "")), "pregnancy_contract_id", pregnancy_id)

	var text: String = "You bred %s with %s. %s is now pregnant and is expected to give birth in %s." % [
		str(mother.get("display_name", "your animal")),
		str(father.get("display_name", "your animal")),
		str(mother.get("display_name", "She")),
		_format_year_value(due_year)
	]

	_emit_diary_text(actor, text, {
		"type": "animal_breeding",
		"pregnancy_id": pregnancy_id,
		"mother_entity_id": str(mother.get("entity_id", "")),
		"father_entity_id": str(father.get("entity_id", ""))
	})

	return {
		"success": true,
		"committed": true,
		"mode": "animal_pregnancy_contract_created",
		"text": text,
		"diary_text": text,
		"popup_title": "Pregnancy Started",
		"popup_text": text,
		"popup_footer": "Age up to let the pregnancy resolve.",
		"pregnancy_contract": pregnancies [pregnancy_id].duplicate(true),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_pure_renderer": true
	}

func commit_egg_action(actor: Person, entity_id: String, action_id: String, _context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null or actor == null:
		return _failure("missing_actor_or_game_state")

	var egg_layer: Dictionary = _entity(entity_id)
	if egg_layer.is_empty():
		return _failure("missing_egg_layer")

	var reproduction: Dictionary = _reproduction_profile_for_entity(egg_layer)
	if str(reproduction.get("type", "")).strip_edges().to_lower() != "egg_layer":
		return _failure("not_egg_layer")

	if str(egg_layer.get("gender", "")).strip_edges().to_lower() != "female":
		return {
			"success": false,
			"reason": "male_animals_do_not_lay_eggs",
			"popup_title": "No Eggs",
			"popup_text": "%s cannot lay eggs." % str(egg_layer.get("display_name", "This animal")),
			"popup_footer": "You need a female egg-laying animal."
		}

	var stats: Dictionary = _safe_dictionary(egg_layer.get("stats", {}))
	var trust_before: int = clampi(int(stats.get("trust", 50)), 0, 100)
	var stress_before: int = clampi(int(stats.get("stress", 0)), 0, 100)

	var trust_delta: int = 0
	var stress_delta: int = 0
	var hatch_bonus: float = 0.0
	var action_label: String = ""

	match action_id:
		"pet:scare_for_eggs":
			trust_delta = -14
			stress_delta = 22
			hatch_bonus = -0.18
			action_label = "scared"
		"pet:sing_for_eggs":
			trust_delta = 5
			stress_delta = -8
			hatch_bonus = 0.08
			action_label = "sang to"
		_:
			action_label = "waited with"

	stats ["trust"] = clampi(trust_before + trust_delta, 0, 100)
	stats ["stress"] = clampi(stress_before + stress_delta, 0, 100)
	egg_layer ["stats"] = stats
	egg_layer ["updated_at_ms"] = int(Time.get_ticks_msec())

	var died_from_stress: bool = false
	if int(stats.get("stress", 0)) >= 96:
		var death_roll: int = _roll_between(1, 100, "egg_stress_death:%s:%d" % [entity_id, int(Time.get_ticks_msec())])
		if death_roll <= 22:
			died_from_stress = true
			egg_layer ["alive"] = false
			egg_layer ["death_reason"] = "stress_from_forced_egg_collection"

	if typeof(gs.entity_registry) == TYPE_DICTIONARY:
		gs.entity_registry [entity_id] = egg_layer.duplicate(true)

	var egg_count: int = _roll_egg_count(egg_layer, reproduction, "%s:%s:%d" % [entity_id, action_id, int(gs.year if gs != null else 0)])
	var hatch_count: int = 0
	if not died_from_stress:
		hatch_count = _roll_hatch_count(egg_count, reproduction, hatch_bonus, "%s:hatch:%s" % [entity_id, action_id])

	var created_offspring: Array = []
	if hatch_count > 0:
		created_offspring = _create_offspring_entities(
			actor,
			egg_layer,
			{},
			hatch_count,
			"egg_hatched:%s" % entity_id,
			{ "source": action_id}
		)

	var unused_eggs: int = max(0, egg_count - hatch_count)
	if unused_eggs > 0:
		_add_eggs_to_inventory(actor, egg_layer, unused_eggs)

	if not created_offspring.is_empty():
		_emit_birth_naming_contract(actor, egg_layer, {}, created_offspring, {
			"source": action_id,
			"egg_count": egg_count,
			"hatch_count": hatch_count
		})

	var text: String = "You %s %s. %s laid %d egg%s. %d hatched, and %d went into your belongings." % [
		action_label,
		str(egg_layer.get("display_name", "your animal")),
		str(egg_layer.get("display_name", "They")),
		egg_count,
		"" if egg_count == 1 else "s",
		hatch_count,
		unused_eggs
	]

	if died_from_stress:
		text += "\n%s became too stressed and died." % str(egg_layer.get("display_name", "The animal"))

	_emit_diary_text(actor, text, {
		"type": "animal_egg_action",
		"action_id": action_id,
		"entity_id": entity_id
	})

	return {
		"success": true,
		"committed": true,
		"mode": "animal_egg_action_committed",
		"text": text,
		"diary_text": text,
		"popup_title": "Eggs Collected",
		"popup_text": text,
		"popup_footer": "Eggs can be cooked, given away, or kept in belongings.",
		"egg_count": egg_count,
		"hatch_count": hatch_count,
		"unused_eggs": unused_eggs,
		"offspring": created_offspring.duplicate(true),
		"state_delta": {
			"before": {
				"trust": trust_before,
				"stress": stress_before
			},
			"after": {
				"trust": int(stats.get("trust", trust_before)),
				"stress": int(stats.get("stress", stress_before))
			},
			"affected_stats": ["trust", "stress"]
		},
		"bond_delta": -7 if action_id == "pet:scare_for_eggs" else 3,
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_pure_renderer": true
	}

func yearly_tick(_payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return _failure("missing_game_state")

	var resolved_births: Array = []
	var pregnancies: Dictionary = _pregnancies()
	var current_year: int = int(gs.year)

	for raw_id in pregnancies.keys():
		var pregnancy_id: String = str(raw_id)
		var pregnancy: Dictionary = _safe_dictionary(pregnancies.get(raw_id, {}))
		if pregnancy.is_empty():
			continue
		if str(pregnancy.get("state", "pregnant")) != "pregnant":
			continue
		if int(pregnancy.get("due_year", current_year + 1)) > current_year:
			continue

		var mother: Dictionary = _entity(str(pregnancy.get("mother_entity_id", "")))
		var father: Dictionary = _entity(str(pregnancy.get("father_entity_id", "")))
		if mother.is_empty():
			pregnancy ["state"] = "failed_missing_mother"
			pregnancies [pregnancy_id] = pregnancy
			continue

		var actor: Person = _actor_by_id(int(pregnancy.get("owner_person_id", -1)))
		if actor == null:
			pregnancy ["state"] = "failed_missing_owner"
			pregnancies [pregnancy_id] = pregnancy
			continue

		var offspring_count: int = max(1, int(pregnancy.get("offspring_count", 1)))
		var offspring: Array = _create_offspring_entities(actor, mother, father, offspring_count, pregnancy_id, {
			"source": "animal_pregnancy_yearly_tick"
		})

		_set_entity_flag(str(mother.get("entity_id", "")), "pregnant", false)
		_set_entity_flag(str(mother.get("entity_id", "")), "pregnancy_contract_id", "")

		pregnancy ["state"] = "resolved_birth"
		pregnancy ["resolved_year"] = current_year
		pregnancy ["offspring_entity_ids"] = _entity_ids_from_entities(offspring)
		pregnancy ["updated_at_ms"] = int(Time.get_ticks_msec())
		pregnancies [pregnancy_id] = pregnancy

		_emit_birth_naming_contract(actor, mother, father, offspring, {
			"source": "pregnancy_yearly_tick",
			"pregnancy_id": pregnancy_id
		})

		var text: String = "%s just had %d baby %s%s." % [
			str(mother.get("display_name", "Your animal")),
			offspring.size(),
			str(pregnancy.get("offspring_label", "animal")),
			"" if offspring.size() == 1 else "s"
		]

		_emit_diary_text(actor, text, {
			"type": "animal_birth",
			"pregnancy_id": pregnancy_id
		})

		resolved_births.append({
			"pregnancy_id": pregnancy_id,
			"mother_entity_id": str(mother.get("entity_id", "")),
			"father_entity_id": str(father.get("entity_id", "")),
			"offspring": offspring.duplicate(true),
			"text": text
		})

	_set_pregnancies(pregnancies)

	last_report = {
		"success": true,
		"mode": "breeding_contract_engine_yearly_tick",
		"resolved_birth_count": resolved_births.size(),
		"resolved_births": resolved_births.duplicate(true),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func validate_breeding_pair(actor: Person, parent_a_entity_id: String, parent_b_entity_id: String, _context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return _failure("missing_actor_or_game_state")

	var parent_a: Dictionary = _entity(parent_a_entity_id)
	var parent_b: Dictionary = _entity(parent_b_entity_id)

	if parent_a.is_empty() or parent_b.is_empty():
		return _failure("missing_parent_entity")

	if str(parent_a.get("entity_id", "")) == str(parent_b.get("entity_id", "")):
		return _failure("same_parent_entity")

	if not bool(parent_a.get("alive", true)) or not bool(parent_b.get("alive", true)):
		return _failure("dead_animals_cannot_breed")

	if int(parent_a.get("owner_person_id", -1)) != int(actor.id) or int(parent_b.get("owner_person_id", -1)) != int(actor.id):
		return _failure("actor_does_not_own_both_animals")

	var species_a: String = str(parent_a.get("species_id", "")).strip_edges().to_lower()
	var species_b: String = str(parent_b.get("species_id", "")).strip_edges().to_lower()
	if species_a == "" or species_a != species_b:
		return _failure("species_incompatible")

	var gender_a: String = str(parent_a.get("gender", "")).strip_edges().to_lower()
	var gender_b: String = str(parent_b.get("gender", "")).strip_edges().to_lower()
	if not ((gender_a == "male" and gender_b == "female") or (gender_a == "female" and gender_b == "male")):
		return _failure("requires_male_and_female")

	var mother: Dictionary = parent_a if gender_a == "female" else parent_b
	var father: Dictionary = parent_b if gender_a == "female" else parent_a
	var reproduction: Dictionary = _reproduction_profile_for_entity(mother)

	if bool(mother.get("pregnant", false)):
		return _failure("mother_already_pregnant")

	var maturity_age: int = int(reproduction.get("maturity_age", 1))
	if int(parent_a.get("age", parent_a.get("age_years", 0))) < maturity_age:
		return _failure("parent_a_not_mature")
	if int(parent_b.get("age", parent_b.get("age_years", 0))) < maturity_age:
		return _failure("parent_b_not_mature")

	var min_health: int = int(reproduction.get("min_health", 45))
	if _health_value(parent_a) < min_health or _health_value(parent_b) < min_health:
		return _failure("health_too_low")

	if _stress_value(parent_a) >= 86 or _stress_value(parent_b) >= 86:
		return _failure("stress_too_high")

	var expected_count: int = max(1, int(reproduction.get("litter_max", reproduction.get("egg_max", 1))))
	var capacity_report: Dictionary = _capacity_report_for_actor(actor, expected_count)
	if not bool(capacity_report.get("can_add", true)):
		return {
			"success": false,
			"reason": "household_animal_capacity_exceeded",
			"popup_title": "Too Many Animals",
			"popup_text": "Your household cannot responsibly support another litter right now.\n\nCurrent animals: %d\nCeiling: %d\nEnvironmental pressure: %d%%" % [
				int(capacity_report.get("current_count", 0)),
				int(capacity_report.get("ceiling", 0)),
				int(capacity_report.get("pressure", 0))
			],
			"popup_footer": "Raise wealth/class support, reduce animal count, or wait.",
			"capacity_report": capacity_report.duplicate(true)
		}

	return {
		"success": true,
		"mother": mother.duplicate(true),
		"father": father.duplicate(true),
		"reproduction": reproduction.duplicate(true),
		"capacity_report": capacity_report.duplicate(true)
	}

func _breedable_partner_choices(actor: Person, parent_a: Dictionary, context: Dictionary = {}) -> Array:
	var out: Array = []
	var parent_a_id: String = str(parent_a.get("entity_id", ""))
	var species_id: String = str(parent_a.get("species_id", "")).strip_edges().to_lower()

	if gs == null or actor == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return out

	for raw_id in gs.entity_registry.keys():
		var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(raw_id, {}))
		if entity.is_empty():
			continue
		if str(entity.get("entity_id", "")) == parent_a_id:
			continue
		if str(entity.get("entity_type", entity.get("entity_kind", ""))).strip_edges().to_lower() != "animal":
			continue
		if int(entity.get("owner_person_id", -1)) != int(actor.id):
			continue
		if str(entity.get("species_id", "")).strip_edges().to_lower() != species_id:
			continue

		var validation: Dictionary = validate_breeding_pair(actor, parent_a_id, str(entity.get("entity_id", "")), context)
		if not bool(validation.get("success", false)):
			continue

		var preview: Dictionary = _offspring_preview(parent_a, entity, _safe_dictionary(validation.get("reproduction", {})))
		out.append({
			"id": "breed:%s:%s" % [parent_a_id, str(entity.get("entity_id", ""))],
			"label": "Breed with %s" % str(entity.get("display_name", "Animal")),
			"text": "Breed %s with %s" % [str(parent_a.get("display_name", "Animal")), str(entity.get("display_name", "Animal"))],
			"journal_text": "",
			"detail_action": "engine_call",
			"engine_property": "breeding_contract_engine",
			"method": "commit_breeding_pair_from_choice",
			"payload": {
				"parent_a_entity_id": parent_a_id,
				"parent_b_entity_id": str(entity.get("entity_id", "")),
				"preview": preview.duplicate(true),
				"source": "breeding_selector_choice"
			},
			"preview_lines": _safe_array(preview.get("lines", []))
		})

	return out

func _commit_egg_laying(actor: Person, mother: Dictionary, father: Dictionary = {}, source: String = "egg_laying", context: Dictionary = {}) -> Dictionary:
	var reproduction: Dictionary = _reproduction_profile_for_entity(mother)
	var egg_count: int = _roll_egg_count(mother, reproduction, "%s:%s:%d" % [str(mother.get("entity_id", "")), source, int(gs.year if gs != null else 0)])
	var hatch_count: int = _roll_hatch_count(egg_count, reproduction, 0.0, "%s:hatch:%s" % [str(mother.get("entity_id", "")), source])
	var unused_eggs: int = max(0, egg_count - hatch_count)

	var offspring: Array = []
	if hatch_count > 0:
		offspring = _create_offspring_entities(actor, mother, father, hatch_count, source, context)
		_emit_birth_naming_contract(actor, mother, father, offspring, {
			"source": source,
			"egg_count": egg_count,
			"hatch_count": hatch_count
		})

	if unused_eggs > 0:
		_add_eggs_to_inventory(actor, mother, unused_eggs)

	var text: String = "%s laid %d egg%s. %d hatched, and %d went into your belongings." % [
		str(mother.get("display_name", "Your animal")),
		egg_count,
		"" if egg_count == 1 else "s",
		hatch_count,
		unused_eggs
	]

	_emit_diary_text(actor, text, {
		"type": "animal_egg_laying",
		"mother_entity_id": str(mother.get("entity_id", "")),
		"father_entity_id": str(father.get("entity_id", ""))
	})

	return {
		"success": true,
		"committed": true,
		"mode": "animal_eggs_resolved",
		"text": text,
		"diary_text": text,
		"popup_title": "Eggs Laid",
		"popup_text": text,
		"popup_footer": "Hatched babies were added to the relationship graph.",
		"egg_count": egg_count,
		"hatch_count": hatch_count,
		"unused_eggs": unused_eggs,
		"offspring": offspring.duplicate(true),
		"commit_authority": ENGINE_SCHEMA
	}

func _create_offspring_entities(actor: Person, mother: Dictionary, father: Dictionary, count: int, seed_key: String, _context: Dictionary = {}) -> Array:
	var out: Array = []
	if gs == null or gs.animal_contract_engine == null:
		return out

	var species_id: String = str(mother.get("species_id", "animal"))
	var reproduction: Dictionary = _reproduction_profile_for_entity(mother)
	var baby_label: String = str(reproduction.get("offspring_label", "baby animal"))

	for i in range(max(1, count)):
		var baby_name: String = gs.animal_contract_engine.default_name_for_species(species_id, "%s:baby:%d" % [seed_key, i])
		var baby: Dictionary = gs.animal_contract_engine.create_animal_entity(species_id, int(actor.id), {
			"source": ENGINE_SCHEMA,
			"name": baby_name,
			"age": 0,
			"gender": _roll_gender("%s:gender:%d" % [seed_key, i]),
			"hunger": 12,
			"trust": 42,
			"mother_entity_id": str(mother.get("entity_id", "")),
			"father_entity_id": str(father.get("entity_id", "")),
			"offspring_label": baby_label
		})

		if baby.is_empty():
			continue

		out.append(baby.duplicate(true))

		_commit_graph_edge(str(mother.get("entity_id", "")), str(baby.get("entity_id", "")), "animal_parent_child", ["animal", "family", "parent", "offspring"], "Mother", baby_label.capitalize(), 80)
		if not father.is_empty():
			_commit_graph_edge(str(father.get("entity_id", "")), str(baby.get("entity_id", "")), "animal_parent_child", ["animal", "family", "parent", "offspring"], "Father", baby_label.capitalize(), 76)

	for i in range(out.size()):
		for j in range(i + 1, out.size()):
			var left: Dictionary = _safe_dictionary(out [i])
			var right: Dictionary = _safe_dictionary(out [j])
			_commit_graph_edge(str(left.get("entity_id", "")), str(right.get("entity_id", "")), "animal_sibling", ["animal", "family", "sibling", "littermate"], "Sibling", "Sibling", 64)

	return out

func _emit_birth_naming_contract(actor: Person, mother: Dictionary, father: Dictionary, offspring: Array, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null or offspring.is_empty():
		return {}

	var contract_id: String = "animal_birth_names:%d:%s:%d" % [
		int(actor.id),
		str(mother.get("entity_id", "mother")).replace(":", "_"),
		int(Time.get_ticks_msec())
	]

	var slots: Array = []
	for raw_baby in offspring:
		var baby: Dictionary = _safe_dictionary(raw_baby)
		slots.append({
			"entity_id": str(baby.get("entity_id", "")),
			"current_name": str(baby.get("display_name", "Baby")),
			"generated_name": str(baby.get("display_name", "Baby")),
			"species_id": str(baby.get("species_id", "")),
			"species_name": str(baby.get("species_name", "Animal")),
			"gender": str(baby.get("gender", "unknown"))
		})

	var contracts: Dictionary = _safe_dictionary(gs.scenario_state.get(NAMING_CONTRACT_STATE_KEY, {}))
	contracts [contract_id] = {
		"schema": "eralife.animal_birth_naming_contract",
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"target_id": int(actor.id),
		"mother_entity_id": str(mother.get("entity_id", "")),
		"father_entity_id": str(father.get("entity_id", "")),
		"offspring_entity_ids": _entity_ids_from_entities(offspring),
		"name_slots": slots.duplicate(true),
		"state": "pending_name_confirmation",
		"created_year": int(gs.year if gs != null else 0),
		"created_at_ms": int(Time.get_ticks_msec()),
		"source": str(context.get("source", "animal_birth"))
	}
	gs.scenario_state [NAMING_CONTRACT_STATE_KEY] = contracts

	if gs.scenario_popup_contract_engine != null:
		var title_text: String = "%s Had Babies" % str(mother.get("display_name", "Your Animal"))
		var overview_text: String = "%s just had %d baby %s%s. Name them now, keep the generated names, or randomize them." % [
			str(mother.get("display_name", "Your animal")),
			offspring.size(),
			str(mother.get("species_name", "animal")).to_lower(),
			"" if offspring.size() == 1 else "s"
		]

		return gs.scenario_popup_contract_engine.emit_popup_contract({
			"id": contract_id,
			"target": int(actor.id),
			"category": "animals",
			"request": "animal_birth_naming",
			"title": title_text,
			"overview": overview_text,
			"details": overview_text,
			"urgency": 72.0,
			"escalates_after_ms": 45000,
			"response_options": [
				{
					"id": "keep_generated_names",
					"label": "Keep Generated Names",
					"text": "You kept the generated names.",
					"journal_text": "%s's babies were named." % str(mother.get("display_name", "Your animal"))
				},
				{
					"id": "randomize_names",
					"label": "Randomize Names",
					"text": "You asked for new animal names.",
					"journal_text": "You randomized the baby animal names."
				}
			],
			"input_slots": slots.duplicate(true),
			"source_result": {
				"animal_birth_naming_contract": contracts [contract_id].duplicate(true)
			}
		}, {
			"source": ENGINE_SCHEMA,
			"target_id": int(actor.id)
		})

	return {
		"success": true,
		"contract_id": contract_id
	}

func _add_eggs_to_inventory(actor: Person, layer: Dictionary, amount: int) -> void:
	if gs == null or actor == null or amount <= 0:
		return
	if gs.belongings_engine == null or not gs.belongings_engine.has_method("add_item"):
		return

	var item_id: int = int(Time.get_ticks_usec())
	if "next_id" in gs:
		item_id = int(gs.next_id)
		gs.next_id += 1

	var year_text: String = _format_year_value(int(gs.year if gs != null else 0))
	gs.belongings_engine.add_item(actor, {
		"id": item_id,
		"name": "%s Eggs" % str(layer.get("species_name", "Animal")),
		"type": "Food",
		"quantity": amount,
		"stackable": true,
		"source_entity_id": str(layer.get("entity_id", "")),
		"source_entity_name": str(layer.get("display_name", "")),
		"lore": "Eggs dropped from %s in the year %s." % [
			str(layer.get("display_name", "an egg-laying creature")),
			year_text
		],
		"description": "Eggs dropped from %s in the year %s." % [
			str(layer.get("display_name", "an egg-laying creature")),
			year_text
		],
		"edible": true,
		"cookable": true,
		"era_cooking_hint": "Cook over a fire." if _current_era_name().to_lower().find("ancient") >= 0 else "Cook before eating."
	}, "Food")

func _commit_graph_edge(subject_entity_id: String, object_entity_id: String, relationship_type: String, tags: Array, subject_role: String, object_role: String, bond: int) -> Dictionary:
	if gs == null or gs.relationship_graph_contract_engine == null:
		return {}

	return gs.relationship_graph_contract_engine.commit_relationship_event({
		"producer": ENGINE_SCHEMA,
		"event_type": relationship_type,
		"relationship_type": relationship_type,
		"relationship_tags": tags.duplicate(true),
		"subject_entity_id": subject_entity_id,
		"object_entity_id": object_entity_id,
		"subject_role": subject_role,
		"object_role": object_role,
		"bond": bond
	}, {
		"producer": ENGINE_SCHEMA
	})

func _offspring_preview(parent_a: Dictionary, parent_b: Dictionary, reproduction: Dictionary) -> Dictionary:
	var min_count: int = int(reproduction.get("litter_min", reproduction.get("egg_min", 1)))
	var max_count: int = int(reproduction.get("litter_max", reproduction.get("egg_max", min_count)))
	var baby_label: String = str(reproduction.get("offspring_label", "baby animal"))

	return {
		"species_id": str(parent_a.get("species_id", "")),
		"species_name": str(parent_a.get("species_name", "Animal")),
		"baby_label": baby_label,
		"count_range": "%d-%d" % [min_count, max_count],
		"lines": [
			"Species: %s" % str(parent_a.get("species_name", "Animal")),
			"Potential babies: %d-%d %s%s" % [min_count, max_count, baby_label, "" if max_count == 1 else "s"],
			"Trait inheritance: behavior traits + stat baselines + rare mutations",
			"Parents: %s + %s" % [str(parent_a.get("display_name", "Animal")), str(parent_b.get("display_name", "Animal"))]
		]
	}

func _capacity_report_for_actor(actor: Person, expected_new_animals: int = 1) -> Dictionary:
	var current_count: int = _owned_animal_count(actor)
	var ceiling: int = _animal_household_ceiling(actor)
	var pressure: int = int(round((float(current_count + max(0, expected_new_animals)) / float(max(1, ceiling))) * 100.0))

	return {
		"current_count": current_count,
		"expected_new_animals": expected_new_animals,
		"ceiling": ceiling,
		"pressure": pressure,
		"can_add": current_count + expected_new_animals <= ceiling
	}

func _animal_household_ceiling(actor: Person) -> int:
	if actor == null:
		return 2

	var class_key: String = str(actor.social_class).strip_edges().to_lower()
	if bool(actor.is_royal) or bool(actor.is_ruler) or class_key.find("royal") >= 0:
		return 12
	if class_key.find("noble") >= 0:
		return 8
	if class_key.find("merchant") >= 0:
		return 5
	if class_key.find("common") >= 0:
		return 2
	if class_key.find("lower") >= 0 or class_key.find("peasant") >= 0 or class_key.find("slave") >= 0:
		return 2
	return 3

func _owned_animal_count(actor: Person) -> int:
	if gs == null or actor == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return 0

	var count: int = 0
	for raw_id in gs.entity_registry.keys():
		var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(raw_id, {}))
		if entity.is_empty():
			continue
		if str(entity.get("entity_type", entity.get("entity_kind", ""))).strip_edges().to_lower() != "animal":
			continue
		if int(entity.get("owner_person_id", -1)) == int(actor.id) and bool(entity.get("alive", true)):
			count += 1
	return count

func _reproduction_profile_for_entity(entity: Dictionary) -> Dictionary:
	var species_contract: Dictionary = _safe_dictionary(entity.get("species_contract", entity.get("species", {})))
	var reproduction: Dictionary = _safe_dictionary(species_contract.get("reproduction", {}))
	if not reproduction.is_empty():
		return reproduction.duplicate(true)

	return {
		"type": "mammal_single",
		"maturity_age": 2,
		"gestation_years": 1,
		"litter_min": 1,
		"litter_max": 1,
		"offspring_label": "baby animal",
		"min_health": 45
	}

func _roll_litter_count(_mother: Dictionary, _father: Dictionary, reproduction: Dictionary, seed_key: String) -> int:
	var low: int = max(1, int(reproduction.get("litter_min", 1)))
	var high: int = max(low, int(reproduction.get("litter_max", low)))
	var base_count: int = _roll_between(low, high, seed_key)

	var mutation_roll: int = _roll_between(1, 1000, "%s:mutation" % seed_key)
	if mutation_roll <= int(reproduction.get("mutation_chance_per_1000", 8)):
		base_count += 1

	return base_count

func _roll_egg_count(layer: Dictionary, reproduction: Dictionary, seed_key: String) -> int:
	var low: int = max(1, int(reproduction.get("egg_min", 1)))
	var high: int = max(low, int(reproduction.get("egg_max", low)))
	var stats: Dictionary = _safe_dictionary(layer.get("stats", {}))
	var trust_value: int = clampi(int(stats.get("trust", 50)), 0, 100)
	var bonus: int = 0
	if trust_value >= 80:
		bonus = 2
	elif trust_value >= 60:
		bonus = 1
	return max(1, _roll_between(low, high, seed_key) + bonus)

func _roll_hatch_count(egg_count: int, reproduction: Dictionary, hatch_bonus: float, seed_key: String) -> int:
	var hatch_rate: float = clamp(float(reproduction.get("hatch_rate", 0.35)) + hatch_bonus, 0.0, 1.0)
	var hatched: int = 0
	for i in range(max(0, egg_count)):
		var roll: int = _roll_between(1, 100, "%s:%d" % [seed_key, i])
		if roll <= int(round(hatch_rate * 100.0)):
			hatched += 1
	return hatched

func _health_value(entity: Dictionary) -> int:
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	return clampi(int(stats.get("health", 100)), 0, max(1, int(stats.get("health_max", 100))))

func _stress_value(entity: Dictionary) -> int:
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	return clampi(int(stats.get("stress", 0)), 0, 100)

func _set_entity_flag(entity_id: String, key: String, value: Variant) -> void:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return
	var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(entity_id, {}))
	if entity.is_empty():
		return
	entity [key] = value
	entity ["updated_at_ms"] = int(Time.get_ticks_msec())
	gs.entity_registry [entity_id] = entity.duplicate(true)

func _entity(entity_id: String) -> Dictionary:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return {}
	return _safe_dictionary(gs.entity_registry.get(entity_id, {})).duplicate(true)

func _entity_ids_from_entities(entities: Array) -> Array:
	var out: Array = []
	for raw_entity in entities:
		var entity: Dictionary = _safe_dictionary(raw_entity)
		var entity_id: String = str(entity.get("entity_id", "")).strip_edges()
		if entity_id != "":
			out.append(entity_id)
	return out

func _actor_by_id(actor_id: int) -> Person:
	if gs == null or actor_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(actor_id)
		if found != null:
			return found
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var restored = gs.get_or_reactivate_npc_by_id(actor_id)
		if restored != null:
			return restored
	return null

func _pregnancies() -> Dictionary:
	_ensure_state()
	return _safe_dictionary(gs.scenario_state.get(PREGNANCY_STATE_KEY, {})).duplicate(true)

func _set_pregnancies(pregnancies: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [PREGNANCY_STATE_KEY] = pregnancies.duplicate(true)

func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if typeof(gs.scenario_state.get(PREGNANCY_STATE_KEY, {})) != TYPE_DICTIONARY:
		gs.scenario_state [PREGNANCY_STATE_KEY] = {}
	if typeof(gs.scenario_state.get(NAMING_CONTRACT_STATE_KEY, {})) != TYPE_DICTIONARY:
		gs.scenario_state [NAMING_CONTRACT_STATE_KEY] = {}

func _emit_diary_text(actor: Person, text: String, meta: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return

	if gs.life_diary_contract_engine != null and gs.life_diary_contract_engine.has_method("emit_diary_intent"):
		gs.life_diary_contract_engine.emit_diary_intent({
			"type": "animal_reproduction",
			"actor_id": int(actor.id),
			"lines": clean_text.split("\n"),
			"source": ENGINE_SCHEMA,
			"preserve_lines_exactly": true,
			"meta": meta.duplicate(true)
		}, {
			"source": ENGINE_SCHEMA
		})

func _roll_between(min_value: int, max_value: int, seed_key: String) -> int:
	var low: int = min(min_value, max_value)
	var high: int = max(min_value, max_value)
	if low == high:
		return low
	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(str(seed_key).hash())
	return rng.randi_range(low, high)

func _roll_gender(seed_key: String) -> String:
	return "male" if _roll_between(1, 100, seed_key) <= 50 else "female"

func _format_year_value(year_value: int) -> String:
	if year_value < 0:
		return "%d BCE" % abs(year_value)
	return "%d CE" % year_value

func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.get("name", gs.era.get("id", ""))) if typeof(gs.era) == TYPE_DICTIONARY else str(gs.era.name)
	return "modern"

func _failure(reason: String, extra: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var out: Dictionary = {
		"success": false,
		"reason": reason,
		"popup_title": "Breeding Failed",
		"popup_text": str(reason).replace("_", " ").capitalize(),
		"popup_footer": "No animal reality was committed.",
		"commit_authority": ENGINE_SCHEMA
	}
	for raw_key in extra.keys():
		out [raw_key] = extra.get(raw_key)
	return out

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []