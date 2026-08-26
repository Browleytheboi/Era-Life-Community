extends Resource
class_name VampireSocietyEngine

var gs
var covens:= {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}):
	if randi() % 400 == 0:
		_found_hunter_reactive_coven()

func found_coven(founder: Person, name: String) -> Dictionary:
	if founder == null or not founder.vampire_profile.get("is_vampire", false):
		return { "text": "❌ Only vampires can found a coven."}

	var coven_id = name.to_lower().replace(" ", "_")
	if covens.has(coven_id):
		return { "text": "❌ That coven already exists."}

	covens [coven_id] = {
		"id": coven_id,
		"name": name,
		"founder_id": founder.id,
		"members": [founder.id],
		"prestige": 10,
		"realm_id": founder.realm_id
	}

	founder.vampire_profile ["coven_id"] = coven_id

	var txt = "🦇 %s founded the vampire coven %s." % [founder.first_name, name]
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_COVEN_FOUNDED, {
		"npc_id": founder.id,
		"text": txt
	})

	return { "text": txt}

func join_coven(npc: Person, coven_id: String) -> Dictionary:
	if npc == null or not npc.vampire_profile.get("is_vampire", false):
		return { "text": "❌ Only vampires can join covens."}
	if not covens.has(coven_id):
		return { "text": "❌ That coven does not exist."}

	if npc.id not in covens [coven_id] ["members"]:
		covens [coven_id] ["members"].append(npc.id)

	npc.vampire_profile ["coven_id"] = coven_id

	var txt = "🦇 %s joined the coven %s." % [npc.first_name, covens [coven_id] ["name"]]
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_COVEN_JOINED, {
		"npc_id": npc.id,
		"text": txt
	})

	return { "text": txt}

func _found_hunter_reactive_coven():
	var candidates:= []
	for npc in gs.npcs:
		if npc.alive and npc.vampire_profile.get("is_vampire", false):
			if npc.vampire_profile.get("coven_id", "") == "":
				candidates.append(npc)

	if candidates.is_empty():
		return

	var founder = candidates [randi() % candidates.size()]
	found_coven(founder, "%s Covenant" % founder.last_name)