extends Resource
class_name SchoolHubContractEngine

const ENGINE_SCHEMA:= "eralife.school_hub_contract_engine"
const HUB_SCHEMA:= "eralife.school_hub.contract"
const CONTRACT_VERSION:= 1
const MAX_CACHE_SIZE:= 96

var gs: GameState = null
var sequence: int = 0
var hub_contract_cache: Dictionary = {}
var last_report: Dictionary = {}


func _init(game_state: GameState = null) -> void:
	bind_game_state(game_state)


func bind_game_state(game_state: GameState) -> void:
	gs = game_state
	_ensure_state()


func emit_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _failure(
			"missing_actor",
			context
		)

	if (
		gs == null
		or gs.school_engine == null
	):
		return _observable_partial(
			actor,
			"school_engine_unavailable",
			context
		)



	var _projection_read_only: bool = true

	var snapshot: Dictionary = _dict(
		gs.school_engine.get_school_ecosystem_snapshot(
			actor
		)
	)
	var enrolled: bool = bool(
		snapshot.get(
			"active",
			false
		)
	)
	var active_section_id: String = _section(
		str(
			context.get(
				"active_section_id",
				context.get(
					"section_id",
					"overview"
				)
			)
		)
	)




	if not enrolled:
		active_section_id = "overview"

	var force_refresh: bool = bool(
		context.get(
			"force_refresh",
			false
		)
	)
	var signature: String = _hub_signature(
		actor,
		active_section_id,
		snapshot
	)
	var cached: Dictionary = _dict(
		hub_contract_cache.get(
			signature,
			{}
		)
	)

	if (
		not force_refresh
		and not cached.is_empty()
	):
		cached ["cache_hit"] = true
		cached ["requested_at_ms"] = int(
			Time.get_ticks_msec()
		)
		last_report = cached.duplicate(false)
		return cached.duplicate(false)

	var active_school: Dictionary = _dict(
		snapshot.get(
			"active_contract",
			{}
		)
	)
	var meal_zone: Dictionary = _dict(
		snapshot.get(
			"meal_zone",
			{}
		)
	)
	var meal_label: String = str(
		active_school.get(
			"meal_surface_label",
			meal_zone.get(
				"name",
				"Communal / Lunch Area"
			)
		)
	).strip_edges()

	if meal_label == "":
		meal_label = "Communal / Lunch Area"

	var tabs: Array = _tabs(
		active_section_id,
		meal_label,
		enrolled
	)
	var section_contracts: Dictionary = (
		_section_contract_deck(
			actor,
			snapshot,
			active_school,
			tabs
		)
	)
	var active_projection: Dictionary = _dict(
		section_contracts.get(
			active_section_id,
			{}
		)
	)

	if active_projection.is_empty():
		active_projection = _observable_partial(
			actor,
			"school_section_projection_missing",
			context
		)

	var higher_learning: Dictionary = _dict(
		snapshot.get(
			"higher_learning_catalog",
			{}
		)
	)
	var pre_enrollment_catalog_pending: bool = (
		not enrolled
		and bool(
			higher_learning.get(
				"visible",
				false
			)
		)
		and not bool(
			higher_learning.get(
				"projection_complete",
				false
			)
		)
	)

	sequence += 1

	active_projection ["success"] = true
	active_projection ["schema"] = HUB_SCHEMA
	active_projection ["version"] = CONTRACT_VERSION
	active_projection ["sequence"] = sequence
	active_projection ["actor_id"] = int(actor.id)
	active_projection ["actor_name"] = _person_name(actor)
	active_projection ["active_section_id"] = active_section_id
	active_projection ["tabs"] = tabs
	active_projection [
		"section_contracts"
	] = section_contracts.duplicate(false)
	active_projection [
		"snapshot"
	] = snapshot.duplicate(false)
	active_projection ["truth_state"] = (
		"observable_partial"
		if pre_enrollment_catalog_pending
		else "hot"
	)
	active_projection ["projection_complete"] = (
		not pre_enrollment_catalog_pending
	)
	active_projection ["authoritative_projection"] = true
	active_projection ["enrolled"] = enrolled
	active_projection ["surface_mode"] = (
		"enrolled_school"
		if enrolled
		else "pre_enrollment_learning_catalog"
	)
	active_projection [
		"pre_enrollment_landing_surface"
	] = not enrolled
	active_projection [
		"in_school_tabs_visible"
	] = enrolled
	active_projection [
		"projection_read_only"
	] = true
	active_projection [
		"school_reconciliation_performed"
	] = false
	active_projection [
		"simulation_mutation_performed"
	] = false
	active_projection ["context"] = context.duplicate(false)
	active_projection ["cache_hit"] = false
	active_projection [
		"created_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	active_projection [
		"surface_revision"
	] = signature
	active_projection ["render_policy"] = {
		"ui_is_pure_renderer": true,
		"render_immediately": true
	}
	active_projection ["ui_is_renderer_only"] = true

	_store_contract(
		signature,
		active_projection
	)
	last_report = active_projection.duplicate(false)

	return active_projection.duplicate(false)
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _failure(
			"missing_actor",
			payload
		)

	if (
		gs == null
		or gs.school_engine == null
	):
		return _failure(
			"school_engine_unavailable",
			payload
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			"refresh"
		)
	).strip_edges().to_lower()

	match action_id:
		"refresh", "open_hub", "change_section", "observe_partial":
			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": CONTRACT_VERSION,
				"mode": "school_hub_projection_refreshed",
				"hub_contract": emit_hub_contract(
					actor,
					{
						"active_section_id": str(
							payload.get(
								"section_id",
								payload.get(
									"active_section_id",
									"overview"
								)
							)
						),
						"source": (
							"school_hub_contract_engine.resolve_intent"
						),
						"force_refresh": bool(
							payload.get(
								"force_refresh",
								false
							)
						),
						"projection_read_only": true
					}
				),
				"ui_is_renderer_only": true
			}

		"observe_communal_presence":
			return observe_communal_presence(
				actor,
				payload
			)

		"fund_higher_learning":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.resolve_higher_learning_program_funding(
						actor,
						str(
							payload.get(
								"program_id",
								""
							)
						),
						str(
							payload.get(
								"funding_method",
								""
							)
						)
					)
				),
				payload
			)

		"join_clique":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.resolve_school_clique_join(
						actor,
						str(
							payload.get(
								"clique_id",
								""
							)
						)
					)
				),
				payload
			)

		"enroll":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.enroll_by_contract_choice(
						actor,
						str(
							payload.get(
								"school_name",
								""
							)
						),
						str(
							payload.get(
								"school_mode",
								payload.get(
									"mode",
									"era_school"
								)
							)
						)
					)
				),
				payload
			)

		"attend_year":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.attend_school_year(
						actor
					)
				),
				payload
			)

		"enroll_child":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.enroll_child_from_parent_school_hub(
						actor,
						int(
							payload.get(
								"child_id",
								-1
							)
						),
						str(
							payload.get(
								"school_name",
								""
							)
						),
						str(
							payload.get(
								"school_mode",
								"era_school"
							)
						)
					)
				),
				payload
			)

		"enroll_children":
			return _commit_school_action(
				actor,
				action_id,
				_dict(
					gs.school_engine.enroll_children_from_parent_school_hub(
						actor,
						_array(
							payload.get(
								"child_ids",
								[]
							)
						),
						str(
							payload.get(
								"school_name",
								""
							)
						),
						str(
							payload.get(
								"school_mode",
								"era_school"
							)
						)
					)
				),
				payload
			)

		_:
			return _failure(
				"unknown_school_hub_intent",
				payload
			)

