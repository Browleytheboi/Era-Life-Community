extends Resource
class_name LegacyMemoryEngine

var gs

func _init(_gs):
	gs = _gs


var dynasty_memories = {}


var npc_memory_of_dynasty = {}





func record_dynasty_event(person: Person, text: String):

	var dynasty = person.last_name

	if not dynasty_memories.has(dynasty):
		dynasty_memories [dynasty] = []

	dynasty_memories [dynasty].append({
		"year": gs.year,
		"text": text
	})

	if dynasty_memories [dynasty].size() > 100:
		dynasty_memories [dynasty].pop_front()





func npc_remembers_dynasty(npc: Person, dynasty: String, text: String):

	if not npc_memory_of_dynasty.has(npc.id):
		npc_memory_of_dynasty [npc.id] = []

	npc_memory_of_dynasty [npc.id].append({
		"dynasty": dynasty,
		"text": text
	})





func apply_dynasty_reaction(player: Person, npc: Person):

	if not npc_memory_of_dynasty.has(npc.id):
		return

	for m in npc_memory_of_dynasty [npc.id]:

		if m.dynasty == player.last_name:

			npc.affection [player.id] = npc.affection.get(player.id, 50) + randi_range(-30, 30)

			gs.push_world_feed(
				"%s seems to recognize the %s family." %
				[npc.first_name, player.last_name],
				{
					"npc_id": npc.id,
					"personally_relevant": true,
					"category": "dynasty",
					"event_name": "dynasty_recognition",
					"source": "legacy_memory_engine"
				}
			)