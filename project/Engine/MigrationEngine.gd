extends Resource
class_name MigrationEngine

var gs
var pending_requests: Dictionary = {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return

func open_player_migration_panel(player: Person) -> Dictionary:
	if gs == null or player == null or gs.geo_engine == null:
		return { "success": false, "text": "Migration is not available right now."}

	var destinations: Array = gs.geo_engine.get_candidate_destinations_for_person(player)
	var known_people_map: Dictionary = _count_known_people_by_settlement(player)

	for i in range(destinations.size()):
		var row: Dictionary = destinations [i]
		var settlement_id: String = str(row.get("settlement_id", ""))
		row ["known_people_there"] = int(known_people_map.get(settlement_id, 0))
		row ["cluster_preview"] = _describe_cluster_preview(player)
		destinations [i] = row

	return {
		"success": true,
		"type": "open_migration_panel",
		"text": "I opened the migration board.",
		"destinations": destinations,
		"owner_id": int(player.id)
	}

func submit_player_migration(settlement_id: String, move_household:= true) -> Dictionary:
	if gs == null or gs.player == null or gs.geo_engine == null:
		return { "success": false, "text": "Migration is not available right now."}
	if settlement_id.strip_edges() == "":
		return { "success": false, "text": "No destination was selected."}

	var player_is_court_locked: bool = bool(gs.player.is_ruler)
	player_is_court_locked = player_is_court_locked or ((bool(gs.player.is_royal) or str(gs.player.royal_title).strip_edges() != "" or str(gs.player.social_class).strip_edges() == "Royal") and not bool(gs.player.exiled) and not bool(gs.player.deposed))
	if player_is_court_locked:
		return { "success": false, "text": "I can't leave my ruling realm while I still belong to the court."}

	var destination: Dictionary = gs.geo_engine.get_settlement(settlement_id)
	if destination.is_empty():
		return { "success": false, "text": "That destination is no longer available."}
	var movers: Array = [gs.player]
	if move_household:
		movers = _resolve_household_cluster(gs.player)
	for raw_person in movers:
		var person: Person = raw_person
		if person == null:
			continue
		_apply_migration(person, destination, {
			"move_household": move_household,
			"is_player_initiated": true
		})
	return {
		"success": true,
		"text": "I relocated to %s." % str(destination.get("name", "my destination"))
	}

func _resolve_household_cluster(player: Person) -> Array:
	var out: Array = []
	if player == null or gs == null:
		return out

	out.append(player)

	if player.partner != null and player.partner.alive and player.partner not in out:
		out.append(player.partner)

	for raw_id in player.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(raw_id))
		if child != null and child.alive and int(child.age) < 18 and child not in out:
			out.append(child)

	if int(player.age) < 18:
		for raw_id in player.parents:
			var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_id))
			if parent != null and parent.alive and parent not in out:
				out.append(parent)

	return out

