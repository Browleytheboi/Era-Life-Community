extends Resource
class_name BoxingRankingEngine

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
var rankings:= {}
var amateur_rankings:= {}

func _init(_gs):
	gs = _gs
	rankings = _default_rankings()
	amateur_rankings = _default_rankings()

func _default_rankings() -> Dictionary:
	return {
		"Flyweight": [],
		"Bantamweight": [],
		"Featherweight": [],
		"Lightweight": [],
		"Welterweight": [],
		"Middleweight": [],
		"Light Heavyweight": [],
		"Heavyweight": []
	}

func ensure_division(division: String) -> void:
	var clean_division: String = str(division).strip_edges()
	if clean_division == "":
		return

	if not rankings.has(clean_division):
		rankings [clean_division] = []

	if not amateur_rankings.has(clean_division):
		amateur_rankings [clean_division] = []
func _boxing_gender_division_for_person(person: Person) -> String:
	if person == null:
		return "Male"

	var direct: String = str(person.boxing_profile.get("boxing_gender_division", "")).strip_edges()
	var direct_lower: String = direct.to_lower()
	if direct_lower in ["female", "woman", "girl", "f"]:
		return "Female"
	if direct_lower in ["male", "man", "boy", "m"]:
		return "Male"

	var gender_text: String = str(person.gender if "gender" in person else "").strip_edges().to_lower()
	if gender_text in ["female", "woman", "girl", "f"]:
		return "Female"

	return "Male"


func _boxing_rank_bucket_key(division: String, gender_division: String = "") -> String:
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"
	return "%s:%s" % [clean_gender, clean_division]


func _boxing_rank_bucket_display_division(bucket_key: String) -> String:
	var clean: String = str(bucket_key).strip_edges()
	if clean.find(":") >= 0:
		return clean.split(":") [-1]
	return clean


func _boxing_rank_bucket_gender(bucket_key: String) -> String:
	var clean: String = str(bucket_key).strip_edges()
	if clean.find(":") >= 0:
		return clean.split(":") [0]
	return "Male"
func _boxing_is_professional_ranked(person: Person) -> bool:
	if person == null:
		return false
	if not person.alive:
		return false
	if not bool(person.boxing_profile.get("is_boxer", false)):
		return false
	if bool(person.boxing_profile.get("retired", false)):
		return false
	return bool(person.boxing_profile.get("turned_pro", false))


func _boxing_is_amateur_ranked(person: Person) -> bool:
	if person == null:
		return false
	if not person.alive:
		return false
	if not bool(person.boxing_profile.get("is_boxer", false)):
		return false
	if bool(person.boxing_profile.get("retired", false)):
		return false

	var circuit: Dictionary = {}
	var raw_circuit: Variant = person.boxing_profile.get("amateur_circuit", {})
	if typeof(raw_circuit) == TYPE_DICTIONARY:
		circuit = raw_circuit

	return bool(circuit.get("is_amateur", false)) and not bool(person.boxing_profile.get("turned_pro", false))


func _boxing_record_for_mode(person: Person, mode: String) -> Dictionary:
	if person == null:
		return {}

	var clean_mode: String = str(mode).strip_edges().to_lower()
	var record_key: String = "record"
	if clean_mode == "amateur":
		record_key = "amateur_record"

	var raw_record: Variant = person.boxing_profile.get(record_key, {})
	if typeof(raw_record) == TYPE_DICTIONARY:
		return raw_record

	return {}


func _boxing_record_text_for_mode(person: Person, mode: String) -> String:
	var record: Dictionary = _boxing_record_for_mode(person, mode)

	return "%d-%d-%d (%d KOs)" % [
		int(record.get("wins", 0)),
		int(record.get("losses", 0)),
		int(record.get("draws", 0)),
		int(record.get("kos", 0))
	]


func _boxing_belt_count(person: Person) -> int:
	if person == null:
		return 0

	var raw_belts: Variant = person.boxing_profile.get("belts", [])
	if typeof(raw_belts) == TYPE_ARRAY:
		return (raw_belts as Array).size()

	return 0

func _boxing_is_active_division_title_holder(person: Person, division: String = "", gender_division: String = "") -> bool:
	if person == null:
		return false

	var clean_division: String = str(division).strip_edges()
	if clean_division == "":
		clean_division = str(person.boxing_profile.get("weight_class", "")).strip_edges()
	if clean_division == "":
		return false

	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = _boxing_gender_division_for_person(person)

	var person_id: int = int(person.id)

	var raw_belts: Variant = person.boxing_profile.get("belts", [])
	if typeof(raw_belts) == TYPE_ARRAY:
		for raw_belt in raw_belts:
			var belt_text: String = str(raw_belt).strip_edges()
			if belt_text == "":
				continue
			if belt_text in ["WBA", "WBC", "IBF", "WBO", "Ring Magazine"]:
				return true
			if belt_text.find(clean_division) >= 0:
				return true

	if gs != null and gs.boxing_title_engine != null and typeof(gs.boxing_title_engine.champions) == TYPE_DICTIONARY:
		var bucket_keys: Array = [
			"%s:%s" % [clean_gender, clean_division],
			clean_division
		]

		for raw_bucket_key in bucket_keys:
			var bucket_key: String = str(raw_bucket_key).strip_edges()
			if bucket_key == "":
				continue

			var champions_raw: Variant = gs.boxing_title_engine.champions.get(bucket_key, {})
			if typeof(champions_raw) != TYPE_DICTIONARY:
				continue

			var champions: Dictionary = champions_raw
			for raw_body in champions.keys():
				if int(champions.get(raw_body, -1)) == person_id:
					return true

	return false
func _division_ranking_score(person: Person, mode: String) -> int:
	if person == null:
		return -999999

	var clean_mode: String = str(mode).strip_edges().to_lower()
	var record: Dictionary = _boxing_record_for_mode(person, clean_mode)
	var amateur_record: Dictionary = _boxing_record_for_mode(person, "amateur")
	var belts: int = _boxing_belt_count(person)

	var wins: int = int(record.get("wins", 0))
	var losses: int = int(record.get("losses", 0))
	var draws: int = int(record.get("draws", 0))
	var kos: int = int(record.get("kos", 0))

	var score: int = 0
	score += wins * 12
	score += kos * 5
	score += draws * 2
	score -= losses * 15
	score += int(float(person.fame) * 0.45)

	if clean_mode == "pro":
		score += belts * 140
		score += int(amateur_record.get("wins", 0)) * 3
		score += int(amateur_record.get("kos", 0)) * 2
		score -= int(amateur_record.get("losses", 0)) * 2

		if wins == 0 and losses == 0 and belts <= 0:
			score -= 500
	else:
		score += int(amateur_record.get("wins", 0)) * 10
		score += int(amateur_record.get("kos", 0)) * 4
		score -= int(amateur_record.get("losses", 0)) * 10

	if bool(person.boxing_profile.get("undisputed", false)):
		score += 260

	return score


