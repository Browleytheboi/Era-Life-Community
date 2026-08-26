extends Resource
class_name SharedPublicSpaceEngine

const CONTRACT_SCHEMA:= "eralife.shared_public_space_engine"
const CONTRACT_VERSION:= 1

var gs
var public_space_sessions: Dictionary = {}
var actor_public_space_sessions: Dictionary = {}
var public_space_catalogs: Dictionary = {}
var runtime_contract_public_space_keys: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"public_space_sessions": public_space_sessions.duplicate(true),
		"actor_public_space_sessions": actor_public_space_sessions.duplicate(true),
		"public_space_catalogs": public_space_catalogs.duplicate(true),
		"runtime_contract_public_space_keys": runtime_contract_public_space_keys.duplicate(true),
		"last_report": last_report.duplicate(true)
	})

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "SharedPublicSpaceEngine import_state expected a Dictionary."}
	public_space_sessions = _safe_dictionary(data.get("public_space_sessions", {}))
	actor_public_space_sessions = _safe_dictionary(data.get("actor_public_space_sessions", {}))
	public_space_catalogs = _safe_dictionary(data.get("public_space_catalogs", {}))
	runtime_contract_public_space_keys = _safe_dictionary(data.get("runtime_contract_public_space_keys", {}))
	last_report = _safe_dictionary(data.get("last_report", {}))
	return {
		"success": true,
		"session_count": public_space_sessions.size(),
		"actor_session_count": actor_public_space_sessions.size(),
		"runtime_contract_space_count": runtime_contract_public_space_keys.size()
	}
func yearly_tick() -> void:
	if gs == null:
		return

	emit_runtime_contracts({ "source": "shared_public_space_yearly_tick"})

	var current_year: int = int(gs.year)
	var stale_keys: Array = []
	for raw_key in public_space_sessions.keys():
		var key: String = str(raw_key)
		var session: Dictionary = _safe_dictionary(public_space_sessions.get(key, {}))
		var updated_year: int = int(session.get("updated_year", current_year))
		var runtime_contract_id: String = str(session.get("runtime_contract_id", "")).strip_edges()
		if runtime_contract_id != "":
			continue
		if current_year - updated_year > 1:
			stale_keys.append(key)
	for key in stale_keys:
		public_space_sessions.erase(key)
		runtime_contract_public_space_keys.erase(key)

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Shared public space command envelope is empty."}
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))
	match command_id:
		"public_space.emit_runtime_contracts":
			return emit_runtime_contracts(payload)
		"public_space.import_runtime_contract":
			return import_runtime_contract(_safe_dictionary(payload.get("contract", {})))
		"public_space.exit":
			var actor: Person = _actor_from_payload(payload)
			return exit_space(actor, str(payload.get("space_type", "")), str(payload.get("space_id", "")), payload)
		"public_space.move_zone":
			var move_actor: Person = _actor_from_payload(payload)
			return move_actor_to_zone(move_actor, str(payload.get("space_type", "")), str(payload.get("space_id", "")), str(payload.get("zone_id", "")), payload)
		_:
			return { "success": false, "reason": "No SharedPublicSpaceEngine route claimed this command.", "command": command_id}

func register_space_catalog(space_type: String, spaces: Array) -> Dictionary:
	var clean_type: String = str(space_type).strip_edges().to_lower()
	if clean_type == "":
		return { "success": false, "reason": "Space type is empty."}
	public_space_catalogs [clean_type] = _safe_array(spaces)
	return { "success": true, "space_type": clean_type, "space_count": _safe_array(spaces).size()}
func emit_runtime_contracts(context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.runtime_contract_engine == null:
		return { "success": false, "reason": "RuntimeContractEngine unavailable."}
	if not gs.runtime_contract_engine.has_method("ensure_default_world_contracts"):
		return { "success": false, "reason": "RuntimeContractEngine cannot emit default contracts."}

	return gs.runtime_contract_engine.ensure_default_world_contracts({
		"source": str(context.get("source", "shared_public_space_emit_runtime_contracts")),
		"space_layer": "shared_public_space_engine"
	})


func import_runtime_contract(contract: Dictionary) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return { "success": false, "reason": "Runtime contract is empty."}

	var public_space: Dictionary = _safe_dictionary(contract.get("public_space", {}))
	var clean_type: String = str(public_space.get("space_type", "")).strip_edges().to_lower()
	var clean_space: String = str(public_space.get("space_id", "")).strip_edges()

	if clean_type == "" or clean_space == "":
		var location: Dictionary = _safe_dictionary(contract.get("location", {}))
		clean_type = str(location.get("space_type", "")).strip_edges().to_lower()
		clean_space = str(location.get("space_id", "")).strip_edges()

	if clean_type == "" or clean_space == "":
		return { "success": false, "reason": "Runtime contract does not contain a public space identity."}

	var key: String = _space_session_key(clean_type, clean_space)
	var zones: Dictionary = _zones_from_runtime_contract(contract)
	var session: Dictionary = _safe_dictionary(public_space_sessions.get(key, {}))

	if session.is_empty():
		session = {
			"schema": CONTRACT_SCHEMA + "_session",
			"version": CONTRACT_VERSION,
			"session_key": key,
			"space_type": clean_type,
			"space_id": clean_space,
			"created_year": _current_year(),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	session ["zones"] = zones
	session ["runtime_contract_id"] = str(contract.get("contract_id", ""))
	session ["runtime_contract_schema"] = str(contract.get("schema", ""))
	session ["runtime_contract_type"] = str(contract.get("contract_type", ""))
	session ["runtime_contract_state"] = str(contract.get("state", "active"))
	session ["lifecycle"] = _safe_dictionary(contract.get("lifecycle", {}))
	session ["movie"] = _safe_dictionary(contract.get("movie", {}))
	session ["active_friction_events"] = _safe_array(contract.get("active_friction_events", []))
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())

	public_space_sessions [key] = session
	runtime_contract_public_space_keys [key] = str(contract.get("contract_id", ""))

	return {
		"success": true,
		"mode": "shared_public_space_import_runtime_contract",
		"space_type": clean_type,
		"space_id": clean_space,
		"session_key": key,
		"contract_id": str(contract.get("contract_id", "")),
		"presence_summary": presence_summary(clean_type, clean_space, { "source": "import_runtime_contract"})
	}


func _runtime_contract_session_for_space(space_type: String, space_id: String, context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.runtime_contract_engine == null:
		return {}

	if not gs.runtime_contract_engine.has_method("get_contract_for_space"):
		return {}

	var contract: Dictionary = gs.runtime_contract_engine.get_contract_for_space(space_type, space_id, context)
	if contract.is_empty():
		return {}

	var import_report: Dictionary = import_runtime_contract(contract)
	if not bool(import_report.get("success", false)):
		return {}

	var key: String = _space_session_key(space_type, space_id)
	return _safe_dictionary(public_space_sessions.get(key, {}))


func _zones_from_runtime_contract(contract: Dictionary) -> Dictionary:
	var raw_zones: Dictionary = _safe_dictionary(contract.get("zones", {}))
	var out: Dictionary = {}

	for raw_zone in raw_zones.keys():
		var zone_id: String = str(raw_zone).strip_edges().to_lower()
		if zone_id == "":
			continue

		var zone: Dictionary = _safe_dictionary(raw_zones.get(raw_zone, {}))
		out [zone_id] = {
			"actor_ids": _safe_array(zone.get("actor_ids", [])),
			"ambient_people": _safe_array(zone.get("ambient_people", [])),
			"runtime_tension": float(zone.get("tension", 0.0))
		}

	if out.is_empty():
		out ["lobby"] = { "actor_ids": [], "ambient_people": []}
		out ["line"] = { "actor_ids": [], "ambient_people": []}
		out ["concessions"] = { "actor_ids": [], "ambient_people": []}
		out ["auditorium"] = { "actor_ids": [], "ambient_people": []}
		out ["exit"] = { "actor_ids": [], "ambient_people": []}

	return out
func enter_space(actor: Person, space_type: String, space_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	if clean_type == "" or clean_space == "":
		return { "success": false, "reason": "Shared public space entry needs a space type and space id."}
	var session: Dictionary = _ensure_space_session(clean_type, clean_space, context)
	var actor_id: int = int(actor.id)
	var zone_id: String = str(context.get("zone_id", context.get("entry_zone", "lobby"))).strip_edges().to_lower()
	if zone_id == "":
		zone_id = "lobby"
	_ensure_zone(session, zone_id)
	_remove_actor_from_all_zones(session, actor_id)
	_add_actor_to_zone(session, zone_id, actor_id)
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	public_space_sessions [str(session.get("session_key", _space_session_key(clean_type, clean_space)))] = session
	actor_public_space_sessions [str(actor_id)] = {
		"space_type": clean_type,
		"space_id": clean_space,
		"zone_id": zone_id,
		"session_key": str(session.get("session_key", "")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	if gs != null and gs.runtime_contract_engine != null and gs.runtime_contract_engine.has_method("attach_actor_to_contract"):
		gs.runtime_contract_engine.attach_actor_to_contract(actor, "", {
			"source": "shared_public_space_enter",
			"space_type": clean_type,
			"space_id": clean_space,
			"zone_id": zone_id
		})

	last_report = {
		"success": true,
		"mode": "shared_public_space_enter",
		"actor_id": actor_id,
		"space_type": clean_type,
		"space_id": clean_space,
		"zone_id": zone_id,
		"presence_summary": presence_summary(clean_type, clean_space, context)
	}
	return last_report.duplicate(true)

func move_actor_to_zone(actor: Person, space_type: String, space_id: String, zone_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	var clean_zone: String = str(zone_id).strip_edges().to_lower()
	if clean_type == "" or clean_space == "" or clean_zone == "":
		return { "success": false, "reason": "Shared public space zone move needs type, id, and zone."}
	var session: Dictionary = _ensure_space_session(clean_type, clean_space, context)
	_remove_actor_from_all_zones(session, int(actor.id))
	_ensure_zone(session, clean_zone)
	_add_actor_to_zone(session, clean_zone, int(actor.id))
	session ["updated_year"] = _current_year()
	session ["updated_at_ms"] = int(Time.get_ticks_msec())
	public_space_sessions [str(session.get("session_key", _space_session_key(clean_type, clean_space)))] = session
	actor_public_space_sessions [str(int(actor.id))] = {
		"space_type": clean_type,
		"space_id": clean_space,
		"zone_id": clean_zone,
		"session_key": str(session.get("session_key", "")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and gs.runtime_contract_engine != null and gs.runtime_contract_engine.has_method("mutate_contract"):
		var contract_id: String = str(session.get("runtime_contract_id", "")).strip_edges()
		if contract_id != "":
			gs.runtime_contract_engine.mutate_contract(contract_id, {
				"type": "actor_zone_changed",
				"actor_id": int(actor.id),
				"zone_id": clean_zone
			}, {
				"source": "shared_public_space_move_zone",
				"space_type": clean_type,
				"space_id": clean_space
			})

	return {
		"success": true,
		"mode": "shared_public_space_move_zone",
		"actor_id": int(actor.id),
		"space_type": clean_type,
		"space_id": clean_space,
		"zone_id": clean_zone,
		"presence_summary": presence_summary(clean_type, clean_space, context)
	}

func exit_space(actor: Person, space_type: String = "", space_id: String = "", _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	var actor_id: int = int(actor.id)
	var actor_key: String = str(actor_id)
	var actor_session: Dictionary = _safe_dictionary(actor_public_space_sessions.get(actor_key, {}))
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	if clean_type == "":
		clean_type = str(actor_session.get("space_type", "")).strip_edges().to_lower()
	if clean_space == "":
		clean_space = str(actor_session.get("space_id", "")).strip_edges()
	if clean_type == "" or clean_space == "":
		actor_public_space_sessions.erase(actor_key)
		return { "success": true, "mode": "shared_public_space_exit_no_session", "actor_id": actor_id}
	var key: String = _space_session_key(clean_type, clean_space)
	var session: Dictionary = _safe_dictionary(public_space_sessions.get(key, {}))
	if not session.is_empty():
		_remove_actor_from_all_zones(session, actor_id)
		session ["updated_year"] = _current_year()
		session ["updated_at_ms"] = int(Time.get_ticks_msec())
		public_space_sessions [key] = session

		if gs != null and gs.runtime_contract_engine != null and gs.runtime_contract_engine.has_method("mutate_contract"):
			var contract_id: String = str(session.get("runtime_contract_id", "")).strip_edges()
			if contract_id != "":
				gs.runtime_contract_engine.mutate_contract(contract_id, {
					"type": "actor_detached",
					"actor_id": actor_id
				}, {
					"source": "shared_public_space_exit",
					"space_type": clean_type,
					"space_id": clean_space
				})

	actor_public_space_sessions.erase(actor_key)
	return {
		"success": true,
		"mode": "shared_public_space_exit",
		"actor_id": actor_id,
		"space_type": clean_type,
		"space_id": clean_space
	}

func presence_summary(space_type: String, space_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	var session: Dictionary = _ensure_space_session(clean_type, clean_space, context)
	var zones: Dictionary = _safe_dictionary(session.get("zones", {}))
	var people_in_building: int = 0
	var zone_counts: Dictionary = {}
	for raw_zone in zones.keys():
		var zone_id: String = str(raw_zone)
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		var count: int = _safe_array(zone.get("actor_ids", [])).size() + _safe_array(zone.get("ambient_people", [])).size()
		zone_counts [zone_id] = count
		people_in_building += count
	return {
		"success": true,
		"space_type": clean_type,
		"space_id": clean_space,
		"people_in_building": people_in_building,
		"zone_counts": zone_counts,
		"session_key": str(session.get("session_key", _space_session_key(clean_type, clean_space)))
	}

func zone_presence_rows(space_type: String, space_id: String, zone_id: String, context: Dictionary = {}) -> Array:
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	var clean_zone: String = str(zone_id).strip_edges().to_lower()
	var session: Dictionary = _ensure_space_session(clean_type, clean_space, context)
	var zones: Dictionary = _safe_dictionary(session.get("zones", {}))
	var zone: Dictionary = _safe_dictionary(zones.get(clean_zone, {}))
	var rows: Array = []
	for raw_id in _safe_array(zone.get("actor_ids", [])):
		var person: Person = _person_from_id(int(raw_id))
		rows.append({
			"id": "actor_%s" % str(raw_id),
			"label": _person_name(person),
			"description": "Present in the %s." % clean_zone.replace("_", " "),
			"kind": "shared_public_space_person",
			"person_id": int(raw_id)
		})
	for raw_ambient in _safe_array(zone.get("ambient_people", [])):
		if typeof(raw_ambient) != TYPE_DICTIONARY:
			continue
		var ambient: Dictionary = raw_ambient as Dictionary
		rows.append({
			"id": str(ambient.get("ambient_id", "ambient")),
			"label": str(ambient.get("name", "Someone nearby")),
			"description": str(ambient.get("description", "Another person sharing the space.")),
			"kind": "shared_public_space_ambient_person",
			"ambient_profile": ambient.duplicate(true)
		})
	return rows

func _ensure_space_session(space_type: String, space_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	var key: String = _space_session_key(clean_type, clean_space)
	var session: Dictionary = _safe_dictionary(public_space_sessions.get(key, {}))
	if not session.is_empty():
		return session

	var runtime_session: Dictionary = _runtime_contract_session_for_space(clean_type, clean_space, context)
	if not runtime_session.is_empty():
		return runtime_session

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("%s|%s|%s|%s" % [clean_type, clean_space, str(_current_year()), str(context.get("seed_salt", "public_space"))])
	var zones: Dictionary = {}
	var zone_ids: Array = _safe_array(context.get("zone_ids", ["lobby", "line", "auditorium", "exit"]))
	for raw_zone in zone_ids:
		var zone_id: String = str(raw_zone).strip_edges().to_lower()
		if zone_id == "":
			continue
		zones [zone_id] = { "actor_ids": [], "ambient_people": []}
	var min_population: int = int(context.get("min_population", 8))
	var max_population: int = int(context.get("max_population", 24))
	if max_population < min_population:
		max_population = min_population
	var target_population: int = int(rng.randi_range(min_population, max_population))
	_seed_ambient_population(zones, target_population, rng, context)
	session = {
		"schema": CONTRACT_SCHEMA + "_session",
		"version": CONTRACT_VERSION,
		"session_key": key,
		"space_type": clean_type,
		"space_id": clean_space,
		"zones": zones,
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	public_space_sessions [key] = session
	return session

func _seed_ambient_population(zones: Dictionary, target_population: int, rng: RandomNumberGenerator, context: Dictionary = {}) -> void:
	var zone_keys: Array = zones.keys()
	if zone_keys.is_empty():
		zones ["lobby"] = { "actor_ids": [], "ambient_people": []}
		zone_keys = ["lobby"]
	var named_candidates: Array = _named_public_candidates(int(context.get("actor_id", -1)))
	var used_ids: Dictionary = {}
	var created: int = 0
	while created < target_population:
		var zone_id: String = str(zone_keys [int(rng.randi_range(0, zone_keys.size() - 1))])
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		if not zone.has("actor_ids"):
			zone ["actor_ids"] = []
		if not zone.has("ambient_people"):
			zone ["ambient_people"] = []
		if created < named_candidates.size():
			var person: Person = named_candidates [created]
			if person != null and not used_ids.has(int(person.id)):
				used_ids [int(person.id)] = true
				var ids: Array = _safe_array(zone.get("actor_ids", []))
				ids.append(int(person.id))
				zone ["actor_ids"] = ids
				zones [zone_id] = zone
				created += 1
				continue
		var ambient: Dictionary = _ambient_person_snapshot(created, rng)
		var ambient_people: Array = _safe_array(zone.get("ambient_people", []))
		ambient_people.append(ambient)
		zone ["ambient_people"] = ambient_people
		zones [zone_id] = zone
		created += 1

func _named_public_candidates(excluded_actor_id: int = -1) -> Array:
	var out: Array = []
	if gs == null or typeof(gs.npcs) != TYPE_ARRAY:
		return out
	for raw_person in gs.npcs:
		if raw_person == null or not (raw_person is Person):
			continue
		var person: Person = raw_person as Person
		if int(person.id) == excluded_actor_id:
			continue
		if not bool(person.alive):
			continue
		out.append(person)
		if out.size() >= 80:
			break
	return out

func _ambient_person_snapshot(index: int, rng: RandomNumberGenerator) -> Dictionary:
	var first_names: Array = ["Avery", "Jordan", "Maya", "Chris", "Taylor", "Sam", "Riley", "Morgan", "Imani", "Devon", "Andre", "Nia"]
	var behaviors: Array = ["waiting with snacks", "checking their phone", "talking quietly", "watching the crowd", "holding a drink", "looking for seats"]
	var name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
	return {
		"ambient_id": "ambient_%d_%d" % [index, int(rng.randi_range(1000, 9999))],
		"name": name,
		"description": str(behaviors [int(rng.randi_range(0, behaviors.size() - 1))]),
		"patience": rng.randf_range(0.15, 0.95),
		"boldness": rng.randf_range(0.1, 0.95),
		"irritability": rng.randf_range(0.05, 0.9)
	}

func _ensure_zone(session: Dictionary, zone_id: String) -> void:
	var clean_zone: String = str(zone_id).strip_edges().to_lower()
	if clean_zone == "":
		return
	var zones: Dictionary = _safe_dictionary(session.get("zones", {}))
	if not zones.has(clean_zone):
		zones [clean_zone] = { "actor_ids": [], "ambient_people": []}
	session ["zones"] = zones

func _add_actor_to_zone(session: Dictionary, zone_id: String, actor_id: int) -> void:
	var zones: Dictionary = _safe_dictionary(session.get("zones", {}))
	var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
	var ids: Array = _safe_array(zone.get("actor_ids", []))
	if not ids.has(actor_id):
		ids.append(actor_id)
	zone ["actor_ids"] = ids
	zones [zone_id] = zone
	session ["zones"] = zones

func _remove_actor_from_all_zones(session: Dictionary, actor_id: int) -> void:
	var zones: Dictionary = _safe_dictionary(session.get("zones", {}))
	for raw_zone in zones.keys():
		var zone_id: String = str(raw_zone)
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		var ids: Array = _safe_array(zone.get("actor_ids", []))
		while ids.has(actor_id):
			ids.erase(actor_id)
		zone ["actor_ids"] = ids
		zones [zone_id] = zone
	session ["zones"] = zones

func _space_session_key(space_type: String, space_id: String) -> String:
	return "%s:%s" % [str(space_type).strip_edges().to_lower(), str(space_id).strip_edges()]

func _actor_from_payload(payload: Dictionary) -> Person:
	if gs == null:
		return null
	var actor_id: int = int(payload.get("actor_id", payload.get("player_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor
	return gs.player

func _person_from_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	return null

func _person_name(person: Person) -> String:
	if person == null:
		return "Someone"
	var full_name: String = "%s %s" % [str(person.first_name), str(person.last_name)]
	full_name = full_name.strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Someone"
	return full_name

func _current_year() -> int:
	if gs != null:
		return int(gs.year)
	return 0

func _stable_seed(material: String) -> int:
	var value: int = int(hash(str(material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)