func _apply_migration(npc: Person, destination: Dictionary, context:= {}) -> void:
	if npc == null or gs == null:
		return

	var migration_context: Dictionary = context.duplicate(true) if typeof(context) == TYPE_DICTIONARY else {}
	var court_locked: bool = bool(npc.is_ruler)
	court_locked = court_locked or ((bool(npc.is_royal) or str(npc.royal_title).strip_edges() != "" or str(npc.social_class).strip_edges() == "Royal") and not bool(npc.exiled) and not bool(npc.deposed))
	var allow_court_departure: bool = bool(migration_context.get("allow_court_departure", false))
	if court_locked and not allow_court_departure:
		if gs.royalty_engine != null and gs.royalty_engine.has_method("setup_seed_royal_house"):
			gs.royalty_engine.setup_seed_royal_house(npc)
		return

	var clean_destination: Dictionary = destination.duplicate(true) if typeof(destination) == TYPE_DICTIONARY else {}
	if gs.geo_engine != null and gs.geo_engine.has_method("_geo_sanitized_settlement"):
		clean_destination = gs.geo_engine._geo_sanitized_settlement(clean_destination)

	if clean_destination.is_empty():
		return

	var old_realm_id: int = int(npc.realm_id)
	var old_settlement_id: String = str(npc.settlement_id)
	var old_city: String = str(npc.home_city)
	var old_country: String = str(npc.home_country)

	var target_city: String = str(clean_destination.get("city", clean_destination.get("name", npc.home_city))).strip_edges()
	var target_country: String = str(clean_destination.get("country", clean_destination.get("realm_name", npc.home_country))).strip_edges()

	if target_city == "" or target_country == "":
		return

	var from_place_packet: Dictionary = {}
	if gs.geo_engine != null and old_settlement_id.strip_edges() != "":
		from_place_packet = gs.geo_engine.get_place_packet(old_settlement_id)

	npc.realm_id = int(clean_destination.get("realm_id", npc.realm_id))
	npc.settlement_id = str(clean_destination.get("id", clean_destination.get("settlement_id", npc.settlement_id)))
	npc.district_id = str(clean_destination.get("default_district_id", npc.district_id))
	npc.locality_id = str(clean_destination.get("default_locality_id", npc.locality_id))
	npc.home_city = target_city
	npc.home_country = target_country

	var to_place_packet: Dictionary = {}
	if gs.geo_engine != null and str(npc.settlement_id).strip_edges() != "":
		to_place_packet = gs.geo_engine.get_place_packet(str(npc.settlement_id))

	if typeof(npc.migration_history) != TYPE_ARRAY:
		npc.migration_history = []

	npc.migration_history.append({
		"year": int(gs.year),
		"from_realm_id": old_realm_id,
		"from_settlement_id": old_settlement_id,
		"from_city": old_city,
		"from_country": old_country,
		"from_place_packet": from_place_packet.duplicate(true),
		"to_realm_id": int(npc.realm_id),
		"to_settlement_id": str(npc.settlement_id),
		"to_city": str(npc.home_city),
		"to_country": str(npc.home_country),
		"to_place_packet": to_place_packet.duplicate(true),
		"context": migration_context.duplicate(true)
	})

	if typeof(npc.diaspora_tags) != TYPE_ARRAY:
		npc.diaspora_tags = []

	if old_country.strip_edges() != "" and old_country != npc.home_country:
		var diaspora_tag:= "diaspora:%s->%s" % [old_country, npc.home_country]
		if diaspora_tag not in npc.diaspora_tags:
			npc.diaspora_tags.append(diaspora_tag)

	if typeof(npc.identity_residue) != TYPE_DICTIONARY:
		npc.identity_residue = {}

	npc.identity_residue ["homesickness"] = float(npc.identity_residue.get("homesickness", 0.0)) + 12.0
	npc.identity_residue ["nostalgia"] = float(npc.identity_residue.get("nostalgia", 0.0)) + 8.0
	npc.identity_residue ["return_home_pull"] = float(npc.identity_residue.get("return_home_pull", 0.0)) + 10.0

	if old_country.strip_edges() != "" and old_country != npc.home_country:
		npc.identity_residue ["diaspora_belonging"] = float(npc.identity_residue.get("diaspora_belonging", 0.0)) + 6.0

	npc.years_in_current_place = 0
	npc.total_place_moves = int(npc.migration_history.size())
	npc.last_place_shift_year = int(gs.year)

	if gs.geo_engine != null:
		gs.geo_engine.bootstrap_person_place(npc, { "settlement_id": npc.settlement_id})

	var place_summary: Dictionary = {}
	var place_tags: Array = []
	if gs.place_influence_engine != null:
		place_summary = gs.place_influence_engine.refresh_npc(npc, false)
		place_tags = gs.place_influence_engine.get_memory_place_tags(npc)

	if gs.world_space_engine != null:
		gs.world_space_engine.place_npc(npc)

	var dominant_channels: Array = place_summary.get("dominant_channels", [])
	var dominant_labels: Array = []
	if typeof(dominant_channels) == TYPE_ARRAY:
		for raw_channel in dominant_channels:
			dominant_labels.append(str(raw_channel))

	var adaptation_tail:= ""
	if not dominant_labels.is_empty():
		adaptation_tail = " The new place pressed on %s." % ", ".join(dominant_labels)

	var move_text:= "%s %s migrated from %s to %s.%s" % [
		str(npc.first_name),
		str(npc.last_name),
		old_city if old_city.strip_edges() != "" else old_country,
		str(npc.home_city),
		adaptation_tail
	]

	if gs.event_bus != null:
		var show_move_in_world_feed: bool = bool(migration_context.get("is_player_initiated", false)) and gs.player != null and int(npc.id) == int(gs.player.id)
		gs.event_bus.emit(ActionEventTypes.NPC_MOVED, {
			"npc_id": int(npc.id),
			"text": move_text,
			"realm_id": int(npc.realm_id),
			"settlement_id": str(npc.settlement_id),
			"district_id": str(npc.district_id),
			"locality_id": str(npc.locality_id),
			"from_realm_id": old_realm_id,
			"from_settlement_id": old_settlement_id,
			"from_city": old_city,
			"from_country": old_country,
			"to_city": str(npc.home_city),
			"to_country": str(npc.home_country),
			"place_tags": place_tags.duplicate(),
			"place_identity_summary": place_summary.duplicate(true),
			"data": {
				"place_tags": place_tags.duplicate(),
				"place_identity_summary": place_summary.duplicate(true),
				"migration_context": migration_context.duplicate(true)
			},
			"source": "migration_engine",
			"suppress_world_feed": not show_move_in_world_feed,
			"show_move_in_world_feed": show_move_in_world_feed
		})
func _count_known_people_by_settlement(player: Person) -> Dictionary:
	var out: Dictionary = {}
	if player == null or gs == null:
		return out

	var known_ids: Array = []
	known_ids += player.parents
	known_ids += player.children
	known_ids += player.friends
	if player.partner != null:
		known_ids.append(int(player.partner.id))

	for raw_id in known_ids:
		var facts: Dictionary = gs.get_npc_facts_by_id(int(raw_id))
		if facts == {}:
			continue
		var settlement_id: String = str(facts.get("settlement_id", ""))
		if settlement_id == "":
			continue
		out [settlement_id] = int(out.get(settlement_id, 0)) + 1

	return out

func _describe_cluster_preview(player: Person) -> Dictionary:
	var household_size:= _resolve_household_cluster(player).size()
	return {
		"household_size": household_size,
		"partner_moves": player.partner != null,
	}