extends Resource
class_name BoxingRivalryEngine

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
var rivalries:= {}

func _init(_gs):
	gs = _gs

func on_fight_completed(payload: Dictionary) -> void:
	var winner_id: int = int(payload.get("winner_id", -1))
	var loser_id: int = int(payload.get("loser_id", -1))
	if winner_id == -1 or loser_id == -1:
		return

	var key: String = _pair_key(winner_id, loser_id)
	if not rivalries.has(key):
		rivalries [key] = {
			"fighter_a": min(winner_id, loser_id),
			"fighter_b": max(winner_id, loser_id),
			"heat": 0,
			"fight_count": 0,
			"trash_talk_count": 0,
		}

	var r: Dictionary = rivalries [key]
	r ["fight_count"] = int(r.get("fight_count", 0)) + 1
	r ["heat"] = int(r.get("heat", 0)) + int(_boxing_policy("rivalry_heat_from_fight", 15))

	if str(payload.get("result_type", "")) == "KO":
		r ["heat"] = int(r.get("heat", 0)) + int(_boxing_policy("rivalry_heat_from_ko", 10))

	if bool(payload.get("title_fight", false)):
		r ["heat"] = int(r.get("heat", 0)) + int(_boxing_policy("rivalry_heat_from_title_fight", 8))

	rivalries [key] = r

	var fight_count_threshold: int = int(_boxing_policy("rivalry_fight_count_threshold", 2))
	var heat_threshold: int = int(_boxing_policy("rivalry_threshold", 30))

	if int(r ["fight_count"]) >= fight_count_threshold or int(r ["heat"]) >= heat_threshold:
		_mark_rivalry(winner_id, loser_id)

func yearly_tick() -> void:
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue

		if randi() % 100 < _trash_talk_chance(npc):
			_attempt_callout(npc)

func _mark_rivalry(a_id: int, b_id: int) -> void:
	var a = gs.get_npc_by_id(a_id)
	var b = gs.get_npc_by_id(b_id)
	if a == null or b == null:
		return

	if b.id not in a.boxing_profile ["rivalries"]:
		a.boxing_profile ["rivalries"].append(b.id)
	if a.id not in b.boxing_profile ["rivalries"]:
		b.boxing_profile ["rivalries"].append(a.id)

	var txt = "🥊 A real rivalry has formed between %s %s and %s %s." % [
		a.first_name, a.last_name, b.first_name, b.last_name
	]

	gs.event_bus.emit(ActionEventTypes.BOXING_RIVALRY_STARTED, {
		"npc_id": a.id,
		"target_id": b.id,
		"text": txt
	})

func _trash_talk_chance(npc: Person) -> int:
	var bp: Dictionary = npc.boxing_profile.get("boxing_personality", {}) if typeof(npc.boxing_profile.get("boxing_personality", {})) == TYPE_DICTIONARY else {}
	var ego_weight: float = float(_boxing_policy("trash_talk_ego_divisor", 3.0))
	var showmanship_weight: float = float(_boxing_policy("trash_talk_showmanship_divisor", 3.0))
	var min_chance: float = float(_boxing_policy("trash_talk_min_chance", 5.0))
	var max_chance: float = float(_boxing_policy("trash_talk_max_chance", 55.0))

	return int(clamp(float(bp.get("ego", 50)) / ego_weight + float(bp.get("showmanship", 50)) / showmanship_weight, min_chance, max_chance))

func _attempt_callout(npc: Person) -> void:
	var target = _pick_callout_target(npc)
	if target == null:
		return

	var lines = [
		"%s says %s is ducking real smoke.",
		"%s called out %s and promised a stoppage.",
		"%s said %s doesn't belong in the ring with them.",
		"%s told the media they would embarrass %s."
	]

	var txt = lines [randi() % lines.size()] % [npc.first_name, target.first_name]
	npc.boxing_profile ["trash_talk_reputation"] = int(npc.boxing_profile.get("trash_talk_reputation", 0)) + 1

	gs.event_bus.emit(ActionEventTypes.BOXING_TRASH_TALKED, {
		"npc_id": npc.id,
		"target_id": target.id,
		"text": txt
	})

func _pick_callout_target(npc: Person) -> Person:
	var division = str(npc.boxing_profile.get("weight_class", ""))
	var candidates:= []

	for other in gs.npcs:
		if other == null or other == npc or not other.alive:
			continue
		if not other.boxing_profile.get("is_boxer", false):
			continue
		if str(other.boxing_profile.get("weight_class", "")) != division:
			continue
		candidates.append(other)

	if candidates.is_empty():
		return null

	return candidates [randi() % candidates.size()]

func _pair_key(a: int, b: int) -> String:
	return "%d_%d" % [min(a, b), max(a, b)]