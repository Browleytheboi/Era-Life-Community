extends Resource
class_name VampireEngine

var gs
var global_state:= {
	"ancient_vampires_awakened": 0,
	"known_coven_count": 0,
	"masquerade_pressure": 0
}

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

		_apply_stage_growth(npc)
		_apply_sun_risk(npc)
		_apply_identity_pressure(npc)

	if randi() % 250 == 0:
		_roll_elder_awakening()

func _apply_stage_growth(npc: Person):
	var vp = npc.vampire_profile
	var years_undead = gs.year - int(vp.get("turned_year", gs.year))

	if years_undead >= 300:
		vp ["vampire_stage"] = "ancient"
	elif years_undead >= 100:
		vp ["vampire_stage"] = "elder"
	elif years_undead >= 20:
		vp ["vampire_stage"] = "mature"
	elif years_undead >= 1:
		vp ["vampire_stage"] = "fledgling"

	vp ["blood_potency"] = clamp(int(vp.get("blood_potency", 0)) + 1, 0, 100)
	npc.vampire_profile = vp

func _apply_sun_risk(npc: Person):
	var vp = npc.vampire_profile
	if bool(vp.get("daywalker", false)):
		return

	var sun_res = int(vp.get("sun_resistance", 0))
	if sun_res >= 100:
		return

	if randi() % 100 < max(2, 15 - int(float(sun_res) / 10.0)):
		npc.health -= randf() * 8.0
		if npc.health <= 0:
			gs.health_engine.try_kill(npc, "Sunlight", true)

func _apply_identity_pressure(npc: Person):
	var vp = npc.vampire_profile


	if npc.fame >= 40 and npc.age >= 30:
		vp ["masquerade_heat"] = clamp(int(vp.get("masquerade_heat", 0)) + 2, 0, 100)

	npc.vampire_profile = vp

func _roll_elder_awakening():
	var candidates:= []
	for npc in gs.npcs:
		if npc.alive and npc.vampire_profile.get("is_vampire", false):
			if npc.vampire_profile.get("vampire_stage", "") in ["elder", "ancient"]:
				candidates.append(npc)

	if candidates.is_empty():
		return

	var chosen = candidates [randi() % candidates.size()]
	var txt = "⚰️ An elder vampire, %s %s, has stirred once more." % [chosen.first_name, chosen.last_name]

	gs.push_world_feed(txt, {
		"npc_id": chosen.id,
		"category": "vampire",
		"event_name": ActionEventTypes.VAMPIRE_ELDER_AWAKENED,
		"source": "vampire_engine"
	})

	gs.event_bus.emit(ActionEventTypes.VAMPIRE_ELDER_AWAKENED, {
		"npc_id": chosen.id,
		"text": txt
	})