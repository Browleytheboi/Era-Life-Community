extends Resource
class_name CareerHubContractEngine

signal resident_career_hub_contract_published(
	actor_id: int,
	contract: Dictionary
)

const ENGINE_SCHEMA:= "eralife.career_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.career_hub_contract"
const HUB_VERSION:= 1
const LENS_STATE_KEY:= "career_hub_lens_state"

var gs
var last_report: Dictionary = {}

var resident_projection_queue: Array = []
var resident_projection_job_by_actor: Dictionary = {}
var resident_projection_service_active: bool = false


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_lens_root()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_lens_root()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"ui_is_renderer_only": true
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"lens_state": _lens_root().duplicate(true),
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	if gs == null:
		return _fail(
			"missing_game_state",
			"Career Hub state could not be imported."
		)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [LENS_STATE_KEY] = _dict(
		data.get(
			"lens_state",
			{}
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)
	_ensure_lens_root()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}

func persist_section_lens(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Career Hub observer could be resolved."
		)

	var section_id: String = _section(
		str(
			payload.get(
				"section_id",
				"overview"
			)
		)
	)
	var lane: String = str(
		payload.get(
			"lane",
			""
		)
	).strip_edges().to_lower()
	var lens: Dictionary = _lens_for(
		actor
	)

	lens ["active_section"] = section_id

	if lane in [
		"full_time",
		"part_time"
	]:
		lens ["career_lane"] = lane

	_commit_lens(
		actor,
		lens
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "career_hub_lens_section_persisted",
		"actor_id": int(
			actor.id
		),
		"active_section": section_id,
		"career_lane": str(
			lens.get(
				"career_lane",
				"full_time"
			)
		),
		"simulation_mutation_performed": false,
		"ui_is_renderer_only": true
	}
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Career Hub observer could be resolved."
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()

	var lens: Dictionary = _lens_for(
		actor
	)

	var result: Dictionary = {
		"success": true,
		"type": "career_hub_refreshed"
	}

	var inline_projection_required: bool = false
	var background_projection_required: bool = false

	match action_id:
		"", "refresh", "open_hub":
			inline_projection_required = true

		"set_section":
			lens ["active_section"] = _section(
				str(
					payload.get(
						"section_id",
						"overview"
					)
				)
			)

			result = {
				"success": true,
				"type": "career_hub_lens_updated",
			}

		"set_career_lane", "browse_lane":
			lens ["career_lane"] = _lane(
				str(
					payload.get(
						"lane",
						"full_time"
					)
				)
			)
			lens ["active_section"] = "opportunities"

			result = {
				"success": true,
				"type": "career_catalog_lens_changed",
				"career_lane": str(
					lens ["career_lane"]
				),
				"text": (
					"I browsed %s careers."
					% str(
						lens ["career_lane"]
					).replace(
						"_",
						"-"
					)
				),
			}

		"select_career_path", "preview_career_path":
			lens ["selected_path_id"] = str(
				payload.get(
					"path_id",
					""
				)
			).strip_edges()
			lens ["active_section"] = "opportunities"

			result = {
				"success": true,
				"type": "career_path_selected",
				"selected_path_id": str(
					lens.get(
						"selected_path_id",
						""
					)
				),
				"blocks_ui": false
			}

			background_projection_required = false

		"set_coworker_shard":
			lens ["coworker_shard_offset"] = maxi(
				0,
				int(
					payload.get(
						"offset",
						0
					)
				)
			)
			lens ["active_section"] = "people"

			background_projection_required = true

		"move_workplace_zone", "observe_workplace_zone":
			result = _move_zone(
				actor,
				payload,
				lens
			)

			background_projection_required = true



		"leave_workplace":
			result = {
				"success": true,
				"type": "career_workplace_lens_closed",
				"text": "",
				"reality_mutated": false,
			}

		"apply_position":
			result = (
				_law().evaluate_application(
					actor,
					str(
						payload.get(
							"position_id",
							""
						)
					),
					payload
				)
				if _law() != null
				else _fail(
					"career_law_unavailable",
					"Career law is unavailable."
				)
			)

			background_projection_required = true

		"apply_career_path":
			result = _apply_path(
				actor,
				payload
			)

			background_projection_required = true

		"apply_legacy_job", \
