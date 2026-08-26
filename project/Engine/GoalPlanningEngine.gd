extends Resource
class_name GoalPlanningEngine

var gs

func _init(_gs):
	gs = _gs






var GOAL_POOL = [
	"BecomeRuler",
	"BecomeWealthy",
	"BecomeFamous",
	"BecomeBendingMaster",
	"HaveFiveChildren",
	"CollectArtifacts",
	"DestroyRivalDynasty"
]






func ensure_goals(npc):

	if npc.long_term_goals.size() > 0:
		return

	var pick = GOAL_POOL [randi() % GOAL_POOL.size()]

	var goal = {
		"type": pick,
		"progress": 0,
		"target": _goal_target(pick),
		"priority": randi_range(40, 100)
	}

	npc.long_term_goals.append(goal)
	npc.strategic_focus = pick







func _goal_target(goal):

	match goal:

		"BecomeRuler":
			return 1

		"BecomeWealthy":
			return 1000000

		"BecomeFamous":
			return 80

		"BecomeBendingMaster":
			return 3

		"HaveFiveChildren":
			return 5

		"CollectArtifacts":
			return 3

		"DestroyRivalDynasty":
			return 1

	return 1







func yearly_update(npc):

	if not npc.alive:
		return

	ensure_goals(npc)

	var completed:= []

	for goal in npc.long_term_goals:

		match goal.get("type", ""):

			"BecomeWealthy":
				goal ["progress"] = npc.bank_balance

			"BecomeFamous":
				goal ["progress"] = npc.fame

			"HaveFiveChildren":
				goal ["progress"] = npc.children.size()

			"BecomeBendingMaster":
				goal ["progress"] = npc.bending_mastery.get(npc.bending_type, 0)

			"CollectArtifacts":
				goal ["progress"] = 0
				if gs.artifacts_engine.ownership.has(npc.id):
					goal ["progress"] = gs.artifacts_engine.ownership [npc.id].size()

			"BecomeRuler":
				goal ["progress"] = 1 if npc.is_ruler else 0

		if int(goal.get("progress", 0)) >= int(goal.get("target", 1)):
			completed.append(goal)

	for goal in completed:
		_goal_completed(npc, goal)







func _goal_completed(npc, goal):

	gs.world_feed.append(
		"🎯 %s %s achieved their life goal: %s." %
		[npc.first_name, npc.last_name, goal.get("type", "UnknownGoal")]
	)

	npc.long_term_goals.erase(goal)


	ensure_goals(npc)
func get_primary_goal(npc: Person) -> Dictionary:
	if npc.long_term_goals.size() == 0:
		ensure_goals(npc)
	if npc.long_term_goals.size() == 0:
		return {}
	return npc.long_term_goals [0]

func get_goal_focus_capabilities(goal_type: String) -> Array:
	match goal_type:
		"BecomeRuler":
			return ["Leadership", "Conversation", "RuleRealm"]
		"BecomeWealthy":
			return ["Management", "Crafting", "Robbery"]
		"BecomeFamous":
			return ["Leadership", "Conversation", "Flirting"]
		"BecomeBendingMaster":
			return ["FireBlast", "WaterWhip", "AirStrike", "EarthCrush", "TeachBending"]
		"HaveFiveChildren":
			return ["Conversation", "Flirting"]
		"CollectArtifacts":
			return ["Conversation", "Leadership"]
		"DestroyRivalDynasty":
			return ["Leadership", "Assassination", "Robbery"]
	return []