extends Resource
class_name BoxingTrainingEngine

var gs
var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = {}
	if typeof(contract) == TYPE_DICTIONARY:
		active_contract = (contract as Dictionary).duplicate(true)

	last_contract_report = {
		"schema": "eralife.boxing_subengine_contract_set_report",
		"success": true,
		"engine": get_script().resource_path.get_file() if get_script() != null else "",
		"contract_schema": str(active_contract.get("schema", "")),
		"role": str(active_contract.get("role", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_contract_report.duplicate(true)


func _boxing_contract() -> Dictionary:
	if not active_contract.is_empty():
		return active_contract

	if has_meta("boxing_contract"):
		var raw: Variant = get_meta("boxing_contract", {})
		if typeof(raw) == TYPE_DICTIONARY:
			return (raw as Dictionary)

	return {}


func _boxing_policies() -> Dictionary:
	var contract: Dictionary = _boxing_contract()
	var raw: Variant = contract.get("policies", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary)
	return {}


func _boxing_rules() -> Dictionary:
	var contract: Dictionary = _boxing_contract()
	var raw: Variant = contract.get("rules", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary)
	return {}


func _boxing_policy(key: String, fallback: Variant = null) -> Variant:
	var policies: Dictionary = _boxing_policies()
	var clean_key: String = str(key).strip_edges()
	if clean_key != "" and policies.has(clean_key):
		return policies.get(clean_key)
	return fallback


func _boxing_rule(key: String, fallback: Variant = null) -> Variant:
	var rules: Dictionary = _boxing_rules()
	var clean_key: String = str(key).strip_edges()
	if clean_key != "" and rules.has(clean_key):
		return rules.get(clean_key)
	return fallback


func _boxing_array_policy(key: String, fallback: Array = []) -> Array:
	var raw: Variant = _boxing_policy(key, fallback)
	if typeof(raw) == TYPE_ARRAY:
		return (raw as Array).duplicate(true)
	return fallback.duplicate(true)


func _boxing_dictionary_policy(key: String, fallback: Dictionary = {}) -> Dictionary:
	var raw: Variant = _boxing_policy(key, fallback)
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)
	return fallback.duplicate(true)
func _init(_gs):
	gs = _gs

func train_fighter(person: Person) -> Dictionary:
	if person == null or not person.boxing_profile.get("is_boxer", false):
		return { "success": false, "text": "\n\nI am not a boxer."}

	if person.boxing_profile.get("retired", false):
		return { "success": false, "text": "\n\nI am retired."}

	var ratings: Dictionary = person.boxing_profile.get("ratings", {}) if typeof(person.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	person.boxing_profile ["ratings"] = ratings

	var improved: Array = []
	var training_pool: Array = _boxing_array_policy("training_pool", [
		"endurance",
		"cardio",
		"strength",
		"jab",
		"cross",
		"left_hook",
		"right_hook",
		"left_uppercut",
		"right_uppercut",
		"body_work",
		"defense",
		"footwork",
		"ring_iq"
	])

	var improvement_chance: int = int(_boxing_policy("training_improvement_chance", 48))
	var min_gain: int = int(_boxing_policy("training_min_gain", 1))
	var max_gain: int = int(_boxing_policy("training_max_gain", 3))
	var health_cost_max: float = float(_boxing_policy("training_health_cost_max", 3.0))
	var health_recovery_max: float = float(_boxing_policy("training_health_recovery_max", 1.5))
	var mental_cost_max: float = float(_boxing_policy("training_mental_cost_max", 2.0))
	var injury_chance: int = int(_boxing_policy("training_injury_chance", 10))
	var injuries_enabled: bool = bool(_boxing_policy("training_injuries_enabled", true))

	for stat in training_pool:
		var stat_key: String = str(stat)
		if stat_key == "":
			continue

		if not ratings.has(stat_key):
			ratings [stat_key] = int(_boxing_policy("default_training_stat", 50))

		if randi() % 100 < improvement_chance:
			ratings [stat_key] = clamp(int(ratings [stat_key]) + randi_range(min_gain, max_gain), 1, 100)
			improved.append(stat_key.replace("_", " ").capitalize())

	if ratings.has("strength"):
		ratings ["power"] = clamp(int((float(ratings.get("power", 50)) + float(ratings.get("strength", 50))) / 2.0), 1, 100)
	if ratings.has("endurance"):
		ratings ["cardio"] = clamp(int((float(ratings.get("cardio", 50)) + float(ratings.get("endurance", 50))) / 2.0), 1, 100)

	person.health = clamp(person.health - randf() * health_cost_max + randf() * health_recovery_max, 0, 100)
	person.mental_health = clamp(person.mental_health - randf() * mental_cost_max, 0, 100)

	if injuries_enabled and gs != null and gs.boxing_injury_engine != null:
		if randi() % 100 < injury_chance:
			gs.boxing_injury_engine.apply_training_injury(person)

	var txt: String = "\n\nI trained in camp and improved my %s." % ", ".join(improved) if improved.size() > 0 else "\n\nI trained in camp."

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_TRAINED, {
			"npc_id": person.id,
			"text": txt,
			"contract_source": "boxing_training_engine"
		})

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(person, { "type": "text", "text": txt})
	var xp_gain: int = int(_boxing_policy("training_xp_gain", 8))
	if not person.boxing_profile.has("growth") or typeof(person.boxing_profile.get("growth", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["growth"] = {
			"xp": 0,
			"total_levels": 0,
			"max_total_levels": 220,
			"max_skill_level": 20,
			"levels": {}
		}

	var growth: Dictionary = person.boxing_profile ["growth"]
	growth ["xp"] = int(growth.get("xp", 0)) + xp_gain
	person.boxing_profile ["growth"] = growth
	return {
		"success": true,
		"text": txt,
		"contract": _boxing_contract().duplicate(true),
		"improved": improved,
		"xp_gain": xp_gain
	}