"perform_activity", \
"work_shift", \
"request_promotion", \
"request_raise", \
"set_weekly_hours", \
"work_harder", \
"quit_position", \
"retire":
			result = _delegate_law(
				actor,
				payload,
				action_id
			)

			background_projection_required = true

		"start_coworker_conversation":
			result = _talk_to_coworker(
				actor,
				int(
					payload.get(
						"target_id",
						-1
					)
				),
				payload
			)



			background_projection_required = false

		"start_manager_meeting":
			result = _queue_scenario(
				actor,
				"manager_checkin",
				int(
					payload.get(
						"target_id",
						-1
					)
				),
				payload
			)

		"start_staff_meeting":
			result = _queue_scenario(
				actor,
				"staff_meeting",
				int(
					payload.get(
						"target_id",
						-1
					)
				),
				payload
			)

		"start_profession_scenario":
			result = _queue_scenario(
				actor,
				str(
					payload.get(
						"scenario_kind",
						"professional_pressure"
					)
				),
				int(
					payload.get(
						"target_id",
						-1
					)
				),
				payload
			)

		_:
			result = _fail(
				"unknown_career_hub_intent",
				"The Career Hub does not recognize that action."
			)

	_commit_lens(
		actor,
		lens
	)

	var projection_context: Dictionary = {
		"active_section": _section(
			str(
				payload.get(
					"section_id",
					lens.get(
						"active_section",
						"overview"
					)
				)
			)
		),
		"career_lane": str(
			lens.get(
				"career_lane",
				"full_time"
			)
		),
		"selected_path_id": str(
			lens.get(
				"selected_path_id",
				""
			)
		),
		"zone_id": str(
			lens.get(
				"zone_id",
				""
			)
		),
		"coworker_shard_offset": int(
			lens.get(
				"coworker_shard_offset",
				0
			)
		),
		"status_text": str(
			result.get(
				"text",
				""
			)
		),
		"source": (
			"career_hub_contract_engine.resolve_intent"
		),
		"background_only": true,
		"blocks_ui": false,
		"ready_gate_member": false
	}

	if inline_projection_required:
		result ["career_hub_contract"] = resolve_career_hub(
			actor,
			projection_context
		)
		result [
			"career_hub_contract_publication_pending"
		] = false

	elif background_projection_required:
		_queue_resident_career_hub_contract_publication(
			int(
				actor.id
			),
			projection_context
		)

		result [
			"career_hub_contract_publication_pending"
		] = true
		result [
			"career_hub_contract_rebuilt_before_action_receipt"
		] = false
		result [
			"career_hub_contract_blocks_ui"
		] = false

	result ["career_hub_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result
func _coworker_conversation_topics() -> Array:
	match _era():
		"Ancient Era":
			return [
				"the coming harvest",
				"the price of goods in the market",
				"traveling merchants and caravans",
				"the local ruler and court",
				"temple festivals",
				"the weather and river conditions"
			]

		"Medieval Era":
			return [
				"guild orders",
				"market day",
				"the harvest",
				"the local lord and court",
				"road conditions",
				"the latest feast or festival"
			]

		"Industrial Era":
			return [
				"factory shifts",
				"rail timetables",
				"wages and prices",
				"new machinery",
				"the morning newspaper",
				"changes around the city"
			]

		"Future Era":
			return [
				"habitat systems",
				"orbital routes",
				"synthetic food",
				"AI policy",
				"off-world news",
				"holo entertainment"
			]

		_:
			return [
				"weekend plans",
				"local news",
				"sports",
				"workplace gossip",
				"restaurants",
				"the commute"
			]


func _talk_to_coworker(
	actor: Person,
	target_id: int,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or target_id <= 0
		or _runtime() == null
	):
		return _fail(
			"coworker_unavailable",
			"That coworker is not currently available."
		)

	var target: Person = _person(
		target_id
	)

	if target == null:
		return _fail(
			"coworker_unavailable",
			"That coworker is not currently available."
		)

	var actor_assignment: Dictionary = (
		_runtime().assignment_for_actor(
			actor
		)
	)
	var target_assignment: Dictionary = (
		_runtime().assignment_for_actor(
			target
		)
	)

	if (
		actor_assignment.is_empty()
		or target_assignment.is_empty()
		or str(
			actor_assignment.get(
				"organization_id",
				""
			)
		) != str(
			target_assignment.get(
				"organization_id",
				""
			)
		)
		or str(
			actor_assignment.get(
				"path_id",
				""
			)
		) != str(
			target_assignment.get(
				"path_id",
				""
			)
		)
	):
		return _fail(
			"target_is_not_current_coworker",
			"That person is not currently part of this profession."
		)

	var topics: Array = (
		_coworker_conversation_topics()
	)

	if topics.is_empty():
		return _fail(
			"conversation_topics_unavailable",
			"No conversation topic is currently observable."
		)

	var topic_key: String = (
		"%d:%d:%d:%s"
		% [
			int(
				actor.id
			),
			target_id,
			int(
				gs.year
			),
			_era()
		]
	)

	var topic_index: int = (
		absi(
			int(
				topic_key.hash()
			)
		)
		% topics.size()
	)

	var topic: String = str(
		topics [
			topic_index
		]
	)

	var target_first_name: String = str(
		target.first_name
	).strip_edges()

	if target_first_name == "":
		target_first_name = _name(
			target
		)

	var narrative_text: String = (
		"You and %s talked about %s."
		% [
			target_first_name,
			topic
		]
	)

	var interaction: Dictionary = (
		payload.duplicate(false)
	)

	interaction [
		"interaction_id"
	] = "coworker_conversation"
	interaction [
		"scenario_kind"
	] = "coworker_conversation"
	interaction [
		"target_id"
	] = target_id
	interaction [
		"topic"
	] = topic
	interaction [
		"narrative_text"
	] = narrative_text


	interaction [
		"performance_delta"
	] = 0
	interaction [
		"satisfaction_delta"
	] = 0
	interaction [
		"stress_delta"
	] = 0.0
	interaction [
		"reputation_delta"
	] = {}
	interaction [
		"relationship_delta"
	] = 0
	interaction [
		"source"
	] = (
		"career_hub_contract_engine."
		+ "coworker_conversation"
	)

	var result: Dictionary = (
		_runtime().commit_professional_interaction(
			actor,
			interaction
		)
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		result [
			"text"
		] = narrative_text
		result [
			"topic"
		] = topic
		result [
			"target_name"
		] = _name(
			target
		)
		result [
			"career_surface_rebuild_required"
		] = false
		result [
			"blocks_ui"
		] = false

	return result
func _queue_resident_career_hub_contract_publication(
	actor_id: int,
	context: Dictionary = {}
) -> void:
	if (
		actor_id <= 0
		or gs == null
	):
		return

	var actor_key: String = str(
		actor_id
	)

	var job_context: Dictionary = (
		context.duplicate(false)
	)

	job_context ["actor_id"] = actor_id
	job_context ["background_only"] = true
	job_context ["blocks_ui"] = false
	job_context ["ready_gate_member"] = false
	job_context [
		"ui_interaction_grace_ignored"
	] = true
	job_context [
		"build_on_click_forbidden"
	] = true

	resident_projection_job_by_actor [
		actor_key
	] = job_context

	if actor_key not in resident_projection_queue:
		resident_projection_queue.append(
			actor_key
		)

	if resident_projection_service_active:
		return

	resident_projection_service_active = true

	call_deferred(
		"_service_resident_career_hub_contract_publication"
	)
func _service_resident_career_hub_contract_publication() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		resident_projection_service_active = false
		return

	while not resident_projection_queue.is_empty():


		await tree.process_frame
		await RenderingServer.frame_post_draw

		if resident_projection_queue.is_empty():
			break

		var actor_key: String = str(
			resident_projection_queue.pop_front()
		)

		var context: Dictionary = _dict(
			resident_projection_job_by_actor.get(
				actor_key,
				{}
			)
		).duplicate(false)

		resident_projection_job_by_actor.erase(
			actor_key
		)

		var actor_id: int = int(
			context.get(
				"actor_id",
				actor_key
			)
		)

		var actor: Person = _person(
			actor_id
		)

		if actor == null:
			await tree.process_frame
			continue

		var contract: Dictionary = resolve_career_hub(
			actor,
			context
		)

		if (
			not contract.is_empty()
			and bool(
				contract.get(
					"authoritative_projection",
					false
				)
			)
		):
			resident_career_hub_contract_published.emit(
				actor_id,
				contract
			)

		await tree.process_frame

	resident_projection_service_active = false

	if not resident_projection_queue.is_empty():
		resident_projection_service_active = true

		call_deferred(
			"_service_resident_career_hub_contract_publication"
		)
func _presentation_contract() -> Dictionary:
	var era_name: String = _era()

	var contract: Dictionary = {
		"era_name": era_name,
		"hub_title": "CAREER HUB",
		"overview_label": "OVERVIEW",
		"workplace_label": "WORKPLACE",
		"people_label": "PEOPLE",
		"workflow_label": "TODAY",
		"organization_label": "ORGANIZATION",
		"opportunity_label": "OPPORTUNITIES",
		"education_label": "EDUCATION",
		"reputation_label": "REPUTATION",
		"promotion_label": "PROMOTION",
		"timeline_label": "TIMELINE",

		"raise_action_label": "REQUEST RAISE",
		"promotion_action_label": (
			"REQUEST PROMOTION REVIEW"
		),
		"quit_action_label": "QUIT POSITION",
		"weekly_hours_label": "WEEKLY HOURS",
		"work_harder_label": "WORK HARDER",

		"group_opportunities_by_social_class": false,

		"colors": {
			"shell_bg": Color(
				0.014,
				0.019,
				0.036,
				0.995
			),
			"shell_border": Color(
				0.27,
				0.47,
				0.82,
				0.92
			),
			"card_bg": Color(
				0.045,
				0.058,
				0.094,
				0.98
			),
			"card_border": Color(
				0.25,
				0.39,
				0.66,
				0.7
			),
			"accent": Color(
				1.0,
				0.78,
				0.34,
				1.0
			),
			"secondary": Color(
				0.52,
				0.74,
				1.0,
				1.0
			),
			"eligible": Color(
				0.2,
				0.86,
				0.42,
				1.0
			),
			"ineligible": Color(
				0.96,
				0.28,
				0.28,
				1.0
			)
		}
	}

	match era_name:
		"Ancient Era":
			contract ["hub_title"] = (
				"VOCATION & DUTY"
			)
			contract ["workplace_label"] = (
				"PLACE OF DUTY"
			)
			contract ["workflow_label"] = "DUTIES"
			contract ["organization_label"] = (
				"INSTITUTION"
			)
			contract ["opportunity_label"] = (
				"OCCUPATIONS"
			)
			contract ["education_label"] = (
				"TRAINING"
			)
			contract ["reputation_label"] = (
				"STANDING"
			)
			contract ["promotion_label"] = (
				"ADVANCEMENT"
			)
			contract ["timeline_label"] = (
				"CHRONICLE"
			)
			contract ["raise_action_label"] = (
				"ASK FOR A MONTHLY INCREASE"
			)
			contract [
				"group_opportunities_by_social_class"
			] = true
			contract ["colors"] = {
				"shell_bg": Color(
					0.055,
					0.032,
					0.018,
					0.995
				),
				"shell_border": Color(
					0.72,
					0.47,
					0.17,
					0.95
				),
				"card_bg": Color(
					0.09,
					0.054,
					0.025,
					0.98
				),
				"card_border": Color(
					0.66,
					0.39,
					0.13,
					0.8
				),
				"accent": Color(
					1.0,
					0.72,
					0.28,
					1.0
				),
				"secondary": Color(
					0.88,
					0.63,
					0.32,
					1.0
				),
				"eligible": Color(
					0.32,
					0.88,
					0.42,
					1.0
				),
				"ineligible": Color(
					0.95,
					0.3,
					0.22,
					1.0
				)
			}

		"Medieval Era":
			contract ["hub_title"] = (
				"LIVELIHOOD & STANDING"
			)
			contract ["workplace_label"] = (
				"HALL & GUILD"
			)
			contract ["workflow_label"] = "DUTIES"
			contract ["organization_label"] = (
				"GUILD & HOUSEHOLD"
			)
			contract ["opportunity_label"] = (
				"LIVELIHOODS"
			)
			contract ["education_label"] = (
				"TRAINING"
			)
			contract ["reputation_label"] = (
				"STANDING"
			)
			contract ["promotion_label"] = (
				"ADVANCEMENT"
			)
			contract ["timeline_label"] = (
				"CHRONICLE"
			)
			contract ["raise_action_label"] = (
				"ASK FOR A MONTHLY INCREASE"
			)
			contract [
				"group_opportunities_by_social_class"
			] = true
			contract ["colors"] = {
				"shell_bg": Color(
					0.035,
					0.025,
					0.031,
					0.995
				),
				"shell_border": Color(
					0.58,
					0.35,
					0.24,
					0.95
				),
				"card_bg": Color(
					0.065,
					0.045,
					0.055,
					0.98
				),
				"card_border": Color(
					0.54,
					0.31,
					0.25,
					0.82
				),
				"accent": Color(
					0.94,
					0.72,
					0.34,
					1.0
				),
				"secondary": Color(
					0.74,
					0.55,
					0.38,
					1.0
				),
				"eligible": Color(
					0.3,
					0.84,
					0.4,
					1.0
				),
				"ineligible": Color(
					0.92,
					0.25,
					0.25,
					1.0
				)
			}

		"Industrial Era":
			contract ["hub_title"] = (
				"EMPLOYMENT & TRADE"
			)
			contract ["workplace_label"] = "WORKS"
			contract ["workflow_label"] = "SHIFT"
			contract ["organization_label"] = (
				"INSTITUTION"
			)
			contract ["opportunity_label"] = "JOBS"
			contract ["timeline_label"] = "RECORD"
			contract ["colors"] = {
				"shell_bg": Color(
					0.03,
					0.033,
					0.036,
					0.995
				),
				"shell_border": Color(
					0.56,
					0.48,
					0.37,
					0.92
				),
				"card_bg": Color(
					0.06,
					0.061,
					0.06,
					0.98
				),
				"card_border": Color(
					0.48,
					0.41,
					0.34,
					0.78
				),
				"accent": Color(
					0.88,
					0.58,
					0.3,
					1.0
				),
				"secondary": Color(
					0.66,
					0.72,
					0.76,
					1.0
				),
				"eligible": Color(
					0.26,
					0.82,
					0.38,
					1.0
				),
				"ineligible": Color(
					0.91,
					0.27,
					0.24,
					1.0
				)
			}

		"Future Era":
			contract ["hub_title"] = (
				"PROFESSIONAL NETWORK"
			)
			contract ["workplace_label"] = (
				"PROFESSIONAL SPACE"
			)
			contract ["people_label"] = "NETWORK"
			contract ["workflow_label"] = (
				"ACTIVE CYCLE"
			)
			contract ["opportunity_label"] = (
				"CAREER PATHS"
			)
			contract ["promotion_label"] = (
				"ADVANCEMENT"
			)
			contract ["colors"] = {
				"shell_bg": Color(
					0.02,
					0.018,
					0.052,
					0.995
				),
				"shell_border": Color(
					0.46,
					0.42,
					0.98,
					0.95
				),
				"card_bg": Color(
					0.04,
					0.035,
					0.09,
					0.98
				),
				"card_border": Color(
					0.35,
					0.48,
					0.96,
					0.82
				),
				"accent": Color(
					0.64,
					0.56,
					1.0,
					1.0
				),
				"secondary": Color(
					0.26,
					0.86,
					1.0,
					1.0
				),
				"eligible": Color(
					0.22,
					0.94,
					0.58,
					1.0
				),
				"ineligible": Color(
					1.0,
					0.3,
					0.48,
					1.0
				)
			}

	return contract
func _active_career_system_policy(
	actor: Person
) -> Dictionary:
	if (
		gs == null
		or gs.era_contract_engine == null
		or not gs.era_contract_engine.has_method(
			"system_policy"
		)
	):
		return {
			"system_id": "career",
			"mode": "base",
			"visible": true
		}

	var policy: Dictionary = _dict(
		gs.era_contract_engine.system_policy(
			"career"
		)
	)
	policy ["actor_id"] = (
		int(actor.id)
		if actor != null
		else -1
	)

	return policy
func _career_replaced_by_roles_contract(
	actor: Person,
	_context: Dictionary,
	policy: Dictionary
) -> Dictionary:
	var role_rows: Array = []

	if (
		gs != null
		and gs.era_mod_contract_engine != null
		and gs.era_mod_contract_engine.has_method(
			"active_role_contracts"
		)
	):
		role_rows = (
			gs.era_mod_contract_engine
			.active_role_contracts(actor)
		)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _name(actor),
		"title": "🪨 TRIBAL ROLES",
		"subtitle": str(
			policy.get(
				"reason",
				(
					"Formal careers are unavailable "
					+ "in this reality."
				)
			)
		),
		"current_time": _time_text(),
		"era_name": _era(),
		"active_section": "roles",
		"career_lane": "none",
		"selected_path_id": "",
		"section_tabs": [
			{
				"id": "roles",
				"label": "ROLES",
				"icon": "🪨"
			}
		],
		"identity_overview": {
			"actor_id": int(actor.id),
			"name": _name(actor),
			"system_mode": "roles_only",
			"replacement_system_id": str(
				policy.get(
					"replacement_system_id",
					"roles"
				)
			)
		},
		"overview_cards": [],
		"organization_contract": {},
		"profession_contract": {},
		"promotion_contract": {},
		"reputation_contract": {},
		"workplace_contract": {},
		"workflow_contract": {},
		"opportunity_contract": {
			"roles": role_rows
		},
		"education_rows": [],
		"timeline_rows": [],
		"status_text": (
			"Contribution roles are active. "
			+ "The base Career ecosystem remains preserved."
		),
		"truth_state": "hot",
		"authoritative_projection": true,
		"surface_revision": "%d:roles:%d" % [
			int(actor.id),
			role_rows.size()
		],
		"replacement_authority": (
			"era_mod_contract_engine"
		),
		"ui_is_renderer_only": true
	}
func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	return _partial(
		actor,
		context
	)
func _activity_rows_with_usage(
	assignment: Dictionary,
	rows: Array
) -> Array:
	var out: Array = []

	var usage_by_year: Dictionary = _dict(
		assignment.get(
			"activity_usage_by_year",
			{}
		)
	)

	var year_key: String = str(
		int(
			gs.year
		)
	)

	var year_usage: Dictionary = _dict(
		usage_by_year.get(
			year_key,
			usage_by_year.get(
				int(
					gs.year
				),
				{}
			)
		)
	)

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		).duplicate(false)

		if row.is_empty():
			continue

		var activity_id: String = str(
			row.get(
				"activity_id",
				row.get(
					"id",
					""
				)
			)
		).strip_edges().to_lower()

		var productive_limit: int = maxi(
			1,
			int(
				row.get(
					"productive_uses_per_year",
					3
				)
			)
		)

		var uses: int = maxi(
			0,
			int(
				year_usage.get(
					activity_id,
					0
				)
			)
		)

		var remaining: int = maxi(
			0,
			productive_limit - uses
		)

		var productive_effects_available: bool = (
			remaining > 0
		)

		row [
			"productive_uses_this_year"
		] = uses
		row [
			"productive_uses_per_year"
		] = productive_limit
		row [
			"productive_uses_remaining"
		] = remaining
		row [
			"productive_effects_available"
		] = productive_effects_available
		row [
			"enabled"
		] = true

		if productive_effects_available:
			row [
				"action_label"
			] = (
				"PERFORM • %d PRODUCTIVE USE%s LEFT"
				% [
					remaining,
					"" if remaining == 1 else "S"
				]
			)

		else:
			row [
				"action_label"
			] = "PERFORM • NO MORE STAT GAINS"

			row [
				"impact_lines"
			] = [
				(
					"Productive gains are exhausted for "
					+ "this duty in %d."
				) % int(
					gs.year
				),
				(
					"Repeating it will not add performance, "
					+ "satisfaction, stress, reputation, "
					+ "experience, or legacy."
				)
			]

		out.append(
			row
		)

	return out

