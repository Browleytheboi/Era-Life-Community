extends Resource
class_name CaseOrchestrator

const CONTRACT_VERSION:= 1
var gs
var cases: Dictionary = {}
var case_id_order: Array = []
var active_case_id: String = ""
var ledger: Array = []
var last_report: Dictionary = {}
func _init(_gs = null):
	gs = _gs

func start_player_crime_case(payload: Dictionary = {}) -> Dictionary:
	if gs == null or gs.player == null:
		return { "success": false, "reason": "No player available for crime case."}

	var crime_raw: Variant = payload.get("crime", {})
	var crime: Dictionary = crime_raw if typeof(crime_raw) == TYPE_DICTIONARY else {}

	var crime_event: Dictionary = gs.crime_contract_engine.normalize_crime_event({
		"actor_id": int(gs.player.id),
		"victim_id": int(payload.get("victim_id", -1)),
		"officer_id": int(payload.get("officer_id", -1)),
		"crime_name": str(payload.get("crime_name", crime.get("name", "unknown crime"))),
		"crime_type": str(crime.get("charge_success", payload.get("crime_name", "crime"))),
		"severity": float(crime.get("severity", payload.get("severity", 35.0))) * 20.0,
		"intent": str(payload.get("intent", "financial_gain")),
		"weapon_name": str(payload.get("weapon_name", "")),
		"success_before_arrest": bool(payload.get("success_before_arrest", false)),
		"payout": int(payload.get("payout", 0)),
		"base_sentence_years": int(crime.get("sentence_success", crime.get("base_sentence_years", 1))),
		"violent": bool(crime.get("violent", false)),
		"charges": crime.get("charges", [str(crime.get("charge_success", payload.get("crime_name", "crime")))]),
		"world_id": str(payload.get("world_id", "")),
		"timestamp": int(Time.get_unix_time_from_system())
	})

	var evidence_packet: Dictionary = gs.investigation_layer.build_evidence_packet(crime_event)
	var case_data: Dictionary = gs.crime_contract_engine.create_case_object(crime_event, evidence_packet)

	case_data = _store_case(case_data)
	case_data = advance_case(case_data, "investigating", { "source": "case_orchestrator"})
	case_data = advance_case(case_data, "charged", { "source": "investigation_layer"})

	var verdict_report: Dictionary = gs.justice_system_engine.evaluate_case(case_data)
	if not bool(verdict_report.get("success", false)):
		return verdict_report

	var verdict: Dictionary = verdict_report.get("verdict", {})
	var sentence: Dictionary = verdict_report.get("sentence", {})

	case_data = advance_case(case_data, "trial", { "source": "justice_system_engine"})
	case_data ["verdict"] = verdict.duplicate(true)
	case_data ["sentence"] = sentence.duplicate(true)
	case_data = advance_case(case_data, "verdict", { "verdict": verdict.duplicate(true)})

	if str(verdict.get("outcome", "")) != "guilty":
		case_data = advance_case(case_data, "closed", { "outcome": "acquitted"})
		_store_case(case_data)
		_record_case_history(case_data, false, "acquitted", 0)
		_emit_case_world_event(case_data, "case_acquitted")
		return _popup_result("acquitted", "Justice", "I was found not guilty.", case_data)

	case_data = advance_case(case_data, "sentenced", { "sentence": sentence.duplicate(true)})
	case_data = _execute_sentence(case_data, verdict, sentence)
	_store_case(case_data)

	return _popup_result("convicted", "Justice", _sentence_text(case_data), case_data)

func advance_case(case_data: Dictionary, next_status: String, payload: Dictionary = {}) -> Dictionary:
	var current_status: String = str(case_data.get("status", "pending"))
	var transition: Dictionary = gs.crime_contract_engine.validate_transition(current_status, next_status)

	if not bool(transition.get("valid", false)):
		var failed: Dictionary = gs.crime_contract_engine.append_history(case_data, "invalid_transition_blocked", transition)
		_store_case(failed)
		return failed

	var next_case: Dictionary = case_data.duplicate(true)
	next_case ["status"] = str(next_status)
	next_case = gs.crime_contract_engine.append_history(next_case, "case_transitioned", {
		"from": current_status,
		"to": str(next_status),
		"payload": payload.duplicate(true)
	})

	_emit_bus("case_transitioned", {
		"case_id": str(next_case.get("case_id", "")),
		"from": current_status,
		"to": str(next_status)
	})

	return _store_case(next_case)

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Justice command envelope must be a Dictionary."}

	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload_raw: Variant = envelope.get("payload", {})
	var payload: Dictionary = payload_raw.duplicate(true) if typeof(payload_raw) == TYPE_DICTIONARY else {}

	match command_id:
		"justice.start_case", "case.start", "crime.case.start":
			return start_player_crime_case(payload)
		_:
			return {
				"success": false,
				"reason": "Unsupported justice command '%s'." % command_id
			}

func get_case_rows(_context: Dictionary = {}) -> Array:
	var out: Array = []
	for raw_case_id in cases.keys():
		var case_data: Dictionary = cases.get(raw_case_id, {})
		out.append({
			"label": "%s • %s • %s" % [
				str(case_data.get("case_id", "")),
				str(case_data.get("status", "")),
				str(case_data.get("crime", {}).get("name", case_data.get("crime", {}).get("type", "crime")))
			],
			"kind": "justice_case",
			"case_id": str(case_data.get("case_id", "")),
			"status": str(case_data.get("status", ""))
		})
	return out

func export_state() -> Dictionary:
	return {
		"schema": "eralife.case_orchestrator_state",
		"version": CONTRACT_VERSION,
		"cases": cases.duplicate(true),
		"case_id_order": case_id_order.duplicate(false),
		"active_case_id": active_case_id,
		"ledger": ledger.duplicate(true),
		"last_report": last_report.duplicate(true)
	}
func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "CaseOrchestrator import data must be a Dictionary."
		}

	var cases_raw: Variant = data.get(
		"cases",
		{}
	)
	cases = (
		cases_raw.duplicate(true)
		if typeof(cases_raw) == TYPE_DICTIONARY
		else {}
	)
	active_case_id = str(
		data.get(
			"active_case_id",
			""
		)
	)

	var order_raw: Variant = data.get(
		"case_id_order",
		[]
	)
	case_id_order = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)



	if (
		case_id_order.is_empty()
		and not cases.is_empty()
	):
		case_id_order = cases.keys()

	var ledger_raw: Variant = data.get(
		"ledger",
		[]
	)
	ledger = (
		ledger_raw.duplicate(true)
		if typeof(ledger_raw) == TYPE_ARRAY
		else []
	)

	return {
		"success": true,
		"imported_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func resident_case_cursor_contract(
	cursor: int
) -> Dictionary:
	var safe_cursor: int = maxi(
		0,
		cursor
	)
	var total_count: int = case_id_order.size()

	if safe_cursor >= total_count:
		return {
			"success": true,
			"complete": true,
			"cursor": safe_cursor,
			"next_cursor": safe_cursor,
			"total_count": total_count,
			"case_id": "",
			"case_data": {},
			"read_only": true
		}

	var case_id: String = str(
		case_id_order [
			safe_cursor
		]
	)
	var case_raw: Variant = cases.get(
		case_id,
		{}
	)
	var case_data: Dictionary = (
		(case_raw as Dictionary).duplicate(false)
		if typeof(case_raw) == TYPE_DICTIONARY
		else {}
	)
	var next_cursor: int = safe_cursor + 1

	return {
		"success": true,
		"complete": next_cursor >= total_count,
		"cursor": safe_cursor,
		"next_cursor": next_cursor,
		"total_count": total_count,
		"case_id": case_id,
		"case_data": case_data,
		"read_only": true
	}
func _execute_sentence(
		case_data: Dictionary,
		verdict: Dictionary,
		sentence: Dictionary
) -> Dictionary:
	var next_case: Dictionary = case_data.duplicate(true)
	var sentence_type: String = str(
		sentence.get(
			"type",
			"none"
		)
	).strip_edges().to_lower()

	if sentence_type in [
		"prison",
		"execution"
	]:
		if not bool(
			_safe_dictionary(
				next_case.get(
					"execution_flags",
					{}
				)
			).get(
				"jail_applied",
				false
			)
		):
			var jail_report: Dictionary = (
				gs.jail_engine.execute_booking(
					next_case,
					verdict,
					{
						"holding_reason": (
							"post_verdict_transfer"
						)
					}
				)
			)

			next_case ["execution_flags"] ["jail_applied"] = bool(
				jail_report.get(
					"success",
					false
				)
			)

			next_case = gs.crime_contract_engine.append_history(
				next_case,
				"jail_execution_report",
				jail_report
			)

		if not bool(
			_safe_dictionary(
				next_case.get(
					"execution_flags",
					{}
				)
			).get(
				"prison_applied",
				false
			)
		):
			var prison_report: Dictionary = (
				gs.prison_engine.execute_sentence(
					next_case,
					sentence
				)
			)

			var prison_applied: bool = bool(
				prison_report.get(
					"success",
					false
				)
			)

			next_case ["execution_flags"] ["prison_applied"] = (
				prison_applied
			)

			next_case = gs.crime_contract_engine.append_history(
				next_case,
				"prison_execution_report",
				prison_report
			)








			if (
				prison_applied
				and gs.jail_engine != null
				and gs.jail_engine.has_method(
					"release_from_jail"
				)
			):
				var participants: Dictionary = _safe_dictionary(
					next_case.get(
						"participants",
						{}
					)
				)
				var accused_id: int = int(
					participants.get(
						"accused",
						-1
					)
				)

				if accused_id > 0:
					var transfer_report: Dictionary = (
						gs.jail_engine.release_from_jail(
							accused_id,
							"transferred_to_prison"
						)
					)

					next_case = (
						gs.crime_contract_engine.append_history(
							next_case,
							"jail_to_prison_transfer_report",
							transfer_report
						)
					)



		next_case = advance_case(
			next_case,
			"incarcerated",
			{
				"sentence": sentence.duplicate(true),
				"condemned": sentence_type == "execution"
			}
		)
	else:
		next_case = advance_case(
			next_case,
			"fined_only",
			{
				"sentence": sentence.duplicate(true)
			}
		)

	if not bool(
		_safe_dictionary(
			next_case.get(
				"execution_flags",
				{}
			)
		).get(
			"economic_applied",
			false
		)
	):
		var economic_report: Dictionary = (
			_apply_economic_sentence(
				next_case,
				sentence
			)
		)

		next_case ["execution_flags"] ["economic_applied"] = bool(
			economic_report.get(
				"success",
				false
			)
		)

		next_case = gs.crime_contract_engine.append_history(
			next_case,
			"economic_execution_report",
			economic_report
		)

	_apply_reputation_sentence(
		next_case,
		sentence
	)
	_apply_political_sentence(
		next_case,
		sentence
	)

	_record_case_history(
		next_case,
		true,
		sentence_type,
		int(
			sentence.get(
				"duration",
				0
			)
		)
	)



	_emit_case_life_diary_event(
		next_case,
		"case_sentenced"
	)
	_emit_case_world_event(
		next_case,
		"case_sentenced"
	)

	return next_case

