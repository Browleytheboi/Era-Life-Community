extends Resource
class_name VampireMasqueradeEngine

var gs

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}):
	if gs == null or not gs.is_feature_enabled("vampires"):
		return
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.vampire_profile.get("is_vampire", false):
			continue

		var vp = npc.vampire_profile


		vp ["masquerade_heat"] = max(0, int(vp.get("masquerade_heat", 0)) - 3)

		if npc.fame >= 50:
			vp ["masquerade_heat"] = clamp(int(vp.get("masquerade_heat", 0)) + 2, 0, 100)

		npc.vampire_profile = vp

		if int(vp ["masquerade_heat"]) >= 75:
			_expose(npc)

func _expose(npc: Person):
	var txt = "☀️ %s %s was exposed to the world as a vampire." % [npc.first_name, npc.last_name]

	gs.event_bus.emit(ActionEventTypes.VAMPIRE_EXPOSED, {
		"npc_id": npc.id,
		"text": txt
	})

	gs.event_bus.emit(ActionEventTypes.VAMPIRE_MASQUERADE_BREACH, {
		"npc_id": npc.id,
		"text": txt
	})