func observe_communal_presence(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null or gs == null or gs.school_engine == null:
		return _failure("school_communal_presence_unavailable", payload)



	var snapshot: Dictionary = _dict(gs.school_engine.get_school_ecosystem_snapshot(actor))
	var meal_zone: Dictionary = _dict(snapshot.get("meal_zone", {}))
	var approach_context: Dictionary = _dict(meal_zone.get("approach_context", {}))
	var pending_scenario: Dictionary = _dict(approach_context.get("pending_scenario", {}))
	var scenario_contract: Dictionary = {}

	if not pending_scenario.is_empty():
		scenario_contract = _dict(gs.school_engine.consume_school_meal_approach_scenario(actor))

	var queue_report: Dictionary = {}

	if (
		not scenario_contract.is_empty()
		and gs.scenario_engine != null
		and gs.scenario_engine.has_method("queue_external_scenario")
	):
		queue_report = _dict(gs.scenario_engine.queue_external_scenario(scenario_contract))

	if not scenario_contract.is_empty():
		_invalidate_actor_cache(int(actor.id))

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "school_communal_presence_observed",
		"actor_id": int(actor.id),
		"visible_dwell_seconds": float(payload.get("visible_dwell_seconds", 0.0)),
		"scenario_contract": scenario_contract.duplicate(true),
		"scenario_queued": bool(queue_report.get("success", not queue_report.is_empty())),
		"queue_report": queue_report.duplicate(true),
		"hub_contract":
		emit_hub_contract(
			actor,
			{
				"active_section_id": "meal",
				"source": "school_hub_contract_engine.observe_communal_presence",
				"force_refresh": true
			}
		),
		"ui_is_renderer_only": true
	}


