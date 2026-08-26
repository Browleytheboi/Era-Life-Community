extends Resource
class_name BoxingFighterEngine

var gs

const WEIGHT_CLASSES = [
	"Flyweight",
	"Bantamweight",
	"Featherweight",
	"Lightweight",
	"Welterweight",
	"Middleweight",
	"Light Heavyweight",
	"Heavyweight"
]

const STYLES = [
	"Pressure Fighter",
	"Counterpuncher",
	"Out-Boxer",
	"Boxer-Puncher",
	"Southpaw Technician"
]

func _init(_gs):
	gs = _gs

func initialize_fighter(person: Person, context: Dictionary = {}) -> void:
	if person == null:
		return

	if "boxing" not in person.combat_sports_unlocked:
		person.combat_sports_unlocked.append("boxing")

	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		person.boxing_profile = {}

	if typeof(person.boxing_profile.get("ratings", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["ratings"] = {}

	if typeof(person.boxing_profile.get("amateur_circuit", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["amateur_circuit"] = {}

	person.boxing_profile ["is_boxer"] = true
	person.boxing_profile ["retired"] = false

	if bool(context.get("auto_assign_gym", false)):
		person.boxing_profile ["gym_id"] = str(context.get("gym_id", "")).strip_edges()
		person.boxing_profile ["gym_name"] = str(context.get("gym_name", _random_gym_name())).strip_edges()
	else:
		if not person.boxing_profile.has("gym_id"):
			person.boxing_profile ["gym_id"] = ""
		if not person.boxing_profile.has("gym_name"):
			person.boxing_profile ["gym_name"] = "No gym"

	person.boxing_profile ["stance"] = ["Orthodox", "Southpaw", "Switch"] [randi() % 3]

	var body_truth: Dictionary = {}
	if gs != null and gs.has_method("observe_body_contracts_for_person"):
		body_truth = gs.observe_body_contracts_for_person(person, {
			"source": "boxing_fighter_engine.initialize_fighter",
			"queue_if_missing": true
		})
	elif gs != null and gs.has_method("ensure_body_contracts_for_person"):
		body_truth = gs.ensure_body_contracts_for_person(person, {
			"source": "boxing_fighter_engine.initialize_fighter",
			"defer": true
		})

	var weight_contract: Dictionary = {}
	if typeof(body_truth.get("weight_contract", {})) == TYPE_DICTIONARY:
		weight_contract = body_truth.get("weight_contract", {}).duplicate(true)
	elif typeof(person.weight_contract) == TYPE_DICTIONARY:
		weight_contract = person.weight_contract.duplicate(true)

	var natural_weight: int = int(round(float(weight_contract.get("weight_lbs", randi_range(112, 240)))))
	var selected_division: String = str(context.get("division", context.get("selected_division", ""))).strip_edges()
	if selected_division == "":
		selected_division = _pick_weight_class(person)

	person.boxing_profile ["weight_class"] = selected_division
	person.boxing_profile ["natural_weight"] = natural_weight

	if typeof(person.boxing_profile.get("weight_management", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["weight_management"] = {}

	person.boxing_profile ["weight_management"] ["walkaround_weight"] = natural_weight
	person.boxing_profile ["weight_management"] ["preferred_division"] = selected_division
	person.boxing_profile ["weight_management"] ["body_source_of_truth"] = "weight_contract_engine"

	if bool(context.get("auto_assign_promoter", false)):
		person.boxing_profile ["promoter"] = str(context.get("promoter", _random_promoter())).strip_edges()
	else:
		if not person.boxing_profile.has("promoter"):
			person.boxing_profile ["promoter"] = "Unsigned"
		if not person.boxing_profile.has("promoter_id"):
			person.boxing_profile ["promoter_id"] = ""

	var force_amateur: bool = bool(context.get("force_amateur", false))
	var turned_pro: bool = bool(context.get("turned_pro", not force_amateur))
	person.boxing_profile ["turned_pro"] = turned_pro
	person.boxing_profile ["amateur_circuit"] ["is_amateur"] = not turned_pro
	person.boxing_profile ["amateur_circuit"] ["tier"] = "youth_amateur" if int(person.age) < 18 else "adult_amateur"
	person.boxing_profile ["amateur_circuit"] ["auto_turn_pro"] = false
	person.boxing_profile ["amateur_circuit"] ["may_turn_pro"] = int(person.age) >= 18

	var ratings: Dictionary = person.boxing_profile ["ratings"]

	ratings ["power"] = clamp(int(float(person.looks) / 2.0) + randi_range(20, 40), 1, 100)
	ratings ["speed"] = clamp(int(float(person.health) / 2.0) + randi_range(20, 40), 1, 100)
	ratings ["chin"] = clamp(int(float(person.health) / 2.0) + randi_range(15, 35), 1, 100)
	ratings ["heart"] = clamp(int(float(person.mental_health) / 2.0) + randi_range(15, 35), 1, 100)
	ratings ["ring_iq"] = clamp(int(float(person.smarts) / 2.0) + randi_range(20, 40), 1, 100)
	ratings ["defense"] = clamp(int(float(person.smarts) / 3.0) + randi_range(20, 40), 1, 100)
	ratings ["footwork"] = clamp(int(float(person.health) / 3.0) + randi_range(20, 40), 1, 100)
	ratings ["head_movement"] = clamp(int(float(person.smarts) / 3.0) + randi_range(18, 38), 1, 100)
	ratings ["blocking"] = clamp(int(float(person.health) / 3.0) + randi_range(18, 38), 1, 100)
	ratings ["cardio"] = clamp(int(float(person.health) / 2.0) + randi_range(20, 40), 1, 100)
	ratings ["endurance"] = clamp(int(float(person.health) / 2.0) + randi_range(18, 38), 1, 100)
	ratings ["strength"] = clamp(int(float(person.looks) / 2.0) + randi_range(18, 38), 1, 100)
	ratings ["jab"] = clamp(int(float(person.smarts) / 3.0) + randi_range(20, 45), 1, 100)
	ratings ["cross"] = clamp(int(float(person.health) / 3.0) + randi_range(20, 45), 1, 100)
	ratings ["left_hook"] = clamp(randi_range(25, 70), 1, 100)
	ratings ["right_hook"] = clamp(randi_range(25, 70), 1, 100)
	ratings ["left_uppercut"] = clamp(randi_range(20, 65), 1, 100)
	ratings ["right_uppercut"] = clamp(randi_range(20, 65), 1, 100)
	ratings ["body_work"] = clamp(randi_range(25, 75), 1, 100)
	ratings ["combinations"] = clamp(randi_range(20, 65), 1, 100)
	ratings ["killer_instinct"] = clamp(randi_range(25, 85), 1, 100)

	_initialize_boxing_personality(person)
	_assign_style_tags_from_personality(person)
	_initialize_prime_window(person)
	_initialize_boxing_family_context(person)

	if not person.boxing_profile.has("growth") or typeof(person.boxing_profile.get("growth", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["growth"] = {
			"xp": 0,
			"total_levels": 0,
			"max_total_levels": 220,
			"max_skill_level": 20,
			"levels": {}
		}

	person.boxing_profile ["style_tags"] = [STYLES [randi() % STYLES.size()]]
	person.boxing_profile ["division_rank"] = -1

	if gs != null and gs.boxing_ranking_engine != null:
		gs.boxing_ranking_engine.ensure_division(person.boxing_profile ["weight_class"])
		gs.boxing_ranking_engine.seed_fighter(person)
func _pick_weight_class(_person: Person) -> String:
	var w = randi_range(112, 240)
	if w <= 115: return "Flyweight"
	if w <= 118: return "Bantamweight"
	if w <= 126: return "Featherweight"
	if w <= 135: return "Lightweight"
	if w <= 147: return "Welterweight"
	if w <= 160: return "Middleweight"
	if w <= 175: return "Light Heavyweight"
	return "Heavyweight"

func _random_gym_name() -> String:
	var gyms = [
		"Iron Temple Boxing",
		"Southside Boxing Club",
		"Crown Gloves Gym",
		"Future Combat Lab"
	]
	return gyms [randi() % gyms.size()]

func _random_promoter() -> String:
	var names = [
		"Acrello Promotions",
		"Golden Crown Boxing",
		"Nova Fights",
		"Empire Ring Sports"
	]
	return names [randi() % names.size()]
func _initialize_boxing_personality(person: Person) -> void:
	var bp = person.boxing_profile ["boxing_personality"]

	bp ["discipline"] = clamp(person.smarts + randi_range(-15, 15), 1, 100)
	bp ["ego"] = clamp(randi_range(20, 80) + (10 if "Extrovert" in person.traits else 0), 1, 100)
	bp ["courage"] = clamp(randi_range(25, 90), 1, 100)
	bp ["showmanship"] = clamp(randi_range(20, 85) + (12 if "Extrovert" in person.traits else 0), 1, 100)
	bp ["violence"] = clamp(randi_range(15, 85) + (10 if "Mean" in person.traits else 0), 1, 100)
	bp ["adaptability"] = clamp(int(person.smarts * 0.7) + randi_range(-10, 15), 1, 100)
	bp ["professionalism"] = clamp(randi_range(20, 90) + (12 if "Loyal" in person.traits else 0), 1, 100)

func _assign_style_tags_from_personality(person: Person) -> void:
	var ratings = person.boxing_profile ["ratings"]
	var bp = person.boxing_profile ["boxing_personality"]
	var tags:= []

	if int(ratings ["speed"]) >= 70 and int(ratings ["footwork"]) >= 68:
		tags.append("Out-Boxer")

	if int(ratings ["ring_iq"]) >= 72 and int(ratings ["defense"]) >= 70:
		tags.append("Counterpuncher")

	if int(ratings ["power"]) >= 72 and int(bp ["violence"]) >= 60:
		tags.append("Pressure Fighter")

	if int(ratings ["power"]) >= 65 and int(ratings ["ring_iq"]) >= 65:
		tags.append("Boxer-Puncher")

	if str(person.boxing_profile.get("stance", "")) == "Southpaw":
		tags.append("Southpaw Technician")

	if tags.is_empty():
		tags.append(STYLES [randi() % STYLES.size()])

	person.boxing_profile ["style_tags"] = tags

func _initialize_prime_window(person: Person) -> void:
	person.boxing_profile ["prime_years"] = {
		"start": 24 + randi_range(0, 2),
		"end": 31 + randi_range(0, 4)
	}

func _initialize_boxing_family_context(person: Person) -> void:
	var boxer_parents:= []
	for pid in person.parents:
		var p = gs.get_npc_by_id(pid)
		if p != null and p.boxing_profile.get("is_boxer", false):
			boxer_parents.append(pid)

	person.boxing_profile ["boxing_family"] ["parent_boxer_ids"] = boxer_parents
	person.boxing_profile ["boxing_family"] ["family_gym"] = person.boxing_profile.get("gym_name", "")
	person.boxing_profile ["boxing_family"] ["fighting_dynasty_name"] = person.last_name
	person.boxing_profile ["boxing_family"] ["legacy_pressure"] = boxer_parents.size() * 20