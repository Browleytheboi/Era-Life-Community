extends Resource
class_name ReputationEngine

var gs

func _init(_gs):
	gs = _gs




func on_reputation_event(payload: Dictionary):
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var fanout_hints_raw: Variant = payload.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}
	if bool(fanout_hints.get("skip_reputation", false)):
		return

	var qos_tier: String = _resolve_event_bus_qos_tier(payload)
	if qos_tier == "ambient":
		return

	var npc_id = int(payload.get("npc_id", -1))
	if npc_id == -1:
		return
	var source_facts = gs.get_npc_facts_by_id(npc_id)
	if source_facts == {}:
		return
	var source = gs.get_npc_by_id(npc_id)
	var intensity = _adjust_reputation_intensity_for_qos(_calculate_intensity(source_facts, payload), qos_tier)

	if source != null:
		_propagate_reputation_qos(source, payload, intensity, qos_tier)
	else:
		_propagate_reputation_from_snapshot_qos(source_facts, payload, intensity, qos_tier)

	gs.dynasty_legacy_engine.add_reputation_by_name(
		str(source_facts.get("last_name", "")),
		5 if qos_tier == "critical" else 2
	)
func _resolve_event_bus_qos_tier(payload: Dictionary) -> String:
	var qos_tier: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
	if qos_tier in ["critical", "important", "ambient"]:
		return qos_tier

	var fanout_priority: String = str(payload.get("fanout_priority", "")).strip_edges().to_lower()
	if fanout_priority in ["critical", "high"]:
		return "critical"
	if fanout_priority in ["ambient", "low"]:
		return "ambient"
	return "important"


func _adjust_reputation_intensity_for_qos(intensity: int, qos_tier: String) -> int:
	if qos_tier == "important":
		return int(clamp(round(float(intensity) * 0.7), 5.0, 100.0))
	return intensity


func _propagate_reputation_qos(source: Person, payload: Dictionary, intensity: int, qos_tier: String):
	if qos_tier == "critical":
		_propagate_reputation(source, payload, intensity)
		return

	var applied: int = 0
	var max_targets: int = 18
	for npc in gs.npcs:
		if npc == source:
			continue
		var social_distance = _social_distance(source, npc)
		var spread_chance = intensity - (social_distance * 15)
		spread_chance = int(clamp(round(float(spread_chance) * 0.65), 0.0, 100.0))
		if randi() % 100 < spread_chance:
			_apply_reputation_memory(source, npc, payload, intensity)
			applied += 1
			if applied >= max_targets:
				break


func _propagate_reputation_from_snapshot_qos(source_facts: Dictionary, payload: Dictionary, intensity: int, qos_tier: String):
	if qos_tier == "critical":
		_propagate_reputation_from_snapshot(source_facts, payload, intensity)
		return

	var applied: int = 0
	var max_targets: int = 18
	for observer in gs.npcs:
		if observer == null or not observer.alive:
			continue
		if observer.id == int(source_facts.get("id", -1)):
			continue
		var social_distance = _social_distance_from_snapshot(source_facts, observer)
		var spread_chance = intensity - (social_distance * 15)
		spread_chance = int(clamp(round(float(spread_chance) * 0.65), 0.0, 100.0))
		if randi() % 100 < spread_chance:
			_apply_reputation_memory_from_snapshot(source_facts, observer, payload, intensity)
			applied += 1
			if applied >= max_targets:
				break





func _calculate_intensity(npc_facts: Dictionary, payload: Dictionary) -> int:
	var base = 10
	var fame_tier = str(npc_facts.get("fame_tier", "None"))
	var social_class = str(npc_facts.get("social_class", ""))

	if fame_tier == "Legend":
		base += 50
	elif fame_tier == "Global":
		base += 35
	elif fame_tier == "National":
		base += 20
	elif fame_tier == "Local":
		base += 10

	if social_class in ["Royal", "Noble"]:
		base += 15

	var event_name = payload.get("event_name", payload.get("type", ""))
	if event_name == ActionEventTypes.NPC_COMMITTED_CRIME:
		base += 25

	return clamp(base, 5, 100)






func _propagate_reputation(source: Person, payload: Dictionary, intensity: int):

	for npc in gs.npcs:

		if npc == source:
			continue

		var social_distance = _social_distance(source, npc)

		var spread_chance = intensity - (social_distance * 15)

		if randi() % 100 < spread_chance:
			_apply_reputation_memory(source, npc, payload, intensity)






func _social_distance(a: Person, b: Person) -> int:
	var weight = gs.social_graph_engine.relationship_strength(a.id, b.id)
	if weight >= 75:
		return 0
	elif weight >= 55:
		return 1
	elif weight >= 35:
		return 2
	if b.id in a.parents or a.id in b.parents:
		return 0

	if b.id in a.friends:
		return 1

	if a.realm_id == b.realm_id:
		return 2

	if a.social_class == b.social_class:
		return 3

	return 4






func _apply_reputation_memory(source: Person, observer: Person, payload: Dictionary, intensity: int):

	var rumor = _distort_event(source, payload, intensity)

	gs.memory_engine.remember(observer.id, rumor)


	var event_name = payload.get("event_name", payload.get("type", ""))
	if event_name == ActionEventTypes.NPC_COMMITTED_CRIME:
		observer.affection [source.id] = observer.affection.get(source.id, 50) - 10

	if source.fame > 50:
		observer.affection [source.id] = observer.affection.get(source.id, 50) + 5






func _distort_event(source: Person, _payload: Dictionary, _intensity: int) -> String:

	var exaggeration = randi_range(0, 3)

	var base = "%s %s was involved in something shocking." % [
		source.first_name,
		source.last_name
	]

	if exaggeration == 0:
		return base

	if exaggeration == 1:
		return "%s %s caused chaos across the realm." % [
			source.first_name,
			source.last_name
		]

	if exaggeration == 2:
		return "Everyone is talking about %s %s." % [
			source.first_name,
			source.last_name
		]

	return "%s %s may change the fate of this era." % [
		source.first_name,
		source.last_name
	]
func _propagate_reputation_from_snapshot(source_facts: Dictionary, payload: Dictionary, intensity: int):
	for observer in gs.npcs:
		if observer == null or not observer.alive:
			continue
		if observer.id == int(source_facts.get("id", -1)):
			continue

		var social_distance = _social_distance_from_snapshot(source_facts, observer)
		var spread_chance = intensity - (social_distance * 15)

		if randi() % 100 < spread_chance:
			_apply_reputation_memory_from_snapshot(source_facts, observer, payload, intensity)


func _social_distance_from_snapshot(source_facts: Dictionary, observer: Person) -> int:
	if observer == null:
		return 4

	if observer.id in source_facts.get("parents", []):
		return 0

	if int(source_facts.get("id", -1)) in observer.parents:
		return 0

	if observer.id in source_facts.get("friends", []):
		return 1

	if observer.realm_id == int(source_facts.get("realm_id", -1)):
		return 2

	if observer.social_class == str(source_facts.get("social_class", "")):
		return 3

	return 4


func _apply_reputation_memory_from_snapshot(source_facts: Dictionary, observer: Person, payload: Dictionary, intensity: int):
	var rumor = _distort_event_from_snapshot(source_facts, payload, intensity)
	gs.memory_engine.remember(observer.id, rumor)

	var source_id = int(source_facts.get("id", -1))
	var event_name = payload.get("event_name", payload.get("type", ""))

	if event_name == ActionEventTypes.NPC_COMMITTED_CRIME:
		observer.affection [source_id] = observer.affection.get(source_id, 50) - 10

	if int(source_facts.get("fame", 0)) > 50:
		observer.affection [source_id] = observer.affection.get(source_id, 50) + 5


func _distort_event_from_snapshot(source_facts: Dictionary, _payload: Dictionary, _intensity: int) -> String:
	var first_name = str(source_facts.get("first_name", "Unknown"))
	var last_name = str(source_facts.get("last_name", ""))
	var exaggeration = randi_range(0, 3)

	var base = "%s %s was involved in something shocking." % [first_name, last_name]

	if exaggeration == 0:
		return base
	if exaggeration == 1:
		return "%s %s caused chaos across the realm." % [first_name, last_name]
	if exaggeration == 2:
		return "Everyone is talking about %s %s." % [first_name, last_name]

	return "%s %s may change the fate of this era." % [first_name, last_name]