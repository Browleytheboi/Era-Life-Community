extends Resource
class_name PrisonEngine

const CONTRACT_VERSION:= 1

var gs
var inmate_records: Dictionary = {}
var prison_ledger: Array = []
var last_report: Dictionary = {}


var resident_prison_reality_by_actor: Dictionary = {}
var prison_facility_members_by_id: Dictionary = {}
var prison_cellmate_by_actor: Dictionary = {}


var prison_facility_contract_by_id: Dictionary = {}



var prison_guard_ids_by_facility: Dictionary = {}
func _init(_gs = null):
	gs = _gs

func execute_sentence(
		case_data: Dictionary,
		sentence: Dictionary = {}
) -> Dictionary:
	if (
		typeof(
			case_data
		) != TYPE_DICTIONARY
		or case_data.is_empty()
	):
		return {
			"success": false,
			"reason": "PrisonEngine needs a CaseObject."
		}

	var sentence_type: String = str(
		sentence.get(
			"type",
			"none"
		)
	).strip_edges().to_lower()
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
	var duration: int = maxi(
		0,
		int(
			sentence.get(
				"duration",
				0
			)
		)
	)

	if accused_id <= 0:
		return {
			"success": false,
			"reason": "Sentence needs accused id."
		}

	if sentence_type in [
		"none",
		"fine_only"
	]:
		return _record(
			"prison_not_required",
			{
				"case_id": str(
					case_data.get(
						"case_id",
						""
					)
				),
				"accused_id": accused_id,
				"sentence_type": sentence_type
			}
		)

	var facility_contract: Dictionary = _prison_facility_contract(
		case_data,
		sentence
	)
	var facility_id: String = str(
		facility_contract.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		return {
			"success": false,
			"reason": "Prison sentence could not resolve a facility identity."
		}

	var incarceration_context: Dictionary = _build_prison_incarceration_context(
		case_data,
		sentence,
		facility_contract
	)
	var execution_schedule: Dictionary = {}

	if sentence_type == "execution":
		execution_schedule = _execution_schedule_for_sentence(
			case_data,
			sentence,
			facility_contract
		)
		incarceration_context ["status"] = "condemned"
		incarceration_context ["execution_schedule"] = execution_schedule.duplicate(true)
		incarceration_context ["years_remaining"] = maxi(
			1,
			int(
				execution_schedule.get(
					"execution_year",
					int(
						gs.year
					) + 1
				)
			) - int(
				gs.year
			)
		)

	var inmate_id: String = "inmate_%d_%s" % [
		accused_id,
		str(
			case_data.get(
				"case_id",
				""
			)
		)
	]
	var row: Dictionary = {
		"schema": "eralife.prison_inmate_record",
		"version": 2,
		"inmate_id": inmate_id,
		"case_id": str(
			case_data.get(
				"case_id",
				""
			)
		),
		"accused_id": accused_id,
		"sentence_type": sentence_type,
		"sentence_years": duration,
		"life_without_parole": bool(
			sentence.get(
				"life_without_parole",
				false
			)
		),
		"years_served": 0,
		"years_remaining": int(
			incarceration_context.get(
				"years_remaining",
				duration
			)
		),
		"months_served": 0,
		"sentence_months": duration * 12,
		"status": (
			"condemned"
			if sentence_type == "execution"
			else "incarcerated"
		),
		"incarceration_kind": "prison",
		"facility_id": facility_id,
		"facility_type": str(
			facility_contract.get(
				"facility_type",
				"State Prison"
			)
		),
		"facility_label": str(
			facility_contract.get(
				"facility_label",
				"State Prison"
			)
		),
		"security_level": str(
			facility_contract.get(
				"security_level",
				"Medium"
			)
		),
		"incarceration_context": incarceration_context.duplicate(true),
		"incarceration_stats": _default_prison_stats(
			incarceration_context
		),
		"execution_schedule": execution_schedule.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	inmate_records [
		str(
			accused_id
		)
	] = row.duplicate(true)



	_register_prison_resident(
		row,
		facility_contract
	)

	_set_sentence_trait(
		accused_id,
		maxi(
			1,
			int(
				row.get(
					"years_remaining",
					duration
				)
			)
		)
	)
	_apply_prison_context_to_actor(
		accused_id,
		row
	)

	_publish_prison_facility_residency(
		facility_id,
		"prison_intake"
	)

	last_report = _record(
		"prison_intake_created",
		row
	)
	last_report ["incarceration_context_applied"] = true
	last_report ["incarceration_context"] = incarceration_context.duplicate(true)
	last_report ["execution_scheduled"] = (
		sentence_type == "execution"
	)
	last_report ["execution_schedule"] = execution_schedule.duplicate(true)
	last_report ["resident_prison_reality_hot"] = (
		not resident_prison_reality_contract(
			accused_id
		).is_empty()
	)

	return last_report.duplicate(true)
func yearly_tick_actor(
	actor
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var actor_id: int = int(
		actor.id
	)
	var key: String = str(
		actor_id
	)
	var row: Dictionary = (
		inmate_records.get(
			key,
			{}
		).duplicate(true)
		if typeof(
			inmate_records.get(
				key,
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if row.is_empty():
		return _legacy_trait_sentence_tick(
			actor
		)

	var sentence_type: String = str(
		row.get(
			"sentence_type",
			"prison"
		)
	).strip_edges().to_lower()
	var execution_schedule: Dictionary = _safe_dictionary(
		row.get(
			"execution_schedule",
			{}
		)
	)

	if (
		sentence_type == "execution"
		and not execution_schedule.is_empty()
		and int(
			gs.year
		) >= int(
			execution_schedule.get(
				"execution_year",
				2147483647
			)
		)
	):
		return _execute_scheduled_death_sentence(
			actor,
			row
		)

	var life_without_parole: bool = bool(
		row.get(
			"life_without_parole",
			false
		)
	)
	var remaining: int = int(
		row.get(
			"years_remaining",
			0
		)
	)

	if not life_without_parole:
		remaining = maxi(
			0,
			remaining - 1
		)

	var served: int = maxi(
		0,
		int(
			row.get(
				"years_served",
				0
			)
		) + 1
	)

	row ["years_remaining"] = remaining
	row ["years_served"] = served
	row ["months_served"] = served * 12
	row ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	var stats: Dictionary = _safe_dictionary(
		row.get(
			"incarceration_stats",
			{}
		)
	)
	stats ["mental_stability"] = clampi(
		int(
			stats.get(
				"mental_stability",
				58
			)
		) - 3,
		0,
		100
	)
	stats ["guard_heat"] = clampi(
		int(
			stats.get(
				"guard_heat",
				20
			)
		) + 1,
		0,
		100
	)
	stats ["contraband_risk"] = clampi(
		int(
			stats.get(
				"contraband_risk",
				12
			)
		) + 1,
		0,
		100
	)
	row ["incarceration_stats"] = stats.duplicate(true)

	var context: Dictionary = _safe_dictionary(
		row.get(
			"incarceration_context",
			{}
		)
	)

	if not context.is_empty():
		context ["years_remaining"] = remaining
		context ["years_served"] = served
		context ["months_served"] = served * 12
		context ["updated_at_ms"] = int(
			Time.get_ticks_msec()
		)
		row ["incarceration_context"] = (
			context.duplicate(true)
		)

	if (
		remaining <= 0
		and not life_without_parole
		and sentence_type != "execution"
	):
		row ["status"] = "released"
		row ["released_at_ms"] = int(
			Time.get_ticks_msec()
		)
		var released_facility_id: String = str(
			row.get(
				"facility_id",
				""
			)
		)
		inmate_records.erase(
			key
		)
		_unregister_prison_resident(
			actor_id,
			released_facility_id
		)

		resident_prison_reality_by_actor.erase(
			str(
				actor_id
			)
		)

		_publish_prison_facility_residency(
			released_facility_id,
			"prison_release"
		)
		_clear_sentence_traits(
			actor
		)
		_clear_prison_context_from_actor(
			actor,
			"released"
		)
		_record(
			"prison_released",
			row
		)

		return {
			"success": true,
			"released": true,
			"text": "I finished my prison sentence.",
			"popup_title": "Release",
			"popup_text": "I finished my prison sentence.",
			"popup_footer": "Tap anywhere to continue."
		}

	inmate_records [key] = row.duplicate(true)

	_set_sentence_trait(
		actor_id,
		maxi(
			1,
			remaining
		)
	)
	_apply_prison_context_to_actor(
		actor_id,
		row
	)

	return {
		"success": true,
		"released": false,
		"life_without_parole": life_without_parole,
		"years_remaining": remaining,
		"years_served": served,
		"text": (
			"I remain imprisoned for life."
			if life_without_parole
			else "I have %d years left in prison."
			% remaining
		)
	}
func build_prison_reality_contract(
		actor,
		_include_population_cards: bool = true
) -> Dictionary:
	if actor == null:
		return {}

	return resident_prison_reality_contract(
		int(
			actor.id
		)
	)


func resident_prison_reality_contract(
		actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var raw_contract: Variant = (
		resident_prison_reality_by_actor.get(
			str(
				actor_id
			),
			{}
		)
	)

	if typeof(
		raw_contract
	) != TYPE_DICTIONARY:
		return {}

	return (
		raw_contract as Dictionary
	).duplicate(false)
func resolve_prison_activity(
	actor,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				int(
					actor.id
				)
			),
			{}
		)
	)

	if row.is_empty():
		return {
			"success": false,
			"reason": "actor_is_not_in_prison"
		}

	var activity_id: String = str(
		payload.get(
			"activity_id",
			payload.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()
	var allowed_ids: Array = []

	for raw_action in _prison_activity_actions_for_era(
		_current_era_name()
	):
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		allowed_ids.append(
			str(
				(
					raw_action as Dictionary
				).get(
					"id",
					""
				)
			)
		)

	for raw_action in _family_contact_actions_for_era(
		_current_era_name(),
		row
	):
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		allowed_ids.append(
			str(
				(
					raw_action as Dictionary
				).get(
					"id",
					""
				)
			)
		)

	if activity_id not in allowed_ids:
		return {
			"success": false,
			"reason": "prison_activity_not_available"
		}

	var stats: Dictionary = _safe_dictionary(
		row.get(
			"incarceration_stats",
			{}
		)
	)
	var result_text: String = ""

	match activity_id:
		"phone_family":
			stats ["mental_stability"] = clampi(
				int(
					stats.get(
						"mental_stability",
						50
					)
				) + 7,
				0,
				100
			)
			result_text = "I called my family from prison."

		"send_letter":
			stats ["mental_stability"] = clampi(
				int(
					stats.get(
						"mental_stability",
						50
					)
				) + 5,
				0,
				100
			)
			result_text = "I sent a letter to my family."

		"yard":
			stats ["respect"] = clampi(
				int(
					stats.get(
						"respect",
						30
					)
				) + randi_range(
					-2,
					4
				),
				0,
				100
			)
			result_text = "I spent time in the prison yard."

		"forced_labor", "prison_job":
			stats ["mental_stability"] = clampi(
				int(
					stats.get(
						"mental_stability",
						50
					)
				) - 2,
				0,
				100
			)
			result_text = "I worked during my sentence."

		"communal_meal":
			result_text = (
				"I ate among the prison population."
			)

		"cell_reflection":
			stats ["mental_stability"] = clampi(
				int(
					stats.get(
						"mental_stability",
						50
					)
				) + 2,
				0,
				100
			)
			result_text = "I spent time alone in my cell."

		_:
			result_text = "I completed a prison activity."

	row ["incarceration_stats"] = stats.duplicate(true)
	row ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	inmate_records [str(
		int(
			actor.id
		)
	)] = row.duplicate(true)
	_apply_prison_context_to_actor(
		int(
			actor.id
		),
		row
	)

	actor.memories.append(
		result_text
	)

	return {
		"success": true,
		"mode": "prison_activity_committed",
		"activity_id": activity_id,
		"text": result_text,
		"popup_title": "Prison",
		"popup_text": result_text,
		"popup_footer": "Tap anywhere to continue.",
		"prison_reality_contract": (
			build_prison_reality_contract(
				actor
			)
		)
	}


func _execution_schedule_for_sentence(
	case_data: Dictionary,
	_sentence: Dictionary,
	facility_contract: Dictionary
) -> Dictionary:
	var era_name: String = str(
		facility_contract.get(
			"era",
			_current_era_name()
		)
	)
	var profile: Dictionary = _execution_profile_for_era(
		era_name
	)
	var methods: Array = _safe_array(
		profile.get(
			"methods",
			[]
		)
	)
	var selected_method: Dictionary = {}

	if not methods.is_empty():
		selected_method = _safe_dictionary(
			methods [
				randi_range(
					0,
					methods.size() - 1
				)
			]
		)

	var wait_years: int = randi_range(
		int(
			profile.get(
				"minimum_wait_years",
				1
			)
		),
		int(
			profile.get(
				"maximum_wait_years",
				3
			)
		)
	)

	return {
		"schema": "eralife.execution_schedule",
		"version": 1,
		"case_id": str(
			case_data.get(
				"case_id",
				""
			)
		),
		"era": era_name,
		"execution_year": int(
			gs.year
		) + wait_years,
		"method_id": str(
			selected_method.get(
				"id",
				"execution"
			)
		),
		"method_label": str(
			selected_method.get(
				"label",
				"Execution"
			)
		),
		"public": bool(
			selected_method.get(
				"public",
				false
			)
		),
		"status": "scheduled",
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _execution_profile_for_era(
	era_name: String
) -> Dictionary:
	match era_name:
		"Ancient Era":
			return {
				"minimum_wait_years": 1,
				"maximum_wait_years": 2,
				"methods": [
					{
						"id": "lions_den",
						"label": "Thrown into the Lions' Den",
						"public": true
					},
					{
						"id": "hot_furnace",
						"label": "Cast into the Hot Furnace",
						"public": true
					},
					{
						"id": "beheading",
						"label": "Beheading",
						"public": true
					}
				]
			}

		"Medieval Era":
			return {
				"minimum_wait_years": 1,
				"maximum_wait_years": 3,
				"methods": [
					{
						"id": "gallows",
						"label": "The Gallows",
						"public": true
					},
					{
						"id": "beheading",
						"label": "Beheading",
						"public": true
					},
					{
						"id": "burning",
						"label": "Burning at the Stake",
						"public": true
					}
				]
			}

		"Industrial Era":
			return {
				"minimum_wait_years": 1,
				"maximum_wait_years": 4,
				"methods": [
					{
						"id": "hanging",
						"label": "Hanging",
						"public": false
					},
					{
						"id": "firing_squad",
						"label": "Firing Squad",
						"public": false
					}
				]
			}

		"Future Era":
			return {
				"minimum_wait_years": 1,
				"maximum_wait_years": 2,
				"methods": [
					{
						"id": "neural_termination",
						"label": "Neural Termination",
						"public": false
					},
					{
						"id": "energy_chamber",
						"label": "Energy Chamber",
						"public": false
					}
				]
			}

		_:
			return {
				"minimum_wait_years": 2,
				"maximum_wait_years": 6,
				"methods": [
					{
						"id": "lethal_injection",
						"label": "Lethal Injection",
						"public": false
					},
					{
						"id": "electric_chair",
						"label": "Electric Chair",
						"public": false
					}
				]
			}


func _execute_scheduled_death_sentence(
		actor,
		row: Dictionary
) -> Dictionary:
	var execution_schedule: Dictionary = _safe_dictionary(
		row.get(
			"execution_schedule",
			{}
		)
	)
	var method_label: String = str(
		execution_schedule.get(
			"method_label",
			"Execution"
		)
	)
	var killed: bool = false

	if (
		gs != null
		and gs.health_engine != null
		and gs.health_engine.has_method(
			"try_kill"
		)
	):
		killed = bool(
			gs.health_engine.try_kill(
				actor,
				method_label
			)
		)

	var actor_id: int = int(
		actor.id
	)
	var case_id: String = str(
		row.get(
			"case_id",
			""
		)
	)
	var facility_id: String = str(
		row.get(
			"facility_id",
			""
		)
	).strip_edges()
	var report: Dictionary = {
		"success": killed,
		"mode": "scheduled_execution_committed",
		"actor_id": actor_id,
		"case_id": case_id,
		"facility_id": facility_id,
		"method_id": str(
			execution_schedule.get(
				"method_id",
				"execution"
			)
		),
		"method_label": method_label,
		"execution_year": int(
			gs.year
		),
		"killed": killed
	}

	row ["status"] = (
		"executed"
		if killed
		else "execution_failed"
	)
	row ["execution_report"] = report.duplicate(true)
	row ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	if killed:

		inmate_records.erase(
			str(
				actor_id
			)
		)


		_unregister_prison_resident(
			actor_id,
			facility_id
		)

		resident_prison_reality_by_actor.erase(
			str(
				actor_id
			)
		)



		if facility_id != "":
			_publish_prison_facility_residency(
				facility_id,
				"scheduled_execution"
			)

		_clear_sentence_traits(
			actor
		)
		_clear_prison_context_from_actor(
			actor,
			"executed"
		)
	else:
		inmate_records [
			str(
				actor_id
			)
		] = row.duplicate(true)

		if facility_id != "":
			_publish_prison_facility_residency(
				facility_id,
				"execution_failed"
			)

	if (
		gs.case_orchestrator != null
		and gs.case_orchestrator.has_method(
			"mark_case_executed"
		)
		and killed
	):
		report ["case_report"] = (
			gs.case_orchestrator.mark_case_executed(
				case_id,
				report
			)
		)

	_record(
		"scheduled_execution_committed",
		report
	)

	return report

func _family_contact_actions_for_era(
	era_name: String,
	_row: Dictionary
) -> Array:
	match era_name:
		"Ancient Era", "Medieval Era":
			return [
				{
					"id": "send_letter",
					"label": "Send Family Letter"
				}
			]

		"Industrial Era":
			return [
				{
					"id": "send_letter",
					"label": "Send Family Letter"
				}
			]

		"Future Era":
			return [
				{
					"id": "phone_family",
					"label": "Supervised Holographic Call"
				},
				{
					"id": "send_letter",
					"label": "Send Secure Message"
				}
			]

		_:
			return [
				{
					"id": "phone_family",
					"label": "Call Family"
				},
				{
					"id": "send_letter",
					"label": "Write Family Letter"
				}
			]


func _prison_activity_actions_for_era(
	era_name: String
) -> Array:
	var out: Array = [
		{
			"id": "communal_meal",
			"label": "Eat With Prisoners"
		},
		{
			"id": "cell_reflection",
			"label": "Reflect in Cell"
		}
	]

	match era_name:
		"Ancient Era", "Medieval Era":
			out.append({
				"id": "forced_labor",
				"label": "Perform Forced Labor"
			})

		"Industrial Era":
			out.append({
				"id": "forced_labor",
				"label": "Work Camp Shift"
			})

		_:
			out.append({
				"id": "yard",
				"label": "Go to the Yard"
			})
			out.append({
				"id": "prison_job",
				"label": "Work Prison Job"
			})

	return out


func _prison_population_cards(
		actor_id: int,
		active_row: Dictionary
) -> Array:
	var facility_id: String = str(
		active_row.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		return []

	var member_ids: Array = _safe_array(
		prison_facility_members_by_id.get(
			facility_id,
			[]
		)
	)
	var cellmate_id: int = int(
		prison_cellmate_by_actor.get(
			str(
				actor_id
			),
			-1
		)
	)
	var ordered_ids: Array = []

	if (
		cellmate_id > 0
		and cellmate_id != actor_id
		and cellmate_id in member_ids
	):
		ordered_ids.append(
			cellmate_id
		)

	for raw_member_id in member_ids:
		var inmate_actor_id: int = int(
			raw_member_id
		)

		if (
			inmate_actor_id <= 0
			or inmate_actor_id == actor_id
			or inmate_actor_id == cellmate_id
		):
			continue

		ordered_ids.append(
			inmate_actor_id
		)

	var out: Array = []

	for inmate_actor_id in ordered_ids:
		var row: Dictionary = _safe_dictionary(
			inmate_records.get(
				str(
					inmate_actor_id
				),
				{}
			)
		)

		if row.is_empty():
			continue

		if str(
			row.get(
				"facility_id",
				""
			)
		).strip_edges() != facility_id:
			continue

		var inmate = _actor_by_id(
			inmate_actor_id
		)
		var inmate_name: String = (
			"%s %s"
			% [
				str(
					inmate.first_name
				),
				str(
					inmate.last_name
				)
			]
		).strip_edges() if inmate != null else (
			"Person %d" % inmate_actor_id
		)

		var is_cellmate: bool = (
			inmate_actor_id == cellmate_id
		)
		var relationship_label: String = (
			"Cellmate"
			if is_cellmate
			else "Inmate"
		)

		out.append({
			"kind": "prison_population_card",
			"card_kind": "person",
			"target_id": inmate_actor_id,
			"person_id": inmate_actor_id,
			"label": inmate_name,
			"name": inmate_name,
			"role": relationship_label,
			"relationship_label": relationship_label,
			"subtitle": "%s • %s • %d years remaining" % [
				relationship_label,
				str(
					row.get(
						"facility_label",
						active_row.get(
							"facility_label",
							"Prison"
						)
					)
				),
				int(
					row.get(
						"years_remaining",
						0
					)
				)
			],
			"sentence_type": str(
				row.get(
					"sentence_type",
					"prison"
				)
			),
			"years_remaining": int(
				row.get(
					"years_remaining",
					0
				)
			),
			"facility_id": facility_id,
			"featured": is_cellmate,
			"cellmate": is_cellmate,
			"can_open_profile": true,
			"ui_is_renderer_only": true
		})

	return out
func _assign_prison_cellmate(
		actor_id: int,
		facility_id: String
) -> int:
	if (
		actor_id <= 0
		or facility_id.strip_edges() == ""
	):
		return -1

	var actor_key: String = str(
		actor_id
	)
	var existing_cellmate_id: int = int(
		prison_cellmate_by_actor.get(
			actor_key,
			-1
		)
	)

	if (
		existing_cellmate_id > 0
		and _actors_share_prison_facility(
			actor_id,
			existing_cellmate_id
		)
	):
		return existing_cellmate_id

	var member_ids: Array = _safe_array(
		prison_facility_members_by_id.get(
			facility_id,
			[]
		)
	).duplicate(false)

	member_ids.sort()

	for raw_candidate_id in member_ids:
		var candidate_id: int = int(
			raw_candidate_id
		)

		if (
			candidate_id <= 0
			or candidate_id == actor_id
		):
			continue

		var candidate_cellmate_id: int = int(
			prison_cellmate_by_actor.get(
				str(
					candidate_id
				),
				-1
			)
		)

		if candidate_cellmate_id > 0:
			continue

		prison_cellmate_by_actor [
			actor_key
		] = candidate_id
		prison_cellmate_by_actor [
			str(
				candidate_id
			)
		] = actor_id

		return candidate_id

	prison_cellmate_by_actor [
		actor_key
	] = -1

	return -1


func _actors_share_prison_facility(
		first_actor_id: int,
		second_actor_id: int
) -> bool:
	if (
		first_actor_id <= 0
		or second_actor_id <= 0
	):
		return false

	var first_row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				first_actor_id
			),
			{}
		)
	)
	var second_row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				second_actor_id
			),
			{}
		)
	)

	if (
		first_row.is_empty()
		or second_row.is_empty()
	):
		return false

	var first_facility_id: String = str(
		first_row.get(
			"facility_id",
			""
		)
	).strip_edges()
	var second_facility_id: String = str(
		second_row.get(
			"facility_id",
			""
		)
	).strip_edges()

	return (
		first_facility_id != ""
		and first_facility_id == second_facility_id
	)


func get_prison_rows(_context: Dictionary = {}) -> Array:
	var out: Array = []
	for raw_key in inmate_records.keys():
		var row: Dictionary = inmate_records.get(raw_key, {})
		out.append({
			"label": "Inmate: person %d • %d years remaining • case %s" % [
				int(row.get("accused_id", -1)),
				int(row.get("years_remaining", 0)),
				str(row.get("case_id", ""))
			],
			"kind": "prison_inmate",
			"case_id": str(row.get("case_id", ""))
		})
	return out

func export_state() -> Dictionary:
	return {
		"schema": "eralife.prison_engine_state",
		"version": CONTRACT_VERSION,
		"inmate_records": inmate_records.duplicate(true),
		"facility_contract_by_id": prison_facility_contract_by_id.duplicate(true),
		"guard_ids_by_facility": prison_guard_ids_by_facility.duplicate(true),
		"prison_ledger": prison_ledger.duplicate(true),
		"last_report": last_report.duplicate(true)
	}
func import_state(
		data: Dictionary
) -> Dictionary:
	if typeof(
		data
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "PrisonEngine import data must be a Dictionary."
		}

	var records_raw: Variant = data.get(
		"inmate_records",
		{}
	)
	inmate_records = (
		records_raw.duplicate(true)
		if typeof(
			records_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var facility_raw: Variant = data.get(
		"facility_contract_by_id",
		{}
	)
	prison_facility_contract_by_id = (
		facility_raw.duplicate(true)
		if typeof(
			facility_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var guard_raw: Variant = data.get(
		"guard_ids_by_facility",
		{}
	)
	prison_guard_ids_by_facility = (
		guard_raw.duplicate(true)
		if typeof(
			guard_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var ledger_raw: Variant = data.get(
		"prison_ledger",
		[]
	)
	prison_ledger = (
		ledger_raw.duplicate(true)
		if typeof(
			ledger_raw
		) == TYPE_ARRAY
		else []
	)

	var last_report_raw: Variant = data.get(
		"last_report",
		{}
	)
	last_report = (
		last_report_raw.duplicate(true)
		if typeof(
			last_report_raw
		) == TYPE_DICTIONARY
		else {}
	)

	resident_prison_reality_by_actor.clear()
	prison_facility_members_by_id.clear()
	prison_cellmate_by_actor.clear()



	_rebuild_resident_prison_indexes_from_canonical_records()

	return {
		"success": true,
		"imported_at_ms": int(
			Time.get_ticks_msec()
		),
	}
func _build_prison_incarceration_context(case_data: Dictionary, sentence: Dictionary, facility_contract: Dictionary) -> Dictionary:
	var current_year: int = int(gs.year) if gs != null else 0
	var duration: int = int(sentence.get("duration", 0))

	return {
		"schema": "eralife.incarceration_context",
		"version": CONTRACT_VERSION,
		"current_context": "incarcerated",
		"incarceration_kind": "prison",
		"facility_type": str(facility_contract.get("facility_type", "State Prison")),
		"facility_label": str(facility_contract.get("facility_label", "State Prison")),
		"era": str(facility_contract.get("era", "Modern Era")),
		"security_level": str(facility_contract.get("security_level", "Medium")),
		"status": "incarcerated",
		"case_id": str(case_data.get("case_id", "")),
		"sentence_type": str(sentence.get("type", "prison")),
		"sentence_years": duration,
		"sentence_months": duration * 12,
		"years_served": 0,
		"months_served": 0,
		"years_remaining": duration,
		"started_year": current_year,
		"rules": _safe_array(facility_contract.get("rules", [])).duplicate(true),
		"restrictions": _safe_array(facility_contract.get("restrictions", [])).duplicate(true),
		"tab_context_map": _incarceration_tab_context_map("prison"),
		"facility_id": str(
			facility_contract.get(
				"facility_id",
				""
			)
		),
		"source": "prison_engine",
		"created_at_ms": int(Time.get_ticks_msec())
	}
func _prison_crime_target_cards(
		population_cards: Array
) -> Array:
	var out: Array = []

	for raw_card in population_cards:
		if typeof(
			raw_card
		) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var target_id: int = int(
			card.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		out.append({
			"kind": "crime_target",
			"label": str(
				card.get(
					"label",
					"Prisoner"
				)
			),
			"target_id": target_id,
			"subtitle": str(
				card.get(
					"subtitle",
					"Current inmate"
				)
			),
			"relationship_label": str(
				card.get(
					"relationship_label",
					"Inmate"
				)
			),
			"target_source": (
				"incarceration_cellmate"
				if bool(
					card.get(
						"cellmate",
						false
					)
				)
				else "incarceration_facility_population"
			),
			"facility_id": str(
				card.get(
					"facility_id",
					""
				)
			),
			"actions": [],
		})

	return out

func _apply_prison_context_to_actor(actor_id: int, row: Dictionary) -> void:
	var actor = _actor_by_id(actor_id)
	if actor == null:
		return

	var context: Dictionary = _safe_dictionary(row.get("incarceration_context", {}))
	if context.is_empty():
		return

	actor.current_context = "incarcerated"
	actor.incarceration_state = {
		"schema": "eralife.incarceration_state",
		"version": CONTRACT_VERSION,
		"active": true,
		"status": str(
			row.get(
				"status",
				"incarcerated"
			)
		),
		"kind": "prison",
		"facility_id": str(
			row.get(
				"facility_id",
				""
			)
		),
		"facility_type": str(
			row.get(
				"facility_type",
				"State Prison"
			)
		),
		"security_level": str(
			row.get(
				"security_level",
				"Medium"
			)
		),
		"case_id": str(
			row.get(
				"case_id",
				""
			)
		),
		"inmate_id": str(
			row.get(
				"inmate_id",
				""
			)
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	actor.incarceration_context = context.duplicate(true)
	actor.incarceration_stats = _safe_dictionary(row.get("incarceration_stats", _default_prison_stats(context))).duplicate(true)


func _clear_prison_context_from_actor(actor, reason: String = "released") -> void:
	if actor == null:
		return

	if str(actor.current_context) == "incarcerated":
		actor.current_context = "free"

	actor.incarceration_state = {
		"schema": "eralife.incarceration_state",
		"version": CONTRACT_VERSION,
		"status": str(reason),
		"kind": "prison",
		"released_at_ms": int(Time.get_ticks_msec())
	}
	actor.incarceration_context = {}
	actor.incarceration_stats = {}


func _prison_facility_contract(
		case_data: Dictionary,
		sentence: Dictionary
) -> Dictionary:
	var era_name: String = _current_era_name()
	var crime: Dictionary = _safe_dictionary(
		case_data.get(
			"crime",
			{}
		)
	)
	var severity: float = clamp(
		float(
			crime.get(
				"severity",
				0.45
			)
		),
		0.0,
		1.0
	)
	var years: int = int(
		sentence.get(
			"duration",
			0
		)
	)
	var security_level: String = (
		_security_level_from_sentence(
			severity,
			years
		)
	)

	var facility_type: String = "State Prison"
	var rules: Array = [
		"Structured sentence",
		"Roll call",
		"Prison jobs",
		"Restricted movement"
	]
	var restrictions: Array = [
		"no_travel",
		"limited_family_contact",
		"restricted_career",
		"controlled_schedule"
	]

	match era_name:
		"Ancient Era":
			facility_type = "Dungeon"
			rules = [
				"Chains",
				"Public punishment",
				"Arbitrary imprisonment",
				"Guard-controlled food"
			]
			restrictions = [
				"no_travel",
				"chains",
				"public_shame",
				"guarded_cell"
			]

		"Medieval Era":
			facility_type = "Castle Prison"
			rules = [
				"Dungeon confinement",
				"Torture risk",
				"Nobility privilege",
				"Guard-controlled release"
			]
			restrictions = [
				"no_travel",
				"guarded_cell",
				"limited_family_contact",
				"torture_risk"
			]

		"Industrial Era":
			facility_type = "Work Camp"
			rules = [
				"Harsh labor",
				"Early formal sentence",
				"Strict roll call",
				"Low safety"
			]
			restrictions = [
				"no_travel",
				"forced_labor",
				"limited_family_contact",
				"restricted_career"
			]

		"Future Era":
			facility_type = "AI Correctional Facility"
			rules = [
				"AI guards",
				"Behavior tracking",
				"Psychological correction",
				"Predictive discipline"
			]
			restrictions = [
				"no_travel",
				"surveillance",
				"behavior_tracking",
				"restricted_career"
			]

		_:
			facility_type = "State Prison"
			rules = [
				"Structured sentence",
				"Roll call",
				"Yard time",
				"Contraband economy",
				"Prison jobs"
			]
			restrictions = [
				"no_travel",
				"limited_family_contact",
				"restricted_career",
				"controlled_schedule"
			]

	var world_id: String = str(
		case_data.get(
			"world_id",
			"world"
		)
	).strip_edges()

	if world_id == "":
		world_id = "world"

	var facility_id: String = (
		"prison:%s:%s:%s"
		% [
			world_id.to_lower().replace(
				" ",
				"_"
			),
			era_name.to_lower().replace(
				" ",
				"_"
			),
			facility_type.to_lower().replace(
				" ",
				"_"
			)
		]
	)

	return {
		"schema": "eralife.incarceration_facility_contract",
		"version": CONTRACT_VERSION,
		"facility_id": facility_id,
		"facility_type": facility_type,
		"facility_label": facility_type,
		"incarceration_kind": "prison",
		"era": era_name,
		"security_level": security_level,
		"rules": rules.duplicate(true),
		"restrictions": restrictions.duplicate(true),
		"immutable": true
	}
func _prison_relationships_surface_contract(
		actor_id: int,
		row: Dictionary,
		population_cards: Array
) -> Dictionary:
	var cellmate_cards: Array = []
	var inmate_cards: Array = []

	for raw_card in population_cards:
		if typeof(
			raw_card
		) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = (
			raw_card as Dictionary
		).duplicate(false)

		if bool(
			card.get(
				"cellmate",
				false
			)
		):
			cellmate_cards.append(
				card
			)
		else:
			inmate_cards.append(
				card
			)

	var guard_cards: Array = (
		_prison_guard_cards(
			row
		)
	)
	var tabs: Array = [
		{
			"key": "cellmate",
			"id": "cellmate",
			"label": "CELLMATE"
		},
		{
			"key": "inmates",
			"id": "inmates",
			"label": "INMATES"
		},
		{
			"key": "guards",
			"id": "guards",
			"label": "GUARDS"
		}
	]
	var section_contracts: Dictionary = {
		"cellmate": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "INMATES / GUARDS",
			"subtitle": str(
				row.get(
					"facility_label",
					"Prison"
				)
			),
			"active_section_id": "cellmate",
			"tabs": tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "CELLMATE",
					"subtitle": (
						"The person sharing your immediate living space."
					),
					"cards": cellmate_cards,
					"empty_text": (
						"Cell assignment is still pending."
					),
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		},
		"inmates": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "INMATES / GUARDS",
			"subtitle": str(
				row.get(
					"facility_label",
					"Prison"
				)
			),
			"active_section_id": "inmates",
			"tabs": tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "PRISONERS",
					"subtitle": (
						"People currently resident in this facility."
					),
					"cards": inmate_cards,
					"empty_text": (
						"No other same-facility prisoners are resident."
					),
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		},
		"guards": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "INMATES / GUARDS",
			"subtitle": str(
				row.get(
					"facility_label",
					"Prison"
				)
			),
			"active_section_id": "guards",
			"tabs": tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "GUARDS",
					"subtitle": (
						"Real facility staff currently assigned to this prison."
					),
					"cards": guard_cards,
					"empty_text": (
						"No guard Person contracts are currently resident."
					),
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		}
	}

	var active: Dictionary = (
		section_contracts [
			"cellmate"
		].duplicate(false)
	)

	active ["section_contracts"] = (
		section_contracts
	)
	active ["incarceration_mode"] = true
	active ["ordinary_relationship_graph_suppressed"] = true
	active ["surface_revision"] = (
		"prison_relationships:%d:%s:%d"
		% [
			actor_id,
			str(
				row.get(
					"facility_id",
					""
				)
			),
			population_cards.size()
		]
	)

	return active
func _prison_program_actions_for_era(
		era_name: String,
		category: String
) -> Array:
	var clean_category: String = str(
		category
	).strip_edges().to_lower()
	var out: Array = []

	match era_name:
		"Ancient Era":
			if clean_category == "education":
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "scribe_instruction",
						"category": "education",
						"label": "Scribe Instruction",
						"description": "Practice reading, writing, and record keeping under confinement.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "oral_history_lessons",
						"category": "education",
						"label": "Oral History Lessons",
						"description": "Study law, custom, and history through oral instruction.",
						"enabled": true,
					}
				]
			else:
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "temple_counsel",
						"category": "rehabilitation",
						"label": "Temple Counsel",
						"description": "Meet with a spiritual counselor assigned to the prison.",
						"enabled": true,
					}
				]

		"Medieval Era":
			if clean_category == "education":
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "chaplain_literacy",
						"category": "education",
						"label": "Chaplain Literacy",
						"description": "Learn basic reading and writing from the prison chaplain.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "trade_instruction",
						"category": "education",
						"label": "Trade Instruction",
						"description": "Learn a practical craft permitted by the gaol.",
						"enabled": true,
					}
				]
			else:
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "chaplain_counsel",
						"category": "rehabilitation",
						"label": "Chaplain Counsel",
						"description": "Attend structured moral and spiritual counseling.",
						"enabled": true,
					}
				]

		"Industrial Era":
			if clean_category == "education":
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "basic_literacy",
						"category": "education",
						"label": "Basic Literacy",
						"description": "Study reading, writing, and arithmetic.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "industrial_trade_school",
						"category": "education",
						"label": "Trade School",
						"description": "Train in a facility-approved industrial trade.",
						"enabled": true,
					}
				]
			else:
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "temperance_group",
						"category": "rehabilitation",
						"label": "Temperance Group",
						"description": "Attend an early structured behavior-reform program.",
						"enabled": true,
					}
				]

		"Future Era":
			if clean_category == "education":
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "adaptive_learning",
						"category": "education",
						"label": "Adaptive Learning Module",
						"description": "Use an AI-personalized academic curriculum.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "neural_skill_lab",
						"category": "education",
						"label": "Neural Skill Lab",
						"description": "Train technical skills using supervised future-era learning systems.",
						"enabled": true,
					}
				]
			else:
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "cognitive_reconditioning",
						"category": "rehabilitation",
						"label": "Cognitive Reconditioning",
						"description": "Participate in monitored behavioral therapy.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "predictive_behavior_course",
						"category": "rehabilitation",
						"label": "Predictive Behavior Course",
						"description": "Work through a supervised risk-reduction program.",
						"enabled": true,
					}
				]

		_:
			if clean_category == "education":
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "ged_classes",
						"category": "education",
						"label": "GED Classes",
						"description": "Work toward an equivalency credential.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "vocational_training",
						"category": "education",
						"label": "Vocational Training",
						"description": "Learn an approved trade while incarcerated.",
						"enabled": true,
					}
				]
			else:
				out = [
					{
						"action_id": "incarceration_program",
						"program_id": "anger_management",
						"category": "rehabilitation",
						"label": "Anger Management",
						"description": "Attend a structured anger-management program.",
						"enabled": true,
					},
					{
						"action_id": "incarceration_program",
						"program_id": "substance_treatment",
						"category": "rehabilitation",
						"label": "Substance Treatment",
						"description": "Attend a supervised recovery program.",
						"enabled": true,
					}
				]

	return out
func _prison_work_actions_for_era(
		era_name: String
) -> Array:
	var out: Array = []

	match era_name:
		"Ancient Era":
			out = [
				_prison_work_row(
					"stone_labor",
					"Stone Laborer",
					"Move stone and supplies under guard supervision.",
					"Rations",
					"Labor Detail"
				),
				_prison_work_row(
					"kitchen_servant",
					"Kitchen Servant",
					"Prepare food for prisoners and guards.",
					"Rations",
					"Kitchen"
				)
			]

		"Medieval Era":
			out = [
				_prison_work_row(
					"castle_labor",
					"Castle Laborer",
					"Perform maintenance and hauling inside the prison.",
					"Room and board",
					"Labor Detail"
				),
				_prison_work_row(
					"prison_kitchen",
					"Kitchen Worker",
					"Prepare meals for the gaol.",
					"Extra rations",
					"Kitchen"
				)
			]

		"Industrial Era":
			out = [
				_prison_work_row(
					"work_camp_labor",
					"Work Camp Laborer",
					"Perform supervised industrial labor.",
					"$0.08 / hour",
					"Industrial Detail"
				),
				_prison_work_row(
					"laundry_worker",
					"Laundry Worker",
					"Clean prison uniforms and linens.",
					"$0.06 / hour",
					"Laundry"
				),
				_prison_work_row(
					"maintenance_worker",
					"Maintenance Worker",
					"Maintain prison buildings and equipment.",
					"$0.10 / hour",
					"Maintenance"
				)
			]

		"Future Era":
			out = [
				_prison_work_row(
					"fabrication_technician",
					"Fabrication Technician",
					"Operate supervised automated fabrication equipment.",
					"6 credits / shift",
					"Fabrication"
				),
				_prison_work_row(
					"data_classification",
					"Data Classification Worker",
					"Perform monitored data-labeling work.",
					"5 credits / shift",
					"Data Operations"
				),
				_prison_work_row(
					"facility_maintenance",
					"Systems Maintenance Worker",
					"Assist with supervised facility maintenance.",
					"7 credits / shift",
					"Maintenance"
				)
			]

		_:
			out = [
				_prison_work_row(
					"kitchen_worker",
					"Kitchen Worker",
					"Prepare meals inside the facility.",
					"$0.25 / hour",
					"Food Service"
				),
				_prison_work_row(
					"laundry_worker",
					"Laundry Worker",
					"Clean prison clothing and linens.",
					"$0.20 / hour",
					"Laundry"
				),
				_prison_work_row(
					"maintenance_worker",
					"Maintenance Worker",
					"Perform supervised repairs and facility upkeep.",
					"$0.35 / hour",
					"Maintenance"
				),
				_prison_work_row(
					"library_clerk",
					"Library Clerk",
					"Organize books and assist with the prison library.",
					"$0.30 / hour",
					"Education"
				)
			]

	return out


func _prison_work_row(
		path_id: String,
		title: String,
		description: String,
		pay_text: String,
		department_name: String
) -> Dictionary:
	return {
		"path_id": path_id,
		"title": title,
		"description": description,
		"organization_name": "Facility Work Program",
		"department_name": department_name,
		"entry_rank_title": "Inmate Worker",
		"pay_amount": 0,
		"pay_text": pay_text,
		"eligibility_label": "YOU'RE ELIGIBLE",
		"qualification_eligible": true,
		"can_apply": true,
		"application_status": "available",
		"requirement_lines": [
			"Must be currently incarcerated.",
			"Assignment remains subject to facility authority."
		],
		"action_id": "incarceration_work",
		"work_id": path_id,
		"ui_is_renderer_only": true
	}
func _prison_activities_surface_contract(
		actor_id: int,
		row: Dictionary
) -> Dictionary:
	var actions: Array = (
		_prison_activity_actions_for_era(
			_current_era_name()
		)
	)

	var categories: Array = [
		{
			"id": "yard",
			"label": "YARD",
			"icon": " ",
			"description": (
				"Physical and social activity inside the facility."
			),
			"actions": []
		},
		{
			"id": "wellbeing",
			"label": "WELLBEING",
			"icon": " ",
			"description": (
				"Actions affecting your incarceration stats."
			),
			"actions": []
		},
		{
			"id": "contact",
			"label": "CONTACT",
			"icon": " ",
			"description": (
				"Approved contact with the outside world."
			),
			"actions": []
		}
	]

	for raw_action in actions:
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		var source_action: Dictionary = raw_action as Dictionary
		var action: Dictionary = {
			"action_id": "incarceration_activity",
			"activity_id": str(
				source_action.get(
					"id",
					""
				)
			),
			"label": str(
				source_action.get(
					"label",
					"Activity"
				)
			),
			"description": str(
				source_action.get(
					"description",
					""
				)
			),
			"enabled": true,
			"facility_id": str(
				row.get(
					"facility_id",
					""
				)
			)
		}
		var category_id: String = str(
			source_action.get(
				"category",
				"yard"
			)
		)

		for category in categories:
			if str(
				category.get(
					"id",
					""
				)
			) == category_id:
				category ["actions"].append(
					action
				)
				break

	return {
		"success": true,
		"schema": "eralife.activities_hub_contract",
		"version": 1,
		"actor_id": actor_id,
		"title": " YARD",
		"subtitle": (
			"Your available actions inside %s."
			% str(
				row.get(
					"facility_label",
					"Prison"
				)
			)
		),
		"active_section": "all",
		"identity_overview": {
			"actor_id": actor_id,
			"location": str(
				row.get(
					"facility_label",
					"Prison"
				)
			),
			"incarcerated": true
		},
		"section_tabs": [
			{
				"id": "all",
				"label": "ALL"
			},
			{
				"id": "yard",
				"label": "YARD"
			},
			{
				"id": "wellbeing",
				"label": "WELLBEING"
			},
			{
				"id": "contact",
				"label": "CONTACT"
			}
		],
		"category_rows": categories,
		"status_text": (
			"Only facility-resident activities are available while incarcerated."
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"projection_complete": true,
		"surface_revision": (
			"prison_activities:%d:%d"
			% [
				actor_id,
				int(
					row.get(
						"updated_at_ms",
						row.get(
							"created_at_ms",
							0
						)
					)
				)
			]
		),
		"ui_is_renderer_only": true
	}
func _prison_school_surface_contract(
		actor_id: int,
		row: Dictionary
) -> Dictionary:
	var tabs: Array = [
		{
			"id": "overview",
			"label": "PROGRAMS"
		},
		{
			"id": "education",
			"label": "EDUCATION"
		},
		{
			"id": "rehabilitation",
			"label": "REHABILITATION"
		}
	]
	var education_actions: Array = (
		_prison_program_actions_for_era(
			_current_era_name(),
			"education"
		)
	)
	var rehabilitation_actions: Array = (
		_prison_program_actions_for_era(
			_current_era_name(),
			"rehabilitation"
		)
	)

	var section_contracts: Dictionary = {
		"overview": {
			"actor_id": actor_id,
			"active_section_id": "overview",
			"tabs": tabs,
			"section_rows": [
				{
					"row_kind": "information",
					"title": "FACILITY PROGRAMS",
					"subtitle": (
						"Ordinary school access is suspended while incarcerated."
					),
					"lines": [
						"Programs are owned by the current facility.",
						"Availability changes by era and facility."
					]
				}
			],
			"truth_state": "hot"
		},
		"education": {
			"actor_id": actor_id,
			"active_section_id": "education",
			"tabs": tabs,
			"section_rows": [
				{
					"row_kind": "actions",
					"title": "EDUCATION",
					"actions": education_actions
				}
			],
			"truth_state": "hot"
		},
		"rehabilitation": {
			"actor_id": actor_id,
			"active_section_id": "rehabilitation",
			"tabs": tabs,
			"section_rows": [
				{
					"row_kind": "actions",
					"title": "REHABILITATION",
					"actions": rehabilitation_actions
				}
			],
			"truth_state": "hot"
		}
	}

	var active: Dictionary = (
		section_contracts [
			"overview"
		].duplicate(false)
	)

	active ["success"] = true
	active ["schema"] = "eralife.school_hub.contract"
	active ["version"] = 1
	active ["title"] = "PROGRAMS"
	active ["subtitle"] = str(
		row.get(
			"facility_label",
			"Prison"
		)
	)
	active ["section_contracts"] = section_contracts
	active ["projection_complete"] = true
	active ["authoritative_projection"] = true
	active ["incarceration_mode"] = true
	active ["ordinary_school_suppressed"] = true
	active ["surface_revision"] = (
		"prison_programs:%d:%s"
		% [
			actor_id,
			str(
				row.get(
					"facility_id",
					""
				)
			)
		]
	)
	active ["ui_is_renderer_only"] = true

	return active
func _prison_career_surface_contract(
		actor_id: int,
		row: Dictionary
) -> Dictionary:
	var jobs: Array = _prison_work_actions_for_era(
		_current_era_name()
	)
	var full_time_catalog: Dictionary = {
		"success": true,
		"schema": "eralife.career_catalog_contract",
		"version": 2,
		"actor_id": actor_id,
		"era_name": _current_era_name(),
		"lane": "full_time",
		"title": "FACILITY WORK ASSIGNMENTS",
		"career_rows": jobs,
		"total_paths": jobs.size(),
		"status_text": "These are the work assignments currently available inside this facility.",
		"ui_is_renderer_only": true
	}
	var part_time_catalog: Dictionary = {
		"success": true,
		"schema": "eralife.career_catalog_contract",
		"version": 2,
		"actor_id": actor_id,
		"era_name": _current_era_name(),
		"lane": "part_time",
		"title": "PART-TIME FACILITY WORK",
		"career_rows": [],
		"total_paths": 0,
		"status_text": "No separate part-time lane exists inside this facility.",
		"ui_is_renderer_only": true
	}

	return {
		"success": true,
		"schema": "eralife.career_hub_contract",
		"version": 1,
		"actor_id": actor_id,
		"actor_name": "",
		"title": " PRISON WORK",
		"subtitle": (
			"Work assignments inside %s."
			% str(
				row.get(
					"facility_label",
					"Prison"
				)
			)
		),
		"current_time": "",
		"era_name": _current_era_name(),
		"active_section": "overview",
		"career_lane": "full_time",
		"selected_path_id": "",
		"section_tabs": [
			{
				"id": "overview",
				"label": "CURRENT"
			},
			{
				"id": "actions",
				"label": "WORK"
			},
			{
				"id": "opportunities",
				"label": "ASSIGNMENTS"
			}
		],
		"identity_overview": {
			"actor_id": actor_id,
			"name": "",
			"role": "Inmate",
			"context": str(
				row.get(
					"facility_label",
					"Prison"
				)
			)
		},
		"overview_cards": [
			{
				"title": "FACILITY WORK",
				"description": (
					"Outside employment is unavailable during incarceration."
				)
			}
		],
		"workload_contract": {
			"employed": false
		},
		"primary_job_actions": [],
		"organization_contract": {},
		"workplace_contract": {},
		"people_contract": {},
		"workflow_contract": {
			"activity_rows": []
		},
		"promotion_contract": {},
		"reputation_contract": {},
		"education_contract": {},
		"opportunity_contract": full_time_catalog,
		"opportunity_contract_by_lane": {
			"full_time": full_time_catalog,
			"part_time": part_time_catalog
		},
		"timeline_contract": {},
		"status_text": (
			"Only facility work assignments are available."
		),
		"incarceration_mode": true,
		"truth_state": "hot",
		"surface_revision": (
			"prison_work:%d:%s:%d"
			% [
				actor_id,
				str(
					row.get(
						"facility_id",
						""
					)
				),
				jobs.size()
			]
		),
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}
func _prison_facility_surface_contract(
		actor_id: int,
		row: Dictionary,
		population_cards: Array
) -> Dictionary:
	var guard_cards: Array = _prison_guard_cards(
		row
	)

	return {
		"schema": "eralife.incarceration_facility_surface",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"title": "FACILITY",
		"subtitle": str(
			row.get(
				"facility_label",
				"Prison"
			)
		),
		"facility_id": str(
			row.get(
				"facility_id",
				""
			)
		),
		"body_lines": [
			(
				"You are incarcerated at %s."
				% str(
					row.get(
						"facility_label",
						"Prison"
					)
				)
			),
			(
				"Security: %s"
				% str(
					row.get(
						"security_level",
						"Medium"
					)
				)
			),
			(
				"Other prisoners currently resident here: %d"
				% population_cards.size()
			),
			(
				"Facility guards currently resident: %d"
				% guard_cards.size()
			)
		],
		"population_count": population_cards.size() + 1,
		"guard_count": guard_cards.size(),
		"truth_state": "hot",
		"projection_complete": true,
		"progressive_observability": true,
		"ui_is_renderer_only": true
	}


func _prison_sentence_surface_contract(
		actor_id: int,
		row: Dictionary
) -> Dictionary:
	var sentence_type: String = str(
		row.get(
			"sentence_type",
			"prison"
		)
	).strip_edges().to_lower()
	var sentence_text: String = ""

	if bool(
		row.get(
			"life_without_parole",
			false
		)
	):
		sentence_text = "Life without parole"
	elif sentence_type == "execution":
		sentence_text = "Death sentence"
	else:
		sentence_text = (
			"%d years"
			% int(
				row.get(
					"sentence_years",
					0
				)
			)
		)

	return {
		"schema": "eralife.incarceration_sentence_surface",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"title": "SENTENCE",
		"subtitle": str(
			row.get(
				"facility_label",
				"Prison"
			)
		),
		"body_lines": [
			"Sentence: %s" % sentence_text,
			(
				"Years served: %d"
				% int(
					row.get(
						"years_served",
						0
					)
				)
			),
			(
				"Years remaining: %d"
				% int(
					row.get(
						"years_remaining",
						0
					)
				)
			),
			(
				"Status: %s"
				% str(
					row.get(
						"status",
						"incarcerated"
					)
				).capitalize()
			)
		],
		"sentence_type": sentence_type,
		"life_without_parole": bool(
			row.get(
				"life_without_parole",
				false
			)
		),
		"execution_schedule": _safe_dictionary(
			row.get(
				"execution_schedule",
				{}
			)
		),
		"truth_state": "hot",
		"projection_complete": true,
		"ui_is_renderer_only": true
	}
func resident_facility_contract_cards(
		exclude_facility_id: String = ""
) -> Array:
	var out: Array = []
	var clean_exclude: String = str(
		exclude_facility_id
	).strip_edges()

	for raw_facility_id in prison_facility_contract_by_id.keys():
		var facility_id: String = str(
			raw_facility_id
		).strip_edges()

		if (
			facility_id == ""
			or facility_id == clean_exclude
		):
			continue

		var contract: Dictionary = _safe_dictionary(
			prison_facility_contract_by_id.get(
				facility_id,
				{}
			)
		)

		if contract.is_empty():
			continue

		var member_count: int = _safe_array(
			prison_facility_members_by_id.get(
				facility_id,
				[]
			)
		).size()
		var guard_count: int = _safe_array(
			prison_guard_ids_by_facility.get(
				facility_id,
				[]
			)
		).size()

		out.append({
			"kind": "incarceration_facility_card",
			"facility_id": facility_id,
			"incarceration_kind": "prison",
			"label": str(
				contract.get(
					"facility_label",
					contract.get(
						"facility_type",
						"Prison"
					)
				)
			),
			"subtitle": (
				"%s • %s • %d inmates • %d guards"
				% [
					str(
						contract.get(
							"era",
							_current_era_name()
						)
					),
					str(
						contract.get(
							"security_level",
							"Medium"
						)
					),
					member_count,
					guard_count
				]
			),
			"security_level": str(
				contract.get(
					"security_level",
					"Medium"
				)
			),
			"resident_count": member_count,
			"guard_count": guard_count,
			"ui_is_renderer_only": true
		})

	return out


func _other_prison_facility_cards(
		current_facility_id: String
) -> Array:
	var out: Array = resident_facility_contract_cards(
		current_facility_id
	)
	var seen: Dictionary = {}

	for raw_card in out:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		seen [
			str(
				(raw_card as Dictionary).get(
					"facility_id",
					""
				)
			)
		] = true



	if (
		gs != null
		and gs.jail_engine != null
		and gs.jail_engine.has_method(
			"resident_facility_contract_cards"
		)
	):
		var jail_cards: Array = gs.jail_engine.call(
			"resident_facility_contract_cards",
			current_facility_id
		)

		for raw_card in jail_cards:
			if typeof(raw_card) != TYPE_DICTIONARY:
				continue

			var card: Dictionary = raw_card as Dictionary
			var facility_id: String = str(
				card.get(
					"facility_id",
					""
				)
			).strip_edges()

			if (
				facility_id == ""
				or seen.has(
					facility_id
				)
			):
				continue

			seen [
				facility_id
			] = true

			out.append(
				card.duplicate(false)
			)

	out.sort_custom(
		func (left: Dictionary, right: Dictionary) -> bool:
			return str(
				left.get(
					"label",
					""
				)
			) < str(
				right.get(
					"label",
					""
				)
			)
	)

	return out
func _prison_main_surface_contracts(
		actor_id: int,
		row: Dictionary,
		population_cards: Array
) -> Dictionary:
	return {
		"relationships": (
			_prison_relationships_surface_contract(
				actor_id,
				row,
				population_cards
			)
		),
		"school": (
			_prison_school_surface_contract(
				actor_id,
				row
			)
		),
		"activities": (
			_prison_activities_surface_contract(
				actor_id,
				row
			)
		),
		"career": (
			_prison_career_surface_contract(
				actor_id,
				row
			)
		)
	}
func _prison_navigation_labels(
		era_name: String
) -> Dictionary:
	match era_name:
		"Ancient Era":
			return {
				"world": "DUNGEON ",
				"life": "SENTENCE ",
				"school": "INSTRUCTION ",
				"activities": "PRISON YARD ",
				"relationships": "PRISONERS / GUARDS ",
				"career": "LABOR ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		"Medieval Era":
			return {
				"world": "DUNGEON ",
				"life": "SENTENCE ",
				"school": "REFORM ",
				"activities": "COURTYARD ",
				"relationships": "PRISONERS / GUARDS ",
				"career": "LABOR ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		"Industrial Era":
			return {
				"world": "WORK CAMP ",
				"life": "SENTENCE ",
				"school": "PROGRAMS ",
				"activities": "YARD ",
				"relationships": "PRISONERS / GUARDS ",
				"career": "CAMP WORK ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		"Future Era":
			return {
				"world": "FACILITY ",
				"life": "SENTENCE ",
				"school": "CORRECTION ",
				"activities": "REC BLOCK ",
				"relationships": "INMATES / AI GUARDS ",
				"career": "FACILITY WORK ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		_:
			return {
				"world": "FACILITY ",
				"life": "SENTENCE ",
				"school": "PROGRAMS ",
				"activities": "YARD ",
				"relationships": "INMATES / GUARDS ",
				"career": "PRISON WORK ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}
func resident_target_access_contract(
		actor_id: int,
		target_id: int
) -> Dictionary:
	var actor_row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				actor_id
			),
			{}
		)
	)

	if actor_row.is_empty():
		return {
			"incarcerated": false,
			"allowed": true
		}

	var target_row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				target_id
			),
			{}
		)
	)
	var facility_id: String = str(
		actor_row.get(
			"facility_id",
			""
		)
	).strip_edges()

	return {
		"incarcerated": true,
		"actor_id": actor_id,
		"target_id": target_id,
		"facility_id": facility_id,
		"allowed": (
			not target_row.is_empty()
			and target_id != actor_id
			and str(
				target_row.get(
					"facility_id",
					""
				)
			).strip_edges() == facility_id
		),
		"population_scan_performed": false,
		"truth_state": "hot",
		"read_only": true
	}
func _register_prison_resident(
		row: Dictionary,
		facility_contract: Dictionary
) -> void:
	var actor_id: int = int(
		row.get(
			"accused_id",
			-1
		)
	)
	var facility_id: String = str(
		row.get(
			"facility_id",
			facility_contract.get(
				"facility_id",
				""
			)
		)
	).strip_edges()

	if (
		actor_id <= 0
		or facility_id == ""
	):
		return

	prison_facility_contract_by_id [
		facility_id
	] = facility_contract.duplicate(true)

	var member_ids: Array = _safe_array(
		prison_facility_members_by_id.get(
			facility_id,
			[]
		)
	).duplicate(false)

	if actor_id not in member_ids:
		member_ids.append(
			actor_id
		)

	member_ids.sort()

	prison_facility_members_by_id [
		facility_id
	] = member_ids

	_assign_prison_cellmate(
		actor_id,
		facility_id
	)




	_ensure_prison_guard_registry_for_facility(
		facility_id,
		facility_contract
	)
func _ensure_prison_guard_registry_for_facility(
		facility_id: String,
		facility_contract: Dictionary
) -> void:
	var clean_facility_id: String = str(
		facility_id
	).strip_edges()

	if (
		clean_facility_id == ""
		or gs == null
	):
		return

	var guard_ids: Array = _safe_array(
		prison_guard_ids_by_facility.get(
			clean_facility_id,
			[]
		)
	).duplicate(false)
	var normalized_guard_ids: Array = []

	for raw_guard_id in guard_ids:
		var guard_id: int = int(
			raw_guard_id
		)

		if (
			guard_id > 0
			and guard_id not in normalized_guard_ids
		):
			normalized_guard_ids.append(
				guard_id
			)

	var security_level: String = str(
		facility_contract.get(
			"security_level",
			"Medium"
		)
	).strip_edges()

	var target_count: int = 3

	match security_level:
		"High":
			target_count = 4

		"Maximum":
			target_count = 5

		_:
			target_count = 3

	target_count = clampi(
		target_count,
		2,
		5
	)

	while normalized_guard_ids.size() < target_count:
		var ordinal: int = normalized_guard_ids.size()
		var guard: Person = _create_prison_guard_person(
			clean_facility_id,
			facility_contract,
			ordinal
		)

		if guard == null:
			break

		normalized_guard_ids.append(
			int(
				guard.id
			)
		)

	prison_guard_ids_by_facility [
		clean_facility_id
	] = normalized_guard_ids


func _create_prison_guard_person(
		facility_id: String,
		facility_contract: Dictionary,
		ordinal: int
) -> Person:
	if (
		gs == null
		or gs.npc_factory == null
		or not gs.npc_factory.has_method(
			"create_random_npc"
		)
	):
		return null

	var guard: Person = gs.npc_factory.create_random_npc(
		false
	)

	if guard == null:
		return null

	var era_name: String = str(
		facility_contract.get(
			"era",
			_current_era_name()
		)
	).strip_edges()
	var role: String = _prison_guard_role_for_era(
		era_name
	)

	guard.age = 24 + int(
		abs(
			hash(
				"%s|guard|%d"
				% [
					facility_id,
					ordinal
				]
			)
		) % 35
	)
	guard.job = role
	guard.alive = true
	guard.health = maxf(
		float(
			guard.health
		),
		65.0
	)
	guard.mental_health = maxf(
		float(
			guard.mental_health
		),
		55.0
	)

	if typeof(guard.traits) != TYPE_ARRAY:
		guard.traits = []

	if "PrisonGuard" not in guard.traits:
		guard.traits.append(
			"PrisonGuard"
		)

	var facility_trait: String = (
		"FacilityStaff:%s"
		% facility_id
	)

	if facility_trait not in guard.traits:
		guard.traits.append(
			facility_trait
		)

	if typeof(guard.memories) != TYPE_ARRAY:
		guard.memories = []

	guard.memories.append(
		(
			"I was assigned to work as %s at %s."
			% [
				role,
				str(
					facility_contract.get(
						"facility_label",
						"the prison"
					)
				)
			]
		)
	)

	if gs.has_method(
		"register_npc"
	):
		gs.register_npc(
			guard
		)
	elif (
		"npcs" in gs
		and typeof(
			gs.npcs
		) == TYPE_ARRAY
	):
		gs.npcs.append(
			guard
		)

	return guard


func _prison_guard_role_for_era(
		era_name: String
) -> String:
	match era_name:
		"Ancient Era":
			return "Dungeon Guard"

		"Medieval Era":
			return "Gaoler"

		"Industrial Era":
			return "Prison Guard"

		"Future Era":
			return "AI-Augmented Correctional Officer"

		_:
			return "Correctional Officer"


func _prison_guard_cards(
		row: Dictionary
) -> Array:
	var facility_id: String = str(
		row.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		return []

	var guard_ids: Array = _safe_array(
		prison_guard_ids_by_facility.get(
			facility_id,
			[]
		)
	)
	var out: Array = []

	for raw_guard_id in guard_ids:
		var guard_id: int = int(
			raw_guard_id
		)

		if guard_id <= 0:
			continue

		var guard: Person = null

		if (
			gs != null
			and gs.has_method(
				"get_npc_by_id"
			)
		):
			guard = gs.get_npc_by_id(
				guard_id,
				false
			)

		if (
			guard == null
			and gs != null
			and gs.has_method(
				"get_or_reactivate_npc_by_id"
			)
		):
			guard = gs.get_or_reactivate_npc_by_id(
				guard_id
			)

		if (
			guard == null
			or not bool(
				guard.alive
			)
		):
			continue

		var guard_name: String = (
			"%s %s"
			% [
				str(
					guard.first_name
				),
				str(
					guard.last_name
				)
			]
		).strip_edges()

		if guard_name == "":
			guard_name = "Guard %d" % guard_id

		out.append({
			"kind": "prison_guard_person_card",
			"card_kind": "person",
			"target_id": guard_id,
			"person_id": guard_id,
			"label": guard_name,
			"name": guard_name,
			"role": str(
				guard.job
			),
			"relationship_label": "Guard",
			"subtitle": (
				"%s • %s"
				% [
					str(
						guard.job
					),
					str(
						row.get(
							"facility_label",
							"Prison"
						)
					)
				]
			),
			"facility_id": facility_id,
			"can_open_profile": true,
			"ui_is_renderer_only": true
		})

	return out
func _unregister_prison_resident(
		actor_id: int,
		facility_id: String
) -> void:
	if actor_id <= 0:
		return

	var clean_facility_id: String = str(
		facility_id
	).strip_edges()
	var actor_key: String = str(
		actor_id
	)
	var former_cellmate_id: int = int(
		prison_cellmate_by_actor.get(
			actor_key,
			-1
		)
	)

	prison_cellmate_by_actor.erase(
		actor_key
	)

	if (
		former_cellmate_id > 0
		and int(
			prison_cellmate_by_actor.get(
				str(
					former_cellmate_id
				),
				-1
			)
		) == actor_id
	):
		prison_cellmate_by_actor.erase(
			str(
				former_cellmate_id
			)
		)

	resident_prison_reality_by_actor.erase(
		actor_key
	)

	if clean_facility_id == "":
		return

	var member_ids: Array = _safe_array(
		prison_facility_members_by_id.get(
			clean_facility_id,
			[]
		)
	).duplicate(false)

	member_ids.erase(
		actor_id
	)

	if member_ids.is_empty():
		prison_facility_members_by_id.erase(
			clean_facility_id
		)
	else:
		member_ids.sort()

		prison_facility_members_by_id [
			clean_facility_id
		] = member_ids

	if (
		former_cellmate_id > 0
		and former_cellmate_id in member_ids
	):
		_assign_prison_cellmate(
			former_cellmate_id,
			clean_facility_id
		)


func _rebuild_resident_prison_indexes_from_canonical_records() -> void:
	resident_prison_reality_by_actor.clear()
	prison_facility_members_by_id.clear()
	prison_cellmate_by_actor.clear()

	for raw_key in inmate_records.keys():
		var actor_id: int = int(
			raw_key
		)
		var row: Dictionary = _safe_dictionary(
			inmate_records.get(
				raw_key,
				{}
			)
		).duplicate(true)

		if (
			actor_id <= 0
			or row.is_empty()
		):
			continue

		var facility_id: String = str(
			row.get(
				"facility_id",
				""
			)
		).strip_edges()

		if facility_id == "":
			var incarceration_context: Dictionary = _safe_dictionary(
				row.get(
					"incarceration_context",
					{}
				)
			)

			facility_id = str(
				incarceration_context.get(
					"facility_id",
					""
				)
			).strip_edges()

		if facility_id == "":
			facility_id = _legacy_prison_facility_id_from_row(
				row
			)

		row ["facility_id"] = facility_id
		row ["incarceration_kind"] = "prison"

		var facility_contract: Dictionary = _safe_dictionary(
			prison_facility_contract_by_id.get(
				facility_id,
				{}
			)
		)

		if facility_contract.is_empty():
			facility_contract = _prison_facility_contract_from_row(
				row
			)

			prison_facility_contract_by_id [
				facility_id
			] = facility_contract.duplicate(true)

		inmate_records [
			str(
				actor_id
			)
		] = row.duplicate(true)

		_register_prison_resident(
			row,
			facility_contract
		)

	for raw_facility_id in prison_facility_members_by_id.keys():
		_publish_prison_facility_residency(
			str(
				raw_facility_id
			),
			"state_hydration"
		)


func _legacy_prison_facility_id_from_row(
		row: Dictionary
) -> String:
	var incarceration_context: Dictionary = _safe_dictionary(
		row.get(
			"incarceration_context",
			{}
		)
	)
	var era_name: String = str(
		incarceration_context.get(
			"era",
			_current_era_name()
		)
	).strip_edges()
	var facility_type: String = str(
		row.get(
			"facility_type",
			"State Prison"
		)
	).strip_edges()

	return (
		"prison:world:%s:%s"
		% [
			era_name.to_lower().replace(
				" ",
				"_"
			),
			facility_type.to_lower().replace(
				" ",
				"_"
			)
		]
	)


func _prison_facility_contract_from_row(
		row: Dictionary
) -> Dictionary:
	var incarceration_context: Dictionary = _safe_dictionary(
		row.get(
			"incarceration_context",
			{}
		)
	)
	var facility_id: String = str(
		row.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		facility_id = _legacy_prison_facility_id_from_row(
			row
		)

	return {
		"schema": "eralife.incarceration_facility_contract",
		"version": CONTRACT_VERSION,
		"facility_id": facility_id,
		"facility_type": str(
			row.get(
				"facility_type",
				"State Prison"
			)
		),
		"facility_label": str(
			row.get(
				"facility_label",
				row.get(
					"facility_type",
					"State Prison"
				)
			)
		),
		"incarceration_kind": "prison",
		"era": str(
			incarceration_context.get(
				"era",
				_current_era_name()
			)
		),
		"security_level": str(
			row.get(
				"security_level",
				"Medium"
			)
		),
		"rules": _safe_array(
			incarceration_context.get(
				"rules",
				[]
			)
		).duplicate(true),
		"restrictions": _safe_array(
			incarceration_context.get(
				"restrictions",
				[]
			)
		).duplicate(true),
		"immutable": true
	}
func _publish_prison_facility_residency(
		facility_id: String,
		reason: String
) -> void:
	var clean_facility_id: String = str(
		facility_id
	).strip_edges()

	if clean_facility_id == "":
		return

	var member_ids: Array = _safe_array(
		prison_facility_members_by_id.get(
			clean_facility_id,
			[]
		)
	).duplicate(false)

	for raw_actor_id in member_ids:
		var actor_id: int = int(
			raw_actor_id
		)

		if actor_id <= 0:
			continue

		var contract: Dictionary = (
			_compose_prison_reality_contract(
				actor_id,
				reason
			)
		)

		if contract.is_empty():
			continue

		resident_prison_reality_by_actor [
			str(
				actor_id
			)
		] = contract.duplicate(false)


func _compose_prison_reality_contract(
		actor_id: int,
		reason: String
) -> Dictionary:
	var row: Dictionary = _safe_dictionary(
		inmate_records.get(
			str(
				actor_id
			),
			{}
		)
	)

	if row.is_empty():
		return {}

	var actor = _actor_by_id(
		actor_id
	)
	var facility_id: String = str(
		row.get(
			"facility_id",
			""
		)
	).strip_edges()
	var population_cards: Array = (
		_prison_population_cards(
			actor_id,
			row
		)
	)
	var crime_target_cards: Array = (
		_prison_crime_target_cards(
			population_cards
		)
	)
	var cellmate_id: int = int(
		prison_cellmate_by_actor.get(
			str(
				actor_id
			),
			-1
		)
	)
	var navigation_labels: Dictionary = (
		_prison_navigation_labels(
			_current_era_name()
		)
	)
	var facility_surface: Dictionary = (
		_prison_facility_surface_contract(
			actor_id,
			row,
			population_cards
		)
	)
	var sentence_surface: Dictionary = (
		_prison_sentence_surface_contract(
			actor_id,
			row
		)
	)
	var surface_contracts: Dictionary = (
		_prison_main_surface_contracts(
			actor_id,
			row,
			population_cards
		)
	)

	var sentence_label: String = ""

	if bool(
		row.get(
			"life_without_parole",
			false
		)
	):
		sentence_label = "Life without parole"
	elif str(
		row.get(
			"sentence_type",
			""
		)
	).strip_edges().to_lower() == "execution":
		sentence_label = "Death sentence"
	else:
		sentence_label = (
			"%d years"
			% int(
				row.get(
					"sentence_years",
					0
				)
			)
		)

	return {
		"schema": "eralife.prison_reality_contract",
		"version": 2,
		"actor_id": actor_id,
		"active": true,
		"incarceration_kind": "prison",
		"identity": {
			"name": (
				(
					"%s %s"
					% [
						str(
							actor.first_name
						),
						str(
							actor.last_name
						)
					]
				).strip_edges()
				if actor != null
				else "Person %d" % actor_id
			),
			"age": (
				int(
					actor.age
				)
				if actor != null
				else -1
			),
			"inmate_id": str(
				row.get(
					"inmate_id",
					""
				)
			),
			"status": str(
				row.get(
					"status",
					"incarcerated"
				)
			)
		},
		"facility": {
			"facility_id": facility_id,
			"type": str(
				row.get(
					"facility_type",
					"Prison"
				)
			),
			"label": str(
				row.get(
					"facility_label",
					"Prison"
				)
			),
			"security_level": str(
				row.get(
					"security_level",
					"Medium"
				)
			),
			"era": _current_era_name()
		},
		"sentence": {
			"label": sentence_label,
			"type": str(
				row.get(
					"sentence_type",
					"prison"
				)
			),
			"years_served": int(
				row.get(
					"years_served",
					0
				)
			),
			"years_remaining": int(
				row.get(
					"years_remaining",
					0
				)
			),
			"life_without_parole": bool(
				row.get(
					"life_without_parole",
					false
				)
			),
			"execution_schedule": _safe_dictionary(
				row.get(
					"execution_schedule",
					{}
				)
			)
		},
		"incarceration_state": {
			"schema": "eralife.incarceration_state",
			"version": CONTRACT_VERSION,
			"active": true,
			"kind": "prison",
			"status": str(
				row.get(
					"status",
					"incarcerated"
				)
			),
			"facility_id": facility_id,
			"case_id": str(
				row.get(
					"case_id",
					""
				)
			)
		},
		"incarceration_context": _safe_dictionary(
			row.get(
				"incarceration_context",
				{}
			)
		),
		"incarceration_stats": _safe_dictionary(
			row.get(
				"incarceration_stats",
				{}
			)
		),
		"navigation_labels": navigation_labels,
		"cellmate_id": cellmate_id,
		"cellmate_assignment_pending": cellmate_id <= 0,
		"population_cards": population_cards,
		"nearby_prisoner_cards": population_cards,
		"crime_target_cards": crime_target_cards,
		"other_facility_cards": _other_prison_facility_cards(
			facility_id
		),
		"facility_surface_contract": facility_surface,
		"sentence_surface_contract": sentence_surface,
		"surface_contracts": surface_contracts,
		"tab_context_map": _incarceration_tab_context_map(
			"prison"
		),
		"truth_state": "hot",
		"projection_complete": true,
		"progressive_observability": true,
		"observation_required": false,
		"source": "prison_engine",
		"publication_reason": reason,
		"immutable": true,
		"ui_is_renderer_only": true,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}

func _default_prison_stats(context: Dictionary) -> Dictionary:
	var security_level: String = str(context.get("security_level", "Medium"))
	var safety: int = 60
	var respect: int = 36
	var guard_heat: int = 18
	var contraband_risk: int = 16

	match security_level:
		"Low":
			safety = 74
			respect = 30
			guard_heat = 12
			contraband_risk = 10
		"Medium":
			safety = 60
			respect = 36
			guard_heat = 22
			contraband_risk = 18
		"High":
			safety = 44
			respect = 42
			guard_heat = 38
			contraband_risk = 30
		"Maximum":
			safety = 28
			respect = 50
			guard_heat = 58
			contraband_risk = 44

	return {
		"safety": safety,
		"respect": respect,
		"mental_stability": 56,
		"guard_heat": guard_heat,
		"contraband_risk": contraband_risk
	}


func _prison_world_snapshot(facility_contract: Dictionary) -> Dictionary:
	var era_name: String = str(facility_contract.get("era", "Modern Era"))
	var facility_type: String = str(facility_contract.get("facility_type", "Prison"))

	var factions: Array = []
	var recent_events: Array = []

	match era_name:
		"Ancient Era":
			factions = ["Chained Prisoners", "Dungeon Guards", "Condemned Captives"]
			recent_events = ["A prisoner rattled chains.", "The guards dragged someone past the cells."]
		"Medieval Era":
			factions = ["Dungeon Prisoners", "Castle Guards", "Noble Prisoners"]
			recent_events = ["A guard inspected the dungeon.", "Someone whispered about torture chambers."]
		"Industrial Era":
			factions = ["Labor Crew", "Foremen", "Cell Block Regulars"]
			recent_events = ["A work bell rang.", "An inmate collapsed during labor."]
		"Future Era":
			factions = ["Monitored Inmates", "AI Guards", "Behavior Review Board"]
			recent_events = ["The facility scanned everyone.", "An AI guard flagged suspicious behavior."]
		_:
			factions = ["Cell Block Regulars", "Yard Crew", "Contraband Network", "Guards"]
			recent_events = ["A fight nearly broke out in the yard.", "Guards searched a cell block."]

	return {
		"population_label": facility_type,
		"total_inmates": 96,
		"factions": factions.duplicate(true),
		"recent_events": recent_events.duplicate(true),
		"transfers": 3,
		"riots": 0,
		"live_counter": true
	}


func _incarceration_tab_context_map(kind: String) -> Dictionary:
	return {
		"world": "%s_population" % kind,
		"life": "%s_daily_routine" % kind,
		"school": "%s_rehab_classes" % kind,
		"activities": "%s_yard_gym_contraband" % kind,
		"relationships": "%s_inmates_guards_household" % kind,
		"career": "%s_jobs" % kind
	}


func _security_level_from_sentence(severity: float, years: int = 0) -> String:
	if severity >= 0.82 or years >= 25:
		return "Maximum"
	if severity >= 0.58 or years >= 10:
		return "High"
	if severity >= 0.32 or years >= 3:
		return "Medium"
	return "Low"


func _actor_by_id(actor_id: int):
	if gs == null or actor_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(actor_id)
		if found != null:
			return found
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var restored = gs.get_or_reactivate_npc_by_id(actor_id)
		if restored != null:
			return restored
	return null


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str(gs.era.get("name", gs.era.get("id", "Modern Era")))
		return str(gs.era.name)
	return "Modern Era"


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func _execute_death_sentence(case_data: Dictionary, sentence: Dictionary) -> Dictionary:
	var accused_id: int = int(case_data.get("participants", {}).get("accused", -1))
	var actor = gs.get_npc_by_id(accused_id) if gs != null and gs.has_method("get_npc_by_id") else null

	var killed: bool = false
	if actor != null and gs != null and gs.health_engine != null and gs.health_engine.has_method("try_kill"):
		killed = gs.health_engine.try_kill(actor, "Execution")

	var payload:= {
		"case_id": str(case_data.get("case_id", "")),
		"accused_id": accused_id,
		"sentence": sentence.duplicate(true),
		"killed": killed
	}

	return _record("prison_execution_applied", payload)

func _set_sentence_trait(actor_id: int, years: int) -> void:
	var actor = _actor_by_id(actor_id)
	if actor == null:
		return

	var next_traits: Array = []
	for raw_trait in actor.traits:
		var t: String = str(raw_trait)
		if t.begins_with("InPrison_") or t.begins_with("OnParole_"):
			continue
		next_traits.append(t)

	next_traits.append("InPrison_%d" % max(1, years))
	actor.traits = next_traits
func _clear_sentence_traits(actor) -> void:
	if actor == null:
		return

	var next_traits: Array = []
	for raw_trait in actor.traits:
		var t: String = str(raw_trait)
		if t.begins_with("InPrison_") or t.begins_with("OnParole_"):
			continue
		next_traits.append(t)

	actor.traits = next_traits

	if str(actor.current_context) == "incarcerated":
		actor.current_context = "free"
func _legacy_trait_sentence_tick(actor) -> Dictionary:
	var new_traits: Array = []
	var release_text: String = ""

	for raw_trait in actor.traits:
		var t: String = str(raw_trait)
		if t.begins_with("InPrison_"):
			var left: int = int(t.split("_") [1]) - 1
			if left > 0:
				new_traits.append("InPrison_%d" % left)
			else:
				release_text = "I finished my prison sentence."
		elif t.begins_with("OnParole_"):
			var parole_left: int = int(t.split("_") [1]) - 1
			if parole_left > 0:
				new_traits.append("OnParole_%d" % parole_left)
		else:
			new_traits.append(t)

	actor.traits = new_traits

	if release_text != "":
		return {
			"success": true,
			"released": true,
			"text": release_text,
			"popup_title": "Release",
			"popup_text": release_text,
			"popup_footer": "Tap anywhere to continue."
		}

	return { "success": true, "released": false}
func resident_incarceration_status_contract(
	actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var row_raw: Variant = inmate_records.get(
		str(
			actor_id
		),
		{}
	)
	var row: Dictionary = (
		row_raw as Dictionary
		if typeof(row_raw) == TYPE_DICTIONARY
		else {}
	)

	return {
		"schema": "eralife.prison.resident_incarceration_status",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"active": not row.is_empty(),
		"status": str(
			row.get(
				"status",
				""
			)
		),
		"read_only": true,
		"truth_state": "hot"
	}
func _record(event_name: String, payload: Dictionary = {}) -> Dictionary:
	var entry:= {
		"event_name": event_name,
		"payload": payload.duplicate(true),
		"year": int(gs.year) if gs != null and gs.get("year") != null else 0,
		"at_ms": int(Time.get_ticks_msec())
	}
	prison_ledger.append(entry)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(event_name, {
			"source": "prison_engine",
			"case_id": str(payload.get("case_id", "")),
			"accused_id": int(payload.get("accused_id", -1)),
			"text": "A prison sentence was processed."
		})

	return {
		"success": true,
		"event_name": event_name,
		"entry": entry.duplicate(true)
	}