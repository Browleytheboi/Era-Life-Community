extends Resource
class_name VampireHunterEngine

var gs
var hunter_orders:= {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}):
	if gs == null or not gs.is_feature_enabled("vampires"):
		return
	_maybe_found_order()
	_maybe_attack_exposed_vampires()

func _maybe_found_order():
	if randi() % 300 != 0:
		return

	var id = "hunters_%d" % gs.year
	var name = ""

	match gs.era.name:
		"Ancient Era":
			name = "Order of the Sun Spear"
		"Medieval Era":
			name = "Ashen Inquisition"
		"Industrial Era":
			name = "Midnight Rail Society"
		"Modern Era":
			name = "Night Crimes Task Force"
		"Future Era":
			name = "Helios Genome Division"
		_:
			name = "Vampire Hunter Order"

	hunter_orders [id] = {
		"id": id,
		"name": name,
		"founded_year": gs.year,
		"threat": randi_range(20, 50)
	}

	var txt = "⚔️ A vampire hunter order was founded: %s." % name
	gs.event_bus.emit(ActionEventTypes.VAMPIRE_HUNTER_ORDER_FOUNDED, {
		"npc_id": -1,
		"text": txt
	})

func _maybe_attack_exposed_vampires():
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.vampire_profile.get("is_vampire", false):
			continue

		var heat = int(npc.vampire_profile.get("masquerade_heat", 0))
		if heat < 50:
			continue

		if randi() % 100 < clamp(int(float(heat) / 2.0), 10, 70):
			npc.health -= randf_range(10.0, 40.0)

			var txt = "⚔️ Vampire hunters attacked %s %s." % [npc.first_name, npc.last_name]
			gs.event_bus.emit(ActionEventTypes.VAMPIRE_HUNTER_ATTACK, {
				"npc_id": npc.id,
				"text": txt
			})

			if npc.health <= 0:
				gs.health_engine.try_kill(npc, "Killed by vampire hunters", true)

func hunt_target(hunter: Person, target: Person) -> Dictionary:
	if hunter == null or target == null:
		return { "text": "❌ Invalid hunt."}

	if not target.vampire_profile.get("is_vampire", false):
		return { "text": "❌ They are not a vampire."}

	target.health -= randf_range(10.0, 35.0)

	if target.health <= 0:
		gs.health_engine.try_kill(target, "Killed by vampire hunter", true)
		return { "text": "⚔️ I slew %s." % target.first_name}

	return { "text": "⚔️ I hunted %s, but they survived." % target.first_name}