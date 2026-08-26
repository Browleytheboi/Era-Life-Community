extends Resource
class_name HumanRelationshipContractEngine

const ENGINE_SCHEMA:= "eralife.relationship_producer.human_relationship_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func sync_actor_relationship_edges(actor: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null or gs.relationship_graph_contract_engine == null:
		return { "success": false, "reason": "missing_graph_or_actor"}
	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var actor_ref: String = str(actor_entity.get("entity_id", ""))
	var count: int = 0
	for parent_id in actor.parents:
		count += _commit_person_edge(actor, int(parent_id), "parent_child", ["human", "family", "parent"], "Child", "Parent", context)
	for child_id in actor.children:
		count += _commit_person_edge(actor, int(child_id), "parent_child", ["human", "family", "child"], "Parent", "Child", context)
	for friend_id in actor.friends:
		count += _commit_person_edge(actor, int(friend_id), "friend", ["human", "friend", "social"], "Friend", "Friend", context)
	for ex_id in actor.ex_partners:
		count += _commit_person_edge(actor, int(ex_id), "ex_partner", ["human", "ex", "romance"], "Ex", "Ex", context)
	var partner: Person = gs.get_valid_partner(actor, true, true) if gs.has_method("get_valid_partner") else null
	if partner != null:
		count += _commit_pair(actor, partner, "partner", ["human", "partner", "romance"], "Partner", "Partner", context)
	return { "success": true, "actor_entity_id": actor_ref, "edges_synced": count, "producer": ENGINE_SCHEMA}

func ensure_pair_edge(actor: Person, target: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null or target == null:
		return { "success": false, "reason": "missing_actor_or_target"}
	var rel_type: String = str(context.get("relationship_type", "human_relationship"))
	var tags: Array = _safe_array(context.get("relationship_tags", ["human", "social"]))
	return _commit_pair_report(actor, target, rel_type, tags, str(context.get("subject_role", "Relationship")), str(context.get("object_role", "Relationship")), context)

func commit_action_result(actor: Person, target: Person, action_id: String, result: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null or target == null:
		return { "success": false, "reason": "missing_actor_or_target"}
	var delta: int = 0
	match str(action_id).strip_edges():
		"compliment", "converse", "gift", "give_money":
			delta = 3
		"insult":
			delta = -5
		"betray":
			delta = -12
		"Befriend", "Ask Out":
			delta = 6
		"Unfriend":
			delta = -18
		_:
			delta = int(context.get("bond_delta", 0))
	return _commit_pair_report(actor, target, "human_action", ["human", "action"], "Actor", "Target", {
		"source": ENGINE_SCHEMA,
		"action_id": action_id,
		"bond_delta": delta,
		"result": result.duplicate(true)
	})

func _commit_person_edge(actor: Person, target_id: int, relationship_type: String, tags: Array, subject_role: String, object_role: String, context: Dictionary) -> int:
	if gs == null or target_id <= 0:
		return 0
	var target: Person = gs.get_or_reactivate_npc_by_id(target_id) if gs.has_method("get_or_reactivate_npc_by_id") else null
	if target == null:
		return 0
	return _commit_pair(actor, target, relationship_type, tags, subject_role, object_role, context)

func _commit_pair(actor: Person, target: Person, relationship_type: String, tags: Array, subject_role: String, object_role: String, context: Dictionary) -> int:
	var report: Dictionary = _commit_pair_report(actor, target, relationship_type, tags, subject_role, object_role, context)
	return 1 if bool(report.get("success", false)) else 0

func _commit_pair_report(actor: Person, target: Person, relationship_type: String, tags: Array, subject_role: String, object_role: String, context: Dictionary) -> Dictionary:
	if gs == null or gs.relationship_graph_contract_engine == null:
		return { "success": false, "reason": "missing_relationship_graph"}
	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var target_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(target, { "source": ENGINE_SCHEMA})
	var current_bond: int = 50
	if typeof(actor.affection) == TYPE_DICTIONARY and actor.affection.has(int(target.id)):
		current_bond = int(actor.affection.get(int(target.id), 50))
	return gs.relationship_graph_contract_engine.commit_relationship_event({
		"producer": ENGINE_SCHEMA,
		"event_type": relationship_type,
		"relationship_type": relationship_type,
		"relationship_tags": tags.duplicate(true),
		"subject_entity_id": str(actor_entity.get("entity_id", "")),
		"object_entity_id": str(target_entity.get("entity_id", "")),
		"subject_role": subject_role,
		"object_role": object_role,
		"bond": clampi(current_bond + int(context.get("bond_delta", 0)), 0, 100),
		"context": context.duplicate(true)
	}, { "producer": ENGINE_SCHEMA})

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []