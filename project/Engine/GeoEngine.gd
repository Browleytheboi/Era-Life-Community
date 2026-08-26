extends Resource
class_name GeoEngine

const GEO_ENGINE_STATE_SCHEMA:= "eralife.geo_engine_state"
const GEO_ENGINE_CONTRACT_SCHEMA:= "eralife.geo_contract"
const GEO_ENGINE_VERSION:= 1

var gs

var settlements: Dictionary = {}
var settlement_packets: Dictionary = {}
var realm_to_settlements: Dictionary = {}
var settlement_anchor_tiles: Dictionary = {}
var geo_contracts: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs):
	gs = _gs

func bootstrap_for_current_era(_payload:= {}) -> void:
	if gs == null:
		return

	if settlements.is_empty():
		_build_default_settlement_layer_for_era()
	else:
		_geo_repair_placeholder_settlement_registry()
		_geo_rebuild_contract_registry_from_settlements()

	_geo_repair_placeholder_places_for_current_player_household("bootstrap_for_current_era")

	last_report = {
		"success": true,
		"mode": "geo_bootstrap_for_current_era",
		"settlement_count": settlements.size(),
		"contract_count": geo_contracts.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return
func export_state() -> Dictionary:
	_geo_repair_placeholder_settlement_registry()
	_geo_rebuild_contract_registry_from_settlements()

	return {
		"schema": GEO_ENGINE_STATE_SCHEMA,
		"version": GEO_ENGINE_VERSION,
		"settlements": settlements.duplicate(true),
		"settlement_packets": settlement_packets.duplicate(true),
		"realm_to_settlements": realm_to_settlements.duplicate(true),
		"settlement_anchor_tiles": _geo_anchor_tiles_to_save(),
		"geo_contracts": geo_contracts.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "GeoEngine import_state expected a Dictionary."
		}

	settlements = _geo_safe_dictionary(data.get("settlements", data.get("geo_settlements", {})))
	settlement_packets = _geo_safe_dictionary(data.get("settlement_packets", data.get("geo_settlement_packets", {})))
	realm_to_settlements = _geo_safe_dictionary(data.get("realm_to_settlements", data.get("geo_realm_to_settlements", {})))
	settlement_anchor_tiles = _geo_anchor_tiles_from_save(data.get("settlement_anchor_tiles", data.get("anchor_tiles", {})))
	geo_contracts = _geo_safe_dictionary(data.get("geo_contracts", data.get("contracts", {})))
	last_report = _geo_safe_dictionary(data.get("last_report", {}))

	if settlements.is_empty():
		bootstrap_for_current_era()
	else:
		_geo_repair_placeholder_settlement_registry()
		_geo_rebuild_contract_registry_from_settlements()

	_geo_repair_placeholder_places_for_current_player_household("geo_import_state")

	last_report = {
		"success": true,
		"mode": "geo_import_state",
		"settlement_count": settlements.size(),
		"contract_count": geo_contracts.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)
func on_npc_born(payload: Dictionary) -> void:
	if gs == null:
		return
	var npc_id: int = int(payload.get("npc_id", -1))
	if npc_id <= 0:
		return
	var npc: Person = gs.get_or_reactivate_npc_by_id(npc_id)
	if npc == null:
		return
	bootstrap_person_place(npc)

func bootstrap_person_place(npc: Person, preferred:= {}) -> void:
	if npc == null:
		return

	if settlements.is_empty():
		bootstrap_for_current_era()

	var preferred_context: Dictionary = preferred if typeof(preferred) == TYPE_DICTIONARY else {}
	var current_settlement_id: String = str(npc.settlement_id).strip_edges()
	var needs_assignment: bool = current_settlement_id == ""

	if not needs_assignment and not settlements.has(current_settlement_id):
		needs_assignment = true

	if not needs_assignment and _geo_person_place_is_placeholder(npc):
		needs_assignment = true

	if not needs_assignment and _geo_person_should_share_player_home(npc):
		var anchor_home: Dictionary = _geo_world_anchor_location()
		var anchor_city: String = str(anchor_home.get("city", "")).strip_edges()
		var anchor_country: String = str(anchor_home.get("country", "")).strip_edges()
		if str(npc.home_city).strip_edges() != anchor_city or str(npc.home_country).strip_edges() != anchor_country:
			needs_assignment = true

	if needs_assignment:
		var chosen: Dictionary = _choose_default_settlement_for_person(npc, preferred_context)
		if not chosen.is_empty():
			npc.settlement_id = str(chosen.get("id", ""))
			npc.district_id = str(chosen.get("default_district_id", ""))
			npc.locality_id = str(chosen.get("default_locality_id", ""))

			if str(npc.origin_settlement_id).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.origin_settlement_id)):
				npc.origin_settlement_id = npc.settlement_id
			if str(npc.origin_district_id).strip_edges() == "":
				npc.origin_district_id = npc.district_id
			if str(npc.origin_locality_id).strip_edges() == "":
				npc.origin_locality_id = npc.locality_id
			if str(npc.birthplace_settlement_id).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birthplace_settlement_id)):
				npc.birthplace_settlement_id = npc.settlement_id

	_sync_person_place_labels_from_settlement(npc)
func get_anchor_tile_for_person(npc: Person):
	if npc == null:
		return null
	var settlement_id: String = str(npc.settlement_id)
	if settlement_id == "":
		return null
	return settlement_anchor_tiles.get(settlement_id, null)

func get_neighbor_tile_for_person(npc: Person, old_tile):
	var anchor = get_anchor_tile_for_person(npc)
	if anchor == null:
		return null
	if old_tile == null:
		return anchor

	var dx:= randi_range(-1, 1)
	var dy:= randi_range(-1, 1)
	return Vector2i(anchor.x + dx, anchor.y + dy)

func get_settlement(settlement_id: String) -> Dictionary:
	return settlements.get(settlement_id, {}).duplicate(true)

func get_place_packet(settlement_id: String) -> Dictionary:
	return settlement_packets.get(settlement_id, {}).duplicate(true)

func get_candidate_destinations_for_person(npc: Person) -> Array:
	var out: Array = []
	if npc == null:
		return out

	if settlements.is_empty():
		bootstrap_for_current_era()

	for settlement_id in settlements.keys():
		var raw_settlement: Dictionary = settlements [settlement_id]
		var settlement: Dictionary = _geo_sanitized_settlement(raw_settlement)

		if settlement.is_empty():
			continue

		var city: String = str(settlement.get("city", settlement.get("name", ""))).strip_edges()
		var country: String = str(settlement.get("country", settlement.get("realm_name", ""))).strip_edges()

		if _geo_location_pair_is_placeholder(city, country):
			continue

		var packet: Dictionary = settlement_packets.get(settlement_id, {})
		out.append({
			"settlement_id": str(settlement_id),
			"realm_id": int(settlement.get("realm_id", -1)),
			"realm_name": country,
			"country": country,
			"settlement_name": city,
			"city": city,
			"district_name": str(settlement.get("default_district_name", "")),
			"travel_cost": int(packet.get("travel_cost", 0)),
			"travel_difficulty": float(packet.get("travel_difficulty", 1.0)),
			"border_openness": float(packet.get("border_openness", 0.5)),
			"school_quality": float(packet.get("school_quality", 0.5)),
			"boxing_scene": float(packet.get("boxing_density", 0.0)),
			"job_prospects": float(packet.get("job_market", 0.5)),
			"crime_pressure": float(packet.get("crime_pressure", 0.0)),
			"fame_market": float(packet.get("fame_concentration", 0.0)),
			"royal_pressure": float(packet.get("royal_influence", 0.0)),
			"faction_presence": float(packet.get("faction_density", 0.0)),
			"housing_vibe": str(packet.get("housing_vibe", "mixed")),
			"cultural_tags": packet.get("cultural_tags", []).duplicate(),
			"place_packet": packet.duplicate(true)
		})

	return out
func _resolve_geo_realm_name(realm_id: int) -> String:
	if gs != null and gs.realm_engine != null and gs.realm_engine.realms.has(realm_id):
		var realm = gs.realm_engine.realms [realm_id]
		var realm_name: String = str(realm.get("name", "")).strip_edges()
		if not _geo_location_text_is_placeholder(realm_name):
			return realm_name

	var anchor_location: Dictionary = _geo_world_anchor_location()
	var anchor_country: String = str(anchor_location.get("country", "")).strip_edges()
	if not _geo_location_text_is_placeholder(anchor_country):
		return anchor_country

	return "United States"
func _build_default_settlement_layer_for_era() -> void:
	if gs == null:
		return

	var rows: Array = _geo_location_rows_for_current_world()
	var registered: int = 0

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		if _geo_register_settlement_from_location(row, registered + 1):
			registered += 1

	if gs.realm_engine != null and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		for raw_realm_id in gs.realm_engine.realms.keys():
			var realm_id: int = int(raw_realm_id)
			var realm: Dictionary = gs.realm_engine.realms.get(raw_realm_id, {})
			if typeof(realm) != TYPE_DICTIONARY:
				continue

			var realm_name: String = str(realm.get("name", "")).strip_edges()
			var capital_city: String = str(realm.get("capital_city", realm.get("capital", ""))).strip_edges()

			if _geo_location_text_is_placeholder(realm_name):
				continue
			if _geo_location_text_is_placeholder(capital_city):
				capital_city = "%s Capital" % realm_name

			_geo_register_settlement_from_location({
				"city": capital_city,
				"country": realm_name,
				"realm_id": realm_id
			}, realm_id)

	if settlements.is_empty():
		_geo_register_settlement_from_location(_geo_world_anchor_location(), 1)
