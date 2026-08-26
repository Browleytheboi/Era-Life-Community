extends Resource
class_name BoxingPromotionEngine

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
var promoter_state:= {}
func _record_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	var raw_record: Variant = actor.boxing_profile.get("record", {})
	if typeof(raw_record) == TYPE_DICTIONARY:
		return raw_record
	return {}


func _win_percentage(actor: Person) -> float:
	var record: Dictionary = _record_for_actor(actor)
	var wins: int = int(record.get("wins", 0))
	var losses: int = int(record.get("losses", 0))
	var draws: int = int(record.get("draws", 0))
	var total: int = wins + losses + draws
	if total <= 0:
		return 0.0
	return float(wins) / float(total)


func _world_title_count(actor: Person) -> int:
	if actor == null:
		return 0
	var belts: Array = actor.boxing_profile.get("belts", []) if typeof(actor.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	var count: int = 0
	for raw_belt in belts:
		var belt_text: String = str(raw_belt)
		if belt_text.find("WBA") >= 0 or belt_text.find("WBC") >= 0 or belt_text.find("IBF") >= 0 or belt_text.find("WBO") >= 0:
			count += 1
	return count

func _base_promotion_catalog() -> Array:
	return [
		{
			"id": "local_fight_brokers",
			"name": "Local Fight Brokers",
			"tier": "basic",
			"glow": 0.22,
			"cut_percent": 18,
			"opportunity_level": 24,
			"booking_power": 35,
			"ppv_baseline": false,
			"requirements": { "pro_only": true, "minimum_wins": 1, "minimum_win_pct": 0.0, "minimum_world_titles": 0},
			"perks": ["Can book low-level paid fights", "Small local purses", "Low media risk"]
		},
		{
			"id": "regional_ringmakers",
			"name": "Regional Ringmakers",
			"tier": "regional",
			"glow": 0.38,
			"cut_percent": 15,
			"opportunity_level": 42,
			"booking_power": 52,
			"ppv_baseline": false,
			"requirements": { "pro_only": true, "minimum_wins": 4, "minimum_win_pct": 0.55, "minimum_world_titles": 0},
			"perks": ["Regional TV slots", "Better opponent access", "More reliable fight booking"]
		},
		{
			"id": "crown_gloves_promotions",
			"name": "Crown Gloves Promotions",
			"tier": "highlevel",
			"glow": 0.58,
			"cut_percent": 12,
			"opportunity_level": 64,
			"booking_power": 70,
			"ppv_baseline": false,
			"requirements": { "pro_only": true, "minimum_wins": 8, "minimum_win_pct": 0.68, "minimum_world_titles": 0},
			"perks": ["Ranked opponent pipeline", "Bigger venues", "Media push"]
		},
		{
			"id": "primetime_boxing_group",
			"name": "PrimeTime Boxing Group",
			"tier": "elite",
			"glow": 0.78,
			"cut_percent": 8,
			"opportunity_level": 82,
			"booking_power": 88,
			"ppv_baseline": true,
			"requirements": { "pro_only": true, "minimum_wins": 12, "minimum_win_pct": 0.78, "minimum_world_titles": 1},
			"perks": ["PPV access", "Title eliminators", "International cards"]
		},
		{
			"id": "acrello_promotions",
			"name": "AcrelloPromotions",
			"tier": "god_tier",
			"glow": 1.0,
			"cut_percent": 1,
			"opportunity_level": 100,
			"booking_power": 100,
			"ppv_baseline": true,
			"requirements": { "pro_only": true, "minimum_wins": 0, "minimum_win_pct": 0.95, "minimum_world_titles": 2},
			"perks": ["Can pursue almost anyone", "Minimal revenue cut", "Bigger contracts", "PPV baseline", "Superfight leverage"]
		}
	]
func get_promotion_catalog(actor: Person = null) -> Array:
	var catalog: Array = _base_promotion_catalog()

	for i in range(catalog.size()):
		if typeof(catalog [i]) != TYPE_DICTIONARY:
			continue

		var company: Dictionary = (catalog [i] as Dictionary).duplicate(true)

		if actor == null:
			company ["eligible"] = false
			company ["locked_reason"] = "No boxer selected."
		else:
			var locked_reason: String = promotion_locked_reason(actor, company)
			company ["eligible"] = locked_reason == ""
			company ["locked_reason"] = locked_reason

		catalog [i] = company

	return catalog


func get_promotion_by_id(promotion_id: String) -> Dictionary:
	var clean_id: String = str(promotion_id).strip_edges()
	if clean_id == "":
		return {}

	for raw_company in _base_promotion_catalog():
		if typeof(raw_company) != TYPE_DICTIONARY:
			continue

		var company: Dictionary = raw_company as Dictionary
		if str(company.get("id", "")).strip_edges() == clean_id:
			return company.duplicate(true)

	return {}

func promotion_locked_reason(actor: Person, company: Dictionary) -> String:
	if actor == null:
		return "No boxer selected."

	if typeof(actor.boxing_profile) != TYPE_DICTIONARY:
		return "No boxing profile."

	var requirements: Dictionary = company.get("requirements", {}) if typeof(company.get("requirements", {})) == TYPE_DICTIONARY else {}
	var turned_pro: bool = bool(actor.boxing_profile.get("turned_pro", false))

	if bool(requirements.get("pro_only", true)) and not turned_pro:
		return "Amateurs cannot sign with promotional companies."

	var record: Dictionary = _record_for_actor(actor)
	var wins: int = int(record.get("wins", 0))
	var minimum_wins: int = int(requirements.get("minimum_wins", 0))
	if wins < minimum_wins:
		return "Requires at least %d professional wins." % minimum_wins

	var minimum_win_pct: float = float(requirements.get("minimum_win_pct", 0.0))
	var win_pct: float = _win_percentage(actor)
	if win_pct < minimum_win_pct:
		return "Requires at least %d%% win percentage." % int(round(minimum_win_pct * 100.0))

	var minimum_titles: int = int(requirements.get("minimum_world_titles", 0))
	var title_count: int = _world_title_count(actor)
	if title_count < minimum_titles:
		return "Requires at least %d world titles." % minimum_titles

	return ""


func can_sign_with_promotion(actor: Person, promotion_id: String) -> bool:
	if actor == null:
		return false

	var company: Dictionary = get_promotion_by_id(promotion_id)
	if company.is_empty():
		return false

	return promotion_locked_reason(actor, company) == ""


func sign_with_promotion(actor: Person, promotion_id: String) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "No boxer selected."}

	var company: Dictionary = get_promotion_by_id(promotion_id)
	if company.is_empty():
		return { "success": false, "text": "That promotional company does not exist."}

	var locked_reason: String = promotion_locked_reason(actor, company)
	if locked_reason != "":
		return {
			"success": false,
			"text": "\n\nI could not sign with %s. %s" % [str(company.get("name", "that promotion")), locked_reason],
			"refresh_tab": "promotions"
		}

	actor.boxing_profile ["promoter_id"] = str(company.get("id", ""))
	actor.boxing_profile ["promoter"] = str(company.get("name", "Unsigned"))
	actor.boxing_profile ["promotion_signed_year"] = int(gs.year) if gs != null else 0
	actor.boxing_profile ["promoter_cut_percent"] = int(company.get("cut_percent", 0))
	actor.boxing_profile ["promoter_booking_power"] = int(company.get("booking_power", 0))
	actor.boxing_profile ["promoter_opportunity_level"] = int(company.get("opportunity_level", 0))
	actor.boxing_profile ["promoter_ppv_baseline"] = bool(company.get("ppv_baseline", false))
	actor.boxing_profile ["promoter_trust"] = max(int(actor.boxing_profile.get("promoter_trust", 50)), 55)

	var txt: String = "\n\nI signed with %s. They now represent my professional boxing career." % str(company.get("name", "a promoter"))

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, { "type": "text", "text": txt})

	return {
		"success": true,
		"text": txt,
		"refresh_tab": "promotions",
		"promotion_id": str(company.get("id", "")),
		"promotion_name": str(company.get("name", ""))
	}
