extends Resource
class_name GlobalNodeContractEngine

const ENGINE_SCHEMA:= "eralife.global_node_contract_engine"
const NODE_SCHEMA:= "eralife.global_node_packet"
const EDGE_SCHEMA:= "eralife.global_node_edge_contract"
const GRAPH_PACKET_SCHEMA:= "eralife.global_node_graph_packet"
const REGISTRY_SCHEMA:= "eralife.global_node_registry"
const CONTRACT_VERSION:= 1

var gs = null
var node_packets_by_id: Dictionary = {}
var edge_packets_by_scope: Dictionary = {}
var graph_packets_by_scope: Dictionary = {}
var alias_to_scope_id: Dictionary = {}
var dirty_scope_ids: Dictionary = {}
var last_ingest_report: Dictionary = {}
var game_state_subscription_ready: bool = false


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
	gs = _gs
	_subscribe_to_game_state()
	_commit_registry()


func ingest_population_card_graph_packet(population_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	if population_packet.is_empty():
		return _fail("empty_population_packet", "", context)

	var realm_id: int = int(population_packet.get("realm_id", -1))
	var realm_name: String = str(population_packet.get("realm_name", "")).strip_edges()
	var scope_id: String = _scope_id("population", realm_id, realm_name)

	if scope_id == "":
		return _fail("invalid_population_scope", "", context)

	var graph_node_contracts: Dictionary = {}
	var graph_node_contracts_raw: Variant = population_packet.get("graph_node_contracts", {})
	if typeof(graph_node_contracts_raw) == TYPE_DICTIONARY:
		graph_node_contracts = graph_node_contracts_raw as Dictionary

	var nodes_by_id: Dictionary = {}
	var cards_raw: Variant = population_packet.get("cards_by_entity_id", {})
	if typeof(cards_raw) == TYPE_DICTIONARY:
		var cards: Dictionary = cards_raw as Dictionary
		for raw_entity_id in cards.keys():
			var entity_id: String = str(raw_entity_id).strip_edges()
			var card_raw: Variant = cards.get(raw_entity_id, {})
			if typeof(card_raw) != TYPE_DICTIONARY:
				continue

			var card_packet: Dictionary = card_raw as Dictionary
			var hover_contract: Dictionary = {}
			var hover_raw: Variant = graph_node_contracts.get(entity_id, {})
			if typeof(hover_raw) == TYPE_DICTIONARY:
				hover_contract = hover_raw as Dictionary

			var node_packet: Dictionary = _node_from_population_card_packet(
				entity_id,
				card_packet,
				hover_contract,
				population_packet,
				context
			)

			if node_packet.is_empty():
				continue

			var node_id: String = str(node_packet.get("id", "")).strip_edges()
			if node_id == "":
				continue

			nodes_by_id [node_id] = node_packet
			node_packets_by_id [node_id] = _merge_node_packet(node_packets_by_id.get(node_id, {}), node_packet)

	var edge_packets: Array = []
	var edges_raw: Variant = population_packet.get("graph_edges", [])
	if typeof(edges_raw) == TYPE_ARRAY:
		for raw_edge in edges_raw as Array:
			if typeof(raw_edge) != TYPE_DICTIONARY:
				continue

			var edge_packet: Dictionary = _edge_from_population_edge_packet(
				raw_edge as Dictionary,
				population_packet,
				context
			)

			if edge_packet.is_empty():
				continue

			edge_packets.append(edge_packet)

	var graph_packet: Dictionary = {
		"schema": GRAPH_PACKET_SCHEMA,
		"version": CONTRACT_VERSION,
		"source_engine": ENGINE_SCHEMA,
		"source_domain": "population",
		"source_packet_schema": str(population_packet.get("schema", "")),
		"scope_id": scope_id,
		"scope_type": "population_realm",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"title": realm_name,
		"subtitle": "Population Network",
		"built_for_year": int(population_packet.get("built_for_year", _value(gs, "year", 0))),
		"built_at_ms": int(Time.get_ticks_msec()),

		"nodes_by_id": nodes_by_id,
		"edges": edge_packets,

		"node_count": nodes_by_id.size(),
		"edge_count": edge_packets.size(),

		"layout_policy": _default_layout_policy("population"),
		"edge_policy": _default_edge_policy("population"),
		"lod_policy": _default_lod_policy("population"),

		"source_context": context.duplicate(true),
		"metadata": {
			"population_reality_input_count": int(population_packet.get("population_reality_input_count", 0)),
			"visible_card_count": int(population_packet.get("visible_card_count", 0)),
			"category_order": population_packet.get("category_order", []),
			"ui_is_renderer_only": true,
			"engine_creates_no_controls": true,
			"engine_creates_no_line2d": true,
			"ready_door_may_not_wait": true
		},

		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
		"engine_creates_no_line2d": true,
		"ready_door_may_not_wait": true
	}

	graph_packets_by_scope [scope_id] = graph_packet
	edge_packets_by_scope [scope_id] = edge_packets
	_register_scope_aliases(scope_id, [
		scope_id,
		str(realm_id),
		realm_name,
		"population:%d" % realm_id,
		"realm_population:%d" % realm_id
	])

	last_ingest_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"source_domain": "population",
		"scope_id": scope_id,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"node_count": nodes_by_id.size(),
		"edge_count": edge_packets.size(),
		"ingested_at_ms": int(Time.get_ticks_msec()),
		"ready_door_may_not_wait": true
	}

	dirty_scope_ids.erase(scope_id)
	_commit_registry()

	return graph_packet.duplicate(true)