func _build_default_place_packet(realm_id: int, realm_name: String) -> Dictionary:
	return {
		"realm_id": realm_id,
		"realm_name": realm_name,
		"naming_flavor": realm_name,
		"dominant_jobs": [],
		"common_ambitions": [],
		"common_traits": [],
		"cultural_tags": [],
		"wealth_distribution": "mixed",
		"public_mood": 0.0,
		"romance_norms": 0.0,
		"violence_norms": 0.0,
		"education_emphasis": 0.5,
		"social_openness": 0.5,
		"spirituality_pressure": 0.15,
		"community_cohesion": 0.5,
		"instability": 0.25,
		"faction_density": 0.35,
		"fame_concentration": 0.15,
		"boxing_density": 0.1,
		"royal_influence": 0.1,
		"supernatural_presence": 0.0,
		"migrant_pull": 0.0,
		"migrant_push": 0.0,
		"scandal_sensitivity": 0.4,
		"encounter_pools": [],
		"event_pools": [],
		"diaspora_flavor": [],
		"travel_cost": 500,
		"travel_difficulty": 1.0,
		"border_openness": 0.5,
		"school_quality": 0.5,
		"job_market": 0.5,
		"crime_pressure": 0.25,
		"housing_vibe": "mixed"
	}
func _geo_location_text_is_placeholder(text: String) -> bool:
	var clean: String = str(text).strip_edges()
	var lower: String = clean.to_lower()

	if clean == "":
		return true
	if lower in ["unknown", "unknown city", "unknown country", "frontier realm", "frontier realm capital", "realm capital", "frontier capital"]:
		return true
	if lower.begins_with("frontier realm"):
		return true
	if lower.find("frontier realm") >= 0:
		return true
	if lower.find("frontier") >= 0 and lower.find("realm") >= 0:
		return true
	if lower.find("realm capital") >= 0 and lower.find("frontier") >= 0:
		return true

	return false


func _geo_location_pair_is_placeholder(city: String, country: String) -> bool:
	return _geo_location_text_is_placeholder(city) or _geo_location_text_is_placeholder(country)


func _geo_world_anchor_location() -> Dictionary:
	var candidates: Array = []

	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		if bool(gs.custom_settings.get("presidential_parents", false)):
			return {
				"city": "Washington, DC",
				"country": "United States",
				"continent": "North America",
				"state": "",
				"territory": "District of Columbia",
				"selected_place_kind": "territory",
				"selected_place": "District of Columbia",
				"geo_anchor_contract": "presidential_parent_contract"
			}

		candidates.append({
			"city": str(gs.custom_settings.get("city", gs.custom_settings.get("birth_city", gs.custom_settings.get("home_city", "")))),
			"country": str(gs.custom_settings.get("country", gs.custom_settings.get("birth_country", gs.custom_settings.get("home_country", "")))),
			"state": str(gs.custom_settings.get("state", gs.custom_settings.get("birth_state", gs.custom_settings.get("home_state", "")))),
			"territory": str(gs.custom_settings.get("territory", gs.custom_settings.get("birth_territory", gs.custom_settings.get("home_territory", "")))),
			"selected_place_kind": str(gs.custom_settings.get("selected_place_kind", "")),
			"selected_place": str(gs.custom_settings.get("selected_place", ""))
		})

	if gs != null and gs.player != null:
		candidates.append({
			"city": str(gs.player.home_city),
			"country": str(gs.player.home_country),
			"state": str(gs.player.get("home_state")),
			"territory": str(gs.player.get("home_territory")),
			"selected_place_kind": str(gs.player.get("selected_place_kind")),
			"selected_place": str(gs.player.get("selected_place"))
		})
		candidates.append({
			"city": str(gs.player.birth_city),
			"country": str(gs.player.birth_country),
			"state": str(gs.player.get("birth_state")),
			"territory": str(gs.player.get("birth_territory")),
			"selected_place_kind": str(gs.player.get("selected_place_kind")),
			"selected_place": str(gs.player.get("selected_place"))
		})

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations"):
		var birth_locations: Array = gs.era_engine.get_birth_locations()
		for raw_place in birth_locations:
			if typeof(raw_place) != TYPE_DICTIONARY:
				continue
			var place: Dictionary = raw_place as Dictionary
			candidates.append({
				"city": str(place.get("city", "")),
				"country": str(place.get("country", "")),
				"state": str(place.get("state", "")),
				"territory": str(place.get("territory", "")),
				"selected_place_kind": str(place.get("selected_place_kind", "")),
				"selected_place": str(place.get("selected_place", ""))
			})

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate as Dictionary
		var city: String = str(candidate.get("city", "")).strip_edges()
		var country: String = str(candidate.get("country", "")).strip_edges()

		if not _geo_location_pair_is_placeholder(city, country):
			var state: String = str(candidate.get("state", "")).strip_edges()
			var territory: String = str(candidate.get("territory", "")).strip_edges()
			var place_kind: String = str(candidate.get("selected_place_kind", "")).strip_edges()
			var selected_place: String = str(candidate.get("selected_place", "")).strip_edges()

			if place_kind == "":
				if territory != "":
					place_kind = "territory"
				elif state != "":
					place_kind = "state"
				else:
					place_kind = "country"

			if selected_place == "":
				if place_kind == "territory":
					selected_place = territory
				elif place_kind == "state":
					selected_place = state
				else:
					selected_place = country

			return {
				"city": city,
				"country": country,
				"continent": "North America" if country == "United States" else "",
				"state": state,
				"territory": territory,
				"selected_place_kind": place_kind,
				"selected_place": selected_place
			}

	return {
		"city": "Chicago",
		"country": "United States",
		"continent": "North America",
		"state": "Illinois",
		"territory": "",
		"selected_place_kind": "state",
		"selected_place": "Illinois"
	}

