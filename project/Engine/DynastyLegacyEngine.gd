extends Resource
class_name DynastyLegacyEngine

var gs

func _init(_gs):
	gs = _gs


var dynasty_reputation = {}
var dynasty_grudges = {}
func _grudge_key(a: String, b: String) -> String:
	return "%s->%s" % [a, b]

func record_conflict(payload: Dictionary):
	var attacker_last = _resolve_last_name(payload.get("npc_id", -1))
	var target_last = _resolve_last_name(payload.get("target_id", -1))

	if attacker_last == "" or target_last == "":
		return

	if attacker_last == target_last:
		return

	var key = _grudge_key(target_last, attacker_last)
	dynasty_grudges [key] = dynasty_grudges.get(key, 0) + 10

func get_relationship_modifier(observer: Person, subject: Person) -> int:
	if observer == null or subject == null:
		return 0

	if observer.last_name == "" or subject.last_name == "":
		return 0

	var key = _grudge_key(observer.last_name, subject.last_name)
	var hate = dynasty_grudges.get(key, 0)

	return clamp(- int(hate / 4), -25, 0)
func add_reputation(person: Person, amount: int):

	var name = person.last_name

	if not dynasty_reputation.has(name):
		dynasty_reputation [name] = 0

	dynasty_reputation [name] += amount


func get_reputation(name: String) -> int:
	return dynasty_reputation.get(name, 0)
func _resolve_last_name(arg) -> String:
	if arg == null:
		return ""

	if arg is Person:
		return arg.last_name

	if typeof(arg) == TYPE_DICTIONARY:
		return str(arg.get("last_name", ""))

	if typeof(arg) == TYPE_INT:
		var facts = gs.get_npc_facts_by_id(int(arg))
		return str(facts.get("last_name", ""))

	return ""


func add_reputation_by_name(name: String, amount: int):
	if name == "":
		return

	if not dynasty_reputation.has(name):
		dynasty_reputation [name] = 0

	dynasty_reputation [name] += amount