func _commit_school_action(
	actor: Person,
	action_id: String,
	result: Dictionary,
	payload: Dictionary
) -> Dictionary:
	_invalidate_actor_cache(
		int(
			actor.id
		)
	)

	return {
		"success": bool(
			result.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "school_hub_intent_resolved",
		"action_id": action_id,
		"result": result.duplicate(true),
		"hub_contract": emit_hub_contract(
			actor,
			{
				"active_section_id": str(
					payload.get(
						"return_section_id",
						payload.get(
							"section_id",
							"overview"
						)
					)
				),
				"source": (
					"school_hub_contract_engine.intent_result"
				),
				"force_refresh": true,
				"projection_read_only": true
			}
		),
		"ui_is_renderer_only": true
	}

func _section_contract_deck(
	actor: Person,
	snapshot: Dictionary,
	active_school: Dictionary,
	tabs: Array
) -> Dictionary:
	var deck: Dictionary = {}
	var enrolled: bool = bool(
		snapshot.get(
			"active",
			false
		)
	)
	var school_option_catalog_revision: String = (
		_school_option_catalog_revision(
			snapshot
		)
	)

	for raw_tab in tabs:
		var tab: Dictionary = _dict(
			raw_tab
		)
		var section_id: String = _section(
			str(
				tab.get(
					"key",
					"overview"
				)
			)
		)

		if not enrolled:
			section_id = "overview"

		var rows: Array = _section_rows(
			actor,
			section_id,
			snapshot,
			active_school
		)
		var section_surface_revision: String = (
			_hub_signature(
				actor,
				section_id,
				snapshot
			)
		)

		deck [
			section_id
		] = {
			"success": true,
			"schema": HUB_SCHEMA,
			"version": CONTRACT_VERSION,
			"actor_id": int(
				actor.id
			),
			"actor_name": _person_name(
				actor
			),
			"title": "SCHOOL HUB",
			"subtitle": _school_subtitle(
				actor,
				active_school
			),
			"header_chip_text": _school_header_chip(
				active_school,
				snapshot
			),
			"active_section_id": section_id,
			"tabs": _tabs(
				section_id,
				str(
					active_school.get(
						"meal_surface_label",
						"Communal / Lunch Area"
					)
				),
				enrolled
			),
			"section_rows": rows,
			"status_text": _status_text(
				snapshot,
				section_id
			),
			"surface_mode": (
				"enrolled_school"
				if enrolled
				else "pre_enrollment_learning_catalog"
			),
			"surface_revision": (
				section_surface_revision
			),
			"school_option_catalog_revision": (
				school_option_catalog_revision
			),
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		}

	return deck
func _section_rows(
	actor: Person,
	section_id: String,
	snapshot: Dictionary,
	active_school: Dictionary
) -> Array:
	match section_id:
		"overview":
			return _overview_rows(
				actor,
				snapshot,
				active_school
			)

		"classes":
			return _class_rows(
				snapshot
			)

		"meal":
			return _meal_rows(
				snapshot,
				active_school
			)

		"teachers":
			return [
				{
					"row_kind": "people_group",
					"title": "Teachers",
					"subtitle": (
						"The educators currently attached "
						+ "to this school contract."
					),
					"cards": _people_cards(
						_array(
							snapshot.get(
								"teachers",
								[]
							)
						),
						"teaching"
					),
					"columns": 2,
					"empty_text": (
						"No teachers are currently observable."
					)
				}
			]

		"social":
			return _social_rows(
				actor,
				snapshot
			)

		"actions":
			return _action_rows(
				actor,
				snapshot,
				active_school
			)

		_:
			return []

func _overview_rows(
	actor: Person,
	snapshot: Dictionary,
	active_school: Dictionary
) -> Array:
	var enrolled: bool = bool(
		snapshot.get(
			"active",
			false
		)
	)



	if not enrolled:
		var landing_rows: Array = []
		var higher_learning: Dictionary = _dict(
			snapshot.get(
				"higher_learning_catalog",
				{}
			)
		)

		if bool(
			higher_learning.get(
				"visible",
				false
			)
		):
			landing_rows.append({
				"row_kind": "higher_learning_programs",
				"surface_scope": (
					"school_hub_pre_enrollment"
				),
				"title": str(
					higher_learning.get(
						"title",
						"HIGHER LEARNING"
					)
				),
				"subtitle": str(
					higher_learning.get(
						"subtitle",
						"Pick a program to study."
					)
				),
				"institutions": (
					higher_learning.get(
						"institutions",
						[]
					)
				),
				"current_program_id": str(
					higher_learning.get(
						"current_program_id",
						""
					)
				),
				"can_choose_program": bool(
					higher_learning.get(
						"can_choose_program",
						false
					)
				),
				"catalog_resident": bool(
					higher_learning.get(
						"resident",
						false
					)
				),
				"projection_complete": bool(
					higher_learning.get(
						"projection_complete",
						false
					)
				),
				"progressive_observability": true,
				"observation_required": false,
				"empty_text": (
					"Higher-learning institution contracts "
					+ "are still becoming resident."
				),
				"ui_is_renderer_only": true
			})

		var available_contracts: Array = _array(
			snapshot.get(
				"available_contracts",
				[]
			)
		)
		var school_preview_mode: bool = bool(
			snapshot.get(
				"school_preview_mode",
				false
			)
		)

		if not available_contracts.is_empty():
			var options_title: String = "Schools You Can Attend"
			var options_subtitle: String = (
				"Available SchoolEngine contracts for %s's "
				+ "current era and life stage."
			) % _person_name(actor)

			if school_preview_mode:
				var transition: Dictionary = _dict(
					snapshot.get(
						"next_school_transition",
						{}
					)
				)
				var stage_display: String = str(
					transition.get(
						"stage_display",
						"School"
					)
				).strip_edges()
				var available_at_age: int = int(
					snapshot.get(
						"school_preview_start_age",
						-1
					)
				)

				if stage_display == "":
					stage_display = "School"

				options_title = (
					"Upcoming %s"
					% stage_display
				)

				if available_at_age >= 0:
					options_subtitle = (
						"%s's resident %s institution contracts "
						+ "are visible now. Enrollment begins at age %d."
					) % [
						_person_name(actor),
						stage_display,
						available_at_age
					]
				else:
					options_subtitle = (
						"%s's upcoming %s institution contracts "
						+ "are already resident and observable."
					) % [
						_person_name(actor),
						stage_display
					]

			landing_rows.append({
				"row_kind": "school_options",
				"surface_scope": (
					"school_hub_pre_enrollment"
				),
				"title": options_title,
				"subtitle": options_subtitle,
				"options": _school_option_cards(
					available_contracts,
					"overview"
				),
				"columns": 2,
				"empty_text": (
					"No school options are currently observable."
				),
				"ui_is_renderer_only": true
			})

		if landing_rows.is_empty():
			landing_rows.append({
				"row_kind": "information",
				"surface_scope": (
					"school_hub_pre_enrollment"
				),
				"title": "Learning Opportunities",
				"lines": [
					(
						"No resident SchoolEngine institution "
						+ "contracts are currently observable for %s "
						+ "in this era."
					) % _person_name(actor)
				],
				"progressive_observability": true,
				"observation_required": false,
				"ui_is_renderer_only": true
			})

		return landing_rows

	var lines: Array = []
	var school_name: String = str(
		active_school.get(
			"school_name",
			actor.school_name
		)
	).strip_edges()
	var school_mode: String = str(
		active_school.get(
			"school_mode",
			actor.school_mode
		)
	).strip_edges()

	if school_name == "":
		school_name = "School"

	lines.append(
		"School: %s"
		% school_name
	)
	lines.append(
		"Mode: %s"
		% (
			school_mode.capitalize()
			if school_mode != ""
			else "None"
		)
	)
	lines.append(
		"Status: %s"
		% str(actor.school_status)
	)
	lines.append(
		"Education: %s"
		% str(actor.education_level)
	)

	var classmates: Array = _array(
		snapshot.get(
			"classmates",
			[]
		)
	)
	var teachers: Array = _array(
		snapshot.get(
			"teachers",
			[]
		)
	)

	lines.append(
		"Observable classmates: %d"
		% classmates.size()
	)
	lines.append(
		"Observable teachers: %d"
		% teachers.size()
	)

	return [
		{
			"row_kind": "summary",
			"title": "School Identity",
			"lines": lines,
			"surface_scope": "active_school"
		},
		{
			"row_kind": "people_group",
			"title": "Classmates",
			"subtitle": (
				"The current student relationship surface."
			),
			"cards": _people_cards(
				classmates,
				"classmate"
			),
			"columns": 3,
			"empty_text": (
				"No classmates are currently observable."
			),
			"surface_scope": "active_school"
		}
	]

func _class_rows(snapshot: Dictionary) -> Array:
	var rows: Array = []

	for raw_class in _array(snapshot.get("classes", [])):
		var class_contract: Dictionary = _dict(raw_class)

		if class_contract.is_empty():
			continue

		rows.append(
			{
				"row_kind": "class_zone",
				"id": str(class_contract.get("zone_id", "class")),
				"title": str(class_contract.get("name", "Class")),
				"subtitle":
				(
					"%d represented students • %d offscreen students"
					% [
						int(
							class_contract.get(
								"represented_student_count",
								_array(class_contract.get("students", [])).size()
							)
						),
						int(class_contract.get("offscreen_student_count", 0))
					]
				),
				"students": _people_cards(_array(class_contract.get("students", [])), "in class"),
				"teachers": _people_cards(_array(class_contract.get("teachers", [])), "teaching"),
				"columns": 3
			}
		)

	if rows.is_empty():
		rows.append(
			{
				"row_kind": "information",
				"title": "Classes",
				"lines": ["No class-zone projection is currently observable."]
			}
		)

	return rows


func _meal_rows(snapshot: Dictionary, active_school: Dictionary) -> Array:
	var meal_zone: Dictionary = _dict(snapshot.get("meal_zone", {}))
	var people: Array = _student_cards(_array(meal_zone.get("people", [])))
	var social_groups: Array = _meal_social_groups(people)
	var title_text: String = (
		str(active_school.get("meal_surface_label", meal_zone.get("name", "Communal / Lunch Area")))
		.strip_edges()
	)

	if title_text == "":
		title_text = "Communal / Lunch Area"

	return [
		{
			"row_kind": "communal_zone",
			"id": "school_communal_area",
			"title": title_text,
			"subtitle":
			(
				"Students remain visible as individual school cards while "
				+ "their resolved conversations and social groups are shown "
				+ "alongside them. Remaining here lets SchoolEngine and "
				+ "ScenarioEngine surface an approach."
			),
			"people": people,
			"social_groups": social_groups,
			"groups": social_groups,
			"friendliness": int(meal_zone.get("friendliness", 50)),
			"friendliness_label": str(meal_zone.get("friendliness_label", "Mixed")),
			"friendliness_description":
			str(
				meal_zone.get(
					"friendliness_description", "The communal area has a mixed social temperature."
				)
			),
			"live_count": int(meal_zone.get("live_count", people.size())),
			"live_count_label":
			str(meal_zone.get("live_count_label", "%d students" % people.size())),
			"approach_context": _dict(meal_zone.get("approach_context", {})),
			"columns": 3,
			"group_columns": 2,
			"ui_is_renderer_only": true
		}
	]


func _social_rows(
	_actor: Person,
	snapshot: Dictionary
) -> Array:
	var rows: Array = []
	var clique_contract: Dictionary = _dict(
		snapshot.get(
			"clique_contract",
			{}
		)
	)

	if (
		not clique_contract.is_empty()
		and bool(
			clique_contract.get(
				"visible",
				false
			)
		)
	):
		rows.append({
			"row_kind": "school_cliques",
			"title": "SCHOOL CLIQUES",
			"subtitle": (
				"Cliques exist only in active Modern/Future "
				+ "high-school reality."
			),
			"cliques": clique_contract.get(
				"cliques",
				[]
			),
			"current_clique_id": str(
				clique_contract.get(
					"current_clique_id",
					""
				)
			),
			"ui_is_renderer_only": true
		})

	rows.append({
		"row_kind": "social_memory",
		"title": "School Social Memory",
		"memories": _array(
			snapshot.get(
				"social_memory",
				[]
			)
		)
	})

	rows.append({
		"row_kind": "people_group",
		"title": "Classmates",
		"subtitle": (
			"Students attached to the active school reality."
		),
		"cards": _people_cards(
			_array(
				snapshot.get(
					"classmates",
					[]
				)
			),
			"classmate"
		),
		"columns": 3,
		"empty_text": (
			"No classmates are currently observable."
		)
	})

	return rows
func _action_rows(_actor: Person, snapshot: Dictionary, _active_school: Dictionary) -> Array:
	var rows: Array = []
	var active: bool = bool(snapshot.get("active", false))

	if active:
		rows.append(
			{
				"row_kind": "actions",
				"title": "School Actions",
				"subtitle":
				"The panel emits expressions; SchoolHubContractEngine routes committed actions.",
				"actions":
				[
					{
						"action_id": "attend_year",
						"label": "Attend School Year",
						"return_section_id": "overview",
						"enabled": true,
						"ui_is_expression_only": true
					}
				]
			}
		)
	else:
		rows.append(
			{
				"row_kind": "school_options",
				"title": "Available Schools",
				"subtitle": "Choose an authoritative SchoolEngine contract.",
				"options":
				_school_option_cards(_array(snapshot.get("available_contracts", [])), "overview"),
				"columns": 2,
				"empty_text": "No school options are currently available."
			}
		)

	return rows


func _student_cards(rows: Array) -> Array:
	var out: Array = []

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)

		if row.is_empty():
			continue

		out.append(_student_card(row))

	return out


