extends Resource
class_name ScenarioResolver

var gs

func _init(_gs):
	gs = _gs

func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if typeof(gs.scenario_history) != TYPE_ARRAY:
		gs.scenario_history = []
	if typeof(gs.transient_scenario_biases) != TYPE_DICTIONARY:
		gs.transient_scenario_biases = {}

func commit_choice(person: Person, scenario: Dictionary, choice: Dictionary) -> Dictionary:
	_ensure_state()
	if gs == null or person == null:
		return {}

	var scenario_id: String = str(scenario.get("id", "unknown_scenario"))
	var choice_id: String = str(choice.get("id", "unknown_choice"))
	var payloads: Dictionary = choice.get("bias_payloads", {})
	var expiry_payload: Dictionary = payloads.get("expiry", {})
	var expiry_year: int = gs.year + int(expiry_payload.get("years", 1))
	var actor_id: int = int(person.id)

	var committed:= {
		"scenario_id": scenario_id,
		"choice_id": choice_id,
		"year": gs.year,
		"npc_id": actor_id,
		"category": str(scenario.get("category", "general")),
		"payloads": payloads.duplicate(true),
		"expiry_year": expiry_year,
		"followup_hooks": choice.get("followup_hooks", []).duplicate(),
		"source": str(scenario.get("source", "scenario_engine")),
		"asset_arc_family": str(scenario.get("asset_arc_family", "")),
		"asset_arc_step": str(scenario.get("asset_arc_step", "")),
		"asset_repeat_group": str(scenario.get("asset_repeat_group", "")),
		"asset_echoes_world_feed": bool(scenario.get("asset_echoes_world_feed", false)),
		"asset_echoes_memory": bool(scenario.get("asset_echoes_memory", false)),
		"asset_echoes_reputation": bool(scenario.get("asset_echoes_reputation", false)),
		"asset_namespace_preferences": scenario.get("asset_namespace_preferences", {}).duplicate(true),
		"asset_identity_mode": scenario.get("asset_identity_mode", []).duplicate(),
		"asset_weight_status_signals": scenario.get("asset_weight_status_signals", {}).duplicate(true),
		"asset_weight_pressure_profile": scenario.get("asset_weight_pressure_profile", {}).duplicate(true),
		"asset_weight_event_hooks": scenario.get("asset_weight_event_hooks", []).duplicate(),
		"asset_weight_portfolio_tags": scenario.get("asset_weight_portfolio_tags", []).duplicate(),
		"asset_weight_provenance_signals": scenario.get("asset_weight_provenance_signals", {}).duplicate(true),
		"asset_weight_condition_profile": scenario.get("asset_weight_condition_profile", {}).duplicate(true),
		"required_asset_event_hooks": scenario.get("required_asset_event_hooks", []).duplicate(),
		"scenario_prompt": str(scenario.get("prompt", "")),
		"journal_text": str(choice.get("journal_text", "")),
		"choice_label": str(choice.get("label", ""))
	}

	var existing_bucket = gs.transient_scenario_biases.get(actor_id, [])
	var bias_bucket: Array = []
	if typeof(existing_bucket) == TYPE_ARRAY:
		bias_bucket = existing_bucket
	elif typeof(existing_bucket) == TYPE_DICTIONARY and not existing_bucket.is_empty():
		bias_bucket = [existing_bucket]
	else:
		bias_bucket = []

	bias_bucket.append(committed)
	gs.transient_scenario_biases [actor_id] = bias_bucket
	gs.scenario_history.append(_build_scenario_history_entry(person, scenario, choice, committed))

	_mark_cooldown(scenario, gs.year)
	_log_choice_to_journal(person, scenario, choice)
	_emit_scenario_asset_echoes(person, scenario, choice, committed)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCENARIO_CHOICE_MADE, {
			"npc_id": person.id,
			"scenario_id": scenario_id,
			"choice_id": choice_id,
			"category": str(scenario.get("category", "general")),
			"text": str(choice.get("journal_text", "")),
			"source": "scenario_resolver",
			"asset_arc_family": str(committed.get("asset_arc_family", "")),
			"asset_arc_step": str(committed.get("asset_arc_step", "")),
			"asset_repeat_group": str(committed.get("asset_repeat_group", "")),
			"asset_echoes_world_feed": bool(committed.get("asset_echoes_world_feed", false)),
			"asset_echoes_memory": bool(committed.get("asset_echoes_memory", false)),
			"asset_echoes_reputation": bool(committed.get("asset_echoes_reputation", false))
		})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCENARIO_RESOLVED, {
			"npc_id": person.id,
			"scenario_id": scenario_id,
			"choice_id": choice_id,
			"category": str(scenario.get("category", "general")),
			"source": "scenario_resolver",
			"asset_arc_family": str(committed.get("asset_arc_family", "")),
			"asset_arc_step": str(committed.get("asset_arc_step", "")),
			"asset_repeat_group": str(committed.get("asset_repeat_group", ""))
		})

	return committed