func get_division_ranked_ids(division: String, mode: String = "pro", limit: int = 10, gender_division: String = "Male") -> Array:
	var clean_division: String = str(division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"
	if clean_division == "":
		return []

	var bucket_key: String = _boxing_rank_bucket_key(clean_division, clean_gender)

	ensure_division(bucket_key)
	_refresh_division(bucket_key)

	var source: Array = []
	if clean_mode == "amateur":
		source = amateur_rankings.get(bucket_key, [])
	else:
		source = rankings.get(bucket_key, [])

	var out: Array = []
	for raw_id in source:
		var fighter_id: int = int(raw_id)
		if fighter_id <= 0:
			continue

		var fighter: Person = gs.get_npc_by_id(fighter_id) if gs != null else null
		if fighter == null:
			continue

		if clean_mode == "pro" and _boxing_is_active_division_title_holder(fighter, clean_division, clean_gender):
			fighter.boxing_profile ["division_rank"] = 0
			continue

		out.append(fighter_id)
		if out.size() >= limit:
			break

	return out
func seed_fighter(person: Person) -> void:
	if person == null:
		return

	var division: String = str(person.boxing_profile.get("weight_class", "")).strip_edges()
	if division == "":
		return

	var gender_division: String = _boxing_gender_division_for_person(person)
	var bucket_key: String = _boxing_rank_bucket_key(division, gender_division)

	ensure_division(bucket_key)

	if _boxing_is_professional_ranked(person):
		if int(person.id) not in rankings [bucket_key]:
			rankings [bucket_key].append(int(person.id))
		amateur_rankings [bucket_key].erase(int(person.id))
	elif _boxing_is_amateur_ranked(person):
		if int(person.id) not in amateur_rankings [bucket_key]:
			amateur_rankings [bucket_key].append(int(person.id))
		rankings [bucket_key].erase(int(person.id))
	else:
		rankings [bucket_key].erase(int(person.id))
		amateur_rankings [bucket_key].erase(int(person.id))

	_refresh_division(bucket_key)

func on_fight_completed(payload: Dictionary) -> void:
	if gs == null:
		return

	var winner_id: int = int(payload.get("winner_id", -1))
	var loser_id: int = int(payload.get("loser_id", -1))
	var winner: Person = gs.get_npc_by_id(winner_id)
	var loser: Person = gs.get_npc_by_id(loser_id)
	if winner == null or loser == null:
		return

	var division: String = str(payload.get("division", winner.boxing_profile.get("weight_class", ""))).strip_edges()
	if division == "":
		return

	ensure_division(division)
	seed_fighter(winner)
	seed_fighter(loser)
	_refresh_division(division)
func _refresh_division(division: String) -> void:
	if gs == null:
		return

	var bucket_key: String = str(division).strip_edges()
	if bucket_key == "":
		return

	ensure_division(bucket_key)

	var bucket_gender: String = "Male"
	var bucket_division: String = bucket_key
	if bucket_key.find(":") >= 0:
		var parts: PackedStringArray = bucket_key.split(":")
		if parts.size() >= 2:
			bucket_gender = str(parts [0]).strip_edges()
			bucket_division = str(parts [parts.size() - 1]).strip_edges()

	if bucket_gender == "":
		bucket_gender = "Male"
	if bucket_division == "":
		return

	var pro_seen: Dictionary = {}
	var amateur_seen: Dictionary = {}
	var pro_list: Array = []
	var amateur_list: Array = []

	for raw_id in rankings.get(bucket_key, []):
		var pro_npc: Person = gs.get_npc_by_id(int(raw_id))
		if pro_npc == null:
			continue
		if str(pro_npc.boxing_profile.get("weight_class", "")).strip_edges() != bucket_division:
			continue
		if _boxing_gender_division_for_person(pro_npc) != bucket_gender:
			continue
		if not _boxing_is_professional_ranked(pro_npc):
			continue
		if _boxing_is_active_division_title_holder(pro_npc, bucket_division, bucket_gender):
			pro_npc.boxing_profile ["division_rank"] = 0
			continue

		var pro_key: String = str(int(pro_npc.id))
		if pro_seen.has(pro_key):
			continue

		pro_seen [pro_key] = true
		pro_list.append(int(pro_npc.id))

	for raw_amateur_id in amateur_rankings.get(bucket_key, []):
		var amateur_npc: Person = gs.get_npc_by_id(int(raw_amateur_id))
		if amateur_npc == null:
			continue
		if str(amateur_npc.boxing_profile.get("weight_class", "")).strip_edges() != bucket_division:
			continue
		if _boxing_gender_division_for_person(amateur_npc) != bucket_gender:
			continue
		if not _boxing_is_amateur_ranked(amateur_npc):
			continue

		var amateur_key: String = str(int(amateur_npc.id))
		if amateur_seen.has(amateur_key):
			continue

		amateur_seen [amateur_key] = true
		amateur_list.append(int(amateur_npc.id))

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null:
			continue
		if str(npc.boxing_profile.get("weight_class", "")).strip_edges() != bucket_division:
			continue
		if _boxing_gender_division_for_person(npc) != bucket_gender:
			continue

		if _boxing_is_professional_ranked(npc):
			if _boxing_is_active_division_title_holder(npc, bucket_division, bucket_gender):
				npc.boxing_profile ["division_rank"] = 0
				continue

			var npc_pro_key: String = str(int(npc.id))
			if not pro_seen.has(npc_pro_key):
				pro_seen [npc_pro_key] = true
				pro_list.append(int(npc.id))
		elif _boxing_is_amateur_ranked(npc):
			var npc_amateur_key: String = str(int(npc.id))
			if not amateur_seen.has(npc_amateur_key):
				amateur_seen [npc_amateur_key] = true
				amateur_list.append(int(npc.id))

	pro_list.sort_custom(func (a, b):
		var fighter_a: Person = gs.get_npc_by_id(int(a))
		var fighter_b: Person = gs.get_npc_by_id(int(b))
		return _division_ranking_score(fighter_a, "pro") > _division_ranking_score(fighter_b, "pro")
	)

	amateur_list.sort_custom(func (a, b):
		var fighter_a: Person = gs.get_npc_by_id(int(a))
		var fighter_b: Person = gs.get_npc_by_id(int(b))
		return _division_ranking_score(fighter_a, "amateur") > _division_ranking_score(fighter_b, "amateur")
	)

	var ranking_limit: int = int(_boxing_policy("division_ranking_limit", 50))
	ranking_limit = max(50, ranking_limit)

	rankings [bucket_key] = pro_list.slice(0, min(ranking_limit, pro_list.size()))
	amateur_rankings [bucket_key] = amateur_list.slice(0, min(ranking_limit, amateur_list.size()))

	for i in range(rankings [bucket_key].size()):
		var pro_ranked: Person = gs.get_npc_by_id(int(rankings [bucket_key] [i]))
		if pro_ranked != null:
			pro_ranked.boxing_profile ["division_rank"] = i + 1
			pro_ranked.boxing_profile ["title_contender"] = i < 5

	for i in range(amateur_rankings [bucket_key].size()):
		var amateur_ranked: Person = gs.get_npc_by_id(int(amateur_rankings [bucket_key] [i]))
		if amateur_ranked != null:
			amateur_ranked.boxing_profile ["amateur_division_rank"] = i + 1
func build_pound_for_pound_payload(mode: String = "pro", gender_division: String = "") -> Dictionary:
	var rows: Array = []
	var clean_mode: String = str(mode).strip_edges().to_lower()
	if clean_mode == "":
		clean_mode = "pro"

	var clean_gender: String = str(gender_division).strip_edges()
	var clean_gender_lower: String = clean_gender.to_lower()
	if clean_gender_lower in ["female", "woman", "girl", "f"]:
		clean_gender = "Female"
	else:
		clean_gender = "Male"

	if gs == null:
		return {
			"schema": "eralife.boxing_pound_for_pound_payload",
			"version": 4,
			"mode": clean_mode,
			"gender_division": clean_gender,
			"fighters": [],
			"contract_source": "boxing_ranking_engine",
			"built_at_ms": int(Time.get_ticks_msec())
		}

	if gs.boxing_engine != null and gs.boxing_engine.has_method("normalize_generated_boxing_faction_identity_names"):
		gs.boxing_engine.normalize_generated_boxing_faction_identity_names("build_pound_for_pound_payload:%s:%s" % [clean_mode, clean_gender])

	for npc in gs.npcs:
		if npc == null:
			continue

		var npc_gender: String = _boxing_gender_division_for_person(npc)
		if npc_gender != clean_gender:
			continue

		if clean_mode == "amateur":
			if not _boxing_is_amateur_ranked(npc):
				continue
			if int(npc.age) < 18:
				continue
		else:
			if not _boxing_is_professional_ranked(npc):
				continue

		var score: int = _pound_for_pound_score(npc, clean_mode)
		var record: Dictionary = _boxing_record_for_mode(npc, clean_mode)
		var archetype: Dictionary = {}
		var raw_archetype: Variant = npc.boxing_profile.get("fighter_archetype", {})
		if typeof(raw_archetype) == TYPE_DICTIONARY:
			archetype = raw_archetype

		var full_name: String = ("%s %s" % [
			str(npc.first_name).strip_edges(),
			str(npc.last_name).strip_edges()
		]).strip_edges()
		if full_name == "":
			full_name = str(npc.name).strip_edges()
		if full_name == "":
			full_name = "Unknown Fighter"

		rows.append({
			"person_id": int(npc.id),
			"name": full_name,
			"division": "%s %s" % [npc_gender, str(npc.boxing_profile.get("weight_class", ""))],
			"rank_in_division": int(npc.boxing_profile.get("amateur_division_rank", 99)) if clean_mode == "amateur" else int(npc.boxing_profile.get("division_rank", 99)),
			"record": record.duplicate(true),
			"record_text": _boxing_record_text_for_mode(npc, clean_mode),
			"belts": npc.boxing_profile.get("belts", []).duplicate(true) if typeof(npc.boxing_profile.get("belts", [])) == TYPE_ARRAY else [],
			"belt_count": _boxing_belt_count(npc),
			"archetype_name": str(archetype.get("name", "Balanced Boxer")),
			"gender_division": npc_gender,
			"score": score
		})

	rows.sort_custom(func (a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	var ranked: Array = []
	var pfp_limit: int = int(_boxing_policy("pound_for_pound_limit", 10))
	pfp_limit = max(10, pfp_limit)

	for i in range(min(pfp_limit, rows.size())):
		var row: Dictionary = rows [i]
		row ["rank"] = i + 1
		ranked.append(row)

	return {
		"schema": "eralife.boxing_pound_for_pound_payload",
		"version": 4,
		"mode": clean_mode,
		"gender_division": clean_gender,
		"fighters": ranked,
		"contract_source": "boxing_ranking_engine",
		"built_at_ms": int(Time.get_ticks_msec())
	}
func _pound_for_pound_score(npc: Person, mode: String = "pro") -> int:
	if npc == null:
		return -999999

	var clean_mode: String = str(mode).strip_edges().to_lower()
	var rec: Dictionary = _boxing_record_for_mode(npc, clean_mode)
	var belts: Array = npc.boxing_profile.get("belts", []) if typeof(npc.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	var history: Array = npc.boxing_profile.get("fight_history", []) if typeof(npc.boxing_profile.get("fight_history", [])) == TYPE_ARRAY else []

	var wins: int = int(rec.get("wins", 0))
	var losses: int = int(rec.get("losses", 0))
	var draws: int = int(rec.get("draws", 0))
	var kos: int = int(rec.get("kos", 0))
	var score: int = 0

	score += wins * 10
	score += kos * 5
	score += draws * 2
	score -= losses * 12
	score += int(float(npc.fame) / 2.0)

	if clean_mode == "pro":
		score += belts.size() * 75
		score += max(0, 50 - int(npc.boxing_profile.get("division_rank", 99))) * 3
	else:
		score += max(0, 50 - int(npc.boxing_profile.get("amateur_division_rank", 99))) * 3
		score += int(npc.boxing_profile.get("golden_gloves_wins", 0)) * 45

	if bool(npc.boxing_profile.get("undisputed", false)):
		score += 160

	for row in history:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if bool(row.get("won", false)):
			if bool(row.get("title_fight", false)):
				score += 18
			if bool(row.get("lineal_fight", false)):
				score += 24

			var opponent_record: Dictionary = {}
			var raw_opponent_record: Variant = row.get("opponent_record", {})
			if typeof(raw_opponent_record) == TYPE_DICTIONARY:
				opponent_record = raw_opponent_record

			score += int(opponent_record.get("wins", 0)) * 2

	return score