func _people_cards(people: Array, fallback_activity: String) -> Array:
	var out: Array = []

	for raw_person in people:
		var row: Dictionary = {}

		if raw_person is Person:
			var person: Person = raw_person as Person
			row = {
				"person_id": int(person.id),
				"full_name": _person_name(person),
				"age": int(person.age),
				"activity": fallback_activity,
				"popularity": _school_popularity(person),
				"friendliness": _school_friendliness(person)
			}
		elif typeof(raw_person) == TYPE_DICTIONARY:
			row = _dict(raw_person)

			if str(row.get("activity", "")).strip_edges() == "":
				row ["activity"] = fallback_activity

		if row.is_empty():
			continue

		out.append(_student_card(row))

	return out


func _student_card(row: Dictionary) -> Dictionary:
	var person_id: int = int(row.get("person_id", row.get("target_id", -1)))
	var person: Person = _person_by_id(person_id)
	var full_name: String = str(row.get("full_name", _person_name(person))).strip_edges()
	var age: int = int(row.get("age", int(person.age) if person != null else 0))
	var activity: String = str(row.get("activity", "nearby")).strip_edges()
	var popularity: int = clampi(int(row.get("popularity", _school_popularity(person))), 0, 100)
	var friendliness: int = clampi(
		int(row.get("friendliness", _school_friendliness(person))), 0, 100
	)

	if full_name == "":
		full_name = "Student %d" % person_id

	if activity == "":
		activity = "nearby"


	return {
		"person_id": person_id,
		"target_id": person_id,
		"full_name": full_name,
		"display_line": "%s (Age %d) • %s" % [full_name, age, activity],
		"activity": activity,
		"popularity": popularity,
		"friendliness": friendliness,
		"social_group": _array(row.get("social_group", [])),
		"button_text": "View Student",
		"interaction_contract":
		{ "can_open_profile": person_id > 0, "target_id": person_id, "ui_is_expression_only": true},
		"ui_is_renderer_only": true
	}


