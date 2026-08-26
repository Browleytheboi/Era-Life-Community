extends Resource
class_name BoxingInjuryEngine

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

func apply_training_injury(person: Person) -> void:
	if person == null:
		return

	if not bool(_boxing_policy("training_injuries_enabled", true)):
		return

	var injury_names: Array = _boxing_array_policy("training_injury_names", [
		"Hand Injury",
		"Cut Over Eye",
		"Rib Strain",
		"Shoulder Strain"
	])

	if injury_names.is_empty():
		injury_names = ["Training Injury"]

	var min_severity: int = int(_boxing_policy("training_injury_min_severity", 1))
	var max_severity: int = int(_boxing_policy("training_injury_max_severity", 4))
	var recovery_years: int = int(_boxing_policy("training_injury_recovery_years", 1))

	var injury: Dictionary = {
		"name": str(injury_names [randi() % injury_names.size()]),
		"severity": randi_range(min_severity, max_severity),
		"recovery_years": recovery_years,
		"source": "training",
	}

	var arr: Array = person.boxing_profile.get("current_injuries", []) if typeof(person.boxing_profile.get("current_injuries", [])) == TYPE_ARRAY else []
	arr.append(injury)
	person.boxing_profile ["current_injuries"] = arr
	person.boxing_profile ["wear"] = int(person.boxing_profile.get("wear", 0)) + int(injury ["severity"])

	var txt: String = "🤕 %s suffered a training injury: %s." % [person.first_name, injury ["name"]]

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_INJURY, {
			"npc_id": person.id,
			"text": txt,
			"injury": injury.duplicate(true),
			"contract_source": "boxing_injury_engine"
		})


func apply_fight_wear(person: Person, damage: int) -> void:
	if person == null:
		return

	if not bool(_boxing_policy("fight_wear_enabled", true)):
		return

	var wear_multiplier: float = float(_boxing_policy("fight_wear_multiplier", 1.0))
	var scar_multiplier: float = float(_boxing_policy("scar_tissue_multiplier", 0.5))
	var injury_damage_multiplier: int = int(_boxing_policy("fight_injury_damage_multiplier", 2))
	var injury_chance_cap: int = int(_boxing_policy("fight_injury_chance_cap", 35))

	var applied_damage: int = max(0, int(round(float(damage) * wear_multiplier)))
	person.boxing_profile ["wear"] = int(person.boxing_profile.get("wear", 0)) + applied_damage
	person.boxing_profile ["scar_tissue"] = int(person.boxing_profile.get("scar_tissue", 0)) + int(round(float(applied_damage) * scar_multiplier))

	var injury_chance: int = min(injury_chance_cap, applied_damage * injury_damage_multiplier)
	if randi() % 100 < injury_chance:
		var arr: Array = person.boxing_profile.get("current_injuries", []) if typeof(person.boxing_profile.get("current_injuries", [])) == TYPE_ARRAY else []
		arr.append({
			"name": str(_boxing_policy("fight_damage_injury_name", "Fight Damage")),
			"severity": max(1, int(applied_damage / 4.0)),
			"recovery_years": int(_boxing_policy("fight_damage_recovery_years", 1)),
			"source": "fight",
		})
		person.boxing_profile ["current_injuries"] = arr


func yearly_recovery(person: Person) -> void:
	if person == null:
		return

	var kept: Array = []
	for raw_injury in person.boxing_profile.get("current_injuries", []):
		if typeof(raw_injury) != TYPE_DICTIONARY:
			continue

		var injury: Dictionary = raw_injury as Dictionary
		injury ["recovery_years"] = int(injury.get("recovery_years", 1)) - 1
		if int(injury ["recovery_years"]) > 0:
			kept.append(injury)

	person.boxing_profile ["current_injuries"] = kept

	var retirement_threshold: int = int(_boxing_policy("wear_retirement_threshold", 75))
	var retirement_chance: int = int(_boxing_policy("wear_retirement_chance", 20))
	var retirement_enabled: bool = bool(_boxing_policy("wear_retirement_enabled", true))

	if retirement_enabled and int(person.boxing_profile.get("wear", 0)) >= retirement_threshold and randi() % 100 < retirement_chance:
		person.boxing_profile ["retired"] = true
		var txt: String = "🧤 %s retired from boxing after too much wear and damage." % person.first_name

		if gs != null and gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_RETIREMENT, {
				"npc_id": person.id,
				"text": txt,
				"contract_source": "boxing_injury_engine"
			})