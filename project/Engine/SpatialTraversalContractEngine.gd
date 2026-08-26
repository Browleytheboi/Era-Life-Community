extends Resource
class_name SpatialTraversalContractEngine

const ENGINE_SCHEMA:= "eralife.spatial_traversal_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null


func _init(_gs: GameState = null) -> void:
	gs = _gs


func commit_property_space_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No actor could be resolved for spatial traversal."
		)

	var property_id: int = int(
		payload.get(
			"property_id",
			-1
		)
	)
	if property_id <= 0:
		return _failure(
			"missing_property_id",
			"No property was provided for traversal."
		)

	var requested_owner_id: int = int(
		payload.get(
			"property_owner_id",
			-1
		)
	)
	var property_context: Dictionary = (
		_property_context(
			actor,
			property_id,
			requested_owner_id
		)
	)
	if not bool(
		property_context.get(
			"success",
			false
		)
	):
		return _failure(
			str(
				property_context.get(
					"reason",
					"missing_property"
				)
			),
			str(
				property_context.get(
					"text",
					"That property could not be found."
				)
			)
		)

	var prop_raw: Variant = property_context.get(
		"property",
		{}
	)
	var node_raw: Variant = property_context.get(
		"node",
		{}
	)
	if (
		typeof(prop_raw) != TYPE_DICTIONARY
		or typeof(node_raw) != TYPE_DICTIONARY
	):
		return _failure(
			"missing_property_context",
			"That property space could not be prepared."
		)

	var prop: Dictionary = prop_raw as Dictionary
	var node: Dictionary = node_raw as Dictionary
	if (
		prop.is_empty()
		or node.is_empty()
	):
		return _failure(
			"missing_property_context",
			"That property space could not be prepared."
		)

	var property_owner_id: int = int(
		property_context.get(
			"property_owner_id",
			requested_owner_id
		)
	)



	var resident_graph: Dictionary = (
		project_resident_property_graph_cursor(
			actor,
			prop,
			node
		)
	)
	if not bool(
		resident_graph.get(
			"resident_graph_hot",
			false
		)
	):
		return {
			"success": false,
			"committed": false,
			"allowed": false,
			"reason": "resident_property_graph_not_hot",
			"text": (
				"The property's resident spatial graph is not attached yet."
			),
			"actor_id": int(actor.id),
			"property_id": property_id,
			"property_owner_id": property_owner_id,
			"surface_delta_contract": {},
			"graph_rebuild_performed": false,
			"commit_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var action_id: String = (
		_payload_action_id(
			payload
		)
	)




	if action_id in [
		"inspect_room",
		"view_household"
	]:
		var observation: Dictionary = (
			_resolve_resident_property_observation(
				actor,
				prop,
				payload,
				resident_graph
			)
		)

		var observation_delta_raw: Variant = (
			observation.get(
				"surface_delta_contract",
				{}
			)
		)
		var observation_delta: Dictionary = (
			observation_delta_raw as Dictionary
			if typeof(observation_delta_raw) == TYPE_DICTIONARY
			else {}
		)

		return {
			"success": bool(
				observation.get(
					"success",
					false
				)
			),
			"committed": false,
			"allowed": bool(
				observation.get(
					"allowed",
					false
				)
			),
			"reason": str(
				observation.get(
					"reason",
					""
				)
			),
			"text": str(
				observation.get(
					"narrative",
					""
				)
			),
			"narrative": str(
				observation.get(
					"narrative",
					""
				)
			),
			"actor_id": int(actor.id),
			"property_id": property_id,
			"property_owner_id": property_owner_id,
			"spatial_traversal_report": observation,
			"surface_delta_contract": observation_delta,
			"presentation_cue": "",
			"graph_rebuild_performed": false,
			"presence_resolution_count": 0,
			"commit_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var resolution: Dictionary = (
		resolve_property_traversal(
			actor,
			prop,
			node,
			payload,
			resident_graph
		)
	)
	var narrative: String = str(
		resolution.get(
			"narrative",
			"You cannot move that way right now."
		)
	)
	var allowed: bool = bool(
		resolution.get(
			"allowed",
			false
		)
	)
	var mutation_committed: bool = (
		allowed
		and bool(
			resolution.get(
				"committed",
				true
			)
		)
	)

	if mutation_committed:
		_commit_property_node(
			actor,
			prop,
			node
		)

		if narrative.strip_edges() != "":
			call_deferred(
				"_emit_property_traversal_diary_tail",
				actor,
				narrative
			)

	var delta_raw: Variant = resolution.get(
		"surface_delta_contract",
		{}
	)
	var surface_delta: Dictionary = (
		delta_raw as Dictionary
		if typeof(delta_raw) == TYPE_DICTIONARY
		else {}
	)

	return {
		"success": allowed,
		"committed": mutation_committed,
		"allowed": allowed,
		"reason": str(
			resolution.get(
				"reason",
				""
			)
		),
		"text": narrative,
		"narrative": narrative,
		"actor_id": int(actor.id),
		"property_id": property_id,
		"property_owner_id": property_owner_id,
		"spatial_traversal_report": resolution,
		"surface_delta_contract": surface_delta,
		"presentation_cue": str(
			resolution.get(
				"presentation_cue",
				""
			)
		),
		"graph_rebuild_performed": false,
		"presence_resolution_count": int(
			resolution.get(
				"presence_resolution_count",
				0
			)
		),
		"post_commit_diary_deferred": (
			mutation_committed
		),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func leave_property_space(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No actor could be resolved for property exit."
		)

	var property_id: int = int(
		payload.get(
			"property_id",
			-1
		)
	)

	if property_id <= 0:
		return _failure(
			"missing_property_id",
			"No property was provided for property exit."
		)

	var requested_owner_id: int = int(
		payload.get(
			"property_owner_id",
			-1
		)
	)

	var property_context: Dictionary = (
		_property_context(
			actor,
			property_id,
			requested_owner_id
		)
	)

	if not bool(
		property_context.get(
			"success",
			false
		)
	):
		return _failure(
			str(
				property_context.get(
					"reason",
					"missing_property"
				)
			),
			str(
				property_context.get(
					"text",
					"That property could not be found."
				)
			)
		)

	var prop_raw: Variant = (
		property_context.get(
			"property",
			{}
		)
	)

	var node_raw: Variant = (
		property_context.get(
			"node",
			{}
		)
	)

	if (
		typeof(prop_raw) != TYPE_DICTIONARY
		or typeof(node_raw) != TYPE_DICTIONARY
	):
		return _failure(
			"missing_property_context",
			"That property space could not be resolved."
		)

	var prop: Dictionary = (
		prop_raw as Dictionary
	)
	var node: Dictionary = (
		node_raw as Dictionary
	)

	var resident_graph: Dictionary = (
		project_resident_property_graph_cursor(
			actor,
			prop,
			node
		)
	)

	if not bool(
		resident_graph.get(
			"resident_graph_hot",
			false
		)
	):
		return _failure(
			"resident_property_graph_not_hot",
			"The property's resident spatial graph is not attached yet."
		)

	var entry_node_id: String = str(
		resident_graph.get(
			"entry_node_id",
			""
		)
	).strip_edges()

	var floors_raw: Variant = resident_graph.get(
		"floors",
		[]
	)
	var floors: Array = (
		floors_raw as Array
		if typeof(floors_raw) == TYPE_ARRAY
		else []
	)

	var entry_room: Dictionary = (
		_room_by_id(
			floors,
			entry_node_id
		)
	)

	if entry_room.is_empty():
		return _failure(
			"missing_property_entry",
			"The property's entry space could not be resolved."
		)

	var previous_room: String = str(
		node.get(
			"active_room",
			""
		)
	)

	node [
		"previous_room"
	] = previous_room
	node [
		"active_floor"
	] = int(
		entry_room.get(
			"floor_index",
			0
		)
	)
	node [
		"active_room"
	] = entry_node_id
	node [
		"active_fixture"
	] = ""
	node [
		"last_traversal_action"
	] = "leave_property"
	node [
		"last_traversal_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	node [
		"last_traversal_authority"
	] = ENGINE_SCHEMA
	node [
		"cursor_revision"
	] = int(
		node.get(
			"cursor_revision",
			0
		)
	) + 1

	var actor_locations_raw: Variant = node.get(
		"actor_locations",
		{}
	)

	var actor_locations: Dictionary = (
		(actor_locations_raw as Dictionary).duplicate(false)
		if typeof(actor_locations_raw) == TYPE_DICTIONARY
		else {}
	)

	actor_locations.erase(
		str(
			int(
				actor.id
			)
		)
	)

	node [
		"actor_locations"
	] = actor_locations

	_commit_property_node(
		actor,
		prop,
		node
	)

	var reset_graph: Dictionary = (
		project_resident_property_graph_cursor(
			actor,
			prop,
			node
		)
	)

	var entry_title: String = str(
		entry_room.get(
			"title",
			"the entrance"
		)
	)

	var narrative: String = (
		"You leave the property. Your next entry begins at %s."
		% entry_title
	)

	var delta: Dictionary = (
		_surface_delta_from_resident_graph(
			actor,
			prop,
			reset_graph,
			narrative,
			"",
			{}
		)
	)




	delta [
		"occupants"
	] = []
	delta [
		"presence_summary"
	] = (
		"Entry presence is refreshing."
	)

	return {
		"success": true,
		"allowed": true,
		"committed": true,
		"schema": (
			"eralife.spatial_traversal.exit_resolution"
		),
		"version": CONTRACT_VERSION,
		"action_id": "leave_property",
		"actor_id": int(
			actor.id
		),
		"property_id": property_id,
		"property_owner_id": int(
			property_context.get(
				"property_owner_id",
				requested_owner_id
			)
		),
		"previous_room": previous_room,
		"entry_room": entry_node_id,
		"narrative": narrative,
		"text": narrative,
		"surface_delta_contract": delta,
		"presentation_cue": "",
		"graph_rebuild_performed": false,
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _surface_contract_from_traversal_resolution(
	actor: Person,
	prop: Dictionary,
	property_id: int,
	property_owner_id: int,
	resolution: Dictionary,
	fallback_graph: Dictionary,
	payload: Dictionary,
	status_text: String
) -> Dictionary:
	var graph: Dictionary = _safe_dictionary(
		resolution.get(
			"graph",
			fallback_graph
		)
	)

	if graph.is_empty():
		graph = fallback_graph

	var node: Dictionary = _safe_dictionary(
		resolution.get(
			"node",
			{}
		)
	)
	var presence_delta: Dictionary = _safe_dictionary(
		resolution.get(
			"presence_delta",
			{}
		)
	)
	var presence: Dictionary = _safe_dictionary(
		presence_delta.get(
			"new_presence_contract",
			{}
		)
	)
	var source_projection: Dictionary = _safe_dictionary(
		payload.get(
			"source_surface_projection",
			{}
		)
	)
	var navigation_actions: Array = _safe_array(
		graph.get(
			"navigation_actions",
			[]
		)
	)

	if navigation_actions.is_empty():
		navigation_actions = _safe_array(
			graph.get(
				"room_navigation_actions",
				[]
			)
		)

	if navigation_actions.is_empty():
		navigation_actions = _safe_array(
			graph.get(
				"movement_options",
				[]
			)
		)

	if navigation_actions.is_empty():
		navigation_actions = _safe_array(
			graph.get(
				"spatial_movement_actions",
				[]
			)
		)

	var title: String = str(
		source_projection.get(
			"title",
			prop.get(
				"name",
				prop.get(
					"property_type",
					"PROPERTY SPACE"
				)
			)
		)
	)

	return {
		"success": true,
		"schema": (
			"eralife.property_space.surface_contract"
		),
		"version": CONTRACT_VERSION,
		"mode": "interior",
		"title": title,
		"subtitle": status_text,
		"actor_id": int(
			actor.id
			if actor != null
			else -1
		),
		"property_id": property_id,
		"property_owner_id": property_owner_id,
		"bedrooms": int(
			source_projection.get(
				"bedrooms",
				node.get(
					"bedrooms",
					prop.get(
						"bedrooms",
						1
					)
				)
			)
		),
		"bathrooms": int(
			source_projection.get(
				"bathrooms",
				node.get(
					"bathrooms",
					prop.get(
						"bathrooms",
						1
					)
				)
			)
		),
		"identity": source_projection.get(
			"identity",
			node.get(
				"identity",
				{}
			)
		),
		"containers": source_projection.get(
			"containers",
			node.get(
				"containers",
				{}
			)
		),
		"spatial_topology": graph.get(
			"spatial_topology",
			{}
		),
		"entry_node_id": str(
			graph.get(
				"entry_node_id",
				""
			)
		),
		"floors": graph.get(
			"floors",
			[]
		),
		"active_floor": int(
			graph.get(
				"active_floor",
				node.get(
					"active_floor",
					0
				)
			)
		),
		"active_room": str(
			graph.get(
				"active_room",
				node.get(
					"active_room",
					"entryway"
				)
			)
		),
		"current_room": graph.get(
			"current_room",
			{}
		),
		"spatial_description": str(
			graph.get(
				"spatial_description",
				""
			)
		),
		"surroundings": graph.get(
			"surroundings",
			[]
		),
		"room_navigation_actions": navigation_actions,
		"navigation_actions": navigation_actions,
		"movement_options": navigation_actions,
		"spatial_movement_actions": navigation_actions,
		"room_interaction_actions": graph.get(
			"room_interaction_actions",
			[]
		),
		"actor_locations": graph.get(
			"actor_locations",
			{}
		),
		"occupants": presence.get(
			"occupants",
			[]
		),
		"presence_summary": presence.get(
			"summary",
			"No one else is in this room right now."
		),
		"status_text": status_text,
		"actions": source_projection.get(
			"actions",
			[
				{
					"action_id": "open_makeover",
					"label": "Open Property Makeover"
				},
				{
					"action_id": "view_household",
					"label": "View Household Members"
				},
				{
					"action_id": "leave_property",
					"label": "Leave Property"
				}
			]
		),
		"truth_state": "observable",
		"ui_is_renderer_only": true,
		"commit_authority": ENGINE_SCHEMA,
		"movement_authority": ENGINE_SCHEMA,
		"structure_authority": (
			"eralife.room_graph_contract_engine"
		),
		"presence_authority": "eralife.presence_engine",
	}
func _emit_property_traversal_diary_tail(
	actor: Person,
	text: String
) -> void:
	if (
		actor == null
		or text.strip_edges() == ""
	):
		return

	_emit_diary(
		actor,
		text
	)
func _resolve_resident_property_observation(
	actor: Person,
	prop: Dictionary,
	payload: Dictionary,
	resident_graph: Dictionary
) -> Dictionary:
	var action_id: String = (
		_payload_action_id(
			payload
		)
	)

	var current_room_raw: Variant = (
		resident_graph.get(
			"current_room",
			{}
		)
	)
	var current_room: Dictionary = (
		current_room_raw as Dictionary
		if typeof(current_room_raw) == TYPE_DICTIONARY
		else {}
	)

	if current_room.is_empty():
		return {
			"success": false,
			"allowed": false,
			"committed": false,
			"reason": "resident_room_not_observable",
			"narrative": (
				"The current room is not observable yet."
			),
			"presentation_cue": "",
			"surface_delta_contract": {},
			"graph_rebuild_performed": false,
			"commit_authority": ENGINE_SCHEMA
		}

	var active_floor: int = int(
		resident_graph.get(
			"active_floor",
			current_room.get(
				"floor_index",
				0
			)
		)
	)
	var active_room: String = str(
		resident_graph.get(
			"active_room",
			current_room.get(
				"room_id",
				""
			)
		)
	).strip_edges()

	var narrative: String = (
		_movement_narrative(
			action_id,
			payload,
			current_room,
			current_room,
			"",
			{}
		)
	)

	return {
		"success": true,
		"allowed": true,
		"committed": false,
		"schema": (
			"eralife.spatial_traversal.observation_resolution"
		),
		"version": CONTRACT_VERSION,
		"action_id": action_id,

		"old_location": {
			"floor": active_floor,
			"room": active_room
		},
		"new_location": {
			"floor": active_floor,
			"room": active_room,
			"fixture_id": ""
		},

		"narrative": narrative,
		"presentation_cue": "",
		"presence_resolution_count": 0,

		"surface_delta_contract": (
			_surface_delta_from_resident_graph(
				actor,
				prop,
				resident_graph,
				narrative,
				"",
				{}
			)
		),

		"graph_rebuild_performed": false,
		"commit_authority": ENGINE_SCHEMA
	}
func resolve_property_traversal(
	actor: Person,
	prop: Dictionary,
	node: Dictionary,
	payload: Dictionary,
	old_graph: Dictionary = {}
) -> Dictionary:
	var graph: Dictionary = old_graph
	if graph.is_empty():
		graph = project_resident_property_graph_cursor(
			actor,
			prop,
			node
		)

	var floors_raw: Variant = graph.get(
		"floors",
		[]
	)
	var floors: Array = (
		floors_raw as Array
		if typeof(floors_raw) == TYPE_ARRAY
		else []
	)
	var active_floor: int = int(
		node.get(
			"active_floor",
			graph.get(
				"active_floor",
				0
			)
		)
	)
	var active_room: String = str(
		node.get(
			"active_room",
			graph.get(
				"active_room",
				graph.get(
					"entry_node_id",
					""
				)
			)
		)
	).strip_edges()
	var current_room: Dictionary = _room_by_id(
		floors,
		active_room
	)
	var action_id: String = _payload_action_id(
		payload
	)

	if action_id in [
		"lock_spatial_edge",
		"unlock_spatial_edge",
		"bolt_spatial_edge",
		"unbolt_spatial_edge"
	]:
		var control_report: Dictionary = (
			_commit_topology_control(
				actor,
				prop,
				node,
				graph,
				payload,
				action_id
			)
		)
		if not bool(
			control_report.get(
				"success",
				false
			)
		):
			var denied_text: String = str(
				control_report.get(
					"text",
					"You cannot secure that passage."
				)
			)
			return {
				"success": false,
				"allowed": false,
				"reason": str(
					control_report.get(
						"reason",
						"door_control_denied"
					)
				),
				"narrative": denied_text,
				"presentation_cue": "",
				"presence_resolution_count": 0,
				"surface_delta_contract": (
					_surface_delta_from_resident_graph(
						actor,
						prop,
						graph,
						denied_text,
						"",
						{}
					)
				),
				"commit_authority": ENGINE_SCHEMA
			}

		var controlled_graph: Dictionary = (
			project_resident_property_graph_cursor(
				actor,
				prop,
				node
			)
		)
		var security_mode: String = str(
			control_report.get(
				"security_mode",
				"lock"
			)
		)
		var releasing: bool = action_id in [
			"unlock_spatial_edge",
			"unbolt_spatial_edge"
		]
		var control_narrative: String = ""
		if security_mode == "bolt":
			control_narrative = (
				"You unbolt the passage."
				if releasing
				else "You bolt the passage shut."
			)
		else:
			control_narrative = (
				"You unlock the door."
				if releasing
				else "You lock the door."
			)

		var control_presentation_cue: String = (
			"door_unlock"
			if releasing
			else "door_lock"
		)

		return {
			"success": true,
			"allowed": true,
			"schema": (
				"eralife.spatial_traversal.resolution"
			),
			"version": CONTRACT_VERSION,
			"action_id": action_id,
			"old_location": {
				"floor": active_floor,
				"room": active_room
			},
			"new_location": {
				"floor": active_floor,
				"room": active_room,
				"fixture_id": ""
			},
			"narrative": control_narrative,
			"presentation_cue": (
				control_presentation_cue
			),
			"presence_resolution_count": 0,
			"surface_delta_contract": (
				_surface_delta_from_resident_graph(
					actor,
					prop,
					controlled_graph,
					control_narrative,
					control_presentation_cue,
					{}
				)
			),
			"constraints": [],
			"graph_rebuild_performed": false,
			"commit_authority": ENGINE_SCHEMA
		}

	var target: Dictionary = _resolve_target(
		actor,
		prop,
		node,
		payload,
		graph
	)
	if not bool(
		target.get(
			"resolved",
			false
		)
	):
		var invalid_text: String = str(
			target.get(
				"narrative",
				"That destination does not exist in this property."
			)
		)
		return {
			"success": false,
			"allowed": false,
			"reason": "invalid_target",
			"narrative": invalid_text,
			"presentation_cue": "",
			"presence_resolution_count": 0,
			"surface_delta_contract": (
				_surface_delta_from_resident_graph(
					actor,
					prop,
					graph,
					invalid_text,
					"",
					{}
				)
			),
			"commit_authority": ENGINE_SCHEMA
		}

	var target_floor: int = int(
		target.get(
			"floor",
			active_floor
		)
	)
	var target_room: String = str(
		target.get(
			"room",
			active_room
		)
	).strip_edges()
	var target_fixture: String = str(
		target.get(
			"fixture_id",
			""
		)
	).strip_edges()
	var target_room_contract: Dictionary = _room_by_id(
		floors,
		target_room
	)
	if target_room_contract.is_empty():
		var missing_text: String = (
			"You cannot find that room from here."
		)
		return {
			"success": false,
			"allowed": false,
			"reason": "missing_target_room",
			"narrative": missing_text,
			"presentation_cue": "",
			"presence_resolution_count": 0,
			"surface_delta_contract": (
				_surface_delta_from_resident_graph(
					actor,
					prop,
					graph,
					missing_text,
					"",
					{}
				)
			),
			"commit_authority": ENGINE_SCHEMA
		}

	var physics_report: Dictionary = _check_physical_path(
		actor,
		prop,
		graph,
		active_floor,
		active_room,
		target_floor,
		target_room,
		action_id,
		payload
	)
	if not bool(
		physics_report.get(
			"allowed",
			false
		)
	):
		var blocked_text: String = str(
			physics_report.get(
				"narrative",
				"There is no clear route that way."
			)
		)
		return {
			"success": false,
			"allowed": false,
			"reason": str(
				physics_report.get(
					"reason",
					"blocked_path"
				)
			),
			"narrative": blocked_text,
			"presentation_cue": "",
			"presence_resolution_count": 0,
			"surface_delta_contract": (
				_surface_delta_from_resident_graph(
					actor,
					prop,
					graph,
					blocked_text,
					"",
					{}
				)
			),
			"constraints": physics_report.get(
				"constraints",
				[]
			),
			"commit_authority": ENGINE_SCHEMA
		}

	var authority_report: Dictionary = _check_authority(
		actor,
		prop,
		target_room_contract,
		target_floor,
		target_room,
		payload
	)
	if not bool(
		authority_report.get(
			"allowed",
			false
		)
	):
		var authority_text: String = str(
			authority_report.get(
				"narrative",
				"You do not have access to that area."
			)
		)
		return {
			"success": false,
			"allowed": false,
			"reason": str(
				authority_report.get(
					"reason",
					"access_denied"
				)
			),
			"narrative": authority_text,
			"presentation_cue": "",
			"presence_resolution_count": 0,
			"surface_delta_contract": (
				_surface_delta_from_resident_graph(
					actor,
					prop,
					graph,
					authority_text,
					"",
					{}
				)
			),
			"commit_authority": ENGINE_SCHEMA
		}

	var moved_between_rooms: bool = (
		target_room != active_room
		or target_floor != active_floor
	)



	node ["active_floor"] = target_floor
	node ["active_room"] = target_room
	node ["active_fixture"] = target_fixture
	node ["last_traversal_action"] = action_id
	node ["last_traversal_at_ms"] = int(
		Time.get_ticks_msec()
	)
	node ["last_traversal_authority"] = ENGINE_SCHEMA
	node ["cursor_revision"] = int(
		node.get(
			"cursor_revision",
			0
		)
	) + 1

	_write_actor_location(
		node,
		actor,
		prop,
		target_floor,
		target_room,
		target_fixture
	)

	var new_graph: Dictionary = (
		project_resident_property_graph_cursor(
			actor,
			prop,
			node
		)
	)
	var presence_delta: Dictionary = {}
	var presence_resolution_count: int = 0
	if moved_between_rooms:
		presence_delta = _presence_delta(
			actor,
			prop,
			graph,
			new_graph
		)
		presence_resolution_count = 1

	var narrative: String = _movement_narrative(
		action_id,
		payload,
		current_room,
		target_room_contract,
		target_fixture,
		authority_report
	)
	var presentation_cue: String = (
		"walking"
		if moved_between_rooms
		else ""
	)

	return {
		"success": true,
		"allowed": true,
		"schema": (
			"eralife.spatial_traversal.resolution"
		),
		"version": CONTRACT_VERSION,
		"action_id": action_id,
		"old_location": {
			"floor": active_floor,
			"room": active_room
		},
		"new_location": {
			"floor": target_floor,
			"room": target_room,
			"fixture_id": target_fixture
		},
		"narrative": narrative,
		"presentation_cue": presentation_cue,
		"presence_delta": presence_delta,
		"presence_resolution_count": (
			presence_resolution_count
		),
		"constraints": (
			physics_report.get(
				"constraints",
				[]
			)
			+ authority_report.get(
				"constraints",
				[]
			)
		),
		"surface_delta_contract": (
			_surface_delta_from_resident_graph(
				actor,
				prop,
				new_graph,
				narrative,
				presentation_cue,
				presence_delta
			)
		),
		"graph_rebuild_performed": false,
		"commit_authority": ENGINE_SCHEMA
	}
func _commit_topology_control(
	actor: Person,
	prop: Dictionary,
	node: Dictionary,
	graph: Dictionary,
	payload: Dictionary,
	action_id: String
) -> Dictionary:
	if (
		gs == null
		or gs.property_engine == null
		or not gs.property_engine.has_method(
			"apply_property_spatial_topology_mutation"
		)
	):
		return {
			"success": false,
			"reason": "missing_property_contract_authority",
			"text": (
				"The property contract authority cannot change that passage right now."
			)
		}

	var security_mode: String = (
		_property_security_mode(
			prop,
			node
		)
	)
	var releasing: bool = action_id in [
		"unlock_spatial_edge",
		"unbolt_spatial_edge"
	]

	if (
		security_mode == "bolt"
		and action_id in [
			"lock_spatial_edge",
			"unlock_spatial_edge"
		]
	):
		return {
			"success": false,
			"reason": "lock_semantics_unavailable_in_era",
			"text": (
				"This era does not use a keyed door lock here. "
				+ "Bolt or unbolt the passage instead."
			)
		}

	var edge_id: String = str(
		payload.get(
			"edge_id",
			""
		)
	).strip_edges()
	var active_room: String = str(
		node.get(
			"active_room",
			graph.get(
				"active_room",
				""
			)
		)
	).strip_edges()
	var target_room: String = str(
		payload.get(
			"target_room_id",
			payload.get(
				"room_id",
				""
			)
		)
	).strip_edges()
	var adjacent: Dictionary = _adjacent_contract_for_target(
		graph,
		active_room,
		target_room,
		edge_id
	)
	if adjacent.is_empty():
		return {
			"success": false,
			"reason": "missing_adjacent_edge",
			"text": (
				"That passage is not connected to your current room."
			)
		}

	if edge_id == "":
		edge_id = str(
			adjacent.get(
				"edge_id",
				adjacent.get(
					"connection_id",
					""
				)
			)
		).strip_edges()
	if edge_id == "":
		return {
			"success": false,
			"reason": "missing_edge_id",
			"text": (
				"The connected passage has no stable edge identity."
			)
		}

	var mutation: Dictionary = {
		"kind": (
			"unlock_edge"
			if releasing
			else "lock_edge"
		),
		"edge_id": edge_id,
		"actor_id": int(actor.id),
		"security_mode": security_mode,
		"semantic_action_id": action_id,
		"from_room_id": active_room,
		"target_room_id": target_room,
		"source": ENGINE_SCHEMA
	}
	var report: Dictionary = (
		gs.property_engine
		.apply_property_spatial_topology_mutation(
			actor,
			prop,
			node,
			mutation
		)
	)
	if not bool(
		report.get(
			"success",
			false
		)
	):
		report ["text"] = (
			"You do not have authority to %s that passage."
			% (
				"unbolt"
				if security_mode == "bolt" and releasing
				else "bolt"
				if security_mode == "bolt"
				else "unlock"
				if releasing
				else "lock"
			)
		)
		return report

	report ["security_mode"] = security_mode
	report ["edge_id"] = edge_id
	report ["node"] = node
	report ["graph_rebuild_performed"] = false
	return report
func _resolve_target(
	_actor: Person,
	_prop: Dictionary,
	node: Dictionary,
	payload: Dictionary,
	graph: Dictionary
) -> Dictionary:
	var floors: Array = _safe_array(
		graph.get(
			"floors",
			[]
		)
	)
	var entry_node_id: String = str(
		graph.get(
			"entry_node_id",
			""
		)
	).strip_edges()
	var active_floor: int = int(
		graph.get(
			"active_floor",
			node.get(
				"active_floor",
				0
			)
		)
	)
	var active_room: String = str(
		graph.get(
			"active_room",
			node.get(
				"active_room",
				entry_node_id
			)
		)
	).strip_edges()

	if active_room == "":
		active_room = entry_node_id

	var action_id: String = _payload_action_id(payload)

	if action_id == "navigate_floor":
		var direction: String = str(payload.get("direction", "")).strip_edges().to_lower()
		var target_floor: int = _adjacent_floor_index(floors, active_floor, direction)
		if target_floor == active_floor:
			return {
				"resolved": false,
				"narrative": "There is no %s route from here." % direction
			}

		var landing_room: Dictionary = _landing_room_for_floor(floors, target_floor, direction)
		if landing_room.is_empty():
			return {
				"resolved": false,
				"narrative": "That floor exists, but there is nowhere safe to land."
			}

		return {
			"resolved": true,
			"type": "direction",
			"direction": direction,
			"floor": target_floor,
			"room": str(landing_room.get("room_id", active_room)),
			"fixture_id": ""
		}

	if action_id == "move_room" or action_id == "move_to_room":
		var requested_room: String = str(payload.get("room_id", payload.get("target_room_id", ""))).strip_edges()
		if requested_room == "":
			return {
				"resolved": false,
				"narrative": "No destination room was provided."
			}

		var room_contract: Dictionary = _room_by_id(floors, requested_room)
		if room_contract.is_empty():
			return {
				"resolved": false,
				"narrative": "That room is not part of this property."
			}

		return {
			"resolved": true,
			"type": "room",
			"floor": int(room_contract.get("floor_index", active_floor)),
			"room": requested_room,
			"fixture_id": ""
		}

	if action_id == "use_fixture":
		var fixture_id: String = str(payload.get("fixture_id", "")).strip_edges()
		var current_room: Dictionary = _room_by_id(floors, active_room)
		var fixture: Dictionary = _fixture_by_id(current_room, fixture_id)
		if fixture.is_empty():
			return {
				"resolved": false,
				"narrative": "That object is not within reach from here."
			}

		return {
			"resolved": true,
			"type": "object",
			"floor": active_floor,
			"room": active_room,
			"fixture_id": fixture_id
		}

	if action_id == "inspect_room":
		return {
			"resolved": true,
			"type": "observation",
			"floor": active_floor,
			"room": active_room,
			"fixture_id": ""
		}

	if action_id == "view_household":
		return {
			"resolved": true,
			"type": "social_context",
			"floor": active_floor,
			"room": active_room,
			"fixture_id": ""
		}

	return {
		"resolved": true,
		"type": "ambient_property_action",
		"floor": active_floor,
		"room": active_room,
		"fixture_id": ""
	}


func _check_physical_path(
	actor: Person,
	prop: Dictionary,
	graph: Dictionary,
	active_floor: int,
	active_room: String,
	target_floor: int,
	target_room: String,
	action_id: String,
	payload: Dictionary
) -> Dictionary:
	if action_id in [
		"inspect_room",
		"use_fixture",
		"view_household"
	]:
		return {
			"allowed": true,
			"constraints": []
		}

	if (
		active_room == target_room
		and active_floor == target_floor
	):
		return {
			"allowed": true,
			"constraints": []
		}

	var edge_id: String = str(
		payload.get(
			"edge_id",
			""
		)
	).strip_edges()
	var adjacent: Dictionary = _adjacent_contract_for_target(
		graph,
		active_room,
		target_room,
		edge_id
	)
	if adjacent.is_empty():
		return {
			"allowed": false,
			"reason": "rooms_not_adjacent",
			"narrative": (
				"That room is not directly reachable from where you are."
			),
			"constraints": [
				"current_room_edge_required"
			]
		}

	if _adjacent_contract_is_structurally_blocked(
		adjacent
	):
		return {
			"allowed": false,
			"reason": "structurally_blocked_edge",
			"narrative": str(
				adjacent.get(
					"blocked_text",
					"The passage is structurally blocked."
				)
			),
			"constraints": [
				"intact_edge_required"
			]
		}

	if _adjacent_contract_is_secured(
		adjacent
	):
		var security_mode: String = str(
			adjacent.get(
				"security_mode",
				_property_security_mode(
					prop,
					{}
				)
			)
		)
		return {
			"allowed": false,
			"reason": "secured_edge",
			"narrative": (
				"You must unbolt this passage before entering."
				if security_mode == "bolt"
				else "You must unlock this door before entering."
			),
			"constraints": [
				"secured_edge_must_be_released"
			],
			"edge_id": str(
				adjacent.get(
					"edge_id",
					edge_id
				)
			),
			"release_action_id": (
				"unbolt_spatial_edge"
				if security_mode == "bolt"
				else "unlock_spatial_edge"
			)
		}

	var topology_raw: Variant = graph.get(
		"spatial_topology",
		{}
	)
	if typeof(topology_raw) != TYPE_DICTIONARY:
		return {
			"allowed": false,
			"reason": "missing_spatial_topology",
			"narrative": (
				"The property has not published a spatial topology yet."
			),
			"constraints": [
				"spatial_topology_required"
			]
		}
	var topology: Dictionary = (
		topology_raw as Dictionary
	)
	if topology.is_empty():
		return {
			"allowed": false,
			"reason": "missing_spatial_topology",
			"narrative": (
				"The property has not published a spatial topology yet."
			),
			"constraints": [
				"spatial_topology_required"
			]
		}

	if (
		gs == null
		or gs.room_graph_contract_engine == null
		or not gs.room_graph_contract_engine.has_method(
			"resolve_edge_traversal_contract"
		)
	):
		return {
			"allowed": false,
			"reason": "missing_edge_resolver",
			"narrative": (
				"No structure authority is available to verify that route."
			),
			"constraints": [
				"room_graph_edge_resolver_required"
			]
		}

	var structure_report: Dictionary = (
		gs.room_graph_contract_engine
		.resolve_edge_traversal_contract(
			actor,
			prop,
			topology,
			active_room,
			target_room
		)
	)



	return structure_report
func _check_authority(actor: Person, prop: Dictionary, target_room: Dictionary, target_floor: int, target_room_id: String, _payload: Dictionary) -> Dictionary:
	var constraints: Array = []
	var access_level: String = str(target_room.get("access_level", "")).strip_edges().to_lower()

	if access_level == "":
		access_level = _floor_access_level(prop, target_floor)

	if access_level == "":
		access_level = "household"

	var tokens: Array = _actor_authority_tokens(actor, prop)

	if access_level in ["public", "public_staff", "household", "household_private", "household_hidden"]:
		return {
			"allowed": true,
			"constraints": constraints
		}

	if access_level in ["private_family", "elite_private"]:
		if tokens.has("resident") or tokens.has("family") or tokens.has("owner") or tokens.has("president") or tokens.has("first_lady"):
			return {
				"allowed": true,
				"constraints": constraints
			}

		return {
			"allowed": false,
			"reason": "private_family_access_denied",
			"narrative": "That part of the residence is private. You do not have access right now.",
			"constraints": ["private_family_access"]
		}

	if access_level == "restricted":
		if tokens.has("president") or tokens.has("first_lady") or tokens.has("security") or tokens.has("senior_staff") or tokens.has("resident"):
			return {
				"allowed": true,
				"constraints": ["restricted_area_authorized"]
			}

		return {
			"allowed": false,
			"reason": "restricted_access_denied",
			"narrative": "A guard blocks your path. You need clearance to enter %s." % target_room_id.replace("_", " "),
			"constraints": ["restricted_clearance_required"]
		}

	if access_level == "ultra_restricted":
		if tokens.has("president") or tokens.has("security"):
			return {
				"allowed": true,
				"constraints": ["ultra_restricted_authorized"]
			}

		return {
			"allowed": false,
			"reason": "ultra_restricted_access_denied",
			"narrative": "Secret Service blocks the way. You need executive or security clearance to enter.",
			"constraints": ["ultra_restricted_clearance_required"]
		}

	return {
		"allowed": true,
		"constraints": constraints
	}


func _movement_narrative(
	action_id: String,
	payload: Dictionary,
	current_room: Dictionary,
	target_room: Dictionary,
	target_fixture: String,
	authority_report: Dictionary
) -> String:
	var target_title: String = str(
		target_room.get(
			"title",
			target_room.get(
				"name",
				target_room.get(
					"room_id",
					"room"
				)
			)
		)
	)
	var current_title: String = str(
		current_room.get(
			"title",
			current_room.get(
				"name",
				current_room.get(
					"room_id",
					"room"
				)
			)
		)
	)
	var access_notes: Array = _safe_array(
		authority_report.get(
			"constraints",
			[]
		)
	)

	if action_id == "navigate_floor":
		var direction: String = str(
			payload.get(
				"direction",
				""
			)
		).strip_edges().to_lower()
		if direction == "up":
			return (
				"You head upstairs. The %s opens up in front of you."
				% target_title
			)
		if direction == "down":
			return (
				"You head downstairs. The %s settles around you."
				% target_title
			)
		return (
			"You change floors and arrive near the %s."
			% target_title
		)

	if (
		action_id == "move_room"
		or action_id == "move_to_room"
	):
		return (
			"You leave the %s and walk into the %s."
			% [
				current_title,
				target_title
			]
		)

	if action_id == "inspect_room":
		return (
			"You inspect the %s and take in what is around you."
			% target_title
		)

	if action_id == "use_fixture":
		var fixture_kind: String = str(
			payload.get(
				"fixture_kind",
				""
			)
		).strip_edges().to_lower()

		if fixture_kind == "arcade_machine":
			return (
				"You inspect the arcade cabinet in the %s. "
				+ "It is ready to use."
			) % target_title

		if target_fixture == "kitchen_fridge":
			return (
				"You walk to the fridge and check the food stored inside the home."
			)
		if target_fixture == "household_storage":
			return (
				"You open household storage. Anything placed here stays "
				+ "with the property until carried again."
			)
		if target_fixture == "attic_heirloom_cache":
			return (
				"You search through old attic boxes, looking for rare "
				+ "artifacts, records, or heirlooms."
			)
		return (
			"You move closer and use %s in the %s."
			% [
				target_fixture.replace(
					"_",
					" "
				),
				target_title
			]
		)

	if action_id == "view_household":
		return (
			"You pause inside the %s and listen for signs of the household nearby."
			% target_title
		)

	if not access_notes.is_empty():
		return (
			"You move through the %s under authorized access."
			% target_title
		)

	return "You move through the property."

func _write_actor_location(node: Dictionary, actor: Person, prop: Dictionary, floor_index: int, room_id: String, fixture_id: String = "") -> void:
	if actor == null:
		return

	var actor_locations: Dictionary = _safe_dictionary(node.get("actor_locations", {}))
	actor_locations [str(int(actor.id))] = {
		"actor_id": int(actor.id),
		"property_id": int(prop.get("id", prop.get("property_id", -1))),
		"floor": floor_index,
		"room": room_id,
		"fixture_id": fixture_id,
		"updated_year": int(gs.year if gs != null else 0),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"authority": ENGINE_SCHEMA
	}
	node ["actor_locations"] = actor_locations


func _presence_delta(
	actor: Person,
	prop: Dictionary,
	old_graph: Dictionary,
	new_graph: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.presence_engine == null
	):
		return {
			"entered": [],
			"left": [],
			"new_presence_contract": {},
			"presence_resolution_count": 0
		}




	var new_presence: Dictionary = (
		gs.presence_engine
		.emit_property_presence_contract(
			actor,
			prop,
			new_graph
		)
	)
	var old_room: String = str(
		old_graph.get(
			"active_room",
			""
		)
	)
	var new_room: String = str(
		new_graph.get(
			"active_room",
			""
		)
	)

	return {
		"entered": _occupant_names_in_room(
			new_presence,
			new_room
		),
		"left": _occupant_names_in_room(
			new_presence,
			old_room
		),
		"new_presence_contract": new_presence,
		"presence_resolution_count": 1,
	}
func project_resident_property_graph_cursor(
	actor: Person,
	prop: Dictionary,
	node: Dictionary,
	source_graph: Dictionary = {}
) -> Dictionary:
	if (
		gs != null
		and gs.room_graph_contract_engine != null
		and gs.room_graph_contract_engine.has_method(
			"project_resident_room_contract"
		)
	):
		var resident_projection: Dictionary = (
			gs.room_graph_contract_engine
			.project_resident_room_contract(
				actor,
				prop,
				node
			)
		)
		if not resident_projection.is_empty():
			resident_projection [
				"spatial_traversal_projection_authority"
			] = ENGINE_SCHEMA
			resident_projection [
				"graph_rebuild_performed"
			] = false
			return resident_projection



	var topology_raw: Variant = node.get(
		"spatial_topology",
		source_graph.get(
			"spatial_topology",
			{}
		)
	)
	var floors_raw: Variant = node.get(
		"floors",
		source_graph.get(
			"floors",
			[]
		)
	)

	var topology: Dictionary = (
		topology_raw as Dictionary
		if typeof(topology_raw) == TYPE_DICTIONARY
		else {}
	)
	var floors: Array = (
		floors_raw as Array
		if typeof(floors_raw) == TYPE_ARRAY
		else []
	)

	return {
		"success": false,
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
		"active_floor": int(
			node.get(
				"active_floor",
				0
			)
		),
		"active_room": str(
			node.get(
				"active_room",
				""
			)
		),
		"current_room": {},
		"navigation_actions": [],
		"room_navigation_actions": [],
		"movement_options": [],
		"spatial_movement_actions": [],
		"room_interaction_actions": [],
		"surroundings": [],
		"cursor_revision": int(
			node.get(
				"cursor_revision",
				0
			)
		),
		"resident_graph_hot": false,
		"reason": (
			"resident_room_graph_projection_unavailable"
		),
		"graph_rebuild_performed": false,
		"ui_is_renderer_only": true
	}
func _navigation_actions_for_current_room(
	prop: Dictionary,
	node: Dictionary,
	source_graph: Dictionary,
	current_room: Dictionary,
	active_floor: int,
	active_room: String
) -> Array:
	var out: Array = []
	var adjacent_raw: Variant = current_room.get(
		"adjacent_nodes",
		[]
	)

	if typeof(adjacent_raw) == TYPE_ARRAY:
		for raw_adjacent in adjacent_raw as Array:
			if typeof(raw_adjacent) != TYPE_DICTIONARY:
				continue

			var adjacent: Dictionary = (
				raw_adjacent as Dictionary
			)
			var target_room: String = str(
				adjacent.get(
					"node_id",
					adjacent.get(
						"room_id",
						adjacent.get(
							"target_room_id",
							""
						)
					)
				)
			).strip_edges()
			if target_room == "":
				continue

			var edge_id: String = str(
				adjacent.get(
					"edge_id",
					adjacent.get(
						"connection_id",
						""
					)
				)
			).strip_edges()
			var target_floor: int = int(
				adjacent.get(
					"floor_index",
					adjacent.get(
						"target_floor",
						active_floor
					)
				)
			)
			var target_title: String = str(
				adjacent.get(
					"title",
					target_room.replace(
						"_",
						" "
					).capitalize()
				)
			)
			var security_mode: String = str(
				adjacent.get(
					"security_mode",
					_property_security_mode(
						prop,
						node
					)
				)
			)
			var secured: bool = (
				_adjacent_contract_is_secured(
					adjacent
				)
			)
			var blocked: bool = (
				_adjacent_contract_is_structurally_blocked(
					adjacent
				)
			)

			if blocked:
				continue

			if secured:
				out.append({
					"action_id": (
						"unbolt_spatial_edge"
						if security_mode == "bolt"
						else "unlock_spatial_edge"
					),
					"label": (
						"Unbolt passage to %s"
						% target_title
						if security_mode == "bolt"
						else "Unlock door to %s"
						% target_title
					),
					"from_room_id": active_room,
					"room_id": target_room,
					"target_room_id": target_room,
					"active_floor": active_floor,
					"target_floor": target_floor,
					"edge_id": edge_id,
					"security_mode": security_mode,
					"secured_edge": true
				})
				continue

			out.append({
				"action_id": "move_to_room",
				"label": "Walk to %s" % target_title,
				"from_room_id": active_room,
				"room_id": target_room,
				"target_room_id": target_room,
				"active_floor": active_floor,
				"target_floor": target_floor,
				"edge_id": edge_id,
				"security_mode": security_mode,
				"secured_edge": false
			})

			if _adjacent_contract_is_securable(
				adjacent
			):
				out.append({
					"action_id": (
						"bolt_spatial_edge"
						if security_mode == "bolt"
						else "lock_spatial_edge"
					),
					"label": (
						"Bolt passage to %s"
						% target_title
						if security_mode == "bolt"
						else "Lock door to %s"
						% target_title
					),
					"from_room_id": active_room,
					"room_id": target_room,
					"target_room_id": target_room,
					"active_floor": active_floor,
					"target_floor": target_floor,
					"edge_id": edge_id,
					"security_mode": security_mode,
					"secured_edge": false
				})

	if not out.is_empty():
		return out



	for key in [
		"navigation_actions",
		"room_navigation_actions",
		"movement_options",
		"spatial_movement_actions"
	]:
		var actions_raw: Variant = source_graph.get(
			key,
			[]
		)
		if typeof(actions_raw) != TYPE_ARRAY:
			continue

		for raw_action in actions_raw as Array:
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = (
				raw_action as Dictionary
			)
			var from_room: String = str(
				action.get(
					"from_room_id",
					action.get(
						"source_room_id",
						""
					)
				)
			).strip_edges()
			if (
				from_room == ""
				or from_room != active_room
			):
				continue
			out.append(
				action
			)

		if not out.is_empty():
			break

	return out


func _interaction_actions_for_current_room(
	current_room: Dictionary,
	active_room: String
) -> Array:
	var out: Array = []
	if current_room.is_empty():
		return out

	var room_title: String = str(
		current_room.get(
			"title",
			current_room.get(
				"name",
				active_room.replace(
					"_",
					" "
				).capitalize()
			)
		)
	)
	out.append({
		"action_id": "inspect_room",
		"label": "Inspect %s" % room_title,
		"room_id": active_room
	})

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
			out.append({
				"action_id": "use_fixture",
				"label": str(
					fixture.get(
						"label",
						"Use %s" % str(
							fixture.get(
								"title",
								"Fixture"
							)
						)
					)
				),
				"room_id": active_room,
				"fixture_id": fixture_id,
				"fixture_kind": str(
					fixture.get(
						"kind",
						"fixture"
					)
				)
			})

	return out


func _surroundings_for_current_room(
	current_room: Dictionary
) -> Array:
	var out: Array = []

	var surroundings_raw: Variant = current_room.get(
		"surroundings",
		[]
	)
	if typeof(surroundings_raw) == TYPE_ARRAY:
		for raw_line in surroundings_raw as Array:
			out.append(
				str(raw_line)
			)

	if not out.is_empty():
		return out

	var adjacent_raw: Variant = current_room.get(
		"adjacent_nodes",
		[]
	)
	if typeof(adjacent_raw) == TYPE_ARRAY:
		for raw_adjacent in adjacent_raw as Array:
			if typeof(raw_adjacent) != TYPE_DICTIONARY:
				continue
			var adjacent: Dictionary = (
				raw_adjacent as Dictionary
			)
			var title: String = str(
				adjacent.get(
					"title",
					adjacent.get(
						"node_id",
						"Nearby Space"
					).replace(
						"_",
						" "
					).capitalize()
				)
			)
			var state: String = str(
				adjacent.get(
					"state",
					"intact"
				)
			).strip_edges()
			out.append(
				"%s%s" % [
					title,
					(
						" — %s" % state.replace(
							"_",
							" "
						).capitalize()
						if state != "" and state != "intact"
						else ""
					)
				]
			)

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

	return out


func _adjacent_contract_for_target(
	graph: Dictionary,
	_active_room: String,
	target_room: String,
	edge_id: String = ""
) -> Dictionary:
	var current_room_raw: Variant = graph.get(
		"current_room",
		{}
	)
	if typeof(current_room_raw) != TYPE_DICTIONARY:
		return {}

	var current_room: Dictionary = (
		current_room_raw as Dictionary
	)
	var adjacent_raw: Variant = current_room.get(
		"adjacent_nodes",
		[]
	)
	if typeof(adjacent_raw) != TYPE_ARRAY:
		return {}

	for raw_adjacent in adjacent_raw as Array:
		if typeof(raw_adjacent) != TYPE_DICTIONARY:
			continue
		var adjacent: Dictionary = (
			raw_adjacent as Dictionary
		)
		var candidate_target: String = str(
			adjacent.get(
				"node_id",
				adjacent.get(
					"room_id",
					adjacent.get(
						"target_room_id",
						""
					)
				)
			)
		).strip_edges()
		var candidate_edge_id: String = str(
			adjacent.get(
				"edge_id",
				adjacent.get(
					"connection_id",
					""
				)
			)
		).strip_edges()

		if (
			edge_id != ""
			and candidate_edge_id == edge_id
		):
			return adjacent

		if (
			target_room != ""
			and candidate_target == target_room
		):
			return adjacent

	return {}


func _adjacent_contract_is_secured(
	adjacent: Dictionary
) -> bool:
	var state: String = str(
		adjacent.get(
			"state",
			adjacent.get(
				"security_state",
				""
			)
		)
	).strip_edges().to_lower()

	return (
		bool(
			adjacent.get(
				"locked",
				false
			)
		)
		or bool(
			adjacent.get(
				"is_locked",
				false
			)
		)
		or bool(
			adjacent.get(
				"secured",
				false
			)
		)
		or bool(
			adjacent.get(
				"bolted",
				false
			)
		)
		or state in [
			"locked",
			"secured",
			"bolted",
			"barred"
		]
	)


func _adjacent_contract_is_structurally_blocked(
	adjacent: Dictionary
) -> bool:
	var state: String = str(
		adjacent.get(
			"state",
			""
		)
	).strip_edges().to_lower()

	return (
		bool(
			adjacent.get(
				"blocked",
				false
			)
		)
		or state in [
			"destroyed",
			"collapsed",
			"unsafe",
			"removed",
			"sealed",
			"locked_off"
		]
	)


func _adjacent_contract_is_securable(
	adjacent: Dictionary
) -> bool:
	if _adjacent_contract_is_secured(
		adjacent
	):
		return true

	if (
		bool(
			adjacent.get(
				"lockable",
				false
			)
		)
		or bool(
			adjacent.get(
				"securable",
				false
			)
		)
		or bool(
			adjacent.get(
				"boltable",
				false
			)
		)
		or bool(
			adjacent.get(
				"is_door",
				false
			)
		)
	):
		return true

	var edge_kind: String = str(
		adjacent.get(
			"edge_kind",
			adjacent.get(
				"kind",
				adjacent.get(
					"type",
					""
				)
			)
		)
	).strip_edges().to_lower()

	return (
		edge_kind.find("door") != -1
		or edge_kind.find("gate") != -1
		or edge_kind.find("hatch") != -1
	)


func _property_security_mode(
	prop: Dictionary,
	node: Dictionary
) -> String:
	var identity: Dictionary = {}
	var identity_raw: Variant = node.get(
		"identity",
		{}
	)
	if typeof(identity_raw) == TYPE_DICTIONARY:
		identity = identity_raw as Dictionary

	var era_text: String = (
		"%s %s %s" % [
			str(
				identity.get(
					"era",
					""
				)
			),
			str(
				prop.get(
					"era",
					prop.get(
						"era_name",
						""
					)
				)
			),
			str(
				gs.era.name
				if gs != null and gs.era != null
				else ""
			)
		]
	).to_lower()

	if (
		era_text.find("ancient") != -1
		or era_text.find("prehistoric") != -1
	):
		return "bolt"

	return "lock"


func _surface_delta_from_resident_graph(
	actor: Person,
	prop: Dictionary,
	graph: Dictionary,
	status_text: String,
	presentation_cue: String,
	presence_delta: Dictionary
) -> Dictionary:
	var presence: Dictionary = {}
	var presence_raw: Variant = presence_delta.get(
		"new_presence_contract",
		{}
	)
	if typeof(presence_raw) == TYPE_DICTIONARY:
		presence = presence_raw as Dictionary

	var delta: Dictionary = {
		"schema": (
			"eralife.property_space.surface_delta_contract"
		),
		"version": CONTRACT_VERSION,
		"actor_id": int(
			actor.id
			if actor != null
			else -1
		),
		"property_id": int(
			prop.get(
				"id",
				-1
			)
		),
		"active_floor": int(
			graph.get(
				"active_floor",
				0
			)
		),
		"active_room": str(
			graph.get(
				"active_room",
				""
			)
		),
		"current_room": graph.get(
			"current_room",
			{}
		),
		"navigation_actions": graph.get(
			"navigation_actions",
			[]
		),
		"room_navigation_actions": graph.get(
			"room_navigation_actions",
			[]
		),
		"movement_options": graph.get(
			"movement_options",
			[]
		),
		"spatial_movement_actions": graph.get(
			"spatial_movement_actions",
			[]
		),
		"room_interaction_actions": graph.get(
			"room_interaction_actions",
			[]
		),
		"spatial_description": str(
			graph.get(
				"spatial_description",
				""
			)
		),
		"surroundings": graph.get(
			"surroundings",
			[]
		),
		"status_text": status_text,
		"presentation_cue": presentation_cue,
		"cursor_revision": int(
			graph.get(
				"cursor_revision",
				0
			)
		),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}

	if not presence.is_empty():
		delta ["occupants"] = presence.get(
			"occupants",
			[]
		)
		delta ["presence_summary"] = str(
			presence.get(
				"summary",
				"No one else is in this room right now."
			)
		)

	return delta

func _occupant_names_in_room(presence: Dictionary, room_id: String) -> Array:
	var names: Array = []
	for raw_occupant in _safe_array(presence.get("occupants", [])):
		var occupant: Dictionary = _safe_dictionary(raw_occupant)
		if str(occupant.get("room_id", "")) != room_id:
			continue
		if str(occupant.get("presence_label", "")) == "You are here.":
			continue
		names.append(str(occupant.get("name", "Someone")))
	return names


func _graph_for(
	actor: Person,
	prop: Dictionary,
	node: Dictionary
) -> Dictionary:
	if (
		gs != null
		and gs.property_engine != null
		and gs.property_engine.has_method(
			"resolve_property_spatial_topology_contract"
		)
	):
		return gs.property_engine.resolve_property_spatial_topology_contract(
			actor,
			prop,
			node,
			{
				"source": ENGINE_SCHEMA,
				"view_contract_only": true,
				"ui_is_renderer_only": true
			}
		)

	if (
		gs != null
		and gs.room_graph_contract_engine != null
	):
		return (
			gs.room_graph_contract_engine
			.emit_room_graph_contract(
				actor,
				prop,
				node
			)
		)

	return {
		"floors": [],
		"entry_node_id": "",
		"spatial_topology": {},
		"active_floor": int(
			node.get("active_floor", 0)
		),
		"active_room": str(
			node.get("active_room", "")
		),
		"current_room": {},
		"navigation_actions": [],
		"room_interaction_actions": [],
		"actor_locations": _safe_dictionary(
			node.get("actor_locations", {})
		),
		"truth_state": "observable_partial",
		"ui_is_renderer_only": true
	}

func _property_context(
	actor: Person,
	property_id: int,
	property_owner_id: int = -1
) -> Dictionary:
	if (
		gs == null
		or gs.property_makeover_contract_engine == null
	):
		return {
			"success": false,
			"reason": (
				"missing_property_makeover_contract_engine"
			),
			"text": (
				"Property traversal cannot resolve without the property contract engine."
			)
		}

	if gs.property_makeover_contract_engine.has_method(
		"resolve_property_space_traversal_context"
	):
		return (
			gs.property_makeover_contract_engine
			.resolve_property_space_traversal_context(
				actor,
				property_id,
				property_owner_id
			)
		)

	return {
		"success": false,
		"reason": "missing_traversal_context_method",
		"text": (
			"Property traversal context is not available yet."
		)
	}

func _commit_property_node(actor: Person, prop: Dictionary, node: Dictionary) -> void:
	if gs == null or gs.property_makeover_contract_engine == null:
		return
	if gs.property_makeover_contract_engine.has_method("commit_property_space_traversal_node"):
		gs.property_makeover_contract_engine.commit_property_space_traversal_node(actor, prop, node)


func _emit_surface(
	actor: Person,
	property_id: int,
	property_owner_id: int = -1,
	status_text: String = ""
) -> Dictionary:
	if (
		gs == null
		or gs.property_makeover_contract_engine == null
	):
		return {}

	return (
		gs.property_makeover_contract_engine
		.emit_property_space_contract(
			actor,
			{
				"actor_id": (
					int(actor.id)
					if actor != null
					else -1
				),
				"property_id": property_id,
				"property_owner_id": property_owner_id,
				"status_text": status_text,
				"source": ENGINE_SCHEMA,
				"ui_is_renderer_only": true
			}
		)
	)

func _emit_diary(actor: Person, text: String) -> void:
	if gs == null or gs.property_makeover_contract_engine == null:
		return
	if gs.property_makeover_contract_engine.has_method("emit_property_space_traversal_diary"):
		gs.property_makeover_contract_engine.emit_property_space_traversal_diary(actor, text)


func _payload_action_id(payload: Dictionary) -> String:
	return str(payload.get("action_id", payload.get("market_action", payload.get("makeover_action", "")))).strip_edges()


func _adjacent_floor_index(floors: Array, active_floor: int, direction: String) -> int:
	var indices: Array = []
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if floor_contract.is_empty():
			continue
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


func _landing_room_for_floor(floors: Array, floor_index: int, direction: String = "") -> Dictionary:
	var rooms: Array = _rooms_on_floor(floors, floor_index)
	if rooms.is_empty():
		return {}

	for raw_room in rooms:
		var room: Dictionary = _safe_dictionary(raw_room)
		var room_id: String = str(room.get("room_id", "")).to_lower()
		if direction == "up" and (room_id.find("hall") != -1 or room_id.find("landing") != -1):
			return room
		if direction == "down" and (room_id.find("living") != -1 or room_id.find("entry") != -1):
			return room

	return _safe_dictionary(rooms [0])


func _rooms_on_floor(floors: Array, floor_index: int) -> Array:
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if floor_contract.is_empty():
			continue
		if int(floor_contract.get("floor_index", -999999)) == floor_index:
			return _safe_array(floor_contract.get("rooms", []))
	return []


func _room_by_id(floors: Array, room_id: String) -> Dictionary:
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		for raw_room in _safe_array(floor_contract.get("rooms", [])):
			var room: Dictionary = _safe_dictionary(raw_room)
			if str(room.get("room_id", "")) == room_id:
				return room
	return {}


func _fixture_by_id(room: Dictionary, fixture_id: String) -> Dictionary:
	if fixture_id == "":
		return {}
	for raw_fixture in _safe_array(room.get("fixtures", [])):
		var fixture: Dictionary = _safe_dictionary(raw_fixture)
		if str(fixture.get("fixture_id", "")) == fixture_id:
			return fixture
	return {}


func _floor_access_level(prop: Dictionary, floor_index: int) -> String:
	var node: Dictionary = _safe_dictionary(prop.get("property_reality_node", {}))
	for raw_floor in _safe_array(node.get("floors", [])):
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if int(floor_contract.get("floor_index", -999999)) == floor_index:
			return str(floor_contract.get("access_level", ""))
	return ""


func _actor_authority_tokens(actor: Person, prop: Dictionary) -> Array:
	var tokens: Array = []
	if actor == null:
		return tokens

	var actor_id: int = int(actor.id)
	var owner_id: int = int(prop.get("owner_id", prop.get("owned_by", -1)))
	if owner_id == actor_id:
		tokens.append("owner")

	var access_contract: Dictionary = _safe_dictionary(prop.get("access_contract", {}))
	if int(access_contract.get("granted_to", -1)) == actor_id:
		tokens.append("resident")

	if int(access_contract.get("legal_office_holder_id", -1)) == actor_id:
		tokens.append("president")

	var access_type: String = str(access_contract.get("type", "")).strip_edges().to_lower()
	if access_type == "executive_residency" and int(access_contract.get("granted_to", -1)) == actor_id:
		tokens.append("executive_resident")

	var actor_text: String = _actor_text_blob(actor)
	if actor_text.find("president") != -1:
		tokens.append("president")
	if actor_text.find("first lady") != -1 or actor_text.find("first_lady") != -1:
		tokens.append("first_lady")
	if actor_text.find("secret service") != -1 or actor_text.find("security") != -1:
		tokens.append("security")
	if actor_text.find("chief of staff") != -1 or actor_text.find("advisor") != -1 or actor_text.find("cabinet") != -1:
		tokens.append("senior_staff")
	if actor_text.find("family") != -1 or actor_text.find("child") != -1 or actor_text.find("spouse") != -1:
		tokens.append("family")

	return tokens


func _actor_text_blob(actor: Person) -> String:
	if actor == null:
		return ""

	var keys: Array = [
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
	]

	var parts: Array = []
	for raw_key in keys:
		var key: String = str(raw_key)
		var value: Variant = actor.get(key)
		if value == null:
			continue
		parts.append(str(value).to_lower())

	return " ".join(parts)


func _denied(reason: String, narrative: String, graph: Dictionary, node: Dictionary, payload: Dictionary) -> Dictionary:
	return {
		"success": false,
		"allowed": false,
		"reason": reason,
		"narrative": narrative,
		"old_location": {
			"floor": int(graph.get("active_floor", node.get("active_floor", 0))),
			"room": str(graph.get("active_room", node.get("active_room", "living_room")))
		},
		"new_location": {
			"floor": int(graph.get("active_floor", node.get("active_floor", 0))),
			"room": str(graph.get("active_room", node.get("active_room", "living_room")))
		},
		"payload": payload.duplicate(true),
		"constraints": [reason],
		"commit_authority": ENGINE_SCHEMA
	}


func _failure(reason: String, text: String) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"committed": false,
		"allowed": false,
		"reason": reason,
		"text": text,
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}

func _source_graph_from_payload(
	payload: Dictionary,
	property_id: int,
	node: Dictionary
) -> Dictionary:
	var source: Dictionary = _safe_dictionary(
		payload.get(
			"source_surface_projection",
			{}
		)
	)

	if source.is_empty():
		return {}

	if int(
		source.get(
			"property_id",
			-1
		)
	) != property_id:
		return {}

	var source_active_room: String = str(
		source.get(
			"active_room",
			""
		)
	).strip_edges()
	var authoritative_active_room: String = str(
		node.get(
			"active_room",
			""
		)
	).strip_edges()

	if (
		authoritative_active_room != ""
		and source_active_room != authoritative_active_room
	):
		return {}

	var spatial_topology: Dictionary = _safe_dictionary(
		source.get(
			"spatial_topology",
			{}
		)
	)
	var floors: Array = _safe_array(
		source.get(
			"floors",
			[]
		)
	)

	if (
		spatial_topology.is_empty()
		or floors.is_empty()
	):
		return {}

	return {
		"spatial_topology": spatial_topology,
		"entry_node_id": str(
			source.get(
				"entry_node_id",
				""
			)
		),
		"floors": floors,
		"active_floor": int(
			source.get(
				"active_floor",
				node.get(
					"active_floor",
					0
				)
			)
		),
		"active_room": source_active_room,
		"current_room": _safe_dictionary(
			source.get(
				"current_room",
				{}
			)
		),
		"navigation_actions": _safe_array(
			source.get(
				"navigation_actions",
				[]
			)
		),
		"room_navigation_actions": _safe_array(
			source.get(
				"room_navigation_actions",
				[]
			)
		),
		"room_interaction_actions": _safe_array(
			source.get(
				"room_interaction_actions",
				[]
			)
		),
		"actor_locations": _safe_dictionary(
			source.get(
				"actor_locations",
				{}
			)
		),
		"spatial_description": str(
			source.get(
				"spatial_description",
				""
			)
		),
		"surroundings": _safe_array(
			source.get(
				"surroundings",
				[]
			)
		),
		"ui_is_renderer_only": true
	}
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)