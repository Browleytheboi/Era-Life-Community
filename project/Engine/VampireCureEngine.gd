extends Resource
class_name VampireCureEngine

var gs

func _init(_gs):
	gs = _gs

func seek_cure(npc: Person) -> Dictionary:
	if npc == null or not npc.vampire_profile.get("is_vampire", false):
		return { "text": "❌ I am not a vampire."}

	var chance:= 0

	match gs.era.name:
		"Ancient Era":
			chance = 10
		"Medieval Era":
			chance = 15
		"Industrial Era":
			chance = 20
		"Modern Era":
			chance = 28
		"Future Era":
			chance = 40

	if randi() % 100 >= chance:
		return { "text": "❌ I searched for a cure, but found nothing."}

	var vp = npc.vampire_profile
	vp ["is_vampire"] = false
	vp ["is_cured"] = true
	vp ["vampire_stage"] = ""
	vp ["thirst"] = 0
	vp ["masquerade_heat"] = 0
	vp ["coven_id"] = ""
	npc.vampire_profile = vp

	npc.traits.erase("Vampire")
	npc.traits.erase("Immortal")

	var txt = "✨ %s %s was cured of vampirism." % [npc.first_name, npc.last_name]
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_CURED, {
		"npc_id": npc.id,
		"text": txt
	})

	return { "text": txt}