func _meal_social_groups(people: Array) -> Array:
	var groups_by_signature: Dictionary = {}

	for raw_person in people:
		var person_row: Dictionary = _dict(raw_person)
		var member_names: Array = _array(person_row.get("social_group", []))

		if member_names.is_empty():
			continue

		member_names.append(str(person_row.get("full_name", "Student")))
		member_names = _clean_string_array(member_names)
		member_names.sort()

		var signature: String = "|".join(PackedStringArray(member_names))

		if signature == "":
			continue

		if groups_by_signature.has(signature):
			continue

		groups_by_signature [signature] = {
			"row_kind": "school_social_group",
			"id": "school_social_group:%s" % str(signature.hash()),
			"title": "Conversation Group" if member_names.size() > 2 else "Student Conversation",
			"member_names": member_names,
			"description": _social_group_description(member_names),
			"member_count": member_names.size(),
			"ui_is_renderer_only": true
		}

	return groups_by_signature.values()


func _social_group_description(member_names: Array) -> String:
	if member_names.is_empty():
		return "No students are currently grouped together."

	if member_names.size() == 1:
		return "%s is standing alone." % str(member_names [0])

	if member_names.size() == 2:
		return "%s and %s are talking together." % [str(member_names [0]), str(member_names [1])]

	return "%s are talking in a group." % _join_strings(member_names)


