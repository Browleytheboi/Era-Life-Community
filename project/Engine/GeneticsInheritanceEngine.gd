extends Resource
class_name GeneticsInheritanceEngine

const CONTRACT_SCHEMA:= "eralife.genetics_inheritance_contract_engine"
const CONTRACT_VERSION:= 1
const PERSON_GENETICS_SCHEMA:= "eralife.person.genetics_contract"

var gs
var last_report: Dictionary = {}
var mutation_log: Array = []

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"last_report": last_report.duplicate(true),
		"mutation_log": mutation_log.duplicate(true)
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "GeneticsInheritanceEngine import_state expected Dictionary."}

	last_report = _safe_dictionary(data.get("last_report", {}))
	mutation_log = _safe_array(data.get("mutation_log", []))

	return {
		"success": true,
		"schema": CONTRACT_SCHEMA + "_state",
		"mutation_count": mutation_log.size()
	}
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
func ensure_genetics_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var existing: Dictionary = _safe_dictionary(actor.genetics_contract)
	if not existing.is_empty() and bool(existing.get("sealed", false)):
		return existing.duplicate(true)

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("genetics|%s|%s|%s|%s" % [
		str(_actor_id(actor)),
		_actor_name(actor),
		_actor_gender(actor),
		str(context.get("source", "ensure_genetics_contract"))
	])

	var defer_parent_resolution: bool = bool(context.get("defer_parent_resolution", true))
	var parents: Array = []
	if not defer_parent_resolution:
		parents = _parent_people(actor)

	var inherited_height_values: Array = []
	var inherited_body_types: Array = []

	for parent in parents:
		if parent == null:
			continue

		var parent_contract: Dictionary = _safe_dictionary(parent.genetics_contract)
		if parent_contract.is_empty() and not defer_parent_resolution:
			parent_contract = ensure_genetics_contract(parent, {
				"source": "parent_genetics_for_child",
				"child_id": _actor_id(actor),
				"defer_parent_resolution": true
			})

		var parent_height: float = float(parent_contract.get("target_adult_height_in", 0.0))
		if parent_height > 0.0:
			inherited_height_values.append(parent_height)

		var parent_body: String = str(parent_contract.get("dominant_body_type", "")).strip_edges().to_lower()
		if parent_body != "":
			inherited_body_types.append(parent_body)

	var gender_text: String = _actor_gender(actor)
	var baseline_height: float = 69.0
	if gender_text in ["female", "woman", "girl", "f"]:
		baseline_height = 64.0

	var inherited_height: float = baseline_height
	if not inherited_height_values.is_empty():
		var total: float = 0.0
		for raw_height in inherited_height_values:
			total += float(raw_height)
		inherited_height = total / float(inherited_height_values.size())

	var mutation_height: float = rng.randfn(0.0, 2.2)
	var target_height: float = clamp(inherited_height + mutation_height, 48.0, 86.0)

	var body_bias: Dictionary = {
		"ectomorph": 1.0 + rng.randf_range(-0.25, 0.25),
		"mesomorph": 1.0 + rng.randf_range(-0.25, 0.25),
		"endomorph": 1.0 + rng.randf_range(-0.25, 0.25)
	}

	for inherited_type in inherited_body_types:
		var clean_type: String = str(inherited_type).strip_edges().to_lower()
		if body_bias.has(clean_type):
			body_bias [clean_type] = float(body_bias.get(clean_type, 1.0)) + 0.45

	var dominant_body_type: String = _dominant_bias_key(body_bias, "mesomorph")

	var growth_timing_roll: int = int(rng.randi_range(0, 100))
	var growth_timing_gene: String = "average"
	if growth_timing_roll <= 24:
		growth_timing_gene = "early"
	elif growth_timing_roll >= 76:
		growth_timing_gene = "late"

	var frame_gene: float = clamp(rng.randfn(1.0, 0.11), 0.74, 1.32)
	var metabolism_gene: float = clamp(rng.randfn(1.0, 0.12), 0.72, 1.35)

	var contract: Dictionary = _merge_dict({
		"schema": PERSON_GENETICS_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": _actor_id(actor),
		"sealed": true,
		"source": str(context.get("source", "genetics_inheritance_engine")),
		"target_adult_height_in": target_height,
		"dominant_body_type": dominant_body_type,
		"body_type_bias": body_bias.duplicate(true),
		"growth_timing_gene": growth_timing_gene,
		"frame_gene": frame_gene,
		"metabolism_gene": metabolism_gene,
		"inherited_from_parent_ids": _parent_ids(actor),
		"mutation_profile": {
			"height_delta": mutation_height,
			"mutation_strength": abs(mutation_height) / 4.0,
			"created_at_ms": int(Time.get_ticks_msec())
		},
		"contract_mesh": {
			"source_of_truth": "genetics_inheritance_engine",
			"observed_by": ["height_contract_engine", "weight_contract_engine", "body_type_contract_engine", "growth_curve_engine"],
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}, existing)

	actor.genetics_contract = contract.duplicate(true)

	if typeof(actor.inherited_systems) != TYPE_DICTIONARY:
		actor.inherited_systems = {}
	actor.inherited_systems ["genetics"] = contract.duplicate(true)

	last_report = {
		"success": true,
		"mode": "ensure_genetics_contract",
		"actor_id": _actor_id(actor),
		"target_adult_height_in": target_height,
		"dominant_body_type": dominant_body_type,
		"growth_timing_gene": growth_timing_gene
	}

	return contract.duplicate(true)

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

func _parent_people(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out

	for raw_id in _parent_ids(actor):
		var parent_id: int = int(raw_id)
		if parent_id <= 0:
			continue

		var parent: Person = null
		if gs.has_method("get_or_reactivate_npc_by_id"):
			parent = gs.get_or_reactivate_npc_by_id(parent_id)
		elif gs.has_method("get_npc_by_id"):
			parent = gs.get_npc_by_id(parent_id)

		if parent != null:
			out.append(parent)

	return out

func _parent_ids(actor: Person) -> Array:
	if actor == null:
		return []
	if not ("parents" in actor):
		return []
	if typeof(actor.parents) != TYPE_ARRAY:
		return []
	return actor.parents.duplicate(true)

func _actor_id(actor: Person) -> int:
	if actor == null:
		return -1
	if "id" in actor:
		return int(actor.id)
	return -1

func _actor_name(actor: Person) -> String:
	if actor == null:
		return "Unknown"

	var first_name: String = str(actor.first_name).strip_edges() if "first_name" in actor else ""
	var last_name: String = str(actor.last_name).strip_edges() if "last_name" in actor else ""
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name != "":
		return full_name

	if "name" in actor:
		var direct_name: String = str(actor.name).strip_edges()
		if direct_name != "":
			return direct_name

	return "Unknown"

func _actor_gender(actor: Person) -> String:
	if actor == null:
		return ""
	if "gender" in actor:
		return str(actor.gender).strip_edges().to_lower()
	return ""

func _stable_seed(seed_text: String) -> int:
	return abs(hash(str(seed_text))) % 2147483647

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