func resolve_career_hub(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or _runtime() == null
		or _law() == null
	):
		return _partial(
			actor,
			context
		)

	var career_policy: Dictionary = (
		_active_career_system_policy(
			actor
		)
	)

	var career_mode: String = str(
		career_policy.get(
			"mode",
			"base"
		)
	).strip_edges().to_lower()

	if career_mode in [
		"disabled",
		"roles_only"
	]:
		return _career_replaced_by_roles_contract(
			actor,
			context,
			career_policy
		)

	var lens: Dictionary = _lens_for(
		actor
	)

	var active_section: String = _section(
		str(
			context.get(
				"active_section",
				lens.get(
					"active_section",
					"overview"
				)
			)
		)
	)

	var lane: String = _lane(
		str(
			context.get(
				"career_lane",
				lens.get(
					"career_lane",
					"full_time"
				)
			)
		)
	)

	var selected_path_id: String = str(
		context.get(
			"selected_path_id",
			lens.get(
				"selected_path_id",
				""
			)
		)
	).strip_edges()

	var assignment: Dictionary = (
		_runtime().assignment_for_actor(
			actor
		)
	)

	var organization: Dictionary = (
		_runtime().organization_for_actor(
			actor
		)
	)

	var position: Dictionary = (
		_runtime().position_for_actor(
			actor
		)
	)

	var path: Dictionary = {}

	if not assignment.is_empty():
		path = _law().get_path_definition(
			str(
				assignment.get(
					"path_id",
					""
				)
			)
		)

	elif selected_path_id != "":
		path = _law().get_path_definition(
			selected_path_id
		)

	var lower: Dictionary = _law().emit_panel_contract(
		actor,
		{
			"active_section": _lower_section(
				active_section
			),
			"source": (
				"career_hub_contract_engine.lower_projection"
			),
			"projection_read_only": true,
			"build_on_click_forbidden": true,
			"ready_gate_member": false
		}
	)



	var full_time_catalog: Dictionary = (
		_law().emit_career_catalog_contract(
			actor,
			"full_time",
			{
				"selected_path_id": selected_path_id,
				"source": (
					"career_hub_contract_engine."
					+ "resident_full_time_catalog"
				),
				"projection_read_only": true,
				"build_on_click_forbidden": true
			}
		)
	)

	var part_time_catalog: Dictionary = (
		_law().emit_career_catalog_contract(
			actor,
			"part_time",
			{
				"selected_path_id": selected_path_id,
				"source": (
					"career_hub_contract_engine."
					+ "resident_part_time_catalog"
				),
				"projection_read_only": true,
				"build_on_click_forbidden": true
			}
		)
	)

	var opportunity_contract_by_lane: Dictionary = {
		"full_time": full_time_catalog,
		"part_time": part_time_catalog
	}

	var catalog: Dictionary = _dict(
		opportunity_contract_by_lane.get(
			lane,
			full_time_catalog
		)
	)

	var space_contract: Dictionary = (
		_space().resolve_space_contract(
			actor,
			{
				"preview_path_id": selected_path_id,
				"zone_id": str(
					context.get(
						"zone_id",
						lens.get(
							"zone_id",
							""
						)
					)
				),
				"coworker_shard_offset": int(
					context.get(
						"coworker_shard_offset",
						lens.get(
							"coworker_shard_offset",
							0
						)
					)
				),
				"coworker_shard_size": 24,
				"projection_read_only": true,
				"build_on_click_forbidden": true
			}
		)
		if _space() != null
		else {}
	)

	var profile: Dictionary = (
		_runtime().resident_actor_profile(
			actor
		)
	)

	var profession: Dictionary = _profession(
		path,
		assignment,
		space_contract
	)

	var promotion: Dictionary = _promotion(
		actor,
		path,
		assignment,
		profile
	)

	var reputation: Dictionary = _reputation(
		profile
	)

	var payroll: Dictionary = _payroll(
		actor,
		assignment
	)

	var people: Dictionary = _people(
		actor,
		space_contract,
		assignment
	)

	var education_rows: Array = _array(
		lower.get(
			"education_rows",
			[]
		)
	)

	var presentation: Dictionary = (
		_presentation_contract()
	)

	var workload: Dictionary = (
		_workload_contract(
			assignment,
			presentation
		)
	)

	var primary_job_actions: Array = (
		_primary_job_actions(
			lower,
			presentation
		)
	)

	var activity_rows: Array = (
		_activity_rows_with_usage(
			assignment,
			_array(
				lower.get(
					"activity_rows",
					[]
				)
			)
		)
	)

	var activity_history_size: int = _array(
		assignment.get(
			"activity_history",
			[]
		)
	).size()

	var assignment_id: String = str(
		assignment.get(
			"assignment_id",
			"none"
		)
	)
	var full_time_catalog_revision: String = str(
		full_time_catalog.get(
			"catalog_revision",
			""
		)
	)

	var part_time_catalog_revision: String = str(
		part_time_catalog.get(
			"catalog_revision",
			""
		)
	)

	var people_revision: String = str(
		people.get(
			"people_revision",
			""
		)
	)
	var surface_revision: String = (
		"%d:%d:%d:%s:%s:%s:%s:%s:%s:%s:%d:%d:%d:%d:%d:%d"
		% [
			int(
				actor.id
			),
			int(
				actor.age
			),
			int(
				gs.year
			),
			active_section,
			lane,
			selected_path_id,
			assignment_id,
			full_time_catalog_revision,
			part_time_catalog_revision,
			people_revision,
			int(
				assignment.get(
					"performance",
					0
				)
			),
			int(
				assignment.get(
					"experience",
					0
				)
			),
			int(
				assignment.get(
					"satisfaction",
					0
				)
			),
			int(
				round(
					float(
						assignment.get(
							"work_stress",
							0.0
						)
					)
				)
			),
			activity_history_size,
			int(
				reputation.get(
					"score",
					0
				)
			)
		]
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(
			actor.id
		),
		"actor_name": _name(
			actor
		),
		"title": " %s" % str(
			presentation.get(
				"hub_title",
				"CAREER HUB"
			)
		),
		"subtitle": _subtitle(
			actor,
			assignment,
			organization,
			path
		),
		"current_time": _time_text(),
		"era_name": _era(),
		"active_section": active_section,
		"career_lane": lane,
		"qualification_actor_id": int(
			actor.id
		),
		"qualification_actor_age": int(
			actor.age
		),
		"full_time_catalog_revision": (
			full_time_catalog_revision
		),
		"part_time_catalog_revision": (
			part_time_catalog_revision
		),
		"selected_path_id": selected_path_id,
		"section_tabs": _tabs(
			presentation
		),
		"presentation_contract": presentation,
		"identity_overview": _identity_overview(
			actor,
			assignment,
			organization,
			path,
			reputation
		),

		"overview_cards": _overview(
			actor,
			assignment,
			organization,
			path,
			promotion,
			payroll,
			profession
		),

		"workload_contract": workload,
		"primary_job_actions": primary_job_actions,

		"organization_contract": {
			"organization": organization,
			"position": position,
			"hierarchy_rows": _array(
				space_contract.get(
					"hierarchy_rows",
					[]
				)
			),
			"department_rows": _array(
				space_contract.get(
					"department_rows",
					[]
				)
			),
			"benefit_rows": _benefits(
				path,
				assignment
			),
			"payroll": payroll,
			"news_rows": [],
		},

		"workplace_contract": space_contract,
		"people_contract": people,

		"workflow_contract": {
			"today_schedule": [],
			"activity_rows": activity_rows,
			"profession_lens": profession,
			"scenario_actions": _scenario_actions(
				assignment,
				people,
				profession
			)
		},

		"promotion_contract": promotion,
		"reputation_contract": reputation,

		"education_contract": {
			"education_rows": education_rows,
			"certification_rows": _certifications(
				path,
				education_rows,
				actor
			)
		},

		"opportunity_contract": catalog,
		"opportunity_contract_by_lane": (
			opportunity_contract_by_lane
		),

		"timeline_contract": {
			"timeline_rows": _timeline(
				profile,
				assignment,
				organization
			),
			"award_rows": _awards(
				profile,
				assignment
			),
			"legacy_rows": _array(
				lower.get(
					"legacy_rows",
					[]
				)
			),
			"retirement": _retirement(
				actor,
				assignment
			)
		},

		"status_text": str(
			context.get(
				"status_text",
				""
			)
		),

		"career_contract": lower,
		"hub_orchestration_authority": ENGINE_SCHEMA,
		"simulation_mutation_authority": (
			"career_runtime_engine"
		),
		"career_law_authority": (
			"career_contract_engine"
		),
		"space_authority": (
			"career_space_contract_engine"
		),
		"scenario_authority": "scenario_engine",


		"truth_state": "hot",
		"surface_revision": surface_revision,
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}