func _apply_economic_sentence(case_data: Dictionary, sentence: Dictionary) -> Dictionary:
	if gs == null or gs.bank_engine == null or gs.player == null:
		return { "success": false, "reason": "BankEngine unavailable."}

	var total_amount: int = max(0, int(sentence.get("fine", 0))) + max(0, int(sentence.get("restitution", 0)))
	if total_amount <= 0:
		return { "success": true, "skipped": true, "reason": "No economic penalty."}

	return gs.bank_engine.request_actor_bank_action(gs.player, {
		"action": "apply_justice_penalty",
		"amount": total_amount,
		"penalty_type": "court_sentence",
		"case_id": str(case_data.get("case_id", "")),
		"reason": "JusticeSystemEngine sentence execution",
		"currency": "USD"
	}, {
		"source": "case_orchestrator",
		"case_id": str(case_data.get("case_id", "")),
		"world_id": str(case_data.get("world_id", ""))
	})

func _apply_reputation_sentence(case_data: Dictionary, sentence: Dictionary) -> void:
	var tags: Array = sentence.get("reputation_tags", []) if typeof(sentence.get("reputation_tags", [])) == TYPE_ARRAY else []
	if tags.is_empty():
		return

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.CRIME_RUMOR_SPREAD, {
			"npc_id": int(case_data.get("participants", {}).get("accused", -1)),
			"case_id": str(case_data.get("case_id", "")),
			"reputation_tags": tags.duplicate(true),
			"text": "A criminal conviction now follows this person."
		})

func _apply_political_sentence(case_data: Dictionary, sentence: Dictionary) -> void:
	var consequences: Array = sentence.get("political_consequences", []) if typeof(sentence.get("political_consequences", [])) == TYPE_ARRAY else []
	if consequences.is_empty():
		return

	var accused_id: int = int(case_data.get("participants", {}).get("accused", -1))
	var actor = gs.get_npc_by_id(accused_id) if gs != null and gs.has_method("get_npc_by_id") else null
	if actor == null:
		return

	for raw_consequence in consequences:
		if typeof(raw_consequence) != TYPE_DICTIONARY:
			continue
		var consequence: Dictionary = raw_consequence
		if bool(consequence.get("can_remove_from_power", false)) and actor.get("is_ruler") != null:
			actor.is_ruler = false
		if bool(consequence.get("can_remove_title", false)) and actor.get("deposed") != null:
			actor.deposed = true

func _record_case_history(case_data: Dictionary, convicted: bool, outcome: String, sentence_years: int = 0) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var record_raw: Variant = gs.scenario_state.get("justice_record", [])
	var record: Array = record_raw if typeof(record_raw) == TYPE_ARRAY else []

	record.append({
		"year": int(gs.year),
		"case_id": str(case_data.get("case_id", "")),
		"crime_name": str(case_data.get("crime", {}).get("name", case_data.get("crime", {}).get("type", ""))),
		"charges": case_data.get("verdict", {}).get("charges", []).duplicate(true) if typeof(case_data.get("verdict", {}).get("charges", [])) == TYPE_ARRAY else [],
		"convicted": convicted,
		"outcome": outcome,
		"sentence_years": sentence_years
	})

	gs.scenario_state ["justice_record"] = record

func _store_case(case_data: Dictionary) -> Dictionary:
	var case_id: String = str(
		case_data.get(
			"case_id",
			""
		)
	)

	if case_id == "":
		return case_data

	var is_new_case: bool = not cases.has(
		case_id
	)

	cases [
		case_id
	] = case_data.duplicate(true)

	if is_new_case:
		case_id_order.append(
			case_id
		)

	active_case_id = case_id

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"justice_cases"
		] = cases.duplicate(true)
		gs.scenario_state [
			"active_justice_case_id"
		] = active_case_id

	return case_data

func _emit_case_world_event(
		case_data: Dictionary,
		event_name: String
) -> void:
	if (
		gs == null
		or not gs.has_method(
			"push_world_feed"
		)
	):
		return

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)
	var accused_id: int = int(
		participants.get(
			"accused",
			-1
		)
	)

	if accused_id <= 0:
		return






	if (
		gs.player != null
		and int(
			gs.player.id
		) == accused_id
	):
		return

	var accused: Person = _resident_case_actor_by_id(
		accused_id
	)
	var text: String = _public_sentence_text(
		case_data,
		accused
	)

	if text.strip_edges() == "":
		return

	gs.push_world_feed(
		text,
		{
			"category": "justice",
			"event_name": event_name,
			"source": "case_orchestrator",
			"case_id": str(
				case_data.get(
					"case_id",
					""
				)
			),
			"npc_id": accused_id,
			"personally_relevant": false,
			"public_perspective": "third_person",
		}
	)
func _emit_case_life_diary_event(
		case_data: Dictionary,
		event_name: String
) -> void:
	if (
		gs == null
		or gs.player == null
		or gs.life_diary_contract_engine == null
		or not gs.life_diary_contract_engine.has_method(
			"emit_diary_intent"
		)
	):
		return

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)
	var accused_id: int = int(
		participants.get(
			"accused",
			-1
		)
	)

	if accused_id != int(
		gs.player.id
	):
		return

	var diary_text: String = _sentence_text(
		case_data
	).strip_edges()

	if diary_text == "":
		return

	gs.life_diary_contract_engine.emit_diary_intent(
		{
			"schema": "eralife.life_diary.intent",
			"version": CONTRACT_VERSION,
			"type": "action_event",
			"actor_id": accused_id,
			"life_diary_text": diary_text,
			"text": diary_text,
			"source": "case_orchestrator",
			"perspective": "first_person",
			"narrator": "self",
			"dedupe_key": (
				"justice:%s:%s"
				% [
					str(
						case_data.get(
							"case_id",
							""
						)
					),
					event_name
				]
			),
			"meta": {
				"event_name": event_name,
				"case_id": str(
					case_data.get(
						"case_id",
						""
					)
				),
			}
		},
		{
			"source": "case_orchestrator.justice_commit",
			"case_id": str(
				case_data.get(
					"case_id",
					""
				)
			),
			"ui_is_renderer_only": true
		}
	)


func _public_sentence_text(
		case_data: Dictionary,
		accused: Person
) -> String:
	var sentence: Dictionary = _safe_dictionary(
		case_data.get(
			"sentence",
			{}
		)
	)
	var verdict: Dictionary = _safe_dictionary(
		case_data.get(
			"verdict",
			{}
		)
	)
	var charges: Array = _safe_array(
		verdict.get(
			"charges",
			[]
		)
	)
	var charge_text: String = (
		", ".join(
			charges
		)
		if not charges.is_empty()
		else "the crime"
	)
	var accused_name: String = "A person"

	if accused != null:
		accused_name = (
			"%s %s"
			% [
				str(
					accused.first_name
				),
				str(
					accused.last_name
				)
			]
		).strip_edges()

		if accused_name == "":
			accused_name = "A person"

	match str(
		sentence.get(
			"type",
			"none"
		)
	).strip_edges().to_lower():
		"prison":
			return (
				"%s was convicted of %s and sentenced to %d years in prison."
				% [
					accused_name,
					charge_text,
					int(
						sentence.get(
							"duration",
							0
						)
					)
				]
			)

		"fine_only":
			return (
				"%s was convicted of %s and ordered to pay fines and restitution."
				% [
					accused_name,
					charge_text
				]
			)

		"execution":
			return (
				"%s was convicted of %s and sentenced to execution."
				% [
					accused_name,
					charge_text
				]
			)

		_:
			return (
				"The case involving %s for %s was resolved."
				% [
					accused_name,
					charge_text
				]
			)

func _emit_bus(event_name: String, payload: Dictionary = {}) -> void:
	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(event_name, payload)
func register_crime_event(
	crime_event: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.crime_contract_engine == null
		or gs.investigation_layer == null
	):
		return {
			"success": false,
			"reason": "crime_case_dependencies_unavailable"
		}

	var evidence_packet: Dictionary = (
		gs.investigation_layer
		.build_evidence_packet(
			crime_event
		)
	)
	var discovered: bool = bool(
		context.get(
			"discovered",
			_safe_dictionary(
				crime_event.get(
					"discovery_contract",
					{}
				)
			).get(
				"discovered",
				false
			)
		)
	)
	var witness_ids: Array = _safe_array(
		context.get(
			"witness_ids",
			[]
		)
	)

	if not discovered:
		evidence_packet ["evidence_strength"] = (
			clampf(
				float(
					evidence_packet.get(
						"evidence_strength",
						0.0
					)
				) * 0.34,
				0.0,
				1.0
			)
		)
	elif witness_ids.is_empty():
		evidence_packet ["evidence_strength"] = (
			clampf(
				float(
					evidence_packet.get(
						"evidence_strength",
						0.0
					)
				) * 0.78,
				0.0,
				1.0
			)
		)

	var case_data: Dictionary = (
		gs.crime_contract_engine
		.create_case_object(
			crime_event,
			evidence_packet
		)
	)

	case_data ["crime_event"] = crime_event.duplicate(true)
	case_data ["discovery_contract"] = _safe_dictionary(
		crime_event.get(
			"discovery_contract",
			{}
		)
	)
	case_data ["interrogation"] = {
		"status": "not_started",
		"response_id": "",
		"questions": [],
		"history": []
	}

	case_data = _store_case(
		case_data
	)

	if discovered:
		case_data = advance_case(
			case_data,
			"investigating",
			{
				"source": (
					"case_orchestrator.register_crime_event"
				),
				"victim_reported": bool(
					context.get(
						"victim_reported",
						false
					)
				),
				"witness_ids": witness_ids.duplicate(true)
			}
		)

	active_case_id = str(
		case_data.get(
			"case_id",
			""
		)
	)
	_store_case(
		case_data
	)

	return {
		"success": true,
		"mode": "crime_case_registered",
		"case_id": active_case_id,
		"case": case_data.duplicate(true),
		"discovered": discovered,
		"interrogation_pending": discovered
	}

func _resolve_interrogation_institutional_power_attempt(
	actor: Person,
	case_data: Dictionary,
	payload: Dictionary,
	evidence_strength: float,
	defense_modifier: float
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "institutional_power_actor_missing"
		}

	var next_case: Dictionary = case_data.duplicate(true)
	var power_kind: String = str(
		payload.get(
			"institutional_power_kind",
			"institutional_office"
		)
	).strip_edges().to_lower()
	var power_label: String = str(
		payload.get(
			"institutional_power_label",
			"Invoke Institutional Power"
		)
	).strip_edges()
	var declared_strength: int = clampi(
		int(
			payload.get(
				"institutional_power_strength",
				0
			)
		),
		0,
		100
	)
	var crime_severity: float = clampf(
		float(
			payload.get(
				"crime_severity",
				0.5
			)
		),
		0.0,
		1.0
	)
	var witness_count: int = maxi(
		0,
		int(
			payload.get(
				"witness_count",
				0
			)
		)
	)
	var interrogation_stage: int = clampi(
		int(
			payload.get(
				"interrogation_stage",
				1
			)
		),
		1,
		3
	)
	var approval_factor: float = clampf(
		float(actor.approval) / 100.0,
		0.0,
		1.0
	)
	var fame_factor: float = clampf(
		float(actor.fame) / 100.0,
		0.0,
		1.0
	)
	var success_chance: float = (
		0.56
		+ float(declared_strength) / 250.0
		+ approval_factor * 0.14
		+ fame_factor * 0.06
		- crime_severity * 0.34
		- float(mini(witness_count, 8)) * 0.025
		- float(interrogation_stage - 1) * 0.07
	)

	if bool(actor.is_ruler):
		success_chance += 0.1
	elif bool(actor.is_royal):
		success_chance += 0.05

	success_chance = clampf(
		success_chance,
		0.08,
		0.94
	)

	var roll: float = randf()
	var succeeded: bool = roll <= success_chance
	var next_evidence_strength: float = evidence_strength
	var next_defense_modifier: float = defense_modifier
	var catastrophic_failure: bool = not succeeded
	var result_text: String = ""
	var charges: Array = _safe_array(
		next_case.get(
			"charges",
			[]
		)
	)

	if succeeded:
		next_evidence_strength = clampf(
			evidence_strength - 0.18,
			0.0,
			1.0
		)
		next_defense_modifier = clampf(
			defense_modifier + 0.2,
			0.0,
			0.6
		)
		result_text = (
			"%s succeeded. Your institutional standing forced the "
			+ "authorities to terminate the interrogation and suppress "
			+ "the active prosecution."
		) % power_label
	else:
		var failure_evidence_bonus: float = clampf(
			float(
				payload.get(
					"institutional_power_failure_evidence_bonus",
					0.25
				)
			),
			0.0,
			0.5
		)
		var failure_defense_penalty: float = clampf(
			float(
				payload.get(
					"institutional_power_failure_defense_penalty",
					0.12
				)
			),
			0.0,
			0.4
		)
		var failure_scandal: int = clampi(
			int(
				payload.get(
					"institutional_power_failure_scandal",
					25
				)
			),
			0,
			100
		)

		next_evidence_strength = clampf(
			evidence_strength + failure_evidence_bonus,
			0.0,
			1.0
		)
		next_defense_modifier = clampf(
			defense_modifier - failure_defense_penalty,
			0.0,
			0.6
		)
		actor.scandal = clampi(
			int(actor.scandal) + failure_scandal,
			0,
			100
		)
		actor.approval = clampi(
			int(actor.approval) - 18,
			0,
			100
		)

		for extra_charge in [
			"obstruction_of_justice",
			"abuse_of_office"
		]:
			if extra_charge not in charges:
				charges.append(extra_charge)

		next_case ["charges"] = charges
		result_text = (
			"%s failed catastrophically. The attempt was recorded as "
			+ "institutional interference, new obstruction and "
			+ "abuse-of-office exposure was added, your scandal rose, "
			+ "and the prosecution's evidence became substantially stronger."
		) % power_label

	next_case ["institutional_power_interference"] = {
		"attempted": true,
		"succeeded": succeeded,
		"catastrophic_failure": catastrophic_failure,
		"power_kind": power_kind,
		"power_label": power_label,
		"declared_strength": declared_strength,
		"success_chance": success_chance,
		"roll": roll,
		"crime_severity": crime_severity,
		"witness_count": witness_count,
		"interrogation_stage": interrogation_stage,
		"evidence_strength_before": evidence_strength,
		"evidence_strength_after": next_evidence_strength,
		"defense_modifier_before": defense_modifier,
		"defense_modifier_after": next_defense_modifier,
		"actor_scandal_after": int(actor.scandal),
		"actor_approval_after": int(actor.approval),
		"resolved_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return {
		"success": true,
		"succeeded": succeeded,
		"catastrophic_failure": catastrophic_failure,
		"result_text": result_text,
		"case": next_case,
		"evidence_strength": next_evidence_strength,
		"defense_modifier": next_defense_modifier,
		"report": (
			next_case [
				"institutional_power_interference"
			] as Dictionary
		).duplicate(true)
	}