func _geo_location_rows_for_current_world() -> Array:
	var rows: Array = []
	var seen: Dictionary = {}

	var anchor: Dictionary = _geo_world_anchor_location()
	var anchor_key: String = "%s|%s" % [str(anchor.get("city", "")), str(anchor.get("country", ""))]
	rows.append(anchor)
	seen [anchor_key] = true

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations"):
		var birth_locations: Array = gs.era_engine.get_birth_locations()
		for raw_place in birth_locations:
			if typeof(raw_place) != TYPE_DICTIONARY:
				continue

			var place: Dictionary = raw_place as Dictionary
			var city: String = str(place.get("city", "")).strip_edges()
			var country: String = str(place.get("country", "")).strip_edges()

			if _geo_location_pair_is_placeholder(city, country):
				continue

			var key: String = "%s|%s" % [city, country]
			if seen.has(key):
				continue

			rows.append({
				"city": city,
				"country": country
			})
			seen [key] = true

	return rows


func _geo_settlement_id_for_location(city: String, country: String) -> String:
	var clean_city: String = str(city).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")
	var clean_country: String = str(country).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")

	if clean_city == "":
		clean_city = "city"
	if clean_country == "":
		clean_country = "country"

	return "place_%s_%s" % [clean_country, clean_city]

func _geo_settlement_id_for_location_contract(city: String, country: String, state: String = "", territory: String = "") -> String:
	var clean_city: String = str(city).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")
	var clean_country: String = str(country).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")
	var clean_state: String = str(state).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")
	var clean_territory: String = str(territory).strip_edges().to_lower().replace(" ", "_").replace(",", "").replace("'", "")

	if clean_city == "":
		clean_city = "city"
	if clean_country == "":
		clean_country = "country"

	if clean_country in ["usa", "united_states", "united_states_of_america"]:
		clean_country = "united_states"

	if clean_territory != "":
		return "place_%s_territory_%s_%s" % [clean_country, clean_territory, clean_city]

	if clean_state != "":
		return "place_%s_state_%s_%s" % [clean_country, clean_state, clean_city]

	return "place_%s_%s" % [clean_country, clean_city]
func _geo_register_settlement_from_location(location: Dictionary, fallback_realm_id: int = 1) -> bool:
	if typeof(location) != TYPE_DICTIONARY:
		return false

	var city: String = str(location.get("city", location.get("name", ""))).strip_edges()
	var country: String = str(location.get("country", location.get("realm_name", ""))).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return false

	var realm_id: int = int(location.get("realm_id", fallback_realm_id))
	if realm_id <= 0:
		realm_id = fallback_realm_id

	var settlement_id: String = str(location.get("id", "")).strip_edges()
	if settlement_id == "":
		settlement_id = _geo_settlement_id_for_location(city, country)

	var default_district_id: String = "%s_central" % settlement_id
	var default_locality_id: String = "%s_central_locality" % settlement_id

	settlements [settlement_id] = {
		"id": settlement_id,
		"schema": "eralife.geo_settlement",
		"version": GEO_ENGINE_VERSION,
		"realm_id": realm_id,
		"realm_name": country,
		"country": country,
		"name": city,
		"city": city,
		"default_district_id": default_district_id,
		"default_district_name": "Central District",
		"default_locality_id": default_locality_id,
		"contract_id": "geo_settlement_%s" % settlement_id,
		"contract_mesh": {
			"source_of_truth": "geo_engine",
			"persistent": true,
			"save_key": "geo_engine_state"
		},
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	var packet: Dictionary = _build_default_place_packet(realm_id, country)
	packet ["realm_name"] = country
	packet ["country"] = country
	packet ["city"] = city
	packet ["settlement_id"] = settlement_id
	packet ["contract_id"] = "geo_place_packet_%s" % settlement_id
	settlement_packets [settlement_id] = packet

	var mapped: Array = realm_to_settlements.get(realm_id, [])
	if settlement_id not in mapped:
		mapped.append(settlement_id)
	realm_to_settlements [realm_id] = mapped

	settlement_anchor_tiles [settlement_id] = _geo_anchor_tile_for_location(city, country)
	geo_contracts [settlement_id] = _geo_contract_for_settlement(settlements [settlement_id], packet)

	return true


func _geo_sanitized_settlement(settlement: Dictionary) -> Dictionary:
	if typeof(settlement) != TYPE_DICTIONARY or settlement.is_empty():
		return {}

	var out: Dictionary = settlement.duplicate(true)
	var city: String = str(out.get("city", out.get("name", ""))).strip_edges()
	var country: String = str(out.get("country", out.get("realm_name", ""))).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		var anchor: Dictionary = _geo_world_anchor_location()
		city = str(anchor.get("city", city)).strip_edges()
		country = str(anchor.get("country", country)).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return {}

	out ["name"] = city
	out ["city"] = city
	out ["realm_name"] = country
	out ["country"] = country

	if str(out.get("id", "")).strip_edges() == "":
		out ["id"] = _geo_settlement_id_for_location(city, country)

	if str(out.get("default_district_id", "")).strip_edges() == "":
		out ["default_district_id"] = "%s_central" % str(out.get("id"))
	if str(out.get("default_district_name", "")).strip_edges() == "":
		out ["default_district_name"] = "Central District"
	if str(out.get("default_locality_id", "")).strip_edges() == "":
		out ["default_locality_id"] = "%s_central_locality" % str(out.get("id"))

	return out


func _geo_person_should_share_player_home(npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false
	if int(npc.id) == int(gs.player.id):
		return true

	var player: Person = gs.player
	var npc_id: int = int(npc.id)

	if int(player.age) < 18 and npc_id in player.parents:
		return true
	if int(npc.age) < 18 and npc_id in player.children:
		return true
	if player.partner != null and int(player.partner.id) == npc_id:
		return true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var member_index: Dictionary = gs.scenario_state.get("custom_household_member_index", {})
		if typeof(member_index) == TYPE_DICTIONARY:
			var player_found: bool = false
			var npc_found: bool = false
			for raw_key in member_index.keys():
				var member_id: int = int(member_index.get(raw_key, -1))
				if member_id == int(player.id):
					player_found = true
				if member_id == npc_id:
					npc_found = true
			if player_found and npc_found:
				return true

	return false
func _geo_safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _geo_safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []


func _geo_anchor_tile_for_location(city: String, country: String) -> Vector2i:
	var seed_value: int = abs(int(hash("%s|%s|geo_anchor" % [city, country])))
	var tile_x: int = int(seed_value % 80) - 40
	var tile_y_seed: int = floori(float(seed_value) / 80.0)
	var tile_y: int = int(tile_y_seed % 80) - 40
	return Vector2i(tile_x, tile_y)


func _geo_anchor_tiles_to_save() -> Dictionary:
	var out: Dictionary = {}

	for raw_settlement_id in settlement_anchor_tiles.keys():
		var settlement_id: String = str(raw_settlement_id)
		var tile_value: Variant = settlement_anchor_tiles.get(raw_settlement_id)

		if typeof(tile_value) == TYPE_VECTOR2I:
			var tile: Vector2i = tile_value
			out [settlement_id] = {
				"x": int(tile.x),
				"y": int(tile.y)
			}
		elif typeof(tile_value) == TYPE_VECTOR2:
			var tile2: Vector2 = tile_value
			out [settlement_id] = {
				"x": int(tile2.x),
				"y": int(tile2.y)
			}

	return out


func _geo_anchor_tiles_from_save(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	var source: Dictionary = _geo_safe_dictionary(value)

	for raw_settlement_id in source.keys():
		var settlement_id: String = str(raw_settlement_id)
		var raw_tile: Variant = source.get(raw_settlement_id)

		if typeof(raw_tile) == TYPE_VECTOR2I:
			out [settlement_id] = raw_tile
		elif typeof(raw_tile) == TYPE_VECTOR2:
			var tile2: Vector2 = raw_tile
			out [settlement_id] = Vector2i(int(tile2.x), int(tile2.y))
		elif typeof(raw_tile) == TYPE_DICTIONARY:
			var tile_dict: Dictionary = raw_tile
			out [settlement_id] = Vector2i(
				int(tile_dict.get("x", 0)),
				int(tile_dict.get("y", 0))
			)

	return out


func _geo_contract_for_settlement(settlement: Dictionary, packet: Dictionary = {}) -> Dictionary:
	var clean_settlement: Dictionary = _geo_sanitized_settlement(settlement)
	if clean_settlement.is_empty():
		return {}

	var settlement_id: String = str(clean_settlement.get("id", "")).strip_edges()
	var city: String = str(clean_settlement.get("city", clean_settlement.get("name", ""))).strip_edges()
	var country: String = str(clean_settlement.get("country", clean_settlement.get("realm_name", ""))).strip_edges()

	return {
		"schema": GEO_ENGINE_CONTRACT_SCHEMA,
		"version": GEO_ENGINE_VERSION,
		"contract_id": "geo_contract_%s" % settlement_id,
		"settlement_id": settlement_id,
		"city": city,
		"country": country,
		"realm_id": int(clean_settlement.get("realm_id", -1)),
		"realm_name": country,
		"settlement": clean_settlement.duplicate(true),
		"place_packet": packet.duplicate(true),
		"visibility_contract": {
			"placeholder_repair_source": "geo_engine_contract"
		},
		"persistence_contract": {
			"save_key": "geo_engine_state",
			"import_method": "import_state",
			"export_method": "export_state",
			"backwards_compatible": true
		},
		"family_contract": {
		},
		"contract_mesh": {
			"source_of_truth": "GeoEngine",
			"systems_allowed_to_observe": ["relationship_profile", "migration", "world", "school", "runtime_contracts"],
			"systems_allowed_to_mutate": ["GeoEngine", "MigrationEngine"],
		},
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func _geo_rebuild_contract_registry_from_settlements() -> void:
	geo_contracts.clear()

	for raw_settlement_id in settlements.keys():
		var settlement_id: String = str(raw_settlement_id)
		var settlement: Dictionary = _geo_sanitized_settlement(settlements.get(raw_settlement_id, {}))
		if settlement.is_empty():
			continue

		settlements [settlement_id] = settlement

		var packet: Dictionary = _geo_safe_dictionary(settlement_packets.get(settlement_id, {}))
		if packet.is_empty():
			packet = _build_default_place_packet(int(settlement.get("realm_id", -1)), str(settlement.get("country", settlement.get("realm_name", ""))))
			packet ["settlement_id"] = settlement_id
			packet ["city"] = str(settlement.get("city", settlement.get("name", "")))
			packet ["country"] = str(settlement.get("country", settlement.get("realm_name", "")))
			packet ["realm_name"] = str(settlement.get("country", settlement.get("realm_name", "")))
			settlement_packets [settlement_id] = packet

		if not settlement_anchor_tiles.has(settlement_id):
			settlement_anchor_tiles [settlement_id] = _geo_anchor_tile_for_location(
				str(settlement.get("city", settlement.get("name", ""))),
				str(settlement.get("country", settlement.get("realm_name", "")))
			)

		geo_contracts [settlement_id] = _geo_contract_for_settlement(settlement, packet)


func _geo_repair_placeholder_settlement_registry() -> void:
	if settlements.is_empty():
		return

	var repaired_settlements: Dictionary = {}
	var repaired_packets: Dictionary = {}
	var repaired_realm_map: Dictionary = {}

	for raw_settlement_id in settlements.keys():
		var settlement_id: String = str(raw_settlement_id)
		var settlement: Dictionary = _geo_sanitized_settlement(settlements.get(raw_settlement_id, {}))
		if settlement.is_empty():
			continue

		var city: String = str(settlement.get("city", settlement.get("name", ""))).strip_edges()
		var country: String = str(settlement.get("country", settlement.get("realm_name", ""))).strip_edges()

		if _geo_location_pair_is_placeholder(city, country):
			continue

		settlement ["id"] = settlement_id
		settlement ["name"] = city
		settlement ["city"] = city
		settlement ["realm_name"] = country
		settlement ["country"] = country

		repaired_settlements [settlement_id] = settlement

		var packet: Dictionary = _geo_safe_dictionary(settlement_packets.get(settlement_id, {}))
		if packet.is_empty():
			packet = _build_default_place_packet(int(settlement.get("realm_id", -1)), country)
		packet ["settlement_id"] = settlement_id
		packet ["city"] = city
		packet ["country"] = country
		packet ["realm_name"] = country
		repaired_packets [settlement_id] = packet

		var realm_id: int = int(settlement.get("realm_id", -1))
		var mapped: Array = _geo_safe_array(repaired_realm_map.get(realm_id, []))
		if settlement_id not in mapped:
			mapped.append(settlement_id)
		repaired_realm_map [realm_id] = mapped

	settlements = repaired_settlements
	settlement_packets = repaired_packets
	realm_to_settlements = repaired_realm_map

	if settlements.is_empty():
		_geo_register_settlement_from_location(_geo_world_anchor_location(), 1)

	_geo_rebuild_contract_registry_from_settlements()


func _geo_anchor_settlement_id() -> String:
	var anchor: Dictionary = _geo_world_anchor_location()
	var city: String = str(anchor.get("city", "")).strip_edges()
	var country: String = str(anchor.get("country", "")).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return ""

	var settlement_id: String = _geo_settlement_id_for_location(city, country)
	if not settlements.has(settlement_id):
		_geo_register_settlement_from_location({
			"id": settlement_id,
			"city": city,
			"country": country,
			"realm_id": 1
		}, 1)

	return settlement_id


func _geo_person_place_is_placeholder(npc: Person) -> bool:
	if npc == null:
		return true

	var city: String = str(npc.home_city).strip_edges()
	var country: String = str(npc.home_country).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return true

	var settlement_id: String = str(npc.settlement_id).strip_edges()
	if settlement_id == "":
		return true

	if not settlements.has(settlement_id):
		return true

	return _geo_sanitized_settlement(settlements.get(settlement_id, {})).is_empty()


func _geo_apply_anchor_home_to_person(npc: Person, reason: String = "anchor_home") -> void:
	if npc == null:
		return

	var anchor_settlement_id: String = _geo_anchor_settlement_id()
	if anchor_settlement_id == "" or not settlements.has(anchor_settlement_id):
		return

	var settlement: Dictionary = _geo_sanitized_settlement(settlements.get(anchor_settlement_id, {}))
	if settlement.is_empty():
		return

	var city: String = str(settlement.get("city", settlement.get("name", ""))).strip_edges()
	var country: String = str(settlement.get("country", settlement.get("realm_name", ""))).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return

	npc.settlement_id = anchor_settlement_id
	npc.district_id = str(settlement.get("default_district_id", npc.district_id))
	npc.locality_id = str(settlement.get("default_locality_id", npc.locality_id))
	npc.realm_id = int(settlement.get("realm_id", npc.realm_id))
	npc.home_city = city
	npc.home_country = country

	if str(npc.origin_settlement_id).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.origin_settlement_id)):
		npc.origin_settlement_id = anchor_settlement_id
	if str(npc.birthplace_settlement_id).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birthplace_settlement_id)):
		npc.birthplace_settlement_id = anchor_settlement_id
	if str(npc.birth_city).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birth_city)):
		npc.birth_city = city
	if str(npc.birth_country).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birth_country)):
		npc.birth_country = country

	if typeof(npc.identity_residue) != TYPE_DICTIONARY:
		npc.identity_residue = {}

	npc.identity_residue ["geo_anchor_home_reason"] = reason
	npc.identity_residue ["geo_anchor_home_at_ms"] = int(Time.get_ticks_msec())


