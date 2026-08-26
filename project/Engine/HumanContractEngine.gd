extends Resource
class_name HumanContractEngine

const ENGINE_SCHEMA:= "eralife.entity_definition.human_contract_engine"
const ENTITY_KIND:= "human"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func define_entity_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var age: int = _safe_int_property(person, "age", 0)
	var entity_id: String = human_entity_id(person)

	var health_value: int = clampi(
		int(round(_safe_float_property(person, "health", 100.0))),
		0,
		_health_display_max(person)
	)
	var hunger_value: int = clampi(
		_safe_int_property(person, "hunger", 0),
		0,
		100
	)
	var mental_value: int = clampi(
		_safe_int_property(person, "mental_health", 100),
		0,
		100
	)
	var smarts_value: int = clampi(
		_safe_int_property(person, "smarts", 50),
		0,
		100
	)
	var looks_value: int = clampi(
		_safe_int_property(person, "looks", 50),
		0,
		100
	)
	var happiness_value: int = clampi(
		_safe_int_property_from_aliases(person, ["happiness", "satisfaction"], 50),
		0,
		100
	)
	var imagination_value: int = clampi(
		_safe_int_property(person, "imagination", 0),
		0,
		100
	)

	var stats: Dictionary = {
		"health": health_value,
		"hunger": hunger_value,
		"mental": mental_value,
		"smarts": smarts_value,
		"looks": looks_value,
		"happiness": happiness_value,
		"satisfaction": happiness_value,
		"imagination": imagination_value
	}

	return {
		"schema": "eralife.entity_definition.human",
		"version": CONTRACT_VERSION,
		"entity_id": entity_id,
		"entity_kind": ENTITY_KIND,
		"entity_type": "human",
		"source_person_id": _safe_int_property(person, "id", 0),
		"display_name": _display_name(person),
		"first_name": str(_safe_variant_property(person, "first_name", "")),
		"last_name": str(_safe_variant_property(person, "last_name", "")),
		"gender": str(_safe_variant_property(person, "gender", "")),
		"age": age,
		"life_stage": life_stage_for_age(age),
		"alive": _safe_bool_property(person, "alive", true) and health_value > 0,
		"stats": stats.duplicate(true),
		"valid_stat_ranges": valid_stat_ranges(age),
		"developmental_rules": developmental_rules(age),
		"biological_constraints": biological_constraints(person),
		"capability_flags": capability_flags(person),
		"lifecycle_rules": lifecycle_rules(person),
		"context": context.duplicate(true),
		"contract_authority": ENGINE_SCHEMA,
		"does_not_execute_behavior": true,
		"stat_source_aliases": {
			"happiness": "Person.satisfaction",
			"satisfaction": "Person.satisfaction",
			"imagination": "Person.imagination"
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}
func human_entity_id(person: Person) -> String:
	if person == null:
		return "human:0"
	return "human:%d" % int(person.id)

func valid_stat_ranges(_age: int = 0) -> Dictionary:
	return {
		"health": { "min": 0, "max": 100},
		"hunger": { "min": 0, "max": 100},
		"mental": { "min": 0, "max": 100},
		"smarts": { "min": 0, "max": 100},
		"looks": { "min": 0, "max": 100},
		"happiness": { "min": 0, "max": 100, "source_property": "satisfaction"},
		"satisfaction": { "min": 0, "max": 100, "alias_of": "happiness"},
		"imagination": { "min": 0, "max": 100},
		"fertility": { "min": 0, "max": 100, "active_from_age": 13, "soft_gate_age": 18},
		"bank_balance": { "min": -999999999, "max": 999999999}
	}

func developmental_rules(age: int) -> Dictionary:
	return {
		"life_stage": life_stage_for_age(age),
		"minor": age < 18,
		"adult": age >= 18,
		"elder": age >= 65,
		"can_hold_job": age >= 14,
		"can_sign_major_contracts": age >= 18,
		"can_adopt_pet_without_guardian": age >= 18,
		"guardian_required_for_pet_shop": age < 18
	}

func biological_constraints(person: Person) -> Dictionary:
	return {
		"mortal": true,
		"base_species": "human",
		"max_mortal_age": int(GameState.MAX_MORTAL_AGE),
		"can_be_parent": int(person.age) >= 13 if person != null else false,
	}

func capability_flags(person: Person) -> Dictionary:
	if person == null:
		return {}

	return {
		"can_form_relationships": bool(person.alive),
		"can_have_pet_relationships": bool(person.alive),
		"can_be_pet_owner": bool(person.alive),
		"can_be_guardian_for_minor_pet_owner": bool(person.alive) and int(person.age) >= 18,
		"can_switch_lens": bool(person.alive) and float(person.health) > 0.0,
	}

func lifecycle_rules(_person: Person) -> Dictionary:
	return {
		"birth_entity_kind": ENTITY_KIND,
		"age_unit": "years",
		"age_source": "Person.age",
		"death_source": "HealthEngine/Person.alive",
		"dead_relationship_section": "dead"
	}

func life_stage_for_age(age: int) -> String:
	if age <= 1:
		return "infant"
	if age < 4:
		return "toddler"
	if age < 13:
		return "child"
	if age < 18:
		return "teen"
	if age < 65:
		return "adult"
	return "elder"

func _display_name(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = "%s %s" % [str(person.first_name).strip_edges(), str(person.last_name).strip_edges()]
	full_name = full_name.strip_edges()
	if full_name == "":
		return "Unknown"
	return full_name

func _health_display_max(person: Person) -> int:
	if person == null:
		return 100

	var health_value: float = _safe_float_property(person, "health", 100.0)
	return max(1, int(round(max(100.0, health_value))))
func _safe_variant_property(target: Object, property_name: String, fallback: Variant = null) -> Variant:
	if target == null:
		return fallback

	var clean_name: String = str(property_name).strip_edges()
	if clean_name == "":
		return fallback

	for property_info in target.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue

		if str(property_info.get("name", "")) == clean_name:
			return target.get(clean_name)

	return fallback


func _safe_int_property(target: Object, property_name: String, fallback: int = 0) -> int:
	var value: Variant = _safe_variant_property(target, property_name, fallback)
	if value == null:
		return fallback

	return int(value)


func _safe_float_property(target: Object, property_name: String, fallback: float = 0.0) -> float:
	var value: Variant = _safe_variant_property(target, property_name, fallback)
	if value == null:
		return fallback

	return float(value)


func _safe_bool_property(target: Object, property_name: String, fallback: bool = false) -> bool:
	var value: Variant = _safe_variant_property(target, property_name, fallback)
	if value == null:
		return fallback

	return bool(value)


func _safe_int_property_from_aliases(target: Object, property_names: Array, fallback: int = 0) -> int:
	if target == null:
		return fallback

	for raw_name in property_names:
		var property_name: String = str(raw_name).strip_edges()
		if property_name == "":
			continue

		var value: Variant = _safe_variant_property(target, property_name, null)
		if value == null:
			continue

		return int(value)

	return fallback