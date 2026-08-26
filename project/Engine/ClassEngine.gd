extends Resource
class_name ClassEngine

var gs

func _init(_gs):
	gs = _gs

var CLASS_TIERS = ["Slave", "Peasant", "Commoner", "Merchant", "Noble", "Royal"]









func _resolve_npc(arg) -> Person:
	if arg == null:
		return null

	if arg is Person:
		return arg

	if typeof(arg) == TYPE_DICTIONARY:
		var npc_id = arg.get("npc_id", -1)
		if npc_id == -1:
			return null
		return gs.get_npc_by_id(npc_id)

	if typeof(arg) == TYPE_INT:
		return gs.get_npc_by_id(arg)

	return null


func assign_birth_class(arg):
	var npc = _resolve_npc(arg)
	if npc == null:
		return
	var era = gs.era.name
	var roll:= randi() % 1000
	var base = "Commoner"
	if era == "Ancient Era":
		if roll < 6:
			base = "Royal"
		elif roll < 70:
			base = "Noble"
		else:
			base = ["Slave", "Peasant", "Commoner", "Commoner"].pick_random()
	elif era == "Medieval Era":
		if roll < 8:
			base = "Royal"
		elif roll < 110:
			base = "Noble"
		else:
			base = ["Peasant", "Peasant", "Commoner", "Merchant"].pick_random()
	elif era == "Industrial Era":
		if roll < 4:
			base = "Royal"
		elif roll < 90:
			base = "Noble"
		else:
			base = ["Commoner", "Commoner", "Merchant", "Merchant"].pick_random()
	elif era == "Modern Era":
		if roll < 4:
			base = "Royal"
		elif roll < 80:
			base = "Noble"
		else:
			base = ["Commoner", "Commoner", "Merchant", "Merchant"].pick_random()
	elif era == "Future Era":
		if roll < 10:
			base = "Royal"
		elif roll < 120:
			base = "Noble"
		else:
			base = ["Commoner", "Merchant", "Merchant", "Noble"].pick_random()
	npc.social_class = base

func apply_family_class_seed(player: Person, forced_social_class: String) -> void:
	var normalized:= str(forced_social_class).strip_edges()
	if player == null:
		return
	if normalized == "" or normalized == "Random / Era Default":
		return
	var family: Array = []
	var seen: Dictionary = {}
	_append_unique_family_member(family, seen, player)
	for pid in player.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		_append_unique_family_member(family, seen, parent)
		if parent.partner != null:
			_append_unique_family_member(family, seen, parent.partner)
		for sid in parent.children:
			_append_unique_family_member(family, seen, gs.get_npc_by_id(int(sid)))
		for gpid in parent.parents:
			var grandparent: Person = gs.get_npc_by_id(int(gpid))
			if grandparent == null:
				continue
			_append_unique_family_member(family, seen, grandparent)
			if grandparent.partner != null:
				_append_unique_family_member(family, seen, grandparent.partner)
			for ggpid in grandparent.parents:
				_append_unique_family_member(family, seen, gs.get_npc_by_id(int(ggpid)))
	for member in family:
		member.social_class = normalized

func _append_unique_family_member(family: Array, seen: Dictionary, person: Person) -> void:
	if person == null:
		return
	var pid:= int(person.id)
	if pid <= 0:
		return
	if seen.has(pid):
		return
	seen [pid] = true
	family.append(person)


func yearly_class_shift(arg):
	var npc = _resolve_npc(arg)
	if npc == null:
		return
	if not npc.alive:
		return
	if npc.social_class == "Royal":
		return


	if randi() % 1000 == 0:
		_promote(npc)


	if npc.fame == 0 and randi() % 1500 == 0:
		_demote(npc)


func _promote(npc):
	var idx = CLASS_TIERS.find(npc.social_class)
	if idx < CLASS_TIERS.size() - 1:
		npc.social_class = CLASS_TIERS [idx + 1]

func _demote(npc):
	var idx = CLASS_TIERS.find(npc.social_class)
	if idx > 0:
		npc.social_class = CLASS_TIERS [idx - 1]