func _geo_repair_placeholder_places_for_current_player_household(reason: String = "geo_repair") -> void:
	if gs == null or gs.player == null:
		return

	var ids: Dictionary = {}
	var player: Person = gs.player
	ids [int(player.id)] = true

	for raw_parent_id in player.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0:
			ids [parent_id] = true

	for raw_child_id in player.children:
		var child_id: int = int(raw_child_id)
		if child_id > 0:
			ids [child_id] = true

	if player.partner != null:
		ids [int(player.partner.id)] = true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var member_index: Dictionary = gs.scenario_state.get("custom_household_member_index", {})
		if typeof(member_index) == TYPE_DICTIONARY:
			for raw_key in member_index.keys():
				var member_id: int = int(member_index.get(raw_key, -1))
				if member_id > 0:
					ids [member_id] = true

	for raw_id in ids.keys():
		var actor_id: int = int(raw_id)
		var actor: Person = null

		if gs.has_method("get_npc_by_id"):
			actor = gs.get_npc_by_id(actor_id)
		if actor == null and gs.has_method("get_or_reactivate_npc_by_id"):
			actor = gs.get_or_reactivate_npc_by_id(actor_id)

		if actor == null:
			continue

		if _geo_person_should_share_player_home(actor) or _geo_person_place_is_placeholder(actor):
			_geo_apply_anchor_home_to_person(actor, reason)
