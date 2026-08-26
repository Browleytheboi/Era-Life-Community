extends Resource
class_name CapabilityGraphEngine

var gs

func _init(_gs):
	gs = _gs






var CAPABILITIES = {


	"Punch": { "tier": 0},
	"WeaponUse": { "tier": 1},


	"Pickpocket": { "tier": 0},
	"Robbery": { "tier": 1},
	"Assassination": { "tier": 2},


	"Conversation": { "tier": 0},
	"Flirting": { "tier": 1},
	"Leadership": { "tier": 2},


	"Labor": { "tier": 0},
	"Crafting": { "tier": 1},
	"Management": { "tier": 2},


	"FireBlast": { "tier": 2},
	"WaterWhip": { "tier": 2},
	"AirStrike": { "tier": 2},
	"EarthCrush": { "tier": 2},


	"TeachBending": { "tier": 3},
	"RuleRealm": { "tier": 4}
}







func initialize_npc(npc: Person):

	if npc.capabilities.nodes.size() > 0:
		return


	npc.capabilities.nodes ["Punch"] = 1
	npc.capabilities.nodes ["Conversation"] = 1


	if npc.smarts > 70:
		npc.capabilities.nodes ["Management"] = 1


	if "Athletic" in npc.traits:
		npc.capabilities.nodes ["Punch"] = 2


	if npc.bending_type != "none":
		match npc.bending_type:
			"fire":
				npc.capabilities.nodes ["FireBlast"] = 1
			"water":
				npc.capabilities.nodes ["WaterWhip"] = 1
			"earth":
				npc.capabilities.nodes ["EarthCrush"] = 1
			"air":
				npc.capabilities.nodes ["AirStrike"] = 1

	if npc.bending_type == "avatar":
		npc.capabilities.nodes ["TeachBending"] = 1







func has_capability(npc: Person, cap: String) -> bool:
	return npc.capabilities.nodes.has(cap)







func level(npc: Person, cap: String) -> int:
	return npc.capabilities.nodes.get(cap, 0)







func improve(npc: Person, cap: String, amount:= 1):

	if not npc.capabilities.nodes.has(cap):
		npc.capabilities.nodes [cap] = 0

	npc.capabilities.nodes [cap] += amount
	npc.capabilities.nodes [cap] = clamp(npc.capabilities.nodes [cap], 0, 10)







func yearly_growth(npc: Person):

	for cap in npc.capabilities.nodes.keys():
		if randi() % 100 < npc.ambition:
			npc.capabilities.nodes [cap] += 1
			npc.capabilities.nodes [cap] = clamp(npc.capabilities.nodes [cap], 0, 10)

	_apply_goal_growth(npc)
func _apply_goal_growth(npc: Person):
	var goal = gs.goal_planning_engine.get_primary_goal(npc)
	if goal == {}:
		return

	var focus_caps = gs.goal_planning_engine.get_goal_focus_capabilities(goal.get("type", ""))
	if focus_caps.size() == 0:
		return

	var support_bonus = _social_support_bonus(npc)

	for cap in focus_caps:
		if not npc.capabilities.nodes.has(cap):
			npc.capabilities.nodes [cap] = 0

		var chance = 20 + int(npc.ambition / 4) + support_bonus
		if randi() % 100 < clamp(chance, 5, 95):
			npc.capabilities.nodes [cap] += 1
			npc.capabilities.nodes [cap] = clamp(npc.capabilities.nodes [cap], 0, 10)
func _social_support_bonus(npc: Person) -> int:
	var strong = gs.social_graph_engine.strongest_connections(npc.id, 3)
	var bonus:= 0

	for other_id in strong:
		var weight = gs.social_graph_engine.relationship_strength(npc.id, other_id)
		if weight >= 70:
			bonus += 5
		elif weight >= 50:
			bonus += 2

	return bonus



func refresh_bending_capabilities(npc: Person):

	if npc == null:
		return

	if npc.capabilities == null:
		npc.capabilities = {
			"nodes": {},
			"edges": {}
		}

	if not npc.capabilities.has("nodes") or npc.capabilities ["nodes"] == null:
		npc.capabilities ["nodes"] = {}


	for cap in ["FireBlast", "WaterWhip", "AirStrike", "EarthCrush", "TeachBending"]:
		npc.capabilities.nodes.erase(cap)

	if npc.bending_type == "none":
		return

	match npc.bending_type:
		"fire":
			npc.capabilities.nodes ["FireBlast"] = max(npc.capabilities.nodes.get("FireBlast", 0), 1)
		"water":
			npc.capabilities.nodes ["WaterWhip"] = max(npc.capabilities.nodes.get("WaterWhip", 0), 1)
		"earth":
			npc.capabilities.nodes ["EarthCrush"] = max(npc.capabilities.nodes.get("EarthCrush", 0), 1)
		"air":
			npc.capabilities.nodes ["AirStrike"] = max(npc.capabilities.nodes.get("AirStrike", 0), 1)
		"avatar":
			npc.capabilities.nodes ["FireBlast"] = max(npc.capabilities.nodes.get("FireBlast", 0), 1)
			npc.capabilities.nodes ["WaterWhip"] = max(npc.capabilities.nodes.get("WaterWhip", 0), 1)
			npc.capabilities.nodes ["EarthCrush"] = max(npc.capabilities.nodes.get("EarthCrush", 0), 1)
			npc.capabilities.nodes ["AirStrike"] = max(npc.capabilities.nodes.get("AirStrike", 0), 1)
			npc.capabilities.nodes ["TeachBending"] = max(npc.capabilities.nodes.get("TeachBending", 0), 1)