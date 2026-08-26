extends Resource
class_name AIEventGenerator

var gs

func _init(_gs):
	gs = _gs





func generate_events(person: Person) -> Array:
	var out:= []
	var personal_roll: int = 60
	var social_roll: int = 35
	var world_roll: int = 25

	if gs != null and gs.scenario_engine != null and person != null:
		var scenario_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(person.id)
		var desire_bias: Dictionary = scenario_bias.get("desire_bias", {})
		var relationship_bias: Dictionary = scenario_bias.get("relationship_bias", {})
		var reputation_bias: Dictionary = scenario_bias.get("reputation_bias", {})
		var crime_pressure: Dictionary = scenario_bias.get("crime_pressure", {})
		var school_pressure: Dictionary = scenario_bias.get("school_pressure", {})
		var asset_pressure: Dictionary = scenario_bias.get("asset_pressure", {})
		var asset_status_signals: Dictionary = scenario_bias.get("asset_status_signals", {})
		var asset_pressure_profile: Dictionary = scenario_bias.get("asset_pressure_profile", {})
		var asset_portfolio_tags: Dictionary = scenario_bias.get("asset_portfolio_tags", {})
		var asset_namespaces: Dictionary = scenario_bias.get("asset_namespaces", {})

		personal_roll += int(round(float(desire_bias.get("self_reflection_weight", 0.0))))
		social_roll += int(round(float(relationship_bias.get("social_visibility", 0.0))))
		social_roll += int(round(float(school_pressure.get("peer_tension", 0.0)) * 0.35))
		world_roll += int(round(float(reputation_bias.get("public_attention", 0.0))))
		world_roll += int(round(float(crime_pressure.get("rumor_heat", 0.0)) * 0.5))

		social_roll += int(round(float(asset_status_signals.get("romance_signal", 0.0)) * 0.45))
		social_roll += int(round(float(asset_pressure_profile.get("spectacle", 0.0)) * 0.35))
		social_roll += int(round(float(asset_pressure.get("max_asset_tier_score", 0.0)) * 0.25))

		world_roll += int(round(float(asset_status_signals.get("public_attention", 0.0)) * 0.55))
		world_roll += int(round(float(asset_pressure_profile.get("criminal_usefulness", 0.0)) * 0.45))
		world_roll += int(round(float(asset_pressure.get("asset_uniqueness_score", 0.0)) * 0.35))

		if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
			world_roll += 12
		if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
			world_roll += 9
		if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
			social_roll += 10
			world_roll += 10
		if int(asset_portfolio_tags.get("portfolio_mood.old_blood", 0)) > 0:
			social_roll += 6

	personal_roll = clamp(personal_roll, 5, 95)
	social_roll = clamp(social_roll, 5, 95)
	world_roll = clamp(world_roll, 5, 95)

	if randi() % 100 < personal_roll:
		out.append(_personal_event(person))
	if randi() % 100 < social_roll:
		out.append(_social_event(person))
	if randi() % 100 < world_roll:
		out.append(_world_reaction_event(person))

	return out.filter(func (e): return e != null)