func _choose_default_settlement_for_person(npc: Person, preferred:= {}) -> Dictionary:
	var preferred_context: Dictionary = preferred if typeof(preferred) == TYPE_DICTIONARY else {}

	var preferred_settlement_id: String = str(preferred_context.get("settlement_id", preferred_context.get("id", ""))).strip_edges()
	if preferred_settlement_id != "" and settlements.has(preferred_settlement_id):
		var preferred_settlement: Dictionary = _geo_sanitized_settlement(settlements [preferred_settlement_id])
		if not preferred_settlement.is_empty():
			return preferred_settlement.duplicate(true)

	var preferred_city: String = str(preferred_context.get("city", preferred_context.get("home_city", ""))).strip_edges()
	var preferred_country: String = str(preferred_context.get("country", preferred_context.get("home_country", ""))).strip_edges()
	if not _geo_location_pair_is_placeholder(preferred_city, preferred_country):
		var preferred_location_id: String = _geo_settlement_id_for_location(preferred_city, preferred_country)
		if not settlements.has(preferred_location_id):
			_geo_register_settlement_from_location({
				"city": preferred_city,
				"country": preferred_country,
				"id": preferred_location_id
			}, 1)
		if settlements.has(preferred_location_id):
			return _geo_sanitized_settlement(settlements [preferred_location_id]).duplicate(true)

	if _geo_person_should_share_player_home(npc):
		var anchor_settlement_id: String = _geo_anchor_settlement_id()
		if anchor_settlement_id != "" and settlements.has(anchor_settlement_id):
			return _geo_sanitized_settlement(settlements [anchor_settlement_id]).duplicate(true)

	var realm_id: int = int(npc.realm_id)
	var options: Array = realm_to_settlements.get(realm_id, [])

	if options.is_empty():
		_build_default_settlement_layer_for_era()
		options = realm_to_settlements.get(realm_id, [])

	if not options.is_empty():
		for raw_settlement_id in options:
			var option_id: String = str(raw_settlement_id)
			if not settlements.has(option_id):
				continue
			var option: Dictionary = _geo_sanitized_settlement(settlements [option_id])
			if not option.is_empty():
				return option.duplicate(true)

	for settlement_id in settlements.keys():
		var settlement: Dictionary = _geo_sanitized_settlement(settlements [settlement_id])
		if not settlement.is_empty():
			return settlement.duplicate(true)

	var anchor: Dictionary = _geo_world_anchor_location()
	_geo_register_settlement_from_location(anchor, 1)
	var fallback_id: String = _geo_settlement_id_for_location(str(anchor.get("city", "")), str(anchor.get("country", "")))
	return _geo_sanitized_settlement(settlements.get(fallback_id, {}))
