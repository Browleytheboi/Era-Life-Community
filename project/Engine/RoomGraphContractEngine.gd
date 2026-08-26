extends Resource
class_name RoomGraphContractEngine
const ENGINE_SCHEMA:= "eralife.room_graph_contract_engine"
const TOPOLOGY_SCHEMA:= "eralife.property.spatial_topology_contract"
const NODE_SCHEMA:= "eralife.property.spatial_node_contract"
const EDGE_SCHEMA:= "eralife.property.spatial_edge_contract"
const CONTRACT_VERSION:= 2
var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	gs = _gs

func _repair_observable_navigation_contract(
	actor: Person,
	prop: Dictionary,
	node: Dictionary,
	topology: Dictionary,
	active_room: String
) -> Dictionary:
	if topology.is_empty():
		return {
			"topology": topology,
			"active_room": "",
			"current_room": {},
			"navigation_actions": [],
			"repaired": false,
			"topology_repair_required": true,
			"repair_mode": "missing_resident_topology",
		}

	var nodes_raw: Variant = topology.get(
		"nodes",
		{}
	)
	var topology_nodes: Dictionary = (
		nodes_raw as Dictionary
		if typeof(nodes_raw) == TYPE_DICTIONARY
		else {}
	)
	var resolved_active_room: String = (
		active_room.strip_edges()
	)
	var current_room: Dictionary = _topology_node(
		topology,
		resolved_active_room
	)
	var cursor_rebased: bool = false
	var cursor_rebase_reason: String = ""

	if (
		current_room.is_empty()
		or bool(
			current_room.get(
				"removed",
				false
			)
		)
	):
		var entry_node_id: String = str(
			topology.get(
				"entry_node_id",
				""
			)
		).strip_edges()
		var entry_room: Dictionary = _topology_node(
			topology,
			entry_node_id
		)

		if (
			not entry_room.is_empty()
			and not bool(
				entry_room.get(
					"removed",
					false
				)
			)
		):
			resolved_active_room = entry_node_id
			current_room = entry_room
			cursor_rebased = true
			cursor_rebase_reason = (
				"invalid_cursor_rebased_to_entry"
			)
		else:
			var first_room: Dictionary = (
				_first_observable_topology_node(
					topology
				)
			)

			if not first_room.is_empty():
				resolved_active_room = str(
					first_room.get(
						"node_id",
						""
					)
				).strip_edges()
				current_room = first_room
				cursor_rebased = true
				cursor_rebase_reason = (
					"invalid_cursor_rebased_to_first_observable_node"
				)

	if cursor_rebased:
		node ["active_room"] = resolved_active_room
		node ["active_floor"] = int(
			current_room.get(
				"floor_index",
				node.get(
					"active_floor",
					0
				)
			)
		)
		node ["room_graph_cursor_rebased"] = true
		node ["room_graph_cursor_rebase_reason"] = (
			cursor_rebase_reason
		)
		node ["room_graph_cursor_rebased_at_ms"] = int(
			Time.get_ticks_msec()
		)







	if not current_room.is_empty():
		var observable_current_room: Dictionary = (
			current_room.duplicate(false)
		)

		observable_current_room ["connections"] = (
			_adjacent_node_ids(
				topology,
				resolved_active_room
			)
		)
		observable_current_room ["adjacent_nodes"] = (
			_adjacent_node_summaries(
				topology,
				resolved_active_room
			)
		)
		observable_current_room [
			"adjacency_projection_authority"
		] = ENGINE_SCHEMA
		observable_current_room [
			"adjacency_derived_from_resident_topology_edges"
		] = true
		observable_current_room [
			"adjacency_projection_rebuilt_topology"
		] = false

		current_room = observable_current_room

	var navigation_actions: Array = _navigation_actions(
		actor,
		prop,
		topology,
		resolved_active_room
	)

	var topology_repair_required: bool = (
		topology_nodes.size() > 1
		and navigation_actions.is_empty()
	)

	if topology_repair_required:
		node ["room_graph_topology_repair_required"] = true
		node ["room_graph_topology_repair_reason"] = (
			"multi_node_topology_has_no_observable_edge"
		)
		node ["room_graph_topology_repair_requested_at_ms"] = int(
			Time.get_ticks_msec()
		)
		node [
			"room_graph_topology_repair_must_run_outside_observation"
		] = true
	else:
		node ["room_graph_topology_repair_required"] = false
		node ["room_graph_topology_repair_reason"] = ""

	return {
		"topology": topology,
		"active_room": resolved_active_room,
		"current_room": current_room,
		"navigation_actions": navigation_actions,
		"repaired": cursor_rebased,
		"cursor_rebased": cursor_rebased,
		"cursor_rebase_reason": cursor_rebase_reason,
		"topology_repair_required": topology_repair_required,
		"repair_mode": (
			cursor_rebase_reason
			if cursor_rebased
			else (
				"background_topology_repair_required"
				if topology_repair_required
				else "resident_topology_valid"
			)
		),
	}
