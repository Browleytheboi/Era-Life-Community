extends Resource
class_name VampireAbilityEngine

var gs

func _init(_gs):
	gs = _gs

func glamour_target(vampire: Person, target: Person) -> Dictionary:
	if vampire == null or target == null:
		return { "text": "❌ Invalid glamour."}
	if not vampire.vampire_profile.get("is_vampire", false):
		return { "text": "❌ I am not a vampire."}

	target.affection [vampire.id] = clamp(target.affection.get(vampire.id, 50) + 15, 0, 100)

	var txt = "🕯️ I glamoured %s into trusting me more." % target.first_name
	gs.narrative_engine.log_event(vampire, { "type": "text", "text": txt})
	return { "text": txt}

func blood_bond_target(vampire: Person, target: Person) -> Dictionary:
	if vampire == null or target == null:
		return { "text": "❌ Invalid bond."}
	if not vampire.vampire_profile.get("is_vampire", false):
		return { "text": "❌ I am not a vampire."}

	var known = target.vampire_profile.get("known_by_ids", [])
	if vampire.id not in known:
		known.append(vampire.id)
	target.vampire_profile ["known_by_ids"] = known

	var txt = "🩸 %s formed a blood bond with %s." % [vampire.first_name, target.first_name]

	gs.event_bus.emit(ActionEventTypes.VAMPIRE_BLOOD_BOND, {
		"npc_id": vampire.id,
		"target_id": target.id,
		"text": txt
	})

	return { "text": txt}