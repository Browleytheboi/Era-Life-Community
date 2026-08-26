extends Resource
class_name VampireOriginEngine

var gs

func _init(_gs):
	gs = _gs
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"reason": "missing_actor",
			"popup_title": "Vampire Request",
			"popup_text": "No living perspective could make this request.",
			"popup_footer": "Nothing was changed."
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"action",
				""
			)
		)
	).strip_edges().to_lower()

	match action_id:
		"ask_to_be_turned":
			if bool(
				actor.vampire_profile.get(
					"is_vampire",
					false
				)
			):
				return {
					"success": false,
					"reason": "actor_already_vampire",
					"text": "I am already a vampire.",
					"popup_title": "Already Turned",
					"popup_text": "You are already a vampire.",
					"popup_footer": "No turning request was necessary."
				}

			var target_id: int = int(
				payload.get(
					"target_id",
					-1
				)
			)

			if target_id > 0:
				var target: Person = null

				if gs.has_method(
					"get_npc_by_id"
				):
					target = gs.get_npc_by_id(
						target_id
					)

				if target == null:
					return {
						"success": false,
						"reason": "vampire_target_missing",
						"popup_title": "Vampire Unavailable",
						"popup_text": (
							"That vampire is no longer observable."
						),
						"popup_footer": "Choose another vampire."
					}

				return ask_to_be_turned(
					actor,
					target
				)

			var choices: Array = []

			for raw_npc in gs.npcs:
				if not (
					raw_npc is Person
				):
					continue

				var vampire: Person = raw_npc as Person

				if (
					vampire == null
					or not bool(vampire.alive)
					or int(vampire.id) == int(actor.id)
					or not bool(
						vampire.vampire_profile.get(
							"is_vampire",
							false
						)
					)
				):
					continue

				var vampire_name: String = (
					(
						str(vampire.first_name)
						+ " "
						+ str(vampire.last_name)
					).strip_edges()
				)
				var blood_potency: int = int(
					vampire.vampire_profile.get(
						"blood_potency",
						0
					)
				)
				var affection: int = int(
					vampire.affection.get(
						actor.id,
						50
					)
				)

				choices.append(
					{
						"id": (
							"ask_to_be_turned:%d"
							% int(vampire.id)
						),
						"label": vampire_name,
						"text": vampire_name,
						"preview_lines": [
							"Blood potency: %d" % blood_potency,
							"Current bond: %d" % affection,
							(
								"Ask %s to make you part "
								+ "of their bloodline."
							) % vampire_name
						],
						"detail_action": "engine_call",
						"engine_property": (
							"vampire_origin_engine"
						),
						"method": "resolve_intent",
						"authority_prevalidated": true,
						"payload": {
							"action_id": "ask_to_be_turned",
							"target_id": int(vampire.id),
							"source": (
								"vampire_origin_engine."
								+ "candidate_browser"
							)
						}
					}
				)

				if choices.size() >= 24:
					break

			if choices.is_empty():
				return {
					"success": false,
					"reason": "no_observable_vampire_candidates",
					"popup_title": "No Vampires Nearby",
					"popup_text": (
						"No living vampire is currently available "
						+ "to receive your request."
					),
					"popup_footer": (
						"The candidate surface will change "
						+ "as reality changes."
					)
				}

			return {
				"success": true,
				"type": "vampire_turn_request_browser",
				"text": "I searched for a vampire willing to turn me.",
				"popup_title": "WHO WILL TURN YOU?",
				"popup_text": (
					"Choose a vampire and ask to enter "
					+ "their bloodline."
				),
				"popup_footer": (
					"Each vampire decides according to bond "
					+ "and blood potency."
				),
				"choices": choices,
				"fullscreen_popup": true,
				"popup_surface_mode": "candidate_browser",
				"candidate_count": choices.size(),
				"ui_is_renderer_only": true
			}

		_:
			return {
				"success": false,
				"reason": "unknown_vampire_origin_intent",
				"popup_title": "Vampire Action Unavailable",
				"popup_text": (
					"No vampire-origin contract is registered "
					+ "for %s."
				) % action_id,
				"popup_footer": "Nothing was changed."
			}
