extends Resource
class_name SocialGraphEngine

var gs

func _init(_gs):
	gs = _gs







var graph:= {}






func ensure_node(id: int):

	if not graph.has(id):
		graph [id] = {}






func connect_people(a: int, b: int, weight: int = 50):

	ensure_node(a)
	ensure_node(b)

	graph [a] [b] = weight
	graph [b] [a] = weight






func disconnect_people(a: int, b: int):

	if graph.has(a):
		graph [a].erase(b)

	if graph.has(b):
		graph [b].erase(a)






func get_connections(id: int) -> Array:

	if not graph.has(id):
		return []

	return graph [id].keys()






func get_affection(a: int, b: int) -> int:

	if not graph.has(a):
		return 50

	return graph [a].get(b, 50)






func modify_affection(a: int, b: int, delta: int):

	ensure_node(a)
	ensure_node(b)

	var val = graph [a].get(b, 50)
	val += delta
	val = clamp(val, 0, 100)

	graph [a] [b] = val
	graph [b] [a] = val
func link(a: int, b: int, weight: int = 50):
	connect_people(a, b, weight)

func unlink(a: int, b: int):
	disconnect_people(a, b)
func strongest_connections(id: int, limit:= 5) -> Array:
	if not graph.has(id):
		return []

	var pairs:= []
	for other_id in graph [id].keys():
		pairs.append({
			"id": other_id,
			"weight": graph [id] [other_id]
		})

	pairs.sort_custom(func (a, b): return a.weight > b.weight)

	var out:= []
	for i in range(min(limit, pairs.size())):
		out.append(pairs [i].id)
	return out

func relationship_strength(a: int, b: int) -> int:
	if not graph.has(a):
		return 0
	return graph [a].get(b, 0)

func has_strong_tie(a: int, b: int, threshold:= 65) -> bool:
	return relationship_strength(a, b) >= threshold