func _build_scenario_history_entry(person: Person, scenario: Dictionary, choice: Dictionary, committed: Dictionary) -> Dictionary:
	return {
		"scenario_id": str(committed.get("scenario_id", "")),
		"choice_id": str(committed.get("choice_id", "")),
		"npc_id": int(person.id),
		"year": int(gs.year),
		"category": str(scenario.get("category", "general")),
		"source": str(scenario.get("source", "scenario_engine")),
		"scenario_prompt": str(scenario.get("prompt", "")),
		"choice_label": str(choice.get("label", "")),
		"journal_text": str(choice.get("journal_text", "")),
		"followup_hooks": committed.get("followup_hooks", []).duplicate(),
		"asset_arc_family": str(committed.get("asset_arc_family", "")),
		"asset_arc_step": str(committed.get("asset_arc_step", "")),
		"asset_repeat_group": str(committed.get("asset_repeat_group", "")),
		"asset_echoes_world_feed": bool(committed.get("asset_echoes_world_feed", false)),
		"asset_echoes_memory": bool(committed.get("asset_echoes_memory", false)),
		"asset_echoes_reputation": bool(committed.get("asset_echoes_reputation", false)),
		"asset_namespace_preferences": committed.get("asset_namespace_preferences", {}).duplicate(true),
		"asset_identity_mode": committed.get("asset_identity_mode", []).duplicate(),
		"asset_weight_status_signals": committed.get("asset_weight_status_signals", {}).duplicate(true),
		"asset_weight_pressure_profile": committed.get("asset_weight_pressure_profile", {}).duplicate(true),
		"asset_weight_event_hooks": committed.get("asset_weight_event_hooks", []).duplicate(),
		"asset_weight_portfolio_tags": committed.get("asset_weight_portfolio_tags", []).duplicate(),
		"asset_weight_provenance_signals": committed.get("asset_weight_provenance_signals", {}).duplicate(true),
		"asset_weight_condition_profile": committed.get("asset_weight_condition_profile", {}).duplicate(true),
		"required_asset_event_hooks": committed.get("required_asset_event_hooks", []).duplicate(),
		"payloads": committed.get("payloads", {}).duplicate(true)
	}
func _emit_scenario_asset_echoes(person: Person, scenario: Dictionary, choice: Dictionary, committed: Dictionary) -> void:
	if gs == null or person == null:
		return

	var family: String = str(committed.get("asset_arc_family", "")).strip_edges()
	var step: String = str(committed.get("asset_arc_step", "")).strip_edges()
	if family == "" and step == "":
		return

	var choice_text: String = str(choice.get("journal_text", "")).strip_edges()
	if choice_text == "":
		choice_text = "I made a choice that shaped how I approached that year."

	if bool(committed.get("asset_echoes_world_feed", false)):
		var wf_text:= "🧩 %s’s ownership arc shifted: %s" % [person.first_name, choice_text]
		if gs.world_feed_engine != null:
			gs.push_world_feed(wf_text, {
				"npc_id": int(person.id),
				"category": "assets",
				"event_name": "asset_arc_echo",
				"source": "scenario_resolver",
				"asset_arc_family": family,
				"asset_arc_step": step,
				"asset_repeat_group": str(committed.get("asset_repeat_group", ""))
			})

	if bool(committed.get("asset_echoes_memory", false)) and gs.npc_memory_web_engine != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCENARIO_RESOLVED, {
			"npc_id": int(person.id),
			"text": choice_text,
			"category": str(scenario.get("category", "general")),
			"source": "scenario_resolver_memory_echo",
			"asset_arc_family": family,
			"asset_arc_step": step,
			"asset_repeat_group": str(committed.get("asset_repeat_group", ""))
		})

	if bool(committed.get("asset_echoes_reputation", false)) and gs.reputation_engine != null:
		var rep_payload:= {
			"npc_id": int(person.id),
			"text": choice_text,
			"category": str(scenario.get("category", "general")),
			"source": "scenario_resolver_reputation_echo",
			"asset_arc_family": family,
			"asset_arc_step": step,
			"asset_repeat_group": str(committed.get("asset_repeat_group", ""))
		}
		gs.reputation_engine.on_reputation_event(rep_payload)

func _mark_cooldown(scenario: Dictionary, year_value: int) -> void:
	if gs == null:
		return
	var cooldowns: Dictionary = gs.scenario_state.get("cooldowns", {})
	var cooldown_key: String = str(scenario.get("cooldown_key", scenario.get("id", "")))
	if cooldown_key == "":
		return
	cooldowns [cooldown_key] = year_value
	gs.scenario_state ["cooldowns"] = cooldowns

func _log_choice_to_journal(person: Person, scenario: Dictionary, choice: Dictionary) -> void:
	if gs == null or gs.narrative_engine == null or person == null:
		return

	var journal_text: String = str(choice.get("journal_text", "")).strip_edges()
	if journal_text == "":
		journal_text = "I made a choice that shaped how I approached that year."

	gs.narrative_engine.log_event(person, {
		"type": "text",
		"text": journal_text,
		"event_name": "scenario_choice",
		"category": str(scenario.get("category", "general")),
		"source": "scenario_resolver",
		"scenario_id": str(scenario.get("id", "")),
		"scenario_choice_id": str(choice.get("id", ""))
	})

func get_bias_bundle_for_npc(npc_id: int) -> Array:
	_ensure_state()
	if gs == null or npc_id <= 0:
		return []

	var raw = gs.transient_scenario_biases.get(npc_id, [])
	if typeof(raw) != TYPE_ARRAY:
		return []

	var out: Array = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("expiry_year", gs.year)) < gs.year:
			continue
		out.append(entry)
	return out

func get_namespace_bias_for_npc(npc_id: int, namespace_name: String) -> Array:
	var out: Array = []
	for entry in get_bias_bundle_for_npc(npc_id):
		var payloads: Dictionary = entry.get("payloads", {})
		if payloads.has(namespace_name):
			out.append(payloads [namespace_name])
	return out

func yearly_decay() -> void:
	_ensure_state()
	if gs == null:
		return

	for npc_id in gs.transient_scenario_biases.keys():
		var filtered: Array = []
		var arr = gs.transient_scenario_biases [npc_id]
		if typeof(arr) != TYPE_ARRAY:
			continue
		for entry in arr:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if int(entry.get("expiry_year", gs.year)) >= gs.year:
				filtered.append(entry)
		gs.transient_scenario_biases [npc_id] = filtered