func resolve_pending_crime_response(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var case_id: String = str(
		payload.get(
			"case_id",
			""
		)
	).strip_edges()
	var response_id: String = str(
		payload.get(
			"response_id",
			payload.get(
				"option_id",
				"remain_silent"
			)
		)
	).strip_edges().to_lower()
	var interrogation_stage: int = clampi(
		int(
			payload.get(
				"interrogation_stage",
				1
			)
		),
		1,
		3
	)
	var case_data: Dictionary = _safe_dictionary(
		cases.get(
			case_id,
			{}
		)
	)

	if case_data.is_empty():
		return {
			"success": false,
			"reason": "crime_case_not_found",
			"popup_title": "Interrogation",
			"popup_text": "The case no longer exists.",
			"popup_footer": "Tap anywhere to continue."
		}

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)

	if int(
		participants.get(
			"accused",
			-1
		)
	) != int(actor.id):
		return {
			"success": false,
			"reason": "actor_is_not_case_accused"
		}

	if str(
		case_data.get(
			"status",
			"pending"
		)
	) == "investigating":
		case_data = advance_case(
			case_data,
			"interrogation",
			{
				"source": "pending_situations_engine",
				"interrogation_stage": interrogation_stage
			}
		)

	var evidence_packet: Dictionary = _safe_dictionary(
		case_data.get(
			"evidence_packet",
			{}
		)
	)
	var evidence_strength: float = clampf(
		float(
			evidence_packet.get(
				"evidence_strength",
				0.0
			)
		),
		0.0,
		1.0
	)
	var defense_modifier: float = clampf(
		float(
			case_data.get(
				"defense_modifier",
				0.0
			)
		),
		0.0,
		0.6
	)
	var interrogation_result: String = ""
	var fugitive: bool = false
	var plea_requested: bool = bool(
		case_data.get(
			"plea_requested",
			false
		)
	)
	var lawyer_tier: String = str(
		payload.get(
			"lawyer_tier",
			""
		)
	).strip_edges().to_lower()
	var lawyer_cost: int = maxi(
		0,
		int(
			payload.get(
				"lawyer_cost",
				0
			)
		)
	)
	var lawyer_quality: int = clampi(
		int(
			payload.get(
				"lawyer_quality",
				0
			)
		),
		0,
		100
	)
	var lawyer_payment_report: Dictionary = {}
	var institutional_power_report: Dictionary = {}
	var institutional_power_succeeded: bool = false
	var institutional_power_catastrophic_failure: bool = false

	if response_id == "exert_institutional_power":
		var power_resolution: Dictionary = (
			_resolve_interrogation_institutional_power_attempt(
				actor,
				case_data,
				payload,
				evidence_strength,
				defense_modifier
			)
		)

		if not bool(
			power_resolution.get(
				"success",
				false
			)
		):
			return power_resolution

		case_data = _safe_dictionary(
			power_resolution.get(
				"case",
				case_data
			)
		)
		evidence_strength = clampf(
			float(
				power_resolution.get(
					"evidence_strength",
					evidence_strength
				)
			),
			0.0,
			1.0
		)
		defense_modifier = clampf(
			float(
				power_resolution.get(
					"defense_modifier",
					defense_modifier
				)
			),
			0.0,
			0.6
		)
		institutional_power_succeeded = bool(
			power_resolution.get(
				"succeeded",
				false
			)
		)
		institutional_power_catastrophic_failure = bool(
			power_resolution.get(
				"catastrophic_failure",
				false
			)
		)
		institutional_power_report = _safe_dictionary(
			power_resolution.get(
				"report",
				{}
			)
		)
		interrogation_result = str(
			power_resolution.get(
				"result_text",
				"You attempted to exert institutional power."
			)
		)

	elif response_id in [
		"request_counsel",
		"retain_counsel"
	]:
		if lawyer_tier == "":
			lawyer_tier = "public_defender"
			lawyer_cost = 0
			lawyer_quality = 20

		if lawyer_cost > int(actor.bank_balance):
			return {
				"success": false,
				"reason": "insufficient_funds_for_lawyer",
				"popup_title": "Counsel Unavailable",
				"popup_text": (
					"You need $%d to retain this lawyer, "
					+ "but you only have $%d."
				) % [
					lawyer_cost,
					int(actor.bank_balance)
				],
				"popup_footer": (
					"Choose another response or a less expensive lawyer."
				),
				"case": case_data.duplicate(true),
				"interrogation_stage": interrogation_stage,
			}

		if lawyer_cost > 0:
			if gs == null or gs.bank_engine == null:
				return {
					"success": false,
					"reason": "bank_engine_unavailable_for_lawyer",
					"popup_title": "Counsel Unavailable",
					"popup_text": (
						"The payment authority is unavailable."
					),
					"popup_footer": "Choose another response.",
				}

			lawyer_payment_report = (
				gs.bank_engine.request_actor_bank_action(
					actor,
					{
						"action": "apply_justice_penalty",
						"amount": lawyer_cost,
						"penalty_type": "legal_counsel_fee",
						"case_id": case_id,
						"reason": (
							"Criminal defense representation"
						),
						"currency": "USD"
					},
					{
						"source": (
							"case_orchestrator.interrogation_counsel"
						),
						"case_id": case_id,
						"lawyer_tier": lawyer_tier,
						"lawyer_quality": lawyer_quality
					}
				)
			)

			if not bool(
				lawyer_payment_report.get(
					"success",
					false
				)
			):
				return {
					"success": false,
					"reason": "lawyer_payment_failed",
					"popup_title": "Counsel Payment Failed",
					"popup_text": str(
						lawyer_payment_report.get(
							"reason",
							"The lawyer could not be retained."
						)
					),
					"popup_footer": "Choose another response.",
					"payment_report": (
						lawyer_payment_report.duplicate(true)
					),
				}

		defense_modifier = clampf(
			maxf(
				defense_modifier,
				0.04
				+ float(lawyer_quality) / 500.0
			),
			0.0,
			0.6
		)
		case_data ["legal_counsel"] = {
			"tier": lawyer_tier,
			"cost": lawyer_cost,
			"quality": lawyer_quality,
			"retained_at_stage": interrogation_stage,
			"retained_at_ms": int(
				Time.get_ticks_msec()
			),
			"payment_report": (
				lawyer_payment_report.duplicate(true)
			)
		}
		interrogation_result = (
			"You retained %s before continuing the interrogation."
			% lawyer_tier.replace("_", " ")
		)

	else:
		match response_id:
			"cooperate":
				evidence_strength = clampf(
					evidence_strength + 0.05,
					0.0,
					1.0
				)
				interrogation_result = (
					"You cooperated and gave investigators an account."
				)

			"deny", "maintain_denial":
				evidence_strength = clampf(
					evidence_strength
					+ randf_range(
						-0.03,
						0.07
					),
					0.0,
					1.0
				)
				interrogation_result = (
					"You denied the allegation."
				)

			"challenge_evidence":
				evidence_strength = clampf(
					evidence_strength - 0.04,
					0.0,
					1.0
				)
				defense_modifier = clampf(
					defense_modifier + 0.05,
					0.0,
					0.6
				)
				interrogation_result = (
					"You challenged the physical evidence."
				)

			"challenge_witnesses":
				evidence_strength = clampf(
					evidence_strength - 0.03,
					0.0,
					1.0
				)
				defense_modifier = clampf(
					defense_modifier + 0.04,
					0.0,
					0.6
				)
				interrogation_result = (
					"You challenged the witness accounts."
				)

			"claim_accident":
				case_data ["claimed_accident"] = true
				defense_modifier = clampf(
					defense_modifier + 0.08,
					0.0,
					0.6
				)
				interrogation_result = (
					"You claimed the weapon use was accidental."
				)

			"justify_intent":
				evidence_strength = clampf(
					evidence_strength + 0.06,
					0.0,
					1.0
				)
				interrogation_result = (
					"You tried to justify your recorded intent."
				)

			"confess":
				evidence_strength = clampf(
					evidence_strength + 0.22,
					0.0,
					1.0
				)
				case_data ["confession_committed"] = true
				interrogation_result = (
					"You confessed to the weapon crime."
				)

			"seek_plea":
				plea_requested = true
				case_data ["plea_requested"] = true
				defense_modifier = clampf(
					defense_modifier + 0.12,
					0.0,
					0.6
				)
				interrogation_result = (
					"You requested plea negotiations."
				)

			"flee":
				evidence_strength = clampf(
					evidence_strength + 0.14,
					0.0,
					1.0
				)
				fugitive = true
				interrogation_result = (
					"You fled before the interrogation concluded."
				)

				if "Fugitive" not in actor.traits:
					actor.traits.append("Fugitive")

			_:
				defense_modifier = clampf(
					defense_modifier + 0.02,
					0.0,
					0.6
				)
				interrogation_result = "You remained silent."
	evidence_packet ["evidence_strength"] = evidence_strength
	case_data ["evidence_packet"] = evidence_packet.duplicate(true)
	case_data ["evidence"] = _safe_array(
		evidence_packet.get(
			"evidence",
			[]
		)
	)
	case_data ["defense_modifier"] = defense_modifier
	case_data ["plea_requested"] = plea_requested

	var interrogation_raw: Variant = case_data.get(
		"interrogation",
		{}
	)
	var interrogation: Dictionary = (
		(interrogation_raw as Dictionary).duplicate(true)
		if typeof(interrogation_raw) == TYPE_DICTIONARY
		else {}
	)
	var interrogation_history: Array = _safe_array(
		interrogation.get(
			"history",
			[]
		)
	).duplicate(true)
	var crime: Dictionary = _safe_dictionary(
		case_data.get(
			"crime",
			{}
		)
	)
	var crime_event: Dictionary = _safe_dictionary(
		case_data.get(
			"crime_event",
			{}
		)
	)

	interrogation_history.append({
		"stage": interrogation_stage,
		"response_id": response_id,
		"result": interrogation_result,
		"evidence_strength": evidence_strength,
		"defense_modifier": defense_modifier,
		"lawyer_tier": lawyer_tier,
		"lawyer_cost": lawyer_cost,
		"lawyer_quality": lawyer_quality,
		"institutional_power_succeeded": (
			institutional_power_succeeded
		),
		"institutional_power_catastrophic_failure": (
			institutional_power_catastrophic_failure
		),
		"institutional_power_report": (
			institutional_power_report.duplicate(true)
		),
		"fugitive": fugitive,
		"completed_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	interrogation ["status"] = (
		"completed"
		if (
			interrogation_stage >= 3
			or fugitive
			or institutional_power_succeeded
		)
		else "in_progress"
	)
	interrogation ["stage"] = interrogation_stage
	interrogation ["stage_count"] = 3
	interrogation ["response_id"] = response_id
	interrogation ["result"] = interrogation_result
	interrogation ["weapon_method"] = str(
		crime.get(
			"weapon_action_label",
			""
		)
	)
	interrogation ["weapon_name"] = str(
		crime.get(
			"weapon_name",
			""
		)
	)
	interrogation ["body_part"] = str(
		crime.get(
			"body_part",
			""
		)
	)
	interrogation ["history"] = interrogation_history
	interrogation ["completed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	case_data ["interrogation"] = interrogation

	case_data = gs.crime_contract_engine.append_history(
		case_data,
		"interrogation_response_committed",
		{
			"stage": interrogation_stage,
			"response_id": response_id,
			"evidence_strength": evidence_strength,
			"defense_modifier": defense_modifier,
			"lawyer_tier": lawyer_tier,
			"lawyer_cost": lawyer_cost,
			"lawyer_quality": lawyer_quality,
			"plea_requested": plea_requested,
			"fugitive": fugitive
		}
	)
	if institutional_power_succeeded:
		case_data = advance_case(
			case_data,
			"closed",
			{
				"outcome": (
					"suppressed_by_institutional_power"
				),
				"response_id": response_id,
				"interrogation_stage": interrogation_stage,
				"institutional_power_report": (
					institutional_power_report.duplicate(true)
				)
			}
		)

		_store_case(
			case_data
		)
		_emit_case_world_event(
			case_data,
			"case_suppressed_by_institutional_power"
		)

		return {
			"success": true,
			"mode": (
				"crime_case_suppressed_by_institutional_power"
			),
			"text": interrogation_result,
			"popup_title": "Authority Exercised",
			"popup_text": interrogation_result,
			"popup_footer": (
				"The case was closed, but the interference remains "
				+ "part of institutional history."
			),
			"case": case_data.duplicate(true),
			"institutional_power_report": (
				institutional_power_report.duplicate(true)
			),
			"hub_contract_refresh_required": true
		}
	if fugitive:
		case_data = advance_case(
			case_data,
			"escaped",
			{
				"response_id": response_id,
				"interrogation_stage": interrogation_stage
			}
		)

		_store_case(case_data)

		return {
			"success": true,
			"mode": "crime_case_fugitive",
			"text": interrogation_result,
			"popup_title": "Fugitive",
			"popup_text": (
				interrogation_result
				+ "\n\nThe case remains active."
			),
			"popup_footer": (
				"The world will continue responding."
			),
			"case": case_data.duplicate(true),
			"hub_contract_refresh_required": true
		}

	if interrogation_stage < 3:
		_store_case(case_data)

		var next_stage_report: Dictionary = {}

		if (
			gs.pending_situations_engine != null
			and gs.pending_situations_engine.has_method(
				"emit_crime_interrogation_stage_contract"
			)
		):
			next_stage_report = (
				gs.pending_situations_engine
				.emit_crime_interrogation_stage_contract(
					actor,
					crime_event,
					{
						"case_id": case_id,
						"case": case_data.duplicate(true)
					},
					interrogation_stage + 1,
					{
						"source": (
							"case_orchestrator.next_interrogation_stage"
						),
						"response_window_ms": 75000
					}
				)
			)

		return {
			"success": true,
			"mode": "crime_interrogation_stage_completed",
			"text": interrogation_result,
			"popup_title": (
				"Interrogation %d/3 Complete"
				% interrogation_stage
			),
			"popup_text": (
				interrogation_result
				+ "\n\nThe next interrogation stage is now pending."
			),
			"popup_footer": (
				"Open Pending Situations to continue."
			),
			"case": case_data.duplicate(true),
			"interrogation_stage": interrogation_stage,
			"next_interrogation_stage": interrogation_stage + 1,
			"next_stage_report": next_stage_report.duplicate(true),
			"hub_contract_refresh_required": true
		}




	if (
		gs.justice_system_engine == null
		or not gs.justice_system_engine.has_method(
			"evaluate_pretrial_disposition"
		)
	):
		_store_case(case_data)

		return {
			"success": false,
			"reason": "pretrial_disposition_authority_unavailable",
			"popup_title": "Interrogation Complete",
			"popup_text": (
				"The interrogation ended, but the pretrial "
				+ "disposition authority is unavailable."
			),
			"popup_footer": "The case remains preserved.",
			"case": case_data.duplicate(true)
		}

	var pretrial_report: Dictionary = (
		gs.justice_system_engine
		.evaluate_pretrial_disposition(
			case_data
		)
	)

	if not bool(
		pretrial_report.get(
			"success",
			false
		)
	):
		_store_case(case_data)
		return pretrial_report

	case_data [
		"pretrial_disposition"
	] = pretrial_report.duplicate(true)

	case_data = gs.crime_contract_engine.append_history(
		case_data,
		"pretrial_disposition_evaluated",
		pretrial_report
	)

	if not bool(
		pretrial_report.get(
			"arrest_authorized",
			false
		)
	):
		case_data = advance_case(
			case_data,
			"dismissed",
			{
				"source": "justice_system_engine",
				"reason": "probable_cause_not_established",
				"pretrial_disposition": (
					pretrial_report.duplicate(true)
				)
			}
		)
		case_data = advance_case(
			case_data,
			"closed",
			{
				"outcome": "released_without_charge"
			}
		)

		var release_report: Dictionary = {}

		if (
			gs.jail_engine != null
			and gs.jail_engine.has_method(
				"release_from_jail"
			)
		):
			release_report = (
				gs.jail_engine.release_from_jail(
					int(actor.id),
					"released_without_charge"
				)
			)

		case_data [
			"pretrial_release_report"
		] = release_report.duplicate(true)

		_store_case(case_data)
		_record_case_history(
			case_data,
			false,
			"released_without_charge",
			0
		)
		_emit_case_world_event(
			case_data,
			"case_dismissed_before_trial"
		)

		var released_result: Dictionary = _popup_result(
			"released_without_charge",
			"Released",
			(
				"The interrogation ended and the court found "
				+ "insufficient probable cause to hold you for trial."
			),
			case_data
		)

		released_result [
			"interrogation_result"
		] = interrogation_result
		released_result [
			"interrogation_stage"
		] = 3
		released_result [
			"pretrial_disposition"
		] = pretrial_report.duplicate(true)
		released_result [
			"release_report"
		] = release_report.duplicate(true)
		released_result [
			"hub_contract_refresh_required"
		] = true

		return released_result

	case_data = advance_case(
		case_data,
		"charged",
		{
			"source": "interrogation_resolution",
			"response_id": response_id,
			"interrogation_stage": interrogation_stage,
			"plea_requested": plea_requested,
			"pretrial_disposition": (
				pretrial_report.duplicate(true)
			)
		}
	)

	if (
		gs.jail_engine == null
		or not gs.jail_engine.has_method(
			"execute_booking"
		)
	):
		_store_case(case_data)

		return {
			"success": false,
			"reason": "pretrial_booking_authority_unavailable",
			"popup_title": "Arrest Authorized",
			"popup_text": (
				"The court authorized arrest, but the booking "
				+ "authority is unavailable."
			),
			"popup_footer": "The charged case remains preserved.",
			"case": case_data.duplicate(true),
			"pretrial_disposition": (
				pretrial_report.duplicate(true)
			)
		}

	var booking_report: Dictionary = (
		gs.jail_engine.execute_booking(
			case_data,
			{},
			{
				"holding_reason": "awaiting_live_trial",
				"bail_allowed": bool(
					pretrial_report.get(
						"bail_allowed",
						false
					)
				),
				"bail_amount": int(
					pretrial_report.get(
						"bail_amount",
						0
					)
				),
				"pretrial_booking": true
			}
		)
	)

	if not bool(
		booking_report.get(
			"success",
			false
		)
	):
		_store_case(case_data)
		return booking_report

	case_data [
		"pretrial_booking"
	] = booking_report.duplicate(true)

	case_data = gs.crime_contract_engine.append_history(
		case_data,
		"pretrial_booking_committed",
		{
			"booking_report": booking_report.duplicate(true),
			"pretrial_disposition": (
				pretrial_report.duplicate(true)
			)
		}
	)

	_store_case(case_data)

	var trial_result: Dictionary = (
		_queue_live_crime_trial(
			actor,
			case_data,
			-1
		)
	)

	trial_result [
		"interrogation_result"
	] = interrogation_result
	trial_result [
		"interrogation_stage"
	] = 3
	trial_result [
		"pretrial_disposition"
	] = pretrial_report.duplicate(true)
	trial_result [
		"booking_report"
	] = booking_report.duplicate(true)
	trial_result [
		"hub_contract_refresh_required"
	] = true

	return trial_result
func _queue_live_crime_trial(
	actor: Person,
	case_data: Dictionary,
	requested_stage: int = -1
) -> Dictionary:
	if (
		actor == null
		or case_data.is_empty()
		or gs == null
		or gs.pending_situations_engine == null
		or not gs.pending_situations_engine.has_method(
			"emit_live_crime_trial_contract"
		)
	):
		return {
			"success": false,
			"reason": (
				"live_crime_trial_runtime_unavailable"
			),
			"case": case_data.duplicate(true)
		}

	var next_case: Dictionary = (
		case_data.duplicate(true)
	)
	var status: String = str(
		next_case.get(
			"status",
			""
		)
	)



	if (
		status == "charged"
		and not bool(
			next_case.get(
				"pretrial_disposition_acknowledged",
				false
			)
		)
	):
		return (
			gs.pending_situations_engine
			.emit_crime_pretrial_disposition_contract(
				actor,
				next_case,
				true,
				{
					"source": (
						"case_orchestrator."
						+ "post_interrogation_arrest"
					)
				}
			)
		)

	if status == "charged":
		next_case = advance_case(
			next_case,
			"trial",
			{
				"source": "live_crime_trial",
			}
		)

	elif status != "trial":
		return {
			"success": false,
			"reason": (
				"case_not_ready_for_live_trial"
			),
			"status": status,
			"case": next_case.duplicate(true)
		}

	var legal_counsel: Dictionary = _safe_dictionary(
		next_case.get(
			"legal_counsel",
			{}
		)
	)

	var counsel_market: Array = []

	if (
		gs.justice_system_engine != null
		and gs.justice_system_engine.has_method(
			"trial_counsel_market"
		)
	):
		counsel_market = (
			gs.justice_system_engine
			.trial_counsel_market(
				next_case
			)
		)

	var stage: int = requested_stage

	if stage < 0:
		stage = (
			0
			if (
				legal_counsel.is_empty()
				and not counsel_market.is_empty()
			)
			else 1
		)

	var live_trial: Dictionary = _safe_dictionary(
		next_case.get(
			"live_trial",
			{}
		)
	)

	if live_trial.is_empty():
		live_trial = {
			"schema": "eralife.live_crime_trial",
			"version": CONTRACT_VERSION,
			"case_id": str(
				next_case.get(
					"case_id",
					""
				)
			),
			"status": "in_progress",
			"stage": stage,
			"stage_count": 4,
			"defense_score": 0.0,
			"prosecution_score": 0.0,
			"credibility_score": 0.0,
			"sentence_mitigation": 0.0,
			"guilty_plea_committed": false,
			"history": [],
			"started_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	else:
		live_trial ["stage"] = stage
		live_trial ["status"] = "in_progress"

	next_case [
		"live_trial"
	] = live_trial

	next_case = _store_case(
		next_case
	)

	var scenario: Dictionary = (
		_build_live_crime_trial_scenario(
			next_case,
			stage
		)
	)

	if scenario.is_empty():
		return {
			"success": false,
			"reason": (
				"live_crime_trial_scenario_empty"
			),
			"case": next_case.duplicate(true)
		}

	var queue_report: Dictionary = (
		gs.pending_situations_engine
		.emit_live_crime_trial_contract(
			actor,
			scenario,
			next_case,
			{
				"source": (
					"case_orchestrator.live_crime_trial"
				)
			}
		)
	)

	if queue_report.is_empty():
		return {
			"success": false,
			"reason": (
				"live_crime_trial_queue_failed"
			),
			"case": next_case.duplicate(true)
		}

	queue_report ["success"] = bool(
		queue_report.get(
			"success",
			true
		)
	)
	queue_report [
		"live_crime_trial"
	] = true
	queue_report [
		"live_trial_case_id"
	] = str(
		next_case.get(
			"case_id",
			""
		)
	)
	queue_report [
		"live_trial_stage"
	] = stage
	queue_report [
		"case"
	] = next_case.duplicate(true)
	queue_report [
		"queue_as_pending_situation"
	] = true
	queue_report [
		"popup_choices_are_contracts"
	] = true
	queue_report [
		"log_to_diary"
	] = false

	return queue_report
func _build_live_crime_trial_scenario(
	case_data: Dictionary,
	stage: int
) -> Dictionary:
	if case_data.is_empty():
		return {}

	var case_id: String = str(
		case_data.get(
			"case_id",
			""
		)
	)
	var crime: Dictionary = _safe_dictionary(
		case_data.get(
			"crime",
			{}
		)
	)
	var evidence_packet: Dictionary = _safe_dictionary(
		case_data.get(
			"evidence_packet",
			{}
		)
	)
	var crime_name: String = str(
		crime.get(
			"name",
			crime.get(
				"type",
				"Criminal Case"
			)
		)
	)
	var weapon_name: String = str(
		crime.get(
			"weapon_name",
			""
		)
	)
	var body_part: String = str(
		crime.get(
			"body_part",
			""
		)
	).replace(
		"_",
		" "
	)
	var witness_count: int = int(
		crime.get(
			"witness_count",
			0
		)
	)
	var evidence_strength: float = clampf(
		float(
			evidence_packet.get(
				"evidence_strength",
				0.0
			)
		),
		0.0,
		1.0
	)

	var panel_title: String = "TRIAL"
	var prompt: String = ""
	var footer_text: String = (
		"The court record changes with every answer."
	)
	var choices: Array = []

	match stage:
		0:
			panel_title = "PRETRIAL • CHOOSE COUNSEL"
			prompt = (
				"You have been booked and the case is moving "
				+ "to trial. Choose who will represent you."
			)

			var counsel_market: Array = []

			if (
				gs.justice_system_engine != null
				and gs.justice_system_engine.has_method(
					"trial_counsel_market"
				)
			):
				counsel_market = (
					gs.justice_system_engine
					.trial_counsel_market(
						case_data
					)
				)

			for raw_tier in counsel_market:
				var tier: Dictionary = _safe_dictionary(
					raw_tier
				)

				if tier.is_empty():
					continue

				choices.append({
					"id": "retain_%s" % str(
						tier.get(
							"id",
							"counsel"
						)
					),
					"label": str(
						tier.get(
							"label",
							"Retain Counsel"
						)
					),
					"trial_action": "retain_counsel",
					"lawyer_tier": str(
						tier.get(
							"id",
							"counsel"
						)
					),
					"lawyer_cost": int(
						tier.get(
							"cost",
							0
						)
					),
					"lawyer_quality": int(
						tier.get(
							"quality",
							20
						)
					),
					"journal_text": (
						"I selected my representation "
						+ "before trial."
					)
				})

			choices.append({
				"id": "represent_myself",
				"label": "Represent Myself",
				"trial_action": "self_represent",
				"lawyer_tier": "self_represented",
				"lawyer_cost": 0,
				"lawyer_quality": 0,
				"journal_text": (
					"I chose to represent myself at trial."
				)
			})

		1:
			panel_title = "TRIAL 1/4 • ARRAIGNMENT"
			prompt = (
				"You are formally arraigned for %s."
				% crime_name
			)

			if weapon_name != "":
				prompt += (
					"\n\nThe charge records %s targeting the %s."
					% [
						weapon_name,
						body_part
					]
				)

			choices = [
				{
					"id": "plead_not_guilty",
					"label": "Plead Not Guilty",
					"trial_action": "plead_not_guilty",
					"defense_delta": 0.03,
					"journal_text": (
						"I pleaded not guilty at arraignment."
					)
				},
				{
					"id": "request_plea_agreement",
					"label": "Request a Plea Agreement",
					"trial_action": "request_plea",
					"defense_delta": 0.06,
					"prosecution_delta": 0.05,
					"sentence_mitigation_delta": 0.12,
					"journal_text": (
						"I requested a negotiated plea."
					)
				},
				{
					"id": "plead_guilty",
					"label": "Plead Guilty",
					"trial_action": "plead_guilty",
					"prosecution_delta": 0.35,
					"sentence_mitigation_delta": 0.2,
					"journal_text": (
						"I entered a guilty plea."
					)
				}
			]

		2:
			panel_title = "TRIAL 2/4 • PROSECUTION CASE"
			prompt = (
				"The prosecution presents the weapon record, "
				+ "forensic evidence, and witness testimony."
				+ "\n\nEvidence strength: %d%%"
				% int(
					round(
						evidence_strength * 100.0
					)
				)
				+ "\nWitnesses: %d"
				% witness_count
			)

			choices = [
				{
					"id": "challenge_weapon_chain",
					"label": "Challenge the Weapon Evidence",
					"trial_action": "challenge_weapon_evidence",
					"defense_delta": 0.09,
					"credibility_delta": 0.02,
					"journal_text": (
						"My defense challenged the weapon evidence."
					)
				},
				{
					"id": "cross_examine_witnesses",
					"label": "Cross-Examine the Witnesses",
					"trial_action": "challenge_witnesses",
					"defense_delta": (
						0.04
						+ minf(
							float(witness_count),
							4.0
						) * 0.012
					),
					"journal_text": (
						"My defense challenged the witness accounts."
					)
				},
				{
					"id": "stipulate_record",
					"label": "Accept the Recorded Facts",
					"trial_action": "stipulate_evidence",
					"prosecution_delta": 0.08,
					"credibility_delta": 0.03,
					"sentence_mitigation_delta": 0.05,
					"journal_text": (
						"I accepted part of the prosecution record."
					)
				}
			]

		3:
			panel_title = "TRIAL 3/4 • DEFENSE CASE"
			prompt = (
				"The court asks whether you will testify "
				+ "or rely on the existing defense record."
			)
			choices = [
				{
					"id": "testify",
					"label": "Testify in My Own Defense",
					"trial_action": "testify",
					"defense_delta": 0.06,
					"credibility_delta": 0.04,
					"journal_text": (
						"I testified in my own defense."
					)
				},
				{
					"id": "remain_silent_at_trial",
					"label": "Exercise My Right to Remain Silent",
					"trial_action": "remain_silent",
					"defense_delta": 0.03,
					"journal_text": (
						"I did not testify at trial."
					)
				},
				{
					"id": "claim_accident",
					"label": "Argue That It Was an Accident",
					"trial_action": "claim_accident",
					"defense_delta": 0.08,
					"prosecution_delta": 0.04,
					"journal_text": (
						"My defense argued that the weapon use "
						+ "was accidental."
					)
				},
				{
					"id": "claim_self_defense",
					"label": "Argue Self-Defense",
					"trial_action": "claim_self_defense",
					"defense_delta": 0.1,
					"prosecution_delta": 0.05,
					"journal_text": (
						"My defense argued that I acted "
						+ "in self-defense."
					)
				}
			]

		4:
			panel_title = "TRIAL 4/4 • CLOSING ARGUMENTS"
			prompt = (
				"Both sides make their final arguments. "
				+ "The court will decide the verdict after this choice."
			)
			choices = [
				{
					"id": "attack_burden",
					"label": "Argue That the Burden Was Not Met",
					"trial_action": "attack_burden",
					"defense_delta": 0.1,
					"journal_text": (
						"My closing argument attacked the "
						+ "prosecution's burden of proof."
					)
				},
				{
					"id": "assert_innocence",
					"label": "Maintain My Innocence",
					"trial_action": "assert_innocence",
					"defense_delta": 0.05,
					"credibility_delta": 0.03,
					"journal_text": (
						"I maintained my innocence in closing."
					)
				},
				{
					"id": "express_remorse",
					"label": "Express Remorse and Seek Mercy",
					"trial_action": "express_remorse",
					"credibility_delta": 0.05,
					"sentence_mitigation_delta": 0.18,
					"journal_text": (
						"I asked the court for mercy."
					)
				}
			]

		_:
			return {}

	return {
		"id": (
			"live_crime_trial_%s_stage_%d"
			% [
				case_id,
				stage
			]
		),
		"category": "crime_trial",
		"source": "case_orchestrator",
		"resolver_owner": "case_orchestrator",
		"resolver_method": (
			"resolve_live_crime_trial_choice"
		),
		"case_id": case_id,
		"trial_stage": stage,
		"panel_title": panel_title,
		"subtitle": "Live Court Proceeding",
		"prompt": prompt,
		"footer_text": footer_text,
		"accent": "#C8A85A",
		"emoji": "⚖",
		"theme": "crime_trial",
		"choices": choices,
		"surface_timing": "immediate",
		"allows_pre_year_age_up_surface": true,
		"blocks_age_up_before_time_resolves": true,
		"asset_echoes_world_feed": false,
		"asset_echoes_memory": false,
		"asset_echoes_reputation": false
	}
func resolve_live_crime_trial_choice(
	actor: Person,
	scenario: Dictionary,
	choice: Dictionary,
	_committed: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": "live_trial_actor_unavailable"
		}

	var case_id: String = str(
		scenario.get(
			"case_id",
			""
		)
	).strip_edges()
	var stage: int = int(
		scenario.get(
			"trial_stage",
			-1
		)
	)
	var case_data: Dictionary = _safe_dictionary(
		cases.get(
			case_id,
			{}
		)
	)

	if case_data.is_empty():
		return {
			"success": false,
			"reason": "live_trial_case_not_found",
			"case_id": case_id
		}

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)

	if int(
		participants.get(
			"accused",
			-1
		)
	) != int(actor.id):
		return {
			"success": false,
			"reason": "actor_is_not_live_trial_accused",
			"case_id": case_id
		}

	var trial_action: String = str(
		choice.get(
			"trial_action",
			""
		)
	).strip_edges().to_lower()
	var live_trial: Dictionary = _safe_dictionary(
		case_data.get(
			"live_trial",
			{}
		)
	)
	var history: Array = _safe_array(
		live_trial.get(
			"history",
			[]
		)
	).duplicate(true)
	var payment_report: Dictionary = {}

	if trial_action == "retain_counsel":
		var lawyer_tier: String = str(
			choice.get(
				"lawyer_tier",
				"public_defender"
			)
		)
		var lawyer_cost: int = maxi(
			0,
			int(
				choice.get(
					"lawyer_cost",
					0
				)
			)
		)
		var lawyer_quality: int = clampi(
			int(
				choice.get(
					"lawyer_quality",
					20
				)
			),
			0,
			100
		)

		if lawyer_cost > int(actor.bank_balance):
			var insufficient_report: Dictionary = (
				_queue_live_crime_trial(
					actor,
					case_data,
					0
				)
			)
			insufficient_report ["text"] = (
				"You need $%d to retain that lawyer, "
				+ "but you currently have $%d."
			) % [
				lawyer_cost,
				int(actor.bank_balance)
			]
			insufficient_report [
				"panel_title"
			] = "PRETRIAL • COUNSEL PAYMENT"
			return insufficient_report

		if lawyer_cost > 0:
			if (
				gs.bank_engine == null
				or not gs.bank_engine.has_method(
					"request_actor_bank_action"
				)
			):
				return {
					"success": false,
					"reason": (
						"bank_engine_unavailable_for_trial_counsel"
					)
				}

			payment_report = (
				gs.bank_engine.request_actor_bank_action(
					actor,
					{
						"action": "apply_justice_penalty",
						"amount": lawyer_cost,
						"penalty_type": (
							"legal_counsel_fee"
						),
						"case_id": case_id,
						"reason": (
							"Pretrial criminal defense representation"
						),
						"currency": "USD"
					},
					{
						"source": (
							"case_orchestrator.live_trial_counsel"
						),
						"case_id": case_id,
						"lawyer_tier": lawyer_tier,
						"lawyer_quality": lawyer_quality
					}
				)
			)

			if not bool(
				payment_report.get(
					"success",
					false
				)
			):
				var payment_retry: Dictionary = (
					_queue_live_crime_trial(
						actor,
						case_data,
						0
					)
				)
				payment_retry ["text"] = (
					"The counsel payment failed. "
					+ "Choose another representation option."
				)
				payment_retry [
					"payment_report"
				] = payment_report.duplicate(true)
				return payment_retry

		case_data ["legal_counsel"] = {
			"tier": lawyer_tier,
			"cost": lawyer_cost,
			"quality": lawyer_quality,
			"retained_at_ms": int(
				Time.get_ticks_msec()
			),
			"payment_report": (
				payment_report.duplicate(true)
			)
		}
		case_data ["defense_modifier"] = clampf(
			maxf(
				float(
					case_data.get(
						"defense_modifier",
						0.0
					)
				),
				0.04
				+ float(lawyer_quality) / 500.0
			),
			0.0,
			0.6
		)

	elif trial_action == "self_represent":
		case_data ["legal_counsel"] = {
			"tier": "self_represented",
			"cost": 0,
			"quality": 0,
			"retained_at_ms": int(
				Time.get_ticks_msec()
			),
			"payment_report": {}
		}

	else:
		live_trial ["defense_score"] = clampf(
			float(
				live_trial.get(
					"defense_score",
					0.0
				)
			) + float(
				choice.get(
					"defense_delta",
					0.0
				)
			),
			0.0,
			0.45
		)
		live_trial [
			"prosecution_score"
		] = clampf(
			float(
				live_trial.get(
					"prosecution_score",
					0.0
				)
			) + float(
				choice.get(
					"prosecution_delta",
					0.0
				)
			),
			0.0,
			0.45
		)
		live_trial ["credibility_score"] = clampf(
			float(
				live_trial.get(
					"credibility_score",
					0.0
				)
			) + float(
				choice.get(
					"credibility_delta",
					0.0
				)
			),
			-0.2,
			0.2
		)
		live_trial [
			"sentence_mitigation"
		] = clampf(
			float(
				live_trial.get(
					"sentence_mitigation",
					0.0
				)
			) + float(
				choice.get(
					"sentence_mitigation_delta",
					0.0
				)
			),
			0.0,
			0.5
		)

		match trial_action:
			"plead_guilty":
				live_trial [
					"guilty_plea_committed"
				] = true

			"request_plea":
				case_data ["plea_requested"] = true

			"claim_accident":
				case_data ["claimed_accident"] = true

			"claim_self_defense":
				case_data [
					"claimed_self_defense"
				] = true

			"testify":
				var testimony_quality: float = clampf(
					(
						float(actor.smarts)
						+ float(actor.mental_health)
					) / 200.0,
					0.0,
					1.0
				)

				live_trial [
					"defense_score"
				] = clampf(
					float(
						live_trial.get(
							"defense_score",
							0.0
						)
					) + testimony_quality * 0.05,
					0.0,
					0.45
				)
				live_trial [
					"credibility_score"
				] = clampf(
					float(
						live_trial.get(
							"credibility_score",
							0.0
						)
					) + (
						testimony_quality - 0.5
					) * 0.08,
					-0.2,
					0.2
				)

	history.append({
		"stage": stage,
		"choice_id": str(
			choice.get(
				"id",
				trial_action
			)
		),
		"trial_action": trial_action,
		"label": str(
			choice.get(
				"label",
				""
			)
		),
		"defense_score": float(
			live_trial.get(
				"defense_score",
				0.0
			)
		),
		"prosecution_score": float(
			live_trial.get(
				"prosecution_score",
				0.0
			)
		),
		"credibility_score": float(
			live_trial.get(
				"credibility_score",
				0.0
			)
		),
		"sentence_mitigation": float(
			live_trial.get(
				"sentence_mitigation",
				0.0
			)
		),
		"completed_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	live_trial ["history"] = history
	live_trial ["stage"] = stage
	live_trial ["last_action"] = trial_action
	live_trial ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	case_data ["live_trial"] = live_trial

	case_data = gs.crime_contract_engine.append_history(
		case_data,
		"live_trial_choice_committed",
		{
			"stage": stage,
			"trial_action": trial_action,
			"choice": choice.duplicate(true),
			"payment_report": (
				payment_report.duplicate(true)
			)
		}
	)
	case_data = _store_case(case_data)

	var next_stage: int = stage + 1

	if (
		stage == 1
		and bool(
			live_trial.get(
				"guilty_plea_committed",
				false
			)
		)
	):


		next_stage = 4

	if stage < 4:
		return _queue_live_crime_trial(
			actor,
			case_data,
			next_stage
		)

	return _finalize_live_crime_trial(
		case_data
	)
func _finalize_live_crime_trial(
	case_data: Dictionary
) -> Dictionary:
	if (
		case_data.is_empty()
		or gs == null
		or gs.justice_system_engine == null
	):
		return {
			"success": false,
			"reason": "live_trial_finalization_unavailable"
		}

	var verdict_report: Dictionary = (
		gs.justice_system_engine.evaluate_case(
			case_data
		)
	)

	if not bool(
		verdict_report.get(
			"success",
			false
		)
	):
		_store_case(case_data)
		return verdict_report

	var verdict: Dictionary = _safe_dictionary(
		verdict_report.get(
			"verdict",
			{}
		)
	)
	var sentence: Dictionary = _safe_dictionary(
		verdict_report.get(
			"sentence",
			{}
		)
	)
	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)
	var accused_id: int = int(
		participants.get(
			"accused",
			-1
		)
	)
	var live_trial: Dictionary = _safe_dictionary(
		case_data.get(
			"live_trial",
			{}
		)
	)

	live_trial ["status"] = "completed"
	live_trial ["stage"] = 4
	live_trial ["verdict"] = verdict.duplicate(true)
	live_trial ["decision_trace"] = _safe_dictionary(
		verdict_report.get(
			"decision_trace",
			{}
		)
	)
	live_trial ["completed_at_ms"] = int(
		Time.get_ticks_msec()
	)

	case_data ["live_trial"] = live_trial
	case_data ["verdict"] = verdict.duplicate(true)
	case_data ["sentence"] = sentence.duplicate(true)
	case_data = advance_case(
		case_data,
		"verdict",
		{
			"source": "live_crime_trial",
			"verdict": verdict.duplicate(true),
			"decision_trace": _safe_dictionary(
				verdict_report.get(
					"decision_trace",
					{}
				)
			)
		}
	)

	if str(
		verdict.get(
			"outcome",
			""
		)
	) != "guilty":
		var release_report: Dictionary = {}

		if (
			gs.jail_engine != null
			and gs.jail_engine.has_method(
				"release_from_jail"
			)
			and accused_id > 0
		):
			release_report = (
				gs.jail_engine.release_from_jail(
					accused_id,
					"acquitted_at_live_trial"
				)
			)

		case_data [
			"trial_release_report"
		] = release_report.duplicate(true)
		case_data = advance_case(
			case_data,
			"closed",
			{
				"outcome": "acquitted",
				"release_report": (
					release_report.duplicate(true)
				)
			}
		)

		_store_case(case_data)
		_record_case_history(
			case_data,
			false,
			"acquitted",
			0
		)
		_emit_case_world_event(
			case_data,
			"case_acquitted"
		)

		var acquitted_result: Dictionary = _popup_result(
			"acquitted",
			"NOT GUILTY",
			(
				"The court found you not guilty. "
				+ "You were released from pretrial custody."
			),
			case_data
		)

		acquitted_result [
			"type"
		] = "crime_trial_complete"
		acquitted_result [
			"live_trial_complete"
		] = true
		acquitted_result [
			"release_report"
		] = release_report.duplicate(true)
		acquitted_result [
			"decision_trace"
		] = _safe_dictionary(
			verdict_report.get(
				"decision_trace",
				{}
			)
		)
		acquitted_result [
			"hub_contract_refresh_required"
		] = true
		acquitted_result [
			"life_diary_text"
		] = "I was found not guilty at trial."

		return acquitted_result

	case_data = advance_case(
		case_data,
		"sentenced",
		{
			"source": "live_crime_trial",
			"sentence": sentence.duplicate(true)
		}
	)
	case_data = _execute_sentence(
		case_data,
		verdict,
		sentence
	)

	var sentence_type: String = str(
		sentence.get(
			"type",
			"none"
		)
	).strip_edges().to_lower()
	var noncustodial_release_report: Dictionary = {}

	if (
		sentence_type == "fine_only"
		and gs.jail_engine != null
		and gs.jail_engine.has_method(
			"release_from_jail"
		)
		and accused_id > 0
	):
		noncustodial_release_report = (
			gs.jail_engine.release_from_jail(
				accused_id,
				"noncustodial_sentence"
			)
		)
		case_data [
			"trial_release_report"
		] = (
			noncustodial_release_report.duplicate(true)
		)

		if str(
			case_data.get(
				"status",
				""
			)
		) == "fined_only":
			case_data = advance_case(
				case_data,
				"closed",
				{
					"outcome": "fine_completed",
					"release_report": (
						noncustodial_release_report
						.duplicate(true)
					)
				}
			)

	_store_case(case_data)

	var convicted_result: Dictionary = _popup_result(
		"convicted",
		"GUILTY",
		_sentence_text(case_data),
		case_data
	)

	convicted_result [
		"type"
	] = "crime_trial_complete"
	convicted_result [
		"live_trial_complete"
	] = true
	convicted_result [
		"decision_trace"
	] = _safe_dictionary(
		verdict_report.get(
			"decision_trace",
			{}
		)
	)
	convicted_result [
		"release_report"
	] = noncustodial_release_report.duplicate(true)
	convicted_result [
		"hub_contract_refresh_required"
	] = true
	convicted_result [
		"life_diary_text"
	] = (
		"I was found guilty at trial. "
		+ _sentence_text(case_data)
	)

	return convicted_result
func mark_case_executed(
	case_id: String,
	execution_report: Dictionary
) -> Dictionary:
	var case_data: Dictionary = _safe_dictionary(
		cases.get(
			case_id,
			{}
		)
	)

	if case_data.is_empty():
		return {
			"success": false,
			"reason": "case_not_found"
		}

	if str(
		case_data.get(
			"status",
			""
		)
	) != "incarcerated":
		return {
			"success": false,
			"reason": "case_is_not_condemned_incarceration"
		}

	case_data = advance_case(
		case_data,
		"executed",
		execution_report
	)
	case_data = advance_case(
		case_data,
		"closed",
		{
			"execution_report": (
				execution_report.duplicate(true)
			)
		}
	)
	_store_case(
		case_data
	)

	return {
		"success": true,
		"case": case_data.duplicate(true)
	}
func _sentence_text(case_data: Dictionary) -> String:
	var sentence: Dictionary = case_data.get("sentence", {}) if typeof(case_data.get("sentence", {})) == TYPE_DICTIONARY else {}
	var verdict: Dictionary = case_data.get("verdict", {}) if typeof(case_data.get("verdict", {})) == TYPE_DICTIONARY else {}
	var charges: Array = verdict.get("charges", []) if typeof(verdict.get("charges", [])) == TYPE_ARRAY else []
	var charge_text: String = ", ".join(charges) if not charges.is_empty() else "the crime"

	match str(sentence.get("type", "none")):
		"prison":
			return "I was convicted of %s and sentenced to %d years in prison." % [charge_text, int(sentence.get("duration", 0))]
		"fine_only":
			return "I was convicted of %s and ordered to pay fines and restitution." % charge_text
		"execution":
			return "I was convicted of %s and sentenced to execution." % charge_text
		_:
			return "The case for %s was resolved." % charge_text

func _popup_result(
	result_key: String,
	title: String,
	text: String,
	case_data: Dictionary
) -> Dictionary:
	last_report = {
		"success": true,
		"result": result_key,
		"case_id": str(
			case_data.get(
				"case_id",
				""
			)
		),
		"case": case_data.duplicate(true),
		"text": text,
		"popup_title": title,
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue."
	}

	if (
		result_key == "released_without_charge"
		and gs != null
		and gs.pending_situations_engine != null
		and gs.pending_situations_engine.has_method(
			"emit_crime_pretrial_disposition_contract"
		)
	):
		var participants: Dictionary = _safe_dictionary(
			case_data.get(
				"participants",
				{}
			)
		)

		var actor: Person = _resident_case_actor_by_id(
			int(
				participants.get(
					"accused",
					-1
				)
			)
		)

		if actor != null:
			last_report [
				"followup_pending_contract_report"
			] = (
				gs.pending_situations_engine
				.emit_crime_pretrial_disposition_contract(
					actor,
					case_data,
					false,
					{
						"source": (
							"case_orchestrator."
							+ "released_without_charge"
						)
					}
				)
			)

	ledger.append(
		last_report.duplicate(true)
	)

	return last_report.duplicate(true)
func _resident_case_actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		var found: Variant = gs.get_npc_by_id(
			actor_id
		)

		if found is Person:
			return found as Person

	return null
func resolve_pretrial_disposition_choice(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": (
				"pretrial_disposition_actor_unavailable"
			)
		}

	var case_id: String = str(
		payload.get(
			"case_id",
			""
		)
	).strip_edges()

	var case_data: Dictionary = _safe_dictionary(
		cases.get(
			case_id,
			{}
		)
	)

	if case_data.is_empty():
		return {
			"success": false,
			"reason": (
				"pretrial_disposition_case_not_found"
			),
			"case_id": case_id
		}

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)

	if int(
		participants.get(
			"accused",
			-1
		)
	) != int(
		actor.id
	):
		return {
			"success": false,
			"reason": (
				"actor_is_not_case_accused"
			)
		}

	var action: String = str(
		payload.get(
			"action",
			payload.get(
				"option_id",
				""
			)
		)
	).strip_edges().to_lower()

	var pretrial: Dictionary = _safe_dictionary(
		case_data.get(
			"pretrial_disposition",
			{}
		)
	)

	var arrested: bool = bool(
		pretrial.get(
			"arrest_authorized",
			false
		)
	)

	if not arrested:
		var release_text: String = (
			"You left custody after the case was dismissed "
			+ "without a criminal charge."
		)

		if action == "call_someone":
			release_text = (
				"You called someone you trusted and then "
				+ "left custody after being released without charge."
			)

		elif action == "leave_silently":
			release_text = (
				"You said nothing else and left custody "
				+ "after being released without charge."
			)

		return {
			"success": true,
			"mode": (
				"released_without_charge_acknowledged"
			),
			"case_id": case_id,
			"text": release_text,
			"popup_title": "Released",
			"popup_text": release_text,
			"popup_footer": (
				"The case is closed."
			)
		}

	case_data [
		"pretrial_disposition_acknowledged"
	] = true
	case_data [
		"pretrial_disposition_choice"
	] = action

	case_data = gs.crime_contract_engine.append_history(
		case_data,
		"pretrial_disposition_acknowledged",
		{
			"choice": action,
			"actor_id": int(
				actor.id
			)
		}
	)

	_store_case(
		case_data
	)

	return _queue_live_crime_trial(
		actor,
		case_data,
		-1
	)


func resolve_pending_live_crime_trial_choice(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": (
				"live_trial_actor_unavailable"
			)
		}

	var case_id: String = str(
		payload.get(
			"case_id",
			""
		)
	).strip_edges()

	var stage: int = int(
		payload.get(
			"trial_stage",
			-1
		)
	)

	var case_data: Dictionary = _safe_dictionary(
		cases.get(
			case_id,
			{}
		)
	)

	if case_data.is_empty():
		return {
			"success": false,
			"reason": (
				"live_trial_case_not_found"
			),
			"case_id": case_id
		}

	var scenario: Dictionary = (
		_build_live_crime_trial_scenario(
			case_data,
			stage
		)
	)

	if scenario.is_empty():
		return {
			"success": false,
			"reason": (
				"live_trial_scenario_unavailable"
			)
		}

	var requested_choice_id: String = str(
		payload.get(
			"trial_choice_id",
			payload.get(
				"option_id",
				""
			)
		)
	).strip_edges()

	var trusted_choice: Dictionary = {}

	for raw_choice in _safe_array(
		scenario.get(
			"choices",
			[]
		)
	):
		var choice: Dictionary = _safe_dictionary(
			raw_choice
		)

		if str(
			choice.get(
				"id",
				""
			)
		) != requested_choice_id:
			continue

		trusted_choice = choice
		break

	if trusted_choice.is_empty():
		return {
			"success": false,
			"reason": (
				"live_trial_choice_not_found"
			),
			"choice_id": requested_choice_id
		}



	return resolve_live_crime_trial_choice(
		actor,
		scenario,
		trusted_choice,
		{}
	)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []