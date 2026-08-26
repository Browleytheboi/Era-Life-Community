extends Resource
class_name FamilyCreationContractEngine

const CONTRACT_SCHEMA:= "eralife.family_creation_contract_engine"
const CONTRACT_VERSION:= 1

var gs


func _init(_gs = null):
	gs = _gs


func build_world_catalog(context: Dictionary = {}) -> Dictionary:
	var year_value: int = int(context.get("year", 2000))
	var era_key: String = str(context.get("era", year_to_era(year_value))).strip_edges()
	if era_key == "":
		era_key = year_to_era(year_value)

	var reality_mode: String = str(context.get("reality_mode", "chaos")).strip_edges().to_lower()
	if reality_mode == "":
		reality_mode = "chaos"

	var social_class: String = str(context.get("default_social_class", context.get("social_class", "Middle Class"))).strip_edges()
	if social_class == "":
		social_class = "Middle Class"

	var countries: Array = country_options_for(era_key, reality_mode)
	var selected_country: String = str(context.get("country", "")).strip_edges()
	if selected_country == "" or not countries.has(selected_country):
		selected_country = str(countries [0]) if not countries.is_empty() else ""

	var cities: Array = city_options_for(era_key, reality_mode, selected_country)
	var selected_city: String = str(context.get("city", "")).strip_edges()
	if selected_city == "" or not cities.has(selected_city):
		selected_city = str(cities [0]) if not cities.is_empty() else ""

	return {
		"schema": "eralife.family_creation_world_catalog",
		"version": CONTRACT_VERSION,
		"era": era_key,
		"year": year_value,
		"reality_mode": reality_mode,
		"selected_country": selected_country,
		"selected_city": selected_city,
		"era_options": _era_options_from_engine(),
		"reality_mode_options": ["realistic", "enhanced", "chaos"],
		"class_options": ["Poor", "Working Class", "Middle Class", "Wealthy", "Noble", "Royal"],
		"country_options": countries,
		"city_options": cities,
		"house_type_options": house_type_options_for(era_key, social_class),
		"job_options": job_options_for(era_key, reality_mode),
		"relationship_options": relationship_options(),
		"stat_options": ["health", "smarts", "looks", "imagination", "mental_health"]
	}

func year_to_era(year_value: int) -> String:
	if year_value <= 476:
		return "Ancient"
	if year_value <= 1492:
		return "Medieval"
	if year_value <= 1945:
		return "Industrial"
	if year_value <= 2039:
		return "Modern"
	return "Future"


func country_options_for(era_key: String, reality_mode: String) -> Array:
	var countries: Array = []

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_countries_for_era"):
		countries = gs.era_engine.get_countries_for_era(era_key)

	if countries.is_empty() and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations_for_era"):
		for raw_location in gs.era_engine.get_birth_locations_for_era(era_key):
			if typeof(raw_location) != TYPE_DICTIONARY:
				continue
			var location: Dictionary = raw_location as Dictionary
			var country: String = str(location.get("country", "")).strip_edges()
			if country != "":
				countries.append(country)

	countries = _filter_countries_for_reality_mode(countries, reality_mode)
	countries = _dedupe_sorted_strings(countries)

	if countries.is_empty():
		countries = _fallback_country_options_for_era(era_key)

	if countries.is_empty():
		countries = ["United States"]

	return _dedupe_sorted_strings(countries)

func city_options_for(era_key: String, reality_mode: String, country: String = "") -> Array:
	var cities: Array = []

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
		cities = gs.era_engine.get_cities_for_era_country(era_key, country)

	if cities.is_empty() and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations_for_era"):
		for raw_location in gs.era_engine.get_birth_locations_for_era(era_key):
			if typeof(raw_location) != TYPE_DICTIONARY:
				continue
			var location: Dictionary = raw_location as Dictionary
			var entry_country: String = str(location.get("country", "")).strip_edges()
			if country != "" and entry_country != country:
				continue
			var city: String = str(location.get("city", "")).strip_edges()
			if city != "":
				cities.append(city)

	cities = _filter_cities_for_reality_mode(era_key, cities, reality_mode)

	if cities.is_empty() and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
		cities = gs.era_engine.get_cities_for_era_country(era_key, "")
		cities = _filter_cities_for_reality_mode(era_key, cities, reality_mode)

	return _dedupe_sorted_strings(cities)
func _era_options_from_engine() -> Array:
	if gs != null and gs.era_engine != null and typeof(gs.era_engine.eras) == TYPE_DICTIONARY:
		var keys: Array = gs.era_engine.eras.keys()
		keys.sort()
		if not keys.is_empty():
			return keys

	return ["Ancient", "Medieval", "Industrial", "Modern", "Future"]


