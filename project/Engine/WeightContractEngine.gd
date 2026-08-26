extends Resource
class_name WeightContractEngine

const CONTRACT_SCHEMA:= "eralife.weight_contract_engine"
const CONTRACT_VERSION:= 1
const PERSON_WEIGHT_SCHEMA:= "eralife.person.weight_contract"

var gs
var last_report: Dictionary = {}
var weight_event_log: Array = []

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"last_report": last_report.duplicate(true),
		"weight_event_log": weight_event_log.duplicate(true)
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "WeightContractEngine import_state expected Dictionary."}

	last_report = _safe_dictionary(data.get("last_report", {}))
	weight_event_log = _safe_array(data.get("weight_event_log", []))

	return {
		"success": true,
		"schema": CONTRACT_SCHEMA + "_state",
		"event_count": weight_event_log.size()
	}

func ensure_weight_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var height_contract: Dictionary = {}
	if gs != null and gs.height_contract_engine != null and gs.height_contract_engine.has_method("ensure_height_contract"):
		height_contract = gs.height_contract_engine.ensure_height_contract(actor, {
			"source": "weight_contract_engine"
		})
	else:
		height_contract = _safe_dictionary(actor.height_contract)

	var body_type_contract: Dictionary = {}
	if gs != null and gs.body_type_contract_engine != null and gs.body_type_contract_engine.has_method("ensure_body_type_contract"):
		body_type_contract = gs.body_type_contract_engine.ensure_body_type_contract(actor, {
			"source": "weight_contract_engine"
		})
	else:
		body_type_contract = _safe_dictionary(actor.body_type_contract)

	var growth_contract: Dictionary = {}
	if gs != null and gs.growth_curve_engine != null and gs.growth_curve_engine.has_method("ensure_growth_curve_contract"):
		growth_contract = gs.growth_curve_engine.ensure_growth_curve_contract(actor, {
			"source": "weight_contract_engine"
		})
	else:
		growth_contract = _safe_dictionary(actor.growth_curve_contract)

	var existing: Dictionary = _safe_dictionary(actor.weight_contract)
	var height_in: float = float(height_contract.get("height_in", 67.0))
	var healthy_weight: float = _healthy_weight_for_height(height_in, body_type_contract, growth_contract)

	var current_weight: float = float(existing.get("weight_lbs", 0.0))
	if current_weight <= 0.0:
		current_weight = healthy_weight + _seeded_starting_weight_offset(actor, body_type_contract)

	current_weight = clamp(current_weight, 5.0, 850.0)

	var bmi: float = _bmi(current_weight, height_in)
	var category: String = _weight_category_from_bmi(bmi)
	var contract: Dictionary = _merge_dict({
		"schema": PERSON_WEIGHT_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"weight_lbs": current_weight,
		"weight_kg": current_weight * 0.45359237,
		"healthy_weight_lbs": healthy_weight,
		"healthy_weight_kg": healthy_weight * 0.45359237,
		"walkaround_weight_lbs": current_weight,
		"bmi": bmi,
		"category": category,
		"display": "%d lb" % int(round(current_weight)),
		"display_metric": "%.1f kg" % (current_weight * 0.45359237),
		"life_stage": str(growth_contract.get("life_stage", "")),
		"body_type": str(body_type_contract.get("type", "mesomorph")),
		"trend": "stable",
		"last_delta_lbs": 0.0,
		"last_reason": str(context.get("source", "weight_contract_engine")),
		"contract_mesh": {
			"source_of_truth": "weight_contract_engine",
			"observed_by": ["relationship_profile", "food_engine", "health_engine", "sports_domains"],
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}, existing)

	contract ["weight_lbs"] = current_weight
	contract ["weight_kg"] = current_weight * 0.45359237
	contract ["healthy_weight_lbs"] = healthy_weight
	contract ["healthy_weight_kg"] = healthy_weight * 0.45359237
	contract ["walkaround_weight_lbs"] = current_weight
	contract ["bmi"] = bmi
	contract ["category"] = category
	contract ["display"] = "%d lb" % int(round(current_weight))
	contract ["display_metric"] = "%.1f kg" % (current_weight * 0.45359237)
	contract ["life_stage"] = str(growth_contract.get("life_stage", ""))
	contract ["body_type"] = str(body_type_contract.get("type", "mesomorph"))
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	actor.weight_contract = contract.duplicate(true)
	_update_actor_body_contract(actor, height_contract, body_type_contract, growth_contract, contract)

	last_report = {
		"success": true,
		"mode": "ensure_weight_contract",
		"actor_id": _actor_id(actor),
		"weight_lbs": current_weight,
		"category": category
	}

	return contract.duplicate(true)

func yearly_tick_person(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var contract: Dictionary = ensure_weight_contract(actor, context)
	if not bool(actor.alive):
		return contract

	var body_type_contract: Dictionary = _safe_dictionary(actor.body_type_contract)
	var traits: Dictionary = _safe_dictionary(body_type_contract.get("traits", {}))
	var healthy_weight: float = float(contract.get("healthy_weight_lbs", contract.get("weight_lbs", 150.0)))
	var current_weight: float = float(contract.get("weight_lbs", healthy_weight))
	var drift_rate: float = clamp(float(traits.get("weight_drift_to_setpoint", 0.15)), 0.02, 0.3)
	var metabolism: float = clamp(float(traits.get("metabolism_multiplier", 1.0)), 0.7, 1.35)

	var hunger_value: float = float(actor.hunger) if "hunger" in actor else -1.0
	var hunger_pressure: float = 0.0
	if hunger_value >= 0.0:
		if hunger_value <= 18.0:
			hunger_pressure = -2.2
		elif hunger_value >= 92.0:
			hunger_pressure = 1.1

	var age_pressure: float = 0.0
	if int(actor.age) >= 30:
		age_pressure += 0.18
	if int(actor.age) >= 45:
		age_pressure += 0.24
	if int(actor.age) >= 65:
		age_pressure -= 0.35

	var setpoint_pull: float = (healthy_weight - current_weight) * drift_rate * metabolism
	var delta: float = clamp(setpoint_pull + hunger_pressure + age_pressure, -8.0, 8.0)

	return apply_weight_delta(actor, delta, {
		"source": str(context.get("source", "weight_contract_yearly_tick")),
		"reason": "yearly_body_drift",
		"healthy_weight_lbs": healthy_weight
	})

func apply_food_intake(actor: Person, food_item: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	if typeof(food_item) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Food item must be Dictionary."}

	var contract: Dictionary = ensure_weight_contract(actor, {
		"source": "food_intake_precheck"
	})

	var body_type_contract: Dictionary = _safe_dictionary(actor.body_type_contract)
	var traits: Dictionary = _safe_dictionary(body_type_contract.get("traits", {}))
	var fat_gain_multiplier: float = clamp(float(traits.get("fat_gain_multiplier", 1.0)), 0.55, 1.6)

	var hunger_before: float = float(context.get("hunger_before", 50.0))
	var hunger_after: float = float(context.get("hunger_after", hunger_before))
	var hunger_delta: float = float(context.get("hunger_delta", hunger_after - hunger_before))

	var fullness_pressure: float = max(0.0, hunger_after - 82.0) / 18.0
	var overeating_pressure: float = max(0.0, hunger_delta - 26.0) / 38.0
	var sugar_pressure: float = clamp(float(food_item.get("sugar", 0.0)) / 100.0, 0.0, 1.0)
	var sodium_pressure: float = clamp(float(food_item.get("sodium", 0.0)) / 140.0, 0.0, 1.0)
	var protein_value: float = clamp(float(food_item.get("protein", 0.0)) / 100.0, 0.0, 1.0)
	var nutrition_value: float = clamp(float(food_item.get("nutrition", 45.0)) / 100.0, 0.0, 1.0)

	var delta: float = 0.0
	if fullness_pressure > 0.0 or overeating_pressure > 0.0:
		delta += 0.05
		delta += fullness_pressure * 0.22
		delta += overeating_pressure * 0.18
		delta += sugar_pressure * 0.16
		delta += sodium_pressure * 0.04
		delta *= fat_gain_multiplier

	if protein_value >= 0.35 and nutrition_value >= 0.55 and hunger_after < 92.0:
		delta += 0.03

	delta = clamp(delta, 0.0, 2.4)

	if delta <= 0.0:
		return {
			"success": true,
			"changed": false,
			"actor_id": _actor_id(actor),
			"weight_lbs": float(contract.get("weight_lbs", 0.0)),
			"text": "Weight unchanged."
		}

	return apply_weight_delta(actor, delta, {
		"source": str(context.get("source", "food_intake")),
		"reason": "food_consumed",
		"food_id": str(food_item.get("id", food_item.get("food_id", ""))),
		"food_name": str(food_item.get("name", food_item.get("id", "food"))),
		"hunger_before": hunger_before,
		"hunger_after": hunger_after,
		"hunger_delta": hunger_delta
	})

func apply_weight_delta(actor: Person, delta_lbs: float, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var contract: Dictionary = ensure_weight_contract(actor, {
		"source": "weight_delta_precheck"
	})

	var before_weight: float = float(contract.get("weight_lbs", 150.0))
	var after_weight: float = clamp(before_weight + float(delta_lbs), 5.0, 850.0)
	var height_in: float = float(_safe_dictionary(actor.height_contract).get("height_in", 67.0))
	var bmi: float = _bmi(after_weight, height_in)
	var category: String = _weight_category_from_bmi(bmi)

	contract ["weight_lbs"] = after_weight
	contract ["weight_kg"] = after_weight * 0.45359237
	contract ["walkaround_weight_lbs"] = after_weight
	contract ["bmi"] = bmi
	contract ["category"] = category
	contract ["display"] = "%d lb" % int(round(after_weight))
	contract ["display_metric"] = "%.1f kg" % (after_weight * 0.45359237)
	contract ["last_delta_lbs"] = after_weight - before_weight
	contract ["last_reason"] = str(context.get("reason", context.get("source", "weight_delta")))
	contract ["trend"] = "gaining" if after_weight > before_weight else ("losing" if after_weight < before_weight else "stable")
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	actor.weight_contract = contract.duplicate(true)

	var height_contract: Dictionary = _safe_dictionary(actor.height_contract)
	var body_type_contract: Dictionary = _safe_dictionary(actor.body_type_contract)
	var growth_contract: Dictionary = _safe_dictionary(actor.growth_curve_contract)
	_update_actor_body_contract(actor, height_contract, body_type_contract, growth_contract, contract)

	var event: Dictionary = {
		"schema": "eralife.weight_event",
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"before_weight_lbs": before_weight,
		"after_weight_lbs": after_weight,
		"delta_lbs": after_weight - before_weight,
		"reason": str(context.get("reason", context.get("source", "weight_delta"))),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	weight_event_log.append(event)
	if weight_event_log.size() > 160:
		weight_event_log = weight_event_log.slice(weight_event_log.size() - 160, weight_event_log.size())

	last_report = event.duplicate(true)

	return {
		"success": true,
		"changed": abs(after_weight - before_weight) > 0.001,
		"actor_id": _actor_id(actor),
		"before_weight_lbs": before_weight,
		"after_weight_lbs": after_weight,
		"delta_lbs": after_weight - before_weight,
		"weight_lbs": after_weight,
		"display": str(contract.get("display", "")),
		"category": category,
		"contract": contract.duplicate(true),
		"event": event.duplicate(true)
	}

func observe_body_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var weight_contract: Dictionary = ensure_weight_contract(actor, context)
	return _safe_dictionary(actor.body_contract).merged({
		"weight_contract": weight_contract.duplicate(true)
	}, true)

func assess_target_weight(actor: Person, target_limit_lbs: float, target_label: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var weight_contract: Dictionary = ensure_weight_contract(actor, {
		"source": "assess_target_weight",
		"target_label": target_label
	})

	var current_weight: float = float(weight_contract.get("weight_lbs", weight_contract.get("walkaround_weight_lbs", 150.0)))
	var limit: float = max(1.0, float(target_limit_lbs))
	var grace_lbs: float = clamp(float(context.get("grace_lbs", 8.0)), 0.0, 35.0)
	var cut_needed: float = max(0.0, current_weight - limit)
	var can_attempt: bool = cut_needed <= grace_lbs
	var status: String = "in_range"

	if cut_needed > grace_lbs:
		status = "too_heavy"
	elif cut_needed > 0.0:
		status = "cut_required"

	var label: String = str(target_label).strip_edges()
	if label == "":
		label = "%d lb target" % int(round(limit))

	var feedback: String = "You can make %s." % label
	if status == "cut_required":
		feedback = "You are %.1f lb over %s. You can attempt the cut, but making weight is not guaranteed." % [cut_needed, label]
	elif status == "too_heavy":
		feedback = "You are too heavy for %s. Current: %d lb. Limit: %d lb. Drop about %d lb first." % [
			label,
			int(round(current_weight)),
			int(round(limit)),
			int(ceil(cut_needed - grace_lbs))
		]

	return {
		"success": true,
		"actor_id": _actor_id(actor),
		"target_label": label,
		"target_limit_lbs": limit,
		"current_weight_lbs": current_weight,
		"grace_lbs": grace_lbs,
		"cut_needed_lbs": cut_needed,
		"can_attempt": can_attempt,
		"status": status,
		"feedback_text": feedback,
		"weight_contract": weight_contract.duplicate(true)
	}

func _update_actor_body_contract(actor: Person, height_contract: Dictionary, body_type_contract: Dictionary, growth_contract: Dictionary, weight_contract: Dictionary) -> void:
	if actor == null:
		return

	actor.body_contract = {
		"schema": "eralife.person.body_contract",
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"height": height_contract.duplicate(true),
		"weight": weight_contract.duplicate(true),
		"body_type": body_type_contract.duplicate(true),
		"growth_curve": growth_contract.duplicate(true),
		"summary": {
			"height": str(height_contract.get("display", "")),
			"weight": str(weight_contract.get("display", "")),
			"body_type": str(body_type_contract.get("display_name", "")),
			"life_stage": str(growth_contract.get("life_stage", "")),
			"weight_category": str(weight_contract.get("category", ""))
		},
		"contract_mesh": {
			"source_of_truth": "body_contract_bundle",
			"composed_from": ["height_contract", "weight_contract", "body_type_contract", "growth_curve_contract", "genetics_contract"],
		},
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func _healthy_weight_for_height(height_in: float, body_type_contract: Dictionary, growth_contract: Dictionary) -> float:
	var height_m: float = max(0.3, height_in * 0.0254)
	var adult_healthy: float = 22.0 * height_m * height_m * 2.20462

	var traits: Dictionary = _safe_dictionary(body_type_contract.get("traits", {}))
	var frame_multiplier: float = clamp(float(traits.get("natural_frame_multiplier", 1.0)), 0.72, 1.35)
	var growth_factor: float = clamp(float(growth_contract.get("weight_growth_factor", 1.0)), 0.1, 1.08)

	return clamp(adult_healthy * frame_multiplier * growth_factor, 5.0, 650.0)

func _seeded_starting_weight_offset(actor: Person, body_type_contract: Dictionary) -> float:
	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(hash("starting_weight|%d|%s" % [_actor_id(actor), str(actor.age if actor != null else 0)])) % 2147483647

	var body_type: String = str(body_type_contract.get("type", "mesomorph")).strip_edges().to_lower()
	var center: float = 0.0
	match body_type:
		"ectomorph":
			center = -5.0
		"endomorph":
			center = 7.0
		_:
			center = 1.5

	return rng.randfn(center, 4.0)

func _bmi(weight_lbs: float, height_in: float) -> float:
	var safe_height: float = max(12.0, height_in)
	return (weight_lbs / (safe_height * safe_height)) * 703.0

func _weight_category_from_bmi(bmi: float) -> String:
	if bmi < 18.5:
		return "lean"
	if bmi < 25.0:
		return "average"
	if bmi < 30.0:
		return "overweight"
	return "obese"

func _actor_id(actor: Person) -> int:
	if actor == null:
		return -1
	if "id" in actor:
		return int(actor.id)
	return -1

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		if typeof(out.get(key, null)) == TYPE_DICTIONARY and typeof(patch.get(key, null)) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out [key], patch [key])
		else:
			out [key] = patch [key]
	return out
func on_npc_born(payload:= {}) -> void:
	_queue_body_contract_refresh_from_payload(payload, "npc_born")


func yearly_tick(payload:= {}) -> void:
	if gs == null:
		return
	if gs.has_method("queue_body_contract_yearly_tick_from_event"):
		gs.queue_body_contract_yearly_tick_from_event(payload if typeof(payload) == TYPE_DICTIONARY else {}, {
			"source": "%s.yearly_tick" % str(CONTRACT_SCHEMA)
		})


func _queue_body_contract_refresh_from_payload(payload:= {}, reason: String = "body_contract_event") -> void:
	if gs == null:
		return
	if not gs.has_method("queue_body_contract_refresh_from_event"):
		return

	var safe_payload: Dictionary = payload if typeof(payload) == TYPE_DICTIONARY else {}
	gs.queue_body_contract_refresh_from_event(safe_payload, {
		"source": "%s.%s" % [str(CONTRACT_SCHEMA), reason],
		"requested_by": str(CONTRACT_SCHEMA)
	})