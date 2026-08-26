extends Resource
class_name BoxingMandatoryEngine

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
var mandatories:= {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}) -> void:
	_enforce_expired_mandatories()

	for division in gs.boxing_ranking_engine.rankings.keys():
		_assign_mandatory_if_needed(division)
func _enforce_expired_mandatories() -> void:
	if gs == null or gs.boxing_title_engine == null:
		return

	for key in mandatories.keys():
		var data: Dictionary = mandatories.get(key, {}) if typeof(mandatories.get(key, {})) == TYPE_DICTIONARY else {}
		if data.is_empty():
			continue

		var deadline_year: int = int(data.get("deadline_year", gs.year + 1))
		if int(gs.year) <= deadline_year:
			continue

		var champion_id: int = int(data.get("champion_id", -1))
		var challenger_id: int = int(data.get("challenger_id", -1))
		var division: String = str(data.get("division", ""))
		var belt: String = str(data.get("belt", ""))

		var champion = gs.get_npc_by_id(champion_id)
		if champion != null and gs.boxing_title_engine.has_method("strip_title_for_missed_mandatory"):
			gs.boxing_title_engine.strip_title_for_missed_mandatory(champion, division, belt, "missed_mandatory")

		var challenger = gs.get_npc_by_id(challenger_id)
		if challenger != null:
			challenger.boxing_profile ["mandatory_status"] = {}

		mandatories.erase(key)

func on_fight_completed(payload: Dictionary) -> void:
	var winner_id = int(payload.get("winner_id", -1))
	var loser_id = int(payload.get("loser_id", -1))

	for key in mandatories.keys():
		var m = mandatories [key]
		if int(m.get("challenger_id", -1)) in [winner_id, loser_id]:
			mandatories.erase(key)

func _assign_mandatory_if_needed(division: String) -> void:
	if gs == null or gs.boxing_title_engine == null or gs.boxing_ranking_engine == null:
		return

	if not gs.boxing_title_engine.champions.has(division):
		return

	var mandatory_bodies: Array = ["WBA", "WBC", "IBF", "WBO"]
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_title_bodies"):
		mandatory_bodies = gs.boxing_contract_engine.get_title_bodies()

	var deadline_years: int = int(_boxing_policy("mandatory_deadline_years", 1))
	var enforcement_policy: String = str(_boxing_policy("mandatory_enforcement_policy", "strip_if_missed"))

	for belt in mandatory_bodies:
		var clean_belt: String = str(belt)
		if clean_belt == "Ring Magazine":
			continue

		var champ_id: int = int(gs.boxing_title_engine.champions [division].get(clean_belt, -1))
		if champ_id == -1:
			continue

		var key: String = "%s_%s" % [division, clean_belt]
		if mandatories.has(key):
			continue

		var rankings: Array = gs.boxing_ranking_engine.rankings.get(division, []) if typeof(gs.boxing_ranking_engine.rankings.get(division, [])) == TYPE_ARRAY else []
		if rankings.size() < 2:
			continue

		var challenger_id: int = int(rankings [0])
		if challenger_id == champ_id and rankings.size() > 1:
			challenger_id = int(rankings [1])

		if challenger_id == champ_id:
			continue

		mandatories [key] = {
			"division": division,
			"belt": clean_belt,
			"champion_id": champ_id,
			"challenger_id": challenger_id,
			"deadline_year": int(gs.year) + deadline_years,
			"enforcement_policy": enforcement_policy,
		}

		var challenger = gs.get_npc_by_id(challenger_id)
		if challenger != null:
			challenger.boxing_profile ["mandatory_status"] = {
				"is_mandatory": true,
				"belt": clean_belt,
				"division": division,
				"deadline_year": int(gs.year) + deadline_years
			}

		var champ = gs.get_npc_by_id(champ_id)
		if champ != null:
			var txt: String = "\n\n📣 %s has been ordered to defend the %s %s title against the mandatory challenger." % [
				champ.first_name,
				clean_belt,
				division
			]
			if gs.event_bus != null:
				gs.event_bus.emit(ActionEventTypes.BOXING_MANDATORY_ORDERED, {
					"npc_id": champ.id,
					"target_id": challenger_id,
					"text": txt,
					"contract_source": "boxing_mandatory_engine"
				})