func _school_option_cards(
	options: Array,
	return_section_id: String
) -> Array:
	var out: Array = []

	for raw_option in options:
		var option: Dictionary = _dict(
			raw_option
		)

		if option.is_empty():
			continue

		var contract: Dictionary = _dict(
			option.get(
				"contract",
				{}
			)
		)
		var school_name: String = str(
			option.get(
				"school_name",
				option.get(
					"name",
					contract.get(
						"name",
						option.get(
							"title",
							"School"
						)
					)
				)
			)
		).strip_edges()
		var school_mode: String = str(
			option.get(
				"school_mode",
				option.get(
					"mode",
					option.get(
						"type",
						contract.get(
							"type",
							"era_school"
						)
					)
				)
			)
		).strip_edges().to_lower()

		if school_name == "":
			continue

		if school_mode == "":
			school_mode = "era_school"

		var tuition: float = float(
			contract.get(
				"tuition",
				option.get(
					"tuition",
					0.0
				)
			)
		)
		var program_text: String = str(
			contract.get(
				"program",
				option.get(
					"description",
					"An available school contract."
				)
			)
		)
		var option_available: bool = bool(
			option.get(
				"available",
				option.get(
					"enabled",
					true
				)
			)
		)
		var preview_only: bool = bool(
			option.get(
				"preview_only",
				contract.get(
					"preview_only",
					false
				)
			)
		)
		var available_at_age: int = int(
			option.get(
				"available_at_age",
				contract.get(
					"available_at_age",
					-1
				)
			)
		)
		var years_until_available: int = int(
			option.get(
				"years_until_available",
				contract.get(
					"years_until_available",
					-1
				)
			)
		)
		var availability_state: String = str(
			option.get(
				"availability_state",
				contract.get(
					"availability_state",
					(
						"available"
						if option_available
						else "unavailable"
					)
				)
			)
		).strip_edges().to_lower()
		var minor_requires_custodial_decision: bool = bool(
			contract.get(
				"minor_requires_custodial_decision",
				false
			)
		)
		var action_enabled: bool = (
			option_available
			and not preview_only
			and not minor_requires_custodial_decision
		)
		var action_label: String = "Enroll"
		var action_id: String = "enroll"

		if preview_only:
			action_id = "school_stage_preview"

			if available_at_age >= 0:
				action_label = (
					"Available at Age %d"
					% available_at_age
				)
				program_text += (
					"\nEnrollment opens at age %d. "
					+ "This institution contract is already "
					+ "resident and observable."
				) % available_at_age
			else:
				action_label = "Upcoming"
				program_text += (
					"\nThis institution contract is already "
					+ "resident and observable, but enrollment "
					+ "is not available yet."
				)
		elif minor_requires_custodial_decision:
			action_label = "Parent / Guardian Decides"
			action_id = "custodial_decision_required"
			program_text += (
				"\nParent / guardian decision required. "
				+ "You may express a preference through "
				+ "your schooling scenario."
			)

		out.append({
			"id": str(
				contract.get(
					"contract_id",
					option.get(
						"contract_id",
						(
							"school_option:%s:%s"
							% [
								school_mode,
								school_name.to_lower().replace(
									" ",
									"_"
								)
							]
						)
					)
				)
			),
			"title": school_name,
			"subtitle": (
				school_mode.replace(
					"_",
					""
				).capitalize()
			),
			"description": program_text,
			"tuition": tuition,
			"enabled": option_available,
			"preview_only": preview_only,
			"availability_state": availability_state,
			"available_at_age": available_at_age,
			"years_until_available": years_until_available,
			"minor_requires_custodial_decision": (
				minor_requires_custodial_decision
			),
			"action": {
				"action_id": action_id,
				"label": action_label,
				"school_name": school_name,
				"school_mode": school_mode,
				"return_section_id": return_section_id,
				"enabled": action_enabled,
				"preview_only": preview_only,
				"availability_state": availability_state,
				"available_at_age": available_at_age,
				"ui_is_expression_only": true
			},
			"ui_is_renderer_only": true
		})

	return out
func _tabs(
	active_section_id: String,
	meal_label: String,
	enrolled: bool = true
) -> Array:
	var rows: Array = [
		{
			"key": "overview",
			"label": "Overview"
		}
	]

	if enrolled:
		rows.append_array([
			{
				"key": "classes",
				"label": "Classes"
			},
			{
				"key": "meal",
				"label": meal_label
			},
			{
				"key": "teachers",
				"label": "Teachers"
			},
			{
				"key": "social",
				"label": "Social"
			},
			{
				"key": "actions",
				"label": "Actions"
			}
		])

	var palette: Dictionary = _school_palette()

	for index in range(rows.size()):
		var row: Dictionary = _dict(
			rows [index]
		)
		row ["selected"] = (
			str(
				row.get(
					"key",
					""
				)
			) == active_section_id
		)
		row ["palette"] = palette.duplicate(true)
		row ["requires_active_enrollment"] = (
			str(
				row.get(
					"key",
					"overview"
				)
			) != "overview"
		)
		rows [index] = row

	return rows

func _school_palette() -> Dictionary:
	return {
		"accent": Color(0.4, 0.72, 1.0, 0.96),
		"active_fill": Color(0.045, 0.09, 0.155, 0.98),
		"inactive_fill": Color(0.025, 0.045, 0.08, 0.96),
		"hover_fill": Color(0.065, 0.13, 0.22, 0.99),
		"font_color": Color(0.95, 0.98, 1.0, 1.0)
	}


func _school_subtitle(actor: Person, active_school: Dictionary) -> String:
	var school_name: String = str(active_school.get("school_name", actor.school_name)).strip_edges()

	if school_name == "" or school_name == "None":
		return "%s's available learning reality." % _person_name(actor)

	return "%s at %s." % [_person_name(actor), school_name]