func ask_to_be_turned(
	actor: Person,
	target: Person
) -> Dictionary:
	if (
		actor == null
		or not bool(actor.alive)
	):
		return {
			"success": false,
			"reason": "missing_requesting_actor",
			"text": "Nobody could make the request.",
			"popup_title": "Vampire Request",
			"popup_text": "No living actor could make this request.",
			"popup_footer": "Nothing was changed."
		}

	if (
		target == null
		or not bool(target.alive)
	):
		return {
			"success": false,
			"reason": "vampire_target_unavailable",
			"text": "Nobody is there to turn me.",
			"popup_title": "Vampire Unavailable",
			"popup_text": "That vampire is no longer available.",
			"popup_footer": "Choose another vampire."
		}

	if not bool(
		target.vampire_profile.get(
			"is_vampire",
			false
		)
	):
		return {
			"success": false,
			"reason": "target_not_vampire",
			"text": "They are not a vampire.",
			"popup_title": "Not A Vampire",
			"popup_text": (
				"%s cannot turn you because they are not a vampire."
				% str(target.first_name)
			),
			"popup_footer": "Choose a vampire."
		}

	if bool(
		actor.vampire_profile.get(
			"is_vampire",
			false
		)
	):
		return {
			"success": false,
			"reason": "actor_already_vampire",
			"text": "I am already a vampire.",
			"popup_title": "Already Turned",
			"popup_text": "You are already a vampire.",
			"popup_footer": "No request was necessary."
		}

	var affection: int = int(
		target.affection.get(
			actor.id,
			50
		)
	)
	var blood_potency: int = int(
		target.vampire_profile.get(
			"blood_potency",
			0
		)
	)
	var chance: int = clampi(
		20
		+ int(float(affection) / 2.0)
		+ int(float(blood_potency) / 5.0),
		5,
		90
	)
	var target_name: String = (
		(
			str(target.first_name)
			+ " "
			+ str(target.last_name)
		).strip_edges()
	)

	if randi() % 100 >= chance:
		return {
			"success": false,
			"reason": "turning_request_refused",
			"text": (
				"%s refused to turn me."
				% target_name
			),
			"popup_title": "REQUEST REFUSED",
			"popup_text": (
				"%s listened to your request—but refused "
				+ "to bring you into their bloodline."
			) % target_name,
			"popup_footer": (
				"Bond: %d • Acceptance chance: %d%%"
				% [
					affection,
					chance
				]
			)
		}

	var result: Dictionary = turn_target(
		target,
		actor
	)

	if not result.has(
		"success"
	):
		result ["success"] = true

	result ["popup_title"] = str(
		result.get(
			"popup_title",
			"THE EMBRACE"
		)
	)
	result ["popup_text"] = str(
		result.get(
			"popup_text",
			(
				"%s accepted your request and brought "
				+ "you into their bloodline."
			) % target_name
		)
	)
	result ["popup_footer"] = str(
		result.get(
			"popup_footer",
			(
				"Blood potency: %d • Maker bond established."
				% blood_potency
			)
		)
	)

	return result
func turn_target(maker: Person, target: Person) -> Dictionary:
	if maker == null or target == null:
		return { "text": "❌ Invalid turning."}

	if not maker.vampire_profile.get("is_vampire", false):
		return { "text": "❌ Only vampires can turn others."}

	if target.vampire_profile.get("is_vampire", false):
		return { "text": "❌ They are already a vampire."}

	var vp = target.vampire_profile
	vp ["is_vampire"] = true
	vp ["vampire_stage"] = "fledgling"
	vp ["maker_id"] = maker.id
	vp ["bloodline_name"] = maker.last_name if maker.last_name != "" else maker.first_name
	vp ["thirst"] = 35
	vp ["humanity"] = 85
	vp ["masquerade_heat"] = 0
	vp ["sun_resistance"] = 0
	vp ["blood_potency"] = max(10, int(maker.vampire_profile.get("blood_potency", 20) / 2))
	vp ["generation_depth"] = int(maker.vampire_profile.get("generation_depth", 0)) + 1
	vp ["turned_year"] = gs.year
	vp ["last_feed_year"] = gs.year
	vp ["maker_bond_strength"] = 50
	vp ["fed_this_year"] = false
	target.vampire_profile = vp

	if "Immortal" not in target.traits:
		target.traits.append("Immortal")
	if "Vampire" not in target.traits:
		target.traits.append("Vampire")

	var txt = "🩸 %s %s was turned into a vampire by %s %s." % [
		target.first_name, target.last_name,
		maker.first_name, maker.last_name
	]

	gs.event_bus.emit(ActionEventTypes.VAMPIRE_TURNED, {
		"npc_id": target.id,
		"target_id": maker.id,
		"text": txt
	})

	return { "text": txt}