func _apply_path(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if _law() == null:
		return _fail(
			"career_law_unavailable",
			"Career law is unavailable."
		)

	var path_id: String = str(
		payload.get(
			"path_id",
			""
		)
	)
	var path: Dictionary = _law().get_path_definition(
		path_id
	)

	if path.is_empty():
		return _fail(
			"career_path_not_found",
			"That professional path could not be found."
		)

	return _law().apply_for_legacy_job(
		actor,
		str(
			path.get(
				"display_name",
				path_id
			)
		),
		_lane(
			str(
				payload.get(
					"lane",
					"full_time"
				)
			)
		),
		payload
	)


func _delegate_law(
	actor: Person,
	payload: Dictionary,
	action_id: String
) -> Dictionary:
	if _law() == null:
		return _fail(
			"career_law_unavailable",
			"Career law is unavailable."
		)

	var forwarded: Dictionary = payload.duplicate(true)
	forwarded ["action_id"] = action_id

	return _law().resolve_intent(
		actor,
		forwarded
	)


func _move_zone(
	actor: Person,
	payload: Dictionary,
	lens: Dictionary
) -> Dictionary:
	if _space() == null:
		return _fail(
			"career_space_unavailable",
			"Career-space authority is unavailable."
		)

	var zone_id: String = str(
		payload.get(
			"zone_id",
			""
		)
	).strip_edges().to_lower()
	var result: Dictionary = _space().move_actor_to_zone(
		actor,
		zone_id,
		{
			"coworker_shard_offset": int(
				lens.get(
					"coworker_shard_offset",
					0
				)
			)
		}
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		lens ["zone_id"] = zone_id
		lens ["active_section"] = "workplace"

	return result


func _queue_scenario(
	actor: Person,
	kind: String,
	target_id: int,
	_context: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.scenario_engine == null
		or not gs.scenario_engine.has_method(
			"queue_external_scenario"
		)
	):
		return _fail(
			"scenario_engine_unavailable",
			"Workplace scenario authority is unavailable."
		)

	var scenario: Dictionary = _scenario(
		actor,
		_person(
			target_id
		),
		kind
	)

	if scenario.is_empty():
		return _fail(
			"career_scenario_not_found",
			"No workplace scenario exists for that moment."
		)

	return gs.scenario_engine.queue_external_scenario(
		scenario
	)


func _scenario(
	actor: Person,
	target: Person,
	kind_raw: String
) -> Dictionary:
	var kind: String = str(
		kind_raw
	).strip_edges().to_lower()
	var title: String = "WORKPLACE MOMENT"
	var prompt: String = ""
	var choices: Array = []

	match kind:
		"coworker_gossip":
			title = "BREAK ROOM CONVERSATION"
			prompt = (
				"%s says, "
				+ "\"I heard someone in the department "
				+ "just got promoted.\"\n\n"
				+ "How do you respond?"
			) % _name(
				target
			)
			choices = [
				_choice(
					"congratulate",
					"Congratulate them",
					2,
					1,
					-1,
					{
						"kindness": 2,
						"reliability": 1
					},
					4
				),
				_choice(
					"ignore",
					"Ignore it",
					0,
					0,
					0,
					{},
					-1
				),
				_choice(
					"scoff",
					"Scoff",
					-2,
					-1,
					1,
					{
						"kindness": -2,
						"carelessness": 1
					},
					-5
				),
				_choice(
					"downplay",
					"Downplay it",
					-1,
					-1,
					0,
					{
						"corruption": 1
					},
					-4
				),
				_choice(
					"joke",
					"Make a joke",
					1,
					1,
					-1,
					{
						"kindness": 1
					},
					2
				)
			]

		"manager_checkin":
			title = "PERFORMANCE CHECK-IN"
			prompt = (
				"A manager asks, "
				+ "\"How is the current assignment going?\""
			)
			choices = [
				_choice(
					"ahead",
					"We're ahead",
					3,
					1,
					0,
					{
						"reliability": 2,
						"leadership": 1
					},
					0
				),
				_choice(
					"behind",
					"We're behind",
					-1,
					0,
					-1,
					{
						"reliability": 1
					},
					0
				),
				_choice(
					"need_staff",
					"We need more staff",
					1,
					0,
					-1,
					{
						"leadership": 2,
						"efficiency": 1
					},
					0
				),
				_choice(
					"lie",
					"Lie",
					4,
					-2,
					2,
					{
						"corruption": 3,
						"reliability": -2
					},
					0
				)
			]

		"staff_meeting":
			title = "STAFF MEETING"
			prompt = (
				"The department reviews performance, pressure, "
				+ "and resources. How do you participate?"
			)
			choices = [
				_choice(
					"present",
					"Present your work",
					3,
					1,
					1,
					{
						"leadership": 2,
						"reliability": 1
					},
					0
				),
				_choice(
					"question",
					"Ask a difficult question",
					2,
					0,
					1,
					{
						"innovation": 2,
						"bravery": 1
					},
					0
				),
				_choice(
					"quiet",
					"Stay quiet",
					0,
					0,
					-1,
					{},
					0
				),
				_choice(
					"challenge",
					"Challenge management",
					1,
					-1,
					2,
					{
						"bravery": 2
					},
					-2
				)
			]

		"emergency_case", "professional_pressure":
			title = "PROFESSIONAL CRISIS"
			prompt = (
				"An urgent problem reaches your department. "
				+ "The outcome can affect performance, reputation, "
				+ "and relationships."
			)
			choices = [
				_choice(
					"step_up",
					"Take responsibility",
					5,
					2,
					4,
					{
						"bravery": 2,
						"reliability": 2
					},
					0
				),
				_choice(
					"call_help",
					"Call for help",
					2,
					1,
					1,
					{
						"reliability": 2,
						"leadership": 1
					},
					1
				),
				_choice(
					"delegate",
					"Delegate it",
					1,
					0,
					0,
					{
						"leadership": 1
					},
					0
				),
				_choice(
					"avoid",
					"Avoid responsibility",
					-5,
					-2,
					-2,
					{
						"carelessness": 3,
						"reliability": -3
					},
					-3
				)
			]

		_:
			return {}

	return {
		"id": "career_%s_%d_%d" % [
			kind,
			int(
				actor.id
			),
			int(
				Time.get_ticks_msec()
			)
		],
		"source": "career_hub_contract_engine",
		"resolver_owner": (
			"career_hub_contract_engine"
		),
		"resolver_method": (
			"_resolve_career_scenario_choice"
		),
		"category": "career",
		"actor_id": int(
			actor.id
		),
		"target_id": (
			int(
				target.id
			)
			if target != null
			else -1
		),
		"career_scenario_kind": kind,
		"panel_title": title,
		"prompt": prompt,
		"footer_text": (
			"This choice changes professional and social reality."
		),
		"choices": choices
	}


func _resolve_career_scenario_choice(
	actor: Person,
	scenario: Dictionary,
	choice: Dictionary,
	_committed: Dictionary
) -> Dictionary:
	if actor == null or _runtime() == null:
		return _fail(
			"career_scenario_actor_unavailable",
			"The workplace moment could not be committed."
		)

	var result: Dictionary = (
		_runtime().commit_professional_interaction(
			actor,
			{
				"interaction_id": str(
					choice.get(
						"id",
						"career_choice"
					)
				),
				"scenario_kind": str(
					scenario.get(
						"career_scenario_kind",
						"career"
					)
				),
				"target_id": int(
					scenario.get(
						"target_id",
						-1
					)
				),
				"performance_delta": int(
					choice.get(
						"performance_delta",
						0
					)
				),
				"satisfaction_delta": int(
					choice.get(
						"satisfaction_delta",
						0
					)
				),
				"stress_delta": float(
					choice.get(
						"stress_delta",
						0.0
					)
				),
				"reputation_delta": _dict(
					choice.get(
						"reputation_delta",
						{}
					)
				),
				"relationship_delta": int(
					choice.get(
						"relationship_delta",
						0
					)
				),
				"source": (
					"career_hub_contract_engine.career_scenario"
				)
			}
		)
	)
	var label: String = str(
		choice.get(
			"label",
			"Respond"
		)
	)

	result ["type"] = "scenario_commit_complete"
	result ["popup_title"] = "WORKPLACE OUTCOME"
	result ["popup_text"] = (
		"Choice: %s\n\n%s"
		% [
			label,
			str(
				result.get(
					"text",
					"Your professional world changed."
				)
			)
		]
	)
	result ["popup_footer"] = (
		"Your professional world remembers this."
	)
	result ["opps"] = []

	return result


func _choice(
	id: String,
	label: String,
	performance: int,
	satisfaction: int,
	stress: int,
	reputation: Dictionary,
	relationship: int
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"performance_delta": performance,
		"satisfaction_delta": satisfaction,
		"stress_delta": stress,
		"reputation_delta": reputation.duplicate(true),
		"relationship_delta": relationship
	}


func _overview(
	actor: Person,
	assignment: Dictionary,
	organization: Dictionary,
	path: Dictionary,
	promotion: Dictionary,
	payroll: Dictionary,
	profession: Dictionary
) -> Array:
	if assignment.is_empty():
		return [
			{
				"title": "Career Discovery",
				"icon": " ",
				"description": (
					"Browse every profession in this era. "
					+ "Age controls applications, never browsing."
				),
				"metrics": [
					_metric(
						"Current Age",
						str(
							actor.age
						)
					),
					_metric(
						"Current Era",
						_era()
					)
				],
				"actions": [
					{
						"action_id": "reveal_section",
						"target_section_id": "opportunities",
						"label": "BROWSE OCCUPATIONS",
						"enabled": true
					}
				]
			}
		]

	return [
		{
			"title": str(
				assignment.get(
					"rank_title",
					actor.job
				)
			),
			"icon": " ",
			"description": str(
				path.get(
					"description",
					(
						"A living position inside a "
						+ "persistent institution."
					)
				)
			),
			"metrics": [
				_metric(
					"Organization",
					str(
						organization.get(
							"name",
							"Institution"
						)
					)
				),
				_metric(
					"Department",
					str(
						assignment.get(
							"department_name",
							"General"
						)
					)
				),
				_metric(
					"Performance",
					str(
						assignment.get(
							"performance",
							actor.job_performance
						)
					)
				),
				_metric(
					"Payroll",
					str(
						payroll.get(
							"annual_text",
							"Unresolved"
						)
					)
				)
			],
			"actions": [
				{
					"action_id": "reveal_section",
					"target_section_id": "actions",
					"label": "OPEN POSITION ACTIONS",
					"enabled": true
				}
			]
		},
		{
			"title": "Promotion Progress",
			"icon": " ",
			"description": str(
				promotion.get(
					"summary",
					"Promotion truth is resolving."
				)
			),
			"progress": float(
				promotion.get(
					"progress",
					0.0
				)
			),
			"metrics": [
				_metric(
					"Current Rank",
					str(
						promotion.get(
							"current_rank_title",
							actor.job
						)
					)
				),
				_metric(
					"Next Rank",
					str(
						promotion.get(
							"next_rank_title",
							"Top Rank"
						)
					)
				),
				_metric(
					"Vacancy",
					(
						"Open"
						if bool(
							promotion.get(
								"vacancy_open",
								false
							)
						)
						else "Closed"
					)
				)
			],
			"actions": [
				{
					"action_id": "reveal_section",
					"target_section_id": "promotion",
					"label": "VIEW PROMOTION LADDER",
					"enabled": true
				}
			]
		},
		{
			"title": str(
				profession.get(
					"title",
					"Professional Operations"
				)
			),
			"icon": str(
				profession.get(
					"icon",
					" "
				)
			),
			"description": str(
				profession.get(
					"description",
					"The profession defines the work you can perform."
				)
			),
			"metrics": _array(
				profession.get(
					"metrics",
					[]
				)
			),
			"actions": [
				{
					"action_id": "reveal_section",
					"target_section_id": "workflow",
					"label": "OPEN DUTIES",
					"enabled": true
				}
			]
		}
	]

func _promotion(
	actor: Person,
	path: Dictionary,
	assignment: Dictionary,
	profile: Dictionary
) -> Dictionary:
	if assignment.is_empty():
		return {
			"available": false,
			"progress": 0.0,
			"summary": (
				"Join an organization before promotion can be evaluated."
			),
			"ladder_rows": []
		}

	var ranks: Array = _array(
		path.get(
			"ranks",
			[]
		)
	)
	var current_index: int = int(
		assignment.get(
			"rank_index",
			0
		)
	)
	var next_rank: Dictionary = (
		_dict(
			ranks [
				current_index + 1
			]
		)
		if current_index + 1 < ranks.size()
		else {}
	)
	var performance: int = int(
		assignment.get(
			"performance",
			actor.job_performance
		)
	)
	var experience: int = int(
		assignment.get(
			"experience",
			actor.job_experience
		)
	)
	var reputation: int = _rep_score(
		profile
	)
	var performance_need: int = int(
		next_rank.get(
			"min_performance",
			100
		)
	)
	var experience_need: int = int(
		next_rank.get(
			"min_experience",
			999
		)
	)
	var reputation_need: int = int(
		next_rank.get(
			"min_reputation",
			100
		)
	)
	var progress: float = clampf(
		(
			minf(
				1.0,
				float(
					performance
				)
				/ maxf(
					1.0,
					float(
						performance_need
					)
				)
			)
			+ minf(
				1.0,
				float(
					experience
				)
				/ maxf(
					1.0,
					float(
						experience_need
					)
				)
			)
			+ minf(
				1.0,
				float(
					reputation
				)
				/ maxf(
					1.0,
					float(
						reputation_need
					)
				)
			)
		) / 3.0,
		0.0,
		1.0
	)
	var vacancy: Dictionary = _runtime().find_promotion_vacancy(
		actor
	)
	var ladder: Array = []

	for rank_index in range(
		ranks.size()
	):
		var rank: Dictionary = _dict(
			ranks [
				rank_index
			]
		)
		ladder.append({
			"rank_index": rank_index,
			"title": str(
				rank.get(
					"title",
					"Rank"
				)
			),
			"current": rank_index == current_index,
			"completed": rank_index < current_index,
			"future": rank_index > current_index
		})

	return {
		"available": not next_rank.is_empty(),
		"progress": progress,
		"current_rank_title": str(
			assignment.get(
				"rank_title",
				actor.job
			)
		),
		"next_rank_title": str(
			next_rank.get(
				"title",
				"Top Rank"
			)
		),
		"vacancy_open": not vacancy.is_empty(),
		"performance": performance,
		"performance_required": performance_need,
		"experience": experience,
		"experience_required": experience_need,
		"reputation": reputation,
		"reputation_required": reputation_need,
		"summary": (
			"Promotion requires performance, experience, "
			+ "professional reputation, and a real vacancy."
		),
		"ladder_rows": ladder,
		"actions": [
			{
				"action_id": "request_promotion",
				"label": "REQUEST PROMOTION REVIEW",
				"enabled": not next_rank.is_empty()
			}
		]
	}


func _reputation(
	profile: Dictionary
) -> Dictionary:
	var reputation: Dictionary = _dict(
		profile.get(
			"professional_reputation",
			{}
		)
	)
	var score: int = _rep_score(
		profile
	)
	var axes: Array = []

	for axis in [
		"reliability",
		"leadership",
		"kindness",
		"innovation",
		"efficiency",
		"bravery",
		"corruption",
		"carelessness"
	]:
		axes.append({
			"label": str(
				axis
			).capitalize(),
			"value": int(
				reputation.get(
					axis,
					0
				)
			),
			"max_value": 100
		})

	return {
		"score": score,
		"stars": _stars(
			score
		),
		"summary": (
			"Professional reputation follows this person "
			+ "across organizations."
		),
		"axis_rows": axes,
		"reach_rows": [
			{
				"label": "Organization",
				"value": clampi(
					score + 15,
					0,
					100
				),
				"stars": _stars(
					score + 15
				)
			},
			{
				"label": "Regional",
				"value": clampi(
					score,
					0,
					100
				),
				"stars": _stars(
					score
				)
			},
			{
				"label": "National",
				"value": clampi(
					score - 18,
					0,
					100
				),
				"stars": _stars(
					score - 18
				)
			},
			{
				"label": "International",
				"value": clampi(
					score - 35,
					0,
					100
				),
				"stars": _stars(
					score - 35
				)
			},
			{
				"label": "Legendary",
				"value": clampi(
					score - 55,
					0,
					100
				),
				"stars": _stars(
					score - 55
				)
			}
		]
	}


func _payroll(
	actor: Person,
	assignment: Dictionary
) -> Dictionary:
	var annual: int = (
		int(
			assignment.get(
				"salary",
				actor.income
			)
		)
		if not assignment.is_empty()
		else 0
	)
	var tax_rate: float = 0.0

	if _era() == "Industrial Era":
		tax_rate = 0.12

	elif _era() in [
		"Modern Era",
		"Future Era"
	]:
		tax_rate = 0.2

	var net: int = int(
		round(
			float(annual)
			* (
				1.0 - tax_rate
			)
		)
	)

	var monthly: int = int(
		round(
			float(annual)
			/ 12.0
		)
	)

	return {
		"annual": annual,
		"annual_text": _money(
			annual,
			actor
		),
		"monthly": monthly,
		"monthly_text": _money(
			monthly,
			actor
		),
		"estimated_net": net,
		"estimated_net_text": _money(
			net,
			actor
		),
		"tax_rate": tax_rate,
		"pay_cycle": (
			"Monthly Provision"
			if _era() in [
				"Ancient Era",
				"Medieval Era"
			]
			else "Biweekly"
		)
	}
func _workload_contract(
	assignment: Dictionary,
	presentation: Dictionary
) -> Dictionary:
	if assignment.is_empty():
		return {
			"employed": false,
			"weekly_hours": 0,
			"hour_actions": [],
			"work_harder_action": {},
			"overwork_threshold": 50,
			"player_selectable_max": 50
		}

	var weekly_hours: int = clampi(
		int(
			assignment.get(
				"weekly_hours",
				40
			)
		),
		1,
		84
	)

	var hour_actions: Array = []

	for value in [
		10,
		20,
		30,
		40,
		50
	]:
		hour_actions.append({
			"action_id": "set_weekly_hours",
			"weekly_hours": value,
			"label": (
				"%d HOURS / WEEK"
				% value
			),
			"enabled": (
				value != weekly_hours
			),
			"selected": (
				value == weekly_hours
			),
			"section_id": "actions"
		})

	return {
		"employed": true,
		"weekly_hours": weekly_hours,
		"weekly_hours_label": str(
			presentation.get(
				"weekly_hours_label",
				"WEEKLY HOURS"
			)
		),
		"hour_actions": hour_actions,
		"work_harder_action": {
			"action_id": "work_harder",
			"label": str(
				presentation.get(
					"work_harder_label",
					"WORK HARDER"
				)
			),
			"enabled": true,
			"section_id": "actions"
		},
		"performance_forecast": (
			"More weekly hours increase next-year "
			+ "performance, but longer schedules increase stress."
		),
		"overwork_threshold": 50,
		"player_selectable_max": 50,
	}

func _primary_job_actions(
	lower: Dictionary,
	presentation: Dictionary
) -> Array:
	var out: Array = []

	for raw_action in _array(
		lower.get(
			"actions",
			[]
		)
	):
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			(raw_action as Dictionary).duplicate(false)
		)

		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		).strip_edges().to_lower()

		match action_id:
			"request_promotion":
				action ["label"] = str(
					presentation.get(
						"promotion_action_label",
						"REQUEST PROMOTION REVIEW"
					)
				)

			"request_raise":
				action ["label"] = str(
					presentation.get(
						"raise_action_label",
						"REQUEST RAISE"
					)
				)

			"quit_position":
				action ["label"] = str(
					presentation.get(
						"quit_action_label",
						"QUIT POSITION"
					)
				)

		if action_id in [
			"request_promotion",
			"request_raise",
			"retire",
			"quit_position",
			"view_coworkers"
		]:
			action ["section_id"] = "actions"

			out.append(
				action
			)

	return out

func _benefits(
	path: Dictionary,
	assignment: Dictionary
) -> Array:
	if assignment.is_empty():
		return []

	var rows: Array = [
		{
			"title": "Professional Standing",
			"description": (
				"Organization membership and promotion eligibility."
			)
		},
		{
			"title": "Workplace Access",
			"description": (
				"Access to the spaces required by this profession."
			)
		}
	]
	var material: String = (
		"%s|%s"
		% [
			path.get(
				"display_name",
				""
			),
			path.get(
				"organization_type",
				""
			)
		]
	).to_lower()

	if (
		"hospital" in material
		or "medical" in material
	):
		rows.append({
			"title": "Clinical Coverage",
			"description": (
				"Institutional health and professional-liability support."
			)
		})

	if (
		"military" in material
		or "knight" in material
	):
		rows.append({
			"title": "Equipment and Quarters",
			"description": (
				"Assigned equipment, food, and lodging."
			)
		})

	if _era() in [
		"Modern Era",
		"Future Era"
	]:
		rows.append({
			"title": "Retirement Plan",
			"description": (
				"Retirement value grows with salary and service."
			)
		})

	return rows


func _schedule(
	profession: Dictionary,
	space: Dictionary,
	assignment: Dictionary
) -> Array:
	if assignment.is_empty():
		return [
			{
				"time": "Any Time",
				"label": "Browse Career Paths",
				"location": "Career Discovery"
			},
			{
				"time": "Any Time",
				"label": "Inspect Education Requirements",
				"location": "Education Desk"
			}
		]

	var zones: Array = _array(
		space.get(
			"zone_rows",
			[]
		)
	)
	var location: String = (
		str(
			_dict(
				zones [0]
			).get(
				"label",
				"Workplace"
			)
		)
		if not zones.is_empty()
		else "Workplace"
	)

	return [
		{
			"time": "08:00",
			"label": "Review priorities",
			"location": location
		},
		{
			"time": "09:00",
			"label": str(
				profession.get(
					"primary_task",
					"Professional duties"
				)
			),
			"location": location
		},
		{
			"time": "11:30",
			"label": "Department coordination",
			"location": "Meeting Area"
		},
		{
			"time": "12:30",
			"label": "Coworker social time",
			"location": "Common Area"
		},
		{
			"time": "13:30",
			"label": "Assignments",
			"location": location
		},
		{
			"time": "16:00",
			"label": "Records and handoff",
			"location": location
		},
		{
			"time": "17:00",
			"label": "Clock out",
			"location": "Exit"
		}
	]


func _profession(
	path: Dictionary,
	assignment: Dictionary,
	space: Dictionary
) -> Dictionary:
	if assignment.is_empty():
		return {
			"archetype": "career_discovery",
			"title": "Professional World Discovery",
			"icon": "🔭",
			"description": (
				"Explore professions before applying."
			),
			"primary_task": "Browse careers",
			"metrics": [
				_metric(
					"Browsing",
					"Always Available"
				),
				_metric(
					"Applying",
					"Requirement-Gated"
				)
			]
		}

	var archetype: String = str(
		space.get(
			"space_archetype",
			"office"
		)
	)
	var data: Dictionary = {
		"hospital": [
			"Clinical Operations",
			"🏥",
			(
				"Treat patients, coordinate care, "
				+ "and manage medical risk."
			),
			"Treat patients"
		],
		"legal": [
			"Legal Practice",
			"⚖️",
			(
				"Manage cases, clients, court dates, "
				+ "and firm reputation."
			),
			"Advance active cases"
		],
		"castle": [
			"Knightly Service",
			"⚔️",
			(
				"Train, patrol, serve the liege, "
				+ "and protect the realm."
			),
			"Complete assigned duty"
		],
		"farm": [
			"Agricultural Operations",
			"🌾",
			(
				"Manage fields, animals, storage, "
				+ "and market pressure."
			),
			"Maintain the harvest"
		],
		"merchant": [
			"Trade Operations",
			"📦",
			(
				"Manage routes, inventory, contracts, "
				+ "and competitors."
			),
			"Advance trade contracts"
		],
		"orbital_station": [
			"Interplanetary Mission",
			"🚀",
			(
				"Manage mission systems, crew, "
				+ "research, and survival."
			),
			"Advance the mission"
		],
		"school": [
			"Education Operations",
			"🏫",
			(
				"Teach, mentor, assess, and shape "
				+ "institutional learning."
			),
			"Teach and mentor"
		],
		"police_station": [
			"Public Safety Operations",
			"🚓",
			(
				"Manage cases, evidence, patrols, "
				+ "and command pressure."
			),
			"Advance investigations"
		],
		"forge": [
			"Craft Production",
			"🔥",
			(
				"Manage materials, commissions, quality, "
				+ "and guild standing."
			),
			"Complete a commission"
		],
		"research_center": [
			"Research Program",
			"🧪",
			(
				"Run experiments, publish results, "
				+ "and build discoveries."
			),
			"Advance research"
		]
	}
	var row: Array = _array(
		data.get(
			archetype,
			[
				str(
					path.get(
						"display_name",
						"Professional Operations"
					)
				),
				"🏢",
				(
					"Perform responsibilities inside "
					+ "a living organization."
				),
				"Complete professional work"
			]
		)
	)

	return {
		"archetype": archetype,
		"title": str(
			row [0]
		),
		"icon": str(
			row [1]
		),
		"description": str(
			row [2]
		),
		"primary_task": str(
			row [3]
		),
		"metrics": [
			_metric(
				"Performance",
				str(
					assignment.get(
						"performance",
						50
					)
				)
			),
			_metric(
				"Experience",
				str(
					assignment.get(
						"experience",
						0
					)
				)
			),
			_metric(
				"Stress",
				str(
					int(
						round(
							float(
								assignment.get(
									"work_stress",
									0.0
								)
							)
						)
					)
				)
			)
		]
	}


func _people(
	actor: Person,
	space: Dictionary,
	assignment: Dictionary
) -> Dictionary:
	var rows: Array = _array(
		_dict(
			space.get(
				"coworker_shard",
				{}
			)
		).get(
			"rows",
			[]
		)
	)

	var manager_rows: Array = []
	var colleagues: Array = []
	var subordinates: Array = []

	var current_rank: int = int(
		assignment.get(
			"rank_index",
			0
		)
	)

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		).duplicate(false)

		row = _attach_coworker_relationship_profile(
			actor,
			row
		)

		var coworker_rank: int = int(
			row.get(
				"rank_index",
				current_rank
			)
		)

		if coworker_rank > current_rank:
			row ["tier_relation"] = "boss"
			row ["tier_label"] = "Boss"

			manager_rows.append(
				row
			)

		elif coworker_rank < current_rank:
			row ["tier_relation"] = "subordinate"
			row ["tier_label"] = "Lower Tier"

			subordinates.append(
				row
			)

		else:
			row ["tier_relation"] = "peer"
			row ["tier_label"] = "Coworker"

			colleagues.append(
				row
			)

	manager_rows.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			return int(
				_dict(
					left_raw
				).get(
					"rank_index",
					0
				)
			) > int(
				_dict(
					right_raw
				).get(
					"rank_index",
					0
				)
			)
	)

	var coworker_rows: Array = []

	coworker_rows.append_array(
		colleagues
	)
	coworker_rows.append_array(
		subordinates
	)

	var people_revision_rows:= PackedStringArray()

	for raw_person_row in manager_rows:
		var person_row: Dictionary = _dict(
			raw_person_row
		)

		people_revision_rows.append(
			"%d:%d:%s"
			% [
				int(
					person_row.get(
						"person_id",
						-1
					)
				),
				int(
					person_row.get(
						"rank_index",
						0
					)
				),
				str(
					_dict(
						person_row.get(
							"relationship_profile_contract",
							{}
						)
					).get(
						"signature",
						""
					)
				)
			]
		)

	for raw_person_row in coworker_rows:
		var person_row: Dictionary = _dict(
			raw_person_row
		)

		people_revision_rows.append(
			"%d:%d:%s"
			% [
				int(
					person_row.get(
						"person_id",
						-1
					)
				),
				int(
					person_row.get(
						"rank_index",
						0
					)
				),
				str(
					_dict(
						person_row.get(
							"relationship_profile_contract",
							{}
						)
					).get(
						"signature",
						""
					)
				)
			]
		)

	var people_revision: String = (
		"%d:%d:%d"
		% [
			int(
				actor.id
			),
			int(
				gs.year
			),
			int(
				"|".join(
					people_revision_rows
				).hash()
			)
		]
	)

	return {
		"actor_id": int(
			actor.id
		),
		"manager": (
			manager_rows [0]
			if not manager_rows.is_empty()
			else {}
		),
		"manager_rows": manager_rows,
		"coworker_rows": coworker_rows,
		"colleague_rows": colleagues,
		"subordinate_rows": subordinates,
		"total_coworkers": int(
			_dict(
				space.get(
					"coworker_shard",
					{}
				)
			).get(
				"total",
				rows.size()
			)
		),
		"people_revision": people_revision,
	}
