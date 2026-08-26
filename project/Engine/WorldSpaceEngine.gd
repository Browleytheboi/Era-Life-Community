extends Resource
class_name WorldSpaceEngine

var gs


var tiles = {}
var npc_tile = {}

const TILE_SIZE = 50
const MAX_TILE_NPCS = 40


func _init(_gs):
	gs = _gs





func place_npc(npc):
	if npc == null:
		return

	var tile = null

	if gs != null and gs.geo_engine != null and gs.geo_engine.has_method("get_anchor_tile_for_person"):
		tile = gs.geo_engine.get_anchor_tile_for_person(npc)

	if tile == null:
		tile = _random_tile()

	npc_tile [npc.id] = tile
	if not tiles.has(tile):
		tiles [tile] = []
	if npc.id not in tiles [tile]:
		tiles [tile].append(npc.id)





func get_tile(npc):
	if npc == null:
		return null

	if not npc_tile.has(npc.id):
		place_npc(npc)

	return npc_tile.get(npc.id, null)





func get_position(npc) -> Vector2i:
	var tile = get_tile(npc)

	if tile == null:
		return Vector2i.ZERO

	if tile is Vector2i:
		return tile

	if typeof(tile) == TYPE_STRING:
		var parts = str(tile).split("_")
		if parts.size() >= 2:
			return Vector2i(int(parts [0]), int(parts [1]))

	return Vector2i.ZERO





func move_npc(npc):
	if npc == null:
		return

	var old_tile = npc_tile.get(npc.id)
	if old_tile == null:
		place_npc(npc)
		old_tile = npc_tile.get(npc.id)

	if old_tile != null and tiles.has(old_tile):
		tiles [old_tile].erase(npc.id)
		if tiles [old_tile].is_empty():
			tiles.erase(old_tile)

	var new_tile = null
	if gs != null and gs.geo_engine != null and gs.geo_engine.has_method("get_neighbor_tile_for_person"):
		new_tile = gs.geo_engine.get_neighbor_tile_for_person(npc, old_tile)

	if new_tile == null:
		new_tile = _neighbor_tile(old_tile)

	npc_tile [npc.id] = new_tile
	if not tiles.has(new_tile):
		tiles [new_tile] = []
	if npc.id not in tiles [new_tile]:
		tiles [new_tile].append(npc.id)

	var moved_text:= "%s %s moved through %s." % [
		str(npc.first_name),
		str(npc.last_name),
		str(npc.home_city if str(npc.home_city).strip_edges() != "" else "the local area")
	]

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.NPC_MOVED, {
			"npc_id": npc.id,
			"tile": new_tile,
			"text": moved_text,
			"realm_id": int(npc.realm_id),
			"settlement_id": str(npc.settlement_id),
			"district_id": str(npc.district_id),
			"locality_id": str(npc.locality_id),
			"home_city": str(npc.home_city),
			"home_country": str(npc.home_country),
			"source": "world_space_engine"
		})





func get_nearby_npcs(npc):

	var tile = npc_tile.get(npc.id)

	if tile == null:
		return []

	var nearby = []

	if tiles.has(tile):
		for id in tiles [tile]:
			if id != npc.id:
				var n = gs.get_npc_by_id(id)
				if n != null:
					nearby.append(n)

	return nearby





func _random_tile():

	var x = randi_range(-100, 100)
	var y = randi_range(-100, 100)

	return "%d_%d" % [x, y]


func _neighbor_tile(tile):

	if tile == null:
		return _random_tile()

	var parts = tile.split("_")

	var x = int(parts [0]) + randi_range(-1, 1)
	var y = int(parts [1]) + randi_range(-1, 1)

	return "%d_%d" % [x, y]