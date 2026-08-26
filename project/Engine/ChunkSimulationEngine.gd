extends Resource
class_name ChunkSimulationEngine

var gs

const CHUNK_SIZE = 50


var chunks = {}

func _init(_gs):
	gs = _gs





func assign_npc(npc):

	var key = _get_chunk_key(npc)

	if not chunks.has(key):
		chunks [key] = []

	if npc.id not in chunks [key]:
		chunks [key].append(npc.id)





func remove_npc(npc):

	var key = _get_chunk_key(npc)

	if chunks.has(key):
		chunks [key].erase(npc.id)



func _get_chunk_key(npc):

	var city = npc.home_city if npc.home_city != "" else npc.birth_city
	var country = npc.home_country if npc.home_country != "" else npc.birth_country

	var x = int(hash(city) % CHUNK_SIZE)
	var y = int(hash(country) % CHUNK_SIZE)

	return Vector2i(x, y)




func get_player_chunk():

	return _get_chunk_key(gs.player)





func get_active_chunks():

	var p = get_player_chunk()

	var active = []

	for x in range(-1, 2):
		for y in range(-1, 2):
			active.append(p + Vector2i(x, y))

	return active





func simulate_world():

	var active = get_active_chunks()

	for key in chunks.keys():

		if key in active:
			_simulate_chunk_full(key)
		else:
			_simulate_chunk_light(key)





func _simulate_chunk_full(key):

	if not chunks.has(key):
		return

	for id in chunks [key]:

		var npc = gs.get_npc_by_id(id)
		if npc == null:
			continue

		gs.health_engine.update_health(npc)
		gs.career_engine.update_career(npc)
		gs.personality_engine.generate_traits(npc)





func _simulate_chunk_light(key):

	if not chunks.has(key):
		return

	for id in chunks [key]:

		var npc = gs.get_npc_by_id(id)
		if npc == null:
			continue
		if not npc.alive:
			continue