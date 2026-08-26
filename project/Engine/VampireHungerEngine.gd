extends Resource
class_name VampireHungerEngine

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
		vp ["fed_this_year"] = false
		vp ["thirst"] = clamp(int(vp.get("thirst", 0)) + 18, 0, 100)

		if int(vp ["thirst"]) >= 80:
			vp ["humanity"] = clamp(int(vp.get("humanity", 100)) - 8, 0, 100)

		if int(vp ["thirst"]) >= 95:
			_trigger_frenzy(npc)

		npc.vampire_profile = vp

func feed(vampire: Person, target: Person, feed_type:= "hunt") -> Dictionary:
	if vampire == null or target == null:
		return { "text": "❌ Invalid feed."}

	if not vampire.vampire_profile.get("is_vampire", false):
		return { "text": "❌ I am not a vampire."}

	if not target.alive:
		return { "text": "❌ Dead blood won't help enough."}

	var vp = vampire.vampire_profile
	vp ["thirst"] = max(0, int(vp.get("thirst", 0)) - 45)
	vp ["last_feed_year"] = gs.year
	vp ["fed_this_year"] = true

	target.health -= randf_range(8.0, 25.0)

	if feed_type == "consensual":
		vp ["humanity"] = clamp(int(vp.get("humanity", 100)) + 1, 0, 100)
	else:
		vp ["humanity"] = clamp(int(vp.get("humanity", 100)) - 4, 0, 100)
		vp ["masquerade_heat"] = clamp(int(vp.get("masquerade_heat", 0)) + 6, 0, 100)

	if target.health <= 0:
		gs.health_engine.try_kill(target, "Drained by vampire", true)

	vampire.vampire_profile = vp

	var txt = "🩸 %s fed on %s." % [vampire.first_name, target.first_name]
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_FED, {
		"npc_id": vampire.id,
		"target_id": target.id,
		"text": txt,
		"feed_type": feed_type
	})

	return { "text": txt}

func use_blood_bag(vampire: Person) -> Dictionary:
	if vampire == null or not vampire.vampire_profile.get("is_vampire", false):
		return { "text": "❌ I am not a vampire."}

	var vp = vampire.vampire_profile
	vp ["thirst"] = max(0, int(vp.get("thirst", 0)) - 20)
	vp ["humanity"] = clamp(int(vp.get("humanity", 100)) - 1, 0, 100)
	vampire.vampire_profile = vp

	return { "text": "🩸 I used stored blood to steady my hunger."}

func _trigger_frenzy(npc: Person):
	var vp = npc.vampire_profile
	vp ["masquerade_heat"] = clamp(int(vp.get("masquerade_heat", 0)) + 20, 0, 100)
	npc.vampire_profile = vp

	var txt = "🦇 %s %s lost control in a blood frenzy." % [npc.first_name, npc.last_name]
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_FRENZY, {
		"npc_id": npc.id,
		"text": txt
	})