func _resident_person_for_career_profile(
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
		return gs.get_npc_by_id(
			actor_id
		)

	for raw_actor in gs.npcs:
		var actor: Person = (
			raw_actor as Person
		)

		if (
			actor != null
			and int(
				actor.id
			) == actor_id
		):
			return actor

	return null


func _attach_coworker_relationship_profile(
	observer: Person,
	row: Dictionary
) -> Dictionary:
	var out: Dictionary = (
		row.duplicate(false)
	)

	var target_id: int = int(
		out.get(
			"person_id",
			-1
		)
	)

	var target: Person = (
		_resident_person_for_career_profile(
			target_id
		)
	)

	if target == null:
		out [
			"relationship_profile_hot"
		] = false
		return out

	out [
		"target_pointer"
	] = target

	var profile_contract: Dictionary = {}

	if (
		gs != null
		and gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"emit_external_resident_profile_contract"
		)
	):
		profile_contract = (
			gs.relationships_hub_contract_engine
			.emit_external_resident_profile_contract(
				observer,
				target,
				{
					"source": (
						"career_hub_contract_engine."
						+ "coworker_profile_projection"
					),
					"relationship_role": (
						"Professional Coworker"
					),
					"projection_read_only": true,
					"build_on_click_forbidden": true,
					"ready_gate_member": false
				}
			)
		)

	out [
		"relationship_profile_contract"
	] = profile_contract

	out [
		"relationship_profile_hot"
	] = (
		not profile_contract.is_empty()
		and int(
			profile_contract.get(
				"target_id",
				-1
			)
		) == target_id
		and str(
			profile_contract.get(
				"truth_state",
				""
			)
		) == "hot"
	)

	return out

func _certifications(
	path: Dictionary,
	_education_rows: Array,
	actor: Person
) -> Array:
	var requirements: Dictionary = _dict(
		path.get(
			"entry_requirements",
			{}
		)
	)
	var rows: Array = []

	for raw_major in _array(
		requirements.get(
			"majors_any",
			[]
		)
	):
		rows.append({
			"title": str(
				raw_major
			),
			"kind": "major",
			"status": "Required pathway"
		})

	for raw_school in _array(
		requirements.get(
			"graduate_programs_any",
			[]
		)
	):
		rows.append({
			"title": str(
				raw_school
			),
			"kind": "professional_school",
			"status": "Required credential"
		})

	for raw_program in _array(
		requirements.get(
			"historical_programs_any",
			[]
		)
	):
		rows.append({
			"title": str(
				raw_program
			),
			"kind": "era_education",
			"status": "Era pathway"
		})

	if rows.is_empty():
		rows.append({
			"title": "Experience-Based Entry",
			"kind": "experience",
			"status": "No formal credential required"
		})

	rows.append({
		"title": "Application Age",
		"kind": "age",
		"status": (
			"Current age: %d • Minimum: %d"
			% [
				int(
					actor.age
				),
				int(
					requirements.get(
						"min_age",
						18
					)
				)
			]
		)
	})

	return rows


func _timeline(
	profile: Dictionary,
	assignment: Dictionary,
	organization: Dictionary
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_row in _array(
		profile.get(
			"career_history",
			[]
		)
	):
		var row: Dictionary = _dict(
			raw_row
		).duplicate(false)

		if row.is_empty():
			continue

		var row_key: String = str(
			row.get(
				"assignment_id",
				""
			)
		).strip_edges()

		if row_key == "":
			row_key = (
				"%s|%s|%s|%s"
				% [
					str(
						row.get(
							"event",
							"career_event"
						)
					),
					str(
						row.get(
							"year",
							"unknown"
						)
					),
					str(
						row.get(
							"rank_title",
							"career"
						)
					),
					str(
						row.get(
							"organization_name",
							row.get(
								"organization_id",
								"institution"
							)
						)
					)
				]
			)

		if seen.has(
			row_key
		):
			continue

		seen [
			row_key
		] = true

		out.append(
			row
		)

	if not assignment.is_empty():
		var current_assignment_id: String = str(
			assignment.get(
				"assignment_id",
				""
			)
		).strip_edges()

		var current_rank_title: String = str(
			assignment.get(
				"rank_title",
				"Career"
			)
		)

		var current_organization_name: String = str(
			organization.get(
				"name",
				"Institution"
			)
		)

		var current_key: String = current_assignment_id

		if current_key == "":
			current_key = (
				"current_position|%s|%s|%s"
				% [
					str(
						gs.year
					),
					current_rank_title,
					current_organization_name
				]
			)

		var equivalent_current_row_exists: bool = (
			seen.has(
				current_key
			)
		)

		if not equivalent_current_row_exists:
			for raw_row in out:
				var row: Dictionary = _dict(
					raw_row
				)

				if (
					str(
						row.get(
							"rank_title",
							""
						)
					) == current_rank_title
					and str(
						row.get(
							"organization_name",
							row.get(
								"organization_id",
								""
							)
						)
					) == current_organization_name
					and int(
						row.get(
							"year",
							-1
						)
					) == int(
						gs.year
					)
				):
					equivalent_current_row_exists = true
					break

		if not equivalent_current_row_exists:
			out.append({
				"event": "current_position",
				"assignment_id": current_assignment_id,
				"year": int(
					gs.year
				),
				"rank_title": current_rank_title,
				"organization_name": (
					current_organization_name
				)
			})

	return out

func _awards(
	profile: Dictionary,
	assignment: Dictionary
) -> Array:
	var score: int = _rep_score(
		profile
	)
	var performance: int = int(
		assignment.get(
			"performance",
			0
		)
	)
	var rows: Array = []

	if performance >= 75:
		rows.append({
			"title": "High Performer",
			"description": (
				"Performance reached 75 or higher."
			)
		})

	if score >= 70:
		rows.append({
			"title": "Respected Professional",
			"description": (
				"Professional reputation reached 70 or higher."
			)
		})

	if int(
		_dict(
			profile.get(
				"legacy",
				{}
			)
		).get(
			"world_traces",
			0
		)
	) > 0:
		rows.append({
			"title": "Historical Impact",
			"description": (
				"This career has left a trace in the world."
			)
		})

	return rows


func _news(
	organization: Dictionary,
	assignment: Dictionary,
	profile: Dictionary
) -> Array:
	if organization.is_empty():
		return []

	return [
		{
			"title": "Organization Stability",
			"description": (
				"Current stability: %d"
				% int(
					organization.get(
						"stability",
						72
					)
				)
			)
		},
		{
			"title": "Department Staffing",
			"description": (
				"Vacancies and promotions continue "
				+ "to change the hierarchy."
			)
		},
		{
			"title": "Professional Standing",
			"description": (
				"Your reputation score is %d."
				% _rep_score(
					profile
				)
			)
		},
		{
			"title": "Current Position",
			"description": str(
				assignment.get(
					"rank_title",
					"Unassigned"
				)
			)
		}
	]


func _retirement(
	actor: Person,
	assignment: Dictionary
) -> Dictionary:
	var retirement_age: int = 62

	if _era() in [
		"Ancient Era",
		"Medieval Era"
	]:
		retirement_age = 52
	elif _era() == "Industrial Era":
		retirement_age = 58
	elif _era() == "Future Era":
		retirement_age = 68

	return {
		"eligible": (
			not assignment.is_empty()
			and int(
				actor.age
			) >= retirement_age
		),
		"retirement_age": retirement_age,
		"years_remaining": maxi(
			0,
			retirement_age
			- int(
				actor.age
			)
		),
		"summary": (
			"Retirement ends the assignment but preserves "
			+ "professional history and legacy."
		)
	}


func _scenario_actions(
	assignment: Dictionary,
	people: Dictionary,
	profession: Dictionary = {}
) -> Array:
	if assignment.is_empty():
		return []

	var manager: Dictionary = _dict(
		people.get(
			"manager",
			{}
		)
	)

	var profession_archetype: String = str(
		profession.get(
			"archetype",
			"professional"
		)
	).strip_edges().to_lower()

	var profession_title: String = str(
		profession.get(
			"title",
			"Professional Operations"
		)
	).strip_edges()

	var primary_task: String = str(
		profession.get(
			"primary_task",
			"Complete professional work"
		)
	).strip_edges()

	var pressure_label: String = (
		"RESOLVE PROFESSIONAL CRISIS"
	)

	match profession_archetype:
		"restaurant":
			pressure_label = "HANDLE SERVICE RUSH"

		"grocery_store":
			pressure_label = "RESOLVE STORE DISRUPTION"

		"artist_workshop":
			pressure_label = "RESOLVE COMMISSION CRISIS"

		"factory":
			pressure_label = "RESOLVE PRODUCTION FAILURE"

		"logistics":
			pressure_label = "RESOLVE DELIVERY DISRUPTION"

		"farm":
			pressure_label = "RESOLVE HARVEST CRISIS"

		"merchant":
			pressure_label = "RESOLVE TRADE DISPUTE"

		"maintenance":
			pressure_label = "RESOLVE FACILITY FAILURE"

		_:
			pass

	return [
		{
			"action_id": "start_staff_meeting",
			"label": "ATTEND STAFF MEETING",
			"enabled": true,
			"profession_archetype": profession_archetype,
			"profession_title": profession_title,
			"primary_task": primary_task
		},
		{
			"action_id": "start_manager_meeting",
			"label": "MEET WITH MANAGER",
			"target_id": int(
				manager.get(
					"person_id",
					-1
				)
			),
			"enabled": not manager.is_empty(),
			"profession_archetype": profession_archetype,
			"profession_title": profession_title,
			"primary_task": primary_task
		},
		{
			"action_id": "start_profession_scenario",
			"scenario_kind": "professional_pressure",
			"label": pressure_label,
			"enabled": true,
			"profession_archetype": profession_archetype,
			"profession_title": profession_title,
			"primary_task": primary_task
		}
	]
func _tabs(
	presentation: Dictionary = {}
) -> Array:
	return [
		{
			"id": "overview",
			"label": str(
				presentation.get(
					"overview_label",
					"OVERVIEW"
				)
			),
			"icon": " "
		},
		{
			"id": "actions",
			"label": "ACTIONS",
			"icon": " "
		},
		{
			"id": "workplace",
			"label": str(
				presentation.get(
					"workplace_label",
					"WORKPLACE"
				)
			),
			"icon": " "
		},
		{
			"id": "people",
			"label": str(
				presentation.get(
					"people_label",
					"PEOPLE"
				)
			),
			"icon": " "
		},
		{
			"id": "workflow",
			"label": "DUTIES",
			"icon": " "
		},
		{
			"id": "organization",
			"label": str(
				presentation.get(
					"organization_label",
					"ORGANIZATION"
				)
			),
			"icon": " "
		},
		{
			"id": "opportunities",
			"label": "OCCUPATIONS",
			"icon": " "
		},
		{
			"id": "education",
			"label": str(
				presentation.get(
					"education_label",
					"EDUCATION"
				)
			),
			"icon": " "
		},
		{
			"id": "reputation",
			"label": "STANDING",
			"icon": " "
		},
		{
			"id": "promotion",
			"label": str(
				presentation.get(
					"promotion_label",
					"PROMOTION"
				)
			),
			"icon": " "
		},
		{
			"id": "timeline",
			"label": str(
				presentation.get(
					"timeline_label",
					"TIMELINE"
				)
			),
			"icon": " "
		}
	]

func _partial(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	var actor_id: int = (
		int(
			actor.id
		)
		if actor != null
		else -1
	)
	var actor_name: String = _name(
		actor
	)
	var actor_age: int = (
		int(
			actor.age
		)
		if actor != null
		else 0
	)
	var actor_job: String = (
		str(
			actor.job
		).strip_edges()
		if actor != null
		else ""
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"title": "💼 CAREER HUB",
		"subtitle": (
			"Professional reality already exists "
			+ "as an observable surface."
		),
		"current_time": _time_text(),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"overview"
				)
			)
		),
		"career_lane": _lane(
			str(
				context.get(
					"career_lane",
					"full_time"
				)
			)
		),
		"section_tabs": _tabs(),
		"identity_overview": {
			"actor_id": actor_id,
			"name": actor_name,
			"age": actor_age,
			"era_name": _era(),
			"employment_status": (
				"Employed"
				if actor_job != ""
				else "Exploring Careers"
			),
			"position_title": (
				actor_job
				if actor_job != ""
				else "Career Explorer"
			),
			"organization_name": "Professional World",
			"department_name": "Reality Resolving",
			"performance": (
				int(
					actor.job_performance
				)
				if (
					actor != null
					and actor_job != ""
				)
				else 0
			),
			"reputation_score": 0,
			"reputation_stars": "☆☆☆☆☆",
			"satisfaction": (
				int(
					round(
						float(
							actor.satisfaction
						)
					)
				)
				if (
					actor != null
					and actor_job != ""
				)
				else 0
			),
			"work_stress": (
				int(
					round(
						float(
							actor.work_stress
						)
					)
				)
				if (
					actor != null
					and actor_job != ""
				)
				else 0
			),
			"current_time": _time_text(),
			"ui_is_renderer_only": true
		},
		"overview_cards": [
			{
				"title": "Career Reality",
				"description": (
					"The professional world is observable now. "
					+ "Authoritative organization, workplace, "
					+ "and promotion truth reconciles in place."
				),
				"metrics": [
					{
						"label": "Current Role",
						"value": (
							actor_job
							if actor_job != ""
							else "Career Explorer"
						)
					},
					{
						"label": "Era",
						"value": _era()
					}
				]
			}
		],
		"organization_contract": {},
		"workplace_contract": {},
		"people_contract": {},
		"workflow_contract": {},
		"promotion_contract": {},
		"reputation_contract": {},
		"education_contract": {},
		"opportunity_contract": {},
		"timeline_contract": {},
		"status_text": str(
			context.get(
				"status_text",
				(
					"Professional truth is "
					+ "reconciling continuously."
				)
			)
		),
		"truth_state": "observable_partial",
		"authoritative_projection": false,
		"ui_is_renderer_only": true
	}

