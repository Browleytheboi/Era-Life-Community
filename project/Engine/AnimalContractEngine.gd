extends Resource
class_name AnimalContractEngine

const ENGINE_SCHEMA:= "eralife.entity_definition.animal_contract_engine"
const ENTITY_KIND:= "animal"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func species_registry() -> Dictionary:
	return {
		"dog": {
			"display_name": "Dog",
			"lifespan_min": 10,
			"lifespan_max": 16,
			"behavior_traits": ["loyal", "playful", "protective"],
			"intelligence_min": 45,
			"intelligence_max": 85,
			"trainable": true,
			"danger_level": 1,
			"social_type": "pack",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 180,
			"yearly_maintenance_cost": 120,
			"birth_family_weight": 38,
			"reproduction": { "type": "mammal_litter", "maturity_age": 2, "gestation_years": 1, "litter_min": 1, "litter_max": 6, "offspring_label": "puppy", "min_health": 45, "mutation_chance_per_1000": 8}
		},
		"cat": {
			"display_name": "Cat",
			"lifespan_min": 12,
			"lifespan_max": 20,
			"behavior_traits": ["independent", "curious", "affectionate"],
			"intelligence_min": 40,
			"intelligence_max": 78,
			"trainable": true,
			"danger_level": 1,
			"social_type": "solitary_social",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 120,
			"yearly_maintenance_cost": 95,
			"birth_family_weight": 34,
			"reproduction": { "type": "mammal_litter", "maturity_age": 1, "gestation_years": 1, "litter_min": 1, "litter_max": 5, "offspring_label": "kitten", "min_health": 42, "mutation_chance_per_1000": 8}
		},
		"horse": {
			"display_name": "Horse",
			"lifespan_min": 22,
			"lifespan_max": 32,
			"behavior_traits": ["strong", "sensitive", "trainable"],
			"intelligence_min": 35,
			"intelligence_max": 72,
			"trainable": true,
			"danger_level": 2,
			"social_type": "herd",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 1400,
			"yearly_maintenance_cost": 620,
			"birth_family_weight": 4,
			"reproduction": { "type": "mammal_single", "maturity_age": 3, "gestation_years": 1, "litter_min": 1, "litter_max": 1, "offspring_label": "foal", "min_health": 55, "mutation_chance_per_1000": 5}
		},
		"cow": {
			"display_name": "Cow",
			"lifespan_min": 14,
			"lifespan_max": 22,
			"behavior_traits": ["gentle", "herd_bound", "useful"],
			"intelligence_min": 28,
			"intelligence_max": 58,
			"trainable": false,
			"danger_level": 1,
			"social_type": "herd",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 850,
			"yearly_maintenance_cost": 420,
			"birth_family_weight": 9,
			"reproduction": { "type": "mammal_single", "maturity_age": 2, "gestation_years": 1, "litter_min": 1, "litter_max": 1, "offspring_label": "calf", "min_health": 50, "mutation_chance_per_1000": 4}
		},
		"chicken": {
			"display_name": "Chicken",
			"lifespan_min": 5,
			"lifespan_max": 10,
			"behavior_traits": ["skittish", "routine_bound", "productive"],
			"intelligence_min": 18,
			"intelligence_max": 42,
			"trainable": false,
			"danger_level": 0,
			"social_type": "flock",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 35,
			"yearly_maintenance_cost": 28,
			"birth_family_weight": 18,
			"reproduction": { "type": "egg_layer", "maturity_age": 1, "egg_min": 3, "egg_max": 12, "hatch_rate": 0.32, "offspring_label": "chick", "min_health": 35, "mutation_chance_per_1000": 10}
		},
		"sheep": {
			"display_name": "Sheep",
			"lifespan_min": 10,
			"lifespan_max": 14,
			"behavior_traits": ["gentle", "flock_bound", "nervous"],
			"intelligence_min": 22,
			"intelligence_max": 48,
			"trainable": false,
			"danger_level": 0,
			"social_type": "flock",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 180,
			"yearly_maintenance_cost": 120,
			"birth_family_weight": 10,
			"reproduction": { "type": "mammal_small_litter", "maturity_age": 1, "gestation_years": 1, "litter_min": 1, "litter_max": 2, "offspring_label": "lamb", "min_health": 42, "mutation_chance_per_1000": 5}
		},
		"goat": {
			"display_name": "Goat",
			"lifespan_min": 12,
			"lifespan_max": 18,
			"behavior_traits": ["stubborn", "social", "resourceful"],
			"intelligence_min": 35,
			"intelligence_max": 68,
			"trainable": true,
			"danger_level": 1,
			"social_type": "herd",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 110,
			"yearly_maintenance_cost": 90,
			"birth_family_weight": 12,
			"reproduction": { "type": "mammal_small_litter", "maturity_age": 1, "gestation_years": 1, "litter_min": 1, "litter_max": 3, "offspring_label": "kid", "min_health": 40, "mutation_chance_per_1000": 7}
		},
		"crow": {
			"display_name": "Crow",
			"lifespan_min": 7,
			"lifespan_max": 14,
			"behavior_traits": ["clever", "watchful", "mischievous"],
			"intelligence_min": 60,
			"intelligence_max": 92,
			"trainable": true,
			"danger_level": 1,
			"social_type": "flock",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 160,
			"yearly_maintenance_cost": 70,
			"birth_family_weight": 4,
			"reproduction": { "type": "egg_layer", "maturity_age": 2, "egg_min": 2, "egg_max": 5, "hatch_rate": 0.28, "offspring_label": "crow chick", "min_health": 45, "mutation_chance_per_1000": 12}
		},
		"raven": {
			"display_name": "Raven",
			"lifespan_min": 10,
			"lifespan_max": 25,
			"behavior_traits": ["ominous", "clever", "bonded"],
			"intelligence_min": 65,
			"intelligence_max": 96,
			"trainable": true,
			"danger_level": 2,
			"social_type": "bonded_pair",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 260,
			"yearly_maintenance_cost": 90,
			"birth_family_weight": 3,
			"reproduction": { "type": "egg_layer", "maturity_age": 2, "egg_min": 2, "egg_max": 5, "hatch_rate": 0.24, "offspring_label": "raven chick", "min_health": 48, "mutation_chance_per_1000": 14}
		},
		"duck": {
			"display_name": "Duck",
			"lifespan_min": 6,
			"lifespan_max": 12,
			"behavior_traits": ["social", "noisy", "water_loving"],
			"intelligence_min": 20,
			"intelligence_max": 45,
			"trainable": false,
			"danger_level": 0,
			"social_type": "flock",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 45,
			"yearly_maintenance_cost": 32,
			"birth_family_weight": 10,
			"reproduction": { "type": "egg_layer", "maturity_age": 1, "egg_min": 4, "egg_max": 10, "hatch_rate": 0.35, "offspring_label": "duckling", "min_health": 35, "mutation_chance_per_1000": 8}
		},
		"goose": {
			"display_name": "Goose",
			"lifespan_min": 10,
			"lifespan_max": 20,
			"behavior_traits": ["territorial", "loud", "protective"],
			"intelligence_min": 24,
			"intelligence_max": 52,
			"trainable": false,
			"danger_level": 1,
			"social_type": "flock",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 70,
			"yearly_maintenance_cost": 42,
			"birth_family_weight": 7,
			"reproduction": { "type": "egg_layer", "maturity_age": 1, "egg_min": 3, "egg_max": 8, "hatch_rate": 0.3, "offspring_label": "gosling", "min_health": 38, "mutation_chance_per_1000": 8}
		},
		"pig": {
			"display_name": "Pig",
			"lifespan_min": 10,
			"lifespan_max": 15,
			"behavior_traits": ["smart", "food_driven", "social"],
			"intelligence_min": 50,
			"intelligence_max": 82,
			"trainable": true,
			"danger_level": 1,
			"social_type": "sounder",
			"eras": ["ancient", "medieval", "industrial", "modern", "future", "all"],
			"base_price": 240,
			"yearly_maintenance_cost": 170,
			"birth_family_weight": 8,
			"reproduction": { "type": "mammal_litter", "maturity_age": 1, "gestation_years": 1, "litter_min": 3, "litter_max": 10, "offspring_label": "piglet", "min_health": 45, "mutation_chance_per_1000": 8}
		},
		"wolf": {
			"display_name": "Wolf",
			"lifespan_min": 8,
			"lifespan_max": 14,
			"behavior_traits": ["pack_bound", "alert", "wild"],
			"intelligence_min": 55,
			"intelligence_max": 86,
			"trainable": true,
			"danger_level": 5,
			"social_type": "pack",
			"eras": ["ancient", "medieval", "industrial", "modern", "future"],
			"base_price": 700,
			"yearly_maintenance_cost": 360,
			"birth_family_weight": 1,
			"reproduction": { "type": "mammal_litter", "maturity_age": 2, "gestation_years": 1, "litter_min": 2, "litter_max": 6, "offspring_label": "wolf pup", "min_health": 60, "mutation_chance_per_1000": 10}
		},
		"coyote": {
			"display_name": "Coyote",
			"lifespan_min": 8,
			"lifespan_max": 14,
			"behavior_traits": ["sly", "alert", "wild"],
			"intelligence_min": 50,
			"intelligence_max": 80,
			"trainable": true,
			"danger_level": 4,
			"social_type": "pair_or_pack",
			"eras": ["ancient", "medieval", "industrial", "modern", "future"],
			"base_price": 420,
			"yearly_maintenance_cost": 240,
			"birth_family_weight": 1,
			"reproduction": { "type": "mammal_litter", "maturity_age": 2, "gestation_years": 1, "litter_min": 2, "litter_max": 6, "offspring_label": "coyote pup", "min_health": 55, "mutation_chance_per_1000": 10}
		},
		"lion": {
			"display_name": "Lion",
			"lifespan_min": 10,
			"lifespan_max": 18,
			"behavior_traits": ["dominant", "dangerous", "pride_bound"],
			"intelligence_min": 48,
			"intelligence_max": 78,
			"trainable": false,
			"danger_level": 9,
			"social_type": "pride",
			"eras": ["ancient", "medieval", "industrial", "modern", "future"],
			"base_price": 5000,
			"yearly_maintenance_cost": 2200,
			"birth_family_weight": 0,
			"reproduction": { "type": "mammal_litter", "maturity_age": 3, "gestation_years": 1, "litter_min": 1, "litter_max": 4, "offspring_label": "cub", "min_health": 70, "mutation_chance_per_1000": 15}
		},
		"tiger": {
			"display_name": "Tiger",
			"lifespan_min": 10,
			"lifespan_max": 20,
			"behavior_traits": ["solitary", "dangerous", "powerful"],
			"intelligence_min": 50,
			"intelligence_max": 82,
			"trainable": false,
			"danger_level": 10,
			"social_type": "solitary",
			"eras": ["ancient", "medieval", "industrial", "modern", "future"],
			"base_price": 6500,
			"yearly_maintenance_cost": 2600,
			"birth_family_weight": 0,
			"reproduction": { "type": "mammal_litter", "maturity_age": 3, "gestation_years": 1, "litter_min": 1, "litter_max": 4, "offspring_label": "cub", "min_health": 72, "mutation_chance_per_1000": 15}
		},
		"camel": {
			"display_name": "Camel",
			"lifespan_min": 25,
			"lifespan_max": 40,
			"behavior_traits": ["enduring", "stubborn", "desert_bred"],
			"intelligence_min": 32,
			"intelligence_max": 62,
			"trainable": true,
			"danger_level": 2,
			"social_type": "herd",
			"eras": ["ancient", "medieval", "industrial", "modern", "future"],
			"base_price": 1100,
			"yearly_maintenance_cost": 340,
			"birth_family_weight": 2,
			"reproduction": { "type": "mammal_single", "maturity_age": 3, "gestation_years": 1, "litter_min": 1, "litter_max": 1, "offspring_label": "calf", "min_health": 55, "mutation_chance_per_1000": 5}
		},
		"rabbit": {
			"display_name": "Rabbit",
			"lifespan_min": 7,
			"lifespan_max": 12,
			"behavior_traits": ["gentle", "skittish", "quiet"],
			"intelligence_min": 28,
			"intelligence_max": 58,
			"trainable": true,
			"danger_level": 0,
			"social_type": "colony",
			"eras": ["industrial", "modern", "future", "all"],
			"base_price": 70,
			"yearly_maintenance_cost": 40,
			"birth_family_weight": 14,
			"reproduction": { "type": "mammal_litter", "maturity_age": 1, "gestation_years": 1, "litter_min": 2, "litter_max": 8, "offspring_label": "kit", "min_health": 35, "mutation_chance_per_1000": 10}
		},
		"falcon": {
			"display_name": "Falcon",
			"lifespan_min": 12,
			"lifespan_max": 18,
			"behavior_traits": ["sharp", "alert", "hunter"],
			"intelligence_min": 52,
			"intelligence_max": 82,
			"trainable": true,
			"danger_level": 3,
			"social_type": "bonded_handler",
			"eras": ["ancient", "medieval", "future"],
			"base_price": 900,
			"yearly_maintenance_cost": 260,
			"birth_family_weight": 2,
			"reproduction": { "type": "egg_layer", "maturity_age": 2, "egg_min": 2, "egg_max": 4, "hatch_rate": 0.22, "offspring_label": "eyas", "min_health": 55, "mutation_chance_per_1000": 12}
		}
	}
func _transport_species_registry_expansion() -> Dictionary:
	return {
		"camel": {
			"display_name": "Camel",
			"lifespan_min": 35,
			"lifespan_max": 50,
			"behavior_traits": [
				"enduring",
				"desert_adapted",
				"trainable"
			],
			"intelligence_min": 34,
			"intelligence_max": 68,
			"trainable": true,
			"danger_level": 2,
			"social_type": "herd",
			"eras": [
				"ancient",
				"medieval",
				"industrial",
				"modern",
				"future",
				"all"
			],
			"base_price": 1650,
			"yearly_maintenance_cost": 540,
			"birth_family_weight": 2,
			"reproduction": {
				"type": "mammal_single",
				"maturity_age": 4,
				"gestation_years": 1,
				"litter_min": 1,
				"litter_max": 1,
				"offspring_label": "calf",
				"min_health": 52,
				"mutation_chance_per_1000": 4
			}
		},
		"donkey": {
			"display_name": "Donkey",
			"lifespan_min": 25,
			"lifespan_max": 40,
			"behavior_traits": [
				"sure_footed",
				"stubborn",
				"dependable"
			],
			"intelligence_min": 38,
			"intelligence_max": 70,
			"trainable": true,
			"danger_level": 1,
			"social_type": "herd",
			"eras": [
				"ancient",
				"medieval",
				"industrial",
				"modern",
				"future",
				"all"
			],
			"base_price": 720,
			"yearly_maintenance_cost": 320,
			"birth_family_weight": 3,
			"reproduction": {
				"type": "mammal_single",
				"maturity_age": 3,
				"gestation_years": 1,
				"litter_min": 1,
				"litter_max": 1,
				"offspring_label": "foal",
				"min_health": 48,
				"mutation_chance_per_1000": 4
			}
		},
		"elephant": {
			"display_name": "Elephant",
			"lifespan_min": 55,
			"lifespan_max": 75,
			"behavior_traits": [
				"powerful",
				"social",
				"high_memory"
			],
			"intelligence_min": 68,
			"intelligence_max": 94,
			"trainable": true,
			"danger_level": 5,
			"social_type": "herd",
			"eras": [
				"ancient",
				"medieval",
				"industrial",
				"modern",
				"future",
				"all"
			],
			"base_price": 9200,
			"yearly_maintenance_cost": 2800,
			"birth_family_weight": 1,
			"reproduction": {
				"type": "mammal_single",
				"maturity_age": 10,
				"gestation_years": 2,
				"litter_min": 1,
				"litter_max": 1,
				"offspring_label": "calf",
				"min_health": 62,
				"mutation_chance_per_1000": 2
			}
		},
		"ox": {
			"display_name": "Ox",
			"lifespan_min": 15,
			"lifespan_max": 25,
			"behavior_traits": [
				"strong",
				"patient",
				"work_trained"
			],
			"intelligence_min": 30,
			"intelligence_max": 58,
			"trainable": true,
			"danger_level": 2,
			"social_type": "herd",
			"eras": [
				"ancient",
				"medieval",
				"industrial",
				"modern",
				"future",
				"all"
			],
			"base_price": 1050,
			"yearly_maintenance_cost": 460,
			"birth_family_weight": 3,
			"reproduction": {
				"type": "mammal_single",
				"maturity_age": 2,
				"gestation_years": 1,
				"litter_min": 1,
				"litter_max": 1,
				"offspring_label": "calf",
				"min_health": 54,
				"mutation_chance_per_1000": 3
			}
		}
	}
