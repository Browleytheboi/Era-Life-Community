extends Resource
class_name RelationshipGraphContractEngine

const ENGINE_SCHEMA:= "eralife.relationship_graph_contract_engine"
const GRAPH_SCHEMA:= "eralife.canonical_relationship_graph"
const EDGE_SCHEMA:= "eralife.canonical_relationship_graph.edge"
const CONTRACT_VERSION:= 1
const MAX_EVENT_LOG:= 600

var gs: GameState = null
var last_report: Dictionary = {}

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()

func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.entity_registry) != TYPE_DICTIONARY:
		gs.entity_registry = {}

	if typeof(gs.canonical_relationship_graph) != TYPE_DICTIONARY or gs.canonical_relationship_graph.is_empty():
		gs.canonical_relationship_graph = {
			"schema": GRAPH_SCHEMA,
			"version": CONTRACT_VERSION,
			"entities": {},
			"edges": {},
			"events": [],
			"authority": ENGINE_SCHEMA,
			"anything_can_relate_to_anything": true,
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var graph_state: Dictionary = gs.canonical_relationship_graph

	if typeof(graph_state.get("entities", {})) != TYPE_DICTIONARY:
		graph_state ["entities"] = {}

	if typeof(graph_state.get("edges", {})) != TYPE_DICTIONARY:
		graph_state ["edges"] = {}

	if typeof(graph_state.get("events", [])) != TYPE_ARRAY:
		graph_state ["events"] = []

	graph_state ["schema"] = GRAPH_SCHEMA
	graph_state ["version"] = CONTRACT_VERSION
	graph_state ["authority"] = ENGINE_SCHEMA
	graph_state ["anything_can_relate_to_anything"] = true

	gs.canonical_relationship_graph = graph_state

func graph() -> Dictionary:
	_ensure_state()
	if gs == null:
		return {}
	return gs.canonical_relationship_graph

func ensure_entity(
	entity_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {}

	var clean_entity: Dictionary = (
		entity_contract.duplicate(false)
	)

	var entity_id: String = str(
		clean_entity.get(
			"entity_id",
			clean_entity.get(
				"id",
				""
			)
		)
	).strip_edges()

	if entity_id == "":
		return {}

	clean_entity [
		"entity_id"
	] = entity_id
	clean_entity [
		"registered_by"
	] = ENGINE_SCHEMA
	clean_entity [
		"registered_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	clean_entity [
		"context"
	] = context.duplicate(false)

	gs.entity_registry [
		entity_id
	] = clean_entity.duplicate(false)

	var graph_state: Dictionary = graph()

	var entities_raw: Variant = graph_state.get(
		"entities",
		{}
	)

	var entities: Dictionary = (
		entities_raw as Dictionary
		if typeof(entities_raw) == TYPE_DICTIONARY
		else {}
	)

	entities [
		entity_id
	] = clean_entity.duplicate(false)

	graph_state [
		"entities"
	] = entities

	gs.canonical_relationship_graph = graph_state

	return clean_entity.duplicate(false)

func ensure_person_entity(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}
	if gs != null and gs.human_contract_engine != null and gs.human_contract_engine.has_method("define_entity_for_person"):
		return ensure_entity(gs.human_contract_engine.define_entity_for_person(person, context), context)
	return ensure_entity({
		"entity_id": "human:%d" % int(person.id),
		"entity_kind": "human",
		"entity_type": "human",
		"source_person_id": int(person.id),
		"display_name": "%s %s" % [str(person.first_name), str(person.last_name)],
		"age": int(person.age),
		"alive": bool(person.alive),
		"stats": {
			"health": clampi(int(round(float(person.health))), 0, 100),
			"smarts": clampi(int(person.smarts), 0, 100),
			"looks": clampi(int(person.looks), 0, 100),
			"mental": clampi(int(person.mental_health), 0, 100)
		}
	}, context)

func commit_relationship_event(event: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	if gs == null:
		return _fail("missing_game_state", event, context)
	var clean_event: Dictionary = _safe_dictionary(event)
	var subject_entity: Dictionary = _safe_dictionary(clean_event.get("subject_entity", {}))
	var object_entity: Dictionary = _safe_dictionary(clean_event.get("object_entity", {}))
	if not subject_entity.is_empty():
		subject_entity = ensure_entity(subject_entity, { "source": "relationship_event_subject"})
	if not object_entity.is_empty():
		object_entity = ensure_entity(object_entity, { "source": "relationship_event_object"})
	var subject_id: String = str(clean_event.get("subject_entity_id", subject_entity.get("entity_id", ""))).strip_edges()
	var object_id: String = str(clean_event.get("object_entity_id", object_entity.get("entity_id", ""))).strip_edges()
	if subject_id == "" or object_id == "":
		return _fail("missing_entity_ids", clean_event, context)
	if subject_id == object_id and not bool(clean_event.get("allow_self_edge", false)):
		return _fail("self_edge_not_allowed", clean_event, context)
	var graph_state: Dictionary = graph()
	var entities: Dictionary = _safe_dictionary(graph_state.get("entities", {}))
	if not entities.has(subject_id) and gs.entity_registry.has(subject_id):
		entities [subject_id] = _safe_dictionary(gs.entity_registry.get(subject_id, {}))
	if not entities.has(object_id) and gs.entity_registry.has(object_id):
		entities [object_id] = _safe_dictionary(gs.entity_registry.get(object_id, {}))
	graph_state ["entities"] = entities
	var edges: Dictionary = _safe_dictionary(graph_state.get("edges", {}))
	var edge_key: String = _edge_key(subject_id, object_id)
	var edge: Dictionary = _safe_dictionary(edges.get(edge_key, {}))
	if edge.is_empty():
		edge = {
			"schema": EDGE_SCHEMA,
			"version": CONTRACT_VERSION,
			"edge_key": edge_key,
			"entity_a": _ordered_pair(subject_id, object_id) [0],
			"entity_b": _ordered_pair(subject_id, object_id) [1],
			"relationship_types": {},
			"relationship_tags": [],
			"directional_roles": {},
			"bond": int(clean_event.get("bond", 50)),
			"created_at_ms": int(Time.get_ticks_msec())
		}
	var relationship_type: String = str(clean_event.get("relationship_type", clean_event.get("event_type", "related"))).strip_edges().to_lower()
	if relationship_type == "":
		relationship_type = "related"
	var relationship_types: Dictionary = _safe_dictionary(edge.get("relationship_types", {}))
	relationship_types [relationship_type] = true
	edge ["relationship_types"] = relationship_types
	var tags: Array = _safe_array(edge.get("relationship_tags", []))
	for raw_tag in _safe_array(clean_event.get("relationship_tags", clean_event.get("tags", []))):
		var tag: String = str(raw_tag).strip_edges().to_lower()
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	if relationship_type != "" and not tags.has(relationship_type):
		tags.append(relationship_type)
	edge ["relationship_tags"] = tags
	var old_bond: int = clampi(int(edge.get("bond", 50)), 0, 100)
	var next_bond: int = old_bond
	if clean_event.has("bond"):
		next_bond = clampi(int(clean_event.get("bond", old_bond)), 0, 100)
	elif clean_event.has("bond_delta") or clean_event.has("delta"):
		next_bond = clampi(old_bond + int(clean_event.get("bond_delta", clean_event.get("delta", 0))), 0, 100)
	edge ["bond"] = next_bond
	edge ["last_event_type"] = str(clean_event.get("event_type", relationship_type))
	edge ["last_producer"] = str(clean_event.get("producer", context.get("producer", "unknown")))
	edge ["updated_at_ms"] = int(Time.get_ticks_msec())
	var directional_roles: Dictionary = _safe_dictionary(edge.get("directional_roles", {}))
	var subject_role: String = str(clean_event.get("subject_role", "")).strip_edges()
	var object_role: String = str(clean_event.get("object_role", "")).strip_edges()
	if subject_role != "":
		directional_roles [subject_id] = subject_role
	if object_role != "":
		directional_roles [object_id] = object_role
	edge ["directional_roles"] = directional_roles
	edges [edge_key] = edge.duplicate(true)
	graph_state ["edges"] = edges
	var event_log: Array = _safe_array(graph_state.get("events", []))
	var event_id: String = "rel_evt:%d:%d" % [int(Time.get_ticks_usec()), event_log.size()]
	clean_event ["event_id"] = event_id
	clean_event ["subject_entity_id"] = subject_id
	clean_event ["object_entity_id"] = object_id
	clean_event ["edge_key"] = edge_key
	clean_event ["committed_by"] = ENGINE_SCHEMA
	clean_event ["committed_at_ms"] = int(Time.get_ticks_msec())
	event_log.append(clean_event.duplicate(true))
	while event_log.size() > MAX_EVENT_LOG:
		event_log.pop_front()
	graph_state ["events"] = event_log
	graph_state ["last_event_id"] = event_id
	graph_state ["updated_at_ms"] = int(Time.get_ticks_msec())
	gs.canonical_relationship_graph = graph_state
	last_report = {
		"success": true,
		"event_id": event_id,
		"edge_key": edge_key,
		"edge": edge.duplicate(true),
		"graph_authority": ENGINE_SCHEMA
	}
	return last_report.duplicate(true)

func bond_for_pair(entity_a: String, entity_b: String, fallback: int = 50) -> int:
	var graph_state: Dictionary = graph()
	var edges: Dictionary = _safe_dictionary(graph_state.get("edges", {}))
	var edge: Dictionary = _safe_dictionary(edges.get(_edge_key(entity_a, entity_b), {}))
	if edge.is_empty():
		return fallback
	return clampi(int(edge.get("bond", fallback)), 0, 100)

func relationships_for_entity(entity_id: String, filters: Dictionary = {}) -> Array:
	var clean_id: String = str(entity_id).strip_edges()
	if clean_id == "":
		return []
	var graph_state: Dictionary = graph()
	var edges: Dictionary = _safe_dictionary(graph_state.get("edges", {}))
	var out: Array = []
	for raw_key in edges.keys():
		var edge: Dictionary = _safe_dictionary(edges.get(raw_key, {}))
		if str(edge.get("entity_a", "")) != clean_id and str(edge.get("entity_b", "")) != clean_id:
			continue
		if not _edge_matches_filters(edge, filters):
			continue
		out.append(edge.duplicate(true))
	out.sort_custom(Callable(self, "_edge_sort"))
	return out

func cards_for_entity(entity_id: String, filters: Dictionary = {}) -> Array:
	var graph_state: Dictionary = graph()
	var entities: Dictionary = _safe_dictionary(graph_state.get("entities", {}))
	var out: Array = []
	for edge in relationships_for_entity(entity_id, filters):
		var target_id: String = str(edge.get("entity_b", "")) if str(edge.get("entity_a", "")) == entity_id else str(edge.get("entity_a", ""))
		var target_entity: Dictionary = _safe_dictionary(entities.get(target_id, gs.entity_registry.get(target_id, {})))
		if target_entity.is_empty():
			continue
		out.append(card_contract_for_edge(entity_id, target_id, target_entity, edge))
	out.sort_custom(Callable(self, "_card_sort"))
	return out

func card_contract_for_edge(source_entity_id: String, target_entity_id: String, target_entity: Dictionary, edge: Dictionary) -> Dictionary:
	var bond: int = clampi(int(edge.get("bond", 50)), 0, 100)
	var health: int = clampi(_entity_stat(target_entity, "health", 100), 0, max(1, _entity_stat(target_entity, "health_max", 100)))
	var health_max: int = max(1, _entity_stat(target_entity, "health_max", 100))
	var state: String = _state_for_bond(bond)
	var role: String = _role_for(source_entity_id, target_entity_id, edge, target_entity)
	return {
		"schema": "eralife.relationship_graph.card_contract",
		"version": CONTRACT_VERSION,
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"target_entity": target_entity.duplicate(true),
		"target_name": str(target_entity.get("display_name", target_entity_id)),
		"target_name_with_age": _entity_name_with_age(target_entity),
		"entity_kind": str(target_entity.get("entity_kind", "entity")),
		"entity_type": str(target_entity.get("entity_type", target_entity.get("species_id", "entity"))),
		"role": role,
		"relationship_type": role,
		"bond": bond,
		"health": health,
		"health_max": health_max,
		"state": state,
		"section_key": "pets" if _safe_array(edge.get("relationship_tags", [])).has("pet") else "relationships",
		"edge": edge.duplicate(true),
		"surface_context": {
			"surface_family": "institution_hub",
			"hub": "relationships",
			"section_key": "pets",
			"target_entity_id": target_entity_id,
			"relationship_bond": bond,
			"relationship_state": state,
			"narrative_perspective": "second_person",
			"descriptor_title_mode": "bond_pov",
			"ui_is_renderer_only": true
		},
		"surface_contract": {
			"card_title": _entity_name_with_age(target_entity),
			"subtitle": role,
			"bond_label": "BOND",
			"health_label": "HEALTH",
			"bond_value": bond,
			"health_value": health,
			"health_max": health_max,
			"state": state,
			"section_key": "pets",
			"button_text": "Open full relationship profile",
			"numbers_live_inside_bars_only": true
		},
		"interaction_contract": {
			"can_open_profile": true,
			"can_switch": false,
			"actions": ["open_full_relationship_profile"]
		},
		"render_policy": {
			"ui_is_pure_renderer": true,
			"graph_is_authority": true
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _edge_matches_filters(edge: Dictionary, filters: Dictionary) -> bool:
	var tags: Array = _safe_array(edge.get("relationship_tags", []))
	var tag_any: Array = _safe_array(filters.get("tag_any", filters.get("relationship_tags", [])))
	if not tag_any.is_empty():
		var matched:= false
		for raw_tag in tag_any:
			if tags.has(str(raw_tag).strip_edges().to_lower()):
				matched = true
				break
		if not matched:
			return false
	var kind_any: Array = _safe_array(filters.get("entity_kind_any", []))
	if not kind_any.is_empty():
		return true
	return true

func _edge_key(a: String, b: String) -> String:
	var pair: Array = _ordered_pair(a, b)
	return "%s<->%s" % [str(pair [0]), str(pair [1])]

func _ordered_pair(a: String, b: String) -> Array:
	var left: String = str(a)
	var right: String = str(b)
	if left < right:
		return [left, right]
	return [right, left]

func _edge_sort(a, b) -> bool:
	return int(_safe_dictionary(a).get("bond", 0)) > int(_safe_dictionary(b).get("bond", 0))

func _card_sort(a, b) -> bool:
	return int(_safe_dictionary(a).get("bond", 0)) > int(_safe_dictionary(b).get("bond", 0))

func _state_for_bond(bond: int) -> String:
	if bond < 35:
		return "conflict"
	if bond < 65:
		return "strained"
	return "warm"

func _role_for(_source_id: String, target_id: String, edge: Dictionary, target_entity: Dictionary) -> String:
	var roles: Dictionary = _safe_dictionary(edge.get("directional_roles", {}))
	var role: String = str(roles.get(target_id, "")).strip_edges()
	if role != "":
		return role
	var tags: Array = _safe_array(edge.get("relationship_tags", []))
	if tags.has("mythical_pet"):
		return "Mythical Pet"
	if tags.has("family_pet"):
		return "Family Pet"
	if tags.has("pet"):
		return "Pet"
	return str(target_entity.get("entity_kind", "Relationship")).capitalize()

func _entity_name_with_age(entity: Dictionary) -> String:
	var name: String = str(entity.get("display_name", "Unknown")).strip_edges()
	var age: int = int(entity.get("age", entity.get("age_years", -1)))
	if age >= 0:
		return "%s (Age %d)" % [name, age]
	return name

func _entity_stat(entity: Dictionary, stat_key: String, fallback: int = 0) -> int:
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	return int(stats.get(stat_key, entity.get(stat_key, fallback)))
func population_hover_contract_for_person(person: Person, visible_entity_ids: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "missing_person",
			"schema": "eralife.population_graph_hover_contract",
			"graph_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var source_entity: Dictionary = ensure_person_entity(person, {
		"source": ENGINE_SCHEMA,
		"view": "population_hover_contract",
		"context": context.duplicate(true)
	})

	var source_entity_id: String = str(source_entity.get("entity_id", "")).strip_edges()
	if source_entity_id == "":
		return {
			"success": false,
			"reason": "missing_source_entity_id",
			"schema": "eralife.population_graph_hover_contract",
			"graph_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var visible_ids: Dictionary = visible_entity_ids.duplicate(true)
	var out_edges: Array = []
	var seen_edges: Dictionary = {}

	var cards: Array = cards_for_entity(source_entity_id, {})
	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card
		var target_entity_id: String = str(card.get("target_entity_id", "")).strip_edges()
		if target_entity_id == "" or target_entity_id == source_entity_id:
			continue

		if not visible_ids.is_empty() and not visible_ids.has(target_entity_id):
			continue

		var edge_contract: Dictionary = _population_graph_edge_contract_from_card(
			source_entity_id,
			card,
			context
		)

		if edge_contract.is_empty():
			continue

		var edge_key: String = str(edge_contract.get("edge_key", "")).strip_edges()
		if edge_key == "":
			edge_key = "%s:%s:%s" % [
				source_entity_id,
				target_entity_id,
				str(edge_contract.get("line_kind", "relationship"))
			]

		if seen_edges.has(edge_key):
			continue

		seen_edges [edge_key] = true
		out_edges.append(edge_contract)

	_append_native_population_person_edges(
		person,
		source_entity_id,
		visible_ids,
		out_edges,
		seen_edges
	)

	_append_native_population_succession_edges(
		person,
		source_entity_id,
		visible_ids,
		out_edges,
		seen_edges
	)

	_append_native_population_civic_edges(
		person,
		source_entity_id,
		visible_ids,
		out_edges,
		seen_edges
	)

	out_edges.sort_custom(Callable(self, "_population_graph_edge_sort"))

	return {
		"success": true,
		"schema": "eralife.population_graph_hover_contract",
		"version": CONTRACT_VERSION,
		"source_entity_id": source_entity_id,
		"source_person_id": int(person.id),
		"source_name": "%s %s" % [str(person.first_name), str(person.last_name)],
		"edges": out_edges,
		"edge_count": out_edges.size(),
		"context": context.duplicate(true),
		"graph_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true,
		"hover_zero_engine_calls": true,
		"built_at_ms": int(Time.get_ticks_msec())
	}

func _population_graph_edge_contract_from_card(source_entity_id: String, card: Dictionary, context: Dictionary = {}) -> Dictionary:
	var target_entity_id: String = str(card.get("target_entity_id", "")).strip_edges()
	if target_entity_id == "":
		return {}

	var edge: Dictionary = _safe_dictionary(card.get("edge", {}))
	var tags: Array = _safe_array(edge.get("relationship_tags", []))
	var relationship_types: Dictionary = _safe_dictionary(edge.get("relationship_types", {}))

	for raw_type in relationship_types.keys():
		var type_key: String = str(raw_type).strip_edges().to_lower()
		if type_key != "" and not tags.has(type_key):
			tags.append(type_key)

	var bond: int = clampi(int(card.get("bond", edge.get("bond", 50))), 0, 100)
	var line_kind: String = _population_graph_line_kind(tags, edge, card, bond, context)
	var weight: float = _population_graph_line_weight(line_kind, bond)
	var intensity: float = _population_graph_line_intensity(line_kind, bond)

	return {
		"schema": "eralife.population_graph_hover_contract.edge",
		"version": CONTRACT_VERSION,
		"edge_key": "%s:%s:%s" % [source_entity_id, target_entity_id, line_kind],
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"target_name": str(card.get("target_name", target_entity_id)),
		"relationship_label": str(card.get("role", card.get("relationship_type", "Relationship"))),
		"line_kind": line_kind,
		"bond": bond,
		"weight": weight,
		"intensity": intensity,
		"tags": tags.duplicate(true),
		"edge": edge.duplicate(true),
		"render_policy": {
			"ui_draws_line_only": true,
			"ui_does_not_calculate_relationship": true,
			"graph_is_authority": true,
		}
	}


func _append_native_population_person_edges(source: Person, source_entity_id: String, visible_entity_ids: Dictionary, out_edges: Array, seen_edges: Dictionary) -> void:
	if source == null:
		return

	for raw_parent_id in source.parents:
		var parent: Person = _population_graph_person_from_raw(raw_parent_id)
		_append_native_population_person_edge(
			source_entity_id,
			parent,
			"Parent",
			"family",
			78,
			visible_entity_ids,
			out_edges,
			seen_edges
		)

	for raw_child_id in source.children:
		var child: Person = _population_graph_person_from_raw(raw_child_id)
		_append_native_population_person_edge(
			source_entity_id,
			child,
			"Child",
			"family",
			82,
			visible_entity_ids,
			out_edges,
			seen_edges
		)

	if source.partner != null:
		var partner_label: String = "Spouse" if str(source.marital_status).strip_edges().to_lower() in ["married", "spouse", "husband", "wife"] else "Partner"
		_append_native_population_person_edge(
			source_entity_id,
			source.partner,
			partner_label,
			"romance",
			94,
			visible_entity_ids,
			out_edges,
			seen_edges
		)

	var friend_count: int = 0
	for raw_friend_id in source.friends:
		if friend_count >= 12:
			break

		var friend: Person = _population_graph_person_from_raw(raw_friend_id)
		if friend == null:
			continue

		friend_count += 1
		_append_native_population_person_edge(
			source_entity_id,
			friend,
			"Friend",
			"social",
			64,
			visible_entity_ids,
			out_edges,
			seen_edges
		)
func _append_native_population_succession_edges(source: Person, source_entity_id: String, visible_entity_ids: Dictionary, out_edges: Array, seen_edges: Dictionary) -> void:
	if source == null or not source.alive:
		return

	if bool(source.is_ruler):
		var heir: Person = _population_graph_find_visible_heir_for_ruler(source, visible_entity_ids)
		if heir != null:
			_append_native_population_person_edge(
				source_entity_id,
				heir,
				"Next In Line",
				"succession_heir",
				100,
				visible_entity_ids,
				out_edges,
				seen_edges
			)
		return

	if int(source.succession_rank) == 1:
		var ruler: Person = _population_graph_find_visible_ruler_for_heir(source, visible_entity_ids)
		if ruler != null:
			_append_native_population_person_edge(
				source_entity_id,
				ruler,
				"Succession Source",
				"succession_heir",
				96,
				visible_entity_ids,
				out_edges,
				seen_edges
			)


func _append_native_population_civic_edges(source: Person, source_entity_id: String, visible_entity_ids: Dictionary, out_edges: Array, seen_edges: Dictionary) -> void:
	if source == null or not source.alive:
		return

	var candidates: Array = []

	for raw_entity_id in visible_entity_ids.keys():
		var target_entity_id: String = str(raw_entity_id).strip_edges()
		if target_entity_id == "" or target_entity_id == source_entity_id:
			continue

		var target: Person = _population_graph_person_from_entity_id(target_entity_id)
		if target == null or not target.alive:
			continue

		var civic_contract: Dictionary = _population_graph_civic_tie_contract(source, target)
		if civic_contract.is_empty():
			continue

		candidates.append(civic_contract)

	candidates.sort_custom(Callable(self, "_population_graph_civic_tie_sort"))

	var additions: int = 0
	for raw_candidate in candidates:
		if additions >= 8:
			break

		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var target: Person = candidate.get("target", null) as Person
		if target == null:
			continue

		_append_native_population_person_edge(
			source_entity_id,
			target,
			str(candidate.get("label", "Civic Tie")),
			str(candidate.get("line_kind", "civic")),
			clampi(int(candidate.get("bond", 44)), 0, 100),
			visible_entity_ids,
			out_edges,
			seen_edges
		)

		additions += 1


func _population_graph_find_visible_heir_for_ruler(source: Person, visible_entity_ids: Dictionary) -> Person:
	var best: Person = null
	var best_rank: int = 999999

	for raw_entity_id in visible_entity_ids.keys():
		var target: Person = _population_graph_person_from_entity_id(str(raw_entity_id))
		if target == null or not target.alive:
			continue
		if int(target.id) == int(source.id):
			continue
		if not _population_graph_people_share_realm(source, target):
			continue

		var rank: int = int(target.succession_rank)
		if rank <= 0:
			continue

		if rank < best_rank:
			best = target
			best_rank = rank

	return best


func _population_graph_find_visible_ruler_for_heir(source: Person, visible_entity_ids: Dictionary) -> Person:
	for raw_entity_id in visible_entity_ids.keys():
		var target: Person = _population_graph_person_from_entity_id(str(raw_entity_id))
		if target == null or not target.alive:
			continue
		if int(target.id) == int(source.id):
			continue
		if not bool(target.is_ruler):
			continue
		if not _population_graph_people_share_realm(source, target):
			continue

		return target

	return null


func _population_graph_civic_tie_contract(source: Person, target: Person) -> Dictionary:
	if source == null or target == null:
		return {}

	if int(source.id) == int(target.id):
		return {}

	if not _population_graph_people_share_realm(source, target):
		return {}

	var source_workplace: String = str(source.current_workplace_id).strip_edges()
	var target_workplace: String = str(target.current_workplace_id).strip_edges()
	if source_workplace != "" and source_workplace == target_workplace:
		return {
			"target": target,
			"label": "Coworker",
			"line_kind": "economic",
			"bond": 58,
			"score": 72
		}

	var source_city: String = _population_graph_person_city_key(source)
	var target_city: String = _population_graph_person_city_key(target)
	if source_city != "" and source_city == target_city:
		return {
			"target": target,
			"label": "Same City",
			"line_kind": "civic",
			"bond": 52,
			"score": 58
		}

	var source_class: String = str(source.social_class).strip_edges().to_lower()
	var target_class: String = str(target.social_class).strip_edges().to_lower()
	if source_class != "" and source_class == target_class and source_class in ["peasant", "commoner", "low class", "lower class", "merchant", "middle class"]:
		return {
			"target": target,
			"label": "Class Tie",
			"line_kind": "civic",
			"bond": 46,
			"score": 48
		}

	return {
		"target": target,
		"label": "Countryfolk",
		"line_kind": "civic",
		"bond": 40,
		"score": 36
	}


func _population_graph_civic_tie_sort(a, b) -> bool:
	var left: Dictionary = _safe_dictionary(a)
	var right: Dictionary = _safe_dictionary(b)

	if int(left.get("score", 0)) == int(right.get("score", 0)):
		return int(left.get("bond", 0)) > int(right.get("bond", 0))

	return int(left.get("score", 0)) > int(right.get("score", 0))


func _population_graph_person_from_entity_id(entity_id: String) -> Person:
	var clean_id: String = str(entity_id).strip_edges()
	if clean_id.begins_with("human:"):
		clean_id = clean_id.replace("human:", "")

	var person_id: int = int(clean_id)
	if person_id <= 0:
		return null

	return _population_graph_person_from_raw(person_id)


func _population_graph_people_share_realm(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	if int(a.realm_id) > 0 and int(b.realm_id) > 0 and int(a.realm_id) == int(b.realm_id):
		return true

	var a_country: String = str(a.home_country).strip_edges().to_lower()
	var b_country: String = str(b.home_country).strip_edges().to_lower()
	if a_country != "" and a_country == b_country:
		return true

	var a_birth_country: String = str(a.birth_country).strip_edges().to_lower()
	var b_birth_country: String = str(b.birth_country).strip_edges().to_lower()
	if a_birth_country != "" and a_birth_country == b_birth_country:
		return true

	var a_nation: String = str(a.bending_nation).strip_edges().to_lower()
	var b_nation: String = str(b.bending_nation).strip_edges().to_lower()
	if a_nation != "" and a_nation == b_nation:
		return true

	return false


func _population_graph_person_city_key(person: Person) -> String:
	if person == null:
		return ""

	var home_city: String = str(person.home_city).strip_edges().to_lower()
	if home_city != "":
		return home_city

	return str(person.birth_city).strip_edges().to_lower()


func _append_native_population_person_edge(source_entity_id: String, target: Person, label_text: String, line_kind: String, bond: int, visible_entity_ids: Dictionary, out_edges: Array, seen_edges: Dictionary) -> void:
	if target == null or not target.alive:
		return

	var target_entity: Dictionary = ensure_person_entity(target, {
		"source": ENGINE_SCHEMA,
		"view": "population_hover_native_edge"
	})

	var target_entity_id: String = str(target_entity.get("entity_id", "")).strip_edges()
	if target_entity_id == "" or target_entity_id == source_entity_id:
		return

	if not visible_entity_ids.is_empty() and not visible_entity_ids.has(target_entity_id):
		return

	var edge_key: String = "%s:%s:%s:%s" % [
		source_entity_id,
		target_entity_id,
		line_kind,
		label_text.to_lower()
	]

	if seen_edges.has(edge_key):
		return

	seen_edges [edge_key] = true

	out_edges.append({
		"schema": "eralife.population_graph_hover_contract.edge",
		"version": CONTRACT_VERSION,
		"edge_key": edge_key,
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"target_name": "%s %s" % [str(target.first_name), str(target.last_name)],
		"relationship_label": label_text,
		"line_kind": line_kind,
		"bond": clampi(bond, 0, 100),
		"weight": _population_graph_line_weight(line_kind, bond),
		"intensity": _population_graph_line_intensity(line_kind, bond),
		"tags": [line_kind, label_text.to_lower()],
		"render_policy": {
			"ui_draws_line_only": true,
			"ui_does_not_calculate_relationship": true,
			"graph_is_authority": true,
		}
	})


func _population_graph_person_from_raw(raw_value: Variant) -> Person:
	if raw_value is Person:
		return raw_value

	var target_id: int = int(raw_value)
	if target_id <= 0:
		return null

	if gs != null and gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(target_id)

	return null


func _population_graph_line_kind(tags: Array, _edge: Dictionary, card: Dictionary, bond: int, _context: Dictionary = {}) -> String:
	if _population_graph_tags_have_any(tags, ["succession_heir", "next_in_line", "heir", "line_of_succession"]):
		return "succession_heir"

	if bond <= 28 or _population_graph_tags_have_any(tags, ["rival", "enemy", "conflict", "succession_conflict", "coup", "claimant_pressure"]):
		return "conflict"

	if _population_graph_tags_have_any(tags, ["romance", "partner", "spouse", "married", "dating", "husband", "wife"]):
		return "romance"

	if _population_graph_tags_have_any(tags, ["family", "parent", "child", "sibling"]):
		return "family"

	if _population_graph_tags_have_any(tags, ["house", "dynasty", "bloodline", "clan"]):
		return "house"

	if _population_graph_tags_have_any(tags, ["political", "allegiance", "royal", "noble", "court", "realm", "state", "vassal", "liege", "succession"]):
		return "political"

	if _population_graph_tags_have_any(tags, ["economic", "merchant", "market", "employer", "employee", "patron", "funding", "trade", "career", "labor"]):
		return "economic"

	if _population_graph_tags_have_any(tags, ["civic", "citizen", "commoner", "peasant", "same_city", "countryfolk", "class_tie"]):
		return "civic"

	if _population_graph_tags_have_any(tags, ["friend", "social", "ally", "alliance"]):
		return "social"

	var role_text: String = str(card.get("role", card.get("relationship_type", ""))).strip_edges().to_lower()
	if role_text.find("next in line") >= 0 or role_text.find("heir") >= 0:
		return "succession_heir"
	if role_text.find("rival") >= 0:
		return "conflict"
	if role_text.find("partner") >= 0 or role_text.find("spouse") >= 0 or role_text.find("husband") >= 0 or role_text.find("wife") >= 0 or role_text.find("dating") >= 0:
		return "romance"
	if role_text.find("parent") >= 0 or role_text.find("child") >= 0 or role_text.find("sibling") >= 0:
		return "family"
	if role_text.find("king") >= 0 or role_text.find("queen") >= 0 or role_text.find("duke") >= 0 or role_text.find("noble") >= 0:
		return "political"
	if role_text.find("merchant") >= 0 or role_text.find("employer") >= 0 or role_text.find("patron") >= 0:
		return "economic"
	if role_text.find("same city") >= 0 or role_text.find("countryfolk") >= 0 or role_text.find("class tie") >= 0:
		return "civic"

	return "relationship"

func _population_graph_tags_have_any(tags: Array, keys: Array) -> bool:
	for raw_tag in tags:
		var tag: String = str(raw_tag).strip_edges().to_lower()
		if keys.has(tag):
			return true
	return false


func _population_graph_line_weight(line_kind: String, bond: int) -> float:
	match line_kind:
		"succession_heir":
			return 4.2
		"conflict":
			return 3.4
		"romance":
			return 3.0
		"political":
			return 2.8
		"economic":
			return 2.4
		"house":
			return 2.6
		"family":
			return 2.2
		"civic":
			return 1.55
		"social":
			return 1.8
		_:
			return 1.5 + (float(clampi(bond, 0, 100)) / 100.0)


func _population_graph_line_intensity(line_kind: String, bond: int) -> float:
	match line_kind:
		"succession_heir":
			return 1.0
		"conflict":
			return 0.94
		"romance":
			return 0.94
		"political":
			return 0.88
		"economic":
			return 0.82
		"house":
			return 0.86
		"family":
			return 0.78
		"civic":
			return 0.58
		"social":
			return 0.68
		_:
			return clampf(0.42 + (float(clampi(bond, 0, 100)) / 180.0), 0.42, 0.84)


func _population_graph_edge_sort(a, b) -> bool:
	var left: Dictionary = _safe_dictionary(a)
	var right: Dictionary = _safe_dictionary(b)

	var left_kind: String = str(left.get("line_kind", "relationship"))
	var right_kind: String = str(right.get("line_kind", "relationship"))

	var order:= {
		"succession_heir": 0,
		"conflict": 1,
		"romance": 2,
		"political": 3,
		"house": 4,
		"economic": 5,
		"family": 6,
		"civic": 7,
		"social": 8,
		"relationship": 9
	}

	var left_order: int = int(order.get(left_kind, 99))
	var right_order: int = int(order.get(right_kind, 99))

	if left_order == right_order:
		return int(left.get("bond", 0)) > int(right.get("bond", 0))

	return left_order < right_order
func _fail(reason: String, event: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"event": event.duplicate(true),
		"context": context.duplicate(true),
		"graph_authority": ENGINE_SCHEMA
	}

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []