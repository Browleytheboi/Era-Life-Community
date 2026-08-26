extends Resource
class_name InfamyEngine

const CONTRACT_SCHEMA:= "eralife.infamy_engine_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.infamy_engine_state"
const STATE_KEY:= "infamy_engine_state"
const MAX_INFAMY_LEDGER:= 180

var gs
var active_contract: Dictionary = {}
var last_infamy_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	return {
		"success": true,
		"schema": "eralife.infamy_contract_set_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "infamy_engine.default")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_infamy_report": last_infamy_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "InfamyEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var report_raw: Variant = data.get("last_infamy_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_infamy_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.infamy_import_report",
		"version": CONTRACT_VERSION,
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func become_villain(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var alias_name: String = str(payload.get("alias", "")).strip_edges()
	if alias_name == "":
		alias_name = "%s the Unregistered" % _person_label(actor)

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("infamy_profiles", {}))
	var key: String = str(int(actor.id))

	var profile: Dictionary = _safe_dictionary(profiles.get(key, {}))
	if profile.is_empty():
		profile = {
			"schema": "eralife.infamy_profile",
			"version": CONTRACT_VERSION,
			"person_id": int(actor.id),
			"person_name": _person_label(actor),
			"alias": alias_name,
			"infamy": 0,
			"heat": 0,
			"wanted_level": 0,
			"villain_tier": "street",
			"known_crimes": [],
			"nemesis_ids": [],
			"created_year": _current_year()
		}

	profile ["alias"] = alias_name
	profile ["villain_active"] = true
	profile ["updated_year"] = _current_year()
	profiles [key] = profile
	state ["infamy_profiles"] = profiles

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.villain_identity_report",
		"person_id": int(actor.id),
		"alias": alias_name,
		"text": "You stop pretending this is hero work. A villain identity wakes up.",
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_infamy_event(report)
	_commit_world_state(state)
	return report

func record_infamy(actor: Person, amount: int, reason: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("infamy_profiles", {}))
	var key: String = str(int(actor.id))
	var profile: Dictionary = _safe_dictionary(profiles.get(key, {}))

	if profile.is_empty():
		become_villain(actor, {})
		state = _world_state()
		profiles = _safe_dictionary(state.get("infamy_profiles", {}))
		profile = _safe_dictionary(profiles.get(key, {}))

	profile ["infamy"] = max(0, int(profile.get("infamy", 0)) + amount)
	profile ["heat"] = clamp(int(profile.get("heat", 0)) + max(1, int(amount / 2.0)), 0, 100)
	profile ["wanted_level"] = clamp(int(ceil(float(profile.get("heat", 0)) / 20.0)), 0, 5)
	profile ["villain_tier"] = _villain_tier(int(profile.get("infamy", 0)))

	var known_crimes: Array = _safe_array(profile.get("known_crimes", []))
	known_crimes.append({
		"reason": reason,
		"amount": amount,
		"context": context.duplicate(true),
		"year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	profile ["known_crimes"] = known_crimes

	profiles [key] = profile
	state ["infamy_profiles"] = profiles

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.infamy_record_report",
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"infamy": int(profile.get("infamy", 0)),
		"heat": int(profile.get("heat", 0)),
		"wanted_level": int(profile.get("wanted_level", 0)),
		"villain_tier": str(profile.get("villain_tier", "street")),
		"reason": reason,
		"context": context.duplicate(true),
		"text": "Infamy rises. People are starting to say your name differently."
	}

	_record_infamy_event(report)
	_commit_world_state(state)
	return report

func resolve_villain_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var action: String = str(payload.get("action", "")).strip_edges().to_lower()

	match action:
		"become_villain":
			return become_villain(actor, payload)
		"commit_super_crime":
			return record_infamy(actor, int(payload.get("amount", 12)), "super_crime", payload)
		_:
			return {
				"success": false,
				"reason": "Unknown villain action.",
				"action": action
			}

func get_infamy_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("infamy_profiles", {}))
	var profile: Dictionary = _safe_dictionary(profiles.get(str(int(actor.id)), {}))

	if profile.is_empty():
		return [
			{
				"label": "No villain identity",
				"description": "You can still choose the villain route, but the world has not learned to fear you yet.",
				"actions": [
					{
						"id": "infamy_become_villain",
						"label": "Become A Villain",
						"kind": "engine_call",
						"engine_property": "infamy_engine",
						"method": "resolve_villain_action",
						"call_mode": "player_payload",
						"payload": {
							"action": "become_villain"
						},
						"refresh_after": true
					}
				]
			}
		]

	return [
		{
			"label": "%s • Infamy %d • Heat %d • Wanted %d★" % [
				str(profile.get("alias", "Unknown Villain")),
				int(profile.get("infamy", 0)),
				int(profile.get("heat", 0)),
				int(profile.get("wanted_level", 0))
			],
			"description": "Tier: %s" % str(profile.get("villain_tier", "street")).capitalize(),
			"actions": [
				{
					"id": "infamy_commit_super_crime",
					"label": "Commit Super Crime",
					"kind": "engine_call",
					"engine_property": "infamy_engine",
					"method": "resolve_villain_action",
					"call_mode": "player_payload",
					"payload": {
						"action": "commit_super_crime",
						"amount": 14
					},
					"refresh_after": true
				}
			]
		}
	]

func yearly_tick(_payload:= {}) -> Dictionary:
	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("infamy_profiles", {}))

	for raw_key in profiles.keys():
		var profile: Dictionary = _safe_dictionary(profiles.get(raw_key, {}))
		profile ["heat"] = max(0, int(profile.get("heat", 0)) - 8)
		profile ["wanted_level"] = clamp(int(ceil(float(profile.get("heat", 0)) / 20.0)), 0, 5)
		profiles [raw_key] = profile

	state ["infamy_profiles"] = profiles
	state ["last_yearly_tick_report"] = {
		"success": true,
		"year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)
	return state ["last_yearly_tick_report"].duplicate(true)

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "infamy_engine.default",
		"heat_policy": {
			"yearly_decay": 8,
			"wanted_star_heat_interval": 20,
			"max_wanted_level": 5
		}
	}

