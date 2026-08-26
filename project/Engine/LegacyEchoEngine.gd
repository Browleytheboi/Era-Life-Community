extends RefCounted
class_name LegacyEchoEngine

var gs
var echo_registry: Dictionary = {}

func _init(game_state):
	gs = game_state




func capture_player_life_echo(_payload):
	if gs.player == null:
		return

	var important:= []

	important += gs.player.parents
	important += gs.player.children
	important += gs.player.friends

	if gs.player.partner != null:
		important.append(gs.player.partner.id)

	for id in important:
		_record_echo_candidate(id)

func _record_echo_candidate(npc_id: int):
	if npc_id <= 0:
		return

	var facts = gs.get_npc_facts_by_id(npc_id)
	if facts.is_empty():
		return

	echo_registry [npc_id] = {
		"npc_id": npc_id,
		"first_seen_year": gs.year,
		"importance": _compute_importance(facts),
		"dynasty": facts.get("last_name", ""),
		"facts": facts
	}

func _compute_importance(facts: Dictionary) -> float:
	var score:= 1.0

	score += facts.get("fame", 0) * 0.1
	score += facts.get("dynasty_prestige", 0) * 0.05

	if facts.get("is_ruler", false):
		score += 5

	if facts.get("is_royal", false):
		score += 3

	return score




func yearly_echo_evaluation(_payload):

	if echo_registry.is_empty():
		return

	if randi() % 100 > 10:
		return

	var keys = echo_registry.keys()
	var id = keys [randi() % keys.size()]
	trigger_echo_encounter(id)




func trigger_echo_encounter(npc_id: int):

	var npc = gs.get_or_reactivate_npc_by_id(npc_id)

	if npc == null:
		return

	var text = "%s %s suddenly reappeared in your life." % [npc.first_name, npc.last_name]

	gs.push_world_feed(text, {
		"npc_id": npc.id,
		"category": "legacy_echo",
		"personally_relevant": true
	})