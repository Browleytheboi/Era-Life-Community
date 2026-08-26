extends Resource
class_name HeightContractEngine

const CONTRACT_SCHEMA:= "eralife.height_contract_engine"
const CONTRACT_VERSION:= 1
const PERSON_HEIGHT_SCHEMA:= "eralife.person.height_contract"

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
		return { "success": false, "reason": "HeightContractEngine import_state expected Dictionary."}
	last_report = _safe_dictionary(data.get("last_report", {}))
	return { "success": true, "schema": CONTRACT_SCHEMA + "_state"}

func ensure_height_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var genetics: Dictionary = {}
	if gs != null and gs.genetics_inheritance_engine != null and gs.genetics_inheritance_engine.has_method("ensure_genetics_contract"):
		genetics = gs.genetics_inheritance_engine.ensure_genetics_contract(actor, {
			"source": "height_contract_engine",
			"requested_by": str(context.get("source", "unknown"))
		})
	else:
		genetics = _safe_dictionary(actor.genetics_contract)

	var growth: Dictionary = {}
	if gs != null and gs.growth_curve_engine != null and gs.growth_curve_engine.has_method("ensure_growth_curve_contract"):
		growth = gs.growth_curve_engine.ensure_growth_curve_contract(actor, {
			"source": "height_contract_engine"
		})
	else:
		growth = _safe_dictionary(actor.growth_curve_contract)

	var target_adult_height: float = float(genetics.get("target_adult_height_in", _fallback_adult_height(actor)))
	var growth_factor: float = clamp(float(growth.get("height_growth_factor", 1.0)), 0.25, 1.05)
	var height_in: float = clamp(target_adult_height * growth_factor, 16.0, 90.0)
	var height_cm: float = height_in * 2.54

	var existing: Dictionary = _safe_dictionary(actor.height_contract)
	var contract: Dictionary = _merge_dict({
		"schema": PERSON_HEIGHT_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"height_in": height_in,
		"height_cm": height_cm,
		"target_adult_height_in": target_adult_height,
		"target_adult_height_cm": target_adult_height * 2.54,
		"display": format_height_inches(height_in),
		"display_metric": "%.1f cm" % height_cm,
		"life_stage": str(growth.get("life_stage", "")),
		"growth_factor": growth_factor,
		"source": str(context.get("source", "height_contract_engine")),
		"contract_mesh": {
			"source_of_truth": "height_contract_engine",
			"observed_by": ["weight_contract_engine", "relationship_profile", "sports_domains"],
		},
		"updated_at_ms": int(Time.get_ticks_msec())
	}, existing)

	contract ["height_in"] = height_in
	contract ["height_cm"] = height_cm
	contract ["display"] = format_height_inches(height_in)
	contract ["display_metric"] = "%.1f cm" % height_cm
	contract ["target_adult_height_in"] = target_adult_height
	contract ["target_adult_height_cm"] = target_adult_height * 2.54
	contract ["life_stage"] = str(growth.get("life_stage", ""))
	contract ["growth_factor"] = growth_factor
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	actor.height_contract = contract.duplicate(true)

	last_report = {
		"success": true,
		"mode": "ensure_height_contract",
		"actor_id": _actor_id(actor),
		"height": str(contract.get("display", ""))
	}

	return contract.duplicate(true)

func yearly_tick_person(actor: Person, context: Dictionary = {}) -> Dictionary:
	return ensure_height_contract(actor, {
		"source": str(context.get("source", "height_contract_yearly_tick"))
	})

func format_height_inches(height_in: float) -> String:
	var rounded: int = int(round(height_in))
	var feet: int = int(floor(float(rounded) / 12.0))
	var inches: int = int(rounded % 12)
	return "%d'%d\"" % [feet, inches]

func _fallback_adult_height(actor: Person) -> float:
	if actor == null:
		return 67.0

	var gender_text: String = str(actor.gender if "gender" in actor else "").strip_edges().to_lower()
	if gender_text in ["female", "woman", "girl", "f"]:
		return 64.0
	return 69.0

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