func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out

	out.append({
		"id": "ai_general_restless_year",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.05,
			"enhanced": 1.0,
			"chaos": 0.95
		},
		"tone": "reflective",
		"rarity": 0.35,
		"cooldown_key": "general:restless_year",
		"cooldown_years": 2,
		"priority": 10,
		"min_age": 12,
		"max_age": 130,
		"prompt": "I can feel a strange pressure building around my life this year. What do I lean into?",
		"followup_hooks": ["general.inner_pressure"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "self_improve",
				"label": "Channel it into discipline and self-improvement.",
				"journal_line": "I chose to channel the pressure into discipline and self-improvement.",
				"followup_hooks": ["general.inner_pressure.discipline"],
				"bias_payloads": {
					"desire_bias": {
						"self_reflection_weight": 12.0
					},
					"health_bias": {
						"stress_delta": -3.0
					},
					"reputation_bias": {
						"public_attention": 2.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "socialize",
				"label": "Get around people and let life get messy.",
				"journal_line": "I chose to get around people and let life get a little messy.",
				"followup_hooks": ["general.inner_pressure.social"],
				"bias_payloads": {
					"relationship_bias": {
						"social_visibility": 10.0
					},
					"school_pressure": {
						"peer_tension": 4.0
					},
					"reputation_bias": {
						"public_attention": 6.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})

	return out





func _personal_event(p):

	var lines = []

	lines.append("I felt a strange sense that my life was moving toward something.")

	if p.fate_arc == "Chosen":
		lines.append("I sensed that something important was waiting for me.")
	if p.bending_type != "none":
		lines.append("I practiced my %s bending." % p.bending_type)
	if p.social_class in ["Noble", "Royal"]:
		lines.append("I became more aware of the expectations placed on me.")

	if "Impulsive" in p.traits:
		lines.append("I made a reckless decision that I couldn't explain.")

	if "Calm" in p.traits:
		lines.append("I handled a tense situation better than expected.")

	return { "type": "text", "text": lines.pick_random()}





func _social_event(p):
	if gs != null and gs.scenario_engine != null and p != null:
		var scenario_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(p.id)
		var asset_namespaces: Dictionary = scenario_bias.get("asset_namespaces", {})
		var asset_status_signals: Dictionary = scenario_bias.get("asset_status_signals", {})
		var asset_pressure_profile: Dictionary = scenario_bias.get("asset_pressure_profile", {})

		if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
			return { "type": "text", "text": "People started reacting to my presence like I was carrying more than just style."}
		if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
			return { "type": "text", "text": "Conversations around me felt careful, like people were measuring how close they wanted to stand to power."}
		if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
			return { "type": "text", "text": "A few people approached me with the kind of curiosity that never feels innocent around rare objects."}
		if float(asset_pressure_profile.get("romance_signal", 0.0)) >= 3.0:
			return { "type": "text", "text": "Interest around me sharpened in a way that felt tied to what I represented, not just who I was."}
		if float(asset_status_signals.get("dynastic_legitimacy", 0.0)) >= 3.0:
			return { "type": "text", "text": "People treated me like my place in the room came with inherited weight."}

	if p.fame > 40:
		return { "type": "text", "text": "Strangers began recognizing me more often."}
	if p.partner != null:
		return { "type": "text", "text": "My relationship shifted in subtle ways."}
	if p.friends.size() > 0:
		return { "type": "text", "text": "A friend confided something unexpected in me."}
	return null





func _world_reaction_event(_p):
	if gs == null:
		return null

	if _p != null and gs.scenario_engine != null:
		var scenario_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(_p.id)
		var asset_namespaces: Dictionary = scenario_bias.get("asset_namespaces", {})
		var asset_pressure_profile: Dictionary = scenario_bias.get("asset_pressure_profile", {})
		var asset_portfolio_tags: Dictionary = scenario_bias.get("asset_portfolio_tags", {})

		if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
			return { "type": "text", "text": "People told stories about the kind of power that distorts how everyone else behaves around it."}
		if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
			return { "type": "text", "text": "Rumors kept circling that collectors, believers, and opportunists were quietly tracking rare objects again."}
		if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
			return { "type": "text", "text": "A strange mythic buzz followed me this year, like ownership itself had become part of local folklore."}
		if float(asset_pressure_profile.get("criminal_usefulness", 0.0)) >= 2.5:
			return { "type": "text", "text": "Shadier people seemed to notice the practical value of what I owned before decent people did."}
		if int(asset_portfolio_tags.get("portfolio_mood.old_blood", 0)) > 0:
			return { "type": "text", "text": "People started behaving like inheritance, ceremony, and social order mattered more around me than before."}

	var era = gs.era.name
	var pools = {
		"Ancient Era": [
			"Rumors spread through the settlement about unseen forces.",
			"Merchants spoke of distant wars."
		],
		"Medieval Era": [
			"Whispers of unrest traveled between villages.",
			"Travelers carried strange stories from afar."
		],
		"Industrial Era": [
			"New machines changed how people lived.",
			"The city felt louder than before."
		],
		"Modern Era": [
			"Everything seemed to move faster this year.",
			"Online conversations shifted public opinion."
		],
		"Future Era": [
			"Systems updated around me without explanation.",
			"People debated whether technology had gone too far."
		]
	}
	var arr = pools.get(era, [])
	if arr.size() == 0:
		return null
	return { "type": "text", "text": arr.pick_random()}