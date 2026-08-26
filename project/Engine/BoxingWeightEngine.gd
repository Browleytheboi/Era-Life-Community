extends Resource
class_name BoxingWeightEngine

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
var DIVISION_LIMITS = {
	"Flyweight": 112,
	"Bantamweight": 118,
	"Featherweight": 126,
	"Lightweight": 135,
	"Welterweight": 147,
	"Middleweight": 160,
	"Light Heavyweight": 175,
	"Heavyweight": 999
}

const DIVISION_ORDER:= [
	"Flyweight",
	"Bantamweight",
	"Featherweight",
	"Lightweight",
	"Welterweight",
	"Middleweight",
	"Light Heavyweight",
	"Heavyweight"
]
func evaluate_division_eligibility(npc: Person, target_division: String, context: Dictionary = {}) -> Dictionary:
	if npc == null:
		return {
			"success": false,
			"selectable": false,
			"reason": "No fighter selected.",
			"status_text": "No fighter selected."
		}

	var clean_division: String = str(target_division).strip_edges()
	if clean_division == "":
		return {
			"success": false,
			"selectable": false,
			"reason": "No division selected.",
			"status_text": "No division selected."
		}

	var limits: Dictionary = _boxing_dictionary_policy("division_limits", DIVISION_LIMITS)
	if not limits.has(clean_division):
		return {
			"success": false,
			"selectable": false,
			"reason": "Unknown division.",
			"status_text": "Unknown division."
		}

	var limit: float = float(limits.get(clean_division, 999.0))
	var lower_bound: float = _division_lower_bound(clean_division)
	var grace_lbs: float = float(context.get("grace_lbs", _boxing_policy("division_selection_grace_lbs", 8.0)))
	var fight_up_grace_lbs: float = float(context.get("fight_up_grace_lbs", _boxing_policy("division_fight_up_grace_lbs", 12.0)))

	var weight_contract: Dictionary = {}
	if gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("ensure_weight_contract"):
		weight_contract = gs.weight_contract_engine.ensure_weight_contract(npc, {
			"source": "boxing_weight_engine.evaluate_division_eligibility",
			"division": clean_division
		})
	elif typeof(npc.weight_contract) == TYPE_DICTIONARY:
		weight_contract = npc.weight_contract.duplicate(true)

	var current_weight: float = float(weight_contract.get("weight_lbs", weight_contract.get("walkaround_weight_lbs", limit)))
	var cut_needed: float = max(0.0, current_weight - limit)

	var too_heavy: bool = cut_needed > grace_lbs
	var too_light: bool = false
	if clean_division == "Heavyweight":
		too_light = current_weight < (176.0 - fight_up_grace_lbs)
	elif lower_bound > 0.0:
		too_light = current_weight < (lower_bound - fight_up_grace_lbs)

	var selectable: bool = not too_heavy and not too_light
	var status: String = "ready"
	var status_text: String = "Natural fit."

	if too_heavy:
		status = "too_heavy"
		status_text = "Too heavy. Current: %d lb. %s limit: %d lb. Lose about %d lb first." % [
			int(round(current_weight)),
			clean_division,
			int(round(limit)),
			int(ceil(cut_needed - grace_lbs))
		]
	elif too_light:
		status = "too_light"
		status_text = "Too light for %s right now. Current: %d lb. Build closer to the division first." % [
			clean_division,
			int(round(current_weight))
		]
	elif cut_needed > 0.0:
		status = "cut_required"
		status_text = "Cut required: %.1f lb over the %s limit. You can try, but the scale matters." % [
			cut_needed,
			clean_division
		]

	var generic_assessment: Dictionary = {}
	if gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("assess_target_weight"):
		generic_assessment = gs.weight_contract_engine.assess_target_weight(npc, limit, clean_division, {
			"source": "boxing_weight_engine",
			"grace_lbs": grace_lbs
		})

	return {
		"success": true,
		"selectable": selectable,
		"division": clean_division,
		"status": status,
		"status_text": status_text,
		"current_weight_lbs": current_weight,
		"division_limit_lbs": limit,
		"division_lower_bound_lbs": lower_bound,
		"grace_lbs": grace_lbs,
		"fight_up_grace_lbs": fight_up_grace_lbs,
		"cut_needed_lbs": cut_needed,
		"weight_contract": weight_contract.duplicate(true),
		"generic_weight_assessment": generic_assessment.duplicate(true)
	}

func _division_lower_bound(division: String) -> float:
	var clean_division: String = str(division).strip_edges()
	var idx: int = DIVISION_ORDER.find(clean_division)
	if idx <= 0:
		return 0.0

	var previous_division: String = str(DIVISION_ORDER [idx - 1])
	var limits: Dictionary = _boxing_dictionary_policy("division_limits", DIVISION_LIMITS)
	return float(limits.get(previous_division, 0.0)) + 0.1

func _current_body_weight_lbs(npc: Person, fallback: float = 150.0) -> float:
	if npc == null:
		return fallback

	if gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("ensure_weight_contract"):
		var weight_contract: Dictionary = gs.weight_contract_engine.ensure_weight_contract(npc, {
			"source": "boxing_weight_engine.current_body_weight"
		})
		return float(weight_contract.get("weight_lbs", weight_contract.get("walkaround_weight_lbs", fallback)))

	if typeof(npc.weight_contract) == TYPE_DICTIONARY:
		return float(npc.weight_contract.get("weight_lbs", npc.weight_contract.get("walkaround_weight_lbs", fallback)))

	return fallback
func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}) -> void:
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		_drift_walkaround_weight(npc)
		_maybe_change_division(npc)

func on_fight_completed(payload: Dictionary) -> void:
	var winner = gs.get_npc_by_id(int(payload.get("winner_id", -1)))
	var loser = gs.get_npc_by_id(int(payload.get("loser_id", -1)))
	if winner != null:
		_apply_post_fight_weight_drift(winner)
	if loser != null:
		_apply_post_fight_weight_drift(loser)

func try_make_weight(npc: Person) -> bool:
	if npc == null:
		return false

	var division: String = str(npc.boxing_profile.get("weight_class", "")).strip_edges()
	var eligibility: Dictionary = evaluate_division_eligibility(npc, division, {
		"source": "try_make_weight",
		"grace_lbs": float(_boxing_policy("scale_grace_lbs", 8.0))
	})

	var wm: Dictionary = npc.boxing_profile.get("weight_management", {}) if typeof(npc.boxing_profile.get("weight_management", {})) == TYPE_DICTIONARY else {}
	var current_weight: float = float(eligibility.get("current_weight_lbs", wm.get("walkaround_weight", 150.0)))
	var limit: float = float(eligibility.get("division_limit_lbs", 999.0))
	var cut_needed: float = max(0.0, current_weight - limit)

	wm ["walkaround_weight"] = int(round(current_weight))
	wm ["weight_cut_difficulty"] = int(clamp(cut_needed * 2.0, 0.0, 35.0))
	wm ["last_scale_status"] = str(eligibility.get("status", "ready"))
	wm ["last_scale_feedback"] = str(eligibility.get("status_text", ""))
	npc.boxing_profile ["weight_management"] = wm

	if not bool(eligibility.get("selectable", true)):
		wm ["last_weight_miss_year"] = gs.year if gs != null else 0
		npc.boxing_profile ["weight_management"] = wm

		var hard_txt: String = "   %s could not make %s. %s" % [
			str(npc.first_name),
			division,
			str(eligibility.get("status_text", "They were not close enough to the division."))
		]

		if gs != null and gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_WEIGHT_MISSED, {
				"npc_id": npc.id,
				"text": hard_txt,
				"division": division,
				"limit": int(round(limit)),
				"walkaround_weight": int(round(current_weight)),
				"contract_source": "boxing_weight_engine",
				"body_source_of_truth": "weight_contract_engine"
			})

		return false

	var difficulty: int = int(wm.get("weight_cut_difficulty", 0))
	var cut_multiplier: int = int(_boxing_policy("weight_cut_fail_multiplier", 3))
	var fail_cap: int = int(_boxing_policy("weight_cut_fail_cap", 60))
	var fail_chance: int = clamp(int(round(cut_needed)) * cut_multiplier + difficulty, 0, fail_cap)

	if randi() % 100 < fail_chance:
		wm ["last_weight_miss_year"] = gs.year if gs != null else 0
		npc.boxing_profile ["weight_management"] = wm

		var txt: String = "   %s missed weight at the scales." % npc.first_name
		if gs != null and gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_WEIGHT_MISSED, {
				"npc_id": npc.id,
				"text": txt,
				"division": division,
				"limit": int(round(limit)),
				"walkaround_weight": int(round(current_weight)),
				"contract_source": "boxing_weight_engine",
				"body_source_of_truth": "weight_contract_engine"
			})

		return false

	return true
func get_next_division(current_division: String) -> String:
	var idx:= DIVISION_ORDER.find(current_division)
	if idx == -1:
		return "Welterweight"
	return DIVISION_ORDER [(idx + 1) % DIVISION_ORDER.size()]