func _school_header_chip(active_school: Dictionary, snapshot: Dictionary) -> String:
	if not bool(snapshot.get("active", false)):
		return "NOT ENROLLED"

	var school_name: String = str(active_school.get("school_name", "School")).strip_edges()
	var school_mode: String = (
		str(active_school.get("school_mode", "era_school")).replace("_", " ").capitalize()
	)

	return "%s • %s" % [school_name, school_mode]


func _status_text(snapshot: Dictionary, section_id: String) -> String:
	if not bool(snapshot.get("active", false)):
		return "Choose an available learning contract."

	if section_id == "meal":
		return (
			"The communal area is live. SchoolEngine owns student presence; "
			+ "ScenarioEngine owns approaches."
		)

	return "School reality is live. Tabs reveal resident projections."

func _school_option_catalog_revision(
	snapshot: Dictionary
) -> String:
	var school_stage: String = str(
		snapshot.get(
			"school_stage",
			""
		)
	).strip_edges().to_lower()
	var school_option_stage: String = str(
		snapshot.get(
			"school_option_stage",
			""
		)
	).strip_edges().to_lower()
	var school_planning_mode: bool = bool(
		snapshot.get(
			"school_planning_mode",
			false
		)
	)
	var school_preview_mode: bool = bool(
		snapshot.get(
			"school_preview_mode",
			false
		)
	)
	var school_preview_start_age: int = int(
		snapshot.get(
			"school_preview_start_age",
			-1
		)
	)
	var school_preview_years_until: int = int(
		snapshot.get(
			"school_preview_years_until",
			-1
		)
	)
	var transition: Dictionary = _dict(
		snapshot.get(
			"next_school_transition",
			{}
		)
	)
	var transition_stage: String = str(
		transition.get(
			"stage_key",
			""
		)
	).strip_edges().to_lower()
	var transition_start_age: int = int(
		transition.get(
			"start_age",
			-1
		)
	)
	var transition_planning_due: bool = bool(
		transition.get(
			"planning_due",
			false
		)
	)
	var option_tokens: PackedStringArray = PackedStringArray()

	for raw_option in _array(
		snapshot.get(
			"available_contracts",
			[]
		)
	):
		var option: Dictionary = _dict(
			raw_option
		)

		if option.is_empty():
			continue

		var contract: Dictionary = _dict(
			option.get(
				"contract",
				{}
			)
		)
		var option_name: String = str(
			option.get(
				"name",
				contract.get(
					"name",
					""
				)
			)
		).strip_edges()
		var option_type: String = str(
			option.get(
				"type",
				contract.get(
					"type",
					"era_school"
				)
			)
		).strip_edges().to_lower()
		var option_stage: String = str(
			contract.get(
				"school_stage",
				school_option_stage
			)
		).strip_edges().to_lower()
		var tuition_cents: int = int(
			round(
				float(
					contract.get(
						"tuition",
						option.get(
							"tuition",
							0.0
						)
					)
				) * 100.0
			)
		)
		var custodial_decision_required: bool = bool(
			contract.get(
				"minor_requires_custodial_decision",
				false
			)
		)
		var option_available: bool = bool(
			option.get(
				"available",
				option.get(
					"enabled",
					true
				)
			)
		)
		var preview_only: bool = bool(
			option.get(
				"preview_only",
				contract.get(
					"preview_only",
					false
				)
			)
		)
		var available_at_age: int = int(
			option.get(
				"available_at_age",
				contract.get(
					"available_at_age",
					-1
				)
			)
		)
		var years_until_available: int = int(
			option.get(
				"years_until_available",
				contract.get(
					"years_until_available",
					-1
				)
			)
		)

		option_tokens.append(
			"%s|%s|%s|%d|%d|%d|%d|%d|%d"
			% [
				option_type,
				option_name,
				option_stage,
				tuition_cents,
				1
				if custodial_decision_required
				else 0,
				1
				if option_available
				else 0,
				1
				if preview_only
				else 0,
				available_at_age,
				years_until_available
			]
		)

	option_tokens.sort()

	var option_material: String = "|".join(
		option_tokens
	)
	var option_catalog_hash: int = int(
		option_material.hash()
	)

	return (
		"%s:%s:%d:%d:%d:%d:%s:%d:%d:%d:%d"
		% [
			school_stage,
			school_option_stage,
			1
			if school_planning_mode
			else 0,
			1
			if school_preview_mode
			else 0,
			school_preview_start_age,
			school_preview_years_until,
			transition_stage,
			transition_start_age,
			1
			if transition_planning_due
			else 0,
			option_tokens.size(),
			option_catalog_hash
		]
	)
