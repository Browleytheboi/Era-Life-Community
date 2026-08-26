extends Resource
class_name PresenceEngine

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	gs = _gs


func emit_property_presence_contract(actor: Person, _prop: Dictionary, graph: Dictionary) -> Dictionary:
	var occupants: Array = []
	var active_room: String = str(graph.get("active_room", "living_room"))
	var actor_locations: Dictionary = _safe_dictionary(graph.get("actor_locations", {}))

	if actor != null:
		occupants.append({
			"id": int(actor.id),
			"name": "%s %s" % [actor.first_name, actor.last_name],
			"room_id": active_room,
			"presence_label": "You are here.",
			"presence_authority": "eralife.presence_engine",
			"location_source": "spatial_traversal_contract"
		})

	var room_ids: Array = _room_ids(graph)
	var family_ids: Array = []

	if actor != null:
		family_ids.append_array(actor.parents)
		family_ids.append_array(actor.children)
		if actor.partner != null:
			family_ids.append(int(actor.partner.id))

	var index: int = 0
	for raw_id in family_ids:
		var npc = gs.get_or_reactivate_npc_by_id(int(raw_id)) if gs != null else null
		if npc == null or not npc.alive:
			continue
		if room_ids.is_empty():
			break

		var npc_id: int = int(npc.id)
		var room_id: String = ""

		if actor_locations.has(str(npc_id)):
			var npc_location: Dictionary = _safe_dictionary(actor_locations.get(str(npc_id), {}))
			room_id = str(npc_location.get("room", ""))

		if room_id == "":
			room_id = str(room_ids [index % room_ids.size()])

		occupants.append({
			"id": npc_id,
			"name": "%s %s" % [npc.first_name, npc.last_name],
			"room_id": room_id,
			"presence_label": "%s is in the %s." % [npc.first_name, room_id.replace("_", " ")],
			"presence_authority": "eralife.presence_engine",
			"location_source": "spatial_traversal_contract" if actor_locations.has(str(npc_id)) else "presence_projection"
		})
		index += 1

	return {
		"occupants": occupants,
		"summary": _summary_for_room(occupants, active_room),
		"presence_authority": "eralife.presence_engine",
		"movement_authority": "eralife.spatial_traversal_contract_engine",
		"ui_is_renderer_only": true
	}
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _room_ids(graph: Dictionary) -> Array:
	var out: Array = []
	for raw_floor in graph.get("floors", []):
		if typeof(raw_floor) != TYPE_DICTIONARY:
			continue
		var floor_contract: Dictionary = raw_floor
		for raw_room in floor_contract.get("rooms", []):
			if typeof(raw_room) != TYPE_DICTIONARY:
				continue
			var room: Dictionary = raw_room
			var room_id: String = str(room.get("room_id", ""))
			if room_id != "":
				out.append(room_id)
	return out

func _summary_for_room(occupants: Array, active_room: String) -> String:
	var names: Array = []
	for raw_occupant in occupants:
		var occupant: Dictionary = raw_occupant
		if str(occupant.get("room_id", "")) == active_room and str(occupant.get("presence_label", "")) != "You are here.":
			names.append(str(occupant.get("name", "Someone")))
	if names.is_empty():
		return "No one else is in this room right now."
	return "%s is here." % ", ".join(names)