func emit_room_graph_contract(
	actor: Person,
	prop: Dictionary,
	node: Dictionary
) -> Dictionary:

	var topology: Dictionary = _ensure_property_topology(
		prop,
		node
	)

	var floors_raw: Variant = node.get(
		"floors",
		[]
	)
	var floors: Array = (
		floors_raw as Array
		if typeof(floors_raw) == TYPE_ARRAY
		else []
	)
	if floors.is_empty():
		floors = _floors_from_topology(
			topology
		)
		node ["floors"] = floors

	var entry_node_id: String = str(
		topology.get(
			"entry_node_id",
			""
		)
	).strip_edges()

	var active_floor: int = int(
		node.get(
			"active_floor",
			0
		)
	)
	var active_room: String = str(
		node.get(
			"active_room",
			entry_node_id
		)
	).strip_edges()

	var actor_locations_raw: Variant = node.get(
		"actor_locations",
		{}
	)
	var actor_locations: Dictionary = (
		actor_locations_raw as Dictionary
		if typeof(actor_locations_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		actor != null
		and actor_locations.has(
			str(
				int(actor.id)
			)
		)
	):
		var actor_location_raw: Variant = (
			actor_locations.get(
				str(
					int(actor.id)
				),
				{}
			)
		)
		if typeof(actor_location_raw) == TYPE_DICTIONARY:
			var actor_location: Dictionary = (
				actor_location_raw as Dictionary
			)
			if str(
				actor_location.get(
					"authority",
					""
				)
			) == (
				"eralife.spatial_traversal_contract_engine"
			):
				active_floor = int(
					actor_location.get(
						"floor",
						active_floor
					)
				)
				active_room = str(
					actor_location.get(
						"room",
						active_room
					)
				).strip_edges()

	var navigation_resolution: Dictionary = (
		_repair_observable_navigation_contract(
			actor,
			prop,
			node,
			topology,
			active_room
		)
	)

	active_room = str(
		navigation_resolution.get(
			"active_room",
			active_room
		)
	).strip_edges()

	var current_room_raw: Variant = (
		navigation_resolution.get(
			"current_room",
			{}
		)
	)
	var current_room: Dictionary = (
		current_room_raw as Dictionary
		if typeof(current_room_raw) == TYPE_DICTIONARY
		else {}
	)

	if not current_room.is_empty():
		active_floor = int(
			current_room.get(
				"floor_index",
				active_floor
			)
		)

	var navigation_raw: Variant = (
		navigation_resolution.get(
			"navigation_actions",
			[]
		)
	)
	var navigation_actions: Array = (
		navigation_raw as Array
		if typeof(navigation_raw) == TYPE_ARRAY
		else []
	)

	var interaction_actions: Array = (
		_room_interaction_actions(
			actor,
			prop,
			topology,
			current_room
		)
	)
	var surroundings: Array = (
		_surroundings_for_topology_node(
			actor,
			prop,
			topology,
			active_room,
			current_room
		)
	)

	node ["spatial_topology"] = topology
	node ["floors"] = floors
	node ["active_floor"] = active_floor
	node ["active_room"] = active_room
	node ["topology_version"] = CONTRACT_VERSION
	node ["structure_authority"] = ENGINE_SCHEMA

	return {
		"schema": (
			"eralife.room_graph.observable_contract"
		),
		"version": CONTRACT_VERSION,
		"property_id": int(
			prop.get(
				"id",
				prop.get(
					"property_id",
					-1
				)
			)
		),
		"navigation_crr_repaired": bool(
			navigation_resolution.get(
				"repaired",
				false
			)
		),
		"navigation_crr_repair_mode": str(
			navigation_resolution.get(
				"repair_mode",
				""
			)
		),
		"navigation_topology_repair_required": bool(
			navigation_resolution.get(
				"topology_repair_required",
				false
			)
		),
		"entry_node_id": entry_node_id,
		"spatial_topology": topology,
		"topology_nodes": topology.get(
			"nodes",
			{}
		),
		"topology_edges": topology.get(
			"edges",
			[]
		),
		"layout_key": str(
			topology.get(
				"layout_key",
				"unknown"
			)
		),
		"layout_signature": str(
			topology.get(
				"layout_signature",
				""
			)
		),
		"floors": floors,
		"active_floor": active_floor,
		"active_room": active_room,
		"current_room": current_room,
		"navigation_actions": navigation_actions,
		"room_navigation_actions": navigation_actions,
		"movement_options": navigation_actions,
		"spatial_movement_actions": navigation_actions,
		"room_interaction_actions": interaction_actions,
		"spatial_description": _spatial_description(
			prop,
			floors,
			active_floor,
			active_room,
			current_room
		),
		"surroundings": surroundings,
		"actor_locations": actor_locations,
		"reality_node": node,
		"truth_state": (
			"observable_partial"
			if bool(
				navigation_resolution.get(
					"topology_repair_required",
					false
				)
			)
			else "observable"
		),
		"graph_rebuild_performed": false,
		"structure_authority": ENGINE_SCHEMA,
		"mutation_authority": (
			"eralife.spatial_traversal_contract_engine"
		),
		"ui_is_renderer_only": true
	}
func project_resident_room_contract(
	actor: Person,
	prop: Dictionary,
	node: Dictionary
) -> Dictionary:
	var topology_raw: Variant = node.get(
		"spatial_topology",
		{}
	)
	if typeof(topology_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"resident_graph_hot": false,
			"reason": "missing_resident_topology",
			"graph_rebuild_performed": false,
			"structure_authority": ENGINE_SCHEMA
		}

	var topology: Dictionary = (
		topology_raw as Dictionary
	)
	if topology.is_empty():
		return {
			"success": false,
			"resident_graph_hot": false,
			"reason": "empty_resident_topology",
			"graph_rebuild_performed": false,
			"structure_authority": ENGINE_SCHEMA
		}

	var floors_raw: Variant = node.get(
		"floors",
		[]
	)
	var floors: Array = (
		floors_raw as Array
		if typeof(floors_raw) == TYPE_ARRAY
		else []
	)

	var entry_node_id: String = str(
		topology.get(
			"entry_node_id",
			""
		)
	).strip_edges()
	var active_room: String = str(
		node.get(
			"active_room",
			entry_node_id
		)
	).strip_edges()

	var validation: Dictionary = (
		_repair_observable_navigation_contract(
			actor,
			prop,
			node,
			topology,
			active_room
		)
	)

	active_room = str(
		validation.get(
			"active_room",
			active_room
		)
	).strip_edges()

	var current_room_raw: Variant = validation.get(
		"current_room",
		{}
	)
	var current_room: Dictionary = (
		current_room_raw as Dictionary
		if typeof(current_room_raw) == TYPE_DICTIONARY
		else {}
	)
	var active_floor: int = int(
		current_room.get(
			"floor_index",
			node.get(
				"active_floor",
				0
			)
		)
	)

	var navigation_raw: Variant = validation.get(
		"navigation_actions",
		[]
	)
	var navigation_actions: Array = (
		navigation_raw as Array
		if typeof(navigation_raw) == TYPE_ARRAY
		else []
	)

	var interaction_actions: Array = (
		_room_interaction_actions(
			actor,
			prop,
			topology,
			current_room
		)
	)
	var surroundings: Array = (
		_surroundings_for_topology_node(
			actor,
			prop,
			topology,
			active_room,
			current_room
		)
	)

	var actor_locations_raw: Variant = node.get(
		"actor_locations",
		{}
	)
	var actor_locations: Dictionary = (
		actor_locations_raw as Dictionary
		if typeof(actor_locations_raw) == TYPE_DICTIONARY
		else {}
	)

	return {
		"success": true,
		"schema": (
			"eralife.property.resident_graph_cursor"
		),
		"version": CONTRACT_VERSION,
		"property_id": int(
			prop.get(
				"id",
				node.get(
					"property_id",
					-1
				)
			)
		),
		"spatial_topology": topology,
		"floors": floors,
		"entry_node_id": entry_node_id,
		"active_floor": active_floor,
		"active_room": active_room,
		"current_room": current_room,
		"navigation_actions": navigation_actions,
		"room_navigation_actions": navigation_actions,
		"movement_options": navigation_actions,
		"spatial_movement_actions": navigation_actions,
		"room_interaction_actions": interaction_actions,
		"actor_locations": actor_locations,
		"spatial_description": _spatial_description(
			prop,
			floors,
			active_floor,
			active_room,
			current_room
		),
		"surroundings": surroundings,
		"cursor_revision": int(
			node.get(
				"cursor_revision",
				0
			)
		),
		"resident_graph_hot": (
			not current_room.is_empty()
		),
		"topology_repair_required": bool(
			validation.get(
				"topology_repair_required",
				false
			)
		),
		"graph_rebuild_performed": false,
		"structure_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _entry_room_for_floor(floors: Array, floor_index: int) -> Dictionary:
	var rooms: Array = _rooms_on_floor(floors, floor_index)
	if rooms.is_empty():
		return {}

	for raw_room in rooms:
		var room: Dictionary = _safe_dictionary(raw_room)
		var room_id: String = str(room.get("room_id", "")).to_lower()
		if room_id in ["entryway", "foyer", "entrance_hall", "main_entrance", "north_portico"]:
			return room

	return _safe_dictionary(rooms [0])


func commit_navigation(_actor: Person, prop: Dictionary, node: Dictionary, payload: Dictionary) -> Dictionary:
	var repaired_node: Dictionary = node.duplicate(true)
	var graph: Dictionary = emit_room_graph_contract(_actor, prop, repaired_node)

	repaired_node ["floors"] = _safe_array(graph.get("floors", repaired_node.get("floors", [])))
	repaired_node ["room_graph_navigation_commit_denied"] = true
	repaired_node ["room_graph_navigation_commit_denied_reason"] = "RoomGraphContractEngine is structure authority only. SpatialTraversalContractEngine owns movement mutation."
	repaired_node ["room_graph_navigation_commit_denied_payload"] = payload.duplicate(true)
	repaired_node ["room_graph_navigation_commit_denied_at_ms"] = int(Time.get_ticks_msec())
	repaired_node ["movement_authority"] = "eralife.spatial_traversal_contract_engine"

	return repaired_node


func _ensure_floors(
	prop: Dictionary,
	node: Dictionary
) -> Array:
	var topology: Dictionary = _ensure_property_topology(
		prop,
		node
	)

	return _floors_from_topology(topology)
func _ensure_property_topology(
	prop: Dictionary,
	node: Dictionary
) -> Dictionary:
	var profile: Dictionary = _property_spatial_profile(
		prop,
		node
	)
	var desired_layout_key: String = _resolve_layout_key(
		profile
	)

	var existing_raw: Variant = node.get(
		"spatial_topology",
		{}
	)
	var existing_topology: Dictionary = (
		existing_raw as Dictionary
		if typeof(existing_raw) == TYPE_DICTIONARY
		else {}
	)

	if not existing_topology.is_empty():
		var existing_layout_key: String = str(
			existing_topology.get(
				"layout_key",
				""
			)
		)

		if existing_layout_key == desired_layout_key:
			var resident_floors_raw: Variant = node.get(
				"floors",
				[]
			)
			if (
				typeof(resident_floors_raw) != TYPE_ARRAY
				or (
					resident_floors_raw as Array
				).is_empty()
			):
				node ["floors"] = _floors_from_topology(
					existing_topology
				)

			node ["spatial_topology"] = existing_topology
			node ["topology_version"] = CONTRACT_VERSION
			node ["structure_authority"] = ENGINE_SCHEMA
			node ["resident_topology_reference_reused"] = true
			return existing_topology



		var mutation_history_raw: Variant = (
			existing_topology.get(
				"mutation_history",
				[]
			)
		)
		var mutation_history: Array = (
			mutation_history_raw as Array
			if typeof(mutation_history_raw) == TYPE_ARRAY
			else []
		)

		var rebuilt: Dictionary = (
			_build_topology_from_property_contract(
				prop,
				node,
				profile,
				desired_layout_key
			)
		)

		for raw_mutation in mutation_history:
			if typeof(raw_mutation) != TYPE_DICTIONARY:
				continue

			var replay_report: Dictionary = (
				_apply_topology_mutation_to_contract(
					rebuilt,
					raw_mutation as Dictionary,
					null,
					prop,
					false
				)
			)
			if bool(
				replay_report.get(
					"success",
					false
				)
			):
				var replayed_raw: Variant = (
					replay_report.get(
						"topology",
						rebuilt
					)
				)
				if typeof(replayed_raw) == TYPE_DICTIONARY:
					rebuilt = replayed_raw as Dictionary

		node ["spatial_topology"] = rebuilt
		node ["floors"] = _floors_from_topology(
			rebuilt
		)
		node ["topology_version"] = CONTRACT_VERSION
		node ["structure_authority"] = ENGINE_SCHEMA
		node ["topology_migrated_outside_traversal"] = true
		return rebuilt

	var existing_floors_raw: Variant = node.get(
		"floors",
		[]
	)
	var existing_floors: Array = (
		existing_floors_raw as Array
		if typeof(existing_floors_raw) == TYPE_ARRAY
		else []
	)

	if (
		not existing_floors.is_empty()
		and _floor_graph_has_movement(
			existing_floors
		)
	):
		var migrated: Dictionary = (
			_topology_from_existing_floors(
				prop,
				node,
				existing_floors,
				profile,
				desired_layout_key
			)
		)
		node ["spatial_topology"] = migrated
		node ["floors"] = _floors_from_topology(
			migrated
		)
		node ["topology_version"] = CONTRACT_VERSION
		node ["structure_authority"] = ENGINE_SCHEMA
		node ["legacy_floor_graph_migrated_once"] = true
		return migrated

	var topology: Dictionary = (
		_build_topology_from_property_contract(
			prop,
			node,
			profile,
			desired_layout_key
		)
	)

	node ["spatial_topology"] = topology
	node ["floors"] = _floors_from_topology(
		topology
	)
	node ["topology_version"] = CONTRACT_VERSION
	node ["structure_authority"] = ENGINE_SCHEMA
	node ["cold_topology_hydration_complete"] = true

	return topology
func apply_topology_mutation(
	actor: Person,
	prop: Dictionary,
	node: Dictionary,
	mutation: Dictionary
) -> Dictionary:
	var mutation_kind: String = str(
		mutation.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	if mutation_kind in [
		"lock_edge",
		"unlock_edge",
		"bolt_edge",
		"unbolt_edge"
	]:
		var topology_raw: Variant = node.get(
			"spatial_topology",
			{}
		)
		if typeof(topology_raw) != TYPE_DICTIONARY:
			return {
				"success": false,
				"reason": "missing_resident_topology",
				"node": node,
				"structure_authority": ENGINE_SCHEMA,
				"full_topology_copy_performed": false
			}

		var resident_topology: Dictionary = (
			topology_raw as Dictionary
		)
		var security_report: Dictionary = (
			_apply_edge_security_mutation(
				resident_topology,
				mutation,
				actor,
				prop
			)
		)

		security_report ["node"] = node
		security_report ["topology"] = resident_topology
		security_report ["floors"] = node.get(
			"floors",
			[]
		)
		security_report ["structure_authority"] = (
			ENGINE_SCHEMA
		)
		security_report [
			"full_topology_copy_performed"
		] = false
		security_report [
			"floors_rebuilt"
		] = false
		security_report [
			"rooms_reflattened"
		] = false
		security_report [
			"changed_edge_branch_only"
		] = true

		if bool(
			security_report.get(
				"success",
				false
			)
		):
			node ["last_topology_mutation"] = (
				mutation.duplicate(false)
			)
			node ["last_topology_mutation_at_ms"] = int(
				Time.get_ticks_msec()
			)
			node ["structure_authority"] = ENGINE_SCHEMA

		return security_report



	var updated_node: Dictionary = node.duplicate(true)
	var topology: Dictionary = _ensure_property_topology(
		prop,
		updated_node
	)
	var report: Dictionary = (
		_apply_topology_mutation_to_contract(
			topology,
			mutation,
			actor,
			prop,
			true
		)
	)

	if not bool(
		report.get(
			"success",
			false
		)
	):
		report ["node"] = updated_node
		report ["structure_authority"] = ENGINE_SCHEMA
		return report

	var updated_topology_raw: Variant = report.get(
		"topology",
		topology
	)
	var updated_topology: Dictionary = (
		updated_topology_raw as Dictionary
		if typeof(updated_topology_raw) == TYPE_DICTIONARY
		else topology
	)

	updated_node ["spatial_topology"] = updated_topology
	updated_node ["floors"] = _floors_from_topology(
		updated_topology
	)
	updated_node ["rooms"] = _flatten_floor_rooms(
		updated_node ["floors"] as Array
	)
	updated_node ["topology_version"] = CONTRACT_VERSION
	updated_node ["last_topology_mutation"] = (
		mutation.duplicate(true)
	)
	updated_node ["last_topology_mutation_at_ms"] = int(
		Time.get_ticks_msec()
	)
	updated_node ["structure_authority"] = ENGINE_SCHEMA

	report ["node"] = updated_node
	report ["topology"] = updated_topology
	report ["floors"] = updated_node.get(
		"floors",
		[]
	)
	report ["structure_authority"] = ENGINE_SCHEMA
	report ["changed_edge_branch_only"] = false
	report ["structural_background_mutation"] = true
	return report
func _apply_edge_security_mutation(
	topology: Dictionary,
	mutation: Dictionary,
	actor: Person,
	prop: Dictionary
) -> Dictionary:
	var edge_id: String = str(
		mutation.get(
			"edge_id",
			""
		)
	).strip_edges()
	if edge_id == "":
		return {
			"success": false,
			"reason": "missing_edge_id"
		}

	var edges_raw: Variant = topology.get(
		"edges",
		[]
	)
	if typeof(edges_raw) != TYPE_ARRAY:
		return {
			"success": false,
			"reason": "missing_topology_edges"
		}

	var edges: Array = edges_raw as Array
	var mutation_kind: String = str(
		mutation.get(
			"kind",
			""
		)
	).strip_edges().to_lower()
	var securing: bool = mutation_kind in [
		"lock_edge",
		"bolt_edge"
	]

	var requested_mode: String = str(
		mutation.get(
			"security_mode",
			""
		)
	).strip_edges().to_lower()
	var security_mode: String = (
		requested_mode
		if requested_mode in [
			"lock",
			"bolt"
		]
		else _property_security_mode(
			prop
		)
	)

	for edge_index in range(
		edges.size()
	):
		var edge_raw: Variant = edges [
			edge_index
		]
		if typeof(edge_raw) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = edge_raw as Dictionary
		if str(
			edge.get(
				"edge_id",
				""
			)
		) != edge_id:
			continue

		if not _actor_can_control_door(
			actor,
			prop,
			edge
		):
			return {
				"success": false,
				"reason": "door_control_denied",
				"edge_id": edge_id,
				"security_mode": security_mode
			}

		if not _edge_is_securable(
			edge
		):
			return {
				"success": false,
				"reason": "door_not_securable",
				"edge_id": edge_id,
				"security_mode": security_mode
			}

		var door_raw: Variant = edge.get(
			"door_contract",
			{}
		)
		var door_contract: Dictionary = (
			door_raw as Dictionary
			if typeof(door_raw) == TYPE_DICTIONARY
			else {}
		)

		door_contract ["security_mode"] = security_mode
		door_contract ["secured"] = securing
		door_contract ["locked"] = (
			securing
			and security_mode == "lock"
		)
		door_contract ["bolted"] = (
			securing
			and security_mode == "bolt"
		)
		door_contract ["secured_by_actor_id"] = (
			int(actor.id)
			if securing and actor != null
			else -1
		)
		door_contract ["locked_by_actor_id"] = (
			int(actor.id)
			if (
				securing
				and security_mode == "lock"
				and actor != null
			)
			else -1
		)
		door_contract ["security_changed_at_ms"] = int(
			Time.get_ticks_msec()
		)

		if actor != null:
			var holders_raw: Variant = (
				door_contract.get(
					"key_holder_ids",
					[]
				)
			)
			var key_holder_ids: Array = (
				holders_raw as Array
				if typeof(holders_raw) == TYPE_ARRAY
				else []
			)
			if not key_holder_ids.has(
				int(actor.id)
			):
				key_holder_ids.append(
					int(actor.id)
				)
			door_contract ["key_holder_ids"] = (
				key_holder_ids
			)

		edge ["door_contract"] = door_contract
		edge ["security_mode"] = security_mode
		edge ["secured"] = securing
		edges [edge_index] = edge
		topology ["edges"] = edges
		topology ["updated_at_ms"] = int(
			Time.get_ticks_msec()
		)

		var history_raw: Variant = topology.get(
			"mutation_history",
			[]
		)
		var history: Array = (
			history_raw as Array
			if typeof(history_raw) == TYPE_ARRAY
			else []
		)
		var receipt: Dictionary = {
			"kind": mutation_kind,
			"edge_id": edge_id,
			"security_mode": security_mode,
			"secured": securing,
			"committed_at_ms": int(
				Time.get_ticks_msec()
			),
			"committed_by_actor_id": (
				int(actor.id)
				if actor != null
				else -1
			)
		}
		history.append(
			receipt
		)
		topology ["mutation_history"] = history

		return {
			"success": true,
			"reason": (
				"edge_secured"
				if securing
				else "edge_released"
			),
			"edge_id": edge_id,
			"security_mode": security_mode,
			"secured": securing,
			"changed_edge": edge,
			"changed_edge_branch_only": true,
			"structure_authority": ENGINE_SCHEMA
		}

	return {
		"success": false,
		"reason": "missing_edge",
		"edge_id": edge_id,
		"security_mode": security_mode
	}
func resolve_edge_traversal_contract(
	actor: Person,
	prop: Dictionary,
	topology: Dictionary,
	from_node_id: String,
	to_node_id: String
) -> Dictionary:
	var edge: Dictionary = _edge_between(
		topology,
		from_node_id,
		to_node_id
	)
	if edge.is_empty():
		return {
			"allowed": false,
			"reason": "not_connected",
			"narrative": (
				"That destination is not connected to where you are standing."
			),
			"constraints": [
				"spatial_edge_required"
			]
		}

	var target_node: Dictionary = _topology_node(
		topology,
		to_node_id
	)
	if (
		target_node.is_empty()
		or bool(
			target_node.get(
				"removed",
				false
			)
		)
	):
		return {
			"allowed": false,
			"reason": "missing_target_node",
			"narrative": (
				"That space no longer exists in this property topology."
			),
			"constraints": [
				"target_node_must_exist"
			],
			"edge": edge
		}

	var target_state: String = str(
		target_node.get(
			"state",
			"intact"
		)
	).strip_edges().to_lower()

	if target_state in [
		"destroyed",
		"unsafe",
		"locked_off",
		"collapsed"
	]:
		return {
			"allowed": false,
			"reason": "target_%s" % target_state,
			"narrative": (
				"%s is currently %s and cannot be entered."
				% [
					str(
						target_node.get(
							"title",
							"That space"
						)
					),
					target_state.replace(
						"_",
						" "
					)
				]
			),
			"constraints": [
				"target_space_%s" % target_state
			],
			"edge": edge,
			"target_node": target_node
		}

	if not bool(
		edge.get(
			"enabled",
			true
		)
	):
		return {
			"allowed": false,
			"reason": str(
				edge.get(
					"blocked_reason",
					"edge_disabled"
				)
			),
			"narrative": str(
				edge.get(
					"blocked_text",
					"That route is blocked right now."
				)
			),
			"constraints": [
				"edge_enabled_required"
			],
			"edge": edge,
			"target_node": target_node
		}

	var tokens: Array = _actor_authority_tokens(
		actor,
		prop
	)
	var requirements_raw: Variant = edge.get(
		"ownership_requirements",
		[]
	)
	var requirements: Array = (
		(requirements_raw as Array).duplicate(false)
		if typeof(requirements_raw) == TYPE_ARRAY
		else []
	)

	var target_requirements_raw: Variant = target_node.get(
		"ownership_requirements",
		[]
	)
	if typeof(target_requirements_raw) == TYPE_ARRAY:
		for raw_requirement in (
			target_requirements_raw as Array
		):
			var requirement: String = str(
				raw_requirement
			)
			if (
				requirement != ""
				and not requirements.has(
					requirement
				)
			):
				requirements.append(
					requirement
				)

	if not _requirements_satisfied(
		requirements,
		tokens
	):
		return {
			"allowed": false,
			"reason": "ownership_access_denied",
			"narrative": (
				"Your current ownership contract does not unlock %s."
				% str(
					target_node.get(
						"title",
						"that space"
					)
				)
			),
			"constraints": requirements,
			"edge": edge,
			"target_node": target_node
		}

	if _edge_is_secured(
		edge
	):
		var security_mode: String = (
			_edge_security_mode(
				prop,
				edge
			)
		)
		var release_action_id: String = (
			_edge_security_action_id(
				security_mode,
				true
			)
		)

		return {
			"allowed": false,
			"reason": (
				"door_bolted"
				if security_mode == "bolt"
				else "door_locked"
			),
			"narrative": (
				"You must unbolt the passage to %s before entering."
				% str(
					target_node.get(
						"title",
						"that space"
					)
				)
				if security_mode == "bolt"
				else (
					"You must unlock the door to %s before entering."
					% str(
						target_node.get(
							"title",
							"that space"
						)
					)
				)
			),
			"constraints": [
				"secured_edge_must_be_released_before_traversal"
			],
			"edge": edge,
			"target_node": target_node,
			"security_mode": security_mode,
			"release_action_id": release_action_id,
			"actor_can_release": (
				_actor_can_control_door(
					actor,
					prop,
					edge
				)
			)
		}

	var access_level: String = str(
		target_node.get(
			"access_level",
			"household"
		)
	).strip_edges().to_lower()

	if not _access_level_allowed(
		access_level,
		tokens
	):
		return {
			"allowed": false,
			"reason": "access_level_denied",
			"narrative": (
				"You do not have access to %s."
				% str(
					target_node.get(
						"title",
						"that space"
					)
				)
			),
			"constraints": [
				access_level
			],
			"edge": edge,
			"target_node": target_node
		}

	return {
		"allowed": true,
		"reason": "allowed",
		"narrative": (
			"The route is physically and contractually available."
		),
		"constraints": [],
		"edge": edge,
		"target_node": target_node
	}
func _property_spatial_profile(
	prop: Dictionary,
	node: Dictionary
) -> Dictionary:
	var identity: Dictionary = _safe_dictionary(
		node.get("identity", {})
	)
	var operational_profile: Dictionary = _safe_dictionary(
		prop.get("operational_profile", {})
	)
	var era_text: String = "%s %s %s" % [
		str(prop.get("era_name", "")),
		str(prop.get("era", "")),
		str(identity.get("era", ""))
	]

	if (
		era_text.strip_edges() == ""
		and gs != null
		and gs.era != null
	):
		era_text = str(gs.era.name)

	var era_key: String = _era_key_from_text(
		era_text
	)
	var subtype: String = str(
		prop.get(
			"subtype",
			prop.get("type", "dwelling")
		)
	).strip_edges().to_lower()
	var category: String = str(
		prop.get(
			"category",
			prop.get("archetype", "residential")
		)
	).strip_edges().to_lower()
	var realm_key: String = "%s %s %s %s" % [
		str(prop.get("realm_name", "")),
		str(prop.get("realm_key", "")),
		str(prop.get("region", "")),
		str(prop.get("country", ""))
	]
	realm_key = realm_key.strip_edges().to_lower()

	var searchable_text: String = "%s %s %s %s %s %s" % [
		str(prop.get("display_name", "")),
		str(prop.get("name", "")),
		str(prop.get("type", "")),
		subtype,
		category,
		realm_key
	]
	searchable_text = searchable_text.to_lower()

	return {
		"era_key": era_key,
		"subtype": subtype,
		"category": category,
		"realm_key": realm_key,
		"searchable_text": searchable_text,
		"bedrooms": int(
			prop.get(
				"bedrooms",
				operational_profile.get(
					"bedrooms",
					_bedroom_count_for_property(prop)
				)
			)
		),
		"bathrooms": int(
			prop.get(
				"bathrooms",
				operational_profile.get(
					"bathrooms",
					_bathroom_count_for_property(prop)
				)
			)
		),
		"value": int(
			prop.get(
				"value",
				prop.get("price", 0)
			)
		),
		"social_tier": str(
			prop.get("social_tier", "")
		).to_lower(),
		"feature_tags": _safe_array(
			prop.get("feature_tags", [])
		),
		"amenity_ids": _safe_array(
			prop.get("amenity_ids", [])
		),
		"ownership_status": str(
			prop.get(
				"ownership_status",
				prop.get("legal_status", "owned")
			)
		).to_lower()
	}


func _resolve_layout_key(
	profile: Dictionary
) -> String:
	var text: String = str(
		profile.get(
			"searchable_text",
			""
		)
	).strip_edges().to_lower()

	var era_key: String = str(
		profile.get(
			"era_key",
			"modern"
		)
	).strip_edges().to_lower()

	var subtype: String = str(
		profile.get(
			"subtype",
			""
		)
	).strip_edges().to_lower()

	var category: String = str(
		profile.get(
			"category",
			"residential"
		)
	).strip_edges().to_lower()

	var realm_key: String = str(
		profile.get(
			"realm_key",
			""
		)
	).strip_edges().to_lower()

	if (
		text.find(
			"white house"
		) >= 0
		or text.find(
			"official_residence_white_house"
		) >= 0
	):
		return "official_residence_white_house"



	if (
		category == "arcade"
		or subtype == "arcade"
		or subtype == "commercial_arcade"
		or text.find(
			"arcade"
		) >= 0
	):
		return "arcade"

	if (
		(
			text.find(
				"air"
			) >= 0
			or realm_key.find(
				"air"
			) >= 0
		)
		and (
			text.find(
				"temple"
			) >= 0
			or category == "religious"
		)
	):
		return "air_nomad_temple"

	if (
		era_key == "ancient"
		and (
			text.find(
				"domus"
			) >= 0
			or subtype == "noble_villa"
			or text.find(
				"roman villa"
			) >= 0
		)
	):
		return "roman_domus"

	if (
		era_key == "ancient"
		and (
			text.find(
				"insula"
			) >= 0
			or text.find(
				"apartment"
			) >= 0
			or subtype in [
				"tenement",
				"micro_apartment"
			]
		)
	):
		return "roman_insula"

	if (
		text.find(
			"castle"
		) >= 0
		or subtype in [
			"castle",
			"earth_fortress",
			"sky_castle"
		]
	):
		return (
			"medieval_castle"
			if era_key in [
				"ancient",
				"medieval"
			]
			else "palace"
		)

	if (
		text.find(
			"palace"
		) >= 0
		or category == "royal"
	):
		return "palace"

	if (
		text.find(
			"mansion"
		) >= 0
		or subtype in [
			"country_estate",
			"lake_house",
			"beach_house"
		]
	):
		return "modern_mansion"

	if (
		subtype in [
			"tiny_house",
			"micro_habitat",
			"mobile_home"
		]
		or text.find(
			"tiny house"
		) >= 0
	):
		return "tiny_house"

	if (
		text.find(
			"apartment"
		) >= 0
		or text.find(
			"penthouse"
		) >= 0
		or subtype in [
			"loft_apartment",
			"studio_apartment",
			"micro_apartment",
			"tenement"
		]
	):
		return "apartment_building"

	if (
		text.find(
			"temple"
		) >= 0
		or text.find(
			"shrine"
		) >= 0
		or category == "religious"
	):
		return "temple"

	if (
		text.find(
			"cabin"
		) >= 0
		or text.find(
			"tree house"
		) >= 0
		or text.find(
			"cave dwelling"
		) >= 0
	):
		return "cabin"

	if era_key == "future":
		return "future_procedural"

	return "%s_dwelling" % era_key
func _arcade_blueprint() -> Dictionary:
	return {
		"entry_node_id": "arcade_entrance",
		"floor_labels": {
			"-1": "Retro Level",
			"0": "Main Arcade Level"
		},
		"nodes": [
			_space(
				"arcade_entrance",
				"Arcade Entrance",
				" ",
				0,
				"The public entrance opens directly toward the arcade floor.",
				"public",
				"entrance"
			),
			_space(
				"main_arcade_floor",
				"Main Arcade Floor",
				" ",
				0,
				(
					"Cabinets, competitive machines, and active game "
					+ "stations fill the main arcade floor."
				),
				"public",
				"arcade_floor",
				[],
				[
					{
						"fixture_id": "arcade_machine_primary",
						"title": "EraLife Stick Fighter Cabinet",
						"label": "Use Arcade Cabinet",
						"inspect_label": "Inspect Arcade Cabinet",
						"surface_text": (
							"EraLife Stick Fighter Cabinet — "
							+ "a playable fighting cabinet is here."
						),
						"kind": "arcade_machine",
						"host_kind": "arcade_machine",
						"action_id": "open_minigame_host",
						"requires_fixture_focus": true,
						"intent_type": "minigame",
						"target_engine_property": (
							"mini_game_contract_engine"
						),



						"provider_id": "stick_fighter",




						"launch_direct": false,
						"open_provider_setup": false,
						"multiplayer_mode": "single_vs_ai",

						"ui_is_renderer_only": true
					}
				]
			),
			_space(
				"prize_counter_snack_bar",
				"Prize Counter & Snack Bar",
				" ",
				0,
				(
					"Prize redemption shelves and a compact snack counter "
					+ "sit beside the main floor."
				),
				"public",
				"commercial_counter"
			),
			_space(
				"private_party_room",
				"Private Party Room",
				" ",
				0,
				(
					"A reservable party room sits away from the main bank "
					+ "of machines."
				),
				"public",
				"party_room"
			),
			_space(
				"restroom",
				"Restroom",
				" ",
				0,
				"A public restroom serves the arcade floor.",
				"public",
				"bathroom"
			),
			_space(
				"manager_office",
				"Manager's Office",
				" ",
				0,
				(
					"The management office contains administrative records "
					+ "and operational controls."
				),
				"household_private",
				"office",
				[
					"owner_or_family"
				]
			),
			_space(
				"machine_service_storage",
				"Machine Service & Prize Storage",
				" ",
				0,
				(
					"Replacement parts, prize inventory, and machine-service "
					+ "tools are stored here."
				),
				"household_private",
				"storage",
				[
					"owner_or_family"
				]
			),
			_space(
				"retro_cabinet_floor",
				"Retro Cabinet Floor",
				" ",
				-1,
				(
					"A lower level preserves older cabinets and classic "
					+ "machines."
				),
				"public",
				"arcade_floor"
			)
		],
		"edges": [
			_topology_edge(
				"arcade_entrance",
				"main_arcade_floor",
				"doorway"
			),
			_topology_edge(
				"main_arcade_floor",
				"prize_counter_snack_bar",
				"walk",
				[],
				false
			),
			_topology_edge(
				"main_arcade_floor",
				"private_party_room",
				"doorway"
			),
			_topology_edge(
				"main_arcade_floor",
				"restroom",
				"doorway",
				[],
				false
			),
			_topology_edge(
				"main_arcade_floor",
				"manager_office",
				"doorway",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"main_arcade_floor",
				"machine_service_storage",
				"secured_door",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"main_arcade_floor",
				"retro_cabinet_floor",
				"staircase",
				[],
				false
			)
		]
	}
func _era_key_from_text(value: String) -> String:
	var text: String = value.to_lower()

	if text.find("ancient") >= 0:
		return "ancient"

	if text.find("medieval") >= 0:
		return "medieval"

	if text.find("industrial") >= 0:
		return "industrial"

	if text.find("future") >= 0:
		return "future"

	return "modern"
func _build_topology_from_property_contract(
	prop: Dictionary,
	node: Dictionary,
	profile: Dictionary,
	layout_key: String
) -> Dictionary:
	var blueprint: Dictionary = {}

	match layout_key:
		"official_residence_white_house":
			return _topology_from_existing_floors(
				prop,
				node,
				_white_house_floors(),
				profile,
				layout_key
			)

		"arcade":
			blueprint = _arcade_blueprint()

		"roman_domus":
			blueprint = _roman_domus_blueprint()

		"roman_insula":
			blueprint = _roman_insula_blueprint()

		"medieval_castle":
			blueprint = _medieval_castle_blueprint()

		"modern_mansion":
			blueprint = _modern_mansion_blueprint()

		"tiny_house":
			blueprint = _tiny_house_blueprint()

		"air_nomad_temple":
			blueprint = _air_nomad_temple_blueprint()

		"apartment_building":
			blueprint = _apartment_blueprint(
				profile
			)

		"palace":
			blueprint = _palace_blueprint(
				profile
			)

		"temple":
			blueprint = _temple_blueprint(
				profile
			)

		"cabin":
			blueprint = _cabin_blueprint(
				profile
			)

		"future_procedural":
			blueprint = _future_procedural_blueprint(
				prop,
				profile
			)

		_:
			blueprint = _era_dwelling_blueprint(
				profile
			)

	return _topology_from_blueprint(
		prop,
		node,
		profile,
		layout_key,
		blueprint
	)

func _topology_from_blueprint(
	prop: Dictionary,
	node: Dictionary,
	profile: Dictionary,
	layout_key: String,
	blueprint: Dictionary
) -> Dictionary:
	var nodes: Dictionary = {}

	for raw_node in _safe_array(
		blueprint.get("nodes", [])
	):
		var space: Dictionary = _normalize_topology_node(
			_safe_dictionary(raw_node)
		)
		var node_id: String = str(
			space.get("node_id", "")
		)

		if node_id != "":
			nodes [node_id] = space

	var edges: Array = []
	var seen_edges: Dictionary = {}

	for raw_edge in _safe_array(
		blueprint.get("edges", [])
	):
		var edge: Dictionary = _normalize_topology_edge(
			_safe_dictionary(raw_edge)
		)
		var edge_id: String = str(
			edge.get("edge_id", "")
		)

		if (
			edge_id == ""
			or seen_edges.has(edge_id)
		):
			continue

		seen_edges [edge_id] = true
		edges.append(edge)

	var entry_node_id: String = str(
		blueprint.get("entry_node_id", "")
	).strip_edges()

	if (
		entry_node_id == ""
		or not nodes.has(entry_node_id)
	):
		entry_node_id = _best_entry_node_id(nodes)

	return _normalize_topology({
		"schema": TOPOLOGY_SCHEMA,
		"version": CONTRACT_VERSION,
		"property_id": int(
			prop.get(
				"id",
				prop.get("property_id", -1)
			)
		),
		"layout_key": layout_key,
		"layout_signature": _layout_signature(
			prop,
			profile,
			layout_key
		),
		"generation_seed": _property_generation_seed(
			prop,
			layout_key
		),
		"entry_node_id": entry_node_id,
		"nodes": nodes,
		"edges": edges,
		"floor_labels": _safe_dictionary(
			blueprint.get("floor_labels", {})
		),
		"mutation_history": _safe_array(
			_safe_dictionary(
				node.get("spatial_topology", {})
			).get("mutation_history", [])
		),
		"generated_from": {
			"template_id": str(
				prop.get("template_id", "")
			),
			"era_key": str(
				profile.get("era_key", "modern")
			),
			"subtype": str(
				profile.get("subtype", "")
			),
			"category": str(
				profile.get(
					"category",
					"residential"
				)
			),
			"realm_key": str(
				profile.get("realm_key", "")
			)
		},
		"ui_is_renderer_only": true
	})
func _roman_domus_blueprint() -> Dictionary:
	return {
		"entry_node_id": "front_entrance",
		"floor_labels": {
			"0": "Domus Ground Level"
		},
		"nodes": [
			_space(
				"front_entrance",
				"Front Entrance",
				"🚪",
				0,
				"The entrance opens directly into the household's public-facing Roman space.",
				"household",
				"entrance"
			),
			_space(
				"atrium",
				"Atrium",
				"🏛️",
				0,
				"The atrium is the organizing center of the domus.",
				"household",
				"atrium"
			),
			_space(
				"tablinum",
				"Tablinum",
				"📜",
				0,
				"The household head receives business and manages records here.",
				"household_private",
				"study"
			),
			_space(
				"triclinium",
				"Triclinium",
				"🍽️",
				0,
				"Dining couches frame the formal eating room.",
				"household",
				"dining_room"
			),
			_space(
				"culina",
				"Culina",
				"🔥",
				0,
				"The household kitchen is compact, hot, and practical.",
				"household",
				"kitchen"
			),
			_space(
				"peristyle_garden",
				"Peristyle Garden",
				"🌳",
				0,
				"A columned garden forms the private open-air heart of the property.",
				"household_private",
				"garden"
			)
		],
		"edges": [
			_topology_edge(
				"front_entrance",
				"atrium",
				"doorway"
			),
			_topology_edge(
				"atrium",
				"tablinum",
				"doorway"
			),
			_topology_edge(
				"atrium",
				"triclinium",
				"doorway"
			),
			_topology_edge(
				"atrium",
				"culina",
				"doorway"
			),
			_topology_edge(
				"atrium",
				"peristyle_garden",
				"colonnade",
				"",
				false
			),
			_topology_edge(
				"tablinum",
				"peristyle_garden",
				"doorway"
			)
		]
	}
func _roman_insula_blueprint() -> Dictionary:
	return {
		"entry_node_id": "apartment_entrance",
		"floor_labels": {
			"0": "Insula Apartment"
		},
		"nodes": [
			_space(
				"apartment_entrance",
				"Apartment Entrance",
				"🚪",
				0,
				"A narrow entrance opens into a compact rented dwelling.",
				"household",
				"entrance"
			),
			_space(
				"living_sleeping_area",
				"Sleeping Area",
				"🛏️",
				0,
				"The same constrained area supports sleep, storage, and daily living.",
				"household_private",
				"living_area"
			),
			_space(
				"shared_kitchen",
				"Shared Kitchen",
				"🔥",
				0,
				"A small cooking space is shared with nearby residents.",
				"household",
				"kitchen"
			),
			_space(
				"balcony",
				"Balcony",
				"🪟",
				0,
				"The balcony overlooks the crowded street below.",
				"household",
				"balcony"
			),
			_space(
				"street",
				"Street",
				"🛣️",
				0,
				"The public street sits directly outside the insula.",
				"public",
				"exit"
			)
		],
		"edges": [
			_topology_edge(
				"street",
				"apartment_entrance",
				"doorway"
			),
			_topology_edge(
				"apartment_entrance",
				"living_sleeping_area",
				"walk"
			),
			_topology_edge(
				"living_sleeping_area",
				"shared_kitchen",
				"doorway"
			),
			_topology_edge(
				"living_sleeping_area",
				"balcony",
				"doorway"
			)
		]
	}
func _medieval_castle_blueprint() -> Dictionary:
	return {
		"entry_node_id": "gatehouse",
		"floor_labels": {
			"-1": "Undercroft",
			"0": "Castle Grounds",
			"1": "Royal Level",
			"2": "Battlements"
		},
		"nodes": [
			_space(
				"gatehouse",
				"Gatehouse",
				"🚪",
				0,
				"The fortified gate controls entry into the castle.",
				"public_staff",
				"gatehouse"
			),
			_space(
				"courtyard",
				"Courtyard",
				"🏰",
				0,
				"The main courtyard connects the castle's public and military spaces.",
				"public_staff",
				"courtyard"
			),
			_space(
				"main_hall",
				"Main Hall",
				"🍖",
				0,
				"The main hall carries feasts, petitions, and household ceremony.",
				"household",
				"great_hall"
			),
			_space(
				"kitchen",
				"Castle Kitchen",
				"🔥",
				0,
				"Large hearths support the castle household.",
				"household",
				"kitchen"
			),
			_space(
				"barracks",
				"Barracks",
				"🛡️",
				0,
				"Guards sleep, train, and prepare here.",
				"restricted",
				"barracks"
			),
			_space(
				"armory",
				"Armory",
				"⚔️",
				0,
				"Weapons and defensive equipment are secured here.",
				"restricted",
				"armory"
			),
			_space(
				"stables",
				"Stables",
				"🐎",
				0,
				"Mounts and carriages remain protected near the courtyard.",
				"household",
				"stable"
			),
			_space(
				"chapel",
				"Chapel",
				"⛪",
				0,
				"The chapel supports worship and household ceremony.",
				"household",
				"chapel"
			),
			_space(
				"dungeon",
				"Dungeon",
				"⛓️",
				-1,
				"Stone cells occupy the secured lower level.",
				"restricted",
				"dungeon"
			),
			_space(
				"secret_passage",
				"Secret Passage",
				"🕯️",
				-1,
				"A concealed passage cuts through the castle structure.",
				"household_hidden",
				"secret_passage",
				[
					"owner_or_family"
				]
			),
			_space(
				"throne_room",
				"Throne Room",
				"👑",
				1,
				"The throne room is built around royal authority and public judgment.",
				"elite_private",
				"throne_room",
				[
					"owner_or_royal"
				]
			),
			_space(
				"royal_chambers",
				"Royal Chambers",
				"🛏️",
				1,
				"The ruling household's private rooms sit above the main hall.",
				"elite_private",
				"bedroom",
				[
					"owner_or_family"
				]
			),
			_space(
				"watch_tower",
				"Watch Tower",
				"🔭",
				2,
				"The tower overlooks the surrounding territory.",
				"restricted",
				"tower"
			),
			_space(
				"north_wall",
				"North Wall",
				"🧱",
				2,
				"The north battlement protects the castle approach.",
				"restricted",
				"battlement"
			),
			_space(
				"south_wall",
				"South Wall",
				"🧱",
				2,
				"The south battlement overlooks the lower grounds.",
				"restricted",
				"battlement"
			)
		],
		"edges": [
			_topology_edge("gatehouse", "courtyard", "fortified_gate"),
			_topology_edge("courtyard", "main_hall", "doorway"),
			_topology_edge("courtyard", "barracks", "walk"),
			_topology_edge("courtyard", "stables", "walk"),
			_topology_edge("courtyard", "chapel", "walk"),
			_topology_edge("main_hall", "kitchen", "service_door"),
			_topology_edge("barracks", "armory", "secured_door"),
			_topology_edge("main_hall", "dungeon", "stone_steps"),
			_topology_edge("dungeon", "secret_passage", "hidden_passage"),
			_topology_edge(
				"secret_passage",
				"royal_chambers",
				"hidden_passage"
			),
			_topology_edge(
				"main_hall",
				"throne_room",
				"grand_staircase"
			),
			_topology_edge(
				"throne_room",
				"royal_chambers",
				"doorway"
			),
			_topology_edge(
				"courtyard",
				"watch_tower",
				"spiral_staircase"
			),
			_topology_edge(
				"watch_tower",
				"north_wall",
				"battlement_walk",
				"",
				false
			),
			_topology_edge(
				"watch_tower",
				"south_wall",
				"battlement_walk",
				"",
				false
			)
		]
	}
func _modern_mansion_blueprint() -> Dictionary:
	return {
		"entry_node_id": "front_entrance",
		"floor_labels": {
			"-1": "Lower Level",
			"0": "Ground Floor",
			"1": "Second Floor",
			"2": "Third Floor / Rooftop"
		},
		"nodes": [
			_space(
				"front_entrance",
				"Front Entrance",
				"🚪",
				0,
				"The formal entrance opens into the mansion.",
				"household",
				"entrance"
			),
			_space(
				"living_room",
				"Living Room",
				"🛋️",
				0,
				"The primary social space anchors the ground floor.",
				"household",
				"living_room"
			),
			_space(
				"kitchen",
				"Kitchen",
				"🍳",
				0,
				"A large modern kitchen supports the household.",
				"household",
				"kitchen"
			),
			_space(
				"dining_room",
				"Dining Room",
				"🍽️",
				0,
				"The dining room connects formal meals to the main living areas.",
				"household",
				"dining_room"
			),
			_space(
				"garage",
				"Garage",
				"🚗",
				0,
				"The enclosed garage stores mobility assets.",
				"household",
				"garage"
			),
			_space(
				"office",
				"Office",
				"💻",
				0,
				"A private office supports work and planning.",
				"household_private",
				"office"
			),
			_space(
				"patio",
				"Patio",
				"🌤️",
				0,
				"The patio connects the house to the backyard.",
				"household",
				"patio"
			),
			_space(
				"backyard",
				"Backyard",
				"🌳",
				0,
				"The landscaped grounds sit behind the mansion.",
				"household",
				"yard"
			),
			_space(
				"second_floor_hall",
				"Second Floor Hall",
				"🪜",
				1,
				"The upper hall connects the private bedroom wing.",
				"household_private",
				"hallway"
			),
			_space(
				"master_bedroom",
				"Master Bedroom",
				"🛏️",
				1,
				"The primary suite occupies a private upper wing.",
				"household_private",
				"bedroom",
				[
					"owner_or_family"
				]
			),
			_space(
				"guest_bedroom",
				"Guest Bedroom",
				"🛏️",
				1,
				"A private guest suite overlooks the grounds.",
				"household_private",
				"bedroom"
			),
			_space(
				"home_theater",
				"Home Theater",
				"🎬",
				1,
				"A dedicated theater supports private entertainment.",
				"household",
				"theater"
			),
			_space(
				"gym",
				"Gym",
				"🏋️",
				1,
				"A private fitness room supports training.",
				"household",
				"gym"
			),
			_space(
				"wine_cellar",
				"Wine Cellar",
				"🍷",
				-1,
				"A climate-controlled cellar sits below the house.",
				"household_private",
				"cellar",
				[
					"owner_or_family"
				]
			),
			_space(
				"indoor_pool",
				"Indoor Pool",
				"🏊",
				-1,
				"A private indoor pool fills part of the lower level.",
				"household",
				"pool"
			),
			_space(
				"third_floor_lounge",
				"Third Floor Lounge",
				"🛋️",
				2,
				"A private lounge crowns the residence.",
				"elite_private",
				"lounge",
				[
					"owner_or_family"
				]
			),
			_space(
				"rooftop",
				"Rooftop",
				"🌆",
				2,
				"The rooftop overlooks the surrounding property.",
				"elite_private",
				"rooftop",
				[
					"owner_or_family"
				]
			)
		],
		"edges": [
			_topology_edge("front_entrance", "living_room", "doorway"),
			_topology_edge("living_room", "kitchen", "walk"),
			_topology_edge("living_room", "dining_room", "walk"),
			_topology_edge("kitchen", "garage", "secured_door"),
			_topology_edge("living_room", "office", "doorway"),
			_topology_edge("living_room", "patio", "glass_door"),
			_topology_edge("patio", "backyard", "walk", "", false),
			_topology_edge(
				"living_room",
				"second_floor_hall",
				"grand_staircase"
			),
			_topology_edge(
				"second_floor_hall",
				"master_bedroom",
				"doorway"
			),
			_topology_edge(
				"second_floor_hall",
				"guest_bedroom",
				"doorway"
			),
			_topology_edge(
				"second_floor_hall",
				"home_theater",
				"doorway"
			),
			_topology_edge(
				"second_floor_hall",
				"gym",
				"doorway"
			),
			_topology_edge(
				"living_room",
				"wine_cellar",
				"basement_stairs"
			),
			_topology_edge(
				"wine_cellar",
				"indoor_pool",
				"walk"
			),
			_topology_edge(
				"second_floor_hall",
				"third_floor_lounge",
				"staircase"
			),
			_topology_edge(
				"third_floor_lounge",
				"rooftop",
				"roof_door"
			)
		]
	}
func _tiny_house_blueprint() -> Dictionary:
	return {
		"entry_node_id": "outside",
		"floor_labels": {
			"0": "Tiny House"
		},
		"nodes": [
			_space(
				"outside",
				"Outside",
				"🌳",
				0,
				"The tiny house sits directly in front of you.",
				"public",
				"exit"
			),
			_space(
				"living_area",
				"Living Area",
				"🛋️",
				0,
				"One compact room performs most household functions.",
				"household",
				"living_area"
			),
			_space(
				"kitchenette",
				"Kitchenette",
				"🍳",
				0,
				"A compact kitchenette occupies one side of the living area.",
				"household",
				"kitchen"
			),
			_space(
				"bathroom",
				"Bathroom",
				"🚿",
				0,
				"A small private bathroom uses the available space carefully.",
				"household_private",
				"bathroom"
			),
			_space(
				"loft_bed",
				"Loft Bed",
				"🛏️",
				0,
				"A short ladder reaches the sleeping loft.",
				"household_private",
				"loft"
			)
		],
		"edges": [
			_topology_edge("outside", "living_area", "doorway"),
			_topology_edge("living_area", "kitchenette", "walk", "", false),
			_topology_edge("living_area", "bathroom", "doorway"),
			_topology_edge("living_area", "loft_bed", "ladder", "", false)
		]
	}
func _air_nomad_temple_blueprint() -> Dictionary:
	return {
		"entry_node_id": "cloud_bridge",
		"floor_labels": {
			"0": "Temple Platform",
			"1": "Upper Sky Level"
		},
		"nodes": [
			_space(
				"cloud_bridge",
				"Cloud Bridge",
				"☁️",
				0,
				"A narrow bridge crosses open air toward the temple.",
				"public",
				"bridge"
			),
			_space(
				"meditation_hall",
				"Meditation Hall",
				"🧘",
				0,
				"The main hall is built around quiet, breath, and open air.",
				"household",
				"meditation_hall"
			),
			_space(
				"prayer_room",
				"Prayer Room",
				"🙏",
				0,
				"A smaller chamber supports private spiritual practice.",
				"household_private",
				"prayer_room"
			),
			_space(
				"wind_garden",
				"Wind Garden",
				"🎐",
				0,
				"Wind chimes and cloud-fed plants fill the open garden.",
				"household",
				"garden"
			),
			_space(
				"training_platform",
				"Training Platform",
				"🥋",
				0,
				"An open platform supports movement and airbending practice.",
				"household",
				"training_platform"
			),
			_space(
				"sky_balcony",
				"Sky Balcony",
				"🌤️",
				1,
				"The upper balcony overlooks the mountains and cloud layer.",
				"household_private",
				"balcony"
			),
			_space(
				"glider_dock",
				"Glider Dock",
				"🪂",
				1,
				"Gliders and aerial mobility assets are secured here.",
				"household",
				"sky_dock"
			)
		],
		"edges": [
			_topology_edge(
				"cloud_bridge",
				"meditation_hall",
				"cloud_bridge",
				"",
				false
			),
			_topology_edge(
				"meditation_hall",
				"prayer_room",
				"doorway"
			),
			_topology_edge(
				"meditation_hall",
				"wind_garden",
				"open_arch",
				"",
				false
			),
			_topology_edge(
				"wind_garden",
				"training_platform",
				"walk",
				"",
				false
			),
			_topology_edge(
				"meditation_hall",
				"sky_balcony",
				"stone_steps",
				"",
				false
			),
			_topology_edge(
				"sky_balcony",
				"glider_dock",
				"sky_walk",
				"",
				false
			)
		]
	}
func _apartment_blueprint(
	profile: Dictionary
) -> Dictionary:
	var text: String = str(
		profile.get("searchable_text", "")
	)
	var is_penthouse: bool = (
		text.find("penthouse") >= 0
	)

	var nodes: Array = [
		_space(
			"building_lobby",
			"Lobby",
			"🏢",
			0,
			"The shared lobby connects residents to the building.",
			"public",
			"lobby"
		),
		_space(
			"mail_room",
			"Mail Room",
			"📬",
			0,
			"Mail and small deliveries are stored here.",
			"household",
			"mail_room"
		),
		_space(
			"shared_laundry",
			"Laundry Room",
			"🧺",
			0,
			"Residents share the building laundry room.",
			"household",
			"laundry"
		),
		_space(
			"elevator",
			"Elevator",
			"🛗",
			0,
			"The elevator connects the lobby to residential levels.",
			"household",
			"elevator"
		),
		_space(
			"apartment_entrance",
			"Apartment Entrance",
			"🚪",
			1,
			"The private apartment begins behind this door.",
			"household_private",
			"entrance"
		),
		_space(
			"living_area",
			"Living Area",
			"🛋️",
			1,
			"The central living space anchors the apartment.",
			"household",
			"living_room"
		),
		_space(
			"kitchen",
			"Kitchen",
			"🍳",
			1,
			"The apartment kitchen supports household meals.",
			"household",
			"kitchen"
		),
		_space(
			"bedroom",
			"Bedroom",
			"🛏️",
			1,
			"The private bedroom supports rest and recovery.",
			"household_private",
			"bedroom"
		),
		_space(
			"bathroom",
			"Bathroom",
			"🚿",
			1,
			"The apartment's private bathroom sits near the bedroom.",
			"household_private",
			"bathroom"
		)
	]
	var edges: Array = [
		_topology_edge("building_lobby", "mail_room", "walk"),
		_topology_edge("building_lobby", "shared_laundry", "walk"),
		_topology_edge("building_lobby", "elevator", "walk", "", false),
		_topology_edge("elevator", "apartment_entrance", "elevator"),
		_topology_edge("apartment_entrance", "living_area", "doorway"),
		_topology_edge("living_area", "kitchen", "walk", "", false),
		_topology_edge("living_area", "bedroom", "doorway"),
		_topology_edge("bedroom", "bathroom", "doorway")
	]

	if is_penthouse:
		nodes.append_array([
			_space(
				"private_elevator",
				"Private Elevator",
				"🛗",
				1,
				"A private elevator serves the penthouse directly.",
				"elite_private",
				"elevator",
				[
					"owner_or_family"
				]
			),
			_space(
				"wine_lounge",
				"Wine Lounge",
				"🍷",
				1,
				"A private lounge supports entertaining and collection storage.",
				"elite_private",
				"lounge",
				[
					"owner_or_family"
				]
			),
			_space(
				"roof_terrace",
				"Roof Terrace",
				"🌆",
				2,
				"A private terrace occupies the building roof.",
				"elite_private",
				"terrace",
				[
					"owner_or_family"
				]
			),
			_space(
				"sky_pool",
				"Sky Pool",
				"🏊",
				2,
				"A private elevated pool overlooks the city.",
				"elite_private",
				"pool",
				[
					"owner_or_family"
				]
			)
		])
		edges.append_array([
			_topology_edge(
				"building_lobby",
				"private_elevator",
				"private_elevator",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"private_elevator",
				"living_area",
				"private_elevator",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"living_area",
				"wine_lounge",
				"doorway",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"wine_lounge",
				"roof_terrace",
				"private_elevator",
				[
					"owner_or_family"
				]
			),
			_topology_edge(
				"roof_terrace",
				"sky_pool",
				"walk",
				[
					"owner_or_family"
				],
				false
			)
		])

	return {
		"entry_node_id": "building_lobby",
		"floor_labels": {
			"0": "Shared Building",
			"1": "Private Residence",
			"2": "Roof Level"
		},
		"nodes": nodes,
		"edges": edges
	}
func _palace_blueprint(
	_profile: Dictionary
) -> Dictionary:
	return {
		"entry_node_id": "grand_entrance",
		"floor_labels": {
			"0": "Ceremonial Level",
			"1": "Royal Residence",
			"2": "Upper Palace"
		},
		"nodes": [
			_space("grand_entrance", "Grand Entrance", "🚪", 0, "The ceremonial entrance opens into the palace.", "public_staff", "entrance"),
			_space("reception_hall", "Reception Hall", "🏛️", 0, "Officials and visitors gather in the reception hall.", "public_staff", "hall"),
			_space("throne_room", "Throne Room", "👑", 0, "The throne room embodies sovereign authority.", "restricted", "throne_room"),
			_space("banquet_hall", "Banquet Hall", "🍽️", 0, "Large formal meals and celebrations occur here.", "household", "dining_room"),
			_space("royal_garden", "Royal Garden", "🌹", 0, "Landscaped grounds extend beyond the ceremonial rooms.", "household", "garden"),
			_space("royal_chambers", "Royal Chambers", "🛏️", 1, "The ruling household's private residence.", "elite_private", "bedroom", ["owner_or_royal"]),
			_space("private_council", "Private Council Chamber", "📜", 1, "Sensitive decisions are discussed here.", "restricted", "council"),
			_space("royal_gallery", "Royal Gallery", "🖼️", 1, "Dynastic history and valuable objects line the gallery.", "elite_private", "gallery"),
			_space("upper_balcony", "Upper Balcony", "🌆", 2, "The palace balcony overlooks the grounds.", "elite_private", "balcony")
		],
		"edges": [
			_topology_edge("grand_entrance", "reception_hall", "doorway"),
			_topology_edge("reception_hall", "throne_room", "ceremonial_door"),
			_topology_edge("reception_hall", "banquet_hall", "doorway"),
			_topology_edge("banquet_hall", "royal_garden", "garden_door"),
			_topology_edge("throne_room", "royal_chambers", "grand_staircase", ["owner_or_royal"]),
			_topology_edge("royal_chambers", "private_council", "doorway"),
			_topology_edge("royal_chambers", "royal_gallery", "walk"),
			_topology_edge("royal_gallery", "upper_balcony", "staircase")
		]
	}


func _temple_blueprint(
	_profile: Dictionary
) -> Dictionary:
	return {
		"entry_node_id": "temple_entrance",
		"floor_labels": {
			"0": "Temple Grounds",
			"1": "Upper Sanctuary"
		},
		"nodes": [
			_space("temple_entrance", "Temple Entrance", "🚪", 0, "The temple entrance opens into sacred space.", "public", "entrance"),
			_space("main_sanctuary", "Main Sanctuary", "🕯️", 0, "The central sanctuary supports worship and ceremony.", "public", "sanctuary"),
			_space("courtyard", "Temple Courtyard", "🌿", 0, "An open courtyard connects the temple grounds.", "public", "courtyard"),
			_space("prayer_room", "Prayer Room", "🙏", 0, "A smaller room supports private prayer.", "household_private", "prayer_room"),
			_space("monastic_quarters", "Monastic Quarters", "🛏️", 1, "Residents sleep and study in the upper quarters.", "restricted", "quarters"),
			_space("archive", "Sacred Archive", "📚", 1, "Religious records and texts are protected here.", "restricted", "archive")
		],
		"edges": [
			_topology_edge("temple_entrance", "main_sanctuary", "doorway"),
			_topology_edge("main_sanctuary", "courtyard", "open_arch", "", false),
			_topology_edge("main_sanctuary", "prayer_room", "doorway"),
			_topology_edge("main_sanctuary", "monastic_quarters", "stone_steps"),
			_topology_edge("monastic_quarters", "archive", "secured_door")
		]
	}


func _cabin_blueprint(
	_profile: Dictionary
) -> Dictionary:
	return {
		"entry_node_id": "porch",
		"floor_labels": {
			"0": "Cabin"
		},
		"nodes": [
			_space("porch", "Porch", "🌲", 0, "The porch faces the surrounding land.", "public", "porch"),
			_space("main_room", "Main Room", "🔥", 0, "A central room combines warmth, meals, and daily life.", "household", "living_room"),
			_space("sleeping_room", "Sleeping Room", "🛏️", 0, "A small private sleeping space sits behind the main room.", "household_private", "bedroom"),
			_space("pantry", "Pantry", "🥫", 0, "Food and supplies are stored in the pantry.", "household", "storage"),
			_space("outside", "Outside", "🌳", 0, "The forest or surrounding land begins beyond the porch.", "public", "exit")
		],
		"edges": [
			_topology_edge("outside", "porch", "walk", "", false),
			_topology_edge("porch", "main_room", "doorway"),
			_topology_edge("main_room", "sleeping_room", "doorway"),
			_topology_edge("main_room", "pantry", "doorway")
		]
	}


func _era_dwelling_blueprint(
	profile: Dictionary
) -> Dictionary:
	var era_key: String = str(
		profile.get("era_key", "modern")
	)

	match era_key:
		"ancient":
			return {
				"entry_node_id": "dwelling_entrance",
				"floor_labels": { "0": "Ancient Dwelling"},
				"nodes": [
					_space("dwelling_entrance", "Dwelling Entrance", "🚪", 0, "The entrance opens into an era-valid household dwelling.", "household", "entrance"),
					_space("hearth_room", "Hearth Room", "🔥", 0, "The hearth supports warmth, food, and gathering.", "household", "living_room"),
					_space("sleeping_area", "Sleeping Area", "🛏️", 0, "Bedding and private belongings occupy this space.", "household_private", "bedroom"),
					_space("storage_area", "Storage Area", "🌾", 0, "Food and household goods are kept here.", "household", "storage"),
					_space("yard", "Yard", "🌿", 0, "The household's outdoor working space sits beside the dwelling.", "household", "yard")
				],
				"edges": [
					_topology_edge("dwelling_entrance", "hearth_room", "doorway"),
					_topology_edge("hearth_room", "sleeping_area", "walk", "", false),
					_topology_edge("hearth_room", "storage_area", "walk", "", false),
					_topology_edge("dwelling_entrance", "yard", "walk", "", false)
				]
			}

		"medieval":
			return {
				"entry_node_id": "front_door",
				"floor_labels": { "0": "Medieval Dwelling"},
				"nodes": [
					_space("front_door", "Front Door", "🚪", 0, "The timber door opens into the dwelling.", "household", "entrance"),
					_space("hall", "Hall", "🔥", 0, "The hall supports eating, work, and gathering.", "household", "living_room"),
					_space("kitchen", "Kitchen", "🍞", 0, "The kitchen sits close to the household hearth.", "household", "kitchen"),
					_space("sleeping_chamber", "Sleeping Chamber", "🛏️", 0, "A private sleeping chamber sits beyond the hall.", "household_private", "bedroom"),
					_space("yard", "Yard", "🐎", 0, "The working yard surrounds the dwelling.", "household", "yard")
				],
				"edges": [
					_topology_edge("front_door", "hall", "doorway"),
					_topology_edge("hall", "kitchen", "doorway"),
					_topology_edge("hall", "sleeping_chamber", "doorway"),
					_topology_edge("front_door", "yard", "walk", "", false)
				]
			}

		"industrial":
			return {
				"entry_node_id": "front_hall",
				"floor_labels": {
					"0": "Ground Floor",
					"1": "Upper Floor"
				},
				"nodes": [
					_space("front_hall", "Front Hall", "🚪", 0, "The narrow hall organizes the industrial-era house.", "household", "entrance"),
					_space("parlour", "Parlour", "🛋️", 0, "The parlour receives guests and family.", "household", "living_room"),
					_space("kitchen", "Kitchen", "🔥", 0, "The kitchen centers on the cooking range.", "household", "kitchen"),
					_space("upper_landing", "Upper Landing", "🪜", 1, "The landing connects the private upper rooms.", "household_private", "hallway"),
					_space("bedroom", "Bedroom", "🛏️", 1, "A private bedroom occupies the upper floor.", "household_private", "bedroom"),
					_space("washroom", "Washroom", "🚿", 1, "An era-valid washroom sits near the bedroom.", "household_private", "bathroom")
				],
				"edges": [
					_topology_edge("front_hall", "parlour", "doorway"),
					_topology_edge("front_hall", "kitchen", "doorway"),
					_topology_edge("front_hall", "upper_landing", "staircase"),
					_topology_edge("upper_landing", "bedroom", "doorway"),
					_topology_edge("upper_landing", "washroom", "doorway")
				]
			}

		_:
			return {
				"entry_node_id": "entryway",
				"floor_labels": {
					"0": "Ground Floor",
					"1": "Upper Floor"
				},
				"nodes": [
					_space("entryway", "Entryway", "🚪", 0, "The entryway opens into the home.", "household", "entrance"),
					_space("living_room", "Living Room", "🛋️", 0, "The household's main social room.", "household", "living_room"),
					_space("kitchen", "Kitchen", "🍳", 0, "The kitchen supports food storage and meals.", "household", "kitchen"),
					_space("dining_room", "Dining Room", "🍽️", 0, "The dining room connects the kitchen and living space.", "household", "dining_room"),
					_space("upper_hall", "Upper Hall", "🪜", 1, "The upper hall reaches the private rooms.", "household_private", "hallway"),
					_space("bedroom", "Bedroom", "🛏️", 1, "The bedroom supports privacy and rest.", "household_private", "bedroom"),
					_space("bathroom", "Bathroom", "🚿", 1, "The bathroom supports hygiene and privacy.", "household_private", "bathroom")
				],
				"edges": [
					_topology_edge("entryway", "living_room", "doorway"),
					_topology_edge("living_room", "kitchen", "walk", "", false),
					_topology_edge("living_room", "dining_room", "walk", "", false),
					_topology_edge("living_room", "upper_hall", "staircase"),
					_topology_edge("upper_hall", "bedroom", "doorway"),
					_topology_edge("upper_hall", "bathroom", "doorway")
				]
			}


func _future_procedural_blueprint(
	prop: Dictionary,
	_profile: Dictionary
) -> Dictionary:
	var generation_seed: int = _property_generation_seed(
		prop,
		"future_procedural"
	)
	var include_medical_pod: bool = (
		generation_seed % 2 == 0
	)
	var include_holo_studio: bool = (
		generation_seed % 3 != 0
	)
	var include_sky_dock: bool = (
		generation_seed % 5 <= 2
	)
	var nodes: Array = [
		_space("arrival_lock", "Arrival Lock", "🚪", 0, "The property verifies identity and environmental conditions here.", "household", "entrance"),
		_space("adaptive_living_core", "Adaptive Living Core", "🛋️", 0, "Responsive walls reshape the primary living area.", "household", "living_room"),
		_space("nutrition_lab", "Nutrition Lab", "🧪", 0, "Food synthesis and household diagnostics operate here.", "household", "kitchen"),
		_space("private_suite", "Private Suite", "🛏️", 0, "A configurable private suite supports rest and recovery.", "household_private", "bedroom", ["owner_or_family"]),
		_space("utility_core", "Utility Core", "🤖", 0, "Robotic maintenance and storage systems occupy this module.", "household", "utility")
	]
	var edges: Array = [
		_topology_edge("arrival_lock", "adaptive_living_core", "identity_door"),
		_topology_edge("adaptive_living_core", "nutrition_lab", "sliding_partition"),
		_topology_edge("adaptive_living_core", "private_suite", "privacy_field"),
		_topology_edge("adaptive_living_core", "utility_core", "service_passage")
	]

	if include_medical_pod:
		nodes.append(
			_space("medical_pod", "Medical Pod", "🩺", 0, "A medical scanner and treatment system occupy this pod.", "household_private", "medical")
		)
		edges.append(
			_topology_edge("private_suite", "medical_pod", "sliding_partition")
		)

	if include_holo_studio:
		nodes.append(
			_space("holo_studio", "Holographic Studio", "🪩", 0, "The room changes visual and functional identity on demand.", "household", "studio")
		)
		edges.append(
			_topology_edge("adaptive_living_core", "holo_studio", "sliding_partition")
		)

	if include_sky_dock:
		nodes.append_array([
			_space("sky_lounge", "Sky Lounge", "🌌", 1, "A high-level lounge overlooks the future city.", "elite_private", "lounge", ["owner_or_family"]),
			_space("roof_platform", "Roof Platform", "🚀", 1, "A roof platform supports drones and aerial mobility.", "elite_private", "rooftop", ["owner_or_family"])
		])
		edges.append_array([
			_topology_edge("adaptive_living_core", "sky_lounge", "private_elevator", ["owner_or_family"]),
			_topology_edge("sky_lounge", "roof_platform", "pressure_door", ["owner_or_family"])
		])

	return {
		"entry_node_id": "arrival_lock",
		"floor_labels": {
			"0": "Adaptive Habitat",
			"1": "Sky Level"
		},
		"nodes": nodes,
		"edges": edges
	}
func _space(
	node_id: String,
	title: String,
	icon: String,
	floor_index: int,
	description: String,
	access_level: String = "household",
	room_type: String = "room",
	ownership_requirements: Array = [],
	fixtures: Array = []
) -> Dictionary:
	return {
		"schema": NODE_SCHEMA,
		"version": CONTRACT_VERSION,
		"node_id": node_id,
		"room_id": node_id,
		"title": title,
		"name": title,
		"icon": icon,
		"floor_index": floor_index,
		"node_type": room_type,
		"room_type": room_type,
		"description": description,
		"approach_label": "%s %s" % [
			icon,
			title
		],
		"access_level": access_level,
		"ownership_requirements": (
			ownership_requirements.duplicate(true)
		),
		"fixtures": fixtures.duplicate(true),
		"state": "intact",
		"damage_state": "",
		"removed": false
	}


func _topology_edge(
	from_node_id: String,
	to_node_id: String,
	movement_kind: String = "walk",
	ownership_requirements: Variant = [],
	lockable: bool = true,
	security_mode: String = ""
) -> Dictionary:
	var resolved_requirements: Array = []
	if typeof(ownership_requirements) == TYPE_ARRAY:
		resolved_requirements = (
			ownership_requirements as Array
		).duplicate(false)

	return {
		"schema": EDGE_SCHEMA,
		"version": CONTRACT_VERSION,
		"edge_id": _canonical_edge_id(
			from_node_id,
			to_node_id
		),
		"from_node_id": from_node_id,
		"to_node_id": to_node_id,
		"bidirectional": true,
		"movement_kind": movement_kind,
		"enabled": true,
		"blocked_reason": "",
		"blocked_text": "",
		"ownership_requirements": resolved_requirements,
		"door_contract": {
			"lockable": lockable,
			"securable": lockable,
			"security_mode": security_mode,
			"secured": false,
			"locked": false,
			"bolted": false,
			"locked_by_actor_id": -1,
			"secured_by_actor_id": -1,
			"key_holder_ids": []
		}
	}


func _canonical_edge_id(
	from_node_id: String,
	to_node_id: String
) -> String:
	var ordered: Array = [
		from_node_id,
		to_node_id
	]
	ordered.sort()

	return "edge:%s:%s" % [
		str(ordered [0]),
		str(ordered [1])
	]


func _normalize_topology(
	topology: Dictionary
) -> Dictionary:
	var normalized: Dictionary = topology.duplicate(true)
	var normalized_nodes: Dictionary = {}
	var raw_nodes: Variant = normalized.get("nodes", {})

	if typeof(raw_nodes) == TYPE_DICTIONARY:
		for raw_key in (
			raw_nodes as Dictionary
		).keys():
			var node_contract: Dictionary = _normalize_topology_node(
				_safe_dictionary(
					(raw_nodes as Dictionary).get(
						raw_key,
						{}
					)
				)
			)
			var node_id: String = str(
				node_contract.get(
					"node_id",
					raw_key
				)
			)

			if node_id != "":
				node_contract ["node_id"] = node_id
				node_contract ["room_id"] = node_id
				normalized_nodes [node_id] = node_contract

	elif typeof(raw_nodes) == TYPE_ARRAY:
		for raw_node in (raw_nodes as Array):
			var node_contract: Dictionary = _normalize_topology_node(
				_safe_dictionary(raw_node)
			)
			var node_id: String = str(
				node_contract.get("node_id", "")
			)

			if node_id != "":
				normalized_nodes [node_id] = node_contract

	var normalized_edges: Array = []
	var seen_edges: Dictionary = {}

	for raw_edge in _safe_array(
		normalized.get("edges", [])
	):
		var edge: Dictionary = _normalize_topology_edge(
			_safe_dictionary(raw_edge)
		)
		var edge_id: String = str(
			edge.get("edge_id", "")
		)
		var from_node_id: String = str(
			edge.get("from_node_id", "")
		)
		var to_node_id: String = str(
			edge.get("to_node_id", "")
		)

		if (
			edge_id == ""
			or seen_edges.has(edge_id)
			or not normalized_nodes.has(from_node_id)
			or not normalized_nodes.has(to_node_id)
		):
			continue

		seen_edges [edge_id] = true
		normalized_edges.append(edge)

	normalized ["schema"] = TOPOLOGY_SCHEMA
	normalized ["version"] = CONTRACT_VERSION
	normalized ["nodes"] = normalized_nodes
	normalized ["edges"] = normalized_edges

	if not normalized.has("mutation_history"):
		normalized ["mutation_history"] = []

	if not normalized.has("floor_labels"):
		normalized ["floor_labels"] = {}

	if (
		str(
			normalized.get("entry_node_id", "")
		) == ""
		or not normalized_nodes.has(
			str(
				normalized.get(
					"entry_node_id",
					""
				)
			)
		)
	):
		normalized ["entry_node_id"] = _best_entry_node_id(
			normalized_nodes
		)

	return normalized


func _normalize_topology_node(
	node_contract: Dictionary
) -> Dictionary:
	var node: Dictionary = node_contract.duplicate(true)
	var node_id: String = str(
		node.get(
			"node_id",
			node.get("room_id", "")
		)
	).strip_edges()

	if node_id == "":
		return {}

	node ["schema"] = NODE_SCHEMA
	node ["version"] = CONTRACT_VERSION
	node ["node_id"] = node_id
	node ["room_id"] = node_id
	node ["title"] = str(
		node.get(
			"title",
			node.get(
				"name",
				node_id.replace("_", " ").capitalize()
			)
		)
	)
	node ["name"] = str(
		node.get(
			"name",
			node.get("title", "Space")
		)
	)
	node ["icon"] = str(
		node.get("icon", "🚪")
	)
	node ["floor_index"] = int(
		node.get("floor_index", 0)
	)
	node ["node_type"] = str(
		node.get(
			"node_type",
			node.get("room_type", "room")
		)
	)
	node ["room_type"] = str(
		node.get(
			"room_type",
			node.get("node_type", "room")
		)
	)
	node ["description"] = str(
		node.get(
			"description",
			"%s exists as part of this property." % str(
				node.get("title", "This space")
			)
		)
	)
	node ["approach_label"] = str(
		node.get(
			"approach_label",
			"%s %s" % [
				node.get("icon", "🚪"),
				node.get("title", "Space")
			]
		)
	)
	node ["access_level"] = str(
		node.get("access_level", "household")
	)
	node ["ownership_requirements"] = _safe_array(
		node.get("ownership_requirements", [])
	)
	node ["fixtures"] = _safe_array(
		node.get("fixtures", [])
	)
	node ["state"] = str(
		node.get("state", "intact")
	)
	node ["damage_state"] = str(
		node.get("damage_state", "")
	)
	node ["removed"] = bool(
		node.get("removed", false)
	)
	return node


func _normalize_topology_edge(
	edge_contract: Dictionary
) -> Dictionary:
	var edge: Dictionary = edge_contract.duplicate(true)

	var from_node_id: String = str(
		edge.get(
			"from_node_id",
			edge.get(
				"from",
				""
			)
		)
	).strip_edges()
	var to_node_id: String = str(
		edge.get(
			"to_node_id",
			edge.get(
				"to",
				""
			)
		)
	).strip_edges()

	if (
		from_node_id == ""
		or to_node_id == ""
	):
		return {}

	var edge_id: String = str(
		edge.get(
			"edge_id",
			""
		)
	).strip_edges()
	if edge_id == "":
		edge_id = _canonical_edge_id(
			from_node_id,
			to_node_id
		)

	edge ["schema"] = EDGE_SCHEMA
	edge ["version"] = CONTRACT_VERSION
	edge ["edge_id"] = edge_id
	edge ["from_node_id"] = from_node_id
	edge ["to_node_id"] = to_node_id
	edge ["bidirectional"] = bool(
		edge.get(
			"bidirectional",
			true
		)
	)
	edge ["movement_kind"] = str(
		edge.get(
			"movement_kind",
			"walk"
		)
	)
	edge ["enabled"] = bool(
		edge.get(
			"enabled",
			true
		)
	)
	edge ["blocked_reason"] = str(
		edge.get(
			"blocked_reason",
			""
		)
	)
	edge ["blocked_text"] = str(
		edge.get(
			"blocked_text",
			""
		)
	)

	var requirements_raw: Variant = edge.get(
		"ownership_requirements",
		[]
	)
	edge ["ownership_requirements"] = (
		(requirements_raw as Array).duplicate(false)
		if typeof(requirements_raw) == TYPE_ARRAY
		else []
	)

	var door_raw: Variant = edge.get(
		"door_contract",
		{}
	)
	var door_contract: Dictionary = (
		(door_raw as Dictionary).duplicate(true)
		if typeof(door_raw) == TYPE_DICTIONARY
		else {}
	)

	door_contract ["lockable"] = bool(
		door_contract.get(
			"lockable",
			edge.get(
				"lockable",
				true
			)
		)
	)
	door_contract ["securable"] = bool(
		door_contract.get(
			"securable",
			door_contract.get(
				"lockable",
				true
			)
		)
	)

	var security_mode: String = str(
		door_contract.get(
			"security_mode",
			edge.get(
				"security_mode",
				""
			)
		)
	).strip_edges().to_lower()
	if security_mode not in [
		"",
		"lock",
		"bolt"
	]:
		security_mode = ""

	var locked: bool = bool(
		door_contract.get(
			"locked",
			edge.get(
				"locked",
				false
			)
		)
	)
	var bolted: bool = bool(
		door_contract.get(
			"bolted",
			edge.get(
				"bolted",
				false
			)
		)
	)
	var secured: bool = bool(
		door_contract.get(
			"secured",
			locked or bolted
		)
	)

	door_contract ["security_mode"] = security_mode
	door_contract ["secured"] = secured
	door_contract ["locked"] = (
		locked
		or (
			secured
			and security_mode != "bolt"
		)
	)
	door_contract ["bolted"] = (
		bolted
		or (
			secured
			and security_mode == "bolt"
		)
	)
	door_contract ["locked_by_actor_id"] = int(
		door_contract.get(
			"locked_by_actor_id",
			-1
		)
	)
	door_contract ["secured_by_actor_id"] = int(
		door_contract.get(
			"secured_by_actor_id",
			door_contract.get(
				"locked_by_actor_id",
				-1
			)
		)
	)

	var key_holders_raw: Variant = door_contract.get(
		"key_holder_ids",
		[]
	)
	door_contract ["key_holder_ids"] = (
		(key_holders_raw as Array).duplicate(false)
		if typeof(key_holders_raw) == TYPE_ARRAY
		else []
	)

	edge ["door_contract"] = door_contract
	return edge
func _property_security_mode(
	prop: Dictionary
) -> String:
	var era_text: String = ""

	if gs != null and gs.era != null:
		era_text = str(
			gs.era.name
		)

	if era_text.strip_edges() == "":
		era_text = str(
			prop.get(
				"era_name",
				prop.get(
					"era",
					""
				)
			)
		)

	var normalized_era: String = (
		era_text
		.strip_edges()
		.to_lower()
	)

	if (
		normalized_era.find(
			"ancient"
		) != -1
		or normalized_era.find(
			"prehistoric"
		) != -1
	):
		return "bolt"

	return "lock"


func _edge_security_mode(
	prop: Dictionary,
	edge: Dictionary
) -> String:
	var door_raw: Variant = edge.get(
		"door_contract",
		{}
	)
	if typeof(door_raw) == TYPE_DICTIONARY:
		var door_contract: Dictionary = (
			door_raw as Dictionary
		)
		var published_mode: String = str(
			door_contract.get(
				"security_mode",
				""
			)
		).strip_edges().to_lower()

		if published_mode in [
			"lock",
			"bolt"
		]:
			return published_mode

	return _property_security_mode(
		prop
	)


func _edge_is_secured(
	edge: Dictionary
) -> bool:
	var door_raw: Variant = edge.get(
		"door_contract",
		{}
	)
	if typeof(door_raw) != TYPE_DICTIONARY:
		return false

	var door_contract: Dictionary = (
		door_raw as Dictionary
	)
	return (
		bool(
			door_contract.get(
				"secured",
				false
			)
		)
		or bool(
			door_contract.get(
				"locked",
				false
			)
		)
		or bool(
			door_contract.get(
				"bolted",
				false
			)
		)
	)


func _edge_is_securable(
	edge: Dictionary
) -> bool:
	var door_raw: Variant = edge.get(
		"door_contract",
		{}
	)
	if typeof(door_raw) != TYPE_DICTIONARY:
		return false

	var door_contract: Dictionary = (
		door_raw as Dictionary
	)
	return bool(
		door_contract.get(
			"securable",
			door_contract.get(
				"lockable",
				false
			)
		)
	)


func _edge_security_action_id(
	security_mode: String,
	releasing: bool
) -> String:
	if security_mode == "bolt":
		return (
			"unbolt_spatial_edge"
			if releasing
			else "bolt_spatial_edge"
		)

	return (
		"unlock_spatial_edge"
		if releasing
		else "lock_spatial_edge"
	)
func _topology_from_existing_floors(
	prop: Dictionary,
	node: Dictionary,
	floors: Array,
	profile: Dictionary,
	layout_key: String
) -> Dictionary:
	var normalized_floors: Array = _normalize_floors(floors)
	var topology_nodes: Dictionary = {}
	var topology_edges: Array = []
	var seen_edge_ids: Dictionary = {}
	var floor_labels: Dictionary = {}
	var legacy_room_id_map: Dictionary = {}
	var global_room_id_map: Dictionary = {}
	var floor_entry_node_ids: Dictionary = {}
	var floor_indices: Array = []

	for raw_floor in normalized_floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)

		if floor_contract.is_empty():
			continue

		var floor_index: int = int(
			floor_contract.get("floor_index", 0)
		)
		var floor_key: String = str(floor_index)
		var floor_access_level: String = str(
			floor_contract.get(
				"access_level",
				"household"
			)
		).strip_edges().to_lower()

		if floor_access_level == "":
			floor_access_level = "household"

		if not floor_indices.has(floor_index):
			floor_indices.append(floor_index)

		floor_labels [floor_key] = str(
			floor_contract.get(
				"label",
				_floor_label(floor_index)
			)
		)

		for raw_room in _safe_array(
			floor_contract.get("rooms", [])
		):
			var legacy_room: Dictionary = _safe_dictionary(
				raw_room
			)

			if legacy_room.is_empty():
				continue

			var legacy_room_id: String = str(
				legacy_room.get(
					"room_id",
					legacy_room.get(
						"node_id",
						""
					)
				)
			).strip_edges()

			if legacy_room_id == "":
				continue

			var node_id: String = legacy_room_id
			var duplicate_index: int = 2

			while topology_nodes.has(node_id):
				node_id = "floor_%d:%s:%d" % [
					floor_index,
					legacy_room_id,
					duplicate_index
				]
				duplicate_index += 1

			legacy_room_id_map [
				"%d|%s" % [
					floor_index,
					legacy_room_id
				]
			] = node_id

			if not global_room_id_map.has(legacy_room_id):
				global_room_id_map [legacy_room_id] = node_id

			var room_access_level: String = str(
				legacy_room.get(
					"access_level",
					floor_access_level
				)
			).strip_edges().to_lower()

			if room_access_level == "":
				room_access_level = floor_access_level

			var node_contract: Dictionary = _normalize_topology_node({
				"schema": NODE_SCHEMA,
				"version": CONTRACT_VERSION,
				"node_id": node_id,
				"room_id": node_id,
				"legacy_room_id": legacy_room_id,
				"title": str(
					legacy_room.get(
						"title",
						legacy_room.get(
							"name",
							legacy_room_id.replace(
								"_",
								" "
							).capitalize()
						)
					)
				),
				"name": str(
					legacy_room.get(
						"name",
						legacy_room.get(
							"title",
							legacy_room_id.replace(
								"_",
								" "
							).capitalize()
						)
					)
				),
				"icon": str(
					legacy_room.get(
						"icon",
						"🚪"
					)
				),
				"floor_index": floor_index,
				"node_type": str(
					legacy_room.get(
						"node_type",
						legacy_room.get(
							"room_type",
							"room"
						)
					)
				),
				"room_type": str(
					legacy_room.get(
						"room_type",
						legacy_room.get(
							"node_type",
							"room"
						)
					)
				),
				"description": str(
					legacy_room.get(
						"description",
						""
					)
				),
				"approach_label": str(
					legacy_room.get(
						"approach_label",
						"Go to %s" % str(
							legacy_room.get(
								"title",
								legacy_room_id.replace(
									"_",
									" "
								).capitalize()
							)
						)
					)
				),
				"access_level": room_access_level,
				"ownership_requirements": _safe_array(
					legacy_room.get(
						"ownership_requirements",
						[]
					)
				),
				"fixtures": _safe_array(
					legacy_room.get(
						"fixtures",
						[]
					)
				),
				"state": str(
					legacy_room.get(
						"state",
						"intact"
					)
				),
				"damage_state": str(
					legacy_room.get(
						"damage_state",
						""
					)
				),
				"removed": bool(
					legacy_room.get(
						"removed",
						false
					)
				),
			})

			if not node_contract.is_empty():
				topology_nodes [node_id] = node_contract

		var entry_room: Dictionary = _entry_room_for_floor(
			normalized_floors,
			floor_index
		)
		var legacy_entry_room_id: String = str(
			entry_room.get(
				"room_id",
				entry_room.get(
					"node_id",
					""
				)
			)
		).strip_edges()
		var mapped_entry_node_id: String = str(
			legacy_room_id_map.get(
				"%d|%s" % [
					floor_index,
					legacy_entry_room_id
				],
				""
			)
		)

		if mapped_entry_node_id != "":
			floor_entry_node_ids [floor_key] = mapped_entry_node_id

	floor_indices.sort()


	for raw_floor in normalized_floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)

		if floor_contract.is_empty():
			continue

		var floor_index: int = int(
			floor_contract.get("floor_index", 0)
		)

		for raw_room in _safe_array(
			floor_contract.get("rooms", [])
		):
			var legacy_room: Dictionary = _safe_dictionary(
				raw_room
			)
			var legacy_room_id: String = str(
				legacy_room.get(
					"room_id",
					legacy_room.get(
						"node_id",
						""
					)
				)
			).strip_edges()
			var source_node_id: String = str(
				legacy_room_id_map.get(
					"%d|%s" % [
						floor_index,
						legacy_room_id
					],
					""
				)
			)

			if source_node_id == "":
				continue

			for raw_connection in _safe_array(
				legacy_room.get(
					"connections",
					[]
				)
			):
				var connection_contract: Dictionary = {}
				var target_legacy_room_id: String = ""

				if typeof(raw_connection) == TYPE_DICTIONARY:
					connection_contract = _safe_dictionary(
						raw_connection
					)
					target_legacy_room_id = str(
						connection_contract.get(
							"target_room_id",
							connection_contract.get(
								"room_id",
								connection_contract.get(
									"to_node_id",
									""
								)
							)
						)
					).strip_edges()
				else:
					target_legacy_room_id = str(
						raw_connection
					).strip_edges()

				if target_legacy_room_id == "":
					continue

				var target_node_id: String = str(
					legacy_room_id_map.get(
						"%d|%s" % [
							floor_index,
							target_legacy_room_id
						],
						global_room_id_map.get(
							target_legacy_room_id,
							""
						)
					)
				)

				if (
					target_node_id == ""
					or not topology_nodes.has(target_node_id)
				):
					continue

				var edge: Dictionary = _topology_edge(
					source_node_id,
					target_node_id,
					str(
						connection_contract.get(
							"movement_kind",
							"doorway"
						)
					),
					_safe_array(
						connection_contract.get(
							"ownership_requirements",
							[]
						)
					),
					bool(
						connection_contract.get(
							"lockable",
							true
						)
					)
				)

				edge ["bidirectional"] = bool(
					connection_contract.get(
						"bidirectional",
						true
					)
				)
				edge ["enabled"] = bool(
					connection_contract.get(
						"enabled",
						true
					)
				)
				edge ["blocked_reason"] = str(
					connection_contract.get(
						"blocked_reason",
						""
					)
				)
				edge ["blocked_text"] = str(
					connection_contract.get(
						"blocked_text",
						""
					)
				)

				if typeof(
					connection_contract.get(
						"door_contract",
						null
					)
				) == TYPE_DICTIONARY:
					edge ["door_contract"] = _safe_dictionary(
						connection_contract.get(
							"door_contract",
							{}
						)
					)

				edge = _normalize_topology_edge(edge)

				if edge.is_empty():
					continue

				var edge_id: String = str(
					edge.get("edge_id", "")
				)

				if (
					edge_id == ""
					or seen_edge_ids.has(edge_id)
				):
					continue

				seen_edge_ids [edge_id] = true
				topology_edges.append(edge)




	for floor_position in range(
		maxi(
			0,
			floor_indices.size() - 1
		)
	):
		var lower_floor: int = int(
			floor_indices [floor_position]
		)
		var upper_floor: int = int(
			floor_indices [floor_position + 1]
		)

		if _topology_has_floor_transition(
			topology_nodes,
			topology_edges,
			lower_floor,
			upper_floor
		):
			continue

		var lower_entry_node_id: String = str(
			floor_entry_node_ids.get(
				str(lower_floor),
				""
			)
		)
		var upper_entry_node_id: String = str(
			floor_entry_node_ids.get(
				str(upper_floor),
				""
			)
		)

		if (
			lower_entry_node_id == ""
			or upper_entry_node_id == ""
			or not topology_nodes.has(lower_entry_node_id)
			or not topology_nodes.has(upper_entry_node_id)
		):
			continue

		var transition_edge: Dictionary = _topology_edge(
			lower_entry_node_id,
			upper_entry_node_id,
			"staircase",
			[],
			false
		)
		transition_edge ["legacy_inferred_floor_transition"] = true
		transition_edge = _normalize_topology_edge(
			transition_edge
		)

		var transition_edge_id: String = str(
			transition_edge.get(
				"edge_id",
				""
			)
		)

		if (
			transition_edge_id != ""
			and not seen_edge_ids.has(transition_edge_id)
		):
			seen_edge_ids [transition_edge_id] = true
			topology_edges.append(transition_edge)

	var requested_entry_room_id: String = str(
		node.get(
			"active_room",
			""
		)
	).strip_edges()
	var entry_node_id: String = str(
		global_room_id_map.get(
			requested_entry_room_id,
			""
		)
	)

	if entry_node_id == "":
		entry_node_id = str(
			floor_entry_node_ids.get(
				"0",
				""
			)
		)

	if (
		entry_node_id == ""
		and not floor_indices.is_empty()
	):
		entry_node_id = str(
			floor_entry_node_ids.get(
				str(int(floor_indices [0])),
				""
			)
		)

	if entry_node_id == "":
		entry_node_id = _best_entry_node_id(
			topology_nodes
		)

	var previous_topology: Dictionary = _safe_dictionary(
		node.get(
			"spatial_topology",
			{}
		)
	)

	return _normalize_topology({
		"schema": TOPOLOGY_SCHEMA,
		"version": CONTRACT_VERSION,
		"property_id": int(
			prop.get(
				"id",
				prop.get(
					"property_id",
					-1
				)
			)
		),
		"layout_key": layout_key,
		"layout_signature": _layout_signature(
			prop,
			profile,
			layout_key
		),
		"generation_seed": _property_generation_seed(
			prop,
			layout_key
		),
		"entry_node_id": entry_node_id,
		"nodes": topology_nodes,
		"edges": topology_edges,
		"floor_labels": floor_labels,
		"mutation_history": _safe_array(
			previous_topology.get(
				"mutation_history",
				[]
			)
		),
		"generated_from": {
			"migration_source": "legacy_floor_contracts",
			"template_id": str(
				prop.get(
					"template_id",
					""
				)
			),
			"era_key": str(
				profile.get(
					"era_key",
					"modern"
				)
			),
			"subtype": str(
				profile.get(
					"subtype",
					""
				)
			),
			"category": str(
				profile.get(
					"category",
					"residential"
				)
			),
			"realm_key": str(
				profile.get(
					"realm_key",
					""
				)
			)
		},
		"ui_is_renderer_only": true
	})


func _topology_has_floor_transition(
	topology_nodes: Dictionary,
	topology_edges: Array,
	first_floor: int,
	second_floor: int
) -> bool:
	for raw_edge in topology_edges:
		var edge: Dictionary = _safe_dictionary(raw_edge)
		var from_node: Dictionary = _safe_dictionary(
			topology_nodes.get(
				str(
					edge.get(
						"from_node_id",
						""
					)
				),
				{}
			)
		)
		var to_node: Dictionary = _safe_dictionary(
			topology_nodes.get(
				str(
					edge.get(
						"to_node_id",
						""
					)
				),
				{}
			)
		)

		if from_node.is_empty() or to_node.is_empty():
			continue

		var from_floor: int = int(
			from_node.get(
				"floor_index",
				0
			)
		)
		var to_floor: int = int(
			to_node.get(
				"floor_index",
				0
			)
		)

		if (
			from_floor == first_floor
			and to_floor == second_floor
		) or (
			from_floor == second_floor
			and to_floor == first_floor
		):
			return true

	return false


func _floor_graph_has_movement(floors: Array) -> bool:
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		var rooms: Array = _safe_array(
			floor_contract.get(
				"rooms",
				[]
			)
		)

		if rooms.size() > 1:
			return true

	return floors.size() > 1



func _bedroom_count_for_property(prop: Dictionary) -> int:
	if prop.has("bedrooms"):
		return max(1, int(prop.get("bedrooms", 1)))

	var text: String = "%s %s %s" % [
		str(prop.get("display_name", "")),
		str(prop.get("subtype", "")),
		str(prop.get("size", ""))
	]
	text = text.to_lower()

	if text.find("mansion") != -1:
		return 6
	if text.find("large") != -1:
		return 4
	if text.find("medium") != -1:
		return 3
	if text.find("apartment") != -1:
		return 1
	return 2


func _bathroom_count_for_property(prop: Dictionary) -> int:
	if prop.has("bathrooms"):
		return max(1, int(prop.get("bathrooms", 1)))

	var text: String = "%s %s %s" % [
		str(prop.get("display_name", "")),
		str(prop.get("subtype", "")),
		str(prop.get("size", ""))
	]
	text = text.to_lower()

	if text.find("mansion") != -1:
		return 5
	if text.find("large") != -1:
		return 3
	if text.find("medium") != -1:
		return 2
	return 1


func _white_house_floors() -> Array:
	return _normalize_floors([
		{
			"floor_index": 0,
			"label": "White House Ground Floor",
			"access_level": "public_staff",
			"rooms": [
				_room("north_portico", "North Portico", 0, "You enter through the front entrance. Secret Service presence is immediate and formal.", "Stand inside the North Portico", [], "public_staff", ["entrance_hall", "map_room"]),
				_room("entrance_hall", "Entrance Hall", 0, "The hall opens into ceremonial space, staff motion, and controlled corridors.", "Walk down the entrance hall", [], "public_staff", ["north_portico", "map_room", "china_room", "diplomatic_reception_room"]),
				_room("map_room", "Map Room", 0, "Historic maps, formal furniture, and state memory shape the room.", "Turn toward the Map Room", [], "public_staff", ["entrance_hall"]),
				_room("china_room", "China Room", 0, "Display cases preserve institutional ceremony and old state dinners.", "Turn left toward the China Room", [], "public_staff", ["entrance_hall"]),
				_room("diplomatic_reception_room", "Diplomatic Reception Room", 0, "This room carries the pressure of greetings, visitors, and state-facing ceremony.", "Enter the Diplomatic Reception Room", [], "public_staff", ["entrance_hall"])
			]
		},
		{
			"floor_index": 1,
			"label": "West Wing",
			"access_level": "restricted",
			"rooms": [
				_room("west_wing_hallway", "West Wing Hallway", 1, "The hallway narrows into executive pressure. Staff move quickly. Security watches everything.", "Go upstairs toward the West Wing hallway", [], "restricted", ["oval_office", "cabinet_room", "press_briefing_room"]),
				_room("oval_office", "Oval Office", 1, "The center of executive authority. Every object in the room feels symbolic.", "Walk toward the Oval Office", [], "restricted", ["west_wing_hallway"]),
				_room("cabinet_room", "Cabinet Room", 1, "A long table waits for officials, pressure, disagreement, and national decisions.", "Enter the Cabinet Room", [], "restricted", ["west_wing_hallway"]),
				_room("press_briefing_room", "Press Briefing Room", 1, "Rows of seats face the podium. The press waits for language to become history.", "Walk to the Press Briefing Room", [], "restricted", ["west_wing_hallway"])
			]
		},
		{
			"floor_index": 2,
			"label": "Executive Residence",
			"access_level": "private_family",
			"rooms": [
				_room("residence_hallway", "Residence Hallway", 2, "The machinery of government softens into family residence, but the authority of the place never disappears.", "Go upstairs into the residence hallway", [], "private_family", ["family_bedrooms", "private_dining_room", "residence_lounge"]),
				_room("family_bedrooms", "Family Bedrooms", 2, "The private family residence sits behind the machinery of government.", "Turn left to the family bedrooms by the stairs", [], "private_family", ["residence_hallway"]),
				_room("private_dining_room", "Private Dining Room", 2, "A quieter dining space where family life and public duty collide.", "Walk to the private dining room", [], "private_family", ["residence_hallway"]),
				_room("residence_lounge", "Residence Lounge", 2, "A lived-in room inside a state-backed home.", "Enter the residence lounge", [], "private_family", ["residence_hallway"])
			]
		},
		{
			"floor_index": 3,
			"label": "Special Access",
			"access_level": "ultra_restricted",
			"rooms": [
				_room("security_checkpoint", "Security Checkpoint", 3, "The air tightens. This area is not simply private. It is guarded by state authority.", "Approach the security checkpoint", [], "ultra_restricted", ["situation_room", "security_corridors"]),
				_room("situation_room", "Situation Room", 3, "The air is tight with national security pressure. Access here is never casual.", "Approach the Situation Room", [], "ultra_restricted", ["security_checkpoint"]),
				_room("security_corridors", "Security Corridors", 3, "Controlled corridors connect power, surveillance, and protection.", "Move through the security corridors", [], "ultra_restricted", ["security_checkpoint"])
			]
		}
	])


func _room(room_id: String, title: String, floor_index: int, description: String = "", approach_label: String = "", fixtures: Array = [], access_level: String = "", connections: Array = []) -> Dictionary:
	return {
		"room_id": room_id,
		"title": title,
		"name": title,
		"floor_index": floor_index,
		"description": description if description.strip_edges() != "" else "%s is part of the property interior reality node." % title,
		"approach_label": approach_label if approach_label.strip_edges() != "" else "Go to %s" % title,
		"fixtures": fixtures,
		"access_level": access_level,
		"connections": connections
	}


func _fixture(fixture_id: String, title: String, kind: String, label: String, surface_text: String) -> Dictionary:
	return {
		"fixture_id": fixture_id,
		"title": title,
		"kind": kind,
		"label": label,
		"surface_text": surface_text
	}


func _navigation_actions(
	actor: Person,
	prop: Dictionary,
	topology: Dictionary,
	active_node_id: String
) -> Array:
	var out: Array = []
	var seen_edges: Dictionary = {}

	for raw_edge in _adjacent_edges(
		topology,
		active_node_id
	):
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = (
			raw_edge as Dictionary
		)

		var edge_id: String = str(
			edge.get(
				"edge_id",
				""
			)
		).strip_edges()

		if (
			edge_id != ""
			and seen_edges.has(
				edge_id
			)
		):
			continue

		if edge_id != "":
			seen_edges [
				edge_id
			] = true

		var target_node_id: String = (
			_other_edge_node(
				edge,
				active_node_id
			)
		)
		if target_node_id == "":
			continue

		var target_node: Dictionary = (
			_topology_node(
				topology,
				target_node_id
			)
		)

		if (
			target_node.is_empty()
			or bool(
				target_node.get(
					"removed",
					false
				)
			)
		):
			continue

		var target_state: String = str(
			target_node.get(
				"state",
				"intact"
			)
		).strip_edges().to_lower()

		var icon: String = str(
			target_node.get(
				"icon",
				""
			)
		).strip_edges()

		var title: String = str(
			target_node.get(
				"title",
				"Space"
			)
		)

		var security_mode: String = (
			_edge_security_mode(
				prop,
				edge
			)
		)

		var secured: bool = (
			_edge_is_secured(
				edge
			)
		)

		var traversal_report: Dictionary = (
			resolve_edge_traversal_contract(
				actor,
				prop,
				topology,
				active_node_id,
				target_node_id
			)
		)

		var allowed: bool = bool(
			traversal_report.get(
				"allowed",
				false
			)
		)

		var label_prefix: String = icon

		if target_state in [
			"destroyed",
			"collapsed",
			"unsafe"
		]:
			label_prefix = ""
		elif not allowed:
			label_prefix = ""

		var blocked_narrative: String = str(
			traversal_report.get(
				"narrative",
				""
			)
		)

		if (
			secured
			and blocked_narrative == ""
		):
			blocked_narrative = (
				"Unlock this passage before entering."
				if security_mode != "bolt"
				else "Unbolt this passage before entering."
			)

		out.append({
			"action_id": "move_room",
			"label": (
				"%s%s%s"
				% [
					label_prefix,
					(
						" "
						if label_prefix != ""
						else ""
					),
					title
				]
			),
			"from_room_id": active_node_id,
			"room_id": target_node_id,
			"target_room_id": target_node_id,
			"target_floor": int(
				target_node.get(
					"floor_index",
					0
				)
			),
			"edge_id": edge_id,
			"movement_kind": str(
				edge.get(
					"movement_kind",
					"walk"
				)
			),
			"security_mode": security_mode,
			"secured_edge": secured,
			"disabled": (
				not allowed
			),
			"blocked_reason": str(
				traversal_report.get(
					"reason",
					""
				)
			),
			"tooltip": blocked_narrative,
			"visual_state": (
				"available"
				if allowed
				else "blocked"
			),
			"truth_source": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		})

	out.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			if (
				typeof(left_raw) != TYPE_DICTIONARY
				or typeof(right_raw) != TYPE_DICTIONARY
			):
				return false

			return str(
				(left_raw as Dictionary).get(
					"label",
					""
				)
			) < str(
				(right_raw as Dictionary).get(
					"label",
					""
				)
			)
	)

	return out
