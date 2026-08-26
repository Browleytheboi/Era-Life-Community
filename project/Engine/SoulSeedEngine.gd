extends Resource
class_name SoulSeedEngine

const SOUL_SEED_VERSION:= 1
const SOUL_SEED_SCHEMA:= "eralife.soul_seed"
const SOUL_SEED_ENGINE_STATE_SCHEMA:= "eralife.soul_seed_engine_state"

var gs
var soul_seed_index: Dictionary = {}
var last_distribution_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": SOUL_SEED_ENGINE_STATE_SCHEMA,
		"version": SOUL_SEED_VERSION,
		"soul_seed_index": soul_seed_index.duplicate(true),
		"last_distribution_report": last_distribution_report.duplicate(true)
	})

func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "SoulSeedEngine import_state expected a Dictionary."
		}
	soul_seed_index = _safe_dictionary(state.get("soul_seed_index", {}))
	last_distribution_report = _safe_dictionary(state.get("last_distribution_report", {}))
	return {
		"success": true,
		"indexed_soul_seed_count": soul_seed_index.size()
	}

func assign_world_soul_seeds(people: Array, settings: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var world_seed: int = _resolve_world_seed(settings, context)
	var contract: Dictionary = _resolve_soul_seed_contract(settings, context)
	var assigned: int = 0
	var player_id: int = int(context.get("player_id", _player_id()))

	for raw_person in people:
		if raw_person == null or not (raw_person is Person):
			continue
		var person: Person = raw_person as Person
		var role: String = "npc"
		if int(person.id) == player_id:
			role = "player"
		elif _is_parent_of_player(person, player_id):
			role = "parent"

		var soul_seed: Dictionary = ensure_soul_seed(person, {
			"source": str(context.get("source", "assign_world_soul_seeds")),
			"world_seed": world_seed,
			"soul_seed_contract": contract.duplicate(true),
			"role": role,
			"player_id": player_id,
		})

		if not soul_seed.is_empty():
			assigned += 1

	last_distribution_report = {
		"schema": "eralife.soul_seed_distribution_report",
		"version": SOUL_SEED_VERSION,
		"success": true,
		"world_seed": world_seed,
		"assigned_count": assigned,
		"population_count": people.size(),
		"contract": contract.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["soul_seed_distribution_report"] = last_distribution_report.duplicate(true)

	return last_distribution_report.duplicate(true)

func ensure_soul_seed(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	if typeof(person.soul_seed_contract) == TYPE_DICTIONARY and not person.soul_seed_contract.is_empty():
		_index_person_seed(person, person.soul_seed_contract)
		return person.soul_seed_contract.duplicate(true)

	var soul_seed: Dictionary = build_soul_seed_for_person(person, context)
	person.soul_seed_contract = soul_seed.duplicate(true)
	person.soul_seed_state = _build_soul_seed_state(person, soul_seed, context)
	_index_person_seed(person, soul_seed)

	return soul_seed.duplicate(true)
func build_soul_seed_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	var world_seed: int = int(context.get("world_seed", _current_world_seed()))
	var role: String = str(context.get("role", "npc")).strip_edges().to_lower()
	if role == "":
		role = "npc"

	var material: String = "%s|%s|%s|%s|%s|%s|%s" % [
		str(world_seed),
		role,
		str(int(person.id)),
		str(person.first_name),
		str(person.last_name),
		str(person.gender),
		str(person.birthday)
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed(material)

	var personality_vector: Dictionary = {
		"openness": _rand_curve(rng),
		"discipline": _rand_curve(rng),
		"empathy": _rand_curve(rng),
		"ambition": _rand_curve(rng),
		"boldness": _rand_curve(rng),
		"patience": _rand_curve(rng),
		"spiritual_sensitivity": _rand_curve(rng)
	}

	var emotional_profile: Dictionary = {
		"baseline_warmth": _rand_curve(rng),
		"reactivity": _rand_curve(rng),
		"recovery_rate": _rand_curve(rng),
		"attachment_intensity": _rand_curve(rng),
		"fear_memory_strength": _rand_curve(rng),
		"joy_memory_strength": _rand_curve(rng)
	}

	var behavioral_curves: Dictionary = {
		"risk_curve": _rand_curve(rng),
		"loyalty_curve": _rand_curve(rng),
		"ambition_curve": _rand_curve(rng),
		"impulse_curve": _rand_curve(rng),
		"forgiveness_curve": _rand_curve(rng),
		"adaptation_curve": _rand_curve(rng)
	}

	var destiny_domains: Array = _destiny_domains_from_rng(rng, role)
	var destiny_weight: float = _round_float(rng.randf_range(0.05, 0.88))
	if role == "player":
		destiny_weight = _round_float(clamp(destiny_weight * 0.55, 0.02, 0.55))

	var soul_seed: Dictionary = {
		"schema": SOUL_SEED_SCHEMA,
		"version": SOUL_SEED_VERSION,
		"soul_seed_id": "soul_%s_%s_%s" % [str(world_seed), role, str(int(person.id))],
		"world_seed": world_seed,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"role": role,
		"core_identity": {
			"personality_vector": personality_vector,
			"emotional_profile": emotional_profile,
			"decision_bias": {
				"risk_weight": behavioral_curves.get("risk_curve", 0.5),
				"loyalty_weight": behavioral_curves.get("loyalty_curve", 0.5),
				"ambition_weight": behavioral_curves.get("ambition_curve", 0.5),
				"impulse_weight": behavioral_curves.get("impulse_curve", 0.5)
			},
			"adaptability": behavioral_curves.get("adaptation_curve", 0.5),
			"memory_bias": _memory_bias_from_rng(rng)
		},
		"hidden_traits": _hidden_traits_from_vectors(personality_vector, emotional_profile, behavioral_curves),
		"behavioral_curves": behavioral_curves,
		"destiny_pressure": {
			"weight": destiny_weight,
			"domains": destiny_domains
		},
		"expression_rules": {
			"evolution_rate": _evolution_rate_from_rng(rng),
			"player_choice_can_override": role == "player",
			"consciousness_binding": "merge_as_identity_substrate"
		},
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return _make_binary_safe(soul_seed)
func build_player_soul_seed_preview(settings: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var preview_context: Dictionary = context.duplicate(true)
	preview_context ["world_seed"] = _resolve_world_seed(settings, context)
	preview_context ["role"] = "player"

	var fake:= Person.new()
	fake.id = int(settings.get("player_id", 0))
	fake.first_name = str(settings.get("first_name", "Player")).strip_edges()
	fake.last_name = str(settings.get("last_name", "Soul")).strip_edges()
	fake.gender = str(settings.get("gender", "")).strip_edges()
	fake.age = int(settings.get("age", settings.get("starting_age", 0)))
	fake.birthday = {
		"month": int(settings.get("month", 1)),
		"day": int(settings.get("day", 1))
	}

	return build_soul_seed_for_person(fake, preview_context)

func _index_person_seed(person: Person, soul_seed: Dictionary) -> void:
	var id_key: String = str(int(person.id))
	soul_seed_index [id_key] = {
		"person_id": int(person.id),
		"name": _person_name(person),
		"role": str(soul_seed.get("role", "npc")),
		"soul_seed_id": str(soul_seed.get("soul_seed_id", "")),
		"world_seed": int(soul_seed.get("world_seed", _current_world_seed())),
		"destiny_pressure": _safe_dictionary(soul_seed.get("destiny_pressure", {})),
		"updated_at_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
func _resolve_soul_seed_contract(settings: Dictionary, context: Dictionary) -> Dictionary:
	var raw: Variant = context.get("soul_seed_contract", {})
	if typeof(raw) != TYPE_DICTIONARY:
		raw = settings.get("soul_seed_contract", {})
	if typeof(raw) != TYPE_DICTIONARY and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var prewarm_raw: Variant = gs.scenario_state.get("god_mode_life_prewarm_contract", {})
		if typeof(prewarm_raw) == TYPE_DICTIONARY:
			var loadout_raw: Variant = (prewarm_raw as Dictionary).get("loadout", {})
			if typeof(loadout_raw) == TYPE_DICTIONARY:
				raw = (loadout_raw as Dictionary).get("soul_seed", {})
	return _safe_dictionary(raw)

func _resolve_world_seed(settings: Dictionary, context: Dictionary) -> int:
	var world_seed: int = int(context.get("world_seed", settings.get("world_seed", -1)))
	if world_seed <= 0:
		var seed_contract_raw: Variant = settings.get("seed_contract", context.get("seed_contract", {}))
		if typeof(seed_contract_raw) == TYPE_DICTIONARY:
			world_seed = int((seed_contract_raw as Dictionary).get("seed", -1))
	if world_seed <= 0 and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		world_seed = int(gs.scenario_state.get("world_seed", -1))
	if world_seed <= 0:
		world_seed = _current_world_seed()
	return world_seed

func _current_world_seed() -> int:
	if gs != null and gs.seed_engine != null:
		return int(gs.seed_engine.seed_value)
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		return int(gs.scenario_state.get("world_seed", 1))
	return 1

func _current_year() -> int:
	if gs != null:
		return int(gs.year)
	return 0

func _player_id() -> int:
	if gs != null and gs.player != null:
		return int(gs.player.id)
	if gs != null:
		return int(gs.player_id)
	return 0
func _safe_person_id_array(person: Person, property_id: String) -> Array:
	var out: Array = []
	if person == null:
		return out

	var raw_value: Variant = person.get(property_id)
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var resolved_id: int = int(raw_id)
		if resolved_id <= 0:
			continue
		if out.has(resolved_id):
			continue
		out.append(resolved_id)

	return out
func _is_parent_of_player(person: Person, player_id: int) -> bool:
	if person == null or gs == null:
		return false

	var player_person: Person = gs.get_npc_by_id(player_id) if gs.has_method("get_npc_by_id") else null
	if player_person == null and gs.player != null and int(gs.player.id) == player_id:
		player_person = gs.player
	if player_person == null:
		return false

	return int(person.id) in _safe_person_id_array(player_person, "parents")

func _person_name(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Unknown"
	return full_name

func _stable_seed(material: String) -> int:
	var value: int = int(hash(str(material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value

func _rand_curve(rng: RandomNumberGenerator) -> float:
	return _round_float(clamp(rng.randf_range(0.05, 0.95), 0.0, 1.0))

func _round_float(value: float) -> float:
	return round(value * 1000.0) / 1000.0

func _memory_bias_from_rng(rng: RandomNumberGenerator) -> String:
	var options: Array = [
		"emotion_weighted",
		"loyalty_weighted",
		"threat_weighted",
		"achievement_weighted",
		"relationship_weighted",
		"meaning_weighted"
	]
	return str(options [int(rng.randi_range(0, options.size() - 1))])

func _evolution_rate_from_rng(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.22:
		return "slow_burn"
	if roll < 0.72:
		return "adaptive"
	return "volatile_growth"

func _destiny_domains_from_rng(rng: RandomNumberGenerator, role: String) -> Array:
	var pool: Array = ["career", "relationships", "power", "family", "fame", "faith", "survival", "legacy", "justice", "creation"]
	var out: Array = []
	var target_count: int = 2
	if role == "player":
		target_count = 3
	while out.size() < target_count and not pool.is_empty():
		var index: int = int(rng.randi_range(0, pool.size() - 1))
		var picked: String = str(pool [index])
		pool.remove_at(index)
		if not out.has(picked):
			out.append(picked)
	return out

func _hidden_traits_from_vectors(personality: Dictionary, emotion: Dictionary, curves: Dictionary) -> Array:
	var out: Array = []

	if float(personality.get("empathy", 0.5)) >= 0.72 and float(curves.get("loyalty_curve", 0.5)) >= 0.64:
		out.append("soul_loyal")
	if float(personality.get("ambition", 0.5)) >= 0.72:
		out.append("destiny_hungry")
	if float(curves.get("risk_curve", 0.5)) >= 0.74 and float(curves.get("impulse_curve", 0.5)) >= 0.58:
		out.append("danger_drawn")
	if float(emotion.get("fear_memory_strength", 0.5)) >= 0.72:
		out.append("scar_sensitive")
	if float(personality.get("spiritual_sensitivity", 0.5)) >= 0.76:
		out.append("reality_sensitive")
	if out.is_empty():
		out.append("ordinary_depth")

	return out

func _build_soul_seed_state(person: Person, soul_seed: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var destiny: Dictionary = _safe_dictionary(soul_seed.get("destiny_pressure", {}))
	var core: Dictionary = _safe_dictionary(soul_seed.get("core_identity", {}))
	var curves: Dictionary = _safe_dictionary(soul_seed.get("behavioral_curves", {}))
	return _make_binary_safe({
		"schema": "eralife.soul_seed_state",
		"version": SOUL_SEED_VERSION,
		"person_id": int(person.id),
		"soul_seed_id": str(soul_seed.get("soul_seed_id", "")),
		"world_seed": int(soul_seed.get("world_seed", _current_world_seed())),
		"destiny_pressure_weight": float(destiny.get("weight", 0.0)),
		"destiny_domains": destiny.get("domains", []) if typeof(destiny.get("domains", [])) == TYPE_ARRAY else [],
		"adaptability": float(core.get("adaptability", curves.get("adaptation_curve", 0.5))),
		"memory_bias": str(core.get("memory_bias", "emotion_weighted")),
		"updated_at_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	})

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)