func define_species(
	species_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_species: String = str(
		species_id
	).strip_edges().to_lower()
	var registry: Dictionary = species_registry()

	registry.merge(
		_transport_species_registry_expansion(),
		true
	)

	if not registry.has(clean_species):
		return {}

	var base: Dictionary = (
		registry [clean_species] as Dictionary
	).duplicate(true)
	base ["schema"] = "eralife.entity_definition.animal_species"
	base ["version"] = CONTRACT_VERSION
	base ["species_id"] = clean_species
	base ["entity_kind"] = ENTITY_KIND
	base ["contract_authority"] = ENGINE_SCHEMA
	base ["defines_rules_only"] = true
	base ["does_not_execute_behavior"] = true
	base ["context"] = context.duplicate(true)

	return base

func create_animal_entity(
	species_id: String,
	owner_person_id: int = 0,
	context: Dictionary = {}
) -> Dictionary:
	var species: Dictionary = define_species(
		species_id,
		context
	)

	if species.is_empty():
		return {}

	if not species_allowed_in_current_era(
		str(
			species.get(
				"species_id",
				""
			)
		)
	):
		return {}

	var entity_id: String = (
		"animal:%d"
		% _next_entity_sequence()
	)

	var lifespan: int = _roll_lifespan(
		species,
		entity_id
	)

	var smarts: int = _roll_between(
		int(
			species.get(
				"intelligence_min",
				30
			)
		),
		int(
			species.get(
				"intelligence_max",
				70
			)
		),
		"%s:smarts" % entity_id
	)

	var instinct: int = _roll_between(
		28,
		92,
		"%s:instinct" % entity_id
	)

	var display_name: String = str(
		context.get(
			"name",
			""
		)
	).strip_edges()

	if display_name == "":
		display_name = default_name_for_species(
			str(
				species.get(
					"species_id",
					"animal"
				)
			),
			entity_id
		)

	var gender: String = str(
		context.get(
			"gender",
			""
		)
	).strip_edges().to_lower()

	if gender not in [
		"male",
		"female"
	]:
		gender = (
			"male"
			if _roll_between(
				1,
				100,
				"%s:gender" % entity_id
			) <= 50
			else "female"
		)

	var reproduction: Dictionary = _safe_dictionary(
		species.get(
			"reproduction",
			{}
		)
	)

	var sub_species: Dictionary = (
		_resolve_sub_species(
			str(
				species.get(
					"species_id",
					species_id
				)
			),
			entity_id,
			context
		)
	)

	var age_years: int = maxi(
		0,
		int(
			context.get(
				"age",
				context.get(
					"age_years",
					0
				)
			)
		)
	)

	var entity: Dictionary = {
		"schema": "eralife.entity.animal",
		"version": CONTRACT_VERSION,
		"entity_id": entity_id,
		"entity_kind": ENTITY_KIND,
		"entity_type": "animal",
		"species_id": str(
			species.get(
				"species_id",
				"animal"
			)
		),
		"species_name": str(
			species.get(
				"display_name",
				"Animal"
			)
		),
		"sub_species_id": str(
			sub_species.get(
				"id",
				""
			)
		),
		"sub_species_name": str(
			sub_species.get(
				"display_name",
				""
			)
		),
		"display_name": display_name,
		"gender": gender,
		"sex": gender,
		"age": age_years,
		"age_years": age_years,
		# Birth anchor. Pets had NO aging path at all -- nothing in the yearly tick
		# touched them, so a pet stayed the age it was created at forever. Rather
		# than add another accumulator that would need its own drain and catch-up
		# (see the NPC aging notes), age is DERIVED from this via
		# resolve_animal_lifecycle(). Written once, never updated.
		"birth_year": (
			int(gs.year) - age_years
			if gs != null
			else -1
		),
		"lifespan_years": lifespan,
		"alive": true,
		"pregnant": false,
		"pregnancy_contract_id": "",
		"owner_person_id": owner_person_id,
		"household_pet_anchor_id": int(
			context.get(
				"household_pet_anchor_id",
				owner_person_id
			)
		),
		"household_access_actor_id": int(
			context.get(
				"household_access_actor_id",
				owner_person_id
			)
		),
		"mother_entity_id": str(
			context.get(
				"mother_entity_id",
				""
			)
		),
		"father_entity_id": str(
			context.get(
				"father_entity_id",
				""
			)
		),
		"offspring_label": str(
			context.get(
				"offspring_label",
				reproduction.get(
					"offspring_label",
					"baby animal"
				)
			)
		),
		"behavior_traits": (
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
		),
		"trainable": bool(
			species.get(
				"trainable",
				false
			)
		),
		"danger_level": int(
			species.get(
				"danger_level",
				0
			)
		),
		"social_type": str(
			species.get(
				"social_type",
				"unknown"
			)
		),
		"last_fed_food_id": "",
		"last_fed_food_name": "",
		"stuffed": false,
		"stats": {
			"health": 100,
			"health_max": 100,
			"hunger": int(
				context.get(
					"hunger",
					22
				)
			),
			"smarts": smarts,
			"instinct": instinct,
			"trust": int(
				context.get(
					"trust",
					50
				)
			),
			"training": int(
				context.get(
					"training",
					0
				)
			),
			"stress": int(
				context.get(
					"stress",
					0
				)
			),
			"fertility": int(
				context.get(
					"fertility",
					_roll_between(
						35,
						90,
						"%s:fertility"
						% entity_id
					)
				)
			),
			"bloodthirst": int(
				context.get(
					"bloodthirst",
					0
				)
			)
		},
		"reproduction_contract": (
			reproduction.duplicate(false)
		),
		"species_contract": species,
		"sub_species_contract": sub_species,
		"contract_authority": ENGINE_SCHEMA,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	var defer_relationship_graph: bool = bool(
		context.get(
			"defer_relationship_graph_registration",
			false
		)
	)

	_register_entity(
		entity,
		defer_relationship_graph
	)

	if bool(
		context.get(
			"compact_entity_receipt",
			false
		)
	):
		return {
			"entity_id": entity_id,
			"entity_kind": ENTITY_KIND,
			"species_id": str(
				entity.get(
					"species_id",
					""
				)
			),
			"species_name": str(
				entity.get(
					"species_name",
					"Animal"
				)
			),
			"sub_species_id": str(
				entity.get(
					"sub_species_id",
					""
				)
			),
			"sub_species_name": str(
				entity.get(
					"sub_species_name",
					""
				)
			),
			"display_name": display_name,
			"gender": gender,
			"age_years": age_years,
			"owner_person_id": owner_person_id,
		}

	return entity.duplicate(true)
func rename_owned_animal(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"popup_title": "Rename Companion",
			"popup_text": (
				"No active owner could be resolved."
			),
			"popup_footer": (
				"Nothing was changed."
			)
		}

	var entity_id: String = str(
		payload.get(
			"entity_id",
			""
		)
	).strip_edges()

	var new_name: String = str(
		payload.get(
			"new_name",
			""
		)
	).strip_edges()

	if (
		entity_id == ""
		or new_name == ""
	):
		return {
			"success": false,
			"popup_title": "Rename Companion",
			"popup_text": (
				"Enter a name before saving."
			),
			"popup_footer": (
				"Your companion kept their current name."
			)
		}

	if new_name.length() > 32:
		new_name = new_name.substr(
			0,
			32
		).strip_edges()

	var entity_raw: Variant = gs.entity_registry.get(
		entity_id,
		{}
	)

	if typeof(entity_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"popup_title": "Rename Companion",
			"popup_text": (
				"That companion is no longer resident."
			),
			"popup_footer": (
				"Nothing was changed."
			)
		}

	var entity: Dictionary = (
		entity_raw as Dictionary
	)

	if str(
		entity.get(
			"entity_kind",
			""
		)
	) != ENTITY_KIND:
		return {
			"success": false,
			"popup_title": "Rename Companion",
			"popup_text": (
				"That entity is not an animal."
			),
			"popup_footer": (
				"Nothing was changed."
			)
		}

	var actor_id: int = int(
		actor.id
	)

	var owns_entity: bool = (
		int(
			entity.get(
				"owner_person_id",
				-1
			)
		) == actor_id
		or int(
			entity.get(
				"household_pet_anchor_id",
				-1
			)
		) == actor_id
		or int(
			entity.get(
				"household_access_actor_id",
				-1
			)
		) == actor_id
	)

	if not owns_entity:
		return {
			"success": false,
			"popup_title": "Rename Companion",
			"popup_text": (
				"You do not hold naming authority for this animal."
			),
			"popup_footer": (
				"Nothing was changed."
			)
		}

	var previous_name: String = str(
		entity.get(
			"display_name",
			"Companion"
		)
	)

	entity [
		"display_name"
	] = new_name
	entity [
		"last_renamed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	entity [
		"last_renamed_by_person_id"
	] = actor_id

	gs.entity_registry [
		entity_id
	] = entity

	call_deferred(
		"_sync_renamed_entity_to_relationship_graph",
		entity_id,
		actor_id
	)

	return {
		"success": true,
		"text": (
			"%s is now named %s."
			% [
				previous_name,
				new_name
			]
		),
		"popup_title": "Companion Renamed",
		"popup_text": (
			"%s is now named %s."
			% [
				previous_name,
				new_name
			]
		),
		"popup_footer": (
			"The new name will stream into your PETS tab."
		),
		"entity_id": entity_id,
		"previous_name": previous_name,
		"new_name": new_name,
	}


func _sync_renamed_entity_to_relationship_graph(
	entity_id: String,
	renamed_by_actor_id: int
) -> void:
	if gs == null:
		return

	var entity_raw: Variant = gs.entity_registry.get(
		entity_id,
		{}
	)

	if typeof(entity_raw) != TYPE_DICTIONARY:
		return

	var entity: Dictionary = (
		entity_raw as Dictionary
	).duplicate(false)

	var renamed_by_actor: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == renamed_by_actor_id
	):
		renamed_by_actor = gs.player
	elif gs.has_method(
		"get_npc_by_id"
	):
		renamed_by_actor = gs.get_npc_by_id(
			renamed_by_actor_id
		)

	if gs.relationship_graph_contract_engine != null:
		gs.relationship_graph_contract_engine.ensure_entity(
			entity,
			{
				"source": (
					"animal_rename_identity_tail"
				),
				"ui_blocking_forbidden": true
			}
		)

		var owner_person_id: int = int(
			entity.get(
				"owner_person_id",
				renamed_by_actor_id
			)
		)

		var owner: Person = null

		if (
			gs.player != null
			and int(
				gs.player.id
			) == owner_person_id
		):
			owner = gs.player
		elif gs.has_method(
			"get_npc_by_id"
		):
			owner = gs.get_npc_by_id(
				owner_person_id
			)

		if owner == null:
			owner = renamed_by_actor

		if owner != null:
			var owner_entity: Dictionary = (
				gs.relationship_graph_contract_engine
				.ensure_person_entity(
					owner,
					{
						"source": (
							"animal_rename_identity_tail"
						)
					}
				)
			)

			gs.relationship_graph_contract_engine.commit_relationship_event(
				{
					"producer": ENGINE_SCHEMA,
					"event_type": (
						"pet_identity_renamed"
					),
					"relationship_type": "pet",
					"relationship_tags": [
						"pet",
						"animal",
						"identity_updated"
					],
					"subject_entity_id": str(
						owner_entity.get(
							"entity_id",
							""
						)
					),
					"object_entity_id": entity_id,
					"subject_role": "Owner",
					"object_role": "Pet",
					"renamed_by_person_id": renamed_by_actor_id,
					"context": {
						"source": (
							"animal_rename_identity_tail"
						),
						"ui_blocking_forbidden": true
					}
				},
				{
					"producer": ENGINE_SCHEMA
				}
			)

	_emit_pet_rename_diary_tail(
		renamed_by_actor,
		entity
	)

	_queue_pet_relationship_projection_tail(
		renamed_by_actor_id,
		"pet_identity_renamed"
	)
func _emit_pet_rename_diary_tail(
	actor: Person,
	entity: Dictionary
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

	var new_name: String = str(
		entity.get(
			"display_name",
			"my companion"
		)
	).strip_edges()

	var gender: String = str(
		entity.get(
			"gender",
			""
		)
	).strip_edges().to_lower()

	var pronoun: String = "them"

	match gender:
		"male":
			pronoun = "him"
		"female":
			pronoun = "her"
		_:
			pronoun = "them"

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
				"animal"
			)
		)
	).strip_edges()

	var identity_parts: Array = []

	if gender != "":
		identity_parts.append(
			gender
		)

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
		identity_text = "animal"

	var diary_text: String = (
		"I renamed %s, a %s, to %s."
		% [
			pronoun,
			identity_text,
			new_name
		]
	)

	gs.life_diary_contract_engine.emit_diary_intent(
		{
			"type": "action_event",
			"actor_id": int(
				actor.id
			),
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
				"pet_rename:%s:%d"
				% [
					entity_id,
					int(
						entity.get(
							"last_renamed_at_ms",
							0
						)
					)
				]
			),
			"source": (
				"animal_contract_engine."
				+ "rename_diary_tail"
			),
			"meta": {
				"entity_id": entity_id,
				"ui_blocking_forbidden": true
			}
		},
		{
			"source": (
				"animal_contract_engine."
				+ "rename_diary_tail"
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
				"animal_contract_engine."
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
func _resolve_sub_species(species_id: String, seed_key: String, context: Dictionary = {}) -> Dictionary:
	var forced: String = str(context.get("sub_species_id", "")).strip_edges().to_lower()
	var pool: Array = _sub_species_pool_for_species(species_id)
	var era_name: String = _current_era_name().to_lower()
	var era_valid: Array = []

	for raw_row in pool:
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue
		if forced != "" and str(row.get("id", "")) == forced:
			return row.duplicate(true)
		var eras: Array = _safe_array(row.get("eras", ["all"]))
		if eras.has("all"):
			era_valid.append(row)
			continue
		for raw_era in eras:
			if era_name.find(str(raw_era).to_lower()) >= 0:
				era_valid.append(row)
				break

	if era_valid.is_empty():
		return { "id": "%s_common" % species_id, "display_name": str(species_id).capitalize(), "eras": ["all"]}

	var index: int = _roll_between(0, era_valid.size() - 1, "%s:subspecies" % seed_key)
	return _safe_dictionary(era_valid [index]).duplicate(true)

func _sub_species_pool_for_species(
	species_id: String
) -> Array:
	match str(
		species_id
	).strip_edges().to_lower():
		"dog":
			return [
				{ "id": "saluki", "display_name": "Saluki", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "basenji", "display_name": "Basenji", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "tibetan_mastiff", "display_name": "Tibetan Mastiff", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "village_cur", "display_name": "Village Cur", "eras": ["ancient", "medieval"]},
				{ "id": "ashyard_hound", "display_name": "Ashyard Hound", "eras": ["ancient", "medieval"]},
				{ "id": "labrador", "display_name": "Labrador Retriever", "eras": ["industrial", "modern", "future"]},
				{ "id": "german_shepherd", "display_name": "German Shepherd", "eras": ["industrial", "modern", "future"]}
			]

		"cat":
			return [
				{ "id": "egyptian_mau", "display_name": "Egyptian Mau", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "alley_cat", "display_name": "Alley Cat", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "barn_cat", "display_name": "Barn Cat", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "persian", "display_name": "Persian", "eras": ["medieval", "industrial", "modern", "future"]},
				{ "id": "maine_coon", "display_name": "Maine Coon", "eras": ["industrial", "modern", "future"]}
			]

		"horse":
			return [
				{ "id": "steppe_horse", "display_name": "Steppe Horse", "eras": ["ancient", "medieval"]},
				{ "id": "desert_courser", "display_name": "Desert Courser", "eras": ["ancient", "medieval"]},
				{ "id": "warhorse", "display_name": "Warhorse", "eras": ["medieval"]},
				{ "id": "workhorse", "display_name": "Workhorse", "eras": ["industrial", "modern"]},
				{ "id": "racing_horse", "display_name": "Racing Horse", "eras": ["industrial", "modern", "future"]}
			]

		"cow":
			return [
				{ "id": "aurochs_bloodline", "display_name": "Aurochs-Blooded Cow", "eras": ["ancient"]},
				{ "id": "village_cow", "display_name": "Village Cow", "eras": ["ancient", "medieval"]},
				{ "id": "highland_cow", "display_name": "Highland Cow", "eras": ["medieval", "industrial", "modern", "future"]},
				{ "id": "dairy_cow", "display_name": "Dairy Cow", "eras": ["industrial", "modern", "future"]}
			]

		"chicken":
			return [
				{ "id": "junglefowl_line", "display_name": "Junglefowl Line", "eras": ["ancient"]},
				{ "id": "village_hen", "display_name": "Village Chicken", "eras": ["ancient", "medieval"]},
				{ "id": "speckled_layer", "display_name": "Speckled Layer", "eras": ["medieval", "industrial", "modern", "future"]},
				{ "id": "modern_layer", "display_name": "Modern Layer", "eras": ["industrial", "modern", "future"]}
			]

		"sheep":
			return [
				{ "id": "desert_sheep", "display_name": "Desert Sheep", "eras": ["ancient", "medieval"]},
				{ "id": "wool_sheep", "display_name": "Wool Sheep", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "blackface_sheep", "display_name": "Blackface Sheep", "eras": ["medieval", "industrial", "modern", "future"]}
			]

		"goat":
			return [
				{ "id": "mountain_goat", "display_name": "Mountain Goat", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "village_goat", "display_name": "Village Goat", "eras": ["ancient", "medieval"]},
				{ "id": "milk_goat", "display_name": "Milk Goat", "eras": ["industrial", "modern", "future"]}
			]

		"crow", "raven":
			return [
				{ "id": "blackwing", "display_name": "Blackwing", "eras": ["all"]},
				{ "id": "graveyard_line", "display_name": "Graveyard Line", "eras": ["ancient", "medieval"]},
				{ "id": "city_scavenger", "display_name": "City Scavenger", "eras": ["industrial", "modern", "future"]}
			]

		"pig":
			return [
				{ "id": "wild_boar_line", "display_name": "Wild Boar Line", "eras": ["ancient", "medieval"]},
				{ "id": "village_pig", "display_name": "Village Pig", "eras": ["ancient", "medieval"]},
				{ "id": "farm_pig", "display_name": "Farm Pig", "eras": ["industrial", "modern", "future"]}
			]

		"duck":
			return [
				{ "id": "mallard", "display_name": "Mallard", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "pekin", "display_name": "Pekin Duck", "eras": ["industrial", "modern", "future"]},
				{ "id": "muscovy", "display_name": "Muscovy Duck", "eras": ["medieval", "industrial", "modern", "future"]}
			]

		"goose":
			return [
				{ "id": "greylag", "display_name": "Greylag Goose", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "toulouse", "display_name": "Toulouse Goose", "eras": ["industrial", "modern", "future"]},
				{ "id": "embden", "display_name": "Embden Goose", "eras": ["industrial", "modern", "future"]}
			]

		"rabbit":
			return [
				{ "id": "dutch", "display_name": "Dutch Rabbit", "eras": ["industrial", "modern", "future"]},
				{ "id": "rex", "display_name": "Rex Rabbit", "eras": ["industrial", "modern", "future"]},
				{ "id": "flemish_giant", "display_name": "Flemish Giant Rabbit", "eras": ["industrial", "modern", "future"]},
				{ "id": "mini_lop", "display_name": "Mini Lop Rabbit", "eras": ["modern", "future"]},
				{ "id": "lionhead", "display_name": "Lionhead Rabbit", "eras": ["modern", "future"]}
			]

		"wolf":
			return [
				{ "id": "gray_wolf", "display_name": "Gray Wolf", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "arctic_wolf", "display_name": "Arctic Wolf", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "indian_wolf", "display_name": "Indian Wolf", "eras": ["ancient", "medieval", "industrial", "modern", "future"]}
			]

		"coyote":
			return [
				{ "id": "plains_coyote", "display_name": "Plains Coyote", "eras": ["industrial", "modern", "future"]},
				{ "id": "desert_coyote", "display_name": "Desert Coyote", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "eastern_coyote", "display_name": "Eastern Coyote", "eras": ["industrial", "modern", "future"]}
			]

		"lion":
			return [
				{ "id": "african_lion", "display_name": "African Lion", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "asiatic_lion", "display_name": "Asiatic Lion", "eras": ["ancient", "medieval", "industrial", "modern", "future"]}
			]

		"tiger":
			return [
				{ "id": "bengal_tiger", "display_name": "Bengal Tiger", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "siberian_tiger", "display_name": "Siberian Tiger", "eras": ["industrial", "modern", "future"]},
				{ "id": "sumatran_tiger", "display_name": "Sumatran Tiger", "eras": ["industrial", "modern", "future"]}
			]

		"camel":
			return [
				{ "id": "dromedary", "display_name": "Dromedary Camel", "eras": ["ancient", "medieval", "industrial", "modern", "future"]},
				{ "id": "bactrian", "display_name": "Bactrian Camel", "eras": ["ancient", "medieval", "industrial", "modern", "future"]}
			]

		"falcon":
			return [
				{ "id": "peregrine", "display_name": "Peregrine Falcon", "eras": ["ancient", "medieval", "future"]},
				{ "id": "saker", "display_name": "Saker Falcon", "eras": ["ancient", "medieval", "future"]},
				{ "id": "gyrfalcon", "display_name": "Gyrfalcon", "eras": ["ancient", "medieval", "future"]}
			]

		_:
			return [
				{
					"id": "%s_common" % species_id,
					"display_name": str(
						species_id
					).capitalize(),
					"eras": [
						"all"
					]
				}
			]
func _era_valid_sub_species_contracts(
	species_id: String
) -> Array:
	var out: Array = []
	var current_era: String = (
		_current_era_name()
		.strip_edges()
		.to_lower()
	)

	for raw_row in _sub_species_pool_for_species(
		species_id
	):
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		)

		var eras_raw: Variant = row.get(
			"eras",
			[
				"all"
			]
		)

		var eras: Array = (
			eras_raw as Array
			if typeof(eras_raw) == TYPE_ARRAY
			else [
				"all"
			]
		)

		var allowed: bool = eras.has(
			"all"
		)

		if not allowed:
			for raw_era in eras:
				var era_key: String = str(
					raw_era
				).strip_edges().to_lower()

				if (
					era_key != ""
					and current_era.find(
						era_key
					) >= 0
				):
					allowed = true
					break

		if allowed:
			out.append(
				row.duplicate(false)
			)

	return out


func pet_shop_variant_contracts_for_species(
	species_id: String,
	actor_id: int,
	listing_id: String
) -> Array:
	var species: Dictionary = define_species(
		species_id,
		{
			"source": (
				"animal_contract_engine.pet_shop_variants"
			),
			"actor_id": actor_id,
			"listing_id": listing_id,
			"read_only": true
		}
	)

	if species.is_empty():
		return []

	var sub_species_rows: Array = (
		_era_valid_sub_species_contracts(
			species_id
		)
	)

	if sub_species_rows.is_empty():
		return []

	var reproduction_raw: Variant = species.get(
		"reproduction",
		{}
	)

	var reproduction: Dictionary = (
		reproduction_raw as Dictionary
		if typeof(reproduction_raw) == TYPE_DICTIONARY
		else {}
	)

	var maturity_age: int = maxi(
		1,
		int(
			reproduction.get(
				"maturity_age",
				1
			)
		)
	)

	var lifespan_max: int = maxi(
		maturity_age + 2,
		int(
			species.get(
				"lifespan_max",
				maturity_age + 8
			)
		)
	)

	var baby_age: int = 0
	var young_age: int = mini(
		lifespan_max - 1,
		maxi(
			1,
			maturity_age
		)
	)
	var grown_age: int = mini(
		lifespan_max - 1,
		maxi(
			2,
			maturity_age + 1
		)
	)

	var age_sex_contracts: Array = [
		{
			"age_stage": "baby",
			"age_stage_label": "Baby",
			"age_years": baby_age,
			"gender": "female"
		},
		{
			"age_stage": "baby",
			"age_stage_label": "Baby",
			"age_years": baby_age,
			"gender": "male"
		},
		{
			"age_stage": "young",
			"age_stage_label": "Young",
			"age_years": young_age,
			"gender": "female"
		},
		{
			"age_stage": "young",
			"age_stage_label": "Young",
			"age_years": young_age,
			"gender": "male"
		},
		{
			"age_stage": "grown",
			"age_stage_label": "Grown",
			"age_years": grown_age,
			"gender": "female"
		},
		{
			"age_stage": "grown",
			"age_stage_label": "Grown",
			"age_years": grown_age,
			"gender": "male"
		}
	]

	var out: Array = []

	for raw_sub_species in sub_species_rows:
		if typeof(raw_sub_species) != TYPE_DICTIONARY:
			continue

		var sub_species: Dictionary = (
			raw_sub_species as Dictionary
		)

		var sub_species_id: String = str(
			sub_species.get(
				"id",
				"%s_common" % species_id
			)
		).strip_edges()

		var sub_species_name: String = str(
			sub_species.get(
				"display_name",
				species.get(
					"display_name",
					species_id.capitalize()
				)
			)
		).strip_edges()

		for raw_age_sex in age_sex_contracts:
			if typeof(raw_age_sex) != TYPE_DICTIONARY:
				continue

			var age_sex: Dictionary = (
				raw_age_sex as Dictionary
			)

			var gender: String = str(
				age_sex.get(
					"gender",
					"female"
				)
			)

			var age_years: int = int(
				age_sex.get(
					"age_years",
					0
				)
			)

			var age_stage: String = str(
				age_sex.get(
					"age_stage",
					"young"
				)
			)

			var breeding_age_reached: bool = (
				age_years >= maturity_age
			)

			var variant_id: String = (
				"%s:%s:%s:%s"
				% [
					listing_id,
					sub_species_id,
					age_stage,
					gender
				]
			)

			out.append({
				"schema": (
					"eralife.pet_shop.animal_variant_contract"
				),
				"version": CONTRACT_VERSION,
				"variant_id": variant_id,
				"listing_id": listing_id,
				"species_id": species_id,
				"species_name": str(
					species.get(
						"display_name",
						species_id.capitalize()
					)
				),
				"sub_species_id": sub_species_id,
				"sub_species_name": sub_species_name,
				"display_name": sub_species_name,
				"gender": gender,
				"sex": gender,
				"gender_label": (
					"Female"
					if gender == "female"
					else "Male"
				),
				"age_years": age_years,
				"age_label": (
					"%d year old" % age_years
					if age_years == 1
					else "%d years old" % age_years
				),
				"age_stage": age_stage,
				"age_stage_label": str(
					age_sex.get(
						"age_stage_label",
						age_stage.capitalize()
					)
				),
				"maturity_age": maturity_age,
				"breeding_age_reached": (
					breeding_age_reached
				),
				"breeding_status_label": (
					"Breeding age"
					if breeding_age_reached
					else "Not breeding age"
				),
				"reproduction_contract": (
					reproduction.duplicate(false)
				),
				"sub_species_contract": (
					sub_species.duplicate(false)
				),
				"species_contract": species,
				"ui_is_renderer_only": true
			})

	return out
func pet_shop_inventory(context: Dictionary = {}) -> Array:
	var out: Array = []
	for species_id in species_registry().keys():
		if not species_allowed_in_current_era(str(species_id)):
			continue
		var species: Dictionary = define_species(str(species_id), context)
		out.append({
			"listing_id": "animal:%s" % str(species_id),
			"entity_kind": ENTITY_KIND,
			"species_id": str(species_id),
			"display_name": str(species.get("display_name", str(species_id).capitalize())),
			"description": "%s • %s • danger %d" % [str(species.get("social_type", "unknown")).capitalize(), "trainable" if bool(species.get("trainable", false)) else "not trainable", int(species.get("danger_level", 0))],
			"price": int(species.get("base_price", 100)),
			"species_contract": species.duplicate(true)
		})
	out.sort_custom(Callable(self, "_listing_sort"))
	return out

func species_allowed_in_current_era(species_id: String) -> bool:
	var era_name: String = _current_era_name().to_lower()
	var species: Dictionary = define_species(species_id)
	if species.is_empty():
		return false
	var eras: Array = _safe_array(species.get("eras", []))
	if eras.has("all"):
		return true
	for raw_era in eras:
		var era_key: String = str(raw_era).strip_edges().to_lower()
		if era_key != "" and era_name.find(era_key) != -1:
			return true
	return false

func default_birth_family_species(context: Dictionary = {}) -> String:
	var candidates: Array = []
	for species_id in species_registry().keys():
		var species: Dictionary = define_species(str(species_id))
		if species.is_empty():
			continue
		if int(species.get("danger_level", 0)) > 2:
			continue
		if not species_allowed_in_current_era(str(species_id)):
			continue

		var weight: int = int(species.get("birth_family_weight", 1))
		if weight <= 0:
			continue

		for i in range(max(1, weight)):
			candidates.append(str(species_id))

	if candidates.is_empty():
		return "dog"

	var seed_key: String = str(context.get("seed_key", "")).strip_edges()
	if seed_key == "":
		seed_key = "birth_family_species:%d:%d:%s" % [
			int(context.get("world_seed", 0)),
			int(gs.year if gs != null else 0),
			str(context.get("household_pet_anchor_id", context.get("anchor_id", "world")))
		]

	var pick: int = _roll_between(0, candidates.size() - 1, seed_key)
	return str(candidates [pick])

func default_name_for_species(species_id: String, seed_key: String = "") -> String:
	var names: Dictionary = {
		"dog": ["Buddy", "Mochi", "Max", "Milo", "Fido", "Rocky", "Coco", "King", "Scout", "Rex", "Biscuit", "Atlas", "Duke", "Pepper", "Blue", "Bear", "Copper"],
		"cat": ["Puss", "Claws", "Dini", "Pepper", "Doja", "Speedy", "Midnight", "Luna", "Shadow", "Mittens", "Nova", "Simba", "Cleo", "Jinx", "Ash", "Nala", "Fig", "Opal", "Miso", "Velvet"],
		"horse": ["Comet", "Maximus", "Dusty", "Majesty", "River", "Storm", "Sable", "Cinder", "Briar", "Valor", "Juniper", "Midnight"],
		"cow": ["Bessie", "Mabel", "Daisy", "Buttercup", "Clover", "Mooana", "Hazel", "Maple", "Pearl", "Nellie"],
		"chicken": ["Henrietta", "Clucky", "Peck", "Nugget", "Goldie", "Maisie", "Pip", "Sunny", "Speckle", "Martha", "Chirp"],
		"sheep": ["Woolly", "Cloud", "Mutton", "Fleece", "Dolly", "Snowdrop", "Baaabara", "Cotton", "Nimbus"],
		"goat": ["Pip", "Nibbles", "Juniper", "Bramble", "Tilly", "Hoof", "Grits", "Pickle", "Sprig", "Moss"],
		"crow": ["Ink", "Cawson", "Soot", "Rook", "Jet", "Murk", "Cinder", "Quill", "Noir"],
		"raven": ["Nevermore", "Symone", "Omen", "Grim", "Vesper", "Morrigan", "Obsidian", "Rune", "Hollow", "Edgar"],
		"duck": ["Waddles", "Quackles", "Quacklin", "Quack'Ela", "Puddle", "Bean", "Daffy", "Marsh", "Ripple", "Billie"],
		"goose": ["Honker", "Gander", "Hilda", "Brutus", "Feather", "Honkules", "Agnes"],
		"pig": ["Truffle", "Napoleon", "Porky", "Bacon", "Hamlet", "Porkchop", "Petunia", "Snout", "Wilbur", "Peppa", "Baconator"],
		"wolf": ["Fangs", "Wolfie", "Moonlight", "Lupa", "Ghost", "Fenrir", "Akela", "Howl", "Timber", "Night"],
		"coyote": ["Yip", "Dust", "Mesa", "Trick", "Echo", "Scrap", "Ridge"],
		"lion": ["Mansa", "Scar", "Mufasa", "Nala", "Simba", "Sefu", "Roar", "Sahara", "Asha", "Kovu"],
		"tiger": ["Shere", "Tigress", "Hobbes", "Rajah", "Stripe", "Khan", "Amber", "Bengal", "Tora", "Sabre"],
		"camel": ["Dune", "Sahara", "Humpfrey", "Mira", "Nomad", "Caravan", "Saffron"],
		"rabbit": ["Thumper", "Clover", "Bun", "Daisy", "Velvet", "Niblet", "Fern", "Hopper"],
		"falcon": ["Arrow", "Keen", "Talon", "Sky", "Sable", "Aerie", "Hawkbit", "Dart"]
	}

	var era_name: String = _current_era_name().to_lower()
	var era_names: Array = []
	if era_name.find("ancient") != -1:
		era_names = ["Amun", "Nebu", "Kiya", "Sargon", "Tigris", "Olive", "Bronze", "Reed"]
	elif era_name.find("medieval") != -1:
		era_names = ["Bran", "Percy", "Willow", "Gawain", "Thorn", "Alder", "Pottage", "Merry"]
	elif era_name.find("industrial") != -1:
		era_names = ["Coal", "Copper", "Rusty", "Millie", "Cog", "Steam", "Penny", "Bolt"]
	elif era_name.find("future") != -1:
		era_names = ["Pixel", "Nova", "Byte", "Circuit", "Astra", "Ion", "Orbit", "Synth"]

	var pool: Array = _safe_array(names.get(str(species_id).to_lower(), ["Companion"])).duplicate(true)
	for raw_name in era_names:
		pool.append(str(raw_name))

	var idx: int = _roll_between(0, pool.size() - 1, "%s:%s" % [species_id, seed_key])
	return str(pool [idx])

func _register_entity(
	entity: Dictionary,
	defer_relationship_graph_registration: bool = false
) -> void:
	if gs == null:
		return

	if typeof(
		gs.entity_registry
	) != TYPE_DICTIONARY:
		gs.entity_registry = {}

	var entity_id: String = str(
		entity.get(
			"entity_id",
			""
		)
	).strip_edges()

	if entity_id == "":
		return



	gs.entity_registry [
		entity_id
	] = entity.duplicate(false)

	if defer_relationship_graph_registration:
		return

	if (
		gs.relationship_graph_contract_engine != null
		and gs.relationship_graph_contract_engine.has_method(
			"ensure_entity"
		)
	):
		gs.relationship_graph_contract_engine.ensure_entity(
			entity,
			{
				"source": ENGINE_SCHEMA
			}
		)

func _next_entity_sequence() -> int:
	if gs == null:
		return int(Time.get_ticks_usec())
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var next_id: int = int(gs.scenario_state.get("entity_next_id", 1))
	gs.scenario_state ["entity_next_id"] = next_id + 1
	return next_id

func _roll_lifespan(species: Dictionary, seed_key: String) -> int:
	return _roll_between(int(species.get("lifespan_min", 8)), int(species.get("lifespan_max", 16)), seed_key)

func _roll_between(min_value: int, max_value: int, seed_key: String) -> int:
	var low: int = min(min_value, max_value)
	var high: int = max(min_value, max_value)
	if low == high:
		return low
	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(str(seed_key).hash())
	return rng.randi_range(low, high)

func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.get("name", gs.era.get("id", ""))) if typeof(gs.era) == TYPE_DICTIONARY else str(gs.era.name)
	return "modern"

