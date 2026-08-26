extends Resource
class_name NPCMemoryWebEngine

var gs


var memory_graph = {}

func _init(_gs):
	gs = _gs





func record_memory(payload):
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var fanout_hints_raw: Variant = payload.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}
	if bool(fanout_hints.get("skip_npc_memory_web", false)):
		return

	var qos_tier: String = _resolve_event_bus_qos_tier(payload)
	if qos_tier == "ambient":
		return

	var npc_id = int(payload.get("npc_id", -1))
	if npc_id == -1:
		return
	var facts = gs.get_npc_facts_by_id(npc_id)
	if facts == {}:
		return
	var text: String = str(payload.get("text", "")).strip_edges()
	if text == "":
		return

	if not memory_graph.has(npc_id):
		memory_graph [npc_id] = []

	if qos_tier == "important" and _has_recent_structured_memory(npc_id, text, str(payload.get("event_name", payload.get("type", "event"))), int(payload.get("year", gs.year))):
		return

	var mem = {
		"event_id": int(payload.get("event_id", -1)),
		"year": int(payload.get("year", gs.year)),
		"era": str(payload.get("era", gs.era.name if gs.era != null else "")),
		"type": str(payload.get("event_name", payload.get("type", "event"))),
		"text": text,
		"impact": _calculate_impact(payload),
		"source": str(payload.get("source", "event_bus")),
		"target_id": int(payload.get("target_id", -1)),
		"data": payload.get("data", {}).duplicate(true),
		"npc_facts": payload.get("npc_facts", payload.get("_query_facts", {})),
		"qos_tier": qos_tier
	}
	const MAX_STRUCTURED_MEMORIES_PER_NPC:= 120
	memory_graph [npc_id].append(mem)
	if memory_graph [npc_id].size() > MAX_STRUCTURED_MEMORIES_PER_NPC:
		memory_graph [npc_id].pop_front()

	if qos_tier == "critical":
		gs.memory_engine.remember(npc_id, mem.text)
	elif int(mem.get("impact", 0)) >= 20:
		gs.memory_engine.remember(npc_id, mem.text)
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


func _has_recent_structured_memory(npc_id: int, text: String, event_type: String, year_value: int) -> bool:
	if not memory_graph.has(npc_id):
		return false

	var memories: Array = memory_graph.get(npc_id, [])
	var start_index: int = max(0, memories.size() - 8)
	for i in range(start_index, memories.size()):
		var raw_mem: Variant = memories [i]
		if typeof(raw_mem) != TYPE_DICTIONARY:
			continue
		var mem: Dictionary = raw_mem
		if int(mem.get("year", -1)) != year_value:
			continue
		if str(mem.get("type", "")).strip_edges() != event_type:
			continue
		if str(mem.get("text", "")).strip_edges() == text:
			return true

	return false





func _calculate_impact(payload):

	var impact = 5
	var event_name = payload.get("event_name", payload.get("type", ""))

	if event_name == ActionEventTypes.NPC_COMMITTED_CRIME:
		impact += 20

	if event_name == ActionEventTypes.NPC_DIED:
		impact += 15

	if event_name == ActionEventTypes.ARTIFACT_ACQUIRED:
		impact += 25

	if event_name == ActionEventTypes.WISH_MADE:
		impact += 30

	return impact





func apply_memory_effects(observer: Person, subject: Person):

	if not memory_graph.has(subject.id):
		return

	var memories = memory_graph [subject.id]

	for m in memories:

		if m.impact > 20:
			observer.affection [subject.id] = observer.affection.get(subject.id, 50) - 10

		if "hero" in m.text.to_lower():
			observer.affection [subject.id] += 5





func inherit_family_memories(child: Person):

	for pid in child.parents:

		if memory_graph.has(pid):

			for m in memory_graph [pid]:

				if m.impact >= 20:

					var rumor = "My family remembers that " + m.text
					gs.memory_engine.remember(child.id, rumor)
func get_recent_memories(npc_id: int, limit: int = 8) -> Array:
	if not memory_graph.has(npc_id):
		return []

	var arr: Array = memory_graph [npc_id] as Array
	var start: int = max(0, arr.size() - limit)
	return arr.slice(start, arr.size())

func get_high_impact_memories(npc_id: int, min_impact:= 20, limit:= 6) -> Array:
	if not memory_graph.has(npc_id):
		return []
	var out: Array = []
	for mem in memory_graph [npc_id]:
		if int(mem.get("impact", 0)) >= min_impact:
			out.append(mem)
	if out.size() > limit:
		out = out.slice(out.size() - limit, out.size())
	return out

func get_relationship_relevant_memories(npc_id: int, other_id: int, limit:= 5) -> Array:
	if not memory_graph.has(npc_id):
		return []
	var out: Array = []
	for mem in memory_graph [npc_id]:
		if int(mem.get("target_id", -1)) == other_id:
			out.append(mem)
	if out.size() > limit:
		out = out.slice(out.size() - limit, out.size())
	return out