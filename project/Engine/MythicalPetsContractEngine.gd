extends Resource
class_name MythicalPetsContractEngine

const ENGINE_SCHEMA:= "eralife.relationship_producer.mythical_pets_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func append_mythical_actions(_actor: Person, entity_id: String, existing_actions: Array = []) -> Array:
	var out: Array = existing_actions.duplicate(true)
	var entity: Dictionary = _entity(entity_id)
	if entity.is_empty() or str(entity.get("entity_kind", "")) != "mythical":
		return out
	out.append({ "id": "mythical:bond", "label": "Bond With Magic", "bond_delta": 5})
	out.append({ "id": "mythical:study", "label": "Study Creature", "bond_delta": 2})
	if bool(entity.get("trainable", true)):
		out.append({ "id": "mythical:train_magic", "label": "Train Mythic Ability", "bond_delta": 4})
	return out

func commit_mythical_pet_action(actor: Person, entity_id: String, action_id: String, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null or gs.relationship_graph_contract_engine == null:
		return { "success": false, "text": "The mythical pet action could not be resolved.", "reason": "missing_graph_or_actor"}
	var entity: Dictionary = _entity(entity_id)
	if entity.is_empty() or str(entity.get("entity_kind", "")) != "mythical":
		return { "success": false, "text": "That mythical creature is not available.", "reason": "missing_mythical_entity"}
	var delta: int = 0
	var label: String = "Mythic Action"
	match action_id:
		"mythical:bond":
			delta = 5
			label = "Bond With Magic"
			_apply_mythical_stat_delta(entity_id, "magic_attunement", 5)
		"mythical:study":
			delta = 2
			label = "Study Creature"
			_apply_mythical_stat_delta(entity_id, "smarts", 1)
		"mythical:train_magic":
			delta = 4
			label = "Train Mythic Ability"
			_apply_mythical_stat_delta(entity_id, "training", 6)
			_apply_mythical_stat_delta(entity_id, "magic_attunement", 3)
		_:
			return { "success": false, "text": "That mythical action is not available right now.", "reason": "unknown_action"}
	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var report: Dictionary = gs.relationship_graph_contract_engine.commit_relationship_event({
		"producer": ENGINE_SCHEMA,
		"event_type": "mythical_pet_profile_action",
		"relationship_type": "mythical_pet_action",
		"relationship_tags": ["pet", "mythical_pet", "mythical_pet_action"],
		"subject_entity_id": str(actor_entity.get("entity_id", "")),
		"object_entity_id": entity_id,
		"subject_role": "Bonded Human",
		"object_role": "Mythical Pet",
		"bond_delta": delta,
		"action_id": action_id,
		"context": context.duplicate(true)
	}, { "producer": ENGINE_SCHEMA})
	var text: String = "You %s with %s." % [label.to_lower(), str(entity.get("display_name", "your mythical pet"))]
	report ["success"] = bool(report.get("success", false))
	report ["text"] = text
	report ["popup_title"] = label
	report ["popup_text"] = text
	report ["popup_footer"] = "Tap anywhere to continue."
	return report

func _apply_mythical_stat_delta(entity_id: String, stat_key: String, delta: int) -> void:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return
	var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(entity_id, {}))
	if entity.is_empty():
		return
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	stats [stat_key] = clampi(int(stats.get(stat_key, 0)) + delta, 0, 100)
	entity ["stats"] = stats
	entity ["updated_at_ms"] = int(Time.get_ticks_msec())
	gs.entity_registry [entity_id] = entity.duplicate(true)
	if gs.relationship_graph_contract_engine != null:
		gs.relationship_graph_contract_engine.ensure_entity(entity, { "source": ENGINE_SCHEMA})

func _entity(entity_id: String) -> Dictionary:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return {}
	return _safe_dictionary(gs.entity_registry.get(entity_id, {})).duplicate(true)

func _safe_dictionary(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}