func get_previous_division(current_division: String) -> String:
	var idx:= DIVISION_ORDER.find(current_division)
	if idx == -1:
		return "Lightweight"
	return DIVISION_ORDER [(idx - 1 + DIVISION_ORDER.size()) % DIVISION_ORDER.size()]

func can_change_division(npc: Person, target_division: String) -> bool:
	if npc == null or not npc.alive:
		return false
	if not npc.boxing_profile.get("is_boxer", false):
		return false
	if target_division == "":
		return false
	if not DIVISION_LIMITS.has(target_division):
		return false
	if str(npc.boxing_profile.get("weight_class", "")) == target_division:
		return false

	var eligibility: Dictionary = evaluate_division_eligibility(npc, target_division, {
		"source": "can_change_division"
	})

	return bool(eligibility.get("selectable", false))
func change_division(npc: Person, target_division: String, reason:= "manual") -> Dictionary:
	if not can_change_division(npc, target_division):
		return {
			"success": false,
			"text": "❌ Weight class change is not available right now."
		}

	var current_division = str(npc.boxing_profile.get("weight_class", ""))
	npc.boxing_profile ["weight_class"] = target_division

	var wm = npc.boxing_profile.get("weight_management", {})
	var hist = wm.get("division_history", [])
	hist.append({
		"year": gs.year,
		"from": current_division,
		"division": target_division,
		"reason": reason
	})
	wm ["division_history"] = hist
	npc.boxing_profile ["weight_management"] = wm

	var txt = "⚖️ %s changed weight classes from %s to %s." % [
		npc.first_name,
		current_division,
		target_division
	]

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_CHANGED_DIVISION, {
			"npc_id": npc.id,
			"text": txt,
			"division": target_division
		})

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(npc, { "type": "text", "text": txt})

	return {
		"success": true,
		"text": txt,
		"old_division": current_division,
		"new_division": target_division
	}

func _drift_walkaround_weight(npc: Person) -> void:
	if npc == null:
		return

	var wm: Dictionary = npc.boxing_profile ["weight_management"] if typeof(npc.boxing_profile.get("weight_management", {})) == TYPE_DICTIONARY else {}

	var weight_contract: Dictionary = {}
	if gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("yearly_tick_person"):
		weight_contract = gs.weight_contract_engine.yearly_tick_person(npc, {
			"source": "boxing_weight_engine_yearly_observer"
		})
	elif gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("ensure_weight_contract"):
		weight_contract = gs.weight_contract_engine.ensure_weight_contract(npc, {
			"source": "boxing_weight_engine_yearly_observer"
		})
	elif typeof(npc.weight_contract) == TYPE_DICTIONARY:
		weight_contract = npc.weight_contract.duplicate(true)

	var walkaround: int = int(round(float(weight_contract.get("weight_lbs", wm.get("walkaround_weight", npc.boxing_profile.get("natural_weight", 150))))))

	wm ["walkaround_weight"] = max(5, walkaround)
	wm ["weight_cut_difficulty"] = clamp(
		abs(int(wm ["walkaround_weight"]) - int(DIVISION_LIMITS.get(npc.boxing_profile.get("weight_class", ""), 147))),
		0,
		35
	)
	wm ["body_source_of_truth"] = "weight_contract_engine"
	npc.boxing_profile ["weight_management"] = wm
func _apply_post_fight_weight_drift(npc: Person) -> void:
	var wm = npc.boxing_profile ["weight_management"]
	wm ["walkaround_weight"] = int(wm.get("walkaround_weight", npc.boxing_profile.get("natural_weight", 150))) + randi_range(-1, 3)
	npc.boxing_profile ["weight_management"] = wm

func _maybe_change_division(npc: Person) -> void:
	var minimum_age: int = int(_boxing_policy("auto_division_change_min_age", 20))
	if npc.age < minimum_age:
		return

	if not bool(_boxing_policy("auto_division_change_enabled", true)):
		return

	var chance: int = int(_boxing_policy("auto_division_change_chance", 12))
	if randi() % 100 >= chance:
		return

	var wm: Dictionary = npc.boxing_profile.get("weight_management", {}) if typeof(npc.boxing_profile.get("weight_management", {})) == TYPE_DICTIONARY else {}
	var walk: int = int(wm.get("walkaround_weight", npc.boxing_profile.get("natural_weight", 150)))
	var current: String = str(npc.boxing_profile.get("weight_class", ""))
	var new_division: String = _best_division_for_weight(walk)

	if new_division == "" or new_division == current:
		return

	change_division(npc, new_division, "walkaround_weight")

func _best_division_for_weight(weight: int) -> String:
	for division in DIVISION_ORDER:
		if weight <= int(DIVISION_LIMITS [division]):
			return division
	return "Heavyweight"