func _sync_person_place_labels_from_settlement(npc: Person) -> void:
	if npc == null:
		return

	if settlements.is_empty():
		bootstrap_for_current_era()

	if _geo_person_should_share_player_home(npc):
		_geo_apply_anchor_home_to_person(npc, "sync_person_place_labels_immediate_family")
		return

	var settlement_id: String = str(npc.settlement_id).strip_edges()
	var settlement: Dictionary = settlements.get(settlement_id, {})

	if settlement.is_empty():
		settlement = _choose_default_settlement_for_person(npc, {})
		if settlement.is_empty():
			return
		npc.settlement_id = str(settlement.get("id", settlement_id))
		npc.district_id = str(settlement.get("default_district_id", npc.district_id))
		npc.locality_id = str(settlement.get("default_locality_id", npc.locality_id))

	settlement = _geo_sanitized_settlement(settlement)
	if settlement.is_empty():
		var anchor_settlement_id: String = _geo_anchor_settlement_id()
		if anchor_settlement_id == "":
			return
		settlement = _geo_sanitized_settlement(settlements.get(anchor_settlement_id, {}))
		npc.settlement_id = anchor_settlement_id

	if settlement.is_empty():
		return

	var realm_id: int = int(settlement.get("realm_id", npc.realm_id))
	var city: String = str(settlement.get("city", settlement.get("name", npc.home_city))).strip_edges()
	var country: String = str(settlement.get("country", settlement.get("realm_name", npc.home_country))).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		var anchor_location: Dictionary = _geo_world_anchor_location()
		city = str(anchor_location.get("city", city)).strip_edges()
		country = str(anchor_location.get("country", country)).strip_edges()

	if _geo_location_pair_is_placeholder(city, country):
		return

	npc.realm_id = realm_id
	npc.home_city = city
	npc.home_country = country

	if str(npc.birth_city).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birth_city)):
		npc.birth_city = city
	if str(npc.birth_country).strip_edges() == "" or _geo_location_text_is_placeholder(str(npc.birth_country)):
		npc.birth_country = country