func ingest_node_graph_packet(source_domain: String, source_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	var clean_domain: String = str(source_domain).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "generic"

	if source_packet.is_empty():
		return _fail("empty_source_packet", clean_domain, context)

	var scope_id: String = str(source_packet.get("scope_id", context.get("scope_id", ""))).strip_edges()
	if scope_id == "":
		scope_id = _scope_id(clean_domain, int(source_packet.get("realm_id", -1)), str(source_packet.get("realm_name", "")))

	if scope_id == "":
		return _fail("invalid_scope", clean_domain, context)

	var nodes_by_id: Dictionary = {}
	var nodes_raw: Variant = source_packet.get("nodes_by_id", source_packet.get("nodes", {}))

	if typeof(nodes_raw) == TYPE_DICTIONARY:
		var nodes_dict: Dictionary = nodes_raw as Dictionary
		for raw_node_id in nodes_dict.keys():
			var node_raw: Variant = nodes_dict.get(raw_node_id, {})
			if typeof(node_raw) != TYPE_DICTIONARY:
				continue

			var node_packet: Dictionary = normalize_node_packet(node_raw as Dictionary, {
				"source_domain": clean_domain,
				"scope_id": scope_id
			}.merged(context, true))

			if node_packet.is_empty():
				continue

			var node_id: String = str(node_packet.get("id", "")).strip_edges()
			if node_id == "":
				continue

			nodes_by_id [node_id] = node_packet
			node_packets_by_id [node_id] = _merge_node_packet(node_packets_by_id.get(node_id, {}), node_packet)

	elif typeof(nodes_raw) == TYPE_ARRAY:
		for raw_node in nodes_raw as Array:
			if typeof(raw_node) != TYPE_DICTIONARY:
				continue

			var node_packet: Dictionary = normalize_node_packet(raw_node as Dictionary, {
				"source_domain": clean_domain,
				"scope_id": scope_id
			}.merged(context, true))

			if node_packet.is_empty():
				continue

			var node_id: String = str(node_packet.get("id", "")).strip_edges()
			if node_id == "":
				continue

			nodes_by_id [node_id] = node_packet
			node_packets_by_id [node_id] = _merge_node_packet(node_packets_by_id.get(node_id, {}), node_packet)

	var edge_packets: Array = []
	var edges_raw: Variant = source_packet.get("edges", source_packet.get("graph_edges", []))
	if typeof(edges_raw) == TYPE_ARRAY:
		for raw_edge in edges_raw as Array:
			if typeof(raw_edge) != TYPE_DICTIONARY:
				continue

			var edge_packet: Dictionary = normalize_edge_packet(raw_edge as Dictionary, {
				"source_domain": clean_domain,
				"scope_id": scope_id
			}.merged(context, true))

			if edge_packet.is_empty():
				continue

			edge_packets.append(edge_packet)

	var graph_packet: Dictionary = {
		"schema": GRAPH_PACKET_SCHEMA,
		"version": CONTRACT_VERSION,
		"source_engine": ENGINE_SCHEMA,
		"source_domain": clean_domain,
		"source_packet_schema": str(source_packet.get("schema", "")),
		"scope_id": scope_id,
		"scope_type": str(source_packet.get("scope_type", "%s_scope" % clean_domain)),
		"title": str(source_packet.get("title", context.get("title", scope_id))),
		"subtitle": str(source_packet.get("subtitle", context.get("subtitle", ""))),
		"built_for_year": int(source_packet.get("built_for_year", _value(gs, "year", 0))),
		"built_at_ms": int(Time.get_ticks_msec()),
		"nodes_by_id": nodes_by_id,
		"edges": edge_packets,
		"node_count": nodes_by_id.size(),
		"edge_count": edge_packets.size(),
		"layout_policy": _default_layout_policy(clean_domain),
		"edge_policy": _default_edge_policy(clean_domain),
		"lod_policy": _default_lod_policy(clean_domain),
		"source_context": context.duplicate(true),
		"metadata": source_packet.get("metadata", {}).duplicate(true) if typeof(source_packet.get("metadata", {})) == TYPE_DICTIONARY else {},
		"ui_is_renderer_only": true,
		"ready_door_may_not_wait": true
	}

	graph_packets_by_scope [scope_id] = graph_packet
	edge_packets_by_scope [scope_id] = edge_packets
	_register_scope_aliases(scope_id, [
		scope_id,
		clean_domain,
		"%s:%s" % [clean_domain, scope_id]
	])

	last_ingest_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"source_domain": clean_domain,
		"scope_id": scope_id,
		"node_count": nodes_by_id.size(),
		"edge_count": edge_packets.size(),
		"ingested_at_ms": int(Time.get_ticks_msec()),
		"ready_door_may_not_wait": true
	}

	dirty_scope_ids.erase(scope_id)
	_commit_registry()

	return graph_packet.duplicate(true)


func normalize_node_packet(raw_node: Dictionary, context: Dictionary = {}) -> Dictionary:
	var node_id: String = str(raw_node.get("id", raw_node.get("node_id", ""))).strip_edges()
	if node_id == "":
		return {}

	var clean_domain: String = str(context.get("source_domain", raw_node.get("source_domain", "generic"))).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "generic"

	return {
		"schema": NODE_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": node_id,
		"node_type": str(raw_node.get("node_type", "%s.node" % clean_domain)),
		"title": str(raw_node.get("title", raw_node.get("display_name", node_id))),
		"subtitle": str(raw_node.get("subtitle", raw_node.get("role_label", ""))),
		"category": str(raw_node.get("category", clean_domain)),
		"icon": str(raw_node.get("icon", _icon_for_domain(clean_domain))),
		"position_hint": raw_node.get("position_hint", {}),
		"color_key": str(raw_node.get("color_key", raw_node.get("accent_key", "%s_default" % clean_domain))),
		"size_class": str(raw_node.get("size_class", "medium")),
		"priority": float(raw_node.get("priority", 0.0)),
		"badges": raw_node.get("badges", []).duplicate(true) if typeof(raw_node.get("badges", [])) == TYPE_ARRAY else [],
		"stats": raw_node.get("stats", []).duplicate(true) if typeof(raw_node.get("stats", [])) == TYPE_ARRAY else [],
		"hover_contract": raw_node.get("hover_contract", {}).duplicate(true) if typeof(raw_node.get("hover_contract", {})) == TYPE_DICTIONARY else {},
		"click_contract": raw_node.get("click_contract", {}).duplicate(true) if typeof(raw_node.get("click_contract", {})) == TYPE_DICTIONARY else {},
		"expansion_contract": raw_node.get("expansion_contract", {}).duplicate(true) if typeof(raw_node.get("expansion_contract", {})) == TYPE_DICTIONARY else {},
		"children": raw_node.get("children", []).duplicate(true) if typeof(raw_node.get("children", [])) == TYPE_ARRAY else [],
		"metadata": raw_node.get("metadata", {}).duplicate(true) if typeof(raw_node.get("metadata", {})) == TYPE_DICTIONARY else {},
		"source_domain": clean_domain,
		"scope_id": str(context.get("scope_id", raw_node.get("scope_id", ""))),
		"ui_is_renderer_only": true,
	}


func normalize_edge_packet(raw_edge: Dictionary, context: Dictionary = {}) -> Dictionary:
	var source_id: String = str(raw_edge.get("source", raw_edge.get("source_entity_id", raw_edge.get("source_node_id", "")))).strip_edges()
	var target_id: String = str(raw_edge.get("target", raw_edge.get("target_entity_id", raw_edge.get("target_node_id", "")))).strip_edges()

	if source_id == "" or target_id == "" or source_id == target_id:
		return {}

	var clean_domain: String = str(context.get("source_domain", raw_edge.get("source_domain", "generic"))).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "generic"

	var edge_type: String = str(raw_edge.get("edge_type", raw_edge.get("line_kind", "relationship"))).strip_edges().to_lower()
	if edge_type == "":
		edge_type = "relationship"

	var strength: float = float(raw_edge.get("strength", raw_edge.get("bond", 50.0)))
	var importance: float = float(raw_edge.get("importance", raw_edge.get("importance_weight", 0.25)))
	var thickness: float = float(raw_edge.get("thickness", raw_edge.get("line_weight", raw_edge.get("weight", _thickness_from_strength(strength, importance)))))

	return {
		"schema": EDGE_SCHEMA,
		"version": CONTRACT_VERSION,
		"source": source_id,
		"target": target_id,
		"edge_type": edge_type,
		"strength": clampf(strength, 0.0, 100.0),
		"color_key": str(raw_edge.get("color_key", raw_edge.get("relationship_color_key", _color_key_for_edge_type(edge_type)))),
		"thickness": clampf(thickness, 1.0, 9.0),
		"animation": _animation_contract_from_edge(raw_edge),
		"direction": str(raw_edge.get("direction", raw_edge.get("flow_direction", "source_to_target"))),
		"importance": clampf(importance, 0.0, 1.0),
		"lod": {
			"score": float(raw_edge.get("lod_score", strength + importance * 75.0)),
			"default_visible": bool(raw_edge.get("default_visible", true)),
			"hover_visible": bool(raw_edge.get("hover_visible", true)),
		},
		"tags": raw_edge.get("tags", []).duplicate(true) if typeof(raw_edge.get("tags", [])) == TYPE_ARRAY else [],
		"metadata": raw_edge.duplicate(true),
		"source_domain": clean_domain,
		"scope_id": str(context.get("scope_id", raw_edge.get("scope_id", ""))),
		"ui_is_renderer_only": true,
	}


func packet_for_scope(scope_id_or_alias: String) -> Dictionary:
	var key: String = _resolve_scope_id(scope_id_or_alias)
	if key == "":
		return {}

	var packet_raw: Variant = graph_packets_by_scope.get(key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	return (packet_raw as Dictionary).duplicate(true)


func has_packet_for_scope(scope_id_or_alias: String) -> bool:
	return not packet_for_scope(scope_id_or_alias).is_empty()


func mark_scope_dirty(scope_id_or_alias: String, reason: String = "node_truth_changed") -> void:
	var key: String = _resolve_scope_id(scope_id_or_alias)
	if key == "":
		key = str(scope_id_or_alias).strip_edges()

	if key == "":
		return

	dirty_scope_ids [key] = {
		"reason": reason,
		"dirty_at_ms": int(Time.get_ticks_msec())
	}

	_commit_registry()


func export_registry() -> Dictionary:
	return {
		"schema": REGISTRY_SCHEMA,
		"version": CONTRACT_VERSION,
		"engine_schema": ENGINE_SCHEMA,
		"node_packets_by_id": node_packets_by_id.duplicate(true),
		"edge_packets_by_scope": edge_packets_by_scope.duplicate(true),
		"graph_packets_by_scope": graph_packets_by_scope.duplicate(true),
		"alias_to_scope_id": alias_to_scope_id.duplicate(true),
		"dirty_scope_ids": dirty_scope_ids.duplicate(true),
		"last_ingest_report": last_ingest_report.duplicate(true),
		"node_count": node_packets_by_id.size(),
		"scope_count": graph_packets_by_scope.size(),
		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
		"engine_creates_no_line2d": true,
		"ready_door_may_not_wait": true
	}


func _node_from_population_card_packet(
	entity_id: String,
	card_packet: Dictionary,
	hover_contract: Dictionary,
	population_packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var node_id: String = str(card_packet.get("entity_id", entity_id)).strip_edges()
	if node_id == "":
		return {}

	var category: String = str(card_packet.get("category", "citizen")).strip_edges().to_lower()
	var realm_id: int = int(population_packet.get("realm_id", card_packet.get("realm_id", -1)))
	var realm_name: String = str(population_packet.get("realm_name", card_packet.get("realm_name", ""))).strip_edges()

	return {
		"schema": NODE_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": node_id,
		"node_type": "person.population_card",
		"title": str(card_packet.get("display_name", node_id)),
		"subtitle": str(card_packet.get("role_label", "")),
		"category": category,
		"icon": _icon_for_population_category(category, card_packet),
		"position_hint": {
			"domain": "population",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"category": category,
			"section_kind": str(card_packet.get("section_kind", category))
		},
		"color_key": str(card_packet.get("accent_key", _color_key_for_population_category(category))),
		"size_class": _size_class_for_population_category(category, card_packet),
		"priority": _priority_for_population_card(category, card_packet),
		"badges": _badges_for_population_card(card_packet),
		"stats": card_packet.get("stats", []).duplicate(true) if typeof(card_packet.get("stats", [])) == TYPE_ARRAY else [],
		"hover_contract": hover_contract.duplicate(true),
		"click_contract": {
			"intent": "expand_node",
			"node_id": node_id,
			"source_domain": "population",
		},
		"expansion_contract": {
			"intent": "expand_cached_network",
			"node_id": node_id,
			"edge_source": "global_node_registry",
			"expanded_mode": "all_cached_edges",
			"ui_is_renderer_only": true
		},
		"children": [],
		"metadata": {
			"source_engine": "PopulationCardContractEngine",
			"source_domain": "population",
			"person_id": int(card_packet.get("person_id", -1)),
			"realm_id": realm_id,
			"realm_name": realm_name,
			"source_card_packet": card_packet.duplicate(true),
			"source_context": context.duplicate(true),
			"ready_door_may_not_wait": true
		},
		"source_domain": "population",
		"scope_id": _scope_id("population", realm_id, realm_name),
		"ui_is_renderer_only": true,
	}


func _edge_from_population_edge_packet(raw_edge: Dictionary, population_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	var edge_context: Dictionary = {
		"source_domain": "population",
		"scope_id": _scope_id(
			"population",
			int(population_packet.get("realm_id", -1)),
			str(population_packet.get("realm_name", ""))
		)
	}

	for key in context.keys():
		edge_context [key] = context [key]

	return normalize_edge_packet(raw_edge, edge_context)


func _merge_node_packet(existing_raw: Variant, incoming: Dictionary) -> Dictionary:
	if typeof(existing_raw) != TYPE_DICTIONARY:
		return incoming.duplicate(true)

	var existing: Dictionary = existing_raw as Dictionary
	if existing.is_empty():
		return incoming.duplicate(true)

	var merged: Dictionary = existing.duplicate(true)

	for key in incoming.keys():
		if key == "metadata" and typeof(merged.get("metadata", {})) == TYPE_DICTIONARY and typeof(incoming.get("metadata", {})) == TYPE_DICTIONARY:
			var metadata: Dictionary = merged.get("metadata", {}).duplicate(true)
			var incoming_metadata: Dictionary = incoming.get("metadata", {})
			for metadata_key in incoming_metadata.keys():
				metadata [metadata_key] = incoming_metadata [metadata_key]
			merged ["metadata"] = metadata
		elif key == "stats" and typeof(incoming.get("stats", [])) == TYPE_ARRAY:
			merged ["stats"] = incoming.get("stats", []).duplicate(true)
		elif key == "badges" and typeof(incoming.get("badges", [])) == TYPE_ARRAY:
			merged ["badges"] = incoming.get("badges", []).duplicate(true)
		else:
			merged [key] = incoming [key]

	var layers: Array = []
	if typeof(existing.get("layers", [])) == TYPE_ARRAY:
		layers = existing.get("layers", []).duplicate(true)

	var incoming_domain: String = str(incoming.get("source_domain", "")).strip_edges()
	if incoming_domain != "" and not layers.has(incoming_domain):
		layers.append(incoming_domain)

	merged ["layers"] = layers
	merged ["global_node_merged"] = true

	return merged


func _badges_for_population_card(card_packet: Dictionary) -> Array:
	var badges: Array = []

	if bool(card_packet.get("is_you", false)):
		badges.append({
			"label": "You",
			"badge_type": "player",
			"color_key": "player_self"
		})

	if bool(card_packet.get("is_ruler", false)):
		badges.append({
			"label": "Ruler",
			"badge_type": "ruler",
			"color_key": "royal_gold"
		})
	elif bool(card_packet.get("is_royal", false)):
		badges.append({
			"label": "Royal",
			"badge_type": "royal",
			"color_key": "royal_gold"
		})

	var succession_rank: int = int(card_packet.get("succession_rank", 0))
	if succession_rank > 0:
		badges.append({
			"label": "Succession #%d" % succession_rank,
			"badge_type": "succession",
			"color_key": "succession_gold"
		})

	return badges


func _animation_contract_from_edge(edge: Dictionary) -> Dictionary:
	return {
		"enabled": bool(edge.get("animated_flow", edge.get("animation_enabled", true))),
		"mode": str(edge.get("flow_mode", "pulse_particles")),
		"direction": str(edge.get("flow_direction", "source_to_target")),
		"gradient_slide_enabled": bool(edge.get("gradient_slide_enabled", true)),
		"pulse_travel_enabled": bool(edge.get("pulse_travel_enabled", true)),
		"particles_enabled": bool(edge.get("particles_enabled", true)),
		"parallel_lane_separation_enabled": bool(edge.get("parallel_lane_separation_enabled", true))
	}


func _default_layout_policy(domain: String) -> Dictionary:
	return {
		"domain": domain,
		"anchor_points": ["LEFT", "RIGHT", "TOP", "BOTTOM"],
		"hover_unconnected_nodes_fade_alpha": 0.4,
	}


func _default_edge_policy(domain: String) -> Dictionary:
	return {
		"domain": domain,
		"curve_mode": "cubic_bezier",
	}


func _default_lod_policy(domain: String) -> Dictionary:
	return {
		"domain": domain,
		"default_max_edges": 5,
		"hover_max_edges": 5,
		"expanded_max_edges": 9999,
		"ready_door_may_not_wait": true
	}


func _priority_for_population_card(category: String, card_packet: Dictionary) -> float:
	var priority: float = 0.0

	match category:
		"royal":
			priority += 900.0
		"noble":
			priority += 700.0
		"master":
			priority += 520.0
		_:
			priority += 100.0

	if bool(card_packet.get("is_ruler", false)):
		priority += 300.0
	if bool(card_packet.get("is_you", false)):
		priority += 250.0

	priority += maxf(0.0, 100.0 - float(int(card_packet.get("succession_rank", 100))))

	return priority


func _size_class_for_population_category(category: String, card_packet: Dictionary) -> String:
	if bool(card_packet.get("is_ruler", false)):
		return "hero"

	match category:
		"royal":
			return "large"
		"noble":
			return "medium_large"
		"master":
			return "medium"
		_:
			return "standard"


func _icon_for_population_category(category: String, card_packet: Dictionary) -> String:
	if bool(card_packet.get("is_ruler", false)):
		return "crown"

	match category:
		"royal":
			return "crown"
		"noble":
			return "crest"
		"master":
			return "spark"
		_:
			return "person"


func _color_key_for_population_category(category: String) -> String:
	match category:
		"royal":
			return "royal_gold"
		"noble":
			return "noble_violet"
		"master":
			return "elemental_master"
		_:
			return "citizen_realm"


func _icon_for_domain(domain: String) -> String:
	match domain:
		"population":
			return "person"
		"family":
			return "family"
		"military":
			return "shield"
		"political":
			return "crown"
		"trade":
			return "trade"
		"economy":
			return "market"
		"prison":
			return "bars"
		"hospital":
			return "cross"
		"school":
			return "book"
		"animal":
			return "paw"
		_:
			return "node"


func _color_key_for_edge_type(edge_type: String) -> String:
	match edge_type:
		"succession_heir":
			return "succession_gold"
		"romance":
			return "romance_pink"
		"family":
			return "family_blue"
		"house":
			return "house_violet"
		"political":
			return "political_gold"
		"economic":
			return "economic_green"
		"trade":
			return "trade_green"
		"military":
			return "military_red"
		"conflict":
			return "conflict_red"
		"civic":
			return "civic_tan"
		"social":
			return "social_sky"
		_:
			return "relationship_default"


func _thickness_from_strength(strength: float, importance: float) -> float:
	return clampf(1.15 + (clampf(strength, 0.0, 100.0) / 28.0) + (clampf(importance, 0.0, 1.0) * 0.85), 1.0, 9.0)


func _scope_id(domain: String, numeric_id: int = -1, name: String = "") -> String:
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "generic"

	if numeric_id > 0:
		return "%s:%d" % [clean_domain, numeric_id]

	var clean_name: String = _alias_key(name)
	if clean_name != "":
		return "%s:%s" % [clean_domain, clean_name]

	return ""


func _register_scope_aliases(scope_id: String, aliases: Array) -> void:
	var clean_scope: String = str(scope_id).strip_edges()
	if clean_scope == "":
		return

	for raw_alias in aliases:
		var alias_key: String = _alias_key(str(raw_alias))
		if alias_key == "":
			continue
		alias_to_scope_id [alias_key] = clean_scope


func _resolve_scope_id(scope_id_or_alias: String) -> String:
	var clean: String = str(scope_id_or_alias).strip_edges()
	if clean == "":
		return ""

	if graph_packets_by_scope.has(clean):
		return clean

	var alias_key: String = _alias_key(clean)
	if alias_to_scope_id.has(alias_key):
		return str(alias_to_scope_id.get(alias_key, ""))

	return ""


func _alias_key(value: String) -> String:
	var cleaned: String = str(value).strip_edges().to_lower()
	for ch in [" ", "_", "-", "•", ".", ",", "'", "\"", ":", ";", "/", "\\", "(", ")"]:
		cleaned = cleaned.replace(ch, "")

	return cleaned


func _subscribe_to_game_state() -> void:
	if game_state_subscription_ready:
		return
	if gs == null:
		return
	if not ("event_bus" in gs):
		return
	if gs.event_bus == null:
		return
	if not gs.event_bus.has_method("subscribe"):
		return

	for raw_event_name in [
		"node.truth.changed",
		"population.year.tick",
		"many_realms_realm_created",
		"many_realms_succession",
		"relationship.changed",
		"family.changed",
		"military.changed",
		"trade.changed",
		"political.changed"
	]:
		var event_name: String = str(raw_event_name).strip_edges()
		if event_name == "":
			continue

		gs.event_bus.subscribe(event_name, self, "_on_node_truth_changed", {
			"allow_defer": true,
			"force_immediate": false,
			"lane": "global_node_contract_engine",
			"subscription_id": "global_node_contract_engine:%s" % event_name,
			"subscription_priority": 18,
			"replay_on_subscribe": false
		})

	game_state_subscription_ready = true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["global_node_contract_engine_subscribed_to_game_state"] = true
		gs.scenario_state ["global_node_contract_engine_subscribed_at_ms"] = int(Time.get_ticks_msec())


func _on_node_truth_changed(payload: Dictionary = {}) -> void:
	var scope_id: String = str(payload.get("scope_id", "")).strip_edges()
	if scope_id != "":
		mark_scope_dirty(scope_id, str(payload.get("event_name", "node_truth_changed")))
		return

	var realm_id: int = int(payload.get("realm_id", payload.get("target_realm_id", -1)))
	var domain: String = str(payload.get("domain", payload.get("source_domain", "population"))).strip_edges().to_lower()
	if realm_id > 0:
		mark_scope_dirty(_scope_id(domain, realm_id), str(payload.get("event_name", "node_truth_changed")))


func _commit_registry() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["global_node_contract_engine_registry"] = export_registry()
	gs.scenario_state ["global_node_contract_engine_registry_count"] = graph_packets_by_scope.size()
	gs.scenario_state ["global_node_contract_engine_node_count"] = node_packets_by_id.size()
	gs.scenario_state ["global_node_contract_engine_hot"] = graph_packets_by_scope.size() > 0
	gs.scenario_state ["canonical_node_graph_registry"] = graph_packets_by_scope.duplicate(true)
	gs.scenario_state ["canonical_node_packets_by_id"] = node_packets_by_id.duplicate(true)
	gs.scenario_state ["global_node_contract_engine_ready_door_may_not_wait"] = true
	gs.scenario_state ["global_node_contract_engine_ui_is_renderer_only"] = true


func _value(source, key: String, fallback = null):
	if source == null:
		return fallback

	if typeof(source) == TYPE_DICTIONARY:
		return (source as Dictionary).get(key, fallback)

	if key in source:
		return source.get(key)

	return fallback


func _fail(reason: String, source_domain: String = "", context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	last_ingest_report = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"reason": reason,
		"source_domain": source_domain,
		"context": context.duplicate(true),
		"reported_at_ms": int(Time.get_ticks_msec()),
		"ready_door_may_not_wait": true
	}

	_commit_registry()

	return last_ingest_report.duplicate(true)