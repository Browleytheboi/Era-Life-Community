extends Resource
class_name VampireLegacyEngine

var gs
var bloodlines:= {}
var family_legacy:= {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}):
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.vampire_profile.get("is_vampire", false):
			continue

		var bloodline = str(npc.vampire_profile.get("bloodline_name", ""))
		if bloodline == "":
			continue

		if not bloodlines.has(bloodline):
			bloodlines [bloodline] = {
				"name": bloodline,
				"members": [],
				"founded_year": gs.year,
				"prestige": 10
			}

		if npc.id not in bloodlines [bloodline] ["members"]:
			bloodlines [bloodline] ["members"].append(npc.id)

		bloodlines [bloodline] ["prestige"] += 1