func _filter_countries_for_reality_mode(countries: Array, reality_mode: String) -> Array:
	var mode: String = str(reality_mode).strip_edges().to_lower()
	var out: Array = []

	for raw_country in countries:
		var country: String = str(raw_country).strip_edges()
		if country == "":
			continue
		if mode == "realistic" and _is_elemental_country_name(country):
			continue
		out.append(country)

	return out


func _filter_cities_for_reality_mode(_era_key: String, cities: Array, _reality_mode: String) -> Array:
	var out: Array = []

	for raw_city in cities:
		var city: String = str(raw_city).strip_edges()
		if city == "":
			continue
		out.append(city)

	return out


func _is_elemental_country_name(country: String) -> bool:
	var normalized: String = str(country).strip_edges().to_lower()
	return normalized.find("fire nation") >= 0 \
or normalized.find("earth kingdom") >= 0 \
or normalized.find("water tribe") >= 0 \
or normalized.find("air temple") >= 0 \
or normalized.find("republic city") >= 0

func _fallback_country_options_for_era(era_key: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()

	match era:
		"ancient":
			return ["China", "Egypt", "Greece", "Kush", "Persia", "Rome"]
		"medieval":
			return ["Byzantium", "England", "France", "Japan", "Mali", "Norway"]
		"industrial":
			return ["Brazil", "England", "France", "Germany", "Japan", "United States"]
		"future":
			return ["Atlantic Federation", "Lunar Commonwealth", "Mars Colony", "Neo Japan", "Pan-African Union", "United States"]
		_:
			return ["Brazil", "Canada", "France", "Japan", "Mexico", "South Korea", "United Kingdom", "United States"]
func _dedupe_sorted_strings(values: Array) -> Array:
	var out: Array = []
	var seen:= {}

	for raw_value in values:
		var value: String = str(raw_value).strip_edges()
		if value == "":
			continue

		var key: String = value.to_lower()
		if seen.has(key):
			continue

		seen [key] = true
		out.append(value)

	out.sort()
	return out


func house_type_options_for(era_key: String, social_class: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()
	var cls: String = str(social_class).strip_edges().to_lower()

	match cls:
		"poor":
			if era == "medieval":
				return ["Small hut", "Shared cottage", "Servant quarters"]
			return ["Tiny apartment", "Shared room", "Old trailer", "Small house"]
		"working class":
			return ["Apartment", "Starter house", "Townhouse", "Small family home"]
		"middle class":
			return ["Suburban house", "Family home", "Townhouse", "Condo"]
		"wealthy":
			return ["Large house", "Luxury condo", "Estate home", "Lake house"]
		"noble":
			if era == "modern" or era == "future":
				return ["Historic estate", "Private manor", "Luxury penthouse"]
			return ["Manor", "Noble estate", "Fortified villa"]
		"royal":
			if era == "future":
				return ["Orbital palace", "Royal citadel", "Dynasty tower"]
			return ["Palace", "Castle", "Royal estate"]
		_:
			return ["Family home", "Apartment", "Townhouse"]


func job_options_for(era_key: String, reality_mode: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()
	var mode: String = str(reality_mode).strip_edges().to_lower()
	var jobs: Array = []

	match era:
		"ancient":
			jobs = ["Farmer", "Soldier", "Scribe", "Merchant", "Priest", "Blacksmith", "Noble", "Ruler"]
		"medieval":
			jobs = ["Peasant", "Knight", "Monk", "Merchant", "Blacksmith", "Baker", "Noble", "Royal Guard"]
		"industrial":
			jobs = ["Factory Worker", "Teacher", "Doctor", "Soldier", "Shopkeeper", "Rail Worker", "Journalist", "Politician"]
		"future":
			jobs = ["AI Systems Tech", "Space Miner", "Cybernetic Doctor", "Drone Courier", "Terraformer", "Quantum Engineer", "Diplomat"]
		_:
			jobs = ["Unemployed", "Student", "Teacher", "Doctor", "Engineer", "Cashier", "Chef", "Soldier", "Police Officer", "Artist", "Content Creator", "Athlete"]

	if mode == "enhanced":
		jobs.append_array(["Power Registry Clerk", "Agency Recruiter", "Superhuman Trainer"])
	elif mode == "chaos":
		jobs.append_array(["Bending Instructor", "Hero Agency Intern", "Villain Analyst", "Realm Cartographer", "Artifact Broker"])

	return jobs


func relationship_options() -> Array:
	return ["Mother", "Father", "Son", "Daughter", "Brother", "Sister", "Husband", "Wife", "Ex", "Roommate", "Friend", "Uncle", "Aunt", "Cousin", "Grandparent"]


func normalize_relationship(raw_value: String) -> String:
	var value: String = str(raw_value).strip_edges().to_lower()
	match value:
		"mom", "mother":
			return "mother"
		"dad", "father":
			return "father"
		"son":
			return "son"
		"daughter":
			return "daughter"
		"brother":
			return "brother"
		"sister":
			return "sister"
		"husband":
			return "husband"
		"wife":
			return "wife"
		"ex", "ex partner", "ex-partner":
			return "ex"
		"roommate":
			return "roommate"
		"friend":
			return "friend"
		"uncle":
			return "uncle"
		"aunt":
			return "aunt"
		"cousin":
			return "cousin"
		"grandparent", "grandma", "grandpa":
			return "grandparent"
		_:
			return "none"


func relationship_gender_lock(raw_value: String) -> String:
	var relation: String = normalize_relationship(raw_value)
	match relation:
		"father", "son", "brother", "husband", "uncle":
			return "male"
		"mother", "daughter", "sister", "wife", "aunt":
			return "female"
		_:
			return ""


func member_requires_job(age_value: int) -> bool:
	return int(age_value) >= 18


func life_stage_age_range(stage_text: String) -> Dictionary:
	var stage: String = str(stage_text).strip_edges().to_lower()
	match stage:
		"baby":
			return { "min": 0, "max": 1, "default": 0}
		"child":
			return { "min": 2, "max": 12, "default": 8}
		"teen":
			return { "min": 13, "max": 17, "default": 16}
		"elder":
			return { "min": 65, "max": 130, "default": 70}
		_:
			return { "min": 18, "max": 64, "default": 25}


func relationship_age_range(raw_relation: String, anchor_age: int = -1) -> Dictionary:
	var relation: String = normalize_relationship(raw_relation)
	var clean_anchor_age: int = int(anchor_age)

	match relation:
		"mother", "father":
			if clean_anchor_age >= 0:
				var parent_min: int = int(clamp(clean_anchor_age + 16, 18, 130))
				return { "min": parent_min, "max": 130}
			return { "min": 18, "max": 130}

		"son", "daughter":
			if clean_anchor_age >= 16:
				return { "min": 0, "max": int(clamp(clean_anchor_age - 16, 0, 130))}
			return { "min": 0, "max": 0}

		"husband", "wife", "ex":
			return { "min": 18, "max": 130}

		"brother", "sister", "cousin":
			if clean_anchor_age >= 0:
				return {
					"min": int(clamp(clean_anchor_age - 25, 0, 130)),
					"max": int(clamp(clean_anchor_age + 25, 0, 130))
				}
			return { "min": 0, "max": 130}

		"uncle", "aunt":
			if clean_anchor_age >= 0:
				return { "min": int(clamp(clean_anchor_age + 10, 18, 130)), "max": 130}
			return { "min": 18, "max": 130}

		"grandparent":
			return { "min": 65, "max": 130}

		_:
			return { "min": 0, "max": 130}


func relationship_options_for_context(context: Dictionary = {}) -> Array:
	var gender: String = str(context.get("gender", "")).strip_edges().to_lower()
	var anchor_age: int = int(context.get("anchor_age", -1))
	var member_age: int = int(context.get("member_age", -1))
	var out: Array = []

	for raw_option in relationship_options():
		var option_text: String = str(raw_option).strip_edges()
		var relation: String = normalize_relationship(option_text)
		var lock: String = relationship_gender_lock(relation)

		if gender != "" and lock != "" and lock != gender:
			continue

		if relation in ["husband", "wife", "ex"]:
			if anchor_age >= 0 and anchor_age < 18:
				continue
			if member_age >= 0 and member_age < 18:
				continue

		if relation in ["son", "daughter"] and anchor_age >= 0 and anchor_age < 16:
			continue

		out.append(option_text)

	return out


func life_stage_for_age(age_value: int) -> String:
	var age: int = int(clamp(age_value, 0, 130))
	if age <= 1:
		return "Baby"
	if age <= 12:
		return "Child"
	if age <= 17:
		return "Teen"
	if age <= 64:
		return "Adult"
	return "Elder"


func validate_world_contract(world_contract: Dictionary) -> Dictionary:
	var required: Array = ["era", "year", "reality_mode", "default_social_class", "house_type", "country", "city"]
	for key in required:
		if str(world_contract.get(key, "")).strip_edges() == "":
			return {
				"success": false,
				"reason": "Select %s before prewarming the world seed." % str(key).replace("_", " ")
			}

	return {
		"success": true,
		"reason": "World contract valid."
	}


func validate_member_basic(member: Dictionary, slot_index: int, existing_members: Array) -> Dictionary:
	if str(member.get("first_name", "")).strip_edges() == "":
		return {
			"success": false,
			"reason": "Enter a first name."
		}

	if str(member.get("last_name", "")).strip_edges() == "":
		return {
			"success": false,
			"reason": "Enter a last name."
		}

	var age_value: int = int(member.get("age", -1))
	if age_value < 0 or age_value > 130:
		return {
			"success": false,
			"reason": "Enter a valid age."
		}

	if slot_index == 0 and age_value < 18:
		return {
			"success": false,
			"reason": "The first created household member must be an adult."
		}

	var gender: String = str(member.get("gender", "")).strip_edges().to_lower()
	if gender == "":
		return {
			"success": false,
			"reason": "Select a gender."
		}

	if member_requires_job(age_value) and str(member.get("job", "")).strip_edges() == "":
		return {
			"success": false,
			"reason": "Select a job / role."
		}

	if slot_index > 0:
		var anchor_key: String = str(member.get("relationship_anchor_key", "")).strip_edges()
		if anchor_key == "":
			return {
				"success": false,
				"reason": "Select who this person is related to."
			}

		var relation: String = normalize_relationship(str(member.get("relationship_to_anchor", "")))
		if relation == "" or relation == "none":
			return {
				"success": false,
				"reason": "Select their relationship."
			}

		var gender_lock: String = relationship_gender_lock(relation)
		if gender_lock != "" and gender != gender_lock:
			return {
				"success": false,
				"reason": "%s requires this member to be %s." % [relation.capitalize(), gender_lock.capitalize()]
			}

		var anchor_member: Dictionary = _member_by_local_key(existing_members, anchor_key)
		if not anchor_member.is_empty():
			var anchor_age: int = int(anchor_member.get("age", -1))
			var allowed_options: Array = relationship_options_for_context({
				"gender": gender,
				"anchor_age": anchor_age,
				"member_age": age_value
			})
			var allowed_relations: Array = []
			for raw_option in allowed_options:
				allowed_relations.append(normalize_relationship(str(raw_option)))

			if not allowed_relations.has(relation):
				return {
					"success": false,
					"reason": "That relationship does not fit this member's gender or age."
				}

			var age_range: Dictionary = relationship_age_range(relation, anchor_age)
			var min_age: int = int(age_range.get("min", 0))
			var max_age: int = int(age_range.get("max", 130))
			if age_value < min_age or age_value > max_age:
				return {
					"success": false,
					"reason": "%s must be age %d-%d for that relationship." % [relation.capitalize(), min_age, max_age]
				}

	return {
		"success": true,
		"reason": "Member basics valid."
	}


func _member_by_local_key(members: Array, local_key: String) -> Dictionary:
	var clean_key: String = str(local_key).strip_edges()
	if clean_key == "":
		return {}

	for raw_member in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue

		var member: Dictionary = raw_member as Dictionary
		if str(member.get("local_key", "")).strip_edges() == clean_key:
			return member.duplicate(true)

	return {}

func build_household_spawn_contract(world_contract: Dictionary, members: Array, start_person_key: String = "person_0") -> Dictionary:
	var family_spawn_policy: String = str(world_contract.get("family_spawn_policy", "house_is_family")).strip_edges().to_lower()
	if family_spawn_policy not in ["house_is_family", "spawn_with_family"]:
		family_spawn_policy = "house_is_family"

	var generate_external_family: bool = family_spawn_policy == "spawn_with_family"

	return {
		"schema": "eralife.custom_household_spawn_contract",
		"version": CONTRACT_VERSION,
		"source": "choose_household_creator_progressive",
		"mode": "pre_existing_household",
		"start_person_key": start_person_key,
		"members": members.duplicate(true),
		"location": {
			"city": str(world_contract.get("city", "")).strip_edges(),
			"country": str(world_contract.get("country", "")).strip_edges()
		},
		"era": {
			"key": str(world_contract.get("era", "")).strip_edges(),
			"year": int(world_contract.get("year", 2000))
		},
		"home": {
			"house_type": str(world_contract.get("house_type", "")).strip_edges()
		},
		"reality_mode": str(world_contract.get("reality_mode", "chaos")).strip_edges().to_lower(),
		"default_social_class": str(world_contract.get("default_social_class", "Middle Class")).strip_edges(),
		"relationship_policy": {
			"family_spawn_policy": family_spawn_policy,
			"generate_external_family": generate_external_family,
			"household_members_are_primary_family": not generate_external_family
		},
		"artifact_policy": {
			"allow_random_starting_artifacts": false,
			"adult_artifact_origin_language": "discovery_not_birth"
		},
		"diary_policy": {
			"mode": "already_living_identity",
		},
		"prewarm_policy": {
			"do_not_play_birth_intro_unless_newborn": true
		}
	}