func _init(_gs):
	gs = _gs

func should_duck(challenger: Person, champion: Person) -> bool:
	if challenger == null or champion == null:
		return false

	if not bool(_boxing_policy("ducking_enabled", true)):
		return false

	var c_bp: Dictionary = champion.boxing_profile.get("boxing_personality", {}) if typeof(champion.boxing_profile.get("boxing_personality", {})) == TYPE_DICTIONARY else {}
	var risk: int = _fight_risk_score(challenger, champion)

	var duck_bias: int = int(_boxing_policy("base_duck_bias", 0))
	var low_courage_threshold: int = int(_boxing_policy("low_courage_threshold", 40))
	var low_professionalism_threshold: int = int(_boxing_policy("low_professionalism_threshold", 45))
	var risk_threshold: int = int(_boxing_policy("duck_risk_threshold", 18))

	duck_bias += int(_boxing_policy("low_courage_duck_bias", 20)) if int(c_bp.get("courage", 50)) < low_courage_threshold else 0
	duck_bias += int(_boxing_policy("low_professionalism_duck_bias", 15)) if int(c_bp.get("professionalism", 50)) < low_professionalism_threshold else 0
	duck_bias += int(_boxing_policy("injury_duck_bias", 10)) if champion.boxing_profile.get("current_injuries", []).size() > 0 else 0
	duck_bias += int(_boxing_policy("dangerous_challenger_duck_bias", 10)) if risk >= risk_threshold else 0

	var max_duck_chance: int = int(_boxing_policy("max_duck_chance", 55))
	return randi() % 100 < clamp(duck_bias, 0, max_duck_chance)
func register_duck(champion: Person, challenger: Person) -> void:
	champion.boxing_profile ["ducked_opponents"].append(challenger.id)
	challenger.boxing_profile ["ducked_by_ids"].append(champion.id)

	var txt = "👀 %s's team avoided a dangerous fight with %s." % [
		champion.first_name, challenger.first_name
	]

	gs.event_bus.emit(ActionEventTypes.BOXING_DUCKED_FIGHT, {
		"npc_id": champion.id,
		"target_id": challenger.id,
		"text": txt
	})

func _fight_risk_score(challenger: Person, champion: Person) -> int:
	var cr = challenger.boxing_profile ["ratings"]
	var hr = champion.boxing_profile ["ratings"]

	var challenger_total = int(cr ["power"]) + int(cr ["speed"]) + int(cr ["ring_iq"]) + int(cr ["chin"])
	var champ_total = int(hr ["power"]) + int(hr ["speed"]) + int(hr ["ring_iq"]) + int(hr ["chin"])

	return max(0, int((challenger_total - champ_total) / 10.0))