func _hub_signature(
	actor: Person,
	section_id: String,
	snapshot: Dictionary
) -> String:
	var active_school: Dictionary = _dict(
		snapshot.get(
			"active_contract",
			{}
		)
	)
	var meal_zone: Dictionary = _dict(
		snapshot.get(
			"meal_zone",
			{}
		)
	)
	var higher_learning: Dictionary = _dict(
		snapshot.get(
			"higher_learning_catalog",
			{}
		)
	)
	var clique_contract: Dictionary = _dict(
		snapshot.get(
			"clique_contract",
			{}
		)
	)
	var contract_id: String = str(
		active_school.get(
			"contract_id",
			"none"
		)
	)
	var contract_revision: int = int(
		active_school.get(
			"updated_at_ms",
			active_school.get(
				"updated_year",
				_current_year()
			)
		)
	)
	var meal_revision: int = int(
		meal_zone.get(
			"last_updated_ms",
			meal_zone.get(
				"next_tick_ms",
				0
			)
		)
	)
	var higher_revision: String = str(
		higher_learning.get(
			"revision",
			"none"
		)
	)
	var clique_revision: String = str(
		clique_contract.get(
			"revision",
			"none"
		)
	)
	var school_option_catalog_revision: String = (
		_school_option_catalog_revision(
			snapshot
		)
	)

	return (
		"school_hub:%d:%d:%d:%s:%s:%d:%d:%d:%d:%s:%s:%s"
		% [
			int(
				actor.id
			),
			_current_year(),
			int(
				actor.age
			),
			section_id,
			contract_id,
			contract_revision,
			meal_revision,
			_array(
				snapshot.get(
					"classmates",
					[]
				)
			).size(),
			_array(
				snapshot.get(
					"teachers",
					[]
				)
			).size(),
			higher_revision,
			clique_revision,
			school_option_catalog_revision
		]
	)

func _section(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()

	match clean:
		"", "overview":
			return "overview"

		"classes", "class", "classrooms":
			return "classes"

		"meal", "lunch", "lunchroom", "communal", "communal_area":
			return "meal"

		"teachers", "teacher":
			return "teachers"

		"social", "students", "classmates":
			return "social"

		"actions", "action":
			return "actions"

		_:
			return "overview"


func _person_by_id(person_id: int) -> Person:
	if person_id <= 0 or gs == null:
		return null

	return gs.get_or_reactivate_npc_by_id(person_id)


func _person_name(person: Person) -> String:
	if person == null:
		return ""

	var full_name: String = (
		"%s %s" % [str(person.first_name).strip_edges(), str(person.last_name).strip_edges()]
	)
	full_name = full_name.strip_edges()

	if full_name == "":
		full_name = str(person.name).strip_edges()

	if full_name == "":
		full_name = "Person %d" % int(person.id)

	return full_name


func _school_popularity(person: Person) -> int:
	if person == null:
		return 0

	var score: float = 0.0
	score += float(person.fame) * 0.3
	score += float(person.respect) * 0.26
	score += float(person.looks) * 0.16
	score += float(person.smarts) * 0.12
	score += float(person.satisfaction) * 0.08
	score += float(person.mental_health) * 0.08

	return clampi(int(round(score)), 0, 100)


func _school_friendliness(person: Person) -> int:
	if person == null:
		return 50

	var score: float = 50.0
	score += (float(person.satisfaction) - 50.0) * 0.24
	score += (float(person.mental_health) - 50.0) * 0.2
	score += (float(person.respect) - 50.0) * 0.22
	score += (float(person.health) - 50.0) * 0.08
	score += (float(person.smarts) - 50.0) * 0.04

	return clampi(int(round(score)), 0, 100)


func _clean_string_array(values: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_value in values:
		var text: String = str(raw_value).strip_edges()

		if text == "" or seen.has(text):
			continue

		seen [text] = true
		out.append(text)

	return out


func _join_strings(values: Array, separator: String = ", ") -> String:
	var packed: PackedStringArray = PackedStringArray()

	for raw_value in values:
		var text: String = str(raw_value).strip_edges()

		if text != "":
			packed.append(text)

	return separator.join(packed)


func _store_contract(
	signature: String,
	contract: Dictionary
) -> void:
	hub_contract_cache [
		signature
	] = contract.duplicate(false)

	while hub_contract_cache.size() > MAX_CACHE_SIZE:
		var keys: Array = hub_contract_cache.keys()

		if keys.is_empty():
			break

		hub_contract_cache.erase(
			keys.front()
		)


func _invalidate_actor_cache(actor_id: int) -> void:
	var erase_keys: Array = []
	var actor_token: String = "school_hub:%d:" % actor_id

	for raw_key in hub_contract_cache.keys():
		var key: String = str(raw_key)

		if key.begins_with(actor_token):
			erase_keys.append(key)

	for raw_key in erase_keys:
		hub_contract_cache.erase(raw_key)


func _observable_partial(actor: Person, reason: String, context: Dictionary = {}) -> Dictionary:
	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_name(actor),
		"title": "SCHOOL HUB",
		"subtitle": "School reality is reconnecting.",
		"header_chip_text": "OBSERVABLE PARTIAL",
		"active_section_id": _section(str(context.get("active_section_id", "overview"))),
		"tabs": _tabs("overview", "Communal / Lunch Area"),
		"section_rows":
		[
			{
				"row_kind": "information",
				"title": "School Reality",
				"lines": ["The resident panel exists while authoritative school truth reconnects."]
			}
		],
		"status_text": reason,
		"truth_state": "observable_partial",
		"projection_complete": false,
		"authoritative_projection": false,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}


func _failure(reason: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}


func _current_year() -> int:
	return int(gs.year) if gs != null else 0


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["school_hub_contract_engine_resident"] = true
	gs.scenario_state ["school_hub_contract_engine_schema"] = ENGINE_SCHEMA
	gs.scenario_state ["school_hub_contract_engine_version"] = CONTRACT_VERSION


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(false)

	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(false)

	return []