func _fallback_navigation_actions(
	_floors: Array,
	_active_floor: int,
	_active_room: String
) -> Array:
	return []
func _room_interaction_actions(
	actor: Person,
	prop: Dictionary,
	topology: Dictionary,
	current_room: Dictionary
) -> Array:
	var out: Array = []

	var room_id: String = str(
		current_room.get(
			"node_id",
			current_room.get(
				"room_id",
				""
			)
		)
	).strip_edges()

	var room_title: String = str(
		current_room.get(
			"title",
			"Space"
		)
	)

	if room_id != "":
		out.append({
			"action_id": "inspect_room",
			"label": "Inspect %s" % room_title,
			"room_id": room_id,
			"from_room_id": room_id,
			"truth_source": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		})

	var active_fixture: String = ""
	var reality_node_raw: Variant = prop.get(
		"property_reality_node",
		{}
	)

	if typeof(reality_node_raw) == TYPE_DICTIONARY:
		active_fixture = str(
			(reality_node_raw as Dictionary).get(
				"active_fixture",
				""
			)
		).strip_edges()

	var fixtures_raw: Variant = current_room.get(
		"fixtures",
		[]
	)

	if typeof(fixtures_raw) == TYPE_ARRAY:
		for raw_fixture in fixtures_raw as Array:
			if typeof(raw_fixture) != TYPE_DICTIONARY:
				continue

			var fixture: Dictionary = (
				raw_fixture as Dictionary
			)

			var fixture_id: String = str(
				fixture.get(
					"fixture_id",
					""
				)
			).strip_edges()
			if fixture_id == "":
				continue

			var configured_action_id: String = str(
				fixture.get(
					"action_id",
					"use_fixture"
				)
			).strip_edges()

			if configured_action_id == "":
				configured_action_id = "use_fixture"

			var configured_label: String = str(
				fixture.get(
					"label",
					(
						"Use %s"
						% str(
							fixture.get(
								"title",
								"Fixture"
							)
						)
					)
				)
			)

			var requires_fixture_focus: bool = bool(
				fixture.get(
					"requires_fixture_focus",
					false
				)
			)
			var fixture_is_active: bool = (
				requires_fixture_focus
				and active_fixture == fixture_id
			)

			var fixture_action_id: String = configured_action_id
			var fixture_action_label: String = configured_label

			if (
				requires_fixture_focus
				and not fixture_is_active
			):
				fixture_action_id = "use_fixture"
				fixture_action_label = str(
					fixture.get(
						"inspect_label",
						(
							"Inspect %s"
							% str(
								fixture.get(
									"title",
									"Fixture"
								)
							)
						)
					)
				)

			var fixture_action: Dictionary = {
				"action_id": fixture_action_id,
				"label": fixture_action_label,
				"room_id": room_id,
				"from_room_id": room_id,
				"fixture_id": fixture_id,
				"fixture_kind": str(
					fixture.get(
						"kind",
						"fixture"
					)
				),
				"host_kind": str(
					fixture.get(
						"host_kind",
						""
					)
				),
				"host_id": str(
					fixture.get(
						"host_id",
						""
					)
				),
				"truth_source": ENGINE_SCHEMA,
				"ui_is_renderer_only": true
			}



			for scalar_key in [
				"provider_id",
				"multiplayer_mode",
				"intent_type",
				"target_engine_property"
			]:
				if fixture.has(
					scalar_key
				):
					fixture_action [
						scalar_key
					] = str(
						fixture.get(
							scalar_key,
							""
						)
					)

			for bool_key in [
				"launch_direct",
				"open_provider_setup"
			]:
				if fixture.has(
					bool_key
				):
					fixture_action [
						bool_key
					] = bool(
						fixture.get(
							bool_key,
							false
						)
					)

			if requires_fixture_focus:
				fixture_action [
					"requires_fixture_focus"
				] = true
				fixture_action [
					"fixture_is_active"
				] = fixture_is_active
				fixture_action [
					"fixture_focus_only"
				] = not fixture_is_active

			out.append(
				fixture_action
			)

	var seen_security_edges: Dictionary = {}

	for raw_edge in _adjacent_edges(
		topology,
		room_id
	):
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = (
			raw_edge as Dictionary
		)

		if not _edge_is_securable(
			edge
		):
			continue

		var edge_id: String = str(
			edge.get(
				"edge_id",
				""
			)
		).strip_edges()

		if (
			edge_id != ""
			and seen_security_edges.has(
				edge_id
			)
		):
			continue

		if edge_id != "":
			seen_security_edges [
				edge_id
			] = true

		var target_node_id: String = (
			_other_edge_node(
				edge,
				room_id
			)
		)

		if target_node_id == "":
			continue

		var target_node: Dictionary = (
			_topology_node(
				topology,
				target_node_id
			)
		)

		if target_node.is_empty():
			continue

		var target_title: String = str(
			target_node.get(
				"title",
				"the adjoining space"
			)
		)

		var security_mode: String = (
			_edge_security_mode(
				prop,
				edge
			)
		)

		var secured: bool = (
			_edge_is_secured(
				edge
			)
		)

		var can_control: bool = (
			_actor_can_control_door(
				actor,
				prop,
				edge
			)
		)

		var action_id: String = (
			_edge_security_action_id(
				security_mode,
				secured
			)
		)

		var action_label: String = ""

		if security_mode == "bolt":
			action_label = (
				"Unbolt passage to %s"
				% target_title
				if secured
				else "Bolt passage to %s"
				% target_title
			)
		else:
			action_label = (
				"Unlock door to %s"
				% target_title
				if secured
				else "Lock door to %s"
				% target_title
			)

		out.append({
			"action_id": action_id,
			"label": action_label,
			"room_id": room_id,
			"from_room_id": room_id,
			"target_room_id": target_node_id,
			"target_floor": int(
				target_node.get(
					"floor_index",
					0
				)
			),
			"edge_id": edge_id,
			"security_mode": security_mode,
			"disabled": (
				not can_control
			),
			"tooltip": (
				""
				if can_control
				else (
					"You do not hold authority to control this passage."
				)
			),
			"truth_source": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		})

	return out
func _floors_from_topology(
	topology: Dictionary
) -> Array:
	var normalized: Dictionary = _normalize_topology(
		topology
	)
	var nodes: Dictionary = _safe_dictionary(
		normalized.get("nodes", {})
	)
	var floor_labels: Dictionary = _safe_dictionary(
		normalized.get("floor_labels", {})
	)
	var floor_map: Dictionary = {}

	for raw_node_id in nodes.keys():
		var node_id: String = str(raw_node_id)
		var space: Dictionary = _safe_dictionary(
			nodes.get(node_id, {})
		)

		if bool(space.get("removed", false)):
			continue

		var floor_index: int = int(
			space.get("floor_index", 0)
		)
		var floor_key: String = str(floor_index)

		if not floor_map.has(floor_key):
			floor_map [floor_key] = {
				"floor_index": floor_index,
				"label": str(
					floor_labels.get(
						floor_key,
						_floor_label(floor_index)
					)
				),
				"access_level": "mixed",
				"rooms": []
			}

		var projected_room: Dictionary = space.duplicate(true)
		projected_room ["connections"] = _adjacent_node_ids(
			normalized,
			node_id
		)
		projected_room ["adjacent_nodes"] = _adjacent_node_summaries(
			normalized,
			node_id
		)

		var floor_contract: Dictionary = _safe_dictionary(
			floor_map.get(floor_key, {})
		)
		var rooms: Array = _safe_array(
			floor_contract.get("rooms", [])
		)
		rooms.append(projected_room)
		floor_contract ["rooms"] = rooms
		floor_map [floor_key] = floor_contract

	var floors: Array = []

	for raw_floor in floor_map.values():
		var floor_contract: Dictionary = _safe_dictionary(
			raw_floor
		)
		var rooms: Array = _safe_array(
			floor_contract.get("rooms", [])
		)

		rooms.sort_custom(func (left_raw, right_raw) -> bool:
			return str(
				(left_raw as Dictionary).get("title", "")
			) < str(
				(right_raw as Dictionary).get("title", "")
			)
		)

		floor_contract ["rooms"] = rooms
		floors.append(floor_contract)

	floors.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("floor_index", 0)
		) < int(
			(right_raw as Dictionary).get("floor_index", 0)
		)
	)

	return floors


func _topology_node(
	topology: Dictionary,
	node_id: String
) -> Dictionary:
	var nodes_raw: Variant = topology.get(
		"nodes",
		{}
	)
	if typeof(nodes_raw) != TYPE_DICTIONARY:
		return {}

	var nodes: Dictionary = nodes_raw as Dictionary
	var node_raw: Variant = nodes.get(
		node_id,
		{}
	)
	return (
		node_raw as Dictionary
		if typeof(node_raw) == TYPE_DICTIONARY
		else {}
	)


func _adjacent_edges(
	topology: Dictionary,
	node_id: String
) -> Array:
	var out: Array = []
	var edges_raw: Variant = topology.get(
		"edges",
		[]
	)
	if typeof(edges_raw) != TYPE_ARRAY:
		return out

	for raw_edge in edges_raw as Array:
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = raw_edge as Dictionary
		if _edge_touches_node(
			edge,
			node_id
		):
			out.append(
				edge
			)

	return out
func _adjacent_node_ids(
	topology: Dictionary,
	node_id: String
) -> Array:
	var out: Array = []

	for raw_edge in _adjacent_edges(
		topology,
		node_id
	):
		var edge: Dictionary = _safe_dictionary(
			raw_edge
		)
		var other_id: String = _other_edge_node(
			edge,
			node_id
		)

		if other_id != "" and not out.has(other_id):
			out.append(other_id)

	return out


func _adjacent_node_summaries(
	topology: Dictionary,
	node_id: String
) -> Array:
	var out: Array = []

	for raw_edge in _adjacent_edges(
		topology,
		node_id
	):
		var edge: Dictionary = _safe_dictionary(
			raw_edge
		)
		var other_id: String = _other_edge_node(
			edge,
			node_id
		)
		var other_node: Dictionary = _topology_node(
			topology,
			other_id
		)

		if other_node.is_empty():
			continue

		var door_contract: Dictionary = _safe_dictionary(
			edge.get(
				"door_contract",
				{}
			)
		)
		var security_mode: String = str(
			door_contract.get(
				"security_mode",
				edge.get(
					"security_mode",
					""
				)
			)
		).strip_edges().to_lower()
		var locked: bool = bool(
			door_contract.get(
				"locked",
				edge.get(
					"locked",
					false
				)
			)
		)
		var bolted: bool = bool(
			door_contract.get(
				"bolted",
				edge.get(
					"bolted",
					false
				)
			)
		)
		var secured: bool = bool(
			door_contract.get(
				"secured",
				locked or bolted
			)
		)
		var lockable: bool = bool(
			door_contract.get(
				"lockable",
				edge.get(
					"lockable",
					false
				)
			)
		)
		var securable: bool = bool(
			door_contract.get(
				"securable",
				lockable
			)
		)

		out.append({
			"node_id": other_id,
			"title": str(
				other_node.get(
					"title",
					"Space"
				)
			),
			"icon": str(
				other_node.get(
					"icon",
					" "
				)
			),
			"floor_index": int(
				other_node.get(
					"floor_index",
					0
				)
			),
			"state": str(
				other_node.get(
					"state",
					"intact"
				)
			),
			"edge_id": str(
				edge.get(
					"edge_id",
					""
				)
			),
			"movement_kind": str(
				edge.get(
					"movement_kind",
					"walk"
				)
			),
			"bidirectional": bool(
				edge.get(
					"bidirectional",
					true
				)
			),
			"blocked": not bool(
				edge.get(
					"enabled",
					true
				)
			),
			"blocked_reason": str(
				edge.get(
					"blocked_reason",
					""
				)
			),
			"blocked_text": str(
				edge.get(
					"blocked_text",
					""
				)
			),
			"ownership_requirements": _safe_array(
				edge.get(
					"ownership_requirements",
					[]
				)
			),
			"security_mode": security_mode,
			"secured": secured,
			"locked": locked,
			"bolted": bolted,
			"lockable": lockable,
			"securable": securable,
			"door_contract": (
				door_contract.duplicate(false)
			)
		})

	return out

func _edge_between(
	topology: Dictionary,
	from_node_id: String,
	to_node_id: String
) -> Dictionary:
	var edges_raw: Variant = topology.get(
		"edges",
		[]
	)
	if typeof(edges_raw) != TYPE_ARRAY:
		return {}

	for raw_edge in edges_raw as Array:
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = raw_edge as Dictionary
		var edge_from: String = str(
			edge.get(
				"from_node_id",
				""
			)
		)
		var edge_to: String = str(
			edge.get(
				"to_node_id",
				""
			)
		)

		if (
			edge_from == from_node_id
			and edge_to == to_node_id
		) or (
			bool(
				edge.get(
					"bidirectional",
					true
				)
			)
			and edge_from == to_node_id
			and edge_to == from_node_id
		):
			return edge

	return {}


func _edge_touches_node(
	edge: Dictionary,
	node_id: String
) -> bool:
	return (
		str(edge.get("from_node_id", "")) == node_id
		or str(edge.get("to_node_id", "")) == node_id
	)


func _other_edge_node(
	edge: Dictionary,
	node_id: String
) -> String:
	var from_node_id: String = str(
		edge.get("from_node_id", "")
	)
	var to_node_id: String = str(
		edge.get("to_node_id", "")
	)

	if from_node_id == node_id:
		return to_node_id

	if (
		to_node_id == node_id
		and bool(edge.get("bidirectional", true))
	):
		return from_node_id

	return ""


func _flatten_floor_rooms(
	floors: Array
) -> Array:
	var out: Array = []

	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(
			raw_floor
		)

		for raw_room in _safe_array(
			floor_contract.get("rooms", [])
		):
			var room: Dictionary = _safe_dictionary(
				raw_room
			)

			if not room.is_empty():
				out.append(room)

	return out


func _floor_label(
	floor_index: int
) -> String:
	if floor_index < 0:
		return "Lower Level"

	if floor_index == 0:
		return "Ground Level"

	if floor_index == 1:
		return "Upper Level"

	return "Floor %d" % (floor_index + 1)


func _best_entry_node_id(
	nodes: Dictionary
) -> String:
	for candidate in [
		"front_entrance",
		"entryway",
		"apartment_entrance",
		"gatehouse",
		"temple_entrance",
		"grand_entrance",
		"outside",
		"porch",
		"arrival_lock"
	]:
		if nodes.has(candidate):
			return candidate

	for raw_node_id in nodes.keys():
		var node_id: String = str(raw_node_id)
		var node: Dictionary = _safe_dictionary(
			nodes.get(node_id, {})
		)

		if (
			str(node.get("node_type", "")) in [
				"entrance",
				"exit"
			]
			or bool(node.get("is_entry", false))
		):
			return node_id

	for raw_node_id in nodes.keys():
		return str(raw_node_id)

	return ""


func _first_observable_topology_node(
	topology: Dictionary
) -> Dictionary:
	var nodes_raw: Variant = topology.get(
		"nodes",
		{}
	)
	if typeof(nodes_raw) != TYPE_DICTIONARY:
		return {}

	var nodes: Dictionary = nodes_raw as Dictionary
	for raw_node_id in nodes.keys():
		var node_raw: Variant = nodes.get(
			raw_node_id,
			{}
		)
		if typeof(node_raw) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = node_raw as Dictionary
		if not bool(
			node.get(
				"removed",
				false
			)
		):
			return node

	return {}
func _layout_signature(
	prop: Dictionary,
	profile: Dictionary,
	layout_key: String
) -> String:
	return "%s|%s|%s|%s|%s" % [
		layout_key,
		str(prop.get("template_id", "")),
		str(profile.get("era_key", "")),
		str(profile.get("realm_key", "")),
		str(prop.get("id", -1))
	]


func _property_generation_seed(
	prop: Dictionary,
	layout_key: String
) -> int:
	var current_year: int = (
		int(gs.year)
		if gs != null
		else 0
	)
	var seed_source: String = "%s|%s|%s|%s" % [
		layout_key,
		str(
			prop.get(
				"id",
				-1
			)
		),
		str(
			prop.get(
				"template_id",
				""
			)
		),
		str(current_year)
	]

	return abs(
		seed_source.hash()
	)
func _apply_topology_mutation_to_contract(
	topology: Dictionary,
	mutation: Dictionary,
	actor: Person,
	prop: Dictionary,
	record_history: bool
) -> Dictionary:
	var updated: Dictionary = _normalize_topology(
		topology
	)
	var nodes: Dictionary = _safe_dictionary(
		updated.get("nodes", {})
	)
	var edges: Array = _safe_array(
		updated.get("edges", [])
	)
	var kind: String = str(
		mutation.get("kind", "")
	).strip_edges().to_lower()
	var mutation_applied: bool = false
	var reason: String = ""

	if kind in ["add_node", "add_room"]:
		var node_contract: Dictionary = _safe_dictionary(
			mutation.get(
				"node",
				mutation.get("room", {})
			)
		)

		if not node_contract.has("floor_index"):
			node_contract ["floor_index"] = int(
				mutation.get("floor_index", 0)
			)

		var new_node: Dictionary = _normalize_topology_node(
			node_contract
		)
		var new_node_id: String = str(
			new_node.get("node_id", "")
		)

		if new_node_id == "":
			reason = "missing_node_id"
		elif nodes.has(new_node_id):
			reason = "node_already_exists"
		else:
			nodes [new_node_id] = new_node

			var connect_to: Array = _safe_array(
				mutation.get("connect_to", [])
			)

			if connect_to.is_empty():
				var anchor: String = str(
					mutation.get(
						"anchor_node_id",
						updated.get("entry_node_id", "")
					)
				)

				if anchor != "":
					connect_to.append(anchor)

			for raw_target in connect_to:
				var target_id: String = str(
					raw_target
				)

				if (
					target_id == ""
					or not nodes.has(target_id)
				):
					continue

				edges.append(
					_topology_edge(
						target_id,
						new_node_id,
						str(
							mutation.get(
								"movement_kind",
								"doorway"
							)
						),
						_safe_array(
							mutation.get(
								"ownership_requirements",
								[]
							)
						),
						bool(
							mutation.get(
								"lockable",
								true
							)
						)
					)
				)

			mutation_applied = true

	elif kind in ["remove_node", "remove_room"]:
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)

		if not nodes.has(node_id):
			reason = "missing_node"
		else:
			var removed_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			removed_node ["removed"] = true
			removed_node ["state"] = "removed"
			nodes [node_id] = removed_node

			for edge_index in range(edges.size()):
				var edge: Dictionary = _safe_dictionary(
					edges [edge_index]
				)

				if _edge_touches_node(edge, node_id):
					edge ["enabled"] = false
					edge ["blocked_reason"] = "space_removed"
					edge ["blocked_text"] = "That space no longer exists."
					edges [edge_index] = edge

			mutation_applied = true

	elif kind in [
		"damage_node",
		"damage_room",
		"destroy_node",
		"destroy_room"
	]:
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)

		if not nodes.has(node_id):
			reason = "missing_node"
		else:
			var damaged_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			var damage_state: String = str(
				mutation.get(
					"damage_state",
					(
						"destroyed"
						if kind.begins_with("destroy")
						else "damaged"
					)
				)
			)

			damaged_node ["state"] = damage_state
			damaged_node ["damage_state"] = damage_state
			damaged_node ["damage_contract"] = mutation.duplicate(true)
			nodes [node_id] = damaged_node

			if damage_state in [
				"destroyed",
				"unsafe",
				"collapsed",
				"locked_off"
			]:
				for edge_index in range(edges.size()):
					var edge: Dictionary = _safe_dictionary(
						edges [edge_index]
					)

					if _edge_touches_node(edge, node_id):
						edge ["enabled"] = false
						edge ["blocked_reason"] = "target_%s" % damage_state
						edge ["blocked_text"] = "%s is %s." % [
							str(
								damaged_node.get(
									"title",
									"That space"
								)
							),
							damage_state.replace("_", " ")
						]
						edges [edge_index] = edge

			mutation_applied = true

	elif kind in ["repair_node", "repair_room"]:
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)

		if not nodes.has(node_id):
			reason = "missing_node"
		else:
			var repaired_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			repaired_node ["state"] = "intact"
			repaired_node ["damage_state"] = ""
			repaired_node.erase("damage_contract")
			nodes [node_id] = repaired_node

			for edge_index in range(edges.size()):
				var edge: Dictionary = _safe_dictionary(
					edges [edge_index]
				)

				if (
					_edge_touches_node(edge, node_id)
					and str(
						edge.get("blocked_reason", "")
					).begins_with("target_")
				):
					edge ["enabled"] = true
					edge ["blocked_reason"] = ""
					edge ["blocked_text"] = ""
					edges [edge_index] = edge

			mutation_applied = true

	elif kind in ["convert_node_type", "convert_room_type"]:
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)
		var new_type: String = str(
			mutation.get(
				"new_type",
				mutation.get("room_type", "")
			)
		).strip_edges()

		if not nodes.has(node_id):
			reason = "missing_node"
		elif new_type == "":
			reason = "missing_new_type"
		else:
			var converted_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			converted_node ["node_type"] = new_type
			converted_node ["room_type"] = new_type

			if str(
				mutation.get("new_title", "")
			).strip_edges() != "":
				converted_node ["title"] = str(
					mutation.get("new_title", "")
				)
				converted_node ["name"] = str(
					mutation.get("new_title", "")
				)

			nodes [node_id] = converted_node
			mutation_applied = true

	elif kind in ["add_edge", "connect_nodes"]:
		var edge: Dictionary = _normalize_topology_edge(
			_safe_dictionary(
				mutation.get("edge", mutation)
			)
		)

		if edge.is_empty():
			reason = "invalid_edge"
		elif (
			not nodes.has(
				str(edge.get("from_node_id", ""))
			)
			or not nodes.has(
				str(edge.get("to_node_id", ""))
			)
		):
			reason = "edge_node_missing"
		else:
			edges = _replace_or_append_edge(
				edges,
				edge
			)
			mutation_applied = true

	elif kind in ["remove_edge", "disconnect_nodes"]:
		var edge_id: String = str(
			mutation.get("edge_id", "")
		)
		var kept_edges: Array = []

		for raw_edge in edges:
			var edge: Dictionary = _safe_dictionary(
				raw_edge
			)

			if str(
				edge.get("edge_id", "")
			) == edge_id:
				mutation_applied = true
				continue

			kept_edges.append(edge)

		edges = kept_edges

		if not mutation_applied:
			reason = "missing_edge"

	elif kind in ["lock_edge", "unlock_edge"]:
		var edge_id: String = str(
			mutation.get("edge_id", "")
		)

		for edge_index in range(edges.size()):
			var edge: Dictionary = _safe_dictionary(
				edges [edge_index]
			)

			if str(
				edge.get("edge_id", "")
			) != edge_id:
				continue

			if not _actor_can_control_door(
				actor,
				prop,
				edge
			):
				reason = "door_control_denied"
				break

			var door_contract: Dictionary = _safe_dictionary(
				edge.get("door_contract", {})
			)

			if not bool(
				door_contract.get("lockable", false)
			):
				reason = "door_not_lockable"
				break

			door_contract ["locked"] = (
				kind == "lock_edge"
			)
			door_contract ["locked_by_actor_id"] = (
				int(actor.id)
				if actor != null
				else -1
			)

			if actor != null:
				var key_holder_ids: Array = _safe_array(
					door_contract.get(
						"key_holder_ids",
						[]
					)
				)

				if not key_holder_ids.has(int(actor.id)):
					key_holder_ids.append(int(actor.id))

				door_contract ["key_holder_ids"] = key_holder_ids

			edge ["door_contract"] = door_contract
			edges [edge_index] = edge
			mutation_applied = true
			break

		if not mutation_applied and reason == "":
			reason = "missing_edge"

	elif kind == "add_fixture":
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)
		var fixture: Dictionary = _safe_dictionary(
			mutation.get("fixture", {})
		)

		if not nodes.has(node_id):
			reason = "missing_node"
		elif fixture.is_empty():
			reason = "missing_fixture"
		else:
			var target_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			var fixtures: Array = _safe_array(
				target_node.get("fixtures", [])
			)
			var fixture_id: String = str(
				fixture.get("fixture_id", "")
			)

			if fixture_id == "":
				reason = "missing_fixture_id"
			elif _fixture_id_exists(
				fixtures,
				fixture_id
			):
				reason = "fixture_already_exists"
			else:
				fixtures.append(fixture)
				target_node ["fixtures"] = fixtures
				nodes [node_id] = target_node
				mutation_applied = true

	elif kind == "remove_fixture":
		var node_id: String = str(
			mutation.get(
				"node_id",
				mutation.get("room_id", "")
			)
		)
		var fixture_id: String = str(
			mutation.get("fixture_id", "")
		)

		if not nodes.has(node_id):
			reason = "missing_node"
		else:
			var target_node: Dictionary = _safe_dictionary(
				nodes.get(node_id, {})
			)
			var kept_fixtures: Array = []

			for raw_fixture in _safe_array(
				target_node.get("fixtures", [])
			):
				var fixture: Dictionary = _safe_dictionary(
					raw_fixture
				)

				if str(
					fixture.get("fixture_id", "")
				) == fixture_id:
					mutation_applied = true
					continue

				kept_fixtures.append(fixture)

			target_node ["fixtures"] = kept_fixtures
			nodes [node_id] = target_node

			if not mutation_applied:
				reason = "missing_fixture"

	else:
		reason = "unsupported_topology_mutation"

	if not mutation_applied:
		return {
			"success": false,
			"reason": reason,
			"topology": updated,
			"mutation": mutation.duplicate(true),
			"structure_authority": ENGINE_SCHEMA
		}

	updated ["nodes"] = nodes
	updated ["edges"] = edges

	if record_history:
		var history: Array = _safe_array(
			updated.get("mutation_history", [])
		)
		var recorded_mutation: Dictionary = mutation.duplicate(true)
		recorded_mutation ["committed_at_ms"] = int(
			Time.get_ticks_msec()
		)
		recorded_mutation ["committed_by_actor_id"] = (
			int(actor.id)
			if actor != null
			else -1
		)
		history.append(recorded_mutation)
		updated ["mutation_history"] = history

	updated = _normalize_topology(updated)

	return {
		"success": true,
		"reason": "topology_mutated",
		"topology": updated,
		"mutation": mutation.duplicate(true),
		"structure_authority": ENGINE_SCHEMA
	}
func _replace_or_append_edge(
	edges: Array,
	replacement: Dictionary
) -> Array:
	var out: Array = []
	var replacement_id: String = str(
		replacement.get("edge_id", "")
	)
	var replaced: bool = false

	for raw_edge in edges:
		var edge: Dictionary = _safe_dictionary(
			raw_edge
		)

		if str(
			edge.get("edge_id", "")
		) == replacement_id:
			out.append(replacement)
			replaced = true
		else:
			out.append(edge)

	if not replaced:
		out.append(replacement)

	return out


func _fixture_id_exists(
	fixtures: Array,
	fixture_id: String
) -> bool:
	for raw_fixture in fixtures:
		var fixture: Dictionary = _safe_dictionary(
			raw_fixture
		)

		if str(
			fixture.get("fixture_id", "")
		) == fixture_id:
			return true

	return false


func _actor_can_control_door(
	actor: Person,
	prop: Dictionary,
	edge: Dictionary
) -> bool:
	if actor == null:
		return false

	var tokens: Array = _actor_authority_tokens(
		actor,
		prop
	)
	if (
		tokens.has(
			"owner"
		)
		or tokens.has(
			"co_owner"
		)
		or tokens.has(
			"executive_resident"
		)
		or tokens.has(
			"royal"
		)
	):
		return true

	var door_raw: Variant = edge.get(
		"door_contract",
		{}
	)
	if typeof(door_raw) != TYPE_DICTIONARY:
		return false

	var door_contract: Dictionary = (
		door_raw as Dictionary
	)
	var holders_raw: Variant = door_contract.get(
		"key_holder_ids",
		[]
	)
	if typeof(holders_raw) != TYPE_ARRAY:
		return false

	return (
		holders_raw as Array
	).has(
		int(actor.id)
	)

func _actor_authority_tokens(
	actor: Person,
	prop: Dictionary
) -> Array:
	var tokens: Array = []

	if actor == null:
		return tokens

	var actor_id: int = int(actor.id)
	var owner_ids: Array = _safe_array(
		prop.get("owners", [])
	)
	var control_roles: Dictionary = _safe_dictionary(
		prop.get("control_roles", {})
	)

	for role_key in [
		"owner_ids",
		"co_owner_ids",
		"tenant_ids",
		"household_user_ids",
		"staff_ids",
		"manager_ids"
	]:
		for raw_id in _safe_array(
			control_roles.get(role_key, [])
		):
			if int(raw_id) != actor_id:
				continue

			match role_key:
				"owner_ids":
					tokens.append("owner")
				"co_owner_ids":
					tokens.append("co_owner")
				"tenant_ids":
					tokens.append("tenant")
				"household_user_ids":
					tokens.append("resident")
				"staff_ids", "manager_ids":
					tokens.append("staff")

	var direct_owner_id: int = int(
		prop.get(
			"owner_id",
			prop.get("owned_by", -1)
		)
	)

	if (
		direct_owner_id == actor_id
		or owner_ids.has(actor_id)
	):
		tokens.append("owner")

	var access_contract: Dictionary = _safe_dictionary(
		prop.get("access_contract", {})
	)

	if int(
		access_contract.get("granted_to", -1)
	) == actor_id:
		tokens.append("resident")

		if str(
			access_contract.get("type", "")
		) == "executive_residency":
			tokens.append("executive_resident")

	var actor_text: String = _actor_text_blob(actor)

	if actor_text.find("president") >= 0:
		tokens.append("president")

	if (
		actor_text.find("king") >= 0
		or actor_text.find("queen") >= 0
		or actor_text.find("royal") >= 0
	):
		tokens.append("royal")

	if (
		actor_text.find("security") >= 0
		or actor_text.find("guard") >= 0
	):
		tokens.append("security")

	if _actor_is_family_of_owner(
		actor,
		owner_ids
	):
		tokens.append("family")

	var unique: Array = []

	for raw_token in tokens:
		var token: String = str(raw_token)

		if token != "" and not unique.has(token):
			unique.append(token)

	return unique


func _actor_is_family_of_owner(
	actor: Person,
	owner_ids: Array
) -> bool:
	if actor == null:
		return false

	for raw_owner_id in owner_ids:
		var owner_id: int = int(raw_owner_id)

		if (
			actor.parents.has(owner_id)
			or actor.children.has(owner_id)
		):
			return true

		if (
			actor.partner != null
			and int(actor.partner.id) == owner_id
		):
			return true

	return false


func _requirements_satisfied(
	requirements: Array,
	tokens: Array
) -> bool:
	for raw_requirement in requirements:
		var requirement: String = str(
			raw_requirement
		).strip_edges().to_lower()

		match requirement:
			"", "none":
				continue
			"owner":
				if not tokens.has("owner"):
					return false
			"owner_or_family":
				if not (
					tokens.has("owner")
					or tokens.has("family")
					or tokens.has("resident")
				):
					return false
			"owner_or_royal":
				if not (
					tokens.has("owner")
					or tokens.has("royal")
				):
					return false
			"resident":
				if not (
					tokens.has("owner")
					or tokens.has("resident")
					or tokens.has("tenant")
				):
					return false
			_:
				if not tokens.has(requirement):
					return false

	return true


func _access_level_allowed(
	access_level: String,
	tokens: Array
) -> bool:
	match access_level:
		"", "public", "public_staff":
			return true

		"household":
			return (
				tokens.has("owner")
				or tokens.has("resident")
				or tokens.has("tenant")
				or tokens.has("family")
				or tokens.has("staff")
			)

		"household_private", "private_family", "household_hidden":
			return (
				tokens.has("owner")
				or tokens.has("resident")
				or tokens.has("family")
				or tokens.has("executive_resident")
			)

		"elite_private":
			return (
				tokens.has("owner")
				or tokens.has("family")
				or tokens.has("royal")
				or tokens.has("executive_resident")
			)

		"restricted":
			return (
				tokens.has("owner")
				or tokens.has("royal")
				or tokens.has("president")
				or tokens.has("security")
				or tokens.has("staff")
			)

		"ultra_restricted":
			return (
				tokens.has("owner")
				or tokens.has("president")
				or tokens.has("security")
			)

	return false


func _actor_text_blob(
	actor: Person
) -> String:
	if actor == null:
		return ""

	var parts: Array = []

	for key in [
		"job",
		"job_title",
		"career",
		"career_title",
		"role",
		"title",
		"government_role",
		"political_office",
		"office",
		"occupation",
		"status"
	]:
		var value: Variant = actor.get(key)

		if value != null:
			parts.append(str(value).to_lower())

	return " ".join(parts)

func _spatial_description(prop: Dictionary, _floors: Array, _active_floor: int, _active_room: String, current_room: Dictionary) -> String:
	var property_name: String = str(prop.get("display_name", prop.get("type", "property")))
	var room_title: String = str(current_room.get("title", "room")).to_lower()
	return "You are inside %s, standing in the %s. The space exists around you as a navigable interior, not a flat menu." % [
		property_name,
		room_title
	]
func _surroundings_for_topology_node(
	actor: Person,
	prop: Dictionary,
	topology: Dictionary,
	active_node_id: String,
	current_room: Dictionary
) -> Array:
	var out: Array = []
	var seen_target_ids: Dictionary = {}
	var current_state: String = str(
		current_room.get(
			"state",
			"intact"
		)
	).strip_edges().to_lower()

	if current_state not in [
		"",
		"intact"
	]:
		out.append(
			"⚠️ %s is currently %s." % [
				str(
					current_room.get(
						"title",
						"This space"
					)
				),
				current_state.replace(
					"_",
					" "
				)
			]
		)

	for raw_edge in _adjacent_edges(
		topology,
		active_node_id
	):
		var edge: Dictionary = _safe_dictionary(raw_edge)
		var target_node_id: String = _other_edge_node(
			edge,
			active_node_id
		)

		if (
			target_node_id == ""
			or seen_target_ids.has(target_node_id)
		):
			continue

		var target_node: Dictionary = _topology_node(
			topology,
			target_node_id
		)

		if (
			target_node.is_empty()
			or bool(
				target_node.get(
					"removed",
					false
				)
			)
		):
			continue

		seen_target_ids [target_node_id] = true

		var traversal_report: Dictionary = resolve_edge_traversal_contract(
			actor,
			prop,
			topology,
			active_node_id,
			target_node_id
		)
		var allowed: bool = bool(
			traversal_report.get(
				"allowed",
				false
			)
		)
		var target_state: String = str(
			target_node.get(
				"state",
				"intact"
			)
		).strip_edges().to_lower()
		var title: String = str(
			target_node.get(
				"title",
				"Space"
			)
		)
		var icon: String = str(
			target_node.get(
				"icon",
				"🚪"
			)
		)
		var movement_kind: String = str(
			edge.get(
				"movement_kind",
				"walk"
			)
		).replace(
			"_",
			" "
		)

		if target_state in [
			"destroyed",
			"collapsed",
			"unsafe",
			"locked_off"
		]:
			out.append(
				"❌ %s — %s" % [
					title,
					target_state.replace(
						"_",
						" "
					).capitalize()
				]
			)
			continue

		if not allowed:
			out.append(
				"🔒 %s — %s" % [
					title,
					str(
						traversal_report.get(
							"narrative",
							"This route is currently unavailable."
						)
					)
				]
			)
			continue

		var approach_text: String = str(
			target_node.get(
				"approach_label",
				""
			)
		).strip_edges()

		if approach_text == "":
			approach_text = "%s %s is connected by %s." % [
				icon,
				title,
				movement_kind
			]

		out.append(approach_text)
	var entry_node_id: String = str(
		topology.get(
			"entry_node_id",
			""
		)
	).strip_edges()

	if (
		active_node_id != ""
		and active_node_id != entry_node_id
		and seen_target_ids.size() == 1
	):
		out.append(
			"This is a dead end. The connected passage is your way back."
		)
	for raw_fixture in _safe_array(
		current_room.get(
			"fixtures",
			[]
		)
	):
		var fixture: Dictionary = _safe_dictionary(
			raw_fixture
		)

		if fixture.is_empty():
			continue

		out.append(
			str(
				fixture.get(
					"surface_text",
					fixture.get(
						"label",
						fixture.get(
							"title",
							"Something usable is here."
						)
					)
				)
			)
		)

	if out.is_empty():
		out.append(
			"No adjacent spatial edges are currently observable from this space."
		)

	return out

func _surroundings_for_room(floors: Array, active_floor: int, active_room: String, current_room: Dictionary) -> Array:
	var out: Array = []

	for raw_room in _rooms_on_floor(floors, active_floor):
		if typeof(raw_room) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = raw_room
		var room_id: String = str(room.get("room_id", ""))
		if room_id == "" or room_id == active_room:
			continue
		out.append(str(room.get("approach_label", "Nearby: %s" % str(room.get("title", "Room")))))

	for raw_fixture in _safe_array(current_room.get("fixtures", [])):
		var fixture: Dictionary = _safe_dictionary(raw_fixture)
		out.append(str(fixture.get("surface_text", fixture.get("label", fixture.get("title", "Something usable is here.")))))

	return out


func _adjacent_floor_index(floors: Array, active_floor: int, direction: String) -> int:
	var indices: Array = []
	for raw_floor in floors:
		if typeof(raw_floor) != TYPE_DICTIONARY:
			continue
		var floor_contract: Dictionary = raw_floor
		var floor_index: int = int(floor_contract.get("floor_index", 0))
		if not indices.has(floor_index):
			indices.append(floor_index)

	indices.sort()

	if indices.is_empty():
		return active_floor

	var current_position: int = indices.find(active_floor)
	if current_position == -1:
		current_position = 0

	if direction == "up":
		return int(indices [min(current_position + 1, indices.size() - 1)])
	if direction == "down":
		return int(indices [max(current_position - 1, 0)])

	return active_floor


func _rooms_on_floor(floors: Array, floor_index: int) -> Array:
	for raw_floor in floors:
		if typeof(raw_floor) != TYPE_DICTIONARY:
			continue
		var floor_contract: Dictionary = raw_floor
		if int(floor_contract.get("floor_index", -1)) == floor_index:
			return _safe_array(floor_contract.get("rooms", []))
	return []


func _first_room_on_floor(floors: Array, floor_index: int) -> Dictionary:
	var rooms: Array = _rooms_on_floor(floors, floor_index)
	if rooms.is_empty():
		return {}
	return _safe_dictionary(rooms [0])


func _room_by_id(floors: Array, room_id: String) -> Dictionary:
	for raw_floor in floors:
		if typeof(raw_floor) != TYPE_DICTIONARY:
			continue
		var floor_contract: Dictionary = raw_floor
		for raw_room in _safe_array(floor_contract.get("rooms", [])):
			if typeof(raw_room) != TYPE_DICTIONARY:
				continue
			var room: Dictionary = raw_room
			if str(room.get("room_id", "")) == room_id:
				return room
	return {}


func _normalize_floors(floors: Array) -> Array:
	var out: Array = []
	for raw_floor in floors:
		if typeof(raw_floor) != TYPE_DICTIONARY:
			continue

		var floor_contract: Dictionary = (raw_floor as Dictionary).duplicate(true)
		var normalized_rooms: Array = []

		for raw_room in _safe_array(floor_contract.get("rooms", [])):
			var room: Dictionary = _safe_dictionary(raw_room)
			if room.is_empty():
				continue
			if str(room.get("room_id", "")).strip_edges() == "":
				continue
			if str(room.get("title", "")).strip_edges() == "":
				room ["title"] = str(room.get("name", room.get("room_id", "Room"))).replace("_", " ").capitalize()
			if str(room.get("name", "")).strip_edges() == "":
				room ["name"] = str(room.get("title", "Room"))
			if not room.has("floor_index"):
				room ["floor_index"] = int(floor_contract.get("floor_index", 0))
			if not room.has("fixtures"):
				room ["fixtures"] = []
			if str(room.get("approach_label", "")).strip_edges() == "":
				room ["approach_label"] = "Go to %s" % str(room.get("title", "Room"))
			normalized_rooms.append(room)

		floor_contract ["rooms"] = normalized_rooms
		out.append(floor_contract)

	return out


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []