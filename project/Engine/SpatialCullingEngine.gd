extends Resource
class_name SpatialCullingEngine

var gs

var NEAR_RADIUS = 2
var MID_RADIUS = 6

func _init(_gs):
	gs = _gs





func _distance(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)





func classify():

	var near:= []
	var mid:= []
	var far:= []

	var player_pos = gs.world_space_engine.get_position(gs.player)

	for npc in gs.npcs:

		if npc == gs.player:
			continue

		if npc == null:
			continue

		if not npc.alive:
			continue

		var pos = gs.world_space_engine.get_position(npc)
		var d = _distance(player_pos, pos)

		if d <= NEAR_RADIUS:
			near.append(npc)
		elif d <= MID_RADIUS:
			mid.append(npc)
		else:
			far.append(npc)

	return {
		"near": near,
		"mid": mid,
		"far": far
	}





func simulate_far_npc(npc):


	if randi() % 5 == 0:
		npc.health = clamp(npc.health + randi_range(-2, 1), 0, 100)


	if npc.job != "" and randi() % 20 == 0:
		npc.income += randi_range(-200, 500)


	if randi() % 20 == 0:
		npc.satisfaction += randi_range(-3, 3)

	npc.satisfaction = clamp(npc.satisfaction, 0, 100)