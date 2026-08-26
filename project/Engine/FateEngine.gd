extends Resource
class_name FateEngine
var gs
func _init(_gs):
	gs = _gs
func assign_arc(person):
	var arcs = ["Blessed", "Struggler", "Chosen", "Wanderer", "Star"]
	person.fate_arc = arcs [randi() % arcs.size()]