func _identity_overview(
	actor: Person,
	assignment: Dictionary,
	organization: Dictionary,
	path: Dictionary,
	reputation: Dictionary
) -> Dictionary:
	var employed: bool = (
		not assignment.is_empty()
	)
	var position_title: String = (
		str(
			assignment.get(
				"rank_title",
				actor.job
			)
		).strip_edges()
		if employed
		else "Career Explorer"
	)
	var organization_name: String = (
		str(
			organization.get(
				"name",
				"Independent / Unassigned"
			)
		).strip_edges()
		if employed
		else "No Current Organization"
	)
	var department_name: String = (
		str(
			assignment.get(
				"department_name",
				path.get(
					"department",
					"Professional Discovery"
				)
			)
		).strip_edges()
		if employed
		else "Professional Discovery"
	)

	return {
		"actor_id": int(
			actor.id
		),
		"name": _name(
			actor
		),
		"age": int(
			actor.age
		),
		"era_name": _era(),
		"employment_status": (
			"Employed"
			if employed
			else "Exploring Careers"
		),
		"position_title": position_title,
		"organization_name": organization_name,
		"department_name": department_name,
		"performance": int(
			assignment.get(
				"performance",
				(
					int(
						actor.job_performance
					)
					if employed
					else 0
				)
			)
		),
		"reputation_score": int(
			reputation.get(
				"score",
				0
			)
		),
		"reputation_stars": str(
			reputation.get(
				"stars",
				"☆☆☆☆☆"
			)
		),
		"satisfaction": int(
			assignment.get(
				"satisfaction",
				(
					float(
						actor.satisfaction
					)
					if employed
					else 0.0
				)
			)
		),
		"work_stress": int(
			round(
				float(
					assignment.get(
						"work_stress",
						(
							float(
								actor.work_stress
							)
							if employed
							else 0.0
						)
					)
				)
			)
		),
		"current_time": _time_text(),
		"ui_is_renderer_only": true
	}
func _subtitle(
	actor: Person,
	assignment: Dictionary,
	organization: Dictionary,
	path: Dictionary
) -> String:
	if assignment.is_empty():
		return (
			"%s • Explore the professional world of %s"
			% [
				_name(
					actor
				),
				_era()
			]
		)

	return "%s • %s • %s" % [
		str(
			organization.get(
				"name",
				"Institution"
			)
		),
		str(
			path.get(
				"display_name",
				"Career"
			)
		),
		str(
			assignment.get(
				"rank_title",
				actor.job
			)
		)
	]


func _lower_section(
	hub_section: String
) -> String:
	match hub_section:
		"workflow":
			return "activities"
		"actions":
			return "overview"
		"opportunities":
			return "opportunities"
		"organization", "people", "workplace":
			return "organization"
		"education":
			return "education"
		"reputation":
			return "reputation"
		"timeline":
			return "legacy"
		_:
			return "overview"

func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	return (
		clean
		if clean in [
			"overview",
			"actions",
			"workplace",
			"people",
			"workflow",
			"organization",
			"opportunities",
			"education",
			"reputation",
			"promotion",
			"timeline"
		]
		else "overview"
	)


func _lane(
	value: String
) -> String:
	return (
		"part_time"
		if str(
			value
		).strip_edges().to_lower() == "part_time"
		else "full_time"
	)


func _lens_for(
	actor: Person
) -> Dictionary:
	var state: Dictionary = _dict(
		_lens_root().get(
			str(
				int(
					actor.id
				)
			),
			{}
		)
	)

	return (
		state
		if not state.is_empty()
		else {
			"active_section": "overview",
			"career_lane": "full_time",
			"selected_path_id": "",
			"zone_id": "",
			"coworker_shard_offset": 0
		}
	)


func _commit_lens(
	actor: Person,
	state: Dictionary
) -> void:
	var root: Dictionary = _lens_root()
	root [
		str(
			int(
				actor.id
			)
		)
	] = state.duplicate(true)
	gs.scenario_state [LENS_STATE_KEY] = root


func _ensure_lens_root() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if typeof(
		gs.scenario_state.get(
			LENS_STATE_KEY,
			{}
		)
	) != TYPE_DICTIONARY:
		gs.scenario_state [LENS_STATE_KEY] = {}


func _lens_root() -> Dictionary:
	_ensure_lens_root()

	return (
		_dict(
			gs.scenario_state.get(
				LENS_STATE_KEY,
				{}
			)
		)
		if gs != null
		else {}
	)


func _rep_score(
	profile: Dictionary
) -> int:
	if profile.has(
		"professional_reputation_score"
	):
		return clampi(
			int(
				profile.get(
					"professional_reputation_score",
					50
				)
			),
			0,
			100
		)

	var reputation: Dictionary = _dict(
		profile.get(
			"professional_reputation",
			{}
		)
	)

	return clampi(
		int(
			round(
				float(
					reputation.get(
						"reliability",
						50
					)
				) * 0.18
				+ float(
					reputation.get(
						"leadership",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"kindness",
						50
					)
				) * 0.1
				+ float(
					reputation.get(
						"innovation",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"efficiency",
						50
					)
				) * 0.16
				+ float(
					reputation.get(
						"bravery",
						50
					)
				) * 0.1
				- float(
					reputation.get(
						"corruption",
						0
					)
				) * 0.08
				- float(
					reputation.get(
						"carelessness",
						0
					)
				) * 0.08
				+ 18.0
			)
		),
		0,
		100
	)


func _metric(
	label: String,
	value: String
) -> Dictionary:
	return {
		"label": label,
		"value": value
	}


func _money(
	value: int,
	actor: Person = null
) -> String:
	if (
		gs != null
		and gs.economy_engine != null
		and gs.economy_engine.has_method(
			"format_money"
		)
	):
		return str(
			gs.economy_engine.format_money(
				value,
				actor
			)
		)

	return str(
		value
	)


func _time_text() -> String:
	var now: Dictionary = Time.get_time_dict_from_system()

	return "%02d:%02d" % [
		int(
			now.get(
				"hour",
				0
			)
		),
		int(
			now.get(
				"minute",
				0
			)
		)
	]


func _stars(
	value: int
) -> String:
	var filled: int = clampi(
		int(
			round(
				float(
					value
				) / 20.0
			)
		),
		0,
		5
	)

	return (
		"★".repeat(
			filled
		)
		+ "☆".repeat(
			5 - filled
		)
	)


func _runtime():
	return (
		gs.career_runtime_engine
		if gs != null
		else null
	)


func _law():
	return (
		gs.career_contract_engine
		if gs != null
		else null
	)


func _space():
	return (
		gs.career_space_contract_engine
		if gs != null
		else null
	)


func _person(
	actor_id: int
) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		return gs.get_or_reactivate_npc_by_id(
			actor_id
		)

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			actor_id
		)

	return null


func _name(
	person: Person
) -> String:
	if person == null:
		return "Someone"

	var full_name: String = (
		"%s %s"
		% [
			str(
				person.first_name
			),
			str(
				person.last_name
			)
		]
	).strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d"
		% int(
			person.id
		)
	)


func _era() -> String:
	return (
		str(
			gs.era.get(
				"name",
				"Unknown Era"
			)
		)
		if gs != null and gs.era != null
		else "Unknown Era"
	)


func _dict(
	value
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value
) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)


func _fail(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}