func _villain_tier(infamy: int) -> String:
	if infamy >= 250:
		return "world_threat"
	if infamy >= 140:
		return "archvillain"
	if infamy >= 70:
		return "city_menace"
	if infamy >= 25:
		return "known_threat"
	return "street"

func _context_actor(context: Dictionary = {}) -> Person:
	if gs != null and gs.player != null:
		return gs.player
	var actor_id: int = int(context.get("player_id", context.get("actor_id", -1)))
	if actor_id > 0 and gs != null and gs.has_method("get_or_reactivate_npc_by_id"):
		var actor = gs.get_or_reactivate_npc_by_id(actor_id)
		if actor is Person:
			return actor
	return null

func _record_infamy_event(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("infamy_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_INFAMY_LEDGER:
		ledger.pop_front()
	state ["infamy_ledger"] = ledger
	state ["last_infamy_report"] = report.duplicate(true)
	last_infamy_report = report.duplicate(true)
	_commit_world_state(state)

func _world_state() -> Dictionary:
	if gs == null:
		return _normalize_state({})
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var raw: Variant = gs.scenario_state.get(STATE_KEY, {})
	var state: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		state = (raw as Dictionary).duplicate(true)
	state = _normalize_state(state)
	gs.scenario_state [STATE_KEY] = state
	return state

func _normalize_state(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out ["schema"] = str(out.get("schema", STATE_SCHEMA))
	out ["version"] = max(CONTRACT_VERSION, int(out.get("version", 1)))
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))

	if typeof(out.get("infamy_profiles", {})) != TYPE_DICTIONARY:
		out ["infamy_profiles"] = {}
	if typeof(out.get("infamy_ledger", [])) != TYPE_ARRAY:
		out ["infamy_ledger"] = []

	return out

func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	if actor.has_method("full_name"):
		return str(actor.full_name())
	return "Person %d" % int(actor.id)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var incoming: Variant = overlay.get(key)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(_safe_dictionary(out.get(key, {})), _safe_dictionary(incoming))
		elif typeof(incoming) == TYPE_DICTIONARY:
			out [key] = _safe_dictionary(incoming)
		elif typeof(incoming) == TYPE_ARRAY:
			out [key] = (incoming as Array).duplicate(true)
		else:
			out [key] = incoming
	return out