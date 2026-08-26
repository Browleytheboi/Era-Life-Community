extends Resource
class_name MythicalContractEngine

const ENGINE_SCHEMA:= "eralife.entity_definition.mythical_contract_engine"
const ENTITY_KIND:= "mythical"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func species_registry() -> Dictionary:
	return {
		"dragon": {
			"display_name": "Dragon",
			"lifespan_min": 300,
			"lifespan_max": 1200,
			"behavior_traits": ["ancient", "territorial", "proud"],
			"intelligence_min": 80,
			"intelligence_max": 100,
			"trainable": true,
			"danger_level": 10,
			"social_type": "bonded_legend",
			"base_price": 50000,
			"chaos_weight": 2
		},
		"phoenix": {
			"display_name": "Phoenix",
			"lifespan_min": 80,
			"lifespan_max": 500,
			"behavior_traits": ["rebirth", "loyal", "radiant"],
			"intelligence_min": 70,
			"intelligence_max": 96,
			"trainable": true,
			"danger_level": 6,
			"social_type": "soul_bonded",
			"base_price": 30000,
			"chaos_weight": 4
		},
		"griffin": {
			"display_name": "Griffin",
			"lifespan_min": 60,
			"lifespan_max": 180,
			"behavior_traits": ["guardian", "aerial", "noble"],
			"intelligence_min": 62,
			"intelligence_max": 90,
			"trainable": true,
			"danger_level": 7,
			"social_type": "guardian_pair",
			"base_price": 18000,
			"chaos_weight": 5
		},
		"unicorn": {
			"display_name": "Unicorn",
			"lifespan_min": 100,
			"lifespan_max": 400,
			"behavior_traits": ["gentle", "pure", "healing"],
			"intelligence_min": 68,
			"intelligence_max": 95,
			"trainable": true,
			"danger_level": 3,
			"social_type": "chosen_companion",
			"base_price": 22000,
			"chaos_weight": 7
		},
		"familiar": {
			"display_name": "Familiar",
			"lifespan_min": 30,
			"lifespan_max": 140,
			"behavior_traits": ["mystic", "observant", "bonded"],
			"intelligence_min": 72,
			"intelligence_max": 98,
			"trainable": true,
			"danger_level": 2,
			"social_type": "arcane_companion",
			"base_price": 7000,
			"chaos_weight": 12
		}
	}
func _mobility_species_registry_expansion() -> Dictionary:
	return {
		"flying_bison": {
			"display_name": "Flying Bison",
			"lifespan_min": 80,
			"lifespan_max": 180,
			"behavior_traits": [
				"loyal",
				"aerial",
				"gentle_giant"
			],
			"intelligence_min": 72,
			"intelligence_max": 96,
			"trainable": true,
			"danger_level": 4,
			"social_type": "sky_herd_bonded",
			"base_price": 42000,
			"chaos_weight": 4
		},
		"spirit_wolf": {
			"display_name": "Spirit Wolf",
			"lifespan_min": 90,
			"lifespan_max": 360,
			"behavior_traits": [
				"spiritual",
				"swift",
				"guardian"
			],
			"intelligence_min": 76,
			"intelligence_max": 98,
			"trainable": true,
			"danger_level": 6,
			"social_type": "soul_pack",
			"base_price": 26000,
			"chaos_weight": 6
		}
	}
func mythical_allowed_for_current_reality() -> bool:
	if gs == null:
		return false
	if gs.has_method("is_feature_enabled") and (gs.is_feature_enabled("mythical_pets") or gs.is_feature_enabled("fantasy") or gs.is_feature_enabled("chaos")):
		return true
	var mode_text: String = ""
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		mode_text = "%s %s %s" % [str(gs.custom_settings.get("reality_mode", "")), str(gs.custom_settings.get("mode", "")), str(gs.custom_settings.get("fantasy_mode", ""))]
	mode_text = mode_text.strip_edges().to_lower()
	return mode_text.find("chaos") != -1 or mode_text.find("fantasy") != -1 or mode_text.find("myth") != -1

func define_species(
	species_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_species: String = str(
		species_id
	).strip_edges().to_lower()
	var registry: Dictionary = species_registry()

	registry.merge(
		_mobility_species_registry_expansion(),
		true
	)

	if not registry.has(clean_species):
		return {}

	var base: Dictionary = (
		registry [clean_species] as Dictionary
	).duplicate(true)
	base ["schema"] = "eralife.entity_definition.mythical_species"
	base ["version"] = CONTRACT_VERSION
	base ["species_id"] = clean_species
	base ["entity_kind"] = ENTITY_KIND
	base ["contract_authority"] = ENGINE_SCHEMA
	base ["defines_rules_only"] = true
	base ["does_not_execute_behavior"] = true
	base ["context"] = context.duplicate(true)

	return base
func create_mythical_entity(species_id: String, owner_person_id: int = 0, context: Dictionary = {}) -> Dictionary:
	if not mythical_allowed_for_current_reality():
		return {}
	var species: Dictionary = define_species(species_id, context)
	if species.is_empty():
		return {}
	var entity_id: String = "mythical:%d" % _next_entity_sequence()
	var display_name: String = str(context.get("name", "")).strip_edges()
	if display_name == "":
		display_name = default_name_for_species(str(species.get("species_id", "familiar")), entity_id)
	var entity: Dictionary = {
		"schema": "eralife.entity.mythical",
		"version": CONTRACT_VERSION,
		"entity_id": entity_id,
		"entity_kind": ENTITY_KIND,
		"entity_type": "mythical",
		"species_id": str(species.get("species_id", "mythical")),
		"species_name": str(species.get("display_name", "Mythical Creature")),
		"display_name": display_name,
		"age": int(context.get("age", 0)),
		"age_years": int(context.get("age", 0)),
		"lifespan_years": _roll_between(int(species.get("lifespan_min", 80)), int(species.get("lifespan_max", 400)), entity_id),
		"alive": true,
		"owner_person_id": owner_person_id,
		"behavior_traits": _safe_array(species.get("behavior_traits", [])).duplicate(true),
		"trainable": bool(species.get("trainable", true)),
		"danger_level": int(species.get("danger_level", 5)),
		"social_type": str(species.get("social_type", "mythic_bond")),
		"stats": {
			"health": 100,
			"health_max": 100,
			"hunger": int(context.get("hunger", 18)),
			"smarts": _roll_between(int(species.get("intelligence_min", 70)), int(species.get("intelligence_max", 100)), "%s:smarts" % entity_id),
			"trust": int(context.get("trust", 45)),
			"training": int(context.get("training", 0)),
			"magic_attunement": int(context.get("magic_attunement", 20))
		},
		"species_contract": species.duplicate(true),
		"contract_authority": ENGINE_SCHEMA,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_register_entity(entity)
	return entity.duplicate(true)

func pet_shop_inventory(context: Dictionary = {}) -> Array:
	if not mythical_allowed_for_current_reality():
		return []
	var out: Array = []
	for species_id in species_registry().keys():
		var species: Dictionary = define_species(str(species_id), context)
		out.append({
			"listing_id": "mythical:%s" % str(species_id),
			"entity_kind": ENTITY_KIND,
			"species_id": str(species_id),
			"display_name": str(species.get("display_name", str(species_id).capitalize())),
			"description": "%s • danger %d • mythical" % [str(species.get("social_type", "mythic")).capitalize(), int(species.get("danger_level", 5))],
			"price": int(species.get("base_price", 10000)),
			"species_contract": species.duplicate(true)
		})
	out.sort_custom(Callable(self, "_listing_sort"))
	return out

func default_name_for_species(species_id: String, seed_key: String = "") -> String:
	var names: Dictionary = {
		"dragon": ["Ashwing", "Ember", "Cinder", "Rhaegon"],
		"phoenix": ["Sol", "Aurelia", "Flare", "Dawn"],
		"griffin": ["Valor", "Talon", "Aerie", "Stormcrest"],
		"unicorn": ["Lumen", "Pearl", "Grace", "Starlace"],
		"familiar": ["Hex", "Oracle", "Muse", "Whisper"]
	}
	var pool: Array = _safe_array(names.get(str(species_id).to_lower(), ["Mythic"]))
	var idx: int = _roll_between(0, pool.size() - 1, "%s:%s" % [species_id, seed_key])
	return str(pool [idx])

func _register_entity(entity: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.entity_registry) != TYPE_DICTIONARY:
		gs.entity_registry = {}
	var entity_id: String = str(entity.get("entity_id", "")).strip_edges()
	if entity_id == "":
		return
	gs.entity_registry [entity_id] = entity.duplicate(true)
	if gs.relationship_graph_contract_engine != null and gs.relationship_graph_contract_engine.has_method("ensure_entity"):
		gs.relationship_graph_contract_engine.ensure_entity(entity, { "source": ENGINE_SCHEMA})

func _next_entity_sequence() -> int:
	if gs == null:
		return int(Time.get_ticks_usec())
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var next_id: int = int(gs.scenario_state.get("entity_next_id", 1))
	gs.scenario_state ["entity_next_id"] = next_id + 1
	return next_id

func _roll_between(min_value: int, max_value: int, seed_key: String) -> int:
	var low: int = min(min_value, max_value)
	var high: int = max(min_value, max_value)
	if low == high:
		return low
	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(str(seed_key).hash())
	return rng.randi_range(low, high)

func _listing_sort(a, b) -> bool:
	return int(_safe_dictionary(a).get("price", 0)) < int(_safe_dictionary(b).get("price", 0))

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []