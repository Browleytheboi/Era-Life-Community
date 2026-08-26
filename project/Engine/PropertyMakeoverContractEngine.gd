extends Resource
class_name PropertyMakeoverContractEngine

const ENGINE_SCHEMA:= "eralife.property_makeover_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null



var authoritative_property_reality_node_by_id: Dictionary = {}
func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs


func emit_property_space_contract(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var property_id: int = int(
		payload.get(
			"property_id",
			-1
		)
	)
	var prop: Dictionary = _property_for_owner(
		actor,
		property_id
	)

	if prop.is_empty():
		return {
			"success": false,
			"reason": "missing_property",
			"schema": "eralife.property_space.surface_contract",
			"version": CONTRACT_VERSION,
			"mode": "interior",
			"title": "PROPERTY SPACE",
			"subtitle": (
				"No property could be resolved for this traversal surface."
			),
			"property_id": property_id,
			"status_text": (
				"No property was available for traversal."
			),
			"floors": [],
			"active_floor": 0,
			"active_room": "entryway",
			"current_room": {},
			"room_navigation_actions": [],
			"navigation_actions": [],
			"movement_options": [],
			"spatial_movement_actions": [],
			"room_interaction_actions": [],
			"household_context_available": false,
			"actions": [
				{
					"action_id": "leave_property",
					"label": "Leave Property"
				}
			],
			"truth_state": "missing_property_but_observable",
			"ui_is_renderer_only": true,
		}

	var node: Dictionary = _ensure_property_reality_node(
		prop,
		actor
	)
	var graph: Dictionary = {}

	if (
		gs != null
		and gs.room_graph_contract_engine != null
	):
		graph = (
			gs.room_graph_contract_engine
			.emit_room_graph_contract(
				actor,
				prop,
				node
			)
		)

	if (
		gs.property_engine != null
		and gs.property_engine.has_method(
			"apply_native_property_spatial_profile_contract"
		)
	):
		graph = (
			gs.property_engine
			.apply_native_property_spatial_profile_contract(
				prop,
				graph
			)
		)

	var presence: Dictionary = {}

	if gs != null and gs.presence_engine != null:
		presence = (
			gs.presence_engine
			.emit_property_presence_contract(
				actor,
				prop,
				graph
			)
		)

	var entry_state: Dictionary = _safe_dictionary(
		node.get(
			"entry_state",
			{}
		)
	)
	var resolved_status_text: String = str(
		payload.get(
			"status_text",
			""
		)
	).strip_edges()

	if resolved_status_text == "":
		resolved_status_text = str(
			entry_state.get(
				"entry_text",
				(
					"You enter through the front door and "
					+ "close it behind you."
				)
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

	var native_property_profile: String = str(
		graph.get(
			"native_property_profile",
			""
		)
	).strip_edges().to_lower()






	var household_context_available: bool = bool(
		graph.get(
			"household_context_available",
			native_property_profile != "arcade"
		)
	)

	var property_actions: Array = [
		{
			"action_id": "open_makeover",
			"label": "Open Property Makeover"
		}
	]

	if household_context_available:
		property_actions.append({
			"action_id": "view_household",
			"label": "View Household Members"
		})

	property_actions.append({
		"action_id": "leave_property",
		"label": "Leave Property"
	})

	var surface_contract: Dictionary = {
		"success": true,
		"schema": "eralife.property_space.surface_contract",
		"version": CONTRACT_VERSION,
		"mode": "interior",
		"title": _property_title(prop),
		"subtitle": resolved_status_text,
		"property_id": property_id,
		"bedrooms": int(
			node.get(
				"bedrooms",
				prop.get(
					"bedrooms",
					1
				)
			)
		),
		"bathrooms": int(
			node.get(
				"bathrooms",
				prop.get(
					"bathrooms",
					1
				)
			)
		),
		"identity": node.get(
			"identity",
			{}
		),
		"containers": node.get(
			"containers",
			{}
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
				0
			)
		),
		"active_room": str(
			graph.get(
				"active_room",
				"entryway"
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
		"status_text": resolved_status_text,
		"native_property_profile": native_property_profile,
		"household_context_available": (
			household_context_available
		),
		"actions": property_actions,
		"truth_state": "observable",
		"ui_is_renderer_only": true,
		"commit_authority": (
			"eralife.spatial_traversal_contract_engine"
		),
		"movement_authority": (
			"eralife.spatial_traversal_contract_engine"
		),
		"structure_authority": (
			"eralife.room_graph_contract_engine"
		),
		"presence_authority": "eralife.presence_engine"
	}

	if (
		gs != null
		and gs.mini_game_host_adapter_engine != null
		and gs.mini_game_host_adapter_engine.has_method(
			"enrich_property_space_contract"
		)
	):
		surface_contract = (
			gs.mini_game_host_adapter_engine
			.enrich_property_space_contract(
				actor,
				prop,
				node,
				surface_contract,
				payload
			)
		)

	return surface_contract

func emit_makeover_surface_contract(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var property_id: int = int(
		payload.get(
			"property_id",
			-1
		)
	)
	var property_owner_id: int = int(
		payload.get(
			"property_owner_id",
			-1
		)
	)
	var prop: Dictionary = _property_for_owner(
		actor,
		property_id,
		property_owner_id
	)
	if prop.is_empty():
		return {
			"success": false,
			"reason": "missing_property",
			"schema": "eralife.property_makeover.surface_contract",
			"version": CONTRACT_VERSION,
			"mode": "makeover",
			"title": "PROPERTY MAKEOVER",
			"subtitle": "No property could be resolved for this construction surface.",
			"property_id": property_id,
			"current_identity": {},
			"estimated_value": 0,
			"makeover_paths": [],
			"status_text": "No property was attached to this makeover request.",
			"truth_state": "missing_property_but_observable",
			"ui_is_renderer_only": true,
			"commit_authority": ENGINE_SCHEMA,
			"actor_id": (
				int(actor.id)
				if actor != null
				else -1
			),
			"property_owner_id": property_owner_id,
		}

	var node: Dictionary = _ensure_property_reality_node(prop, actor)
	var paths: Array = _makeover_paths_for_property(actor, prop, node)

	if paths.is_empty():
		var property_value: int = max(1, int(prop.get("value", prop.get("price", 10000))))
		var fallback_cost: int = max(500, int(float(property_value) * 0.05))
		var fallback_value_delta: int = max(250, int(float(property_value) * 0.03))

		paths.append(_spatial_path(
			"add_basic_room",
			"Add Basic Room",
			"Add a new observable room so this property never collapses into a flat menu.",
			fallback_cost,
			5,
			"low",
			{
				"kind": "add_room",
				"floor_index": 0,
				"room": {
					"room_id": "bonus_room",
					"title": "Bonus Room",
					"name": "Bonus Room",
					"floor_index": 0,
					"description": "A newly finished room waiting for household meaning.",
					"approach_label": "Walk into the bonus room",
					"fixtures": [],
					"connections": ["entryway", "living_room"]
				}
			},
			fallback_value_delta,
			2,
			"expanded"
		))

	return {
		"success": true,
		"schema": "eralife.property_makeover.surface_contract",
		"version": CONTRACT_VERSION,
		"mode": "makeover",
		"title": "PROPERTY MAKEOVER",
		"subtitle": _identity_summary(prop, node),
		"property_id": property_id,
		"bedrooms": int(node.get("bedrooms", prop.get("bedrooms", 1))),
		"bathrooms": int(node.get("bathrooms", prop.get("bathrooms", 1))),
		"current_identity": node.get("identity", {}),
		"estimated_value": int(prop.get("value", prop.get("price", 0))),
		"makeover_paths": paths,
		"status_text": str(payload.get("status_text", "")),
		"truth_state": "observable",
		"ui_is_renderer_only": true,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"property_owner_id": property_owner_id,
		"commit_authority": ENGINE_SCHEMA
	}
func commit_makeover_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var property_id: int = int(payload.get("property_id", -1))
	var path_id: String = str(payload.get("path_id", "")).strip_edges()
	var action_id: String = str(payload.get("makeover_action", payload.get("action_id", ""))).strip_edges()

	var prop: Dictionary = _property_for_owner(actor, property_id)
	if prop.is_empty():
		return { "success": false, "text": "That property could not be found."}

	var node: Dictionary = _ensure_property_reality_node(prop, actor)
	var selected_path: Dictionary = {}
	for raw_path in _makeover_paths_for_property(actor, prop, node):
		var path: Dictionary = _safe_dictionary(raw_path)
		if str(path.get("path_id", "")) == path_id:
			selected_path = path
			break

	if selected_path.is_empty():
		return _result(actor, property_id, false, "That makeover path is no longer available.")

	if action_id == "delay_project":
		return _result(actor, property_id, true, "You delayed the makeover project.")

	if action_id == "preview_makeover":
		return _result(actor, property_id, true, _makeover_preview_text(selected_path))

	if action_id not in ["proceed_makeover", "build_self", "hire_contractors"]:
		return _result(actor, property_id, false, "That makeover action is not available.")

	var cost: int = int(selected_path.get("cost", 0))
	if action_id == "build_self":
		cost = int(round(float(cost) * 1.35))
	if action_id == "hire_contractors":
		cost = int(round(float(cost) * 1.1))
	if int(actor.bank_balance) < cost:
		return _result(actor, property_id, false, "You need %s for this makeover." % _format_money(cost))

	actor.bank_balance -= cost
	_apply_makeover_to_property(prop, node, selected_path, actor)
	_replace_property_for_all_owners(prop)
	if action_id == "hire_contractors":
		var contractor_profile: Dictionary = _safe_dictionary(selected_path.get("contractor_profile", {}))
		var reputation: int = int(contractor_profile.get("reputation", 70))
		var botch_roll: int = abs(str("%s|%d|%d" % [path_id, int(actor.id), int(gs.year if gs != null else 0)]).hash()) % 100
		if botch_roll > reputation:
			prop ["condition"] = max(1.0, float(prop.get("condition", 100.0)) - 12.0)
			_replace_property_for_all_owners(prop)
			return _result(actor, property_id, false, "The contractors botched part of the job. Your property condition dropped and the project needs follow-up.")
	var diary_text: String = "I finally upgraded my %s with %s. This was much needed." % [
		str(prop.get("display_name", prop.get("type", "property"))).to_lower(),
		str(selected_path.get("title", "a makeover")).to_lower()
	]
	_emit_diary(actor, diary_text)

	return _result(actor, property_id, true, diary_text)


func _apply_makeover_to_property(
	prop: Dictionary,
	node: Dictionary,
	path: Dictionary,
	actor: Person
) -> void:
	var effects: Dictionary = _safe_dictionary(
		path.get("effects", {})
	)
	var identity: Dictionary = _safe_dictionary(
		node.get("identity", {})
	)
	identity ["style"] = str(
		effects.get(
			"identity_shift",
			identity.get("style", "basic")
		)
	)
	identity ["reputation"] = str(
		effects.get(
			"status_signal",
			identity.get(
				"reputation",
				"average"
			)
		)
	)
	identity ["last_updated_year"] = int(
		gs.year
	)
	node ["identity"] = identity

	var spatial_mutation: Dictionary = _safe_dictionary(
		effects.get("spatial_mutation", {})
	)

	if not spatial_mutation.is_empty():
		var mutation_report: Dictionary = _apply_spatial_mutation_to_node(
			node,
			spatial_mutation,
			prop,
			actor
		)

		if bool(
			mutation_report.get("success", false)
		):
			node = _safe_dictionary(
				mutation_report.get(
					"node",
					node
				)
			)
		else:
			node ["last_spatial_mutation_failure"] = (
				mutation_report.duplicate(true)
			)

	prop ["property_reality_node"] = node
	prop ["value"] = (
		int(
			prop.get(
				"value",
				prop.get("price", 0)
			)
		)
		+ int(
			effects.get(
				"property_value_delta",
				0
			)
		)
	)
	prop ["worth"] = int(
		prop ["value"]
	)
	prop ["condition"] = minf(
		100.0,
		float(
			prop.get(
				"condition",
				100.0
			)
		) + float(
			effects.get(
				"condition_delta",
				8.0
			)
		)
	)

	var passive: Dictionary = _safe_dictionary(
		prop.get("passive_modifiers", {})
	)
	passive ["comfort"] = (
		float(
			passive.get("comfort", 0.0)
		)
		+ float(
			effects.get(
				"comfort_delta",
				1.0
			)
		)
	)
	passive ["household_happiness"] = (
		float(
			passive.get(
				"household_happiness",
				0.0
			)
		)
		+ float(
			effects.get(
				"household_happiness_delta",
				0.0
			)
		)
	)
	prop ["passive_modifiers"] = passive

	var amenity_contract: Dictionary = _safe_dictionary(
		effects.get("amenity_contract", {})
	)

	if not amenity_contract.is_empty():
		var amenity_id: String = str(
			amenity_contract.get(
				"amenity_id",
				""
			)
		).strip_edges()
		var amenity_name: String = str(
			amenity_contract.get(
				"display_name",
				path.get(
					"title",
					"Amenity"
				)
			)
		)
		var amenity_contracts: Array = _safe_array(
			prop.get(
				"amenity_contracts",
				[]
			)
		)
		var amenity_ids: Array = _safe_array(
			prop.get("amenity_ids", [])
		)
		var amenities: Array = _safe_array(
			prop.get("amenities", [])
		)

		if (
			amenity_id != ""
			and not amenity_ids.has(amenity_id)
		):
			amenity_ids.append(amenity_id)
			amenity_contracts.append(
				amenity_contract.duplicate(true)
			)

		if (
			amenity_name != ""
			and not amenities.has(
				amenity_name
			)
		):
			amenities.append(amenity_name)

		prop ["amenity_contracts"] = amenity_contracts
		prop ["amenity_ids"] = amenity_ids
		prop ["amenities"] = amenities
		prop ["amenity_summary"] = " • ".join(
			amenities.slice(
				0,
				mini(5, amenities.size())
			)
		)
		prop ["vehicle_storage_capacity"] = maxi(
			0,
			int(
				prop.get(
					"vehicle_storage_capacity",
					0
				)
			)
			+ int(
				effects.get(
					"vehicle_storage_capacity_delta",
					amenity_contract.get(
						"vehicle_storage_capacity_delta",
						0
					)
				)
			)
		)

		var operational_profile: Dictionary = _safe_dictionary(
			prop.get(
				"operational_profile",
				{}
			)
		)
		operational_profile ["vehicle_storage_capacity"] = int(
			prop.get(
				"vehicle_storage_capacity",
				0
			)
		)
		prop ["operational_profile"] = operational_profile

	var history: Array = _safe_array(
		prop.get("history", [])
	)
	history.append(
		"%s %s upgraded %s with %s in %s." % [
			actor.first_name,
			actor.last_name,
			str(
				prop.get(
					"display_name",
					"the property"
				)
			),
			str(
				path.get(
					"title",
					"a makeover"
				)
			),
			str(gs.year)
		]
	)
	prop ["history"] = history
func _apply_spatial_mutation_to_node(
	node: Dictionary,
	mutation: Dictionary,
	prop: Dictionary = {},
	actor: Person = null
) -> Dictionary:
	if mutation.is_empty():
		return {
			"success": false,
			"reason": "missing_spatial_mutation",
			"node": node
		}

	if (
		gs != null
		and gs.property_engine != null
		and gs.property_engine.has_method(
			"apply_property_spatial_topology_mutation"
		)
		and not prop.is_empty()
	):
		return gs.property_engine.apply_property_spatial_topology_mutation(
			actor,
			prop,
			node,
			mutation
		)

	return {
		"success": false,
		"reason": "missing_topology_mutation_authority",
		"node": node,
		"ui_is_renderer_only": true
	}
func _floor_index_exists(floors: Array, floor_index: int) -> bool:
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if int(floor_contract.get("floor_index", 999999)) == floor_index:
			return true
	return false


func _room_id_exists(rooms: Array, room_id: String) -> bool:
	for raw_room in rooms:
		var room: Dictionary = _safe_dictionary(raw_room)
		if str(room.get("room_id", "")) == room_id:
			return true
	return false


func _fixture_id_exists(fixtures: Array, fixture_id: String) -> bool:
	for raw_fixture in fixtures:
		var fixture: Dictionary = _safe_dictionary(raw_fixture)
		if str(fixture.get("fixture_id", "")) == fixture_id:
			return true
	return false

func _ensure_property_reality_node(
	prop: Dictionary,
	actor: Person
) -> Dictionary:
	var property_id: int = int(
		prop.get(
			"id",
			-1
		)
	)
	var node: Dictionary = {}

	if (
		property_id > 0
		and authoritative_property_reality_node_by_id.has(
			property_id
		)
	):
		var canonical_raw: Variant = (
			authoritative_property_reality_node_by_id.get(
				property_id,
				{}
			)
		)
		if typeof(canonical_raw) == TYPE_DICTIONARY:
			node = canonical_raw as Dictionary

	if node.is_empty():
		var node_raw: Variant = prop.get(
			"property_reality_node",
			{}
		)
		if typeof(node_raw) == TYPE_DICTIONARY:
			node = node_raw as Dictionary

	var created_node: bool = node.is_empty()
	if created_node:
		node = {
			"schema": "eralife.property.reality_node",
			"version": CONTRACT_VERSION,
			"property_id": property_id,
			"identity": {
				"style": str(
					prop.get(
						"decor_style",
						"basic"
					)
				),
				"condition": str(
					prop.get(
						"condition_label",
						"maintained"
					)
				).to_lower(),
				"reputation": "average",
				"era": str(
					gs.era.name
					if gs != null and gs.era != null
					else ""
				)
			},
			"spatial_topology": {},
			"floors": [],
			"rooms": [],
			"containers": _default_property_containers(
				prop
			),
			"active_floor": 0,
			"active_room": "",
			"active_fixture": "",
			"actor_locations": {},
			"cursor_revision": 0,
			"entry_state": {
				"entered": true,
				"entry_method": "property_entry_contract",
				"entry_text": (
					"You enter the property and arrive at its current entry space."
				)
			},
			"cleanliness": 72,
			"wear": 18,
			"created_for_actor_id": (
				int(actor.id)
				if actor != null
				else -1
			),
			"created_year": int(
				gs.year
				if gs != null
				else 0
			)
		}

	node = _repair_property_reality_node(
		prop,
		node,
		actor
	)

	var topology_raw: Variant = node.get(
		"spatial_topology",
		{}
	)
	var floors_raw: Variant = node.get(
		"floors",
		[]
	)
	var topology_missing: bool = (
		typeof(topology_raw) != TYPE_DICTIONARY
		or (topology_raw as Dictionary).is_empty()
		or typeof(floors_raw) != TYPE_ARRAY
		or (floors_raw as Array).is_empty()
	)

	if topology_missing:


		node = _hydrate_property_topology(
			prop,
			node,
			actor
		)

	if property_id > 0:
		authoritative_property_reality_node_by_id [
			property_id
		] = node

	prop ["property_reality_node"] = node

	if (
		created_node
		or topology_missing
	):
		_replace_property_for_all_owners(
			prop
		)

	return node
func _repair_property_reality_node(
	prop: Dictionary,
	node: Dictionary,
	actor: Person
) -> Dictionary:
	if not node.has("schema"):
		node ["schema"] = "eralife.property.reality_node"

	if not node.has("version"):
		node ["version"] = CONTRACT_VERSION

	if not node.has("property_id"):
		node ["property_id"] = int(
			prop.get("id", -1)
		)

	if (
		not node.has("identity")
		or typeof(
			node.get("identity", {})
		) != TYPE_DICTIONARY
	):
		node ["identity"] = {
			"style": str(
				prop.get("decor_style", "basic")
			),
			"condition": str(
				prop.get(
					"condition_label",
					"maintained"
				)
			).to_lower(),
			"reputation": "average",
			"era": str(
				gs.era.name
				if gs != null and gs.era != null
				else ""
			)
		}

	if (
		not node.has("spatial_topology")
		or typeof(
			node.get("spatial_topology", {})
		) != TYPE_DICTIONARY
	):
		node ["spatial_topology"] = {}

	if (
		not node.has("floors")
		or typeof(node.get("floors", [])) != TYPE_ARRAY
	):
		node ["floors"] = []

	if (
		not node.has("rooms")
		or typeof(node.get("rooms", [])) != TYPE_ARRAY
	):
		node ["rooms"] = []

	if (
		not node.has("containers")
		or typeof(
			node.get("containers", {})
		) != TYPE_DICTIONARY
	):
		node ["containers"] = _default_property_containers(
			prop
		)

	if not node.has("created_for_actor_id"):
		node ["created_for_actor_id"] = (
			int(actor.id)
			if actor != null
			else -1
		)

	if not node.has("created_year"):
		node ["created_year"] = int(
			gs.year
			if gs != null
			else 0
		)

	if not node.has("active_floor"):
		node ["active_floor"] = 0

	if not node.has("active_room"):
		node ["active_room"] = ""

	if not node.has("active_fixture"):
		node ["active_fixture"] = ""

	if (
		not node.has("actor_locations")
		or typeof(
			node.get("actor_locations", {})
		) != TYPE_DICTIONARY
	):
		node ["actor_locations"] = {}

	return node


func _hydrate_property_topology(
	prop: Dictionary,
	node: Dictionary,
	actor: Person
) -> Dictionary:
	if gs == null:
		return node

	var graph: Dictionary = {}

	if (
		gs.property_engine != null
		and gs.property_engine.has_method(
			"resolve_property_spatial_topology_contract"
		)
	):
		graph = gs.property_engine.resolve_property_spatial_topology_contract(
			actor,
			prop,
			node,
			{
				"source": ENGINE_SCHEMA,
				"ui_is_renderer_only": true
			}
		)
	elif gs.room_graph_contract_engine != null:
		graph = (
			gs.room_graph_contract_engine
			.emit_room_graph_contract(
				actor,
				prop,
				node
			)
		)

	var resolved_node: Dictionary = _safe_dictionary(
		graph.get("reality_node", node)
	)

	if not resolved_node.is_empty():
		return resolved_node

	return node
func _default_rooms_for_property(
	prop: Dictionary
) -> Array:
	var node: Dictionary = _safe_dictionary(
		prop.get("property_reality_node", {})
	)
	var existing_rooms: Array = _safe_array(
		node.get("rooms", [])
	)

	if not existing_rooms.is_empty():
		return existing_rooms

	var flattened: Array = []

	for raw_floor in _safe_array(
		node.get("floors", [])
	):
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
				flattened.append(room)



	return flattened
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
func _default_property_containers(_prop: Dictionary) -> Dictionary:
	return {
		"kitchen_fridge": {
			"container_id": "kitchen_fridge",
			"title": "Fridge",
			"room_id": "kitchen",
			"kind": "food_storage",
			"accepts_tags": ["food", "drink", "ingredient", "meal"],
			"stored_items": [],
			"portable": false,
			"description": "Food stored here belongs to the property space and can be retrieved later."
		},
		"household_storage": {
			"container_id": "household_storage",
			"title": "Household Storage",
			"room_id": "storage_room",
			"kind": "belonging_storage",
			"accepts_tags": ["belonging", "tool", "clothing", "heirloom", "misc"],
			"stored_items": [],
			"portable": false,
			"description": "Items stored here cannot be used until the actor retrieves and carries them again."
		},
		"attic_heirloom_cache": {
			"container_id": "attic_heirloom_cache",
			"title": "Attic Heirloom Cache",
			"room_id": "attic",
			"kind": "artifact_cache",
			"stored_items": [],
			"portable": false,
			"description": "Rare artifacts, family records, heirlooms, and strange finds can emerge here through future discovery contracts."
		}
	}


func _makeover_paths_for_property(
	actor: Person,
	prop: Dictionary,
	node: Dictionary
) -> Array:
	var paths: Array = _era_structural_makeover_paths(
		prop,
		node
	)
	var synthesis_engine:= _property_amenity_synthesis_engine()

	if synthesis_engine != null:
		paths.append_array(
			synthesis_engine.makeover_path_contracts_for_property(
				actor,
				prop,
				{
					"source": ENGINE_SCHEMA,
					"property_id": int(
						prop.get("id", -1)
					),
					"resolved_price": int(
						prop.get(
							"value",
							prop.get("price", 0)
						)
					),
					"era_key": _makeover_era_key(),
					"view_contract_only": true,
					"ui_is_renderer_only": true
				}
			)
		)

	var seen_path_ids: Dictionary = {}
	var deduped: Array = []

	for raw_path in paths:
		var path: Dictionary = _safe_dictionary(
			raw_path
		)
		var path_id: String = str(
			path.get("path_id", "")
		).strip_edges()

		if (
			path_id == ""
			or seen_path_ids.has(path_id)
		):
			continue

		seen_path_ids [path_id] = true
		deduped.append(path)
	paths.append_array(
		_spatial_repair_paths_for_property(
			prop,
			node
		)
	)
	paths.append_array(
		_contract_room_expansion_paths(
			prop,
			node
		)
	)
	deduped.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("cost", 0)
		) < int(
			(right_raw as Dictionary).get("cost", 0)
		)
	)

	return deduped
func _spatial_repair_paths_for_property(
	prop: Dictionary,
	node: Dictionary
) -> Array:
	var out: Array = []
	var topology: Dictionary = _safe_dictionary(
		node.get("spatial_topology", {})
	)
	var nodes: Dictionary = _safe_dictionary(
		topology.get("nodes", {})
	)
	var property_value: int = maxi(
		1,
		int(
			prop.get(
				"value",
				prop.get("price", 1)
			)
		)
	)

	for raw_node_id in nodes.keys():
		var node_id: String = str(raw_node_id)
		var space: Dictionary = _safe_dictionary(
			nodes.get(node_id, {})
		)
		var state: String = str(
			space.get("state", "intact")
		).strip_edges().to_lower()

		if state not in [
			"damaged",
			"destroyed",
			"unsafe",
			"collapsed",
			"locked_off"
		]:
			continue

		var severe: bool = state in [
			"destroyed",
			"collapsed"
		]
		var cost: int = maxi(
			500,
			int(
				round(
					float(property_value)
					* (0.14 if severe else 0.07)
				)
			)
		)
		var title: String = str(
			space.get("title", "Damaged Space")
		)

		out.append(
			_spatial_path(
				"repair_space:%s" % node_id,
				"Repair %s" % title,
				"Restore the damaged spatial node and reopen its valid graph edges.",
				cost,
				21 if severe else 8,
				"high" if severe else "medium",
				{
					"kind": "repair_node",
					"node_id": node_id
				},
				int(
					round(float(cost) * 0.74)
				),
				6,
				"restored"
			)
		)

	return out


func _contract_room_expansion_paths(
	prop: Dictionary,
	node: Dictionary
) -> Array:
	var out: Array = []
	var topology: Dictionary = _safe_dictionary(
		node.get("spatial_topology", {})
	)
	var nodes: Dictionary = _safe_dictionary(
		topology.get("nodes", {})
	)

	if nodes.is_empty():
		return out

	var era_key: String = _makeover_era_key()
	var property_value: int = maxi(
		1,
		int(
			prop.get(
				"value",
				prop.get("price", 1)
			)
		)
	)
	var anchor_node_id: String = _topology_anchor_node_id(
		nodes,
		[
			"living_room",
			"atrium",
			"main_hall",
			"apartment_entrance",
			"living_area",
			"meditation_hall",
			str(
				topology.get(
					"entry_node_id",
					""
				)
			)
		]
	)

	if anchor_node_id == "":
		return out

	var candidates: Array = []

	match era_key:
		"ancient":
			candidates = [
				{
					"node_id": "household_workroom",
					"title": "Household Workroom",
					"icon": "🏺",
					"room_type": "workroom",
					"description": "A practical room supports craft, household production, and storage."
				},
				{
					"node_id": "storage_chamber",
					"title": "Storage Chamber",
					"icon": "🧺",
					"room_type": "storage",
					"description": "A dedicated chamber protects household goods and provisions."
				}
			]

		"medieval":
			candidates = [
				{
					"node_id": "pantry",
					"title": "Pantry",
					"icon": "🥖",
					"room_type": "pantry",
					"description": "A cool pantry expands food storage near the kitchen."
				},
				{
					"node_id": "workroom",
					"title": "Workroom",
					"icon": "⚒️",
					"room_type": "workroom",
					"description": "A protected workroom supports craft and repairs."
				}
			]

		"industrial":
			candidates = [
				{
					"node_id": "scullery",
					"title": "Scullery",
					"icon": "🧼",
					"room_type": "utility",
					"description": "A scullery separates washing and utility work from the main kitchen."
				},
				{
					"node_id": "mechanical_workshop",
					"title": "Mechanical Workshop",
					"icon": "⚙️",
					"room_type": "workshop",
					"description": "A workshop supports tools, repairs, and industrial craft."
				}
			]

		"future":
			candidates = [
				{
					"node_id": "adaptive_office_module",
					"title": "Adaptive Office Module",
					"icon": "🧠",
					"room_type": "office",
					"description": "A configurable module reshapes itself around focused work."
				},
				{
					"node_id": "autonomous_utility_pod",
					"title": "Autonomous Utility Pod",
					"icon": "🤖",
					"room_type": "utility",
					"description": "An autonomous pod handles laundry, cleaning, repair, and storage."
				}
			]

		_:
			candidates = [
				{
					"node_id": "home_office",
					"title": "Home Office",
					"icon": "💻",
					"room_type": "office",
					"description": "A dedicated office supports focused work and planning."
				},
				{
					"node_id": "laundry_room",
					"title": "Laundry Room",
					"icon": "🧺",
					"room_type": "utility",
					"description": "A dedicated utility room supports laundry and household maintenance."
				}
			]

	for raw_candidate in candidates:
		var candidate: Dictionary = _safe_dictionary(
			raw_candidate
		)
		var node_id: String = str(
			candidate.get("node_id", "")
		)

		if node_id == "" or nodes.has(node_id):
			continue

		var title: String = str(
			candidate.get("title", "New Room")
		)
		var cost: int = maxi(
			1200,
			int(
				round(
					float(property_value) * 0.065
				)
			)
		)

		out.append(
			_spatial_path(
				"add_room:%s" % node_id,
				"Add %s" % title,
				str(
					candidate.get(
						"description",
						"Add a persistent room to the property topology."
					)
				),
				cost,
				14,
				"high",
				{
					"kind": "add_node",
					"anchor_node_id": anchor_node_id,
					"movement_kind": "doorway",
					"lockable": true,
					"node": {
						"node_id": node_id,
						"room_id": node_id,
						"title": title,
						"icon": str(
							candidate.get(
								"icon",
								"🚪"
							)
						),
						"floor_index": int(
							_safe_dictionary(
								nodes.get(
									anchor_node_id,
									{}
								)
							).get(
								"floor_index",
								0
							)
						),
						"node_type": str(
							candidate.get(
								"room_type",
								"room"
							)
						),
						"room_type": str(
							candidate.get(
								"room_type",
								"room"
							)
						),
						"description": str(
							candidate.get(
								"description",
								""
							)
						),
						"access_level": "household",
						"state": "intact",
						"fixtures": []
					}
				},
				int(
					round(float(cost) * 0.78)
				),
				5,
				"expanded"
			)
		)

	return out


func _topology_anchor_node_id(
	nodes: Dictionary,
	candidates: Array
) -> String:
	for raw_candidate in candidates:
		var candidate: String = str(
			raw_candidate
		).strip_edges()

		if candidate != "" and nodes.has(candidate):
			return candidate

	for raw_node_id in nodes.keys():
		var node_id: String = str(raw_node_id)
		var space: Dictionary = _safe_dictionary(
			nodes.get(node_id, {})
		)

		if not bool(space.get("removed", false)):
			return node_id

	return ""
func _era_structural_makeover_paths(
	prop: Dictionary,
	node: Dictionary
) -> Array:
	var paths: Array = []
	var era_key: String = _makeover_era_key()
	var base_value: int = maxi(
		1,
		int(
			prop.get(
				"value",
				prop.get("price", 1)
			)
		)
	)
	var multiplier: float = maxf(
		0.75,
		float(
			prop.get(
				"makeover_cost_multiplier",
				1.0
			)
		)
	)

	match era_key:
		"ancient":
			paths.append(
				_path(
					"ancient_dwelling_restoration",
					"Ancient Dwelling Restoration",
					"Renew mudbrick, stone, timber, plaster, roofing, and era-valid surfaces.",
					int(
						float(base_value)
						* 0.16
						* multiplier
					),
					12,
					"medium",
					int(float(base_value) * 0.09),
					5,
					"ancient_restored"
				)
			)
			paths.append(
				_path(
					"ancient_food_space_upgrade",
					"Hearth & Food Storage Upgrade",
					"Improve the hearth, grain protection, preparation surfaces, and communal eating space.",
					int(
						float(base_value)
						* 0.09
						* multiplier
					),
					8,
					"medium",
					int(float(base_value) * 0.07),
					4,
					"ancient_functional"
				)
			)
			paths.append(
				_path(
					"ancient_guard_upgrade",
					"Boundary & Guard Upgrade",
					"Strengthen gates, boundary markers, watch points, and household protection.",
					int(
						float(base_value)
						* 0.1
						* multiplier
					),
					7,
					"medium",
					int(float(base_value) * 0.08),
					3,
					"ancient_secure"
				)
			)

		"medieval":
			paths.append(
				_path(
					"medieval_masonry_renewal",
					"Masonry & Timber Renewal",
					"Repair stonework, beams, shutters, roofing, and era-valid interior finishes.",
					int(
						float(base_value)
						* 0.16
						* multiplier
					),
					18,
					"high",
					int(float(base_value) * 0.12),
					7,
					"medieval_restored"
				)
			)
			paths.append(
				_path(
					"medieval_hearth_upgrade",
					"Great Hearth Upgrade",
					"Expand cooking, warmth, smoke control, food storage, and household gathering.",
					int(
						float(base_value)
						* 0.1
						* multiplier
					),
					10,
					"medium",
					int(float(base_value) * 0.08),
					6,
					"medieval_functional"
				)
			)
			paths.append(
				_path(
					"medieval_fortification_upgrade",
					"Fortification Upgrade",
					"Improve locks, shutters, walls, watch points, and defensive circulation.",
					int(
						float(base_value)
						* 0.14
						* multiplier
					),
					16,
					"high",
					int(float(base_value) * 0.11),
					4,
					"medieval_secure"
				)
			)

		"industrial":
			paths.append(
				_path(
					"industrial_renovation",
					"Industrial-Era Renovation",
					"Upgrade brickwork, flooring, ventilation, gas fixtures, and practical circulation.",
					int(
						float(base_value)
						* 0.2
						* multiplier
					),
					20,
					"high",
					int(float(base_value) * 0.15),
					9,
					"industrial_modernized"
				)
			)
			paths.append(
				_path(
					"industrial_kitchen_upgrade",
					"Range & Pantry Upgrade",
					"Improve the cooking range, pantry, food storage, water access, and family gathering.",
					int(
						float(base_value)
						* 0.1
						* multiplier
					),
					10,
					"medium",
					int(float(base_value) * 0.08),
					7,
					"industrial_functional"
				)
			)
			paths.append(
				_path(
					"industrial_security_upgrade",
					"Locks, Gates & Fire Safety",
					"Improve locks, gates, fire resistance, and industrial-era household safety.",
					int(
						float(base_value)
						* 0.08
						* multiplier
					),
					7,
					"low",
					int(float(base_value) * 0.06),
					3,
					"industrial_secure"
				)
			)

		"future":
			paths.append(
				_path(
					"future_habitat_reconfiguration",
					"Adaptive Habitat Reconfiguration",
					"Reconfigure responsive walls, environmental systems, smart surfaces, and spatial automation.",
					int(
						float(base_value)
						* 0.26
						* multiplier
					),
					16,
					"high",
					int(float(base_value) * 0.2),
					14,
					"future_adaptive"
				)
			)
			paths.append(
				_path(
					"future_nutrition_lab",
					"Autonomous Nutrition Lab",
					"Upgrade food synthesis, storage, diagnostics, and household nutrition systems.",
					int(
						float(base_value)
						* 0.12
						* multiplier
					),
					8,
					"medium",
					int(float(base_value) * 0.1),
					8,
					"future_functional"
				)
			)
			paths.append(
				_path(
					"future_security_matrix",
					"Predictive Security Matrix",
					"Install identity-aware access, perimeter sensing, and emergency isolation systems.",
					int(
						float(base_value)
						* 0.12
						* multiplier
					),
					9,
					"medium",
					int(float(base_value) * 0.09),
					5,
					"future_secure"
				)
			)

		_:
			paths.append(
				_path(
					"modern_renovation",
					"Modern Renovation",
					"Transform the interior with era-valid flooring, lighting, layout, and comfort.",
					int(
						float(base_value)
						* 0.24
						* multiplier
					),
					21,
					"high",
					int(float(base_value) * 0.18),
					12,
					"modern"
				)
			)
			paths.append(
				_path(
					"functional_kitchen",
					"Functional Kitchen Upgrade",
					"Improve cooking outcomes, food storage, nourishment, and household gathering.",
					int(
						float(base_value)
						* 0.1
						* multiplier
					),
					10,
					"medium",
					int(float(base_value) * 0.08),
					7,
					"functional"
				)
			)
			paths.append(
				_path(
					"security_upgrade",
					"Security Upgrade",
					"Lower crime pressure and make the property feel safer.",
					int(
						float(base_value)
						* 0.08
						* multiplier
					),
					6,
					"low",
					int(float(base_value) * 0.06),
					3,
					"secure"
				)
			)

	if _property_supports_added_floor(
		prop,
		era_key
	):
		paths.append(
			_spatial_path(
				"add_floor",
				"Add Another Floor",
				"Add a vertical layer only where the property form and historical construction support it.",
				int(
					float(base_value)
					* 0.22
					* multiplier
				),
				30,
				"high",
				{
					"kind": "add_floor",
					"floor": _new_custom_floor_node(
						node
					)
				},
				int(float(base_value) * 0.18),
				8,
				"expanded"
			)
		)

	return paths
func _property_supports_added_floor(
	prop: Dictionary,
	era_key: String
) -> bool:
	var subtype: String = str(
		prop.get("subtype", "")
	).to_lower()

	if subtype in [
		"shared_hut",
		"stone_dwelling",
		"micro_apartment",
		"mobile_home",
		"tiny_house",
		"cave_dwelling",
		"floating_house",
		"floating_estate"
	]:
		return false

	if era_key == "ancient":
		return subtype in [
			"noble_villa",
			"palace_wing",
			"temple_compound"
		]

	return true
func _amenity_room_path(prop: Dictionary, path_id: String, title: String, description: String, room_id: String, room_title: String, cost_rate: float, days: int, disruption: String, value_rate: float, identity_shift: String) -> Dictionary:
	var base_value: int = max(1, int(prop.get("value", prop.get("price", 10000))))
	var cost: int = int(float(base_value) * cost_rate * _renovation_cost_multiplier(prop))
	var value_delta: int = int(float(base_value) * value_rate)
	return _spatial_path(
		path_id,
		title,
		description,
		cost,
		days,
		disruption,
		{
			"kind": "add_room",
			"floor_index": 0,
			"room": {
				"room_id": room_id,
				"title": room_title,
				"name": room_title,
				"floor_index": 0,
				"description": description,
				"approach_label": "Walk to the %s" % room_title.to_lower(),
				"fixtures": [
					{
						"fixture_id": "%s_main" % room_id,
						"title": room_title,
						"kind": "amenity",
						"label": "Enjoy the %s" % room_title,
						"surface_text": "The %s is ready to be used, enjoyed, shown off, or folded into future life events." % room_title.to_lower()
					}
				]
			}
		},
		value_delta,
		6,
		identity_shift
	)


func _amenity_fixture_path(prop: Dictionary, path_id: String, title: String, description: String, room_id: String, fixture_id: String, fixture_title: String, fixture_kind: String, cost_rate: float, days: int, disruption: String, value_rate: float, identity_shift: String) -> Dictionary:
	var base_value: int = max(1, int(prop.get("value", prop.get("price", 10000))))
	var cost: int = int(float(base_value) * cost_rate * _renovation_cost_multiplier(prop))
	var value_delta: int = int(float(base_value) * value_rate)
	return _spatial_path(
		path_id,
		title,
		description,
		cost,
		days,
		disruption,
		{
			"kind": "add_fixture",
			"room_id": room_id,
			"fixture": {
				"fixture_id": fixture_id,
				"title": fixture_title,
				"kind": fixture_kind,
				"label": "Interact with %s" % fixture_title,
				"surface_text": "%s moves through the home as an observable household system." % fixture_title
			}
		},
		value_delta,
		4,
		identity_shift
	)


func _renovation_cost_multiplier(prop: Dictionary) -> float:
	var value: int = int(prop.get("value", prop.get("price", 0)))
	if value >= 1000000:
		return 2.0
	if value >= 500000:
		return 1.55
	if value >= 250000:
		return 1.25
	return 1.0


func _personal_cave_title(actor: Person) -> String:
	if actor != null and str(actor.gender).to_lower() == "female":
		return "Woman Cave"
	if actor != null and str(actor.gender).to_lower() == "male":
		return "Man Cave"
	return "Personal Cave"


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return ""


func _new_custom_floor_node(node: Dictionary) -> Dictionary:
	var floors: Array = _safe_array(node.get("floors", []))
	var highest_floor: int = 0
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		highest_floor = max(highest_floor, int(floor_contract.get("floor_index", 0)))

	var new_floor_index: int = highest_floor + 1
	return {
		"floor_index": new_floor_index,
		"label": "New Floor %d" % new_floor_index,
		"access_level": "household_private",
		"rooms": [
			{
				"room_id": "new_floor_hallway_%d" % new_floor_index,
				"title": "New Floor Hallway",
				"name": "New Floor Hallway",
				"floor_index": new_floor_index,
				"description": "A newly constructed hallway waiting for rooms, identity, and future blueprints.",
				"approach_label": "Go upstairs to the new floor",
				"fixtures": []
			}
		]
	}
func _spatial_path(path_id: String, title: String, description: String, cost: int, days: int, disruption: String, spatial_mutation: Dictionary, value_delta: int, happiness_delta: int, identity_shift: String) -> Dictionary:
	var projected_value: int = cost + value_delta
	return {
		"path_id": path_id,
		"title": title,
		"description": description,
		"cost": cost,
		"cost_text": _format_money(cost),
		"projected_value_delta": value_delta,
		"projected_value_delta_text": _format_money(value_delta),
		"projected_value_after_construction": projected_value,
		"projected_value_after_construction_text": _format_money(projected_value),
		"duration_days": days,
		"disruption_level": disruption,
		"contractor_profile": _contractor_profile_for_path(path_id, cost),
		"effects": {
			"property_value_delta": value_delta,
			"household_happiness_delta": happiness_delta,
			"identity_shift": identity_shift,
			"status_signal": "spatially_upgraded",
			"comfort_delta": max(1.0, float(happiness_delta) / 4.0),
			"spatial_mutation": spatial_mutation.duplicate(true)
		},
		"options": [
			{ "action_id": "preview_makeover", "label": "Review Impact"},
			{ "action_id": "build_self", "label": "Build It Yourself"},
			{ "action_id": "hire_contractors", "label": "Hire Contractors"},
			{ "action_id": "delay_project", "label": "Delay Project"}
		]
	}
func _contractor_profile_for_path(path_id: String, cost: int) -> Dictionary:
	var contractor_seed: int = abs(str("%s|%d|%d" % [path_id, cost, int(gs.year if gs != null else 0)]).hash())
	var reputation: int = 35 + (contractor_seed % 61)
	return {
		"contractor_id": "contractor_%s" % path_id,
		"name": "Local Contractor Crew",
		"reputation": reputation,
		"reputation_label": "Reliable" if reputation >= 75 else "Risky" if reputation < 50 else "Mixed",
		"botch_risk": max(5, 100 - reputation),
	}

func _path(path_id: String, title: String, description: String, cost: int, days: int, disruption: String, value_delta: int, happiness_delta: int, identity_shift: String) -> Dictionary:
	return {
		"path_id": path_id,
		"title": title,
		"description": description,
		"cost": cost,
		"cost_text": _format_money(cost),
		"duration_days": days,
		"disruption_level": disruption,
		"effects": {
			"property_value_delta": value_delta,
			"household_happiness_delta": happiness_delta,
			"identity_shift": identity_shift,
			"status_signal": "upgraded",
			"comfort_delta": max(1.0, float(happiness_delta) / 4.0)
		},
		"options": [
			{ "action_id": "proceed_makeover", "label": "Proceed With Renovation"},
			{ "action_id": "preview_makeover", "label": "Review Impact"},
			{ "action_id": "delay_project", "label": "Delay Project"}
		]
	}


func _room(room_id: String, title: String, description: String) -> Dictionary:
	return {
		"room_id": room_id,
		"title": title,
		"description": description,
		"cleanliness": 72,
		"wear": 18,
		"occupants": []
	}


func _actor_can_access_property_contract(
	actor: Person,
	prop: Dictionary,
	registry_owner_id: int
) -> bool:
	if actor == null or prop.is_empty():
		return false

	var actor_id: int = int(actor.id)
	var owner_id: int = int(
		prop.get(
			"owner_id",
			prop.get(
				"legal_owner_id",
				registry_owner_id
			)
		)
	)
	var legal_owner_id: int = int(
		prop.get(
			"legal_owner_id",
			owner_id
		)
	)
	var visible_actor_id: int = int(
		prop.get(
			"visible_actor_id",
			-1
		)
	)
	var access_contract: Dictionary = _safe_dictionary(
		prop.get(
			"access_contract",
			{}
		)
	)
	var granted_to: int = int(
		access_contract.get(
			"granted_to",
			-1
		)
	)

	if actor_id in [
		int(registry_owner_id),
		owner_id,
		legal_owner_id,
		visible_actor_id,
		granted_to
	]:
		return true

	for list_key in [
		"granted_actor_ids",
		"resident_ids",
		"household_member_ids",
		"authorized_actor_ids",
		"staff_actor_ids"
	]:
		for raw_actor_id in _safe_array(
			access_contract.get(
				list_key,
				prop.get(
					list_key,
					[]
				)
			)
		):
			if int(raw_actor_id) == actor_id:
				return true

	if (
		bool(
			prop.get(
				"government_owned",
				false
			)
		)
		and str(
			prop.get(
				"contract_id",
				""
			)
		) == "official_residence_white_house"
	):
		return _actor_has_white_house_access(
			actor,
			prop
		)

	return false


func _property_for_owner(
	actor: Person,
	property_id: int,
	property_owner_id: int = -1
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.property_engine == null
		or property_id <= 0
	):
		return {}

	if (
		property_owner_id > 0
		and gs.property_engine.properties.has(
			property_owner_id
		)
	):
		var explicit_rows_raw: Variant = (
			gs.property_engine.properties.get(
				property_owner_id,
				[]
			)
		)
		if typeof(explicit_rows_raw) == TYPE_ARRAY:
			for raw_prop in explicit_rows_raw as Array:
				if typeof(raw_prop) != TYPE_DICTIONARY:
					continue
				var explicit_prop: Dictionary = (
					raw_prop as Dictionary
				)
				if int(
					explicit_prop.get(
						"id",
						-1
					)
				) != property_id:
					continue
				if _actor_can_access_property_contract(
					actor,
					explicit_prop,
					property_owner_id
				):
					return explicit_prop
			return {}

	for raw_owner_id in (
		gs.property_engine.properties.keys()
	):
		var registry_owner_id: int = int(
			raw_owner_id
		)
		var rows_raw: Variant = (
			gs.property_engine.properties.get(
				raw_owner_id,
				[]
			)
		)
		if typeof(rows_raw) != TYPE_ARRAY:
			continue

		for raw_prop in rows_raw as Array:
			if typeof(raw_prop) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = (
				raw_prop as Dictionary
			)
			if int(
				prop.get(
					"id",
					-1
				)
			) != property_id:
				continue
			if _actor_can_access_property_contract(
				actor,
				prop,
				registry_owner_id
			):
				return prop

	return {}
func _actor_has_white_house_access(actor: Person, prop: Dictionary) -> bool:
	if actor == null:
		return false

	var actor_id: int = int(actor.id)
	if actor_id == int(prop.get("visible_actor_id", -1)):
		return true
	if actor_id == int(prop.get("legal_owner_id", -1)):
		return true
	if actor_id == int(prop.get("owner_id", -1)):
		return true

	var access_contract: Dictionary = _safe_dictionary(prop.get("access_contract", {}))
	if actor_id == int(access_contract.get("granted_to", -1)):
		return true
	if actor_id == int(access_contract.get("legal_office_holder_id", -1)):
		return true

	var text_blob: String = ("%s %s %s %s" % [
		str(actor.job),
		str(actor.social_class),
		str(actor.reputation),
		str(actor.title if "title" in actor else "")
	]).to_lower()

	return text_blob.find("president") != -1 or text_blob.find("first lady") != -1 or text_blob.find("first family") != -1


func _replace_property_for_all_owners(prop: Dictionary) -> void:
	var property_id: int = int(prop.get("id", -1))
	for owner_id in gs.property_engine.properties.keys():
		var rows: Array = gs.property_engine.properties.get(owner_id, [])
		for i in range(rows.size()):
			var row: Dictionary = _safe_dictionary(rows [i])
			if int(row.get("id", -1)) == property_id:
				rows [i] = prop
		gs.property_engine.properties [owner_id] = rows


func _result(actor: Person, property_id: int, success: bool, text: String) -> Dictionary:
	return {
		"success": success,
		"committed": success,
		"text": text,
		"popup_title": "Property Makeover",
		"popup_text": text,
		"popup_footer": "Property reality node refreshed.",
		"surface_contract": emit_makeover_surface_contract(actor, { "property_id": property_id, "status_text": text}),
		"commit_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}


func _emit_diary(actor: Person, text: String) -> void:
	if gs != null and gs.life_diary_contract_engine != null and gs.life_diary_contract_engine.has_method("emit_diary_intent"):
		gs.life_diary_contract_engine.emit_diary_intent({
			"type": "property_makeover",
			"actor_id": int(actor.id),
			"lines": [text],
			"source": ENGINE_SCHEMA
		})


func _interior_intro(prop: Dictionary, node: Dictionary) -> String:
	return "You step inside %s. The space feels %s, %s, and lived in." % [
		str(prop.get("display_name", prop.get("type", "your property"))),
		str(node.get("identity", {}).get("style", "basic")),
		str(node.get("identity", {}).get("condition", "maintained"))
	]


func _identity_summary(prop: Dictionary, node: Dictionary) -> String:
	return "%s • Condition: %s • Style: %s • Value: %s" % [
		str(prop.get("display_name", "Property")),
		str(node.get("identity", {}).get("condition", "maintained")).capitalize(),
		str(node.get("identity", {}).get("style", "basic")).capitalize(),
		_format_money(int(prop.get("value", prop.get("price", 0))))
	]


func _occupants_for_property(actor: Person, _prop: Dictionary) -> Array:
	return [{ "id": int(actor.id), "name": "%s %s" % [actor.first_name, actor.last_name], "room_id": "living_room"}]


func _property_title(prop: Dictionary) -> String:
	return "INSIDE • %s" % str(prop.get("display_name", prop.get("type", "Property")))


func _makeover_preview_text(path: Dictionary) -> String:
	return "%s would cost %s, take %d days, and create %s disruption." % [
		str(path.get("title", "This makeover")),
		str(path.get("cost_text", "$0")),
		int(path.get("duration_days", 0)),
		str(path.get("disruption_level", "low"))
	]
func _property_amenity_synthesis_engine() -> PropertyAmenitySynthesisContractEngine:
	if gs == null:
		return null

	if gs.property_amenity_synthesis_contract_engine == null:
		gs.property_amenity_synthesis_contract_engine = PropertyAmenitySynthesisContractEngine.new(
			gs
		)
	elif gs.property_amenity_synthesis_contract_engine.has_method(
		"bind_game_state"
	):
		gs.property_amenity_synthesis_contract_engine.bind_game_state(
			gs
		)

	return gs.property_amenity_synthesis_contract_engine


func _makeover_era_key() -> String:
	var era_text: String = "modern"

	if gs != null and gs.era != null:
		era_text = str(
			gs.era.name
		).to_lower()

	if era_text.find("ancient") >= 0:
		return "ancient"

	if era_text.find("medieval") >= 0:
		return "medieval"

	if era_text.find("industrial") >= 0:
		return "industrial"

	if era_text.find("future") >= 0:
		return "future"

	return "modern"
func commit_property_space_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if gs != null and gs.spatial_traversal_contract_engine != null:
		return gs.spatial_traversal_contract_engine.commit_property_space_action(actor, payload)

	var property_id: int = int(payload.get("property_id", -1))
	return {
		"success": false,
		"committed": false,
		"allowed": false,
		"text": "Spatial traversal authority is not available right now.",
		"surface_contract": emit_property_space_contract(actor, {
			"property_id": property_id,
			"status_text": "Spatial traversal authority is not available right now."
		}),
		"commit_authority": "eralife.spatial_traversal_contract_engine",
		"ui_is_renderer_only": true
	}
func resolve_property_space_traversal_context(
	actor: Person,
	property_id: int,
	property_owner_id: int = -1
) -> Dictionary:
	var prop: Dictionary = _property_for_owner(
		actor,
		property_id,
		property_owner_id
	)
	if prop.is_empty():
		return {
			"success": false,
			"reason": "missing_property",
			"text": "That property could not be found.",
			"actor_id": (
				int(actor.id)
				if actor != null
				else -1
			),
			"property_id": property_id,
			"property_owner_id": property_owner_id
		}

	var node: Dictionary = _ensure_property_reality_node(
		prop,
		actor
	)
	var resolved_owner_id: int = int(
		prop.get(
			"owner_id",
			prop.get(
				"legal_owner_id",
				property_owner_id
			)
		)
	)

	return {
		"success": true,
		"property": prop,
		"node": node,
		"actor_id": int(actor.id),
		"property_id": property_id,
		"property_owner_id": resolved_owner_id,
		"authority": ENGINE_SCHEMA
	}


func commit_property_space_traversal_node(
	_actor: Person,
	prop: Dictionary,
	node: Dictionary
) -> void:
	if (
		prop.is_empty()
		or node.is_empty()
	):
		return

	var property_id: int = int(
		prop.get(
			"id",
			node.get(
				"property_id",
				-1
			)
		)
	)

	if property_id > 0:
		authoritative_property_reality_node_by_id [
			property_id
		] = node



	prop ["property_reality_node"] = node

func emit_property_space_traversal_diary(actor: Person, text: String) -> void:
	_emit_diary(actor, text)
func _property_space_action_text(_actor: Person, _prop: Dictionary, node: Dictionary, payload: Dictionary) -> String:
	var action_id: String = str(payload.get("action_id", payload.get("market_action", "")))
	var room_id: String = str(payload.get("room_id", node.get("active_room", "living_room")))
	var fixture_id: String = str(payload.get("fixture_id", ""))

	if action_id == "navigate_floor":
		var direction: String = str(payload.get("direction", ""))
		if direction == "up":
			return "I went upstairs and moved deeper into the property."
		if direction == "down":
			return "I went downstairs and moved through the property."
		return "I changed floors inside the property."

	if action_id == "move_room" or action_id == "move_to_room":
		return "I walked into the %s." % room_id.replace("_", " ")

	if action_id == "inspect_room":
		return "I inspected the %s and took in what was around me." % room_id.replace("_", " ")

	if action_id == "use_fixture":
		if fixture_id == "kitchen_fridge":
			return "I opened the fridge and checked the food stored inside the home."
		if fixture_id == "household_storage":
			return "I opened household storage and checked what belongings could be stored here."
		if fixture_id == "attic_heirloom_cache":
			return "I searched through old attic boxes for anything rare, strange, or meaningful."
		return "I used %s inside the %s." % [
			fixture_id.replace("_", " "),
			room_id.replace("_", " ")
		]

	return "I moved through the property."

func _format_money(amount: int) -> String:
	if gs != null and gs.economy_engine != null and gs.economy_engine.has_method("format_money"):
		return str(gs.economy_engine.format_money(amount))
	return "$%d" % amount


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []