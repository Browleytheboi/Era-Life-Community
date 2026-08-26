extends Resource
class_name SchoolEngine
var gs
var enrollment: Dictionary = {}
var school_rosters: Dictionary = {}
var school_teachers: Dictionary = {}
var school_contracts: Dictionary = {}
var school_contract_observations: Dictionary = {}
var school_social_memory: Dictionary = {}
var school_academic_records: Dictionary = {}



var higher_learning_catalog_by_era: Dictionary = {}
var higher_learning_program_index: Dictionary = {}


var school_clique_intro_bond_queue: Array = []
var school_clique_intro_bond_service_active: bool = false

const SCHOOL_CONTRACT_SCHEMA:= "eralife.school_contract"
const SCHOOL_CONTRACT_VERSION:= 1
const SCHOOL_COHORT_MIN:= 101
const SCHOOL_COHORT_MAX:= 232
const SCHOOL_CLASS_SIZE_TARGET:= 26
const SCHOOL_CLASS_PREVIEW_LIMIT:= 10
const SCHOOL_TEACHER_MIN:= 1
const SCHOOL_TEACHER_MAX:= 3

const SCHOOL_MINOR_STAGE_PLAN_STATE_KEY:= (
	"school_engine_minor_stage_plan_state_v1"
)
const SCHOOL_CLIQUE_STATE_KEY:= (
	"school_engine_clique_contract_state"
)
const SCHOOL_CLIQUE_AUTO_MEMBERS_PER_CLIQUE:= 3
const SCHOOL_CLIQUE_VISIBLE_MEMBER_LIMIT:= 6
const SCHOOL_CLIQUE_JOIN_BOND_BONUS:= 10
const SCHOOL_CLIQUE_INTERACTION_MULTIPLIER:= 1.35

func _init(_gs):
	gs = _gs







	_arm_current_era_higher_learning_catalog_warm_service()



var ERA_SCHOOLS = {
	"Ancient Era": {
		"child": ["Temple School", "Pergola School", "Village Tutor"],
		"teen": ["Temple School", "Pergola School", "Agoge", "Scholar House"],
		"young_adult": ["Philosophy Academy", "Military Academy", "Priestly College"],
		"ages": {
			"child_start": 6,
			"teen_start": 12,
			"adult_start": 18
		}
	},
	"Medieval Era": {
		"child": ["Monastic School", "Abbey School", "Village Tutor"],
		"teen": ["Monastic School", "Knight Hall", "Guild Apprenticeship"],
		"young_adult": ["Cathedral School", "Guild College", "Court Education"],
		"ages": {
			"child_start": 6,
			"teen_start": 12,
			"adult_start": 18
		}
	},
	"Industrial Era": {
		"child": ["Public School", "Factory School", "Church School"],
		"teen": ["Public School", "Boarding School", "Trade School"],
		"young_adult": ["Technical Institute", "Teacher College", "Trade Academy"],
		"ages": {
			"child_start": 6,
			"teen_start": 12,
			"adult_start": 18
		}
	},
	"Modern Era": {
		"preschool": ["Preschool"],
		"elementary": ["Elementary School"],
		"child": ["Elementary School"],
		"middle": ["Middle School"],
		"high": ["High School"],
		"young_adult": ["University", "Community College", "Trade School"],
		"ages": {
			"preschool_start": 4,
			"elementary_start": 5,
			"child_start": 5,
			"middle_start": 11,
			"high_start": 14,
			"adult_start": 18
		}
	},
	"Future Era": {
		"preschool": ["Preschool"],
		"child": ["Learning Pod"],
		"middle": ["Neuro-Classroom"],
		"high": ["AI Academy", "Simulation School"],
		"young_adult": ["Cyber Institute", "Orbital Academy", "Terraforming College"],
		"ages": {
			"preschool_start": 4,
			"child_start": 5,
			"middle_start": 11,
			"high_start": 14,
			"adult_start": 18
		}
	}
}

var BENDING_SCHOOLS = {
	"air": {
		"name": "Air Temple",
		"skills": ["air", "discipline", "spirituality", "evade"],
	},
	"water": {
		"name": "Waterbending School",
		"skills": ["water", "healing", "flow_control"],
	},
	"earth": {
		"name": "Earthbending School",
		"skills": ["earth", "metal", "stability"],
	},
	"fire": {
		"name": "Firebending School",
		"skills": ["fire", "breathwork", "aggression_control"],
	},
	"avatar": {
		"name": "Avatar Temple",
		"skills": ["air", "water", "earth", "fire", "spirituality"],
	}
}



func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)

	if player == null or not player.alive:
		return out

	ensure_family_school_reality_for(player)




	var graduation_scenario: Dictionary = (
		_secondary_graduation_scenario_for(
			player,
			context
		)
	)

	if not graduation_scenario.is_empty():
		out.append(
			graduation_scenario
		)

	if _needs_school_enrollment_choice(
		player
	):
		var transition: Dictionary = (
			_next_minor_school_transition_for(
				player
			)
		)
		var planning_stage: String = str(
			transition.get(
				"stage_key",
				""
			)
		)
		var player_choices: Array = (
			_school_enrollment_choices_for(
				player,
				player,
				"child_player",
				planning_stage
			)
		)

		if not player_choices.is_empty():
			out.append({
				"id": (
					"school_enrollment_request_%d_%s_%d"
					% [
						int(
							player.id
						),
						planning_stage,
						int(
							context.get(
								"year",
								0
							)
						)
					]
				),
				"category": "school",
				"source": "school_engine",
				"resolver_owner": "school_engine",
				"resolver_method": "resolve_school_enrollment_choice",
				"school_target_id": int(
					player.id
				),
				"school_requester_role": "child_player",
				"school_stage_key": planning_stage,
				"school_stage_start_age": int(
					transition.get(
						"start_age",
						-1
					)
				),
				"school_request_kind": "stage_preference",
				"era_tags": ["any"],
				"reality_modes": [
					"realistic",
					"enhanced",
					"chaos"
				],
				"reality_weights": {
					"realistic": 1.25,
					"enhanced": 1.0,
					"chaos": 0.9
				},
				"tone": "family",
				"rarity": 1.0,
				"cooldown_key": (
					"school:stage_preference:%d:%s"
					% [
						int(
							player.id
						),
						planning_stage
					]
				),
				"cooldown_years": 1,
				"priority": 34,
				"min_age": int(
					player.age
				),
				"max_age": int(
					player.age
				),
				"prompt": (
					_school_child_enrollment_prompt(
						player,
						planning_stage
					)
				),
				"followup_hooks": [
					"school.enrollment.request"
				],
				"bias_payloads": {},
				"choices": player_choices
			})

	var child_scenario: Dictionary = (
		_parent_school_enrollment_scenario(
			player,
			context
		)
	)

	if not child_scenario.is_empty():
		out.append(
			child_scenario
		)

	if (
		_is_school_visible_age(player)
		and _is_active_student(player)
	):
		var school_label: String = player.school_name

		if school_label == "":
			school_label = "school"

		var contract: Dictionary = (
			get_school_ecosystem_snapshot(
				player
			)
		)
		var active_contract: Dictionary = _safe_dictionary(
			contract.get(
				"active_contract",
				{}
			)
		)
		var social_title: String = str(
			active_contract.get(
				"social_surface_label",
				"School Social Pressure"
			)
		).strip_edges()
		var meal_label: String = str(
			active_contract.get(
				"meal_surface_label",
				"school"
			)
		).strip_edges()

		out.append({
			"id": (
				"school_peer_heat_%d_%d"
				% [
					int(player.id),
					int(context.get("year", 0))
				]
			),
			"category": "school",
			"source": "school_engine",
			"era_tags": ["any"],
			"reality_modes": [
				"realistic",
				"enhanced",
				"chaos"
			],
			"reality_weights": {
				"realistic": 1.15,
				"enhanced": 1.0,
				"chaos": 0.9
			},
			"tone": "awkward",
			"rarity": 0.5,
			"cooldown_key": (
				"school:peer_heat:%d"
				% int(player.id)
			),
			"cooldown_years": 2,
			"priority": 13,
			"min_age": _get_school_start_age(),
			"max_age": _get_school_end_age(),
			"prompt": (
				"%s is forming around me at %s. "
				+ "It followed me through %s. "
				+ "How do I handle it?"
			) % [
				social_title,
				school_label,
				meal_label
			],
			"followup_hooks": [
				"school.peer_heat"
			],
			"bias_payloads": {},
			"choices": [
				{
					"id": "keep_head_down",
					"label": (
						"Keep my head down and protect my peace."
					),
					"journal_line": (
						"I chose to keep my head down "
						+ "and protect my peace at school."
					),
					"followup_hooks": [
						"school.peer_heat.low_profile"
					],
					"bias_payloads": {
						"school_pressure": {
							"peer_tension": 5.0,
							"mental_delta": 1.0
						},
						"relationship_bias": {
							"social_visibility": -4.0
						},
						"expiry": {
							"years": 1
						}
					}
				},
				{
					"id": "stand_on_business",
					"label": (
						"Stand on business and make my presence felt."
					),
					"journal_line": (
						"I decided not to shrink myself "
						+ "at school this year."
					),
					"followup_hooks": [
						"school.peer_heat.visibility"
					],
					"bias_payloads": {
						"school_pressure": {
							"peer_tension": 14.0,
							"smarts_delta": 1.0
						},
						"relationship_bias": {
							"social_visibility": 9.0
						},
						"reputation_bias": {
							"public_attention": 5.0
						},
						"expiry": {
							"years": 1
						}
					}
				}
			]
		})

	return out
func _secondary_graduation_scenario_for(
	person: Person,
	context: Dictionary = {}
) -> Dictionary:
	if not _secondary_completion_due(
		person
	):
		return {}

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)
	var school_name: String = (
		_secondary_school_name_from_record(
			rec
		)
	)
	var era_name: String = str(
		gs.era.name
	)
	var prompt: String = ""
	var higher_label: String = ""
	var year_off_label: String = ""

	match era_name:
		"Ancient Era":
			prompt = (
				"You completed your youth studies at %s. "
				+ "Adult learning is now open to you. "
				+ "What will you do?"
			) % school_name
			higher_label = "Seek Higher Learning"
			year_off_label = "Take a Year Away"

		"Medieval Era":
			prompt = (
				"You completed your schooling at %s. "
				+ "Cathedral schools, guild colleges, and court "
				+ "education may now be within reach. What will you do?"
			) % school_name
			higher_label = "Seek Higher Learning"
			year_off_label = "Take a Year Away"

		"Industrial Era":
			prompt = (
				"You graduated from %s. Institutes, teacher colleges, "
				+ "and trade academies are now possible. "
				+ "What will you do?"
			) % school_name
			higher_label = "Look for Higher Learning"
			year_off_label = "Take a Year Off"

		"Future Era":
			prompt = (
				"You completed your secondary academy studies at %s! "
				+ "Advanced institutes and orbital colleges are now "
				+ "open possibilities. What will you do?"
			) % school_name
			higher_label = "Look for Advanced Learning"
			year_off_label = "Take a Cycle Off"

		_:
			prompt = (
				"You graduated from %s! What will you do?"
				% school_name
			)
			higher_label = "Look for Higher Learning"
			year_off_label = "Take a Year Off"

	return {
		"id": (
			"school_secondary_graduation_%d_%d"
			% [
				int(person.id),
				int(
					context.get(
						"year",
						gs.year
					)
				)
			]
		),
		"category": "school",
		"source": "school_engine",
		"resolver_owner": "school_engine",
		"resolver_method": (
			"resolve_secondary_graduation_choice"
		),
		"era_tags": ["any"],
		"reality_modes": [
			"realistic",
			"enhanced",
			"chaos"
		],
		"reality_weights": {
			"realistic": 1.0,
			"enhanced": 1.0,
			"chaos": 1.0
		},
		"tone": "milestone",
		"rarity": 1.0,
		"priority": 10000,
		"cooldown_key": (
			"school:secondary_graduation:%d"
			% int(person.id)
		),
		"cooldown_years": 1000,
		"min_age": int(person.age),
		"max_age": int(person.age),
		"prompt": prompt,
		"followup_hooks": [
			"school.secondary_graduation"
		],
		"bias_payloads": {},
		"choices": [
			{
				"id": "higher_learning",
				"label": higher_label,
				"journal_line": (
					"I decided to look into higher learning."
				),
				"followup_hooks": [
					"school.secondary_graduation.higher_learning"
				],
				"bias_payloads": {}
			},
			{
				"id": "year_off",
				"label": year_off_label,
				"journal_line": (
					"I decided to take time away before choosing "
					+ "my next education path."
				),
				"followup_hooks": [
					"school.secondary_graduation.year_off"
				],
				"bias_payloads": {}
			},
			{
				"id": "nothing",
				"label": "Nothing",
				"journal_line": (
					"I decided not to pursue anything else right now."
				),
				"followup_hooks": [
					"school.secondary_graduation.nothing"
				],
				"bias_payloads": {}
			}
		]
	}


func _secondary_completion_due(
	person: Person
) -> bool:
	if (
		person == null
		or not person.alive
		or gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
		or not enrollment.has(
			person.id
		)
	):
		return false

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if str(
		rec.get(
			"status",
			"active"
		)
	) != "active":
		return false

	var era_data_raw: Variant = ERA_SCHOOLS.get(
		gs.era.name,
		{}
	)
	var era_data: Dictionary = (
		era_data_raw as Dictionary
		if typeof(era_data_raw) == TYPE_DICTIONARY
		else {}
	)
	var ages_raw: Variant = era_data.get(
		"ages",
		{}
	)
	var ages: Dictionary = (
		ages_raw as Dictionary
		if typeof(ages_raw) == TYPE_DICTIONARY
		else {}
	)
	var adult_start: int = int(
		ages.get(
			"adult_start",
			18
		)
	)

	if int(person.age) != adult_start:
		return false

	var secondary_stage: String = (
		"high"
		if str(gs.era.name) in [
			"Modern Era",
			"Future Era"
		]
		else "teen"
	)
	var secondary_names_raw: Variant = era_data.get(
		secondary_stage,
		[]
	)
	var secondary_names: Array = (
		secondary_names_raw as Array
		if typeof(secondary_names_raw) == TYPE_ARRAY
		else []
	)
	var school_name: String = (
		_secondary_school_name_from_record(
			rec
		)
	)

	return (
		school_name != ""
		and school_name in secondary_names
	)


func _secondary_school_name_from_record(
	rec: Dictionary
) -> String:
	var mode: String = str(
		rec.get(
			"mode",
			""
		)
	).strip_edges()

	if mode == "dual":
		return str(
			rec.get(
				"era_school",
				""
			)
		).strip_edges()

	if mode != "era_school":
		return ""

	return str(
		rec.get(
			"school_name",
			""
		)
	).strip_edges()


func resolve_secondary_graduation_choice(
	actor: Person,
	_scenario: Dictionary,
	choice: Dictionary,
	_committed: Dictionary
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"type": "scenario_commit_complete",
			"text": "The graduation viewpoint is no longer resident."
		}

	var choice_id: String = str(
		choice.get(
			"id",
			""
		)
	).strip_edges().to_lower()
	var graduation_report: Dictionary = (
		graduate_if_ready(
			actor
		)
	)

	if not bool(
		graduation_report.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"type": "scenario_commit_complete",
			"text": str(
				graduation_report.get(
					"text",
					"Graduation could not be committed."
				)
			)
		}

	match choice_id:
		"higher_learning":
			return {
				"success": true,
				"type": "scenario_commit_complete",
				"text": (
					"Graduation is complete. "
					+ "Your resident higher-learning options are ready."
				),
				"popup_title": "HIGHER LEARNING",
				"popup_text": (
					"Choose where you want to study, then choose "
					+ "what you want to study."
				),
				"open_school_hub_after_scenario": true,
				"school_section_id": "overview",
				"log_to_diary": false,
				"ui_is_renderer_only": true
			}

		"year_off":
			return {
				"success": true,
				"type": "scenario_commit_complete",
				"text": (
					"Graduation is complete. "
					+ "You chose to take time away before deciding."
				),
				"popup_title": "YEAR OFF",
				"popup_text": (
					"Higher learning remains part of reality "
					+ "if you decide to pursue it later."
				),
				"log_to_diary": false
			}

		_:
			return {
				"success": true,
				"type": "scenario_commit_complete",
				"text": (
					"Graduation is complete. "
					+ "You chose not to pursue another program right now."
				),
				"popup_title": "GRADUATED",
				"popup_text": (
					"You entered the next stage of your life "
					+ "without choosing higher learning."
				),
				"log_to_diary": false
			}
func get_adult_academic_prompts_for(person: Person) -> Array:
	var prompts:= []

	if person == null:
		return prompts

	if not ERA_SCHOOLS.has(gs.era.name):
		return prompts

	if not can_attend_school(person):
		return prompts

	var def = ERA_SCHOOLS [gs.era.name]
	var ages = def.get("ages", {})
	var adult_start = int(ages.get("adult_start", 18))



	if person.age != adult_start:
		return prompts


	if enrollment.has(person.id):
		var rec = enrollment [person.id]
		if rec.get("status", "active") == "active":
			return prompts

	var young_adult_schools: Array = def.get("young_adult", [])
	for school_name in young_adult_schools:
		prompts.append("Apply to %s" % school_name)

	return prompts
func get_runtime_school_session_catalog(context: Dictionary = {}) -> Array:
	var era_name: String = str(context.get("era", gs.era.name)).strip_edges()
	var out: Array = []
	var adult_stub:= Person.new()
	adult_stub.age = 18
	adult_stub.gender = "Male"
	adult_stub.social_class = "Commoner"
	adult_stub.bending_type = "none"

	var school_types: Array = _era_school_type_contract_names_for_stage(era_name, "high")
	if school_types.is_empty():
		school_types = _era_school_type_contract_names_for_stage(era_name, "adult_learning")
	if school_types.is_empty():
		school_types = ["Local School", "Public Lessons", "Private Tutor", "Apprenticeship Hall"]

	for raw_school in school_types:
		var school_name: String = str(raw_school).strip_edges()
		if school_name == "":
			continue

		var profile: Dictionary = _school_profile_for(school_name, "era_school", adult_stub)
		out.append({
			"id": school_name.to_lower().replace(" ", "_").replace("'", ""),
			"name": school_name,
			"institution_type": str(profile.get("institution_type", "school")),
			"meal_surface_label": str(profile.get("meal_surface_label", "Meal Break")),
			"era": era_name,
			"source": "school_engine"
		})

	return out
func yearly_school_tick(
	_payload = {}
):
	if gs == null:
		return

	var processed_keys: Dictionary = {}

	if gs.era != null:
		_ensure_higher_learning_catalog_for_era(
			str(
				gs.era.name
			)
		)

	if gs.player != null:
		_commit_minor_school_stage_entry_if_due(
			gs.player,
			"school_engine.yearly_school_tick.controlled_actor"
		)




		for raw_child_id in gs.player.children:
			var child_id: int = int(
				raw_child_id
			)
			var child: Person = gs.get_npc_by_id(
				child_id,
				false
			)

			if (
				child == null
				or not child.alive
			):
				continue

			_commit_minor_school_stage_entry_if_due(
				child,
				"school_engine.yearly_school_tick.controlled_parent_child"
			)

	ensure_world_npc_school_reality()

	if gs.player != null:
		ensure_family_school_reality_for(
			gs.player
		)



		_ensure_school_clique_population_for_actor(
			gs.player
		)

	for npc in gs.npcs:
		if npc == null:
			continue
		if not npc.alive:
			continue
		if not enrollment.has(npc.id):
			continue
		if str(
			_safe_dictionary(
				enrollment.get(
					npc.id,
					{}
				)
			).get(
				"mode",
				""
			)
		) == "era_school":
			_sync_era_school_stage(
				npc
			)
		var rec: Dictionary = enrollment [
			npc.id
		]

		if rec.get("status", "active") != "active":
			continue

		if rec.get("mode", "") == "dual":
			var era_school: String = str(
				rec.get(
					"era_school",
					""
				)
			)
			var bend_school: String = str(
				rec.get(
					"bending_school",
					""
				)
			)

			if era_school != "":
				var era_key: String = _school_key(
					era_school,
					"era_school"
				)

				if not processed_keys.has(
					era_key
				):
					_apply_yearly_cohort_churn(
						npc,
						era_school,
						"era_school"
					)
					_ensure_school_contract_for_enrollment(
						npc
					)
					processed_keys [
						era_key
					] = true

			if bend_school != "":
				var bend_key: String = _school_key(
					bend_school,
					"bending_school"
				)

				if not processed_keys.has(
					bend_key
				):
					_apply_yearly_cohort_churn(
						npc,
						bend_school,
						"bending_school"
					)
					_ensure_school_contract_for_enrollment(
						npc
					)
					processed_keys [
						bend_key
					] = true

		else:
			var school_name: String = str(
				rec.get(
					"school_name",
					""
				)
			)
			var mode: String = str(
				rec.get(
					"mode",
					"era_school"
				)
			)

			if school_name == "":
				continue

			var skey: String = _school_key(
				school_name,
				mode
			)

			if processed_keys.has(
				skey
			):
				continue

			_apply_yearly_cohort_churn(
				npc,
				school_name,
				mode
			)
			_ensure_school_contract_for_enrollment(
				npc
			)
			processed_keys [
				skey
			] = true

		_ensure_school_clique_population_for_actor(
			npc
		)
func get_students_for(person: Person) -> Array:
	if person == null:
		return []
	if str(person.school_status) != "staff":
		return []

	var school_name: String = str(person.school_name)
	var mode: String = str(person.school_mode)
	if school_name == "" or school_name == "None":
		return []
	if mode == "" or mode == "None":
		return []

	var ids: Array = []
	var skey: String = _school_key(school_name, mode)
	ids.append_array(school_rosters.get(skey, []))

	var out: Array = []
	var seen:= {}

	for sid in ids:
		var student_id: int = int(sid)
		if student_id <= 0:
			continue
		if seen.has(student_id):
			continue
		seen [student_id] = true

		var student: Person = gs.get_or_reactivate_npc_by_id(student_id)
		if student == null:
			continue
		if not student.alive:
			continue
		if str(student.school_status) != "active":
			continue

		out.append(student)

	return out
func get_school_options_for(person: Person) -> Array:
	var options:= []
	if person == null:
		return options
	if not can_attend_school(person):
		return options

	var era_options: Array = _era_school_options_for_person(person)
	for raw_option in era_options:
		var option: Dictionary = _safe_dictionary(raw_option)
		var school_name: String = str(option.get("name", "")).strip_edges()
		var school_type: String = str(option.get("type", "era_school")).strip_edges()
		if school_name == "" or school_type == "":
			continue
		options.append({
			"type": school_type,
			"name": school_name,
			"contract": _build_school_option_contract(person, school_name, school_type)
		})

	var bending_school = get_bending_school_for(person)
	if bending_school != "" and int(person.age) >= _get_school_start_age() and int(person.age) < 24:
		options.append({
			"type": "bending_school",
			"name": bending_school,
			"contract": _build_school_option_contract(person, bending_school, "bending_school")
		})

	var regular_school_count: int = 0
	for raw_check in options:
		var check: Dictionary = _safe_dictionary(raw_check)
		if str(check.get("type", "")) == "era_school":
			regular_school_count += 1

	if regular_school_count > 0 and bending_school != "" and int(person.age) < 24:
		options.append({
			"type": "dual_enrollment",
			"name": "Dual Enrollment",
			"contract": {
				"schema": SCHOOL_CONTRACT_SCHEMA + ".option",
				"version": SCHOOL_CONTRACT_VERSION,
				"type": "dual_enrollment",
				"name": "Dual Enrollment",
				"era": gs.era.name,
				"tuition": 0.0,
				"lane": "school",
				"contract_mesh": {
					"combines": ["era_school", "bending_school"]
				}
			}
		})

	return options

func get_default_school_for(
	person: Person
) -> String:
	if person == null:
		return ""

	var stage_key: String = (
		_school_stage_key_for_person(
			person
		)
	)

	if stage_key == "":
		return ""

	if _is_minor_school_actor(
		person
	):
		var custodial_choice: Dictionary = (
			_custodial_default_school_for_stage(
				person,
				stage_key
			)
		)

		return str(
			custodial_choice.get(
				"name",
				""
			)
		).strip_edges()

	var options: Array = (
		_era_school_options_for_person(
			person,
			stage_key
		)
	)

	if options.is_empty():
		return ""

	var choice_seed: int = _stable_school_seed(
		"%d|%s|%s|default_school"
		% [
			int(
				person.id
			),
			str(
				gs.era.name
			),
			stage_key
		]
	)
	var picked: Dictionary = _safe_dictionary(
		options [
			choice_seed % options.size()
		]
	)

	return str(
		picked.get(
			"name",
			""
		)
	).strip_edges()
func _school_custodial_adult_for(
	child: Person
) -> Person:
	if (
		child == null
		or gs == null
	):
		return null

	if (
		gs.family_contract_engine != null
		and gs.family_contract_engine.has_method(
			"get_custodial_adult"
		)
	):
		var custodial_raw: Variant = (
			gs.family_contract_engine.get_custodial_adult(
				child,
				{
					"source": (
						"school_engine."
						+ "custodial_school_authority"
					),
					"read_only": true,
				}
			)
		)

		if custodial_raw is Person:
			var custodial_person: Person = (
				custodial_raw as Person
			)

			if custodial_person.alive:
				return custodial_person

	for raw_parent_id in child.parents:
		var parent_id: int = int(
			raw_parent_id
		)
		var parent: Person = null

		if (
			gs.player != null
			and int(
				gs.player.id
			) == parent_id
		):
			parent = gs.player
		else:
			parent = gs.get_npc_by_id(
				parent_id,
				false
			)

		if (
			parent == null
			or not parent.alive
			or int(
				parent.age
			) < 18
		):
			continue

		return parent

	return null


func _custodial_school_option_score(
	child: Person,
	custodian: Person,
	option: Dictionary,
	stage_key: String
) -> int:
	var contract: Dictionary = _safe_dictionary(
		option.get(
			"contract",
			{}
		)
	)
	var school_name: String = str(
		option.get(
			"name",
			""
		)
	).strip_edges()
	var lower_name: String = (
		school_name.to_lower()
	)
	var tuition: float = float(
		contract.get(
			"tuition",
			0.0
		)
	)
	var score: int = 40

	if lower_name.contains(
		"public"
	):
		score += 28

	if lower_name.contains(
		"private"
	):
		score += 8

	if lower_name.contains(
		"boarding"
	):
		score -= 4

	if tuition <= 0.0:
		score += 12

	if custodian != null:
		var available_wealth: float = maxf(
			0.0,
			float(
				custodian.bank_balance
			)
		)
		var custodian_class: String = str(
			custodian.social_class
		).strip_edges().to_lower()

		if tuition > 0.0:
			if available_wealth >= tuition * 10.0:
				score += 32
			elif available_wealth >= tuition * 4.0:
				score += 20
			elif available_wealth >= tuition * 2.0:
				score += 8
			elif available_wealth >= tuition:
				score -= 8
			else:
				score -= 42

		if custodian_class in [
			"royal",
			"noble"
		]:
			if (
				lower_name.contains(
					"private"
				)
				or lower_name.contains(
					"boarding"
				)
			):
				score += 22

		elif (
			custodian_class.contains(
				"upper"
			)
			or custodian_class.contains(
				"wealth"
			)
		):
			if (
				lower_name.contains(
					"private"
				)
				or lower_name.contains(
					"boarding"
				)
			):
				score += 12

	if child != null:
		if child.is_royal:
			if (
				lower_name.contains(
					"private"
				)
				or lower_name.contains(
					"boarding"
				)
			):
				score += 12

		if int(
			child.smarts
		) >= 75:
			score += 5

	var tie_break: int = (
		_stable_school_seed(
			"%d|%d|%s|%s|custodial_default"
			% [
				int(
					child.id
				)
				if child != null
				else -1,
				int(
					custodian.id
				)
				if custodian != null
				else -1,
				stage_key,
				school_name
			]
		)
		% 11
	)

	return score + tie_break


func _custodial_default_school_for_stage(
	child: Person,
	stage_key: String
) -> Dictionary:
	var options: Array = (
		get_school_options_for_stage(
			child,
			stage_key
		)
	)

	if options.is_empty():
		return {}

	var custodian: Person = (
		_school_custodial_adult_for(
			child
		)
	)
	var best_option: Dictionary = {}
	var best_score: int = -2147483648

	for raw_option in options:
		var option: Dictionary = _safe_dictionary(
			raw_option
		)

		if option.is_empty():
			continue

		var score: int = (
			_custodial_school_option_score(
				child,
				custodian,
				option,
				stage_key
			)
		)

		if (
			best_option.is_empty()
			or score > best_score
		):
			best_option = option
			best_score = score

	return best_option.duplicate(true)
func get_bending_school_for(person: Person) -> String:
	if person.bending_type == "none":
		return ""

	if not BENDING_SCHOOLS.has(person.bending_type):
		return ""

	return BENDING_SCHOOLS [person.bending_type] ["name"]

func _education_rights_allow_person(
	person: Person
) -> bool:
	if (
		person == null
		or gs == null
		or gs.era_engine == null
	):
		return false

	var rights: Dictionary = _safe_dictionary(
		gs.era_engine.rights()
	)

	if (
		str(
			person.gender
		) == "Female"
		and not bool(
			rights.get(
				"women_can_education",
				true
			)
		)
	):
		if person.bending_type in [
			"air",
			"avatar"
		]:
			return true

		if person.is_royal:
			return true

		if person.social_class in [
			"Noble",
			"Royal"
		]:
			return true

		return false

	return true


func can_attend_school(
	person: Person
) -> bool:
	if person == null:
		return false

	if int(
		person.age
	) < _get_school_start_age():
		return false

	return _education_rights_allow_person(
		person
	)

func enroll_in_era_school(person: Person) -> Dictionary:
	if not can_attend_school(person):
		return { "success": false, "text": "❌ I am not permitted to attend school in this era."}

	var school_name = get_default_school_for(person)
	if school_name == "":
		return { "success": false, "text": "❌ There is no suitable era school for my age."}

	return _enroll(person, school_name, "era_school")

func enroll_in_bending_school(person: Person) -> Dictionary:
	if person.bending_type == "none":
		return { "success": false, "text": "❌ I am not a bender."}

	var school_name = get_bending_school_for(person)
	if school_name == "":
		return { "success": false, "text": "❌ No bending school is available."}

	return _enroll(person, school_name, "bending_school")

func enroll_dual(person: Person) -> Dictionary:
	if not can_attend_school(person):
		return { "success": false, "text": "❌ I am not permitted to attend school in this era."}

	if person.bending_type == "none":
		return { "success": false, "text": "❌ Dual enrollment requires a bending ability."}

	var era_school = get_default_school_for(person)
	var bend_school = get_bending_school_for(person)

	if era_school == "" or bend_school == "":
		return { "success": false, "text": "❌ Dual enrollment is not available."}

	enrollment [person.id] = {
		"mode": "dual",
		"era_school": era_school,
		"bending_school": bend_school,
		"started_age": person.age,
		"status": "active"
	}
	_register_student_in_roster(person.id, _school_key(era_school, "era_school"))
	_register_student_in_roster(person.id, _school_key(bend_school, "bending_school"))
	_ensure_schoolmates(person, era_school, "era_school")
	_ensure_schoolmates(person, bend_school, "bending_school")
	sync_person_school_fields(person)

	var txt = "I enrolled in %s and %s." % [era_school, bend_school]
	gs.narrative_engine.log_event(person, { "type": "text", "text": txt})
	return { "success": true, "text": txt}

func drop_out(person: Person) -> Dictionary:
	if not enrollment.has(person.id):
		return { "success": false, "text": "❌ I am not currently enrolled in school."}

	enrollment [person.id] ["status"] = "dropped"
	sync_person_school_fields(person)

	var txt = "I dropped out of school."
	gs.narrative_engine.log_event(person, { "type": "text", "text": txt})
	return { "success": true, "text": txt}

func get_classmates(person: Person) -> Array:
	if person == null:
		return []
	if not _is_active_student(person):
		return []

	var stage_key: String = _school_stage_key_for_person(
		person
	)

	if (
		not _is_school_visible_age(person)
		and stage_key == ""
	):
		return []

	var ids: Array = []
	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if rec.is_empty():
		return []

	if str(rec.get("mode", "")) == "dual":
		var era_school: String = str(
			rec.get(
				"era_school",
				""
			)
		).strip_edges()
		var bending_school: String = str(
			rec.get(
				"bending_school",
				""
			)
		).strip_edges()

		if era_school != "":
			var era_roster_raw: Variant = (
				school_rosters.get(
					_school_key(
						era_school,
						"era_school"
					),
					[]
				)
			)

			if typeof(
				era_roster_raw
			) == TYPE_ARRAY:
				ids.append_array(
					era_roster_raw as Array
				)

		if bending_school != "":
			var bending_roster_raw: Variant = (
				school_rosters.get(
					_school_key(
						bending_school,
						"bending_school"
					),
					[]
				)
			)

			if typeof(
				bending_roster_raw
			) == TYPE_ARRAY:
				ids.append_array(
					bending_roster_raw as Array
				)

	else:
		var school_name: String = str(
			rec.get(
				"school_name",
				""
			)
		).strip_edges()
		var mode: String = str(
			rec.get(
				"mode",
				"era_school"
			)
		).strip_edges()

		if (
			school_name == ""
			or mode == ""
		):
			return []

		var roster_raw: Variant = (
			school_rosters.get(
				_school_key(
					school_name,
					mode
				),
				[]
			)
		)

		if typeof(
			roster_raw
		) == TYPE_ARRAY:
			ids.append_array(
				roster_raw as Array
			)

	var out: Array = []
	var seen: Dictionary = {}

	for raw_id in ids:
		var npc_id: int = int(
			raw_id
		)

		if npc_id == int(person.id):
			continue
		if seen.has(npc_id):
			continue

		seen [
			npc_id
		] = true


		var npc: Person = gs.get_npc_by_id(
			npc_id
		)

		if (
			npc != null
			and npc.alive
		):
			out.append(
				npc
			)

	return out

func attend_school_year(person: Person) -> Dictionary:
	if not _is_school_visible_age(person):
		return { "success": false, "text": "I am no longer school-aged."}

	if not enrollment.has(
		person.id
	):
		if _is_minor_school_actor(
			person
		):
			return {
				"success": false,
				"text": (
					"My parent or guardian has not "
					+ "completed my school enrollment."
				),
			}

		var auto: bool = _auto_assign_school(
			person
		)

		if not auto:
			return {
				"success": false,
				"text": "I did not attend school this year."
			}

	var rec = enrollment [person.id]
	if rec.get("status", "active") != "active":
		return { "success": false, "text": "I am no longer attending school."}

	_sync_era_school_stage(person)
	rec = enrollment [person.id]

	var lines:= []

	if rec ["mode"] == "era_school":
		lines.append("I attended %s." % rec ["school_name"])
		_apply_era_school_effects(person, rec ["school_name"])
	elif rec ["mode"] == "bending_school":
		lines.append("I attended %s." % rec ["school_name"])
		_apply_bending_school_effects(person, rec ["school_name"])
	elif rec ["mode"] == "dual":
		lines.append("I balanced classes between %s and %s." % [rec ["era_school"], rec ["bending_school"]])
		_apply_era_school_effects(person, rec ["era_school"])
		_apply_bending_school_effects(person, rec ["bending_school"])
	elif rec ["mode"] == "college_major":
		var major_name: String = str(rec.get("major", _major_from_school_name(str(rec.get("school_name", ""))))).strip_edges()
		lines.append("I attended college for %s." % major_name)
		_apply_era_school_effects(person, str(rec.get("school_name", "")))
	elif rec ["mode"] == "graduate_school":
		var grad_name: String = str(rec.get("graduate_school", rec.get("school_name", ""))).strip_edges()
		lines.append("I attended %s." % grad_name)
		_apply_era_school_effects(person, str(rec.get("school_name", "")))

	person.mental_health -= randf() * 2.0

	rec ["years_attended"] = int(rec.get("years_attended", 0)) + 1
	enrollment [person.id] = rec
	_advance_postsecondary_record_for_year(person, rec)

	if gs != null and gs.scenario_engine != null:
		var scenario_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(person.id)
		var school_pressure: Dictionary = scenario_bias.get("school_pressure", {})
		if not school_pressure.is_empty():
			person.mental_health += float(school_pressure.get("mental_delta", 0.0))
			person.smarts = clamp(
				int(person.smarts) + int(round(float(school_pressure.get("smarts_delta", 0.0)))),
				0,
				100
			)
			var peer_tension: float = float(school_pressure.get("peer_tension", 0.0))
			if peer_tension >= 10.0:
				var drama_text:= "Tension followed me through school this year."
				lines.append(drama_text)
				if gs.event_bus != null:
					gs.event_bus.emit(ActionEventTypes.SCHOOL_DRAMA, {
						"npc_id": person.id,
						"text": drama_text,
						"source": "school_engine",
						"intensity": int(round(peer_tension))
					})

	var school_event = _random_school_event(person)
	if school_event != "":
		lines.append(school_event)

	for line in lines:
		gs.narrative_engine.log_event(person, { "type": "text", "text": line})

	sync_person_school_fields(person)
	return { "success": true, "text": lines.pick_random()}
func _advance_postsecondary_record_for_year(person: Person, rec: Dictionary) -> void:
	if person == null:
		return

	var mode: String = str(rec.get("mode", "")).strip_edges()
	if mode not in ["college_major", "graduate_school"]:
		return

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	if record.is_empty():
		record = {
			"completed_college_majors": [],
			"major_scores": {},
			"graduate_schools": [],
			"last_updated_year": int(gs.year)
		}

	if mode == "college_major":
		var major_name: String = str(rec.get("major", "")).strip_edges()
		var years: int = int(rec.get("years_attended", 0))
		var scores: Dictionary = _safe_dictionary(record.get("major_scores", {}))
		if major_name != "":
			scores [major_name] = max(int(scores.get(major_name, 0)), _college_performance_score(person))
			record ["major_scores"] = scores

			if years >= 4:
				var completed: Array = _safe_array(record.get("completed_college_majors", []))
				if major_name not in completed:
					completed.append(major_name)
				record ["completed_college_majors"] = completed

	if mode == "graduate_school":
		var grad_name: String = str(rec.get("graduate_school", rec.get("school_name", ""))).strip_edges()
		var grad_rows: Array = _safe_array(record.get("graduate_schools", []))
		if grad_name != "" and grad_name not in grad_rows:
			grad_rows.append(grad_name)
		record ["graduate_schools"] = grad_rows

	record ["last_updated_year"] = int(gs.year)
	school_academic_records [key] = record

func interact_with_classmate(classmate: Person, action: String, item:= {}) -> Dictionary:
	match action:
		"compliment":
			return gs.relationship_activities_engine.compliment(classmate)
		"converse":
			return gs.relationship_activities_engine.converse(classmate)
		"gift":
			return gs.relationship_activities_engine.gift(classmate, item)
		"give_money":
			return gs.relationship_activities_engine.give_money(classmate, int(item.get("amount", 10)))
		"ask_out":
			return gs.relationship_activities_engine.ask_out(classmate)
		"fight":
			var result = gs.relationship_activities_engine.crime_on_person(classmate, "attack")
			gs.event_bus.emit(ActionEventTypes.SCHOOL_DRAMA, {
				"npc_id": gs.player.id,
				"target_id": classmate.id,
				"text": "A school fight broke out between %s and %s." % [
					gs.player.first_name, classmate.first_name
				],
				"drama_type": "fight"
			})
			return result
		"insult":
			return gs.relationship_activities_engine.insult(classmate)
		"betray":
			return gs.relationship_activities_engine.betray(classmate)
		"era_activity":
			return gs.relationship_activities_engine.era_activity(classmate)
		"spar":
			return _spar_with_classmate(classmate)
		_:
			return { "text": "\n❌\n Unknown school interaction."}

func graduate_if_ready(person: Person) -> Dictionary:
	if not enrollment.has(person.id):
		return {
			"success": false,
			"text": " I am not enrolled."
		}

	var rec: Dictionary = enrollment [
		person.id
	]

	if rec.get("status", "active") != "active":
		return {
			"success": false,
			"text": "   I am not currently enrolled."
		}

	var adult_start: int = 18

	if (
		gs != null
		and gs.era != null
		and ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		var era_data_raw: Variant = ERA_SCHOOLS.get(
			gs.era.name,
			{}
		)
		var era_data: Dictionary = (
			era_data_raw as Dictionary
			if typeof(era_data_raw) == TYPE_DICTIONARY
			else {}
		)
		var ages_raw: Variant = era_data.get(
			"ages",
			{}
		)
		var ages: Dictionary = (
			ages_raw as Dictionary
			if typeof(ages_raw) == TYPE_DICTIONARY
			else {}
		)

		adult_start = int(
			ages.get(
				"adult_start",
				18
			)
		)

	if (
		person.age < adult_start
		and str(
			rec.get(
				"mode",
				""
			)
		) != "bending_school"
	):
		return {
			"success": false,
			"text": " I am too young to graduate."
		}

	rec ["status"] = "graduated"
	enrollment [
		person.id
	] = rec

	sync_person_school_fields(
		person
	)

	person.smarts += 5
	person.satisfaction += 10
	person.dynasty_prestige += 1

	gs.dynasty_legacy_engine.add_reputation(
		person,
		2
	)

	var txt: String = (
		"I graduated from %s."
		% _school_record_name(
			rec
		)
	)

	gs.narrative_engine.log_event(
		person,
		{
			"type": "text",
			"text": txt
		}
	)

	return {
		"success": true,
		"text": txt,
		"graduated_school": (
			_school_record_name(
				rec
			)
		),
		"graduation_age": int(
			person.age
		),
		"adult_start_age": adult_start
	}



func sync_person_school_fields(person: Person) -> void:
	if person == null:
		return

	_repair_shared_school_enrollment(
		person
	)

	if not enrollment.has(
		person.id
	):
		person.school_mode = ""
		person.school_name = ""
		person.school_status = ""
		person.education_level = "None"
		return

	var rec: Dictionary = enrollment [
		person.id
	]
	var mode: String = str(
		rec.get(
			"mode",
			""
		)
	)
	var status: String = str(
		rec.get(
			"status",
			""
		)
	)
	var era_level: String = (
		get_default_school_for(
			person
		)
	)

	person.school_mode = mode
	person.school_status = (
		status
		if status != ""
		else "None"
	)

	match mode:
		"dual":
			var era_school: String = str(
				rec.get(
					"era_school",
					""
				)
			)
			var bending_school: String = str(
				rec.get(
					"bending_school",
					""
				)
			)

			person.school_name = (
				"%s and %s"
				% [
					era_school,
					bending_school
				]
			)
			person.education_level = (
				era_level
				if era_level != ""
				else "Dual Enrollment"
			)

		"era_school":
			person.school_name = str(
				rec.get(
					"institution_name",
					rec.get(
						"school_name",
						""
					)
				)
			)
			person.education_level = str(
				rec.get(
					"program",
					(
						era_level
						if era_level != ""
						else person.school_name
					)
				)
			)

		"bending_school":
			person.school_name = str(
				rec.get(
					"school_name",
					""
				)
			)
			person.education_level = "Bending School"

		"college_major":
			person.school_name = str(
				rec.get(
					"institution_name",
					rec.get(
						"school_name",
						""
					)
				)
			)

			var major_name: String = str(
				rec.get(
					"major",
					_major_from_school_name(
						str(
							rec.get(
								"school_name",
								""
							)
						)
					)
				)
			).strip_edges()

			person.education_level = (
				"College - %s"
				% (
					major_name
					if major_name != ""
					else "Undeclared"
				)
			)

		"graduate_school":
			person.school_name = str(
				rec.get(
					"school_name",
					""
				)
			)
			person.education_level = str(
				rec.get(
					"graduate_school",
					person.school_name
				)
			)

		_:
			person.school_name = ""
			person.education_level = "None"

	if person.school_name == "":
		person.school_name = "None"
	if person.school_mode == "":
		person.school_mode = "None"
	if person.school_status == "":
		person.school_status = "None"
	if person.education_level == "":
		person.education_level = "None"
func _parse_school_key(skey: String) -> Dictionary:
	var parts: Array = skey.split("|", false, 3)
	if parts.size() < 3:
		return {
			"era": "",
			"mode": "",
			"name": skey
		}
	return {
		"era": str(parts [0]),
		"mode": str(parts [1]),
		"name": str(parts [2])
	}


func _get_bending_school_element_from_name(school_name: String) -> String:
	for element in ["air", "water", "earth", "fire", "avatar"]:
		if not BENDING_SCHOOLS.has(element):
			continue
		if str(BENDING_SCHOOLS [element].get("name", "")) == school_name:
			return element
	return ""


func _school_accepts_bending_type(school_name: String, bending_type: String) -> bool:
	var school_element: String = _get_bending_school_element_from_name(school_name)
	if school_element == "":
		return false

	if school_element == "avatar":
		return bending_type in ["air", "water", "earth", "fire", "avatar"]

	return bending_type == school_element
func _auto_assign_school(person: Person) -> bool:
	if not _is_school_visible_age(person):
		return false
	if not can_attend_school(person):
		return false

	if person.bending_type in ["air", "water", "earth", "fire", "avatar"]:
		var shared_bending_school: String = _find_shared_bending_school_override(person)
		if shared_bending_school != "":
			var shared_result: Dictionary = _enroll(person, shared_bending_school, "bending_school")
			return bool(shared_result.get("success", false))

		var bend_result: Dictionary = enroll_in_bending_school(person)
		return bool(bend_result.get("success", false))

	var school_name = get_default_school_for(person)
	if school_name == "":
		return false
	var era_result: Dictionary = enroll_in_era_school(person)
	return bool(era_result.get("success", false))
func _find_shared_bending_school_override(person: Person) -> String:
	if person == null:
		return ""
	if str(person.bending_type) not in ["air", "water", "earth", "fire", "avatar"]:
		return ""

	for skey in school_rosters.keys():
		var parsed: Dictionary = _parse_school_key(str(skey))
		if str(parsed.get("era", "")) != str(gs.era.name):
			continue
		if str(parsed.get("mode", "")) != "bending_school":
			continue

		var school_name: String = str(parsed.get("name", ""))
		if school_name != "Avatar Temple":
			continue

		_sanitize_school_roster(str(skey), person)
		var roster_ids: Array = school_rosters.get(skey, [])

		for sid in roster_ids:
			var schoolmate: Person = gs.get_or_reactivate_npc_by_id(int(sid))
			if schoolmate == null:
				continue
			if not schoolmate.alive:
				continue
			if int(schoolmate.id) == int(person.id):
				continue
			if str(schoolmate.school_status) != "active":
				continue
			if schoolmate.home_city != person.home_city:
				continue
			if schoolmate.home_country != person.home_country:
				continue
			if not _same_school_age_group(person, schoolmate):
				continue
			return "Avatar Temple"

	return ""


func _repair_shared_school_enrollment(person: Person) -> void:
	if person == null:
		return
	if not enrollment.has(person.id):
		return
	if not _is_school_visible_age(person):
		return

	var rec: Dictionary = enrollment.get(person.id, {})
	if rec.is_empty():
		return
	if str(rec.get("status", "active")) != "active":
		return

	var shared_bending_school: String = _find_shared_bending_school_override(person)
	if shared_bending_school == "":
		return

	var current_mode: String = str(rec.get("mode", ""))
	var current_school_name: String = str(rec.get("school_name", ""))
	var current_bending_school: String = str(rec.get("bending_school", ""))

	if current_mode == "dual":
		if current_bending_school == shared_bending_school:
			return

		rec ["bending_school"] = shared_bending_school
		enrollment [person.id] = rec

		var era_school_name: String = str(rec.get("era_school", ""))
		if era_school_name != "":
			_register_student_in_roster(person.id, _school_key(era_school_name, "era_school"))
			_ensure_schoolmates(person, era_school_name, "era_school")
			_ensure_school_teachers(person, era_school_name, "era_school")

		_register_student_in_roster(person.id, _school_key(shared_bending_school, "bending_school"))
		_ensure_schoolmates(person, shared_bending_school, "bending_school")
		_ensure_school_teachers(person, shared_bending_school, "bending_school")
		return

	if current_mode == "bending_school" and current_school_name == shared_bending_school:
		return

	enrollment [person.id] = {
		"mode": "bending_school",
		"school_name": shared_bending_school,
		"started_age": int(rec.get("started_age", person.age)),
		"status": "active"
	}

	_register_student_in_roster(person.id, _school_key(shared_bending_school, "bending_school"))
	_ensure_schoolmates(person, shared_bending_school, "bending_school")
	_ensure_school_teachers(person, shared_bending_school, "bending_school")

func _enroll(person: Person, school_name: String, mode: String) -> Dictionary:
	var contract: Dictionary = _build_school_contract(person, school_name, mode)
	enrollment [person.id] = {
		"mode": mode,
		"school_name": school_name,
		"started_age": person.age,
		"status": "active",
		"contract_id": str(contract.get("contract_id", "")),
		"institution_type": str(contract.get("institution_type", "")),
		"era_school_stage": str(contract.get("school_stage", "")),
		"program": str(contract.get("program", "")),
		"lane": str(contract.get("lane", "school")),
		"tuition": float(contract.get("tuition", 0.0)),
		"major": str(contract.get("major", "")),
		"graduate_school": str(contract.get("graduate_school", "")),
		"required_major": str(contract.get("required_major", "")),
		"scholarship_eligible": bool(contract.get("scholarship_eligible", false)),
		"scholarship_reason": str(contract.get("scholarship_reason", "")),
		"years_attended": 0,
		"meal_surface_label": str(contract.get("meal_surface_label", ""))
	}

	var skey = _school_key(school_name, mode)
	_register_student_in_roster(person.id, skey)
	_ensure_schoolmates(person, school_name, mode)
	_ensure_school_teachers(person, school_name, mode)
	_ensure_school_contract_for_enrollment(person)
	_seed_postsecondary_record_if_needed(person, enrollment [person.id])
	sync_person_school_fields(person)

	var txt = "I enrolled in %s." % school_name
	gs.narrative_engine.log_event(person, { "type": "text", "text": txt})
	return {
		"success": true,
		"text": txt,
		"contract_id": str(contract.get("contract_id", "")),
		"school_contract": contract
	}
func _school_key(name: String, mode: String) -> String:
	return "%s|%s|%s" % [gs.era.name, mode, name]

func _school_record_name(rec: Dictionary) -> String:
	if str(
		rec.get(
			"mode",
			""
		)
	) == "dual":
		return (
			"%s and %s"
			% [
				str(
					rec.get(
						"era_school",
						""
					)
				),
				str(
					rec.get(
						"bending_school",
						""
					)
				)
			]
		)

	var institution_name: String = str(
		rec.get(
			"institution_name",
			""
		)
	).strip_edges()
	var program_name: String = str(
		rec.get(
			"program",
			""
		)
	).strip_edges()

	if institution_name != "":
		if (
			program_name != ""
			and program_name != institution_name
		):
			return (
				"%s — %s"
				% [
					institution_name,
					program_name
				]
			)

		return institution_name

	return str(
		rec.get(
			"school_name",
			""
		)
	)
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_join_strings(values: Array, separator: String = ", ") -> String:
	var out: String = ""
	for i in range(values.size()):
		if i > 0:
			out += separator
		out += str(values [i])
	return out
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _stable_school_seed(material: String) -> int:
	var seed_value: int = abs(str(material).hash())
	if seed_value <= 0:
		seed_value = 1
	return seed_value


func _school_contract_id(school_name: String, mode: String) -> String:
	return _school_key(school_name, mode)


func _era_school_options_for_person(
	person: Person,
	stage_override: String = ""
) -> Array:
	var out: Array = []

	if person == null:
		return out

	if (
		gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		return out

	var era_name: String = str(
		gs.era.name
	)
	var stage_key: String = str(
		stage_override
	).strip_edges().to_lower()

	if stage_key == "":
		stage_key = _school_stage_key_for_person(
			person
		)

	if stage_key == "":
		return out

	if (
		era_name in [
			"Industrial Era",
			"Modern Era",
			"Future Era"
		]
		and stage_key in [
			"young_adult",
			"adult_learning"
		]
	):
		for major_name in _college_majors_for_era(
			era_name
		):
			out.append({
				"type": "college_major",
				"name": "College: %s" % major_name
			})

		return out

	if (
		era_name in [
			"Industrial Era",
			"Modern Era",
			"Future Era"
		]
		and stage_key == "graduate"
	):
		var graduate_options: Array = (
			_graduate_school_options_for_person(
				person
			)
		)

		if not graduate_options.is_empty():
			return graduate_options

		for major_name in _college_majors_for_era(
			era_name
		):
			out.append({
				"type": "college_major",
				"name": "College: %s" % major_name
			})

		return out

	var school_types: Array = (
		_era_school_type_contract_names_for_stage(
			era_name,
			stage_key,
			person
		)
	)

	for school_name in school_types:
		var clean_name: String = str(
			school_name
		).strip_edges()

		if clean_name != "":
			out.append({
				"type": "era_school",
				"name": clean_name
			})

	return out
func _school_stage_key_for_person(
	person: Person
) -> String:
	if person == null:
		return ""

	if (
		gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		return ""

	var era_name: String = str(
		gs.era.name
	)
	var ages: Dictionary = _safe_dictionary(
		ERA_SCHOOLS [
			era_name
		].get(
			"ages",
			{}
		)
	)
	var adult_start: int = int(
		ages.get(
			"adult_start",
			18
		)
	)
	var age: int = int(
		person.age
	)

	if era_name == "Modern Era":
		var preschool_start: int = int(
			ages.get(
				"preschool_start",
				4
			)
		)
		var elementary_start: int = int(
			ages.get(
				"elementary_start",
				ages.get(
					"child_start",
					5
				)
			)
		)
		var middle_start: int = int(
			ages.get(
				"middle_start",
				11
			)
		)
		var high_start: int = int(
			ages.get(
				"high_start",
				14
			)
		)

		if age < preschool_start:
			return ""
		if age < elementary_start:
			return "preschool"
		if age < middle_start:
			return "elementary"
		if age < high_start:
			return "middle"
		if age < adult_start:
			return "high"
		if age < 24:
			return "young_adult"
		if _has_completed_college_major(
			person
		):
			return "graduate"

		return "adult_learning"

	if era_name == "Future Era":
		var future_preschool_start: int = int(
			ages.get(
				"preschool_start",
				4
			)
		)
		var future_child_start: int = int(
			ages.get(
				"child_start",
				5
			)
		)
		var future_middle_start: int = int(
			ages.get(
				"middle_start",
				11
			)
		)
		var future_high_start: int = int(
			ages.get(
				"high_start",
				14
			)
		)

		if age < future_preschool_start:
			return ""
		if age < future_child_start:
			return "preschool"
		if age < future_middle_start:
			return "child"
		if age < future_high_start:
			return "middle"
		if age < adult_start:
			return "high"
		if age < 24:
			return "young_adult"
		if _has_completed_college_major(
			person
		):
			return "graduate"

		return "adult_learning"

	var child_start: int = maxi(
		0,
		int(
			ages.get(
				"child_start",
				6
			)
		)
	)

	if age < child_start:
		return ""

	if era_name == "Industrial Era":
		var industrial_teen_start: int = int(
			ages.get(
				"teen_start",
				12
			)
		)

		if age < industrial_teen_start:
			return "child"
		if age < adult_start:
			return "teen"
		if age < 24:
			return "young_adult"
		if _has_completed_college_major(
			person
		):
			return "graduate"

		return "adult_learning"

	if (
		ages.has(
			"middle_start"
		)
		and ages.has(
			"high_start"
		)
	):
		var historical_middle_start: int = int(
			ages.get(
				"middle_start",
				11
			)
		)
		var historical_high_start: int = int(
			ages.get(
				"high_start",
				14
			)
		)

		if age < historical_middle_start:
			return "child"
		if age < historical_high_start:
			return "middle"
		if age < adult_start:
			return "high"

		return "adult_learning"

	var historical_teen_start: int = int(
		ages.get(
			"teen_start",
			12
		)
	)

	if age < historical_teen_start:
		return "child"
	if age < adult_start:
		return "teen"

	return "adult_learning"
func _school_stage_display_name(
	stage_key: String
) -> String:
	match str(
		stage_key
	).strip_edges().to_lower():
		"preschool":
			return "Preschool"

		"elementary":
			return "Elementary School"

		"child":
			return "Primary School"

		"middle":
			return "Middle School"

		"teen":
			return "Secondary School"

		"high":
			return "High School"

		"young_adult":
			return "Higher Learning"

		"graduate":
			return "Graduate School"

		"adult_learning":
			return "Adult Learning"

	return "School"


func _minor_school_stage_keys_for_era(
	era_name: String
) -> Array:
	match str(
		era_name
	):
		"Modern Era":
			return [
				"preschool",
				"elementary",
				"middle",
				"high"
			]

		"Future Era":
			return [
				"preschool",
				"child",
				"middle",
				"high"
			]

		_:
			return [
				"child",
				"teen"
			]

func _school_stage_start_age(
	era_name: String,
	stage_key: String
) -> int:
	if not ERA_SCHOOLS.has(
		era_name
	):
		return -1

	var ages: Dictionary = _safe_dictionary(
		ERA_SCHOOLS [
			era_name
		].get(
			"ages",
			{}
		)
	)
	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	match clean_stage:
		"preschool":
			return int(
				ages.get(
					"preschool_start",
					-1
				)
			)

		"elementary":
			return int(
				ages.get(
					"elementary_start",
					ages.get(
						"child_start",
						-1
					)
				)
			)

		"child":
			return int(
				ages.get(
					"child_start",
					-1
				)
			)

		"middle":
			return int(
				ages.get(
					"middle_start",
					-1
				)
			)

		"teen":
			return int(
				ages.get(
					"teen_start",
					-1
				)
			)

		"high":
			return int(
				ages.get(
					"high_start",
					-1
				)
			)

	return -1


func _is_minor_school_actor(
	person: Person
) -> bool:
	if person == null:
		return false

	var adult_start: int = 18

	if (
		gs != null
		and gs.era != null
		and ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		var ages: Dictionary = _safe_dictionary(
			ERA_SCHOOLS [
				gs.era.name
			].get(
				"ages",
				{}
			)
		)

		adult_start = int(
			ages.get(
				"adult_start",
				18
			)
		)

	return int(
		person.age
	) < adult_start


func _next_minor_school_transition_for(
	person: Person
) -> Dictionary:
	if (
		person == null
		or gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		return {}

	var era_name: String = str(
		gs.era.name
	)
	var age: int = int(
		person.age
	)

	for raw_stage_key in _minor_school_stage_keys_for_era(
		era_name
	):
		var stage_key: String = str(
			raw_stage_key
		)
		var start_age: int = (
			_school_stage_start_age(
				era_name,
				stage_key
			)
		)

		if (
			start_age < 0
			or age >= start_age
		):
			continue

		return {
			"stage_key": stage_key,
			"stage_display": (
				_school_stage_display_name(
					stage_key
				)
			),
			"start_age": start_age,
			"current_age": age,
			"years_until": (
				start_age - age
			),
			"planning_due": (
				age == start_age - 1
			)
		}

	return {}
func _build_school_option_contract(
	person: Person,
	school_name: String,
	mode: String,
	stage_override: String = ""
) -> Dictionary:
	var stage_key: String = str(
		stage_override
	).strip_edges().to_lower()

	if stage_key == "":
		stage_key = _school_stage_key_for_person(
			person
		)

	var profile: Dictionary = _school_profile_for(
		school_name,
		mode,
		person
	)
	var minor_requires_custodial_decision: bool = (
		_is_minor_school_actor(
			person
		)
		and mode in [
			"era_school",
			"bending_school",
			"dual_enrollment"
		]
	)

	return {
		"schema": SCHOOL_CONTRACT_SCHEMA + ".option",
		"version": SCHOOL_CONTRACT_VERSION,
		"type": mode,
		"name": school_name,
		"era": gs.era.name,
		"school_stage": stage_key,
		"school_stage_display": (
			_school_stage_display_name(
				stage_key
			)
		),
		"institution_type": str(
			profile.get(
				"institution_type",
				mode
			)
		),
		"program": str(
			profile.get(
				"program",
				_school_stage_display_name(
					stage_key
				)
			)
		),
		"lane": str(
			profile.get(
				"lane",
				"school"
			)
		),
		"tuition": float(
			profile.get(
				"tuition",
				0.0
			)
		),
		"major": str(
			profile.get(
				"major",
				""
			)
		),
		"graduate_school": str(
			profile.get(
				"graduate_school",
				""
			)
		),
		"required_major": str(
			profile.get(
				"required_major",
				""
			)
		),
		"scholarship_eligible": bool(
			profile.get(
				"scholarship_eligible",
				false
			)
		),
		"scholarship_reason": str(
			profile.get(
				"scholarship_reason",
				""
			)
		),
		"meal_surface_label": str(
			profile.get(
				"meal_surface_label",
				""
			)
		),
		"class_surface_label": str(
			profile.get(
				"class_surface_label",
				"Classes"
			)
		),
		"social_surface_label": str(
			profile.get(
				"social_surface_label",
				"School Social Pressure"
			)
		),
		"minor_requires_custodial_decision": (
			minor_requires_custodial_decision
		),
		"child_direct_enrollment_forbidden": (
			minor_requires_custodial_decision
		),
		"child_may_express_preference": (
			minor_requires_custodial_decision
		),
		"child_preference_is_advisory_only": (
			minor_requires_custodial_decision
		),
		"custodial_authority_owns_minor_enrollment": (
			minor_requires_custodial_decision
		),
		"contract_mesh": {
			"postsecondary_requirements_are_contract_data": (
				mode in [
					"college_major",
					"graduate_school"
				]
			),
			"child_direct_enrollment_forbidden": (
				minor_requires_custodial_decision
			),
			"custodial_authority_owns_minor_enrollment": (
				minor_requires_custodial_decision
			)
		}
	}


func get_school_options_for_stage(
	person: Person,
	stage_key: String
) -> Array:
	var options: Array = []

	if (
		person == null
		or not _education_rights_allow_person(
			person
		)
	):
		return options

	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	if clean_stage == "":
		return options

	for raw_option in _era_school_options_for_person(
		person,
		clean_stage
	):
		var option: Dictionary = _safe_dictionary(
			raw_option
		)
		var school_name: String = str(
			option.get(
				"name",
				""
			)
		).strip_edges()
		var school_type: String = str(
			option.get(
				"type",
				"era_school"
			)
		).strip_edges()

		if (
			school_name == ""
			or school_type == ""
		):
			continue

		options.append({
			"type": school_type,
			"name": school_name,
			"contract": (
				_build_school_option_contract(
					person,
					school_name,
					school_type,
					clean_stage
				)
			)
		})

	return options

func _school_contract_needs_population_rescale(contract: Dictionary) -> bool:
	if contract.is_empty():
		return true

	var zones: Dictionary = _safe_dictionary(contract.get("zones", {}))
	var population: Dictionary = _safe_dictionary(contract.get("population", {}))
	var students_total: int = int(population.get("students_total", 0))

	if students_total > 0 and students_total < SCHOOL_COHORT_MIN:
		return true

	var classes: Array = _safe_array(zones.get("classes", []))
	if classes.is_empty():
		return true

	for raw_class in classes:
		var class_zone: Dictionary = _safe_dictionary(raw_class)
		var class_students: Array = _safe_array(class_zone.get("students", []))
		var total_students: int = int(class_zone.get("total_students", class_students.size()))
		if total_students > 0 and total_students < min(18, SCHOOL_CLASS_SIZE_TARGET):
			return true
		if not class_zone.has("student_preview_limit"):
			return true
		if not class_zone.has("school_roster_total"):
			return true

	return false
func _build_school_contract(person: Person, school_name: String, mode: String) -> Dictionary:
	if person == null:
		return {}

	var clean_school: String = str(school_name).strip_edges()
	var clean_mode: String = str(mode).strip_edges()
	if clean_school == "" or clean_mode == "":
		return {}

	_ensure_schoolmates(person, clean_school, clean_mode)

	var contract_id: String = _school_contract_id(clean_school, clean_mode)
	var profile: Dictionary = _school_profile_for(clean_school, clean_mode, person)

	if school_contracts.has(contract_id):
		var existing_contract: Dictionary = _safe_dictionary(school_contracts.get(contract_id, {}))
		if not existing_contract.is_empty():
			existing_contract ["era"] = gs.era.name
			existing_contract ["school_name"] = clean_school
			existing_contract ["school_mode"] = clean_mode
			existing_contract ["school_stage"] = _school_stage_key_for_person(person)
			existing_contract ["institution_type"] = str(profile.get("institution_type", clean_mode))
			existing_contract ["program"] = str(profile.get("program", _school_stage_key_for_person(person)))
			existing_contract ["lane"] = str(profile.get("lane", "school"))
			existing_contract ["profile"] = profile
			existing_contract ["meal_surface_label"] = str(profile.get("meal_surface_label", ""))
			existing_contract ["class_surface_label"] = str(profile.get("class_surface_label", "Classes"))
			existing_contract ["social_surface_label"] = str(profile.get("social_surface_label", "School Social Pressure"))
			if _school_contract_needs_population_rescale(existing_contract):
				existing_contract ["zones"] = _school_zone_contracts_for(person, clean_school, clean_mode, profile)
			else:
				existing_contract = _refresh_school_live_contract(person, existing_contract, profile)
			existing_contract ["population"] = _school_contract_population(_safe_dictionary(existing_contract.get("zones", {})))
			existing_contract ["updated_year"] = int(gs.year)
			existing_contract ["updated_at_ms"] = int(Time.get_ticks_msec())
			school_contracts [contract_id] = existing_contract
			return existing_contract.duplicate(true)

	var zones: Dictionary = _school_zone_contracts_for(person, clean_school, clean_mode, profile)

	var contract: Dictionary = {
		"schema": SCHOOL_CONTRACT_SCHEMA,
		"version": SCHOOL_CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "school_institution",
		"state": "active",
		"era": gs.era.name,
		"school_name": clean_school,
		"school_mode": clean_mode,
		"school_stage": _school_stage_key_for_person(person),
		"institution_type": str(profile.get("institution_type", clean_mode)),
		"program": str(profile.get("program", _school_stage_key_for_person(person))),
		"lane": str(profile.get("lane", "school")),
		"tuition": float(profile.get("tuition", 0.0)),
		"major": str(profile.get("major", "")),
		"graduate_school": str(profile.get("graduate_school", "")),
		"required_major": str(profile.get("required_major", "")),
		"scholarship_eligible": bool(profile.get("scholarship_eligible", false)),
		"scholarship_reason": str(profile.get("scholarship_reason", "")),
		"meal_surface_label": str(profile.get("meal_surface_label", "")),
		"class_surface_label": str(profile.get("class_surface_label", "Classes")),
		"social_surface_label": str(profile.get("social_surface_label", "School Social Pressure")),
		"profile": profile,
		"zones": zones,
		"population": _school_contract_population(zones),
		"student_roster_key": _school_key(clean_school, clean_mode),
		"teacher_roster_key": _school_key(clean_school, clean_mode),
		"created_year": int(gs.year),
		"updated_year": int(gs.year),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"systems": {
			"specialization": "school_engine",
			"consequence": "scenario_engine",
			"relationship": "relationship_activities_engine",
			"reputation": "dynasty_legacy_engine",
			"ui": "mainscene.school_hub"
		},
		"contract_mesh": {
			"tags": ["school", "education", "public_space", "social_friction", "era_aware", "observable_reality"],
			"can_interact_with": ["relationships", "fame", "family", "career", "bending", "scenario", "scholarships", "graduate_school"],
		}
	}

	school_contracts [contract_id] = contract
	return contract.duplicate(true)

func _ensure_school_contract_for_enrollment(person: Person) -> Dictionary:
	if person == null:
		return {}
	if not enrollment.has(person.id):
		return {}

	var rec: Dictionary = enrollment.get(person.id, {})
	if rec.is_empty():
		return {}
	if str(rec.get("status", "active")) != "active":
		return {}

	var mode: String = str(rec.get("mode", "")).strip_edges()

	if mode == "dual":
		var era_school: String = str(rec.get("era_school", "")).strip_edges()
		var bending_school: String = str(rec.get("bending_school", "")).strip_edges()
		var era_contract: Dictionary = _build_school_contract(person, era_school, "era_school") if era_school != "" else {}
		var bending_contract: Dictionary = _build_school_contract(person, bending_school, "bending_school") if bending_school != "" else {}

		if era_contract.is_empty() and bending_contract.is_empty():
			return {}

		var primary: Dictionary = era_contract if not era_contract.is_empty() else bending_contract
		primary ["contract_id"] = _school_contract_id(_school_record_name(rec), "dual")
		primary ["contract_type"] = "school_dual_institution"
		primary ["school_mode"] = "dual"
		primary ["school_name"] = _school_record_name(rec)
		primary ["secondary_contract"] = bending_contract
		primary ["dual_contracts"] = [era_contract, bending_contract]
		primary ["contract_mesh"] ["combines"] = ["era_school", "bending_school"]
		school_contracts [str(primary.get("contract_id", ""))] = primary
		return primary.duplicate(true)

	var school_name: String = str(rec.get("school_name", "")).strip_edges()
	if school_name == "":
		return {}

	return _build_school_contract(person, school_name, mode)

func _school_preview_options_for_transition(
	person: Person,
	transition: Dictionary
) -> Array:
	var out: Array = []

	if (
		person == null
		or transition.is_empty()
	):
		return out

	var stage_key: String = str(
		transition.get(
			"stage_key",
			""
		)
	).strip_edges().to_lower()
	var start_age: int = int(
		transition.get(
			"start_age",
			-1
		)
	)
	var years_until: int = maxi(
		0,
		int(
			transition.get(
				"years_until",
				start_age - int(person.age)
			)
		)
	)

	if (
		stage_key == ""
		or start_age < 0
		or int(person.age) >= start_age
	):
		return out

	for raw_option in get_school_options_for_stage(
		person,
		stage_key
	):
		var option: Dictionary = _safe_dictionary(
			raw_option
		)

		if option.is_empty():
			continue

		var contract: Dictionary = _safe_dictionary(
			option.get(
				"contract",
				{}
			)
		)

		option ["available"] = false
		option ["enabled"] = false
		option ["preview_only"] = true
		option ["availability_state"] = "upcoming"
		option ["available_at_age"] = start_age
		option ["years_until_available"] = years_until

		contract ["preview_only"] = true
		contract ["availability_state"] = "upcoming"
		contract ["available_at_age"] = start_age
		contract ["years_until_available"] = years_until
		contract ["enrollment_available_now"] = false
		contract ["projection_read_only"] = true
		contract ["simulation_mutation_performed"] = false

		option ["contract"] = contract
		out.append(
			option
		)

	return out
func get_school_ecosystem_snapshot(
	person: Person
) -> Dictionary:
	var snapshot: Dictionary = {
		"success": false,
		"active": false,
		"active_contract": {},
		"available_contracts": [],
		"higher_learning_catalog": {},
		"clique_contract": {},
		"teachers": [],
		"classmates": [],
		"meal_zone": {},
		"classes": [],
		"social_memory": [],
		"school_stage": "",
		"school_stage_display": "",
		"school_option_stage": "",
		"school_planning_mode": false,
		"school_preview_mode": false,
		"school_preview_start_age": -1,
		"school_preview_years_until": -1,
		"next_school_transition": {},
		"minor_requires_custodial_decision": false,
		"projection_read_only": true,
		"simulation_mutation_performed": false
	}

	if person == null:
		return snapshot

	var current_stage: String = (
		_school_stage_key_for_person(
			person
		)
	)
	var next_transition: Dictionary = (
		_next_minor_school_transition_for(
			person
		)
	)

	snapshot [
		"school_stage"
	] = current_stage
	snapshot [
		"school_stage_display"
	] = (
		_school_stage_display_name(
			current_stage
		)
		if current_stage != ""
		else "Before School"
	)
	snapshot [
		"next_school_transition"
	] = next_transition.duplicate(true)
	snapshot [
		"minor_requires_custodial_decision"
	] = _is_minor_school_actor(
		person
	)

	var higher_learning: Dictionary = (
		_resident_higher_learning_catalog_for_actor(
			person
		)
	)

	snapshot [
		"higher_learning_catalog"
	] = higher_learning







	if not bool(
		higher_learning.get(
			"visible",
			false
		)
	):
		if (
			current_stage == ""
			and not next_transition.is_empty()
		):
			var preview_stage: String = str(
				next_transition.get(
					"stage_key",
					""
				)
			).strip_edges().to_lower()
			var preview_start_age: int = int(
				next_transition.get(
					"start_age",
					-1
				)
			)
			var preview_years_until: int = maxi(
				0,
				int(
					next_transition.get(
						"years_until",
						preview_start_age - int(person.age)
					)
				)
			)

			snapshot [
				"available_contracts"
			] = _school_preview_options_for_transition(
				person,
				next_transition
			)
			snapshot [
				"school_option_stage"
			] = preview_stage
			snapshot [
				"school_planning_mode"
			] = bool(
				next_transition.get(
					"planning_due",
					false
				)
			)
			snapshot [
				"school_preview_mode"
			] = true
			snapshot [
				"school_preview_start_age"
			] = preview_start_age
			snapshot [
				"school_preview_years_until"
			] = preview_years_until
		else:
			snapshot [
				"available_contracts"
			] = get_school_options_for(
				person
			)
			snapshot [
				"school_option_stage"
			] = current_stage

	if not enrollment.has(
		person.id
	):
		snapshot ["success"] = true
		snapshot ["active"] = false
		return snapshot

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		rec.is_empty()
		or str(
			rec.get(
				"status",
				"active"
			)
		) != "active"
	):
		snapshot ["success"] = true
		snapshot ["active"] = false
		return snapshot

	var contract: Dictionary = (
		_resident_school_contract_for_enrollment(
			person
		)
	)

	if contract.is_empty():


		contract = _enrollment_observation_shell(
			person,
			rec
		)

	var zones_raw: Variant = contract.get(
		"zones",
		{}
	)
	var zones: Dictionary = (
		zones_raw as Dictionary
		if typeof(zones_raw) == TYPE_DICTIONARY
		else {}
	)
	var meal_raw: Variant = zones.get(
		"meal",
		{}
	)
	var classes_raw: Variant = zones.get(
		"classes",
		[]
	)
	var social_memory_raw: Variant = (
		school_social_memory.get(
			str(
				int(
					person.id
				)
			),
			[]
		)
	)

	snapshot ["success"] = true
	snapshot ["active"] = true
	snapshot ["active_contract"] = contract
	snapshot ["teachers"] = get_teachers_for(
		person
	)
	snapshot ["classmates"] = get_classmates(
		person
	)
	snapshot ["meal_zone"] = (
		(meal_raw as Dictionary).duplicate(
			false
		)
		if typeof(meal_raw) == TYPE_DICTIONARY
		else {}
	)
	snapshot ["classes"] = (
		(classes_raw as Array).duplicate(
			false
		)
		if typeof(classes_raw) == TYPE_ARRAY
		else []
	)
	snapshot ["social_memory"] = (
		(social_memory_raw as Array).duplicate(
			false
		)
		if typeof(social_memory_raw) == TYPE_ARRAY
		else []
	)
	snapshot ["clique_contract"] = (
		emit_school_clique_contract(
			person
		)
	)

	school_contract_observations [
		str(
			int(
				person.id
			)
		)
	] = {
		"observed_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_id": str(
			contract.get(
				"contract_id",
				""
			)
		),
		"school_name": str(
			contract.get(
				"school_name",
				""
			)
		),
		"era": (
			str(
				gs.era.name
			)
			if gs.era != null
			else ""
		),
	}

	return snapshot
func _resident_school_contract_for_enrollment(
	person: Person
) -> Dictionary:
	if (
		person == null
		or not enrollment.has(
			person.id
		)
	):
		return {}

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		rec.is_empty()
		or str(
			rec.get(
				"status",
				"active"
			)
		) != "active"
	):
		return {}

	var mode: String = str(
		rec.get(
			"mode",
			""
		)
	).strip_edges()
	var contract_id: String = ""

	if mode == "dual":
		contract_id = _school_contract_id(
			_school_record_name(
				rec
			),
			"dual"
		)
	else:
		var school_name: String = str(
			rec.get(
				"school_name",
				""
			)
		).strip_edges()

		if (
			school_name == ""
			or mode == ""
		):
			return {}

		contract_id = _school_contract_id(
			school_name,
			mode
		)

	var contract_raw: Variant = school_contracts.get(
		contract_id,
		{}
	)

	if typeof(
		contract_raw
	) != TYPE_DICTIONARY:
		return {}

	return (
		(contract_raw as Dictionary).duplicate(false)
	)


func _enrollment_observation_shell(
	person: Person,
	rec: Dictionary
) -> Dictionary:
	if (
		person == null
		or rec.is_empty()
	):
		return {}

	var mode: String = str(
		rec.get(
			"mode",
			""
		)
	).strip_edges()
	var school_name: String = (
		_school_record_name(
			rec
		)
	)
	var contract_id: String = (
		_school_contract_id(
			school_name,
			mode
		)
	)

	return {
		"schema": SCHOOL_CONTRACT_SCHEMA,
		"version": SCHOOL_CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "school_resident_observation_shell",
		"state": "resident_shell",
		"era": (
			str(gs.era.name)
			if (
				gs != null
				and gs.era != null
			)
			else ""
		),
		"school_name": school_name,
		"school_mode": mode,
		"school_stage": (
			_school_stage_key_for_person(
				person
			)
		),
		"institution_type": str(
			rec.get(
				"institution_type",
				mode
			)
		),
		"program": str(
			rec.get(
				"program",
				""
			)
		),
		"major": str(
			rec.get(
				"major",
				""
			)
		),
		"tuition": float(
			rec.get(
				"tuition",
				0.0
			)
		),
		"meal_surface_label": str(
			rec.get(
				"meal_surface_label",
				""
			)
		),
		"class_surface_label": "Classes",
		"social_surface_label": "School Social Pressure",
		"zones": {},
		"population": 0,
		"projection_complete": false,
		"ui_is_renderer_only": true
	}
func _arm_current_era_higher_learning_catalog_warm_service() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()

	if not (main_loop is SceneTree):
		set_meta(
			"higher_learning_catalog_warm_service_active",
			false
		)
		return

	var tree: SceneTree = main_loop as SceneTree
	var callback:= Callable(
		self,
		"_drive_current_era_higher_learning_catalog_warm_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		set_meta(
			"higher_learning_catalog_warm_service_active",
			true
		)
		return

	tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT
	)

	set_meta(
		"higher_learning_catalog_warm_service_active",
		true
	)
	set_meta(
		"higher_learning_catalog_warm_service_requires_input_idle",
		false
	)
	set_meta(
		"higher_learning_catalog_warm_service_uses_call_deferred",
		false
	)
	set_meta(
		"higher_learning_catalog_warm_service_uses_timer",
		false
	)
	set_meta(
		"higher_learning_catalog_warm_service_blocks_ui",
		false
	)
	set_meta(
		"higher_learning_catalog_warm_service_ready_gate_member",
		false
	)


func _drive_current_era_higher_learning_catalog_warm_process_frame() -> void:
	set_meta(
		"higher_learning_catalog_warm_service_active",
		false
	)

	_warm_current_era_higher_learning_catalog()
func _warm_current_era_higher_learning_catalog() -> void:
	set_meta(
		"higher_learning_catalog_warm_retry_armed",
		false
	)

	if (
		gs == null
		or gs.era == null
		or gs.career_contract_engine == null
		or not gs.career_contract_engine.has_method(
			"emit_education_path_projection"
		)
	):



		set_meta(
			"higher_learning_catalog_warm_retry_armed",
			true
		)

		_arm_current_era_higher_learning_catalog_warm_service()
		return

	_ensure_higher_learning_catalog_for_era(
		str(
			gs.era.name
		)
	)
func _higher_learning_program_slug(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"&",
		"•",
		":",
		"'"
	]:
		clean = clean.replace(
			token,
			"_"
		)

	while clean.contains(
		"__"
	):
		clean = clean.replace(
			"__",
			"_"
		)

	return clean


func _higher_learning_institutions_for_era(
	era_name: String
) -> Array:
	if not ERA_SCHOOLS.has(
		era_name
	):
		return []

	var era_data_raw: Variant = ERA_SCHOOLS.get(
		era_name,
		{}
	)
	var era_data: Dictionary = (
		era_data_raw as Dictionary
		if typeof(era_data_raw) == TYPE_DICTIONARY
		else {}
	)
	var institutions_raw: Variant = era_data.get(
		"young_adult",
		[]
	)

	return (
		(institutions_raw as Array).duplicate(false)
		if typeof(institutions_raw) == TYPE_ARRAY
		else []
	)


func _higher_learning_topics_for_institution(
	era_name: String,
	institution_name: String
) -> Array:
	match era_name:
		"Ancient Era":
			match institution_name:
				"Philosophy Academy":
					return [
						"Philosophy & Statecraft",
						"Natural Philosophy & Healing",
						"Rhetoric & Letters"
					]

				"Military Academy":
					return [
						"Command & Strategy",
						"Martial Discipline"
					]

				"Priestly College":
					return [
						"Sacred Medicine",
						"Temple Administration",
						"Ritual & Letters"
					]

		"Medieval Era":
			match institution_name:
				"Cathedral School":
					return [
						"Theology & Letters",
						"Medicine & Natural Philosophy",
						"Canon & Administration"
					]

				"Guild College":
					return [
						"Guild Medicine",
						"Commercial Arithmetic",
						"Master Craft"
					]

				"Court Education":
					return [
						"Courtcraft & Diplomacy",
						"Chivalric Command",
						"Law & Administration"
					]

		"Industrial Era", "Modern Era", "Future Era":
			return _college_majors_for_era(
				era_name
			)

	return []


func _higher_learning_institution_tuition(
	era_name: String,
	institution_name: String
) -> float:
	match era_name:
		"Ancient Era":
			match institution_name:
				"Philosophy Academy":
					return 1200.0
				"Military Academy":
					return 1800.0
				"Priestly College":
					return 900.0

		"Medieval Era":
			match institution_name:
				"Cathedral School":
					return 1200.0
				"Guild College":
					return 900.0
				"Court Education":
					return 3500.0

		"Industrial Era":
			match institution_name:
				"Technical Institute":
					return 2400.0
				"Teacher College":
					return 1800.0
				"Trade Academy":
					return 1300.0

		"Modern Era":
			match institution_name:
				"University":
					return 12500.0
				"Community College":
					return 4800.0
				"Trade School":
					return 7200.0

		"Future Era":
			match institution_name:
				"Cyber Institute":
					return 16500.0
				"Orbital Academy":
					return 22000.0
				"Terraforming College":
					return 18500.0

	return -1.0


func _higher_learning_funding_methods_for_era(
	era_name: String
) -> Array:
	match era_name:
		"Ancient Era":
			return [
				{
					"id": "scholarship",
					"label": "Seek Patronage"
				},
				{
					"id": "parents",
					"label": "Ask My Household to Sponsor Me"
				},
				{
					"id": "self",
					"label": "Pay the Academy Dues Myself"
				},
				{
					"id": "loan",
					"label": "Take a Creditor's Note"
				}
			]

		"Medieval Era":
			return [
				{
					"id": "scholarship",
					"label": "Petition for a Bursary"
				},
				{
					"id": "parents",
					"label": "Ask My Family to Sponsor Me"
				},
				{
					"id": "self",
					"label": "Pay the School Dues Myself"
				},
				{
					"id": "loan",
					"label": "Take a Merchant Loan"
				}
			]

		"Future Era":
			return [
				{
					"id": "scholarship",
					"label": "Apply for a Merit Allocation"
				},
				{
					"id": "parents",
					"label": "Ask My Family to Fund It"
				},
				{
					"id": "self",
					"label": "Pay for It Myself"
				},
				{
					"id": "loan",
					"label": "Take Out Education Credit"
				}
			]

		_:
			return [
				{
					"id": "scholarship",
					"label": "Apply for a Scholarship"
				},
				{
					"id": "parents",
					"label": "Ask Parents to Pay"
				},
				{
					"id": "self",
					"label": "Pay for It Myself"
				},
				{
					"id": "loan",
					"label": "Take Out a Loan"
				}
			]


func _higher_learning_picker_prompt_for_era(
	era_name: String
) -> String:
	match era_name:
		"Ancient Era":
			return (
				"Choose a discipline. Your discipline shapes "
				+ "which adult institutions and careers become reachable."
			)

		"Medieval Era":
			return (
				"Choose a course of study. Your studies shape "
				+ "the guild, court, scholarly, and healing paths ahead."
			)

		"Industrial Era":
			return (
				"Pick a field to study. Institutes and colleges now "
				+ "connect education directly to professional work."
			)

		"Future Era":
			return (
				"Pick a specialization. Advanced study determines "
				+ "which future professions you can qualify for."
			)

		_:
			return (
				"Pick a major to study. Your major changes which "
				+ "career paths you can qualify for later."
			)


func _higher_learning_program_mode_for_era(
	era_name: String
) -> String:
	if era_name in [
		"Industrial Era",
		"Modern Era",
		"Future Era"
	]:
		return "college_major"

	return "era_school"


func _higher_learning_school_name_for_program(
	era_name: String,
	institution_name: String,
	program_name: String
) -> String:
	if era_name in [
		"Industrial Era",
		"Modern Era",
		"Future Era"
	]:
		return (
			"%s • %s"
			% [
				institution_name,
				program_name
			]
		)

	return institution_name


func _higher_learning_qualification_tokens(
	era_name: String,
	institution_name: String,
	program_name: String
) -> Array:
	if era_name in [
		"Industrial Era",
		"Modern Era",
		"Future Era"
	]:
		return [
			program_name
		]



	return [
		institution_name
	]


func _ensure_higher_learning_catalog_for_era(
	era_name: String
) -> void:
	var clean_era: String = str(
		era_name
	).strip_edges()

	if clean_era == "":
		return

	var existing_raw: Variant = (
		higher_learning_catalog_by_era.get(
			clean_era,
			{}
		)
	)
	var existing: Dictionary = (
		existing_raw as Dictionary
		if typeof(existing_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		not existing.is_empty()
		and bool(
			existing.get(
				"projection_complete",
				false
			)
		)
	):
		return

	_queue_higher_learning_catalog_prewarm(
		clean_era
	)
func _queue_higher_learning_catalog_prewarm(
	era_name: String
) -> void:
	var clean_era: String = str(
		era_name
	).strip_edges()

	if clean_era == "":
		return

	var existing_raw: Variant = (
		higher_learning_catalog_by_era.get(
			clean_era,
			{}
		)
	)
	var existing: Dictionary = (
		existing_raw as Dictionary
		if typeof(existing_raw) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		existing.get(
			"projection_complete",
			false
		)
	):
		return

	var active_job_raw: Variant = get_meta(
		"higher_learning_catalog_prewarm_job",
		{}
	)
	var active_job: Dictionary = (
		active_job_raw as Dictionary
		if typeof(active_job_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		not active_job.is_empty()
		and str(
			active_job.get(
				"era_name",
				""
			)
		) == clean_era
	):
		var active_generation: int = int(
			active_job.get(
				"generation",
				-1
			)
		)

		if active_generation > 0:
			_schedule_higher_learning_catalog_prewarm_quantum(
				active_generation
			)

		return

	var generation: int = int(
		get_meta(
			"higher_learning_catalog_prewarm_generation",
			0
		)
	) + 1

	set_meta(
		"higher_learning_catalog_prewarm_generation",
		generation
	)
	set_meta(
		"higher_learning_catalog_prewarm_job",
		{
			"generation": generation,
			"era_name": clean_era,
			"institution_names": (
				_higher_learning_institutions_for_era(
					clean_era
				)
			),
			"institution_cursor": 0,
			"program_cursor": 0,
			"current_programs": [],
			"institutions": [],
			"program_count": 0,
			"funding_methods": (
				_higher_learning_funding_methods_for_era(
					clean_era
				)
			),
			"started_at_ms": int(
				Time.get_ticks_msec()
			)
		}
	)

	_schedule_higher_learning_catalog_prewarm_quantum(
		generation
	)

func _schedule_higher_learning_catalog_prewarm_quantum(
	generation: int,
	delay_seconds: float = 0.025
) -> void:
	if generation != int(
		get_meta(
			"higher_learning_catalog_prewarm_generation",
			0
		)
	):
		return

	var scheduled_generation: int = int(
		get_meta(
			"higher_learning_catalog_prewarm_scheduled_generation",
			-1
		)
	)

	if scheduled_generation == generation:
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if not (main_loop is SceneTree):
		set_meta(
			"higher_learning_catalog_prewarm_scheduled_generation",
			-1
		)
		return

	var tree: SceneTree = main_loop as SceneTree
	var callback:= Callable(
		self,
		"_service_higher_learning_catalog_prewarm_quantum"
	).bind(
		generation
	)

	set_meta(
		"higher_learning_catalog_prewarm_scheduled_generation",
		generation
	)

	if not tree.process_frame.is_connected(
		callback
	):
		tree.process_frame.connect(
			callback,
			CONNECT_ONE_SHOT
		)

	set_meta(
		"higher_learning_catalog_prewarm_requested_delay_seconds",
		maxf(
			0.0,
			delay_seconds
		)
	)
	set_meta(
		"higher_learning_catalog_prewarm_one_quantum_per_process_frame",
		true
	)
	set_meta(
		"higher_learning_catalog_prewarm_requires_input_idle",
		false
	)
	set_meta(
		"higher_learning_catalog_prewarm_uses_call_deferred",
		false
	)
	set_meta(
		"higher_learning_catalog_prewarm_uses_timer",
		false
	)
	set_meta(
		"higher_learning_catalog_prewarm_blocks_ui",
		false
	)
	set_meta(
		"higher_learning_catalog_prewarm_ready_gate_member",
		false
	)
func _queue_controlled_actor_school_catalog_successor(
	era_name: String,
	publication_frontier: String
) -> void:
	if (
		gs == null
		or gs.player == null
		or gs.era == null
		or gs.reality_projection_contract_engine == null
		or not gs.reality_projection_contract_engine.has_method(
			"queue_resident_temporal_surface_refresh"
		)
	):
		return

	var clean_era: String = str(
		era_name
	).strip_edges()
	var clean_frontier: String = str(
		publication_frontier
	).strip_edges()
	var current_era: String = str(
		gs.era.name
	).strip_edges()
	var actor_id: int = int(
		gs.player.id
	)

	if (
		clean_era == ""
		or clean_frontier == ""
		or clean_era != current_era
		or actor_id <= 0
		or not gs.player.alive
	):
		return

	var publication_key: String = (
		"%d:%s:%s"
		% [
			actor_id,
			clean_era,
			clean_frontier
		]
	)

	if str(
		get_meta(
			"higher_learning_school_successor_last_publication_key",
			""
		)
	) == publication_key:
		return

	set_meta(
		"higher_learning_school_successor_last_publication_key",
		publication_key
	)

	var queue_report: Dictionary = (
		gs.reality_projection_contract_engine
		.queue_resident_temporal_surface_refresh(
			actor_id,
			[
				"school"
			],
			{
				"source": (
					"school_engine."
					+ "higher_learning_catalog_prewarm"
				),
				"reason": (
					"resident_higher_learning_catalog_advanced"
				),
				"era_name": clean_era,
				"catalog_publication_frontier": clean_frontier,
				"target_year": int(
					gs.year
				),
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"ui_interaction_grace_ignored": true,
				"build_on_click_forbidden": true,
				"render_boundary_required": false,
				"ready_gate_member": false,
				"projection_read_only": true
			}
		)
	)

	set_meta(
		"higher_learning_school_successor_last_queue_report",
		queue_report.duplicate(false)
	)
func _publish_higher_learning_catalog_prewarm_snapshot(
	job: Dictionary,
	complete: bool
) -> void:
	var era_name: String = str(
		job.get(
			"era_name",
			""
		)
	).strip_edges()

	if era_name == "":
		return

	var institutions: Array = _safe_array(
		job.get(
			"institutions",
			[]
		)
	).duplicate(false)
	var current_programs: Array = _safe_array(
		job.get(
			"current_programs",
			[]
		)
	)
	var institution_names: Array = _safe_array(
		job.get(
			"institution_names",
			[]
		)
	)
	var institution_cursor: int = int(
		job.get(
			"institution_cursor",
			0
		)
	)



	if (
		not complete
		and not current_programs.is_empty()
		and institution_cursor >= 0
		and institution_cursor < institution_names.size()
	):
		var institution_name: String = str(
			institution_names [
				institution_cursor
			]
		).strip_edges()
		var tuition: float = (
			_higher_learning_institution_tuition(
				era_name,
				institution_name
			)
		)

		if tuition < 0.0:
			tuition = 0.0

		institutions.append({
			"institution_id": (
				_higher_learning_program_slug(
					institution_name
				)
			),
			"name": institution_name,
			"program_prompt": (
				_higher_learning_picker_prompt_for_era(
					era_name
				)
			),
			"tuition": tuition,
			"programs": (
				current_programs.duplicate(false)
			),
			"projection_complete": false,
			"ui_is_renderer_only": true
		})

	var program_count: int = int(
		job.get(
			"program_count",
			0
		)
	)
	var projection_state: String = (
		"hot"
		if complete
		else "publishing"
	)
	var revision: String = (
		"%s:%d:%d:%s"
		% [
			_higher_learning_program_slug(
				era_name
			),
			institutions.size(),
			program_count,
			projection_state
		]
	)

	higher_learning_catalog_by_era [
		era_name
	] = {
		"schema": (
			"eralife.school_engine."
			+ "higher_learning_catalog_contract"
		),
		"version": SCHOOL_CONTRACT_VERSION,
		"era_name": era_name,
		"title": "HIGHER LEARNING",
		"subtitle": (
			_higher_learning_picker_prompt_for_era(
				era_name
			)
		),
		"institutions": institutions,
		"program_count": program_count,
		"revision": revision,
		"resident": complete,
		"projection_complete": complete,
		"projection_state": projection_state,
		"career_paths_preauthored": complete,
		"progressive_observability": true,
		"observation_required": false,
		"ui_is_renderer_only": true
	}





	var publication_frontier: String = (
		"%s:%d:%s"
		% [
			_higher_learning_program_slug(
				era_name
			),
			institution_cursor,
			projection_state
		]
	)

	_queue_controlled_actor_school_catalog_successor(
		era_name,
		publication_frontier
	)
func _service_higher_learning_catalog_prewarm_quantum(
	generation: int
) -> void:
	if generation != int(
		get_meta(
			"higher_learning_catalog_prewarm_generation",
			0
		)
	):
		return

	set_meta(
		"higher_learning_catalog_prewarm_scheduled_generation",
		-1
	)

	var job_raw: Variant = get_meta(
		"higher_learning_catalog_prewarm_job",
		{}
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		job.is_empty()
		or int(
			job.get(
				"generation",
				-1
			)
		) != generation
	):
		return

	if (
		gs == null
		or gs.career_contract_engine == null
		or not gs.career_contract_engine.has_method(
			"emit_education_path_projection"
		)
	):
		_schedule_higher_learning_catalog_prewarm_quantum(
			generation,
			0.15
		)
		return

	var era_name: String = str(
		job.get(
			"era_name",
			""
		)
	)
	var institution_names: Array = _safe_array(
		job.get(
			"institution_names",
			[]
		)
	)
	var institution_cursor: int = int(
		job.get(
			"institution_cursor",
			0
		)
	)

	if institution_cursor >= institution_names.size():
		_publish_higher_learning_catalog_prewarm_snapshot(
			job,
			true
		)

		set_meta(
			"higher_learning_catalog_prewarm_job",
			{}
		)
		set_meta(
			"higher_learning_catalog_prewarm_complete_generation",
			generation
		)
		set_meta(
			"higher_learning_catalog_prewarm_completed_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)
		return

	var institution_name: String = str(
		institution_names [
			institution_cursor
		]
	).strip_edges()

	if institution_name == "":
		job ["institution_cursor"] = (
			institution_cursor + 1
		)
		job ["program_cursor"] = 0
		job ["current_programs"] = []

		set_meta(
			"higher_learning_catalog_prewarm_job",
			job
		)

		_schedule_higher_learning_catalog_prewarm_quantum(
			generation
		)
		return

	var institution_tuition: float = (
		_higher_learning_institution_tuition(
			era_name,
			institution_name
		)
	)

	if institution_tuition < 0.0:
		institution_tuition = 0.0

	var program_names: Array = (
		_higher_learning_topics_for_institution(
			era_name,
			institution_name
		)
	)
	var program_cursor: int = int(
		job.get(
			"program_cursor",
			0
		)
	)
	var current_programs: Array = _safe_array(
		job.get(
			"current_programs",
			[]
		)
	)

	if program_cursor >= program_names.size():
		var institutions: Array = _safe_array(
			job.get(
				"institutions",
				[]
			)
		)
		institutions.append({
			"institution_id": (
				_higher_learning_program_slug(
					institution_name
				)
			),
			"name": institution_name,
			"program_prompt": (
				_higher_learning_picker_prompt_for_era(
					era_name
				)
			),
			"tuition": institution_tuition,
			"programs": (
				current_programs.duplicate(false)
			),
			"projection_complete": true,
			"ui_is_renderer_only": true
		})

		job ["institutions"] = institutions
		job ["institution_cursor"] = (
			institution_cursor + 1
		)
		job ["program_cursor"] = 0
		job ["current_programs"] = []

		_publish_higher_learning_catalog_prewarm_snapshot(
			job,
			false
		)

		set_meta(
			"higher_learning_catalog_prewarm_job",
			job
		)

		_schedule_higher_learning_catalog_prewarm_quantum(
			generation
		)
		return

	var program_name: String = str(
		program_names [
			program_cursor
		]
	).strip_edges()

	if program_name == "":
		job ["program_cursor"] = (
			program_cursor + 1
		)

		set_meta(
			"higher_learning_catalog_prewarm_job",
			job
		)

		_schedule_higher_learning_catalog_prewarm_quantum(
			generation
		)
		return

	var program_id: String = (
		"higher_learning:%s:%s:%s"
		% [
			_higher_learning_program_slug(
				era_name
			),
			_higher_learning_program_slug(
				institution_name
			),
			_higher_learning_program_slug(
				program_name
			)
		]
	)
	var qualification_tokens: Array = (
		_higher_learning_qualification_tokens(
			era_name,
			institution_name,
			program_name
		)
	)


	var career_projection: Dictionary = (
		gs.career_contract_engine
		.emit_education_path_projection(
			era_name,
			qualification_tokens
		)
	)
	var program_mode: String = (
		_higher_learning_program_mode_for_era(
			era_name
		)
	)
	var school_name: String = (
		_higher_learning_school_name_for_program(
			era_name,
			institution_name,
			program_name
		)
	)
	var funding_methods: Array = _safe_array(
		job.get(
			"funding_methods",
			[]
		)
	)
	var program_contract: Dictionary = {
		"schema": (
			"eralife.school_engine."
			+ "higher_learning_program_contract"
		),
		"version": SCHOOL_CONTRACT_VERSION,
		"program_id": program_id,
		"era_name": era_name,
		"institution_name": institution_name,
		"program_name": program_name,
		"school_name": school_name,
		"school_mode": program_mode,
		"major": (
			program_name
			if program_mode == "college_major"
			else ""
		),
		"qualification_tokens": (
			qualification_tokens
		),
		"career_projection": (
			career_projection
		),
		"tuition": institution_tuition,
		"cost_label": (
			"Program cost"
			if era_name in [
				"Modern Era",
				"Future Era"
			]
			else "Study cost"
		),
		"funding_methods": (
			funding_methods
		),
		"ui_is_renderer_only": true
	}

	current_programs.append(
		program_contract
	)
	higher_learning_program_index [
		program_id
	] = program_contract

	job ["current_programs"] = current_programs
	job ["program_cursor"] = program_cursor + 1
	job ["program_count"] = int(
		job.get(
			"program_count",
			0
		)
	) + 1



	_publish_higher_learning_catalog_prewarm_snapshot(
		job,
		false
	)

	set_meta(
		"higher_learning_catalog_prewarm_job",
		job
	)

	_schedule_higher_learning_catalog_prewarm_quantum(
		generation
	)

func _resident_higher_learning_catalog_for_actor(
	person: Person
) -> Dictionary:
	if (
		person == null
		or gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		return {}

	var era_name: String = str(
		gs.era.name
	)
	var era_data_raw: Variant = ERA_SCHOOLS.get(
		era_name,
		{}
	)
	var era_data: Dictionary = (
		era_data_raw as Dictionary
		if typeof(era_data_raw) == TYPE_DICTIONARY
		else {}
	)
	var ages_raw: Variant = era_data.get(
		"ages",
		{}
	)
	var ages: Dictionary = (
		ages_raw as Dictionary
		if typeof(ages_raw) == TYPE_DICTIONARY
		else {}
	)
	var adult_start: int = int(
		ages.get(
			"adult_start",
			18
		)
	)
	var completed_college: bool = (
		_has_completed_college_major(
			person
		)
		if era_name in [
			"Industrial Era",
			"Modern Era",
			"Future Era"
		]
		else false
	)
	var visible: bool = (
		int(person.age) >= adult_start
		and can_attend_school(
			person
		)
		and not completed_college
	)
	var catalog_raw: Variant = (
		higher_learning_catalog_by_era.get(
			era_name,
			{}
		)
	)
	var catalog: Dictionary = (
		(catalog_raw as Dictionary).duplicate(false)
		if typeof(catalog_raw) == TYPE_DICTIONARY
		else {}
	)

	if catalog.is_empty():
		return {
			"schema": (
				"eralife.school_engine."
				+ "higher_learning_catalog_contract"
			),
			"version": SCHOOL_CONTRACT_VERSION,
			"era_name": era_name,
			"title": "HIGHER LEARNING",
			"subtitle": (
				_higher_learning_picker_prompt_for_era(
					era_name
				)
			),
			"institutions": [],
			"program_count": 0,
			"visible": visible,
			"can_choose_program": false,
			"resident": false,
			"projection_complete": false,
			"revision": (
				"cold:%s"
				% _higher_learning_program_slug(
					era_name
				)
			),
			"ui_is_renderer_only": true
		}

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)
	var active: bool = (
		not rec.is_empty()
		and str(
			rec.get(
				"status",
				""
			)
		) == "active"
	)
	var current_program_id: String = str(
		rec.get(
			"higher_learning_program_id",
			""
		)
	).strip_edges()

	catalog ["visible"] = visible
	catalog ["can_choose_program"] = (
		visible
		and not active
	)
	catalog [
		"current_program_id"
	] = current_program_id
	catalog [
		"actor_id"
	] = int(
		person.id
	)
	catalog [
		"actor_currently_enrolled"
	] = active
	catalog [
		"projection_read_only"
	] = true

	return catalog

func _school_contract_population(zones: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"students_total": 0,
		"teachers_total": 0,
		"meal_visible": 0,
		"class_visible": 0,
		"represented_student_count": 0,
		"offscreen_student_count": 0
	}

	var meal_zone: Dictionary = _safe_dictionary(zones.get("meal", {}))
	out ["meal_visible"] = _safe_array(meal_zone.get("people", [])).size()

	var roster_total: int = 0
	var represented_total: int = 0
	var offscreen_total: int = 0
	var classes: Array = _safe_array(zones.get("classes", []))

	for raw_class in classes:
		var class_zone: Dictionary = _safe_dictionary(raw_class)
		var students: Array = _safe_array(class_zone.get("students", []))
		out ["class_visible"] += students.size()
		out ["teachers_total"] += _safe_array(class_zone.get("teachers", [])).size()
		roster_total = max(roster_total, int(class_zone.get("school_roster_total", 0)))
		represented_total = max(represented_total, int(class_zone.get("represented_student_count", 0)))
		offscreen_total = max(offscreen_total, int(class_zone.get("offscreen_student_count", 0)))

	out ["represented_student_count"] = represented_total
	out ["offscreen_student_count"] = offscreen_total
	out ["students_total"] = max(roster_total, out ["meal_visible"] + out ["class_visible"])

	return out

func _school_zone_contracts_for(_person: Person, school_name: String, mode: String, profile: Dictionary) -> Dictionary:
	var skey: String = _school_key(school_name, mode)
	var roster_ids: Array = _safe_array(school_rosters.get(skey, []))
	var teacher_ids: Array = _safe_array(school_teachers.get(skey, []))

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_school_seed("%s|%d|seeded_live_school_contract" % [skey, int(gs.year)])

	var class_rows: Array = []
	var class_names: Array = _safe_array(profile.get("classes", []))
	if class_names.is_empty():
		class_names = ["Core Lessons"]

	var shuffled_students: Array = roster_ids.duplicate()
	shuffled_students.shuffle()

	var class_size: int = int(profile.get("class_size", SCHOOL_CLASS_SIZE_TARGET))
	class_size = int(clamp(class_size, 18, 34))

	var class_preview_limit: int = int(profile.get("class_preview_limit", SCHOOL_CLASS_PREVIEW_LIMIT))
	class_preview_limit = int(clamp(class_preview_limit, 6, class_size))

	var visible_class_count: int = min(class_names.size(), max(1, ceili(float(roster_ids.size()) / float(class_size))))
	var assigned_student_ids: Dictionary = {}

	for i in range(visible_class_count):
		var class_student_rows: Array = []
		var class_teacher_rows: Array = []
		var start_index: int = i * class_size
		var stop_index: int = min(start_index + class_size, shuffled_students.size())

		for idx in range(start_index, stop_index):
			var student: Person = gs.get_or_reactivate_npc_by_id(int(shuffled_students [idx]))
			if student == null or not student.alive:
				continue
			class_student_rows.append(_school_runtime_person_row(student, "classroom", "in class"))
			assigned_student_ids [int(student.id)] = true

		if not teacher_ids.is_empty():
			var teacher: Person = gs.get_or_reactivate_npc_by_id(int(teacher_ids [i % teacher_ids.size()]))
			if teacher != null and teacher.alive:
				class_teacher_rows.append(_school_runtime_person_row(teacher, "classroom", "teaching"))

		class_rows.append({
			"zone_id": "class_%d" % (i + 1),
			"name": str(class_names [i]),
			"students": class_student_rows,
			"teachers": class_teacher_rows,
			"total_students": class_student_rows.size(),
			"target_class_size": class_size,
			"student_preview_limit": class_preview_limit,
			"school_roster_total": roster_ids.size(),
			"school_key": skey,
			"tension": rng.randf_range(0.05, 0.55)
		})

	var represented_student_count: int = assigned_student_ids.size()
	var offscreen_student_count: int = max(0, roster_ids.size() - represented_student_count)

	for row_index in range(class_rows.size()):
		var class_row: Dictionary = _safe_dictionary(class_rows [row_index])
		class_row ["represented_student_count"] = represented_student_count
		class_row ["offscreen_student_count"] = offscreen_student_count
		class_rows [row_index] = class_row

	var meal_people: Array = []
	var meal_count: int = 0
	if not roster_ids.is_empty():
		meal_count = int(rng.randi_range(3, min(12, max(3, roster_ids.size()))))

	var meal_ids: Array = roster_ids.duplicate()
	meal_ids.shuffle()

	for i in range(min(meal_count, meal_ids.size())):
		var meal_student: Person = gs.get_or_reactivate_npc_by_id(int(meal_ids [i]))
		if meal_student == null or not meal_student.alive:
			continue

		var row: Dictionary = _school_runtime_person_row(meal_student, "meal", str(profile.get("meal_activity", "eating nearby")))
		row ["entered_meal_at_ms"] = int(Time.get_ticks_msec())
		row ["linger_until_ms"] = int(Time.get_ticks_msec()) + int(rng.randi_range(8500, 22000))
		meal_people.append(row)

	meal_people = _school_apply_meal_social_activity(meal_people, profile, rng)

	var meal_tension: float = rng.randf_range(0.05, 0.75)
	var meal_friendliness: Dictionary = _school_meal_friendliness_surface(meal_people, meal_tension)

	return {
		"classes": class_rows,
		"meal": {
			"zone_id": "meal",
			"name": str(profile.get("meal_surface_label", "Meal Break")),
			"people": meal_people,
			"live_count": meal_people.size(),
			"live_count_label": _school_people_label(meal_people.size()),
			"activity": str(profile.get("meal_activity", "taking a break")),
			"has_modern_lunchroom": bool(profile.get("has_modern_lunchroom", false)),
			"tension": meal_tension,
			"friendliness": int(meal_friendliness.get("value", 50)),
			"friendliness_label": str(meal_friendliness.get("label", "Mixed")),
			"friendliness_description": str(meal_friendliness.get("description", "The space has a neutral social temperature.")),
			"next_tick_ms": int(Time.get_ticks_msec()) + int(rng.randi_range(950, 1800)),
			"social_refresh_at_ms": int(Time.get_ticks_msec()) + int(profile.get("meal_social_refresh_ms", 7000)),
			"social_refresh_ms": int(profile.get("meal_social_refresh_ms", 7000)),
		},
		"hallway": {
			"zone_id": "hallway",
			"name": str(profile.get("hallway_label", "Shared School Space")),
			"activity": str(profile.get("hallway_activity", "moving between lessons")),
			"tension": rng.randf_range(0.05, 0.8)
		}
	}


func _school_runtime_person_row(npc: Person, zone_id: String, activity: String) -> Dictionary:
	if npc == null:
		return {}

	var first_name: String = str(npc.first_name).strip_edges()
	var last_name: String = str(npc.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name == "":
		full_name = str(npc.name).strip_edges()

	return {
		"person_id": int(npc.id),
		"first_name": first_name,
		"last_name": last_name,
		"full_name": full_name,
		"age": int(npc.age),
		"zone_id": zone_id,
		"activity": activity,
		"popularity": _school_popularity_score_for(npc),
		"friendliness": _school_person_friendliness_score_for(npc),
		"school_name": str(npc.school_name),
		"school_mode": str(npc.school_mode)
	}
func _school_popularity_score_for(npc: Person) -> int:
	if npc == null:
		return 0

	var score: float = 0.0
	score += float(npc.fame) * 0.3
	score += float(npc.respect) * 0.26
	score += float(npc.looks) * 0.16
	score += float(npc.smarts) * 0.12
	score += float(npc.satisfaction) * 0.08
	score += float(npc.mental_health) * 0.08

	return clamp(int(round(score)), 0, 100)
func _school_person_friendliness_score_for(npc: Person) -> int:
	if npc == null:
		return 50

	var score: float = 50.0
	score += (float(npc.satisfaction) - 50.0) * 0.24
	score += (float(npc.mental_health) - 50.0) * 0.2
	score += (float(npc.respect) - 50.0) * 0.22
	score += (float(npc.health) - 50.0) * 0.08
	score += (float(npc.smarts) - 50.0) * 0.04

	return clamp(int(round(score)), 0, 100)
func _school_meal_friendliness_surface(people: Array, tension: float = 0.0) -> Dictionary:
	var score: int = _school_meal_friendliness_score(people, tension)

	return {
		"value": score,
		"label": _school_meal_friendliness_label(score),
		"description": _school_meal_friendliness_description(score, people)
	}


func _school_meal_friendliness_score(people: Array, tension: float = 0.0) -> int:
	var visible_count: int = 0
	var popularity_total: float = 0.0
	var talking_count: int = 0
	var solo_count: int = 0

	for raw_person in people:
		var row: Dictionary = _safe_dictionary(raw_person)
		if row.is_empty():
			continue

		visible_count += 1
		popularity_total += float(clamp(int(row.get("popularity", 0)), 0, 100))

		var activity_text: String = str(row.get("activity", "")).strip_edges().to_lower()
		var social_group: Array = _safe_array(row.get("social_group", []))

		if activity_text.find("talking") >= 0 or not social_group.is_empty():
			talking_count += 1

		if activity_text.find("alone") >= 0 or activity_text.find("keeping to themselves") >= 0 or activity_text.find("quietly") >= 0:
			solo_count += 1

	var score: float = 48.0

	if visible_count <= 0:
		score -= 10.0
	else:
		var average_popularity: float = popularity_total / float(visible_count)
		var talking_ratio: float = float(talking_count) / float(visible_count)
		var solo_ratio: float = float(solo_count) / float(visible_count)

		score += (average_popularity - 50.0) * 0.2
		score += talking_ratio * 18.0
		score -= solo_ratio * 8.0
		score += clamp(float(visible_count) / 12.0, 0.0, 1.0) * 8.0

	score -= clamp(tension, 0.0, 1.0) * 20.0

	return clamp(int(round(score)), 0, 100)


func _school_meal_friendliness_label(score: int) -> String:
	var clean_score: int = clamp(int(score), 0, 100)

	if clean_score >= 82:
		return "Inviting"
	if clean_score >= 66:
		return "Warm"
	if clean_score >= 46:
		return "Mixed"
	if clean_score >= 28:
		return "Guarded"

	return "Cold"


func _school_meal_friendliness_description(score: int, people: Array) -> String:
	var clean_score: int = clamp(int(score), 0, 100)
	var visible_count: int = _safe_array(people).size()

	if clean_score >= 82:
		return "The space feels open. People are relaxed, social, and easy to approach."
	if clean_score >= 66:
		return "The space feels warm. Conversations are already moving through the room."
	if clean_score >= 46:
		return "The space feels mixed. Some groups are friendly, while others keep to themselves."
	if clean_score >= 28:
		return "The space feels guarded. People are present, but the room is not naturally opening up."

	if visible_count <= 0:
		return "The space feels empty and socially cold."

	return "The space feels cold. People are keeping distance, watching the room, or staying locked into their own circles."

func _refresh_school_live_contract(person: Person, contract: Dictionary, profile: Dictionary) -> Dictionary:
	if person == null or contract.is_empty():
		return contract

	var zones: Dictionary = _safe_dictionary(contract.get("zones", {}))
	var meal_zone: Dictionary = _safe_dictionary(zones.get("meal", {}))
	if meal_zone.is_empty():
		return contract

	var now_ms: int = int(Time.get_ticks_msec())
	var next_tick_ms: int = int(meal_zone.get("next_tick_ms", 0))
	if next_tick_ms > now_ms:
		return contract

	var school_name: String = str(contract.get("school_name", "")).strip_edges()
	var school_mode: String = str(contract.get("school_mode", "")).strip_edges()
	if school_name == "" or school_mode == "":
		return contract

	var skey: String = _school_key(school_name, school_mode)
	var roster_ids: Array = _safe_array(school_rosters.get(skey, []))
	var people: Array = _safe_array(meal_zone.get("people", []))
	var meal_tick_bucket: int = floori(float(now_ms) / 777.0)

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_school_seed("%s|%d|meal_live|%d" % [skey, int(gs.year), meal_tick_bucket])

	var kept_people: Array = []
	var present_ids: Dictionary = {}

	for raw_person in people:
		var row: Dictionary = _safe_dictionary(raw_person)
		var row_id: int = int(row.get("person_id", -1))
		if row_id <= 0:
			continue

		var npc: Person = gs.get_or_reactivate_npc_by_id(row_id)
		if npc == null or not npc.alive:
			continue

		var linger_until_ms: int = int(row.get("linger_until_ms", now_ms + 6000))
		var should_leave: bool = now_ms >= linger_until_ms and rng.randf() <= 0.42
		if should_leave:
			continue

		row ["zone_id"] = "meal"
		row ["full_name"] = _school_runtime_person_row(npc, "meal", str(row.get("activity", "nearby"))).get("full_name", str(row.get("full_name", "Student")))
		row ["age"] = int(npc.age)
		row ["popularity"] = _school_popularity_score_for(npc)
		row ["friendliness"] = _school_person_friendliness_score_for(npc)
		if not row.has("linger_until_ms"):
			row ["linger_until_ms"] = now_ms + int(rng.randi_range(8500, 22000))
		kept_people.append(row)
		present_ids [row_id] = true

	var target_max: int = min(14, max(4, roster_ids.size()))
	var add_count: int = 0

	if kept_people.size() < target_max and rng.randf() <= 0.68:
		add_count = int(rng.randi_range(1, min(3, target_max - kept_people.size())))

	if add_count > 0:
		var candidate_ids: Array = roster_ids.duplicate()
		candidate_ids.shuffle()

		for raw_id in candidate_ids:
			if add_count <= 0:
				break

			var candidate_id: int = int(raw_id)
			if candidate_id <= 0 or present_ids.has(candidate_id):
				continue

			var candidate: Person = gs.get_or_reactivate_npc_by_id(candidate_id)
			if candidate == null or not candidate.alive:
				continue

			var new_row: Dictionary = _school_runtime_person_row(candidate, "meal", str(profile.get("meal_activity", "eating nearby")))
			new_row ["entered_meal_at_ms"] = now_ms
			new_row ["linger_until_ms"] = now_ms + int(rng.randi_range(8500, 24000))
			kept_people.append(new_row)
			present_ids [candidate_id] = true
			add_count -= 1

	var social_refresh_ms: int = max(7000, int(profile.get("meal_social_refresh_ms", 7000)))
	var social_refresh_at_ms: int = int(meal_zone.get("social_refresh_at_ms", 0))
	var has_existing_social_state: bool = false

	for raw_social_person in kept_people:
		var social_row: Dictionary = _safe_dictionary(raw_social_person)
		if social_row.has("social_group"):
			has_existing_social_state = true
			break

	var should_refresh_social: bool = social_refresh_at_ms <= 0 or now_ms >= social_refresh_at_ms
	if social_refresh_at_ms <= 0 and has_existing_social_state:
		should_refresh_social = false
		social_refresh_at_ms = now_ms + social_refresh_ms

	if should_refresh_social:
		kept_people = _school_apply_meal_social_activity(kept_people, profile, rng)
		social_refresh_at_ms = now_ms + social_refresh_ms

	var meal_friendliness: Dictionary = _school_meal_friendliness_surface(kept_people, float(meal_zone.get("tension", 0.0)))
	meal_zone ["friendliness"] = int(meal_friendliness.get("value", 50))
	meal_zone ["friendliness_label"] = str(meal_friendliness.get("label", "Mixed"))
	meal_zone ["friendliness_description"] = str(meal_friendliness.get("description", "The space has a neutral social temperature."))

	meal_zone = _school_update_meal_approach_context(person, contract, meal_zone, kept_people, profile, rng, now_ms)

	meal_zone ["people"] = kept_people
	meal_zone ["live_count"] = kept_people.size()
	meal_zone ["live_count_label"] = _school_people_label(kept_people.size())
	meal_zone ["activity"] = str(profile.get("meal_activity", "taking a break"))
	meal_zone ["next_tick_ms"] = now_ms + int(rng.randi_range(950, 2100))
	meal_zone ["social_refresh_at_ms"] = social_refresh_at_ms
	meal_zone ["social_refresh_ms"] = social_refresh_ms
	meal_zone ["last_updated_ms"] = now_ms

	zones ["meal"] = meal_zone
	contract ["zones"] = zones
	contract ["population"] = _school_contract_population(zones)
	contract ["updated_at_ms"] = now_ms
	contract ["updated_year"] = int(gs.year)

	return contract
func _school_update_meal_approach_context(actor: Person, contract: Dictionary, meal_zone: Dictionary, people: Array, profile: Dictionary, rng: RandomNumberGenerator, now_ms: int) -> Dictionary:
	if actor == null or gs == null:
		return meal_zone

	var context: Dictionary = _safe_dictionary(meal_zone.get("approach_context", {}))
	var actor_id: int = int(actor.id)
	var friendliness_value: int = clamp(int(meal_zone.get("friendliness", _school_meal_friendliness_score(people, float(meal_zone.get("tension", 0.0))))), 0, 100)

	if int(context.get("actor_id", -1)) != actor_id:
		context = {
			"actor_id": actor_id,
			"entered_at_ms": now_ms,
			"cooldown_until_ms": now_ms + 9000,
			"pending_scenario": {},
			"last_approacher_id": -1,
			"live_scenario_enabled": true,
			"last_friendliness": friendliness_value
		}

	context ["last_friendliness"] = friendliness_value

	if not bool(context.get("live_scenario_enabled", true)):
		meal_zone ["approach_context"] = context
		return meal_zone

	if not _safe_dictionary(context.get("pending_scenario", {})).is_empty():
		meal_zone ["approach_context"] = context
		return meal_zone

	var entered_at_ms: int = int(context.get("entered_at_ms", now_ms))
	var dwell_ms: int = now_ms - entered_at_ms
	if dwell_ms < 9000:
		meal_zone ["approach_context"] = context
		return meal_zone

	var cooldown_until_ms: int = int(context.get("cooldown_until_ms", 0))
	if now_ms < cooldown_until_ms:
		meal_zone ["approach_context"] = context
		return meal_zone

	var candidate_row: Dictionary = _school_pick_meal_approach_candidate(actor, people, rng, int(context.get("last_approacher_id", -1)))
	if candidate_row.is_empty():
		context ["cooldown_until_ms"] = now_ms + 7000
		meal_zone ["approach_context"] = context
		return meal_zone

	var chance: float = _school_meal_approach_chance_for(actor, people.size(), friendliness_value)
	if rng.randf() > chance:
		context ["cooldown_until_ms"] = now_ms + int(rng.randi_range(4500, 8500))
		meal_zone ["approach_context"] = context
		return meal_zone

	var scenario: Dictionary = _build_school_meal_approach_scenario(actor, candidate_row, contract, profile, now_ms)
	if scenario.is_empty():
		context ["cooldown_until_ms"] = now_ms + 9000
		meal_zone ["approach_context"] = context
		return meal_zone

	context ["pending_scenario"] = scenario
	context ["last_approacher_id"] = int(candidate_row.get("person_id", -1))
	context ["cooldown_until_ms"] = now_ms + 45000
	meal_zone ["approach_context"] = context

	return meal_zone

func _school_meal_approach_chance_for(actor: Person, visible_count: int, friendliness_value: int = 50) -> float:
	if actor == null:
		return 0.0

	var school_popularity: int = _school_popularity_score_for(actor)
	var fame_value: int = clamp(int(actor.fame), 0, 100)
	var clean_friendliness: int = clamp(int(friendliness_value), 0, 100)

	var base: float = 0.08
	var popularity_bonus: float = float(school_popularity) / 100.0 * 0.16
	var fame_bonus: float = float(fame_value) / 100.0 * 0.14
	var crowd_bonus: float = clamp(float(visible_count) / 18.0, 0.0, 1.0) * 0.06
	var friendliness_bonus: float = ((float(clean_friendliness) / 100.0) - 0.5) * 0.22

	return clamp(base + popularity_bonus + fame_bonus + crowd_bonus + friendliness_bonus, 0.02, 0.54)

func _school_pick_meal_approach_candidate(actor: Person, people: Array, rng: RandomNumberGenerator, last_approacher_id: int = -1) -> Dictionary:
	if actor == null:
		return {}

	var candidates: Array = []

	for raw_person in people:
		var row: Dictionary = _safe_dictionary(raw_person)
		if row.is_empty():
			continue

		var person_id: int = int(row.get("person_id", -1))
		if person_id <= 0:
			continue
		if person_id == int(actor.id):
			continue
		if person_id == last_approacher_id and people.size() > 2:
			continue

		var npc: Person = gs.get_or_reactivate_npc_by_id(person_id)
		if npc == null or not npc.alive:
			continue

		candidates.append(row)

	if candidates.is_empty():
		return {}

	candidates.shuffle()
	return _safe_dictionary(candidates [int(rng.randi_range(0, candidates.size() - 1))])


func consume_school_meal_approach_scenario(actor: Person) -> Dictionary:
	if actor == null or gs == null:
		return {}

	var contract: Dictionary = _ensure_school_contract_for_enrollment(actor)
	if contract.is_empty():
		return {}

	var contract_id: String = str(contract.get("contract_id", "")).strip_edges()
	if contract_id == "" or not school_contracts.has(contract_id):
		return {}

	var stored_contract: Dictionary = _safe_dictionary(school_contracts.get(contract_id, {}))
	var zones: Dictionary = _safe_dictionary(stored_contract.get("zones", {}))
	var meal_zone: Dictionary = _safe_dictionary(zones.get("meal", {}))
	var context: Dictionary = _safe_dictionary(meal_zone.get("approach_context", {}))
	var scenario: Dictionary = _safe_dictionary(context.get("pending_scenario", {}))

	if scenario.is_empty():
		return {}

	context ["pending_scenario"] = {}
	context ["last_surface_at_ms"] = int(Time.get_ticks_msec())
	context ["cooldown_until_ms"] = int(Time.get_ticks_msec()) + 45000
	meal_zone ["approach_context"] = context
	zones ["meal"] = meal_zone
	stored_contract ["zones"] = zones
	stored_contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	stored_contract ["updated_year"] = int(gs.year)
	school_contracts [contract_id] = stored_contract

	return scenario.duplicate(true)


func _build_school_meal_approach_scenario(actor: Person, approacher_row: Dictionary, contract: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	if actor == null:
		return {}

	var approacher_id: int = int(approacher_row.get("person_id", -1))
	if approacher_id <= 0:
		return {}

	var approacher: Person = gs.get_or_reactivate_npc_by_id(approacher_id)
	if approacher == null or not approacher.alive:
		return {}

	var era_name: String = gs.era.name if gs != null and gs.era != null else "Modern Era"
	var approacher_name: String = str(approacher_row.get("full_name", "")).strip_edges()
	if approacher_name == "":
		approacher_name = "%s %s" % [approacher.first_name, approacher.last_name]

	var actor_name: String = "%s %s" % [actor.first_name, actor.last_name]
	var meal_label: String = str(contract.get("meal_surface_label", profile.get("meal_surface_label", "Meal Break"))).strip_edges()
	if meal_label == "":
		meal_label = "Meal Break"

	var greeting_line: String = _school_meal_approach_intro_line(era_name, approacher_name)
	var response_line: String = _school_meal_player_greeting_line(era_name, actor_name)

	return {
		"id": "school_meal_approach_%d_%d_%d" % [int(actor.id), approacher_id, now_ms],
		"category": "school",
		"source": "school_engine",
		"resolver_owner": "school_engine",
		"resolver_method": "resolve_school_meal_approach_choice",
		"panel_title": str(meal_label).to_upper(),
		"subtitle": "A live school interaction is starting.",
		"footer_text": "Choose how you respond.",
		"accent": "#79A8FF",
		"emoji": "🏫",
		"auto_timeout_seconds": 13.0,
		"auto_timeout_label": "Ignore them",
		"school_meal_approach": {
			"stage": "opening",
			"approacher_id": approacher_id,
			"approacher_name": approacher_name,
			"actor_id": int(actor.id),
			"actor_name": actor_name,
			"era": era_name,
			"meal_label": meal_label
		},
		"prompt": "%s sees you all alone, and decides to approach you.\n\n%s" % [
			approacher_name,
			greeting_line
		],
		"choices": [
			{
				"id": "ignore",
				"label": "Ignore them",
				"journal_text": "I ignored %s when they approached me during %s." % [approacher_name, meal_label],
				"tone": "cold",
				"bias_payloads": {
					"school_pressure": {
						"popularity_delta": -2.0,
						"peer_tension": 3.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "respond_intro",
				"label": response_line,
				"journal_text": "I answered %s when they approached me during %s." % [approacher_name, meal_label],
				"tone": "warm",
				"bias_payloads": {
					"relationship_bias": {
						"social_visibility": 3.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	}


func resolve_school_meal_approach_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if actor == null or gs == null:
		return {}

	var payload: Dictionary = _safe_dictionary(scenario.get("school_meal_approach", {}))
	var approacher_id: int = int(payload.get("approacher_id", -1))
	var approacher: Person = gs.get_or_reactivate_npc_by_id(approacher_id)
	if approacher == null or not approacher.alive:
		return {
			"type": "scenario_commit_complete",
			"popup_title": "They Walked Away",
			"popup_text": "The student who approached you is no longer nearby.",
			"popup_footer": "Tap anywhere to continue.",
			"text": "The school conversation passed before it could begin."
		}

	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var _era_name: String = str(payload.get("era", gs.era.name if gs.era != null else "Modern Era"))
	var approacher_name: String = str(payload.get("approacher_name", "%s %s" % [approacher.first_name, approacher.last_name])).strip_edges()
	var _actor_name: String = str(payload.get("actor_name", "%s %s" % [actor.first_name, actor.last_name])).strip_edges()
	var meal_label: String = str(payload.get("meal_label", "Meal Break")).strip_edges()

	match choice_id:
		"ignore":
			actor.respect = clamp(int(actor.respect) - 2, 0, 100)
			actor.satisfaction = clamp(int(actor.satisfaction) - 1, 0, 100)

			return {
				"type": "scenario_commit_complete",
				"popup_title": "They Walk Away",
				"popup_text": "%s waits for the answer that never comes, mutters something under their breath, and walks away.\n\nYour school popularity takes a small hit." % approacher_name,
				"popup_footer": "Tap anywhere to continue.",
				"text": "I let %s stand there unanswered during %s until they walked away." % [approacher_name, meal_label]
			}

		"respond_intro":
			return _queue_school_meal_how_are_you_scenario(actor, approacher, payload)

		"respond_good":
			return _resolve_school_meal_good_response(actor, approacher, payload)

		"accept_friend":
			return _resolve_school_meal_friend_response(actor, approacher, payload, true)

		"reject_friend":
			return _resolve_school_meal_friend_response(actor, approacher, payload, false)

	return {
		"type": "scenario_commit_complete",
		"popup_title": "Conversation Ends",
		"popup_text": "%s nods and heads back into the flow of %s." % [approacher_name, meal_label],
		"popup_footer": "Tap anywhere to continue.",
		"text": "A school conversation ended quietly."
	}


func _queue_school_meal_how_are_you_scenario(actor: Person, approacher: Person, payload: Dictionary) -> Dictionary:
	if actor == null or approacher == null or gs == null or gs.scenario_engine == null:
		return {}

	var era_name: String = str(payload.get("era", gs.era.name if gs.era != null else "Modern Era"))
	var approacher_name: String = str(payload.get("approacher_name", "%s %s" % [approacher.first_name, approacher.last_name])).strip_edges()
	var actor_name: String = str(payload.get("actor_name", "%s %s" % [actor.first_name, actor.last_name])).strip_edges()
	var meal_label: String = str(payload.get("meal_label", "Meal Break")).strip_edges()
	var question: String = _school_meal_how_are_you_question(era_name)
	var answer: String = _school_meal_good_answer(era_name)

	var next_payload: Dictionary = payload.duplicate(true)
	next_payload ["stage"] = "how_are_you"

	var scenario: Dictionary = {
		"id": "school_meal_how_are_you_%d_%d_%d" % [int(actor.id), int(approacher.id), int(Time.get_ticks_msec())],
		"category": "school",
		"source": "school_engine",
		"resolver_owner": "school_engine",
		"resolver_method": "resolve_school_meal_approach_choice",
		"panel_title": str(meal_label).to_upper(),
		"subtitle": "The conversation keeps going.",
		"footer_text": "Choose your reply.",
		"accent": "#79A8FF",
		"emoji": "💬",
		"school_meal_approach": next_payload,
		"prompt": "You answer, \"%s\"\n\n%s smiles a little and asks, \"%s\"" % [
			_school_meal_player_intro_text(era_name, actor_name),
			approacher_name,
			question
		],
		"choices": [
			{
				"id": "respond_good",
				"label": answer,
				"journal_text": "I had a small conversation with %s during %s." % [approacher_name, meal_label],
				"tone": "warm",
				"bias_payloads": {
					"relationship_bias": {
						"social_visibility": 4.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	}

	return gs.scenario_engine.queue_external_scenario(scenario)

func _school_meal_time_phrase(meal_label: String) -> String:
	var clean_label: String = str(meal_label).strip_edges()
	if clean_label == "":
		clean_label = "meal space"
	return "during my time at the %s" % clean_label
func _resolve_school_meal_good_response(actor: Person, approacher: Person, payload: Dictionary) -> Dictionary:
	var _era_name: String = str(payload.get("era", gs.era.name if gs.era != null else "Modern Era"))
	var approacher_name: String = str(payload.get("approacher_name", "%s %s" % [approacher.first_name, approacher.last_name])).strip_edges()
	var meal_label: String = str(payload.get("meal_label", "Meal Break")).strip_edges()
	var friend_chance: float = _school_meal_friend_request_chance(actor, approacher)

	if randf() <= friend_chance and gs.scenario_engine != null:
		return _queue_school_meal_friend_request_scenario(actor, approacher, payload)

	actor.satisfaction = clamp(int(actor.satisfaction) + 1, 0, 100)
	approacher.satisfaction = clamp(int(approacher.satisfaction) + 1, 0, 100)

	return {
		"type": "scenario_commit_complete",
		"popup_title": "Small Conversation",
		"popup_text": "%s says they are doing alright, thanks you for asking, then heads back into %s." % [approacher_name, meal_label],
		"popup_footer": "Tap anywhere to continue.",
		"text": "I talked with %s %s." % [approacher_name, _school_meal_time_phrase(meal_label)]
	}


func _queue_school_meal_friend_request_scenario(actor: Person, approacher: Person, payload: Dictionary) -> Dictionary:
	if actor == null or approacher == null or gs == null or gs.scenario_engine == null:
		return {}

	var approacher_name: String = str(payload.get("approacher_name", "%s %s" % [approacher.first_name, approacher.last_name])).strip_edges()
	var meal_label: String = str(payload.get("meal_label", "Meal Break")).strip_edges()
	var next_payload: Dictionary = payload.duplicate(true)
	next_payload ["stage"] = "friend_request"

	var scenario: Dictionary = {
		"id": "school_meal_friend_request_%d_%d_%d" % [int(actor.id), int(approacher.id), int(Time.get_ticks_msec())],
		"category": "school",
		"source": "school_engine",
		"resolver_owner": "school_engine",
		"resolver_method": "resolve_school_meal_approach_choice",
		"panel_title": str(meal_label).to_upper(),
		"subtitle": "A possible friendship forms.",
		"footer_text": "Choose whether to connect.",
		"accent": "#79A8FF",
		"emoji": "🤝",
		"school_meal_approach": next_payload,
		"prompt": "%s starts to walk away, then turns back.\n\n\"Do you want to be friends?\"" % approacher_name,
		"choices": [
			{
				"id": "accept_friend",
				"label": "Accept",
				"journal_text": "I became friends with %s after talking during %s." % [approacher_name, meal_label],
				"tone": "warm",
				"bias_payloads": {
					"relationship_bias": {
						"friendship": 8.0,
						"social_visibility": 4.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "reject_friend",
				"label": "Reject",
				"journal_text": "I chose not to become friends with %s after talking during %s." % [approacher_name, meal_label],
				"tone": "careful",
				"bias_payloads": {
					"relationship_bias": {
						"social_visibility": -1.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	}

	return gs.scenario_engine.queue_external_scenario(scenario)


func _resolve_school_meal_friend_response(actor: Person, approacher: Person, payload: Dictionary, accepted: bool) -> Dictionary:
	var approacher_name: String = str(payload.get("approacher_name", "%s %s" % [approacher.first_name, approacher.last_name])).strip_edges()
	var meal_label: String = str(payload.get("meal_label", "Meal Break")).strip_edges()

	if accepted:
		if int(approacher.id) not in actor.friends:
			actor.friends.append(int(approacher.id))
		if int(actor.id) not in approacher.friends:
			approacher.friends.append(int(actor.id))

		actor.satisfaction = clamp(int(actor.satisfaction) + 3, 0, 100)
		approacher.satisfaction = clamp(int(approacher.satisfaction) + 3, 0, 100)

		return {
			"type": "scenario_commit_complete",
			"popup_title": "New Friend",
			"popup_text": "You and %s become friends before they head back into %s." % [approacher_name, meal_label],
			"popup_footer": "Tap anywhere to continue.",
			"text": "I became friends with %s during %s." % [approacher_name, meal_label]
		}

	actor.respect = clamp(int(actor.respect) - 1, 0, 100)

	return {
		"type": "scenario_commit_complete",
		"popup_title": "Friendship Declined",
		"popup_text": "You decline. %s nods, accepts it, and walks away." % approacher_name,
		"popup_footer": "Tap anywhere to continue.",
		"text": "I chose not to become friends with %s during %s." % [approacher_name, meal_label]
	}


func _school_meal_friend_request_chance(actor: Person, approacher: Person) -> float:
	if actor == null or approacher == null:
		return 0.0

	var actor_popularity: int = _school_popularity_score_for(actor)
	var approacher_popularity: int = _school_popularity_score_for(approacher)
	var chance: float = 0.22
	chance += float(actor_popularity) / 100.0 * 0.24
	chance += float(approacher_popularity) / 100.0 * 0.08
	chance += float(clamp(int(actor.fame), 0, 100)) / 100.0 * 0.16

	return clamp(chance, 0.18, 0.72)


func _school_meal_approach_intro_line(era_name: String, approacher_name: String) -> String:
	match str(era_name).strip_edges():
		"Ancient Era":
			return "\"Peace to you. I am %s.\"" % approacher_name
		"Medieval Era":
			return "\"Well met. I am %s.\"" % approacher_name
		"Industrial Era":
			return "\"Hey. I'm %s.\"" % approacher_name
		"Future Era":
			return "\"Hello. I'm %s. Mind if I sync with your table for a moment?\"" % approacher_name
		_:
			return "\"Hey, I'm %s.\"" % approacher_name


func _school_meal_player_greeting_line(era_name: String, actor_name: String) -> String:
	match str(era_name).strip_edges():
		"Ancient Era":
			return "Peace to you. I am %s." % actor_name
		"Medieval Era":
			return "Well met. I am %s." % actor_name
		"Industrial Era":
			return "Hey, I'm %s." % actor_name
		"Future Era":
			return "Hello. I'm %s." % actor_name
		_:
			return "Hey, I'm %s." % actor_name


func _school_meal_player_intro_text(era_name: String, actor_name: String) -> String:
	match str(era_name).strip_edges():
		"Ancient Era":
			return "Peace to you. I am %s." % actor_name
		"Medieval Era":
			return "Well met. I am %s." % actor_name
		"Industrial Era":
			return "Hey, I'm %s." % actor_name
		"Future Era":
			return "Hello. I'm %s." % actor_name
		_:
			return "Hey, I'm %s." % actor_name


func _school_meal_how_are_you_question(era_name: String) -> String:
	match str(era_name).strip_edges():
		"Ancient Era":
			return "How fares your spirit today?"
		"Medieval Era":
			return "How art thou?"
		"Industrial Era":
			return "How are you holding up?"
		"Future Era":
			return "How is your state today?"
		_:
			return "How are you?"


func _school_meal_good_answer(era_name: String) -> String:
	match str(era_name).strip_edges():
		"Ancient Era":
			return "I fare well. And your spirit?"
		"Medieval Era":
			return "Good, how art thou?"
		"Industrial Era":
			return "I'm good. How are you?"
		"Future Era":
			return "My state is good. How is yours?"
		_:
			return "Good, how are you?"
func _school_apply_meal_social_activity(people: Array, profile: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rows: Array = []
	for raw_person in people:
		var row: Dictionary = _safe_dictionary(raw_person)
		if row.is_empty():
			continue
		rows.append(row)

	if rows.is_empty():
		return rows

	var indices: Array = []
	for i in range(rows.size()):
		indices.append(i)
	indices.shuffle()

	var used: Dictionary = {}

	for raw_index in indices:
		var index: int = int(raw_index)
		if used.has(index):
			continue
		if index < 0 or index >= rows.size():
			continue

		var row: Dictionary = _safe_dictionary(rows [index])
		var roll: float = rng.randf()

		if roll <= 0.34 or rows.size() <= 1:
			row ["activity"] = _school_meal_solo_activity(profile, rng)
			row ["social_group"] = []
			rows [index] = row
			used [index] = true
			continue

		var group_size: int = 2 if roll <= 0.78 else 3
		var group_indices: Array = [index]
		used [index] = true

		for other_raw_index in indices:
			var other_index: int = int(other_raw_index)
			if used.has(other_index):
				continue
			if other_index < 0 or other_index >= rows.size():
				continue

			group_indices.append(other_index)
			used [other_index] = true

			if group_indices.size() >= group_size:
				break

		if group_indices.size() <= 1:
			row ["activity"] = _school_meal_solo_activity(profile, rng)
			row ["social_group"] = []
			rows [index] = row
			continue

		var group_people: Array = []
		for group_raw_index in group_indices:
			var group_index: int = int(group_raw_index)
			if group_index < 0 or group_index >= rows.size():
				continue

			var group_row: Dictionary = _safe_dictionary(rows [group_index])
			var person_id: int = int(group_row.get("person_id", group_index))
			var full_name: String = str(group_row.get("full_name", "Someone")).strip_edges()
			if full_name == "":
				full_name = "Someone"

			group_people.append({
				"index": group_index,
				"person_id": person_id,
				"full_name": full_name
			})

		if group_people.size() <= 1:
			for raw_person_data in group_people:
				var solo_data: Dictionary = _safe_dictionary(raw_person_data)
				var solo_index: int = int(solo_data.get("index", -1))
				if solo_index < 0 or solo_index >= rows.size():
					continue

				var solo_row: Dictionary = _safe_dictionary(rows [solo_index])
				solo_row ["activity"] = _school_meal_solo_activity(profile, rng)
				solo_row ["social_group"] = []
				rows [solo_index] = solo_row
			continue

		for raw_person_data in group_people:
			var person_data: Dictionary = _safe_dictionary(raw_person_data)
			var group_index: int = int(person_data.get("index", -1))
			var self_id: int = int(person_data.get("person_id", -1))
			var self_name: String = str(person_data.get("full_name", "")).strip_edges()

			if group_index < 0 or group_index >= rows.size():
				continue

			var group_row: Dictionary = _safe_dictionary(rows [group_index])
			var others: Array = []

			for raw_other_data in group_people:
				var other_data: Dictionary = _safe_dictionary(raw_other_data)
				var other_id: int = int(other_data.get("person_id", -1))
				var other_name: String = str(other_data.get("full_name", "Someone")).strip_edges()

				if other_name == "":
					other_name = "Someone"

				if other_id == self_id and other_id > 0:
					continue

				if other_id <= 0 and other_name == self_name:
					continue

				others.append(other_name)

			if others.is_empty():
				group_row ["activity"] = _school_meal_solo_activity(profile, rng)
			elif others.size() == 1:
				group_row ["activity"] = "talking with %s" % str(others [0])
			else:
				group_row ["activity"] = "talking in a group with %s" % _school_join_names(others)

			group_row ["social_group"] = others
			rows [group_index] = group_row

	return rows

func _school_meal_solo_activity(profile: Dictionary, rng: RandomNumberGenerator) -> String:
	var meal_label: String = str(profile.get("meal_surface_label", "meal")).to_lower()
	var options: Array = [
		"eating alone",
		"watching the room",
		"keeping to themselves",
		"quietly finishing their meal",
		"listening nearby"
	]

	if meal_label.find("courtyard") >= 0:
		options.append("sitting near the courtyard edge")
	if meal_label.find("hall") >= 0:
		options.append("sitting along the hall wall")
	if meal_label.find("lunch") >= 0 or meal_label.find("commons") >= 0:
		options.append("scrolling through the lunch noise")

	return str(options [int(rng.randi_range(0, options.size() - 1))])


func _school_join_names(names: Array) -> String:
	var clean: Array = []
	for raw_name in names:
		var name_text: String = str(raw_name).strip_edges()
		if name_text != "":
			clean.append(name_text)

	if clean.is_empty():
		return "nearby students"
	if clean.size() == 1:
		return str(clean [0])
	if clean.size() == 2:
		return "%s and %s" % [str(clean [0]), str(clean [1])]

	var out: String = ""
	for i in range(clean.size()):
		if i > 0:
			out += ", " if i < clean.size() - 1 else ", and "
		out += str(clean [i])
	return out

func _school_people_label(count: int) -> String:
	if count == 1:
		return "1 person"
	return "%d people" % max(0, count)


func _school_profile_for(school_name: String, mode: String, _person: Person) -> Dictionary:
	var era_name: String = gs.era.name
	var lower_school: String = str(school_name).strip_edges().to_lower()
	if mode == "college_major":
		var major_name: String = _major_from_school_name(school_name)
		return {
			"institution_type": "college_major",
			"lane": "college",
			"program": "College Major",
			"major": major_name,
			"tuition": _school_tuition_for_option(school_name, mode, _person),
			"class_surface_label": "College Courses",
			"meal_surface_label": "Campus Commons",
			"meal_activity": "moving through campus between classes",
			"hallway_label": "Campus Walkway",
			"hallway_activity": "crossing campus",
			"social_surface_label": "Campus Social Pressure",
			"has_modern_lunchroom": true,
			"classes": _college_classes_for_major(major_name),
			"ambient_events": [
				"A professor challenged my answer in front of the class.",
				"My study group somehow became more dramatic than the assignment.",
				"I felt the pressure of choosing a future that actually costs money.",
				"Campus made adulthood feel official and fake at the same time."
			],
			"friction_templates": [
				"During campus lunch, {antagonist} joked that my major was useless. {helper} backed me up before the table got quiet.",
				"In class, {antagonist} tried to embarrass me during discussion. {helper} added the missing detail and saved the moment.",
				"At the campus commons, {antagonist} flexed their internship plans. {helper} reminded me that my path was still moving."
			],
			"crush_line": "Someone from class asked if I wanted to study together a little too casually.",
			"jealous_line": "I compared my future to students who already seemed connected.",
			"impulsive_line": "I nearly changed my whole major after one bad lecture."
		}

	if mode == "graduate_school":
		var required_major: String = _graduate_school_required_major(school_name)
		var scholarship_ok: bool = _qualifies_for_grad_scholarship(_person, school_name)
		var scholarship_reason: String = "Scholarship locked: complete the matching major and keep strong college performance."
		if scholarship_ok:
			scholarship_reason = "Scholarship eligible: matching major completed with strong college performance."
		return {
			"institution_type": "graduate_school",
			"lane": "graduate_school",
			"program": school_name,
			"graduate_school": school_name,
			"required_major": required_major,
			"scholarship_eligible": scholarship_ok,
			"scholarship_reason": scholarship_reason,
			"tuition": _school_tuition_for_option(school_name, mode, _person),
			"class_surface_label": "Graduate Courses",
			"meal_surface_label": "Graduate Commons",
			"meal_activity": "recovering between impossible lectures",
			"hallway_label": "Graduate Hall",
			"hallway_activity": "moving between seminars",
			"social_surface_label": "Professional Pressure",
			"has_modern_lunchroom": true,
			"classes": ["Advanced Seminar", "Clinical / Case Lab", "Ethics", "Professional Practice"],
			"ambient_events": [
				"A professor treated the room like everyone already had their life together.",
				"The workload made undergrad look like a tutorial.",
				"A classmate casually mentioned a connection that could change their career.",
				"Graduate school made ambition feel expensive."
			],
			"friction_templates": [
				"During a graduate break, {antagonist} implied I did not belong here. {helper} reminded me my record earned the seat.",
				"In seminar, {antagonist} tried to corner my argument. {helper} gave me the source I needed.",
				"At the graduate commons, {antagonist} bragged about their scholarship. {helper} helped me look for another funding path."
			],
			"crush_line": "Someone in my cohort started saving me a seat.",
			"jealous_line": "I compared my funding package to everyone else's.",
			"impulsive_line": "I nearly sent an email I absolutely should have drafted twice."
		}
	if mode == "bending_school":
		return {
			"institution_type": "bending_school",
			"class_surface_label": "Bending Forms",
			"meal_surface_label": "Training Yard Meal Break",
			"meal_activity": "recovering after forms practice",
			"hallway_label": "Training Yard",
			"hallway_activity": "waiting for sparring drills",
			"social_surface_label": "Training Rivalry Pressure",
			"has_modern_lunchroom": false,
			"classes": ["Forms Practice", "Element Control", "Discipline Circle"],
			"ambient_events": [
				"A student copied my stance and almost got it right.",
				"The instructor corrected my breathing in front of everyone.",
				"Someone challenged me with their eyes before practice even started.",
				"The yard got quiet when my bending improved."
			],
			"friction_templates": [
				"{antagonist} smirked when my form slipped during drills. {helper} quietly showed me how to reset my stance.",
				"{antagonist} pushed the pace too hard during sparring. {helper} stepped between us before it became a real fight.",
				"During the training yard meal break, {antagonist} joked about my control. {helper} reminded everyone I was improving."
			],
			"crush_line": "Someone watched my forms practice a little too closely.",
			"jealous_line": "I found myself comparing my bending progress to other students.",
			"impulsive_line": "I nearly escalated a training drill into a real fight."
		}

	match era_name:
		"Ancient Era":
			var institution_type: String = "temple_tutoring"
			if lower_school.find("agoge") >= 0:
				institution_type = "warrior_training_yard"
			elif lower_school.find("academy") >= 0:
				institution_type = "royal_academy"
			elif lower_school.find("scholar") >= 0:
				institution_type = "scribe_school"

			return {
				"institution_type": institution_type,
				"class_surface_label": "Lessons",
				"meal_surface_label": "Communal Meal Courtyard",
				"meal_activity": "sharing a courtyard meal",
				"hallway_label": "Courtyard Walkway",
				"hallway_activity": "moving between lessons and drills",
				"social_surface_label": "Court / Temple Social Pressure",
				"has_modern_lunchroom": false,
				"classes": ["Scribe Lessons", "Ritual Memory", "Numbers And Grain", "Discipline Yard"],
				"ambient_events": [
					"A tutor praised my memory in front of the other students.",
					"I copied symbols until my hand cramped.",
					"A student whispered that my family name carried weight.",
					"The courtyard felt louder than the lesson."
				],
				"friction_templates": [
					"During the communal meal courtyard, {antagonist} laughed when my clay tablet cracked. {helper} helped me gather the pieces before the tutor saw.",
					"{antagonist} mocked my recitation in the temple hall. {helper} whispered the next line before I froze.",
					"At the training yard meal break, {antagonist} called my stance soft. {helper} told me to keep my chin up."
				],
				"crush_line": "Someone lingered near the courtyard after lessons like they wanted to speak.",
				"jealous_line": "I compared my progress to students with stronger family names.",
				"impulsive_line": "I nearly answered a temple insult louder than wisdom allowed."
			}

		"Medieval Era":
			var medieval_type: String = "monastery_education"
			if lower_school.find("knight") >= 0:
				medieval_type = "warrior_training_yard"
			elif lower_school.find("guild") >= 0:
				medieval_type = "apprenticeship_hall"
			elif lower_school.find("court") >= 0:
				medieval_type = "royal_academy"

			return {
				"institution_type": medieval_type,
				"class_surface_label": "Studies",
				"meal_surface_label": "Hall Meal Break",
				"meal_activity": "eating under watchful elders",
				"hallway_label": "Stone Hallway",
				"hallway_activity": "moving between study rooms",
				"social_surface_label": "Hall Reputation Pressure",
				"has_modern_lunchroom": false,
				"classes": ["Letters And Ledgers", "Faith And Oaths", "Craft Practice", "Etiquette / Combat"],
				"ambient_events": [
					"A master corrected my work and made everyone watch.",
					"The hall smelled like wax, bread, and old arguments.",
					"A student repeated a rumor before prayers ended.",
					"I learned more from the whispers than the lesson."
				],
				"friction_templates": [
					"During the hall meal break, {antagonist} laughed when I dropped my bread. {helper} slid half of theirs onto my plate.",
					"{antagonist} called me unfit for the hall. {helper} challenged them with one look.",
					"In the stone hallway, {antagonist} spread a rumor about my family. {helper} told me who started it."
				],
				"crush_line": "Someone kept finding reasons to sit near me at the hall table.",
				"jealous_line": "I compared myself to students with better patrons.",
				"impulsive_line": "I nearly broke hall discipline over a whispered insult."
			}

		"Industrial Era":
			return {
				"institution_type": "industrial_school",
				"class_surface_label": "Classrooms",
				"meal_surface_label": "Lunchroom",
				"meal_activity": "eating lunch between bells",
				"hallway_label": "Hallways",
				"hallway_activity": "moving between class periods",
				"social_surface_label": "Cliques / Discipline Pressure",
				"has_modern_lunchroom": true,
				"classes": ["Reading Room", "Arithmetic", "Civics", "Trade Practice"],
				"ambient_events": [
					"The bell controlled the whole day.",
					"A teacher warned the room to stop whispering.",
					"Someone passed a note and acted innocent.",
					"The lunchroom felt like its own small city."
				],
				"friction_templates": [
					"During lunch, {antagonist} laughed when my tray slipped. {helper} helped me clean it up.",
					"In the hallway, {antagonist} shoved past me and acted like I was invisible. {helper} asked if I was okay.",
					"A rumor moved across the lunchroom before the bell rang. {antagonist} enjoyed it. {helper} told me the truth."
				],
				"crush_line": "A classmate looked away too fast when I noticed them staring.",
				"jealous_line": "I compared my grades to the students everyone praised.",
				"impulsive_line": "I almost snapped back at a teacher in front of the class."
			}

		"Modern Era":
			return {
				"institution_type": "modern_school",
				"class_surface_label": "Classrooms",
				"meal_surface_label": "Lunchroom",
				"meal_activity": "sitting in the lunchroom",
				"hallway_label": "Hallways",
				"hallway_activity": "moving through the halls",
				"social_surface_label": "Cliques / Rumors / Crushes",
				"has_modern_lunchroom": true,
				"classes": ["Homeroom", "Math", "Science", "History", "Elective"],
				"ambient_events": [
					"A teacher praised my answer and the room reacted.",
					"The hallway had more drama than the lesson.",
					"A group kept whispering every time I passed.",
					"The lunchroom made every friendship feel public."
				],
				"friction_templates": [
					"During lunch, {antagonist} laughed when my tray slipped. {helper} helped me clean it up. My reputation shifted.",
					"In the hallway, {antagonist} repeated a rumor loud enough for me to hear. {helper} walked beside me like it did not matter.",
					"At lunch, {antagonist} tried to make me the joke of the table. {helper} changed the subject before it stuck."
				],
				"crush_line": "A classmate seemed to have a crush on me.",
				"jealous_line": "I caught myself comparing my life to everyone else's highlight reel.",
				"impulsive_line": "I nearly turned a hallway comment into a whole incident."
			}

		"Future Era":
			return {
				"institution_type": "future_learning_ecosystem",
				"class_surface_label": "Learning Modules",
				"meal_surface_label": "Nutrient Commons",
				"meal_activity": "taking a nutrient break",
				"hallway_label": "Transit Spine",
				"hallway_activity": "moving between smart classrooms",
				"social_surface_label": "Algorithmic Social Pressure",
				"has_modern_lunchroom": true,
				"classes": ["AI Tutor Sync", "Simulation Lab", "Ethics Module", "Skill Pod"],
				"ambient_events": [
					"The AI tutor adjusted the lesson before I admitted I was confused.",
					"A classmate's ranking update changed the mood instantly.",
					"The simulation lab exposed who panicked under pressure.",
					"The nutrient commons tracked everything except the awkward silence."
				],
				"friction_templates": [
					"During nutrient break, {antagonist} laughed when my simulation score flashed red. {helper} patched my module before the ranking locked.",
					"In the transit spine, {antagonist} leaked my learning score. {helper} flooded the feed with distractions.",
					"At the nutrient commons, {antagonist} used the class algorithm against me. {helper} helped me appeal the score."
				],
				"crush_line": "Someone kept syncing their study pod schedule with mine.",
				"jealous_line": "I compared myself to students whose learning scores updated like celebrity stats.",
				"impulsive_line": "I nearly challenged the school algorithm in public."
			}

	return {
		"institution_type": "school",
		"class_surface_label": "Classes",
		"meal_surface_label": "Meal Break",
		"meal_activity": "taking a break",
		"hallway_label": "Shared Space",
		"hallway_activity": "moving between lessons",
		"social_surface_label": "School Pressure",
		"has_modern_lunchroom": false,
		"classes": ["Core Lessons"],
		"ambient_events": [],
		"friction_templates": []
	}


func _resolve_school_social_friction_event(person: Person) -> Dictionary:
	if person == null:
		return {}
	if not _is_active_student(person):
		return {}
	if randi() % 3 != 0:
		return {}

	var classmates: Array = get_classmates(person)
	if classmates.size() < 2:
		return {}

	var contract: Dictionary = _ensure_school_contract_for_enrollment(person)
	var profile: Dictionary = _safe_dictionary(contract.get("profile", {}))
	var templates: Array = _safe_array(profile.get("friction_templates", []))
	if templates.is_empty():
		return {}

	classmates.shuffle()
	var antagonist: Person = classmates [0]
	var helper: Person = classmates [1]
	if antagonist == null or helper == null:
		return {}

	var template: String = str(templates [randi() % templates.size()])
	var antagonist_name: String = ("%s %s" % [antagonist.first_name, antagonist.last_name]).strip_edges()
	var helper_name: String = ("%s %s" % [helper.first_name, helper.last_name]).strip_edges()
	var text: String = template.replace("{antagonist}", antagonist_name).replace("{helper}", helper_name)

	person.mental_health = clamp(person.mental_health - randf() * 3.0, 0.0, 100.0)
	person.satisfaction = clamp(person.satisfaction + randf_range(-2.0, 2.0), 0.0, 100.0)

	if typeof(person.affection) == TYPE_DICTIONARY:
		person.affection [antagonist.id] = clamp(int(person.affection.get(antagonist.id, 50)) - randi_range(4, 12), 0, 100)
		person.affection [helper.id] = clamp(int(person.affection.get(helper.id, 50)) + randi_range(4, 12), 0, 100)

	var memory_key: String = str(int(person.id))
	var rows: Array = _safe_array(school_social_memory.get(memory_key, []))
	rows.append({
		"year": int(gs.year),
		"text": text,
		"antagonist_id": int(antagonist.id),
		"helper_id": int(helper.id),
		"contract_id": str(contract.get("contract_id", "")),
		"era": gs.era.name
	})
	if rows.size() > 12:
		rows = rows.slice(rows.size() - 12, rows.size())
	school_social_memory [memory_key] = rows

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCHOOL_DRAMA, {
			"npc_id": person.id,
			"target_id": antagonist.id,
			"helper_id": helper.id,
			"text": text,
			"drama_type": "contract_school_friction",
			"source": "school_engine"
		})

	return {
		"success": true,
		"text": text,
		"antagonist_id": int(antagonist.id),
		"helper_id": int(helper.id)
	}


func _needs_school_enrollment_choice(
	person: Person
) -> bool:
	if (
		person == null
		or not person.alive
		or not _education_rights_allow_person(
			person
		)
	):
		return false

	var transition: Dictionary = (
		_next_minor_school_transition_for(
			person
		)
	)

	if (
		transition.is_empty()
		or not bool(
			transition.get(
				"planning_due",
				false
			)
		)
	):
		return false

	var stage_key: String = str(
		transition.get(
			"stage_key",
			""
		)
	)

	return _minor_school_stage_plan_for(
		person,
		stage_key
	).is_empty()


func _school_child_enrollment_prompt(
	child: Person,
	stage_key: String = ""
) -> String:
	if child == null:
		return (
			"My parent or guardian is talking about "
			+ "my education for next year. What will I suggest?"
		)

	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	if clean_stage == "":
		var transition: Dictionary = (
			_next_minor_school_transition_for(
				child
			)
		)

		clean_stage = str(
			transition.get(
				"stage_key",
				""
			)
		)

	var stage_display: String = (
		_school_stage_display_name(
			clean_stage
		)
	)

	return (
		"My parent or guardian has started talking about "
		+ "my %s education for next year. What will I suggest?"
	) % stage_display


func _school_enrollment_choices_for(
	_actor: Person,
	target: Person,
	requester_role: String,
	stage_key: String = ""
) -> Array:
	var choices: Array = []

	if target == null:
		return choices

	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	if clean_stage == "":
		var transition: Dictionary = (
			_next_minor_school_transition_for(
				target
			)
		)

		clean_stage = str(
			transition.get(
				"stage_key",
				""
			)
		)

	var options: Array = (
		get_school_options_for_stage(
			target,
			clean_stage
		)
		if clean_stage != ""
		else get_school_options_for(
			target
		)
	)

	for raw_option in options:
		var option: Dictionary = _safe_dictionary(
			raw_option
		)
		var contract: Dictionary = _safe_dictionary(
			option.get(
				"contract",
				{}
			)
		)
		var school_name: String = str(
			option.get(
				"name",
				""
			)
		).strip_edges()
		var mode: String = str(
			option.get(
				"type",
				""
			)
		).strip_edges()

		if (
			school_name == ""
			or mode == ""
		):
			continue

		var tuition: float = float(
			contract.get(
				"tuition",
				0.0
			)
		)
		var tuition_text: String = (
			"Free"
			if tuition <= 0.0
			else "$%s / year"
			% str(
				int(
					round(
						tuition
					)
				)
			)
		)
		var label: String = (
			"Suggest %s"
			% school_name
		)
		var journal: String = (
			"I told my parent or guardian "
			+ "that I wanted %s."
		) % school_name
		var request_kind: String = (
			"stage_preference"
		)

		if requester_role == "parent_player":
			label = (
				"Choose %s for %s (%s)"
				% [
					school_name,
					target.first_name,
					tuition_text
				]
			)
			journal = (
				"I planned %s's next school stage: %s."
				% [
					target.first_name,
					school_name
				]
			)
			request_kind = "custodial_stage_plan"

		choices.append({
			"id": (
				"school_choice_%s_%s_%s"
				% [
					clean_stage,
					mode,
					school_name.to_lower().replace(
						" ",
						"_"
					)
				]
			),
			"label": label,
			"journal_line": journal,
			"school_request_kind": request_kind,
			"school_target_id": int(
				target.id
			),
			"school_stage_key": clean_stage,
			"school_name": school_name,
			"school_mode": mode,
			"tuition": tuition,
			"tuition_text": tuition_text,
			"followup_hooks": [
				"school.enrollment.choice"
			],
			"bias_payloads": {
				"school_pressure": {
					"mental_delta": 1.0,
					"smarts_delta": 1.0,
					"peer_tension": 0.0
				},
				"expiry": {
					"years": 1
				}
			}
		})

	var family_label: String = (
		"Tell them I don't have a preference."
	)
	var family_journal: String = (
		"I told my family I did not have a school preference."
	)
	var family_request_kind: String = (
		"stage_family_decides"
	)

	if requester_role == "parent_player":
		family_label = (
			"Let the household decide when the time comes."
		)
		family_journal = (
			"I left the final school decision open for now."
		)
		family_request_kind = (
			"custodial_stage_family_decides"
		)

	choices.append({
		"id": (
			"school_choice_%s_family_decides"
			% clean_stage
		),
		"label": family_label,
		"journal_line": family_journal,
		"school_request_kind": family_request_kind,
		"school_target_id": int(
			target.id
		),
		"school_stage_key": clean_stage,
		"school_name": "",
		"school_mode": "era_school",
		"followup_hooks": [
			"school.enrollment.family_decides"
		],
		"bias_payloads": {
			"school_pressure": {
				"mental_delta": -1.0,
				"peer_tension": 2.0
			},
			"expiry": {
				"years": 1
			}
		}
	})

	return choices
func _single_gender_school_prefix(
	person: Person
) -> String:
	if person == null:
		return ""

	match str(
		person.gender
	).strip_edges().to_lower():
		"male":
			return "All-Boys"

		"female":
			return "All-Girls"

	return ""


func _era_school_type_contract_names_for_stage(
	era_name: String,
	stage_key: String,
	person: Person = null
) -> Array:
	match str(
		era_name
	):
		"Ancient Era":
			match str(
				stage_key
			):
				"adult_learning":
					return [
						"Scribe Mastery Hall",
						"Royal Academy Adult Circle",
						"Warrior Command Yard",
						"Temple Scholar House"
					]

				_:
					return [
						"Temple Tutoring",
						"Royal Academy",
						"Scribe School",
						"Warrior Training Yard"
					]

		"Medieval Era":
			match str(
				stage_key
			):
				"adult_learning":
					return [
						"Guild Mastery Hall",
						"Monastic Scholar Track",
						"Court Law Hall",
						"Knight Commander Yard"
					]

				_:
					return [
						"Monastery Education",
						"Guild Apprenticeship",
						"Court Education",
						"Knight Hall"
					]

		"Industrial Era":
			match str(
				stage_key
			):
				"adult_learning":
					return [
						"Technical College",
						"Normal School",
						"Business Institute",
						"Night School"
					]

				_:
					return [
						"Public School",
						"Factory School",
						"Church School",
						"Boarding School"
					]

		"Modern Era":
			match str(
				stage_key
			):
				"preschool":
					return [
						"Public Preschool",
						"Private Preschool"
					]

				"elementary":
					var elementary: Array = [
						"Public Elementary School",
						"Private Elementary School",
						"Boarding Elementary School"
					]
					var elementary_gender_prefix: String = (
						_single_gender_school_prefix(
							person
						)
					)

					if elementary_gender_prefix != "":
						elementary.append(
							"%s Public Elementary School"
							% elementary_gender_prefix
						)
						elementary.append(
							"%s Private Elementary School"
							% elementary_gender_prefix
						)

					return elementary

				"middle":
					var middle: Array = [
						"Public Middle School",
						"Private Middle School",
						"Boarding Middle School"
					]
					var middle_gender_prefix: String = (
						_single_gender_school_prefix(
							person
						)
					)

					if middle_gender_prefix != "":
						middle.append(
							"%s Public Middle School"
							% middle_gender_prefix
						)
						middle.append(
							"%s Private Middle School"
							% middle_gender_prefix
						)

					return middle

				"high":
					var high: Array = [
						"Public High School",
						"Private High School",
						"Boarding High School",
						"Military High School"
					]
					var high_gender_prefix: String = (
						_single_gender_school_prefix(
							person
						)
					)

					if high_gender_prefix != "":
						high.append(
							"%s Public High School"
							% high_gender_prefix
						)
						high.append(
							"%s Private High School"
							% high_gender_prefix
						)

					return high

				"adult_learning", "young_adult":
					return [
						"Community College",
						"State University",
						"Trade School",
						"Online University"
					]

				"graduate":
					return [
						"Nursing School",
						"Medical School",
						"Law School",
						"Business School"
					]

		"Future Era":
			match str(
				stage_key
			):
				"preschool":
					return [
						"Early Learning Pod",
						"AI Preschool"
					]

				"adult_learning":
					return [
						"Skill Cloud",
						"Neural University",
						"Corporate Academy",
						"Orbital Institute"
					]

				_:
					return [
						"Learning Pod",
						"AI Academy",
						"Simulation School",
						"Orbital Academy"
					]

	return [
		"Local School",
		"Private Tutor",
		"Apprenticeship Hall",
		"Public Lessons"
	]
func _has_completed_college_major(person: Person) -> bool:
	if person == null:
		return false

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	var completed: Array = _safe_array(record.get("completed_college_majors", []))
	return not completed.is_empty()

func _school_option_available_for(person: Person, school_name: String, mode: String) -> bool:
	if person == null:
		return false

	var clean_school: String = str(school_name).strip_edges()
	var clean_mode: String = str(mode).strip_edges()
	if clean_school == "" or clean_mode == "":
		return false

	var options: Array = get_school_options_for(person)
	for raw_option in options:
		var option: Dictionary = _safe_dictionary(raw_option)
		var option_name: String = str(option.get("name", "")).strip_edges()
		var option_mode: String = str(option.get("type", "")).strip_edges()
		if option_name == clean_school and option_mode == clean_mode:
			return true

	return false
func _person_id_in_school_array(values: Array, target_id: int) -> bool:
	for raw_id in values:
		if int(raw_id) == int(target_id):
			return true
	return false


func _append_unique_school_person(out: Array, seen: Dictionary, person: Person) -> void:
	if person == null:
		return
	if seen.has(int(person.id)):
		return
	seen [int(person.id)] = true
	out.append(person)


func _school_person_is_child_of(parent: Person, child: Person) -> bool:
	if parent == null or child == null:
		return false
	if _person_id_in_school_array(_safe_array(parent.children), int(child.id)):
		return true
	if _person_id_in_school_array(_safe_array(child.parents), int(parent.id)):
		return true
	return false


func get_children_for_parent(parent: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if parent == null or gs == null:
		return out

	for raw_child_id in _safe_array(parent.children):
		var child: Person = gs.get_or_reactivate_npc_by_id(int(raw_child_id))
		if child == null:
			continue
		if not child.alive:
			continue
		if not _person_id_in_school_array(_safe_array(child.parents), int(parent.id)):
			child.parents.append(int(parent.id))
		_append_unique_school_person(out, seen, child)

	for raw_npc in _safe_array(gs.npcs):
		var npc: Person = raw_npc
		if npc == null:
			continue
		if not npc.alive:
			continue
		if int(npc.id) == int(parent.id):
			continue
		if _person_id_in_school_array(_safe_array(npc.parents), int(parent.id)):
			if not _person_id_in_school_array(_safe_array(parent.children), int(npc.id)):
				parent.children.append(int(npc.id))
			_append_unique_school_person(out, seen, npc)

	if gs.player != null and int(gs.player.id) != int(parent.id):
		var player_child: Person = gs.player
		if player_child.alive and _person_id_in_school_array(_safe_array(player_child.parents), int(parent.id)):
			if not _person_id_in_school_array(_safe_array(parent.children), int(player_child.id)):
				parent.children.append(int(player_child.id))
			_append_unique_school_person(out, seen, player_child)

	return out
func get_enrollable_children_for_parent(parent: Person) -> Array:
	var out: Array = []
	if parent == null or gs == null:
		return out

	var children: Array = get_children_for_parent(parent)
	for raw_child in children:
		var child: Person = raw_child
		if child == null:
			continue
		if not child.alive:
			continue
		if int(child.age) < _get_school_start_age():
			continue
		if _is_active_student(child):
			continue
		if not can_attend_school(child):
			continue

		out.append(child)

	return out


func enroll_child_from_parent_school_hub(parent: Person, child_id: int, school_name: String, mode: String) -> Dictionary:
	if parent == null:
		return {
			"success": false,
			"text": "No parent was supplied for child enrollment.",
			"popup_title": "Child Enrollment",
			"popup_text": "No parent was supplied for child enrollment.",
			"popup_footer": "Tap anywhere to continue."
		}
	if child_id <= 0:
		return {
			"success": false,
			"text": "No child was selected.",
			"popup_title": "Child Enrollment",
			"popup_text": "No child was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var child: Person = gs.get_or_reactivate_npc_by_id(child_id)
	if child == null:
		return {
			"success": false,
			"text": "That child could not be found.",
			"popup_title": "Child Enrollment",
			"popup_text": "That child could not be found.",
			"popup_footer": "Tap anywhere to continue."
		}

	var is_parent_child: bool = false
	for raw_child_id in parent.children:
		if int(raw_child_id) == int(child_id):
			is_parent_child = true
			break

	if not is_parent_child:
		return {
			"success": false,
			"text": "%s is not my child." % child.first_name,
			"popup_title": "Child Enrollment",
			"popup_text": "%s is not my child." % child.first_name,
			"popup_footer": "Tap anywhere to continue."
		}

	if int(child.age) < _get_school_start_age():
		return {
			"success": false,
			"text": "%s is not old enough for school yet." % child.first_name,
			"popup_title": "Too Young",
			"popup_text": "%s is not old enough for school yet." % child.first_name,
			"popup_footer": "Tap anywhere to continue."
		}

	if _is_active_student(child):
		return {
			"success": false,
			"text": "%s is already enrolled in school." % child.first_name,
			"popup_title": "Already Enrolled",
			"popup_text": "%s is already enrolled in school." % child.first_name,
			"popup_footer": "Tap anywhere to continue."
		}

	if not _school_option_available_for(child, school_name, mode):
		return {
			"success": false,
			"text": "%s cannot enroll in %s right now." % [child.first_name, school_name],
			"popup_title": "School Not Available",
			"popup_text": "%s cannot enroll in %s right now. Their age or era path does not expose that school contract." % [child.first_name, school_name],
			"popup_footer": "Tap anywhere to continue."
		}

	var result: Dictionary = enroll_by_contract_choice(
		child,
		school_name,
		mode,
		{
			"custodial_authority_confirmed": true,
			"custodial_actor_id": int(
				parent.id
			),
			"source": (
				"school_engine."
				+ "parent_school_hub"
			)
		}
	)
	if bool(result.get("success", false)):
		var line: String = "I enrolled %s in %s." % [child.first_name, school_name]
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(parent, {
				"type": "text",
				"text": line,
				"source": "school_engine.parent_school_hub"
			})
		result ["text"] = line
		result ["popup_title"] = "Child Enrolled"
		result ["popup_text"] = line
		result ["popup_footer"] = "Tap anywhere to continue."
		result ["return_to_parent_enroll_screen"] = true

	return result
func enroll_children_from_parent_school_hub(parent: Person, child_ids: Array, school_name: String, mode: String) -> Dictionary:
	if parent == null:
		return {
			"success": false,
			"text": "No parent was supplied for child enrollment.",
			"popup_title": "Child Enrollment",
			"popup_text": "No parent was supplied for child enrollment.",
			"popup_footer": "Tap anywhere to continue."
		}

	if child_ids.is_empty():
		return {
			"success": false,
			"text": "No children were selected.",
			"popup_title": "Choose A Child",
			"popup_text": "Select at least one eligible child before choosing a school.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_school: String = str(school_name).strip_edges()
	var clean_mode: String = str(mode).strip_edges()
	if clean_school == "" or clean_mode == "":
		return {
			"success": false,
			"text": "No school contract was selected.",
			"popup_title": "Choose A School",
			"popup_text": "No school contract was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var seen: Dictionary = {}
	var enrolled_names: Array = []
	var blocked_lines: Array = []

	for raw_child_id in child_ids:
		var child_id: int = int(raw_child_id)
		if child_id <= 0:
			continue
		if seen.has(child_id):
			continue
		seen [child_id] = true

		var result: Dictionary = enroll_child_from_parent_school_hub(parent, child_id, clean_school, clean_mode)
		if bool(result.get("success", false)):
			var child: Person = gs.get_or_reactivate_npc_by_id(child_id)
			if child != null:
				enrolled_names.append(child.first_name)
			else:
				enrolled_names.append("Child %d" % child_id)
		else:
			var reason: String = str(result.get("text", result.get("popup_text", "Enrollment failed."))).strip_edges()
			if reason != "":
				blocked_lines.append(reason)

	var success: bool = not enrolled_names.is_empty()
	var popup_lines: Array = []

	if success:
		popup_lines.append("Enrolled: %s" % _safe_join_strings(enrolled_names))
		popup_lines.append("School: %s" % clean_school)

	if not blocked_lines.is_empty():
		popup_lines.append("Blocked:")
		for blocked in blocked_lines:
			popup_lines.append("- %s" % str(blocked))

	var final_text: String = _safe_join_strings(popup_lines, "\n")
	if final_text == "":
		final_text = "No children were enrolled."

	return {
		"success": success,
		"text": final_text,
		"popup_title": "Children Enrolled" if success else "Child Enrollment",
		"popup_text": final_text,
		"popup_footer": "Tap anywhere to continue.",
		"enrolled_names": enrolled_names,
		"blocked": blocked_lines,
		"return_to_parent_enroll_screen": not success
	}

func _is_current_player_child(person: Person) -> bool:
	if person == null or gs == null or gs.player == null:
		return false
	return int(person.id) in gs.player.children


func ensure_world_npc_school_reality() -> void:
	if gs == null:
		return
	if not ("npcs" in gs):
		return

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null:
			continue
		if not npc.alive:
			continue
		if gs.player != null and int(npc.id) == int(gs.player.id):
			continue
		if _is_current_player_child(npc):
			continue
		if int(npc.age) < _get_school_start_age():
			continue
		if int(npc.age) >= int(ERA_SCHOOLS.get(gs.era.name, {}).get("ages", {}).get("adult_start", 18)):
			continue
		if _is_active_student(npc):
			continue
		if not can_attend_school(npc):
			continue

		_auto_assign_school(npc)
		sync_person_school_fields(npc)

func _college_majors_for_era(
	era_name: String
) -> Array:
	match str(era_name).strip_edges():
		"Industrial Era":
			return [
				"Engineering",
				"Mechanical Engineering",
				"Electrical Engineering",
				"Medicine",
				"Nursing",
				"Law",
				"Teaching",
				"Education",
				"Accounting",
				"Architecture",
				"Chemistry",
				"Business",
				"Finance"
			]

		"Modern Era":
			return [
				"Finance",
				"Psychology",
				"Criminal Justice",
				"Information Systems",
				"Economics",
				"Political Science",
				"Biology",
				"Accounting",
				"Nursing",
				"Medicine",
				"Law",
				"Teaching",
				"Education",
				"Architecture",
				"Chemistry",
				"Business",
				"Computer Science",
				"Software Engineering",
				"Physics",
				"Mathematics",
				"Civil Engineering",
				"Design",
				"History",
				"Literature",
				"AI Ethics"
			]

		"Future Era":
			return [
				"Quantum Systems",
				"Planetary Engineering",
				"Neural Architecture",
				"Nanotechnology",
				"Reality Computing",
				"Synthetic Biology",
				"Artificial Consciousness",
				"Temporal Physics",
				"Orbital Logistics",
				"Interstellar Medicine",
				"Climate Synthesis",
				"Planetary Governance",
				"AI Ethics"
			]

		_:
			return []


func _modern_college_majors() -> Array:
	return _college_majors_for_era(
		"Modern Era"
	)


func _graduate_school_definitions() -> Array:
	return [
		{
			"name": "Nursing School",
			"required_major": "Nursing",
			"required_majors_any": [
				"Nursing",
				"Biology",
				"Medicine"
			],
			"tuition": 18000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Medical School",
			"required_major": "Biology",
			"required_majors_any": [
				"Biology",
				"Medicine"
			],
			"tuition": 52000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Law School",
			"required_major": "Political Science",
			"required_majors_any": [
				"Political Science",
				"Law",
				"Criminal Justice"
			],
			"tuition": 42000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Veterinarian School",
			"required_major": "Biology",
			"required_majors_any": [
				"Biology",
				"Medicine"
			],
			"tuition": 41000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Business School",
			"required_major": "Finance",
			"required_majors_any": [
				"Finance",
				"Accounting",
				"Economics",
				"Business"
			],
			"tuition": 38000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Dental School",
			"required_major": "Biology",
			"required_majors_any": [
				"Biology",
				"Medicine"
			],
			"tuition": 48000.0,
			"eras": [
				"Modern Era"
			]
		},
		{
			"name": "Pharmacy School",
			"required_major": "Biology",
			"required_majors_any": [
				"Biology",
				"Chemistry",
				"Medicine"
			],
			"tuition": 39000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Engineering Academy",
			"required_major": "Engineering",
			"required_majors_any": [
				"Engineering",
				"Mechanical Engineering",
				"Electrical Engineering",
				"Civil Engineering",
				"Physics"
			],
			"tuition": 36000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Teaching College",
			"required_major": "Education",
			"required_majors_any": [
				"Education",
				"Teaching",
				"History",
				"Literature",
				"Psychology"
			],
			"tuition": 24000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Architecture School",
			"required_major": "Architecture",
			"required_majors_any": [
				"Architecture",
				"Civil Engineering",
				"Design"
			],
			"tuition": 41000.0,
			"eras": [
				"Industrial Era",
				"Modern Era"
			]
		},
		{
			"name": "Interstellar Medical School",
			"required_major": "Interstellar Medicine",
			"required_majors_any": [
				"Interstellar Medicine",
				"Synthetic Biology",
				"Neural Architecture"
			],
			"tuition": 76000.0,
			"eras": [
				"Future Era"
			]
		},
		{
			"name": "Neural Surgery Residency",
			"required_major": "Neural Architecture",
			"required_majors_any": [
				"Neural Architecture",
				"Interstellar Medicine"
			],
			"tuition": 88000.0,
			"eras": [
				"Future Era"
			]
		},
		{
			"name": "Biofabrication Residency",
			"required_major": "Synthetic Biology",
			"required_majors_any": [
				"Synthetic Biology",
				"Nanotechnology"
			],
			"tuition": 72000.0,
			"eras": [
				"Future Era"
			]
		},
		{
			"name": "Quantum Navigation Academy",
			"required_major": "Quantum Systems",
			"required_majors_any": [
				"Quantum Systems",
				"Orbital Logistics",
				"Temporal Physics"
			],
			"tuition": 68000.0,
			"eras": [
				"Future Era"
			]
		},
		{
			"name": "Planetary Governance Academy",
			"required_major": "Planetary Governance",
			"required_majors_any": [
				"Planetary Governance",
				"AI Ethics",
				"Orbital Logistics"
			],
			"tuition": 65000.0,
			"eras": [
				"Future Era"
			]
		},
		{
			"name": "Reality Stability Institute",
			"required_major": "Reality Computing",
			"required_majors_any": [
				"Reality Computing",
				"Temporal Physics",
				"Quantum Systems"
			],
			"tuition": 92000.0,
			"eras": [
				"Future Era"
			]
		}
	]


func _graduate_school_options_for_person(
	person: Person
) -> Array:
	var out: Array = []

	if person == null:
		return out

	var era_name: String = str(gs.era.name)

	for raw_definition in _graduate_school_definitions():
		var definition: Dictionary = (
			_safe_dictionary(
				raw_definition
			)
		)
		var graduate_name: String = str(
			definition.get(
				"name",
				""
			)
		).strip_edges()

		if graduate_name == "":
			continue

		if era_name not in _safe_array(
			definition.get(
				"eras",
				[]
			)
		):
			continue

		var required_majors: Array = _safe_array(
			definition.get(
				"required_majors_any",
				[
					str(
						definition.get(
							"required_major",
							""
						)
					)
				]
			)
		)
		var eligible: bool = (
			_completed_any_college_major_for(
				person,
				required_majors
			)
		)

		out.append({
			"type": "graduate_school",
			"name": graduate_name,
			"eligible": eligible,
			"required_majors_any": required_majors,
			"contract": (
				_build_school_option_contract(
					person,
					graduate_name,
					"graduate_school"
				)
			)
		})

	return out
func _completed_any_college_major_for(
	person: Person,
	required_majors: Array
) -> bool:
	for raw_major in required_majors:
		if _completed_college_major_for(
			person,
			str(raw_major)
		):
			return true

	return false


func _major_from_school_name(school_name: String) -> String:
	var clean: String = str(
		school_name
	).strip_edges()


	if clean.begins_with(
		"College:"
	):
		return clean.replace(
			"College:",
			""
		).strip_edges()



	if clean.contains(
		" • "
	):
		var parts: PackedStringArray = clean.split(
			" • ",
			false,
			1
		)

		if parts.size() >= 2:
			return str(
				parts [1]
			).strip_edges()

	return clean


func _graduate_school_required_major(
	graduate_school: String
) -> String:
	var required_majors: Array = (
		_graduate_school_required_majors(
			graduate_school
		)
	)

	if required_majors.is_empty():
		return ""

	return str(required_majors [0])



func _graduate_school_tuition(graduate_school: String) -> float:
	var clean: String = str(graduate_school).strip_edges()
	for raw_def in _graduate_school_definitions():
		var def: Dictionary = _safe_dictionary(raw_def)
		if str(def.get("name", "")).strip_edges() == clean:
			return float(def.get("tuition", 0.0))
	return 0.0


func _school_tuition_for_option(
	school_name: String,
	mode: String,
	_person: Person
) -> float:
	var clean_name: String = str(
		school_name
	).strip_edges()
	var clean_mode: String = str(
		mode
	).strip_edges()
	var era_name: String = (
		str(gs.era.name)
		if (
			gs != null
			and gs.era != null
		)
		else ""
	)

	if clean_mode == "college_major":
		var institution_name: String = clean_name

		if clean_name.contains(
			" • "
		):
			var parts: PackedStringArray = clean_name.split(
				" • ",
				false,
				1
			)

			if not parts.is_empty():
				institution_name = str(
					parts [0]
				).strip_edges()

		var institution_tuition: float = (
			_higher_learning_institution_tuition(
				era_name,
				institution_name
			)
		)

		if institution_tuition >= 0.0:
			return institution_tuition


		return 12500.0

	if clean_mode == "graduate_school":
		return _graduate_school_tuition(
			clean_name
		)

	if clean_mode == "bending_school":
		return 0.0

	var higher_learning_tuition: float = (
		_higher_learning_institution_tuition(
			era_name,
			clean_name
		)
	)

	if higher_learning_tuition >= 0.0:
		return higher_learning_tuition

	if era_name == "Modern Era":
		var modern_school_name: String = (
			clean_name.to_lower()
		)

		if modern_school_name.contains(
			"boarding"
		):
			return 14500.0

		if modern_school_name.contains(
			"military"
		):
			return 6200.0

		if modern_school_name.contains(
			"private"
		):
			return 8500.0

		if modern_school_name.contains(
			"public"
		):
			return 0.0

	if era_name == "Industrial Era":
		match clean_name:
			"Public School":
				return 0.0
			"Factory School":
				return 0.0
			"Church School":
				return 1200.0
			"Boarding School":
				return 4800.0

	if era_name == "Future Era":
		match clean_name:
			"Learning Pod":
				return 0.0
			"AI Academy":
				return 9000.0
			"Simulation School":
				return 12000.0
			"Orbital Academy":
				return 22000.0

	if era_name in [
		"Ancient Era",
		"Medieval Era"
	]:
		if clean_name in [
			"Royal Academy",
			"Court Education",
			"Knight Hall"
		]:
			return 3500.0

		if clean_name in [
			"Apprenticeship Hall",
			"Guild Apprenticeship"
		]:
			return 900.0

	return 0.0
func _higher_learning_scholarship_contract(
	actor: Person,
	program: Dictionary
) -> Dictionary:
	if actor == null:
		return {
			"eligible": false,
			"reason": "missing_actor"
		}

	var era_name: String = str(
		program.get(
			"era_name",
			(
				gs.era.name
				if (
					gs != null
					and gs.era != null
				)
				else ""
			)
		)
	)
	var threshold: int = 75

	match era_name:
		"Ancient Era":
			threshold = 65
		"Medieval Era":
			threshold = 68
		"Industrial Era":
			threshold = 72
		"Future Era":
			threshold = 78

	var merit_score: int = clampi(
		int(
			round(
				float(actor.smarts) * 0.7
				+ float(actor.mental_health) * 0.1
				+ float(actor.satisfaction) * 0.1
				+ float(actor.respect) * 0.1
			)
		),
		0,
		100
	)
	var eligible: bool = (
		merit_score >= threshold
	)

	return {
		"eligible": eligible,
		"merit_score": merit_score,
		"required_merit_score": threshold,
		"reason": (
			"Merit requirements satisfied."
			if eligible
			else (
				"Your current academic and personal record "
				+ "did not meet the funding threshold."
			)
		),
	}


func _resolve_parent_education_sponsor(
	actor: Person,
	amount: float,
	program: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.bank_engine == null
	):
		return {
			"success": false,
			"reason": "parent_funding_authority_unavailable"
		}

	for raw_parent_id in actor.parents:
		var parent_id: int = int(
			raw_parent_id
		)

		if parent_id <= 0:
			continue




		var parent: Person = gs.get_npc_by_id(
			parent_id
		)

		if (
			parent == null
			or not parent.alive
		):
			continue

		var payment_report: Dictionary = (
			gs.bank_engine.settle_obligation_for_actor(
				parent,
				amount,
				{
					"reason": "education_parent_sponsorship",
					"program_id": str(
						program.get(
							"program_id",
							""
						)
					),
					"text": (
						"A parent paid an education obligation."
					)
				},
				{
					"source": (
						"school_engine."
						+ "parent_education_sponsorship"
					),
					"student_id": int(
						actor.id
					)
				}
			)
		)

		if bool(
			payment_report.get(
				"success",
				false
			)
		):
			payment_report [
				"parent_id"
			] = parent_id
			return payment_report

	return {
		"success": false,
		"reason": "no_resident_parent_can_cover_program_cost",
		"text": (
			"No currently resident parent could cover the program cost."
		)
	}


func resolve_higher_learning_program_funding(
	actor: Person,
	program_id: String,
	funding_method: String
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.era == null
	):
		return {
			"success": false,
			"text": "Higher learning is not available right now."
		}

	var clean_program_id: String = str(
		program_id
	).strip_edges()
	var clean_funding_method: String = str(
		funding_method
	).strip_edges().to_lower()
	var program_raw: Variant = (
		higher_learning_program_index.get(
			clean_program_id,
			{}
		)
	)
	var program: Dictionary = (
		program_raw as Dictionary
		if typeof(program_raw) == TYPE_DICTIONARY
		else {}
	)

	if program.is_empty():
		return {
			"success": false,
			"text": (
				"That higher-learning program is not resident."
			)
		}

	if str(
		program.get(
			"era_name",
			""
		)
	) != str(
		gs.era.name
	):
		return {
			"success": false,
			"text": (
				"That program belongs to a different era."
			)
		}

	if not can_attend_school(
		actor
	):
		return {
			"success": false,
			"text": (
				"You are not permitted to pursue this education "
				+ "under the current era contract."
			)
		}

	if _is_active_student(
		actor
	):
		return {
			"success": false,
			"text": (
				"You are already actively enrolled in a school program."
			)
		}

	if clean_funding_method not in [
		"scholarship",
		"parents",
		"self",
		"loan"
	]:
		return {
			"success": false,
			"text": "Unknown education funding method."
		}

	var tuition: float = max(
		0.0,
		float(
			program.get(
				"tuition",
				0.0
			)
		)
	)
	var funding_report: Dictionary = {
		"success": true,
		"funding_method": clean_funding_method,
		"amount": tuition
	}

	if tuition > 0.0:
		match clean_funding_method:
			"scholarship":
				var scholarship: Dictionary = (
					_higher_learning_scholarship_contract(
						actor,
						program
					)
				)

				if not bool(
					scholarship.get(
						"eligible",
						false
					)
				):
					return {
						"success": false,
						"popup_title": "SCHOLARSHIP",
						"popup_text": (
							"Your scholarship application was not approved."
						),
						"text": str(
							scholarship.get(
								"reason",
								"Scholarship requirements were not met."
							)
						),
						"scholarship_contract": scholarship
					}

				funding_report = {
					"success": true,
					"funding_method": "scholarship",
					"amount": tuition,
					"student_paid": 0.0,
					"scholarship_contract": scholarship
				}

			"parents":
				funding_report = (
					_resolve_parent_education_sponsor(
						actor,
						tuition,
						program
					)
				)

			"self":
				if (
					gs.bank_engine == null
					or not gs.bank_engine.has_method(
						"settle_obligation_for_actor"
					)
				):
					return {
						"success": false,
						"text": "Bank authority is unavailable."
					}

				funding_report = (
					gs.bank_engine
					.settle_obligation_for_actor(
						actor,
						tuition,
						{
							"reason": "education_self_payment",
							"program_id": clean_program_id,
							"text": (
								"Education tuition was paid."
							)
						},
						{
							"source": (
								"school_engine."
								+ "higher_learning_self_payment"
							)
						}
					)
				)

			"loan":
				if (
					gs.debt_contract_engine == null
					or not gs.debt_contract_engine.has_method(
						"create_education_debt"
					)
				):
					return {
						"success": false,
						"text": "Debt authority is unavailable."
					}

				funding_report = (
					gs.debt_contract_engine
					.create_education_debt(
						actor,
						int(
							round(
								tuition
							)
						),
						{
							"program_id": clean_program_id,
							"institution_name": str(
								program.get(
									"institution_name",
									""
								)
							),
							"program_name": str(
								program.get(
									"program_name",
									""
								)
							)
						}
					)
				)

	if not bool(
		funding_report.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"popup_title": "FUNDING",
			"popup_text": (
				"That funding path could not cover this program."
			),
			"text": str(
				funding_report.get(
					"text",
					funding_report.get(
						"reason",
						"Education funding failed."
					)
				)
			)
		}

	var enrollment_report: Dictionary = (
		_commit_higher_learning_enrollment(
			actor,
			program,
			clean_funding_method
		)
	)

	if not bool(
		enrollment_report.get(
			"success",
			false
		)
	):
		return enrollment_report

	return {
		"success": true,
		"text": str(
			enrollment_report.get(
				"text",
				"Enrollment complete."
			)
		),
		"popup_title": "ENROLLED",
		"popup_text": (
			"You are now enrolled at %s to study %s."
			% [
				str(
					program.get(
						"institution_name",
						"Higher Learning"
					)
				),
				str(
					program.get(
						"program_name",
						"your chosen field"
					)
				)
			]
		),
		"program_id": clean_program_id,
		"funding_method": clean_funding_method,
		"ui_is_renderer_only": true
	}


func _commit_higher_learning_enrollment(
	actor: Person,
	program: Dictionary,
	funding_method: String
) -> Dictionary:
	if (
		actor == null
		or program.is_empty()
	):
		return {
			"success": false,
			"text": "The education contract is no longer valid."
		}

	var school_mode: String = str(
		program.get(
			"school_mode",
			"era_school"
		)
	).strip_edges()
	var school_name: String = str(
		program.get(
			"school_name",
			""
		)
	).strip_edges()
	var institution_name: String = str(
		program.get(
			"institution_name",
			school_name
		)
	).strip_edges()
	var program_name: String = str(
		program.get(
			"program_name",
			""
		)
	).strip_edges()
	var major_name: String = str(
		program.get(
			"major",
			""
		)
	).strip_edges()
	var program_id: String = str(
		program.get(
			"program_id",
			""
		)
	).strip_edges()

	if (
		school_name == ""
		or school_mode == ""
		or program_id == ""
	):
		return {
			"success": false,
			"text": "The education contract is incomplete."
		}

	var contract_id: String = _school_contract_id(
		school_name,
		school_mode
	)

	enrollment [
		actor.id
	] = {
		"mode": school_mode,
		"school_name": school_name,
		"institution_name": institution_name,
		"started_age": int(actor.age),
		"status": "active",
		"contract_id": contract_id,
		"institution_type": (
			"college_major"
			if school_mode == "college_major"
			else "historical_higher_learning"
		),
		"era_school_stage": (
			_school_stage_key_for_person(
				actor
			)
		),
		"program": program_name,
		"higher_learning_program_id": program_id,
		"lane": (
			"college"
			if school_mode == "college_major"
			else "higher_learning"
		),
		"tuition": float(
			program.get(
				"tuition",
				0.0
			)
		),
		"funding_method": funding_method,
		"major": major_name,
		"graduate_school": "",
		"required_major": "",
		"scholarship_eligible": (
			funding_method == "scholarship"
		),
		"scholarship_reason": (
			"Education funding resolved through scholarship."
			if funding_method == "scholarship"
			else ""
		),
		"years_attended": 0,
		"meal_surface_label": ""
	}



	_register_student_in_roster(
		int(
			actor.id
		),
		_school_key(
			school_name,
			school_mode
		)
	)

	_seed_postsecondary_record_if_needed(
		actor,
		enrollment [
			actor.id
		]
	)

	sync_person_school_fields(
		actor
	)

	var text: String = (
		"I enrolled at %s to study %s."
		% [
			institution_name,
			program_name
		]
	)

	gs.narrative_engine.log_event(
		actor,
		{
			"type": "text",
			"text": text
		}
	)

	return {
		"success": true,
		"text": text,
		"contract_id": contract_id,
		"program_id": program_id,
	}
func _school_clique_definitions() -> Array:
	return [
		{
			"clique_id": "popular_kids",
			"label": "Popular Kids",
			"description": (
				"High-visibility students who dominate the school's "
				+ "social center."
			),
			"requirements_text": (
				"Popularity 70+ • Looks 70+"
			)
		},
		{
			"clique_id": "mean_girls",
			"label": "Mean Girls",
			"description": (
				"A socially sharp girls-only clique."
			),
			"requirements_text": "Women only"
		},
		{
			"clique_id": "nerds",
			"label": "Nerds",
			"description": (
				"Students who connect through academics, interests, "
				+ "and school knowledge."
			),
			"requirements_text": "Smarts 65+"
		},
		{
			"clique_id": "normies",
			"label": "Normies",
			"description": (
				"The broad middle of school life without an extreme "
				+ "social or academic identity."
			),
			"requirements_text": "No special stat gate"
		},
		{
			"clique_id": "social_floaters",
			"label": "Social Floaters",
			"description": (
				"Students comfortable moving between different groups."
			),
			"requirements_text": (
				"Popularity 45+ • Friendliness 55+"
			)
		},
		{
			"clique_id": "brainy_kids",
			"label": "Brainy Kids",
			"description": (
				"The highest-performing academic crowd."
			),
			"requirements_text": "Smarts 80+"
		},
		{
			"clique_id": "loners",
			"label": "Loners",
			"description": (
				"Students who spend most of school outside the "
				+ "main social currents."
			),
			"requirements_text": (
				"Popularity 40 or lower OR Friendliness 40 or lower"
			)
		}
	]


func _school_clique_eligibility_contract(
	actor: Person,
	clique_id: String
) -> Dictionary:
	if actor == null:
		return {
			"eligible": false,
			"reason": "missing_actor"
		}

	var popularity: int = _school_popularity_score_for(
		actor
	)
	var friendliness: int = (
		_school_person_friendliness_score_for(
			actor
		)
	)
	var clean_clique: String = str(
		clique_id
	).strip_edges().to_lower()
	var eligible: bool = false

	match clean_clique:
		"popular_kids":
			eligible = (
				popularity >= 70
				and int(actor.looks) >= 70
			)

		"mean_girls":
			eligible = (
				str(actor.gender) == "Female"
			)

		"nerds":
			eligible = (
				int(actor.smarts) >= 65
			)

		"normies":
			eligible = true

		"social_floaters":
			eligible = (
				popularity >= 45
				and friendliness >= 55
			)

		"brainy_kids":
			eligible = (
				int(actor.smarts) >= 80
			)

		"loners":
			eligible = (
				popularity <= 40
				or friendliness <= 40
			)

		_:
			eligible = false

	return {
		"eligible": eligible,
		"clique_id": clean_clique,
		"popularity": popularity,
		"friendliness": friendliness,
		"looks": int(actor.looks),
		"smarts": int(actor.smarts),
		"gender": str(actor.gender),
	}


func _active_modern_future_high_school_context(
	actor: Person
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.era == null
		or str(gs.era.name) not in [
			"Modern Era",
			"Future Era"
		]
		or not enrollment.has(
			actor.id
		)
	):
		return {}

	var rec_raw: Variant = enrollment.get(
		actor.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		rec.is_empty()
		or str(
			rec.get(
				"status",
				""
			)
		) != "active"
	):
		return {}

	var era_data_raw: Variant = ERA_SCHOOLS.get(
		gs.era.name,
		{}
	)
	var era_data: Dictionary = (
		era_data_raw as Dictionary
		if typeof(era_data_raw) == TYPE_DICTIONARY
		else {}
	)
	var ages_raw: Variant = era_data.get(
		"ages",
		{}
	)
	var ages: Dictionary = (
		ages_raw as Dictionary
		if typeof(ages_raw) == TYPE_DICTIONARY
		else {}
	)
	var high_start: int = int(
		ages.get(
			"high_start",
			14
		)
	)
	var adult_start: int = int(
		ages.get(
			"adult_start",
			18
		)
	)

	if (
		int(actor.age) < high_start
		or int(actor.age) >= adult_start
	):
		return {}

	var mode: String = str(
		rec.get(
			"mode",
			""
		)
	)
	var school_name: String = ""

	if mode == "dual":
		school_name = str(
			rec.get(
				"era_school",
				""
			)
		).strip_edges()
		mode = "era_school"
	elif mode == "era_school":
		school_name = str(
			rec.get(
				"school_name",
				""
			)
		).strip_edges()
	else:
		return {}

	var high_schools_raw: Variant = era_data.get(
		"high",
		[]
	)
	var high_schools: Array = (
		high_schools_raw as Array
		if typeof(high_schools_raw) == TYPE_ARRAY
		else []
	)

	if school_name not in high_schools:
		return {}

	return {
		"actor_id": int(actor.id),
		"era_name": str(gs.era.name),
		"school_name": school_name,
		"school_mode": mode,
		"school_key": _school_key(
			school_name,
			mode
		)
	}


func _school_clique_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get(
		SCHOOL_CLIQUE_STATE_KEY,
		{}
	)

	if typeof(raw) != TYPE_DICTIONARY:
		gs.scenario_state [
			SCHOOL_CLIQUE_STATE_KEY
		] = {
			"schools": {},
			"memberships_by_actor": {}
		}

	var state: Dictionary = gs.scenario_state [
		SCHOOL_CLIQUE_STATE_KEY
	]

	if typeof(
		state.get(
			"schools",
			{}
		)
	) != TYPE_DICTIONARY:
		state [
			"schools"
		] = {}

	if typeof(
		state.get(
			"memberships_by_actor",
			{}
		)
	) != TYPE_DICTIONARY:
		state [
			"memberships_by_actor"
		] = {}

	return state
func _ensure_school_clique_population_for_actor(
	actor: Person
) -> void:
	var context: Dictionary = (
		_active_modern_future_high_school_context(
			actor
		)
	)

	if context.is_empty():
		return

	var school_key: String = str(
		context.get(
			"school_key",
			""
		)
	)

	if school_key == "":
		return

	var roster_raw: Variant = school_rosters.get(
		school_key,
		[]
	)
	var roster: Array = (
		roster_raw as Array
		if typeof(roster_raw) == TYPE_ARRAY
		else []
	)

	if roster.is_empty():
		return

	var state: Dictionary = _school_clique_state()
	var schools: Dictionary = state [
		"schools"
	]
	var memberships: Dictionary = state [
		"memberships_by_actor"
	]
	var school_state_raw: Variant = schools.get(
		school_key,
		{}
	)
	var school_state: Dictionary = (
		school_state_raw as Dictionary
		if typeof(school_state_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		int(
			school_state.get(
				"seeded_year",
				-999999
			)
		) == int(gs.year)
		and int(
			school_state.get(
				"seeded_roster_count",
				-1
			)
		) == roster.size()
	):
		return

	var members_raw: Variant = school_state.get(
		"members_by_clique",
		{}
	)
	var members_by_clique: Dictionary = (
		members_raw as Dictionary
		if typeof(members_raw) == TYPE_DICTIONARY
		else {}
	)
	var definitions: Array = _school_clique_definitions()

	for raw_definition in definitions:
		var definition: Dictionary = raw_definition
		var clique_id: String = str(
			definition.get(
				"clique_id",
				""
			)
		)

		if typeof(
			members_by_clique.get(
				clique_id,
				[]
			)
		) != TYPE_ARRAY:
			members_by_clique [
				clique_id
			] = []

		var old_members: Array = (
			members_by_clique [
				clique_id
			]
		)
		var clean_members: Array = []

		for raw_member_id in old_members:
			var member_id: int = int(
				raw_member_id
			)

			if member_id not in roster:
				continue

			var member: Person = (
				actor
				if member_id == int(actor.id)
				else gs.get_npc_by_id(
					member_id
				)
			)

			if (
				member == null
				or not member.alive
			):
				continue

			if member_id not in clean_members:
				clean_members.append(
					member_id
				)

		members_by_clique [
			clique_id
		] = clean_members

	var target_total: int = mini(
		roster.size(),
		definitions.size()
		* SCHOOL_CLIQUE_AUTO_MEMBERS_PER_CLIQUE
	)
	var assigned_total: int = 0

	for raw_definition in definitions:
		var definition: Dictionary = raw_definition
		var clique_id: String = str(
			definition.get(
				"clique_id",
				""
			)
		)
		var existing: Array = members_by_clique [
			clique_id
		]

		assigned_total += existing.size()

	for raw_student_id in roster:
		if assigned_total >= target_total:
			break

		var student_id: int = int(
			raw_student_id
		)

		if (
			student_id <= 0
			or student_id == int(actor.id)
		):
			continue

		var existing_membership_raw: Variant = (
			memberships.get(
				str(student_id),
				{}
			)
		)
		var existing_membership: Dictionary = (
			existing_membership_raw as Dictionary
			if typeof(existing_membership_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			not existing_membership.is_empty()
			and str(
				existing_membership.get(
					"school_key",
					""
				)
			) == school_key
		):
			continue

		var student: Person = gs.get_npc_by_id(
			student_id
		)

		if (
			student == null
			or not student.alive
		):
			continue

		var eligible_cliques: Array = []

		for raw_definition in definitions:
			var definition: Dictionary = raw_definition
			var clique_id: String = str(
				definition.get(
					"clique_id",
					""
				)
			)
			var member_ids: Array = members_by_clique [
				clique_id
			]

			if (
				member_ids.size()
				>= SCHOOL_CLIQUE_AUTO_MEMBERS_PER_CLIQUE
			):
				continue

			var eligibility: Dictionary = (
				_school_clique_eligibility_contract(
					student,
					clique_id
				)
			)

			if bool(
				eligibility.get(
					"eligible",
					false
				)
			):
				eligible_cliques.append(
					clique_id
				)

		if eligible_cliques.is_empty():
			continue

		var choice_material: String = (
			"%s:%d:%d"
			% [
				school_key,
				student_id,
				int(gs.year)
			]
		)
		var choice_index: int = (
			absi(
				int(
					choice_material.hash()
				)
			)
			% eligible_cliques.size()
		)
		var selected_clique: String = str(
			eligible_cliques [
				choice_index
			]
		)
		var selected_members: Array = (
			members_by_clique [
				selected_clique
			]
		)

		selected_members.append(
			student_id
		)
		members_by_clique [
			selected_clique
		] = selected_members

		memberships [
			str(student_id)
		] = {
			"actor_id": student_id,
			"school_key": school_key,
			"clique_id": selected_clique,
			"joined_year": int(gs.year),
		}

		assigned_total += 1

	var revision: String = (
		"%s:%d:%d:%d"
		% [
			school_key,
			int(gs.year),
			roster.size(),
			assigned_total
		]
	)

	school_state [
		"school_key"
	] = school_key
	school_state [
		"school_name"
	] = str(
		context.get(
			"school_name",
			""
		)
	)
	school_state [
		"seeded_year"
	] = int(
		gs.year
	)
	school_state [
		"seeded_roster_count"
	] = roster.size()
	school_state [
		"members_by_clique"
	] = members_by_clique
	school_state [
		"revision"
	] = revision

	schools [
		school_key
	] = school_state
	state [
		"schools"
	] = schools
	state [
		"memberships_by_actor"
	] = memberships
	gs.scenario_state [
		SCHOOL_CLIQUE_STATE_KEY
	] = state


func emit_school_clique_contract(
	actor: Person
) -> Dictionary:
	var school_context: Dictionary = (
		_active_modern_future_high_school_context(
			actor
		)
	)

	if school_context.is_empty():
		return {}

	var school_key: String = str(
		school_context.get(
			"school_key",
			""
		)
	)
	var state: Dictionary = _school_clique_state()
	var schools: Dictionary = state [
		"schools"
	]
	var memberships: Dictionary = state [
		"memberships_by_actor"
	]
	var school_state_raw: Variant = schools.get(
		school_key,
		{}
	)
	var school_state: Dictionary = (
		school_state_raw as Dictionary
		if typeof(school_state_raw) == TYPE_DICTIONARY
		else {}
	)
	var members_raw: Variant = school_state.get(
		"members_by_clique",
		{}
	)
	var members_by_clique: Dictionary = (
		members_raw as Dictionary
		if typeof(members_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_membership_raw: Variant = (
		memberships.get(
			str(
				int(
					actor.id
				)
			),
			{}
		)
	)
	var actor_membership: Dictionary = (
		actor_membership_raw as Dictionary
		if typeof(actor_membership_raw) == TYPE_DICTIONARY
		else {}
	)
	var current_clique_id: String = ""

	if str(
		actor_membership.get(
			"school_key",
			""
		)
	) == school_key:
		current_clique_id = str(
			actor_membership.get(
				"clique_id",
				""
			)
		)

	var clique_rows: Array = []

	for raw_definition in _school_clique_definitions():
		var definition: Dictionary = raw_definition
		var clique_id: String = str(
			definition.get(
				"clique_id",
				""
			)
		)
		var member_ids_raw: Variant = (
			members_by_clique.get(
				clique_id,
				[]
			)
		)
		var member_ids: Array = (
			member_ids_raw as Array
			if typeof(member_ids_raw) == TYPE_ARRAY
			else []
		)
		var member_cards: Array = []

		for raw_member_id in member_ids:
			if (
				member_cards.size()
				>= SCHOOL_CLIQUE_VISIBLE_MEMBER_LIMIT
			):
				break

			var member_id: int = int(
				raw_member_id
			)
			var member: Person = (
				actor
				if member_id == int(actor.id)
				else gs.get_npc_by_id(
					member_id
				)
			)

			if (
				member == null
				or not member.alive
			):
				continue

			member_cards.append(
				_school_runtime_person_row(
					member,
					"school_clique",
					(
						"member of %s"
						% str(
							definition.get(
								"label",
								"clique"
							)
						)
					)
				)
			)

		var eligibility: Dictionary = (
			_school_clique_eligibility_contract(
				actor,
				clique_id
			)
		)
		var joined: bool = (
			current_clique_id == clique_id
		)

		clique_rows.append({
			"clique_id": clique_id,
			"label": str(
				definition.get(
					"label",
					clique_id
				)
			),
			"description": str(
				definition.get(
					"description",
					""
				)
			),
			"requirements_text": str(
				definition.get(
					"requirements_text",
					""
				)
			),
			"eligibility_contract": eligibility,
			"eligible": bool(
				eligibility.get(
					"eligible",
					false
				)
			),
			"joined": joined,
			"member_cards": member_cards,
			"member_count": member_ids.size(),
			"ui_is_renderer_only": true
		})

	return {
		"schema": (
			"eralife.school_engine."
			+ "school_clique_surface_contract"
		),
		"version": SCHOOL_CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"era_name": str(
			school_context.get(
				"era_name",
				""
			)
		),
		"school_name": str(
			school_context.get(
				"school_name",
				""
			)
		),
		"school_key": school_key,
		"current_clique_id": current_clique_id,
		"cliques": clique_rows,
		"visible": true,
		"revision": str(
			school_state.get(
				"revision",
				(
					"cliques:%s:cold"
					% school_key
				)
			)
		),
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}


func resolve_school_clique_join(
	actor: Person,
	clique_id: String
) -> Dictionary:
	var school_context: Dictionary = (
		_active_modern_future_high_school_context(
			actor
		)
	)

	if school_context.is_empty():
		return {
			"success": false,
			"text": (
				"Cliques are only available while actively attending "
				+ "Modern or Future secondary school."
			)
		}

	var clean_clique_id: String = str(
		clique_id
	).strip_edges().to_lower()
	var known: bool = false
	var clique_label: String = clean_clique_id

	for raw_definition in _school_clique_definitions():
		var definition: Dictionary = raw_definition

		if str(
			definition.get(
				"clique_id",
				""
			)
		) != clean_clique_id:
			continue

		known = true
		clique_label = str(
			definition.get(
				"label",
				clean_clique_id
			)
		)
		break

	if not known:
		return {
			"success": false,
			"text": "That school clique does not exist."
		}

	var eligibility: Dictionary = (
		_school_clique_eligibility_contract(
			actor,
			clean_clique_id
		)
	)

	if not bool(
		eligibility.get(
			"eligible",
			false
		)
	):
		return {
			"success": false,
			"popup_title": "CLIQUE",
			"popup_text": (
				"You do not currently meet this clique's requirements."
			),
			"text": (
				"You could not join %s."
				% clique_label
			)
		}

	var school_key: String = str(
		school_context.get(
			"school_key",
			""
		)
	)
	var state: Dictionary = _school_clique_state()
	var schools: Dictionary = state [
		"schools"
	]
	var memberships: Dictionary = state [
		"memberships_by_actor"
	]
	var school_state_raw: Variant = schools.get(
		school_key,
		{}
	)
	var school_state: Dictionary = (
		school_state_raw as Dictionary
		if typeof(school_state_raw) == TYPE_DICTIONARY
		else {}
	)
	var members_raw: Variant = school_state.get(
		"members_by_clique",
		{}
	)
	var members_by_clique: Dictionary = (
		members_raw as Dictionary
		if typeof(members_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_key: String = str(
		int(
			actor.id
		)
	)
	var current_raw: Variant = memberships.get(
		actor_key,
		{}
	)
	var current: Dictionary = (
		current_raw as Dictionary
		if typeof(current_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		str(
			current.get(
				"school_key",
				""
			)
		) == school_key
		and str(
			current.get(
				"clique_id",
				""
			)
		) == clean_clique_id
	):
		return {
			"success": true,
			"text": (
				"You are already part of %s."
				% clique_label
			),
			"clique_id": clean_clique_id
		}


	if not current.is_empty():
		var old_school_key: String = str(
			current.get(
				"school_key",
				""
			)
		)
		var old_clique_id: String = str(
			current.get(
				"clique_id",
				""
			)
		)

		if schools.has(
			old_school_key
		):
			var old_school: Dictionary = schools [
				old_school_key
			]
			var old_members: Dictionary = old_school.get(
				"members_by_clique",
				{}
			)

			if typeof(
				old_members.get(
					old_clique_id,
					[]
				)
			) == TYPE_ARRAY:
				var old_ids: Array = old_members [
					old_clique_id
				]
				old_ids.erase(
					int(
						actor.id
					)
				)
				old_members [
					old_clique_id
				] = old_ids
				old_school [
					"members_by_clique"
				] = old_members
				schools [
					old_school_key
				] = old_school

	if typeof(
		members_by_clique.get(
			clean_clique_id,
			[]
		)
	) != TYPE_ARRAY:
		members_by_clique [
			clean_clique_id
		] = []

	var member_ids: Array = members_by_clique [
		clean_clique_id
	]
	var intro_member_ids: Array = []

	for raw_member_id in member_ids:
		var member_id: int = int(
			raw_member_id
		)

		if member_id == int(actor.id):
			continue

		if (
			intro_member_ids.size()
			< SCHOOL_CLIQUE_VISIBLE_MEMBER_LIMIT
		):
			intro_member_ids.append(
				member_id
			)

	if int(actor.id) not in member_ids:
		member_ids.append(
			int(
				actor.id
			)
		)

	members_by_clique [
		clean_clique_id
	] = member_ids
	school_state [
		"members_by_clique"
	] = members_by_clique
	school_state [
		"revision"
	] = (
		"%s:%d:%s:%d"
		% [
			school_key,
			int(gs.year),
			clean_clique_id,
			member_ids.size()
		]
	)
	schools [
		school_key
	] = school_state

	memberships [
		actor_key
	] = {
		"actor_id": int(
			actor.id
		),
		"school_key": school_key,
		"clique_id": clean_clique_id,
		"joined_year": int(
			gs.year
		),
	}

	state [
		"schools"
	] = schools
	state [
		"memberships_by_actor"
	] = memberships
	gs.scenario_state [
		SCHOOL_CLIQUE_STATE_KEY
	] = state

	_queue_school_clique_intro_bonds(
		int(
			actor.id
		),
		intro_member_ids
	)

	return {
		"success": true,
		"text": (
			"You joined %s."
			% clique_label
		),
		"popup_title": "CLIQUE JOINED",
		"popup_text": (
			"Your bond with students in %s will grow faster "
			+ "while you share the clique."
		) % clique_label,
		"clique_id": clean_clique_id,
		"intro_bonds_queued": intro_member_ids.size(),
	}


func relationship_bond_gain_contract(
	actor: Person,
	target: Person,
	base_amount: int
) -> Dictionary:
	var clean_amount: int = int(
		base_amount
	)

	if (
		actor == null
		or target == null
		or clean_amount <= 0
	):
		return {
			"base_amount": clean_amount,
			"adjusted_amount": clean_amount
		}

	var actor_context: Dictionary = (
		_active_modern_future_high_school_context(
			actor
		)
	)
	var target_context: Dictionary = (
		_active_modern_future_high_school_context(
			target
		)
	)

	if (
		actor_context.is_empty()
		or target_context.is_empty()
		or str(
			actor_context.get(
				"school_key",
				""
			)
		) != str(
			target_context.get(
				"school_key",
				""
			)
		)
	):
		return {
			"base_amount": clean_amount,
			"adjusted_amount": clean_amount
		}

	var state: Dictionary = _school_clique_state()
	var memberships: Dictionary = state [
		"memberships_by_actor"
	]
	var actor_membership_raw: Variant = (
		memberships.get(
			str(
				int(
					actor.id
				)
			),
			{}
		)
	)
	var target_membership_raw: Variant = (
		memberships.get(
			str(
				int(
					target.id
				)
			),
			{}
		)
	)
	var actor_membership: Dictionary = (
		actor_membership_raw as Dictionary
		if typeof(actor_membership_raw) == TYPE_DICTIONARY
		else {}
	)
	var target_membership: Dictionary = (
		target_membership_raw as Dictionary
		if typeof(target_membership_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_clique: String = str(
		actor_membership.get(
			"clique_id",
			""
		)
	)
	var target_clique: String = str(
		target_membership.get(
			"clique_id",
			""
		)
	)
	var same_clique: bool = (
		actor_clique != ""
		and actor_clique == target_clique
		and str(
			actor_membership.get(
				"school_key",
				""
			)
		) == str(
			target_membership.get(
				"school_key",
				""
			)
		)
	)

	if not same_clique:
		return {
			"base_amount": clean_amount,
			"adjusted_amount": clean_amount
		}

	var adjusted_amount: int = maxi(
		clean_amount + 1,
		int(
			round(
				float(clean_amount)
				* SCHOOL_CLIQUE_INTERACTION_MULTIPLIER
			)
		)
	)

	return {
		"clique_id": actor_clique,
		"base_amount": clean_amount,
		"adjusted_amount": adjusted_amount,
		"multiplier": SCHOOL_CLIQUE_INTERACTION_MULTIPLIER,
	}
func _queue_school_clique_intro_bonds(
	actor_id: int,
	member_ids: Array
) -> void:
	if actor_id <= 0:
		return

	for raw_member_id in member_ids:
		var member_id: int = int(
			raw_member_id
		)

		if (
			member_id <= 0
			or member_id == actor_id
		):
			continue

		school_clique_intro_bond_queue.append({
			"actor_id": actor_id,
			"target_id": member_id,
			"amount": SCHOOL_CLIQUE_JOIN_BOND_BONUS
		})

	_arm_school_clique_intro_bond_service()


func _arm_school_clique_intro_bond_service() -> void:
	if (
		school_clique_intro_bond_service_active
		or school_clique_intro_bond_queue.is_empty()
	):
		return

	school_clique_intro_bond_service_active = true

	var tree: SceneTree = (
		Engine.get_main_loop()
		as SceneTree
	)

	if tree == null:
		call_deferred(
			"_service_school_clique_intro_bond_quantum"
		)
		return

	var timer: SceneTreeTimer = tree.create_timer(
		0.002
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_school_clique_intro_bond_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _service_school_clique_intro_bond_quantum() -> void:
	school_clique_intro_bond_service_active = false

	if (
		school_clique_intro_bond_queue.is_empty()
		or gs == null
	):
		return

	var row_raw: Variant = (
		school_clique_intro_bond_queue.pop_front()
	)
	var row: Dictionary = (
		row_raw as Dictionary
		if typeof(row_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_id: int = int(
		row.get(
			"actor_id",
			-1
		)
	)
	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)
	var actor: Person = (
		gs.player
		if (
			gs.player != null
			and int(gs.player.id) == actor_id
		)
		else gs.get_npc_by_id(
			actor_id
		)
	)
	var target: Person = (
		gs.player
		if (
			gs.player != null
			and int(gs.player.id) == target_id
		)
		else gs.get_npc_by_id(
			target_id
		)
	)

	if (
		actor != null
		and target != null
		and actor.alive
		and target.alive
		and gs.relationship_activities_engine != null
		and gs.relationship_activities_engine.has_method(
			"apply_school_clique_intro_bond"
		)
	):
		gs.relationship_activities_engine.apply_school_clique_intro_bond(
			actor,
			target,
			int(
				row.get(
					"amount",
					SCHOOL_CLIQUE_JOIN_BOND_BONUS
				)
			)
		)

	_arm_school_clique_intro_bond_service()
func _college_classes_for_major(major: String) -> Array:
	match str(major):
		"Finance":
			return ["Corporate Finance", "Markets", "Risk Modeling", "Business Ethics"]
		"Psychology":
			return ["Intro Psychology", "Developmental Psychology", "Research Methods", "Abnormal Psychology"]
		"Criminal Justice":
			return ["Criminal Law", "Investigations", "Courts And Corrections", "Forensics"]
		"Information Systems":
			return ["Database Systems", "Systems Analysis", "Cybersecurity", "Business Analytics"]
		"Economics":
			return ["Microeconomics", "Macroeconomics", "Econometrics", "Public Policy"]
		"How To Get Away With Murder Law 101":
			return ["Legal Theater", "Evidence", "Trial Strategy", "Ethics Before The Plot Twist"]
		"Political Science":
			return ["Political Theory", "Constitutional Systems", "Campaigns", "International Relations"]
		"Biology":
			return ["Cell Biology", "Anatomy", "Chemistry Lab", "Genetics"]
		"Accounting":
			return ["Financial Accounting", "Auditing", "Taxation", "Cost Accounting"]
		_:
			return ["Core Seminar", "Writing", "Research Methods", "Elective"]


func _seed_postsecondary_record_if_needed(person: Person, rec: Dictionary) -> void:
	if person == null:
		return

	var mode: String = str(rec.get("mode", "")).strip_edges()
	if mode not in ["college_major", "graduate_school"]:
		return

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	if record.is_empty():
		record = {
			"completed_college_majors": [],
			"major_scores": {},
			"graduate_schools": [],
			"last_updated_year": int(gs.year)
		}

	if mode == "college_major":
		var major: String = str(rec.get("major", "")).strip_edges()
		if major != "" and not _safe_dictionary(record.get("major_scores", {})).has(major):
			var scores: Dictionary = _safe_dictionary(record.get("major_scores", {}))
			scores [major] = _college_performance_score(person)
			record ["major_scores"] = scores

	if mode == "graduate_school":
		var grad: String = str(rec.get("graduate_school", rec.get("school_name", ""))).strip_edges()
		var grad_rows: Array = _safe_array(record.get("graduate_schools", []))
		if grad != "" and grad not in grad_rows:
			grad_rows.append(grad)
		record ["graduate_schools"] = grad_rows

	record ["last_updated_year"] = int(gs.year)
	school_academic_records [key] = record


func _college_performance_score(person: Person) -> int:
	if person == null:
		return 0
	return clamp(int(round((float(person.smarts) * 0.62) + (float(person.mental_health) * 0.18) + (float(person.satisfaction) * 0.2))), 0, 100)


func _completed_college_major_for(person: Person, required_major: String) -> bool:
	if person == null:
		return false

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	var completed: Array = _safe_array(record.get("completed_college_majors", []))
	if str(required_major).strip_edges() in completed:
		return true

	var active: Dictionary = _safe_dictionary(enrollment.get(person.id, {}))
	if str(active.get("mode", "")) == "college_major" and str(active.get("major", "")).strip_edges() == str(required_major).strip_edges():
		return int(active.get("years_attended", 0)) >= 4

	return false


func _qualifies_for_grad_scholarship(
	person: Person,
	graduate_school: String
) -> bool:
	var required_majors: Array = (
		_graduate_school_required_majors(
			graduate_school
		)
	)

	for raw_major in required_majors:
		var major: String = str(
			raw_major
		).strip_edges()

		if not _completed_college_major_for(
			person,
			major
		):
			continue

		if _college_score_for_major(
			person,
			major
		) >= 85:
			return true

	return false
func emit_career_education_contract(
	person: Person,
	context: Dictionary = {}
) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"schema": (
				"eralife.career_education_contract"
			),
			"reason": "missing_person"
		}

	var key: String = str(
		int(person.id)
	)
	var record: Dictionary = _safe_dictionary(
		school_academic_records.get(
			key,
			{}
		)
	)
	var active: Dictionary = _safe_dictionary(
		enrollment.get(
			person.id,
			{}
		)
	)
	var completed_majors: Array = _safe_array(
		record.get(
			"completed_college_majors",
			[]
		)
	)
	var graduate_schools: Array = _safe_array(
		record.get(
			"graduate_schools",
			[]
		)
	)
	var historical_programs: Array = _safe_array(
		record.get(
			"historical_programs",
			[]
		)
	)

	for candidate in [
		str(
			active.get(
				"school_name",
				""
			)
		),
		str(person.school_name)
	]:
		var clean_candidate: String = str(
			candidate
		).strip_edges()

		if clean_candidate == "":
			continue
		if clean_candidate.begins_with(
			"College:"
		):
			continue
		if clean_candidate in graduate_schools:
			continue
		if clean_candidate not in historical_programs:
			historical_programs.append(
				clean_candidate
			)

	var active_major: String = ""
	var active_program: String = ""

	match str(
		active.get(
			"mode",
			""
		)
	):
		"college_major":
			active_major = str(
				active.get(
					"major",
					""
				)
			)

		"graduate_school":
			active_program = str(
				active.get(
					"graduate_school",
					active.get(
						"school_name",
						""
					)
				)
			)

	return {
		"success": true,
		"schema": (
			"eralife.career_education_contract"
		),
		"version": 1,
		"actor_id": int(person.id),
		"era_name": str(gs.era.name),
		"active_major": active_major,
		"active_program": active_program,
		"completed_majors": completed_majors,
		"graduate_schools": graduate_schools,
		"historical_programs": historical_programs,
		"available_majors": (
			_college_majors_for_era(
				str(gs.era.name)
			)
		),
		"graduate_school_options": (
			_graduate_school_options_for_person(
				person
			)
		),
		"college_performance_score": (
			_college_performance_score(
				person
			)
		),
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}
func _graduate_school_required_majors(
	graduate_school: String
) -> Array:
	var clean: String = str(
		graduate_school
	).strip_edges()

	for raw_definition in _graduate_school_definitions():
		var definition: Dictionary = (
			_safe_dictionary(
				raw_definition
			)
		)

		if str(
			definition.get(
				"name",
				""
			)
		).strip_edges() != clean:
			continue

		return _safe_array(
			definition.get(
				"required_majors_any",
				[
					str(
						definition.get(
							"required_major",
							""
						)
					)
				]
			)
		)

	return []
func _college_score_for_major(person: Person, major: String) -> int:
	if person == null:
		return 0

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	var scores: Dictionary = _safe_dictionary(record.get("major_scores", {}))
	if scores.has(major):
		return int(scores.get(major, 0))

	return _college_performance_score(person)


func get_postsecondary_lane_snapshot(person: Person) -> Dictionary:
	var out: Dictionary = {
		"record": {},
		"active_major": "",
		"college_performance_score": 0,
		"graduate_school_options": []
	}
	if person == null:
		return out

	var key: String = str(int(person.id))
	var record: Dictionary = _safe_dictionary(school_academic_records.get(key, {}))
	var active: Dictionary = _safe_dictionary(enrollment.get(person.id, {}))

	out ["record"] = record
	out ["college_performance_score"] = _college_performance_score(person)

	if str(active.get("mode", "")) == "college_major":
		out ["active_major"] = str(active.get("major", ""))

	if _safe_array(record.get("completed_college_majors", [])).is_empty() and str(out.get("active_major", "")) == "":
		out ["graduate_school_options"] = []
	else:
		out ["graduate_school_options"] = _graduate_school_options_for_person(person)

	return out


func _parent_school_enrollment_scenario(
	player: Person,
	context: Dictionary
) -> Dictionary:
	if player == null:
		return {}

	for raw_child_id in player.children:
		var child: Person = (
			gs.get_or_reactivate_npc_by_id(
				int(
					raw_child_id
				)
			)
		)

		if (
			child == null
			or not child.alive
			or not _needs_school_enrollment_choice(
				child
			)
		):
			continue

		var transition: Dictionary = (
			_next_minor_school_transition_for(
				child
			)
		)
		var planning_stage: String = str(
			transition.get(
				"stage_key",
				""
			)
		)
		var choices: Array = (
			_school_enrollment_choices_for(
				player,
				child,
				"parent_player",
				planning_stage
			)
		)

		if choices.is_empty():
			continue

		return {
			"id": (
				"parent_school_enrollment_%d_%s_%d"
				% [
					int(
						child.id
					),
					planning_stage,
					int(
						context.get(
							"year",
							0
						)
					)
				]
			),
			"category": "school",
			"source": "school_engine",
			"resolver_owner": "school_engine",
			"resolver_method": "resolve_school_enrollment_choice",
			"school_target_id": int(
				child.id
			),
			"school_requester_role": "parent_player",
			"school_stage_key": planning_stage,
			"school_stage_start_age": int(
				transition.get(
					"start_age",
					-1
				)
			),
			"school_request_kind": "custodial_stage_plan",
			"era_tags": ["any"],
			"reality_modes": [
				"realistic",
				"enhanced",
				"chaos"
			],
			"reality_weights": {
				"realistic": 1.25,
				"enhanced": 1.0,
				"chaos": 0.9
			},
			"tone": "family",
			"rarity": 1.0,
			"cooldown_key": (
				"school:parent_stage_plan:%d:%s"
				% [
					int(
						child.id
					),
					planning_stage
				]
			),
			"cooldown_years": 1,
			"priority": 36,
			"min_age": 18,
			"max_age": 130,
			"prompt": (
				"%s will enter %s next year. "
				+ "What schooling will I plan for them?"
			) % [
				child.first_name,
				_school_stage_display_name(
					planning_stage
				)
			],
			"followup_hooks": [
				"school.parent.enrollment"
			],
			"bias_payloads": {},
			"choices": choices
		}

	return {}
func resolve_school_enrollment_choice(
	actor: Person,
	scenario: Dictionary,
	choice: Dictionary,
	_committed: Dictionary
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"text": (
				"No actor could resolve the schooling choice."
			)
		}

	var target_id: int = int(
		choice.get(
			"school_target_id",
			scenario.get(
				"school_target_id",
				actor.id
			)
		)
	)
	var target: Person = actor

	if (
		target_id > 0
		and target_id != int(
			actor.id
		)
	):
		target = gs.get_or_reactivate_npc_by_id(
			target_id
		)

	if target == null:
		return {
			"success": false,
			"text": (
				"The schooling target could not be found."
			)
		}

	var request_kind: String = str(
		choice.get(
			"school_request_kind",
			scenario.get(
				"school_request_kind",
				"direct"
			)
		)
	).strip_edges()
	var requester_role: String = str(
		scenario.get(
			"school_requester_role",
			""
		)
	).strip_edges()
	var school_name: String = str(
		choice.get(
			"school_name",
			""
		)
	).strip_edges()
	var mode: String = str(
		choice.get(
			"school_mode",
			"era_school"
		)
	).strip_edges()
	var stage_key: String = str(
		choice.get(
			"school_stage_key",
			scenario.get(
				"school_stage_key",
				""
			)
		)
	).strip_edges().to_lower()

	if request_kind in [
		"stage_preference",
		"stage_family_decides",
		"custodial_stage_plan",
		"custodial_stage_family_decides"
	]:
		var planning_result: Dictionary = (
			_author_minor_school_stage_plan(
				actor,
				target,
				stage_key,
				school_name,
				mode,
				requester_role,
				request_kind
			)
		)
		var planning_text: String = str(
			planning_result.get(
				"text",
				""
			)
		).strip_edges()

		return {
			"success": bool(
				planning_result.get(
					"success",
					false
				)
			),
			"type": "scenario_commit_complete",
			"text": planning_text,
			"popup_title": "Schooling Plan",
			"popup_text": planning_text,
			"popup_footer": (
				"Tap anywhere to continue."
			),
			"school_result": (
				planning_result.duplicate(
					true
				)
			),
		}


	if (
		_is_minor_school_actor(
			target
		)
		and requester_role == "child_player"
	):
		var current_stage: String = (
			_school_stage_key_for_person(
				target
			)
		)

		if current_stage == "":
			return {
				"success": false,
				"text": (
					"No current minor school stage could be resolved."
				)
			}

		var legacy_plan: Dictionary = (
			_author_minor_school_stage_plan(
				actor,
				target,
				current_stage,
				school_name,
				mode,
				requester_role,
				"legacy_child_preference"
			)
		)
		var legacy_text: String = str(
			legacy_plan.get(
				"text",
				""
			)
		)

		return {
			"success": bool(
				legacy_plan.get(
					"success",
					false
				)
			),
			"type": "scenario_commit_complete",
			"text": legacy_text,
			"popup_title": "Schooling Plan",
			"popup_text": legacy_text,
			"popup_footer": "Tap anywhere to continue.",
			"school_result": legacy_plan,
		}

	if (
		request_kind == "family_decides"
		or school_name == ""
	):
		school_name = get_default_school_for(
			target
		)
		mode = "era_school"

	if school_name == "":
		return {
			"success": false,
			"text": (
				"%s could not be enrolled because no "
				+ "era-appropriate school was available."
			) % target.first_name,
			"popup_title": "Schooling Unavailable",
			"popup_text": (
				"%s could not be enrolled because no "
				+ "era-appropriate school was available."
			) % target.first_name,
			"popup_footer": "Tap anywhere to continue."
		}

	var result: Dictionary = (
		enroll_by_contract_choice(
			target,
			school_name,
			mode,
			{
				"custodial_authority_confirmed": (
					requester_role
					== "parent_player"
				),
				"source": (
					"school_engine."
					+ "legacy_enrollment_scenario"
				)
			}
		)
	)
	var final_text: String = (
		"%s entered %s."
		% [
			target.first_name,
			school_name
		]
	)

	if (
		bool(
			result.get(
				"success",
				false
			)
		)
		and final_text != ""
		and gs.narrative_engine != null
	):
		gs.narrative_engine.log_event(
			target,
			{
				"type": "text",
				"text": final_text,
				"source": (
					"school_engine."
					+ "enrollment_choice"
				),
				"category": "school"
			}
		)

	return {
		"success": bool(
			result.get(
				"success",
				false
			)
		),
		"type": "scenario_commit_complete",
		"text": (
			final_text
			if final_text != ""
			else str(
				result.get(
					"text",
					""
				)
			)
		),
		"popup_title": "Schooling Path",
		"popup_text": (
			final_text
			if final_text != ""
			else str(
				result.get(
					"text",
					""
				)
			)
		),
		"popup_footer": "Tap anywhere to continue.",
		"school_result": result
	}
func _ensure_minor_school_stage_plan_for_simulation(
	person: Person,
	stage_key: String
) -> Dictionary:
	var existing_plan: Dictionary = (
		_minor_school_stage_plan_for(
			person,
			stage_key
		)
	)

	if not existing_plan.is_empty():
		return existing_plan

	var custodian: Person = (
		_school_custodial_adult_for(
			person
		)
	)



	if (
		custodian != null
		and gs.player != null
		and int(
			custodian.id
		) == int(
			gs.player.id
		)
		and int(
			person.id
		) != int(
			gs.player.id
		)
	):
		return {}

	var planning_report: Dictionary = (
		_author_minor_school_stage_plan(
			custodian,
			person,
			stage_key,
			"",
			"era_school",
			"simulation_custodian",
			"simulation_family_decides"
		)
	)

	if not bool(
		planning_report.get(
			"success",
			false
		)
	):
		return {}

	return _safe_dictionary(
		planning_report.get(
			"plan",
			{}
		)
	)


func _commit_minor_school_stage_entry_if_due(
	person: Person,
	source: String
) -> Dictionary:
	if (
		person == null
		or not person.alive
		or not _is_minor_school_actor(
			person
		)
		or not _education_rights_allow_person(
			person
		)
	):
		return {
			"success": false,
			"committed": false,
			"reason": "minor_school_stage_not_applicable"
		}

	var stage_key: String = (
		_school_stage_key_for_person(
			person
		)
	)

	if stage_key == "":
		return {
			"success": false,
			"committed": false,
			"reason": "minor_school_stage_not_started"
		}

	var start_age: int = (
		_school_stage_start_age(
			str(
				gs.era.name
			),
			stage_key
		)
	)

	if (
		start_age < 0
		or int(
			person.age
		) < start_age
	):
		return {
			"success": false,
			"committed": false,
			"reason": "minor_school_stage_not_due"
		}

	if enrollment.has(
		person.id
	):
		_sync_era_school_stage(
			person
		)

		return {
			"success": true,
			"committed": false,
			"mode": "existing_enrollment_stage_synchronized",
			"stage_key": stage_key
		}

	var plan: Dictionary = (
		_ensure_minor_school_stage_plan_for_simulation(
			person,
			stage_key
		)
	)

	if plan.is_empty():
		return {
			"success": false,
			"committed": false,
			"reason": "custodial_decision_required",
			"stage_key": stage_key
		}

	var school_name: String = str(
		plan.get(
			"decided_school",
			""
		)
	).strip_edges()
	var mode: String = str(
		plan.get(
			"decided_mode",
			"era_school"
		)
	).strip_edges()

	if school_name == "":
		return {
			"success": false,
			"committed": false,
			"reason": "planned_school_missing"
		}

	var result: Dictionary = _enroll(
		person,
		school_name,
		mode
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		_mark_minor_school_stage_plan_committed(
			person,
			stage_key,
			school_name
		)

	result ["stage_key"] = stage_key
	result ["source"] = source
	result ["custodial_plan_applied"] = true

	return result

func _parent_accepts_school_request(
	child: Person,
	school_name: String,
	mode: String
) -> bool:
	if child == null:
		return false

	var custodian: Person = (
		_school_custodial_adult_for(
			child
		)
	)
	var chance: int = 54
	var tuition: float = (
		_school_tuition_for_option(
			school_name,
			mode,
			child
		)
	)
	var lower_school_name: String = (
		str(
			school_name
		).to_lower()
	)

	if lower_school_name.contains(
		"public"
	):
		chance += 18

	if tuition <= 0.0:
		chance += 10

	if mode == "bending_school":
		chance -= 8

	if custodian != null:
		var available_wealth: float = maxf(
			0.0,
			float(
				custodian.bank_balance
			)
		)
		var custodian_class: String = str(
			custodian.social_class
		).strip_edges().to_lower()

		if tuition > 0.0:
			if available_wealth >= tuition * 10.0:
				chance += 24
			elif available_wealth >= tuition * 4.0:
				chance += 14
			elif available_wealth >= tuition * 2.0:
				chance += 5
			elif available_wealth < tuition:
				chance -= 42
			else:
				chance -= 14

		if custodian_class in [
			"royal",
			"noble"
		]:
			if (
				lower_school_name.contains(
					"private"
				)
				or lower_school_name.contains(
					"boarding"
				)
			):
				chance += 14

		elif (
			custodian_class.contains(
				"upper"
			)
			or custodian_class.contains(
				"wealth"
			)
		):
			if (
				lower_school_name.contains(
					"private"
				)
				or lower_school_name.contains(
					"boarding"
				)
			):
				chance += 8

	if child.is_royal:
		chance += 8

	if int(
		child.smarts
	) >= 70:
		chance += 7

	var stage_key: String = (
		_school_stage_key_for_person(
			child
		)
	)
	var roll_seed: int = _stable_school_seed(
		"%d|%d|%s|%s|%s|%d|custodial_acceptance"
		% [
			int(
				child.id
			),
			int(
				custodian.id
			)
			if custodian != null
			else -1,
			school_name,
			mode,
			stage_key,
			int(
				gs.year
			)
		]
	)

	return int(
		roll_seed % 100
	) < clampi(
		chance,
		8,
		95
	)
func _minor_school_stage_plan_registry() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	return _safe_dictionary(
		gs.scenario_state.get(
			SCHOOL_MINOR_STAGE_PLAN_STATE_KEY,
			{}
		)
	)


func _minor_school_stage_plan_for(
	child: Person,
	stage_key: String
) -> Dictionary:
	if child == null:
		return {}

	var registry: Dictionary = (
		_minor_school_stage_plan_registry()
	)
	var child_plans: Dictionary = _safe_dictionary(
		registry.get(
			str(
				int(
					child.id
				)
			),
			{}
		)
	)

	return _safe_dictionary(
		child_plans.get(
			str(
				stage_key
			).strip_edges().to_lower(),
			{}
		)
	)


func _store_minor_school_stage_plan(
	child: Person,
	stage_key: String,
	plan: Dictionary
) -> void:
	if (
		child == null
		or gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return

	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	if clean_stage == "":
		return

	var registry: Dictionary = (
		_minor_school_stage_plan_registry()
	)
	var child_key: String = str(
		int(
			child.id
		)
	)
	var child_plans: Dictionary = _safe_dictionary(
		registry.get(
			child_key,
			{}
		)
	)

	child_plans [
		clean_stage
	] = plan.duplicate(true)

	registry [
		child_key
	] = child_plans

	gs.scenario_state [
		SCHOOL_MINOR_STAGE_PLAN_STATE_KEY
	] = registry


func _school_option_available_for_stage(
	person: Person,
	school_name: String,
	mode: String,
	stage_key: String
) -> bool:
	for raw_option in get_school_options_for_stage(
		person,
		stage_key
	):
		var option: Dictionary = _safe_dictionary(
			raw_option
		)

		if (
			str(
				option.get(
					"name",
					""
				)
			).strip_edges() == str(
				school_name
			).strip_edges()
			and str(
				option.get(
					"type",
					""
				)
			).strip_edges() == str(
				mode
			).strip_edges()
		):
			return true

	return false


func _author_minor_school_stage_plan(
	actor: Person,
	child: Person,
	stage_key: String,
	requested_school_name: String,
	requested_mode: String,
	requester_role: String,
	request_kind: String
) -> Dictionary:
	if (
		child == null
		or gs == null
	):
		return {
			"success": false,
			"reason": "missing_school_planning_context"
		}

	var clean_stage: String = str(
		stage_key
	).strip_edges().to_lower()

	if clean_stage == "":
		return {
			"success": false,
			"reason": "missing_school_stage"
		}

	var stage_start_age: int = (
		_school_stage_start_age(
			str(
				gs.era.name
			),
			clean_stage
		)
	)

	if stage_start_age < 0:
		return {
			"success": false,
			"reason": "school_stage_has_no_start_age"
		}

	var requested_school: String = str(
		requested_school_name
	).strip_edges()
	var requested_school_mode: String = str(
		requested_mode
	).strip_edges()

	if requested_school_mode == "":
		requested_school_mode = "era_school"

	if (
		requested_school != ""
		and not _school_option_available_for_stage(
			child,
			requested_school,
			requested_school_mode,
			clean_stage
		)
	):
		return {
			"success": false,
			"reason": "requested_school_not_available_for_stage"
		}

	var custodian: Person = (
		_school_custodial_adult_for(
			child
		)
	)
	var default_option: Dictionary = (
		_custodial_default_school_for_stage(
			child,
			clean_stage
		)
	)

	if default_option.is_empty():
		return {
			"success": false,
			"reason": "no_canonical_school_option_for_stage"
		}

	var decided_school: String = str(
		default_option.get(
			"name",
			""
		)
	).strip_edges()
	var decided_mode: String = str(
		default_option.get(
			"type",
			"era_school"
		)
	).strip_edges()
	var listened_to_child: bool = false
	var controlled_custodian_decision: bool = (
		requester_role == "parent_player"
		and actor != null
		and _school_person_is_child_of(
			actor,
			child
		)
	)

	if (
		controlled_custodian_decision
		and requested_school != ""
	):
		decided_school = requested_school
		decided_mode = requested_school_mode
	elif requested_school != "":
		listened_to_child = (
			_parent_accepts_school_request(
				child,
				requested_school,
				requested_school_mode
			)
		)

		if listened_to_child:
			decided_school = requested_school
			decided_mode = requested_school_mode

	var plan: Dictionary = {
		"schema": (
			SCHOOL_CONTRACT_SCHEMA
			+ ".minor_stage_plan"
		),
		"version": SCHOOL_CONTRACT_VERSION,
		"child_id": int(
			child.id
		),
		"stage_key": clean_stage,
		"stage_display": (
			_school_stage_display_name(
				clean_stage
			)
		),
		"stage_start_age": stage_start_age,
		"requested_school": requested_school,
		"requested_mode": requested_school_mode,
		"request_kind": request_kind,
		"requester_role": requester_role,
		"requester_actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"custodian_id": (
			int(
				custodian.id
			)
			if custodian != null
			else -1
		),
		"custodian_social_class": (
			str(
				custodian.social_class
			)
			if custodian != null
			else ""
		),
		"decided_school": decided_school,
		"decided_mode": decided_mode,
		"listened_to_child": listened_to_child,
		"controlled_custodian_decision": (
			controlled_custodian_decision
		),
		"decision_year": int(
			gs.year
		),
		"status": "planned",
		"enrollment_committed": false
	}

	_store_minor_school_stage_plan(
		child,
		clean_stage,
		plan
	)

	var text: String = ""

	if controlled_custodian_decision:
		text = (
			"I decided that %s will attend %s for %s."
			% [
				child.first_name,
				decided_school,
				_school_stage_display_name(
					clean_stage
				)
			]
		)
	elif requested_school == "":
		text = (
			"My parent or guardian decided on %s for my %s education."
			% [
				decided_school,
				_school_stage_display_name(
					clean_stage
				)
			]
		)
	elif listened_to_child:
		text = (
			"My parent or guardian listened to me. "
			+ "They plan to send me to %s for %s."
		) % [
			decided_school,
			_school_stage_display_name(
				clean_stage
			)
		]
	else:
		text = (
			"My parent or guardian heard my request for %s, "
			+ "but decided on %s instead."
		) % [
			requested_school,
			decided_school
		]

	return {
		"success": true,
		"mode": "minor_school_stage_plan_authored",
		"plan": plan.duplicate(true),
		"text": text,
		"enrollment_committed": false,
		"ui_is_renderer_only": false
	}


func _mark_minor_school_stage_plan_committed(
	child: Person,
	stage_key: String,
	school_name: String
) -> void:
	var plan: Dictionary = (
		_minor_school_stage_plan_for(
			child,
			stage_key
		)
	)

	if plan.is_empty():
		return

	plan ["status"] = "committed"
	plan ["enrollment_committed"] = true
	plan ["committed_school"] = school_name
	plan ["committed_year"] = int(
		gs.year
	)

	_store_minor_school_stage_plan(
		child,
		stage_key,
		plan
	)


func enroll_by_contract_choice(
	person: Person,
	school_name: String,
	mode: String,
	context: Dictionary = {}
) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"text": (
				"No person was supplied for school enrollment."
			)
		}

	var clean_mode: String = str(
		mode
	).strip_edges()
	var clean_school: String = str(
		school_name
	).strip_edges()
	var custodial_authority_confirmed: bool = bool(
		context.get(
			"custodial_authority_confirmed",
			false
		)
	)
	var simulation_authority_confirmed: bool = bool(
		context.get(
			"simulation_authority_confirmed",
			false
		)
	)

	if (
		_is_minor_school_actor(
			person
		)
		and clean_mode in [
			"era_school",
			"bending_school",
			"dual_enrollment"
		]
		and not custodial_authority_confirmed
		and not simulation_authority_confirmed
	):
		return {
			"success": false,
			"reason": "minor_direct_enrollment_forbidden",
			"text": (
				"My parent or guardian has authority "
				+ "over this school enrollment."
			),
		}

	match clean_mode:
		"dual_enrollment":
			return enroll_dual(
				person
			)

		"bending_school":
			if clean_school == "":
				return enroll_in_bending_school(
					person
				)

			if person.bending_type == "none":
				return {
					"success": false,
					"text": "I am not a bender."
				}

			return _enroll(
				person,
				clean_school,
				"bending_school"
			)

		"college_major":
			if gs.era.name != "Modern Era":
				return {
					"success": false,
					"text": (
						"College majors are not available in this era."
					)
				}

			if int(
				person.age
			) < 18:
				return {
					"success": false,
					"text": (
						"I am not old enough to choose "
						+ "a college major yet."
					)
				}

			if clean_school == "":
				return {
					"success": false,
					"text": "No college major was selected."
				}

			return _enroll(
				person,
				clean_school,
				"college_major"
			)

		"graduate_school":
			if gs.era.name != "Modern Era":
				return {
					"success": false,
					"text": (
						"Graduate school is not available in this era."
					)
				}

			if int(
				person.age
			) < 22:
				return {
					"success": false,
					"text": (
						"I am not old enough for graduate school yet."
					)
				}

			if clean_school == "":
				return {
					"success": false,
					"text": (
						"No graduate school was selected."
					)
				}

			return _enroll(
				person,
				clean_school,
				"graduate_school"
			)

		"era_school":
			if not can_attend_school(
				person
			):
				return {
					"success": false,
					"text": (
						"I am not permitted to attend "
						+ "school in this era."
					)
				}

			if clean_school == "":
				clean_school = get_default_school_for(
					person
				)

			if clean_school == "":
				return {
					"success": false,
					"text": (
						"There is no suitable era school "
						+ "for my age."
					)
				}

			return _enroll(
				person,
				clean_school,
				"era_school"
			)

		_:
			return {
				"success": false,
				"text": (
					"Unknown school enrollment mode: %s"
					% clean_mode
				)
			}


func ensure_family_school_reality_for(anchor: Person) -> void:
	if anchor == null or gs == null:
		return

	var candidates: Array = _collect_family_school_candidates(anchor)
	for npc in candidates:
		if npc == null:
			continue
		if not npc.alive:
			continue
		if int(npc.age) >= int(ERA_SCHOOLS.get(gs.era.name, {}).get("ages", {}).get("adult_start", 18)):
			continue
		if int(npc.age) < _get_school_start_age():
			continue
		if not can_attend_school(npc):
			sync_person_school_fields(npc)
			continue

		if gs.player != null and int(anchor.id) == int(gs.player.id) and int(npc.id) in anchor.children:
			if enrollment.has(npc.id):
				_ensure_school_contract_for_enrollment(npc)
				sync_person_school_fields(npc)
			continue

		if not enrollment.has(npc.id):
			_auto_assign_school(npc)
		else:
			_ensure_school_contract_for_enrollment(npc)

		sync_person_school_fields(npc)

func _collect_family_school_candidates(anchor: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if anchor == null:
		return out

	for raw_parent_id in anchor.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue
		for raw_sibling_id in parent.children:
			var sibling_id: int = int(raw_sibling_id)
			if sibling_id == int(anchor.id):
				continue
			if seen.has(sibling_id):
				continue
			var sibling: Person = gs.get_or_reactivate_npc_by_id(sibling_id)
			if sibling == null:
				continue
			seen [sibling_id] = true
			out.append(sibling)

	for raw_child_id in anchor.children:
		var child_id: int = int(raw_child_id)
		if seen.has(child_id):
			continue
		var child: Person = gs.get_or_reactivate_npc_by_id(child_id)
		if child == null:
			continue
		seen [child_id] = true
		out.append(child)

	return out
func get_teachers_for(person: Person) -> Array:
	if person == null:
		return []
	if not enrollment.has(person.id):
		return []

	var rec_raw: Variant = enrollment.get(
		person.id,
		{}
	)
	var rec: Dictionary = (
		rec_raw as Dictionary
		if typeof(rec_raw) == TYPE_DICTIONARY
		else {}
	)

	if rec.is_empty():
		return []

	var ids: Array = []

	if str(rec.get("mode", "")) == "dual":
		var era_school: String = str(
			rec.get(
				"era_school",
				""
			)
		)
		var bending_school: String = str(
			rec.get(
				"bending_school",
				""
			)
		)

		if era_school != "":
			var era_teacher_raw: Variant = (
				school_teachers.get(
					_school_key(
						era_school,
						"era_school"
					),
					[]
				)
			)

			if typeof(
				era_teacher_raw
			) == TYPE_ARRAY:
				ids.append_array(
					era_teacher_raw as Array
				)

		if bending_school != "":
			var bending_teacher_raw: Variant = (
				school_teachers.get(
					_school_key(
						bending_school,
						"bending_school"
					),
					[]
				)
			)

			if typeof(
				bending_teacher_raw
			) == TYPE_ARRAY:
				ids.append_array(
					bending_teacher_raw as Array
				)

	else:
		var school_name: String = str(
			rec.get(
				"school_name",
				""
			)
		)
		var mode: String = str(
			rec.get(
				"mode",
				""
			)
		)

		if (
			school_name == ""
			or mode == ""
		):
			return []

		var teacher_raw: Variant = (
			school_teachers.get(
				_school_key(
					school_name,
					mode
				),
				[]
			)
		)

		if typeof(
			teacher_raw
		) == TYPE_ARRAY:
			ids.append_array(
				teacher_raw as Array
			)

	var out: Array = []
	var seen: Dictionary = {}

	for raw_teacher_id in ids:
		var teacher_id: int = int(
			raw_teacher_id
		)

		if teacher_id <= 0:
			continue
		if seen.has(
			teacher_id
		):
			continue

		seen [
			teacher_id
		] = true



		var teacher: Person = gs.get_npc_by_id(
			teacher_id
		)

		if (
			teacher != null
			and teacher.alive
		):
			out.append(
				teacher
			)

	return out

func _register_teacher_in_roster(person_id: int, key: String) -> void:
	if not school_teachers.has(key):
		school_teachers [key] = []
	if person_id not in school_teachers [key]:
		school_teachers [key].append(person_id)


func _bending_teacher_job_title(element: String) -> String:
	match element:
		"air":
			return "Airbending Master"
		"water":
			return "Waterbending Master"
		"earth":
			return "Earthbending Master"
		"fire":
			return "Firebending Master"
		_:
			return "Bending Master"


func _set_bending_nation_from_element(npc: Person, element: String) -> void:
	if npc == null:
		return

	match element:
		"air":
			npc.bending_nation = "Air Nomads"
		"water":
			npc.bending_nation = "Water Tribe"
		"earth":
			npc.bending_nation = "Earth Kingdom"
		"fire":
			npc.bending_nation = "Fire Nation"
		_:
			npc.bending_nation = ""


func _configure_bending_school_teacher(
	teacher: Person,
	student: Person,
	school_name: String
) -> void:
	if teacher == null:
		return

	var school_element: String = _get_bending_school_element_from_name(school_name)
	var avatar_student:= student != null and student.bending_type == "avatar"
	var four_element_teacher:= school_element == "avatar" or avatar_student
	var all_elements:= ["air", "water", "earth", "fire"]

	teacher.education_level = "Educated"
	teacher.school_name = school_name
	teacher.school_mode = "bending_school"
	teacher.school_status = "staff"
	teacher.smarts = max(teacher.smarts, randi_range(85, 100))

	if four_element_teacher:
		if str(teacher.bending_type) not in all_elements:
			teacher.bending_type = str(all_elements [randi() % all_elements.size()])

		teacher.bending_mastery = {
			"air": 3,
			"water": 3,
			"earth": 3,
			"fire": 3
		}
		teacher.avatar_state_unlocked = false
		teacher.avatar_state_used = false
		_set_bending_nation_from_element(teacher, teacher.bending_type)
		teacher.job = "Rare Four-Element Master"
		teacher.fame = max(teacher.fame, randi_range(20, 45))
	else:
		teacher.bending_type = school_element
		teacher.bending_mastery = {
			"air": 0,
			"water": 0,
			"earth": 0,
			"fire": 0
		}
		if school_element in teacher.bending_mastery:
			teacher.bending_mastery [school_element] = 3

		teacher.avatar_state_unlocked = false
		teacher.avatar_state_used = false
		_set_bending_nation_from_element(teacher, school_element)
		teacher.job = _bending_teacher_job_title(school_element)
		teacher.fame = max(teacher.fame, randi_range(5, 18))


func _ensure_school_teachers(person: Person, school_name: String, mode: String) -> void:
	var skey: String = _school_key(school_name, mode)
	if not school_teachers.has(skey):
		school_teachers [skey] = []

	var teacher_ids: Array = school_teachers.get(skey, [])
	var cleaned_ids: Array = []

	for tid in teacher_ids:
		var existing_teacher: Person = gs.get_or_reactivate_npc_by_id(int(tid))
		if existing_teacher != null and existing_teacher.alive:
			existing_teacher.age = clamp(existing_teacher.age, 24, 70)
			existing_teacher.home_city = person.home_city
			existing_teacher.home_country = person.home_country
			existing_teacher.birth_city = existing_teacher.home_city
			existing_teacher.birth_country = existing_teacher.home_country
			existing_teacher.income = max(int(existing_teacher.income), randi_range(25000, 90000))
			existing_teacher.school_name = school_name
			existing_teacher.school_mode = mode
			existing_teacher.school_status = "staff"

			if mode == "bending_school":
				_configure_bending_school_teacher(existing_teacher, person, school_name)
			else:
				existing_teacher.job = "Teacher"
				existing_teacher.education_level = "Educated"
				existing_teacher.smarts = max(existing_teacher.smarts, randi_range(65, 100))

			cleaned_ids.append(existing_teacher.id)

	school_teachers [skey] = cleaned_ids

	var target_count: int = randi_range(SCHOOL_TEACHER_MIN, SCHOOL_TEACHER_MAX)
	var current_count: int = int(cleaned_ids.size())
	if current_count >= target_count:
		return

	for i in range(target_count - current_count):
		var teacher: Person = gs.npc_factory.create_random_npc(true)
		if teacher == null:
			continue

		teacher.age = randi_range(24, 70)
		teacher.home_city = person.home_city
		teacher.home_country = person.home_country
		teacher.birth_city = teacher.home_city
		teacher.birth_country = teacher.home_country
		teacher.income = randi_range(25000, 90000)
		teacher.school_name = school_name
		teacher.school_mode = mode
		teacher.school_status = "staff"

		if mode == "bending_school":
			_configure_bending_school_teacher(teacher, person, school_name)
		else:
			teacher.job = "Teacher"
			teacher.education_level = "Educated"
			teacher.smarts = max(teacher.smarts, randi_range(65, 100))

		gs.register_npc(teacher)
		_register_teacher_in_roster(teacher.id, skey)
func _register_student_in_roster(person_id: int, key: String):
	if not school_rosters.has(key):
		school_rosters [key] = []

	if person_id not in school_rosters [key]:
		school_rosters [key].append(person_id)

	gs.school_rosters = school_rosters

func _ensure_schoolmates(person: Person, school_name: String, mode: String):
	var skey: String = _school_key(school_name, mode)
	_ensure_school_teachers(person, school_name, mode)

	if not school_rosters.has(skey):
		school_rosters [skey] = []

	_sanitize_school_roster(skey, person)

	var roster: Array = school_rosters [skey]
	var target_size: int = _get_target_cohort_size(skey)

	if roster.size() >= target_size:
		gs.school_rosters = school_rosters
		return

	for i in range(target_size - roster.size()):
		var classmate: Person = _spawn_schoolmate_for(person, school_name, mode)
		if classmate == null:
			continue

		gs.npcs.append(classmate)

		if gs.world_space_engine != null:
			gs.world_space_engine.place_npc(classmate)

		if gs.chunk_simulation_engine != null:
			gs.chunk_simulation_engine.assign_npc(classmate)

		if gs.social_graph_engine != null:
			gs.social_graph_engine.connect_people(
				person.id,
				classmate.id,
				randi_range(35, 70)
			)

		roster.append(classmate.id)

	school_rosters [skey] = roster
	gs.school_rosters = school_rosters
func _school_cohort_bounds_for_current_era() -> Dictionary:
	var era_name: String = ""
	if gs != null and gs.era != null:
		era_name = str(gs.era.name).strip_edges()

	match era_name:
		"Ancient Era":
			return { "min": SCHOOL_COHORT_MIN, "max": 132}
		"Medieval Era":
			return { "min": 112, "max": 156}
		"Industrial Era":
			return { "min": 128, "max": 196}
		"Modern Era":
			return { "min": 151, "max": SCHOOL_COHORT_MAX}
		"Future Era":
			return { "min": 180, "max": 320}
		_:
			return { "min": SCHOOL_COHORT_MIN, "max": SCHOOL_COHORT_MAX}
func _get_target_cohort_size(skey: String) -> int:
	var bounds: Dictionary = _school_cohort_bounds_for_current_era()
	var min_size: int = int(bounds.get("min", SCHOOL_COHORT_MIN))
	var max_size: int = int(bounds.get("max", SCHOOL_COHORT_MAX))

	if max_size < min_size:
		max_size = min_size

	var spread: int = max_size - min_size + 1
	return min_size + int(abs(skey.hash()) % spread)
func _get_school_age_group(person: Person) -> String:
	if person == null:
		return ""
	if not ERA_SCHOOLS.has(gs.era.name):
		return ""

	var ages: Dictionary = ERA_SCHOOLS [gs.era.name].get("ages", {})
	var child_start: int = int(ages.get("child_start", 5))
	var adult_start: int = int(ages.get("adult_start", 18))

	if ages.has("middle_start") and ages.has("high_start"):
		var middle_start: int = int(ages.get("middle_start", 11))

		if person.age < child_start:
			return ""
		if person.age < middle_start:
			return "child"
		if person.age < adult_start:
			return "teen"
		return "adult"

	var teen_start: int = int(ages.get("teen_start", 12))

	if person.age < child_start:
		return ""
	if person.age < teen_start:
		return "child"
	if person.age < adult_start:
		return "teen"
	return "adult"


func _get_school_age_bounds(group: String) -> Dictionary:
	var out: Dictionary = { "min": 0, "max": 0}

	if not ERA_SCHOOLS.has(gs.era.name):
		return out

	var ages: Dictionary = ERA_SCHOOLS [gs.era.name].get("ages", {})
	var child_start: int = int(ages.get("child_start", 5))
	var adult_start: int = int(ages.get("adult_start", 18))
	var school_end_age: int = _get_school_end_age()

	if ages.has("middle_start") and ages.has("high_start"):
		var middle_start: int = int(ages.get("middle_start", 11))

		match group:
			"child":
				out ["min"] = child_start
				out ["max"] = middle_start - 1
			"teen":
				out ["min"] = middle_start
				out ["max"] = adult_start - 1
			"adult":
				out ["min"] = adult_start
				out ["max"] = school_end_age

		return out

	var teen_start: int = int(ages.get("teen_start", 12))

	match group:
		"child":
			out ["min"] = child_start
			out ["max"] = teen_start - 1
		"teen":
			out ["min"] = teen_start
			out ["max"] = adult_start - 1
		"adult":
			out ["min"] = adult_start
			out ["max"] = school_end_age

	return out


func _roll_school_age_for_group(group: String, anchor_age: int) -> int:
	var bounds: Dictionary = _get_school_age_bounds(group)
	var min_age: int = int(bounds.get("min", anchor_age))
	var max_age: int = int(bounds.get("max", anchor_age))

	if min_age > max_age:
		return anchor_age

	return clamp(anchor_age + randi_range(-2, 2), min_age, max_age)


func _same_school_age_group(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var a_group: String = _get_school_age_group(a)
	var b_group: String = _get_school_age_group(b)

	if a_group == "" or b_group == "":
		return false

	return a_group == b_group

func _sanitize_school_roster(skey: String, anchor: Person = null) -> void:
	if not school_rosters.has(skey):
		school_rosters [skey] = []
		return

	var parsed: Dictionary = _parse_school_key(skey)
	var school_name: String = str(parsed.get("name", ""))
	var mode: String = str(parsed.get("mode", ""))

	var cleaned: Array = []

	for sid in school_rosters [skey]:
		var npc: Person = gs.get_or_reactivate_npc_by_id(int(sid))
		if npc == null:
			continue
		if not npc.alive:
			continue
		if str(npc.school_status) != "active":
			continue
		if str(npc.school_mode) != mode:
			continue
		if str(npc.school_name) != school_name:
			continue

		if anchor != null and not _same_school_age_group(anchor, npc):
			continue

		if mode == "bending_school":
			if not _school_accepts_bending_type(school_name, str(npc.bending_type)):
				continue

		cleaned.append(npc.id)

	school_rosters [skey] = cleaned


func _spawn_schoolmate_for(person: Person, school_name: String, mode: String) -> Person:
	var classmate: Person = gs.npc_factory.create_random_npc()
	if classmate == null:
		return null


	classmate.age = clamp(person.age + randi_range(-2, 2), 5, 24)


	classmate.school_name = school_name
	classmate.school_mode = mode
	classmate.school_status = "active"
	classmate.education_level = person.education_level


	classmate.home_city = person.home_city
	classmate.home_country = person.home_country
	classmate.birth_city = person.home_city
	classmate.birth_country = person.home_country

	if mode == "bending_school":
		var school_element: String = _get_bending_school_element_from_name(school_name)

		if school_element == "avatar":
			var types: Array = ["air", "water", "earth", "fire"]
			classmate.bending_type = str(types [randi() % types.size()])
		else:
			classmate.bending_type = school_element

		match classmate.bending_type:
			"air":
				classmate.bending_nation = "Air Nomads"
			"water":
				classmate.bending_nation = "Water Tribe"
			"earth":
				classmate.bending_nation = "Earth Kingdom"
			"fire":
				classmate.bending_nation = "Fire Nation"
	else:
		if classmate.bending_type != "none":
			classmate.bending_type = "none"
			classmate.bending_nation = ""

	return classmate

func _apply_era_school_effects(person: Person, school_name: String):
	person.smarts = clamp(person.smarts + randi_range(1, 4), 0, 200)
	person.satisfaction = clamp(person.satisfaction + randi_range(-2, 4), 0, 100)

	match gs.era.name:
		"Ancient Era":
			if school_name == "Agoge":
				person.health += randf() * 2.0
				if "Athletic" not in person.traits and randi() % 6 == 0:
					person.traits.append("Athletic")

		"Medieval Era":
			person.health += randf() * 0.5

		"Industrial Era":
			person.mental_health -= randf() * 0.5

		"Modern Era":
			person.smarts += 1

		"Future Era":
			person.smarts += 2

func _apply_bending_school_effects(person: Person, _school_name: String):
	if person.bending_type == "none":
		return

	match person.bending_type:
		"air":
			gs.bending_engine.train_element(person, "air")
			person.mental_health += randf() * 2.0

		"water":
			gs.bending_engine.train_element(person, "water")

		"earth":
			gs.bending_engine.train_element(person, "earth")
			if person.bending_mastery ["earth"] >= 2 and randi() % 4 == 0:
				gs.bending_engine.attempt_metalbending(person)

		"fire":
			gs.bending_engine.train_element(person, "fire")

		"avatar":
			var elems = ["air", "water", "earth", "fire"]
			gs.bending_engine.train_element(person, elems [randi() % elems.size()])

	person.satisfaction = clamp(person.satisfaction + randi_range(0, 4), 0, 100)

func _random_school_event(person: Person) -> String:
	if person == null:
		return ""

	var friction: Dictionary = _resolve_school_social_friction_event(person)
	if not friction.is_empty():
		return str(friction.get("text", ""))

	var contract: Dictionary = _ensure_school_contract_for_enrollment(person)
	var profile: Dictionary = _safe_dictionary(contract.get("profile", {}))
	var pool: Array = _safe_array(profile.get("ambient_events", []))

	if pool.is_empty():
		pool.append("A classmate made me laugh during lessons.")
		pool.append("I struggled to focus in class today.")
		pool.append("A teacher praised my potential.")
		pool.append("A rumor spread through the school.")
		pool.append("I made it through another year of lessons.")

	if person.age >= 12:
		pool.append(str(profile.get("crush_line", "A classmate seemed to have a crush on me.")))

	if person.bending_type != "none":
		pool.append("My control over %s bending improved." % person.bending_type)

	if "Jealous" in person.traits:
		pool.append(str(profile.get("jealous_line", "I found myself comparing my progress to other students.")))

	if "Impulsive" in person.traits:
		pool.append(str(profile.get("impulsive_line", "I nearly got in trouble for acting without thinking.")))

	return str(pool [randi() % pool.size()])

func _spar_with_classmate(classmate: Person) -> Dictionary:
	if classmate == null:
		return { "text": "❌ Nobody to spar with."}

	var txt = "I sparred with %s at school." % classmate.first_name

	if gs.player.bending_type != "none":
		var chance = 55 + gs.player.bending_mastery.get(gs.player.bending_type, 0) * 10
		if randi() % 100 < chance:
			gs.player.satisfaction += 5
			gs.player.mental_health += 2
			txt = "I sparred with %s and performed well." % classmate.first_name
		else:
			gs.player.health -= randf() * 3.0
			txt = "I sparred with %s and got roughed up." % classmate.first_name

	gs.narrative_engine.log_event(gs.player, { "type": "text", "text": txt})
	return { "text": txt}

func _process_school_progress(npc: Person):
	if not can_attend_school(npc):
		sync_person_school_fields(npc)
		return

	var school_start_age = _get_school_start_age()
	var school_end_age = _get_school_end_age()

	if npc.age < school_start_age:
		sync_person_school_fields(npc)
		return


	if npc.age > school_end_age:
		if enrollment.has(npc.id) and enrollment [npc.id].get("status", "active") == "active":
			enrollment [npc.id] ["status"] = "graduated"
		sync_person_school_fields(npc)
		return

	if not enrollment.has(npc.id):
		_auto_assign_school(npc)

	if enrollment.has(npc.id) and enrollment [npc.id].get("status", "active") == "active":
		_sync_era_school_stage(npc)
		attend_school_year(npc)

	sync_person_school_fields(npc)

func are_classmates(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	for key in school_rosters.keys():
		var roster = school_rosters [key]
		if a.id in roster and b.id in roster:
			return true

	return false
func _is_active_student(person: Person) -> bool:
	if person == null:
		return false
	if not enrollment.has(person.id):
		return false
	return enrollment [person.id].get("status", "active") == "active"

func _is_school_visible_age(person: Person) -> bool:
	if person == null:
		return false

	var school_start_age = _get_school_start_age()
	var school_end_age = _get_school_end_age()

	return person.age >= school_start_age and person.age <= school_end_age
func _get_school_start_age() -> int:
	if (
		gs == null
		or gs.era == null
		or not ERA_SCHOOLS.has(
			gs.era.name
		)
	):
		return 6

	var ages: Dictionary = _safe_dictionary(
		ERA_SCHOOLS [
			gs.era.name
		].get(
			"ages",
			{}
		)
	)

	if ages.has(
		"preschool_start"
	):
		return maxi(
			0,
			int(
				ages.get(
					"preschool_start",
					4
				)
			)
		)

	return maxi(
		0,
		int(
			ages.get(
				"child_start",
				6
			)
		)
	)


func _get_school_end_age() -> int:
	if not ERA_SCHOOLS.has(gs.era.name):
		return 23

	var ages = ERA_SCHOOLS [gs.era.name].get("ages", {})

	return max(23, int(ages.get("adult_start", 18)) + 5)
func _get_yearly_swap_count(skey: String) -> int:
	var target_size: int = _get_target_cohort_size(skey)
	var suggested: int = int(round(float(target_size) * 0.15))
	return clamp(max(2, suggested), 2, 4)


func _pick_carryover_students_from_roster(person: Person, school_name: String, mode: String) -> Array:
	var old_key: String = _school_key(school_name, mode)
	if not school_rosters.has(old_key):
		return []

	var candidates: Array = []

	for sid in school_rosters [old_key]:
		var student_id: int = int(sid)
		if student_id == person.id:
			continue

		var npc: Person = gs.get_or_reactivate_npc_by_id(student_id)
		if npc == null:
			continue
		if not npc.alive:
			continue
		if abs(int(npc.age) - int(person.age)) > 3:
			continue

		candidates.append(npc.id)

	candidates.shuffle()

	var keep_count: int = min(candidates.size(), randi_range(2, 4))
	return candidates.slice(0, keep_count)


func _move_carryover_students_to_new_school(carry_ids: Array, old_school: String, new_school: String, mode: String) -> void:
	var old_key: String = _school_key(old_school, mode)
	var new_key: String = _school_key(new_school, mode)

	for sid in carry_ids:
		var classmate: Person = gs.get_or_reactivate_npc_by_id(int(sid))
		if classmate == null:
			continue
		if not classmate.alive:
			continue

		_unregister_student_from_roster(classmate.id, old_key)

		classmate.school_name = new_school
		classmate.school_mode = mode
		classmate.school_status = "active"

		_register_student_in_roster(classmate.id, new_key)


func _apply_yearly_cohort_churn(person: Person, school_name: String, mode: String) -> void:
	var skey: String = _school_key(school_name, mode)

	if school_name == "":
		return
	if not school_rosters.has(skey):
		return

	_sanitize_school_roster(skey)

	var roster: Array = school_rosters [skey].duplicate()
	var removable: Array = []

	for sid in roster:
		var student_id: int = int(sid)
		if student_id == person.id:
			continue

		var npc: Person = gs.get_or_reactivate_npc_by_id(student_id)
		if npc == null:
			continue
		if not npc.alive:
			continue

		removable.append(student_id)

	if removable.is_empty():
		_ensure_schoolmates(person, school_name, mode)
		return

	removable.shuffle()

	var swap_count: int = min(_get_yearly_swap_count(skey), removable.size())

	for i in range(swap_count):
		_unregister_student_from_roster(int(removable [i]), skey)

	_ensure_schoolmates(person, school_name, mode)
func _sync_era_school_stage(
	person: Person
) -> void:
	if (
		person == null
		or not enrollment.has(
			person.id
		)
	):
		return

	var rec: Dictionary = _safe_dictionary(
		enrollment.get(
			person.id,
			{}
		)
	)

	if (
		rec.is_empty()
		or str(
			rec.get(
				"status",
				"active"
			)
		) != "active"
		or str(
			rec.get(
				"mode",
				""
			)
		) != "era_school"
	):
		return

	var expected_stage: String = (
		_school_stage_key_for_person(
			person
		)
	)

	if expected_stage not in _minor_school_stage_keys_for_era(
		str(
			gs.era.name
		)
	):


		return

	var current_stage: String = str(
		rec.get(
			"era_school_stage",
			""
		)
	).strip_edges().to_lower()

	if current_stage == expected_stage:
		return

	var plan: Dictionary = (
		_ensure_minor_school_stage_plan_for_simulation(
			person,
			expected_stage
		)
	)

	if plan.is_empty():


		return

	var expected_school: String = str(
		plan.get(
			"decided_school",
			""
		)
	).strip_edges()
	var expected_mode: String = str(
		plan.get(
			"decided_mode",
			"era_school"
		)
	).strip_edges()

	if (
		expected_school == ""
		or expected_mode != "era_school"
	):
		return

	var current_school: String = str(
		rec.get(
			"school_name",
			""
		)
	).strip_edges()
	var carryover_ids: Array = []

	if current_school != "":
		carryover_ids = (
			_pick_carryover_students_from_roster(
				person,
				current_school,
				"era_school"
			)
		)

		_unregister_student_from_roster(
			person.id,
			_school_key(
				current_school,
				"era_school"
			)
		)

	var contract: Dictionary = _build_school_contract(
		person,
		expected_school,
		"era_school"
	)

	rec ["school_name"] = expected_school
	rec ["started_age"] = int(
		person.age
	)
	rec ["contract_id"] = str(
		contract.get(
			"contract_id",
			""
		)
	)
	rec ["institution_type"] = str(
		contract.get(
			"institution_type",
			""
		)
	)
	rec ["era_school_stage"] = expected_stage
	rec ["program"] = str(
		contract.get(
			"program",
			_school_stage_display_name(
				expected_stage
			)
		)
	)
	rec ["lane"] = str(
		contract.get(
			"lane",
			"school"
		)
	)
	rec ["tuition"] = float(
		contract.get(
			"tuition",
			0.0
		)
	)
	rec ["meal_surface_label"] = str(
		contract.get(
			"meal_surface_label",
			""
		)
	)

	enrollment [
		person.id
	] = rec

	_register_student_in_roster(
		person.id,
		_school_key(
			expected_school,
			"era_school"
		)
	)

	if (
		current_school != ""
		and current_school != expected_school
	):
		_move_carryover_students_to_new_school(
			carryover_ids,
			current_school,
			expected_school,
			"era_school"
		)

	_ensure_schoolmates(
		person,
		expected_school,
		"era_school"
	)
	_ensure_school_teachers(
		person,
		expected_school,
		"era_school"
	)
	_ensure_school_contract_for_enrollment(
		person
	)
	_mark_minor_school_stage_plan_committed(
		person,
		expected_stage,
		expected_school
	)
	sync_person_school_fields(
		person
	)
func _unregister_student_from_roster(person_id: int, key: String) -> void:
	if not school_rosters.has(key):
		return
	school_rosters [key].erase(person_id)
	if school_rosters [key].is_empty():
		school_rosters.erase(key)
	gs.school_rosters = school_rosters