extends Resource
class_name JusticeSystemEngine

const CONTRACT_VERSION:= 1

var gs
var ledger: Array = []
var last_verdict: Dictionary = {}

func _init(_gs = null):
	gs = _gs
func evaluate_pretrial_disposition(
	case_data: Dictionary = {}
) -> Dictionary:
	if (
		typeof(case_data) != TYPE_DICTIONARY
		or case_data.is_empty()
	):
		return {
			"success": false,
			"reason": (
				"JusticeSystemEngine needs a CaseObject "
				+ "for pretrial disposition."
			)
		}

	var legal_system_id: String = str(
		case_data.get(
			"legal_system",
			"modern_democracy"
		)
	)
	var legal_system: Dictionary = {}

	if (
		gs != null
		and gs.crime_contract_engine != null
	):
		legal_system = (
			gs.crime_contract_engine.get_legal_system(
				legal_system_id
			)
		)

	var crime_raw: Variant = case_data.get(
		"crime",
		{}
	)
	var crime: Dictionary = (
		crime_raw as Dictionary
		if typeof(crime_raw) == TYPE_DICTIONARY
		else {}
	)
	var evidence_raw: Variant = case_data.get(
		"evidence_packet",
		{}
	)
	var evidence_packet: Dictionary = (
		evidence_raw as Dictionary
		if typeof(evidence_raw) == TYPE_DICTIONARY
		else {}
	)
	var crime_event_raw: Variant = case_data.get(
		"crime_event",
		{}
	)
	var crime_event: Dictionary = (
		crime_event_raw as Dictionary
		if typeof(crime_event_raw) == TYPE_DICTIONARY
		else {}
	)
	var discovery_raw: Variant = crime_event.get(
		"discovery_contract",
		case_data.get(
			"discovery_contract",
			{}
		)
	)
	var discovery: Dictionary = (
		discovery_raw as Dictionary
		if typeof(discovery_raw) == TYPE_DICTIONARY
		else {}
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
	var severity: float = clampf(
		float(
			crime.get(
				"severity",
				0.35
			)
		),
		0.0,
		1.0
	)
	var burden: float = clampf(
		float(
			legal_system.get(
				"burden_of_proof",
				0.68
			)
		),
		0.05,
		0.95
	)
	var witness_count: int = maxi(
		int(
			crime.get(
				"witness_count",
				0
			)
		),
		int(
			discovery.get(
				"witness_count",
				0
			)
		)
	)
	var victim_reported: bool = bool(
		crime.get(
			"victim_reported",
			discovery.get(
				"victim_reported",
				false
			)
		)
	)
	var target_died: bool = bool(
		crime.get(
			"target_died",
			false
		)
	)
	var confession_committed: bool = bool(
		case_data.get(
			"confession_committed",
			false
		)
	)

	var probable_cause_score: float = evidence_strength
	probable_cause_score += severity * 0.08
	probable_cause_score += (
		0.18
		if confession_committed
		else 0.0
	)
	probable_cause_score += (
		mini(
			witness_count,
			4
		) * 0.035
	)
	probable_cause_score += (
		0.06
		if victim_reported
		else 0.0
	)
	probable_cause_score += (
		0.06
		if target_died
		else 0.0
	)
	probable_cause_score = clampf(
		probable_cause_score,
		0.0,
		1.0
	)

	var probable_cause_threshold: float = clampf(
		burden * 0.72 - (
			0.03
			if bool(
				crime.get(
					"violent",
					false
				)
			)
			else 0.0
		),
		0.24,
		0.58
	)
	var arrest_authorized: bool = (
		probable_cause_score
		>= probable_cause_threshold
	)
	var bail_allowed: bool = (
		arrest_authorized
		and bool(
			legal_system.get(
				"allows_bail",
				false
			)
		)
	)
	var bail_amount: int = (
		int(
			round(
				500.0
				+ severity * 9000.0
				+ evidence_strength * 4500.0
			)
		)
		if bail_allowed
		else 0
	)

	return {
		"success": true,
		"case_id": str(
			case_data.get(
				"case_id",
				""
			)
		),
		"legal_system": legal_system_id,
		"arrest_authorized": arrest_authorized,
		"release_authorized": not arrest_authorized,
		"probable_cause_score": probable_cause_score,
		"probable_cause_threshold": probable_cause_threshold,
		"evidence_strength": evidence_strength,
		"severity": severity,
		"witness_count": witness_count,
		"victim_reported": victim_reported,
		"target_died": target_died,
		"confession_committed": confession_committed,
		"bail_allowed": bail_allowed,
		"bail_amount": bail_amount,
		"evaluated_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func trial_counsel_market(
	case_data: Dictionary = {}
) -> Array:
	var legal_system_id: String = str(
		case_data.get(
			"legal_system",
			"modern_democracy"
		)
	).strip_edges().to_lower()

	match legal_system_id:
		"industrial_court":
			return [
				{
					"id": "public_solicitor",
					"label": "Use the Public Solicitor — Free",
					"cost": 0,
					"quality": 20
				},
				{
					"id": "local_defense_attorney",
					"label": "Hire a Local Defense Attorney — $750",
					"cost": 750,
					"quality": 36
				},
				{
					"id": "experienced_barrister",
					"label": "Hire an Experienced Barrister — $5,000",
					"cost": 5000,
					"quality": 62
				},
				{
					"id": "elite_industrial_counsel",
					"label": "Hire Elite Trial Counsel — $20,000",
					"cost": 20000,
					"quality": 86
				}
			]

		"modern_democracy":
			return [
				{
					"id": "public_defender",
					"label": "Use a Public Defender — Free",
					"cost": 0,
					"quality": 20
				},
				{
					"id": "junior_defense_lawyer",
					"label": "Hire a Junior Defense Lawyer — $2,500",
					"cost": 2500,
					"quality": 40
				},
				{
					"id": "experienced_criminal_lawyer",
					"label": "Hire an Experienced Lawyer — $12,000",
					"cost": 12000,
					"quality": 65
				},
				{
					"id": "elite_trial_counsel",
					"label": "Hire Elite Trial Counsel — $50,000",
					"cost": 50000,
					"quality": 90
				}
			]

		"future_tribunal":
			return [
				{
					"id": "public_defense_ai",
					"label": "Use Public Defense AI — Free",
					"cost": 0,
					"quality": 25
				},
				{
					"id": "licensed_synth_counsel",
					"label": "Hire Licensed Synth-Counsel — $5,000",
					"cost": 5000,
					"quality": 47
				},
				{
					"id": "quantum_trial_specialist",
					"label": "Hire a Quantum Trial Specialist — $25,000",
					"cost": 25000,
					"quality": 74
				},
				{
					"id": "sovereign_legal_architect",
					"label": "Hire a Sovereign Legal Architect — $100,000",
					"cost": 100000,
					"quality": 96
				}
			]

		_:


			return []
func evaluate_case(
	case_data: Dictionary = {}
) -> Dictionary:
	if (
		typeof(case_data) != TYPE_DICTIONARY
		or case_data.is_empty()
	):
		return {
			"success": false,
			"reason": (
				"JusticeSystemEngine needs a CaseObject."
			)
		}

	var legal_system_id: String = str(
		case_data.get(
			"legal_system",
			"modern_democracy"
		)
	)
	var legal_system: Dictionary = {}

	if (
		gs != null
		and gs.crime_contract_engine != null
	):
		legal_system = (
			gs.crime_contract_engine.get_legal_system(
				legal_system_id
			)
		)

	var crime_raw: Variant = case_data.get(
		"crime",
		{}
	)
	var crime: Dictionary = (
		crime_raw as Dictionary
		if typeof(crime_raw) == TYPE_DICTIONARY
		else {}
	)
	var evidence_raw: Variant = case_data.get(
		"evidence_packet",
		{}
	)
	var evidence_packet: Dictionary = (
		evidence_raw as Dictionary
		if typeof(evidence_raw) == TYPE_DICTIONARY
		else {}
	)
	var participants_raw: Variant = case_data.get(
		"participants",
		{}
	)
	var participants: Dictionary = (
		participants_raw as Dictionary
		if typeof(participants_raw) == TYPE_DICTIONARY
		else {}
	)
	var counsel_raw: Variant = case_data.get(
		"legal_counsel",
		{}
	)
	var legal_counsel: Dictionary = (
		counsel_raw as Dictionary
		if typeof(counsel_raw) == TYPE_DICTIONARY
		else {}
	)
	var trial_raw: Variant = case_data.get(
		"live_trial",
		{}
	)
	var live_trial: Dictionary = (
		trial_raw as Dictionary
		if typeof(trial_raw) == TYPE_DICTIONARY
		else {}
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
	var severity: float = clampf(
		float(
			crime.get(
				"severity",
				0.35
			)
		),
		0.0,
		1.0
	)
	var burden: float = clampf(
		float(
			legal_system.get(
				"burden_of_proof",
				0.68
			)
		),
		0.05,
		0.95
	)
	var corruption: float = clampf(
		float(
			legal_system.get(
				"corruption",
				0.2
			)
		),
		0.0,
		1.0
	)
	var due_process: float = clampf(
		float(
			legal_system.get(
				"due_process",
				0.6
			)
		),
		0.0,
		1.0
	)
	var prior_convictions: int = (
		_count_prior_convictions(
			int(
				participants.get(
					"accused",
					-1
				)
			)
		)
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
	var counsel_quality: float = clampf(
		float(
			legal_counsel.get(
				"quality",
				0
			)
		) / 100.0,
		0.0,
		1.0
	)
	var counsel_modifier: float = (
		counsel_quality * 0.18
	)
	var trial_defense_score: float = clampf(
		float(
			live_trial.get(
				"defense_score",
				0.0
			)
		),
		0.0,
		0.45
	)
	var trial_prosecution_score: float = clampf(
		float(
			live_trial.get(
				"prosecution_score",
				0.0
			)
		),
		0.0,
		0.45
	)
	var credibility_score: float = clampf(
		float(
			live_trial.get(
				"credibility_score",
				0.0
			)
		),
		-0.2,
		0.2
	)
	var confession_pressure: float = (
		0.22
		if bool(
			case_data.get(
				"confession_committed",
				false
			)
		)
		else 0.0
	)
	var guilty_plea_committed: bool = bool(
		live_trial.get(
			"guilty_plea_committed",
			false
		)
	)

	var judgment_score: float = evidence_strength
	judgment_score += severity * 0.1
	judgment_score += (
		float(prior_convictions) * 0.035
	)
	judgment_score += corruption * 0.045
	judgment_score += trial_prosecution_score
	judgment_score += confession_pressure
	judgment_score -= due_process * 0.035
	judgment_score -= defense_modifier
	judgment_score -= counsel_modifier
	judgment_score -= trial_defense_score
	judgment_score -= credibility_score
	judgment_score = clampf(
		judgment_score,
		0.0,
		1.0
	)

	if guilty_plea_committed:
		judgment_score = maxf(
			judgment_score,
			burden
		)

	var guilty: bool = (
		guilty_plea_committed
		or judgment_score >= burden
	)
	var verdict: Dictionary = (
		_build_verdict_object(
			case_data,
			guilty,
			judgment_score,
			burden,
			legal_system
		)
	)
	var sentence_raw: Variant = verdict.get(
		"sentence",
		{}
	)
	var sentence: Dictionary = (
		sentence_raw as Dictionary
		if typeof(sentence_raw) == TYPE_DICTIONARY
		else {}
	)

	var sentence_mitigation: float = clampf(
		float(
			live_trial.get(
				"sentence_mitigation",
				0.0
			)
		) + (
			0.12
			if bool(
				case_data.get(
					"plea_requested",
					false
				)
			)
			else 0.0
		),
		0.0,
		0.5
	)

	if (
		guilty
		and not sentence.is_empty()
		and sentence_mitigation > 0.0
	):
		var sentence_type: String = str(
			sentence.get(
				"type",
				""
			)
		)

		if sentence_type == "prison":
			sentence ["duration"] = maxi(
				1,
				int(
					round(
						float(
							sentence.get(
								"duration",
								1
							)
						) * (
							1.0 - sentence_mitigation
						)
					)
				)
			)

		sentence ["fine"] = maxi(
			0,
			int(
				round(
					float(
						sentence.get(
							"fine",
							0
						)
					) * (
						1.0
						- sentence_mitigation * 0.5
					)
				)
			)
		)

		var flags_raw: Variant = sentence.get(
			"flags",
			[]
		)
		var flags: Array = (
			(flags_raw as Array).duplicate(true)
			if typeof(flags_raw) == TYPE_ARRAY
			else []
		)

		if "trial_mitigation_applied" not in flags:
			flags.append(
				"trial_mitigation_applied"
			)

		sentence ["flags"] = flags
		sentence [
			"mitigation_fraction"
		] = sentence_mitigation
		verdict ["sentence"] = sentence.duplicate(true)

	var reasoning_raw: Variant = verdict.get(
		"reasoning",
		[]
	)
	var reasoning: Array = (
		(reasoning_raw as Array).duplicate(true)
		if typeof(reasoning_raw) == TYPE_ARRAY
		else []
	)

	reasoning.append(
		"Defense modifier: %.2f"
		% defense_modifier
	)
	reasoning.append(
		"Counsel modifier: %.2f"
		% counsel_modifier
	)
	reasoning.append(
		"Live-trial defense: %.2f"
		% trial_defense_score
	)
	reasoning.append(
		"Live-trial prosecution: %.2f"
		% trial_prosecution_score
	)
	reasoning.append(
		"Credibility effect: %.2f"
		% credibility_score
	)

	verdict ["reasoning"] = reasoning
	verdict ["decision_trace"] = {
		"evidence_strength": evidence_strength,
		"severity_pressure": severity * 0.1,
		"prior_conviction_pressure": (
			float(prior_convictions) * 0.035
		),
		"corruption_pressure": corruption * 0.045,
		"confession_pressure": confession_pressure,
		"trial_prosecution_score": trial_prosecution_score,
		"due_process_protection": due_process * 0.035,
		"defense_modifier": defense_modifier,
		"counsel_modifier": counsel_modifier,
		"trial_defense_score": trial_defense_score,
		"credibility_score": credibility_score,
		"judgment_score": judgment_score,
		"burden_of_proof": burden,
		"guilty_plea_committed": guilty_plea_committed,
		"sentence_mitigation": sentence_mitigation
	}

	ledger.append(
		verdict.duplicate(true)
	)
	last_verdict = verdict.duplicate(true)

	return {
		"success": true,
		"case_id": str(
			case_data.get(
				"case_id",
				""
			)
		),
		"verdict": verdict.duplicate(true),
		"sentence": sentence.duplicate(true),
		"decision_trace": (
			verdict ["decision_trace"].duplicate(true)
		),
		"evaluated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

func _build_verdict_object(case_data: Dictionary, guilty: bool, judgment_score: float, burden: float, legal_system: Dictionary) -> Dictionary:
	var crime_raw: Variant = case_data.get("crime", {})
	var crime: Dictionary = crime_raw if typeof(crime_raw) == TYPE_DICTIONARY else {}

	var charges: Array = crime.get("charges", []) if typeof(crime.get("charges", [])) == TYPE_ARRAY else []
	if charges.is_empty():
		charges = [str(crime.get("name", crime.get("type", "unknown crime")))]

	var sentence: Dictionary = _build_sentence_object(case_data, guilty, legal_system)

	return {
		"schema": "eralife.verdict_object",
		"version": CONTRACT_VERSION,
		"case_id": str(case_data.get("case_id", "")),
		"outcome": "guilty" if guilty else "not_guilty",
		"charges": charges.duplicate(true),
		"judgment_score": judgment_score,
		"burden_of_proof": burden,
		"reasoning": [
			"Evidence strength: %.2f" % float(case_data.get("evidence_packet", {}).get("evidence_strength", 0.0)),
			"Burden of proof: %.2f" % burden,
			"Severity pressure: %.2f" % float(crime.get("severity", 0.0)),
			"Legal system: %s" % str(case_data.get("legal_system", "modern_democracy"))
		],
		"sentence": sentence.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _build_sentence_object(case_data: Dictionary, guilty: bool, legal_system: Dictionary) -> Dictionary:
	if not guilty:
		return {
			"schema": "eralife.sentence_object",
			"version": CONTRACT_VERSION,
			"type": "none",
			"duration": 0,
			"fine": 0,
			"restitution": 0,
			"flags": ["acquitted"],
			"economic_penalties": [],
			"reputation_tags": [],
			"political_consequences": []
		}

	var crime_raw: Variant = case_data.get("crime", {})
	var crime: Dictionary = crime_raw if typeof(crime_raw) == TYPE_DICTIONARY else {}

	var severity: float = clamp(float(crime.get("severity", 0.35)), 0.0, 1.0)
	var base_years: int = max(1, int(crime.get("base_sentence_years", 1)))
	var multiplier: float = max(0.05, float(legal_system.get("sentence_multiplier", 1.0)))
	var duration: int = max(1, int(round(float(base_years) * multiplier)))
	var allows_execution: bool = bool(legal_system.get("allows_execution", false))
	var violent: bool = bool(crime.get("violent", false))

	var fine: int = int(round(250.0 + severity * 4500.0))
	var restitution: int = int(crime.get("payout", 0))
	var flags: Array = []
	var sentence_type: String = "prison"

	if severity < 0.22:
		sentence_type = "fine_only"
		duration = 0
		flags.append("low_severity")
	elif allows_execution and violent and severity >= 0.9:
		sentence_type = "execution"
		duration = 0
		flags.append("execution_eligible")

	if bool(crime.get("success_before_arrest", false)):
		flags.append("crime_completed_before_arrest")

	return {
		"schema": "eralife.sentence_object",
		"version": CONTRACT_VERSION,
		"type": sentence_type,
		"duration": duration,
		"fine": fine,
		"restitution": restitution,
		"flags": flags,
		"economic_penalties": [
			{
				"type": "fine",
				"amount": fine,
				"reason": "court_fine"
			},
			{
				"type": "restitution",
				"amount": restitution,
				"reason": "victim_restitution"
			}
		],
		"reputation_tags": [
			"convicted_criminal",
			"convicted_%s" % str(crime.get("type", "crime")).to_lower().replace(" ", "_")
		],
		"political_consequences": _political_consequence_packet(case_data, severity)
	}

func _political_consequence_packet(case_data: Dictionary, severity: float) -> Array:
	var out: Array = []
	var accused_id: int = int(case_data.get("participants", {}).get("accused", -1))
	var accused = null
	if gs != null and gs.has_method("get_npc_by_id"):
		accused = gs.get_npc_by_id(accused_id)

	if accused != null and (bool(accused.is_ruler) or bool(accused.is_royal)):
		out.append({
			"type": "royal_scandal",
			"severity": severity,
			"can_remove_title": severity >= 0.55,
			"can_remove_from_power": severity >= 0.75
		})

	return out

func _count_prior_convictions(_actor_id: int) -> int:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return 0

	var record_raw: Variant = gs.scenario_state.get("justice_record", [])
	var record: Array = record_raw if typeof(record_raw) == TYPE_ARRAY else []
	var total: int = 0

	for raw_entry in record:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		if bool(entry.get("convicted", false)):
			total += 1

	return total

func export_state() -> Dictionary:
	return {
		"schema": "eralife.justice_system_engine_state",
		"version": CONTRACT_VERSION,
		"ledger": ledger.duplicate(true),
		"last_verdict": last_verdict.duplicate(true)
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "JusticeSystemEngine import data must be a Dictionary."}

	var ledger_raw: Variant = data.get("ledger", [])
	ledger = ledger_raw.duplicate(true) if typeof(ledger_raw) == TYPE_ARRAY else []

	var verdict_raw: Variant = data.get("last_verdict", {})
	last_verdict = verdict_raw.duplicate(true) if typeof(verdict_raw) == TYPE_DICTIONARY else {}

	return { "success": true, "imported_at_ms": int(Time.get_ticks_msec())}