extends Resource
class_name BoxingFightSimEngine

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

func simulate_fight(a: Person, b: Person, meta:= {}) -> Dictionary:
	if a == null or b == null:
		return { "success": false, "text": "\n❌\n Fight could not be simulated."}

	var meta_dict: Dictionary = meta if typeof(meta) == TYPE_DICTIONARY else {}
	var resolution: Dictionary = {}

	var prebuilt_raw: Variant = meta_dict.get("prebuilt_combat_resolution", {})
	if typeof(prebuilt_raw) == TYPE_DICTIONARY and not (prebuilt_raw as Dictionary).is_empty():
		resolution = (prebuilt_raw as Dictionary).duplicate(true)
	else:
		if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("simulate_fight"):
			resolution = gs.boxing_combat_resolution_engine.simulate_fight(a, b, meta_dict)

	if resolution.is_empty() or not bool(resolution.get("success", false)):
		resolution = _fallback_score_fight(a, b, meta_dict)

	var winner = a if int(resolution.get("winner_id", int(a.id))) == int(a.id) else b
	var loser = b if winner == a else a
	var result_type: String = str(resolution.get("result_type", "Decision"))
	var division: String = str(winner.boxing_profile.get("weight_class", meta_dict.get("division", "")))
	var fight_logs: Array = resolution.get("round_logs", []) if typeof(resolution.get("round_logs", [])) == TYPE_ARRAY else []

	if fight_logs.is_empty() and gs.boxing_round_log_engine != null:
		fight_logs = gs.boxing_round_log_engine.generate_fight_log(a, b, winner.id, result_type)

	_apply_result(winner, loser, result_type)

	winner.boxing_profile ["round_log_last_fight"] = fight_logs.duplicate(true)
	loser.boxing_profile ["round_log_last_fight"] = fight_logs.duplicate(true)

	var txt: String = "\n🥊\n %s %s defeated %s %s by %s." % [
		winner.first_name,
		winner.last_name,
		loser.first_name,
		loser.last_name,
		result_type
	]

	var belts: Array = meta_dict.get("belts", []) if typeof(meta_dict.get("belts", [])) == TYPE_ARRAY else []
	if belts.is_empty() and str(meta_dict.get("belt", "")) != "":
		belts.append(str(meta_dict.get("belt", "")))

	var payload:= {
		"npc_id": int(winner.id),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"text": txt,
		"round_logs": fight_logs.duplicate(true),
		"result_type": result_type,
		"division": division,
		"title_fight": bool(meta_dict.get("title_fight", false)),
		"belt": str(meta_dict.get("belt", "")),
		"belts": belts.duplicate(true),
		"lineal_fight": bool(meta_dict.get("lineal_fight", false)),
		"undisputed_possible": bool(meta_dict.get("undisputed_possible", false)),
		"combat_resolution": resolution.duplicate(true),
		"venue": meta_dict.get("venue", {}).duplicate(true) if typeof(meta_dict.get("venue", {})) == TYPE_DICTIONARY else {}
	}

	var economy: Dictionary = {}
	if gs.boxing_fight_economy_engine != null and gs.boxing_fight_economy_engine.has_method("settle_fight_economy"):
		economy = gs.boxing_fight_economy_engine.settle_fight_economy(winner, loser, payload, meta_dict)

	payload ["economy"] = economy.duplicate(true)

	_append_fight_history(winner, loser, result_type, division, fight_logs, true, payload)
	_append_fight_history(loser, winner, result_type, division, fight_logs, false, payload)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_FIGHT_COMPLETED, payload)

	return {
		"success": true,
		"text": txt,
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"result_type": result_type,
		"round_logs": fight_logs.duplicate(true),
		"economy": economy.duplicate(true),
		"combat_resolution": resolution.duplicate(true),
		"popup_title": "Fight Result",
		"popup_text": txt,
		"popup_footer": "Tap anywhere to continue."
	}
func _fighter_score(person: Person, ratings: Dictionary) -> int:
	var score:= 0
	score += int(ratings.get("power", 50))
	score += int(ratings.get("speed", 50))
	score += int(ratings.get("chin", 50))
	score += int(ratings.get("ring_iq", 50))
	score += int(ratings.get("defense", 50))
	score += int(ratings.get("footwork", 50))
	score += int(ratings.get("cardio", 50))
	score += int(ratings.get("killer_instinct", 50))

	score += int(person.health / 4)
	score -= int(person.boxing_profile.get("wear", 0) / 3)
	score -= int(person.boxing_profile.get("scar_tissue", 0) / 2)
	score -= person.boxing_profile.get("current_injuries", []).size() * 5
	var bp = person.boxing_profile.get("boxing_personality", {})
	var age = person.age
	var prime = person.boxing_profile.get("prime_years", { "start": 24, "end": 31})

	if age >= int(prime.get("start", 24)) and age <= int(prime.get("end", 31)):
		score += 12
	elif age > int(prime.get("end", 31)):
		score -= min(18, age - int(prime.get("end", 31)))

	score += int(bp.get("discipline", 50) / 8.0)
	score += int(bp.get("adaptability", 50) / 8.0)
	score += int(bp.get("courage", 50) / 10.0)

	if "Pressure Fighter" in person.boxing_profile.get("style_tags", []):
		score += int(ratings.get("power", 50) / 12.0)

	if "Counterpuncher" in person.boxing_profile.get("style_tags", []):
		score += int(ratings.get("ring_iq", 50) / 12.0)

	if "Out-Boxer" in person.boxing_profile.get("style_tags", []):
		score += int(ratings.get("footwork", 50) / 12.0)
	return score + randi_range(-20, 20)

func _apply_result(winner: Person, loser: Person, result_type: String) -> void:
	var wrec = winner.boxing_profile ["record"]
	var lrec = loser.boxing_profile ["record"]

	wrec ["wins"] += 1
	lrec ["losses"] += 1

	if result_type in ["KO", "TKO"]:
		wrec ["kos"] += 1
		gs.boxing_injury_engine.apply_fight_wear(loser, randi_range(10, 20))
	else:
		gs.boxing_injury_engine.apply_fight_wear(loser, randi_range(5, 12))
		gs.boxing_injury_engine.apply_fight_wear(winner, randi_range(1, 6))

	winner.boxing_profile ["last_fight_year"] = gs.year
	loser.boxing_profile ["last_fight_year"] = gs.year
	winner.boxing_profile ["scheduled_opponent_id"] = -1
	loser.boxing_profile ["scheduled_opponent_id"] = -1
func _append_fight_history(person: Person, opponent: Person, result_type: String, division: String, fight_logs: Array, won: bool, payload: Dictionary = {}) -> void:
	var history = person.boxing_profile.get("fight_history", []) if typeof(person.boxing_profile.get("fight_history", [])) == TYPE_ARRAY else []
	var opponent_record: Dictionary = opponent.boxing_profile.get("record", {}) if opponent != null and typeof(opponent.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
	var opponent_archetype: Dictionary = opponent.boxing_profile.get("fighter_archetype", {}) if opponent != null and typeof(opponent.boxing_profile.get("fighter_archetype", {})) == TYPE_DICTIONARY else {}

	history.append({
		"year": gs.year,
		"opponent_id": int(opponent.id),
		"opponent_name": "%s %s" % [opponent.first_name, opponent.last_name],
		"opponent_record": opponent_record.duplicate(true),
		"opponent_archetype": opponent_archetype.duplicate(true),
		"won": won,
		"result_type": result_type,
		"division": division,
		"rounds": fight_logs.size(),
		"title_fight": bool(payload.get("title_fight", false)),
		"belts": payload.get("belts", []).duplicate(true) if typeof(payload.get("belts", [])) == TYPE_ARRAY else [],
		"lineal_fight": bool(payload.get("lineal_fight", false)),
		"undisputed_possible": bool(payload.get("undisputed_possible", false)),
		"economy": payload.get("economy", {}).duplicate(true) if typeof(payload.get("economy", {})) == TYPE_DICTIONARY else {}
	})

	if history.size() > 80:
		history.pop_front()

	person.boxing_profile ["fight_history"] = history
func _fallback_score_fight(a: Person, b: Person, meta: Dictionary = {}) -> Dictionary:
	var ar: Dictionary = a.boxing_profile.get("ratings", {}) if typeof(a.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var br: Dictionary = b.boxing_profile.get("ratings", {}) if typeof(b.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var a_score: int = _fighter_score(a, ar)
	var b_score: int = _fighter_score(b, br)
	var result_type: String = str(_boxing_policy("default_result_type", "Decision"))
	var winner: Person = a
	var loser: Person = b

	if b_score > a_score:
		winner = b
		loser = a

	var gap: int = abs(a_score - b_score)
	var ko_gap: int = int(_boxing_policy("fallback_ko_score_gap", 18))
	var ko_chance: int = int(_boxing_policy("fallback_ko_chance", 60))
	var tko_gap: int = int(_boxing_policy("fallback_tko_score_gap", 10))
	var tko_chance: int = int(_boxing_policy("fallback_tko_chance", 35))

	if gap >= ko_gap and randi() % 100 < ko_chance:
		result_type = "KO"
	elif gap >= tko_gap and randi() % 100 < tko_chance:
		result_type = "TKO"

	var fight_logs: Array = []
	if gs.boxing_round_log_engine != null:
		fight_logs = gs.boxing_round_log_engine.generate_fight_log(a, b, winner.id, result_type)

	return {
		"success": true,
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"result_type": result_type,
		"round_logs": fight_logs,
		"fallback": true,
		"contract_source": "boxing_fight_sim_engine",
		"meta": meta.duplicate(true)
	}