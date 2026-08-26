extends Resource
class_name RealitySurgeEngine

const CONTRACT_SCHEMA:= "eralife.reality_surge_engine_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.reality_surge_engine_state"
const STATE_KEY:= "reality_surge_engine_state"
const MAX_SURGE_LEDGER_SIZE:= 160
const MAX_PENDING_UI_SURGES:= 12

var gs
var active_contract: Dictionary = {}
var contract_registry: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_surge_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)
	_bootstrap_contract_registry()
	last_contract_report = {
		"schema": "eralife.reality_surge_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "reality_surge_engine.default")),
		"registered_contract_count": contract_registry.size(),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)

func bootstrap_default_contracts() -> Dictionary:
	_bootstrap_contract_registry()
	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	_commit_world_state(state)
	return {
		"success": true,
		"schema": "eralife.reality_surge_bootstrap_report",
		"version": CONTRACT_VERSION,
		"contract_count": contract_registry.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"contract_registry": contract_registry.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_surge_report": last_surge_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "RealitySurgeEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var registry_raw: Variant = data.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		contract_registry = (registry_raw as Dictionary).duplicate(true)
	else:
		contract_registry = {}

	_bootstrap_contract_registry()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY and not (world_state_raw as Dictionary).is_empty():
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	var surge_report_raw: Variant = data.get("last_surge_report", {})
	if typeof(surge_report_raw) == TYPE_DICTIONARY:
		last_surge_report = (surge_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"contract_count": contract_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func yearly_tick(_payload:= {}) -> void:
	var state: Dictionary = _world_state()
	var active_echoes: Dictionary = _safe_dictionary(state.get("active_stat_echoes", {}))
	var now_ms: int = int(Time.get_ticks_msec())
	var removed: int = 0

	for key in active_echoes.keys():
		var row: Dictionary = _safe_dictionary(active_echoes.get(key, {}))
		if int(row.get("expires_at_ms", 0)) > 0 and int(row.get("expires_at_ms", 0)) <= now_ms:
			active_echoes.erase(key)
			removed += 1

	state ["active_stat_echoes"] = active_echoes
	state ["last_yearly_tick_report"] = {
		"schema": "eralife.reality_surge_yearly_tick_report",
		"version": CONTRACT_VERSION,
		"removed_expired_stat_echoes": removed,
		"updated_at_ms": now_ms
	}
	_commit_world_state(state)

func register_surge_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {
			"success": false,
			"reason": "Reality surge contract missing."
		}

	var normalized: Dictionary = _normalize_surge_contract(contract)
	var contract_id: String = str(normalized.get("id", "")).strip_edges()
	if contract_id == "":
		return {
			"success": false,
			"reason": "Reality surge contract id missing."
		}

	contract_registry [contract_id] = normalized.duplicate(true)

	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	_commit_world_state(state)

	return {
		"success": true,
		"contract_id": contract_id,
		"domain": str(normalized.get("domain", "generic")),
		"registered_at_ms": int(Time.get_ticks_msec())
	}

func trigger_surge(contract_id: String, actor: Person, event_payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var resolved_contract: Dictionary = _resolve_contract(contract_id)
	if resolved_contract.is_empty():
		return {
			"success": false,
			"reason": "No matching reality surge contract.",
			"contract_id": contract_id
		}

	var salience: float = _resolve_salience(resolved_contract, event_payload, context)
	var threshold: Dictionary = _safe_dictionary(_safe_dictionary(resolved_contract.get("trigger", {})).get("threshold", {}))
	var salience_min: float = float(threshold.get("salience_min", 0.0))
	if salience < salience_min and not bool(context.get("force", false)):
		return {
			"success": false,
			"reason": "Reality surge salience below threshold.",
			"contract_id": str(resolved_contract.get("id", contract_id)),
			"salience": salience,
			"salience_min": salience_min
		}

	var duplicate_key: String = _surge_duplicate_key(resolved_contract, actor, event_payload, context)
	if _recent_duplicate_exists(duplicate_key, int(context.get("duplicate_window_ms", 1800))):
		return {
			"success": false,
			"reason": "Duplicate reality surge suppressed.",
			"contract_id": str(resolved_contract.get("id", contract_id)),
			"duplicate_key": duplicate_key
		}

	var visual_layer: Dictionary = _safe_dictionary(resolved_contract.get("visual_layer", {}))
	var perception_layer: Dictionary = _safe_dictionary(resolved_contract.get("perception_layer", {}))
	var reward_manifestation: Dictionary = _resolve_reward_manifestation(resolved_contract, actor, event_payload, context)
	var stat_echo: Dictionary = _apply_stat_echo(actor, resolved_contract, event_payload, context)
	var theme: Dictionary = _resolve_theme(actor, resolved_contract, event_payload, context)
	var stability: Dictionary = _safe_dictionary(resolved_contract.get("stability", {}))

	var surge_id: String = "%s_%d_%d" % [
		str(resolved_contract.get("id", "reality_surge")).replace(".", "_"),
		int(actor.id),
		int(Time.get_ticks_msec())
	]

	var report: Dictionary = {
		"schema": "eralife.reality_surge_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"surge_id": surge_id,
		"contract_id": str(resolved_contract.get("id", contract_id)),
		"domain": str(resolved_contract.get("domain", event_payload.get("domain", "generic"))),
		"event_name": str(event_payload.get("event_name", context.get("event_name", ""))),
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"actor_is_player": _actor_is_player(actor),
		"salience": salience,
		"surge_profile": _safe_dictionary(resolved_contract.get("surge_profile", {})),
		"theme": theme.duplicate(true),
		"visual_layer": visual_layer.duplicate(true),
		"perception_layer": perception_layer.duplicate(true),
		"reward_manifestation": reward_manifestation.duplicate(true),
		"stat_echo": stat_echo.duplicate(true),
		"stability": stability.duplicate(true),
		"event_payload": event_payload.duplicate(true),
		"context": context.duplicate(true),
		"duplicate_key": duplicate_key,
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("surge_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_SURGE_LEDGER_SIZE:
		ledger.pop_front()
	state ["surge_ledger"] = ledger
	state ["last_surge_report"] = report.duplicate(true)

	if _actor_is_player(actor):
		var pending: Array = _safe_array(state.get("pending_ui_surges", []))
		pending.append(report.duplicate(true))
		while pending.size() > MAX_PENDING_UI_SURGES:
			pending.pop_front()
		state ["pending_ui_surges"] = pending

	_commit_world_state(state)
	last_surge_report = report.duplicate(true)
	_emit_reality_surge_event(report)

	return report.duplicate(true)

func on_competitive_match_completed(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	_bootstrap_contract_registry()

	for key in contract_registry.keys():
		var contract: Dictionary = _safe_dictionary(contract_registry.get(key, {}))
		if contract.is_empty():
			continue
		if not _event_matches_contract(payload, contract):
			continue

		var winner_id: int = int(payload.get("winner_id", payload.get("npc_id", -1)))
		var actor: Person = _person_by_id(winner_id)
		if actor == null:
			continue

		trigger_surge(str(contract.get("id", key)), actor, payload, {
			"source": "competitive_match_completed",
			"duplicate_window_ms": 1800
		})

func consume_pending_ui_surges() -> Array:
	var state: Dictionary = _world_state()
	var pending: Array = _safe_array(state.get("pending_ui_surges", []))
	state ["pending_ui_surges"] = []
	_commit_world_state(state)
	return pending

func get_active_stat_echo(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	var state: Dictionary = _world_state()
	var active_echoes: Dictionary = _safe_dictionary(state.get("active_stat_echoes", {}))
	var key: String = str(int(actor.id))
	var row: Dictionary = _safe_dictionary(active_echoes.get(key, {}))
	if row.is_empty():
		return {}
	if int(row.get("expires_at_ms", 0)) > 0 and int(row.get("expires_at_ms", 0)) <= int(Time.get_ticks_msec()):
		active_echoes.erase(key)
		state ["active_stat_echoes"] = active_echoes
		_commit_world_state(state)
		return {}
	return row.duplicate(true)

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "reality_surge_engine.default",
		"runtime_policy": {
			"emit_event_bus": true,
		},
		"surge_contracts": [
			{
				"schema": "eralife.reality_surge_contract",
				"version": CONTRACT_VERSION,
				"id": "bending.championship.surge",
				"domain": "bending",
				"display_name": "Bending Championship Reality Surge",
				"trigger": {
					"event": "competitive.match.completed",
					"filters": {
						"domain": "bending",
						"championship": true,
					},
					"threshold": {
						"salience_min": 85.0
					}
				},
				"surge_profile": {
					"type": ["elemental_resonance", "competitive_legacy"],
					"intensity": 0.92
				},
				"visual_layer": {
					"theme_resolver": "elemental_affinity_resolver",
					"shader_profile": "elemental_surge",
					"distortion": true,
					"particles": true,
				},
				"perception_layer": {
					"time_dilation": 0.85,
					"input_lock_ms": 1200,
					"camera_weight": 0.3,
					"audio_muffle": 0.6
				},
				"reward_manifestation": {
					"animate_to_inventory": true,
					"object_type": "trophy",
					"target_ui": "belongings_button",
					"spawn_effect": "materialize_from_energy",
					"category": "Trophies"
				},
				"stat_echo": {
					"temporary_boost": {
						"willpower": 12
					},
					"duration_ms": 2500,
					"decay_curve": "ease_out"
				},
				"stability": {
					"instability_gain": 0.15,
					"mutation_chance": 0.02
				}
			},
			{
				"schema": "eralife.reality_surge_contract",
				"version": CONTRACT_VERSION,
				"id": "agni_kai.championship.surge",
				"domain": "bending",
				"display_name": "Agni Kai Reality Surge",
				"trigger": {
					"event": "competitive.match.completed",
					"filters": {
						"domain": "bending",
						"division": "agni_kai",
						"championship": true,
					},
					"threshold": {
						"salience_min": 80.0
					}
				},
				"surge_profile": {
					"type": ["elemental_resonance", "national_legacy", "fire_supremacy"],
					"intensity": 0.96
				},
				"visual_layer": {
					"theme_resolver": "elemental_affinity_resolver",
					"shader_profile": "elemental_surge_fire",
					"distortion": true,
					"particles": true,
				},
				"perception_layer": {
					"time_dilation": 0.82,
					"input_lock_ms": 1350,
					"camera_weight": 0.36,
					"audio_muffle": 0.55
				},
				"reward_manifestation": {
					"animate_to_inventory": true,
					"object_type": "trophy",
					"target_ui": "belongings_button",
					"spawn_effect": "materialize_from_energy",
					"category": "Trophies"
				},
				"stat_echo": {
					"temporary_boost": {
						"willpower": 14
					},
					"duration_ms": 2800,
					"decay_curve": "ease_out"
				},
				"stability": {
					"instability_gain": 0.18,
					"mutation_chance": 0.025
				}
			}
		]
	}

func _bootstrap_contract_registry() -> void:
	if typeof(contract_registry) != TYPE_DICTIONARY:
		contract_registry = {}

	var contracts: Array = _safe_array(active_contract.get("surge_contracts", []))
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_surge_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges()
		if contract_id == "":
			continue
		if not contract_registry.has(contract_id):
			contract_registry [contract_id] = normalized.duplicate(true)

func _normalize_surge_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.reality_surge_contract"))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", "generic.reality_surge")).strip_edges()
	out ["domain"] = str(out.get("domain", "generic")).strip_edges().to_lower()
	out ["display_name"] = str(out.get("display_name", out.get("id", "Reality Surge")))
	if typeof(out.get("trigger", {})) != TYPE_DICTIONARY:
		out ["trigger"] = {}
	if typeof(out.get("visual_layer", {})) != TYPE_DICTIONARY:
		out ["visual_layer"] = {}
	if typeof(out.get("perception_layer", {})) != TYPE_DICTIONARY:
		out ["perception_layer"] = {}
	if typeof(out.get("reward_manifestation", {})) != TYPE_DICTIONARY:
		out ["reward_manifestation"] = {}
	if typeof(out.get("stat_echo", {})) != TYPE_DICTIONARY:
		out ["stat_echo"] = {}
	if typeof(out.get("stability", {})) != TYPE_DICTIONARY:
		out ["stability"] = {}
	return out

func _resolve_contract(contract_id: String) -> Dictionary:
	_bootstrap_contract_registry()
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id != "" and contract_registry.has(clean_id):
		return _safe_dictionary(contract_registry.get(clean_id, {}))
	return {}

func _event_matches_contract(payload: Dictionary, contract: Dictionary) -> bool:
	var trigger: Dictionary = _safe_dictionary(contract.get("trigger", {}))
	var expected_event: String = str(trigger.get("event", "")).strip_edges()
	if expected_event != "":
		var event_name: String = str(payload.get("event_name", payload.get("event_type", ""))).strip_edges()
		if event_name == "":
			event_name = expected_event
		if event_name != expected_event:
			return false

	var filters: Dictionary = _safe_dictionary(trigger.get("filters", {}))
	for raw_key in filters.keys():
		var key: String = str(raw_key)
		var expected: Variant = filters.get(raw_key)
		var actual: Variant = _payload_filter_value(payload, key)
		if not _filter_value_matches(actual, expected):
			return false

	var threshold: Dictionary = _safe_dictionary(trigger.get("threshold", {}))
	var salience_min: float = float(threshold.get("salience_min", 0.0))
	if salience_min > 0.0:
		var salience: float = _resolve_salience(contract, payload, {})
		if salience < salience_min:
			return false

	return true

func _payload_filter_value(payload: Dictionary, key: String) -> Variant:
	var clean_key: String = str(key).strip_edges()
	if clean_key == "winner_is_player":
		var actor: Person = _person_by_id(int(payload.get("winner_id", payload.get("npc_id", -1))))
		return _actor_is_player(actor)
	if clean_key == "actor_is_player":
		var actor_id: int = int(payload.get("actor_id", payload.get("person_id", payload.get("npc_id", payload.get("winner_id", -1)))))
		var actor: Person = _person_by_id(actor_id)
		return _actor_is_player(actor)
	if clean_key.find(".") >= 0:
		return _read_payload_path(payload, clean_key)
	return payload.get(clean_key, "")

func _filter_value_matches(actual: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_ARRAY:
		for raw_expected in expected:
			if _filter_value_matches(actual, raw_expected):
				return true
		return false
	if typeof(expected) == TYPE_BOOL:
		return bool(actual) == bool(expected)
	if typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		return float(actual) == float(expected)
	return str(actual).strip_edges().to_lower() == str(expected).strip_edges().to_lower()

func _read_payload_path(payload: Dictionary, path: String) -> Variant:
	var pieces: PackedStringArray = str(path).split(".")
	var current: Variant = payload
	for piece in pieces:
		if typeof(current) != TYPE_DICTIONARY:
			return null
		current = (current as Dictionary).get(str(piece), null)
	return current

func _resolve_salience(contract: Dictionary, event_payload: Dictionary, context: Dictionary = {}) -> float:
	if context.has("salience"):
		return clamp(float(context.get("salience", 0.0)), 0.0, 100.0)
	if event_payload.has("salience"):
		return clamp(float(event_payload.get("salience", 0.0)), 0.0, 100.0)

	var media: Dictionary = _safe_dictionary(event_payload.get("media", {}))
	if media.has("reaction_score"):
		return clamp(float(media.get("reaction_score", 0.0)), 0.0, 100.0)

	var audience: Dictionary = _safe_dictionary(event_payload.get("audience", {}))
	if audience.has("reaction_score"):
		return clamp(float(audience.get("reaction_score", 0.0)), 0.0, 100.0)

	if bool(event_payload.get("championship", false)) and _filter_value_matches(_payload_filter_value(event_payload, "winner_is_player"), true):
		return 100.0

	var surge_profile: Dictionary = _safe_dictionary(contract.get("surge_profile", {}))
	return clamp(float(surge_profile.get("intensity", 0.5)) * 100.0, 0.0, 100.0)

func _resolve_theme(actor: Person, contract: Dictionary, event_payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var element: String = str(context.get("element", event_payload.get("element", ""))).strip_edges().to_lower()
	if element == "":
		element = _actor_element(actor)

	var is_avatar: bool = actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar"
	var theme_id: String = "avatar" if is_avatar else element
	if theme_id == "":
		theme_id = "generic"

	var profile: Dictionary = {
		"schema": "eralife.reality_surge_theme",
		"version": CONTRACT_VERSION,
		"theme_id": theme_id,
		"element": element,
		"is_avatar": is_avatar,
		"resolver": str(_safe_dictionary(contract.get("visual_layer", {})).get("theme_resolver", "default"))
	}

	match theme_id:
		"fire":
			profile ["motion"] = "pulsing_ember_heat_distortion"
			profile ["primary_color"] = "ember"
			profile ["secondary_color"] = "gold"
		"water":
			profile ["motion"] = "flowing_border_ripple"
			profile ["primary_color"] = "water"
			profile ["secondary_color"] = "moon"
		"earth":
			profile ["motion"] = "grounded_heavy_dust_pulse"
			profile ["primary_color"] = "stone"
			profile ["secondary_color"] = "jade"
		"air":
			profile ["motion"] = "light_flicker_drifting_particles"
			profile ["primary_color"] = "air"
			profile ["secondary_color"] = "sky"
		"avatar":
			profile ["motion"] = "cycling_elemental_spectrum"
			profile ["primary_color"] = "avatar_spectrum"
			profile ["secondary_color"] = "cosmic_white"
			profile ["element_cycle"] = ["fire", "water", "earth", "air"]
		_:
			profile ["motion"] = "reality_pulse"
			profile ["primary_color"] = "gold"
			profile ["secondary_color"] = "white"

	return profile

func _resolve_reward_manifestation(contract: Dictionary, actor: Person, event_payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var reward: Dictionary = _safe_dictionary(contract.get("reward_manifestation", {}))
	var reward_item: Dictionary = _safe_dictionary(context.get("reward_item", event_payload.get("reward_item", {})))
	var trophy_report: Dictionary = _safe_dictionary(context.get("trophy_report", event_payload.get("trophy_report", {})))

	if reward_item.is_empty():
		reward_item = _safe_dictionary(trophy_report.get("item", {}))

	reward ["actor_id"] = int(actor.id) if actor != null else -1
	reward ["actor_name"] = _person_label(actor)
	reward ["item"] = reward_item.duplicate(true)
	reward ["item_name"] = str(reward_item.get("display_name", reward_item.get("name", reward.get("object_type", "Reward"))))
	reward ["manifested_existing_item"] = not reward_item.is_empty()
	reward ["category"] = str(reward.get("category", trophy_report.get("category", "Trophies")))

	return reward

func _apply_stat_echo(actor: Person, contract: Dictionary, event_payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var stat_echo: Dictionary = _safe_dictionary(contract.get("stat_echo", {}))
	var temporary_boost: Dictionary = _safe_dictionary(stat_echo.get("temporary_boost", {}))
	if actor == null or temporary_boost.is_empty():
		return {}

	var duration_ms: int = int(stat_echo.get("duration_ms", 0))
	var now_ms: int = int(Time.get_ticks_msec())
	var expires_at_ms: int = now_ms + max(0, duration_ms)

	var row: Dictionary = {
		"schema": "eralife.reality_surge_stat_echo",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"temporary_boost": temporary_boost.duplicate(true),
		"duration_ms": duration_ms,
		"decay_curve": str(stat_echo.get("decay_curve", "ease_out")),
		"source_contract_id": str(contract.get("id", "")),
		"event_name": str(event_payload.get("event_name", context.get("event_name", ""))),
		"started_at_ms": now_ms,
		"expires_at_ms": expires_at_ms
	}

	var state: Dictionary = _world_state()
	var active_echoes: Dictionary = _safe_dictionary(state.get("active_stat_echoes", {}))
	active_echoes [str(int(actor.id))] = row.duplicate(true)
	state ["active_stat_echoes"] = active_echoes
	_commit_world_state(state)

	return row

func _surge_duplicate_key(contract: Dictionary, actor: Person, event_payload: Dictionary, context: Dictionary = {}) -> String:
	var event_key: String = str(event_payload.get("event_uid", event_payload.get("match_id", event_payload.get("tournament_id", context.get("tournament_id", ""))))).strip_edges()
	if event_key == "":
		event_key = "%s:%s:%d" % [
			str(event_payload.get("event_name", context.get("event_name", ""))),
			str(event_payload.get("division", context.get("division", ""))),
			_current_year()
		]
	return "%s|%d|%s" % [
		str(contract.get("id", "")),
		int(actor.id) if actor != null else -1,
		event_key
	]

func _recent_duplicate_exists(duplicate_key: String, window_ms: int) -> bool:
	if duplicate_key.strip_edges() == "":
		return false

	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("surge_ledger", []))
	var now_ms: int = int(Time.get_ticks_msec())

	for raw_row in ledger:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if str(row.get("duplicate_key", "")) != duplicate_key:
			continue
		if now_ms - int(row.get("created_at_ms", 0)) <= max(0, window_ms):
			return true

	return false

func _actor_element(actor: Person) -> String:
	if actor == null:
		return ""

	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type in ["fire", "water", "earth", "air", "avatar"]:
		if bending_type == "avatar":
			return "avatar"
		return bending_type

	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		var best_element: String = ""
		var best_value: int = -1
		for element in ["fire", "water", "earth", "air"]:
			var value: int = int(actor.bending_mastery.get(element, 0))
			if value > best_value:
				best_value = value
				best_element = element
		if best_value > 0:
			return best_element

	return ""

func _emit_reality_surge_event(report: Dictionary) -> void:
	if gs == null or gs.event_bus == null:
		return
	if not bool(_safe_dictionary(active_contract.get("runtime_policy", {})).get("emit_event_bus", true)):
		return
	gs.event_bus.emit("reality.surge.triggered", report)

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
	if typeof(out.get("contract_registry", {})) != TYPE_DICTIONARY:
		out ["contract_registry"] = {}
	if typeof(out.get("surge_ledger", [])) != TYPE_ARRAY:
		out ["surge_ledger"] = []
	if typeof(out.get("pending_ui_surges", [])) != TYPE_ARRAY:
		out ["pending_ui_surges"] = []
	if typeof(out.get("active_stat_echoes", {})) != TYPE_DICTIONARY:
		out ["active_stat_echoes"] = {}
	if typeof(out.get("last_surge_report", {})) != TYPE_DICTIONARY:
		out ["last_surge_report"] = {}
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

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for npc in gs.npcs:
			if npc != null and int(npc.id) == person_id:
				return npc
	return null

func _actor_is_player(actor: Person) -> bool:
	return gs != null and actor != null and gs.player != null and int(actor.id) == int(gs.player.id)

func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	var label: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if label == "":
		label = str(actor.name).strip_edges()
	if label == "":
		label = "Person %d" % int(actor.id)
	return label

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