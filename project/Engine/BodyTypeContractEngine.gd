extends Resource
class_name BodyTypeContractEngine

const CONTRACT_SCHEMA:= "eralife.body_type_contract_engine"
const CONTRACT_VERSION:= 1
const PERSON_BODY_TYPE_SCHEMA:= "eralife.person.body_type_contract"

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
		return { "success": false, "reason": "BodyTypeContractEngine import_state expected Dictionary."}
	last_report = _safe_dictionary(data.get("last_report", {}))
	return { "success": true, "schema": CONTRACT_SCHEMA + "_state"}

func ensure_body_type_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var existing: Dictionary = _safe_dictionary(actor.body_type_contract)
	if not existing.is_empty() and bool(existing.get("sealed", false)):
		return existing.duplicate(true)

	var genetics: Dictionary = {}
	if gs != null and gs.genetics_inheritance_engine != null and gs.genetics_inheritance_engine.has_method("ensure_genetics_contract"):
		genetics = gs.genetics_inheritance_engine.ensure_genetics_contract(actor, {
			"source": "body_type_contract_engine",
			"requested_by": str(context.get("source", "unknown"))
		})
	else:
		genetics = _safe_dictionary(actor.genetics_contract)

	var body_bias: Dictionary = _safe_dictionary(genetics.get("body_type_bias", {}))
	var body_type: String = str(genetics.get("dominant_body_type", "")).strip_edges().to_lower()
	if body_type == "":
		body_type = _dominant_bias_key(body_bias, "mesomorph")

	if body_type not in ["ectomorph", "mesomorph", "endomorph"]:
		body_type = "mesomorph"

	var traits: Dictionary = _body_type_traits(body_type)
	var contract: Dictionary = _merge_dict({
		"schema": PERSON_BODY_TYPE_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"sealed": true,
		"type": body_type,
		"display_name": _body_type_display_name(body_type),
		"description": str(traits.get("description", "")),
		"traits": traits.duplicate(true),
		"source": str(context.get("source", "body_type_contract_engine")),
		"contract_mesh": {
			"source_of_truth": "body_type_contract_engine",
			"observed_by": ["weight_contract_engine", "height_contract_engine", "relationship_profile", "sports_domains"],
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}, existing)

	actor.body_type_contract = contract.duplicate(true)

	last_report = {
		"success": true,
		"mode": "ensure_body_type_contract",
		"actor_id": _actor_id(actor),
		"type": body_type
	}

	return contract.duplicate(true)

func _body_type_traits(body_type: String) -> Dictionary:
	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			return {
				"fat_gain_multiplier": 0.78,
				"muscle_gain_multiplier": 0.88,
				"natural_frame_multiplier": 0.92,
				"metabolism_multiplier": 1.14,
				"weight_drift_to_setpoint": 0.18,
				"description": "Naturally leaner frame, faster metabolism, harder weight gain."
			}
		"endomorph":
			return {
				"fat_gain_multiplier": 1.22,
				"muscle_gain_multiplier": 1.03,
				"natural_frame_multiplier": 1.1,
				"metabolism_multiplier": 0.88,
				"weight_drift_to_setpoint": 0.12,
				"description": "Naturally heavier frame, easier weight gain, slower weight loss."
			}
		_:
			return {
				"fat_gain_multiplier": 1.0,
				"muscle_gain_multiplier": 1.1,
				"natural_frame_multiplier": 1.02,
				"metabolism_multiplier": 1.0,
				"weight_drift_to_setpoint": 0.15,
				"description": "Balanced athletic frame with average weight response."
			}

func _body_type_display_name(body_type: String) -> String:
	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			return "Ectomorph"
		"endomorph":
			return "Endomorph"
		_:
			return "Mesomorph"

func _dominant_bias_key(bias: Dictionary, fallback: String = "mesomorph") -> String:
	var best_key: String = fallback
	var best_value: float = -999999.0

	for raw_key in bias.keys():
		var clean_key: String = str(raw_key).strip_edges().to_lower()
		var value: float = float(bias.get(raw_key, 0.0))
		if value > best_value:
			best_value = value
			best_key = clean_key

	return best_key

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