func _listing_sort(a, b) -> bool:
	return int(_safe_dictionary(a).get("price", 0)) < int(_safe_dictionary(b).get("price", 0))

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func resolve_animal_lifecycle(entity_id: String) -> Dictionary:
	# Single source of truth for a pet's age and alive state.
	#
	# Pets have no yearly tick -- nothing in AgeUpRuntimeEngine or WorldEngine
	# touches them, which is why a pet created at age 3 stayed 3 forever. Rather
	# than add an accumulator that would need its own bounded drain, anchor and
	# catch-up (all three of which failed for NPCs before being replaced by
	# derivation), age is computed from birth_year on every read:
	#
	#   age   = current_year - birth_year
	#   alive = age <= lifespan_years
	#
	# Derived state cannot drift, cannot be starved, and needs no invalidation.
	# Death is still announced exactly once -- see the pet_death_recorded latch
	# below -- so it is not a silent state change.
	if (
		gs == null
		or typeof(gs.entity_registry) != TYPE_DICTIONARY
		or not gs.entity_registry.has(entity_id)
	):
		return {}

	var entity_raw = gs.entity_registry.get(entity_id, {})

	if typeof(entity_raw) != TYPE_DICTIONARY:
		return {}

	var entity: Dictionary = entity_raw
	var current_year: int = int(gs.year)
	var stored_age: int = int(
		entity.get("age", entity.get("age_years", 0))
	)

	# Backfill for pets created before birth_year existed. Anchors from the age
	# they currently hold, so an existing pet stops being frozen but does not
	# retroactively gain the years it already missed.
	if int(entity.get("birth_year", -1)) <= 0:
		entity["birth_year"] = current_year - stored_age

	var derived_age: int = maxi(
		0,
		current_year - int(entity.get("birth_year", current_year))
	)
	var lifespan: int = int(entity.get("lifespan_years", 0))
	var died_of_age: bool = (
		lifespan > 0
		and derived_age > lifespan
	)
	var was_alive: bool = bool(entity.get("alive", true))

	# A dead animal's age freezes at the age it died, otherwise a long-dead pet
	# would keep "aging" in the Dead section every year.
	if died_of_age:
		derived_age = mini(derived_age, maxi(0, lifespan + 1))

	entity["age"] = derived_age
	entity["age_years"] = derived_age

	if died_of_age:
		entity["alive"] = false

		if not bool(entity.get("pet_death_recorded", false)):
			# Death is DERIVED, not observed: the pet died the year it exceeded its
			# lifespan, which may be several years before anything read this card.
			# Recording current_year would date the death to whenever the player
			# happened to open the hub. birth_year + lifespan_years + 1 is the
			# first year the animal was past its span, and it is stable no matter
			# when the read occurs.
			var true_death_year: int = (
				int(entity.get("birth_year", current_year))
				+ lifespan
				+ 1
			)

			if true_death_year > current_year:
				true_death_year = current_year

			entity["pet_death_recorded"] = true
			entity["death_year"] = true_death_year
			entity["death_age"] = maxi(0, lifespan + 1)
			entity["death_reason"] = "old_age"

			EraLog.truth(
				"ERALIFE_PET_DEATH|entity=%s|name=%s|death_age=%d|lifespan=%d|death_year=%d|observed_year=%d|years_late=%d"
				% [
					entity_id,
					str(entity.get("display_name", "?")),
					maxi(0, lifespan + 1),
					lifespan,
					true_death_year,
					current_year,
					current_year - true_death_year
				]
			)

	# ensure_entity() maintains TWO copies -- the registry and
	# graph_state["entities"] -- and cards_for_entity() reads the GRAPH copy first,
	# so both must move together or the card renders the stale one.
	#
	# But ensure_entity() also stamps registered_at_ms = Time.get_ticks_msec() and
	# writes gs.canonical_relationship_graph. _hub_signature() keys the hub
	# contract cache on _relationship_graph_revision(), which reads that graph. So
	# calling it unconditionally on every READ mutated the graph, invalidated the
	# hub cache, forced a rebuild, and read the pets again -- unbounded recursion
	# and a signal 11 the moment a second caller (the Dead Pets group) shared the
	# same build.
	#
	# Only write when something actually changed. A read that changes nothing must
	# not touch the graph.
	var previous_age: int = int(
		entity.get("_lifecycle_written_age", -12345)
	)
	var previous_alive: bool = bool(
		entity.get("_lifecycle_written_alive", true)
	)
	var lifecycle_changed: bool = (
		previous_age != derived_age
		or previous_alive != bool(entity.get("alive", true))
	)

	if lifecycle_changed:
		entity["_lifecycle_written_age"] = derived_age
		entity["_lifecycle_written_alive"] = bool(
			entity.get("alive", true)
		)

		gs.entity_registry[entity_id] = entity

		if (
			gs.relationship_graph_contract_engine != null
			and gs.relationship_graph_contract_engine.has_method(
				"ensure_entity"
			)
		):
			gs.relationship_graph_contract_engine.ensure_entity(
				entity,
				{
					"source": "animal_contract_engine.resolve_animal_lifecycle"
				}
			)
	else:
		gs.entity_registry[entity_id] = entity

	return {
		"entity_id": entity_id,
		"age": derived_age,
		"alive": bool(entity.get("alive", true)),
		"lifespan_years": lifespan,
		"died_this_read": died_of_age and was_alive,
		"birth_year": int(entity.get("birth_year", -1))
	}
