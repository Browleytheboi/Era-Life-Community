extends Resource
class_name DynastyEngine

var gs

func _init(_gs):
	gs = _gs






var dynasties = {}





func register_dynasty(last_name: String):

	if dynasties.has(last_name):
		return

	dynasties [last_name] = {
		"origin": _random_origin(),
		"root": _extract_root(last_name),
		"prestige": 50 + randi() % 50,
		"age": 1,
		"mutation_count": 0
	}





func _random_origin():
	var list = [
		"Germanic", "Slavic", "Latin", "Celtic", "African",
		"Nordic", "East Asian", "Arabic", "Hebrew"
	]
	return list [randi() % list.size()]



func _extract_root(last_name: String):
	if last_name.length() < 4:
		return last_name
	return last_name.substr(0, 4).to_lower()





func inherit_surname(father_last: String, mother_last: String) -> String:


	var base = father_last


	register_dynasty(father_last)
	register_dynasty(mother_last)

	var dy = dynasties [base]


	if _should_mutate(gs.era):
		base = _mutate_surname(base)
		dy ["mutation_count"] += 1


	dy ["age"] += 1
	dynasties [father_last] = dy

	return base





func _should_mutate(era: Dictionary) -> bool:

	match era.name:
		"Ancient Era":
			return randi() % 100 < 5
		"Medieval Era":
			return randi() % 100 < 10
		"Industrial Era":
			return randi() % 100 < 15
		"Modern Era":
			return randi() % 100 < 20
		"Future Era":
			return randi() % 100 < 35
		_:
			return false


func _mutate_surname(name: String) -> String:

	var patterns = [
		func (n): return n + "sen",
		func (n): return n + "ov",
		func (n): return n + "ski",
		func (n): return n.substr(0, max(2, n.length() - 2)) + "er",
		func (n): return n + "-" + str(randi() % 99),
		func (n): return n + "Prime",
		func (n): return n + " IX"
	]

	var f = patterns [randi() % patterns.size()]
	var newname = f.call(name)

	return newname





func autofill_name(gender: String) -> Dictionary:
	var era_name = gs.era.name if gs.era != null else "Modern Era"

	var first = gs.names_db.random_first_for_era(gender, era_name)
	var last = gs.names_db.random_last_for_era(era_name)

	register_dynasty(last)
	return { "first": first, "last": last}





func describe(last_name: String) -> String:

	if not dynasties.has(last_name):
		return "%s (untracked dynasty)" % last_name

	var d = dynasties [last_name]

	return "%s — Origin: %s | Prestige: %d | Age: %d | Mutations: %d" % [
		last_name,
		d.origin,
		d.prestige,
		d.age,
		d.mutation_count
	]