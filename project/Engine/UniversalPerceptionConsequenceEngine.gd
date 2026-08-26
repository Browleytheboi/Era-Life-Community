extends Resource
class_name UniversalPerceptionConsequenceEngine

const CONTRACT_SCHEMA:= "eralife.upce_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.upce_state"
const STATE_KEY:= "upce_state"
const MAX_INTERPRETATION_LEDGER:= 260
const MAX_PENDING_UI_INTERPRETATIONS:= 8

var gs
var active_contract: Dictionary = {}
var interpretation_contract_registry: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_interpretation_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	_bootstrap_contract_registry()

	last_contract_report = {
		"schema": "eralife.upce_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "upce.default")),
		"registered_contract_count": interpretation_contract_registry.size(),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_contract_report.duplicate(true)

func bootstrap_default_contracts() -> Dictionary:
	_bootstrap_contract_registry()

	var state: Dictionary = _world_state()
	state ["contract_registry"] = interpretation_contract_registry.duplicate(true)
	_commit_world_state(state)

	return {
		"schema": "eralife.upce_bootstrap_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_count": interpretation_contract_registry.size(),
		"bootstrapped_at_ms": int(Time.get_ticks_msec())
	}

func export_contract() -> Dictionary:
	return active_contract.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"contract_registry": interpretation_contract_registry.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_interpretation_report": last_interpretation_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "UniversalPerceptionConsequenceEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var registry_raw: Variant = data.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		interpretation_contract_registry = (registry_raw as Dictionary).duplicate(true)
	else:
		interpretation_contract_registry = {}

	_bootstrap_contract_registry()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	var interpretation_raw: Variant = data.get("last_interpretation_report", {})
	if typeof(interpretation_raw) == TYPE_DICTIONARY:
		last_interpretation_report = (interpretation_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.upce_import_report",
		"version": CONTRACT_VERSION,
		"contract_count": interpretation_contract_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func register_interpretation_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {
			"success": false,
			"reason": "UPCE interpretation contract missing."
		}

	var normalized: Dictionary = _normalize_interpretation_contract(contract)
	var contract_id: String = str(normalized.get("id", "")).strip_edges()

	if contract_id == "":
		return {
			"success": false,
			"reason": "UPCE interpretation contract id missing."
		}

	interpretation_contract_registry [contract_id] = normalized.duplicate(true)

	var state: Dictionary = _world_state()
	state ["contract_registry"] = interpretation_contract_registry.duplicate(true)
	_commit_world_state(state)

	return {
		"success": true,
		"contract_id": contract_id,
		"registered_at_ms": int(Time.get_ticks_msec())
	}

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return {
			"success": false,
			"reason": "UPCE received an empty command envelope."
		}

	var payload: Dictionary = {}
	var payload_raw: Variant = envelope.get("event_payload", envelope)
	if typeof(payload_raw) == TYPE_DICTIONARY:
		payload = (payload_raw as Dictionary).duplicate(true)
	else:
		payload = envelope.duplicate(true)

	var context: Dictionary = {}
	var context_raw: Variant = envelope.get("context", {})
	if typeof(context_raw) == TYPE_DICTIONARY:
		context = (context_raw as Dictionary).duplicate(true)

	context ["source"] = str(context.get("source", envelope.get("source", "route_command_envelope")))
	context ["command_id"] = str(envelope.get("id", envelope.get("command", "upce.interpret_event")))

	return interpret_event(payload, context)

func on_event_from_bus(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	interpret_event(payload, {
		"source": "event_bus",
		"event_name": str(payload.get("event_name", payload.get("event_type", "")))
	})

func interpret_event(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(payload) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "UPCE interpret_event expected Dictionary payload."
		}

	var event: Dictionary = _normalize_event(payload, context)
	var contract: Dictionary = _resolve_contract_for_event(event)
	var actor: Person = _person_by_id(int(event.get("actor_id", -1)))
	var target: Person = _person_by_id(int(event.get("target_id", -1)))
	var other: Person = _person_by_id(int(event.get("other_person_id", -1)))

	var classification: Dictionary = _resolve_classification(event, contract)
	var channels: Array = _resolve_channels(event, contract, classification)
	var witness_people: Array = _resolve_witnesses(event, actor, target, other)
	var observations: Array = _build_observations(event, contract, classification, channels, actor, target, other, witness_people)
	var visible_consequences: Array = _apply_consequences(event, contract, classification, actor, target, other, observations)
	var future_hooks: Array = _build_future_hooks(event, contract, classification, channels, actor, target, other, observations)
	var clear_narrative: String = _build_clear_narrative(event, classification, channels, actor, target, observations)
	var myth_packet: Dictionary = _build_myth_packet(event, contract, classification, channels, actor, observations)

	var report_id: String = "upce_%s_%d" % [
		str(event.get("event_id", event.get("event_name", "event"))).replace(".", "_").replace(" ", "_"),
		int(Time.get_ticks_msec())
	]

	var report: Dictionary = {
		"schema": "eralife.upce_interpretation",
		"version": CONTRACT_VERSION,
		"success": true,
		"interpretation_id": report_id,
		"contract_id": str(contract.get("id", "social.generic.default")),
		"event": event.duplicate(true),
		"event_name": str(event.get("event_name", "")),
		"actor_id": int(event.get("actor_id", -1)),
		"target_id": int(event.get("target_id", -1)),
		"classification": classification.duplicate(true),
		"perception_channels": channels.duplicate(true),
		"observations": observations.duplicate(true),
		"clear_narrative": clear_narrative,
		"player_narrative": _player_narrative_from_observations(observations, clear_narrative),
		"visible_consequences": visible_consequences.duplicate(true),
		"future_hooks": future_hooks.duplicate(true),
		"myth_packet": myth_packet.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_report(report)
	_commit_observer_memories(report, actor, target, other)
	_seed_world_feed(report, actor, target)
	_queue_future_hooks(report)
	_queue_player_ui_interpretation(report)
	_emit_interpretation_event(report)

	last_interpretation_report = report.duplicate(true)
	return report.duplicate(true)

func consume_pending_ui_interpretations() -> Array:
	var state: Dictionary = _world_state()
	var pending: Array = _safe_array(state.get("pending_ui_interpretations", []))
	state ["pending_ui_interpretations"] = []
	_commit_world_state(state)
	return pending

func get_last_interpretation_report() -> Dictionary:
	return last_interpretation_report.duplicate(true)

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "upce.default",
		"runtime_policy": {
			"emit_event_bus": true,
			"queue_player_ui_interpretations": true,
			"write_life_diary": true,
			"write_world_feed": true,
		},
		"bias_profiles": {
			"default": {
				"fear_bias": 0.0,
				"trust_bias": 0.0,
				"distortion_bias": 0.0,
				"myth_bias": 0.0
			},
			"trusting": {
				"fear_bias": -0.12,
				"trust_bias": 0.24,
				"distortion_bias": -0.08,
				"myth_bias": 0.05
			},
			"paranoid": {
				"fear_bias": 0.32,
				"trust_bias": -0.35,
				"distortion_bias": 0.28,
				"myth_bias": 0.16
			},
			"religious": {
				"fear_bias": 0.08,
				"trust_bias": 0.02,
				"distortion_bias": 0.12,
				"myth_bias": 0.34,
				"supernatural_frame": "divine"
			},
			"religious_extremist": {
				"fear_bias": 0.22,
				"trust_bias": -0.18,
				"distortion_bias": 0.22,
				"myth_bias": 0.48,
				"supernatural_frame": "divine_judgment"
			},
			"scientific": {
				"fear_bias": -0.04,
				"trust_bias": 0.06,
				"distortion_bias": -0.18,
				"myth_bias": -0.18,
				"supernatural_frame": "mutation"
			},
			"emotional": {
				"fear_bias": 0.12,
				"trust_bias": -0.05,
				"distortion_bias": 0.18,
				"myth_bias": 0.08
			}
		},
		"interpretation_contracts": [
			{
				"id": "social.cheating.default",
				"event_match": ["npc_cheated", "romance_betrayal", "relationship.cheating", "cheating"],
				"classification": {
					"social": true,
					"betrayal": true,
					"intimate": true,
					"public": false,
					"violent": false,
					"supernatural": false,
					"intent": "selfish",
					"lethality": "none",
					"moral_weight": 72.0
				},
				"channels": ["direct_target", "family", "rumor"],
				"relationship_deltas": {
					"target": -42,
					"partner": -55,
					"children": -18,
					"witness": -12
				},
				"fame": {
					"amount": 0,
					"scandal": 8,
					"public_only": true,
				},
				"future_hooks": ["partner_confrontation", "family_trust_fracture", "rumor_mutation"]
			},
			{
				"id": "social.betrayal.default",
				"event_match": ["npc_betrayed", "betrayal", "relationship.betrayal"],
				"classification": {
					"social": true,
					"betrayal": true,
					"public": false,
					"violent": false,
					"supernatural": false,
					"intent": "harmful",
					"lethality": "none",
					"moral_weight": 68.0
				},
				"channels": ["direct_target", "family", "rumor"],
				"relationship_deltas": {
					"target": -34,
					"witness": -10,
					"family": -8
				},
				"future_hooks": ["revenge_chance", "trust_decay", "rumor_mutation"]
			},
			{
				"id": "social.violence.default",
				"event_match": ["npc_fought", "fight", "assault", "battle"],
				"classification": {
					"social": true,
					"violent": true,
					"public": true,
					"supernatural": false,
					"intent": "aggressive",
					"lethality": "medium",
					"moral_weight": 58.0
				},
				"channels": ["direct_target", "witness", "family", "rumor"],
				"relationship_deltas": {
					"target": -28,
					"witness": -8,
					"children": -16
				},
				"future_hooks": ["retaliation_chance", "authority_attention"]
			},
			{
				"id": "social.heroic_rescue.default",
				"event_match": ["heroic_rescue", "rescue", "life_saved", "bus_saved"],
				"classification": {
					"social": true,
					"heroic": true,
					"public": true,
					"violent": false,
					"supernatural": false,
					"intent": "protective",
					"lethality": "low",
					"moral_weight": 86.0
				},
				"channels": ["direct_target", "witness", "family", "media", "myth"],
				"relationship_deltas": {
					"target": 24,
					"witness": 8,
					"family": 6
				},
				"fame": {
					"amount": 4,
					"scandal": 0,
					"public_only": true,
				},
				"future_hooks": ["hero_identity_pressure", "institutional_attention", "myth_seed"]
			},
			{
				"id": "power.public_usage.default",
				"event_match": ["power_granted", "power_activated", "superhero_patrol", "superhero_battle_completed", "villain_identity_created", "power_usage"],
				"classification": {
					"social": true,
					"power": true,
					"public": true,
					"violent": true,
					"supernatural": true,
					"intent": "unclear",
					"lethality": "high",
					"moral_weight": 76.0
				},
				"channels": ["direct_target", "witness", "family", "media", "government", "criminal", "myth"],
				"relationship_deltas": {
					"target": 4,
					"witness": -4,
					"family": -2
				},
				"fame": {
					"amount": 8,
					"scandal": 2,
					"public_only": true,
				},
				"future_hooks": ["registration_pressure", "government_file", "criminal_interest", "myth_seed"]
			},
			{
				"id": "public.fame.default",
				"event_match": ["fame_spike", "scandal", "exposed", "infamy_changed"],
				"classification": {
					"social": true,
					"fame": true,
					"public": true,
					"violent": false,
					"supernatural": false,
					"intent": "public_attention",
					"lethality": "none",
					"moral_weight": 52.0
				},
				"channels": ["witness", "family", "media", "rumor", "myth"],
				"relationship_deltas": {
					"family": 2,
					"witness": 1
				},
				"future_hooks": ["media_arc", "identity_drift", "rumor_mutation"]
			},
			{
				"id": "crime.public.default",
				"event_match": ["npc_committed_crime", "npc_arrested", "crime_rumor_spread", "case_created", "case_verdict_returned", "case_sentenced"],
				"classification": {
					"social": true,
					"crime": true,
					"public": true,
					"violent": false,
					"supernatural": false,
					"intent": "criminal",
					"lethality": "unknown",
					"moral_weight": 74.0
				},
				"channels": ["witness", "family", "media", "government", "criminal", "rumor"],
				"relationship_deltas": {
					"family": -10,
					"witness": -6
				},
				"fame": {
					"amount": 0,
					"scandal": 10,
					"public_only": true,
				},
				"future_hooks": ["legal_pressure", "rumor_mutation", "reputation_damage"]
			},
			{
				"id": "social.generic.default",
				"event_match": ["*"],
				"classification": {
					"social": true,
					"public": false,
					"violent": false,
					"supernatural": false,
					"intent": "unclear",
					"lethality": "none",
					"moral_weight": 35.0
				},
				"channels": ["direct_target", "witness"],
				"relationship_deltas": {
					"target": 0,
					"witness": 0
				},
				"future_hooks": []
			}
		]
	}

func _bootstrap_contract_registry() -> void:
	if typeof(interpretation_contract_registry) != TYPE_DICTIONARY:
		interpretation_contract_registry = {}

	var contracts: Array = _safe_array(active_contract.get("interpretation_contracts", []))
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = _normalize_interpretation_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges()

		if contract_id == "":
			continue
		if not interpretation_contract_registry.has(contract_id):
			interpretation_contract_registry [contract_id] = normalized.duplicate(true)

	_ingest_modded_interpretation_contracts()

func _ingest_modded_interpretation_contracts() -> void:
	if gs == null:
		return
	if gs.mod_loader == null:
		return
	if not gs.mod_loader.has_method("export_registry"):
		return

	var registry_raw: Variant = gs.mod_loader.export_registry()
	if typeof(registry_raw) != TYPE_DICTIONARY:
		return

	var registry: Dictionary = registry_raw as Dictionary
	var mod_contracts_raw: Variant = registry.get("upce_contracts", registry.get("perception_contracts", []))
	var mod_contracts: Array = []

	if typeof(mod_contracts_raw) == TYPE_ARRAY:
		mod_contracts = mod_contracts_raw as Array
	elif typeof(mod_contracts_raw) == TYPE_DICTIONARY:
		for key in (mod_contracts_raw as Dictionary).keys():
			mod_contracts.append((mod_contracts_raw as Dictionary).get(key))

	for raw_contract in mod_contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = _normalize_interpretation_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges()
		if contract_id == "":
			continue

		interpretation_contract_registry [contract_id] = normalized.duplicate(true)

func _normalize_interpretation_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.upce_interpretation_contract"))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", "social.generic.default")).strip_edges()

	if typeof(out.get("event_match", [])) != TYPE_ARRAY:
		out ["event_match"] = [str(out.get("event_match", "*"))]

	if typeof(out.get("classification", {})) != TYPE_DICTIONARY:
		out ["classification"] = {}

	if typeof(out.get("channels", [])) != TYPE_ARRAY:
		out ["channels"] = []

	if typeof(out.get("relationship_deltas", {})) != TYPE_DICTIONARY:
		out ["relationship_deltas"] = {}

	if typeof(out.get("fame", {})) != TYPE_DICTIONARY:
		out ["fame"] = {}

	if typeof(out.get("future_hooks", [])) != TYPE_ARRAY:
		out ["future_hooks"] = []

	return out

func _normalize_event(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = payload.duplicate(true)

	var event_name: String = str(out.get("event_name", out.get("event_type", context.get("event_name", "")))).strip_edges()
	if event_name == "":
		event_name = str(out.get("type", out.get("action_id", context.get("command_id", "social.event")))).strip_edges()
	if event_name == "":
		event_name = "social.event"

	out ["event_name"] = event_name
	out ["event_id"] = str(out.get("event_id", "%s_%d_%d" % [event_name, _current_year(), int(Time.get_ticks_msec())]))

	if not out.has("actor_id"):
		out ["actor_id"] = int(out.get("npc_id", out.get("person_id", out.get("winner_id", -1))))

	if not out.has("target_id"):
		out ["target_id"] = int(out.get("target_id", out.get("victim_id", out.get("opponent_id", -1))))

	if not out.has("other_person_id"):
		out ["other_person_id"] = int(out.get("other_person_id", out.get("partner_id", out.get("lover_id", -1))))

	if not out.has("public"):
		out ["public"] = bool(out.get("seen_publicly", out.get("public_event", false)))

	if not out.has("text"):
		out ["text"] = str(out.get("description", event_name.replace("_", " ")))

	out ["source"] = str(out.get("source", context.get("source", "upce")))
	out ["year"] = int(out.get("year", _current_year()))

	return out

func _resolve_contract_for_event(event: Dictionary) -> Dictionary:
	_bootstrap_contract_registry()

	var event_name: String = str(event.get("event_name", "")).strip_edges().to_lower()
	var fallback: Dictionary = {}

	for key in interpretation_contract_registry.keys():
		var contract: Dictionary = _safe_dictionary(interpretation_contract_registry.get(key, {}))
		if contract.is_empty():
			continue

		var event_match: Array = _safe_array(contract.get("event_match", []))
		for raw_match in event_match:
			var match_text: String = str(raw_match).strip_edges().to_lower()
			if match_text == "*":
				fallback = contract.duplicate(true)
				continue
			if event_name == match_text or event_name.find(match_text) >= 0:
				return contract.duplicate(true)

	if not fallback.is_empty():
		return fallback.duplicate(true)

	return _normalize_interpretation_contract({
		"id": "social.generic.default",
		"event_match": ["*"]
	})

func _resolve_classification(event: Dictionary, contract: Dictionary) -> Dictionary:
	var out: Dictionary = _safe_dictionary(contract.get("classification", {}))

	var event_name: String = str(event.get("event_name", "")).strip_edges().to_lower()
	var text: String = str(event.get("text", "")).strip_edges().to_lower()

	if event.has("classification") and typeof(event.get("classification", {})) == TYPE_DICTIONARY:
		out = _merge_dict(out, event.get("classification", {}) as Dictionary)

	if event.has("public"):
		out ["public"] = bool(event.get("public", out.get("public", false)))

	if event.has("power_level") or event.has("power_profile") or event_name.find("power") >= 0 or event_name.find("superhero") >= 0:
		out ["power"] = true
		out ["supernatural"] = true

	if event_name.find("cheat") >= 0 or event_name.find("betray") >= 0:
		out ["betrayal"] = true
		out ["social"] = true

	if event_name.find("fight") >= 0 or event_name.find("battle") >= 0 or text.find("fought") >= 0:
		out ["violent"] = true

	if event_name.find("killed") >= 0 or event_name.find("death") >= 0 or text.find("killed") >= 0:
		out ["violent"] = true
		out ["lethality"] = "fatal"

	if not out.has("moral_weight"):
		out ["moral_weight"] = 35.0

	var power_score: float = _power_score(event)
	if power_score >= 70.0:
		out ["supernatural"] = true
		out ["lethality"] = "high"

	out ["power_score"] = power_score
	out ["salience"] = _resolve_salience(event, out)

	return out

func _resolve_channels(event: Dictionary, contract: Dictionary, classification: Dictionary) -> Array:
	var channels: Array = []

	for raw_channel in _safe_array(contract.get("channels", [])):
		_append_unique_string(channels, str(raw_channel))

	for raw_channel in _safe_array(event.get("perception_channels", [])):
		_append_unique_string(channels, str(raw_channel))

	if bool(classification.get("public", false)) or bool(event.get("public", false)):
		_append_unique_string(channels, "witness")
		_append_unique_string(channels, "media")
		_append_unique_string(channels, "rumor")

	if bool(classification.get("supernatural", false)) or bool(classification.get("power", false)):
		_append_unique_string(channels, "government")
		_append_unique_string(channels, "criminal")
		_append_unique_string(channels, "myth")

	if channels.is_empty():
		_append_unique_string(channels, "direct_target")

	return channels

func _resolve_witnesses(event: Dictionary, actor: Person, target: Person, other: Person) -> Array:
	var out: Array = []

	for raw_id in _safe_array(event.get("witness_ids", [])):
		_append_unique_person(out, _person_by_id(int(raw_id)))

	if bool(event.get("include_children_as_witnesses", true)):
		for person in [actor, target, other]:
			if person == null:
				continue
			for raw_child_id in person.children:
				_append_unique_person(out, _person_by_id(int(raw_child_id)))

	var witness_count: int = int(event.get("witness_count", event.get("witnesses", 0)))
	if witness_count > 0:
		out = out.slice(0, min(out.size(), witness_count))

	return out

func _build_observations(event: Dictionary, _contract: Dictionary, classification: Dictionary, channels: Array, actor: Person, target: Person, other: Person, witnesses: Array) -> Array:
	var observations: Array = []
	var seen_people: Dictionary = {}

	if actor != null:
		observations.append(_observation_for_person("self", actor, actor, target, other, event, classification, channels))
		seen_people [int(actor.id)] = true

	if target != null and not seen_people.has(int(target.id)):
		observations.append(_observation_for_person("direct_target", target, actor, target, other, event, classification, channels))
		seen_people [int(target.id)] = true

	if other != null and not seen_people.has(int(other.id)):
		observations.append(_observation_for_person("affected_person", other, actor, target, other, event, classification, channels))
		seen_people [int(other.id)] = true

	for witness in witnesses:
		if witness == null:
			continue
		if seen_people.has(int(witness.id)):
			continue
		observations.append(_observation_for_person("witness", witness, actor, target, other, event, classification, channels))
		seen_people [int(witness.id)] = true

	for raw_channel in channels:
		var channel: String = str(raw_channel)
		if channel in ["government", "media", "criminal", "myth", "rumor"]:
			observations.append(_institution_observation(channel, actor, target, event, classification))

	return observations

func _observation_for_person(role: String, observer: Person, actor: Person, target: Person, other: Person, event: Dictionary, classification: Dictionary, channels: Array) -> Dictionary:
	var bias_id: String = _bias_profile_for_person(observer)
	var bias: Dictionary = _bias_profile_row(bias_id)
	var emotional_state: Dictionary = _emotion_for_observer(role, observer, actor, target, other, event, classification, bias)
	var distortion: float = _memory_distortion_for_observer(role, event, classification, bias)
	var myth_seed: String = _myth_seed_for_observer(role, bias_id, event, classification)
	var diary_text: String = _life_diary_text_for_observer(role, observer, actor, target, other, event, classification, emotional_state, myth_seed)

	return {
		"schema": "eralife.upce_observer_interpretation",
		"version": CONTRACT_VERSION,
		"role": role,
		"observer_id": int(observer.id),
		"observer_name": _person_label(observer),
		"bias_profile": bias_id,
		"emotional_state": emotional_state.duplicate(true),
		"memory": {
			"truth_confidence": clamp(1.0 - distortion, 0.0, 1.0),
			"distortion_factor": distortion,
			"purity": "pure" if distortion <= 0.18 else "distorted",
			"decay_curve": "trauma_sticky" if float(emotional_state.get("fear", 0.0)) >= 0.65 else "normal"
		},
		"myth_seed": myth_seed,
		"diary_text": diary_text,
		"channels": channels.duplicate(true)
	}

func _institution_observation(channel: String, _actor: Person, _target: Person, event: Dictionary, classification: Dictionary) -> Dictionary:
	var myth_seed: String = "public_record"

	match channel:
		"government":
			myth_seed = "unregistered_threat" if bool(classification.get("supernatural", false)) else "case_file"
		"media":
			myth_seed = "headline"
		"criminal":
			myth_seed = "asset_or_threat"
		"myth":
			myth_seed = "legend_seed"
		"rumor":
			myth_seed = "distorted_story"

	return {
		"schema": "eralife.upce_institutional_interpretation",
		"version": CONTRACT_VERSION,
		"role": channel,
		"observer_id": -1,
		"observer_name": channel.capitalize(),
		"bias_profile": channel,
		"emotional_state": _institution_emotion(channel, classification),
		"memory": {
			"truth_confidence": clamp(1.0 - _channel_distortion(channel, event), 0.0, 1.0),
			"distortion_factor": _channel_distortion(channel, event),
			"purity": "institutional"
		},
		"myth_seed": myth_seed,
		"diary_text": "",
		"channels": [channel]
	}

func _emotion_for_observer(role: String, _observer: Person, _actor: Person, _target: Person, _other: Person, _event: Dictionary, classification: Dictionary, bias: Dictionary) -> Dictionary:
	var fear: float = 0.0
	var anger: float = 0.0
	var awe: float = 0.0
	var gratitude: float = 0.0
	var loyalty: float = 0.0
	var shame: float = 0.0
	var grief: float = 0.0
	var distrust: float = 0.0

	if bool(classification.get("heroic", false)):
		gratitude += 0.55
		awe += 0.25

	if bool(classification.get("betrayal", false)):
		anger += 0.52
		grief += 0.32
		distrust += 0.48

	if bool(classification.get("violent", false)):
		fear += 0.38
		anger += 0.18

	if bool(classification.get("supernatural", false)):
		awe += 0.42
		fear += 0.25

	if str(classification.get("lethality", "none")) in ["high", "fatal"]:
		fear += 0.28
		grief += 0.18

	if role == "self":
		shame += 0.22 if bool(classification.get("betrayal", false)) else 0.0
		gratitude *= 0.45
		fear *= 0.55
	elif role == "direct_target":
		gratitude += 0.35 if bool(classification.get("heroic", false)) else 0.0
		anger += 0.3 if bool(classification.get("betrayal", false)) else 0.0
	elif role == "witness":
		fear += 0.18
		awe += 0.16

	fear += float(bias.get("fear_bias", 0.0))
	distrust -= float(bias.get("trust_bias", 0.0))

	return {
		"fear": clamp(fear, 0.0, 1.0),
		"anger": clamp(anger, 0.0, 1.0),
		"awe": clamp(awe, 0.0, 1.0),
		"gratitude": clamp(gratitude, 0.0, 1.0),
		"loyalty": clamp(loyalty, 0.0, 1.0),
		"shame": clamp(shame, 0.0, 1.0),
		"grief": clamp(grief, 0.0, 1.0),
		"distrust": clamp(distrust, 0.0, 1.0)
	}

func _institution_emotion(channel: String, classification: Dictionary) -> Dictionary:
	match channel:
		"government":
			return {
				"fear": 0.18 if bool(classification.get("supernatural", false)) else 0.04,
				"control": 0.82,
				"trust": 0.05,
				"awe": 0.12
			}
		"criminal":
			return {
				"fear": 0.18,
				"opportunism": 0.84,
				"trust": 0.0,
				"awe": 0.22
			}
		"media":
			return {
				"curiosity": 0.75,
				"distortion_pressure": 0.35,
				"awe": 0.22
			}
		"myth":
			return {
				"awe": 0.9,
				"symbolism": 0.8
			}
		_:
			return {
				"distrust": 0.42,
				"curiosity": 0.4
			}

func _memory_distortion_for_observer(role: String, event: Dictionary, classification: Dictionary, bias: Dictionary) -> float:
	var distortion: float = 0.12
	distortion += _era_distortion_factor()
	distortion += float(bias.get("distortion_bias", 0.0))

	if role == "direct_target":
		distortion -= 0.1
	elif role == "witness":
		distortion += 0.12

	if bool(classification.get("supernatural", false)):
		distortion += 0.1

	if bool(event.get("public", false)):
		distortion += 0.06

	return clamp(distortion, 0.0, 0.92)

func _channel_distortion(channel: String, event: Dictionary) -> float:
	var base: float = _era_distortion_factor()

	match channel:
		"media":
			base += float(event.get("media_distortion_factor", 0.22))
		"rumor":
			base += 0.38
		"myth":
			base += 0.46
		"government":
			base += 0.08
		"criminal":
			base += 0.18
		_:
			base += 0.12

	return clamp(base, 0.0, 0.95)

func _myth_seed_for_observer(role: String, bias_id: String, _event: Dictionary, classification: Dictionary) -> String:
	if role == "self":
		return "identity_moment"

	if bool(classification.get("heroic", false)) and role == "direct_target":
		return "hero"

	if bool(classification.get("betrayal", false)):
		return "betrayer"

	if bool(classification.get("supernatural", false)):
		match bias_id:
			"religious", "religious_extremist":
				return "divine_sign"
			"scientific":
				return "mutation_case"
			"paranoid":
				return "threat_entity"
			_:
				return "unknown_entity"

	if bool(classification.get("fame", false)):
		return "public_identity"

	return "personal_memory"

func _life_diary_text_for_observer(role: String, observer: Person, actor: Person, target: Person, _other: Person, event: Dictionary, classification: Dictionary, emotion: Dictionary, myth_seed: String) -> String:
	if bool(event.get("suppress_life_diary", false)):
		return ""

	var actor_label: String = _relative_label(observer, actor)
	var target_label: String = _relative_label(observer, target)
	var event_name: String = str(event.get("event_name", "")).strip_edges().to_lower()

	if event_name == "object.perceived" or bool(classification.get("object_perception", false)):
		var item_name: String = str(event.get("item_name", "an object")).strip_edges()
		if item_name == "":
			item_name = "an object"
		var myth_level: String = str(event.get("myth_level", "")).strip_edges()
		if myth_level == "":
			myth_level = "strange"

		if role == "self":
			if item_name.to_lower() == "red bonnet":
				return "People noticed my Red Bonnet. It did not feel like a hat anymore. It felt like a story deciding who believed in it."
			return "People noticed my %s. The way they looked at it made it feel %s, not ordinary." % [item_name, myth_level]

		if role == "direct_target" or role == "affected_person":
			if actor_label == "me":
				return "I noticed my %s differently. It felt like the world was beginning to give it a name." % item_name
			return "I noticed %s's %s. Something about it made the room feel less ordinary." % [actor_label, item_name]

		return "I saw %s's %s. I felt %s, but I could tell other people were already turning it into a story." % [actor_label, item_name, _dominant_emotion_word(emotion)]

	if role == "self":
		if bool(classification.get("betrayal", false)):
			return "I betrayed %s. I could feel the trust shift around me." % target_label
		if bool(classification.get("heroic", false)):
			return "I saved %s. People saw me, but not everyone looked relieved." % target_label
		if bool(classification.get("supernatural", false)):
			return "I used power in front of people. Some looked amazed. Some looked afraid."
		return str(event.get("text", "Something happened."))

	if event_name.find("yell") >= 0:
		if role == "witness":
			return "I saw %s yell at %s. I felt scared." % [actor_label, target_label]
		return "%s yelled at me. I felt %s." % [actor_label, _dominant_emotion_word(emotion)]

	if bool(classification.get("betrayal", false)):
		if role == "direct_target" or role == "affected_person":
			return "%s betrayed me. I felt %s." % [actor_label, _dominant_emotion_word(emotion)]
		if role == "witness":
			return "I saw what %s did to %s. It made me feel %s." % [actor_label, target_label, _dominant_emotion_word(emotion)]

	if bool(classification.get("heroic", false)):
		if role == "direct_target":
			return "%s saved me. I felt grateful, but I still wondered what kind of person can do that." % actor_label
		if role == "witness":
			return "I saw %s save someone. I felt %s." % [actor_label, _dominant_emotion_word(emotion)]

	if bool(classification.get("supernatural", false)):
		return "I saw %s use impossible power. In my mind, the memory became: %s." % [actor_label, myth_seed.replace("_", " ")]

	return "I saw %s. I felt %s." % [str(event.get("text", "something happen")), _dominant_emotion_word(emotion)]

func _dominant_emotion_word(emotion: Dictionary) -> String:
	var best_key: String = "changed"
	var best_value: float = -1.0

	for raw_key in emotion.keys():
		var key: String = str(raw_key)
		var value: float = float(emotion.get(raw_key, 0.0))
		if value > best_value:
			best_value = value
			best_key = key

	match best_key:
		"fear":
			return "afraid"
		"anger":
			return "angry"
		"awe":
			return "awed"
		"gratitude":
			return "grateful"
		"grief":
			return "hurt"
		"distrust":
			return "suspicious"
		"shame":
			return "ashamed"
		_:
			return best_key

func _apply_consequences(event: Dictionary, contract: Dictionary, classification: Dictionary, actor: Person, target: Person, other: Person, observations: Array) -> Array:
	var visible: Array = []

	_apply_relationship_consequences(contract, actor, target, other, observations, visible)
	_apply_fame_consequences(event, contract, classification, actor, visible)

	if bool(classification.get("supernatural", false)) and actor != null:
		visible.append("A file, rumor, or myth can now form around %s's power." % _person_label(actor))

	if bool(classification.get("betrayal", false)):
		visible.append("Trust damage was seeded into memories, not just relationship points.")

	return visible

func _apply_relationship_consequences(contract: Dictionary, actor: Person, target: Person, other: Person, _observations: Array, visible: Array) -> void:
	if gs == null or gs.relationship_engine == null:
		return
	if not gs.relationship_engine.has_method("adjust_relationship"):
		return

	var deltas: Dictionary = _safe_dictionary(contract.get("relationship_deltas", {}))

	if actor != null and target != null:
		var target_delta: int = int(deltas.get("target", 0))
		if target_delta != 0:
			gs.relationship_engine.adjust_relationship(target, actor, target_delta)
			visible.append("%s's feelings toward %s shifted by %d." % [_person_label(target), _person_label(actor), target_delta])

	if actor != null and other != null:
		var partner_delta: int = int(deltas.get("partner", deltas.get("target", 0)))
		if partner_delta != 0:
			gs.relationship_engine.adjust_relationship(other, actor, partner_delta)
			visible.append("%s's trust toward %s shifted by %d." % [_person_label(other), _person_label(actor), partner_delta])

	var child_delta: int = int(deltas.get("children", 0))
	if child_delta != 0 and actor != null:
		for raw_child_id in actor.children:
			var child: Person = _person_by_id(int(raw_child_id))
			if child == null:
				continue
			gs.relationship_engine.adjust_relationship(child, actor, child_delta)

func _apply_fame_consequences(event: Dictionary, contract: Dictionary, classification: Dictionary, actor: Person, visible: Array) -> void:
	if actor == null:
		return

	var fame_rule: Dictionary = _safe_dictionary(contract.get("fame", {}))
	if fame_rule.is_empty():
		return

	var public_only: bool = bool(fame_rule.get("public_only", true))
	if public_only and not bool(classification.get("public", event.get("public", false))):
		return

	var amount: int = int(fame_rule.get("amount", 0))
	if bool(classification.get("supernatural", false)):
		amount += int(round(_power_score(event) / 18.0))

	if amount != 0:
		if gs != null and gs.fame_engine != null and gs.fame_engine.has_method("give_fame"):
			gs.fame_engine.give_fame(actor, amount)
			visible.append("Fame moved through FameEngine by %+d." % amount)
		else:
			actor.fame = clamp(int(actor.fame) + amount, 0, 100)
			visible.append("Fame changed by %+d." % amount)

	var scandal: int = int(fame_rule.get("scandal", 0))
	if scandal != 0:
		actor.scandal = clamp(int(actor.scandal) + scandal, 0, 100)
		actor.paparazzi_heat = clamp(int(actor.paparazzi_heat) + int(round(float(scandal) * 0.65)), 0, 100)
		visible.append("Scandal pressure increased by %d." % scandal)

func _build_future_hooks(_event: Dictionary, contract: Dictionary, classification: Dictionary, channels: Array, _actor: Person, _target: Person, _other: Person, _observations: Array) -> Array:
	var hooks: Array = []

	for raw_hook in _safe_array(contract.get("future_hooks", [])):
		_append_unique_string(hooks, str(raw_hook))

	if "government" in channels:
		_append_unique_string(hooks, "government_attention")
	if "criminal" in channels:
		_append_unique_string(hooks, "criminal_org_recruit_or_kill")
	if "media" in channels:
		_append_unique_string(hooks, "media_distortion_arc")
	if "myth" in channels:
		_append_unique_string(hooks, "myth_layer_identity_seed")
	if bool(classification.get("betrayal", false)):
		_append_unique_string(hooks, "relationship_confrontation_scenario")
	if bool(classification.get("supernatural", false)):
		_append_unique_string(hooks, "registration_pressure")

	return hooks

func _build_clear_narrative(event: Dictionary, classification: Dictionary, _channels: Array, actor: Person, target: Person, _observations: Array) -> String:
	var actor_name: String = _person_label(actor)
	var target_name: String = _person_label(target)
	var event_name: String = str(event.get("event_name", "")).strip_edges().to_lower()

	if event_name == "object.perceived" or bool(classification.get("object_perception", false)):
		var item_name: String = str(event.get("item_name", "an object")).strip_edges()
		if item_name == "":
			item_name = "an object"
		var myth_level: String = str(event.get("myth_level", "")).strip_edges()
		var bias_profile: String = str(event.get("bias_profile", "ordinary_social")).strip_edges().to_lower()
		if myth_level == "":
			myth_level = "strange"

		match bias_profile:
			"religious_extremist", "spiritual":
				return "%s noticed %s around %s and interpreted it like a sign instead of a possession." % [target_name, item_name, actor_name]
			"scientific":
				return "%s noticed %s around %s and treated it like an anomaly worth studying." % [target_name, item_name, actor_name]
			"paranoid":
				return "%s noticed %s around %s and felt the air shift into threat." % [target_name, item_name, actor_name]
			"mythic_folk":
				return "%s noticed %s around %s, and the story around it started sounding %s." % [target_name, item_name, actor_name, myth_level]
			_:
				return "%s noticed %s around %s. It did not feel like ordinary property anymore." % [target_name, item_name, actor_name]

	if bool(classification.get("heroic", false)):
		if bool(classification.get("supernatural", false)):
			return "%s saved %s with power people could not easily explain. Some felt grateful. Some felt afraid." % [actor_name, target_name]
		return "%s saved %s. Gratitude spread first, but interpretation followed close behind." % [actor_name, target_name]

	if bool(classification.get("betrayal", false)):
		return "%s betrayed %s. The fact happened once, but the meaning began splitting across everyone who knew them." % [actor_name, target_name]

	if bool(classification.get("supernatural", false)):
		return "%s revealed power in a social world that immediately tried to name it, fear it, exploit it, or worship it." % actor_name

	if bool(classification.get("fame", false)):
		return "%s became more visible. Fame did not settle as one truth; it began mutating into reputation, envy, admiration, and rumor." % actor_name

	return str(event.get("text", "%s did something people interpreted differently." % actor_name))

func _player_narrative_from_observations(observations: Array, fallback: String) -> String:
	if gs == null or gs.player == null:
		return fallback

	for raw_obs in observations:
		if typeof(raw_obs) != TYPE_DICTIONARY:
			continue
		var obs: Dictionary = raw_obs as Dictionary
		if int(obs.get("observer_id", -1)) == int(gs.player.id):
			var diary_text: String = str(obs.get("diary_text", "")).strip_edges()
			if diary_text != "":
				return diary_text

	return fallback

func _build_myth_packet(event: Dictionary, _contract: Dictionary, classification: Dictionary, channels: Array, actor: Person, observations: Array) -> Dictionary:
	var myth_strength: float = 0.0

	for raw_obs in observations:
		if typeof(raw_obs) != TYPE_DICTIONARY:
			continue
		var obs: Dictionary = raw_obs as Dictionary
		var memory: Dictionary = _safe_dictionary(obs.get("memory", {}))
		myth_strength += float(memory.get("distortion_factor", 0.0)) * 0.25
		if str(obs.get("myth_seed", "")) not in ["", "personal_memory"]:
			myth_strength += 0.12

	if "myth" in channels:
		myth_strength += 0.32
	if bool(classification.get("supernatural", false)):
		myth_strength += 0.22
	if bool(classification.get("fame", false)):
		myth_strength += 0.15

	myth_strength = clamp(myth_strength, 0.0, 1.0)

	return {
		"schema": "eralife.upce_myth_packet",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"event_id": str(event.get("event_id", "")),
		"myth_strength": myth_strength,
		"myth_active": myth_strength >= 0.35,
		"identity_label": _myth_identity_label(classification, myth_strength),
		"channels": channels.duplicate(true)
	}

func _myth_identity_label(classification: Dictionary, myth_strength: float) -> String:
	if myth_strength < 0.35:
		return "remembered_person"
	if bool(classification.get("heroic", false)):
		return "hero"
	if bool(classification.get("betrayal", false)):
		return "betrayer"
	if bool(classification.get("crime", false)):
		return "criminal_legend"
	if bool(classification.get("supernatural", false)):
		return "mythic_power"
	if bool(classification.get("fame", false)):
		return "public_figure"
	return "local_myth"

func _commit_report(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("interpretation_ledger", []))
	ledger.append(report.duplicate(true))

	while ledger.size() > MAX_INTERPRETATION_LEDGER:
		ledger.pop_front()

	state ["interpretation_ledger"] = ledger
	state ["last_interpretation_report"] = report.duplicate(true)
	_commit_world_state(state)

func _commit_observer_memories(report: Dictionary, actor: Person, target: Person, other: Person) -> void:
	if gs == null:
		return

	var observations: Array = _safe_array(report.get("observations", []))

	for raw_obs in observations:
		if typeof(raw_obs) != TYPE_DICTIONARY:
			continue

		var obs: Dictionary = raw_obs as Dictionary
		var observer_id: int = int(obs.get("observer_id", -1))
		if observer_id <= 0:
			continue

		var observer: Person = _person_by_id(observer_id)
		if observer == null:
			continue

		var diary_text: String = str(obs.get("diary_text", "")).strip_edges()
		if diary_text == "":
			continue

		var memory_packet: Dictionary = {
			"schema": "eralife.upce_memory_packet",
			"version": CONTRACT_VERSION,
			"source": "upce_engine",
			"event_id": str(report.get("interpretation_id", "")),
			"event_name": str(report.get("event_name", "")),
			"observer_id": observer_id,
			"actor_id": int(actor.id) if actor != null else -1,
			"target_id": int(target.id) if target != null else -1,
			"other_person_id": int(other.id) if other != null else -1,
			"bias_profile": str(obs.get("bias_profile", "default")),
			"emotional_state": _safe_dictionary(obs.get("emotional_state", {})),
			"memory": _safe_dictionary(obs.get("memory", {})),
			"myth_seed": str(obs.get("myth_seed", "")),
			"text": diary_text,
			"year": _current_year()
		}

		if gs.memory_engine != null and gs.memory_engine.has_method("remember_upce_interpretation"):
			gs.memory_engine.remember_upce_interpretation(observer_id, memory_packet)
		elif gs.memory_engine != null and gs.memory_engine.has_method("remember"):
			gs.memory_engine.remember(observer_id, diary_text)

		if bool(_runtime_policy().get("write_life_diary", true)) and gs.narrative_engine != null and gs.narrative_engine.has_method("log_event"):
			gs.narrative_engine.log_event(observer, {
				"type": "text",
				"text": diary_text,
				"life_diary_text": diary_text,
				"force_first_person_memory": true,
				"source": "upce_engine",
				"event_name": str(report.get("event_name", "upce_interpretation")),
				"category": "perception",
				"shared_event_id": str(report.get("interpretation_id", "")),
				"supports_conflicting_narratives": true,
				"skip_llm_enhancement": true,
				"skip_relationship_hooks": true,
				"suppress_world_feed": true
			})

func _seed_world_feed(report: Dictionary, actor: Person, target: Person) -> void:
	if gs == null:
		return
	if not bool(_runtime_policy().get("write_world_feed", true)):
		return

	var classification: Dictionary = _safe_dictionary(report.get("classification", {}))
	var should_feed: bool = bool(classification.get("public", false)) or "media" in _safe_array(report.get("perception_channels", []))

	if not should_feed:
		return

	var text: String = str(report.get("clear_narrative", "")).strip_edges()
	if text == "":
		return

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(text, {
			"schema": "eralife.upce_world_feed_entry",
			"event_name": str(report.get("event_name", "upce_interpretation")),
			"npc_id": int(actor.id) if actor != null else -1,
			"target_id": int(target.id) if target != null else -1,
			"category": "perception",
			"source": "upce_engine",
			"upce_interpretation_id": str(report.get("interpretation_id", "")),
			"myth_packet": _safe_dictionary(report.get("myth_packet", {})),
		})

func _queue_future_hooks(report: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var hooks: Array = _safe_array(gs.scenario_state.get("upce_pending_future_hooks", []))
	hooks.append({
		"schema": "eralife.upce_future_hook_packet",
		"version": CONTRACT_VERSION,
		"interpretation_id": str(report.get("interpretation_id", "")),
		"event_name": str(report.get("event_name", "")),
		"actor_id": int(report.get("actor_id", -1)),
		"target_id": int(report.get("target_id", -1)),
		"future_hooks": _safe_array(report.get("future_hooks", [])),
		"myth_packet": _safe_dictionary(report.get("myth_packet", {})),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	while hooks.size() > 60:
		hooks.pop_front()

	gs.scenario_state ["upce_pending_future_hooks"] = hooks

func _queue_player_ui_interpretation(report: Dictionary) -> void:
	if gs == null or gs.player == null:
		return
	if not bool(_runtime_policy().get("queue_player_ui_interpretations", true)):
		return

	var event: Dictionary = _safe_dictionary(report.get("event", {}))
	if _should_suppress_player_ui_interpretation(report, event):
		return

	var player_related: bool = int(report.get("actor_id", -1)) == int(gs.player.id) or int(report.get("target_id", -1)) == int(gs.player.id)

	if not player_related:
		for raw_obs in _safe_array(report.get("observations", [])):
			if typeof(raw_obs) != TYPE_DICTIONARY:
				continue
			if int((raw_obs as Dictionary).get("observer_id", -1)) == int(gs.player.id):
				player_related = true
				break

	if not player_related:
		return

	var state: Dictionary = _world_state()
	var pending: Array = _safe_array(state.get("pending_ui_interpretations", []))
	pending.append(report.duplicate(true))

	while pending.size() > MAX_PENDING_UI_INTERPRETATIONS:
		pending.pop_front()

	state ["pending_ui_interpretations"] = pending
	_commit_world_state(state)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var ui_pending: Array = _safe_array(gs.scenario_state.get("pending_upce_interpretations", []))
	ui_pending.append(report.duplicate(true))

	while ui_pending.size() > MAX_PENDING_UI_INTERPRETATIONS:
		ui_pending.pop_front()

	gs.scenario_state ["pending_upce_interpretations"] = ui_pending
func _should_suppress_player_ui_interpretation(report: Dictionary, event: Dictionary) -> bool:
	if report.is_empty():
		return true

	if bool(report.get("suppress_player_ui_interpretation", false)):
		return true
	if bool(event.get("suppress_player_ui_interpretation", false)):
		return true
	if bool(report.get("suppress_upce_player_popup", false)):
		return true
	if bool(event.get("suppress_upce_player_popup", false)):
		return true

	var force_popup: bool = bool(report.get("force_player_ui_interpretation", event.get("force_player_ui_interpretation", false)))
	var explicit_popup: bool = bool(report.get("show_player_ui_interpretation", event.get("show_player_ui_interpretation", false)))
	var generic_popups_enabled: bool = bool(_runtime_policy().get("generic_player_ui_interpretation_popups_enabled", false))

	if not force_popup and not explicit_popup and not generic_popups_enabled:
		return true

	var allow_boot_popup: bool = bool(report.get("allow_boot_player_ui_interpretation", event.get("allow_boot_player_ui_interpretation", false)))
	if not allow_boot_popup and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		if bool(gs.scenario_state.get("birth_shell_first_boot", false)):
			return true
		if bool(gs.scenario_state.get("birth_shell_first_boot_active", false)):
			return true
		if bool(gs.scenario_state.get("birth_shell_deferred_boot_pending", false)):
			return true
		if bool(gs.scenario_state.get("post_spawn_ui_finalize_pending", false)):
			return true
		if bool(gs.scenario_state.get("post_spawn_world_prewarm_pending", false)):
			return true
		if bool(gs.scenario_state.get("deferred_data_bootstrap_pending", false)):
			return true
		if bool(gs.scenario_state.get("deferred_runtime_watchers_bootstrap", false)):
			return true

	var classification: Dictionary = _safe_dictionary(report.get("classification", event.get("classification", {})))
	var event_name: String = str(event.get("event_name", report.get("event_name", ""))).strip_edges().to_lower()
	var event_type: String = str(event.get("event_type", "")).strip_edges().to_lower()
	var source: String = str(event.get("source", report.get("source", ""))).strip_edges().to_lower()

	var is_object_perception: bool = event_name == "object.perceived" or event_type == "object_perception" or bool(classification.get("object_perception", false))
	if is_object_perception and not force_popup and not bool(event.get("allow_object_perception_popup", report.get("allow_object_perception_popup", false))):
		return true

	if not force_popup:
		if source.find("spawn") >= 0:
			return true
		if source.find("bootstrap") >= 0:
			return true
		if source.find("birth_shell") >= 0:
			return true

	return false

func _emit_interpretation_event(report: Dictionary) -> void:
	if gs == null:
		return
	if gs.event_bus == null:
		return
	if not bool(_runtime_policy().get("emit_event_bus", true)):
		return

	gs.event_bus.emit("upce_interpretation_completed", report)

func _runtime_policy() -> Dictionary:
	return _safe_dictionary(active_contract.get("runtime_policy", {}))

func _bias_profile_for_person(person: Person) -> String:
	if person == null:
		return "default"

	if person.has_meta("bias_profile"):
		var meta_bias: String = str(person.get_meta("bias_profile")).strip_edges().to_lower()
		if meta_bias != "":
			return meta_bias

	if person.has_meta("upce_bias_profile"):
		var upce_meta_bias: String = str(person.get_meta("upce_bias_profile")).strip_edges().to_lower()
		if upce_meta_bias != "":
			return upce_meta_bias

	var contract_raw: Variant = person.consciousness_contract
	if typeof(contract_raw) == TYPE_DICTIONARY:
		var contract: Dictionary = contract_raw as Dictionary
		var contract_bias: String = str(contract.get("bias_profile", contract.get("perception_bias_profile", ""))).strip_edges().to_lower()
		if contract_bias != "":
			return contract_bias

	if "Paranoid" in person.traits:
		return "paranoid"
	if "Religious" in person.traits:
		return "religious"
	if "Genius" in person.traits or "Logical" in person.traits or int(person.smarts) >= 80:
		return "scientific"
	if "Loyal" in person.traits or "Kind" in person.traits:
		return "trusting"
	if "Jealous" in person.traits or "Petulant" in person.traits or "Crazy" in person.traits:
		return "emotional"

	return "default"

func _bias_profile_row(profile_id: String) -> Dictionary:
	var profiles: Dictionary = _safe_dictionary(active_contract.get("bias_profiles", {}))
	var clean_id: String = str(profile_id).strip_edges().to_lower()
	var row: Dictionary = _safe_dictionary(profiles.get(clean_id, {}))

	if row.is_empty():
		row = _safe_dictionary(profiles.get("default", {}))

	return row

func _power_score(event: Dictionary) -> float:
	var raw_power: Variant = event.get("power_level", event.get("power_score", 0))

	if typeof(raw_power) in [TYPE_INT, TYPE_FLOAT]:
		return clamp(float(raw_power), 0.0, 100.0)

	var text: String = str(raw_power).strip_edges().to_lower()

	match text:
		"street":
			return 18.0
		"city":
			return 38.0
		"national":
			return 52.0
		"global":
			return 68.0
		"planetary":
			return 86.0
		"cosmic":
			return 98.0
		_:
			return 0.0

func _resolve_salience(event: Dictionary, classification: Dictionary) -> float:
	if event.has("salience"):
		return clamp(float(event.get("salience", 0.0)), 0.0, 100.0)

	var salience: float = float(classification.get("moral_weight", 35.0))
	salience += _power_score(event) * 0.35

	if bool(classification.get("public", false)):
		salience += 10.0
	if bool(classification.get("betrayal", false)):
		salience += 8.0
	if bool(classification.get("heroic", false)):
		salience += 12.0

	return clamp(salience, 0.0, 100.0)

func _era_distortion_factor() -> float:
	if gs == null or gs.era == null:
		return 0.2

	var era_name: String = str(gs.era.name).strip_edges().to_lower()

	if era_name.find("ancient") >= 0:
		return 0.38
	if era_name.find("medieval") >= 0:
		return 0.3
	if era_name.find("industrial") >= 0:
		return 0.22
	if era_name.find("future") >= 0:
		return 0.08

	return 0.14

func _relative_label(observer: Person, person: Person) -> String:
	if person == null:
		return "someone"
	if observer == null:
		return _person_label(person)

	if int(observer.id) == int(person.id):
		return "myself"

	if int(person.id) in observer.parents:
		return "my Dad" if str(person.gender) == "Male" else "my Mom"

	if int(observer.id) in person.children:
		return "my child"

	if observer.partner == person:
		return "my partner"

	if person.id in observer.ex_partners:
		return "my ex"

	return person.first_name

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(person_id)
		if found != null:
			return found

	if gs.has_method("get_or_reactivate_npc_by_id"):
		var reactivated = gs.get_or_reactivate_npc_by_id(person_id)
		if reactivated != null:
			return reactivated

	return null

func _person_label(person: Person) -> String:
	if person == null:
		return "Someone"

	var full_name: String = "%s %s" % [str(person.first_name), str(person.last_name)]
	full_name = full_name.strip_edges()

	if full_name == "":
		return "Person #%d" % int(person.id)

	return full_name

func _append_unique_person(out: Array, person: Person) -> void:
	if person == null:
		return

	for existing in out:
		if existing is Person and int(existing.id) == int(person.id):
			return

	out.append(person)

func _append_unique_string(out: Array, value: String) -> void:
	var clean_value: String = str(value).strip_edges()
	if clean_value == "":
		return
	if clean_value in out:
		return
	out.append(clean_value)

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
	out ["version"] = max(CONTRACT_VERSION, int(out.get("version", CONTRACT_VERSION)))
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))

	if typeof(out.get("contract_registry", {})) != TYPE_DICTIONARY:
		out ["contract_registry"] = {}

	if typeof(out.get("interpretation_ledger", [])) != TYPE_ARRAY:
		out ["interpretation_ledger"] = []

	if typeof(out.get("pending_ui_interpretations", [])) != TYPE_ARRAY:
		out ["pending_ui_interpretations"] = []

	if typeof(out.get("last_interpretation_report", {})) != TYPE_DICTIONARY:
		out ["last_interpretation_report"] = {}

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