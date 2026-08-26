extends Resource
class_name GrowthCurveEngine

const CONTRACT_SCHEMA:= "eralife.growth_curve_engine"
const CONTRACT_VERSION:= 1
const PERSON_GROWTH_SCHEMA:= "eralife.person.growth_curve_contract"

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"last_report": last_report.duplicate(true)
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "GrowthCurveEngine import_state expected Dictionary."}
	last_report = _safe_dictionary(data.get("last_report", {}))
	return { "success": true, "schema": CONTRACT_SCHEMA + "_state"}

func ensure_growth_curve_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var existing: Dictionary = _safe_dictionary(actor.growth_curve_contract)
	if not existing.is_empty() and bool(existing.get("sealed", false)):
		return _refresh_growth_snapshot(actor, existing, context)

	var genetics: Dictionary = {}
	if gs != null and gs.genetics_inheritance_engine != null and gs.genetics_inheritance_engine.has_method("ensure_genetics_contract"):
		genetics = gs.genetics_inheritance_engine.ensure_genetics_contract(actor, {
			"source": "growth_curve_engine",
			"requested_by": str(context.get("source", "unknown"))
		})
	else:
		genetics = _safe_dictionary(actor.genetics_contract)

	var variant: String = str(genetics.get("growth_timing_gene", "average")).strip_edges().to_lower()
	if variant not in ["early", "average", "late"]:
		variant = "average"

	var maturity_age: int = 18
	match variant:
		"early":
			maturity_age = 16
		"late":
			maturity_age = 21
		_:
			maturity_age = 18

	var contract: Dictionary = _merge_dict({
		"schema": PERSON_GROWTH_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"sealed": true,
		"variant": variant,
		"maturity_age": maturity_age,
		"life_stage": life_stage_for_age(int(actor.age)),
		"height_growth_factor": current_height_growth_factor(actor, maturity_age),
		"weight_growth_factor": current_weight_growth_factor(actor, maturity_age),
		"elder_compression_factor": elder_height_compression_factor(int(actor.age)),
		"source": str(context.get("source", "growth_curve_engine")),
		"contract_mesh": {
			"source_of_truth": "growth_curve_engine",
			"observed_by": ["height_contract_engine", "weight_contract_engine", "school", "relationships", "sports_domains"],
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}, existing)

	actor.growth_curve_contract = contract.duplicate(true)

	last_report = {
		"success": true,
		"mode": "ensure_growth_curve_contract",
		"actor_id": _actor_id(actor),
		"variant": variant,
		"life_stage": str(contract.get("life_stage", ""))
	}

	return contract.duplicate(true)

func yearly_tick_person(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var contract: Dictionary = ensure_growth_curve_contract(actor, context)
	return _refresh_growth_snapshot(actor, contract, {
		"source": str(context.get("source", "growth_curve_yearly_tick"))
	})

func _refresh_growth_snapshot(actor: Person, contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	var maturity_age: int = int(contract.get("maturity_age", 18))
	contract ["life_stage"] = life_stage_for_age(int(actor.age))
	contract ["height_growth_factor"] = current_height_growth_factor(actor, maturity_age)
	contract ["weight_growth_factor"] = current_weight_growth_factor(actor, maturity_age)
	contract ["elder_compression_factor"] = elder_height_compression_factor(int(actor.age))
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contract ["last_context"] = context.duplicate(true)

	actor.growth_curve_contract = contract.duplicate(true)
	return contract.duplicate(true)

func current_height_growth_factor(actor: Person, maturity_age: int = 18) -> float:
	if actor == null:
		return 1.0

	var age: float = max(0.0, float(actor.age))
	var adult_age: float = max(13.0, float(maturity_age))

	if age <= 0.0:
		return 0.305
	if age < 2.0:
		return lerp(0.305, 0.485, age / 2.0)
	if age < 6.0:
		return lerp(0.485, 0.655, (age - 2.0) / 4.0)
	if age < 12.0:
		return lerp(0.655, 0.815, (age - 6.0) / 6.0)
	if age < adult_age:
		return lerp(0.815, 1.0, (age - 12.0) / max(1.0, adult_age - 12.0))

	return elder_height_compression_factor(int(age))

func current_weight_growth_factor(actor: Person, maturity_age: int = 18) -> float:
	var height_factor: float = current_height_growth_factor(actor, maturity_age)
	return clamp(pow(height_factor, 2.18), 0.1, 1.05)

func elder_height_compression_factor(age: int) -> float:
	if age < 65:
		return 1.0
	return clamp(1.0 - (float(age - 65) * 0.0012), 0.955, 1.0)

func life_stage_for_age(age: int) -> String:
	if age <= 1:
		return "baby"
	if age <= 5:
		return "child"
	if age <= 12:
		return "preteen"
	if age <= 17:
		return "teen"
	if age <= 25:
		return "young_adult"
	if age <= 59:
		return "adult"
	if age <= 79:
		return "elder"
	return "elderly"

func _actor_id(actor: Person) -> int:
	if actor == null:
		return -1
	if "id" in actor:
		return int(actor.id)
	return -1

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

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