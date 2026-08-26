extends Resource
class_name MemoryEngine

const MEMORY_PACKET_SCHEMA:= "eralife.memory_packet"
const UPCE_MEMORY_PACKET_SCHEMA:= "eralife.upce_memory_packet"
const MAX_STRUCTURED_MEMORY_PER_PERSON:= 140

var gs

func _init(_gs):
	gs = _gs

func remember(person_id: int, event: String):
	if gs == null:
		return
	if not gs.memories.has(person_id):
		gs.memories [person_id] = []

	if "Avatar" in event:
		gs.archive_generations.append({ "avatar_event": event})

	gs.memories [person_id].append(event)

	var person: Person = _person_by_id(person_id)
	if person != null and typeof(person.memories) == TYPE_ARRAY:
		person.memories.append(event)

func remember_packet(person_id: int, packet: Dictionary) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "MemoryEngine has no GameState."
		}

	if typeof(packet) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "remember_packet expected Dictionary."
		}

	var normalized: Dictionary = packet.duplicate(true)
	normalized ["schema"] = str(normalized.get("schema", MEMORY_PACKET_SCHEMA))
	normalized ["version"] = max(1, int(normalized.get("version", 1)))
	normalized ["person_id"] = int(normalized.get("person_id", person_id))
	normalized ["year"] = int(normalized.get("year", gs.year))
	normalized ["created_at_ms"] = int(normalized.get("created_at_ms", Time.get_ticks_msec()))

	var text: String = str(normalized.get("text", normalized.get("diary_text", ""))).strip_edges()
	if text == "":
		text = str(normalized.get("event_name", "I remembered something."))

	normalized ["text"] = text

	remember(person_id, text)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var structured_root: Dictionary = {}
	var root_raw: Variant = gs.scenario_state.get("structured_memories", {})
	if typeof(root_raw) == TYPE_DICTIONARY:
		structured_root = (root_raw as Dictionary).duplicate(true)

	var key: String = str(person_id)
	var person_packets: Array = []
	var packets_raw: Variant = structured_root.get(key, [])
	if typeof(packets_raw) == TYPE_ARRAY:
		person_packets = (packets_raw as Array).duplicate(true)

	person_packets.append(normalized.duplicate(true))

	while person_packets.size() > MAX_STRUCTURED_MEMORY_PER_PERSON:
		person_packets.pop_front()

	structured_root [key] = person_packets
	gs.scenario_state ["structured_memories"] = structured_root

	return {
		"success": true,
		"person_id": person_id,
		"text": text,
		"packet": normalized.duplicate(true)
	}

func remember_upce_interpretation(person_id: int, packet: Dictionary) -> Dictionary:
	var normalized: Dictionary = packet.duplicate(true)
	normalized ["schema"] = str(normalized.get("schema", UPCE_MEMORY_PACKET_SCHEMA))
	normalized ["source"] = str(normalized.get("source", "upce_engine"))
	normalized ["memory_type"] = str(normalized.get("memory_type", "biased_social_interpretation"))
	return remember_packet(person_id, normalized)

func get_memories(person_id: int) -> Array:
	if gs == null:
		return []
	return gs.memories.get(person_id, [])

func get_structured_memories(person_id: int) -> Array:
	if gs == null:
		return []
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return []

	var root_raw: Variant = gs.scenario_state.get("structured_memories", {})
	if typeof(root_raw) != TYPE_DICTIONARY:
		return []

	var packets_raw: Variant = (root_raw as Dictionary).get(str(person_id), [])
	if typeof(packets_raw) == TYPE_ARRAY:
		return (packets_raw as Array).duplicate(true)

	return []

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	return null