extends Resource
class_name ECSEngine

var gs

var entities:= []
var components:= {}

func _init(_gs):
	gs = _gs




func create_entity() -> int:

	var id = gs.next_id
	gs.next_id += 1

	entities.append(id)
	return id





func add_component(entity_id: int, comp_name: String, data):

	if not components.has(comp_name):
		components [comp_name] = {}

	components [comp_name] [entity_id] = data





func get_component(entity_id: int, comp_name: String):

	if not components.has(comp_name):
		return null

	return components [comp_name].get(entity_id)





func query(comp_name: String) -> Array:

	if not components.has(comp_name):
		return []

	return components [comp_name].keys()





func remove_entity(entity_id: int):

	entities.erase(entity_id)

	for c in components.keys():
		components [c].erase(entity_id)