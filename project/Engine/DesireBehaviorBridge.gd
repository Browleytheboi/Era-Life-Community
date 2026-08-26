extends Resource
class_name DesireBehaviorBridge

var gs

func _init(_gs):
	gs = _gs





func process_npc(npc: Person):

	if not npc.alive:
		return


	_handle_core(npc)


	_handle_active(npc)


	_handle_impulses(npc)

	_handle_goal_directives(npc)

func _handle_goal_directives(npc: Person):
	var goal = gs.goal_planning_engine.get_primary_goal(npc)
	if goal == {}:
		return

	match goal.get("type", ""):
		"BecomeWealthy":
			if npc.bank_balance > 50000 and randi() % 300 == 0:
				gs.property_engine.buy_property(npc, "Small", randi_range(20000, 120000))

		"BecomeFamous":
			if randi() % 300 == 0:
				gs.fame_engine.give_fame(npc, 3)

		"BecomeRuler":
			if npc.fame > 40 and npc.smarts > 60 and randi() % 500 == 0:
				npc.capabilities.nodes ["RuleRealm"] = max(
					npc.capabilities.nodes.get("RuleRealm", 0), 1
				)

		"BecomeBendingMaster":
			if npc.bending_type != "none" and randi() % 250 == 0:
				gs.bending_engine.train_element(npc, npc.bending_type)




func _handle_core(npc):


	if "love" in npc.desires.core:
		_seek_partner(npc)

	if "power" in npc.desires.core:
		if randi() % 500 == 0:
			gs.fame_engine.give_fame(npc, 5)

	if "security" in npc.desires.core:
		if npc.bank_balance > 50000 and randi() % 400 == 0:
			gs.property_engine.buy_property(npc, "Small", randi_range(20000, 120000))






func _handle_active(npc):

	if "career_growth" in npc.desires.active:
		if randi() % 200 == 0:
			gs.career_engine.assign_job(npc)

	if "have_child" in npc.desires.active:
		var partner = gs.get_valid_partner(npc, true)
		if partner != null and npc.age > 20 and npc.age < 45:
			if randi() % 150 == 0:
				gs.spawn_child(npc, partner, true)

	if "fame" in npc.desires.active:
		if randi() % 250 == 0:
			gs.fame_engine.give_fame(npc, randi_range(5, 15))






func _handle_impulses(npc):

	if "jealous_spike" in npc.desires.impulses:
		var partner = gs.get_valid_partner(npc, true)
		if partner != null and randi() % 120 == 0:
			gs.end_partnership(npc, false)

	if "crime_urge" in npc.desires.impulses:
		if randi() % 180 == 0:
			gs.crime_engine.commit_crime("Mug a Stranger", "Knife")

	if "escape" in npc.desires.impulses:
		if randi() % 200 == 0:
			gs.world_engine.process_movement()






func _seek_partner(npc):
	if gs.get_valid_partner(npc, true) != null:
		return
	if randi() % 250 != 0:
		return

	var singles:= []
	for other in gs.npcs:
		if other == npc:
			continue
		if other.partner == null and other.age >= 18 and other.alive:
			singles.append(other)

	if singles.size() == 0:
		return

	var connected_ids = gs.social_graph_engine.get_connections(npc.id)
	var preferred:= []
	for other_id in connected_ids:
		var other = gs.get_npc_by_id(other_id)
		if other == null:
			continue
		if other == npc:
			continue
		if not other.alive:
			continue
		if other.partner != null:
			continue
		if other.age < 18:
			continue
		preferred.append(other)

	var candidate_pool: Array = preferred if preferred.size() > 0 else singles
	var best_score: float = -999999.0
	var best_candidates: Array = []

	for raw_candidate in candidate_pool:
		var candidate: Person = raw_candidate
		var score: float = _score_partner_candidate_for_npc(npc, candidate)
		if score > best_score:
			best_score = score
			best_candidates = [candidate]
		elif is_equal_approx(score, best_score):
			best_candidates.append(candidate)

	if best_candidates.is_empty():
		return

	var pick: Person = best_candidates [randi() % best_candidates.size()]
	npc.partner = pick
	pick.partner = npc
	npc.marital_status = "Partnered"
	pick.marital_status = "Partnered"

	gs.event_bus.emit(ActionEventTypes.NPC_PARTNERED, {
		"npc_id": npc.id,
		"target_id": pick.id,
		"text": "%s partnered with %s." % [npc.first_name, pick.first_name]
	})

	gs.social_graph_engine.connect_people(npc.id, pick.id)
	gs.narrative_engine.log_event(npc, {
		"type": "text",
		"text": "%s partnered with %s." % [npc.first_name, pick.first_name]
	})
func _score_partner_candidate_for_npc(seeker: Person, candidate: Person) -> float:
	var score: float = 0.0

	if seeker == null or candidate == null:
		return score

	if gs.social_graph_engine != null:
		var connected_ids = gs.social_graph_engine.get_connections(seeker.id)
		if candidate.id in connected_ids:
			score += 8.0

	if gs.scenario_engine != null:
		var candidate_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(candidate.id)
		var asset_pressure: Dictionary = candidate_bias.get("asset_pressure", {})
		var asset_status_signals: Dictionary = candidate_bias.get("asset_status_signals", {})
		var asset_pressure_profile: Dictionary = candidate_bias.get("asset_pressure_profile", {})
		var asset_namespaces: Dictionary = candidate_bias.get("asset_namespaces", {})
		var asset_portfolio_tags: Dictionary = candidate_bias.get("asset_portfolio_tags", {})

		score += float(asset_status_signals.get("romance_signal", 0.0)) * 1.75
		score += float(asset_pressure_profile.get("spectacle", 0.0)) * 1.25
		score += float(asset_pressure.get("max_asset_tier_score", 0.0)) * 0.75
		score += float(asset_pressure.get("asset_uniqueness_score", 0.0)) * 0.65

		if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
			score += 10.0
		if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
			score += 8.0
		if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
			score += 6.0
		if int(asset_portfolio_tags.get("portfolio_mood.old_blood", 0)) > 0:
			score += 4.0

	score += randf() * 2.0
	return score